# Quirk Battlegrounds — working tools and handoff

`QuirkBattlegrounds_City.rbxl` (repo root) is the game, and **it's the source
of truth**. This folder holds what was used to build it outside Studio:

| Folder | What's in it |
|---|---|
| `src/` | Every script in the place as of Round 97, one file per script, named by its full path (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript) |
| `anim/` | The R6 keyframe toolkit: a pose language, a box-figure preview renderer, and the builders that turn clips into KeyframeSequences |
| `place/` | Python tools that edit the binary `.rbxl` directly (swap script sources or the animation folder, leaving everything else byte-identical), plus Lune dump scripts |
| `tests/` | The headless test harnesses (Lune) for the server and the client, with the animation folder they load |

You need Python 3 with `numpy pillow lz4 zstandard` (and `ffmpeg` for preview
videos), and [Lune](https://github.com/lune-org/lune) 0.10+ for the `.luau` tools.

---

## Where things stand (Round 97)

Round 97 is built on Round 96. It changed three scripts (`QuirkConfig`,
`HUD`, `QuirkServer`); nothing else in the place changed. Not playtested in
Studio yet.

**Anti-exploit** (`Config.AntiExploit`, the server's `Kit.AX`). The owner:
"Sure do the anti exploit". The server already decided hits, damage,
cooldowns, Bucks and every dev feature. What it trusted was where each body
is, because each player's own machine moves their own body. This round adds:
- **Movement watchdog.** Four times a second the server looks at every
  player's body and flags what nothing in the game can do:
  - **Speed:** over 75 studs/s flat, measured over a second.
  - **Teleport:** a jump of 45+ studs between two looks.
  - **Rise:** going up faster than 95 studs/s.
  - **Hover:** 3 s in the air with nothing under them and not falling.
  - **Spin:** over 100 rad/s, the usual fling exploit.
  - **Fling:** a body moving over 800 studs/s.
- **What excuses a body** (for 2.5 s after, too):
  - any request of theirs except raising a guard (every move, dash,
    parkour and flight asks the server);
  - the server moving the body itself (a respawn, a warp, a grab, a ranked
    mark). The root's `CFrame` changed signal only fires for server sets;
    a client moving its own body never fires it on the server.
  - a force the server put in the root (a hit's `Knockback`, Zero Gravity).
    A client's own forces never reach the server.
  - states that carry the body: ragdolled, grabbed, carried, stunned,
    frozen, finishers, clashes, possession, every flight, phasing, stopped
    time, ranked holds.
  - Low gravity (Moon Gravity, Zero Gravity, an admin event) turns the rise
    and hover checks off.
- **Lag.** A laggy machine sends nothing and then all of it at once, so
  every check measures over the time since the body last moved. A body
  frozen in mid-air stops counting as hovering after a second.
- **Who's watched.** Everyone except testers and the dev flight's people
  (who fly and teleport for real). In Studio everyone counts as a tester;
  set `CheckTesters = true` to try it on yourself.
- **Modes.**
  - **`Log` (as shipped):** it only takes notes. They go to the F2
    console's `flags` (the last flags) and `ax` (who has how many points),
    which only the owner sees; to a live server's output (F9 → Server);
    and to a toast for the owner if they're in the server (`Notify`).
  - **`Enforce`:** also pulls a body back to where it last stood (speed,
    teleport, rise, hover), and takes a flinger's body out of everyone's
    way for 8 s (it touches no one). At `KickAt` points it kicks; that's
    0 by default, meaning never.
  - **`Off`.**
  - Switch every server in `Config.AntiExploit.Mode`, or one server with
    `ax enforce` / `ax log` / `ax off` in the F2 console. `ax clear [who]`
    forgets someone's flags.
- **Request rate.** Over 40 requests a second (80 at once) is flagged as
  Spam; in Enforce the extra requests are dropped.
- **Clash.** Presses are capped at 11 a second, down from about 19. Twelve
  presses in a row spaced more evenly than 6 ms is flagged as a macro.
- **Farming limits.** These apply in every mode, but not to testers or the
  dev flight's people:
  - The 4th KO of the same player inside 10 minutes pays nothing: no
    Bucks, KO count, streak, ult or heal. The popup still says K.O.! with
    "NO REWARD - THE SAME PLAYER AGAIN", and the kill feed still shows it.
  - Dummies pay at most 20 Bucks every 10 minutes.
  - A 3rd ranked match against the same player inside an hour is unrated.
- **Known gaps.**
  - An exploit that also sends the game's own move requests stays
    excused for 2.5 s after each one.
  - Walking through walls isn't checked.
  - A hover held perfectly still isn't caught after its first second,
    because it looks exactly like a frozen connection.
  - Log mode is there to show what it would catch before turning
    Enforce on.

**Tests (round 97).**
- **New checks:** 41 server checks (the watchdog, every excuse, lag, Log
  and Enforce, fling, spam, clash, farming, the console) and a client
  check (the no-reward popup). Both fail on round 96's sources and pass
  now.
- **Full server suite:** 1,924 passed, 41 failed. That's round 94's 40
  plus the snack machine's "…nobody else can take it", which flips.
- **Destruction suite:** unchanged (36 passed).
- **Full client suite** (run on its own): the same problems as round 96 up
  to the round 17 stall, apart from timing checks that flip from run to
  run. This time FLOAT 75, HITSTOP, M1Brawler4 and RADIO 84 failed (RADIO
  84's own test notes a slow frame can miss a flicker), and BACK DASH 66
  passed. Run alongside the server suite, THE CHAIN also failed once; on
  its own it passes.

### Round 96

Round 96 is built on Round 95. It changed five scripts (`QuirkConfig`,
`VFX`, `QuirkClient`, `QuirkServer`, `Destruction`); nothing else in the
place changed.

**Dismantle** (`Config.Dismantle`, the server's `Kit.DM`, the cut itself in
`Destruction.Slice` / `Collapse` / `Crumble`). The owner: "Make it so when I
draw click my mouse across a building it slices like sukuna dismantle and
causes the building destruction".
- **Who.** The dev flight's people only (`Kit.DF.allowed`; `DevFlyer` on
  the client).
- **Using it.** U, or the test menu's DISMANTLE row, arms it. The mouse is
  freed (the shift lock goes off and comes back when it's put away), a chip
  shows at the top, and the left button stops punching. Press and drag
  draws a white line; let go and the cut is sent if the line is at least
  40 px. U again puts it away. Mouse only for now (no touch or controller).
- **The cut.** The flat sheet through the camera and the drawn line, out
  to 900 studs, and 2° past each end of the line. Everything in the map's
  Buildings, Trees, Streetlights, Benches, Dumpster and Bushes folders
  that the sheet crosses inside the drawn stretch is cut right through,
  nearest first.
  - A part square to the cut is split exactly at it. A part at an angle is
    first halved across its other axes until the cut is within 1.2 studs
    (`Step`), never under 3 studs (`MinSize`), at most 256 pieces a part.
  - Each piece is a fragment of the original part, so it grows back like
    any broken part.
  - At most 3,000 new parts a cut (`Budget`); past that, a part goes whole
    to the side its middle is on. No new cut while 7,000 pieces are still
    moving (`MaxMoving`).
- **What comes off.**
  - **Slanted or flat cut:** the top slides off. Down the slope on a
    slanted cut, along the drawn line on a flat one (under 15° or so).
    It holds for 0.35 s with the cut glowing, slides until it's clear of
    what's left, then falls, tipping forward, and smashes into whatever
    is under it.
  - **Upright cut:** the smaller side topples over, away from the cut.
  - The moving side is welded into one body and steered by the server
    (rigid `AlignPosition` / `AlignOrientation` on its biggest piece).
    Nothing collides with it or finds it while it moves. Whole parts move
    as copies (lights and decals come along) while the originals wait in
    storage, held from regrowing until it lands.
  - **The landing:** 50 chunks flung, a 14-stud crater, a dust cloud, and
    anyone within 32 studs hit (25) and thrown. Everything grows back 40 s
    later, as any broken part does.
- **People.** Anyone the sheet passes through (3.5 studs either side) takes
  30. Never the dev.
- **The street.** Where the cut meets Roads or Ground it leaves a gash: a
  capsule every 24 studs, at most 10 a cut, 60 parts each.
- **Checks on the server.** Alive, 0.5 s cooldown, the camera within 450
  studs of his body, two real directions at most 150° apart. Not while
  he's in another body.
- **On every screen.** A white-hot line with red edges where the cut shows
  on walls and round each building it went through, sparks, a metal shing
  (`DismantleCut`). Then the grinding slide (`DismantleSlide`), the crash
  (`DismantleImpact`) and a slash on any body it cut (`DismantleHit`).

**Tests (round 96).**
- **New checks:** 23 server checks for `Kit.DM`, 24 destruction checks for
  `Slice` / `Collapse` / `Crumble` on a small tower, and a client section
  (arming, the line, the request, the effects). All three fail on round
  95's sources and pass now.
- **Full server suite:** 1,884 passed, 40 failed: round 94's 40. The
  snack machine's "…nobody else can take it" passed this time.
- **Destruction suite:** 36 passed (the 12 old checks and the 24 new ones).
- **Full client suite:** the same problems as round 95 up to the round 17
  stall (the round 96 section runs before it), apart from the timing
  checks that flip from run to run (BACK DASH 66 failed this time; FLOAT
  75, M1Brawler3 and PAD SENSITIVITY 68 passed).
- **A dev check on the real city** (not part of the suites): the cut run
  on buildings from the place itself. A flat cut is exact. A 10° one is
  within 1.2 studs, a steep 35° diagonal within about 1.5, an upright one
  within 1. Volume is kept exactly. About 300–1,150 new parts a building,
  15–80 ms each in Lune.

### Round 95

Round 95 is built on Round 94. It changed four scripts (`QuirkConfig`,
`HUD`, `QuirkClient`, `QuirkServer`); nothing else in the place changed.

**Ranked duels on the Sky Coffin** (`Config.Ranked`, the server's `Kit.RK`).
The owner picked this from the list of ideas ("Let's do 3!").
- **Queue.** The phone has a new RANKED app (⚔️). FIND A MATCH puts you in
  the queue; press it again to leave. The server pairs the two closest in
  rating, within 200 points, widening by 100 every 10 s of waiting. One
  duel runs at a time, because there's one stage.
- **Duel.** Kurogiri's mist takes both players to the Sports Festival
  stage on the Sky Coffin. They're healed, cooldowns are reset and the ult
  meter is emptied. They're held on their marks through a 3 s countdown.
  First to 2 rounds wins (5 rounds at most). A round ends one of three ways:
  - **KO.** The blow that would kill leaves them at 1 HP and down. Nobody
    dies up there.
  - **Ring out.** Off the top of the stage and down to it.
  - **Time.** At 90 s, more health left wins the round. Equal health is a
    draw.
- **Rules during a duel.** The two can only hit each other, and only while
  a round is on. Anyone else who gets on the stage is thrown off. There are
  no finishers, no hero switching and no dev flight, and duelists can't
  possess or be possessed.
- **Rating.** Elo (`Config.RankedDelta`): K 32, or 48 for a player's first
  10 matches. Leaving mid-duel counts as a loss.
- **Saving.** Each player's record is saved to a DataStore with
  `UpdateAsync`; Studio keeps it in memory unless `StudioSaves`. The best
  ratings from every server go on an ordered store. They're published,
  together with whoever's in the server, as `ReplicatedStorage.RankedBoard`
  (JSON) for the app.
- **Tiers.** ROOKIE, SIDEKICK, PRO HERO, TOP 100, TOP 10, SYMBOL OF PEACE.
  A player's tier and rating show over their head once they've played a
  match.
- **On screen.** A VS card, a scoreboard along the top, the calls (ROUND n,
  3-2-1, FIGHT!, K.O.!, RING OUT!, TIME!) and a result card (VICTORY /
  DEFEAT / DRAW, the rating change, PROMOTED). Everyone else gets a line
  when a duel starts and ends.

**Possessing players** (`Config.Possess.Players`). The owner: "let me take
control of players too like how I can do that to dummies".
- **Who.** Devs only, the same people as the dummy possess. K or the test
  menu's Possess panel now lists other players as well.
- **Controls.** A player body uses a dummy's keys (M1 chain, F guard, Q
  dash or ragdoll cancel) plus that player's own hero moves on 1 2 3 R 4,
  but never their ult. The moves run on the server as theirs, with their
  cooldowns (`PS.heroMove` → `Kit.onUseAbility`).
- **Credit.** Nothing the body does credits anyone: no KO, Bucks or ult
  charge.
- **The possessed player's screen.** A banner reads "CONTROLLED BY <dev>".
  Their controls and the game's keys do nothing. Reset still works: the dev
  is sent home and the player resets.
- **What the server does.** The remote handler drops everything their own
  machine sends (`Kit.PS.fromVictim`). Their body's network ownership goes
  to the dev and comes back to them afterwards. A possessed body's ragdoll
  is run by the server, as a dummy's is.
- **Limits.**
  - Possession can't target the dev's own body, another dev's parked body,
    someone who is possessing a body themselves, or anyone in a ranked
    duel.
  - A move that carries the caster across the map on their own screen
    (a dash attack's travel, say) goes off where the body stands. That
    travel normally runs on the caster's own machine.

**Tests (round 95).**
- **New checks:** 26 server checks for possession, 33 for ranked duels,
  and a client section for both. They fail on round 94's sources and
  pass now.
- **Full server suite:** 1,860 passed, 41 failed. That's round 94's 40
  plus the snack machine's "…nobody else can take it", which flips.
- **Full client suite:** the same problems as round 94 up to where both
  stall.
- **Running the client suite:** run it with the place's own animations
  (`ANIM_RBXM=<the place's Animations folder as .rbxm>`). Without them,
  the USS clip checks fail and the M1 clip checks don't run.
- **Timing checks:** HITSTOP, BACK DASH 66, M1Brawler3 and PAD
  SENSITIVITY 68 flip from run to run, more so when the machine is
  busy.
- **Updated test:** the phone dock test now expects six apps.

### Round 94

Rounds 85–93 were made in another session, on top of Round 84 (the dev
flight, LIGHTSPEED, the light wipe, Saitama, Bakugo's Max Capacity and
more). Round 94 is built on the owner's place with those rounds in it. It
changed four scripts (`QuirkConfig`, `VFX`, `Destruction`, `QuirkServer`);
nothing else in the place changed.

**The city comes back whole after a wipe.** The owner: "when doing the
hyperspace dev flying and then crashing into the ground, the map is
purposely wiped out and then brought back. but the map does not look right
cosmetically speaking, it looks like it is missing parts of it." There were
two causes.
- **Streaming (every screen).** The place has `StreamingEnabled` with
  opportunistic stream-out past 1,024 studs, and the city is about 1,250
  across. A part that streams out is only parented to nil, and it streams
  back in later as the same part, with whatever local look it had. The
  wipe engine (`VFX.ST.World`) hides each part with
  `LocalTransparencyModifier = 1`. When the city came back, `WS.unhide`
  skipped any part that was streamed out at that moment, so those parts
  came back invisible for good. Now it gives every part its look back,
  streamed out or not (`WS.unhide`).
- **The server's carving.** The light wipe carves a real crater and six
  240-stud furrows out from it; the Serious Punch carves a 640-stud
  trench. These stayed out for Destruction's `RegenTime` (40 s after the
  last hit), but every screen rebuilds the city about 12–15 s after the
  blast. The city came back with trenches through it, and the cut pieces
  had no lights. Now the server rebuilds with the rewind
  (`Kit.wipeRebuild` → `Destruction.RestoreArea`), in two steps:
  - **Mid:** halfway through the empty plain, everything broken in the
    wiped folders that stands over the foundations. On every screen it
    arrives hidden and comes back with the rest of the city.
  - **End:** as the rewind ends, the rest (the crater in the street, the
    low pieces).
  - Left alone: a piece in someone's marble, anything that would come back
    on a dummy, a double, the raid's Nomu or someone still ragdolled (the
    usual regrow takes those), and everything when **Destruction Respawns**
    is off (`MapRegen`).
- **Code:**
  - **Client:** `WS.unhide` in VFX's Serious Punch block (`VFX.ST.World`).
  - **Server:** `Kit.wipeRebuild` and `LW.style` in the light wipe's block
    of `QuirkServer` (`Kit.LW`). `LW.blast` and `ST.blast` call it. The
    tests reach it as `Destruction.LightWipe.rebuild`, with the last plan
    in `.lastPlan`.
  - **Destruction:** `Destruction.RestoreArea(center, radius, opts)`.
- The labels jump from 84 to 94 because the other session used 85–93 in
  its code comments.

### Round 84

Rounds 79–83 were made in another session, on the owner's `final.rbxl`.
Round 84 is built on that place. It changed four scripts (`QuirkClient`,
`QuirkConfig`, `VFX`, `QuirkServer`); nothing else in the place changed.

**The slam jump goes on the press.** In a grounded M1 chain, Space after
hit 3 hops you as soon as hit 3's swing ends on your own screen. If the
swing has already ended, it hops `Slam.PressGrace` (0.04 s) after the
press. It no longer waits for you to let go, or for the server's copy of
the lock, which arrives a ping late.
- **Upslam:** hold Space through hit 3's swing with the 4th clicked into
  it, or hold it from before hit 3. A 4th clicked early with Space held is
  kept, however early.
- **One press, one jump:** still holding Space when you land doesn't jump
  you again.
- A tap during hits 1–2 with no more clicks jumps out of the chain
  `Slam.ArmWait` (now 0.12 s) after the next hit was due.
- **Code:** `QuirkM1Jump` (RenderStep) and `useM1` in `QuirkClient`. Tuning
  is in `Config.M1.Slam`.

**Shigaraki (Decay)**, from the anime frame by frame:
- **Radio Waves (ult 1), ep 119 with Air Cannon:**
  - Air Cannon's gold orb swells round his palm: a ForceField bubble with
    amber light inside. It flickers violet twice, with black lightning
    cracked across it.
  - Then a white pop. The blast rolls out across the fan:
    - a yellow-green wall with a bright yellow crest and a violet edge;
    - **the yellow streaks** tearing out ahead of it;
    - yellow-green haze left on the street, with black lightning hanging in it;
    - violet lightning striking down the buildings it meets;
    - the air tinted yellow-green for a moment.
  - Whoever it jams loses their quirk for `Jam` seconds: no moves (M1s,
    dashes and the guard still work). Everyone sees static crackling on
    them (`RadioJam`).
- **Rivet Stab (R):**
  - Rivets grow out of his fingertips, shoot out along five lines, and pull
    back into his fingers.
  - The nearest one hit is pinned on three rivets (`Pin`), then reeled in
    to `ReelTo` studs in front of him, still dazed. A boss is only pierced.
- **Rivet Storm (ult 2):**
  - Tendrils burst from his hands and back, with a crown of them rising out
    of his spine.
  - Everyone caught is lifted `Lift` studs on the rivets, held `Hold`
    seconds, then slammed into the street (`SlamDamage`, a knockdown).
- **Code:**
  - **Server:** `Handlers.RivetStab`, `Kit.rivetReel`, `Handlers.RadioWaves`
    and `Handlers.RivetStorm` in `QuirkServer`. The jam check is in
    `Kit.onUseAbility`.
  - **Client effects:** in VFX's Decay block (`DY`): `Effects.RivetStab`,
    `RivetPin`, `RadioWaves`, `RadioJam`, `RivetStorm`, `RivetLift` and
    `RivetSlam`, plus `DY.liveTendril`, `DY.jag` and `DY.strike`.
  - **Colours:** `PAL.GOLD`, `HAZE` and `YELLOW`.

### Round 78: United States of Smash

Round 78 reworked **United States of Smash** to match All Might vs
All For One at Kamino (anime ep. 49 / manga ch. 94):

1. **The press:** a lunge (26 studs) with the decoy left. It has to catch
   someone. A miss is a whiff that costs 5 s of cooldown, not the ult.
2. **The catch:** the target is held dazed for 2 s of "UNITED STATES OF…"
   while the right arm swells gold, and All Might is armoured.
3. **The strike:** the overhand right lands on the face. An impact frame plays
   (white, stark black-and-white, a beat of red) and everything freezes for
   0.38 s. The ult music ducks under it.
4. **The slam:** it drives them into the street. Then the crater, the dust
   wall, the wind pressure, and the twister (rebuilt with beam wind streaks,
   a storm cloud with lightning, and a darkened sky). Then the raised fist and
   "You're next."

A boss (the raid's Nomu) can't be grabbed, so it's punched where it stands.
Prime All Might's `PrimeUSS` works the same way.

**Where it lives:**
- **Server:** `Handlers.UnitedStatesSmash` in `ServerScriptService.QuirkServer`, plus `Kit.shortCooldown`.
- **Client effects:** at the end of `ReplicatedStorage.Shared.VFX`: `Effects.UnitedStatesSmash` (lunge), `Effects.USSWhiff`, `Effects.USSCatch` (build plus cutscene), `USS.strike` (impact frame and freeze), `Effects.USSSlam`. The twister is the `twister()` function.
- **Tuning:** `ReplicatedStorage.Shared.QuirkConfig`, on the `UnitedStatesSmash` / `PrimeUSS` entries: `Lunge`, `LungeTime`, `WhiffCooldown`, `BuildTime`, `FreezeTime`, `SlamTime`, `MusicDuck`.
- **Sounds:** `Config.Sounds.MightUSSImpact`, `USSJab`, `USSStrike`, `USSWhiff`, `Twister`. A layer's `Fade = seconds` fades its tail out.
- **Music ducking:** the hook is `VFX.Hooks.DuckMusic(depth, attack, hold, release)` in `QuirkClient`.

The branch is `claude/gracious-hawking-5st98u`. Each round has updated
`QuirkBattlegrounds_City.rbxl` in place.

---

## How the animations work

- **R6 bodies** play keyframed clips: the KeyframeSequences in
  `ReplicatedStorage.Animations`, the same thing Studio's Animation Editor saves.
  - A move's motion `X` plays clip `MoveX`.
  - A held pose `X` plays `PoseX`.
  - The game samples them itself (`VFX.Clip` in VFX), so nothing has to be
    uploaded. Edit a clip, save it back under the same name, and it plays.
  - To use a **published** animation instead, put its id in
    `Config.Animations.Clips.<ClipName>`.
- **Keyframe names mean something:**
  - `Hit` is the contact frame. Hitstop freezes the clip there, and the swing's
    smear and sound time to it.
  - `Hold` is where the clip waits while the move holds the pose
    (`VFX.Clip(char, name, { holdFor = seconds })`).
  - `Slam` is just a marker.
- **R15 bodies** fall back to the procedural `MOTIONS` / `POSES` tables in VFX.
- **United States of Smash clips:**
  - `MoveUSSLunge` and `MoveUSSWhiff`
  - `MoveUSSBuild` (held on `Hold` for the build)
  - `MoveUSSSmash` (`Hit` at 0.06 s, `Slam` at 0.18 s)
  - `MoveUSSVictory`

### Authoring clips with the toolkit (`anim/`)

A pose is a small dict (see the top of `rig.py` and `moves_lib.py`):

```python
P(body=dict(y=-0.5, twist=40, lean=30, fwd=0.6, tilt=-8),  # sink, turn the chest (+ = left), lean forward
  ra=(80, 14, 0), la=(-34, 0, 34),                          # arms: (raise, across, out[, spin]) in degrees
  rl=dict(f=-1.7, s=0.4), ll=dict(f=1.3, s=0.14),           # feet planted: forward / sideways studs
  head=(-6, -16, 0))                                        # pitch (+ = down), yaw, roll
```

A clip is a list of `(time, pose, easing, keyname)` built with `seq()`. For
the patterns, see `moves_uss.py`, `moves_am.py` and `m1.py`.

```bash
cd anim
python3 preview.py moves_uss MoveUSSSmash --sheet-only   # contact sheet of every key (3 views)
python3 export.py clips.json moves_uss                   # clips -> JSON
lune run append_ks.luau ../../QuirkBattlegrounds_City.rbxl clips.json Animations.rbxm   # the place's folder + these (same name = replaced)
cd ../place
RBXL_PACK=zstd python3 rbxl_replace.py ../../QuirkBattlegrounds_City.rbxl ../anim/Animations.rbxm out.rbxl ReplicatedStorage
python3 rbxl_check.py out.rbxl
```

### With the Roblox Studio MCP (the plan for better animations)

With Studio open and its MCP server connected (Assistant → … → Manage MCP
Servers → Enable Studio as MCP server), edit and check clips **in Studio**:

- **Look at them:**
  - Clone a clip from `ReplicatedStorage.Animations` and register it with
    `KeyframeSequenceProvider:RegisterKeyframeSequence`.
  - Play it on an R6 rig, then pause it on its keys (`track:AdjustSpeed(0)`, `track.TimePosition = t`).
  - Use `screen_capture` from a few camera angles. Do this on All Might's
    muscle form at its real 1.5× scale.
- **Measure contacts:**
  - The fist should touch the face at `Hit`. During the build the server holds
    the victim 4.6 studs in front, slightly raised.
  - The fist should reach the street at `Slam`.
  - The feet shouldn't slide while the lunge carries the root.
- **Playtest the real move:**
  - Start a playtest, give yourself the ult (test menu or console), and fire
    United States of Smash at a dummy.
  - Capture the impact frame, the freeze, the slam and the twister. The
    twister has never been seen in-engine yet: beam widths, transparency and
    colours may need tuning.
- **To-do for the animations:**
  - Match key poses to frames from the Kamino clip (if one is provided).
  - Arcs and overlap: the head and free arm should trail.
  - A smear frame on the strike.
  - A real victim reaction: a head-snap on the strike, then limp into the
    street. They currently just get the `Stagger` pose.
  - Line the cutscene shot cuts (`USS.shots` in VFX) up with the poses.

Moon Animator's own UI can't be driven by an agent. It can open the same
KeyframeSequences for hand polish, but they must be saved back into
`ReplicatedStorage.Animations` under the same name.

---

## Changing scripts outside Studio

```bash
cd place
lune run dump_sources.luau ../../QuirkBattlegrounds_City.rbxl ../src       # place -> src/
# ... edit src/ ...
RBXL_PACK=zstd python3 rbxl_write.py ../../QuirkBattlegrounds_City.rbxl out.rbxl ../src   # src/ -> place (only Source chunks change)
python3 rbxl_check.py out.rbxl
```

The place is saved by Studio with zstd, so keep `RBXL_PACK=zstd`. Diff two
places with `dump_names.luau` (instances) and `dump_sources.luau` (scripts).

## Tests

```bash
cd tests
lune run compile_all.luau ../src     # every script compiles at every optimisation/debug level (Studio uses full debug info)
lune run server_tests.luau ../src    # ~1,800 checks, ~25 min
lune run client_tests.luau ../src    # the client, VFX and HUD, ~60 min; prints "N problem(s)"
lune run destruction_tests.luau ../src   # the real Destruction module on a small map (carving, restoring), seconds
```

The harness is a mock: sounds never end, `Debris` never removes anything,
there's no real physics or raycasts, and only player characters, dummies,
Twice's doubles and the raid Nomu are found by spatial queries. Found in
round 84:
- On the client, a tween applies its goal at once, so only end states can
  be checked.
- `RunService.Heartbeat` is never fired, so the input buffer never runs.
  The round 84 slam test drives Heartbeat itself.
- Nothing applies gravity: a root keeps whatever velocity it was last given.

Found in round 94:
- Lune's parts have no default `LocalTransparencyModifier`, and they don't
  work out `Position` from `CFrame`. Tests set both on the parts they make.
- Parenting doesn't fire `DescendantAdded`. The round 94 wipe test fires it
  itself to stand in for a part streaming back in.
- The server tests can't reach `Kit`. They reach the light wipe through
  the stubbed Destruction module (`Destruction.LightWipe`).

Found in round 95:
- Possession and ranked duels are reached the same way:
  `Destruction.Possess` (`Kit.PS`) and `Destruction.Ranked` (`Kit.RK`).
- The harness doesn't build the Sky Coffin. The ranked tests stub
  `RK.stage`.
- The harness's DataStore mock has no `UpdateAsync`, and every store name
  shares one table. The ranked tests give `RK` a store of their own.
- On the client, a method can be implemented only once
  (`r.implementMethod`), so `UnbindAction` stays a no-op. The tests check
  what the code tracks instead.

Found in round 97:
- In Studio everyone is a tester, so the watchdog and the farming limits
  skip everyone in the harness. The round 97 tests swap in their own
  `AX.exempt`, stand the background look down and call `AX.check`
  themselves.
- To move a body the way its own machine would (no `CFrame` changed
  signal), the tests write the mock's `_props.CFrame` directly. A normal
  `root.CFrame =` is a server move.
- The anti-exploit is reached through `Destruction.AntiExploit` (`Kit.AX`).

Found in round 96:
- Dismantle is reached the same way: `Destruction.Dismantle` (`Kit.DM`).
  The server tests stub `Slice`, `Collapse`, `MovingCount` and `Capsule`
  and check what `Kit.DM` asks of them.
- Lune throws on reading a property of a destroyed instance (Roblox gives
  `nil`). The new Destruction code asks for `Parent` through a `pcall`.
- The Destruction module's own loops keep Lune running, so an error at the
  top level of `destruction_tests.luau` hangs the run instead of ending
  it. The round 96 section runs in a `pcall`.
- There's no `workspace:Raycast` in the destruction tests, so a falling top
  lands on its building's foot.
- On the client, Lune's `UserInputService` has no `GetFocusedTextBox`, and
  reading `MouseBehavior` throws. UDim offsets are whole pixels.

These checks have failed on and off for many rounds and aren't caused by
recent work:
- the two back-dash checks
- "FLOAT 75: touching down…"
- the snack machine's "…nobody else can take it"

**Failing on the owner's rounds 85–93 place** (found in round 94; every
one fails the same way on the place as uploaded, before round 94). The
other session changed these kits, so the old tests are out of date:
- Bakugo: his 4th is Max Capacity now, not Scorched Earth, and his numbers
  changed ("his 4th move (V) is Scorched Earth", "BAKUGO, nerfed hard",
  "…out of the ult, 4 is still Scorched Earth").
- Crazy Diamond's BREAK has no `Hold` any more ("…and RESTORE: it all
  comes flying home").
- Rivet Storm's `Hold` is `LiftHold` now ("Rivet Storm lifts them 9
  studs…", "caught on a rivet…").
- The emote wheel and emote rolls ("7 new emotes on the wheel…" and the
  roll and Robux checks after it), THE JIGGY's BPM, and "R6 bodies:
  Roblox's clips…".
- "the M1 finisher … puts them down for 0.02s".
- The harness now runs each server test section in a `pcall`, so a stale
  section counts as one failure ("section errored: …") and the run goes
  on.
- On the client, from round 17's section ("lock-on, scope, erased") a
  raycast stub error repeats every frame and the run stalls there. It does
  the same on the uploaded place, so it's a harness problem, not the game.
  The sections before it run; the round 94 one is among them.

**Failing on the owner's rounds 79–83 place.** These fail on the upload as
it came, before round 84. The changes there behind them look deliberate, so
the old tests are out of date rather than the game being broken:
- Client:
  - "…hold BLOCK to guard, let go to drop it": round 82's phone buttons
    wait to tell a tap from a hold.
  - "THE CLIPS", "HITSTOP", "M1Brawler4" and "THE CROUCH": the M1 and
    crouch clips were re-keyed.
  - "USS 78: … the smash lands 0.06s in": `MoveUSSSmash` was re-keyed in
    round 79.
- Server:
  - "no credit without a hit" and "B's KO count unchanged by A's fall"
  - "V: BLINK"
  - "a dummy KO'd by the finisher ragdolls" and "…keeps the hit's motion"
  - "the M1 finisher … puts them down"
  - Bakugo's Explosive Speed blitz checks ("B, 40 studs down the lane…" and
    the six after it)
