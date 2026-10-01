"""Idle / walk / run / sprint loops (and the fighting-stance idle), keyframed
for R6. The game plays them from the locomotion layer: the cycles are all in
phase (0 = the right foot reaching forward), blended by speed and played at
the rate that keeps the planted foot still on the street (STRIDE studs per
cycle); backing up runs them in reverse, going sideways turns the legs."""
import math
from m1 import P, merge, clip, GUARD
import rig

LIN = ('Linear', 'In')
L = 2.0  # hip pivot to sole
N = 16   # keys per cycle


def cyc(name, length, pose_at, n=N):
    keys = []
    for i in range(n + 1):
        u = i / n
        keys.append((round(length * u, 5), pose_at(u % 1.0), LIN))
    c = clip(name, keys)
    c['loop'] = True
    c['priority'] = 'Movement'
    return c


def stride(amp):
    return 4 * L * math.sin(math.radians(amp))


CLIPS = {}
STRIDES = {}

# WALK: easy and loose - the stride from the hips, the arms swinging a beat
# behind, the shoulders turning against the hips, a bob (lowest as the feet
# spread), weight rolling over the planted foot
WALK_A = 24


def walk(u):
    c = math.cos(2 * math.pi * u)
    s2 = math.sin(4 * math.pi * u)
    leg = WALK_A * c
    bob = -L * (1 - math.cos(math.radians(leg))) - 0.02
    arm_c = math.cos(2 * math.pi * (u - 0.04))
    return P(body=dict(y=bob, lean=3, twist=-5 * c, tilt=1.2 * math.sin(2 * math.pi * u), side=0.04 * math.sin(2 * math.pi * u)),
             ra=(4 - 20 * arm_c, 0, 6), la=(4 + 20 * arm_c, 0, 6),
             rl=(leg, 0, 3 + 2 * max(0.0, s2)), ll=(-leg, 0, 3 + 2 * max(0.0, -s2)))


CLIPS['LocoWalk'] = cyc('LocoWalk', 0.95, walk)
STRIDES['LocoWalk'] = stride(WALK_A)

# RUN: forward lean, big arm drive (more forward than back), a flight
# phase (the body high as the legs spread, both feet off the street)
RUN_A = 40


def run_arm(u):
    # forward drive bigger than the back swing, a beat behind the legs
    c = math.cos(2 * math.pi * (u - 0.05))
    return 52 * c if c > 0 else 40 * c


def run(u):
    c = math.cos(2 * math.pi * u)
    s = math.sin(2 * math.pi * u)
    leg = RUN_A * c
    lift = 0.07 * math.cos(4 * math.pi * u) - 0.02
    return P(body=dict(y=lift, lean=11, twist=-9 * c, tilt=1.5 * s),
             head=(-8, 0, 0),
             ra=(10 - run_arm(u), 0, 10), la=(10 - run_arm(u + 0.5), 0, 10),
             rl=(leg + 6 * max(0.0, s), 0, 4), ll=(-leg + 6 * max(0.0, -s), 0, 4))


CLIPS['LocoRun'] = cyc('LocoRun', 0.34, run)
STRIDES['LocoRun'] = stride(RUN_A)

# SPRINT: the anime run - thrown well forward, both arms straight back and
# trailing, long fast strides, eyes up on where you're going
SPRINT_A = 52


def sprint(u):
    c = math.cos(2 * math.pi * u)
    leg = SPRINT_A * c
    lift = 0.1 * math.cos(4 * math.pi * u) - 0.02
    wob = math.sin(2 * math.pi * u)
    return P(body=dict(y=lift, lean=32, twist=-6 * c, tilt=1.5 * wob, fwd=0.2),
             head=(-24, 0, 0),
             ra=(-78 + 5 * wob, 0, 12), la=(-78 - 5 * wob, 0, 12),
             rl=(leg + 8 * max(0.0, wob), 0, 4), ll=(-leg + 8 * max(0.0, -wob), 0, 4))


CLIPS['LocoSprint'] = cyc('LocoSprint', 0.3, sprint)
STRIDES['LocoSprint'] = stride(SPRINT_A)

# IDLE: settled, feet apart, breathing; the weight drifts from foot to foot
def idle(u):
    b = math.sin(2 * math.pi * u)            # one breath
    w = math.sin(2 * math.pi * (u + 0.1))    # the weight, foot to foot
    return P(body=dict(y=-0.03 + 0.025 * b, lean=1.2 * b, side=0.05 * w, tilt=1.2 * w),
             ra=(3 + 2 * b, 0, 7 + 1.5 * b), la=(3 + 2 * b, 0, 7 + 1.5 * b),
             rl=dict(f=0.05, s=0.15), ll=dict(f=-0.05, s=0.15))


CLIPS['LocoIdle'] = cyc('LocoIdle', 3.2, idle, n=12)

# FIGHTING IDLE (just fought): the M1 guard, bouncing on the toes
def fight(u):
    b = math.sin(2 * math.pi * u)
    return merge(GUARD, body=dict(y=-0.14 - 0.05 * max(0.0, b) + 0.02, twist=-16 + 2 * b, lean=5 + b),
                 ra=(70 + 3 * b, 38, 6), la=(80 + 3 * b, 30, 4))


CLIPS['LocoFight'] = cyc('LocoFight', 0.62, fight, n=8)

for c in CLIPS.values():
    c['priority'] = 'Movement'

ORDER = ['LocoIdle', 'LocoFight', 'LocoWalk', 'LocoRun', 'LocoSprint']
