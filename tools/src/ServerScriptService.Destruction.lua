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
	-- (round 60) a body out of its owner's hands - down, held in a grab, a
	-- marble - lands on the street but never shoves, lifts or flings anyone
	PhysicsService:RegisterCollisionGroup("Loose")
	for _, other in { "Characters", "Debris", "Ragdoll", "Loose", "PhaseDive" } do
		PhysicsService:CollisionGroupSetCollidable("Loose", other, false)
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
local function carve(shape, profileName, dir, shared, minSize, touched)
	if not Settings.Enabled then
		return
	end
	local prof = PROFILES[profileName] or PROFILES.Impact
	local pad = Vector3.one * (prof.Rim + 0.1)
	local mn, mx = shape.min - pad, shape.max + pad
	local parts = workspace:GetPartBoundsInBox(CFrame.new((mn + mx) / 2), mx - mn, includeParams)
	local ctx = {
		shape = shape,
		profile = prof,
		dir = typeof(dir) == "Vector3" and dir or Vector3.zero,
		budget = shared and shared.budget or prof.Budget or 200,
		debris = shared and shared.debris or prof.Debris or 20,
		minSize = minSize or prof.MinSize,
		touched = touched, -- (optional: the originals this carve took, for a hold)
	}
	for _, part in parts do
		if part.Parent and part:IsA("Part") and part:GetAttribute("Destroyable") == true then
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

function Destruction.Sphere(center, radius, profileName, dir)
	carve(sphereShape(center, radius), profileName, dir)
end

function Destruction.Capsule(a, b, radius, profileName, dir)
	carve(capsuleShape(a, b, radius), profileName, dir)
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
