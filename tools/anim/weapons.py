"""Creati's three weapons, each with its own M1 set (four hits, the uppercut,
the downslam) and its 4th move - keyframed for R6 with the weapon in her
right fist (it sits across the fist: the arm spins to aim it; `blade` is
where its business end points, street space: +X right, +Y up, -Z ahead).

SWORD: fast one-handed cuts, the free hand guarding - diagonal down, a rising
backhand, a flat cut across, then a two-handed overhead cleave.
STAFF: two-handed and spinning - a sweep round, the butt end back the other
way, a rising strike from the ground, then an overhead slam.
SPEAR: reach - two thrusts, a low sweep that takes the legs, then a lunging
thrust with everything behind it."""
from m1 import P, merge, clip, OUT, IN, INOUT, LIN, STANCE_WIDE
import rig

CLIPS = {}


def arm(r, a=0, o=0, blade=None, bladeC=None):
    d = {'r': r, 'a': a, 'o': o}
    if blade is not None:
        d['blade'] = blade
    if bladeC is not None:
        d['bladeC'] = bladeC
    return d


def grab(k):
    return {'grab': k}


ORTHO = dict(rl=dict(f=-0.9, s=0.35), ll=dict(f=0.9, s=0.1))
LUNGE = dict(rl=dict(f=-1.2, s=0.3), ll=dict(f=1.2, s=0.05))


def weapon_clip(name, prop, keys, lunge=None):
    c = clip(name, keys, lunge=lunge)
    c['prop'] = prop
    return c

# ============================================================== SWORD
SG = P(body=dict(y=-0.14, twist=-18, lean=5), ra=arm(45, 18, 6, (0.15, 0.55, -0.82)), la=(62, 34, 4), **ORTHO)

CLIPS['SwordM1_1'] = weapon_clip('SwordM1_1', 'Sword', [  # diagonal cut, high right to low left
    (0.0, SG, OUT),
    (0.05, merge(SG, body=dict(y=-0.18, twist=-36, lean=-2), ra=arm(165, -5, 30, (0.25, 0.25, 0.93)), la=(80, 28, 0)), IN),
    (0.095, merge(SG, body=dict(y=-0.26, twist=28, lean=16, fwd=0.2), ra=arm(58, 42, 0, (-0.62, -0.35, -0.7)), la=(36, 12, 30), **STANCE_WIDE), OUT, 'Hit'),
    (0.15, merge(SG, body=dict(y=-0.26, twist=34, lean=18, fwd=0.22), ra=arm(36, 55, 0, (-0.55, -0.7, 0.45)), la=(34, 12, 30), **STANCE_WIDE), INOUT),
    (0.27, merge(SG, body=dict(y=-0.17, twist=2, lean=6), ra=arm(58, 22, 4, (0.1, 0.6, -0.8)), la=(60, 30, 4)), INOUT),
    (0.42, SG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['SwordM1_2'] = weapon_clip('SwordM1_2', 'Sword', [  # rising backhand, low left to high right
    (0.0, SG, OUT),
    (0.055, merge(SG, body=dict(y=-0.22, twist=30, lean=8), ra=arm(40, 60, 0, (-0.6, -0.5, 0.6)), la=(80, 20, 0)), IN),
    (0.105, merge(SG, body=dict(y=-0.22, twist=-30, lean=6, fwd=0.15), ra=arm(120, -30, 20, (0.6, 0.55, -0.55)), la=(40, 30, 20),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), OUT, 'Hit'),
    (0.165, merge(SG, body=dict(y=-0.2, twist=-40, lean=4, fwd=0.17), ra=arm(150, -40, 30, (0.7, 0.7, 0.2)), la=(40, 30, 20),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), INOUT),
    (0.29, merge(SG, body=dict(y=-0.17, twist=-10, lean=6), ra=arm(60, 20, 6, (0.15, 0.55, -0.82))), INOUT),
    (0.44, SG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['SwordM1_3'] = weapon_clip('SwordM1_3', 'Sword', [  # flat cut across, right to left
    (0.0, SG, OUT),
    (0.065, merge(SG, body=dict(y=-0.24, twist=-48, lean=2), ra=arm(88, -5, 10, (0.6, 0.05, 0.8)), la=(70, 40, 0)), IN),
    (0.115, merge(SG, body=dict(y=-0.26, twist=40, lean=12, fwd=0.2), ra=arm(88, -40, 0, (-1.0, 0.05, -0.1)), la=(40, 20, 30), **STANCE_WIDE), OUT, 'Hit'),
    (0.18, merge(SG, body=dict(y=-0.26, twist=52, lean=12, fwd=0.22), ra=arm(86, -7, 0, (-0.7, 0.0, 0.7)), la=(38, 20, 30), **STANCE_WIDE), INOUT),
    (0.3, merge(SG, body=dict(y=-0.17, twist=8, lean=6), ra=arm(60, 22, 6, (0.15, 0.55, -0.82))), INOUT),
    (0.46, SG, INOUT),
], lunge=(0.05, 15, 0.06))

SW_UP = arm(172, 0, 8, (0.05, 0.25, 0.97))
CLIPS['SwordM1_4'] = weapon_clip('SwordM1_4', 'Sword', [  # both hands on it, up over the head, and cleaved down
    (0.0, SG, OUT),
    (0.06, merge(SG, body=dict(y=-0.3, twist=-16, lean=-8), ra=SW_UP, la=grab(-0.35)), OUT),
    (0.1, merge(SG, body=dict(y=-0.36, twist=-20, lean=-12), ra=arm(178, 0, 8, (0.05, 0.1, 1.0)), la=grab(-0.35)), IN),
    (0.15, merge(SG, body=dict(y=-0.5, twist=8, lean=30, fwd=0.5), ra=arm(46, 20, 0, (-0.05, -0.35, -0.93)), la=grab(-0.35), **LUNGE), OUT, 'Hit'),
    (0.23, merge(SG, body=dict(y=-0.5, twist=10, lean=34, fwd=0.52), ra=arm(32, 20, 0, (-0.05, -0.7, -0.7)), la=grab(-0.35), **LUNGE), INOUT),
    (0.4, merge(SG, body=dict(y=-0.46, twist=8, lean=30, fwd=0.48), ra=arm(36, 20, 0, (-0.05, -0.62, -0.78)), la=grab(-0.35), **LUNGE), INOUT),
    (0.58, merge(SG, body=dict(y=-0.2, twist=0, lean=6), ra=arm(55, 20, 4, (0.15, 0.55, -0.82)), la=(60, 30, 4)), INOUT),
    (0.8, SG, INOUT),
], lunge=(0.1, 26, 0.09))

CLIPS['SwordUp'] = weapon_clip('SwordUp', 'Sword', [  # low, then a rising cut that takes her up with it
    (0.0, SG, OUT),
    (0.05, merge(SG, body=dict(y=-0.5, twist=-28, lean=22, tilt=10), ra=arm(-8, 10, 24, (0.2, -0.3, -0.93)), la=(80, 40, 2),
                 rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), OUT),
    (0.085, merge(SG, body=dict(y=-0.56, twist=-32, lean=24, tilt=12), ra=arm(-14, 10, 26, (0.2, -0.35, -0.9)), la=(80, 40, 2),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), IN),
    (0.13, merge(SG, body=dict(y=0.3, twist=22, lean=-14, tilt=-8), ra=arm(140, 6, 4, (0.0, 0.64, 0.77)), la=(-20, 0, 40), rl=(-14, 0, 6), ll=(42, 0, 4)), OUT, 'Hit'),
    (0.2, merge(SG, body=dict(y=0.36, twist=26, lean=-16, tilt=-9), ra=arm(158, 4, 4, (0.0, 0.4, 0.92)), la=(-24, 0, 42), rl=(-16, 0, 6), ll=(46, 0, 4)), INOUT),
    (0.42, merge(SG, body=dict(y=0.22, twist=20, lean=-10, tilt=-6), ra=arm(150, 4, 4, (0.0, 0.5, 0.86)), la=(-18, 0, 38), rl=(-10, 0, 6), ll=(34, 0, 4)), INOUT),
    (0.62, merge(SG, body=dict(y=-0.1, twist=0, lean=2), ra=arm(70, 20, 4, (0.15, 0.55, -0.82)), la=(60, 30, 4)), INOUT),
    (0.82, SG, INOUT),
], lunge=(0.1, 12, 0.09))

AIR = dict(rl=(18, 0, 4), ll=(8, 0, 4))
CLIPS['SwordDown'] = weapon_clip('SwordDown', 'Sword', [  # in the air: raised in both hands, cut straight down
    (0.0, merge(SG, body=dict(y=0, lean=4, twist=0), **AIR), OUT),
    (0.09, merge(SG, body=dict(y=0, lean=-20, twist=0), ra=arm(176, 0, 6, (0.0, 0.2, 0.98)), la=grab(-0.35), rl=(40, 0, 6), ll=(54, 0, 6)), IN),
    (0.14, merge(SG, body=dict(y=0.1, lean=40, twist=0), ra=arm(40, 14, 0, (0.0, -0.6, -0.8)), la=grab(-0.35), rl=(-28, 0, 6), ll=(-14, 0, 6)), OUT, 'Hit'),
    (0.21, merge(SG, body=dict(y=0.1, lean=44, twist=0), ra=arm(30, 14, 0, (0.0, -0.8, -0.6)), la=grab(-0.35), rl=(-32, 0, 6), ll=(-18, 0, 6)), INOUT),
    (0.4, merge(SG, body=dict(y=0.08, lean=38, twist=0), ra=arm(34, 14, 0, (0.0, -0.72, -0.7)), la=grab(-0.35), rl=(-24, 0, 6), ll=(-12, 0, 6)), INOUT),
    (0.62, merge(SG, body=dict(y=0, lean=10, twist=0), ra=arm(60, 20, 4, (0.15, 0.55, -0.82)), la=(60, 30, 4), rl=(12, 0, 4), ll=(4, 0, 4)), INOUT),
    (0.82, merge(SG, body=dict(y=0, lean=4, twist=0), **AIR), INOUT),
], lunge=(0.1, 6, 0.12))

# IAI RUSH (sword 4th): dropped low, blade back by the hip; through them in a
# blur; the cut finished out to the side, held
IAI_LOW = merge(SG, body=dict(y=-0.55, twist=-40, lean=26), ra=arm(-20, -10, 30, (0.2, -0.2, 0.95)), la=(40, 40, 0),
                rl=dict(f=-1.2, s=0.3), ll=dict(f=1.2, s=0.1))
CLIPS['IaiRush'] = weapon_clip('IaiRush', 'Sword', [
    (0.0, SG, OUT),
    (0.08, IAI_LOW, OUT),
    (0.29, merge(IAI_LOW, body=dict(y=-0.5, twist=-44, lean=34, fwd=0.3)), IN),
    (0.33, merge(SG, body=dict(y=-0.42, twist=18, lean=20, fwd=0.3), ra=arm(88, -75, 0, (0.1, 0.0, -1.0)), la=(20, 10, 40), **LUNGE), OUT, 'Hit'),
    (0.52, merge(SG, body=dict(y=-0.4, twist=22, lean=18, fwd=0.3), ra=arm(88, -80, 0, (0.15, 0.0, -0.99)), la=(20, 10, 40), **LUNGE), INOUT),
    (0.64, merge(SG, body=dict(y=-0.36, twist=16, lean=16, fwd=0.26), ra=arm(60, -60, 10, (0.4, -0.5, -0.75)), la=(24, 10, 36), **LUNGE), INOUT),
    (0.84, SG, INOUT),
])

# ============================================================== STAFF
STG = P(body=dict(y=-0.16, twist=-25, lean=6), ra=arm(40, 30, 0, (-0.55, 0.35, -0.75)), la=grab(1.8), **ORTHO)

CLIPS['StaffM1_1'] = weapon_clip('StaffM1_1', 'Staff', [  # a sweep round, right to left, at head height
    (0.0, STG, OUT),
    (0.05, merge(STG, body=dict(y=-0.2, twist=-55, lean=0), ra=arm(70, 0, 10, (0.8, 0.2, 0.55)), la=grab(1.4)), IN),
    (0.095, merge(STG, body=dict(y=-0.26, twist=35, lean=12, fwd=0.2), ra=arm(70, -35, 0, (-0.95, 0.05, -0.3)), la=grab(1.4), **STANCE_WIDE), OUT, 'Hit'),
    (0.15, merge(STG, body=dict(y=-0.26, twist=45, lean=13, fwd=0.22), ra=arm(65, 0, 0, (-0.7, 0.05, 0.7)), la=grab(1.4), **STANCE_WIDE), INOUT),
    (0.27, merge(STG, body=dict(y=-0.18, twist=-5, lean=6)), INOUT),
    (0.42, STG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['StaffM1_2'] = weapon_clip('StaffM1_2', 'Staff', [  # and back the other way: a backhand sweep, left to right
    (0.0, STG, OUT),
    (0.055, merge(STG, body=dict(y=-0.2, twist=40, lean=6), ra=arm(70, 0, 0, (-0.77, 0.1, 0.64)), la=grab(1.5)), IN),
    (0.105, merge(STG, body=dict(y=-0.24, twist=-35, lean=12, fwd=0.15), ra=arm(72, 35, 0, (0.95, 0.05, -0.3)), la=grab(1.5),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), OUT, 'Hit'),
    (0.165, merge(STG, body=dict(y=-0.24, twist=-48, lean=12, fwd=0.17), ra=arm(68, 0, 0, (0.67, 0.05, 0.74)), la=grab(1.5),
                  rl=dict(f=-1.0, s=0.35), ll=dict(f=0.95, s=0.1, turn=-15)), INOUT),
    (0.29, merge(STG, body=dict(y=-0.18, twist=-12, lean=6)), INOUT),
    (0.44, STG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['StaffM1_3'] = weapon_clip('StaffM1_3', 'Staff', [  # the front end brought up from the street
    (0.0, STG, OUT),
    (0.065, merge(STG, body=dict(y=-0.42, twist=-20, lean=18), ra=arm(20, 20, 0, (0.0, -0.55, -0.83)), la=grab(1.6),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.1)), IN),
    (0.115, merge(STG, body=dict(y=-0.05, twist=10, lean=-8), ra=arm(60, 15, 0, (0.0, 0.85, -0.5)), la=grab(1.6),
                  rl=dict(f=-0.7, s=0.3), ll=dict(f=0.8, s=0.1)), OUT, 'Hit'),
    (0.175, merge(STG, body=dict(y=0.0, twist=14, lean=-10), ra=arm(70, 15, 0, (0.0, 0.95, 0.2)), la=grab(1.6),
                  rl=dict(f=-0.7, s=0.3), ll=dict(f=0.8, s=0.1)), INOUT),
    (0.3, merge(STG, body=dict(y=-0.16, twist=-10, lean=4)), INOUT),
    (0.46, STG, INOUT),
], lunge=(0.05, 15, 0.06))

ST_UP = arm(165, 10, 0, (0.0, 0.3, 0.95))
CLIPS['StaffM1_4'] = weapon_clip('StaffM1_4', 'Staff', [  # up over the head in both hands, and slammed down
    (0.0, STG, OUT),
    (0.06, merge(STG, body=dict(y=-0.3, twist=-10, lean=-10), ra=ST_UP, la=grab(1.6)), OUT),
    (0.1, merge(STG, body=dict(y=-0.36, twist=-12, lean=-14), ra=arm(172, 10, 0, (0.0, 0.15, 0.99)), la=grab(1.6)), IN),
    (0.15, merge(STG, body=dict(y=-0.5, twist=5, lean=30, fwd=0.5), ra=arm(50, 25, 0, (-0.1, -0.35, -0.93)), la=grab(1.6), **LUNGE), OUT, 'Hit'),
    (0.23, merge(STG, body=dict(y=-0.5, twist=6, lean=34, fwd=0.52), ra=arm(40, 25, 0, (-0.1, -0.55, -0.83)), la=grab(1.6), **LUNGE), INOUT),
    (0.4, merge(STG, body=dict(y=-0.46, twist=5, lean=30, fwd=0.48), ra=arm(44, 25, 0, (-0.1, -0.5, -0.86)), la=grab(1.6), **LUNGE), INOUT),
    (0.58, merge(STG, body=dict(y=-0.2, twist=-10, lean=6)), INOUT),
    (0.8, STG, INOUT),
], lunge=(0.1, 26, 0.09))

CLIPS['StaffUp'] = weapon_clip('StaffUp', 'Staff', [  # low, then swung up under them as she springs
    (0.0, STG, OUT),
    (0.05, merge(STG, body=dict(y=-0.5, twist=-26, lean=24), ra=arm(14, 20, 0, (0.0, -0.6, -0.8)), la=grab(1.6),
                 rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), OUT),
    (0.085, merge(STG, body=dict(y=-0.56, twist=-30, lean=26), ra=arm(10, 20, 0, (0.0, -0.65, -0.76)), la=grab(1.6),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), IN),
    (0.13, merge(STG, body=dict(y=0.3, twist=12, lean=-14), ra=arm(80, 10, 0, (0.0, 0.98, -0.1)), la=grab(1.6), rl=(-14, 0, 6), ll=(42, 0, 4)), OUT, 'Hit'),
    (0.2, merge(STG, body=dict(y=0.36, twist=14, lean=-16), ra=arm(96, 10, 0, (0.0, 0.95, 0.3)), la=grab(1.6), rl=(-16, 0, 6), ll=(46, 0, 4)), INOUT),
    (0.42, merge(STG, body=dict(y=0.22, twist=10, lean=-10), ra=arm(90, 10, 0, (0.0, 0.96, 0.2)), la=grab(1.6), rl=(-10, 0, 6), ll=(34, 0, 4)), INOUT),
    (0.62, merge(STG, body=dict(y=-0.1, twist=-10, lean=2)), INOUT),
    (0.82, STG, INOUT),
], lunge=(0.1, 12, 0.09))

CLIPS['StaffDown'] = weapon_clip('StaffDown', 'Staff', [  # in the air: raised, then brought down like an axe
    (0.0, merge(STG, body=dict(y=0, lean=4, twist=-10), **AIR), OUT),
    (0.09, merge(STG, body=dict(y=0, lean=-20, twist=-6), ra=arm(172, 10, 0, (0.0, 0.2, 0.98)), la=grab(1.6), rl=(40, 0, 6), ll=(54, 0, 6)), IN),
    (0.14, merge(STG, body=dict(y=0.1, lean=40, twist=0), ra=arm(44, 20, 0, (-0.05, -0.6, -0.8)), la=grab(1.6), rl=(-28, 0, 6), ll=(-14, 0, 6)), OUT, 'Hit'),
    (0.21, merge(STG, body=dict(y=0.1, lean=44, twist=0), ra=arm(36, 20, 0, (-0.05, -0.8, -0.6)), la=grab(1.6), rl=(-32, 0, 6), ll=(-18, 0, 6)), INOUT),
    (0.4, merge(STG, body=dict(y=0.08, lean=38, twist=0), ra=arm(40, 20, 0, (-0.05, -0.72, -0.7)), la=grab(1.6), rl=(-24, 0, 6), ll=(-12, 0, 6)), INOUT),
    (0.62, merge(STG, body=dict(y=0, lean=10, twist=-10), rl=(12, 0, 4), ll=(4, 0, 4)), INOUT),
    (0.82, merge(STG, body=dict(y=0, lean=4, twist=-10), **AIR), INOUT),
], lunge=(0.1, 6, 0.12))

# STRIKE AND STOP (staff 4th): wound up, then a full turn with the staff held
# out level - it sweeps round her - and planted upright at the end: STOP
SPIN = dict(legs='chest')
WHIRL = arm(84, 0, 0, bladeC=(1.0, 0.05, 0.0))
CLIPS['StrikeAndStop'] = weapon_clip('StrikeAndStop', 'Staff', [
    (0.0, STG, OUT),
    (0.1, merge(STG, body=dict(SPIN, y=-0.24, twist=-70, lean=6), ra=WHIRL, la=(60, 30, 20), rl=(0, 0, 8), ll=(0, 0, 8)), IN),
    (0.15, merge(STG, body=dict(SPIN, y=-0.26, twist=20, lean=8), ra=WHIRL, la=(60, 30, 20), rl=(0, 0, 8), ll=(0, 0, 8)), LIN, 'Hit'),
    (0.2, merge(STG, body=dict(SPIN, y=-0.26, twist=110, lean=8), ra=WHIRL, la=(60, 30, 20), rl=(0, 0, 8), ll=(0, 0, 8)), LIN),
    (0.25, merge(STG, body=dict(SPIN, y=-0.26, twist=200, lean=8), ra=WHIRL, la=(60, 30, 20), rl=(0, 0, 8), ll=(0, 0, 8)), LIN),
    (0.3, merge(STG, body=dict(SPIN, y=-0.26, twist=290, lean=8), ra=WHIRL, la=(60, 30, 20), rl=(0, 0, 8), ll=(0, 0, 8)), LIN),
    (0.36, merge(STG, body=dict(y=-0.3, twist=360 + 10, lean=4), ra=arm(30, -10, 20, (0.1, 1.0, 0.0)), la=(70, 40, 0), **ORTHO), OUT),
    (0.56, merge(STG, body=dict(y=-0.28, twist=360 + 8, lean=3), ra=arm(30, -10, 20, (0.1, 1.0, 0.0)), la=(70, 40, 0), **ORTHO), INOUT),
    (0.78, merge(STG, body=dict(twist=360 - 25)), INOUT),
])

# ============================================================== SPEAR
SPG = P(body=dict(y=-0.16, twist=-30, lean=6), ra=arm(22, 10, 0, (0.0, 0.12, -1.0)), la=grab(2.2), **ORTHO)

CLIPS['SpearM1_1'] = weapon_clip('SpearM1_1', 'Spear', [  # a jab
    (0.0, SPG, OUT),
    (0.05, merge(SPG, body=dict(y=-0.2, twist=-40, lean=0, fwd=-0.2), ra=arm(-15, 5, 0, (0.0, 0.05, -1.0)), la=grab(2.4)), IN),
    (0.095, merge(SPG, body=dict(y=-0.26, twist=10, lean=14, fwd=0.35), ra=arm(45, 15, 0, (0.0, 0.02, -1.0)), la=grab(2.0), **STANCE_WIDE), OUT, 'Hit'),
    (0.15, merge(SPG, body=dict(y=-0.26, twist=14, lean=15, fwd=0.4), ra=arm(50, 15, 0, (0.0, 0.0, -1.0)), la=grab(2.0), **STANCE_WIDE), INOUT),
    (0.27, merge(SPG, body=dict(y=-0.18, twist=-24, lean=6), ra=arm(15, 10, 0, (0.0, 0.1, -1.0))), INOUT),
    (0.42, SPG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['SpearM1_2'] = weapon_clip('SpearM1_2', 'Spear', [  # a second thrust, higher, stepping through
    (0.0, SPG, OUT),
    (0.055, merge(SPG, body=dict(y=-0.22, twist=-46, lean=-2, fwd=-0.2), ra=arm(-10, 0, 10, (0.0, 0.2, -0.98)), la=grab(2.4)), IN),
    (0.105, merge(SPG, body=dict(y=-0.24, twist=16, lean=12, fwd=0.4), ra=arm(62, 18, 0, (0.0, 0.22, -0.98)), la=grab(1.9),
                  rl=dict(f=-1.2, s=0.3), ll=dict(f=1.1, s=0.05)), OUT, 'Hit'),
    (0.165, merge(SPG, body=dict(y=-0.24, twist=20, lean=13, fwd=0.44), ra=arm(66, 18, 0, (0.0, 0.2, -0.98)), la=grab(1.9),
                  rl=dict(f=-1.2, s=0.3), ll=dict(f=1.1, s=0.05)), INOUT),
    (0.29, merge(SPG, body=dict(y=-0.18, twist=-24, lean=6), ra=arm(15, 10, 0, (0.0, 0.1, -1.0))), INOUT),
    (0.44, SPG, INOUT),
], lunge=(0.05, 15, 0.06))

CLIPS['SpearM1_3'] = weapon_clip('SpearM1_3', 'Spear', [  # swung round low, right to left, at the legs
    (0.0, SPG, OUT),
    (0.065, merge(SPG, body=dict(y=-0.3, twist=-60, lean=8), ra=arm(50, -50, 20, (0.85, -0.2, 0.45)), la=grab(1.6)), IN),
    (0.115, merge(SPG, body=dict(y=-0.34, twist=40, lean=16, fwd=0.2), ra=arm(55, 40, 0, (-0.85, -0.2, -0.5)), la=grab(1.6), **STANCE_WIDE), OUT, 'Hit'),
    (0.18, merge(SPG, body=dict(y=-0.34, twist=55, lean=16, fwd=0.22), ra=arm(50, 55, 0, (-0.6, -0.15, 0.78)), la=grab(1.6), **STANCE_WIDE), INOUT),
    (0.3, merge(SPG, body=dict(y=-0.2, twist=-20, lean=6)), INOUT),
    (0.46, SPG, INOUT),
], lunge=(0.05, 15, 0.06))

SP_BACK = merge(SPG, body=dict(y=-0.3, twist=-55, lean=-6, fwd=-0.3), ra=arm(-30, 0, 6, (0.0, 0.08, -1.0)), la=grab(3.0))
SP_OUT = merge(SPG, body=dict(y=-0.5, twist=15, lean=24, fwd=0.7), ra=arm(60, 18, 0, (0.0, 0.0, -1.0)), la=grab(2.0), **LUNGE)
CLIPS['SpearM1_4'] = weapon_clip('SpearM1_4', 'Spear', [  # drawn right back, then a lunging thrust with everything behind it
    (0.0, SPG, OUT),
    (0.06, SP_BACK, OUT),
    (0.1, merge(SP_BACK, body=dict(y=-0.34, twist=-60, lean=-8, fwd=-0.36)), IN),
    (0.15, SP_OUT, OUT, 'Hit'),
    (0.23, merge(SP_OUT, body=dict(y=-0.5, twist=18, lean=26, fwd=0.76), ra=arm(64, 18, 0, (0.0, 0.0, -1.0))), INOUT),
    (0.4, merge(SP_OUT, body=dict(y=-0.46, twist=14, lean=22, fwd=0.7)), INOUT),
    (0.58, merge(SPG, body=dict(y=-0.2, twist=-20, lean=6)), INOUT),
    (0.8, SPG, INOUT),
], lunge=(0.1, 26, 0.09))

CLIPS['SpearUp'] = weapon_clip('SpearUp', 'Spear', [  # the point swept up under them as she springs
    (0.0, SPG, OUT),
    (0.05, merge(SPG, body=dict(y=-0.5, twist=-30, lean=22), ra=arm(10, 12, 10, (0.0, -0.45, -0.9)), la=grab(2.0),
                 rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), OUT),
    (0.085, merge(SPG, body=dict(y=-0.56, twist=-34, lean=24), ra=arm(6, 12, 10, (0.0, -0.5, -0.87)), la=grab(2.0),
                  rl=dict(f=-0.8, s=0.5), ll=dict(f=0.9, s=0.15)), IN),
    (0.13, merge(SPG, body=dict(y=0.3, twist=10, lean=-14), ra=arm(70, 12, 0, (0.0, 0.94, -0.35)), la=grab(1.8), rl=(-14, 0, 6), ll=(42, 0, 4)), OUT, 'Hit'),
    (0.2, merge(SPG, body=dict(y=0.36, twist=12, lean=-16), ra=arm(84, 12, 0, (0.0, 0.99, 0.1)), la=grab(1.8), rl=(-16, 0, 6), ll=(46, 0, 4)), INOUT),
    (0.42, merge(SPG, body=dict(y=0.22, twist=10, lean=-10), ra=arm(80, 12, 0, (0.0, 0.98, 0.0)), la=grab(1.8), rl=(-10, 0, 6), ll=(34, 0, 4)), INOUT),
    (0.62, merge(SPG, body=dict(y=-0.1, twist=-20, lean=2)), INOUT),
    (0.82, SPG, INOUT),
], lunge=(0.1, 12, 0.09))

CLIPS['SpearDown'] = weapon_clip('SpearDown', 'Spear', [  # in the air: raised, point down, driven down into them
    (0.0, merge(SPG, body=dict(y=0, lean=4, twist=-10), **AIR), OUT),
    (0.09, merge(SPG, body=dict(y=0, lean=-14, twist=-6), ra=arm(150, 0, 6, (0.0, -0.4, -0.92)), la=grab(1.6), rl=(40, 0, 6), ll=(54, 0, 6)), IN),
    (0.14, merge(SPG, body=dict(y=0.1, lean=36, twist=0), ra=arm(40, 14, 0, (0.0, -0.92, -0.38)), la=grab(1.6), rl=(-28, 0, 6), ll=(-14, 0, 6)), OUT, 'Hit'),
    (0.21, merge(SPG, body=dict(y=0.1, lean=40, twist=0), ra=arm(34, 14, 0, (0.0, -0.96, -0.28)), la=grab(1.6), rl=(-32, 0, 6), ll=(-18, 0, 6)), INOUT),
    (0.4, merge(SPG, body=dict(y=0.08, lean=36, twist=0), ra=arm(36, 14, 0, (0.0, -0.94, -0.33)), la=grab(1.6), rl=(-24, 0, 6), ll=(-12, 0, 6)), INOUT),
    (0.62, merge(SPG, body=dict(y=0, lean=10, twist=-10), rl=(12, 0, 4), ll=(4, 0, 4)), INOUT),
    (0.82, merge(SPG, body=dict(y=0, lean=4, twist=-10), **AIR), INOUT),
], lunge=(0.1, 6, 0.12))

# PIERCING THRUST (spear 4th): drawn back, then everything into one thrust, held
CLIPS['PiercingThrust'] = weapon_clip('PiercingThrust', 'Spear', [
    (0.0, SPG, OUT),
    (0.12, merge(SP_BACK, body=dict(y=-0.36, twist=-62, lean=-8, fwd=-0.4)), IN),
    (0.17, merge(SP_OUT, body=dict(y=-0.52, twist=18, lean=26, fwd=0.8)), OUT, 'Hit'),
    (0.45, merge(SP_OUT, body=dict(y=-0.5, twist=16, lean=24, fwd=0.76)), INOUT),
    (0.7, SPG, INOUT),
])

ORDER = [
    'SwordM1_1', 'SwordM1_2', 'SwordM1_3', 'SwordM1_4', 'SwordUp', 'SwordDown', 'IaiRush',
    'StaffM1_1', 'StaffM1_2', 'StaffM1_3', 'StaffM1_4', 'StaffUp', 'StaffDown', 'StrikeAndStop',
    'SpearM1_1', 'SpearM1_2', 'SpearM1_3', 'SpearM1_4', 'SpearUp', 'SpearDown', 'PiercingThrust',
]
