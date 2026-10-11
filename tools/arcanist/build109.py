# Round 109: the Arcanist's 16 clips grafted into the place's
# ReplicatedStorage.Animations (every old instance untouched; rbxl_replace.py
# can't any more: round 107 put KeyframeSequences outside that folder), then
# rbxl_write.py puts every script's source from tools/src in. Checked for
# shared UniqueIds before it's used.
#   SP=<scratch> TARGET=<the place> python3 -I build109.py
import json
import os
import subprocess
import sys

SP = os.environ['SP']
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(HERE, '..')
sys.path.insert(0, os.path.join(TOOLS, 'jjba'))
sys.path.insert(0, os.path.join(TOOLS, 'place'))
import rbxgraft  # noqa: E402
import uniqueids  # noqa: E402

TARGET = os.environ['TARGET']
CLIPS_JSON = SP + '/r109/clips109.json'
SRC_PLACE = SP + '/r109/clips109.rbxl'
MID = SP + '/r109/clips_grafted.rbxl'
OUT = SP + '/r109/build109.rbxl'
os.makedirs(SP + '/r109', exist_ok=True)

anim = os.path.join(TOOLS, 'anim')
subprocess.check_call([sys.executable, 'export.py', CLIPS_JSON, 'moves_arc'], cwd=anim)
subprocess.check_call(['lune', 'run', os.path.join(HERE, 'clips109.luau'), CLIPS_JSON, SRC_PLACE])
names = [c['name'] for c in json.load(open(CLIPS_JSON, encoding='utf-8'))]
items = [('ReplicatedStorage.Arc109.' + n, 'ReplicatedStorage.Animations', None) for n in names]
r = rbxgraft.graft(TARGET, MID, SRC_PLACE, items, ['PackageLink'], os.path.join(TOOLS, 'place'), seed=109)
print('graft', r['count'], 'new', r['new'], 'merged', r['merged'])
env = dict(os.environ, RBXL_PACK='zstd')
subprocess.check_call([sys.executable, 'rbxl_write.py', MID, OUT, os.path.join(TOOLS, 'src')], cwd=os.path.join(TOOLS, 'place'), env=env)
subprocess.check_call([sys.executable, 'rbxl_check.py', OUT], cwd=os.path.join(TOOLS, 'place'))
if uniqueids.scan(OUT, show=20)[0]:
    sys.exit('duplicate UniqueIds in ' + OUT)
print('->', OUT)
