"""Write every clip as JSON (what the KeyframeSequences are built from):
python3 export.py out.json module [module ...]"""
import json, sys, importlib
import rig
data = []
for m in sys.argv[2:]:
    mod = importlib.import_module(m)
    data += [rig.to_json(mod.CLIPS[n]) for n in mod.ORDER]
names = [c['name'] for c in data]
assert len(names) == len(set(names)), 'duplicate clip names'
json.dump(data, open(sys.argv[1], 'w'))
print(sys.argv[1], len(data), 'clips', sum(len(c['keys']) for c in data), 'keys')
