"""Round 108: new R6 animations for the Touhou slots whose originals can't be
used on the new account (they belong to the group Ivory Boat and to the
account generalprinciple) - so Mokou and Remilia move again.

Only the 80 slots the game really plays are made: the moves' attacker and
victim clips, the reactions their hits play on whoever they hit, and the
afterimages. (Their M1s and dashes run on the game's own M1 system - the
Touhou scripts only ever stop those - and the wings, the spinning spear and
the camera rigs aren't R6 bodies.) Each clip is a NEW animation in the move's
spirit (a kick where theirs kicked, a spear where hers stabs), timed to the
move's own script: the beatdowns last the move's AttackLength and the
victim's hits land with the attacker's.

Built on tools/anim (rig.py's pose language, moves_lib's beats):
    python3 standin108.py out.json      (then: lune run standin108.luau out.json <dir>)
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'anim'))
from moves_lib import P, merge, REST, blend, over, seq, OUT, IN, INOUT  # noqa: E402
import moves_common as MC  # noqa: E402
import rig  # noqa: E402

LIN = ('Linear', 'In')
LUNGE = MC.LUNGE
BRACE = MC.BRACE
AIR = dict(legs='chest')  # (off the ground: the legs move with the body)


def k(t, pose, ease=INOUT, name='Keyframe'):
    return (round(t, 4), pose, ease, name)


def mir(pose):
    return rig.mirror(pose)


# ------------------------------------------------------------------ poses

# MOKOU: hands in her pockets until she kicks; fire from the palms
POCKETS = P(body=dict(y=-0.04, lean=-3), ra=(-10, 8, 6), la=(-10, 8, 6), rl=dict(f=-0.15, s=0.3), ll=dict(f=0.2, s=0.25))
COIL_K = P(body=dict(y=-0.5, lean=18, twist=-14), ra=(-40, 0, 20), la=(-36, 0, 22), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.6, s=0.25))
CHAMBER = P(body=dict(y=-0.12, lean=8, twist=-10), ra=(-20, 0, 26), la=(46, 22, 14), rl=(70, 0, 6), ll=dict(f=0.05, s=0.2))
K_FRONT = MC.KICK
K_ROUND = P(body=dict(y=-0.05, twist=50, lean=-10, tilt=-22), ra=(-20, 0, 35), la=(50, -20, 40), rl=(85, 30, 45), ll=dict(f=0.1, s=0.15))
K_ROUND_W = P(body=dict(y=-0.2, twist=-30, lean=6, tilt=6), ra=(-10, 0, 30), la=(40, 10, 30), rl=(40, -10, 10), ll=dict(f=0.1, s=0.2))
K_SIDE = P(body=dict(y=-0.05, twist=70, tilt=-24, lean=-6), ra=(20, 0, 48), la=(70, 30, 10), rl=(92, 0, 10), ll=dict(f=0.0, s=0.15))
K_AXE_UP = P(body=dict(lean=-22), rl=(160, 0, 5), ra=(40, 0, 45), la=(40, 0, 45), ll=dict(f=0, s=0.2))
K_AXE_DOWN = P(body=dict(y=-0.35, lean=24, fwd=0.2), rl=dict(f=1.0, s=0.3), ll=dict(f=-0.4, s=0.25), ra=(10, 0, 40), la=(10, 0, 40))
K_KNEE = P(body=dict(y=-0.05, lean=12), ra=(80, 20, 0), la=(80, 20, 0), rl=(118, 0, 2), ll=dict(f=-0.1, s=0.2))
K_FLY = P(body=dict(AIR, y=0.5, lean=-25), rl=(95, 0, 0), ll=(35, 0, 8), ra=(-30, 0, 40), la=(60, 30, 10))
K_FLY_W = P(body=dict(AIR, y=0.4, lean=10), rl=(60, 0, 6), ll=(70, 0, 8), ra=(-50, 0, 30), la=(-40, 0, 30))
DROPKICK = P(body=dict(AIR, pivot='center', y=0.1, lean=-70), rl=(92, 0, 6), ll=(88, 0, 10), ra=(150, 0, 30), la=(150, 0, 30), head=(30, 0, 0))
STOMP = MC.STOMP
STOMP_W = P(body=dict(y=0.0, lean=-8, tilt=8), ra=(40, 0, 40), la=(40, 0, 40), rl=(82, 0, 8), ll=dict(f=-0.05, s=0.25))
PALMS = MC.BLAST
PALM_R = P(body=dict(y=-0.28, twist=40, lean=14, fwd=0.35), ra=(92, 0, 0, -90), la=(-20, 0, 20), **LUNGE)
PALM_W = P(body=dict(y=-0.2, twist=-30, lean=2, fwd=-0.1), ra=(40, -10, 30), la=(60, 30, 10), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.7, s=0.15))
FIRE_UP = MC.ARMS_UP
COUNTER = P(body=dict(y=-0.2, lean=-10, twist=-14), ra=(-10, 8, 6), la=(-10, 8, 6), head=(-6, 0, 0), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.5, s=0.25))
GRAB_LIFT = P(body=dict(y=0.05, lean=-10, twist=10), ra=(150, 10, 0), la=(60, 30, 10), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.5, s=0.2))
SLAM_DOWN = merge(MC.GROUND, body=dict(y=-0.95, lean=48, fwd=0.35), ra=(40, 14, 4), la=(40, 14, 4))

# REMILIA: Gungnir in the right hand (stabs, sweeps, throws), claws, wings
SP_HIGH = P(body=dict(y=-0.1, twist=-30, lean=-10), ra=(175, -15, 20), la=(70, 20, 20), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.6, s=0.2))
SP_DOWN = P(body=dict(y=-0.3, twist=35, lean=22, fwd=0.3), ra=(40, 25, 0), la=(-20, 0, 30), **LUNGE)
SP_THRUST = P(body=dict(y=-0.3, twist=30, lean=15, fwd=0.45), ra=(94, 4, 0), la=(80, 40, 0), **LUNGE)
SP_BACK = P(body=dict(y=-0.32, twist=-34, lean=6, fwd=-0.1), ra=(40, -20, 30), la=(70, 30, 6), rl=dict(f=-0.9, s=0.4), ll=dict(f=0.6, s=0.15))
SP_SWEEP_W = P(body=dict(y=-0.2, twist=-45, lean=4), ra=(90, -75, 10), la=(60, 20, 20), rl=dict(f=-0.7, s=0.4), ll=dict(f=0.6, s=0.2))
SP_SWEEP = P(body=dict(y=-0.25, twist=45, lean=10, fwd=0.2), ra=(88, 70, 0), la=(-10, 0, 30), **LUNGE)
CLAW_W = P(body=dict(y=-0.15, twist=30, lean=4), la=(150, -20, 20), ra=(60, 20, 20), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.6, s=0.2))
CLAW = P(body=dict(y=-0.3, twist=-35, lean=18, fwd=0.3), la=(50, 30, 0), ra=(-10, 0, 30), **LUNGE)
KISS = P(body=dict(y=-0.3, lean=34, fwd=0.5), ra=(100, 22, 0), la=(100, 22, 0), head=(-10, 0, 0), **LUNGE)
KISS_W = P(body=dict(y=-0.55, lean=24, fwd=-0.1), ra=(-30, 0, 30), la=(-30, 0, 30), rl=dict(f=-0.9, s=0.35), ll=dict(f=0.5, s=0.25))
BITE = P(body=dict(y=-0.05, lean=16, twist=8), ra=(86, 46, 0), la=(84, 48, 0), head=(28, 18, 6), rl=dict(f=-0.5, s=0.3), ll=dict(f=0.4, s=0.2))
HOVER = P(body=dict(AIR, y=0.45, lean=4), ra=(20, 0, 34), la=(20, 0, 34), rl=(12, 0, 4), ll=(-6, 0, 4), head=(6, 0, 0))
ELEGANT = P(body=dict(y=-0.02, lean=-6, twist=-10), ra=(80, 68, 0), la=(74, 70, 0), head=(-8, -10, 0), rl=dict(f=-0.1, s=0.15), ll=dict(f=0.25, s=0.05))
THROW_W = MC.WIND_T
THROWN = MC.THROWN
SIDEARM_W = P(body=dict(y=-0.22, twist=-50, lean=0), ra=(80, -60, 20), la=(70, 30, 10), rl=dict(f=-0.9, s=0.4), ll=dict(f=0.7, s=0.15))
SIDEARM = P(body=dict(y=-0.25, twist=50, lean=16, fwd=0.3), ra=(80, 40, 0), la=(-20, 0, 30), **LUNGE)
DIVE = MC.DIVE
UPPER = MC.UPPER

# the hit body
DAZED = P(body=dict(y=-0.12, lean=6), head=(10, 0, 0), ra=(4, 0, 12), la=(4, 0, 10), rl=dict(f=-0.15, s=0.3), ll=dict(f=0.15, s=0.25))
FL_BACK = P(body=dict(y=-0.1, lean=-16), head=(-26, 0, 0), ra=(30, 0, 30), la=(20, 0, 24), rl=dict(f=-0.35, s=0.3), ll=dict(f=0.1, s=0.25))
FL_GUT = P(body=dict(y=-0.25, lean=32), head=(18, 0, 0), ra=(40, 30, 10), la=(40, 30, 10), rl=dict(f=-0.3, s=0.3), ll=dict(f=0.2, s=0.25))
FL_TWIST = P(body=dict(y=-0.15, twist=28, tilt=14, lean=4), head=(0, 30, 12), ra=(15, 0, 40), la=(50, -10, 20), rl=dict(f=-0.25, s=0.3), ll=dict(f=0.2, s=0.25))
FLINCHES = [FL_BACK, FL_GUT, FL_TWIST, mir(FL_TWIST)]
FL_AIR = P(body=dict(AIR, y=0.5, lean=-30), rl=(30, 0, 10), ll=(55, 0, 10), ra=(140, 0, 30), la=(120, 0, 35), head=(-20, 0, 0))
FLUNG = P(body=dict(AIR, pivot='center', lean=-50, y=0.6), head=(18, 0, 0), ra=(100, 0, 40), la=(90, 0, 45), rl=(40, 0, 10), ll=(60, 0, 10))
DOWN_BACK = P(body=dict(AIR, pivot='center', lean=-90, y=-2.45), ra=(10, 0, 30), la=(10, 0, 25), rl=(0, 0, 8), ll=(0, 0, 6), head=(0, 0, 0))
DOWN_FRONT = P(body=dict(AIR, pivot='center', lean=90, y=-2.45), ra=(20, 0, 30), la=(-10, 0, 25), rl=(0, 0, 8), ll=(0, 0, 6), head=(0, 0, 0))
LIFTED = P(body=dict(AIR, y=0.6, lean=-8), head=(-25, 0, 0), ra=(115, 30, 0), la=(110, 30, 0), rl=(8, 0, 4), ll=(-6, 0, 4))
KNEEL = P(body=dict(y=-1.15, lean=14), head=(14, 0, 0), ra=(10, 0, 18), la=(14, 0, 16), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.55, s=0.3))


# ------------------------------------------------------------------ clips

def release(name, wind, hit, dur, prio='Action3', settle=None, end=REST, t_wind=None, start=REST):
    """A wind-up, the snap into the strike (a touch past it), held, then home."""
    tw = t_wind if t_wind is not None else min(0.32, dur * 0.3)
    th = tw + 0.08
    hold = max(th + 0.12, dur * 0.68)
    return seq(name, [k(0, start, OUT), k(tw, wind, IN), k(th, over(wind, hit, 0.1), OUT, 'Hit'), k(th + 0.08, hit),
                      k(hold, settle if settle is not None else hit), k(dur, end)], prio)


def whiff(name, wind, hit, dur, prio='Action3'):
    """The strike finds nothing: carried on past it, a stumble, back to the stance."""
    tw = min(0.3, dur * 0.28)
    th = tw + 0.08
    past = merge(blend(wind, hit, 1.3), body=dict(lean=hit.get('body', {}).get('lean', 0) + 14))
    return seq(name, [k(0, REST, OUT), k(tw, wind, IN), k(th, hit, OUT, 'Hit'), k(th + 0.14, past, OUT),
                      k(th + 0.34, blend(past, DAZED, 0.5)), k(dur, REST)], prio)


def hold(name, pose, dur=1.0, loop=True, prio='Action3', deep=1.06, t_in=0.18):
    """Into a pose and held, breathing (looped when the move holds it)."""
    if loop:
        return dict(seq(name, [k(0, pose), k(dur * 0.5, blend(REST, pose, deep)), k(dur, pose)], prio), loop=True)
    return seq(name, [k(0, REST, OUT), k(t_in, over(REST, pose, 0.08), OUT), k(t_in + 0.1, pose),
                      k(dur, blend(REST, pose, deep))], prio)


def static(name, pose, dur=0.27, prio='Action'):
    """One pose, held (the afterimages)."""
    return seq(name, [k(0, pose, LIN), k(dur, pose, LIN)], prio)


def hit_times(dur, n, first=0.25, last_gap=0.6):
    """When a beatdown's n hits land: spread over the move, the last a finisher."""
    if n <= 1:
        return [first]
    end = max(first + 0.1 * n, dur - last_gap)
    return [first + (end - first) * i / (n - 1) for i in range(n)]


def flurry(name, strikes, dur, n, finisher=None, start=REST, end=REST, prio='Action3'):
    """A beatdown: n strikes (cycling through `strikes`, each a (wind, hit)
    pair) spread over the move, the last one the finisher, then home."""
    ts = hit_times(dur, n)
    keys = [k(0, start, OUT)]
    for i, t in enumerate(ts):
        last = i == len(ts) - 1
        w, h = finisher if (last and finisher) else strikes[i % len(strikes)]
        lead = 0.16 if last else min(0.09, (ts[1] - ts[0]) * 0.45 if len(ts) > 1 else 0.09)
        keys.append(k(t - lead, w, IN))
        keys.append(k(t, over(w, h, 0.1), OUT, 'Hit'))
        if last:
            keys.append(k(t + 0.1, h))
            keys.append(k(max(t + 0.2, dur - 0.18), h))
        else:
            gap = ts[i + 1] - t
            if gap > 0.32:
                keys.append(k(t + min(0.12, gap * 0.35), h))
                if gap > 0.7:  # (a beat between bursts)
                    keys.append(k(t + gap * 0.6, blend(h, start if start is not REST else POCKETS, 0.6)))
    keys.append(k(dur, end))
    return seq(name, _ordered(keys), prio)


def victim(name, dur, n, end='down_back', base=None, prio='Action4', heavy=False):
    """Taking a beatdown: a flinch on each of its hits (in time with the
    attacker's), dazed between them, then knocked down (or flung, or left
    standing)."""
    base = base if base is not None else DAZED
    ts = hit_times(dur, n)
    keys = [k(0, base, OUT)]
    for i, t in enumerate(ts):
        last = i == len(ts) - 1
        f = FLINCHES[i % len(FLINCHES)]
        if base is LIFTED:
            f = merge(LIFTED, head=f.get('head'), ra=f.get('ra'), la=f.get('la'),
                      body=dict(lean=-8 + (f['body'].get('lean', 0) * 0.6), twist=f['body'].get('twist', 0) * 0.6))
        if heavy:
            f = blend(base, f, 1.35)
        if last:
            break
        keys.append(k(t + 0.02, f, OUT))
        gap = ts[i + 1] - t
        if gap > 0.25:
            keys.append(k(t + min(0.2, gap * 0.6), blend(f, base, 0.6)))
    tf = ts[-1]
    if end == 'down_back':
        keys += [k(tf + 0.03, FLUNG, OUT, 'Hit'), k(tf + 0.35, DOWN_BACK, IN), k(max(tf + 0.5, dur), DOWN_BACK)]
    elif end == 'down_front':
        keys += [k(tf + 0.03, FL_GUT, OUT, 'Hit'), k(tf + 0.3, KNEEL, IN), k(tf + 0.6, DOWN_FRONT, IN), k(max(tf + 0.75, dur), DOWN_FRONT)]
    elif end == 'launch':
        keys += [k(tf + 0.03, FL_AIR, OUT, 'Hit'), k(tf + 0.3, FLUNG), k(max(tf + 0.45, dur), FLUNG)]
    else:
        keys += [k(tf + 0.03, FL_BACK, OUT, 'Hit'), k(tf + 0.3, blend(FL_BACK, DAZED, 0.6)), k(max(tf + 0.45, dur), REST)]
    return seq(name, _ordered(keys), prio)


def _ordered(keys):
    """Times strictly increasing (a key that would land on or before the last is nudged after it)."""
    out = []
    for key in keys:
        t = key[0]
        if out and t <= out[-1][0]:
            t = out[-1][0] + 1 / 60
        out.append((round(t, 4),) + tuple(key[1:]))
    return out


def reaction(name, pose, dur=0.45, prio='Action2', big=False):
    """A hit reaction: snapped into it, a wobble, back up."""
    p = blend(DAZED, pose, 1.4) if big else pose
    return seq(name, [k(0, REST, OUT), k(0.05, over(REST, p, 0.12), OUT, 'Hit'), k(0.14, p),
                      k(dur * 0.65, blend(p, DAZED, 0.6)), k(dur, REST)], prio)


def spin(name, base, dur, turns=1.0, rise=0.0, t0=0.0, arms=None, prio='Action3'):
    """The whole body spun round (keys a quarter turn apart - Roblox goes the
    short way between keys), rising by `rise` studs."""
    steps = max(1, int(round(turns * 4)))
    keys = [k(0, base, OUT)] if t0 > 0 else []
    for i in range(steps + 1):
        u = i / steps
        b = dict(base.get('body', {}))
        b.update(AIR, roll=0)
        b['twist'] = b.get('twist', 0) + 360 * turns * u
        b['y'] = b.get('y', 0) + rise * math.sin(math.pi * u)
        p = merge(base, body=b)
        if arms is not None:
            p = merge(p, ra=arms[0], la=arms[1])
        keys.append(k(t0 + (dur - t0) * u * 0.9, p, LIN))
    keys.append(k(dur, REST))
    return seq(name, _ordered(keys), prio)


# ------------------------------------------------------------------ the 80

KICKS = [(CHAMBER, K_FRONT), (K_ROUND_W, K_ROUND), (CHAMBER, K_SIDE), (mir(CHAMBER), mir(K_FRONT)), (K_ROUND_W, K_KNEE), (mir(K_ROUND_W), mir(K_ROUND))]
AIRKICKS = [(K_FLY_W, K_FLY), (mir(K_FLY_W), mir(K_FLY)), (K_FLY_W, merge(K_FLY, rl=(70, 0, 30), body=dict(AIR, y=0.5, lean=-30, twist=40)))]
STOMPS = [(STOMP_W, STOMP), (K_AXE_UP, K_AXE_DOWN)]
SPEAR = [(SP_HIGH, SP_DOWN), (SP_SWEEP_W, SP_SWEEP), (SP_BACK, SP_THRUST), (CLAW_W, CLAW), (mir(CLAW_W), mir(CLAW))]
SCRAMBLE = [(CLAW_W, CLAW), (mir(CLAW_W), mir(CLAW)), (SP_BACK, SP_THRUST), (CHAMBER, K_FRONT), (SP_SWEEP_W, SP_SWEEP), (SP_HIGH, SP_DOWN)]

C = {}


def add(old_id, slot, clip):
    clip['name'] = '%s %s' % (old_id, slot)
    clip['slot'] = slot
    C[old_id] = clip


# --- Mokou (Immortal Blaze) ---
add('88554512282085', 'Mokou Skill1.StartupGrab', release('', COIL_K, K_FLY, 0.9))
add('81340248017777', 'Mokou Skill1.Success', flurry('', AIRKICKS, 71 / 60, 4, finisher=(K_AXE_UP, merge(K_AXE_DOWN, body=dict(AIR, y=0.2, lean=24))), start=K_FLY_W))
add('105167650055806', 'Mokou Skill1.Victim', victim('', 71 / 60, 4, end='launch'))
add('113818101455706', 'Mokou Skill1.Victim2', seq('', [k(0, DAZED, OUT), k(0.08, FL_AIR, OUT, 'Hit'), k(0.5, blend(FL_AIR, FLUNG, 0.5)), k(1.0, FLUNG)], 'Action4'))
add('86208985982958', 'Mokou Skill2.Release', whiff('', COIL_K, K_SIDE, 0.95))
add('103437648238860', 'Mokou Skill2.Success', flurry('', KICKS + STOMPS, 315 / 60, 13, finisher=(K_ROUND_W, K_ROUND), start=POCKETS))
add('70374968022434', 'Mokou Skill2.Victim', victim('', 315 / 60, 13))
add('95589433738932', 'Mokou Awakening.Skill2.Release', release('', MC.REV, DROPKICK, 0.95))
add('123548284046255', 'Mokou Awakening.Skill2.Success', flurry('', [(STOMP_W, STOMP), (CHAMBER, K_FRONT), (K_ROUND_W, K_KNEE), (K_ROUND_W, K_ROUND)], 400 / 60, 15,
                                                                finisher=(MC.REV, DROPKICK), start=POCKETS))
add('85675893869792', 'Mokou Awakening.Skill3.Release', whiff('', PALM_W, PALM_R, 0.9))
add('99058026163893', 'Mokou Awakening.Skill3.Success', flurry('', [(PALM_W, PALM_R)] + KICKS[:3], 200 / 60, 8, finisher=(COIL_K, K_AXE_UP)))
add('90572488446664', 'Mokou Awakening.Skill3.Victim', victim('', 200 / 60, 8, end='launch'))
add('100156864186007', 'Mokou Awakening.Skill4.Release', hold('', COUNTER, 1.2, loop=False))
add('112685577131623', 'Mokou Awakening.Skill4.Success', flurry('', KICKS + [(PALM_W, PALM_R)] + STOMPS, 451 / 60, 16, finisher=(MC.REV, DROPKICK), start=COUNTER))
add('137680639825079', 'Mokou Awakening.Skill4.Victim', victim('', 451 / 60, 16))
add('95546273858325', 'Mokou Skill2OLD.Success', flurry('', KICKS, 2.5, 6, finisher=(K_ROUND_W, K_ROUND)))
add('117826107919894', 'Mokou Skill2OLD.Victim', victim('', 2.5, 6))
# FUJIYAMA VOLCANO: grabbed up, slammed into the street, stomped, the fire set off under them
add('126770669106638', 'Mokou Skill3.Success', seq('', _ordered([
    k(0, POCKETS, OUT), k(0.2, MC.GRAB, OUT), k(0.55, GRAB_LIFT, INOUT), k(0.8, merge(GRAB_LIFT, ra=(175, 0, 0), body=dict(lean=-16))),
    k(0.95, SLAM_DOWN, OUT, 'Hit'), k(1.15, SLAM_DOWN),
    k(1.35, STOMP_W, IN), k(1.45, STOMP, OUT, 'Hit'), k(1.7, STOMP_W, IN), k(1.8, STOMP, OUT, 'Hit'),
    k(2.05, STOMP_W, IN), k(2.15, STOMP, OUT, 'Hit'), k(2.5, MC.COWL, IN), k(2.75, MC.ARMS_UP, OUT, 'Hit'),
    k(3.3, MC.ARMS_UP), k(210 / 60, REST)]), 'Action3'))
add('113503086858505', 'Mokou Skill3.Victim', seq('', _ordered([
    k(0, DAZED, OUT), k(0.25, FL_GUT, OUT), k(0.55, LIFTED), k(0.8, merge(LIFTED, body=dict(AIR, y=1.0, lean=-20))),
    k(0.97, DOWN_BACK, OUT, 'Hit'), k(1.47, merge(DOWN_BACK, ra=(40, 0, 50), head=(-20, 0, 0)), OUT), k(1.6, DOWN_BACK),
    k(1.82, merge(DOWN_BACK, la=(40, 0, 50), rl=(20, 0, 10)), OUT), k(1.95, DOWN_BACK), k(2.17, merge(DOWN_BACK, ra=(50, 0, 40), la=(40, 0, 50)), OUT),
    k(2.3, DOWN_BACK), k(2.77, FLUNG, OUT, 'Hit'), k(3.1, DOWN_BACK, IN), k(210 / 60, DOWN_BACK)]), 'Action4'))
add('110485203042029', 'Mokou Specialnew.Release', release('', MC.COIL, PALMS, 0.75, t_wind=0.2))
add('73755645375655', 'Mokou Specialnew.ReleaseTa', release('', PALM_W, PALM_R, 0.75, t_wind=0.2))
add('136545287121629', 'Mokou Awakening.DeathAnim', seq('', [
    k(0, REST, OUT), k(0.08, FL_BACK, OUT), k(0.4, blend(FL_BACK, FL_GUT, 0.5)), k(0.75, KNEEL, IN), k(1.05, merge(KNEEL, body=dict(y=-1.3, lean=30))),
    k(1.4, FLUNG, IN), k(1.7, DOWN_BACK, OUT), k(3.0, DOWN_BACK)], 'Action4'))
for i, (oid, pose) in enumerate([('106595932906570', K_FRONT), ('112214037939666', K_ROUND), ('119770714667862', K_FLY), ('126650249505888', K_SIDE)], 1):
    add(oid, 'BLSR %d (afterimage)' % i, static('', pose))

# --- Remilia (Scarlet Empress) ---
# the awakening (14 s): arms folded, she rises off the street, spins, spreads
# her arms (the wings), calls Gungnir up into her hand and points it at them
AW = []
AW += [k(0, REST, OUT), k(0.6, ELEGANT), k(2.4, merge(ELEGANT, head=(-14, -20, 0)))]
AW += [k(3.2, merge(HOVER, ra=(30, 0, 40), la=(30, 0, 40))), k(4.6, merge(HOVER, body=dict(AIR, y=0.75, lean=0)))]
_spin = spin('', merge(HOVER, body=dict(AIR, y=0.75)), 1.8, turns=2, rise=0.25)
AW += [(4.7 + kk['t'], kk['pose'], kk['ease'], kk['name']) for kk in _spin['keys'][:-1]]
AW += [k(6.8, merge(HOVER, body=dict(AIR, y=0.9, lean=-10), ra=(110, -20, 60), la=(110, -20, 60), head=(-20, 0, 0)), OUT, 'Hit'),
       k(8.6, merge(HOVER, body=dict(AIR, y=0.95, lean=-12), ra=(116, -24, 64), la=(116, -24, 64), head=(-24, 0, 0)))]
AW += [k(9.4, merge(HOVER, body=dict(AIR, y=0.9), ra=(176, 0, 10), la=(40, 0, 40), head=(-30, 0, 0))), k(11.0, merge(HOVER, body=dict(AIR, y=0.9), ra=(178, 0, 8), la=(40, 0, 40)))]
AW += [k(11.5, merge(HOVER, body=dict(AIR, y=0.7, twist=30, lean=10), ra=(92, 4, 0), la=(-20, 0, 30)), OUT, 'Hit'), k(13.4, merge(HOVER, body=dict(AIR, y=0.6, twist=30, lean=10), ra=(92, 4, 0), la=(-20, 0, 30)))]
AW += [k(844 / 60 + 0.25, REST)]
add('134413792479820', 'Remilia Awakening.AwakenAnim', seq('', _ordered(AW), 'Action4'))
# NIGHTLESS CASTLE
add('96049252470351', 'Remilia Awakening.Skill1.STARTNEW', hold('', merge(HOVER, ra=(110, -20, 60), la=(110, -20, 60)), 1.2, loop=False))
add('81935136729809', 'Remilia Awakening.Skill1.MISSNEW', whiff('', SP_HIGH, SP_DOWN, 1.0))
add('112049695372365', 'Remilia Awakening.Skill1.SUCCESSNEW', flurry('', SPEAR, 143 / 60, 6, finisher=(SP_BACK, SP_THRUST)))
add('121396696849223', 'Remilia Awakening.Skill1.VICTIMNEW', victim('', 143 / 60, 6, end='launch'))
# SCARLET PIERCE (a counter)
add('103901385332562', 'Remilia Awakening.Skill2.Cast', hold('', ELEGANT, 1.0, loop=False))
add('122942537936440', 'Remilia Awakening.Skill2.Success', flurry('', [(SP_BACK, SP_THRUST), (SP_HIGH, SP_DOWN), (SP_SWEEP_W, SP_SWEEP)], 359 / 60, 12,
                                                                 finisher=(THROW_W, THROWN), start=ELEGANT))
add('102560249007590', 'Remilia Awakening.Skill2.Victim', victim('', 359 / 60, 12))
# SCARLET IRON SEPULCHRE (Bad Lady Scramble): a long, wild rush of claws, spear and kicks
add('130196013814350', 'Remilia Awakening.Skill3.Release', release('', KISS_W, MC.RUSH, 1.0))
add('118826387368191', 'Remilia Awakening.Skill3.Release2', whiff('', CLAW_W, CLAW, 1.0))
add('118941982890586', 'Remilia Awakening.Skill3.Success', flurry('', SCRAMBLE, 940 / 60, 34, finisher=(SP_HIGH, SP_DOWN)))
add('96621879258942', 'Remilia Awakening.Skill3.Victim', victim('', 940 / 60, 34))
# MISERABLE MULTITUDE: up into the air, and spear after spear thrown down at them
MM = [k(0, REST, OUT), k(0.5, MC.COWL, IN), k(0.9, merge(HOVER, body=dict(AIR, y=1.0, lean=-6), ra=(150, -10, 30), la=(150, -10, 30)), OUT)]
t = 1.6
for i in range(9):
    w, h = (THROW_W, THROWN) if i % 2 == 0 else (mir(THROW_W), mir(THROWN))
    w = merge(w, body=dict(w['body'], **AIR, y=0.9))
    h = merge(h, body=dict(h['body'], **AIR, y=0.9, lean=h['body'].get('lean', 0) + 12))
    MM += [k(t, w, IN), k(t + 0.1, h, OUT, 'Hit')]
    t += 0.5
MM += [k(t + 0.3, merge(HOVER, body=dict(AIR, y=1.0), ra=(178, 0, 6), la=(40, 0, 40))), k(t + 1.0, merge(HOVER, body=dict(AIR, y=1.0), ra=(178, 0, 6), la=(40, 0, 40))),
       k(t + 1.15, merge(THROWN, body=dict(THROWN['body'], **AIR, y=0.8, lean=36)), OUT, 'Hit'), k(487 / 60 - 0.3, merge(THROWN, body=dict(THROWN['body'], **AIR, y=0.6, lean=30))),
       k(487 / 60, REST)]
add('104021859653778', 'Remilia Awakening.Skill4.Release', seq('', _ordered(MM), 'Action4'))
# VAMPIRIC KISS: a lunge for the neck, a bite, thrown off
add('116694727194817', 'Remilia Skill1.Release', release('', KISS_W, KISS, 0.9))
add('95005368970029', 'Remilia Skill1.Release2New', whiff('', KISS_W, KISS, 1.0))
add('129581595461291', 'Remilia Skill1.ReleaseNew', dict(seq('', [k(0, KISS), k(0.2, merge(KISS, body=dict(y=-0.25, lean=38, fwd=0.55), ra=(104, 18, 0), la=(98, 26, 0))), k(0.4, KISS)], 'Action3'), loop=True))
BITE2 = merge(BITE, head=(36, 22, 8), body=dict(y=-0.08, lean=20, twist=10))
add('139557574586154', 'Remilia Skill1.Success', seq('', _ordered([
    k(0, KISS, OUT), k(0.2, BITE, OUT), k(0.6, BITE2, OUT, 'Hit'), k(1.0, BITE), k(1.3, BITE2, OUT, 'Hit'), k(1.7, BITE),
    k(1.85, SP_SWEEP_W, IN), k(1.95, MC.BLAST, OUT, 'Hit'), k(2.25, MC.BLAST), k(143 / 60, REST)]), 'Action3'))
add('118580204277633', 'Remilia Skill1.SuccessNew', seq('', [k(0, KISS, OUT), k(0.15, BITE, OUT), k(0.45, BITE2, OUT, 'Hit'), k(0.85, BITE), k(1.2, BITE2)], 'Action3'))
add('88799907085956', 'Remilia Skill1.SuccessNewFinisher', seq('', [k(0, BITE), k(0.3, BITE2, OUT, 'Hit'), k(0.6, BITE), k(0.75, SP_SWEEP_W, IN),
                                                                    k(0.85, MC.BLAST, OUT, 'Hit'), k(1.2, MC.BLAST), k(1.5, REST)], 'Action3'))
BITTEN = merge(LIFTED, body=dict(AIR, y=0.25, lean=-14, twist=-10), head=(-20, -30, -14), ra=(60, 20, 30), la=(70, 10, 30))
BITTEN2 = merge(BITTEN, head=(-28, -36, -18), ra=(90, 30, 20), la=(30, 0, 40))
add('117926942626963', 'Remilia Skill1.Victim', seq('', _ordered([
    k(0, DAZED, OUT), k(0.2, BITTEN, OUT), k(0.62, BITTEN2, OUT, 'Hit'), k(1.0, BITTEN), k(1.32, BITTEN2, OUT, 'Hit'), k(1.7, BITTEN),
    k(1.97, FLUNG, OUT, 'Hit'), k(2.25, DOWN_BACK, IN), k(143 / 60, DOWN_BACK)]), 'Action4'))
add('105347340587524', 'Remilia Skill1.VictimNew', seq('', [k(0, DAZED, OUT), k(0.15, BITTEN, OUT), k(0.47, BITTEN2, OUT, 'Hit'), k(0.85, BITTEN), k(1.2, BITTEN2)], 'Action4'))
add('72323173649922', 'Remilia Skill1.VictimNewFinisher', seq('', [k(0, BITTEN), k(0.32, BITTEN2, OUT, 'Hit'), k(0.6, BITTEN), k(0.87, FLUNG, OUT, 'Hit'),
                                                                   k(1.15, DOWN_BACK, IN), k(1.5, DOWN_BACK)], 'Action4'))
# HEARTBREAK: Gungnir cocked back and thrown (close: stabbed in)
add('109175025011855', 'Remilia Skill2.Hold', hold('', THROW_W, 0.9))
add('78481800158366', 'Remilia Skill2.HoldClose', hold('', SP_BACK, 0.9))
add('78332699411211', 'Remilia Skill2.NewRelease', release('', THROW_W, THROWN, 0.8, t_wind=0.08, start=THROW_W))
add('109368316634074', 'Remilia Skill2.Release', release('', SIDEARM_W, SIDEARM, 0.8, t_wind=0.12))
add('115916590606773', 'Remilia Skill2.ReleaseClose', release('', SP_BACK, SP_THRUST, 0.8, t_wind=0.08, start=SP_BACK))
add('71532812870582', 'Remilia Skill2.CloseVariant', release('', SP_BACK, SP_THRUST, 1.0))
add('113153033751095', 'Remilia Skill2.Success', flurry('', [(SP_BACK, SP_THRUST), (SP_SWEEP_W, SP_SWEEP), (SP_HIGH, SP_DOWN)], 282 / 60, 7,
                                                       finisher=(merge(SP_HIGH, ra=(178, 0, 10), body=dict(y=0.05, lean=-14)), merge(SLAM_DOWN, ra=(60, 10, 0), la=(-20, 0, 30)))))
add('99010286305154', 'Remilia Skill2.Victim', victim('', 282 / 60, 7, heavy=True))
# SCARLET STINGER / DEMON KING CRADLE
add('73712744544567', 'Remilia Skill3.Release', hold('', MC.COWL, 0.8, loop=False, t_in=0.12))
add('117759742720341', 'Remilia Skill3.Success', spin('', merge(UPPER, body=dict(UPPER['body'], y=0.3)), 1.0, turns=2, rise=0.9, arms=((170, 10, 0), (60, -10, 60))))
add('132231122450051', 'Remilia Skill3.Victim', seq('', [k(0, DAZED, OUT), k(0.08, FL_GUT, OUT, 'Hit'), k(0.3, FL_AIR, OUT), k(0.75, FLUNG), k(1.0, FLUNG)], 'Action4'))
add('114694958626815', 'Remilia Skill3.NEWSTAB', hold('', merge(SP_BACK, body=dict(y=-0.5, twist=-40, lean=14, fwd=-0.15)), 0.5, loop=False, t_in=0.1))
add('131184751372079', 'Remilia Skill3.NEWHIT', release('', SP_BACK, SP_THRUST, 0.8, t_wind=0.04, start=SP_BACK))
add('125013873256822', 'Remilia Skill3.NEWMISS', whiff('', SP_BACK, SP_THRUST, 0.9))
add('119788919749366', 'Remilia Skill3.NEWVICTIM', seq('', [k(0, DAZED, OUT), k(0.06, FL_GUT, OUT, 'Hit'), k(0.3, blend(FL_GUT, FLUNG, 0.4)), k(0.55, FLUNG), k(0.8, FLUNG)], 'Action4'))
SP_AIR_UP = merge(SP_HIGH, body=dict(AIR, y=0.6, lean=-14, twist=-20), ra=(178, -10, 10), la=(150, 0, 30), rl=(30, 0, 10), ll=(50, 0, 10))
add('72980469747201', 'Remilia Skill3.NEWAIRVARIANTSTARTUP', hold('', SP_AIR_UP, 0.5, loop=False, t_in=0.1))
add('130187509617447', 'Remilia Skill3.NEWAIRVARIANTSLAM', release('', SP_AIR_UP, merge(SLAM_DOWN, ra=(50, 10, 0), la=(-20, 0, 30)), 0.8, t_wind=0.05, start=SP_AIR_UP))
# MIDNIGHT KING (Ceiling Fear): up, and down onto them
add('78489585784552', 'Remilia Skill4.Startup', hold('', merge(HOVER, body=dict(AIR, y=0.9, lean=-10), ra=(170, 0, 20), la=(170, 0, 20)), 0.8, loop=False, t_in=0.15))
add('82871872174505', 'Remilia Skill4.StartupNew', hold('', merge(HOVER, body=dict(AIR, y=0.9, lean=12), ra=(-40, 0, 40), la=(-40, 0, 40)), 0.8, loop=False, t_in=0.15))
add('85755598829892', 'Remilia Skill4.Success', seq('', [k(0, merge(HOVER, body=dict(AIR, y=0.9)), OUT), k(0.15, DIVE, IN), k(0.3, SLAM_DOWN, OUT, 'Hit'),
                                                        k(0.75, SLAM_DOWN), k(0.95, merge(SP_HIGH, body=dict(y=-0.3))), k(1.05, SP_DOWN, OUT, 'Hit'), k(76 / 60, REST)], 'Action3'))
add('71464565385340', 'Remilia Skill4.Victim', seq('', [k(0, DAZED, OUT), k(0.3, FLUNG, OUT, 'Hit'), k(0.45, DOWN_BACK, OUT), k(1.05, merge(DOWN_BACK, ra=(50, 0, 40), head=(-24, 0, 0)), OUT, 'Hit'),
                                                       k(1.15, DOWN_BACK), k(76 / 60, DOWN_BACK)], 'Action4'))
# MILLENIUM VAMPIRE
add('109739299132189', 'Remilia Special.Hit', release('', CLAW_W, CLAW, 0.9))
add('97264893487499', 'Remilia Special.Release', whiff('', CLAW_W, CLAW, 0.9))
add('117322473499719', 'Remilia Special.ReleaseNew', release('', mir(CLAW_W), mir(CLAW), 0.9))

# --- the reactions their hits play on whoever they hit ---
for oid, pose, n in [('126666515307802', FL_BACK, 1), ('89450561243568', FL_GUT, 2), ('88734040000550', FL_TWIST, 3), ('87273756597526', mir(FL_TWIST), 4)]:
    add(oid, 'Reactions.Reaction%d' % n, reaction('', pose))
for oid, pose, n in [('77776207323955', FL_BACK, 1), ('106205693845137', FL_GUT, 2), ('113715472766145', FL_TWIST, 3), ('106025773955713', mir(FL_TWIST), 4)]:
    add(oid, 'ReactionsCrazy.Reaction%d' % n, reaction('', pose, dur=0.6, big=True))

ORDER = sorted(C, key=lambda i: C[i]['slot'])

if __name__ == '__main__':
    assert len(C) == 80, len(C)
    out = []
    for oid in ORDER:
        c = C[oid]
        ts = [kk['t'] for kk in c['keys']]
        assert all(b > a for a, b in zip(ts, ts[1:])), (oid, ts)
        j = rig.to_json(c)
        j['id'] = oid
        j['slot'] = c['slot']
        out.append(j)
    json.dump(out, open(sys.argv[1], 'w'))
    print(sys.argv[1], len(out), 'clips', sum(len(c['keys']) for c in out), 'keys',
          'longest %.2fs' % max(c['keys'][-1]['t'] for c in out))
