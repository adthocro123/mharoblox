# Quirk Battlegrounds — working tools and handoff

`QuirkBattlegrounds_City.rbxl` (repo root) is the game, and **it's the source
of truth**. This folder holds what was used to build it outside Studio:

| Folder | What's in it |
|---|---|
| `src/` | Every script in the place as of Round 107, one file per script, named by its full path (`.server.lua` = Script, `.client.lua` = LocalScript, `.lua` = ModuleScript) |
| `anim/` | The R6 keyframe toolkit: a pose language, a box-figure preview renderer, and the builders that turn clips into KeyframeSequences |
| `place/` | Python tools that edit the binary `.rbxl` directly (swap script sources or the animation folder, leaving everything else byte-identical), plus Lune dump scripts. `uniqueids.py` (Round 106) finds UniqueIds two instances share: Studio won't open such a place |
| `tests/` | The headless test harnesses (Lune) for the server and the client, with the animation folder they load |
| `jjba/` | Round 104: the tools that grafted the JJBA place into the game (a binary-format codec and grafter, the Moon Animator converter, the graft list, the checks). Round 105: `cd_check.luau` (Crazy Diamond on the Star Platinum model, checked and posed) and `render_parts.py` (its box-figure preview). Round 106: `assets106.py` (the graft of the Stand arrows, the Rokakaka, the props in the hand and their two clips) and `spots_check.luau` (where the items go, worked out offline) |
| `touhou/` | Round 107: Mokou and Remilia from the owner's Touhou place. `graft107.json` (what comes over), `kit107.luau` (the new folders, the Knit stand-in, `Bridge`), `assets107.py` (the graft), `port107.py` (their scripts into `src/`, paths patched, footer stripped), `paths107.luau` (every path their scripts name is in the place), `ids107.py` and `reupload107.md` (the animations and sounds to upload again), `reupload_anims.py` (moves the 185 animations to the new account with Roblox's Open Cloud API and writes the Studio snippet that swaps the ids; run on your own computer), `swap107.py` (puts its `map.json` into a place file), `owners107.py` and `owners107.md` (who owns each animation on Roblox - 129 the group Ivory Boat, 51 the user generalprinciple, 5 others - and how an owner lets Quirk Battlegrounds use them without uploading again), `saved107.luau` and `saved107.json` (the 27 animations whose keyframes the Touhou place still has, matched by name, written out for `reupload_anims.py --upload-only`), `standin108.py` + `standin108.luau` (Round 108: 80 new R6 animations for the slots whose originals can't be used, built as KeyframeSequences), `reupload107_map.json` (old id -> new id for those 27, uploaded to the new account; `swap107.py` puts them in a place: 29 Animations), `sounds107_map.json` (stand-ins for the 42 sounds that won't load in the new account's game - 33 private to generalprinciple, 7 to Lord_Gabe06, 2 deleted - each a sound this pack already uses that does load; `swap107.py` swaps Sounds too: 135 of them) |

You need Python 3 with `numpy pillow lz4 zstandard` (and `ffmpeg` for preview
videos), and [Lune](https://github.com/lune-org/lune) 0.10+ for the `.luau` tools.

---

## Round 108: new animations for the Touhou slots that can't come back

On the new account Mokou's and Remilia's animations don't play: Roblox
plays an animation only for its owner, and 158 of the 185 belong to the
group Ivory Boat (111), the account generalprinciple (42) and others (5).
27 came back from keyframes the Touhou place still had (Round 107). For
the rest, `touhou/standin108.py` makes NEW R6 animations on `anim/`'s pose
language, one for each slot the game actually plays - 80 of them:

- the moves' attacker and victim clips (Mokou kicks, stomps, flying kicks,
  fire palms; Remilia's spear stabs, sweeps and throws, the bite, the dive,
  the rising spin, her 14 s awakening), each beatdown as long as its
  script's `AttackLength`, the victim's flinches landing on the attacker's
  hits and ending knocked down, flung or lifted as the move does;
- the reactions their hits play on whoever they hit (`Reactions`,
  `ReactionsCrazy` 1-4) and the four afterimage poses (`BLSRAFTERIMAGES`).

Left out, on purpose: their M1s, dashes, blocks, idle and run (the game's
own M1 system runs those; the Touhou scripts only ever stop them), the
knock-back reactions their scripts have commented out, the slots only old
versions of moves used (50 in all), and the 8 that aren't R6 bodies (three
wing rigs, the spinning spear, the cutscene cameras).

`standin108.luau` builds them as KeyframeSequences - `reupload107/<old
id>.rbxm` for `reupload_anims.py --upload-only`, and one
`touhou_new_anims.rbxm` to look at in Studio. All 80 read back with every
key in place. `reupload_anims.py` now writes the swap as one line and puts
it on the clipboard (Mac `pbcopy`, Windows `clip`) when it's done; tested
against a stand-in for Roblox's API (80 of 80 uploaded, 107 in the map),
not yet against Roblox, and not playtested in Studio.

## Where things stand (Round 107)

Round 107 builds on Round 106. The owner sent their own Touhou place
(free to edit in Studio; they made its assets) and asked for two of its
fighters: "lets do 1 and 2". **Mokou (IMMORTAL BLAZE)** and **Remilia
(SCARLET EMPRESS)** are now in the hero list, both DEV ONLY. They run that
place's own move scripts and effect scripts, unchanged apart from a few
paths, on top of the game's systems. Three of the game's scripts changed
(`QuirkConfig`, `VFX`, `QuirkServer`) and two small ones were added (the
Knit stand-in and `Bridge`). Not playtested in Studio yet.

**The animations need uploading again.** Quirk Battlegrounds is on a new
account, and Roblox only plays an animation in a game owned by whoever owns
the animation. `touhou/reupload_anims.py` moves all 185 with Roblox's Open
Cloud API (downloaded with an old-account key, uploaded with a new-account
key; tested against a stand-in for the API, not yet against Roblox's).
Before using a key it asks Roblox about it (`POST /api-keys/v1/introspect`)
and says what's wrong, if anything: pasted in part, switched off, expired,
missing a permission, or a user id that isn't the key's own. It reads the
key a keystroke at a time, because Python's `getpass` keeps only one
terminal line of it (1024 characters on a Mac).
`touhou/reupload107.md` lists all 185 animations and 275 sounds with where
each one sits, with the steps, and two command-bar snippets for doing it by
hand instead: one fetches the animations on the old account, the other swaps
in the new ids. Until then the moves still work (hits, effects, sounds you own or
Roblox's), but the bodies don't animate. The two awakening songs fall back to
Roblox-library tracks if theirs won't load.

**How it's done: their scripts, our systems.**
- That place is built on Knit (services and controllers). Its moves are
  ModuleScripts, one per move (`Skill1`...`Skill4`, `Special`, and an
  `Awakening` folder with the awakened set and `Awaken`). Each is a class
  with `Release` (and `Hold` for held moves) that calls the place's
  services: AnimationService, CombatService, HitboxService, DamageService,
  StateService, MovementService, BodymoverService, GrabService,
  CooldownService, CounterService, RagdollService.
- `QuirkServer`'s `Kit.TH` is a stand-in for each of those services, made
  from the game's own systems:
  - **Damage** goes through the game's `damage()` (guard, i-frames,
    knockdown rules, ult meter, KOs), times `DamageScale` (3: its fighters
    have 100 health, ours 300).
  - **Hitboxes** are the game's box queries, with that place's hit-once and
    tick rules. As there, a hit from behind (or from a move that ignores
    guard) gets through a guard.
  - **Stun, slow, can't-act, auto-rotate, i-frames**: that place keeps
    these as values in a `Values` folder on the body. `Kit.TH` watches them
    and maps each onto the game's own (stun, `SlowedTo`,
    `CombatActionUntil`, `BodyLocked`, i-frames), every 0.1 s.
  - **Animations** play on the body's Animator. **Effects** go to every
    screen in range as one `TH` effect (module, function, arguments), and
    each client calls that place's effect module with them.
  - **Cooldowns** are that place's own (each move sets its own). The HUD
    slot shows each one.
  - **Grabs** use that place's own constraint grab, with its
    `REPLICATEPOS1` pinning on the client.
  - A hit on someone mid-move sets `Cancel`, which that place's moves
    listen for.
- `ReplicatedStorage.Packages.Knit` is a small Knit stand-in for the effect
  scripts. It provides the animation controller they call, and `Hud`, which
  hides the game's screens through their cutscenes.
- If `ServerStorage.Touhou` is missing, or the layer fails while it
  loads, `Kit.TH` is never set and the game's hooks skip it. Mokou and
  Remilia can't move then; nothing else changes.
- `port107.py` copied their scripts (88) and patched only what pointed
  outside the moves: the collision group's name, `workspace.YukarinStation`,
  `PlayerGui.AwakeningBar` (now the Knit stand-in's `Hud`), the mouse and
  position remotes (now `Bridge`), and where `SimJump` lives. It also
  strips the "Powered by RoxzyFX" footer (and its Discord invite) from
  each one.

**The keys.** 1, 2, 3 are its Skill1 to Skill3; R is its Special; 4 is its
Skill4; G awakens (its `Awaken`, with its cutscene). In the awakening, 1 to
4 are its awakened set, and R stays the same. M1s, dashes and guard are the
game's own. Their M1s play that place's swing and hit sounds and sparks
(`M1Effects`).

**Mokou** (`Config.Quirks.Mokou`): SOARING SKY KICK, FIRE TALON ASSAULT,
FUJIYAMA VOLCANO BEATDOWN, PHOENIX FEATHER (R), BAMBOO BOMB (4). Awakened:
BAMBOO FOREST IN FLAMES, with BLAZE SIGN: BREAKNECK FIRE TALON ASSAULT,
FLAMING BLITZ TABLETOP DROPKICK, SOUTH WIND: CLEAR SKY and FLAMING SUGARY
DESSERT. Her wings come out when she awakens.
- **Immortal** (that place's rule, `Immortal`): knocked out with a full ult
  meter and not awakened, she lies dead for 5 s instead. Nothing can hurt
  her and she can't act, except to awaken. Awakening in that time raises
  her (the cutscene heals her). If she doesn't awaken, she's out. With the
  meter not full, a KO is a KO.

**Remilia** (`Config.Quirks.Remilia`): VAMPIRIC KISS, HEARTBREAK (hold to
aim the Gungnir, let go to throw), SCARLET STINGER, MILLENIUM VAMPIRE (R:
her hits do 1.9x and heal her half of each), MIDNIGHT KING (4). Awakened:
BLOODTHIRSTY NIGHTMARE LULLABY, with NIGHTLESS CASTLE, SCARLET PIERCE,
SCARLET IRON SEPULCHRE and MISERABLE MULTITUDE.
- Her spear is in her right hand and her wings are on her back, as that
  place dresses her. The awakened spear swaps in on its cue.

**The ult.** Each awakening is that place's: its cutscene, its song, its
extras (Mokou's smoke and wings; Remilia's smoke, its MilleniumFakepire
model and the spear swap). The meter's 60 s run starts after the cutscene
(`AwakenLength`). The game's own ult shout and blast are skipped for them.

**What came over** (`touhou/graft107.json`, `touhou/assets107.py`; 35,074
instances; the round 106 place's own are unchanged):
- `ReplicatedStorage.Assets`: their VFX for both, the shared combat
  effects, their animations (characters, M1s, reactions) and the camera
  rigs and models the moves use.
- `ReplicatedStorage.Modules`: shaker, RockScript, baseassets,
  TweenModule and the Gungnir throwables. `ReplicatedStorage.Voicelines`:
  Remilia's.
- `ReplicatedStorage.Touhou.Combats`: their effect modules (the client).
- `ServerStorage.Touhou.Attacks`: their move modules (the server), plus
  `SimJump`. `ServerStorage.ModelStorage`: the wings and spears.
- `Lighting`: their impact frames and colour corrections.
- Not brought over: their framework itself (Knit and its services and
  controllers), their HUD, their M1 / dash / block, the other fighters and
  their old or unused move scripts.
- Gaps their own place has too. `paths107.luau` checks every
  `game.X.Y` path their scripts spell out against the built place. 292 are
  there. 7 aren't in their place either, and nothing reaches them or the
  failure is caught (listed in `KNOWN`). For example, Mokou's SOARING SKY KICK
  plays a `kick11` hit sound that was never in their place.

**Settings** (`Config.Touhou`): `DamageScale`, `VampireDamage` /
`VampireHeal`, `Lifesteal` (their 0.2 heal-per-hit; 0 here), `Immortal`,
`M1Effects`, the `Settings` their effect scripts read (cutscenes on,
reduced visuals off...), the hit highlight colours, `TorsoRange` and
`MaxRange`. `Enabled = false` turns the layer off.

**Tests (round 107).**
- Server: 39 checks.
  - Both are DEV ONLY, all 18 moves are their scripts, and HEARTBREAK is
    held.
  - Dressing: Mokou's values and feathers; Remilia's spear and wings.
  - A move: Mokou's 1 runs its script, its hitbox finds the dummy, and it
    hits for its damage x3. Its stun and slow are the game's. Its cooldown
    shows in her slot, and its effect goes out with its arguments (a nil
    kept). Then 1 on cooldown does nothing, and a hit on her cancels her
    move.
  - Remilia's held throw waits out its minimum hold.
  - Mokou's immortality: she lies dead, can't be hurt, can only awaken,
    awakening raises her, and the meter runs after the cutscene. Not
    awakened in time: she's out. Meter not full: a KO.
  - Their M1s play that place's swing and hit effects. Other heroes are
    left alone.
- Client: `VFX.TH` calls the module's function with the server's
  arguments. A missing module or function does nothing. A broken effect is
  caught and warned about once. The face-your-aim turn works. The Knit
  stand-in hides and brings back only the screens it hid, and plays and
  stops tracks.
- Full suites:
  - Server: 2067 passed, 57 failed (round 106: 2029 passed, 56 failed).
    The 38 more passes are this round's 39 less one, the support drop's
    "nobody else can take it". That check failed because A still had a
    soda an earlier section gave him at random. The test now clears it,
    and that section passes on its own (41/41). The other failures are
    round 106's.
  - Client: stops at the same round 34 HUD error as before, with 91
    problems printed before it, as in round 106. One is this round's
    broken-effect check, which warns on purpose (it's taken back off the
    count). A few timing checks differ from run to run; the rest are round
    106's.

### Round 106

Round 106 builds on Round 105. The owner asked: "Also add the stand arrows
and fruit". The JJBA place's Stand Arrow and Rokakaka now lie about the
city. Three scripts changed (`QuirkConfig`, `VFX`, `QuirkServer`). The
JJBA place's items, the props held in the hand and two clips were grafted
in (`jjba/assets106.py`). Not playtested in Studio yet.

**Fixed after the first upload: the place wouldn't open.** Studio said "DM
contains duplicate Unique ids". The JJBA place's `AnimParts.MetalPart` had
come over a second time inside `JJBA.Held` (Round 104 had grafted it as
`JJBA.MetalPart`), and its 16 instances carried the same UniqueIds as the
first copy. Nothing uses the second one, so it's left out now. Two
safeguards:
- The grafter (`jjba/rbxgraft.py`) gives any copied UniqueId that's
  already in the place a fresh one.
- `place/uniqueids.py` checks a place for shared UniqueIds, and
  `assets106.py` runs it on what it writes. (Repeated HistoryIds are only
  counted: the round 105 place has the same ones and opens fine.)

**What came over from the JJBA place** (`jjba/assets106.py`; 1,644
instances; the round 105 place's own 85,459 are unchanged):
- `ReplicatedStorage.JJBA.Items`: its `Tools` folder. These are the Arrow
  and the Rokakaka as they lie on the ground. Its third item, the Parallel
  Crystal (which gives POM there), came with the folder but isn't placed:
  its clip (`GetPOM`) is an animation id with no keyframes in the place.
- `ReplicatedStorage.JJBA.Held`: its `AnimParts` folder. These are the
  arrow and the fruit as they sit in the hand, each on the motor the JJBA
  place used.
- `ReplicatedStorage.Animations.MoveStandArrow` (its `UseArrow`, 3 s) and
  `MoveRokakakaEat` (its `RokakakaEat`, 2 s). Both are KeyframeSequences,
  played by the game's own clip player like every other move.
- Its scripts did not come over. The game's own code does what they did.

**How they work** (`Config.JJBA.Items`; server `Kit.JI`; VFX `VFX.JI`,
effect `JJBAItem`):
- **Where they lie.** There are 3 arrows and 2 Rokakaka at a time. Each is
  9 studs off to one side of one of the map's spawn pads
  (`Map.Spawns`), on whatever is under it. Each item has a spot of its own.
  One that's taken comes back 60 s later at another free spot (the JJBA
  place's respawn time).
  - An offline check (`jjba/spots_check.luau`, every map part as its box)
    finds a spot by all 11 pads: 6 at street level, 5 on upper floors and
    rooftops.
- **How they look.** They float a little off the ground, turn and bob on
  each screen near them, and glow (a warm PointLight).
- **Using one.** Walk up and press E (D-pad right on a controller, a tap on
  a phone). There's no hold, unlike the JJBA place's 0.5 s: E is also the
  finisher's key, and the game presses a prompt for you with a tap.
- **The arrow.**
  - He plays the JJBA place's clip with the arrow in his right hand.
  - At 0.88 s its head goes in (the clip's own keys): the JJBA place's stab
    sound and its GetStand burst streaming off him for 4 s.
  - At 1.9 s a Stand awakens in him: its name rises over his head in its
    colour, with the JJBA place's Stand energy sound.
  - Which Stand: the JJBA place's own odds. Star Platinum 59, The World 41
    (`Pool`; add others there).
  - He's held still for the clip (3 s).
  - Refused if he's on a Stand already ("a Rokakaka takes it").
- **The Rokakaka.**
  - He eats it on the JJBA place's clip. The fruit turns in his hand as the
    clip has it.
  - Three bites: each takes a piece, with bits flying off and a crunch.
  - At 1.5 s his Stand drains out of him and he's the hero he was before
    the arrow (or the first public hero).
  - Refused if he isn't on a Stand ("Only a Stand user can eat a
    Rokakaka").
- **Not usable when:** ragdolled, stunned, mid-move, in HERO SHUFFLE, in a
  ranked duel, or in or out of a possessed body. He's told why.
  - Knocked out before it takes: he gets nothing, and the item is still
    used up.

**Who gets to keep an arrow's Stand** (`Unlocks`). All the Stands are DEV
ONLY in the hero list. With `Unlocks = true` (the default, as in the JJBA
place, where anyone can get one) an arrow's Stand belongs to whoever
stabbed himself with it:
- It stays through the DEV ONLY lock (losing dev access), the roster
  switch, and HERO SHUFFLE (he gets it back when the shuffle ends).
- He loses it by eating a Rokakaka, or by picking another hero himself.
  The Stands are still DEV ONLY in the list, so he can't pick it back.
- It lasts for his visit; it isn't saved.
- A Stand from an arrow can't play ranked, like any DEV ONLY hero.
- With `Unlocks = false`, an arrow only gives Stands he could pick anyway
  (so nothing, for players without dev access).

**Other settings:** `Count`, `Respawn`, `Spots` (or a list of positions),
`Float` / `Spin` / `Bob`, `Light`, the clip timings, the prompt texts and
every message. `Enabled = false`: none of them about.

**Tests (round 106).**
- Server: 37 checks.
  - They're put down: 3 arrows and 2 Rokakaka, each at its own spot,
    anchored, with the prompt (E, no hold) and the glow.
  - An arrow, used by a player without dev access: it's taken, every
    screen plays it, he's held for the clip, and Star Platinum is his at
    Give.
  - Then: he keeps it when dev access is lost; a second arrow is refused;
    the arrow comes back elsewhere.
  - The Rokakaka takes the Stand back (he's Explosion again), and does
    nothing without one.
  - The pool's other draw gives The World. Picking another hero gives it
    up, and he can't pick it back.
  - Knocked out mid-stab: no Stand. Ragdolled: refused.
    `Unlocks = false`: refused without dev access. `Enabled = false`: none
    put down.
  - All pass on round 106; on round 105 the section fails at once.
- Client:
  - The arrow in his right hand on the JJBA place's motor, and the clip
    moving his arm.
  - At the stab, the GetStand burst (its 9 emitters), which stops after 4 s.
  - The Stand's name in its colour, and the arrow gone at the end.
  - The fruit turns in his hand, shrinks with each bite and is gone after
    the last.
  - Nothing is drawn in the hand of someone far off.
  - The ones lying about turn, standing on end, and bob on the spot.
  - The fixture (`tests/JJBA.rbxm`) now carries `Items`, `Held`,
    `GetStand` and, as a second root, the two clips.
- Full suites:
  - Server: 2029 passed, 56 failed (round 105: 1992 passed, 56 failed).
    The 37 more passes are this round's section. The failures are round
    105's (two of them name a random emote, so their names differ each run).
  - Client: stops at the same round 34 HUD error as before, with the same
    91 problems before it. None are in round 106's section.

### Round 105

Round 105 builds on Round 104. The owner asked: "there should also be a
cinematic for cmoon as well, port that over pls. fix crazy diamond as well,
make him look like one of my models". Three scripts changed (`QuirkConfig`,
`VFX`, `QuirkServer`). No assets were added: the C-MOON scene came over with
`JJBA.Effects` in Round 104. Not playtested in Studio yet.

**C-MOON's cinematic** (`Config.JJBA.Cinematic.CMoon`; VFX: `VFX.JSC`;
server: `Kit.JJ.arrive`). This is the JJBA place's own `Cmoon_StartScene`,
from its `ModEffects` script, its scene `JJBA.Effects.Cmoon.StartScene`,
and its `Startcutscenecmoon` track.
- **When it plays.** The JJBA place plays it when you get C-MOON. Here it
  plays on Pucci's own screen 0.6 s after he's picked, and again if he's
  picked again. Everyone else sees C-MOON's arrival around him: a green
  ring and its summon sound.
- **What it shows**, on the JJBA place's own timeline:
  - **0 s:** a white flash, then the dark, with its streams of light
    rushing in.
  - **7 s:** the Earth (its sky in five shells, its clouds) bursts into
    view, turning, with the camera jolted and a flare of blur and bloom.
  - **13.2 s:** a hand rises into the frame and reaches for it. This is its
    Moon Animator save (`CmoonStartCutScene`), read key by key. The hand
    wears Pucci's sleeve, hand and gold band.
  - **13.6 s:** the lens is flung wide. Roblox's widest is 120; the JJBA
    place asks for 170.
  - **13.7 s:** the wind bursts out at the camera and it shakes again.
  - **16.1 s:** the screen goes white, and under it his camera comes back
    at 17.1 s.
- **Where it plays.** The scene is cloned 4,000 studs over the street, so
  nothing of the city is in its sky. The time of day is set to night and
  the atmosphere cleared while it plays, then put back.
- **Holding his inputs.** It uses the game's own cutscene lock
  (`VFX.Cinematic`): his inputs are held, and his camera comes back however
  it ends. The HUD, chat and player list are hidden while it plays, as the
  JJBA place does.
- **Ending it early.** Any key or button after 1.5 s skips it. A hit or a
  KO ends it at once. Nothing is held on the server, so it's no shelter in
  a fight.
- **The white-out at the end.** It lifts about 1.5 s after his camera is
  back. The JJBA place holds it about 3 s longer.
- **Sound.** If the JJBA track won't load on that client, the game's own
  sounds play at the beats instead (`CMoonCineRise / Earth / Wind / White`).
- `Enabled = false` turns it off.

**Crazy Diamond drawn from the JJBA place's model**
(`Config.JJBA.Stands.CrazyDiamond`; `JS.paint`).
- **Which model.** The JJBA place's STAR PLATINUM model (the closest build to
  Crazy Diamond in the JJBA place), painted in Crazy Diamond's colours.
  `Paint.Parts` sets each part's colour by name. `false` hides a part: the
  hair and the loincloth flaps.
  - **Pink:** the body.
  - **Light blue:** the shoulder pads, wrist and shin guards, the headband
    and the mask.
  - **White:** the bands and knuckles.
- **Hearts.** Seven, on the forehead, chest, belt, both shoulders and both
  knees. Each is welded to its part, so it moves with the limb.
- **Aura and trails.** Star Platinum's aura and arm trails, in pink.
- **Motion.** It uses Star Platinum's clips: the barrage loop for
  DORARARA, its pose for the rage. Every other move puts its pose on the
  rig, as before.
- **The old figure.** The part-built figure comes back if the model is
  missing or `Use = false`.
- **Checked offline** (`jjba/cd_check.luau`): its colours, the hair hidden,
  21 heart parts that move with their limb, and Star Platinum's own model
  untouched.

**Tests (round 105).**
- Server: 10 checks.
  - The cinematic is sent 0.6 s after Pucci is picked, and nothing is held
    on the server.
  - It isn't sent if he's picked away first, for another hero, when it's
    off, or if he's knocked out by then.
  - All pass on round 105. On round 104 the section fails: its config
    checks fail and it stops.
- Client:
  - Crazy Diamond: out for DORARARA on the painted model, with its own
    barrage clip, pink, no hair, hearts showing, a pink aura, and the
    part-built figure hidden.
  - The cinematic, run 8x fast:
    - It takes his camera from the scene's own, 4,000 studs up, at night,
      with the HUD hidden and a white flash first.
    - The Earth appears at 7 s and turns.
    - The hand reaches out in front, and the lens goes wide.
    - At the end his camera, the HUD and the time of day are back and the
      scene is gone.
  - A key skips it after 1.5 s (not before), and a hit ends it.
  - Someone else's cinematic never plays on your screen.
- Full suites:
  - Server: 1992 passed, 56 failed (round 104: 1981 passed, 57 failed).
    The failures are the same, except one that comes and goes ("deflating:
    the bangs go with the costume") passed this run. Two other failing
    checks name a random emote, so their names differ each run.
  - Client: stops at the same round 34 HUD error as before, with 91
    problems before it. That's round 104's 89, plus two timing checks
    (FLOAT 75's Air Force flick, RADIO 84's flicker) that also fail on the
    uploaded final. None are in round 105's section.

### Round 104

Round 104 is built on the owner's uploaded `final.rbxl` (Round 103 plus
the other session's Mob, Tokoyami and Pucci). The JJBA place
(`jjba.rbxl`) is ported into it: "take my version of JJBA stands and
moves, and combine it with the current stand available in the final
version of quirk battlegrounds". Three scripts changed (`QuirkConfig`,
`VFX`, `QuirkServer`), and the JJBA place's assets were grafted in. Not
playtested in Studio yet.

**What came over from the JJBA place** (`tools/jjba/`; every old instance
in the place is byte-for-byte as it was).
- `ReplicatedStorage.JJBA.Stands`: its four Stand models (STAR PLATINUM,
  THE WORLD, C-MOON, MADE IN HEAVEN), with no scripts, Humanoids, saved
  animations or sounds.
- `ReplicatedStorage.JJBA.Clips`: 26 Stand clips. These are its
  KeyframeSequences, plus the 8 loops that only lived in its Moon
  Animator saves (the four barrages, C-MOON's heavy punch and block, The
  World's block, Star Platinum's Moon idle), converted into
  KeyframeSequences. The conversion is `T = v:Inverse() * C1`; it matched
  the exported twin to rounding error.
- `ReplicatedStorage.JJBA.Effects` (hit models, auras, the knife, the
  road roller, POM's void ball, and more) and `MetalPart`.
- 20 character clips in `ReplicatedStorage.Animations` (Jotaro's time
  stop and pose, DIO's ZA WARUDO / knives / vampire / road roller, Pucci's
  knives / gravity / evolve, POM's fist / heavy / void ball). The game's
  clip player picks them up by name: `PoseZaWarudo` and `PoseVampireHold`
  now play on DIO's R and 3 instead of the procedural poses.

**The Stands are drawn from the JJBA models** (`Config.JJBA`; VFX:
`VFX.JS`).
- On every screen the model is cloned, anchored, its joints read and
  removed, then posed every frame through its own rig
  (`Part1 = Part0 * C0 * T * C1^-1`), all in one BulkMoveTo.
- Where T comes from:
  - STAR PLATINUM and THE WORLD (CDV): the JJBA place's own clip for what
    the Stand is doing (Idle / Walk at his shoulder, the barrage loop in
    the rush, Heavy, Finger, Knives). With no clip for the action, the
    old figure's angle pose is put on the JJBA rig's joints, so every M1
    and move it already had still moves it. Every change is blended over
    `Fade`.
  - C-MOON and MADE IN HEAVEN ride Pucci's own rig (VFX.CM). Each mesh
    limb takes its bone's turn: an arm or leg follows the line from
    shoulder or hip to fist or foot, and the torso sits on the chest
    with its shoulders on C-MOON's. All of Pucci's keyed poses, strikes
    and the MADE IN HEAVEN swap hold.
- Each Stand gets its JJBA aura on its torso, its summon and dismiss
  bursts, arm trails and afterimage arms in the rush, and its colour on
  the shouts and outline.
- The old part-built figures come back if a model is missing, if
  `Config.JJBA.Enabled = false`, or if a Stand has `Use = false`.
- Checked offline (`tools/jjba/js_check.luau`) on the real models: all
  four punch toward their front in their own barrage clips; rest poses
  match the rigs; arms and legs follow the bones within 3°.

**STAR PLATINUM (Jotaro, new, dev only)** (`Config.Quirks.StarPlatinum`;
server `Kit.JJ`). Its M1s are the Stand's (StandReach 3).
- **1 ORA ORA ORA!**: Crazy Diamond's rush, in purple.
- **2 STAR FINGER**: two fingers out like a spear (24 studs). Damage,
  thrown, off their feet.
- **3 ORA!**: a wound-up punch with a crater.
- **R STAR PLATINUM: THE WORLD**: 2.5 s of DIO's stopped time (Kit.TS).
  Everything he does in it lands when time moves again.
- **4 BEARING SHOT**: a ball bearing at 320 studs/s that goes through one
  body.
- **Ult STAR PLATINUM: THE WORLD**: bigger rush, finger and ORA!, 5 s of
  stopped time, and **ORA ORA... ORA!!** (time stops, the Stand pummels
  the nearest one 30 times, and it all lands at once).
- Jotaro's look: cap and badge, long coat, collar and chain.
- Sounds: the JJBA place's.

**POM (new, dev only)**. No Stand. Two void balls on his fists and a
black-and-cyan aura (the JJBA place's).
- **1 FIST ATTACK**: a lunging punch.
- **2 DOUBLE ATTACK**: two blows.
- **3 HEAVY CHARGE**: an armoured wind-up, then one blow with a
  shockwave and a crater.
- **R VOID BALL**: thrown; it erases a channel through the street as it
  goes.
- **4 VOID SLAM**: up and down on the aim point.
- **Super leap**: jump again in the air.
- **Ult LAST WORD**: three void balls at once, and one great void ball
  that ends the ult.

**Stopped time is shared.** `TimeStopImmune` (DIO and Jotaro) means you
move in anyone's stopped time. Everyone else is still frozen by both.

**DIO and Pucci** keep their kits:
- DIO's knives are the JJBA place's `DIOKNIFE`, and the road roller is
  its `RoadRoller` mesh.
- The JJBA sounds are layered into the cues of their moves, on top of the
  game's own layers.
- The voices (ZA WARUDO, time resumes, ROAD ROLLER DA, "Made in Heaven",
  Star Platinum's) are the JJBA place's clips. If a clip won't load on
  that client, it falls back to the text-to-speech line (`Fallback`). The
  ult themes for Jotaro and POM are its MusicOST, with a licensed
  fallback.

**Known gaps.**
- **Audio privacy.** Roblox only plays audio that is public or owned by
  the game's owner. Many of the JJBA place's IDs are old uploads that may
  be private. Those layers stay silent, and the voices and themes fall
  back as described above.
- **Pucci's MADE IN HEAVEN horse.** The JJBA model's horse half is shaped
  its own way (in front of the torso). Only its turns follow the game's
  galloping bones, not its offsets.
- **What Lune can't do.** `Model:ScaleTo`, BulkMoveTo and the particle
  look are untested here: Lune has none of them, and the code falls back
  where they fail.

**Tests (round 104).**
- Server: both kits move by move (rush, finger at 18 vs 40 studs, ORA!,
  bearing at 60, stopped time holding the rush, the finale through
  stopped time; POM's five moves and LAST WORD ending the ult), DIO and
  Jotaro moving in each other's stopped time while Pucci doesn't, and
  both looks. 29 checks, all pass.
- Client: loads `tests/JJBA.rbxm` (a trimmed copy of the JJBA folder).
  Checks:
  - Star Platinum's model out with its own barrage and finger clips,
    shown, with its fist on the model's hand and its aura.
  - The World's model and barrage clip.
  - DIO's knife and road roller meshes.
  - Every Star Platinum and POM effect plays without a warning.
  - C-MOON drawn from its JJBA model on Pucci's rig.
  - It fails on the uploaded final and passes on round 104.
- Full suites on the round 104 sources:
  - Server: 1981 passed, 57 failed. The uploaded final: 1952 passed, the
    same 57 failed.
  - Client: stops where the uploaded final's run stops (a HUD meter
    error in the round 34 section, HUD line 5367). 89 problems before
    that point, every one also on the uploaded final, and none in the
    round 104 section.

### Round 103

Round 103 is built on Round 102. It changed three scripts (`QuirkConfig`,
`VFX`, `QuirkServer`); nothing else in the place changed. Not playtested
in Studio yet.

The owner sent a still from the 2018 Broly film (Broly inside a column of
green light going up into a dark sky, the ground scorched black and split
by glowing red cracks): "This emote should be powerful and affect the map
and world".

**FINAL FORM changes the world** (`Config.FinalForm.World`; VFX: `FF.world`
/ `FF.worldFrame`; the server's `Kit.FF`).
- **The column of light** (`Pillar`): from LEGENDARY (15.0 s) he's inside
  a green column 34-40 studs across and 900 tall, breathing on the beat,
  with light racing up inside it, a glow where it meets the street and a
  light. It holds through the roar and the glare, then draws in to
  nothing by 20.0 s, as the Eraser Cannon starts. A pitched-up rumble
  roars under it (the `Pillar` bed).
- **The sky** (`Sky`): a black-red storm ceiling 950 studs across, 175
  over the street, closes over the city through the surge (9-15 s),
  turns slowly, and goes with the power (25.6-28 s).
- **The land** (`Lava`, `Scorch`): 18 red-hot seams (8 on a low-end
  machine) race out across the map from him, each over a scorched black
  streak, out to 80-170 studs with branches. They grow through the surge,
  reach all the way out at LEGENDARY, and cool from 26.25 s. The ground
  under him is scorched black, 80 studs across.
- **The rubble** (`Debris`): 34 chunks lift off the street 16-85 studs
  round him from 10 s, hang there bobbing through the hold, and drop
  when the sky goes off (25.0 s).
- **Everyone's screen** (`Grade`): anyone else within 700 studs gets the
  world dark and red (a `FinalFormWorld` ColorCorrection on their camera,
  full within 350 studs). His own grade went red for the second stage
  too. Far-off screens (past `Skip`) still get the column, the sky and
  the red, but not the seams or the rubble.
- **The server, for real** (`Server`, `Kit.FF`): on the song's first drop
  a 14-stud crater (the `Crater` profile), and on LEGENDARY a 38-stud one
  (`FlightCrater`, GODSPEED's kind). Both are rebuilt after
  `Config.Destruction.RegenTime` like any move's damage. Each one shoves
  everyone near him back and up (24 / 46 studs; no damage, not knocked
  down; the game's own knockback scaling applies). They only happen while
  he's still in it: alive, within `Drift` (3) studs of where he started,
  and no other emote, move, dash or guard since. `Server.Enabled = false`
  keeps the visuals only.

**Known gaps.**
- The sky ceiling is a flat disk at 175 studs. A building taller than
  that pokes through it, and from more than ~475 studs away it's a disk
  in the sky.
- The seams lie flat at his street level: they pass under buildings
  (hidden inside them), and on a slope they float or sink.
- The server can't see his emote break off. It goes by where he stands
  and what he's pressed, so a player who freezes in place and presses
  nothing gets the craters even if his screen dropped the emote.

**Tests (round 103).**
- Client: three bodies at once (yours, someone's 60 studs off, someone's
  520 off) - the column, the sky, the seams out across the map, the
  scorch, the rubble rising and dropping, the red on someone else's
  screen and not on yours, the far one's world without seams or rubble,
  and everything gone at the end. Server: both craters with their
  profiles and the shove, nothing when he walked off, pressed a move or
  started another emote, and nothing with `Enabled = false`. Both fail on
  round 102's sources and pass now.
- Round 102's client section still passes on round 103's sources.
- Full server suite: 1972 passed, 60 failed (round 102: 1960 / 60). The
  60 are the same as round 102's apart from the emote-roll order check,
  which is random. The 12 new passes are round 103's section.

### Round 102

Round 102 is built on the owner's upload (`FINAL.rbxl`), which is round 98
plus another session's rounds 99-101. Those three rounds aren't in this
repo's history, and their tests aren't here; `src/` now holds their
scripts too. From their own comments:
- **Round 99:** GODSPEED (dev flight's last speed), outer space and the
  craters it leaves, Inasa's wind kit, All Might's look brought closer to
  the anime.
- **Round 100:** the Stark Street HUD kit (`HUD.ST`): the fight HUD, the
  top bar, the menus.
- **Round 101:** JJS-style awakenings with voice lines (`VFX.AK`), and
  FINAL FORM remade as a rage transformation.

Round 102 changed two scripts (`QuirkConfig`, `VFX`); nothing else in the
place changed. Not playtested in Studio yet.

The owner: "I want you to research broly's huge transformation in dbz. and
I already have a good layout for that already in the emote called final
form, but i need the scale and the transformation to last longer!!!"

**FINAL FORM, the whole song** (`Config.FinalForm`; VFX: the FINAL FORM
block, `EM.FF`). Round 101's layout is kept for beats 0-8 (the awakening,
FINAL FORM on the song's first drop at 5.0 s). It now runs 46 beats
(28.75 s of the song's 30) instead of 12 (7.5 s), in Broly's way: the
1993 film's Legendary Super Saiyan (body swelling far past his height,
green hair, blank white eyes, green aura, lightning) and the 2018 film's
Full Power (a green burst that lights the sky, the Eraser Cannon).
- **The surge (5.0-13.75 s):** bigger on each of the drop's hits (x1.55
  at Go to x2.55), the crab flex and the head-back strain in turn. Bigger
  rocks orbit him and slabs of the street tip up farther out, the cracks
  grow, bolts land wider and the cloud spreads.
- **The brink and the silent beat (13.75-15.0 s):** the scream, then the
  song's one silent beat: the light drains into him again and he's a
  black figure outlined in light.
- **LEGENDARY (15.0 s, the second drop):** x3.2, nearly 16 studs tall.
  The crown pops wilder and goes green, the burst comes again bigger (a
  360-stud pillar, domes, rings, spray) and leaves a second crater twice
  as wide.
- **The hold (15-25 s):** the roar at you, the glare, fists ground
  together, a flex on every hit.
- **The Eraser Cannon (20-25 s):** a green ball in his right fist swells
  on the hits, then he hurls it into the sky (23.75 s) and it goes off up
  there on the song's last hit (25.0 s), while he laughs.
- **The power-down (26.25-28.125 s):** steam, and he shrinks back to
  exactly his own size before his body is given back.
- **The bulk:** the double is thicker as well as taller (`Double.Bulk`:
  x1.33 at x3.2). Each limb turns on his own shoulder or hip on the wider
  torso, his head and what's welded to it aren't bulked (the face and
  crown ride it), and it's lifted if a spread leg would sink into the
  street. With no bulk it's exactly round 101's scaling.
- **His own camera** (`Config.FinalForm.Camera`): `Humanoid.CameraOffset`
  goes up 3 studs for every 1 he's grown, and the least zoom is pushed out
  to his zoom at the start x size^0.8 (8-70 studs). Both come back in with
  him as he shrinks. Each setting is given back exactly at the end (or
  when it's broken off), unless something else changed it meanwhile; a
  value changed meanwhile is kept.
- **New sounds** (all the game's own takes): `FinalFormCharge`,
  `FinalFormThrow`, `FinalFormSkyBoom` and `FinalFormQuake`. The beds add
  a second riser into the silent beat, a second scream and a second
  inhale.

**Known gaps.**
- How big he looks, the camera's lift and zoom, and the new poses are
  numbers on paper until someone watches it in Studio. The knobs are
  `Double` (sizes, `Bulk`), `Camera` and `Legendary`.
- The server still sees his real body: his hitbox and size never change.

**Tests (round 102).**
- A client section (pure checks of the size curve, the bulk, the silent
  beats and the crown, then a full 29-second run on a properly built R6
  body, one broken off as a giant, and one with a zoom setting changed
  mid-run). It fails on the upload's sources and passes now.
- On the upload's sources (before and after round 102) the harness's
  setup reports three HUD problems that come from round 100's HUD:
  "kill feed rows: 0", "recap panel missing" and "combo counter didn't
  reach 3 HITS".
- **Full server suite**, the upload's sources against round 102's: 1,959
  passed / 61 failed, and 1,960 passed / 60 failed. The failures are the
  same apart from two that change from run to run: the emote-roll order
  check (it fails on both, with different random picks) and the snack
  machine's "...nobody else can take it" (failed only on the upload's
  run). Against round 98's run, about 20 more fail on the upload's own
  sources, all in things rounds 99-101 changed:
  - the awakening outfits;
  - moves: Heaven-Piercing, Chimera Kraken, Weather Changer, New Order,
    Domain Expansion, BREAK and a few more;
  - round 98's Config check (passes with no Id yet);
  - the wipe's rebuild hook.

  Round 102 touches none of them. They're unexamined: the old tests may
  just be out of date.

### Round 98

Round 98 is built on Round 97. It changed four scripts (`QuirkConfig`,
`HUD`, `QuirkClient`, `QuirkServer`); nothing else in the place changed.
Not playtested in Studio yet.

The owner: "Give me some ban commands or kick too. Also make some
gamepasses, more emote slots. Awakening outfits, and make some badges that
peoples names. Like mod, tester, etc one for me too. Make them so I can
give them out".

**Moderation** (`Config.Moderation`, the server's `Kit.MOD`). New F2
console commands:
- `kick <who> [reason]`: out of this server; they can rejoin.
- `ban <who> [time] [reason]`: out of every server now, and turned away
  every time they come back until it runs out. The time is `30m`, `12h`,
  `7d`, `2w`, `1y` or `perm`; a bare number means days. With no time the
  owner's ban is permanent.
- `unban <who>`, `bans [who]` (the bans in force, or one person's) and
  `warn <who> <text>` (a red warning card on their screen).
- `<who>` is someone in the server (their name or the start of it),
  `@username` or a UserId. The last two reach people who aren't in the
  server. `all` / `others` / `random` are never allowed here, and a name
  start that fits two people is refused.
- Nobody can kick or ban the owner, themselves, or staff as high as they
  are.
- Bans are saved in a DataStore (a record per person plus a list for
  `bans`), and every other server is told over MessagingService, so a ban
  kicks them wherever they are. On a live server a ban also goes on
  Roblox's own ban list (`Players:BanAsync`, `RobloxBans`), which also
  catches the alt accounts Roblox links to them (`BanAlts`). `unban` lifts
  both.
- Studio keeps its bans, tags and given passes to itself
  (`StudioSaves = true` saves them).
- Reasons and warnings typed by one person for another go through
  Roblox's text filter.

**Staff.** A MOD or ADMIN tag gives console powers too:
- **Mod:** `kick`, `ban` (one day if no time is given, three days at most,
  even if they type `perm`), `unban` (only their own bans), `bans`,
  `warn`, `players`, `tp`, `flags`, `tags`, `help`. One person at a time.
- **Admin:** the same with no ban cap, lifting anyone's ban, plus
  `announce`, `bring` and `respawn`.
- Everything else stays the owner's. What staff type stays between them
  and the console, and the owner's console hears about every kick, ban and
  warning.

**Name tags** (`Config.Tags`, the server's `Kit.TG`). A coloured pill over
the name (everyone sees it, out to 100 studs) and `[TAG]` before the name
in chat (TextChatService).
- Tags: OWNER (always the game's owner; nobody can give or take it),
  ADMIN, DEV, MOD, TESTER, CREATOR, VIP (also comes with the VIP pass) and
  OG. Add more by copying a line in `Config.Tags.List`.
- `tag <who> <tag>`, `untag <who> <tag|all>`, `tags [who|tag]`. Saved:
  every server, every visit. The owner's commands only (`tags` is staff's
  too).
- Someone with several shows the first in the list.
- It hides whenever their name does: an invisible body, a see-through head
  (first person), down, the director's camera. Your own isn't drawn over
  your own head (`ShowOwn`), the way Roblox doesn't show you your name.
- `BadgeId`: put a Roblox badge's ID on a tag and whoever has it is
  awarded that badge.

**Game passes** (`Config.GamePasses`, the server's `Kit.GP`). Roblox
makes the passes: on the Creator Hub (your experience → Monetization →
Passes) create each one, set its picture and price, put it on sale and
paste its ID into `Id`. Until then a pass isn't sold (Studio shows its
banner anyway, marked "NO ID YET").
- **+8 EMOTE SLOTS:** a second ring of 8 on the emote wheel (16 in all).
  In the shop's EMOTES tab, the button at the end of the slot row offers
  the pass, and with it switches between RING 1 and RING 2. New emotes go
  on the second ring once the first is full. It's saved as `Wheel2`, and
  losing the pass hides the ring without emptying it.
- **AWAKENING OUTFITS:** the phone's OUTFIT app (round 59). It stays free
  for everyone until its `Id` is set (`FreeUntilSetUp`); after that the
  app shows the pass instead of the outfits, and a saved pick is only worn
  with the pass.
- **VIP:** the VIP name tag, and 25% more Bucks earned.
- **2x BUCKS:** double Bucks earned from KOs, raids, UNO wins and money
  rain (not codes, refunds or what the owner gives). With VIP too it's
  x2.5.
- They're under "Game passes" on the shop's SHOP tab, showing Roblox's
  real price, or OWNED / GIFTED.
- Bought in the game: on at once. Bought on the website: from their next
  join.
- `givepass <who> <pass>`, `takepass <who> <pass>` (only a given one: a
  bought pass is theirs) and `passes [who]`.

**Known gaps.**
- The tag's height over the name (`Height`, `Lift`) is a guess until
  someone looks at it in Studio.
- A record whose save failed is tried 3 times, then again with that
  person's next change.

**Tests (round 98).**
- **New checks:** 73 server checks and a client section. They cover:
  - bans, kicks and warnings, and the limits on mods;
  - the staff console;
  - saving, other servers, and Roblox's ban list;
  - tags and passes;
  - the emote ring and its save, the outfit pass, and Bucks;
  - on the client: tags over heads and in chat, the pass banners, the
    emote ring, the outfit lock, the warning card, and the console badge.

  Both fail on round 97's sources and pass now.
- **Full server suite:** 1,996 passed, 41 failed. That's round 94's 40
  plus "deflating: the bangs go with the costume". That check waits 0.2 s
  after a move; it passed in round 97 and in two earlier round 98 runs on
  the same game code. The snack machine's check passed this time.
- **Destruction suite:** unchanged (36 passed).
- **Full client suite** (run on its own): the same problems as round 97
  up to the round 17 stall, apart from the timing checks that flip:
  - failed this time: BACK DASH 66;
  - passed this time: M1Brawler4, RADIO 84 and SMASH 77.

### Round 97

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
python3 uniqueids.py out.rbxl   # no UniqueId shared by two instances (Studio refuses the place otherwise)
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
python3 uniqueids.py out.rbxl   # no UniqueId shared by two instances (Studio refuses the place otherwise)
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

Found in round 98:
- Moderation, tags and passes are reached through `Destruction.Moderation`
  (`Kit.MOD`, with `.TG`, `.GP` and `.Console`).
- In Studio everyone the server harness makes is an owner, so the round 98
  tests mark their players as not owners (`Console.owners[p] = false`)
  before they join.
- The tests give the DataStore mock an `UpdateAsync` and switch
  `StudioSaves` on to check what's saved. They stub `Players.BanAsync` /
  `UnbanAsync` and the text filter, and flip `studioMode` off for the live
  ban.
- On the client, `SetAttribute` doesn't fire the change signal; the
  harness's `setAttr` does. The client keeps only your own `Character`, so
  the name tag tests use your own body with `ShowOwn` on. Lune's parts
  have no `LocalTransparencyModifier`, so the tests implement it for
  `Part` and `MeshPart`.

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

Found in round 102:
- The HUD uses `Font.new` since the owner's round 100: the client
  harness's script environment has `Font` now.
- Lune doesn't keep every bit of a `Vector3` property: 0.3 reads back as
  0.30000305. Tests compare against the value read back after setting it.
- The client keeps an R15 body; the harness's R6 dummy has every limb at
  the origin. The round 102 section builds its own R6 body (real
  proportions and joints) and makes it yours for the run.
- The main chunk of `client_tests.luau` is at Luau's 200-register limit
  where the round sections go, so the round 102 section runs in a
  function of its own.

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
