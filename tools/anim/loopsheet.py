"""Loops at 8 phases each (a row per loop, one view)."""
import sys, importlib, os
from PIL import Image
import rig, preview
mod = importlib.import_module(sys.argv[1])
names = sys.argv[3:]
view = os.environ.get('VIEW', 'side')
cell = (220, 210)
rows = []
for n in names:
    c = mod.CLIPS[n]
    b = rig.bake(c)
    L = b[-1]['t']
    frames = []
    for i in range(8):
        t = L * i / 8
        frames.append(([(rig.fk(rig.sample(b, t)), preview.colours())], '%s %.2f' % (n.replace('Loco', ''), i / 8)))
    rows.append(rig.render_frames(frames, views=(view,), cell=cell))
img = Image.new('RGB', (cell[0] * 8, cell[1] * len(rows)), (255, 255, 255))
for r, row in enumerate(rows):
    for i, im in enumerate(row):
        img.paste(im, (i * cell[0], r * cell[1]))
img.save(sys.argv[2]); print(sys.argv[2], img.size)
