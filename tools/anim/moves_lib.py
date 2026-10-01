"""Building blocks for the heroes' move clips (round 63), on top of rig.py's
pose language (see m1.py). A move is choreographed as beats - an
anticipation the eye can read, a snap into the strike (a key named "Hit"),
an overshoot, the held contact, a follow-through that carries the turn, and
the settle - with the feet planted on the street (legs as f/s spots) and the
body's weight shifted onto them.

blend(a, b, t) interpolates two poses' numbers (t > 1 extrapolates: an
overshoot; t < 0 a counter-move)."""
from m1 import P, merge, clip, OUT, IN, INOUT, LIN
import rig

REST = P()
STANCE = P(body=dict(y=-0.1), rl=dict(f=-0.35, s=0.3), ll=dict(f=0.35, s=0.2))
BODY_KEYS = ('y', 'fwd', 'side', 'lean', 'twist', 'tilt')


def _lerp(a, b, t):
    return a + (b - a) * t


def _limb(v):
    if v is None:
        return (0, 0, 0, 0)
    if isinstance(v, dict):
        return v
    v = list(v) + [0, 0, 0, 0]
    return tuple(v[:4])


def blend(a, b, t):
    out = {}
    ba, bb = a.get('body', {}), b.get('body', {})
    body = {}
    for k in BODY_KEYS:
        va, vb = ba.get(k, 0), bb.get(k, 0)
        if va or vb:
            body[k] = _lerp(va, vb, t)
    for k in ('pivot', 'legs'):
        if k in bb or k in ba:
            body[k] = bb.get(k, ba.get(k)) if t >= 0.5 else ba.get(k, bb.get(k))
    out['body'] = body
    ha, hb = a.get('head'), b.get('head')
    if ha is not None or hb is not None:
        ha = ha if ha is not None else (0, 0, 0)
        hb = hb if hb is not None else (0, 0, 0)
        out['head'] = tuple(_lerp(x, y, t) for x, y in zip(list(ha) + [0] * 3, list(hb) + [0] * 3))[:3]
    for key in ('ra', 'la'):
        va, vb = a.get(key), b.get(key)
        if va is None and vb is None:
            continue
        la, lb = _limb(va), _limb(vb)
        if isinstance(la, dict) or isinstance(lb, dict):
            out[key] = vb if t >= 0.5 else va
        else:
            out[key] = tuple(_lerp(x, y, t) for x, y in zip(la, lb))
    for key in ('rl', 'll'):
        va, vb = a.get(key, {'f': 0, 's': 0}), b.get(key, {'f': 0, 's': 0})
        if isinstance(va, dict) and isinstance(vb, dict):
            out[key] = {k: _lerp(va.get(k, 0), vb.get(k, 0), t) for k in set(va) | set(vb)}
        elif not isinstance(va, dict) and not isinstance(vb, dict):
            out[key] = tuple(_lerp(x, y, t) for x, y in zip(_limb(va), _limb(vb)))
        else:
            out[key] = vb if t >= 0.5 else va
    return out


def over(prev, hit, k=0.12):
    """The strike carried a touch past itself."""
    return blend(prev, hit, 1 + k)


def seq(name, keys, priority='Action'):
    c = clip(name, keys)
    c['priority'] = priority
    return c


def strike(name, hit, wind=None, t_hit=0.06, settle=None, hold=0.14, follow=None, back=0.36, overshoot=0.1, start=None):
    """A held-pose clip (VFX.Pose): a quick counter-move, the snap into the
    pose ("Hit", past it), the settle, the "Hold" key (held as long as the
    move holds the pose), a follow-through and back to rest."""
    start = start if start is not None else REST
    wind = wind if wind is not None else blend(start, hit, -0.18)
    settle = settle if settle is not None else hit
    follow = follow if follow is not None else blend(settle, REST, 0.55)
    keys = [
        (0.0, wind, OUT),
        (t_hit, over(wind, hit, overshoot), OUT, 'Hit'),
        (t_hit + 0.07, settle, INOUT),
        (max(hold, t_hit + 0.09), settle, INOUT, 'Hold'),
        (max(hold, t_hit + 0.09) + 0.13, follow, INOUT),
        (max(hold, t_hit + 0.09) + back, REST, INOUT),
    ]
    return seq(name, keys)


def charge(name, pose, deep=None, t_in=0.1, hold=0.16, back=0.3):
    """A held build-up pose (a coil, a charge): into it, sinking deeper
    ("Hold"), and back out if nothing follows."""
    deep = deep if deep is not None else blend(REST, pose, 1.08)
    keys = [
        (0.0, blend(REST, pose, 0.25), OUT),
        (t_in, pose, OUT),
        (hold, deep, INOUT, 'Hold'),
        (hold + back * 0.5, blend(deep, REST, 0.6), INOUT),
        (hold + back, REST, INOUT),
    ]
    return seq(name, keys)


def beats(name, beats_list, end, rest_after=0.3, start=None):
    """A motion clip from beats: (time, pose, ease, keyname?) plus the
    return to rest at end + rest_after."""
    keys = [(0.0, start if start is not None else REST, OUT)]
    for b in beats_list:
        keys.append(b)
    keys.append((end + rest_after, REST, INOUT))
    return seq(name, keys)
