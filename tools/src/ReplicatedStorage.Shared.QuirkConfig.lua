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
-- and your item (right), and clicking the left stick locks on. Push the left
-- stick all the way to sprint.
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
Config.LockOnKeys = { Enum.KeyCode.T, Enum.KeyCode.ButtonL3 } -- lock the camera onto the nearest enemy
Config.ShiftLockKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.DPadDown }
Config.ItemKeys = { Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }
Config.UseItemKeys = { Enum.KeyCode.DPadRight } -- tap: use the selected item, hold: pick the next one
Config.ShopKeys = { Enum.KeyCode.H, Enum.KeyCode.ButtonSelect }
Config.BoardKeys = { Enum.KeyCode.L } -- TOP HEROES: the all-time kills leaderboard
Config.EmoteKeys = { Enum.KeyCode.B, Enum.KeyCode.ButtonR3 } -- the emote wheel (controller: click the right stick, tilt it to pick, click again)

Config.LockOn = {
	Range = 90, -- how far it looks for someone to lock onto
	BreakRange = 140, -- the lock lets go past this
	Angle = 75, -- only targets within this many degrees of where the camera looks
}

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
	{ Id = "Dance", Rarity = "Rare", Name = "DANCE", Icon = "🕺" },
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
	{ Id = "Griddy", Rarity = "Rare", Name = "THE GRIDDY", Icon = "🕺" },
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
	{ Id = "DadMode", Rarity = "Legendary", Name = "THE JIGGY", Say = "HIT IT!", Icon = "🎶", Party = true, Song = "rbxassetid://116394797033057", Bpm = 128, Offset = 0.1 },
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
}

Config.EmoteSlots = 4 -- (round 58) how many the wheel holds

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
	Center = Vector3.new(-70, 600, 888), -- the lawn's surface, over the middle spawn
	Radius = 425, -- the disc (850 studs across)
	Barrier = 418, -- the pillar ring: the barrier runs between them
	BarrierHeight = 290,
	CityGate = Vector3.new(-72, 26, 857), -- the street by the middle spawn (a ray finds its exact height)
	-- touching the barrier: a jolt that locks you up for a moment and throws
	-- you back off it (no damage)
	Zap = { Stun = 0.7, Push = 55, Cooldown = 1.2 },
}
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
	Cooldown = 0.28,
	FinisherCooldown = 0.78,
	ActionTime = 0.18,
	FinisherActionTime = 0.42,
	ComboReset = 1.1,
	ComboLength = 4,
	Damage = 4,
	FinisherDamage = 10,
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
	-- DOWNSLAM: TAP jump during the chain (you hop as you let go) and throw
	-- the 4th anywhere off the ground (DownslamHeight studs will do) - it
	-- spikes them into the street and they bounce off it. (Jump held until
	-- the chain runs out - ComboReset - is an ordinary jump again.)
	-- While both of you are airborne, M1s keep them floating up there with you.
	-- (Lift for LiftTime seconds, then they coast: ~14 studs up; you rise
	-- RiseWith after them, so the two of you meet up there for the air combo)
	Uppercut = { Lift = 55, LiftTime = 0.12, RiseWith = 0, Forward = 8, Stun = 1.3, Hitstop = 0.1 },
	-- (round 75) HitboxExtra: a hair more box (width, height, depth) for the
	-- downslam; HopDelay: a jump tapped or held in the chain hops you that long
	-- after the swing's lock lets go (unless the 4th goes out with it held -
	-- that's the upslam)
	Downslam = { Drop = 150, Forward = 10, Ragdoll = 1.5, Bounce = 26, Hitstop = 0.12, Crater = 3.2, HitboxExtra = Vector3.new(1.5, 1.5, 1.5), HopDelay = 0.07 },
	AirJuggle = { Up = 26, Forward = 3, Stun = 0.7 },
	MinAirHeight = 3, -- studs between your feet and the ground that count as "in the air"
	DownslamHeight = 0.25, -- (round 63) off the ground enough for a downslam (round 75: lower)
	-- Fighting style per quirk: Brawler (straight, hook, uppercut, power
	-- straight), Kicks (snap kick, two roundhouses, axe kick), Claw (open-hand
	-- rakes) or Mixed (hands and feet). A table picks per form:
	-- { Base = ..., Alt = ... (R form), Ult = ... }. Anything unlisted brawls.
	Styles = {
		Engine = "Kicks",
		Decay = "Claw",
		FullCowl = { Base = "Mixed", Ult = "Kicks" }, -- fists and feet; all Shoot Style at 100%
		PrimeDeku = { Base = "Mixed", Ult = "Kicks" }, -- (round 74)
		Limitless = "Mixed",
		Overhaul = "Claw", -- open-hand touches: every one of them can take you apart
		Manifest = "Mixed", -- a tentacle lash, a talon kick, a clam fist, a crab-shell kick
		Creation = "Weapon", -- (round 60) Creati swings the staff / sword / spear in her hand
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
-- second at full tilt, Deadzone, Curve (1 = a straight line). Lock-on keeps
-- up with its target faster too (LockOnFollow).
Config.Look = {
	InstantShiftLock = true,
	-- (round 68) x the player's CONTROLLER SENSITIVITY (the settings: 50% to
	-- 300%); ROBLOX CAMERA in the settings hands the stick back to Roblox's
	-- own camera and its sensitivity instead
	Pad = { Enabled = true, Speed = 250, PitchSpeed = 190, Deadzone = 0.12, Curve = 1.25 },
	LockOnFollow = 18,
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

-- Map destruction (parts with the Destroyable attribute set to true)
Config.Destruction = {
	Enabled = true,
	RegenTime = 40, -- seconds after the last hit before a broken part rebuilds
	DebrisLifetime = 7, -- seconds flying chunks stay around
	MaxDebris = 260, -- cap on loose chunks at once (oldest are removed first)
	SlamSpeed = 110, -- knockback this strong sends the target crashing through walls
}

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
		Decay = { Name = "DECAY", Time = 1.45, Forward = 15, Up = 8 },
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
	Procedural = { R6 = "auto", R15 = false },
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
	},
	ClipFade = 0.05, -- seconds a clip blends in from whatever the body was doing
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
	},
	-- Every move by its Id (see the quirk tables below)
	Moves = {
		APShot = "", BlastRush = "", Howitzer = "", StunGrenade = "", AutoCannon = "", Cluster = "", BlastOrbit = "", ScorchedEarth = "", FullBodyCluster = "", ExplosiveSpeed = "",
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
	-- UNITED STATES OF SMASH: "...SMASH!!" lands on the punch
	MightUSS = {
		Folder = "All Might", Sound = "united_states_of_smash_my_hero_academia_1", Id = "rbxassetid://104378200563777", Gain = 2, Range = 400,
		First = 0.1, Beat = 2.0, MaxCut = 0.3, Length = 7,
	},
	-- Bakugo: his awakening, and Explosive Speed (his R in the ult) - "I'M
	-- THE FINAL BOSS, GOT IT?" (to All For One, in the Final Season's "The
	-- Final Boss!!"), trimmed before "...ALL FOR ONE!!"
	Bakugo200 = { Folder = "Bakugo", Sound = "Bakugo 200%", Id = "rbxassetid://140687924372203", Gain = 2, Range = 260, Length = 3 },
	FinalBoss = {
		Folder = "Bakugo", Sound = "I'M THE FINAL BOSS, GOT IT? BAKUGO", Id = "rbxassetid://87930671985739", Gain = 2, Range = 260,
		Trim = true, First = 0.1, Cut = 3.2, Length = 8,
	},
	-- Deku's awakening (G) - Prime Deku's too
	DekuAwaken = { Folder = "Deku", Sound = "Deku full cowel", Id = "rbxassetid://110359127412280", Gain = 2, Range = 260, Length = 7 },
	-- (round 74) DIO
	ZaWarudo = { Id = "", Text = "The World! Time, stop!", VoiceId = "5", Pitch = -2, Speed = 0.95, Volume = 3, Range = 300, Bubble = "ZA WARUDO!!" },
	TimeResume = { Id = "", Text = "And time... moves again.", VoiceId = "5", Pitch = -2, Speed = 0.9, Volume = 3, Range = 300, Bubble = "TOKI WA UGOKIDASU..." },
	RoadRoller = { Id = "", Text = "Road roller da!", VoiceId = "5", Pitch = -1, Speed = 1.05, Volume = 3, Range = 300, Bubble = "ROAD ROLLER DA!!" },
	Wry = { Id = "", Text = "Wryyyyyy!", VoiceId = "5", Pitch = 0, Speed = 1, Volume = 3, Range = 300, Bubble = "WRYYYYYYY!!" },
}

-- (round 76) who says what, and when. Awaken: the line when you awaken (G),
-- by quirk. Moves: lines that go off as a move does, by the move's Id - All
-- Might charging up before every move he has. (The lines that land on a
-- moment - I AM HERE, SMASH! on the Detroit Smash, UNITED STATES OF SMASH,
-- Bakugo's FINAL BOSS - are said by their moves themselves.)
Config.VoiceCues = {
	Awaken = { Explosion = "Bakugo200", FullCowl = "DekuAwaken", PrimeDeku = "DekuAwaken" },
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
-- (round 77) whose punches sound like their own (by the attacker's quirk):
-- { light hit cue, heavy hit cue }
Config.HitSounds = {
	OneForAll = { "MightHit", "MightHeavyHit" },
	PrimeMight = { "MightHit", "MightHeavyHit" },
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
	Ice = {
		{ Id = L.IceHammer, Volume = 2.77, Speed = { 0.85, 1 } },
		{ Id = L.IceCrunch, Volume = 2.46, Speed = { 0.9, 1.05 }, Length = 0.9 },
		{ Id = L.SubBoom, Volume = 1.08, Speed = 1.2, Length = 0.6 },
	},
	Shatter = { Gap = 0.06, { Id = L.GlassBreak, Volume = 2.74, Speed = { 1, 1.2 } }, { Id = L.GlassDebris, Volume = 2.74, Speed = { 0.9, 1.1 } } },
	Fire = { { Id = L.FireWhoosh, Volume = 1.83, Speed = { 0.9, 1.05 }, Length = 1.4 }, { Id = L.FlameLick, Volume = 1.83, Speed = { 0.9, 1.1 }, Length = 0.9 } },
	-- Iida's engines: a rising rev, then the exhaust roar
	Engine = { { Id = L.MotorRev, Volume = 1.69, Speed = { 1.1, 1.25 }, Length = 0.8 }, { Id = S.Roar, Volume = 0.74, Speed = { 1.25, 1.4 }, Length = 0.8 } },
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
	BlitzSlow = { { Id = L.SuckShort, Volume = 2.4, Speed = 0.45, Length = 0.9 }, { Id = L.EnergyGrowl, Volume = 0.8, Speed = 0.5, Length = 0.8 } },
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
	ReciproRev = { { Id = L.MotorRev, Volume = 1.6, Speed = 1.35, Length = 0.6 }, { Id = S.Roar, Volume = 0.89, Speed = 1.6, Length = 0.5 } },
	ReciproBoom = {
		Range = 700,
		{ Id = L.JetPass, Volume = 1.36, Speed = 1.3, Length = 1 },
		{ Id = L.WhooshExplosion, Volume = 1.02, Speed = 1.2, Length = 0.8 },
		{ Id = L.CrackyPunch, Volume = 1.7, Speed = 0.9, Length = 0.4 },
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
	UltEngine = { Range = 1200, { Id = L.MotorRev, Volume = 1.78, Speed = 1.1, Length = 1.4 }, { Id = L.JetPass, Volume = 1.42, Speed = 0.9, Length = 2 }, { Id = S.Roar, Volume = 1.07, Speed = 1.4, Length = 1.4 } },
	-- DECAY: everything he touches cracks, crumbles and pours away as dust
	Crumble = {
		Gap = 0.05,
		{ Id = L.BoulderCrack, Volume = 1.65, Speed = { 0.85, 1.05 }, Length = 1 },
		{ Id = L.DirtBurst, Volume = 1.92, Speed = { 0.9, 1.1 }, Length = 1 },
	},
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
	-- punch and comes back up through them
	MightUSSImpact = {
		Range = 2400,
		{ Id = L.CrackyPunch, Volume = 0.9, Speed = 0.6, Length = 0.6, Distort = 0.25, Fade = 0.3 },
		{ Id = L.BodySlamThump, Volume = 1, Speed = 0.7, Length = 1.1, Peak = true, Eq = { 5, 0, -5 }, Fade = 0.6 },
		{ Id = L.DeepImpact, Volume = 0.85, Length = 4.2, Peak = true, PreRoll = 0.03, Fade = 2.4 },
		{ Id = L.ThunderBlast, Volume = 0.8, Speed = 0.9, Length = 4, Peak = true, Delay = 0.03, Fade = 2.4 },
		{ Id = L.AirPound, Volume = 0.95, Speed = 0.75, Length = 1.6, Peak = true, Fade = 0.8 },
		{ Id = L.SonicPressure, Volume = 0.75, Speed = 0.9, Length = 3.2, Peak = true, Delay = 0.06, Fade = 2 },
		{ Id = L.BigBoomTail, Volume = 0.7, Length = 4.5, Peak = true, Delay = 0.1, Fade = 3 },
		{ Id = L.Quake, Volume = 0.45, Delay = 0.25, Length = 3.2, Fade = 2.2 },
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
	-- a whiff: he over-reaches through the air
	USSWhiff = { { Id = L.SwishLarge, Volume = 1.1, Speed = 0.8, Length = 0.6 }, { Id = L.WhooshBurst, Volume = 0.4, Speed = 0.9, Length = 0.6, Fade = 0.3 } },
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
	-- KO + interface (played flat, not in the world)
	KO = { Range = 500, { Id = L.BodyFall, Volume = 1.85, Speed = 0.9, Length = 1 }, { Id = L.CrackThud, Volume = 1.85, Speed = 0.8, Length = 0.6 }, { Id = L.SubBoom, Volume = 1.85, Speed = 0.7 } },
	KOConfirm = { { Id = S.Stinger, Volume = 1.2 }, { Id = L.CrackyPunch, Volume = 0.96, Speed = 0.6, Length = 0.4 } },
	Streak = { { Id = S.Victory, Volume = 0.7 } },
	RankUp = { { Id = S.Victory, Volume = 0.9 }, { Id = S.Stinger, Volume = 0.7, Speed = 1.25, Delay = 0.12 } }, -- a new hero rank
	Knocked = { { Id = S.Negative, Volume = 0.9, Speed = 0.8 }, { Id = S.Stinger, Volume = 0.6, Speed = 0.7 } },
	-- bucks + shop
	Bucks = { { Id = L.CoinThrow, Volume = 1.3, Speed = 1.1 }, { Id = S.Ping, Volume = 0.5, Speed = 1.5 } },
	Purchase = { { Id = L.CoinThrow, Volume = 1.2 }, { Id = S.Stinger, Volume = 0.5, Speed = 1.6 } },
	ShopNo = { { Id = S.Negative, Volume = 0.8 } },
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
		Description = "Point-blank blasts and flying on explosions - HOLD DASH (Q) to fly. 1 AP Shot, 2 Blast Rush, 3 Eruption Orbit, 4 Scorched Earth - every one changes in the air. R: Stun Grenade (blinds anyone not guarding). Ult: Dynamight - Howitzer Impact, R Explosive Speed (a blur down the street into a point-blank Explosion), 4 Full-Body Cluster (his last stand against Shigaraki).",
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
		Abilities = {
			-- a pinpoint armour-piercing beam that drills through buildings. On
			-- the ground it goes straight out (never into the street at his
			-- feet); in the air he can aim it down at them, and the recoil
			-- kicks him up and back
			{
				Id = "APShot", Name = "AP SHOT", Cooldown = 9.5, Damage = 10, Stun = 0.25, CutIn = false, Range = 110,
				Aim = { Up = 55, Down = 0 }, AirAim = { Up = 55, Down = 80 },
			},
			-- a rocket charge that blasts through whatever's in the way; in the
			-- air it's a dive-bomb on the aim point (Range) and the landing goes
			-- off (Radius round it, Stun)
			{ Id = "BlastRush", Name = "BLAST RUSH", Cooldown = 12, Damage = 6, FinisherDamage = 9, Radius = 12, Stun = 0.45, CutIn = false, Range = 45 },
			-- palm to the street: it erupts under whoever's in front (Radius,
			-- Range studs ahead) and throws them up; he rockets up after them,
			-- circles them blasting (OrbitHits), and the last blast from above
			-- drives them into the street. In the air: straight for the nearest one
			{
				Id = "BlastOrbit", Name = "ERUPTION ORBIT", Cooldown = 18, Damage = 6, OrbitDamage = 2, OrbitHits = 3, SlamDamage = 8,
				SlamStun = 0.9, CutIn = true, Range = 14, Radius = 8, Launch = 95,
			},
		},
		-- R: a flash so bright it blinds (Blind seconds) anyone caught in it
		-- who isn't guarding; a raised guard takes it on the arms
		Special = { Id = "StunGrenade", Name = "STUN GRENADE", Cooldown = 25, Damage = 3, CutIn = true, Radius = 20, Blind = 1.1, Stun = 0.6 },
		-- 4: grabs the face in front of him, rockets forward dragging them
		-- through the street and blows up in their face (in the air: straight
		-- down, head first into the street)
		Extra = { Id = "ScorchedEarth", Name = "SCORCHED EARTH", Cooldown = 17, Damage = 10, DragDamage = 2, Stun = 0.9, CutIn = true, Range = 8, DragTime = 0.6, DragSpeed = 70 },
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
			Special = {
				Id = "ExplosiveSpeed", Name = "EXPLOSIVE SPEED", Cooldown = 20, Damage = 24, SplashDamage = 6, Radius = 10,
				Range = 75, Width = 4.5, Speed = 320, WindUp = 1.25, SlowMo = 1.3, FlipTime = 0.14, FlipRise = 3, ActionTime = 0.7, CutIn = false,
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
			-- one explosion.
			Extra = {
				Id = "FullBodyCluster", Name = "FULL-BODY CLUSTER", Cooldown = 22, CutIn = false,
				WalkTime = 0.9, WalkDistance = 5, Range = 55, Hits = 5, FirstGap = 0.24, Ramp = 0.8, VoidTime = 0.7,
				BlinkDamage = 5, HitDamage = 2, FinalDamage = 12, SplashDamage = 5, Radius = 12, SelfDamage = 8,
				Say = "IZUKU... YOU'VE GOTTA WIN.",
			},
			Name = "DYNAMIGHT",
			Shout = "I'LL BLOW YOU ALL AWAY!!",
			Color = Color3.fromRGB(255, 96, 20),
			AccentColor = Color3.fromRGB(255, 240, 140),
			Duration = 22,
			WalkSpeed = 21,
			JumpPower = 60,
			Abilities = {
				-- (LiveAim: every shot goes where he's aiming right then)
				{ Id = "AutoCannon", Name = "AP SHOT: AUTO-CANNON", Cooldown = 12, Damage = 4, Shots = 6, Stun = 0.25, LiveAim = 0.15, CutIn = true },
				{ Id = "Cluster", Name = "CLUSTER", Cooldown = 28, Damage = 5, BombStun = 0.35, FinisherDamage = 20, Radius = 32, CutIn = true, Range = 80 },
				-- the real one: up, spinning into a tornado of explosions, and down
				-- on the aim point (Range) - Radius-stud blast, a Crater-stud hole
				{
					Id = "Howitzer", Name = "HOWITZER IMPACT", Cooldown = 36, Damage = 32, CutIn = false, Range = 110, Radius = 34, Crater = 34,
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
		Description = "Right side freezes, left side burns. Ice: Ice Spike, Frost Burst, Glacier Breaker, 4 Ice Slider. R swaps sides. Fire: Flashfire, Flame Pillar, Flashfreeze Heatwave, 4 Jet Kindling (a flame-jet rush into a white-hot punch). Ult: Phosphor - Heaven-Piercing Ice Wall.",
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
		Extra = { Id = "IceSlider", Name = "ICE SLIDER", Cooldown = 9, Damage = 8, FreezeTime = 1, Range = 70, RideTime = 0.75, CutIn = false },
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
		-- Ult uses both sides at once (R is disabled while it lasts)
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
		-- R: five finger lances that punch straight through buildings
		Special = { Id = "RivetStab", Name = "RIVET STAB", Cooldown = 12, Damage = 16, CutIn = false, Range = 110 },
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
				-- their screen and their lock-on lost for Jam seconds
				{ Id = "RadioWaves", Name = "RADIO WAVES", Cooldown = 9, Damage = 26, CutIn = true, Range = 85, Angle = 60, Speed = 220, Jam = 2.5 },
				-- lances erupt from him in every direction
				{ Id = "RivetStorm", Name = "RIVET STORM", Cooldown = 13.5, Damage = 22, CutIn = true, Range = 90 },
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
			{ Id = "SpikePrison", Name = "SPIKE PRISON", Cooldown = 17.5, Damage = 30, CutIn = true, Range = 60, Radius = 12, Hold = 1.6 },
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
				{ Id = "BreakRestore", Name = "BREAK AND RESTORE", Cooldown = 30, Damage = 28, ReturnDamage = 30, Radius = 60, Hold = 1.3, CutIn = true },
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
}

Config.QuirkOrder = { "Explosion", "OneForAll", "FullCowl", "HalfCold", "Engine", "Creation", "Lemillion", "Manifest", "Arbor", "Electrification", "Overhaul", "Decay", "Compress", "Double", "Limitless", "CrazyDiamond", "PlusUltra", "Hellflame", "Blueflame", "PrimeDeku", "PrimeMight", "TheWorld" }

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
