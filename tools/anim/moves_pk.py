"""PARKOUR (round 65) as keyframed R6 clips: what VFX.Motion("Pk...") plays
(as "MovePk..."). The parkour code moves the body along its path - over
the top of a vault, up a wall, tipped back under a slide, turned over in a
roll - so each clip is the body's own pose on top of that: the planted
hand and the legs swung through, hand over hand, feet first, tucked tight."""
from moves_lib import P, merge, REST, blend, over, seq, OUT, IN, INOUT, LIN
import rig

CLIPS = {}
RUN = P(body=dict(lean=12), ra=(-30, 0, 12), la=(44, 8, 10), rl=(40, 0, 4), ll=(-24, 0, 4))

# VAULT (a speed vault, ~0.3-0.5s over the top): the left hand plants on
# the obstacle, the body tips onto it and both legs swing through to the
# right, then he drops onto his feet already running
PLANT = P(body=dict(y=0.35, lean=26, tilt=-24, twist=-8), la=(62, 18, -4), ra=(86, -14, 58),
          rl=(78, -18, 40), ll=(70, 26, -18), head=(10, 10, 0))
SWING = P(body=dict(y=0.3, lean=14, tilt=-30, twist=-14), la=(40, 12, -2), ra=(98, -10, 64),
          rl=(62, -8, 52), ll=(58, 30, -4), head=(4, 14, 0))
VLAND = P(body=dict(y=-0.36, lean=14), ra=(40, 0, 30), la=(26, 0, 34),
          rl=dict(f=0.45, s=0.35), ll=dict(f=-0.35, s=0.25), head=(-6, 0, 0))
CLIPS['MovePkVault'] = seq('MovePkVault', [
    (0.0, blend(RUN, PLANT, 0.3), OUT),
    (0.07, PLANT, OUT, 'Hit'),
    (0.19, SWING, INOUT),
    (0.3, VLAND, OUT, 'Land'),
    (0.42, blend(VLAND, RUN, 0.6), INOUT),
    (0.52, REST, INOUT),
])

# MANTLE (onto a ledge you can reach): hands up on the edge, a push that
# brings the knees up, one foot on the top, up
HANG = P(body=dict(lean=-4), ra=(168, 0, 12), la=(168, 0, 12), rl=(-6, 0, 4), ll=(4, 0, 4), head=(-20, 0, 0))
PUSH = P(body=dict(y=0.3, lean=34), ra=(52, 0, 14), la=(52, 0, 14), rl=(96, 0, 8), ll=(74, 0, 8), head=(-8, 0, 0))
STEP = P(body=dict(y=-0.2, lean=24), ra=(30, 0, 16), la=(26, 0, 18), rl=dict(f=0.55, s=0.3), ll=(34, 0, 6), head=(-10, 0, 0))
CLIPS['MovePkMantle'] = seq('MovePkMantle', [
    (0.0, HANG, OUT),
    (0.1, PUSH, OUT, 'Hit'),
    (0.22, STEP, INOUT),
    (0.36, REST, INOUT),
])

# CLIMB (played every 0.24s on the way up): hand over hand, the knee on
# the reaching side's other leg driving up
REACH_R = P(body=dict(lean=-6), ra=(174, 0, 6), la=(120, 0, 10), rl=(8, 0, 4), ll=(72, 0, 6), head=(-26, 0, 0))
REACH_L = rig.mirror(REACH_R)
CLIPS['MovePkClimb'] = seq('MovePkClimb', [
    (0.0, blend(REACH_L, REACH_R, 0.4), OUT),
    (0.06, REACH_R, INOUT, 'Hit'),
    (0.18, REACH_L, INOUT),
    (0.24, blend(REACH_L, REACH_R, 0.4), INOUT),
])

# SLIDE (the body tipped back by the parkour code): feet first, the right
# leg out straight along the street, the left lower, a hand trailing on the
# ground, the other up in front, chin tucked to see where he's going
SLIDE = P(body=dict(lean=-8, tilt=-4), rl=(86, 0, 4), ll=(44, 0, 10), ra=(-36, 0, 34), la=(72, 16, 12), head=(34, 0, 0))
CLIPS['MovePkSlide'] = seq('MovePkSlide', [
    (0.0, REST, OUT),
    (0.07, over(REST, SLIDE, 0.08), OUT, 'Hit'),
    (0.12, SLIDE, INOUT),
    (0.36, merge(SLIDE, rl=(80, 0, 4), ll=(52, 0, 10)), INOUT),
    (0.5, REST, INOUT),
])

# WALL RUN (wall on the right; the left one is its mirror): two strides
# along it, leaning in, the arms swinging against the legs
WR_A = P(body=dict(lean=10, tilt=16), rl=(58, 0, 6), ll=(-36, 0, 4), ra=(-34, 0, 22), la=(70, 18, 8), head=(-4, 8, 0))
WR_B = P(body=dict(lean=10, tilt=16), rl=(-30, 0, 6), ll=(56, 0, 4), ra=(72, 18, 10), la=(-34, 0, 20), head=(-4, 8, 0))
CLIPS['MovePkWallRunR'] = seq('MovePkWallRunR', [
    (0.0, blend(REST, WR_A, 0.5), OUT),
    (0.06, WR_A, INOUT, 'Hit'),
    (0.16, WR_B, INOUT),
    (0.26, WR_A, INOUT),
    (0.34, blend(WR_A, WR_B, 0.5), INOUT),
])
CLIPS['MovePkWallRunL'] = seq('MovePkWallRunL', [(k['t'], rig.mirror(k['pose']), k['ease'], k['name']) for k in CLIPS['MovePkWallRunR']['keys']])

# WALL KICK: coiled against the wall, then springing off it - arms thrown
# up, body stretched out, then gathering to land
COIL = P(body=dict(y=0.2, lean=10), rl=(78, 0, 10), ll=(50, 0, 10), ra=(150, 0, 18), la=(150, 0, 18), head=(-14, 0, 0))
SPRING = P(body=dict(y=0.4, lean=-14), rl=(-18, 0, 6), ll=(10, 0, 8), ra=(176, 0, 24), la=(172, 0, 24), head=(-26, 0, 0))
GATHER = P(body=dict(lean=6), rl=(40, 0, 6), ll=(20, 0, 8), ra=(70, 0, 34), la=(62, 0, 36), head=(-6, 0, 0))
CLIPS['MovePkWallKick'] = seq('MovePkWallKick', [
    (0.0, COIL, OUT),
    (0.07, over(COIL, SPRING, 0.1), OUT, 'Hit'),
    (0.14, SPRING, INOUT),
    (0.32, GATHER, INOUT),
    (0.5, REST, INOUT),
])

# ROLL (the parkour code turns the body over): tucked tight, chin down,
# arms round the shins - then open out onto the feet running
TUCKED = P(body=dict(y=-0.3, lean=36, pivot='center', legs='chest'), rl=(104, 0, 6), ll=(96, 0, 6),
           ra=(62, 26, 10), la=(62, 26, 10), head=(38, 0, 0))
CLIPS['MovePkRoll'] = seq('MovePkRoll', [
    (0.0, blend(REST, TUCKED, 0.4), OUT),
    (0.06, TUCKED, OUT, 'Hit'),
    (0.34, merge(TUCKED, rl=(96, 0, 6), ll=(86, 0, 6)), INOUT),
    (0.44, merge(REST, body=dict(y=-0.3, lean=16), ra=(34, 0, 22), la=(30, 0, 24),
                 rl=dict(f=0.4, s=0.3), ll=dict(f=-0.3, s=0.25)), OUT, 'Land'),
    (0.58, REST, INOUT),
])

ORDER = list(CLIPS)
