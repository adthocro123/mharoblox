"""The four dashes, keyframed for R6 (Q + a direction). The body only poses:
the dash itself moves you (front 0.28s, sides 0.2s, back 0.68s: a backflip, a twist, a handstand)."""
from m1 import P, merge, clip, OUT, IN, INOUT, LIN
import rig

REST = P()

CLIPS = {}

# FRONT: an explosive push off the back foot - dropped low, the chest thrown
# forward, both arms swept straight back (the anime dash) - held through the
# glide, then the lead foot plants and the arms swing through to brake
FLY = P(body=dict(y=-0.28, lean=30, fwd=0.35), ra=(-72, 0, 14), la=(-78, 0, 16), rl=(-42, 0, 4), ll=(36, 0, 4))
CLIPS['DashFront'] = clip('DashFront', [
    (0.0, REST, OUT),
    (0.05, merge(FLY, body=dict(y=-0.3, lean=34, fwd=0.4), ra=(-80, 0, 16), la=(-86, 0, 18), rl=(-48, 0, 4), ll=(40, 0, 4)), OUT),
    (0.2, FLY, IN),
    (0.3, merge(REST, body=dict(y=-0.34, lean=8, fwd=0.1), ra=(46, 10, 22), la=(30, 6, 28),
                rl=dict(f=-0.8, s=0.35), ll=dict(f=1.15, s=0.15)), OUT),
    (0.42, merge(REST, body=dict(y=-0.14, lean=4), ra=(14, 0, 10), la=(10, 0, 12), rl=dict(f=-0.4, s=0.2), ll=dict(f=0.45, s=0.1)), INOUT),
    (0.56, REST, INOUT),
])

# BACK (round 65, Rampage Showdown's Sukuna; round 66: the twist, a longer
# handstand, the landing): a BACKFLIP, then up into a layout with a full
# TWIST, onto his HANDS, and over into a three-point landing. A dip, a spring
# up and back with the arms thrown over his head, tucked tight as he turns
# over; the feet barely touch and he springs up again, laid out flat on his
# back in the air - arms folded in, legs together - and spins a full 360 on
# his own long axis while he's horizontal; then he opens out, reaching back
# for the street, onto his hands (a split handstand, head up looking at the
# street, held a beat - the legs scissor wider), the legs whip over and he
# drops into a superhero landing: one foot planted, the other leg stretched
# back along the street, a fist on the ground, the head down - then it comes
# up to look at the fight, and he rises.
FLIP = dict(pivot='center', legs='chest')
FOLD = dict(ra=(34, 52, 4), la=(34, 52, 4))  # (arms folded across him for the spin)
CLIPS['DashBack'] = clip('DashBack', [
    (0.0, REST, OUT),
    # the dip: sunk, chest over the knees, arms swept down and back
    (0.04, merge(REST, body=dict(y=-0.5, lean=12), ra=(-52, 0, 12), la=(-52, 0, 12),
                 rl=dict(f=0.25, s=0.3), ll=dict(f=-0.05, s=0.3), head=(8, 0, 0)), OUT),
    # up and back: arms thrown over his head, body straight off the push
    (0.09, merge(REST, body=dict(FLIP, y=0.7, lean=-42), ra=(172, 0, 14), la=(172, 0, 14),
                 rl=(-8, 0, 4), ll=(-8, 0, 4), head=(-26, 0, 0)), LIN),
    # tucked tight, turning over
    (0.15, merge(REST, body=dict(FLIP, y=1.7, lean=-135), ra=(84, 18, 14), la=(84, 18, 14),
                 rl=(104, 0, 6), ll=(98, 0, 6), head=(22, 0, 0)), LIN),
    (0.21, merge(REST, body=dict(FLIP, y=2.0, lean=-228), ra=(72, 22, 12), la=(72, 22, 12),
                 rl=(112, 0, 6), ll=(106, 0, 6), head=(24, 0, 0)), LIN),
    # opening out, feet reaching for the street
    (0.27, merge(REST, body=dict(FLIP, y=1.0, lean=-318), ra=(128, 0, 22), la=(128, 0, 22),
                 rl=(44, 0, 6), ll=(34, 0, 6), head=(6, 0, 0)), OUT),
    # the feet barely touch - and he springs straight up again
    (0.31, merge(REST, body=dict(FLIP, y=-0.3, lean=-378), ra=(176, 0, 16), la=(176, 0, 16),
                 rl=dict(f=0.55, s=0.3), ll=dict(f=0.35, s=0.3), head=(-38, 0, 0)), OUT),
    # laid out flat on his back in the air, arms folded in: the TWIST - a
    # full turn on his own long axis while he's horizontal (a quarter a key)
    (0.35, merge(REST, **FOLD, body=dict(FLIP, y=1.1, lean=-440), rl=(-4, 0, 2), ll=(-4, 0, 2), head=(-8, 0, 0)), LIN, 'Twist'),
    (0.39, merge(REST, **FOLD, body=dict(FLIP, y=1.5, lean=-446, roll=90), rl=(-4, 0, 2), ll=(-4, 0, 2), head=(-8, 0, 0)), LIN),
    (0.43, merge(REST, **FOLD, body=dict(FLIP, y=1.7, lean=-452, roll=180), rl=(-4, 0, 2), ll=(-4, 0, 2), head=(-8, 0, 0)), LIN),
    (0.47, merge(REST, **FOLD, body=dict(FLIP, y=1.6, lean=-458, roll=270), rl=(-4, 0, 2), ll=(-4, 0, 2), head=(-8, 0, 0)), LIN),
    # out of the spin, opening up: arms reaching back over his head
    (0.51, merge(REST, body=dict(FLIP, y=1.2, lean=-466, roll=360), ra=(150, 0, 14), la=(150, 0, 14),
                 rl=(-10, 0, 4), ll=(-4, 0, 4), head=(-40, 0, 0)), OUT),
    (0.56, merge(REST, body=dict(FLIP, y=0.2, lean=-505, fwd=-0.3), ra=(180, 0, 12), la=(180, 0, 12),
                 rl=(-16, 0, 5), ll=(-6, 0, 5), head=(-60, 0, 0)), OUT),
    # onto his hands: a split handstand, looking at the street
    # (head right back, looking at the street between his hands: an R6 head
    # is as long as the arms reach past the shoulders) - held a beat, the
    # legs scissoring wider
    (0.61, merge(REST, body=dict(FLIP, y=-0.85, lean=-540, fwd=-0.55), ra=(176, 0, 10), la=(176, 0, 10),
                 rl=(-14, 0, 4), ll=(10, 0, 4), head=(-70, 0, 0)), OUT, 'Hands'),
    (0.69, merge(REST, body=dict(FLIP, y=-0.84, lean=-546, fwd=-0.58), ra=(174, 0, 10), la=(174, 0, 10),
                 rl=(-30, 0, 5), ll=(24, 0, 5), head=(-70, 0, 0)), INOUT),
    (0.77, merge(REST, body=dict(FLIP, y=-0.8, lean=-553, fwd=-0.6), ra=(170, 0, 10), la=(170, 0, 10),
                 rl=(-44, 0, 6), ll=(38, 0, 6), head=(-68, 0, 0)), IN),
    # the legs whip over (a snap off the hands)
    (0.82, merge(REST, body=dict(FLIP, y=-0.3, lean=-652, fwd=-0.75), ra=(150, 0, 18), la=(150, 0, 18),
                 rl=(46, 0, 6), ll=(36, 0, 6), head=(-10, 0, 0)), OUT),
    # the SUPERHERO LANDING: one foot planted, the other leg stretched back
    # along the street, the right fist on the ground, the left arm flung
    # back, the head down...
    (0.87, merge(REST, body=dict(y=-1.3, lean=52, fwd=0.1, twist=-8), ra=(55, 8, 8), la=(-58, 0, 34),
                 rl=dict(f=1.25, s=0.45), ll=(-80, 0, 12), head=(30, 0, 0)), OUT, 'Land'),
    # ...then it comes up to look at the fight
    (0.99, merge(REST, body=dict(y=-1.28, lean=50, fwd=0.1, twist=-8), ra=(55, 8, 8), la=(-52, 0, 30),
                 rl=dict(f=1.25, s=0.45), ll=(-78, 0, 12), head=(-44, 0, 0)), INOUT),
    (1.12, merge(REST, body=dict(y=-0.42, lean=10), ra=(20, 0, 14), la=(12, 0, 18),
                 rl=dict(f=0.6, s=0.3), ll=dict(f=-0.7, s=0.2), head=(-6, 0, 0)), INOUT),
    (1.26, REST, INOUT),
])
# (round 67) all of it a little quicker: every key x BACK_PACE (the game's
# Config.Movement back dash numbers are paced to match)
BACK_PACE = 0.85
for _k in CLIPS['DashBack']['keys']:
    _k['t'] = round(_k['t'] * BACK_PACE, 4)
# (the preview's stand-in for the dash carrying him back)
CLIPS['DashBack']['lunge'] = (round(0.04 * BACK_PACE, 4), -52, 0.8)

# SIDES: a low lateral push off the far foot - the body shifted and tipped
# into it, the lead arm out, the other across the chest - then a wide skid
# on the lead foot, leaning back against the slide
RIGHT_FLY = P(body=dict(y=-0.3, side=0.35, tilt=16, twist=-6), ra=(24, 0, 64), la=(40, 52, 0),
              rl=(8, 0, 34), ll=dict(f=0.1, s=1.6))
CLIPS['DashRight'] = clip('DashRight', [
    (0.0, REST, OUT),
    (0.045, merge(RIGHT_FLY, body=dict(y=-0.34, side=0.4, tilt=20)), OUT),
    (0.16, RIGHT_FLY, IN),
    (0.25, merge(REST, body=dict(y=-0.42, side=-0.1, tilt=-10), ra=(34, 0, 44), la=(36, 0, 40),
                 rl=dict(f=0.1, s=1.35), ll=dict(f=-0.1, s=0.3)), OUT),
    (0.37, merge(REST, body=dict(y=-0.16, tilt=-3), ra=(10, 0, 14), la=(10, 0, 14), rl=dict(f=0, s=0.6), ll=dict(f=0, s=0.25)), INOUT),
    (0.5, REST, INOUT),
])
CLIPS['DashLeft'] = clip('DashLeft', [(k['t'], rig.mirror(k['pose']), k['ease'], k['name']) for k in CLIPS['DashRight']['keys']])
for c in CLIPS.values():
    c['priority'] = 'Action'

ORDER = ['DashFront', 'DashBack', 'DashLeft', 'DashRight']
