"""Creati's three weapons as the game builds them (the same part table and
the same CFrame maths as the server's YM.arm: at (x, grip + y, z), turned
x/y/z, a cylinder's length turned onto Z), written as frames for
sim/scene_render_z4.py: each weapon on its own, then in her hand at a
contact pose. python3 weapon_sheet.py frames.json"""
import json, math, sys
import numpy as np
import rig, weapons, weapons_geo as G

ALONG = rig.R3(rig.ry(90))  # CFrame.Angles(0, rad(90), 0)


def weapon_parts(name, arm=np.eye(4)):
    out = []
    for kind, size, pos, r, col, mat, tr in G.WEAPONS[name]:
        m = rig.T(pos[0], pos[1] + G.GRIP, pos[2])
        m[:3, :3] = G.rot(*r)
        if kind == 'cyl':
            m = m @ ALONG
            size = (size[2], size[0], size[1])
        w = arm @ m
        c = G.COLORS[col]
        out.append({
            'cf': [float(v) for v in w[:3, 3]] + [float(v) for v in w[:3, :3].reshape(-1)],
            'size': [float(v) for v in size], 'color': [c[0] / 255, c[1] / 255, c[2] / 255],
            'alpha': 1 - tr, 'shape': {'cyl': 'cyl', 'ball': 'ball', 'wedge': 'wedge'}.get(kind, 'box'),
            'neon': mat == 'Neon',
        })
    return out


BODY = {'Torso': (196, 32, 52), 'Head': (250, 222, 200), 'Right Arm': (250, 222, 200), 'Left Arm': (250, 222, 200),
        'Right Leg': (34, 32, 40), 'Left Leg': (34, 32, 40)}


def body_parts(world):
    out = []
    for part, col in BODY.items():
        w = world[part]
        s = rig.SIZES[part]
        out.append({'cf': [float(v) for v in w[:3, 3]] + [float(v) for v in w[:3, :3].reshape(-1)],
                    'size': [float(v) for v in s], 'color': [c / 255 for c in col], 'alpha': 1, 'shape': 'box'})
    # the gold belt and the ponytail, so she reads as her
    t = world['Torso']
    belt = t @ rig.T(0, -0.8, 0)
    out.append({'cf': [float(v) for v in belt[:3, 3]] + [float(v) for v in belt[:3, :3].reshape(-1)],
                'size': [2.08, 0.3, 1.08], 'color': [1, 0.77, 0.27], 'alpha': 1, 'shape': 'box'})
    h = world['Head'] @ rig.T(0, 0.35, 0.45)
    out.append({'cf': [float(v) for v in h[:3, 3]] + [float(v) for v in h[:3, :3].reshape(-1)],
                'size': [0.7, 0.7, 0.7], 'color': [0.09, 0.08, 0.1], 'alpha': 1, 'shape': 'ball'})
    return out


def pose_at(clip, t):
    baked = rig.bake(clip)
    return rig.sample(baked, t)


frames = []
# the weapons alone, laid out flat and angled to the camera
for name, eye, at in (('Sword', (5.2, 1.9, 0.4), (0, 0, -1.9)), ('Staff', (7.2, 2.4, 1.6), (0, 0, -1.1)),
                      ('Spear', (9.4, 3.0, 0.9), (0, 0, -2.6))):
    frames.append({'label': name.upper(), 'parts': weapon_parts(name, rig.T(0, -G.GRIP, 0)),
                   'meta': {'eye': list(eye), 'at': list(at), 'fov': 40}})
# in her hand: the guard, and each weapon's heaviest hit at contact
for clip_name, t, eye, at in (('SwordM1_4', None, (-7.5, 4.2, -7.0), (0, 2.4, -2.2)),
                              ('StaffM1_1', None, (-8.0, 4.4, -7.5), (0, 2.6, -1.5)),
                              ('PiercingThrust', None, (-9.0, 3.6, -3.0), (0, 2.4, -3.2))):
    clip = weapons.CLIPS[clip_name]
    hit = [k['t'] for k in clip['keys'] if k.get('name') == 'Hit'][0]
    x = pose_at(clip, hit + 0.02)
    world = rig.fk(x)
    parts = body_parts(world) + weapon_parts(clip['prop'], world['Right Arm'])
    # the street
    parts.append({'cf': [0, -0.1, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1], 'size': [40, 0.2, 40], 'color': [0.62, 0.62, 0.64], 'alpha': 1, 'shape': 'box'})
    frames.append({'label': clip_name + ' (contact)', 'parts': parts, 'meta': {'eye': list(eye), 'at': list(at), 'fov': 40}})
json.dump(frames, open(sys.argv[1], 'w'))
print(sys.argv[1], len(frames), 'frames')
