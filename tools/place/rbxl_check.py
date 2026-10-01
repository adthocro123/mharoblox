"""Check a binary place / model the way Studio does when it opens one:
class ids 0..classes-1, one INST chunk each, the instance counts adding up
to the header's, every referent unique and inside [0, instances), the
parent table covering every instance (parents -1 or a real referent), and
referent properties pointing at real instances (or -1).
Usage: rbxl_check.py file.rbxl [...]"""
import struct, sys
from rbxl_write import raw_chunks, decompress
from rbxl_splice import dec_refs


def check(path):
    data = open(path, 'rb').read()
    n_classes, n_inst = struct.unpack_from('<II', data, 16)
    problems = []
    cids, counts, refs = set(), {}, []
    prnt = None
    ref_props = []
    for name, raw, clen, ulen in raw_chunks(data):
        tag = name.rstrip(b'\0')
        if tag == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cnt, = struct.unpack_from('<I', body, 9 + ln)
            if cid in cids:
                problems.append('class id %d twice' % cid)
            cids.add(cid)
            counts[cid] = cnt
            refs += dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt)
        elif tag == b'PROP':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            if body[8 + ln] == 0x13:
                ref_props.append((cid, body[8:8 + ln].decode(), body[9 + ln:]))
        elif tag == b'PRNT':
            body = decompress(raw, clen, ulen)
            n, = struct.unpack_from('<I', body, 1)
            prnt = (dec_refs(body[5:5 + 4 * n], n), dec_refs(body[5 + 4 * n:5 + 8 * n], n))
    if cids != set(range(n_classes)):
        problems.append('class ids not 0..%d (%d of them)' % (n_classes - 1, len(cids)))
    if sum(counts.values()) != n_inst or len(refs) != n_inst:
        problems.append('instances: header %d, chunks %d' % (n_inst, len(refs)))
    bad = [r for r in refs if r < 0 or r >= n_inst]
    if bad:
        problems.append('%d referents outside [0, %d) (e.g. %d)' % (len(bad), n_inst, bad[0]))
    if len(set(refs)) != len(refs):
        problems.append('duplicate referents')
    known = set(refs)
    if prnt is None:
        problems.append('no PRNT chunk')
    else:
        kids, pars = prnt
        if sorted(kids) != sorted(refs):
            problems.append('PRNT covers %d instances, not the %d there are' % (len(kids), len(refs)))
        odd = [p for p in pars if p != -1 and p not in known]
        if odd:
            problems.append('%d parents are not instances (e.g. %d)' % (len(odd), odd[0]))
    for cid, pname, buf in ref_props:
        vals = dec_refs(buf[:4 * counts.get(cid, 0)], counts.get(cid, 0))
        odd = [v for v in vals if v != -1 and v not in known]
        if odd:
            problems.append('%d %s references point nowhere' % (len(odd), pname))
    return n_classes, n_inst, problems


if __name__ == '__main__':
    bad = 0
    for p in sys.argv[1:]:
        c, n, problems = check(p)
        print('%s: %d classes, %d instances: %s' % (p, c, n, 'OK' if not problems else '; '.join(problems)))
        bad += bool(problems)
    sys.exit(1 if bad else 0)
