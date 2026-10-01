"""Simulate the game playing clips back to back (each new clip fades in from
wherever the body is over FADE seconds; after the last one the body eases
back to rest over RECOVER seconds with Sine Out) and render it."""
import sys, importlib, math, os
import numpy as np
import rig, preview

FADE = 0.05
RECOVER = 0.3


def ease_out_quad(a):
    return 1 - (1 - a) * (1 - a)


def sine_out(a):
    return math.sin(a * math.pi / 2)


def simulate(mod, plays, fps=60, tail=0.5):
    """plays: [(t_start, clipname)]. Returns [(t, transforms, hrp_z)]."""
    baked = {n: rig.bake(mod.CLIPS[n]) for _, n in plays}
    end = plays[-1][0] + baked[plays[-1][1]][-1]['t'] + RECOVER + tail
    rest = {p: np.eye(4) for p in rig.ORDER}
    out = []
    current = rest
    active = None  # (t0, name, from)
    idx = 0
    z = 0.0
    last_t = 0.0
    n = int(end * fps)
    release = None
    for i in range(n + 1):
        t = i / fps
        while idx < len(plays) and plays[idx][0] <= t + 1e-9:
            active = (plays[idx][0], plays[idx][1], current)
            idx += 1
            release = None
        if active:
            t0, name, frm = active
            b = baked[name]
            local = t - t0
            if local <= b[-1]['t']:
                pose = rig.sample(b, local)
                k = min(1.0, local / FADE)
                e = ease_out_quad(k)
                current = {p: rig.lerp_cf(frm[p], pose[p], e) for p in rig.ORDER}
            else:
                if release is None:
                    release = (t0 + b[-1]['t'], rig.sample(b, b[-1]['t']))
                r0, held = release
                a = min(1.0, (t - r0) / RECOVER)
                current = {p: rig.lerp_cf(held[p], rest[p], sine_out(a)) for p in rig.ORDER}
            clip = mod.CLIPS[name]
            # the M1 step moves the body
            dz = preview.lunge_at(clip, local) - preview.lunge_at(clip, max(0, local - 1 / fps))
            z += dz
        out.append((t, current, z))
    return out


if __name__ == '__main__':
    mod = importlib.import_module(sys.argv[1])
    out_path = sys.argv[2]
    spec = sys.argv[3:]  # name@time ...
    plays = [(float(s.split('@')[1]), s.split('@')[0]) for s in spec]
    slow = float(os.environ.get('SLOW', 1))
    frames = simulate(mod, plays)
    imgs = []
    fps = 60
    step = 1 if slow == 1 else None
    rendered = []
    for t, x, z in frames:
        hrp = rig.T(0, 3, -z)
        hy = float(os.environ.get('HRP_Y', 3))
        hrp = rig.T(0, hy, -z)
        wd = rig.fk(x, hrp)
        if os.environ.get('PROP'):
            import weapons_geo
            wd = rig.with_prop(wd, weapons_geo.boxes(os.environ['PROP']))
        rendered.append(([(wd, preview.colours()), (preview.dummy_world(-4.6 - z, hy - 3), preview.DUMMY_COL, 'dummy')], (os.environ.get('LABEL', '') + '   %.2fs' % t).strip(), (0, hy - 3, -z)))
    if slow != 1:
        # repeat frames for slow motion
        rendered = [f for f in rendered for _ in range(int(slow))]
    imgs = rig.render_frames(rendered, views=tuple(os.environ.get('VIEWS', 'behind,front,side').split(',')))
    rig.write_video(imgs, out_path, fps)
    print(out_path, len(imgs), 'frames')
