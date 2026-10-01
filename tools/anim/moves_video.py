"""Round 63's move clips back to back, as the game plays them (a Hold key
held for the move's hold). python3 moves_video.py out.mp4"""
import sys, os
import rig, preview, moves_am, moves_rest, moves_common, getup

FPS = 30
ALL = {}
for m in (moves_am, moves_rest, moves_common, getup):
    ALL.update(m.CLIPS)
plan = [
    ('MoveDetroitSmash', 1, 'ALL MIGHT: DETROIT SMASH'),
    ('MoveDetroitSmash', 3, 'DETROIT SMASH (x3 slow)'),
    ('MoveNewHampshire', 1, 'NEW HAMPSHIRE SMASH'),
    ('MoveUnitedStatesSmash', 1, 'UNITED STATES OF SMASH'),
    ('MoveSkyUppercut', 1, 'SKY UPPERCUT'),
    ('MoveHowitzer', 1, 'BAKUGO: HOWITZER IMPACT'),
    ('LastStandWalk', 1, 'FULL-BODY CLUSTER: the walk'),
    ('ClusterPalm', 1, '...the blink, palm in the face'),
    ('ClusterStrikeA', 1, '...from every side'),
    ('ClusterStrikeB', 1, '...'),
    ('ClusterStrikeC', 1, '...'),
    ('ClusterCharge', 1, '...both palms (the white void)'),
    ('ClusterFinal', 1, '...everything he has left'),
    ('MoveStLouis', 1, 'DEKU: ST. LOUIS SMASH'),
    ('MoveManchester', 1, 'DEKU: MANCHESTER SMASH'),
    ('MoveDecayWave', 1, 'SHIGARAKI: DECAY'),
    ('MoveSpinKick', 1, 'IIDA: SPIN KICK'),
    ('PosePunchR', 1, 'held pose: PUNCH (held 0.4s)'),
    ('PoseSlam', 1, 'held pose: SLAM (held 0.4s)'),
    ('GetUpBack', 1, 'GETTING UP (on his back)'),
    ('GetUpFront', 1, 'GETTING UP (face down)'),
]
rendered = []
for name, slow, label in plan:
    clip = ALL[name]
    baked = rig.bake(clip)
    length = baked[-1]['t']
    hold_at = next((k['t'] for k in baked if k['name'] == 'Hold'), None)
    hold = 0.4 if hold_at is not None else 0
    n = int((length + hold + 0.25) * FPS * slow)
    for i in range(n + 1):
        t = i / (FPS * slow)
        if hold_at is not None and t > hold_at:
            t = hold_at if t < hold_at + hold else t - hold
        x = rig.sample(baked, min(t, length))
        bodies = [(rig.fk(x, rig.T(0, 3, -preview.lunge_at(clip, t))), preview.colours()), (preview.dummy_world(), preview.DUMMY_COL, 'dummy')]
        rendered.append((bodies, '%s   %.2fs' % (label, t)))
imgs = rig.render_frames(rendered, views=tuple(os.environ.get('VIEWS', 'behind,side').split(',')), cell=(400, 300))
rig.write_video(imgs, sys.argv[1], fps=FPS)
print(sys.argv[1], len(imgs), 'frames')
