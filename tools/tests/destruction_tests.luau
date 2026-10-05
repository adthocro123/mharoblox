-- Runs the real Destruction module on a small map of reflection-checked parts
-- and checks the Decay / DecayHuge / Rivet profiles carve, tint and shed debris.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local r = require("@lune/roblox")
local Instance, Vector3, CFrame = r.Instance, r.Vector3, r.CFrame

local SRC = process.args[1] or "../src"
local problems = {}
local passes = 0
local function check(cond, label)
	if cond then
		passes += 1
		print("  PASS  " .. label)
	else
		table.insert(problems, label)
		print("  FAIL  " .. label)
	end
end

local noop = function() end
for _, pair in {
	{ "PhysicsService", "RegisterCollisionGroup" }, { "PhysicsService", "CollisionGroupSetCollidable" },
	{ "Debris", "AddItem" },
} do
	r.implementMethod(pair[1], pair[2], noop)
end
r.implementMethod("Players", "GetPlayers", function()
	return {}
end)
r.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name)
end)
-- brute-force spatial query over the Include list (axis-aligned, like the carver's query box)
r.implementMethod("Workspace", "GetPartBoundsInBox", function(_, cf, size, params)
	local out = {}
	local mn, mx = cf.Position - size / 2, cf.Position + size / 2
	for _, root in params.FilterDescendantsInstances do
		for _, p in root:GetDescendants() do
			if p:IsA("BasePart") then
				local c, h = p.CFrame.Position, p.Size / 2
				if c.X + h.X >= mn.X and c.X - h.X <= mx.X and c.Y + h.Y >= mn.Y and c.Y - h.Y <= mx.Y and c.Z + h.Z >= mn.Z and c.Z - h.Z <= mx.Z then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end)

r.implementMethod("Workspace", "GetPartBoundsInRadius", function(_, pos, radius, params)
	local out = {}
	for _, root in params.FilterDescendantsInstances do
		for _, p in root:GetDescendants() do
			if p:IsA("BasePart") then
				local lp = p.CFrame:PointToObjectSpace(pos)
				local h = p.Size / 2
				local q = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
				if (lp - q).Magnitude <= radius then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end)

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

-- a "building": a 5x5 grid of 8x8x8 blocks, 3 floors high, plus a road slab
local count = 0
for x = -2, 2 do
	for z = -2, 2 do
		for y = 0, 2 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(8, 8, 8)
			p.CFrame = CFrame.new(x * 8, 4 + y * 8, z * 8)
			p.Anchored = true
			p.Color = r.Color3.fromRGB(200, 60, 60)
			p:SetAttribute("Destroyable", true)
			p.Parent = map
			count += 1
		end
	end
end
local road = Instance.new("Part")
road.Size = Vector3.new(120, 1, 12)
road.CFrame = CFrame.new(0, -0.5, 60)
road.Anchored = true
road:SetAttribute("Destroyable", true)
road.Parent = map

local RandomShim = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * math.random()
			end,
			NextInteger = function(_, a, b)
				return math.random(a, b)
			end,
			NextUnitVector = function()
				return Vector3.new(math.random() - 0.5, math.random() - 0.5 + 0.01, math.random() - 0.5).Unit
			end,
		}
	end,
}
local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = game:GetService("ReplicatedStorage")
local cfgInst = Instance.new("ModuleScript")
cfgInst.Name = "QuirkConfig"
cfgInst.Parent = shared
local modules = {}
local function env(scriptInst)
	return setmetatable({
		game = game,
		workspace = workspace,
		script = scriptInst,
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = r.Vector2,
		CFrame = CFrame,
		Color3 = r.Color3,
		Enum = r.Enum,
		Random = RandomShim,
		OverlapParams = { new = function() return {} end },
		task = task,
		require = function(mod)
			return modules[mod.Name]
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			table.insert(problems, "warn: " .. table.concat(parts, " "))
			print("  !! warn: " .. table.concat(parts, " "))
		end,
	}, { __index = _G })
end
modules.QuirkConfig = luau.load(fs.readFile(SRC .. "/ReplicatedStorage.Shared.QuirkConfig.lua"), { debugName = "QuirkConfig", environment = env(cfgInst) })()
local dInst = Instance.new("ModuleScript")
dInst.Name = "Destruction"
local Destruction = luau.load(fs.readFile(SRC .. "/ServerScriptService.Destruction.lua"), { debugName = "Destruction", environment = env(dInst) })()

local UP = Vector3.new(0, 1, 0)
local function mapStats()
	local blocks, decayed, slate = 0, 0, 0
	for _, p in map:GetDescendants() do
		if p:IsA("BasePart") then
			blocks += 1
			if p:GetAttribute("Decayed") then
				decayed += 1
			end
			if p.Material == r.Enum.Material.Slate then
				slate += 1
			end
		end
	end
	return blocks, decayed, slate
end
local function debrisStats()
	local n, dusty = 0, 0
	local folder = workspace:FindFirstChild("MapDebris")
	for _, p in folder and folder:GetChildren() or {} do
		n += 1
		if p.Material == r.Enum.Material.Slate then
			dusty += 1
		end
	end
	return n, dusty
end
local stored = function()
	local s = game:GetService("ServerStorage"):FindFirstChild("BrokenMapParts")
	return s and #s:GetChildren() or 0
end

print("== round 94: RestoreArea - the city back with a wipe's rewind")
local B85 = Instance.new("Folder")
B85.Name = "Buildings"
B85.Parent = map
local R85 = Instance.new("Folder")
R85.Name = "Roads"
R85.Parent = map
local O = Vector3.new(500, 0, 0)
local function block(parent, pos, size)
	local p = Instance.new("Part")
	p.Size = size or Vector3.new(8, 8, 8)
	p.CFrame = CFrame.new(pos)
	p.Position = pos -- (Lune's parts don't derive it from the CFrame)
	p.Anchored = true
	p.Color = r.Color3.fromRGB(120, 130, 160)
	p:SetAttribute("Destroyable", true)
	p.Parent = parent
	return p
end
local tower = Instance.new("Model")
tower.Name = "Tower85"
tower.Parent = B85
local towerParts = {}
for x = 0, 2 do
	for y = 0, 3 do
		for z = -1, 1 do
			table.insert(towerParts, block(tower, O + Vector3.new(30 + x * 8, 4 + y * 8, z * 8)))
		end
	end
end
local lit = towerParts[1] -- (30, 4, -8): its light comes back with it
local lamp = Instance.new("SurfaceLight")
lamp.Parent = lit
local slab = block(tower, O + Vector3.new(-40, 0.5, 0), Vector3.new(24, 1, 24)) -- (a floor slab: its top under the foundations)
local road = block(R85, O + Vector3.new(0, -0.5, 0), Vector3.new(200, 1, 20))
local farHouse = Instance.new("Model")
farHouse.Name = "Far85"
farHouse.Parent = B85
local far = block(farHouse, O + Vector3.new(0, 4, 400))

-- THE BLAST: a furrow through the tower (the street left), the crater in
-- the road, the slab, the far house
Destruction.Capsule(O + Vector3.new(22, 6, 0), O + Vector3.new(70, 6, 0), 7, "SeriousPunch", Vector3.new(1, 0, 0), { Above = 0.5, Budget = 210 })
Destruction.Sphere(O + Vector3.new(0, 1, 0), 10, "LightWipe", UP, { Budget = 300 })
Destruction.Sphere(O + Vector3.new(-40, 0.5, 0), 4, "Crater", UP)
Destruction.Sphere(O + Vector3.new(0, 4, 400), 3, "Impact", UP)
-- someone's marble: a piece of the tower's top in a pocket
local hold = Destruction.Compress(O + Vector3.new(46, 28, 8), 3)
local function broken(p)
	return p.Parent ~= nil and p.Parent.Name == "BrokenMapParts"
end
local brokenTower = {}
for _, p in towerParts do
	if broken(p) then
		table.insert(brokenTower, p)
	end
end
check(#brokenTower >= 6 and broken(road) and broken(slab) and broken(far), "the blast carves the tower (" .. #brokenTower .. " blocks), the road, the slab, the far house")
local held = towerParts[#towerParts] -- (46, 28, 8)
check(broken(held) and hold.Count >= 1, "...and a piece of the tower's in a marble")
-- a dummy standing where one of the tower's broken blocks was
local dummy = Instance.new("Model")
dummy.Name = "Dummy85"
dummy.Parent = workspace
local droot = Instance.new("Part")
droot.Name = "HumanoidRootPart"
droot.Size = Vector3.new(2, 2, 1)
droot.CFrame = CFrame.new(O + Vector3.new(30, 4, 0))
droot.Position = O + Vector3.new(30, 4, 0)
droot.Parent = dummy
local under
for _, p in towerParts do
	if (p.CFrame.Position - droot.CFrame.Position).Magnitude < 0.1 then
		under = p
	end
end
check(under and broken(under), "a dummy stands where a broken block was")
local fragsIn = function(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Fragment") then
			n += 1
		end
	end
	return n
end
check(fragsIn(tower) > 0, "the tower's cut pieces stand in for it (" .. fragsIn(tower) .. " fragments)")

-- MID: the wiped folders, over the foundations, round the dummy, a few a frame
local t0 = os.clock()
local n1 = Destruction.RestoreArea(O, 300, { Folders = { [B85] = true }, MinTop = O.Y + 3, Bodies = { dummy }, Above = 320, Below = 140, Batch = 3 })
local backTower, stillOut = 0, {}
for _, p in brokenTower do
	if p.Parent == tower then
		backTower += 1
	else
		table.insert(stillOut, p)
	end
end
print(string.format("  mid: %d put back (%d of %d tower blocks), %.3fs", n1, backTower, #brokenTower, os.clock() - t0))
check(n1 > 0 and backTower == #brokenTower - 2, "MID: the tower's broken blocks are back (" .. backTower .. "/" .. #brokenTower .. ")")
check(#stillOut == 2 and table.find(stillOut, under) and table.find(stillOut, held), "...but not one on top of the dummy, nor the piece in the marble")
check(lit.Parent == tower and lamp.Parent == lit, "...each with its own light (the cut pieces had none)")
local leftFrags = 0
for _, d in tower:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Fragment") then
		leftFrags += 1
	end
end
check(broken(road) and broken(slab), "...not the street, nor a slab under the foundations (theirs is the end of the rewind)")
check(broken(far), "...nor the house out of the blast's reach")

-- END: the rest (no dummy any more)
dummy:Destroy()
local n2 = Destruction.RestoreArea(O, 300, { Above = 320, Below = 140 })
check(n2 >= 3 and road.Parent == R85 and slab.Parent == tower and under.Parent == tower, "END: the crater in the road, the slab, the block the dummy left - back (" .. n2 .. ")")
check(broken(held) and broken(far), "...the marble's piece stays in the marble; the far house waits for the usual regrow")
local frag2 = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Fragment") and (d.CFrame.Position - O).Magnitude < 300 then
		local near = (d.CFrame.Position - held.CFrame.Position).Magnitude < 8
		if not near then
			frag2 += 1
		end
	end
end
check(frag2 == 0, "...and no cut pieces left over in reach but the marble's (" .. frag2 .. ")")
Destruction.Release(hold)
Destruction.RegenerateAll()

print("== round 96: DISMANTLE - Slice (a flat cut right through), Collapse (the top coming off), Crumble")
local ok96, err96 = pcall(function()
	local O96 = Vector3.new(900, 0, 0)
	local DMC = modules.QuirkConfig.Dismantle
	local B96 = map:FindFirstChild("Buildings") or Instance.new("Folder")
	B96.Name = "Buildings"
	B96.Parent = map
	local function part(parent, pos, size, cls)
		local p = Instance.new(cls or "Part")
		p.Size = size
		p.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
		p.Anchored = true
		p.Color = r.Color3.fromRGB(150, 120, 110)
		p:SetAttribute("Destroyable", true)
		p.Parent = parent
		return p
	end
	-- a small tower: four columns, four floors, a beam turned 30 degrees, a
	-- wedge, a lit block up top
	local function tower(name, at)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = B96
		for _, x in { -10, 10 } do
			for _, z in { -10, 10 } do
				part(m, at + Vector3.new(x, 20, z), Vector3.new(2, 40, 2))
			end
		end
		for _, y in { 10, 20, 30, 40 } do
			part(m, at + Vector3.new(0, y, 0), Vector3.new(22, 1, 22))
		end
		part(m, CFrame.new(at + Vector3.new(0, 25, 0)) * CFrame.Angles(0, math.rad(30), math.rad(20)), Vector3.new(2, 2, 16))
		local wedge = part(m, at + Vector3.new(4, 26, 4), Vector3.new(4, 6, 4))
		wedge.Shape = r.Enum.PartType.Wedge
		local lit = part(m, at + Vector3.new(-5, 36, -5), Vector3.new(4, 4, 4))
		local light = Instance.new("PointLight")
		light.Parent = lit
		return m
	end
	local function contents(m)
		local n, vol = 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Destroyable") == true then
				n += 1
				vol += d.Size.X * d.Size.Y * d.Size.Z
			end
		end
		return n, vol
	end
	-- how far any of them pokes onto the wrong side of the cut
	local function poke(list, P, M, side)
		local w = 0
		for _, p in list do
			local h, cf = p.Size / 2, p.CFrame
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						w = math.max(w, -(cf:PointToWorldSpace(Vector3.new(h.X * x, h.Y * y, h.Z * z)) - P):Dot(M) * side)
					end
				end
			end
		end
		return w
	end
	local function baseOf(m, g)
		local set, out = {}, {}
		for _, x in g.Movers do
			set[x] = true
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Destroyable") == true and not set[d] then
				table.insert(out, d)
			end
		end
		return out
	end
	local opts = { Step = DMC.Step, MinSize = DMC.MinSize, PerPart = DMC.PerPart, Budget = DMC.Budget, Upright = DMC.Upright, Flat = DMC.Slide.Flat, ClearPad = DMC.Slide.ClearPad, Stroke = Vector3.new(1, 0, 0) }
	local quick = {
		Slide = { Delay = 0.05, Start = 30, Accel = 300, Max = 300, MaxTime = 1, ClearPad = 2 },
		Fall = { Spin = 1, Tilt = 1, MaxTime = 2 },
		Topple = { Gap = 0.5, Accel = 60, Angle = 80 },
		Impact = { Debris = 5, Crater = 3 },
	}

	-- FLAT, through the middle
	local t1 = tower("Cut96", O96)
	local n0, v0 = contents(t1)
	local P = O96 + Vector3.new(0, 25, 0)
	local heldBefore = Destruction.HeldCount()
	local groups = Destruction.Slice({ t1 }, P, Vector3.new(0, 1, 0), opts)
	local g = groups[1]
	check(#groups == 1 and g.Mode == "Slide" and g.Unit == t1, "a flat cut through a building: one group, its top slides")
	if g then
		local n1, v1 = contents(t1)
		check(math.abs(v1 - v0) < 1e-3 * v0, string.format("...nothing lost or made: the same volume, in more parts (%d -> %d)", n0, n1))
		local square, slanted, wedgeUp = {}, {}, false
		for _, m in g.Movers do
			if m.Shape ~= r.Enum.PartType.Block then
				wedgeUp = wedgeUp or m.CFrame.Position.Y > P.Y
			elseif math.abs(m.CFrame.UpVector.Y) > 0.999 then
				table.insert(square, m)
			else
				table.insert(slanted, m)
			end
		end
		check(poke(square, P, g.Normal, 1) < 1e-3 and poke(baseOf(t1, g), P, g.Normal, -1) <= DMC.Step + 0.05 and poke(slanted, P, g.Normal, 1) <= DMC.Step + 0.05,
			"...cut through: a part square to it exactly, a turned one within Step; above it moves, below stays")
		check(wedgeUp, "...a wedge goes whole, to the side its middle's on")
		check((g.Dir - Vector3.new(1, 0, 0)).Magnitude < 1e-3 and g.Stroked == true, "...a flat cut's top slides along the drawn line")
		check(g.Clear >= 22 and math.abs(g.Ground - O96.Y) < 1e-3, "...far enough to clear what's left (" .. string.format("%.1f", g.Clear) .. "), its foot on the street")
		local lightMoved = false
		for _, m in g.Movers do
			if m:FindFirstChildOfClass("PointLight") then
				lightMoved = true
			end
		end
		local stored = game:GetService("ServerStorage"):FindFirstChild("BrokenMapParts")
		check(lightMoved and stored and #stored:GetChildren() > 0, "...a whole part goes as a copy, its light with it; the part itself waits in storage")
		check(Destruction.HeldCount() > heldBefore and Destruction.MovingCount() == #g.Movers, "...held from regrowing while it comes off (Held), all of it counted (MovingCount)")
		-- a carve meanwhile leaves the pieces coming off alone
		local floor30
		for _, m in g.Movers do
			if math.abs(m.CFrame.Position.Y - 30) < 0.01 and m.Size.X > 20 then
				floor30 = m
			end
		end
		Destruction.Sphere(floor30 and floor30.CFrame.Position or P + Vector3.new(0, 5, 0), 2, "Impact")
		check(floor30 ~= nil and floor30.Parent == t1 and Destruction.MovingCount() == #g.Movers, "...a carve meanwhile doesn't touch what's coming off")

		-- COLLAPSE
		local slid, landed, at
		local t0 = os.clock()
		local fromPivot = g.Centre
		local copts = table.clone(quick)
		copts.OnSlide = function()
			slid = true
		end
		copts.OnImpact = function(p)
			landed, at = os.clock() - t0, p
		end
		local debrisBefore = #workspace:FindFirstChild("MapDebris"):GetChildren()
		Destruction.Collapse(g, copts)
		task.wait(0.02)
		local welds = 0
		for _, m in g.Movers do
			if m:FindFirstChild("DismantleWeld") then
				welds += 1
			end
		end
		local root = g.Root
		check(welds == #g.Movers - 1 and root:FindFirstChild("DismantleMove") and root:FindFirstChild("DismantleTurn"),
			"COLLAPSE: welded into one body round its biggest piece, steered (AlignPosition, AlignOrientation)")
		local still = true
		for _, m in g.Movers do
			still = still and m.CanCollide == false and m.CanQuery == false
		end
		check(still and root.Anchored == true, "...nothing collides with it or finds it; held a beat (Delay) first")
		local maxX, minY, sawSlide, sawFall = -math.huge, math.huge, false, false
		local movedFree
		while not landed and os.clock() - t0 < 5 do
			task.wait()
			if g.Pivot then
				maxX = math.max(maxX, g.Pivot.Position.X)
				minY = math.min(minY, g.Pivot.Position.Y)
			end
			sawSlide = sawSlide or g.Phase == "Slide"
			if g.Phase == "Slide" and movedFree == nil then
				movedFree = root.Anchored == false
			end
			sawFall = sawFall or g.Phase == "Fall"
		end
		check(slid and sawSlide and sawFall and maxX > fromPivot.X + 20, string.format("...it slides off along the drawn line (%.0f studs), then falls", maxX - fromPivot.X))
		check(movedFree == true, "...moving for real (unanchored, the server's)")
		check(landed ~= nil and at ~= nil and math.abs(at.Y - g.Ground) < 1e-3 and minY < fromPivot.Y - 10, "...and lands on the street (" .. tostring(landed and string.format("%.2f s", landed)) .. ")")
		task.wait(0.05)
		local gone = true
		for _, m in g.Movers do
			gone = gone and m.Parent == nil
		end
		local debrisAfter = #workspace:FindFirstChild("MapDebris"):GetChildren()
		check(gone and Destruction.MovingCount() == 0 and g.Done == true, "CRUMBLE: what came down is gone")
		check(debrisAfter > debrisBefore and debrisAfter - debrisBefore <= quick.Impact.Debris, "...chunks of it flung (" .. (debrisAfter - debrisBefore) .. ", at most Impact.Debris)")
		check(Destruction.HeldCount() == heldBefore, "...and the building's free to grow back")
		Destruction.RegenerateAll()
		local n2, v2 = contents(t1)
		check(n2 == n0 and math.abs(v2 - v0) < 1e-3, "REGROW: the building's back as it was (" .. n2 .. " parts)")
	end

	-- SLANTED, 30 degrees: the staircase within Step
	local nS = Vector3.new(math.sin(math.rad(30)), math.cos(math.rad(30)), 0)
	local gs = Destruction.Slice({ t1 }, P, nS, opts)[1]
	if gs then
		local over, under = poke(gs.Movers, P, gs.Normal, 1), poke(baseOf(t1, gs), P, gs.Normal, -1)
		check(over <= DMC.Step + 0.05 and under <= DMC.Step + 0.05, string.format("a slanted cut: pieces at most Step off it (%.2f / %.2f, Step %.1f)", over, under, DMC.Step))
		check(gs.Mode == "Slide" and gs.Dir.Y < -0.4 and not gs.Stroked, "...and the top slides DOWN it")
		Destruction.Crumble(gs)
		Destruction.RegenerateAll()
	else
		check(false, "a slanted cut makes a group")
	end

	-- UPRIGHT: the smaller side topples over, away from the cut
	local Pu = O96 + Vector3.new(6, 0, 0)
	local gu = Destruction.Slice({ t1 }, Pu, Vector3.new(-1, 0, 0), opts)[1]
	if gu then
		local small = true
		for _, m in gu.Movers do
			small = small and m.CFrame.Position.X > Pu.X - 0.01
		end
		check(gu.Mode == "Topple" and small and gu.Dir.X > 0.99, "an upright cut: the smaller side (out past it) topples, away from the cut")
		local landedU
		local copts = table.clone(quick)
		copts.OnImpact = function(p)
			landedU = p
		end
		local look0 = CFrame.new(gu.Centre)
		Destruction.Collapse(gu, copts)
		local t0 = os.clock()
		local tilted = 0
		while not landedU and os.clock() - t0 < 4 do
			task.wait()
			if gu.Pivot then
				tilted = math.max(tilted, math.deg(math.acos(math.clamp(gu.Pivot.UpVector:Dot(Vector3.new(0, 1, 0)), -1, 1))))
			end
		end
		check(landedU ~= nil and tilted > 60 and Destruction.MovingCount() == 0, string.format("...over it goes (%.0f degrees) and down", tilted))
		Destruction.RegenerateAll()
	else
		check(false, "an upright cut makes a group")
	end

	-- THE BUDGET: past it, a part goes whole by its middle
	local gb = Destruction.Slice({ t1 }, P, nS, { Step = DMC.Step, MinSize = DMC.MinSize, PerPart = DMC.PerPart, Budget = 4, Upright = DMC.Upright })[1]
	if gb then
		local _, vb = contents(t1)
		check(math.abs(vb - v0) < 1e-3 and poke(gb.Movers, P, gb.Normal, 1) > DMC.Step, "past the Budget the rest go whole by their middle (nothing lost)")
		Destruction.Crumble(gb)
	end
	Destruction.RegenerateAll()

	-- PUT BACK meanwhile (the test menu's rebuild): it lets go
	local gr = Destruction.Slice({ t1 }, P, Vector3.new(0, 1, 0), opts)[1]
	if gr then
		local copts = table.clone(quick)
		copts.Slide = table.clone(quick.Slide)
		copts.Slide.Delay = 0.3
		Destruction.Collapse(gr, copts)
		task.wait(0.05)
		Destruction.RegenerateAll()
		task.wait(0.5)
		local n3 = contents(t1)
		check(gr.Done == true and Destruction.MovingCount() == 0 and Destruction.HeldCount() == heldBefore and n3 == n0,
			"rebuilt while it's coming off: it lets go, nothing left held or moving")
	end
	t1:Destroy()
end)
if not ok96 then
	check(false, "round 96 section errored: " .. tostring(err96))
end

print(string.format("\n%d passed, %d problem(s)", passes, #problems))
process.exit(#problems == 0 and 0 or 1)

