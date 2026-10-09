# Round 104: the JJBA place's stands, effects and clips grafted into the
# user's final.rbxl -> SP/r104/assets104.rbxl (every old instance untouched)
import sys, os, json
SP = os.environ['SP']
sys.path.insert(0, SP + '/r104')
import rbxgraft
FINAL = SP + '/up104_final104/place.rbxl'
JJ = SP + '/up104_jjba/place.rbxl'
BASE = SP + '/r104/jjba_base.rbxm'
STEP1 = SP + '/r104/assets104a.rbxl'
OUT = SP + '/r104/assets104.rbxl'
EX = ['Script', 'LocalScript', 'ModuleScript', 'Humanoid', 'Animator', 'AnimationController', 'BodyColors']
A = 'ReplicatedStorage.Animatons.'
STAND = ['KeyframeSequence', 'Sound', 'AnimSaves']
# (Moon Animator's own data under each exported pose: the game reads only the poses)
MOON = ['IntValue', 'Folder', 'StringValue', 'NumberValue', 'BoolValue']
items = [
    # the stands (no scripts, no Humanoid, no saved animations or sounds of their own)
    ['ReplicatedStorage.Stands.StarPlatinum.StarPlatinum', 'ReplicatedStorage.JJBA.Stands', 'StarPlatinum', STAND],
    ['ReplicatedStorage.Stands.TheWorld.TheWorld', 'ReplicatedStorage.JJBA.Stands', 'TheWorld', STAND],
    ['ReplicatedStorage.Stands.C_Moon.Cmoon', 'ReplicatedStorage.JJBA.Stands', 'CMoon', STAND],
    ['ReplicatedStorage.Stands.MadeInHeaven.MadeInHeaven', 'ReplicatedStorage.JJBA.Stands', 'MadeInHeaven', STAND],
    # the effects (hit bursts, smoke, wind, the knife, the road roller, the
    # time-stop sphere, C-Moon's and MIH's scenes, the auras)
    ['ReplicatedStorage.Effects', 'ReplicatedStorage.JJBA', 'Effects'],
    ['ReplicatedStorage.AnimParts.MetalPart', 'ReplicatedStorage.JJBA', 'MetalPart'],
]
STAND_CLIPS = [
    ('SPAnims.Standart.Idle.starplatinum_StarPlatinum', 'SP_Idle'),
    ('SPAnims.Standart.Walk.spMove_StarPlatinum', 'SP_Walk'),
    ('SPAnims.StarFinger.StarFinger_StarPlatinum', 'SP_StarFinger'),
    ('SPAnims.StarFingerKnock.StarFingerKnockedOut_StarPlatinum', 'SP_StarFingerKO'),
    ('SPAnims.Oraa.SPPunchHeavy_StarPlatinum', 'SP_Ora'),
    ('SPAnims.StandPose.jojostandpose_StarPlatinum', 'SP_Pose'),
    ('SPAnims.Barrage.SPBarage_Dummy3', 'SP_Barrage'),
    ('TWAnims.Standart.Idle.DioIdle_TheWorld', 'TW_Idle'),
    ('TWAnims.Standart.Walk.Diomove_TheWorld', 'TW_Walk'),
    ('TWAnims.MudaMuda.mudaaaa', 'TW_Barrage'),
    ('TWAnims.Knives.DioThrowKnives_TheWorld', 'TW_Knives'),
    ('MIHAnims.Standart.Idle.MIHidle_MadeInHeaven', 'MIH_Idle'),
    ('MIHAnims.Standart.Walk.MoveMIH_MadeInHeaven', 'MIH_Walk'),
    ('MIHAnims.MIHBarrage.MIHBarrage_MadeInHeaven', 'MIH_Barrage'),
    ('MIHAnims.MIHHeavyPunch.MIHHeavyPunch_MadeInHeaven', 'MIH_Heavy'),
    ('CmoonAnims.Standart.Idle.C_Moon_Idle_Cmoon_Rig', 'CM_Idle'),
    ('CmoonAnims.CenterGravity.CenterGravity_Cmoon_Rig', 'CM_CenterGravity'),
]
for src, name in STAND_CLIPS:
    items.append([A + src, 'ReplicatedStorage.JJBA.Clips', name, MOON])
items.append(['ReplicatedStorage.Stands.TheWorld.TheWorld.AnimSaves.knives stand', 'ReplicatedStorage.JJBA.Clips', 'TW_KnivesStand', MOON])
CHAR_CLIPS = [
    ('SPAnims.JotaroTimeStop.JotaroTimeStop_Dummy3', 'MoveJotaroTimeStop'),
    ('SPAnims.Pose.JotaroPose_Dummy3', 'PoseJotaroPose'),
    ('TWAnims.TimeStop.TimeStop_Dummy3', 'PoseZaWarudo'),
    ('TWAnims.Pose.DioPose_Dummy3', 'PoseDioPose'),
    ('TWAnims.ThrowKnive.ThrowKnife_Dummy3', 'MoveDioKnives'),
    ('TWAnims.steelattackstart.steelattackstart_Dummy3', 'MoveVampireStart'),
    ('TWAnims.steelattackidle.steelattackidle_Dummy3', 'PoseVampireHold'),
    ('TWAnims.Steelattackend.steelattackend_Dummy3', 'MoveVampireEnd'),
    ('Dioroadrollerstart.RoadRollerStart_Dummy3', 'MoveRoadRollerStart'),
    ('Dioroadrollerend.Dioroadrollerend_Dummy3', 'MoveRoadRollerEnd'),
    ('MIHAnims.PucciThrowKnifes.PucciThrowknives_Dummy', 'MovePucciKnives1'),
    ('MIHAnims.PucciThrowKnifes2.PucciThrowKnifes2_Dummy', 'MovePucciKnives2'),
    ('MIHAnims.PucciThrowKnifes3.PucciThrowKnifes3_Dummy', 'MovePucciKnives3'),
    ('CmoonAnims.GravityFreeze.GravityFreeze_Pucci_Dummy3', 'MoveGravityFreeze'),
    ('CmoonAnims.GravityFreeze_Hit.GravityFreeze_HIT_Dummy3', 'PoseGravityPinned'),
    ('CmoonAnims.Evolve_Cmoon_Idle.Evolve_Cmoon_Idle_Dummy3', 'PoseCMoonEvolve'),
    ('POMAnims.Fistattack.POMfirstattacK_Dummy', 'MovePOMFist'),
    ('POMAnims.HeavyAttackStart.POMHeavyAttackstart_Dummy', 'MovePOMHeavyStart'),
    ('POMAnims.HeavyAttack.POMHEAVYATTACK_Dummy', 'MovePOMHeavy'),
    ('POMAnims.VoidBall.POMvoidBall_Dummy', 'MovePOMVoidBall'),
]
for src, name in CHAR_CLIPS:
    items.append([A + src, 'ReplicatedStorage.Animations', name, MOON])

r1 = rbxgraft.graft(FINAL, STEP1, BASE, [['JJBA', 'ReplicatedStorage', None]], EX, SP)
print('pass 1', r1['count'], 'new', r1['new'], 'merged', r1['merged'])
r2 = rbxgraft.graft(STEP1, OUT, JJ, items, EX, SP)
print('pass 2', r2['count'], 'sstr', r2['sstr_added'])
print(' new', r2['new'])
print(' merged', r2['merged'])
print(' defaulted', r2['defaulted'], 'dropped', r2['dropped'])
json.dump({'items': items}, open(SP + '/r104/assets104_items.json', 'w'), indent=1)
