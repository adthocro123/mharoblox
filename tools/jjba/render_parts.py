# render_parts.py <frames.json> <out.png> [title]: each frame a panel; every
# part drawn as its box (a ball as a disc), flat-shaded, far to near, seen
# from in front (-Z) and a little to its right and above
import sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
frames = json.load(open(sys.argv[1]))
title = sys.argv[3] if len(sys.argv) > 3 else ''
W, H = 420, 560
def look_at(eye, target):
    f = target - eye; f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return eye, r, u, f
def cf_mat(c):
    p = np.array(c[0:3]); R = np.array(c[3:12]).reshape(3, 3)
    return p, R
light = np.array([0.4, 0.8, -0.5]); light /= np.linalg.norm(light)
panels = []
for fr in frames:
    img = Image.new('RGB', (W, H), (34, 36, 44))
    d = ImageDraw.Draw(img)
    pts = [np.array(p['cf'][0:3]) for p in fr['parts']]
    ctr = np.mean(pts, axis=0) if pts else np.zeros(3)
    eye = ctr + np.array([3.5, 1.5, -9.5])
    E, r, u, f = look_at(eye, ctr)
    foc = 560
    def proj(v):
        q = v - E
        z = q @ f
        return (W / 2 + foc * (q @ r) / z, H / 2 - foc * (q @ u) / z, z)
    polys = []
    for p in fr['parts']:
        pos, R = cf_mat(p['cf'])
        sx, sy, sz = [s / 2 for s in p['size']]
        col = np.array(p['color'])
        if p['shape'] == 'ball':
            x, y, z = proj(pos)
            rad = foc * min(sx, sy, sz) / z
            shade = 0.55 + 0.45 * max(0.0, float(light @ (-f)))
            polys.append((z, 'ball', (x, y, rad), tuple(int(255 * min(1, c * shade)) for c in col)))
            continue
        ax = [R[:, 0] * sx, R[:, 1] * sy, R[:, 2] * sz]
        for i in range(3):
            for sgn in (1, -1):
                n = R[:, i] * sgn
                if n @ (E - (pos + ax[i] * sgn)) <= 0:
                    continue
                j, k = [a for a in range(3) if a != i]
                c0 = pos + ax[i] * sgn
                quad = [c0 + ax[j] * a + ax[k] * b for a, b in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
                pq = [proj(v) for v in quad]
                zc = np.mean([q[2] for q in pq])
                shade = 0.45 + 0.55 * max(0.0, float(light @ n))
                polys.append((zc, 'poly', [(q[0], q[1]) for q in pq], tuple(int(255 * min(1, c * shade)) for c in col)))
    polys.sort(key=lambda t: -t[0])
    for z, kind, g, col in polys:
        if kind == 'ball':
            x, y, rad = g
            d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=col, outline=(20, 20, 24))
        else:
            d.polygon(g, fill=col, outline=(20, 20, 24))
    d.text((10, 10), fr['label'], fill=(235, 235, 240))
    panels.append(img)
out = Image.new('RGB', (W * len(panels), H + (28 if title else 0)), (20, 20, 26))
for i, im in enumerate(panels):
    out.paste(im, (i * W, 28 if title else 0))
if title:
    ImageDraw.Draw(out).text((10, 8), title, fill=(255, 255, 255))
out.save(sys.argv[2])
print('wrote', sys.argv[2], out.size)
