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

print(string.format("\n%d passed, %d problem(s)", passes, #problems))
process.exit(#problems == 0 and 0 or 1)

