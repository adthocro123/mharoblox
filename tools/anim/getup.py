"""Getting up off the street after a ragdoll (round 63), keyframed for R6.
Each clip's FIRST frame lies on the street the way the ragdoll left the
body - the root is stood right over the torso, turned so the head points the
right way - so the get-up takes over with no pop to standing.
  GetUpBack: on the back, head behind - sit up, hands pushing off behind,
             swing the feet under, rise.
  GetUpFront: face down, head in front - push up off both hands, jump the
             feet in under the body, rise."""
from m1 import P, merge, clip, OUT, IN, INOUT
REST = P()
FLAT = -2.5  # the torso's centre lying on the street (the root 3 up)

CLIPS = {}
CLIPS['GetUpBack'] = clip('GetUpBack', [
    (0.0, P(body=dict(pivot='center', legs='chest', y=FLAT, lean=-90), ra=(-8, 0, 26), la=(-8, 0, 30),
            rl=(0, 0, 6), ll=(4, 0, 8), head=(-6, 0, 0)), OUT),
    # sit up: the chest comes up off the street, the hands push off behind
    (0.1, P(body=dict(pivot='center', y=-1.75, lean=-38, fwd=0.45), ra=(-42, 0, 22), la=(-42, 0, 22),
            rl=(82, 0, 8), ll=(78, 0, 10), head=(14, 0, 0)), OUT),
    # the feet swing in under him: a low crouch, leaning over the knees
    (0.21, P(body=dict(y=-1.15, lean=34, fwd=0.2), ra=(58, 16, 16), la=(52, 16, 18),
             rl=dict(f=0.15, s=0.45), ll=dict(f=-0.2, s=0.4), head=(-10, 0, 0)), INOUT),
    # and up
    (0.33, P(body=dict(y=-0.3, lean=9), ra=(22, 8, 12), la=(18, 8, 12),
             rl=dict(f=0.05, s=0.25), ll=dict(f=-0.1, s=0.2)), INOUT),
    (0.46, REST, INOUT),
])
CLIPS['GetUpFront'] = clip('GetUpFront', [
    (0.0, P(body=dict(pivot='center', legs='chest', y=FLAT, lean=90), ra=(36, 0, 30), la=(36, 0, 30),
            rl=(0, 0, 6), ll=(-4, 0, 8), head=(-20, 0, 0)), OUT),
    # push up off both hands, the head coming up
    (0.1, P(body=dict(pivot='center', legs='chest', y=-1.7, lean=62, fwd=0.25), ra=(96, 4, 14), la=(96, 4, 14),
            rl=(-6, 0, 6), ll=(-2, 0, 8), head=(-34, 0, 0)), OUT),
    # the feet jump in under him: a crouch over them
    (0.21, P(body=dict(y=-1.15, lean=36, fwd=0.15), ra=(64, 14, 14), la=(60, 14, 16),
             rl=dict(f=0.1, s=0.45), ll=dict(f=-0.25, s=0.4), head=(-14, 0, 0)), INOUT),
    (0.33, P(body=dict(y=-0.3, lean=9), ra=(22, 8, 12), la=(18, 8, 12),
             rl=dict(f=0.05, s=0.25), ll=dict(f=-0.1, s=0.2)), INOUT),
    (0.46, REST, INOUT),
])
for c in CLIPS.values():
    c['priority'] = 'Action'
ORDER = ['GetUpBack', 'GetUpFront']
