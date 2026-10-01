"""The M1 combo (the Brawler set most heroes fight with), keyframed for R6.

Timing is locked to the game: the client's hit smear and the server's hitbox
land ~0.1s after the click (0.15s on the 4th), and the next click can come at
0.28s. So every hit is: a coil (anticipation) the eye can catch, a 2-3 frame
snap, a held CONTACT key (named "Hit"; hitstop freezes it longer on a
connect), a follow-through past it, and a recoil that ends in the guard - the
recoil of one hit is the wind-up of the next, so a chain flows.
"""


def P(**kw):
    return kw


def merge(base, **kw):
    out = {k: (dict(v) if isinstance(v, dict) else v) for k, v in base.items()}
    for k, v in kw.items():
        if k == 'body' and isinstance(out.get(k), dict):
            b = dict(out[k]); b.update(v); out[k] = b
        else:
            out[k] = v
    return out


OUT = ('CubicV2', 'Out')
IN = ('CubicV2', 'In')
INOUT = ('CubicV2', 'InOut')
LIN = ('Linear', 'In')

# hands: straight R6 arms reach the chin only held about level
RG = (70, 38, 6)    # right fist up in front of the chest
LG = (80, 30, 4)    # left (lead) fist a little higher and further out

# the fighting guard every hit starts from and settles back into: bladed a
# little (right shoulder back), knees soft, lead (left) foot forward
GUARD = P(
    body=dict(y=-0.14, twist=-16, lean=5),
    ra=RG, la=LG,
    rl=dict(f=-0.9, s=0.35), ll=dict(f=0.9, s=0.1),
)
STANCE_WIDE = dict(rl=dict(f=-1.1, s=0.3), ll=dict(f=1.0, s=0.05))


def clip(name, keys, lunge=None):
    c = {'name': name, 'keys': [], 'lunge': lunge}
    for k in keys:
        t, pose = k[0], k[1]
        ease = k[2] if len(k) > 2 else INOUT
        c['keys'].append({'t': t, 'pose': pose, 'ease': ease, 'name': k[3] if len(k) > 3 else 'Keyframe'})
    return c


CLIPS = {}

# 1: RIGHT STRAIGHT - drop the right fist back and sink onto the rear foot,
# then hips and chest snap round and the fist drives dead ahead at chest
# height; the left hand comes home to the chin
CLIPS['M1Brawler1'] = clip('M1Brawler1', [
    (0.0, GUARD, OUT),
    (0.05, merge(GUARD, body=dict(y=-0.2, twist=-32, lean=2, fwd=-0.08), ra=(50, 12, 16), la=(100, 20, 2)), IN),
    (0.095, merge(GUARD, body=dict(y=-0.24, twist=36, lean=10, fwd=0.2), ra=(98, 14, 0), la=(104, 56, 0), **STANCE_WIDE), OUT, 'Hit'),
    (0.15, merge(GUARD, body=dict(y=-0.24, twist=41, lean=12, fwd=0.22), ra=(100, 12, 0), la=(104, 58, 0), **STANCE_WIDE), INOUT),
    (0.27, merge(GUARD, body=dict(y=-0.17, twist=6, lean=7), ra=(84, 28, 4), la=(96, 30, 2)), INOUT),
    (0.42, GUARD, INOUT),
], lunge=(0.05, 15, 0.06))

# 2: LEFT HOOK - the chest winds left and the left arm swings out wide at
# the side, level; then the body whips right and the arm sweeps round
# through the front (the contact) and on across
CLIPS['M1Brawler2'] = clip('M1Brawler2', [
    (0.0, GUARD, OUT),
    (0.055, merge(GUARD, body=dict(y=-0.2, twist=30, lean=4, tilt=-6), la=(96, -78, 4), ra=(74, 56, 2)), IN),
    (0.105, merge(GUARD, body=dict(y=-0.24, twist=-26, lean=9, tilt=5, fwd=0.15), la=(98, -12, 2), ra=(80, 58, 0),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), OUT, 'Hit'),
    (0.165, merge(GUARD, body=dict(y=-0.24, twist=-42, lean=10, tilt=6, fwd=0.17), la=(96, 22, 2), ra=(80, 58, 0),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), INOUT),
    (0.29, merge(GUARD, body=dict(y=-0.17, twist=-14, lean=6), la=(88, 28, 2), ra=(74, 44, 4)), INOUT),
    (0.44, GUARD, INOUT),
], lunge=(0.05, 15, 0.06))

# 3: RIGHT UPPERCUT - sink low with the right shoulder dropped and the fist
# down by the hip, then drive up through the legs: the body rises and leans
# back as the fist comes up in front of the face and on over the head
CLIPS['M1Brawler3'] = clip('M1Brawler3', [
    (0.0, GUARD, OUT),
    (0.065, merge(GUARD, body=dict(y=-0.44, twist=-30, lean=20, tilt=10), ra=(-6, 0, 18), la=(100, 40, 2),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.1)), IN),
    (0.115, merge(GUARD, body=dict(y=-0.03, twist=24, lean=-9, tilt=-8), ra=(160, 18, 0), la=(90, 44, 2),
                  rl=dict(f=-0.7, s=0.3), ll=dict(f=0.8, s=0.1)), OUT, 'Hit'),
    (0.175, merge(GUARD, body=dict(y=0.0, twist=28, lean=-12, tilt=-9), ra=(168, 14, 0), la=(88, 44, 2),
                  rl=dict(f=-0.7, s=0.3), ll=dict(f=0.8, s=0.1)), INOUT),
    (0.3, merge(GUARD, body=dict(y=-0.15, twist=4, lean=3), ra=(108, 32, 2), la=(96, 30, 2)), INOUT),
    (0.46, GUARD, INOUT),
], lunge=(0.05, 15, 0.06))

# 4: THE POWER STRAIGHT (finisher) - a big coil you can read from across
# the street: the right fist drawn right back and low, the left arm out
# pointing at them; then everything goes into it - a long lunge, the chest
# thrown round, the left arm yanked back behind, held
CLIPS['M1Brawler4'] = clip('M1Brawler4', [
    (0.0, GUARD, OUT),
    (0.06, merge(GUARD, body=dict(y=-0.32, twist=-52, lean=-2, fwd=-0.2, tilt=4), ra=(34, -6, 30), la=(98, 4, 0),
                 rl=dict(f=-1.0, s=0.4, turn=20), ll=dict(f=1.0, s=0.1)), OUT),
    (0.1, merge(GUARD, body=dict(y=-0.36, twist=-58, lean=-4, fwd=-0.26, tilt=5), ra=(28, -8, 34), la=(98, 2, 0),
                rl=dict(f=-1.0, s=0.4, turn=20), ll=dict(f=1.0, s=0.1)), IN),
    (0.15, merge(GUARD, body=dict(y=-0.46, twist=58, lean=18, fwd=0.55), ra=(97, 10, 0), la=(-32, 8, 34),
                 rl=dict(f=-1.2, s=0.3), ll=dict(f=1.2, s=0.05)), OUT, 'Hit'),
    (0.23, merge(GUARD, body=dict(y=-0.46, twist=63, lean=20, fwd=0.58), ra=(99, 8, 0), la=(-36, 8, 36),
                 rl=dict(f=-1.2, s=0.3), ll=dict(f=1.2, s=0.05)), INOUT),
    (0.4, merge(GUARD, body=dict(y=-0.43, twist=56, lean=17, fwd=0.5), ra=(96, 10, 0), la=(-28, 8, 32),
                rl=dict(f=-1.2, s=0.3), ll=dict(f=1.2, s=0.05)), INOUT),
    (0.58, merge(GUARD, body=dict(y=-0.2, twist=8, lean=6), ra=(80, 30, 4), la=(76, 30, 4)), INOUT),
    (0.8, GUARD, INOUT),
], lunge=(0.1, 26, 0.09))

# UPPERCUT (jump held into the 4th): sink deep, then spring off the street -
# the whole body rises clear of it, leaning back, the fist straight up over
# the head, the lead knee up
CLIPS['M1Uppercut'] = clip('M1Uppercut', [
    (0.0, GUARD, OUT),
    (0.05, merge(GUARD, body=dict(y=-0.5, twist=-28, lean=24, tilt=12), ra=(-20, 0, 20), la=(100, 40, 2),
                 rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), OUT),
    (0.085, merge(GUARD, body=dict(y=-0.56, twist=-32, lean=26, tilt=13), ra=(-24, 0, 22), la=(100, 42, 2),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), IN),
    (0.13, merge(GUARD, body=dict(y=0.3, twist=24, lean=-16, tilt=-10), ra=(174, 8, 0), la=(-24, 0, 40),
                 rl=(-14, 0, 6), ll=(42, 0, 4)), OUT, 'Hit'),
    (0.2, merge(GUARD, body=dict(y=0.36, twist=28, lean=-18, tilt=-11), ra=(178, 6, 0), la=(-28, 0, 42),
                rl=(-16, 0, 6), ll=(46, 0, 4)), INOUT),
    (0.42, merge(GUARD, body=dict(y=0.22, twist=22, lean=-11, tilt=-8), ra=(170, 6, 0), la=(-20, 0, 38),
                 rl=(-10, 0, 6), ll=(34, 0, 4)), INOUT),
    (0.62, merge(GUARD, body=dict(y=-0.1, twist=0, lean=2), ra=(104, 30, 2), la=(84, 30, 2)), INOUT),
    (0.82, GUARD, INOUT),
], lunge=(0.1, 12, 0.09))

# DOWNSLAM (the 4th thrown in the air): both fists up over the head, arched
# back, knees tucked - then hammered down in front, the body folding over
# them and the legs kicking out behind
AIR = P(body=dict(y=0.0, lean=4), ra=RG, la=LG, rl=(18, 0, 4), ll=(8, 0, 4))
CLIPS['M1Downslam'] = clip('M1Downslam', [
    (0.0, AIR, OUT),
    (0.09, merge(AIR, body=dict(lean=-20), ra=(174, 14, 0), la=(174, 14, 0), rl=(40, 0, 6), ll=(54, 0, 6)), IN),
    (0.14, merge(AIR, body=dict(lean=40, y=0.1), ra=(40, 14, 0), la=(40, 14, 0), rl=(-28, 0, 6), ll=(-14, 0, 6)), OUT, 'Hit'),
    (0.21, merge(AIR, body=dict(lean=44, y=0.1), ra=(32, 14, 0), la=(32, 14, 0), rl=(-32, 0, 6), ll=(-18, 0, 6)), INOUT),
    (0.4, merge(AIR, body=dict(lean=38, y=0.08), ra=(38, 14, 0), la=(38, 14, 0), rl=(-24, 0, 6), ll=(-12, 0, 6)), INOUT),
    (0.62, merge(AIR, body=dict(lean=10), ra=(84, 30, 2), la=(84, 30, 2), rl=(12, 0, 4), ll=(4, 0, 4)), INOUT),
    (0.82, AIR, INOUT),
], lunge=(0.1, 6, 0.12))

ORDER = ['M1Brawler1', 'M1Brawler2', 'M1Brawler3', 'M1Brawler4', 'M1Uppercut', 'M1Downslam']
