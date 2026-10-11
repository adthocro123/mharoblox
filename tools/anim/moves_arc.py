"""THE ARCANIST (round 109) as keyframed R6 clips: the wand drawn and put
away, its M1 flicks, and a clip for each way a spell is cast (Config.Grimoire
.Spells[...].Clip). His wand sits in his right fist as a straight extension
of the arm, tipped a little forward (Kit.GR.WAND), so where the right arm
points is where the wand points: every cast is a wind-up the eye can read,
the wand snapping onto the aim at the key named "Hit" (the spell's Windup:
the server casts it then), a held beat, and a settle into his ready stance -
wand low and forward, the left hand open.

Timing: each "Hit" key lands at (about) its spell's Windup, so the bolt
leaves the wand on the frame the wand arrives."""
from moves_lib import P, merge, REST, blend, over, seq, OUT, IN, INOUT, LIN
import rig

CLIPS = {}

# the ready stance (wand out): bladed a touch, weight low, the wand forward
# and down, the left hand open at the hip
READY = P(body=dict(y=-0.12, twist=-12, lean=4), ra=(48, 12, 6), la=(18, -6, 14),
          rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))

# DRAW (R, 0.4 s): the right hand crosses to the wand at his left hip, pulls
# it up across the body, and flourishes it out into the ready stance
REACH = P(body=dict(y=-0.06, twist=18, lean=6), ra=(26, 52, -6), la=(10, 0, 18), head=(14, 16, 0))
PULL = P(body=dict(y=-0.04, twist=6, lean=2), ra=(118, 36, 4), la=(14, 0, 22), head=(-4, 6, 0))
FLOURISH = P(body=dict(y=-0.1, twist=-14, lean=4), ra=(76, 6, 18), la=(26, -10, 20), head=(-2, -4, 0))
CLIPS['MoveArcDraw'] = seq('MoveArcDraw', [
    (0.0, REST, OUT),
    (0.1, REACH, OUT),
    (0.2, PULL, OUT, 'Hit'),
    (0.3, over(PULL, FLOURISH, 0.12), INOUT),
    (0.42, READY, INOUT),
    (0.6, blend(READY, REST, 0.5), INOUT),
])
# PUT AWAY: the wand twirled down and slid back into the belt
TWIRL = P(body=dict(y=-0.06, twist=-6), ra=(132, 18, 10), la=(16, 0, 18), head=(-6, 0, 0))
CLIPS['MoveArcSheathe'] = seq('MoveArcSheathe', [
    (0.0, READY, OUT),
    (0.1, TWIRL, OUT),
    (0.22, REACH, INOUT, 'Hit'),
    (0.4, REST, INOUT),
])

# THE M1s: a flick of the wrist that snaps the wand onto the aim; the 2nd
# the same off a backhand; the 4th wound right back over the shoulder and
# driven through with the body behind it
COCK = P(body=dict(y=-0.12, twist=-22, lean=2), ra=(104, 26, 10), la=(24, -8, 20), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
FLICK = P(body=dict(y=-0.14, twist=10, lean=8), ra=(90, 4, 4), la=(14, -14, 22), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
CLIPS['MoveArcBolt'] = seq('MoveArcBolt', [
    (0.0, blend(READY, COCK, 0.8), OUT),
    (0.06, over(COCK, FLICK, 0.12), OUT, 'Hit'),
    (0.14, FLICK, INOUT),
    (0.32, READY, INOUT),
])
BACKCOCK = P(body=dict(y=-0.12, twist=14, lean=2), ra=(96, 58, -4), la=(22, -10, 22), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
BACKFLICK = P(body=dict(y=-0.14, twist=-14, lean=8), ra=(92, -14, 12), la=(16, -18, 24), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
CLIPS['MoveArcBoltL'] = seq('MoveArcBoltL', [
    (0.0, blend(READY, BACKCOCK, 0.8), OUT),
    (0.06, over(BACKCOCK, BACKFLICK, 0.12), OUT, 'Hit'),
    (0.14, BACKFLICK, INOUT),
    (0.32, READY, INOUT),
])
OVERHEAD = P(body=dict(y=-0.08, twist=-28, lean=-8), ra=(168, 22, 8), la=(60, -20, 30), head=(-10, 8, 0),
             rl=dict(f=-0.85, s=0.35), ll=dict(f=0.6, s=0.15))
DRIVE = P(body=dict(y=-0.3, twist=16, lean=18, fwd=0.3), ra=(88, 2, 2), la=(-24, -6, 26), head=(4, -6, 0),
          rl=dict(f=-1.1, s=0.35), ll=dict(f=1.0, s=0.15))
CLIPS['MoveArcBoltFin'] = seq('MoveArcBoltFin', [
    (0.0, READY, OUT),
    (0.09, OVERHEAD, OUT),
    (0.15, over(OVERHEAD, DRIVE, 0.12), OUT, 'Hit'),
    (0.3, DRIVE, INOUT),
    (0.55, READY, INOUT),
])

# CAST (a bolt: Ember Dart, Fireball, Chain Spark): the wand drawn back by
# the ear, the left hand out to aim, then thrust straight down the line
BACK = P(body=dict(y=-0.12, twist=-26, lean=-2), ra=(140, 30, 16), la=(80, -16, 8), head=(-2, 10, 0),
         rl=dict(f=-0.8, s=0.35), ll=dict(f=0.7, s=0.15))
THRUST = P(body=dict(y=-0.18, twist=14, lean=10, fwd=0.15), ra=(92, 2, 2), la=(30, -12, 26), head=(2, -4, 0),
           rl=dict(f=-0.95, s=0.35), ll=dict(f=0.85, s=0.15))
CLIPS['MoveArcCast'] = seq('MoveArcCast', [
    (0.0, blend(READY, BACK, 0.4), OUT),
    (0.08, BACK, OUT),
    (0.13, over(BACK, THRUST, 0.1), OUT, 'Hit'),
    (0.24, THRUST, INOUT, 'Hold'),
    (0.5, READY, INOUT),
])

# FAN (Frost Shard): the wand swept flat across the front, left to right
SWL = P(body=dict(y=-0.12, twist=28, lean=4), ra=(90, 62, 0), la=(30, -8, 24), head=(0, 18, 0),
        rl=dict(f=-0.75, s=0.35), ll=dict(f=0.75, s=0.15))
SWR = P(body=dict(y=-0.14, twist=-22, lean=6), ra=(88, -38, 10), la=(40, -20, 30), head=(0, -12, 0),
        rl=dict(f=-0.75, s=0.35), ll=dict(f=0.75, s=0.15))
CLIPS['MoveArcFan'] = seq('MoveArcFan', [
    (0.0, blend(READY, SWL, 0.5), OUT),
    (0.08, SWL, OUT),
    (0.14, blend(SWL, SWR, 0.5), LIN, 'Hit'),
    (0.22, over(SWL, SWR, 0.06), OUT),
    (0.5, READY, INOUT),
])

# SWEEP (Gust): a big backhand sweep, the left palm shoved out with it
GATHERW = P(body=dict(y=-0.2, twist=34, lean=6), ra=(70, 70, -4), la=(60, 40, 0), head=(0, 16, 0),
            rl=dict(f=-0.8, s=0.4), ll=dict(f=0.7, s=0.15))
SHOVE = P(body=dict(y=-0.24, twist=-18, lean=14, fwd=0.2), ra=(96, -48, 16), la=(92, -4, 4), head=(2, -6, 0),
          rl=dict(f=-1.0, s=0.4), ll=dict(f=0.95, s=0.15))
CLIPS['MoveArcSweep'] = seq('MoveArcSweep', [
    (0.0, blend(READY, GATHERW, 0.5), OUT),
    (0.1, GATHERW, OUT),
    (0.16, over(GATHERW, SHOVE, 0.12), OUT, 'Hit'),
    (0.3, SHOVE, INOUT),
    (0.55, READY, INOUT),
])

# SELF (Mend, Ward): the wand brought to the chest, the head bowed, then
# raised high - the light comes down on him
CHEST = P(body=dict(y=-0.08, lean=8), ra=(58, 72, 0), la=(52, 64, 0), head=(22, 0, 0),
          rl=dict(f=-0.35, s=0.3), ll=dict(f=0.35, s=0.2))
RAISE = P(body=dict(y=0.02, lean=-8), ra=(172, 10, 8), la=(40, -10, 34), head=(-24, 0, 0),
          rl=dict(f=-0.35, s=0.3), ll=dict(f=0.35, s=0.2))
CLIPS['MoveArcSelf'] = seq('MoveArcSelf', [
    (0.0, blend(READY, CHEST, 0.5), OUT),
    (0.1, CHEST, OUT),
    (0.2, over(CHEST, RAISE, 0.08), OUT, 'Hit'),
    (0.42, RAISE, INOUT, 'Hold'),
    (0.7, READY, INOUT),
])

# BLINK: a quick dip and the wand flicked along the way he goes
DIP = P(body=dict(y=-0.4, lean=22, twist=-6), ra=(70, 10, 10), la=(30, -10, 26), head=(-10, 0, 0),
        rl=dict(f=-0.8, s=0.35), ll=dict(f=0.6, s=0.2))
GO = P(body=dict(y=-0.2, lean=26, fwd=0.3), ra=(96, 0, 4), la=(-20, 0, 30), head=(-16, 0, 0),
       rl=dict(f=-1.2, s=0.3), ll=dict(f=0.9, s=0.2))
CLIPS['MoveArcBlink'] = seq('MoveArcBlink', [
    (0.0, blend(READY, DIP, 0.6), OUT),
    (0.06, over(DIP, GO, 0.1), OUT, 'Hit'),
    (0.2, GO, INOUT),
    (0.42, READY, INOUT),
])

# POINT (Shade Snare): the wand stabbed down at a spot on the street ahead
POINTUP = P(body=dict(y=-0.08, twist=-16, lean=-4), ra=(150, 18, 10), la=(50, -16, 26), head=(10, 6, 0),
            rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
POINTDOWN = P(body=dict(y=-0.22, twist=10, lean=16), ra=(58, 4, 2), la=(28, -20, 34), head=(24, -2, 0),
              rl=dict(f=-0.9, s=0.35), ll=dict(f=0.85, s=0.15))
CLIPS['MoveArcPoint'] = seq('MoveArcPoint', [
    (0.0, blend(READY, POINTUP, 0.5), OUT),
    (0.1, POINTUP, OUT),
    (0.17, over(POINTUP, POINTDOWN, 0.1), OUT, 'Hit'),
    (0.34, POINTDOWN, INOUT, 'Hold'),
    (0.6, READY, INOUT),
])

# THRUST (Glacial Lance): a fencer's lunge - wand low and back, then the
# whole body behind it, the back leg straight
LOW = P(body=dict(y=-0.3, twist=-34, lean=6), ra=(36, -14, 24), la=(70, 10, 10), head=(0, 14, 0),
        rl=dict(f=-0.9, s=0.4), ll=dict(f=0.8, s=0.15))
LUNGE = P(body=dict(y=-0.5, twist=12, lean=22, fwd=0.5), ra=(94, 0, 0), la=(-30, 0, 30), head=(-6, -6, 0),
          rl=dict(f=-1.6, s=0.4), ll=dict(f=1.3, s=0.15))
CLIPS['MoveArcThrust'] = seq('MoveArcThrust', [
    (0.0, blend(READY, LOW, 0.4), OUT),
    (0.18, LOW, INOUT),
    (0.3, over(LOW, LUNGE, 0.1), OUT, 'Hit'),
    (0.46, LUNGE, INOUT, 'Hold'),
    (0.75, READY, INOUT),
])

# SKY (Thundercall, Meteor, Starfall): the wand thrust straight up to call
# it down, then brought down to point at where it's coming
SKYUP = P(body=dict(y=0.04, lean=-12, twist=-6), ra=(178, 4, 6), la=(30, -8, 50), head=(-32, 0, 0),
          rl=dict(f=-0.45, s=0.35), ll=dict(f=0.45, s=0.2))
SKYPOINT = P(body=dict(y=-0.12, lean=8, twist=8), ra=(78, 4, 4), la=(20, -10, 30), head=(6, 0, 0),
             rl=dict(f=-0.7, s=0.35), ll=dict(f=0.7, s=0.15))
CLIPS['MoveArcSky'] = seq('MoveArcSky', [
    (0.0, blend(READY, SKYUP, 0.4), OUT),
    (0.12, over(READY, SKYUP, 0.06), OUT),
    (0.2, SKYUP, INOUT, 'Hit'),
    (0.42, SKYUP, INOUT, 'Hold'),
    (0.58, SKYPOINT, INOUT),
    (0.85, READY, INOUT),
])

# CHANNEL (Void Orb, Tempest): both hands forward, the wand and the open
# palm, leaning into it as it goes out
CUP = P(body=dict(y=-0.16, lean=2, twist=-8), ra=(64, 34, 4), la=(64, 34, 4), head=(8, 0, 0),
        rl=dict(f=-0.75, s=0.4), ll=dict(f=0.7, s=0.2))
PUSH = P(body=dict(y=-0.26, lean=16, twist=4, fwd=0.25), ra=(90, 10, 2), la=(90, 12, 2), head=(-4, 0, 0),
         rl=dict(f=-1.05, s=0.4), ll=dict(f=0.95, s=0.2))
CLIPS['MoveArcChannel'] = seq('MoveArcChannel', [
    (0.0, blend(READY, CUP, 0.5), OUT),
    (0.14, CUP, INOUT),
    (0.25, over(CUP, PUSH, 0.08), OUT, 'Hit'),
    (0.5, PUSH, INOUT, 'Hold'),
    (0.8, READY, INOUT),
])

# SLAM (Absolute Zero): the wand up over the head in both hands, then
# driven down into the street, down on one knee
HIGH = P(body=dict(y=0.06, lean=-14), ra=(176, 8, 2), la=(170, 20, 2), head=(-24, 0, 0),
         rl=dict(f=-0.4, s=0.35), ll=dict(f=0.4, s=0.2))
KNEEL = P(body=dict(y=-1.15, lean=30), ra=(30, 10, 2), la=(36, 24, 2), head=(16, 0, 0),
          rl=dict(f=-1.2, s=0.35), ll=dict(f=0.7, s=0.2))
CLIPS['MoveArcSlam'] = seq('MoveArcSlam', [
    (0.0, blend(READY, HIGH, 0.5), OUT),
    (0.22, HIGH, INOUT),
    (0.35, over(HIGH, KNEEL, 0.06), IN, 'Hit'),
    (0.6, KNEEL, INOUT, 'Hold'),
    (0.95, READY, INOUT),
])

# THE BOOK (Y): the grimoire held open in the left hand, the wand's tip
# turning its pages; held as long as the book's open
BOOK = P(body=dict(y=-0.04, lean=6), la=(62, 44, 0), ra=(58, 56, -4), head=(26, 4, 0),
         rl=dict(f=-0.3, s=0.3), ll=dict(f=0.3, s=0.2))
TURN = merge(BOOK, ra=(66, 30, 4))
CLIPS['MoveArcBook'] = seq('MoveArcBook', [
    (0.0, REST, OUT),
    (0.22, BOOK, OUT, 'Hit'),
    (0.5, TURN, INOUT),
    (0.8, BOOK, INOUT, 'Hold'),
    (1.1, REST, INOUT),
])

ORDER = list(CLIPS)
