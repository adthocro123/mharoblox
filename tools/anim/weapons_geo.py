"""Creati's weapons, part by part - one definition for both the game (the
server builds them from the Lua this writes) and the previews.

Every part sits in the right arm's own space at the fist (y = GRIP below the
arm's centre); a weapon's length runs along the arm's -Z (across the fist,
at right angles to the arm). A part: (kind, (sx, sy, sz), (x, y, z),
(rx, ry, rz) degrees, colour, material, transparency). Cylinders' size is
(diameter, diameter, length); they're turned onto Z in the game."""
import math
import numpy as np

GRIP = -0.85  # the fist: 0.15 up from the bottom of a 2-stud R6 arm

COLORS = {
    'STEEL': (214, 220, 230), 'STEEL_DARK': (120, 128, 144), 'EDGE': (246, 250, 255),
    'GOLD': (255, 196, 70), 'GOLD_DARK': (196, 134, 40), 'RED': (196, 32, 52),
    'LACQUER': (70, 20, 30), 'WRAP': (30, 28, 34), 'GEM': (255, 70, 110), 'TASSEL': (220, 40, 60),
}


def ring(z, d=0.34, l=0.08, c='GOLD'):
    return ('cyl', (d, d, l), (0, 0, z), (0, 0, 0), c, 'Metal', 0)


SWORD = [
    # the grip: a red wrap with gold ribs, a pommel with a gem
    ('cyl', (0.22, 0.22, 0.9), (0, 0, 0.12), (0, 0, 0), 'RED', 'Fabric', 0),
    ring(-0.22, 0.26, 0.06), ring(0.12, 0.26, 0.06), ring(0.46, 0.26, 0.06),
    ('ball', (0.36, 0.36, 0.36), (0, 0, 0.66), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('ball', (0.16, 0.16, 0.16), (0, 0, 0.84), (0, 0, 0), 'GEM', 'Glass', 0),
    # the crossguard: a gold bar, a block in the middle, balled ends
    ('block', (1.4, 0.14, 0.2), (0, 0, -0.42), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('block', (0.36, 0.26, 0.32), (0, 0, -0.42), (0, 0, 0), 'GOLD_DARK', 'Metal', 0),
    ('ball', (0.22, 0.22, 0.22), (0.72, 0, -0.42), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('ball', (0.22, 0.22, 0.22), (-0.72, 0, -0.42), (0, 0, 0), 'GOLD', 'Metal', 0),
    # the blade: flat steel with a darker fuller down its middle, bright edges,
    # and a real point (two wedges)
    ('block', (0.09, 0.36, 3.3), (0, 0, -2.2), (0, 0, 0), 'STEEL', 'Metal', 0),
    ('block', (0.11, 0.09, 2.6), (0, 0, -1.95), (0, 0, 0), 'STEEL_DARK', 'Metal', 0),
    ('block', (0.1, 0.035, 3.3), (0, 0.17, -2.2), (0, 0, 0), 'EDGE', 'Neon', 0.35),
    ('block', (0.1, 0.035, 3.3), (0, -0.17, -2.2), (0, 0, 0), 'EDGE', 'Neon', 0.35),
    ('wedge', (0.09, 0.18, 0.7), (0, 0.09, -4.2), (0, 0, 0), 'STEEL', 'Metal', 0),
    ('wedge', (0.09, 0.18, 0.7), (0, -0.09, -4.2), (0, 0, 180), 'STEEL', 'Metal', 0),
]

STAFF = [
    # a lacquered bo: dark red-black, gold-capped, gold rings, two grip wraps
    ('cyl', (0.3, 0.3, 6.6), (0, 0, -1.1), (0, 0, 0), 'LACQUER', 'Wood', 0),
    ('cyl', (0.36, 0.36, 0.46), (0, 0, 1.97), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('cyl', (0.36, 0.36, 0.46), (0, 0, -4.17), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('ball', (0.34, 0.34, 0.34), (0, 0, 2.22), (0, 0, 0), 'GOLD_DARK', 'Metal', 0),
    ('ball', (0.34, 0.34, 0.34), (0, 0, -4.42), (0, 0, 0), 'GOLD_DARK', 'Metal', 0),
    ring(1.62), ring(-3.82), ring(-1.1, 0.34, 0.12),
    ('cyl', (0.34, 0.34, 0.7), (0, 0, 0.0), (0, 0, 0), 'RED', 'Fabric', 0),
    ('cyl', (0.34, 0.34, 0.7), (0, 0, -2.2), (0, 0, 0), 'RED', 'Fabric', 0),
]

SPEAR = [
    # the haft: lacquered, a black grip wrap, gold rings, a capped butt
    ('cyl', (0.24, 0.24, 6.9), (0, 0, -1.55), (0, 0, 0), 'LACQUER', 'Wood', 0),
    ('cyl', (0.28, 0.28, 1.1), (0, 0, 0.05), (0, 0, 0), 'WRAP', 'Fabric', 0),
    ring(0.7, 0.3), ring(-0.6, 0.3), ring(-3.6, 0.3),
    ('cyl', (0.3, 0.3, 0.36), (0, 0, 1.95), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('ball', (0.3, 0.3, 0.3), (0, 0, 2.15), (0, 0, 0), 'GOLD_DARK', 'Metal', 0),
    # the socket, a red tassel hanging off it
    ('cyl', (0.34, 0.34, 0.5), (0, 0, -5.05), (0, 0, 0), 'GOLD', 'Metal', 0),
    ('cyl', (0.26, 0.26, 0.24), (0, 0, -5.4), (0, 0, 0), 'GOLD_DARK', 'Metal', 0),
    ('block', (0.07, 0.07, 1.0), (0.1, 0.12, -4.45), (-18, 8, 0), 'TASSEL', 'Fabric', 0),
    ('block', (0.07, 0.07, 1.0), (-0.1, 0.12, -4.45), (-18, -8, 0), 'TASSEL', 'Fabric', 0),
    ('block', (0.07, 0.07, 1.1), (0, 0.18, -4.4), (-24, 0, 0), 'TASSEL', 'Fabric', 0),
    ('block', (0.07, 0.07, 0.9), (0.06, -0.06, -4.5), (-12, 14, 0), 'TASSEL', 'Fabric', 0),
    # the head: a leaf blade - flaring out of the socket, a ridge up its
    # middle, a long point
    ('block', (0.08, 0.46, 0.9), (0, 0, -6.05), (0, 0, 0), 'STEEL', 'Metal', 0),
    ('wedge', (0.08, 0.23, 0.45), (0, 0.115, -5.38), (0, 180, 0), 'STEEL', 'Metal', 0),
    ('wedge', (0.08, 0.23, 0.45), (0, -0.115, -5.38), (0, 180, 180), 'STEEL', 'Metal', 0),
    ('wedge', (0.08, 0.23, 0.9), (0, 0.115, -6.95), (0, 0, 0), 'STEEL', 'Metal', 0),
    ('wedge', (0.08, 0.23, 0.9), (0, -0.115, -6.95), (0, 0, 180), 'STEEL', 'Metal', 0),
    ('block', (0.12, 0.06, 2.1), (0, 0, -6.2), (0, 0, 0), 'STEEL_DARK', 'Metal', 0),
    ('block', (0.09, 0.03, 0.9), (0, 0.22, -6.05), (0, 0, 0), 'EDGE', 'Neon', 0.35),
    ('block', (0.09, 0.03, 0.9), (0, -0.22, -6.05), (0, 0, 0), 'EDGE', 'Neon', 0.35),
]

WEAPONS = {'Sword': SWORD, 'Staff': STAFF, 'Spear': SPEAR}


def rot(rx, ry, rz):
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    X = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Y = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Z = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return X @ Y @ Z  # CFrame.Angles order


def boxes(name):
    """Preview boxes in the arm's space: [(4x4, size, colour)]."""
    out = []
    for kind, size, pos, r, col, mat, tr in WEAPONS[name]:
        m = np.eye(4)
        m[:3, :3] = rot(*r)
        m[:3, 3] = (pos[0], pos[1] + GRIP, pos[2])
        c = COLORS[col]
        if tr:
            c = tuple(int(v * (1 - tr) + 255 * tr) for v in c)
        out.append((m, size, c))
    return out


def lua():
    """The Lua table the server builds them from."""
    lines = ['{']
    for name in ('Staff', 'Sword', 'Spear'):
        lines.append('\t%s = {' % name)
        for kind, size, pos, r, col, mat, tr in WEAPONS[name]:
            f = lambda v: ('%g' % round(v, 4))
            lines.append('\t\t{ "%s", %s, %s, %s, "%s", "%s", %s },' % (
                kind, ', '.join(f(v) for v in size), ', '.join(f(v) for v in pos), ', '.join(f(v) for v in r), col, mat, f(tr)))
        lines.append('\t},')
    lines.append('}')
    return '\n'.join(lines)


if __name__ == '__main__':
    print(lua())
