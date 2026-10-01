"""Every other hero's moves as keyframed clips (round 63): Deku, Todoroki,
Shigaraki, Overhaul, Lemillion, Suneater, Kamui Woods, Mr. Compress,
Kaminari, Creati, Iida, and the dash punch. Timing follows each move's
motion (its strike lands when the move's hit does)."""
from moves_lib import P, merge, REST, STANCE, blend, over, seq, OUT, IN, INOUT, LIN
import rig

CLIPS = {}


def two(name, a1, e1, pose1, a2, e2, pose2, end_extra=0.3, drift=0.04, over_k=0.1, deep=None, hitname='Hit', mid=None):
    """The common shape: into a first pose (arrive a1, held to e1 - sinking
    deeper), the snap into the second (arrive a2 "Hit", past it), held to
    e2 with a drift, a follow-through, rest."""
    deep = deep if deep is not None else blend(REST, pose1, 1.06)
    keys = [(0.0, REST, OUT), (a1, pose1, OUT)]
    if e1 - a1 > 0.03:
        keys.append((e1, deep, IN))
    keys.append((a2, over(deep, pose2, over_k), OUT, hitname))
    keys.append((min(a2 + 0.08, e2), pose2, INOUT))
    if e2 - a2 > 0.14:
        keys.append((e2, blend(pose2, REST, drift), INOUT))
    keys.append((e2 + end_extra * 0.45, blend(pose2, REST, 0.6), INOUT))
    keys.append((e2 + end_extra, REST, INOUT))
    return seq(name, keys)


def one(name, a, e, pose, end_extra=0.3, start=None, over_k=0.1):
    """A single held pose: snap in ("Hit", past it), held, out."""
    start = start if start is not None else blend(REST, pose, -0.2)
    keys = [(0.0, start, OUT), (a, over(start, pose, over_k), OUT, 'Hit'), (min(a + 0.08, e), pose, INOUT)]
    if e - a > 0.14:
        keys.append((e, blend(pose, REST, 0.05), INOUT))
    keys.append((e + end_extra * 0.45, blend(pose, REST, 0.6), INOUT))
    keys.append((e + end_extra, REST, INOUT))
    return seq(name, keys)


LUNGE = dict(rl=dict(f=-1.15, s=0.32), ll=dict(f=0.95, s=0.1))
BRACE = dict(rl=dict(f=-0.95, s=0.42), ll=dict(f=0.75, s=0.3))
WIDE = dict(rl=dict(f=-0.25, s=0.7), ll=dict(f=0.25, s=0.65))

# ------------------------------------------------------------------ DEKU
# FULL COWL: gathered into a crouch, then up with the lightning crackling
# off him, arms out from his sides
CLIPS['MoveCowlUp'] = two('MoveCowlUp', 0.12, 0.24,
                          P(body=dict(y=-0.9, lean=24), ra=(-20, 0, 30), la=(-20, 0, 30), head=(12, 0, 0), rl=dict(f=-0.45, s=0.5), ll=dict(f=0.5, s=0.45)),
                          0.32, 0.67, P(body=dict(y=0.05, lean=-12), ra=(22, -6, 56), la=(22, -6, 56), head=(-12, 0, 0), rl=dict(f=-0.2, s=0.45), ll=dict(f=0.2, s=0.4)), end_extra=0.37)
# AIR FORCE: the flick, the wrist snapping forward
FLICK = P(body=dict(y=-0.2, twist=26, lean=8, fwd=0.15), ra=(92, 4, -2, 60), la=(26, 10, 26), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.7, s=0.15))
CLIPS['MoveFlick'] = two('MoveFlick', 0.08, 0.12, merge(FLICK, body=dict(y=-0.16, twist=14, lean=4), ra=(78, 6, -2, 0)), 0.15, 0.23, FLICK, end_extra=0.14)
AF = P(body=dict(y=-0.45, twist=30, lean=10, fwd=0.2), ra=(96, 4, -2, 60), la=(22, 10, 32), rl=dict(f=-1.0, s=0.4, turn=16), ll=dict(f=0.8, s=0.15))
CLIPS['MoveAirForceR'] = two('MoveAirForceR', 0.05, 0.07, merge(AF, body=dict(y=-0.42, twist=18, lean=6), ra=(82, 0, 0, 0)), 0.1, 0.16, AF, end_extra=0.14)
CLIPS['MoveAirForceL'] = seq('MoveAirForceL', [(k['t'], rig.mirror(k['pose']), k['ease'], k['name']) for k in CLIPS['MoveAirForceR']['keys']])
# BLACKWHIP: the arm flung out, the whip leaving the palm
CLIPS['MoveWhipCast'] = one('MoveWhipCast', 0.08, 0.3, P(body=dict(y=-0.25, twist=24, lean=10, fwd=0.2), ra=(94, 2, 0, 90), la=(40, 20, 20), **LUNGE), end_extra=0.14)
# ...and hauled in: both arms out holding it, then yanked back down
CLIPS['MoveWhipBind'] = two('MoveWhipBind', 0.08, 0.51,
                            P(body=dict(y=-0.3, lean=8), ra=(94, 14, 10), la=(94, 14, 10), **BRACE),
                            0.59, 0.72, P(body=dict(y=-0.55, lean=26, fwd=-0.2), ra=(16, 6, 22), la=(16, 6, 22), rl=dict(f=-0.9, s=0.45), ll=dict(f=0.6, s=0.35)), end_extra=0.15)
# ST. LOUIS SMASH: sunk and wound up, then a full spin in the air into the
# roundhouse, the leg out straight
SL_WIND = P(body=dict(y=-0.5, twist=-40, lean=10), ra=(24, 0, 28), la=(60, 10, 18), rl=dict(f=-0.5, s=0.5), ll=dict(f=0.5, s=0.3))
SL = [P(body=dict(pivot='center', legs='chest', twist=a, tilt=-12, y=0.2), ra=(20, 0, 62), la=(20, 0, 62), rl=(30 + 10 * i, 0, 70 + 4 * i), ll=(-6, 0, 10), head=(0, -a * 0.15, 0))
      for i, a in enumerate((46, 136, 226, 330))]
CLIPS['MoveStLouis'] = seq('MoveStLouis', [
    (0.0, REST, OUT), (0.08, SL_WIND, OUT), (0.1, merge(SL_WIND, body=dict(y=-0.56, twist=-46, lean=12)), IN),
    (0.14, SL[0], LIN), (0.17, SL[1], LIN), (0.21, SL[2], LIN),
    (0.25, merge(SL[3], rl=(60, 0, 82)), OUT, 'Hit'), (0.36, SL[3], INOUT),
    (0.44, merge(STANCE, body=dict(y=-0.4, twist=-10)), INOUT), (0.55, REST, INOUT),
])
# MANCHESTER SMASH: a front flip - tucked, turning over - and the heel
# brought down out of it
MC = [P(body=dict(pivot='center', legs='chest', lean=a, y=0.3), ra=(60, 20, 30), la=(60, 20, 30), rl=(100, 0, 8), ll=(100, 0, 10), head=(-20, 0, 0))
      for a in (100, 190, 280)]
MC_AXE = P(body=dict(pivot='center', legs='chest', lean=345 - 360, y=0.2), ra=(20, 0, 45), la=(30, 0, 45), rl=(165, 0, 6), ll=(-12, 0, 8))
MC_LAND = P(body=dict(y=-0.6, lean=22, fwd=0.2), ra=(-16, 0, 36), la=(-16, 0, 36), rl=dict(f=0.5, s=0.35), ll=dict(f=-0.4, s=0.3))
CLIPS['MoveManchester'] = seq('MoveManchester', [
    (0.0, REST, OUT), (0.07, P(body=dict(y=-0.75, lean=26), ra=(-40, 0, 20), la=(-40, 0, 20), rl=dict(f=-0.3, s=0.4), ll=dict(f=0.3, s=0.35)), OUT),
    (0.14, MC[0], LIN), (0.21, MC[1], LIN), (0.28, MC[2], LIN),
    (0.36, MC_AXE, OUT), (0.41, MC_AXE, IN),
    (0.47, over(MC_AXE, MC_LAND, 0.08), OUT, 'Hit'), (0.55, MC_LAND, INOUT), (0.72, REST, INOUT),
])
# DETROIT SMASH 100%: the same wind-up as All Might's, held longer, and the
# punch driven all the way through
D_COIL = P(body=dict(y=-0.5, twist=-50, lean=6, fwd=-0.25, tilt=6), ra=(-66, -8, 24), la=(84, -12, 8), rl=dict(f=-1.3, s=0.45, turn=24), ll=dict(f=0.95, s=0.15))
D_HIT = P(body=dict(y=-0.5, twist=44, lean=20, fwd=0.72), ra=(95, 6, 0), la=(-40, 4, 34), rl=dict(f=-1.55, s=0.35), ll=dict(f=1.25, s=0.1))
CLIPS['MoveDetroit100'] = two('MoveDetroit100', 0.2, 1.0, D_COIL, 1.05, 1.75, D_HIT, end_extra=0.44,
                              deep=merge(D_COIL, body=dict(y=-0.6, twist=-58, lean=8, fwd=-0.3, tilt=7), ra=(-72, -8, 28)))
# FA JIN: the squat and the launch (the power in the legs)
CLIPS['MoveFaJinLaunch'] = one('MoveFaJinLaunch', 0.06, 0.24,
                               P(body=dict(y=-0.95, lean=34, twist=18, fwd=-0.2), ra=(-46, 0, 18), la=(70, 10, 10), rl=dict(f=-1.0, s=0.45), ll=dict(f=0.5, s=0.4), head=(-22, -10, 0)),
                               end_extra=0.25)
CLIPS['MoveFaJinRelease'] = one('MoveFaJinRelease', 0.04, 0.59, D_HIT, end_extra=0.4,
                                start=P(body=dict(y=-0.55, twist=-40, lean=10, fwd=-0.2), ra=(-50, 0, 24), la=(80, -10, 8), rl=dict(f=-1.2, s=0.45), ll=dict(f=0.9, s=0.15)))
# GEARSHIFT: sunk low, the right arm thrown back as it shifts
GS = P(body=dict(y=-0.62, lean=20, twist=-16), ra=(-24, 0, 18), la=(62, 14, 10), rl=dict(f=-0.7, s=0.45), ll=dict(f=0.4, s=0.35), head=(-12, 12, 0))
CLIPS['MoveGearshiftShift'] = two('MoveGearshiftShift', 0.05, 0.08, merge(GS, ra=(28, 0, 14), body=dict(y=-0.6, lean=18, twist=-10)), 0.12, 0.22, GS, end_extra=0.22)
# a kick straight up (the launch in the rain of blows)
CLIPS['MoveRainLaunch'] = two('MoveRainLaunch', 0.11, 0.11, P(body=dict(y=-0.2, twist=-14, lean=8), ra=(44, 0, 10), la=(46, 0, 10), rl=(40, 0, 6), ll=dict(f=0.05, s=0.25)),
                              0.18, 0.26, P(body=dict(y=0.0, lean=-16, twist=18), ra=(-20, 0, 26), la=(34, 0, 36), rl=(128, 0, 4), ll=dict(f=0.1, s=0.25)), end_extra=0.15)

# ------------------------------------------------------------------ TODOROKI
# ICE WALL: the right foot lifted high... and stamped down, the ice racing
# out from it
CLIPS['MoveIceWall'] = two('MoveIceWall', 0.25, 0.49,
                           P(body=dict(y=0.0, lean=-10, tilt=6), ra=(40, 0, 42), la=(40, 0, 42), rl=(78, 0, 6), ll=dict(f=0.0, s=0.25)),
                           0.55, 1.45, P(body=dict(y=-0.5, lean=24, fwd=0.2), ra=(30, 0, 50), la=(-40, 0, 20), rl=dict(f=0.45, s=0.5), ll=dict(f=-0.45, s=0.3)), end_extra=0.37)

# ------------------------------------------------------------------ SHIGARAKI
MENACE = P(body=dict(y=-0.08, lean=-10), ra=(40, -10, 70), la=(40, -10, 70), head=(-14, 0, 0), rl=dict(f=-0.2, s=0.4), ll=dict(f=0.2, s=0.35))
TOUCH = P(body=dict(y=-0.9, lean=40, fwd=0.2), ra=(40, 6, 4, 90), la=(-20, 0, 24), rl=dict(f=-0.7, s=0.45), ll=dict(f=0.6, s=0.35), head=(-10, 0, 0))
HANDS = P(body=dict(y=-1.05, lean=46, fwd=0.25), ra=(40, 14, 4, 90), la=(40, 14, 4, 90), rl=dict(f=-0.6, s=0.55), ll=dict(f=0.6, s=0.5), head=(-12, 0, 0))
CLIPS['MoveDecayWave'] = two('MoveDecayWave', 0.08, 0.1, MENACE, 0.22, 0.77, TOUCH, end_extra=0.31)
CLIPS['MoveGrasp'] = one('MoveGrasp', 0.06, 0.51, P(body=dict(y=-0.25, twist=24, lean=16, fwd=0.35), ra=(94, 6, 0, -40), la=(-30, 0, 16), **LUNGE), end_extra=0.25)
CLIPS['MoveCollapse'] = two('MoveCollapse', 0.15, 0.35, MENACE, 0.5, 1.5, HANDS, end_extra=0.44)
CLIPS['MoveTotalDecay'] = two('MoveTotalDecay', 0.3, 1.0, MENACE, 1.2, 3.6, HANDS, end_extra=0.5, drift=0.02,
                              deep=merge(MENACE, ra=(46, -10, 74), la=(46, -10, 74), body=dict(y=-0.14, lean=-14)))
CLIPS['MoveRivetStab'] = one('MoveRivetStab', 0.06, 0.56, P(body=dict(y=-0.28, twist=20, lean=8, fwd=0.2), ra=(92, 4, 0), la=(70, 30, 4), **LUNGE), end_extra=0.25)
CLIPS['MoveRivetStorm'] = one('MoveRivetStorm', 0.1, 0.75, MENACE, end_extra=0.31)
CLIPS['MoveRadioWaves'] = two('MoveRadioWaves', 0.12, 0.38,
                              P(body=dict(y=-0.38, twist=-40, lean=6, fwd=-0.15), ra=(-60, 0, 14), la=(46, 0, 14), rl=dict(f=-1.0, s=0.45), ll=dict(f=0.8, s=0.2)),
                              0.43, 0.88, P(body=dict(y=-0.26, lean=12, fwd=0.3), ra=(92, 16, 0, 90), la=(92, 16, 0, 90), **BRACE), end_extra=0.31)

# ------------------------------------------------------------------ OVERHAUL
OV_DOWN = P(body=dict(y=-1.0, lean=40, twist=8, fwd=0.2), ra=(56, 4, -6, 90), la=(20, 0, 22), rl=dict(f=0.55, s=0.4), ll=dict(f=-0.35, s=0.35), head=(-16, 0, 0))
CLIPS['MoveOverhaulTouch'] = one('MoveOverhaulTouch', 0.06, 0.38, P(body=dict(y=-0.22, twist=26, lean=12, fwd=0.25), ra=(90, 4, -4, -90), la=(16, 0, 14), **LUNGE), end_extra=0.25)
CLIPS['MoveOverhaulSlam'] = one('MoveOverhaulSlam', 0.12, 0.52, OV_DOWN, end_extra=0.31,
                                start=P(body=dict(y=-0.1, lean=-6), ra=(120, 0, 10), la=(20, 0, 22), rl=dict(f=-0.2, s=0.35), ll=dict(f=0.2, s=0.3)))
CLIPS['MoveOverhaulGloves'] = two('MoveOverhaulGloves', 0.15, 0.55,
                                  P(body=dict(y=-0.05, lean=4, twist=-10), ra=(70, 40, 0), la=(56, 30, 0), head=(12, 10, 0), rl=dict(f=-0.2, s=0.3), ll=dict(f=0.2, s=0.3)),
                                  0.7, 1.9, OV_DOWN, end_extra=0.37)

# ------------------------------------------------------------------ LEMILLION
CLIPS['MoveHammerDown'] = two('MoveHammerDown', 0.08, 0.18,
                              P(body=dict(y=-0.05, lean=-16), ra=(176, 10, 0), la=(176, 10, 0), rl=dict(f=-0.3, s=0.35), ll=dict(f=0.3, s=0.3)),
                              0.23, 0.53, P(body=dict(y=-0.7, lean=36, fwd=0.35), ra=(40, 16, 0), la=(40, 16, 0), rl=dict(f=-0.8, s=0.45), ll=dict(f=0.7, s=0.35)), end_extra=0.31)

# ------------------------------------------------------------------ SUNEATER
# CHICKEN KICK: crouched, then the talon leg snapped straight up and over
CLIPS['MoveChickenKick'] = two('MoveChickenKick', 0.08, 0.14,
                               P(body=dict(y=-0.55, lean=18), ra=(34, 0, 36), la=(34, 0, 36), rl=(28, 0, 8), ll=dict(f=0.2, s=0.3)),
                               0.2, 0.44, P(body=dict(y=0.0, lean=-26), ra=(-44, 0, 44), la=(56, 0, 56), rl=(168, 0, 4), ll=dict(f=0.1, s=0.25), head=(-20, 0, 0)), end_extra=0.35)
# TAKO THRASH: the tentacle arm raised and lashed across, three times
T_UP = P(body=dict(y=-0.1, lean=-8), ra=(172, 0, 8), la=(30, 0, 30), head=(-18, 0, 0), rl=dict(f=-0.2, s=0.35), ll=dict(f=0.2, s=0.3))
T_L = P(body=dict(y=-0.35, twist=-34, lean=18), ra=(46, -20, 64), la=(20, 0, 30), rl=dict(f=-0.7, s=0.45), ll=dict(f=0.6, s=0.25))
T_R = P(body=dict(y=-0.35, twist=36, lean=18), ra=(70, 56, 0), la=(20, 0, 40), rl=dict(f=-0.7, s=0.35), ll=dict(f=0.6, s=0.35))
CLIPS['MoveTakoThrash'] = seq('MoveTakoThrash', [
    (0.0, REST, OUT), (0.12, T_UP, OUT), (0.14, T_UP, IN), (0.22, over(T_UP, T_L, 0.1), OUT, 'Hit'), (0.32, T_L, INOUT),
    (0.44, T_UP, OUT), (0.46, T_UP, IN), (0.54, over(T_UP, T_R, 0.1), OUT), (0.64, T_R, INOUT),
    (0.76, T_UP, OUT), (0.78, T_UP, IN), (0.86, over(T_UP, T_L, 0.12), OUT), (1.08, T_L, INOUT),
    (1.25, blend(T_L, REST, 0.6), INOUT), (1.45, REST, INOUT),
])
# CLAM HAMMER: both fists (a clam shell) raised and brought down
CLIPS['MoveClamHammer'] = two('MoveClamHammer', 0.1, 0.18,
                              P(body=dict(y=-0.05, lean=-16), ra=(176, 12, 0), la=(176, 12, 0), rl=dict(f=-0.35, s=0.35), ll=dict(f=0.3, s=0.3)),
                              0.24, 0.64, P(body=dict(y=-0.75, lean=38, fwd=0.35), ra=(44, 16, 0), la=(44, 16, 0), rl=dict(f=-0.85, s=0.45), ll=dict(f=0.7, s=0.35)), end_extra=0.37)
# SWORDFISH: drawn back, then flung forward - impaled, thrown
CLIPS['MoveSwordfishFling'] = two('MoveSwordfishFling', 0.14, 0.36,
                                  P(body=dict(y=-0.2, twist=-24, lean=-6), ra=(138, -8, 10), la=(10, 0, 25), rl=dict(f=-0.8, s=0.4), ll=dict(f=0.6, s=0.2)),
                                  0.43, 0.63, P(body=dict(y=-0.35, twist=18, lean=20, fwd=0.35), ra=(108, 8, 4), la=(-22, 0, 22), **LUNGE), end_extra=0.31)
# URCHIN SPIKES: curled up tight, then everything flung out
CLIPS['MoveUrchinSpikes'] = two('MoveUrchinSpikes', 0.08, 0.12,
                                P(body=dict(y=-0.7, lean=24), ra=(60, 40, 0), la=(60, 40, 0), rl=dict(f=0.1, s=0.35), ll=dict(f=0.1, s=0.3), head=(18, 0, 0)),
                                0.17, 0.49, P(body=dict(y=0.0, lean=-14), ra=(74, -24, 84), la=(74, -24, 84), rl=dict(f=0.2, s=0.7), ll=dict(f=-0.2, s=0.7), head=(-18, 0, 0)), end_extra=0.31)

# ------------------------------------------------------------------ KAMUI WOODS
CLIPS['MoveRootBreaker'] = two('MoveRootBreaker', 0.07, 0.12,
                               P(body=dict(y=-0.05, lean=-12), ra=(-34, 0, 12), la=(-34, 0, 12), rl=dict(f=-0.2, s=0.35), ll=dict(f=0.25, s=0.3)),
                               0.18, 0.73, P(body=dict(y=-0.72, lean=30, fwd=0.2), ra=(54, 6, 4), la=(54, 6, 4), rl=dict(f=0.5, s=0.45), ll=dict(f=-0.4, s=0.35)), end_extra=0.31)
SW = [P(body=dict(pivot='center', legs='chest', lean=-8), ra=(176, 0, 6), la=(40, 0, 50), rl=(-30, 0, 8), ll=(-20, 0, 10), head=(-18, 0, 0)),
      P(body=dict(pivot='center', legs='chest', lean=6), ra=(172, 0, 8), la=(60, 0, 40), rl=(20, 0, 8), ll=(46, 0, 10)),
      P(body=dict(pivot='center', legs='chest', lean=18), ra=(165, 0, 10), la=(75, 0, 30), rl=(80, 0, 8), ll=(70, 0, 10)),
      P(body=dict(pivot='center', legs='chest', lean=-14), ra=(150, 0, 25), la=(100, 0, 45), rl=(70, 0, 8), ll=(50, 0, 10), head=(-20, 0, 0))]
CLIPS['MoveSwingArc'] = seq('MoveSwingArc', [
    (0.0, REST, OUT), (0.12, SW[0], OUT, 'Hit'), (0.3, SW[0], INOUT), (0.52, SW[1], INOUT), (0.64, SW[1], INOUT),
    (0.84, SW[2], INOUT), (0.96, SW[2], INOUT), (1.12, SW[3], OUT), (1.37, SW[3], INOUT), (1.8, REST, INOUT),
])

# ------------------------------------------------------------------ MR. COMPRESS
REACH = P(body=dict(y=-0.25, twist=24, lean=14, fwd=0.3), ra=(92, 6, -6, -60), la=(-40, 0, 25), **LUNGE)
TIP = P(body=dict(y=-0.05, twist=-10, lean=4), ra=(70, 30, -10), la=(10, 0, 25), head=(6, -12, 0), rl=dict(f=-0.25, s=0.3), ll=dict(f=0.25, s=0.28))
CLIPS['MoveCompressGrab'] = two('MoveCompressGrab', 0.1, 0.22, REACH, 0.34, 0.59, TIP, end_extra=0.31)
CANE = P(body=dict(y=-0.3, twist=-30, lean=-6, fwd=0.2), ra=(95, 8, 8), la=(-30, 0, 15), head=(-6, 20, 0), rl=dict(f=0.9, s=0.3), ll=dict(f=-0.8, s=0.2))
CLIPS['MoveCaneTrick'] = seq('MoveCaneTrick', [
    (0.0, REST, OUT), (0.08, over(REST, CANE, 0.1), OUT, 'Hit'), (0.28, CANE, INOUT),
    (0.4, TIP, OUT), (0.52, TIP, INOUT),
    (0.58, P(body=dict(y=-0.2, twist=22, lean=8), ra=(95, 0, 0), la=(20, 0, 10), **LUNGE), OUT), (0.78, P(body=dict(y=-0.2, twist=20, lean=8), ra=(95, 0, 0), la=(20, 0, 10), **LUNGE), INOUT),
    (0.98, P(body=dict(y=0.0, lean=-12, twist=10), ra=(166, 0, 20), la=(20, 0, 30), head=(-25, 0, 0)), OUT), (1.33, P(body=dict(y=0.0, lean=-12, twist=10), ra=(166, 0, 20), la=(20, 0, 30), head=(-25, 0, 0)), INOUT),
    (1.7, REST, INOUT),
])
FLING = P(body=dict(y=-0.15, twist=-22, lean=6), ra=(102, -10, 25), la=(15, 0, 20), rl=dict(f=0.6, s=0.3), ll=dict(f=-0.5, s=0.25))
CLIPS['MoveMarbleToss'] = one('MoveMarbleToss', 0.06, 0.36, FLING, end_extra=0.37)
OVERHEAD = P(body=dict(y=-0.1, twist=-30, lean=-12), ra=(178, 0, 15), la=(60, 0, 10), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.6, s=0.2))
CLIPS['MoveMarbleStorm'] = two('MoveMarbleStorm', 0.2, 0.3, P(body=dict(y=-0.1, lean=-10), ra=(84, -14, 80), la=(84, -14, 80), head=(-12, 0, 0)), 0.4, 1.1, OVERHEAD, end_extra=0.37)
CLIPS['MoveRubbleThrow'] = two('MoveRubbleThrow', 0.16, 0.22, OVERHEAD, 0.29, 0.54, merge(FLING, body=dict(y=-0.25, twist=26, lean=22, fwd=0.3), ra=(96, 20, 0)), end_extra=0.37)
CLIPS['MoveCaneStrike'] = one('MoveCaneStrike', 0.08, 0.33, CANE, end_extra=0.31)
CLIPS['MoveMagiciansChoice'] = one('MoveMagiciansChoice', 0.08, 0.18, P(body=dict(y=0.0, lean=-14), ra=(160, 0, 30), la=(15, 0, 25), head=(12, 0, 0)), end_extra=0.19)
CLIPS['MoveCurtainCall'] = two('MoveCurtainCall', 0.25, 1.15, P(body=dict(y=0.0, lean=-12), ra=(170, 0, 16), la=(170, 0, 16), head=(-14, 0, 0)),
                               1.23, 1.53, P(body=dict(y=-0.95, lean=34, twist=10), ra=(40, 0, 10), la=(20, 0, 30), rl=dict(f=0.5, s=0.45), ll=dict(f=-0.4, s=0.35)), end_extra=0.44)

# ------------------------------------------------------------------ KAMINARI
POINT = P(body=dict(y=-0.1, twist=-26, lean=2), ra=(95, 0, 0), la=(75, 30, 10), head=(-4, 18, 0), rl=dict(f=0.5, s=0.3), ll=dict(f=-0.45, s=0.25))
CLIPS['MovePointer'] = one('MovePointer', 0.07, 0.29, POINT, end_extra=0.25)
CLIPS['MoveStunBolt'] = one('MoveStunBolt', 0.08, 0.38, merge(POINT, body=dict(y=-0.15, twist=-30, lean=4), la=(20, 0, 20)), end_extra=0.31)
CHARGE = P(body=dict(y=-0.3, lean=14), ra=(40, -10, 70), la=(40, -10, 70), head=(20, 0, 0), rl=dict(f=-0.2, s=0.5), ll=dict(f=0.2, s=0.45))
CLIPS['MoveDischarge'] = one('MoveDischarge', 0.14, 0.49, CHARGE, end_extra=0.37)
CLIPS['MoveDischargeLine'] = two('MoveDischargeLine', 0.12, 0.24, CHARGE, 0.3, 0.6, P(body=dict(y=-0.24, lean=10, fwd=0.25), ra=(92, 16, 0, 90), la=(92, 16, 0, 90), **BRACE), end_extra=0.37)
CLIPS['MoveVolts'] = two('MoveVolts', 0.2, 0.5, CHARGE, 0.62, 1.22, P(body=dict(y=0.05, lean=-22), ra=(175, -6, 34), la=(175, -6, 34), head=(-30, 0, 0), rl=dict(f=-0.2, s=0.5), ll=dict(f=0.2, s=0.45)), end_extra=0.44)
CLIPS['MoveThunderLand'] = one('MoveThunderLand', 0.05, 0.3, P(body=dict(y=-1.1, lean=30), ra=(30, 0, 60), la=(30, 0, 60), head=(-20, 0, 0), rl=dict(f=0.5, s=0.6), ll=dict(f=-0.5, s=0.5)), end_extra=0.44, over_k=0.15)
CLIPS['MoveWheey'] = one('MoveWheey', 0.3, 1.8, P(body=dict(y=-0.2, lean=6, tilt=10), ra=(70, 0, 20), la=(8, 0, 25), head=(12, 0, 18)), end_extra=0.5)
CLIPS['MoveElectricGrasp'] = two('MoveElectricGrasp', 0.1, 0.75, P(body=dict(y=-0.2, twist=-12, lean=-6), ra=(86, 0, 10, -60), la=(30, 0, 30), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.5, s=0.2)),
                                 0.83, 1.08, P(body=dict(y=-0.6, lean=-30, twist=-10), ra=(20, 0, 15), la=(20, 0, 30), rl=dict(f=0.6, s=0.4), ll=dict(f=-0.4, s=0.3)), end_extra=0.37)
CLIPS['MoveZapTrap'] = two('MoveZapTrap', 0.09, 0.15, P(body=dict(y=-0.35, twist=24, lean=-8), ra=(-30, 0, 30), la=(40, 0, 20), rl=dict(f=-0.6, s=0.35), ll=dict(f=0.5, s=0.25)),
                           0.22, 0.42, P(body=dict(y=-0.6, twist=-18, lean=26, fwd=0.2), ra=(70, 4, 4), la=(-20, 0, 30), **LUNGE), end_extra=0.35)

# ------------------------------------------------------------------ CREATI
CLIPS['MoveMatryoshkaThrow'] = two('MoveMatryoshkaThrow', 0.1, 0.14, P(body=dict(y=-0.15, twist=-26, lean=-10), ra=(150, 0, 30), la=(60, 0, -10), rl=dict(f=-0.8, s=0.35), ll=dict(f=0.6, s=0.2)),
                                   0.2, 0.36, P(body=dict(y=-0.25, twist=24, lean=16, fwd=0.3), ra=(88, 20, 0), la=(20, 0, 30), **LUNGE), end_extra=0.25)

# ------------------------------------------------------------------ IIDA
CLIPS['MoveSpinKick'] = seq('MoveSpinKick', [
    (0.0, REST, OUT),
    (0.06, P(body=dict(pivot='center', legs='chest', twist=90, tilt=-24, y=0.1), ra=(30, 0, 70), la=(30, 0, 60), rl=(20, 0, 85), ll=(-6, 0, 8)), OUT, 'Hit'),
    (0.2, P(body=dict(pivot='center', legs='chest', twist=210, tilt=-24, y=0.1), ra=(30, 0, 70), la=(30, 0, 60), rl=(20, 0, 85), ll=(-6, 0, 8)), LIN),
    (0.32, P(body=dict(pivot='center', legs='chest', twist=330, tilt=-24, y=0.1), ra=(30, 0, 70), la=(30, 0, 60), rl=(20, 0, 85), ll=(-6, 0, 8)), LIN),
    (0.44, P(body=dict(pivot='center', legs='chest', twist=360, tilt=-10), ra=(20, 0, 40), la=(20, 0, 40), rl=(10, 0, 20), ll=(-6, 0, 8)), OUT),
    (0.64, REST, INOUT),
])
CLIPS['MoveAxeKick'] = two('MoveAxeKick', 0.06, 0.1, P(body=dict(y=0.0, lean=-12), ra=(20, 0, 40), la=(20, 0, 40), rl=(150, 0, 4), ll=dict(f=0.05, s=0.25)),
                           0.16, 0.36, P(body=dict(y=-0.4, lean=30), ra=(-20, 0, 30), la=(-20, 0, 30), rl=dict(f=0.8, s=0.3), ll=dict(f=-0.3, s=0.25)), end_extra=0.31)
CLIPS['MoveSkyward'] = two('MoveSkyward', 0.06, 0.12, P(body=dict(y=-0.4, lean=16), rl=dict(f=-0.4, s=0.3), ll=dict(f=0.3, s=0.3)),
                           0.18, 0.48, P(body=dict(y=0.0, lean=-24), ra=(-30, 0, 30), la=(40, 0, 40), rl=(170, 0, 4), ll=dict(f=0.05, s=0.25), head=(-20, 0, 0)), end_extra=0.31)

# ------------------------------------------------------------------ THE DASH PUNCH
DP_WIND = P(body=dict(y=-0.3, twist=-26, lean=18), ra=(30, 0, 18), la=(70, 10, -10), rl=dict(f=-0.9, s=0.3), ll=dict(f=0.7, s=0.15))
DP = P(body=dict(y=-0.32, twist=32, lean=22, fwd=0.4), ra=(96, 4, -6), la=(10, 0, 22), rl=dict(f=-1.3, s=0.3), ll=dict(f=0.9, s=0.1))
CLIPS['MoveDashPunch'] = two('MoveDashPunch', 0.03, 0.05, DP_WIND, 0.1, 0.22, DP, end_extra=0.25)

ORDER = list(CLIPS)
