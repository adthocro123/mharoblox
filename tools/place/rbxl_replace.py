"""Replace a folder in a binary place (.rbxl) with a new one from a binary
model (.rbxm), in place: the model's classes must already be in the place
and be used only by the folder being replaced (ReplicatedStorage.Animations:
Configuration, KeyframeSequence, Keyframe, Pose). Those classes keep their
class ids; their INST / PROP chunks are swapped for the model's; the new
instances get the ids the old ones free (and any more just past them), so
every referent stays inside [0, instance count) as Studio requires. Every
other chunk is left byte-identical, and what is written here is compressed
the way rbxl_write.PACK says (RBXL_PACK=zstd for a place Studio saved with
zstd, so the file never mixes the two).
Usage: rbxl_replace.py in.rbxl model.rbxm out.rbxl ParentPath"""
import struct, sys
import rbxl
from rbxl_write import raw_chunks, decompress, pack_chunk
from rbxl_splice import enc_refs, dec_refs


def replace(place_path, model_path, out_path, parent_path):
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

    # the model: its classes, instances, properties and parents
    m_inst, m_props, m_prnt, m_refs = {}, {}, None, []
    for name, raw, clen, ulen in raw_chunks(model):
        tag = name.rstrip(b'\0')
        body = decompress(raw, clen, ulen) if tag in (b'INST', b'PROP', b'PRNT') else None
        if tag == b'INST':
            cid, ln = struct.unpack_from('<II', body, 0)
            assert body[8 + ln] == 0, 'services not supported'
            cnt, = struct.unpack_from('<I', body, 9 + ln)
            refs = dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt)
            m_inst[cid] = (body[8:8 + ln].decode(), body, ln, cnt, refs)
            m_refs += refs
        elif tag == b'PROP':
            cid, ln = struct.unpack_from('<II', body, 0)
            assert body[8 + ln] not in (0x13, 0x1c), 'referent / shared-string properties not supported'
            m_props.setdefault(cid, []).append(body)
        elif tag == b'PRNT':
            assert body[0] == 0
            n, = struct.unpack_from('<I', body, 1)
            m_prnt = list(zip(dec_refs(body[5:5 + 4 * n], n), dec_refs(body[5 + 4 * n:5 + 8 * n], n)))
    names = {v[0] for v in m_inst.values()}
    roots = [k for k, p in m_prnt if p < 0]
    assert len(roots) == 1, 'the model should have one root'

    # the place: which class ids those are, and the instances that go
    pchunks = raw_chunks(place)
    p_cid, p_counts, gone = {}, {}, set()
    for name, raw, clen, ulen in pchunks:
        if name.rstrip(b'\0') == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cname = body[8:8 + ln].decode()
            cnt, = struct.unpack_from('<I', body, 9 + ln)
            p_counts[cid] = cnt
            if cname in names:
                p_cid[cname] = cid
                gone.update(dec_refs(body[13 + ln:13 + ln + 4 * cnt], cnt))
    assert set(p_cid) == names, ('classes missing from the place', names - set(p_cid))
    outside = [path(r) for r in gone if not path(r).startswith(parent_path + '.')]
    assert not outside, ('instances of those classes outside the folder', outside[:3])

    keep = set(inst) - gone
    total = len(keep) + len(m_refs)
    assert len(inst) == p_count and max(keep) < total, ('ids reach past the new count', max(keep), total)
    free = sorted(set(range(total)) - keep)
    assert len(free) == len(m_refs) == len(set(m_refs))
    new_ref = dict(zip(sorted(m_refs), free))
    by_name = {v[0]: (cid, v) for cid, v in m_inst.items()}

    out = [bytearray(place[:32])]
    struct.pack_into('<II', out[0], 16, p_classes, total)
    props_done = set()
    for name, raw, clen, ulen in pchunks:
        tag = name.rstrip(b'\0')
        if tag == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cname = body[8:8 + ln].decode()
            if cname in names:
                _, (mname, mbody, mln, cnt, refs) = by_name[cname]
                nb = struct.pack('<I', cid) + mbody[4:13 + mln] + enc_refs([new_ref[r] for r in refs]) + mbody[13 + mln + 4 * cnt:]
                out.append(pack_chunk(b'INST', nb))
                continue
        elif tag == b'PROP':
            body = decompress(raw, clen, ulen)
            cid, = struct.unpack_from('<I', body, 0)
            cname = next((n for n, c in p_cid.items() if c == cid), None)
            if cname is not None:
                if cname not in props_done:  # the model's properties go where the old ones were
                    props_done.add(cname)
                    mcid = by_name[cname][0]
                    for mb in m_props.get(mcid, []):
                        out.append(pack_chunk(b'PROP', struct.pack('<I', cid) + mb[4:]))
                continue
            # (nothing that stays may point at what goes)
            ln, = struct.unpack_from('<I', body, 4)
            if body[8 + ln] == 0x13:
                vals = dec_refs(body[9 + ln:9 + ln + 4 * p_counts[cid]], p_counts[cid])
                assert not any(v in gone for v in vals), 'a referent property points into the folder'
        elif tag == b'PRNT':
            for cname in names - props_done:  # (a class whose old instances had no properties)
                mcid = by_name[cname][0]
                for mb in m_props.get(mcid, []):
                    out.append(pack_chunk(b'PROP', struct.pack('<I', p_cid[cname]) + mb[4:]))
            body = decompress(raw, clen, ulen)
            assert body[0] == 0
            n, = struct.unpack_from('<I', body, 1)
            kids = dec_refs(body[5:5 + 4 * n], n)
            pars = dec_refs(body[5 + 4 * n:5 + 8 * n], n)
            pairs = [(k, p) for k, p in zip(kids, pars) if k not in gone]
            assert all(p not in gone for _, p in pairs), 'something that stays is parented to what goes'
            pairs += [(new_ref[k], new_ref[p] if p >= 0 else parent_ref) for k, p in m_prnt]
            nb = bytes([0]) + struct.pack('<I', len(pairs)) + enc_refs([k for k, _ in pairs]) + enc_refs([p for _, p in pairs])
            out.append(pack_chunk(b'PRNT', nb))
            continue
        out.append(raw)
    open(out_path, 'wb').write(b''.join(bytes(b) for b in out))
    return sorted(names), len(gone), len(m_refs)


if __name__ == '__main__':
    print('replaced', replace(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]))
