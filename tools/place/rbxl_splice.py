"""Splice a binary model (.rbxm) into a binary place (.rbxl) under an existing
instance, leaving every existing chunk byte-identical except the parent table
(PRNT) and the header's class / instance counts.
Usage: rbxl_splice.py in.rbxl model.rbxm out.rbxl ParentPath
The model's classes must not already exist in the place (they get new class
ids). Its referents are renumbered into the ids the place leaves free below
the new instance count - Studio refuses any referent outside [0, count):
past the place's highest one when its ids run 0..n-1, into the gap when
something was taken out first (rbxl_strip.py)."""
import struct, sys
import rbxl
from rbxl_write import raw_chunks, decompress, pack_chunk, _deinterleave, _interleave


def enc_refs(vals):
    out, prev = [], 0
    for v in vals:
        d = v - prev
        prev = v
        u = ((d << 1) ^ (d >> 31)) & 0xffffffff
        out.append(struct.pack('>I', u))
    return _interleave(out, 4)


def dec_refs(buf, n):
    return rbxl.read_refs(buf, 0, n)[0]


def splice(place_path, model_path, out_path, parent_path):
    place = open(place_path, 'rb').read()
    model = open(model_path, 'rb').read()
    p_classes, p_count = struct.unpack_from('<II', place, 16)
    _, _, inst = rbxl.parse(place_path)

    def path(r):
        p = []
        while r != -1 and r in inst:
            p.append(inst[r]['props'].get('Name', '?'))
            r = inst[r]['parent']
        return '.'.join(reversed(p))

    parents = [r for r in inst if path(r) == parent_path]
    assert len(parents) == 1, ('parent not unique', parent_path, len(parents))
    parent_ref = parents[0]
    existing_classes = {v['class'] for v in inst.values()}

    pchunks = raw_chunks(place)
    mchunks = raw_chunks(model)
    # the model's referents -> the free ids below the new count, in order
    m_refs = []
    for name, raw, clen, ulen in mchunks:
        if name.rstrip(b'\0') == b'INST':
            body = decompress(raw, clen, ulen)
            ln, = struct.unpack_from('<I', body, 4)
            cnt, = struct.unpack_from('<I', body, 9 + ln)
            m_refs += dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt)
    total = p_count + len(m_refs)
    assert len(inst) == p_count and max(inst) < total, ('place ids reach past the new count', max(inst), total)
    free = sorted(set(range(total)) - set(inst))
    assert len(free) == len(m_refs) == len(set(m_refs))
    new_ref = dict(zip(sorted(m_refs), free))
    m_inst, m_prop, m_prnt = [], [], None
    cid_map = {}
    new_class_names = []
    m_count = 0
    for name, raw, clen, ulen in mchunks:
        tag = name.rstrip(b'\0')
        if tag == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cname = body[8:8 + ln].decode()
            assert cname not in existing_classes, 'class already in the place: ' + cname
            fmt = body[8 + ln]
            assert fmt == 0, 'services not supported'
            cnt, = struct.unpack_from('<I', body, 9 + ln)
            refs = dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt)
            new_cid = p_classes + len(new_class_names)
            cid_map[cid] = new_cid
            new_class_names.append(cname)
            m_count += cnt
            nb = struct.pack('<I', new_cid) + body[4:13 + ln] + enc_refs([new_ref[r] for r in refs]) + body[13 + ln + 4 * cnt:]
            m_inst.append(pack_chunk(b'INST', nb))
        elif tag == b'PROP':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            ptype = body[8 + ln]
            assert ptype not in (0x13, 0x1c), 'referent / shared-string properties not supported'
            m_prop.append(pack_chunk(b'PROP', struct.pack('<I', cid_map[cid]) + body[4:]))
        elif tag == b'PRNT':
            body = decompress(raw, clen, ulen)
            assert body[0] == 0
            n, = struct.unpack_from('<I', body, 1)
            kids = dec_refs(body[5:5 + 4 * n], n)
            pars = dec_refs(body[5 + 4 * n:5 + 8 * n], n)
            m_prnt = [(new_ref[k], new_ref[p] if p >= 0 else parent_ref) for k, p in zip(kids, pars)]
        elif tag in (b'META', b'SSTR'):
            pass  # (nothing the model needs)
    assert m_prnt is not None and len(m_prnt) == m_count

    out = [bytearray(place[:32])]
    struct.pack_into('<II', out[0], 16, p_classes + len(new_class_names), p_count + m_count)
    last_inst = max(i for i, c in enumerate(pchunks) if c[0].rstrip(b'\0') == b'INST')
    for i, (name, raw, clen, ulen) in enumerate(pchunks):
        tag = name.rstrip(b'\0')
        if tag == b'PRNT':
            out.extend(m_prop)  # the model's properties, after the place's
            body = decompress(raw, clen, ulen)
            n, = struct.unpack_from('<I', body, 1)
            kids = dec_refs(body[5:5 + 4 * n], n)
            pars = dec_refs(body[5 + 4 * n:5 + 8 * n], n)
            assert 5 + 8 * n == len(body)
            kids += [k for k, _ in m_prnt]
            pars += [p for _, p in m_prnt]
            nb = bytes([0]) + struct.pack('<I', len(kids)) + enc_refs(kids) + enc_refs(pars)
            out.append(pack_chunk(b'PRNT', nb))
            continue
        out.append(raw)
        if i == last_inst:
            out.extend(m_inst)
    open(out_path, 'wb').write(b''.join(bytes(b) for b in out))
    return new_class_names, m_count


if __name__ == '__main__':
    print('spliced', splice(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]))
