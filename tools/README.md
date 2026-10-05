# Quirk Battlegrounds — working tools and handoff

`QuirkBattlegrounds_City.rbxl` (repo root) is the game, and **it's the source
of truth**. This folder holds what was used to build it outside Studio:

| Folder | What's in it |
|---|---|
| `src/` | Every script in the place as of Round 95, one file per script, named by its full path (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript) |
| `anim/` | The R6 keyframe toolkit: a pose language, a box-figure preview renderer, and the builders that turn clips into KeyframeSequences |
| `place/` | Python tools that edit the binary `.rbxl` directly (swap script sources or the animation folder, leaving everything else byte-identical), plus Lune dump scripts |
| `tests/` | The headless test harnesses (Lune) for the server and the client, with the animation folder they load |

You need Python 3 with `numpy pillow lz4 zstandard` (and `ffmpeg` for preview
videos), and [Lune](https://github.com/lune-org/lune) 0.10+ for the `.luau` tools.

---

## Where things stand (Round 95)

Round 95 is built on Round 94. It changed four scripts (`QuirkConfig`,
`HUD`, `QuirkClient`, `QuirkServer`); nothing else in the place changed.
Not playtested in Studio yet.

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
