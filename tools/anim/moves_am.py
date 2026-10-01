"""ALL MIGHT and BAKUGO (round 63): the moves as keyframed clips. Each
"Move<name>" clip keeps its motion's timing (the strike lands when the move's
blast does) - anticipation, a snap into the strike ("Hit"), an overshoot,
the held contact, a follow-through, the settle - feet planted, the weight
thrown onto the front foot."""
from moves_lib import P, merge, REST, STANCE, blend, over, seq, OUT, IN, INOUT, LIN
import rig

CLIPS = {}

# ---------------------------------------------------------------- ALL MIGHT
# DETROIT SMASH: sunk into a wide stance, the right fist drawn right back
# behind the hip and trembling, the left arm aimed at them; then the hips,
# chest and shoulder unwind in that order and the fist goes out level -
# the rear leg driving it, the left arm yanked back - held while the wind
# pressure tears down the street
D_COIL = P(body=dict(y=-0.46, twist=-56, lean=4, fwd=-0.22, tilt=6), ra=(-56, -8, 30), la=(88, -18, 8),
           rl=dict(f=-1.3, s=0.45, turn=24), ll=dict(f=0.95, s=0.15))
D_DEEP = merge(D_COIL, body=dict(y=-0.54, twist=-63, lean=6, fwd=-0.3, tilt=7), ra=(-64, -8, 34), la=(92, -20, 8))
D_HIT = P(body=dict(y=-0.52, twist=48, lean=22, fwd=0.72, tilt=-4), ra=(93, 6, 0), la=(-34, 4, 38),
          rl=dict(f=-1.55, s=0.35), ll=dict(f=1.25, s=0.1))
D_FOLLOW = P(body=dict(y=-0.28, twist=18, lean=9, fwd=0.25), ra=(70, 22, 6), la=(18, 10, 22), rl=dict(f=-0.85, s=0.3), ll=dict(f=0.75, s=0.12))
CLIPS['MoveDetroitSmash'] = seq('MoveDetroitSmash', [
    (0.0, REST, OUT),
    (0.12, D_COIL, OUT),
    (0.34, D_DEEP, IN),
    (0.395, over(D_DEEP, D_HIT, 0.1), OUT, 'Hit'),
    (0.47, D_HIT, INOUT),
    (0.8, merge(D_HIT, body=dict(y=-0.49, twist=45, lean=20, fwd=0.66, tilt=-3)), INOUT),
    (1.0, D_FOLLOW, INOUT),
    (1.18, REST, INOUT),
])

# NEW HAMPSHIRE SMASH: sunk low, both fists cocked at the hips... then flat
# out through the air like a missile, both fists leading
NH_COIL = P(body=dict(y=-0.62, lean=30, fwd=-0.1), ra=(-42, 0, 22), la=(-42, 0, 22), rl=dict(f=-0.9, s=0.5), ll=dict(f=0.6, s=0.4), head=(-20, 0, 0))
NH_FLY = P(body=dict(pivot='center', legs='chest', lean=80, y=0.1), ra=(172, 8, 4), la=(172, 8, 4), rl=(-4, 0, 6), ll=(6, 0, 8), head=(-50, 0, 0))
CLIPS['MoveNewHampshire'] = seq('MoveNewHampshire', [
    (0.0, REST, OUT),
    (0.1, NH_COIL, OUT),
    (0.24, merge(NH_COIL, body=dict(y=-0.72, lean=34, fwd=-0.14)), IN),
    (0.3, over(NH_COIL, NH_FLY, 0.06), OUT, 'Hit'),
    (0.38, NH_FLY, INOUT),
    (0.66, merge(NH_FLY, body=dict(pivot='center', legs='chest', lean=76, y=0.1), rl=(-10, 0, 8), ll=(10, 0, 10)), INOUT),
    (0.8, merge(STANCE, body=dict(y=-0.5, lean=22), ra=(40, 0, 30), la=(40, 0, 30), rl=dict(f=-0.6, s=0.5), ll=dict(f=0.7, s=0.4)), OUT),
    (0.98, REST, INOUT),
])

# BACKDROP DRIVER: arms locked round them, then he arches right back over
# his heels - hips thrust up, head to the street behind him - and drives
# them in
BD_WRAP = P(body=dict(y=-0.42, lean=16, fwd=0.2), ra=(72, 44, 0), la=(72, 44, 0), rl=dict(f=-0.5, s=0.5), ll=dict(f=0.6, s=0.45))
BD_ARCH = P(body=dict(y=0.1, lean=-80, fwd=0.2), ra=(158, 22, 0), la=(158, 22, 0), rl=dict(f=0.45, s=0.5), ll=dict(f=0.45, s=0.45), head=(-30, 0, 0))
BD_DRIVE = P(body=dict(y=-0.25, lean=-148, fwd=0.3), ra=(174, 12, 0), la=(174, 12, 0), rl=dict(f=0.7, s=0.5), ll=dict(f=0.7, s=0.45), head=(-35, 0, 0))
CLIPS['MoveSuplex'] = seq('MoveSuplex', [
    (0.0, REST, OUT),
    (0.08, BD_WRAP, OUT),
    (0.14, merge(BD_WRAP, body=dict(y=-0.5, lean=20, fwd=0.22)), IN),
    (0.4, BD_ARCH, LIN),
    (0.6, over(BD_ARCH, BD_DRIVE, 0.05), OUT, 'Hit'),
    (0.7, BD_DRIVE, INOUT),
    (0.95, blend(BD_DRIVE, BD_WRAP, 0.6), INOUT),
    (1.2, merge(STANCE, body=dict(y=-0.3, lean=8)), INOUT),
    (1.4, REST, INOUT),
])

# WEATHER CHANGER: sunk low with the fist wound down by his knee... then
# straight up, rising onto his toes, the whole body behind it
WC_COIL = P(body=dict(y=-0.78, lean=30, twist=-36, tilt=12), ra=(-18, 12, 10), la=(72, 22, 10), rl=dict(f=-0.9, s=0.5), ll=dict(f=0.8, s=0.35))
WC_HIT = P(body=dict(y=0.22, lean=-12, twist=26, tilt=-10), ra=(178, 4, 0), la=(-30, 0, 36), rl=dict(f=-0.55, s=0.3), ll=dict(f=0.35, s=0.2), head=(28, 0, 0))
CLIPS['MoveSkyUppercut'] = seq('MoveSkyUppercut', [
    (0.0, REST, OUT),
    (0.12, WC_COIL, OUT),
    (0.45, merge(WC_COIL, body=dict(y=-0.86, lean=33, twist=-40, tilt=13), ra=(-24, 12, 10)), IN),
    (0.5, over(WC_COIL, WC_HIT, 0.08), OUT, 'Hit'),
    (0.58, WC_HIT, INOUT),
    (1.1, merge(WC_HIT, body=dict(y=0.16, lean=-10, twist=22, tilt=-8)), INOUT),
    (1.3, blend(WC_HIT, REST, 0.6), INOUT),
    (1.45, REST, INOUT),
])

# UNITED STATES OF SMASH: the right fist cocked high with everything he has
# left; the feint with the broken left; then the overhand right, driven
# down and through
US_COCK = P(body=dict(y=-0.22, twist=-36, lean=-8, tilt=8), ra=(162, -12, 30), la=(60, 22, 10), rl=dict(f=-1.05, s=0.4), ll=dict(f=0.85, s=0.2))
US_FEINT = merge(US_COCK, body=dict(y=-0.25, twist=-12, lean=4, tilt=5), la=(96, 4, 0))
US_HIT = P(body=dict(y=-0.58, twist=40, lean=38, fwd=0.62, tilt=-8), ra=(52, 14, 0), la=(-36, 0, 30), rl=dict(f=-1.55, s=0.35), ll=dict(f=1.3, s=0.1))
CLIPS['MoveUnitedStatesSmash'] = seq('MoveUnitedStatesSmash', [
    (0.0, REST, OUT),
    (0.2, US_COCK, OUT),
    (0.55, merge(US_COCK, body=dict(y=-0.28, twist=-40, lean=-10, tilt=9), ra=(168, -12, 32)), INOUT),
    (0.67, US_FEINT, OUT),
    (0.87, US_FEINT, IN),
    (0.93, over(US_FEINT, US_HIT, 0.08), OUT, 'Hit'),
    (1.02, US_HIT, INOUT),
    (1.63, merge(US_HIT, body=dict(y=-0.55, twist=37, lean=35, fwd=0.58, tilt=-7)), INOUT),
    (1.85, blend(US_HIT, REST, 0.6), INOUT),
    (2.05, REST, INOUT),
])
# YOU'RE NEXT: the finger at them
CLIPS['MoveYoureNext'] = seq('MoveYoureNext', [
    (0.0, REST, OUT),
    (0.15, P(body=dict(twist=16, lean=-4), ra=(92, -10, 0), la=(18, 0, 36), head=(-8, -10, 6), rl=dict(f=-0.2, s=0.35), ll=dict(f=0.25, s=0.3)), OUT, 'Hit'),
    (1.45, P(body=dict(twist=14, lean=-3), ra=(90, -10, 0), la=(18, 0, 36), head=(-8, -10, 6), rl=dict(f=-0.2, s=0.35), ll=dict(f=0.25, s=0.3)), INOUT),
    (1.75, REST, INOUT),
])
# COLORADO SMASH: down on one knee, springing up tucked, then the fist
# raised over his head as he comes down on them
CO_KNEEL = P(body=dict(y=-1.1, lean=26), ra=(30, 0, 30), la=(30, 0, 30), rl=dict(f=-0.9, s=0.35), ll=dict(f=0.8, s=0.3))
CO_TUCK = P(body=dict(pivot='center', legs='chest', lean=24), ra=(100, 34, 0), la=(100, 34, 0), rl=(108, 0, 8), ll=(100, 0, 10), head=(-12, 0, 0))
CO_RAISE = P(body=dict(pivot='center', legs='chest', lean=-12), ra=(174, 0, 8), la=(150, 0, 26), rl=(24, 0, 8), ll=(-8, 0, 8))
CLIPS['MoveColoradoSmash'] = seq('MoveColoradoSmash', [
    (0.0, REST, OUT),
    (0.1, CO_KNEEL, OUT),
    (0.3, merge(CO_KNEEL, body=dict(y=-1.2, lean=30)), IN),
    (0.4, CO_TUCK, OUT),
    (1.05, merge(CO_TUCK, body=dict(pivot='center', legs='chest', lean=30)), INOUT),
    (1.2, over(CO_TUCK, CO_RAISE, 0.06), OUT, 'Hit'),
    (1.9, CO_RAISE, INOUT),
    (2.15, REST, INOUT),
])
# MUSCLE FORM: out of the steam - a front double biceps, then hunched into
# a most-muscular, all of him straining
FX1 = P(body=dict(y=-0.1, lean=-6), ra=(40, -20, 84), la=(40, -20, 84), head=(10, 0, 0), rl=dict(f=0, s=0.55), ll=dict(f=0, s=0.55))
FX2 = P(body=dict(y=-0.42, lean=22), ra=(40, 52, 6), la=(40, 52, 6), head=(-14, 0, 0), rl=dict(f=-0.2, s=0.65), ll=dict(f=0.25, s=0.6))
CLIPS['MoveFlex'] = seq('MoveFlex', [
    (0.0, REST, OUT),
    (0.1, over(REST, FX1, 0.1), OUT),
    (0.2, FX1, INOUT),
    (0.85, merge(FX1, ra=(44, -22, 86), la=(44, -22, 86)), INOUT),
    (0.93, over(FX1, FX2, 0.08), OUT, 'Hit'),
    (1.02, FX2, INOUT),
    (1.53, merge(FX2, body=dict(y=-0.46, lean=24)), INOUT),
    (1.8, REST, INOUT),
])

# ---------------------------------------------------------------- BAKUGO
# ERUPTION ORBIT's opening: dropped into a crouch, the palm slammed into
# the street
ER_UP = P(body=dict(y=-0.2, lean=-10), ra=(150, 0, 12), la=(-30, 0, 24), rl=dict(f=-0.35, s=0.4), ll=dict(f=0.35, s=0.35))
ER_DOWN = P(body=dict(y=-1.1, lean=44, fwd=0.25), ra=(52, 6, -4), la=(-40, 0, 32), rl=dict(f=-0.7, s=0.55), ll=dict(f=0.75, s=0.45))
CLIPS['MoveEruptionSlam'] = seq('MoveEruptionSlam', [
    (0.0, REST, OUT),
    (0.1, ER_UP, OUT),
    (0.16, merge(ER_UP, ra=(160, 0, 12)), IN),
    (0.23, over(ER_UP, ER_DOWN, 0.08), OUT, 'Hit'),
    (0.3, ER_DOWN, INOUT),
    (0.35, ER_DOWN, INOUT),
    (0.55, blend(ER_DOWN, REST, 0.55), INOUT),
    (0.7, REST, INOUT),
])
# HOWITZER IMPACT's launch: crouched with both palms back, then up and
# spinning, arms flung up and out
HW_CROUCH = P(body=dict(y=-0.7, lean=30), ra=(-62, 0, 30), la=(-62, 0, 30), rl=dict(f=-0.5, s=0.5), ll=dict(f=0.5, s=0.45))
HW_UP = P(body=dict(pivot='center', legs='chest', lean=-8), ra=(150, -20, 40), la=(150, -20, 40), rl=(10, 0, 10), ll=(-6, 0, 10), head=(20, 0, 0))
CLIPS['MoveHowitzer'] = seq('MoveHowitzer', [
    (0.0, REST, OUT),
    (0.1, HW_CROUCH, OUT),
    (0.14, merge(HW_CROUCH, body=dict(y=-0.78, lean=34)), IN),
    (0.22, over(HW_CROUCH, HW_UP, 0.08), OUT, 'Hit'),
    (0.3, HW_UP, INOUT),
    (0.77, merge(HW_UP, ra=(160, -24, 44), la=(160, -24, 44)), INOUT),
    (1.0, REST, INOUT),
])

# FULL-BODY CLUSTER (his last stand, chapter 362): the walk - beaten half to
# death, head down and hunched, one arm hanging, and calm
WALK_A = P(body=dict(y=-0.14, lean=12, tilt=4), ra=(8, 0, 12), la=(-6, 0, 8), head=(-18, 0, 4), rl=dict(f=0.55, s=0.3), ll=dict(f=-0.45, s=0.25))
WALK_B = P(body=dict(y=-0.08, lean=11, tilt=-3), ra=(-8, 0, 12), la=(8, 0, 8), head=(-14, 0, -2), rl=dict(f=-0.45, s=0.3), ll=dict(f=0.55, s=0.25))
CLIPS['LastStandWalk'] = seq('LastStandWalk', [
    (0.0, blend(REST, WALK_A, 0.6), OUT),
    (0.22, WALK_A, INOUT),
    (0.45, WALK_B, INOUT),
    (0.68, WALK_A, INOUT),
    (0.9, merge(WALK_B, head=(-4, 0, 0), body=dict(y=-0.25, lean=16)), INOUT),
])
# the palm, point blank in their face: the whole arm driven into it
PALM = P(body=dict(y=-0.3, twist=40, lean=18, fwd=0.5), ra=(100, 6, 0, 90), la=(-30, 0, 30), rl=dict(f=-1.2, s=0.35), ll=dict(f=0.9, s=0.12))
CLIPS['ClusterPalm'] = seq('ClusterPalm', [
    (0.0, P(body=dict(y=-0.3, twist=-20, lean=8), ra=(60, -10, 20), la=(40, 20, 10), rl=dict(f=-0.9, s=0.35), ll=dict(f=0.7, s=0.15)), OUT),
    (0.05, over(REST, PALM, 0.06), OUT, 'Hit'),
    (0.12, PALM, INOUT),
    (0.3, merge(PALM, body=dict(y=-0.28, twist=36, lean=15, fwd=0.45)), INOUT),
    (0.45, blend(PALM, STANCE, 0.6), INOUT),
])
# every side: a hook of a palm, a spinning back kick with the blast off his
# back, both palms from above
CS_A = P(body=dict(y=-0.25, twist=-44, lean=12, tilt=6), la=(94, -12, 0), ra=(40, 40, 10), rl=dict(f=-0.9, s=0.4), ll=dict(f=0.8, s=0.15))
CS_B = P(body=dict(y=0.0, twist=60, lean=-28, tilt=-18), ra=(30, 0, 60), la=(40, 0, 60), rl=(12, 0, 70), ll=dict(f=0.1, s=0.3))
CS_C = P(body=dict(pivot='center', legs='chest', lean=38), ra=(128, 26, 0), la=(128, 26, 0), rl=(-20, 0, 10), ll=(-8, 0, 12), head=(-20, 0, 0))
for name, pose, wind in (('ClusterStrikeA', CS_A, merge(CS_A, body=dict(twist=10), la=(40, -40, 20))),
                         ('ClusterStrikeB', CS_B, merge(CS_B, body=dict(twist=-30, lean=-10))),
                         ('ClusterStrikeC', CS_C, merge(CS_C, body=dict(pivot='center', legs='chest', lean=-10), ra=(176, 0, 10), la=(176, 0, 10)))):
    CLIPS[name] = seq(name, [
        (0.0, wind, OUT),
        (0.045, over(wind, pose, 0.08), OUT, 'Hit'),
        (0.11, pose, INOUT),
        (0.2, blend(pose, STANCE, 0.3), INOUT),
    ])
# the white void: floating, both palms drawn back together, filling with
# everything he has left - then all of it, both palms thrown into them
CH = P(body=dict(pivot='center', legs='chest', lean=-6, twist=-24), ra=(-40, 30, 20), la=(-40, 30, 20), rl=(20, 0, 10), ll=(-10, 0, 10), head=(-6, 20, 0))
FIN = P(body=dict(pivot='center', legs='chest', lean=18, twist=20), ra=(96, 18, 0, 90), la=(96, 18, 0, 90), rl=(-24, 0, 12), ll=(-6, 0, 12), head=(-16, 0, 0))
CLIPS['ClusterCharge'] = seq('ClusterCharge', [
    (0.0, blend(REST, CH, 0.5), OUT),
    (0.18, CH, OUT),
    (0.7, merge(CH, body=dict(pivot='center', legs='chest', lean=-10, twist=-30), ra=(-48, 32, 22), la=(-48, 32, 22)), INOUT),
])
CLIPS['ClusterFinal'] = seq('ClusterFinal', [
    (0.0, CH, OUT),
    (0.05, over(CH, FIN, 0.1), OUT, 'Hit'),
    (0.14, FIN, INOUT),
    (0.45, merge(FIN, body=dict(pivot='center', legs='chest', lean=12, twist=16)), INOUT),
    (0.7, blend(FIN, REST, 0.7), INOUT),
])

ORDER = list(CLIPS)
