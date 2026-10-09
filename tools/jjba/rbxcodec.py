"""Per-instance codec for binary Roblox PROP chunks.

split(ptype, data, n) -> list of n per-instance values (opaque bytes for most
types; ints for Ref (absolute referents) and SharedString (indices)).
join(ptype, values) -> the PROP chunk's value bytes again.

join(split(x)) == x for every chunk is the codec's own test (selftest()).
"""
import struct


def deint(buf, n, width):
    return [bytes(buf[j * n + i] for j in range(width)) for i in range(n)]


def inter(vals, width):
    n = len(vals)
    out = bytearray(n * width)
    for i, b in enumerate(vals):
        assert len(b) == width, (len(b), width)
        for j in range(width):
            out[j * n + i] = b[j]
    return bytes(out)


def _zz_dec(u):
    return (u >> 1) ^ -(u & 1)


def _zz_enc(v):
    return ((v << 1) ^ (v >> 31)) & 0xffffffff


def _strings(data, n, p=0):
    out = []
    for _ in range(n):
        l, = struct.unpack_from('<I', data, p)
        out.append(data[p:p + 4 + l])
        p += 4 + l
    return out, p


def _cframes(data, n, p=0):
    rots = []
    for _ in range(n):
        k = data[p]
        if k == 0:
            rots.append(data[p:p + 37])
            p += 37
        else:
            rots.append(data[p:p + 1])
            p += 1
    xs = deint(data[p:p + 4 * n], n, 4); p += 4 * n
    ys = deint(data[p:p + 4 * n], n, 4); p += 4 * n
    zs = deint(data[p:p + 4 * n], n, 4); p += 4 * n
    return [r + x + y + z for r, x, y, z in zip(rots, xs, ys, zs)], p


def _cframes_join(vals):
    rots, xs, ys, zs = [], [], [], []
    for v in vals:
        r, pos = v[:-12], v[-12:]
        rots.append(r)
        xs.append(pos[0:4]); ys.append(pos[4:8]); zs.append(pos[8:12])
    return b''.join(rots) + inter(xs, 4) + inter(ys, 4) + inter(zs, 4)


FIXED = {0x02: 1, 0x09: 1, 0x0A: 1, 0x05: 8, 0x08: 24, 0x14: 6, 0x17: 8}
INTER = {0x03: 4, 0x04: 4, 0x0B: 4, 0x12: 4, 0x1B: 8, 0x21: 8, 0x1F: 16}
MULTI = {0x06: (4, 4), 0x07: (4, 4, 4, 4), 0x0C: (4, 4, 4), 0x0D: (4, 4), 0x0E: (4, 4, 4), 0x18: (4, 4, 4, 4)}


def split(t, data, n):
    if t in (0x01, 0x1D):
        vals, p = _strings(data, n)
    elif t in FIXED:
        w = FIXED[t]
        vals, p = [data[i * w:(i + 1) * w] for i in range(n)], n * w
    elif t in INTER:
        w = INTER[t]
        vals, p = deint(data, n, w), n * w
    elif t in MULTI:
        cols, p = [], 0
        for w in MULTI[t]:
            cols.append(deint(data[p:p + n * w], n, w))
            p += n * w
        vals = [b''.join(c[i] for c in cols) for i in range(n)]
    elif t == 0x1A:
        r, g, b = data[0:n], data[n:2 * n], data[2 * n:3 * n]
        vals, p = [bytes((r[i], g[i], b[i])) for i in range(n)], 3 * n
    elif t == 0x10:
        vals, p = _cframes(data, n)
    elif t == 0x1E:
        assert data[0] == 0x10
        cfs, p = _cframes(data, n, 1)
        assert data[p] == 0x02
        p += 1
        vals = [cf + data[p + i:p + i + 1] for i, cf in enumerate(cfs)]
        p += n
    elif t == 0x13:
        raw = deint(data, n, 4)
        acc, vals = 0, []
        for b in raw:
            acc += _zz_dec(struct.unpack('>I', b)[0])
            vals.append(acc)
        p = 4 * n
    elif t == 0x1C:
        vals, p = [struct.unpack('>I', b)[0] for b in deint(data, n, 4)], 4 * n
    elif t == 0x15 or t == 0x16:
        w = 12 if t == 0x15 else 20
        vals, p = [], 0
        for _ in range(n):
            c, = struct.unpack_from('<I', data, p)
            vals.append(data[p:p + 4 + c * w])
            p += 4 + c * w
    elif t == 0x19:
        vals, p = [], 0
        for _ in range(n):
            f = data[p]
            ln = 1
            if f & 1:
                ln += 20
                if f & 2:
                    ln += 4
            vals.append(data[p:p + ln])
            p += ln
    elif t == 0x20:
        vals, p = [], 0
        for _ in range(n):
            q = p
            l, = struct.unpack_from('<I', data, q); q += 4 + l
            q += 3
            l, = struct.unpack_from('<I', data, q); q += 4 + l
            vals.append(data[p:q])
            p = q
    elif t == 0x22:
        kinds = deint(data, n, 4)
        p = 4 * n
        trailer = data[p:]
        assert trailer == b'\0' * 12, ('Content with sources not supported', trailer[:16].hex())
        assert all(k == b'\0\0\0\0' for k in kinds), 'Content with sources not supported'
        vals = kinds
        p = len(data)
    else:
        raise ValueError('unsupported property type 0x%02x' % t)
    assert p == len(data), ('trailing bytes', hex(t), p, len(data))
    return vals


def join(t, vals):
    n = len(vals)
    if t in (0x01, 0x1D) or t in FIXED or t in (0x15, 0x16, 0x19, 0x20):
        return b''.join(vals)
    if t in INTER:
        return inter(vals, INTER[t])
    if t in MULTI:
        out, o = b'', 0
        for w in MULTI[t]:
            out += inter([v[o:o + w] for v in vals], w)
            o += w
        return out
    if t == 0x1A:
        return bytes(v[0] for v in vals) + bytes(v[1] for v in vals) + bytes(v[2] for v in vals)
    if t == 0x10:
        return _cframes_join(vals)
    if t == 0x1E:
        return b'\x10' + _cframes_join([v[:-1] for v in vals]) + b'\x02' + bytes(v[-1] for v in vals)
    if t == 0x13:
        out, prev = [], 0
        for v in vals:
            out.append(struct.pack('>I', _zz_enc(v - prev)))
            prev = v
        return inter(out, 4)
    if t == 0x1C:
        return inter([struct.pack('>I', v) for v in vals], 4)
    if t == 0x22:
        return inter(vals, 4) + b'\0' * 12
    raise ValueError('unsupported property type 0x%02x' % t)


def selftest(path, rbxl_dir):
    import sys
    sys.path.insert(0, rbxl_dir)
    from rbxl import read_chunks
    data = open(path, 'rb').read()
    nc, ni, chunks = read_chunks(data)
    counts = {}
    for name, body in chunks:
        if name == 'INST':
            cid, ln = struct.unpack_from('<II', body, 0)
            counts[cid] = struct.unpack_from('<I', body, 8 + ln + 1)[0]
    ok = bad = 0
    seen = set()
    for name, body in chunks:
        if name != 'PROP':
            continue
        cid, ln = struct.unpack_from('<II', body, 0)
        t = body[8 + ln]
        raw = body[9 + ln:]
        try:
            vals = split(t, raw, counts[cid])
            assert join(t, vals) == raw
            ok += 1
            seen.add(t)
        except Exception as e:
            bad += 1
            print('FAIL', body[8:8 + ln], hex(t), e)
    print(path.split('/')[-2], 'round-trip ok', ok, 'bad', bad, 'types', sorted(hex(x) for x in seen))
    return bad == 0


if __name__ == '__main__':
    import sys
    good = all(selftest(p, sys.argv[1]) for p in sys.argv[2:])
    sys.exit(0 if good else 1)
