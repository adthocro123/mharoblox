"""The looped clips as the game plays them: each for a couple of cycles, the
body carried along at the speed its stride is timed for (so a planted foot
should stay put on the street). python3 loco_video.py out.mp4"""
import sys, os
import numpy as np
import rig, preview, loco

FPS = 60
plan = [('LocoIdle', 3.2, 'IDLE'), ('LocoFight', 1.6, 'FIGHTING STANCE'), ('LocoWalk', 1.9, 'WALK'),
        ('LocoRun', 1.4, 'RUN'), ('LocoSprint', 1.2, 'SPRINT')]
rendered = []
for name, seconds, label in plan:
    clip = loco.CLIPS[name]
    baked = rig.bake(clip)
    length = baked[-1]['t']
    speed = loco.STRIDES.get(name, 0) / length  # studs a second
    for i in range(int(seconds * FPS)):
        t = i / FPS
        z = speed * t
        x = rig.sample(baked, t % length)
        wd = rig.fk(x, rig.T(0, 3, -z))
        rendered.append(([(wd, preview.colours())], '%s   %.1f studs/s' % (label, speed), (0, 0, -z)))
imgs = rig.render_frames(rendered, views=tuple(os.environ.get('VIEWS', 'side,front').split(',')))
rig.write_video(imgs, sys.argv[1], fps=FPS)
print(sys.argv[1], len(imgs), 'frames')
