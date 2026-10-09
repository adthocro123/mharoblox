# Round 106: the JJBA place's Stand Arrow and Rokakaka fruit (and the Parallel
# Crystal that came with them), the props held in the hand, and the two
# character clips, grafted into the round 105 place -> SP/r106/assets106.rbxl
# (every old instance untouched). TARGET: the round 105 place
# (git show 7a40325:QuirkBattlegrounds_City.rbxl > round105.rbxl).
# (round 107) AnimParts.MetalPart is left out: Round 104 grafted it already
# (ReplicatedStorage.JJBA.MetalPart), and the second copy carried the same
# UniqueIds - Studio wouldn't open the place ("DM contains duplicate Unique
# ids"). The output is checked for any shared UniqueId before it's used.
import sys, os, json
SP = os.environ['SP']
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbxgraft
TARGET = os.environ['TARGET']
JJ = SP + '/up104_jjba/place.rbxl'
OUT = SP + '/r106/assets106.rbxl'
EX = ['Script', 'LocalScript', 'ModuleScript', 'Humanoid', 'Animator', 'AnimationController', 'BodyColors']
A = 'ReplicatedStorage.Animatons.'
# (Moon Animator's own data under each exported pose: the game reads only the poses)
MOON = ['IntValue', 'Folder', 'StringValue', 'NumberValue', 'BoolValue']
items = [
    # the items as they lie on the map (their ProximityPrompts kept; the
    # arrow's own tool script left out) and as they're held in the hand
    ['ReplicatedStorage.Tools', 'ReplicatedStorage.JJBA', 'Items'],
    ['ReplicatedStorage.AnimParts', 'ReplicatedStorage.JJBA', 'Held', ['MetalPart']],
    # the arrow through the chest (the JJBA place's getstand) and the fruit eaten
    [A + 'getstand.UseArrow_Dummy3', 'ReplicatedStorage.Animations', 'MoveStandArrow', MOON],
    [A + 'GenericAnimationXyiation.RokakakaEat.RokakakaEat_Dummy3', 'ReplicatedStorage.Animations', 'MoveRokakakaEat', MOON],
]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
r = rbxgraft.graft(TARGET, OUT, JJ, items, EX, SP)
print('graft', r['count'], 'sstr', r['sstr_added'])
print(' new', r['new'])
print(' merged', r['merged'])
print(' defaulted', r['defaulted'], 'dropped', r['dropped'])
print(' reminted', len(r['reminted']))
sys.path.insert(0, os.path.join(HERE, '..', 'place'))
import uniqueids
if uniqueids.scan(OUT, show=20)[0]:
    sys.exit('duplicate UniqueIds in ' + OUT)
json.dump({'items': items}, open(os.path.join(HERE, 'assets106_items.json'), 'w'), indent=1)
