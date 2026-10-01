# Quirk Battlegrounds — working tools and handoff

`QuirkBattlegrounds_City.rbxl` (repo root) is the game, and **it's the source
of truth**. This folder holds what was used to build it outside Studio:

| Folder | What's in it |
|---|---|
| `src/` | Every script in the place as of Round 78, one file per script, named by its full path (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript) |
| `anim/` | The R6 keyframe toolkit: a pose language, a box-figure preview renderer, and the builders that turn clips into KeyframeSequences |
| `place/` | Python tools that edit the binary `.rbxl` directly (swap script sources or the animation folder, leaving everything else byte-identical), plus Lune dump scripts |
| `tests/` | The headless test harnesses (Lune) for the server and the client, with the animation folder they load |

You need Python 3 with `numpy pillow lz4 zstandard` (and `ffmpeg` for preview
videos), and [Lune](https://github.com/lune-org/lune) 0.10+ for the `.luau` tools.

---

## Where things stand (Round 78)

The last change reworked **United States of Smash** to match All Might vs
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
```

The harness is a mock: sounds never end, `Debris` never removes anything,
there's no real physics or raycasts, and only player characters, dummies,
Twice's doubles and the raid Nomu are found by spatial queries. These checks
have failed on and off for many rounds and aren't caused by recent work:
- the two back-dash checks
- "FLOAT 75: touching down…"
- the snack machine's "…nobody else can take it"
