"""All clips' key poses in one sheet: a row per clip, a cell per key (front + side)."""
import sys, importlib, os
from PIL import Image, ImageDraw
import rig, preview
mod = importlib.import_module(sys.argv[1])
names = sys.argv[3:] or mod.ORDER
views = os.environ.get('VIEWS', 'front,side').split(',')
cell = (230, 200)
rows = []
for name in names:
    clip = mod.CLIPS[name]
    baked = rig.bake(clip)
    frames = []
    for k in baked:
        hrp = rig.T(0, 3, -preview.lunge_at(clip, k['t']))
        w = rig.fk(k['x'], hrp)
        if clip.get('prop'):
            import weapons_geo
            w = rig.with_prop(w, weapons_geo.boxes(clip['prop']))
        frames.append(([(w, preview.colours()), (preview.dummy_world(), preview.DUMMY_COL, 'dummy')],
                       '%s %.3f%s' % (name.replace('M1', ''), k['t'], ' HIT' if k['name'] == 'Hit' else '')))
    rows.append(rig.render_frames(frames, views=views, cell=cell))
W = cell[0] * len(views)
ncol = max(len(r) for r in rows)
img = Image.new('RGB', (W * ncol, cell[1] * len(rows)), (255, 255, 255))
d = ImageDraw.Draw(img)
for i, r in enumerate(rows):
    for j, im in enumerate(r):
        img.paste(im, (j * W, i * cell[1]))
        d.rectangle([j * W, i * cell[1], (j + 1) * W - 1, (i + 1) * cell[1] - 1], outline=(180, 180, 190))
img.save(sys.argv[2])
print(sys.argv[2], img.size)
