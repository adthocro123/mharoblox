"""Replace script Source strings inside a binary .rbxl, leaving every other
chunk byte-identical. Usage: rbxl_write.py in.rbxl out.rbxl srcdir
srcdir holds files named by full instance path (as dump.py writes them)."""
import struct, sys, os
import lz4.block, zstandard
import rbxl

EXT = {'Script': '.server.lua', 'LocalScript': '.client.lua', 'ModuleScript': '.lua'}


def raw_chunks(data):
    pos = 32
    out = []
    while pos < len(data):
        name = data[pos:pos + 4]
        clen, ulen, res = struct.unpack_from('<III', data, pos + 4)
        size = clen if clen else ulen
        out.append((name, data[pos:pos + 16 + size], clen, ulen))
        pos += 16 + size
        if name.rstrip(b'\0') == b'END':
            break
    return out


def decompress(raw, clen, ulen):
    body = raw[16:]
    if clen == 0:
        return body
    if body[:4] == b'\x28\xb5\x2f\xfd':
        return zstandard.ZstdDecompressor().decompress(body, max_output_size=ulen)
    return lz4.block.decompress(body, uncompressed_size=ulen)


# How chunks written here are compressed: 'lz4' (older Studio saves) or
# 'zstd' (what Studio writes now) - match the place being edited
# (RBXL_PACK=zstd), so a place never mixes the two.
PACK = os.environ.get('RBXL_PACK', 'lz4')


def pack_chunk(name, body):
    if PACK == 'zstd':
        comp = zstandard.ZstdCompressor(level=3, write_content_size=True, write_checksum=False).compress(body)
    else:
        comp = lz4.block.compress(body, store_size=False)
    return name + struct.pack('<III', len(comp), len(body), 0) + comp


def _deinterleave(buf, n, width):
    return [bytes(buf[j * n + i] for j in range(width)) for i in range(n)]


def _interleave(vals, width):
    n = len(vals)
    out = bytearray(n * width)
    for i, b in enumerate(vals):
        for j in range(width):
            out[j * n + i] = b[j]
    return bytes(out)


def _enc_float(f):
    u, = struct.unpack('>I', struct.pack('>f', f))
    return struct.pack('>I', ((u << 1) | (u >> 31)) & 0xffffffff)


def _dec_float(b):
    u, = struct.unpack('>I', b)
    u = ((u >> 1) | (u << 31)) & 0xffffffff
    return struct.unpack('>f', struct.pack('>I', u))[0]


# Property patches applied on top of the script sources:
#   (class, property, fn(ref, inst) -> new value or None to keep)
# enum (0x12) values are ints, float (0x04) values are floats, bool (0x02)
# values are bools.
PATCHES = [
    # the movement pack's custom shift lock owns Shift; Roblox's built-in one
    # (on for anyone whose Shift Lock Switch setting is on) would take it first
    ('StarterPlayer', 'EnableMouseLockOption', lambda r, inst: False),
    # keep Motor6D character joints: every pose, ragdoll and the movement pack
    # works on Motor6Ds (Roblox's Avatar Joint Upgrade turns "Default" into
    # AnimationConstraints on live servers). RolloutState.Disabled = 1
    ('StarterPlayer', 'AvatarJointUpgrade_SerializedRollout', lambda r, inst: 1),
    # invisible spawn pads (and their decals)
    ('SpawnLocation', 'Transparency', lambda r, inst: 1.0),
    ('Decal', 'Transparency', lambda r, inst: 1.0 if inst.get(inst[r]['parent'], {}).get('class') == 'SpawnLocation' else None),
]


def write(src_path, out_path, srcdir):
    data = open(src_path, 'rb').read()
    _, _, inst = rbxl.parse(src_path)

    def path(r):
        p = []
        while r != -1 and r in inst:
            p.append(inst[r]['props'].get('Name', '?'))
            r = inst[r]['parent']
        return '.'.join(reversed(p))

    chunks = raw_chunks(data)
    classes = {}
    for name, raw, clen, ulen in chunks:
        if name == b'INST':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            cname = body[8:8 + ln].decode()
            p = 8 + ln + 1
            count, = struct.unpack_from('<I', body, p)
            refs, _ = rbxl.read_refs(body, p + 4, count)
            classes[cid] = (cname, refs)

    changed = []
    out = [data[:32]]
    for name, raw, clen, ulen in chunks:
        if name == b'PROP':
            body = decompress(raw, clen, ulen)
            cid, ln = struct.unpack_from('<II', body, 0)
            pname = body[8:8 + ln].decode()
            cname, refs = classes[cid]
            if pname == 'Source' and cname in EXT:
                p = 8 + ln
                ptype = body[p]
                p += 1
                values = []
                for r in refs:
                    l, = struct.unpack_from('<I', body, p)
                    values.append(body[p + 4:p + 4 + l])
                    p += 4 + l
                assert p == len(body), 'unexpected trailing bytes in Source chunk'
                new = bytearray(body[:8 + ln + 1])
                for r, old in zip(refs, values):
                    f = os.path.join(srcdir, path(r) + EXT[cname])
                    val = old
                    if os.path.exists(f):
                        val = open(f, 'rb').read()
                        if val != old:
                            changed.append(path(r))
                    new += struct.pack('<I', len(val)) + val
                out.append(pack_chunk(name, bytes(new)))
                continue
            patch = [fn for (pc, pp, fn) in PATCHES if pc == cname and pp == pname]
            if patch:
                p = 8 + ln
                ptype = body[p]
                n = len(refs)
                if ptype == 0x02:
                    assert p + 1 + n == len(body), 'unexpected property chunk size'
                    vals = [body[p + 1 + i:p + 2 + i] for i in range(n)]
                    edits = 0
                    for i, r in enumerate(refs):
                        v = patch[0](r, inst)
                        if v is not None and bytes([1 if v else 0]) != vals[i]:
                            vals[i] = bytes([1 if v else 0])
                            edits += 1
                    if edits:
                        changed.append('%s.%s x%d' % (cname, pname, edits))
                        out.append(pack_chunk(name, body[:p + 1] + b''.join(vals)))
                        continue
                    out.append(raw)
                    continue
                vals = _deinterleave(body[p + 1:p + 1 + 4 * n], n, 4)
                assert p + 1 + 4 * n == len(body), 'unexpected property chunk size'
                edits = 0
                for i, r in enumerate(refs):
                    v = patch[0](r, inst)
                    if v is None:
                        continue
                    if ptype == 0x12:
                        b = struct.pack('>I', int(v))
                    elif ptype == 0x04:
                        b = _enc_float(float(v))
                    else:
                        raise ValueError('unsupported property type 0x%02x for %s.%s' % (ptype, cname, pname))
                    if b != vals[i]:
                        vals[i] = b
                        edits += 1
                if edits:
                    changed.append('%s.%s x%d' % (cname, pname, edits))
                    out.append(pack_chunk(name, body[:p + 1] + _interleave(vals, 4)))
                    continue
        out.append(raw)
    open(out_path, 'wb').write(b''.join(out))
    return changed


if __name__ == '__main__':
    print('changed:', write(sys.argv[1], sys.argv[2], sys.argv[3]))
