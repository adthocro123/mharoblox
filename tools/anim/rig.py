"""R6 animation toolkit: rig math, Roblox-accurate KeyframeSequence sampling,
forward kinematics, a small box renderer and video output.

Space conventions (Roblox): +X right, +Y up, -Z forward (the HumanoidRootPart
looks down -Z). A Pose.CFrame is the Motor6D.Transform of the joint that
drives that part:  Part1 = Part0 * C0 * Transform * C1:Inverse().
"""
import math, json, os, subprocess
import numpy as np
from PIL import Image, ImageDraw

# ---------------------------------------------------------------- CFrames (4x4)

def T(x=0.0, y=0.0, z=0.0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def R3(m3):
    m = np.eye(4)
    m[:3, :3] = m3
    return m


def rx(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22):
    m = np.eye(4)
    m[:3, :3] = [[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]]
    m[:3, 3] = (x, y, z)
    return m


def inv(m):
    r = m[:3, :3].T
    out = np.eye(4)
    out[:3, :3] = r
    out[:3, 3] = -r @ m[:3, 3]
    return out


def quat(m3):
    t = np.trace(m3)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        return np.array([0.25 * s, (m3[2, 1] - m3[1, 2]) / s, (m3[0, 2] - m3[2, 0]) / s, (m3[1, 0] - m3[0, 1]) / s])
    i = int(np.argmax([m3[0, 0], m3[1, 1], m3[2, 2]]))
    if i == 0:
        s = math.sqrt(1.0 + m3[0, 0] - m3[1, 1] - m3[2, 2]) * 2
        return np.array([(m3[2, 1] - m3[1, 2]) / s, 0.25 * s, (m3[0, 1] + m3[1, 0]) / s, (m3[0, 2] + m3[2, 0]) / s])
    if i == 1:
        s = math.sqrt(1.0 + m3[1, 1] - m3[0, 0] - m3[2, 2]) * 2
        return np.array([(m3[0, 2] - m3[2, 0]) / s, (m3[0, 1] + m3[1, 0]) / s, 0.25 * s, (m3[1, 2] + m3[2, 1]) / s])
    s = math.sqrt(1.0 + m3[2, 2] - m3[0, 0] - m3[1, 1]) * 2
    return np.array([(m3[1, 0] - m3[0, 1]) / s, (m3[0, 2] + m3[2, 0]) / s, (m3[1, 2] + m3[2, 1]) / s, 0.25 * s])


def qmat(q):
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def lerp_cf(a, b, t):
    """CFrame:Lerp - position linear, rotation slerp."""
    qa, qb = quat(a[:3, :3]), quat(b[:3, :3])
    d = float(np.dot(qa, qb))
    if d < 0:
        qb, d = -qb, -d
    if d > 0.9995:
        q = qa + (qb - qa) * t
    else:
        th = math.acos(min(d, 1.0))
        q = (math.sin((1 - t) * th) * qa + math.sin(t * th) * qb) / math.sin(th)
    m = np.eye(4)
    m[:3, :3] = qmat(q)
    m[:3, 3] = a[:3, 3] + (b[:3, 3] - a[:3, 3]) * t
    return m


def comps(m):
    """CFrame components x,y,z,R00..R22 (Roblox order)."""
    r = m[:3, :3]
    return [float(v) for v in (m[0, 3], m[1, 3], m[2, 3], r[0, 0], r[0, 1], r[0, 2], r[1, 0], r[1, 1], r[1, 2], r[2, 0], r[2, 1], r[2, 2])]


def from_comps(c):
    return cf(*c)

# ---------------------------------------------------------------- the R6 rig

SIZES = {
    'HumanoidRootPart': (2, 2, 1), 'Torso': (2, 2, 1), 'Head': (2, 1, 1),
    'Right Arm': (1, 2, 1), 'Left Arm': (1, 2, 1), 'Right Leg': (1, 2, 1), 'Left Leg': (1, 2, 1),
}
# part -> (parent part, motor name, C0, C1): Roblox's stock R6 joints
JOINTS = {
    'Torso': ('HumanoidRootPart', 'RootJoint', cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    'Head': ('Torso', 'Neck', cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    'Right Arm': ('Torso', 'Right Shoulder', cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    'Left Arm': ('Torso', 'Left Shoulder', cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
    'Right Leg': ('Torso', 'Right Hip', cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    'Left Leg': ('Torso', 'Left Hip', cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
}
ORDER = ['Torso', 'Head', 'Right Arm', 'Left Arm', 'Right Leg', 'Left Leg']
GRID_FAR = 8.0  # (how far back the street's grid is drawn)
GROUND = -3.0  # the street, in HumanoidRootPart space (feet touch it at rest)


def fk(transforms, hrp=None):
    """World CFrames of every part from joint transforms {part: 4x4}."""
    hrp = T(0, 3, 0) if hrp is None else hrp
    world = {'HumanoidRootPart': hrp}
    for part in ORDER:
        parent, _, c0, c1 = JOINTS[part]
        x = transforms.get(part, np.eye(4))
        world[part] = world[parent] @ c0 @ x @ inv(c1)
    return world

# ---------------------------------------------------------------- posing
# A key pose is written the way an animator thinks about it:
#   body = dict(y=, fwd=, side=, lean=, twist=, tilt=)
#       y: studs up/down of the pelvis (negative = sink), fwd/side: shift
#       lean: degrees forward (+) / back, pivoting at the pelvis
#       twist: degrees the chest turns LEFT (+) = right shoulder forward
#       tilt: degrees the chest leans to its RIGHT side (+)
#   head = (pitch, yaw, roll) on top of the chest; None = keeps the eyes on
#       the target (undoes most of the chest's turn and lean)
#   ra / la = (raise, across, out, spin): raise forward from hanging
#       (90 = level, 180 = straight up, negative = behind), swing across the
#       chest (+ = toward the middle), lift out to the side, spin on its axis
#   rl / ll = a planted foot: dict(f=, s=) the foot's spot on the street
#       (studs forward of / out to the side of the hip), or a free leg: a
#       tuple like the arms, relative to the street (not the chest)


def chest_rot(body):
    # turn about the spine, then lean forward about the hips' side axis, then
    # tip sideways; lean forward = the chest's top toward -Z
    # (round 66) roll: degrees the body spins about its own spine (+ = to its
    # left), after the rest - a twist in the air, whatever way it's lying
    return ry(body.get('twist', 0)) @ rx(-body.get('lean', 0)) @ rz(-body.get('tilt', 0)) @ ry(body.get('roll', 0))


def limb_rot(p, side):
    raise_, across, out, spin = (list(p) + [0, 0, 0, 0])[:4]
    return ry(across * side) @ rz(out * side) @ rx(raise_) @ ry(spin * side)


def arm_rot(spec, side, rc):
    """An arm: a tuple (raise, across, out, spin), or a dict r/a/o plus
    blade=(x, y, z) - the direction (street space) the held weapon should
    point; the arm spins on its own axis to point it as near as it can (a
    weapon sits across the fist, at right angles to the arm)."""
    if not isinstance(spec, dict):
        return limb_rot(spec, side)
    base = limb_rot((spec.get('r', 0), spec.get('a', 0), spec.get('o', 0), spec.get('spin', 0)), side)
    blade = spec.get('blade')
    if blade is None and spec.get('bladeC') is None:
        return base
    # (bladeC: the direction in the chest's own space - it turns with her)
    b = np.array(spec['bladeC'], float) if spec.get('bladeC') is not None else rc.T @ np.array(blade, float)
    b = b / np.linalg.norm(b)
    if spec.get('fit', True):
        base = limb_rot(fit_arm(spec, side, b), side)
    axis = base @ np.array([0, -1.0, 0])
    bp = b - axis * float(np.dot(b, axis))
    if np.linalg.norm(bp) < 1e-6:
        return base
    b0 = base @ np.array([0, 0, -1.0])
    ang = math.atan2(float(np.dot(np.cross(b0, bp), axis)), float(np.dot(b0, bp)))
    return base @ ry(-math.degrees(ang))


def _axes(r, a, o, side):
    """The arm's axis (shoulder to fist) in chest space, for arrays of r/a/o."""
    r, a, o = (np.radians(v) for v in (r, a, o * side))
    a = a * side
    y, z = -np.cos(r), -np.sin(r)
    x, y = -np.sin(o) * y, np.cos(o) * y
    return np.stack([np.cos(a) * x + np.sin(a) * z, y, -np.sin(a) * x + np.cos(a) * z], -1)


_FIT = {}


def fit_arm(spec, side, b, tol=8.0):
    """A weapon sits across the fist, so the arm must stand near square to
    where it should point: the least change of raise/across/out that puts
    the arm within `tol` degrees of square to `b` (chest space)."""
    r0, a0, o0 = (float(spec.get(k, 0)) for k in ('r', 'a', 'o'))
    spin = spec.get('spin', 0)
    key = (r0, a0, o0, side, tuple(np.round(b, 4)))
    if key in _FIT:
        return _FIT[key]
    err0 = math.degrees(math.asin(min(1.0, abs(float(_axes(r0, a0, o0, side) @ b)))))
    best = (r0, a0, o0, spin)
    if err0 > tol:
        d = np.arange(-96, 97, 4.0)
        R, A, O = np.meshgrid(d, d, np.arange(-40, 41, 10.0), indexing='ij')
        ax = _axes(r0 + R, a0 + A, o0 + O, side)
        err = np.degrees(np.arcsin(np.clip(np.abs(ax @ b), 0, 1)))
        dev = np.sqrt(R ** 2 + A ** 2 + (1.5 * O) ** 2)
        cost = np.maximum(err - tol * 0.5, 0) + 0.12 * dev
        i = np.unravel_index(int(np.argmin(cost)), cost.shape)
        best = (r0 + R[i], a0 + A[i], o0 + O[i], spin)
    _FIT[key] = best
    return best


def mirror(pose):
    """The same pose, left for right."""
    out = {}
    body = dict(pose.get('body', {}))
    for k in ('twist', 'tilt', 'side', 'roll'):
        if k in body:
            body[k] = -body[k]
    out['body'] = body
    if pose.get('head') is not None:
        h = (list(pose['head']) + [0, 0, 0])[:3]
        out['head'] = (h[0], -h[1], -h[2])
    for a, b in (('ra', 'la'), ('rl', 'll')):
        for src, dst in ((a, b), (b, a)):
            v = pose.get(src)
            if v is None:
                continue
            if isinstance(v, dict):
                v = dict(v)
                for bk in ('blade', 'bladeC'):
                    if bk in v:
                        x, y, z = v[bk]
                        v[bk] = (-x, y, z)
            out[dst] = v
    return out


def rotation_between(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    v = np.cross(a, b); c = float(np.dot(a, b))
    if c < -0.9999:
        return rx(180)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


def to_transforms(pose):
    body = pose.get('body', {})
    rc = chest_rot(body)
    pelvis = np.array([body.get('side', 0), -1 + body.get('y', 0), -body.get('fwd', 0)])
    if body.get('pivot') == 'center':
        # (a flip: the body turns about its middle, y/fwd/side move that)
        pelvis = np.array([body.get('side', 0), body.get('y', 0), -body.get('fwd', 0)]) - rc @ np.array([0, 1, 0])
    # torso centre = pelvis + chest rotation of (0, 1, 0)
    center = pelvis + rc @ np.array([0, 1, 0])
    torso_hrp = T(*center) @ R3(rc)  # the torso in HumanoidRootPart space
    out = {}
    c0, c1 = JOINTS['Torso'][2], JOINTS['Torso'][3]
    out['Torso'] = inv(c0) @ torso_hrp @ c1

    def joint_x(part, q_chest):
        r0 = JOINTS[part][2][:3, :3]
        return R3(r0.T @ q_chest @ r0)

    # head: keeps the eyes on the target unless told otherwise
    head = pose.get('head')
    if head is None:
        # undo most of the chest's turn / lean / tip (in chest space)
        world = ry(-body.get('twist', 0) * 0.15) @ rx(body.get('lean', 0) * 0.3)
        q = rc.T @ world
    else:
        hp, hy, hr = (list(head) + [0, 0, 0])[:3]
        q = ry(hy) @ rx(-hp) @ rz(-hr)
    out['Head'] = joint_x('Head', q)
    for part, key, side in (('Right Arm', 'ra', 1), ('Left Arm', 'la', -1)):
        spec = pose.get(key, (0,))
        if isinstance(spec, dict) and 'grab' in spec:
            continue  # (after the right arm: it reaches for the weapon)
        out[part] = joint_x(part, arm_rot(spec, side, rc))
    la = pose.get('la')
    if isinstance(la, dict) and 'grab' in la:
        # both hands on it: the left fist reaches for a point `grab` studs up
        # the held weapon from the right fist
        world = fk(out, T(0, 0, 0))
        arm = world['Right Arm']
        grip_y = la.get('grip_y', -0.85)
        c0 = JOINTS['Left Arm'][2]
        pivot = (torso_hrp @ np.array([c0[0, 3], c0[1, 3], c0[2, 3], 1]))[:3]
        # (slide along the shaft to where the left hand can actually reach it,
        # staying near the asked-for spot)
        k0 = la['grab']
        best = None
        for k in np.arange(k0 - 1.6, k0 + 1.61, 0.05):
            p = (arm @ np.array([0, grip_y, -k, 1]))[:3]
            score = abs(float(np.linalg.norm(p - pivot)) - 1.58) + 0.12 * abs(k - k0)
            if best is None or score < best[0]:
                best = (score, p)
        target = best[1]
        want = rc.T @ (target - pivot)
        rest = np.array([-0.5, -1.5, 0.0])  # left shoulder pivot -> its fist
        out['Left Arm'] = joint_x('Left Arm', rotation_between(rest, want))
    for part, key, side in (('Right Leg', 'rl', 1), ('Left Leg', 'll', -1)):
        spec = pose.get(key, {'f': 0, 's': 0})
        if isinstance(spec, dict):
            q_world = plant(torso_hrp, part, side, spec)
        elif body.get('legs') == 'chest':
            q_world = rc @ limb_rot(spec, side)  # (tucked with the body: a flip)
        else:
            q_world = limb_rot(spec, side)
        out[part] = joint_x(part, rc.T @ q_world)
    return out


def plant(torso_hrp, part, side, spec):
    """Rotation (street space) that puts this leg's foot on the street at
    spec f (forward) / s (out) from under its hip, as near as it can reach."""
    c0 = JOINTS[part][2]
    pivot = (torso_hrp @ np.array([c0[0, 3], c0[1, 3], c0[2, 3], 1]))[:3]
    rest = np.array([-0.5 * side, -2.0, 0.0])  # hip pivot -> foot sole centre
    reach = np.linalg.norm(rest)
    h = pivot[1] - GROUND
    want_h = np.array([spec.get('s', 0) * side, 0, -spec.get('f', 0)])
    # the sole's centre sits 0.5 in from the pivot at rest: aim from the leg's
    # own line under the hip
    base = np.array([pivot[0] - 0.5 * side, 0, pivot[2]])
    horiz = base + want_h - np.array([pivot[0], 0, pivot[2]])
    if h >= reach:
        target = np.array([horiz[0], -h, horiz[2]])  # can't reach: hangs
    else:
        flat = math.sqrt(max(reach * reach - h * h, 0))
        n = np.linalg.norm(horiz)
        d = horiz / n * flat if n > 1e-6 else np.array([0, 0, 0.0])
        if n < 1e-6 and flat > 1e-3:
            d = np.array([rest[0], 0, 0]) / abs(rest[0]) * flat
        target = np.array([d[0], -h, d[2]])
    q = rotation_between(rest, target)
    # keep the kneecap (the leg's front) facing where the foot points
    yaw = spec.get('turn', 0)
    if yaw:
        axis = target / np.linalg.norm(target)
        k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
        a = math.radians(yaw * side)
        q = (np.eye(3) + math.sin(a) * k + (1 - math.cos(a)) * k @ k) @ q
    return q

# ---------------------------------------------------------------- clips
# A clip: {'name', 'keys': [{'t', 'pose', 'ease': (style, dir), 'name'?}]}
# easing on a key = how it travels to the NEXT key (Roblox's rule)

STYLES = {'Linear': 0, 'Constant': 1, 'Elastic': 2, 'Cubic': 3, 'Bounce': 4, 'CubicV2': 5}
DIRS = {'In': 0, 'Out': 1, 'InOut': 2}


def ease(a, style, direction):
    if style == 'Constant':
        return 0.0 if a < 1 else 1.0
    if style == 'Linear':
        return a
    if style in ('CubicV2', 'Cubic'):
        if style == 'Cubic':  # Roblox's legacy Cubic has In / Out swapped
            direction = {'In': 'Out', 'Out': 'In'}.get(direction, direction)
        if direction == 'In':
            return a ** 3
        if direction == 'Out':
            return 1 - (1 - a) ** 3
        return 4 * a ** 3 if a < 0.5 else 1 - (-2 * a + 2) ** 3 / 2
    raise ValueError(style)


def bake(clip):
    """Each key's joint transforms (what the KeyframeSequence stores)."""
    out = []
    for k in clip['keys']:
        out.append({'t': k['t'], 'x': to_transforms(k['pose']), 'ease': k.get('ease', ('CubicV2', 'InOut')), 'name': k.get('name', 'Keyframe')})
    return out


def sample(baked, t):
    if t <= baked[0]['t']:
        return baked[0]['x']
    if t >= baked[-1]['t']:
        return baked[-1]['x']
    for a, b in zip(baked, baked[1:]):
        if a['t'] <= t < b['t']:
            u = (t - a['t']) / (b['t'] - a['t'])
            e = ease(u, *a['ease'])
            return {p: lerp_cf(a['x'][p], b['x'][p], e) for p in ORDER}
    return baked[-1]['x']


def to_json(clip):
    baked = bake(clip)
    return {
        'name': clip['name'], 'loop': clip.get('loop', False), 'priority': clip.get('priority', 'Action'),
        'keys': [{
            't': k['t'], 'name': k['name'], 'style': k['ease'][0], 'dir': k['ease'][1],
            'poses': {p: comps(k['x'][p]) for p in ORDER},
        } for k in baked],
    }

# ---------------------------------------------------------------- rendering

PALETTE = {
    'Head': (245, 205, 160), 'Torso': (58, 92, 170),
    'Right Arm': (245, 205, 160), 'Left Arm': (245, 205, 160),
    'Right Leg': (40, 44, 58), 'Left Leg': (40, 44, 58),
}
ACCENT = {'Right Arm': (226, 84, 70), 'Right Leg': (226, 84, 70)}


def box_faces(m, size):
    s = np.array(size) / 2
    r = m[:3, :3]; c = m[:3, 3]
    res = []
    for axis in range(3):
        for sign in (-1, 1):
            others = [i for i in range(3) if i != axis]
            quad = []
            for a, b in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
                k = np.zeros(3); k[axis] = sign; k[others[0]] = a; k[others[1]] = b
                quad.append(c + r @ (s * k))
            res.append((quad, r[:, axis] * sign))
    return res


class Camera:
    def __init__(self, eye, at, w, h, fov=38):
        self.eye = np.array(eye, float); at = np.array(at, float)
        f = at - self.eye; self.f = f / np.linalg.norm(f)
        r = np.cross(self.f, [0, 1, 0]); self.r = r / np.linalg.norm(r)
        self.u = np.cross(self.r, self.f)
        self.w, self.h = w, h
        self.k = (h / 2) / math.tan(math.radians(fov) / 2)

    def proj(self, p):
        d = p - self.eye
        z = float(np.dot(d, self.f))
        return (self.w / 2 + np.dot(d, self.r) / z * self.k, self.h / 2 - np.dot(d, self.u) / z * self.k), z


LIGHT = np.array([0.35, 0.85, 0.4]) / np.linalg.norm([0.35, 0.85, 0.4])


def draw_scene(img, cam, bodies, extra=None, ss=2):
    """bodies: list of (world dict, tint alpha, colours override)"""
    d = ImageDraw.Draw(img)
    # the street grid
    for gx in range(-8, 9, 2):
        a, _ = cam.proj(np.array([gx, 0, -14.0])); b, _ = cam.proj(np.array([gx, 0, GRID_FAR]))
        d.line([a, b], fill=(206, 208, 214), width=ss)
    for gz in range(-14, int(GRID_FAR) + 1, 2):
        a, _ = cam.proj(np.array([-8, 0, gz])); b, _ = cam.proj(np.array([8, 0, gz]))
        d.line([a, b], fill=(206, 208, 214), width=ss)
    polys = []
    for world, colours in bodies:
        for m, size, col in world.get('__boxes__', ()):
            for quad, n in box_faces(m, size):
                if np.dot(n, cam.f) > 0:
                    continue
                pts, zs = zip(*(cam.proj(p) for p in quad))
                if min(zs) <= 0.1:
                    continue
                shade = 0.62 + 0.38 * max(0.0, float(np.dot(n, LIGHT)))
                polys.append((float(np.mean(zs)), pts, tuple(int(min(255, c * shade)) for c in col)))
        for part, m in world.items():
            if part in ('HumanoidRootPart', '__boxes__'):
                continue
            base = np.array(colours.get(part, PALETTE[part]), float)
            for quad, n in box_faces(m, SIZES[part]):
                if np.dot(n, cam.f) > 0:
                    continue
                pts, zs = zip(*(cam.proj(p) for p in quad))
                if min(zs) <= 0.1:
                    continue
                shade = 0.62 + 0.38 * max(0.0, float(np.dot(n, LIGHT)))
                polys.append((float(np.mean(zs)), pts, tuple(int(min(255, c * shade)) for c in base)))
    for _, pts, col in sorted(polys, key=lambda p: -p[0]):
        d.polygon(pts, fill=col, outline=(24, 24, 30), width=ss)
    if extra:
        extra(d, cam)


VIEWS = {
    'behind': ((5.4, 6.0, 10.2), (0, 2.8, -1.6)),    # over your own shoulder (the player's camera)
    'front': ((-8.6, 4.3, -9.4), (0, 2.7, -0.6)),    # what the other player sees (the dummy's left)
    'side': ((12.0, 3.4, -2.2), (0, 2.7, -2.2)),     # profile
}
HIDE_DUMMY = {'front'}  # it would stand in the way


def render_frames(frames, path_png=None, views=('behind', 'front', 'side'), cell=(480, 360), ss=2, label=None):
    """frames: list of (bodies, caption). Returns list of PIL images (one per frame)."""
    out = []
    w, h = cell
    for fr in frames:
        bodies, caption = fr[0], fr[1]
        follow = (np.array([0, 0, fr[2]]) if np.isscalar(fr[2]) else np.array(fr[2], float)) if len(fr) > 2 else np.zeros(3)  # the camera keeps up with him
        img = Image.new('RGB', (w * len(views) * ss, h * ss), (244, 245, 248))
        for i, v in enumerate(views):
            eye, at = VIEWS[v] if isinstance(v, str) else v
            eye, at = np.array(eye, float) + follow, np.array(at, float) + follow
            sub = Image.new('RGB', (w * ss, h * ss), (244, 245, 248))
            shown = [b for b in bodies if not (v in HIDE_DUMMY and len(b) > 2 and b[2] == 'dummy')]
            draw_scene(sub, Camera(eye, at, w * ss, h * ss), [(b[0], b[1]) for b in shown], ss=ss)
            img.paste(sub, (i * w * ss, 0))
        img = img.resize((w * len(views), h), Image.LANCZOS)
        if caption:
            ImageDraw.Draw(img).text((8, 6), caption, fill=(20, 20, 30))
        out.append(img)
    return out


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def write_video(images, path, fps=60):
    tmp = path + '_frames'
    os.makedirs(tmp, exist_ok=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    for i, im in enumerate(images):
        im.save(os.path.join(tmp, '%05d.png' % i))
    if path.endswith('.gif'):
        subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', os.path.join(tmp, '%05d.png'),
                        '-vf', 'split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer', path], check=True)
    else:
        subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', os.path.join(tmp, '%05d.png'),
                        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-movflags', '+faststart', path], check=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)


def with_prop(world, boxes, part='Right Arm'):
    """Add a held prop's boxes ([(arm-local CFrame, size, colour)]) to a posed body."""
    arm = world[part]
    world = dict(world)
    world['__boxes__'] = [(arm @ m, size, col) for m, size, col in boxes]
    return world
