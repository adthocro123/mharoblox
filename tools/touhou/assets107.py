# Round 107: Mokou and Remilia from the owner's Touhou place, grafted into
# the round 106 place -> SP/r107/assets107.rbxl (every old instance untouched).
#   1. kit107.rbxl (kit107.luau): the new folders, Bridge, the Knit stand-in
#   2. the Touhou place's things (graft107.json): its effects, animations,
#      models, sounds, lighting effects, and its scripts for the two of them
# Then rbxl_write.py puts every script's source from tools/src in (the ported
# ones from port107.py: no uploader's stamp, the few paths patched).
# The output is checked for shared UniqueIds before it's used.
#   SP=... TARGET=<round 106 place> TOUHOU=<the Touhou place> python3 -I assets107.py
import json
import os
import sys

SP = os.environ['SP']
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'jjba'))
sys.path.insert(0, os.path.join(HERE, '..', 'place'))
import rbxgraft  # noqa: E402
import uniqueids  # noqa: E402

TARGET = os.environ['TARGET']
TOUHOU = os.environ['TOUHOU']
KIT = os.environ.get('KIT', SP + '/r107/kit.rbxl')
MID = SP + '/r107/kit_grafted.rbxl'
OUT = SP + '/r107/assets107.rbxl'
SPEC = json.load(open(os.path.join(HERE, 'graft107.json'), encoding='utf-8'))
EX = ['PackageLink']

os.makedirs(os.path.dirname(OUT), exist_ok=True)
r = rbxgraft.graft(TARGET, MID, KIT, SPEC['kit'], EX, os.path.join(HERE, '..', 'place'))
print('kit graft', r['count'], 'reminted', len(r['reminted']))
r = rbxgraft.graft(MID, OUT, TOUHOU, SPEC['items'], EX, os.path.join(HERE, '..', 'place'), seed=107)
print('graft', r['count'], 'sstr', r['sstr_added'])
print(' new', r['new'])
print(' merged', r['merged'])
print(' defaulted', r['defaulted'], 'dropped', r['dropped'])
print(' reminted', len(r['reminted']))
if uniqueids.scan(OUT, show=20)[0]:
    sys.exit('duplicate UniqueIds in ' + OUT)
