"""BAKUGO: EXPLOSIVE SPEED (round 64) as keyframed clips. The crouch
(Move, during the wind-up), the flight (a held Pose: the server tips his
body flat out face down, so the pose is written in the body's own frame),
and the catch (Move: the server flips him upside down face to face - a
tuck, then the free arm thrown wide and his palm coming slowly up into
their face as time crawls)."""
from moves_lib import P, merge, REST, blend, over, strike, seq, OUT, IN, INOUT, LIN

CLIPS = {}

# the sprinter's crouch: sunk on the back foot, chest down over the front
# knee, both arms swept back behind him with the palms open (the jets), chin
# up looking down the street - coiling tighter as the beads pop
C1 = P(body=dict(y=-0.6, lean=34, fwd=-0.05), ra=(-46, 0, 24), la=(-46, 0, 24),
       rl=dict(f=-1.25, s=0.3), ll=dict(f=0.6, s=0.22), head=(-30, 0, 0))
C2 = merge(C1, body=dict(y=-0.7, lean=40, fwd=-0.02), ra=(-56, 0, 28), la=(-56, 0, 28), head=(-34, 0, 0))
C2T = merge(C2, body=dict(y=-0.69, lean=41, fwd=-0.02, tilt=2.5, twist=3), ra=(-58, 2, 28), la=(-55, -2, 29))
C3 = merge(C1, body=dict(y=-0.76, lean=45, fwd=0.04), ra=(-66, 0, 32), la=(-66, 0, 32), head=(-38, 0, 0))
CLIPS['MoveBlitzCrouch'] = seq('MoveBlitzCrouch', [
    (0.0, blend(REST, C1, 0.3), OUT),
    (0.12, over(REST, C1, 0.08), OUT, 'Hit'),
    (0.3, C2, INOUT),
    (0.42, C2T, INOUT),
    (0.52, C2, INOUT),
    (0.64, C3, IN),
    (0.7, C3, LIN),
])

# flat out like a missile (the body tipped face down by the server): head
# back to look where he's going, arms swept back along his sides with the
# palms blasting behind him, legs straight back together
FLY = P(body=dict(lean=-4), head=(-58, 0, 0), ra=(-14, 0, 14), la=(-14, 0, 14), rl=(-4, 0, 5), ll=(-10, 0, 7))
CLIPS['PoseBlitzFly'] = strike('PoseBlitzFly', FLY, wind=C3, t_hit=0.05, hold=0.1, back=0.3, overshoot=0.06)

# the catch: tucked for an instant as he flips over, then upside down face
# to face - the free arm thrown wide, legs flung out, and the right palm
# coming up flat into their face as time crawls
TUCK = P(body=dict(lean=30), ra=(60, 20, 20), la=(60, 20, 20), rl=(80, 0, 10), ll=(70, 0, 10), head=(20, 0, 0))
REACH0 = P(body=dict(lean=-10, twist=24), ra=(116, 22, 18), la=(-30, 0, 62), rl=(-30, 0, 12), ll=(46, 0, 16), head=(-6, -14, 0))
REACH1 = merge(REACH0, body=dict(lean=-12, twist=30), ra=(138, 24, 16), la=(-38, 0, 68), rl=(-36, 0, 14), ll=(54, 0, 18), head=(-8, -18, 0))
CLIPS['MoveBlitzFlip'] = seq('MoveBlitzFlip', [
    (0.0, FLY, OUT),
    (0.08, TUCK, OUT, 'Hit'),
    (0.24, over(TUCK, REACH0, 0.06), OUT),
    (0.34, REACH0, INOUT),
    (1.35, REACH1, INOUT),
    (1.5, REACH1, LIN),
])

ORDER = list(CLIPS)
