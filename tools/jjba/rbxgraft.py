"""Graft subtrees of one binary place (.rbxl) into another.

Every chunk of the target is kept byte-identical except:
  * the INST / PROP chunks of classes the graft adds instances to (the old
    instances' values are kept exactly; the new ones are appended),
  * the SSTR (shared strings) chunk, when new shared strings are needed,
  * the PRNT (parent) chunk, and the header's class / instance counts.
Classes the target doesn't have yet get new INST / PROP chunks.

Usage (from Python):
  graft(target, out, source, items, exclude=set(), rbxl_dir=...)
  items: [(source_path, target_parent_path, new_name_or_None), ...]
Paths are dotted Name paths from the DataModel (Service.Child.Child).
References (Ref properties) to instances outside the grafted subtrees become
nil. Instances of excluded classes are left out with everything under them.
"""
import hashlib
import os
import random
import struct
import sys
from collections import Counter

import rbxcodec

PACK_ZSTD = True


def _load_helpers(rbxl_dir):
    sys.path.insert(0, rbxl_dir)
    import rbxl  # noqa
    from rbxl_write import raw_chunks, decompress  # noqa
    return rbxl, raw_chunks, decompress


def _pack(name, body):
    import zstandard
    comp = zstandard.ZstdCompressor(level=3, write_content_size=True, write_checksum=False).compress(body)
    return name + struct.pack('<III', len(comp), len(body), 0) + comp


def _enc_refs(vals):
    return rbxcodec.join(0x13, vals)


def _dec_refs(buf, n):
    return rbxcodec.split(0x13, buf[:4 * n], n)


class Place:
    def __init__(self, path, rbxl, raw_chunks, decompress):
        self.file = path
        self.data = open(path, 'rb').read()
        self.n_classes, self.n_inst = struct.unpack_from('<II', self.data, 16)
        self.chunks = raw_chunks(self.data)  # (name, raw, clen, ulen)
        self.decompress = decompress
        self.classes = {}  # cid -> dict(name, fmt, refs, extra, chunk_index)
        self.props = {}  # cid -> list of (pname, ptype, chunk_index)
        self.cid_of = {}
        self.sstr = None  # (version, [(hash, value)])
        self.sstr_index = None
        self.parent = {}
        self.order = []  # PRNT order of (child, parent)
        for i, (name, raw, clen, ulen) in enumerate(self.chunks):
            tag = name.rstrip(b'\0')
            if tag == b'INST':
                body = decompress(raw, clen, ulen)
                cid, ln = struct.unpack_from('<II', body, 0)
                cname = body[8:8 + ln].decode()
                fmt = body[8 + ln]
                cnt, = struct.unpack_from('<I', body, 9 + ln)
                refs = _dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt)
                extra = body[13 + ln + 4 * cnt:]
                self.classes[cid] = dict(name=cname, fmt=fmt, refs=refs, extra=extra, chunk=i)
                self.cid_of[cname] = cid
            elif tag == b'PROP':
                body = decompress(raw, clen, ulen)
                cid, ln = struct.unpack_from('<II', body, 0)
                pname = body[8:8 + ln].decode()
                self.props.setdefault(cid, []).append((pname, body[8 + ln], i))
            elif tag == b'SSTR':
                body = decompress(raw, clen, ulen)
                ver, cnt = struct.unpack_from('<II', body, 0)
                p, entries = 8, []
                for _ in range(cnt):
                    h = body[p:p + 16]
                    l, = struct.unpack_from('<I', body, p + 16)
                    entries.append((h, body[p + 20:p + 20 + l]))
                    p += 20 + l
                assert p == len(body)
                self.sstr = (ver, entries)
                self.sstr_index = i
            elif tag == b'PRNT':
                body = decompress(raw, clen, ulen)
                assert body[0] == 0
                n, = struct.unpack_from('<I', body, 1)
                kids = _dec_refs(body[5:5 + 4 * n], n)
                pars = _dec_refs(body[5 + 4 * n:5 + 8 * n], n)
                assert 5 + 8 * n == len(body)
                self.order = list(zip(kids, pars))
                for k, p in self.order:
                    self.parent[k] = p
                self.prnt_index = i
        self.class_of = {}
        for cid, c in self.classes.items():
            for r in c['refs']:
                self.class_of[r] = cid
        self.children = {}
        for k, p in self.order:
            self.children.setdefault(p, []).append(k)
        self._names = None

    def body(self, i):
        name, raw, clen, ulen = self.chunks[i]
        return self.decompress(raw, clen, ulen)

    def prop_values(self, cid, pname):
        for pn, pt, i in self.props.get(cid, []):
            if pn == pname:
                b = self.body(i)
                ln, = struct.unpack_from('<I', b, 4)
                return pt, rbxcodec.split(pt, b[9 + ln:], len(self.classes[cid]['refs']))
        return None, None

    def names(self):
        if self._names is None:
            self._names = {}
            for cid, c in self.classes.items():
                t, vals = self.prop_values(cid, 'Name')
                for r, v in zip(c['refs'], vals or []):
                    self._names[r] = v[4:].decode('utf-8', 'replace')
        return self._names

    def path(self, r):
        names, p = self.names(), []
        while r != -1 and r in self.class_of:
            p.append(names.get(r, '?'))
            r = self.parent.get(r, -1)
        return '.'.join(reversed(p))

    def find(self, path):
        # walk from the root by names (services are roots)
        names = self.names()
        parts = path.split('.')
        level = [r for r in self.class_of if self.parent.get(r, -1) == -1 and names.get(r) == parts[0]]
        for part in parts[1:]:
            level = [k for r in level for k in self.children.get(r, []) if names.get(k) == part]
        assert len(level) == 1, ('not unique', path, len(level))
        return level[0]


def graft(target_path, out_path, source_path, items, exclude=(), rbxl_dir=None, seed=104):
    rbxl, raw_chunks, decompress = _load_helpers(rbxl_dir)
    rnd = random.Random(seed)
    T = Place(target_path, rbxl, raw_chunks, decompress)
    S = Place(source_path, rbxl, raw_chunks, decompress)
    exclude = set(exclude)

    # 1. what comes over, pre-order (parents before children, siblings in order)
    sel, root_of = [], {}
    renamed = {}
    names = S.names()
    for item in items:
        spath, tparent, newname = item[0], item[1], item[2]
        extra = set(item[3]) if len(item) > 3 and item[3] else set()
        root = S.find(spath)
        tpar = T.find(tparent)
        stack = [root]
        while stack:
            r = stack.pop()
            cname = S.classes[S.class_of[r]]['name']
            if cname in exclude or (r != root and (cname in extra or names.get(r) in extra)):
                continue
            sel.append(r)
            stack.extend(reversed(S.children.get(r, [])))
        root_of[root] = tpar
        if newname:
            renamed[root] = newname
    assert len(sel) == len(set(sel)), 'overlapping items'
    M = len(sel)
    total = T.n_inst + M
    assert len(T.class_of) == T.n_inst and max(T.class_of) < total
    free = sorted(set(range(total)) - set(T.class_of))
    assert len(free) == M
    new_ref = dict(zip(sel, free))
    selset = set(sel)

    # 2. shared strings the selection uses
    t_ver, t_entries = T.sstr
    # (keyed by content: Studio writes every hash as 16 zero bytes now)
    t_by_value = {}
    for i, (h, v) in enumerate(t_entries):
        t_by_value.setdefault(v, i)
    s_entries = S.sstr[1] if S.sstr else []
    sstr_map = {}

    def map_sstr(i):
        if i not in sstr_map:
            h, v = s_entries[i]
            if v not in t_by_value:
                t_by_value[v] = len(t_entries)
                t_entries.append((h, v))
            sstr_map[i] = t_by_value[v]
        return sstr_map[i]

    # 3. per source class: the selected instances, in INST order
    by_class = {}
    for r in sel:
        by_class.setdefault(S.class_of[r], []).append(r)
    for cid in by_class:
        index = {r: i for i, r in enumerate(S.classes[cid]['refs'])}
        by_class[cid].sort(key=lambda r: index[r])

    # (round 107) every UniqueId already in the target: Studio won't open a
    # place where two instances share one ("DM contains duplicate Unique
    # ids"), and a source instance grafted in before (or the same one twice)
    # carries the same id. A copied id that's taken gets a fresh one: the
    # same time and random parts, the next index nobody's using.
    taken_ids = set()
    for cid in T.classes:
        t, vals = T.prop_values(cid, 'UniqueId')
        if t == 0x1F:
            taken_ids.update(v for v in vals if v != bytes(16))
    reminted = []

    def fresh_id(v):
        if v == bytes(16) or v not in taken_ids:
            taken_ids.add(v)
            return v
        idx, = struct.unpack_from('>I', v, 0)
        while True:
            idx = (idx + 1) & 0xFFFFFFFF
            w = struct.pack('>I', idx) + v[4:]
            if w not in taken_ids:
                taken_ids.add(w)
                reminted.append((v, w))
                return w

    def source_vals(scid, pname, ptype):
        """values of pname for the selected instances of source class scid"""
        st, vals = S.prop_values(scid, pname)
        if st is None:
            return None
        assert st == ptype, (S.classes[scid]['name'], pname, hex(st), hex(ptype))
        index = {r: i for i, r in enumerate(S.classes[scid]['refs'])}
        out = []
        for r in by_class[scid]:
            v = vals[index[r]]
            if ptype == 0x13:
                v = new_ref.get(v, -1) if v != -1 else -1
            elif ptype == 0x1C:
                v = map_sstr(v)
            elif ptype == 0x1F and pname == 'UniqueId':
                v = fresh_id(v)
            elif pname == 'Name' and r in renamed:
                nb = renamed[r].encode()
                v = struct.pack('<I', len(nb)) + nb
            out.append(v)
        return out

    replaced = {}  # chunk index -> new raw chunk
    new_inst_chunks, new_prop_chunks = [], []
    report = {'merged': {}, 'new': {}, 'defaulted': [], 'dropped': []}
    next_cid = T.n_classes
    for scid, refs in sorted(by_class.items(), key=lambda kv: S.classes[kv[0]]['name']):
        cname = S.classes[scid]['name']
        s_props = {pn: pt for pn, pt, i in S.props.get(scid, [])}
        if cname in T.cid_of:
            tcid = T.cid_of[cname]
            c = T.classes[tcid]
            old_n = len(c['refs'])
            assert c['fmt'] == 0 and S.classes[scid]['fmt'] == 0
            body = struct.pack('<I', tcid) + struct.pack('<I', len(cname)) + cname.encode() + bytes([0])
            body += struct.pack('<I', old_n + len(refs)) + _enc_refs(c['refs'] + [new_ref[r] for r in refs]) + c['extra']
            replaced[c['chunk']] = _pack(b'INST', body)
            t_names = set()
            for pname, ptype, i in T.props.get(tcid, []):
                t_names.add(pname)
                b = T.body(i)
                ln, = struct.unpack_from('<I', b, 4)
                old = rbxcodec.split(ptype, b[9 + ln:], old_n)
                add = source_vals(scid, pname, ptype) if s_props.get(pname) == ptype else None
                if add is None:
                    if ptype == 0x1F:
                        add = [fresh_id(bytes(rnd.getrandbits(8) for _ in range(16))) for _ in refs]
                    elif ptype == 0x13:
                        add = [-1] * len(refs)
                    else:
                        common = Counter(old).most_common(1)[0][0]
                        add = [common] * len(refs)
                    report['defaulted'].append((cname, pname))
                nb = b[:9 + ln] + rbxcodec.join(ptype, old + add)
                replaced[i] = _pack(b'PROP', nb)
            for pname in s_props:
                if pname not in t_names:
                    report['dropped'].append((cname, pname))
            report['merged'][cname] = len(refs)
        else:
            tcid = next_cid
            next_cid += 1
            assert S.classes[scid]['fmt'] == 0
            body = struct.pack('<I', tcid) + struct.pack('<I', len(cname)) + cname.encode() + bytes([0])
            body += struct.pack('<I', len(refs)) + _enc_refs([new_ref[r] for r in refs])
            new_inst_chunks.append(_pack(b'INST', body))
            for pname, ptype, i in S.props.get(scid, []):
                vals = source_vals(scid, pname, ptype)
                nb = struct.pack('<I', tcid) + struct.pack('<I', len(pname)) + pname.encode() + bytes([ptype])
                new_prop_chunks.append(_pack(b'PROP', nb + rbxcodec.join(ptype, vals)))
            report['new'][cname] = len(refs)

    # 4. parents: the target's, then the selection's (pre-order)
    order = list(T.order)
    for r in sel:
        p = S.parent.get(r, -1)
        order.append((new_ref[r], root_of[r] if r in root_of else new_ref[p]))
    kids = [k for k, _ in order]
    pars = [p for _, p in order]
    replaced[T.prnt_index] = _pack(b'PRNT', bytes([0]) + struct.pack('<I', len(order)) + _enc_refs(kids) + _enc_refs(pars))

    # 5. shared strings
    if sstr_map:
        sb = struct.pack('<II', t_ver, len(t_entries))
        for h, v in t_entries:
            sb += h + struct.pack('<I', len(v)) + v
        replaced[T.sstr_index] = _pack(b'SSTR', sb)

    # 6. write: header, chunks in order (new INST after the last INST, new PROP before PRNT)
    head = bytearray(T.data[:32])
    struct.pack_into('<II', head, 16, next_cid, total)
    out = [bytes(head)]
    last_inst = max(i for i, c in enumerate(T.chunks) if c[0].rstrip(b'\0') == b'INST')
    for i, (name, raw, clen, ulen) in enumerate(T.chunks):
        tag = name.rstrip(b'\0')
        if tag == b'PRNT':
            out.extend(new_prop_chunks)
        out.append(replaced.get(i, raw))
        if i == last_inst:
            out.extend(new_inst_chunks)
    open(out_path, 'wb').write(b''.join(out))
    report['count'] = M
    report['reminted'] = reminted  # (round 107) copied UniqueIds that were taken: (old, new)
    report['sstr_added'] = len(sstr_map)
    report['new_ref_of_root'] = {S.path(r): new_ref[r] for r in root_of}
    return report


if __name__ == '__main__':
    import json
    spec = json.load(open(sys.argv[1]))
    rep = graft(spec['target'], spec['out'], spec['source'], spec['items'], spec.get('exclude', []), spec['rbxl_dir'])
    print(json.dumps(rep, indent=1, default=str)[:6000])
