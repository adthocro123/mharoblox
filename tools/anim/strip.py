"""Filmstrip of a simulated chain: every Nth frame, one view, in a grid."""
import sys, importlib, os
from PIL import Image, ImageDraw
import rig, preview, chain
mod = importlib.import_module(sys.argv[1])
out = sys.argv[2]
plays = [(float(s.split('@')[1]), s.split('@')[0]) for s in sys.argv[3:]]
every = int(os.environ.get('EVERY', 2))
view = os.environ.get('VIEW', 'front')
t0 = float(os.environ.get('T0', 0)); t1 = float(os.environ.get('T1', 99))
cols = int(os.environ.get('COLS', 10))
cell = (int(os.environ.get('CW', 180)), int(os.environ.get('CH', 170)))
frames = [f for i, f in enumerate(chain.simulate(mod, plays)) if i % every == 0 and t0 <= f[0] <= t1]
rendered = [([(rig.fk(x, rig.T(0, 3, -z)), preview.colours()), (preview.dummy_world(-4.6 - z), preview.DUMMY_COL, 'dummy')], '%.3f' % t, -z) for t, x, z in frames]
imgs = rig.render_frames(rendered, views=(view,), cell=cell)
rows = (len(imgs) + cols - 1) // cols
sheet = Image.new('RGB', (cell[0] * cols, cell[1] * rows), (255, 255, 255))
for i, im in enumerate(imgs):
    sheet.paste(im, ((i % cols) * cell[0], (i // cols) * cell[1]))
sheet.save(out)
print(out, sheet.size, len(imgs))
