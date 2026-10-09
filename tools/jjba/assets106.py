# Round 106: the JJBA place's Stand Arrow and Rokakaka fruit (and the Parallel
# Crystal that came with them), the props held in the hand, and the two
# character clips, grafted into the round 105 place -> SP/r106/assets106.rbxl
# (every old instance untouched)
import sys, os, json
SP = os.environ['SP']
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbxgraft
TARGET = os.environ.get('TARGET') or os.path.join(HERE, '..', '..', 'QuirkBattlegrounds_City.rbxl')
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
    ['ReplicatedStorage.AnimParts', 'ReplicatedStorage.JJBA', 'Held'],
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
json.dump({'items': items}, open(os.path.join(HERE, 'assets106_items.json'), 'w'), indent=1)
