"""uniqueids.py <place.rbxl> [...]: every UniqueId-typed property (UniqueId,
HistoryId) in a binary place, and any value two instances share - Studio
won't open a place with a duplicate UniqueId ("DM contains duplicate Unique
ids"). Exit 1 if there are any."""
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'jjba'))
import rbxgraft  # noqa


def scan(path, show=12):
    rbxl, raw_chunks, decompress = rbxgraft._load_helpers(HERE)
    P = rbxgraft.Place(path, rbxl, raw_chunks, decompress)
    bad = 0
    for pname in ('UniqueId', 'HistoryId'):
        seen = defaultdict(list)
        for cid, c in P.classes.items():
            t, vals = P.prop_values(cid, pname)
            if t is None:
                continue
            for r, v in zip(c['refs'], vals):
                if v != bytes(16):
                    seen[v].append(r)
        dups = {v: rs for v, rs in seen.items() if len(rs) > 1}
        n = sum(len(rs) for rs in dups.values())
        print('%s: %s values, %d shared by %d instances' % (os.path.basename(path), pname, len(dups), n))
        # (HistoryId repeats are Studio's own, in places that open fine: only counted)
        for v, rs in list(dups.items())[:show] if pname == 'UniqueId' else []:
            print('   ', v.hex(), '|', ' & '.join(P.path(r) for r in rs))
        if pname == 'UniqueId':
            bad += len(dups)
    return bad, P


if __name__ == '__main__':
    total = 0
    for f in sys.argv[1:]:
        total += scan(f)[0]
    sys.exit(1 if total else 0)
