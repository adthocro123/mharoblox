"""Preview clips: a contact sheet of every key pose (3 views) and a video
(real time and slow motion) with a training dummy to hit.
Usage: python3 preview.py module clipname [clipname...] [--slow N] [--sheet-only]"""
import sys, importlib, math, os
import numpy as np
from PIL import Image, ImageDraw
import rig

OUT = os.environ.get('OUT', 'out')

DUMMY_COL = {p: (150, 150, 158) for p in rig.PALETTE}
DUMMY_COL['Head'] = (170, 170, 176)


def dummy_world(z=-4.6, up=0.0):
    # a dummy facing you, a step in front
    hrp = rig.T(0, 3 + up, z) @ rig.R3(rig.ry(180))
    return rig.fk({}, hrp)


def lunge_at(clip, t):
    """How far the M1 step has carried the body forward by time t."""
    l = clip.get('lunge')
    if not l:
        return 0.0
    start, speed, dur = l
    return max(0.0, min(t - start, dur)) * speed


def colours():
    c = dict(rig.PALETTE)
    c.update(rig.ACCENT)
    return c


def sheet(clip, path):
    baked = rig.bake(clip)
    frames = []
    for k in baked:
        hrp = rig.T(0, 3, -lunge_at(clip, k['t']))
        frames.append(([(rig.fk(k['x'], hrp), colours()), (dummy_world(), DUMMY_COL, 'dummy')], '%s  t=%.3f  %s' % (clip['name'], k['t'], k['name'] if k['name'] != 'Keyframe' else '')))
    imgs = rig.render_frames(frames, cell=(400, 330))
    cols = 1
    W, H = imgs[0].size
    sheet_img = Image.new('RGB', (W * cols, H * len(imgs)), (255, 255, 255))
    for i, im in enumerate(imgs):
        sheet_img.paste(im, ((i % cols) * W, (i // cols) * H))
    sheet_img.save(path)
    return path


def video(clip, path, fps=60, slow=1, tail=0.25, views=('behind', 'front', 'side')):
    baked = rig.bake(clip)
    length = baked[-1]['t'] + tail
    n = int(math.ceil(length * fps * slow))
    frames = []
    for i in range(n + 1):
        t = i / (fps * slow)
        hrp = rig.T(0, 3, -lunge_at(clip, t))
        frames.append(([(rig.fk(rig.sample(baked, t), hrp), colours()), (dummy_world(), DUMMY_COL, 'dummy')],
                       '%s   %.3fs%s' % (clip['name'], t, ('   (x%g slow)' % slow) if slow != 1 else '')))
    imgs = rig.render_frames(frames, views=views)
    rig.write_video(imgs, path, fps)
    return path


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    mod = importlib.import_module(args[0])
    names = args[1:] or list(mod.CLIPS)
    SLOW = 1
    for a in sys.argv:
        if a.startswith('--slow='):
            SLOW = float(a.split('=')[1])
    SHEET_ONLY = '--sheet-only' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        clip = mod.CLIPS[name]
        print(sheet(clip, os.path.join(OUT, name + '_keys.png')))
        if not SHEET_ONLY:
            print(video(clip, os.path.join(OUT, name + ('_slow%g' % SLOW if SLOW != 1 else '') + '.mp4'), slow=SLOW))
