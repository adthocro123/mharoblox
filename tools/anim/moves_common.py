"""The held poses many moves share (round 63): "Pose<name>" clips, played
by VFX.Pose - a readable counter-move, a snap into the pose ("Hit"), the
"Hold" key held as long as the move holds it, then a follow-through."""
from moves_lib import P, merge, REST, STANCE, blend, over, strike, charge, seq, OUT, IN, INOUT
import rig

CLIPS = {}
LUNGE = dict(rl=dict(f=-1.15, s=0.32), ll=dict(f=0.95, s=0.1))
BRACE = dict(rl=dict(f=-0.95, s=0.42), ll=dict(f=0.75, s=0.3))
WIDE = dict(rl=dict(f=-0.2, s=0.75), ll=dict(f=0.2, s=0.75))

# a straight right, everything behind it
PUNCH_R = P(body=dict(y=-0.28, twist=44, lean=13, fwd=0.35), ra=(95, 5, 0), la=(66, 42, 8), **LUNGE)
CLIPS['PosePunchR'] = strike('PosePunchR', PUNCH_R,
                             wind=P(body=dict(y=-0.16, twist=-22, lean=4, fwd=-0.05), ra=(52, 10, 22), la=(84, 34, 4), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.7, s=0.12)),
                             settle=merge(PUNCH_R, body=dict(y=-0.27, twist=40, lean=12, fwd=0.32)))
CLIPS['PosePunchL'] = seq('PosePunchL', [(k['t'], rig.mirror(k['pose']), k['ease'], k['name']) for k in CLIPS['PosePunchR']['keys']])

# the fist drawn right back, sunk on the back foot, the other arm aiming
COIL = P(body=dict(y=-0.4, twist=-50, lean=5, fwd=-0.18, tilt=6), ra=(-52, -8, 26), la=(84, -16, 6),
         rl=dict(f=-1.15, s=0.45, turn=22), ll=dict(f=0.9, s=0.15))
CLIPS['PosePunchCharge'] = charge('PosePunchCharge', COIL, deep=merge(COIL, body=dict(y=-0.46, twist=-56, lean=6, fwd=-0.24, tilt=7), ra=(-58, -8, 30)))

# both palms thrust out (a blast, a push, a shockwave off the hands)
BLAST = P(body=dict(y=-0.24, lean=12, fwd=0.28), ra=(92, 16, 0), la=(92, 16, 0), **BRACE)
CLIPS['PoseBlast'] = strike('PoseBlast', BLAST,
                            wind=P(body=dict(y=-0.14, lean=-6, fwd=-0.1), ra=(38, -14, 22), la=(38, -14, 22), rl=dict(f=-0.7, s=0.4), ll=dict(f=0.55, s=0.3)))

# both arms flung up over the head (a charge, a signal, a grenade going up)
ARMS_UP = P(body=dict(y=-0.04, lean=-12), ra=(168, -4, 14), la=(168, -4, 14), rl=dict(f=-0.2, s=0.4), ll=dict(f=0.25, s=0.35))
CLIPS['PoseArmsUp'] = strike('PoseArmsUp', ARMS_UP,
                             wind=P(body=dict(y=-0.3, lean=14), ra=(20, 10, 24), la=(20, 10, 24), rl=dict(f=-0.25, s=0.45), ll=dict(f=0.25, s=0.4)), t_hit=0.08)

# a hand shot out to grab whoever's in front
GRAB = P(body=dict(y=-0.3, twist=28, lean=18, fwd=0.42), ra=(88, 8, 0, -30), la=(-30, 0, 28), **LUNGE)
CLIPS['PoseGrab'] = strike('PoseGrab', GRAB,
                           wind=P(body=dict(y=-0.2, twist=-16, lean=6), ra=(50, 0, 20), la=(60, 30, 10), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.6, s=0.12)))

# an overhand throw: the arm right back over the shoulder, then whipped
# through, the body turning over the front foot
THROWN = P(body=dict(y=-0.22, twist=34, lean=22, fwd=0.3), ra=(96, 22, 0), la=(-20, 0, 30), **LUNGE)
WIND_T = P(body=dict(y=-0.2, twist=-38, lean=-12, fwd=-0.2), ra=(205, -10, 12), la=(80, -10, 10), rl=dict(f=-1.0, s=0.4), ll=dict(f=0.85, s=0.15))
CLIPS['PoseThrow'] = seq('PoseThrow', [
    (0.0, WIND_T, OUT),
    (0.07, over(WIND_T, THROWN, 0.08), OUT, 'Hit'),
    (0.14, merge(THROWN, ra=(62, 30, 0), body=dict(y=-0.24, twist=40, lean=26, fwd=0.34)), INOUT),
    (0.16, merge(THROWN, ra=(60, 30, 0), body=dict(y=-0.24, twist=40, lean=26, fwd=0.34)), INOUT, 'Hold'),
    (0.3, blend(THROWN, REST, 0.55), INOUT),
    (0.52, REST, INOUT),
])

# a front kick: chambered, then snapped out, leaning back off it
KICK = P(body=dict(y=-0.08, lean=-14, twist=-8), ra=(-24, 0, 30), la=(56, 24, 16), rl=(98, 0, 4), ll=dict(f=0.05, s=0.2))
CLIPS['PoseKick'] = strike('PoseKick', KICK,
                           wind=P(body=dict(y=-0.14, lean=6), ra=(30, 10, 20), la=(60, 20, 14), rl=(64, 0, 6), ll=dict(f=0.05, s=0.2)), t_hit=0.07)
CLIPS['PoseKickLeft'] = seq('PoseKickLeft', [(k['t'], rig.mirror(k['pose']), k['ease'], k['name']) for k in CLIPS['PoseKick']['keys']])

# a hand slammed to the street: dropped into a crouch over it
GROUND = P(body=dict(y=-1.05, lean=42, fwd=0.2), ra=(56, 6, 8), la=(-20, 0, 34), rl=dict(f=-0.6, s=0.5), ll=dict(f=0.7, s=0.4))
CLIPS['PoseGround'] = strike('PoseGround', GROUND,
                             wind=P(body=dict(y=-0.3, lean=-6), ra=(150, 0, 14), la=(30, 0, 30), rl=dict(f=-0.3, s=0.4), ll=dict(f=0.3, s=0.3)), t_hit=0.08)
CLIPS['PoseSlam'] = strike('PoseSlam', merge(GROUND, body=dict(y=-0.95, lean=48, fwd=0.35), ra=(40, 14, 4), la=(40, 14, 4)),
                           wind=P(body=dict(y=-0.1, lean=-14), ra=(172, 0, 10), la=(172, 0, 10), rl=dict(f=-0.35, s=0.4), ll=dict(f=0.3, s=0.35)), t_hit=0.08)

# a stomp: the knee hoisted, then driven down into the street
STOMP = P(body=dict(y=-0.42, lean=12, tilt=-6), ra=(30, 0, 44), la=(-24, 0, 30), rl=dict(f=0.35, s=0.55), ll=dict(f=-0.2, s=0.3))
CLIPS['PoseStomp'] = strike('PoseStomp', STOMP,
                            wind=P(body=dict(y=0.0, lean=-8, tilt=8), ra=(40, 0, 40), la=(40, 0, 40), rl=(82, 0, 8), ll=dict(f=-0.05, s=0.25)), t_hit=0.08)

# a clap: the arms swung in wide, the palms meeting in front
CLAP = P(body=dict(y=-0.15, lean=8), ra=(96, 46, 0), la=(96, 46, 0), rl=dict(f=-0.4, s=0.4), ll=dict(f=0.4, s=0.3))
CLIPS['PoseClap'] = strike('PoseClap', CLAP,
                           wind=P(body=dict(y=-0.08, lean=-8), ra=(88, -64, 14), la=(88, -64, 14), rl=dict(f=-0.3, s=0.4), ll=dict(f=0.3, s=0.3)), t_hit=0.07)

# a landing: soaked up in a deep crouch, a hand out for balance
LAND = P(body=dict(y=-0.95, lean=30), ra=(46, -6, 34), la=(30, 0, 40), rl=dict(f=-0.5, s=0.6), ll=dict(f=0.6, s=0.5))
CLIPS['PoseLand'] = strike('PoseLand', LAND, wind=blend(REST, LAND, 0.5), t_hit=0.05, overshoot=0.15)

# both palms blasting out behind (rocketing forward on it)
RUSH = P(body=dict(y=-0.22, lean=28, fwd=0.2), ra=(-78, 0, 16), la=(-78, 0, 16), rl=dict(f=-0.9, s=0.35), ll=dict(f=0.5, s=0.25))
CLIPS['PoseRushBack'] = strike('PoseRushBack', RUSH)

# flying head first, down at them, the palms blasting behind
DIVE = P(body=dict(pivot='center', legs='chest', lean=112), ra=(-150, 0, 20), la=(-150, 0, 20), rl=(-6, 0, 6), ll=(8, 0, 6), head=(-38, 0, 0))
CLIPS['PoseDiveBomb'] = strike('PoseDiveBomb', DIVE, wind=blend(REST, DIVE, 0.4), t_hit=0.08, overshoot=0.05)

# AP SHOT: the right arm locked out straight, the left hand bracing its
# wrist, feet dug in for the recoil
AP = P(body=dict(y=-0.3, twist=24, lean=8, fwd=0.15), ra=(92, 6, 0), la=(84, 62, 0), rl=dict(f=-1.05, s=0.45, turn=18), ll=dict(f=0.8, s=0.2))
CLIPS['PoseAPShot'] = strike('PoseAPShot', AP,
                             wind=P(body=dict(y=-0.2, twist=4, lean=2), ra=(70, 8, 10), la=(70, 50, 4), rl=dict(f=-0.9, s=0.45), ll=dict(f=0.7, s=0.2)), t_hit=0.05, overshoot=0.06)

# CAROLINA's X: both arms crossed high in front, ready to scissor
CROSS = P(body=dict(y=-0.22, lean=-6, twist=-6), ra=(128, 62, 0), la=(134, 58, 0), **BRACE)
CLIPS['PoseCross'] = charge('PoseCross', CROSS, deep=merge(CROSS, body=dict(y=-0.28, lean=-8, twist=-8), ra=(136, 66, 0), la=(142, 62, 0)), t_in=0.09)

# the guard: forearms up in front of the face, knees bent, waiting
COUNTER = P(body=dict(y=-0.35, lean=6), ra=(104, 38, 0, 40), la=(104, 38, 0, 40), **BRACE)
CLIPS['PoseCounterStance'] = charge('PoseCounterStance', COUNTER)

# the sprinter's crouch (a rev, a start)
REV = P(body=dict(y=-0.62, lean=34, fwd=0.1), ra=(-58, 0, 14), la=(-58, 0, 14), rl=dict(f=-1.1, s=0.3), ll=dict(f=0.55, s=0.25))
CLIPS['PoseRev'] = charge('PoseRev', REV)
# arms out wide, hands open, head down: a menace
MENACE = P(body=dict(y=-0.1, lean=-6), ra=(42, -10, 64), la=(42, -10, 64), head=(-12, 0, 0), rl=dict(f=-0.2, s=0.4), ll=dict(f=0.2, s=0.35))
CLIPS['PoseMenace'] = charge('PoseMenace', MENACE)
# the deep crouch (Full Cowl gathering itself)
COWL = P(body=dict(y=-1.0, lean=26), ra=(20, 0, 40), la=(20, 0, 40), head=(10, 0, 0), rl=dict(f=-0.5, s=0.55), ll=dict(f=0.55, s=0.45))
CLIPS['PoseCowlCrouch'] = charge('PoseCowlCrouch', COWL, t_in=0.08)
# a rising uppercut finish
UPPER = P(body=dict(y=0.05, twist=26, lean=-12, tilt=-8), ra=(170, 10, 0), la=(24, 20, 16), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.6, s=0.15))
CLIPS['PoseFinishUppercut'] = strike('PoseFinishUppercut', UPPER,
                                     wind=P(body=dict(y=-0.5, twist=-24, lean=20, tilt=10), ra=(-10, 0, 20), la=(80, 30, 6), rl=dict(f=-0.7, s=0.45), ll=dict(f=0.7, s=0.2)))


ORDER = list(CLIPS)
