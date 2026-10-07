-- Destruction (ModuleScript) — ServerScriptService.Destruction
-- Carves the map with the actual shape of each attack.
--
-- How it works: every map part hit by an attack is recursively cut in half
-- (in its own local space, so rotated parts work) until the pieces either sit
-- fully outside the attack shape (kept), fully inside it (removed), or are
-- small enough to decide by their centre. Pieces that end up just outside the
-- hole get the attack's "rim" look: scorched by fire and explosions, frosted
-- by ice, cracked by impacts. Removed pieces can fly off as physical debris.
--
-- Only BaseParts with the attribute Destroyable == true are touched (the map
-- ships with these set; the "Undestroyable" ground layer is left alone).
-- Broken parts are stored and rebuilt RegenTime seconds after their last hit.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuirkConfig"))
local Settings = Config.Destruction or { Enabled = true, RegenTime = 40, DebrisLifetime = 7, MaxDebris = 260 }

local Destruction = {}

local UP = Vector3.new(0, 1, 0)
local EPS = 1e-3
local rng = Random.new()

local map = workspace:WaitForChild("Map")

local debrisFolder = workspace:FindFirstChild("MapDebris") or Instance.new("Folder")
debrisFolder.Name = "MapDebris"
debrisFolder.Parent = workspace

local store = Instance.new("Folder")
store.Name = "BrokenMapParts"
store.Parent = ServerStorage

pcall(function()
	PhysicsService:RegisterCollisionGroup("Debris")
	PhysicsService:RegisterCollisionGroup("Characters")
	PhysicsService:CollisionGroupSetCollidable("Debris", "Characters", false)
	-- ragdoll limb colliders touch the map, but not bodies, each other or debris
	PhysicsService:RegisterCollisionGroup("Ragdoll")
	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Characters", false)
	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Ragdoll", false)
	PhysicsService:CollisionGroupSetCollidable("Ragdoll", "Debris", false)
	-- bodies pass through each other (Config.Physics): no shoving matches or
	-- body-block flings in the middle of a combo
	local physics = Config.Physics or {}
	PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", physics.CharacterCollisions == true)
	-- Lemillion's PHASE DIVE: his body goes through everything - roofs,
	-- floors, the street, people, rubble (his own machine puts him in it)
	PhysicsService:RegisterCollisionGroup("PhaseDive")
	for _, other in { "Default", "Characters", "Debris", "Ragdoll", "PhaseDive" } do
		PhysicsService:CollisionGroupSetCollidable("PhaseDive", other, false)
	end
	-- (round 86) DEV FLIGHT: a flying dev's body (his own machine puts it
	-- in this group) goes through people, rubble and limp bodies - only the
	-- map stops him (he knocks people aside instead: the server's Ram)
	PhysicsService:RegisterCollisionGroup("DevFlyer")
	for _, other in { "Characters", "Debris", "Ragdoll", "PhaseDive", "DevFlyer" } do
		PhysicsService:CollisionGroupSetCollidable("DevFlyer", other, false)
	end
	-- (round 60) a body out of its owner's hands - down, held in a grab, a
	-- marble - lands on the street but never shoves, lifts or flings anyone
	PhysicsService:RegisterCollisionGroup("Loose")
	for _, other in { "Characters", "Debris", "Ragdoll", "Loose", "PhaseDive", "DevFlyer" } do
		PhysicsService:CollisionGroupSetCollidable("Loose", other, false)
	end
	-- (round 87) THROUGH-THE-BUILDING KNOCKBACK: the wall a thrown player's
	-- machine draws round his hole until the server's lands - solid to the
	-- camera (it doesn't swing through the wall after him), nothing to anyone
	PhysicsService:RegisterCollisionGroup("SmashGhost")
	for _, other in { "Default", "Characters", "Debris", "Ragdoll", "Loose", "PhaseDive", "DevFlyer", "SmashGhost" } do
		PhysicsService:CollisionGroupSetCollidable("SmashGhost", other, false)
	end
end)

---------------------------------------------------------------------------
-- Attack profiles: how each kind of attack breaks things
---------------------------------------------------------------------------
-- MinSize  smallest piece the cutter makes (smaller = finer hole shape)
-- Rim      how far past the hole the rim effect reaches
-- RimEffect scorch | frost | crack | decay | erase | overhaul
-- Fling    how removed chunks fly: radial | directional | tangential | up | drop
-- Tint     look of flying chunks: burnt | frost | decay | void | overhaul | nil
-- NoCarve  mark the area without removing anything (flamethrower scorch)

local PROFILES = {
	Explosion = { MinSize = 3, Rim = 2, RimEffect = "scorch", Fling = "radial", Speed = { 40, 85 }, Up = { 25, 55 }, Tint = "burnt", FireChance = 0.25, Debris = 20, Budget = 150 },
	BigExplosion = { MinSize = 4, Rim = 2.5, RimEffect = "scorch", Fling = "radial", Speed = { 50, 100 }, Up = { 35, 70 }, Tint = "burnt", FireChance = 0.25, Debris = 32, Budget = 320 },
	Crater = { MinSize = 4, Rim = 2.5, RimEffect = "crack", Fling = "radial", Speed = { 45, 100 }, Up = { 50, 95 }, Debris = 32, Budget = 320 },
	Wind = { MinSize = 3.5, Rim = 1.2, RimEffect = "crack", Fling = "directional", Speed = { 80, 150 }, Up = { 10, 40 }, Debris = 30, Budget = 260 },
	Impact = { MinSize = 2.5, Rim = 1, RimEffect = "crack", Fling = "directional", Speed = { 30, 65 }, Up = { 10, 30 }, Debris = 8, Budget = 70 },
	Tunnel = { MinSize = 2.5, Rim = 0, RimEffect = "crack", Fling = "directional", Speed = { 40, 80 }, Up = { 5, 25 }, Debris = 5, Budget = 60 },
	Slash = { MinSize = 1.5, Rim = 0.6, RimEffect = "crack", Fling = "directional", Speed = { 40, 80 }, Up = { 5, 20 }, Debris = 12, Budget = 140 },
	Whirl = { MinSize = 3.5, Rim = 1.5, RimEffect = "crack", Fling = "tangential", Speed = { 60, 110 }, Up = { 20, 45 }, Debris = 24, Budget = 220 },
	Ice = { MinSize = 1.8, Rim = 1.2, RimEffect = "frost", Fling = "drop", Speed = { 2, 8 }, Up = { 0, 6 }, Tint = "frost", Debris = 2, Budget = 50 },
	Fire = { MinSize = 3, Rim = 2, RimEffect = "scorch", Fling = "up", Speed = { 8, 25 }, Up = { 60, 110 }, Tint = "burnt", FireChance = 0.4, Debris = 16, Budget = 180 },
	Scorch = { MinSize = 3, Rim = 0, RimEffect = "scorch", NoCarve = true, Debris = 0, Budget = 110 },
	-- beams drill a clean tunnel straight through buildings
	Beam = { MinSize = 1.8, Rim = 1, RimEffect = "scorch", Fling = "directional", Speed = { 20, 50 }, Up = { 5, 20 }, Tint = "burnt", Debris = 8, Budget = 160 },
	-- DECAY: things don't blow apart, they crumble where they stand
	Decay = { MinSize = 4.5, Rim = 2.2, RimEffect = "decay", Fling = "crumble", Speed = { 2, 8 }, Up = { 0, 5 }, Tint = "decay", Debris = 26, Budget = 260 },
	DecayHuge = { MinSize = 7, Rim = 2.6, RimEffect = "decay", Fling = "crumble", Speed = { 2, 10 }, Up = { 0, 6 }, Tint = "decay", Debris = 30, Budget = 320 },
	Rivet = { MinSize = 1.6, Rim = 0.8, RimEffect = "crack", Fling = "directional", Speed = { 20, 45 }, Up = { 2, 10 }, Tint = "decay", Debris = 6, Budget = 120 },
	-- the biggest blasts (Bakugo's Howitzer Impact): coarse pieces, flung hard
	-- the NUKE's blast wave: coarse pieces (it's a whole district), flung hard
	Nuke = { MinSize = 8, Rim = 4, RimEffect = "scorch", Fling = "radial", Speed = { 90, 180 }, Up = { 60, 140 }, Tint = "burnt", FireChance = 0.35, Debris = 60, Budget = 1100 },
	HugeExplosion = { MinSize = 5.5, Rim = 3, RimEffect = "scorch", Fling = "radial", Speed = { 60, 130 }, Up = { 50, 110 }, Tint = "burnt", FireChance = 0.3, Debris = 45, Budget = 700 },
	SmallExplosion = { MinSize = 3.5, Rim = 1.5, RimEffect = "scorch", Fling = "radial", Speed = { 35, 70 }, Up = { 25, 50 }, Tint = "burnt", FireChance = 0.2, Debris = 6, Budget = 60 },
	-- (round 92) Bakugo's MAX CAPACITY: the gauntlet's blast tearing a
	-- trench down the street - coarse, scorched, the chunks blown on down
	-- the aim (Config.Quirks.Explosion.Extra.Budget a cut)
	BracerBlast = { MinSize = 4, Rim = 2.2, RimEffect = "scorch", Fling = "directional", Speed = { 70, 150 }, Up = { 15, 50 }, Tint = "burnt", FireChance = 0.3, Debris = 24, Budget = 180 },
	-- Limitless: Blue drags the rubble INTO the point; Hollow Purple erases
	-- (almost nothing is left to fall, and the cut edge is scorched violet)
	Implode = { MinSize = 3, Rim = 1.5, RimEffect = "crack", Fling = "inward", Speed = { 45, 95 }, Up = { 4, 18 }, Debris = 26, Budget = 240 },
	Erase = { MinSize = 4.5, Rim = 1.6, RimEffect = "erase", Fling = "radial", Speed = { 4, 12 }, Up = { 2, 8 }, Tint = "void", Debris = 5, Budget = 700 },
	-- OVERHAUL: touched matter comes apart into chunks that pop loose, and the
	-- edge of what's left is shot through with his red
	Overhaul = { MinSize = 3, Rim = 1.6, RimEffect = "overhaul", Fling = "up", Speed = { 6, 18 }, Up = { 20, 45 }, Tint = "overhaul", Debris = 20, Budget = 240 },
	OverhaulHuge = { MinSize = 5, Rim = 2.4, RimEffect = "overhaul", Fling = "up", Speed = { 8, 24 }, Up = { 30, 60 }, Tint = "overhaul", Debris = 34, Budget = 520 },
	-- CRAZY DIAMOND: the Stand's rush punches straight through walls; the
	-- ult's ground punch shatters everything around at once (to be restored)
	Stand = { MinSize = 2.5, Rim = 1, RimEffect = "crack", Fling = "directional", Speed = { 50, 95 }, Up = { 10, 30 }, Debris = 10, Budget = 120 },
	-- MR. COMPRESS: the piece shrinks into a marble - a clean cut, nothing
	-- flies off (it's in his pocket)
	Compress = { MinSize = 2.5, Rim = 0.5, RimEffect = "crack", Fling = "drop", Speed = { 0, 2 }, Up = { 0, 2 }, Debris = 0, Budget = 140 },
	Shatter = { MinSize = 5, Rim = 2, RimEffect = "crack", Fling = "radial", Speed = { 40, 80 }, Up = { 40, 80 }, Debris = 70, Budget = 600 },
	-- (round 96) DISMANTLE: the cut's gash in the street (a fine, cracked
	-- line), and the top of a building coming down - the chunks off it
	-- thrown out round where it lands, and its crater
	DismantleGash = { MinSize = 2, Rim = 0.8, RimEffect = "crack", Fling = "directional", Speed = { 30, 60 }, Up = { 5, 20 }, Debris = 6, Budget = 160 },
	Collapse = { MinSize = 4, Rim = 2, RimEffect = "crack", Fling = "radial", Speed = { 25, 65 }, Up = { 25, 60 }, Debris = 50, Budget = 320 },
	-- (round 86) DEV FLIGHT: a body at FAST and up punching clean through a
	-- building - chunks blown out of the far side and on down the street
	FlyThrough = { MinSize = 3, Rim = 1.2, RimEffect = "crack", Fling = "directional", Speed = { 60, 140 }, Up = { 5, 25 }, Debris = 14, Budget = 160 },
	-- (round 87) THROUGH-THE-BUILDING KNOCKBACK (Config.Smash): a body-sized
	-- hole punched through a wall - a fine cut for the body's outline, a
	-- cracked rim, the brick and glass blown out the far side along its
	-- path; Lite when the server's carving a lot already (coarse, a few
	-- chunks); the splat's crater - cracked round it, the grit dropping
	-- (blown out ahead of him - faster than he goes on through it, so it's
	-- in front, not in his camera's way)
	SmashThrough = { MinSize = 2.2, Rim = 1.4, RimEffect = "crack", Fling = "directional", Speed = { 110, 190 }, Up = { 4, 22 }, Debris = 16, Budget = 150 },
	SmashThroughLite = { MinSize = 4, Rim = 0.8, RimEffect = "crack", Fling = "directional", Speed = { 100, 160 }, Up = { 4, 18 }, Debris = 3, Budget = 45 },
	SmashSplat = { MinSize = 1.6, Rim = 1.8, RimEffect = "crack", Fling = "drop", Speed = { 2, 10 }, Up = { 0, 6 }, Debris = 6, Budget = 90 },
	-- (round 89) THE BOMB (Config.DevFlight.Bomb): a dev flying into the
	-- street or a building at mach speed - a blast hole in the street and
	-- whatever stands round it, scorched, the chunks blown out hard (its own
	-- cap, the size of the biggest blasts': a whole corner of a block goes)
	FlightBomb = { MinSize = 4.5, Rim = 3, RimEffect = "scorch", Fling = "radial", Speed = { 70, 150 }, Up = { 60, 130 }, Tint = "burnt", FireChance = 0.3, Debris = 48, Budget = 700 },
	-- (round 89) ALL THE WAY DOWN (Config.DevFlight.Shaft): straight down
	-- through a building's floors - a body-wide shaft, the slabs' chunks
	-- driven down it ahead of him. ((round 89 review) its budget is the
	-- shaft's own - Config.DevFlight.Shaft.Budget by its length - and a
	-- touch coarser: a 130-stud tower's shaft is ~1000 pieces as it is)
	FlyShaft = { MinSize = 4, Rim = 1.4, RimEffect = "crack", Fling = "directional", Speed = { 40, 90 }, Up = { 0, 12 }, Debris = 16, Budget = 420 },
	-- (round 90) SAITAMA'S SERIOUS PUNCH: the trench of holes down the punch's
	-- line through whatever stands there - coarse (a whole city block at a
	-- time; every screen's own copy of the city is what's blown away), the
	-- chunks blasted on down the line hard (Config.Quirks.Saitama's
	-- TrenchBudget a cut). And the SERIOUS TABLE FLIP: the slab of street
	-- torn out of its bed - big pieces, thrown up
	SeriousPunch = { MinSize = 8, Rim = 3, RimEffect = "crack", Fling = "directional", Speed = { 160, 320 }, Up = { 20, 90 }, Debris = 18, Budget = 260 },
	TableFlip = { MinSize = 4, Rim = 1.5, RimEffect = "crack", Fling = "up", Speed = { 10, 30 }, Up = { 50, 90 }, Debris = 14, Budget = 220 },
	-- (round 99) CRATERS (Config.DevFlight.Crater): LIGHTSPEED's and
	-- GODSPEED's crater - the street and everything standing round it blown
	-- out, coarse (a whole storey at a time: on the real city's densest
	-- corners its 60-90 stud craters need 560-1340 pieces at this size, under
	-- the tiers' budgets - r99/out/craters_sims.txt), the rim scorched, the
	-- chunks thrown out hard and HIGH (its budget the tier's); and the
	-- buildings round it ripped open where the shock ring hits them (a
	-- facade's worth, thrown on out)
	FlightCrater = { MinSize = 12, Rim = 4, RimEffect = "scorch", Fling = "radial", Speed = { 110, 240 }, Up = { 120, 260 }, Tint = "burnt", FireChance = 0.25, Debris = 60, Budget = 1100 },
	CraterRip = { MinSize = 6, Rim = 2.5, RimEffect = "scorch", Fling = "radial", Speed = { 120, 220 }, Up = { 60, 140 }, Tint = "burnt", FireChance = 0.2, Debris = 16, Budget = 120 },
}
Destruction.Profiles = PROFILES

local SCORCH = Color3.fromRGB(30, 24, 22)
local FROST = Color3.fromRGB(176, 226, 246)
local DUST = Color3.fromRGB(116, 106, 110)
local VOID = Color3.fromRGB(46, 24, 70) -- Hollow Purple's cut edge
local OVERHAUL_RED = Color3.fromRGB(150, 28, 40) -- Overhaul's disassembly

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

local function vmin(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end

local function vmax(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

local function obbClosest(cf, half, p)
	local lp = cf:PointToObjectSpace(p)
	return cf:PointToWorldSpace(Vector3.new(
		math.clamp(lp.X, -half.X, half.X),
		math.clamp(lp.Y, -half.Y, half.Y),
		math.clamp(lp.Z, -half.Z, half.Z)
	))
end

local function aabbOf(cf, half)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ext = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	)
	return cf.Position - ext, cf.Position + ext
end

-- Every shape is convex and exposes closest(p): the nearest point of the
-- shape to p (p itself when p is inside).
local function sphereShape(c, r)
	return {
		center = c,
		min = c - Vector3.one * r,
		max = c + Vector3.one * r,
		closest = function(p)
			local v = p - c
			local m = v.Magnitude
			if m <= r then
				return p
			end
			return c + v * (r / m)
		end,
	}
end

local function capsuleShape(a, b, r)
	local ab = b - a
	local len2 = ab:Dot(ab)
	return {
		center = (a + b) / 2,
		min = vmin(a, b) - Vector3.one * r,
		max = vmax(a, b) + Vector3.one * r,
		closest = function(p)
			local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
			local q = a + ab * t
			local v = p - q
			local m = v.Magnitude
			if m <= r then
				return p
			end
			return q + v * (r / m)
		end,
	}
end

local function boxShape(cf, size)
	local half = size / 2
	local mn, mx = aabbOf(cf, half)
	return {
		center = cf.Position,
		min = mn,
		max = mx,
		closest = function(p)
			return obbClosest(cf, half, p)
		end,
	}
end

-- vertical cylinder, c = centre
local function cylinderShape(c, r, h)
	local hh = h / 2
	return {
		center = c,
		min = c - Vector3.new(r, hh, r),
		max = c + Vector3.new(r, hh, r),
		closest = function(p)
			local y = math.clamp(p.Y, c.Y - hh, c.Y + hh)
			local vx, vz = p.X - c.X, p.Z - c.Z
			local m = math.sqrt(vx * vx + vz * vz)
			if m > r then
				vx, vz = vx * r / m, vz * r / m
			end
			return Vector3.new(c.X + vx, y, c.Z + vz)
		end,
	}
end

local function pointDistance(shape, p)
	return (shape.closest(p) - p).Magnitude
end

-- Distance between an oriented box and a convex shape (alternating projections)
local function boxDistance(shape, cf, half)
	local p = cf.Position
	local dist = math.huge
	for _ = 1, 8 do
		local q = shape.closest(p)
		local p2 = obbClosest(cf, half, q)
		dist = (p2 - q).Magnitude
		if dist < EPS or (p2 - p).Magnitude < EPS then
			break
		end
		p = p2
	end
	return dist
end

local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- Distance to a convex set is convex, so its max over a box is at a corner
local function maxCornerDistance(shape, cf, half)
	local worst = 0
	for _, c in CORNERS do
		worst = math.max(worst, pointDistance(shape, cf:PointToWorldSpace(half * c)))
	end
	return worst
end

---------------------------------------------------------------------------
-- Bookkeeping (for regeneration)
---------------------------------------------------------------------------

local originals = {} -- [original part] = { Parent, LastHit, Fragments = { [frag] = true } }

-- is where a part came from still in the world? (a structure that's been
-- taken down since isn't)
local function stillInWorld(parent)
	local ok, inside = pcall(function()
		return parent ~= nil and parent:IsDescendantOf(workspace)
	end)
	return ok and inside
end
local fragOrigin = {} -- [fragment] = original part
-- (round 96) a piece of a Dismantle cut that's coming off: [part] = its
-- group (Slice / Collapse / Crumble, below) - no carve touches it meanwhile
local moving = {}

-- Take a part out of the world. Originals are kept for regen; fragments are destroyed.
local function retire(part)
	local orig = fragOrigin[part]
	if orig then
		fragOrigin[part] = nil
		local rec = originals[orig]
		if rec then
			rec.Fragments[part] = nil
			rec.LastHit = os.clock()
		end
		part:Destroy()
		return orig
	end
	originals[part] = { Parent = part.Parent, LastHit = os.clock(), Fragments = {} }
	part.Parent = store
	return part
end

local COPY = {
	"Name", "Color", "Material", "MaterialVariant", "Transparency", "Reflectance", "CastShadow",
	"CanCollide", "CanQuery", "CanTouch", "CollisionGroup",
	"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface",
}

local function snapshot(part)
	local props = {}
	for _, k in COPY do
		props[k] = part[k]
	end
	props.Scorched = part:GetAttribute("Scorched")
	props.Frosted = part:GetAttribute("Frosted")
	props.Cracked = part:GetAttribute("Cracked")
	props.Decayed = part:GetAttribute("Decayed")
	return props
end

local function applyProps(p, props)
	for _, k in COPY do
		p[k] = props[k]
	end
end

local function makeFragment(props, cf, size, parent, orig)
	local p = Instance.new("Part")
	applyProps(p, props)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p:SetAttribute("Destroyable", true)
	p:SetAttribute("Fragment", true)
	if props.Scorched then
		p:SetAttribute("Scorched", true)
	end
	if props.Frosted then
		p:SetAttribute("Frosted", true)
	end
	if props.Cracked then
		p:SetAttribute("Cracked", true)
	end
	if props.Decayed then
		p:SetAttribute("Decayed", true)
	end
	p.Parent = parent
	fragOrigin[p] = orig
	local rec = originals[orig]
	if rec then
		rec.Fragments[p] = true
	end
	return p
end

local function applyRim(p, effect)
	if effect == "scorch" then
		if not p:GetAttribute("Scorched") then
			p:SetAttribute("Scorched", true)
			p.Color = p.Color:Lerp(SCORCH, 0.6)
		end
	elseif effect == "frost" then
		if not p:GetAttribute("Frosted") then
			p:SetAttribute("Frosted", true)
			p.Material = Enum.Material.Ice
			p.Color = p.Color:Lerp(FROST, 0.7)
		end
	elseif effect == "crack" then
		if not p:GetAttribute("Cracked") then
			p:SetAttribute("Cracked", true)
			p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.2)
		end
	elseif effect == "erase" then
		if not p:GetAttribute("Erased") then
			p:SetAttribute("Erased", true)
			p.Color = p.Color:Lerp(VOID, 0.55)
		end
	elseif effect == "overhaul" then
		if not p:GetAttribute("Overhauled") then
			p:SetAttribute("Overhauled", true)
			p.Color = p.Color:Lerp(OVERHAUL_RED, 0.35)
		end
	elseif effect == "decay" then
		-- the edge of the decay: dusty, grey and dry
		if not p:GetAttribute("Decayed") then
			p:SetAttribute("Decayed", true)
			p.Material = Enum.Material.Slate
			p.Color = p.Color:Lerp(DUST, 0.6)
		end
	end
end

---------------------------------------------------------------------------
-- Debris
---------------------------------------------------------------------------

local debrisQueue = {}

local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		return fallback
	end
	return f.Unit
end

local function flingVelocity(ctx, pos)
	local prof = ctx.profile
	local speed = rng:NextNumber(prof.Speed[1], prof.Speed[2])
	local up = rng:NextNumber(prof.Up[1], prof.Up[2])
	local center = ctx.shape.center
	local dir
	if prof.Fling == "radial" then
		local v = pos - center
		dir = v.Magnitude > 0.1 and v.Unit or rng:NextUnitVector()
	elseif prof.Fling == "directional" then
		dir = (ctx.dir.Magnitude > 0.1 and ctx.dir.Unit or rng:NextUnitVector()) + rng:NextUnitVector() * 0.25
	elseif prof.Fling == "tangential" then
		local out = flatUnit(pos - center, rng:NextUnitVector())
		dir = UP:Cross(out) + out * 0.6
	elseif prof.Fling == "up" then
		dir = flatUnit(pos - center, Vector3.zero) * 0.4
	elseif prof.Fling == "inward" then
		-- sucked toward the centre (Blue)
		local v = center - pos
		dir = v.Magnitude > 0.1 and v.Unit or rng:NextUnitVector()
	elseif prof.Fling == "crumble" then
		-- falls apart where it stood, with a little outward drift
		dir = flatUnit(pos - center, rng:NextUnitVector()) * 0.3 + Vector3.new(0, -0.2, 0)
	else
		dir = rng:NextUnitVector()
	end
	if dir.Magnitude < 0.01 then
		dir = rng:NextUnitVector()
	end
	return dir.Unit * speed + UP * up
end

local function spawnDebris(props, cf, size, ctx)
	local s = Vector3.new(math.min(size.X, 5), math.min(size.Y, 5), math.min(size.Z, 5))
	if s.X * s.Y * s.Z < 0.05 then
		return
	end
	local p = Instance.new("Part")
	applyProps(p, props)
	p.Size = s
	p.CFrame = cf
	p.Anchored = false
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CollisionGroup = "Debris"
	local tint = ctx.profile.Tint
	if tint == "burnt" and rng:NextNumber() < 0.6 then
		p.Color = p.Color:Lerp(SCORCH, 0.55)
	elseif tint == "frost" then
		p.Material = Enum.Material.Ice
		p.Color = p.Color:Lerp(FROST, 0.7)
	elseif tint == "decay" then
		p.Material = Enum.Material.Slate
		p.Color = p.Color:Lerp(DUST, 0.65)
	elseif tint == "void" then
		p.Color = p.Color:Lerp(VOID, 0.7)
	elseif tint == "overhaul" and rng:NextNumber() < 0.5 then
		p.Color = p.Color:Lerp(OVERHAUL_RED, 0.45)
	end
	if ctx.profile.FireChance and rng:NextNumber() < ctx.profile.FireChance then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = p
	end
	p.Parent = debrisFolder
	if (Config.Physics or {}).ServerOwnedDebris ~= false then
		-- the server keeps simulating it: no hand-off between players' machines
		-- mid-flight (that hand-off is the stutter / teleport)
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
	end
	p.AssemblyLinearVelocity = flingVelocity(ctx, cf.Position)
	p.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(4, 12)
	Debris:AddItem(p, rng:NextNumber(Settings.DebrisLifetime * 0.7, Settings.DebrisLifetime * 1.2))
	table.insert(debrisQueue, p)
	while #debrisQueue > (Settings.MaxDebris or 260) do
		local oldest = table.remove(debrisQueue, 1)
		if oldest.Parent then
			oldest:Destroy()
		end
	end
end

-- keep the debris queue from growing with already-expired parts
task.spawn(function()
	while true do
		task.wait(5)
		local alive = {}
		for _, p in debrisQueue do
			if p.Parent then
				table.insert(alive, p)
			end
		end
		debrisQueue = alive
	end
end)

---------------------------------------------------------------------------
-- The cutter
---------------------------------------------------------------------------

local AXES = { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1) }

local function processPart(part, ctx)
	local shape, prof = ctx.shape, ctx.profile
	local rim = prof.Rim
	local cf, size = part.CFrame, part.Size
	local half = size / 2

	if boxDistance(shape, cf, half) > rim + EPS then
		return
	end
	if prof.NoCarve and part:GetAttribute("Scorched") and maxCornerDistance(shape, cf, half) < EPS then
		return -- already marked
	end

	local props = snapshot(part)

	-- wedges and other non-block shapes: break whole or leave alone
	if part.Shape ~= Enum.PartType.Block then
		if prof.NoCarve then
			return
		end
		if pointDistance(shape, cf.Position) < EPS or maxCornerDistance(shape, cf, half) < EPS then
			local orig = retire(part)
			if ctx.touched then
				ctx.touched[orig] = true
			end
			if ctx.debris > 0 then
				ctx.debris -= 1
				spawnDebris(props, cf, size, ctx)
			end
		end
		return
	end

	local keep, rimList, remove = {}, {}, {}
	local splits = 0
	local budget = ctx.budget

	local function visit(bcf, bsize, depth)
		local bhalf = bsize / 2
		local d = boxDistance(shape, bcf, bhalf)
		if d > rim + EPS then
			table.insert(keep, { bcf, bsize })
			return
		end
		local far = maxCornerDistance(shape, bcf, bhalf)
		if far < EPS then
			-- fully inside the attack
			table.insert(prof.NoCarve and rimList or remove, { bcf, bsize })
			return
		end
		if d > EPS and far <= rim then
			-- fully inside the rim band, not touching the hole
			table.insert(rimList, { bcf, bsize })
			return
		end
		-- split along the longest axis
		local axis, len = 1, bsize.X
		if bsize.Y > len then
			axis, len = 2, bsize.Y
		end
		if bsize.Z > len then
			axis, len = 3, bsize.Z
		end
		if len <= ctx.minSize or splits >= budget or depth > 26 then
			local cd = pointDistance(shape, bcf.Position)
			if cd < EPS then
				table.insert(prof.NoCarve and rimList or remove, { bcf, bsize })
			elseif cd <= rim then
				table.insert(rimList, { bcf, bsize })
			else
				table.insert(keep, { bcf, bsize })
			end
			return
		end
		splits += 1
		local ax = AXES[axis]
		local newSize = bsize - ax * (len / 2)
		visit(bcf * CFrame.new(ax * (len / 4)), newSize, depth + 1)
		visit(bcf * CFrame.new(ax * (-len / 4)), newSize, depth + 1)
	end
	visit(cf, size, 0)

	if #remove == 0 and #rimList == 0 then
		return
	end

	local parent = part.Parent
	local orig = retire(part)
	if ctx.touched then
		ctx.touched[orig] = true
	end
	for _, b in keep do
		makeFragment(props, b[1], b[2], parent, orig)
	end
	for _, b in rimList do
		applyRim(makeFragment(props, b[1], b[2], parent, orig), prof.RimEffect)
	end
	for _, b in remove do
		if ctx.debris > 0 and rng:NextNumber() < 0.6 then
			ctx.debris -= 1
			spawnDebris(props, b[1], b[2], ctx)
		end
	end
	ctx.budget = math.max(ctx.budget - (#keep + #rimList), 0)
end

local includeParams = OverlapParams.new()
includeParams.FilterType = Enum.RaycastFilterType.Include
includeParams.FilterDescendantsInstances = { map }
includeParams.MaxParts = 2000

-- shared (optional): { budget, debris } spent across several carves (a whole spike layout)
-- opts (optional, round 87): { Above = y: leave alone every part whose top is
-- at or under it (the floor a body's skidding on), Skip = { [part] = true } }
-- ((round 89 review) opts.Budget: this carve's own budget in place of the
-- profile's - a dev flight's shaft by its length, a bomb by what's left)
local function carve(shape, profileName, dir, shared, minSize, touched, opts)
	if not Settings.Enabled then
		return
	end
	local above = opts and tonumber(opts.Above)
	local skip = opts and type(opts.Skip) == "table" and opts.Skip or nil
	local prof = PROFILES[profileName] or PROFILES.Impact
	local pad = Vector3.one * (prof.Rim + 0.1)
	local mn, mx = shape.min - pad, shape.max + pad
	local parts = workspace:GetPartBoundsInBox(CFrame.new((mn + mx) / 2), mx - mn, includeParams)
	local ctx = {
		shape = shape,
		profile = prof,
		dir = typeof(dir) == "Vector3" and dir or Vector3.zero,
		budget = shared and shared.budget or (opts and tonumber(opts.Budget)) or prof.Budget or 200,
		debris = shared and shared.debris or prof.Debris or 20,
		minSize = minSize or prof.MinSize,
		touched = touched, -- (optional: the originals this carve took, for a hold)
	}
	for _, part in parts do
		if part.Parent and part:IsA("Part") and part:GetAttribute("Destroyable") == true and not moving[part]
			and not (skip and skip[part]) and not (above and part.Position.Y + (math.abs(part.CFrame.RightVector.Y) * part.Size.X
				+ math.abs(part.CFrame.UpVector.Y) * part.Size.Y + math.abs(part.CFrame.LookVector.Y) * part.Size.Z) / 2 <= above) then
			local ok, err = pcall(processPart, part, ctx)
			if not ok then
				warn("[Destruction] " .. tostring(err))
			end
		end
	end
	if shared then
		shared.budget = ctx.budget
		shared.debris = ctx.debris
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- (round 87) opts: carve()'s (Above / Skip: the floor left alone)
function Destruction.Sphere(center, radius, profileName, dir, opts)
	carve(sphereShape(center, radius), profileName, dir, nil, nil, nil, opts)
end

function Destruction.Capsule(a, b, radius, profileName, dir, opts)
	carve(capsuleShape(a, b, radius), profileName, dir, nil, nil, nil, opts)
end

function Destruction.Box(cf, size, profileName, dir)
	carve(boxShape(cf, size), profileName, dir)
end

function Destruction.Cylinder(center, radius, height, profileName, dir)
	carve(cylinderShape(center, radius, height), profileName, dir)
end

-- MR. COMPRESS: a piece of the map (a ball of it) shrinks into a marble. The
-- parts it takes stay gone - no regeneration - until the marble is thrown
-- (Release), then they're back on the usual timer. Returns the hold.
function Destruction.Compress(center, radius)
	local touched = {}
	carve(sphereShape(center, radius), "Compress", nil, nil, nil, touched)
	local n = 0
	for orig in touched do
		local rec = originals[orig]
		if rec then
			rec.Held = (rec.Held or 0) + 1
			n += 1
		end
	end
	return { Parts = touched, Count = n }
end

function Destruction.Release(hold)
	if not hold or hold.Released then
		return
	end
	hold.Released = true
	for orig in hold.Parts do
		local rec = originals[orig]
		if rec and rec.Held then
			rec.Held = rec.Held > 1 and rec.Held - 1 or nil
			rec.LastHit = os.clock()
		end
	end
end

-- how many map parts are in someone's pocket right now
function Destruction.HeldCount()
	local n = 0
	for _, rec in originals do
		if rec.Held then
			n += 1
		end
	end
	return n
end

-- A whole SpikeLayouts layout. Each spike is carved (as two capsules that
-- follow its taper) when it finishes growing, so buildings split in sync with
-- the ice. All spikes share one part budget so a glacier can't flood the server.
function Destruction.Spikes(list, growTime, totalBudget, profileName)
	local shared = { budget = totalBudget or 200, debris = 6 }
	profileName = profileName or "Ice"
	for _, sp in list do
		task.delay(sp.Delay + (growTime or 0.15) * 0.6, function()
			if shared.budget <= 0 then
				return
			end
			local minSize = math.max(PROFILES[profileName].MinSize, sp.Thick * 0.45)
			local a = sp.Base
			carve(capsuleShape(a, a + sp.Dir * (sp.Length * 0.58), sp.Thick * 0.55), profileName, sp.Dir, shared, minSize)
			carve(capsuleShape(a + sp.Dir * (sp.Length * 0.5), a + sp.Dir * (sp.Length * 0.95), sp.Thick * 0.32), profileName, sp.Dir, shared, minSize)
		end)
	end
end

---------------------------------------------------------------------------
-- CRAZY DIAMOND: what's broken can be put back, or built into something new
---------------------------------------------------------------------------

local function nearBroken(orig, rec, center, radius)
	if not stillInWorld(rec.Parent) then
		return false
	end
	local half = orig.Size / 2
	return (obbClosest(orig.CFrame, half, center) - center).Magnitude <= radius
end

local function pointIn(part, shrink)
	local h = part.Size / 2 * (shrink or 0.8)
	return part.CFrame * Vector3.new(rng:NextNumber(-h.X, h.X), rng:NextNumber(-h.Y, h.Y), rng:NextNumber(-h.Z, h.Z))
end

-- Rubble near a point, as building material: { Position, Size, Color,
-- Material } each. Loose debris is used up (it's taken out of the world: it
-- becomes the new thing); holes in buildings only lend their look (they
-- stay broken, and still restore / regenerate).
function Destruction.Rubble(center, radius, want)
	local out = {}
	for _, p in debrisFolder:GetChildren() do
		if #out >= want then
			break
		end
		if p:IsA("BasePart") and (p.CFrame.Position - center).Magnitude <= radius then
			table.insert(out, { Position = p.CFrame.Position, Size = p.Size, Color = p.Color, Material = p.Material })
			p:Destroy()
		end
	end
	local holes = {}
	for orig, rec in originals do
		if nearBroken(orig, rec, center, radius) then
			table.insert(holes, orig)
		end
	end
	local i = 0
	while #out < want and #holes > 0 and i < want * 2 do
		i += 1
		local orig = holes[(i - 1) % #holes + 1]
		table.insert(out, { Position = pointIn(orig), Size = Vector3.one * 2, Color = orig.Color, Material = orig.Material })
	end
	return out
end

-- The closest breakable thing to a point, and the spot on it nearest the point
function Destruction.NearestBreakable(center, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.MaxParts = 400
	local best, bestPoint, bestDist
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		if part:IsA("Part") and part:GetAttribute("Destroyable") == true and not part:GetAttribute("CrazyBuilt") then
			local q = obbClosest(part.CFrame, part.Size / 2, center)
			local d = (q - center).Magnitude
			if not bestDist or d < bestDist then
				best, bestPoint, bestDist = part, q, d
			end
		end
	end
	return best, bestPoint
end

-- Put everything broken near a point back the way it was, right now. Loose
-- debris nearby flies home (and is taken out of the world). Returns the
-- restored parts, and the flights home for the effects:
-- { From, To, Size, Color, Material } each (at most maxFlights).
function Destruction.RestoreNear(center, radius, maxFlights)
	local restored = {}
	for orig, rec in originals do
		if nearBroken(orig, rec, center, radius) then
			for frag in rec.Fragments do
				fragOrigin[frag] = nil
				frag:Destroy()
			end
			originals[orig] = nil
			if pcall(function()
				orig.Parent = rec.Parent
			end) then
				table.insert(restored, orig)
			else
				pcall(orig.Destroy, orig)
			end
		end
	end
	local flights = {}
	if #restored > 0 then
		for _, p in debrisFolder:GetChildren() do
			if p:IsA("BasePart") and (p.CFrame.Position - center).Magnitude <= radius then
				if #flights < (maxFlights or 80) then
					local home, homeDist
					for _, o in restored do
						local d = (o.CFrame.Position - p.CFrame.Position).Magnitude
						if not homeDist or d < homeDist then
							home, homeDist = o, d
						end
					end
					table.insert(flights, { From = p.CFrame.Position, To = pointIn(home), Size = p.Size, Color = p.Color, Material = p.Material })
				end
				p:Destroy()
			end
		end
	end
	return restored, flights
end

-- Put a character's parts in the "Characters" collision group (debris passes
-- through them). Round 60 (Config.Physics.CharacterCollisions): bodies
-- collide with each other - you can stand on someone. A body that's out of
-- its owner's hands - ragdolled, grabbed, a marble (Compressed) - goes
-- "Loose" instead: it still lands on the street but never shoves, lifts or
-- flings anyone. Let go (or back up), it stays loose until it's clear of
-- everyone else's body, so it isn't spat out of whoever it was inside.
Destruction.looseState = setmetatable({}, { __mode = "k" }) -- [model] = true while loose
function Destruction.RegisterCharacter(model)
	local physics = Config.Physics or {}
	local function wantLoose()
		return model:GetAttribute("Ragdolled") == true or model:GetAttribute("Grabbed") == true
			or model:GetAttribute("Compressed") == true
	end
	local function set(d)
		-- (ragdoll colliders keep their own group: they must not hit the body)
		if d:IsA("BasePart") and d.Name ~= "RagdollCollider" then
			d.CollisionGroup = Destruction.looseState[model] and "Loose" or "Characters"
		end
	end
	local function apply(loose)
		Destruction.looseState[model] = loose or nil
		for _, d in model:GetDescendants() do
			set(d)
		end
	end
	-- is anyone else's body where this one is?
	local function overlapping()
		local ok, found = pcall(function()
			local root = model:FindFirstChild("HumanoidRootPart")
			if not root then
				return false
			end
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model }
			params.CollisionGroup = "Characters"
			for _, p in workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(4, 6, 3), params) do
				local other = p.CanCollide and p:FindFirstAncestorOfClass("Model")
				if other and other ~= model and other:FindFirstChildOfClass("Humanoid") then
					return true
				end
			end
			return false
		end)
		return ok and found
	end
	local token = 0
	local function refresh()
		token += 1
		local mine = token
		if wantLoose() then
			if not Destruction.looseState[model] then
				apply(true)
			end
			return
		end
		if not Destruction.looseState[model] then
			return
		end
		task.spawn(function()
			local t0 = os.clock()
			while token == mine and model.Parent and not wantLoose() and overlapping()
				and os.clock() - t0 < (physics.LooseMax or 3) do
				task.wait(physics.LooseCheck or 0.15)
			end
			if token == mine and model.Parent and not wantLoose() then
				apply(false)
			end
		end)
	end
	for _, d in model:GetDescendants() do
		set(d)
	end
	model.DescendantAdded:Connect(set)
	for _, attr in { "Ragdolled", "Grabbed", "Compressed" } do
		model:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
end

---------------------------------------------------------------------------
-- Regeneration
---------------------------------------------------------------------------

local function characterParams()
	local list = {}
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(list, dummies)
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.MaxParts = 1
	return params
end

-- Don't rebuild a part on top of someone
local function blocked(part, params)
	local shrink = Vector3.new(math.max(part.Size.X - 0.6, 0.1), math.max(part.Size.Y - 0.6, 0.1), math.max(part.Size.Z - 0.6, 0.1))
	return #workspace:GetPartBoundsInBox(part.CFrame, shrink, params) > 0
end

-- Test menu: rebuild every broken part right now, and toggle destruction
function Destruction.RegenerateAll()
	for orig, rec in originals do
		for frag in rec.Fragments do
			fragOrigin[frag] = nil
			frag:Destroy()
		end
		originals[orig] = nil
		if not (stillInWorld(rec.Parent) and pcall(function()
			orig.Parent = rec.Parent
		end)) then
			pcall(orig.Destroy, orig)
		end
	end
	debrisFolder:ClearAllChildren()
end

-- (round 94) THE CITY BACK WITH A WIPE'S REWIND (the server's
-- Kit.wipeRebuild: the Serious Punch - (round 99) the LIGHTSPEED crash is a crater now). Every broken
-- part of the map within radius studs (flat) of center - from opts.Below
-- studs under it to opts.Above over it - put back now, its fragments gone.
-- opts:
--   Folders = { [folder] = true }: only parts from inside these
--   MinTop = y: only parts whose top is over it
--   Bodies = { model }: a part that would come back on one of these is left
--     to the usual regrow (nothing's rebuilt on top of anyone)
--   Batch = n: a frame's break every n parts put back (it yields)
-- A part in someone's marble (Held) stays there; one whose structure has
-- gone is left for the regrow loop to throw away. Returns how many came back.
function Destruction.RestoreArea(center, radius, opts)
	opts = opts or {}
	local above, below = tonumber(opts.Above) or math.huge, tonumber(opts.Below) or math.huge
	local minTop = tonumber(opts.MinTop)
	local params
	if type(opts.Bodies) == "table" and #opts.Bodies > 0 then
		params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = opts.Bodies
		params.MaxParts = 1
	end
	local function within(parent)
		if type(opts.Folders) ~= "table" then
			return true
		end
		for f in opts.Folders do
			if parent == f or parent:IsDescendantOf(f) then
				return true
			end
		end
		return false
	end
	-- (picked first, put back after: the list can't change under the pick)
	local list = {}
	for orig, rec in originals do
		if not rec.Held and stillInWorld(rec.Parent) and within(rec.Parent) then
			local cf, size = orig.CFrame, orig.Size
			local q = obbClosest(cf, size / 2, center)
			local flat = Vector3.new(q.X - center.X, 0, q.Z - center.Z).Magnitude
			local top = cf.Position.Y + (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
			if flat <= radius and q.Y - center.Y <= above and center.Y - q.Y <= below
				and not (minTop and top <= minTop) and not (params and blocked(orig, params)) then
				table.insert(list, orig)
			end
		end
	end
	local n = 0
	local batch = tonumber(opts.Batch)
	for i, orig in list do
		local rec = originals[orig]
		if rec and not rec.Held and stillInWorld(rec.Parent) then
			for frag in rec.Fragments do
				fragOrigin[frag] = nil
				frag:Destroy()
			end
			originals[orig] = nil
			if pcall(function()
				orig.Parent = rec.Parent
			end) then
				n += 1
			else
				pcall(orig.Destroy, orig)
			end
		end
		if batch and batch > 0 and i % batch == 0 and i < #list then
			task.wait()
		end
	end
	return n
end

---------------------------------------------------------------------------
-- (round 96) DISMANTLE (Config.Dismantle; the server's Kit.DM decides who,
-- where and what): a flat cut through whole structures, and what's over it
-- coming off
---------------------------------------------------------------------------
-- Destruction.Slice(units, point, normal, opts) -> groups
--   units: models (a building, a tree, a bench...) the sheet through point,
--   square to normal, goes through - each cut along it, right through. A
--   part across it is split: along its own axis nearest the normal, AT the
--   cut (exact for a part square to it; on a slanted cut it's first halved
--   across its other axes - not under opts.MinSize - till the cut's at most
--   opts.Step studs off: a fine staircase), opts.PerPart pieces at most,
--   every piece a fragment of it (it regrows like any broken part). The
--   side that comes off: over a slanted or flat cut, the top; an upright
--   one (|normal.Y| under opts.Upright), the smaller side. All of that side
--   - whole parts too (a copy moves, its lights and decals with it; the part
--   itself waits in storage) - is the group's MOVERS, kept from regrowing
--   (Held) till it's come down (Crumble).
--   opts: Step, MinSize, PerPart, Budget (new parts in all; past it a part
--   goes whole to the side its middle's on), Upright, Flat (a cut flatter
--   than this slope: its top slides along Stroke - the drawn line - not
--   down it), Stroke, ClearPad.
--   A group: { Unit, Movers, Root (the biggest), Mode ("Slide" down the
--   cut, or "Topple" over away from it), Dir, Normal (toward the side that
--   comes off), Clear (how far it slides to be clear of what's left under
--   it), Ground (the unit's foot), Centre, Lo, Hi (the movers' box), Holds
--   ([original] = true), Pieces (parts made), Stroked (it slides along the
--   drawn line) }.
-- Destruction.Collapse(group, opts): it comes off - its movers welded to the
--   Root, unanchored, the server's (nothing collides with them or finds
--   them), steered each frame (rigid AlignPosition / AlignOrientation):
--   Slide: held opts.Delay (the cut shows), then down the cut (Dir) from
--     Slide.Start studs/s, Accel (down a slope: x its steepness, never under
--     0.35 of it) up to Max, till it's slid Clear (or MaxTime, or it's sunk Sink under the
--     street), then FALLS: on at its speed, gravity, tipping forward (Fall:
--     Spin rad/s up to Tilt) till its lowest corner's down on what's under
--     its middle (a ray down; else Ground) - or Fall.MaxTime
--   Topple: Topple.Gap out along Dir, then over about its far bottom edge
--     (Accel rad/s^2) to Angle degrees
--   then it crumbles there (Crumble with opts.Impact) and opts.OnImpact(
--   point, group); opts.OnSlide(group) as it starts. Runs on its own.
-- Destruction.Crumble(group, at, opts): the movers gone - opts.Debris
--   chunks of them flung from `at`, a Crater of opts.Crater studs there -
--   their originals free to regrow from now. (Put back meanwhile - the test
--   menu's rebuild, Crazy Diamond - it just lets go.)
-- Destruction.MovingCount(): pieces still coming off, all cuts.
do
	local groups = {} -- the ones still coming off, oldest first
	-- still in the world? (a piece put back meanwhile - the test menu's
	-- rebuild, Crazy Diamond - is gone; asked so it can't throw)
	local function present(inst)
		local ok, parent = pcall(function()
			return inst.Parent
		end)
		return ok and parent ~= nil
	end
	-- how far a box reaches either side of its middle along n
	local function reach(cf, half, n)
		return math.abs(cf.RightVector:Dot(n)) * half.X + math.abs(cf.UpVector:Dot(n)) * half.Y + math.abs(cf.LookVector:Dot(n)) * half.Z
	end
	-- the boxes one box makes, cut by the sheet through P square to M:
	-- { cf, size, side (1: M's side, -1: the other) } each
	local function cutBox(cf, size, P, M, opts)
		local out = {}
		local step, minSize = tonumber(opts.Step) or 1.2, tonumber(opts.MinSize) or 3
		local maxHalvings = math.max(math.floor((tonumber(opts.PerPart) or 64) / 2) - 1, 0)
		local halvings = 0
		local queue, qi = { { cf, size } }, 1
		while qi <= #queue do
			local bcf, bsize = queue[qi][1], queue[qi][2]
			qi += 1
			local d = (bcf.Position - P):Dot(M)
			-- (its local X, Y, Z: LookVector is -Z)
			local a = { bcf.RightVector:Dot(M), bcf.UpVector:Dot(M), -bcf.LookVector:Dot(M) }
			local h = { bsize.X / 2, bsize.Y / 2, bsize.Z / 2 }
			local r = math.abs(a[1]) * h[1] + math.abs(a[2]) * h[2] + math.abs(a[3]) * h[3]
			if d >= r - EPS then
				table.insert(out, { bcf, bsize, 1 })
			elseif d <= -r + EPS then
				table.insert(out, { bcf, bsize, -1 })
			else
				-- the axis nearest the normal: cut across it, at the cut
				local k = 1
				for i = 2, 3 do
					if math.abs(a[i]) > math.abs(a[k]) then
						k = i
					end
				end
				-- how far off the cut that'd be at the box's edges; halve it
				-- across the axis that's worst while it's over Step
				local off, j, worst = 0, nil, 0
				for i = 1, 3 do
					if i ~= k then
						local e = math.abs(a[i]) * h[i]
						off += e
						if e > worst and h[i] * 2 > minSize then
							j, worst = i, e
						end
					end
				end
				if j and off > step and halvings < maxHalvings then
					halvings += 1
					local ax, len = AXES[j], h[j] * 2
					local half = bsize - ax * (len / 2)
					table.insert(queue, { bcf * CFrame.new(ax * (len / 4)), half })
					table.insert(queue, { bcf * CFrame.new(ax * (-len / 4)), half })
				else
					local t = math.clamp(-d / a[k], -h[k], h[k])
					local lo, hi = t + h[k], h[k] - t
					local ax = AXES[k]
					local up = a[k] > 0 and 1 or -1 -- (the side of the piece toward +axis)
					if lo < 0.2 then
						table.insert(out, { bcf, bsize, up })
					elseif hi < 0.2 then
						table.insert(out, { bcf, bsize, -up })
					else
						local rest = bsize - ax * (2 * h[k])
						table.insert(out, { bcf * CFrame.new(ax * ((t - h[k]) / 2)), rest + ax * lo, -up })
						table.insert(out, { bcf * CFrame.new(ax * ((t + h[k]) / 2)), rest + ax * hi, up })
					end
				end
			end
		end
		return out
	end

	local function sliceUnit(unit, P, N, opts, budget)
		local parts = {}
		for _, d in unit:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Destroyable") == true and not moving[d] and d.Parent then
				table.insert(parts, d)
			end
		end
		if #parts == 0 then
			return nil
		end
		-- which side comes off: the top - or, an upright cut, the smaller side
		local upright = math.abs(N.Y) < (tonumber(opts.Upright) or 0.3)
		local M = N.Y >= 0 and N or -N
		local foot = math.huge
		local sides = { 0, 0 }
		for _, p in parts do
			local cf, size = p.CFrame, p.Size
			local mn = aabbOf(cf, size / 2)
			foot = math.min(foot, mn.Y)
			if upright then
				local v = size.X * size.Y * size.Z
				local i = (cf.Position - P):Dot(N) >= 0 and 1 or 2
				sides[i] += v
			end
		end
		if upright then
			M = sides[1] <= sides[2] and N or -N
		end
		local movers, base, holds = {}, {}, {}
		local made = 0
		-- a part that goes whole: a fragment moves itself; an original sends
		-- a copy (and waits in storage)
		local function takeWhole(part)
			local orig = fragOrigin[part]
			if orig then
				holds[orig] = true
				table.insert(movers, part)
				return
			end
			local parent = part.Parent
			local okCopy, copy = pcall(part.Clone, part)
			local props = (not okCopy or not copy) and snapshot(part) or nil
			orig = retire(part)
			if props then
				copy = makeFragment(props, orig.CFrame, orig.Size, parent, orig)
			else
				copy:SetAttribute("Fragment", true)
				copy.Parent = parent
				fragOrigin[copy] = orig
				local rec = originals[orig]
				if rec then
					rec.Fragments[copy] = true
				end
			end
			holds[orig] = true
			made += 1
			budget.left -= 1
			table.insert(movers, copy)
		end
		for _, part in parts do
			local cf, size = part.CFrame, part.Size
			local d = (cf.Position - P):Dot(M)
			local r = reach(cf, size / 2, M)
			if d >= r - EPS then
				takeWhole(part)
			elseif d <= -r + EPS then
				table.insert(base, part)
			elseif not (part:IsA("Part") and part.Shape == Enum.PartType.Block) or budget.left <= 0 then
				-- (a wedge, a ball - or the cut's spent its parts: whole, by its middle)
				if d >= 0 then
					takeWhole(part)
				else
					table.insert(base, part)
				end
			else
				local boxes = cutBox(cf, size, P, M, opts)
				local props = snapshot(part)
				local parent = part.Parent
				local orig = retire(part)
				for _, b in boxes do
					local f = makeFragment(props, b[1], b[2], parent, orig)
					if b[3] > 0 then
						holds[orig] = true
						table.insert(movers, f)
					else
						table.insert(base, f)
					end
				end
				made += #boxes
				budget.left -= #boxes
			end
		end
		if #movers == 0 then
			return nil
		end
		-- the group: its biggest piece leads, its box, where it goes
		local root, best = nil, -1
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, m in movers do
			local v = m.Size.X * m.Size.Y * m.Size.Z
			if v > best then
				root, best = m, v
			end
			local mn, mx = aabbOf(m.CFrame, m.Size / 2)
			lo, hi = vmin(lo, mn), vmax(hi, mx)
		end
		local mode, dir, stroked
		if upright then
			mode = "Topple"
			dir = flatUnit(M, Vector3.new(1, 0, 0))
		else
			mode = "Slide"
			local down = Vector3.new(0, -1, 0)
			local slope = down - M * down:Dot(M)
			local stroke = typeof(opts.Stroke) == "Vector3" and opts.Stroke - M * opts.Stroke:Dot(M) or Vector3.zero
			if slope.Magnitude < (tonumber(opts.Flat) or 0.26) and stroke.Magnitude > 0.05 then
				dir = stroke.Unit
				stroked = true
			elseif slope.Magnitude > 1e-3 then
				dir = slope.Unit
			else
				dir = M:Cross(Vector3.new(1, 0, 0)).Unit
			end
		end
		-- how far it slides to be clear of what's left under it
		local far, near = -math.huge, math.huge
		for _, p in base do
			if present(p) then
				far = math.max(far, p.CFrame.Position:Dot(dir) + reach(p.CFrame, p.Size / 2, dir))
			end
		end
		for _, m in movers do
			near = math.min(near, m.CFrame.Position:Dot(dir) - reach(m.CFrame, m.Size / 2, dir))
		end
		local clear = (far > -math.huge and math.max(far - near, 0) or 0) + (tonumber(opts.ClearPad) or 4)
		local group = {
			Unit = unit, Movers = movers, Root = root, Mode = mode, Dir = dir, Normal = M, Clear = clear,
			Ground = foot < math.huge and foot or lo.Y, Centre = (lo + hi) / 2, Lo = lo, Hi = hi, Holds = holds,
			Pieces = made, Born = os.clock(), Stroked = stroked,
		}
		for _, m in movers do
			moving[m] = group
		end
		for orig in holds do
			local rec = originals[orig]
			if rec then
				rec.Held = (rec.Held or 0) + 1
			end
		end
		table.insert(groups, group)
		return group
	end

	function Destruction.Slice(units, point, normal, opts)
		opts = type(opts) == "table" and opts or {}
		if not Settings.Enabled or type(units) ~= "table" or typeof(point) ~= "Vector3" or typeof(normal) ~= "Vector3" or normal.Magnitude < 0.5 then
			return {}
		end
		local N = normal.Unit
		local budget = { left = tonumber(opts.Budget) or 3000 }
		local out = {}
		for _, unit in units do
			if budget.left <= 0 then
				break
			end
			if typeof(unit) == "Instance" and present(unit) then
				local ok, g = pcall(sliceUnit, unit, point, N, opts, budget)
				if not ok then
					warn("[Destruction] slice: " .. tostring(g))
				elseif g then
					table.insert(out, g)
				end
			end
		end
		return out
	end

	function Destruction.MovingCount()
		local n = 0
		for _, g in groups do
			n += #g.Movers
		end
		return n
	end

	function Destruction.Crumble(group, at, opts)
		if type(group) ~= "table" or group.Done then
			return 0
		end
		group.Done = true
		local i = table.find(groups, group)
		if i then
			table.remove(groups, i)
		end
		opts = type(opts) == "table" and opts or {}
		local now = os.clock()
		local live = {}
		for _, m in group.Movers do
			if moving[m] == group then
				moving[m] = nil
			end
			if present(m) then
				table.insert(live, m)
			end
		end
		-- chunks of it thrown out from where it came down (spread through it)
		local want = typeof(at) == "Vector3" and math.min(math.floor(tonumber(opts.Debris) or 40), #live) or 0
		if want > 0 then
			local ctx = { profile = PROFILES.Collapse, shape = { center = at }, dir = typeof(opts.Dir) == "Vector3" and opts.Dir or Vector3.zero }
			local stride = #live / want
			for n = 1, want do
				local m = live[math.floor((n - 1) * stride) + 1]
				if m then
					spawnDebris(snapshot(m), m.CFrame, m.Size, ctx)
				end
			end
		end
		for _, m in group.Movers do
			local orig = fragOrigin[m]
			if orig then
				fragOrigin[m] = nil
				local rec = originals[orig]
				if rec then
					rec.Fragments[m] = nil
				end
			end
			if present(m) then
				m:Destroy()
			end
		end
		for orig in group.Holds do
			local rec = originals[orig]
			if rec then
				rec.LastHit = now
				if rec.Held then
					rec.Held = rec.Held > 1 and rec.Held - 1 or nil
				end
			end
		end
		local crater = tonumber(opts.Crater) or 0
		if typeof(at) == "Vector3" and crater > 0 then
			carve(sphereShape(at, crater), "Crater", nil)
		end
		return #live
	end

	-- what's under a point (the map; the pieces coming off aren't found)
	local function under(p)
		local ok, hit = pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { map }
			return workspace:Raycast(p, Vector3.new(0, -1500, 0), params)
		end)
		return ok and hit and hit.Position.Y or nil
	end

	-- one body round the Root, steered (still anchored till it moves)
	local function rig(group)
		local root = group.Root
		for _, m in group.Movers do
			if present(m) then
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				if m ~= root then
					local w = Instance.new("WeldConstraint")
					w.Name = "DismantleWeld"
					w.Part0 = root
					w.Part1 = m
					w.Parent = m
				end
			end
		end
		local att = Instance.new("Attachment")
		att.Name = "DismantleAt"
		att.Parent = root
		local ap = Instance.new("AlignPosition")
		ap.Name = "DismantleMove"
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Attachment0 = att
		ap.RigidityEnabled = true
		ap.Position = root.CFrame.Position
		ap.Parent = root
		local ao = Instance.new("AlignOrientation")
		ao.Name = "DismantleTurn"
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.RigidityEnabled = true
		ao.CFrame = root.CFrame.Rotation
		ao.Parent = root
		group.Align = { P = ap, O = ao }
	end

	function Destruction.Collapse(group, opts)
		if type(group) ~= "table" or group.Done or not group.Root then
			return
		end
		opts = type(opts) == "table" and opts or {}
		local SL = type(opts.Slide) == "table" and opts.Slide or {}
		local FA = type(opts.Fall) == "table" and opts.Fall or {}
		local TP = type(opts.Topple) == "table" and opts.Topple or {}
		task.spawn(function()
			local ok, err = pcall(function()
				local root = group.Root
				rig(group)
				local c0 = group.Centre
				local rootOff = CFrame.new(c0):ToObjectSpace(root.CFrame)
				local lo, hi = group.Lo - c0, group.Hi - c0
				local corners = {}
				for _, k in CORNERS do
					table.insert(corners, Vector3.new(k.X > 0 and hi.X or lo.X, k.Y > 0 and hi.Y or lo.Y, k.Z > 0 and hi.Z or lo.Z))
				end
				local function lowest(cf)
					local y = math.huge
					for _, k in corners do
						y = math.min(y, (cf * k).Y)
					end
					return y
				end
				local function alive()
					return not group.Done and present(root)
				end
				-- (where its middle is now: group.Pivot; the Root steered to match)
				local function place(cf)
					group.Pivot = cf
					local target = cf * rootOff
					group.Align.P.Position = target.Position
					group.Align.O.CFrame = target.Rotation
				end
				group.Pivot = CFrame.new(c0)
				group.Phase = "Hold"
				local t0 = os.clock()
				while alive() and os.clock() - t0 < (tonumber(opts.Delay) or tonumber(SL.Delay) or 0.35) do
					task.wait()
				end
				if not alive() then
					Destruction.Crumble(group) -- (put back meanwhile: it just lets go)
					return
				end
				for _, m in group.Movers do
					if present(m) then
						m.Anchored = false
					end
				end
				pcall(function()
					root:SetNetworkOwner(nil)
				end)
				if opts.OnSlide then
					task.spawn(opts.OnSlide, group)
				end
				local dir = group.Dir
				local at
				if group.Mode == "Topple" then
					group.Phase = "Topple"
					-- out a little from the cut, then over its far bottom edge
					local gap = tonumber(TP.Gap) or 1.5
					local farOut = -math.huge
					for _, k in corners do
						farOut = math.max(farOut, k:Dot(dir))
					end
					local hinge = c0 + dir * (farOut + gap)
					hinge = Vector3.new(hinge.X, group.Lo.Y, hinge.Z)
					local axis = UP:Cross(dir)
					axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.new(0, 0, 1)
					local base = CFrame.new(hinge)
					local off = base:ToObjectSpace(CFrame.new(c0 + dir * gap))
					local maxA = math.rad(tonumber(TP.Angle) or 82)
					local t1 = os.clock()
					while alive() do
						local t = os.clock() - t1
						local a = math.min(0.5 * (tonumber(TP.Accel) or 2.4) * t * t, maxA)
						local cf = base * CFrame.fromAxisAngle(axis, a) * off
						place(cf)
						if a >= maxA then
							at = Vector3.new(cf.Position.X, hinge.Y, cf.Position.Z)
							break
						end
						task.wait()
					end
				else
					group.Phase = "Slide"
					-- (down a slope: as steep as it is; along the drawn line: full)
					local slope = group.Stroked and 1 or math.sqrt(math.max(1 - group.Normal.Y * group.Normal.Y, 0))
					local accel = (tonumber(SL.Accel) or 34) * math.clamp(slope, 0.35, 1)
					local v, dist = tonumber(SL.Start) or 3, 0
					local sink = math.min(lowest(CFrame.new(c0)), group.Ground) - (tonumber(SL.Sink) or 3)
					local t1, last = os.clock(), os.clock()
					while alive() do
						task.wait()
						local now = os.clock()
						local dt = now - last
						last = now
						v = math.min(v + accel * dt, tonumber(SL.Max) or 55)
						dist += v * dt
						local cf = CFrame.new(c0 + dir * dist)
						place(cf)
						if lowest(cf) < sink then
							at = Vector3.new(cf.Position.X, group.Ground, cf.Position.Z)
							break
						end
						if dist >= group.Clear or now - t1 >= (tonumber(SL.MaxTime) or 3) then
							break
						end
					end
					if not at and alive() then
						-- off the edge: falling, tipping forward
						group.Phase = "Fall"
						local start = c0 + dir * dist
						local vel = dir * v
						local flat = Vector3.new(dir.X, 0, dir.Z)
						local axis = flat.Magnitude > 0.05 and UP:Cross(flat.Unit).Unit or nil
						local ground = under(start) or group.Ground
						local g = workspace.Gravity
						local t2 = os.clock()
						while alive() do
							task.wait()
							local t = os.clock() - t2
							local pos = start + vel * t - UP * (0.5 * g * t * t)
							local cf = CFrame.new(pos)
							if axis then
								cf *= CFrame.fromAxisAngle(axis, math.min((tonumber(FA.Spin) or 0.7) * t, tonumber(FA.Tilt) or 1.2))
							end
							place(cf)
							if lowest(cf) <= ground + 0.5 or t >= (tonumber(FA.MaxTime) or 6) then
								at = Vector3.new(pos.X, ground, pos.Z)
								break
							end
						end
					end
				end
				if not alive() then
					Destruction.Crumble(group)
					return
				end
				group.Phase = "Down"
				local impact = type(opts.Impact) == "table" and table.clone(opts.Impact) or {}
				impact.Dir = impact.Dir or dir
				Destruction.Crumble(group, at, impact)
				if opts.OnImpact then
					task.spawn(opts.OnImpact, at, group)
				end
			end)
			if not ok then
				warn("[Destruction] collapse: " .. tostring(err))
				Destruction.Crumble(group)
			end
		end)
	end
end

function Destruction.SetEnabled(on)
	Settings.Enabled = on and true or false
	workspace:SetAttribute("DestructionEnabled", Settings.Enabled)
end
workspace:SetAttribute("DestructionEnabled", Settings.Enabled)

task.spawn(function()
	while true do
		task.wait(1.5)
		local now = os.clock()
		local params
		-- (server settings: Destruction Respawns off - the city stays broken)
		local regen = workspace:GetAttribute("MapRegen") ~= false
		for orig, rec in originals do
			if regen and not rec.Held and now - rec.LastHit >= Settings.RegenTime then
				params = params or characterParams()
				if blocked(orig, params) then
					rec.LastHit = now - Settings.RegenTime + 2
				else
					for frag in rec.Fragments do
						fragOrigin[frag] = nil
						frag:Destroy()
					end
					originals[orig] = nil
					if not (stillInWorld(rec.Parent) and pcall(function()
						orig.Parent = rec.Parent
					end)) then
						pcall(orig.Destroy, orig)
					end
				end
			end
		end
	end
end)

return Destruction
