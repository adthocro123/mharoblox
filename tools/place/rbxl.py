import struct, sys, json, os
import lz4.block, zstandard

def read_chunks(data):
    assert data[:8] == b'<roblox!'
    num_classes, num_inst = struct.unpack_from('<II', data, 16)
    pos = 32
    chunks = []
    while pos < len(data):
        name = data[pos:pos+4].rstrip(b'\0').decode()
        clen, ulen, _ = struct.unpack_from('<III', data, pos+4)
        pos += 16
        if clen == 0:
            body = data[pos:pos+ulen]; pos += ulen
        else:
            raw = data[pos:pos+clen]; pos += clen
            if raw[:4] == b'\x28\xb5\x2f\xfd':
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ulen)
        chunks.append((name, body))
        if name == 'END':
            break
    return num_classes, num_inst, chunks

def deinterleave(buf, n, width):
    out = []
    for i in range(n):
        b = bytes(buf[j*n + i] for j in range(width))
        out.append(b)
    return out

def read_refs(body, pos, n):
    raw = deinterleave(body[pos:pos+4*n], n, 4)
    vals, acc = [], 0
    for b in raw:
        u = struct.unpack('>I', b)[0]
        v = (u >> 1) ^ -(u & 1)
        acc += v
        vals.append(acc)
    return vals, pos + 4*n

def parse(path):
    data = open(path, 'rb').read()
    nc, ni, chunks = read_chunks(data)
    classes = {}
    inst = {}
    for name, body in chunks:
        if name == 'INST':
            cid, = struct.unpack_from('<I', body, 0)
            ln, = struct.unpack_from('<I', body, 4)
            cname = body[8:8+ln].decode()
            pos = 8+ln
            is_service = body[pos]; pos += 1
            count, = struct.unpack_from('<I', body, pos); pos += 4
            refs, pos = read_refs(body, pos, count)
            classes[cid] = (cname, refs)
            for r in refs:
                inst[r] = {'class': cname, 'props': {}, 'children': [], 'parent': None}
        elif name == 'PROP':
            cid, = struct.unpack_from('<I', body, 0)
            ln, = struct.unpack_from('<I', body, 4)
            pname = body[8:8+ln].decode()
            pos = 8+ln
            ptype = body[pos]; pos += 1
            cname, refs = classes[cid]
            if ptype in (0x01, 0x1D) and pname in ('Name', 'Source', 'Value', 'Text', 'LinkedSource', 'ScriptGuid'):
                for r in refs:
                    l, = struct.unpack_from('<I', body, pos); pos += 4
                    s = body[pos:pos+l]; pos += l
                    try:
                        s = s.decode('utf-8')
                    except UnicodeDecodeError:
                        s = s.decode('latin-1')
                    inst[r]['props'][pname] = s
            elif ptype == 0x02 and pname in ('Disabled', 'Enabled'):
                for i, r in enumerate(refs):
                    inst[r]['props'][pname] = bool(body[pos+i])
            elif ptype == 0x12 and pname == 'RunContext':
                vals = deinterleave(body[pos:pos+4*len(refs)], len(refs), 4)
                for r, b in zip(refs, vals):
                    inst[r]['props'][pname] = struct.unpack('>I', b)[0]
        elif name == 'PRNT':
            ver = body[0]
            n, = struct.unpack_from('<I', body, 1)
            kids, pos = read_refs(body, 5, n)
            parents, pos = read_refs(body, pos, n)
            for k, p in zip(kids, parents):
                inst[k]['parent'] = p
                if p != -1 and p in inst:
                    inst[p]['children'].append(k)
    return nc, ni, inst

if __name__ == '__main__':
    nc, ni, inst = parse(sys.argv[1])
    print(nc, ni, len(inst))
