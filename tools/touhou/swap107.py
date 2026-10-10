# Round 107: the new account's animation ids into a place, outside Studio.
# reupload_anims.py writes map.json (old id -> new id); this rewrites every
# Animation's AnimationId and every Sound's SoundId found in it, leaving
# every other chunk byte-identical (the same job as its swap_animations.lua
# in Studio). A map's value can also be {"new": id, ...} (sounds107_map.json).
#   RBXL_PACK=zstd python3 -I swap107.py in.rbxl map.json out.rbxl
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'place'))
import rbxl  # noqa: E402
from rbxl_write import raw_chunks, decompress, pack_chunk  # noqa: E402

ID = re.compile(rb'(\d+)\s*$')
SWAPS = {('Animation', b'AnimationId'), ('Sound', b'SoundId')}


def swap(src, mapping, out):
    data = open(src, 'rb').read()
    chunks = raw_chunks(data)
    classes = {}
    for name, raw, clen, ulen in chunks:
        if name == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            p = 8 + ln + 1
            count, = struct.unpack_from('<I', body, p)
            refs, _ = rbxl.read_refs(body, p + 4, count)
            classes[cid] = (body[8:8 + ln].decode(), refs)
    swapped, seen = 0, set()
    parts = [data[:32]]
    for name, raw, clen, ulen in chunks:
        if name == b'PROP':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cname, refs = classes[cid]
            if (cname, body[8:8 + ln]) in SWAPS:
                p = 8 + ln
                assert body[p] == 0x01, '%s isn\'t stored as a string here' % body[8:8 + ln].decode()
                p += 1
                new = bytearray(body[:p])
                for _ in refs:
                    l, = struct.unpack_from('<I', body, p)
                    val = body[p + 4:p + 4 + l]
                    p += 4 + l
                    m = ID.search(val)
                    if m and m.group(1).decode() in mapping:
                        seen.add(m.group(1).decode())
                        val = b'rbxassetid://' + mapping[m.group(1).decode()].encode()
                        swapped += 1
                    new += struct.pack('<I', len(val)) + val
                assert p == len(body), 'unexpected trailing bytes in a %s chunk' % cname
                parts.append(pack_chunk(name, bytes(new)))
                continue
        parts.append(raw)
    open(out, 'wb').write(b''.join(parts))
    return swapped, seen


if __name__ == '__main__':
    src, mfile, out = sys.argv[1:4]
    mapping = {str(k): str(v['new'] if isinstance(v, dict) else v) for k, v in json.load(open(mfile, encoding='utf-8')).items()}
    bad = [k for k, v in mapping.items() if not (k.isdigit() and v.isdigit())]
    if bad:
        sys.exit('not an old id -> new id map: ' + ', '.join(bad[:5]))
    n, seen = swap(src, mapping, out)
    print('%d Animations and Sounds swapped (%d of the %d ids in the map are in this place)' % (n, len(seen), len(mapping)))
