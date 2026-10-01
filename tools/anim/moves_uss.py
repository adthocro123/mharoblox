"""UNITED STATES OF SMASH, round 78: the way it goes against All For One at
Kamino (anime ep. 49 / manga ch. 94). The left is a decoy that lands on his
face; the last embers of One For All go into the right arm while All Might
ducks low; then the overhand right to the face - an impact frame, the world
stops - and it drives him down into the street. Then the raised fist.

Each is a "Move<name>" clip (ReplicatedStorage.Animations), played by the
move's effects at its beats (they don't run on one clock: the build only
starts if the lunge catches someone):
  MoveUSSLunge   on the press: coil, the lunge with the left ("Hit": the fist
                 is out from there on, so a catch anywhere along it reads)
  MoveUSSWhiff   nobody caught: over-reached, he stumbles out of it
  MoveUSSBuild   caught: steps in, sinks low, the right fist cocked high
                 behind him - held on its "Hold" key through "UNITED STATES
                 OF..." (the move says how long)
  MoveUSSSmash   the overhand right lands on the face ("Hit" - hitstop
                 freezes it there for the impact frame), then drives down
                 through them into the street ("Slam")
  MoveUSSVictory the fist raised high ("Hold")
"""
from moves_lib import P, merge, REST, blend, over, seq, OUT, IN, INOUT, LIN

CLIPS = {}

# ---------------------------------------------------------------- the decoy
LU_COIL = P(body=dict(y=-0.42, twist=26, lean=14, fwd=-0.12, tilt=4), la=(-28, 0, 22), ra=(38, 24, 22),
            rl=dict(f=-1.0, s=0.38), ll=dict(f=0.9, s=0.16), head=(-6, -18, 0))
LU_JAB = P(body=dict(y=-0.48, twist=-36, lean=26, fwd=0.62, tilt=-4), la=(94, 6, 0), ra=(-22, 0, 32),
           rl=dict(f=-1.65, s=0.36), ll=dict(f=1.35, s=0.12), head=(-10, 22, 0))
CLIPS['MoveUSSLunge'] = seq('MoveUSSLunge', [
    (0.0, REST, OUT),
    (0.11, LU_COIL, IN),
    (0.18, over(LU_COIL, LU_JAB, 0.1), OUT, 'Hit'),
    (0.27, LU_JAB, INOUT),
    (0.56, merge(LU_JAB, body=dict(y=-0.46, twist=-34, lean=24, fwd=0.6, tilt=-4)), INOUT),
    (0.8, blend(LU_JAB, REST, 0.55), INOUT),
    (1.05, REST, INOUT),
])

# nobody there: he over-reaches and stumbles out of it
WH_OVER = P(body=dict(y=-0.62, twist=-30, lean=40, fwd=0.85, tilt=-8), la=(70, 0, 20), ra=(-30, 0, 40),
            rl=dict(f=-1.8, s=0.4), ll=dict(f=1.6, s=0.2), head=(-20, 10, 0))
CLIPS['MoveUSSWhiff'] = seq('MoveUSSWhiff', [
    (0.0, LU_JAB, OUT),
    (0.14, WH_OVER, OUT),
    (0.42, blend(WH_OVER, REST, 0.45), INOUT),
    (0.72, REST, INOUT),
])

# ---------------------------------------------------------------- caught
# he steps in under them, left hand still up at them; then low, the right
# fist cocked high behind his head with everything he has left
BU_STEP = P(body=dict(y=-0.6, twist=-8, lean=18, fwd=0.3), la=(70, -6, 10), ra=(120, -10, 30),
            rl=dict(f=-1.2, s=0.42), ll=dict(f=1.0, s=0.18), head=(-14, 0, 0))
BU_COCK = P(body=dict(y=-0.82, twist=-42, lean=14, fwd=0.05, tilt=10), la=(92, -14, 4), ra=(158, -14, 36),
            rl=dict(f=-1.45, s=0.5), ll=dict(f=1.05, s=0.22), head=(-22, 30, 0))
BU_DEEP = merge(BU_COCK, body=dict(y=-0.9, twist=-48, lean=16, fwd=0.0, tilt=12), ra=(164, -16, 38), la=(96, -16, 4))
CLIPS['MoveUSSBuild'] = seq('MoveUSSBuild', [
    (0.0, LU_JAB, OUT),
    (0.14, BU_STEP, OUT),
    (0.32, BU_COCK, INOUT, 'Hold'),
    (0.5, BU_DEEP, IN),
])

# the overhand right on the face; then down through them into the street
SM_FACE = P(body=dict(y=-0.36, twist=40, lean=30, fwd=0.6, tilt=-8), ra=(80, 14, 0), la=(-34, 0, 34),
            rl=dict(f=-1.7, s=0.4), ll=dict(f=1.3, s=0.14), head=(-6, -16, 0))
SM_DRIVE = P(body=dict(y=-1.05, twist=34, lean=52, fwd=0.95, tilt=-6), ra=(30, 12, 0), la=(-44, 0, 40),
             rl=dict(f=-1.95, s=0.44), ll=dict(f=1.45, s=0.2), head=(10, -10, 0))
CLIPS['MoveUSSSmash'] = seq('MoveUSSSmash', [
    (0.0, BU_DEEP, IN),
    (0.06, over(BU_DEEP, SM_FACE, 0.06), OUT, 'Hit'),
    (0.1, SM_FACE, INOUT),
    (0.18, over(SM_FACE, SM_DRIVE, 0.08), OUT, 'Slam'),
    (0.26, SM_DRIVE, INOUT),
    (0.62, merge(SM_DRIVE, body=dict(y=-1.0, twist=32, lean=48, fwd=0.9, tilt=-6)), INOUT),
    (0.95, blend(SM_DRIVE, REST, 0.55), INOUT),
])

# the fist raised in victory (the anime: he raises it, then the muscle form
# comes back one last time)
VI_RAISE = P(body=dict(y=-0.06, twist=6, lean=-6), ra=(174, 0, 6), la=(10, 0, 14),
             rl=dict(f=-0.3, s=0.45), ll=dict(f=0.32, s=0.38), head=(-16, 0, 0))
CLIPS['MoveUSSVictory'] = seq('MoveUSSVictory', [
    (0.0, blend(SM_DRIVE, REST, 0.55), OUT),
    (0.32, over(blend(SM_DRIVE, REST, 0.55), VI_RAISE, 0.05), OUT, 'Hit'),
    (0.42, VI_RAISE, INOUT),
    (1.6, merge(VI_RAISE, body=dict(y=-0.04, twist=5, lean=-7)), INOUT, 'Hold'),
    (1.95, REST, INOUT),
])

ORDER = list(CLIPS)
