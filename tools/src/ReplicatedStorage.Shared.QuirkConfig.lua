-- QuirkConfig (ModuleScript) — ReplicatedStorage.Shared.QuirkConfig
-- Every tunable number lives here. Server and client both read it, so
-- cooldowns and names stay in sync.

local Config = {}

Config.GameTitle = "QUIRK BATTLEGROUNDS" -- rename to whatever you want

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------

-- Keyboard + mouse: every move is on the number keys, 1 2 3 4. And a
-- controller layout copied from Jujutsu Shenanigans: B punches, the
-- bumpers/triggers are the moves (LB, LT, RT, then RB), X guards, Y dashes, A
-- jumps, the D-pad holds the ult (up), the special (left), shift lock (down)
-- and your item (right). Push the left stick all the way to sprint. ((round
-- 92) no lock-on any more - "remove lock-on": T / L3 are the dev flight's
-- hover-lock only, Config.DevFlight.LockKeys)
Config.AbilityKeys = {
	{ Enum.KeyCode.One, Enum.KeyCode.ButtonL1 },
	{ Enum.KeyCode.Two, Enum.KeyCode.ButtonL2 },
	{ Enum.KeyCode.Three, Enum.KeyCode.ButtonR2 },
}
Config.M1Keys = { Enum.KeyCode.ButtonB } -- (and the left mouse button)
Config.MenuKey = Enum.KeyCode.M
Config.SpecialKeys = { Enum.KeyCode.R, Enum.KeyCode.DPadLeft }
Config.UltKeys = { Enum.KeyCode.G, Enum.KeyCode.DPadUp }
Config.DashKeys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }
Config.SprintKeys = { Enum.KeyCode.LeftControl } -- controller: push the stick all the way
Config.AutoSprintStick = 0.9 -- how far the left stick goes before you break into a sprint
Config.BlockKeys = { Enum.KeyCode.F, Enum.KeyCode.ButtonX } -- hold to guard
Config.ExtraKeys = { Enum.KeyCode.Four } -- the 4th move
Config.FinisherKeys = { Enum.KeyCode.E } -- finish someone at their last sliver of health
-- RB: the 4th move slot. Finishes a nearly-beaten target in front of you,
-- otherwise it's the 4th move (4)
Config.ContextKeys = { Enum.KeyCode.ButtonR1 }
Config.ShiftLockKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.DPadDown }
Config.ItemKeys = { Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }
Config.UseItemKeys = { Enum.KeyCode.DPadRight } -- tap: use the selected item, hold: pick the next one
Config.ShopKeys = { Enum.KeyCode.H, Enum.KeyCode.ButtonSelect }
Config.BoardKeys = { Enum.KeyCode.L } -- TOP HEROES: the all-time kills leaderboard
Config.EmoteKeys = { Enum.KeyCode.B, Enum.KeyCode.ButtonR3 } -- the emote wheel (controller: click the right stick, tilt it to pick, click again)

-- Ability indices as they travel to the server
Config.SPECIAL_INDEX = 4 -- R
Config.ULT_INDEX = 5 -- G
Config.DASH_INDEX = 6 -- Q
Config.LEAP_INDEX = 7 -- All Might's super leap (jump again in the air)
Config.BLOCK_INDEX = 8 -- F: guard on / off
Config.EXTRA_INDEX = 9 -- 4: the 4th move (every kit's Extra)
Config.FINISH_INDEX = 10 -- E: finisher on a nearly-beaten target
Config.PARKOUR_INDEX = 11 -- (no key: tells everyone which parkour move you're doing)
Config.RELEASE_INDEX = 12 -- (no key of its own: letting go of a move you're holding/charging)
Config.EMOTE_INDEX = 13 -- B: an emote off the wheel
Config.AIM_INDEX = 14 -- (no key: where you're aiming now, while a move that follows your aim goes)
Config.PRANK_INDEX = 15 -- LB + RB together (1 + 4): Iida's prank, in his ult, in the air - only
-- while the test menu's "Iida's Muffler Prank" switch is on (workspace MufflerPrank)
Config.PrankWindow = 0.18 -- how close together the two have to be

-- The emote wheel (B): tap B and click one, or hold B, point at one and let
-- go. An emote is a motion everyone sees; it stops the moment you move, jump
-- or get hit. Round the wheel clockwise from the top. Say: a word bubble.
-- (Icon: the picture on the controller menu's card)
-- (round 58) They're got from the Hero Shop - the only way to get one - and
-- your wheel holds EmoteSlots of the ones you own. A new player starts with
-- none: an empty wheel. (round 63) The shop sells them the way Jujutsu
-- Shenanigans does: a random one you don't have yet (Config.EmoteShop),
-- picked by Rarity. (Exclusive = true: never rolled - codes and events only.)
Config.Emotes = {
	{ Id = "Wave", Rarity = "Common", Name = "WAVE", Icon = "👋" },
	{ Id = "Point", Rarity = "Common", Name = "YOU'RE NEXT", Say = "YOU'RE NEXT.", Icon = "👉" },
	{ Id = "Laugh", Rarity = "Common", Name = "LAUGH", Say = "HA HA HA!", Icon = "😂" },
	{ Id = "Cheer", Rarity = "Rare", Name = "PLUS ULTRA!", Say = "PLUS ULTRA!", Icon = "🔥" },
	-- (round 85) DANCE: 16 beats of house on the drop of Tony Romera - "I
	-- Can't" (Monstercat: free in any experience) - the step-clap, raise the
	-- roof, the pump, a spin and a pose. Song / SongStart (on the beat) /
	-- Volume / Bpm: every emote with a song plays it (VFX: the Emote wrapper),
	-- from SongStart, faded out when it ends or is broken off.
	{ Id = "Dance", Rarity = "Rare", Name = "DANCE", Icon = "🕺", Song = "rbxassetid://5410082805", SongStart = 45.76, Volume = 0.55, Bpm = 126 },
	{ Id = "Flex", Rarity = "Common", Name = "FLEX", Icon = "💪" },
	{ Id = "Bow", Rarity = "Common", Name = "BOW", Icon = "🙇" },
	{ Id = "Taunt", Rarity = "Common", Name = "COME ON", Icon = "😤" },
	-- (round 53) DRAGON BALL Z: cup it at the hip - KA... ME... HA... ME...
	-- HA!! - and a beam goes down the street (it doesn't hurt anyone)
	{ Id = "Kamehameha", Rarity = "Legendary", Name = "KAMEHAMEHA", Icon = "🌀" },
	-- BREATH OF THE WILD: the cooking pot on the campfire, the ingredients
	-- hopping about in it, and he holds up what came out: Dubious Food
	{ Id = "DubiousFood", Rarity = "Epic", Name = "DUBIOUS FOOD", Icon = "🍲" },
	-- up out of sight and back down in a three-point landing that cracks
	-- the street
	{ Id = "HeroLanding", Rarity = "Epic", Name = "HERO LANDING", Icon = "💥" },
	{ Id = "TPose", Rarity = "Rare", Name = "T-POSE", Icon = "🧍" },
	-- (round 85) THE GRIDDY to Slippy - "Flow" (Monstercat), from its drop:
	-- 156 bpm (a 78 half-time swagger), the heel taps on every beat, then
	-- the goggles - 16 beats
	{ Id = "Griddy", Rarity = "Rare", Name = "THE GRIDDY", Icon = "🥽",Song = "rbxassetid://7028913008", SongStart = 52.32, Volume = 0.65, Bpm = 156 },
	-- asleep sitting up, a snot bubble growing and shrinking till it pops
	{ Id = "Nap", Rarity = "Rare", Name = "NAP", Icon = "💤" },
	-- he dies (dramatically), his soul floats up - and gets sucked back in
	{ Id = "FakeDeath", Rarity = "Epic", Name = "FAKE DEATH", Icon = "👻" },
	-- THE JIGGY (round 63: it was DAD MODE; same Id, so owners keep it): a
	-- full dad-dance routine to a song, 32 beats of it - the disco
	-- point, the sprinkler, the lawnmower (it takes two pulls to start), the
	-- floss, and a dab to finish - on a light-up dance floor under a disco
	-- ball. Song: the track it dances to (audio/dad_mode.mp3 in the repo,
	-- uploaded to Roblox; with no Song it plays Config.Music.Disco). Bpm /
	-- Offset (seconds to the first beat) keep the lights on the beat.
	-- (round 85: measured, the song is 128.95 bpm with its first beat at
	-- 0.085 s - the dance reads this Bpm too. A Party emote's song plays from
	-- SongStart (none here: 0); Offset = the first beat after that; the
	-- confetti's on beat ConfettiBeat, 0-based, default 30.)
	{ Id = "DadMode", Rarity = "Legendary", Name = "THE JIGGY", Say = "HIT IT!", Icon = "🎶", Party = true, Song = "rbxassetid://116394797033057", Bpm = 128.95, Offset = 0.085 },
	-- (round 72) WHY ARE YOU CRYING, to 我真的特别爱你 (为什么你会流泪): 36
	-- beats, each on the song's beat. Shy, a huge breath while the song drops
	-- out, then down on one knee on the hook under a big pastel heart - "I
	-- REALLY LOVE YOU!!" - and the heart cracks in two. He falls apart:
	-- sobbing into his hands with anime waterfall tears, a rain cloud all his
	-- own, pounding the street and wailing at the sky, a puddle growing
	-- under him, a tantrum face down on the floor... then he's up like
	-- nothing happened, dabs his eyes with a hanky, and a smug finger heart:
	-- "why are YOU crying?". Song: (round 73) its own track, composed for it
	-- beat for beat (audio/why_are_you_crying.mp3 in the repo - Roblox takes
	-- the original song down as copyrighted music). SongStart: where in the
	-- upload to start (0). (round 76) Where the music comes from, first found:
	-- a Sound called WHY ARE YOU CRYING in a folder called Emotes in Workspace
	-- (the way the All Might / Bakugo / Deku folders are - upload the mp3, put
	-- the Sound there); Song (an id); else FallbackSong - a licensed track
	-- from the Creator Store ("Very Sad", Kosinus Arts: free in any
	-- experience), so it's never silent. (Any emote with a song works the same.)
	{ Id = "WhyCry", Rarity = "Legendary", Name = "WHY ARE YOU CRYING", Icon = "😭", Song = "", SongStart = 0, Bpm = 116.9,
		FallbackSong = "rbxassetid://1838845759", FallbackStart = 0, FallbackVolume = 0.7 },
	-- (round 85) ROBO-CHOP: Iida, class rep, takes the floor - glasses
	-- pushed up, his chopping hands, robot turns with his head a beat
	-- behind, a stiff-legged march with his calves popping exhaust, a robot
	-- arm wave, a rev in a sprinter's set and a chop salute: 32 beats to
	-- Pegboard Nerds & Tokyo Machine - "MOSHI" (Monstercat: free in any
	-- experience), from the drop's first kick (59.89 s, on the beat grid)
	{ Id = "RoboChop", Rarity = "Legendary", Name = "ROBO-CHOP", Icon = "🤖", Song = "rbxassetid://7024340270", SongStart = 59.89, Volume = 0.55, Bpm = 128 },
	-- (round 85) AURA FARM: shades on, stood on the bow of a long racing
	-- canoe gliding down a river, rowers paddling on the beat behind him,
	-- doing the calm arm rolls and hand waves of the 2025 boat-race clips -
	-- aura flames, and a +AURA to finish: 32 beats to "AURA = INF"
	-- (DistroKid: free in any experience) from 16.67 s (on the beat grid)
	{ Id = "AuraFarm", Rarity = "Legendary", Name = "AURA FARM", Icon = "🛶", Song = "rbxassetid://95131770144654", SongStart = 16.67, Volume = 0.9, Bpm = 146 },
	-- (round 85) FEVER TIME: Saturday-night disco on a light-up floor under
	-- a mirror ball - the point, hip rolls, a spin, the hustle, a knee drop
	-- and the poster pose in a spotlight: 32 beats to "I Like To Disco B"
	-- (APM: free in any experience) from 24.37 s (its first beat + 12 bars)
	-- (round 92: Icon 💃 - 🪩 isn't in Roblox's emoji font, TwemojiMozilla,
	-- so it showed as a box; the wheel shows icons now)
	{ Id = "FeverTime", Rarity = "Legendary", Name = "FEVER TIME", Icon = "💃", Song = "rbxassetid://1847785418", SongStart = 24.37, Volume = 1.0, Bpm = 120 },
	-- (round 85) I AM HERE: All Might's entrance to a brass fanfare (APM,
	-- "March of Justice 30A": free in any experience) - up out of sight and
	-- down in a landing that cracks the street, up in shadow ("IT'S FINE
	-- NOW." "WHY?"), then the grin, the bangs, the god rays and the hero
	-- stance: "I AM HERE!" - a laugh, a thumbs-up. 12 beats.
	{ Id = "IAmHere", Rarity = "Epic", Name = "I AM HERE", Icon = "🦸", Song = "rbxassetid://1835323453", SongStart = 0.11, Volume = 1.2, Bpm = 95 },
	-- (round 85) SWING TIME: a top hat and cane Charleston under a spotlight
	-- to "Swing With Me (Electro Swing Mix)" (APM) - the Charleston, the
	-- bee's knees, a cane twirl, cane taps, a spin and a hat tip. 32 beats.
	{ Id = "SwingTime", Rarity = "Epic", Name = "SWING TIME", Icon = "🎩", Song = "rbxassetid://1838645022", SongStart = 11.53, Volume = 0.9, Bpm = 130 },
	-- (round 85) MENACING: a JoJo-style menace taunt on the drop of Pegboard
	-- Nerds - "Shaku" (Monstercat): four poses on the drop's hits, purple
	-- ゴゴゴ letters drifting up round him. 8 beats (3.4 s): fine mid-fight.
	{ Id = "Menacing", Rarity = "Epic", Name = "MENACING", Icon = "😈", Song = "rbxassetid://7024332460", SongStart = 70.67, Volume = 0.5, Bpm = 140 },
	-- (round 85) EMERGENCY EXIT (Iida's season-1 gag): the alarm's going off,
	-- the engines fire him up and he's slapped flat on a big exit sign in its
	-- running man - to APM's "Pixieland Rag" (free in any experience), 10
	-- beats from its loud part
	{ Id = "EmergencyExit", Rarity = "Epic", Name = "EMERGENCY EXIT", Icon = "🚪", Say = "EVERYONE, STAY CALM!!",
		Song = "rbxassetid://1842247195", SongStart = 20.13, Volume = 1.2, Bpm = 97 },
	-- (round 85) SHUFFLE: cutting shapes on a light-up floor - the running
	-- man, the T-step, kick-cross, double-time, a spin and a freeze: 16
	-- beats to Rogue - "Move Me" (Monstercat) from the big drop (105.02 s)
	{ Id = "Shuffle", Rarity = "Rare", Name = "SHUFFLE", Icon = "👟", Song = "rbxassetid://7028548115", SongStart = 105.02, Volume = 0.6, Bpm = 128 },
	-- (round 85) REV IT UP (Iida): a sprinter's set, three revs of his calf
	-- engines - the third catches, cyan jets - and a smug chop. No song: the
	-- engines are the music
	{ Id = "RevItUp", Rarity = "Rare", Name = "REV IT UP", Icon = "💨" },
	-- (round 85) SHORT CIRCUIT (Kaminari's overload): zapped stiff, then the
	-- brain-fried "WHEEEY~" with both thumbs up - to APM's "Circus Parade
	-- (A)", 8 beats from the top
	{ Id = "ShortCircuit", Rarity = "Rare", Name = "SHORT CIRCUIT", Icon = "⚡",
		Song = "rbxassetid://1840443886", SongStart = 0.45, Volume = 1.2, Bpm = 126 },
	-- (round 85) SIX SEVEN: the "6 7" meme - palms up, see-sawing, a big 6
	-- and 7 popping over his hands - to DRIFT NIGHT PHONK (DistroKid). 6
	-- beats (2.3 s).
	{ Id = "SixSeven", Rarity = "Common", Name = "SIX SEVEN", Icon = "🤲", Song = "rbxassetid://85735197482652", SongStart = 12.41, Volume = 1.2, Bpm = 155 },
	-- (round 85) HOLD THIS L: an L on the forehead, then a big one handed to
	-- you - to the horn stabs of APM's "Power Move (b 60)", 4 beats
	-- (round 92: Icon 😏 - 🫵 isn't in Roblox's emoji font either)
	{ Id = "HoldThisL", Rarity = "Common", Name = "HOLD THIS L", Icon = "😏",
		Song = "rbxassetid://1840019129", SongStart = 30.11, Volume = 1.2, Bpm = 97 },
	-- (round 92) TEN MORE (VFX: the round-92 emote block). Songs are licensed
	-- Creator Store audio (APM, Monstercat, DistroKid: free in any
	-- experience) from the round-84 music catalog, none heard by ear yet:
	-- SongStart is on each one's measured beat grid (Crab Rave's isn't
	-- measured: 16 bars in, where its intro should end).
	-- SEAN O'PRY: the 2026 meme - the model's 2015 mango tutorial ("can i get
	-- another mango?") and his finger-snap edit. He botches a mango on a
	-- cutting board, deadpans the line, catches another... and the beat
	-- drops: a snap on every other beat - each one a new suit (black, white,
	-- gold: the cologne ad he snapped through) - the runway smolder, a laugh
	-- track, and a last snap that rains mangoes. 24 beats to APM's "Energize
	-- Me" (future house, the sound-alike of the edits' music): 8 of its intro
	-- for the mango, then the kick comes in on the first snap.
	{ Id = "SeanOPry", Rarity = "Legendary", Name = "SEAN O'PRY", Icon = "🥭", Song = "rbxassetid://9040295642", SongStart = 3.91, Volume = 0.6, Bpm = 124 },
	-- CRAB RAVE: claws up - crabs scuttle in from all round and rave with
	-- him: the crab walk, a spin, the drop, a low shuffle and claws to the
	-- sky. 16 beats to Noisestorm - "Crab Rave" (Monstercat).
	{ Id = "CrabRave", Rarity = "Epic", Name = "CRAB RAVE", Icon = "🦀", Song = "rbxassetid://5410086218", SongStart = 30.72, Volume = 0.5, Bpm = 125 },
	-- FINAL FORM: the battlegrounds power-up - feet planted, the ground
	-- shaking, rocks lifting, a scream, lightning, then a golden aura and a
	-- pillar of light into the sky; he comes out of it in a stance. 12 beats
	-- to APM's "Anthemic Step Music" (a dubstep sting).
	{ Id = "FinalForm", Rarity = "Legendary", Name = "FINAL FORM", Icon = "🌟", Song = "rbxassetid://1836098839", SongStart = 0.02, Volume = 0.65, Bpm = 96 },
	-- K-POP IDOL: on stage with a headset mic - the big heart, the point
	-- steps, a body roll, a hair flip, the hook, a spin and a finger heart at
	-- the cheek, light sticks waving. 16 beats to "K-Pop Party" (DistroKid).
	{ Id = "KPopIdol", Rarity = "Epic", Name = "K-POP IDOL", Icon = "💖", Song = "rbxassetid://135361546383974", SongStart = 22.71, Volume = 1.2, Bpm = 127 },
	-- MIC DROP: a mic in a spotlight, "PEACE OUT.", held out... and dropped:
	-- BOOM. He's already walking. No song (3 s: a quick one mid-fight).
	{ Id = "MicDrop", Rarity = "Common", Name = "MIC DROP", Icon = "🎤", Bpm = 120 },
	-- BREAKDANCE: on a cardboard mat by a boombox - toprock, the drop, a
	-- headspin and the b-boy stance. 12 beats to "Boom Bap Hip Hop Beat"
	-- (DistroKid).
	{ Id = "Breakdance", Rarity = "Epic", Name = "BREAKDANCE", Icon = "🧢", Song = "rbxassetid://76909090263477", SongStart = 3.29, Volume = 1.2, Bpm = 90 },
	-- MAKE IT RAIN: shades on, a stack of Bucks, a bill flicked off it on
	-- every beat, then the whole stack thrown up. 12 beats to APM's "Funk
	-- Boss".
	{ Id = "MakeItRain", Rarity = "Rare", Name = "MAKE IT RAIN", Icon = "💸", Song = "rbxassetid://1839367287", SongStart = 18.98, Volume = 1.15, Bpm = 102 },
	-- MOONWALK: the point to the sky, gliding backwards over a sidewalk
	-- that lights up under his feet, a spin, up on his toes and the lean.
	-- 12 beats to APM's "Moonwalk".
	{ Id = "Moonwalk", Rarity = "Rare", Name = "MOONWALK", Icon = "🌙", Song = "rbxassetid://1837664271", SongStart = 0.47, Volume = 0.9, Bpm = 125 },
	-- TUNG SAHUR: the brainrot - he's a wooden log with a bat: TUNG TUNG TUNG
	-- (nine of them)... SAHUR! No song: the bat is the beat (Bpm: its tempo).
	{ Id = "TungSahur", Rarity = "Rare", Name = "TUNG SAHUR", Icon = "🥁", Bpm = 200 },
	-- BOO!: tiptoeing up on you... BOO! - a jack-o'-lantern head, bats
	-- everywhere, a cackle. To APM's "Tongue In Cheek" (no beat: Bpm is the
	-- tiptoe's).
	{ Id = "Boo", Rarity = "Common", Name = "BOO!", Icon = "🎃", Song = "rbxassetid://1837500112", SongStart = 0, Volume = 1.2, Bpm = 120 },
}

-- (round 58) how many the wheel holds. (round 92) 8 (it was 4): one ring of
-- eight - the eight ways a mouse flick or the right stick points - on PC,
-- the controller's menu (4 x 2 cards) and the phone. A wheel saved with the
-- old four keeps them where they were on the ring (top, right, bottom, left
-- = slots 1, 3, 5, 7), and the new slots between them get the newest of the
-- rest they own (the server, when it loads them; saves say how many slots
-- they were made with: WheelSlots).
Config.EmoteSlots = 8

-- (round 63) THE SHOP, the way Jujutsu Shenanigans does it (its wiki: the
-- Shop and Emotes pages). A SHOP tab of wide banners - EMOTES: a random
-- emote you don't have yet (never a repeat), RollPrice each, bought 1x / 2x /
-- 5x / 10x at a time (Multipliers); buying PickAt at once, you choose the
-- last one yourself from every one you don't have (or PICK LATER - it waits
-- for you, saved). The odds are on the banner: each roll picks a rarity by
-- Weight, then an emote of it. SODA / ITEM DELIVERY (Config.Deliveries)
-- follow, then everything else by name. An EMOTES tab (yours, newest first
-- or A-Z, with a search, and your wheel) and a REWARDS tab (Config.Codes).
Config.EmoteShop = {
	RollPrice = 25,
	Multipliers = { 1, 2, 5, 10 },
	PickAt = 10,
	-- (round 72) ROBUX: the same rolls for Robux, alongside Bucks. Each
	-- multiplier is a Developer Product you make on the Creator Dashboard
	-- (your experience > Monetization > Developer Products): paste its ID
	-- into Product. 0 = not set up yet: no Robux button for that one. Price:
	-- what the button says until Roblox tells the game the product's own
	-- price (set the real price on the dashboard).
	Robux = {
		[1] = { Product = 0, Price = 25 },
		[2] = { Product = 0, Price = 49 },
		[5] = { Product = 0, Price = 119 },
		[10] = { Product = 0, Price = 229 },
	},
	-- (round 72) WIPE: everyone's emotes - what they own, their wheel, their
	-- free picks - are taken away once, the first time they join after this
	-- number changes (it's saved with them). 0 = never. Bump it to wipe again.
	Wipe = 1,
	-- (round 72) the roll's reveal goes by itself this many seconds after the
	-- last card's turned over (a second more for a big roll); NICE! closes it
	-- straight away, and a click anywhere turns the rest over at once
	RevealStay = 1.8,
	Rarities = {
		{ Id = "Common", Name = "COMMON", Weight = 55, Color = Color3.fromRGB(196, 202, 214) },
		{ Id = "Rare", Name = "RARE", Weight = 28, Color = Color3.fromRGB(96, 170, 255) },
		{ Id = "Epic", Name = "EPIC", Weight = 13, Color = Color3.fromRGB(196, 110, 255) },
		{ Id = "Legendary", Name = "LEGENDARY", Weight = 4, Color = Color3.fromRGB(255, 204, 60) },
	},
}

-- (round 63) DELIVERIES: pay, and it comes to you - wherever you are on the
-- map; walk into it to take it (it's yours alone). Left Despawn seconds,
-- it's gone. Soda: a soda (Item); Item: a random one of the shop's items
-- that fits your bag. (MaxAtOnce: deliveries on the way at a time.)
-- (round 66) THE SUPPORT DROP: it comes in a U.A. Support Course drop pod
-- (Pod): FallTime seconds out of the sky (Height studs up, Drift across)
-- onto a ring it marks Offset studs from you - everyone sees it coming - and
-- anyone else within Radius is thrown clear (Push / Lift). It opens
-- OpenDelay after it lands, your delivery sitting on top (Pedestal).
Config.Deliveries = {
	Soda = { Name = "SODA DELIVERY", Info = "A Support Course drop pod brings you a drink, anywhere on the map!", Price = 5, Item = "Soda" },
	Item = { Name = "ITEM DELIVERY", Info = "A drop pod with a random item inside - test your luck!", Price = 8 },
	Despawn = 10, MaxAtOnce = 2,
	Pod = { FallTime = 1.6, Height = 170, Drift = 60, Offset = 6, Radius = 8, Push = 55, Lift = 30, OpenDelay = 0.5, Pedestal = 3.4 },
}

-- (round 63) CODES for the REWARDS tab: CODE = { Bucks = n, Emote = "Id" }.
-- Each works once per player (saved). Add your own for updates and events.
Config.Codes = {
	PLUSULTRA = { Bucks = 25 },
	GOBEYOND = { Bucks = 10, Emote = "Cheer" },
}

-- ONE FOR ALL: THE VESTIGE REALM (round 58): the space inside the quirk
-- where Deku, dreaming, met the ones who held it before him - built far from
-- the city (Center: the floor's surface). The way in is easy to miss: the
-- lone bench on a roof at the north end of the city (Bench) - rest there
-- (hold E for RestTime seconds). The way out: the pale doorway behind where
-- you wake, or off the edge.
Config.VestigeRealm = {
	Enabled = true,
	Center = Vector3.new(2600, 1400, -2600),
	Bench = Vector3.new(39.3, 157.1, 1144.5),
	RestTime = 2,
}

-- (round 71) DEKU'S MEMORIES, inside One For All. In the dark of the
-- vestige realm stands a lone classroom door - the huge "barrier-free" door
-- of Class 1-A. Through it: U.A. High, Class 1-A, the way Deku first saw it
-- (Classroom: where the room's floor is, from the realm's Center). The
-- room's big door opens onto the U.A. Sports Festival stadium (Stadium):
-- step up onto the stage and the memory plays for you - Midoriya vs
-- Todoroki, the final tournament - and it ends in a clash that's yours to
-- push (ClashTime seconds; Rival: how hard Todoroki pushes back, presses a
-- second and how many of them count). FightTime: how long before the stage
-- plays it for you again. FadeTime: the white-out between memories. The
-- tunnel out of the stadium, and the classroom's small back door, lead back
-- into the realm.
Config.DekuMemories = {
	Enabled = true,
	Classroom = Vector3.new(0, 0, -900),
	Stadium = Vector3.new(0, 0, -1800),
	FadeTime = 1,
	FightTime = 40,
	ClashTime = 9,
	Rival = { Rate = 3.3, Accuracy = 0.8 },
}

-- Testing menu (P, or the TEST button top-left). Who can use it:
--   everyone while testing in Studio, the game's creator, and AllowedUserIds.
--   Set Public = true to let everyone use it in a live game (not recommended).
Config.TestMenu = {
	Enabled = true,
	Key = Enum.KeyCode.P,
	AllowedUserIds = {},
	Public = false,
}

-- (round 66) THE CONSOLE (F2): every test feature as a typed command ('help'
-- lists them). Only the OWNER runs commands: the account that made the game
-- (a group game: the group's owner) and anyone in Owners (UserIds) - in
-- Studio, whoever's testing (Player1 of a local server test). Anyone else
-- can open it and watch the log, read-only. History: lines the server keeps.
Config.Console = {
	Enabled = true,
	Key = Enum.KeyCode.F2,
	Owners = {},
	History = 200,
}

-- (round 86) DEV FLIGHT: Invincible / Omni-Man flight, for the owner and
-- Devs only. Who: the game's owner (its creator - a group game: the group's
-- owner -, Config.Console.Owners, and in Studio whoever's testing: Player1 of
-- a local server test, anyone in a place that's never been published) and
-- the UserIds in Devs. The server checks it on the switch and on every
-- request it acts on (a building smashed, a crater, a boom everyone hears,
-- people knocked aside): nobody else gets any of it.
--   V (Key), the test menu's DEV FLIGHT, or holding the D-pad down PadHold
--   seconds (a tap is still shift lock): fly / stop. On the street it's the
--   take-off - a tap: a quick crouch; held: charged up to MaxCharge, the
--   harder he goes. In the air he catches himself. Off mid-air: he drops.
--   W / the stick: where the camera looks (CRUISE). Let go and he hovers
--   (A/D/S drift, Space / A up, C / LT down - with sprint, faster).
--   SPRINT (Left Ctrl, the stick all the way, RT, the phone's RUN): FAST;
--   kept Enter seconds at FAST: HYPERSONIC, the sonic boom as he passes
--   BoomAt. DASH (Q / Y / DASH) or a double-tap of sprint: the MACH BURST.
--   GUARD (F / X / BLOCK) at speed, or S held: the braking flip.
--   T / L3 / the phone's LOCK (LockKeys): the hover-lock (round 90).
--   X / RB: the DIVE SLAM onto where the camera looks (RB with someone
--   ready to finish: the FINISH, as on foot). A controller loses LT / RT /
--   RB's moves while he flies (they're the flight's); M1 and LB still go.
-- Coming down slow: the superhero landing; at Crash.Speed or more: the
-- Omni-Man crash and its crater. Skimming the street shallow and fast holds
-- him Skim studs over it. At FAST and up he goes through breakable buildings
-- (the server carves a FlyThrough segment each, Smash.Rate a second) and
-- knocks people out of his way (Ram: no damage). Unbreakable walls stop
-- him dead (WallHit). M1s and moves still go: he hangs in the air for them.
Config.DevFlight = {
	Enabled = true,
	Devs = {}, -- UserIds besides the owner
	Key = Enum.KeyCode.V, -- fly / stop (held on the street: the charged take-off)
	PadHold = 0.45, -- a controller: hold the D-pad down this long (a tap is still shift lock)
	DownKey = Enum.KeyCode.C, -- sink (a controller: LT)
	DiveKey = Enum.KeyCode.X, -- the dive slam (a controller: RB)
	-- (round 92) THE HOVER-LOCK's keys (Control.Lock): the flight's own, bound
	-- only while he flies (the lock-on they were is gone); a phone: its LOCK
	-- button, shown only while he flies
	LockKeys = { Enum.KeyCode.T, Enum.KeyCode.ButtonL3 },
	Tiers = {
		-- Drift: A/D/S while hovering; Rise / Sink: Space / C (Fast*: with sprint); Bob: studs
		Hover = { Speed = 0, Drift = 24, Rise = 30, Sink = 12, FastRise = 64, FastSink = 40, Accel = 7, Bob = 0.5, BobPeriod = 3.2, Lean = 10, Fov = 70 },
		-- Up / Down: how fast he gets to the speed and comes off it (1/s); Turn:
		-- how fast the heading follows the camera (1/s); Bank: degrees at most
		-- into a turn; Lag: how far the camera trails (studs); Roll: the
		-- camera's tilt into a turn at most (degrees); HeadUp: the chest
		-- raised off the line he flies (degrees)
		-- (round 90, devfly2: "a little more controllable" - Turn 6 / 3.5 /
		-- 1.8 -> 7.5 / 5 / 3 and the heading now swings round a big turn at
		-- once (Control.Turn: a U-turn at HYPERSONIC took 9 s, now ~1); Align
		-- 12 / 10 / 8 -> 16 / 14 / 12: the body follows his line tighter.
		-- Strafe: A / D across his line, studs/s - r90/out/devfly2_sims.png)
		Cruise = { Speed = 90, Up = 6.5, Down = 3.2, Turn = 7.5, Bank = 35, Fov = 78, Lag = 1, Roll = 10, Align = 16, HeadUp = 10, Strafe = 45 },
		Fast = { Speed = 220, Up = 4.5, Down = 2.2, Turn = 5, Bank = 55, Fov = 88, Lag = 2.4, Roll = 14, Align = 14, HeadUp = 6, Strafe = 70 },
		Hyper = { Speed = 520, Up = 4.5, Down = 1.4, Turn = 3, Bank = 70, Fov = 100, Lag = 5.5, Roll = 18, Align = 12, HeadUp = 0, Enter = 1, Shake = 0.3, Strafe = 90 },
		-- (round 90) Light: LIGHTSPEED - Config.DevFlight.Light (set below)
	},
	-- the sonic boom: once each time he passes BoomAt going up (again only
	-- after dropping under BoomRearm); everyone else hears it distance /
	-- SoundSpeed seconds late (1 stud ~ 0.35 m: 980 studs/s is Mach 1)
	BoomAt = 420, BoomRearm = 340, SoundSpeed = 980, BoomRange = 2500, BoomDelayMax = 2.5,
	-- the mach burst: Add on top of his speed (at most Cap) in Rise seconds,
	-- held Hold, back to his tier over Decay; committed (Turn) while it lasts
	Boost = { Add = 460, Cap = 980, Rise = 0.06, Hold = 0.18, Decay = 0.5, Turn = 0.8, Cooldown = 1.2, DoubleTap = 0.3, Fov = 112 },
	-- the braking flip: from MinSpeed up; his speed x e^(-Decay t) for Time s
	Brake = { Time = 0.45, Decay = 9, MinSpeed = 80, Fov = 64, Cooldown = 0.6 },
	-- the take-off: crouched at least Tap s (a tap), charged up to MaxCharge;
	-- launched straight up at Speed (tap .. full charge), easing off at
	-- AscentK over Ascent s into the hover. (round 86 review: harder - a tap
	-- is ~100 studs up in 0.9 s, a full charge ~170, small against the sky;
	-- the full one stays under BoomAt, so the launch and the boom stay apart)
	Takeoff = { Tap = 0.24, MaxCharge = 0.8, Speed = { 240, 400 }, Ascent = 0.9, AscentK = 2 },
	-- the superhero landing: coming down at MinDown+ (steeper than Steep
	-- degrees, or slower than Slow); slower than that it's a soft touchdown
	Land = { MinDown = 30, Steep = 20, Slow = 60, Hold = 0.45, Rise = 0.55 }, -- (round 86 review: Rise 0.4 -> 0.55, the heavier get-up)
	-- the crash: Speed+ coming down steeper than Pitch degrees, or IntoSurface+
	-- straight into it. The crater's Radius grows a stud every PerStud past
	-- Speed; anyone within Radius + KnockReach is knocked off their feet
	-- (Knock: out, up - no damage). Held Hold s in it, then Rise s getting up.
	-- (a crater 3-5 body lengths across: radius 8 at Speed, 13 by ~560)
	Crash = { Speed = 260, IntoSurface = 200, Pitch = 25, Radius = { 8, 13 }, PerStud = 60, Knock = { 92, 46 }, KnockReach = 12, Hold = 0.9, Rise = 0.55, Gap = 1 },
	Skim = 4.5, -- studs over the street a shallow fast pass is held at
	DropWindow = 8, -- s: switched off mid-air, his landing still gets its dust
	-- through buildings: from Speed up, LookAhead = speed x [1] + [2] studs;
	-- the hole's Radius; the speed each wall costs (Loss); at most Rate holes
	-- a second, each at most SegMax studs long (the server clamps them to
	-- where it sees him); walls opened on his screen close again after Reopen s
	Smash = { Speed = 200, LookAhead = { 0.15, 8 }, Radius = { Fast = 4.5, Hyper = 6.5, Boost = 8 }, Loss = { Fast = 0.15, Hyper = 0.06, Boost = 0 }, Rate = 12, SegMax = 36, Reopen = 1, Profile = "FlyThrough" },
	WallHit = { Speed = 200, Bounce = 0.12 }, -- an unbreakable wall at Speed+: stopped dead
	-- people in his way from MinSpeed up: knocked flying out of it (Speed),
	-- each once every Every s
	Ram = { Damage = 0, Speed = { 100, 130 }, Width = 5, MinSpeed = 180, Every = 1 },
	DiveSlam = { Range = 600, Speed = 760, Angle = 45 }, -- no ground in sight: straight down at Angle
	MaxForce = 20000, MaxForceHyper = 40000, -- x his mass
	-- the camera: trails him (LagPerSpeed x speed, at most LagMax studs, on a
	-- spring of LagSpeed), tilts RollPer x his bank, FOV by speed (FovK);
	-- the launch leaves it LaunchLag studs below him and holds its FOV punch
	-- LaunchHold s
	-- (round 90, devfly2: "a smarter camera - less lag at low speed,
	-- cinematic at high speed, never fighting the player": no trail at all
	-- under LagFrom studs/s (the hover and CRUISE sit dead on him), the
	-- spring LagSpeedLow there and LagSpeed at speed; at LIGHTSPEED it
	-- trails up to Light.Lag; Swing: studs it's left behind across a strafe
	-- or a barrel roll (he slides across the frame, then it catches him);
	-- the roll RollPer 0.35 -> 0.3; the hover-lock's own Control.Lock.Fov)
	Camera = { LagSpeed = 9, LagSpeedLow = 16, LagFrom = 100, LagPerSpeed = 0.012, LagMax = 6, LaunchLag = 9, LaunchHold = 0.16, BoostKick = 55, RollPer = 0.3, FovK = 6, Lift = 1, Swing = 0.022, SwingMax = 1.6 },
	Relay = 0.1, -- s between his tier going to the server
	-- (round 86 review) the place streams: at FAST and up the server asks for
	-- the map Ahead s down his path (at most Max studs) every Every s
	Stream = { Enabled = true, Every = 0.5, Ahead = 1, Max = 900, Timeout = 1 },
	-- (round 88) THE CARRY - the flight's 5th move (Omni-Man's grab: "pick
	-- players up and do new moves with them, then back to the old moveset").
	-- While he flies, the move bar is his hero's moves (they still work) plus
	-- GRAB: Z (a controller: click the right stick; a phone: the GRAB
	-- button) takes whoever's in front of him within Reach (+ PerSpeed x his
	-- speed, at most MaxReach) and inside Cone (the dot of his aim and the
	-- way to them) - a player or a training dummy (or someone else's Twice
	-- double), never the raid's Nomu, and by the rules every grab goes by
	-- (god mode, a dodge, Infinity, the UNO table, a finisher, a clash,
	-- already held / holding someone, a stopped clock, a possessed or parked
	-- body, his own double, near the Vestige Realm; taken on the Sky Coffin,
	-- let go on it - never outside its barrier). They hang off his fist,
	-- by the collar, kicking; everyone sees it (the server holds the body).
	-- Holding them, the bar is the carry's moves (Moves: keys / buttons):
	--   SLAM  he dives (steeply, a little ahead) and drives them into the
	--         street: the flight's crash and its crater, Slam.Damage (and
	--         Splash to anyone within SplashRadius), left lying in a crater
	--   THROW swung back over the shoulder and hurled where he's looking at
	--         Throw.Speed (+ Carry of his own speed, at most Max): hard enough
	--         to go through buildings (round 87's through-the-building path)
	--   RAM   flat out (Ram.Speed) along his look (Pitch at most), holding them
	--         out in front: every building on the way smashed through (the
	--         flight's own holes), WallDamage a wall (MaxWalls), and at the end
	--         (Ram.Time, or RAM again) they're flung on (EndPush) - DROP lets
	--         them go with no push
	--   DROP  let go; they fall (some of his speed, at most Drop.Max; from
	--         higher than Drop.Fall they come down limp)
	-- Let go by itself after MaxHold s, if he's hit hard (a push of Push+),
	-- stunned, knocked down or grabbed, and when the flight ends. Then the
	-- bar is the flight's again (and his hero's alone once he's down). Numbers:
	-- like a big move (Hawks' FEATHER CARRY 20, Bakugo's BACKDROP DRIVER 42):
	-- at most 6 + 35 a carry - never a one-shot.
	Carry = {
		Enabled = true,
		Key = Enum.KeyCode.Z, -- GRAB (holding someone: DROP)
		PadKey = Enum.KeyCode.ButtonR3, -- (the emote wheel's - no emotes up here)
		Priority = 3050, -- the keys it takes (over the flight's 3000)
		Gap = 0.35, -- s between two grabs asked for
		ActGap = 0.15, -- s between two of the carry's moves asked for
		Reach = 10, PerSpeed = 0.08, MaxReach = 30, Cone = 0.35,
		GrabDamage = 6,
		-- (owner, after round 88: "take away the time limiter from holding people
		-- while doing the flying") false: no time limit - he holds them till he
		-- drops, throws, rams or slams them, is hit, or the flight ends. A number
		-- puts a limit back (s). SafetyHold: only a net, should anything else fail
		MaxHold = false,
		SafetyHold = 300,
		Push = 40, -- a push on him this hard (studs/s) makes him let go
		-- where they hang, worked out from his poses (anim/moves_carry.py;
		-- r88/scratch_carry/hold_fit.py): his root's space, studs (x his
		-- size). Hover: the collar in his raised fist, out to his right and
		-- in front (so the camera behind him sees them), turned Yaw to face
		-- him; Fly: ahead of his fist, upright, back first (his root's up is
		-- the way he flies); Push: in both fists (the slam's dive, the ram).
		-- Blended from the hover's to flight's as his body lies down (Lean:
		-- the flight's own studs/s over which it does)
		Hold = {
			Hover = Vector3.new(2.5, 0.35, -1.1), Yaw = 114,
			Fly = Vector3.new(1.7, 2.4, -0.66),
			Push = Vector3.new(0, 2.46, -0.75),
			Pivot = Vector3.new(1, 0.5, 0), -- (the right shoulder: the throw swings round it)
			Lean = { 20, 50 },
		},
		-- each move: Act (what goes to the server), its name, its keys (Keys:
		-- the keyboard's and the controller's; Cap / Pad / Touch: what the
		-- bar shows), its colour
		Moves = {
			{ Act = "Slam", Name = "SLAM", Cap = "1", Pad = "RB", Touch = "SLAM", Keys = { Enum.KeyCode.One, Enum.KeyCode.X, Enum.KeyCode.ButtonR1 }, Color = Color3.fromRGB(255, 104, 66) },
			{ Act = "Throw", Name = "THROW", Cap = "2", Pad = "B", Touch = "THROW", Keys = { Enum.KeyCode.Two, Enum.KeyCode.ButtonB }, Color = Color3.fromRGB(255, 196, 70) },
			{ Act = "Ram", Name = "RAM", Cap = "3", Pad = "Y", Touch = "RAM", Keys = { Enum.KeyCode.Three, Enum.KeyCode.Q, Enum.KeyCode.ButtonY }, Color = Color3.fromRGB(110, 214, 255) },
			{ Act = "Drop", Name = "DROP", Cap = "4", Pad = "R3", Touch = "DROP", Keys = { Enum.KeyCode.Four, Enum.KeyCode.Z, Enum.KeyCode.ButtonR3 }, Color = Color3.fromRGB(196, 200, 214) },
		},
		Color = Color3.fromRGB(120, 220, 255), -- GRAB's own (the 5th box, the chip)
		-- SLAM: the dive aimed Ahead studs past straight down; the impact
		-- counts after MinTime s at MinSpeed+ (or within Near studs of the
		-- street); Timeout: no impact by then, he just lets go. Down: s they
		-- lie in it. Crater: the street broken where they hit (always; the
		-- flight's crash makes its own on top at speed)
		Slam = { Ahead = 6, Damage = 26, Splash = 8, SplashRadius = 12, MinTime = 0.1, MinSpeed = 120, Near = 14, Timeout = 2.5, Down = 2.4, Crater = 6.5, Knock = { 70, 36 } },
		-- THROW: swung back WindUp s (the clip's Hit: the let go), Speed
		-- along his look with Lift x it up, plus Carry x his own velocity, at
		-- most Max; the push lasts Time s
		Throw = {
			WindUp = 0.21, Back = 0.15, Swing = 125, Through = -25, Speed = 240, Lift = 0.12, Carry = 0.35, Max = 360, Time = 0.8, Damage = 14,
			-- (round 89) THE LANDING (the owner: "when throwing the opponent as
			-- well make sure they are ragdolled and hit the ground hard"): limp
			-- the whole way (from KeepFrom s on - the throw's own knockdown lasts
			-- that long at least - kept limp every Every s, Keep s at a time,
			-- while they're up; at most MaxTime s; not if they get up by
			-- themselves: the ragdoll cancel), and coming down - the server's own view of
			-- their body: up in the air, then the street within Rest studs (+ a
			-- frame of their fall) under them, at MinSpeed+ studs/s - a hard
			-- landing: Damage[1]..[2] by how fast (MinSpeed..Full), a crater
			-- (Crater[1]..[2] studs, Profile) and dust, bounced back up (Bounce
			-- x the speed, BounceMin..BounceMax studs/s; Slide x it on along the
			-- street), down Down[1]..[2] s longer. Ram: the RAM's fling at the
			-- end lands the same way. (Worst case a carry: 6 + 14 + 28 = 48 of
			-- 300 - never a one-shot.)
			Land = {
				Enabled = true, Ram = true, MinSpeed = 70, Full = 320, Damage = { 6, 28 }, Crater = { 2.6, 4.6 }, Profile = "SmashSplat",
				Bounce = 0.16, BounceMin = 14, BounceMax = 42, Slide = 0.35, Down = { 1.4, 2.4 },
				Keep = 0.7, Every = 0.25, KeepFrom = 0.9, Rest = 3.4, MinTime = 0.1, MaxTime = 5,
			},
		},
		-- RAM: flat out at Speed (reached at Up 1/s), turning after the
		-- camera at Turn 1/s, never pitched more than Pitch degrees; Time s
		Ram = { Speed = 480, Up = 7, Turn = 1.6, Pitch = 20, Time = 1.1, WallDamage = 5, MaxWalls = 5, EndDamage = 10, EndPush = 150, EndLift = 0.12 },
		Drop = { Carry = 0.5, Max = 120, Fall = 10 },
	},
	-- (round 89) THE BOMB (the owner: "when dashing (mach bursting) into the
	-- ground/buildings, the damage increases way more, like a big bomb went
	-- off"): a crash past the sound barrier - the burst (even from a
	-- standstill: +460), HYPERSONIC, the dive slam, the carry's SLAM - isn't
	-- a crater any more, it's a blast. At a speed the server has seen him
	-- reach of Speed+ studs/s (BoomAt: the boom's own; under it, a FAST
	-- crash, it's the crater as before) - and it goes by the speed his
	-- machine says he hit at, never more than Seen x the server's + Slack:
	-- the blast hole Radius[1] at Speed growing to Radius[2] at
	-- Full (studs; its middle Lift x it up off the street - the street, and
	-- the buildings round it, blown out: the Profile); everyone within Reach
	-- x it - by the rules every hit goes by (Kit.DF.canKnock: nobody in god
	-- mode, dodging, held, being finished, a clash, the UNO table...) - hit
	-- for Damage[1]..[2] at the middle (by the speed), falling off to Edge x
	-- that at the reach, never more than MaxShare of their max health (no
	-- one-shot: 90 of 300 at the very most), and thrown off their feet
	-- (Knock: Out / Up studs/s, the same falloff) - one his own flight's ram
	-- knocked down in the last RamGrace s (right where he came down) too:
	-- lying there is no shield from the same hit. Into a building's wall at
	-- the burst (the first one each burst; Gap s apart): the same blast at
	-- the wall, Wall x its size (his machine sees the wall a moment ahead,
	-- as the burst comes up to speed: the server asks its own view of him
	-- again Retries times, Wait s apart, before it says no). Shake: how hard,
	-- and how far off it's felt. Everyone sees the fireball, the shock dome,
	-- the dust wall, the debris, and hears the deepest boom (Config.Sounds
	-- DevFlyBomb, on the round-87 boom's roll and muffle)
	Bomb = {
		Enabled = true,
		Speed = 420, Full = 940, Seen = 1.15, Slack = 40, Retries = 2, Wait = 0.08,
		-- (round 89, in Studio) a burst from a hover hits the street before the
		-- server's seen 420: within BurstWindow s of a burst (Q) any crash at
		-- BurstSpeed+ is the bomb, as big as BurstFloor at least
		BurstWindow = 1.6, BurstSpeed = 150, BurstFloor = 860,
		Radius = { 14, 24 }, Lift = 0.25, Reach = 1.6,
		Damage = { 30, 90 }, Edge = 0.3, MaxShare = 0.3, RamGrace = 0.75,
		Knock = { Out = { 90, 170 }, Up = { 55, 100 } },
		Wall = 0.7, Gap = 1, Profile = "FlightBomb",
		Shake = { 3.4, 420 },
		OwnDust = 14, -- (his own screen: he's in the middle of it - the crash's dust burst no bigger than this, the fireball without its smoke)
		-- (round 89 review) everyone it hits is knocked off their feet - down
		-- Down[1] s at its reach to Down[2] s at its middle. (The push alone
		-- only floored the ones right under him: with the falloff it's under
		-- Config.Ragdoll.MinSpeed for most of the reach - the old crash
		-- floored everyone in its)
		Down = { 1.1, 2.2 },
		-- (round 89 review) many in a row: what one dev's bombs carve out of
		-- the map is held to Rate (Destruction budget) a second, Burst at
		-- once - a bomb carves with what's left (the profile's at most), and
		-- with less than Min left it hurts and shows but doesn't carve (the
		-- holes regrow only after Config.Destruction.RegenTime)
		Carve = { Rate = 350, Burst = 1400, Min = 200 },
	},
	-- (round 89) ALL THE WAY DOWN (the owner: "when doing that to a
	-- building, make sure you go all the way down, same thing for the slam
	-- move"): a crash - anything he comes down on the street as the crash
	-- for: the burst, the dive, the carry's SLAM - onto a building (its roof,
	-- or a floor inside after a wall at a downward angle) doesn't stop there.
	-- Every floor under him with room under it (Drop+ studs) goes, straight
	-- down to the street (at most Depth studs down, MaxFloors floors), at
	-- Speed+ studs/s - and the crash (the bomb) is down there. His machine
	-- opens the floors at once (he never snags; the one he holds goes with
	-- him); the server carves the shaft (Radius, the Profile) down its own
	-- view of the building under where it sees him (only once it's seen him
	-- moving at MinSeen+ studs/s), Gap s apart at most
	-- (Thin / Stuck: a thin part that'll go stuck right under a floor - a
	-- ceiling light, a beam, a stair's next step - goes with it, the room
	-- under it measured past it; Shaft.plan)
	-- ((round 89 review) MaxFloors: a thin part stuck under a floor counts
	-- as one, and a fall down the top of an outside wall meets every band of
	-- it - 16 stopped him half way down the city's 130-stud towers (the real
	-- map, every roof point: 36 at most). Budget: the shaft's carve gets
	-- PerStud x its length, Min..Max - the profile's one budget ran out on
	-- the towers' upper floors and left the lower ones whole (the real map:
	-- 1103 at most, ~8.5 a stud). Beats: his way down shows at most this
	-- many floors giving way, BeatGap+ studs apart)
	Shaft = {
		Enabled = true, Drop = 4, Depth = 260, MaxFloors = 48, Speed = 520, Radius = 7, Profile = "FlyShaft", Gap = 0.6, MinSeen = 60, Thin = 1.2, Stuck = 3,
		Budget = { PerStud = 10, Min = 420, Max = 1500 }, Beats = 12, BeatGap = 6,
	},
}

-- (round 88) THE CARRY's body: where the one he carries is this frame, on
-- every machine the same - his root's CFrame, how fast he goes, what he's
-- doing with them (Hold / Slam / Ram / Throw, t s into it), his size
do
	local C = Config.DevFlight.Carry
	local H = C.Hold
	-- (upright, turned to face him / along the flight: back first, head up)
	local HOVER = CFrame.new(H.Hover) * CFrame.Angles(0, math.rad(H.Yaw), 0)
	local AHEAD = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
	local FLY = CFrame.new(H.Fly) * AHEAD
	local PUSH = CFrame.new(H.Push) * AHEAD
	-- how far his body has gone from upright to lying along his path (the
	-- flight's own blend: DevFly.orient)
	function C.lean(speed)
		local a = math.clamp(((tonumber(speed) or 0) - H.Lean[1]) / (H.Lean[2] - H.Lean[1]), 0, 1)
		return a * a * (3 - 2 * a)
	end
	-- the throw's swing round his shoulder (degrees: + = back over it) t s in
	function C.swing(t)
		local T = C.Throw
		t = tonumber(t) or 0
		if t <= T.Back then
			local a = math.clamp(t / T.Back, 0, 1)
			return T.Swing * (1 - (1 - a) * (1 - a))
		end
		local a = math.clamp((t - T.Back) / math.max(T.WindUp - T.Back, 1e-3), 0, 1)
		return T.Swing + (T.Through - T.Swing) * a * a
	end
	-- their root's CFrame
	function C.at(rootCF, speed, mode, t, scale)
		local a = mode == "Slam" and 1 or C.lean(speed)
		local rel = HOVER:Lerp((mode == "Slam" or mode == "Ram") and PUSH or FLY, a)
		if mode == "Throw" then
			local pivot = CFrame.new(H.Pivot)
			rel = pivot * CFrame.Angles(math.rad(C.swing(t)), 0, 0) * pivot:Inverse() * rel
		end
		scale = tonumber(scale) or 1
		if scale ~= 1 then
			rel = CFrame.new(rel.Position * scale) * rel.Rotation
		end
		return rootCF * rel
	end
	-- driven into the street at `ground`, in front of him (`face`): on their
	-- back across in front of him (the head to his right), his fist in
	-- their chest (MoveCarrySlam's)
	function C.downAt(ground, face)
		local f = Vector3.new(face.X, 0, face.Z)
		f = f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, -1)
		local right = f:Cross(Vector3.new(0, 1, 0)).Unit
		local at = ground + f * 1.9 + right * 0.9 + Vector3.new(0, 0.55, 0)
		return CFrame.lookAt(at, at + Vector3.new(0, 1, 0), right)
	end
end

-- (round 89) FLIGHTBOOM's geometry, the same on every machine (the server's
-- checks, the flyer's own screen, everyone's picture of it): how hard and how
-- big a bomb is at a speed, how much of it reaches someone, and the way down
-- through a building
do
	local D = Config.DevFlight
	local B, S = D.Bomb, D.Shaft
	-- how hard (0..1) a bomb at this speed is, and its blast hole's radius
	function B.power(speed)
		local k = ((tonumber(speed) or 0) - B.Speed) / math.max(B.Full - B.Speed, 1)
		k = (k == k) and math.clamp(k, 0, 1) or 0
		return k, B.Radius[1] + (B.Radius[2] - B.Radius[1]) * k
	end
	-- how much of a blast of radius R reaches someone d studs from its middle
	-- (0..1: all of it at the middle, Edge of it at the reach, none past it)
	function B.falloff(d, R)
		local reach = (tonumber(R) or 0) * B.Reach
		d = tonumber(d) or math.huge
		if d ~= d or reach <= 0 or d > reach then
			return 0
		end
		return B.Edge + (1 - B.Edge) * (1 - d / reach)
	end
	-- a part's top and bottom (world Y, its rotated bounds)
	function S.span(part)
		local cf, s = part.CFrame, part.Size
		local h = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
		return cf.Position.Y + h, cf.Position.Y - h
	end
	-- the way down from `top` (where he came down on it): straight down
	-- through every floor with room under it to the street - the first thing
	-- under him with no room under it (Drop) or nothing under it at all
	-- within Depth (the ground: never on down into the void), or one that
	-- won't break. Anything thin (Thin studs at most) that'll go, stuck right
	-- under a floor - a ceiling light, a beam, the next step of a stair -
	-- goes with it (at most Stuck of them), the room measured past it.
	-- cast(origin, vec) -> the map's hit or nil (a cast that starts inside a
	-- part doesn't see it); breakable(part) -> may it go. { Top, Bottom,
	-- Floors = { { Part, Y } ... }, Street } - or nil: there's no floor to go
	-- through (that's the street he's on)
	function S.plan(top, cast, breakable)
		if typeof(top) ~= "Vector3" or top ~= top then
			return nil
		end
		local floorY = top.Y - S.Depth
		local function down(y)
			if y <= floorY then
				return nil
			end
			return cast(Vector3.new(top.X, y, top.Z), Vector3.new(0, floorY - y, 0))
		end
		local function goes(h)
			return h ~= nil and typeof(h.Instance) == "Instance" and h.Instance:IsA("BasePart") and breakable(h.Instance) == true
		end
		local floors = {}
		local hit = down(top.Y + 0.5)
		if not hit or typeof(hit.Instance) ~= "Instance" then
			return nil -- (nothing under him at all)
		end
		while #floors < S.MaxFloors and goes(hit) do
			local y = hit.Position.Y
			local _, bottom = S.span(hit.Instance)
			local under = down(math.min(bottom, y) - 0.05)
			-- (past anything thin stuck right under it, that goes with it)
			local stuck = {}
			while under and y - under.Position.Y < S.Drop and #stuck < (S.Stuck or 3) and goes(under) do
				local t2, b2 = S.span(under.Instance)
				if t2 - b2 > (S.Thin or 1.2) then
					break
				end
				table.insert(stuck, under)
				under = down(math.min(b2, under.Position.Y) - 0.05)
			end
			if not under or y - under.Position.Y < S.Drop then
				break -- (no room under it, or nothing at all: the street)
			end
			table.insert(floors, { Part = hit.Instance, Y = y })
			for _, s in stuck do
				table.insert(floors, { Part = s.Instance, Y = s.Position.Y })
			end
			hit = under
		end
		if #floors == 0 then
			return nil
		end
		return { Top = top, Bottom = Vector3.new(top.X, hit.Position.Y, top.Z), Floors = floors, Street = hit.Instance }
	end
end

-- (round 90) DEVFLY2 - DEV FLIGHT 2.0. The owner: "make the dev fly a little
-- more controllable, as well as adding another level of speed to it. you can
-- really show off here and be creative". Measured old against new frame by
-- frame (r90/scratch_devfly2/sims.py -> r90/out/devfly2_sims.png); what
-- already felt good (the tiers' speeds, the burst, the brake, the boom, the
-- launch) is as it was.
--   THE CONTROL (Config.DevFlight.Control):
--     Turn - the heading swings round to where he aims at the tier's Turn
--       (1/s) x how far off it is, up to Knee radians: past that it turns no
--       faster - so a big turn swings round at once instead of creeping (the
--       old blend all but stalled a U-turn: 9 s at HYPERSONIC, now ~1 s); a
--       hard turn (From..Full degrees off, from BleedFrom studs/s) is a CARVE:
--       up to Mult x the turn, and it costs Bleed of his speed a second
--     A / D at speed: a STRAFE across his line (each tier's Strafe studs/s,
--       reached at StrafeK 1/s), the heading staying on the camera (SideTurn:
--       how much A / D still bend it - it was 0.45), rolled StrafeBank degrees
--       into it; the bank leans into the turn he asks for (BankIntent degrees
--       a radian off) on top of the one he's making, followed at BankK 1/s
--     Roll - A or D twice quickly (a flick of the stick twice; DoubleTap s):
--       the BARREL ROLL at speed (Dist studs across in Time s, one full turn
--       round his line) or a SIDESTEP in the hover (HoverDist in HoverTime);
--       Cooldown s; a flick counts past Flick, let go under Rest
--     Stop / Hold - let go in the hover and he stops crisp (Stop 1/s), then
--       holds the spot (under Settle studs/s for Still s: pulled back to it
--       at K 1/s, at most Max - no creeping, the breath only for show; moved
--       Lost studs off it by something else, it's let go, never a yank back)
--     Lock - THE HOVER-LOCK: LockKeys while he flies (T / L3 / the phone's
--       LOCK - (round 92) the flight's own, the lock-on's gone): held dead
--       still where he is, his body turned to where he aims (pitched at
--       most Pitch degrees) for precise aim, WASD / Space / C nudging him at
--       Nudge studs/s (NudgeK 1/s), the view Fov; at speed it's the braking flip and the
--       lock at the end of it - one key from any speed to a dead stop. The
--       key again, sprint, the burst or the dive let go
--   Bounds - nothing he does takes him under Floor (studs: the place deletes
--     anything under -500), over Ceiling, or past Radius from Center (turned
--     back in at Turn 1/s); Cushion studs over Floor he's eased level
Config.DevFlight.Control = {
	Turn = { Knee = 1, From = 30, Full = 90, Mult = 1.8, Bleed = 0.9, BleedFrom = 150 },
	SideTurn = 0.18, StrafeK = 8, StrafeBank = 28,
	BankIntent = 30, BankK = 11,
	-- ((round 90 review) Flick 0.7 -> 0.6: W + D held is 0.707 across - a
	-- hair over 0.7, and a pitched, rolled camera's right skews it under, so
	-- the roll with W held came and went)
	Roll = { DoubleTap = 0.3, Flick = 0.6, Rest = 0.3, Dist = 30, Time = 0.36, HoverDist = 18, HoverTime = 0.28, Cooldown = 0.55 },
	Stop = 14,
	Hold = { Settle = 2, Still = 0.2, K = 6, Max = 12, Lost = 25 },
	Lock = { K = 9, Max = 30, Nudge = 12, NudgeK = 10, Pitch = 55, Fov = 62, Lost = 25 },
}
Config.DevFlight.Bounds = { Floor = -340, Cushion = 60, Ceiling = 9000, Center = Vector3.new(5, 25, 888), Radius = 18000, Turn = 1.2 }
-- LIGHTSPEED - the tier over HYPERSONIC. At HYPERSONIC (sprint and W held)
-- the burst key HELD (Q / Y / the phone's DASH - a tap is still the burst)
-- charges the LIGHT BARRIER for Charge s: the burst goes, his body starts to
-- glow and the air round him crackles, the world closes in round the edges
-- of his screen. Full, it BREAKS: a blinding flash, a prismatic shockwave, a
-- second deeper boom with the barrier shattering in it, the camera left
-- behind (Kick studs) - and he's at Speed in Jump s, the view BreakFov,
-- settling to Fov. He stays there while W and sprint are held (Up / Down
-- 1/s; under Rearm he drops back out of it, the light snapping off him), a
-- break every Cooldown s at most. Never while he carries someone. Turn /
-- Bank / Align / Lag / Roll / HeadUp / Strafe / Shake as a tier's; Smash:
-- the hole through a building (no speed lost); Brake: the braking flip from
-- it (longer); Stream: the server asks for the map ahead this often.
-- Look: how it looks - Sheath (the plasma sheath round him: studs), Streak
-- (the light streak everyone else sees: its Life s, Width, the colour
-- fringes Fringe studs off it), Rings (s between the prismatic rings shed
-- on his line), Stars (his own screen's star streaks: how many, their
-- length, how far round his line, how far ahead), Grade (his screen's
-- colour), Break (the shockwave's ring and disc, studs; the shards)
Config.DevFlight.Light = {
	Enabled = true,
	Speed = 1400, Charge = 1.4, Jump = 0.25, Up = 3.2, Down = 1.6, Rearm = 900, Cooldown = 3,
	Turn = 1.8, Bank = 75, Align = 11, Fov = 116, BreakFov = 120, Lag = 8, Roll = 16, HeadUp = 0, Strafe = 0, Shake = 0.35, Kick = 12,
	Smash = { Radius = 8, Loss = 0 },
	Brake = { Time = 0.7, Decay = 7 },
	Stream = { Every = 0.3 },
	-- ((round 90 review) the server's view of him a beat behind his own: the
	-- charge it hasn't seen him fast enough for yet is asked again Times
	-- times, Wait s apart, before it's dropped)
	Retry = { Times = 3, Wait = 0.1 },
	Look = {
		Sheath = { Length = 9, Width = 3.4, Ahead = 1.2 },
		Streak = { Life = 0.45, Width = 1, Fringe = 1.3 },
		Rings = 0.24,
		Stars = { Count = 40, Len = { 40, 90 }, Round = { 12, 70 }, Ahead = { 80, 420 } },
		Grade = { Saturation = 0.22, Contrast = 0.14, Tint = Color3.fromRGB(222, 234, 255), Bloom = 0.7 },
		Break = { Ring = 160, Disc = 180, Shards = 20, Flare = 30 },
	},
}
Config.DevFlight.Tiers.Light = Config.DevFlight.Light -- (a tier like the others: TIERS.Light)

-- (round 87) ADMIN-ABUSE EVENTS: server-wide events a dev fires live and
-- everyone plays - the test menu's Dev only > ADMIN EVENTS... panel, or the
-- console (`event`, `event <name> [seconds] [all]`, `event stop [name|all]
-- [all]`). Who fires them: exactly the dev flight's devs (Kit.DF.allowed:
-- Config.DevFlight.Devs, Console.Owners, the creator / a group's rank 255,
-- Studio's tester); the server checks every request. Each one starts with a
-- full-width banner and a sting on every screen, plays its own music (the
-- MUSIC button mutes it; an ult theme ducks it), shows a countdown chip on
-- the HUD, changes the sky where it fits (Look: each player's own screen),
-- and ends with an EVENT OVER beat. THIS SERVER or ALL SERVERS: ALL SERVERS
-- goes out on MessagingService (Topic) and every running server starts it
-- at once (Studio sends nothing to the live game unless StudioSends).
-- Several run at once (at most MaxRunning) unless they clash (Clash: the
-- new one ends the old). The server owns the state - one workspace
-- attribute (Attribute: Config.ParseAdminEvents reads it) - so late
-- joiners and respawns get it; nothing is saved: an event ends with its
-- server. Durations: the panel's picker (each event's own Duration is its
-- default); MinDuration..MaxDuration seconds.
-- Music: licensed tracks that load in the place (r84/music_catalog.md:
-- Monstercat / APM / DistroKid, each measured there), in at their drop;
-- Volume is the catalog's level x0.6 (a bed under the fight). Only their
-- loading is checked: none has been listened to by ear.
-- Look (the sky, on each screen): Tint / Brightness / Contrast / Saturation
-- (a ColorCorrection of the event's own, stacked), Clock (the time of day),
-- Ambient (Lighting.OutdoorAmbient), Atmo (the Atmosphere's Color / Decay /
-- Density / Haze / Glare), Moon (x the moon's size), Stars (how many). Two
-- events with a Clock, an Ambient or an Atmo: the later one in Order wins.
Config.AdminEvents = {
	Enabled = true,
	Attribute = "AdminEvents", -- (on workspace; AdminEventsSync: Live / Local / Studio)
	Topic = "QuirkAdminEvents", -- (MessagingService: ALL SERVERS)
	StudioSends = false, -- a Studio playtest's ALL SERVERS reaches the live game (off: it stays in Studio)
	MaxRunning = 4,
	Durations = { 60, 120, 180, 300 }, -- the panel's picker (DEFAULT: each event's own)
	MinDuration = 10,
	MaxDuration = 900,
	Gap = 0.3, -- s between two requests from one dev
	-- (round 87 review) a body down, held or being finished when GIANT / TINY
	-- starts or ends is resized once it's up - waiting at most ResizeWait s
	ResizeWait = 15,
	-- (round 87 review) meteors and bills aren't aimed at anyone within this
	-- of the Vestige Realm's Center (One For All's dream, far off the city)
	AwayFromRealm = 600,
	Banner = { Hold = 3.2 }, -- the start banner holds this long (the EVENT OVER one is shorter)
	-- the music: faded in / out (s); under someone's ult theme it ducks to UnderUlt
	Music = { Volume = 1, FadeIn = 1.2, FadeOut = 2.4, UnderUlt = 0.22 },
	Ticks = 5, -- the chip ticks the last Ticks seconds
	Order = { "Meteor", "LowGravity", "Giant", "Tiny", "Shuffle", "MoneyRain", "UltFrenzy", "PlusUltra", "BloodMoon" },
	Clash = { Giant = { "Tiny" }, Tiny = { "Giant" } },
	Events = {
		-- flaming rocks, telegraphed by a red ring Warn s ahead, near people
		-- (within Spread studs of someone; one every Every s, sooner with a
		-- crowd: / clamp(players / 4, 1, Crowd)); in Radius: Damage (middle ..
		-- edge: never a one-shot), knocked Out / Up (middle .. edge: the
		-- middle knocks you down), a Crater (Destruction, Profile)
		Meteor = {
			Name = "METEOR SHOWER", Icon = "☄️", Color = Color3.fromRGB(255, 96, 40),
			Blurb = "Flaming rocks rain on the city. Watch for the red rings!",
			Aliases = { "meteor", "meteors", "shower", "rocks" },
			Duration = 90,
			Music = { Id = "rbxassetid://7024332460", Start = 70.67, Volume = 0.3 }, -- Pegboard Nerds - Shaku (Monstercat, dubstep): the heavy drop
			Look = {
				Tint = Color3.fromRGB(255, 206, 186), Brightness = -0.04, Contrast = 0.1, Clock = 18.1,
				Atmo = { Color = Color3.fromRGB(170, 70, 44), Decay = Color3.fromRGB(120, 34, 22), Density = 0.4, Haze = 2.2, Glare = 0.5 },
			},
			Every = { 0.55, 1.1 }, Crowd = 2.5, Spread = 42, Warn = 1.3, Height = 320,
			Radius = 10, Damage = { 30, 12 }, Out = { 85, 35 }, Up = { 55, 22 }, Crater = 5.5, Profile = "Explosion",
			-- (round 87 review) each screen draws a meteor by how far it lands
			-- from the camera: within Near the whole beat (the ring, the
			-- impact's cracks, rocks, smoke, embers, the glowing chunk); out to
			-- Far the rock and a plain blast; past Far nothing (the sky streaks
			-- fill the distance). A low-end machine: half of each.
			Draw = { Near = 420, Far = 1300 },
		},
		-- workspace.Gravity x Gravity (moon jumps: a 6-stud jump goes 21);
		-- a knock's lift x sqrt(Gravity), its push across x Gravity^0.25: half
		-- again as long in the air, a little farther - never off the map (left
		-- alone, 2.5x as far)
		LowGravity = {
			Name = "LOW GRAVITY", Icon = "🪐", Color = Color3.fromRGB(160, 130, 255),
			Blurb = "Moon jumps for everyone. Every hit floats.",
			Aliases = { "lowgrav", "lowgravity", "gravity", "moon", "space" },
			Duration = 120,
			Music = { Id = "rbxassetid://7028557220", Start = 92.77, Volume = 0.36 }, -- Rogue - Motion (Monstercat, future bass)
			Look = { Tint = Color3.fromRGB(232, 226, 255), Contrast = 0.05, Saturation = -0.04 },
			Gravity = 0.3,
		},
		-- every player's body x Scale (Model:ScaleTo, the game's own Giant toy
		-- path); walk x Walk, jump x Jump (on top of the scale: it feels heavy)
		Giant = {
			Name = "GIANT MODE", Icon = "🦖", Color = Color3.fromRGB(255, 150, 40),
			Blurb = "Everyone twice the size. Every step shakes the street.",
			Aliases = { "giant", "giants", "big", "huge" },
			Duration = 90,
			Music = { Id = "rbxassetid://7028913008", Start = 52.32, Volume = 0.39 }, -- Slippy - Flow (Monstercat, half-time trap)
			Scale = 2, Walk = 1.3, Jump = 1.25,
			Step = { Every = 0.62, Shake = 1, Reach = 70 }, -- a giant's footfall (each screen): every Every s of walking, shaking within Reach
		},
		Tiny = {
			Name = "TINY MODE", Icon = "🐜", Color = Color3.fromRGB(110, 225, 150),
			Blurb = "Everyone pocket-sized. Same punches.",
			Aliases = { "tiny", "small", "mini", "shrink" },
			Duration = 90,
			Music = { Id = "rbxassetid://1836039989", Start = 0, Volume = 0.72 }, -- Bouncy Way (APM)
			Scale = 0.5, Walk = 0.85, Jump = 0.8,
		},
		-- everyone dealt a random PUBLIC hero (not the one they have), First s
		-- in, then every Every s: a slot machine on their screen for Spin s,
		-- then the switch (their ult meter kept). Picking from the phone is
		-- locked meanwhile; at the end everyone gets their own hero back.
		Shuffle = {
			Name = "HERO SHUFFLE", Icon = "🎰", Color = Color3.fromRGB(255, 205, 40),
			Blurb = "Everyone gets a random hero. New ones every 40 s.",
			Aliases = { "shuffle", "random", "heroes", "slots" },
			Duration = 120,
			Music = { Id = "rbxassetid://7024340270", Start = 60.43, Volume = 0.33 }, -- Pegboard Nerds & Tokyo Machine - MOSHI (Monstercat, 8-bit electro house)
			First = 1.8, Every = 40, Spin = 2.6,
			-- (round 87 review) mid-ult (being finished, held...) as a reel lands
			-- or as it ends: switched once that's over, not cut - the deal
			-- waits till the next round, the hand-back at most BackWait s
			BackWait = 90,
		},
		-- Bucks fall from the sky (Every s: PerWave[1] + one a player, at most
		-- PerWave[2], within Spread of someone, Fall s down, lying Life s):
		-- walk within Grab studs to take one (Value each, at most Cap a player
		-- an event; the server checks where you are). Every KO pays x Bucks.
		MoneyRain = {
			Name = "MONEY RAIN", Icon = "💸", Color = Color3.fromRGB(90, 225, 110),
			Blurb = "Grab the falling Bucks! Every KO pays double.",
			Aliases = { "money", "moneyrain", "bucks", "cash", "double" },
			Duration = 90,
			Music = { Id = "rbxassetid://1839367287", Start = 0.16, Volume = 0.69 }, -- Funk Boss (APM)
			Look = { Tint = Color3.fromRGB(255, 246, 218), Contrast = 0.05, Saturation = 0.12 },
			Bucks = 2, Every = 2.2, PerWave = { 2, 8 }, Spread = 34, Fall = 2.4, Life = 14, Value = 1, Cap = 8, Grab = 4.5,
		},
		-- ult meters fill Ult times as fast, everyone's gets Boost at the
		-- start and Trickle a second (not while an ult is up)
		UltFrenzy = {
			Name = "ULT FRENZY", Icon = "⚡", Color = Color3.fromRGB(80, 200, 255),
			Blurb = "Ult meters fill four times as fast. Ults everywhere!",
			Aliases = { "ult", "ults", "frenzy", "ultfrenzy" },
			Duration = 90,
			Music = { Id = "rbxassetid://91258638617904", Start = 30.43, Volume = 0.69 }, -- When The Bass Goes Boom (DistroKid, EDM)
			Look = { Tint = Color3.fromRGB(232, 244, 255), Contrast = 0.06, Saturation = 0.2 },
			Ult = 4, Boost = 30, Trickle = 1.5,
		},
		-- every knock x Knock (Side: across, Up: the lift - judged at its full
		-- force, so more knock people down); a combo's held hits stay short,
		-- and (round 87 review) a raw push - an M1's spacing, an air juggle,
		-- the uppercut, the dash punch - isn't touched: only the M1 chain's
		-- 4th hit sends them
		PlusUltra = {
			Name = "PLUS ULTRA", Icon = "💥", Color = Color3.fromRGB(255, 60, 70),
			Blurb = "Every hit sends them flying. Go beyond!",
			Aliases = { "plusultra", "plus", "knockback", "fly", "launch" },
			Duration = 60,
			Music = { Id = "rbxassetid://5410082346", Start = 59.32, Volume = 0.33 }, -- Hoaprox & Rogue - New World (Monstercat, drumstep)
			Look = { Contrast = 0.1, Saturation = 0.1 },
			Knock = { Side = 2.5, Up = 1.6 },
		},
		-- night, a big red moon, every hit x Damage
		BloodMoon = {
			Name = "BLOOD MOON", Icon = "🩸", Color = Color3.fromRGB(205, 24, 44),
			Blurb = "Night falls red. Every hit does 25% more.",
			Aliases = { "bloodmoon", "blood", "redmoon", "night" },
			Duration = 120,
			Music = { Id = "rbxassetid://95131770144654", Start = 16.67, Volume = 0.54 }, -- AURA = INF (DistroKid, Brazilian phonk)
			Look = {
				Clock = 0, Tint = Color3.fromRGB(255, 168, 168), Brightness = -0.02, Contrast = 0.16, Saturation = -0.12, Moon = 2.6, Stars = 4000,
				Ambient = Color3.fromRGB(118, 44, 54), -- (night, but lit red: everyone can still see who they're fighting)
				Atmo = { Color = Color3.fromRGB(96, 12, 24), Decay = Color3.fromRGB(64, 0, 12), Density = 0.32, Haze = 1.4, Glare = 0 },
			},
			Damage = 1.25,
		},
	},
}

do
	local AE = Config.AdminEvents
	local cache = { text = false, map = {} }
	-- "Meteor=1759450123.40,90,1,Name;Giant=..." -> { [id] = { Ends = server
	-- time, Length = s, Global = bool, By = who } } (known events only)
	function Config.ParseAdminEvents(text)
		local out = {}
		for entry in string.gmatch(type(text) == "string" and text or "", "[^;]+") do
			local id, rest = string.match(entry, "^([%w_]+)=(.*)$")
			if id and AE.Events[id] then
				local ends, len, g, by = string.match(rest, "^([%d%.%-]+),([%d%.]+),([01]),?(.*)$")
				if tonumber(ends) and tonumber(len) then
					out[id] = { Ends = tonumber(ends), Length = tonumber(len), Global = g == "1", By = by ~= "" and by or nil }
				end
			end
		end
		return out
	end
	-- the reverse, in Order (a name keeps letters, digits, _ and spaces)
	function Config.EncodeAdminEvents(map)
		local parts = {}
		for _, id in AE.Order do
			local e = map[id]
			if e then
				local by = string.sub(string.gsub(tostring(e.By or ""), "[^%w_ ]", ""), 1, 20)
				table.insert(parts, string.format("%s=%.2f,%d,%d,%s", id, e.Ends, math.floor((e.Length or 0) + 0.5), e.Global and 1 or 0, by))
			end
		end
		return table.concat(parts, ";")
	end
	-- what's running now (workspace's attribute, cached by its string)
	function Config.AdminEventsRunning()
		local text = workspace:GetAttribute(AE.Attribute or "AdminEvents") or ""
		if cache.text ~= text then
			cache.text = text
			cache.map = Config.ParseAdminEvents(text)
		end
		return cache.map
	end
	-- an event from a word (its id, its name, one of its aliases, or the start of one)
	function Config.FindAdminEvent(word)
		word = string.lower(string.gsub(tostring(word or ""), "[%s_%-]", ""))
		if word == "" then
			return nil
		end
		local starts
		for _, id in AE.Order do
			local def = AE.Events[id]
			local names = { string.lower(id), string.lower(string.gsub(def.Name, "%s", "")) }
			for _, a in def.Aliases or {} do
				table.insert(names, a)
			end
			for _, n in names do
				if n == word then
					return id
				end
				if not starts and string.sub(n, 1, #word) == word then
					starts = id
				end
			end
		end
		return starts
	end
end

-- (round 87) THE DIRECTOR CAMERA: a free camera for trailers, TikToks and
-- thumbnails - for the same people as the dev flight (the server marks them
-- DevFlyer; nobody else gets the key, the menu row or anything else). It
-- all happens on your own screen: nobody else sees anything different, and
-- it sends the server nothing.
--   J (Key) or the test menu's DIRECTOR CAM: on / off. Your body stays where
--   it is and does nothing meanwhile (Roblox's controls off, the game's keys
--   taken). Off gives everything back as it was: the camera (its type,
--   subject, field of view, where it looked), the shift lock and the
--   mouse, the HUD, Roblox's own UI and chat, the name tags,
--   your body and your controls.
-- THE SHOTS: 1 FREE (fly it: WASD, E / Q up and down, hold the right mouse
-- button - or F to latch it - to look, the wheel for speed, Shift fast,
-- Ctrl slow), 2 ORBIT round the target, 3 TRACK (the camera stays where you
-- put it and turns after the target, a beat behind), 4 FOLLOW (a chase cam
-- on a spring behind the target), and the DOLLY: R drops a key where the
-- camera is (where it looks, its zoom, its roll), Enter plays a smooth move
-- through them (L: on a loop), [ / ] how long it takes. A key dropped while
-- the camera is on a target looks at the target when it's played. The
-- target: click a body, or T for the next (players, dummies, Twice's
-- doubles, the raid's Nomu - your own body last).
-- THE LENS: Z / X zoom in and out, , and . the dutch roll, C puts both back;
-- G focus (depth of field on the target - or what's in the middle of the
-- frame), U a colour grade, Y the shake (off / the game's impacts / and a
-- hand-held drift).
-- THE FRAME: the HUD, Roblox's UI, chat, name tags and your own body are
-- off the screen; B a letterbox (2.39:1, then a 9:16 frame for TikTok), I
-- the rule-of-thirds grid, O your own body back, H hides the director's own
-- overlay (and the mouse): the frame is clean for recording.
-- TIME: - / = slow motion (1, 0.5, 0.25, 0.1x, ramped), Space a freeze
-- frame (a still copy of every body near the camera holds the moment while
-- you fly round it). The game's cutscenes: the director's camera wins; 0
-- lets the target's own ult cutscene play on it.
-- A controller: the sticks fly and look, RT / LT up and down, RB / LB fast
-- / slow, X the next shot, A the next target, Y freeze, the D-pad zoom (up /
-- down) and slow motion (left / right), L3 resets the lens, R3 hides the
-- overlay, Select the letterbox; hold B to leave.
Config.Director = {
	Enabled = true,
	Key = Enum.KeyCode.J, -- on / off
	Priority = 3200, -- the keys it takes while it's on (over the free cam's and the flight's 3000)
	Keys = {
		Up = Enum.KeyCode.E, Down = Enum.KeyCode.Q, Fast = Enum.KeyCode.LeftShift, Slow = Enum.KeyCode.LeftControl,
		LookLatch = Enum.KeyCode.F,
		Free = Enum.KeyCode.One, Orbit = Enum.KeyCode.Two, Track = Enum.KeyCode.Three, Follow = Enum.KeyCode.Four,
		NextTarget = Enum.KeyCode.T,
		DollyKey = Enum.KeyCode.R, DollyUndo = Enum.KeyCode.Backspace, DollyPlay = Enum.KeyCode.Return, DollyLoop = Enum.KeyCode.L,
		DollyShorter = Enum.KeyCode.LeftBracket, DollyLonger = Enum.KeyCode.RightBracket,
		ZoomIn = Enum.KeyCode.Z, ZoomOut = Enum.KeyCode.X, RollLeft = Enum.KeyCode.Comma, RollRight = Enum.KeyCode.Period,
		ResetLens = Enum.KeyCode.C,
		Focus = Enum.KeyCode.G, Grade = Enum.KeyCode.U, Shake = Enum.KeyCode.Y,
		Slower = Enum.KeyCode.Minus, Faster = Enum.KeyCode.Equals, Freeze = Enum.KeyCode.Space,
		Letterbox = Enum.KeyCode.B, Grid = Enum.KeyCode.I, Body = Enum.KeyCode.O, Overlay = Enum.KeyCode.H,
		Smooth = Enum.KeyCode.Nine, Cutscenes = Enum.KeyCode.Zero,
	},
	-- a controller (Deadzone: of the sticks; ExitHold: s to hold B to leave)
	Pad = {
		Exit = Enum.KeyCode.ButtonB, ExitHold = 0.6, Fast = Enum.KeyCode.ButtonR1, Slow = Enum.KeyCode.ButtonL1,
		Mode = Enum.KeyCode.ButtonX, Target = Enum.KeyCode.ButtonA, Freeze = Enum.KeyCode.ButtonY,
		ZoomIn = Enum.KeyCode.DPadUp, ZoomOut = Enum.KeyCode.DPadDown, Slower = Enum.KeyCode.DPadLeft, Faster = Enum.KeyCode.DPadRight,
		ResetLens = Enum.KeyCode.ButtonL3, Overlay = Enum.KeyCode.ButtonR3, Letterbox = Enum.KeyCode.ButtonSelect,
		Deadzone = 0.14, Curve = 1.6,
	},
	-- flying it: Speed studs/s to start (Min..Max; each notch of the wheel
	-- x / Step), Fast / Slow while Shift / Ctrl are held
	Fly = { Speed = 24, Min = 1, Max = 800, Step = 1.18, Fast = 4, Slow = 0.25 },
	-- how it moves and turns (1/s: higher is snappier) - 9 cycles them
	Smooth = {
		{ Name = "SMOOTH", Move = 4, Look = 12 },
		{ Name = "CINEMA", Move = 1.6, Look = 4.5 },
		{ Name = "SNAPPY", Move = 10, Look = 30 },
	},
	-- looking: radians a pixel (the mouse) / a second (a stick all the way),
	-- both slower zoomed in (x FOV / 70); never past PitchMax degrees
	Look = { Mouse = 0.0042, Pad = 2.2, PitchMax = 88 },
	-- the lens: Fov to start / C; ZoomRate deg/s (x3 with Shift); RollRate
	-- deg/s, at most RollMax; K: how fast each eases to where it's going
	Lens = { Fov = 70, Min = 6, Max = 110, ZoomRate = 22, ZoomK = 6, RollRate = 30, RollMax = 45, RollK = 6 },
	-- the target: aimed AimY studs over its root; a click takes the body
	-- nearest the pointer within PickAngle degrees; lost for Lost s: free
	Target = { AimY = 1.5, PickAngle = 7, Lost = 1.5, Retarget = 4 },
	-- ORBIT: Radius / Height studs, Speed deg/s round (the wheel: Step a
	-- notch, at most Max either way); W / S in and out (RadiusRate: x e^
	-- a second), E / Q up and down (HeightRate studs/s), A / D round (Turn
	-- deg/s); Look: how fast it turns to the target; Avoid: kept out of walls
	Orbit = { Radius = 14, MinRadius = 3, MaxRadius = 400, Height = 4, Speed = 18, Step = 4, Max = 120, RadiusRate = 0.9, HeightRate = 8, Turn = 70, Look = 10, Avoid = true },
	-- TRACK: Look (1/s) is the lag a camera operator has; Lead s: aimed
	-- that far ahead of where the target's going
	Track = { Look = 3.2, Lead = 0.12 },
	-- FOLLOW: Distance behind, Height, Side; Spring (1/s, the wheel: 1..14)
	-- chases the spot behind (it trails a body running at v by about 2v /
	-- Spring studs: 6 at a run, more at a sprint, and catches up when they
	-- stop); Heading (1/s): how fast it swings behind a turn; LookAhead
	-- studs in front of them
	Follow = { Distance = 16, Height = 5, Side = 0, Spring = 6, MinSpring = 1, MaxSpring = 14, Heading = 3, LookAhead = 3, Look = 8, Avoid = true },
	-- the DOLLY: Time s (x Step with [ ]), at most MaxKeys; eased in and out;
	-- the path is drawn (Dots) while the overlay is up
	Dolly = { Time = 6, MinTime = 1, MaxTime = 120, Step = 1, MaxKeys = 24, Dots = 56 },
	-- G: the depth of field - focus on the target (else the middle of the
	-- frame, up to Auto studs), pulled at K; in focus within Radius x the
	-- distance (MinRadius..)
	Focus = { FarIntensity = 0.45, NearIntensity = 0.7, Radius = 0.12, MinRadius = 1.5, Auto = 400, K = 5 },
	-- U: the colour grades, in order (the last one: none)
	Grades = {
		{ Name = "FILM", Brightness = 0.01, Contrast = 0.12, Saturation = -0.12, Tint = Color3.fromRGB(255, 244, 228) },
		{ Name = "ANIME", Brightness = 0.03, Contrast = 0.16, Saturation = 0.32, Tint = Color3.fromRGB(255, 252, 246) },
		{ Name = "NOIR", Brightness = -0.02, Contrast = 0.38, Saturation = -1, Tint = Color3.fromRGB(255, 255, 255) },
		{ Name = "BLEACH", Brightness = 0.02, Contrast = 0.28, Saturation = -0.5, Tint = Color3.fromRGB(240, 246, 255) },
		{ Name = "DUSK", Brightness = -0.04, Contrast = 0.1, Saturation = -0.06, Tint = Color3.fromRGB(255, 214, 186) },
		{ Name = "MOONLIGHT", Brightness = -0.06, Contrast = 0.14, Saturation = -0.3, Tint = Color3.fromRGB(196, 214, 255) },
	},
	-- Y: the shake - the game's impacts (Gain x, smoothed, on the slowed
	-- clock) and a hand-held drift (degrees / studs, Freq Hz)
	Shake = { Mode = 2, Gain = 0.7, Freq = 16, Hand = { Yaw = 0.35, Pitch = 0.25, Roll = 0.4, Move = 0.05, Freq = 0.45 } },
	-- TIME: the slow motion steps (- / =), eased between at RampK; Sound:
	-- the game's sounds in slow motion (dB off the highs / mids at the
	-- slowest, the pitch dropped to Octave); Freeze: a still copy of every
	-- body within Radius studs of the camera (at most Max)
	Time = {
		Steps = { 1, 0.5, 0.25, 0.1 }, RampK = 7,
		Sound = { High = 22, Mid = 6, Low = 2, Octave = 0.62 },
		Freeze = { Radius = 450, Max = 24 },
	},
	-- B: the frame - Off, Scope (2.39:1 letterbox), Vertical (9:16 for
	-- TikTok, dimmed outside while the overlay's up, black when it isn't)
	Frame = { Modes = { "Off", "Scope", "Vertical" }, Scope = 2.39, Vertical = 9 / 16, Slide = 0.35, Dim = 0.45 },
	-- what stays on the screen: the game's flashes and dims (they're the
	-- fight's), the speech bubbles; the cutscene bars only for a target's
	-- cutscene let through (0)
	KeepGuis = { "QuirkFlash", "QuirkOverlay" },
	CutsceneGui = "QuirkCinema",
	KeepBillboards = { "SpeechBubble" },
	-- the place streams: far from your body, the map round the camera is asked
	-- for (every Every s, From studs away)
	Stream = { Every = 1, From = 300, Timeout = 1 },
	Sounds = true, -- the director's own ticks (only while its overlay is up: never in a recording)
}

-- (round 87) POSSESS: a dev takes over a training dummy or the raid's
-- High-End Nomu - to stage fights for clips, or to play the boss against
-- everyone else. Who: the dev flight's people (Kit.DF.allowed: the owner,
-- Config.Console.Owners, DevFlight.Devs, Studio's tester); the server
-- checks it on every request. K (Key) takes the body you aim at (a dummy,
-- the Nomu, or any model with the Possessable attribute - (round 95) or a
-- PLAYER (Players: the owner, "let me take control of players too like how
-- I can do that to dummies");
-- within AimCone degrees of the aim is enough, out to Range studs), or pick
-- one off the test menu's POSSESS panel. K again (the panel's LEAVE, your
-- reset), the body going down, a new hero or leaving brings you back. Your
-- own body waits where you left it: hidden, anchored, out of every hitbox,
-- earning nothing. The body's AI stops and your machine drives it: walk /
-- run (sprint) / jump, the normal camera and shift lock. A
-- DUMMY punches (M1: the heroes' M1 chain - the same hits, hit reactions
-- and guard rules), guards (F, parries and all) and dashes (Q; Q while it's
-- down: the ragdoll cancel once its meter's full). THE NOMU fights with the
-- raid's own moves: M1 SWIPE, 1 SLAM (it leaps onto where you aim), 2
-- CHARGE, 3 ROAR, on the raid's cooldowns; the raid's clock, health and
-- pay-out still apply. A possessed body's hits credit nobody: no KO, Bucks
-- or ult for anyone (and the dev never earns from the raid he's playing).
-- (round 95) A PLAYER fights as a dummy does (M1, F, Q) plus their own
-- hero's moves - 1 2 3, R and 4, run by the server as theirs (their
-- cooldowns; moves that carry their body across the map on its own
-- screen go off where it stands) - never their ult. Their own keys do
-- nothing meanwhile, their screen says who has them, and they get it back
-- as it was when he leaves (or they reset). Never another dev's parked
-- body, nor someone in a ranked duel.
Config.Possess = {
	Enabled = true,
	Players = true, -- (round 95) players are bodies too
	Key = Enum.KeyCode.K,
	Range = 260, -- studs K reaches
	AimCone = 8, -- degrees: a body this near the aim counts (no pixel hunt)
	Folders = { "Dummies", "NomuRaid" }, -- where bodies live (plus any model with the Possessable attribute)
	-- the wisp from you to the body and back: studs x PerStud s, Min..Max;
	-- Arc: how high it bows (x the distance)
	Travel = { Min = 0.38, Max = 0.85, PerStud = 0.004, Arc = 0.16 },
	Gap = 0.5, -- s between two requests (K mashed)
	ActGap = 0.04, -- s between two of the same move asked of a body (each has its own cooldown too)
	Tell = false, -- a faint tell on a possessed body for everyone else (off: clips stay clean)
	-- the server holds the body while a ragdoll, a grab or an anchor has it,
	-- and hands it back to your machine Regain s after it lets go
	Regain = 0.35,
	-- (a body let go while an anchor has it - the Nomu mid-slam, a stopped
	-- clock: the server takes it back once it's loose, waiting up to this long)
	OwnerWait = 20,
	Dummy = {
		WalkSpeed = 16, RunSpeed = 26, JumpPower = 50,
		BlockWalk = 0.45, -- the walk x this with the guard up
		Dash = { Speed = 64, Time = 0.2, Cooldown = 1 }, -- Q (its M1s are Config.M1's: the heroes' chain)
	},
	Nomu = {
		JumpPower = 58,
		RoarCooldown = 8,
		Reach = 120, -- studs a Slam / Charge may be aimed
		Zoom = 30, -- the camera pulls back this far for a body this big, and stays MinZoom off it
		MinZoom = 20,
	},
	-- each body's keys (the dock under its health bar shows them): Act is
	-- what goes to the server; Slot the hero's key it rides on (M1, Ability1-3,
	-- Block, Dash, Jump); Key / Pad / Touch the cap on each device
	Moves = {
		Dummy = {
			{ Act = "M1", Slot = "M1", Name = "PUNCH", Key = "M1", Pad = "B", Touch = "HIT" },
			{ Act = "Block", Slot = "Block", Name = "GUARD", Key = "F", Pad = "X", Touch = "BLOCK" },
			{ Act = "Dash", Slot = "Dash", Name = "DASH", Key = "Q", Pad = "Y", Touch = "DASH" },
			{ Act = "Jump", Slot = "Jump", Name = "JUMP", Key = "SPACE", Pad = "A", Touch = "JUMP" },
		},
		-- (round 95) a player: a dummy's keys, then their hero's moves (the
		-- client adds those from their hero: Act "Move", Slot Ability1-3 /
		-- Special / Extra - HeroKeys says the caps)
		Player = {
			{ Act = "M1", Slot = "M1", Name = "PUNCH", Key = "M1", Pad = "B", Touch = "HIT" },
			{ Act = "Block", Slot = "Block", Name = "GUARD", Key = "F", Pad = "X", Touch = "BLOCK" },
			{ Act = "Dash", Slot = "Dash", Name = "DASH", Key = "Q", Pad = "Y", Touch = "DASH" },
		},
		HeroKeys = {
			{ Slot = "Ability1", Key = "1", Pad = "LB", Touch = "1" },
			{ Slot = "Ability2", Key = "2", Pad = "LT", Touch = "2" },
			{ Slot = "Ability3", Key = "3", Pad = "RT", Touch = "3" },
			{ Slot = "Special", Key = "R", Pad = "<", Touch = "R" },
			{ Slot = "Extra", Key = "4", Pad = "RB", Touch = "4" },
		},
		Nomu = {
			{ Act = "Swipe", Slot = "M1", Name = "SWIPE", Key = "M1", Pad = "B", Touch = "HIT" },
			{ Act = "Slam", Slot = "Ability1", Name = "SLAM", Key = "1", Pad = "LB", Touch = "1" },
			{ Act = "Charge", Slot = "Ability2", Name = "CHARGE", Key = "2", Pad = "LT", Touch = "2" },
			{ Act = "Roar", Slot = "Ability3", Name = "ROAR", Key = "3", Pad = "RT", Touch = "3" },
		},
	},
	Color = Color3.fromRGB(150, 70, 255), -- the possession's own (the wisp's core, the chip)
}

-- (round 88) COSMETICS A: three signature looks that react to the fight.
-- The pieces are built on the server with the rest of the look
-- (Kit.dekuBoots, Kit.grenadeBracers, Kit.iidaGlasses); every screen makes
-- them react (VFX.CosA) from what already replicates - the moves' effects,
-- BlastFlying, BrokenArmR / BrokenArmL, the Engine kit's bursts and stalls.
-- Pure presentation: nothing here changes a fight. Nothing reacts past Cull
-- studs from the camera or on a look you've hidden (SHOW COSMETICS), and a
-- low-end machine gets half the particles and no lights.
--   DEKU (FullCowl, PrimeDeku): his red high-tops on Mei Hatsume's iron
--   soles (bolted on in yellow). The soles crackle green while he sprints
--   or dashes; his kicks leave glowing green prints where he plants and
--   pushes off (an axe kick: where it lands); after a 100% move the boots
--   smoke and crack for a while.
--   BAKUGO (Explosion): (round 90) the black band between the green on each
--   gauntlet IS his SWEAT bar: it fills amber from the wrist up, drains as
--   he blasts, flashes and glows when full (the grenade pins with it).
--   IIDA (Engine): his lenses glint on every engine burst and fog over when
--   his engines stall, clearing after.
Config.CosmeticsA = {
	Scan = 0.4, -- s between looks for who's wearing what
	Cull = 160, -- studs from the camera
	Deku = {
		Green = Color3.fromRGB(110, 255, 168), -- One For All's green (the crackle, the prints)
		Core = Color3.fromRGB(232, 255, 242), -- ...its white-hot middle
		Seam = Color3.fromRGB(26, 74, 52), -- the soles' seam, quiet (built with the boots)
		-- the soles crackling: on while he's faster than SprintFrom studs/s on
		-- the street (his walk is 22, his sprint 34) or for Dash s after a
		-- dash; Arcs a second crawling along the soles' edges (each lit Arc
		-- s), Sparks a second off each sole, a green light under each (Light
		-- studs, flickering round Bright; not on a low-end machine); Fade s to
		-- die down
		Crackle = { SprintFrom = 27, Ground = 4.2, Dash = 0.4, Arcs = 14, Arc = 0.07, Sparks = 36, Light = 7, Bright = 1.8, Fade = 0.25, Rise = 0.08 },
		-- the prints: lit Hold s, gone by Life (M1Life for a punch-combo
		-- kick's); Size x the iron sole's; at most Max of one Deku's on the
		-- street; Reach: how far over the street a sole can be and still print
		Print = { Hold = 0.35, Life = 2.8, M1Life = 1.5, Size = 1, M1Size = 0.85, Max = 10, Reach = 1.6 },
		-- which effects print, when (s after the effect), how: Plant = the foot
		-- he stands on (Foot: which, else the one not kicking), Push = both feet,
		-- Land = at the effect's Pos (along its Dir), Points = at each of its
		-- Points (Gap apart), and Size
		Prints = {
			StLouisSmash = { { At = 0, How = "Plant", Foot = "Left" }, { At = 0.18, How = "Plant", Foot = "Left" } },
			ManchesterSmash = { { At = 0, How = "Push" } },
			ManchesterLand = { { At = 0, How = "Land", Size = 1.9 } },
			GearshiftRush = { { At = 0.1, How = "Push" } },
			RushBlitz = { { At = 0, How = "Points", Size = 0.9 } },
			FistRain = { { At = 0, How = "Push" }, { At = 0.18, How = "Plant", Foot = "Left" } },
			BlackwhipReelKick = { { At = 0, How = "Plant", Foot = "Left" } },
			PrimeFlashStep = { { At = 0, How = "Push" } },
			FlashChainHit = { { At = 0, How = "Land", Size = 1.1 } },
		},
		-- 100%: the boots smoke and crack for Time s (Cracks on each boot,
		-- glowing green for Glow s; the iron red-hot, cooling over Heat s;
		-- Smoke a second off each boot), all of it gone over the last Fade s.
		-- After these effects (s after) - and whenever his arm breaks
		-- (BrokenArmR / BrokenArmL: 1,000,000% and INFINITE 100%)
		Strain = {
			Time = 9, Glow = 2.4, Heat = 4, Cracks = 4, Smoke = 12, Fade = 1.2,
			Hot = Color3.fromRGB(255, 118, 46), Crack = Color3.fromRGB(30, 6, 8), Smog = Color3.fromRGB(206, 206, 212),
			Moves = { HundredSmashBlast = 0, RushBlitz = 0.6, VestigeDDS = 1.6, GearshiftRush = 0.9 },
		},
	},
	Bakugo = {
		Fill = Color3.fromRGB(255, 146, 34), -- the sweat (nitro: it glows)
		Hot = Color3.fromRGB(255, 240, 190), -- ...flashing as a blast draws on it
		Low = Color3.fromRGB(255, 58, 30), -- ...throbbing red under LowAt
		-- (round 90: 0.18 - where the HUD's SWEAT bar says DRIED UP)
		LowAt = 0.18,
		Ease = 7, -- how fast the level follows (a second)
		Flash = 0.14, -- s each blast lights the band
		-- (round 90) THE BAND: the sweat shows in the black band between the
		-- green segments (Kit.grenadeBracers' SweatFill, under them), rising
		-- from the wrist. Its top edge glows hotter (Level: the SWEAT bar's
		-- bright top) so the level reads in the grooves. Filling up: the edge
		-- runs up the whole band in Sweep s, the band flashes white-hot and
		-- eases back over FullFlash s; full, it breathes up to Charged in
		-- time with the pins
		Level = Color3.fromRGB(255, 236, 120),
		Charged = Color3.fromRGB(255, 196, 84),
		Sweep = 0.22,
		FullFlash = 0.55,
		-- full: the grenade pins glow (a throb every Throb s), a light of
		-- Light studs (not on a low-end machine)
		Pin = Color3.fromRGB(255, 200, 70), Throb = 1.1, Light = 6,
		Ground = 4.2, -- studs under his middle that count as on the street (everyone else's screens follow his sweat)
	},
	Iida = {
		-- a burst (an Engine kit flash at least MinScale): a star off a lens
		-- (Size studs, Life s; not from further behind him than Facing) and the
		-- lens flashing white; no closer together than Gap s
		Glint = { MinScale = 1.2, Gap = 0.3, Size = 1.8, Life = 0.24, Facing = -0.25, Color = Color3.fromRGB(214, 244, 255) },
		-- a stall: the lenses fog over in In s (to Transparency, Color: past
		-- half-fogged they go from glass to a flat white - the anime's blank
		-- lenses - and a flash goes neon), stay the stall's length, clear over
		-- Clear s; Steam wisps a second off them for the first second (never
		-- on your own screen up close)
		Fog = { In = 0.25, Clear = 1.4, Transparency = 0.05, Color = Color3.fromRGB(250, 252, 255), Steam = 10 },
	},
}

-- (round 88) COSMETICS B: three signature looks that move with the fight.
-- Pure presentation - nothing here changes a move. The pieces are built on
-- the server with the look (Kit.gojoBlindfold, Kit.shigarakiHand; Todoroki's
-- scar is the gate for his), and every screen moves them (VFX.CosB) from the
-- beats it already gets. Only while something's happening; half the frost
-- and steam on a low-end machine; hidden with the look (SHOW COSMETICS off,
-- WEAR COSMETICS off, first person); gone with the body, the hero or the ult.
Config.CosmeticsB = {
	-- GOJO (Limitless): in his ult (UNLIMITED VOID) he pushes the blindfold up
	-- onto his forehead - the cloth bunched, tipped back, the knot low at the
	-- back - and the SIX EYES show (JJK ep. 7, the fight with Jogo): bright
	-- sky-blue irises ringed darker, a white catchlight, his white lashes, a
	-- soft blue glow on his face, and a glint off both as they open. When the
	-- ult ends it slides back down over them.
	Gojo = {
		Lift = 0.2, -- studs (x the head's size) the band's middle rides up
		Tilt = 12, -- degrees it tips back (the front up on his forehead)
		Bunch = 0.8, -- its height pushed up (the cloth bunches)
		Loose = 1.03, -- and round (it sits looser up there)
		-- each eye, in the head's size: X / Y its middle on the face, the
		-- dark rim and the bright iris (width, height), the catchlight
		-- (size; Spot: its offset, both eyes lit from the same side), the lash
		Eye = { X = 0.2, Y = 0.1, Rim = { 0.225, 0.245 }, Iris = { 0.17, 0.19 }, Catch = 0.06, Spot = { 0.04, 0.05 }, Lash = { 0.24, 0.035 } },
		RimColor = Color3.fromRGB(24, 92, 196),
		IrisColor = Color3.fromRGB(110, 205, 255),
		LashColor = Color3.fromRGB(242, 246, 255),
		Glow = { Range = 5, Brightness = 1.8, Color = Color3.fromRGB(120, 200, 255) },
		-- on every screen, from the awakening (his hand comes up past his face
		-- in the HandSign): Delay s before the band starts up, LiftTime to get
		-- there (Overshoot past it and back), the eyes opening EyesAt for
		-- EyesIn s, the glint (GlintAt; Size studs, Life s)
		Delay = 0.1,
		LiftTime = 0.28,
		Overshoot = 0.08,
		EyesAt = 0.2,
		EyesIn = 0.16,
		GlintAt = 0.42,
		GlintSize = 2.2,
		GlintLife = 0.5,
		-- and back down at the end: DropTime (it falls), the eyes dimming under it
		DropTime = 0.26,
		EyesOut = 0.18,
		Window = 1.5, -- s a screen waits for the server's new gear before giving up
	},
	-- TODOROKI (HalfCold): his right shoulder frosts over after his ice moves
	-- and his left side steams after his fire moves (canon: too much of one
	-- side and his body freezes or overheats - he evens it out with the
	-- other). Fire on a frosted shoulder melts it off into steam at once.
	Todoroki = {
		Frost = {
			-- s after each move's press that the frost forms (when its ice is out)
			Moves = { IceSpike = 0.14, FrostBurst = 0.16, GlacierBreaker = 0.26, IceSlider = 0.16, GlacialField = 0.22, IceWall = 0.42 },
			Max = 3, -- it builds up: shoulder, then collar and jaw, then his face and hair
			Hold = 3.2, -- s it stays after the last ice move...
			Fade = 1.4, -- ...then thaws away over this long
			Melt = 0.45, -- s to melt off when fire hits it
			Grow = 0.2, -- s a piece takes to crust over
			Glaze = 0.25, -- the thin ice on his skin (1 = clear; the crystals are solid)
			Snow = { 4, 7, 11 }, -- motes falling off it a second, by level
			Mist = { 3, 5, 7 }, -- cold air sinking off it a second, by level
		},
		Steam = {
			Moves = { Flashfire = 0.16, FlamePillar = 0.36, Heatwave = 0.6, JetKindling = 0.42, Phosphor = 0.36, HeatwaveMax = 0.9 },
			Time = 4.5, -- s it steams after the last fire move (thinning out)
			Rate = { Shoulder = 9, Arm = 6, Hair = 6 }, -- puffs a second at the start
			Alpha = 0.58, -- the steam at its thickest (1 = clear): faint
			Size = { 0.5, 2.2 }, -- studs, as it rises
			Rise = 2.4, -- studs a second
			Puff = 3, -- a first breath of it off each spot
		},
	},
	-- SHIGARAKI (Decay): while he charges a Decay the hand on his face
	-- ("Father") clenches into a claw - the knuckles up off his face, the
	-- tips digging in, trembling - greying toward ash at the fingertips with
	-- dust crumbling off it (the hand he'll decay one day); as the move goes
	-- off it springs open and settles back.
	Shigaraki = {
		-- each move's charge, s from the press to its release (the moves' own
		-- beats; a move's Windup is used where it has one)
		Charge = { DecayWave = 0.22, Sinkhole = 0.35, DecayGrasp = 0.2, Collapse = 0.5, RivetStab = 0.2, RadioWaves = 0.45, RivetStorm = 0.3, TotalDecay = 1.3, Awaken = 0.6 },
		In = 0.08, -- s into the claw
		Settle = 0.34, -- s springing open and back after the release
		Curl = 28, -- degrees each finger lifts at the knuckle
		Claw = -50, -- ...and the tip bends back in at the middle joint
		Thumb = 0.6, -- the thumb does this much of it
		Tremble = 3.5, -- degrees it shakes while it's held
		TrembleHz = 16,
		Ash = 0.45, -- how far the fingertips grey toward ash (the knuckles half that)
		Dust = 22, -- dust a second off the hand while it's held
		Flakes = 8, -- flakes off it when it springs open
	},
}

---------------------------------------------------------------------------
-- Bucks + the shop (H, the SHOP button, or Select on a controller)
---------------------------------------------------------------------------
-- Every KO pays out (round 60: one Buck a KO); spend it on items. Items go in your bag (up to
-- MaxKinds different ones) and are used with 5/6/7/8, D-pad right, or by
-- tapping them on the item bar. Bucks and your bag are saved between
-- sessions (a live game needs API access; in Studio turn on "Enable Studio
-- Access to API Services" to test saving).

Config.Economy = {
	Currency = "Bucks",
	PerKO = 1, -- knocking out a player (round 60: every KO is one Buck)
	PerDummyKO = 1, -- practice pays a little
	StartingBucks = 10, -- a new player can buy two things straight away
	MaxKinds = 4, -- different items you can carry at once
	MaxStack = 9, -- of any one item
	UseCooldown = 0.5, -- between item uses
	SaveData = true,
	DataStore = "QuirkBattlegrounds_Bucks_v1",
	AutoSave = 90, -- seconds
}

-- Icon: an emoji (shows on the shop cards and the item bar)
-- Gives: how many of it one purchase puts in your bag
Config.Items = {
	Soda = {
		Name = "POP SODA", Icon = "🥤", Price = 5, Gives = 1, Color = Color3.fromRGB(70, 200, 255),
		Info = "Crack it open, chug it: +40 health.",
		Heal = 40,
	},
	Sniper = {
		Name = "HERO SNIPER", Icon = "🎯", Price = 5, Gives = 3, Color = Color3.fromRGB(150, 160, 180),
		Info = "3 shots. Use it to scope in, then click / RT / tap to fire. Use again to put it away.",
		Damage = 35, Range = 450, FireRate = 0.9, ScopeFov = 18, HeadshotBonus = 1.5,
	},
	Bomb = {
		Name = "BAKU-BOMB", Icon = "💣", Price = 5, Gives = 1, Color = Color3.fromRGB(255, 132, 36),
		Info = "Lob it where you aim. It sticks where it lands and blows a hole in the street.",
		Damage = 32, Radius = 16, ThrowSpeed = 85, Fuse = 0.7, MaxFlight = 2.5,
	},
	AllMightHair = {
		Name = "ALL MIGHT HAIR", Icon = "💪", Price = 5, Gives = 1, Color = Color3.fromRGB(255, 212, 64),
		Info = "Wear the legendary bangs. Use: ONE Detroit Smash that clears the street, then poof.",
		Damage = 45, Range = 110, Width = 30,
	},
	Trigger = {
		Name = "TRIGGER", Icon = "💉", Price = 5, Gives = 1, Color = Color3.fromRGB(235, 50, 70),
		Info = "Quirk booster: +25% damage and +20% speed for 10 seconds.",
		Duration = 10, DamageBoost = 1.25, SpeedBoost = 1.2,
	},
	CaptureScarf = {
		Name = "CAPTURE SCARF", Icon = "🧣", Price = 5, Gives = 1, Color = Color3.fromRGB(200, 200, 190),
		Info = "Aizawa's scarf: snag the first enemy in line, reel them in and ERASE their quirk for 5s.",
		Range = 55, Stun = 1.4, Erase = 5,
	},
	GrapeBalls = {
		Name = "GRAPE BALLS", Icon = "🍇", Price = 5, Gives = 3, Color = Color3.fromRGB(150, 70, 200),
		Info = "Mineta's sticky balls. Drop one: whoever steps on it is stuck for 2 seconds.",
		Root = 2.2, Life = 20, MaxOut = 6,
	},
	ZeroGravity = {
		Name = "ZERO GRAVITY", Icon = "🪐", Price = 5, Gives = 1, Color = Color3.fromRGB(255, 150, 190),
		Info = "Uraraka's touch on yourself: moon jumps and floaty falls for 10 seconds.",
		Duration = 10, Gravity = 0.25,
	},
	-- food: not in the Hero Shop. The snack machines and Tony's counter sell
	-- these (Sound: the cue that plays while you eat it)
	Chips = {
		Name = "POTATO CHIPS", Icon = "🥔", Price = 3, Gives = 1, Color = Color3.fromRGB(240, 190, 60),
		Info = "Salty, crunchy: +25 health.", Heal = 25, Sound = "Crunch",
	},
	CandyBar = {
		Name = "CHOCO BAR", Icon = "🍫", Price = 3, Gives = 1, Color = Color3.fromRGB(120, 70, 40),
		Info = "Pure sugar: +30 health.", Heal = 30, Sound = "Munch",
	},
	PizzaSlice = {
		Name = "PIZZA SLICE", Icon = "🍕", Price = 5, Gives = 1, Color = Color3.fromRGB(235, 120, 50),
		Info = "Tony's classic pepperoni: +60 health.", Heal = 60, Sound = "Munch",
	},
	GarlicKnots = {
		Name = "GARLIC KNOTS", Icon = "🥖", Price = 5, Gives = 3, Color = Color3.fromRGB(220, 180, 110),
		Info = "Three knots, +20 health each.", Heal = 20, Sound = "Munch",
	},
	WholePizza = {
		Name = "WHOLE PIZZA", Icon = "📦", Price = 12, Gives = 1, Color = Color3.fromRGB(200, 60, 40),
		Info = "The whole pie in one sitting: back to full health.", Heal = 999, Sound = "Feast",
	},
}
-- the Hero Shop's shelf
Config.ShopOrder = { "Soda", "Sniper", "Bomb", "AllMightHair", "Trigger", "CaptureScarf", "GrapeBalls", "ZeroGravity" }
-- every item (the bag, saving)
Config.ItemOrder = {
	"Soda", "Sniper", "Bomb", "AllMightHair", "Trigger", "CaptureScarf", "GrapeBalls", "ZeroGravity",
	"Chips", "CandyBar", "PizzaSlice", "GarlicKnots", "WholePizza",
}

---------------------------------------------------------------------------
-- Food around the city
---------------------------------------------------------------------------

-- Snack machines on the sidewalks. E (D-pad right, or tap the prompt) buys
-- a random snack for your bag (eaten on the spot if your bag is full).
-- Punch one and, like JJS's vending machines, a free snack rattles out onto
-- the pavement: whoever grabs it first eats it. Then it has to restock.
-- Spots: where each machine stands (on the ground) and which way it faces.
Config.SnackMachine = {
	Price = 3,
	Snacks = { "Chips", "CandyBar", "Soda" },
	Restock = 30, -- seconds before a punched machine drops another free snack
	PickupLife = 20, -- a free snack nobody grabs is gone after this long
	Spots = {
		{ Position = Vector3.new(-85.2, 26.7, 546.4), Face = Vector3.new(1, 0, 0) }, -- outside Tony's
		{ Position = Vector3.new(-58.5, 26.7, 567.2), Face = Vector3.new(-1, 0, 0) },
		{ Position = Vector3.new(-27.3, 26.7, 635.1), Face = Vector3.new(0, 0, 1) },
		{ Position = Vector3.new(107.6, 26.7, 612.2), Face = Vector3.new(-1, 0, 0) },
		{ Position = Vector3.new(-99.5, 26.7, 689.0), Face = Vector3.new(0, 0, 1) }, -- by the training dummies
		{ Position = Vector3.new(-120.9, 26.7, 768.9), Face = Vector3.new(1, 0, 0) },
		{ Position = Vector3.new(50.0, 27.26, 900.2), Face = Vector3.new(-1, 0, 0) },
		{ Position = Vector3.new(267.0, 26.7, 955.8), Face = Vector3.new(-1, 0, 0) },
		{ Position = Vector3.new(193.1, 26.7, 745.6), Face = Vector3.new(1, 0, 0) },
		{ Position = Vector3.new(-236.9, 26.24, 583.7), Face = Vector3.new(0, 0, -1) },
		{ Position = Vector3.new(-316.7, 26.24, 558.1), Face = Vector3.new(0, 0, 1) },
		{ Position = Vector3.new(-101.2, 26.7, 1211.7), Face = Vector3.new(-1, 0, 0) },
		{ Position = Vector3.new(-239.2, 26.7, 1233.4), Face = Vector3.new(1, 0, 0) },
	},
}

-- Tony's Pizzeria: the diner ("The Thing Where You Can Eat") gets a cook
-- behind the register. Walk up and talk to him (E / D-pad right) to order.
-- Food goes in your bag (eaten on the spot if it's full).
Config.PizzaParlor = {
	Enabled = true,
	Name = "TONY'S PIZZERIA",
	Cook = "Tony",
	Position = Vector3.new(-126, 26.65, 536.3), -- his feet, behind the counter
	Face = Vector3.new(0, 0, 1), -- towards the customers
	SignPosition = Vector3.new(-128, 37, 538.4), -- the sign hanging over the counter
	PizzaOnCounter = Vector3.new(-121.5, 30, 540),
	TalkRange = 14,
	Menu = { "PizzaSlice", "GarlicKnots", "WholePizza", "Soda" },
	Greetings = {
		"Ay, a hero! What'll it be?",
		"Welcome to Tony's! Plus Ultra portions!",
		"You look like you took a Detroit Smash to the face. Pizza?",
		"No quirks behind the counter, capisce?",
		"Fresh outta the oven, hot as Endeavor!",
	},
	Thanks = {
		"One slice, comin' right up!",
		"Mangia! Now go save the city!",
		"That'll put some All Might in ya!",
		"Enjoy! Tell your friends at U.A.!",
		"Hot and fresh, like Bakugo's temper!",
	},
	Broke = "No Bucks, no pizza! Go knock somebody out and come back.",
}

-- UNO at Tony's: every table in the pizzeria (within Range of Tony) gets
-- seats - walk up, "Play UNO" - and when 2 to MaxPlayers are sat at one a
-- game deals in (AutoStart seconds, or START). Standard rules: match the
-- colour or the number/symbol, Skip, Reverse, Draw Two, Wild, Wild Draw
-- Four; nothing to play - draw one (play it if it fits, or pass). Call UNO
-- on your last card or anyone can CATCH you (you draw CatchPenalty).
-- TurnTime seconds a turn (then you draw and pass). First out wins
-- WinBucks. Seated players can't fight and can't be hit.
Config.Uno = {
	Enabled = true,
	Range = 110, -- studs from Tony: which tables are the pizzeria's
	SeatRange = 9, -- a seat this close to a table belongs to it
	MaxPlayers = 4,
	HandSize = 7,
	TurnTime = 20,
	AutoStart = 10,
	NextRound = 8, -- seconds after a win before the next deal
	CatchPenalty = 2,
	WinBucks = 25,
}

-- (round 89) JOIN THE DISCORD: a kiosk on the plaza by the middle spawn (a
-- blurple totem, a glowing sign on top and a chat bubble over it), built by
-- the server at startup in workspace.Shops like the snack machines: attacks
-- pass through it, the city's destruction and its rebuild never touch it,
-- and one that's gone (anything clearing it away) is built again. Walk up
-- and press E (D-pad right, or tap the prompt): a card with the invite to
-- select and copy (Ctrl+C) - Roblox can't open links, so nothing's
-- clickable, and nothing is sent anywhere.
-- ROBLOX POLICY: only a player Roblox allows Discord links for (PolicyService:
-- GetPolicyInfoForPlayerAsync's AllowedExternalLinkReferences lists
-- "Discord", asked on their own screen) ever sees the Allowed words - the
-- invite, or the word Discord on the sign, the screen, the prompt or the
-- card. Everyone else, and anyone whose check fails, sees the Neutral ones.
-- The server builds everything in the Neutral words; a screen that's allowed
-- swaps its own copy.
-- Spots: where each kiosk stands (its feet; a ray finds the street's exact
-- height within Snap studs) and which way it faces.
Config.Discord = {
	Enabled = true,
	Invite = "discord.gg/ZUACwx6S3", -- (also what the kiosk's screen shows, to those allowed)
	Spots = {
		-- the middle spawn's crossing, its north-east corner (14 studs from the
		-- spawn, back to the hedge's corner, the lanes left 17+ studs wide),
		-- turned to face the spawn: the first thing on your right as you spawn
		{ Position = Vector3.new(-60.2, 26.07, 877.2), Face = Vector3.new(-1, 0, 1) },
	},
	Snap = 4,
	PromptRange = 7, -- (short: E is also the finisher's key, and this is where people fight)
	PressGap = 0.5, -- seconds: one card per press, however the prompt fired
	CloseRange = 22, -- walk this far from the kiosk and the card closes
	Rebuild = 5, -- seconds between checks that every kiosk's still there
	AskWait = 3, -- seconds the card waits for Roblox's answer if it hasn't come yet
	Retry = { Times = 2, Every = 10 }, -- the policy ask failed: asked again (until then: neutral)
	Pulse = 1.6, -- seconds: the sign's glow breathing in, and the same back out
	Look = {
		Blurple = Color3.fromRGB(88, 101, 242), -- #5865F2: the body, the card's accent
		Deep = Color3.fromRGB(71, 82, 196), -- the fins, the neck
		Ink = Color3.fromRGB(30, 31, 34), -- the sign's face, the screen
		Slab = Color3.fromRGB(43, 45, 49), -- the plinth, the bezel, the shelf
		Glow = Color3.fromRGB(150, 160, 255), -- the neon frame and strip
		Bubble = Color3.fromRGB(245, 246, 255),
		Plinth = Vector3.new(6.4, 0.5, 3.6),
		Body = Vector3.new(4.6, 7, 2.4),
		Sign = Vector3.new(8.4, 3.4, 1),
		Neck = 0.6, -- between the body and the sign
		Frame = 0.25, -- the neon frame round the sign
		ScreenAt = 4.2, -- the screen's middle, above the plinth
		Neon = { 0, 0.45 }, -- the frame's transparency as it breathes (bright, dim)
		Light = { Range = 16, Brightness = { 2.2, 0.9 } }, -- the sign's light (bright, dim)
		TextGlow = 1.6, -- the signs' brightness (lit, at night too)
		PixelsPerStud = 50,
	},
	-- Roles: SignTop / SignMain (the sign, both faces), ScreenTop / ScreenMain /
	-- ScreenBottom (the screen), Action / Object (the prompt), Title / Line
	-- (the card). The Allowed screen's middle line is the Invite.
	Allowed = {
		SignTop = "JOIN THE",
		SignMain = "DISCORD",
		ScreenTop = "OUR DISCORD",
		ScreenBottom = "walk up to copy the invite",
		Action = "Join the Discord",
		Object = "Community",
		Title = "JOIN THE DISCORD",
		Line = "Copy the invite, then paste it into Discord or your browser.",
		-- (under the invite, for the device you're on; Selected: once it's selected)
		Hint = {
			Keyboard = "Click the invite to select it, then press Ctrl+C (Cmd+C on a Mac)",
			Touch = "Tap the invite, select it and Copy - or take a screenshot",
			Gamepad = "Type it into Discord on your phone or computer",
		},
		Selected = {
			Keyboard = "Selected - now press Ctrl+C (Cmd+C on a Mac)",
			Touch = "Now tap Copy",
			Gamepad = "Type it into Discord on your phone or computer",
		},
	},
	Neutral = {
		SignTop = "JOIN OUR",
		SignMain = "COMMUNITY",
		ScreenTop = "COMMUNITY",
		ScreenMain = "see the game page",
		ScreenBottom = "walk up for more",
		Action = "Join our community",
		Object = "Community",
		Title = "OUR COMMUNITY",
		Line = "Join our community - see the game page",
	},
}

---------------------------------------------------------------------------
-- (round 92) tweaks - PLUME CYCLONE WITHOUT A HITBOX (the owner: "make plume
-- cyclone hitbox not visible to other players"). Hawks' cyclone (3, and the
-- ult's CYCLONE: TEMPEST) used to stand two ForceField cylinders round him -
-- the "wind sheets", 0.9 and 0.62 x the shred Radius, 9 and 7 studs tall -
-- and lay a ForceField disc on the street 1.1 x the Radius, on every screen:
-- a translucent column the size of the hit, i.e. a hitbox. They're gone,
-- on every screen. Its wind is wind now:
--   Wind - Arcs (LowArcs on a low-end machine) thin ribbons of air whipping
--     round him: each an arc Span radians long, at RadiusMin..RadiusMax x the
--     move's Radius and HeightMin..HeightMax studs off his middle, climbing
--     Climb studs along itself and Rise over its life (Life seconds, a
--     random one between the two), turning Spin rad/s (every Reverse-th one
--     the other way), Width studs at its widest, fading in and out with its
--     life (Opacity at its best) - then it's back somewhere else, so nothing
--     ever stands there as a shape. Emission: its LightEmission.
--   Reach - on HIS screen only (a held move's marker, as the Vanishing Act's
--     and the nuke's are): a faint dashed ring at the Radius on the street
--     (Lift over it; in the air, AirDrop under his middle) - Dashes dashes
--     Fill of the way round, Thickness studs, Transparency, turning Spin
--     rad/s, in over FadeIn s. On = false: none.
--   RainDisc - SCARLET RAIN's red disc on the street (its whole area, the same
--     kind of hitbox): "Caster" his screen only, false nobody's, "All" as it
--     was. Everyone else sees the blades gather overhead and come down, and
--     the ring flash.
Config.CycloneLook = {
	Wind = {
		Arcs = 6, LowArcs = 3, Span = 1.35, RadiusMin = 0.5, RadiusMax = 1.05, HeightMin = -1.8, HeightMax = 3.6,
		Climb = 1.2, Rise = 1.4, Life = { 0.42, 0.72 }, Spin = 7.5, Reverse = 3, Width = 0.6, Opacity = 0.55,
		Emission = 0.55, Color = { Color3.fromRGB(255, 252, 248), Color3.fromRGB(255, 196, 188) },
	},
	Reach = {
		On = true, Dashes = 24, Fill = 0.5, Thickness = 0.16, Transparency = 0.55, Color = Color3.fromRGB(255, 120, 110),
		Spin = 0.6, Lift = 0.12, AirDrop = 0.5, FadeIn = 0.2,
	},
	RainDisc = "Caster",
}

---------------------------------------------------------------------------
-- (round 92) LIGHTWIPE - LIGHTSPEED INTO THE GROUND: THE END OF THE MAP. The
-- owner: "if you do lightspeed into the ground, way bigger destruction.
-- whole map gone." A dev who crashes at LIGHTSPEED (Config.DevFlight.Light -
-- the only way past the burst's 980) into the street, or down onto a
-- building, doesn't make the bomb (Config.DevFlight.Bomb): he ends the map.
-- A blinding impact and a pillar of light, a shock dome racing out from the
-- crater over the whole city, every building ripped up and flung straight
-- out from it, the sky going to ash, a mushroom of dust climbing over him, a
-- huge sound, every screen shaking - then the empty plain, and the city
-- flying back together. The Serious Punch's engine (VFX.ST.World) run as a
-- blast from a point (Config.LightWave). Server: Kit.LW (DF.land asks it
-- first); his machine: DevFly.LW; every screen: VFX.LWX.
--   Speed: his machine's speed at the crash, studs/s (LIGHTSPEED is 1400;
--     the burst tops out at 980 and the dive at 760: nothing else gets here)
--   MinSeen: the server's own view of him (its peak - over the burst's
--     cap), asked again Retry.Times times, Retry.Wait s apart, before it's
--     the bomb after all (round 89's lesson: his machine meets the street
--     before the server's view of him has caught up)
--   Cooldown: s - once a server, whoever flies (the map's everyone's);
--     inside it a crash at LIGHTSPEED is the bomb, as ever
--   Drop: the city's street must be under where he hit within this many
--     studs (a roof - the city's tallest are ~130 up - is; the Sky Coffin's
--     floor, 1600 up, isn't the map: the bomb there). Coming down on a
--     building he's put down on the street under it: it's gone anyway
--   Hold: s he stays down in the crater (the crash's own is 1.45)
--   Wave: the shock front out of the crater - one law for the server (who's
--     hit, when) and every screen (what goes, when): Reach studs at Time s
--     (+ Delay), r = Reach x (t / Time) ^ Power: explosive at first, slowing
--     as it spreads, as a blast wave does (the middle of the city to its
--     corners, ~620 studs: 1 s; one corner to the other, ~1250: 2.5 s)
--   THE HITS (the server, each as the wave gets to them): everyone within
--     Radius studs (flat) of the crater, from Below under it to Above over
--     it (not the Sky Coffin up at 1600, not the Vestige Realm), by the
--     rules every hit goes by (Kit.DF.canKnock: god mode, a dodge, a grab, a
--     finisher, a clash, the UNO table, his own double... - lying down is no
--     shield): Damage.Near within Damage.Full studs, falling off to
--     Damage.Far at Wave.Reach (Curve: how fast), never more than MaxShare
--     of their max health - nobody's one-shot; thrown straight out from it
--     (Push / Lift: Near -> Far, over PushTime s) but never off the edge of
--     the city (Kit.ST.keepOn: Edge studs inside it), off their feet Down s
--     (Near -> Far). Never him.
--   THE REAL MAP (the server's - (round 94) put back with every screen's
--     rewind: Kit.wipeRebuild, halfway through the empty plain and as the
--     rewind ends; it used to wait out Destruction's 40 s and the city came
--     back with the furrows still through it):
--     the Crater at the impact (studs: the Profile, its own CraterBudget)
--     and Furrows torn straight out from it (FurrowLength studs from
--     FurrowStart, FurrowRadius, each its FurrowBudget, carved as the wave
--     gets there; the street itself is left) - the Serious Punch's crater-
--     and-trench budget, no more
--   World: every screen's city (VFX.ST.World: Config.Saitama.Wipe's
--     numbers, these on top). Speed / Up: each piece's flight straight out
--     from the crater - Near at it, Far from Fade studs on. Hold s of empty
--     plain, then the rewind (RewindSpan, RewindTime). PrimeHold: s a screen
--     keeps the city it read ahead (someone broke the light barrier: the
--     crash could come any moment - read a little a frame, ScanBudget, not
--     all at once at the impact). The dust wall (Wall), the scorch marks
--     (Scour), the grade (Grade: the impact's white-out - Windup - then ash),
--     the sky (Sky: ash clouds rolling in over Time s; no vortex), how it
--     feels where you are (Hit, Fov, Flash), seen from Range studs
--   Look (VFX.LWX; half as much on a low-end machine): Flash - the white-out
--     clearing (s: his own, the nearest, the farthest); Pillar - the column
--     of light up out of the crater (Height, Radius from -> to, Life s);
--     Fireball (studs across from -> to in Rise s, gone in Life s); Prism -
--     the colour rings racing out over the street (studs, Life s); Dome - the
--     shock dome riding the front (its transparency at the crater -> at its
--     biggest: a part's 2048 studs - faded out by then); Front - the ring of
--     light at its foot (Segments, Low); Mushroom - the cloud over the
--     crater: its cap (a ring of rolling puffs, a crown over it) climbing to
--     Height (Rise s to most of it, then Drift x Height a second), spreading
--     to Width across, Stem puffs up it, Cap round it, and a Collar of
--     condensation round the stem part way up (Low*: a low-end machine's),
--     Glow s of fire in it; held over the empty plain, sucked back down into
--     the crater with the rewind. Shake: the impact (how hard, felt how
--     far, s); Rumble: the cloud going up, near it. Title: everyone else
--     told who; Cinematic: his own camera pulled up over the city as it goes
Config.DevFlight.LightWipe = {
	Enabled = true,
	Speed = 1100,
	MinSeen = 1000, Retry = { Times = 3, Wait = 0.1 },
	Cooldown = 30,
	Drop = 220,
	-- ((round 92 review) the server puts the crater on the city's street
	-- straight under where it has the crash, looking at most Snap studs
	-- down: its view of him is a beat behind at 1400 studs/s - over the
	-- roof he came down on, or up in the air)
	Snap = 600,
	Hold = 2.2,
	LateWait = 1.5, -- (s after a screen loads before it looks for one going on: the map streams in first)
	Wave = { Reach = 1300, Time = 2.6, Power = 0.72, Delay = 0.05 },
	Radius = 1800, Above = 320, Below = 140,
	Damage = { Near = 70, Far = 14, Full = 40, Curve = 2 }, MaxShare = 0.3,
	Push = { Near = 260, Far = 110 }, Lift = { Near = 140, Far = 70 }, PushTime = 0.35, Edge = 40,
	Down = { Near = 2.8, Far = 1.8 },
	Crater = 34, Profile = "LightWipe", CraterBudget = 1100,
	Furrows = 6, FurrowStart = 30, FurrowLength = 240, FurrowRadius = 14, FurrowBudget = 210, FurrowProfile = "SeriousPunch",
	World = {
		Speed = { Near = 1150, Far = 360, Fade = 1300 }, SpeedJitter = 0.25,
		Up = { Near = 280, Far = 70 },
		Hold = 8, RewindSpan = 1.6, RewindTime = 1.6, MaxTime = 32,
		ScanBudget = 600, PrimeHold = 40,
		-- ((round 92 review) a screen reads the city ahead from a point on its
		-- street: under where the light barrier broke, this camera or this
		-- screen's body - looking at most PrimeDepth studs down)
		PrimeDepth = 4000,
		Wall = { Segments = 56, LowSegments = 28, Height = 12, Size = { 26, 90 }, Reach = 1600 },
		Scour = { Count = 40, LowCount = 18, Length = { 120, 520 }, Width = { 8, 26 } },
		Grade = {
			Windup = { Brightness = 0.55, Contrast = 0.35, Saturation = -0.6, Tint = Color3.fromRGB(240, 246, 255) }, -- (the white-out: the engine's own, the punch's)
			After = { Brightness = -0.07, Contrast = 0.2, Saturation = -0.38, Tint = Color3.fromRGB(255, 214, 178) },
			AfterDelay = 0.05, AfterTime = 0.6, -- (the white-out clears faster than the punch's: the blast's to be seen)
			SunRays = { Intensity = 0.22, Spread = 0.9 },
		},
		Sky = {
			Cover = 0.82, Density = 0.78, Color = Color3.fromRGB(92, 78, 70), Time = 2.6, ClearTime = 1.3,
			Vortex = 0, LowVortex = 0, Height = 260, Radius = { 700, 140 }, Size = { 190, 80 },
			Dark = Color3.fromRGB(70, 60, 56), Light = Color3.fromRGB(150, 140, 132),
		},
		Hit = 7, Fov = 16, Flash = 0.3,
		Range = 2800,
	},
	Look = {
		Flash = { 1.1, 0.75, 0.3 },
		Pillar = { Height = 1600, Radius = { 10, 70 }, Life = 1.6 },
		Fireball = { 30, 230, Rise = 0.35, Life = 1.6 },
		Prism = { 900, Life = 1 },
		Dome = { 0.25, 0.9 },
		Front = { Segments = 40, Low = 20 },
		Mushroom = { Height = 520, Rise = 1.9, Drift = 0.015, Width = 380, Stem = 16, LowStem = 8, Cap = 18, LowCap = 10, Collar = 10, LowCollar = 6, Glow = 1.8 },
		Shake = { 5, 2600, 1.6 }, Rumble = { 0.6, 700, 3.5 },
		Title = true,
		Cinematic = true,
		-- (his cinematic: each shot T s, From / To = { where, looking at } in
		-- his space as he hit - X right, Y up, -Z ahead; Fov from -> to: him in
		-- the crater as the white clears, the crane up and back over the city
		-- as it goes, the cloud climbing over him from the empty street)
		Shots = {
			{ T = 0.6, From = { Vector3.new(3, 2, -9), Vector3.new(0, 1, 0) }, To = { Vector3.new(4, 3, -12), Vector3.new(0, 1.5, 0) }, Fov = { 70, 74 } },
			{ T = 3.2, Cut = true, From = { Vector3.new(0, 60, 160), Vector3.new(0, 30, -60) }, To = { Vector3.new(0, 520, 640), Vector3.new(0, 0, -420) }, Fov = { 72, 80 }, Style = Enum.EasingStyle.Quad },
			{ T = 1.6, Cut = true, From = { Vector3.new(-220, 8, -300), Vector3.new(0, 230, 0) }, To = { Vector3.new(-240, 12, -330), Vector3.new(0, 280, 0) }, Fov = { 76, 74 } },
		},
	},
}
do
	local LWC = Config.DevFlight.LightWipe
	-- the last one, as the server keeps it on workspace (LightWipe): every
	-- machine's cooldown, and a late joiner's screen plays what's left of it
	function LWC.encode(id, origin, at)
		return string.format("%d|%.2f|%.2f|%.2f|%.3f", id, origin.X, origin.Y, origin.Z, at)
	end
	function LWC.decode(s)
		if type(s) ~= "string" then
			return nil
		end
		local id, x, y, z, at = string.match(s, "^(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
		x, y, z, at = tonumber(x), tonumber(y), tonumber(z), tonumber(at)
		if not (id and x and y and z and at) or x ~= x or y ~= y or z ~= z or at ~= at or math.abs(x) > 1e6 or math.abs(y) > 1e6 or math.abs(z) > 1e6 then
			return nil
		end
		return { Id = tonumber(id), Origin = Vector3.new(x, y, z), At = at }
	end
	-- how long one lasts on a screen: the wave out to the city's far side,
	-- the empty plain, the rewind (s after the impact)
	function LWC.span()
		local W, V = LWC.World, LWC.Wave
		return (V.Delay or 0) + (V.Time or 2.1) * 1.4 + 0.3 + (W.Hold or 8) + (W.RewindSpan or 1.6) + (W.RewindTime or 1.6)
	end
end

-- (round 92) THE LIGHT WIPE's wave - the Serious Punch's law (Config.
-- SeriousWave) for a blast from a point: when it reaches pos (s after the
-- impact), never "in a line", no front (0), how far (flat). spec: the
-- LightWipe's Wave. And how far out the front is t s after it.
function Config.LightWave(spec, origin, _d, pos)
	local dist = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z).Magnitude
	local reach = math.max(spec.Reach or 1300, 1)
	return (spec.Delay or 0) + (spec.Time or 2.1) * (dist / reach) ^ (1 / math.max(spec.Power or 0.7, 0.05)), false, 0, dist
end
function Config.LightReach(spec, t)
	local a = math.max(((tonumber(t) or 0) - (spec.Delay or 0)) / math.max(spec.Time or 2.1, 1e-3), 0)
	return (spec.Reach or 1300) * a ^ math.max(spec.Power or 0.7, 0.05)
end

---------------------------------------------------------------------------
-- (round 92) FLIGHTGRANT: the dev flight GIVEN to people (the owner: "make
-- me able to give people the flight ability as well"). A dev (the dev
-- flight's own gate, Kit.DF.allowed - only them, never someone a grant lets
-- fly) gives anyone in the server the dev flight and takes it back: the
-- test menu's GIVE FLIGHT panel (Dev only) or the console (giveflight
-- <who> [perm] [full], takeflight <who|all>, flights).
--   THIS SERVER: till they leave.
--   SAVED (perm): a list of UserIds in DataStore (Key), read when a server
--     starts and every Resync s, merged with UpdateAsync, sent live to
--     every running server on MessagingService (Topic) - the roster
--     switch's way: one save at a time, WriteGap apart, versioned; Studio
--     keeps its own changes to its session unless StudioSaves.
-- A granted player flies exactly as a dev does - V / the D-pad held / the
-- phone's FLY button (the Touch spot), the flight HUD, every tier and
-- LIGHTSPEED, through the walls, the crash, the carry - except the
-- destructive extras, which stay the devs' unless the grant is FULL POWER
-- (FullByDefault: off): the mach burst's bomb, all the way down, the Sky
-- Coffin's shield breaking, and the LIGHTSPEED wipe (Kit.DF.fullPower).
-- A grant never makes anyone a dev: the director camera, possess, admin
-- events and the roster panel don't see it (they go by DevFlyer /
-- Kit.DF.allowed). On the player (the server's word): FlightGrant ("Server"
-- or "Perm"), FlightFull, FlightGrantBy, FlightGrantAt; in workspace the
-- saved list (Attribute: Config.EncodeFlightGrants) and FlightGrantSync /
-- FlightGrantLastBy / FlightGrantLastAt.
---------------------------------------------------------------------------
Config.FlightGrant = {
	Enabled = true,
	DataStore = "QuirkBattlegrounds_FlightGrants_v1",
	Key = "FlightGrants", -- { Grants = { ["<UserId>"] = { Full, By, At, Name } }, Version, By, At }
	Topic = "QuirkFlightGrants", -- a message: { V, Ops = { { Id, G = entry | false } } (or All), By, At, From }
	Attribute = "FlightGrantsSaved", -- workspace: the saved list, one line a grant
	FullByDefault = false, -- a new grant's FULL POWER
	MaxSaved = 100, -- saved grants at most (the list rides on a workspace attribute)
	StudioSaves = false, -- Studio saves and sends its changes like a live server (off: they stay in the session)
	WriteGap = 6, -- seconds between two writes to the key (changes meanwhile go in the next one)
	SaveTimeout = 30, -- a save not back by then is given up on (the next one takes over)
	Resync = 120, -- seconds between re-reads of the save (heals a lost message)
	MessageMax = 1000, -- bytes a message may be (as JSON); bigger: the servers read the save instead
	JoinToast = 5, -- seconds after joining before someone with a saved grant is reminded of it
	Pending = 5, -- seconds the panel's switch waits (dimmed) for the server's word before it goes back
	-- the toast: its hold (s) and its top (px); on a phone its size (its words
	-- stay readable) and its spot - left of the move buttons (TouchX: the
	-- screen's width), under the top bar
	Toast = { Hold = 4.6, Y = 64, TouchScale = 0.78, TouchX = 0.4, TouchY = 56 },
	Touch = { X = -310, Y = -140, Size = 40 }, -- the phone's FLY button: from the jump button's centre (TOUCH.LAYOUT's way)
}

-- the saved list as one attribute string: a grant a line, "id\tfull\tat\tname\tby"
-- (newest first). Names lose tabs and line breaks (they can't hold them anyway).
function Config.EncodeFlightGrants(map)
	local list = {}
	for id, e in type(map) == "table" and map or {} do
		if tonumber(id) and type(e) == "table" then
			table.insert(list, { Id = tonumber(id), E = e })
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = tonumber(a.E.At) or 0, tonumber(b.E.At) or 0
		if ta ~= tb then
			return ta > tb
		end
		return a.Id < b.Id
	end)
	local function clean(s)
		return (string.gsub(tostring(s or ""), "[\t\r\n]", " "))
	end
	local lines = {}
	for _, it in list do
		table.insert(lines, string.format("%d\t%d\t%d\t%s\t%s", it.Id, it.E.Full == true and 1 or 0, math.floor(tonumber(it.E.At) or 0), clean(it.E.Name), clean(it.E.By)))
	end
	return table.concat(lines, "\n")
end

-- ...and back: { { Id, Full, At, Name, By } } in the string's order (junk lines skipped)
function Config.ParseFlightGrants(text)
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for line in string.gmatch(text, "[^\n]+") do
		local id, full, at, name, by = string.match(line, "^(%-?%d+)\t([01])\t(%-?%d+)\t([^\t]*)\t([^\t]*)$")
		if id then
			table.insert(out, { Id = tonumber(id), Full = full == "1", At = tonumber(at), Name = name, By = by })
		end
	end
	return out
end

---------------------------------------------------------------------------
-- (round 92) INASA YOARASHI (Shiketsu High, the hero Gale Force): a new
-- hero, dev only for now - Config.Quirks.Whirlwind.DevOnly is the one flag
-- (Config.IsDevOnly reads it; the HERO ROSTER switch releases him like
-- anyone else). His look, his cape in his own wind, his wind's colours and
-- the SKYBREAKER CYCLONE's world; the kit's numbers are
-- Config.Quirks.Whirlwind's. Server: Kit.IN (the look, every move's
-- gameplay, the wind wall's deflect, the cyclone); every screen: VFX.IN.
---------------------------------------------------------------------------
Config.Inasa = {
	-- HIS LOOK (QuirkGear.Cosmetics, built by the server: hidden with WEAR
	-- COSMETICS off like any hero's look). The hero costume: a thick burgundy
	-- coat with gold buttons and a cape over the shoulders, its collar thick
	-- fur; the left arm in a heavy brown sleeve and a big tan glove with air
	-- pipes over the knuckles, the right in the blue undersuit (SleeveShare
	-- of the arm, the hand bare); burgundy trousers with tubes round the
	-- ankles, big brown shoes (Shoe/GloveShare: the share of the limb), a
	-- padded plate on the left shoulder. The SHIKETSU CAP (Cap). The avatar's
	-- hair, hats and face come off (Kit.ST.bare, shared with Saitama) for his
	-- own: short black hair under the cap, big wide eyes, thick brows and a
	-- huge toothy grin (Face; wilder in the ult). Over: how far the coat
	-- stands off the body.
	Look = {
		Coat = Color3.fromRGB(128, 28, 46),
		CoatDark = Color3.fromRGB(92, 18, 32), -- (the cape's lining and edge)
		Button = Color3.fromRGB(242, 198, 52),
		Fur = Color3.fromRGB(234, 220, 188),
		Sleeve = Color3.fromRGB(112, 74, 48),
		Glove = Color3.fromRGB(214, 176, 122),
		Pipe = Color3.fromRGB(150, 156, 166),
		Under = Color3.fromRGB(44, 74, 150),
		Pants = Color3.fromRGB(84, 22, 36),
		Shoe = Color3.fromRGB(90, 56, 34),
		Plate = Color3.fromRGB(118, 124, 134),
		Cap = Color3.fromRGB(24, 28, 38),
		Band = Color3.fromRGB(128, 28, 46),
		Visor = Color3.fromRGB(12, 12, 16),
		Badge = Color3.fromRGB(242, 198, 52),
		Hair = Color3.fromRGB(24, 20, 20),
		Over = 0.05,
		SleeveShare = 0.72, GloveShare = 0.4, ShoeShare = 0.3,
	},
	-- THE CAP, in the head's visible size (v = 1.2 studs across for an R6
	-- head): the Crown sitting Lift over the head's middle, the flared Top
	-- (tipped back TopTilt degrees), the Band round its foot, the long wide
	-- Visor out front tipped down VisorTilt degrees, the school's gold Badge
	Cap = {
		Crown = Vector3.new(1.24, 0.52, 1.24), Lift = 0.5,
		Top = Vector3.new(1.42, 0.14, 1.46), TopTilt = 6,
		Band = 0.16,
		Visor = Vector3.new(1.18, 0.07, 0.62), VisorTilt = 16,
		Badge = Vector3.new(0.26, 0.24, 0.04),
	},
	-- HIS FACE (the head's visible size, on its front): big round eyes (the
	-- white, a gold Iris, a small Pupil), the brows thick and slanted down to
	-- the middle (BrowTilt degrees), the grin - the mouth's dark rim with the
	-- Teeth in it and a line between the rows. In the ult it's wilder (Wild x
	-- the grin and the brows' slant).
	Face = {
		EyeX = 0.21, EyeY = 0.06,
		Eye = Vector3.new(0.24, 0.22, 0.03), Iris = Vector3.new(0.13, 0.13, 0.02), Pupil = Vector3.new(0.06, 0.07, 0.02),
		Brow = Vector3.new(0.3, 0.075, 0.03), BrowY = 0.25, BrowTilt = 12,
		Mouth = Vector3.new(0.58, 0.22, 0.03), MouthY = -0.25,
		Teeth = Vector3.new(0.5, 0.15, 0.02), TeethLine = 0.022,
		Ink = Color3.fromRGB(20, 16, 18), White = Color3.fromRGB(250, 250, 246), IrisColor = Color3.fromRGB(236, 176, 40),
		Wild = 1.15,
	},
	-- THE CAPE off his shoulders (the long coat's tail): Segments (Width,
	-- Height studs) hinged at their top edges and swung by every screen from
	-- his motion - Rest degrees back off his body, Lift a stud/s of speed,
	-- Fall as he drops, at most Max; a flutter of Flutter degrees (more with
	-- speed, and in Wind: his own - every move gusts it) at Rate a second;
	-- Side: the swing out on turns; Blend: how fast it follows. Within Cull
	-- studs of the camera (LowCull on a low-end machine). Collar: the fur
	-- round the top of the torso (Front, Back and each Side piece).
	Coat = {
		Segments = { { 2.3, 1.45 }, { 2.5, 1.55 } },
		Thick = 0.14,
		Rest = 5, Lift = 1.8, Max = 72, Fall = 1.2, Side = 1,
		Flutter = 2.5, FlutterSpeed = 0.22, Rate = 1.4, Wind = 24, Blend = 9,
		Cull = 160, LowCull = 80,
		Collar = { Front = Vector3.new(1.7, 0.42, 0.36), Back = Vector3.new(2.2, 0.56, 0.42), Side = Vector3.new(0.4, 0.5, 1.15) },
	},
	-- HIS WIND on every screen: the streaks (Air; Pale: their shaded side),
	-- the street's Dust, the leaves and paper caught up in it (Leaves:
	-- colours; Bits: how many a gust carries, LowBits on a low-end machine)
	Wind = {
		Air = Color3.fromRGB(242, 250, 255), Pale = Color3.fromRGB(196, 226, 230),
		Dust = Color3.fromRGB(206, 192, 170), DustDark = Color3.fromRGB(150, 136, 118),
		Leaves = { Color3.fromRGB(116, 160, 70), Color3.fromRGB(196, 150, 60), Color3.fromRGB(170, 90, 44) },
		Paper = Color3.fromRGB(240, 238, 228),
		Bits = 10, LowBits = 4,
		-- the coat snapping in his gusts: how hard (0..1) and how long, a move
		Gust = 0.7, GustTime = 1.2,
	},
	-- THE SKYBREAKER CYCLONE's world, on every screen (who's hit and how hard
	-- is the server's: Config.Quirks.Whirlwind.Ult's SkyCyclone). The funnel:
	-- BaseRadius at the street out to TopRadius at Height studs, its axis
	-- swaying Sway studs at the top, turning Spin a second; Rings of wind
	-- streaks climbing it (Streaks each; LowRings on a low-end machine); a
	-- ring of storm cloud over it (Clouds puffs, CloudRadius out at
	-- CloudHeight, CloudSize studs) with lightning every Bolts seconds; the
	-- pieces of the city it carries (the server's rubble, plus Extra street
	-- chunks of PieceSize, at most MaxPieces / LowPieces) wheeling up it -
	-- Orbit radius (low -> high), OrbitSpeed turns a second, Climb studs/s up;
	-- Leaves and paper in it. Every screen within Range sees it (the whole
	-- city); within Near the sky dims (Grade) and the screen shakes (Shake:
	-- from -> at its height). Whatever happens, it's all gone MaxTime
	-- seconds after it began.
	Cyclone = {
		Height = 900, BaseRadius = 12, TopRadius = 240, Sway = 40, Spin = 1.4,
		Rings = 26, LowRings = 12, Streaks = 3,
		Clouds = 18, LowClouds = 8, CloudRadius = 260, CloudHeight = 820, CloudSize = { 120, 60 },
		Bolts = 0.7,
		Extra = 30, LowExtra = 10, MaxPieces = 90, LowPieces = 36, PieceSize = { 1.2, 4.5 },
		Orbit = { 6, 60 }, OrbitSpeed = 0.35, Climb = 70,
		Leaves = 40, LowLeaves = 14,
		Grade = { Brightness = -0.06, Contrast = 0.14, Saturation = -0.3, Tint = Color3.fromRGB(214, 226, 236) },
		Shake = { 0.6, 2.2 }, Near = 600,
		Range = 4000,
		MaxTime = 14,
	},
	-- WHAT HE SHOUTS: one of Lines in a speech bubble as a move goes off
	-- (Every seconds apart at most) - his own, loud and happy, never a quote
	Hype = {
		Every = 3,
		Lines = { "I LOVE THIS!!", "FEEL THE WIND!!", "BLOW 'EM AWAY!!", "WHAT A HOT-BLOODED FIGHT!!", "MORE!! GIVE ME MORE!!", "THE WIND'S ON MY SIDE!!" },
	},
	-- the SKYBREAKER CYCLONE's titles (his screen: big; everyone else's:
	-- smaller, with whose it is - Who, %s his name)
	Titles = { Call = "SKYBREAKER...", Hurl = "CYCLONE!!!", Who = "%s: SKYBREAKER CYCLONE" },
}

---------------------------------------------------------------------------
-- (round 92) hawksair: HAWKS' FLYING MOVESET's shared maths (the numbers
-- are Config.Quirks.FierceWings.Alt). Where the one he carries is, this
-- frame - the server holds the body there and every screen hangs it there
-- itself before drawing (so it never trails behind him on replication),
-- each from where it sees his root: the same answer from the same inputs.
-- state: "Lift" (reeled up from `from` over the carry's Lift), "Hold" (on
-- the feathers' lines under him), "Flurry" (pulled in to his blades), "Spin"
-- (whirled round him), "Toss" (yanked up from `from` to `top` over Time); t:
-- seconds in that state. Never a NaN: nothing's ever aimed along nothing.
---------------------------------------------------------------------------
Config.HawksAir = {}
do
	local UP = Vector3.new(0, 1, 0)
	local function flatUnit(v, fallback)
		local f = typeof(v) == "Vector3" and Vector3.new(v.X, 0, v.Z) or Vector3.zero
		if f == f and f.Magnitude > 0.05 then
			return f.Unit
		end
		return fallback or Vector3.new(0, 0, -1)
	end
	Config.HawksAir.flatUnit = flatUnit
	function Config.HawksAir.spec()
		local q = Config.Quirks and Config.Quirks.FierceWings
		return (q and q.Alt and q.Alt.Carry) or {}
	end
	-- the follow-up on a slot (1-4)
	function Config.HawksAir.move(slot)
		return (Config.HawksAir.spec().Moves or {})[slot]
	end
	function Config.HawksAir.at(rootCF, vel, state, t, from, top, scale)
		local C = Config.HawksAir.spec()
		local s = (type(scale) == "number" and scale == scale and scale > 0) and scale or 1
		t = (type(t) == "number" and t == t) and math.max(t, 0) or 0
		local look = flatUnit(rootCF.LookVector)
		local v = (typeof(vel) == "Vector3" and vel == vel) and vel or Vector3.zero
		local fv = Vector3.new(v.X, 0, v.Z)
		local base = rootCF.Position
		local face = look
		local spot
		if state == "Toss" and typeof(from) == "Vector3" and typeof(top) == "Vector3" then
			local T = Config.HawksAir.move(1) or {}
			local k = math.clamp(t / math.max(T.Time or 0.38, 0.05), 0, 1)
			-- (bowed out in front of him on the way up: never through his body)
			spot = from:Lerp(top, 1 - (1 - k) * (1 - k)) + look * math.sin(math.pi * k) * (T.Bow or 4) * s
		elseif state == "Flurry" then
			local F = Config.HawksAir.move(2) or {}
			spot = base + look * (F.Reach or 3.2) * s - UP * 0.6 * s
			face = -look -- (facing him, at the end of his blades)
		elseif state == "Spin" then
			-- one and a half turns round him at his chest (from behind, round
			-- to in front), quickening: let go out in front, down his aim
			local G = Config.HawksAir.move(3) or {}
			local k = math.clamp(t / math.max(G.Spin or 0.32, 0.05), 0, 1)
			local a = 3 * math.pi * k ^ 1.6
			local right = look:Cross(UP)
			spot = base - UP * 1.2 * s + (right * math.sin(a) - look * math.cos(a)) * (G.Radius or 4.5) * s
			face = right * math.cos(a) + look * math.sin(a) -- (along the way they're swung: a unit, never nothing)
		else
			local speed = fv.Magnitude
			local back = math.clamp(speed / math.max(C.TrailSpeed or 70, 1), 0, 1) * (C.Trail or 2.4) * s
			local dir = speed > 1 and fv.Unit or look
			spot = base - UP * (C.Hang or 6.5) * s + look * (C.Ahead or 0.6) * s - dir * back
			if state == "Lift" and typeof(from) == "Vector3" then
				local Q = Config.Quirks and Config.Quirks.FierceWings
				local k = math.clamp(t / math.max((Q and Q.Extra and Q.Extra.Lift) or 0.35, 0.05), 0, 1)
				spot = from:Lerp(spot, 1 - (1 - k) ^ 3)
			end
		end
		return CFrame.lookAt(spot, spot + face)
	end
end

---------------------------------------------------------------------------
-- (round 90) WALKING AND RUNNING ("better walk and run animations, for all
-- characters"). Every R6 body walks, runs and sprints on the built-in gait
-- (VFX's locomotion layer - Config.Animations.Procedural.R6 = true), worked
-- out every frame from how the body is really moving, so a planted foot
-- stays planted at any speed, on every screen. Gait: the stride's numbers,
-- the same for everyone. Styles: how each hero carries it - a style only
-- lists what it changes from Athletic. A pair or a trio is { walk, run,
-- sprint } (a pair: the sprint is the run's). Heroes: who walks how - a
-- style's name, or { normal, Alt = in the second form, Ult = in the ult }.
---------------------------------------------------------------------------
Config.Locomotion = {
	Far = 260, -- studs from the camera: a body further off keeps Roblox's own clips (too far to see)
	Lod = { 90, 170 }, -- studs from the camera: further, a walking body is re-posed every 2nd / 3rd frame
	-- (review fixes) a low-end machine (the graphics slider, or under 40 fps)
	-- re-poses from this share of Lod's distances; a body behind the camera
	-- (past BehindFrom studs, never your own) counts as far off; another
	-- body's ground check (a raycast) every GroundEvery seconds
	LowEndLod = 0.5, BehindFrom = 12, GroundEvery = 0.05,
	-- (round 91, JJS) the shared gait rebuilt to Jujutsu Shenanigans' walk
	-- and run (VFX's locomotion header says how it moves); the numbers below
	-- are JJS's, read off its footage frame by frame (S/r91 jjs_reference)
	-- (round 93, the owner: "they should be strides" - big strides with the
	-- kick held up behind, fewer steps, the arms close and swinging forward
	-- and back, and a strafe the same stride turned the way he goes)
	Gait = {
		WalkAt = 7, RunAt = 14, -- studs/s: JJS's quiet walk up to WalkAt, its run from RunAt (every normal pace and the sprint)
		-- the sprint (forward only): from SprintFrom x the hero's walk speed, all of it by SprintFull
		SprintFrom = 1.12, SprintFull = 1.42,
		-- the stride's rate (strides a second, two steps each) follows the
		-- speed like JJS's playback: Cadence at CadenceAt studs/s (walk, run,
		-- sprint), x (speed / that) ^ CadencePow. (Round 93: "they should be
		-- strides" - fewer, longer steps: about 3.6 a second at a 22 studs/s
		-- run and 4 at a 34 sprint, against round 91's frantic 4.3 / 5; the
		-- walk, its calmer version, 3.2 at 7 against 3.7.) The walk ~0.8 s a
		-- stride in JJS (R6 legs can't keep a planted foot at that pace this
		-- fast, so ours steps a little quicker)
		Cadence = { 1.6, 1.75, 1.95 }, CadenceAt = { 7, 20, 32 }, CadencePow = 0.3,
		-- degrees either side of the hip a planted foot sweeps (walk, run,
		-- sprint); the share of the stride it's down is what keeps it planted
		-- at that, within DutyRange (a run: a short, springy contact)
		Swing = { 34, 40, 43 }, DutyRange = { 0.13, 0.62 },
		MaxSwing = 46, -- degrees: a stride longer than that comes quicker instead of wider
		Sole = 0.25, -- half a foot's length over a leg's: the heel and toe the body rocks over
		-- (round 93) how far down the planted leg's dip the hips ride (0.5:
		-- halfway); the longer strides dip more - a touch higher keeps the
		-- planted sole out of the street
		Ride = 0.4,
		-- the swing (of the stride, after the toe-off; walk, run, sprint): the
		-- kick back peaks at KickAt, the reach in front at ReachAt; the foot
		-- comes down moving back with Catch of the stance's speed. (Round 93,
		-- JJS's stride: the kick is HELD up behind, the sole showing, while the
		-- other foot takes its step, then the leg whips through to the reach -
		-- KickHold: how long it lingers there, 1 = not at all)
		KickAt = { 0.3, 0.32, 0.32 }, ReachAt = { 0.76, 0.88, 0.88 }, KickHold = { 1, 2.2, 2.2 }, Catch = 0.5,
		-- studs: one soft bob a step (walk, run, sprint) - + up over the
		-- planted leg (a walk), - down into it (a run: lowest mid-stance, up
		-- through the flight). (Round 93: a rhythmic bob, a little more)
		Bob = { 0.025, -0.06, -0.06 },
		LeanPulse = { 0, 1.2, 1.5 }, -- degrees: the lean a touch further as each foot pushes off
		NeckHold = 0.6, -- the share of the lean the head holds up against (JJS: lowered with it a little, the face still ahead)
		Speed = 12, -- how quickly the stride follows the speed (per second)
		-- degrees off straight ahead: backing up (the stride runs backwards).
		-- From a run, it's backing up once it has gone that way BackHold
		-- seconds, and never while the body comes round to the way he goes
		-- faster than BackTurn radians a second (a U-turn, not a backpedal).
		-- (Review fix: "coming round" is his facing closing on the way he
		-- goes; the camera turning him in shift lock turns the way he goes
		-- with him, so a strafe or a backpedal stays one)
		BackEnter = 115, BackLeave = 100, BackHold = 0.08, BackTurn = 2.5,
		-- going sideways: the chest turns this share of the way (up to TurnMax
		-- degrees), the legs the rest (up to LegTurnMax); the head stays ahead.
		-- Coming round faster than TurnFade[1] radians a second (none past
		-- [2]), the legs don't turn off: the body is turning to the way he goes
		TurnShare = 0.25, TurnMax = 20, LegTurnMax = 70, TurnSpring = 18, TurnFade = { 1.5, 4.5 },
		-- (round 93) going sideways the lean goes the way he strides - this
		-- share of it as a roll into where he's going, none on over his front
		-- (an R6 chest rolled further drops one hip, and the leg under it,
		-- into the street)
		LeanInto = 0.3,
		-- { going sideways, backing up }: steps this much quicker and shorter,
		-- this much of the kick gone, the arms' swing this much smaller.
		-- (Round 93: "base those movements for moving side to side too" - a
		-- strafe is the run's own stride turned the way he goes, so sideways
		-- barely any; backing up is the stride reversed, calmer)
		CalmQuick = { 0.05, 0.15 }, CalmShort = { 0.05, 0.33 }, CalmKick = { 0.15, 0.5 }, CalmArms = { 0.1, 0.5 },
		-- backing up, the arms' swing this much of the run's (round 93 review:
		-- eased in as he goes back, not cut the frame he turns back - the arm
		-- in front dropped about 18 degrees in that one frame)
		BackArms = 0.7,
		-- (round 93 review) studs (x the body's size): how far a cape hung off
		-- his back (Saitama's, Inasa's coat) is held out past a leg the run
		-- kicks up behind (the strides' kick went 0.8-1.1 studs into it)
		CapeClear = 0.15,
		Bank = 6, -- degrees at most: leaning into a turn (worked out from the speed and the turn; JJS: barely)
		BankSpring = { 22, 0.9 }, -- the bank following the turn: { stiffness, damping }
		YawFollow = 14, -- per second: how quickly the turn's rate is read (the bank and the head's lead come with it)
		LookLead = { 4, 8, 14 }, -- the head leading a turn: degrees per radian/s of turn, at most, how quickly
		LeanSpring = { 13, 0.6 }, -- the lean following the speed: { stiffness, damping } (under 1: it rocks a little)
		StartLean = 4, -- degrees: the kick of leaning into a start
		StopKick = 250, -- degrees/s: a stop from a sprint pitches the chest on (the head up) before it settles
		StopCarry = { 0.15, 0.6 }, -- a stop keeps this share of the legs' swing (they don't run on) and the arms'
		-- a start, a stop, a jump, a landing, a new hero: the body carries on with
		-- how it was moving into the new pose and settles (no cross-fade); the
		-- legs quicker (SettleLegs)
		Settle = { 13, 0.72 }, SettleLegs = { 24, 0.95 },
		-- seconds: the switch's own frame moves on with the speed it had, at
		-- most this much of it (a long frame - a hitch, a slow phone - doesn't
		-- fling a limb on past its stride)
		SwitchStep = 1 / 60,
		LandIn = 0.05, -- seconds: a landing's dip comes in over this (not in one frame)
		AirAfter = 0.07, -- seconds off the street before it's a jump (a kerb or a bump isn't)
		-- standing (JJS: a neutral stand): degrees of breath, studs-ish of the
		-- weight's drift, degrees the head looks about, the arms off the sides,
		-- the feet apart
		Idle = { Breath = 0.5, Shift = 0.4, Look = 3, ArmOut = 4, Stance = 1 },
	},
	-- (round 91, JJS: one shared gait. JJS gives nearly every character the
	-- same walk and run, so Athletic IS that gait now, and a hero's style is
	-- only a small touch on top of it, never another gait. Round 90's hands in
	-- the pockets and behind the back, the heavy arms set out, the big hunches
	-- and leans, the swagger and Iida's metronome are gone: on straight R6
	-- arms they read as stiff "penguin" arms and wings, and they fought the
	-- JJS run. Kept: Chargebolt's anime sprint - his own run, as JJS gives a
	-- few characters theirs -, Twice's twitch, Hawks' arms kept off his wings,
	-- the big bodies' feet a little apart, a little bend standing for the
	-- hunched ones.)
	Styles = {
		-- the default: JJS's walk, run and sprint
		Athletic = {
			Cadence = 1, -- x the stride rate
			Bounce = 1, -- x the bob (Gait.Bob)
			Lean = { 3, 20, 23 }, -- degrees forward (JJS: upright walking, about 20 running)
			Twist = { 1, 7, 8 }, -- the shoulders turning with the arm in front (JJS: 10 at most)
			Roll = { 1, 1, 0.8 }, -- the torso rolling over the planted foot
			Sway = { 0.03, 0.02, 0.01 }, -- studs: the hips over the planted foot
			Width = 1, -- degrees: the legs set apart (an R6 leg swings out round its outer edge: wide sinks the inner edge)
			Clear = -3, -- degrees: a swinging leg turned in a touch (round its outer edge that lifts the foot)
			-- (round 93, JJS's big strides: the trailing leg driven back and
			-- kicked up near level behind - the sole up - and held there while
			-- the other foot steps (Gait.KickHold); the front one reaching well
			-- out before it lands)
			Kick = { 8, 38, 40 }, -- degrees the trailing leg swings on back past the toe-off
			Reach = { 2, 12, 14 }, -- degrees the front leg swings on past the landing before it comes down
			-- THE ARMS, from the chest (round 93, JJS: straight, close to the
			-- body, swinging forward and back the way he runs against the legs -
			-- never out to the sides like wings). Forward at the front of the
			-- swing (the hand up to the chest), as they pass the body, and back
			-- past the hip (degrees):
			ArmFwd = { 32, 95, 100 }, ArmMid = { 2, 6, 8 }, ArmBack = { 30, 40, 46 },
			-- out from the side as they pass, at the front, at the back: only
			-- enough to clear the body
			ArmOut = { 6, 7, 8 }, ArmTuck = { 6, 6, 6 }, ArmFlare = { 6, 8, 9 },
			ArmCross = { 0, 34, 36 }, -- degrees in across the chest at the front (JJS: the fist in front of the chest)
			ArmLag = 0.04, -- of a stride: the arms a beat behind the legs
			Ninja = 0, -- 0..1: the sprint is the anime arms-back run
			Pockets = 0, -- 0..1: walking and standing with the hands in the pockets
			Behind = 0, -- 0..1: walking and standing with the hands behind the back
			Hunch = 0, -- degrees: shoulders rounded, head pushed forward, standing and walking (negative: chest out, chin up)
			Heavy = 0, -- 0..1: the arms held out off a big chest (standing and moving)
			Stiff = 0, -- 0..1: precise - less twist, roll and sway
			Swagger = 0, -- 0..1: more roll and sway in the walk, a lazy head
			Jitter = 0, -- 0..1: twitchy
		},
		-- big bodies (All Might's muscle form, Prime All Might, Overhaul's ult): a touch heavier, the feet a little apart
		-- (round 93: these leans a degree more, with the shared run's)
		Titan = { Cadence = 0.95, Bounce = 0.85, Width = 3, Lean = { 2, 16, 20 } },
		-- Endeavor: the same, a little less
		Brute = { Cadence = 0.96, Width = 2, Lean = { 2, 17, 21 } },
		-- All Might's true form, Shigaraki, Suneater: a little bent standing and walking (not running)
		Frail = { Hunch = 4, Lean = { 4, 18, 22 } },
		Slouch = { Hunch = 5, Lean = { 5, 18, 22 } },
		Timid = { Hunch = 4, Cadence = 1.03 },
		-- Iida: upright, a touch quicker, the shoulders steadier
		Engine = { Cadence = 1.04, Lean = { 2, 16, 20 }, Twist = { 1, 3, 4 } },
		-- Chargebolt: flat out, the anime arms-back run (his own run, as a few JJS characters have theirs)
		Loose = { Ninja = 1, ArmLag = 0.06 },
		-- Twice (and his doubles): a twitch of the head now and then
		Twitchy = { Jitter = 1 },
		-- Hawks: his arms carried a little shorter behind him, off his folded wings
		-- (round 93: the shared arms swing close now - his back swing is
		-- shorter, and at his sprint, under the Guard wings, a touch out
		-- behind: 0.29 studs clear of the nearest feather, 0.4 of the folded ones)
		Hawks = { ArmBack = { 20, 24, 16 }, ArmFlare = { 6, 8, 16 } },
	},
	Heroes = {
		Explosion = "Athletic",
		OneForAll = { "Frail", Alt = "Titan", Ult = "Titan" },
		FullCowl = "Athletic",
		HalfCold = "Athletic",
		Engine = "Engine",
		Creation = "Athletic",
		Lemillion = "Athletic",
		Manifest = "Timid",
		Arbor = "Athletic",
		Electrification = "Loose",
		Overhaul = { "Athletic", Ult = "Titan" },
		Decay = "Slouch",
		Compress = "Athletic",
		Double = "Twitchy",
		Limitless = "Athletic",
		CrazyDiamond = "Athletic",
		PlusUltra = "Athletic",
		Hellflame = "Brute",
		Blueflame = "Athletic",
		PrimeDeku = "Athletic",
		PrimeMight = "Titan",
		TheWorld = "Athletic",
		FierceWings = "Hawks",
		Saitama = "Athletic", -- (round 90: the new hero; round 91: the shared gait)
		Whirlwind = "Athletic", -- (round 92: Inasa - big, upright, all energy)
	},
}

-- (round 90) SAITAMA (One Punch Man, a guest - dev only): his look, his
-- cape, his bored idle and the SERIOUS PUNCH's world (the kit's numbers are
-- Config.Quirks.Saitama's). Server: Kit.ST (the look, the moves, the punch's
-- gameplay); every screen: VFX.ST (the cape, the face, the idle, the moves,
-- the whole city blown away and put back).
Config.Saitama = {
	-- HIS LOOK (QuirkGear.Cosmetics, built by the server: hidden with WEAR
	-- COSMETICS off like any hero's look): the yellow jumpsuit over every
	-- limb (Over: how far it stands off the body), red gloves (GloveShare:
	-- the share of the arm from the hand up) and boots (BootShare: of the
	-- leg), each with a cuff; the black belt and its round buckle; the white cape off
	-- his shoulders. The avatar's hair comes off (bald) and its face decal is
	-- swapped for his own, drawn in thin lines: the dot eyes under heavy
	-- lids, the flat mouth - SERIOUS in the ult (narrowed eyes, brows down,
	-- the shadow over them). Shine: the light on his head.
	Look = {
		Suit = Color3.fromRGB(250, 206, 46),
		SuitShade = Color3.fromRGB(222, 170, 30), -- (the zip, the seams)
		Glove = Color3.fromRGB(204, 30, 38),
		GloveCuff = Color3.fromRGB(176, 22, 30),
		Belt = Color3.fromRGB(28, 26, 30),
		Buckle = Color3.fromRGB(236, 190, 52),
		Cape = Color3.fromRGB(246, 246, 242),
		CapeEdge = Color3.fromRGB(226, 226, 220),
		Ink = Color3.fromRGB(26, 22, 24), -- (the face's lines)
		Shadow = Color3.fromRGB(70, 46, 40), -- (the serious face's shade over the eyes)
		Over = 0.04,
		GloveShare = 0.36,
		BootShare = 0.42,
		Shine = { Size = Vector3.new(0.34, 0.12, 0.22), Transparency = 0.45 },
	},
	-- (in the head's visible size: v = 1.2 studs across for an R6 head; the
	-- face is on its front, -v/2)
	Face = {
		EyeY = 0.07, EyeX = 0.19,
		Eye = Vector3.new(0.1, 0.12, 0.03), -- (deadpan: a dot)
		Lid = Vector3.new(0.22, 0.026, 0.02), LidY = 0.08, -- (the heavy, bored lid line just over it)
		Mouth = Vector3.new(0.2, 0.024, 0.02), MouthY = -0.24,
		-- SERIOUS: the eyes narrowed to slits, the brows slanting down to the
		-- middle (Tilt degrees), the shadow over the top of the face
		SeriousEye = Vector3.new(0.17, 0.05, 0.03),
		Brow = Vector3.new(0.26, 0.05, 0.02), BrowY = 0.2, BrowTilt = 16,
		SeriousMouth = Vector3.new(0.26, 0.03, 0.02),
		ShadeY = 0.18, ShadeSize = Vector3.new(0.98, 0.3, 0.02), ShadeTransparency = 0.55,
	},
	-- THE CAPE: Segments from the shoulders down (Width, Height studs), hinged
	-- at their top edges. Every screen swings it from his motion: Rest
	-- degrees back off his body standing still, Lift degrees a stud/s of
	-- speed (back from where he goes; up as he falls), at most Max; a flutter
	-- of Flutter degrees (more with speed, and in Wind: the Serious Punch,
	-- the awakening) at Rate cycles a second; each segment adds Follow of its
	-- swing to the next. Within Cull studs of the camera every frame (Low
	-- on a low-end machine); past it, still.
	Cape = {
		Segments = { { 2.2, 1.1 }, { 2.5, 1.1 }, { 2.8, 1.2 } },
		Thick = 0.08,
		Rest = 6, Lift = 2.2, Max = 78, Fall = 1.4, Side = 1.2,
		Flutter = 3, FlutterSpeed = 0.25, Rate = 1.6, Follow = 0.55,
		Wind = 26, -- (degrees of flutter in a gale)
		Blend = 10, -- (how fast it follows: per second)
		Cull = 160, LowCull = 80,
	},
	-- THE BORED IDLE: standing still and out of a fight this long (After), he
	-- gets bored: one of Clips (a nose pick, a yawn and a scratch, a long
	-- look at nothing), held Hold seconds; another after Every more. Moving,
	-- a hit, a move: back to normal at once.
	Idle = {
		After = 7, Every = 12, Hold = 2.6,
		Clips = { "PoseSaitamaBored1", "PoseSaitamaBored2", "PoseSaitamaBored3" },
		Calm = 4, -- (seconds since his last fight: Reactions' rule is the server's - here, no hit seen this long)
		Cull = 140,
	},
	-- THE SERIOUS PUNCH's WORLD, on every screen (the gameplay - who's hit,
	-- how hard - is the server's, Config.Quirks.Saitama.Ult's SeriousPunch).
	-- When the server says it's thrown (SeriousPunchGo: where, which way, the
	-- server time), every machine runs the same wave over its own copy of the
	-- city: workspace.Map's Folders (each building, tree, lamp, bench, bush
	-- and dumpster) are torn apart and blown to the horizon as the wave
	-- reaches each part, and put back later. Nothing in the real map changes:
	-- the originals are hidden on this screen (and can't be stood on, here -
	-- the bodies thrown through where they were fly on), copies fly.
	-- Foundation: what stands no higher than this over the street stays (the
	-- lots, the bowling hall's floor: what's left).
	-- Pieces: a BUILDING comes apart in chunks - a grid laid over it (about
	-- Chunks cells, LowChunks on a low-end machine, each ChunkMin..ChunkMax
	-- studs), each cell with ChunkVolume of building in it a block hugging
	-- what's there, the colour most of it is (its walls count most); the
	-- other things fly as copies of their biggest parts (Props of each);
	-- the biggest of all first, at most Max (LowMax) in all. Split: a copy
	-- longer than this is broken in two, at most SplitMax times a piece.
	-- Rubble: what a building's bottom chunks leave lying on its lot
	-- (PerChunk at most each, Max / LowMax in all), and dust boils up off it.
	-- Flight: each one bursts out of the middle of what it was part of
	-- (Burst studs/s at most), then the blast takes it - its push building
	-- up over Ramp seconds to Speed studs/s straight ahead of the punch ->
	-- behind him (x SpeedJitter either way) - and Up studs/s up (behind him
	-- they're thrown up more); Bias: how much the line drags things along
	-- it, Gravity, Spin radians/s (smaller pieces faster); after FlyTime (+-
	-- FlyJitter) seconds they're gone over the horizon (Fade: the last seconds).
	-- Hold: seconds the city stays gone after the wave has passed everything;
	-- then the REWIND: every piece flies back along its own path, the far side
	-- of the city first, converging on him (RewindSpan seconds from the first
	-- to the last), each one RewindTime seconds coming home, and snaps in.
	-- MaxTime: whatever happens, everything's back this long after the punch.
	Wipe = {
		Folders = { "Buildings", "Trees", "Streetlights", "Benches", "Bushes", "Dumpster" },
		Foundation = 3,
		Chunks = 36, LowChunks = 14, ChunkMin = 10, ChunkMax = 40, ChunkVolume = 40,
		Rubble = { PerChunk = 3, Max = 320, LowMax = 90, Size = { 3, 9 }, Height = { 1.5, 4.5 } },
		-- ((round 90 review) the dust banks off the lots: one a building, at
		-- most Max (LowMax) - each an emitter (Emit puffs of smoke, Size
		-- studs growing) and Puffs of the toon dust)
		Dust = { Max = 80, LowMax = 24, Emit = 10, LowEmit = 4, Size = { 14, 34 }, Puffs = 2, LowPuffs = 1 },
		Props = { Trees = 5, Streetlights = 2, Benches = 1, Bushes = 1, Dumpster = 2 },
		LowProps = { Trees = 2, Streetlights = 1, Benches = 0, Bushes = 0, Dumpster = 1 },
		Max = 1700, LowMax = 520,
		Split = 34, SplitMax = 2,
		MinVolume = 6, -- (a part this small never gets a copy: it vanishes in the dust)
		Speed = { Front = 920, Back = 360 }, SpeedJitter = 0.22,
		Up = { Front = 55, Back = 150 },
		Bias = 0.6, Gravity = 46, Spin = 4.5, Burst = 34, Ramp = 0.22,
		FlyTime = 3.1, FlyJitter = 0.5, Fade = 0.5,
		Hold = 7, RewindSpan = 1.4, RewindTime = 1.5, MaxTime = 30,
		ScanBudget = 900, HideBudget = 900, -- (parts a frame: read at the windup, hidden as the wave reaches them)
		-- ((round 90 review) a low-end machine hides fewer a frame (it falls a
		-- little behind the wave, never a long frame); and every frame a slice
		-- of what's hidden is checked for something else on this screen having
		-- shown it or made it solid again (the dev flight's and the smash's
		-- opened walls closing) - CheckBudget parts a frame)
		LowHideBudget = 400, CheckBudget = 500, LowCheckBudget = 200,
		CameraClear = 12, -- (a flying piece this close to the camera fades out of the way)
		-- the dust wall the wave pushes ahead of it (Segments round it; Low on
		-- a low-end machine), Height studs, its puffs Size studs (near him ->
		-- out at the edge); gone past Reach
		Wall = { Segments = 44, LowSegments = 24, Height = 9, Size = { 18, 64 }, Reach = 1500 },
		-- the blast down the line: the column (Length, its Radius from the fist
		-- out to the far end, the time it takes to reach there), the rings
		-- round it (Rings, out to Spacing apart), and how long it lasts
		Column = { Length = 2600, Radius = { 8, 150 }, Reach = 0.32, Life = 2.2, Rings = 12, Spacing = 60, Pitch = 3 },
		-- the scour marks the blast leaves fanned out over the street (Count
		-- of them, Length studs, Width)
		Scour = { Count = 34, LowCount = 16, Length = { 220, 760 }, Width = { 6, 22 } },
		-- THE SKY: the clouds (Roblox's own, this screen's) gather over the
		-- windup (Cover / Density / Color) and are blown clear by the punch
		-- (ClearTime); a ring of storm clouds (Vortex parts, Height studs up,
		-- Radius out) wheels in over him, and the blast throws them away
		Sky = {
			Cover = 0.88, Density = 0.72, Color = Color3.fromRGB(70, 70, 82), ClearTime = 1.3,
			Vortex = 26, LowVortex = 12, Height = 260, Radius = { 700, 140 }, Size = { 190, 80 },
			Dark = Color3.fromRGB(64, 64, 76), Light = Color3.fromRGB(150, 150, 164),
		},
		-- THE GRADE (an effect of its own on this screen's Lighting, stacked on
		-- whatever's there): the windup darkens and drains it, the punch whites
		-- it out, the cleared sky after is bright and warm (with SunRays), all
		-- of it gone with the rewind
		Grade = {
			Windup = { Brightness = -0.08, Contrast = 0.18, Saturation = -0.4, Tint = Color3.fromRGB(226, 232, 246) },
			After = { Brightness = 0.04, Contrast = 0.06, Saturation = 0.12, Tint = Color3.fromRGB(255, 250, 238) },
			SunRays = { Intensity = 0.16, Spread = 0.7 },
		},
		-- how it feels where you are: the screen shakes harder and harder over
		-- the windup (Shake { from, to }), and the wave hitting you shakes it
		-- (Hit), kicks the view out (Fov degrees) and whites it out (Flash)
		Shake = { 0.4, 2.8 }, Hit = 6, Fov = 14, Flash = 0.35,
		-- seen from this far off (the Vestige Realm, the sky above): none of it
		Range = 2600,
		-- the street, if the map doesn't say (the real map's is ~25-26)
		Street = 25.5,
	},
}

-- (round 90) THE SERIOUS PUNCH's wave: when it reaches pos (seconds after the
-- punch), whether pos is in the punch's line, how square in front of him it
-- is (0..1) and how far. One law for the server (who's hit, when) and every
-- screen (what's blown away, when). spec: the ability (Front / Back / Sharp
-- / Delay / LineCone / LineWidth); d: his flat aim.
function Config.SeriousWave(spec, origin, d, pos)
	local rel = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z)
	local dist = rel.Magnitude
	local c = dist > 0.01 and rel.Unit:Dot(d) or 1
	local front = math.max(c, 0) ^ (spec.Sharp or 1.6)
	local speed = (spec.Back or 520) + ((spec.Front or 1600) - (spec.Back or 520)) * front
	local fwd = rel:Dot(d)
	local lateral = (rel - d * fwd).Magnitude
	local inLine = fwd > -2 and lateral <= math.max(spec.LineWidth or 16, fwd * math.tan(math.rad(spec.LineCone or 14)))
	return (spec.Delay or 0) + dist / math.max(speed, 1), inLine, front, dist
end

-- All Might's hero costume, worn in muscle form and Plus Ultra (catalog
-- clothing ids, applied with a HumanoidDescription). Set Enabled = false to
-- keep the player's own clothes. The casual yellow-pants look is
-- Shirt 1206336891 + Pants 1206335841.
Config.AllMightOutfit = {
	Enabled = true,
	Shirt = 9279053597,
	Pants = 9279054609,
}

---------------------------------------------------------------------------
-- Core stats
---------------------------------------------------------------------------

-- The game is built for R6 bodies (the movement pack, the moves' poses). If
-- the experience's avatar settings on the Roblox site let R15 avatars in,
-- they respawn as R6 bodies wearing their own avatar. false: allow R15.
Config.ForceR6 = true

-- Parkour - you're in control, nothing happens by itself:
--  * RUN by double-tapping W (or hold Left Ctrl / push the stick all the way)
--  * running at something, press JUMP: VAULT over low stuff, CLIMB walls and
--    ledges, RUN UP walls too tall to top out; press DASH at something with a
--    gap beneath it to SLIDE under
--  * WALL HOP: press jump beside a wall while moving - you run along it, then
--    kick off (one press, one hop). Hops in a row: 3 above 2/3 health, 2
--    above 1/3, 1 below that
--  * LANDING ROLL: falling further than a jump, press jump just before you
--    land to roll out of it, further the bigger the fall, keeping your speed
--    (round 65, JJS: and the fall's speed turns into forward speed - Convert
--    x how fast you were falling, at most MaxBoost, for Carry seconds)
--  * (round 65) LEDGE CATCH: in the air, moving at a ledge your hands can
--    reach (its top from Below studs under your middle to Above over it):
--    press jump - or hold it as you get there - and you pull yourself up
--  * (round 65) AUTO RUN (the settings, like JJS): moving is running
Config.Parkour = {
	Enabled = true,
	DoubleTapRun = true,
	Reach = 3.2, -- studs ahead an obstacle has to be
	VaultMax = 4.6, -- up to this high: vaulted over (thin) or mantled onto (deep)
	VaultTime = 0.36,
	ClimbMax = 16, -- walls up to this high are climbed onto
	ClimbSpeed = 34, -- studs a second up the wall
	WallRunUp = 10, -- a wall too tall to top out: you run this far up it (then wall hop)
	SlideGap = 2.4, -- room needed underneath to slide through
	SlideTime = 0.45,
	WallHop = {
		Range = 2.8, -- how close the wall has to be (studs)
		RunTime = 0.3, RunSpeed = 30, RunRise = 16, -- running along it
		KickOut = 58, KickUp = 58, KickAlong = 22, KickTime = 0.16, -- the kick off it (a real shove)
		Carry = 0.25, -- after the kick you keep flying outward this long (air steering can't eat it)
		Gap = 0.15,
		ByHealth = { { 0.66, 3 }, { 0.33, 2 }, { 0, 1 } }, -- { above this share of health, hops }
	},
	Roll = { MinFall = 10, Window = 4.5, Time = 0.45, Base = 8, PerStud = 0.35, Max = 26, Convert = 0.3, MaxBoost = 22, Carry = 0.25 },
	LedgeCatch = { Enabled = true, Reach = 3.2, Below = 1.2, Above = 4.2 },
	Cooldown = 0.3,
}

-- Hit registration. Everyone sees everyone else slightly in the past (the
-- trip to the server and back, plus the smoothing on top), so melee and dash
-- hitboxes also count whoever was inside them that long ago - if it hit on
-- your screen, it hit - up to MaxRewind seconds back. M1s are measured from
-- where the attacker stood on their own screen, and stay live for a few
-- frames (an active window, not a single-frame check).
Config.Hitboxes = {
	LagCompensation = true,
	MaxRewind = 0.25, -- seconds
	InterpDelay = 0.05, -- the smoothing every client adds on top of the ping
	M1ActiveFrames = 4, -- checks, 1/30 s apart
	MaxOriginDrift = 8, -- studs the attacker's own position may differ from the server's
}

-- Physics feel
Config.Physics = {
	-- (round 60) bodies collide: you bump into people and can stand on
	-- someone. A body that's out of its owner's hands - down in the street,
	-- held in a grab, a marble in Mr. Compress's palm - goes "Loose" (it
	-- still lands on the street, but never shoves or lifts anyone), and stays
	-- loose after it's let go / gets up until it's clear of everyone
	-- (checked every LooseCheck seconds, at most LooseMax)
	CharacterCollisions = true,
	LooseCheck = 0.15,
	LooseMax = 3,
	ServerOwnedDebris = true, -- rubble is simulated by the server (no hand-offs between players' machines)
}

Config.PlayerMaxHealth = 300

-- Balance: no single hit takes more than MaxHitShare of someone's max health
-- (so nothing one-shots). Applied after every multiplier (ult, Trigger).
Config.Balance = {
	MaxHitShare = 0.35,
}

-- The edge of the world: invisible walls round the city's base plates (so a
-- big hit can't throw anyone off the map), a thick invisible floor under them
-- (so a hard slam can't punch through the thin street), and a safety net -
-- anyone who still ends up under the map is put back where they last stood.
Config.MapBounds = {
	Enabled = true,
	-- no invisible walls round the edge of the city: off the edge is the void
	-- (true puts the walls back)
	Walls = false,
	VoidDepth = 150, -- fallen off the edge this far below the street: KO'd
	WallHeight = 700, -- studs above the street
	WallThickness = 8,
	FloorThickness = 30,
	RescueDepth = 30, -- this far under the street (not off its edge) counts as fallen through: put back
	RescueImmunity = 1.5, -- seconds of safety after being put back
}
-- THE SKY COFFIN: the final war's floating battlefield (the U.A. grounds
-- lifted into the sky on propulsion jets, walled in by an electromagnetic
-- barrier, the generator that powers it hanging off the side) with the
-- Sports Festival stage in front of the main building. The server builds it
-- over the plaza by the middle spawn; a warp gate there takes you up.
-- ALL MIGHT vs ALL FOR ONE: every so often the two of them fight across the
-- sky over wherever each player is (the city or the Sky Coffin), everyone
-- at once. First: seconds after the server starts; Every: seconds between;
-- Length: how long it runs. It's OFF until someone switches it on in the
-- test menu (SERVER SETTINGS); its button there starts one any time.
Config.SkyBattle = {
	Enabled = true,
	First = 90,
	Every = 300,
	Length = 53,
}

-- DEKU DROPS IN: every few minutes Deku comes down out of the sky into the
-- middle of the city (Spot: the plaza by the middle spawn), craters it at
-- ImpactAt seconds (Crater studs; anyone within Radius blown off their feet
-- by Push - not hurt), gets up, and blasts back up into the sky at JumpAt.
-- OFF until someone switches it on in the test menu; its button there
-- drops him in any time.
-- BLOOD (JJS-style; each player can switch it off in SETTINGS). A hard hit
-- (MinDamage or more, or a heavy one) sprays drops out of the far side of
-- whoever took it - they fly, and splat where they land; a KO leaves a pool.
-- Deku's broken arms drip. Stains fade after StainLife, pools after
-- PoolLife. (Roblox's maturity questionnaire asks about blood: Color is
-- yours to pick.)
Config.Blood = {
	Enabled = true,
	MinDamage = 9,
	Color = Color3.fromRGB(168, 10, 20),
	DarkColor = Color3.fromRGB(104, 6, 12),
	StainLife = 9,
	PoolLife = 14,
	MaxStains = 90,
	MaxDrops = 160,
	Gravity = 110,
}

-- 100% breaks Deku's arm: it hangs off his shoulder, limp, and flops about
-- as he moves (a physics ball socket in place of the joint) till it heals
Config.BrokenArms = { Limp = true, Drip = true }

Config.DekuDrop = {
	Enabled = true,
	First = 150,
	Every = 300,
	Length = 11,
	ImpactAt = 2.4,
	JumpAt = 7.4,
	Spot = Vector3.new(-70, 26, 868),
	Crater = 11,
	Radius = 28,
	Push = 70,
}

-- (round 71) NOMU RAIDS: every so often a High-End Nomu - Hood, the one
-- Endeavor and Hawks fought - comes down into the middle of the city on its
-- shoulder jets and the whole server has to take it down together.
-- First / Every: seconds to the first one, then between them (only with
-- MinPlayers in the server; server settings: NomuRaid toggle, and "Nomu
-- Raid - Now"). Spot: where it lands (default: Deku's drop spot).
-- Health (+ PerPlayer for everyone in the server, MaxHealth at most); it
-- regenerates (Regen: PerSecond of its max once it's gone After seconds
-- untouched). Phase 2 at half health: it roars, and moves faster and hits
-- more often. TimeLimit: not beaten by then, it flies off.
-- Its moves: SWIPE (a huge backhand in front of it), SLAM (leaps on whoever
-- it's after, the street caves in round it), CHARGE (its jets fire and it
-- rams straight through), ROAR (knocks everyone near back).
-- Truce: while it's down there, players near it (TruceRadius) can't hurt
-- each other. Rewards (Bucks) for everyone who fought it: Base + a share
-- of Pool by damage done, + Top[rank] for the three who did the most (at
-- least MinShare of the damage, or MinDamage). Got away: Consolation.
Config.NomuRaid = {
	-- (round 75) off unless the server panel / console switches raids on
	-- (workspace NomuRaid = true); the panel can also kill the one that's down
	Enabled = true,
	OptIn = true,
	First = 240,
	Every = 600,
	MinPlayers = 1,
	LandAt = 2.6,
	Health = 2600,
	PerPlayer = 1400,
	MaxHealth = 16000,
	TimeLimit = 240,
	WalkSpeed = 22,
	Phase2Speed = 29,
	Aggro = 260,
	HipHeight = 6,
	Crater = 13,
	LandRadius = 34,
	Regen = { After = 6, PerSecond = 0.012 },
	Swipe = { Damage = 18, Reach = 12, Windup = 0.45, Cooldown = 1.5 },
	Slam = { Damage = 26, Radius = 18, Air = 0.85, Windup = 0.35, Cooldown = 7, Crater = 9 },
	Charge = { Damage = 20, Range = 80, Windup = 0.6, Time = 0.5, Cooldown = 6, Width = 7 },
	Roar = { Radius = 36, Push = 70 },
	Truce = true,
	TruceRadius = 260,
	Rewards = { Base = 5, Pool = 40, Top = { 10, 5, 3 }, MinShare = 0.02, MinDamage = 60, Consolation = 1 },
}

Config.SkyCoffin = {
	Enabled = true,
	-- the lawn's surface, over the middle spawn. (round 90: way up - 1,575
	-- studs over the street, was 600. The city below is past the place's
	-- streaming radius from up there and lost in the haze: a sea of clouds
	-- under it (Clouds) is what you see over the edge)
	Center = Vector3.new(-70, 1600, 888),
	Radius = 425, -- the disc (850 studs across)
	Barrier = 418, -- the pillar ring: the barrier runs between them
	BarrierHeight = 290,
	CityGate = Vector3.new(-72, 26, 857), -- the street by the middle spawn (a ray finds its exact height)
	-- touching the barrier: a jolt that locks you up for a moment and throws
	-- you back off it (no damage)
	Zap = { Stun = 0.7, Push = 55, Cooldown = 1.2 },
	-- (round 90) THE CLOUD SEA under it: Count banks of cloud (each 3 to 5
	-- puffs of Size studs across, flattened) Below studs under the lawn,
	-- from under the island out to Out x Radius from its middle
	Clouds = { Count = 52, Below = { 300, 430 }, Out = { 0.15, 3.3 }, Size = { 70, 170 } },
	-- (round 90) knocked off it, the fall to the street takes ~4 s: once
	-- you're Below studs under the lawn, still Above studs over the street
	-- (nearer than that it's streamed in already) and falling faster than
	-- MinFall, the street where you'll land is streamed in to you on the way
	-- down (every Every s) - the city's past the streaming radius up there
	FallStream = { Below = 40, Above = 600, MinFall = 30, Every = 1 },
	-- (round 90) THE SHIELD GOES DOWN (the owner: "turn off animation for
	-- the shield"). A dev flying into the barrier on the dev flight (at
	-- MinSpeed or more - the server: half that, by what it sees; one dev's
	-- breaks Gap s apart) breaks it where he hits it - a crack of Radius
	-- studs to a corner (MinSpeed up to FullAt), shards, sparks, a crackling
	-- boom - and flies straight on through (no flip, no roll: his camera
	-- gets a Flash and a Shake). Then the whole shield powers down, the
	-- failure running round the ring both ways from there (Fail: the struck
	-- panel at Start s, each one further round Step s later; each flickers
	-- and stutters for Flicker s, an arc jumping between its pillars, then
	-- its energy drains down out of it over Drain s - the roof over it Roof s
	-- behind - and it goes dark; a pillar's light dies once both its panels
	-- have, the peak's last) under a fading electric hum. The arena's open:
	-- nobody's stopped or jolted by it. Down s after the break it boots back
	-- up over Boot s - the reverse: the pillars relight round the ring from
	-- the generator, the panels fill from the ground up, the roof fades in,
	-- a surge, the peak and a snap - and it's solid again. (His own screen
	-- plays it at once and calls it off if the server hasn't confirmed it in
	-- Confirm s.) Shards: how many (half on a low-end machine), their life,
	-- speed and size; nobody past FxCull sees the shards and arcs, nobody
	-- past Cull the shield's animation
	Break = {
		MinSpeed = 60,
		FullAt = 520,
		Radius = { 9, 15 },
		Gap = 0.2,
		Fail = { Start = 0.3, Step = 0.17, Flicker = 0.6, Drain = 0.75, Roof = 0.12 },
		Down = 15,
		Boot = 3.4,
		Confirm = 1.5,
		Shards = 22,
		ShardLife = { 0.9, 1.7 },
		ShardSpeed = { 26, 110 },
		ShardSize = { 1.2, 3.4 },
		Cracks = 6,
		FxCull = 700,
		Cull = 1500,
		Flash = 0.1,
		Shake = 0.55,
		Color = Color3.fromRGB(255, 214, 90), -- the field's gold
		Hot = Color3.fromRGB(255, 249, 222), -- ...white-hot at the break, and surging
		Rim = Color3.fromRGB(255, 236, 150), -- the crack's crackling edge
		Ember = Color3.fromRGB(255, 128, 36), -- the energy draining out of a panel (and filling back in)
		Dead = Color3.fromRGB(50, 44, 36), -- a pillar's light, dead
	},
}
-- (round 90) THE BARRIER'S SHAPE, for the break (the server's Kit.SB checks
-- it, every screen draws the crack and runs the failure round it, the
-- flyer's own screen sees it coming): its faces as the server builds them
-- (QuirkServer's SC.build) - W0..W11 the walls between pillar i and i + 1,
-- R0..R11 the tent of a roof above them, and the Lid (what stops you under
-- the roof) - and its ring (pillar i at i / 12 of the way round)
do
	local SC = Config.SkyCoffin
	local B = SC.Break
	local UPV = Vector3.new(0, 1, 0)
	local made = {} -- [face] = its frame, worked out once (for where the island is)
	function B.dims()
		local RP, BH = SC.Barrier or 418, SC.BarrierHeight or 290
		return SC.Center, RP, BH, RP * math.cos(math.pi / 12), 2 * RP * math.sin(math.pi / 12)
	end
	-- the wall (0..11) a spot is round the ring at (wall i runs from pillar
	-- i to pillar i + 1)
	function B.wallAt(pos)
		local rel = (typeof(pos) == "Vector3" and pos == pos) and pos - SC.Center or Vector3.zero
		local a = math.atan2(rel.X, rel.Z) % (math.pi * 2)
		return math.floor(a / (math.pi / 6)) % 12
	end
	-- how many steps round the ring from wall (or pillar) i to j, either way (0..6)
	function B.apart(i, j)
		local d = (i - j) % 12
		return math.min(d, 12 - d)
	end
	-- pillar i's foot, on the lawn
	function B.pillar(i)
		local C, RP = B.dims()
		local a = i / 12 * math.pi * 2
		return C + Vector3.new(math.sin(a) * RP, 0, math.cos(a) * RP)
	end
	-- the pillar nearest the generator (SC.build puts it out past the rim
	-- at -(Radius + 130), 40): the boot-up starts there
	function B.genPillar()
		local a = math.atan2(-((SC.Radius or 425) + 130), 40) % (math.pi * 2)
		return math.floor(a / (math.pi / 6) + 0.5) % 12
	end
	-- a face's frame and outline: its plane (o, along u and v, out along n -
	-- out of the island, or up), the outline in (u, v) going round
	-- anticlockwise seen from n, and how thick the drawn face is. nil: no
	-- such face
	function B.frame(face)
		if type(face) ~= "string" then
			return nil
		end
		local C, RP, BH, inR, chord = B.dims()
		local had = made[face]
		if had and had.at == C and had.rp == RP and had.bh == BH then
			return had.f
		end
		local f = B.build(face, C, RP, BH, inR, chord)
		if f then
			made[face] = { at = C, rp = RP, bh = BH, f = f }
		end
		return f
	end
	function B.build(face, C, RP, BH, inR, chord)
		local kind, i = face:sub(1, 1), tonumber(face:sub(2))
		if not (i and i == math.floor(i) and i >= 0 and i <= 11) then
			return nil
		end
		if kind == "W" then
			local a = (i + 0.5) / 12 * math.pi * 2
			local n = Vector3.new(math.sin(a), 0, math.cos(a))
			local u = Vector3.new(math.cos(a), 0, -math.sin(a))
			local w = (chord - 14) / 2
			return { o = C + n * inR, u = u, v = UPV, n = n, poly = { { -w, 0 }, { w, 0 }, { w, BH }, { -w, BH } }, thick = 0.6 }
		elseif kind == "R" then
			local function top(k)
				local a = k / 12 * math.pi * 2
				return C + Vector3.new(math.sin(a) * RP, BH + 5, math.cos(a) * RP)
			end
			local A, Bv, P = top(i), top((i + 1) % 12), C + Vector3.new(0, BH + math.floor(BH * 0.27), 0)
			local o = (A + Bv + P) / 3
			local u = (Bv - A).Unit
			local n = (Bv - A):Cross(P - A).Unit
			if n.Y < 0 then
				n = -n
			end
			local v = n:Cross(u)
			local poly = {}
			for _, q in { A, Bv, P } do
				table.insert(poly, { (q - o):Dot(u), (q - o):Dot(v) })
			end
			local area = 0
			for k = 1, 3 do
				local p, q = poly[k], poly[k % 3 + 1]
				area += p[1] * q[2] - q[1] * p[2]
			end
			if area < 0 then
				poly = { poly[1], poly[3], poly[2] }
			end
			return { o = o, u = u, v = v, n = n, poly = poly, thick = 0.3 }
		end
		return nil
	end
	-- a point in a face's frame (and how far off its plane)
	function B.local2(f, pos)
		local rel = pos - f.o
		return rel:Dot(f.u), rel:Dot(f.v), rel:Dot(f.n)
	end
	function B.world(f, x, y)
		return f.o + f.u * x + f.v * y
	end
	-- is (x, y) inside the outline, `pad` studs in from every edge?
	function B.inside(f, x, y, pad)
		local poly = f.poly
		for k = 1, #poly do
			local p, q = poly[k], poly[k % #poly + 1]
			local ex, ey = q[1] - p[1], q[2] - p[2]
			local len = math.sqrt(ex * ex + ey * ey)
			-- (anticlockwise: inside is to the left of each edge)
			if (ex * (y - p[2]) - ey * (x - p[1])) / math.max(len, 1e-6) < (pad or 0) then
				return false
			end
		end
		return true
	end
	-- a hole of corner radius r (a flat-topped hexagon) as near (x, y) as it
	-- can be with all of it Margin studs inside the face (a face too small
	-- for it: a smaller hole). -> x, y, r
	function B.fit(f, x, y, r)
		local poly = f.poly
		for _ = 1, 4 do
			for k = 1, #poly do
				local p, q = poly[k], poly[k % #poly + 1]
				local ex, ey = q[1] - p[1], q[2] - p[2]
				local len = math.max(math.sqrt(ex * ex + ey * ey), 1e-6)
				local mx, my = -ey / len, ex / len -- (inward)
				-- (how far the hexagon reaches toward this edge)
				local reach = 0
				for c = 0, 5 do
					local th = c * math.pi / 3
					reach = math.max(reach, -(math.cos(th) * mx + math.sin(th) * my) * r)
				end
				local d = (x - p[1]) * mx + (y - p[2]) * my
				local need = reach + 1
				if d < need then
					x, y = x + mx * (need - d), y + my * (need - d)
				end
			end
		end
		if not B.inside(f, x, y, r * 0.86) then
			return x, y, r * 0.6
		end
		return x, y, r
	end
	-- the hole's size at a speed
	function B.radius(speed)
		local R = B.Radius or { 9, 15 }
		local k = math.clamp(((tonumber(speed) or 0) - (B.MinSpeed or 60)) / math.max((B.FullAt or 520) - (B.MinSpeed or 60), 1), 0, 1)
		return R[1] + (R[2] - R[1]) * (k == k and k or 0)
	end
	-- the first face a straight line (from p along unit d, at most len
	-- studs) goes through: { Face, T (studs along it), Pos (on the face) },
	-- walls clear of the pillars (Pillar studs either side), the Lid inside
	-- the walls, the roof's faces where they are. nil: none
	function B.cross(p, d, len, pillar)
		local C, RP, BH, inR, chord = B.dims()
		local rel = p - C
		local best
		local function take(face, t, pos)
			if t >= 0 and t <= len and (not best or t < best.T) then
				best = { Face = face, T = t, Pos = pos }
			end
		end
		-- (anywhere near it at all?)
		local r = Vector3.new(rel.X, 0, rel.Z).Magnitude
		if r > RP + len + 30 or (math.abs(r - inR) > len + 12 and (rel.Y < BH - len - 12 or rel.Y > BH + 90 + len)) then
			return nil
		end
		for i = 0, 11 do
			local a = (i + 0.5) / 12 * math.pi * 2
			local n = Vector3.new(math.sin(a), 0, math.cos(a))
			local dn = d:Dot(n)
			if math.abs(dn) > 1e-3 then
				local t = (inR - rel:Dot(n)) / dn
				local h = rel + d * t
				local u = h:Dot(Vector3.new(math.cos(a), 0, -math.sin(a)))
				if math.abs(u) <= chord / 2 - (pillar or 8.5) and h.Y >= -2 and h.Y <= BH + 38 then
					take("W" .. i, t, C + h)
				end
			end
		end
		if math.abs(d.Y) > 1e-3 then
			local t = (BH + 3 - rel.Y) / d.Y
			local h = rel + d * t
			if Vector3.new(h.X, 0, h.Z).Magnitude < inR then
				take("Lid", t, C + h)
			end
		end
		for i = 0, 11 do
			local f = B.frame("R" .. i)
			local dn = d:Dot(f.n)
			if math.abs(dn) > 1e-3 then
				local t = (f.o - p):Dot(f.n) / dn
				local x, y = B.local2(f, p + d * t)
				if B.inside(f, x, y, 0) then
					take("R" .. i, t, p + d * t)
				end
			end
		end
		return best
	end
end
Config.DummyMaxHealth = 500
Config.DummyRespawnTime = 5 -- a knocked-out dummy lies there (ragdolled) this long before it respawns

-- Training dummies you can spawn from the test menu (TEST > Spawn Dummies...).
-- They respawn as the same kind where they were spawned.
Config.DummyKinds = {
	{ Id = "Normal", Label = "DUMMY", Info = "Stands there and takes it.", Color = Color3.fromRGB(226, 196, 156) },
	{
		Id = "Finisher", Label = "FINISHER DUMMY", Info = "Spawns at its last sliver of health: walk up and press E.",
		Color = Color3.fromRGB(230, 110, 100), HealthShare = 0.1,
	},
	{
		Id = "Attack", Label = "ATTACK DUMMY", Info = "Walks at you throwing punch combos: practise blocking and parrying.",
		Color = Color3.fromRGB(235, 140, 60), WalkSpeed = 13, Damage = 6, ComboLength = 4, ComboRest = 1.3, Sight = 70,
	},
	{ Id = "Block", Label = "BLOCKING DUMMY", Info = "Always has its guard up: practise breaking it.", Color = Color3.fromRGB(120, 160, 220) },
	{
		Id = "Moving", Label = "MOVING DUMMY", Info = "Sidesteps back and forth: practise hitting a moving target.",
		Color = Color3.fromRGB(120, 200, 130), WalkSpeed = 14, Stride = 10,
	},
	{
		Id = "Tank", Label = "TANK DUMMY", Info = "5000 health, back to full 3s after you stop: test whole combos.",
		Color = Color3.fromRGB(150, 150, 160), MaxHealth = 5000, RegenDelay = 3,
	},
	{ Id = "R6", Label = "R6 DUMMY", Info = "A classic blocky R6 body.", Color = Color3.fromRGB(226, 196, 156), Rig = "R6" },
	-- (the rest are Jujutsu Shenanigans' private-server dummies)
	{
		Id = "Evasive", Label = "EVASIVE DUMMY", Info = "Ragdoll-cancels the moment its meter is full (shown over its head): bait it out.",
		Color = Color3.fromRGB(150, 235, 255), Evasive = true, Reaction = 0.2,
	},
	{
		Id = "Counter", Label = "COUNTER DUMMY", Info = "Keeps going into a counter stance: hit it then and it hits back. Wait it out.",
		Color = Color3.fromRGB(255, 200, 70), Stance = 1.1, Rest = 1.6, Damage = 10,
	},
	{ Id = "OneHP", Label = "1 HP DUMMY", Info = "One hit and it's down: test KOs and finishers' follow-through.", Color = Color3.fromRGB(255, 120, 120), MaxHealth = 1 },
}

function Config.DummyKind(id)
	for _, kind in Config.DummyKinds do
		if kind.Id == id then
			return kind
		end
	end
	return nil
end
Config.BaseWalkSpeed = 18
Config.BaseJumpPower = 50

Config.M1 = {
	-- (round 81) holding M1 throws a hit every Cooldown seconds (JJS-smooth:
	-- each swing's follow-through is the next one's coil); after the 4th
	-- there's FinisherCooldown before a new chain
	Cooldown = 0.3,
	FinisherCooldown = 1.0,
	ActionTime = 0.18,
	FinisherActionTime = 0.42,
	ComboReset = 1.1,
	ComboLength = 4,
	Damage = 4,
	FinisherDamage = 10,
	-- (round 81) when each swing's fist lands: seconds into its clip (the
	-- clips' "Hit" keys - hits 1-4, the uppercut, the downslam). The server
	-- checks its hitbox ServerLead seconds before that, so the confirmed hit
	-- reaches everyone's screen on the contact frame.
	Contact = { 0.12, 0.125, 0.13, 0.18, Up = 0.16, Down = 0.17 },
	ServerLead = 0.015,
	-- (round 81) hits 1-3 stun for this long and pin the target (no walking
	-- out of it: JJS "momentum denied") - it outlasts the cadence, so the
	-- victim stays in hit-stun from one hit to the next
	Stun = 0.7,
	-- (round 81) THE STICK (JJS): a landed hit pushes the victim about a stud
	-- (Speed studs/s held Hold seconds, then fading to 0 over Fade) and pulls
	-- the attacker the same way, never closer than MinGap studs root to root,
	-- so the two of them drift forward together and the gap holds. Pull: how
	-- far the attacker is pulled (the uppercut less: you want to be under them)
	-- (round 83) UpGap: the uppercut's step-in comes this close instead (under
	-- them - mid-chain the gap's held at MinGap, so its Step.Up step is all
	-- there and the clip's planted feet stay put)
	Stick = { Speed = 10, Hold = 0.06, Fade = 0.1, MinGap = 3, Pull = 1.1, UpPull = 0.5, UpGap = 2.2 },
	-- (round 81) the small committed step in each swing's coil (studs)
	-- (round 83: Up 0.8 - the uppercut keeps both feet on the street now, and
	-- R6 legs can't bend: its deep crouch is a long step in, which the clip's
	-- feet are planted for; never nearer than Stick.MinGap - the uppercut's
	-- Stick.UpGap - either way)
	Step = { Distance = 0.4, Finisher = 0.9, Up = 0.8 },
	-- (round 81) walk speed x this while you're chaining (the swing's step and
	-- pull do the closing; the walk keeps the legs)
	ChainWalk = 0.5,
	FinisherKnockback = 55, -- how hard the 4th hit sends them (studs/s)
	FinisherLift = 15,
	HitboxSize = Vector3.new(6.5, 6, 7.5),
	HitboxForward = 4, -- the box's centre, in front of you
	-- (round 68) what M1s do to buildings: (round 69) only the 4th breaks
	-- anything - a hole the size of a body (Finisher: width, height, depth)
	-- in whatever it lands on; the first three don't mark it
	Destruction = { Finisher = Vector3.new(4.5, 6, 4) },
	-- M1 tracking: a nudge toward the nearest opponent within Range studs
	-- and Angle degrees of where you're facing - at most MaxTurn degrees (you
	-- do the aiming; it just forgives being a little off)
	Assist = { Angle = 35, Range = 9, MaxTurn = 30 },
	-- the 4th hit ragdolls players and dummies (hold the button to keep punching)
	RagdollOnFinisher = true,
	RagdollTime = 1.3,
	-- both fighters freeze on the contact frame for this long (the anime "weight")
	Hitstop = 0.04,
	FinisherHitstop = 0.075,
	-- JJS / TSB finishers (round 63: easier, and the upslam keeps you on your
	-- feet). UPSLAM: hold jump and throw the 4th hit - you stay on the ground
	-- (holding jump through the chain never hops you, whenever you pressed
	-- it, and nor does the 4th: RiseWith 0) - it launches them straight up.
	-- DOWNSLAM: TAP jump during the chain (round 83: Slam below - you hop
	-- once hit 3's swing lets you) and throw the 4th anywhere off the ground
	-- (DownslamHeight studs will do) - it spikes them into the street. (Jump
	-- held until the chain runs out - ComboReset - is an ordinary jump again.)
	-- While both of you are airborne, M1s keep them floating up there with you.
	-- (Lift for LiftTime seconds, then they coast: ~14 studs up; you rise
	-- RiseWith after them, so the two of you meet up there for the air combo)
	-- (round 81: Forward 2 - a JJS uppercut goes straight up, so they come
	-- down in front of you)
	-- (round 83: Hitstop 0.13 - a beat longer, so the freeze covers the moment
	-- the launch takes to reach the attacker's screen; KickDeg / KickTime: the
	-- attacker's own camera tips up that many degrees on the hit and eases
	-- back over KickTime)
	Uppercut = { Lift = 55, LiftTime = 0.12, RiseWith = 0, Forward = 2, Stun = 1.3, Hitstop = 0.13, KickDeg = 2, KickTime = 0.25 },
	-- (round 75) HitboxExtra: a hair more box (width, height, depth) for the
	-- downslam
	-- (round 81) it's thrown at the top of the hop (held till you stop
	-- rising), it can't be blocked (JJS)
	-- (round 83) ONE SLAM: HopSpeed - the slam hop rises at this whatever the
	-- quirk's JumpPower (55-72 put the hammer 2-6 studs over most heads); no
	-- hang at the top - he falls through the coil drifting Drift studs/s
	-- forward, the hammer lands on the head, his body freezes with the
	-- hitstop, then he's driven down at Dive studs/s and the street takes it
	-- all at once as he lands (the crater, the ring, the sound, the impact
	-- frame, the shake). The server's crater waits max(fall / Drop, Hitstop +
	-- CraterLag) so it lands with him; a victim more than BounceFall studs up
	-- bounces off the street (Bounce), one already on it doesn't (Slide: a
	-- short push along it), and the ragdoll starts at the crater. SlamFade: a
	-- downslam with no slam hop's tuck under it (thrown off a ledge, or the
	-- hop's relay dropped) blends in from hit 3 over this long. Gap: the
	-- drift brings him no nearer than this to whoever's under him (root to
	-- root: the fists, ~2 studs out in front, on their head); Recoil: a
	-- landed one's dive carries him back off them this fast (studs/s), so he
	-- comes down about MinGap away, not in them
	Downslam = { Drop = 150, Forward = 10, Ragdoll = 1.5, Bounce = 26, Hitstop = 0.12, Crater = 3.2, HitboxExtra = Vector3.new(1.5, 1.5, 1.5), Dive = 45,
		HopSpeed = 50, Drift = 6, CraterLag = 0.08, BounceFall = 1, Slide = 2, SlamFade = 0.14, Gap = 2.2, Recoil = 8 },
	-- (round 83) THE JUMP KEY IN A GROUNDED CHAIN. Held: never a hop (the 4th
	-- is the upslam). A tap - pressed and let go inside TapMax seconds - is the
	-- hop for the downslam: after hit 1 or 2 it waits for hit 3's swing -
	-- unless no M1 comes by Cooldown + ArmWait after the last one (slower
	-- than any clicked chain), when it was a jump out of the chain: an
	-- ordinary jump. UpCommit: a 4th thrown within this of jump going down
	-- waits that long to see whether it's a tap. AirGrace: the feet off the
	-- street for less than this (a curb, a slope) isn't leaving it.
	-- (round 84) AFTER HIT 3 THE HOP GOES ON THE PRESS - it doesn't wait for
	-- you to let go (that, and the server's late copy of hit 3's lock, was
	-- the "takes too long to jump"): as soon as hit 3's swing lets you, or
	-- PressGrace after the press if it already has (room for Space and the
	-- 4th's click pressed together: that's the upslam). Held through hit 3's
	-- swing with the 4th clicked into it, it's the upslam (JJS / TSB: hold
	-- jump through the 3rd's recovery and M1); held from before hit 3,
	-- still never a hop. One press is one jump: still held when you land,
	-- it doesn't jump you again
	Slam = { TapMax = 0.2, UpCommit = 0.1, ArmWait = 0.12, AirGrace = 0.1, PressGrace = 0.04 },
	AirJuggle = { Up = 26, Forward = 3, Stun = 0.7 },
	MinAirHeight = 3, -- studs between your feet and the ground that count as "in the air"
	DownslamHeight = 0.25, -- (round 63) off the ground enough for a downslam (round 75: lower)
	-- Fighting style per quirk: Brawler (straight, hook, uppercut, power
	-- straight), Kicks (snap kick, two roundhouses, axe kick), Claw (open-hand
	-- rakes) or Mixed (hands and feet). A table picks per form:
	-- { Base = ..., Alt = ... (R form), Ult = ... }. Anything unlisted brawls.
	-- (round 85) Engine: Iida's own kicks (VFX M1_SETS.Engine, keyframed),
	-- so Deku's forms keep the shared Kicks set
	Styles = {
		Engine = "Engine",
		Decay = "Claw",
		FullCowl = { Base = "Mixed", Ult = "Kicks" }, -- fists and feet; all Shoot Style at 100%
		PrimeDeku = { Base = "Mixed", Ult = "Kicks" }, -- (round 74)
		Limitless = "Mixed",
		Overhaul = "Claw", -- open-hand touches: every one of them can take you apart
		Manifest = "Mixed", -- a tentacle lash, a talon kick, a clam fist, a crab-shell kick
		Creation = "Weapon", -- (round 60) Creati swings the staff / sword / spear in her hand
		FierceWings = "Feather", -- (round 86) Hawks: his two longest primaries drawn as swords (VFX.WeaponKit.Feather)
	},
}

-- Ragdoll: any hit that knocks someone back at MinSpeed or faster (the big
-- moves: smashes, blasts, finishers) sends them limp for Time..MaxTime
-- seconds (harder hits last longer). While limp they can't act, and the
-- knockback is scaled by KnockbackScale and pushed with at most MaxForce so
-- the body tumbles instead of rocketing off.
Config.Ragdoll = {
	Enabled = true,
	OnMoves = true,
	MinSpeed = 100,
	Time = 1.3,
	MaxTime = 2.2,
	KnockbackScale = 0.8,
	MaxForce = 30000,
	-- how long a ragdoll lasts follows how hard the hit was: the move's own
	-- time x (Base + damage / PerDamage), kept within Min..Max - a jab puts
	-- you down briefly, a smash for a good while - then x Longer for everyone,
	-- never past Cap seconds
	Strength = { Base = 0.7, PerDamage = 40, Min = 0.8, Max = 1.45, Longer = 1.15, Cap = 3 },
	-- KOs: the body goes limp and flies with the finishing hit instead of
	-- falling apart (players and training dummies)
	OnDeath = true,
	-- KNOCKDOWNS: a move that lands MinDamage or more knocks them off their
	-- feet - down on the street for Time seconds (harder hits longer, as
	-- above) - instead of just stunning them. Not a move that holds them
	-- (a grab, a freeze, a bind, a juggle: NoKnockdown on the ability).
	-- While they're down, anything but the move that put them there only does
	-- DownedScale of its damage, and getting up gives WakeGuard seconds where
	-- no move can knock them straight back down: no stomping on someone lying
	-- in the street, no chaining them down again - the fight breaks and
	-- resets instead of one player spamming the other. (Server settings can
	-- switch it off: workspace attribute Knockdowns = false.)
	Knockdown = { Enabled = true, MinDamage = 7, Time = 1.1, DownedScale = 0.6, WakeGuard = 1 },
	-- (round 63) SMOOTHER: every joint has a little friction (JointFriction:
	-- the limbs still flop under their own weight but don't flail or
	-- shiver), nothing bounces (the limbs' colliders have no give and a good
	-- grip on the street), the limbs set off with the body's speed (they
	-- don't trail behind the push), and getting up starts from where you lie:
	-- on your back you sit up, face down you push yourself up (the GetUpBack
	-- / GetUpFront clips), right where the body is - no pop to standing.
	JointFriction = 25,
	-- (round 59) DOWN MEANS DOWN: nothing hits someone who's ragdolled - no
	-- M1s, no uppercuts, no moves. Only a DOWNSLAM (the 4th M1 from the air:
	-- it's what it's for) lands, in full; and a move still finishes its own
	-- hits on whoever it put down, a finisher still finishes, and a burn
	-- keeps burning. (Server settings: workspace attribute DownImmune = false.)
	DownImmune = true,
}

-- (round 68) COMBOS: Suneater, Deku, All Might and Creati chain their moves.
-- A hit from one of their moves doesn't knock the target down or ragdoll
-- them - that ended every combo, since nothing hits someone who's down - it
-- holds them in HITSTUN where they stand (Stun: Base + damage x PerDamage,
-- at most Max; a move's own longer stun still wins), and the shove is kept
-- to MaxShove studs/s across and MaxLift up so the next hit reaches (Keep:
-- launchers whose lift IS the combo). Their ENDERS - and, UltMovesEnd,
-- every move of their ult forms - still send you flying or put you down,
-- as before. The ragdoll cancel (Config.Evasive) breaks out of a combo's
-- hitstun as well as a ragdoll, like JJS. (Server settings: workspace
-- attribute Combos = false switches it off.)
Config.Combos = {
	Enabled = true,
	Heroes = { Manifest = true, FullCowl = true, OneForAll = true, Creation = true, PrimeDeku = true, PrimeMight = true },
	Stun = { Base = 0.65, PerDamage = 0.02, Max = 1.2 },
	MaxShove = 38,
	MaxLift = 42,
	Keep = { ChickenKick = true },
	UltMovesEnd = true,
	Enders = {
		-- Deku: the big axe kick, Fa Jin's gale, Gearshift's Transmission, 100%
		-- Detroit Smash, Blackwhip's slam, Infinite 100%
		ManchesterSmash = true, FaJinSmash = true, Gearshift = true, HundredSmash = true, BlackwhipSlam = true, FistRain = true,
		-- All Might: Detroit Smash, Hero's Counter, the suplex, 100% Texas Smash, United States of Smash
		DetroitSmash = true, HeroCounter = true, BackdropDriver = true, TexasSmashMax = true, UnitedStatesSmash = true,
		-- Suneater: the chimera's charge and Scorpius Toxin
		Centaur = true, OctopusMirage = true,
		-- Creati: the cannons
		GrandCannon = true, DischargeCannon = true,
		-- (round 74) Prime Deku and Prime All Might: everything but the air bullets
		PrimeFlashStep = true, BlackwhipReel = true, VestigeSmash = true, FlashStepChain = true, VestigeDDS = true, DangerCounter = true,
		MissouriSmash = true, HurricaneSmash = true, PrimeDetroit = true, IAmHereLeap = true, PlusUltraUSJ = true, PrimeUSS = true,
	},
}

-- KO FINISHERS: a move's killing blow plays out - time slows for everyone
-- near, the one who landed it strikes a pose, their quirk bursts off the
-- body as it's launched (Launch studs/s along the hit, Lift up), and their
-- camera swings round for a moment to watch (KillCam, CamTime seconds).
-- (round 71) QUIRK CLASHES, the way Jujutsu Shenanigans does its beam
-- clashes: two big moves aimed at each other meet in the middle and push.
-- Both players are locked in, and a prompt comes up - one of three buttons
-- (Keys: W A D on a keyboard; PadKeys on a controller; on a phone the
-- button jumps round the screen). The right one shoves the meeting point
-- a Step towards them; the wrong one knocks you back half a step and locks
-- you out for WrongPenalty. Push it all the way and it's over; otherwise
-- whoever's ahead when Time runs out wins, and their move goes through:
-- WinDamage x its damage (MinDamage..MaxDamage), a blast that sends them
-- flying. Dead level (inside Draw): it all goes up between them
-- (DrawDamage each). Anyone else too near the meeting point is caught in it
-- (SplashDamage every half second, within SplashRadius).
-- When: a clash move (Moves) is "out" for Window seconds after it's used;
-- if it hits someone whose own clash move is out and aimed back at them
-- (Facing: how squarely, as a dot product), it's a clash instead of a hit.
-- Server settings: workspace attribute Clashes = false turns them off.
Config.Clash = {
	Enabled = true,
	Window = 1.2,
	Facing = 0.55,
	MinRange = 4,
	MaxRange = 160,
	Time = 10,
	Step = 0.055,
	UltStep = 0.066, -- (an ult form's move pushes a little harder)
	WrongPenalty = 0.35,
	MinGap = 0.07,
	Draw = 0.06,
	Keys = { "W", "A", "D" },
	PadKeys = { W = "ButtonY", A = "ButtonX", D = "ButtonB" },
	PadLabels = { W = "Y", A = "X", D = "B" },
	WinDamage = 1.5,
	MinDamage = 28,
	MaxDamage = 80,
	DrawDamage = 16,
	SplashRadius = 11,
	SplashDamage = 5,
	-- the moves that clash: [move Id] = { Color = the beam, Core = its
	-- white-hot middle, Width = how thick (studs), Kind = what it looks like
	-- where it meets: "fire" | "wind" | "lightning" | "energy" }
	Moves = {
		APShot = { Color = Color3.fromRGB(255, 160, 50), Core = Color3.fromRGB(255, 244, 210), Width = 3.2, Kind = "fire" },
		AutoCannon = { Color = Color3.fromRGB(255, 160, 50), Core = Color3.fromRGB(255, 244, 210), Width = 3.6, Kind = "fire" },
		MaxCapacity = { Color = Color3.fromRGB(255, 150, 40), Core = Color3.fromRGB(255, 248, 220), Width = 6.5, Kind = "fire" }, -- (round 92: Bakugo's gauntlet)
		DetroitSmash = { Color = Color3.fromRGB(250, 236, 196), Core = Color3.fromRGB(255, 255, 255), Width = 5, Kind = "wind" },
		TexasSmashMax = { Color = Color3.fromRGB(255, 226, 150), Core = Color3.fromRGB(255, 255, 255), Width = 6, Kind = "wind" },
		DelawareSmash = { Color = Color3.fromRGB(120, 255, 160), Core = Color3.fromRGB(236, 255, 240), Width = 3.4, Kind = "lightning" },
		StLouisSmash = { Color = Color3.fromRGB(120, 255, 160), Core = Color3.fromRGB(236, 255, 240), Width = 4, Kind = "lightning" },
		HundredSmash = { Color = Color3.fromRGB(110, 255, 150), Core = Color3.fromRGB(240, 255, 244), Width = 5.5, Kind = "lightning" },
		MillionSmash = { Color = Color3.fromRGB(110, 255, 150), Core = Color3.fromRGB(240, 255, 244), Width = 7, Kind = "lightning" },
		Flashfire = { Color = Color3.fromRGB(255, 110, 40), Core = Color3.fromRGB(255, 236, 180), Width = 4, Kind = "fire" },
		Heatwave = { Color = Color3.fromRGB(255, 96, 36), Core = Color3.fromRGB(255, 236, 180), Width = 5.5, Kind = "fire" },
		HeatwaveMax = { Color = Color3.fromRGB(255, 96, 36), Core = Color3.fromRGB(255, 236, 180), Width = 6.5, Kind = "fire" },
		ReversalRed = { Color = Color3.fromRGB(255, 46, 66), Core = Color3.fromRGB(255, 220, 226), Width = 4.5, Kind = "energy" },
		RedMax = { Color = Color3.fromRGB(255, 46, 66), Core = Color3.fromRGB(255, 220, 226), Width = 5.5, Kind = "energy" },
		HollowPurple = { Color = Color3.fromRGB(170, 80, 255), Core = Color3.fromRGB(240, 222, 255), Width = 6, Kind = "energy" },
		PurpleMax = { Color = Color3.fromRGB(170, 80, 255), Core = Color3.fromRGB(240, 222, 255), Width = 7.5, Kind = "energy" },
		PlasmaCannon = { Color = Color3.fromRGB(110, 200, 255), Core = Color3.fromRGB(230, 246, 255), Width = 5, Kind = "energy" },
		GrandCannon = { Color = Color3.fromRGB(255, 196, 220), Core = Color3.fromRGB(255, 246, 250), Width = 4.5, Kind = "energy" },
		DischargeCannon = { Color = Color3.fromRGB(255, 226, 80), Core = Color3.fromRGB(255, 252, 226), Width = 4.5, Kind = "lightning" },
		JetBurn = { Color = Color3.fromRGB(255, 110, 36), Core = Color3.fromRGB(255, 236, 180), Width = 4.5, Kind = "fire" },
		BlueJetBurn = { Color = Color3.fromRGB(70, 140, 255), Core = Color3.fromRGB(220, 236, 255), Width = 4.5, Kind = "fire" },
		Cremation = { Color = Color3.fromRGB(70, 140, 255), Core = Color3.fromRGB(220, 236, 255), Width = 5, Kind = "fire" },
		BlueProminence = { Color = Color3.fromRGB(70, 140, 255), Core = Color3.fromRGB(220, 236, 255), Width = 6.5, Kind = "fire" },
	},
}

Config.KOFinisher = { Enabled = true, KillCam = true, CamTime = 1, SlowMo = 0.9, Launch = 95, Lift = 70 }

-- Knockback from moves (not M1s, the dash punch or Chicken Kick's launch -
-- their push is the combo): the sideways shove x MoveScale, the lift x
-- MoveLift. A spike down keeps its full force. (Whether a hit knocks you off
-- your feet, and how long for, still goes on the move's full force.)
Config.Knockback = { MoveScale = 0.7, MoveLift = 0.88 }

-- RAGDOLL CANCEL (Jujutsu Shenanigans' "evasive"): press DASH while you're
-- ragdolled and the meter is full - you're up on your feet at once with a
-- quickstep in the direction you're holding (or to the side), a gust of
-- wind, IFrames seconds of invincibility and the meter back to empty.
-- It refills from fighting: full after TAKING TakenToFill damage or DEALING
-- DealtToFill; at or below LowHealth of your health it fills faster (taken
-- x LowTakenMult, dealt x LowDealtMult). A KO fills it; you spawn with it
-- full. Getting up (either way) gives WakeImmune seconds where M1s can't
-- stun or ragdoll you (no infinite punch loops on someone getting up).
-- Grabs, finishers and freezes can't be cancelled.
Config.Evasive = {
	Enabled = true,
	TakenToFill = 120,
	DealtToFill = 260,
	LowHealth = 0.5,
	LowTakenMult = 1.23,
	LowDealtMult = 2,
	IFrames = 1,
	WakeImmune = 0.75,
	Quickstep = { Speed = 75, Time = 0.18 },
}

-- Movement: hold to sprint, tap to dash in the direction you're moving
Config.Movement = {
	SprintMultiplier = 1.55,
	SprintFov = 78,
	NormalFov = 70,
	DashSpeed = 92,
	DashTime = 0.22,
	-- front and side dashes follow your camera the whole way (aimed), and last
	-- a touch longer so there's time to steer them
	SteerDashes = true,
	FrontDashTime = 0.28,
	SideDashTime = 0.2,
	FrontDashCooldown = 5,
	MobilityDashCooldown = 2,
	FrontWhiffRecovery = 0.18,
	DashHitRecovery = 0.08,
	InputBuffer = 0.14,
	DashCooldown = 2, -- HUD fallback; front and mobility use separate timers
	-- JJS: a front dash that reaches someone ends in a punch (it stops you
	-- right there): Damage, a short stun, a small shove. A guard blocks it.
	-- (JJS) a front dash into someone is a combo starter: stunned where they
	-- stand for Stun seconds (StunWalk: how fast they can shuffle meanwhile),
	-- barely pushed (Push) so the M1s that follow connect. (round 68) A GUT
	-- PUNCH to the FIRST one IN YOUR PATH: a lane Width either side of the
	-- way you're dashing, Reach ahead - they double over it for the stun
	DashPunch = { Damage = 6, Reach = 6, Width = 2.2, Height = 5, Stun = 1.1, StunWalk = 0, Push = 3, Hitstop = 0.09 },
	AirDashes = 1, -- extra dashes allowed per jump
	DashIFrames = 0.22, -- seconds of invincibility at the start of a dash
	-- (round 65) THE BACK DASH is Rampage Showdown's Sukuna: a backflip
	-- straight into a handstand and over onto his feet. It carries him for
	-- BackDashTime seconds at BackDashSpeed x DashSpeed (about as far as a
	-- front dash), steers with the camera like the others, and he's free
	-- BackDashRecovery after it, as his feet come down
	-- (round 66) ...then up flat on his back and a full 360 twist while he's
	-- horizontal, a longer handstand, and a three-point superhero landing:
	-- he's free as it lands. It keeps its own pace (BackDashCurve: { seconds
	-- in, x the speed }): flat out through the flip and the twist, only
	-- drifting while he's on his hands. BackDashBeats: when the twist, the
	-- hands and the landing come (the effects keep time with the clip).
	-- (round 67: all of it a little quicker - x0.85 - and faster over the
	-- ground to match, so it still covers about the same distance)
	BackDashTime = 0.66,
	BackDashSpeed = 0.54,
	BackDashRecovery = 0.08,
	BackDashHop = 0,
	BackDashCurve = { { 0, 1 }, { 0.43, 1 }, { 0.51, 0.32 }, { 0.65, 0.28 }, { 0.66, 0.2 } },
	BackDashBeats = { Twist = 0.3, Hands = 0.52, Land = 0.74 },
	-- (round 65, JJS) a side or back dash can cut into your own M1: thrown
	-- during the swing's startup, the punch still comes out from wherever the
	-- dash takes you (the "side-dash M1" - round a guard). Only an M1, never
	-- a move, and never a front dash.
	DashOutOfM1 = true,
	-- (round 65, JJS's anti-run) your front dash is cooling down and the
	-- player you're aiming at (within Range studs, Angle degrees of the
	-- middle of the screen) has turned their back and is running (MinSpeed):
	-- the dash key still throws you after them - a CHASE dash forward on the
	-- side-dash timer (Time seconds; no punch at the end)
	ChaseDash = { Enabled = true, Range = 45, Angle = 22, MinSpeed = 12, Time = 0.24 },
	-- How moving FEELS - Jujutsu Shenanigans' way: you start and stop on a
	-- dime (no skids, no stagger when you land), a run picks up almost at
	-- once, every jump is the same height, you fall at normal gravity, and
	-- you move a little slower the more hurt you are.
	Feel = {
		RunBuild = 0.15, -- walking -> a full run (seconds)
		HurtSlow = 0.15, -- at 0 HP you'd move this share slower (speed follows health)
		CoyoteTime = 0.1, -- you can still jump this long after running off an edge
		JumpBuffer = 0.1, -- a jump pressed this long before you land goes off as you land
		MaxFallSpeed = 150, -- studs/s
	},
}

-- (round 65) LOOKING AROUND, JJS-style: the camera answers the moment you
-- move. The mouse always did; now SHIFT LOCK turns your body with the camera
-- the same frame (InstantShiftLock - no easing round after it), your head
-- follows the look faster, and a CONTROLLER's right stick turns the camera in
-- proportion to how far it's pushed from the first moment (Roblox's own
-- camera eases a small push in on a curve): Speed / PitchSpeed degrees a
-- second at full tilt, Deadzone, Curve (1 = a straight line). ((round 92)
-- LockOnFollow went with the lock-on.)
Config.Look = {
	InstantShiftLock = true,
	-- (round 68) x the player's CONTROLLER SENSITIVITY (the settings: 50% to
	-- 300%); ROBLOX CAMERA in the settings hands the stick back to Roblox's
	-- own camera and its sensitivity instead
	Pad = { Enabled = true, Speed = 250, PitchSpeed = 190, Deadzone = 0.12, Curve = 1.25 },
	-- (round 82) A PHONE's buttons: a finger that lands on one fires nothing
	-- yet. Moved more than Slop GUI pixels from where it landed first, it's a
	-- camera drag and never fires. Still for Commit seconds (FastCommit for
	-- the parry and the dodge), it's a hold: down then, up when it lifts.
	-- Lifted first, it's a tap: down on the lift, and for a move you can
	-- hold, up TapHold seconds later (a BLOCK tap is a quick guard). A drag
	-- (or a held finger that moves on) turns the camera Speed degrees per
	-- pixel, the way Roblox's own touch camera does.
	Touch = {
		Slop = 10,
		Commit = 0.1,
		FastCommit = { QuirkBlock = 0.06, QuirkDash = 0.06 },
		TapHold = 0.1,
		Speed = { Yaw = 1, Pitch = 0.66 },
	},
}

-- Ultimates (G). The meter fills from 0 to 100.
-- (round 59) The ult is EARNED: it doesn't fill on its own, or from taking
-- hits, blocking, parrying or a KO bonus - only from the damage you DEAL.
-- A full meter is KillsToFill players' worth of it (1.5 x 300 health = 450).
Config.Ult = {
	KillsToFill = 1.5,
	GainPerDamageDealt = 100 / (Config.PlayerMaxHealth * 1.5),
	GainPerDamageTaken = 0,
	PassivePerSecond = 0,
	DamageMultiplier = 1.15, -- all your damage while ulting
	StudioChargeMultiplier = 1, -- (1: Studio charges like a live server - the test menu can fill it)
	ActivationRadius = 26, -- activating blasts nearby enemies away
	ActivationDamage = 12,
	ActivationArmor = 1.3, -- popping it: untouchable through the awakening
	MoveArmor = 0.6, -- an ult move can't be traded mid-swing (at least this, or its ActionTime)
}

-- (round 59) AWAKENING OUTFITS: pick one of your saved Roblox outfits (the
-- phone's OUTFIT app) and you wear it while you're awakened (the ult) - your
-- own look comes back when it ends. Saved with your data. Max: how many of
-- your outfits the app lists.
Config.AwakeningOutfits = { Enabled = true, Max = 60 }

-- HERO RANKS: lifetime kills (saved) climb the ladder. Short = the player
-- list's column; dummies don't count (Fights.DummyKOsCount).
Config.Ranks = {
	{ Name = "STUDENT", Short = "Student", Kills = 0, Color = Color3.fromRGB(196, 200, 212) },
	{ Name = "LICENSED PRE-HERO", Short = "Pre-Hero", Kills = 10, Color = Color3.fromRGB(120, 196, 255) },
	{ Name = "U.A. GRADUATE", Short = "U.A. Grad", Kills = 30, Color = Color3.fromRGB(96, 226, 150) },
	{ Name = "SEMI-PRO", Short = "Semi-Pro", Kills = 75, Color = Color3.fromRGB(255, 212, 84) },
	{ Name = "PRO HERO", Short = "Pro Hero", Kills = 150, Color = Color3.fromRGB(255, 146, 64) },
	{ Name = "TOP 10 HERO", Short = "Top 10", Kills = 300, Color = Color3.fromRGB(255, 84, 84) },
	{ Name = "NO. 1 HERO", Short = "No. 1 Hero", Kills = 600, Color = Color3.fromRGB(255, 228, 120) },
}
-- the rank a kill count has earned (its index and entry), and the next one
function Config.RankOf(kills)
	local index = 1
	for i, r in Config.Ranks do
		if (kills or 0) >= r.Kills then
			index = i
		end
	end
	return index, Config.Ranks[index], Config.Ranks[index + 1]
end
-- TOP HEROES (the HUD's leaderboard, L): the most kills of all time
Config.Leaderboard = { Enabled = true, Store = "QuirkBattlegrounds_Kills_v1", Size = 10, Refresh = 60 }

---------------------------------------------------------------------------
-- (round 95) RANKED DUELS. The owner: "Let's do 3!" - ranked duels in the
-- Sky Coffin. One on one on the Sports Festival stage up on the Sky Coffin
-- (the one-on-one tournament's own), first to Wins rounds (MaxRounds at
-- most). Join from the phone's RANKED app; the server pairs the two in the
-- queue nearest in rating (Match: within Range points, widening by Widen
-- every WidenEvery s waited). Both are taken up to the stage (where they
-- were and their hero kept), healed, their cooldowns and ult meter reset,
-- any flight ended, and held on their marks through the Countdown.
--   A ROUND is won by a KO (nobody dies: the blow that would have killed
--   leaves them at 1 and down), a RING OUT - off the stage and down on the
--   ground round it, as at the Sports Festival (Stage.Half studs from its
--   middle, under the stage's top + OutBelow) - or, at RoundTime, more
--   health left (even: a draw, no point). Between rounds (Between s) the
--   stage is put back and they start again from their marks.
--   NOBODY ELSE touches them meanwhile, and they touch nobody else; anyone
--   else on the stage is thrown off it (PushOut); no finishers. They can't
--   switch hero, use the dev flight, possess or be possessed.
--   RATING: the winner's goes up and the loser's down by the Elo rule (K;
--   KNew for someone's first Placement matches), never under Floor.
--   Leaving mid-duel loses it; dying some other way (the void, a reset)
--   loses the round (back on the marks once they're back, RespawnWait s).
--   SAVED as Bucks are (DataStore; Studio keeps its own unless
--   StudioSaves); the best of every server on the RANKED app's board
--   (Board, BoardSize, refreshed every BoardRefresh s).
--   TIERS: the rating each starts at, and its colour - over their head too
--   once they've played one (Tag, seen from TagDistance studs). Dev-only
--   heroes can't queue. Intro: the VS card before round 1.
---------------------------------------------------------------------------
Config.Ranked = {
	Enabled = true,
	DataStore = "QuirkBattlegrounds_Ranked_v1",
	Board = "QuirkBattlegrounds_RankedBoard_v1",
	BoardSize = 10,
	BoardRefresh = 60,
	StudioSaves = false,
	Start = 1000,
	K = 32,
	KNew = 48,
	Placement = 10,
	Floor = 0,
	Wins = 2,
	MaxRounds = 5,
	RoundTime = 90,
	Countdown = 3,
	Between = 3,
	EndHold = 4.5,
	Intro = 2.5,
	RespawnWait = 10,
	Tag = true,
	TagDistance = 70,
	Match = { Range = 200, Widen = 100, WidenEvery = 10, Every = 1 },
	-- the stage: its middle from the Sky Coffin's (its top's surface), half
	-- its width, the marks (Spot studs out either side), and the push that
	-- throws anyone else off it
	Stage = { Offset = Vector3.new(0, 4.8, -10), Half = 42, Spot = 22, OutBelow = 1, PushOut = 70 },
	Tiers = {
		{ Name = "ROOKIE", Min = 0, Color = Color3.fromRGB(196, 140, 98) },
		{ Name = "SIDEKICK", Min = 900, Color = Color3.fromRGB(196, 204, 220) },
		{ Name = "PRO HERO", Min = 1100, Color = Color3.fromRGB(255, 206, 70) },
		{ Name = "TOP 100", Min = 1300, Color = Color3.fromRGB(70, 214, 200) },
		{ Name = "TOP 10", Min = 1500, Color = Color3.fromRGB(186, 110, 255) },
		{ Name = "SYMBOL OF PEACE", Min = 1700, Color = Color3.fromRGB(255, 92, 80) },
	},
}
-- the tier a rating is in (its index and entry)
function Config.RankedTier(rating)
	local tiers = Config.Ranked.Tiers
	local best = 1
	for i, t in tiers do
		if (tonumber(rating) or 0) >= t.Min then
			best = i
		end
	end
	return best, tiers[best]
end
-- what a match moves each rating by (the Elo rule): the winner's gain and
-- the loser's loss (both whole, at least 1), each by their own K
function Config.RankedDelta(winnerRating, loserRating, kWinner, kLoser)
	local R = Config.Ranked
	local expect = 1 / (1 + 10 ^ (((tonumber(loserRating) or R.Start) - (tonumber(winnerRating) or R.Start)) / 400))
	local gain = math.max(1, math.floor((kWinner or R.K) * (1 - expect) + 0.5))
	local loss = math.max(1, math.floor((kLoser or R.K) * (1 - expect) + 0.5))
	return gain, loss
end

---------------------------------------------------------------------------
-- (round 96) DISMANTLE (Kit.DM) - the owner: "Make it so when I draw click
-- my mouse across a building it slices like sukuna dismantle and causes the
-- building destruction". The dev flight's people only (Kit.DF.allowed).
-- Key (U) - or the test menu's DISMANTLE - arms it: the mouse is freed (the
-- shift lock's off till it's put away) and a left-click DRAG draws the cut
-- on the screen; letting go cuts. The cut is the flat sheet through the
-- camera and the drawn line: everything it crosses in the drawn stretch
-- (Pad degrees past each end), out to Range studs from the camera, is cut
-- along it, right through - buildings, trees, streetlights, benches, bins,
-- bushes (Folders).
--   Over a slanted or flat cut the top SLIDES OFF down the cut (a cut
--   flatter than Slide.Flat: along the drawn line) - Slide.Delay first,
--   the cut glowing, then from Start studs/s, Accel (down a slope: x its
--   steepness, at least 0.35 of it) up to Max - till it's
--   clear of what's left under it (+ ClearPad), then FALLS, tipping over
--   (Fall.Spin rad/s, at most Fall.Tilt), onto the street or whatever's
--   under it: it smashes (Impact.Debris chunks flung, a Crater, the dust)
--   and anyone within Impact.Radius is hit and thrown. An upright cut
--   (|normal.Y| under Upright) TOPPLES the smaller side over, away from
--   the cut (Topple). Anyone the sheet passes through (BodyWidth either
--   side) takes Damage; where it meets the street it leaves a gash (Gash:
--   a stretch every Spacing studs, Max a cut, Budget parts each).
--   The cut: pieces at most Step studs off the true cut (a fine staircase
--   on a slanted one), never under MinSize, PerPart pieces at most out of
--   one part, Budget new parts a cut (past it a part goes whole to the side
--   its middle's on); no new cut while MaxMoving pieces are still moving.
--   It all grows back as anything broken does (Config.Destruction's
--   RegenTime after it lands).
---------------------------------------------------------------------------
Config.Dismantle = {
	Enabled = true,
	Key = Enum.KeyCode.U,
	MinStroke = 40, -- (pixels: a shorter drag is a click, not a cut)
	Range = 900, -- (studs from the camera)
	Reach = 450, -- (the camera at most this far from his body)
	MaxAngle = 150, -- (degrees: the widest drawn stretch)
	Pad = 2, -- (degrees past each end of the drawn line)
	Cooldown = 0.5,
	Rays = 40, -- (samples along the cut: where it shows, where it meets the street)
	Folders = { "Buildings", "Trees", "Streetlights", "Benches", "Dumpster", "Bushes" },
	Upright = 0.3,
	Step = 1.2,
	MinSize = 3,
	PerPart = 256,
	Budget = 3000,
	MaxMoving = 7000,
	Damage = 30,
	BodyWidth = 3.5,
	Slide = { Delay = 0.35, Start = 3, Accel = 34, Max = 55, MaxTime = 3.5, ClearPad = 4, Flat = 0.26, Sink = 3 },
	Fall = { Spin = 0.7, Tilt = 1.2, MaxTime = 6 },
	Topple = { Gap = 1.5, Accel = 2.4, Angle = 82 },
	Impact = { Debris = 50, Crater = 14, Damage = 25, Radius = 32, Push = 90, Lift = 60 },
	Gash = { Radius = 1.4, MaxGap = 30, Spacing = 24, Max = 10, Budget = 60 },
}

---------------------------------------------------------------------------
-- (round 97) ANTI-EXPLOIT (Kit.AX) - the owner: "Sure do the anti exploit".
-- The server already decides hits, damage, cooldowns, Bucks and every dev
-- feature; what it took on trust was where a body is (each player's own
-- machine moves their own body). The WATCHDOG looks at everyone's body
-- every Tick s - not testers, nor the dev flight's people (CheckTesters:
-- them too, to try it in Studio) - and flags what nothing in the game can
-- do: faster than Speed.Max studs/s flat over Speed.Window s, a jump of
-- Teleport studs between two looks, rising faster than Rise studs/s,
-- Hover.Time s in the air without falling (no ground within Hover.Ground
-- studs under them), spinning faster than Spin rad/s (SpinCarried while
-- something's moving them), going faster than Fling studs/s. Anything that
-- moves a body for real excuses it, and for Grace s after: a request of
-- theirs (every move, dash, parkour and flight asks the server), the
-- server moving it (a respawn, a warp, a grab, a ranked mark), a force the
-- server put on it (a hit's knockback, Zero Gravity) and the states that
-- carry it (ragdolled, grabbed, carried, flying, phasing, stopped time...).
-- Low gravity (under LowGravity, Moon Gravity, Zero Gravity): no rising or
-- hovering checks.
--   MODE "Log" (as shipped: run it a while, see what it would catch, no
--   false alarms?) only notes them: the F2 console's `flags` and `ax`, a
--   line in a live server's output, a toast for the owner in the server
--   (Notify). "Enforce" also acts: back to where they last stood (Pull:
--   speed, teleport, rising, hovering), a flinger's body out of everyone's
--   way for Quarantine s, and at KickAt points (0: never) a kick. "Off".
--   The console's `ax enforce` / `ax log` / `ax off` switches one server.
--   Each flag is Points[kind]; Decay of them forgotten a second. LogGap s
--   between two lines for the same player and kind; LogSize kept.
-- REQUESTS: past Requests.Rate a second (Burst at once): flagged (Spam;
--   Enforce: dropped).
-- CLASH: presses no faster than Clash.MaxRate a second; Clash.Run presses
--   in a row spaced more evenly than Clash.Steady s (a hand can't): Clash.
-- FARMING (whatever the mode; testers and the dev flight's people are
--   never limited either): KO the same player more than Farm.Free
--   times in Farm.Window s and the rest pay nothing - no Bucks, KO count,
--   streak, ult or heal; dummies pay at most Farm.DummyBucks a Window; a
--   ranked match with someone you've played Farm.RankedFree times in
--   Farm.RankedWindow s is unrated.
---------------------------------------------------------------------------
Config.AntiExploit = {
	Enabled = true,
	Mode = "Log", -- "Log" | "Enforce" | "Off"
	CheckTesters = false,
	Tick = 0.25,
	Grace = 2.5,
	Speed = { Max = 75, Window = 1 },
	Teleport = 45,
	Rise = 95,
	Hover = { Time = 3, Ground = 14, Fall = 4 },
	Spin = 100,
	SpinCarried = 400,
	Fling = 800,
	LowGravity = 150,
	Points = { Speed = 1, Teleport = 3, Rise = 1, Hover = 2, Spin = 3, Fling = 2, Spam = 1, Clash = 1 },
	Decay = 0.1,
	KickAt = 0,
	KickMessage = "Removed by the server's anti-cheat. If that's a mistake, rejoin.",
	Quarantine = 8,
	LogGap = 4,
	LogSize = 300,
	Notify = true,
	Requests = { Rate = 40, Burst = 80 },
	Clash = { MaxRate = 11, Run = 12, Steady = 0.006 },
	Farm = { Enabled = true, Window = 600, Free = 3, DummyBucks = 20, RankedWindow = 3600, RankedFree = 2 },
}

-- Map destruction (parts with the Destroyable attribute set to true)
Config.Destruction = {
	Enabled = true,
	RegenTime = 40, -- seconds after the last hit before a broken part rebuilds
	DebrisLifetime = 7, -- seconds flying chunks stay around
	MaxDebris = 260, -- cap on loose chunks at once (oldest are removed first)
	SlamSpeed = 110, -- knockback this strong sends the target crashing through walls
}

-- (round 87) THROUGH-THE-BUILDING KNOCKBACK (the Omni-Man train scene): a
-- body thrown hard enough doesn't stop at the first wall it meets. How hard
-- is how fast it's going INTO the wall (studs/s, after the game's own
-- scaling of a push: Config.Knockback, and x0.8 for a limp body):
--   Splat.Speed+: a WALL SPLAT - a crater in the wall, the body spread on it
--     for Hold s (its back to the wall, arms and legs out), then it drops
--   Through.Speed+: it BURSTS THROUGH - a body-sized hole along its path (a
--     capsule of Radius, out the far side), held on the wall a HitStop, Loss
--     of its speed gone with the wall, and on it goes, through at most
--     MaxWalls walls a throw. The next wall it meets too slowly, past
--     MaxWalls, thicker than SegMax, or with the edge of the city behind
--     it, it's embedded in: the splat.
-- Only breakable walls (the map's Destroyable parts) - never a floor, a
-- roof, the Sky Coffin's barrier or a quirk's own wall (ice, wood), and
-- never a body held in a combo, grabbed, being finished, in a clash or a
-- raid boss (armoured). The body's own machine runs its body (it owns it):
-- it opens the walls ahead on its screen and says where it went through;
-- the server checks that against what it threw and where it sees the body,
-- and carves the real holes (a few a second, server-wide). NPCs and a
-- finisher's send-off are the server's own. Holes grow back with the rest
-- of the city (Config.Destruction.RegenTime). Which moves reach which tier:
-- r87/out/smash.md
Config.Smash = {
	Enabled = true,
	WallSlope = 0.55, -- a wall: its face this close to upright at least (|normal.Y| at most)
	-- ((round 87 review) and it stands up: wall at least Stand studs over
	-- where the body meets it - its own top, or more wall right above. A
	-- kerb, a sidewalk's edge, a hedge or a low wall a skidding body runs
	-- into is tumbled over by the physics, never splatted on or burst through)
	Stand = 2.5,
	Splat = {
		Speed = 60,
		Hold = 0.42, -- s spread on the wall
		Off = 0.55, -- studs his root sits off the wall (in the crater)
		Lift = 1, -- studs up the wall from where he hit it (pinned there, his feet off the street)
		Tilt = 14, -- degrees he's tipped one way or the other, at most
		Drop = { 8, -6 }, -- studs/s off the wall and down, as he comes off it
		-- the crater: Crater studs across its mouth (radius), as deep as
		-- DepthShare of the wall (MinDepth .. Depth: a thin wall cracks round
		-- him, a thick one caves in)
		Crater = 2.8, Depth = 1.3, DepthShare = 0.45, MinDepth = 0.15, MaxSphere = 6,
		Profile = "SmashSplat",
		-- spread on the wall: each joint turned (degrees about the parent's
		-- X, Y, Z) - arms up and out, legs apart, the head lolled
		Pose = {
			["Right Shoulder"] = { 0, 0, 125 }, ["Left Shoulder"] = { 0, 0, -125 },
			["Right Hip"] = { 0, 0, 22 }, ["Left Hip"] = { 0, 0, -22 }, Neck = { -10, 0, 14 },
			RightShoulder = { 0, 0, 125 }, LeftShoulder = { 0, 0, -125 }, RightHip = { 0, 0, 22 }, LeftHip = { 0, 0, -22 },
		},
	},
	Through = {
		Speed = 95,
		MaxWalls = 4,
		Loss = 0.18, -- of its speed, each wall
		HitStop = 0.06, -- s held on the wall before it bursts through
		Radius = { 3.4, 4.6 }, RadiusAt = 260, -- the hole's radius, Radius[1] at Speed growing to Radius[2] at RadiusAt
		Pad = { 1.4, 1.8 }, -- studs the hole starts in front of the wall / runs on past it
		Layers = 3, Layer = 1.6, -- a breakable layer this close behind (a panel, a frame) goes too, up to Layers more
		SegMax = 12, -- studs of wall at most (thicker: it's embedded in it)
		Beyond = 24, Floor = 420, -- the city must go on Beyond studs past the wall (ground within Floor under it)
		Cutout = 0.85, -- the hole on his own screen (before the server's lands), x Radius: inside the real one
		Profile = "SmashThrough", Lite = "SmashThroughLite", -- (Lite: the server's busy)
	},
	Probe = { Ahead = 2.5, Extra = 3.2, Radius = 1.4 }, -- the look ahead: frames of travel + studs, a sphere this wide
	-- a wall seen ahead is met when his root gets within Contact studs of it
	-- (it's opened the moment it's seen); not there within Arrive s, it's off
	Contact = 1.6, Arrive = 0.3,
	MaxTime = 2.6, MinTime = 0.3, EndSpeed = 24, SlowFor = 0.3, -- a throw's watched at most MaxTime s; over once it's slower than EndSpeed for SlowFor s
	-- the server-wide carving: Rate full holes a second (Burst at once), then
	-- HardRate coarse ones (HardBurst), then none (the throw still goes on)
	Rate = 8, Burst = 8, HardRate = 20, HardBurst = 12,
	-- a hole a player's machine reports: at most Reach[1] + speed x Reach[2]
	-- studs from where the server sees the body, going the way it was thrown
	-- (Cone: the dot of the two across), the server's own speed for it at
	-- least Tolerance of Through.Speed; waiting at most Align s for the
	-- server's view of the body to get to the wall
	Reach = { 16, 0.3 }, Cone = 0.3, Tolerance = 0.92, Align = 0.12,
	-- ((round 87 review) and on his path: no more than Lane studs to the side
	-- of the line the server sees him on, nor above / below it (plus his
	-- climb or fall x Reach[2]); the server's view of him lags along it)
	Lane = 8,
	Reopen = 1.4, -- s: a wall his machine opened that the server didn't carve closes again (once he's out of it)
	-- never the floor: nothing whose top is under Ground studs over the street
	-- below the hole, or Under studs under his path (a storey's floor slab),
	-- is opened or carved
	Floor = { Ground = 0.6, Under = 2.6 },
	Ghost = "SmashGhost", -- the collision group of his screen's stand-in wall (it hides the camera, stops nothing)
	Skid = { Speed = 24, Height = 3.4, Every = 0.07 }, -- through a wall and down in the street: dust and scrapes while it slides
	-- ((round 87 review) studs from a screen's camera past which a wall going
	-- is only its flash, dust and sound there: no cracks, crater, chunks or
	-- skid marks too far off to see - a busy server, a low-end machine)
	Far = 360,
}

-- (round 87) the geometry both sides use (the server for the bodies it
-- runs, each player's machine for its own): no state, nothing saved
Config.SmashKit = {}
do
	local SK = Config.SmashKit
	local UPV = Vector3.new(0, 1, 0)
	-- a wall the throw can break: a map part marked Destroyable (not the Sky
	-- Coffin's barrier, NoPhase)
	function SK.breakable(part)
		return typeof(part) == "Instance" and part:IsA("Part") and part:GetAttribute("Destroyable") == true and not part:GetAttribute("NoPhase")
	end
	-- the map's being carved (the test menu / server settings can stop it)
	function SK.carving()
		return (Config.Destruction or {}).Enabled ~= false and workspace:GetAttribute("DestructionEnabled") ~= false
	end
	-- the top of a part, however it's turned
	function SK.top(part)
		local cf, s = part.CFrame, part.Size
		return cf.Position.Y + (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
	end
	-- how far a line from `at` (on or in the part) along unit d runs before
	-- it leaves the part's box
	function SK.depth(part, at, d)
		local cf, h = part.CFrame, part.Size / 2
		local p, v = cf:PointToObjectSpace(at), cf:VectorToObjectSpace(d)
		local t = math.huge
		for _, ax in { "X", "Y", "Z" } do
			if v[ax] > 1e-6 then
				t = math.min(t, (h[ax] - p[ax]) / v[ax])
			elseif v[ax] < -1e-6 then
				t = math.min(t, (-h[ax] - p[ax]) / v[ax])
			end
		end
		return t == math.huge and 0 or math.max(t, 0)
	end
	-- the floor guard: parts whose top is at or under this are left alone
	-- (g: the ground under the hole, a raycast result or nil; pathY: the
	-- height of his path at the wall)
	function SK.floorAbove(g, pathY)
		local F = Config.Smash.Floor or {}
		return math.max(g and g.Position.Y + (F.Ground or 0.6) or -math.huge, pathY - (F.Under or 2.6))
	end
	-- a floor (a storey's slab, a sill, a ledge): flat - its thinnest side
	-- facing up - with its top under his path. Never opened or carved
	function SK.isFloor(part, pathY)
		local cf, s = part.CFrame, part.Size
		local ax, m = cf.RightVector, s.X
		if s.Y < m then
			ax, m = cf.UpVector, s.Y
		end
		if s.Z < m then
			ax = cf.LookVector
		end
		return math.abs(ax.Y) > 0.85 and SK.top(part) <= pathY + 0.5
	end
	-- the hole's radius at this speed into the wall
	function SK.radius(into)
		local T = Config.Smash.Through
		local k = math.clamp((into - T.Speed) / math.max(T.RadiusAt - T.Speed, 1), 0, 1)
		return T.Radius[1] + (T.Radius[2] - T.Radius[1]) * k
	end
	-- (round 87 review) does the wall stand up over where it was met (hit)?
	-- Its own top Stand studs over it, or more of the map right above it (a
	-- window pane under the wall over it). A kerb, a hedge, a low wall: no
	function SK.stands(hit, cast)
		local up = Config.Smash.Stand or 2.5
		if SK.top(hit.Instance) >= hit.Position.Y + up then
			return true
		end
		local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		n = n.Magnitude > 0.05 and n.Unit or hit.Normal
		return cast ~= nil and cast(hit.Position + n * 0.6 + UPV * up, -n * 1.6) ~= nil
	end
	-- what a body flying at v does to the wall it's met (hit: a raycast
	-- result on the map): { Kind = "Through", A, B, R, Dir }, { Kind =
	-- "Splat", Pos, Normal, Depth }, or nil (too slow, not a wall, not
	-- breakable: the physics have it). walls: walls it's been through this
	-- throw, of at most max; cast(origin, vector): a raycast on the map.
	-- (round 87 review) scale: the body's (SK.scale) - a giant's hole is a
	-- giant's size
	function SK.plan(hit, v, walls, max, cast, scale)
		local S = Config.Smash
		local part = hit and hit.Instance
		if not SK.breakable(part) or v.Magnitude < 1 then
			return nil
		end
		local n = hit.Normal
		if math.abs(n.Y) > S.WallSlope then
			return nil -- (a floor, a roof, a ceiling)
		end
		local into = -v:Dot(n)
		local SP, T = S.Splat, S.Through
		if into < SP.Speed or not SK.stands(hit, cast) then
			return nil -- (too slow; or a kerb, a hedge: tumbled over)
		end
		local d, at = v.Unit, hit.Position
		local depth = math.clamp(SK.depth(part, at, -n) * SP.DepthShare, SP.MinDepth, SP.Depth)
		if into >= T.Speed and walls < max and SK.carving() then
			local exit = at + d * SK.depth(part, at, d)
			for _ = 1, T.Layers do
				local more = cast(exit + d * 0.02, d * T.Layer)
				if not (more and SK.breakable(more.Instance)) then
					break
				end
				exit = more.Position + d * SK.depth(more.Instance, more.Position, d)
			end
			-- (not too thick to get through, and the city goes on past it:
			-- never out over the edge of the map)
			if (exit - at):Dot(d) <= T.SegMax and cast(exit + d * T.Beyond + UPV * 4, -UPV * T.Floor) then
				return { Kind = "Through", A = at - d * T.Pad[1], B = exit + d * T.Pad[2], R = SK.radius(into) * (scale or 1), Dir = d, Into = into, Part = part, Pos = at, Normal = n, Depth = depth }
			end
		end
		return { Kind = "Splat", Pos = at, Normal = n, Depth = depth, Into = into, Part = part }
	end
	-- (round 87 review) how big a body is (Model:ScaleTo: the Giant toy, an
	-- event's giants), 1 if it can't be told
	function SK.scale(model)
		local ok, s = pcall(function()
			return model:GetScale()
		end)
		s = ok and tonumber(s) or 1
		return (s == s and s > 0) and math.clamp(s, 0.5, 4) or 1
	end
	-- where the body goes on a splat: its back to the wall, upright, tipped
	-- ((round 87 review) scale: the body's - a giant's back is further off it)
	function SK.wallCF(pos, normal, tilt, scale)
		local n = Vector3.new(normal.X, 0, normal.Z)
		n = n.Magnitude > 0.05 and n.Unit or Vector3.new(0, 0, 1)
		local SP = Config.Smash.Splat
		local at = pos + (n * SP.Off + UPV * (SP.Lift or 0)) * (scale or 1)
		return CFrame.lookAt(at, at + n) * CFrame.Angles(0, 0, math.rad(tilt or 0))
	end
	-- spread on the wall: { { part, CFrame }, ... }, the root at rootCF and
	-- out from it a joint at a time. A limp body's limbs (their joints off:
	-- the ragdoll) are turned by Splat.Pose round each joint; a joint that's
	-- on keeps its part where it is on its parent
	function SK.splay(model, rootCF)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then
			return {}
		end
		local POSE = Config.Smash.Splat.Pose or {}
		local out, placed, motors = { { root, rootCF } }, { [root] = rootCF }, {}
		for _, m in model:GetDescendants() do
			if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Part1.Parent == model then
				table.insert(motors, m)
			end
		end
		for _ = 1, 8 do
			local more = false
			for _, m in motors do
				local p0, p1 = m.Part0, m.Part1
				if placed[p0] and not placed[p1] then
					local cf
					if m.Enabled then
						cf = placed[p0] * m.C0 * (m.Transform or CFrame.new()) * m.C1:Inverse()
					else
						local r = POSE[m.Name]
						local pivot = m.C0.Position
						local turn = r and CFrame.new(pivot) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3])) * CFrame.new(-pivot) or CFrame.new()
						cf = placed[p0] * turn * m.C0 * m.C1:Inverse()
						table.insert(out, { p1, cf })
					end
					placed[p1] = cf
					more = true
				end
			end
			if not more then
				break
			end
		end
		return out
	end
	-- onto the wall: the rest of the way along its path to Contact off it
	-- (what this frame's step would have done - the hit-stop holds it there,
	-- not short of the wall). Moved by each assembly's root (a limp body's
	-- limbs are their own)
	function SK.advance(model, root, plan)
		local gap = (root.Position - plan.Pos):Dot(plan.Normal) - Config.Smash.Contact
		local along = -plan.Dir:Dot(plan.Normal)
		if gap <= 0 or along < 0.15 then
			return
		end
		local shift = plan.Dir * math.min(gap / along, 12)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and not p.Anchored then
				local ok, r = pcall(function()
					return p.AssemblyRootPart
				end)
				if not ok or r == nil or r == p then
					p.CFrame = p.CFrame + shift
				end
			end
		end
	end
	-- the throw's pushes on the root (the knockback, a finisher's send-off):
	-- held off while the body is (kill: gone - the throw ends here)
	function SK.pushes(root, kill)
		local list = {}
		for _, c in root:GetChildren() do
			if c:IsA("LinearVelocity") and (c.Name == "Knockback" or c.Name == "FinisherLaunch") then
				if kill then
					c:Destroy()
				else
					c.Enabled = false
					table.insert(list, c)
				end
			end
		end
		return list
	end
	-- held still where it is, every part of the body (each limb of a limp
	-- one is its own): a zero mover each, so its machine keeps running it
	-- (and everyone else sees it held there, posed). (round 87 review) free:
	-- the splat - the ragdoll's joint limits are let go while it's held (its
	-- arms are spread past them: R6 shoulders twist 35 at most, R15 swing
	-- 80 - and a limit pulling against the hold shakes the limb), back on
	-- as it's let go (the arms flop back in as it drops)
	function SK.hold(model, free)
		local made = {}
		if free then
			made.limits = {}
			for _, j in model:GetDescendants() do
				if j.Name == "RagdollSocket" and (j:IsA("BallSocketConstraint") or j:IsA("HingeConstraint")) then
					local twist = j:IsA("BallSocketConstraint") and j.TwistLimitsEnabled or nil
					table.insert(made.limits, { j, j.LimitsEnabled, twist })
					j.LimitsEnabled = false
					if twist ~= nil then
						j.TwistLimitsEnabled = false
					end
				end
			end
		end
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local a = Instance.new("Attachment")
				a.Name = "SmashHold"
				a.Parent = p
				local lv = Instance.new("LinearVelocity")
				lv.Name = "SmashHold"
				lv.Attachment0 = a
				lv.MaxForce = 1e6
				lv.RelativeTo = Enum.ActuatorRelativeTo.World
				lv.VectorVelocity = Vector3.zero
				lv.Parent = p
				local av = Instance.new("AngularVelocity")
				av.Name = "SmashHold"
				av.Attachment0 = a
				av.MaxTorque = 1e6
				av.RelativeTo = Enum.ActuatorRelativeTo.World
				av.AngularVelocity = Vector3.zero
				av.Parent = p
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
				table.insert(made, av)
				table.insert(made, lv)
				table.insert(made, a)
			end
		end
		return made
	end
	function SK.unhold(made)
		if not made then
			return
		end
		for i = 1, #made do
			pcall(made[i].Destroy, made[i])
		end
		-- (the joint limits back as they were)
		for _, j in made.limits or {} do
			pcall(function()
				j[1].LimitsEnabled = j[2]
				if j[3] ~= nil then
					j[1].TwistLimitsEnabled = j[3]
				end
			end)
		end
		made.limits = nil
	end
	-- on its way again at v (nil: as it is), the pushes back on - keep of
	-- their speed
	function SK.resume(model, pushes, v, keep)
		for _, c in pushes do
			if c.Parent then
				c.VectorVelocity = c.VectorVelocity * keep
				c.Enabled = true
			end
		end
		if v then
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and not p.Anchored then
					p.AssemblyLinearVelocity = v
				end
			end
		end
	end
	-- off the wall after a splat: away from it a little, and down
	function SK.drop(model, normal)
		local D = Config.Smash.Splat.Drop
		local n = Vector3.new(normal.X, 0, normal.Z)
		n = n.Magnitude > 0.05 and n.Unit or Vector3.zero
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and not p.Anchored then
				p.AssemblyLinearVelocity = n * D[1] + UPV * D[2]
			end
		end
	end
end

-- Textures. The defaults are Roblox's built-in particle smoke and flame
-- (always available); swap in any texture from the Creator Store if you like.
Config.Assets = {
	SmokeTexture = "rbxasset://textures/particles/smoke_main.dds",
	FireTexture = "rbxasset://textures/particles/fire_main.dds", -- Todoroki's (and every other real) fire
}

---------------------------------------------------------------------------
-- Guard (hold F / L2). Blocks hits from the front, but every blocked hit
-- wears the guard meter down; at zero the guard shatters and you're stunned.
-- Raise it just as a hit lands (ParryWindow) to PARRY: no damage, and the
-- attacker is left stunned and open for a counter.
---------------------------------------------------------------------------

Config.Guard = {
	Max = 100,
	RegenPerSecond = 24, -- refills while not blocking...
	RegenDelay = 1.4, -- ...this long after the last blocked hit
	ChipDamage = 0.15, -- share of a blocked hit's damage that still goes through
	GuardDamagePerDamage = 1.6, -- meter lost per point of blocked damage
	FinisherGuardDamage = 30, -- the 4th M1 hits the guard extra hard
	BlockAngle = 150, -- degrees in front of you that the guard covers
	BlockWalkSpeed = 7,
	BreakStun = 1.8, -- stun when the guard shatters
	BreakRefill = 0.6, -- the meter comes back at this fraction after a break
	ParryWindow = 0.2, -- seconds after raising your guard that count as a parry
	ParryRange = 22, -- only attackers this close can be parried (melee range)
	ParryStun = 1.2, -- how long the parried attacker is left open
	ParryImmunity = 0.4, -- the rest of a parried combo can't hit you
	ParryLockout = 0.8, -- raising the guard again this soon can't parry (no mashing)
	ParryUlt = 0, -- ult meter gained for a parry (round 59: none - it's earned by dealing damage)
}

---------------------------------------------------------------------------
-- Fights: KOs, streaks, kill feed and the recap you see when you go down.
-- The last player to hit someone within CreditWindow seconds gets the KO
-- (including knocking them off the map).
---------------------------------------------------------------------------

Config.Fights = {
	CreditWindow = 15,
	HealOnKO = 30, -- health restored to whoever lands the KO
	UltOnKO = 0, -- ult meter granted for a KO (round 59: none - the damage that got it counts)
	StreakCallouts = { [3] = "ON A ROLL", [5] = "RAMPAGE", [7] = "UNSTOPPABLE", [10] = "SYMBOL OF PEACE" },
	ShutdownStreak = 3, -- ending a streak this long gets announced
	DummyKOsCount = false, -- true: training dummies add to KOs and streaks
	ComboTimeout = 1.4, -- seconds without landing a hit before your combo counter resets
	RecapTime = 5, -- seconds the "KNOCKED OUT" recap stays up
	RespawnTime = 5,
}

---------------------------------------------------------------------------
-- Finishers: when someone (a player or a training dummy) is down to their
-- last sliver of health, walk up and press E to finish them with your
-- quirk's signature execution. Both fighters are locked in for it (nobody
-- else can steal the KO), the body flies off ragdolled, and the kill feed
-- says FINISHED.
---------------------------------------------------------------------------

Config.Finishers = {
	Enabled = true,
	Threshold = 0.15, -- at or below this share of their max health
	Range = 10, -- studs from them
	Cooldown = 1,
	-- the finishing blow launches the body: each style's Forward/Up (below)
	-- times Scale, at least MinForward/MinUp, at most MaxSpeed studs/s overall;
	-- it tumbles (Spin, rad/s) and holds its speed for Carry seconds
	Launch = { Scale = 2.4, MinForward = 140, MinUp = 70, MaxSpeed = 340, Spin = 12, Carry = 0.2, Bounce = 0.14, Force = 250000 },
	-- per quirk: the move's name, how long it takes (seconds), and which way the
	-- body is launched at the end (forward and up; negative up = slammed into
	-- the street first, then it ricochets away)
	Styles = {
		Default = { Name = "FINISHING BLOW", Time = 1.1, Forward = 90, Up = 45 },
		Explosion = { Name = "POINT-BLANK EXPLOSION", Time = 1.25, Forward = 125, Up = 70 },
		OneForAll = { Name = "DETROIT SMASH", Time = 1.15, Forward = 60, Up = 150 },
		FullCowl = { Name = "MANCHESTER SMASH", Time = 1.3, Forward = 25, Up = -70 },
		HalfCold = { Name = "FLASHFREEZE: FLAME BURST", Time = 1.5, Forward = 120, Up = 55 },
		Engine = { Name = "RECIPRO SPIN KICK", Time = 1.05, Forward = 150, Up = 35 },
		Decay = { Name = "DECAY", Time = 1.45, Forward = 15, Up = 8, Crumble = true }, -- (round 83: Crumble - turned to ash where they stand, not launched)
		Limitless = { Name = "REVERSAL: RED - POINT BLANK", Time = 1.25, Forward = 175, Up = 45 },
		Overhaul = { Name = "DISASSEMBLY", Time = 1.35, Forward = 20, Up = 130 },
		Manifest = { Name = "SPIDER CRAB CRUSH", Time = 1.3, Forward = 110, Up = 60 },
		Arbor = { Name = "LACQUERED CHAIN PRISON", Time = 1.35, Forward = 60, Up = -60 },
		Compress = { Name = "VANISHING ACT", Time = 1.3, Forward = 45, Up = 35 },
		Creation = { Name = "CREATION: POINT-BLANK CANNON", Time = 1.3, Forward = 135, Up = 55 },
		Electrification = { Name = "DISCHARGE: POINT BLANK", Time = 1.2, Forward = 110, Up = 50 },
		Hellflame = { Name = "FLASHFIRE FIST: JET BURN", Time = 1.25, Forward = 125, Up = 55 },
		Blueflame = { Name = "CREMATION: POINT BLANK", Time = 1.25, Forward = 100, Up = 65 },
		Double = { Name = "DOUBLE TROUBLE", Time = 1.3, Forward = 100, Up = 55 }, -- (round 69: Twice)
		PrimeDeku = { Name = "FLASH STEP: SMASH", Time = 1.2, Forward = 150, Up = 50 }, -- (round 74)
		PrimeMight = { Name = "DETROIT SMASH: PRIME", Time = 1.15, Forward = 70, Up = 170 },
		TheWorld = { Name = "MUDA MUDA MUDA!", Time = 1.3, Forward = 130, Up = 55 },
		FierceWings = { Name = "FEATHER BLADES: X-CUT", Time = 1.2, Forward = 120, Up = 55 }, -- (round 86)
		-- (round 90) Saitama: he just punches them, once. Far.
		Saitama = { Name = "ONE PUNCH.", Time = 1.1, Forward = 160, Up = 95 },
		-- (round 92) Inasa: a gust under them that throws them up out of sight
		Whirlwind = { Name = "SKY-HIGH SEND-OFF!!", Time = 1.2, Forward = 70, Up = 175 },
	},
}

---------------------------------------------------------------------------
-- Cinematics: scripted camera shots for the biggest moves (every move with
-- Cinematic = true, plus awakenings). The caster gets the full cutscene and
-- can't be hit during the windup (CinematicArmor seconds); players caught
-- nearby get a short camera cut toward it.
---------------------------------------------------------------------------

Config.Cinematics = {
	Enabled = true,
	Awakenings = true, -- camera sweep when you press G
	AwakeningArmor = 1.2, -- the awakening can't be interrupted for this long
	Witness = true, -- players near a big move get a brief cut toward it
	WitnessRadius = 90,
	Letterbox = true,
}

---------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------
-- A slot is "rbxassetid://123" or a table:
--   { Id = "rbxassetid://123", Start = 1.2, Length = 0.8, Speed = 1 }
-- Start skips into the clip, Length cuts it off (seconds). Empty "" slots use
-- the built-in procedural motion (works on R6 and R15). Filled slots play on
-- your own character (Roblox replicates it) and skip the procedural motion.
--
-- Animations only play for games you own OR animations published by Roblox.
-- The ones filled in below are Roblox's own emotes (R15), so they work in any
-- experience. Replace them with your own uploads any time.

Config.Animations = {
	Rig = "R15", -- slots are skipped on other rigs (they fall back to procedural motion)
	M1 = { "", "", "", "" }, -- punch 1, 2, 3, 4 (finisher)
	Dash = { Front = "", Back = "", Left = "", Right = "" },
	-- Procedural movement (idle / walk / run / sprint / jump / fall / climb /
	-- sit made in code, see VFX) for these rig types. R6 needs it: Roblox's
	-- animation sets - and every clip below - are R15-only, and a game can only
	-- play animations it (or Roblox) owns. Set R15 = true to use it there too
	-- instead of the Movement clips.
	-- R6 = "auto": Roblox's clips (Animate) + the MovementSystem pack walk the
	-- body, and the built-in procedural gait takes over any body that isn't
	-- playing a clip (true: always the procedural gait; false: never).
	-- (round 64: round 62's keyframed idle / walk / run / sprint loops are
	-- gone - back to this)
	-- (round 90: R6 = true - every R6 body walks, runs and sprints on the
	-- rebuilt gait, Config.Locomotion; the movement pack's directional
	-- walking sits out - the gait turns the legs into a strafe itself - and
	-- its head-look stays on top)
	Procedural = { R6 = true, R15 = false },
	-- (round 63) THE MOVES as keyframed clips too (ReplicatedStorage.
	-- Animations): a move's motion plays its "Move<name>" clip and a held
	-- pose its "Pose<name>" clip, when the place has one, on R6 bodies (a
	-- pose clip's "Hold" key is held for as long as the move holds the pose).
	-- false: the older procedural motions everywhere.
	MoveClips = true,
	-- (round 61) KEYFRAMED CLIPS - real animations: the KeyframeSequences in
	-- ReplicatedStorage.Animations (the M1 combo: the four hits, the uppercut
	-- and the downslam; round 62: the four dashes and Creati's sword, staff
	-- and spear sets). Every client plays them straight from the place on R6
	-- bodies; nothing to upload. Open one in the Animation Editor to change
	-- it. To play one through Roblox's Animator instead, publish it from
	-- Studio and paste its id here (a blank slot plays the place's copy).
	Clips = {
		M1Brawler1 = "", M1Brawler2 = "", M1Brawler3 = "", M1Brawler4 = "",
		M1Uppercut = "", M1Downslam = "",
		DashFront = "", DashBack = "", DashLeft = "", DashRight = "",
		SwordM1_1 = "", SwordM1_2 = "", SwordM1_3 = "", SwordM1_4 = "", SwordUp = "", SwordDown = "", IaiRush = "",
		StaffM1_1 = "", StaffM1_2 = "", StaffM1_3 = "", StaffM1_4 = "", StaffUp = "", StaffDown = "", StrikeAndStop = "",
		SpearM1_1 = "", SpearM1_2 = "", SpearM1_3 = "", SpearM1_4 = "", SpearUp = "", SpearDown = "", PiercingThrust = "",
		-- (round 81) the M1 victim's reactions and the downslam's touchdown
		M1React1 = "", M1React2 = "", M1React3 = "", M1ReactFinisher = "", M1ReactUp = "", M1ReactDown = "", M1SlamLand = "",
		-- (round 83) the slam hop, the kickers' uppercut and downslam, the
		-- uppercut's victim landing
		M1SlamHop = "", M1KickUp = "", M1KickDown = "", M1ReactUpLand = "",
	},
	ClipFade = 0.05, -- seconds a clip blends in from whatever the body was doing
	M1ClipFade = 0.07, -- (round 81) ...an M1 swing blends from the last one's follow-through this long
	ClipRecover = 0.25, -- seconds it takes to ease back to standing after one
	-- (round 68) no fighting stance after a fight (the guard-up bounce on
	-- the toes, swaying): the idle stays the idle. true brings it back
	FightStance = false,
	-- looped while sprinting: the anime "arms back" run (Roblox's Ninja run)
	Sprint = { Id = "rbxassetid://656118852", Speed = 1.15 },
	Leap = "", -- All Might super leap (skydive)
	Land = { Id = "rbxassetid://10714360164", Start = 1.0, Length = 0.9 }, -- "Hero Landing" emote
	Hit = "", -- when you get hit
	Block = "", -- held while guarding
	Parry = "",
	GuardBreak = { Id = "rbxassetid://10714066964", Start = 0.2, Length = 1.7 }, -- "Dizzy" emote
	-- Default movement (applied to Roblox's Animate script on spawn). Roblox's
	-- own Superhero animation set: a fists-up guard for idle (plus its
	-- look-around), a confident walk, an athletic run. Idle takes one id or
	-- { idle, look-around }. The Animate script plays Run at normal fight
	-- speed and Walk when moving slowly (e.g. a half-tilted stick).
	Movement = {
		Idle = { "rbxassetid://616111295", "rbxassetid://616113536" }, -- SuperHero_Idle, SuperHero_LookAround
		Walk = "rbxassetid://616122287", -- SuperHero_Walk
		Run = "rbxassetid://616117076", -- SuperHero_Run
		Jump = "rbxassetid://616115533", -- SuperHero_Jump
		Fall = "rbxassetid://616108001", -- SuperHero_Fall
		Climb = "rbxassetid://616104706", -- SuperHero_Climb
	},
	-- G awakening, per quirk
	Ult = {
		Explosion = { Id = "rbxassetid://10714389396", Start = 0.9, Length = 1.5 }, -- "Power Blast" emote
		OneForAll = { Id = "rbxassetid://10713990381", Start = 5.6, Length = 1.4 }, -- "Bodybuilder" (arms raised)
		HalfCold = { Id = "rbxassetid://10714347256", Start = 1.2, Length = 1.8 }, -- "Godlike" (levitate)
		Engine = { Id = "rbxassetid://10714360164", Start = 1.05, Length = 1.1 }, -- "Hero Landing" (launch crouch)
		Decay = { Id = "rbxassetid://10714347256", Start = 1.2, Length = 1.8 }, -- "Godlike" (rises, arms out)
		FullCowl = "", -- procedural power-up (lightning bursts off him)
		Limitless = "", -- procedural hand sign
		CrazyDiamond = "", -- procedural (the Stand's rage pose)
		Hellflame = "", -- procedural (the No. 1 pose, a column of fire)
		Blueflame = "", -- procedural (arms thrown wide, head back: the reveal)
		FierceWings = "", -- (round 86) procedural (the wings thrown open)
		Saitama = "", -- (round 90) his own clip ("OK.")
		Whirlwind = "", -- (round 92) his own clip (the bow, then arms wide: "I LOVE THIS!!!")
	},
	-- Every move by its Id (see the quirk tables below)
	Moves = {
		APShot = "", BlastRush = "", Howitzer = "", StunGrenade = "", AutoCannon = "", Cluster = "", BlastOrbit = "", MaxCapacity = "", FullBodyCluster = "", ExplosiveSpeed = "",
		TexasSmash = "", NewHampshireSmash = "", CarolinaSmash = "",
		MuscleForm = { Id = "rbxassetid://10713990381", Start = 3.6, Length = 1.5 }, -- "Bodybuilder" double-biceps flex
		DetroitSmash = "", OklahomaSmash = "", BackdropDriver = "", ColoradoSmash = "", HeroCounter = "", WeatherChanger = "",
		PlusUltraRush = "", TexasSmashMax = "", UnitedStatesSmash = "",
		IceSpike = "", FrostBurst = "", IceWall = "", SideSwap = "", GlacierBreaker = "", IceSlider = "", JetKindling = "",
		Flashfire = "", FlamePillar = "", Heatwave = "",
		Phosphor = "", GlacialField = "", HeatwaveMax = "",
		SpinKick = "", EngineGatling = "", ReciproBurst = "", SkywardKick = "", ReciproExtend = "",
		TurboKick = "", ReciproTurbo = "", ReciproMax = "",
		DecayWave = "", DecayGrasp = "", Collapse = "", RivetStab = "", Sinkhole = "", PillarRise = "", PhantomGrasp = "",
		RadioWaves = "", RivetStorm = "", TotalDecay = "",
		DelawareSmash = "", Blackwhip = "", Smokescreen = "", QuirkCycle = "",
		StLouisSmash = "", ManchesterSmash = "", FaJinSmash = "", Float = "", HundredSmash = "",
		GearshiftRush = "", BlackwhipSlam = "", FistRain = "", MassGrasp = "",
		LapseBlue = "", ReversalRed = "", HollowPurple = "", Infinity = "", Blink = "",
		BlueMax = "", RedMax = "", PurpleMax = "",
		Dorarara = "", CrazyBuild = "", YoAngelo = "", CrazyRestore = "", Blueprint = "", BreakRestore = "",
		ChickenKick = "", TakoSnatch = "", TakoThrash = "", Snack = "", Swordfish = "",
		Kraken = "", Centaur = "", OctopusMirage = "", PlasmaCannon = "",
		ChainPrison = "", TimberSlingshot = "", RootBreaker = "", BranchSwing = "", TreeHammer = "",
		ThousandBranch = "", GreatSlingshot = "", TimberTorrent = "", SequoiaSpear = "",
		RubbleThrow = "", SurpriseAttack = "", VanishingAct = "", CompressMap = "", MagiciansChoice = "", GrandFinale = "", PhantomEndgame = "",
		MarbleStorm = "", CurtainCall = "", DisappearingAct = "",
		DaggerShot = "", TapeDash = "", MeasureTape = "", Double = "", DoubleCross = "",
		ParadeMarch = "", DaggerStorm = "", Dogpile = "",
		Discharge = "", ElectricGrasp = "", ZapTrap = "", Pointer = "", StunBolt = "",
		IndiscriminateDischarge = "", LightningRod = "", ChainLightning = "",
		HellSpider = "", JetBurn = "", VanishingFist = "", FlashfireJet = "", HellsCurtain = "",
		HellSpiderWeb = "", VanishingJetBurn = "", ProminenceNova = "", SkyProminence = "",
		Cremation = "", HellMinefield = "", BlueSpider = "", BlueWall = "", BlueJetBurn = "",
		BlueProminence = "", SekotoPeak = "", BlueVanishing = "",
		PrimeFlashStep = "", BlackwhipReel = "", AirForceStorm = "", DangerCounter = "", VestigeSmash = "", FlashStepChain = "", VestigeDDS = "",
		MissouriSmash = "", HurricaneSmash = "", PrimeDetroit = "", IAmHereLeap = "", PlusUltraUSJ = "", PrimeUSS = "",
		MudaRush = "", KnifeVolley = "", VampireDrain = "", ZaWarudo = "", SpaceRipper = "", KnifeRing = "", RoadRoller = "",
		FeatherBarrage = "", SwiftCut = "", PlumeCyclone = "", FierceWings = "", FeatherCarry = "", -- (round 86) Hawks
		ScarletRain = "", TooFast = "", PlumeTempest = "", ThousandFeathers = "",
		RazorStrafe = "", PeregrineStoop = "", GaleBeat = "", FeatherDrill = "", -- (round 92, hawksair: his flying moveset - his own clips, anim/moves_hawks_air.py)
		NormalPunch = "", ConsecutivePunches = "", SeriousSneeze = "", SeriousSideHops = "", SeriousTableFlip = "", SeriousPunch = "", -- (round 90) Saitama
		SlicingGust = "", GaleCannon = "", DragonWhirlwind = "", WindWall = "", WindRide = "", SkyCyclone = "", -- (round 92) Inasa
	},
}

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------
-- Each cue is a list of layers played together. A layer:
--   { Id = "rbxassetid://123", Volume = 0.6, Speed = { 0.9, 1.1 },
--     Start = 0.2, Length = 0.8, Delay = 0.05, Distort = 0.3 }
-- Speed / Volume can be a number or a {min, max} range picked at random each
-- play, so repeated hits never sound identical. Start skips into the file,
-- Length fades it out early. Id can also be a list of takes - one is picked
-- at random each play - where a take is an id or { Id = ..., Start = n }.
-- A cue can also set Range (hearing distance) and Gap (minimum seconds
-- between plays). A plain "rbxassetid://123" works too; "" (or an empty
-- table) is silent.
--
-- Two sources, both free to use in any experience and never taken down:
--   S: audio published by Roblox itself (classic engine sounds)
--   L: Roblox's licensed sound-effects library (the "(SFX)" assets from
--      Roblox / ProSoundEffects in the Creator Store). Start skips each
--      file's lead-in silence so the hit lands on the frame it's played.
-- Swap in anything from the Creator Store to restyle a cue.

local S = {
	Hit = "rbxassetid://12222046", -- hit.wav: body thud
	Snap = "rbxassetid://12222140", -- snap.wav: sharp crack
	Bass = "rbxassetid://12221944", -- bass.wav: sub-bass thump
	Collide = "rbxassetid://12221984", -- collide.wav: heavy crash
	Swoosh = "rbxassetid://12222200", -- swoosh.wav
	Lunge = "rbxassetid://12222208", -- swordlunge.wav: fast whoosh
	Slash = "rbxassetid://12222216", -- swordslash.wav (silent for its first 0.38s)
	Ring = "rbxassetid://12222225", -- unsheath.wav: metallic ring
	Cannon = "rbxassetid://3149249837", -- Cannon_Explode
	Rumble = "rbxassetid://12222084", -- Rocket shot.wav: long low boom
	Blast = "rbxassetid://12222132", -- Shoulder fired rocket.wav: sharp blast
	Roar = "rbxassetid://12222065", -- Launching rocket.wav: jet roar
	Jet = "rbxassetid://12222095", -- Rocket whoosh 01.wav
	Thunder = "rbxassetid://12222030", -- HalloweenThunder.wav
	Beast = "rbxassetid://9120031442", -- Thunder With Lion Roar Searing Blast Growl
	Glass = "rbxassetid://12222005", -- glassbreak.wav
	Flash = "rbxassetid://12221996", -- flashbulb.wav
	Ping = "rbxassetid://12221990", -- electronicpingshort.wav
	Beam = "rbxassetid://162670130", -- UFO Beam
	Oof = "rbxassetid://79348298352567", -- the classic OOF
	Stinger = "rbxassetid://15675043410", -- Roblox_UI_Tonal_Stinger
	Victory = "rbxassetid://12222253", -- victory.wav
	Negative = "rbxassetid://17208353912", -- Roblox GUI - Negative
	Aura = "rbxassetid://17208327798", -- Roblox GUI - Aura
}
Config.SoundLibrary = S

local function take(id, start)
	return { Id = "rbxassetid://" .. id, Start = start }
end

local L = {
	-- punches: the anime's hits are a dry "crack" on top of a meaty thud
	BeefyHit = { take("9117969584", 0.02), take("9117969717", 0.02), take("9117969892", 0.02) }, -- Punch Kit Beefy Hit
	CrackyPunch = { take("9113960355", 0.26), take("9113961593", 0.16), take("9113962225", 0.28) }, -- Cracky Punch
	CrackThud = { take("9117971499", 0.18), take("9117971755", 0.18), take("9117971770", 0.18) }, -- Punch Some Crack And Thud
	BodyHit = { take("9113483076", 0), take("9113491193", 0) }, -- Body Hit
	BodyImpact = { take("9113527761", 0.07), take("9113526259", 0.33) }, -- Body Impact
	BodyFall = { take("9113470178", 0.07) }, -- Body Fall Heavy
	BodyFallHuge = { take("9113471356", 0.2), take("9113471397", 0.2) }, -- Body Fall Huge Slow
	-- the "boom" under every big hit
	SubBoom = { take("9119661511", 0.1), take("9119661508", 0.13) }, -- Sub Boom Slapback Element
	BoomThump = { take("9113552058", 0.2) }, -- Boom Thump Rumble Deep Resonant Impact
	-- (round 77) ALL MIGHT'S PUNCHES. In the anime a smash of his is less a
	-- punch than a change in the weather: a dry crack and a thump you feel in
	-- your chest, then the air itself bursting outward (the "wind pressure"),
	-- a boom that rolls on like thunder and the street giving way. These are
	-- the layers for that, from Roblox's licensed library (Pro Sound Effects
	-- and APM: free in any experience). Each machine measures where a file's
	-- loudest moment is, and a Peak layer starts just before it.
	BodySlamThump = { take("9113535176", 0), take("9113535217", 0) }, -- Body Slam Low End Thump 1 / 2
	AirPound = { take("9125577249", 0), take("9125577266", 0), take("9125577419", 0), take("9125577695", 0) }, -- Giant Air Blast Low Bursts Pound
	SonicPressure = { take("9120769331", 0), take("9120769456", 0) }, -- Wind Whoosh Sonic Boom Low End Impact 1 / 2
	SonicCrack = { take("9119382258", 0), take("9119382515", 0), take("9119382752", 0) }, -- Sonic Boom 1 / 2 / 3
	BigBoomTail = { take("9125484511", 0), take("9125484526", 0), take("9125484367", 0) }, -- Deep Hits Big Reverberant Booms Rumbling Tail
	ThunderBlast = { take("9120016037", 0), take("9120016021", 0), take("9120016256", 0) }, -- Thunder Cracks Big Rumbling Blasts Booming 1 / 2 / 3
	DeepImpact = { take("1843025542", 0) }, -- Deep Impact (Max Cameron Concors, APM)
	-- swings and air
	SwishThin = { take("9119700128", 0.05), take("9119699577", 0.03) }, -- Swish High End Thin Sharp Thick
	AirySlice = { take("9120704519", 0.04), take("9120704525", 0.03), take("9120704715", 0.04) }, -- Whooshes Fast Wipes Quick Airy Slices
	SwishLarge = { take("9119700676", 0.02), take("9119700795", 0.02), take("9119700943", 0.03) }, -- Swish Large Multiple Variations
	WhooshSwishBy = { take("9120717363", 0.18) }, -- Whoosh Fast Swish By
	WhooshBurst = { take("9120695130", 0.8), take("9120695365", 0.8) }, -- Whoosh Burst
	AscendWhoosh = { take("9113077643", 0.75) }, -- Air Whoosh High End Ascending Short
	-- wind pressure: what a Smash leaves behind
	VortexBlast = { take("9120749305", 0.25), take("9120749463", 0.27) }, -- Wind Burst Alien Vortex Blasts
	GiantSwish = { take("9120722193", 0.45), take("9120719658", 0.4) }, -- Whoosh Giant Swish By
	WindBlast = { take("9120698640", 3.15) }, -- Whoosh By Huge Wind Blast (the blast itself)
	WindRoar = { take("9120698637", 2.4) }, -- Whoosh By Huge Wind Blast (the long roar)
	HowlingWind = { take("9120697819", 0.4), take("9120698185", 0.4) }, -- Whoosh By Howling Wind Light Rumbling
	DeepBlast = { take("9120704346", 0.3) }, -- Whoosh Deep Booming Blast Reversed At Tail
	-- explosions: Bakugo's are crackling pops, not cannon shots
	ExplosionCrack = { take("9114362943", 0), take("9114363238", 0) }, -- Explosion Soft Crack
	Explosions = { take("9114362121", 0) }, -- Explosions
	WhooshExplosion = { take("9120705982", 0.02), take("9120706224", 0.02) }, -- Whoosh Explosion
	PowerBoom = { take("9117876706", 0.1), take("9117876774", 0.1) }, -- Power Explosions Big Heavy Searing Boom
	PowerBoomLong = { take("9117876720", 0.18) }, -- Power Explosions Big Heavy Searing Boom (long tail)
	-- One For All: crackling Full Cowl lightning, powering up
	Static = { take("9114248410", 0), take("9114249466", 0), take("9114250120", 0) }, -- Electricity Static
	Zap = { take("9117877054", 0), take("9117878870", 0.03) }, -- Powerline Zaps
	PowerUp = { take("9117884769", 0.25) }, -- Power Up Sweeteners
	PowerHit = { take("9117885276", 0) }, -- Power Up Sweeteners (instant)
	EnergyGrowl = { take("9114315138", 0.18), take("9114315120", 0.17) }, -- Energy Burst Growl
	EnergySnap = { take("9114315422", 0) }, -- Energy Burst Growl (instant)
	SuckIn = { take("9118808257", 0.75) }, -- Sci Fi Reverse Suck Close: swells into a hit ~0.9s later
	SuckShort = { take("9118808396", 0.25) }, -- Sci Fi Reverse Suck Close: swells ~0.5s later
	-- Todoroki
	IceHammer = { take("9114865174", 0), take("9114865191", 0) }, -- Ice Hammer Hitting Large Chunks
	IceCrunch = { take("9114866288", 0.23) }, -- Ice Pick Small Crunches Splinters
	FireWhoosh = { take("9114440738", 0.2) }, -- Fire Whoosh
	FlameLick = { take("9114463410", 0.22) }, -- Flame Licks
	FireBurst = { take("9114429654", 0.14) }, -- Fire Burst
	GlassBreak = { take("9114590633", 0.04), take("9114590265", 0.02) }, -- Glass Break
	GlassSmash = { take("9114614830", 0.16) }, -- Glass Smashes
	GlassDebris = { take("9114601337", 0.12), take("9114601455", 0.17) }, -- Glass Debris
	-- (round 81) ice freezing over (a crackle, not glass), steam letting go,
	-- the ground splitting (ProSoundEffects, public: checked on the economy API)
	IceFreezeCrackle = { take("9125611419", 0), take("9125611312", 0) }, -- Ice Freeze Large Piece Crackles Liquid Nitro
	AirRelease = { take("9116495722", 0) }, -- Medium Pressure Air Release 2
	EarthCrack = { take("9114220520", 0) }, -- Earthquake Cracking 1
	-- (round 81) fire meeting ice: the searing hiss of it flashing to steam,
	-- the superheated air bursting (ProSoundEffects, public: checked on the
	-- economy API; each Start skips the file's lead-in silence)
	SteamSear = { take("9118882814", 0.25), take("9118883047", 0.25) }, -- Searing Bursts 11 / 13 (hissing pass-bys, very airy)
	SearBlast = { take("9126219292", 0), take("9126220199", 0.08) }, -- White Light Short Searing Bursts Rumble Hiss 2 / 4
	-- (round 81) Origin: fire meeting the ice - steam (all Pro Sound Effects)
	SteamBurst = { take("9114588400", 0), take("9114588408", 0), take("9114588467", 0) }, -- Giant Steam Chuff Air Burst Valve 1 / 2 / 3
	SteamTube = { take("9125579986", 0), take("9125580012", 0) }, -- Giant Steam Chuff Air Burst Through The Tube 2 / 1 (valve)
	Sizzle = { take("9119165436", 0), take("9119165650", 0), take("9119166199", 0) }, -- Sizzle Short And Explosive Sear 1 / 4 / 8
	IceSizzle = { take("9114858178", 0) }, -- Ice Crack And Sizzle 1
	FireballSizzle = { take("9114428855", 0) }, -- Fireball Sizzle 2 (huge close burn)
	-- Iida
	MotorRev = { take("9116990418", 0.6) }, -- Motor Wind Up
	Accelerate = { take("9117882683", 0.8) }, -- Power Up Accelerating Motors
	JetPass = { take("9114888034", 0.35) }, -- Jet Pass By
	-- guard
	SwordClash = { take("9119747138", 0.04), take("9119747163", 0.04) }, -- Sword Impact
	SwordTick = { take("9119742980", 0) }, -- Sword Draw Clang Unsheathing Two Sabers
	MetalSwoosh = { take("9119707271", 0.05) }, -- Swish Suck Reversed Metallic Swoosh Impact
	-- (round 62) Creati's weapons: blades whipping through the air, a stab
	-- going in, the long ring of steel, a wooden staff's whoosh
	SwordWhip = { take("9119753112", 0.26), take("9119750692", 0.25), take("9119752789", 0.22) }, -- Sword Whip 1001 / 201 / 901
	SwordSwish = { take("9119750029", 0.02), take("9119750035", 0) }, -- Sword Swishes 1 / 2
	SwordStab = { take("9119748927", 0) }, -- Sword Stab 1
	BladeImpact = { take("9119747120", 0) }, -- Sword Impact 102
	BladeRing = { take("9119747477", 0.22) }, -- Sword Long Metallic Ring Decay 1
	BladeScrape = { take("9119748082", 0.25) }, -- Sword Scrape 101
	SwordUnsheath = { take("9119743392", 0), take("9119742967", 0) }, -- Sword Draw Clang Unsheathing Two Sabers 12 / 7
	StaffWhoosh = { take("9119737071", 0), take("9119737392", 0.33) }, -- Swoosh Pack 2 / 8 (low, woody)
	-- rock, debris, decay
	RockCrack = { take("9118582372", 0.4), take("9118582585", 0.55) }, -- Rock Crack
	BoulderCrack = { take("9118584737", 0), take("9118584958", 0) }, -- Rock Cracks Big Boulder Hits
	RockBurst = { take("9118576383", 3.6) }, -- Rock Burst
	DirtBurst = { take("9118675813", 0.34), take("9118675437", 0.55) }, -- Rocks Dirt Debris Pouring Bursts
	DebrisImpact = { take("9114032158", 0), take("9114032056", 0.21) }, -- Debris Impact
	DebrisMove = { take("9114032754", 0.27) }, -- Debris Movement
	Quake = { take("9114221264", 0.15), take("9114221327", 0.08) }, -- Earthquake Debris
	-- Overhaul: the red crackle of his Quirk, then flesh and bone coming apart
	-- (and snapping back together), stone grinding into new shapes
	QuirkCrackle = { take("9116276288", 0), take("9116276051", 0.04), take("9116278351", 0.04) }, -- Lightning Flashes Quick Electrical Bursts
	CrackleRun = { take("9116279561", 0.05), take("9116277954", 0.05) }, -- Lightning Flashes Quick Electrical Bursts (stuttering)
	BoneSnap = { take("9113540587", 0.03), take("9113542363", 0.12), take("9113540932", 0.2) }, -- Bone Cracks
	-- Kamui Woods: timber - branches snapping and splitting, creaking under load,
	-- trunks slamming down
	BranchSnap = { take("9113581977", 0), take("9113581974", 0), take("9113581982", 0), take("9113582136", 0) }, -- Branch Snap Wood Stick Crack
	BranchThrash = { take("9113582288", 0), take("9113582462", 0) }, -- Branch Thrash
	WoodCrack = { take("9120817182", 0), take("9120826640", 0) }, -- Wood Crack / Wood Cracks Multiple Variations
	WoodSplinter = { take("9120827596", 0), take("9120826949", 0) }, -- Wood Crack Thick Splintering Popping / Snapping Splintering
	WoodCreak = { take("9120829478", 0), take("9120831408", 0) }, -- Wood Creak / Intense Cracking Splintering
	WoodClunk = { take("9120797172", 0), take("9120797291", 0), take("9120797307", 0) }, -- Wood Beam Impact Resonant Clunks
	WoodCrash = { take("9120827780", 0) }, -- Wood Crash
	TreeBreak = { take("9120258724", 0), take("9120258936", 0) }, -- Tree Branches Breaking Snapping Cracking
	TreeSlap = { take("9120262845", 0), take("9120262924", 0) }, -- Tree Slap
	TreeDestruction = { take("9120261955", 0) }, -- Tree Destruction
	FleshReshape = { take("9119560180", 0.05), take("9119559825", 0.02) }, -- Squishy Bone Cracks
	JuicySplat = { take("9120628323", 0.04) }, -- Web Shoot Big Juicy Splat Impact
	GutsSplat = { take("9114741191", 0.29), take("9114741340", 0.55) }, -- Guts Splat
	BloodSpurt = { take("9113464577", 0.26) }, -- Blood Spurt
	MeatyThud = { take("9116485127", 0.06), take("9116485130", 0.08) }, -- Meat Hack Fleshy Hits
	StoneGrind = { take("9118664646", 0.08), take("9118665020", 0.15) }, -- Rock Scrape Deep Grinding Impacts
	-- the kaiju: a giant creature's roar with thunder in it, footfalls that boom
	MonsterRoar = { take("9113987603", 0.6) }, -- Creature Vocal Giant Crab Monster Roars
	MonsterGrowl = { take("9113980319", 0.7) }, -- Creature Mix Giant Crab Monster Roar Growl
	RoarBlast = { take("9120025244", 0.25) }, -- Thunder With Lion Roar Searing Blast
	BeastRumble = { take("9116299987", 0.35) }, -- Lion Roar Gargle Low Inhale Beast
	GiantStep = { take("9125404769", 0) }, -- Boomy Footsteps Giant Thumpy Dinosaur Footsteps
	-- the shop and its items
	CoinThrow = { take("9113849651", 0) }, -- Coin Throws
	Gulp = { take("9116316528", 0.27), take("9116316523", 0.25) }, -- Liquid Gulp
	CanPop = { take("9113537815", 0.05) }, -- Boink Wet Suction Pop
	RifleShot = { take("9118174270", 0), take("9118173988", 0), take("9118174539", 0) }, -- Rifle Single Shots
	BalloonPop = { take("9113263649", 0) }, -- Balloon Pop
	-- food
	AppleChew = { take("9113138343", 0.6) }, -- Apple Chew
	BagelBite = { take("9113247146", 0.88) }, -- Bagel Bite
	ChipBag = { take("9117851142", 0), take("9117850887", 0) }, -- Potato Chip Bag Drop
	Wrapper = { take("9117409728", 0.08) }, -- Plastic Bag Handling Crunchy Cellophane
	Burp = { take("9113644760", 0.22) }, -- Burps Belch
	CrowdRoar = { take("9114013553", 0.4) }, -- Crowd Reactions 2
	CrowdWhoops = { take("9114015637", 0.2), take("9114015699", 0.1) }, -- Crowd Whoops And Screams
	CoinDrop = { take("9113704038", 0.18) }, -- Candy Machine Coin Drops Insert Vending
	-- (round 86) HAWKS: wings and feathers (the library has no feather sound -
	-- big wing beats are pitched up a touch with a cloth-like bat rustle on
	-- top so they read as feathers, not leather; Starts skip each file's
	-- lead-in, measured in Studio: r86/sfx_catalog.md)
	WingFlapBig = { take("9120773999", 0.08), take("9120776877", 0.12) }, -- Wing Flaps 14 / Wing Flaps 1: one big whomp each (RMS ~0.4)
	WingFlapShort = { take("9120771864", 0.06) }, -- Wing Flaps 27: a short single whomp (quieter, ~0.18)
	WingFlapHuge = { take("9120773590", 0.06) }, -- Wing Flaps 8: several huge beats (the loudest, ~0.87)
	WingFlutter = { take("9120779837", 0.08), take("9120779671", 0.1) }, -- Wing Flap Up Down Movement 8 / 7: small fast flaps (~0.1)
	FeatherRustle = { take("9125386815", 0.27), take("9125386819", 0.67) }, -- Bat Noises Bursts Of Wings Flapping 3 / 4: cloth-like rustle (quiet, ~0.04)
	MagicFlutter = { take("9116426727", 0.48) }, -- Magic Transformation Oscillating Flutter 2: a flutter into a gusty burst
	FeatherSwish = { take("9126013644", 0.1), take("9126013382", 0.08), take("9126014020", 0.06) }, -- Swish Med High End Sharp Swords 13 / 11 / 20: the "thwip"
	FeatherSwarm = { take("9114157694", 0.16) }, -- Doppler Whooshes Crackly Airy Bursts 1: the swarm leaving
	ArrowHit = { take("9113162981", 0.63), take("9113162860", 0.65), take("9113163331", 0.61) }, -- Arrow In And Hit 6 / 1 / 11: on the hit
	ArrowThunk = { take("9113160975", 0.63) }, -- Arrow In And Hit 3: a heavy wooden thunk
	-- (round 86, C2) Hawks' moves (r86/sfx_catalog.md: measured Starts). The
	-- zoom, the gusts, the deep thump and the dirt are the flight's own takes
	-- (L.MagicZoom, L.FlyGust, L.DeepImpact7, L.BodyFallDirt, after this
	-- table); ArrowPass / PigeonSurge are the same as hawks_ult's (one of each
	-- pair goes when they merge)
	ArrowPass = { take("9113166355", 0.89), take("9113166561", 0.89) }, -- Arrow Out Whooshing Pass By 4 / 8: a doppler fly-by (quiet, ~0.1)
	ArrowHitHeavy = { take("9113161857", 0.59) }, -- Arrow In And Hit 19: a wooden strike, an airy rip, a deep tail (~0.57)
	PigeonSurge = { take("9125738421", 0.69) }, -- Pigeon Surges Sudden Bursts Of Birds Flying 1: wings bursting up (quiet, ~0.06)
	SwordShing = { take("9119749145", 0.01) }, -- Sword Swish 102: a metal shing at the head
	SwordFoil = { take("9119750447", 0.06) }, -- Sword Swishes 9: fast airy foil swipes
	SwordDraw = { take("9119747260", 0.27) }, -- Sword In 1: a sabre out of its scabbard
	ClothBloom = { take("9117234408", 0.59) }, -- Parachute Blossom 1: cloth bursts, billowing
	TearingAir = { take("9120741911", 0.59) }, -- Whoosh Sweeteners Tearing Atmosphere 1 (12.9 s: a loop bed)
	AiryWind = { take("9125742262", 0) }, -- Plasma Trails Constant Airy Whooshing Windy 2 (33 s: a loop bed)
	CapeSnap = { take("9113716967", 1.59) }, -- Cape Flap Parachute Movement 6: one big canvas snap
}
-- music (APM tracks from the Creator Store, free in any experience)
Config.Music = {
	Disco = "rbxassetid://9038367768", -- Funky Disco Beats
}
-- ULT MUSIC: while someone's ult is up, their theme plays - your own at full
-- volume, someone else's fading in as you get close (one track at a time:
-- yours first, else the nearest). Every track is an APM Music piece from the
-- Creator Store (licensed by Roblox, free in any experience). Start = seconds
-- in (skip the intro to where it hits). Swap in any audio you have the rights
-- to: an asset id you uploaded works the same.
Config.UltMusic = {
	Volume = 0.5,
	FullRange = 70, -- studs: full volume this close to the one ulting...
	HearRange = 230, -- ...fading out to nothing here
	FadeIn = 1.2,
	FadeOut = 1.8,
	Default = { Id = "rbxassetid://1838626813", Start = 0 }, -- Epic Rock Action (Guillaume Roussel)
	Tracks = {
		-- the heroes: heroic rock + orchestra (the "You Say Run" feel)
		OneForAll = { Id = "rbxassetid://122159934022680", Start = 120 }, -- Epic Rock Action: rock band, orchestra, choir
		FullCowl = { Id = "rbxassetid://9047148335", Start = 27 }, -- Epic Hybrid Rock A (Moritz Bintig)
		Explosion = { Id = "rbxassetid://1848129303", Start = 2 }, -- Riveting And Explosive A (Gregor F Narholz)
		HalfCold = { Id = "rbxassetid://1848096641", Start = 47 }, -- Legend Of A Hero A (Gregor F Narholz)
		Engine = { Id = "rbxassetid://1848128446", Start = 20 }, -- Right Man For The Job A (Gregor F Narholz)
		Lemillion = { Id = "rbxassetid://1835320614", Start = 75 }, -- Epic Ascent (Bradley James Farmer)
		Manifest = { Id = "rbxassetid://1837089134", Start = 29 }, -- Void (Bibliotheque): gritty guitar, builds
		Arbor = { Id = "rbxassetid://9047148591", Start = 20 }, -- Epic Hybrid Rock C (Moritz Bintig)
		Electrification = { Id = "rbxassetid://120858992982640", Start = 8 }, -- Thunderbolt (Jorge Hervas Martinez): superhero
		Hellflame = { Id = "rbxassetid://9043019379", Start = 6 }, -- Forged In Fire A (Rockshop): action rock
		Blueflame = { Id = "rbxassetid://9045517679", Start = 4 }, -- Flames Everywhere (A) (Epic Score): dark epic hybrid
		CrazyDiamond = { Id = "rbxassetid://1847791599", Start = 34 }, -- Heroic Epic Build A (Moritz Bintig)
		-- the villains: darker
		Decay = { Id = "rbxassetid://1848128971", Start = 8 }, -- Anarchy B (Gregor F Narholz)
		Overhaul = { Id = "rbxassetid://1848125982", Start = 25 }, -- Judgment Day C (Gregor F Narholz)
		Limitless = { Id = "rbxassetid://1848131944", Start = 12 }, -- Wheel Of Darkness (Gregor F Narholz)
		Compress = { Id = "rbxassetid://117498563506482", Start = 12 }, -- The Great Illusion (A Villains Neverland)
		Double = { Id = "rbxassetid://1848128971", Start = 40 }, -- Anarchy B again, further in (round 69: Twice)
		-- (round 74)
		PrimeDeku = { Id = "rbxassetid://9047148335", Start = 60 }, -- Epic Hybrid Rock A, further in
		PrimeMight = { Id = "rbxassetid://122159934022680", Start = 60 }, -- Epic Rock Action, further in
		TheWorld = { Id = "rbxassetid://1848131944", Start = 40 }, -- Wheel Of Darkness, further in
		-- (round 86, hawks_ult) the fastest hero: Night Run (APM / Magnetic
		-- Records, Atmospheric Drum 'n' Bass, 173 BPM), in at its first loud
		-- stretch (23-88 s) on a bar line (r84/music_catalog.md: loaded and
		-- streamed in the place)
		FierceWings = { Id = "rbxassetid://9044545570", Start = 22.4 },
		-- (round 90) Saitama: March of Justice 30A (APM / 2nd Foundation,
		-- Heroes and Villains: a majestic brass chorale over military drums,
		-- "noble, epic, heroism" - 31 s, a little longer than his ult). The
		-- most heroic thing in the library, played completely straight for the
		-- most bored hero alive (r84/music_catalog.md: loaded in the place)
		Saitama = { Id = "rbxassetid://1835323453", Start = 0.11 },
		-- (round 92) Inasa: Future Victory (APM: an upbeat, all-out victory
		-- cue, 63 s - r84/music_catalog.md, loaded in the place): the fight of
		-- his life and he's loving every second
		Whirlwind = { Id = "rbxassetid://1839223123", Start = 0.09 },
	},
}

-- VOICE LINES. Id: an audio clip you uploaded (and have the rights to) plays
-- if set. Otherwise Roblox's own text-to-speech says the line (VoiceId 5 is
-- its deeper US male voice; Pitch in semitones).
-- (round 76) THE SOUND FOLDERS: a line with a Folder plays the Sound called
-- Sound in that folder in Workspace (the All Might, Bakugo and Deku folders),
-- at that Sound's Volume x Gain - so whatever's in the folder is what plays;
-- Id is the same clip, for if the folder's ever gone. A line that has to land
-- on a moment of its move is lined up by its BEAT: each player's machine
-- measures a clip once, when it loads it - where the speech starts (First),
-- where its loudest word starts (Beat) and where the phrase that word is in
-- starts (Cut) - and starts it so the beat lands on time. First / Beat / Cut
-- here are only used until it has. MaxCut: how much of the start of the
-- speech it may skip to land the beat (0: none - it lands late instead).
-- Trim: it stops before the phrase with the loudest word.
-- (round 83) Fixed = { [asset number] = { First, Beat, Stop } }: a clip
-- measured by hand. When the line plays THAT clip, these are used as they
-- are and the machine's own measurement is ignored for it; Stop is a hard
-- stop (seconds into the clip, a short fade either side of it). Any other
-- clip in the folder is measured and trimmed as before.
Config.Voice = {
	-- All Might bulking up into his muscle form, and Prime All Might's meteor:
	-- "...HERE!" lands on the burst out of the steam / the landing
	IAmHere = {
		Folder = "All Might", Sound = "all might i am here", Id = "rbxassetid://83632324702728", Gain = 2, Range = 220,
		First = 0.1, Beat = 1.0, MaxCut = 0.25, Length = 3,
		Text = "I am here!", VoiceId = "5", Pitch = -3, Speed = 0.9, Volume = 3, Bubble = "I AM HERE!",
	},
	-- (round 76) the rest of the folders. All Might charging up: before every
	-- move he has (Config.VoiceCues)
	MightCharge = { Folder = "All Might", Sound = "All Might Charge", Id = "rbxassetid://129685410396909", Gain = 2, Range = 180, Length = 3 },
	-- (round 77) Detroit Smash: just "SMASH!", lined up so it lands on the
	-- punch (it replaced the "DETROIT SMASH" line)
	MightSmash = { Folder = "All Might", Sound = "All Might SMASH", Id = "rbxassetid://100451251229906", Gain = 2, Range = 220,
		First = 0.05, Beat = 0.25, MaxCut = 0.15, Length = 3 },
	-- UNITED STATES OF SMASH: "...SMASH!!" lands on the punch. (round 81)
	-- Measured in Studio: the speech starts 0.7s in and "SMASH" at 4.29s -
	-- 2.3s more than the 2s build - so it skips in (MaxCut) to "...STATES
	-- OF... SMASH!!" with SMASH on the strike; it used to land 2s late, in
	-- the twister. Gain 0.5: the folder's Sound is at 5.1, and x2 pinned it
	-- at the engine's ceiling of 10, some 19dB over his other lines and the
	-- crack it rides (its speech measures 0.2-0.28 RMS; SMASH's 0.3 x 1).
	-- Volume: the folder Sound's own 5.1, for if the folder's ever gone.
	MightUSS = {
		Folder = "All Might", Sound = "united_states_of_smash_my_hero_academia_1", Id = "rbxassetid://104378200563777", Gain = 0.5, Range = 400,
		First = 0.7, Beat = 4.29, MaxCut = 2.5, Length = 7, Volume = 5.1,
	},
	-- Bakugo: his awakening, and Explosive Speed (his R in the ult) - "I'M
	-- THE FINAL BOSS, GOT IT?" (to All For One, in the Final Season's "The
	-- Final Boss!!")
	Bakugo200 = { Folder = "Bakugo", Sound = "Bakugo 200%", Id = "rbxassetid://140687924372203", Gain = 2, Range = 260, Length = 3 },
	-- (round 83) measured in Studio (8.09s): "I'M" at 0.45, "GOT" 1.92, "IT?"
	-- over by 2.28, quiet 2.33-2.92, then a scream from 2.94 to the end. The
	-- scream is the loudest thing in it, so the machine's measurement put the
	-- cut in the wrong place (the "aahhh" after GOT IT?): for this clip it's
	-- Fixed - out at 2.36, right after "GOT IT?", and "GOT" is the beat
	-- (Explosive Speed lands its opener on it). Trim / First / Cut: for any
	-- other clip put in the folder.
	FinalBoss = {
		Folder = "Bakugo", Sound = "I'M THE FINAL BOSS, GOT IT? BAKUGO", Id = "rbxassetid://87930671985739", Gain = 2, Range = 260,
		Fixed = { ["87930671985739"] = { First = 0.45, Beat = 1.92, Stop = 2.36 } },
		MaxCut = 0.1, Trim = true, First = 0.1, Cut = 3.2, Length = 8,
	},
	-- Deku's awakening (G) - Prime Deku's too
	DekuAwaken = { Folder = "Deku", Sound = "Deku full cowel", Id = "rbxassetid://110359127412280", Gain = 2, Range = 260, Length = 7 },
	-- (round 74) DIO
	ZaWarudo = { Id = "", Text = "The World! Time, stop!", VoiceId = "5", Pitch = -2, Speed = 0.95, Volume = 3, Range = 300, Bubble = "ZA WARUDO!!" },
	TimeResume = { Id = "", Text = "And time... moves again.", VoiceId = "5", Pitch = -2, Speed = 0.9, Volume = 3, Range = 300, Bubble = "TOKI WA UGOKIDASU..." },
	RoadRoller = { Id = "", Text = "Road roller da!", VoiceId = "5", Pitch = -1, Speed = 1.05, Volume = 3, Range = 300, Bubble = "ROAD ROLLER DA!!" },
	Wry = { Id = "", Text = "Wryyyyyy!", VoiceId = "5", Pitch = 0, Speed = 1, Volume = 3, Range = 300, Bubble = "WRYYYYYYY!!" },
	-- (round 90) SAITAMA: flat, unbothered (text-to-speech, a calm voice a
	-- touch slow). The SERIOUS PUNCH's two lines carry across the city.
	SaitamaOK = { Id = "", Text = "OK.", VoiceId = "5", Pitch = -1, Speed = 0.9, Volume = 3, Range = 260, Bubble = "OK." },
	SeriousSeries = { Id = "", Text = "Serious series.", VoiceId = "5", Pitch = -2, Speed = 0.85, Volume = 3.2, Range = 1800, Bubble = "SERIOUS SERIES..." },
	SeriousPunchCall = { Id = "", Text = "Serious punch.", VoiceId = "5", Pitch = -2, Speed = 0.9, Volume = 3.5, Range = 1800, Bubble = "SERIOUS PUNCH." },
	SaitamaConsecutive = { Id = "", Text = "Consecutive normal punches.", VoiceId = "5", Pitch = -1, Speed = 1.15, Volume = 3, Range = 220, Bubble = "CONSECUTIVE NORMAL PUNCHES" },
	SaitamaSneeze = { Id = "", Text = "Ah... ah... achoo!", VoiceId = "5", Pitch = -1, Speed = 1.1, Volume = 3, Range = 260, Bubble = "ah... AH... ACHOO!!" },
	SaitamaTableFlip = { Id = "", Text = "Serious table flip.", VoiceId = "5", Pitch = -1, Speed = 1, Volume = 3, Range = 260, Bubble = "SERIOUS TABLE FLIP." },
	SaitamaSideHops = { Id = "", Text = "Serious side hops.", VoiceId = "5", Pitch = -1, Speed = 1.15, Volume = 2.6, Range = 200, Bubble = "SERIOUS SIDE HOPS." },
	SaitamaOops = { Id = "", Text = "Oops.", VoiceId = "5", Pitch = -1, Speed = 0.85, Volume = 3, Range = 400, Bubble = "...oops." },
	-- (round 92) INASA: loud, happy, all-in (text-to-speech, the deeper voice
	-- pushed up and quick). His own lines, not quotes. The SKYBREAKER
	-- CYCLONE's two carry across the city.
	InasaAwaken = { Id = "", Text = "I love this! Let's go all out!", VoiceId = "5", Pitch = 1, Speed = 1.15, Volume = 3.2, Range = 320, Bubble = "I LOVE THIS!!!" },
	InasaCannon = { Id = "", Text = "Gale cannon!", VoiceId = "5", Pitch = 1, Speed = 1.2, Volume = 3, Range = 260, Bubble = "GALE CANNON!!" },
	InasaWhirl = { Id = "", Text = "Dragon whirlwind!", VoiceId = "5", Pitch = 1, Speed = 1.2, Volume = 3, Range = 260, Bubble = "DRAGON WHIRLWIND!!" },
	InasaWall = { Id = "", Text = "Blown right back!", VoiceId = "5", Pitch = 1, Speed = 1.25, Volume = 2.8, Range = 220, Bubble = "BLOWN RIGHT BACK!!" },
	InasaRide = { Id = "", Text = "Ride the wind!", VoiceId = "5", Pitch = 1, Speed = 1.2, Volume = 2.8, Range = 220, Bubble = "RIDE THE WIND!!" },
	InasaSkyCall = { Id = "", Text = "Sky breaker...", VoiceId = "5", Pitch = 0, Speed = 0.95, Volume = 3.4, Range = 1800, Bubble = "SKYBREAKER..." },
	InasaSkyHurl = { Id = "", Text = "Cyclone!", VoiceId = "5", Pitch = 1, Speed = 1.05, Volume = 3.6, Range = 1800, Bubble = "CYCLONE!!!" },
}

-- (round 76) who says what, and when. Awaken: the line when you awaken (G),
-- by quirk. Moves: lines that go off as a move does, by the move's Id - All
-- Might charging up before every move he has. (The lines that land on a
-- moment - I AM HERE, SMASH! on the Detroit Smash, UNITED STATES OF SMASH,
-- Bakugo's FINAL BOSS - are said by their moves themselves.)
Config.VoiceCues = {
	Awaken = { Explosion = "Bakugo200", FullCowl = "DekuAwaken", PrimeDeku = "DekuAwaken", Saitama = "SaitamaOK", Whirlwind = "InasaAwaken" },
	Moves = {
		-- All Might: true form, muscle form, Plus Ultra
		TexasSmash = { "MightCharge" }, NewHampshireSmash = { "MightCharge" }, CarolinaSmash = { "MightCharge" }, HeroCounter = { "MightCharge" },
		DetroitSmash = { "MightCharge" }, OklahomaSmash = { "MightCharge" }, BackdropDriver = { "MightCharge" }, ColoradoSmash = { "MightCharge" },
		PlusUltraRush = { "MightCharge" }, TexasSmashMax = { "MightCharge" }, WeatherChanger = { "MightCharge" },
		-- Prime All Might
		MissouriSmash = { "MightCharge" }, HurricaneSmash = { "MightCharge" }, PrimeDetroit = { "MightCharge" },
		IAmHereLeap = { "MightCharge" }, PlusUltraUSJ = { "MightCharge" },
	},
}

-- OUT-OF-COMBAT HEALING: Delay seconds after your last hit (given, taken or
-- blocked) your health starts to come back - slow at first (Rate: share of
-- max health a second), building to MaxRate over Ramp seconds. Not while
-- you're down, decaying or at 0. (The server settings panel can turn it off.)
Config.Regen = {
	Enabled = true,
	Delay = 7,
	Rate = 0.015,
	MaxRate = 0.06,
	Ramp = 5,
}
Config.SoundLibraryLicensed = L
-- (round 86) DEV FLIGHT's own (ProSoundEffects / APM, every one checked
-- loadable in the place: r86/sfx_catalog.md). The beds loop (no lead-in).
-- (round 86 review: the hover bed was 9119462416 "Spiraling Wind Data Tunnel" - the
-- store calls it synthy swirling air, not wind - now the natural airy Plasma Trails
-- bed the cruise uses, pitched down (the cue's Speed): a low breeze under him)
L.FlyHoverBed = { take("9125742262", 0) } -- Plasma Trails Constant Airy Whooshing Windy 2 (33 s)
L.FlyCruiseBed = { take("9125742262", 0) } -- Plasma Trails Constant Airy Whooshing Windy 2 (33 s)
L.FlyFastBed = { take("9125742111", 0) } -- Plasma Trails Constant Airy Whooshing Windy 1 (18 s)
L.FlyHyperBed = { take("9126232239", 0.93) } -- Whoosh Phased Constant Flanging Fiery Pass Bys 2 (24.6 s)
L.FlyHyperRumble = { take("9118748093", 0) } -- Rumble Constant Roar Energy Building 2 (35 s, rock steady)
L.FlyGust = { take("9120697840", 0.59), take("9120698168", 0.67), take("9120698415", 0.72) } -- Whoosh By Howling Wind Light Rumbling 3 / 8 / 12
L.CapeFlap = { take("9113716929", 0.91), take("9113716768", 0.42) } -- Cape Flap Parachute Movement 5 / 3 (canvas rustle)
L.CapeSnap = { take("9113716967", 1.59) } -- Cape Flap Parachute Movement 6 (one big canvas snap)
L.DeepImpact7 = { take("9114036511", 0.14) } -- Deep Impacts 7 (a low punchy thump)
L.EarthCracking = { take("9114219864", 0.27) } -- Earthquake Cracking 3 (cracks, scattering debris)
L.SweepAperture = { take("9040280289", 0.5) } -- Sweeping Aperture (APM: a white-noise launch whoosh)
L.SonicBoomAPM = { take("86235382347768", 0.06) } -- Boom Sonic Boom (APM, a 6 s tail)
L.MagicZoom = { take("9116417467", 1.53) } -- Magic Swoosh Fast Zooming Pass Bys Airy 23
L.WallCrash = { take("9120479801", 0) } -- Wall Crash 1 (stone block, brick wall hit, collapse)
L.WallCrashRubble = { take("9120479831", 1.9) } -- Wall Crash 2 (its crash lands 0.5 s in: the rubble after)
L.MetalCrash = { take("9116546325", 0.16), take("9116546968", 0.16) } -- Metal Crash 1 / 8 (a hollow girder clang)
L.BodyFallDirt = { take("9113469691", 0.48) } -- Body Fall Dirt 1
L.QuakeBlast = { take("9114224675", 0) } -- Earthquake Explosion 5 (the rock hit, then the street dying)
-- (round 87, flightsfx) the flight's new sounds (ProSoundEffects / APM /
-- DistroKid, every one loaded and measured silently in Studio: octave bands
-- and envelopes in r87/out/flightsfx.md). The PSE "Sonic Boom" files under
-- L.SonicCrack measured as deep booms (all their energy under 100 Hz), so
-- the N-wave's actual crack is a whip crack - a whip's crack is a sonic
-- boom in miniature - bright at 3-6 kHz, pitched down in the cue
L.FlyCrack = { take("9120665113", 1.41), take("9120665264", 1.47) } -- Whip Cracks 1 / 4 (the crack lands ~0.04 s after Start)
L.FlyRush = { take("9116938734", 0) } -- Missile Air Constant Low Phasey Synth 1 (27 s: steady air rushing, 375 Hz-3 kHz)
L.FlyBuffet = { take("9125443949", 0) } -- Clouds Swirl Steamy Rumble Churning 5 (36 s: a churning low rumble)
L.FlyByWhomp = { take("9120696953", 0.78), take("9126233950", 0.37), take("9126234246", 0.31) } -- Whoosh By Airy Whomping 15 / Whoosh Slam Doppler 3 / 9 (each peaks 0.4 s after Start, its pitch falling through it)
L.FlyScream = { take("9118850002", 1.0) } -- Screeching Wind Sweeteners 1 (a scream rising 375 Hz -> 2.2 kHz, top 1.5 s after Start)
L.EarRing = { take("98392426611447", 2) } -- 2172 Hz pure tone (DistroKid: 99.9% of it at 2.17 kHz): pitched up ~1.6x, the ringing in your ears
L.GlassShiver = { take("9114117764", 3.95) } -- Dishes Rattle 12 (earthquake: windows and dishes shivering)
L.ThunderRoll = { take("9120021237", 5.45), take("9120021259", 3.3) } -- Thunder Rumbling 1 / 2 (a crash rolling on for seconds)
L.DistantBooms = { take("9113169432", 0.35) } -- Artillery Distant 2 (deep far-off booms: quiet, ~0.09)
L.Rumbler = { take("1843027142", 0) } -- Rumbler (APM: a 7 s sub rumble dying away)
L.GaiaRoll = { take("1841354529", 0.1) } -- Deep Gaia Rolling Impact 1 (APM: low rolls building to 1 s)
L.AirBrake = { take("9113083077", 1.25) } -- Airy Whoosh Blast 22 (air sucked in, the whomp 0.38 s after Start)
L.ClothTick = { take("9113818130", 0.08) } -- Cloth Flap 3 (one quick flap of cloth, 0.3 s)
-- (round 90, devfly2) LIGHTSPEED's own: every one from r86/sfx_catalog.md's
-- measured list (each loads in the place; Starts put the peak on the beat)
L.LightTunnel = { take("9119462416", 0) } -- Spiraling Wind Data Tunnel Travelling 2 (18 s, the flattest loop measured: synthy swirling air - the tunnel of light)
L.LightSwell = { take("9039693523", 0.95) } -- Tutti Suck (APM): the orchestral swell, sucked out ~1.4 s after Start (the charge's 1.4 s: out on the break)
L.LightRiser = { take("1843490542", 5.36) } -- Critical Mass - SFX Riser 1 (APM): its top (6.76 s) 1.4 s after Start
L.LightSuck = { take("9039693361", 1.21) } -- Gobstopper Sucker (APM): a sub suck-out, its peak ~0.7 s after Start (dropping out of it)
L.LightSizzle = { take("9120731970", 0.65) } -- Whoosh Phased Sizzling Whomping Pass Bys 3 (a crackling electric hum: the plasma round him)
-- (round 87, flightsfx) THE FLIGHT'S SOUND MIX: the cues are Config.Sounds
-- DevFly*; these say how they ride his speed, how a sonic boom changes with
-- distance, how the city answers it, the muffle, the fly-bys
Config.DevFlight.Sound = {
	-- THE WIND IN HIS EARS: a bed per tier, faded in over In = { from, to }
	-- studs/s and out over Out (equal-power: the air never dips between
	-- them). Its pitch rides the speed: the cue's Speed x (speed / Center) ^
	-- Ride (within PitchClamp); Bright: its high band, dB, from [1] slow to
	-- [2] fast (the air gets brighter and harder as he speeds up); Buffet: it
	-- shakes (below)
	Beds = {
		DevFlyHoverBed = { Out = { 0, 120 }, Center = 20, Ride = 0 },
		DevFlyCruiseBed = { In = { 30, 120 }, Out = { 180, 260 }, Center = 120, Ride = 0.22, Bright = { -9, 0 } },
		DevFlyFastBed = { In = { 150, 240 }, Out = { 380, 480 }, Center = 260, Ride = 0.22, Bright = { -6, 2 } },
		DevFlyBuffet = { In = { 160, 260 }, Out = { 480, 640 }, Center = 300, Ride = 0.15, Buffet = true },
		DevFlyHyperBed = { In = { 360, 520 }, Center = 560, Ride = 0.25, Bright = { -4, 3 } },
		DevFlyHyperTear = { In = { 400, 560 }, Center = 600, Ride = 0.2 },
		DevFlyHyperFlange = { In = { 420, 560 }, Center = 600, Ride = 0.12 },
		DevFlyHyperRumble = { In = { 300, 520 }, Center = 520, Ride = 0.1 },
	},
	-- the air's loudness riding his exact speed: { speed, dB }, a line between
	Level = { { 0, -3 }, { 90, -2 }, { 220, -1 }, { 520, 0 }, { 980, 2.5 } },
	PitchClamp = { 0.7, 1.4 },
	Follow = 6, -- 1/s: how fast a bed's volume follows the speed
	Idle = 1.5, -- s: a bed silent this long is let go (a new one when it's wanted)
	-- the take-off: silence, then the roar - the wind comes up from nothing
	-- between these (s after the launch)
	Launch = { 0.08, 0.7 },
	-- buffeting at FAST: the low rumble shaken at these rates (Hz), Depth by
	-- speed, TurnDepth more when he pulls a hard turn
	Buffet = { Rates = { 5.3, 8.7, 2.1 }, Depth = 0.45, TurnDepth = 0.35 },
	-- gusts: one at random every Every s from MinSpeed up, and one on a hard
	-- turn (the air pulling him sideways at Turn+ studs/s^2, at most every
	-- TurnGap s); Swell: the wind louder by this much in the hardest turns
	-- (round 87 review: TurnGap 0.6 -> 1.2 - steering at HYPER pulls 900+
	-- for seconds, and 3 s gusts every 0.6 s stacked five howls over the beds)
	Gust = { MinSpeed = 150, Every = { 2, 4 }, Turn = 900, TurnGap = 1.2, Swell = 0.35 },
	-- the cape: Rate = { flaps a second at a standstill, at full, the speed
	-- that's full }; quick flaps (DevFlyFlutterFast) from Fast studs/s; it's
	-- lost under the roar from Masked[1] to Masked[2]
	Cape = { Rate = { 1, 8, 450 }, Fast = 160, Masked = { 450, 700 } },
	-- the beds ducked, then roaring back in (To: how low, Hold s, Back s to
	-- come back, Over: how far over before they settle)
	Duck = {
		Boom = { To = 0.12, Hold = 0.34, Back = 0.95, Over = 1.3 },
		Boost = { To = 0.4, Hold = 0.05, Back = 0.7, Over = 1.4 },
		Brake = { To = 0.25, Hold = 0.12, Back = 0.55, Over = 1 },
		Crash = { To = 0.1, Hold = 0.3, Back = 0.8, Over = 1 },
	},
	-- THE SONIC BOOM, mixed by distance: each cue's gain is { near, far,
	-- from, to } (smoothstep over those studs) - far away the crack is gone
	-- (high frequencies die in the air), the low end and the roll carry
	Boom = {
		Mix = {
			DevFlyBoomCrack = { 1, 0.06, 150, 1100 },
			DevFlyBoomWhomp = { 1, 0, 60, 320 },
			DevFlyBoomBody = { 1, 0.8, 200, 1500 },
			DevFlyBoomSub = { 0.9, 1.6, 200, 1600 },
			DevFlyBoomRoll = { 0.5, 1.4, 150, 1200 },
			DevFlyBoomFar = { 0, 1.6, 500, 1800 },
			DevFlyBoomShiver = { 1, 0, 90, 380 },
		},
		-- the city answering: Rays out round the boom at each tilt (Tilts:
		-- how far down they lean) as far as Reach, and one at the street;
		-- each wall it meets sends it back from there, late by the extra way
		-- round / SoundSpeed, quieter by Absorb x Near / how far it went.
		-- At most Taps (half on a low-end machine), at least MinLate s after
		-- the boom and Spacing s apart, none later than MaxLate
		Echo = { Rays = 10, Tilts = { -0.2, -0.7 }, Reach = 520, Taps = 4, Absorb = 0.9, Near = 60, MinLate = 0.12, Spacing = 0.07, MaxLate = 3, Ground = true },
		-- the world muffled for a beat (his own ears, and anyone close): the
		-- game's sound groups lose { Low, Mid, High } dB at full depth (the
		-- same order as a cue's Eq), from Delay s (after the second crack)
		-- over Attack, held Hold, back over Release - then the EQ is taken
		-- off again
		Muffle = { Eq = { 2, -12, -30 }, Delay = 0.16, Attack = 0.08, Hold = 0.32, Release = 1.1 },
		MuffleWithin = 260, -- studs: watchers this close get it too (less, the farther)
		RingWithin = 220, -- studs: and their ears ring
		-- (round 87 review) boom after boom (a burst crosses BoomAt every
		-- ~1.2 s): within Within s of the last full boom this machine heard,
		-- a boom is only its punch - none of the Skip cues, no echoes, no new
		-- ringing, the muffle at Muffle x (0: none) - so the world isn't held
		-- muffled and the voices (Config.Audio.MaxVoices) stay free for the fight
		Again = { Within = 3, Skip = { DevFlyBoomRoll = true, DevFlyBoomFar = true }, Muffle = 0 },
	},
	-- the crash: the muffle and the ring this deep for him (and anyone near),
	-- and the city's echoes (Echo taps)
	Crash = { Muffle = 0.7, Ring = 0.7, Echo = 3, Late = 1.5 },
	-- FLY-BYS: someone passing within Radius[1] + Radius[2] x speed studs of
	-- your ears, closest in Lead s: a whoosh riding him (louder and lower the
	-- faster he goes: Gain / Pitch from MinSpeed to 980), once every Every s;
	-- the bright tear on top from Tear studs/s; at most Voices at once
	FlyBy = { MinSpeed = 150, Radius = { 40, 0.12 }, Lead = 0.4, Every = 1.2, Gain = { 0.45, 1.3 }, Pitch = { 1.08, 0.84 }, Tear = 220, Voices = 6 },
	-- the pitch of anyone flying, as you hear it: c / (c - K x how fast he's
	-- coming at you) (K < 1: the real thing tamed), within Clamp, followed at
	-- Follow 1/s
	Doppler = { K = 0.4, Clamp = { 0.72, 1.35 }, Follow = 10 },
	Watch = 1.2, -- everyone else hears the wind on a flyer this loud
	Voices = 10, -- at most this many of the flight's held sounds (fly-bys, rings, screams) at once
}
-- (round 90, devfly2) LIGHTSPEED in his ears: three beds of its own over the
-- hypersonic rush (the tunnel's synthy swirl, the rush pitched up bright,
-- the energy roar pitched down under it), the fiery pass-bys and the tear
-- fading out under them; the air louder again (Level). The break ducks his
-- wind deepest of all (Duck.Light) and muffles and rings like the boom
-- (Light.Muffle / Ring); the charge's swell and riser are let go fast
-- (Light.Abort s) if he lets go of the key before it breaks
do
	local SN = Config.DevFlight.Sound
	-- ((round 90 review) In from 1000, over the mach burst's top (980): from
	-- 900 every plain burst at HYPERSONIC played a third of the tunnel and the
	-- deep roar - LIGHTSPEED's own sound, leaking into the burst's)
	SN.Beds.DevFlyLightBed = { In = { 1000, 1330 }, Center = 1400, Ride = 0.15 }
	SN.Beds.DevFlyLightRush = { In = { 1030, 1360 }, Center = 1400, Ride = 0.2, Bright = { 0, 4 } }
	SN.Beds.DevFlyLightDeep = { In = { 1000, 1330 }, Center = 1400, Ride = 0.1 }
	SN.Beds.DevFlyHyperFlange.Out = { 1000, 1400 }
	SN.Beds.DevFlyHyperTear.Out = { 1000, 1400 }
	table.insert(SN.Level, { 1400, 4.5 })
	SN.Duck.Light = { To = 0.04, Hold = 0.42, Back = 1.2, Over = 1.45 }
	SN.Duck.LightOut = { To = 0.3, Hold = 0.1, Back = 0.6, Over = 1 }
	SN.Light = { Muffle = 1, Ring = 1, Abort = 0.18, Watch = { "DevFlyLightBed", "DevFlyLightDeep" } }
end
-- (round 86, hawks_ult) HAWKS' ult: the storm's build, its roar, the sweep
-- into the last cut and the suck-back as the feathers come home (licensed
-- ProSoundEffects / APM, loadable in the place: r86/sfx_catalog.md). Starts
-- put each one's peak on the beat it's played for
L.StormRiser = { take("1843490542", 5.8) } -- Critical Mass - SFX Riser 1 (APM): its top (6.8 s) about a second after Start
L.FlangeStorm = { take("9126232346", 0.93) } -- Whoosh Phased Constant Flanging Fiery Pass Bys 3 (a tearing, pulsing roar)
L.PigeonSurge = { take("9125738421", 0.69) } -- Pigeon Surges Sudden Bursts Of Birds Flying 1 (hundreds of wings, quiet)
L.WingFlapsDragon = { take("9120772394", 0.16) } -- Wing Flaps 6 (giant, dragon-sized: one huge beat)
L.SweepHit = { take("1845262222", 5.67) } -- Sweep-Hit (b) (APM): a sweep up into a hit 0.6 s after Start
L.TuttiSuck = { take("9039693523", 1.5) } -- Tutti Suck (APM): an orchestral swell, sucked out ~0.85 s after Start
L.SubSuck = { take("9039693361", 1.21) } -- Gobstopper Sucker (APM): the sub under it (peak ~0.7 s after Start)
L.ArrowPass = { take("9113166355", 0.89), take("9113166561", 0.89) } -- Arrow Out Whooshing Pass By 4 / 8: a falling zip (quiet: ~4x)
-- (round 90) SAITAMA: the Serious Punch's riser, cut so its top lands on the
-- punch when it starts with the fist drawn back (the rest of his sounds are
-- the library's own, already in L: r86/sfx_catalog.md)
L.SeriousRiser = { take("1843490542", 3.96) } -- Critical Mass - SFX Riser 1 (APM): its top (6.76 s) 2.8 s after Start
-- (round 77) whose punches sound like their own (by the attacker's quirk):
-- { light hit cue, heavy hit cue }
Config.HitSounds = {
	OneForAll = { "MightHit", "MightHeavyHit" },
	PrimeMight = { "MightHit", "MightHeavyHit" },
	Engine = { "EngineHit", "EngineHeavyHit" }, -- (round 85) Iida's kicks
	-- (round 86) Hawks: everything he lands is a cut; (round 90) his M1s their
	-- own (a blade cutting through, not a feather sticking in: Effects.Hit)
	FierceWings = { "FeatherHit", "FeatherHeavyHit", M1 = { "FeatherSlash", "FeatherSlashHeavy" } },
	Saitama = { "SaitamaHit", "SaitamaHeavyHit" }, -- (round 90) a dull, heavy thud with something cartoonish in it
	Whirlwind = { "InasaHit", "InasaHeavyHit" }, -- (round 92) a meaty punch with a burst of air behind it
}

Config.Audio = {
	Volume = 1, -- master volume for every combat sound
	MaxVoices = 48, -- hard cap on sounds playing at once
	MusicVolume = 1, -- ult music (the HUD's MUSIC button mutes it)
	VoiceVolume = 1, -- voice lines
}

Config.Sounds = {
	-- combat basics
	Swing = { { Id = L.SwishThin, Volume = 1.15, Speed = { 0.95, 1.1 } }, { Id = L.AirySlice, Volume = 1.67, Speed = { 0.9, 1.1 } } },
	HeavySwing = { { Id = L.SwishLarge, Volume = 1.4, Speed = { 0.85, 0.95 } }, { Id = L.WhooshSwishBy, Volume = 0.78, Speed = 1.1, Length = 0.6 } },
	Hit = {
		Gap = 0.03,
		{ Id = L.BeefyHit, Volume = 0.64, Speed = { 0.95, 1.1 }, Length = 0.4 },
		{ Id = L.CrackyPunch, Volume = 1.16, Speed = { 0.95, 1.1 }, Length = 0.35 },
	},
	HeavyHit = {
		Gap = 0.04,
		{ Id = L.CrackThud, Volume = 2.18, Speed = { 0.9, 1 }, Length = 0.6 },
		{ Id = L.BodyImpact, Volume = 1.34, Speed = { 0.9, 1 }, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 1.17, Speed = { 1, 1.1 }, Length = 0.9 },
	},
	Dash = { { Id = L.WhooshBurst, Volume = 0.54, Speed = { 1.1, 1.25 }, Length = 0.6 }, { Id = L.AirySlice, Volume = 0.98, Speed = 0.8 } },
	Skid = { { Id = L.DirtBurst, Volume = 0.9, Speed = { 1.35, 1.5 }, Length = 0.35 }, { Id = L.BodyFall, Volume = 0.5, Speed = 1.4, Length = 0.3 } },
	-- (round 87) THROUGH-THE-BUILDING KNOCKBACK (Config.Smash): a body
	-- bursting through a wall (the thud on it, the wall going, the glass, the
	-- rubble after), a wall splat (the body slapping into it, the crack, the
	-- grit), grit trickling off the crater, a body skidding to a stop in the
	-- street. The game's own licensed takes (r86/sfx_catalog.md: Wall Crash
	-- 1 hits at its head, Wall Crash 2's rubble lands later - its own layer)
	SmashThrough = {
		Range = 900, Gap = 0.05,
		{ Id = L.DeepImpact7, Volume = 1.1, Speed = 0.9, Near = 40 },
		{ Id = L.BodySlamThump, Volume = 1, Speed = 0.9, Peak = true, Length = 0.6 },
		{ Id = L.WallCrash, Volume = 1.3, Peak = true, Length = 1.8, Fade = 0.9, Near = 60 },
		{ Id = L.GlassBreak, Volume = 0.9, Speed = { 0.95, 1.15 }, Delay = 0.03, Length = 1, Fade = 0.4 },
		{ Id = L.WallCrashRubble, Volume = 0.8, Delay = 0.18, Length = 2.2, Fade = 1.1, Near = 40 },
	},
	SmashSplat = {
		Range = 700, Gap = 0.05,
		{ Id = L.BodySlamThump, Volume = 1.3, Speed = 0.85, Peak = true, Length = 0.7 },
		{ Id = L.DeepImpact7, Volume = 1, Speed = 0.95, Near = 40 },
		{ Id = L.BoulderCrack, Volume = 0.9, Speed = { 0.9, 1.05 }, Length = 1, Fade = 0.4 },
		{ Id = L.DebrisImpact, Volume = 0.7, Delay = 0.06, Length = 0.9, Fade = 0.4 },
	},
	SmashCrumble = { Gap = 0.2, { Id = L.DebrisMove, Volume = 0.6, Speed = 1.1, Length = 0.9, Fade = 0.4 }, { Id = L.GlassDebris, Volume = 0.35, Speed = 1.2, Length = 0.6, Fade = 0.3 } },
	SmashSkid = { Gap = 0.18, { Id = L.StoneGrind, Volume = 0.55, Speed = { 1.15, 1.35 }, Length = 0.4, Fade = 0.2 }, { Id = L.DirtBurst, Volume = 0.5, Speed = { 1.3, 1.5 }, Length = 0.3 } },
	Kick = {
		{ Id = L.BeefyHit, Volume = 0.75, Speed = { 0.85, 0.95 }, Length = 0.4 },
		{ Id = L.CrackyPunch, Volume = 1.12, Speed = { 0.85, 0.95 }, Length = 0.4 },
		{ Id = L.SwishThin, Volume = 0.75, Speed = 0.9 },
	},
	-- parkour
	PkVault = { { Id = L.SwishLarge, Volume = 0.8, Speed = 1.3, Length = 0.4 }, { Id = L.BodyFall, Volume = 0.5, Speed = 1.4, Delay = 0.25, Length = 0.3 } },
	PkClimb = { { Id = L.DirtBurst, Volume = 0.45, Speed = 1.6, Length = 0.2 }, { Id = L.BodyHit, Volume = 0.35, Speed = 1.5, Delay = 0.12, Length = 0.2 } },
	PkWallKick = { { Id = L.BodyHit, Volume = 0.8, Speed = 1.25, Length = 0.25 }, { Id = L.WhooshBurst, Volume = 0.6, Speed = 1.4, Length = 0.4 } },
	PkSlide = { { Id = L.DirtBurst, Volume = 0.8, Speed = 1.2, Length = 0.5 }, { Id = L.SwishLarge, Volume = 0.5, Speed = 1.1, Length = 0.4 } },
	PkRoll = { { Id = L.BodyFall, Volume = 0.9, Speed = 1.2, Length = 0.4 }, { Id = L.DirtBurst, Volume = 0.6, Speed = 1.4, Delay = 0.1, Length = 0.3 } },
	-- (round 66) the back dash's twist and its superhero landing
	BackTwist = { { Id = L.SwishLarge, Volume = 0.8, Speed = 1.5, Length = 0.35 }, { Id = L.AirySlice, Volume = 0.7, Speed = 1.2 } },
	HeroLand = {
		{ Id = L.CrackThud, Volume = 1.1, Speed = 1.25, Length = 0.4 },
		{ Id = L.DirtBurst, Volume = 0.8, Speed = 1.2, Length = 0.35 },
		{ Id = L.BodyFall, Volume = 0.6, Speed = 1.3, Length = 0.3 },
	},
	-- (round 66) the Support Drop: coming in, the slam, the lid popping
	PodIncoming = { Range = 500, { Id = L.JetPass, Volume = 1.1, Speed = 1.15, Length = 1.6 } },
	PodLand = {
		Range = 500,
		{ Id = L.DeepBlast, Volume = 1.1, Speed = 1.1, Length = 1 },
		{ Id = L.RockBurst, Volume = 0.9, Speed = 1, Length = 0.8 },
		{ Id = L.DebrisImpact, Volume = 0.7, Speed = 1, Delay = 0.05, Length = 0.8 },
	},
	PodOpen = { { Id = L.CanPop, Volume = 1.2, Speed = 0.6, Length = 0.5 }, { Id = L.WhooshBurst, Volume = 0.6, Speed = 1.6, Length = 0.5 } },
	-- the M1 finishers
	Uppercut = { { Id = L.CrackyPunch, Volume = 1.5, Speed = 0.85, Length = 0.4 }, { Id = L.AscendWhoosh, Volume = 1.1, Speed = 1.3, Length = 0.6 } },
	Downslam = {
		Range = 500,
		{ Id = L.BoomThump, Volume = 1.8, Speed = 1.05 },
		{ Id = L.BodyFall, Volume = 1.4, Speed = 0.9, Length = 0.6 },
		{ Id = L.DirtBurst, Volume = 1, Speed = 0.9, Length = 0.6 },
	},
	-- guard
	Block = {
		Gap = 0.04,
		{ Id = L.BodyHit, Volume = 1.37, Speed = { 1.05, 1.2 }, Length = 0.3 },
		{ Id = L.SwordTick, Volume = 0.59, Speed = { 1.2, 1.4 }, Length = 0.2 },
	},
	GuardUp = { { Id = L.SwishThin, Volume = 0.57, Speed = 1.3 } },
	Parry = {
		{ Id = L.SwordClash, Volume = 1.41, Speed = { 1.05, 1.15 }, Length = 0.8 },
		{ Id = L.CrackyPunch, Volume = 1.57, Speed = 1.2, Length = 0.3 },
		{ Id = L.SubBoom, Volume = 0.94, Speed = 1.3, Length = 0.6 },
	},
	GuardBreak = {
		{ Id = L.GlassBreak, Volume = 1.66, Speed = 0.85 },
		{ Id = L.BodyImpact, Volume = 1.87, Speed = 0.8, Length = 0.6 },
		{ Id = L.SubBoom, Volume = 1.87, Speed = 0.8 },
	},
	-- elements
	Explosion = {
		Range = 600,
		{ Id = L.ExplosionCrack, Volume = 1.74, Speed = { 1, 1.15 }, Length = 1.4 },
		{ Id = L.WhooshExplosion, Volume = 0.98, Speed = { 1.1, 1.3 }, Length = 0.6 },
	},
	BigExplosion = {
		Range = 1200,
		{ Id = L.PowerBoom, Volume = 1.73, Speed = { 0.9, 1 } },
		{ Id = L.ExplosionCrack, Volume = 1.39, Speed = 0.8, Length = 2.5 },
		{ Id = L.SubBoom, Volume = 1.56, Speed = 0.8 },
	},
	-- Howitzer Impact (ult): the whine of it spinning up, then a searing boom
	-- with a long rumbling tail that carries across the map
	-- the NUKE: an overload whine that swells right into the blast, crackling
	-- pulses counting it down, then a searing boom with a long rumbling tail
	-- that carries across the map
	NukeCharge = {
		Range = 900,
		{ Id = L.PowerUp, Volume = 2.2, Speed = 0.6, Length = 1.6 },
		{ Id = L.EnergyGrowl, Volume = 1.4, Speed = 0.7, Length = 1.4 },
		{ Id = L.SuckIn, Volume = 2.8, Delay = 0.65, Length = 1 },
		{ Id = L.Static, Volume = 1.2, Speed = 0.7, Length = 1.5 },
	},
	NukePulse = { Range = 500, { Id = L.ExplosionCrack, Volume = 0.8, Speed = { 1.5, 1.8 }, Length = 0.3 } },
	NukeBoom = {
		Range = 4000,
		{ Id = L.PowerBoomLong, Volume = 2.2, Speed = 0.75 },
		{ Id = L.DeepBlast, Volume = 1.8, Speed = 0.7, Length = 3 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.55 },
		{ Id = L.ExplosionCrack, Volume = 1.6, Speed = 0.7, Length = 3 },
		{ Id = L.Quake, Volume = 1.6, Speed = 0.8, Delay = 0.3, Length = 3 },
		{ Id = L.RockBurst, Volume = 1.2, Speed = 0.9, Delay = 0.25, Length = 2.5 },
	},
	BlastCharge = {
		Range = 900,
		{ Id = L.PowerUp, Volume = 2.2, Speed = 0.8, Length = 1.2 },
		{ Id = L.EnergyGrowl, Volume = 1.4, Speed = 0.9, Length = 1 },
		{ Id = L.Static, Volume = 1.2, Speed = 0.8, Length = 1.2 },
	},
	MegaBoom = {
		Range = 4000,
		{ Id = L.PowerBoomLong, Volume = 2.2, Speed = 0.75 },
		{ Id = L.DeepBlast, Volume = 1.8, Speed = 0.7, Length = 3 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.55 },
		{ Id = L.ExplosionCrack, Volume = 1.6, Speed = 0.7, Length = 3 },
		{ Id = L.Quake, Volume = 1.6, Speed = 0.8, Delay = 0.3, Length = 3 },
		{ Id = L.RockBurst, Volume = 1.2, Speed = 0.9, Delay = 0.25, Length = 2.5 },
	},
	Wind = { { Id = L.VortexBlast, Volume = 1.48, Speed = { 0.9, 1.05 }, Length = 1.4 }, { Id = L.GiantSwish, Volume = 1.27, Speed = 1.1, Length = 1 } },
	-- the Smash sound: a crack, a sub boom and the wind pressure rolling out
	Smash = {
		Range = 800,
		{ Id = L.CrackyPunch, Volume = 1.52, Speed = 0.75, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 1.52, Speed = { 0.9, 1 } },
		{ Id = L.WindBlast, Volume = 0.84, Speed = { 1, 1.1 }, Length = 1.3 },
		{ Id = L.BoulderCrack, Volume = 0.68, Speed = { 0.85, 1 }, Length = 1.1, Delay = 0.05 },
	},
	-- (round 81) ice crunches and cracks as it tears up through the street
	Ice = {
		{ Id = L.IceHammer, Volume = 2.77, Speed = { 0.85, 1 } },
		{ Id = L.IceCrunch, Volume = 2.46, Speed = { 0.9, 1.05 }, Length = 0.9 },
		{ Id = L.RockCrack, Volume = 1.3, Speed = { 1.25, 1.4 }, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 1.08, Speed = 1.2, Length = 0.6 },
	},
	-- (round 81) ice breaking up: chunky crunching and cracking, not glass
	Shatter = {
		Gap = 0.06,
		{ Id = L.IceHammer, Volume = 2.2, Speed = { 1.05, 1.2 } },
		{ Id = L.IceCrunch, Volume = 2.4, Speed = { 1.1, 1.25 }, Length = 0.8 },
		{ Id = L.RockCrack, Volume = 1.4, Speed = { 1.3, 1.5 }, Length = 0.5 },
		{ Id = L.DebrisImpact, Volume = 0.9, Speed = { 1.2, 1.35 }, Length = 0.5, Delay = 0.08 },
	},
	-- (round 81) someone freezing solid: a crackle of ice racing over them, a hard crunch, a breath of cold
	IceFreeze = {
		{ Id = L.IceFreezeCrackle, Volume = 1.6, Speed = { 1.25, 1.4 }, Length = 0.8, Fade = 0.35 },
		{ Id = L.IceCrunch, Volume = 2.2, Speed = { 1.2, 1.35 }, Length = 0.5 },
		{ Id = L.IceHammer, Volume = 1.2, Speed = { 1.35, 1.5 }, Length = 0.4 },
		{ Id = L.HowlingWind, Volume = 0.6, Speed = 1.5, Length = 0.6, Fade = 0.3 },
	},
	-- (round 81) ice melting off into steam: a long hiss and a soft creak
	IceMelt = {
		{ Id = L.AirRelease, Volume = 1.4, Speed = { 0.8, 0.95 }, Length = 1.3, Fade = 0.6 },
		{ Id = L.IceFreezeCrackle, Volume = 0.9, Speed = 0.7, Length = 1, Fade = 0.5 },
	},
	-- (round 81) a whole field freezing: the ground cracks and rumbles under it
	IceRumble = {
		Range = 700,
		{ Id = L.EarthCrack, Volume = 1.6, Speed = { 1.1, 1.2 }, Length = 1.4, Fade = 0.6 },
		{ Id = L.IceFreezeCrackle, Volume = 1.4, Speed = 0.9, Length = 1.6, Fade = 0.7 },
	},
	Fire = { { Id = L.FireWhoosh, Volume = 1.83, Speed = { 0.9, 1.05 }, Length = 1.4 }, { Id = L.FlameLick, Volume = 1.83, Speed = { 0.9, 1.1 }, Length = 0.9 } },
	-- (round 81) flame poured onto ice: a searing hiss as it flashes to steam,
	-- with a low roar of fire under it
	SteamHiss = {
		{ Id = L.SteamSear, Volume = 2.4, Speed = { 0.85, 1 }, Length = 1.2, Fade = 0.5 },
		{ Id = L.AirRelease, Volume = 1.8, Speed = { 1.05, 1.2 }, Length = 1.2, Fade = 0.6 },
		{ Id = L.FireWhoosh, Volume = 0.9, Speed = 0.65, Length = 1, Fade = 0.4 },
	},
	-- (round 81) Flashfreeze Heatwave going off: the superheated air bursting -
	-- a searing white roar on a deep boom, then a long hiss of steam rolling out
	SteamBlast = {
		Range = 1200,
		{ Id = L.SearBlast, Volume = 2.6, Speed = { 0.8, 0.9 }, Length = 1.8, Fade = 0.6 },
		{ Id = L.PowerBoom, Volume = 1.4, Speed = { 0.85, 0.95 } },
		{ Id = L.DeepBlast, Volume = 1.2, Speed = 0.8, Length = 2.2, Fade = 0.8 },
		{ Id = L.AirRelease, Volume = 2.2, Speed = { 0.7, 0.8 }, Length = 2.4, Fade = 1.2, Delay = 0.12 },
		{ Id = L.SubBoom, Volume = 1.3, Speed = 0.75 },
	},
	-- Iida's engines: a rising rev, then the exhaust roar
	Engine = { { Id = L.MotorRev, Volume = 1.69, Speed = { 1.1, 1.25 }, Length = 0.8 }, { Id = S.Roar, Volume = 0.74, Speed = { 1.25, 1.4 }, Length = 0.8 } },
	-- (round 85) the engine kit's cues (VFX.EngineKit). A gear shift: the
	-- gearbox's clunk, a crack, and the rev stepping up
	EngineGear = {
		{ Id = L.WoodClunk, Volume = 1.3, Speed = { 0.55, 0.62 }, Length = 0.35 },
		{ Id = S.Snap, Volume = 0.55, Speed = 0.7, Length = 0.2 },
		{ Id = L.Accelerate, Volume = 1.1, Speed = { 1.2, 1.3 }, Length = 0.6, Fade = 0.3, Delay = 0.05 },
	},
	-- a backfire: a short pop out of the pipes and a puff of air
	EngineBackfire = {
		{ Id = L.ExplosionCrack, Volume = 0.9, Speed = { 1.5, 1.7 }, Length = 0.3 },
		{ Id = L.CanPop, Volume = 1.1, Speed = { 0.6, 0.7 }, Length = 0.3 },
		{ Id = L.AirRelease, Volume = 0.7, Speed = 1.5, Length = 0.35, Fade = 0.2 },
	},
	-- the stall: one cough of a choking engine (the kit plays it two or three times)
	EngineStall = {
		Gap = 0.1,
		{ Id = L.MotorRev, Volume = 1.4, Speed = { 0.5, 0.6 }, Length = 0.14 },
		{ Id = L.CanPop, Volume = 0.6, Speed = { 0.45, 0.55 }, Length = 0.2 },
	},
	-- ...and the pipes hissing as they cool after it
	EngineCool = {
		{ Id = L.SteamTube, Volume = 0.8, Speed = { 1.1, 1.2 }, Length = 1.2, Fade = 0.7 },
		{ Id = L.AirRelease, Volume = 0.6, Speed = 0.8, Length = 1.4, Fade = 0.8 },
	},
	-- (round 88) the reacting looks (Config.CosmeticsA, VFX.CosA): small and
	-- close by, under the moves they ride on. Iida's lens glinting: a bright
	-- ting with a ring after it
	GlassesGlint = {
		Range = 140, Gap = 0.25,
		{ Id = S.Ping, Volume = 0.3, Speed = 2.6, Length = 0.35 },
		{ Id = L.BladeRing, Volume = 0.22, Speed = 1.7, Length = 0.45, Fade = 0.3 },
	},
	-- ...and fogging over: a soft puff of steam
	GlassesFog = { Range = 90, Gap = 0.3, { Id = L.SteamBurst, Volume = 0.3, Speed = 1.6, Length = 0.45, Fade = 0.25 } },
	-- Deku's soles sparking: a quiet crackle now and then
	BootCrackle = { Range = 90, Gap = 0.25, { Id = L.QuirkCrackle, Volume = 0.35, Speed = { 1.3, 1.5 }, Length = 0.3 } },
	-- ...a print burnt into the street: a short sizzle and a snap
	BootPrint = {
		Range = 140, Gap = 0.06,
		{ Id = L.Sizzle, Volume = 0.4, Speed = { 1.3, 1.5 }, Length = 0.35, Fade = 0.15 },
		{ Id = L.Zap, Volume = 0.25, Speed = 1.4, Length = 0.25 },
	},
	-- ...the boots giving after a 100% move: a crack, then a hiss of smoke
	BootStrain = {
		Range = 220, Gap = 0.4,
		{ Id = L.RockCrack, Volume = 0.7, Speed = { 1.5, 1.7 }, Length = 0.4 },
		{ Id = L.SteamSear, Volume = 0.6, Speed = 1.2, Length = 1.1, Fade = 0.5, Delay = 0.05 },
	},
	-- Bakugo's tubes full again: a click of the pins and a fizz
	SweatFull = {
		Range = 90, Gap = 0.5,
		{ Id = L.SwordTick, Volume = 0.35, Speed = 1.8, Length = 0.25 },
		{ Id = L.Sizzle, Volume = 0.3, Speed = 1.7, Length = 0.4, Fade = 0.2 },
	},
	-- (round 90) THE SKY COFFIN'S SHIELD GOING DOWN (VFX.SB): the break - a
	-- crackling boom, the field cracking like glass, a burst of electricity,
	-- a deep thump under it and the shards raining on after
	SkyBreak = {
		Range = 900, Gap = 0.15,
		{ Id = L.GlassSmash, Volume = 1.5, Speed = { 0.72, 0.8 }, Length = 1 },
		{ Id = L.QuirkCrackle, Volume = 1.6, Speed = { 0.85, 0.95 }, Length = 0.6 },
		{ Id = L.Zap, Volume = 1.1, Speed = 0.7, Length = 0.7, Delay = 0.02 },
		{ Id = L.SubBoom, Volume = 1.4, Speed = 0.8, Length = 1.2, Fade = 0.6 },
		{ Id = L.GlassDebris, Volume = 0.9, Speed = { 1.05, 1.2 }, Length = 0.9, Fade = 0.4, Delay = 0.18 },
	},
	-- ...a panel stuttering as it fails (and the crack's edge crackling)
	SkyCrackle = { Range = 260, Gap = 0.2, { Id = L.QuirkCrackle, Volume = 0.55, Speed = { 1.2, 1.5 }, Length = 0.3, Near = 40 } },
	-- ...the whole shield powering down: the stutter, a groan, and the hum
	-- stepping down and fading out (heard right across the arena: Near)
	SkyPowerDown = {
		Range = 1100, Gap = 1,
		{ Id = L.CrackleRun, Volume = 1.2, Speed = 0.9, Length = 1.4, Fade = 0.5, Near = 260 },
		{ Id = L.EnergyGrowl, Volume = 1.3, Speed = 0.55, Length = 2.2, Fade = 1.2, Delay = 0.15, Near = 260 },
		{ Id = L.Static, Volume = 0.9, Speed = 0.85, Length = 0.8, Fade = 0.4, Delay = 0.3, Near = 260 },
		{ Id = L.Static, Volume = 0.7, Speed = 0.62, Length = 0.9, Fade = 0.5, Delay = 0.9, Near = 260 },
		{ Id = L.Static, Volume = 0.5, Speed = 0.45, Length = 1.2, Fade = 0.9, Delay = 1.6, Near = 260 },
	},
	-- ...booting back up: the hum rising, static crawling up it
	SkyPowerUp = {
		Range = 1100, Gap = 1,
		{ Id = L.PowerUp, Volume = 1.6, Speed = 0.62, Length = 2.8, Fade = 0.4, Near = 260 },
		{ Id = L.Static, Volume = 0.6, Speed = 0.7, Length = 1.2, Fade = 0.5, Delay = 0.4, Near = 220 },
		{ Id = L.Static, Volume = 0.75, Speed = 0.95, Length = 1, Fade = 0.4, Delay = 1.4, Near = 220 },
	},
	-- ...and the field whole again: a snap and a zap
	SkyOnline = {
		Range = 1100, Gap = 1,
		{ Id = L.EnergySnap, Volume = 1.2, Speed = 0.9, Length = 0.6, Near = 260 },
		{ Id = L.Zap, Volume = 0.8, Speed = 0.8, Length = 0.6, Near = 220 },
		{ Id = L.SubBoom, Volume = 0.7, Speed = 1.1, Length = 0.8, Fade = 0.4, Near = 220 },
	},
	-- the ignition: a rev that catches, the fire coughing out, then the jets' roar
	EngineIgnite = {
		Range = 500,
		{ Id = L.MotorRev, Volume = 1.6, Speed = { 1.4, 1.5 }, Length = 0.45 },
		{ Id = L.FireBurst, Volume = 0.9, Speed = 1.25, Length = 0.35 },
		{ Id = L.JetPass, Volume = 1.1, Speed = 1.45, Length = 0.7, Fade = 0.35, Delay = 0.2 },
	},
	-- his kicks landing (Config.HitSounds.Engine): a meaty boot into a body
	EngineHit = {
		Gap = 0.03,
		{ Id = L.BeefyHit, Volume = 0.85, Speed = { 0.78, 0.88 }, Length = 0.4 },
		{ Id = L.CrackyPunch, Volume = 1.05, Speed = { 0.8, 0.9 }, Length = 0.35 },
		{ Id = L.BodySlamThump, Volume = 0.7, Speed = { 1, 1.1 }, Length = 0.45, Peak = true, Eq = { 3, 0, -2 } },
	},
	-- ...and his heavy ones (15+ damage, or marked heavy): the boot, the boom, the engines' roar
	EngineHeavyHit = {
		Gap = 0.04,
		{ Id = L.CrackThud, Volume = 2, Speed = { 0.85, 0.92 }, Length = 0.6 },
		{ Id = L.BodySlamThump, Volume = 1.2, Speed = 0.95, Length = 0.6, Peak = true, Eq = { 4, 0, -2 } },
		{ Id = L.SubBoom, Volume = 1.1, Speed = 1, Length = 0.9 },
		{ Id = L.JetPass, Volume = 0.6, Speed = 1.7, Length = 0.4, Fade = 0.2 },
	},
	-- (round 85) ENGINE GATLING's barrage: the engines revving higher and
	-- higher the whole way through it (the jets pulse with every kick)
	EngineGatling = {
		Range = 450,
		{ Id = L.Accelerate, Volume = 1.2, Speed = { 1.15, 1.2 }, Length = 0.6, Fade = 0.15 },
		{ Id = L.MotorRev, Volume = 0.9, Speed = { 1.35, 1.45 }, Length = 0.55, Fade = 0.2 },
	},
	-- AP Shot: a pinpoint crack-bang
	Beam = {
		Range = 700,
		{ Id = L.ExplosionCrack, Volume = 1.02, Speed = 1.3, Length = 0.8 },
		{ Id = L.EnergySnap, Volume = 0.76, Speed = 1.25, Length = 0.6 },
		{ Id = L.WhooshExplosion, Volume = 0.51, Speed = 1.4, Length = 0.5 },
	},
	Grenade = { { Id = S.Flash, Volume = 2.03, Speed = 0.8 }, { Id = L.WhooshExplosion, Volume = 1.02, Speed = 1.2, Length = 0.7 }, { Id = S.Ping, Volume = 0.85, Speed = 2, Delay = 0.05, Length = 1.4 } },
	-- blinded by the Stun Grenade: the high whine in your ears
	Ringing = { Range = 9999, { Id = S.Ping, Volume = 1.1, Speed = 2.6, Length = 2.4 }, { Id = S.Ping, Volume = 0.6, Speed = 2.9, Delay = 0.3, Length = 2 } },
	-- Bakugo's M1s: a little blast off the palm
	PalmPop = { { Id = L.ExplosionCrack, Volume = 0.9, Speed = { 1.4, 1.6 }, Length = 0.35 }, { Id = L.WhooshExplosion, Volume = 0.5, Speed = 1.5, Length = 0.3 } },
	-- (round 92) MAX CAPACITY (Bakugo's 4th): the gauntlet filling to bursting
	-- (a power-up whine, crackling, the hiss of it heating), the pin pulled
	-- (a bright metal ting), the blast (a searing boom with a long rumbling
	-- tail, the street torn up behind it - heard across the city), and the
	-- gauntlet venting steam after
	MaxCapCharge = {
		Range = 500,
		{ Id = L.PowerUp, Volume = 1.6, Speed = 1.05, Length = 0.6, Fade = 0.1 },
		{ Id = L.QuirkCrackle, Volume = 1.1, Speed = 1.25, Length = 0.55 },
		{ Id = L.SteamSear, Volume = 0.8, Speed = 1.2, Length = 0.5, Fade = 0.15 },
	},
	MaxCapPin = {
		Range = 300,
		{ Id = S.Ping, Volume = 1.2, Speed = 1.7, Length = 0.6 },
		{ Id = L.BladeRing, Volume = 0.7, Speed = 1.6, Length = 0.5, Fade = 0.2 },
		{ Id = L.MetalSwoosh, Volume = 0.5, Speed = 1.8, Length = 0.25 },
	},
	MaxCapBlast = {
		Range = 2000,
		{ Id = L.PowerBoomLong, Volume = 2.2, Speed = 0.85 },
		{ Id = L.DeepBlast, Volume = 1.8, Speed = 0.8, Length = 2.5 },
		{ Id = L.WhooshExplosion, Volume = 1.6, Speed = 0.75, Length = 1.2 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.6 },
		{ Id = L.ExplosionCrack, Volume = 1.5, Speed = 0.75, Length = 2.5 },
		{ Id = L.RockBurst, Volume = 1.2, Speed = 1, Delay = 0.12, Length = 2 },
	},
	MaxCapVent = { Range = 200, { Id = L.SteamBurst, Volume = 0.9, Speed = 1.1, Length = 1.2, Fade = 0.5 }, { Id = L.Sizzle, Volume = 0.6, Speed = 0.9, Length = 1, Fade = 0.4 } },
	Leap = { { Id = L.WhooshBurst, Volume = 0.7, Speed = 0.9, Length = 1 }, { Id = L.AscendWhoosh, Volume = 0.7, Length = 1 } },
	-- one signature move per quirk (windup + payoff)
	-- EXPLOSIVE SPEED: the sweat beads popping all over him (a crackle that
	-- quickens), the blitz, time slowing right down, then the point-blank blast
	BlitzCharge = {
		{ Id = L.QuirkCrackle, Volume = 1.3, Speed = 1.3, Length = 0.7 },
		{ Id = L.ExplosionCrack, Volume = 0.7, Speed = 1.8, Length = 0.2, Delay = 0.12 },
		{ Id = L.ExplosionCrack, Volume = 0.8, Speed = 1.9, Length = 0.2, Delay = 0.3 },
		{ Id = L.ExplosionCrack, Volume = 0.9, Speed = 2, Length = 0.2, Delay = 0.42 },
		{ Id = L.Static, Volume = 1.2, Speed = 1.2, Length = 0.6 },
	},
	-- THE JIGGY's confetti popper on the dab
	Confetti = { { Id = L.ExplosionCrack, Volume = 0.6, Speed = 2.2, Length = 0.25 }, { Id = L.AirySlice, Volume = 1, Speed = 1.3 } },
	BlitzGo = { Range = 500, { Id = L.WhooshBurst, Volume = 1.4, Speed = 1.25, Length = 0.6 }, { Id = L.ExplosionCrack, Volume = 1.2, Speed = 1.3, Length = 0.5 }, { Id = L.AirySlice, Volume = 1.2, Speed = 0.8 } },
	-- (round 83) the time-crawl is 0.5s now (it was 1.3)
	BlitzSlow = { { Id = L.SuckShort, Volume = 2.4, Speed = 0.5, Length = 0.6, Fade = 0.15 }, { Id = L.EnergyGrowl, Volume = 0.8, Speed = 0.55, Length = 0.55, Fade = 0.15 } },
	-- (round 83) the blitz: his palm going off in their face on "GOT" (kept
	-- under the line), the blur of an overtake, the boom of him passing them,
	-- the blast from in front (each a little bigger than the last)
	BlitzOpen = { { Id = L.ExplosionCrack, Volume = 1, Speed = { 1.25, 1.35 }, Length = 0.45 }, { Id = L.SubBoom, Volume = 0.7, Speed = 1.2, Length = 0.5 } },
	BlitzPass = { Gap = 0.05, { Id = L.WhooshBurst, Volume = 0.8, Speed = 1.6, Length = 0.3 }, { Id = L.WhooshSwishBy, Volume = 0.7, Speed = 1.4, Length = 0.3 } },
	BlitzBoom = { Gap = 0.05, { Id = L.SonicCrack, Volume = 0.7, Speed = { 1.15, 1.3 }, Length = 0.5, Fade = 0.2, Peak = true }, { Id = L.ExplosionCrack, Volume = 0.5, Speed = 2, Length = 0.2 } },
	BlitzHit = { Gap = 0.05, { Id = L.ExplosionCrack, Volume = 1.1, Speed = { 1.2, 1.4 }, Length = 0.45 }, { Id = L.WhooshExplosion, Volume = 0.6, Speed = 1.35, Length = 0.35 }, { Id = L.BodyImpact, Volume = 0.8, Speed = 1.3, Length = 0.3 } },
	HowitzerSpin = {
		{ Id = L.ExplosionCrack, Volume = 1.18, Speed = 1.4, Length = 0.3 },
		{ Id = L.ExplosionCrack, Volume = 1.18, Speed = 1.5, Length = 0.3, Delay = 0.18 },
		{ Id = L.ExplosionCrack, Volume = 1.31, Speed = 1.35, Length = 0.3, Delay = 0.36 },
		{ Id = L.FireWhoosh, Volume = 1.57, Speed = 1.2, Length = 0.8 },
	},
	DetroitCharge = { { Id = L.PowerUp, Volume = 2.66, Speed = 0.9, Length = 0.8 }, { Id = L.Static, Volume = 1.77, Speed = 0.9 }, { Id = L.SuckShort, Volume = 3.55, Length = 0.6 } },
	FaJinSwing = { Gap = 0.05, { Id = L.GiantSwish, Volume = 0.8, Speed = { 1.1, 1.3 }, Length = 0.35 } }, -- each swing of the wind-up
	FaJinRelease = {
		Range = 900,
		{ Id = L.WindBlast, Volume = 2, Speed = 0.85, Length = 2.2 },
		{ Id = L.SubBoom, Volume = 1.5, Speed = 0.8 },
		{ Id = L.WindRoar, Volume = 1.3, Speed = 1.1, Delay = 0.08, Length = 2 },
	},
	-- ONE FOR ALL at 100%: the smash, and the arm giving way under it
	HundredSmash = {
		Range = 1400,
		{ Id = L.CrackyPunch, Volume = 2, Speed = 0.7, Length = 0.6 },
		{ Id = L.PowerBoom, Volume = 2, Speed = 0.8, Length = 2 },
		{ Id = L.WindRoar, Volume = 1.6, Length = 2.5 },
		{ Id = L.VortexBlast, Volume = 1.4, Speed = 0.7, Delay = 0.05, Length = 2 },
	},
	ArmBreak = { Range = 250, { Id = L.BoneSnap, Volume = 1.8, Length = 0.7 }, { Id = L.CrackThud, Volume = 1, Speed = 1.3, Length = 0.3 } },
	-- DEKU DROPS IN: the scream of the fall, the landing, the charge, the launch
	DekuFall = { Range = 1500, { Id = L.HowlingWind, Volume = 1.4, Speed = 1.25, Length = 2.4 }, { Id = L.JetPass, Volume = 1, Speed = 0.8, Delay = 1, Length = 1.4 } },
	DekuImpact = {
		Range = 2400,
		{ Id = L.BodyFallHuge, Volume = 2.5, Speed = 0.7 },
		{ Id = L.PowerBoom, Volume = 2.4, Speed = 0.7, Length = 3 },
		{ Id = L.Quake, Volume = 2.2, Speed = 0.8, Length = 3 },
		{ Id = L.RockBurst, Volume = 1.8, Delay = 0.1, Length = 3 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.6 },
	},
	CowlCharge = { Range = 500, { Id = L.EnergyGrowl, Volume = 1.5, Speed = 1.1, Length = 1.6 }, { Id = L.CrackleRun, Volume = 1.3, Length = 1.6 } },
	-- ENDEAVOR: flame licking in his hand, the roar of a jet of it, the
	-- whump of it all going up at once
	HellSpiderCharge = { { Id = L.FlameLick, Volume = 1, Speed = 1.3, Length = 0.5 }, { Id = S.Aura, Volume = 0.6, Speed = 1.4 } },
	HellSpider = { Range = 500, { Id = L.AirySlice, Volume = 1.4, Speed = 0.8 }, { Id = L.FireWhoosh, Volume = 1.3, Speed = 1.3, Length = 0.8 }, { Id = S.Beam, Volume = 0.5, Speed = 1.8, Length = 0.5 } },
	FireBlast = { Range = 700, { Id = L.FireBurst, Volume = 1.6 }, { Id = L.WhooshExplosion, Volume = 1.2, Speed = 0.9 }, { Id = L.SubBoom, Volume = 1 } },
	FirePunch = { Gap = 0.04, { Id = L.FlameLick, Volume = 0.8, Speed = { 1.1, 1.3 }, Length = 0.4 }, { Id = L.FireWhoosh, Volume = 0.5, Speed = 1.5, Length = 0.3 } },
	JetBurnCharge = { { Id = L.FlameLick, Volume = 1.2, Speed = 0.9, Length = 0.6 }, { Id = L.SuckShort, Volume = 1, Speed = 1.4, Length = 0.4 } },
	JetBurn = { Range = 900, { Id = S.Roar, Volume = 1.3, Speed = 0.9, Length = 1.2 }, { Id = L.FireWhoosh, Volume = 1.6, Speed = 0.8, Length = 1.2 }, { Id = L.FireBurst, Volume = 1.2, Speed = 0.9 } },
	FlameOut = { { Id = L.SuckShort, Volume = 1.4, Speed = 1.6, Length = 0.35 }, { Id = S.Swoosh, Volume = 0.6, Speed = 0.8 } },
	VanishingFist = { Range = 1000, { Id = L.PowerBoom, Volume = 2, Speed = 1 }, { Id = L.FireBurst, Volume = 1.8, Speed = 0.8 }, { Id = L.CrackyPunch, Volume = 1.4, Speed = 0.8 }, { Id = L.SubBoom, Volume = 1.6, Speed = 0.8 } },
	FlashfireJet = { Range = 600, { Id = S.Jet, Volume = 1.2, Speed = 1.1, Length = 0.8 }, { Id = L.FireWhoosh, Volume = 1.2, Speed = 1.1, Length = 0.8 } },
	CurtainCharge = { { Id = L.SuckIn, Volume = 1.6, Speed = 1.6, Length = 0.5 }, { Id = L.FlameLick, Volume = 1, Speed = 0.8, Length = 0.5 } },
	HellsCurtain = { Range = 900, { Id = L.FireWhoosh, Volume = 2, Speed = 0.6, Length = 1.5 }, { Id = L.FireBurst, Volume = 1.6, Speed = 0.7 }, { Id = L.HowlingWind, Volume = 1, Speed = 1.2, Length = 1 } },
	FistFly = { Range = 900, { Id = S.Roar, Volume = 1.4, Speed = 0.8, Length = 1 }, { Id = L.FireWhoosh, Volume = 1.4, Speed = 0.7, Length = 1 } },
	FistBoom = { Range = 1600, { Id = L.PowerBoomLong, Volume = 2.4, Speed = 0.85, Length = 2.5 }, { Id = L.FireBurst, Volume = 2, Speed = 0.7 }, { Id = L.SubBoom, Volume = 2, Speed = 0.7 }, { Id = L.Quake, Volume = 1.2 } },
	ProminenceCharge = { Range = 800, { Id = L.SuckIn, Volume = 2.4, Speed = 0.9, Length = 1 }, { Id = L.FlameLick, Volume = 1.6, Speed = 0.6, Length = 1 }, { Id = L.EnergyGrowl, Volume = 1.2, Speed = 0.6 } },
	SkyRise = { Range = 1200, { Id = S.Roar, Volume = 1.8, Speed = 0.8, Length = 1.4 }, { Id = L.AscendWhoosh, Volume = 2, Speed = 0.8 }, { Id = L.FireWhoosh, Volume = 1.6, Speed = 0.7, Length = 1.2 } },
	SkyProminence = {
		Range = 3000,
		{ Id = L.PowerBoomLong, Volume = 3, Speed = 0.7, Length = 3 },
		{ Id = L.FireBurst, Volume = 2.4, Speed = 0.55 },
		{ Id = L.SubBoom, Volume = 2.4, Speed = 0.6 },
		{ Id = L.WindRoar, Volume = 1.8, Speed = 0.8, Delay = 0.2, Length = 2.5 },
	},
	Overheat = { { Id = L.HowlingWind, Volume = 1, Speed = 2.2, Length = 1 }, { Id = L.FlameLick, Volume = 0.8, Speed = 0.6, Length = 0.6 } },
	UltHellflame = {
		Range = 1400,
		{ Id = S.Stinger, Volume = 1, Speed = 0.9 },
		{ Id = L.FireBurst, Volume = 2, Speed = 0.6 },
		{ Id = L.PowerUp, Volume = 1.4, Speed = 0.8, Delay = 0.1 },
		{ Id = S.Roar, Volume = 1.4, Speed = 0.7, Length = 1.4 },
	},
	-- DABI: the same roar, lower and colder
	Cremation = { Range = 900, { Id = L.FireWhoosh, Volume = 1.8, Speed = 0.75, Length = 1 }, { Id = S.Roar, Volume = 1, Speed = 1.2, Length = 0.9 }, { Id = L.FlameLick, Volume = 1.2, Speed = 0.7, Delay = 0.1 } },
	Minefield = { { Id = L.FlameLick, Volume = 1.2, Speed = 0.6, Length = 0.8 }, { Id = L.Quake, Volume = 1, Speed = 1.2, Length = 1 } },
	MinefieldErupt = { Range = 800, Gap = 0.05, { Id = L.FireBurst, Volume = 1.6, Speed = { 0.8, 1 } }, { Id = L.DirtBurst, Volume = 1, Speed = 1.1, Length = 0.6 } },
	BlueSpider = { Range = 900, { Id = L.FireWhoosh, Volume = 1.6, Speed = 0.9, Length = 0.9 }, { Id = S.Roar, Volume = 1.1, Speed = 1.3, Length = 0.8 } },
	BlueWall = { Range = 900, { Id = L.FireBurst, Volume = 1.8, Speed = 0.8 }, { Id = L.BoomThump, Volume = 1.2 }, { Id = L.FireWhoosh, Volume = 1.2, Speed = 0.6, Length = 1.2 } },
	BlueJet = { Range = 700, { Id = S.Jet, Volume = 1.2, Speed = 1.2, Length = 0.6 }, { Id = L.FireWhoosh, Volume = 1.2, Speed = 1.2, Length = 0.6 } },
	BlueBlast = { Range = 1000, { Id = L.FireBurst, Volume = 1.8, Speed = 0.9 }, { Id = L.PowerBoom, Volume = 1.6, Speed = 1.1 }, { Id = L.CrackyPunch, Volume = 1.2 } },
	BlueProminence = {
		Range = 2000,
		{ Id = S.Beam, Volume = 1.4, Speed = 0.6, Length = 1.4 },
		{ Id = S.Roar, Volume = 2, Speed = 0.7, Length = 1.4 },
		{ Id = L.FireWhoosh, Volume = 2, Speed = 0.55, Length = 1.4 },
		{ Id = L.SubBoom, Volume = 1.6, Speed = 0.7 },
	},
	SekotoPeak = { Range = 1600, { Id = L.FireWhoosh, Volume = 2.2, Speed = 0.5, Length = 2 }, { Id = L.FireBurst, Volume = 2, Speed = 0.6 }, { Id = L.WindRoar, Volume = 1.4, Speed = 0.9, Length = 2 } },
	UltBlueflame = {
		Range = 1400,
		{ Id = S.Stinger, Volume = 1, Speed = 0.8 },
		{ Id = L.FireBurst, Volume = 2, Speed = 0.5 },
		{ Id = L.EnergyGrowl, Volume = 1.4, Speed = 0.6 },
		{ Id = S.Beast, Volume = 0.8, Speed = 1.2, Length = 1.5 },
	},
	-- (round 86) HAWKS: wing beats (pitched up, a feathery rustle on top),
	-- the feathers' "thwip", their hit and the click as one slots home, the
	-- blades. WingBeat: one big downstroke (the takeoff); WingFlap: a beat in
	-- flight (hover / climb); WingSnap: the wings snapped open; WingFold:
	-- tucked away. HawksWind and CycloneLoop are LOOPED beds (VFX.HK.loop
	-- plays their first layer's first take, looped, on his body)
	WingBeat = { Gap = 0.08, Range = 320, { Id = L.WingFlapBig, Volume = 0.7, Speed = { 1.08, 1.2 }, Length = 0.9 }, { Id = L.FeatherRustle, Volume = 4, Speed = { 0.95, 1.1 }, Length = 0.6 } },
	WingFlap = { Gap = 0.12, Range = 220, { Id = L.WingFlutter, Volume = 1.8, Speed = { 0.95, 1.2 } }, { Id = L.WingFlapShort, Volume = 1.1, Speed = { 1.1, 1.25 }, Length = 0.5 } },
	WingSnap = { Gap = 0.06, Range = 260, { Id = L.WingFlapShort, Volume = 1.3, Speed = 1.25, Length = 0.45 }, { Id = L.CapeSnap, Volume = 0.4, Speed = 1.3, Length = 0.5 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1.15, Length = 0.4 } },
	WingFold = { Gap = 0.1, { Id = L.WingFlutter, Volume = 1.4, Speed = 0.9 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1.1, Length = 0.5 } },
	HawksTakeoff = { Range = 420, { Id = L.MagicFlutter, Volume = 1.2, Length = 1.2 }, { Id = L.WingFlapHuge, Volume = 0.45, Speed = 1.12, Length = 1.3 }, { Id = L.WhooshBurst, Volume = 0.6, Speed = 1.1, Length = 0.8 } },
	HawksBoost = { Gap = 0.2, Range = 380, { Id = L.JetPass, Volume = 0.9, Speed = 1.4, Length = 1 }, { Id = L.WingFlapShort, Volume = 1.3, Speed = 1.3, Length = 0.4 } },
	HawksLand = { Gap = 0.2, Range = 260, { Id = L.BodyFall, Volume = 0.5, Speed = 1.1, Length = 0.6 }, { Id = L.WingFlapBig, Volume = 0.5, Speed = 1.25, Length = 0.6 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1, Length = 0.6 } },
	HawksWind = { { Id = L.AiryWind, Volume = 2.5, Speed = 1 } },
	FeatherThwip = { Gap = 0.03, { Id = L.FeatherSwish, Volume = 0.8, Speed = { 1.3, 1.7 }, Length = 0.35 } },
	FeatherVolley = { Range = 320, { Id = L.FeatherSwarm, Volume = 1.2, Speed = { 1, 1.15 } }, { Id = L.WingFlapShort, Volume = 1.2, Speed = 1.25, Length = 0.4 } },
	FeatherHit = { Gap = 0.04, { Id = L.ArrowHit, Volume = 1, Speed = { 1, 1.2 }, Length = 0.45 }, { Id = L.BeefyHit, Volume = 0.3, Speed = { 1.1, 1.25 }, Length = 0.25 } },
	FeatherHeavyHit = { Gap = 0.05, { Id = L.ArrowThunk, Volume = 0.5, Speed = { 0.95, 1.05 }, Length = 0.6 }, { Id = L.SwordShing, Volume = 0.6, Speed = 1.1, Length = 0.5 }, { Id = L.BeefyHit, Volume = 0.5, Speed = 0.95, Length = 0.35 } },
	FeatherReturn = { Gap = 0.03, { Id = L.SwordTick, Volume = 0.25, Speed = { 2.4, 2.8 }, Length = 0.2 } },
	FeatherGrow = { Gap = 0.06, { Id = L.SwordTick, Volume = 0.08, Speed = { 2.9, 3.2 }, Length = 0.15 } },
	-- (round 90) his M1s retuned: a light blade whipping through the air with
	-- a feathery rustle on it (it was a metal clang and a foil swipe), the
	-- 4th a heavier whip and a shing; the blade's own layer on a hit is a cut
	-- going in (a stab, a wet thud - no metal-on-metal impact)
	FeatherSwing = { { Id = L.SwordWhip, Volume = 0.75, Speed = { 1.2, 1.38 }, Length = 0.38 }, { Id = L.FeatherSwish, Volume = 0.6, Speed = { 1.25, 1.45 }, Length = 0.3 },
		{ Id = L.FeatherRustle, Volume = 2.2, Speed = { 1.15, 1.3 }, Length = 0.3 } },
	FeatherHeavy = { { Id = L.SwordWhip, Volume = 1, Speed = { 0.95, 1.05 }, Length = 0.55 }, { Id = L.SwordShing, Volume = 0.6, Speed = 1.05, Length = 0.5 },
		{ Id = L.GiantSwish, Volume = 0.55, Speed = 1.35, Length = 0.5 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1.1, Length = 0.5 } },
	FeatherBladeHit = { Gap = 0.04, { Id = L.SwordStab, Volume = 0.6, Speed = { 1.15, 1.3 }, Length = 0.3 }, { Id = L.MeatyThud, Volume = 0.45, Speed = { 1.2, 1.35 }, Length = 0.25 } },
	FeatherDraw = { Gap = 0.2, { Id = L.SwordDraw, Volume = 0.35, Speed = 1.6, Length = 0.4 }, { Id = L.SwishThin, Volume = 0.4, Speed = 2, Length = 0.25 } },
	-- (round 90) HAWKS: an M1 landing (HitSounds.FierceWings.M1: a dry cut and
	-- the anime crack - the arrow in wood stays for his feathers); every dash's
	-- three feathers peeling off; the wings snapping open and catching him in
	-- the air (R off the street); the braked fall (a flutter now and then, a
	-- LOOPED wind bed: VFX.HK.loop); the homecoming stream whipping past
	FeatherSlash = { Gap = 0.03, { Id = L.AirySlice, Volume = 1.2, Speed = { 1.25, 1.45 }, Length = 0.3 }, { Id = L.CrackyPunch, Volume = 0.55, Speed = { 1.1, 1.25 }, Length = 0.3 } },
	FeatherSlashHeavy = { Gap = 0.05, { Id = L.SwordShing, Volume = 0.8, Speed = 0.95, Length = 0.6 }, { Id = L.CrackThud, Volume = 1.2, Speed = 1.05, Length = 0.45 },
		{ Id = L.AirySlice, Volume = 1.3, Speed = 1, Length = 0.35 } },
	HawksDash = { Gap = 0.08, Range = 220, { Id = L.FeatherRustle, Volume = 3.5, Speed = { 1.1, 1.3 }, Length = 0.4 }, { Id = L.FeatherSwish, Volume = 0.5, Speed = { 1.5, 1.8 }, Length = 0.25 } },
	HawksAirCatch = { Gap = 0.2, Range = 320, { Id = L.WingFlapBig, Volume = 0.75, Speed = 1.15, Length = 0.8 }, { Id = L.CapeSnap, Volume = 0.45, Speed = 1.2, Length = 0.5 },
		{ Id = L.FeatherRustle, Volume = 4, Speed = 1.05, Length = 0.6 } },
	HawksBrake = { Gap = 0.4, Range = 220, { Id = L.WingFlutter, Volume = 1.4, Speed = 0.85 }, { Id = L.FeatherRustle, Volume = 3, Speed = 0.95, Length = 0.6 } },
	HawksFallWind = { { Id = L.AiryWind, Volume = 1.6, Speed = 0.85 } },
	FeatherHome = { Gap = 0.08, Range = 160, { Id = L.ArrowPass, Volume = 2.5, Speed = { 1.2, 1.4 }, Length = 0.6 }, { Id = L.FeatherRustle, Volume = 2.5, Speed = 1.2, Length = 0.4 } },
	SwiftCut = { Range = 360, { Id = L.SwordShing, Volume = 1, Length = 0.7 }, { Id = L.WhooshSwishBy, Volume = 1, Speed = 1.3, Length = 0.6 }, { Id = L.MagicZoom, Volume = 0.7, Speed = 1.25, Length = 0.6 } }, -- (round 86, C2: the zoom)
	SwiftCutRing = { Gap = 0.05, { Id = L.BladeRing, Volume = 0.55, Speed = 1.15, Length = 0.8 }, { Id = L.SwordFoil, Volume = 0.6, Speed = 1.2 }, { Id = L.ArrowHit, Volume = 0.7, Speed = 1.15, Length = 0.35 } }, -- (round 86, C2: the pop of it opening)
	CycloneStart = { Range = 360, { Id = L.VortexBlast, Volume = 0.8 }, { Id = L.ClothBloom, Volume = 1.4, Length = 1.2 } },
	CycloneLoop = { { Id = L.TearingAir, Volume = 1.6 } },
	CycloneBurst = { Range = 420, { Id = L.WindBlast, Volume = 0.9, Length = 1.4 }, { Id = L.GiantSwish, Volume = 1 }, { Id = L.FeatherSwarm, Volume = 1.2, Speed = 0.85 } }, -- (round 86, C2: the swarm flung out)
	FeatherBlock = { Gap = 0.05, { Id = L.SwordClash, Volume = 0.4, Speed = 1.4, Length = 0.3 } },
	CarryHook = { Gap = 0.05, { Id = L.ArrowHit, Volume = 0.9, Speed = 1.4, Length = 0.3 }, { Id = L.ClothBloom, Volume = 1.2, Length = 0.8 } },
	CarryLift = { Range = 360, { Id = L.AscendWhoosh, Volume = 1 }, { Id = L.WingFlapBig, Volume = 0.5, Speed = 1.2 } },
	CarrySlam = { Range = 500, { Id = L.BodySlamThump, Volume = 1.1 }, { Id = L.DebrisImpact, Volume = 0.9, Speed = 1.1, Length = 0.8 }, { Id = L.DeepImpact7, Volume = 0.7, Speed = 0.9, Length = 0.9 }, { Id = L.BodyFallDirt, Volume = 0.6, Speed = 1.05, Length = 0.9 } }, -- (round 86, C2: the deep thump and the dirt under it)
	-- (round 86, C2) HAWKS' MOVES, presented: the barrage's feathers
	-- bristling out of the wings (a rustle, a dry metal shk), their fly-by,
	-- the mark (his screen: a soft ping as he feels them through it); Swift
	-- Cut's coil (an inhale of air), the pass (the shing, a heavy wooden
	-- strike and a sub thump under the impact frame), the skid, the twirl;
	-- the cyclone's feathers bursting off his wings (a surge of wings), the
	-- blades whirring past each other, the gusts; the carry's whirl and dive
	FeatherBristle = { Gap = 0.1, { Id = L.FeatherRustle, Volume = 4, Speed = 1.2, Length = 0.45 }, { Id = L.SwordDraw, Volume = 0.22, Speed = 2.2, Length = 0.25 } },
	FeatherFlyby = { Gap = 0.3, Range = 120, { Id = L.ArrowPass, Volume = 3.5, Speed = { 1.05, 1.2 }, Length = 1 }, { Id = L.FeatherSwarm, Volume = 0.8, Speed = 1.3, Length = 0.6 } },
	FeatherMark = { Gap = 0.3, { Id = S.Ping, Volume = 0.25, Speed = 1.6 }, { Id = L.SwordTick, Volume = 0.2, Speed = 2, Length = 0.2 } },
	SwiftCutCoil = { Gap = 0.2, { Id = L.AscendWhoosh, Volume = 0.8, Speed = 1.2, Length = 0.4 }, { Id = L.SwordFoil, Volume = 0.4, Speed = 0.8, Length = 0.3 } },
	SwiftCutPass = { Gap = 0.1, Range = 420, { Id = L.SwordShing, Volume = 1.1, Speed = 0.95, Length = 0.7 }, { Id = L.ArrowHitHeavy, Volume = 0.9, Speed = 1.05, Length = 0.6 }, { Id = L.SubBoom, Volume = 0.5, Speed = 1.3, Length = 0.6 } },
	SwiftCutSkid = { Gap = 0.2, { Id = L.StoneGrind, Volume = 0.6, Speed = 1.3, Length = 0.45 }, { Id = L.FeatherRustle, Volume = 2.5, Speed = 1.1, Length = 0.4 } },
	BladeTwirl = { Gap = 0.2, { Id = L.SwordFoil, Volume = 0.5, Speed = 1.5, Length = 0.3 }, { Id = L.SwordTick, Volume = 0.25, Speed = 2.2, Length = 0.2 } },
	CycloneLaunch = { Range = 360, { Id = L.PigeonSurge, Volume = 5, Length = 1.4 }, { Id = L.FeatherSwarm, Volume = 1, Speed = 0.9 } },
	CycloneWhirr = { Gap = 0.05, { Id = L.SwordTick, Volume = 0.15, Speed = { 2.2, 2.8 }, Length = 0.15 } },
	CycloneGust = { Gap = 0.3, { Id = L.FlyGust, Volume = 0.8, Speed = { 0.9, 1.2 }, Length = 1.2 } },
	CarrySpin = { Gap = 0.2, Range = 300, { Id = L.GiantSwish, Volume = 0.9, Speed = 1.2 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1.2, Length = 0.5 } },
	CarryDive = { Gap = 0.2, Range = 360, { Id = L.WhooshSwishBy, Volume = 1, Speed = 0.8, Length = 0.5 }, { Id = L.ClothBloom, Volume = 1, Speed = 1.3, Length = 0.5 } },
	-- (round 92, hawksair) HIS FLYING MOVESET (VFX.HK's ON THE WING block), all
	-- on the kit's licensed takes: the strafe's stream and each feather going
	-- into the street; the stoop's tuck, its dive (the jet pass and the zoom)
	-- and the swoop back up; the gale's rear-up and its stroke (the dragon-sized
	-- beat on the huge wind blast); the drill forming (a rustle, a blade drawn,
	-- a vortex), launching, boring through, bursting. THE CARRY: the takeoff
	-- with them, the toss's yank, the flurry's stabs and its crossing cut, the
	-- throw's whirl and its release on a gust, the pins coming out
	StrafeRake = { Gap = 0.2, Range = 380, { Id = L.FeatherSwarm, Volume = 1.1, Speed = 1.15 }, { Id = L.JetPass, Volume = 0.5, Speed = 1.6, Length = 0.6 } },
	StrafeHit = { Gap = 0.04, Range = 200, { Id = L.ArrowHit, Volume = 0.6, Speed = { 1.1, 1.3 }, Length = 0.35 } },
	StoopCoil = { Gap = 0.2, Range = 260, { Id = L.WingFlapShort, Volume = 1.2, Speed = 1.3, Length = 0.4 }, { Id = L.FeatherRustle, Volume = 3, Speed = 1.1, Length = 0.4 } },
	StoopDive = { Gap = 0.2, Range = 420, { Id = L.JetPass, Volume = 1, Speed = 1.25 }, { Id = L.MagicZoom, Volume = 0.7, Speed = 1.1, Length = 0.8 } },
	StoopPullUp = { Gap = 0.2, Range = 320, { Id = L.WingFlapBig, Volume = 0.7, Speed = 1.15, Length = 0.7 }, { Id = L.WhooshSwishBy, Volume = 0.8, Speed = 0.9, Length = 0.5 } },
	GaleWindup = { Gap = 0.2, Range = 300, { Id = L.WingFlutter, Volume = 1.6, Speed = 0.9 }, { Id = L.AscendWhoosh, Volume = 0.8, Speed = 0.9, Length = 0.4 } },
	GaleBeat = { Gap = 0.2, Range = 600, { Id = L.WingFlapsDragon, Volume = 0.9, Speed = 1.1, Length = 1.2 }, { Id = L.WindBlast, Volume = 1, Length = 1.5, Fade = 0.6 },
		{ Id = L.FeatherRustle, Volume = 4, Length = 0.6 } },
	DrillForm = { Gap = 0.2, Range = 300, { Id = L.FeatherRustle, Volume = 4, Speed = 1.2, Length = 0.6 }, { Id = L.SwordDraw, Volume = 0.3, Speed = 1.8, Length = 0.3 },
		{ Id = L.VortexBlast, Volume = 0.4, Speed = 1.4, Length = 0.5 } },
	DrillLaunch = { Gap = 0.2, Range = 480, { Id = L.VortexBlast, Volume = 0.9, Speed = 1.1 }, { Id = L.FeatherSwarm, Volume = 1.2, Speed = 0.9 }, { Id = L.JetPass, Volume = 0.6, Speed = 1.5, Length = 0.8 } },
	DrillBore = { Gap = 0.08, Range = 320, { Id = L.StoneGrind, Volume = 0.8, Speed = 1.4, Length = 0.4 }, { Id = L.ArrowHitHeavy, Volume = 0.7, Length = 0.5 } },
	DrillBurst = { Gap = 0.2, Range = 480, { Id = L.WhooshExplosion, Volume = 0.8, Speed = 1.15 }, { Id = L.FeatherSwarm, Volume = 1.3, Speed = 0.8 }, { Id = L.DebrisImpact, Volume = 0.7, Length = 0.8 } },
	CarryTakeoff = { Gap = 0.2, Range = 420, { Id = L.WingFlapHuge, Volume = 0.5, Speed = 1.15, Length = 1 }, { Id = L.AscendWhoosh, Volume = 1 }, { Id = L.ClothBloom, Volume = 1, Length = 0.7 } },
	TossYank = { Gap = 0.2, Range = 360, { Id = L.AscendWhoosh, Volume = 1.1, Speed = 1.15 }, { Id = L.CapeSnap, Volume = 0.6, Speed = 1.1, Length = 0.5 } },
	FlurryStab = { Gap = 0.03, Range = 240, { Id = L.SwordStab, Volume = 0.6, Speed = { 1.15, 1.35 }, Length = 0.3 }, { Id = L.MeatyThud, Volume = 0.4, Speed = 1.3, Length = 0.25 } },
	FlurryCross = { Gap = 0.2, Range = 420, { Id = L.SwordShing, Volume = 1.1 }, { Id = L.CrackThud, Volume = 1.2 }, { Id = L.SubBoom, Volume = 0.5, Speed = 1.2, Length = 0.6 } },
	ThrowWhirl = { Gap = 0.2, Range = 320, { Id = L.GiantSwish, Volume = 1, Speed = 1.1 }, { Id = L.FlyGust, Volume = 0.9, Speed = 1.2, Length = 1 } },
	ThrowRelease = { Gap = 0.2, Range = 480, { Id = L.WindBlast, Volume = 0.9, Speed = 1.15, Length = 1.2 }, { Id = L.WhooshSwishBy, Volume = 1, Speed = 0.8, Length = 0.6 } },
	CarryLetGo = { Gap = 0.2, Range = 240, { Id = L.FeatherSwish, Volume = 0.6, Speed = 1.4, Length = 0.3 }, { Id = L.ClothBloom, Volume = 0.6, Speed = 1.4, Length = 0.5 } },
	FeathersBurned = { Gap = 0.15, { Id = L.FlameLick, Volume = 0.8, Length = 0.6 }, { Id = L.Sizzle, Volume = 0.7, Length = 0.6 } },
	FeathersPlucked = { { Id = L.SwishThin, Volume = 0.25, Speed = 0.6, Length = 0.3 }, { Id = L.WingFlutter, Volume = 1.2, Speed = 0.7 } },
	FeatherStorm = { Range = 1200, { Id = L.WindRoar, Volume = 1.4, Speed = 0.9, Length = 2.5 }, { Id = L.WhooshExplosion, Volume = 1.2 }, { Id = L.GiantSwish, Volume = 1 } },
	-- (round 86, hawks_ult) FULL PLUMAGE's awakening: the cocoon's flutter,
	-- then on the snap (0.28 s: MoveHawksAwaken's Hit) one giant beat, the
	-- blast of air and the feathers bursting off the edges
	UltFierceWings = {
		Range = 1400,
		{ Id = L.MagicFlutter, Volume = 1.3, Speed = 1.1, Length = 0.6, Fade = 0.2 },
		{ Id = S.Stinger, Volume = 0.9, Speed = 1.05, Delay = 0.26 },
		{ Id = L.WingFlapsDragon, Volume = 0.9, Speed = 1.08, Length = 1.4, Fade = 0.6, Delay = 0.26 },
		{ Id = L.WindBlast, Volume = 0.8, Length = 1.4, Fade = 0.6, Delay = 0.27 },
		{ Id = L.FeatherSwarm, Volume = 1.4, Speed = 0.9, Delay = 0.28 },
		{ Id = L.FeatherRustle, Volume = 4, Speed = 1.05, Length = 1, Delay = 0.28 },
	},
	-- (round 86, hawks_ult) THE THOUSAND-FEATHER STORM, beat by beat (VFX.HU):
	-- StormRiser builds from the plan to the break (its top on the break);
	-- StormLaunch: the downstroke that throws him 40 up; StormBreak: every
	-- feather off him at once; StormRoar: the storm itself (its first 2 s,
	-- fading) with StormBlades thwips and StormShred hits all through it;
	-- StormDive: the sweep into the last cut (its hit on the cut); StormCut;
	-- StormHome: the swell that's sucked out as the last feather lands, with
	-- a cascade of StormClick; StormFold: the double beat that folds them
	-- (round 86 review) the riser and the launch are cut off ~0.15 s before
	-- the break (it lands ~0.92 s in) and the music ducks under that gap
	-- (HU.stormStart): a breath of silence, so StormBreak hits
	StormRiser = { Range = 1000, { Id = L.StormRiser, Volume = 4, Length = 0.76, Fade = 0.06 }, { Id = L.WindRoar, Volume = 1, Speed = 1.1, FadeIn = 0.5, Length = 0.78, Fade = 0.08 } },
	StormLaunch = { Range = 700, { Id = L.WingFlapHuge, Volume = 0.6, Speed = 0.95, Length = 0.64, Fade = 0.25 }, { Id = L.DeepImpact7, Volume = 1, Length = 0.64, Fade = 0.2 }, { Id = L.SweepAperture, Volume = 0.9, Length = 0.64, Fade = 0.3 }, { Id = L.FeatherRustle, Volume = 4, Length = 0.6, Fade = 0.15 } },
	StormBreak = { Range = 1200, { Id = L.WhooshExplosion, Volume = 1.2 }, { Id = L.GiantSwish, Volume = 1 }, { Id = L.WingFlapsDragon, Volume = 0.8, Speed = 1.2, Length = 0.8 }, { Id = L.FeatherSwarm, Volume = 1.6, Speed = 0.85 }, { Id = L.SonicBoomAPM, Volume = 0.5, Length = 1.6, Fade = 1 } },
	StormRoar = { Range = 900, { Id = L.FlangeStorm, Volume = 1.6, Length = 2.1, Fade = 0.6 }, { Id = L.PigeonSurge, Volume = 5, Length = 2.1, Fade = 0.5 }, { Id = L.TearingAir, Volume = 1.8, Length = 2.1, Fade = 0.5 }, { Id = L.VortexBlast, Volume = 0.9 } },
	StormBlades = { Gap = 0.04, Range = 300, { Id = L.FeatherSwish, Volume = 0.55, Speed = { 1.5, 2.1 }, Length = 0.3 } },
	StormShred = { Gap = 0.05, Range = 300, { Id = L.ArrowHit, Volume = 0.7, Speed = { 1.1, 1.35 }, Length = 0.35 } },
	StormDive = { Range = 900, { Id = L.SweepHit, Volume = 1.3, Length = 1.1, Fade = 0.4 }, { Id = L.MagicZoom, Volume = 0.8, Length = 0.8, Fade = 0.3 }, { Id = L.SwordDraw, Volume = 0.5, Speed = 1.4, Length = 0.5 } },
	StormCut = {
		Range = 1200,
		{ Id = L.SwordShing, Volume = 1.2, Speed = 0.9, Length = 0.8 },
		{ Id = L.SwordWhip, Volume = 3, Speed = 0.85, Length = 0.7 },
		{ Id = L.DeepBlast, Volume = 1, Length = 1.2, Fade = 0.5 },
		{ Id = L.SonicCrack, Volume = 0.8, Length = 1.5, Fade = 0.8 },
		{ Id = L.BladeRing, Volume = 0.5, Speed = 0.95, Length = 1.4, Fade = 0.8, Delay = 0.05 },
		{ Id = L.ArrowThunk, Volume = 0.6, Speed = 0.9, Length = 0.6 },
	},
	StormHome = { Range = 900, { Id = L.TuttiSuck, Volume = 1.1, Length = 1.0, Fade = 0.1 }, { Id = L.SubSuck, Volume = 0.9, Length = 1.0, Fade = 0.15 }, { Id = L.FeatherRustle, Volume = 3.5, FadeIn = 0.4, Length = 0.9, Fade = 0.2 } },
	StormClick = { Gap = 0.015, Range = 220, { Id = L.SwordTick, Volume = 0.22, Speed = { 2.4, 3 }, Length = 0.16 } },
	StormFold = { Range = 400, { Id = L.WingFlapBig, Volume = 0.6, Speed = 1.15, Length = 0.6 }, { Id = L.WingFlapBig, Volume = 0.5, Speed = 1.25, Length = 0.6, Delay = 0.2 }, { Id = L.FeatherRustle, Volume = 3, Length = 0.6, Delay = 0.2 } },
	-- (round 86, hawks_ult) SCARLET RAIN (the feathers up, a zip on the way
	-- down, the thunk into the street), TOO FAST (each cut; all of them
	-- opening at once) and TEMPEST's roar on top of the cyclone's bed
	RainCall = { Range = 500, { Id = L.FeatherSwarm, Volume = 1.4, Speed = 1.1 }, { Id = L.WingFlapShort, Volume = 1.3, Speed = 1.2, Length = 0.45 }, { Id = L.AscendWhoosh, Volume = 0.9, Length = 0.8 } },
	RainFall = { Gap = 0.06, Range = 300, { Id = L.ArrowPass, Volume = 4, Speed = { 1.1, 1.3 }, Length = 0.7, Fade = 0.2 } },
	RainHit = { Gap = 0.04, Range = 260, { Id = L.ArrowHit, Volume = 0.8, Speed = { 1, 1.2 }, Length = 0.4 } },
	TooFastCut = { Gap = 0.08, Range = 420, { Id = L.SwordShing, Volume = 0.9, Speed = { 1.05, 1.2 }, Length = 0.5 }, { Id = L.SwordFoil, Volume = 0.9, Speed = 1.15, Length = 0.4 }, { Id = L.MagicZoom, Volume = 0.5, Speed = 1.3, Length = 0.5, Fade = 0.2 } },
	TooFastOpen = { Range = 520, { Id = L.BladeRing, Volume = 0.6, Speed = 1.1, Length = 1, Fade = 0.5 }, { Id = L.ArrowThunk, Volume = 0.6, Length = 0.5 }, { Id = L.SwordShing, Volume = 0.9, Speed = 0.8, Length = 0.6 } },
	TempestRoar = { Range = 520, { Id = L.FlangeStorm, Volume = 1.2, Length = 3, Fade = 0.8 }, { Id = L.HowlingWind, Volume = 0.9, Length = 3, Fade = 0.8 } },
	-- BLOOD: a wet spurt on the hardest hits
	BloodSpray = { Gap = 0.05, { Id = L.BloodSpurt, Volume = 0.7, Speed = { 0.9, 1.15 }, Length = 0.6 } },
	DekuLaunch = {
		Range = 2400,
		{ Id = L.PowerBoom, Volume = 2.5, Speed = 0.9, Length = 2.5 },
		{ Id = L.DirtBurst, Volume = 2, Length = 2 },
		{ Id = L.AscendWhoosh, Volume = 2, Speed = 0.8, Length = 2 },
		{ Id = L.WhooshExplosion, Volume = 1.6, Length = 1 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.7 },
	},
	DetroitImpact = {
		Range = 900,
		{ Id = L.CrackyPunch, Volume = 1.2, Speed = 0.8, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 1.1, Speed = 0.9 },
		{ Id = L.WindBlast, Volume = 0.9, Length = 1.6 },
		{ Id = L.VortexBlast, Volume = 0.7, Speed = 0.8, Delay = 0.05, Length = 1.5 },
	},
	IceWallRise = {
		Range = 900,
		{ Id = L.IceHammer, Volume = 3.74, Speed = 0.7 },
		{ Id = L.IceCrunch, Volume = 3.37, Speed = 0.8, Length = 1.6 },
		{ Id = L.RockCrack, Volume = 2.99, Speed = 1.1, Length = 1.6 },
		{ Id = L.GlassSmash, Volume = 1.87, Speed = 0.7, Length = 1 },
	},
	-- (round 81) HEAVEN-PIERCING ICE WALL, a beat at a time (IceWallRise
	-- stays for Glacier Breaker's pillar): the cold drawn in as the knee comes
	-- up; the stomp (a low thump under the ice); the run tearing up the
	-- street every 40 studs; the crest erupting (the biggest: a boulder crack,
	-- the ice hammered, a boom that rolls on, the wind it shoves); the tip
	-- punching the clouds (thunder, high up); the ice groaning while it
	-- stands (a wood creak pitched down); and the end - it cracks, then melts
	-- away with a long hiss of wind
	IceWallGather = {
		Range = 300,
		{ Id = L.SuckShort, Volume = 1.2, Speed = 0.8 },
		{ Id = L.HowlingWind, Volume = 0.6, Speed = 1.2, Length = 0.8 },
	},
	IceWallStomp = {
		Range = 600,
		{ Id = L.BodySlamThump, Volume = 2, Speed = 0.8 },
		{ Id = L.IceHammer, Volume = 3, Speed = 0.6 },
		{ Id = L.SubBoom, Volume = 1.6, Speed = 0.7 },
		{ Id = L.GlassSmash, Volume = 1.2, Speed = 1.1, Length = 0.5 },
	},
	IceWallRun = {
		Range = 500,
		Gap = 0.1,
		{ Id = L.IceCrunch, Volume = 2.6, Speed = { 0.75, 0.9 }, Length = 1 },
		{ Id = L.RockCrack, Volume = 2, Speed = { 0.9, 1.1 }, Length = 0.8 },
		{ Id = L.Quake, Volume = 1.4, Speed = 0.8, Length = 1.2 },
	},
	IceWallCrest = {
		Range = 1400,
		{ Id = L.BoulderCrack, Volume = 2.5, Speed = 0.7 },
		{ Id = L.IceHammer, Volume = 3.5, Speed = 0.5 },
		{ Id = L.BigBoomTail, Volume = 2, Speed = 0.8 },
		{ Id = L.WindRoar, Volume = 1.4, Speed = 0.9, Length = 2, Fade = 0.8 },
		{ Id = L.GlassBreak, Volume = 1.8, Speed = 0.7, Delay = 0.08 },
	},
	IceWallPeak = {
		Range = 1600,
		{ Id = L.ThunderBlast, Volume = 1.2, Speed = 1.3 },
		{ Id = L.WindRoar, Volume = 1, Speed = 1.1, Length = 2, Fade = 0.8 },
		{ Id = L.GlassSmash, Volume = 1.2, Speed = 0.6 },
	},
	IceWallCreak = {
		Range = 400,
		{ Id = L.WoodCreak, Volume = 1.2, Speed = { 0.4, 0.5 } },
		{ Id = L.IceCrunch, Volume = 0.8, Speed = 1.3, Length = 0.4 },
	},
	IceWallCrack = {
		Range = 900,
		Gap = 0.06,
		{ Id = L.GlassBreak, Volume = 2.7, Speed = { 0.7, 0.9 } },
		{ Id = L.BoulderCrack, Volume = 2, Speed = 0.6 },
	},
	IceWallMelt = {
		Range = 900,
		{ Id = L.FireWhoosh, Volume = 1.2, Speed = 0.5, Length = 2 },
		{ Id = L.FlameLick, Volume = 1, Speed = 0.6 },
		{ Id = L.HowlingWind, Volume = 0.8, Speed = 0.7, Length = 2.5, Fade = 1 },
	},
	ReciproRev ={ { Id = L.MotorRev, Volume = 1.6, Speed = 1.35, Length = 0.6 }, { Id = S.Roar, Volume = 0.89, Speed = 1.6, Length = 0.5 } },
	-- (round 85) Recipro Burst's rev a gear up, and up again: the pitch climbing
	-- to a scream at gear 3
	ReciproRev2 = { { Id = L.MotorRev, Volume = 1.6, Speed = 1.55, Length = 0.55 }, { Id = S.Roar, Volume = 0.9, Speed = 1.8, Length = 0.45 } },
	ReciproRev3 = {
		{ Id = L.MotorRev, Volume = 1.7, Speed = 1.8, Length = 0.5 },
		{ Id = S.Roar, Volume = 0.95, Speed = 2.05, Length = 0.45 },
		{ Id = L.Accelerate, Volume = 0.8, Speed = 1.6, Length = 0.5, Fade = 0.25 },
	},
	ReciproBoom = {
		Range = 700,
		{ Id = L.JetPass, Volume = 1.36, Speed = 1.3, Length = 1 },
		{ Id = L.WhooshExplosion, Volume = 1.02, Speed = 1.2, Length = 0.8 },
		{ Id = L.CrackyPunch, Volume = 1.7, Speed = 0.9, Length = 0.4 },
	},
	-- (round 85) gear 3's last strike breaking the sound barrier: the crack,
	-- the low-end thump of the pressure wave
	ReciproBarrier = {
		Range = 800, Gap = 0.1,
		{ Id = L.SonicCrack, Volume = 1.4, Speed = 1, Length = 1 },
		{ Id = L.SonicPressure, Volume = 1.2, Speed = 0.95, Length = 1.1 },
		{ Id = L.BoomThump, Volume = 0.9, Speed = 0.9, Length = 0.6 },
	},
	-- (round 85) Recipro Extend's frost cracking off his calves in a burst of steam
	ExtendFrost = {
		{ Id = L.IceCrunch, Volume = 1.2, Speed = { 1, 1.15 }, Length = 0.4 },
		{ Id = L.IceSizzle, Volume = 0.9, Speed = 1.2, Length = 0.5 },
		{ Id = L.SteamBurst, Volume = 1, Speed = { 1.1, 1.25 }, Length = 0.8, Fade = 0.4, Delay = 0.03 },
	},
	-- forms + awakenings
	-- MUSCLE FORM: the pressure building (a deep rumble, a growl), then the
	-- heartbeat before he bursts out
	MuscleRumble = { Range = 300, { Id = L.Quake, Volume = 1.4, Speed = 0.6, Length = 1 }, { Id = L.EnergyGrowl, Volume = 1.3, Speed = 0.55, Length = 0.9 } },
	MuscleThump = { Range = 400, { Id = L.BoomThump, Volume = 2.2, Speed = 0.6 }, { Id = L.SubBoom, Volume = 1.4, Speed = 0.6 } },
	-- "I AM HERE!": the street goes wild as he bursts out
	IAmHere = {
		Range = 400,
		{ Id = L.CrowdRoar, Volume = 1.3, Length = 3.2, Delay = 0.15 },
		{ Id = L.CrowdWhoops, Volume = 0.9, Length = 2.5, Delay = 0.35 },
	},
	Transform = {
		{ Id = L.PowerUp, Volume = 1.43, Speed = 0.8 },
		{ Id = L.EnergyGrowl, Volume = 1.14, Speed = 0.8, Length = 1.2 },
		{ Id = L.SubBoom, Volume = 1.29, Speed = 0.8 },
		{ Id = L.Static, Volume = 0.71, Delay = 0.1 },
	},
	SideSwap = { { Id = L.IceCrunch, Volume = 1.33, Speed = 1.3, Length = 0.4 }, { Id = L.FlameLick, Volume = 1.6, Speed = 1.2, Length = 0.5 } },
	Ult = { Range = 1200, { Id = L.PowerUp, Volume = 1, Speed = 0.75 }, { Id = S.Thunder, Volume = 0.8, Start = 1.0, Length = 2.2 }, { Id = L.SubBoom, Volume = 1, Speed = 0.7 } },
	UltExplosion = { Range = 1200, { Id = S.Beast, Volume = 1.38, Start = 0.25 }, { Id = L.PowerBoom, Volume = 1.15, Speed = 0.9 }, { Id = L.ExplosionCrack, Volume = 0.92, Speed = 0.9, Length = 2 } },
	UltOneForAll = {
		Range = 1200,
		{ Id = S.Beast, Volume = 1.5, Start = 0.25, Speed = 0.9 },
		{ Id = L.Zap, Volume = 1.04, Speed = 0.8 },
		{ Id = L.PowerUp, Volume = 1.16, Speed = 0.7 },
		{ Id = L.SubBoom, Volume = 1.27, Speed = 0.6 },
	},
	UltHalfCold = { Range = 1200, { Id = L.IceHammer, Volume = 1.99, Speed = 0.6 }, { Id = L.FireBurst, Volume = 1.59, Speed = 0.9, Length = 2 }, { Id = L.RockCrack, Volume = 1.59, Length = 1.8 } },
	-- (round 81) ORIGIN: HALF-COLD HALF-HOT (Todoroki's ult R), beat by beat.
	-- The stamp, and the glacier wave racing down the street
	OriginWave = {
		Range = 900,
		{ Id = L.IceHammer, Volume = 1.6, Speed = 0.9 },
		{ Id = L.IceCrunch, Volume = 2, Speed = { 0.9, 1.05 }, Length = 0.9, Fade = 0.4 },
		{ Id = L.RockCrack, Volume = 1.2, Speed = 1.1, Length = 0.8, Fade = 0.3, Delay = 0.08 },
		{ Id = L.GlassDebris, Volume = 0.7, Speed = 1.2, Length = 0.6, Fade = 0.2, Delay = 0.15 },
	},
	-- nobody caught: the ridge dies away, and a breath out
	OriginWhiff = { { Id = L.IceCrunch, Volume = 1.2, Speed = 0.8, Length = 0.6, Fade = 0.3 }, { Id = L.WhooshBurst, Volume = 0.3, Speed = 0.7, Length = 0.6, Fade = 0.3 } },
	-- caught: the cage snaps shut round them
	OriginCatch = {
		Range = 900,
		{ Id = L.IceHammer, Volume = 2, Speed = 0.75 },
		{ Id = L.GlassSmash, Volume = 0.9, Speed = 0.9, Length = 0.8, Fade = 0.3 },
		{ Id = L.IceCrunch, Volume = 1.6, Speed = 0.8, Length = 0.7, Fade = 0.3 },
	},
	-- the cold: the wind howling, the frost creeping, two slow heartbeats
	OriginFrost = {
		Range = 600,
		{ Id = L.HowlingWind, Volume = 0.6, Speed = 0.9, Length = 1, Fade = 0.5 },
		{ Id = L.IceCrunch, Volume = 0.9, Speed = 1.25, Length = 0.5, Fade = 0.2, Delay = 0.1 },
		{ Id = L.BoomThump, Volume = 0.9, Speed = 0.8, Length = 0.5, Fade = 0.2, Delay = 0.05 },
		{ Id = L.BoomThump, Volume = 0.7, Speed = 0.8, Length = 0.5, Fade = 0.2, Delay = 0.55 },
	},
	-- (round 82) the two hands: his left hand and the left of his hair go up
	-- (a fwoom) as the frost wall surges up off his right side
	OriginHands = {
		Range = 900,
		{ Id = L.FireWhoosh, Volume = 1.4, Speed = 1.1, Length = 0.9, Fade = 0.4 },
		{ Id = L.FlameLick, Volume = 1.1, Length = 0.8, Fade = 0.3 },
		{ Id = L.IceCrunch, Volume = 1.1, Speed = 0.7, Length = 0.8, Fade = 0.4, Delay = 0.04 },
		{ Id = L.HowlingWind, Volume = 0.5, Speed = 1.2, Length = 0.8, Fade = 0.4 },
	},
	-- (round 82) ...and the screen goes black and white (a deep hit under it)
	OriginFlare = {
		Range = 600,
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.9, Length = 1.2, Fade = 0.6 },
		{ Id = L.WhooshBurst, Volume = 0.6, Speed = 0.6, Length = 0.6, Fade = 0.3 },
	},
	-- IGNITION: his left side goes up (the frost on the right flashes to steam)
	OriginIgnite = {
		Range = 1200,
		{ Id = L.FireBurst, Volume = 1.8, Speed = 0.7 },
		{ Id = L.FireWhoosh, Volume = 1.6, Speed = 0.8, Length = 2.5, Fade = 1 },
		{ Id = L.PowerBoom, Volume = 1, Speed = 0.7, Length = 1.6, Fade = 0.8 },
		{ Id = L.EnergyGrowl, Volume = 0.8, Speed = 0.7, Length = 1.2, Fade = 0.6 },
		{ Id = L.Sizzle, Volume = 1, Speed = 0.9, Length = 1.2, Fade = 0.6, Delay = 0.1 },
	},
	-- the ice field erupts round them and the ring of fire races through it
	OriginField = {
		Range = 1200,
		{ Id = L.IceHammer, Volume = 1.8, Speed = 0.7 },
		{ Id = L.RockCrack, Volume = 1.3, Speed = 0.8, Length = 1, Fade = 0.4 },
		{ Id = L.FireWhoosh, Volume = 1.6, Speed = 0.65, Length = 1.6, Fade = 0.8, Delay = 0.05 },
		{ Id = L.IceSizzle, Volume = 1.2, Length = 1.4, Fade = 0.8, Delay = 0.25 },
	},
	-- the heat gathering in the left palm (the suck-in swells into the thrust)
	OriginCharge = {
		Range = 600,
		{ Id = L.SuckIn, Volume = 0.9, Length = 1, Fade = 0.1 },
		{ Id = L.FireballSizzle, Volume = 0.9, Length = 1, Fade = 0.4 },
		{ Id = L.FlameLick, Volume = 1.2, Speed = 0.9, Length = 1, Fade = 0.4 },
	},
	-- "Thanks." - the palm thrust
	OriginThrust = { Range = 1200, { Id = L.FireWhoosh, Volume = 1.8, Speed = 0.8, Length = 0.8, Fade = 0.3 }, { Id = L.WhooshBurst, Volume = 0.8, Speed = 0.8, Length = 0.6, Fade = 0.3 } },
	-- the expansion: the fire meets the frozen air (heard across the district)
	OriginBlast = {
		Range = 4000,
		{ Id = L.PowerBoomLong, Volume = 1.6, Speed = 0.75, Length = 4, Fade = 2.4 },
		{ Id = L.DeepBlast, Volume = 1.2, Length = 3, Fade = 1.6 },
		{ Id = L.SubBoom, Volume = 1.5, Speed = 0.55 },
		{ Id = L.IceHammer, Volume = 1.6, Speed = 0.6 },
		{ Id = L.GlassSmash, Volume = 1.2, Speed = 0.8, Length = 1.5, Fade = 0.8 },
		{ Id = L.WindBlast, Volume = 1, Length = 2.6, Fade = 1.4, Delay = 0.05 },
		{ Id = L.Quake, Volume = 0.8, Length = 2.6, Fade = 1.6, Delay = 0.3 },
	},
	-- the steam rolling over everything, then hissing away
	OriginSteam = {
		Range = 1200,
		{ Id = L.SteamBurst, Volume = 1.4, Speed = 0.8, Length = 4, Fade = 2 },
		{ Id = L.SteamTube, Volume = 0.8, Speed = 0.7, Length = 4, Fade = 2, Delay = 0.3 },
		{ Id = L.WindRoar, Volume = 0.8, Speed = 0.7, Length = 3.4, Fade = 2 },
	},
	UltEngine = { Range = 1200, { Id = L.MotorRev, Volume = 1.78, Speed = 1.1, Length = 1.4 }, { Id = L.JetPass, Volume = 1.42, Speed = 0.9, Length = 2 }, { Id = S.Roar, Volume = 1.07, Speed = 1.4, Length = 1.4 } },
	-- (round 85) RECIPRO TURBO's own (VFX.IidaTurbo). The awakening: his old
	-- mufflers wrenched out (a metal scrape, a clang, a crack), the long
	-- tubes sliding in hot, heating up (a sizzle under a rising whine), the
	-- eruption (a blast, the jet, rocks, a sonic crack); at the end of the
	-- ult they slide back in (a clunk and a hiss)
	TurboTear = {
		{ Id = L.BladeScrape, Volume = 1.2, Speed = 0.7, Length = 0.35 },
		{ Id = L.SwordClash, Volume = 0.8, Speed = 0.55, Length = 0.45 },
		{ Id = L.WoodCrack, Volume = 0.7, Speed = 0.8, Length = 0.3 },
	},
	TurboGrow = {
		{ Id = L.MetalSwoosh, Volume = 1, Speed = { 0.75, 0.85 }, Length = 0.5 },
		{ Id = L.Sizzle, Volume = 0.6, Speed = 1.1, Length = 0.4, Delay = 0.08 },
	},
	TurboHeat = {
		{ Id = L.FireballSizzle, Volume = 0.8, Speed = 1.2, Length = 0.6, Fade = 0.2 },
		{ Id = L.PowerUp, Volume = 0.9, Speed = 1.15, Length = 0.6, Fade = 0.2 },
	},
	TurboErupt = {
		Range = 900,
		{ Id = L.WhooshExplosion, Volume = 1.6, Speed = 1, Length = 1.2 },
		{ Id = L.JetPass, Volume = 1.4, Speed = 1.3, Length = 1.1, Fade = 0.4 },
		{ Id = L.RockBurst, Volume = 1, Speed = 0.9, Length = 0.8 },
		{ Id = L.SonicCrack, Volume = 1, Speed = 1.1, Length = 0.6 },
	},
	TurboRetract = {
		{ Id = L.WoodClunk, Volume = 1.1, Speed = 0.5, Length = 0.35 },
		{ Id = L.SteamTube, Volume = 0.8, Speed = 1.3, Length = 0.6, Fade = 0.3 },
	},
	-- TURBO KICK's blink (a crack and a thin whoosh) and TURBO RUSH's legs
	-- (a whoosh by each) and its finisher (the pressure and the blast)
	TurboBlink = {
		{ Id = L.SonicCrack, Volume = 1, Speed = 1.3, Length = 0.45 },
		{ Id = L.SwishThin, Volume = 1.2, Speed = 1.4, Length = 0.3 },
	},
	TurboBar = { Gap = 0.05, { Id = L.WhooshSwishBy, Volume = 0.9, Speed = { 1.4, 1.6 }, Length = 0.3 } },
	TurboFlash = {
		Range = 700,
		{ Id = L.SonicPressure, Volume = 1.3, Speed = 1, Length = 0.8 },
		{ Id = L.WhooshExplosion, Volume = 1, Speed = 1.25, Length = 0.7 },
	},
	-- MAXIMUM BURST: the charge (the rev climbing to a scream), the go (a
	-- sonic crack, the jet, the boom), the windows going as he passes, the
	-- hit, and his mufflers blowing at the end of it (a pop-bang and the
	-- engines choking)
	MaxCharge = {
		Range = 900,
		{ Id = L.MotorRev, Volume = 1.7, Speed = 1, Length = 0.65 },
		{ Id = L.Accelerate, Volume = 1.3, Speed = 1.35, Length = 0.6, Delay = 0.12 },
		{ Id = L.HowlingWind, Volume = 0.7, Speed = 1.6, Length = 0.5, Delay = 0.25 },
	},
	MaxGo = {
		Range = 1200,
		{ Id = L.SonicCrack, Volume = 1.6, Speed = 0.9, Length = 0.7 },
		{ Id = L.JetPass, Volume = 1.6, Speed = 1.1, Length = 1.2, Fade = 0.5 },
		{ Id = L.SubBoom, Volume = 1.3, Speed = 0.9 },
	},
	MaxGlass = { Gap = 0.1, Range = 500, { Id = L.GlassSmash, Volume = 0.8, Speed = { 1, 1.2 }, Length = 0.6 } },
	MaxImpact = {
		Range = 1200,
		{ Id = L.DeepImpact, Volume = 1.4, Speed = 1, Length = 1.6, Fade = 0.6 },
		{ Id = L.SonicPressure, Volume = 1.3, Speed = 0.85, Length = 0.9 },
		{ Id = L.CrackThud, Volume = 1.6, Speed = 0.8, Length = 0.6 },
	},
	MufflerBlow = {
		Range = 700,
		{ Id = L.ExplosionCrack, Volume = 1.3, Speed = 1.05, Length = 0.45 },
		{ Id = L.CanPop, Volume = 1.4, Speed = 0.5, Length = 0.35 },
		{ Id = L.MotorRev, Volume = 1.1, Speed = 0.5, Length = 0.3, Delay = 0.18 },
	},
	-- DECAY: everything he touches cracks, crumbles and pours away as dust
	Crumble = {
		Gap = 0.05,
		{ Id = L.BoulderCrack, Volume = 1.65, Speed = { 0.85, 1.05 }, Length = 1 },
		{ Id = L.DirtBurst, Volume = 1.92, Speed = { 0.9, 1.1 }, Length = 1 },
	},
	-- (round 83) a body crusting over in stone (the Decaying status): a dry
	-- crackle and a trickle of grit
	DecayCrust = {
		Gap = 0.3,
		{ Id = L.EarthCrack, Volume = 1.3, Speed = { 1.2, 1.4 }, Length = 0.8 },
		{ Id = L.DirtBurst, Volume = 0.9, Speed = 1.3, Length = 0.6 },
	},
	-- (round 83) a body gone to ash: it slumps and pours into a heap
	DecayAsh = {
		{ Id = L.DirtBurst, Volume = 1.8, Speed = 0.8, Length = 1.4 },
		{ Id = L.DebrisMove, Volume = 1.3, Speed = 0.9, Length = 1.2 },
		{ Id = L.BoulderCrack, Volume = 1.1, Speed = 0.7, Length = 0.8 },
	},
	-- (round 88) COSMETICS B (Config.CosmeticsB), all ids the game already
	-- plays, kept quiet and close (they ride on the moves' own sounds):
	-- the hand on Shigaraki's face clenching - a dry knuckle crack and grit
	DecayKnuckles = {
		Range = 120,
		{ Id = L.RockCrack, Volume = 0.7, Speed = { 1.8, 2.1 }, Length = 0.25 },
		{ Id = L.DirtBurst, Volume = 0.45, Speed = 1.6, Length = 0.45, Fade = 0.25 },
	},
	-- Gojo's Six Eyes opening: a bright metallic ring and a high ping
	SixEyesGlint = {
		Range = 160,
		{ Id = L.BladeRing, Volume = 0.9, Speed = 1.35, Length = 1, Fade = 0.5 },
		{ Id = S.Ping, Volume = 0.35, Speed = 1.7 },
	},
	-- Todoroki's shoulder crusting over (a small crackle of ice), the frost
	-- seared off it by his fire, and his left side steaming
	ShotoFrostCreep = { Range = 120, { Id = L.IceFreezeCrackle, Volume = 0.8, Speed = { 1.4, 1.6 }, Length = 0.6, Fade = 0.3 } },
	ShotoFrostMelt = { Range = 120, { Id = L.SteamSear, Volume = 1, Speed = { 1.1, 1.25 }, Length = 0.7, Fade = 0.35 } },
	ShotoSteam = { Range = 100, { Id = L.AirRelease, Volume = 0.45, Speed = { 1.15, 1.3 }, Length = 1.1, Fade = 0.6 } },
	DecayWave = {
		Range = 700,
		{ Id = L.RockCrack, Volume = 1.91, Speed = 1.1, Length = 1.4 },
		{ Id = L.DebrisMove, Volume = 1.48, Length = 1.4 },
		{ Id = L.Quake, Volume = 1.7, Length = 1.6 },
		{ Id = L.SubBoom, Volume = 1.48, Speed = 0.8 },
	},
	DecayGrasp = { { Id = L.CrackyPunch, Volume = 2.69, Speed = 0.7, Length = 0.4 }, { Id = L.BoulderCrack, Volume = 1.89, Speed = 0.9, Length = 0.8 }, { Id = L.DirtBurst, Volume = 1.62, Length = 0.9 } },
	Collapse = {
		Range = 1000,
		{ Id = L.Quake, Volume = 1.85, Length = 3 },
		{ Id = L.RockBurst, Volume = 1.67, Length = 2.6 },
		{ Id = L.SubBoom, Volume = 1.85, Speed = 0.6 },
		{ Id = L.BoulderCrack, Volume = 1.3, Speed = 0.8, Length = 1.5 },
	},
	TotalDecay = {
		Range = 1600,
		{ Id = S.Beast, Volume = 2.31, Start = 0.25, Speed = 0.8 },
		{ Id = L.Quake, Volume = 2.1, Speed = 0.8, Length = 4 },
		{ Id = L.RockBurst, Volume = 2.1, Speed = 0.8, Length = 4 },
		{ Id = L.BoomThump, Volume = 2.1, Speed = 0.7 },
		{ Id = L.DebrisMove, Volume = 1.68, Speed = 0.8, Delay = 0.4, Length = 3 },
	},
	Rivet = {
		Gap = 0.04,
		{ Id = S.Ring, Volume = 1.34, Speed = { 1.8, 2 } },
		{ Id = L.MetalSwoosh, Volume = 1.79, Speed = { 1, 1.15 }, Length = 0.6 },
		{ Id = L.AirySlice, Volume = 2.01, Speed = 1.3 },
	},
	-- (round 84) the rivets yanked back into his fingers with someone on them
	RivetReel = { Range = 400, { Id = L.WhooshSwishBy, Volume = 1.5, Speed = 0.8 }, { Id = L.MetalSwoosh, Volume = 1.1, Speed = 0.7, Length = 0.5 } },
	-- (round 84) the static crackling on someone Radio Waves jammed
	RadioJam = { Range = 250, { Id = L.Static, Volume = 0.9, Speed = 1.25, Length = 0.9 }, { Id = L.QuirkCrackle, Volume = 0.6, Speed = 1.1, Length = 0.4 } },
	-- Radio Waves: a crackle of static building in his arms, then the pulse -
	-- an electric snap, a deep thrum rolling out, and the hiss of jammed air
	RadioCharge = { Range = 500, { Id = L.Static, Volume = 1.6, Speed = 0.8, Length = 0.6 }, { Id = L.QuirkCrackle, Volume = 1.2, Speed = 0.7, Length = 0.5 } },
	RadioWaves = {
		Range = 900,
		{ Id = L.EnergySnap, Volume = 1.6, Speed = 0.7, Length = 0.6 },
		{ Id = L.DeepBlast, Volume = 1.4, Speed = 1.3, Length = 1.6 },
		{ Id = L.Static, Volume = 1.4, Speed = 1.1, Delay = 0.1, Length = 1.4 },
		{ Id = L.Zap, Volume = 1, Speed = 0.8, Delay = 0.05, Length = 0.8 },
	},
	UltDecay = { Range = 1200, { Id = S.Beast, Volume = 3.3, Start = 0.25, Speed = 0.75 }, { Id = L.Quake, Volume = 2.48, Speed = 0.8, Length = 2.5 }, { Id = L.BoulderCrack, Volume = 1.93, Speed = 0.7, Length = 1.5 } },
	-- ALL MIGHT (Plus Ultra)
	-- Full Cowl crackle around a charging fist
	Spark = { Gap = 0.06, { Id = L.Static, Volume = 2.33, Speed = { 0.9, 1.2 } } },
	-- United States of Smash: everything One For All has left, sucked into one fist...
	USSCharge = {
		Range = 1200,
		{ Id = L.PowerUp, Volume = 2.03, Speed = 0.8 },
		{ Id = L.EnergyGrowl, Volume = 1.42, Speed = 0.7, Length = 1 },
		{ Id = L.SuckIn, Volume = 3.66, Length = 1.05 },
		{ Id = L.Zap, Volume = 1.22, Speed = 0.8, Delay = 0.3 },
	},
	-- ...and released into the ground
	USSImpact = {
		Range = 2000,
		{ Id = L.CrackyPunch, Volume = 1.4, Speed = 0.6, Length = 0.6 },
		{ Id = L.PowerBoomLong, Volume = 1.2, Speed = 0.8, Length = 4 },
		{ Id = L.WindBlast, Volume = 1.2, Speed = 0.85, Length = 2.5 },
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.7 },
		{ Id = L.BoomThump, Volume = 1, Speed = 0.8 },
		{ Id = L.Quake, Volume = 0.8, Delay = 0.2, Length = 3 },
	},
	-- (round 77) ALL MIGHT'S OWN PUNCHES (the shared cues above stay for
	-- Deku and the rest). Built the way his hits are in the anime, front to
	-- back: the crack (a touch of distortion for grit), a body-deep thump
	-- (the equaliser pushes its lows: Eq = { low, mid, high } in dB), the air
	-- bursting out, then the boom and the wind rolling away. Peak = true: the
	-- layer starts just before its loudest moment, so every layer's hit lands
	-- together on the punch.
	-- his M1s and light hits
	MightHit = {
		Gap = 0.03,
		{ Id = L.BeefyHit, Volume = 0.8, Speed = { 0.85, 0.95 }, Length = 0.4 },
		{ Id = L.CrackyPunch, Volume = 1.1, Speed = { 0.85, 0.95 }, Length = 0.35 },
		{ Id = L.BodySlamThump, Volume = 0.9, Speed = { 0.95, 1.05 }, Length = 0.5, Peak = true, Eq = { 4, 0, -2 } },
		{ Id = L.AirPound, Volume = 0.45, Speed = { 1.2, 1.35 }, Length = 0.45, Peak = true },
	},
	-- his heavy hits (15+ damage, or marked heavy)
	MightHeavyHit = {
		Gap = 0.04,
		{ Id = L.CrackThud, Volume = 2, Speed = { 0.8, 0.9 }, Length = 0.6 },
		{ Id = L.BodySlamThump, Volume = 1.3, Speed = 0.9, Length = 0.7, Peak = true, Eq = { 5, 0, -3 } },
		{ Id = L.AirPound, Volume = 1, Speed = { 0.9, 1 }, Length = 0.9, Peak = true },
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.9, Length = 1 },
	},
	-- the smashes: Texas Smash 100%, Carolina, Oklahoma, New Hampshire, the rush
	MightSmash = {
		Range = 800,
		{ Id = L.CrackyPunch, Volume = 1.5, Speed = 0.75, Length = 0.5, Distort = 0.2 },
		{ Id = L.BodySlamThump, Volume = 1.3, Speed = 0.88, Length = 0.8, Peak = true, Eq = { 5, 0, -3 } },
		{ Id = L.AirPound, Volume = 1.2, Speed = { 0.9, 1 }, Length = 1.1, Peak = true },
		{ Id = L.SubBoom, Volume = 1.3, Speed = { 0.85, 0.95 } },
		{ Id = L.SonicCrack, Volume = 0.8, Speed = { 1, 1.1 }, Length = 1.4, Peak = true, Delay = 0.03 },
		{ Id = L.BoulderCrack, Volume = 0.6, Speed = { 0.85, 1 }, Length = 1.1, Delay = 0.06 },
	},
	-- DETROIT SMASH (and the Hero's Counter, the Backdrop Driver's slam,
	-- Weather Changer, the USJ finish): the weather changes
	MightImpact = {
		Range = 1000,
		{ Id = L.CrackyPunch, Volume = 1.4, Speed = 0.7, Length = 0.5, Distort = 0.25 },
		{ Id = L.BodySlamThump, Volume = 1.5, Speed = 0.8, Length = 0.9, Peak = true, Eq = { 6, 0, -4 } },
		{ Id = L.AirPound, Volume = 1.5, Speed = 0.85, Length = 1.4, Peak = true },
		{ Id = L.ThunderBlast, Volume = 1.2, Speed = { 0.95, 1.05 }, Length = 2.6, Peak = true, PreRoll = 0.04, Delay = 0.02 },
		{ Id = L.SonicPressure, Volume = 1.1, Length = 2.4, Peak = true, Delay = 0.05 },
		{ Id = L.WindBlast, Volume = 0.8, Length = 1.6, Delay = 0.08 },
	},
	-- UNITED STATES OF SMASH (and the I AM HERE meteor's landing). (round
	-- 78) A bit quieter, and the long tails fade out (Fade: seconds of fade
	-- before Length) instead of stopping - the ult music dips under the
	-- punch and comes back up through them. (round 81) The tails carry
	-- (Near: full volume out to 60 studs): the twister's crane shot watches
	-- from 60-110 studs off, where they'd have sunk to a fifth
	MightUSSImpact = {
		Range = 2400,
		{ Id = L.CrackyPunch, Volume = 0.9, Speed = 0.6, Length = 0.6, Distort = 0.25, Fade = 0.3 },
		{ Id = L.BodySlamThump, Volume = 1, Speed = 0.7, Length = 1.1, Peak = true, Eq = { 5, 0, -5 }, Fade = 0.6 },
		{ Id = L.DeepImpact, Volume = 0.85, Length = 4.2, Peak = true, PreRoll = 0.03, Fade = 2.4, Near = 60 },
		{ Id = L.ThunderBlast, Volume = 0.8, Speed = 0.9, Length = 4, Peak = true, Delay = 0.03, Fade = 2.4, Near = 60 },
		{ Id = L.AirPound, Volume = 0.95, Speed = 0.75, Length = 1.6, Peak = true, Fade = 0.8 },
		{ Id = L.SonicPressure, Volume = 0.75, Speed = 0.9, Length = 3.2, Peak = true, Delay = 0.06, Fade = 2, Near = 60 },
		{ Id = L.BigBoomTail, Volume = 0.7, Length = 4.5, Peak = true, Delay = 0.1, Fade = 3, Near = 60 },
		{ Id = L.Quake, Volume = 0.45, Delay = 0.25, Length = 3.2, Fade = 2.2, Near = 60 },
	},
	-- (round 90) SAITAMA. His fists: a dull, heavy thud with a cartoon thump
	-- in it (Deep Impacts 7 is filed under "Cartoon" - for him, that's right)
	SaitamaHit = {
		Gap = 0.03,
		{ Id = L.BeefyHit, Volume = 0.9, Speed = { 0.8, 0.9 }, Length = 0.4 },
		{ Id = L.DeepImpact7, Volume = 0.35, Speed = { 1.1, 1.25 }, Length = 0.45 },
		{ Id = L.BodyHit, Volume = 0.5, Speed = { 0.9, 1 }, Length = 0.35 },
	},
	SaitamaHeavyHit = {
		Gap = 0.04,
		{ Id = L.CrackThud, Volume = 1.6, Speed = { 0.8, 0.88 }, Length = 0.6 },
		{ Id = L.DeepImpact7, Volume = 0.8, Speed = 0.95, Length = 0.6 },
		{ Id = L.AirPound, Volume = 0.8, Speed = { 0.9, 1 }, Length = 0.9, Peak = true },
		{ Id = L.SubBoom, Volume = 0.9, Speed = 0.9, Length = 1 },
	},
	-- NORMAL PUNCH: a lazy swish, then a punch out of all proportion to it -
	-- the thump, the crack, the pressure, the gale tearing off down the street
	NormalPunchSwing = {
		{ Id = L.SwishLarge, Volume = 1.1, Speed = { 0.85, 0.95 }, Length = 0.5 },
		{ Id = L.AirySlice, Volume = 1.2, Speed = { 0.9, 1 } },
	},
	NormalPunchHit = {
		Range = 1200,
		{ Id = L.DeepImpact7, Volume = 1.4, Speed = 0.85, Length = 0.8 },
		{ Id = L.CrackyPunch, Volume = 1.2, Speed = 0.75, Length = 0.5, Distort = 0.15 },
		{ Id = L.BodySlamThump, Volume = 1.2, Speed = 0.8, Length = 0.9, Peak = true, Eq = { 5, 0, -3 } },
		{ Id = L.SonicPressure, Volume = 0.9, Length = 2.2, Peak = true, Delay = 0.03, Fade = 1.2, Near = 40 },
		{ Id = L.SubBoom, Volume = 1, Speed = 0.9 },
	},
	NormalPunchGale = {
		Range = 900,
		{ Id = L.WindBlast, Volume = 1.1, Length = 2, Fade = 1.2, Near = 40 },
		{ Id = L.FlyGust, Volume = 1.4, Speed = { 0.9, 1.05 }, Length = 2.4, Fade = 1.4, Near = 40 },
	},
	-- CONSECUTIVE NORMAL PUNCHES: the PSE "Fast Punches" swishes, rattling
	-- (the voice cap: a Gap, and the flurry plays one every other punch)
	PunchFlurry = {
		Gap = 0.035,
		{ Id = L.FeatherSwish, Volume = 0.9, Speed = { 1.1, 1.45 }, Length = 0.3 },
	},
	PunchFlurryHit = {
		Gap = 0.045,
		{ Id = L.BeefyHit, Volume = 0.7, Speed = { 0.95, 1.1 }, Length = 0.3 },
		{ Id = L.CrackyPunch, Volume = 0.6, Speed = { 1, 1.15 }, Length = 0.25 },
	},
	PunchFlurryFinish = {
		Range = 900,
		{ Id = L.CrackThud, Volume = 1.8, Speed = 0.8, Length = 0.7 },
		{ Id = L.AirPound, Volume = 1.3, Speed = 0.9, Length = 1.2, Peak = true },
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.9 },
		{ Id = L.SonicCrack, Volume = 0.7, Length = 1.4, Peak = true, Delay = 0.02 },
	},
	-- SERIOUS SNEEZE: the breath in (a reverse suck), then the cone of wind
	SneezeInhale = {
		{ Id = L.SuckIn, Volume = 1.4, Speed = 1.05, Length = 0.95 },
		{ Id = L.AirBrake, Volume = 0.8, Speed = 1.3, Length = 0.6 },
	},
	SneezeBlast = {
		Range = 1400,
		{ Id = L.WindBlast, Volume = 1.4, Length = 2.2, Fade = 1.2, Near = 40 },
		{ Id = L.WhooshBurst, Volume = 1.2, Speed = 0.95 },
		{ Id = L.AirPound, Volume = 1.3, Speed = 0.9, Length = 1.3, Peak = true },
		{ Id = L.SonicPressure, Volume = 1, Length = 2.4, Peak = true, Delay = 0.02, Fade = 1.4, Near = 40 },
		{ Id = L.DebrisImpact, Volume = 0.7, Delay = 0.15, Length = 1.4 },
	},
	-- SERIOUS SIDE HOPS: a zip a hop, the zoom over them, a flick of the cape
	HopZip = {
		Gap = 0.035,
		{ Id = L.SwishThin, Volume = 1.1, Speed = { 1.5, 1.8 }, Length = 0.25 },
	},
	HopStart = {
		{ Id = L.MagicZoom, Volume = 0.8, Speed = 1.2, Length = 0.9, Fade = 0.4 },
	},
	HopLand = {
		{ Id = L.ClothTick, Volume = 1.2 },
		{ Id = L.SwishLarge, Volume = 0.6, Speed = 1.3, Length = 0.3 },
	},
	-- SERIOUS TABLE FLIP: the street grinding and cracking loose, heaved up,
	-- turned over and slammed down
	FlipGrip = {
		Range = 700,
		{ Id = L.StoneGrind, Volume = 1.4, Speed = 0.85, Length = 0.6 },
		{ Id = L.EarthCracking, Volume = 1.3, Length = 1.0, Fade = 0.5 },
	},
	FlipHeave = {
		Range = 900,
		{ Id = L.RockBurst, Volume = 1.3, Speed = 0.85, Length = 1.2 },
		{ Id = L.GiantSwish, Volume = 1.2, Speed = 0.7 },
		{ Id = L.Quake, Volume = 0.8, Length = 1.6, Fade = 0.8 },
	},
	FlipSlam = {
		Range = 1200,
		{ Id = L.WallCrash, Volume = 1.4 },
		{ Id = L.QuakeBlast, Volume = 1.2, Length = 3, Fade = 1.6, Near = 40 },
		{ Id = L.BodySlamThump, Volume = 1.4, Speed = 0.7, Length = 1, Peak = true, Eq = { 6, 0, -3 } },
		{ Id = L.BoulderCrack, Volume = 1, Delay = 0.04, Length = 1.2 },
		{ Id = L.DebrisImpact, Volume = 1, Delay = 0.1, Length = 1.6 },
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.85 },
	},
	-- the awakening: a beat of nothing, the cape snaps, the eyes glint - and
	-- the air round him jumps
	UltSaitama = {
		Range = 900,
		{ Id = L.CapeSnap, Volume = 1.1 },
		{ Id = L.SwordShing, Volume = 0.7, Speed = 1.25, Delay = 0.32, Length = 0.8 },
		{ Id = L.AirPound, Volume = 0.9, Peak = true, Delay = 0.34, Length = 1.2 },
		{ Id = L.SubBoom, Volume = 0.9, Delay = 0.34 },
		{ Id = L.SonicPressure, Volume = 0.6, Peak = true, Delay = 0.36, Length = 2, Fade = 1.2, Near = 40 },
	},
	-- SERIOUS SERIES: SERIOUS PUNCH. These play FLAT on every screen (the
	-- whole city hears it), each machine setting its own gain by how far it
	-- is (VFX.ST). The windup: the wind and the churning rumble rising over
	-- the city (FadeIn), gusting; his eyes going serious (a shing over a deep
	-- thoom); the fist drawn back: the riser, the street grinding, every
	-- window shivering, and the whole thing sucked out to silence exactly as
	-- the punch lands (TuttiSuck's suck-out 0.85 s after its Start)
	SeriousWind = {
		{ Id = L.FlyBuffet, Volume = 2.6, Length = 4.4, Fade = 0.3, FadeIn = 1.2 },
		{ Id = L.FlyHyperRumble, Volume = 3, Length = 4.4, Fade = 0.3, FadeIn = 2 },
		{ Id = L.HowlingWind, Volume = 1, Delay = 0.4, Length = 3.9, Fade = 0.6 },
		{ Id = L.FlyGust, Volume = 1.2, Delay = 1.6, Length = 2.4, Fade = 0.5 },
	},
	SeriousEyes = {
		{ Id = L.SwordShing, Volume = 1, Speed = 0.85, Length = 1.2 },
		{ Id = L.DeepImpact7, Volume = 0.8, Speed = 0.7, Length = 0.9 },
		{ Id = L.SubBoom, Volume = 0.7, Speed = 0.8 },
	},
	SeriousCharge = {
		{ Id = L.SeriousRiser, Volume = 1.6, Length = 2.85, Fade = 0.1 },
		{ Id = L.SubSuck, Volume = 1.2, Delay = 1.95, Length = 0.9, Fade = 0.1 },
		{ Id = L.TuttiSuck, Volume = 1.1, Delay = 1.95, Length = 0.9, Fade = 0.05 },
		{ Id = L.StoneGrind, Volume = 0.8, Speed = 0.6, Length = 2.6, Fade = 1 },
		{ Id = L.GlassShiver, Volume = 1.4, Length = 2.6, Fade = 1 },
	},
	-- the punch: the fist's crack, the boom, the city coming apart under it
	SeriousPunch = {
		{ Id = L.CrackyPunch, Volume = 1.2, Speed = 0.55, Length = 0.6, Distort = 0.3 },
		{ Id = L.SonicBoomAPM, Volume = 1.6, Length = 5, Fade = 3 },
		{ Id = L.SonicPressure, Volume = 1.4, Length = 3.5, Peak = true, Fade = 2 },
		{ Id = L.QuakeBlast, Volume = 1.6, Length = 6, Fade = 4 },
		{ Id = L.DeepImpact, Volume = 1.2, Length = 4, Peak = true, PreRoll = 0.03, Fade = 2.5 },
		{ Id = L.BigBoomTail, Volume = 1.1, Length = 5, Peak = true, Delay = 0.08, Fade = 3.5 },
		{ Id = L.SubBoom, Volume = 1.4 },
		{ Id = L.CapeSnap, Volume = 1, Delay = 0.02 },
	},
	-- the wave going over you: the gale, the tearing roar, the buildings
	-- round you breaking up (each screen plays it as its own wave arrives)
	SeriousWave = {
		{ Id = L.WindBlast, Volume = 1.5, Length = 2.6, Fade = 1.6 },
		{ Id = L.FlyHyperBed, Volume = 1.3, Length = 2.8, Fade = 2, FadeIn = 0.1 },
		{ Id = L.WallCrash, Volume = 1.2, Delay = 0.05 },
		{ Id = L.MetalCrash, Volume = 0.9, Delay = 0.12 },
		{ Id = L.GlassSmash, Volume = 0.9, Delay = 0.1 },
		{ Id = L.EarthCracking, Volume = 1.1, Delay = 0.2, Length = 2.4, Fade = 1.2 },
		{ Id = L.WallCrashRubble, Volume = 0.8, Delay = 0.35, Length = 2.5, Fade = 1.2 },
	},
	-- after it: a wind over an empty plain, the last of the rumble, far-off booms
	SeriousAftermath = {
		{ Id = L.AiryWind, Volume = 2.4, Length = 9, Fade = 4, FadeIn = 1.5 },
		{ Id = L.Rumbler, Volume = 1.2, Length = 6, Fade = 3 },
		{ Id = L.ThunderRoll, Volume = 0.6, Delay = 0.5, Length = 5, Fade = 3 },
		{ Id = L.DistantBooms, Volume = 2.2, Delay = 1.2, Length = 4, Fade = 2 },
	},
	-- the city flying back together: a slow swell sucked in as the last of it
	-- snaps home (2.9 s: RewindSpan + RewindTime), with a thump
	SeriousRewind = {
		{ Id = L.MagicZoom, Volume = 1, Speed = 0.7, Length = 2, Fade = 0.8 },
		{ Id = L.SweepAperture, Volume = 1, Speed = 0.8, Delay = 0.3, Length = 2.2, Fade = 0.8 },
		{ Id = L.TuttiSuck, Volume = 1.3, Speed = 0.8, Delay = 1.84, Length = 1.2, Fade = 0.05 },
		{ Id = L.SubSuck, Volume = 1, Delay = 2.2, Length = 0.9, Fade = 0.1 },
		{ Id = L.DeepImpact7, Volume = 1.2, Speed = 0.8, Delay = 2.9, Length = 0.9 },
	},
	-- his cape in the gale (played every few tenths of a second as it whips)
	SaitamaCape = {
		Gap = 0.2,
		{ Id = L.CapeFlap, Volume = 1.3, Speed = { 0.9, 1.1 }, Length = 0.8 },
	},
	-- (round 92) INASA. Every take is the library's own, already in L (the
	-- r86 catalog's measured Starts). His fists: a meaty punch with a burst
	-- of air behind it
	InasaHit = {
		Gap = 0.03,
		{ Id = L.BeefyHit, Volume = 0.8, Speed = { 0.9, 1 }, Length = 0.4 },
		{ Id = L.AirySlice, Volume = 1.2, Speed = { 0.8, 0.95 }, Length = 0.35 },
	},
	InasaHeavyHit = {
		Gap = 0.04,
		{ Id = L.CrackThud, Volume = 1.7, Speed = { 0.88, 0.96 }, Length = 0.6 },
		{ Id = L.AirPound, Volume = 0.9, Speed = { 1, 1.1 }, Length = 0.8, Peak = true },
		{ Id = L.WhooshBurst, Volume = 0.8, Speed = 0.9, Length = 0.7 },
	},
	-- SLICING GUST: a gust a pulse (the whoosh, the air slicing past), the
	-- shove landing on them
	InasaGustPulse = {
		Gap = 0.05,
		{ Id = L.WhooshBurst, Volume = 1, Speed = { 0.85, 1 }, Length = 0.7 },
		{ Id = L.AirySlice, Volume = 1.5, Speed = { 0.75, 0.9 }, Length = 0.4 },
	},
	InasaGustHit = {
		Gap = 0.05,
		{ Id = L.AirPound, Volume = 0.7, Speed = { 1.1, 1.25 }, Length = 0.5, Peak = true },
		{ Id = L.BodyHit, Volume = 0.5, Speed = { 0.95, 1.05 }, Length = 0.3 },
	},
	-- GALE CANNON: the air sucked into his palms, then the blast down the
	-- street (the boom, the pressure, the howl after it), and the burst on a wall
	InasaCannonDraw = {
		{ Id = L.AirBrake, Volume = 1.1, Speed = 1.15, Length = 0.6 },
		{ Id = L.SuckShort, Volume = 0.9, Speed = 1.2, Length = 0.5 },
	},
	InasaCannonFire = {
		Range = 1200,
		{ Id = L.WindBlast, Volume = 1.3, Length = 2, Fade = 1.1, Near = 40 },
		{ Id = L.AirPound, Volume = 1.2, Speed = 0.85, Length = 1.2, Peak = true },
		{ Id = L.SonicPressure, Volume = 0.9, Length = 2.2, Peak = true, Delay = 0.02, Fade = 1.2, Near = 40 },
		{ Id = L.SubBoom, Volume = 1.1, Speed = 0.9 },
		{ Id = L.FlyGust, Volume = 1.2, Delay = 0.1, Length = 2, Fade = 1.2, Near = 40 },
	},
	InasaCannonBurst = {
		Range = 900,
		{ Id = L.WallCrash, Volume = 1.2 },
		{ Id = L.DebrisImpact, Volume = 1, Delay = 0.06, Length = 1.4 },
		{ Id = L.AirPound, Volume = 1, Speed = 0.8, Length = 1, Peak = true },
	},
	-- DRAGON WHIRLWIND: the spin-up and the fling, its roar while it rolls
	-- (played again as each dies away: InasaWhirlLoop), the burst that throws them
	InasaWhirlSpin = {
		{ Id = L.GiantSwish, Volume = 1.1, Speed = 1.1 },
		{ Id = L.SwishLarge, Volume = 1, Speed = 0.8, Length = 0.5 },
	},
	InasaWhirlLoop = {
		Range = 700,
		{ Id = L.FlyGust, Volume = 1.4, Speed = { 0.95, 1.05 }, Length = 2.2, Fade = 0.7, FadeIn = 0.35, Near = 30 },
		{ Id = L.TearingAir, Volume = 1.3, Length = 2.2, Fade = 0.7, FadeIn = 0.35, Near = 30 },
	},
	InasaWhirlBurst = {
		Range = 900,
		{ Id = L.WindBlast, Volume = 1.2, Length = 1.8, Fade = 1, Near = 40 },
		{ Id = L.AirPound, Volume = 1.1, Speed = 0.9, Length = 1, Peak = true },
		{ Id = L.DirtBurst, Volume = 0.8, Delay = 0.05, Length = 1 },
	},
	-- WIND WALL: the wall going up (a canvas snap of air), a hit stopped
	-- dead on it, the gust that sends a shot back
	InasaWallUp = {
		{ Id = L.WhooshBurst, Volume = 1.1, Speed = 0.8, Length = 0.8 },
		{ Id = L.ClothBloom, Volume = 1, Length = 1.2, Fade = 0.6 },
		{ Id = L.AirPound, Volume = 0.8, Speed = 1.1, Length = 0.7, Peak = true },
	},
	InasaWallBlock = {
		Gap = 0.06,
		{ Id = L.AirPound, Volume = 0.9, Speed = { 1.15, 1.3 }, Length = 0.5, Peak = true },
		{ Id = L.SwishLarge, Volume = 0.8, Speed = 1.2, Length = 0.35 },
	},
	InasaWallDeflect = {
		Gap = 0.08,
		Range = 700,
		{ Id = L.GiantSwish, Volume = 1.1, Speed = 1.25 },
		{ Id = L.AirPound, Volume = 0.9, Speed = 0.95, Length = 0.8, Peak = true },
		{ Id = L.WhooshSwishBy, Volume = 0.9, Length = 0.6 },
	},
	-- WIND RIDE: the gust that throws him up onto it, the air rushing past,
	-- the landing
	InasaRideStart = {
		{ Id = L.SweepAperture, Volume = 0.9, Speed = 1.1, Length = 1.2, Fade = 0.5 },
		{ Id = L.WhooshBurst, Volume = 1, Speed = 0.9, Length = 0.7 },
		{ Id = L.AirPound, Volume = 0.8, Speed = 1.1, Length = 0.6, Peak = true },
	},
	InasaRideRush = {
		{ Id = L.FlyGust, Volume = 1.2, Speed = { 1.05, 1.15 }, Length = 1.8, Fade = 0.6, FadeIn = 0.15 },
	},
	InasaRideEnd = {
		{ Id = L.AirBrake, Volume = 1, Speed = 1.1, Length = 0.6 },
		{ Id = L.ClothTick, Volume = 1.1 },
	},
	-- the awakening: the bow, then the air round him going up all at once
	UltWhirlwind = {
		Range = 900,
		{ Id = L.WindBlast, Volume = 1.2, Delay = 0.45, Length = 2, Fade = 1.2, Near = 40 },
		{ Id = L.AirPound, Volume = 1, Delay = 0.45, Length = 1.2, Peak = true },
		{ Id = L.SubBoom, Volume = 0.9, Delay = 0.45 },
		{ Id = L.CapeSnap, Volume = 1, Delay = 0.48 },
		{ Id = L.FlyGust, Volume = 1.3, Delay = 0.55, Length = 2.4, Fade = 1.4, Near = 40 },
	},
	-- SKYBREAKER CYCLONE. Played FLAT on every screen (the whole city hears
	-- it, each machine at its own gain by how far it is: VFX.IN.far). The
	-- wind rising over the city as it forms (FadeIn), the funnel tearing up
	-- to the clouds, its roar while it pulls, the burst and the city hurled
	InasaSkyWind = {
		{ Id = L.FlyBuffet, Volume = 2.4, Length = 5, Fade = 0.6, FadeIn = 1 },
		{ Id = L.FlyHyperRumble, Volume = 2.6, Length = 5, Fade = 0.6, FadeIn = 1.4 },
		{ Id = L.HowlingWind, Volume = 1, Delay = 0.3, Length = 4.6, Fade = 0.8 },
	},
	InasaSkyRise = {
		{ Id = L.FlangeStorm, Volume = 1.4, Length = 4.6, Fade = 0.8, FadeIn = 0.4 },
		{ Id = L.GaiaRoll, Volume = 1.2, Length = 2.4, Fade = 1.2 },
		{ Id = L.Quake, Volume = 0.9, Length = 2.6, Fade = 1.2 },
		{ Id = L.TearingAir, Volume = 1.6, Delay = 0.5, Length = 4, Fade = 0.8, FadeIn = 0.5 },
	},
	InasaHurlBlast = {
		{ Id = L.WindBlast, Volume = 1.5, Length = 2.6, Fade = 1.4 },
		{ Id = L.SonicPressure, Volume = 1.3, Length = 3, Peak = true, Fade = 1.8 },
		{ Id = L.DeepImpact, Volume = 1.1, Length = 3.5, Peak = true, PreRoll = 0.03, Fade = 2.2 },
		{ Id = L.BigBoomTail, Volume = 1, Length = 4.5, Peak = true, Delay = 0.08, Fade = 3 },
		{ Id = L.SubBoom, Volume = 1.3 },
		{ Id = L.RockBurst, Volume = 1.1, Delay = 0.1, Length = 2, Fade = 1 },
	},
	-- a piece of the city hurled past, and landing
	InasaChunkWhoosh = {
		Gap = 0.06,
		Range = 500,
		{ Id = L.GiantSwish, Volume = 1, Speed = { 0.9, 1.15 } },
	},
	InasaChunkHit = {
		Gap = 0.05,
		Range = 700,
		{ Id = L.DebrisImpact, Volume = 1.1, Speed = { 0.9, 1.1 }, Length = 1.2 },
		{ Id = L.BoulderCrack, Volume = 0.8, Speed = { 0.95, 1.1 }, Length = 0.8 },
	},
	-- his cape snapping in his own wind
	InasaCape = {
		Gap = 0.2,
		{ Id = L.CapeFlap, Volume = 1.2, Speed = { 0.95, 1.15 }, Length = 0.8 },
	},
	InasaDash = {
		{ Id = L.WhooshBurst, Volume = 0.8, Speed = { 1, 1.15 }, Length = 0.6 },
		{ Id = L.AirySlice, Volume = 1.2, Speed = 0.85 },
	},
	-- (round 78) the decoy left landing on his face
	USSJab = {
		Range = 900,
		{ Id = L.CrackyPunch, Volume = 1, Speed = { 0.85, 0.95 }, Length = 0.4 },
		{ Id = L.BeefyHit, Volume = 0.8, Speed = 0.9, Length = 0.4 },
		{ Id = L.AirPound, Volume = 0.5, Speed = 1.25, Length = 0.5, Peak = true, Fade = 0.25 },
	},
	-- ...and the overhand right on the face: one sharp crack, then nothing
	-- (the impact frame: the music drops out with it)
	USSStrike = {
		Range = 1600,
		{ Id = L.CrackyPunch, Volume = 1.1, Speed = 0.7, Length = 0.5, Distort = 0.3, Fade = 0.2 },
		{ Id = L.BodySlamThump, Volume = 0.9, Speed = 0.8, Length = 0.6, Peak = true, Eq = { 5, 0, -3 }, Fade = 0.3 },
		{ Id = L.SonicCrack, Volume = 0.5, Speed = 1.1, Length = 0.9, Peak = true, Fade = 0.6 },
	},
	-- a whiff: he over-reaches through the air. (round 81) Arms wheeling,
	-- not a second punch: the decoy's swing already made the big swish
	USSWhiff = { { Id = L.SwishLarge, Volume = 0.7, Speed = 0.8, Length = 0.6 }, { Id = L.WhooshBurst, Volume = 0.4, Speed = 0.9, Length = 0.6, Fade = 0.3 } },
	-- (round 81) THE BUILD, timed to the strike. USSCharge was the round-76
	-- 0.95s charge: over the 2s build it was played twice, its suck-in
	-- "hit" twice on nothing, and its power-up ran on through the impact
	-- frame (it stays for Deku's AB sequence). The hum swells under
	-- "UNITED STATES OF..." and is gone before the swing...
	USSBuildHum = {
		Range = 1200,
		{ Id = L.PowerUp, Volume = 1.6, Speed = 0.8, Length = 1.8, Fade = 0.6 },
		{ Id = L.EnergyGrowl, Volume = 1.1, Speed = 0.7, Length = 1.2, Fade = 0.5 },
		{ Id = L.Zap, Volume = 1, Speed = 0.8, Delay = 0.3, Length = 1, Fade = 0.4 },
	},
	-- ...and the air sucked into the fist, closing on the strike: played Lead
	-- seconds before it (measured in Studio: the file swells to its close at
	-- 1.68s, 0.93s past its Start), it stops just after, under the crack.
	-- (A quiet file - 0.05 RMS at its loudest - hence the Volume.)
	USSSuck = { Range = 1200, Lead = 0.93, { Id = L.SuckIn, Volume = 5, Length = 1, Fade = 0.06 } },
	-- (round 81) his feet hitting the street: dropping onto both under them
	-- on the catch; the stumble out of a whiff, and the hop back
	USSFootfall = {
		Range = 500,
		Gap = 0.1,
		{ Id = L.BodyFall, Volume = 0.5, Speed = 1.1, Length = 0.4, Fade = 0.15 },
		{ Id = L.DirtBurst, Volume = 0.35, Length = 0.5, Fade = 0.2 },
	},
	-- (round 81) the twister's own wind (Twister stays for the Hurricane
	-- Smash and the AB sequence): full volume out to 70 studs (Near), so it's
	-- heard from the crane shot, 60-110 studs off, over the music swelling
	-- back. The loop carries it as long as the funnel lasts: each play rises
	-- (FadeIn) as the one before dies away, so the roar never dips or restarts
	USSTwister = {
		Range = 1200,
		{ Id = L.WindRoar, Volume = 1.4, Length = 3.6, Fade = 1.6, Near = 70 },
		{ Id = L.HowlingWind, Volume = 1.1, Speed = 0.8, Length = 3.6, Fade = 1.8, Near = 70 },
	},
	USSTwisterLoop = {
		Range = 1200,
		Gap = 0.5,
		{ Id = L.WindRoar, Volume = 1.15, Length = 3.6, FadeIn = 1, Fade = 1.6, Near = 70 },
		{ Id = L.HowlingWind, Volume = 0.9, Speed = 0.8, Length = 3.6, FadeIn = 1, Fade = 1.8, Near = 70 },
	},
	-- (round 81) thunder rolling under the lightning in its storm cloud
	USSThunder = { Range = 1500, Gap = 1.1, { Id = L.ThunderBlast, Volume = 0.8, Speed = { 0.85, 1 }, Length = 2.4, Fade = 1.8, Peak = true, PreRoll = 0.12, Near = 160 } },
	-- the updraft twister the punch leaves behind (round 78: quieter, rising
	-- and dying away under the music)
	Twister = { Range = 1200, { Id = L.WindRoar, Volume = 1.4, Length = 3.6, Fade = 1.6 }, { Id = L.HowlingWind, Volume = 1.1, Speed = 0.8, Length = 3.6, Fade = 1.8 } },
	-- Colorado Smash: the takeoff cracks the street, then the long rising leap
	ColoradoLeap = {
		Range = 900,
		{ Id = L.SubBoom, Volume = 0.74 },
		{ Id = L.BoulderCrack, Volume = 0.41, Length = 0.8 },
		{ Id = L.WhooshBurst, Volume = 0.74, Speed = 0.85, Length = 1.2 },
		{ Id = L.AscendWhoosh, Volume = 0.74, Length = 1.4 },
	},
	ColoradoImpact = {
		Range = 1400,
		{ Id = L.PowerBoom, Volume = 1.69, Speed = 0.9 },
		{ Id = L.SubBoom, Volume = 1.84, Speed = 0.8 },
		{ Id = L.RockBurst, Volume = 1.38, Length = 3 },
		{ Id = L.BodyFallHuge, Volume = 1.23, Length = 1.2 },
		{ Id = L.DirtBurst, Volume = 1.23, Delay = 0.15, Length = 1.5 },
	},
	-- ONE FOR ALL: 9TH (Deku)
	CowlOn = {
		Range = 700,
		{ Id = L.PowerUp, Volume = 2.04, Speed = 1.1 },
		{ Id = L.Zap, Volume = 1.78, Speed = { 0.9, 1.05 } },
		{ Id = L.SubBoom, Volume = 1.53, Speed = 1.1 },
		{ Id = L.Static, Volume = 1.27, Delay = 0.1 },
	},
	AirBullet = {
		Range = 600,
		{ Id = L.CrackyPunch, Volume = 1.13, Speed = 1.3, Length = 0.3 },
		{ Id = L.WhooshBurst, Volume = 0.73, Speed = 1.35, Length = 0.6 },
		{ Id = L.SwishThin, Volume = 0.81, Speed = 0.8 },
	},
	Blackwhip = {
		{ Id = L.SwishLarge, Volume = 1.58, Speed = { 1.1, 1.25 } },
		{ Id = L.MetalSwoosh, Volume = 1.19, Speed = 0.7, Length = 0.5 },
		{ Id = L.CrackyPunch, Volume = 1.19, Speed = 1.5, Length = 0.25, Delay = 0.1 },
	},
	Smokescreen = {
		Range = 600,
		{ Id = L.WhooshExplosion, Volume = 1.08, Speed = 0.7, Length = 1.2 },
		{ Id = L.GiantSwish, Volume = 1.3, Speed = 0.8, Length = 1.4 },
		{ Id = L.DirtBurst, Volume = 0.87, Speed = 0.8, Length = 1 },
	},
	UltFullCowl = {
		Range = 1200,
		{ Id = S.Beast, Volume = 0.86, Start = 0.25, Speed = 1.05 },
		{ Id = L.Zap, Volume = 1.33, Speed = 0.8 },
		{ Id = L.PowerUp, Volume = 1.33, Speed = 0.8 },
		{ Id = L.SubBoom, Volume = 1.2, Speed = 0.7 },
		{ Id = L.Static, Volume = 0.8, Delay = 0.2 },
	},
	-- OVERHAUL, like the anime: the red crackle as his Quirk takes hold, then a
	-- wet burst of snapping bone as it comes apart, and the squelch and click
	-- of it all slotting back together. Timed to the effects: bodies burst
	-- 0.35s after the touch lands (Disassemble / Restore / the ult).
	Disassemble = {
		Gap = 0.04,
		{ Id = L.QuirkCrackle, Volume = 1.5, Speed = { 1.05, 1.2 }, Length = 0.4 },
		{ Id = L.CrackyPunch, Volume = 1.3, Speed = 1.2, Length = 0.3 },
		{ Id = L.BoneSnap, Volume = 2.6, Speed = { 0.9, 1.05 }, Length = 0.35, Delay = 0.33 },
		{ Id = L.JuicySplat, Volume = 1.4, Speed = { 0.85, 1 }, Length = 0.5, Delay = 0.35 },
		{ Id = L.GutsSplat, Volume = 0.9, Speed = 0.95, Length = 0.5, Delay = 0.36 },
		{ Id = L.SubBoom, Volume = 0.9, Speed = 1.15, Length = 0.5, Delay = 0.35 },
	},
	Reassemble = {
		Gap = 0.05,
		{ Id = L.FleshReshape, Volume = 5, Speed = 1.35, Length = 0.3 },
		{ Id = L.SuckShort, Volume = 3, Speed = 1.4, Length = 0.4 },
		{ Id = L.QuirkCrackle, Volume = 1, Speed = 1.3, Length = 0.25 },
		{ Id = L.BoneSnap, Volume = 2.4, Speed = 1.15, Length = 0.3, Delay = 0.2 },
	},
	SpikeErupt = {
		Range = 700,
		Gap = 0.05,
		{ Id = L.QuirkCrackle, Volume = 0.7, Speed = { 0.9, 1.05 }, Length = 0.25 },
		{ Id = L.BoulderCrack, Volume = 1.8, Speed = { 0.95, 1.15 }, Length = 0.9 },
		{ Id = L.StoneGrind, Volume = 2.4, Speed = { 1, 1.2 }, Length = 0.7 },
		{ Id = L.DebrisImpact, Volume = 1.4, Speed = { 0.9, 1.1 }, Length = 0.7 },
		{ Id = L.SubBoom, Volume = 1.1, Speed = 1.2, Length = 0.6 },
	},
	Restore = {
		{ Id = L.QuirkCrackle, Volume = 1.8, Speed = 1.1, Length = 0.38 },
		{ Id = L.JuicySplat, Volume = 1, Speed = 1.1, Length = 0.35, Delay = 0.35 },
		{ Id = L.FleshReshape, Volume = 5, Speed = 1.2, Length = 0.4, Delay = 0.36 },
		{ Id = L.SuckShort, Volume = 3, Speed = 1.1, Length = 0.5, Delay = 0.2 },
		{ Id = L.BoneSnap, Volume = 1.5, Speed = 1.2, Length = 0.3, Delay = 0.62 },
		{ Id = L.PowerHit, Volume = 1.6, Speed = 1.2, Length = 0.6, Delay = 0.65 },
	},
	-- the ult (fused with Nemoto) and Total Overhaul's wind-up: a long crackle,
	-- his body bursting and knitting back together bigger
	UltOverhaul = {
		Range = 1200,
		{ Id = L.CrackleRun, Volume = 1.6, Speed = 0.95, Length = 1 },
		{ Id = L.GutsSplat, Volume = 1.2, Speed = 0.85, Length = 0.6, Delay = 0.35 },
		{ Id = L.BoneSnap, Volume = 1.8, Speed = 0.85, Length = 0.4, Delay = 0.35 },
		{ Id = L.FleshReshape, Volume = 3.2, Speed = 0.9, Length = 1.3, Delay = 0.4 },
		{ Id = S.Beast, Volume = 0.9, Start = 0.25, Speed = 0.8, Delay = 0.3 },
		{ Id = L.Quake, Volume = 1.6, Speed = 0.9, Length = 2 },
		{ Id = L.StoneGrind, Volume = 2, Speed = 0.8, Length = 1.4, Delay = 0.3 },
	},
	TotalOverhaul = {
		Range = 1600,
		{ Id = L.CrackleRun, Volume = 1.8, Speed = 0.8, Length = 1.2 },
		{ Id = L.Quake, Volume = 2.2, Speed = 0.8, Length = 4 },
		{ Id = L.RockBurst, Volume = 2, Speed = 0.9, Length = 3.5 },
		{ Id = L.BoomThump, Volume = 2, Speed = 0.75 },
		{ Id = L.StoneGrind, Volume = 2.6, Speed = 0.75, Length = 2.2, Delay = 0.2 },
		{ Id = L.BoulderCrack, Volume = 1.8, Speed = 0.8, Length = 2, Delay = 0.4 },
	},
	-- the kaiju (Fusion: Katsukame): he comes apart with a wet crack, the
	-- flesh and the street knit into the monster, and it roars
	KaijuFuse = {
		Range = 1200,
		{ Id = L.CrackleRun, Volume = 1.8, Speed = 0.9, Length = 0.6 },
		{ Id = L.BoneSnap, Volume = 2.2, Speed = 0.8, Length = 0.4, Delay = 0.43 },
		{ Id = L.GutsSplat, Volume = 1.4, Speed = 0.8, Length = 0.7, Delay = 0.45 },
		{ Id = L.BloodSpurt, Volume = 1.2, Speed = 0.8, Length = 0.8, Delay = 0.47 },
		{ Id = L.MeatyThud, Volume = 1.2, Speed = 0.7, Length = 0.6, Delay = 0.45 },
		{ Id = L.FleshReshape, Volume = 4, Speed = 0.75, Length = 1.3, Delay = 0.5 },
	},
	KaijuRise = {
		Range = 1600,
		{ Id = L.Quake, Volume = 2.4, Speed = 0.7, Length = 3 },
		{ Id = L.RockBurst, Volume = 2, Speed = 0.8, Length = 3 },
		{ Id = L.StoneGrind, Volume = 3, Speed = 0.65, Length = 1.6, Delay = 0.1 },
		{ Id = L.DebrisMove, Volume = 1.6, Speed = 0.8, Delay = 0.3, Length = 2.5 },
		{ Id = L.QuirkCrackle, Volume = 1, Speed = 0.8, Length = 0.8, Delay = 0.2 },
	},
	KaijuRoar = {
		Range = 1600,
		{ Id = L.MonsterRoar, Volume = 3.2, Speed = 0.85, Length = 3.2 },
		{ Id = L.RoarBlast, Volume = 3.6, Speed = 0.9, Length = 2.6 },
		{ Id = L.BeastRumble, Volume = 1.8, Speed = 0.75, Length = 2.6 },
		{ Id = L.BoomThump, Volume = 2, Speed = 0.7 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.6 },
	},
	KaijuSwing = {
		Range = 800,
		{ Id = L.GiantSwish, Volume = 1.1, Speed = { 0.55, 0.65 }, Length = 0.8 },
		{ Id = L.MonsterGrowl, Volume = 2.6, Speed = { 1, 1.2 }, Length = 0.9 },
	},
	KaijuSlam = {
		Range = 1000,
		{ Id = L.BoulderCrack, Volume = 1.8, Speed = 0.8, Length = 1.2 },
		{ Id = L.GiantStep, Volume = 1.8, Speed = 0.8, Length = 1.2 },
		{ Id = L.MeatyThud, Volume = 1.4, Speed = 0.6, Length = 0.6 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.7 },
		{ Id = L.DirtBurst, Volume = 1.6, Speed = 0.8, Length = 1.2, Delay = 0.05 },
	},
	KaijuStep = {
		Range = 500,
		Gap = 0.2,
		{ Id = L.GiantStep, Volume = 1.3, Speed = { 0.85, 1.05 }, Length = 0.9 },
		{ Id = L.DebrisImpact, Volume = 0.7, Speed = 0.7, Length = 0.6 },
	},
	KaijuCollapse = {
		Range = 1200,
		{ Id = L.CrackleRun, Volume = 1.6, Speed = 0.8, Length = 0.8 },
		{ Id = L.FleshReshape, Volume = 3.5, Speed = 0.7, Length = 1.2 },
		{ Id = L.BoulderCrack, Volume = 2, Speed = 0.7, Length = 1.5, Delay = 0.1 },
		{ Id = L.RockBurst, Volume = 1.6, Speed = 0.9, Length = 2, Delay = 0.1 },
	},
	-- the finished body flying off
	FinisherLaunch = {
		Range = 700,
		{ Id = L.GiantSwish, Volume = 0.8, Speed = { 0.8, 0.9 }, Length = 1.2 },
		{ Id = L.WhooshBurst, Volume = 0.6, Speed = 0.9, Length = 1 },
		{ Id = L.DeepBlast, Volume = 0.5, Speed = 1.1, Length = 0.8 },
	},
	-- finishers: the killing blow lands
	Finisher = {
		Range = 900,
		{ Id = L.CrackThud, Volume = 2.4, Speed = 0.8, Length = 0.7 },
		{ Id = L.SubBoom, Volume = 1.8, Speed = 0.75 },
		{ Id = L.BoomThump, Volume = 1.4, Speed = 0.9 },
		{ Id = L.PowerHit, Volume = 1.6, Speed = 0.8, Length = 0.8 },
	},
	-- LIMITLESS
	InfinityOn = { { Id = L.SuckShort, Volume = 7.25, Speed = 1.3, Length = 0.5 }, { Id = L.PowerHit, Volume = 3.62, Speed = 1.4, Length = 0.6 } },
	InfinityStop = { Gap = 0.08, { Id = L.SuckShort, Volume = 4.32, Speed = 1.6, Length = 0.35 }, { Id = L.SwishThin, Volume = 1.44, Speed = 0.6 } },
	Blue = {
		Range = 800,
		{ Id = L.SuckIn, Volume = 3.82, Speed = 0.8, Length = 1.6 },
		{ Id = L.HowlingWind, Volume = 2.04, Speed = 1.2, Length = 2 },
		{ Id = L.EnergyGrowl, Volume = 1.53, Speed = 0.6, Length = 1.4 },
	},
	RedCharge = { { Id = L.EnergyGrowl, Volume = 1, Speed = 1.3, Length = 0.5 }, { Id = L.Static, Volume = 1, Speed = 0.8 } },
	Red = {
		Range = 1000,
		{ Id = L.CrackyPunch, Volume = 1.96, Speed = 0.8, Length = 0.5 },
		{ Id = L.PowerBoom, Volume = 1.71, Speed = 1.05 },
		{ Id = L.VortexBlast, Volume = 1.71, Speed = 0.9, Length = 1.4 },
		{ Id = L.SubBoom, Volume = 1.47 },
	},
	PurpleCharge = {
		Range = 1000,
		{ Id = L.PowerUp, Volume = 2.98, Speed = 0.7 },
		{ Id = L.SuckIn, Volume = 4.97, Speed = 0.75, Length = 1.3 },
		{ Id = L.Zap, Volume = 1.99, Speed = 0.7, Delay = 0.3 },
	},
	Purple = {
		Range = 2000,
		{ Id = S.Beast, Volume = 1.62, Start = 0.25, Speed = 0.7 },
		{ Id = L.PowerBoomLong, Volume = 2.16, Speed = 0.7, Length = 3 },
		{ Id = L.WindRoar, Volume = 2.16, Speed = 0.8, Length = 2.5 },
		{ Id = L.DeepBlast, Volume = 1.89, Speed = 0.8, Length = 2 },
	},
	Blink = { Gap = 0.05, { Id = L.AirySlice, Volume = 1.75, Speed = 1.4 }, { Id = L.EnergySnap, Volume = 0.88, Speed = 1.6, Length = 0.3 } },
	Domain = {
		Range = 1600,
		{ Id = L.SuckIn, Volume = 3, Speed = 0.6, Length = 1.6 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.5 },
		{ Id = S.Thunder, Volume = 1, Start = 1.0, Length = 2, Speed = 0.8 },
		{ Id = S.Stinger, Volume = 0.8, Speed = 0.6, Delay = 0.6 },
	},
	UltLimitless = { Range = 1200, { Id = L.PowerHit, Volume = 4.26, Speed = 0.8 }, { Id = L.SuckShort, Volume = 6.39, Speed = 0.8, Length = 0.8 } },
	-- cinematics
	CineCut = { { Id = L.AirySlice, Volume = 3.35, Speed = 1.2 } },
	CineHit = { { Id = L.CrackyPunch, Volume = 1.56, Speed = 0.7, Length = 0.5 }, { Id = L.SubBoom, Volume = 1.25, Speed = 0.8 } },
	-- (round 87) the director camera's own sounds (flat, quiet, and only
	-- while its overlay is up: never in a recording): on and off (a clapper's
	-- clack and a soft ping), a tick for each switch, a key dropped, the dolly
	-- rolling (the clapper), the freeze frame (a flashbulb and a shutter
	-- click), slow motion setting in (a low suck) and speed coming back
	DirectorOn = { { Id = L.WoodClunk, Volume = 0.55, Speed = 1.6, Length = 0.22 }, { Id = S.Ping, Volume = 0.22, Speed = 1.4, Length = 0.3, Delay = 0.05 } },
	DirectorOff = { { Id = L.WoodClunk, Volume = 0.45, Speed = 1.3, Length = 0.22 }, { Id = S.Ping, Volume = 0.18, Speed = 0.9, Length = 0.3 } },
	DirectorTick = { Gap = 0.04, { Id = L.SwordTick, Volume = 0.3, Speed = 2.6, Length = 0.12 } },
	DirectorKey = { { Id = L.SwordTick, Volume = 0.4, Speed = 2, Length = 0.15 }, { Id = S.Ping, Volume = 0.25, Speed = 2.2, Length = 0.2 } },
	DirectorAction = { { Id = L.WoodClunk, Volume = 0.9, Speed = 1.9, Length = 0.25 }, { Id = L.SwordTick, Volume = 0.25, Speed = 3, Length = 0.1 } },
	DirectorShutter = { { Id = S.Flash, Volume = 0.7, Speed = 1.25 }, { Id = L.SwordTick, Volume = 0.35, Speed = 3.2, Length = 0.08 } },
	DirectorSlow = { { Id = L.SuckShort, Volume = 1.4, Speed = 0.55, Length = 0.6, Fade = 0.2 }, { Id = L.SubBoom, Volume = 0.6, Speed = 0.6 } },
	DirectorFast = { { Id = L.WhooshBurst, Volume = 0.6, Speed = 1.3, Length = 0.4, Fade = 0.15 } },
	DirectorNo = { { Id = S.Negative, Volume = 0.45 } },
	-- KO + interface (played flat, not in the world)
	KO = { Range = 500, { Id = L.BodyFall, Volume = 1.85, Speed = 0.9, Length = 1 }, { Id = L.CrackThud, Volume = 1.85, Speed = 0.8, Length = 0.6 }, { Id = L.SubBoom, Volume = 1.85, Speed = 0.7 } },
	KOConfirm = { { Id = S.Stinger, Volume = 1.2 }, { Id = L.CrackyPunch, Volume = 0.96, Speed = 0.6, Length = 0.4 } },
	Streak = { { Id = S.Victory, Volume = 0.7 } },
	RankUp = { { Id = S.Victory, Volume = 0.9 }, { Id = S.Stinger, Volume = 0.7, Speed = 1.25, Delay = 0.12 } }, -- a new hero rank
	-- (round 95) RANKED DUELS: the VS card, each round, FIGHT (the Sports
	-- Festival crowd), a win
	RankedFound = { { Id = S.Stinger, Volume = 1 }, { Id = S.Ping, Volume = 0.6, Speed = 0.8, Delay = 0.1 } },
	RankedRound = { { Id = S.Ping, Volume = 0.8, Speed = 1.2 } },
	RankedFight = { { Id = S.Stinger, Volume = 0.9, Speed = 1.1 }, { Id = L.CrowdRoar, Volume = 0.7, Speed = 1, Length = 2.5 } },
	RankedWin = { { Id = S.Victory, Volume = 1 }, { Id = L.CrowdWhoops, Volume = 0.6, Speed = 1, Delay = 0.2, Length = 2.5 } },
	-- (round 96) DISMANTLE: armed (a blade drawn), the cut (a thin metal
	-- shing through the air, the edge's ring after it), the top grinding off
	-- down the cut, the crash, and a body the cut goes through
	DismantleArm = { { Id = L.BladeScrape, Volume = 0.45, Speed = 1.4, Length = 0.6 } },
	DismantleCut = {
		{ Id = L.SwordShing, Volume = 1, Speed = 1.1 },
		{ Id = L.AirySlice, Volume = 0.9, Speed = 0.9 },
		{ Id = L.BladeRing, Volume = 0.55, Speed = 1.2, Delay = 0.05, Length = 1.4 },
		Range = 900,
	},
	DismantleSlide = { { Id = L.StoneGrind, Volume = 1, Speed = 0.7, Length = 2.5 }, { Id = L.Quake, Volume = 0.7, Speed = 0.9, Length = 2.5 }, Range = 700 },
	DismantleImpact = {
		{ Id = L.PowerBoomLong, Volume = 1, Speed = 0.85 },
		{ Id = L.DirtBurst, Volume = 0.9, Speed = 0.9, Delay = 0.05 },
		{ Id = L.Quake, Volume = 0.8, Speed = 0.8, Length = 3 },
		{ Id = L.GlassSmash, Volume = 0.5, Speed = 0.9, Delay = 0.1 },
		Range = 1100,
	},
	DismantleHit = { { Id = L.SwordShing, Volume = 0.8, Speed = 1.3 }, { Id = L.CrackThud, Volume = 0.6, Speed = 1.1 } },
	-- (round 86) the roster switch: a hero released to everyone (the NEW HERO
	-- banner), your hero pulled back to DEV ONLY, a switch flipped on the panel.
	-- (review) The release is a debut, not a rank-up (RankUp is Victory +
	-- Stinger): a rush up, a low hit as the banner lands, the press cameras'
	-- flashbulb, the tonal sting, and a power-up shimmer under the sparks.
	RosterRelease = {
		{ Id = L.AscendWhoosh, Volume = 1.3, Speed = 1.15 },
		{ Id = L.SubBoom, Volume = 1.1, Speed = 0.95, Delay = 0.1 },
		{ Id = S.Flash, Volume = 0.9, Speed = 1.05, Delay = 0.12 },
		{ Id = S.Stinger, Volume = 0.75, Speed = 1.12, Delay = 0.18 },
		{ Id = L.PowerUp, Volume = 0.9, Speed = 1.3, Delay = 0.26, Length = 0.9 },
	},
	RosterPulled = { { Id = S.Negative, Volume = 0.8, Speed = 0.9 }, { Id = S.Ping, Volume = 0.3, Speed = 0.7, Delay = 0.1, Length = 0.5 } },
	RosterToggle = { { Id = L.SwordTick, Volume = 0.42, Speed = 2.4, Length = 0.15 }, { Id = S.Ping, Volume = 0.22, Speed = 1.9, Length = 0.25 } },
	-- (round 92) FLIGHTGRANT (only ids already in S / L): the dev flight given
	-- to you - a rush up, the cape's snap, a gust, the power-up shimmer and a
	-- bright ping; taken back - a suck-out into a soft low hit
	FlightGranted = {
		{ Id = L.AscendWhoosh, Volume = 1.1, Speed = 1.1 },
		{ Id = L.CapeSnap, Volume = 0.8, Speed = 1.1, Delay = 0.12, Length = 0.6, Fade = 0.2 },
		{ Id = L.FlyGust, Volume = 0.7, Speed = 1.15, Delay = 0.1, Length = 1.6, Fade = 0.8 },
		{ Id = L.PowerUp, Volume = 0.8, Speed = 1.35, Delay = 0.22, Length = 0.9 },
		{ Id = S.Ping, Volume = 0.3, Speed = 1.4, Delay = 0.3, Length = 0.5 },
	},
	FlightRevoked = {
		{ Id = L.SuckShort, Volume = 0.8, Speed = 1.05 },
		{ Id = S.Negative, Volume = 0.6, Speed = 0.95, Delay = 0.3 },
		{ Id = L.BoomThump, Volume = 0.5, Delay = 0.42, Length = 1, Fade = 0.6 },
	},
	-- (round 87) ADMIN EVENTS (Config.AdminEvents; only ids already in S / L).
	-- The banner: a sweep up into a hit as the name slams in (SweepHit's
	-- hit is 0.6 s after it starts), the low boom and the tonal sting on
	-- it, the crowd going up. EVENT OVER: a suck-out into a soft low hit.
	-- The chip's last seconds tick. The meteors: the fiery fall, the impact
	-- (a searing boom, rock bursting, the debris, a rolling tail). A bill
	-- grabbed (coins). HERO SHUFFLE's reel (a tick a hero) and its jackpot.
	-- A body growing / shrinking, a giant's footfall, gravity letting go.
	AdminEventStart = {
		{ Id = L.SweepHit, Volume = 1 },
		{ Id = L.SubBoom, Volume = 1.3, Speed = 0.85, Delay = 0.58 },
		{ Id = L.DeepImpact, Volume = 0.9, Delay = 0.58, Length = 2.2, Fade = 1.2 },
		{ Id = S.Stinger, Volume = 0.85, Speed = 0.95, Delay = 0.62 },
		{ Id = L.CrowdWhoops, Volume = 0.5, Delay = 0.8, Length = 2.4, Fade = 1 },
	},
	AdminEventOver = {
		{ Id = L.SuckShort, Volume = 0.9, Speed = 1.1 },
		{ Id = L.BoomThump, Volume = 0.8, Delay = 0.48, Length = 1.4, Fade = 0.8 },
		{ Id = S.Ping, Volume = 0.3, Speed = 0.8, Delay = 0.5, Length = 0.6 },
	},
	AdminEventTick = { { Id = L.SwordTick, Volume = 0.35, Speed = 2.8, Length = 0.12 }, { Id = S.Ping, Volume = 0.18, Speed = 2.2, Length = 0.2 } },
	AdminMeteorFall = { Range = 700, Gap = 0.08, { Id = L.FlyHyperBed, Volume = 1.2, Speed = { 1.1, 1.3 }, Length = 1.25, Fade = 0.35 }, { Id = L.FireWhoosh, Volume = 1, Speed = 0.7, Length = 1 } },
	AdminMeteorImpact = {
		Range = 900,
		Gap = 0.06,
		{ Id = L.PowerBoom, Volume = 1.5, Speed = { 0.8, 0.95 } },
		{ Id = L.RockBurst, Volume = 1.2, Length = 1.6, Fade = 0.6 },
		{ Id = L.DebrisImpact, Volume = 1, Delay = 0.08 },
		{ Id = L.BigBoomTail, Volume = 0.8, Length = 2.5, Fade = 1.5 },
	},
	AdminBillGrab = { { Id = L.CoinThrow, Volume = 1.1, Speed = 1.25 }, { Id = S.Ping, Volume = 0.35, Speed = 1.7 } },
	AdminReelTick = { Gap = 0.03, { Id = L.SwordTick, Volume = 0.3, Speed = { 3, 3.4 }, Length = 0.08 } },
	AdminReelLand = { { Id = S.Stinger, Volume = 1, Speed = 1.15 }, { Id = L.PowerHit, Volume = 0.8, Speed = 1.1 }, { Id = L.CoinDrop, Volume = 1, Delay = 0.05 } },
	AdminGrow = { Range = 300, { Id = L.PowerUp, Volume = 0.9, Speed = 0.8, Length = 1.2, Fade = 0.5 }, { Id = L.GiantStep, Volume = 1.2, Delay = 0.35 } },
	AdminShrink = { Range = 300, { Id = L.SuckShort, Volume = 0.8, Speed = 1.5 }, { Id = L.BalloonPop, Volume = 0.5, Speed = 1.6, Delay = 0.3 } },
	AdminGiantStep = { Range = 260, Gap = 0.05, { Id = L.GiantStep, Volume = 1.1, Speed = { 0.9, 1.05 } } },
	AdminGravity = { { Id = L.SuckIn, Volume = 0.8, Speed = 0.8 }, { Id = L.AscendWhoosh, Volume = 1, Speed = 0.7, Delay = 0.3 } },
	Knocked = { { Id = S.Negative, Volume = 0.9, Speed = 0.8 }, { Id = S.Stinger, Volume = 0.6, Speed = 0.7 } },
	-- bucks + shop
	Bucks = { { Id = L.CoinThrow, Volume = 1.3, Speed = 1.1 }, { Id = S.Ping, Volume = 0.5, Speed = 1.5 } },
	Purchase = { { Id = L.CoinThrow, Volume = 1.2 }, { Id = S.Stinger, Volume = 0.5, Speed = 1.6 } },
	ShopNo = { { Id = S.Negative, Volume = 0.8 } },
	-- (round 89) the JOIN THE DISCORD card coming up (Config.Discord): a soft tick and ping
	DiscordCard = { { Id = S.Ping, Volume = 0.32, Speed = 1.45, Length = 0.35 }, { Id = L.SwordTick, Volume = 0.26, Speed = 2.6, Length = 0.12 } },
	-- items
	Soda = { { Id = L.CanPop, Volume = 1.6, Speed = 1.8 }, { Id = L.Gulp, Volume = 1.6, Delay = 0.25 }, { Id = S.Ping, Volume = 0.4, Speed = 0.9, Delay = 0.8 } },
	SniperScope = { { Id = L.SwordTick, Volume = 0.8, Speed = 2.2 } },
	SniperShot = {
		Range = 1400,
		{ Id = L.RifleShot, Volume = 2.2, Speed = { 0.95, 1.05 } },
		{ Id = L.SubBoom, Volume = 0.9, Speed = 1.3 },
	},
	SniperHit = { { Id = L.CrackyPunch, Volume = 1.2, Speed = 1.2, Length = 0.3 } },
	BombThrow = { { Id = L.SwishLarge, Volume = 1.1, Speed = 1.2 } },
	BombBoom = {
		Range = 1000,
		{ Id = L.ExplosionCrack, Volume = 1.8 },
		{ Id = L.PowerBoom, Volume = 1.4, Speed = 1.1 },
		{ Id = L.DebrisImpact, Volume = 1, Delay = 0.1 },
	},
	HairPoof = { { Id = L.BalloonPop, Volume = 1.4, Speed = 0.8 }, { Id = S.Flash, Volume = 0.6 } },
	Trigger = { { Id = L.PowerUp, Volume = 2.2, Speed = 1.2 }, { Id = L.Zap, Volume = 1.2, Delay = 0.15 } },
	Scarf = { { Id = L.WhooshSwishBy, Volume = 1.2, Speed = 1.3 }, { Id = L.SwishThin, Volume = 1, Speed = 0.8, Delay = 0.1 } },
	Erased = { { Id = S.Negative, Volume = 1, Speed = 0.6 }, { Id = L.SuckShort, Volume = 2, Speed = 1.6, Length = 0.4 } },
	GrapeDrop = { { Id = L.CanPop, Volume = 1.4, Speed = 0.7 } },
	GrapeStick = { { Id = L.JuicySplat, Volume = 1.2, Speed = 1.3 }, { Id = L.CanPop, Volume = 1.2, Speed = 0.6 } },
	ZeroG = { { Id = L.AscendWhoosh, Volume = 1.6 }, { Id = S.Aura, Volume = 0.8, Speed = 1.2 } },
	-- food
	Crunch = { { Id = L.ChipBag, Volume = 2.4 }, { Id = L.AppleChew, Volume = 1.4, Delay = 0.2, Length = 0.8 } },
	Munch = { { Id = L.Wrapper, Volume = 1.4 }, { Id = L.BagelBite, Volume = 1.6, Delay = 0.15 }, { Id = L.AppleChew, Volume = 1.2, Delay = 0.35, Length = 0.7 } },
	Feast = {
		{ Id = L.BagelBite, Volume = 1.6 }, { Id = L.AppleChew, Volume = 1.4, Delay = 0.25, Length = 0.8 },
		{ Id = L.Burp, Volume = 1.3, Delay = 1 },
	},
	-- SUNEATER: the wet crackle of a body reshaping, a tentacle lash, a claw
	-- closing, a snack wolfed down, the Kraken's roar, the Centaur's hooves
	Manifest = { { Id = L.FleshReshape, Volume = 1.6, Speed = { 0.95, 1.1 } }, { Id = L.QuirkCrackle, Volume = 0.8, Speed = 1.2, Length = 0.5 } },
	Tentacle = { { Id = L.SwishThin, Volume = 1.4, Speed = { 0.8, 0.95 } }, { Id = L.JuicySplat, Volume = 0.9, Speed = 1.2, Delay = 0.08, Length = 0.4 } },
	-- the chicken leg's kick up; a tentacle slamming someone into the street;
	-- the swordfish bill going in
	ChickenKick = { { Id = L.WhooshSwishBy, Volume = 1.3, Speed = 0.9 }, { Id = L.BeefyHit, Volume = 1.6, Delay = 0.1 }, { Id = L.AscendWhoosh, Volume = 1.1, Delay = 0.12, Length = 0.8 } },
	TentacleSlam = { Range = 300, { Id = L.BodyImpact, Volume = 1.7, Speed = { 0.9, 1.05 } }, { Id = L.MeatyThud, Volume = 1.4 }, { Id = L.DebrisImpact, Volume = 1, Length = 0.6 } },
	Impale = { { Id = L.MetalSwoosh, Volume = 1.3 }, { Id = L.JuicySplat, Volume = 1.5, Delay = 0.06 }, { Id = L.BodyHit, Volume = 1.2, Delay = 0.06 } },
	ClawCrush = { { Id = L.BoneSnap, Volume = 1.8, Speed = { 0.95, 1.05 }, Length = 0.4 }, { Id = L.MeatyThud, Volume = 1.6 }, { Id = L.CrackyPunch, Volume = 1.2, Speed = 0.8, Length = 0.3 } },
	Snack = { { Id = L.BagelBite, Volume = 1.6 }, { Id = L.AppleChew, Volume = 1.3, Delay = 0.2, Length = 0.7 }, { Id = L.Gulp, Volume = 1.4, Delay = 0.65 } },
	Kraken = { Range = 700, { Id = L.MonsterRoar, Volume = 1.6, Speed = 0.8, Length = 1.8 }, { Id = L.WindRoar, Volume = 1.2, Speed = 0.8, Length = 1.4 }, { Id = L.FleshReshape, Volume = 1.8, Speed = 0.7 } },
	Centaur = { Range = 600, { Id = L.BeastRumble, Volume = 1.6, Speed = 0.9, Length = 1.4 }, { Id = L.GiantStep, Volume = 1.6, Speed = 1.2 }, { Id = L.GiantStep, Volume = 1.4, Speed = 1.3, Delay = 0.18 } },
	Sting = { { Id = L.EnergySnap, Volume = 1.2, Speed = 1.4, Length = 0.3 }, { Id = L.JuicySplat, Volume = 1.3, Speed = 0.9 } },
	PlasmaCharge = { Range = 800, { Id = L.PowerUp, Volume = 1.8, Speed = 0.9, Length = 1.4 }, { Id = L.EnergyGrowl, Volume = 1.2, Speed = 0.9, Length = 1.2 }, { Id = L.FleshReshape, Volume = 1.6, Speed = 0.8 } },
	PlasmaFire = { Range = 1600, { Id = L.PowerBoomLong, Volume = 2, Speed = 1.1 }, { Id = L.ExplosionCrack, Volume = 1.4, Speed = 1.1, Length = 1.2 }, { Id = L.EnergySnap, Volume = 1.2, Speed = 0.8, Length = 0.6 } },
	Vend = { { Id = L.CoinDrop, Volume = 1.8 }, { Id = S.Hit, Volume = 0.6, Speed = 1.6, Delay = 0.5 } },
	MachineHit = { { Id = S.Collide, Volume = 0.7, Speed = 1.4 }, { Id = L.SwordTick, Volume = 0.5, Speed = 0.7 } },
	Bell = { { Id = S.Ping, Volume = 0.7, Speed = 1.2 } },
	-- PLUS ULTRA (dev kit)
	MillionCharge = {
		Range = 1200,
		{ Id = L.SuckIn, Volume = 4, Speed = 0.8, Length = 1.4 },
		{ Id = L.Static, Volume = 1.5, Speed = 0.8 },
		{ Id = L.EnergyGrowl, Volume = 1.8, Speed = 0.7, Delay = 0.3 },
	},
	MillionSmash = {
		Range = 2400,
		{ Id = L.WindBlast, Volume = 2.4, Speed = 0.8, Length = 3 },
		{ Id = L.PowerBoomLong, Volume = 2.2, Speed = 0.75, Length = 3 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.6 },
		{ Id = L.WindRoar, Volume = 1.8, Speed = 0.9, Delay = 0.2, Length = 3 },
	},
	Prominence = {
		Range = 1600,
		{ Id = L.FireBurst, Volume = 2.2, Speed = 0.7 },
		{ Id = L.FireWhoosh, Volume = 2, Speed = 0.6, Length = 2 },
		{ Id = L.PowerBoom, Volume = 1.6, Speed = 0.8 },
		{ Id = L.FlameLick, Volume = 1.4, Speed = 0.8, Delay = 0.3 },
	},
	WarpGate = { { Id = L.SuckShort, Volume = 3, Speed = 0.7, Length = 0.6 }, { Id = L.HowlingWind, Volume = 1, Speed = 1.4, Length = 0.8 } },
	Rewind = { { Id = L.SuckIn, Volume = 3, Speed = 1.4, Length = 0.8 }, { Id = S.Stinger, Volume = 0.8, Speed = 1.3, Delay = 0.3 } },
	NewOrder = {
		Range = 1400,
		{ Id = S.Stinger, Volume = 1, Speed = 0.8 },
		{ Id = L.AscendWhoosh, Volume = 2, Speed = 0.8 },
		{ Id = L.PowerUp, Volume = 1.5, Speed = 0.7 },
	},
	NewOrderSlam = { Range = 1400, { Id = L.BoomThump, Volume = 2 }, { Id = L.Quake, Volume = 1.6 }, { Id = L.SubBoom, Volume = 1.6, Speed = 0.7 } },
	-- LEMILLION: sinking through the street, popping back out of it
	PhaseSink = { { Id = L.SuckShort, Volume = 2.2, Speed = 1.25, Length = 0.5 }, { Id = L.DebrisMove, Volume = 0.8, Speed = 1.2, Length = 0.5 } },
	PhaseOut = {
		{ Id = L.DirtBurst, Volume = 1.4, Speed = { 1, 1.15 }, Length = 0.6 },
		{ Id = L.AscendWhoosh, Volume = 1.2, Speed = 1.3, Length = 0.6 },
		{ Id = L.RockBurst, Volume = 0.8, Speed = 1.1, Length = 0.6 },
	},
	PhantomBlink = { { Id = L.WhooshBurst, Volume = 0.9, Speed = { 1.35, 1.5 }, Length = 0.4 }, { Id = L.SuckShort, Volume = 1.2, Speed = 1.6, Length = 0.3 } },
	Permeate = { { Id = L.SuckIn, Volume = 2, Speed = 1.5, Length = 0.7 }, { Id = S.Stinger, Volume = 0.5, Speed = 1.5 } },
	-- R in the air: he lets go and drops through everything; the ground spits him out
	PhaseDive = { { Id = L.SuckIn, Volume = 2, Speed = 1.2, Length = 0.8 }, { Id = L.WhooshBurst, Volume = 1, Speed = 0.8, Length = 0.6 } },
	PhaseSpit = {
		Range = 400,
		{ Id = L.RockBurst, Volume = 1.6, Speed = 0.9, Length = 0.8 },
		{ Id = L.DeepBlast, Volume = 1.2, Speed = 1.2, Length = 0.8 },
		{ Id = L.AscendWhoosh, Volume = 1.4, Speed = 1.1, Length = 0.7, Delay = 0.05 },
	},
	-- TODOROKI's JET KINDLING: the flame jet, then the white-hot fist going off
	JetKindling = { { Id = L.JetPass, Volume = 1.4, Speed = 1.3, Length = 0.6 }, { Id = L.FireWhoosh, Volume = 1.8, Speed = 1.1, Length = 0.7 } },
	JetKindlingBlast = {
		Range = 500,
		{ Id = L.PowerBoom, Volume = 1.6, Speed = 1.05 },
		{ Id = L.FireBurst, Volume = 2, Speed = 0.9, Length = 1 },
		{ Id = L.BodyImpact, Volume = 1.2, Speed = 0.9, Length = 0.5 },
		{ Id = L.FlameLick, Volume = 1.6, Speed = 0.8, Length = 1.2, Delay = 0.1 },
	},
	CounterReady = { { Id = L.SwordTick, Volume = 0.9, Speed = 0.8 }, { Id = L.SwishThin, Volume = 0.6, Speed = 0.7 } },
	CounterTrigger = {
		{ Id = L.SwordClash, Volume = 1.1, Speed = 1.4, Length = 0.5 },
		{ Id = L.SuckShort, Volume = 2.2, Speed = 1.1, Length = 0.5 },
		{ Id = S.Stinger, Volume = 0.8, Speed = 1.2 },
	},
	-- Suneater's Vast Hybrid Chimera: the body reshaping, a sea creature's roar
	UltManifest = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 0.95 },
		{ Id = L.FleshReshape, Volume = 2.2, Speed = 0.8 },
		{ Id = L.MonsterRoar, Volume = 1.4, Speed = 0.9, Delay = 0.15, Length = 1.6 },
		{ Id = L.PowerUp, Volume = 1.4, Speed = 0.8, Delay = 0.05 },
	},
	-- UNO: a card slapped down; a win
	UnoCard = { Gap = 0.05, { Id = S.Swoosh, Volume = 0.6, Speed = { 1.5, 1.8 }, Length = 0.3 }, { Id = S.Snap, Volume = 0.3, Speed = 1.4 } },
	UnoWin = { { Id = S.Victory, Volume = 0.9 }, { Id = S.Stinger, Volume = 0.6, Speed = 1.2, Delay = 0.1 } },
	-- KAMUI WOODS: timber everywhere - snaps, creaks, splinters, trunks coming down
	Arbor = { Gap = 0.05, { Id = L.BranchSnap, Volume = 1.2, Speed = { 0.9, 1.1 } }, { Id = L.WoodCreak, Volume = 0.6, Speed = 1.2, Length = 0.4 } },
	BranchShoot = { Gap = 0.05, { Id = L.BranchThrash, Volume = 1.3, Speed = { 1.1, 1.25 }, Length = 0.6 }, { Id = L.BranchSnap, Volume = 1, Speed = { 0.95, 1.1 } } },
	WoodBind = { { Id = L.WoodCrack, Volume = 1.5, Speed = 1, Length = 0.8 }, { Id = L.WoodCreak, Volume = 1.1, Speed = 0.9, Delay = 0.05, Length = 1 } },
	WoodCrush = { Range = 500, { Id = L.WoodSplinter, Volume = 1.6, Speed = 0.95, Length = 0.9 }, { Id = L.CrackThud, Volume = 1.6, Speed = 0.8, Length = 0.5 } },
	StakeBurst = { Range = 500, { Id = L.WoodCrack, Volume = 1.5, Speed = { 0.85, 1 }, Length = 0.7 }, { Id = L.RockCrack, Volume = 1.2, Speed = 1.1, Length = 0.5 } },
	TrunkSlam = {
		Range = 900,
		{ Id = L.WoodCrash, Volume = 1.8, Speed = 0.85, Length = 1.4 },
		{ Id = L.TreeSlap, Volume = 1.6, Speed = 0.8 },
		{ Id = L.SubBoom, Volume = 1.4, Speed = 0.8 },
		{ Id = L.RockCrack, Volume = 1.2, Speed = 0.8, Delay = 0.05, Length = 0.8 },
	},
	BranchSwing = { Gap = 0.1, { Id = L.BranchThrash, Volume = 1.2, Speed = 1.3, Length = 0.5 }, { Id = L.WoodCreak, Volume = 0.9, Speed = 1.4, Delay = 0.1, Length = 0.6 } },
	LogRoll = { Range = 900, { Id = L.WoodClunk, Volume = 1.6, Speed = { 0.8, 0.95 }, Length = 0.8 }, { Id = L.TreeBreak, Volume = 1.4, Speed = 0.9, Length = 1.4 }, { Id = S.Rumble, Volume = 1, Speed = 1.2, Length = 1.4 } },
	TreeBurst = {
		Range = 1200,
		{ Id = L.TreeDestruction, Volume = 1.8, Speed = 1, Length = 2 },
		{ Id = L.WoodSplinter, Volume = 1.6, Speed = 0.8, Length = 1 },
		{ Id = L.SubBoom, Volume = 1.6, Speed = 0.7 },
	},
	UltArbor = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1 },
		{ Id = L.TreeDestruction, Volume = 1.6, Speed = 1.1, Length = 1.8 },
		{ Id = L.WoodCreak, Volume = 1.4, Speed = 0.8, Delay = 0.1, Length = 1.4 },
		{ Id = L.PowerUp, Volume = 1.4, Speed = 0.85, Delay = 0.05 },
	},
	-- MR. COMPRESS: things shrinking into marbles (a suck and a glassy ping)
	-- and popping back out (a boom), his cane, rubble landing, the crowd
	Compress = { Gap = 0.05, { Id = L.SuckShort, Volume = 1.1, Speed = { 1.2, 1.4 } }, { Id = S.Ping, Volume = 0.7, Speed = 1.6, Delay = 0.12 } },
	Decompress = { Range = 500, { Id = L.BalloonPop, Volume = 1.2, Speed = 0.8 }, { Id = L.PowerBoom, Volume = 1.1, Speed = 1.2, Length = 0.6 } },
	MarblePop = { { Id = L.BalloonPop, Volume = 0.9, Speed = 1.1 }, { Id = L.RockCrack, Volume = 0.8, Speed = 1.3, Length = 0.4 } },
	MarbleThrow = { { Id = L.SwishThin, Volume = 0.8, Speed = 1.3, Length = 0.3 }, { Id = S.Ping, Volume = 0.4, Speed = 2 } },
	CaneHit = { Gap = 0.05, { Id = L.WoodClunk, Volume = 1.2, Speed = 1.3, Length = 0.3 }, { Id = L.CrackyPunch, Volume = 1, Speed = 1.1 } },
	RubbleLand = { Range = 700, { Id = L.RockBurst, Volume = 1.5, Speed = 0.9, Length = 0.8 }, { Id = L.DebrisImpact, Volume = 1.3, Speed = 1 }, { Id = L.SubBoom, Volume = 1.2, Speed = 0.9 } },
	UltCompress = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1.1 },
		{ Id = L.CrowdWhoops, Volume = 1.2, Speed = 1, Delay = 0.15, Length = 1.6 },
		{ Id = L.PowerUp, Volume = 1.3, Speed = 1 },
	},
	-- CHARGEBOLT: static, zaps, thunder
	StaticCrackle = { Gap = 0.04, { Id = L.Static, Volume = 0.9, Speed = { 1, 1.3 }, Length = 0.5 } },
	ElectricZap = { Gap = 0.04, { Id = L.Zap, Volume = 1.1, Speed = { 0.95, 1.25 }, Length = 0.5 }, { Id = L.Static, Volume = 0.6, Speed = 1.4, Length = 0.3 } },
	Discharge = { Range = 700, { Id = L.Zap, Volume = 1.5, Speed = 0.8, Length = 0.9 }, { Id = S.Thunder, Volume = 1, Speed = 1.3, Length = 1 }, { Id = L.PowerBoom, Volume = 1.1, Speed = 1.1, Length = 0.6 } },
	PointerShot = { { Id = L.RifleShot, Volume = 0.6, Speed = 1.6, Length = 0.3 }, { Id = S.Ping, Volume = 0.5, Speed = 1.3, Delay = 0.05 } },
	PointerStick = { { Id = S.Snap, Volume = 0.8, Speed = 1.2 }, { Id = L.Static, Volume = 0.5, Speed = 1.5, Length = 0.3 } },
	Thunderbolt = { Range = 1200, { Id = S.Thunder, Volume = 1.6, Speed = 1, Length = 1.4 }, { Id = L.Zap, Volume = 1.3, Speed = 0.7, Length = 0.8 }, { Id = L.SubBoom, Volume = 1.2, Speed = 0.9 } },
	UltElectrification = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1 },
		{ Id = L.Static, Volume = 1.5, Speed = 0.8, Length = 1.6 },
		{ Id = L.PowerUp, Volume = 1.4, Speed = 1.05, Delay = 0.05 },
		{ Id = S.Thunder, Volume = 1.1, Speed = 1.2, Delay = 0.2 },
	},
	Wheey = { { Id = S.Oof, Volume = 0.8, Speed = 1.3 }, { Id = L.Static, Volume = 0.6, Speed = 0.7, Length = 0.8 } },
	-- (round 85) the SHORT CIRCUIT emote's bolt: Thunderbolt's crack, heard
	-- down the street rather than across the map (a taunt, not the ult)
	EmoteThunder = { Range = 150, { Id = S.Thunder, Volume = 0.75, Speed = 1.15, Length = 1 }, { Id = L.Zap, Volume = 0.6, Speed = 0.8, Length = 0.6 } },
	-- (round 92) the new emotes' sounds (made of the game's own takes; heard
	-- a street away, not across the map)
	-- SEAN O'PRY: the finger snap (a short crack, pitched up), the mango
	-- going wrong, and the laugh track that overhypes it
	EmoteSnap = { Range = 150, { Id = S.Snap, Volume = 0.9, Speed = { 1.9, 2.1 }, Length = 0.25 }, { Id = L.SwishThin, Volume = 0.35, Speed = 2.2, Length = 0.15 } },
	EmoteSplat = { Range = 120, { Id = L.JuicySplat, Volume = 1.2, Speed = { 1.1, 1.3 }, Length = 0.6 } },
	EmoteCrowd = { Range = 150, { Id = L.CrowdWhoops, Volume = 0.8, Speed = 1, Length = 2.4 } },
	-- FINAL FORM: the power building (and the ground rumbling), then going off
	EmotePowerUp = { Range = 160, { Id = L.PowerUp, Volume = 1.6, Speed = 0.8, Length = 2.2 }, { Id = L.Quake, Volume = 0.8, Speed = 0.7, Length = 2.2 } },
	EmotePowerBurst = { Range = 180, { Id = L.EnergySnap, Volume = 1.4, Speed = 0.8, Length = 1 }, { Id = L.SubBoom, Volume = 1.3, Speed = 0.7, Length = 1.4 }, { Id = L.Zap, Volume = 0.8, Speed = 0.9, Length = 0.6 } },
	-- MIC DROP: the thud and the speakers whining
	EmoteMicDrop = { Range = 160, { Id = L.BoomThump, Volume = 1.6, Speed = 0.8, Length = 1 }, { Id = L.WoodClunk, Volume = 0.5, Speed = 1.8, Length = 0.2 }, { Id = S.Ping, Volume = 0.3, Speed = 2.6, Delay = 0.05, Length = 0.9 } },
	-- TUNG SAHUR: the bat on the street - a hollow wooden knock
	EmoteWoodKnock = { Range = 140, Gap = 0.05, { Id = L.WoodClunk, Volume = 1.2, Speed = { 0.95, 1.1 }, Length = 0.35 }, { Id = L.BranchSnap, Volume = 0.3, Speed = 1.4, Length = 0.15 } },
	UltLemillion = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1.05 },
		{ Id = L.PowerUp, Volume = 1.6, Speed = 0.9 },
		{ Id = L.AscendWhoosh, Volume = 1.6, Speed = 0.9, Delay = 0.1 },
	},
	MillionPunch = {
		Range = 1400,
		{ Id = L.PowerHit, Volume = 2, Speed = 0.8 },
		{ Id = L.BoomThump, Volume = 2, Speed = 0.85 },
		{ Id = L.Quake, Volume = 1.8, Speed = 0.9, Length = 1.6 },
		{ Id = L.SubBoom, Volume = 1.8, Speed = 0.7 },
	},
	-- CRAZY DIAMOND: every rush punch is a dry crack, the last one a boom;
	-- restoration is things rushing backwards into place with a bright snap
	Dora = { Range = 300, { Id = L.CrackyPunch, Volume = 1.1, Speed = { 1.15, 1.35 }, Length = 0.22 }, { Id = L.SwishThin, Volume = 0.8, Speed = { 1.3, 1.5 }, Length = 0.15 } },
	DoraFinish = {
		Range = 800,
		{ Id = L.CrackyPunch, Volume = 1.6, Speed = 0.8, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 1.5, Speed = 0.9 },
		{ Id = L.WindBlast, Volume = 0.8, Speed = 1.1, Length = 1.2 },
	},
	StandOn = { { Id = L.SuckShort, Volume = 2.2, Speed = 1.5, Length = 0.4 }, { Id = L.EnergySnap, Volume = 1, Speed = 1.3 } },
	GroundPunch = {
		Range = 500,
		{ Id = L.CrackyPunch, Volume = 1.3, Speed = 0.85, Length = 0.4 },
		{ Id = L.BoulderCrack, Volume = 1.3, Speed = 1 },
		{ Id = L.DirtBurst, Volume = 1, Speed = 1.1, Length = 0.6 },
	},
	Rebuild = {
		Range = 600,
		{ Id = L.StoneGrind, Volume = 1.6, Speed = 1.1, Length = 0.9 },
		{ Id = L.DebrisMove, Volume = 1.3, Speed = 1.2, Length = 0.8 },
		{ Id = L.RockCrack, Volume = 1, Speed = 1.3, Length = 0.6, Delay = 0.3 },
	},
	RestoreSnap = {
		Range = 800,
		{ Id = L.SuckIn, Volume = 2.4, Speed = 1.6, Length = 0.6 },
		{ Id = L.PowerHit, Volume = 1.1, Speed = 1.4, Delay = 0.35 },
		{ Id = L.StoneGrind, Volume = 1, Speed = 1.4, Length = 0.5, Delay = 0.1 },
	},
	CDShatter = {
		Range = 1400,
		{ Id = L.PowerHit, Volume = 2, Speed = 0.8 },
		{ Id = L.BoulderCrack, Volume = 2, Speed = 0.8 },
		{ Id = L.RockBurst, Volume = 1.6, Speed = 0.95, Length = 2 },
		{ Id = L.SubBoom, Volume = 1.8, Speed = 0.7 },
	},
	UltCrazyDiamond = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1.1 },
		{ Id = L.EnergyGrowl, Volume = 1.6, Speed = 0.9, Length = 1 },
		{ Id = L.PowerUp, Volume = 1.4, Speed = 1.1 },
	},
	-- (round 60) CREATI (Momo Yaoyorozu): something coming out of her skin (a
	-- bright shimmer and a ring of steel), her weapons, the cannons, the
	-- matryoshka flashbangs, the shield taking hits, the railgun
	Create = { Gap = 0.05, { Id = L.SuckShort, Volume = 0.9, Speed = { 1.5, 1.7 }, Length = 0.35 }, { Id = S.Ping, Volume = 0.45, Speed = { 1.9, 2.1 }, Delay = 0.1 }, { Id = S.Ring, Volume = 0.6, Speed = 1.3, Delay = 0.12, Length = 0.5 } },
	CreateBig = { Range = 500, { Id = L.PowerUp, Volume = 1.2, Speed = 1.3, Length = 0.8 }, { Id = L.StoneGrind, Volume = 0.9, Speed = 1.4, Length = 0.5 }, { Id = S.Ring, Volume = 0.8, Speed = 0.9, Delay = 0.15 } },
	WeaponSwing = { { Id = L.SwishLarge, Volume = 1.2, Speed = { 1.05, 1.2 } }, { Id = L.MetalSwoosh, Volume = 0.5, Speed = 1.2, Length = 0.3 } },
	WeaponHit = { Gap = 0.04, { Id = L.SwordClash, Volume = 0.8, Speed = { 1.1, 1.3 }, Length = 0.3 }, { Id = L.CrackyPunch, Volume = 1, Speed = 1.05 } },
	-- (round 62) Creati's three weapons each sound like what they are
	-- (VFX.WeaponKit): the swing, the 4th hit's swing, what a landed hit adds
	SwordSwing = { { Id = L.SwordWhip, Volume = 0.9, Speed = { 1.05, 1.2 }, Length = 0.45 }, { Id = L.SwordSwish, Volume = 0.7, Speed = { 1.1, 1.25 } } },
	SwordHeavy = { { Id = L.SwordWhip, Volume = 1.1, Speed = { 0.9, 1 }, Length = 0.6 }, { Id = L.SwishLarge, Volume = 0.7, Speed = 1.05 } },
	SwordHit = { { Id = L.SwordStab, Volume = 0.8, Speed = { 1.05, 1.2 }, Length = 0.35 }, { Id = L.BladeImpact, Volume = 0.35, Speed = { 1.3, 1.5 }, Length = 0.15 } },
	SwordRing = { { Id = L.BladeRing, Volume = 0.45, Speed = 1.15, Length = 1.3 } },
	SwordDraw = { { Id = L.SwordUnsheath, Volume = 0.9, Speed = { 1, 1.1 } }, { Id = L.BladeScrape, Volume = 0.5, Speed = 1.3, Length = 0.35 } },
	StaffSwing = { { Id = L.StaffWhoosh, Volume = 1.1, Speed = { 0.85, 0.95 }, Length = 0.5 }, { Id = L.SwishLarge, Volume = 0.6, Speed = { 0.8, 0.9 } } },
	StaffHeavy = { { Id = L.GiantSwish, Volume = 0.8, Speed = 1.2, Length = 0.6 }, { Id = L.StaffWhoosh, Volume = 1, Speed = 0.75 } },
	StaffHit = { { Id = L.WoodClunk, Volume = 1.3, Speed = { 1.15, 1.3 }, Length = 0.45 }, { Id = L.CrackyPunch, Volume = 0.8, Speed = 1.1 } },
	StaffSlam = {
		{ Id = L.WoodClunk, Volume = 1.5, Speed = 0.9, Length = 0.7 },
		{ Id = L.SubBoom, Volume = 0.8, Speed = 1.2, Length = 0.8 },
		{ Id = L.DirtBurst, Volume = 0.6, Speed = 1.2, Length = 0.5 },
	},
	SpearSwing = { { Id = L.SwordSwish, Volume = 1, Speed = { 1.15, 1.3 } }, { Id = L.AirySlice, Volume = 1, Speed = { 1.1, 1.25 } } },
	SpearHeavy = { { Id = L.SwordWhip, Volume = 1, Speed = 1.25, Length = 0.5 }, { Id = L.WhooshSwishBy, Volume = 0.7, Speed = 1.2, Length = 0.5 } },
	SpearHit = { { Id = L.SwordStab, Volume = 1, Speed = { 0.95, 1.05 }, Length = 0.4 }, { Id = L.MeatyThud, Volume = 0.7, Speed = 1.15, Length = 0.3 } },
	CannonFire = { Range = 700, { Id = S.Cannon, Volume = 1.3, Speed = { 0.95, 1.05 } }, { Id = L.SubBoom, Volume = 1.2, Speed = 1.1 } },
	GrandCannonFire = { Range = 1100, { Id = S.Cannon, Volume = 1.8, Speed = 0.7 }, { Id = L.PowerBoom, Volume = 1.6, Speed = 0.8 }, { Id = L.SubBoom, Volume = 1.8, Speed = 0.7 } },
	ShellBoom = { Range = 600, Gap = 0.05, { Id = L.ExplosionCrack, Volume = 1.1, Speed = { 1, 1.15 } }, { Id = L.DebrisImpact, Volume = 0.8, Speed = 1.1 } },
	DollPop = { Gap = 0.03, { Id = L.BalloonPop, Volume = 0.8, Speed = { 1.3, 1.6 } }, { Id = L.ExplosionCrack, Volume = 0.6, Speed = 1.5, Length = 0.3 } },
	Flashbang = { Range = 500, { Id = S.Flash, Volume = 1.4, Speed = 0.9 }, { Id = L.ExplosionCrack, Volume = 1.3, Speed = 1.2 }, { Id = L.SuckShort, Volume = 0.8, Speed = 2, Length = 0.25 } },
	ShieldBlock = { Gap = 0.05, { Id = L.SwordClash, Volume = 1.3, Speed = { 0.7, 0.8 } }, { Id = L.WoodClunk, Volume = 0.7, Speed = 0.6, Length = 0.3 } },
	WallBreak = { Range = 500, { Id = L.GlassSmash, Volume = 1, Speed = 0.7 }, { Id = L.DebrisImpact, Volume = 1.1, Speed = 0.8 } },
	NetLaunch = { { Id = L.WhooshBurst, Volume = 1, Speed = 0.8 }, { Id = L.WoodClunk, Volume = 0.8, Speed = 0.8 } },
	RailCharge = { { Id = L.Static, Volume = 1.2, Speed = 1.1, Length = 1 }, { Id = L.PowerUp, Volume = 1, Speed = 1.4 } },
	Railgun = { Range = 1100, { Id = L.Zap, Volume = 1.6, Speed = 0.7 }, { Id = L.PowerBoom, Volume = 1.5, Speed = 1.2 }, { Id = L.DeepBlast, Volume = 1.2, Speed = 0.9 } },
	LuckyBag = { { Id = L.Wrapper, Volume = 1.2, Speed = 0.9 }, { Id = L.CoinDrop, Volume = 1, Speed = 1.1, Delay = 0.2 } },
	UltCreation = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 1.15 },
		{ Id = L.PowerUp, Volume = 1.5, Speed = 1.2 },
		{ Id = S.Ring, Volume = 1, Speed = 0.8, Delay = 0.1 },
	},
	-- (round 60) Suneater's zip: the tentacle snapping taut, the launch off it
	ZipPull = { { Id = L.JuicySplat, Volume = 0.8, Speed = 1.4, Length = 0.3 }, { Id = L.WhooshSwishBy, Volume = 1, Speed = 1.2 } },
	ZipLaunch = { { Id = L.AscendWhoosh, Volume = 1.2, Speed = 1.1 }, { Id = L.WhooshBurst, Volume = 0.7, Speed = 1.3, Length = 0.5 } },
	-- (round 69) TWICE: knives, the measuring tape, the mud
	KnifeThrow = { Gap = 0.03, { Id = L.SwishThin, Volume = 0.8, Speed = { 1.5, 1.8 }, Length = 0.25 }, { Id = L.SwordTick, Volume = 0.4, Speed = 1.6 } },
	KnifeHit = { Gap = 0.03, { Id = L.SwordStab, Volume = 0.9, Speed = { 1.1, 1.3 }, Length = 0.4 }, { Id = L.BladeImpact, Volume = 0.6, Speed = 1.3, Length = 0.3 } },
	TapeWhip = { Gap = 0.05, { Id = L.SwordWhip, Volume = 1, Speed = 1.4, Length = 0.4 }, { Id = L.MetalSwoosh, Volume = 0.6, Speed = 1.6, Length = 0.3 } },
	CloneForm = { Gap = 0.06, { Id = L.FleshReshape, Volume = 1, Speed = 1.1, Length = 0.8 }, { Id = L.JuicySplat, Volume = 0.6, Speed = 0.8, Length = 0.4 } },
	CloneMelt = { Gap = 0.06, { Id = L.GutsSplat, Volume = 0.9, Speed = 0.8, Length = 0.6 }, { Id = L.JuicySplat, Volume = 0.7, Speed = 0.6, Length = 0.5 } },
	ParadeRoar = { Range = 700, { Id = L.CrowdRoar, Volume = 1.2, Speed = 0.9, Length = 1.6 }, { Id = L.GiantStep, Volume = 1, Speed = 1.2 } },
	UltDouble = {
		Range = 1200,
		{ Id = S.Stinger, Volume = 1, Speed = 0.9 },
		{ Id = L.FleshReshape, Volume = 1.6, Speed = 0.8, Length = 1.2 },
		{ Id = L.CrowdRoar, Volume = 1.2, Speed = 1, Delay = 0.5, Length = 1.6 },
	},
	-- (round 71) QUIRK CLASHES: the two moves meeting, every good press, the end
	ClashStart = { Range = 900, { Id = L.PowerBoom, Volume = 1.4, Speed = 0.9 }, { Id = L.WhooshBurst, Volume = 1.1, Speed = 0.8 }, { Id = S.Beam, Volume = 1, Speed = 0.8, Length = 1.2 } },
	ClashLoop = { { Id = L.WindRoar, Volume = 0.9, Speed = 1.1 } },
	ClashPush = { Gap = 0.05, { Id = L.PowerHit, Volume = 0.7, Speed = { 1.1, 1.35 }, Length = 0.3 }, { Id = S.Beam, Volume = 0.4, Speed = 1.4, Length = 0.25 } },
	ClashWrong = { { Id = S.Negative, Volume = 0.6, Speed = 1.2 } },
	ClashWin = { Range = 1200, { Id = L.ExplosionCrack, Volume = 1.5, Speed = 0.85, Length = 2 }, { Id = L.PowerBoomLong, Volume = 1.3, Speed = 0.9 }, { Id = L.DeepBlast, Volume = 1.1, Speed = 0.8 } },
	-- (round 71) THE NOMU RAID: the siren, the landing, the roar, its swings and jets, it going down
	NomuSiren = { { Id = S.Stinger, Volume = 1.2, Speed = 0.8 }, { Id = L.Accelerate, Volume = 0.6, Speed = 0.6, Length = 1.4 } },
	NomuLand = { Range = 1500, { Id = L.Quake, Volume = 2, Speed = 0.7, Length = 2 }, { Id = L.SubBoom, Volume = 1.6, Speed = 0.8 }, { Id = L.BoulderCrack, Volume = 1.4, Speed = 0.8, Length = 1.4 } },
	NomuRoar = { Range = 900, { Id = L.MonsterRoar, Volume = 1.8, Speed = 0.85, Length = 2 }, { Id = S.Beast, Volume = 1.2, Speed = 0.7, Start = 0.25 } },
	NomuSwipe = { Range = 400, { Id = L.GiantSwish, Volume = 1.4, Speed = 0.8 }, { Id = L.BeefyHit, Volume = 1.2, Speed = 0.7, Delay = 0.4 } },
	NomuJet = { Range = 700, { Id = L.JetPass, Volume = 1.4, Speed = 1.1, Length = 1.6 }, { Id = L.WhooshBurst, Volume = 1, Speed = 0.8 } },
	NomuDown = { Range = 1200, { Id = L.MonsterGrowl, Volume = 1.4, Speed = 0.7, Length = 1.6 }, { Id = L.BodyFallHuge, Volume = 1.8, Speed = 0.8, Delay = 0.6 } },
	-- (round 87) POSSESS (Config.Possess), all ids the game already plays:
	-- the soul pulled out of its body (the APM sub suck-out, a deep reversed
	-- whoosh slowed right down), landing in the body it takes (a soft sub
	-- thump, a slow growl as the eyes light, a short suck snapping shut),
	-- going home (the reverse suck, the whoosh running out), the body
	-- re-forming round it, and K with nothing to take
	PossessOut = { Range = 320, { Id = L.SubSuck, Volume = 1.1, Speed = 0.9, Length = 1.1, Fade = 0.35 }, { Id = L.DeepBlast, Volume = 0.9, Speed = 0.72, Length = 1.3, Fade = 0.5 } },
	PossessIn = {
		Range = 320,
		{ Id = L.SubBoom, Volume = 1, Speed = 0.62, Length = 1.2, Fade = 0.5 },
		{ Id = L.EnergyGrowl, Volume = 0.55, Speed = 0.55, Length = 1, Fade = 0.4 },
		{ Id = L.SuckShort, Volume = 0.6, Speed = 1.35, Length = 0.4, Fade = 0.15 },
	},
	PossessBack = { Range = 320, { Id = L.SuckIn, Volume = 1.4, Speed = 1.15, Length = 0.8, Fade = 0.3 }, { Id = L.DeepBlast, Volume = 0.6, Speed = 0.95, Length = 0.9, Fade = 0.4 } },
	PossessReform = { Range = 220, { Id = L.SubBoom, Volume = 0.7, Speed = 0.85, Length = 0.8, Fade = 0.3 }, { Id = L.MagicFlutter, Volume = 0.6, Speed = 1.2, Length = 0.7, Fade = 0.3 } },
	PossessDeny = { { Id = S.Negative, Volume = 0.45, Speed = 1.15 } },
	-- (round 71) DEKU'S MEMORIES: going from one to the next, and the Sports Festival fight
	MemoryIn = { { Id = S.Aura, Volume = 0.9, Speed = 0.8 }, { Id = L.HowlingWind, Volume = 0.4, Speed = 1.2, Length = 1.6 } },
	MemoryCrowd = { Range = 2000, { Id = L.CrowdRoar, Volume = 1.1, Speed = 1, Length = 3 }, { Id = L.CrowdWhoops, Volume = 0.8, Speed = 1, Delay = 0.3, Length = 2.5 } },
	MemoryIce = { Range = 600, { Id = L.IceHammer, Volume = 1.4, Speed = 0.9 }, { Id = L.IceCrunch, Volume = 1, Speed = 0.8, Delay = 0.1 } },
	MemoryShatter = { Range = 600, { Id = L.GlassSmash, Volume = 1.3, Speed = 0.9 }, { Id = L.WindBlast, Volume = 1.2, Speed = 1.2, Length = 1.2 }, { Id = L.GlassDebris, Volume = 1, Delay = 0.15 } },
	MemoryIgnite = { Range = 900, { Id = L.FireBurst, Volume = 1.6, Speed = 0.8 }, { Id = L.FireWhoosh, Volume = 1.4, Speed = 0.7, Length = 2 }, { Id = L.PowerBoomLong, Volume = 1, Speed = 0.9 } },
	MemoryWalls = { Range = 600, { Id = L.StoneGrind, Volume = 1.4, Speed = 0.8 }, { Id = L.Quake, Volume = 1, Speed = 1.2, Length = 1.2 } },
	MemoryCharge = { Range = 600, { Id = L.Static, Volume = 1, Speed = 0.9, Length = 1.5 }, { Id = L.PowerUp, Volume = 1.1, Speed = 0.9 }, { Id = L.FlameLick, Volume = 1, Speed = 0.8, Delay = 0.2 } },
	MemoryBlast = { Range = 3000, { Id = L.PowerBoomLong, Volume = 2, Speed = 0.8 }, { Id = L.WindRoar, Volume = 1.4, Speed = 0.8, Length = 3 }, { Id = L.SubBoom, Volume = 1.6, Speed = 0.7 } },
	MemoryThud = { Range = 500, { Id = L.BodyFallHuge, Volume = 1.4, Speed = 0.9 }, { Id = L.DirtBurst, Volume = 0.8, Speed = 1.1, Length = 0.5 } },
	-- (round 74) PRIME DEKU: the flash step, the kick behind them, the eight
	FlashStep = { Gap = 0.04, { Id = L.WhooshBurst, Volume = 1, Speed = { 1.4, 1.6 }, Length = 0.4 }, { Id = S.Thunder, Volume = 0.5, Speed = 1.8, Length = 0.35 }, { Id = L.EnergySnap, Volume = 0.7, Speed = 1.3, Length = 0.3 } },
	FlashAppear = { Gap = 0.04, { Id = L.EnergySnap, Volume = 0.9, Speed = 1.1, Length = 0.35 }, { Id = L.Static, Volume = 0.5, Speed = 1.4, Length = 0.3 } },
	FlashKick = { Gap = 0.05, { Id = L.PowerHit, Volume = 1.2, Speed = 1, Length = 0.6 }, { Id = L.CrackyPunch, Volume = 1, Speed = 0.8, Length = 0.4 }, { Id = S.Thunder, Volume = 0.6, Speed = 1.3, Length = 0.6 } },
	VestigeCall = { Range = 400, { Id = L.PowerUp, Volume = 1, Speed = 0.8, Length = 1.2 }, { Id = L.EnergyGrowl, Volume = 0.7, Speed = 0.9, Length = 1 } },
	UltPrimeDeku = { Range = 1200, { Id = S.Stinger, Volume = 1, Speed = 1 }, { Id = S.Thunder, Volume = 0.9, Speed = 0.9, Length = 1.4 }, { Id = L.PowerUp, Volume = 1, Speed = 1.1, Length = 1.2 } },
	-- PRIME ALL MIGHT: the sonic boom, the fall out of the sky
	SonicBoom = { Gap = 0.05, { Id = L.WhooshExplosion, Volume = 1.2, Speed = 1.2, Length = 0.8 }, { Id = L.BoomThump, Volume = 0.9, Speed = 1, Length = 0.6 } },
	MeteorFall = { Range = 500, { Id = L.JetPass, Volume = 1.2, Speed = 0.7, Length = 1 }, { Id = L.WindRoar, Volume = 0.9, Speed = 1.1, Length = 0.8 } },
	UltPrimeMight = { Range = 1200, { Id = L.PowerUp, Volume = 1, Speed = 0.75 }, { Id = L.CrowdRoar, Volume = 1, Speed = 1, Delay = 0.3, Length = 1.6 }, { Id = L.SubBoom, Volume = 1, Speed = 0.7 } },
	-- DIO: stopped time, the clock, the drain, the eyes, the road roller
	ZaWarudo = { Range = 500, { Id = L.PowerUp, Volume = 1, Speed = 0.6, Length = 1 }, { Id = S.Stinger, Volume = 0.8, Speed = 0.8 } },
	TimeStop = { Range = 800, { Id = L.SuckIn, Volume = 1.3, Speed = 0.6, Length = 1.2 }, { Id = L.SubBoom, Volume = 1.2, Speed = 0.5, Length = 1.5 }, { Id = L.PowerBoomLong, Volume = 0.8, Speed = 0.6, Length = 1.4, Delay = 0.1 } },
	TimeResume = { Range = 800, { Id = L.SuckShort, Volume = 1.2, Speed = 0.8, Length = 0.8 }, { Id = L.WhooshBurst, Volume = 1, Speed = 0.6, Length = 0.8 } },
	ClockTick = { Range = 600, { Id = L.SwordTick, Volume = 1.1, Speed = 0.55, Length = 0.25 }, { Id = L.WoodClunk, Volume = 0.6, Speed = 1.6, Length = 0.2 } },
	Drain = { Gap = 0.2, { Id = L.Gulp, Volume = 1, Speed = 0.6, Length = 0.8 }, { Id = L.BloodSpurt, Volume = 0.7, Speed = 0.8, Length = 0.6 } },
	EyeBeam = { Gap = 0.05, { Id = S.Beam, Volume = 1, Speed = 1.8, Length = 0.5 }, { Id = L.EnergySnap, Volume = 0.8, Speed = 1.6, Length = 0.3 } },
	RoadRollerLand = { Range = 600, { Id = L.DebrisImpact, Volume = 1.3, Speed = 0.8, Length = 1 }, { Id = L.PowerBoom, Volume = 1.1, Speed = 0.8, Length = 1 }, { Id = L.SwordClash, Volume = 0.8, Speed = 0.4, Length = 0.8 } },
	RoadRollerBoom = { Range = 800, { Id = L.Explosions, Volume = 1.4, Speed = 0.9, Length = 1.6 }, { Id = L.ExplosionCrack, Volume = 1.1, Speed = 0.9, Length = 1 }, { Id = L.SubBoom, Volume = 1.2, Speed = 0.7, Length = 1.4 } },
	UltTheWorld = { Range = 1200, { Id = S.Stinger, Volume = 1, Speed = 0.8 }, { Id = L.MonsterRoar, Volume = 0.7, Speed = 1.4, Length = 1.4 }, { Id = L.PowerBoomLong, Volume = 0.9, Speed = 0.8 } },
	-- dev toys
	Launch = { { Id = L.WhooshBurst, Volume = 1.2, Speed = 1.2 }, { Id = L.SubBoom, Volume = 1 } },
	Boing = { { Id = L.BalloonPop, Volume = 1.2, Speed = 0.5 }, { Id = L.AscendWhoosh, Volume = 0.8, Speed = 1.4 } },
	-- (round 86) DEV FLIGHT. The wind beds are looped by the flight itself
	-- (a Sound each, crossfaded by his speed: only the first layer's take
	-- and Volume are used). The beats escalate: smash < landing < boom <
	-- crash - only the crash gets the cannon and the big tail at full.
	-- (round 87, flightsfx: the mix that drives them is Config.DevFlight.Sound;
	-- the beds' Volumes put each tier ~3 dB over the last by the measured
	-- loudness of each file - hover ~0.06, cruise ~0.09, fast ~0.14, hyper ~0.2)
	DevFlyHoverBed = { { Id = L.FlyHoverBed, Volume = 1.8, Speed = 0.78 } },
	DevFlyCruiseBed = { { Id = L.FlyCruiseBed, Volume = 2.6 } },
	DevFlyFastBed = { { Id = L.FlyFastBed, Volume = 1.9 } },
	-- (round 87) HYPERSONIC's bed is a steady rush of air now: the flanging
	-- pass-bys it was (L.FlyHyperBed) swell and die every ~6 s (measured: 20
	-- dB swings), so they ride on top as colour (DevFlyHyperFlange)
	DevFlyHyperBed = { { Id = L.FlyRush, Volume = 1.8 } },
	DevFlyHyperRumble = { { Id = L.FlyHyperRumble, Volume = 2.6 } },
	DevFlyBuffet = { { Id = L.FlyBuffet, Volume = 1.4, Speed = 0.9 } }, -- (round 87) FAST: the air buffeting him (shaken by the flight)
	DevFlyHyperTear = { { Id = L.TearingAir, Volume = 1.6 } }, -- (round 87) the air tearing at HYPERSONIC
	DevFlyHyperFlange = { { Id = L.FlyHyperBed, Volume = 0.45 } }, -- (round 87) the fiery pass-bys, under it
	DevFlyGust = { Gap = 0.5, { Id = L.FlyGust, Volume = 1.1, Speed = { 0.9, 1.2 }, Length = 3, Fade = 1.2 } },
	DevFlyFlutter = { Gap = 0.12, { Id = L.CapeFlap, Volume = 0.45, Speed = { 1.05, 1.25 }, Length = 0.7, Fade = 0.3 } },
	DevFlyFlutterFast = { Gap = 0.05, { Id = L.ClothTick, Volume = 2.6, Speed = { 1.2, 1.5 }, Length = 0.35, Fade = 0.15 } }, -- (round 87) the cape snapping fast at speed
	DevFlyCrouch = { { Id = L.SuckShort, Volume = 0.9, Speed = 0.9, Length = 0.9, Fade = 0.2 }, { Id = L.EarthCracking, Volume = 0.7, Speed = 1.3, Length = 0.8, Fade = 0.3 } },
	DevFlyTakeoff = {
		Range = 900,
		{ Id = L.DeepImpact7, Volume = 1.3, Near = 40 },
		{ Id = S.Cannon, Volume = 0.6, Speed = 1.1, Length = 1.4, Fade = 0.6, Near = 40 }, -- (round 87) the show's cannon under the thump
		{ Id = L.EarthCracking, Volume = 1.6, Length = 2, Fade = 0.8, Near = 40 },
		{ Id = L.SweepAperture, Volume = 1, Length = 1.6, Fade = 0.6, Near = 40 },
		{ Id = S.Roar, Volume = 0.7, Speed = 1.25, Length = 1.4, Fade = 0.6, Near = 40 },
	},
	-- (round 87) the rising whoosh that leaves with him (it rides his body:
	-- everyone hears it go up; his own ears have it flat)
	DevFlyTakeoffRise = { Range = 700, Gap = 0.3, { Id = L.AscendWhoosh, Volume = 1.4, Speed = 0.85, Length = 1.4, Fade = 0.5, Near = 40 }, { Id = L.WhooshBurst, Volume = 0.7, Speed = 0.9, Length = 1, Fade = 0.4, Near = 40 } },
	DevFlyCatch = { Gap = 0.3, { Id = L.CapeSnap, Volume = 0.8, Speed = 1.15, Length = 0.6, Fade = 0.2 }, { Id = L.AscendWhoosh, Volume = 0.7, Speed = 0.9 }, { Id = L.SubBoom, Volume = 0.5, Speed = 1.5, Length = 0.6, Fade = 0.3 } },
	-- (round 86) the N-wave: two cracks 0.09 s apart, the boom's long tail under them
	-- (round 87: kept for anything that wants the whole boom in one cue; the
	-- flight plays it in parts below, mixed by distance)
	DevFlyBoom = {
		Range = 2500, Gap = 0.3,
		{ Id = L.FlyCrack, Volume = 2.2, Speed = { 0.6, 0.66 }, Peak = true, PreRoll = 0.02, Length = 0.7, Fade = 0.4, Near = 260 },
		{ Id = L.FlyCrack, Volume = 1.8, Speed = { 0.52, 0.56 }, Peak = true, PreRoll = 0.02, Delay = 0.11, Length = 0.7, Fade = 0.4, Near = 260 },
		{ Id = L.SonicBoomAPM, Volume = 1.4, Length = 4, Fade = 2.5, Near = 220 },
		{ Id = L.BigBoomTail, Volume = 1.1, Length = 3, Fade = 2, Near = 220 },
	},
	-- (round 87, flightsfx) THE SONIC BOOM in parts (DFX mixes them by
	-- distance: Config.DevFlight.Sound.Boom.Mix). The crack: the bow shock
	-- and, Delay later, the tail shock - the N-wave's "ka-BOOM" (whip cracks,
	-- pitched down: a crack at ~2.7 kHz with a punch under the first)
	DevFlyBoomCrack = {
		Range = 2500, Gap = 0.25,
		{ Id = L.FlyCrack, Volume = 2.2, Speed = { 0.6, 0.66 }, Peak = true, PreRoll = 0.02, Length = 0.7, Fade = 0.4, Near = 260 },
		{ Id = L.DeepImpact7, Volume = 0.9, Speed = 1.15, Length = 0.6, Fade = 0.3, Near = 220 },
		{ Id = L.FlyCrack, Volume = 1.8, Speed = { 0.52, 0.56 }, Peak = true, PreRoll = 0.02, Delay = 0.11, Length = 0.7, Fade = 0.4, Near = 260 },
	},
	-- the pressure wave hitting you: a whomp of air (close only)
	DevFlyBoomWhomp = { Range = 600, Gap = 0.25, { Id = L.SonicPressure, Volume = 1.1, Peak = true, PreRoll = 0.03, Length = 1.4, Fade = 0.8, Near = 60 } },
	-- the boom itself: the APM boom (its punch at 94-188 Hz), the deep hit,
	-- the PSE booms (all under 100 Hz) for the body
	DevFlyBoomBody = {
		Range = 2500, Gap = 0.25,
		{ Id = L.SonicBoomAPM, Volume = 1.4, Length = 4, Fade = 2.5, Near = 220 },
		{ Id = L.DeepImpact, Volume = 1.1, Length = 3, Fade = 2, Near = 220 },
		{ Id = L.SonicCrack, Volume = 0.8, Peak = true, Length = 2.5, Fade = 1.5, Near = 220 },
	},
	-- the sub: the chest thump (47 Hz) and the cannon
	DevFlyBoomSub = { Range = 2600, Gap = 0.25, { Id = L.SubBoom, Volume = 1.6, Speed = 0.85, Length = 2, Fade = 1, Near = 260 }, { Id = S.Cannon, Volume = 1, Speed = 0.7, Length = 2, Fade = 1, Near = 260 } },
	-- the roll: thunder rolling on after it
	DevFlyBoomRoll = { Range = 2600, Gap = 0.25, { Id = L.ThunderRoll, Volume = 1.6, Delay = 0.3, FadeIn = 0.25, Length = 4.5, Fade = 3, Near = 260 }, { Id = L.BigBoomTail, Volume = 0.9, Delay = 0.15, Length = 3.5, Fade = 2.5, Near = 260 } },
	-- far away: only the low rumble carries
	DevFlyBoomFar = {
		Range = 2800, Gap = 0.25,
		{ Id = L.Rumbler, Volume = 1.8, Length = 5, Fade = 3, Near = 400 },
		{ Id = L.DistantBooms, Volume = 6, Delay = 0.1, Length = 3, Fade = 1.5, Near = 400 },
		{ Id = L.GaiaRoll, Volume = 1.2, Delay = 0.2, Length = 3.5, Fade = 2, Near = 400 },
	},
	-- close by: the windows and everything loose shivering
	DevFlyBoomShiver = { Range = 300, Gap = 0.4, { Id = L.GlassShiver, Volume = 2.2, Delay = 0.08, Length = 1.8, Fade = 1.2, Near = 30 }, { Id = L.GlassDebris, Volume = 2.5, Delay = 0.25, Speed = { 0.9, 1.1 }, Length = 0.9, Near = 30 } },
	-- one echo off the city (played where the wall is: darker, smeared)
	DevFlyBoomEcho = {
		Range = 2600, Gap = 0,
		{ Id = L.SonicBoomAPM, Volume = 1, Speed = { 0.9, 0.98 }, Eq = { 2, -4, -14 }, Length = 2.4, Fade = 1.6, Near = 160 },
		{ Id = L.ThunderBlast, Volume = 1.6, Speed = { 0.92, 1 }, Eq = { 0, -2, -10 }, Length = 2.2, Fade = 1.6, Near = 160 },
	},
	-- your ears ringing after it (a pure tone ~3.5 kHz, outside the muffle)
	DevFlyEarRing = { { Id = L.EarRing, Volume = 0.1, Speed = { 1.55, 1.7 }, FadeIn = 0.04, Length = 2.6, Fade = 2.3 } },
	-- (round 87) the mach burst's punch-in: a whomp of air, a crack as he
	-- punches through, the zoom, a sub
	DevFlyBoost = {
		Gap = 0.2, Range = 1500,
		{ Id = L.SonicPressure, Volume = 1.1, Peak = true, PreRoll = 0.03, Length = 1.2, Fade = 0.6, Near = 60 },
		{ Id = L.FlyCrack, Volume = 1.6, Speed = 0.8, Peak = true, PreRoll = 0.02, Length = 0.5, Fade = 0.3, Near = 80 },
		{ Id = L.MagicZoom, Volume = 1, Length = 1.4, Fade = 0.6 },
		{ Id = L.WhooshBurst, Volume = 0.9, Speed = 1.1, Length = 0.8 },
		{ Id = L.SubBoom, Volume = 1, Speed = 1.1, Length = 1, Fade = 0.5, Near = 60 },
	},
	-- (round 87) the braking flip: the cape snapping round, an air-brake
	-- whomp (air sucked in, then the thump), the swish
	DevFlyBrake = {
		Gap = 0.2,
		{ Id = L.CapeSnap, Volume = 1, Length = 0.9, Fade = 0.4 },
		{ Id = L.AirBrake, Volume = 1.4, Length = 1.2, Fade = 0.6 },
		{ Id = L.SwishLarge, Volume = 0.9, Speed = 0.8 },
		{ Id = L.SubBoom, Volume = 0.8, Speed = 1.25, Length = 0.8, Fade = 0.4 },
	},
	DevFlySmash = {
		Range = 1200, Gap = 0.06,
		{ Id = L.WallCrash, Volume = 1.4, Peak = true, Length = 2.2, Fade = 1, Near = 60 },
		{ Id = L.MetalCrash, Volume = 0.9, Length = 1.8, Fade = 0.9, Near = 60 },
		{ Id = L.GlassSmash, Volume = 0.8, Speed = { 0.9, 1.1 }, Near = 40 },
		{ Id = S.Cannon, Volume = 0.45, Speed = 1.2, Near = 40 },
		{ Id = L.WallCrashRubble, Volume = 0.9, Delay = 0.15, Length = 2.4, Fade = 1.2, Near = 40 },
		{ Id = L.SubBoom, Volume = 0.9, Speed = 1.1, Length = 1.2, Fade = 0.6, Near = 40 }, -- (round 87) the weight: the wall crashes have no sub (-25 dB at 47 Hz)
	},
	DevFlyRam = { Gap = 0.08, { Id = L.BodyImpact, Volume = 1.1 }, { Id = L.SubBoom, Volume = 0.8, Speed = 1.2 }, { Id = L.WhooshSwishBy, Volume = 0.8 } },
	DevFlyWallHit = {
		Range = 900,
		{ Id = L.DeepImpact7, Volume = 1.3, Speed = 0.9, Near = 40 },
		{ Id = L.BoulderCrack, Volume = 1, Length = 1.2, Fade = 0.5 },
		{ Id = L.DebrisImpact, Volume = 0.8, Length = 1 },
		{ Id = S.Cannon, Volume = 0.7, Speed = 1.05, Length = 1.4, Fade = 0.6, Near = 40 }, -- (round 87) stopped dead: real weight
	},
	DevFlyLand = {
		Range = 700,
		{ Id = L.CrackThud, Volume = 1.1, Speed = 1.15, Length = 0.5 },
		{ Id = L.DirtBurst, Volume = 0.8, Speed = 1.1, Length = 0.5 },
		{ Id = L.BodyFall, Volume = 0.6, Speed = 1.2, Length = 0.35 },
		{ Id = L.BodyFallDirt, Volume = 0.8, Length = 1.2, Fade = 0.5 },
		{ Id = L.DeepImpact7, Volume = 0.8, Near = 30 },
		{ Id = S.Cannon, Volume = 0.45, Speed = 1.25, Length = 1, Fade = 0.5, Near = 30 }, -- (round 87) the superhero's weightier footfall
	},
	DevFlySoft = { Gap = 0.2, { Id = L.BodyFall, Volume = 0.5, Speed = 1.3, Length = 0.3 }, { Id = L.DirtBurst, Volume = 0.4, Speed = 1.4, Length = 0.3 } },
	DevFlyCrash = {
		Range = 1400,
		{ Id = L.QuakeBlast, Volume = 2, Length = 5, Fade = 2, Near = 90 },
		{ Id = L.DeepImpact7, Volume = 1.6, Near = 90 },
		{ Id = S.Cannon, Volume = 1.1, Speed = 0.8, Near = 90 },
		{ Id = L.BigBoomTail, Volume = 1.8, Length = 3.5, Fade = 2, Near = 90 },
		{ Id = L.WallCrash, Volume = 1.2, Length = 2.5, Fade = 1, Near = 60 },
		{ Id = L.EarthCracking, Volume = 1.6, Delay = 0.2, Length = 2.6, Fade = 1, Near = 60 },
		-- (round 87) the chest hit, the pressure, the street's rumble dying away
		{ Id = L.DeepImpact, Volume = 1.3, Length = 3, Fade = 2, Near = 90 },
		{ Id = L.SonicPressure, Volume = 0.9, Peak = true, PreRoll = 0.03, Length = 1.4, Fade = 0.8, Near = 60 },
		{ Id = L.Rumbler, Volume = 1.4, Delay = 0.3, Length = 4, Fade = 2.5, Near = 120 },
	},
	-- (round 87) the dive: a scream rising as he comes down (it rides him)
	DevFlyDive = {
		Range = 1200, Gap = 0.3,
		{ Id = L.FlyScream, Volume = 3.2, Length = 2.2, Fade = 0.5, Near = 60 },
		{ Id = L.JetPass, Volume = 1.2, Speed = 0.8, Length = 1.4, Near = 60 },
		{ Id = L.HowlingWind, Volume = 1, Speed = 1.3, Length = 1.4 },
	},
	-- (round 87, flightsfx) FLY-BYS: a flyer passing close - a doppler whomp
	-- riding him (DFX bends its pitch as he goes by), the bright tear on top
	-- from FAST up
	DevFlyFlyBy = { Range = 700, { Id = L.FlyByWhomp, Volume = 1.4, Length = 1.6, Fade = 0.7, Near = 25 } },
	DevFlyFlyByTear = { Range = 700, { Id = L.MagicZoom, Volume = 0.8, Length = 1.2, Fade = 0.6, Near = 25 } },
	-- (round 90, devfly2) LIGHTSPEED. The beds (Config.DevFlight.Sound.Beds:
	-- crossfaded in from 1000 studs/s over the hypersonic rush): the tunnel's
	-- synthy swirl (quiet: ~0.06 body RMS), the rush pitched up bright, the
	-- energy roar pitched down under it
	DevFlyLightBed = { { Id = L.LightTunnel, Volume = 3.2, Speed = 1.1 } },
	DevFlyLightRush = { { Id = L.FlyRush, Volume = 1.6, Speed = 1.32 } },
	DevFlyLightDeep = { { Id = L.FlyHyperRumble, Volume = 2.4, Speed = 0.72 } },
	-- the charge (the burst held at HYPERSONIC): an orchestral swell sucked out
	-- on the break, a riser topping out on it, the plasma's crackle fading in
	-- (held: let go of the key early and they're let go)
	DevFlyLightCharge = {
		Range = 900, Gap = 0.5,
		{ Id = L.LightSwell, Volume = 1.3, Length = 1.5, Fade = 0.1, Near = 40 },
		{ Id = L.LightRiser, Volume = 2.6, Length = 1.5, Fade = 0.12, Near = 40 },
		{ Id = L.LightSizzle, Volume = 1.8, FadeIn = 0.4, Length = 1.5, Fade = 0.2, Near = 30 },
	},
	-- THE LIGHT BARRIER breaking, in his head: the crack deeper than the
	-- boom's, the APM boom pitched down, the sub, the cannon, the zoom away and
	-- the beam's ring (the shatter below on top; then the muffle and the ring)
	DevFlyLightBreak = {
		Range = 2600, Gap = 0.5,
		{ Id = L.FlyCrack, Volume = 2.4, Speed = { 0.5, 0.55 }, Peak = true, PreRoll = 0.02, Length = 0.8, Fade = 0.4, Near = 260 },
		{ Id = L.SonicBoomAPM, Volume = 1.6, Speed = 0.78, Length = 4.5, Fade = 2.5, Near = 240 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.6, Length = 2.5, Fade = 1.2, Near = 260 },
		{ Id = S.Cannon, Volume = 1.1, Speed = 0.5, Near = 240 },
		{ Id = L.MagicZoom, Volume = 1.2, Speed = 1.35, Length = 1.2, Fade = 0.6 },
		{ Id = S.Beam, Volume = 0.6, Speed = 0.5, Length = 1.4, Fade = 0.8 },
	},
	-- the barrier shattering like glass (everyone: where it broke - late by
	-- the distance for anyone else, over the boom's own mix)
	DevFlyLightShatter = {
		Range = 1800, Gap = 0.5,
		{ Id = L.GlassSmash, Volume = 1.6, Speed = { 0.55, 0.62 }, Length = 1.6, Fade = 0.8, Near = 120 },
		{ Id = L.GlassDebris, Volume = 1.8, Delay = 0.12, Speed = { 0.7, 0.8 }, Length = 1.4, Fade = 0.8, Near = 120 },
		{ Id = L.LightSuck, Volume = 0.9, Speed = 0.8, Length = 1.2, Fade = 0.5, Near = 120 },
	},
	-- dropping back out of it: the air sucked back in, a brake whomp, the cape
	DevFlyLightOut = {
		Range = 900, Gap = 0.4,
		{ Id = L.LightSuck, Volume = 1.2, Speed = 1.15, Length = 1, Fade = 0.4, Near = 60 },
		{ Id = L.AirBrake, Volume = 1.1, Speed = 1.25, Length = 0.9, Fade = 0.4, Near = 60 },
		{ Id = L.CapeSnap, Volume = 0.8, Speed = 1.1, Length = 0.6, Near = 40 },
	},
	-- someone at LIGHTSPEED passing you: a deep whomp, the zoom, a crack
	DevFlyLightPass = {
		Range = 900,
		{ Id = L.FlyByWhomp, Volume = 1.6, Speed = 0.7, Length = 1.6, Fade = 0.7, Near = 30 },
		{ Id = L.MagicZoom, Volume = 1.1, Speed = 1.5, Length = 1, Fade = 0.5, Near = 30 },
		{ Id = L.FlyCrack, Volume = 1.2, Speed = 0.8, Peak = true, PreRoll = 0.02, Length = 0.6, Near = 60 },
	},
	-- the barrel roll / the sidestep: a heavy swish, the air, the cape
	DevFlyRoll = { Gap = 0.25, Range = 500, { Id = L.SwishLarge, Volume = 1.2, Speed = { 0.7, 0.78 } }, { Id = L.WhooshSwishBy, Volume = 0.9, Speed = 1.15, Length = 0.6 }, { Id = L.ClothTick, Volume = 1.6, Speed = 1.3, Length = 0.3 } },
	-- the hover-lock: the cape snapping still, the air settling round him; let go
	DevFlyLockOn = { Gap = 0.2, { Id = L.CapeSnap, Volume = 0.7, Speed = 1.3, Length = 0.5, Fade = 0.2 }, { Id = L.SuckShort, Volume = 0.5, Speed = 1.5, Length = 0.5, Fade = 0.2 } },
	DevFlyLockOff = { Gap = 0.2, { Id = L.ClothTick, Volume = 1.4, Speed = 1.1, Length = 0.3 } },
	-- (round 88) THE CARRY (the flight's 5th move): the game's own licensed
	-- takes (r86/sfx_catalog.md). The reach: a heavy swish and a flick of
	-- cloth as the arm shoots out
	DevCarryReach = { Gap = 0.15, { Id = L.SwishLarge, Volume = 1.1, Speed = { 0.82, 0.9 } }, { Id = L.ClothTick, Volume = 1, Length = 0.4 } },
	-- the grab: the collar yanked tight (a canvas snap, a cloth burst), the
	-- grip's thud, a crack, a low thump under it
	DevCarryGrab = {
		Range = 500, Gap = 0.2,
		{ Id = L.CapeSnap, Volume = 1.1, Speed = 1.15, Length = 0.8, Fade = 0.4 },
		{ Id = L.ClothBloom, Volume = 2, Speed = 1.25, Length = 0.6, Fade = 0.3 },
		{ Id = L.BodyImpact, Volume = 1.2 },
		{ Id = L.CrackThud, Volume = 0.9, Speed = 1.1, Length = 0.5 },
		{ Id = L.SubBoom, Volume = 0.7, Speed = 1.3, Length = 0.8, Fade = 0.4, Near = 30 },
	},
	-- THE SLAM: the deepest impact the game has - the body slam's low end,
	-- the quake, the cannon, the APM deep hit, the boulder cracking, the
	-- street giving way, a sub you feel
	DevCarrySlam = {
		Range = 1600, Gap = 0.3,
		{ Id = L.BodySlamThump, Volume = 1.8, Speed = 0.8, Near = 90 },
		{ Id = L.DeepImpact7, Volume = 1.8, Speed = 0.82, Near = 90 },
		{ Id = L.DeepImpact, Volume = 1.5, Length = 3, Fade = 2, Near = 120 },
		{ Id = S.Cannon, Volume = 1.2, Speed = 0.65, Near = 90 },
		{ Id = L.BoulderCrack, Volume = 1.3, Speed = 0.9, Length = 1.4, Fade = 0.6, Near = 60 },
		{ Id = L.QuakeBlast, Volume = 1.6, Delay = 0.05, Length = 4, Fade = 2, Near = 90 },
		{ Id = L.SubBoom, Volume = 1.8, Speed = 0.7, Length = 2, Fade = 1, Near = 120 },
	},
	-- the throw: the wind-up's whoosh, then the hurl - a giant swish, the
	-- air burst, a whip crack, the pressure wave
	DevCarryWindup = { Gap = 0.2, { Id = L.SwishLarge, Volume = 1, Speed = { 0.62, 0.68 }, Length = 0.5 }, { Id = L.ClothTick, Volume = 0.8, Speed = 0.9, Length = 0.3 } },
	DevCarryThrow = {
		Range = 900, Gap = 0.2,
		{ Id = L.GiantSwish, Volume = 1.3, Speed = 1.1 },
		{ Id = L.WhooshBurst, Volume = 1, Speed = 1.15, Length = 0.8 },
		{ Id = L.FlyCrack, Volume = 1.2, Speed = 0.9, Peak = true, PreRoll = 0.02, Length = 0.5, Fade = 0.3, Near = 60 },
		{ Id = L.SonicPressure, Volume = 0.9, Peak = true, PreRoll = 0.03, Length = 1.2, Fade = 0.6, Near = 60 },
		{ Id = L.SubBoom, Volume = 0.8, Speed = 1.2, Length = 0.8, Fade = 0.4 },
	},
	-- the ram's punch-in: the air whomp, the wind tearing past, the cape
	DevCarryRam = {
		Range = 1200, Gap = 0.3,
		{ Id = L.SonicPressure, Volume = 1.2, Peak = true, PreRoll = 0.03, Length = 1.4, Fade = 0.7, Near = 60 },
		{ Id = L.WindBlast, Volume = 1, Length = 1.6, Fade = 0.8, Near = 60 },
		{ Id = L.CapeSnap, Volume = 0.9, Speed = 0.9, Length = 0.8, Fade = 0.4 },
		{ Id = L.SubBoom, Volume = 1, Speed = 0.95, Length = 1.2, Fade = 0.6, Near = 60 },
	},
	-- let go: a flap of cloth, a swish
	DevCarryRelease = { Gap = 0.15, Range = 300, { Id = L.ClothTick, Volume = 1, Length = 0.4 }, { Id = L.SwishThin, Volume = 0.8, Speed = 0.85 } },
	-- (nobody in reach / it didn't take: a short whiff)
	DevCarryMiss = { Gap = 0.2, { Id = L.AirySlice, Volume = 1.2, Speed = 0.8 } },
	-- (round 89) THE BOMB (Config.DevFlight.Bomb): a crash at mach speed goes
	-- off like a bomb - the game's own licensed takes (r86/sfx_catalog.md),
	-- on top of the crash's own (DevFlyCrash) and the boom's roll and sub:
	-- the searing blast and its long tail, the APM deep hit, the cannon
	-- pitched down, the thunder blast, the boom's long tail, the sub you
	-- feel, the street and the buildings coming down after it (8 voices:
	-- with the crash's, the roll's and the sub's, ~30 of Audio.MaxVoices 48)
	DevFlyBomb = {
		Range = 2600, Gap = 0.3,
		{ Id = L.PowerBoom, Volume = 2.2, Speed = { 0.62, 0.68 }, Length = 3, Fade = 1.5, Near = 120 },
		{ Id = L.PowerBoomLong, Volume = 2.2, Speed = 0.6, Length = 5, Fade = 2.5, Near = 140 },
		{ Id = L.DeepImpact, Volume = 1.8, Length = 3.5, Fade = 2, Near = 160 },
		{ Id = S.Cannon, Volume = 1.4, Speed = 0.55, Near = 140 },
		{ Id = L.ThunderBlast, Volume = 1.6, Speed = 0.8, Delay = 0.05, Length = 3, Fade = 2, Near = 200 },
		{ Id = L.BigBoomTail, Volume = 2, Speed = 0.85, Delay = 0.1, Length = 5, Fade = 3, Near = 220 },
		{ Id = L.SubBoom, Volume = 2, Speed = 0.6, Length = 2.5, Fade = 1.2, Near = 200 },
		{ Id = L.WallCrashRubble, Volume = 1.4, Delay = 0.35, Length = 3, Fade = 1.5, Near = 80 },
	},
	-- (round 92) LIGHTWIPE - LIGHTSPEED INTO THE GROUND (Config.DevFlight.
	-- LightWipe). Flat on every screen (the whole city hears it; each screen
	-- sets its own gain by how far off it is - VFX.LWX). The impact: the
	-- light barrier's crack dropped an octave, the searing blast and its long
	-- tail, the earthquake's rock hit, the APM boom and deep hit, the thunder,
	-- the sub you feel, the air sucked out after it. The cloud going up: the
	-- long sub rumble, the roar building under it, the thunder rolling on,
	-- far-off booms. (The wave going over you, the empty plain and the rewind
	-- are the Serious Punch's own: SeriousWave, SeriousAftermath, SeriousRewind)
	LightWipeImpact = {
		Gap = 1,
		{ Id = L.FlyCrack, Volume = 2.4, Speed = 0.42, Peak = true, PreRoll = 0.02, Length = 1, Fade = 0.5 },
		{ Id = L.PowerBoomLong, Volume = 2.4, Speed = 0.5, Length = 6, Fade = 3 },
		{ Id = L.QuakeBlast, Volume = 1.8, Speed = 0.8, Length = 6, Fade = 4 },
		{ Id = L.SonicBoomAPM, Volume = 1.6, Speed = 0.6, Length = 5, Fade = 3 },
		{ Id = L.DeepImpact, Volume = 1.6, Speed = 0.8, Length = 4, Peak = true, PreRoll = 0.03, Fade = 2.5 },
		{ Id = L.ThunderBlast, Volume = 1.6, Speed = 0.7, Delay = 0.06, Length = 3.5, Fade = 2 },
		{ Id = L.SubBoom, Volume = 2.2, Speed = 0.5, Length = 3, Fade = 1.5 },
		{ Id = L.LightSuck, Volume = 1, Speed = 0.6, Delay = 0.02, Length = 1.4, Fade = 0.6 },
	},
	LightWipeRumble = {
		Gap = 1,
		{ Id = L.Rumbler, Volume = 2, Length = 7, Fade = 3.5, FadeIn = 0.4 },
		{ Id = L.FlyHyperRumble, Volume = 1.6, Speed = 0.6, FadeIn = 0.8, Length = 6, Fade = 3 },
		{ Id = L.ThunderRoll, Volume = 1.2, Speed = 0.8, Delay = 0.3, Length = 6, Fade = 3.5 },
		{ Id = L.DistantBooms, Volume = 2.2, Delay = 1.5, Length = 4, Fade = 2 },
	},
	-- down through a building: each floor giving way (the slab cracking, the
	-- girders, the rubble, a punch under it)
	DevFlyShaft = {
		Range = 1200, Gap = 0.04,
		{ Id = L.WallCrash, Volume = 1.3, Speed = { 0.85, 1 }, Peak = true, Length = 1.6, Fade = 0.8, Near = 60 },
		{ Id = L.MetalCrash, Volume = 0.8, Speed = { 0.9, 1.05 }, Length = 1.2, Fade = 0.6, Near = 60 },
		{ Id = L.BoulderCrack, Volume = 1, Speed = { 0.85, 0.95 }, Length = 1, Fade = 0.4, Near = 40 },
		{ Id = L.DebrisImpact, Volume = 0.9, Delay = 0.08, Length = 1.2, Near = 40 },
		{ Id = L.SubBoom, Volume = 1, Speed = 1.05, Length = 1, Fade = 0.5, Near = 60 },
	},
	-- (round 89) THE THROW'S LANDING (Carry.Throw.Land): the body hitting the
	-- street hard - the slam's thump, the crack and thud, the dirt, a punch
	DevCarryThrowLand = {
		Range = 900, Gap = 0.2,
		{ Id = L.BodySlamThump, Volume = 1.6, Speed = 0.9, Near = 60 },
		{ Id = L.CrackThud, Volume = 1.2, Speed = 0.95, Length = 0.6 },
		{ Id = L.BodyFallDirt, Volume = 1.1, Length = 1.2, Fade = 0.5 },
		{ Id = L.DirtBurst, Volume = 0.9, Speed = 1.05, Length = 0.7, Fade = 0.3 },
		{ Id = L.DeepImpact7, Volume = 1.2, Speed = 0.95, Near = 40 },
		{ Id = S.Cannon, Volume = 0.5, Speed = 1.2, Length = 1, Fade = 0.5, Near = 40 },
	},
}


---------------------------------------------------------------------------
-- Quirks
---------------------------------------------------------------------------
-- CutInCorner: where the comic-panel cut-in slides in (matches the video layout)
-- CutInImage: optional "rbxassetid://..." of YOUR OWN art to show inside the panel
-- Ult: the G moveset. Duration in seconds; WalkSpeed/JumpPower apply while active.

Config.Quirks = {
	-- Katsuki Bakugo. His palms sweat nitroglycerin and he sets it off: every
	-- explosion goes off the moment he makes it (he can't hold one back or
	-- throw it), so everything is point-blank, a beam, or him flying on the
	-- blasts. Every move has an air version (Air = used off the ground).
	Explosion = {
		DisplayName = "EXPLOSION",
		Description = "Point-blank blasts and flying on explosions - HOLD DASH (Q) to fly. 1 AP Shot, 2 Blast Rush, 3 Eruption Orbit, 4 Max Capacity (he pulls his gauntlet's pin: a blast that tears down the street - aim it down from the air) - every one changes in the air. R: Stun Grenade (blinds anyone not guarding). Ult: Dynamight - Howitzer Impact, R Explosive Speed (a blur down the street into a point-blank Explosion), 4 Full-Body Cluster (his last stand against Shigaraki).",
		Color = Color3.fromRGB(255, 132, 36),
		AccentColor = Color3.fromRGB(255, 226, 92),
		CutInCorner = "TopLeft",
		CutInImage = "",
		WalkSpeed = 19,
		JumpPower = 55,
		-- (round 73) BLAST FLIGHT: hold the dash key (Q / Y / the phone's DASH)
		-- - the dash goes off as usual; still held after HoldDelay, he takes
		-- off on his explosions, the way he does in the anime: both palms
		-- thrown back and blasting (propulsion, braking and turning, all from
		-- the hands). A blast every Interval kicks him along wherever he's
		-- looking (BlastSpeed); between them he coasts down to Cruise (Drag),
		-- turns toward the aim (Turn) and sags (Sag studs/s by the next
		-- blast). Off the street he always goes up and out (TakeOffUp). It
		-- runs on the nitro-sweat in his palms: Fuel seconds of it (the SWEAT
		-- bar), back at Regen a second once he's been on the ground
		-- RegenDelay; MinFuel to take off, Cooldown after he drops out, and he
		-- keeps Carry of his speed as he does. The server passes a blast on no
		-- sooner than MinGap after the last. In the ult (Dynamight): Ult's
		-- numbers instead.
		BlastFlight = {
			HoldDelay = 0.22, Interval = 0.32, BlastSpeed = 82, Cruise = 44, Drag = 3, Turn = 5, Sag = 14, TakeOffUp = 0.45,
			Fuel = 3.5, MinFuel = 0.6, Regen = 1.2, RegenDelay = 0.6, Cooldown = 1.5, Carry = 0.55, MinGap = 0.2,
			Ult = { Fuel = 6, BlastSpeed = 100, Cruise = 55 },
		},
		-- (round 92) "increase bakugo damage output, make him playable": the
		-- old "nerfed hard" numbers left him at about 4 damage a second from
		-- his moves - the bottom of the roster (Deku ~7, Iida ~10, All Might
		-- ~10, Todoroki's fire ~14). Back up to upper-middle (~8.6): every
		-- move hits about 40% harder and comes back sooner, and the 4th is
		-- MAX CAPACITY (S/r92/out/bakugo.md has the table)
		Abilities = {
			-- a pinpoint armour-piercing beam that drills through buildings. On
			-- the ground it goes straight out (never into the street at his
			-- feet); in the air he can aim it down at them, and the recoil
			-- kicks him up and back. (round 92) 10 every 9.5 s -> 14 every 7 s
			{
				Id = "APShot", Name = "AP SHOT", Cooldown = 7, Damage = 14, Stun = 0.4, CutIn = false, Range = 110,
				Aim = { Up = 55, Down = 0 }, AirAim = { Up = 55, Down = 80 },
			},
			-- a rocket charge that blasts through whatever's in the way; in the
			-- air it's a dive-bomb on the aim point (Range) and the landing goes
			-- off (Radius round it, Stun). (round 92) 6 + 9 every 12 s -> 8 + 12
			-- every 9 s, the blast a stud wider
			{ Id = "BlastRush", Name = "BLAST RUSH", Cooldown = 9, Damage = 8, FinisherDamage = 12, Radius = 13, Stun = 0.45, CutIn = false, Range = 45 },
			-- palm to the street: it erupts under whoever's in front (Radius,
			-- Range studs ahead) and throws them up; he rockets up after them,
			-- circles them blasting (OrbitHits), and the last blast from above
			-- drives them into the street. In the air: straight for the nearest one.
			-- (round 92) 20 all told every 18 s -> 29 every 14 s; the eruption a
			-- stud wider (a step off its middle no longer slips out of it)
			{
				Id = "BlastOrbit", Name = "ERUPTION ORBIT", Cooldown = 14, Damage = 8, OrbitDamage = 3, OrbitHits = 3, SlamDamage = 12,
				SlamStun = 0.9, CutIn = true, Range = 14, Radius = 9, Launch = 95,
			},
		},
		-- R: a flash so bright it blinds (Blind seconds) anyone caught in it
		-- who isn't guarding; a raised guard takes it on the arms. (round 92)
		-- every 25 s -> 18 s, 3 -> 5, a little wider and longer
		Special = { Id = "StunGrenade", Name = "STUN GRENADE", Cooldown = 18, Damage = 5, CutIn = true, Radius = 22, Blind = 1.3, Stun = 0.8 },
		-- 4: (round 92) MAX CAPACITY - the Grenadier Bracers' pin (chapter 10,
		-- the first battle trial, against Deku: "if it doesn't hit you, you
		-- won't die"). The gauntlets store his sweat; he plants his feet,
		-- levels the right one at them and pulls its pin - everything it's
		-- stored goes off at once, a torrent of explosion down the aim that
		-- tears a trench through whatever stands in it. (It replaces SCORCHED
		-- EARTH, a grab that mostly whiffed.)
		--   The windup: Windup s, the pin out at Pin (back on his gauntlet
		--   PinBack s later). He's braced through it, his feet planted
		--   (WindupSpeed): a hit still lands (x Brace) but nothing staggers him
		--   off it. He aims till it goes (LiveAim: his aim streams up for 6 x
		--   LiveAim + 0.35 s). Aim: on the street it goes straight out or up
		--   (never into the street at his feet); in the air (AirAim) he can
		--   drive it down.
		--   The blast: its front runs out at Speed studs/s to Range (on screen
		--   a chain of explosions rides it from ChainFrom studs out; through
		--   walls: Wall studs blown out of the first one, the trench Carve[1]
		--   .. Carve[2] wide), Width[1] across at the gauntlet to Width[2] at
		--   Range. Whoever it reaches takes Damage, falling to FarScale of it
		--   at Range (Hitstop; GuardDamage more on a raised guard), thrown
		--   Launch[1]..[2] studs/s down the aim (Lift up) - near, hard enough
		--   to go through a wall - and knocked down (Ragdoll, Stun).
		--   Where it meets the street (from the air) it goes off: a Crater-stud
		--   hole and CraterDamage x Damage round it in Radius.
		--   The recoil skids him back Recoil studs/s for RecoilTime (his own
		--   machine; in the air AirRecoil throws him back and up).
		--   The trench: Segments capsules down the line (Budget pieces each,
		--   the Destruction profile Profile).
		--   Look (VFX.GB): Booms explosions and Rings shock rings race out with
		--   the front (half on a low-end machine), the torrent lasts JetLife s;
		--   his screen: the view tightens by Fov[1] in the windup and kicks out
		--   by Fov[2], the camera's jerked up Kick degrees, Shake; anyone
		--   within Near studs of the line: a flash and an impact frame; a
		--   screen whose camera is more than Far studs off the line (round 92
		--   review) draws it on the low-end budget with a third of the
		--   explosions, without the street's detail, the streaks or the
		--   hanging smoke.
		Extra = {
			Id = "MaxCapacity", Name = "MAX CAPACITY", Cooldown = 15, CutIn = true, ActionTime = 0.9,
			Windup = 0.5, Pin = 0.36, PinBack = 2.4, Brace = 0.85, WindupSpeed = 0, LiveAim = 0.05,
			Range = 120, Width = { 8, 30 }, Speed = 520, ChainFrom = 22,
			Damage = 30, FarScale = 0.6, Hitstop = 0.12, GuardDamage = 25, Launch = { 190, 120 }, Lift = { 48, 32 }, Ragdoll = 1.6, Stun = 1.2,
			Aim = { Up = 30, Down = 0 }, AirAim = { Up = 20, Down = 85 },
			Recoil = 34, RecoilTime = 0.22, AirRecoil = { Back = 80, Up = 46 },
			Radius = 16, CraterDamage = 0.7, Crater = 13,
			Carve = { 4.5, 11 }, Segments = 4, Budget = 180, Wall = 11, Profile = "BracerBlast",
			Look = { Booms = 6, Rings = 8, JetLife = 0.42, Fov = { -7, 16 }, Kick = 4, Shake = 3.4, Near = 50, Far = 450 },
		},
		Ult = {
			-- R: EXPLOSIVE SPEED (round 64: back, on R in the ult; outside it R is
			-- the Stun Grenade) - "Explosive Speed: Cluster" (chapter 406 and the
			-- Final Season anime, against All For One): the beads of nitro sweat
			-- stored in his palms race through his whole body and pop. He drops
			-- into a sprinter's crouch, the street cracking under him (WindUp),
			-- then he's a blur straight down the aim, flat out like a missile
			-- (Speed, up to Range; the lane is Width either side). The first one
			-- in it: he flips over as he reaches them (FlipTime), upside down face
			-- to face, his head FlipRise up so it's level with theirs; time slows
			-- right down (SlowMo) as his palm comes up to their face - and the
			-- Explosion goes off point blank (chapter 405): Damage, and
			-- SplashDamage to anyone round them (Radius). Nobody: he skids to a
			-- stop at the end of the lane. (round 76) He says it first: "I'M THE
			-- FINAL BOSS, GOT IT?" - a longer crouch for it (WindUp: 0.7s before).
			-- (round 83) THE BLITZ, a leapfrog down the lane (chapter 406: he
			-- speeds past All For One again and again, blast after blast): his
			-- palm goes off in their face on "GOT" (OpenAt after the press,
			-- OpenDamage) and throws them down the lane; he overtakes them in a
			-- blur and from in front blasts them back and higher (BlastDamage) -
			-- Overtakes times, each leg longer (LegLength + LegGrow a leg) and
			-- quicker (FirstLeg x Ramp, never under MinLeg), Rise higher each
			-- time over an Arc; he hangs back for most of a leg and is past them
			-- in the last DashShare of it, Settle in front before the blast; the
			-- boom of him passing hits too (BoomDamage, from overtake BoomFrom
			-- on). The last overtake ends in the flip, a short time-crawl
			-- (SlowMo, was 1.3) and the Explosion (Damage). Every hit is
			-- unblockable; his cutscene's last shot (BlastShot) runs on after it.
			-- Caught with their back to a wall, the catch slides back down the
			-- lane till the first leg has MinFirstLeg studs (and him room in
			-- front of them). (round 92) 28 all told -> 39 (45 with the ult's
			-- x1.15): the opener 4, each blast 4, each boom 3, the Explosion 14
			Special = {
				Id = "ExplosiveSpeed", Name = "EXPLOSIVE SPEED", Cooldown = 20, Damage = 14, SplashDamage = 8, Radius = 10,
				Range = 75, Width = 4.5, Speed = 320, WindUp = 1.25, SlowMo = 0.5, FlipTime = 0.14, FlipRise = 3, ActionTime = 0.7, CutIn = false,
				OpenAt = 1.5, OpenDamage = 4, Overtakes = 4, FirstLeg = 0.32, Ramp = 0.8, MinLeg = 0.14,
				LegLength = 7, LegGrow = 3, Rise = 1.2, Arc = 0.6, DashShare = 0.4, Settle = 0.06,
				BlastDamage = 4, BoomDamage = 3, BoomFrom = 2, BlastShot = 0.8, MinFirstLeg = 2.5,
			},
			-- 4: FULL-BODY CLUSTER (round 63) - his last stand against Shigaraki,
			-- chapter 362 "Light Fades to Rain" (Episode 149 of the anime).
			-- Beaten half to death, he gets up and WALKS at them (WalkTime,
			-- WalkDistance: nothing touches him, he reads every attack) -
			-- "Izuku... you've gotta win" (Say). Then he's gone - and in their
			-- face, his palm letting off a mass of stored Cluster point blank
			-- (BlinkDamage; Range, in front). He's stored so many beads of
			-- sweat they can't stay in his palms and burst out all over his
			-- body: he's all round them, dodging and blasting from every side
			-- (Hits x HitDamage, one more every other hit), each blast bigger
			-- and quicker than the last (FirstGap, x Ramp). A moment in a white
			-- void on his own screen (VoidTime: All Might, and the card he always
			-- wanted signed), then everything he has left point blank
			-- (FinalDamage, a launch; SplashDamage round them in Radius) - and
			-- the card slips out of his pocket. The beads burst through skin
			-- that isn't made for it: it costs him SelfDamage (never his last
			-- point of health). Nobody in reach: he blasts off down the aim into
			-- one explosion. (round 92) 29 all told -> 44 (the blink 7, the hits 3
			-- and up, the last 18)
			Extra = {
				Id = "FullBodyCluster", Name = "FULL-BODY CLUSTER", Cooldown = 22, CutIn = false,
				WalkTime = 0.9, WalkDistance = 5, Range = 55, Hits = 5, FirstGap = 0.24, Ramp = 0.8, VoidTime = 0.7,
				BlinkDamage = 7, HitDamage = 3, FinalDamage = 18, SplashDamage = 7, Radius = 12, SelfDamage = 8,
				Say = "IZUKU... YOU'VE GOTTA WIN.",
			},
			Name = "DYNAMIGHT",
			Shout = "I'LL BLOW YOU ALL AWAY!!",
			Color = Color3.fromRGB(255, 96, 20),
			AccentColor = Color3.fromRGB(255, 240, 140),
			-- (round 92) DYNAMIGHT hits like the other ults now (it was about
			-- half of Plus Ultra's or Full Cowl 100%'s): 26 s (was 22), every move
			-- harder and sooner
			Duration = 26,
			WalkSpeed = 21,
			JumpPower = 60,
			Abilities = {
				-- (LiveAim: every shot goes where he's aiming right then)
				-- (round 92) 6 x 4 every 12 s -> 6 x 6 every 10 s
				{ Id = "AutoCannon", Name = "AP SHOT: AUTO-CANNON", Cooldown = 10, Damage = 6, Shots = 6, Stun = 0.25, LiveAim = 0.15, CutIn = true },
				-- (round 92) 5 + 20 every 28 s -> 7 + 28 every 20 s
				{ Id = "Cluster", Name = "CLUSTER", Cooldown = 20, Damage = 7, BombStun = 0.35, FinisherDamage = 28, Radius = 32, CutIn = true, Range = 80 },
				-- the real one: up, spinning into a tornado of explosions, and down
				-- on the aim point (Range) - Radius-stud blast, a Crater-stud hole.
				-- (round 92) 32 every 36 s -> 44 every 28 s
				{
					Id = "Howitzer", Name = "HOWITZER IMPACT", Cooldown = 28, Damage = 44, CutIn = false, Range = 110, Radius = 34, Crater = 34,
					Cinematic = true, CinematicArmor = 1.4,
				},
			},
		},
	},

	-- All Might: the Symbol of Peace. Fists and raw power (not kicks and a
	-- toolbox of quirks - that's Deku): wind pressure that levels streets,
	-- a wrestler's grapples, and a hero who's always there in time.
	OneForAll = {
		DisplayName = "ONE FOR ALL",
		Description = "The Symbol of Peace: fists, wind pressure and grapples. True form: Texas Smash, New Hampshire Smash, Carolina Smash, 4 Hero's Counter. R: muscle form - Detroit Smash, Oklahoma Smash, Backdrop Driver, 4 Colorado Smash. Ult: Plus Ultra (4: Weather Changer).",
		Color = Color3.fromRGB(52, 78, 160),
		AccentColor = Color3.fromRGB(226, 214, 160),
		ModeName = "TRUE FORM",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 18,
		JumpPower = 50,
		Abilities = {
			{ Id = "TexasSmash", Name = "TEXAS SMASH", Cooldown = 5.5, Damage = 16, CutIn = false },
			-- fists cocked, then his own punch's wind fires him forward like a
			-- missile: whoever he meets rides his fists the whole way
			-- (TravelTime) and gets the wind he was pushing at the end
			{ Id = "NewHampshireSmash", Name = "NEW HAMPSHIRE SMASH", Cooldown = 7, Damage = 10, FinisherDamage = 14, TravelTime = 0.4, CutIn = false },
			{ Id = "CarolinaSmash", Name = "CAROLINA SMASH", Cooldown = 10, Damage = 20, CutIn = true },
		},
		-- 4 (true form): he stands his ground (Window seconds); a hit that
		-- lands in it doesn't, and for an instant the Symbol of Peace answers
		-- it with a Detroit Smash
		Extra = { Id = "HeroCounter", Name = "HERO'S COUNTER", Cooldown = 12, Damage = 26, Window = 0.9, CutIn = false },
		-- Passive in muscle form / ult: jump again in mid-air for a huge leap,
		-- landing slams the ground (like crossing the city in a few bounds)
		SuperLeap = { Up = 115, Forward = 85, Cooldown = 0.6, LandRadius = 14, LandDamage = 12 },
		-- R special: transform. Duration = seconds in muscle form (0 = no limit),
		-- RecoverTime = wait after powering down before you can transform again.
		Special = {
			Id = "MuscleForm",
			Name = "MUSCLE FORM",
			Form = true,
			Cooldown = 1,
			Duration = 30,
			RecoverTime = 12,
			CutIn = true,
			ResetOnRespawn = true,
			-- his presence (canon: villains froze in terror at it): as he
			-- powers up, anyone within Radius is frozen (Freeze seconds); at
			-- the burst (BurstAt) the steam blast shoves them away. No damage.
			-- (round 73) He grows in heartbeats first: Pulses = { seconds in,
			-- share of the way to his full muscle-form size }.
			-- (round 76: a longer build - 1.35s to the burst before - so the
			-- whole "I AM HERE!" fits in it, "HERE!" on the burst)
			Presence = { Radius = 20, Freeze = 2.0, BurstAt = 1.9, Push = 80, Lift = 30, Pulses = { { 0.6, 0.3 }, { 1.1, 0.55 }, { 1.5, 0.8 } } },
		},
		Alt = {
			DisplayName = "ONE FOR ALL",
			ModeName = "MUSCLE FORM",
			Outfit = true, -- puts on the hero costume (Config.AllMightOutfit)
			Color = Color3.fromRGB(205, 44, 52),
			AccentColor = Color3.fromRGB(255, 212, 64),
			CutInImage = "",
			WalkSpeed = 21,
			JumpPower = 62,
			-- How much bigger he gets. R15 body scale multipliers (R6 avatars use R6Scale uniformly)
			BodyScale = { BodyWidthScale = 1.45, BodyDepthScale = 1.4, BodyHeightScale = 1.4, HeadScale = 1.25, R6Scale = 1.4 },
			Abilities = {
				{ Id = "DetroitSmash", Name = "DETROIT SMASH", Cooldown = 7, Damage = 28, CutIn = false },
				{ Id = "OklahomaSmash", Name = "OKLAHOMA SMASH", Cooldown = 10.5, Damage = 24, CutIn = true },
				-- arms round whoever's in front (Range), over his head and into the
				-- street behind him: a Crater, and a shock (ShockDamage, Radius)
				-- that throws everyone near off their feet
				{
					Id = "BackdropDriver", Name = "BACKDROP DRIVER", Cooldown = 13, Damage = 26, GrabDamage = 6, ShockDamage = 10,
					Range = 9, Radius = 16, Crater = 16, OverTime = 0.55, CutIn = true,
				},
			},
			-- 4 (muscle form + Plus Ultra): an aimed skyscraper-high leap that
			-- crashes down on the aim point, boring through everything on the way
			-- down and cratering the landing. Range = max distance, Height = arc peak.
			Extra = {
				Id = "ColoradoSmash", Name = "COLORADO SMASH", Cooldown = 18, Damage = 42, CutIn = false,
				Range = 160, Height = 105, TravelTime = 1.5, LandRadius = 30, DiveDamage = 18, Cinematic = true,
				-- (round 75) aimed from the sky: SkyCam Height up, Back behind the
				-- view's centre, panned at Pan studs/s
				Hold = { Max = 6, Speed = 0, Toggle = true, Marker = true, MarkerSize = 30, Reach = 400, Color = Color3.fromRGB(255, 210, 80),
					Names = { "COLORADO SMASH: AIM" }, SkyCam = { Height = 95, Back = 40, Pan = 80 } },
			},
		},
		-- Ult forces muscle form (no time limit while it lasts)
		Ult = {
			Name = "PLUS ULTRA",
			Shout = "PLUS... ULTRAAA!!",
			Color = Color3.fromRGB(255, 196, 40),
			AccentColor = Color3.fromRGB(255, 250, 220),
			Duration = 30,
			WalkSpeed = 25,
			JumpPower = 70,
			ForceAlt = true,
			Outfit = true,
			BodyScale = { BodyWidthScale = 1.55, BodyDepthScale = 1.5, BodyHeightScale = 1.5, HeadScale = 1.3, R6Scale = 1.5 },
			-- 4 in the ult: an uppercut at the sky - an updraft sucks everyone
			-- within Radius up (HangTime), the clouds split, then it all comes down
			Extra = {
				Id = "WeatherChanger", Name = "WEATHER CHANGER", Cooldown = 20, Damage = 10, DropDamage = 26,
				Radius = 45, HangTime = 1.1, CutIn = true,
			},
			Abilities = {
				{ Id = "PlusUltraRush", Name = "PLUS ULTRA RUSH", Cooldown = 9, Damage = 5, Hits = 12, FinisherDamage = 20, CutIn = true },
				{ Id = "TexasSmashMax", Name = "TEXAS SMASH: 100%", Cooldown = 12, Damage = 38, CutIn = true },
				-- All of One For All's remaining power in the right fist. (round 78)
				-- The way it went against All For One at Kamino: the left is a decoy
				-- that lands on his face - it has to: Lunge studs in LungeTime (after
				-- LungeStartup) and nobody caught is just a whiff, the ult isn't spent
				-- on it (WhiffCooldown seconds and he can try again). Caught: BuildTime
				-- of "UNITED STATES OF..." while the last embers pour into his right
				-- arm; then the overhand right to the face - an impact frame, everything
				-- stops for FreezeTime - and it drives them down into the street
				-- (SlamTime). The wind pressure craters it and spawns a twister that
				-- tears buildings apart. Then the raised fist, and "You're next."
				{
					Id = "UnitedStatesSmash", Name = "UNITED STATES OF SMASH", Cooldown = 30, Damage = 60, CutIn = false,
					WindDamage = 20, WindRadius = 46,
					-- the tornado: how long it lasts, how tall, how wide at the top,
					-- how far out it drags people in, and its damage to anyone caught
					TwisterTime = 6.5, TwisterHeight = 300, TwisterTopRadius = 110, TwisterPull = 90, TwisterDamage = 10,
					Lunge = 26, LungeTime = 0.32, LungeStartup = 0.16, JabDamage = 6, WhiffCooldown = 5,
					BuildTime = 2.0, FreezeTime = 0.38, SlamTime = 0.12, ActionTime = 0.6,
					-- the ult music dips to this share of its volume under the punch,
					-- then swells back up with the twister
					MusicDuck = 0.15,
					-- (armour through the lunge; a catch armours him to the end)
					Cinematic = true, CinematicArmor = 0.7,
				},
			},
		},
	},

	-- Shoto Todoroki: his right side freezes, his left burns. His ice grows
	-- out of a sheet he lays from his foot (so it's always joined to him,
	-- ledges included); his fire is up close and personal.
	HalfCold = {
		DisplayName = "HALF-COLD HALF-HOT",
		Description = "Right side freezes, left side burns. Ice: Ice Spike, Frost Burst, Glacier Breaker, 4 Ice Slider. R swaps sides. Fire: Flashfire, Flame Pillar, Flashfreeze Heatwave, 4 Jet Kindling (a flame-jet rush into a white-hot punch). Ult: Phosphor - Heaven-Piercing Ice Wall; R Origin: Half-Cold Half-Hot (a glacier wave that has to catch someone, then both sides at once).",
		Color = Color3.fromRGB(70, 150, 230),
		AccentColor = Color3.fromRGB(205, 240, 255),
		ModeName = "ICE SIDE",
		CutInCorner = "BottomLeft",
		CutInImage = "",
		WalkSpeed = 18,
		JumpPower = 50,
		Abilities = {
			{ Id = "IceSpike", Name = "ICE SPIKE", Cooldown = 8.5, Damage = 16, CutIn = false, FreezeTime = 1.6, IceDuration = 3 },
			{ Id = "FrostBurst", Name = "FROST BURST", Cooldown = 9.5, Damage = 14, CutIn = true, FreezeTime = 2, IceDuration = 3 },
			-- a punch drives whoever's in front (Range) back into a wall of ice
			-- that erupts behind them - pinned there PinTime seconds - then a
			-- pillar of ice bursts up under them and shatters the wall. Someone
			-- already frozen solid: the punch shatters their ice (ShatterDamage
			-- on top) and in they go all the same
			{ Id = "GlacierBreaker", Name = "GLACIER BREAKER", Cooldown = 11, Damage = 10, ShatterDamage = 5, PillarDamage = 20, Range = 10, PinTime = 0.55, CutIn = true },
		},
		-- 4 (ice): a ramp of ice shoots out along the aim (Range) and he skates
		-- up it (RideTime), freezing anyone it erupts under, then flies off the lip
		-- (round 81: the ramp stands IceDuration seconds, then breaks up)
		Extra = { Id = "IceSlider", Name = "ICE SLIDER", Cooldown = 9, Damage = 8, FreezeTime = 1, Range = 70, RideTime = 0.75, IceDuration = 3, CutIn = false },
		-- R special: swaps between the ice moveset above and the fire moveset below
		Special = { Id = "SideSwap", Name = "SWAP SIDE", Cooldown = 1.2, Form = true },
		Alt = {
			DisplayName = "HALF-HOT",
			ModeName = "FIRE SIDE",
			Color = Color3.fromRGB(225, 78, 36),
			AccentColor = Color3.fromRGB(255, 208, 96),
			CutInImage = "",
			Abilities = {
				{ Id = "Flashfire", Name = "FLASHFIRE", Cooldown = 5, Damage = 16, CutIn = false, BurnTicks = 3, BurnDamage = 3 },
				{ Id = "FlamePillar", Name = "FLAME PILLAR", Cooldown = 9.5, Damage = 22, CutIn = true, BurnTicks = 4, BurnDamage = 3, Range = 70 },
				{ Id = "Heatwave", Name = "FLASHFREEZE HEATWAVE", Cooldown = 24, Damage = 40, CutIn = true, BurnTicks = 5, BurnDamage = 3 },
			},
			-- 4 (fire): JET KINDLING (canon: his flames compressed to a white-hot
			-- point on the fist - on contact a violent explosion of fire bursts
			-- out of his arm). Flames jet from his elbow and rocket him along
			-- the aim (DashSpeed x DashTime; in the air it follows the aim up
			-- or down too); the first person he reaches takes the white-hot
			-- punch (Damage) and the blast goes on through them, catching
			-- anyone behind (BlastDamage). Nobody reached: the fist goes off
			-- at the end of the jet anyway.
			Extra = {
				Id = "JetKindling", Name = "JET KINDLING", Cooldown = 10, Damage = 22, BlastDamage = 12,
				DashSpeed = 125, DashTime = 0.32, Reach = 6, BlastLength = 22, BurnTicks = 4, BurnDamage = 3, CutIn = true,
			},
		},
		-- Ult uses both sides at once. R doesn't swap sides while it lasts:
		-- (round 81) it's ORIGIN, the ult's own R (Ult.Special below)
		Ult = {
			Name = "PHOSPHOR",
			Shout = "PHOSPHOR!",
			Color = Color3.fromRGB(150, 110, 255),
			AccentColor = Color3.fromRGB(255, 244, 236),
			Duration = 30,
			WalkSpeed = 23,
			JumpPower = 60,
			Abilities = {
				{ Id = "Phosphor", Name = "PHOSPHOR", Cooldown = 8, Damage = 36, CutIn = true, BurnTicks = 5, BurnDamage = 3 },
				{ Id = "GlacialField", Name = "GLACIAL FIELD", Cooldown = 16, Damage = 24, CutIn = true, FreezeTime = 3, IceDuration = 5 },
				-- a glacier from his foot that climbs into the sky as it runs out
				-- ahead of him (Length studs long, fanning out ~170 wide, the spire ~330 tall)
				{
					Id = "IceWall", Name = "HEAVEN-PIERCING ICE WALL", Cooldown = 32, Damage = 42, CutIn = false, FreezeTime = 3.5, IceDuration = 9,
					Length = 200, Cinematic = true, CinematicArmor = 1.4,
				},
			},
			Extra = { Id = "HeatwaveMax", Name = "FLASHFREEZE HEATWAVE: MAXIMUM", Cooldown = 32, Damage = 50, CutIn = false, BurnTicks = 6, BurnDamage = 3, Cinematic = true, CinematicArmor = 1.2 },
			-- (round 81) R in the ult: ORIGIN - Deku vs Todoroki, the Sports
			-- Festival (anime ep. 23 / ch. 38-40), the first time he uses both
			-- halves at once. The freezing wave he opens every fight with: low
			-- and fast along the street (Range studs at WaveSpeed, WaveStartup
			-- after the press, LaneWidth across) - it has to catch someone; nobody
			-- is a whiff, WhiffCooldown seconds and not the move. Caught: caged in
			-- ice where they stand (GlacierDamage) for BuildTime while it plays out
			-- (Beats: shares of BuildTime) - his right side frosted over and
			-- shivering; IGNITION, his left side goes up in a towering plume; ice
			-- pillars erupt round them as a ring of fire races across the street
			-- through them; the left arm swung back, the flame swelling in the
			-- palm - "Thanks." - and the palm thrust (Thrust: the fire's out on its
			-- way to them). Fire meets the frozen air on BuildTime: it expands
			-- (FreezeTime: the impact frames), Damage, a burn and a
			-- ring-out (Launch, Lift); SplashDamage round it (SplashRadius); a
			-- steam whiteout (Blind) for everyone else in SteamRadius, the cloud
			-- clearing over SteamTime.
			-- (round 82) BuildTime 2.8 -> 3.4: IGNITION is a cutscene beat of
			-- its own now (the clip at 2:08.2-2:09.2 - the two hands, the black
			-- and white frames, the starburst), Ignite to Field about 1.3 s.
			-- Workspace attribute OriginPace (absent = 1) plays the whole caught
			-- cutscene that many times slower, for stills (the server scales
			-- Build and Freeze by it; every screen follows Build).
			Special = {
				Id = "ShotoOrigin", Name = "ORIGIN: HALF-COLD HALF-HOT", Cooldown = 34, CutIn = false,
				Range = 48, WaveSpeed = 170, WaveStartup = 0.2, LaneWidth = 9, WhiffCooldown = 6,
				GlacierDamage = 8, BuildTime = 3.4, FreezeTime = 0.3,
				Beats = { Ignite = 0.24, Field = 0.63, Thanks = 0.77, Thrust = 0.88 },
				Damage = 46, Launch = 210, Lift = 65, BurnTicks = 4, BurnDamage = 3,
				SplashDamage = 18, SplashRadius = 38, SteamRadius = 55, SteamTime = 4, Blind = 1.1,
				ActionTime = 0.6, MusicDuck = 0.15, Cinematic = true, CinematicArmor = 0.75,
			},
		},
	},

	-- Tenya Iida: exhaust pipes in his calves - everything he does is a kick,
	-- and every kick is fast
	-- (round 74) back on the public roster
	Engine = {
		DisplayName = "ENGINE",
		Description = "Exhaust-powered calves, all kicks. 1 Recipro Spin, 2 Engine Gatling (barrage, then the heel into the street), 3 Recipro Burst - HOLD for gears 1-3: a dash strike per gear, steered with your camera. R Recipro Extend - the mufflers pulled out of his calves, a sprinter's start, and one rocket of a kick that carries them down the street. 4 Skyward Kick. Ult: Recipro Turbo.",
		Color = Color3.fromRGB(40, 86, 200),
		AccentColor = Color3.fromRGB(196, 222, 255),
		CutInCorner = "BottomLeft",
		CutInImage = "",
		-- (round 73: balanced - still the fastest on his feet, by a little)
		WalkSpeed = 23,
		JumpPower = 55,
		-- (round 85) his calf engines. The server builds them (QuirkServer
		-- addEnginePipes) and every client's exhaust comes out of the same
		-- mouths (VFX.EngineKit), so both read these. Studs on a stock 1x2x1
		-- R6 leg (scaled to the leg), from its centre: +Z is the back of the
		-- calf. A silver housing bulging out of the calf (tapering into the
		-- knee and the ankle), a darker plate on its back with 6 short silver
		-- stubs in 2 columns of 3 (dark bores, mouths pointing back, Splay
		-- degrees out and Droop degrees down), and a gold engine disc on the
		-- outside of the calf. (round 85 review) The housing wraps round the
		-- outside of each calf too (Cheek: Out studs proud of the side, from
		-- Front back to the housing), so his calves read thick from the
		-- front; the stubs are gunmetal on a light plate (dark holes at a
		-- distance); the gold piece is the canon boxy block with 4 round
		-- cylinder ends (Block), on the cheek
		Look = {
			Housing = { Y = -0.3, Height = 0.62, Depth = 0.34, Width = 0.86, Top = 0.2, Bottom = -0.8 },
			Cheek = { Out = 0.14, Front = -0.22 },
			Plate = { Width = 0.68, Height = 0.5 },
			Rows = { -0.11, -0.3, -0.49 }, -- (the stubs' heights; the first column is the outer one)
			Column = 0.2, -- (each column this far out from the middle of the calf)
			StubBase = 0.8, StubLength = 0.26, StubWidth = 0.16, BoreWidth = 0.11,
			Splay = 10,
			Droop = 6,
			Block = { Y = -0.3, Z = 0.2, Height = 0.4, Width = 0.5, Depth = 0.1, End = 0.15, EndLength = 0.07 },
			Metal = Color3.fromRGB(178, 184, 194),
			PlateColor = Color3.fromRGB(214, 218, 226),
			StubColor = Color3.fromRGB(95, 100, 110),
			BoreColor = Color3.fromRGB(34, 36, 42),
			Gold = Color3.fromRGB(205, 165, 65),
			GoldShade = Color3.fromRGB(150, 115, 40),
		},
		Abilities = {
			-- a whirling roundhouse: one kick round him, the second throws them away
			{ Id = "SpinKick", Name = "RECIPRO SPIN", Cooldown = 7, Damage = 6, FinisherDamage = 9, Radius = 11, CutIn = false },
			-- a blur of kicks (Hits, Interval), then an axe kick into the street
			{ Id = "EngineGatling", Name = "ENGINE GATLING", Cooldown = 10, Damage = 2, Hits = 7, Interval = 0.07, FinisherDamage = 10, CutIn = true },
			-- HOLD it: gear 1 at once, gear 2 and gear 3 at Hold.Levels seconds
			-- (slowed to Hold.Speed while it revs). Let go: one dash strike per
			-- gear (DashTime each), steered with the camera; the last one hits
			-- for Finish[gear], the rest for Damage
			{
				Id = "ReciproBurst", Name = "RECIPRO BURST", Cooldown = 13, Damage = 7, Finish = { 10, 13, 18 },
				DashTime = 0.18, DashSpeed = 160, CutIn = false,
				Hold = { Max = 1.6, Levels = { 0.5, 1.1 }, Speed = 8, Names = { "GEAR 1", "GEAR 2", "GEAR 3" }, Color = Color3.fromRGB(110, 180, 255) },
				-- (round 85) the freeze on a hit (both bodies, on screen only):
				-- a dash strike's (0.04, as it was), and the last strike's by
				-- gear - gear 1's as it was (0.1), only ever longer above it
				Hitstop = { Strike = 0.04, Last = { 0.1, 0.11, 0.13 } },
			},
		},
		-- 4: a rising kick that launches them straight up; he hops up after them
		-- (a launcher: they're held up there for him, not knocked down)
		Extra = { Id = "SkywardKick", Name = "SKYWARD KICK", Cooldown = 9, Damage = 10, Launch = 95, NoKnockdown = true, CutIn = false },
		-- (round 75) R: RECIPRO EXTEND - the cooled engines' second wind. He
		-- yanks the mufflers out of his calves (they glow white-blue), drops
		-- into a sprinter's start (Startup) and goes: Speed down the camera's
		-- aim, out to Range. The first one he meets takes the kick (Damage) and
		-- is carried along on his leg (Carry seconds, CarrySpeed) - then the
		-- engines fire again and they're launched (Launch, Lift). Nobody there:
		-- he skids to a stop. Uninterruptible once he's off
		Special = {
			Id = "ReciproExtend", Name = "RECIPRO EXTEND", Cooldown = 16, Damage = 24, Startup = 0.45, Speed = 175, Range = 95,
			Radius = 6, Carry = 0.4, CarrySpeed = 120, Launch = 140, Lift = 55, Uninterruptible = true, CutIn = true,
		},
		-- Ult: the 10-second super-speed state, stretched for gameplay
		Ult = {
			Name = "RECIPRO TURBO",
			Shout = "RECIPRO... TURBO!!",
			Color = Color3.fromRGB(40, 140, 255),
			AccentColor = Color3.fromRGB(220, 244, 255),
			Duration = 20,
			WalkSpeed = 38,
			JumpPower = 60,
			Abilities = {
				{ Id = "TurboKick", Name = "TURBO KICK", Cooldown = 4, Damage = 10, Range = 40, CutIn = false },
				{ Id = "ReciproTurbo", Name = "TURBO RUSH", Cooldown = 10.5, Damage = 10, FinisherDamage = 15, CutIn = true },
				{ Id = "ReciproMax", Name = "RECIPRO: MAXIMUM BURST", Cooldown = 26, Damage = 36, CutIn = false, Cinematic = true, CinematicArmor = 0.6 },
			},
			-- THE PRANK (in the air: LB + RB together - 1 + 4 on a keyboard): the
			-- class rep asks everyone to please stand back, pulls one of the
			-- mufflers out of his calf and lobs it at whoever he's aiming at. It
			-- homes in (Speed). It's a nuke: Damage in the core, EdgeDamage at the
			-- rim of Radius, the city with it (Crater). It never hurts him.
			Prank = {
				Id = "MufflerNuke", Name = "MUFFLER... NUKE?!", Cooldown = 30, CutIn = false, ActionTime = 0.6,
				Range = 180, Speed = 150, Damage = 110, EdgeDamage = 35, CoreRadius = 40, Radius = 200, Crater = 110, WaveSpeed = 480,
			},
		},
	},

	-- Fully awakened: everything he touches with all five fingers crumbles.
	-- The map-wrecker (released: anyone can pick him).
	Decay = {
		DisplayName = "DECAY",
		Description = "Fully awakened. Decay waves eat the ground, finger lances pierce buildings, and Collapse crumbles a whole block. Ult: All For One.",
		Color = Color3.fromRGB(92, 82, 90),
		AccentColor = Color3.fromRGB(214, 62, 66),
		ModeName = "AWAKENED",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 19,
		JumpPower = 55,
		Abilities = {
			-- palm to the ground: a crack of decay races forward and eats everything on it
			{ Id = "DecayWave", Name = "DECAY", Cooldown = 7, Damage = 18, CutIn = false, Range = 64, DecayTicks = 4, DecayDamage = 3 },
			-- lunge with an open hand; whoever it catches starts crumbling
			{ Id = "DecayGrasp", Name = "DECAY GRASP", Cooldown = 9.5, Damage = 16, CutIn = false, DecayTicks = 6, DecayDamage = 3 },
			-- both hands down: the block around him falls apart (no cutscene: it
			-- plays out in the fight)
			{ Id = "Collapse", Name = "COLLAPSE", Cooldown = 21.5, Damage = 32, CutIn = false, Radius = 46, DecayTicks = 5, DecayDamage = 3 },
		},
		-- R: five finger lances that punch straight through buildings. (round
		-- 84) The nearest one they skewer is pinned on them (Pin), then the
		-- rivets pull back into his fingers and reel them in to ReelTo studs
		-- in front of him, still dazed (AfterStun)
		Special = { Id = "RivetStab", Name = "RIVET STAB", Cooldown = 12, Damage = 16, CutIn = false, Range = 110,
			Windup = 0.2, Pin = 0.45, Reel = 0.3, ReelTo = 5, AfterStun = 0.75 },
		-- 4: both hands to the street - it crumbles away in front of him (Range
		-- x Width) and swallows whoever's standing on it to the waist (HoldTime),
		-- decaying while they're stuck
		Extra = { Id = "Sinkhole", Name = "SINKHOLE", Cooldown = 13, Damage = 10, DecayTicks = 4, DecayDamage = 3, Range = 30, Width = 24, HoldTime = 1.5, Sink = 3, CutIn = true },
		Ult = {
			Name = "ALL FOR ONE",
			Shout = "EVERYTHING... CRUMBLES.",
			Color = Color3.fromRGB(150, 30, 44),
			AccentColor = Color3.fromRGB(240, 226, 230),
			Duration = 30,
			WalkSpeed = 22,
			JumpPower = 62,
			Abilities = {
				-- a stolen quirk (All For One's): RADIO WAVES. Black lightning with a
				-- purple edge crackles round his arms, then an electromagnetic
				-- pulse ripples out in a wide fan (Angle degrees either side,
				-- Range studs, the wave travelling at Speed): whoever it reaches
				-- is hurt and hurled back, and it jams them - static all over
				-- their screen for Jam seconds, and
				-- (round 84) their quirk with it: no moves till it clears (M1s,
				-- dashes and the guard still work). Windup: Air Cannon's gold
				-- orb swelling in his palm (ep 119)
				{ Id = "RadioWaves", Name = "RADIO WAVES", Cooldown = 9, Damage = 26, CutIn = true, Range = 85, Angle = 60, Speed = 220, Jam = 2.5, Windup = 0.45 },
				-- lances erupt from his back and arms in every direction; (round
				-- 84) whoever they skewer is lifted Lift studs on them, held
				-- LiftHold seconds (round 85: was "Hold", which the client read as a held move), then slammed into the street (SlamDamage)
				{ Id = "RivetStorm", Name = "RIVET STORM", Cooldown = 13.5, Damage = 16, CutIn = true, Range = 90,
					Windup = 0.3, Lift = 9, LiftHold = 0.7, SlamTime = 0.16, SlamDamage = 10, SlamRagdoll = 1.6 },
				-- the full cinematic: decay spreads across a whole district
				{ Id = "TotalDecay", Name = "TOTAL DECAY", Cooldown = 81, Damage = 55, CutIn = false, Radius = 120, DecayTicks = 8, DecayDamage = 4, Cinematic = true, CinematicArmor = 2.6 },
			},
		},
	},

	-- Ninth holder: three distinct physical attacks, with inherited quirks on V.
	FullCowl = {
		DisplayName = "ONE FOR ALL: 9TH",
		Description = "1 Delaware Smash: Air Force - two flicked air bullets. 2 St. Louis Smash: Air Force - a spinning kick that fires a blade of air. 3 Manchester Smash - a somersault into an axe kick that craters the street. 4: Blackwhip; R cycles inherited quirks (Smokescreen, Float, Fa Jin - squat to store it, Gearshift - shift up to TOP GEAR, then Transmission into Detroit Smash: Quintuple, 100%: Detroit Smash). Dash, then Blackwhip: the Blackwhip slingshot. Float: you stay on your feet till you jump, then fly where you look - dash to fire Air Force behind you. G: Full Cowl 100% - Danger Sense dodges for you, and 4 is the 1,000,000% Delaware Detroit Smash.",
		Color = Color3.fromRGB(27, 164, 126),
		AccentColor = Color3.fromRGB(188, 255, 231),
		ModeName = "FULL COWL 45%",
		CutInCorner = "BottomLeft",
		CutInImage = "",
		-- (round 73: balanced - he was the fastest, highest-jumping, hardest-hitting)
		WalkSpeed = 22,
		JumpPower = 58,
		Abilities = {
			-- DELAWARE SMASH: AIR FORCE - flicks from alternate hands, each one a
			-- bullet of compressed air (Shots of them, Gap apart, Damage each);
			-- the last blows them away
			{ Id = "DelawareSmash", Name = "DELAWARE SMASH: AIR FORCE", Cooldown = 7, Damage = 6, Shots = 2, Gap = 0.15, Range = 85, Startup = 0.12, ActionTime = 0.45, AimAssist = 3, CutIn = false },
			-- ST. LOUIS SMASH: AIR FORCE - a spinning Shoot Style kick (Damage up
			-- close) that fires a blade of compressed air (BladeDamage, out to
			-- Range, BladeWidth across)
			{ Id = "StLouisSmash", Name = "ST. LOUIS SMASH: AIR FORCE", Cooldown = 9, Damage = 16, BladeDamage = 12, Range = 45, BladeWidth = 16, Startup = 0.18, ActionTime = 0.52, Aim = { Up = 35, Down = 50 }, AimAssist = 7, CutIn = false },
			-- MANCHESTER SMASH: leap, somersault, axe kick - the street craters
			-- (LandRadius) and the shockwave rolls out further (ShockRadius)
			{ Id = "ManchesterSmash", Name = "MANCHESTER SMASH", Cooldown = 12, Damage = 24, ShockDamage = 6, Range = 44, Height = 20, TravelTime = 0.5, LandRadius = 16, ShockRadius = 30, ActionTime = 0.82, CutIn = false },
		},
		Special = { Id = "QuirkCycle", Name = "NEXT QUIRK", Cycle = true, Cooldown = 0.4, CutIn = false },
		Extras = {
			-- (round 75) DASH, THEN BLACKWHIP (Dash.Window seconds after a dash
			-- starts): the BLACKWHIP SLINGSHOT - the tendrils latch on ahead and the
			-- tension catapults him (Speed, out to Range, Time at most), clipping
			-- whoever's in the way (Damage); Blackwhip's cooldown x CooldownScale
			{ Id = "Blackwhip", Name = "BLACKWHIP", Cooldown = 10, Damage = 12, Range = 60, ActionTime = 0.5, NoKnockdown = true, CutIn = false,
				Dash = { Window = 0.5, Speed = 165, Range = 85, Time = 0.55, Lift = 0.12, Damage = 8, Radius = 5, CooldownScale = 0.6 } },
			{ Id = "Smokescreen", Name = "SMOKESCREEN", Cooldown = 15, Damage = 6, Radius = 24, Duration = 5, ActionTime = 0.26, CutIn = false },
			-- (round 75) FLOAT (Nana Shimura's): gravity lets go of him - but he
			-- stays on his feet until he jumps (within Window seconds). Then he's
			-- up (Lift) and flying for Duration: where the camera looks, at Speed
			-- (easing in at Accel), Space to rise (Rise), looking down to sink; the
			-- DASH key flicks an Air Force behind him (Boost, every BoostEvery). He
			-- can come down and jump up again while it lasts. Gravity comes back
			-- gently (Settle seconds) at the end
			{ Id = "Float", Name = "FLOAT", Cooldown = 15, Damage = 0, Window = 8, Duration = 7, Lift = 18, Speed = 34, Accel = 4, Rise = 22,
				Boost = 95, BoostEvery = 0.55, Settle = 1.2, ActionTime = 0.15, CutIn = false },
			-- FA JIN (the 3rd user's quirk): press 4 and he squats - down, up,
			-- down, up, each one quicker than the last - and the kinetic energy
			-- piles up in his legs, glowing red (Hold.Levels); press 4 again (or
			-- squat to Max) and it all goes out through them at once: he rockets
			-- forward (Launch: Min -> Max studs over Time seconds) straight into a
			-- Detroit Smash - MinScale of the power at a tap, all of it squatted
			-- right up: Damage, a Range-stud gale Width across
			{
				Id = "FaJinSmash", Name = "FA JIN: DETROIT SMASH", Cooldown = 18, Damage = 36, MinScale = 0.5, Range = 120, Width = 28,
				ActionTime = 0.9, CutIn = false,
				Launch = { Min = 16, Max = 62, Time = 0.24 },
				Hold = { Max = 2.4, Levels = { 0.8, 1.6 }, Speed = 4, Toggle = true, Names = { "FA JIN", "FA JIN: STORING", "FA JIN: FULL POWER" }, Color = Color3.fromRGB(255, 70, 60) },
			},
			-- GEARSHIFT (Kudo's, the 2nd user's quirk: it changes the speed of
			-- whatever he touches, himself included, glowing blue): press 4 to
			-- shift up a gear like a driver working the stick - LOW, SECOND,
			-- THIRD, TOP - each one faster on his feet (SpeedPerGear) and harder
			-- hitting (DamagePerGear, everything he does) for GearTime seconds
			-- after the last shift. At TOP GEAR, press 4 again: OVERDRIVE into
			-- TRANSMISSION - he's on whoever he's aiming at (Range) and every
			-- punch comes faster than the last (Hits, from Interval, x Speedup a
			-- punch, down to MinInterval), then DETROIT SMASH: QUINTUPLE - five
			-- Detroit Smashes (Quintuple x QuintupleDamage) - and the last sends
			-- them flying (FinisherDamage), geared down (Slow for SlowTime). The
			-- recoil locks him up (Recoil), the gears drop back to neutral, and
			-- the quirk needs RushCooldown to recover.
			{
				Id = "Gearshift", Name = "GEARSHIFT", Cooldown = 0.8, Damage = 3, Hits = 6, Quintuple = 5, QuintupleDamage = 4, FinisherDamage = 16, Range = 60,
				Interval = 0.2, Speedup = 0.78, MinInterval = 0.04, SpeedPerGear = 0.07, DamagePerGear = 0.04, TopGear = 4, GearTime = 12, Recoil = 0.6,
				Slow = 0.5, SlowTime = 3, RushCooldown = 22, ActionTime = 0.25, CutIn = false, NoKnockdown = true,
				Gears = { "LOW GEAR", "SECOND GEAR", "THIRD GEAR", "TOP GEAR" },
			},
			-- 100%: DETROIT SMASH - One For All at 100% through one arm, before he
			-- could spread it out: the street in front of him (Range x Width) blown
			-- away (Damage) after a Startup wind-up
			{
				-- (round 75: the arm holds now - no break, no recoil)
				Id = "HundredSmash", Name = "100%: DETROIT SMASH", Cooldown = 20, Damage = 30, Range = 100, Width = 26, Startup = 0.55,
				ActionTime = 1, CutIn = false,
			},
		},
		Ult = {
			Name = "FULL COWL 100%",
			Shout = "ONE FOR ALL... FULL COWL 100%!!",
			Color = Color3.fromRGB(64, 255, 174),
			AccentColor = Color3.fromRGB(235, 255, 246),
			Duration = 30,
			WalkSpeed = 30,
			JumpPower = 76,
			-- DANGER SENSE (the 4th user's quirk), while he's at 100%: a hit
			-- coming for him sets the hair on his neck on end and he's already
			-- moved - once every Cooldown seconds (Grace: untouchable for that long)
			DangerSense = { Cooldown = 11, Grace = 0.35 },
			-- 4 at 100%: the Overhaul fight's flick-and-punch, with Eri
			-- rewinding his arm - a gale that levels a street
			Extra = {
				Id = "MillionSmash", Name = "1,000,000% DELAWARE DETROIT SMASH", Cooldown = 22, Damage = 50, CutIn = false,
				Range = 240, Width = 64, Charge = 1.45, Cinematic = true, CinematicArmor = 1.8,
			},
			Abilities = {
				-- the lightning blitz: a kick from every side (Hits, Gap apart, Orbit
				-- studs round them), everyone in the storm (Radius), then the big one
				{ Id = "GearshiftRush", Name = "100%: SHOOT STYLE RUSH", Cooldown = 9, Damage = 4, Hits = 7, Gap = 0.07, Orbit = 4.6, Radius = 6.5, FinisherDamage = 18, Range = 26, ActionTime = 0.85, CutIn = false },
				{ Id = "BlackwhipSlam", Name = "BLACKWHIP: COLLAPSE", Cooldown = 12, Damage = 24, CatchDamage = 6, Range = 55, MaxTargets = 4, ActionTime = 0.98, CutIn = false },
				-- the Overhaul fight's finale (Eri on his back): the kick launches them
				-- (Lift studs, RiseTime); up there he punches faster and faster (Hits,
				-- from Interval down by Speedup a hit to MinInterval), then the fists
				-- come raining down (RainHits over RainTime) and drive them into the
				-- street - and it all explodes (FinisherDamage; ShockDamage round it).
				-- A whiff recovers quickly; a confirmed catch extends the action.
				{
					Id = "FistRain", Name = "INFINITE 100%", Cooldown = 26, LaunchDamage = 10, Damage = 2, Hits = 16, Interval = 0.12,
					Speedup = 0.86, MinInterval = 0.035, RiseTime = 0.3, Lift = 26, RainHits = 4, RainDamage = 4, RainTime = 0.6,
					FinisherDamage = 22, ShockDamage = 14, Range = 24, Radius = 18, AimAssist = 7, ActionTime = 0.38, CutIn = false,
				},
			},
		},
	},

	-- Kai Chisaki, the young head of the Shie Hassaikai. Overhaul takes apart
	-- anything he touches and puts it back together however he likes: people
	-- burst and reform, the street erupts into spikes and walls, and he can
	-- rebuild his own body. His ult is the fused form (he merged with his
	-- subordinates): taller, a second pair of arms, the mask melted into a beak.
	Overhaul = {
		DisplayName = "OVERHAUL",
		Description = "Takes apart whatever he touches. Disassemble, raise spikes, or trap foes in stone. R: Restore. Ult: Fusion - chase foes with pillars, seize them with fused arms, and become the Katsukame kaiju.",
		Color = Color3.fromRGB(128, 22, 40),
		AccentColor = Color3.fromRGB(255, 150, 150),
		ModeName = "SHIE HASSAIKAI",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 18,
		JumpPower = 52,
		Abilities = {
			-- a lunge with a bare hand: whoever he touches cracks red, comes apart and is put back together
			{ Id = "Disassemble", Name = "DISASSEMBLE", Cooldown = 7, Damage = 20, CutIn = false, Stun = 1.2 },
			-- palm on the ground: three cracks race out in a fan (Spread degrees
			-- between the lines) and the street erupts into three short lines of
			-- spikes, Range studs long (one hit per target, whichever line gets them)
			{ Id = "SpikeRush", Name = "SPIKE FAN", Cooldown = 9.5, Damage = 20, CutIn = false, Range = 40, Lanes = 3, Spread = 26 },
			-- reassembly: walls of stone rise around the aim point, then spikes lance inward
			{ Id = "SpikePrison", Name = "SPIKE PRISON", Cooldown = 17.5, Damage = 30, CutIn = true, Range = 60, Radius = 12, PrisonHold = 1.6 }, -- (round 85: was Hold, which the client reads as a held move)
		},
		-- R: he takes his own body apart and rebuilds it - heals, and burns / decay stop
		Special = { Id = "Restore", Name = "RESTORE", Cooldown = 27, CutIn = false, Heal = 45 },
		-- 4: the street under him is taken apart and rebuilt as a pillar that
		-- throws him up (Lift), spikes bursting out round its foot (Radius)
		Extra = { Id = "PillarRise", Name = "PILLAR RISE", Cooldown = 9, Damage = 12, Radius = 12, Lift = 95, CutIn = false },
		Ult = {
			Name = "FUSION",
			Shout = "OVERHAUL.",
			Color = Color3.fromRGB(170, 26, 44),
			AccentColor = Color3.fromRGB(255, 196, 170),
			Duration = 28,
			WalkSpeed = 21,
			JumpPower = 56,
			BodyScale = { BodyWidthScale = 1.3, BodyDepthScale = 1.3, BodyHeightScale = 1.35, HeadScale = 1.15, R6Scale = 1.35 },
			Abilities = {
				-- all four hands down: stone pillars burst out of the ground one after another toward the aim
				{ Id = "PillarBarrage", Name = "PILLAR BARRAGE", Cooldown = 8, Damage = 10, Hits = 6, FinisherDamage = 18, CutIn = true, Range = 90 },
				-- the fused arms lash out, reel in up to three foes, and crush them into the street
				{ Id = "MassGrasp", Name = "FUSION: MASS GRASP", Cooldown = 14, Damage = 10, FinisherDamage = 18, Range = 55, MaxTargets = 3, CutIn = true },
				-- The Deku fight: he fuses with Katsukame and the rubble into a
				-- towering kaiju (limbs reaching out of its back, the beak mask
				-- grown enormous). While it lasts (Duration) his punches are giant
				-- slams, he crushes whatever he walks through, and he takes only
				-- DamageTaken of every hit. Rising out of the ground blasts Radius.
				{
					Id = "Kaiju", Name = "FUSION: KATSUKAME", Cooldown = 40.5, Damage = 36, CutIn = false, Radius = 32, Duration = 14,
					SlamDamage = 24, SlamRadius = 14, SlamCooldown = 0.85, DamageTaken = 0.5,
					Cinematic = true, CinematicArmor = 2,
				},
			},
			-- 4: the whole block cracks red, comes apart, and is rebuilt as a forest of spikes
			Extra = { Id = "TotalOverhaul", Name = "TOTAL OVERHAUL", Cooldown = 54, Damage = 62, CutIn = false, Radius = 85, Cinematic = true, CinematicArmor = 1.6 },
		},
	},

	-- The strongest. Limitless bends space: Blue drags everything into one
	-- point, Red throws it all away, and Hollow Purple erases whatever it
	-- touches. DevOnly like Decay (testers and players they grant).
	Limitless = {
		DisplayName = "LIMITLESS",
		Description = "The strongest. Blue drags the street in, Red blasts it away, Hollow Purple erases a line of the city. R: Infinity. 4: Blink. Ult: Unlimited Void.",
		Color = Color3.fromRGB(34, 44, 96),
		AccentColor = Color3.fromRGB(150, 210, 255),
		ModeName = "SIX EYES",
		CutInCorner = "TopLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 21,
		JumpPower = 58,
		Abilities = {
			-- an attraction point: pulls people and rubble in and crushes them together
			{ Id = "LapseBlue", Name = "LAPSE: BLUE", Cooldown = 8, Damage = 4, Ticks = 6, CutIn = false, Range = 70, Radius = 24, Duration = 1.8 },
			-- a repulsion point fired from the fingertip: everything flies away
			{ Id = "ReversalRed", Name = "REVERSAL: RED", Cooldown = 11, Damage = 30, CutIn = true, Range = 80, Radius = 20 },
			-- Blue + Red = imaginary mass: erases a straight line through the city
			{ Id = "HollowPurple", Name = "HOLLOW PURPLE", Cooldown = 29.5, Damage = 48, CutIn = false, Range = 220, Radius = 10, Cinematic = true, CinematicArmor = 1.4 },
		},
		-- R: Infinity - for a few seconds nothing can reach him (hits stop just short)
		Special = { Id = "Infinity", Name = "INFINITY", Cooldown = 19, CutIn = false, Duration = 4 },
		-- 4: step through space to the aim point
		Extra = { Id = "Blink", Name = "BLINK", Cooldown = 4, Damage = 0, CutIn = false, Range = 45 },
		-- G: Domain Expansion. Everyone caught inside is paralysed at first
		-- (infinite information) and slowed for as long as they stay in it.
		Ult = {
			Name = "UNLIMITED VOID",
			Shout = "DOMAIN EXPANSION... UNLIMITED VOID.",
			Color = Color3.fromRGB(110, 70, 220),
			AccentColor = Color3.fromRGB(240, 245, 255),
			Duration = 25,
			WalkSpeed = 24,
			JumpPower = 62,
			DomainRadius = 60,
			DomainStun = 4,
			DomainSlow = 9,
			Abilities = {
				{ Id = "BlueMax", Name = "BLUE: MAXIMUM OUTPUT", Cooldown = 12, Damage = 5, Ticks = 10, CutIn = true, Range = 80, Radius = 40, Duration = 3 },
				{ Id = "RedMax", Name = "RED: MAXIMUM OUTPUT", Cooldown = 13.5, Damage = 44, CutIn = true, Range = 100, Radius = 32 },
				{ Id = "PurpleMax", Name = "HOLLOW PURPLE: 200%", Cooldown = 54, Damage = 75, CutIn = false, Range = 320, Radius = 18, Cinematic = true, CinematicArmor = 1.8 },
			},
		},
	},

	-- Mirio Togata, LEMILLION: Permeation. Everything passes through him -
	-- punches, walls, the street - and when he lets it back in, whatever he's
	-- inside pushes him out, fast. He sinks through the ground and shoots out
	-- of it wherever he likes, and reads a fight (Prediction) well enough to
	-- let the hit pass through and be behind the guy who threw it.
	-- His costume (hair fibres, so it phases with him): white top with
	-- "1000000" across the chest in yellow, red cape and gloves, dark blue
	-- pants, white boots, and the visor pushed up on his forehead.
	Lemillion = {
		DisplayName = "LEMILLION",
		Description = "Permeation. Sink through the street and burst out anywhere, blind-spot strikes and a counter that lets the hit pass through. R: Permeate - on the ground, walk through walls; in the air, fall through everything and pick where the ground spits you out. Ult: Phantom Menace - he comes up out of the street in a golden ring, phases through some hits, and 4 is PHANTOM MENACE: ENDGAME.",
		Color = Color3.fromRGB(214, 40, 44),
		AccentColor = Color3.fromRGB(255, 214, 60),
		ModeName = "PERMEATION",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 20,
		JumpPower = 55,
		Abilities = {
			-- drop through the street, travel under it, and shoot out of it at the
			-- aim point: anyone standing over the exit takes an uppercut
			{ Id = "DeepDive", Name = "DEEP DIVE", Cooldown = 8, Damage = 16, CutIn = false, Range = 55, Radius = 9 },
			-- phase straight through the first person ahead, then hit them from
			-- behind, the side and above before they can turn round
			{ Id = "PhantomMenace", Name = "PHANTOM MENACE", Cooldown = 12, Damage = 7, FinisherDamage = 10, Hits = 3, NoKnockdown = true, CutIn = true, Range = 40 },
			-- Prediction: a stance. Whatever hits him in it passes straight through,
			-- and he comes up out of the ground behind whoever threw it
			{ Id = "Prediction", Name = "PREDICTION", Cooldown = 16, Damage = 24, CutIn = false, Duration = 1, Range = 60 },
		},
		-- R: PERMEATE. On the ground: for Duration he goes straight through
		-- walls - never the floor - and nothing lands on him (attacking lets the
		-- world back in). In the air: he lets everything go and drops through
		-- roofs, floors and the street; under it he steers where he'll come
		-- out (a marker, up to DiveRange from where he went under, ChooseTime
		-- to pick - R, click or jump to go) and the ground spits him out there:
		-- Launch up into the air, throwing aside whoever's on the spot.
		Special = {
			Id = "Permeate", Name = "PERMEATE", Cooldown = 14, CutIn = false, Duration = 3,
			DiveSpeed = 110, DiveRange = 80, ChooseTime = 2.5, MarkerSpeed = 70, Launch = 105, SpitDamage = 8, SpitRadius = 9,
		},
		-- 4: his arm sinks into the street and comes up under whoever's ahead
		-- (Range): it drags them down to the waist (HoldTime), then flings them up
		Extra = { Id = "PhantomGrasp", Name = "PHANTOM GRASP", Cooldown = 12, Damage = 6, LaunchDamage = 14, Range = 35, HoldTime = 1.2, Sink = 2.6, Launch = 90, CutIn = false },
		Ult = {
			Name = "PHANTOM MENACE",
			Shout = "I'M GONNA SAVE A MILLION PEOPLE... LEMILLION!!",
			Color = Color3.fromRGB(255, 196, 40),
			AccentColor = Color3.fromRGB(255, 250, 220),
			Duration = 25,
			WalkSpeed = 27,
			JumpPower = 65,
			-- while it lasts, some hits simply pass through him
			PhaseChance = 0.3,
			-- (round 75) 4: PHANTOM MENACE: ENDGAME - he sinks out of sight and
			-- comes up out of the street under everyone round him (Radius, Targets
			-- at most) one after another (Gap), each one launched (Damage, Lift);
			-- then out of thin air above them all, and down through the sky into
			-- the street in the middle of them - it erupts (FinisherDamage, Blast)
			Extra = {
				Id = "PhantomEndgame", Name = "PHANTOM MENACE: ENDGAME", Cooldown = 26, Damage = 12, FinisherDamage = 24, Radius = 45, Targets = 5,
				Gap = 0.42, Lift = 70, Blast = 26, Cinematic = true, CinematicArmor = 2.6, CutIn = false,
			},
			Abilities = {
				{ Id = "DeepDive", Name = "DEEP DIVE: SURPRISE ATTACK", Cooldown = 4, Damage = 20, CutIn = false, Range = 90, Radius = 14 },
				-- blind spot after blind spot: he's everywhere around them at once
				{ Id = "PhantomRush", Name = "PHANTOM MENACE: BLIND SPOTS", Cooldown = 12, Damage = 4, Hits = 8, FinisherDamage = 20, NoKnockdown = true, CutIn = true, Range = 50 },
				-- up out of the ground under them, then out of thin air above them
				{
					Id = "MillionPunch", Name = "LEMILLION: ONE MILLION", Cooldown = 32.5, Damage = 38, LaunchDamage = 20, CutIn = false,
					Range = 60, Radius = 16, Cinematic = true, CinematicArmor = 1.6,
				},
			},
		},
	},

	-- Tamaki Amajiki, SUNEATER (the Big 3): Manifest. Whatever he's eaten,
	-- he can grow on his own body - octopus tentacles for fingers (takoyaki),
	-- clamshell armour (clams), spider crab claws that crush steel, chicken
	-- talons and wings - as many at once as he likes, as big as he likes.
	-- It runs on what's still in his STOMACH: every manifestation uses some
	-- of it (Cost), and the fuller he is the stronger they are (Stomach.Empty
	-- x at 0 up to Stomach.Full x when full). R: a snack from his pouches.
	-- He fights like the anime (and a friend's sketch): a chicken leg to kick
	-- you into the air, an octopus arm to snatch you out of it, a tentacle
	-- that slams you about - blocky, two suckers on every segment - and a
	-- swordfish's bill for a hand (a clamshell hammer in the air).
	-- His costume: black bodysuit with beige plating on the arms and
	-- shoulders, a white tunic, hood and cape, a silver front mask on the
	-- collar, a thin beige mask with a purple lens, a purple carrier vest with
	-- brown straps and food pouches - and bare feet. Pointed ears, dark indigo
	-- hair spilling out of the hood.
	Manifest = {
		DisplayName = "SUNEATER",
		Description = "Manifest: grow whatever he's eaten. 1 Chicken Kick launches them up, 2 Tako Snatch catches them in the air and slams them down (at a building: it ZIPS him there - jump on the way to point-launch off it), 3 Tako Thrash slams them right, left, right, 4 Swordfish impales and flings them straight ahead. In the air: 1 Bamboo Sweep, 3 Urchin Spikes, 4 Clam Hammer - and falling, he glides on chicken wings. Runs on his STOMACH - R: eat a snack. Ult: Vast Hybrid Chimera.",
		Color = Color3.fromRGB(88, 64, 150),
		AccentColor = Color3.fromRGB(238, 228, 204),
		ModeName = "MANIFEST",
		CutInCorner = "TopLeft",
		CutInImage = "",
		WalkSpeed = 20,
		JumpPower = 55,
		-- the stomach meter: moves cost from it, power scales with it
		Stomach = { Max = 100, Empty = 0.8, Full = 1.1 },
		-- (round 59) his WINGS: falling for more than After seconds, chicken
		-- wings grow out of his back and he glides - his fall held to
		-- FallSpeed studs/s - until he lands (or MaxTime)
		Glide = { After = 0.5, FallSpeed = 14, MaxTime = 12 },
		Abilities = {
			-- CHICKEN KICK: his leg becomes a huge chicken leg (canon: chicken
			-- talons strengthened with octopus muscle) and he kicks straight up -
			-- whoever's in front (Range) is launched into the air (Launch studs/s,
			-- like Spider-Man's Amazing Combo) and held there (Stun) for a follow-up
			-- (a launcher: not knocked down)
			-- (round 59) in the air: BAMBOO SWEEP (Air) - a stalk of bamboo grows
			-- out of his arm and sweeps round him, Arc degrees from his left to
			-- his right, tilted down at the street (Tilt), growing as it goes -
			-- Length0 studs (medium) to Length1 (huge) at the end of the swing -
			-- then swings back round to where it started, shrinking, and goes back
			-- into his arm. Everyone it passes through is hit once each way
			-- (Damage out, ReturnDamage back). He hangs in the air while it goes.
			-- (round 72) It stays on the ground: the stalk points down as far as
			-- it takes (up to MaxTilt degrees) for its tip to drag along the
			-- street, Skim studs up - growing up to Reach studs if he's high up -
			-- and at the end of the swing it lies there, full size, for HoldTime
			-- seconds before it swings back.
			{ Id = "ChickenKick", Name = "CHICKEN KICK", Cooldown = 7, Damage = 10, Launch = 92, Stun = 1.3, Range = 8, Cost = 4, ActionTime = 0.45, NoKnockdown = true, CutIn = false,
				AirActionTime = 1.25, Air = { Name = "BAMBOO SWEEP", Damage = 12, ReturnDamage = 8, WindUp = 0.12, SwingTime = 0.45, HoldTime = 0.3, ReturnTime = 0.35, Arc = 240, Tilt = 16, MaxTilt = 72, Skim = 0.4, Reach = 30, Length0 = 8, Length1 = 22, Thick0 = 0.8, Thick1 = 1.7, Width = 2.5 } },
			-- TAKO SNATCH, the follow-up: an octopus arm shoots out along the aim
			-- (up too - it bends toward someone in the air, AimAssist degrees),
			-- catches the first one it reaches and slams them into the street in
			-- front of him. Caught in mid-air: AirBonus x the damage
			-- (round 60) nobody to catch, but it hits a building: THE ZIP
			-- (Spider-Man's web zip / point launch). The tentacle latches on
			-- wherever it struck (Zip.Range) and reels him in along a straight
			-- line to it - quick, and quicker as he goes (Speed studs/s, full
			-- speed after Accel seconds). He ends up ON it: struck near the top
			-- of a wall (within Ledge studs of it) he goes over the lip onto the
			-- roof; lower down he clings to the wall (Cling seconds) and drops
			-- off. JUMP on the way (or on the wall) and he doesn't stop: POINT
			-- LAUNCH - flung up (LaunchUp) and on (LaunchForward) over it. A zip
			-- only costs Zip.Cooldown seconds of Tako Snatch's cooldown.
			{ Id = "TakoSnatch", Name = "TAKO SNATCH", Cooldown = 8, Damage = 6, SlamDamage = 10, AirBonus = 1.4, Range = 45, AimAssist = 22, Cost = 4, ActionTime = 0.6, CutIn = false,
				Zip = { Range = 95, Speed = 150, Accel = 0.18, MaxTime = 1.4, MinDistance = 8, Ledge = 12, Cling = 0.45, LaunchUp = 88, LaunchForward = 58, Cooldown = 2.5 } },
			-- TAKO THRASH, the octopus move itself: a huge tentacle grabs the one
			-- in front (Range) and slams them into the street to his right, his
			-- left, then his right again (SlamDamage, SlamDamage, FinalDamage) -
			-- and lets them fly off the last one. (Round 59) In the air: URCHIN
			-- SPIKES - sea urchin spines burst out of every inch of him, UrchinRadius
			-- round (UrchinDamage, knocked away), and pull back in
			{ Id = "TakoThrash", Name = "TAKO THRASH", Cooldown = 11, Damage = 4, SlamDamage = 6, FinalDamage = 10, Range = 16, Cost = 6, ActionTime = 1.35, CutIn = false,
				AirActionTime = 0.6, AirName = "URCHIN SPIKES", UrchinDamage = 14, UrchinRadius = 11, UrchinSpines = 44 },
		},
		-- R: something from his pouches (takoyaki, clams, a drumstick) - the
		-- stomach fills by Refill, and it's food: Heal health
		Special = { Id = "Snack", Name = "SNACK", Cooldown = 12, Refill = 50, Heal = 10, CutIn = false },
		-- 4: SWORDFISH (canon: Fat Gum fed him swordfish for the raid): his
		-- hand becomes a swordfish's bill - a lunge that impales the first one
		-- in line (Range), lifts them on it, then flings them straight on ahead
		-- of him (round 59: no longer off to the side), ragdolled. In the air: CLAM HAMMER - both fists become one clamshell
		-- hammer over his head and he brings it down (Spider-Man's mid-air
		-- overhead slam in Marvel Rivals): whoever's under it is spiked into the
		-- street (HammerDamage), and the landing jolts anyone round it
		-- (ShockDamage, HammerRadius)
		Extra = {
			Id = "Swordfish", Name = "SWORDFISH", Cooldown = 9, Damage = 9, ThrowDamage = 9, Range = 15,
			HammerDamage = 16, HammerRadius = 9, ShockDamage = 6, Cost = 4, ActionTime = 0.7, CutIn = false,
		},
		Ult = {
			Name = "VAST HYBRID CHIMERA",
			Shout = "NOW THAT CRUSHING WEIGHT... MAKES ME STRONGER!",
			Color = Color3.fromRGB(120, 56, 170),
			AccentColor = Color3.fromRGB(196, 255, 226),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 58,
			BodyScale = { BodyWidthScale = 1.12, BodyDepthScale = 1.12, BodyHeightScale = 1.12, HeadScale = 1.12, R6Scale = 1.12 },
			-- (everything he manifests at full size: the stomach isn't touched)
			Abilities = {
				-- KRAKEN: shells over his face and body, and his arms become eight
				-- giant tentacles that thrash round him in a rotating wave
				{ Id = "Kraken", Name = "CHIMERA KRAKEN", Cooldown = 10, Damage = 5, Hits = 4, FinisherDamage = 14, Radius = 30, CutIn = true },
				-- CENTAUR: bull legs and horns, vines with hard fruit swinging off
				-- his arms - a stampede down a lane (Range long, Width wide)
				{ Id = "Centaur", Name = "CHIMERA CENTAUR", Cooldown = 12, Damage = 20, Range = 70, Width = 14, CutIn = true },
				-- OCTOPUS MIRAGE into SCORPIUS TOXIN: he fades into the street
				-- (Vanish seconds, nearly invisible), comes up behind whoever's
				-- nearest the aim (Range) and a scorpion tail stings them: Damage,
				-- then Poison ticks of PoisonDamage
				{ Id = "OctopusMirage", Name = "OCTOPUS MIRAGE: SCORPIUS TOXIN", Cooldown = 16, Damage = 16, Poison = 5, PoisonDamage = 3, Vanish = 1.4, Range = 45, CutIn = false },
			},
			-- 4: PLASMA CANNON - everything he's ever eaten in one arm (zebra
			-- tarantula, dragonfruit, spider crab, sika deer, alligator, sea
			-- turtle, locust, sea urchin, bamboo...) and a beam out of it that
			-- goes through walls. HOLD to charge it (three levels), let go to fire.
			Extra = {
				Id = "PlasmaCannon", Name = "PLASMA CANNON", Cooldown = 26, Damage = 26, LevelDamage = { 26, 36, 50 }, LevelWidth = { 9, 13, 18 }, Range = 260,
				CutIn = false, Hold = { Max = 2, Levels = { 0.7, 1.4 }, Speed = 5, Names = { "PLASMA CANNON", "PLASMA CANNON: II", "PLASMA CANNON: MAX" }, Color = Color3.fromRGB(196, 255, 226) },
			},
		},
	},

	-- Shinji Nishiya, KAMUI WOODS (No. 7): Arbor. His body is wood and it
	-- grows - branches out of his arms that bind, lash and carry him between
	-- the buildings. He looks (the anime): a navy bodysuit, wooden arms, a
	-- wooden helmet with a tan riveted band down the middle and white eyes,
	-- tan riveted armbands, a wooden belt with a bundle of red roses on it,
	-- wooden knee guards and boots. Everything he grows is blocky timber.
	Arbor = {
		DisplayName = "KAMUI WOODS",
		Description = "Arbor: his wooden body grows into branches. 1 Lacquered Chain Prison binds them, 2 Timber Slingshot throws them up, slings him off a building and slams them down, 3 Root Breaker, 4 Great Tree Hammer. R: Branch Swing (needs something taller than him). Ult: Great Forest.",
		Color = Color3.fromRGB(128, 82, 46),
		AccentColor = Color3.fromRGB(232, 204, 150),
		ModeName = "ARBOR",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 19,
		JumpPower = 55,
		Abilities = {
			-- LACQUERED CHAIN PRISON (his move in canon): branches shoot out of his
			-- arm along the aim, wrap the first one they reach (Range, bending
			-- AimAssist degrees toward them) in a wooden cage and hold them (Bind)
			{ Id = "ChainPrison", Name = "LACQUERED CHAIN PRISON", Cooldown = 11, Damage = 8, Range = 50, Bind = 1.6, AimAssist = 12, ActionTime = 0.45, CutIn = false },
			-- TIMBER SLINGSHOT: he grabs the one in front (Range) and hurls them up
			-- (Lift studs); a branch shoots to the nearest building (no building
			-- within AnchorRange: a trunk bursts out of the street behind him),
			-- he slingshots himself off it, over them, and drives them into the
			-- street - SlamDamage, and ShockDamage to anyone round it (Radius)
			{
				Id = "TimberSlingshot", Name = "TIMBER SLINGSHOT", Cooldown = 14, LaunchDamage = 6, SlamDamage = 20, ShockDamage = 8,
				Radius = 12, Range = 12, Lift = 24, AnchorRange = 45, ActionTime = 0.4, CutIn = false,
			},
			-- ROOT BREAKER: a line of blocky wooden stakes bursts out of the street
			-- along the aim (Range long, Width wide) and throws them up (Launch)
			{ Id = "RootBreaker", Name = "ROOT BREAKER", Cooldown = 8, Damage = 13, Range = 42, Width = 8, Launch = 55, ActionTime = 0.4, CutIn = false },
		},
		-- R: BRANCH SWING - a branch shoots out to something taller than him
		-- (within Range) and he swings off it like a web-slinger (SwingTime at
		-- most, SwingSpeed along the arc), letting go flying: ExitSpeed along
		-- the swing plus ExitLift up, and the fling keeps its speed for Carry
		-- seconds (steering bends it, it doesn't eat it). Nothing tall enough
		-- in reach: it won't go. R again mid-swing lets go and swings off the
		-- next one.
		Special = {
			Id = "BranchSwing", Name = "BRANCH SWING", Cooldown = 2, Range = 110, SwingTime = 1.3, SwingSpeed = 95, ExitSpeed = 90,
			ExitLift = 10, Carry = 0.7, Swing = true, CutIn = false,
		},
		-- 4: GREAT TREE HAMMER - his arm grows into a huge blocky trunk and he
		-- brings it down on the street in front (Range long, Width wide)
		Extra = { Id = "TreeHammer", Name = "GREAT TREE HAMMER", Cooldown = 12, Damage = 20, Range = 20, Width = 10, ActionTime = 0.8, CutIn = false },
		Ult = {
			Name = "GREAT FOREST",
			Shout = "ARBOR... GREAT FOREST!",
			Color = Color3.fromRGB(226, 128, 44), -- (an autumn forest: his leaves are orange)
			AccentColor = Color3.fromRGB(238, 216, 156),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 58,
			BodyScale = { BodyWidthScale = 1.1, BodyDepthScale = 1.1, BodyHeightScale = 1.1, HeadScale = 1.1, R6Scale = 1.1 },
			Abilities = {
				-- THOUSAND-BRANCH PRISON: branches burst out of the street all round
				-- him (Radius) and cage everyone in it (Bind), then crush (CrushDamage)
				{ Id = "ThousandBranch", Name = "THOUSAND-BRANCH PRISON", Cooldown = 14, Damage = 8, CrushDamage = 14, Radius = 28, Bind = 1.8, CutIn = true },
				-- the slingshot, bigger: higher, harder, a wider crater
				{
					Id = "GreatSlingshot", Name = "GREAT TIMBER SLINGSHOT", Cooldown = 12, LaunchDamage = 8, SlamDamage = 26, ShockDamage = 12,
					Radius = 18, Range = 14, Lift = 30, AnchorRange = 55, ActionTime = 0.4, CutIn = true,
				},
				-- TIMBER TORRENT: a wave of logs and trunks rolls down a lane
				-- (Range long, Width wide), bowling everyone over
				{ Id = "TimberTorrent", Name = "TIMBER TORRENT", Cooldown = 12, Damage = 18, Range = 80, Width = 16, ActionTime = 0.6, CutIn = true },
			},
			-- 4: SEQUOIA SPEAR - a giant tree bursts out of the street under the
			-- aim point (Range) and spears whoever's there (Radius) into the sky
			Extra = { Id = "SequoiaSpear", Name = "SEQUOIA SPEAR", Cooldown = 18, Damage = 28, Range = 70, Radius = 9, Launch = 110, ActionTime = 0.6, CutIn = true },
		},
	},

	-- Atsuhiro Sako, MR. COMPRESS (League of Villains): Compress. Anything he
	-- touches shrinks into a marble he can pocket, and pops back out full
	-- size wherever he lets go of it (the training camp: Bakugo and
	-- Tokoyami in his pocket). A stage magician - top hat, mask, cane,
	-- "Ladies and gentlemen!" - who fights with the city itself: pieces of
	-- it as marbles in his pocket (up to Marbles.Max), thrown back at people
	-- as rubble. A pocketed piece stays gone from the map till it's thrown.
	Compress = {
		DisplayName = "MR. COMPRESS",
		Description = "Compress: R pockets a piece of the street as a marble (3 at a time). 1 Rubble Throw hurls one back full size, 2 Surprise Attack (the cane trick), 3 Vanishing Act compresses THEM and flicks the marble away, 4 Magician's Choice. Marbles in his pocket add a hit to his moves. Ult: Showtime - the spotlights come on, marbles orbit him and refill his pocket, and 4 is the GRAND FINALE.",
		Color = Color3.fromRGB(176, 84, 30), -- (his burnt-orange coat)
		AccentColor = Color3.fromRGB(150, 214, 255), -- (marble glass)
		ModeName = "COMPRESS",
		CutInCorner = "TopLeft",
		CutInImage = "",
		WalkSpeed = 19,
		JumpPower = 55,
		-- the pocket: Max marbles; R takes a ball of Radius studs of the map
		-- within Reach; holding any adds BonusDamage as another hit on moves 2-4
		Marbles = { Max = 3, Radius = 5, Reach = 16, BonusDamage = 4 },
		Abilities = {
			-- RUBBLE THROW: a marble lobbed at the aim point (Range); it pops
			-- back to full size on the way down and the piece of the city lands
			-- on them (Damage, Radius). Empty pocket: a rock off the street
			-- (RockDamage, one target)
			{ Id = "RubbleThrow", Name = "RUBBLE THROW", Cooldown = 7, Damage = 16, RockDamage = 8, Radius = 7, Range = 60, ThrowSpeed = 90, ActionTime = 0.45, CutIn = false },
			-- SURPRISE ATTACK: the cane's pommel in the face (Damage, Stun). With
			-- room in his pocket, the trick: the cane shrinks into a marble he
			-- drops at their feet, a straight punch (PunchDamage), and the cane
			-- pops back out under their chin (CaneDamage) - up they go - and he
			-- catches it coming down
			{ Id = "SurpriseAttack", Name = "SURPRISE ATTACK", Cooldown = 9, Damage = 7, Stun = 0.5, PunchDamage = 6, CaneDamage = 9, Range = 7, ActionTime = 0.4, CutIn = false },
			-- VANISHING ACT: a hand on whoever's in front (Range) and THEY'RE the
			-- marble in his palm, untouchable. (Round 59) He keeps it: he's free
			-- to walk about with it (Hold.Speed) and aim - a ring on his screen
			-- shows where it'll land - and 3 again flicks it there (Throw studs at
			-- most; at Hold.Max it goes by itself). They pop back out there, into
			-- the street (Damage; SplashDamage round the spot). Knocked down or
			-- stunned holding it, he drops it and they pop out at his feet.
			{ Id = "VanishingAct", Name = "VANISHING ACT", Cooldown = 12, Damage = 18, SplashDamage = 6, Range = 8, Held = 4, Throw = 60, ActionTime = 0.6, CutIn = false,
				Hold = { Max = 4, Speed = 14, Toggle = true, Marker = true, Names = { "VANISHING ACT" }, Color = Color3.fromRGB(255, 160, 60) } },
		},
		-- R: COMPRESS - the piece of the city he's pointing at, into his pocket
		Special = { Id = "CompressMap", Name = "COMPRESS", Cooldown = 5, CutIn = false },
		-- 4: MAGICIAN'S CHOICE (Ultra Rumble's move): he compresses HIMSELF - a
		-- puff of smoke where he stood, the marble flies to the aim point
		-- (Range, Speed) and he pops back out there, throwing off whoever's on
		-- the spot (Radius, Damage). Untouchable on the way.
		Extra = { Id = "MagiciansChoice", Name = "MAGICIAN'S CHOICE", Cooldown = 10, Damage = 8, Radius = 6, Range = 40, Speed = 160, CutIn = false },
		Ult = {
			Name = "SHOWTIME",
			Shout = "LADIES AND GENTLEMEN... IT'S SHOWTIME!",
			Color = Color3.fromRGB(230, 120, 40),
			AccentColor = Color3.fromRGB(255, 240, 200),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 58,
			Abilities = {
				-- GRAND ILLUSION - MARBLE STORM: a fan of marbles (Count) thrown down
				-- the aim, each one a piece of the city coming down (Damage, Radius)
				{ Id = "MarbleStorm", Name = "GRAND ILLUSION: MARBLE STORM", Cooldown = 11, Damage = 12, Count = 7, Radius = 6, Range = 55, CutIn = true },
				-- CURTAIN CALL: he takes a whole slab of the city, compressed on the
				-- spot, and lets it drop out of the sky onto the aim point (Range;
				-- Damage, Radius)
				{ Id = "CurtainCall", Name = "CURTAIN CALL", Cooldown = 14, Damage = 30, Radius = 16, Range = 60, CutIn = true },
				-- DISAPPEARING ACT: everyone round him (Radius) is a marble in his
				-- hand for Held seconds; then he throws the lot into the street in
				-- front of him and they pop out in a heap (Damage)
				{ Id = "DisappearingAct", Name = "DISAPPEARING ACT", Cooldown = 16, Damage = 22, Radius = 20, Held = 1.2, CutIn = true },
			},
			-- 4: the same trick, further and harder
			-- (round 75) a marble back in his pocket every Refill seconds while it lasts
			Refill = 3,
			-- 4: THE GRAND FINALE - everyone round him (Radius) is a marble in his
			-- hand; he juggles them (Juggle seconds), throws the lot straight up
			-- (Height) and they come back down full size, all at once, into the
			-- street (Damage; SplashDamage round each one) in a rain of confetti
			Extra = {
				Id = "GrandFinale", Name = "THE GRAND FINALE", Cooldown = 24, Damage = 26, SplashDamage = 8, Radius = 30, Juggle = 1.4,
				Height = 70, Fall = 0.7, Cinematic = true, CinematicArmor = 2.2, CutIn = false,
			},
		},
	},

	-- (round 69) Jin Bubaigawara, TWICE (League of Villains): Double. Anything
	-- he has the measurements of he can make a copy of - himself included -
	-- out of a mud that holds its shape until it's hit hard enough, then
	-- melts back into sludge. The measuring tapes in his red wristbands whip
	-- out sharp enough to cut ice, and he throws knives. His doubles are real
	-- bodies: anyone can hit them, his own hits pass through them, and they go
	-- for whoever's nearest that isn't him (Ultra Rumble: Self Duplicate,
	-- Dagger Shot, Foot Boost; the ult is Sad Man's Parade).
	-- (round 70) off the public roster for now: a dev character
	Double = {
		DevOnly = true,
		DisplayName = "TWICE",
		Description = "Double: R makes a double of himself that fights for him (2 at a time - they melt when they're hit enough). 1 Dagger Shot: knives down the aim, and his doubles throw too. 2 Tape Dash: the tape zips him along the aim into a slash. 3 Measure: the tape lashes the first one in line and reels them in - measured, his next R makes a double of THEM that fights on his side. 4 Double Cross swaps him with his double nearest the aim (none out: he throws one there). Ult: Sad Man's Parade.",
		Color = Color3.fromRGB(46, 46, 52), -- (the black bodysuit)
		AccentColor = Color3.fromRGB(214, 44, 52), -- (the red wristbands)
		ModeName = "DOUBLE",
		CutInCorner = "TopLeft",
		CutInImage = "",
		WalkSpeed = 20,
		JumpPower = 56,
		-- his doubles: Max out at once (the ult: Ult.Special.Max). Each has
		-- Health, lasts Life seconds, runs at Speed for the nearest enemy
		-- within Sight studs and hits from Reach for Damage (a double of an
		-- enemy: EnemyDamage) every Every seconds, stunning Stun; it melts
		-- into mud over Melt seconds
		Clones = { Max = 2, Health = 32, Life = 16, Speed = 21, Sight = 70, Reach = 4.2, Damage = 4, EnemyDamage = 5, Every = 0.8, Stun = 0.35, Melt = 0.7 },
		Abilities = {
			-- DAGGER SHOT: Knives in quick succession (Gap) down the aim (Range,
			-- Speed); each one Damage and slows them to SlowTo for SlowTime.
			-- Every double of his throws one at the same spot too
			{ Id = "DaggerShot", Name = "DAGGER SHOT", Cooldown = 7, Damage = 4, Knives = 3, Gap = 0.1, Range = 70, Speed = 190, SlowTo = 9, SlowTime = 1.4, ActionTime = 0.45, CutIn = false },
			-- TAPE DASH (Ultra Rumble's Foot Boost): the tape shoots out down the
			-- aim - up the side of a building too - and zips him along it (Range
			-- in Time), knife out: the first one in his way takes Damage, Stun
			{ Id = "TapeDash", Name = "TAPE DASH", Cooldown = 8, Damage = 9, Stun = 0.9, Range = 36, Time = 0.32, ActionTime = 0.45, CutIn = false },
			-- MEASURE: the tape lashes out (Range) and wraps the first one in
			-- line (Damage), reels them in to Pull studs in front of him (held
			-- Bind seconds) - measured for Measured seconds: his next R makes a
			-- double of THEM
			{ Id = "MeasureTape", Name = "MEASURE", Cooldown = 10, Damage = 7, Range = 38, Pull = 4.5, Bind = 0.9, Measured = 25, ActionTime = 0.55, CutIn = false },
		},
		-- R: DOUBLE - a double of himself (or of whoever he's measured) steps
		-- out of him and goes for the nearest enemy
		Special = { Id = "Double", Name = "DOUBLE", Cooldown = 5, CutIn = false },
		-- 4: DOUBLE CROSS - which one's the real one? He swaps places with his
		-- double nearest the aim (within Range); none out, he throws one there
		-- (Toss studs at most) instead
		Extra = { Id = "DoubleCross", Name = "DOUBLE CROSS", Cooldown = 9, Range = 90, Toss = 40, CutIn = false },
		Ult = {
			Name = "SAD MAN'S PARADE",
			Shout = "SAD MAN'S PARADE!",
			Color = Color3.fromRGB(120, 72, 44), -- (the mud)
			AccentColor = Color3.fromRGB(214, 44, 52),
			Duration = 24,
			WalkSpeed = 22,
			JumpPower = 58,
			-- the awakening: Burst doubles pour out of him on the spot
			Burst = 4,
			Abilities = {
				-- PARADE: a column of doubles (Count) stampedes down the aim (Range,
				-- Speed, Width), trampling whoever's in the way (Damage, once each)
				{ Id = "ParadeMarch", Name = "PARADE", Cooldown = 10, Damage = 6, Count = 8, Range = 55, Speed = 38, Width = 5, CutIn = true },
				-- DAGGER STORM: he and every double throw Knives at the aim spot
				{ Id = "DaggerStorm", Name = "DAGGER STORM", Cooldown = 9, Damage = 4, Knives = 4, Gap = 0.08, Range = 80, Speed = 210, SlowTo = 8, SlowTime = 1.6, CutIn = true },
				-- DOGPILE: every double of his (and Count more out of the ground)
				-- piles onto the first one in front of him (Range): Damage a
				-- double, then the heap melts and bursts (BurstDamage)
				{ Id = "Dogpile", Name = "DOGPILE", Cooldown = 14, Damage = 3, Count = 6, Range = 45, BurstDamage = 14, CutIn = true },
			},
			-- R: more doubles at once (Max), quicker
			Special = { Id = "Double", Name = "DOUBLE", Cooldown = 2.5, Max = 6, CutIn = false },
			-- 4: the swap, further and quicker
			Extra = { Id = "DoubleCross", Name = "DOUBLE CROSS", Cooldown = 5, Range = 140, Toss = 60, CutIn = false },
		},
	},

	-- (round 74) PRIME DEKU - the Ninth at the end of the war: every quirk
	-- One For All ever held, all of them at once. Gearshift speed makes him a
	-- blur: he's gone before you see him move, and back behind you (Toji
	-- Fushiguro's flash step). Dev only: he's meant to be too much.
	PrimeDeku = {
		DisplayName = "PRIME DEKU",
		Description = "Dev: every quirk One For All ever held, all at once. 1 Flash Step: he's gone - aim where he comes back and press 1 again; anyone in the ring gets him BEHIND them. 2 Blackwhip Reel: whips catch everyone in front and reel them into a St. Louis Smash. 3 Air Force Storm: he floats up and rains air bullets on the aim. R Danger Sense: hit him in it and he's already behind you. 4 Vestige Smash: the ones before him bring a fist down on the aim. Ult: One For All: Prime (2 Flash Step Chain, 3 Delaware Detroit Smash).",
		Color = Color3.fromRGB(20, 120, 88),
		AccentColor = Color3.fromRGB(120, 255, 190),
		ModeName = "ONE FOR ALL: PRIME",
		CutInCorner = "BottomLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 26,
		JumpPower = 70,
		Abilities = {
			-- FLASH STEP: he's gone - a crack of green lightning where he stood,
			-- untouchable. A ring on your screen follows your aim (Range studs
			-- out at most, Radius across); press 1 again (at Hold.Max it goes by
			-- itself) and he's back there. Someone in the ring: he's BEHIND them
			-- - their camera and his close in on it - and the kick lands (Damage,
			-- they're launched). Nobody there: he lands in a shockwave
			-- (MissDamage, MissRadius).
			{
				Id = "PrimeFlashStep", Name = "FLASH STEP", Cooldown = 8, Damage = 30, MissDamage = 8, MissRadius = 10, Range = 75, Radius = 11,
				Launch = 150, Lift = 55, Ragdoll = 2, ActionTime = 0.2, CutIn = false, Uninterruptible = true,
				Hold = { Max = 2.6, Speed = 0, Toggle = true, Marker = true, MarkerSize = 22, Names = { "FLASH STEP: AIM" }, Color = Color3.fromRGB(80, 255, 170) },
			},
			-- BLACKWHIP REEL: six whips of black energy fan out (Range, Spread
			-- degrees), catch up to MaxTargets (CatchDamage each), reel them in
			-- to him and a St. Louis Smash spin kick blows them all away (Damage)
			{ Id = "BlackwhipReel", Name = "BLACKWHIP REEL", Cooldown = 10, Damage = 20, CatchDamage = 6, Range = 58, Spread = 50, MaxTargets = 4, ActionTime = 0.9, CutIn = false },
			-- AIR FORCE STORM: Float lifts him (Lift studs) and he flicks Shots
			-- air bullets down on the aim (Range studs away at most), each one
			-- Damage in a Splash-stud burst anywhere within Radius of the spot
			{ Id = "AirForceStorm", Name = "AIR FORCE STORM", Cooldown = 11, Damage = 5, Shots = 12, Gap = 0.07, Splash = 7, Radius = 13, Range = 90, Lift = 14, ActionTime = 1.1, CutIn = false },
		},
		-- R: DANGER SENSE - he waits for it (Window seconds). A hit coming in
		-- doesn't land: he's already behind whoever threw it and the kick
		-- does (Damage)
		Special = { Id = "DangerCounter", Name = "DANGER SENSE", Cooldown = 10, Damage = 22, Window = 1, CutIn = false },
		-- 4: VESTIGE SMASH - the ones who held it before him, a colossal
		-- ghostly fist out of the sky onto the aim point (Range): Damage in
		-- Radius, a Crater
		Extra = { Id = "VestigeSmash", Name = "VESTIGE SMASH", Cooldown = 16, Damage = 30, Range = 95, Radius = 22, Crater = 20, Delay = 0.85, CutIn = true },
		Ult = {
			Name = "ONE FOR ALL: PRIME",
			Shout = "EVERYONE... LEND ME YOUR POWER!!",
			Color = Color3.fromRGB(90, 255, 180),
			AccentColor = Color3.fromRGB(240, 255, 250),
			Duration = 25,
			WalkSpeed = 32,
			JumpPower = 80,
			Abilities = {
				-- the flash step, further and quicker
				{
					Id = "PrimeFlashStep", Name = "FLASH STEP: AFTERIMAGE", Cooldown = 4, Damage = 36, MissDamage = 12, MissRadius = 14, Range = 110, Radius = 14,
					Launch = 175, Lift = 60, Ragdoll = 2.2, ActionTime = 0.2, CutIn = false, Uninterruptible = true,
					Hold = { Max = 2.6, Speed = 0, Toggle = true, Marker = true, MarkerSize = 28, Names = { "FLASH STEP: AIM" }, Color = Color3.fromRGB(150, 255, 210) },
				},
				-- FLASH STEP CHAIN (Toji's six steps): behind everyone within Range
				-- (up to Targets), one after another - a kick each (Damage), and the
				-- last one sends them all flying (FinisherDamage)
				{ Id = "FlashStepChain", Name = "FLASH STEP CHAIN", Cooldown = 12, Damage = 10, FinisherDamage = 18, Targets = 5, Range = 85, Gap = 0.32, ActionTime = 0.3, CutIn = true, Uninterruptible = true, CinematicArmor = 0.4 },
				-- the last fight's punch: the eight before him at his back, the
				-- gale down the aim (Range x Width) after a Charge
				{
					Id = "VestigeDDS", Name = "1,000,000%: DELAWARE DETROIT SMASH", Cooldown = 28, Damage = 52, Range = 260, Width = 70, Charge = 1.5,
					CutIn = false, Cinematic = true, CinematicArmor = 1.9,
				},
			},
			Extra = { Id = "VestigeSmash", Name = "VESTIGE SMASH: ALL EIGHT", Cooldown = 10, Damage = 38, Range = 130, Radius = 30, Crater = 28, Delay = 0.75, CutIn = true },
		},
	},

	-- (round 74) PRIME ALL MIGHT - the Symbol of Peace in his prime, before
	-- the wound: always the muscle, always in the costume, always leaping.
	-- He's there before the danger is. Dev only.
	PrimeMight = {
		DisplayName = "PRIME ALL MIGHT",
		Description = "Dev: the Symbol of Peace at his peak - always in muscle form (jump again in the air to leap). 1 Missouri Smash: a lariat at the speed of sound. 2 Texas Smash: Hurricane - a punch that leaves a twister down the street. 3 Detroit Smash: Prime. R I Am Here: he leaps out of sight - aim his landing, R again, and anyone under it looks up into the sun. 4 Plus Ultra: the USJ punches. Ult: Symbol of Peace (3 United States of Smash).",
		Color = Color3.fromRGB(40, 70, 180),
		AccentColor = Color3.fromRGB(255, 212, 64),
		ModeName = "PRIME",
		CutInCorner = "TopRight",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 24,
		JumpPower = 72,
		Outfit = true, -- (the hero costume, always)
		BodyScale = { BodyWidthScale = 1.5, BodyDepthScale = 1.45, BodyHeightScale = 1.45, HeadScale = 1.25, R6Scale = 1.45 },
		-- jump again in mid-air: a huge leap (always, not just in a form)
		SuperLeap = { Up = 125, Forward = 95, Cooldown = 0.5, LandRadius = 16, LandDamage = 14, Always = true },
		Abilities = {
			-- MISSOURI SMASH: a lariat at the speed of sound down the aim (Range
			-- in Time): everyone on the way clotheslined (Damage) and blown off
			-- their feet; a sonic boom after him
			{ Id = "MissouriSmash", Name = "MISSOURI SMASH", Cooldown = 7, Damage = 20, Range = 60, Time = 0.3, Width = 8, ActionTime = 0.5, CutIn = false },
			-- TEXAS SMASH: HURRICANE - the punch's wind becomes a twister lying
			-- down the street (Range x Width): it drags whoever's in it along
			-- (Damage over Time seconds) and throws them out the far end
			{ Id = "HurricaneSmash", Name = "TEXAS SMASH: HURRICANE", Cooldown = 10, Damage = 18, Ticks = 5, Range = 140, Width = 26, Time = 1.1, ActionTime = 0.6, CutIn = true },
			-- DETROIT SMASH: PRIME - the street in front of him (Range x Width), gone
			{ Id = "PrimeDetroit", Name = "DETROIT SMASH: PRIME", Cooldown = 12, Damage = 30, Range = 120, Width = 40, ActionTime = 0.7, CutIn = true },
		},
		-- R: I AM HERE - he leaps out of sight. A ring on your screen follows
		-- your aim (Range at most, Radius across); R again (at Hold.Max it goes
		-- by itself) and he comes down there like a meteor. Anyone under it
		-- looks up and sees him against the sun, then the Detroit Smash from
		-- above (Damage); everyone near the landing gets the shock (SplashDamage)
		Special = {
			Id = "IAmHereLeap", Name = "I AM HERE!", Cooldown = 12, Damage = 30, SplashDamage = 12, Range = 160, Radius = 12, Splash = 24, Crater = 18,
			ActionTime = 0.2, CutIn = false, Uninterruptible = true,
			Hold = { Max = 3, Speed = 0, Toggle = true, Marker = true, MarkerSize = 24, Reach = 330, Names = { "I AM HERE: AIM" }, Color = Color3.fromRGB(255, 212, 64) },
		},
		-- 4: PLUS ULTRA (the USJ): the first one in front (Range) is caught and
		-- takes Hits punches, every one past 100% (Damage), then the last one
		-- sends them through the roof of the sky (FinisherDamage)
		Extra = { Id = "PlusUltraUSJ", Name = "PLUS ULTRA!", Cooldown = 18, Damage = 2, Hits = 24, Interval = 0.05, FinisherDamage = 24, Range = 12, Launch = 60, Lift = 190, ActionTime = 0.4, CutIn = true, Uninterruptible = true, CinematicArmor = 2 },
		Ult = {
			Name = "SYMBOL OF PEACE",
			Shout = "WHY? BECAUSE I AM HERE!!",
			Color = Color3.fromRGB(255, 196, 40),
			AccentColor = Color3.fromRGB(255, 250, 220),
			Duration = 25,
			WalkSpeed = 28,
			JumpPower = 80,
			Outfit = true,
			BodyScale = { BodyWidthScale = 1.6, BodyDepthScale = 1.55, BodyHeightScale = 1.55, HeadScale = 1.3, R6Scale = 1.55 },
			Abilities = {
				{ Id = "MissouriSmash", Name = "MISSOURI SMASH: SONIC", Cooldown = 4, Damage = 26, Range = 85, Time = 0.32, Width = 11, ActionTime = 0.45, CutIn = false },
				{ Id = "HurricaneSmash", Name = "TEXAS SMASH: TYPHOON", Cooldown = 7, Damage = 24, Ticks = 6, Range = 200, Width = 36, Time = 1.3, ActionTime = 0.6, CutIn = true },
				-- the real one (All Might's own, bigger)
				{
					Id = "PrimeUSS", Name = "UNITED STATES OF SMASH", Cooldown = 26, Damage = 60, CutIn = false,
					WindDamage = 24, WindRadius = 56,
					TwisterTime = 7.5, TwisterHeight = 360, TwisterTopRadius = 140, TwisterPull = 110, TwisterDamage = 12,
					-- (round 78: only on a hit - see United States of Smash)
					Lunge = 30, LungeTime = 0.32, LungeStartup = 0.14, JabDamage = 8, WhiffCooldown = 5,
					BuildTime = 2.0, FreezeTime = 0.4, SlamTime = 0.12, ActionTime = 0.6, MusicDuck = 0.15,
					Cinematic = true, CinematicArmor = 0.7,
				},
			},
			Special = {
				Id = "IAmHereLeap", Name = "I AM HERE!!", Cooldown = 7, Damage = 38, SplashDamage = 16, Range = 220, Radius = 16, Splash = 32, Crater = 26,
				ActionTime = 0.2, CutIn = false, Uninterruptible = true,
				Hold = { Max = 3, Speed = 0, Toggle = true, Marker = true, MarkerSize = 32, Reach = 330, Names = { "I AM HERE: AIM" }, Color = Color3.fromRGB(255, 240, 150) },
			},
			Extra = { Id = "PlusUltraUSJ", Name = "PLUS ULTRA: 300 SMASHES", Cooldown = 12, Damage = 2, Hits = 32, Interval = 0.04, FinisherDamage = 30, Range = 14, Launch = 70, Lift = 220, ActionTime = 0.4, CutIn = true, Uninterruptible = true, CinematicArmor = 2.2 },
		},
	},

	-- (round 74) DIO (JoJo Part 3, a guest - dev only): THE WORLD. A Stand
	-- that fights beside him (it throws his M1s, like Crazy Diamond), knives
	-- by the dozen, a vampire's hunger - and time itself: ZA WARUDO stops it
	-- for everyone but him. Whatever he does to someone while it's stopped
	-- lands all at once when it starts again.
	TheWorld = {
		DisplayName = "DIO",
		Description = "Dev: THE WORLD. 1 Muda Muda: the Stand's rush. 2 Knives: a fan of them (stopped in the air in stopped time, until it moves again). 3 Vampire: a hand on their head and he drinks. R ZA WARUDO: time stops for everyone but him - every hit he lands in it arrives when it starts again. 4 Space Ripper Stingy Eyes. Ult: DIO's World (2 Knife Ring, 3 ROAD ROLLER DA!).",
		Color = Color3.fromRGB(226, 182, 48),
		AccentColor = Color3.fromRGB(46, 110, 96),
		ModeName = "THE WORLD",
		CutInCorner = "TopLeft",
		CutInImage = "",
		DevOnly = true,
		Stand = true, -- (a Stand fights beside him)
		StandReach = 3, -- the M1s are the Stand's, from out in front of him
		WalkSpeed = 21,
		JumpPower = 58,
		Abilities = {
			-- MUDA MUDA: the Stand's rush (Hits of Damage, Interval apart, out to
			-- Range, breaking BreakDepth into whatever's in front), then MUDA!
			{ Id = "MudaRush", Name = "MUDA MUDA MUDA!", Cooldown = 6, Damage = 3, Hits = 16, Interval = 0.075, FinisherDamage = 16, Range = 7.5, BreakDepth = 16, CutIn = false },
			-- KNIVES: a fan of them (Knives, Spread degrees) down the aim (Range,
			-- Speed); each one Damage and a flinch. In stopped time they stop in
			-- the air a few studs out and go on when it moves again.
			{ Id = "KnifeVolley", Name = "KNIVES", Cooldown = 7, Damage = 4, Knives = 8, Spread = 30, Range = 90, Speed = 200, ActionTime = 0.4, CutIn = false },
			-- VAMPIRE: a hand on the head of whoever's in front (Range): Ticks
			-- sips of Damage over Time seconds - each one heals him as much - then
			-- he throws them away
			{ Id = "VampireDrain", Name = "VAMPIRE", Cooldown = 12, Damage = 4, Ticks = 6, Time = 1.2, Range = 7, Heal = 1, ActionTime = 0.4, CutIn = true },
		},
		-- R: ZA WARUDO - time stops (Duration seconds) for everyone within
		-- Radius but him: frozen where they stand, and whatever he does to them
		-- lands when it starts again
		Special = { Id = "ZaWarudo", Name = "ZA WARUDO!", Cooldown = 38, Duration = 5, Radius = 220, CutIn = true },
		-- 4: SPACE RIPPER STINGY EYES - two beams of fluid out of his eyes at
		-- the speed of a bullet, through everyone down the aim (Range)
		Extra = { Id = "SpaceRipper", Name = "SPACE RIPPER STINGY EYES", Cooldown = 10, Damage = 18, Range = 140, Width = 2.6, ActionTime = 0.5, CutIn = true },
		Ult = {
			Name = "DIO'S WORLD",
			Shout = "WRYYYYYYYYY!!",
			Color = Color3.fromRGB(255, 214, 60),
			AccentColor = Color3.fromRGB(120, 255, 200),
			Duration = 25,
			WalkSpeed = 24,
			JumpPower = 62,
			Abilities = {
				{ Id = "MudaRush", Name = "MUDA MUDA MUDA MUDA!!", Cooldown = 5, Damage = 4, Hits = 24, Interval = 0.06, FinisherDamage = 24, Range = 9, BreakDepth = 28, Rage = true, CutIn = true },
				-- KNIFE RING: the knives appear all round whoever's nearest the aim
				-- (Range), hanging in the air - Knives of them at Ring studs - and
				-- all come in at once (Damage each) after Hang seconds (or when
				-- time moves again)
				{ Id = "KnifeRing", Name = "KNIVES: NOWHERE TO RUN", Cooldown = 9, Damage = 2, Knives = 20, Ring = 7, Hang = 0.7, Range = 80, ActionTime = 0.4, CutIn = true },
				-- ROAD ROLLER DA!: time stops (if it hasn't) for TimeStop seconds; he
				-- leaps, a road roller comes down on the aim point (Range) - on
				-- whoever's there - and he pounds it (Hits); when time moves again
				-- it goes up (Damage in Radius)
				{
					Id = "RoadRoller", Name = "ROAD ROLLER DA!", Cooldown = 30, Damage = 50, Radius = 16, Range = 100, Hits = 10, TimeStop = 3.4,
					CutIn = false, Cinematic = true, CinematicArmor = 3.6,
				},
			},
			Special = { Id = "ZaWarudo", Name = "ZA WARUDO!!", Cooldown = 24, Duration = 9, Radius = 260, CutIn = true },
			Extra = { Id = "SpaceRipper", Name = "SPACE RIPPER STINGY EYES", Cooldown = 6, Damage = 24, Range = 180, Width = 3.2, ActionTime = 0.45, CutIn = true },
		},
	},

	-- (round 60) Momo Yaoyorozu, CREATI: Creation. Anything non-living she
	-- knows the make-up of comes out of her skin (it's why her costume shows
	-- so much of it), made from the lipids in her body - the bigger it is,
	-- the longer it takes. She fights with what she makes: a staff, a sword, a
	-- spear, a shield big enough to hide behind, cannons, matryoshka dolls
	-- with flashbangs in them, a capture net, the railgun. Her kit is My Hero
	-- Ultra Rumble's (Strike and Stop, Unfalling Castle Wall, Bullet Rain, the
	-- Lucky Bag) and One's Justice's (the weapons she cycles through, the
	-- matryoshka flash, the cannon). She looks (the anime): a high black
	-- ponytail, the red costume, a gold utility belt.
	Creation = {
		DisplayName = "CREATI",
		Description = "Creation: anything non-living comes out of her skin. R CREATE puts the next weapon in her hand (staff, sword, spear): her M1s swing it and 4 is its move (Strike and Stop, Iai Rush, Piercing Thrust). 1 Matryoshka Flash: three nesting dolls that go off like flashbangs. 2 Unfalling Castle Wall: tap to plant a shield wall; hold to carry the shield (hits from the front land on it), let go to bash with it. 3 Bullet Rain: a cannon lobs three shells that burst into matryoshka bombs. Ult: Creati: Full Arsenal.",
		Color = Color3.fromRGB(196, 32, 52), -- (her red costume)
		AccentColor = Color3.fromRGB(255, 196, 70), -- (the gold belt)
		ModeName = "CREATION",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 20,
		JumpPower = 55,
		-- the glow her skin gives off as something comes out of it
		Glow = Color3.fromRGB(255, 176, 214),
		-- what her M1s swing (R picks it - the Extras below say which): Reach
		-- studs onto the M1's hitbox, x Damage
		Weapons = {
			Staff = { Name = "STAFF", Reach = 1.5, Damage = 1 },
			Sword = { Name = "SWORD", Reach = 1, Damage = 1.15 },
			Spear = { Name = "SPEAR", Reach = 3, Damage = 0.95 },
		},
		Abilities = {
			-- MATRYOSHKA FLASH (One's Justice 2): Dolls nesting dolls out of her
			-- palm, thrown in a fan (Spread degrees apart) down the aim. Each flies
			-- (Speed) until it reaches someone or something, or Range; there it
			-- splits open and the flashbang inside goes off: everyone within
			-- Radius takes Damage (once, however many dolls catch them), is stunned
			-- (Stun) and blinded (Blind seconds, the screen white). A guard takes it.
			{ Id = "MatryoshkaFlash", Name = "MATRYOSHKA FLASH", Cooldown = 9, Damage = 6, Dolls = 3, Spread = 13, Range = 46, Speed = 95, Radius = 7, Stun = 1.2, Blind = 1.8, ActionTime = 0.4, NoKnockdown = true, CutIn = false },
			-- UNFALLING CASTLE WALL (Ultra Rumble): a tower shield out of her
			-- forearm. TAP: she plants it - a wall (Width x Height) Ahead of her,
			-- facing her aim, for WallTime seconds or until WallHP of hits break
			-- it: no hit gets through it and nobody walks through it. HOLD: she
			-- carries it (slowed to Hold.Speed) and hits from in front of her land
			-- on the shield; let go and she drives it forward (Bash studs over
			-- BashTime): whoever it hits takes Damage and is knocked flying
			{
				Id = "CastleWall", Name = "UNFALLING CASTLE WALL", Cooldown = 10, Damage = 13, Bash = 14, BashTime = 0.22, BashWidth = 6,
				Width = 12, Height = 9, Ahead = 5, WallTime = 7, WallHP = 70, ActionTime = 0.3, CutIn = false,
				Hold = { Max = 3, Levels = { 0.3 }, Speed = 11, Names = { "CASTLE WALL", "SHIELD UP" }, Color = Color3.fromRGB(255, 196, 70) },
			},
			-- BULLET RAIN (Ultra Rumble): a cannon out of her side, planted on the
			-- street beside her: it lobs Shells shells (Interval apart) at the aim
			-- point (Range), Spread studs apart. Each lands for Damage (Radius) and
			-- bursts into Bombs matryoshka bombs that hop out and go off
			-- (BombDamage, BombRadius; once each per shell)
			{ Id = "BulletRain", Name = "BULLET RAIN", Cooldown = 13, Damage = 7, Shells = 3, Interval = 0.45, Range = 85, Spread = 6, Radius = 7, Bombs = 4, BombDamage = 2, BombRadius = 4.5, ActionTime = 0.55, NoKnockdown = true, CutIn = false },
		},
		-- R: CREATE - the next weapon into her hand (the 4th move goes with it)
		Special = { Id = "CreateWeapon", Name = "CREATE", Cycle = true, Cooldown = 0.6, CutIn = false },
		-- 4: whatever's in her hand
		Extras = {
			-- STRIKE AND STOP (Ultra Rumble): the staff whirled round her (Radius):
			-- everyone it catches takes Damage and is STOPPED - whatever they were
			-- doing is cut off, and they're stunned (Stun)
			{ Id = "StrikeAndStop", Name = "STRIKE AND STOP", Weapon = "Staff", Cooldown = 7, Damage = 9, Radius = 9, Stun = 1.2, ActionTime = 0.5, NoKnockdown = true, CutIn = false },
			-- IAI RUSH: the sword low, she dashes Dash studs down the aim (over
			-- DashTime) and cuts through everyone she passes (Damage, Width)
			{ Id = "IaiRush", Name = "IAI RUSH", Weapon = "Sword", Cooldown = 8, Damage = 12, Dash = 24, DashTime = 0.24, Width = 5, ActionTime = 0.45, CutIn = false },
			-- PIERCING THRUST: the spear driven out Range studs (Width): the first
			-- one on the point takes Damage and is run back Push studs, down
			{ Id = "PiercingThrust", Name = "PIERCING THRUST", Weapon = "Spear", Cooldown = 8, Damage = 12, Range = 15, Width = 3.5, Push = 14, ActionTime = 0.5, CutIn = false },
		},
		Ult = {
			Name = "CREATI: FULL ARSENAL",
			Shout = "EVERYONE, LEAVE IT TO ME... CREATION!!",
			Color = Color3.fromRGB(255, 120, 150),
			AccentColor = Color3.fromRGB(255, 232, 170),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 58,
			Abilities = {
				-- GRAND CANNON: a field cannon rises out of the street beside her
				-- and fires one shell at the aim point (Range, Speed): Damage in
				-- Radius, and a crater
				{ Id = "GrandCannon", Name = "GRAND CANNON", Cooldown = 12, Damage = 30, Radius = 15, Range = 140, Speed = 190, ActionTime = 0.9, CutIn = true },
				-- CAPTURE NET (the final exam against Eraser Head): a catapult flings
				-- a weighted net over the aim point (Range): everyone under it
				-- (Radius) takes Damage and is pinned for Pin seconds
				{ Id = "CaptureNet", Name = "CAPTURE NET", Cooldown = 13, Damage = 8, Radius = 12, Range = 70, Pin = 2.8, Flight = 0.7, ActionTime = 0.6, NoKnockdown = true, CutIn = false },
				-- DISCHARGE CANNON (the railgun she builds for Kaminari): on her
				-- shoulder, charged for Charge seconds, then one slug straight down
				-- the aim - through everyone in the lane (Range long, Width wide)
				{ Id = "DischargeCannon", Name = "DISCHARGE CANNON", Cooldown = 18, Damage = 34, Range = 220, Width = 7, Charge = 0.9, ActionTime = 1.3, CutIn = true },
			},
			-- 4: YAOYOROZU'S LUCKY BAG (Ultra Rumble's special): a bag drops at her
			-- feet and Items random Hero Shop items spill into her bag (no room for
			-- one: Heal health instead)
			Extra = { Id = "LuckyBag", Name = "LUCKY BAG", Cooldown = 20, Damage = 0, Items = 2, Heal = 20, ActionTime = 0.4, CutIn = false },
		},
	},

	-- Denki Kaminari, CHARGEBOLT: Electrification. He stores electricity
	-- and lets it out of his whole body - indiscriminately, unless he aims
	-- it: his Sharpshooting Gear (Hatsume and Power Loader's support item)
	-- fires POINTER discs that stick where they land, and his discharge is
	-- drawn straight to a pointer. Too much at once and his brain
	-- short-circuits ("wheeey").
	Electrification = {
		DisplayName = "CHARGEBOLT",
		Description = "Electrification. R fires a POINTER (2 in the clip; they stick to people or the map for 20s) and his lightning homes to it. 1 Discharge: a shock all round him - or one bolt straight to a pointer. 2 Electric Grasp (with a pointer in hand: throws them up, tags them, blasts them back). 3 Zap Trap (only he can see it): step on it and you're stunned (set near a pointer: a live wire runs to it). 4 Stun Bolt (shoot a pointer: it ricochets from person to person; shoot a trap: it overloads). 1 in the air: a lightning dive. Ult: 1,300,000 Volts.",
		Color = Color3.fromRGB(255, 214, 40),
		AccentColor = Color3.fromRGB(150, 220, 255),
		ModeName = "ELECTRIFICATION",
		CutInCorner = "TopRight",
		CutInImage = "",
		WalkSpeed = 20,
		JumpPower = 55,
		-- the clip: Max pointers; each flies Range studs and sticks for Life
		-- seconds, then comes back to the clip. His electricity is drawn to a
		-- pointer within Vicinity. Both fired: R reloads for Reload seconds
		Pointers = { Max = 2, Life = 20, Range = 60, Vicinity = 40, Reload = 4 },
		Abilities = {
			-- DISCHARGE: electricity out of his whole body (Radius; Damage, Stun).
			-- A pointer within Vicinity: it all goes down ONE line to it instead -
			-- everyone on the line (LineWidth) is jolted (LineDamage, LineStun
			-- seconds), and a pointer stuck on someone means it ends in them
			-- (TagDamage, knocked flat). In the air with AirHeight studs under him:
			-- THUNDER DIVE - he comes down as a bolt (DiveSpeed) and it goes off
			-- where he lands (AirRadius, AirDamage)
			{
				Id = "Discharge", Name = "DISCHARGE", Cooldown = 8, Damage = 10, Radius = 12, Stun = 1, LineDamage = 12, LineStun = 2, LineWidth = 4, TagDamage = 16,
				AirHeight = 6, AirRadius = 16, AirDamage = 13, DiveSpeed = 160, ActionTime = 0.4, CutIn = false,
			},
			-- ELECTRIC GRASP: a hand on their face (Range), filled with
			-- electricity (Damage, then Ticks x TickDamage) and slammed into the
			-- street (SlamDamage). A pointer in the clip: he throws them UP
			-- instead (Lift), tags them with it, and the bolt that follows
			-- (BoltDamage) blows them Push studs back
			{ Id = "ElectricGrasp", Name = "ELECTRIC GRASP", Cooldown = 10, Damage = 6, Ticks = 2, TickDamage = 2, SlamDamage = 10, Range = 8, Lift = 26, BoltDamage = 14, Push = 13, SlamPush = 6, ActionTime = 0.6, CutIn = false },
			-- ZAP TRAP: a trap on the street where he's aiming (Range) - and
			-- (round 59) nobody but him can see it. Armed after ArmTime; whoever steps within Radius of it is jolted stiff
			-- (Damage, Stun) and it's spent. Max at once (a new one replaces the
			-- oldest); gone after Life. Set within WireRange of a pointer: a live
			-- wire runs from the trap to it - crossing it jolts you (WireDamage,
			-- WireStun, once every WireEvery seconds). A Stun Bolt into a trap
			-- overloads it: a burst all round it (OverDamage, OverRadius).
			-- (round 68) THREE at once (Max), and with two or more armed an
			-- unseen FENCE runs between every pair (at most FenceRange apart):
			-- pass through it and you're jolted (FenceDamage, FenceStun - once
			-- every FenceEvery; in the line within FenceWidth, up to
			-- FenceHeight). Only he sees it; crossing it lights it up.
			{
				Id = "ZapTrap", Name = "ZAP TRAP", Cooldown = 8, Damage = 8, Stun = 1.8, Radius = 5, Range = 16, Max = 3, Life = 25, ArmTime = 0.5,
				WireRange = 30, WireDamage = 6, WireStun = 1.2, WireEvery = 1.2, OverDamage = 18, OverRadius = 14, ActionTime = 0.4, CutIn = false,
				FenceRange = 40, FenceDamage = 7, FenceStun = 0.9, FenceEvery = 1, FenceWidth = 1.6, FenceHeight = 9,
			},
		},
		-- R: POINTER - a disc straight down the aim, sticking to the first
		-- thing it hits
		Special = { Id = "Pointer", Name = "POINTER", Cooldown = 0.6, CutIn = false },
		-- 4: STUN BOLT - a finger gun: one bolt down the aim (Range); the first
		-- one it hits is jolted stiff (Damage, Stun), and it jumps to the next
		-- within ChainRange (ChainDamage). Into one of his pointers (on the map,
		-- within RelayWidth of the line, or on the one it hits): it RICOCHETS -
		-- to the nearest one within RicochetRange, and from them to the next,
		-- Ricochets times (RicochetDamage each). Into one of his traps: it
		-- overloads it
		Extra = {
			Id = "StunBolt", Name = "STUN BOLT", Cooldown = 7, Damage = 9, ChainDamage = 6, Range = 45, ChainRange = 10, Stun = 1.4,
			Ricochets = 4, RicochetRange = 10, RicochetDamage = 7, RelayWidth = 3.5, ActionTime = 0.35, CutIn = false,
		},
		Ult = {
			Name = "1,300,000 VOLTS",
			Shout = "INDISCRIMINATE DISCHARGE... 1,300,000 VOLTS!",
			Color = Color3.fromRGB(255, 236, 90),
			AccentColor = Color3.fromRGB(255, 255, 255),
			Duration = 22,
			WalkSpeed = 23,
			JumpPower = 60,
			-- (canon: after that much, his brain's fried - "wheeey" - for this long)
			Wheey = 2,
			Abilities = {
				-- INDISCRIMINATE DISCHARGE: the works, all round him (Radius):
				-- everyone in it is hurt and knocked flat, the street scorched
				{ Id = "IndiscriminateDischarge", Name = "INDISCRIMINATE DISCHARGE", Cooldown = 12, Damage = 26, Radius = 34, CutIn = true },
				-- LIGHTNING ROD: lightning out of the sky onto the aim point (Range)
				-- and onto every pointer he has out (Damage, Radius round each)
				{ Id = "LightningRod", Name = "LIGHTNING ROD", Cooldown = 11, Damage = 20, Radius = 8, Range = 70, CutIn = true },
				-- CHAIN LIGHTNING: a bolt into the nearest one, and from them to the
				-- next within JumpRange, and the next... (Jumps; Damage, Stun each)
				{ Id = "ChainLightning", Name = "CHAIN LIGHTNING", Cooldown = 13, Damage = 16, Jumps = 6, JumpRange = 30, Stun = 1.5, CutIn = true },
			},
			-- 4: the finger gun, at full charge
			Extra = {
				Id = "StunBolt", Name = "STUN BOLT: MAX", Cooldown = 5, Damage = 14, ChainDamage = 10, Range = 60, ChainRange = 14, Stun = 1.6,
				Ricochets = 6, RicochetRange = 14, RicochetDamage = 10, RelayWidth = 4, ActionTime = 0.35, CutIn = false,
			},
		},
	},

	-- CRAZY DIAMOND (JoJo Part 4, a guest - dev only): Josuke Higashikata's
	-- Stand. It punches through anything, and it puts things back together.
	-- RESTORE fixes everything broken around him (the pieces fly home through
	-- whoever's in the way); BUILD rebuilds the rubble into something new -
	-- 4 picks which: a wall, stairs, a pillar, a bridge or a dome; YO ANGELO
	-- seals someone inside a rock made of the street.
	CrazyDiamond = {
		DisplayName = "CRAZY DIAMOND",
		Description = "Dev: a Stand that smashes anything and puts it back. 1: DORARARA. 2: Build from the rubble (4 picks what). 3: Yo, Angelo. R: Restore. Ult: Shining Diamond.",
		Color = Color3.fromRGB(226, 110, 176),
		AccentColor = Color3.fromRGB(130, 214, 240),
		ModeName = "STAND",
		CutInCorner = "TopRight",
		CutInImage = "",
		DevOnly = true,
		Stand = true, -- (a Stand fights beside him)
		StandReach = 2.5, -- (round 66) the M1s are the Stand's, thrown from out in front of him: this much more reach
		WalkSpeed = 20,
		JumpPower = 55,
		-- what BUILD makes (4 cycles through them, in this order)
		Blueprints = { "Wall", "Stairs", "Pillar", "Bridge", "Dome" },
		Abilities = {
			-- the rush: a flurry that follows where he faces and punches a hole
			-- BreakDepth studs into whatever's in front, then one last DORA!
			{ Id = "Dorarara", Name = "DORARARARA!", Cooldown = 6, Damage = 3, Hits = 14, Interval = 0.085, FinisherDamage = 16, Range = 7, BreakDepth = 16, CutIn = false },
			-- rubble rebuilt at the aim point (Range) into the current blueprint;
			-- up to MaxStructures stand at once, each for Lifetime seconds
			{ Id = "CrazyBuild", Name = "BUILD", Blueprint = true, Cooldown = 4, Damage = 14, Range = 60, Lifetime = 45, MaxStructures = 6, CutIn = false },
			-- the street climbs whoever's in front and seals them in rock
			{ Id = "YoAngelo", Name = "YO, ANGELO", Cooldown = 14, Damage = 22, TickDamage = 2, Range = 30, TrapTime = 3, CutIn = true },
		},
		-- R: everything broken within Radius goes back the way it was; every
		-- piece flying home that passes through someone hits them (Damage
		-- each, up to MaxHitsPerTarget). His own structures come apart too.
		Special = { Id = "CrazyRestore", Name = "RESTORE", Cooldown = 8, Damage = 7, Radius = 80, MaxHitsPerTarget = 4, CutIn = false },
		-- 4: what BUILD makes next
		Extra = { Id = "Blueprint", Name = "BLUEPRINT", Cooldown = 0.25, CutIn = false },
		Ult = {
			Name = "SHINING DIAMOND",
			Shout = "WHAT DID YOU SAY ABOUT MY HAIR?!",
			Color = Color3.fromRGB(255, 80, 170),
			AccentColor = Color3.fromRGB(190, 240, 255),
			Duration = 30,
			WalkSpeed = 25,
			JumpPower = 62,
			Abilities = {
				{ Id = "Dorarara", Name = "DORARARA: RAGE", Cooldown = 5, Damage = 4, Hits = 22, Interval = 0.07, FinisherDamage = 26, Range = 9, BreakDepth = 30, Rage = true, CutIn = true },
				{ Id = "CrazyBuild", Name = "BUILD: MAX", Blueprint = true, Cooldown = 2, Damage = 20, Range = 90, Scale = 1.6, Lifetime = 60, MaxStructures = 10, CutIn = false },
				-- one punch shatters everything within Radius, then it all flies home
				{ Id = "BreakRestore", Name = "BREAK AND RESTORE", Cooldown = 30, Damage = 28, ReturnDamage = 30, Radius = 60, RestoreHold = 1.3, CutIn = true }, -- (round 85: was Hold - see SpikePrison)
			},
		},
	},

	-- The dev kit: every hero's trump card in one moveset, straight from the
	-- show. DevOnly like Decay (testers and players they grant).
	PlusUltra = {
		DisplayName = "PLUS ULTRA",
		Description = "Dev kit: the biggest moves in the show. 1,000,000% Smash, Prominence Burn, Warp Gate. R: Rewind. 4: NUKE (hold, let go to throw). Ult: Symbol of Peace (4: New Order).",
		Color = Color3.fromRGB(200, 40, 50),
		AccentColor = Color3.fromRGB(255, 214, 70),
		ModeName = "DEV KIT",
		CutInCorner = "TopLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 22,
		JumpPower = 60,
		Abilities = {
			-- Deku vs Overhaul, with Eri rewinding him: a flick so strong the wind
			-- pressure levels a whole street. Range = how far the blast reaches.
			{
				Id = "MillionSmash", Name = "1,000,000% DELAWARE DETROIT SMASH", Cooldown = 14, Damage = 50, CutIn = false,
				Range = 230, Width = 60, Charge = 1.45, Cinematic = true, CinematicArmor = 1.8,
			},
			-- Endeavor's strongest: he goes supernova where he stands
			{ Id = "ProminenceBurn", Name = "PROMINENCE BURN", Cooldown = 12, Damage = 40, CutIn = true, Radius = 36, BurnTicks = 6, BurnDamage = 3 },
			-- Kurogiri: step into a warp gate, come out at the aim point; anyone
			-- standing where it opens gets swallowed up and spat out stunned
			{ Id = "WarpGate", Name = "WARP GATE", Cooldown = 5, Damage = 12, CutIn = false, Range = 250, Radius = 12 },
		},
		-- R: Eri's Rewind: back to full health, every cooldown ready, +50 ult
		Special = { Id = "Rewind", Name = "REWIND", Cooldown = 30, CutIn = true, UltGain = 50 },
		-- 4: the NUKE. HOLD it: a sun-sized bomb forms over his head and grows
		-- (he can still walk, slowly); LET GO to throw it where he's aiming
		-- (up to Range studs; it throws itself at full size). Everything scales
		-- from MinScale to full with how long he held it: a Radius-stud blast
		-- wave rolling out at WaveSpeed, a Crater-stud hole in the city. Damage
		-- in the core, EdgeDamage at the rim (the per-hit cap still applies: it
		-- never one-shots anyone, and it never hurts him).
		Extra = {
			Id = "Nuke", Name = "NUKE", Cooldown = 40, CutIn = false,
			Damage = 140, EdgeDamage = 45, CoreRadius = 60, Radius = 260, Crater = 150, WaveSpeed = 480,
			Range = 300, MinCharge = 0.6, MaxCharge = 3, MinScale = 0.7, BombSize = 40,
			Hold = { Max = 3, Levels = { 1.2, 2.4 }, Speed = 10, Names = { "NUKE", "NUKE: CRITICAL", "NUKE: MELTDOWN" }, Color = Color3.fromRGB(255, 170, 60) },
		},
		Ult = {
			Name = "SYMBOL OF PEACE",
			Shout = "IT'S FINE NOW. WHY? BECAUSE I AM HERE!",
			Outfit = true,
			Color = Color3.fromRGB(255, 196, 40),
			AccentColor = Color3.fromRGB(255, 250, 220),
			Duration = 20,
			WalkSpeed = 30,
			JumpPower = 75,
			-- 4: Star and Stripe's New Order: "everyone around me floats" - then drops
			Extra = { Id = "NewOrder", Name = "NEW ORDER", Cooldown = 18, Damage = 35, CutIn = true, Radius = 100, FloatTime = 2.6 },
			Abilities = {
				{
					Id = "MillionSmash", Name = "1,000,000% SMASH: NO LIMITS", Cooldown = 6, Damage = 58, CutIn = false,
					Range = 300, Width = 76, Charge = 1.45, Cinematic = true, CinematicArmor = 1.8,
				},
				{ Id = "ProminenceBurn", Name = "PROMINENCE BURN: MAX", Cooldown = 5, Damage = 44, CutIn = true, Radius = 46, BurnTicks = 6, BurnDamage = 3 },
				{ Id = "WarpGate", Name = "WARP GATE", Cooldown = 1.5, Damage = 12, CutIn = false, Range = 320, Radius = 14 },
			},
		},
	},

	-- Enji Todoroki, ENDEAVOR - the No. 1 Hero (a dev character). HELLFLAME:
	-- he makes fire and controls it, from a candle to a column you can see
	-- across the city, and flies on it. Canon moves: HELL SPIDER (his flames
	-- squeezed white-hot through his fingertips as threads that slice), JET
	-- BURN (a torrent of fire off his fist), VANISHING FIST (the fire drawn
	-- all into one fist), HELL'S CURTAIN (a blanket of fire thrown over
	-- them), PROMINENCE BURN (everything he has, out of his whole body).
	-- His drawback is canon too - HEAT BUILDUP: he can't cool as fast as he
	-- burns, so every move heats him up, and at the top of the gauge he
	-- overheats. Prominence Burn is what he does with all of that heat.
	-- His costume: the dark navy suit, flames for his beard, moustache and
	-- brows and round his eyes, flames off his shoulders, the armoured
	-- bracers with the grilles on the backs of his hands, the scar.
	Hellflame = {
		DisplayName = "ENDEAVOR",
		Description = "Dev: Hellflame, the No. 1 Hero. 1 Hell Spider (white-hot threads off his fingertips). 2 Jet Burn (a torrent of fire off his fist). 3 Vanishing Fist (his fire goes out, he closes in, and the fist lands as an inferno). R: Flashfire Jet (fly on flames). 4 Hell's Curtain (a wall of fire). Every flame heats him up: at the top of the gauge he overheats. Ult: Plus Ultra - 4: Prominence Burn in the sky.",
		Color = Color3.fromRGB(226, 72, 18),
		AccentColor = Color3.fromRGB(255, 214, 96),
		ModeName = "HELLFLAME",
		CutInCorner = "TopRight",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 20,
		JumpPower = 56,
		-- HEAT BUILDUP (0..Max, "Heat" on him, the gauge on his HUD): every move
		-- adds its Heat; it bleeds off Cool a second once he's gone CoolDelay
		-- seconds without using fire. At Max he OVERHEATS: steam pours off
		-- him, he's slowed to Slow for Lock seconds and his fire won't come
		-- (moves are refused), then the gauge drops to Reset. PerHeat: the
		-- Prominence Burns hit harder the hotter he was (Damage x (1 + Heat
		-- / Max x PerHeat)) - they vent it all.
		Heat = { Max = 100, Cool = 10, CoolDelay = 1.6, Lock = 2.5, Slow = 8, Reset = 55, PerHeat = 0.6 },
		Abilities = {
			-- HELL SPIDER: his flames squeezed white-hot through his fingertips
			-- as Threads threads, swept down across whatever's in front (Range,
			-- a Spread-degree fan): each one they cross is cut (Hits x Damage)
			-- and burns. The threads cut the city too
			{ Id = "HellSpider", Name = "HELL SPIDER", Cooldown = 9, Damage = 5, Hits = 3, Range = 42, Spread = 40, Threads = 5, BurnTicks = 2, BurnDamage = 2, Heat = 18, ActionTime = 0.6, CutIn = false },
			-- JET BURN: a step, the fist out, and a torrent of fire off it down
			-- the aim (Range, Width) for Duration - Ticks hits of Damage /
			-- Ticks, shoving them away, burning (in the air he can aim it down)
			{ Id = "JetBurn", Name = "JET BURN", Cooldown = 11, Damage = 20, Ticks = 4, Range = 60, Width = 10, Duration = 0.7, BurnTicks = 3, BurnDamage = 2, Heat = 24, ActionTime = 0.95, CutIn = false },
			-- VANISHING FIST: every flame on him goes out - he's on them in a
			-- dash (Range) - and it all comes back at once in the fist: an
			-- inferno the size of a car (Damage, knocked flat; SplashDamage
			-- round it in Radius). Nobody reached: the fist goes off anyway
			{ Id = "VanishingFist", Name = "VANISHING FIST", Cooldown = 13, Damage = 26, SplashDamage = 8, Range = 34, Radius = 11, Speed = 150, BurnTicks = 3, BurnDamage = 2, Heat = 22, ActionTime = 0.75, CutIn = false },
		},
		-- R: FLASHFIRE JET - flames out of his feet and he flies down the aim
		-- (Speed, for Time seconds - up and down too), trailing fire
		Special = { Id = "FlashfireJet", Name = "FLASHFIRE JET", Cooldown = 4, Speed = 115, Time = 0.5, Heat = 8, CutIn = false },
		-- 4: HELL'S CURTAIN - both fists back, all his fire on one point, then
		-- thrown forward: a blanket of fire across the street (Width wide,
		-- Range ahead: Damage, pushed back) that stays up as a wall for
		-- Duration, burning anyone who goes through it (TickDamage)
		Extra = { Id = "HellsCurtain", Name = "HELL'S CURTAIN", Cooldown = 15, Damage = 12, TickDamage = 4, Width = 38, Range = 24, Duration = 4, BurnTicks = 2, BurnDamage = 2, Heat = 26, ActionTime = 0.8, CutIn = false },
		Ult = {
			Name = "PLUS ULTRA",
			Shout = "WATCH ME... THIS IS THE NUMBER ONE HERO!",
			Color = Color3.fromRGB(255, 120, 30),
			AccentColor = Color3.fromRGB(255, 246, 200),
			Duration = 24,
			WalkSpeed = 23,
			JumpPower = 62,
			-- (Heat builds half as fast while it's up)
			HeatScale = 0.5,
			Abilities = {
				-- HELL SPIDER: WEB - both hands, twice the threads, crossed into a
				-- net down the aim that cuts everything in it, then goes up in flames
				{ Id = "HellSpiderWeb", Name = "HELL SPIDER: WEB", Cooldown = 10, Damage = 6, Hits = 3, BlastDamage = 12, Range = 60, Spread = 56, Threads = 10, BurnTicks = 3, BurnDamage = 2, Heat = 20, ActionTime = 0.8, CutIn = true },
				-- VANISHING JET BURN (canon: the two together): a fist of fire the
				-- size of a house thrown down the aim (Range, Speed); where it hits,
				-- it goes off (Damage, Radius)
				{ Id = "VanishingJetBurn", Name = "VANISHING JET BURN", Cooldown = 12, Damage = 34, Radius = 18, Range = 110, Speed = 170, BurnTicks = 4, BurnDamage = 3, Heat = 26, ActionTime = 0.8, CutIn = true },
				-- PROMINENCE BURN: all of it, out of his whole body - a sphere of
				-- heat round him (Radius; Damage + his heat, knocked flat) and a
				-- column of fire up into the sky. Vents the gauge
				{ Id = "ProminenceNova", Name = "PROMINENCE BURN", Cooldown = 18, Damage = 38, Radius = 34, BurnTicks = 4, BurnDamage = 3, ActionTime = 1.4, CutIn = false, Cinematic = true, CinematicArmor = 1.4 },
			},
			-- 4: PLUS ULTRA: PROMINENCE BURN (the High-End fight): he grabs whoever's
			-- in front (Reach), rockets straight up Height studs on a column of
			-- fire, and lets it all out with them in his arms - a pillar of fire
			-- over the city. They fall (Damage; SkyDamage to anyone caught under
			-- it in Radius). Nobody to grab: he goes up alone and brings it
			-- down on the street. Vents the gauge
			Extra = { Id = "SkyProminence", Name = "PLUS ULTRA: PROMINENCE BURN", Cooldown = 22, Damage = 44, SkyDamage = 18, Reach = 12, Height = 110, Rise = 1.1, Radius = 26, ActionTime = 3.2, CutIn = false, Cinematic = true, CinematicArmor = 3.4 },
		},
	},

	-- Toya Todoroki, DABI (League of Villains - a dev character). BLUEFLAME:
	-- blue fire, hotter than his father's - but he got his mother's body,
	-- built for cold, so it burns him as well (the purple scarred skin
	-- stapled on round his face, neck and arms). He copied his father's
	-- moves to spite him: HELL SPIDER (roaring streams, not threads), JET
	-- BURN, the VANISHING FIST he throws; and his own HELL MINEFIELD
	-- (flames pushed under the street, erupting out of it). Canon drawback:
	-- every move sears him (SelfBurn, never below 1 health). His ult is the
	-- reveal - the black dye washes out of his hair (white), and he's
	-- burning all over.
	Blueflame = {
		DisplayName = "DABI",
		Description = "Dev: Blueflame - hotter than his father's fire, and it burns him too (every move costs him a little health, never the last of it). 1 Cremation (a wave of blue fire; the street stays burning). 2 Hell Minefield (flames under the street, erupting ahead). 3 Hell Spider (roaring blue streams off his fingertips). R: Blue Wall (a ring of fire round him). 4 Jet Burn (a flame-jet rush into a point-blank blast). Ult: It's Me, Toya - burning all over, white hair.",
		Color = Color3.fromRGB(36, 116, 255),
		AccentColor = Color3.fromRGB(170, 236, 255),
		ModeName = "BLUEFLAME",
		CutInCorner = "TopLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 20,
		JumpPower = 56,
		Abilities = {
			-- CREMATION: a wave of blue fire out of his palm down the aim (Range,
			-- Width): Damage, burning. The street where it went stays alight
			-- (Patches, PatchLife seconds: PatchDamage a tick to whoever stands in it)
			{ Id = "Cremation", Name = "CREMATION", Cooldown = 8, Damage = 14, Range = 40, Width = 12, BurnTicks = 4, BurnDamage = 2, Patches = 5, PatchRadius = 4, PatchLife = 5, PatchDamage = 3, SelfBurn = 3, ActionTime = 0.8, CutIn = false },
			-- HELL MINEFIELD: a hand on the street and his flames go under it -
			-- Delay later pillars of blue fire burst out of it one after another
			-- (Count, Gap seconds apart) up to the aim point (Range): each throws
			-- whoever's on it up (Damage, Radius, Lift)
			{ Id = "HellMinefield", Name = "HELL MINEFIELD", Cooldown = 12, Damage = 15, Count = 6, Range = 46, Radius = 6.5, Gap = 0.13, Delay = 0.45, Lift = 60, BurnTicks = 2, BurnDamage = 2, SelfBurn = 4, ActionTime = 0.65, CutIn = false },
			-- HELL SPIDER (his copy - roaring columns, not his father's threads):
			-- five streams of blue fire off his fingertips (Streams, Spread fan,
			-- Range): whoever they reach takes Hits x Damage, burning
			{ Id = "BlueSpider", Name = "HELL SPIDER", Cooldown = 10, Damage = 6, Hits = 3, Range = 46, Spread = 30, Streams = 5, BurnTicks = 3, BurnDamage = 2, SelfBurn = 3, ActionTime = 0.7, CutIn = false },
		},
		-- R: BLUE WALL - a stamp, and a ring of blue fire bursts up round him
		-- (Radius): whoever's on it is thrown out (Damage, Push); it burns for
		-- Duration, and crossing it burns (TickDamage)
		Special = { Id = "BlueWall", Name = "BLUE WALL", Cooldown = 14, Damage = 8, TickDamage = 4, Radius = 16, Duration = 5, Push = 60, SelfBurn = 2, ActionTime = 0.5, CutIn = false },
		-- 4: JET BURN - blue flames out behind him rocket him down the aim
		-- (Range, Speed); the first one he reaches gets a point-blank blast in
		-- the face (Damage, knocked flat; SplashDamage round it)
		Extra = { Id = "BlueJetBurn", Name = "JET BURN", Cooldown = 11, Damage = 20, SplashDamage = 7, Radius = 8, Range = 40, Speed = 140, BurnTicks = 3, BurnDamage = 2, SelfBurn = 4, ActionTime = 0.6, CutIn = false },
		Ult = {
			Name = "IT'S ME... TOYA",
			Shout = "IT'S ME... TOYA!",
			Color = Color3.fromRGB(80, 170, 255),
			AccentColor = Color3.fromRGB(236, 252, 255),
			Duration = 22,
			WalkSpeed = 23,
			JumpPower = 60,
			-- burning all over: Drain health a second, but never below Floor x
			-- his max health (and his moves don't sear him on top of it)
			Drain = 1.5,
			Floor = 0.15,
			Abilities = {
				-- PROMINENCE BURN (his, on Shoto): a beam of blue fire out of his
				-- whole chest down the aim (Range, Width): Damage, burning, the
				-- street cut open
				{ Id = "BlueProminence", Name = "PROMINENCE BURN", Cooldown = 14, Damage = 40, Range = 120, Width = 14, BurnTicks = 4, BurnDamage = 3, ActionTime = 1.3, CutIn = false, Cinematic = true, CinematicArmor = 1.2 },
				-- SEKOTO PEAK (where he "died" - the wildfire): blue fire spreads
				-- out of him over the street (Radius) for Duration: everyone in it
				-- burns (TickDamage every Tick seconds)
				{ Id = "SekotoPeak", Name = "SEKOTO PEAK", Cooldown = 16, Damage = 10, TickDamage = 3, Tick = 0.5, Radius = 38, Duration = 6, ActionTime = 0.8, CutIn = true },
				-- VANISHING FIST (he throws it): a fist of blue fire the size of a
				-- car flies down the aim (Range, Speed) and goes off where it hits
				-- (Damage, Radius)
				{ Id = "BlueVanishing", Name = "VANISHING FIST", Cooldown = 11, Damage = 30, Radius = 14, Range = 90, Speed = 150, BurnTicks = 3, BurnDamage = 3, ActionTime = 0.7, CutIn = true },
			},
			-- 4: the rush, burning white-hot
			Extra = { Id = "BlueJetBurn", Name = "JET BURN: MAX", Cooldown = 7, Damage = 26, SplashDamage = 10, Radius = 11, Range = 56, Speed = 180, BurnTicks = 3, BurnDamage = 3, ActionTime = 0.6, CutIn = false },
		},
	},

	-- (round 86) Keigo Takami, HAWKS - the Wing Hero, No. 2: "the man who's
	-- too fast". FIERCE WINGS: two big crimson wings, and he moves every
	-- feather on its own. Not a puncher (Power C+, Speed S, Technique S+):
	-- his damage is many fast cuts and feathers doing the work for him. HIS
	-- WINGS ARE HIS AMMO: every move spends feathers ("Feathers" on him, the
	-- gauge on his HUD) and you can SEE the wings thin out as he does (the
	-- wing is drawn from the count: Wing.Hide / Wing.Visible); they grow back
	-- once he's gone RegrowDelay seconds without spending. At 0 he's PLUCKED:
	-- no moves for Plucked seconds (and he jumps lower) - fire burns Fire
	-- extra off him a hit. Calm body, busy feathers.
	FierceWings = {
		DisplayName = "HAWKS",
		Description = "Dev: Fierce Wings, the No. 2 Hero - too fast. His wings are his ammo: every move spends feathers (watch the wings thin out) and they grow back. M1: feather blades. 1 Feather Barrage (homing feathers). 2 Swift Cut (a feather-sword dash straight through them). 3 Plume Cyclone (hold: a tornado of feathers that guards and shreds). R: Fierce Wings (take off and fly - slower on thin wings) - flying, his moves are new: Razor Strafe, Peregrine Stoop, Gale Beat, Feather Drill. 4 Feather Carry (feathers hook them and he takes off with them: toss, flurry or throw them in the air). Fire burns his feathers. Ult: Full Plumage - 4: the Thousand-Feather Storm.",
		Color = Color3.fromRGB(196, 28, 36),
		AccentColor = Color3.fromRGB(242, 218, 99),
		ModeName = "FIERCE WINGS",
		CutInCorner = "BottomLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 21,
		JumpPower = 58,
		-- the two long primaries drawn as swords (M1.Styles: "Feather"): this
		-- much more reach than fists (the server's swing box and his own
		-- screen's both read it)
		BladeReach = 1,
		-- FEATHERS (0..Max; UltMax in the ult - the Overgrowth). Regrow a
		-- second once RegrowDelay seconds pass without spending (FlyRegrow
		-- while flying, x UltRegrow in the ult). Flying costs FlyDrain a
		-- second (x UltFlyDrain in the ult; it doesn't hold the regrowth back).
		-- At 0: PLUCKED for Plucked seconds (moves refused, JumpPower
		-- PluckedJump). A fire hit (burn) takes Fire more. Low: the HUD's
		-- "running thin".
		-- (round 90) Dash: every dash (the dash key, on the street or in the
		-- air, any way) spends this many - or the last of them (emptying the
		-- wings plucks him, as any spend does). It's never refused: the dash
		-- is how he gets out of trouble. Plucked, it's a bare-wing dash (a
		-- puff of down, nothing spent)
		Feathers = { Max = 100, UltMax = 150, Regrow = 4, RegrowDelay = 1.6, FlyRegrow = 2, UltRegrow = 2, FlyDrain = 5, UltFlyDrain = 0.5, Plucked = 2.5, PluckedJump = 45, Fire = 6, Low = 20,
			Dash = 3 },
		-- (round 90) HIS M1s (FEATHER BLADES, his own clips: anim/moves_hawks_m1.py).
		-- Grip: each blade leaves the fist this many degrees off the forearm
		-- (toward the arm's front), Blade studs long (Vane of it the feather,
		-- the rest its point; Width across) - the clips are posed for exactly
		-- this. Sheathe: seconds after the last swing they fly home. Guard:
		-- the wings' fold while he's swinging (tight and high on his back: off
		-- his own screen, clear of the blades), held this long after a swing;
		-- the 4th throws them up (Pop: the wing state, for PopTime). Slash: the
		-- crimson cut mark left where each swing goes through them (Length,
		-- Life), AirBeat: a downstroke on every cut in the air. (round 90
		-- review) WalkOff: walking away this long after his last swing, they go
		-- home at once (the grip points them down the arm: his walk's swing
		-- would dip them into the street)
		M1 = { Grip = 40, Blade = 3, Vane = 2.25, Width = 0.42, Sheathe = 1.4, WalkOff = 0.6, Guard = 0.75, Pop = "Max", PopTime = 0.32,
			Slash = { Length = 5.5, Life = 0.16, Heavy = 8 }, AirBeat = true },
		-- (round 90) THE WING-BRAKED FALL: off a drop of more than MinDrop studs
		-- (never an ordinary jump), falling faster than Engage studs/s, his wings
		-- open into a canopy (Wing.States.Brake) and he falls no faster than
		-- Terminal (full wings) .. Bare (Feathers.Low and under) - quadratic
		-- air drag, at most MaxForce x his weight; at 0 feathers / plucked the
		-- wings can't hold him (no brake). Held jump spreads them wider: x
		-- Hold. Beat: a downstroke every this many seconds while he's under
		-- them. (His own machine moves him - the server only marks him
		-- HawksFalling for every screen's wings and pose.) Stoop: a long way
		-- down (the sky arena, off the flight) is not floated all of it - After
		-- seconds under the canopy with more than Above studs below him, the
		-- wings tuck and he stoops (no faster than Speed), and the canopy
		-- flares open again Above over the street (or with jump held).
		-- (round 90 review) Relay: the server lets it come on from off no more
		-- often than this (seconds) - a client can't flicker it on every screen;
		-- Resend: his machine tells it "off" again this often while the server
		-- still has him falling (an "off" it dropped: DIO's stopped time)
		Fall = { MinDrop = 12, Engage = 18, Terminal = 22, Bare = 46, Hold = 0.6, MaxForce = 1.6, Beat = 1.3, Delay = 0.12, Relay = 0.15, Resend = 0.5,
			Stoop = { After = 2.5, Above = 40, Speed = 140 } },
		-- (round 90) THE HOMECOMING: feathers coming back to him (a miss, a
		-- refund, the storm's, a blade) fly in as a flock (Flock: a V of them
		-- from far off, Gap studs between ranks, From studs out) and wrap
		-- round him in a spiral stream (Turns, from Radius in to the slot, Time
		-- seconds) into their slots; regrowth comes in the same way out of thin
		-- air (Grow: a glint Radius out, Time to slot in; at most Max in the
		-- air at once a Hawks, past that they slide out as before). Low-end:
		-- straight in, no spiral (LowSpiral = false)
		Home = { Turns = 1.15, Radius = 3.4, Time = 0.34, Rise = 1.4, Flock = { Min = 3, From = 14, Gap = 1.1, Spread = 0.7 },
			Grow = { Radius = 6, Rise = 1.5, Time = 0.5, Max = 8, Cull = 140 }, LowSpiral = false },
		-- (round 90) ON HIS FEET: running (faster than RunSpeed) the wings fold
		-- tight (Wing.States.Guard); stopping from a run (under StopSpeed
		-- within StopTime) they flutter open and settle (Flutter seconds)
		Run = { RunSpeed = 26, StopSpeed = 3, StopTime = 0.35, Flutter = 0.32 },
		Abilities = {
			-- FEATHER BARRAGE: a two-finger point and Count feathers peel off his
			-- wings one after another and fly. With someone near the aim (Homing
			-- degrees of it, within Range) they home on them (Speed, turning
			-- Turn degrees a second, in sharp steps); with nobody they fly
			-- straight down the aim in a tight fan (AimedSpeed). Each one that
			-- lands: Damage and a Stun-second flinch. A feather that misses
			-- (Life seconds out, or the street) turns round and comes home:
			-- Refund each
			-- (round 90) in the air: fired down at them - homing on anyone within
			-- AirHoming degrees of the aim, else straight down the aim pitched at
			-- least AirPitch degrees under level (he hangs in the air for it)
			{ Id = "FeatherBarrage", Name = "FEATHER BARRAGE", Cooldown = 7, Damage = 2, Count = 12, Range = 90, Speed = 140, AimedSpeed = 200, Turn = 220, Homing = 35, Spread = 8, Stun = 0.15, Life = 1.2, Gap = 0.025, Delay = 0.12, Feathers = 12, Refund = 1, ActionTime = 0.45, CutIn = false,
				AirHoming = 60, AirPitch = 25 },
			-- SWIFT CUT ("too fast"): one long primary drawn as a sword, a coil,
			-- and he's through them - Range studs in Time seconds down the aim
			-- (up to Aim degrees up or down; in the air too). Everyone on the line
			-- (Width) takes Damage as he passes; CutDelay later the cut they
			-- didn't see opens (CutDamage). (round 86, C2) The map: a clean
			-- gash GashWidth wide along the line, on GashPast past its end
			-- (round 90) in the air: a stoop - up to AirAim degrees down (a dive
			-- cut onto someone below)
			{ Id = "SwiftCut", Name = "SWIFT CUT", Cooldown = 8, Damage = 14, CutDamage = 4, CutDelay = 0.25, Range = 32, Time = 0.22, Width = 4.5, Aim = 30, Coil = 0.16, Feathers = 6, ActionTime = 0.55, CutIn = false, GashWidth = 7, GashPast = 4,
				AirAim = 60 },
			-- PLUME CYCLONE (hold): the wings sweep round him and Count feathers
			-- spiral out into rings - a red cyclone (Radius). While it's held
			-- (Hold.Max at most): everyone in it is dragged in (Pull studs/s) and
			-- shredded (Damage every Tick), and the feathers guard him (hits on
			-- him land for Guard of their damage, and can't stagger him). Feathers
			-- upfront, Drain more a second held. Let go: the rings burst outward
			-- (BurstDamage, Push), and the ones that survived come home (Refund)
			-- (hits land in whole points: 2 every 0.3 s - about 16 over a full
			-- hold, 24 with the burst)
			-- (round 90) in the air (AirHover): he hangs where he is inside it,
			-- the rings round his body instead of on the street
			{ Id = "PlumeCyclone", Name = "PLUME CYCLONE", Cooldown = 12, Damage = 2, Tick = 0.3, Radius = 7, Pull = 4, BurstDamage = 8, BurstRadius = 12, Push = 70, Guard = 0.5, Count = 40, Feathers = 16, Drain = 4, Refund = 8, AirHover = true,
				Hold = { Max = 2.5, Speed = 10, Names = { "PLUME CYCLONE" }, Color = Color3.fromRGB(230, 60, 60) }, CutIn = false },
		},
		-- R: FIERCE WINGS - a crouch, one huge downstroke (Lift studs/s up for
		-- LiftTime) and he's flying, up to Duration seconds: where the camera
		-- looks (W/S along it, A/D across, Space up), at Speed x (Weak + (1 -
		-- Weak) x his feathers) - thin wings fly slower. The dash key: a tuck
		-- dive down the aim (Boost studs/s for BoostTime; BoostCost feathers,
		-- every BoostEvery). R again, or the time up, or no feathers left: he
		-- glides down (falling no faster than Glide). Needs MinFeathers to take
		-- off. Landing: LandCooldown before he can take off again
		-- (round 86 review) Crouch: he stays put that long first (the clip's
		-- crouch, MoveHawksTakeoff's Hit) - the downstroke launches him.
		-- GlideMax: past the window the server keeps him flying while he's
		-- still coming down, no longer than this (his machine says when he's
		-- down; this is only for when it never does)
		-- (round 90) Already in the air: no crouch, no launch - the wings snap
		-- open and catch him (his fall arrested over AirCatch seconds, AirPop
		-- studs/s of lift at the end) and he's hovering at once.
		-- BoostCost 3 (was 5): every press of the dash key costs 3 (Feathers.Dash)
		Special = { Id = "FierceWings", Name = "FIERCE WINGS", Cooldown = 4, Feathers = 8, MinFeathers = 16, Speed = 62, Weak = 0.55, Accel = 3.5, Rise = 30, Lift = 70, LiftTime = 0.2,
			Crouch = 0.12, Boost = 120, BoostTime = 0.5, BoostCost = 3, BoostEvery = 0.9, Glide = 20, GlideMax = 45, Duration = 10, LandCooldown = 4, CutIn = false,
			AirCatch = 0.22, AirPop = 6, AirHeight = 3,
			-- (round 92, hawksair) his flying bar (Alt) is a form of his: a new
			-- body is on his feet, on his own bar (the server's respawn reset)
			ResetOnRespawn = true },
		-- 4: FEATHER CARRY - a lazy two-finger flick and his feathers hook into
		-- whoever's in front (Range, a Cone-wide cone, in plain sight): Damage as
		-- they bite. (round 92, hawksair) No slam any more: they're reeled up
		-- under him (Lift seconds) as he takes off with them, straight into his
		-- flying bar - whose 1-4 are the CARRY FOLLOW-UPS while he holds them
		-- (Alt.Carry). Needs MinFeathers (the carry and a flight's worth: the
		-- spend can't pluck him on the way up). Refund: the pins that come home
		-- when he lets go
		Extra = { Id = "FeatherCarry", Name = "FEATHER CARRY", Cooldown = 13, Damage = 6, Range = 40, Cone = 0.8, Hook = 0.2, Lift = 0.35,
			Feathers = 10, MinFeathers = 18, Refund = 4, ActionTime = 0.5, CutIn = false },
		-- (round 92, hawksair) ON THE WING - his FLYING moveset (the owner: "a new
		-- moveset while hes flying, after hitting r"). While he's up on R's
		-- flight (HawksFlying) his 1 2 3 4 are these - the game's alt-form
		-- mechanism (QuirkAlt / Config.GetView): the server puts him in it as his
		-- flight comes up (Kit.HK.relay, HawksLift) and out as it ends (HK.land),
		-- his own machine at the same moments (HawksFly.start / stop), so his
		-- own bar is back the moment he's down. Each keeps its own cooldown (the
		-- alt's keys). Not in the ult: the ult's bar wins there, as for every
		-- form. Jumping or under the braked fall he isn't flying: 1-3 keep their
		-- round-90 air variants there. FlyHang: how long a move holds him still
		-- in the air (0: he flies on through it). LandName: R's box while he flies
		Alt = {
			ModeName = "ON THE WING",
			LandName = "LAND",
			Color = Color3.fromRGB(178, 26, 40),
			AccentColor = Color3.fromRGB(150, 212, 255),
			Abilities = {
				-- RAZOR STRAFE: a strafing run - he flies on while Count feathers
				-- rake the street ahead of him (Gap apart, after Delay): a line of
				-- hits that starts where his aim meets the street (Range at most;
				-- pitched at least Pitch under level) and walks Step studs a feather
				-- the way he's flying. Each lands at Speed: everyone within Radius of
				-- it takes Damage and a Stun flinch (MaxHits from one run at most).
				-- Refund: the ones that come home out of the street
				{ Id = "RazorStrafe", Name = "RAZOR STRAFE", Cooldown = 8, Damage = 3, Count = 12, Gap = 0.05, Delay = 0.1, Range = 70, Pitch = 30, Step = 2.6,
					Radius = 3.6, MaxHits = 4, Stun = 0.12, Speed = 200, Feathers = 10, Refund = 4, ActionTime = 0.3, FlyHang = 0, CutIn = false },
				-- PEREGRINE STOOP: the falcon's dive - wings tucked (Coil), he drops
				-- down the aim (Down degrees under level at most, Up over it) at
				-- Speed through whoever's on the line (Width): Damage, knocked off
				-- their feet (Ragdoll), and the cut opens CutDelay later
				-- (CutDamage). It ends on the street (his root at hip height), at a
				-- wall or Range out - and he swoops out of it and climbs (PullUp
				-- seconds: PullSpeed on along the way he went, Climb studs/s up),
				-- still flying. The map: a clean gash where he went (GashWidth,
				-- GashPast)
				-- (round 92 review) FlyHang covers the longest dive and then some
				-- (Coil + Range / Speed = 0.415, plus the frames the effect's two
				-- delays take): the swoop ends the hold the moment it starts, but
				-- a hold that ran out first left him standing at the bottom of a
				-- long stoop into the street for a frame - his flight saw the
				-- street under him and landed him (no swoop, his own bar back)
				{ Id = "PeregrineStoop", Name = "PEREGRINE STOOP", Cooldown = 9, Damage = 16, CutDamage = 4, CutDelay = 0.25, Range = 55, Speed = 200, Coil = 0.14, Down = 75, Up = 10,
					Width = 5, Ragdoll = 1.1, PullUp = 0.45, PullSpeed = 70, Climb = 55, GashWidth = 6, GashPast = 3, Feathers = 8, ActionTime = 0.7, FlyHang = 0.6, CutIn = false },
				-- GALE BEAT: the wings reared up (Windup), then one enormous
				-- downstroke down the aim (Up / Down degrees): a cone of wind (Range,
				-- Cone degrees either side, in plain sight) - Damage, blown away at
				-- Push studs/s with Lift and off their feet (Ragdoll): off a roof,
				-- into a wall. The stroke throws him up (Recoil studs/s). The street
				-- under the gust is scoured (a Whirl, Scour studs)
				{ Id = "GaleBeat", Name = "GALE BEAT", Cooldown = 10, Damage = 7, Windup = 0.26, Range = 36, Cone = 42, Up = 20, Down = 70, Push = 110, Lift = 34, Ragdoll = 1.3,
					Recoil = 24, Scour = 7, Feathers = 10, ActionTime = 0.6, FlyHang = 0.5, CutIn = false },
			},
			-- 4: FEATHER DRILL - feathers peel off both wings into a spinning lance
			-- in his hands (Windup) and he drives it down the aim (Up / Down) at
			-- Speed, Range at most: it bores through walls (a tunnel, Bore) and
			-- stops on the street. Everyone it passes (Width) is caught on it -
			-- Ticks x Damage, TickGap apart, carried along with it - and at the end
			-- it bursts (BurstDamage in BurstRadius, pushed BurstPush). Refund: the
			-- ones that survive the burst come home
			Extra = { Id = "FeatherDrill", Name = "FEATHER DRILL", Cooldown = 12, Damage = 3, Ticks = 3, TickGap = 0.07, Windup = 0.34, Range = 80, Speed = 130, Width = 3.6,
				Up = 25, Down = 80, Bore = 2.4, BurstDamage = 6, BurstRadius = 9, BurstPush = 60, Feathers = 16, Refund = 6, ActionTime = 0.55, FlyHang = 0.5, CutIn = true },
			-- THE CARRY (FEATHER CARRY's hold: Kit.HA on the server). The pins in
			-- them, he flies with them hanging Hang studs under him (Ahead of
			-- him; swung back to Trail at TrailSpeed and faster), a little
			-- slower (SpeedMult). His bar's 1-4 are these follow-ups meanwhile -
			-- each lets go of them (one a carry), none of them a slam. He lets go
			-- by himself after MaxHold, when his flight isn't up within LiftWait
			-- of the hook, when he lands or is knocked about (a push of Push or
			-- more), plucked or erased - they fall where they are (Drop: keeping
			-- Carry of his speed, at most Max; limp from higher than Fall), never
			-- left out over the void. Gap: the server's gap between follow-ups.
			-- (round 92 review) StreamSpeed: a PLAYER carried while he goes this
			-- fast or faster has the map ahead of him asked for on their machine
			-- too (the dev carry's way: Kit.DF.streamAhead) - the place streams,
			-- and a body the server drags faster than its map arrives pauses
			-- that player's game
			Carry = {
				MaxHold = 3.5, LiftWait = 1.2, Hang = 6.5, Ahead = 0.6, Trail = 2.4, TrailSpeed = 70, SpeedMult = 0.8, Gap = 0.25, Push = 40, StreamSpeed = 45,
				Drop = { Carry = 0.4, Max = 60, Fall = 10 },
				Color = Color3.fromRGB(255, 196, 92),
				Moves = {
					-- 1 SKY TOSS: the pins yank them straight up (Rise studs over
					-- Time, bowed Bow studs out in front of him on the way past) and
					-- let go at the top - then a volley at the falling body:
					-- Count feathers (Damage each), homing (Speed, Turn), Gap apart;
					-- they come down stunned (Fall s) and limp (Ragdoll)
					{ Id = "SkyToss", Name = "SKY TOSS", Rise = 22, Bow = 4, Time = 0.38, Count = 10, Damage = 2, Speed = 170, Turn = 260, Gap = 0.03, Fall = 1.2, Ragdoll = 1.4,
						Feathers = 6, ActionTime = 0.6 },
					-- 2 FEATHER FLURRY: reeled in to his blades (Lead s; Reach in
					-- front of him), Hits stabs (Damage, Gap apart), then the crossing
					-- cut (CrossDamage) that lets go of them: kicked away Push studs/s
					-- with Lift, limp (Ragdoll)
					{ Id = "FeatherFlurry", Name = "FEATHER FLURRY", Lead = 0.16, Hits = 6, Gap = 0.075, Damage = 2, CrossDamage = 8, Reach = 3.2, Push = 80, Lift = 20, Ragdoll = 1.4,
						Feathers = 4, ActionTime = 0.8 },
					-- 3 GALE THROW: whirled round him (Spin s, Radius out: one and a
					-- half turns) and hurled down his aim on a gust - Damage, thrown
					-- at Speed (with Lift of it up), through the buildings in the way
					-- (the round-87 raw push, Time s)
					{ Id = "GaleThrow", Name = "GALE THROW", Spin = 0.32, Radius = 4.5, Damage = 12, Speed = 220, Lift = 0.15, Time = 0.7, Feathers = 4, ActionTime = 0.5 },
					-- 4 LET GO: the pins come out; they drop where they are (Drop)
					{ Id = "LetGo", Name = "LET GO" },
				},
			},
		},
		Ult = {
			Name = "FULL PLUMAGE",
			Shout = "LET'S WRAP THIS UP FAST!",
			Color = Color3.fromRGB(226, 36, 44),
			AccentColor = Color3.fromRGB(255, 232, 150),
			Duration = 22,
			WalkSpeed = 23,
			JumpPower = 62,
			Abilities = {
				-- FEATHER BARRAGE: SCARLET RAIN - the feathers go up first and
				-- come down out of the sky on the aim point (Radius, Range): Count
				-- of them, Damage each. The misses come home (Refund each)
				-- (round 86 review, hawks_ult) RingHeight: where every screen draws
				-- the ring of blades over the spot (in a gameplay camera's view;
				-- Height is only the server's roof check)
				{ Id = "ScarletRain", Name = "BARRAGE: SCARLET RAIN", Cooldown = 9, Damage = 2, Count = 16, Radius = 12, Range = 80, Height = 45, Fall = 0.55, Stun = 0.12, Feathers = 18, Refund = 1, ActionTime = 0.5, CutIn = true,
					RingHeight = 18 },
				-- TOO FAST: three Swift Cuts in a blink - through them, turned on
				-- the spot, through again: each pass re-aimed at whoever's nearest
				-- (Range) where he stands (nobody: on along the aim). All the cuts
				-- open together CutDelay after the last
				{ Id = "TooFast", Name = "TOO FAST", Cooldown = 10, Damage = 11, CutDamage = 3, CutDelay = 0.25, Cuts = 3, Range = 26, Time = 0.16, Gap = 0.12, Width = 4.5, Feathers = 12, ActionTime = 1.15, CutIn = true },
				-- PLUME CYCLONE: TEMPEST - the cyclone, bigger and harder; free
				-- while he's flying
				{ Id = "PlumeTempest", Name = "CYCLONE: TEMPEST", Cooldown = 10, Damage = 2, Tick = 0.2, Radius = 9.8, Pull = 6, BurstDamage = 12, BurstRadius = 16, Push = 90, Guard = 0.4, Count = 56, Feathers = 16, Drain = 4, Refund = 8, FreeFlying = true,
					Hold = { Max = 2.5, Speed = 12, Names = { "CYCLONE: TEMPEST" }, Color = Color3.fromRGB(255, 90, 80) }, CutIn = true },
			},
			-- 4: THE THOUSAND-FEATHER STORM - straight up Height studs, every
			-- feather off him at once, and the storm comes down on them (the aim
			-- point, or whoever's nearest it within Range; Radius): everyone in it
			-- held up in the air and shredded (Ticks x Damage, every Tick), then
			-- he dives through the eye of it with two swords - the last cut on the
			-- one in the middle (FinalDamage, knocked flat). Then every feather
			-- flies home (it costs nothing in the end)
			-- (round 86, hawks_ult) the beats, inside the same totals: Crouch (on
			-- the street before the downstroke, out of Rise), Sun (hung at the
			-- top against the sun, the wings at full stretch, before they break -
			-- out of Break), HomeSteps (the wings fill back in that many steps as
			-- the feathers land: the first HomeLead of Home they're all still in
			-- the air, then a step at a time to the end - each client lands
			-- every feather in its slot on its step). Show: how much of it is drawn (VFX.HU) - Parts
			-- feathers flying as parts, Swirl emitters round the funnel at Rate
			-- shards a second, Burst shards as the wings break, Ribbons of wind;
			-- a low-end machine draws half
			Extra = { Id = "ThousandFeathers", Name = "THOUSAND-FEATHER STORM", Cooldown = 24, Damage = 2, Ticks = 15, Tick = 0.1, FinalDamage = 18, Radius = 24, Range = 70, Height = 40,
				Rise = 0.5, Break = 0.6, Storm = 1.6, Dive = 0.6, Home = 0.8, ActionTime = 4.4, CutIn = false, Cinematic = true, CinematicArmor = 4.6,
				Crouch = 0.1, Sun = 0.42, HomeSteps = 8, HomeLead = 0.45, Show = { Parts = 150, Swirl = 8, Rate = 70, Burst = 360, Ribbons = 8 } },
		},
		-- THE WINGS (built by the server in QuirkGear: Kit.hawksWings; posed by
		-- every client: VFX.HK). Each wing is 3 bones (humerus, forearm to the
		-- bend, hand) with the feathers hinged on them: P primaries (P1 the
		-- outermost, at the tip), S secondaries, C coverts, O the ult's
		-- overgrowth row. Frames: the RIGHT wing's has X out, Y up, Z back
		-- (its root at Root on the torso); the left wing's is the torso's
		-- turned half round, and every local CFrame of it is the right one's
		-- mirrored (z and the turns about X and Y flipped). A bone's turn
		-- (degrees, absolute in the wing's frame) is Ry(-sweep) Rz(raise)
		-- Rx(twist) from S/E/W = { raise, sweep, twist }; a feather hangs at
		-- Phi degrees (from -Y toward +X) - in a state, Phi x Fan[row][1] +
		-- Fan[row][2]. Hide: the order feathers go as he spends them (per
		-- wing); Visible: { points (of Max, as 0..100), feathers showing a wing }.
		-- (Generated by r86/scratch_hawks_kit/gen_lua.py from the offline rig.)
		Wing = {
			Root = Vector3.new(0.36, 0.55, 0.56),
			Bones = { 0.75, 1.9, 1.05 },
			Feathers = {
				{ Row = "P", Idx = 1, Bone = 3, At = 0.95, Y = -0.02, Z = 0, Phi = 74, Len = 3, Wid = 0.46 },
				{ Row = "P", Idx = 2, Bone = 3, At = 0.78, Y = -0.02, Z = -0.015, Phi = 64, Len = 3.05, Wid = 0.46 },
				{ Row = "P", Idx = 3, Bone = 3, At = 0.61, Y = -0.02, Z = -0.03, Phi = 54, Len = 2.95, Wid = 0.46 },
				{ Row = "P", Idx = 4, Bone = 3, At = 0.44, Y = -0.02, Z = -0.045, Phi = 44, Len = 2.75, Wid = 0.46 },
				{ Row = "P", Idx = 5, Bone = 3, At = 0.27, Y = -0.02, Z = -0.06, Phi = 34, Len = 2.5, Wid = 0.46 },
				{ Row = "P", Idx = 6, Bone = 3, At = 0.1, Y = -0.02, Z = -0.075, Phi = 24, Len = 2.3, Wid = 0.46 },
				{ Row = "S", Idx = 1, Bone = 2, At = 1.8, Y = -0.03, Z = 0.05, Phi = 18, Len = 2.25, Wid = 0.46 },
				{ Row = "S", Idx = 2, Bone = 2, At = 1.564, Y = -0.03, Z = 0.056, Phi = 16, Len = 2.2, Wid = 0.46 },
				{ Row = "S", Idx = 3, Bone = 2, At = 1.329, Y = -0.03, Z = 0.062, Phi = 14, Len = 2.15, Wid = 0.46 },
				{ Row = "S", Idx = 4, Bone = 2, At = 1.093, Y = -0.03, Z = 0.068, Phi = 12, Len = 2.1, Wid = 0.46 },
				{ Row = "S", Idx = 5, Bone = 2, At = 0.857, Y = -0.03, Z = 0.074, Phi = 10, Len = 2.05, Wid = 0.46 },
				{ Row = "S", Idx = 6, Bone = 2, At = 0.621, Y = -0.03, Z = 0.08, Phi = 8, Len = 2, Wid = 0.46 },
				{ Row = "S", Idx = 7, Bone = 2, At = 0.386, Y = -0.03, Z = 0.086, Phi = 6, Len = 1.95, Wid = 0.46 },
				{ Row = "S", Idx = 8, Bone = 2, At = 0.15, Y = -0.03, Z = 0.092, Phi = 4, Len = 1.9, Wid = 0.46 },
				{ Row = "C", Idx = 1, Bone = 2, At = 1.75, Y = 0.08, Z = 0.1, Phi = 22, Len = 1.15, Wid = 0.38 },
				{ Row = "C", Idx = 2, Bone = 2, At = 1.375, Y = 0.08, Z = 0.106, Phi = 19.5, Len = 1.125, Wid = 0.38 },
				{ Row = "C", Idx = 3, Bone = 2, At = 1, Y = 0.08, Z = 0.112, Phi = 17, Len = 1.1, Wid = 0.38 },
				{ Row = "C", Idx = 4, Bone = 2, At = 0.625, Y = 0.08, Z = 0.118, Phi = 14.5, Len = 1.075, Wid = 0.38 },
				{ Row = "C", Idx = 5, Bone = 2, At = 0.25, Y = 0.08, Z = 0.124, Phi = 12, Len = 1.05, Wid = 0.38 },
				{ Row = "C", Idx = 6, Bone = 1, At = 0.68, Y = 0.06, Z = 0.15, Phi = 14, Len = 1.05, Wid = 0.38 },
				{ Row = "C", Idx = 7, Bone = 1, At = 0.53, Y = 0.06, Z = 0.156, Phi = 11.5, Len = 0.988, Wid = 0.38 },
				{ Row = "C", Idx = 8, Bone = 1, At = 0.38, Y = 0.06, Z = 0.162, Phi = 9, Len = 0.925, Wid = 0.38 },
				{ Row = "C", Idx = 9, Bone = 1, At = 0.23, Y = 0.06, Z = 0.168, Phi = 6.5, Len = 0.863, Wid = 0.38 },
				{ Row = "C", Idx = 10, Bone = 1, At = 0.08, Y = 0.06, Z = 0.174, Phi = 4, Len = 0.8, Wid = 0.38 },
				{ Row = "O", Idx = 1, Bone = 2, At = 1.85, Y = 0.14, Z = 0.135, Phi = 26, Len = 1.35, Wid = 0.36 },
				{ Row = "O", Idx = 2, Bone = 2, At = 1.55, Y = 0.14, Z = 0.141, Phi = 24, Len = 1.28, Wid = 0.36 },
				{ Row = "O", Idx = 3, Bone = 2, At = 1.25, Y = 0.14, Z = 0.147, Phi = 22, Len = 1.21, Wid = 0.36 },
				{ Row = "O", Idx = 4, Bone = 2, At = 0.95, Y = 0.14, Z = 0.153, Phi = 20, Len = 1.14, Wid = 0.36 },
				{ Row = "O", Idx = 5, Bone = 2, At = 0.65, Y = 0.14, Z = 0.159, Phi = 18, Len = 1.07, Wid = 0.36 },
				{ Row = "O", Idx = 6, Bone = 2, At = 0.35, Y = 0.14, Z = 0.165, Phi = 16, Len = 1, Wid = 0.36 },
			},
			Hide = { "P1", "P2", "S2", "P3", "P4", "S4", "S6", "P5", "P6", "S8", "S1", "S3", "S5", "S7", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10" },
			Visible = { { 0, 0 }, { 10, 5 }, { 25, 10 }, { 50, 17 }, { 75, 21 }, { 100, 24 } },
			-- (the ult's Overgrowth: the O row shows a feather per this many points over Max)
			OverPer = 8,
			Vane = 0.78, -- (of a feather's length: the rest is its pointed tip)
			Colors = {
				P = Color3.fromRGB(222, 44, 44), S = Color3.fromRGB(196, 28, 36), C = Color3.fromRGB(150, 18, 28), O = Color3.fromRGB(176, 22, 32),
				Tip = Color3.fromRGB(246, 88, 70), Shaft = Color3.fromRGB(96, 10, 18), Nub = Color3.fromRGB(110, 20, 26),
			},
			States = {
				Folded = { S = { 0, 54.5, 0 }, E = { 54.6, 14.3, -8.1 }, W = { -67, 45, -23 }, Fan = { P = { 0.5, 64.6 }, S = { 1.5, -55.9 }, C = { 1, -55.3 }, O = { 1, -55.3 } } },
				Spread = { S = { 31, 14, 0 }, E = { 21.6, 8, 0 }, W = { -16.7, 3.4, 0 }, Fan = { P = { 1.3, 10 }, S = { 1.15, 9 }, C = { 1.1, 6 }, O = { 1.1, 6 } } },
				Glide = { S = { -4.4, 16.7, 0 }, E = { -5.6, 10.2, 0 }, W = { -17.7, 4.6, 0 }, Fan = { P = { 0.9, 4 }, S = { 1, 0 }, C = { 1, 0 }, O = { 1, 0 } } },
				Tuck = { S = { -44.6, 50.7, -40.6 }, E = { -70.7, 59, -57.6 }, W = { -81, 71.6, -71.4 }, Fan = { P = { 0.15, 80 }, S = { 0.2, 82 }, C = { 0.2, 82 }, O = { 0.2, 82 } } },
				Mantle = { S = { 36, -14, 0 }, E = { 16, -73.3, 0 }, W = { -2.7, -160.7, 0 }, Fan = { P = { 0.7, -29.7 }, S = { 1, -21.5 }, C = { 1, -27.5 }, O = { 1, -27.5 } } },
				Flare = { S = { 28.3, -11.3, 0 }, E = { 35, -36.9, 0 }, W = { 10.5, -68.2, 0 }, Fan = { P = { 1.45, -8 }, S = { 1.1, -4 }, C = { 1, 0 }, O = { 1, 0 } } },
				FlapUp = { S = { 57.9, 28.6, 24.8 }, E = { 58.6, 55, 50.6 }, W = { 34.2, 76, 74.5 }, Fan = { P = { 1.3, -6 }, S = { 1, 0 }, C = { 1, 0 }, O = { 1, 0 } } },
				FlapDown = { S = { -24, -8.5, 0 }, E = { -36.3, -11.3, 0 }, W = { -62.4, -16.7, 0 }, Fan = { P = { 1, 2 }, S = { 1, 0 }, C = { 1, 0 }, O = { 1, 0 } } },
				Max = { S = { 47.6, 17.7, 0 }, E = { 43.3, 6.8, 0 }, W = { 15.6, -2.3, 0 }, Fan = { P = { 1.4, 6 }, S = { 1.15, 3 }, C = { 1.05, 0 }, O = { 1.05, 0 } } },
				-- (round 86 review, hawks_ult) folded in the ult (the wings
				-- UltScale bigger): the bends a little higher, the hands and the
				-- primaries tipped out, so the longer tips clear the street (1.2
				-- studs in his slouch, not 0.6)
				UltFolded = { S = { 13.1, 54.5, 0 }, E = { 60.4, 14.3, -8.7 }, W = { -63.4, 36.9, -15.9 }, Fan = { P = { 0.5, 66.9 }, S = { 1.5, -59.7 }, C = { 1, -61.1 }, O = { 1, -61.1 } } },
				-- (round 90) Guard: drawn in tight and high on his back (the bends
				-- up behind his head, the hands and primaries down along his
				-- spine) - the M1 chain's fold and his run's: they hide almost
				-- nothing of your own screen his body doesn't, and the blades
				-- never cut through them. Brake: the slow fall's canopy - wide, a
				-- shallow V, the leading edge a little forward, the primaries
				-- splayed into fingers. (r90/scratch_hawks/wing/states90.py)
				Guard = { S = { 33.4, 69, 0 }, E = { 72.2, 66.8, 71.7 }, W = { -80.4, 135, -138.3 }, Fan = { P = { 0.35, 83.1 }, S = { 0.6, -85.2 }, C = { 0.8, -90.9 }, O = { 0.8, -90.9 } } },
				Brake = { S = { 26.4, -6.8, 0 }, E = { 17.4, -12.4, 0 }, W = { -15.5, -6.8, 0 }, Fan = { P = { 1.45, 8 }, S = { 1.15, 6 }, C = { 1.1, 4 }, O = { 1.1, 4 } } },
			},
			-- the wing beat (Flap: FlapUp <-> FlapDown): seconds for the stroke
			-- down and back up, by what he's doing - and on thin wings (Weak:
			-- under Feathers.Low) faster and shakier
			Beat = { Hover = { 0.38, 0.26 }, Climb = { 0.24, 0.16 }, Weak = { 0.2, 0.13 }, Jitter = 6 },
			-- (studs from this machine's camera) within Cull: posed every frame,
			-- every feather; out to FarCull (a Hawks in the sky): the bones and
			-- the feathers' fans FarRate times a second, no twitches - past it
			-- the wings hold still. A low-end machine (IceKit.lowEnd) halves
			-- them: LowCull / LowFarCull, LowFarRate
			Cull = 150, FarCull = 500, FarRate = 15, LowCull = 80, LowFarCull = 300, LowFarRate = 10, -- (round 86 review: they froze past 150)
			Fade = 7, -- (your own wings fade with the camera this close behind you)
			-- (round 86, hawks_ult) FULL PLUMAGE: the wings this much bigger in the
			-- ult (the bones and the feathers; the root stays on his back), with a
			-- faint rim of light round them (UltRim: colour, outline and fill
			-- transparency) out to UltRimCull studs
			UltScale = 1.35,
			UltRim = { Color = Color3.fromRGB(255, 110, 90), Outline = 0.4, Fill = 0.9 },
			UltRimCull = 300,
			UltRimLowCull = 80, -- (round 86 review: a low-end machine's cull)
		},
	},

	-- (round 90) SAITAMA (One Punch Man, a guest - dev only): the hero for
	-- fun, bald from training, strong enough that every fight ends in one
	-- punch - which bores him. His moves are ordinary in numbers and
	-- ridiculous to look at (the joke is the presentation): a normal punch
	-- that blows a gale down the street behind them, a flurry of fists, a
	-- sneeze that clears a road, afterimages, the street flipped like a
	-- table - and in his ult, when he finally gets SERIOUS, one punch that
	-- blows the whole city away. His look, his cape, his idle and the city's
	-- part in it: Config.Saitama.
	Saitama = {
		DisplayName = "SAITAMA",
		Description = "Dev: One Punch Man, the hero for fun - bored, bald and far too strong. 1 Normal Punch (a gale down the street behind them). 2 Consecutive Normal Punches. 3 Serious Sneeze (it clears a road). R Serious Side Hops (afterimages - he's behind them). 4 Serious Table Flip (the street flipped over on them). Jump again in the air: a huge leap. Ult: Serious Mode - 3: SERIOUS PUNCH (it blows the whole city away).",
		Color = Color3.fromRGB(250, 206, 46),
		AccentColor = Color3.fromRGB(204, 30, 38),
		ModeName = "HERO FOR FUN",
		CutInCorner = "BottomRight",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 20,
		JumpPower = 60,
		-- jump again in mid-air: he just jumps very high (Saitama's jump)
		SuperLeap = { Up = 150, Forward = 70, Cooldown = 2.5, LandRadius = 12, LandDamage = 6, Always = true },
		Abilities = {
			-- NORMAL PUNCH: a lazy step in and a straight right at whoever's in
			-- front (Range, Width), Startup seconds after the press (the clip's
			-- Hit): Damage, thrown Launch studs/s with Lift. Its wind carries on
			-- down the line behind them (WindRange, WindWidth): everyone else
			-- in it takes WindDamage and is shoved WindPush. A whiff still
			-- blows the gale.
			{ Id = "NormalPunch", Name = "NORMAL PUNCH", Cooldown = 7, Damage = 16, Range = 8.5, Width = 6, Startup = 0.16, Lunge = 6,
				Launch = 150, Lift = 55, Ragdoll = 1.6, WindDamage = 4, WindRange = 50, WindWidth = 10, WindPush = 110, WindLift = 30,
				ActionTime = 0.5, CutIn = false },
			-- CONSECUTIVE NORMAL PUNCHES: a flurry of fists in front of him (Range
			-- x Width, following where he faces): Hits of Damage, Interval apart
			-- (they're held in it), then the last one (FinisherDamage) throws them
			{ Id = "ConsecutivePunches", Name = "CONSECUTIVE NORMAL PUNCHES", Cooldown = 11, Damage = 1, Hits = 14, Interval = 0.07, Startup = 0.15,
				FinisherDamage = 8, Range = 8, Width = 9, Launch = 120, Lift = 40, ActionTime = 1.35, CutIn = true },
			-- SERIOUS SNEEZE: "ah... ah..." (Windup, the clip's Hit) - ACHOO: a
			-- cone of wind down the aim (Range, Cone degrees either side):
			-- Damage, blown Push studs/s with Lift, off their feet; the street
			-- in it scoured
			{ Id = "SeriousSneeze", Name = "SERIOUS SNEEZE", Cooldown = 14, Damage = 9, Windup = 0.75, Range = 70, Cone = 30,
				Push = 150, Lift = 45, Ragdoll = 1.4, ActionTime = 1.1, CutIn = true },
		},
		-- R: SERIOUS SIDE HOPS - side to side so fast he leaves afterimages:
		-- Hops of them in Time seconds, zigzagging round whoever's nearest
		-- his aim (within Range, Cone degrees of it) to end at their back
		-- (Behind studs) - or, nobody there, Distance down the aim. Untouchable
		-- for Dodge seconds; the afterimages hang there Ghosts seconds.
		Special = { Id = "SeriousSideHops", Name = "SERIOUS SIDE HOPS", Cooldown = 8, Range = 40, Cone = 55, Time = 0.5, Hops = 8, Spread = 7,
			Behind = 4, Distance = 26, Dodge = 0.6, Ghosts = 1.1, CutIn = false },
		-- 4: SERIOUS TABLE FLIP - fingers under the street in front of him, and
		-- over it goes like a table: a slab (Ahead studs out, Length long,
		-- Width wide) heaved up at Grip (the clip's Hit) - everyone on it
		-- thrown up and over (Damage, Launch / Lift) - turning over its far
		-- edge in Flip seconds and slammed down beyond it, upside down: whoever
		-- it lands on (Reach past the far edge - its own length: it turns over
		-- on its hinge) takes SlamDamage, flattened
		Extra = { Id = "SeriousTableFlip", Name = "SERIOUS TABLE FLIP", Cooldown = 15, Damage = 10, SlamDamage = 12, Grip = 0.35, Flip = 0.6,
			Ahead = 3, Length = 34, Width = 26, Reach = 34, Thick = 3, Launch = 40, Lift = 105, SlamStun = 1.2, ActionTime = 1.1, CutIn = true },
		Ult = {
			Name = "SERIOUS MODE",
			Shout = "OK.",
			Color = Color3.fromRGB(255, 214, 60),
			AccentColor = Color3.fromRGB(255, 248, 230),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 64,
			Abilities = {
				{ Id = "NormalPunch", Name = "NORMAL PUNCH.", Cooldown = 5, Damage = 20, Range = 9, Width = 7, Startup = 0.16, Lunge = 7,
					Launch = 190, Lift = 65, Ragdoll = 1.8, WindDamage = 6, WindRange = 80, WindWidth = 14, WindPush = 140, WindLift = 40,
					ActionTime = 0.45, CutIn = false },
				{ Id = "ConsecutivePunches", Name = "CONSECUTIVE NORMAL PUNCHES", Cooldown = 8, Damage = 1, Hits = 20, Interval = 0.055, Startup = 0.15,
					FinisherDamage = 10, Range = 9, Width = 12, Launch = 150, Lift = 45, ActionTime = 1.4, CutIn = true },
				-- SERIOUS SERIES: SERIOUS PUNCH. He stops (anchored, untouchable
				-- for CinematicArmor) and gets serious for Windup seconds - the
				-- city darkens, the wind and the screens' shaking build, the
				-- eyes (Beats.Eyes), the fist drawn back (Draw), held shaking
				-- (Fist), "SERIOUS PUNCH." (Call) - then the punch, down his
				-- aim (locked when he pressed it). The wave goes out from him
				-- over the whole city (SeriousWave: Front studs/s straight
				-- ahead -> Back behind, Delay after the punch) - everyone it
				-- reaches within Radius studs of him, from Below under his feet
				-- to Above over them (not the sky arena, not the realm), is hit
				-- as it gets to them: in the punch's line (within LineCone
				-- degrees of it, or LineWidth studs of its axis) LineDamage and
				-- thrown LinePush / LineLift; everyone else WaveDamage and
				-- WavePush / WaveLift; off their feet (Ragdoll) - never off the
				-- edge of the city (a throw that would carry them past it is cut
				-- short, landing Edge studs inside). Nobody's one-shot (the
				-- hit's share cap holds), the dodged, god-moded and protected
				-- are left alone, and the city itself is blown away and put
				-- back on every screen (Config.Saitama.Wipe). The real map: a
				-- Crater at his feet and a trench of holes through whatever
				-- stands down the line (Trench studs long, from TrenchStart, of
				-- TrenchRadius, carved TrenchStep at a time as the wave gets
				-- there, each its TrenchBudget; the street itself is left) -
				-- (round 94) put back with every screen's rewind (the server's
				-- Kit.wipeRebuild), not left for the usual 40 s. He stays put Follow seconds
				-- after it. Cooldown: once an ult.
				{
					Id = "SeriousPunch", Name = "SERIOUS PUNCH", Cooldown = 60, CutIn = false,
					Cinematic = true, CinematicArmor = 8, ActionTime = 5.4,
					Windup = 4.2, Follow = 0.6, Beats = { Eyes = 0.55, Draw = 1.4, Fist = 2.6, Call = 3.55 },
					LineDamage = 80, WaveDamage = 20, LineCone = 14, LineWidth = 16,
					Radius = 1700, Above = 320, Below = 140,
					Front = 1600, Back = 520, Sharp = 1.6, Delay = 0.05,
					LinePush = 240, LineLift = 115, WavePush = 120, WaveLift = 85, PushTime = 0.35, Ragdoll = 2.6, Edge = 40,
					Crater = 24, Trench = 640, TrenchStart = 14, TrenchRadius = 18, TrenchStep = 80, TrenchBudget = 260,
					MusicDuck = 0.12,
				},
			},
			Special = { Id = "SeriousSideHops", Name = "SERIOUS SIDE HOPS", Cooldown = 5, Range = 48, Cone = 60, Time = 0.45, Hops = 10, Spread = 8,
				Behind = 4, Distance = 30, Dodge = 0.6, Ghosts = 1.3, CutIn = false },
			Extra = { Id = "SeriousTableFlip", Name = "SERIOUS TABLE FLIP", Cooldown = 11, Damage = 12, SlamDamage = 16, Grip = 0.35, Flip = 0.6,
				Ahead = 3, Length = 44, Width = 34, Reach = 44, Thick = 3.5, Launch = 45, Lift = 120, SlamStun = 1.4, ActionTime = 1.1, CutIn = true },
		},
	},

	-- (round 92) INASA YOARASHI (Shiketsu High - the hero Gale Force; DEV
	-- ONLY for now: DevOnly is the one flag - Config.IsDevOnly reads it, the
	-- HERO ROSTER switch releases him live). Huge, loud, hot-blooded, and his
	-- Whirlwind moves the air over a whole street: gusts that cut, a cannon of
	-- packed wind, a tornado that drags people in and juggles them, a wall
	-- nothing gets through, his own gale to ride; and in his ult a cyclone up
	-- to the clouds that rips up the city and hurls it. Nothing one-shots: the
	-- numbers sit in the roster's band (player health 300). His look, his
	-- cape, his wind: Config.Inasa.
	Whirlwind = {
		DisplayName = "INASA",
		Description = "Dev: Inasa Yoarashi of Shiketsu High - huge, loud, and he LOVES a good fight. 1 Slicing Gust (gust after gust down a cone). 2 Gale Cannon (a blast of wind down the street that bowls them over). 3 Dragon Whirlwind (a tornado that drags them in and juggles them). R Wind Wall (nothing gets through from the front - shots are blown back). 4 Wind Ride (surf his own gale). Jump again in the air: an updraft. Ult: Passion Storm - 3: SKYBREAKER CYCLONE (a whirlwind up to the clouds that rips up the street and hurls it).",
		Color = Color3.fromRGB(150, 32, 54),
		AccentColor = Color3.fromRGB(214, 246, 236),
		ModeName = "WHIRLWIND",
		CutInCorner = "BottomLeft",
		CutInImage = "",
		DevOnly = true,
		WalkSpeed = 20,
		JumpPower = 55,
		-- (big and tall: 195 cm - a head over most of the roster)
		BodyScale = { BodyWidthScale = 1.08, BodyDepthScale = 1.08, BodyHeightScale = 1.12, HeadScale = 1.05, R6Scale = 1.1 },
		-- jump again in mid-air: an updraft throws him up and on
		SuperLeap = { Up = 105, Forward = 60, Cooldown = 3, LandRadius = 10, LandDamage = 5, Always = true },
		Abilities = {
			-- SLICING GUST: arms flung out and the air goes with them - Pulses
			-- gusts down a cone (Cone degrees either side of the aim, Height
			-- studs up and down), Interval apart from Startup (the clip's Hit),
			-- each reaching further (RangeStart -> Range). Every one that catches
			-- them hits (Damage) and shoves them on (Push / Lift, held Stun -
			-- kept on their feet); the last throws them (FinalPush / FinalLift,
			-- off their feet for Ragdoll)
			{ Id = "SlicingGust", Name = "SLICING GUST", Cooldown = 7, Damage = 4, Pulses = 4, Startup = 0.2, Interval = 0.1,
				RangeStart = 18, Range = 34, Cone = 38, Height = 12, Push = 55, Lift = 16, Stun = 0.5, FinalPush = 125, FinalLift = 45, Ragdoll = 1.3,
				ActionTime = 0.65, CutIn = false },
			-- GALE CANNON: the wind packed between his palms (Windup, the clip's
			-- Hit) and fired down the aim - a blast Width wide (Height tall) out
			-- to Range or the first wall (it bursts there: WallBurst studs) at
			-- Speed studs/s. Everyone it reaches: Damage, bowled over (Push /
			-- Lift, off their feet for Ragdoll). It scours the street and
			-- carries the rubble along it (Rubble pieces)
			{ Id = "GaleCannon", Name = "GALE CANNON", Cooldown = 10, Damage = 20, Windup = 0.35, Range = 90, Width = 10, Height = 12, Speed = 260,
				Push = 150, Lift = 45, Ragdoll = 1.6, Rubble = 6, WallBurst = 9, ActionTime = 0.8, CutIn = true },
			-- DRAGON WHIRLWIND: he spins the air up over his head and flings it
			-- (Startup, the clip's Hit): a tornado set down Ahead studs in front
			-- that rolls on down the aim (Speed studs/s for Life seconds; a wall
			-- stops it). Everyone within PullRadius (and Height over the street)
			-- is dragged in (Pull studs/s, swung round it Swirl); inside
			-- CoreRadius they're caught - held, carried up LiftHeight round its
			-- side, TickDamage every TickEvery - and when it dies it bursts:
			-- everyone caught thrown up and on (FinalDamage, Launch / Throw, off
			-- their feet). Once it's thrown it's its own: hitting him doesn't stop it.
			{ Id = "DragonWhirlwind", Name = "DRAGON WHIRLWIND", Cooldown = 13, Startup = 0.3, Ahead = 7, Speed = 14, Life = 2.6,
				PullRadius = 16, CoreRadius = 6, Height = 24, Pull = 30, Swirl = 28, LiftHeight = 9, TickDamage = 2, TickEvery = 0.3,
				FinalDamage = 8, Launch = 95, Throw = 40, Ragdoll = 1.4, ActionTime = 0.6, CutIn = true },
		},
		-- R: WIND WALL - arms out, a wall of wind in front of him for Time
		-- seconds (he can barely walk: WalkSpeed). Every hit from the front
		-- (within Cone degrees of where he set it) is stopped - not a burn, a
		-- grab or an unblockable one. From further off than MeleeRange (a
		-- shot) it's blown back down the line at whoever threw it
		-- (ReflectShare of it, at most ReflectMax, at ReflectSpeed studs/s;
		-- a thrower once every ReflectGap seconds); up close they're blown
		-- back themselves (Push / Lift, PushDamage, held Stun, once a wall).
		-- Anyone walking into it (Width x Depth x Height in front) is shoved off.
		-- A stance: nothing else while it's up (ActionTime = Time) - no punching
		-- from behind a wall nothing gets through.
		Special = { Id = "WindWall", Name = "WIND WALL", Cooldown = 12, Time = 1.4, Cone = 70, Width = 14, Depth = 8, Height = 12,
			Push = 85, Lift = 25, PushDamage = 4, Stun = 0.6, MeleeRange = 14, ReflectShare = 0.5, ReflectMax = 20, ReflectSpeed = 220, ReflectGap = 0.25,
			WalkSpeed = 4, ActionTime = 1.4, CutIn = false },
		-- 4: WIND RIDE - a gust under his feet and he's off on it (Launch, the
		-- clip's Hit): his own machine flies him at Speed studs/s wherever his
		-- camera looks (pitched MinPitch..MaxPitch degrees) for Time seconds,
		-- then lets him go with Carry of it. Anyone he rides through (Radius)
		-- takes Damage, blown aside (Push / Lift, off their feet for Ragdoll).
		-- ((round 92 review) the server looks Trail seconds past Time: its
		-- view of him trails his own screen's by the ping)
		Extra = { Id = "WindRide", Name = "WIND RIDE", Cooldown = 9, Time = 1.4, Launch = 0.12, Speed = 80, MinPitch = -30, MaxPitch = 35, Carry = 0.45,
			Radius = 6, Damage = 9, Push = 70, Lift = 55, Ragdoll = 1.2, Trail = 0.2, ActionTime = 1.55, CutIn = false },
		Ult = {
			Name = "PASSION STORM",
			Shout = "I LOVE THIS!!!",
			Color = Color3.fromRGB(196, 44, 66),
			AccentColor = Color3.fromRGB(236, 255, 248),
			Duration = 25,
			WalkSpeed = 22,
			JumpPower = 60,
			Abilities = {
				{ Id = "SlicingGust", Name = "SLICING GUST: FURY", Cooldown = 5, Damage = 4.5, Pulses = 5, Startup = 0.2, Interval = 0.09,
					RangeStart = 20, Range = 44, Cone = 44, Height = 14, Push = 60, Lift = 18, Stun = 0.5, FinalPush = 145, FinalLift = 55, Ragdoll = 1.5,
					ActionTime = 0.7, CutIn = false },
				-- (the rubble it carries hits too: DebrisDamage more)
				{ Id = "GaleCannon", Name = "GALE CANNON: TYPHOON", Cooldown = 7, Damage = 26, DebrisDamage = 6, Windup = 0.35, Range = 130, Width = 15, Height = 16, Speed = 320,
					Push = 175, Lift = 55, Ragdoll = 1.8, Rubble = 16, WallBurst = 13, ActionTime = 0.8, CutIn = true },
				-- SKYBREAKER CYCLONE. He plants himself (anchored, untouchable for
				-- CinematicArmor), throws both arms at the sky ("SKYBREAKER..." at
				-- Beats.Call, the arms up at Beats.Arms) and a whirlwind tears up
				-- out of the street at his aim (MinAhead..Range studs in front of
				-- him) and climbs to the clouds over Form seconds - every screen in
				-- the city sees it. For Hold seconds it pulls: everyone within
				-- PullRadius (from Below under the street to Height over it) is
				-- dragged in (Pull, swung round Swirl); inside EyeRadius they're
				-- caught in the eye - carried up it (EyeLift studs, low -> high)
				-- spinning, TickDamage every TickEvery. The street at its foot is
				-- torn up (Carves times, CarveRadius) and the rubble round it
				-- (GatherRadius, GatherWant a pull every Gather seconds, MaxRubble
				-- in all) sucked up into it. Then "...CYCLONE!!!": he throws his
				-- arms down and it bursts - everyone in the eye thrown out of it
				-- (BurstDamage, BurstPush / BurstLift, off their feet for
				-- Ragdoll), everyone else it was pulling shoved off (Shove) - and
				-- everything it carried is hurled: everyone within HurlRange
				-- (Above / Below, the nearest MaxTargets) has Chunks pieces thrown
				-- at them ChunkGap apart at ChunkSpeed studs/s - each that lands
				-- (within ChunkHit studs of them when it gets there) ChunkDamage.
				-- He stays put Follow seconds after. Once an ult (Cooldown).
				-- ((round 92 review) its foot: the street found up to FootProbe
				-- studs under his aim - cast off a rooftop, it's the street below)
				{
					Id = "SkyCyclone", Name = "SKYBREAKER CYCLONE", Cooldown = 60, CutIn = false,
					Cinematic = true, CinematicArmor = 5.6, ActionTime = 5.6,
					Range = 70, MinAhead = 26, Form = 1.1, EyeHold = 3.4, Follow = 0.6, -- (round 92, integration: EyeHold, not Hold - an ability's Hold is the held-move table)
					 Beats = { Call = 0.2, Arms = 0.9 }, FootProbe = 600,
					PullRadius = 70, EyeRadius = 14, Height = 220, Below = 90, Pull = 40, Swirl = 44, EyeLift = { 8, 34 }, TickDamage = 3, TickEvery = 0.4,
					BurstDamage = 26, BurstPush = 170, BurstLift = 95, Ragdoll = 2.4, Shove = 80,
					HurlRange = 260, Above = 220, Chunks = 3, ChunkGap = 0.12, ChunkDamage = 7, ChunkSpeed = 170, ChunkHit = 8, MaxTargets = 14,
					Carves = 3, CarveRadius = 14, Gather = 0.5, GatherRadius = 90, GatherWant = 8, MaxRubble = 60,
					MusicDuck = 0.25,
				},
			},
			Special = { Id = "WindWall", Name = "WIND WALL", Cooldown = 8, Time = 1.8, Cone = 80, Width = 18, Depth = 10, Height = 16,
				Push = 110, Lift = 35, PushDamage = 6, Stun = 0.8, MeleeRange = 14, ReflectShare = 0.75, ReflectMax = 26, ReflectSpeed = 260, ReflectGap = 0.2,
				WalkSpeed = 6, ActionTime = 1.8, CutIn = false },
			Extra = { Id = "WindRide", Name = "STORM RIDE", Cooldown = 6, Time = 1.8, Launch = 0.12, Speed = 105, MinPitch = -35, MaxPitch = 45, Carry = 0.5,
				Radius = 8, Damage = 12, Push = 90, Lift = 70, Ragdoll = 1.4, Trail = 0.2, ActionTime = 1.95, CutIn = false },
		},
	},
}

Config.QuirkOrder = { "Explosion", "OneForAll", "FullCowl", "HalfCold", "Engine", "Creation", "Lemillion", "Manifest", "Arbor", "Electrification", "Overhaul", "Decay", "Compress", "Double", "Limitless", "CrazyDiamond", "PlusUltra", "Hellflame", "Blueflame", "PrimeDeku", "PrimeMight", "TheWorld", "FierceWings", "Saitama", "Whirlwind" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- alt = on the quirk's second side/form; ult = G ultimate active; pick =
-- which of the quirk's Extras is in the 4th slot (Deku's R cycles it)
function Config.GetAbility(quirkName, index, alt, ult, pick)
	local quirk = quirkName and Config.Quirks[quirkName]
	if not quirk then
		return nil
	end
	if index == Config.SPECIAL_INDEX then
		if ult and quirk.Ult and quirk.Ult.Special then
			return quirk.Ult.Special -- (round 64: the ult's own R - Bakugo's Explosive Speed)
		end
		if ult and quirk.Special and quirk.Special.Form then
			return nil -- form swaps are locked while ulting
		end
		return quirk.Special
	end
	if index == Config.EXTRA_INDEX then
		return Config.GetExtra(quirk, alt, ult, pick)
	end
	if index == Config.PRANK_INDEX then
		local on = workspace ~= nil and workspace:GetAttribute("MufflerPrank") == true
		return on and ult and quirk.Ult and quirk.Ult.Prank or nil
	end
	if ult and quirk.Ult then
		return quirk.Ult.Abilities[index]
	end
	local set = (alt and quirk.Alt) and quirk.Alt.Abilities or quirk.Abilities
	return set[index]
end

-- which Extra a quirk's pick lands on (it wraps round)
function Config.PickedExtra(quirk, pick)
	local list = quirk and quirk.Extras
	if not list or #list == 0 then
		return nil
	end
	local i = math.floor(tonumber(pick) or 1)
	return list[((i - 1) % #list) + 1], ((i - 1) % #list) + 1
end

-- The 4th move (4): the ult's own, else (if the ult forces the alt form)
-- the alt form's, else the base quirk's - a quirk with a list of Extras
-- uses whichever one is picked
function Config.GetExtra(quirk, alt, ult, pick)
	local base = Config.PickedExtra(quirk, pick) or quirk.Extra
	if ult and quirk.Ult then
		return quirk.Ult.Extra or ((quirk.Ult.ForceAlt or alt) and quirk.Alt and quirk.Alt.Extra) or base
	end
	if alt and quirk.Alt then
		return quirk.Alt.Extra or base
	end
	return base
end

-- Key used for cooldown bookkeeping (client HUD and server validation agree on it)
function Config.CooldownKey(quirkName, index, alt, ult, pick)
	if index == Config.SPECIAL_INDEX then
		local quirk = Config.Quirks[quirkName or ""]
		if ult and quirk and quirk.Ult and quirk.Ult.Special then
			return quirkName .. ":S:" .. quirk.Ult.Special.Id -- (the ult's own R keeps its own)
		end
		return quirkName .. ":S"
	end
	if index == Config.EXTRA_INDEX then
		local quirk = Config.Quirks[quirkName or ""]
		local extra = quirk and Config.GetExtra(quirk, alt, ult, pick)
		-- (each of the ult's / alt's / picked 4th moves keeps its own cooldown)
		return quirkName .. ":X" .. (extra and (":" .. extra.Id) or "")
	end
	if ult then
		return quirkName .. ":U:" .. index
	end
	return quirkName .. ((alt and ":A:") or ":") .. index
end

-- Flattened view of a quirk for the HUD (swaps colours/moves per form)
function Config.GetView(quirkName, alt, ult, pick)
	local quirk = quirkName and Config.Quirks[quirkName]
	if not quirk then
		return nil
	end
	local nextExtra = quirk.Extras and Config.PickedExtra(quirk, (tonumber(pick) or 1) + 1) or nil
	if ult and quirk.Ult then
		return setmetatable({
			ModeName = quirk.Ult.Name,
			Color = quirk.Ult.Color,
			AccentColor = quirk.Ult.AccentColor,
			Abilities = quirk.Ult.Abilities,
			-- form swaps hide the R slot during the ult; move specials stay (an
			-- ult with its own R shows that)
			Special = quirk.Ult.Special or ((quirk.Special and not quirk.Special.Form) and quirk.Special) or false,
			Extra = Config.GetExtra(quirk, alt, true, pick) or false,
			NextExtra = nextExtra,
			IsUlt = true,
		}, { __index = quirk })
	end
	if alt and quirk.Alt then
		return setmetatable({
			DisplayName = quirk.Alt.DisplayName or quirk.DisplayName,
			ModeName = quirk.Alt.ModeName,
			OtherModeName = quirk.ModeName,
			Color = quirk.Alt.Color,
			AccentColor = quirk.Alt.AccentColor,
			CutInImage = (quirk.Alt.CutInImage ~= "" and quirk.Alt.CutInImage) or quirk.CutInImage,
			Abilities = quirk.Alt.Abilities,
			Extra = Config.GetExtra(quirk, true, false, pick) or false,
			NextExtra = nextExtra,
		}, { __index = quirk })
	end
	return setmetatable({
		OtherModeName = quirk.Alt and quirk.Alt.ModeName or nil,
		Extra = Config.GetExtra(quirk, false, false, pick) or false,
		NextExtra = nextExtra,
	}, { __index = quirk })
end

-- An aimed move's direction (ability.Aim = { Up = degrees, Down = degrees }):
-- the aim itself, its pitch held between Down below and Up above the
-- horizon. The server and every client work it out the same way.
function Config.AimedDirection(dir, look, aim)
	local d = (typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.01) and dir.Unit or look
	local h = Vector3.new(d.X, 0, d.Z)
	if h.Magnitude < 0.05 then
		h = Vector3.new(look.X, 0, look.Z)
	end
	h = h.Magnitude > 0.05 and h.Unit or Vector3.new(0, 0, -1)
	local pitch = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
	pitch = math.clamp(pitch, -math.rad((aim and aim.Down) or 0), math.rad((aim and aim.Up) or 0))
	return (h * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit
end

-- Swinging (Kamui's branch, Suneater's tentacle): where to look for
-- something to swing from - a fan of rays up, ahead and to either side - and
-- how good a spot is (the swinger's screen and the server agree). The best
-- line goes a good way ahead (about 25-70 studs) and high: much nearer is a
-- hop, much further a long slow sag; a long way off to the side is worse.
Config.SwingFan = {
	Pitches = { 22, 32, 42, 52, 62, 72, 82, 88 },
	Yaws = { 0, -15, 15, -30, 30, -45, 45, -60, 60, -75, 75, -90, 90 },
}
function Config.SwingScore(ahead, up, side)
	local far = math.min(ahead, 70) - math.max(ahead - 70, 0) * 0.4
	local near = math.max(25 - ahead, 0) * 0.3
	return far - near + math.min(up, 55) * 0.7 - math.max(side - 30, 0) * 0.5
end

-- The shop's items in display order (Config.Items keyed by id)
function Config.GetItem(id)
	return type(id) == "string" and Config.Items[id] or nil
end

---------------------------------------------------------------------------
-- (round 86) THE ROSTER SWITCH: testers release DEV ONLY heroes to
-- everyone, and pull heroes back to DEV ONLY, live and with no republish -
-- the test menu's HERO ROSTER panel, or the owner's console ("roster").
-- A quirk's DevOnly above is only its DEFAULT now. The server keeps the
-- changes from the defaults (the overrides), saves them (a DataStore, one
-- key), sends them to every running server (MessagingService, one topic)
-- and to every client (the workspace attribute RosterOverrides, e.g.
-- "FierceWings=public:1759450000,Decay=dev:1759440000": the state and when
-- it was switched). Every DEV ONLY gate asks Config.IsDevOnly(id), never
-- .DevOnly. Studio reads the live roster but keeps its own switches to that
-- session (it saves and sends nothing) unless StudioSaves is on; a server
-- whose DataStore isn't answering keeps them for that server till it is
-- (the panel says which).
---------------------------------------------------------------------------
Config.Roster = {
	DataStore = "QuirkBattlegrounds_Roster_v1",
	Key = "RosterOverrides",
	Topic = "QuirkRoster", -- (MessagingService)
	Attribute = "RosterOverrides", -- (on workspace; RosterSync / RosterBy / RosterAt say how it stands)
	-- who may switch heroes besides the owner (Console.isOwner: the creator,
	-- a group's owner, Console.Owners), TestMenu.AllowedUserIds and Studio.
	-- Testers let in by TestMenu.Public only look.
	Editors = {},
	-- a hero pulled back to DEV ONLY while someone without dev access plays
	-- him: theirs for the rest of that life, then the first public hero
	-- (false: switched at once, like a revoked DEV ACCESS)
	KeepUntilRespawn = true,
	Resync = 120, -- seconds between re-reads of the saved roster (heals a missed message)
	NewFor = 3 * 86400, -- a hero released from DEV ONLY wears a NEW pill on the phone this long
	Announce = true, -- a NEW HERO banner on the screen of everyone who couldn't pick him before
	-- (round 86 review) the save, and Studio:
	--  StudioSaves: a Studio playtest saves and sends its switches like a live
	--   server (they reach the live game). Off, Studio still reads the live
	--   roster, but a switch there stays in that session.
	--  WriteGap: seconds between two writes to the key (Roblox allows one per
	--   6 s); clicks made meanwhile all go in the next one.
	--  SaveTimeout: a save that hasn't come back by then is given up on (the
	--   next one takes over).
	--  AnnounceDelay: a release waits this long on each client before its
	--   banner, and is dropped if the hero's been pulled again by then (a
	--   tester's misclick doesn't flash every screen).
	StudioSaves = false,
	WriteGap = 6,
	SaveTimeout = 30,
	AnnounceDelay = 1.5,
}

do
	local cache = { text = false, map = {} }
	local STATES = { public = true, dev = true }

	-- "Name=public:1759450000,Name=dev" -> { [Name] = { State = "public" | "dev", Since = time } }
	-- (heroes this Config knows, real states only)
	function Config.ParseRoster(text)
		local map = {}
		if type(text) ~= "string" then
			return map
		end
		for name, state, since in string.gmatch(text, "([%w_]+)=(%a+):?(%d*)") do
			if Config.Quirks[name] and STATES[state] then
				map[name] = { State = state, Since = tonumber(since) }
			end
		end
		return map
	end

	-- the other way: in QuirkOrder, then any others by name (so one state is always one string)
	function Config.EncodeRoster(map)
		local out, done = {}, {}
		local function add(name)
			local e = map[name]
			if e and not done[name] and Config.Quirks[name] and STATES[e.State] then
				done[name] = true
				table.insert(out, name .. "=" .. e.State .. (tonumber(e.Since) and (":" .. math.floor(e.Since)) or ""))
			end
		end
		for _, name in Config.QuirkOrder do
			add(name)
		end
		local rest = {}
		for name in map do
			if not done[name] then
				table.insert(rest, name)
			end
		end
		table.sort(rest)
		for _, name in rest do
			add(name)
		end
		return table.concat(out, ",")
	end

	-- the overrides in force (the server keeps the attribute; read on every machine)
	function Config.RosterOverrides()
		local text = ""
		if workspace then
			text = workspace:GetAttribute(Config.Roster.Attribute or "RosterOverrides") or ""
		end
		if text ~= cache.text then
			cache.text = text
			cache.map = Config.ParseRoster(text)
		end
		return cache.map
	end

	-- "public" / "dev" when a hero is switched from his default, else nil
	function Config.RosterOverride(quirkName)
		local e = Config.RosterOverrides()[quirkName]
		return e and e.State or nil
	end

	-- THE gate: only testers (and players they've granted) may pick this hero
	function Config.IsDevOnly(quirkName)
		local q = Config.Quirks[quirkName or ""]
		if not q then
			return false
		end
		local o = Config.RosterOverride(quirkName)
		if o then
			return o == "dev"
		end
		return q.DevOnly == true
	end

	-- released from DEV ONLY in the last Roster.NewFor seconds (the phone's NEW pill)
	function Config.RosterNew(quirkName, now)
		local q = Config.Quirks[quirkName or ""]
		local e = Config.RosterOverrides()[quirkName or ""]
		if not (q and q.DevOnly and e and e.State == "public") then
			return false
		end
		return e.Since ~= nil and (now or os.time()) - e.Since < (Config.Roster.NewFor or 0)
	end
end

function Config.FindAbilityById(id)
	for _, quirk in Config.Quirks do
		for _, set in { quirk.Abilities, quirk.Alt and quirk.Alt.Abilities, quirk.Ult and quirk.Ult.Abilities } do
			for _, ability in set or {} do
				if ability.Id == id then
					return ability
				end
			end
		end
		if quirk.Special and quirk.Special.Id == id then
			return quirk.Special
		end
		if quirk.Ult and quirk.Ult.Special and quirk.Ult.Special.Id == id then
			return quirk.Ult.Special
		end
		for _, extra in { quirk.Extra, quirk.Alt and quirk.Alt.Extra, quirk.Ult and quirk.Ult.Extra } do
			if extra and extra.Id == id then
				return extra
			end
		end
		for _, extra in quirk.Extras or {} do
			if extra.Id == id then
				return extra
			end
		end
	end
	return nil
end

-- (round 59) Suneater's BAMBOO SWEEP, t seconds into the swing (after its
-- WindUp): the stalk's angle off the way he faced (degrees, + = his right),
-- its length and thickness, and 1 on the way out / -1 on the way back; nil
-- once it's back in his arm. Out: from his left round to his right, growing
-- (eased), biggest at the end; (round 72) held there HoldTime seconds;
-- back: the same way round, shrinking.
function Config.BambooAt(spec, t)
	local out, hold, back = spec.SwingTime or 0.45, spec.HoldTime or 0, spec.ReturnTime or 0.35
	if t < 0 or t > out + hold + back then
		return nil
	end
	local k, way
	if t <= out then
		k, way = t / out, 1
	elseif t <= out + hold then
		k, way = 1, 1
	else
		k, way = 1 - (t - out - hold) / back, -1
	end
	k = k * k * (3 - 2 * k)
	local arc = (spec.Arc or 240) / 2
	local l0, l1 = spec.Length0 or 8, spec.Length1 or 22
	local w0, w1 = spec.Thick0 or 0.8, spec.Thick1 or 1.7
	return -arc + 2 * arc * k, l0 + (l1 - l0) * k, w0 + (w1 - w0) * k, way
end

-- (round 72) how far down the stalk points so its tip drags along the
-- street: drop = how far above the ground (under the tip) it grows from.
-- The tip stays Skim studs up - never flatter than 2 degrees, never steeper
-- than MaxTilt; if the ground's too far down for that, the stalk grows (up
-- to Reach studs) to get there. The tilt (radians) and the length.
function Config.BambooReach(spec, len, drop)
	local maxT = math.rad(spec.MaxTilt or 72)
	local want = (drop or 0) - (spec.Skim or 0.4)
	if want > len * math.sin(maxT) then
		len = math.min(want / math.sin(maxT), math.max(len, spec.Reach or len))
	end
	return math.asin(math.clamp(want / len, math.sin(math.rad(2)), math.sin(maxT))), len
end

-- the stalk this frame, from `from` round towards `flat`: its direction, its
-- length and whether its tip is on the ground. floorY(pos) = the height of
-- the ground under pos (nil: nothing under it - then it keeps its Tilt).
-- The server's hits and every screen's stalk both come from here.
function Config.BambooAim(spec, from, flat, len, floorY)
	local tilt, l, low = math.rad(spec.Tilt or 16), len, false
	local g = floorY(from + flat * len * 0.85)
	if g then
		tilt, l = Config.BambooReach(spec, len, from.Y - g)
		local g2 = floorY(from + flat * l * math.cos(tilt))
		if g2 then
			tilt, l = Config.BambooReach(spec, len, from.Y - g2)
			low = from.Y - l * math.sin(tilt) - g2 < 1.5
		end
	end
	return flat * math.cos(tilt) - Vector3.new(0, 1, 0) * math.sin(tilt), l, low
end

return Config
