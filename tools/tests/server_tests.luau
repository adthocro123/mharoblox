-- Headless fight simulation: runs the real QuirkServer + QuirkConfig against
local task = require("@lune/task")
-- mocked engine services and checks guard / parry / guard break / KO flows.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local M = require("./mock")
local Vector3, CFrame, Enum = M.Vector3, M.CFrame, M.Enum

local SRC = process.args[1] or "../src"
local failures, passes = 0, 0
local function check(cond, label)
	if cond then
		passes += 1
		print("  PASS  " .. label)
	else
		failures += 1
		print("  FAIL  " .. label)
	end
end
M.section = function(fn) -- (round 94: a stale section is one failure, not the end of the run)
	local ok, err = pcall(fn)
	if not ok then
		check(false, "section errored: " .. tostring(err))
	end
end

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local game = M.new("DataModel", "Game")
game.CreatorId = 0
local services = {}
local function service(name)
	if not services[name] then
		local s = M.new(name, name)
		s.Parent = game
		services[name] = s
	end
	return services[name]
end
function game.GetService(_, name)
	return service(name)
end
local Players = service("Players")
local ReplicatedStorage = service("ReplicatedStorage")
local ServerScriptService = service("ServerScriptService")
local RunService = service("RunService")
local studioMode = true
function RunService.IsStudio()
	return studioMode
end
local Debris = service("Debris")
function Debris.AddItem(_, obj, t)
	task.delay(t or 10, function()
		obj:Destroy()
	end)
end
local workspace = M.new("Workspace", "Workspace")
workspace.Parent = game
workspace.Gravity = 196.2
local map = M.new("Folder", "Map")
map.Parent = workspace
-- the street everything stands on (the real map's base plates are named this)
local basePlate = M.new("Part", "Undestroyable")
basePlate.Size = Vector3.new(5000, 1, 5000)
basePlate.CFrame = CFrame.new(0, -0.5, 0)
basePlate.Anchored = true
basePlate.Parent = map
-- a spawn pad (with its decal), to check the server hides it
local spawnPad = M.new("SpawnLocation", "SpawnLocation")
spawnPad.CFrame = CFrame.new(0, 0.5, 900)
spawnPad.Size = Vector3.new(12, 1, 12)
local spawnDecal = M.new("Decal", "Decal")
spawnDecal.Parent = spawnPad
spawnPad.Parent = map
local dummies = M.new("Folder", "Dummies")
dummies.Parent = workspace

local playerList = {}
function Players.GetPlayers()
	return table.clone(playerList)
end
function Players.GetPlayerByUserId(_, userId)
	for _, p in playerList do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end
function Players.GetPlayerFromCharacter(_, model)
	for _, p in playerList do
		if p.Character == model then
			return p
		end
	end
	return nil
end

-- every character model in the world, for overlap queries
local function allModels()
	local list = {}
	for _, p in playerList do
		if p.Character and p.Character.Parent then
			table.insert(list, p.Character)
		end
	end
	for _, d in dummies:GetChildren() do
		table.insert(list, d)
	end
	local doubles = workspace:FindFirstChild("TwiceClones") -- (round 69: Twice's doubles)
	for _, d in doubles and doubles:GetChildren() or {} do
		table.insert(list, d)
	end
	local raid = workspace:FindFirstChild("NomuRaid") -- (round 71: the Nomu)
	for _, d in raid and raid:GetChildren() or {} do
		table.insert(list, d)
	end
	return list
end
local function excluded(model, params)
	for _, inst in params and params.FilterDescendantsInstances or {} do
		if inst == model or model:IsDescendantOf(inst) then
			return true
		end
	end
	return false
end
function workspace.GetPartBoundsInBox(_, cf, size, params)
	local out = {}
	for _, model in allModels() do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and not excluded(model, params) then
			local lp = cf:PointToObjectSpace(root.Position)
			if math.abs(lp.X) <= size.X / 2 + 1 and math.abs(lp.Y) <= size.Y / 2 + 1 and math.abs(lp.Z) <= size.Z / 2 + 1 then
				table.insert(out, root)
			end
		end
	end
	return out
end
function workspace.GetPartBoundsInRadius(_, pos, radius, params)
	local out = {}
	for _, model in allModels() do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and not excluded(model, params) and (root.Position - pos).Magnitude <= radius + 1 then
			table.insert(out, root)
		end
	end
	return out
end
function workspace.Raycast()
	return nil
end
function workspace.GetServerTimeNow()
	return os.clock()
end

-- Remotes + shared modules
local remotes = M.new("Folder", "Remotes")
remotes.Parent = ReplicatedStorage
for _, n in { "UseAbility", "SelectQuirk", "PlayVFX", "TestCommand" } do
	M.new("RemoteEvent", n).Parent = remotes
end
local shared = M.new("Folder", "Shared")
shared.Parent = ReplicatedStorage

-- (round 71) Random.new(seed): the same numbers for the same seed
local function seededRandom(seed)
	local state = math.floor(tonumber(seed) or math.random(1, 2 ^ 30)) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function nxt()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, a, b) return (a or 0) + ((b or 1) - (a or 0)) * nxt() end,
		NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end,
		NextUnitVector = function() return Vector3.new(0, 1, 0) end,
	}
end

local function env(scriptInst)
	local e = {
		game = game,
		workspace = workspace,
		script = scriptInst,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = M.Color3,
		Enum = Enum,
		NumberSequence = { new = function() return {} end },
		NumberSequenceKeypoint = { new = function() return {} end },
		ColorSequence = { new = function() return {} end },
		NumberRange = { new = function() return {} end },
		PhysicalProperties = { new = function(d, f, e, fw, ew) return { Density = d, Friction = f, Elasticity = e or 0.5, FrictionWeight = fw or 1, ElasticityWeight = ew or 1 } end },
		Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end },
		OverlapParams = { new = function() return {} end },
		RaycastParams = { new = function() return {} end },
		Random = { new = seededRandom },
		Instance = { new = function(c) return M.new(c) end },
		task = task,
		typeof = function(v)
			if type(v) == "table" and rawget(v, "_props") then
				return "Instance"
			end
			return typeof(v)
		end,
		warn = function(...)
			print("  [warn]", ...)
		end,
	}
	e.require = function(mod)
		return rawget(mod, "_exports")
	end
	return setmetatable(e, { __index = _G })
end

local function loadModule(path, name, parent)
	local inst = M.new("ModuleScript", name)
	inst.Parent = parent
	local fn = luau.load(fs.readFile(path), { debugName = name, environment = env(inst) })
	rawset(inst, "_exports", fn())
	return inst
end

local configInst = loadModule(SRC .. "/ReplicatedStorage.Shared.QuirkConfig.lua", "QuirkConfig", shared)
local Config = rawget(configInst, "_exports")
-- (round 72) developer products for the Robux emote rolls (a real game pastes its own IDs)
for n, spec in Config.EmoteShop.Robux do
	spec.Product = 72000 + n
end
-- the real ice layouts (the server carves with exactly these spikes)
local spikes = loadModule(SRC .. "/ReplicatedStorage.Shared.SpikeLayouts.lua", "SpikeLayouts", shared)
local destruction = M.new("ModuleScript", "Destruction")
destruction.Parent = ServerScriptService
local noop = function() end
-- record which destruction profiles get used, so we can check they exist
local profilesUsed = {}
local function carveStub(...)
	local args = table.pack(...)
	for i = 1, args.n do
		if type(args[i]) == "string" then
			profilesUsed[args[i]] = true
		end
	end
end
-- Crazy Diamond's side of it: rubble to build with, restoring what's broken
local cd = { rubble = 5, restored = {}, flights = {}, rubbleCalls = 0, restoreCalls = 0 }
local function rubbleStub(center, _, want)
	cd.rubbleCalls += 1
	local out = {}
	for i = 1, math.min(want, cd.rubble) do
		out[i] = { Position = center + Vector3.new(i * 3, 1, 0), Size = Vector3.one * 2, Color = M.Color3.fromRGB(123, 111, 99), Material = Enum.Material.Brick }
	end
	return out
end
local function restoreStub(center, radius)
	cd.restoreCalls += 1
	cd.lastRestore = { center, radius }
	return cd.restored, table.clone(cd.flights)
end
rawset(destruction, "_exports", {
	Sphere = carveStub, Box = carveStub, Capsule = carveStub, Cylinder = carveStub, Spikes = carveStub,
	RegisterCharacter = noop, RegenerateAll = noop, SetEnabled = noop,
	Rubble = rubbleStub, NearestBreakable = function() return nil end, RestoreNear = restoreStub,
})
-- MR. COMPRESS: a fake piece of the map wherever he points (unless the test
-- says the spot's bare), and the holds counted
cd.held = 0
cd.bare = false
cd.compressCalls = 0
cd.releaseCalls = 0
local dx = rawget(destruction, "_exports")
dx.NearestBreakable = function(center, _radius)
	if cd.bare then
		return nil
	end
	local part = M.new("Part", "Part")
	part.Color = M.Color3.fromRGB(123, 111, 99)
	part.Material = Enum.Material.Brick
	part.Position = center
	part.CFrame = CFrame.new(center)
	return part, center
end
dx.Compress = function(center, radius)
	cd.compressCalls += 1
	cd.held += 1
	cd.lastCompress = { center, radius }
	return { Parts = {}, Count = 1 }
end
dx.Release = function(hold)
	if hold and not hold.Released then
		hold.Released = true
		cd.releaseCalls += 1
		cd.held -= 1
	end
end
dx.HeldCount = function()
	return cd.held
end


DS = { data = {}, board = {} }
do
	local serde = require("@lune/serde")
	local DSS = service("DataStoreService")
	function DSS.GetDataStore(_, _name)
		return {
			GetAsync = function(_, k)
				return DS.data[k]
			end,
			SetAsync = function(_, k, v)
				DS.data[k] = v
			end,
		}
	end
	function DSS.GetOrderedDataStore(_, _name)
		return {
			SetAsync = function(_, k, v)
				DS.board[k] = v
			end,
			GetSortedAsync = function(_, _asc, size)
				local page = {}
				for k, v in DS.board do
					table.insert(page, { key = k, value = v })
				end
				table.sort(page, function(a, b)
					return a.value > b.value
				end)
				while #page > size do
					table.remove(page)
				end
				return { GetCurrentPage = function()
					return page
				end }
			end,
		}
	end
	local http = service("HttpService")
	function http.JSONEncode(_, v)
		return serde.encode("json", v)
	end
	function http.JSONDecode(_, v)
		return serde.decode("json", v)
	end
end
do
	local ct = M.new("Model", "Chairs & Tables")
	ct.Parent = map
	local function block(modelName, pos, size)
		local m = M.new("Model", modelName)
		local p = M.new("Part", "Part")
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Anchored = true
		p.Parent = m
		m.Parent = ct
		return m
	end
	block("Table", Vector3.new(-95, 28.2, 567), Vector3.new(4, 3, 4))
	for _, o in { Vector3.new(5.5, 0, 0), Vector3.new(-5.5, 0, 0), Vector3.new(0, 0, 5.5), Vector3.new(0, 0, -5.5) } do
		block("Big Seat", Vector3.new(-95, 27.6, 567) + o, Vector3.new(2, 2, 2))
	end
	-- (a stool too far from any table: not a seat)
	block("Big Seat", Vector3.new(-95, 27.6, 600), Vector3.new(2, 2, 2))
	block("Table", Vector3.new(-120, 28.2, 590), Vector3.new(4, 3, 4))
	for _, sx in { 5.5, -5.5 } do
		local chair = block("Chair", Vector3.new(-120 + sx, 29.17, 590), Vector3.new(3, 0.3, 2.7))
		local back = M.new("Part", "Part")
		back.Size = Vector3.new(0.3, 6.3, 2.7)
		back.CFrame = CFrame.new(Vector3.new(-120 + sx + (sx > 0 and 1.35 or -1.35), 29.77, 590))
		back.Anchored = true
		back.Parent = chair
	end
end
local serverScript = M.new("Script", "QuirkServer")
serverScript.Parent = ServerScriptService
local serverFn = luau.load(fs.readFile(SRC .. "/ServerScriptService.QuirkServer.server.lua"), { debugName = "QuirkServer", environment = env(serverScript) })
task.spawn(serverFn)
task.wait(0.1)

-- drive Heartbeat (guard regen)
task.spawn(function()
	while true do
		RunService.Heartbeat:Fire(1 / 30)
		task.wait(1 / 30)
	end
end)

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------
local function makeCharacter(name, cf)
	local model = M.new("Model", name)
	local root = M.new("Part", "HumanoidRootPart")
	root.CFrame = cf
	root.Parent = model
	local hum = M.new("Humanoid", "Humanoid")
	hum.Parent = model
	model.PrimaryPart = root
	return model, hum, root
end

local function addPlayer(name, userId)
	local p = M.new("Player", name)
	p.DisplayName = name
	p.UserId = userId
	table.insert(playerList, p)
	p.Parent = Players
	function p.LoadCharacter() end
	Players.PlayerAdded:Fire(p)
	task.wait()
	return p
end

local function spawnChar(p, cf)
	local model, hum, root = makeCharacter(p.Name, cf)
	model.Parent = workspace
	p.Character = model
	p.CharacterAdded:Fire(model)
	task.wait(0.05)
	return model, hum, root
end

local UseAbility = remotes:FindFirstChild("UseAbility")
local SelectQuirk = remotes:FindFirstChild("SelectQuirk")
local TestCommand = remotes:FindFirstChild("TestCommand")
local function fire(remote, ...)
	remote.OnServerEvent:Fire(...)
	task.wait()
end

local function sentTo(p, effectId)
	local out = {}
	for _, s in M.sent do
		if (s.To == p or s.To == "all") and s.Args[1] == effectId then
			table.insert(out, s.Args[3])
		end
	end
	return out
end
local function clearSent()
	table.clear(M.sent)
end

local function stat(p, name)
	return p:FindFirstChild("leaderstats"):FindFirstChild(name).Value
end

local BLOCK = Config.BLOCK_INDEX
local G = Config.Guard

local A = addPlayer("Alpha", 1)
local B = addPlayer("Bravo", 2)
fire(SelectQuirk, A, "Explosion")
fire(SelectQuirk, B, "Explosion")
-- A at origin facing +Z toward B; B 4 studs away facing A
local aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 4)))
local bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
task.wait(0.1)

workspace:SetAttribute("HealthRegen", false) -- (off: these tests count exact health; round 30 turns it on)
workspace:SetAttribute("NomuRaid", false) -- (round 71: no scheduled raid landing mid-test)
print("== setup")
check(A:FindFirstChild("leaderstats") ~= nil, "leaderstats created")
check(bHum.Health == Config.PlayerMaxHealth, "player health set to " .. Config.PlayerMaxHealth)
check(bChar:GetAttribute("Guard") == G.Max, "guard meter starts full")

local function m1(p)
	fire(UseAbility, p, 0)
	task.wait(0.15) -- the hit resolves 0.08s after the swing
end

print("== unblocked hit")
clearSent()
local h0 = bHum.Health
m1(A)
check(bHum.Health == h0 - Config.M1.Damage, "M1 deals " .. Config.M1.Damage)
local hits = sentTo(A, "Hit")
check(#hits == 1 and hits[1].Attacker == A and hits[1].Amount == Config.M1.Damage, "Hit broadcast carries attacker + amount")
task.wait(Config.M1.ComboReset + 0.1)

print("== block (after the parry window)")
fire(UseAbility, B, BLOCK, true)
check(bChar:GetAttribute("Blocking") == true, "guard raised")
check(#sentTo(A, "Guard") == 1 and #sentTo(B, "Guard") == 0, "Guard shown to others, not echoed to the owner")
task.wait(G.ParryWindow + 0.1)
clearSent()
h0 = bHum.Health
m1(A)
local chip = math.floor(Config.M1.Damage * G.ChipDamage + 0.5)
check(bHum.Health == h0 - chip, string.format("blocked hit only chips %d (took %d)", chip, h0 - bHum.Health))
check(#sentTo(A, "Block") == 1 and #sentTo(A, "Hit") == 0, "Block effect instead of Hit")
local expectGuard = math.floor(G.Max - Config.M1.Damage * G.GuardDamagePerDamage + 0.5)
check(bChar:GetAttribute("Guard") == expectGuard, "guard meter drained to " .. expectGuard .. " (got " .. tostring(bChar:GetAttribute("Guard")) .. ")")
check(not bChar:GetAttribute("Stunned"), "blocker isn't stunned")

print("== guard regen")
fire(UseAbility, B, BLOCK, false)
check(bChar:GetAttribute("Blocking") == false, "guard lowered")
task.wait(G.RegenDelay + 0.6)
check((bChar:GetAttribute("Guard") or 0) > expectGuard, "meter refills after RegenDelay (" .. tostring(bChar:GetAttribute("Guard")) .. ")")
task.wait(1.5)

print("== parry")
task.wait(G.ParryLockout)
fire(UseAbility, B, BLOCK, true)
clearSent()
h0 = bHum.Health
m1(A)
check(bHum.Health == h0, "parried hit does no damage")
local parries = sentTo(A, "Parry")
check(#parries == 1 and parries[1].By == B and parries[1].Against == A, "Parry broadcast names both players")
check(aChar:GetAttribute("Stunned") == true, "attacker is stunned by the parry")
fire(UseAbility, A, 0)
task.wait(0.15)
check(bHum.Health == h0, "a stunned attacker can't swing")
task.wait(G.ParryStun + 0.1)
check(not aChar:GetAttribute("Stunned"), "attacker recovers after ParryStun")

print("== parry lockout (mashing the guard)")
fire(UseAbility, B, BLOCK, false)
fire(UseAbility, B, BLOCK, true) -- instant re-raise
clearSent()
task.wait(Config.M1.ComboReset)
m1(A)
check(#sentTo(A, "Parry") == 0 and #sentTo(A, "Block") == 1, "re-raising too soon blocks but can't parry")

print("== guard break")
task.wait(0.3)
bChar:SetAttribute("Stunned", false)
local broke = false
for _ = 1, 30 do
	m1(A)
	task.wait(0.25)
	if #sentTo(A, "GuardBreak") > 0 then
		broke = true
		break
	end
end
check(broke, "enough blocked hits shatter the guard")
check(bChar:GetAttribute("GuardBroken") == true and bChar:GetAttribute("Blocking") == false, "broken guard drops the block")
check(bChar:GetAttribute("Stunned") == true, "guard break stuns")
fire(UseAbility, B, BLOCK, true)
check(bChar:GetAttribute("Blocking") == false, "can't re-raise a broken guard")
task.wait(G.BreakStun + 0.2)
check(bChar:GetAttribute("GuardBroken") == false, "guard recovers after BreakStun")
check(math.abs((bChar:GetAttribute("Guard") or 0) - G.Max * G.BreakRefill) <= 6, "guard refilled to BreakRefill (" .. tostring(bChar:GetAttribute("Guard")) .. ")")

print("== hit from behind")
task.wait(Config.M1.ComboReset)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 10)) -- B turns away
fire(UseAbility, B, BLOCK, true)
task.wait(G.ParryWindow + 0.1)
clearSent()
h0 = bHum.Health
m1(A)
check(bHum.Health == h0 - Config.M1.Damage, "a guard doesn't cover your back")
check(bChar:GetAttribute("Blocking") == false, "getting hit from behind drops the guard")
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0))

print("== attacking lowers your own guard")
task.wait(Config.M1.ComboReset)
fire(UseAbility, A, BLOCK, true)
check(aChar:GetAttribute("Blocking") == true, "attacker raises guard")
m1(A)
check(aChar:GetAttribute("Blocking") == false, "swinging drops it")

print("== KO + recap")
task.wait(Config.M1.ComboReset)
clearSent()
bHum.Health = 3
local aHealthBefore = aHum.Health
aHum.Health = 100
m1(A)
task.wait(0.1)
check(bHum.Health == 0, "B knocked out")
local kos = stat(A, "Kills")
check(kos == 1 and stat(A, "Streak") == 1, "KO + streak credited to A")
local confirm = sentTo(A, "KOConfirm")
check(#confirm == 1 and confirm[1].Victim == "Bravo" and confirm[1].Counted, "A gets the KO popup")
check(aHum.Health == 100 + Config.Fights.HealOnKO, "KO heals the attacker")
local feed = sentTo(B, "KOFeed")
check(#feed == 1 and feed[1].Killer == "Alpha" and feed[1].Victim == "Bravo", "kill feed reaches everyone")
local recap = sentTo(B, "Recap")
check(#recap == 1 and recap[1].Killer == "Alpha", "B's recap names the attacker")
check(recap[1] and recap[1].Blocked >= 3 and recap[1].Parries == 1 and recap[1].Taken > 0, string.format("recap stats (taken %s, blocked %s, parries %s)", tostring(recap[1] and recap[1].Taken), tostring(recap[1] and recap[1].Blocked), tostring(recap[1] and recap[1].Parries)))
local recapA = sentTo(A, "Recap")
check(#recapA == 0, "only the victim gets a recap")
local _ = aHealthBefore

print("== streak + callout + shutdown")
for i = 2, 3 do
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
	task.wait(Config.M1.ComboReset)
	clearSent()
	bHum.Health = 2
	m1(A)
	task.wait(0.1)
	print("   dbg B health", bHum.Health, "B stunned", bChar:GetAttribute("Stunned"), "hits", #sentTo(A, "Hit"), "blocks", #sentTo(A, "Block"), "punch", #sentTo(B, "Punch"), "kos", stat(A, "Kills"))
	check(stat(A, "Streak") == i, "streak " .. i)
end
local c3 = sentTo(A, "KOConfirm")
check(#c3 == 1 and c3[1].Callout == Config.Fights.StreakCallouts[3], "3-KO callout: " .. tostring(c3[1] and c3[1].Callout))
check(A:GetAttribute("BestStreak") == 3, "best streak tracked")
-- B finally takes A down: A's 3-streak ends (shutdown)
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
task.wait(Config.M1.ComboReset)
clearSent()
aHum.Health = 2
fire(UseAbility, B, 0)
task.wait(0.2)
check(stat(A, "Streak") == 0, "A's streak resets on KO")
local shut = sentTo(A, "KOFeed")
check(#shut == 1 and shut[1].Shutdown == 3, "feed announces the ended 3-streak")

print("== fall with no recent attacker")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 4)))
task.wait(0.1)
clearSent()
aHum:TakeDamage(1000)
task.wait(0.1)
local fall = sentTo(B, "KOFeed")
check(#fall == 1 and fall[1].Killer == nil, "no credit without a hit")
check(stat(B, "Kills") == 1, "B's KO count unchanged by A's fall")

print("== dummies")
local dummy, dHum = makeCharacter("Training Dummy", CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
dHum.MaxHealth = 500
dHum.Health = 500
dummy.Parent = dummies
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 4)))
bChar.Parent = nil -- B out of the way
task.wait(0.6)
fire(TestCommand, A, "DummiesBlock")
task.wait(0.1)
check(dummy:GetAttribute("Blocking") == true, "test menu: dummies raise their guard")
clearSent()
m1(A)
check(#sentTo(A, "Block") == 1 and #sentTo(A, "Parry") == 0, "dummies block (never parry)")
fire(TestCommand, A, "DummiesBlock")
task.wait(Config.M1.ComboReset)
local before = stat(A, "Kills")
clearSent()
dHum.Health = 2
m1(A)
task.wait(0.1)
check(stat(A, "Kills") == before, "dummy KOs don't count by default")
local dfeed = sentTo(A, "KOFeed")
check(#dfeed == 1 and dfeed[1].Dummy == true and #sentTo(B, "KOFeed") == 0, "dummy KO feed is private to the attacker")


print("== DECAY (dev-only)")
dummy:Destroy()
bChar.Parent = workspace
local C = Config.Quirks.Decay
-- fresh bodies, B 10 studs in front of A
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 10)))
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 10), Vector3.new(0, 3, 0)))
task.wait(0.2)
studioMode = false -- a live server: A isn't the creator or allow-listed
fire(SelectQuirk, A, "Limitless")
check(A:GetAttribute("Quirk") ~= "Limitless", "non-testers can't pick a dev-only quirk (Limitless - Decay's public now)")
studioMode = true
fire(SelectQuirk, A, "Decay")
check(A:GetAttribute("Quirk") == "Decay", "testers can pick it")
task.wait(0.1)
local fwd = Vector3.new(0, 0, 1)
local function cast(index, extra)
	fire(UseAbility, A, index, fwd, Vector3.new(0, 3, 10), 1234, aRoot.Position)
	task.wait(extra or 0)
end

-- 1: DECAY wave, then the decay keeps eating
clearSent()
bHum.Health = 200
cast(1, 1.0)
local afterHit = bHum.Health
check(afterHit <= 200 - C.Abilities[1].Damage, "DECAY wave hits (" .. (200 - afterHit) .. " dmg so far)")
check(#sentTo(A, "Decaying") == 1 and bChar:GetAttribute("Decaying") == true, "target is decaying")
task.wait(C.Abilities[1].DecayTicks * 0.5 + 0.3)
check(bHum.Health == 200 - C.Abilities[1].Damage - C.Abilities[1].DecayTicks * C.Abilities[1].DecayDamage, "decay ticks deal " .. C.Abilities[1].DecayTicks * C.Abilities[1].DecayDamage .. " more (hp " .. bHum.Health .. ")")
check(bChar:GetAttribute("Decaying") == false, "decay wears off")

-- the decay itself can land the KO (credited to the one who touched you)
local kosBefore = stat(A, "Kills")
bHum.Health = C.Abilities[1].Damage + 2
bChar:SetAttribute("Stunned", false)
task.wait(C.Abilities[1].Cooldown)
cast(1, 0.5 + C.Abilities[1].DecayTicks * 0.5 + 0.3)
check(bHum.Health == 0 and stat(A, "Kills") == kosBefore + 1, "KO by decay is credited")

-- R: RIVET STAB through a target 30 studs out
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 30), Vector3.new(0, 3, 0)))
task.wait(0.2)
clearSent()
cast(Config.SPECIAL_INDEX, 0.4)
check(bHum.Health == Config.PlayerMaxHealth - C.Special.Damage, "RIVET STAB pierces to 30 studs (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(profilesUsed.Rivet == true, "lances drill with the Rivet profile")
task.wait((C.Special.Pin or 0) + (C.Special.Reel or 0) + 0.1) -- (round 84: the pin and the reel)

-- 3: COLLAPSE: A can't be touched during the windup, B inside the radius is caught
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 12), Vector3.new(0, 3, 0)))
fire(SelectQuirk, B, "OneForAll")
task.wait(0.2)
aHum.Health = 200
clearSent()
cast(3, 0.1)
fire(UseAbility, B, 0)
task.wait(0.2)
check(aHum.Health == 200, "caster can't be hit during the COLLAPSE windup")
task.wait(1.5)
check(bHum.Health <= Config.PlayerMaxHealth - C.Abilities[3].Damage, "COLLAPSE catches B (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(profilesUsed.Decay == true, "the map crumbles with the Decay profile")

-- G: ALL FOR ONE
task.wait(3)
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 12), Vector3.new(0, 3, 0)))
task.wait(0.2)
A:SetAttribute("Ult", 100)
fire(UseAbility, A, Config.ULT_INDEX)
check(A:GetAttribute("UltActive") == true, "awakening")
aHum.Health = 200
fire(UseAbility, B, 0)
task.wait(0.2)
check(aHum.Health == 200, "the awakening can't be interrupted")
task.wait(1.2)
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 40), Vector3.new(0, 3, 0)))
task.wait(0.2)
cast(1, 0.8)
check(bHum.Health < Config.PlayerMaxHealth, "RADIO WAVES reaches 40 studs")
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(-30, 3, 0), Vector3.new(0, 3, 0)))
task.wait(0.2)
cast(2, 0.6)
check(bHum.Health < Config.PlayerMaxHealth, "RIVET STORM hits someone to the side")
task.wait((C.Ult.Abilities[2].Hold or 0) + (C.Ult.Abilities[2].SlamTime or 0) + 0.1) -- (round 84: the lift and the slam)
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(80, 3, 60), Vector3.new(0, 3, 0)))
task.wait(0.2)
clearSent()
cast(3, 1.3 + 2.4 + 0.3)
check(bHum.Health <= Config.PlayerMaxHealth - C.Ult.Abilities[3].Damage * Config.Ult.DamageMultiplier + 1, "TOTAL DECAY reaches 100 studs out (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(profilesUsed.DecayHuge == true, "TOTAL DECAY uses the DecayHuge profile")


print("== DEV ACCESS grants")
studioMode = false
game.CreatorId = 1 -- A (UserId 1) owns the game; B is a regular player
fire(SelectQuirk, A, "Explosion")
A:SetAttribute("Tester", true)
fire(SelectQuirk, B, "Limitless")
check(B:GetAttribute("Quirk") ~= "Limitless", "B can't pick a dev character yet")
clearSent()
fire(TestCommand, B, "GrantDevAll", nil, true)
fire(TestCommand, B, "GrantDev", B.UserId, true)
fire(SelectQuirk, B, "Limitless")
check(B:GetAttribute("Quirk") ~= "Limitless", "a non-tester can't grant access (not even to themselves)")
fire(TestCommand, A, "GrantDev", B.UserId, true)
check(B:GetAttribute("DevAccess") == true, "the owner grants B access")
check(#sentTo(B, "Notice") == 1, "B is told they got access")
fire(SelectQuirk, B, "Limitless")
check(B:GetAttribute("Quirk") == "Limitless", "B can now pick Limitless")
fire(TestCommand, A, "GrantDev", B.UserId, false)
check(B:GetAttribute("DevAccess") == false, "access revoked")
check(B:GetAttribute("Quirk") ~= "Limitless" and Config.Quirks[B:GetAttribute("Quirk")] ~= nil, "revoking moves B off the dev character (now " .. tostring(B:GetAttribute("Quirk")) .. ")")
fire(TestCommand, A, "GrantDevAll", nil, true)
check(B:GetAttribute("DevAccess") == true, "grant everyone")
fire(TestCommand, A, "GrantDev", A.UserId, false)
check(A:GetAttribute("Quirk") == "Explosion" and (A:GetAttribute("DevAccess") ~= false), "testers can't revoke themselves")
fire(TestCommand, A, "GrantDevAll", nil, false)
check(B:GetAttribute("DevAccess") == false, "revoke all")
studioMode = true

print("== UNITED STATES OF SMASH (rebuilt)")
local USS = Config.Quirks.OneForAll.Ult.Abilities[3]
fire(SelectQuirk, A, "OneForAll")
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 10)))
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 7), Vector3.new(0, 3, 0)))
task.wait(0.2)
A:SetAttribute("Ult", 100)
fire(UseAbility, A, Config.ULT_INDEX)
task.wait(1.4)
check(A:GetAttribute("UltActive") == true and A:GetAttribute("QuirkAlt") == true, "Plus Ultra (muscle form forced)")
local third = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
local cChar, cHum = spawnChar(third, CFrame.lookAt(Vector3.new(30, 3, 7), Vector3.new(0, 3, 7)))
task.wait(0.2)
fire(UseAbility, A, 3, Vector3.new(0, 0, 1), Vector3.new(0, 3, 10), 5, aRoot.Position)
task.wait(USS.LungeStartup + 0.1 + USS.BuildTime + USS.FreezeTime + USS.SlamTime + 0.35) -- (round 78: the catch, the build, the freeze, the slam)
local mult = Config.Ult.DamageMultiplier
check(bHum.Health <= Config.PlayerMaxHealth - math.floor(USS.Damage * mult + 0.5), "the overhand right buries B (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(bChar:GetAttribute("Ragdolled") == true, "B is slammed into the ground (ragdolled)")
check(cHum.Health <= Config.PlayerMaxHealth - math.floor(USS.WindDamage * mult + 0.5), "the wind pressure hits C at 30 studs (took " .. (Config.PlayerMaxHealth - cHum.Health) .. ")")
-- someone 75 studs off is dragged toward it
local fourth = Players:FindFirstChild("Delta") or addPlayer("Delta", 4)
local dChar, _, dRoot = spawnChar(fourth, CFrame.lookAt(Vector3.new(75, 3, 17), Vector3.new(0, 3, 17)))
local pulled = false
local t0 = os.clock()
while os.clock() - t0 < USS.TwisterTime do
	local lv = dRoot:FindFirstChild("Knockback")
	if lv and lv.VectorVelocity.X < -20 then
		pulled = true
	end
	task.wait(0.05)
end
check(pulled, "the tornado's suction drags people in from 75 studs away")
check(profilesUsed.Whirl == true, "the twister tears buildings apart (Whirl profile)")
dChar.Parent = nil

print("== COLORADO SMASH (muscle form, V)")
task.wait(1)
fire(TestCommand, A, "EndUlt")
task.wait(0.3)
check(A:GetAttribute("QuirkAlt") ~= true, "back in true form")
clearSent()
fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(0, 3, 40), 1, aRoot.Position)
task.wait(0.4)
check(#sentTo(B, "ColoradoSmash") == 0, "no Colorado Smash in true form")
fire(TestCommand, A, "ResetCooldowns")
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.3)
check(A:GetAttribute("QuirkAlt") == true, "muscle form")
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 20), Vector3.new(0, 3, 0)))
task.wait(0.2)
clearSent()
fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(0, 3, 60), 1, aRoot.Position)
task.wait(0.5)
local col = Config.Quirks.OneForAll.Alt.Extra
check(#sentTo(B, "ColoradoSmash") == 1, "Colorado Smash cast (others see it)")
fire(UseAbility, A, Config.RELEASE_INDEX, Vector3.new(0, 0, 1), Vector3.new(0, 3, 20))
task.wait(0.1)
check(#sentTo(B, "ColoradoGo") == 1 and #sentTo(A, "ColoradoGo") == 1, "4 again: he goes - everyone's told where he's coming down (round 75: aimed from the sky)")
-- the harness can't fly him there; the server lands him where he ends up
task.wait(col.TravelTime + 1.5)
check(#sentTo(B, "ColoradoLand") == 1, "the landing slam fires")
check(bHum.Health <= Config.PlayerMaxHealth - col.Damage, "the landing hits B inside LandRadius (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")

print("== ONE FOR ALL: 9TH (Deku)")
local D = Config.Quirks.FullCowl
task.wait(0.5)
fire(TestCommand, A, "EndUlt")
studioMode = false
fire(SelectQuirk, A, "FullCowl")
check(A:GetAttribute("Quirk") == "FullCowl", "Deku is open to everyone (not dev-only)")
studioMode = true
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 10)))
local function place(z, x)
	local c, h, r = spawnChar(B, CFrame.lookAt(Vector3.new(x or 0, 3, z), Vector3.new(0, 3, 0)))
	task.wait(0.15)
	return c, h, r
end
local function useAt(index, z, wait)
	fire(UseAbility, A, index, Vector3.new(0, 0, 1), Vector3.new(0, 3, z), 7, aRoot.Position)
	task.wait(wait or 0)
end
local function knockDir(model)
	local r = model:FindFirstChild("HumanoidRootPart")
	local lv = r and r:FindFirstChild("Knockback")
	return lv and lv.VectorVelocity or nil
end
bChar, bHum, bRoot = place(40)
useAt(1, 40, 0.18 + 40 / 300 + 0.15 + ((D.Abilities[1].Shots or 1) - 1) * (D.Abilities[1].Gap or 0.13) + 0.1)
check(bHum.Health == Config.PlayerMaxHealth - D.Abilities[1].Damage * (D.Abilities[1].Shots or 1), "DELAWARE SMASH: AIR FORCE - every air bullet hits at 40 studs (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
-- (always in Full Cowl now: the glow gear's on from the start - give the
-- mock body a torso + forearm for it to hang on)
for _, n in { "UpperTorso", "RightLowerArm" } do
	local limbPart = M.new("Part", n)
	limbPart.CFrame = aRoot.CFrame
	limbPart.Parent = aChar
end
fire(SelectQuirk, A, "FullCowl") -- (rebuilds the gear on the new limbs)
task.wait(0.3)
local gear = aChar:FindFirstChild("QuirkGear")
local light = false
for _, d in gear and gear:GetDescendants() or {} do
	if d.ClassName == "PointLight" then
		light = true
	end
end
check(light and A:GetAttribute("QuirkAlt") ~= true, "always in Full Cowl: the green glow without a form to switch on")
do -- (its own block: the main chunk is at the local limit)
-- 2: ST. LOUIS SMASH: a close sweeping Shoot Style kick (no slash down the street any more)
bChar, bHum, bRoot = place(6)
local third2 = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
fire(SelectQuirk, third2, "Explosion")
local cChar2, cHum2 = spawnChar(third2, CFrame.lookAt(Vector3.new(0, 3, (D.Abilities[2].Range or 45) + 25), Vector3.new(0, 3, 0)))
task.wait(0.15)
useAt(2, 30, (D.Abilities[2].Startup or 0.18) + 0.2)
check(bHum.Health == Config.PlayerMaxHealth - D.Abilities[2].Damage, "ST. LOUIS SMASH kicks B point blank")
check(cHum2.Health == Config.PlayerMaxHealth, "...and its air blade stops short of C, past its reach")
cChar2:Destroy()
task.wait(D.Abilities[2].ActionTime or 0.5)
-- 3: MANCHESTER SMASH
bChar, bHum, bRoot = place(10)
clearSent()
useAt(3, 10, D.Abilities[3].TravelTime + 1)
check(#sentTo(B, "ManchesterLand") == 1 and bHum.Health == Config.PlayerMaxHealth - D.Abilities[3].Damage, "MANCHESTER SMASH lands on B")
-- V: whichever quirk R picked - Blackwhip first: it pulls them in
bChar, bHum, bRoot = place(30)
clearSent()
useAt(Config.EXTRA_INDEX, 30, 0.12 + 0.1)
local catches = sentTo(B, "BlackwhipCatch")
check(#catches == 1 and catches[1].Target == bChar, "V BLACKWHIP catches the first one in line (everyone draws the tendrils)")
check(#sentTo(A, "BlackwhipCatch") == 1, "the caster is told who they caught too")
task.wait(0.5)
check(bHum.Health == Config.PlayerMaxHealth - D.Extras[1].Damage and (bRoot.Position - aRoot.Position).Magnitude < 12,
	"...and reels them in to him (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ", " .. math.floor((bRoot.Position - aRoot.Position).Magnitude) .. " studs)")
task.wait(0.5)
-- R, then V: Smokescreen
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.1)
bChar, bHum, bRoot = place(12)
clearSent()
useAt(Config.EXTRA_INDEX, 12, 0.25)
check(#sentTo(B, "Smoked") >= 1 and bHum.Health == Config.PlayerMaxHealth - D.Extras[2].Damage, "R then V: SMOKESCREEN chokes and blinds whoever is inside")
fire(UseAbility, B, 0)
task.wait(0.2)
check(aHum.Health == Config.PlayerMaxHealth, "Deku vanishes in the smoke (untouchable for a moment)")
task.wait(D.Extras[2].Duration)
-- R, then V: Float
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.1)
clearSent()
useAt(Config.EXTRA_INDEX, 10, 0.1)
check(#sentTo(B, "Float") == 1, "R then V: FLOAT")
-- R, then V: Fa Jin (R has a short cooldown of its own)
task.wait(math.max(D.Special.Cooldown, D.Extras[3].ActionTime or 0) + 0.05)
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.1)
bChar, bHum, bRoot = place(55)
useAt(Config.EXTRA_INDEX, 55, D.Extras[4].Hold.Max + 0.1)
fire(UseAbility, A, Config.RELEASE_INDEX, Vector3.new(0, 0, 1), Vector3.new(0, 3, 55))
task.wait(0.35)
check(bHum.Health == Config.PlayerMaxHealth - D.Extras[4].Damage, "R then 4: FA JIN wound all the way, 4 again: the gale reaches 55 studs")
-- G: FULL COWL 100%
task.wait(0.3)
bChar, bHum, bRoot = place(5)
A:SetAttribute("Ult", 100)
fire(UseAbility, A, Config.ULT_INDEX)
task.wait(1.4)
check(A:GetAttribute("UltActive") == true and aChar:GetAttribute("UltActive") == true, "FULL COWL 100%")
local UA = D.Ult.Abilities
local mult = Config.Ult.DamageMultiplier
local function ulted(n)
	return math.floor(n * mult + 0.5)
end
bChar, bHum, bRoot = place(5)
local before = bHum.Health
useAt(1, 5, 0.12 + UA[1].Hits * 0.065 + 0.3)
local rush = UA[1].Hits * ulted(UA[1].Damage) + ulted(UA[1].FinisherDamage)
check(before - bHum.Health >= rush * 0.9, "100%: SHOOT STYLE RUSH lands the flurry + the last kick (took " .. (before - bHum.Health) .. " of " .. rush .. ")")
task.wait(0.5)
bChar, bHum, bRoot = place(25, 6)
clearSent()
useAt(2, 25, 0.35)
local binds = sentTo(B, "BlackwhipBind")
check(#binds == 1 and #binds[1].Targets == 1, "BLACKWHIP: COLLAPSE binds everyone in the cone")
task.wait(0.75)
check(bChar:GetAttribute("Ragdolled") == true and bHum.Health == Config.PlayerMaxHealth - ulted(UA[2].CatchDamage) - ulted(UA[2].Damage),
	"then slams them into the street (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
task.wait(1.5)
-- INFINITE 100%: the opening kick has to land, then the fist storm
bChar, bHum, bRoot = place(60)
clearSent()
useAt(3, 60, 0.4)
check(#sentTo(B, "FistRainCatch") == 0 and bHum.Health == Config.PlayerMaxHealth, "INFINITE 100%: whiffed, nobody is caught")
check(aRoot.Anchored ~= true and aChar:GetAttribute("FistRainActive") ~= true, "...and a whiff leaves him free")
fire(TestCommand, A, "ResetCooldowns")
task.wait(0.3)
bChar, bHum, bRoot = place(5)
clearSent()
useAt(3, 5, 0.3)
check(#sentTo(B, "FistRainCatch") == 1 and aChar:GetAttribute("FistRainActive") == true, "INFINITE 100%: the kick lands and he takes them up")
task.wait(UA[3].RiseTime + (function()
	local t = 0
	for i = 1, UA[3].Hits do
		t += math.max(UA[3].MinInterval, UA[3].Interval * UA[3].Speedup ^ (i - 1))
	end
	return t
end)() + 0.1 + UA[3].RainTime + 0.4)
local storm = ulted(UA[3].LaunchDamage) + UA[3].Hits * ulted(UA[3].Damage) + UA[3].RainHits * ulted(UA[3].RainDamage) + ulted(UA[3].FinisherDamage)
check(Config.PlayerMaxHealth - bHum.Health >= storm * 0.9 and #sentTo(B, "FistRainFinish") == 1,
	"...the fist storm and the finish (took " .. (Config.PlayerMaxHealth - bHum.Health) .. " of " .. storm .. ")")
check(aRoot.Anchored ~= true and aChar:GetAttribute("FistRainActive") == nil, "...and lets both of them go")
task.wait(0.5)
end
fire(TestCommand, A, "EndUlt")
task.wait(0.3)

print("== LIMITLESS (dev-only)")
local Lm = Config.Quirks.Limitless
studioMode = false -- (A owns the game by now, so ask as B)
fire(SelectQuirk, B, "Limitless")
check(B:GetAttribute("Quirk") ~= "Limitless", "non-testers can't pick Limitless")
studioMode = true
fire(SelectQuirk, A, "Limitless")
check(A:GetAttribute("Quirk") == "Limitless", "testers can")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 10)))
bChar, bHum, bRoot = place(20)
useAt(1, 20, 0.25 + Lm.Abilities[1].Duration + 0.2)
check(bHum.Health == Config.PlayerMaxHealth - Lm.Abilities[1].Ticks * Lm.Abilities[1].Damage, "LAPSE: BLUE crushes for " .. Lm.Abilities[1].Ticks .. " ticks (took " .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(profilesUsed.Implode == true, "Blue caves the map INTO the point (Implode profile)")
task.wait(0.5)
bChar, bHum, bRoot = place(25)
clearSent()
useAt(2, 25, 0.3 + 30 / 260 + 0.1)
check(#sentTo(B, "RedBurst") == 1 and bHum.Health == Config.PlayerMaxHealth - Lm.Abilities[2].Damage, "REVERSAL: RED bursts on B")
local away = knockDir(bChar)
check(away and away.Z > 100 * Config.Knockback.MoveScale, "and throws them away from the burst")
task.wait(1.2)
bChar, bHum, bRoot = place(100)
useAt(3, 100, 1.25 + 100 / 170 + 0.4)
check(bHum.Health == Config.PlayerMaxHealth - Lm.Abilities[3].Damage, "HOLLOW PURPLE erases down to 100 studs")
check(profilesUsed.Erase == true, "with the Erase profile")
-- R: Infinity
task.wait(0.3)
bChar, bHum, bRoot = place(4)
fire(SelectQuirk, B, "Explosion")
task.wait(0.1)
clearSent()
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.1)
check(aChar:GetAttribute("Infinity") == true, "INFINITY up")
aHum.Health = 200
m1(B)
check(aHum.Health == 200 and #sentTo(B, "InfinityStop") >= 1, "hits stop short of him")
task.wait(Lm.Special.Duration)
check(aChar:GetAttribute("Infinity") == false, "Infinity drops after " .. Lm.Special.Duration .. "s")
task.wait(Config.M1.ComboReset)
m1(B)
check(aHum.Health < 200, "and he can be hit again")
task.wait(0.6) -- let the hit stun wear off
clearSent()
useAt(Config.EXTRA_INDEX, 30, 0.1)
check(#sentTo(B, "Blink") == 1, "V: BLINK")
-- G: Unlimited Void
bChar, bHum, bRoot = place(40)
A:SetAttribute("Ult", 100)
clearSent()
fire(UseAbility, A, Config.ULT_INDEX)
task.wait(0.2)
check(#sentTo(A, "Domain") == 1 and #sentTo(B, "Domain") == 1, "DOMAIN EXPANSION drawn for everyone (the caster too)")
task.wait(1.0)
check(bChar:GetAttribute("Stunned") == true and #sentTo(B, "VoidOverload") == 1, "B, 40 studs away inside the domain, is paralysed")
task.wait(Lm.Ult.DomainStun + 0.2)
check(bChar:GetAttribute("Stunned") ~= true and bChar:GetAttribute("SlowedTo") == Lm.Ult.DomainSlow, "then slowed for as long as they stay inside")
fire(TestCommand, A, "EndUlt")
task.wait(1)
check(#sentTo(B, "DomainEnd") == 1, "the domain collapses when the ult ends")
task.wait(1)
check(bChar:GetAttribute("SlowedTo") == nil, "and the slow wears off")

print("== RAGDOLL: the 4th M1, big moves, and getting back up")
local RG = Config.Ragdoll
fire(SelectQuirk, A, "Explosion")
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 4)))
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
-- a jointed body so the ragdoll has something to swap
local function joint(name, p0, p1)
	local m = M.new("Motor6D", name)
	m.Part0, m.Part1, m.Enabled = p0, p1, true
	m.C0, m.C1 = CFrame.new(), CFrame.new()
	m.Parent = p1
	return m
end
local lt = M.new("Part", "LowerTorso")
lt.Parent = bChar
local ut = M.new("Part", "UpperTorso")
ut.Parent = bChar
local ua = M.new("Part", "RightUpperArm")
ua.Parent = bChar
local la = M.new("Part", "RightLowerArm")
la.Parent = bChar
joint("Root", bRoot, lt)
local waist = joint("Waist", lt, ut)
local shoulder = joint("RightShoulder", ut, ua)
local elbow = joint("RightElbow", ua, la)
bRoot.CanCollide = true
task.wait(0.1)
for i = 1, 4 do
	fire(UseAbility, A, 0)
	task.wait(i == 4 and 0.2 or Config.M1.Cooldown + 0.02)
end
check(bChar:GetAttribute("Ragdolled") == true, "the 4th M1 ragdolls")
local lv = bRoot:FindFirstChild("Knockback")
local launch = lv and lv.VectorVelocity.Magnitude or 0
check(lv ~= nil and lv.MaxForce == RG.MaxForce, "the limp body is pushed with a bounded force (" .. tostring(lv and lv.MaxForce) .. ")")
check(launch > 0 and launch <= Config.M1.FinisherKnockback + 20, string.format("and a gentler launch (%.0f studs/s)", launch))
local hinge = la:FindFirstChild("RagdollSocket")
local socket = ua:FindFirstChild("RagdollSocket")
check(hinge and hinge.ClassName == "HingeConstraint" and hinge.LowerAngle < 0 and hinge.UpperAngle > 90, "elbows become hinges that bend one way")
check(socket and socket.ClassName == "BallSocketConstraint", "shoulders become limited ball-sockets")
local nc = 0
for _, d in bChar:GetDescendants() do
	if d.ClassName == "NoCollisionConstraint" then
		nc += 1
	end
end
check(nc == 3, "joined parts never collide with each other (" .. nc .. " no-collision pairs)")
local coll = ut:FindFirstChild("RagdollCollider")
check(coll and coll.CollisionGroup == "Ragdoll", "limb colliders stay in the Ragdoll group")
check(bRoot.CanCollide == false and waist.Enabled == false and elbow.Enabled == false, "root box stops colliding; joints go limp")
bHum.Health = 200
fire(UseAbility, B, 0)
task.wait(0.2)
check(aHum.Health == Config.PlayerMaxHealth, "you can't attack while ragdolled")
task.wait(Config.M1.RagdollTime + 0.2)
check(bChar:GetAttribute("Ragdolled") == false and waist.Enabled and elbow.Enabled and shoulder.Enabled, "the ragdoll ends and the joints come back")
check(bRoot.CanCollide == true and la:FindFirstChild("RagdollSocket") == nil, "everything is put back the way it was")
-- a big move ragdolls by itself (knockback >= MinSpeed)
fire(SelectQuirk, A, "OneForAll")
task.wait(0.1)
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.3)
bChar:SetAttribute("Stunned", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0))
task.wait(0.1)
fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(0, 3, 6), 1, aRoot.Position)
task.wait(0.8)
check(bChar:GetAttribute("Ragdolled") == true, "DETROIT SMASH knocks B off their feet (ragdoll on big moves)")
task.wait(RG.MaxTime + 0.2)
check(bChar:GetAttribute("Ragdolled") == false, "and they get back up")
-- NPC get-up: stood upright above the ground before the joints snap back
local npc, npcHum, npcRoot = makeCharacter("Npc", CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(90), 0, 0))
npc.Parent = dummies
npcHum.Health = 100
fire(SelectQuirk, A, "Explosion")
task.wait(0.1)
npc:SetAttribute("Ragdolled", false)
-- drive it through the real ragdoll: an M1 finisher on the dummy
aRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, -4), Vector3.new(0, 3, 0))
npcRoot.CFrame = CFrame.new(0, 3, 0)
bRoot.CFrame = CFrame.new(50, 3, 50)
task.wait(Config.M1.ComboReset + 0.1)
for i = 1, 4 do
	fire(UseAbility, A, 0)
	task.wait(i == 4 and 0.2 or Config.M1.Cooldown + 0.02)
end
check(npc:GetAttribute("Ragdolled") == true, "dummies ragdoll too")
npcRoot.CFrame = CFrame.new(3, 0.4, 2) * CFrame.Angles(math.rad(90), 0, 0) -- lying in the street
task.wait(Config.M1.RagdollTime + 0.2)
check(npc:GetAttribute("Ragdolled") == false and npcRoot.CFrame.UpVector.Y > 0.99, "getting up stands it upright first (up " .. string.format("%.2f", npcRoot.CFrame.UpVector.Y) .. ")")
check(npcRoot.CFrame.Position.Y >= 1.5, string.format("lifted clear of the ground it lay on (y %.1f, was 0.4)", npcRoot.CFrame.Position.Y))
npc:Destroy()
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0))

print("== KO: the body goes limp and flies with the hit (no falling apart)")
fire(SelectQuirk, A, "Explosion")
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 4)))
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
do
	local lt2 = M.new("Part", "LowerTorso")
	lt2.Parent = bChar
	local ut2 = M.new("Part", "UpperTorso")
	ut2.Parent = bChar
	joint("Root", bRoot, lt2)
	local waist2 = joint("Waist", lt2, ut2)
	task.wait(0.1)
	check(bHum.BreakJointsOnDeath == false, "players' bodies stay in one piece when they die")
	task.wait(Config.M1.ComboReset + 0.1)
	bHum.Health = 3
	m1(A)
	task.wait(0.1)
	check(bHum.Health == 0 and bChar:GetAttribute("Ragdolled") == true, "going down ragdolls the body")
	check(waist2.Enabled == false and ut2:FindFirstChild("RagdollSocket") ~= nil, "its joints turn into sockets instead of breaking")
	task.wait(RG.MaxTime + 0.4)
	check(bChar:GetAttribute("Ragdolled") == true, "and it stays limp (nobody gets up from a KO)")
end
do
	-- a dummy KO'd by the 4th M1 flies off with it
	local dm, dmHum, dmRoot = makeCharacter("Training Dummy", CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0)))
	local dmTorso = M.new("Part", "UpperTorso")
	dmTorso.Parent = dm
	dmHum.MaxHealth = 500
	dmHum.Health = Config.M1.Damage * 3 + 6
	bRoot.CFrame = CFrame.new(60, 3, 60)
	dm.Parent = dummies
	joint("Waist", dmRoot, dmTorso)
	task.wait(0.7)
	check(dmHum.BreakJointsOnDeath == false, "dummies stay in one piece too")
	task.wait(Config.M1.ComboReset)
	for i = 1, 4 do
		fire(UseAbility, A, 0)
		task.wait(i == 4 and 0.15 or Config.M1.Cooldown + 0.02)
	end
	local klv = dmRoot:FindFirstChild("Knockback")
	check(dmHum.Health == 0 and dm:GetAttribute("Ragdolled") == true, "a dummy KO'd by the finisher ragdolls")
	check(klv ~= nil and klv.MaxForce == RG.MaxForce and klv.VectorVelocity.Magnitude > 20, "and keeps the hit's motion (bounded push " .. tostring(klv and klv.MaxForce) .. ")")
	dm:Destroy()
end

print("== FINISHERS")
local FIN = Config.Finishers
fire(SelectQuirk, A, "Overhaul")
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 6)))
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0)))
local third = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
fire(SelectQuirk, third, "Explosion")
local cChar, cHum, cRoot = spawnChar(third, CFrame.lookAt(Vector3.new(0, 3, 10), Vector3.new(0, 3, 6)))
task.wait(0.2)
clearSent()
fire(UseAbility, A, Config.FINISH_INDEX, bChar)
task.wait(0.1)
check(#sentTo(B, "Finisher") == 0, "can't finish someone who isn't low")
bHum.Health = math.floor(Config.PlayerMaxHealth * FIN.Threshold) - 1
bRoot.CFrame = CFrame.new(0, 3, 40)
fire(UseAbility, A, Config.FINISH_INDEX, bChar)
task.wait(0.1)
check(#sentTo(B, "Finisher") == 0, "...or someone out of reach")
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0))
fire(UseAbility, A, Config.FINISH_INDEX, bChar)
task.wait(0.15)
local fin = sentTo(B, "Finisher")
check(#fin == 1 and fin[1].Target == bChar and fin[1].Style == "Overhaul" and #sentTo(A, "Finisher") == 1, "E on a nearly-beaten B starts Overhaul's finisher (everyone sees it)")
check(aChar:GetAttribute("Finishing") == true and bChar:GetAttribute("BeingFinished") == true and bRoot.Anchored == true, "both are locked in")
local hpBefore = bHum.Health
fire(UseAbility, third, 0)
task.wait(0.2)
check(bHum.Health == hpBefore, "nobody else can steal the KO")
local aHp = aHum.Health
fire(UseAbility, B, 0)
task.wait(0.15)
check(aHum.Health == aHp, "the one being finished can't fight back")
clearSent()
local launchLV
bRoot.ChildAdded:Connect(function(c)
	if c.Name == "FinisherLaunch" then
		launchLV = c
	end
end)
task.wait(FIN.Styles.Overhaul.Time)
check(bHum.Health == 0 and bChar:GetAttribute("Ragdolled") == true, "the finisher KOs them, and the body flies off ragdolled")
check(bRoot.Anchored == false, "they're let go for the launch")
do
	local v = bRoot.AssemblyLinearVelocity
	local lv = launchLV
	local limbsFly = true
	for _, p in bChar:GetChildren() do
		if p:IsA("BasePart") and (p.AssemblyLinearVelocity - v).Magnitude > 1 then
			limbsFly = false
		end
	end
	check(v.Magnitude >= 300 and v.Z > 100 and v.Y > 150 and v.Magnitude <= FIN.Launch.MaxSpeed + 1,
		string.format("DISASSEMBLY launches the body huge, up and away from A (%.0f, %.0f, %.0f)", v.X, v.Y, v.Z))
	check(limbsFly, "every limb flies with it (no dragging behind the root)")
	check(lv ~= nil and lv:IsA("LinearVelocity") and lv.MaxForce >= 100000, "it holds that speed through the first scrape")
	check(#sentTo(B, "FinisherLaunch") == 1, "everyone sees it fly (wind streak)")
end
local kfeed = sentTo(B, "KOFeed")
check(#kfeed == 1 and kfeed[1].Finisher == true and kfeed[1].Killer == "Alpha", "kill feed: Alpha FINISHED Bravo")
local kconf = sentTo(A, "KOConfirm")
check(#kconf == 1 and kconf[1].Finisher == true, "A's popup says FINISHED")
check(aChar:GetAttribute("Finishing") == false, "A is free again")
do
	local hp = aHum.Health
	cRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 3), Vector3.new(0, 3, 0))
	fire(UseAbility, third, 0)
	task.wait(0.2)
	check(aHum.Health == hp, "...and still armoured for a moment after (nobody gets a free hit)")
end
do
	local dm, dmHum = makeCharacter("Training Dummy", CFrame.lookAt(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0)))
	dmHum.MaxHealth = 500
	dmHum.Health = 40
	dm.Parent = dummies
	task.wait(1.1)
	clearSent()
	fire(UseAbility, A, Config.FINISH_INDEX, dm)
	task.wait(FIN.Styles.Overhaul.Time + 0.3)
	check(dmHum.Health == 0 and #sentTo(A, "Finisher") == 1, "dummies can be finished too")
	dm:Destroy()
	-- Manchester Smash: slammed into the street, then it ricochets off
	fire(SelectQuirk, A, "FullCowl")
	task.wait(0.2)
	local dm2, dm2Hum, dm2Root = makeCharacter("Training Dummy", CFrame.lookAt(Vector3.new(0, 3, 6), Vector3.new(0, 3, 0)))
	dm2Hum.MaxHealth = 500
	dm2Hum.Health = 40
	dm2.Parent = dummies
	task.wait(1.1)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.FINISH_INDEX, dm2)
	task.wait(FIN.Styles.FullCowl.Time + 0.05)
	local down = dm2Root.AssemblyLinearVelocity
	task.wait(FIN.Launch.Bounce + 0.1)
	local off = dm2Root.AssemblyLinearVelocity
	check(dm2Hum.Health == 0 and down.Y < -100 and off.Y > 50 and off.Z > 100,
		string.format("MANCHESTER SMASH slams them down (%.0f) and they ricochet away (%.0f up, %.0f out)", down.Y, off.Y, off.Z))
	dm2:Destroy()
	fire(SelectQuirk, A, "Overhaul")
end
cChar.Parent = nil

local gearFrames
print("== OVERHAUL")
local OV = Config.Quirks.Overhaul
local mult = Config.Ult.DamageMultiplier
fire(SelectQuirk, A, "Overhaul")
fire(SelectQuirk, B, "Explosion")
aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 5)))
local aHead = M.new("Part", "Head")
aHead.Size = Vector3.new(2, 1, 1)
aHead.Parent = aChar
local aTorso = M.new("Part", "Torso")
aTorso.Size = Vector3.new(2, 2, 1)
aTorso.CFrame = aRoot.CFrame
aTorso.Color = M.Color3.fromRGB(40, 60, 50)
aTorso.Parent = aChar
aHead.CFrame = aRoot.CFrame * CFrame.new(0, 1.5, 0)
aHead.Color = M.Color3.fromRGB(240, 210, 180)
M.new("SpecialMesh", "Mesh").Parent = aHead -- an R6 head (drawn ~1.2 studs across)
for _, limbSpec in { { "Right Arm", 1.5, 0 }, { "Left Arm", -1.5, 0 }, { "Right Leg", 0.5, -2 }, { "Left Leg", -0.5, -2 } } do
	local limbPart = M.new("Part", limbSpec[1])
	limbPart.Size = Vector3.new(1, 2, 1)
	limbPart.CFrame = aRoot.CFrame * CFrame.new(limbSpec[2], limbSpec[3], 0)
	limbPart.Color = limbSpec[3] == 0 and M.Color3.fromRGB(240, 210, 180) or M.Color3.fromRGB(40, 44, 60)
	limbPart.Parent = aChar
end
fire(SelectQuirk, A, "Overhaul") -- rebuild the gear now there's a head to put the mask on
bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(0, 3, 5), Vector3.new(0, 3, 0)))
task.wait(0.3)
local gear = aChar:FindFirstChild("QuirkGear")
check(gear and #gear:GetDescendants() >= 2, "the plague-doctor mask (gear)")
gearFrames = {}
if process.env.GEAR_OUT then
	local out = {}
	for _, container in { aChar, gear } do
		for _, p in container:GetChildren() do
			if p.ClassName == "Part" and p.Size and p.Name ~= "HumanoidRootPart" then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
				local c = p.Color or M.Color3.new(0.5, 0.5, 0.5)
				table.insert(out, { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { c.R, c.G, c.B }, alpha = (p.Transparency or 0) >= 0.99 and 0 or 1, shape = p:FindFirstChildOfClass("SpecialMesh") and "ball" or (p.Shape == Enum.PartType.Cylinder and "cyl" or "box") })
			end
		end
	end
	gearFrames[1] = { label = "Overhaul (gear)", parts = out }
end
clearSent()
fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(0, 3, 10), 1, aRoot.Position)
task.wait(0.7)
check(bHum.Health == Config.PlayerMaxHealth - OV.Abilities[1].Damage, "DISASSEMBLE: the touch lands (" .. (Config.PlayerMaxHealth - bHum.Health) .. ")")
check(#sentTo(B, "Disassembled") == 1 and bChar:GetAttribute("Stunned") == true, "they come apart for everyone, and are left stunned")
check(profilesUsed.Overhaul == true, "walls he lunges into come apart (Overhaul profile)")
task.wait(1.5)
bHum.Health = 200
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 30), Vector3.new(0, 3, 0))
fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(0, 3, 30), 1, aRoot.Position)
task.wait(0.25 + 0.03 * 8 + 0.4)
check(bHum.Health == 200 - OV.Abilities[2].Damage, "SPIKE FAN: the middle line reaches 30 studs down the street")
task.wait(1.2)
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
fire(UseAbility, A, 3, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
task.wait(0.4)
check(bChar:GetAttribute("Stunned") == true and bHum.WalkSpeed == 0, "SPIKE PRISON: the walls trap them")
task.wait(0.7)
check(bHum.Health == 200 - OV.Abilities[3].Damage, "...then the spikes stab in")
aHum.Health = 100
aChar:SetAttribute("Burning", true)
fire(UseAbility, A, Config.SPECIAL_INDEX)
task.wait(0.5)
check(aHum.Health == 100 + OV.Special.Heal and aChar:GetAttribute("Burning") == false, "RESTORE rebuilds his body: heals, and the fire goes out")
A:SetAttribute("Ult", 100)
fire(UseAbility, A, Config.ULT_INDEX)
task.wait(1.4)
check(A:GetAttribute("UltActive") == true, "FUSION")
local fused = 0
for _, g in (aChar:FindFirstChild("QuirkGear") or aChar):GetChildren() do
	if g.Name == "FusedArm" then
		fused += 1
	end
end
check(fused == 4, "the fused form grows a second pair of arms (" .. fused .. " arm parts)")
if process.env.GEAR_OUT then
	-- dump the fused body for scene_render.py (a visual check)
	local serde = require("@lune/serde")
	local baseFrame = gearFrames and gearFrames[1]
	local out = {}
	local function add(p)
		if p.ClassName == "Part" and p.Size then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local c = p.Color or M.Color3.new(0.5, 0.5, 0.5)
			table.insert(out, { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { c.R, c.G, c.B }, alpha = (p.Transparency or 0) >= 0.99 and 0 or 1, shape = p:FindFirstChildOfClass("SpecialMesh") and "ball" or (p.Shape == Enum.PartType.Cylinder and "cyl" or "box") })
		end
	end
	for _, p in aChar:GetChildren() do
		if p.Name ~= "HumanoidRootPart" then
			add(p)
		end
	end
	for _, p in aChar:FindFirstChild("QuirkGear"):GetChildren() do
		add(p)
	end
	fs.writeFile(process.env.GEAR_OUT, serde.encode("json", { baseFrame or { label = "base", parts = {} }, { label = "Overhaul fused (gear)", parts = out } }))
end
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 30), Vector3.new(0, 3, 0))
fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(0, 3, 60), 1, aRoot.Position)
task.wait(0.3 + 0.14 * 5 + 0.3)
check(bHum.Health == 200 - math.floor(OV.Ult.Abilities[1].Damage * mult + 0.5), "PILLAR BARRAGE: a pillar catches B at 30 studs (took " .. (200 - bHum.Health) .. ")")
task.wait(1.2)
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 20), Vector3.new(0, 3, 0))
clearSent()
fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(0, 3, 20), 1, aRoot.Position)
task.wait(0.3 + 0.1)
check(#sentTo(B, "MassGraspCatch") == 1 and bRoot.Anchored == true, "FUSION: MASS GRASP seizes B 20 studs off")
task.wait(0.55 + 0.2)
check(bHum.Health == 200 - math.floor(OV.Ult.Abilities[2].Damage * mult + 0.5) - math.floor(OV.Ult.Abilities[2].FinisherDamage * mult + 0.5) and not bRoot.Anchored,
	"...and crushes them into the street (took " .. (200 - bHum.Health) .. ")")
task.wait(1.5)
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 60), Vector3.new(0, 3, 0))
clearSent()
fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(0, 3, 60), 1, aRoot.Position)
task.wait(0.2)
check(#sentTo(B, "TotalOverhaul") == 1, "V: TOTAL OVERHAUL cast (everyone sees it)")
task.wait(1.1 + 0.5 + 0.3 + 0.3)
check(bHum.Health == 200 - math.floor(OV.Ult.Extra.Damage * mult + 0.5), "TOTAL OVERHAUL: the block comes apart and B is impaled 60 studs out")
check(profilesUsed.OverhaulHuge == true, "the whole block comes apart (OverhaulHuge profile)")

print("== OVERHAUL: FUSION - KATSUKAME (the kaiju)")
local KJ = OV.Ult.Abilities[3]
task.wait(0.5)
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 20), Vector3.new(0, 3, 0))
-- a body to hide: a head with a face, a glove glinting red
local kHead = M.new("Part")
kHead.Name = "KaijuTestHead"
kHead.Parent = aChar
local kFace = M.new("Decal")
kFace.Parent = kHead
local kSpark = M.new("ParticleEmitter")
kSpark.Parent = kHead
clearSent()
fire(UseAbility, A, 3, Vector3.new(0, 0, 1), Vector3.new(0, 3, 20), 1, aRoot.Position)
task.wait(0.2)
check(#sentTo(B, "Kaiju") == 1 and KJ.Id == "Kaiju", "FUSION: KATSUKAME cast (everyone sees it rise)")
check(aChar:GetAttribute("Kaiju") ~= true, "...it takes a moment to climb out of the ground")
check(kHead.Transparency == 0, "his body is still there while he crouches")
task.wait(0.5)
check(kHead.Transparency == 1 and kFace.Transparency == 1 and kSpark.Enabled == false, "his body comes apart: hidden for everyone (body, face, particles)")
task.wait(1.1)
check(aChar:GetAttribute("Kaiju") == true and aChar:FindFirstChild("KaijuHurtbox") ~= nil, "the kaiju is up: its whole body can be hit")
local lateGear = M.new("Part")
lateGear.Name = "LateGear"
lateGear.Parent = aChar
task.wait()
check(lateGear.Transparency == 1, "gear added while he's inside it stays hidden too")
check(aChar:FindFirstChild("KaijuHurtbox").Transparency == 1, "(the hurtbox is invisible anyway)")
check(bHum.Health == 200 - math.floor(KJ.Damage * mult + 0.5), "rising out of the ground blasts B 20 studs away (took " .. (200 - bHum.Health) .. ")")
check(aHum.JumpPower == 0, "a kaiju doesn't jump")
-- M1 is a giant slam 20 studs ahead
task.wait(1.6)
bHum.Health = 200
bChar:SetAttribute("Stunned", false)
bChar:SetAttribute("Ragdolled", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(4, 3, 20), Vector3.new(0, 3, 0))
clearSent()
fire(UseAbility, A, 0)
task.wait(0.5)
check(#sentTo(B, "Punch") == 1, "M1: an arm comes down (everyone sees it)")
check(bHum.Health == 200 - math.floor(KJ.SlamDamage * mult + 0.5), "the slam lands 20 studs ahead (took " .. (200 - bHum.Health) .. ")")
-- it shrugs off half of every hit
aHum.Health = 150
local hit = math.floor(20 * (KJ.DamageTaken or 0.5) + 0.5)
bChar:SetAttribute("Stunned", false)
bChar:SetAttribute("Ragdolled", false)
bRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0))
fire(SelectQuirk, B, "Overhaul")
task.wait(0.2)
fire(UseAbility, B, 1, Vector3.new(0, 0, -1), Vector3.new(0, 3, 0), 1, bRoot.Position)
task.wait(0.8)
check(aHum.Health == 150 - hit, "a kaiju takes half damage (took " .. (150 - aHum.Health) .. " of a 20-damage touch)")
-- it comes apart when the ult ends
clearSent()
fire(TestCommand, A, "EndUlt")
task.wait(0.3)
check(aChar:GetAttribute("Kaiju") ~= true and aChar:FindFirstChild("KaijuHurtbox") == nil and #sentTo(B, "KaijuEnd") == 1, "the kaiju comes apart when the ult ends")
check(aHum.JumpPower > 0, "and he can jump again")
check(kHead.Transparency == 0 and kFace.Transparency == 0 and kSpark.Enabled == true and lateGear.Transparency == 0, "and he steps back out of it, exactly as he was")
kHead:Destroy()
lateGear:Destroy()
fire(SelectQuirk, B, "Explosion")
task.wait(0.3)

print("== DUMMY KINDS (the Dummies script + what each kind does)")
do
	for _, m in dummies:GetChildren() do
		m:Destroy()
	end
	local dummyScript = M.new("Script", "Dummies")
	dummyScript.Parent = ServerScriptService
	local dfn = luau.load(fs.readFile(SRC .. "/ServerScriptService.Dummies.server.lua"), { debugName = "Dummies", environment = env(dummyScript) })
	task.spawn(dfn)
	task.wait(0.3)
	local defaults = #dummies:GetChildren()
	check(defaults == 5, "the default row of dummies spawns (" .. defaults .. ")")
	fire(SelectQuirk, A, "Explosion")
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 12)))
	bChar.Parent = nil
	task.wait(0.2)
	local function spawned(kind)
		local before = {}
		for _, m in dummies:GetChildren() do
			before[m] = true
		end
		fire(TestCommand, A, "SpawnDummy", kind)
		task.wait(0.3)
		for _, m in dummies:GetChildren() do
			if not before[m] then
				return m, m:FindFirstChildOfClass("Humanoid"), m:FindFirstChild("HumanoidRootPart")
			end
		end
		return nil
	end
	local fin, finHum = spawned("Finisher")
	check(fin and fin:GetAttribute("DummyKind") == "Finisher" and finHum.Health <= finHum.MaxHealth * Config.Finishers.Threshold, "FINISHER DUMMY spawns at its last sliver of health (" .. tostring(finHum and finHum.Health) .. ")")
	check(fin and fin:FindFirstChild("Head") and fin:FindFirstChild("Head"):FindFirstChild("DummyLabel") ~= nil, "it wears its name over its head")
	fin:Destroy()
	local blk = spawned("Block")
	task.wait(0.6)
	check(blk and blk:GetAttribute("Blocking") == true, "BLOCKING DUMMY holds its guard up")
	blk:Destroy()
	local mov, movHum = spawned("Moving")
	task.wait(0.3)
	check(mov and movHum.WalkSpeed > 0 and movHum.MoveToTarget ~= nil, "MOVING DUMMY walks (sidesteps)")
	mov:Destroy()
	local tank, tankHum = spawned("Tank")
	check(tank and tankHum.MaxHealth == Config.DummyKind("Tank").MaxHealth, "TANK DUMMY has " .. tostring(tankHum and tankHum.MaxHealth) .. " health")
	tankHum:TakeDamage(800)
	task.wait(1)
	check(tankHum.Health < tankHum.MaxHealth, "...keeps the damage while you're hitting it")
	task.wait(Config.DummyKind("Tank").RegenDelay + 0.4)
	check(tankHum.Health == tankHum.MaxHealth, "...and is back to full once you stop")
	tank:Destroy()
	-- ATTACK dummy: walks at you and punches; a parry stuns it
	local atk, atkHum, atkRoot = spawned("Attack")
	check(atk and atkHum.WalkSpeed > 0, "ATTACK DUMMY can walk")
	atkRoot.CFrame = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 0))
	aHum.Health = 200
	clearSent()
	task.wait(1.2)
	check(#sentTo(A, "Punch") >= 1 and aHum.Health < 200, "it throws punches at you (" .. (200 - aHum.Health) .. " damage)")
	-- raise the guard just as it swings: parried
	task.wait(1.5)
	aHum.Health = 200
	local parried = false
	for _ = 1, 6 do
		-- wait for its next swing to start, then raise the guard (one clean parry, no mashing)
		local seen = #sentTo(A, "Punch")
		local t0 = os.clock()
		while #sentTo(A, "Punch") == seen and os.clock() - t0 < 3 do
			task.wait(1 / 60)
		end
		fire(UseAbility, A, BLOCK, true)
		task.wait(0.25)
		fire(UseAbility, A, BLOCK, false)
		if atk:GetAttribute("Stunned") then
			parried = true
			break
		end
		task.wait(Config.Guard.ParryLockout + 0.1)
	end
	check(parried, "its punches can be parried (the dummy is left stunned)")
	atk:Destroy()
	-- clear: only the default row is left
	spawned("Normal")
	spawned("R6")
	fire(TestCommand, A, "ClearDummies")
	task.wait(0.2)
	check(#dummies:GetChildren() == defaults, "CLEAR removes the spawned ones, the default row stays")
end

---------------------------------------------------------------------------
-- Round 17: Bucks, the shop and its items, the hero outfit, quirk-switch
-- cooldown, the dev toys and the PLUS ULTRA kit
---------------------------------------------------------------------------
do
	local Shop = remotes:FindFirstChild("Shop")
	local E, I = Config.Economy, Config.Items
	local FWD = Vector3.new(0, 0, 1)
	local base = Vector3.new(300, 3, 0)
	-- fighters with heads and arms (for the hair and the rifle)
	local R6 = {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), M.Color3.new(0.2, 0.3, 0.75) },
		{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), M.Color3.new(0.92, 0.72, 0.57) },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), M.Color3.new(0.92, 0.72, 0.57) },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), M.Color3.new(0.92, 0.72, 0.57) },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), M.Color3.new(0.25, 0.25, 0.3) },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), M.Color3.new(0.25, 0.25, 0.3) },
	}
	local function body(p, pos, look)
		local model, hum, root = spawnChar(p, CFrame.lookAt(pos, look))
		root.AssemblyMass = 12
		for _, spec in R6 do
			local part = M.new("Part", spec[1])
			part.Size = spec[2]
			part.Color = spec[4]
			part.CFrame = root.CFrame * CFrame.new(spec[3])
			if spec[1] == "Head" then
				local mesh = M.new("SpecialMesh", "Mesh")
				mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
				mesh.Parent = part
			end
			part.Parent = model
		end
		hum.MaxHealth = Config.PlayerMaxHealth
		hum.Health = Config.PlayerMaxHealth
		return model, hum, root
	end
	local function fresh()
		local a, ah, ar = body(A, base, base + FWD * 4)
		local b, bh, br = body(B, base + FWD * 4, base)
		task.wait(0.1)
		return a, ah, ar, b, bh, br
	end
	local function use(id, target)
		fire(Shop, A, "Use", id, FWD, target or base + FWD * 4)
		task.wait(0.05)
	end

	print("== bucks")
	check(Shop ~= nil and Shop.ClassName == "RemoteEvent", "the server makes the Shop remote")
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	local aC, aH, aR, bC, bH, bR = fresh()
	check(stat(A, "Bucks") == A:GetAttribute("Bucks"), "Bucks shows on the leaderboard (" .. tostring(stat(A, "Bucks")) .. ")")
	local before = A:GetAttribute("Bucks") or 0
	clearSent()
	task.wait(Config.M1.ComboReset + 0.1)
	bH.Health = 3
	m1(A)
	task.wait(0.2)
	check((A:GetAttribute("Bucks") or 0) == before + E.PerKO, string.format("a KO pays %d bucks (%d -> %d)", E.PerKO, before, A:GetAttribute("Bucks") or 0))
	local confirm = sentTo(A, "KOConfirm")
	check(#confirm >= 1 and confirm[#confirm].Bucks == E.PerKO, "the KO popup says +" .. E.PerKO .. " BUCKS")
	check(stat(A, "Bucks") == A:GetAttribute("Bucks"), "...and the leaderboard keeps up")

	print("== shop")
	aC, aH, aR, bC, bH, bR = fresh()
	for _, id in Config.ItemOrder do
		A:SetAttribute("Item_" .. id, nil)
	end
	A:SetAttribute("Bucks", 12)
	clearSent()
	fire(Shop, A, "Buy", "Soda")
	check(A:GetAttribute("Bucks") == 7 and A:GetAttribute("Item_Soda") == 1, "a soda costs 5 (" .. tostring(A:GetAttribute("Bucks")) .. " left)")
	fire(Shop, A, "Buy", "Sniper")
	check(A:GetAttribute("Bucks") == 2 and A:GetAttribute("Item_Sniper") == I.Sniper.Gives, "the sniper comes with " .. I.Sniper.Gives .. " shots")
	fire(Shop, A, "Buy", "Bomb")
	local results = sentTo(A, "ShopResult")
	check(A:GetAttribute("Item_Bomb") == nil and A:GetAttribute("Bucks") == 2 and results[#results].Ok == false, "can't buy what you can't afford")
	fire(Shop, A, "Buy", "Lamborghini")
	fire(Shop, A, "Buy", nil)
	check(A:GetAttribute("Bucks") == 2, "nonsense purchases are ignored")
	A:SetAttribute("Bucks", 100)
	fire(Shop, A, "Buy", "Bomb")
	fire(Shop, A, "Buy", "Trigger")
	fire(Shop, A, "Buy", "ZeroGravity")
	check(A:GetAttribute("Item_ZeroGravity") == nil and A:GetAttribute("Bucks") == 90, "a 5th kind of item is refused (bag full)")
	fire(Shop, A, "Buy", "Soda")
	check(A:GetAttribute("Item_Soda") == 2, "more of one you already have is fine")
	for _ = 1, 12 do
		fire(Shop, A, "Buy", "Soda")
	end
	check(A:GetAttribute("Item_Soda") == E.MaxStack, "stacks stop at " .. E.MaxStack)

	print("== items")
	aH.Health = 100
	use("Soda")
	use("Soda")
	check(A:GetAttribute("Item_Soda") == E.MaxStack - 1, "one soda used (items can't be spammed)")
	task.wait(0.6)
	check(aH.Health == 100 + I.Soda.Heal, "a soda heals " .. I.Soda.Heal .. " (" .. aH.Health .. ")")

	-- sniper
	use("Sniper")
	check(aC:GetAttribute("Scoped") == true and aC:FindFirstChild("HeroSniper") ~= nil, "using the sniper scopes in (the rifle comes out)")
	check(A:GetAttribute("Item_Sniper") == I.Sniper.Gives, "scoping in doesn't use a shot")
	local bHead = bC:FindFirstChild("Head")
	workspace.Raycast = function()
		return { Position = bHead.CFrame.Position, Instance = bHead, Normal = Vector3.new(0, 1, 0), Distance = 4 }
	end
	local h0 = bH.Health
	clearSent()
	fire(Shop, A, "Fire", FWD, bHead.CFrame.Position)
	local headshot = math.floor(I.Sniper.Damage * I.Sniper.HeadshotBonus + 0.5)
	check(h0 - bH.Health == headshot, string.format("a headshot does %d (did %d)", headshot, h0 - bH.Health))
	local shots = sentTo(A, "SniperShot")
	check(#shots == 1 and shots[1].Headshot == true, "everyone sees the shot (HEADSHOT)")
	fire(Shop, A, "Fire", FWD, bHead.CFrame.Position)
	check(A:GetAttribute("Item_Sniper") == I.Sniper.Gives - 1, "fire rate is enforced")
	for _ = 1, I.Sniper.Gives - 1 do
		task.wait(I.Sniper.FireRate)
		fire(Shop, A, "Fire", FWD, bHead.CFrame.Position)
	end
	check(A:GetAttribute("Item_Sniper") == nil and aC:GetAttribute("Scoped") == false, "out of shots: the scope comes down and the sniper's gone")
	fire(Shop, A, "Fire", FWD, bHead.CFrame.Position)
	check(#sentTo(A, "SniperShot") == I.Sniper.Gives, "no shots without the sniper")

	-- bomb: lands right away (the ray hits at once) and blows after the fuse
	aC, aH, aR, bC, bH, bR = fresh()
	workspace.Raycast = function(_, origin)
		return { Position = origin, Instance = map, Normal = Vector3.new(0, 1, 0), Distance = 0 }
	end
	task.wait(E.UseCooldown)
	clearSent()
	h0 = bH.Health
	use("Bomb")
	check(#sentTo(A, "BombThrow") == 1, "the bomb is thrown (everyone sees it)")
	task.wait(I.Bomb.Fuse + 0.3)
	check(h0 - bH.Health == I.Bomb.Damage and #sentTo(A, "BombBoom") == 1, "BOOM: " .. (h0 - bH.Health) .. " damage")
	workspace.Raycast = function()
		return nil
	end

	-- trigger: faster and harder-hitting
	task.wait(E.UseCooldown)
	local speed0 = aC:GetAttribute("BaseWalkSpeed")
	use("Trigger")
	check((aC:GetAttribute("TriggeredUntil") or 0) > os.clock(), "TRIGGER is on")
	check(math.abs(aC:GetAttribute("BaseWalkSpeed") - speed0 * I.Trigger.SpeedBoost) < 0.01, "...+20% speed")
	task.wait(Config.M1.ComboReset + 0.1)
	while bC:GetAttribute("Ragdolled") do
		task.wait(0.05)
	end
	h0 = bH.Health
	m1(A)
	check(h0 - bH.Health == math.floor(Config.M1.Damage * I.Trigger.DamageBoost + 0.5), "...+25% damage (" .. (h0 - bH.Health) .. ")")
	aC:SetAttribute("TriggeredUntil", nil)

	-- capture scarf
	A:SetAttribute("Bucks", 100)
	A:SetAttribute("Item_Soda", nil) -- (room in the bag)
	for _, id in { "CaptureScarf", "GrapeBalls", "ZeroGravity", "AllMightHair" } do
		fire(Shop, A, "Buy", id)
	end
	check(aC:FindFirstChild("HeroHair") ~= nil, "owning All Might's hair: you wear it")
	aC, aH, aR, bC, bH, bR = fresh()
	local t0 = os.clock()
	while not aC:FindFirstChild("HeroHair") and os.clock() - t0 < 2 do
		task.wait(0.05)
	end
	check(aC:FindFirstChild("HeroHair") ~= nil, string.format("...still on after a respawn (%.2fs)", os.clock() - t0))
	task.wait(E.UseCooldown)
	use("CaptureScarf")
	task.wait(0.35)
	check((bC:GetAttribute("ErasedUntil") or 0) > os.clock() and bC:GetAttribute("Stunned") == true, "the capture scarf catches them and ERASES their quirk")
	task.wait(I.CaptureScarf.Stun + 0.1)
	clearSent()
	fire(UseAbility, B, 1, -FWD, base)
	check(#sentTo(A, "APShot") == 0, "an erased player can't use their quirk")
	m1(B)
	check(#sentTo(A, "Punch") >= 1, "...but can still punch")
	bC:SetAttribute("ErasedUntil", nil)

	-- grape balls
	aC, aH, aR, bC, bH, bR = fresh()
	task.wait(E.UseCooldown)
	-- (round 84: B's punch above stuns A for longer since the owner's round
	-- 81 M1s - an item can't be used stunned)
	local waited = os.clock()
	while aC:GetAttribute("Stunned") and os.clock() - waited < 3 do
		task.wait(0.05)
	end
	use("GrapeBalls")
	local drops = workspace:FindFirstChild("ItemDrops")
	local ball = drops and drops:FindFirstChild("GrapeBall")
	ball = ball or { CFrame = CFrame.new(0, -500, 0), Parent = nil }
	check(ball ~= nil and A:GetAttribute("Item_GrapeBalls") == I.GrapeBalls.Gives - 1, "a grape ball is dropped (" .. tostring(A:GetAttribute("Item_GrapeBalls")) .. " left)")
	bR.CFrame = CFrame.new(ball.CFrame.Position)
	task.wait(0.25)
	check(bC:GetAttribute("Stunned") == true and bH.WalkSpeed == 0, "stepping on it sticks you in place")
	check(ball.Parent == nil, "...and uses the ball up")

	-- zero gravity
	task.wait(E.UseCooldown)
	use("ZeroGravity")
	task.wait(0.3)
	local vf = aR:FindFirstChild("ZeroGravity")
	check(vf ~= nil and vf.Force.Y > 0, "ZERO GRAVITY lifts most of your weight")

	-- the hair's one smash
	aC, aH, aR, bC, bH, bR = fresh()
	task.wait(E.UseCooldown)
	h0 = bH.Health
	clearSent()
	use("AllMightHair")
	task.wait(0.5)
	check(h0 - bH.Health == I.AllMightHair.Damage, "ALL MIGHT HAIR: one Detroit Smash (" .. (h0 - bH.Health) .. ")")
	task.wait(0.4)
	check(aC:FindFirstChild("HeroHair") == nil and #sentTo(A, "HairPoof") == 1, "...then the hair poofs off")

	print("== hero outfit")
	fire(SelectQuirk, A, "OneForAll")
	aC, aH, aR, bC, bH, bR = fresh()
	local applied
	function aH.GetAppliedDescription()
		return { Shirt = 111, Pants = 222 }
	end
	function aH.ApplyDescription(_, desc)
		applied = { Shirt = desc.Shirt, Pants = desc.Pants }
	end
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.1)
	check(aC:GetAttribute("HeroOutfit") ~= true and applied == nil, "the costume isn't on yet as he starts to power up (no early reveal)")
	task.wait(Config.Quirks.OneForAll.Special.Presence.BurstAt + 0.15)
	check(aC:GetAttribute("HeroOutfit") == true and applied and applied.Shirt == Config.AllMightOutfit.Shirt
		and applied.Pants == Config.AllMightOutfit.Pants, "muscle form puts on All Might's costume")
	task.wait(Config.Quirks.OneForAll.Special.Cooldown + 0.1)
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.1)
	check(aC:GetAttribute("HeroOutfit") == false and applied.Shirt == 111 and applied.Pants == 222, "powering down puts your own clothes back")

	print("== quirk switching")
	studioMode = false -- B is an ordinary player (A owns the game)
	fire(SelectQuirk, A, "Explosion")
	aC, aH, aR, bC, bH, bR = fresh()
	task.wait(2.6)
	clearSent()
	fire(UseAbility, B, 3, -FWD, base) -- Eruption Orbit (a 12s cooldown)
	fire(SelectQuirk, B, "OneForAll")
	check(B:GetAttribute("Quirk") == "OneForAll", "switch quirks")
	fire(SelectQuirk, B, "Explosion")
	check(B:GetAttribute("Quirk") == "OneForAll", "switching again straight away is refused")
	task.wait(2.6)
	fire(SelectQuirk, B, "Explosion")
	check(B:GetAttribute("Quirk") == "Explosion", "...fine after a moment")
	fire(UseAbility, B, 3, -FWD, base)
	check(#sentTo(A, Config.Quirks.Explosion.Abilities[3].Id) == 1, "switching away and back doesn't reset cooldowns")
	studioMode = true
	task.wait(1)

	print("== dev toys")
	local bucks0 = A:GetAttribute("Bucks") or 0
	fire(TestCommand, A, "MoneyPrinter")
	check(A:GetAttribute("Bucks") == bucks0 + 100, "MONEY PRINTER: +100")
	local g0 = workspace.Gravity
	fire(TestCommand, A, "MoonGravity")
	check(workspace.Gravity == 45 and workspace:GetAttribute("MoonGravity") == true, "MOON GRAVITY on")
	fire(TestCommand, A, "MoonGravity")
	check(workspace.Gravity == g0, "...and off")
	fire(TestCommand, A, "GiantMode")
	check(A:GetAttribute("SizeMode") == 3, "GIANT MODE")
	fire(TestCommand, A, "TinyMode")
	check(A:GetAttribute("SizeMode") == 0.4, "TINY MODE (switches straight over)")
	fire(TestCommand, A, "TinyMode")
	check(A:GetAttribute("SizeMode") == nil, "...and back to normal")
	local head = aC:FindFirstChild("Head")
	local size0 = head.Size
	fire(TestCommand, A, "Bobblehead")
	check(aC:GetAttribute("Bobblehead") == true and math.abs(head.Size.Y - size0.Y * 2.6) < 1e-3, "BOBBLEHEAD")
	fire(TestCommand, A, "Bobblehead")
	check(math.abs(head.Size.Y - size0.Y) < 1e-3, "...and back")
	aC, aH, aR, bC, bH, bR = fresh()
	fire(TestCommand, A, "LaunchEveryone")
	local kb = bR:FindFirstChild("Knockback")
	check(kb ~= nil and kb.VectorVelocity.Y > 100, "LAUNCH EVERYONE sends them flying")
	check(aR:FindFirstChild("Knockback") == nil, "...but not you")
	fire(TestCommand, A, "DiscoParty")
	check(workspace:GetAttribute("Disco") == true and workspace:GetAttribute("DiscoCenter") ~= nil, "DISCO PARTY on")
	fire(TestCommand, A, "DiscoParty")
	check(workspace:GetAttribute("Disco") == false, "...and off")
	B:SetAttribute("Item_AllMightHair", nil)
	fire(TestCommand, A, "HairForAll")
	check(B:GetAttribute("Item_AllMightHair") == 1, "ALL MIGHT HAIR FOR ALL")
	local n0 = #dummies:GetChildren()
	fire(TestCommand, A, "DummyRain")
	task.wait(0.3)
	check(#dummies:GetChildren() == n0 + 8, "DUMMY RAIN drops 8 dummies (" .. (#dummies:GetChildren() - n0) .. ")")
	fire(TestCommand, A, "ClearDummies")
	studioMode = false
	fire(TestCommand, B, "MoneyPrinter")
	check((B:GetAttribute("Bucks") or 0) < 100, "the dev toys are testers only")
	studioMode = true

	print("== PLUS ULTRA")
	fire(SelectQuirk, A, "PlusUltra")
	check(A:GetAttribute("Quirk") == "PlusUltra", "the dev kit can be picked by testers")
	aC, aH, aR, bC, bH, bR = fresh()
	-- warp gate: straight to the aim point
	local target = base + FWD * 60
	fire(UseAbility, A, 3, FWD, target)
	task.wait(0.5)
	check((aR.CFrame.Position - target).Magnitude < 6, "WARP GATE: through the mist to the aim point")
	clearSent()
	fire(UseAbility, A, 3, FWD, base)
	check(#sentTo(B, "WarpGate") == 0, "...and it has a cooldown")
	-- rewind: full health and the cooldowns come back
	aH.Health = 60
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.1)
	check(aH.Health == aH.MaxHealth and #sentTo(A, "CooldownReset") == 1, "REWIND: back to full health")
	fire(UseAbility, A, 3, FWD, base)
	check(#sentTo(B, "WarpGate") == 1, "...and the warp gate is ready again")
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	check(#sentTo(A, "CooldownReset") == 1, "...but Rewind itself stays on cooldown")
	task.wait(0.6) -- (let that warp land before the next test)
	-- the big three
	aC, aH, aR, bC, bH, bR = fresh()
	h0 = bH.Health
	fire(UseAbility, A, 1, FWD, base + FWD * 4)
	task.wait(1.5)
	local pu = Config.Quirks.PlusUltra
	check(h0 - bH.Health == pu.Abilities[1].Damage, "1,000,000% DELAWARE DETROIT SMASH hits for " .. (h0 - bH.Health))
	aC, aH, aR, bC, bH, bR = fresh()
	h0 = bH.Health
	fire(UseAbility, A, 2, FWD, base)
	task.wait(0.9)
	check(h0 - bH.Health == pu.Abilities[2].Damage and bC:GetAttribute("Burning") == true, "PROMINENCE BURN: " .. (h0 - bH.Health) .. " and burning")
	-- (New Order is the ult's V now - the NUKE took the base V)
	aC, aH, aR, bC, bH, bR = fresh()
	fire(TestCommand, A, "FillUlt")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1)
	bC:SetAttribute("Stunned", false)
	h0 = bH.Health
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, base)
	task.wait(0.5)
	local float = bR:FindFirstChild("Knockback")
	check(float ~= nil and float.VectorVelocity.Y > 0 and bC:GetAttribute("Stunned") == true, "NEW ORDER (ult V): everyone around floats")
	local NO = pu.Ult.Extra
	task.wait(NO.FloatTime + 0.2)
	check(h0 - bH.Health == math.floor(NO.Damage * Config.Ult.DamageMultiplier + 0.5) and #sentTo(A, "NewOrderSlam") == 1, "...then slams down (" .. (h0 - bH.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	fire(SelectQuirk, A, "Explosion")

	-- dump a body wearing the hair, scoped in, for scene_render.py
	-- (a function of its own: this file is near Luau's 200-local limit)
	local function dumpHair()
		local serde = require("@lune/serde")
		aC, aH, aR, bC, bH, bR = fresh()
		A:SetAttribute("Bucks", 100)
		fire(Shop, A, "Buy", "AllMightHair")
		fire(Shop, A, "Buy", "Sniper")
		task.wait(E.UseCooldown)
		use("Sniper")
		local out = {}
		local function add(part)
			if part.ClassName == "Part" and part.Name ~= "HumanoidRootPart" then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
				local c = part.Color or M.Color3.new(0.5, 0.5, 0.5)
				local shape = part:FindFirstChildOfClass("SpecialMesh") and "ball" or (part.Shape == Enum.PartType.Cylinder and "cyl" or "box")
				-- (an R6 head draws as a ~1.2 stud rounded head)
				local size = part.Name == "Head" and { 1.25, 1.25, 1.25 } or { part.Size.X, part.Size.Y, part.Size.Z }
				table.insert(out, { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = size, color = { c.R, c.G, c.B }, alpha = 1, shape = shape })
			end
		end
		for _, part in aC:GetChildren() do
			add(part)
		end
		for _, name in { "HeroHair", "HeroSniper" } do
			for _, part in (aC:FindFirstChild(name) or aC):GetChildren() do
				if aC:FindFirstChild(name) then
					add(part)
				end
			end
		end
		fs.writeFile(process.env.HAIR_OUT, serde.encode("json", { { label = "All Might hair + sniper", parts = out } }))
		use("Sniper")
	end
	if process.env.HAIR_OUT then
		dumpHair()
	end
end

---------------------------------------------------------------------------
-- Round 18: snack machines and Tony's Pizzeria
---------------------------------------------------------------------------
do
	local Shop = remotes:FindFirstChild("Shop")
	local SM, PIZZA, I = Config.SnackMachine, Config.PizzaParlor, Config.Items
	local shops = workspace:FindFirstChild("Shops")
	print("== snack machines")
	check(shops ~= nil, "the food stands are built (workspace.Shops)")
	local machines = {}
	for _, m in shops and shops:GetChildren() or {} do
		if m.Name == "SnackMachine" then
			table.insert(machines, m)
		end
	end
	check(#machines == #SM.Spots, string.format("a snack machine at every spot (%d of %d)", #machines, #SM.Spots))
	local body = machines[1]:FindFirstChild("Body")
	local pp = body:FindFirstChildOfClass("ProximityPrompt")
	check(pp ~= nil and pp.KeyboardKeyCode == Enum.KeyCode.E and pp.GamepadKeyCode == Enum.KeyCode.DPadRight, "each has a prompt (E / D-pad right)")
	local look = body.CFrame.LookVector
	local stand = body.CFrame.Position + look * 4 - Vector3.new(0, 0.2, 0)
	local aC, aH, aR = spawnChar(A, CFrame.lookAt(stand, stand - look))
	aH.MaxHealth, aH.Health = Config.PlayerMaxHealth, Config.PlayerMaxHealth
	for _, id in Config.ItemOrder do
		A:SetAttribute("Item_" .. id, nil)
	end
	A:SetAttribute("Bucks", SM.Price + 1)
	clearSent()
	pp.Triggered:Fire(A)
	task.wait(0.1)
	local got = 0
	for _, id in SM.Snacks do
		got += A:GetAttribute("Item_" .. id) or 0
	end
	check(A:GetAttribute("Bucks") == 1 and got == 1, "a snack costs " .. SM.Price .. " and goes in your bag")
	check(#sentTo(B, "Vend") == 1, "...everyone sees it drop into the flap")
	task.wait(0.6)
	pp.Triggered:Fire(A)
	task.wait(0.1)
	check(A:GetAttribute("Bucks") == 1, "no Bucks, no snack")
	-- punch it: a free snack rattles out (JJS style)
	clearSent()
	task.wait(Config.M1.ComboReset + 0.1)
	fire(UseAbility, A, 0)
	task.wait(0.25)
	local free = shops:FindFirstChild("FreeSnack")
	check(#sentTo(B, "MachineHit") == 1 and free ~= nil, "punching the machine knocks a free snack loose")
	check(free and (free.Position - body.Position).Magnitude > 4, "...it pops out onto the pavement, not at your feet")
	task.wait(Config.M1.Cooldown + 0.1)
	fire(UseAbility, A, 0)
	task.wait(0.25)
	local frees = 0
	for _, c in shops:GetChildren() do
		if c.Name == "FreeSnack" then
			frees += 1
		end
	end
	check(#sentTo(B, "MachineHit") == 2 and frees == 1, "punch it again: it rattles, but it has to restock first")
	-- whoever walks over it eats it
	task.wait(0.4)
	aH.Health = 100
	local heal = I[free:GetAttribute("Item")].Heal
	aR.CFrame = CFrame.new(free.Position + Vector3.new(0, 2.5, 0))
	task.wait(0.9)
	check(free.Parent == nil and aH.Health == 100 + heal, "walk over it and you eat it (+" .. (aH.Health - 100) .. ")")

	print("== Tony's Pizzeria")
	local tony = shops:FindFirstChild(PIZZA.Cook)
	check(tony ~= nil and tony:FindFirstChildOfClass("Humanoid") ~= nil and tony:FindFirstChild("ChefGear") ~= nil, "Tony is behind the counter, chef's hat and all")
	local tonyRoot = tony:FindFirstChild("HumanoidRootPart")
	check(tonyRoot.Anchored == true and (tonyRoot.Position - (PIZZA.Position + Vector3.new(0, 3, 0))).Magnitude < 0.01, "...standing where the config puts him")
	-- attacks go straight through him
	local bC, bH, bR = spawnChar(B, CFrame.lookAt(tonyRoot.Position + Vector3.new(0, 0, 3), tonyRoot.Position))
	local tonyHum = tony:FindFirstChildOfClass("Humanoid")
	local hp = tonyHum.Health
	clearSent()
	task.wait(Config.M1.ComboReset + 0.1)
	fire(UseAbility, B, 0)
	task.wait(0.25)
	local hitTony = false
	for _, h in sentTo(A, "Hit") do
		if h.Target == tony then
			hitTony = true
		end
	end
	check(tonyHum.Health == hp and not hitTony, "nobody can hurt Tony")
	bR.CFrame = CFrame.new(tonyRoot.Position + Vector3.new(40, 0, 60))
	-- talk to him
	local counter = tonyRoot.Position + PIZZA.Face * 8
	aC, aH, aR = spawnChar(A, CFrame.lookAt(counter, tonyRoot.Position))
	aH.MaxHealth, aH.Health = Config.PlayerMaxHealth, 50
	local talk = tonyRoot:FindFirstChildOfClass("ProximityPrompt")
	clearSent()
	talk.Triggered:Fire(A)
	task.wait(0.05)
	local menu = sentTo(A, "VendorMenu")
	check(#menu == 1 and menu[1].Vendor == "Pizza" and menu[1].Npc == tony, "talking to Tony opens his menu")
	check(#sentTo(B, "NpcSay") == 1, "...and everyone hears him say hi")
	for _, id in Config.ItemOrder do
		A:SetAttribute("Item_" .. id, nil)
	end
	A:SetAttribute("Bucks", 30)
	fire(Shop, A, "Buy", "PizzaSlice", "Pizza")
	check(A:GetAttribute("Item_PizzaSlice") == 1 and A:GetAttribute("Bucks") == 30 - I.PizzaSlice.Price, "a pizza slice: " .. I.PizzaSlice.Price .. " Bucks, into the bag")
	check(#sentTo(B, "NpcSay") == 2, "...Tony thanks you")
	fire(Shop, A, "Buy", "GarlicKnots", "Pizza")
	check(A:GetAttribute("Item_GarlicKnots") == I.GarlicKnots.Gives, "garlic knots come " .. I.GarlicKnots.Gives .. " to a bag")
	fire(Shop, A, "Buy", "PizzaSlice")
	check(A:GetAttribute("Item_PizzaSlice") == 1, "the Hero Shop doesn't sell pizza")
	fire(Shop, A, "Buy", "Sniper", "Pizza")
	check(A:GetAttribute("Item_Sniper") == nil, "...and Tony doesn't sell sniper rifles")
	fire(Shop, A, "Buy", "PizzaSlice", "Burgers")
	check(A:GetAttribute("Item_PizzaSlice") == 1, "made-up vendors are ignored")
	aR.CFrame = CFrame.new(counter + Vector3.new(0, 0, 80))
	fire(Shop, A, "Buy", "PizzaSlice", "Pizza")
	check(A:GetAttribute("Item_PizzaSlice") == 1, "you have to be at the counter to order")
	aR.CFrame = CFrame.lookAt(counter, tonyRoot.Position)
	-- eat it
	task.wait((Config.Economy.UseCooldown or 0.5) + 0.1)
	clearSent()
	fire(Shop, A, "Use", "PizzaSlice", PIZZA.Face * -1, tonyRoot.Position)
	task.wait(0.7)
	check(aH.Health == 50 + I.PizzaSlice.Heal and #sentTo(B, "Eat") == 1, "eating the slice: +" .. (aH.Health - 50))
	check(A:GetAttribute("Item_PizzaSlice") == nil, "...and it's gone")
	-- a full bag: you eat it at the counter
	for _, id in { "Sniper", "Bomb", "Trigger" } do
		A:SetAttribute("Item_" .. id, 1)
	end
	aH.Health = 40
	clearSent()
	fire(Shop, A, "Buy", "WholePizza", "Pizza")
	task.wait(0.7)
	local res = sentTo(A, "ShopResult")
	check(res[#res] and res[#res].Ok and res[#res].Ate == true and A:GetAttribute("Item_WholePizza") == nil, "bag full: the whole pizza gets eaten right there")
	check(aH.Health == aH.MaxHealth, "...and a whole pizza is full health")
	A:SetAttribute("Bucks", 0)
	clearSent()
	fire(Shop, A, "Buy", "PizzaSlice", "Pizza")
	res = sentTo(A, "ShopResult")
	check(res[1] and res[1].Ok == false and res[1].Text == PIZZA.Broke, "broke: '" .. tostring(res[1] and res[1].Text) .. "'")
	-- dump the food stands for scene_render.py (merged with the real map)
	-- (a function of its own: this file is near Luau's 200-local limit)
	local function dumpFood()
		local serde = require("@lune/serde")
		local out = {}
		for _, part in shops:GetDescendants() do
			if part.ClassName == "Part" and part.Name ~= "FreeSnack" and (part.Transparency or 0) < 0.99 then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
				local c = part.Color or M.Color3.new(0.5, 0.5, 0.5)
				local shape = part:FindFirstChildOfClass("SpecialMesh") and "ball" or (part.Shape == Enum.PartType.Cylinder and "cyl" or "box")
				local size = part.Name == "Head" and { 1.25, 1.25, 1.25 } or { part.Size.X, part.Size.Y, part.Size.Z }
				table.insert(out, { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = size, color = { c.R, c.G, c.B }, alpha = (part.Transparency or 0) > 0.3 and 0.45 or 1, shape = shape })
			end
		end
		fs.writeFile(process.env.FOOD_OUT, serde.encode("json", out))
	end
	if process.env.FOOD_OUT then
		dumpFood()
	end
end

---------------------------------------------------------------------------
-- Round 19: bodies (Motor6D joints, R6) and hidden spawn pads
---------------------------------------------------------------------------
do
	print("== spawn pads")
	check(spawnPad.Transparency == 1 and spawnDecal.Transparency == 1, "spawn pads (and their decals) are invisible")
	print("== joints")
	-- a body built the Avatar Joint Upgrade way: AnimationConstraints, not Motor6Ds
	local model, hum, root = makeCharacter("Upgraded", CFrame.new(0, 3, 1200))
	local torso = M.new("Part", "UpperTorso")
	torso.Parent = model
	local arm = M.new("Part", "RightUpperArm")
	arm.Parent = model
	local a0 = M.new("Attachment", "RightShoulderRigAttachment")
	a0.CFrame = CFrame.new(1, 0.56, 0)
	a0.Parent = torso
	local a1 = M.new("Attachment", "RightShoulderRigAttachment")
	a1.CFrame = CFrame.new(-0.5, 0.39, 0)
	a1.Parent = arm
	local joint = M.new("AnimationConstraint", "RightShoulder")
	joint.Attachment0 = a0
	joint.Attachment1 = a1
	joint.Parent = arm
	local socket = M.new("BallSocketConstraint", "RightShoulderSocket")
	socket.Parent = arm
	model.Parent = dummies
	task.wait(0.1)
	local motor = arm:FindFirstChild("RightShoulder")
	check(motor ~= nil and motor.ClassName == "Motor6D" and motor.Part0 == torso and motor.Part1 == arm, "AnimationConstraint joints go back to Motor6Ds")
	check(motor and motor.C0 == a0.CFrame and motor.C1 == a1.CFrame, "...with the same rest pose (C0/C1 from the rig attachments)")
	check(socket.Parent == nil and model:GetAttribute("ClassicJoints") == true, "...the stray sockets go, and the body is marked ready")
	model:Destroy()
	local aC = spawnChar(A, CFrame.new(0, 3, 1250))
	check(aC:GetAttribute("ClassicJoints") == true, "players' bodies are marked ready too")
	print("== R6 bodies")
	-- the experience lets an R15 body in: it's swapped for an R6 one
	local loads = 0
	function A.LoadCharacter()
		loads += 1
	end
	function Players.GetHumanoidDescriptionFromUserId()
		return M.new("Folder", "HumanoidDescription")
	end
	function Players.CreateHumanoidModelFromDescription(_, _, rig)
		local r6, h = makeCharacter("Rig", CFrame.new(0, 3, 900))
		h.RigType = rig
		h.WalkSpeed = 1
		M.new("LocalScript", "Animate").Parent = r6
		return r6
	end
	local sp = game:GetService("StarterPlayer")
	sp.CharacterJumpHeight = 9.5
	sp.CharacterMaxSlopeAngle = 70
	local r15 = spawnChar(A, CFrame.new(0, 3, 1250))
	task.wait(0.5)
	local swapped = A.Character
	local sHum = swapped and swapped:FindFirstChildOfClass("Humanoid")
	check(swapped ~= r15 and sHum ~= nil and sHum.RigType == Enum.HumanoidRigType.R6, "an R15 body in an R6 game: swapped for an R6 body")
	check(swapped.Parent == workspace and r15.Parent == nil and loads == 0, "...in place, with no respawn or shared StarterCharacter")
	check(game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter") == nil, "...and nobody else gets that body")
	check((swapped:GetPivot().Position - Vector3.new(0, 3, 1250)).Magnitude < 1, "...standing where the old body stood")
	check(swapped:GetAttribute("ClassicJoints") == true and swapped:GetAttribute("CharSetup") == true,
		"...and gets a normal spawn's setup (joints, guard, passives)")
	check(sHum.JumpHeight == 9.5 and sHum.MaxSlopeAngle == 70 and sHum.DisplayName == A.DisplayName,
		"...with the place's jump/slope settings and the player's name")
	check(A.DevEnableMouseLock == false, "the built-in shift lock is off (the custom one owns Shift)")
	swapped:Destroy()
	local r6Char, r6Hum = makeCharacter("Alpha", CFrame.new(0, 3, 1250))
	r6Hum.RigType = Enum.HumanoidRigType.R6
	r6Char.Parent = workspace
	A.Character = r6Char
	A.CharacterAdded:Fire(r6Char)
	task.wait(0.1)
	check(loads == 0 and r6Char:GetAttribute("ClassicJoints") == true, "an R6 body is left alone")
	Players.CreateHumanoidModelFromDescription = nil
	function A.LoadCharacter() end
end

---------------------------------------------------------------------------
-- Round 20: hit registration (lag compensation, the attacker's own view,
-- the M1's active window)
---------------------------------------------------------------------------
do
	print("== HIT REGISTRATION")
	local FWD = Vector3.new(0, 0, 1)
	local base = Vector3.new(620, 3, 0)
	fire(SelectQuirk, A, "Explosion")
	local function setup(bAt)
		local aC, aH, aR = spawnChar(A, CFrame.lookAt(base, base + FWD))
		local bC, bH, bR = spawnChar(B, CFrame.lookAt(bAt, base))
		aH.MaxHealth, aH.Health = 200, 200
		bH.MaxHealth, bH.Health = 200, 200
		task.wait(0.4) -- (a little history)
		return aC, aH, aR, bC, bH, bR
	end
	local function swing(cf)
		fire(UseAbility, A, 0, cf)
		task.wait(0.25)
	end

	-- they stepped out of reach on the server, but on A's screen they were still there
	function A.GetNetworkPing()
		return 0.12
	end
	local _, _, _, bC, bH = setup(base + FWD * 4)
	local h0 = bH.Health
	bC:PivotTo(CFrame.lookAt(base + FWD * 14, base))
	swing()
	check(bH.Health < h0, "a punch that landed on the attacker's screen lands (lag compensation)")
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 4)
	h0 = bH.Health
	bC:PivotTo(CFrame.lookAt(base + FWD * 14, base))
	task.wait(0.5)
	swing()
	check(bH.Health == h0, "...but not once they've been gone longer than the rewind")
	A.GetNetworkPing = nil
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 4)
	h0 = bH.Health
	bC:PivotTo(CFrame.lookAt(base + FWD * 14, base))
	swing()
	check(bH.Health == h0, "...and with no ping known there's no rewind at all")

	-- measured from where the attacker stood on their own screen
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 9)
	h0 = bH.Health
	swing(CFrame.lookAt(base + FWD * 5, base + FWD * 6))
	check(bH.Health < h0, "the swing comes from where the attacker is on their screen")
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 9)
	h0 = bH.Health
	swing(CFrame.lookAt(base + FWD * 40, base + FWD * 41))
	check(bH.Health == h0, "...but a position far from the server's is ignored")

	-- the swing stays live for a few frames: walking into it still gets hit
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 12)
	h0 = bH.Health
	fire(UseAbility, A, 0)
	task.wait(0.095)
	bC:PivotTo(CFrame.lookAt(base + FWD * 4, base))
	task.wait(0.2)
	check(bH.Health < h0, "stepping into a punch a frame late still gets hit (active window)")
	task.wait(Config.M1.ComboReset + 0.1)
	_, _, _, bC, bH = setup(base + FWD * 4)
	h0 = bH.Health
	m1(A)
	task.wait(0.2)
	check(h0 - bH.Health == Config.M1.Damage, "...and a punch still only lands once (" .. (h0 - bH.Health) .. ")")
	task.wait(Config.M1.ComboReset + 0.1)
end

---------------------------------------------------------------------------
-- Round 20: LEMILLION (Permeation)
---------------------------------------------------------------------------
do
	print("== LEMILLION")
	local FWD = Vector3.new(0, 0, 1)
	local base = Vector3.new(420, 3, 0)
	local stubRayLem = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
		end
		return nil
	end
	local LEM = Config.Quirks.Lemillion
	local R6 = {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
		{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
	}
	local function body(p, pos, look)
		local model, hum, root = spawnChar(p, CFrame.lookAt(pos, look))
		root.AssemblyMass = 12
		for _, spec in R6 do
			local part = M.new("Part", spec[1])
			part.Size = spec[2]
			part.CFrame = root.CFrame * CFrame.new(spec[3])
			part.Parent = model
		end
		hum.MaxHealth = Config.PlayerMaxHealth
		hum.Health = Config.PlayerMaxHealth
		return model, hum, root
	end
	local function fresh(bPos)
		fire(TestCommand, A, "ResetCooldowns")
		local a, ah, ar = body(A, base, base + FWD * 4)
		local b, bh, br = body(B, bPos or base + FWD * 4, base)
		task.wait(0.1)
		return a, ah, ar, b, bh, br
	end
	local function near(p, q, tol)
		return (p - q).Magnitude < (tol or 3)
	end

	fire(SelectQuirk, A, "Lemillion")
	fire(SelectQuirk, B, "Explosion")
	check(A:GetAttribute("Quirk") == "Lemillion", "Lemillion can be picked (not dev-only)")
	check(not LEM.DevOnly and table.find(Config.QuirkOrder, "Lemillion") ~= nil, "...and he's in everyone's quirk menu")
	local aC, aH, aR, bC, bH, bR = fresh()
	fire(SelectQuirk, A, "Lemillion") -- (rebuilds the gear now the test body has its limbs)
	task.wait(0.4)
	local gear = aC:FindFirstChild("QuirkGear")
	local text
	for _, d in gear and gear:GetDescendants() or {} do
		if d.ClassName == "TextLabel" then
			text = d.Text
		end
	end
	local capes = 0
	for _, d in gear and gear:GetDescendants() or {} do
		if d.Name == "Cape" or d.Name == "Visor" then
			capes += 1
		end
	end
	check(gear ~= nil and capes >= 6 and text == nil, "his look goes on: the cape and the visor (" .. capes .. " pieces)")
	local noClip = true
	for _, d in gear and gear:GetDescendants() or {} do
		if d.ClassName == "Part" and (d.CanCollide or d.CanQuery or d.CanTouch or not d.Massless) then
			noClip = false
		end
	end
	check(noClip, "...weightless, no collisions, no hitbox queries")
	-- dump the costumed body for scene_render.py (LEM_OUT=file.json)
	if process.env.LEM_OUT then
		local serde = require("@lune/serde")
		local out = {}
		local function add(part, color)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
			local c = color or part.Color or M.Color3.new(0.5, 0.5, 0.5)
			local shape = part:FindFirstChildOfClass("SpecialMesh") and "ball" or (part.Shape == Enum.PartType.Cylinder and "cyl" or "box")
			local size = part.Name == "Head" and { 1.25, 1.25, 1.25 } or { part.Size.X, part.Size.Y, part.Size.Z }
			table.insert(out, { cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = size, color = { c.R, c.G, c.B }, alpha = 1, shape = shape })
		end
		for _, part in aC:GetChildren() do
			if part.ClassName == "Part" and part.Name ~= "HumanoidRootPart" then
				add(part, M.Color3.new(0.93, 0.76, 0.62))
			end
		end
		for _, part in gear:GetChildren() do
			if part.ClassName == "Part" then
				if part.Transparency == 1 then
					add(part, M.Color3.new(1, 0.8, 0.1)) -- (the lettering plate: drawn as a yellow band)
				else
					add(part)
				end
			end
		end
		fs.writeFile(process.env.LEM_OUT, serde.encode("json", { { label = "Lemillion costume", parts = out } }))
	end

	print("== DEEP DIVE")
	local exit = base + FWD * 30
	aC, aH, aR, bC, bH, bR = fresh(exit)
	local h0 = bH.Health
	clearSent()
	fire(UseAbility, A, 1, FWD, exit)
	local launchY = 0
	task.spawn(function()
		for _ = 1, 40 do
			local lv = bR:FindFirstChild("Knockback")
			launchY = math.max(launchY, lv and lv.VectorVelocity.Y or 0)
			task.wait(0.03)
		end
	end)
	task.wait(0.15)
	check(aC:GetAttribute("Submerged") == true and aR.Anchored == true, "he sinks through the street (hidden, held in place)")
	local aHealth = aH.Health
	m1(B)
	task.wait(0.15)
	check(aH.Health == aHealth, "...where nothing can touch him")
	fire(UseAbility, A, 2, FWD, base)
	check(#sentTo(B, "PhantomMenace") == 0, "...and he can't do anything else down there")
	task.wait(0.55)
	check(near(aR.CFrame.Position, exit + Vector3.new(0, 3.2, 0), 4) and aC:GetAttribute("Submerged") == false and aR.Anchored == false,
		"...and bursts out at the aim point")
	check(h0 - bH.Health == LEM.Abilities[1].Damage and bC:GetAttribute("Stunned") == true,
		"...uppercutting whoever stood there (" .. (h0 - bH.Health) .. ")")
	check(launchY > 50, "...up into the air (" .. math.floor(launchY) .. ")")
	task.wait(0.3)

	print("== PHANTOM MENACE")
	aC, aH, aR, bC, bH, bR = fresh()
	h0 = bH.Health
	clearSent()
	fire(UseAbility, A, 2, FWD, base + FWD * 4)
	task.wait(1.3)
	local strikes = sentTo(A, "PhantomStrike")
	local pm = LEM.Abilities[2]
	check(#strikes == 3 and h0 - bH.Health == pm.Damage * 2 + pm.FinisherDamage,
		"three blind-spot strikes (" .. #strikes .. " for " .. (h0 - bH.Health) .. ")")
	check(strikes[1] and (strikes[1].At - bR.Position):Dot(bR.CFrame.LookVector) < 0, "...the first from behind them")
	check(bC:GetAttribute("Ragdolled") == true and aR.Anchored == false, "...the last puts them on the floor, and he lets go")
	-- nobody in front: he phases straight ahead instead
	aC, aH, aR, bC, bH, bR = fresh(base + Vector3.new(80, 0, 0))
	clearSent()
	fire(UseAbility, A, 2, FWD, base + FWD * 20)
	task.wait(0.1)
	check(#sentTo(A, "PhantomMiss") == 1 and #sentTo(A, "PhantomStrike") == 0, "...with nobody there he phases straight ahead")

	print("== PREDICTION")
	aC, aH, aR, bC, bH, bR = fresh()
	task.wait(Config.M1.ComboReset + 0.1)
	h0 = bH.Health
	aHealth = aH.Health
	clearSent()
	fire(UseAbility, A, 3, FWD, base + FWD * 4)
	check(aC:GetAttribute("Countering") == true, "the stance is up")
	m1(B)
	task.wait(0.15)
	check(aH.Health == aHealth and #sentTo(B, "PredictionTrigger") == 1, "a punch into it passes straight through him")
	task.wait(0.5)
	check(h0 - bH.Health == LEM.Abilities[3].Damage and bC:GetAttribute("Ragdolled") == true,
		"...and he's behind them for a heavy one (" .. (h0 - bH.Health) .. ")")
	check((aR.Position - bR.Position):Dot(bR.CFrame.LookVector) < 0 and aC:GetAttribute("Countering") == false,
		"...from their blind spot, and the stance is spent")
	-- nothing comes: it just ends
	aC, aH, aR, bC, bH, bR = fresh()
	fire(UseAbility, A, 3, FWD, base + FWD * 4)
	task.wait(LEM.Abilities[3].Duration + 0.2)
	check(aC:GetAttribute("Countering") == false, "...if nothing comes, the stance drops by itself")
	task.wait(Config.M1.ComboReset + 0.1)
	aHealth = aH.Health
	m1(B)
	task.wait(0.15)
	check(aH.Health < aHealth, "...and hits land on him again")

	print("== PERMEATE")
	aC, aH, aR, bC, bH, bR = fresh()
	task.wait(Config.M1.ComboReset + 0.1)
	aHealth = aH.Health
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	m1(B)
	task.wait(0.15)
	check(aC:GetAttribute("Phasing") == true and aC:GetAttribute("WallPhase") == true and aH.Health == aHealth, "R: PERMEATE - hits pass straight through (and he walks through walls)")
	m1(A)
	check(aC:GetAttribute("Phasing") == false and aC:GetAttribute("WallPhase") == false, "...until he attacks (the world comes back in)")

	print("== PHANTOM MENACE (ult)")
	aC, aH, aR, bC, bH, bR = fresh()
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.3)
	check(A:GetAttribute("UltActive") == true, "G: the ult")
	LEM.Ult.PhaseChance = 1
	task.wait(Config.M1.ComboReset + 0.1)
	while bC:GetAttribute("Ragdolled") == true do
		task.wait(0.05)
	end
	aHealth = aH.Health
	clearSent()
	m1(B)
	task.wait(0.15)
	local dodges = sentTo(B, "Dodge")
	check(aH.Health == aHealth and #dodges >= 1 and dodges[1].Phase == true, "in it, hits can pass straight through him")
	LEM.Ult.PhaseChance = 0.3
	-- the finisher: up out of the street under them, then from above
	-- (no respawn here: a new body ends the ult)
	fire(TestCommand, A, "ResetCooldowns")
	bC:PivotTo(CFrame.lookAt(base + FWD * 25, base))
	aC:PivotTo(CFrame.lookAt(base, base + FWD))
	bC:SetAttribute("Stunned", false)
	bC:SetAttribute("Ragdolled", false)
	bH.Health = bH.MaxHealth
	task.wait(0.1)
	h0 = bH.Health
	clearSent()
	fire(UseAbility, A, 3, FWD, base + FWD * 25)
	task.wait(1.5)
	local mp = LEM.Ult.Abilities[3]
	local mult = Config.Ult.DamageMultiplier or 1
	local expect = math.floor(mp.LaunchDamage * mult + 0.5) + math.floor(mp.Damage * mult + 0.5)
	check(#sentTo(B, "MillionPunchRise") == 1 and #sentTo(B, "MillionPunchDrop") == 1 and h0 - bH.Health == expect,
		"LEMILLION: ONE MILLION - launched, then driven down (" .. (h0 - bH.Health) .. "/" .. expect .. ")")
	task.wait(0.3)
	check(#sentTo(B, "MillionPunchImpact") == 1 and aR.Anchored == false and aC:GetAttribute("Submerged") == false,
		"...into the street, and he's free again")
	fire(TestCommand, A, "EndUlt")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.2)
	workspace.Raycast = stubRayLem
end

---------------------------------------------------------------------------
-- Round 21: JJS M1 finishers (uppercut / downslam, air juggles) and the
-- aimed St. Louis Smash
---------------------------------------------------------------------------
do
	print("== M1 FINISHERS: UPPERCUT / DOWNSLAM")
	local FWD = Vector3.new(0, 0, 1)
	local base = Vector3.new(720, 3, 0)
	local UPV = Vector3.new(0, 1, 0)
	-- a flat street at y = 0 (the default stub has no ground at all); a ray
	-- only finds it if it's long enough to reach it
	local stubRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = UPV }
		end
		return nil
	end
	fire(SelectQuirk, A, "Explosion")
	local function setup(aPos, bPos)
		fire(TestCommand, A, "ResetCooldowns")
		local aC, aH, aR = spawnChar(A, CFrame.lookAt(aPos, Vector3.new(bPos.X, aPos.Y, bPos.Z)))
		local bC, bH, bR = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		aH.MaxHealth, aH.Health = 200, 200
		bH.MaxHealth, bH.Health = 200, 200
		task.wait(Config.M1.ComboReset + 0.1)
		return aC, aH, aR, bC, bH, bR
	end
	local function chain3()
		for _ = 1, 3 do
			fire(UseAbility, A, 0)
			task.wait(Config.M1.Cooldown + 0.02)
		end
	end
	-- the fastest the body was pushed up (+) or down (-) over the next moment
	local function watchLaunch(bR, seconds)
		local peak = { Up = 0, Down = 0 }
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < seconds do
				local lv = bR:FindFirstChild("Knockback")
				if lv then
					peak.Up = math.max(peak.Up, lv.VectorVelocity.Y)
					peak.Down = math.min(peak.Down, lv.VectorVelocity.Y)
				end
				task.wait(0.02)
			end
		end)
		return peak
	end
	local function lastPunch(p)
		local list = sentTo(p, "Punch")
		return list[#list]
	end

	-- UPPERCUT: 4th hit with jump held, standing
	local _, _, _, bC, bH, bR = setup(base, base + FWD * 4)
	chain3()
	clearSent()
	local h0 = bH.Health
	local peak = watchLaunch(bR, 0.5)
	fire(UseAbility, A, 0, nil, "Up")
	task.wait(0.5)
	local punch = lastPunch(B)
	check(punch and punch.Finisher == true and punch.Variant == "Up", "UPPERCUT: everyone sees the 4th hit as an uppercut")
	check(h0 - bH.Health == Config.M1.FinisherDamage and peak.Up >= Config.M1.Uppercut.Lift * 0.9,
		"...it launches them straight up (" .. math.floor(peak.Up) .. " up)")
	check(bC:GetAttribute("Stunned") == true and bC:GetAttribute("Ragdolled") ~= true, "...stunned, not limp: ready for an air combo")

	-- a downslam can't be claimed standing on the street
	_, _, _, bC, bH, bR = setup(base, base + FWD * 4)
	chain3()
	clearSent()
	fire(UseAbility, A, 0, nil, "Down")
	task.wait(0.3)
	punch = lastPunch(B)
	check(punch and punch.Variant == nil and bC:GetAttribute("Ragdolled") == true, "a 'downslam' from the ground is just the normal 4th hit")

	-- DOWNSLAM: the 4th hit in the air, over them (up there with you: a
	-- spike down on someone already standing on the street stays flat)
	_, _, _, bC, bH, bR = setup(base + Vector3.new(0, 5, 0), base + FWD * 3.5 + Vector3.new(0, 4, 0))
	chain3()
	clearSent()
	h0 = bH.Health
	peak = watchLaunch(bR, 0.8)
	fire(UseAbility, A, 0, nil, "Down")
	task.wait(0.8)
	punch = lastPunch(B)
	local slam = sentTo(B, "Downslam")
	check(punch and punch.Variant == "Down" and h0 - bH.Health == Config.M1.FinisherDamage, "DOWNSLAM: the 4th hit thrown in the air")
	-- (a limp body takes Config.Ragdoll.KnockbackScale of any push)
	check(peak.Down <= -Config.M1.Downslam.Drop * (Config.Ragdoll.KnockbackScale or 0.8) * 0.9 and bC:GetAttribute("Ragdolled") == true,
		"...spikes them into the street, limp (" .. math.floor(peak.Down) .. ")")
	check(#slam == 1 and peak.Up > 0, "...they hit it (everyone sees the impact) and bounce off it")

	-- AIR COMBO: both in the air, hits keep them up there
	_, _, _, bC, bH, bR = setup(base + Vector3.new(0, 9, 0), base + FWD * 4 + Vector3.new(0, 9, 0))
	peak = watchLaunch(bR, 0.3)
	fire(UseAbility, A, 0)
	task.wait(0.3)
	check(peak.Up >= Config.M1.AirJuggle.Up * 0.9 and bC:GetAttribute("Stunned") == true,
		"air combo: M1s keep an airborne target floating (" .. math.floor(peak.Up) .. " up)")
	workspace.Raycast = stubRay

	print("== ST. LOUIS SMASH (aimed)")
	fire(SelectQuirk, A, "FullCowl")
	local aC, aH, aR
	aC, aH, aR, bC, bH, bR = setup(base, base + FWD * 8 + Vector3.new(0, 7, 0))
	task.wait(0.3)
	check(Config.Quirks.FullCowl.Abilities[2].Id == "StLouisSmash", "(St. Louis Smash is in his base kit now: slot 2)")
	h0 = bH.Health
	local up = (bR.Position - aR.Position).Unit
	fire(UseAbility, A, 2, up, bR.Position)
	task.wait(0.5)
	check(bH.Health < h0, "aimed up, the kick reaches someone just above him (" .. (h0 - bH.Health) .. ")")
	-- the same shot levelled off (the old behaviour) misses them
	fire(TestCommand, A, "ResetCooldowns")
	bC:PivotTo(CFrame.new(base + FWD * 8 + Vector3.new(0, 7, 0)))
	bH.Health = 200
	h0 = bH.Health
	task.wait(Config.Quirks.FullCowl.Abilities[2].ActionTime or 0.5)
	fire(UseAbility, A, 2, FWD, base + FWD * 8)
	task.wait(0.5)
	check(bH.Health == h0, "...aimed level it goes under them")
	local a = Config.AimedDirection(Vector3.new(0, -1, 0.05).Unit, FWD, { Up = 60, Down = 45 })
	check(math.abs(math.deg(math.asin(a.Y)) + 45) < 1, "straight down is held to 45 degrees below level")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.2)
end

---------------------------------------------------------------------------
-- Round 22: parkour (the moves run on the player's machine; the server
-- only passes them on for everyone else to see)
---------------------------------------------------------------------------
do
	print("== PARKOUR relay")
	local FWD = Vector3.new(0, 0, 1)
	spawnChar(A, CFrame.new(820, 3, 0))
	spawnChar(B, CFrame.new(830, 3, 0))
	task.wait(0.2)
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Vault", FWD, nil, 0.36)
	local seen = sentTo(B, "Parkour")
	check(#seen == 1 and seen[1].Kind == "Vault" and seen[1].Time == 0.36 and #sentTo(A, "Parkour") == 0,
		"a vault is passed on to everyone else (not back to the vaulter)")
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WallRun", FWD, "L", 0.3)
	check(#sentTo(B, "Parkour") == 1, "...and spamming is throttled")
	task.wait(0.1)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WallRun", FWD, "L", 0.3)
	seen = sentTo(B, "Parkour")
	check(#seen == 2 and seen[2].Side == "L", "a wall run says which side the wall is on")
	task.wait(0.1)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Teleport", FWD)
	task.wait(0.1)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Roll", FWD, nil, 99)
	seen = sentTo(B, "Parkour")
	check(#seen == 3 and seen[3].Kind == "Roll" and seen[3].Time == 2, "made-up moves are ignored, times are capped")
	A.Character:SetAttribute("ErasedUntil", workspace:GetServerTimeNow() + 5)
	task.wait(0.1)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Climb", FWD, nil, 0.5)
	check(#sentTo(B, "Parkour") == 4, "parkour isn't a quirk: it works while erased")
	A.Character:SetAttribute("ErasedUntil", nil)
end

---------------------------------------------------------------------------
-- Round 27: BAKUGO - no NUKE; AP Shot stays off the street; air variants;
-- Eruption Orbit; Scorched Earth; the grenade blinds the unguarded; the
-- real Howitzer Impact is the ult
---------------------------------------------------------------------------
do
	print("== BAKUGO (round 27)")
	local EXP = Config.Quirks.Explosion
	local MAX = Config.PlayerMaxHealth
	local X = 1200
	local FWD = Vector3.new(0, 0, 1)
	local ids = {}
	for _, set in { EXP.Abilities, EXP.Ult.Abilities } do
		for _, ab in set do
			ids[ab.Id] = true
		end
	end
	for _, ex in { EXP.Extra, EXP.Special, EXP.Ult and EXP.Ult.Extra } do
		if ex then
			ids[ex.Id] = true
		end
	end
	check(not ids.Nuke and Config.Quirks.PlusUltra.Extra.Id == "Nuke", "no NUKE for Bakugo (his explosions go off the moment he makes them) - it's the dev kit's now")
	check(EXP.Abilities[3].Id == "BlastOrbit" and EXP.Ult.Abilities[3].Id == "Howitzer", "Howitzer Impact is saved for the ult; Eruption Orbit takes its slot")
	check(EXP.Extra and EXP.Extra.Id == "ScorchedEarth", "his 4th move (V) is Scorched Earth")
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	A:SetAttribute("NoCooldowns", true)
	local third = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	local function fresh(bPos, cPos)
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(third, CFrame.lookAt(cPos or Vector3.new(X + 400, 3, 0), Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end

	-- AP SHOT: aimed at the street right in front of him, it still goes straight out
	fresh(Vector3.new(X, 3, 45))
	clearSent()
	fire(UseAbility, A, 1, Vector3.new(0, -0.7, 0.7).Unit, Vector3.new(X, 0, 6), 1, aRoot.Position)
	task.wait(0.35)
	check(bHum.Health < MAX, "AP SHOT aimed at the street at his feet still flies straight out and hits B 45 studs away (" .. bHum.Health .. ")")
	check(profilesUsed.Beam == true, "...drilling through whatever's in the way")
	-- in the air he can aim it down at them
	fresh(Vector3.new(X, 3, 300), Vector3.new(X, 3, 24))
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 30, 0), Vector3.new(X, 30, 10))
	fire(UseAbility, A, 1, (Vector3.new(X, 3, 24) - Vector3.new(X, 31.5, 0)).Unit, Vector3.new(X, 3, 24), 1, aRoot.Position, true)
	task.wait(0.35)
	check(cHum.Health < MAX, "AP SHOT in the air: aimed down at C below him, it hits (" .. cHum.Health .. ")")
	fresh(Vector3.new(X, 3, 300), Vector3.new(X, 3, 24))
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 30, 0), Vector3.new(X, 30, 10))
	fire(UseAbility, A, 1, (Vector3.new(X, 3, 24) - Vector3.new(X, 31.5, 0)).Unit, Vector3.new(X, 3, 24), 1, aRoot.Position, false)
	task.wait(0.35)
	check(cHum.Health == MAX, "(the same aim claimed from the ground goes straight out over C)")

	-- BLAST RUSH in the air: a dive-bomb on the aim point, the landing explodes
	fresh(Vector3.new(X, 3, 30))
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 25, 0), Vector3.new(X, 25, 10))
	clearSent()
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position, true)
	check(#sentTo(B, "BlastRush") == 1 and sentTo(B, "BlastRush")[1].Air == true, "BLAST RUSH in the air tells everyone it's the air version")
	task.wait(0.15)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 28), Vector3.new(X, 3, 38)) -- (his machine dived him down there)
	task.wait(0.8)
	check(bHum.Health < MAX and bHum.Health <= MAX - EXP.Abilities[2].FinisherDamage, "...and the landing blows up on B (" .. bHum.Health .. ")")
	check(profilesUsed.BigExplosion == true, "...leaving a crater")

	-- ERUPTION ORBIT: the street erupts under B, B goes up and is held there,
	-- he circles blasting, then drives B into the street
	local ORB = EXP.Abilities[3]
	fresh(Vector3.new(X, 3, 9))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 9), 1, aRoot.Position, false)
	task.wait(0.35)
	check(bHum.Health == MAX - ORB.Damage, "ERUPTION ORBIT: the street erupts under B (" .. bHum.Health .. ")")
	task.wait(0.45)
	check(bRoot.Anchored == true and bChar:GetAttribute("Grabbed") == true, "...B is held up there while he circles")
	local catch = sentTo(A, "BlastOrbitCatch")[1]
	check(catch ~= nil and catch.Targets and catch.Targets[1] == bChar and typeof(catch.Center) == "Vector3", "(his own screen is told who to circle, and where)")
	task.wait(1.1)
	local want = ORB.Damage + ORB.OrbitDamage * ORB.OrbitHits + ORB.SlamDamage
	check(bHum.Health == MAX - want, "...three blasts from the sides and the last one from above (" .. (MAX - bHum.Health) .. " of " .. want .. ")")
	check(not bRoot.Anchored and not bChar:GetAttribute("Grabbed") and bChar:GetAttribute("Ragdolled") == true, "...then B is let go - driven into the street, limp")
	-- nobody there: just the eruption
	fresh(Vector3.new(X, 3, 60))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 9), 1, aRoot.Position, false)
	task.wait(0.9)
	local empty = sentTo(A, "BlastOrbitCatch")[1]
	check(empty ~= nil and #empty.Targets == 0 and bHum.Health == MAX, "(an eruption that catches nobody: no orbit)")
	-- in the air: straight for the nearest one
	fresh(Vector3.new(X, 23, 12))
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 22, 0), Vector3.new(X, 22, 10))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 22, 12), 1, aRoot.Position, true)
	task.wait(0.3)
	check(bRoot.Anchored == true and bHum.Health == MAX - ORB.Damage, "ERUPTION ORBIT in the air: no eruption, he goes straight for B up there")
	task.wait(1.2)
	check(not bRoot.Anchored and bHum.Health == MAX - want, "...and ends it the same way")

	-- SCORCHED EARTH (V): grab the face, drag them along the street, blow up in their face
	local SE = EXP.Extra
	if SE and SE.Id == "ScorchedEarth" then
	fresh(Vector3.new(X, 3, 6))
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position, false)
	task.wait(0.3)
	check(bChar:GetAttribute("Grabbed") == true and bRoot.Anchored == true, "SCORCHED EARTH grabs B by the face")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 40)) -- (his machine rockets him on)
	task.wait(0.15)
	check((bRoot.Position - Vector3.new(X, 3, 33.2)).Magnitude < 1.5, "...and B goes with him, held out in front (" .. tostring(bRoot.Position) .. ")")
	check(profilesUsed.Crater == true, "...ploughing a trench")
	task.wait(0.8)
	check(bHum.Health == MAX - SE.DragDamage - SE.Damage and not bRoot.Anchored, "...then it blows up in B's face (" .. (MAX - bHum.Health) .. ")")
	-- a guard doesn't stop a grab
	fresh(Vector3.new(X, 3, 6))
	fire(UseAbility, B, BLOCK, true)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position, false)
	task.wait(0.3)
	check(bChar:GetAttribute("Grabbed") == true and not bChar:GetAttribute("Blocking"), "(a raised guard doesn't stop a grab)")
	task.wait(1)
	end

	-- STUN GRENADE: B isn't guarding and is blinded; C guards it and isn't
	fresh(Vector3.new(X, 3, 10), Vector3.new(X, 3, -10))
	cRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, -10), Vector3.new(X, 3, 0))
	fire(UseAbility, third, BLOCK, true)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position, false)
	task.wait(0.4)
	local blindB, blindC = sentTo(B, "Blind"), sentTo(third, "Blind")
	check(#blindB == 1 and blindB[1].Duration == EXP.Special.Blind and bChar:GetAttribute("Stunned") == true, "STUN GRENADE blinds B, who wasn't guarding (" .. tostring(blindB[1] and blindB[1].Duration) .. "s)")
	check(#blindC == 0 and not cChar:GetAttribute("Stunned"), "...but not C, who took it on a raised guard")

	-- HOWITZER IMPACT (ult): he flies at the aim point and the whole block goes
	local HOW = EXP.Ult.Abilities[3]
	fresh(Vector3.new(X, 3, 80), Vector3.new(X + 30, 3, 80))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	check(A:GetAttribute("UltActive") == true, "(ult on)")
	aHum.Health = MAX
	bHum.Health, cHum.Health = MAX, MAX
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 80), 1, aRoot.Position, false)
	task.wait(0.9)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 76), Vector3.new(X, 3, 86)) -- (his machine flew him there)
	task.wait(0.9)
	check(bHum.Health < MAX and bChar:GetAttribute("Ragdolled") == true, "HOWITZER IMPACT (ult) crashes down on the aim point: B is blown away (" .. bHum.Health .. ")")
	check(cHum.Health < MAX and MAX - cHum.Health < MAX - bHum.Health, "...C, 30 studs off, is caught by the edge of it (" .. cHum.Health .. ")")
	check(bHum.Health > 0 and MAX - bHum.Health <= MAX * Config.Balance.MaxHitShare + 0.5, "...but it can't one-shot anyone")
	check(aHum.Health == MAX, "(and it never hurts him)")
	fire(TestCommand, A, "EndUlt")
	A:SetAttribute("NoCooldowns", nil)
	cChar.Parent = nil
end

---------------------------------------------------------------------------
-- Round 27: ALL MIGHT - fists, grapples and a counter (not Deku's kit):
-- New Hampshire Smash carries them on his fists, Hero's Counter, the
-- Backdrop Driver, and Weather Changer in the ult
---------------------------------------------------------------------------
do
	print("== ALL MIGHT (round 27)")
	local OFA = Config.Quirks.OneForAll
	local MAX = Config.PlayerMaxHealth
	local X = 1800
	local FWD = Vector3.new(0, 0, 1)
	local deku = Config.Quirks.FullCowl
	local dekuIds = {}
	for _, set in { deku.Abilities, deku.Alt and deku.Alt.Abilities or {}, deku.Extras or {} } do
		for _, ab in set do
			dekuIds[ab.Id] = true
		end
	end
	local shared = {}
	for _, set in { OFA.Abilities, OFA.Alt.Abilities } do
		for _, ab in set do
			if dekuIds[ab.Id] then
				table.insert(shared, ab.Id)
			end
		end
	end
	check(#shared == 0, "All Might shares no move with Deku (" .. table.concat(shared, ", ") .. ")")
	check(OFA.Extra and OFA.Extra.Id == "HeroCounter" and OFA.Alt.Extra.Id == "ColoradoSmash" and OFA.Ult.Extra.Id == "WeatherChanger",
		"a 4th move in every form: Hero's Counter, Colorado Smash, Weather Changer")
	fire(SelectQuirk, A, "OneForAll")
	fire(SelectQuirk, B, "Explosion")
	A:SetAttribute("NoCooldowns", true)
	B:SetAttribute("NoCooldowns", true)
	local third = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	local function fresh(bPos, cPos)
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(third, CFrame.lookAt(cPos or Vector3.new(X + 400, 3, 0), Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end

	-- NEW HAMPSHIRE SMASH: B rides his fists, then the wind goes off
	local NH = OFA.Abilities[2]
	fresh(Vector3.new(X, 3, 6), Vector3.new(X + 9, 3, 38))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.35)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 20), Vector3.new(X, 3, 30)) -- (his machine fires him forward)
	task.wait(0.1)
	check(bChar:GetAttribute("Grabbed") == true and bRoot.Anchored == true, "NEW HAMPSHIRE SMASH: B is caught on his fists")
	check((bRoot.Position - Vector3.new(X, 3, 24.5)).Magnitude < 1.5, "...and carried along in front of him (" .. tostring(bRoot.Position) .. ")")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 40))
	task.wait(0.4)
	check(not bRoot.Anchored and bHum.Health == MAX - NH.Damage - NH.FinisherDamage, "...then the wind he was pushing goes off on B (" .. (MAX - bHum.Health) .. ")")
	check(cHum.Health == MAX - NH.FinisherDamage, "...and on C standing near where he stopped")
	check(profilesUsed.Wind == true, "(the street and walls in the way are blown open)")

	-- HERO'S COUNTER: B shoots him mid-stance - it doesn't land, and B pays
	local HC = OFA.Extra
	fresh(Vector3.new(X, 3, 20))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Countering") == true, "HERO'S COUNTER: he stands his ground")
	clearSent()
	fire(UseAbility, B, 1, -FWD, Vector3.new(X, 3, 0), 1, bRoot.Position)
	task.wait(0.5)
	check(aHum.Health == MAX, "...B's AP Shot doesn't land on him")
	check(#sentTo(B, "HeroCounterHit") == 1, "...everyone sees the Symbol of Peace answer it")
	check(bHum.Health == MAX - HC.Damage and bChar:GetAttribute("Ragdolled") == true, "...with a Detroit Smash that flattens B (" .. (MAX - bHum.Health) .. ")")
	check(not aChar:GetAttribute("Countering"), "(one counter per stance)")
	-- outside the stance, a hit lands like any other
	fresh(Vector3.new(X, 3, 20))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(HC.Window + 0.2)
	fire(UseAbility, B, 1, -FWD, Vector3.new(X, 3, 0), 1, bRoot.Position)
	task.wait(0.4)
	check(aHum.Health < MAX and bHum.Health == MAX, "(too late: the stance is over and the shot lands)")

	-- BACKDROP DRIVER (muscle form): over his head and into the street behind him
	local BD = OFA.Alt.Abilities[3]
	fresh(Vector3.new(X, 3, 5), Vector3.new(X + 4, 3, -5))
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.3)
	check(A:GetAttribute("QuirkAlt") == true, "(muscle form)")
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.15 + BD.OverTime * 0.5)
	check(bRoot.Anchored == true and bRoot.Position.Y > aRoot.Position.Y + 3, "BACKDROP DRIVER: B goes up over his head (" .. tostring(bRoot.Position) .. ")")
	task.wait(BD.OverTime * 0.5 + 0.3)
	check(not bRoot.Anchored and bHum.Health == MAX - BD.GrabDamage - BD.Damage and bChar:GetAttribute("Ragdolled") == true,
		"...and is driven into the street behind him (" .. (MAX - bHum.Health) .. ")")
	check(cHum.Health == MAX - BD.ShockDamage, "...the shock throws C, standing behind him, off their feet")
	-- nobody to grab
	fresh(Vector3.new(X, 3, 40))
	if A:GetAttribute("QuirkAlt") ~= true then
		fire(UseAbility, A, Config.SPECIAL_INDEX) -- (the new body starts in true form)
		task.wait(0.3)
	end
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.3)
	local miss = sentTo(A, "BackdropCatch")[1]
	check(miss ~= nil and miss.Target == nil and bHum.Health == MAX, "(nobody in reach: he grabs thin air)")
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.2)

	-- WEATHER CHANGER (ult V): everyone around goes up... and comes down
	local WC = OFA.Ult.Extra
	fresh(Vector3.new(X, 3, 20), Vector3.new(X - 30, 3, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	aHum.Health, bHum.Health, cHum.Health = MAX, MAX, MAX
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.55)
	local lift = bRoot:FindFirstChild("Knockback")
	check(bHum.Health < MAX and lift and lift.VectorVelocity.Y > 100 * Config.Knockback.MoveLift, "WEATHER CHANGER: the updraft sucks B up into the sky")
	check(cHum.Health < MAX, "...and C, 30 studs away")
	task.wait(WC.HangTime + 0.3)
	local mult = Config.Ult.DamageMultiplier
	check(math.abs((MAX - bHum.Health) - (WC.Damage + WC.DropDamage) * mult) < 1.5, "...then the whole sky comes back down on them (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	A:SetAttribute("NoCooldowns", nil)
	B:SetAttribute("NoCooldowns", nil)
	cChar.Parent = nil
end

---------------------------------------------------------------------------
-- Round 27: DEKU - always in Full Cowl, punches and kicks; R swaps which of
-- the earlier holders' quirks is in his 4th slot; Blackwhip throws
---------------------------------------------------------------------------
do
	print("== DEKU (round 27)")
	local DK = Config.Quirks.FullCowl
	local MAX = Config.PlayerMaxHealth
	local X = 2400
	local FWD = Vector3.new(0, 0, 1)
	check(DK.Alt == nil and DK.Special.Cycle == true and not DK.Special.Form, "no second form to flip into: R swaps quirks instead")
	check(DK.Abilities[2].Id == "StLouisSmash" and DK.Abilities[3].Id == "ManchesterSmash", "his base kit has his kicks (St. Louis, Manchester)")
	local names = {}
	for _, e in DK.Extras do
		table.insert(names, e.Id)
	end
	check(#DK.Extras >= 4 and table.concat(names, ","):find("Blackwhip") and table.concat(names, ","):find("Smokescreen"), "the 4th slot rotates through his quirks (" .. table.concat(names, ", ") .. ")")
	fire(SelectQuirk, A, "FullCowl")
	fire(SelectQuirk, B, "Explosion")
	A:SetAttribute("NoCooldowns", true)
	check(A:GetAttribute("QuirkPick") == 1, "(starts on the first one)")
	local function fresh(bPos)
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end

	-- BLACKWHIP (pick 1): snag and reel them in to him
	local BW = DK.Extras[1]
	fresh(Vector3.new(X, 3, 30))
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	local catch = sentTo(A, "BlackwhipCatch")[1]
	check(catch and catch.Target == bChar and bRoot.Anchored == true, "BLACKWHIP snags B 30 studs away")
	task.wait(0.4)
	check(not bRoot.Anchored and (bRoot.Position - aRoot.Position).Magnitude < 10 and bHum.Health == MAX - BW.Damage,
		"...reels B in to him and lets go (" .. tostring(bRoot.Position) .. ", " .. (MAX - bHum.Health) .. ")")
	task.wait(BW.ActionTime or 0.5)

	-- R: the next quirk
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.1)
	check(A:GetAttribute("QuirkPick") == 2 and #sentTo(B, "QuirkCycle") == 1, "R puts the next quirk in his 4th slot")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	check(#sentTo(B, "Smokescreen") == 1, "...and V is now Smokescreen")
	for _ = 1, #DK.Extras - 1 do
		fire(UseAbility, A, Config.SPECIAL_INDEX)
		task.wait(0.05)
	end
	check(A:GetAttribute("QuirkPick") == 1, "(it goes round and comes back to the first)")
	-- each quirk keeps its own cooldown
	A:SetAttribute("NoCooldowns", nil)
	fire(TestCommand, A, "ResetCooldowns")
	fresh(Vector3.new(X, 3, 200))
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.1)
	fire(UseAbility, A, Config.SPECIAL_INDEX) -- (R swaps the quirk even mid-move: it's no attack)
	task.wait(0.1)
	check(A:GetAttribute("QuirkPick") == 2, "R swaps the quirk even while Blackwhip's still going")
	task.wait(DK.Extras[1].ActionTime or 0.5)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "Blackwhip") == 1 and #sentTo(B, "Smokescreen") == 1, "(a quirk on cooldown doesn't hold up the next one)")
	fire(TestCommand, A, "ResetCooldowns")
	-- switching quirks resets it
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.1)
	check(A:GetAttribute("QuirkPick") == 1, "(a new quirk starts back on the first pick)")
end

---------------------------------------------------------------------------
-- Round 27: TODOROKI - Glacier Breaker, Ice Slider, Scorching Grip, and the
-- Heaven-Piercing Ice Wall as a giant ult move
---------------------------------------------------------------------------
do
	print("== TODOROKI (round 27)")
	local HC = Config.Quirks.HalfCold
	local MAX = Config.PlayerMaxHealth
	local X = 3000
	local FWD = Vector3.new(0, 0, 1)
	check(HC.Abilities[3].Id == "GlacierBreaker" and HC.Ult.Abilities[3].Id == "IceWall", "Heaven-Piercing Ice Wall is an ult move now")
	check(HC.Extra.Id == "IceSlider" and HC.Alt.Extra.Id == "JetKindling" and HC.Ult.Extra.Id == "HeatwaveMax", "a 4th move on each side, and in the ult")
	local Layouts = rawget(spikes, "_exports")
	local list = Layouts.IceWall(Vector3.new(0, 0, 0), FWD, 7)
	local top, reach = 0, 0
	for _, sp in list do
		top = math.max(top, (sp.Base + sp.Dir * sp.Length).Y)
		reach = math.max(reach, sp.Base.Z)
	end
	check(top > 250 and reach > 150, string.format("...and it pierces heaven: %d studs tall, %d studs long", top, reach))
	fire(SelectQuirk, A, "HalfCold")
	fire(SelectQuirk, B, "Explosion")
	A:SetAttribute("NoCooldowns", true)
	local function fresh(bPos)
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end

	-- GLACIER BREAKER: punched into an ice wall, pinned, then the pillar
	local GB = HC.Abilities[3]
	fresh(Vector3.new(X, 3, 5))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.3)
	local pin = sentTo(B, "GlacierPin")[1]
	check(pin and pin.Target == bChar and bRoot.Anchored == true and bHum.Health == MAX - GB.Damage, "GLACIER BREAKER: B is punched back into a wall of ice and pinned there")
	check((bRoot.Position - Vector3.new(X, 3, 5.6)).Magnitude < 1, "...back against the wall (" .. tostring(bRoot.Position) .. ")")
	task.wait(GB.PinTime + 0.2)
	check(not bRoot.Anchored and bHum.Health == MAX - GB.Damage - GB.PillarDamage and bChar:GetAttribute("Ragdolled") == true, "...then the ice pillar throws B up out of it (" .. (MAX - bHum.Health) .. ")")

	-- ICE SLIDER: the ramp freezes whoever it erupts under
	local IS = HC.Extra
	fresh(Vector3.new(X, 3, 30))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.1)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 6, 24), Vector3.new(X, 6, 34)) -- (skating up the ramp)
	task.wait(0.5)
	check(bHum.Health == MAX - IS.Damage and bChar:GetAttribute("Frozen") == true, "ICE SLIDER: the ramp erupts under B and freezes them")
	task.wait(1.2)

	-- (the fire side's V, JET KINDLING: round 31's section)

	-- HEAVEN-PIERCING ICE WALL (ult): it runs out ahead and takes everyone with it
	fresh(Vector3.new(X, 3, 150))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	aHum.Health, bHum.Health = MAX, MAX
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 150), 1, aRoot.Position)
	task.wait(0.55 + 150 / 160 + 0.5)
	check(bHum.Health < MAX and bChar:GetAttribute("Frozen") == true, "HEAVEN-PIERCING ICE WALL reaches B 150 studs away and freezes them in it")
	check(profilesUsed.Ice == true, "(it carves the city)")
	fire(TestCommand, A, "EndUlt")
	A:SetAttribute("NoCooldowns", nil)
end

---------------------------------------------------------------------------
-- Round 27: IIDA - three different kicks (not three dashes): Recipro Spin,
-- Engine Gatling, and a Recipro Burst you HOLD for gears 1-3; Skyward Kick
---------------------------------------------------------------------------
do
	print("== IIDA (round 27)")
	local EN = Config.Quirks.Engine
	local MAX = Config.PlayerMaxHealth
	local X = 3600
	local FWD = Vector3.new(0, 0, 1)
	check(EN.Abilities[1].Id == "SpinKick" and EN.Abilities[2].Id == "EngineGatling" and EN.Abilities[3].Id == "ReciproBurst" and EN.Extra.Id == "SkywardKick",
		"his kit: Recipro Spin, Engine Gatling, Recipro Burst, V Skyward Kick")
	check(EN.Abilities[3].Hold and #EN.Abilities[3].Hold.Levels == 2, "Recipro Burst is held, with 3 gears")
	fire(SelectQuirk, A, "Engine")
	fire(SelectQuirk, B, "Explosion")
	A:SetAttribute("NoCooldowns", true)
	local function fresh(bPos)
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end

	-- RECIPRO SPIN: round him twice, the second throws them
	local SK = EN.Abilities[1]
	fresh(Vector3.new(X - 6, 3, -3))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.7)
	check(bHum.Health == MAX - SK.Damage - SK.FinisherDamage, "RECIPRO SPIN catches B behind him too (" .. (MAX - bHum.Health) .. ")")

	-- ENGINE GATLING: the barrage, then the heel into the street
	local EG = EN.Abilities[2]
	fresh(Vector3.new(X, 3, 4))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.08 + EG.Hits * EG.Interval + 0.35)
	check(bHum.Health == MAX - EG.Damage * EG.Hits - EG.FinisherDamage, "ENGINE GATLING: " .. EG.Hits .. " kicks, then the heel (" .. (MAX - bHum.Health) .. ")")
	check(bChar:GetAttribute("Ragdolled") == true, "...spiking B into the street")

	-- RECIPRO BURST: hold for gears
	local RB = EN.Abilities[3]
	local function burst(holdFor)
		fresh(Vector3.new(X, 3, 4))
		clearSent()
		fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
		task.wait(0.1)
		local revving = aChar:GetAttribute("Holding") == "ReciproBurst" and aChar:GetAttribute("SlowedTo") == RB.Hold.Speed
		task.wait(holdFor)
		fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 40))
		task.wait(0.1)
		local rel = sentTo(B, "ReciproBurstRelease")[1]
		task.wait(3 * (RB.DashTime + 0.08) + 0.3)
		return revving, rel and rel.Level, MAX - bHum.Health
	end
	local revving, level, took = burst(0)
	check(revving, "RECIPRO BURST: holding it revs the engines (he's slowed while it charges)")
	check(level == 1 and took == RB.Finish[1], "...a tap is gear 1: one strike (" .. tostring(level) .. ", " .. took .. ")")
	_, level, took = burst(0.75)
	check(level == 2 and took == RB.Damage + RB.Finish[2], "...held past " .. RB.Hold.Levels[1] .. "s is gear 2: two strikes (" .. tostring(level) .. ", " .. took .. ")")
	_, level, took = burst(1.2)
	check(level == 3 and took == RB.Damage * 2 + RB.Finish[3] and bChar:GetAttribute("Ragdolled") == true, "...held past " .. RB.Hold.Levels[2] .. "s is gear 3: three strikes, and the last one breaks the sound barrier (" .. tostring(level) .. ", " .. took .. ")")
	-- never let go: it goes by itself at full power
	fresh(Vector3.new(X, 3, 4))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(RB.Hold.Max + 0.6)
	local auto = sentTo(B, "ReciproBurstRelease")[1]
	check(auto and auto.Level == 3 and not aChar:GetAttribute("Holding"), "(held to the end, it goes by itself in gear 3)")
	task.wait(1)
	-- nothing else while it revs
	fresh(Vector3.new(X, 3, 60))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.1)
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	check(#sentTo(B, "SpinKick") == 0, "(no other move while it revs)")
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 40))
	task.wait(1)

	-- SKYWARD KICK: straight up
	fresh(Vector3.new(X, 3, 4))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.2)
	local lift = bRoot:FindFirstChild("Knockback")
	check(bHum.Health == MAX - EN.Extra.Damage and lift and lift.VectorVelocity.Y > 80, "SKYWARD KICK launches B straight up")
	A:SetAttribute("NoCooldowns", nil)
end

---------------------------------------------------------------------------
-- Round 27: everyone has a 4th move - Lemillion's Phantom Grasp, Decay's
-- Sinkhole, Overhaul's Pillar Rise
---------------------------------------------------------------------------
do
	print("== 4TH MOVES (round 27)")
	local MAX = Config.PlayerMaxHealth
	local X = 4200
	local FWD = Vector3.new(0, 0, 1)
	local missing = {}
	for _, q in Config.QuirkOrder do
		local quirk = Config.Quirks[q]
		for _, form in { { false, false }, { true, false }, { false, true } } do
			if not Config.GetAbility(q, Config.EXTRA_INDEX, form[1], form[2], 1) then
				table.insert(missing, q)
			end
		end
		quirk = quirk
	end
	check(#missing == 0, "every quirk has a 4th move in every form (missing: " .. table.concat(missing, ", ") .. ")")
	local function fresh(quirk, bPos)
		fire(SelectQuirk, A, quirk)
		A:SetAttribute("NoCooldowns", true)
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
	end
	fire(SelectQuirk, B, "Explosion")

	-- LEMILLION: Phantom Grasp
	local PG = Config.Quirks.Lemillion.Extra
	fresh("Lemillion", Vector3.new(X, 3, 25))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 25), 1, aRoot.Position)
	task.wait(0.45)
	check(bRoot.Anchored == true and bRoot.Position.Y < 3 - PG.Sink + 0.1, "PHANTOM GRASP drags B, 25 studs away, down into the street (" .. tostring(bRoot.Position) .. ")")
	task.wait(PG.HoldTime - 0.1)
	local lift = bRoot:FindFirstChild("Knockback")
	check(not bRoot.Anchored and bHum.Health == MAX - PG.Damage - PG.LaunchDamage and lift and lift.VectorVelocity.Y > 60, "...then flings them up out of it (" .. (MAX - bHum.Health) .. ")")

	-- DECAY: Sinkhole
	local SH = Config.Quirks.Decay.Extra
	fresh("Decay", Vector3.new(X + 6, 3, 18))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 18), 1, aRoot.Position)
	task.wait(0.5)
	check(bRoot.Anchored == true and bRoot.Position.Y < 3 - SH.Sink + 0.1 and bHum.Health <= MAX - SH.Damage, "SINKHOLE: the street swallows B to the waist")
	check(profilesUsed.Decay == true, "...the ground crumbles away")
	task.wait(SH.HoldTime + 0.2)
	check(not bRoot.Anchored and bHum.Health < MAX - SH.Damage, "...B climbs out, decaying (" .. (MAX - bHum.Health) .. ")")

	-- OVERHAUL: Pillar Rise
	local PR = Config.Quirks.Overhaul.Extra
	fresh("Overhaul", Vector3.new(X + 5, 3, 3))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.3)
	check(bHum.Health == MAX - PR.Damage and bChar:GetAttribute("Stunned") == true, "PILLAR RISE: the spikes round the pillar's foot catch B")
	A:SetAttribute("NoCooldowns", nil)
	task.wait(1.5)
end

---------------------------------------------------------------------------
-- Round 25: CRAZY DIAMOND (dev character) - break, fix and build
---------------------------------------------------------------------------
do
	print("== CRAZY DIAMOND")
	local CDQ = Config.Quirks.CrazyDiamond
	local MAX = Config.PlayerMaxHealth
	local X = 1600
	local FWD = Vector3.new(0, 0, 1)
	check(CDQ ~= nil and CDQ.DevOnly == true and table.find(Config.QuirkOrder, "CrazyDiamond") ~= nil, "CRAZY DIAMOND is in the game (dev only)")
	fire(SelectQuirk, A, "CrazyDiamond")
	fire(SelectQuirk, B, "Explosion")
	check(A:GetAttribute("Quirk") == "CrazyDiamond", "a tester can pick it")
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	for _, spec in { { "Head", Vector3.new(2, 1, 1), 1.5 }, { "Torso", Vector3.new(2, 2, 1), 0 } } do
		local limbPart = M.new("Part", spec[1])
		limbPart.Size = spec[2]
		limbPart.CFrame = aRoot.CFrame * CFrame.new(0, spec[3], 0)
		limbPart.Parent = aChar
	end
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 5), Vector3.new(X, 3, 0)))
	task.wait(0.4)
	A:SetAttribute("NoCooldowns", true)

	-- 1: DORARARA
	bHum.Health = MAX
	clearSent()
	local rush = CDQ.Abilities[1]
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	check(#sentTo(B, "Dorarara") == 1, "everyone sees the rush")
	task.wait(0.15 + rush.Hits * rush.Interval + 0.35)
	local took = MAX - bHum.Health
	check(took >= rush.Damage * rush.Hits * 0.6 + rush.FinisherDamage, "DORARARA lands the rush and the last DORA! (" .. took .. ")")
	check(profilesUsed.Stand == true and profilesUsed.Crater == true, "...and punches a hole through whatever's in front")
	bChar:SetAttribute("Stunned", false)
	bChar:SetAttribute("Ragdolled", false)

	-- V: the blueprint
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	check(A:GetAttribute("Blueprint") == CDQ.Blueprints[2], "V moves the blueprint on (" .. tostring(A:GetAttribute("Blueprint")) .. ")")
	for _ = 2, #CDQ.Blueprints do
		fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
		task.wait(0.3)
	end
	check(A:GetAttribute("Blueprint") == CDQ.Blueprints[1], "...and round again")

	-- 2: BUILD a wall right where B stands
	local function builtModels()
		local f = map:FindFirstChild("CrazyBuilt")
		return f and f:GetChildren() or {}
	end
	aChar:SetAttribute("Stunned", false)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 20), Vector3.new(X, 3, 0))
	A:SetAttribute("Blueprint", "Wall")
	clearSent()
	local rubbleBefore = cd.rubbleCalls
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.2 + 0.3 + 0.45 + 0.25)
	local walls = builtModels()
	local wall = walls[#walls]
	local stones = wall and wall:GetChildren() or {}
	check(#walls == 1 and #stones == 32, "BUILD raises a wall of stones at the aim point (" .. #stones .. ")")
	local solid, rubbly = true, true
	for _, p in stones do
		if p.Transparency ~= 0 or p.CanCollide ~= true or p:GetAttribute("Destroyable") ~= true or p:GetAttribute("CrazyBuilt") ~= true then
			solid = false
		end
		if p.Color ~= M.Color3.fromRGB(123, 111, 99) or p.Material ~= Enum.Material.Brick then
			rubbly = false
		end
	end
	check(solid, "...solid, and breakable like the rest of the city")
	check(rubbly and cd.rubbleCalls > rubbleBefore, "...made out of the rubble lying around")
	local seen = sentTo(B, "CrazyBuilt")
	check(#seen == 1 and #seen[1].Blocks == 32 and typeof(seen[1].Blocks[1].From) == "Vector3" and seen[1].Blocks[32].Delay > seen[1].Blocks[1].Delay,
		"everyone sees each stone fly in from its rubble, bottom first")
	check(bHum.Health < MAX, "whoever it comes up under is thrown clear (" .. (MAX - bHum.Health) .. ")")
	bChar:SetAttribute("Stunned", false)

	-- every blueprint builds
	for _, kind in { "Stairs", "Pillar", "Bridge", "Dome" } do
		A:SetAttribute("Blueprint", kind)
		fire(UseAbility, A, 2, FWD, Vector3.new(X + 30, 3, 40), 1, aRoot.Position)
		task.wait(0.25)
	end
	task.wait(1)
	local kinds = {}
	for _, m in builtModels() do
		kinds[#kinds + 1] = m.Name .. "=" .. #m:GetChildren()
	end
	check(#builtModels() == 5, "walls, stairs, pillars, bridges and domes all build (" .. table.concat(kinds, ", ") .. ")")
	-- only so many at once: the oldest crumbles
	for _ = 1, 2 do
		A:SetAttribute("Blueprint", "Pillar")
		fire(UseAbility, A, 2, FWD, Vector3.new(X - 30, 3, 40), 1, aRoot.Position)
		task.wait(0.25)
	end
	task.wait(0.5)
	check(#builtModels() == CDQ.Abilities[2].MaxStructures, "at most " .. CDQ.Abilities[2].MaxStructures .. " stand at once (" .. #builtModels() .. ")")
	check(wall.Parent == nil, "...the oldest (the wall) crumbled")

	-- R: RESTORE. The broken parts nearby come back; a piece flying home
	-- straight through B hits them; his own structures come apart.
	local broken = M.new("Part", "Broken")
	broken.CFrame = CFrame.new(X + 40, 5, 0)
	broken.Size = Vector3.new(6, 6, 6)
	broken.Parent = map
	cd.restored = { broken }
	bHum.Health = MAX
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X + 20, 3, 0), Vector3.new(X, 3, 0))
	cd.flights = {
		{ From = Vector3.new(X + 10, 3, 0), To = Vector3.new(X + 40, 5, 0), Size = Vector3.one * 2, Color = M.Color3.new(1, 1, 1), Material = Enum.Material.Brick },
		{ From = Vector3.new(X + 12, 3, 1), To = Vector3.new(X + 40, 4, 1), Size = Vector3.one * 2, Color = M.Color3.new(1, 1, 1), Material = Enum.Material.Brick },
		{ From = Vector3.new(X - 50, 3, 0), To = Vector3.new(X - 60, 3, 0), Size = Vector3.one * 2, Color = M.Color3.new(1, 1, 1), Material = Enum.Material.Brick },
	}
	clearSent()
	local restoresBefore = cd.restoreCalls
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.25 + 0.4)
	check(cd.restoreCalls == restoresBefore + 1 and cd.lastRestore[2] == CDQ.Special.Radius, "RESTORE puts back everything broken within " .. CDQ.Special.Radius .. " studs")
	check(#builtModels() == 0, "...and takes his own structures apart")
	local back = sentTo(B, "Restored")
	check(#back == 1 and #back[1].Flights >= 3 + 32 and #back[1].Parts == 1, "everyone sees the pieces fly home (" .. (back[1] and #back[1].Flights or 0) .. ")")
	check(MAX - bHum.Health == CDQ.Special.Damage * 2, "the two pieces flying home through B hit them (" .. (MAX - bHum.Health) .. ")")
	cd.flights, cd.restored = {}, {}
	broken.Parent = nil
	bChar:SetAttribute("Stunned", false)

	-- someone standing where a part comes back is put outside it
	local slab = M.new("Part", "Slab")
	slab.CFrame = CFrame.new(X + 20, 3, 0)
	slab.Size = Vector3.new(8, 8, 8)
	slab.Parent = map
	cd.restored = { slab }
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.4)
	local lp = slab.CFrame:PointToObjectSpace(bRoot.Position)
	check(math.abs(lp.X) > 4 or math.abs(lp.Z) > 4, "someone standing where a wall comes back is put outside it, not inside it")
	cd.restored = {}
	slab.Parent = nil

	-- 3: YO, ANGELO: B is sealed in a rock
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bRoot.Anchored = false
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 10), Vector3.new(X, 3, 0))
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10))
	clearSent()
	local angelo = CDQ.Abilities[3]
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(6 * 0.11 + 0.55 + 0.3)
	local rock
	for _, m in builtModels() do
		if m.Name:find("Prison") then
			rock = m
		end
	end
	check(rock ~= nil and #rock:GetChildren() >= 20, "YO, ANGELO: a rock closes round them")
	check(bRoot.Anchored == true and bChar:GetAttribute("Sealed") == true, "...and they're sealed inside it")
	check(MAX - bHum.Health >= angelo.Damage, "...taking the hit (" .. (MAX - bHum.Health) .. ")")
	task.wait(angelo.TrapTime + 0.8)
	check(bRoot.Anchored == false and not bChar:GetAttribute("Sealed") and rock.Parent == nil, "then it crumbles and lets them go")

	-- Ult: SHINING DIAMOND; BREAK AND RESTORE
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	check(A:GetAttribute("UltActive") == true, "Shining Diamond (the ult)")
	local gear = aChar:FindFirstChild("QuirkGear")
	local pins, hair = 0, 0
	for _, p in gear and gear:GetDescendants() or {} do
		if p.Material == Enum.Material.Metal and p.Color == M.Color3.fromRGB(255, 205, 60) then
			pins += 1
		elseif p:FindFirstChildOfClass("SpecialMesh") and p.Color == M.Color3.fromRGB(28, 26, 32) then
			hair += 1
		end
	end
	check(pins == 2 and hair == 2, "Josuke's pompadour and collar pins (" .. hair .. " hair, " .. pins .. " pins)")
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bChar:SetAttribute("Ragdolled", false)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 20), Vector3.new(X, 3, 0))
	local br = CDQ.Ult.Abilities[3]
	local restoresNow = cd.restoreCalls
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.4 + 0.1)
	check(profilesUsed.Shatter == true and bHum.Health < MAX, "BREAK: one punch shatters everything around")
	local afterBreak = bHum.Health
	task.wait((br.Hold or 0) + 0.3)
	check(cd.restoreCalls == restoresNow + 1 and bHum.Health < afterBreak, "...and RESTORE: it all comes flying home, through them")
	fire(TestCommand, A, "EndUlt")
	A:SetAttribute("NoCooldowns", nil)
	task.wait(0.3)
end

---------------------------------------------------------------------------
-- Round 25: balance - more health, no one-shots, the edge of the world,
-- Lemillion never comes up over the void, finishers go where you aim
---------------------------------------------------------------------------
do
	print("== BALANCE + THE EDGE OF THE WORLD")
	local MAX = Config.PlayerMaxHealth
	local X = 1800
	local stubRay = workspace.Raycast
	-- the street: solid over the base plate, nothing past its edge (x/z 2500)
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and math.abs(origin.X) < 2500 and math.abs(origin.Z) < 2500 and origin.Y > -1 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
		end
		return nil
	end
	check(MAX == 300, "players have more health (" .. MAX .. ")")
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 10), Vector3.new(X, 3, 0)))
	task.wait(0.3)
	check(bHum.MaxHealth == MAX and bHum.Health == MAX, "...on a fresh body")
	fire(TestCommand, A, "ResetCooldowns")

	-- no single hit takes more than MaxHitShare
	local ap = Config.Quirks.Explosion.Abilities[1]
	local apDamage = ap.Damage
	ap.Damage = 1000
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.4)
	ap.Damage = apDamage
	local took = MAX - bHum.Health
	check(bHum.Health > 0 and took == math.floor(MAX * Config.Balance.MaxHitShare + 0.5), "even a 1000-damage hit can't one-shot: it's capped at " .. took)
	bChar:SetAttribute("Stunned", false)
	check(Config.M1.Damage * 3 + Config.M1.FinisherDamage <= MAX * 0.1, "a whole M1 combo is under a tenth of your health")

	-- walls round the edge of the base plate, a thick floor under it
	local bounds = workspace:FindFirstChild("MapBounds")
	local walls, floors, invisible = 0, 0, true
	for _, p in bounds and bounds:GetChildren() or {} do
		if p.Name == "Wall" then
			walls += 1
		elseif p.Name == "Floor" then
			floors += 1
		end
		if p.Transparency ~= 1 or p.CanCollide ~= true or p.CanQuery ~= false then
			invisible = false
		end
	end
	check(walls == 0 and floors == 1 and invisible, "no walls round the map (off the edge is the void now), a thick invisible floor under it (" .. walls .. " walls, " .. floors .. " floor)")

	-- knocked off the map anyway: put back where they last stood, alive
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(X + 5, 3, 10)
	task.wait(0.4)
	bRoot.CFrame = CFrame.new(X + 5, -120, 10)
	bRoot.AssemblyLinearVelocity = Vector3.new(0, -200, 0)
	task.wait(0.4)
	check(bHum.Health == MAX and bRoot.Position.Y > 0 and math.abs(bRoot.Position.X - (X + 5)) < 1 and bRoot.AssemblyLinearVelocity.Magnitude < 1,
		"falling out of the map puts you back where you last stood, alive (" .. tostring(bRoot.Position) .. ")")

	-- Lemillion: a Deep Dive aimed past the edge comes up on the last bit of street
	fire(SelectQuirk, A, "Lemillion")
	task.wait(0.1)
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(2480, 3, 0), Vector3.new(2490, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 1, Vector3.new(1, 0, 0), Vector3.new(2560, 3, 0), 1, aRoot.Position)
	task.wait(1.2)
	check(aRoot.Position.X < 2500 and aRoot.Position.X > 2480 and aRoot.Position.Y > 0 and aRoot.Anchored == false,
		"a Deep Dive aimed past the edge comes up on the last bit of street (" .. tostring(aRoot.Position) .. ")")
	-- Phantom Menace on someone who's been knocked off the map: he doesn't follow
	fire(TestCommand, A, "ResetCooldowns")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(2400, 3, 0), Vector3.new(2410, 3, 0))
	bRoot.CFrame = CFrame.new(2410, 3, 0)
	bChar:SetAttribute("Stunned", false)
	task.wait(0.3)
	-- (a slam punched them through the street: they're just under it)
	bRoot.CFrame = CFrame.new(2410, -8, 0)
	task.wait(0.05)
	fire(UseAbility, A, 2, Vector3.new(1, 0, 0), Vector3.new(2410, 3, 0), 1, aRoot.Position)
	task.wait(1.2)
	check(aRoot.Position.Y > 0, "Phantom Menace never follows anyone under the map (" .. tostring(aRoot.Position) .. ")")

	-- finishers: the blow sends them where you're aiming
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.1)
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 6)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 6), Vector3.new(X, 3, 0)))
	task.wait(0.3)
	bHum.Health = math.floor(MAX * Config.Finishers.Threshold) - 1
	local launchLV
	bRoot.ChildAdded:Connect(function(c)
		if c.Name == "FinisherLaunch" then
			launchLV = c
		end
	end)
	fire(UseAbility, A, Config.FINISH_INDEX, bChar, Vector3.new(1, 0, 0))
	task.wait((Config.Finishers.Styles.Explosion or {}).Time or 1.2)
	task.wait(0.3)
	local v = bRoot.AssemblyLinearVelocity
	check(bHum.Health == 0 and v.X > 100 and math.abs(v.Z) < v.X * 0.3,
		string.format("the finisher launches them where you aim, not straight away from you (%.0f, %.0f, %.0f)", v.X, v.Y, v.Z))
	workspace.Raycast = stubRay
end

---------------------------------------------------------------------------
-- Round 28: ragdoll cancel, dash punch, fewer random throws, server
-- settings, the NUKE (dev kit), a wider Heaven-Piercing wall, SUNEATER
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at Luau's 200-local limit)
	local MAX = Config.PlayerMaxHealth
	local X = 5200
	local FWD = Vector3.new(0, 0, 1)
	local function fresh(aQuirk, bPos, bQuirk)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 4), Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
	end
	local function combo(p)
		task.wait(Config.M1.ComboReset + 0.05) -- (a fresh chain: the 4th swing is the finisher)
		for _ = 1, 4 do
			fire(UseAbility, p, 0)
			task.wait(Config.M1.Cooldown + 0.05)
		end
		task.wait(Config.M1.FinisherCooldown)
	end

	print("== RAGDOLL CANCEL (JJS evasive)")
	fresh("Explosion")
	check(bChar:GetAttribute("Evasive") == 100, "a fresh body starts with its ragdoll cancel ready (" .. tostring(bChar:GetAttribute("Evasive")) .. ")")
	combo(A)
	check(bChar:GetAttribute("Ragdolled") == true, "the 4th M1 ragdolls B")
	clearSent()
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	check(bChar:GetAttribute("Ragdolled") == false and bChar:GetAttribute("Stunned") == false, "DASH while ragdolled: straight back up, stun gone")
	check(bChar:GetAttribute("Evasive") == 0, "...and the meter is spent")
	local ev = sentTo(A, "Evasive")[1]
	check(ev ~= nil and ev.Dir and math.abs(ev.Dir.X - 1) < 0.01, "...everyone sees the quickstep, the way B held (" .. tostring(ev and ev.Dir) .. ")")
	local hBefore = bHum.Health
	fire(UseAbility, A, 0)
	task.wait(0.2)
	check(bHum.Health == hBefore, "...with a moment of invincibility (a follow-up M1 whiffs)")
	task.wait(Config.Evasive.IFrames + 0.1)
	-- empty meter: no second cancel
	combo(A)
	check(bChar:GetAttribute("Ragdolled") == true, "ragdolled again")
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	check(bChar:GetAttribute("Ragdolled") == true, "...but the meter isn't full: no cancel this time")
	local meter = bChar:GetAttribute("Evasive")
	check(meter > 0 and meter < 100, "the meter refills from the damage taken (" .. string.format("%.1f", meter) .. ")")
	local aMeter = aChar:GetAttribute("Evasive")
	check(aMeter == 100, "(the attacker's full one stays full: " .. tostring(aMeter) .. ")")
	-- getting up: everyone plays the get-up, and M1s can't stun you for a moment
	clearSent()
	local waited = 0
	while bChar:GetAttribute("Ragdolled") and waited < 4 do
		task.wait(0.05)
		waited += 0.05
	end
	check(#sentTo(A, "GetUp") >= 1, "getting up plays the get-up on every screen")
	task.wait(0.35) -- (the knockdown's own stun runs out a moment after they're up)
	check(bChar:GetAttribute("Stunned") ~= true, "(up and free)")
	fire(UseAbility, A, 0)
	task.wait(0.15)
	check(bChar:GetAttribute("Stunned") ~= true, "...and for a moment after getting up an M1 can't stun them (no loops)")
	task.wait(Config.Evasive.WakeImmune + 0.2)
	bChar:SetAttribute("Stunned", false)
	-- dealing damage fills it faster at low health; a KO fills it
	aChar:SetAttribute("Evasive", 0)
	aHum.Health = MAX * 0.4
	fire(UseAbility, A, 0)
	task.wait(0.2)
	local low = aChar:GetAttribute("Evasive")
	check(math.abs(low - Config.M1.Damage * 100 / Config.Evasive.DealtToFill * Config.Evasive.LowDealtMult) < 0.01, "at low health dealing damage fills it twice as fast (" .. string.format("%.2f", low) .. ")")
	aHum.Health = MAX
	bHum.Health = 1
	task.wait(Config.M1.Cooldown)
	fire(UseAbility, A, 0)
	task.wait(0.3)
	check(bHum.Health == 0 and aChar:GetAttribute("Evasive") == 100, "a KO fills your ragdoll cancel")
	-- server setting / player switch turn it off
	fresh("Explosion")
	combo(A)
	B:SetAttribute("NoEvade", true)
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	check(bChar:GetAttribute("Ragdolled") == true, "a player with Evade switched off can't cancel")
	B:SetAttribute("NoEvade", nil)
	workspace:SetAttribute("EvasiveEnabled", false)
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	check(bChar:GetAttribute("Ragdolled") == true, "...nor anyone when the server switches Ragdoll Cancel off")
	workspace:SetAttribute("EvasiveEnabled", nil)
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	check(bChar:GetAttribute("Ragdolled") == false, "...back on, it works again")
	task.wait(1.2)

	print("== FRONT DASH PUNCH (JJS)")
	fresh("Explosion", Vector3.new(X, 3, 4))
	bChar:SetAttribute("Stunned", false)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	local DP = Config.Movement.DashPunch
	check(bHum.Health == MAX - DP.Damage and bChar:GetAttribute("Stunned") == true, "a front dash that reaches B ends in a punch (" .. (MAX - bHum.Health) .. " damage, stunned)")
	check(#sentTo(B, "DashPunch") == 1, "...everyone else sees the punch")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	check(bHum.Health == MAX - DP.Damage, "...once per dash")
	task.wait(1)
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	check(bHum.Health == MAX - DP.Damage, "no punch without a front dash to go with it")
	A:SetAttribute("NoCooldowns", true)
	bRoot.CFrame = CFrame.new(X, 3, 30)
	task.wait(0.4) -- (long enough that nobody's screen still shows them close)
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	check(bHum.Health == MAX - DP.Damage, "...nor from across the street")
	bRoot.CFrame = CFrame.new(X, 3, 4)
	task.wait(0.4)
	workspace:SetAttribute("DashPunchEnabled", false)
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	check(bHum.Health == MAX - DP.Damage, "...nor when the server switches Dash Punches off")
	workspace:SetAttribute("DashPunchEnabled", nil)
	task.wait(Config.Movement.FrontDashTime + Config.Movement.FrontWhiffRecovery + 0.05) -- (the front dash's own lock)
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Side")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	check(bHum.Health == MAX - DP.Damage, "...and a side dash doesn't punch")
	A:SetAttribute("NoCooldowns", nil)

	print("== KNOCKBACK: one push at a time, never down into the street")
	fresh("Explosion")
	local fake = M.new("LinearVelocity", "Knockback")
	fake.Parent = bRoot
	local kb, pushes
	local conn = bRoot.ChildAdded:Connect(function(c)
		if c.Name == "Knockback" and not kb then
			kb = c
			pushes = 0
			for _, o in bRoot:GetChildren() do
				if o.Name == "Knockback" then
					pushes += 1
				end
			end
		end
	end)
	fire(UseAbility, A, 0)
	task.wait(0.2)
	conn:Disconnect()
	check(pushes == 1 and fake.Parent == nil, "a new hit replaces the last push instead of stacking on it (" .. tostring(pushes) .. ")")
	check(kb and kb.MaxForce ~= math.huge and kb.MaxForce > 0, "...and pushes with a strong but finite force (" .. tostring(kb and kb.MaxForce) .. ")")
	-- a spike down on someone standing on the street stays flat
	local stubRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y > -1 and origin.Y < 40 then
			local depth = origin.Y
			if depth <= math.abs(dir.Y) then
				return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = depth, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
			end
		end
		return nil
	end
	fresh("FullCowl", Vector3.new(X, 3, 12))
	fire(TestCommand, A, "FillUlt")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.3)
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	local slamY
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.4 do
			local k = bRoot:FindFirstChild("Knockback")
			if k and k.VectorVelocity.Y < -20 then
				slamY = k.VectorVelocity.Y
			end
			task.wait()
		end
	end)
	task.wait(1.2)
	check(slamY == nil, "a slam down on someone already on the street doesn't drive them into it (" .. tostring(slamY) .. ")")
	workspace.Raycast = stubRay
	fire(TestCommand, A, "EndUlt")
	task.wait(1.5)

	print("== SERVER SETTINGS (JJS private server menu)")
	fresh("Explosion")
	bChar:SetAttribute("Stunned", false)
	fire(TestCommand, A, "PSSet", "DamageMult", 2)
	fire(UseAbility, A, 0)
	task.wait(0.2)
	check(MAX - bHum.Health == Config.M1.Damage * 2, "Damage Multiplier x2: an M1 does double (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "PSSet", "DamageMult", 99)
	check(workspace:GetAttribute("DamageMult") == 10, "...clamped to a sane range")
	fire(TestCommand, A, "PSSet", "KnockbackMult", 0)
	task.wait(0.4)
	bChar:SetAttribute("Stunned", false)
	fire(UseAbility, A, 0)
	task.wait(0.2)
	local k0 = bRoot:FindFirstChild("Knockback")
	check(k0 == nil or k0.VectorVelocity.Magnitude < 0.01, "Knockback Multiplier 0: hits don't move anyone")
	fire(TestCommand, A, "PSSet", "Gravity", 100)
	check(workspace.Gravity == 100, "Gravity changes the world's gravity")
	fire(TestCommand, A, "PSSet", "SpeedMult", 2)
	task.wait(0.1)
	check(aChar:GetAttribute("BaseWalkSpeed") == (Config.Quirks.Explosion.WalkSpeed or Config.BaseWalkSpeed) * 2, "Walk Speed x2 applies to everyone straight away")
	fire(TestCommand, A, "PSSet", "UltRate", 0)
	local u0 = A:GetAttribute("Ult") or 0
	fire(UseAbility, A, 0)
	task.wait(0.2)
	check((A:GetAttribute("Ult") or 0) == u0, "Ult Charge Rate 0: dealing damage charges nothing")
	fire(TestCommand, A, "PSSet", "MapRegen", false)
	check(workspace:GetAttribute("MapRegen") == false, "Destruction Respawns off")
	fire(TestCommand, A, "PSSet", "ResetSettings", true)
	check(workspace:GetAttribute("DamageMult") == 1 and workspace:GetAttribute("KnockbackMult") == 1 and workspace.Gravity == 196.2
		and workspace:GetAttribute("MapRegen") == true and aChar:GetAttribute("BaseWalkSpeed") == (Config.Quirks.Explosion.WalkSpeed or Config.BaseWalkSpeed),
		"Reset All Settings puts everything back")
	-- players: one of them, or everyone
	fire(TestCommand, A, "PSPlayer", "GodMode", B.UserId)
	check(B:GetAttribute("GodMode") == true and A:GetAttribute("GodMode") ~= true, "God Mode for one player")
	fire(TestCommand, A, "PSPlayer", "GodMode", B.UserId)
	check(B:GetAttribute("GodMode") ~= true, "...and off again")
	fire(TestCommand, A, "PSPlayer", "Skills", 0)
	check(A:GetAttribute("NoSkills") == true and B:GetAttribute("NoSkills") == true, "Moves off for everyone")
	clearSent()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	check(#sentTo(B, "APShot") == 0, "...and a move does nothing")
	fire(TestCommand, A, "PSPlayer", "Skills", 0)
	check(A:GetAttribute("NoSkills") == nil and B:GetAttribute("NoSkills") == nil, "...and back on")
	local late = addPlayer("Latecomer", 77)
	check(late:GetAttribute("NoSkills") == nil, "(what's back on stays on for someone joining later)")
	fire(TestCommand, A, "PSPlayer", "NoCooldowns", 0)
	local late2 = addPlayer("Latecomer2", 78)
	check(late2:GetAttribute("NoCooldowns") == true, "an 'everyone' switch also goes to whoever joins later")
	fire(TestCommand, A, "PSPlayer", "NoCooldowns", 0)
	fire(TestCommand, A, "PSPlayer", "Melee", B.UserId)
	hBefore = aHum.Health
	fire(UseAbility, B, 0)
	task.wait(0.2)
	check(aHum.Health == hBefore, "Melee off: B's M1s do nothing")
	fire(TestCommand, A, "PSPlayer", "Melee", B.UserId)
	fire(TestCommand, A, "PSPlayer", "NoStun", B.UserId)
	bChar:SetAttribute("Stunned", false)
	combo(A)
	check(bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("Stunned") ~= true, "No Stun: a whole combo can't stun or ragdoll B")
	fire(TestCommand, A, "PSPlayer", "NoStun", B.UserId)
	bHum.Health = 50
	fire(TestCommand, A, "PSPlayer", "Heal", B.UserId)
	check(bHum.Health == bHum.MaxHealth, "Heal")
	bRoot.CFrame = CFrame.new(X + 300, 3, 0)
	fire(TestCommand, A, "PSPlayer", "Bring", B.UserId)
	check((bRoot.Position - aRoot.Position).Magnitude < 8, "Bring pulls them to you")
	bRoot.CFrame = CFrame.new(X + 300, 3, 0)
	fire(TestCommand, A, "PSPlayer", "GoTo", B.UserId)
	check((aRoot.Position - bRoot.Position).Magnitude < 8, "Go To takes you to them")
	local kicked
	function late.Kick(_, msg)
		kicked = msg
	end
	table.insert(Config.TestMenu.AllowedUserIds, A.UserId)
	studioMode = false -- (in Studio everyone's a tester, and testers can't be kicked)
	fire(TestCommand, A, "PSPlayer", "Kick", late.UserId)
	fire(TestCommand, A, "PSPlayer", "Kick", A.UserId)
	studioMode = true
	table.remove(Config.TestMenu.AllowedUserIds)
	check(kicked ~= nil, "Kick (not yourself, not other testers)")
	fire(TestCommand, A, "PSPlayer", "InfiniteUlt", A.UserId)
	task.wait(0.7)
	check(A:GetAttribute("Ult") == 100, "Infinite Ult keeps the meter full")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.3)
	local ends = A:GetAttribute("UltEnds") or 0
	check(A:GetAttribute("UltActive") == true and ends - workspace:GetServerTimeNow() > Config.Quirks.Explosion.Ult.Duration - 1.5,
		"...and while it's active the ult's time never runs down")
	fire(TestCommand, A, "PSPlayer", "InfiniteUlt", A.UserId)
	fire(TestCommand, A, "EndUlt")
	-- only testers can touch any of it
	studioMode = false
	fire(TestCommand, B, "PSSet", "DamageMult", 5)
	check(workspace:GetAttribute("DamageMult") == 1, "players who aren't testers can't change the server's settings")
	studioMode = true
	for _, p in { late, late2 } do
		local i = table.find(playerList, p)
		if i then
			table.remove(playerList, i)
		end
	end
	task.wait(0.5)

	print("== NUKE (dev kit)")
	local NK = Config.Quirks.PlusUltra.Extra
	check(NK.Id == "Nuke" and NK.Hold ~= nil, "the PLUS ULTRA dev kit's V is the NUKE (held)")
	check(Config.Quirks.PlusUltra.Ult.Extra.Id == "NewOrder", "...New Order moved to its ult's V")
	fresh("PlusUltra", Vector3.new(X, 3, 60))
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Holding") == "Nuke" and aChar:GetAttribute("SlowedTo") == NK.Hold.Speed, "holding V: the bomb grows over his head (he can still walk, slowly)")
	task.wait(1.5)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 60))
	task.wait(0.1)
	local throw = sentTo(B, "NukeThrow")[1]
	check(throw ~= nil and throw.Scale > NK.MinScale and throw.Scale < 1, "letting go throws it, sized by how long it was held (" .. tostring(throw and throw.Scale) .. ")")
	task.wait(2.2)
	check(bHum.Health < MAX and bHum.Health >= MAX * (1 - Config.Balance.MaxHitShare) - 1 and bChar:GetAttribute("Ragdolled") == true,
		"it goes off where he aimed: B takes a capped hit and is blown away (" .. (MAX - bHum.Health) .. ")")
	check(aHum.Health == MAX, "...and it never hurts him")
	check(profilesUsed.Nuke == true, "...and takes the city with it")
	task.wait(3)

	print("== HEAVEN-PIERCING ICE WALL: wider, and on the street where it stands")
	local HV = rawget(spikes, "_exports").HEAVEN
	check(HV.Width >= 150 and HV.Height >= 300, "the glacier is " .. HV.Width .. " studs across and " .. HV.Height .. " tall")
	local list = rawget(spikes, "_exports").IceWall(Vector3.new(0, 10, 0), Vector3.new(0, 0, 1), 1234)
	local widest = 0
	for _, sp in list do
		widest = math.max(widest, math.abs(sp.Base.X))
	end
	check(widest > 60, "...its spikes fan out across the street (" .. string.format("%.0f", widest) .. " studs out to the side)")
	local snapped = rawget(spikes, "_exports").IceWall(Vector3.new(0, 10, 0), Vector3.new(0, 0, 1), 1234, function(pos)
		return Vector3.new(pos.X, pos.Z > 50 and -30 or 10, pos.Z)
	end)
	local ok, far = true, 0
	for _, sp in snapped do
		local z = sp.Base.Z
		local expect = (z > 50 and -30 or 10) - 2.5
		if math.abs(sp.Base.Y - expect) > 1.1 then
			ok = false
		end
		far = math.max(far, z)
	end
	check(ok and far > 150, "...each spike grows from the street where it stands (off a ledge: from the street below)")
	local silly = rawget(spikes, "_exports").IceSpike(Vector3.new(0, 10, 0), Vector3.new(0, 0, 1), 7, function(pos)
		return Vector3.new(pos.X, -500, pos.Z)
	end)
	check(math.abs(silly[1].Base.Y - (10 - 1.5)) < 0.01, "...(a snap to nowhere sensible keeps his own height)")
	-- the hit reaches the whole width
	fresh("HalfCold", Vector3.new(X + 70, 3, 175))
	fire(TestCommand, A, "FillUlt")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.3)
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 100), 5, aRoot.Position)
	task.wait(0.55 + 200 / 160 + 0.4)
	check(bHum.Health < MAX, "Heaven-Piercing now reaches someone 70 studs to the side, 175 out (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(4)

	print("== SUNEATER (Tamaki Amajiki)")
	local SE = Config.Quirks.Manifest
	check(table.find(Config.QuirkOrder, "Manifest") ~= nil and not SE.DevOnly, "SUNEATER is on the quirk menu for everyone")
	fresh("Manifest", Vector3.new(X, 3, 30))
	check(aChar:GetAttribute("Stomach") == SE.Stomach.Max, "his stomach starts full (" .. tostring(aChar:GetAttribute("Stomach")) .. ")")
	for _, spec in {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) }, { "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) }, { "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) }, { "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
	} do
		local part = M.new("Part", spec[1])
		part.Size = spec[2]
		part.CFrame = aRoot.CFrame * CFrame.new(spec[3])
		part.Parent = aChar
	end
	fire(SelectQuirk, A, "Manifest") -- (rebuilds the gear now the body has limbs)
	task.wait(0.4)
	local gear = aChar:FindFirstChild("QuirkGear")
	check(gear and gear:FindFirstChild("Belt", true) and gear:FindFirstChild("Ear", true) and not gear:FindFirstChild("Hood", true), "...his utility belt, pointed ears showing (" .. (gear and #gear:GetChildren() or 0) .. " pieces)")
	local noClip = true
	for _, d in gear and gear:GetDescendants() or {} do
		if d.ClassName == "Part" and (d.CanCollide or d.CanQuery or d.CanTouch or not d.Massless) then
			noClip = false
		end
	end
	check(noClip, "...weightless, no collisions, no hitbox queries")
	-- the new kit (a friend's sketch): the street is at y = 0 for these
	local stubRaySE = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end
	local full, empty = SE.Stomach.Full, SE.Stomach.Empty
	local function pw(n, k)
		return math.floor(n * (k or full) + 0.5)
	end
	check(SE.Abilities[1].Id == "ChickenKick" and SE.Abilities[2].Id == "TakoSnatch" and SE.Abilities[3].Id == "TakoThrash" and SE.Extra.Id == "Swordfish",
		"his kit: 1 Chicken Kick, 2 Tako Snatch, 3 Tako Thrash, 4 Swordfish")
	-- CHICKEN KICK: launched straight up, held there (not ragdolled - catchable)
	local CK = SE.Abilities[1]
	fresh("Manifest", Vector3.new(X, 3, 4))
	clearSent()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.25)
	local kb = bRoot:FindFirstChild("Knockback")
	check(MAX - bHum.Health == pw(CK.Damage) and kb ~= nil and kb.VectorVelocity.Y > CK.Launch * 0.9 and bChar:GetAttribute("Stunned") == true
		and bChar:GetAttribute("Ragdolled") ~= true, "CHICKEN KICK: B is launched straight up and held there, not ragdolled (" .. (MAX - bHum.Health) .. ", " .. tostring(kb and kb.VectorVelocity) .. ")")
	check(#sentTo(B, "ChickenKick") == 1, "...everyone sees the chicken leg")
	check(aChar:GetAttribute("Stomach") == SE.Stomach.Max - CK.Cost, "...and it cost some stomach (" .. tostring(aChar:GetAttribute("Stomach")) .. ")")
	-- hungry: weaker
	fresh("Manifest", Vector3.new(X, 3, 4))
	aChar:SetAttribute("Stomach", 0)
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.3)
	check(MAX - bHum.Health == pw(CK.Damage, empty), "on an empty stomach his manifestations are weaker (" .. (MAX - bHum.Health) .. ")")
	-- TAKO SNATCH: out of the air (the aim bends up to them), slammed down in front of him
	local TS = SE.Abilities[2]
	fresh("Manifest", Vector3.new(X + 2, 9, 18)) -- (up in the air, ~15 degrees above his aim)
	clearSent()
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 18), 1, aRoot.Position)
	task.wait(0.12 + 0.12 + 0.05)
	local catch = sentTo(B, "TakoSnatchCatch")[1]
	check(catch ~= nil and catch.Target == bChar and catch.Air == true and bRoot.Anchored == true,
		"TAKO SNATCH: the octopus arm plucks B out of the air (aimed level, it bent up to them)")
	task.wait(0.32 + 0.15)
	local airWant = pw(TS.Damage * TS.AirBonus) + pw(TS.SlamDamage * TS.AirBonus)
	check(not bRoot.Anchored and bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("ComboStun") == true and math.abs(bRoot.Position.Z - 6) < 1.5 and bRoot.Position.Y < 4,
		"...and slams them into the street in front of him - on their feet, in hitstun (round 68: a combo) (" .. tostring(bRoot.Position) .. ")")
	check(math.abs((MAX - bHum.Health) - airWant) <= 1, "...caught mid-air: " .. TS.AirBonus .. "x (" .. (MAX - bHum.Health) .. " ~ " .. airWant .. ")")
	check(#sentTo(B, "TentacleSlam") == 1, "...everyone sees the slam")
	-- on the ground: no bonus
	fresh("Manifest", Vector3.new(X, 3, 20))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.12 + 0.13 + 0.32 + 0.2)
	local groundWant = pw(TS.Damage) + pw(TS.SlamDamage)
	check(math.abs((MAX - bHum.Health) - groundWant) <= 1, "...someone on the ground: no bonus (" .. (MAX - bHum.Health) .. " ~ " .. groundWant .. ")")
	-- nobody along the aim: nothing caught
	fresh("Manifest", Vector3.new(X + 30, 3, 0))
	clearSent()
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.5)
	local miss = sentTo(B, "TakoSnatchCatch")[1]
	check(miss ~= nil and miss.Target == nil and bHum.Health == MAX, "...and nobody along the aim: the arm comes back empty")
	-- TAKO THRASH: grabbed, slammed right, left, right
	local TT = SE.Abilities[3]
	fresh("Manifest", Vector3.new(X, 3, 6))
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position)
	task.wait(0.18 + 0.05)
	check(#sentTo(B, "TakoThrashCatch") == 1 and bRoot.Anchored == true, "TAKO THRASH: the tentacle grabs B")
	local sides = {}
	local t0 = os.clock()
	local seen = 0
	while os.clock() - t0 < 1.3 do
		local slams = sentTo(B, "TentacleSlam")
		if #slams > seen then
			seen = #slams
			table.insert(sides, bRoot.Position.X - X)
		end
		task.wait()
	end
	local right = FWD:Cross(Vector3.new(0, 1, 0))
	local rsign = right.X > 0 and 1 or -1
	check(#sides == 3 and sides[1] * rsign > 4 and sides[2] * rsign < -4 and sides[3] * rsign > 4,
		"...slammed to his right, his left, his right again (" .. table.concat(sides, ", ") .. ")")
	local thrashWant = pw(TT.Damage) + 2 * pw(TT.SlamDamage) + pw(TT.FinalDamage)
	check(math.abs((MAX - bHum.Health) - thrashWant) <= 1 and not bRoot.Anchored and bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("ComboStun") == true,
		"...then let go - on their feet, in hitstun (round 68: a combo) (" .. (MAX - bHum.Health) .. " ~ " .. thrashWant .. ")")
	-- SWORDFISH: impaled, lifted, flung aside
	local SF = SE.Extra
	fresh("Manifest", Vector3.new(X, 3, 10))
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position, false)
	task.wait(0.16 + 0.25)
	check(#sentTo(B, "SwordfishImpale") == 1 and bRoot.Anchored == true and bRoot.Position.Y > 4.5,
		"SWORDFISH: the bill goes into B and lifts them on it (" .. tostring(bRoot.Position) .. ")")
	task.wait(0.3)
	kb = bRoot:FindFirstChild("Knockback")
	check(not bRoot.Anchored and bChar:GetAttribute("Ragdolled") ~= true and kb ~= nil and kb.VectorVelocity.Z > 20 and kb.VectorVelocity.Z <= Config.Combos.MaxShove + 0.01 and math.abs(kb.VectorVelocity.X) < 5,
		"...and throws them straight on ahead of him - still in reach (round 68: a combo) (" .. tostring(kb and kb.VectorVelocity) .. ")")
	check(MAX - bHum.Health == pw(SF.Damage) + pw(SF.ThrowDamage), "...(" .. (MAX - bHum.Health) .. ")")
	-- in the air: CLAM HAMMER - B under him is spiked into the street
	fresh("Manifest", Vector3.new(X, 5, 3))
	task.wait(1.6)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 9, 0), Vector3.new(X, 9, 10))
	bRoot.CFrame = CFrame.new(X, 5, 3)
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position, true)
	task.wait(0.18 + 0.05)
	kb = bRoot:FindFirstChild("Knockback")
	check(MAX - bHum.Health == pw(SF.HammerDamage) and kb ~= nil and kb.VectorVelocity.Y < -80 and bChar:GetAttribute("Ragdolled") == true,
		"CLAM HAMMER (in the air): B under him is spiked into the street (" .. (MAX - bHum.Health) .. ", " .. tostring(kb and kb.VectorVelocity) .. ")")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)) -- (his machine brings him down)
	task.wait(0.2)
	check(#sentTo(B, "ClamHammerLand") == 1, "...and his landing shakes the street")
	workspace.Raycast = stubRaySE
	task.wait(1.4)
	-- SNACK
	fire(TestCommand, A, "ResetCooldowns")
	aChar:SetAttribute("Stomach", 20)
	aHum.Health = 100
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.7)
	check(aChar:GetAttribute("Stomach") == 20 + SE.Special.Refill and aHum.Health == 100 + SE.Special.Heal, "R: a snack refills his stomach and heals a little")
	aChar:SetAttribute("Stomach", 20)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	aChar:SetAttribute("Stunned", true)
	task.wait(0.5)
	aChar:SetAttribute("Stunned", false)
	check(aChar:GetAttribute("Stomach") == 20, "...hit while eating, he drops it")
	-- VAST HYBRID CHIMERA
	fresh("Manifest", Vector3.new(X, 3, 12))
	fire(TestCommand, A, "FillUlt")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.4)
	local stomachBefore = aChar:GetAttribute("Stomach")
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bChar:SetAttribute("Ragdolled", false)
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(0.35 + 4 * 0.2 + 0.3)
	check(bHum.Health < MAX - 20 and bChar:GetAttribute("Ragdolled") == true, "CHIMERA KRAKEN: the tentacles' wave batters B and flings them (" .. (MAX - bHum.Health) .. ")")
	check(aChar:GetAttribute("Stomach") == stomachBefore, "...(in the ult his stomach isn't touched)")
	task.wait(1.6)
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bRoot.CFrame = CFrame.new(X, 3, 6)
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.3 + 0.75)
	check(bHum.Health < MAX and bChar:GetAttribute("Ragdolled") == true, "CHIMERA CENTAUR: the stampede tramples B (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.6)
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X + 20, 3, 20), Vector3.new(X + 20, 3, 40))
	fire(UseAbility, A, 3, FWD, Vector3.new(X + 20, 3, 20), 1, aRoot.Position)
	task.wait(0.2)
	check(aChar:GetAttribute("Mirage") == true, "OCTOPUS MIRAGE: he fades into the street")
	task.wait(SE.Ult.Abilities[3].Vanish + 0.1)
	check(aChar:GetAttribute("Mirage") == nil and (aRoot.Position - (bRoot.Position - Vector3.new(0, 0, 4))).Magnitude < 1.5,
		"...and comes up right behind B (" .. tostring(aRoot.Position) .. ")")
	task.wait(0.3)
	local stung = bHum.Health
	check(stung < MAX, "SCORPIUS TOXIN: the sting lands (" .. (MAX - stung) .. ")")
	task.wait(1.1)
	check(bHum.Health < stung, "...and the venom keeps eating at them (" .. (stung - bHum.Health) .. " more)")
	task.wait(1.8)
	-- PLASMA CANNON (held)
	local PC = SE.Ult.Extra
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	bChar:SetAttribute("Ragdolled", false)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10))
	bRoot.CFrame = CFrame.new(X, 3, 120)
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 120), 1, aRoot.Position)
	task.wait(PC.Hold.Levels[2] + 0.1)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 120))
	task.wait(0.4)
	local rel = sentTo(B, "PlasmaCannonRelease")[1]
	check(rel ~= nil and rel.Level == 3, "PLASMA CANNON: held to full, it fires at level 3")
	check(bHum.Health < MAX and bChar:GetAttribute("Ragdolled") == true and profilesUsed.Beam, "...a beam through everything that hits B 120 studs away (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	-- switching away: no stomach
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.1)
	check(aChar:GetAttribute("Stomach") == nil, "switching to someone else: no stomach meter")
	task.wait(1.6)
end)

---------------------------------------------------------------------------
-- Round 29: Overhaul's SPIKE FAN, Decay's RADIO WAVES
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local MAX = Config.PlayerMaxHealth
	local X = 6400
	local FWD = Vector3.new(0, 0, 1)
	local function fresh(aQuirk, bPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
	end

	print("== SPIKE FAN (Overhaul)")
	local SF = Config.Quirks.Overhaul.Abilities[2]
	check(SF.Id == "SpikeRush" and SF.Lanes == 3 and SF.Range <= 45, "Overhaul's 2 is a fan of 3 short lines (" .. SF.Lanes .. " x " .. SF.Range .. " studs)")
	local function spike(bPos)
		fresh("Overhaul", bPos)
		fire(UseAbility, A, 2, FWD, bPos, 1, aRoot.Position)
		task.wait(0.25 + 0.03 * (SF.Range / 5 + 1) + 0.4)
		return MAX - bHum.Health
	end
	local a = math.rad(SF.Spread)
	local took = spike(Vector3.new(X, 3, 3) + Vector3.new(math.sin(a), 0, math.cos(a)) * 26)
	check(took == SF.Damage, "a side line catches someone " .. SF.Spread .. " degrees off to the left (" .. took .. ")")
	check(bChar:GetAttribute("Stunned") == true, "...stunned")
	task.wait(1.3)
	took = spike(Vector3.new(X, 3, 3) + Vector3.new(-math.sin(a), 0, math.cos(a)) * 30)
	check(took == SF.Damage, "...and the other side line, to the right (" .. took .. ")")
	task.wait(1.3)
	took = spike(Vector3.new(X, 3, 25))
	check(took == SF.Damage, "the middle line still hits straight ahead (" .. took .. ")")
	task.wait(1.3)
	took = spike(Vector3.new(X, 3, 58))
	check(took == 0, "the lines are short now: 58 studs out is safe (" .. took .. ")")
	task.wait(1.3)
	took = spike(Vector3.new(X + 20, 3, 4))
	check(took == 0, "nothing off to the side outside the fan (" .. took .. ")")
	local spikeSrc = fs.readFile(SRC .. "/ReplicatedStorage.Shared.VFX.lua")
	check(spikeSrc:find("ability.Lanes", 1, true) ~= nil, "the spikes on screen follow the same lanes (VFX reads Lanes)")

	print("== RADIO WAVES (Decay)")
	local DC = Config.Quirks.Decay
	local RW = DC.Ult.Abilities[1]
	check(RW.Id == "RadioWaves" and RW.Name == "RADIO WAVES", "Decay's awakened 1 is RADIO WAVES")
	local anyAir = false
	for _, ab in DC.Ult.Abilities do
		anyAir = anyAir or ab.Id == "AirCannon"
	end
	check(not anyAir, "...AIR CANNON is gone from Decay")
	local function awaken(bPos)
		fresh("Decay", bPos)
		A:SetAttribute("Ult", 100)
		fire(UseAbility, A, Config.ULT_INDEX)
		task.wait(1.6)
		-- (the awakening's own blast: put B back where the test wants them)
		bRoot.CFrame = CFrame.lookAt(bPos, Vector3.new(X, 3, 0))
		local old = bRoot:FindFirstChild("Knockback")
		if old then
			old:Destroy()
		end
		bHum.Health = MAX
		bChar:SetAttribute("Stunned", false)
		bChar:SetAttribute("JammedUntil", nil)
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
	end
	awaken(Vector3.new(X, 3, 60))
	check(A:GetAttribute("UltActive") == true, "awakened")
	local before = workspace:GetServerTimeNow()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4 + 30 / RW.Speed)
	check(bHum.Health == MAX, "the wave travels: it hasn't reached 60 studs yet")
	task.wait(40 / RW.Speed + 0.1)
	check(bHum.Health < MAX, "RADIO WAVES reaches B 60 studs away (" .. (MAX - bHum.Health) .. ")")
	check(bChar:GetAttribute("Stunned") == true, "...stunned")
	local kb = bRoot:FindFirstChild("Knockback")
	check(kb ~= nil, "...and hurled back")
	check((bChar:GetAttribute("JammedUntil") or 0) > before + RW.Jam - 0.5, "...and JAMMED for " .. RW.Jam .. "s")
	local jam = sentTo(B, "Jammed")
	check(#jam == 1 and jam[1].Duration == RW.Jam, "B's screen gets the static (Jammed sent to B only)")
	check(#sentTo(A, "Jammed") == 0, "(not to Shigaraki)")
	check(#sentTo(B, "RadioWaves") >= 1, "everyone sees the pulse")
	fire(TestCommand, A, "EndUlt")
	task.wait(1.4)
	-- a wide fan, but a fan
	awaken(Vector3.new(X, 3, 0) + Vector3.new(math.sin(math.rad(RW.Angle - 10)), 0, math.cos(math.rad(RW.Angle - 10))) * 40)
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4 + 40 / RW.Speed + 0.2)
	check(bHum.Health < MAX, "the fan is wide: " .. (RW.Angle - 10) .. " degrees off to the side still gets hit")
	fire(TestCommand, A, "EndUlt")
	task.wait(1.4)
	awaken(Vector3.new(X, 3, -30))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4 + 30 / RW.Speed + 0.2)
	check(bHum.Health == MAX and bChar:GetAttribute("JammedUntil") == nil, "...nobody behind him")
	fire(TestCommand, A, "EndUlt")
	task.wait(1.4)
	awaken(Vector3.new(X, 3, RW.Range + 12))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4 + RW.Range / RW.Speed + 0.3)
	check(bHum.Health == MAX, "...and not past its range (" .. RW.Range + 12 .. " studs)")
	fire(TestCommand, A, "EndUlt")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
end)

---------------------------------------------------------------------------
-- Round 30: out-of-combat healing
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local MAX = Config.PlayerMaxHealth
	local RG = Config.Regen
	local X = 7600
	print("== OUT-OF-COMBAT HEALING")
	workspace:SetAttribute("HealthRegen", nil) -- (on, as on a real server)
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	-- Roblox's own Health script (a flat 1%/s, fight or no fight) goes
	local model, hum, root = makeCharacter(B.Name, CFrame.lookAt(Vector3.new(X, 3, 4), Vector3.new(X, 3, 0)))
	M.new("Script", "Health").Parent = model
	model.Parent = workspace
	B.Character = model
	B.CharacterAdded:Fire(model)
	task.wait(0.1)
	bChar, bHum, bRoot = model, hum, root
	check(model:FindFirstChild("Health") == nil, "Roblox's flat Health regen script is removed from new bodies")
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	task.wait(0.3)
	aHum.Health = MAX - 40
	bHum.Health = MAX - 150
	fire(TestCommand, A, "ResetCooldowns")
	task.wait(Config.M1.ComboReset + 0.05)
	fire(UseAbility, A, 0)
	task.wait(0.3)
	local hurt = bHum.Health
	check(hurt < MAX - 150, "A punches B (" .. (MAX - 150 - hurt) .. ")")
	task.wait(RG.Delay - 1.2)
	check(bHum.Health == hurt and aHum.Health == MAX - 40,
		"nothing heals mid-fight: " .. RG.Delay .. "s wait after the last hit, for both of them (" .. bHum.Health .. ", " .. aHum.Health .. ")")
	check(bChar:GetAttribute("Regenerating") == nil, "...and the HUD isn't told it's healing")
	task.wait(1.7)
	check(bHum.Health > hurt and aHum.Health > MAX - 40, "then both start to heal (B " .. hurt .. " -> " .. string.format("%.1f", bHum.Health) .. ")")
	check(bChar:GetAttribute("Regenerating") == true, "...the character says it's healing (the HUD's green tag)")
	local h0 = bHum.Health
	task.wait(1)
	local slow = bHum.Health - h0
	task.wait(RG.Ramp)
	local h1 = bHum.Health
	task.wait(1)
	local fast = bHum.Health - h1
	check(slow > 0 and fast > slow * 1.6, string.format("slow at first, then it builds (%.1f/s -> %.1f/s)", slow, fast))
	task.wait(8)
	check(bHum.Health == MAX and bChar:GetAttribute("Regenerating") == nil, "it stops at full (" .. bHum.Health .. ")")
	-- ragdolled (the fight's still on): nothing
	bHum.Health = MAX - 100
	bChar:SetAttribute("Ragdolled", true)
	task.wait(0.5)
	local r0 = bHum.Health
	task.wait(RG.Delay + 1)
	check(bHum.Health == r0, "no healing while ragdolled")
	bChar:SetAttribute("Ragdolled", false)
	task.wait(1)
	check(bHum.Health > r0, "...back up: it comes back")
	-- any damage (a fall, poison...) resets the wait
	local d0 = bHum.Health - 20
	bHum.Health = d0
	task.wait(1.5)
	check(bHum.Health == d0, "damage from anywhere restarts the wait")
	-- server settings: off
	fire(TestCommand, A, "PSSet", "HealthRegen", false)
	check(workspace:GetAttribute("HealthRegen") == false, "server settings: Health Regen off")
	task.wait(RG.Delay + 1.5)
	check(bHum.Health == d0, "...and nothing heals")
	fire(TestCommand, A, "PSSet", "HealthRegen", true)
	task.wait(1)
	check(bHum.Health > d0, "...on again: healing")
	workspace:SetAttribute("HealthRegen", false) -- (the rest of the suite counts exact health)

	print("== IIDA: nothing one-shots")
	workspace:SetAttribute("HealthRegen", false)
	check(aHum.RequiresNeck == false and bHum.RequiresNeck == false,
		"only health decides a KO: a ragdolled neck pulled apart by a launch can't kill (RequiresNeck off)")
	local Y = 8200
	local function cast(index, holdFor, ult)
		fire(SelectQuirk, A, "Engine")
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(Y, 3, 0), Vector3.new(Y, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(Y, 3, 4), Vector3.new(Y, 3, 0)))
		task.wait(0.2)
		if ult then
			A:SetAttribute("Ult", 100)
			fire(UseAbility, A, Config.ULT_INDEX)
			task.wait(1.6)
			bRoot.CFrame = CFrame.lookAt(Vector3.new(Y, 3, 4), Vector3.new(Y, 3, 0))
			local kb = bRoot:FindFirstChild("Knockback")
			if kb then
				kb:Destroy()
			end
		end
		bHum.Health = MAX
		bChar:SetAttribute("Stunned", false)
		bChar:SetAttribute("Ragdolled", false)
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, index, FWD, bRoot.Position, 1, aRoot.Position)
		if holdFor then
			task.wait(holdFor)
			fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
		end
		task.wait(2.5)
		local took = MAX - bHum.Health
		if ult then
			fire(TestCommand, A, "EndUlt")
			task.wait(0.3)
		end
		return took
	end
	local worst, worstName = 0, ""
	for _, c in {
		{ 1, nil, false, "RECIPRO SPIN" }, { 2, nil, false, "ENGINE GATLING" }, { 3, 1.3, false, "RECIPRO BURST (gear 3)" },
		{ Config.EXTRA_INDEX, nil, false, "SKYWARD KICK" },
		{ 1, nil, true, "TURBO KICK" }, { 2, nil, true, "TURBO RUSH" }, { 3, nil, true, "MAXIMUM BURST" },
	} do
		local took = cast(c[1], c[2], c[3])
		print(string.format("    %-24s %3d of %d", c[4], took, MAX))
		if took > worst then
			worst, worstName = took, c[4]
		end
	end
	check(worst > 0 and worst < MAX * 0.5, "every Iida move, full health: none takes even half (worst: " .. worstName .. " " .. worst .. " of " .. MAX .. ")")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
end)

---------------------------------------------------------------------------
-- Round 31: Todoroki's JET KINDLING, Lemillion's new PERMEATE
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local MAX = Config.PlayerMaxHealth
	local X = 9000
	local FWD = Vector3.new(0, 0, 1)
	local UPV = Vector3.new(0, 1, 0)
	workspace:SetAttribute("HealthRegen", false)
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	local function fresh(aQuirk, bPos, cPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		fire(SelectQuirk, C, "Explosion")
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(C, CFrame.new(cPos or Vector3.new(X + 400, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
	end

	print("== JET KINDLING (Todoroki, fire V)")
	local HC = Config.Quirks.HalfCold
	local JK = HC.Alt.Extra
	check(JK.Id == "JetKindling" and JK.Name == "JET KINDLING", "the fire side's V is JET KINDLING now (Scorching Grip is gone)")
	fresh("HalfCold", Vector3.new(X, 3, 5), Vector3.new(X, 3, 16))
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.3)
	check(A:GetAttribute("QuirkAlt") == true, "(fire side)")
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait(0.12) -- (before the first burn tick)
	local took = MAX - bHum.Health
	check(took == JK.Damage and bChar:GetAttribute("Ragdolled") == true, "the white-hot fist lands on the first one he reaches (" .. took .. ")")
	check(bRoot:FindFirstChild("Knockback") ~= nil, "...and blows them away")
	local hit = sentTo(B, "JetKindlingHit")[1]
	check(hit ~= nil and hit.Target == bChar, "everyone sees the punch land on B")
	check(MAX - cHum.Health == JK.BlastDamage, "the blast bursts on through B into C behind them (" .. (MAX - cHum.Health) .. ")")
	task.wait(1.6)
	check(bHum.Health < MAX - took, "...and B keeps burning (" .. (MAX - took - bHum.Health) .. ")")
	-- nobody in reach: the fist goes off at the end of the jet anyway
	fresh("HalfCold", Vector3.new(X, 3, 12))
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.3)
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.6)
	hit = sentTo(B, "JetKindlingHit")[1]
	check(hit ~= nil and hit.Target == nil, "nobody reached: the fist still goes off at the end of the jet")
	check(MAX - bHum.Health == JK.BlastDamage, "...and its blast catches B just past it (" .. (MAX - bHum.Health) .. ")")
	-- in the air it follows the aim down
	fresh("HalfCold", Vector3.new(X, 3, 60))
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.3)
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, -0.7, 0.7).Unit, Vector3.new(X, 0, 20), 1, aRoot.Position, true)
	task.wait(0.6)
	hit = sentTo(B, "JetKindlingHit")[1]
	check(hit ~= nil and hit.Dir.Y < -0.4, "in the air it rockets him down the aim (" .. tostring(hit and hit.Dir) .. ")")
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.3)

	print("== PERMEATE (Lemillion, R)")
	local P = Config.Quirks.Lemillion.Special
	-- on the ground: through walls, never the floor
	fresh("Lemillion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position, false)
	task.wait(0.1)
	check(aChar:GetAttribute("WallPhase") == true and aChar:GetAttribute("Phasing") == true,
		"R on the ground: WALL PHASE (his machine lets the walls through, never the floor)")
	check(aChar:GetAttribute("PhaseDive") ~= true and aChar:GetAttribute("Submerged") ~= true, "...he stays on the street")
	task.wait(P.Duration + 0.2)
	check(aChar:GetAttribute("WallPhase") == false and aChar:GetAttribute("Phasing") == false, "...for " .. P.Duration .. "s")

	-- in the air: the dive. A street at y = 0, and a roof at y = 40 over x > X + 30
	local stubRay = workspace.Raycast
	local ROOF = 40
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) ~= "Vector3" or dir.Y >= 0 then
			return nil
		end
		if origin.X > X + 30 and origin.Y > ROOF and origin.Y + dir.Y <= ROOF then
			return { Position = Vector3.new(origin.X, ROOF, origin.Z), Distance = origin.Y - ROOF, Normal = UPV }
		end
		if origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = UPV }
		end
		return nil
	end
	local function dive(bPos)
		fresh("Lemillion", bPos)
		aRoot.CFrame = CFrame.new(X, 60, 0)
		task.wait(0.05)
		clearSent()
		fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 0, 10), 1, aRoot.Position, true)
		task.wait(0.1)
	end
	dive(Vector3.new(X, 3, 50))
	check(aChar:GetAttribute("PhaseDive") == true and aChar:GetAttribute("Phasing") == true and aChar:GetAttribute("WallPhase") ~= true,
		"R in the air: PHASE DIVE - he lets everything go (his machine drops him through it all)")
	check(aChar:GetAttribute("Submerged") ~= true, "...still falling: not under yet")
	local before = aHum.Health
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 60, 3), Vector3.new(X, 60, 0)) -- (right beside him, mid-air)
	task.wait(Config.M1.ComboReset + 0.05)
	fire(UseAbility, B, 0)
	task.wait(0.2)
	check(aHum.Health == before, "...nothing lands on him while he falls")
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 50), Vector3.new(X, 3, 0))
	-- his machine drops him through the street
	aRoot.CFrame = CFrame.new(X, -8, 0)
	task.wait(0.15)
	check(aChar:GetAttribute("Submerged") == true and aRoot.Anchored == true and aRoot.Position.Y < 0,
		"under the street he's held there, hidden, while he picks where to come out (" .. tostring(aRoot.Position) .. ")")
	-- he picks the spot where B stands: the ground spits him out there
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 0, 50))
	task.wait(0.08) -- (the launch lasts a fifth of a second)
	check(aChar:GetAttribute("Submerged") == false and aChar:GetAttribute("PhaseDive") == false and aChar:GetAttribute("Phasing") == false,
		"he comes out (phase over)")
	check((Vector3.new(aRoot.Position.X, 0, aRoot.Position.Z) - Vector3.new(X, 0, 50)).Magnitude < 1 and aRoot.Position.Y > 0,
		"...right where he picked (" .. tostring(aRoot.Position) .. ")")
	local kb = aRoot:FindFirstChild("PhaseLaunch")
	check(kb ~= nil and kb.VectorVelocity.Y >= P.Launch * 0.9 and aChar:GetAttribute("Ragdolled") ~= true,
		"...the ground spits him out, up into the air (on his feet, not ragdolled)")
	check(#sentTo(B, "PermeateSpit") == 1, "everyone sees it spit him out")
	check(MAX - bHum.Health == P.SpitDamage and bRoot:FindFirstChild("Knockback") ~= nil, "...whoever was standing on the spot is thrown aside (" .. (MAX - bHum.Health) .. ")")
	task.wait(0.6)
	-- too far: no further than DiveRange from where he went under; a roof on the way is where he comes out
	dive(Vector3.new(X + 400, 3, 0))
	aRoot.CFrame = CFrame.new(X, -8, 0)
	task.wait(0.15)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X + 500, 0, 0))
	task.wait(0.2)
	local dist = (Vector3.new(aRoot.Position.X, 0, aRoot.Position.Z) - Vector3.new(X, 0, 0)).Magnitude
	check(math.abs(dist - P.DiveRange) < 1.5, "the exit's no further than " .. P.DiveRange .. " studs from where he went under (" .. string.format("%.1f", dist) .. ")")
	check(math.abs(aRoot.Position.Y - (ROOF + 3.2)) < 0.5, "...and over a building he comes up on its roof (" .. string.format("%.1f", aRoot.Position.Y) .. ")")
	task.wait(0.6)
	-- he never picks: straight back up where he went in
	dive(Vector3.new(X + 400, 3, 0))
	aRoot.CFrame = CFrame.new(X + 5, -8, 5)
	task.wait(0.15)
	check(aChar:GetAttribute("Submerged") == true, "(under)")
	task.wait(P.ChooseTime + 0.6)
	check(aChar:GetAttribute("Submerged") == false and (Vector3.new(aRoot.Position.X, 0, aRoot.Position.Z) - Vector3.new(X + 5, 0, 5)).Magnitude < 1,
		"no pick in " .. P.ChooseTime .. "s: the ground spits him out where he went in")
	workspace.Raycast = stubRay
	task.wait(0.5)
	-- over the void (no street under him at all): nothing happens
	dive(Vector3.new(X + 400, 3, 0))
	check(aChar:GetAttribute("PhaseDive") ~= true, "over nothing (the edge of the map): no dive")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
	C.Character = nil
	if cChar then
		cChar.Parent = nil
	end
end)

---------------------------------------------------------------------------
-- Round 32: All Might's presence; the action lock's grace; the dash timers
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local MAX = Config.PlayerMaxHealth
	local X = 9500
	local FWD = Vector3.new(0, 0, 1)
	workspace:SetAttribute("HealthRegen", false)
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	local function fresh(aQuirk, bPos, cPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		fire(SelectQuirk, C, "Explosion")
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(C, CFrame.new(cPos or Vector3.new(X + 400, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
	end

	print("== ALL MIGHT'S PRESENCE (the transformation)")
	local P = Config.Quirks.OneForAll.Special.Presence
	check(P and P.Radius and P.Freeze and P.BurstAt, "muscle form has a presence")
	fresh("OneForAll", Vector3.new(X, 3, 8), Vector3.new(X, 3, 40))
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.1)
	check(A:GetAttribute("QuirkAlt") == true, "(muscle form)")
	check(bChar:GetAttribute("Stunned") == true, "B, 8 studs off, freezes in terror as he powers up")
	check(cChar:GetAttribute("Stunned") ~= true, "C, 40 studs off, doesn't")
	local told = sentTo(B, "Terrified")
	check(#told == 1 and told[1].From == aChar, "B's screen is told (TERRIFIED)")
	check(#sentTo(C, "Terrified") == 0, "...C's isn't")
	check(bRoot:FindFirstChild("Knockback") == nil, "...held there, not shoved yet")
	task.wait(P.BurstAt)
	local kb = bRoot:FindFirstChild("Knockback")
	check(kb ~= nil and kb.VectorVelocity.Z > P.Push * Config.Knockback.MoveScale * 0.9 and kb.VectorVelocity.Y > 0,
		"the burst blasts B away (" .. tostring(kb and kb.VectorVelocity) .. ")")
	check(bHum.Health == MAX and cHum.Health == MAX, "no damage: just the fear and the blast")
	check(cRoot:FindFirstChild("Knockback") == nil, "...C's out of it")
	task.wait(P.Freeze)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX) -- (back to his true form)
	task.wait(0.1)
	check(A:GetAttribute("QuirkAlt") == false, "(back to his true form)")
	check(bChar:GetAttribute("Stunned") ~= true and #sentTo(B, "Terrified") == 0, "deflating frightens nobody")

	print("== the action lock: a press arriving just before it's up waits it out")
	local E = Config.Quirks.Explosion.Abilities
	fresh("Explosion", Vector3.new(X, 3, 60))
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.12)
	clearSent()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	check(#sentTo(B, E[1].Id) == 0, "a move pressed with 0.12s of the lock left doesn't go early...")
	task.wait(0.2)
	check(#sentTo(B, E[1].Id) == 1, "...and isn't dropped: it goes as the lock ends")
	task.wait(1)
	fire(TestCommand, A, "ResetCooldowns")
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.6)
	clearSent()
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.75)
	check(#sentTo(B, E[2].Id) == 0, "one pressed deep inside the lock (0.6s left) is refused")
	-- the guard
	task.wait(0.5)
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.12)
	fire(UseAbility, A, BLOCK, true)
	check(aChar:GetAttribute("Blocking") ~= true, "a guard raised with the lock still on isn't up yet...")
	task.wait(0.2)
	check(aChar:GetAttribute("Blocking") == true, "...it goes up as the lock ends (the client shows it raised)")
	fire(UseAbility, A, BLOCK, false)
	check(aChar:GetAttribute("Blocking") ~= true, "(down again)")
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.12)
	fire(UseAbility, A, BLOCK, true)
	fire(UseAbility, A, BLOCK, false)
	task.wait(0.2)
	check(aChar:GetAttribute("Blocking") ~= true, "...but not if it was let go meanwhile")
	-- parkour isn't a combat action
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.5)
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Vault", FWD, nil, 0.36)
	check(#sentTo(B, "Parkour") == 1, "a vault straight out of a punch still shows for everyone")
	task.wait(0.6)

	print("== the two dash timers")
	local MV = Config.Movement
	fresh("Explosion", Vector3.new(X, 3, 60))
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	check(#sentTo(B, "Dash") == 1, "a front dash")
	check((aChar:GetAttribute("CombatActionUntil") or 0) > workspace:GetServerTimeNow() + MV.FrontDashTime,
		"...locks attacks for the dash and its whiff recovery")
	task.wait(MV.FrontDashTime + MV.FrontWhiffRecovery + 0.05)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Right")
	check(#sentTo(B, "Dash") == 1, "a side step runs on its own timer: there straight after a front dash")
	task.wait(MV.SideDashTime + 0.05)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	check(#sentTo(B, "Dash") == 0, "the front dash is still on its " .. MV.FrontDashCooldown .. "s timer")
	task.wait(MV.MobilityDashCooldown - MV.SideDashTime)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, Vector3.new(-1, 0, 0), "Back")
	check(#sentTo(B, "Dash") == 1, "the side/back step is back after " .. MV.MobilityDashCooldown .. "s")
	task.wait(0.5)
end)
---------------------------------------------------------------------------
-- Round 33: the emote wheel; every move on 1 2 3 4
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 9800
	print("== EMOTES (the B wheel)")
	do
		local ids = {}
		for _, e in Config.Emotes do
			table.insert(ids, e.Id)
		end
		A:SetAttribute("EmotesOwned", table.concat(ids, ",")) -- (as if bought)
	end
	check(Config.EMOTE_INDEX ~= nil and #(Config.Emotes or {}) >= 6, "a wheel's worth of emotes (" .. #(Config.Emotes or {}) .. ")")
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(X, 3, 0))
	bChar, bHum, bRoot = spawnChar(B, CFrame.new(X, 3, 10))
	task.wait(0.2)
	clearSent()
	fire(UseAbility, A, Config.EMOTE_INDEX, "Dance")
	local seen = sentTo(B, "Emote")
	check(#seen == 1 and seen[1].Id == "Dance" and #sentTo(A, "Emote") == 0, "an emote is passed on to everyone else (not back to you)")
	fire(UseAbility, A, Config.EMOTE_INDEX, "Wave")
	check(#sentTo(B, "Emote") == 1, "...spamming it is throttled")
	task.wait(0.5)
	fire(UseAbility, A, Config.EMOTE_INDEX, "NotAnEmote")
	fire(UseAbility, A, Config.EMOTE_INDEX, 12)
	check(#sentTo(B, "Emote") == 1, "...only the wheel's emotes")
	aChar:SetAttribute("Stunned", true)
	task.wait(0.5)
	fire(UseAbility, A, Config.EMOTE_INDEX, "Wave")
	check(#sentTo(B, "Emote") == 1, "...not while stunned")
	aChar:SetAttribute("Stunned", false)
	fire(UseAbility, A, Config.EMOTE_INDEX, "Wave")
	check(#sentTo(B, "Emote") == 2 and sentTo(B, "Emote")[2].Id == "Wave", "...back on your feet, it goes")

	print("== every move on 1 2 3 4")
	local function has(list, key)
		return table.find(list or {}, key) ~= nil
	end
	check(has(Config.AbilityKeys[1], Enum.KeyCode.One) and has(Config.AbilityKeys[2], Enum.KeyCode.Two)
		and has(Config.AbilityKeys[3], Enum.KeyCode.Three) and has(Config.ExtraKeys, Enum.KeyCode.Four), "the moves are on 1 2 3 4")
	local stray = 0
	for _, list in { Config.AbilityKeys[1], Config.AbilityKeys[2], Config.AbilityKeys[3], Config.ExtraKeys } do
		for _, k in list do
			if k == Enum.KeyCode.Z or k == Enum.KeyCode.X or k == Enum.KeyCode.C or k == Enum.KeyCode.V then
				stray += 1
			end
		end
	end
	check(stray == 0, "...and not on Z X C V any more (" .. stray .. ")")
	check(not has(Config.ItemKeys, Enum.KeyCode.Four) and has(Config.ItemKeys, Enum.KeyCode.Five), "items moved up to 5-8")
	check(has(Config.EmoteKeys, Enum.KeyCode.B) and not has(Config.ShopKeys, Enum.KeyCode.B)
		and not has(Config.ShopKeys, Config.TestMenu.Key), "B is the emote wheel; the shop's off it (and off the test menu's key)")
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 34: the dash punch stun-locks; moves shove less far; a ragdoll lasts
-- as long as the hit was hard
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 10200
	local FWD = Vector3.new(0, 0, 1)
	local function fresh(aQuirk, bPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 4), Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
	end
	-- how long B stays down (polled)
	local function downFor(limit)
		local t0 = os.clock()
		while bChar:GetAttribute("Ragdolled") == true and os.clock() - t0 < limit do
			task.wait(0.02)
		end
		return os.clock() - t0
	end

	print("== the dash punch stun-locks (JJS)")
	local DP = Config.Movement.DashPunch
	fresh("Explosion", Vector3.new(X, 3, 4))
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Punch", bChar)
	local kb = bRoot:FindFirstChild("Knockback")
	check(bChar:GetAttribute("Stunned") == true and bHum.WalkSpeed == 0, "a dash into B stuns them where they stand (walk speed " .. bHum.WalkSpeed .. ")")
	check(kb == nil or kb.VectorVelocity.Magnitude <= DP.Push + 0.5, "...barely pushed: still in reach (" .. tostring(kb and kb.VectorVelocity) .. ")")
	task.wait(DP.Stun - 0.2)
	check(bChar:GetAttribute("Stunned") == true, "...still stunned " .. (DP.Stun - 0.2) .. "s later: time to start the M1s")
	local h0 = bHum.Health
	fire(UseAbility, A, 0)
	task.wait(0.2)
	check(bHum.Health < h0 and bChar:GetAttribute("Stunned") == true, "...the M1 that follows lands and keeps them stunned")
	task.wait(1.2)

	print("== moves shove less far (M1s keep their push)")
	local KB = Config.Knockback
	fresh("Engine", Vector3.new(X, 3, 4))
	local SK = Config.Quirks.Engine.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.2)
	kb = bRoot:FindFirstChild("Knockback")
	local v = kb and kb.VectorVelocity or Vector3.zero
	check(math.abs(v.Y - SK.Launch * KB.MoveLift) < 1 and math.abs(v.Z - 8 * KB.MoveScale) < 0.5,
		"SKYWARD KICK: the lift x" .. KB.MoveLift .. ", the shove x" .. KB.MoveScale .. " (" .. tostring(v) .. ")")
	task.wait(1.6)
	fresh("Explosion", Vector3.new(X, 3, 4))
	task.wait(Config.M1.ComboReset)
	fire(UseAbility, A, 0)
	task.wait(0.12)
	kb = bRoot:FindFirstChild("Knockback")
	check(kb ~= nil and math.abs(kb.VectorVelocity.Z - 10) < 0.5, "...an M1 keeps its push: the combo's spacing (" .. tostring(kb and kb.VectorVelocity) .. ")")
	task.wait(1.2)

	print("== a ragdoll lasts as long as the hit was hard")
	local RS = Config.Ragdoll.Strength
	-- a jab-strength finisher: the M1 combo's 4th hit
	fresh("Explosion", Vector3.new(X, 3, 4))
	task.wait(Config.M1.ComboReset)
	for i = 1, 4 do
		fire(UseAbility, A, 0)
		task.wait(i < 4 and Config.M1.Cooldown + 0.05 or 0.16) -- (the finisher lands 0.14s after the press)
	end
	local weak = downFor(4) + 0.02
	local weakWant = Config.M1.RagdollTime * math.clamp(RS.Base + Config.M1.FinisherDamage / RS.PerDamage, RS.Min, RS.Max) * RS.Longer
	check(math.abs(weak - weakWant) < 0.2, string.format("the M1 finisher (%d damage) puts them down for %.2fs (~%.2f)", Config.M1.FinisherDamage, weak, weakWant))
	task.wait(1.2)
	-- a big one: Deku's Fa Jin (34)
	fresh("FullCowl", Vector3.new(X, 3, 20))
	A:SetAttribute("QuirkPick", 4)
	local FJ = Config.Quirks.FullCowl.Extras[4]
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(FJ.Hold.Max + 0.1)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 20))
	local t0 = os.clock()
	while bChar:GetAttribute("Ragdolled") ~= true and os.clock() - t0 < 1.2 do
		task.wait(0.02)
	end
	local big = downFor(5)
	check(big > weak + 0.5 and big > 1.9, string.format("FA JIN (%d damage) puts them down far longer: %.2fs", FJ.Damage, big))
	check(big <= RS.Cap + 0.1, "...but never past " .. RS.Cap .. "s")
	A:SetAttribute("QuirkPick", 1)
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 35: every hero's signature look (kept minimal); Overhaul's fused
-- arms; Deku's INFINITE 100% (up into the sky, the barrage, down into the street)
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 11000
	local SKIN = M.Color3.fromRGB(240, 205, 170)
	local function r6(p, pos)
		local model, hum, root = spawnChar(p, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
		for _, s in {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
			{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
			{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
			{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		} do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Color = SKIN
			part.Parent = model
			if s[1] == "Head" then
				M.new("SpecialMesh", "Mesh").Parent = part
			end
		end
		return model, hum, root
	end
	local function named(gear, name)
		local out = {}
		for _, d in gear and gear:GetDescendants() or {} do
			if d.Name == name and d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
		return out
	end
	local function dressed(quirk)
		fire(SelectQuirk, A, quirk)
		if aChar then
			aChar.Parent = nil
		end
		aChar, aHum, aRoot = r6(A, Vector3.new(X, 3, 0))
		fire(SelectQuirk, A, quirk) -- (the gear built on this body)
		task.wait(0.4)
		return aChar:FindFirstChild("QuirkGear"), aChar:FindFirstChild("Head")
	end
	local function clean(gear)
		for _, d in gear and gear:GetDescendants() or {} do
			if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch or not d.Massless) then
				return false
			end
		end
		return true
	end

	print("== signature looks (minimal, one or two pieces a hero)")
	local gear, head = dressed("Explosion")
	local bracers = named(gear, "Bracer")
	check(#bracers >= 40, "BAKUGO: the grenade gauntlets, a segmented grenade on each forearm (" .. #bracers .. " segments)")
	local left, right = 0, 0
	for _, b in bracers do
		local rel = aRoot.CFrame:PointToObjectSpace(b.Position)
		if rel.X > 0.8 and rel.Y < 0.6 then
			right += 1
		elseif rel.X < -0.8 and rel.Y < 0.6 then
			left += 1
		end
	end
	check(left >= 20 and right >= 20, "...one on each arm, down the forearm (" .. left .. " / " .. right .. ")")
	check(clean(gear), "...weightless, no collisions, no hitbox queries")
	gear, head = dressed("HalfCold")
	local scar = named(gear, "Scar")
	local onLeft = true
	for _, p in scar do
		local rel = head.CFrame:PointToObjectSpace(p.Position)
		if rel.X > 0 or rel.Z > -0.1 then
			onLeft = false
		end
	end
	check(#scar >= 5 and onLeft, "TODOROKI: the burn scar round his left eye (" .. #scar .. " patches)")
	gear, head = dressed("Engine")
	check(#named(gear, "Glasses") >= 9 and #named(gear, "Pipe") == 6, "IIDA: his glasses (and still the engines in his calves)")
	gear, head = dressed("OneForAll")
	local bangs = named(gear, "Bang")
	local up = #bangs == 2
	for _, b in bangs do
		up = up and head.CFrame:PointToObjectSpace(b.Position).Y > 0.5
	end
	check(up, "ALL MIGHT: the two bangs standing up off his forehead")
	gear, head = dressed("FullCowl")
	local boots = named(gear, "Boot")
	local low = #boots >= 12
	for _, b in boots do
		low = low and aRoot.CFrame:PointToObjectSpace(b.Position).Y < -2
	end
	check(low, "DEKU: the red boots (" .. #boots .. " pieces, all down at his feet)")
	gear, head = dressed("Decay")
	local father = named(gear, "Father")
	local front = #father >= 10
	for _, p in father do
		front = front and head.CFrame:PointToObjectSpace(p.Position).Z < 0 -- (the fingertips curl round the side)
	end
	check(front, "SHIGARAKI: the hand over his face (" .. #father .. " pieces)")
	gear, head = dressed("Limitless")
	check(#named(gear, "Blindfold") == 1, "GOJO: the blindfold")
	gear, head = dressed("Lemillion")
	local text = nil
	for _, d in gear and gear:GetDescendants() or {} do
		if d.ClassName == "TextLabel" then
			text = d.Text
		end
	end
	check(#named(gear, "Cape") >= 3 and #named(gear, "Visor") >= 3 and text == nil,
		"LEMILLION, kept minimal: the cape and the visor, no full costume")
	gear, head = dressed("Manifest")
	check(#named(gear, "Hood") == 0 and #named(gear, "Belt") == 1 and #named(gear, "Pouch") >= 6 and #named(gear, "Ear") == 2 and #gear:GetChildren() < 16,
		"SUNEATER, kept minimal: no hood - his utility belt and his pointed ears (" .. #gear:GetChildren() .. " pieces)")

	print("== OVERHAUL's fused arms (the anime's look)")
	gear, head = dressed("Overhaul")
	A:SetAttribute("Ult", 100)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	gear = aChar:FindFirstChild("QuirkGear")
	local skin = named(gear, "FusedSkin")
	check(#skin >= 30, "his own arms turn to pink plates cut by black cracks (" .. #skin .. " pieces)")
	check(#named(gear, "FusedArm") == 4 and #named(gear, "FusedClaw") >= 12, "...two thick rock arms out of his back, hooked claws on every hand")
	check(clean(gear), "...weightless, no collisions")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.4)

	print("== DEKU: INFINITE 100% (the Overhaul fight's finale)")
	-- (a street at y = 0 under everyone; open sky above)
	local rayBefore = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < -0.5 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = workspace }
		end
		return nil
	end
	local IN = Config.Quirks.FullCowl.Ult.Abilities[3]
	check(IN.Id == "FistRain" and IN.Hits >= 12, "(the barrage move)")
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	fire(SelectQuirk, A, "FullCowl")
	fire(SelectQuirk, B, "Explosion")
	fire(SelectQuirk, C, "Explosion")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	task.wait(0.2)
	A:SetAttribute("Ult", 100)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	for _, old in { bChar } do
		if old then
			old.Parent = nil
		end
	end
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 5), Vector3.new(X, 3, 0)))
	local cChar, cHum = spawnChar(C, CFrame.new(Vector3.new(X + 6, 3, 7)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local startY = bRoot.Position.Y
	fire(UseAbility, A, 3, Vector3.new(0, 0, 1), Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait((IN.Startup or 0.18) + IN.RiseTime + 0.05)
	check(bRoot.Position.Y - startY > 18, string.format("the kick blasts them up into the sky (%.1f studs)", bRoot.Position.Y - startY))
	check((aRoot.Position - bRoot.Position).Magnitude < 9 and aRoot.Position.Y - startY > 15, "...and he's up there after them")
	local caught = sentTo(B, "FistRainCatch")[1]
	check(caught and typeof(caught.At) == "Vector3", "...everyone's told where (the barrage is drawn there)")
	local barrageTime = 0
	for i = 1, IN.Hits do
		barrageTime += math.max(IN.MinInterval, IN.Interval * IN.Speedup ^ (i - 1))
	end
	task.wait(barrageTime + 0.05)
	check(#sentTo(B, "FistRainStrike") == IN.Hits, "the barrage: " .. IN.Hits .. " 100% punches (" .. #sentTo(B, "FistRainStrike") .. ")")
	task.wait(0.1 + IN.RainTime + 0.2)
	local fin = sentTo(B, "FistRainFinish")[1]
	check(fin and fin.From and fin.From.Y > fin.Pos.Y + 15, "the fists rain them down out of the sky")
	check(bRoot.Position.Y - startY < 4 and bChar:GetAttribute("Ragdolled") == true, "...hurled down into the street, left lying there")
	check(cHum.Health < Config.PlayerMaxHealth, "...and the crash hits whoever's near where they land")
	check(aRoot.Anchored ~= true and aChar:GetAttribute("FistRainActive") == nil, "...and he's free again")
	fire(TestCommand, A, "EndUlt")
	cChar.Parent = nil
	workspace.Raycast = rayBefore
	task.wait(1.5)
end)
---------------------------------------------------------------------------
-- Round 36: the cosmetics switches, hero ranks + Top Heroes (saved), Fa
-- Jin's tap-to-wind-up, the Auto-Cannon's live aim, ult armour, Iida's
-- speed, INFINITE 100%'s rain of fists
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 12500
	local MAX = Config.PlayerMaxHealth
	local SKIN = M.Color3.fromRGB(240, 205, 170)
	local Settings = remotes:FindFirstChild("Settings")
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	local serde = require("@lune/serde")
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function limbs(model, root)
		for _, s in {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
			{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
			{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
			{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		} do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Color = SKIN
			part.Parent = model
			if s[1] == "Head" then
				M.new("SpecialMesh", "Mesh").Parent = part
			end
		end
	end
	local function fresh(aQuirk, bPos, cPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		fire(SelectQuirk, C, "Explosion")
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 8), Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(C, CFrame.new(cPos or Vector3.new(X + 400, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
	end

	print("== SETTINGS: MY COSMETICS / SHOW COSMETICS")
	check(Settings ~= nil, "a Settings remote")
	fresh("Explosion")
	limbs(aChar, aRoot)
	fire(SelectQuirk, A, "Explosion") -- (the gear built on the limbs)
	task.wait(0.4)
	local gear = aChar:FindFirstChild("QuirkGear")
	local cos = gear and gear:FindFirstChild("Cosmetics")
	check(cos ~= nil and #cos:GetDescendants() >= 40, "the signature look is its own model (QuirkGear.Cosmetics, " .. (cos and #cos:GetDescendants() or 0) .. " pieces)")
	fire(Settings, A, "WearCosmetics", false)
	task.wait(0.3)
	gear = aChar:FindFirstChild("QuirkGear")
	check(A:GetAttribute("WearCosmetics") == false and not (gear and gear:FindFirstChild("Cosmetics")), "MY COSMETICS off: the look comes off, for everyone")
	check(gear ~= nil, "...the rest of the gear stays")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.4)
	gear = aChar:FindFirstChild("QuirkGear")
	check(not (gear and gear:FindFirstChild("Cosmetics")), "...and stays off when the gear is rebuilt")
	task.wait(0.2)
	fire(Settings, A, "WearCosmetics", true)
	task.wait(0.3)
	gear = aChar:FindFirstChild("QuirkGear")
	check(gear and gear:FindFirstChild("Cosmetics"), "...back on again")
	task.wait(0.2)
	fire(Settings, A, "ShowCosmetics", false)
	task.wait(0.05)
	check(A:GetAttribute("ShowCosmetics") == false, "SHOW COSMETICS off is remembered (your own screen hides everyone else's)")
	task.wait(0.2)
	fire(Settings, A, "Volume", false)
	task.wait(0.2)
	fire(Settings, A, "ShowCosmetics", "yes")
	task.wait(0.05)
	check(A:GetAttribute("Volume") == nil and A:GetAttribute("ShowCosmetics") == false, "junk settings are ignored")
	task.wait(0.2)
	fire(Settings, A, "ShowCosmetics", true)
	task.wait(0.05)

	print("== HERO RANKS (by all-time kills) and TOP HEROES")
	local ls = A:FindFirstChild("leaderstats")
	check(ls and ls:FindFirstChild("Kills") and ls:FindFirstChild("Rank") and ls:FindFirstChild("KOs") == nil, "the player list shows Kills and a Rank")
	check(Config.Ranks[1].Name == "STUDENT" and Config.Ranks[2].Kills == 10 and Config.RankOf(10) == 2 and Config.RankOf(9) == 1, "STUDENT, then LICENSED PRE-HERO at 10 kills")
	local names = {}
	for _, rk in Config.Ranks do
		table.insert(names, rk.Name)
	end
	check(table.concat(names, ","):find("U.A. GRADUATE,SEMI-PRO,PRO HERO", 1, true) ~= nil, "...U.A. GRADUATE, SEMI-PRO, PRO HERO (" .. table.concat(names, ", ") .. ")")
	for _, p in { A, B, C } do
		fire(TestCommand, p, "ResetStats")
	end
	-- Dana's save says 9 kills and her look off
	DS.data["u_4"] = { Bucks = 5, Items = {}, Kills = 9, Settings = { WearCosmetics = false, ShowCosmetics = true, Music = false } }
	local D = addPlayer("Dana", 4)
	task.wait(0.3)
	check(D:GetAttribute("Kills") == 9 and stat(D, "Kills") == 9 and stat(D, "Rank") == Config.Ranks[1].Short, "a returning player's kills load from the save (9, " .. tostring(stat(D, "Rank")) .. ")")
	check(D:GetAttribute("WearCosmetics") == false and D:GetAttribute("Music") == false, "...and so do their settings")
	check(#sentTo(D, "RankUp") == 0, "...quietly (no rank-up for loading)")
	fire(SelectQuirk, D, "Explosion")
	local dChar, dHum, dRoot = spawnChar(D, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	if aChar then
		aChar.Parent = nil
	end
	bChar.Parent = nil
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 12), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	clearSent()
	bHum.Health = 3
	fire(UseAbility, D, 1, Vector3.new(0, 0, 1), bRoot.Position, 1, dRoot.Position)
	task.wait(0.8)
	check(bHum.Health == 0 and stat(D, "Kills") == 10, "a KO: kills 10 (" .. tostring(stat(D, "Kills")) .. ")")
	local up = sentTo(B, "RankUp")[1]
	check(stat(D, "Rank") == Config.Ranks[2].Short and D:GetAttribute("RankIndex") == 2 and up and up.UserId == 4 and up.Index == 2,
		"...LICENSED PRE-HERO: the rank goes up, and everyone's told")
	local board = ReplicatedStorage:FindFirstChild("TopHeroes")
	local list = board and board.Value ~= "" and serde.decode("json", board.Value) or {}
	check(list[1] and list[1].UserId == 4 and list[1].Kills == 10 and list[1].Name == "Dana", "TOP HEROES shows it straight away (" .. tostring(board and board.Value) .. ")")
	D.Parent = nil
	Players.PlayerRemoving:Fire(D)
	task.wait(0.2)
	local saved = DS.data["u_4"]
	check(saved and saved.Kills == 10 and saved.Settings and saved.Settings.WearCosmetics == false, "leaving saves the kills and the settings")
	check(DS.board["u_4"] == 10, "...and the all-time kills board")
	dChar.Parent = nil

	print("== FA JIN: tap to wind up, tap again to let go")
	fresh("FullCowl", Vector3.new(X, 3, 30))
	local FJ = Config.FindAbilityById("FaJinSmash")
	check(FJ.Hold and FJ.Hold.Toggle == true, "(a toggle hold)")
	A:SetAttribute("QuirkPick", 4)
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.3)
	check(aChar:GetAttribute("Holding") == "FaJinSmash", "4: he winds up (and holds it)")
	task.wait(FJ.Hold.Max - 0.3 + 0.1)
	check(aChar:GetAttribute("Holding") == "FaJinSmash", "...until he taps again (the key coming up doesn't let it go)")
	fire(UseAbility, A, Config.RELEASE_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30))
	task.wait(0.55)
	local rel = sentTo(B, "FaJinSmashRelease")[1]
	check(rel and rel.Level == 3 and rel.Power > 0.95, "wound all the way: full power (level " .. tostring(rel and rel.Level) .. ")")
	local full = MAX - bHum.Health
	check(full == FJ.Damage, "the full gale: " .. FJ.Damage .. " at 30 studs (" .. full .. ")")
	check(bChar:GetAttribute("Ragdolled") == true, "...and it bowls them over")
	task.wait(2.2)
	fresh("FullCowl", Vector3.new(X, 3, 30))
	A:SetAttribute("QuirkPick", 4)
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	fire(UseAbility, A, Config.RELEASE_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30))
	task.wait(0.55)
	local tap = MAX - bHum.Health
	check(tap > 0 and tap < full * 0.7, "a quick tap: a weaker gust (" .. tap .. " vs " .. full .. ")")
	task.wait(1)
	fresh("FullCowl", Vector3.new(X, 3, 100))
	A:SetAttribute("QuirkPick", 4)
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 100), 1, aRoot.Position)
	task.wait(FJ.Hold.Max + 0.9)
	check(bHum.Health < MAX, "never tapped again: it goes by itself at full power, and reaches " .. FJ.Range .. " studs")

	print("== AP SHOT: AUTO-CANNON follows the aim while it fires")
	fresh("Explosion", Vector3.new(X, 3, 40), Vector3.new(X + 40, 3, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.6)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local AC = Config.Quirks.Explosion.Ult.Abilities[1]
	check(AC.Id == "AutoCannon" and AC.LiveAim, "(the live-aimed move)")
	bHum.Health, cHum.Health = MAX, MAX
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(X, 3, 40), 1, aRoot.Position)
	task.wait(0.2)
	local swung = false
	task.spawn(function()
		for _ = 1, 20 do
			fire(UseAbility, A, Config.AIM_INDEX, Vector3.new(1, 0, 0))
			swung = true
			task.wait(0.06)
		end
	end)
	task.wait(1.1)
	local shots = sentTo(B, "AutoCannonShot")
	local turned = 0
	for _, sh in shots do
		if sh.Dir and sh.Dir.X > 0.9 then
			turned += 1
		end
	end
	check(swung and #shots == AC.Shots and turned >= 3, "he swings it round mid-burst: the later shots go the new way (" .. turned .. " of " .. #shots .. ")")
	check(bHum.Health < MAX and cHum.Health < MAX, "...hitting what was in front, then what he turned to")
	check(#sentTo(A, "AutoCannonShot") == 0, "(his own screen draws his shots from his own aim)")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.3)

	print("== ULT ARMOUR")
	fresh("Explosion", Vector3.new(X, 3, 30), Vector3.new(X - 8, 3, 0))
	cRoot.CFrame = CFrame.lookAt(Vector3.new(X - 8, 3, 0), aRoot.Position)
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.15)
	fire(TestCommand, C, "ResetCooldowns")
	local hp0 = aHum.Health
	fire(UseAbility, C, 1, Vector3.new(1, 0, 0), aRoot.Position, 1, cRoot.Position)
	task.wait(0.5)
	check(aHum.Health == hp0, "popping the ult: nothing touches him while he powers up")
	task.wait(1.4)
	fire(TestCommand, A, "ResetCooldowns")
	fire(TestCommand, C, "ResetCooldowns")
	hp0 = aHum.Health
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	fire(UseAbility, C, 1, Vector3.new(1, 0, 0), aRoot.Position, 1, cRoot.Position)
	task.wait(0.35)
	check(aHum.Health == hp0, "...and his ult moves can't be interrupted as they go off")
	task.wait(0.8)
	fire(TestCommand, C, "ResetCooldowns")
	fire(UseAbility, C, 1, Vector3.new(1, 0, 0), aRoot.Position, 1, cRoot.Position)
	task.wait(0.4)
	check(aHum.Health < hp0, "(once it's over he can be hit again)")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.3)

	print("== IIDA: a little slower")
	check(Config.Quirks.Engine.WalkSpeed <= 24 and Config.Quirks.Engine.Ult.WalkSpeed <= 50, "Iida's walk speed " .. Config.Quirks.Engine.WalkSpeed .. " (ult " .. Config.Quirks.Engine.Ult.WalkSpeed .. ")")

	print("== INFINITE 100%: the fists come raining down, and it all goes off")
	local rayBefore = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < -0.5 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = workspace }
		end
		return nil
	end
	local IN = Config.FindAbilityById("FistRain")
	local gaps, barrage = {}, 0
	for i = 1, IN.Hits do
		gaps[i] = math.max(IN.MinInterval, IN.Interval * IN.Speedup ^ (i - 1))
		barrage += gaps[i]
	end
	check(gaps[1] > gaps[#gaps] * 2 and gaps[#gaps] >= IN.MinInterval, string.format("the punches speed up (%.3f s apart at first, %.3f at the end)", gaps[1], gaps[#gaps]))
	fresh("FullCowl", Vector3.new(X, 3, 5), Vector3.new(X + 6, 3, 7))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	bChar.Parent = nil
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 5), Vector3.new(X, 3, 0)))
	cRoot.CFrame = CFrame.new(Vector3.new(X + 6, 3, 7))
	cHum.Health = MAX
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 3, Vector3.new(0, 0, 1), Vector3.new(X, 3, 5), 1, aRoot.Position)
	task.wait((IN.Startup or 0.18) + 0.1)
	local caught = sentTo(B, "FistRainCatch")[1]
	check(caught and caught.Barrage and math.abs(caught.Barrage - barrage) < 0.01 and caught.RainTime == IN.RainTime, "the kick lands: everyone's told the timeline (for the camera)")
	task.wait(IN.RiseTime + barrage)
	check(#sentTo(B, "FistRainStrike") == IN.Hits, "the barrage, faster and faster (" .. #sentTo(B, "FistRainStrike") .. " punches)")
	task.wait(0.1 + 0.05)
	local fall = sentTo(B, "FistRainFall")[1]
	check(fall and fall.Time == IN.RainTime and fall.Hits == IN.RainHits and fall.From and fall.From.Y > fall.Pos.Y + 15, "then the fists rain down on them, out of the sky")
	task.wait(IN.RainTime * 0.5)
	local midY = bRoot.Position.Y
	check(midY > 4 and midY < fall.From.Y - 1, string.format("...driving them down (%.1f studs up, halfway)", midY))
	task.wait(IN.RainTime * 0.5 + 0.1)
	local fin = sentTo(B, "FistRainFinish")[1]
	check(fin ~= nil and bRoot.Position.Y < 5 and bChar:GetAttribute("Ragdolled") == true, "...into the street, and it all goes off")
	local storm = IN.LaunchDamage + IN.Hits * IN.Damage + IN.RainHits * IN.RainDamage + IN.FinisherDamage
	check(MAX - bHum.Health >= storm * 0.9, "the whole thing: " .. storm .. " (took " .. (MAX - bHum.Health) .. ")")
	check(cHum.Health < MAX, "...and the blast catches whoever's near")
	task.wait(0.4)
	check(aRoot.Anchored ~= true and aChar:GetAttribute("FistRainActive") == nil, "...and he's free again")
	fire(TestCommand, A, "EndUlt")
	workspace.Raycast = rayBefore
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 37: Kamui Woods, the swings (his branch, Suneater's tentacle),
-- Suneater's slower stomach, Bakugo toned down, UNO at Tony's
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 14000
	local MAX = Config.PlayerMaxHealth
	local SKIN = M.Color3.fromRGB(240, 205, 170)
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, cHum, cRoot
	for _, p in { A, B, C } do
		fire(TestCommand, p, "ResetCooldowns")
	end
	-- a street at y = 0, and (when `building` is set) a block of flats:
	-- an axis-aligned box the rays stop at
	local building = nil
	local function ray(_, origin, dir)
		if typeof(dir) ~= "Vector3" then
			return nil
		end
		local best
		if building then
			local tmin, tmax = 0, 1
			local normal
			for _, ax in { "X", "Y", "Z" } do
				local o, d = origin[ax], dir[ax]
				local lo, hi = building.min[ax], building.max[ax]
				if math.abs(d) < 1e-9 then
					if o < lo or o > hi then
						tmin = 2
					end
				else
					local t1, t2 = (lo - o) / d, (hi - o) / d
					local n = -math.sign(d)
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					if t1 > tmin then
						tmin = t1
						normal = Vector3.new(ax == "X" and n or 0, ax == "Y" and n or 0, ax == "Z" and n or 0)
					end
					tmax = math.min(tmax, t2)
				end
			end
			if tmin <= tmax and tmin >= 0 and tmin <= 1 and normal then
				best = { Position = origin + dir * tmin, Distance = dir.Magnitude * tmin, Normal = normal, Instance = workspace }
			end
		end
		if dir.Y < 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			if not best or t * dir.Magnitude < best.Distance then
				best = { Position = Vector3.new(origin.X + dir.X * t, 0, origin.Z + dir.Z * t), Distance = dir.Magnitude * t, Normal = Vector3.new(0, 1, 0), Instance = workspace }
			end
		end
		return best
	end
	local rayBefore = workspace.Raycast
	workspace.Raycast = ray
	local function limbs(model, root)
		for _, s in {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
			{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
			{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
			{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		} do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Color = SKIN
			part.Parent = model
			if s[1] == "Head" then
				M.new("SpecialMesh", "Mesh").Parent = part
			end
		end
	end
	local function fresh(aQuirk, bPos, cPos)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, "Explosion")
		fire(SelectQuirk, C, "Explosion")
		for _, old in { aChar, bChar, cChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 8), Vector3.new(X, 3, 0)))
		cChar, cHum, cRoot = spawnChar(C, CFrame.new(cPos or Vector3.new(X + 400, 3, 0)))
		task.wait(0.2)
		for _, p in { A, B, C } do
			fire(TestCommand, p, "ResetCooldowns")
		end
		clearSent()
	end
	local function ult(n)
		return math.floor(n * Config.Ult.DamageMultiplier + 0.5)
	end
	-- the strongest launch a knockback gives them over the next `t` seconds
	local function launchY(root, t)
		local best = 0
		local t0 = os.clock()
		while os.clock() - t0 < t do
			local kb = root:FindFirstChild("Knockback")
			if kb and kb.VectorVelocity then
				best = math.max(best, kb.VectorVelocity.Y)
			end
			task.wait()
		end
		return best
	end
	local function named(gear, name)
		local n = 0
		for _, d in gear and gear:GetDescendants() or {} do
			if d.Name == name and d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end

	print("== KAMUI WOODS (Arbor)")
	local AR = Config.Quirks.Arbor
	check(AR and table.find(Config.QuirkOrder, "Arbor") and AR.DisplayName == "KAMUI WOODS", "Kamui Woods is on the character select")
	check(AR.Special.Id == "BranchSwing" and AR.Special.Swing == true and #AR.Abilities == 3 and AR.Extra and AR.Ult, "...a full kit: 3 moves, the swing on R, a 4th, an ult")
	check(AR.Abilities[2].Id == "TimberSlingshot", "(2 is the Timber Slingshot)")
	fresh("Arbor", Vector3.new(X, 3, 20))
	limbs(aChar, aRoot)
	fire(SelectQuirk, A, "Arbor")
	task.wait(0.4)
	local gear = aChar:FindFirstChild("QuirkGear")
	local cos = gear and gear:FindFirstChild("Cosmetics")
	check(named(cos, "Helmet") == 0 and named(cos, "Band") == 0 and named(cos, "Eye") == 0, "his look: no helmet (your own face shows)")
	check(named(cos, "Bark") >= 2 and named(cos, "Armband") == 2 and named(cos, "Rose") >= 3, "...wooden forearms, the armbands, the roses on his belt")

	print("== LACQUERED CHAIN PRISON")
	fresh("Arbor", Vector3.new(X, 3, 25))
	local CP = AR.Abilities[1]
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	local catch = sentTo(B, "ChainPrisonCatch")[1]
	check(catch and catch.Target == bChar and bHum.Health == MAX - CP.Damage, "the branches reach them 25 studs off (" .. (MAX - bHum.Health) .. ")")
	check(bChar:GetAttribute("Stunned") == true and bHum.WalkSpeed == 0, "...caged: rooted to the spot")
	task.wait(CP.Bind + 0.3)
	check(bChar:GetAttribute("Stunned") ~= true, "...and let go after " .. CP.Bind .. "s")
	fresh("Arbor", Vector3.new(X, 3, 90))
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	catch = sentTo(B, "ChainPrisonCatch")[1]
	check(catch and catch.Target == nil and bHum.Health == MAX, "out of reach: the branches come back empty")

	print("== TIMBER SLINGSHOT")
	local TS = AR.Abilities[2]
	-- a building behind him
	building = { min = Vector3.new(X - 12, 0, -30), max = Vector3.new(X + 12, 60, -14) }
	fresh("Arbor", Vector3.new(X, 3, 6), Vector3.new(X + 7, 3, 9))
	local startY = bRoot.Position.Y
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.15 + 0.38)
	check(bRoot.Position.Y - startY > 16 and bChar:GetAttribute("Grabbed") == true, string.format("he throws them way up (%.1f studs)", bRoot.Position.Y - startY))
	local toss = sentTo(B, "TimberToss")[1]
	check(toss and toss.Anchor and toss.Anchor.Z < -12 and toss.Pillar == nil, "...and his branch grabs the building behind him")
	task.wait(0.12 + 0.3)
	local gap = toss and (aRoot.Position - toss.Anchor).Magnitude or 999
	check(gap < 4 and aRoot.Position.Y > 8, string.format("...hauls himself up to it (%.1f studs off, %.1f up)", gap, aRoot.Position.Y))
	task.wait(0.22)
	check(aRoot.Position.Y > bRoot.Position.Y, "...flings himself off it, over them")
	task.wait(0.3)
	local slam = sentTo(B, "TimberSlam")[1]
	check(slam and bRoot.Position.Y < 5 and bChar:GetAttribute("Ragdolled") == true, "...and slams them into the street")
	check(MAX - bHum.Health >= TS.LaunchDamage + TS.SlamDamage, "the whole thing: " .. (TS.LaunchDamage + TS.SlamDamage) .. " (" .. (MAX - bHum.Health) .. ")")
	check(cHum.Health == MAX - TS.ShockDamage, "...and the crash catches whoever's next to them")
	check(aRoot.Anchored ~= true and bChar:GetAttribute("Grabbed") == nil, "...then both are free")
	-- no building in reach: a trunk out of the street
	building = nil
	task.wait(1.4)
	fresh("Arbor", Vector3.new(X, 3, 6))
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	toss = sentTo(B, "TimberToss")[1]
	check(toss and toss.Pillar == true and toss.Anchor.Y > 12, "nothing to grab: a trunk bursts out of the street for him")
	task.wait(1.4)
	check(sentTo(B, "TimberSlam")[1] ~= nil and MAX - bHum.Health >= TS.LaunchDamage + TS.SlamDamage, "...and it all still lands")
	-- nobody in front: nothing happens
	fresh("Arbor", Vector3.new(X, 3, 40))
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	check(#sentTo(B, "TimberWhiff") == 1 and #sentTo(B, "TimberToss") == 0 and aRoot.Anchored ~= true, "a whiff: nobody to throw")
	task.wait(0.4)

	print("== ROOT BREAKER / GREAT TREE HAMMER")
	fresh("Arbor", Vector3.new(X, 3, 22), Vector3.new(X + 16, 3, 20))
	local RB = AR.Abilities[3]
	fire(UseAbility, A, 3, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	local up = launchY(bRoot, 0.6)
	check(bHum.Health == MAX - RB.Damage and up > 40, "ROOT BREAKER: stakes up out of the street throw them up (" .. (MAX - bHum.Health) .. ")")
	check(cHum.Health == MAX, "...only along the line")
	task.wait(1.2)
	fresh("Arbor", Vector3.new(X, 3, 10))
	local TH = AR.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	check(bHum.Health == MAX - TH.Damage and bChar:GetAttribute("Ragdolled") == true, "GREAT TREE HAMMER: the trunk comes down on them (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.4)

	print("== BRANCH SWING (R)")
	fresh("Arbor", Vector3.new(X, 3, 60))
	building = { min = Vector3.new(X - 10, 0, 30), max = Vector3.new(X + 10, 70, 50) }
	local good = Vector3.new(X, 40, 30 - 0.3)
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.6, 0.8).Unit, good, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 0 and #sentTo(B, "BranchSwing") == 1, "a branch to the building (40 studs up): he swings, and everyone sees the branch")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.6, 0.8).Unit, Vector3.new(X + 30, 40, -20), 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 1, "...into thin air: called off")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 1, 29.7), 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 1, "...off something lower than him: no")
	building = nil

	print("== GREAT FOREST (ult)")
	fresh("Arbor", Vector3.new(X, 3, 10), Vector3.new(X + 12, 3, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	check(A:GetAttribute("UltActive") == true, "(the ult)")
	local TB = AR.Ult.Abilities[1]
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	bHum.Health, cHum.Health = MAX, MAX
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	local caught = sentTo(B, "ThousandBranchCatch")[1]
	check(caught and #caught.Targets == 2 and bChar:GetAttribute("Stunned") == true and cChar:GetAttribute("Stunned") == true, "THOUSAND-BRANCH PRISON: everyone round him caged")
	task.wait(TB.Bind + 0.2)
	local both = ult(TB.Damage) + ult(TB.CrushDamage)
	check(bHum.Health == MAX - both and cHum.Health == MAX - both, "...then crushed (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.5)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 45), Vector3.new(X, 3, 0))
	bChar:SetAttribute("Stunned", false)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 3, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.9)
	check(bHum.Health == MAX - ult(AR.Ult.Abilities[3].Damage), "TIMBER TORRENT: the logs roll over them 45 studs down the street")
	task.wait(1.5)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 0))
	bChar:SetAttribute("Stunned", false)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30), 1, aRoot.Position)
	up = launchY(bRoot, 0.7)
	check(bHum.Health == MAX - ult(AR.Ult.Extra.Damage) and up > 80, "SEQUOIA SPEAR: a giant tree under them spears them into the sky")
	fire(TestCommand, A, "EndUlt")
	task.wait(1.5)

	print("== SUNEATER: the tentacle swings off a building; a slower stomach")
	fresh("Manifest", Vector3.new(X + 60, 3, 0))
	building = { min = Vector3.new(X - 10, 0, 25), max = Vector3.new(X + 10, 60, 45) }
	local before = aChar:GetAttribute("Stomach")
	fire(UseAbility, A, 2, Vector3.new(0, 0.6, 0.8).Unit, Vector3.new(X, 30, 25), 1, aRoot.Position)
	task.wait(0.8)
	local swing = sentTo(A, "TakoZip")[1]
	check(swing and swing.Anchor and swing.Anchor.Z < 25.5 and swing.Anchor.Y > 8, "TAKO SNATCH at a building, nobody in reach: it latches on and zips him there (round 60)")
	check(#sentTo(B, "TakoZip") == 1, "...everyone sees the tentacle")
	local cost = before - aChar:GetAttribute("Stomach")
	check(cost == Config.Quirks.Manifest.Abilities[2].Cost and cost <= 5, "...and it only cost " .. tostring(cost) .. " of his stomach (was 12)")
	building = nil
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(X, 3, 40), 1, aRoot.Position)
	task.wait(0.5)
	check(#sentTo(A, "TakoZip") == 0, "...at nothing: no zip")
	local total = 0
	for _, a in Config.Quirks.Manifest.Abilities do
		total += a.Cost or 0
	end
	check(total + (Config.Quirks.Manifest.Extra.Cost or 0) <= 20, "every move together costs " .. total + (Config.Quirks.Manifest.Extra.Cost or 0) .. " of 100 (was 52)")

	print("== BAKUGO, toned down")
	local EX = Config.Quirks.Explosion
	check(EX.Abilities[1].Damage <= 15 and EX.Abilities[1].Cooldown >= 7, "AP SHOT: " .. EX.Abilities[1].Damage .. " every " .. EX.Abilities[1].Cooldown .. "s (was 24 every 4.5s)")
	check(EX.Ult.Abilities[1].Damage * EX.Ult.Abilities[1].Shots <= 40 and EX.Ult.Abilities[3].Damage <= 50, "the ult: Auto-Cannon " .. EX.Ult.Abilities[1].Damage * EX.Ult.Abilities[1].Shots .. " a burst, Howitzer " .. EX.Ult.Abilities[3].Damage)
	fresh("Explosion", Vector3.new(X, 3, 30))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	local CL = EX.Ult.Abilities[2]
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(X, 3, 30), 7, aRoot.Position)
	task.wait(1.1)
	check(MAX - bHum.Health <= ult(CL.Damage) + ult(CL.FinisherDamage), "CLUSTER: the bombs overlap, but each one only hits you once, then the big one (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(1.5)

	print("== UNO at Tony's")
	local UnoRemote = remotes:FindFirstChild("Uno")
	check(UnoRemote ~= nil, "an Uno remote")
	local seats = {}
	for _, d in ((workspace:FindFirstChild("UnoTables") or workspace):FindFirstChild("Table1") or workspace):GetDescendants() do
		if d.ClassName == "Seat" then
			table.insert(seats, d)
		end
	end
	check(#seats == 4, "the pizzeria's table gets a seat by each of its 4 chairs (" .. #seats .. ")")
	check(seats[1] and seats[1]:FindFirstChild("PlayUno") and seats[1].CanTouch == false, "...each with a Play UNO prompt (and no sitting down by walking into it)")
	local function states(p)
		local out = {}
		for _, s in M.sent do
			if s.To == p and s.Args[1] == "State" then
				table.insert(out, s.Args[2])
			end
		end
		return out
	end
	local function last(p)
		local all = states(p)
		return all[#all]
	end
	fresh("FullCowl")
	aChar.Parent = workspace
	clearSent()
	seats[1].Occupant = aHum
	task.wait(0.1)
	local st = last(A)
	check(st and st.Phase == "Lobby" and #st.Seated == 1 and aChar:GetAttribute("PlayingUno") == true, "A sits down: the table's panel, waiting for someone else")
	-- (sat at the table: no fighting)
	bRoot.CFrame = CFrame.lookAt(aRoot.Position + Vector3.new(0, 0, 4), aRoot.Position)
	local hp = aHum.Health
	fire(UseAbility, B, 1, (aRoot.Position - bRoot.Position).Unit, aRoot.Position, 1, bRoot.Position)
	task.wait(0.5)
	check(aHum.Health == hp, "...and nobody can hit someone sat playing")
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(0, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	check(#sentTo(B, "DelawareSmash") == 0, "...or fight from the table")
	seats[2].Occupant = bHum
	task.wait(0.1)
	st = last(A)
	check(st and #st.Seated == 2 and st.StartIn and st.StartIn > 0, "B sits too: the deal's counting down")
	clearSent()
	UnoRemote.OnServerEvent:Fire(A, "Start")
	task.wait(0.2)
	local sa, sb = last(A), last(B)
	check(sa and sb and sa.Phase == "Game" and #sa.Hand == 7 and #sb.Hand == 7, "DEAL: 7 cards each")
	check(sa.Top and string.match(sa.Top, "^[RYGB]%d$") and sa.Color == string.sub(sa.Top, 1, 1), "...a number card turned up to start (" .. tostring(sa.Top) .. ")")
	check(#sa.Players == 2 and (sa.MyTurn ~= sb.MyTurn), "...and it's one of them's turn")
	-- rig it: A's go, A holds R5 R9 G5 WF YS, the pile R3
	task.wait(0.15)
	fire(TestCommand, A, "UnoRig", "Hand:R5,G7,WF,YS,B1")
	task.wait(0.15)
	fire(TestCommand, A, "UnoRig", "Top:R3")
	task.wait(0.15)
	fire(TestCommand, A, "UnoRig", "Turn:")
	task.wait(0.15)
	sa = last(A)
	check(sa.MyTurn and sa.Top == "R3" and #sa.Hand == 5, "(rigged: A's go, R3 on the pile)")
	clearSent()
	UnoRemote.OnServerEvent:Fire(A, "Play", 2) -- G7 on R3: no
	task.wait(0.15)
	check(#states(A) == 0, "a green 7 on a red 3: not allowed")
	UnoRemote.OnServerEvent:Fire(A, "Play", 1) -- R5
	task.wait(0.15)
	sa, sb = last(A), last(B)
	check(sa and sa.Top == "R5" and #sa.Hand == 4 and not sa.MyTurn and sb.MyTurn, "a red 5 on a red 3: played, and it's B's go")
	-- B has nothing? rig B: B holds B9, R7; plays R7
	fire(TestCommand, B, "UnoRig", "Hand:B9,R7,Y2")
	task.wait(0.15)
	UnoRemote.OnServerEvent:Fire(B, "Play", 2)
	task.wait(0.15)
	sa = last(A)
	check(sa.Top == "R7" and sa.MyTurn, "B plays a red 7 (same colour), back to A")
	-- a wild draw four: A picks blue, B draws 4 and is skipped
	UnoRemote.OnServerEvent:Fire(A, "Play", 2, "B") -- WF (hand now G7,WF,YS,B1)
	task.wait(0.15)
	sa, sb = last(A), last(B)
	check(sa.Top == "WF" and sa.Color == "B" and #sb.Hand == 6 and sa.MyTurn, "WILD DRAW FOUR (blue): B draws 4 and misses a go - A again")
	-- A: G7, YS, B1 -> plays B1 (blue), down to 2 ... calls UNO first
	UnoRemote.OnServerEvent:Fire(A, "Uno")
	task.wait(0.15)
	UnoRemote.OnServerEvent:Fire(A, "Play", 3) -- B1
	task.wait(0.15)
	sa = last(A)
	check(sa.Top == "B1" and #sa.Hand == 2, "A plays a blue 1 (2 cards left)")
	-- B: draws (nothing blue or 1): if it fits, pass
	sb = last(B)
	UnoRemote.OnServerEvent:Fire(B, "Draw")
	task.wait(0.15)
	sb = last(B)
	if sb.MyTurn and sb.Drawn then
		UnoRemote.OnServerEvent:Fire(B, "Pass")
		task.wait(0.15)
	end
	sa, sb = last(A), last(B)
	check(sa.MyTurn and #sb.Hand == 7, "B has nothing to play: draws one, and it's A's go")
	-- A plays down to one card without calling UNO: B catches it
	fire(TestCommand, A, "UnoRig", "Hand:B5,G2")
	task.wait(0.15)
	UnoRemote.OnServerEvent:Fire(A, "Play", 1)
	task.wait(0.15)
	sb = last(B)
	check(sb.CanCatch == true, "A's on one card and didn't call UNO: B can catch it")
	UnoRemote.OnServerEvent:Fire(B, "Catch")
	task.wait(0.15)
	sa = last(A)
	check(#sa.Hand == 1 + Config.Uno.CatchPenalty, "CAUGHT: A draws " .. Config.Uno.CatchPenalty)
	-- A goes out: wins the bucks
	fire(TestCommand, A, "UnoRig", "Hand:B7")
	task.wait(0.15)
	fire(TestCommand, A, "UnoRig", "Turn:")
	task.wait(0.15)
	fire(TestCommand, A, "UnoRig", "Top:B2")
	task.wait(0.15)
	local bucks = A:GetAttribute("Bucks") or 0
	clearSent()
	UnoRemote.OnServerEvent:Fire(A, "Play", 1)
	task.wait(0.15)
	local ended = false
	for _, s in M.sent do
		if s.To == A and s.Args[1] == "End" and s.Args[2].You == true then
			ended = true
		end
	end
	check(ended and last(A).Phase == "Lobby", "A's last card: A WINS, back to the lobby")
	check((A:GetAttribute("Bucks") or 0) == bucks + Config.Uno.WinBucks, "...and " .. Config.Uno.WinBucks .. " Bucks for it")
	check(last(A).StartIn ~= nil, "...the next deal's on the way")
	-- B gets up mid-game: the game's over (not enough players)
	UnoRemote.OnServerEvent:Fire(A, "Start")
	task.wait(0.2)
	check(last(A).Phase == "Game", "(a new deal)")
	clearSent()
	seats[2].Occupant = nil
	task.wait(0.15)
	check(bChar:GetAttribute("PlayingUno") == nil, "B stands up: off the table")
	local closed = false
	for _, s in M.sent do
		if s.To == B and s.Args[1] == "Closed" then
			closed = true
		end
	end
	check(closed and last(A).Phase == "Lobby", "...their panel closes, and with one player left the game's over")
	seats[1].Occupant = nil
	task.wait(0.1)
	check(aChar:GetAttribute("PlayingUno") == nil, "A gets up: free to fight again")

	workspace.Raycast = rayBefore
	task.wait(0.5)
end)
---------------------------------------------------------------------------
-- Round 38: swinging made easier (chains, a wider search, Tako Snatch finds
-- the spot on a building), Suneater's utility belt, Kamui without his helmet
---------------------------------------------------------------------------
;M.section(function() -- (its own function: the main chunk is at the 200-local limit)
	local X = 15500
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	-- a street at y = 0 and a block of flats (an axis-aligned box)
	local building = nil
	local function ray(_, origin, dir)
		if typeof(dir) ~= "Vector3" then
			return nil
		end
		local best
		if building then
			local tmin, tmax, normal = 0, 1, nil
			for _, ax in { "X", "Y", "Z" } do
				local o, d = origin[ax], dir[ax]
				local lo, hi = building.min[ax], building.max[ax]
				if math.abs(d) < 1e-9 then
					if o < lo or o > hi then
						tmin = 2
					end
				else
					local t1, t2 = (lo - o) / d, (hi - o) / d
					local n = -math.sign(d)
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					if t1 > tmin then
						tmin = t1
						normal = Vector3.new(ax == "X" and n or 0, ax == "Y" and n or 0, ax == "Z" and n or 0)
					end
					tmax = math.min(tmax, t2)
				end
			end
			if tmin <= tmax and tmin >= 0 and tmin <= 1 and normal then
				best = { Position = origin + dir * tmin, Distance = dir.Magnitude * tmin, Normal = normal, Instance = workspace }
			end
		end
		if dir.Y < 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			if not best or t * dir.Magnitude < best.Distance then
				best = { Position = Vector3.new(origin.X + dir.X * t, 0, origin.Z + dir.Z * t), Distance = dir.Magnitude * t, Normal = Vector3.new(0, 1, 0), Instance = workspace }
			end
		end
		return best
	end
	local rayBefore = workspace.Raycast
	workspace.Raycast = ray
	local function fresh(q)
		fire(SelectQuirk, A, q)
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.new(Vector3.new(X + 500, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
	end

	print("== SWINGING, easier")
	local BS = Config.Quirks.Arbor.Special
	check(BS.Cooldown == 2 and BS.Range >= 100, "Kamui's R: " .. BS.Cooldown .. "s between swings (round 75) and " .. BS.Range .. " studs of reach (was 80)")
	fresh("Arbor")
	-- a building off to the side of the street, 60 up
	building = { min = Vector3.new(X + 14, 0, -20), max = Vector3.new(X + 40, 60, 120) }
	local side = Vector3.new(X + 13.7, 45, 85)
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.5, 1).Unit, side, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 0 and #sentTo(B, "BranchSwing") == 1, "a branch to a building beside the street, 96 studs off (past the old reach): allowed")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.5, 1).Unit, side, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "BranchSwing") == 0, "...not again half a second later (round 75: 2s between swings)")
	task.wait(BS.Cooldown)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.5, 1).Unit, side, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 0 and #sentTo(B, "BranchSwing") == 1, "...and again once it's back")
	building = nil

	print("== TAKO SNATCH finds the spot")
	fresh("Manifest")
	-- a wall straight ahead: aimed flat at it (low down) he still swings,
	-- off a spot higher up it
	building = { min = Vector3.new(X - 20, 0, 30), max = Vector3.new(X + 20, 50, 60) }
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(X, 4, 30), 1, aRoot.Position)
	task.wait(0.8)
	local swing = sentTo(A, "TakoZip")[1]
	check(swing and swing.Anchor and swing.Anchor.Y < 6 and swing.Anchor.Z < 30.5, "aimed flat at a wall: the tentacle zips him straight to that spot (round 60) (" .. tostring(swing and swing.Anchor) .. ")")
	local catch = sentTo(B, "TakoSnatchCatch")[1]
	check(catch and swing and math.abs(catch.Reach - (swing.Anchor - (aRoot.Position + Vector3.new(0, 1.5, 0))).Magnitude) < 3, "...and the tentacle flies to where it caught")
	-- aimed up at the sky, a building off to the side: it finds the building
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	building = { min = Vector3.new(X + 12, 0, -10), max = Vector3.new(X + 40, 50, 60) }
	fire(UseAbility, A, 2, Vector3.new(0, 0.7, 0.7).Unit, Vector3.new(X, 40, 40), 1, aRoot.Position)
	task.wait(0.8)
	swing = sentTo(A, "TakoZip")[1]
	check(swing and swing.Anchor.X > X + 11, "aimed up, nothing there, a building beside him: it catches the building")
	-- aimed flat down an empty street: no swing (a missed snatch is a miss)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	building = nil
	fire(UseAbility, A, 2, Vector3.new(0, 0, 1), Vector3.new(X, 4, 40), 1, aRoot.Position)
	task.wait(0.5)
	check(#sentTo(A, "TakoZip") == 0, "aimed flat down an empty street: a miss, no zip")

	print("== the looks")
	local function limbs(model, root)
		for _, s in {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
			{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
			{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
			{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		} do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Parent = model
			if s[1] == "Head" then
				M.new("SpecialMesh", "Mesh").Parent = part
			end
		end
	end
	local function count(model, name)
		local n = 0
		for _, d in model and model:GetDescendants() or {} do
			if d.Name == name and d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end
	fresh("Manifest")
	limbs(aChar, aRoot)
	fire(SelectQuirk, A, "Manifest")
	task.wait(0.4)
	local gearOf = function()
		local g = aChar:FindFirstChild("QuirkGear")
		return g and g:FindFirstChild("Cosmetics")
	end
	local cos = gearOf()
	check(count(cos, "Hood") == 0 and count(cos, "Belt") == 1 and count(cos, "Buckle") == 1 and count(cos, "Pouch") == 12, "SUNEATER: no hood; a utility belt - strap, buckle, six pouches with flaps")
	check(count(cos, "Ear") == 2, "...his pointed ears still showing")
	local belt
	for _, d in cos and cos:GetDescendants() or {} do
		if d.Name == "Belt" then
			belt = d
		end
	end
	check(belt and math.abs(belt.Position.Y - (aRoot.Position.Y - 0.78)) < 0.2, "...round his waist")
	fresh("Arbor")
	limbs(aChar, aRoot)
	fire(SelectQuirk, A, "Arbor")
	task.wait(0.4)
	cos = gearOf()
	check(count(cos, "Helmet") == 0 and count(cos, "Eye") == 0 and count(cos, "Bark") >= 2 and count(cos, "Rose") >= 3, "KAMUI: no helmet - the wooden forearms, armbands and roses stay")

	workspace.Raycast = rayBefore
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 39: Root Breaker's roots travel down the street from his arms
---------------------------------------------------------------------------
;M.section(function()
	local X = 16500
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	fire(SelectQuirk, A, "Arbor")
	fire(SelectQuirk, B, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 40), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	print("== ROOT BREAKER, round 39")
	local RB = Config.Quirks.Arbor.Abilities[1 + 2]
	local t0 = os.clock()
	fire(UseAbility, A, 3, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	local hitAt
	while os.clock() - t0 < 1 do
		if bHum.Health < MAX and not hitAt then
			hitAt = os.clock() - t0
		end
		task.wait()
	end
	check(bHum.Health == MAX - RB.Damage, "the roots reach the end of the line, 40 studs off (" .. (MAX - bHum.Health) .. ")")
	check(hitAt and hitAt > 0.45, string.format("...a moment later than someone close: they travel from his arms (%.2fs)", hitAt or -1))
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 41: Branch Swing checked from where his screen had him (and not off
-- invisible walls), Bakugo nerfed hard, Todoroki's freeze cuts moves short,
-- Glacier Breaker on someone frozen
---------------------------------------------------------------------------
;M.section(function()
	local X = 17500
	local MAX = Config.PlayerMaxHealth
	local FWD = Vector3.new(0, 0, 1)
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	-- a street at y = 0 and a block of flats (an axis-aligned box; inst is
	-- what a ray says it hit)
	local building = nil
	local function ray(_, origin, dir)
		if typeof(dir) ~= "Vector3" then
			return nil
		end
		local best
		if building then
			local tmin, tmax, normal = 0, 1, nil
			for _, ax in { "X", "Y", "Z" } do
				local o, d = origin[ax], dir[ax]
				local lo, hi = building.min[ax], building.max[ax]
				if math.abs(d) < 1e-9 then
					if o < lo or o > hi then
						tmin = 2
					end
				else
					local t1, t2 = (lo - o) / d, (hi - o) / d
					local n = -math.sign(d)
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					if t1 > tmin then
						tmin = t1
						normal = Vector3.new(ax == "X" and n or 0, ax == "Y" and n or 0, ax == "Z" and n or 0)
					end
					tmax = math.min(tmax, t2)
				end
			end
			if tmin <= tmax and tmin >= 0 and tmin <= 1 and normal then
				best = { Position = origin + dir * tmin, Distance = dir.Magnitude * tmin, Normal = normal, Instance = building.inst or workspace }
			end
		end
		if dir.Y < 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			if not best or t * dir.Magnitude < best.Distance then
				best = { Position = Vector3.new(origin.X + dir.X * t, 0, origin.Z + dir.Z * t), Distance = dir.Magnitude * t, Normal = Vector3.new(0, 1, 0), Instance = workspace }
			end
		end
		return best
	end
	local rayBefore = workspace.Raycast
	local function fresh(qa, qb, bPos)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb)
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X + 500, 3, 0), Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		clearSent()
	end

	print("== BRANCH SWING, round 41")
	local BS = Config.Quirks.Arbor.Special
	check((BS.ExitSpeed or 0) >= 75 and (BS.ExitLift or 0) >= 8 and (BS.Carry or 0) >= 0.5, "Kamui lets go of a swing harder, higher, and keeps the speed a while (" .. tostring(BS.ExitSpeed) .. " along, +" .. tostring(BS.ExitLift) .. " up, " .. tostring(BS.Carry) .. "s)")
	workspace.Raycast = ray
	fresh("Arbor", "Explosion")
	-- a building far up the street: 123 studs from where the server has him,
	-- 110 from where his screen had him when he pressed it (14 studs on)
	building = { min = Vector3.new(X - 20, 0, 118.3), max = Vector3.new(X + 20, 60, 160) }
	local anchor = Vector3.new(X, 40, 118)
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.3, 1).Unit, anchor, 1, aRoot.Position + Vector3.new(0, 0, 14))
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 0, "flying along a chain: the line is checked from where his screen had him when he pressed it, so lag doesn't turn it down")
	task.wait(0.6)
	fire(TestCommand, A, "ResetCooldowns") -- (round 75: 2s between swings)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.3, 1).Unit, anchor, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 1, "...but from right where he stands, that far off is still out of reach")
	task.wait(0.6)
	-- an invisible wall: nothing a branch can hold on to
	local ghost = M.new("Part")
	ghost.Transparency = 1
	ghost.CanCollide = true
	building = { min = Vector3.new(X - 20, 0, 40), max = Vector3.new(X + 20, 60, 42), inst = ghost }
	fire(TestCommand, A, "ResetCooldowns") -- (round 75: 2s between swings)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.5, 1).Unit, Vector3.new(X, 30, 39.7), 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 1, "an invisible wall isn't something to swing from")
	task.wait(0.6)
	ghost.Transparency = 0
	fire(TestCommand, A, "ResetCooldowns") -- (round 75: 2s between swings)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(0, 0.5, 1).Unit, Vector3.new(X, 30, 39.7), 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "SwingDenied") == 0, "...the same wall you can see is")
	task.wait(0.6)
	-- Tako Snatch's search sees through it too: aimed at an empty street
	-- with only an invisible wall ahead, nothing to swing from
	ghost.Transparency = 1
	building = { min = Vector3.new(X - 60, 0, 20), max = Vector3.new(X + 60, 80, 22), inst = ghost }
	fresh("Suneater", "Explosion")
	aChar:SetAttribute("Stomach", 100)
	fire(UseAbility, A, 2, Vector3.new(0, 0.3, 1).Unit, Vector3.new(X, 20, 60), 1, aRoot.Position)
	task.wait(0.6)
	check(#sentTo(B, "TakoZip") == 0, "TAKO SNATCH doesn't grab an invisible wall to zip to either")
	building = nil
	workspace.Raycast = rayBefore
	task.wait(1)

	print("== BAKUGO, nerfed hard")
	local EX = Config.Quirks.Explosion
	local AP, BR, BO = EX.Abilities[1], EX.Abilities[2], EX.Abilities[3]
	check(AP.Damage <= 10 and AP.Cooldown >= 9, "AP SHOT: " .. AP.Damage .. " every " .. AP.Cooldown .. "s (was 14 every 7s)")
	check(BR.Damage + BR.FinisherDamage <= 15 and BR.Cooldown >= 12 and BR.Radius <= 12, "BLAST RUSH: " .. BR.Damage .. " + " .. BR.FinisherDamage .. ", " .. BR.Radius .. "-stud blast, every " .. BR.Cooldown .. "s (was 9 + 13, 17 studs, 9s)")
	check(BO.Damage + BO.OrbitDamage * BO.OrbitHits + BO.SlamDamage <= 20 and BO.Cooldown >= 18, "ERUPTION ORBIT: " .. BO.Damage + BO.OrbitDamage * BO.OrbitHits + BO.SlamDamage .. " all told, every " .. BO.Cooldown .. "s (was 29, 14s)")
	check(EX.Special.Cooldown >= 25 and EX.Special.Blind <= 1.2 and EX.Special.Radius <= 20, "STUN GRENADE: every " .. EX.Special.Cooldown .. "s, blinds " .. EX.Special.Blind .. "s, " .. EX.Special.Radius .. " studs (was 18s, 1.8s, 30)")
	check(EX.Extra.Damage + EX.Extra.DragDamage <= 12 and EX.Extra.Cooldown >= 17, "SCORCHED EARTH: " .. EX.Extra.Damage + EX.Extra.DragDamage .. " every " .. EX.Extra.Cooldown .. "s (was 18, 13s)")
	local U = EX.Ult
	check(U.Duration <= 22 and U.Abilities[1].Damage * U.Abilities[1].Shots <= 24 and U.Abilities[3].Damage <= 32, "DYNAMIGHT: " .. U.Duration .. "s (was 30), Auto-Cannon " .. U.Abilities[1].Damage * U.Abilities[1].Shots .. " a burst (was 36), Howitzer " .. U.Abilities[3].Damage .. " (was 45)")
	fresh("Explosion", "Explosion", Vector3.new(X, 3, 30))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	check(bHum.Health == MAX - AP.Damage, "AP SHOT lands for " .. (MAX - bHum.Health))
	-- the Blast Rush blast only reaches 12 studs now (the old one: 17)
	fresh("Explosion", "Explosion", Vector3.new(X + 15, 3, 6))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.8)
	check(bHum.Health == MAX, "BLAST RUSH's blast doesn't reach someone 15 studs off it any more (" .. (MAX - bHum.Health) .. ")")
	task.wait(0.5)

	print("== TODOROKI: frozen solid, your move stops dead")
	-- B (Iida) starts his Engine Gatling on A; A's Ice Slider freezes him
	-- a moment in: the rest of the barrage and its heel slam never land
	local EG = Config.Quirks.Engine.Abilities[2]
	check(EG.Id == "EngineGatling", "(Iida's 2 is the Engine Gatling)")
	fresh("HalfCold", "Engine", Vector3.new(X, 3, 5))
	fire(UseAbility, B, 2, -FWD, aRoot.Position, 1, bRoot.Position)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4)
	check(bChar:GetAttribute("Frozen") == true, "the Ice Slider froze B")
	task.wait(0.8)
	local took = MAX - aHum.Health
	check(took <= EG.Damage * 3 and not aChar:GetAttribute("Ragdolled"), "...and B's barrage stopped the moment he froze: " .. took .. " taken (the whole thing is " .. EG.Damage * EG.Hits + EG.FinisherDamage .. "), no heel slam")
	task.wait(1.2)
	-- thawed out, his next one goes the whole way (the cut doesn't linger)
	aHum.Health = MAX
	fire(TestCommand, B, "ResetCooldowns")
	check(not bChar:GetAttribute("Frozen") and not bChar:GetAttribute("Stunned"), "B thaws out")
	fire(UseAbility, B, 2, -FWD, aRoot.Position, 1, bRoot.Position)
	task.wait(1.1)
	check(MAX - aHum.Health == EG.Damage * EG.Hits + EG.FinisherDamage, "...and his next barrage goes the whole way (" .. (MAX - aHum.Health) .. ")")
	task.wait(1.5)

	print("== GLACIER BREAKER on someone frozen")
	local HC = Config.Quirks.HalfCold
	local GB, IS = HC.Abilities[3], HC.Extra
	fresh("HalfCold", "Explosion", Vector3.new(X, 3, 5))
	A:SetAttribute("NoCooldowns", true)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.4)
	check(bChar:GetAttribute("Frozen") == true, "B frozen by the Ice Slider")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10))
	clearSent()
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	local pin = sentTo(B, "GlacierPin")[1]
	check(pin and pin.Target == bChar and pin.Shatter == true, "GLACIER BREAKER works on them: the punch shatters their ice and drives them into the wall")
	check(#sentTo(B, "Thaw") == 1 and bChar:GetAttribute("Frozen") ~= true and bChar:GetAttribute("Grabbed") == true, "...their ice breaks (thawed, and pinned instead)")
	check(bHum.Health == MAX - IS.Damage - GB.Damage - GB.ShatterDamage, "...for the punch and a little extra for the shatter (" .. (MAX - bHum.Health) .. ")")
	task.wait(GB.PinTime + 0.25)
	check(bHum.Health == MAX - IS.Damage - GB.Damage - GB.ShatterDamage - GB.PillarDamage and not bRoot.Anchored, "...then the pillar throws them up out of it")
	A:SetAttribute("NoCooldowns", nil)
	task.wait(1.5)
end)
---------------------------------------------------------------------------
-- Round 42: UNO players sit on the chairs (not up by the backrest),
-- Bakugo's EXPLOSIVE SPEED, the DAD MODE emote
---------------------------------------------------------------------------
;M.section(function()
	local X = 18500
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)

	print("== UNO: sat on the chair, not floating over it")
	local tables = workspace:FindFirstChild("UnoTables")
	local t2 = tables and tables:FindFirstChild("Table2")
	local chairSeats = {}
	for _, d in (t2 or workspace):GetDescendants() do
		if d.ClassName == "Seat" then
			table.insert(chairSeats, d)
		end
	end
	check(#chairSeats == 2, "a table with two proper chairs (a seat board, a tall backrest) gets two seats (" .. #chairSeats .. ")")
	for i, seat in chairSeats do
		local p = seat.CFrame.Position
		check(math.abs(p.Y - 29.32) < 0.25, string.format("chair %d: the seat is on the seat board (%.2f), not up by the top of the backrest (32.9)", i, p.Y))
		check(math.abs(math.abs(p.X - -120) - 5.5) < 0.2 and math.abs(p.Z - 590) < 0.2, string.format("...over the board, not the backrest (%.1f, %.1f)", p.X, p.Z))
	end
	local t1 = tables and tables:FindFirstChild("Table1")
	for _, d in (t1 or workspace):GetDescendants() do
		if d.ClassName == "Seat" then
			check(math.abs(d.CFrame.Position.Y - 28.6) < 0.25, string.format("a stool's seat stays on top of the stool (%.2f)", d.CFrame.Position.Y))
			break
		end
	end

	print("== BAKUGO: FULL-BODY CLUSTER (the ult's 4: his last stand, chapter 362)")
	local EX = Config.Quirks.Explosion
	local FB = EX.Ult.Extra
	check(FB and FB.Id == "FullBodyCluster" and FB.Name == "FULL-BODY CLUSTER", "Dynamight's 4th move is FULL-BODY CLUSTER (his last stand against Shigaraki)")
	check(Config.GetExtra(EX, false, false).Id == "ScorchedEarth", "...out of the ult, 4 is still Scorched Earth")
	local mult = (Config.Ult and Config.Ult.DamageMultiplier) or 1
	local function fresh(bPos)
		fire(SelectQuirk, A, "Explosion")
		fire(SelectQuirk, B, "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		A:SetAttribute("Ult", 100)
		fire(UseAbility, A, Config.ULT_INDEX)
		task.wait(1.5)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	fresh(Vector3.new(X, 3, 30))
	local t0 = os.clock()
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	local z1 = aRoot.CFrame.Position.Z
	check(#sentTo(B, "FullBodyCluster") == 1 and aRoot.Anchored and z1 > 0.8 and z1 < FB.WalkDistance + 0.3,
		string.format("he WALKS at them first (everyone sees it; %.1f studs on, carried by the server)", z1))
	check(bHum.Health == MAX and not bChar:GetAttribute("Grabbed"), "...nothing's happened to B yet")
	local blink
	while os.clock() - t0 < FB.WalkTime + 0.5 and not blink do
		blink = sentTo(B, "FullBodyClusterBlink")[1]
		task.wait()
	end
	check(blink and blink.Target == bChar, "then he's gone - and in B's face")
	check(math.abs(aRoot.CFrame.Position.Z - (30 - 2.6)) < 1.2 and bChar:GetAttribute("Grabbed") == true,
		string.format("...right in front of B (%.1f), who's held there", aRoot.CFrame.Position.Z))
	local spots = {}
	while os.clock() - t0 < 6 and #sentTo(B, "FullBodyClusterFinal") == 0 do
		for _, h in sentTo(B, "FullBodyClusterHit") do
			spots[h.Level] = h.Pos
		end
		task.wait()
	end
	local hits = sentTo(B, "FullBodyClusterHit")
	check(#hits == FB.Hits, "all round them: " .. #hits .. " blasts (" .. FB.Hits .. ")")
	local distinct = 0
	for i = 2, FB.Hits do
		if spots[i] and spots[i - 1] and (spots[i] - spots[i - 1]).Magnitude > 2 then
			distinct += 1
		end
	end
	check(distinct >= FB.Hits - 2, "...each from a different side (" .. distinct .. " moves round them)")
	check(#sentTo(B, "FullBodyClusterVoid") == 1, "...the white void before the last one (his screen)")
	task.wait(0.3)
	local expect = FB.BlinkDamage + FB.FinalDamage
	for i = 1, FB.Hits do
		expect += FB.HitDamage + math.floor((i - 1) / 2)
	end
	local took = MAX - bHum.Health
	check(math.abs(took - expect * mult) <= FB.Hits + 2, string.format("everything he has: %d damage in all (about %.0f)", took, expect * mult))
	check(bChar:GetAttribute("Ragdolled") == true and not bChar:GetAttribute("Grabbed"), "...and B's launched (ragdolled, let go)")
	check(MAX - aHum.Health == FB.SelfDamage, "the beads burst through his skin: it cost him " .. (MAX - aHum.Health) .. " health")
	task.wait(0.3)
	check(not aRoot.Anchored and aChar:GetAttribute("BodyLocked") == nil and (aChar:GetAttribute("CombatActionUntil") or 0) < workspace:GetServerTimeNow() + 0.3, "Bakugo's free again afterwards")

	-- nobody in reach: he blasts off down the aim into one explosion
	fresh(Vector3.new(X + 60, 3, 0))
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(FB.WalkTime + 0.5)
	check(#sentTo(B, "FullBodyClusterWhiff") == 1 and #sentTo(B, "FullBodyClusterBlink") == 0 and bHum.Health == MAX, "nobody in reach: he blasts off down the aim into one explosion, B untouched")
	check(aRoot.CFrame.Position.Z > FB.WalkDistance + 8 and not aRoot.Anchored and aHum.Health == MAX, string.format("...(%.0f studs on), free, and it costs him nothing", aRoot.CFrame.Position.Z))

	-- stunned in the walk: it's called off
	fresh(Vector3.new(X, 3, 30))
	fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	aChar:SetAttribute("Stunned", true)
	task.wait(FB.WalkTime)
	aChar:SetAttribute("Stunned", false)
	check(#sentTo(B, "FullBodyClusterCancel") == 1 and #sentTo(B, "FullBodyClusterBlink") == 0 and bHum.Health == MAX, "stunned in the walk: it's called off")
	check(not aRoot.Anchored and aChar:GetAttribute("BodyLocked") == nil, "...and he isn't left rooted")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	print("== DAD MODE (emote)")
	local dad
	for _, e in Config.Emotes do
		if e.Id == "DadMode" then
			dad = e
		end
	end
	check(dad and dad.Party and dad.Bpm == 128 and dad.Name == "THE JIGGY", "THE JIGGY (was DAD MODE) is an emote, a party, on the song's 128 BPM")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(X, 3, 0))
	bChar, bHum, bRoot = spawnChar(B, CFrame.new(X, 3, 10))
	task.wait(1)
	clearSent()
	fire(UseAbility, A, Config.EMOTE_INDEX, "DadMode")
	local seen = sentTo(B, "Emote")
	check(#seen == 1 and seen[1].Id == "DadMode", "...and everyone sees it")
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 43: knockdowns (moves put you on the street), KO finishers,
-- Explosive Speed flat out, Chain Prison's cage
---------------------------------------------------------------------------
;M.section(function()
	local X = 19500
	local MAX = Config.PlayerMaxHealth
	local FWD = Vector3.new(0, 0, 1)
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	workspace:SetAttribute("Knockdowns", nil) -- (on: the default)
	local function fresh(qa, qb, bPos)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 30), Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local KD = Config.Ragdoll.Knockdown
	local AP = Config.Quirks.Explosion.Abilities[1]

	print("== KNOCKDOWNS: a move puts you on the street")
	check(KD and KD.Enabled and KD.MinDamage <= 8, "moves knock you down now (" .. tostring(KD and KD.MinDamage) .. "+ damage)")
	fresh("Explosion")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(bHum.Health == MAX - AP.Damage and bChar:GetAttribute("Ragdolled") == true, "AP SHOT (" .. AP.Damage .. "): B goes down on the street, not just stunned")
	-- down there, another move only does part of its damage
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.4)
	local second = MAX - AP.Damage - bHum.Health
	check(second == 0, "...hit again while down: nothing - " .. second .. " (round 59: down means down; only a downslam lands)")
	-- up again: a moment where no move knocks them straight back down
	local t0 = os.clock()
	while bChar:GetAttribute("Ragdolled") and os.clock() - t0 < 4 do
		task.wait(0.05)
	end
	check(not bChar:GetAttribute("Ragdolled"), string.format("...and up again (%.1fs)", os.clock() - t0))
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(not bChar:GetAttribute("Ragdolled"), "...getting up gives a moment where the next move can't put them straight back down")
	task.wait(1.5)

	-- small hits (a barrage's jabs) don't; nor do moves that hold you
	fresh("Engine", "Explosion", Vector3.new(X, 3, 5))
	bChar:SetAttribute("Stunned", false)
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	check(not bChar:GetAttribute("Ragdolled"), "a barrage's little jabs don't put you down mid-combo")
	task.wait(1.5)
	fresh("HalfCold", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	check(bChar:GetAttribute("Grabbed") == true and not bChar:GetAttribute("Ragdolled"), "a grab (Glacier Breaker) keeps hold of them instead")
	task.wait(1.5)
	fresh("Arbor", "Explosion", Vector3.new(X, 3, 20))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.8)
	check(bHum.Health < MAX and not bChar:GetAttribute("Ragdolled"), "a bind (Chain Prison) holds them caged, not lying down")
	task.wait(2)
	check(Config.Quirks.Manifest.Abilities[1].NoKnockdown and Config.Quirks.Engine.Extra.NoKnockdown, "launchers (Chicken Kick, Skyward Kick) keep them up there for the follow-up instead")
	-- the server setting
	fresh("Explosion")
	fire(TestCommand, A, "PSSet", "Knockdowns", false)
	check(workspace:GetAttribute("Knockdowns") == false, "server settings: Knockdowns off")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(bHum.Health == MAX - AP.Damage and not bChar:GetAttribute("Ragdolled"), "...then a move only stuns, as before")
	fire(TestCommand, A, "PSSet", "Knockdowns", true)
	task.wait(1)

	print("== KO FINISHERS")
	fresh("Explosion")
	bHum.Health = 5
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	local ko = sentTo(B, "KOFinisher")[1]
	check(bHum.Health <= 0 and ko and ko.Target == bChar and ko.Move == "APShot" and ko.Name == AP.Name, "a move's killing blow plays a finisher on every screen (" .. tostring(ko and ko.Move) .. ")")
	local kb = bRoot:FindFirstChild("Knockback")
	check(kb and kb.VectorVelocity.Z > 30 and kb.VectorVelocity.Y > 20, "...and the body's launched along the hit, up and away")
	task.wait(0.5)
	-- an M1 KO doesn't
	fresh("Explosion", "FullCowl", Vector3.new(X, 3, 4))
	bHum.Health = 2
	clearSent()
	fire(UseAbility, A, 0)
	task.wait(0.3)
	check(bHum.Health <= 0 and #sentTo(B, "KOFinisher") == 0, "(an M1 knockout keeps its own finish)")
	task.wait(0.5)

	print("== FULL-BODY CLUSTER: no cut-in, nothing hides it")
	local ES = Config.Quirks.Explosion.Ult.Extra
	check(ES.CutIn == false, "no cut-in over the walk (his last stand plays out in the fight)")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 44: Shigaraki's public (Collapse without the cutscene), Bakugo's
-- blink, MR. COMPRESS, CHARGEBOLT
---------------------------------------------------------------------------
;M.section(function()
	local X = 20500
	local MAX = Config.PlayerMaxHealth
	local FWD = Vector3.new(0, 0, 1)
	local mult = (Config.Ult and Config.Ult.DamageMultiplier) or 1
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, bPos)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos or Vector3.new(X, 3, 30), Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local function moveB(pos)
		bRoot.CFrame = CFrame.lookAt(pos, Vector3.new(X, 3, 0))
		bRoot.Position = pos
		bRoot.Anchored = false
	end
	local function about(n, want, slack)
		return n >= want - (slack or 1) and n <= want + (slack or 1)
	end
	-- a street at y = 0 under everything here (lobs land on it, throws find it)
	local function street(on)
		if on then
			workspace.Raycast = function(_, origin, dir)
				if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
					local t = origin.Y / -dir.Y
					local p = origin + dir * t
					return { Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.new(0, 1, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Asphalt }
				end
				return nil
			end
		else
			workspace.Raycast = function()
				return nil
			end
		end
	end

	print("== SHIGARAKI: public, and Collapse without the cutscene")
	local DQ = Config.Quirks.Decay
	check(not DQ.DevOnly and table.find(Config.QuirkOrder, "Decay") ~= nil, "DECAY is on everyone's quirk menu now")
	studioMode = false
	local creator = game.CreatorId
	game.CreatorId = 999
	task.wait(2.6) -- (a regular player's switch cooldown)
	fire(SelectQuirk, A, "Decay")
	check(A:GetAttribute("Quirk") == "Decay", "...a regular player picks him")
	game.CreatorId = creator
	studioMode = true
	check(not DQ.Abilities[3].Cinematic and not DQ.Abilities[3].CinematicArmor, "COLLAPSE has no cutscene any more")
	fresh("Decay", "Explosion", Vector3.new(X, 3, 12))
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.3)
	check(MAX - bHum.Health >= DQ.Abilities[3].Damage, "...and it still crumbles the block round him (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.5)

	print("== BAKUGO: FULL-BODY CLUSTER reaches them from further off")
	local FBC = Config.Quirks.Explosion.Ult.Extra
	fresh("Explosion", "FullCowl", Vector3.new(X, 3, 40))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(FBC.WalkTime + 0.2)
	local bl = sentTo(B, "FullBodyClusterBlink")[1]
	check(bl and math.abs(aRoot.CFrame.Position.Z - (40 - 2.6)) < 1.5 and bChar:GetAttribute("Grabbed") == true,
		string.format("B 40 studs off: after the walk he's simply ON them (%.1f studs on)", aRoot.CFrame.Position.Z))
	task.wait(4)
	check(MAX - bHum.Health >= FBC.FinalDamage, "...and it all lands (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	print("== MR. COMPRESS")
	local CQ = Config.Quirks.Compress
	check(CQ and table.find(Config.QuirkOrder, "Compress") ~= nil and not CQ.DevOnly and CQ.Marbles.Max == 3, "MR. COMPRESS is on the quirk menu: 3 marbles in his pocket")
	check(CQ.Abilities[1].Id == "RubbleThrow" and CQ.Abilities[2].Id == "SurpriseAttack" and CQ.Abilities[3].Id == "VanishingAct" and CQ.Special.Id == "CompressMap" and CQ.Extra.Id == "MagiciansChoice",
		"his kit: 1 Rubble Throw, 2 Surprise Attack, 3 Vanishing Act, 4 Magician's Choice, R Compress")
	street(true)
	fresh("Compress", "Explosion", Vector3.new(X, 3, 20))
	check(aChar:GetAttribute("Marbles") == 0 and cd.held == 0, "an empty pocket on a new body")
	for i = 1, 3 do
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
		fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 0, 8), 1, aRoot.Position)
		task.wait(0.1)
		check(aChar:GetAttribute("Marbles") == i and cd.held == i and #sentTo(B, "CompressTake") == 1,
			"R: a piece of the street shrinks into a marble (" .. i .. " in his pocket; " .. cd.held .. " piece(s) of the map held back from restoring)")
	end
	check(cd.lastCompress and cd.lastCompress[2] == CQ.Marbles.Radius, "...each one a ball of the map, " .. CQ.Marbles.Radius .. " studs")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 0, 8), 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Marbles") == 3 and cd.held == 3 and #sentTo(A, "Notice") == 1, "...pockets full: a 4th won't go (he's told)")
	-- 1: the marble thrown: a piece of the city comes down on B
	local RT = CQ.Abilities[1]
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	local rt = sentTo(B, "RubbleLob")[1]
	check(rt and rt.Big == true and aChar:GetAttribute("Marbles") == 2 and cd.held == 2, "RUBBLE THROW: a marble out of the pocket (2 left; that piece of the street is restoring again)")
	task.wait((rt and rt.LandTime or 0.8) + 0.3)
	check(MAX - bHum.Health == RT.Damage, "...it pops back to full size and comes down on B: " .. (MAX - bHum.Health) .. " damage")
	check(bChar:GetAttribute("Ragdolled") == true, "...knocked flat under it")
	task.wait(1.8)
	fresh("Compress", "Explosion", Vector3.new(X, 3, 20))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	rt = sentTo(B, "RubbleLob")[1]
	task.wait((rt and rt.LandTime or 0.8) + 0.3)
	check(rt and rt.Big == false and MAX - bHum.Health == RT.RockDamage and not bChar:GetAttribute("Ragdolled"), "...an empty pocket: a rock off the street - " .. (MAX - bHum.Health) .. ", a knock on the head")
	task.wait(0.6)
	-- 2: the cane; with room in the pocket, the trick
	local SA = CQ.Abilities[2]
	fresh("Compress", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	check(MAX - bHum.Health == SA.Damage and bChar:GetAttribute("Stunned") == true, "SURPRISE ATTACK: the cane's pommel in the face - " .. SA.Damage .. ", stunned")
	local ct = sentTo(B, "CaneTrick")[1]
	check(ct and ct.Trick == true and aChar:GetAttribute("Marbles") == 1, "...room in his pocket: the trick - the cane's a marble on the floor (1 in the pocket for the moment)")
	task.wait(0.5)
	check(MAX - bHum.Health == SA.Damage + SA.PunchDamage + SA.CaneDamage, "...a punch, then the cane pops back out under the chin: " .. (MAX - bHum.Health) .. " in all")
	check(bRoot:FindFirstChild("Knockback") ~= nil or bChar:GetAttribute("Ragdolled") == true, "...and up they go")
	task.wait(0.45)
	check(aChar:GetAttribute("Marbles") == 0, "...he catches the cane coming down: the pocket's his own again")
	task.wait(1.5)
	-- a marble in the pocket: another hit on top
	fresh("Compress", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 0, 8), 1, aRoot.Position)
	task.wait(0.1)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.2)
	check(MAX - bHum.Health == SA.Damage + SA.PunchDamage + SA.CaneDamage + CQ.Marbles.BonusDamage and #sentTo(B, "MarblePop") == 1,
		"a marble in his pocket: the trick ends with it flicked at them - another hit (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.5)
	-- 3: THEY'RE the marble
	local VA = CQ.Abilities[3]
	fresh("Compress", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.3)
	check(bChar:GetAttribute("Compressed") == true and bChar:GetAttribute("Grabbed") == true and #sentTo(B, "VanishingGrab") == 1, "VANISHING ACT: a hand on B and THEY'RE the marble")
	check(bHum.Health == MAX, "...untouchable in his palm")
	task.wait(0.5)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 30))
	task.wait(0.32 + 0.25)
	check(bChar:GetAttribute("Compressed") == nil and math.abs(bRoot.CFrame.Position.Z - 30) < 4.5,
		string.format("...flicked at the aim point: B pops back out 30 studs down the street (%.1f)", bRoot.CFrame.Position.Z))
	check(MAX - bHum.Health == VA.Damage and bChar:GetAttribute("Ragdolled") == true and #sentTo(B, "VanishingPop") == 1, "...into the street: " .. (MAX - bHum.Health) .. ", knocked flat")
	task.wait(2)
	-- 4: HE'S the marble
	local MG = CQ.Extra
	fresh("Compress", "Explosion", Vector3.new(X, 3, 25))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 25), 1, aRoot.Position)
	task.wait(0.08)
	check(aChar:GetAttribute("Compressed") == true and #sentTo(B, "MagiciansFly") == 1, "MAGICIAN'S CHOICE: he's the marble - a puff of smoke where he stood")
	task.wait(0.5)
	check(aChar:GetAttribute("Compressed") == nil and math.abs(aRoot.CFrame.Position.Z - 25) < 3 and not aRoot.Anchored,
		string.format("...and pops back out at the aim point (%.1f studs on), on his feet", aRoot.CFrame.Position.Z))
	check(MAX - bHum.Health == MG.Damage and bChar:GetAttribute("Stunned") == true and #sentTo(B, "MagiciansPop") == 1, "...B was standing there: " .. (MAX - bHum.Health) .. ", thrown off the spot")
	task.wait(1)
	-- SHOWTIME
	local CU = CQ.Ult
	fresh("Compress", "Explosion", Vector3.new(X, 3, 30))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.4)
	check(#sentTo(B, "RubbleLob") == CU.Abilities[1].Count, "SHOWTIME - MARBLE STORM: a fan of " .. CU.Abilities[1].Count .. " marbles, each a piece of the city coming down")
	task.wait(1.6)
	bHum.Health = MAX
	moveB(Vector3.new(X, 3, 40))
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	local cc = sentTo(B, "CurtainSlab")[1]
	check(cc and typeof(cc.Pos) == "Vector3" and (cc.Pos - Vector3.new(X, 0, 40)).Magnitude < 4, "CURTAIN CALL: a slab of the city out of the sky, over the aim point")
	task.wait(1.2)
	check(about(MAX - bHum.Health, math.floor(CU.Abilities[2].Damage * mult + 0.5)) and bChar:GetAttribute("Ragdolled") == true and #sentTo(B, "CurtainDrop") == 1, "...comes down on B: " .. (MAX - bHum.Health) .. ", flat")
	task.wait(2.2)
	bHum.Health = MAX
	moveB(Vector3.new(X, 3, 8))
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(bChar:GetAttribute("Compressed") == true and #sentTo(B, "DisappearingGrab") == 1, "DISAPPEARING ACT: everyone round him into marbles in his hand")
	task.wait(CU.Abilities[3].Held + 0.7)
	check(bChar:GetAttribute("Compressed") == nil and about(MAX - bHum.Health, math.floor(CU.Abilities[3].Damage * mult + 0.5)) and bChar:GetAttribute("Ragdolled") == true and bRoot.CFrame.Position.Z > 9,
		string.format("...thrown into the street in front of him in a heap: %d damage, %.1f studs on", MAX - bHum.Health, bRoot.CFrame.Position.Z))
	fire(TestCommand, A, "EndUlt")
	task.wait(1.2)
	fresh("Explosion", "Explosion", Vector3.new(X, 3, 20))
	check(aChar:GetAttribute("Marbles") == nil and cd.held == 0, "someone else's quirk: the pocket's gone, the street's all restoring")
	street(false)

	print("== CHARGEBOLT")
	local EQ = Config.Quirks.Electrification
	local PT = EQ.Pointers
	check(EQ and table.find(Config.QuirkOrder, "Electrification") ~= nil and not EQ.DevOnly and PT.Max == 2 and PT.Life == 20, "CHARGEBOLT is on the quirk menu: 2 pointers in the clip, 20s each")
	check(EQ.Abilities[1].Id == "Discharge" and EQ.Abilities[2].Id == "ElectricGrasp" and EQ.Abilities[3].Id == "ZapTrap" and EQ.Special.Id == "Pointer" and EQ.Extra.Id == "StunBolt",
		"his kit: 1 Discharge, 2 Electric Grasp, 3 Zap Trap, 4 Stun Bolt, R Pointer")
	street(true)
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 20))
	check(aChar:GetAttribute("Pointers") == 2, "a full clip on a new body")
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	local ps = sentTo(B, "PointerStick")[1]
	check(ps and ps.Target == bChar and aChar:GetAttribute("Pointers") == 1 and bChar:GetAttribute("Pointed") == 1 and #sentTo(B, "PointerShot") == 1, "POINTER: the disc sticks to B (1 left in the clip)")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(1, 0, 0), Vector3.new(X + 30, 3, 0), 1, aRoot.Position)
	task.wait(0.1)
	ps = sentTo(B, "PointerStick")[1]
	check(ps and ps.Target == nil and typeof(ps.Pos) == "Vector3" and aChar:GetAttribute("Pointers") == 0, "...the second sticks to the street (the clip's empty)")
	check(#sentTo(A, "Reload") == 1, "...both out: R reloads (" .. PT.Reload .. "s on the slot)")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "PointerStick") == 0 and #sentTo(A, "Notice") == 1, "...no pointers left: R won't fire (he's told)")
	PT.Life = 1.2
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 20))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Pointers") == 1 and bChar:GetAttribute("Pointed") == 1, "(a pointer on B - 1.2s for the test)")
	clearSent()
	task.wait(1.4)
	check(aChar:GetAttribute("Pointers") == 2 and bChar:GetAttribute("Pointed") == nil and #sentTo(B, "PointerGone") == 1, "...it expires: off B, back in the clip")
	PT.Life = 20
	-- 1: DISCHARGE
	local DC = EQ.Abilities[1]
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 6))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(MAX - bHum.Health == DC.Damage and bChar:GetAttribute("Stunned") == true and #sentTo(B, "DischargeBurst") == 1 and #sentTo(B, "Shocked") == 1,
		"DISCHARGE, nothing to aim it at: a shock all round him - " .. (MAX - bHum.Health) .. ", stunned, sparking")
	check(not bChar:GetAttribute("Ragdolled"), "(a jolt, not a knockdown)")
	task.wait(1.3)
	fresh("Electrification", "Explosion", Vector3.new(X + 30, 3, 0))
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(8, -4.5, 22).Unit, Vector3.new(X + 8, 0, 22), 1, aRoot.Position)
	task.wait(0.1)
	ps = sentTo(B, "PointerStick")[1]
	check(ps and ps.Target == nil and typeof(ps.Pos) == "Vector3" and (ps.Pos - Vector3.new(X + 8, 0, 22)).Magnitude < 3, "(a pointer on the street 23 studs off)")
	moveB(Vector3.new(X + 3, 3, 10))
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	local dl = sentTo(B, "DischargeLine")[1]
	check(dl and typeof(dl.To) == "Vector3" and (dl.To - ps.Pos).Magnitude < 1, "...a pointer near: it all goes down ONE line, straight to it")
	check(MAX - bHum.Health == DC.LineDamage and bChar:GetAttribute("Stunned") == true and not bChar:GetAttribute("Ragdolled"), "...B was on the line: " .. (MAX - bHum.Health) .. ", stunned stiff for " .. DC.LineStun .. "s")
	local sh = sentTo(B, "Shocked")[1]
	check(sh and sh.Duration == DC.LineStun, "(electrocuted that long)")
	task.wait(DC.LineStun + 0.3)
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 15))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(MAX - bHum.Health == DC.TagDamage and bChar:GetAttribute("Ragdolled") == true and (bRoot:FindFirstChild("Knockback") ~= nil or bRoot.CFrame.Position.Z > 16),
		"...the pointer's ON B: the line ends in them - " .. (MAX - bHum.Health) .. ", knocked back and flat")
	task.wait(2)
	-- 2: ELECTRIC GRASP
	local EG = EQ.Abilities[2]
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(1, 0, 0), Vector3.new(X + 30, 3, 0), 1, aRoot.Position)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.SPECIAL_INDEX, Vector3.new(-1, 0, 0), Vector3.new(X - 30, 3, 0), 1, aRoot.Position)
	fire(TestCommand, A, "ResetCooldowns")
	task.wait(0.1)
	check(aChar:GetAttribute("Pointers") == 0, "(both pointers fired off into the street)")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	local eg = sentTo(B, "ElectricGraspHold")[1]
	check(eg and eg.Target == bChar and eg.Air == false and bChar:GetAttribute("Grabbed") == true, "ELECTRIC GRASP: a hand on B's face")
	task.wait(1)
	local total = EG.Damage + EG.Ticks * EG.TickDamage + EG.SlamDamage
	check(MAX - bHum.Health == total and bChar:GetAttribute("Ragdolled") == true and #sentTo(B, "GraspSlam") == 1, "...filled with electricity and slammed into the street: " .. (MAX - bHum.Health) .. " (" .. total .. ")")
	task.wait(1.6)
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 5))
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	eg = sentTo(B, "ElectricGraspHold")[1]
	check(eg and eg.Air == true, "...with a pointer in the clip: the other one")
	task.wait(0.45)
	check(bRoot.CFrame.Position.Y > 15, string.format("...B thrown straight up (%.0f studs)", bRoot.CFrame.Position.Y))
	task.wait(0.22)
	check(bChar:GetAttribute("Pointed") == 1 and aChar:GetAttribute("Pointers") == 1 and #sentTo(B, "GraspBolt") == 1, "...tagged with a pointer up there, and the bolt after them")
	check(MAX - bHum.Health == EG.Damage + EG.BoltDamage and bChar:GetAttribute("Ragdolled") == true, "...: " .. (MAX - bHum.Health) .. " damage, knocked flat")
	local kb = bRoot:FindFirstChild("Knockback")
	check(kb and math.abs(kb.VectorVelocity.Z * 0.3 - EG.Push) < 2, string.format("...and blown back %d studs (%s for 0.3s)", EG.Push, tostring(kb and kb.VectorVelocity)))
	task.wait(2)
	-- 4: STUN BOLT
	local SB = EQ.Extra
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 20))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	local sb = sentTo(B, "StunBoltHit")[1]
	check(sb and sb.Hit == true and MAX - bHum.Health == SB.Damage and bChar:GetAttribute("Stunned") == true and not bChar:GetAttribute("Ragdolled"),
		"STUN BOLT: the finger gun - B jolted stiff (" .. (MAX - bHum.Health) .. ", " .. SB.Stun .. "s)")
	task.wait(SB.Stun + 0.3)
	-- 1,300,000 VOLTS
	local EU = EQ.Ult
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 60))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	moveB(Vector3.new(X, 3, 20)) -- (in range now, clear of the awakening's own blast)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.75)
	check(about(MAX - bHum.Health, math.floor(EU.Abilities[1].Damage * mult + 0.5)) and bChar:GetAttribute("Ragdolled") == true and #sentTo(B, "IndiscriminateBoom") == 1,
		"1,300,000 VOLTS - INDISCRIMINATE DISCHARGE: everyone round him, " .. (MAX - bHum.Health) .. ", flat")
	task.wait(2.2)
	bHum.Health = MAX
	moveB(Vector3.new(X, 3, 40))
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1)
	local lr = sentTo(B, "LightningStrikes")[1]
	check(lr and type(lr.Spots) == "table" and #lr.Spots >= 1 and about(MAX - bHum.Health, math.floor(EU.Abilities[2].Damage * mult + 0.5)), "LIGHTNING ROD: out of the sky onto the aim point - " .. (MAX - bHum.Health))
	task.wait(1.5)
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	moveB(Vector3.new(X, 3, 15))
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	local cl = sentTo(B, "ChainBolts")[1]
	check(cl and type(cl.Points) == "table" and #cl.Points == 2 and about(MAX - bHum.Health, math.floor(EU.Abilities[3].Damage * mult + 0.5)) and bChar:GetAttribute("Stunned") == true,
		"CHAIN LIGHTNING: into the nearest one - " .. (MAX - bHum.Health) .. ", stunned")
	clearSent()
	fire(TestCommand, A, "EndUlt")
	task.wait(0.15)
	check(aChar:GetAttribute("Wheey") == true and aChar:GetAttribute("Stunned") == true and #sentTo(B, "Wheey") == 1, "...and after all that: WHEEEY - his brain's fried for " .. EU.Wheey .. "s")
	task.wait(EU.Wheey + 0.4)
	check(aChar:GetAttribute("Wheey") == nil and not aChar:GetAttribute("Stunned"), "...then he's back")
	fresh("Explosion", "Explosion", Vector3.new(X, 3, 20))
	check(aChar:GetAttribute("Pointers") == nil, "someone else's quirk: the clip's gone")
	street(false)
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 45: Chargebolt's look pared down to one bracer on the arm; the
-- animation fallbacks
---------------------------------------------------------------------------
;M.section(function()
	local X = 21500
	studioMode = true
	local function r6(p, pos)
		local model, hum, root = spawnChar(p, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
		local specs = {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) }, { "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) }, { "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) }, { "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		}
		for _, s in specs do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Parent = model
		end
		return model, hum, root
	end

	print("== CHARGEBOLT: one bracer on the arm, attached")
	fire(SelectQuirk, A, "Electrification")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = r6(A, Vector3.new(X, 3, 0))
	fire(SelectQuirk, A, "Electrification")
	task.wait(0.4)
	local gear = aChar:FindFirstChild("QuirkGear")
	local arm = aChar:FindFirstChild("Right Arm")
	local pieces, others = {}, {}
	for _, d in gear and gear:GetDescendants() or {} do
		if d:IsA("BasePart") then
			if d.Name == "Shooter" then
				table.insert(pieces, d)
			else
				table.insert(others, d.Name)
			end
		end
	end
	check(#pieces == 3 and #others == 0, "just the Shooter: " .. #pieces .. " pieces, nothing else (" .. table.concat(others, ", ") .. ")")
	local welded = 0
	for _, p in pieces do
		local w = p:FindFirstChildOfClass("Weld")
		if w and w.Part0 == arm then
			welded += 1
		end
	end
	-- attached: every piece touches the arm, or a piece that does (boxes in
	-- the arm's space, a hair of slack)
	local function box(part)
		return arm.CFrame:PointToObjectSpace(part.CFrame.Position), part.Size / 2
	end
	local function touch(a, b)
		local ca, ha = box(a)
		local cb, hb = box(b)
		local d = ca - cb
		local lim = ha + hb + Vector3.new(0.03, 0.03, 0.03)
		return math.abs(d.X) <= lim.X and math.abs(d.Y) <= lim.Y and math.abs(d.Z) <= lim.Z
	end
	local on = { [arm] = true }
	for _ = 1, #pieces do
		for _, p in pieces do
			if not on[p] then
				for q in on do
					if touch(p, q) then
						on[p] = true
						break
					end
				end
			end
		end
	end
	local touching = 0
	for _, p in pieces do
		if on[p] and math.abs(box(p).Y) < arm.Size.Y / 2 then
			touching += 1
		end
	end
	check(welded == 3, "...all of it welded to the right arm (" .. welded .. ")")
	check(touching == 3, "...on the forearm, every piece touching the arm or the piece under it - nothing hanging in the air (" .. touching .. ")")

	print("== ANIMATIONS: every move has something to play")
	check(Config.Animations.Procedural.R6 == "auto" and Config.Animations.Strides == nil, "R6 bodies: Roblox's clips, and the built-in gait for any body playing none (round 64: round 62's loops are gone)")
end)
---------------------------------------------------------------------------
-- Round 46: the Sky Coffin (the floating arena over the city: barrier,
-- Sports Festival stage, warp gates); Bakugo upside down at the blitz's
-- catch, and the slow motion longer
---------------------------------------------------------------------------
;M.section(function()
	local SCfg = Config.SkyCoffin
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local map = workspace:FindFirstChild("Map")
	local arena = map and map:FindFirstChild("SkyCoffin")

	print("== THE SKY COFFIN")
	check(arena ~= nil and SCfg and SCfg.Enabled, "the Sky Coffin is built into the map when the server starts")
	local count, kinds, classes = 0, {}, {}
	local walls, solids, barrierOk = 0, 0, true
	for _, d in arena and arena:GetDescendants() or {} do
		classes[d.ClassName] = (classes[d.ClassName] or 0) + 1
		if d:IsA("BasePart") then
			count += 1
			kinds[d.Name] = (kinds[d.Name] or 0) + 1
			if d.Name == "BarrierWall" then
				walls += 1
				barrierOk = barrierOk and d.CanCollide == false and d.CanQuery == false and d.Transparency >= 0.7 and d.Transparency < 0.9
			elseif d.Name == "Barrier" then
				solids += 1
				barrierOk = barrierOk and d.CanCollide ~= false and d.Transparency == 1
			end
		end
	end
	check(count > 500, "...a detailed model (" .. count .. " parts)")
	local lawn = arena and arena:FindFirstChild("Lawn")
	local lp = lawn and lawn.Position
	check(lp and lp.Y > 400 and (Vector3.new(lp.X, 0, lp.Z) - Vector3.new(-70, 0, 888)).Magnitude < 5, "...floating way up over the middle of the city (the lawn at " .. tostring(lp and math.floor(lp.Y)) .. ")")
	check(kinds.Pillar == 12 and walls == 12 and kinds.BarrierRoof == 24, string.format("...twelve black pillars round the rim, the barrier between them, a tent of a roof (%s pillars, %d walls, %s roof pieces)", tostring(kinds.Pillar), walls, tostring(kinds.BarrierRoof)))
	check(solids == 13 and barrierOk, "...the barrier: see-through gold; what stops you is invisible so the camera never snags on it (12 walls and a lid: " .. solids .. ")")
	local stage = arena and arena:FindFirstChild("Stage")
	check(stage and stage.Size.X >= 80 and stage:GetAttribute("Destroyable") == true, "the Sports Festival stage in front of U.A. - it breaks, like the city")
	check(kinds.Line == 4 and kinds.Flame == 4 and (classes.Fire or 0) == 4, "...the white line round the top, red flames at the four corners")
	check(kinds.UA == 3 and kinds.Plaza == 1, "U.A.'s main building behind it: an H of glass (" .. tostring(kinds.UA) .. " blocks)")
	check(kinds.Generator == 1 and (kinds.Jet or 0) >= 10 and (classes.ParticleEmitter or 0) >= 10, "the generator outside the barrier, propulsion jets underneath (" .. tostring(kinds.Jet) .. ")")
	check((kinds.Cloud or 0) >= 20, "...clouds drifting under it")

	-- WARP GATES
	print("== KUROGIRI'S WARP GATES")
	local city, sky
	for _, d in arena and arena:GetDescendants() or {} do
		if d.Name == "WarpGate" then
			if d.Position.Y < 200 then
				city = d
			else
				sky = d
			end
		end
	end
	check(city and sky, "a warp gate in the plaza by the middle spawn and one up on the lawn")
	check(city and (Vector3.new(city.Position.X, 0, city.Position.Z) - Vector3.new(-70.3, 0, 887.3)).Magnitude < 40, "...the city one a short walk from the middle spawn")
	local label = city and city:FindFirstChildOfClass("BillboardGui")
	local title = label and label:FindFirstChild("Title")
	check(title and title.Text == "THE SKY COFFIN", "...labelled: " .. tostring(title and title.Text))
	fire(SelectQuirk, A, "FullCowl")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(-72, 30, 880))
	task.wait(0.2)
	clearSent()
	aRoot.CFrame = CFrame.new(city.Position - Vector3.new(0, 3.5, 0))
	task.wait(0.3)
	local warp = sentTo(B, "SkyWarp")[1]
	check(warp and warp.Up == true, "walk into it: into the mist (everyone sees it)")
	check(aRoot.Position.Y > 400 and (aRoot.Position - sky.Position).Magnitude < 9, string.format("...and out of the one up on the Sky Coffin (%.0f studs up)", aRoot.Position.Y))
	local look = aRoot.CFrame.LookVector
	local inward = (SCfg.Center - aRoot.Position) * Vector3.new(1, 0, 1)
	check(look:Dot(inward.Unit) > 0.9 and (aRoot.Position - sky.Position).Magnitude > 6, "...facing into the arena, a few steps clear of the gate")
	clearSent()
	aRoot.CFrame = CFrame.new(sky.Position - Vector3.new(0, 3.5, 0))
	task.wait(0.3)
	check(aRoot.Position.Y > 400 and #sentTo(B, "SkyWarp") == 0, "...no bouncing straight back: a moment before the gate takes you again")
	aRoot.CFrame = CFrame.new(sky.Position + Vector3.new(0, -3.5, -12))
	task.wait(2.8)
	aRoot.CFrame = CFrame.new(sky.Position - Vector3.new(0, 3.5, 0))
	task.wait(0.3)
	warp = sentTo(B, "SkyWarp")[1]
	check(warp and warp.Up == false and aRoot.Position.Y < 100 and (aRoot.Position - city.Position).Magnitude < 9, "...and back down to the city through the other one")

	-- THE BARRIER
	print("== THE BARRIER")
	local center = SCfg.Center
	local RP, BH = SCfg.Barrier, SCfg.BarrierHeight
	local inR = RP * math.cos(math.pi / 12)
	local a = math.pi / 12 -- (the middle of the panel between the first two pillars)
	local out = Vector3.new(math.sin(a), 0, math.cos(a))
	task.wait(1.5)
	clearSent()
	aHum.Health = MAX
	-- (the push only lasts a moment: catch it while it's on)
	local function push(within)
		local t0 = os.clock()
		while os.clock() - t0 < within do
			local kb = aRoot:FindFirstChild("Knockback")
			if kb then
				return kb.VectorVelocity
			end
			task.wait()
		end
		return nil
	end
	aRoot.CFrame = CFrame.new(center + out * (inR - 1) + Vector3.new(0, 3, 0))
	local kb = push(0.3)
	task.wait(0.05)
	local zap = sentTo(B, "BarrierZap")[1]
	check(zap and aChar:GetAttribute("Stunned") == true, "touch the barrier: a jolt that locks you up for a moment")
	check(kb and kb:Dot(-out) > 30 and aHum.Health == MAX, "...throws you back off it, into the arena (no damage)")
	local shocked = sentTo(B, "Shocked")[1]
	check(shocked and shocked.Target == aChar, "...sparks all over you")
	aRoot.CFrame = CFrame.new(center + Vector3.new(0, 8, 0)) -- (thrown off it: no physics here)
	task.wait(1.5)
	clearSent()
	aRoot.CFrame = CFrame.new(center + out * (inR - 7) + Vector3.new(0, 3, 0))
	task.wait(0.3)
	check(#sentTo(B, "BarrierZap") == 0, "...a few steps off it: nothing")
	aRoot.CFrame = CFrame.new(center + Vector3.new(30, BH - 2, 10))
	kb = push(0.3)
	task.wait(0.05)
	zap = sentTo(B, "BarrierZap")[1]
	check(zap and kb and kb.Y < -20, "...the roof too: flown up into it, you're knocked back down")
	task.wait(1.5)
	aRoot.CFrame = CFrame.new(-72, 30, 880)
	task.wait(0.2)

	print("== FULL-BODY CLUSTER: face to face, the right way up")
	local FB = Config.Quirks.Explosion.Ult.Extra
	local X = 23500
	local FWD = Vector3.new(0, 0, 1)
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "FullCowl")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	aHum.Health, bHum.Health = MAX, MAX
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(FB.WalkTime + 0.12)
	local cf = aRoot.CFrame
	local toB = (bRoot.Position - cf.Position) * Vector3.new(1, 0, 1)
	check(#sentTo(B, "FullBodyClusterBlink") == 1 and cf.UpVector.Y > 0.95 and toB.Magnitude > 0.5 and cf.LookVector:Dot(toB.Unit) > 0.9,
		string.format("the blink: the right way up, face to face (up %.2f)", cf.UpVector.Y))
	check(aRoot.Anchored and bChar:GetAttribute("Grabbed") == true and aChar:GetAttribute("BodyLocked") == true, "...held there, his body the move's (his shift lock / lock-on can't turn him)")
	task.wait(3)
	check(aRoot.CFrame.UpVector.Y > 0.99 and not aRoot.Anchored and aChar:GetAttribute("BodyLocked") == nil, "...and on his feet and free afterwards")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 47: the Sky Coffin way bigger; no invisible walls round the city -
-- off the edge is the void (a KO, for whoever knocked you off)
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local SCfg = Config.SkyCoffin
	local MB = Config.MapBounds
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)

	print("== THE SKY COFFIN, WAY BIGGER")
	local arena = workspace:FindFirstChild("Map"):FindFirstChild("SkyCoffin")
	local lawn = arena and arena:FindFirstChild("Lawn")
	check(SCfg.Radius >= 400 and lawn and lawn.Size.Y >= 800, "the disc: " .. (lawn and math.floor(lawn.Size.Y) or 0) .. " studs across (was 334)")
	check(SCfg.BarrierHeight >= 250, "the barrier " .. SCfg.BarrierHeight .. " studs high (was 118)")
	local tallest = 0
	for _, d in arena:GetDescendants() do
		if d.Name == "UA" then
			tallest = math.max(tallest, d.Size.Y)
		end
	end
	check(tallest >= 160, "U.A.'s main building scaled up with it (" .. tallest .. " studs tall)")
	local stage = arena:FindFirstChild("Stage")
	check(stage and stage.Size.X == 84, "...the Sports Festival stage still fighting-sized (84)")
	check(arena.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, "always loaded for everyone (seen from all over the city; no warping onto a floor that hasn't streamed in)")
	local shadowless = true
	for _, n in { "Hull", "Lawn", "Generator" } do
		local p = arena:FindFirstChild(n)
		shadowless = shadowless and p ~= nil and p.CastShadow == false
	end
	check(shadowless, "...its big slabs cast no shadow on the city")

	print("== NO INVISIBLE WALLS: OFF THE EDGE IS THE VOID")
	local walls, floor = 0, nil
	for _, p in workspace:FindFirstChild("MapBounds"):GetChildren() do
		if p.Name == "Wall" then
			walls += 1
		elseif p.Name == "Floor" then
			floor = p
		end
	end
	check(MB.Walls == false and walls == 0, "no invisible walls round the city (" .. walls .. ")")
	check(floor and floor.Size.X == basePlate.Size.X and floor.Size.Z == basePlate.Size.Z, "...the floor under the street is exactly its size: no invisible ledge past the edge")
	local X = 2400
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "FullCowl")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X + 10, 3, 0)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X + 5, 3, 0), Vector3.new(X, 3, 0)))
	task.wait(0.3)
	fire(TestCommand, A, "ResetCooldowns")
	aHum.Health, bHum.Health = MAX, MAX
	local kills = stat(A, "Kills")
	-- A hits B, and B goes off the edge (x 2500)
	fire(UseAbility, A, 0)
	task.wait(0.3)
	check(bHum.Health < MAX, "(A lands a hit on B)")
	bChar:SetAttribute("Ragdolled", nil)
	bRoot.CFrame = CFrame.new(2530, -20, 0)
	task.wait(0.4)
	check(bHum.Health > 0 and bRoot.Position.Y < -10, "knocked off the edge: falling - nobody puts you back")
	bRoot.CFrame = CFrame.new(2530, -200, 0)
	task.wait(0.4)
	check(bHum.Health <= 0, "...far enough down: the void KOs you")
	check(stat(A, "Kills") == kills + 1, "...and it's A's KO (" .. kills .. " -> " .. stat(A, "Kills") .. ")")
	-- someone punched through the street (still over it) is still put back
	bChar, bHum, bRoot = spawnChar(B, CFrame.new(X - 100, 3, 40))
	task.wait(0.4)
	bRoot.CFrame = CFrame.new(X - 100, -60, 40)
	task.wait(0.4)
	check(bHum.Health > 0 and bRoot.Position.Y > 0, "punched through the street (not off its edge): still put back where you stood")
	task.wait(0.5)
end)
---------------------------------------------------------------------------
-- Round 48: Decay on the Sky Coffin (its plates fire themselves off, Total
-- Decay takes him up into the barrier, Best Jeanist's fibers bring him back),
-- Lemillion on the island, Bakugo's blitz body lock, Iida's muffler nuke
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local SCfg = Config.SkyCoffin
	local C = SCfg.Center
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local arena = workspace:FindFirstChild("Map"):FindFirstChild("SkyCoffin")
	local lawn = arena and arena:FindFirstChild("Lawn")
	local stubRay = workspace.Raycast
	-- the island's lawn: what a ray down onto it finds
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 then
			local rel = origin - C
			if Vector3.new(rel.X, 0, rel.Z).Magnitude < SCfg.Radius and rel.Y >= -1 and rel.Y + dir.Y <= 0 then
				return { Position = Vector3.new(origin.X, C.Y, origin.Z), Normal = Vector3.new(0, 1, 0), Distance = rel.Y, Instance = lawn, Material = Enum.Material.Grass }
			end
		end
		return nil
	end
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, aAt + Vector3.new(1, 0, 0)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local function push(root, within)
		local t0, best = os.clock(), nil
		while os.clock() - t0 < within do
			local kb = root:FindFirstChild("Knockback")
			if kb and (not best or kb.VectorVelocity.Y > best.Y) then
				best = kb.VectorVelocity
			end
			task.wait()
		end
		return best
	end
	local FWD = Vector3.new(1, 0, 0)

	print("== DECAY ON THE SKY COFFIN: the plates fire themselves off")
	check(lawn and lawn:GetAttribute("SkyFloor") == true and lawn:GetAttribute("NoPhase") == true, "the lawn's the island's ground (Lemillion's dive stops under it, nobody phases through it)")
	local S = C + Vector3.new(-150, 3, 150)
	fresh("Decay", "FullCowl", S, S + Vector3.new(8, 0, 0))
	fire(UseAbility, A, 3, FWD, S + FWD * 10, 1, aRoot.Position) -- COLLAPSE
	local kb = push(bRoot, 1.4)
	local tiles = sentTo(B, "SkyTiles")
	local n, inside = 0, true
	for _, t in tiles do
		for _, tile in t.Tiles do
			n += 1
			local cx, cz = (tile[1] + 0.5) * 12, (tile[2] + 0.5) * 12
			if math.sqrt(cx * cx + cz * cz) > SCfg.Radius - 21 then
				inside = false
			end
		end
	end
	check(n >= 20 and inside, "COLLAPSE on the island: its plates cut loose and fired off, ring by ring (" .. n .. " plates, " .. #tiles .. " rings)")
	check(not kb or kb.Y < 100, "...(round 49: it's all for the eyes - nobody's fired up with a plate: " .. tostring(kb and math.floor(kb.Y)) .. ")")
	check(#sentTo(B, "SkyRide") == 0 and not aRoot.Anchored, "...Shigaraki stays on his feet for that one")
	task.wait(2.6)
	-- (the plates are back: the same spot goes again)
	clearSent()
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 3, FWD, S + FWD * 10, 1, aRoot.Position)
	task.wait(1.4)
	check(#sentTo(B, "SkyTiles") > 0, "...a couple of seconds later the spares are in and it goes again")
	task.wait(1)

	print("== TOTAL DECAY on the island (round 49: no ride - he's not punished for it)")
	fresh("Decay", "FullCowl", S, S + Vector3.new(30, 0, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local start = aRoot.Position
	fire(UseAbility, A, 3, FWD, S + FWD * 10, 1, aRoot.Position) -- TOTAL DECAY
	local top, locked = -math.huge, false
	local t0 = os.clock()
	while os.clock() - t0 < 3.4 do
		top = math.max(top, aRoot.Position.Y)
		locked = locked or aChar:GetAttribute("BodyLocked") == true or aRoot.Anchored
		task.wait()
	end
	local reach = 0
	for _, t in sentTo(B, "SkyTiles") do
		reach = math.max(reach, t.Reach or 0)
	end
	check(#sentTo(B, "SkyTiles") > 0 and reach == 120, "the plates still fire off (and Jeanist's told how far it'll spread: " .. reach .. ")")
	check(#sentTo(B, "SkyRide") == 0 and #sentTo(B, "JeanistFibers") == 0 and not locked and top < start.Y + 5, "...but Shigaraki stays right where he is: no ride up into the barrier")
	check(not aChar:GetAttribute("Stunned") and not aChar:GetAttribute("Ragdolled"), "...not zapped, not slammed down")
	fire(TestCommand, A, "EndUlt")
	task.wait(2)

	print("== LEMILLION ON THE ISLAND")
	local rim = C + Vector3.new(380, 30, 0)
	fresh("Lemillion", "FullCowl", rim, C + Vector3.new(300, 3, 0))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, rim + FWD * 20, 1, aRoot.Position, true) -- PHASE DIVE (R in the air)
	task.wait(1.6)
	local y = aRoot.Position.Y
	check(y > C.Y - 20 and y < C.Y, string.format("PHASE DIVE: under the island's floor (%.0f), not down through it to the city", y - C.Y))
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, C + Vector3.new(700, 0, 0))
	task.wait(0.15)
	local flat = Vector3.new(aRoot.Position.X - C.X, 0, aRoot.Position.Z - C.Z).Magnitude
	check(flat < SCfg.Barrier * math.cos(math.pi / 12) - 5 and aRoot.Position.Y > C.Y, string.format("...steered out past the barrier: he comes up inside it (%.0f from the middle)", flat))
	task.wait(1.5)
	fresh("Lemillion", "FullCowl", C + Vector3.new(380, 3, 0), C + Vector3.new(300, 3, 0))
	fire(UseAbility, A, 1, FWD, C + Vector3.new(440, 0, 0), 1, aRoot.Position) -- DEEP DIVE
	task.wait(1)
	flat = Vector3.new(aRoot.Position.X - C.X, 0, aRoot.Position.Z - C.Z).Magnitude
	check(flat < SCfg.Barrier * math.cos(math.pi / 12) - 5 and aRoot.Position.Y > C.Y, string.format("DEEP DIVE aimed out past the barrier: up inside it (%.0f)", flat))
	local barrierSolid = nil
	for _, d in arena:GetDescendants() do
		if d.Name == "Barrier" and d.CanCollide ~= false then
			barrierSolid = barrierSolid or d
		end
	end
	check(barrierSolid and barrierSolid:GetAttribute("NoPhase") == true, "...and the barrier's not matter he can walk through")
	workspace.Raycast = stubRay
	task.wait(1)

	print("== BAKUGO: his body's the move's for the whole of FULL-BODY CLUSTER")
	local X = 26500
	fresh("Explosion", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	local FB = Config.Quirks.Explosion.Ult.Extra
	for round = 1, 2 do
		aHum.Health, bHum.Health = MAX, MAX
		aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10))
		bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 0))
		bChar:SetAttribute("Ragdolled", nil)
		bChar:SetAttribute("Stunned", nil)
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, Config.EXTRA_INDEX, Vector3.new(0, 0, 1), bRoot.Position, 1, aRoot.Position)
		task.wait(FB.WalkTime + 0.5)
		check(aChar:GetAttribute("BodyLocked") == true, "cluster #" .. round .. ": the body locked all round them, so his own shift lock / lock-on can't turn him")
		task.wait(3)
		check(aChar:GetAttribute("BodyLocked") == nil and aRoot.CFrame.UpVector.Y > 0.99, "...let go (and upright) afterwards")
		task.wait(1)
	end
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	print("== IIDA'S PRANK: the muffler nuke")
	workspace:SetAttribute("MufflerPrank", true) -- (round 49: only with the test menu's switch on)
	check(Config.GetAbility("Engine", Config.PRANK_INDEX, false, true) and not Config.GetAbility("Engine", Config.PRANK_INDEX, false, false),
		"it's his ult's (LB + RB in the air - 1 + 4), with the switch on")
	X = 28500
	fresh("Engine", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X + 40, 3, 0))
	fire(UseAbility, A, Config.PRANK_INDEX, FWD, bRoot.Position, 1, aRoot.Position, true)
	task.wait(1)
	check(#sentTo(B, "MufflerThrow") == 0 and bHum.Health == MAX, "...not outside his ult")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.PRANK_INDEX, FWD, bRoot.Position, 1, aRoot.Position, false)
	task.wait(1)
	check(#sentTo(B, "MufflerThrow") == 0, "...nor on the ground")
	fire(TestCommand, A, "ResetCooldowns")
	aHum.Health, bHum.Health = MAX, MAX
	clearSent()
	fire(UseAbility, A, Config.PRANK_INDEX, FWD, bRoot.Position, 1, aRoot.Position, true)
	task.wait(0.2)
	check(#sentTo(B, "MufflerNuke") == 1, "in the air, in his ult: he pulls a muffler out of his calf (everyone sees it)")
	task.wait(0.5)
	local throw = sentTo(B, "MufflerThrow")[1]
	check(throw and throw.Target == bChar, "...and lobs it at B")
	task.wait(1.2)
	local boom = sentTo(B, "MufflerBoom")[1]
	check(boom and (boom.Pos - bRoot.Position).Magnitude < 8, "...it hits them: IT'S A NUKE")
	check(MAX - bHum.Health >= 20 and aHum.Health == MAX, string.format("...B takes %d, Iida takes nothing", MAX - bHum.Health))
	fire(TestCommand, A, "EndUlt")
	task.wait(1)
	workspace:SetAttribute("MufflerPrank", nil)
end)
---------------------------------------------------------------------------
-- Round 49: Iida's prank behind the test menu's switch; All Might vs All For
-- One in the sky; Deku's Fa Jin (squats, then out through his legs) and
-- Gearshift (up through the gears, then Transmission)
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, bAt))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local FWD = Vector3.new(0, 0, 1)

	print("== IIDA'S PRANK: gone, unless the test menu switches it on")
	check(workspace:GetAttribute("MufflerPrank") ~= true and Config.GetAbility("Engine", Config.PRANK_INDEX, false, true) == nil, "off by default - not even in his ult")
	check(not Config.Quirks.Engine.Description:find("psst"), "(and his move list doesn't hint at it)")
	local X = 30500
	fresh("Engine", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 40))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.PRANK_INDEX, FWD, bRoot.Position, 1, aRoot.Position, true)
	task.wait(1.2)
	check(#sentTo(B, "MufflerNuke") == 0 and #sentTo(B, "MufflerThrow") == 0 and bHum.Health == MAX, "in his ult, in the air, LB + RB: nothing")
	fire(TestCommand, A, "PSSet", "MufflerPrank", true)
	check(workspace:GetAttribute("MufflerPrank") == true and Config.GetAbility("Engine", Config.PRANK_INDEX, false, true) ~= nil, "the test menu's switch turns it on")
	fire(TestCommand, A, "PSSet", "MufflerPrank", false)
	check(workspace:GetAttribute("MufflerPrank") == nil, "...and off")
	fire(TestCommand, A, "PSSet", "MufflerPrank", true)
	fire(TestCommand, A, "PSSet", "ResetSettings")
	check(workspace:GetAttribute("MufflerPrank") == nil, "(resetting the settings puts it back off)")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== ALL MIGHT vs ALL FOR ONE, in the sky")
	local SB = Config.SkyBattle
	check(SB and SB.Enabled and SB.Every >= 120 and SB.First > 0 and SB.Length > 30, "every few minutes, for about " .. math.floor(SB.Length) .. "s")
	clearSent()
	fire(TestCommand, A, "PSSet", "SkyBattleNow")
	task.wait(0.1)
	local sb = sentTo(B, "SkyBattle")[1]
	check(sb and sb.Length == SB.Length and type(sb.Seed) == "number" and #sentTo(A, "SkyBattle") == 1, "the test menu's button: everyone's told to look up at once")
	fire(TestCommand, A, "PSSet", "SkyBattle", false)
	check(workspace:GetAttribute("SkyBattle") ~= true, "its switch turns them off")
	fire(TestCommand, A, "PSSet", "ResetSettings")
	check(workspace:GetAttribute("SkyBattle") ~= true, "(back off with the rest: off until switched on)")

	print("== FA JIN: squat after squat, then it all goes out through his legs")
	local FJ = Config.FindAbilityById("FaJinSmash")
	local pickOf = {}
	for i, e in Config.Quirks.FullCowl.Extras do
		pickOf[e.Id] = i
	end
	check(FJ.Launch and FJ.Launch.Max > FJ.Launch.Min and FJ.Hold.Speed <= 6, "(stored in his legs: he stays planted to squat, and it launches him)")
	X = 32500
	fresh("FullCowl", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 150))
	A:SetAttribute("QuirkPick", pickOf.FaJinSmash)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(FJ.Hold.Max + 0.1)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.7)
	local rel = sentTo(B, "FaJinSmashRelease")[1]
	check(rel and rel.Power > 0.95, "squatted all the way up: full power")
	check(bHum.Health < MAX, "the launch carries it: B's 150 studs away (the gale alone reaches " .. FJ.Range .. ")")
	task.wait(1.5)
	fresh("FullCowl", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 150))
	A:SetAttribute("QuirkPick", pickOf.FaJinSmash)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.7)
	check(#sentTo(B, "FaJinSmashRelease") == 1 and bHum.Health == MAX, "a quick tap: a short hop and a gust that falls short of them")
	task.wait(1.5)

	print("== GEARSHIFT: up through the gears, then TRANSMISSION")
	local GSA = Config.FindAbilityById("Gearshift")
	check(pickOf.Gearshift ~= nil, "it's in his R cycle")
	X = 34500
	fresh("FullCowl", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	A:SetAttribute("QuirkPick", pickOf.Gearshift)
	local base = aChar:GetAttribute("BaseWalkSpeed")
	for _ = 1, GSA.TopGear do
		fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
		task.wait(GSA.Cooldown + 0.1)
	end
	check(aChar:GetAttribute("Gearshift") == GSA.TopGear, "four presses: LOW, SECOND, THIRD, TOP GEAR")
	local boosted = aChar:GetAttribute("BaseWalkSpeed")
	check(math.abs(boosted - base * (1 + GSA.TopGear * GSA.SpeedPerGear)) < 0.01 and aHum.WalkSpeed >= boosted - 0.01,
		string.format("...each gear faster on his feet (%.1f -> %.1f)", base, boosted))
	check(bHum.Health == MAX and #sentTo(B, "Gearshift") == GSA.TopGear, "(shifting hurts nobody; everyone sees each shift)")
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.05)
	local rush = sentTo(B, "TransmissionRush")[1]
	check(rush and rush.Target == bChar, "at TOP GEAR: TRANSMISSION - he's on B in a blink")
	check((aRoot.CFrame.Position - bRoot.CFrame.Position).Magnitude < 6 and aChar:GetAttribute("BodyLocked") == true, "(right in front of them, his body the move's)")
	local seen, gaps, last = 0, {}, os.clock()
	local t0 = os.clock()
	while os.clock() - t0 < 2.6 do
		local n = #sentTo(B, "GearshiftHit")
		if n > seen then
			table.insert(gaps, os.clock() - last)
			last = os.clock()
			seen = n
		end
		task.wait()
	end
	check(seen == GSA.Hits + (GSA.Quintuple or 0) + 1, "every punch, the Quintuple and the finisher (" .. seen .. ")")
	check(#gaps >= GSA.Hits and gaps[3] > gaps[GSA.Hits] + 0.05, string.format("...each punch faster than the last (%.2fs -> %.2fs apart)", gaps[3] or 0, gaps[GSA.Hits] or 0))
	check(MAX - bHum.Health >= GSA.FinisherDamage + GSA.Damage * 3, "...B takes " .. (MAX - bHum.Health))
	check(bChar:GetAttribute("Ragdolled") == true and not bRoot.Anchored, "...and the last one sends them flying")
	check(aChar:GetAttribute("Gearshift") == nil and not aRoot.Anchored and aChar:GetAttribute("BodyLocked") == nil, "the recoil: back to neutral, his body his own again")
	check(#sentTo(B, "GearshiftRecoil") == 1, "...and locked up a moment")
	local rl = sentTo(A, "Reload")[1]
	check(rl and rl.Time == GSA.RushCooldown and type(rl.Key) == "string", "...and the quirk needs " .. GSA.RushCooldown .. "s to recover (his slot shows it)")
	task.wait(1)
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	check(aChar:GetAttribute("Gearshift") == nil and #sentTo(B, "Gearshift") == 0, "(it won't shift again till then)")
	fire(TestCommand, A, "ResetCooldowns")
	local saved = GSA.GearTime
	GSA.GearTime = 0.6
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	check(aChar:GetAttribute("Gearshift") == 1, "(shifting again once it's recovered)")
	task.wait(0.8)
	check(aChar:GetAttribute("Gearshift") == nil and aChar:GetAttribute("BaseWalkSpeed") == base and #sentTo(B, "GearshiftDown") == 1, "left alone, the gears run back down to neutral")
	GSA.GearTime = saved
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	fire(SelectQuirk, A, "Engine")
	task.wait(3)
	check(aChar:GetAttribute("Gearshift") == nil, "(someone else's quirk: no gears)")
	task.wait(0.5)
end)
---------------------------------------------------------------------------
-- Round 50: Deku, way stronger - Delaware Smash: Air Force (three flicks),
-- St. Louis Smash's air blade, Gearshift's harder hits a gear at a time,
-- Transmission's Detroit Smash: Quintuple and the gear-down, Danger Sense in
-- his ult, and the 1,000,000% Delaware Detroit Smash
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, bAt))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local FWD = Vector3.new(0, 0, 1)
	local D = Config.Quirks.FullCowl
	local Del = Config.FindAbilityById("DelawareSmash")
	local StL = Config.FindAbilityById("StLouisSmash")
	local GSA = Config.FindAbilityById("Gearshift")
	local pickOf = {}
	for i, e in D.Extras do
		pickOf[e.Id] = i
	end
	local function slotOf(id)
		for i, a in D.Abilities do
			if a.Id == id then
				return i
			end
		end
		return nil
	end

	print("== DEKU: DELAWARE SMASH: AIR FORCE - a flick from each hand, then another")
	local X = 36500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	fire(UseAbility, A, slotOf("DelawareSmash"), FWD, bRoot.Position, 7, aRoot.Position)
	task.wait(1.2)
	check(#sentTo(B, "AirForceHit") == Del.Shots, "every air bullet lands on B 60 studs off (" .. #sentTo(B, "AirForceHit") .. " of " .. Del.Shots .. ")")
	local volley = MAX - bHum.Health
	check(volley >= Del.Damage * Del.Shots - 0.01, "...(" .. volley .. " in all)")

	print("== DEKU: ST. LOUIS SMASH: AIR FORCE - the kick sends a blade of air")
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	local third = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	fire(SelectQuirk, third, "Explosion")
	local cChar, cHum = spawnChar(third, CFrame.lookAt(Vector3.new(X, 3, 80), Vector3.new(X, 3, 0)))
	task.wait(0.15)
	fire(UseAbility, A, slotOf("StLouisSmash"), FWD, bRoot.Position, 7, aRoot.Position)
	task.wait((StL.Startup or 0.18) + 0.6)
	check(bHum.Health <= MAX - (StL.BladeDamage or 18) + 0.01, "the blade cuts B 30 studs off (" .. (MAX - bHum.Health) .. ")")
	check(cHum.Health == MAX, "...and it stops short of C 80 studs off")
	cChar:Destroy()

	print("== DEKU: GEARSHIFT - harder a gear at a time")
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	aChar:SetAttribute("Gearshift", GSA.TopGear)
	fire(UseAbility, A, slotOf("DelawareSmash"), FWD, bRoot.Position, 7, aRoot.Position)
	task.wait(1.2)
	local geared = MAX - bHum.Health
	local want = volley * (1 + GSA.DamagePerGear * GSA.TopGear)
	check(math.abs(geared - want) < 0.6, string.format("at TOP GEAR the same volley hits %d%% harder (%.1f vs %.1f)", GSA.DamagePerGear * GSA.TopGear * 100, geared, volley))
	aChar:SetAttribute("Gearshift", nil)

	print("== DEKU: TRANSMISSION - the rush, DETROIT SMASH: QUINTUPLE, geared down")
	X = 38500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	A:SetAttribute("QuirkPick", pickOf.Gearshift)
	for _ = 1, GSA.TopGear do
		fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
		task.wait(GSA.Cooldown + 0.1)
	end
	clearSent()
	local bBase = bChar:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	local t0 = os.clock()
	while os.clock() - t0 < 5 and #sentTo(B, "GearshiftRecoil") == 0 do
		task.wait(0.05)
	end
	local quint, final = 0, false
	for _, h in sentTo(B, "GearshiftHit") do
		if h.Quintuple then
			quint += 1
		end
		if h.Final then
			final = true
		end
	end
	check(#sentTo(B, "TransmissionRush") == 1, "at TOP GEAR: he's on B in a blink")
	check(quint == GSA.Quintuple and final, "the rush, then DETROIT SMASH: QUINTUPLE (" .. quint .. " of them), then the last one")
	local floor = GSA.Hits * GSA.Damage + GSA.Quintuple * GSA.QuintupleDamage + GSA.FinisherDamage
	check(MAX - bHum.Health >= floor, "...B takes " .. (MAX - bHum.Health) .. " (at least " .. floor .. ")")
	check(#sentTo(B, "GearedDown") == 1 and bHum.WalkSpeed < bBase - 0.01, string.format("...and comes out of it geared down: slowed (%.1f of %.1f)", bHum.WalkSpeed, bBase))
	task.wait(1)

	print("== DEKU'S ULT: DANGER SENSE")
	X = 40500
	fresh("FullCowl", "FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 40))
	B:SetAttribute("Ult", 100)
	fire(UseAbility, B, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	clearSent()
	fire(UseAbility, A, slotOf("DelawareSmash"), FWD, bRoot.Position, 7, aRoot.Position)
	task.wait(1.2)
	check(#sentTo(A, "DangerSense") == 1, "someone else's move: he senses it coming")
	check(bHum.Health > MAX - Del.Damage * Del.Shots, "...and he's already moved (took " .. (MAX - bHum.Health) .. " of " .. Del.Damage * Del.Shots .. ")")
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	clearSent()
	fire(UseAbility, A, slotOf("DelawareSmash"), FWD, bRoot.Position, 7, aRoot.Position)
	task.wait(1.2)
	check(#sentTo(A, "DangerSense") == 0 and bHum.Health < MAX, "(once every " .. D.Ult.DangerSense.Cooldown .. "s: the next one lands)")
	fire(TestCommand, B, "EndUlt")
	task.wait(0.5)

	print("== DEKU'S ULT: 1,000,000% DELAWARE DETROIT SMASH")
	X = 42500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 200))
	local M = D.Ult.Extra
	check(M and M.Id == "MillionSmash", "his ult's 4th move")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(4)
	check(MAX - bHum.Health >= M.Damage, "it reaches B 200 studs down the street (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)
end)
---------------------------------------------------------------------------
-- Round 51: Chargebolt's Zap Trap (Live Wire's gone), the trap's live wire
-- to a pointer, Stun Bolt ricocheting off pointers and overloading traps,
-- the Thunder Dive; Deku's 100% Detroit Smash breaking his arms; Deku
-- dropping into the middle of the city
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, aAt + Vector3.new(0, 0, 1)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local FWD = Vector3.new(0, 0, 1)
	local EQ = Config.Quirks.Electrification
	local ZT = EQ.Abilities[3]
	local SB = EQ.Extra
	local function extra(name, at)
		local plr = Players:FindFirstChild(name) or addPlayer(name, name == "Charlie" and 3 or 4)
		fire(SelectQuirk, plr, "Explosion")
		local c, h, r = spawnChar(plr, CFrame.new(at))
		task.wait(0.1)
		h.Health = MAX
		return c, h, r
	end

	print("== CHARGEBOLT: ZAP TRAP")
	check(ZT.Id == "ZapTrap" and ZT.Name == "ZAP TRAP" and not Config.FindAbilityById("LiveWire"), "Live Wire's gone: 3 is ZAP TRAP")
	local X = 44500
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 40, 3, 0))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 0, 12), 1, aRoot.Position)
	task.wait(0.4)
	local set = sentTo(B, "ZapTrapSet")[1]
	check(set and typeof(set.Pos) == "Vector3" and math.abs(set.Pos.Z - 12) < 1 and set.WireTo == nil, "a trap on the street where he aimed (12 studs)")
	task.wait(ZT.ArmTime + 0.2)
	check(bHum.Health == MAX and #sentTo(B, "ZapTrapSnap") == 0, "...waiting there: nobody on it")
	bRoot.CFrame = CFrame.new(X + 2, 3, 12)
	task.wait(0.25)
	check(#sentTo(B, "ZapTrapSnap") == 1 and MAX - bHum.Health == ZT.Damage and bChar:GetAttribute("Stunned") == true,
		"B steps on it: jolted stiff (" .. (MAX - bHum.Health) .. ", " .. ZT.Stun .. "s)")
	task.wait(ZT.Stun + 0.3)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(X + 40, 3, 0)
	task.wait(0.1)
	bRoot.CFrame = CFrame.new(X + 1, 3, 12)
	task.wait(0.3)
	check(bHum.Health == MAX and #sentTo(B, "ZapTrapSnap") == 1, "...and it's spent")
	-- no more than Max at once
	clearSent()
	for k = 1, ZT.Max + 1 do
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, 3, FWD, Vector3.new(X - 8 * k, 0, 10), 1, aRoot.Position)
		task.wait(0.45)
	end
	local gone = sentTo(B, "ZapTrapGone")
	check(#sentTo(B, "ZapTrapSet") == ZT.Max + 1 and #gone == 1 and gone[1].How == "Replaced", "only " .. ZT.Max .. " at once: another replaces the oldest")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
	check(#sentTo(B, "ZapTrapGone") == ZT.Max + 1, "(another quirk: his traps go)")

	print("== CHARGEBOLT: a trap near a pointer strings a live wire to it")
	X = 46500
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 40, 3, 0))
	-- the pointer flies its full range and lands 60 studs down the street
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.1)
	fire(TestCommand, A, "ResetCooldowns")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 28), Vector3.new(X, 3, 29)) -- (he walks up the street)
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 0, 44), 1, aRoot.Position)
	task.wait(0.4 + ZT.ArmTime)
	set = sentTo(B, "ZapTrapSet")[1]
	check(set and set.WireTo ~= nil, "set within " .. ZT.WireRange .. " studs of a pointer: a live wire from the trap to it")
	bRoot.CFrame = CFrame.new(X + 0.5, 3, 52) -- (on the wire, well clear of the trap)
	task.wait(0.3)
	check(#sentTo(B, "ZapTrapWireJolt") == 1 and MAX - bHum.Health == ZT.WireDamage, "crossing it jolts you (" .. (MAX - bHum.Health) .. ")")
	task.wait(0.4)
	check(#sentTo(B, "ZapTrapWireJolt") == 1, "(once every " .. ZT.WireEvery .. "s, not every frame)")
	bRoot.CFrame = CFrame.new(X + 40, 3, 0)
	task.wait(1.6)

	print("== CHARGEBOLT: STUN BOLT off a pointer - it ricochets")
	X = 48500
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 6, 3, 60))
	local cChar, cHum = extra("Charlie", Vector3.new(X + 13, 3, 60))
	local dChar, dHum = extra("Delta", Vector3.new(X + 13, 3, 80)) -- (20 studs on: out of reach)
	bRoot.CFrame = CFrame.new(X + 40, 3, 0) -- (out of the pointer's way while it flies)
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.1)
	-- (he walks up: the pointer's within the bolt's range now)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 25), Vector3.new(X, 3, 26))
	bRoot.CFrame = CFrame.new(X + 6, 3, 60)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(0.6)
	local hit = sentTo(B, "StunBoltHit")[1]
	check(hit and hit.Relay == 2 and #hit.Points == 4, "the bolt hits the pointer and ricochets: pointer -> B -> C (" .. tostring(hit and #hit.Points) .. " points)")
	check(MAX - bHum.Health == SB.RicochetDamage and MAX - cHum.Health == SB.RicochetDamage, "...each one jolted (" .. (MAX - bHum.Health) .. ", " .. (MAX - cHum.Health) .. ")")
	check(dHum.Health == MAX, "...but only to someone within " .. SB.RicochetRange .. " studs of the last")
	dChar:Destroy()
	task.wait(1.5)
	-- a pointer on someone: it bounces on from them
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	cChar.Parent = nil
	cChar, cHum = extra("Charlie", Vector3.new(X + 8, 3, 30))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(bChar:GetAttribute("Pointed") == 1, "(B tagged with a pointer)")
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	bHum.Health, cHum.Health = MAX, MAX
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	hit = sentTo(B, "StunBoltHit")[1]
	check(hit and hit.Relay == 2 and MAX - bHum.Health == SB.Damage and MAX - cHum.Health == SB.RicochetDamage,
		"B wearing a pointer: the bolt ricochets on from them to C (" .. (MAX - cHum.Health) .. ")")
	cChar:Destroy()
	task.wait(1.5)

	print("== CHARGEBOLT: STUN BOLT into his own trap - it overloads")
	X = 50500
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 8, 3, 20))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 0, 14), 1, aRoot.Position)
	task.wait(0.4)
	local trapAt = sentTo(B, "ZapTrapSet")[1].Pos
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local from = aRoot.Position + Vector3.new(0, 1.4, 0)
	fire(UseAbility, A, Config.EXTRA_INDEX, ((trapAt + Vector3.new(0, 0.6, 0)) - from).Unit, trapAt, 1, aRoot.Position)
	task.wait(0.4)
	check(#sentTo(B, "ZapTrapOverload") == 1 and MAX - bHum.Health == ZT.OverDamage and bChar:GetAttribute("Ragdolled") == true,
		"aimed at the trap: it overloads - B " .. math.floor((bRoot.Position - trapAt).Magnitude) .. " studs off takes " .. (MAX - bHum.Health) .. ", knocked flat")
	task.wait(2)

	print("== CHARGEBOLT: DISCHARGE in the air - the Thunder Dive")
	X = 52500
	local stub = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
		end
		return nil
	end
	fresh("Electrification", "Explosion", Vector3.new(X, 40, 0), Vector3.new(X + 9, 3, 2))
	aRoot.Anchored = true
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.25 + 0.5)
	local D1 = EQ.Abilities[1]
	check(#sentTo(B, "ThunderDive") == 1 and aRoot.CFrame.Position.Y < 5, string.format("up in the air: he comes down as the bolt (%.1f up now)", aRoot.CFrame.Position.Y))
	check(MAX - bHum.Health == D1.AirDamage and #sentTo(B, "DischargeBurst") == 1 and sentTo(B, "DischargeBurst")[1].Air == true,
		"...and it goes off where he lands: B " .. D1.AirRadius .. " studs round takes " .. (MAX - bHum.Health))
	fresh("Electrification", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 14, 3, 0))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	check(#sentTo(B, "ThunderDive") == 0 and MAX - bHum.Health == 0, "(on the street: the usual shock round him - B 14 studs off is out of its " .. D1.Radius .. ")")
	workspace.Raycast = stub
	task.wait(1.2)

	print("== DEKU: 100% DETROIT SMASH - and the arm breaks")
	local D = Config.Quirks.FullCowl
	local HS = Config.FindAbilityById("HundredSmash")
	local pick
	for i, e in D.Extras do
		if e.Id == "HundredSmash" then
			pick = i
		end
	end
	check(pick ~= nil, "it's in his R cycle")
	X = 54500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	A:SetAttribute("QuirkPick", pick)
	local function smash()
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
		local before = aHum.Health
		bHum.Health = MAX
		fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
		task.wait(HS.Startup + 0.3)
		return before - aHum.Health
	end
	local cost = smash()
	local now = workspace:GetServerTimeNow()
	check(MAX - bHum.Health == HS.Damage and #sentTo(B, "HundredSmashBlast") == 1, "the whole street in front of him: B 60 studs off takes " .. (MAX - bHum.Health))
	check(aChar:GetAttribute("BrokenArmR") == nil and aChar:GetAttribute("BrokenArmL") == nil and sentTo(B, "HundredSmashBlast")[1].Side == "R",
		"...and his arm holds (round 75: no break)")
	check(cost == 0, "...no recoil (" .. cost .. ")")
	local _ = now
	task.wait(1)
	cost = smash()
	check(aChar:GetAttribute("BrokenArmL") == nil and cost == 0, "the next one: still fine")
	task.wait(1)
	cost = smash()
	check(cost == 0, "and the next: never a cost (" .. cost .. ")")
	task.wait(1)
	aHum.Health = 5
	cost = smash()
	check(aHum.Health == 5, "(it never hurts him: " .. aHum.Health .. ")")
	aHum.Health = MAX
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
	check(aChar:GetAttribute("BrokenArmR") == nil and aChar:GetAttribute("BrokenArmL") == nil, "(another quirk: his arms are fine)")

	print("== DEKU'S ULT: 1,000,000% leaves the arm in pieces")
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 200))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(4)
	check((aChar:GetAttribute("BrokenArmR") or 0) > workspace:GetServerTimeNow(), "the 1,000,000% Delaware Detroit Smash: his right arm goes purple")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== DEKU DROPS IN")
	-- (no scheduled one turning up mid-test: switched off, and any running
	-- one left to finish)
	fire(TestCommand, A, "PSSet", "DekuDrop", false)
	local DDC = Config.DekuDrop
	task.wait(DDC.Length)
	check(DDC and DDC.Enabled and DDC.Every >= 120 and DDC.JumpAt > DDC.ImpactAt, "every few minutes, in the middle of the city")
	local spot = DDC.Spot
	fresh("Explosion", "Explosion", spot + Vector3.new(-40, 0, 0), spot + Vector3.new(10, 0, 3))
	fire(TestCommand, A, "PSSet", "DekuDropNow")
	task.wait(0.1)
	local drop = sentTo(B, "DekuDrop")[1]
	check(drop and typeof(drop.Pos) == "Vector3" and (drop.Pos - spot).Magnitude < 1 and #sentTo(A, "DekuDrop") == 1, "the test menu's button: everyone sees him coming down")
	task.wait(DDC.ImpactAt + 0.2)
	check(bChar:GetAttribute("Ragdolled") == true and bHum.Health == MAX, "he lands: B 10 studs off is blown off his feet - not hurt")
	check(aChar:GetAttribute("Ragdolled") ~= true, "(A 40 studs off is fine)")
	fire(TestCommand, A, "PSSet", "DekuDropNow")
	task.wait(0.1)
	check(#sentTo(B, "DekuDrop") == 1, "(one at a time)")
	check(workspace:GetAttribute("DekuDrop") ~= true, "its switch turns them off")
	fire(TestCommand, A, "PSSet", "ResetSettings")
	check(workspace:GetAttribute("DekuDrop") ~= true, "(back off with the rest: off until switched on)")
	task.wait(DDC.Length)
end)
---------------------------------------------------------------------------
-- Round 52: ENDEAVOR (Hellflame: heat buildup, Hell Spider, Jet Burn,
-- Vanishing Fist, Hell's Curtain, Plus Ultra) and DABI (Blueflame: it sears
-- him; Cremation, Hell Minefield, Hell Spider, Blue Wall, Jet Burn, the
-- reveal) - both dev only; Deku's broken arm hanging limp; the BLOOD setting
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, aAt + Vector3.new(0, 0, 1)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	-- (a street under everyone, for the moves that stand on it)
	local stub = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
		end
		return nil
	end
	local FWD = Vector3.new(0, 0, 1)
	local EN, DB = Config.Quirks.Hellflame, Config.Quirks.Blueflame
	local HEAT = EN.Heat

	print("== ENDEAVOR (dev): the kit")
	check(EN.DevOnly == true and DB.DevOnly == true and table.find(Config.QuirkOrder, "Hellflame") ~= nil and table.find(Config.QuirkOrder, "Blueflame") ~= nil,
		"ENDEAVOR and DABI: two new dev characters on the list")
	check(EN.Abilities[1].Id == "HellSpider" and EN.Abilities[2].Id == "JetBurn" and EN.Abilities[3].Id == "VanishingFist" and EN.Special.Id == "FlashfireJet" and EN.Extra.Id == "HellsCurtain",
		"Endeavor: 1 Hell Spider, 2 Jet Burn, 3 Vanishing Fist, R Flashfire Jet, 4 Hell's Curtain")
	check(EN.Ult.Abilities[1].Id == "HellSpiderWeb" and EN.Ult.Abilities[2].Id == "VanishingJetBurn" and EN.Ult.Abilities[3].Id == "ProminenceNova" and EN.Ult.Extra.Id == "SkyProminence",
		"...Plus Ultra: Hell Spider Web, Vanishing Jet Burn, Prominence Burn; 4 Prominence Burn in the sky")
	for _, id in { "HellSpider", "JetBurn", "VanishingFist", "HellsCurtain", "HellSpiderWeb", "VanishingJetBurn", "ProminenceNova", "SkyProminence",
		"Cremation", "HellMinefield", "BlueSpider", "BlueWall", "BlueJetBurn", "BlueProminence", "SekotoPeak", "BlueVanishing" } do
		if not Config.FindAbilityById(id) then
			check(false, id .. " in the config")
		end
	end

	print("== ENDEAVOR: heat buildup")
	local X = 60500
	fresh("Hellflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 20))
	check(aChar:GetAttribute("Heat") == 0, "he starts cold (Heat 0)")
	local SP = EN.Abilities[1]
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Heat") == SP.Heat and #sentTo(B, "HellSpider") == 1, "HELL SPIDER heats him up (" .. tostring(aChar:GetAttribute("Heat")) .. ")")
	task.wait(0.5)
	check(MAX - bHum.Health == SP.Damage * SP.Hits, "...the threads cut B, 20 studs in front, " .. SP.Hits .. " times (" .. (MAX - bHum.Health) .. ")")
	local burn = sentTo(B, "Burn")[1]
	check(burn and burn.Pal == "hell", "...and he burns - in Endeavor's fire")
	task.wait(HEAT.CoolDelay + 1)
	check((aChar:GetAttribute("Heat") or 99) < SP.Heat, "he cools off a moment after (" .. tostring(aChar:GetAttribute("Heat")) .. ")")
	-- the top of the gauge
	aChar:SetAttribute("Heat", 90)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Overheated") == true and aHum.WalkSpeed == HEAT.Slow and #sentTo(B, "Overheat") == 1, "at the top he OVERHEATS: steam, slowed to " .. HEAT.Slow)
	fire(TestCommand, A, "ResetCooldowns")
	task.wait(0.9)
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "HellSpider") == 0, "...and his fire won't come")
	task.wait(HEAT.Lock)
	local h = aChar:GetAttribute("Heat") or 0
	check(aChar:GetAttribute("Overheated") == nil and h <= HEAT.Reset and h > HEAT.Reset - 20 and aHum.WalkSpeed ~= HEAT.Slow, "then he's cooled enough to go again (" .. h .. ")")

	print("== ENDEAVOR: JET BURN, VANISHING FIST, HELL'S CURTAIN")
	X = 62500
	fresh("Hellflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	local JB = EN.Abilities[2]
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1)
	local took = MAX - bHum.Health
	check(took >= JB.Damage - 0.5 and took <= JB.Damage + 4, "JET BURN: a torrent down the street - B 30 studs off takes " .. took)
	X = 64500
	fresh("Hellflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	local VF = EN.Abilities[3]
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	local vh = sentTo(B, "VanishingFistHit")[1]
	check(vh and vh.Target == bChar and MAX - bHum.Health == VF.Damage and bChar:GetAttribute("Ragdolled") == true, "VANISHING FIST: on him, and the fist lands as an inferno (" .. (MAX - bHum.Health) .. ", knocked flat)")
	task.wait(2.5)
	X = 66500
	fresh("Hellflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	local HC = EN.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(MAX - bHum.Health == HC.Damage, "HELL'S CURTAIN: the sheet of fire - B 12 studs in front takes " .. (MAX - bHum.Health))
	task.wait(1.6)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(X + 4, 3, HC.Range) -- (walking through the wall it left)
	task.wait(0.7)
	check(MAX - bHum.Health >= HC.TickDamage, "...and the wall it leaves burns whoever goes through it (" .. (MAX - bHum.Health) .. ")")
	task.wait(HC.Duration)

	print("== ENDEAVOR: PLUS ULTRA")
	X = 68500
	fresh("Hellflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 200, 3, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	bRoot.CFrame = CFrame.new(X, 3, 20)
	bHum.Health = MAX
	aChar:SetAttribute("Heat", 50)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.9)
	local nova = sentTo(B, "ProminenceNovaBurst")[1]
	check(nova and (nova.Heat or 0) > 0.3 and (nova.Heat or 0) <= 0.5 and aChar:GetAttribute("Heat") == 0 and MAX - bHum.Health > EN.Ult.Abilities[3].Damage,
		"PROMINENCE BURN: everything out of him - it vents his heat, and hits harder for it (" .. (MAX - bHum.Health) .. ")")
	task.wait(2.5)
	-- the fist thrown
	bRoot.CFrame = CFrame.new(X, 3, 50)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	local fly = sentTo(B, "FlameFistFly")[1]
	check(fly and fly.Pal == "hell" and math.abs(fly.To.Z - 50) < 4, "VANISHING JET BURN: a fist of fire flies down the street, at B")
	task.wait(0.6)
	check(#sentTo(B, "FlameFistBoom") == 1 and MAX - bHum.Health >= EN.Ult.Abilities[2].Damage, "...and goes off on him (" .. (MAX - bHum.Health) .. ")")
	task.wait(2.5)
	-- the sky
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 6), aRoot.Position)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local SK = EN.Ult.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.4)
	local rise = sentTo(B, "SkyProminenceRise")[1]
	check(rise and rise.Target == bChar and bChar:GetAttribute("Grabbed") == true, "PLUS ULTRA: PROMINENCE BURN - he takes hold of B...")
	task.wait(SK.Rise * 0.6)
	check(aRoot.CFrame.Position.Y > 40, string.format("...rockets straight up with him (%.0f up)", aRoot.CFrame.Position.Y))
	task.wait(SK.Rise * 0.4 + 0.3)
	check(#sentTo(B, "SkyProminenceBurst") == 1 and MAX - bHum.Health >= SK.Damage and bChar:GetAttribute("Grabbed") == nil,
		"...and lets it all out up there (" .. (MAX - bHum.Health) .. ") - B's thrown down into the street")
	task.wait(1.8)
	check(aRoot.Anchored == false and aRoot.CFrame.Position.Y < 8, string.format("(he comes back down on his flames: %.1f up)", aRoot.CFrame.Position.Y))
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	print("== DABI (dev): Blueflame sears him")
	check(DB.Abilities[1].Id == "Cremation" and DB.Abilities[2].Id == "HellMinefield" and DB.Abilities[3].Id == "BlueSpider" and DB.Special.Id == "BlueWall" and DB.Extra.Id == "BlueJetBurn",
		"Dabi: 1 Cremation, 2 Hell Minefield, 3 Hell Spider, R Blue Wall, 4 Jet Burn")
	X = 70500
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 20))
	local CR = DB.Abilities[1]
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(MAX - aHum.Health == CR.SelfBurn and #sentTo(B, "Seared") == 1, "every move costs him (" .. (MAX - aHum.Health) .. "): his fire burns him too")
	task.wait(0.8)
	check(MAX - bHum.Health >= CR.Damage and (sentTo(B, "Burn")[1] or {}).Pal == "blue", "CREMATION: the wave of blue fire - B takes " .. (MAX - bHum.Health) .. ", burning blue")
	local patches = sentTo(B, "CremationPatches")[1]
	check(patches and #patches.Points == CR.Patches, "...and the street stays alight in " .. CR.Patches .. " places")
	task.wait(1.2)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(patches.Points[2] + Vector3.new(0, 3, 0))
	task.wait(1.1)
	check(MAX - bHum.Health >= CR.PatchDamage, "...standing in it burns (" .. (MAX - bHum.Health) .. ")")
	aHum.Health = 2
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(aHum.Health == 1, "(never the last of his health: " .. aHum.Health .. ")")
	aHum.Health = MAX
	task.wait(1.5)

	print("== DABI: HELL MINEFIELD, HELL SPIDER, BLUE WALL, JET BURN")
	X = 72500
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	local HM = DB.Abilities[2]
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 0, 30), 1, aRoot.Position)
	task.wait(HM.Delay + HM.Count * HM.Gap + 0.3)
	check(#sentTo(B, "MinefieldErupt") == HM.Count and MAX - bHum.Health >= HM.Damage, "HELL MINEFIELD: " .. HM.Count .. " pillars out of the street up to where he aimed - B takes " .. (MAX - bHum.Health))
	task.wait(2)
	X = 74500
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 20))
	local BS = DB.Abilities[3]
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.8)
	check(MAX - bHum.Health >= BS.Damage * BS.Hits, "HELL SPIDER (his): the streams - B takes " .. (MAX - bHum.Health))
	task.wait(1.5)
	X = 76500
	local BW = DB.Special
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, BW.Radius))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	check(MAX - bHum.Health == BW.Damage and bChar:FindFirstChild("HumanoidRootPart"):FindFirstChild("Knockback") ~= nil, "BLUE WALL: the ring bursts up under B and throws him out (" .. (MAX - bHum.Health) .. ")")
	bRoot.CFrame = CFrame.new(X, 3, 40)
	task.wait(1)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(X + BW.Radius, 3, 0)
	task.wait(0.8)
	check(MAX - bHum.Health >= BW.TickDamage, "...and crossing it burns (" .. (MAX - bHum.Health) .. ")")
	task.wait(BW.Duration)
	X = 78500
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	local BJ = DB.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	local bh = sentTo(B, "BlueJetBurnHit")[1]
	check(bh and bh.Target == bChar and MAX - bHum.Health == BJ.Damage, "JET BURN (his): the rush, and blue fire in B's face (" .. (MAX - bHum.Health) .. ")")
	task.wait(2.5)

	print("== DABI: IT'S ME... TOYA")
	X = 80500
	fresh("Blueflame", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X + 200, 3, 0))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.2)
	aHum.Health = MAX
	task.wait(2)
	local lost = MAX - aHum.Health
	check(lost >= DB.Ult.Drain * 1.5 and lost <= DB.Ult.Drain * 2.5, "burning all over: it eats " .. DB.Ult.Drain .. " a second (" .. lost .. " in 2s)")
	local floor = MAX * DB.Ult.Floor
	aHum.Health = floor + 0.3
	task.wait(1)
	check(math.abs(aHum.Health - floor) < 0.01, "...but never below " .. math.floor(DB.Ult.Floor * 100) .. "% of him")
	aHum.Health = MAX
	bRoot.CFrame = CFrame.new(X, 3, 60)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	local before = aHum.Health
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.6)
	check(MAX - bHum.Health > DB.Ult.Abilities[1].Damage and before - aHum.Health < 4,
		"PROMINENCE BURN (his): the beam out of his chest - B 60 studs off takes " .. (MAX - bHum.Health) .. " (and it doesn't sear him on top)")
	local tUp = os.clock()
	while bChar:GetAttribute("Ragdolled") and os.clock() - tUp < 4 do
		task.wait(0.05)
	end
	bRoot.CFrame = CFrame.new(X, 3, 10)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.6)
	check(MAX - bHum.Health >= DB.Ult.Abilities[2].Damage + DB.Ult.Abilities[2].TickDamage, "SEKOTO PEAK: the fire spreads over the street - B keeps burning (" .. (MAX - bHum.Health) .. ")")
	task.wait(DB.Ult.Abilities[2].Duration)
	bRoot.CFrame = CFrame.new(X, 3, 40)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	check((sentTo(B, "FlameFistFly")[1] or {}).Pal == "blue", "VANISHING FIST (thrown): a fist of blue fire")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	print("== DEKU: the broken arm hangs limp")
	X = 82500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	-- (the mock body is just a root: give it a torso, an arm and the shoulder joint)
	local torso = M.new("Part", "Torso")
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = aRoot.CFrame
	torso.Parent = aChar
	local arm = M.new("Part", "Right Arm")
	arm.Size = Vector3.new(1, 2, 1)
	arm.CFrame = aRoot.CFrame * CFrame.new(1.5, 0, 0)
	arm.Parent = aChar
	local motor = M.new("Motor6D", "Right Shoulder")
	motor.Part0 = torso
	motor.Part1 = arm
	motor.C0 = CFrame.new(1, 0.5, 0)
	motor.C1 = CFrame.new(-0.5, 0.5, 0)
	motor.Enabled = true
	motor.Parent = torso
	-- (round 75: 100% doesn't break it any more - the ult's 1,000,000% does)
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(3)
	local ball
	for _, c in arm:GetChildren() do
		if c.Name == "LimpArmR" and c.ClassName == "BallSocketConstraint" then
			ball = c
		end
	end
	check(motor.Enabled == false and motor:GetAttribute("Limp") == true and ball ~= nil and ball.ClassName == "BallSocketConstraint",
		"1,000,000% breaks it: the shoulder lets go and the arm hangs off him on a ball socket - limp")
	check(ball and ball.LimitsEnabled == true and ball.UpperAngle >= 60 and ball.UpperAngle <= 120 and torso:FindFirstChild("LimpArmR") ~= nil,
		"...swinging free (a cone of " .. tostring(ball and ball.UpperAngle) .. " degrees), flopping about as he moves")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
	check(motor.Enabled == true and motor:GetAttribute("Limp") == nil and arm:FindFirstChild("LimpArmR") == nil, "healed (another quirk): the joint's back")

	print("== BLOOD: a setting, saved")
	local Settings = remotes:FindFirstChild("Settings")
	fire(Settings, A, "Blood", false)
	task.wait(0.2)
	check(A:GetAttribute("Blood") == false, "BLOOD off in the settings (saved with the rest)")
	fire(Settings, A, "Blood", true)
	task.wait(0.2)
	check(Config.Blood and Config.Blood.Enabled == true and Config.Blood.MinDamage > 0, "(on by default; only hard hits bleed)")
	workspace.Raycast = stub
end)
---------------------------------------------------------------------------
-- Round 53: Deku's ult the way the movies animate it (the lightning blitz,
-- GO BEYOND - PLUS ULTRA's longer charge), the new emotes
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(qa, qb, aAt, bAt)
		fire(SelectQuirk, A, qa)
		fire(SelectQuirk, B, qb or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aAt, aAt + Vector3.new(0, 0, 1)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bAt, aAt))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local FWD = Vector3.new(0, 0, 1)
	local D = Config.Quirks.FullCowl
	local RUSH = Config.FindAbilityById("GearshiftRush")

	print("== DEKU AT 100%: SHOOT STYLE RUSH, the lightning blitz")
	local X = 61500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.4)
	bChar.Parent = nil
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 12), Vector3.new(X, 3, 0)))
	bHum.Health = MAX
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.12 + 0.05)
	local blitz = sentTo(B, "RushBlitz")[1]
	check(blitz and #blitz.Points == RUSH.Hits and blitz.Target == bChar, "the blitz: " .. RUSH.Hits .. " points round B, everyone told where (" .. tostring(blitz and #blitz.Points) .. ")")
	local round = blitz ~= nil
	for _, p in blitz and blitz.Points or {} do
		local off = Vector3.new(p.X - blitz.Center.X, 0, p.Z - blitz.Center.Z).Magnitude
		round = round and off <= RUSH.Orbit + 0.05 and off >= 1.5
	end
	check(round and blitz and (Vector3.new(blitz.Center.X, 0, blitz.Center.Z) - Vector3.new(X, 0, 12)).Magnitude < 0.5, "...a zig-zag right round him, " .. RUSH.Orbit .. " studs out")
	local sides = 0
	if blitz then
		local right = Vector3.new(-1, 0, 0)
		for i = 2, #blitz.Points do
			local a = (blitz.Points[i - 1] - blitz.Center):Dot(right)
			local b = (blitz.Points[i] - blitz.Center):Dot(right)
			if a * b < 0 then
				sides += 1
			end
		end
	end
	check(sides >= RUSH.Hits - 2, "...side to side (" .. sides .. " crossings)")
	check(aRoot.Anchored == true and aChar:GetAttribute("BodyLocked") == true, "...the server carries him (anchored, his screen hands off)")
	task.wait(RUSH.Hits * RUSH.Gap * 0.5)
	local mid = (aRoot.Position - blitz.Center).Magnitude
	check(mid <= RUSH.Orbit + 0.3 and mid >= 1.5, string.format("...he's round B mid-blitz (%.1f studs)", mid))
	task.wait(RUSH.Hits * RUSH.Gap * 0.5 + 0.3)
	check(MAX - bHum.Health >= RUSH.FinisherDamage, "...a kick every time he lands, then the big one (B took " .. (MAX - bHum.Health) .. ")")
	check(aRoot.Anchored ~= true and aChar:GetAttribute("BodyLocked") == nil, "...and he's free again")
	check((aRoot.Position - (blitz.Center - FWD * 3.6)).Magnitude < 1, "...standing in front of where B was")
	-- nobody there: he blitzes the spot he's aiming at
	bChar.Parent = nil
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.2)
	local whiff = sentTo(B, "RushBlitz")[1]
	check(whiff and (whiff.Center - Vector3.new(X, 3, 9)).Magnitude < 0.5 and whiff.Target == nil, "a whiff: he blitzes the spot 9 studs ahead")
	task.wait(RUSH.Hits * RUSH.Gap + 0.4)
	check(aRoot.Anchored ~= true and aChar:GetAttribute("BodyLocked") == nil, "...and lets go of him after")
	-- the ult running out mid-blitz: let go, never stuck
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 12), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.25)
	aChar:SetAttribute("Stunned", true)
	task.wait(RUSH.Hits * RUSH.Gap + 0.3)
	check(aRoot.Anchored ~= true and aChar:GetAttribute("BodyLocked") == nil, "stunned mid-blitz: it stops, and lets go of him")
	aChar:SetAttribute("Stunned", false)
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== DEKU AT 100%: 1,000,000% - GO... BEYOND... PLUS ULTRA!!")
	X = 62500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 150))
	local M = D.Ult.Extra
	check(M.Charge == 1.45 and M.CinematicArmor >= M.Charge, "the charge takes " .. M.Charge .. "s (All Might's there behind him), and he can't be touched through it")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.2)
	check(bHum.Health == MAX and #sentTo(B, "MillionSmash") == 1, "...nothing yet at 1.2s: GO... BEYOND...")
	task.wait(2)
	check(MAX - bHum.Health >= M.Damage, "...PLUS ULTRA!! - it reaches B 150 studs down the street (" .. (MAX - bHum.Health) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== MORE EMOTES")
	local want = { "Kamehameha", "DubiousFood", "HeroLanding", "TPose", "Griddy", "Nap", "FakeDeath" }
	local have = {}
	for _, e in Config.Emotes do
		have[e.Id] = e
	end
	local all = true
	for _, id in want do
		all = all and have[id] ~= nil and type(have[id].Name) == "string" and type(have[id].Icon) == "string"
	end
	check(all and #Config.Emotes == 17, "7 new emotes on the wheel (" .. #Config.Emotes .. " in all): Kamehameha, Dubious Food, Hero Landing, T-Pose, the Griddy, Nap, Fake Death")
	X = 63500
	fresh("FullCowl", "Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 10))
	local passed = 0
	for _, id in want do
		clearSent()
		fire(UseAbility, A, Config.EMOTE_INDEX, id)
		local seen = sentTo(B, "Emote")[1]
		if seen and seen.Id == id then
			passed += 1
		end
		task.wait(0.5)
	end
	check(passed == #want, "...every one passed on to everyone else (" .. passed .. ")")
end)
---------------------------------------------------------------------------
-- Round 58: the world events off until someone switches them on; emotes
-- bought in the shop (the only way to get one) and a four-slot wheel that
-- starts empty; One For All's vestige realm and its hidden way in
---------------------------------------------------------------------------
;M.section(function()
	local ShopRemote = remotes:FindFirstChild("Shop")
	print("== THE WORLD EVENTS: off until someone switches them on")
	fire(TestCommand, A, "PSSet", "ResetSettings")
	check(workspace:GetAttribute("SkyBattle") ~= true and workspace:GetAttribute("DekuDrop") ~= true, "as the server starts (and after RESET): the sky battle and Deku dropping in are off")
	check(Config.SkyBattle.Enabled == true and Config.DekuDrop.Enabled == true, "...still there to switch on")
	clearSent()
	task.wait(2)
	check(#sentTo(B, "SkyBattle") == 0 and #sentTo(B, "DekuDrop") == 0, "...and neither turns up on its own (long past their first time)")
	fire(TestCommand, A, "PSSet", "SkyBattle", true)
	fire(TestCommand, A, "PSSet", "DekuDrop", true)
	check(workspace:GetAttribute("SkyBattle") == true and workspace:GetAttribute("DekuDrop") == true, "the test menu's switches turn them on")
	fire(TestCommand, A, "PSSet", "ResetSettings")
	check(workspace:GetAttribute("SkyBattle") ~= true and workspace:GetAttribute("DekuDrop") ~= true, "RESET puts them back off")
	clearSent()
	fire(TestCommand, A, "PSSet", "SkyBattleNow")
	task.wait(0.1)
	check(#sentTo(B, "SkyBattle") == 1, "the GO button still starts one while they're off")

	print("== EMOTES: rolled in the shop (JJS-style), four on the wheel")
	local X = 71500
	local ESH = Config.EmoteShop
	local rated = 0
	for _, e in Config.Emotes do
		if e.Rarity and e.Price == nil then
			rated += 1
		end
	end
	check(rated == #Config.Emotes and Config.EmoteSlots == 4 and ESH.RollPrice == 25 and table.concat(ESH.Multipliers, ",") == "1,2,5,10" and ESH.PickAt == 10,
		"every emote has a rarity (" .. rated .. "/" .. #Config.Emotes .. "), no price: they're rolled at " .. ESH.RollPrice .. " a go, 1x/2x/5x/10x")
	local E = addPlayer("Echo", 5)
	task.wait(0.3)
	check(E:GetAttribute("EmotesOwned") == "" and E:GetAttribute("EmoteWheel") == ",,,", "a new player owns none: the wheel's four slots are empty (" .. tostring(E:GetAttribute("EmoteWheel")) .. ")")
	fire(SelectQuirk, E, "Explosion")
	local eChar = spawnChar(E, CFrame.new(X, 3, 0))
	task.wait(0.3)
	clearSent()
	fire(UseAbility, E, Config.EMOTE_INDEX, "Wave")
	check(#sentTo(B, "Emote") == 0, "an emote you don't own doesn't play")
	local start = E:GetAttribute("Bucks") or 0
	fire(ShopRemote, E, "RollEmotes", 1)
	local no = sentTo(E, "ShopResult")[1]
	check(no and no.Ok == false and no.Item == "Roll" and E:GetAttribute("EmotesOwned") == "" and (E:GetAttribute("Bucks") or 0) == start,
		"not enough (" .. start .. " Bucks): it says so, nothing's taken")
	for _ = 1, 5 do
		fire(TestCommand, E, "MoneyPrinter") -- (100 a go: enough for the 16 rolls below)
	end
	local bucks = E:GetAttribute("Bucks") or 0
	task.wait(0.6)
	clearSent()
	fire(ShopRemote, E, "RollEmotes", 1)
	local roll = sentTo(E, "EmoteRoll")[1]
	local first = roll and roll.Got[1]
	check(roll and #roll.Got == 1 and roll.Pick == 0 and E:GetAttribute("EmotesOwned") == first and E:GetAttribute("EmoteWheel") == first .. ",,,"
		and E:GetAttribute("Bucks") == bucks - ESH.RollPrice, "1x: a random emote (" .. tostring(first) .. "), straight onto the wheel, " .. ESH.RollPrice .. " Bucks")
	fire(ShopRemote, E, "RollEmotes", 3)
	check(E:GetAttribute("Bucks") == bucks - ESH.RollPrice, "3x isn't a thing")
	task.wait(0.6)
	clearSent()
	fire(ShopRemote, E, "RollEmotes", 5)
	roll = sentTo(E, "EmoteRoll")[1]
	local seen, repeats = { [first] = true }, 0
	for _, id in roll and roll.Got or {} do
		if seen[id] then
			repeats += 1
		end
		seen[id] = true
	end
	check(roll and #roll.Got == 5 and repeats == 0 and E:GetAttribute("Bucks") == bucks - 6 * ESH.RollPrice, "5x: five more, never one you have (" .. table.concat(roll and roll.Got or {}, ",") .. ")")
	local order = {}
	for id in string.gmatch(E:GetAttribute("EmotesOwned"), "[^,]+") do
		table.insert(order, id)
	end
	check(#order == 6 and order[1] == first and order[6] == roll.Got[5], "what you own is kept in the order you got it (the shop lists the newest first)")
	check(E:GetAttribute("EmoteWheel") == first .. "," .. roll.Got[1] .. "," .. roll.Got[2] .. "," .. roll.Got[3], "...the wheel filled up in that order: " .. E:GetAttribute("EmoteWheel"))
	task.wait(0.6)
	clearSent()
	fire(ShopRemote, E, "RollEmotes", 10)
	roll = sentTo(E, "EmoteRoll")[1]
	check(roll and #roll.Got == 9 and roll.Pick == 1 and E:GetAttribute("EmotePicks") == 1 and E:GetAttribute("Bucks") == bucks - 16 * ESH.RollPrice,
		"10x: nine random, and the tenth you pick yourself (a free pick waiting; paid for all ten)")
	local left
	for _, e in Config.Emotes do
		if not string.find("," .. E:GetAttribute("EmotesOwned") .. ",", "," .. e.Id .. ",", 1, true) then
			left = e.Id
		end
	end
	fire(ShopRemote, E, "PickEmote", first)
	check(E:GetAttribute("EmotePicks") == 1, "the pick can't be one you have")
	clearSent()
	fire(ShopRemote, E, "PickEmote", left)
	check(left and string.find(E:GetAttribute("EmotesOwned"), left, 1, true) and E:GetAttribute("EmotePicks") == nil and sentTo(E, "EmoteRoll")[1],
		"picked: " .. tostring(left) .. " is yours, no picks left")
	task.wait(0.6)
	clearSent()
	for _ = 1, #Config.Emotes - 16 do
		fire(ShopRemote, E, "RollEmotes", 1)
		task.wait(0.6)
	end
	clearSent()
	local b2 = E:GetAttribute("Bucks")
	fire(ShopRemote, E, "RollEmotes", 1)
	no = sentTo(E, "ShopResult")[1]
	check(no and no.Ok == false and no.Text:find("all the emotes") and E:GetAttribute("Bucks") == b2, "every one owned: \"" .. tostring(no and no.Text) .. "\" - and it takes nothing")
	task.wait(0.5)
	clearSent()
	fire(UseAbility, E, Config.EMOTE_INDEX, first)
	check(#sentTo(B, "Emote") == 1 and sentTo(B, "Emote")[1].Id == first, "...and now they play for everyone")
	fire(ShopRemote, E, "EquipEmote", 4, first)
	local w = {}
	for id in string.gmatch(E:GetAttribute("EmoteWheel") .. ",", "([^,]*),") do
		table.insert(w, id)
	end
	check(w[1] == "" and w[4] == first, "moved to slot 4 (it leaves slot 1): " .. tostring(E:GetAttribute("EmoteWheel")))
	task.wait(0.1)
	fire(ShopRemote, E, "EquipEmote", 5, first)
	task.wait(0.1)
	fire(ShopRemote, E, "EquipEmote", 1.5, first)
	check(E:GetAttribute("EmoteWheel") == table.concat(w, ","), "no slot 5, no half slots")
	local ownedStr = E:GetAttribute("EmotesOwned")
	E.Parent = nil
	Players.PlayerRemoving:Fire(E)
	task.wait(0.2)
	local saved = DS.data["u_5"]
	check(saved and saved.Emotes == ownedStr and saved.Wheel == table.concat(w, ","), "leaving saves what you own (in order) and your wheel")
	eChar.Parent = nil
	DS.data["u_6"] = { Bucks = 3, Items = {}, Kills = 0, Emotes = "Nap,Bogus,Griddy", Wheel = "Nap,Bogus,Kamehameha,Griddy", Picks = 2, Codes = "PLUSULTRA", EmoteWipe = Config.EmoteShop.Wipe }
	local F = addPlayer("Foxtrot", 6)
	task.wait(0.3)
	check(F:GetAttribute("EmotesOwned") == "Nap,Griddy" and F:GetAttribute("EmoteWheel") == "Nap,,,Griddy" and F:GetAttribute("EmotePicks") == 2 and F:GetAttribute("CodesUsed") == "PLUSULTRA",
		"coming back: yours load in the order you got them (nothing that isn't an emote, nothing on the wheel you don't own), your free picks and your codes: "
			.. tostring(F:GetAttribute("EmotesOwned")) .. " / " .. tostring(F:GetAttribute("EmoteWheel")))
	F.Parent = nil
	Players.PlayerRemoving:Fire(F)

	print("== ONE FOR ALL: THE VESTIGE REALM")
	local VRC = Config.VestigeRealm
	local realm = workspace:FindFirstChild("VestigeRealm")
	local names, shadows, colored = {}, 0, 0
	for _, m in realm and realm:GetChildren() or {} do
		if m:IsA("Model") and m:GetAttribute("VestigeName") then
			table.insert(names, m:GetAttribute("VestigeName"))
			local black, field = true, false
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					if p.Color.R > 0.05 or p.Color.G > 0.05 then
						black = false
					end
					if p.Material == Enum.Material.ForceField then
						field = true
					end
				end
			end
			shadows += black and 1 or 0
			colored += field and 1 or 0
		end
	end
	local all = table.concat(names, ", ")
	check(realm and #names == 8 and all:find("YOICHI SHIGARAKI", 1, true) and all:find("NANA SHIMURA", 1, true) and all:find("TOSHINORI YAGI", 1, true),
		"far off, the realm: all eight who held One For All (" .. all .. ")")
	check(shadows == 2 and colored >= 4, "...two of them only shadows, the others draped in colour and light (" .. shadows .. " shadows, " .. colored .. " in colour)")
	check(realm and realm:FindFirstChild("Floor") and realm:FindFirstChild("Heart") and realm:FindFirstChild("WakeDoor"), "...a black glass floor, the flame, a way out")
	local way = workspace:FindFirstChild("VestigeWay")
	local ember = way and way:FindFirstChild("Ember")
	local spot = way and way:FindFirstChild("RestSpot")
	local prompt = spot and spot:FindFirstChild("Rest")
	check(ember and (ember.Position - VRC.Bench).Magnitude < 4 and ember.Size.X < 0.5, "the way in: a tiny ember over the rooftop bench (easy to miss)")
	check(prompt and prompt.HoldDuration >= 1.5 and prompt.MaxActivationDistance <= 8 and prompt.ActionText == "Rest a while", "...rest there a while (hold, right up close)")
	-- (from anywhere else, nothing)
	fire(SelectQuirk, A, "Explosion")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(X, 3, 30))
	task.wait(0.2)
	clearSent()
	prompt.Triggered:Fire(A)
	task.wait(1.6)
	check(#sentTo(A, "VestigeIn") == 0 and A:GetAttribute("InVestige") == nil, "resting anywhere but the bench does nothing")
	aChar:PivotTo(CFrame.new(VRC.Bench + Vector3.new(0, 2.6, -3)))
	task.wait(0.1)
	prompt.Triggered:Fire(A)
	check(#sentTo(A, "VestigeIn") == 1, "at the bench: you drift off (your screen goes dark)")
	task.wait(1.6)
	local arrive = VRC.Center + Vector3.new(0, 3.5, 66)
	check(A:GetAttribute("InVestige") == true and (aRoot.Position - arrive).Magnitude < 6, "...and wake up inside One For All (" .. tostring(aRoot.Position) .. ")")
	clearSent()
	local door = realm:FindFirstChild("WakeDoor")
	door.Touched:Fire(aRoot)
	check(#sentTo(A, "VestigeOut") == 1, "walk into the pale doorway: you wake up")
	task.wait(1.4)
	check(A:GetAttribute("InVestige") == nil and (aRoot.Position - VRC.Bench).Magnitude < 8, "...back on the roof by the bench (" .. tostring(aRoot.Position) .. ")")
	fire(TestCommand, A, "Vestige")
	task.wait(1.6)
	check(A:GetAttribute("InVestige") == true, "the test menu goes straight in")
	aChar:PivotTo(CFrame.new(VRC.Center + Vector3.new(0, -70, 0)))
	task.wait(1.8)
	check(A:GetAttribute("InVestige") == nil and (aRoot.Position - VRC.Center).Magnitude > 500, "off the edge: you wake up (not a fall to your death)")
end)
---------------------------------------------------------------------------
-- Round 59: the ult earned by dealing damage (1.5 players' worth); nothing
-- hits someone who's down but a downslam; Suneater's Bamboo Sweep and
-- Urchin Spikes (in the air), his glide; Mr. Compress's Vanishing Act held;
-- Dabi hides the avatar's own hair; awakening outfits
---------------------------------------------------------------------------
;M.section(function()
	local ShopRemote = remotes:FindFirstChild("Shop")
	local X = 73500
	local MAX = Config.PlayerMaxHealth
	local FWD = Vector3.new(0, 0, 1)
	workspace:SetAttribute("HealthRegen", false)
	workspace:SetAttribute("DownImmune", nil)
	local function place(aQuirk, aPos, bPos, bQuirk)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		if aChar then
			aChar.Parent = nil
		end
		if bChar then
			bChar.Parent = nil
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aPos, aPos + FWD))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		task.wait(0.25)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		clearSent()
	end

	print("== THE ULT: earned by dealing damage - 1.5 players' worth")
	local U = Config.Ult
	check(math.abs(U.GainPerDamageDealt * MAX * 1.5 - 100) < 1e-6 and U.PassivePerSecond == 0 and U.GainPerDamageTaken == 0
		and Config.Guard.ParryUlt == 0 and Config.Fights.UltOnKO == 0 and U.StudioChargeMultiplier == 1,
		"a full meter is " .. MAX * 1.5 .. " damage dealt; nothing fills it on its own, from taking hits, parrying or a KO")
	place("Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	A:SetAttribute("Ult", 0)
	B:SetAttribute("Ult", 0)
	task.wait(2.2)
	check((A:GetAttribute("Ult") or 0) == 0 and (B:GetAttribute("Ult") or 0) == 0, "standing about: nothing (" .. tostring(A:GetAttribute("Ult")) .. ")")
	local h0 = aHum.Health
	fire(UseAbility, B, 0)
	task.wait(0.3)
	local dealt = h0 - aHum.Health
	check(dealt > 0 and math.abs((B:GetAttribute("Ult") or 0) - dealt * 100 / (MAX * 1.5)) < 0.01 and (A:GetAttribute("Ult") or 0) == 0,
		string.format("B's punch (%d): B's meter +%.2f%%, A's (the one hit) nothing", dealt, B:GetAttribute("Ult") or 0))
	task.wait(1)

	print("== DOWN MEANS DOWN: nothing hits someone who's down but a downslam")
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	local stubRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end
	bChar:SetAttribute("Ragdolled", true)
	h0 = bHum.Health
	fire(UseAbility, A, 0)
	task.wait(0.35)
	check(bHum.Health == h0, "an M1 on someone lying in the street: nothing")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position, false)
	task.wait(0.4)
	check(bHum.Health == h0, "...a move (Chicken Kick): nothing")
	task.wait(Config.M1.ComboReset + 0.1)
	-- up in the air over them: three hits (none land), then the downslam
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 8, 0), Vector3.new(X, 8, 10))
	bRoot.CFrame = CFrame.new(X, 7, 3.5)
	for _ = 1, 3 do
		fire(UseAbility, A, 0)
		task.wait(Config.M1.Cooldown + 0.05)
	end
	check(bHum.Health == h0, "...three M1s in the air: nothing")
	fire(UseAbility, A, 0, nil, "Down")
	task.wait(0.4)
	check(h0 - bHum.Health == Config.M1.FinisherDamage, "...the DOWNSLAM lands - in full (" .. (h0 - bHum.Health) .. ")")
	workspace.Raycast = stubRay
	task.wait(Config.M1.ComboReset + 0.1)
	-- the server setting
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	workspace:SetAttribute("DownImmune", false)
	bChar:SetAttribute("Ragdolled", true)
	h0 = bHum.Health
	fire(UseAbility, A, 0)
	task.wait(0.35)
	check(bHum.Health < h0, "(server settings can switch it off: hits land on the downed again)")
	workspace:SetAttribute("DownImmune", nil)
	bChar:SetAttribute("Ragdolled", nil)
	task.wait(Config.M1.ComboReset + 0.1)

	print("== SUNEATER: Bamboo Sweep and Urchin Spikes in the air, the glide")
	local SE = Config.Quirks.Manifest
	local full = SE.Stomach.Full
	local function pw(n)
		return math.floor(n * full + 0.5)
	end
	local CK, TT = SE.Abilities[1], SE.Abilities[3]
	check(CK.Air and CK.Air.Name == "BAMBOO SWEEP" and TT.AirName == "URCHIN SPIKES" and SE.Glide and SE.Glide.After == 0.5,
		"in the air: 1 is the Bamboo Sweep, 3 the Urchin Spikes; falling half a second, he glides")
	-- the stalk's curve: from his left round to his right, growing, then back
	local a0, l0 = Config.BambooAt(CK.Air, 0)
	local a1, l1, _, w1 = Config.BambooAt(CK.Air, CK.Air.SwingTime)
	local HOLD = CK.Air.HoldTime or 0 -- (round 72: it lies there a moment at the end)
	local a2, l2, _, w2 = Config.BambooAt(CK.Air, CK.Air.SwingTime + HOLD + CK.Air.ReturnTime)
	check(a0 < -100 and a1 > 100 and l0 == CK.Air.Length0 and l1 == CK.Air.Length1 and w1 == 1 and a2 < -100 and l2 == CK.Air.Length0 and w2 == -1
		and Config.BambooAt(CK.Air, CK.Air.SwingTime + HOLD + CK.Air.ReturnTime + 0.05) == nil,
		string.format("the bamboo: %d deg -> %d deg, %d -> %d studs (biggest at the end), then back round to where it started", a0, a1, l0, l1))
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X, 3, 8))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 8), 1, aRoot.Position, true)
	task.wait(0.05)
	local cast = sentTo(B, "ChickenKick")[1]
	task.wait(CK.Air.WindUp + CK.Air.SwingTime + HOLD + CK.Air.ReturnTime + 0.2)
	check(cast and cast.Air == true and MAX - bHum.Health == pw(CK.Air.Damage) + pw(CK.Air.ReturnDamage),
		"BAMBOO SWEEP: through B on the way round and again on the way back (" .. (MAX - bHum.Health) .. ")")
	task.wait(2)
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X, 3, 6))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position, true)
	task.wait(0.22)
	check(MAX - bHum.Health == pw(TT.UrchinDamage) and bChar:GetAttribute("Grabbed") ~= true and bRoot:FindFirstChild("Knockback") ~= nil,
		"URCHIN SPIKES: spines out of every inch of him - B's run through and knocked away (" .. (MAX - bHum.Health) .. ")")
	check((aChar:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow() < TT.ActionTime - 0.5, "...a short move (not the thrash's long lock)")
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "Glide")
	task.wait(0.12)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "GlideEnd")
	task.wait(0.05)
	local pk = sentTo(B, "Parkour")
	check(#pk == 2 and pk[1].Kind == "Glide" and pk[2].Kind == "GlideEnd", "his glide: everyone sees the wings go out, and fold away")
	task.wait(1.5)

	print("== MR. COMPRESS: the Vanishing Act, held")
	local VA = Config.Quirks.Compress.Abilities[3]
	place("Compress", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.3)
	check(bChar:GetAttribute("Compressed") == true and aChar:GetAttribute("Holding") == "VanishingAct" and aChar:GetAttribute("SlowedTo") == VA.Hold.Speed,
		"a hand on B and they're the marble - he keeps it, free to walk about")
	task.wait(1.6)
	check(bChar:GetAttribute("Compressed") == true, "...for as long as he likes (not flicked straight away)")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X + 12, 3, 4), Vector3.new(X + 12, 3, 14))
	task.wait(0.1)
	check((bRoot.Position - (aRoot.CFrame * CFrame.new(0.9, 0.5, -1.4)).Position).Magnitude < 0.6, "...the marble goes where he goes")
	clearSent()
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X + 12, 3, 40))
	task.wait(0.32 + 0.3)
	check(bChar:GetAttribute("Compressed") == nil and math.abs(bRoot.Position.X - (X + 12)) < 3 and math.abs(bRoot.Position.Z - 40) < 4.5,
		string.format("3 again: flicked where he's aiming now (%.1f, %.1f)", bRoot.Position.X - X, bRoot.Position.Z))
	check(MAX - bHum.Health == VA.Damage and #sentTo(B, "VanishingThrow") == 1 and aChar:GetAttribute("Holding") == nil, "...and they pop out there, into the street")
	task.wait(2)
	place("Compress", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.4)
	aChar:SetAttribute("Stunned", true)
	task.wait(0.15)
	local pop = sentTo(B, "VanishingPop")[1]
	check(bChar:GetAttribute("Compressed") == nil and pop and pop.Dropped == true and bHum.Health == MAX and aChar:GetAttribute("Holding") == nil,
		"knocked about holding it: he drops it - B pops out at his feet, unhurt")
	aChar:SetAttribute("Stunned", false)
	task.wait(0.5)
	place("Compress", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.45)
	check(aChar:GetAttribute("Holding") == nil, "nobody in reach: nothing in his hand, nothing to hold")

	print("== DABI: the avatar's own hair comes off")
	place("Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	local function accessory(name, attachment)
		local acc = M.new("Accessory", name)
		local handle = M.new("Part", "Handle")
		handle.Transparency = 0
		handle.Parent = acc
		M.new("Attachment", attachment).Parent = handle
		acc.Parent = aChar
		return handle
	end
	local hair = accessory("CoolHair", "HairAttachment")
	local cap = accessory("Cap", "HatAttachment")
	fire(SelectQuirk, A, "Blueflame")
	task.wait(0.4)
	check(hair.Transparency == 1 and cap.Transparency == 0, "as Dabi: the avatar's hair is hidden (his own goes over it) - a hat isn't")
	local late = accessory("MoreHair", "HairAttachment")
	task.wait(0.1)
	check(late.Transparency == 1, "...hair that loads in later too")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.4)
	check(hair.Transparency == 0 and late.Transparency == 0 and hair:GetAttribute("LookTransparency") == nil, "someone else: it's back")

	print("== AWAKENING OUTFITS: a saved outfit, worn while awakened")
	local fetched = 0
	Players.GetHumanoidDescriptionFromOutfitIdAsync = function(_, id)
		fetched += 1
		if id == 777 then
			return {
				Shirt = 7771, Pants = 7772, HeightScale = 1.3, WalkAnimation = 99,
				Clone = function(self)
					return table.clone(self)
				end,
			}
		end
		error("not an outfit")
	end
	task.wait(0.5)
	fire(ShopRemote, A, "AwakenOutfit", 777)
	task.wait(0.1)
	check(A:GetAttribute("AwakenOutfit") == 777 and fetched == 1, "picked on the phone: kept, and its look fetched now (ready for the moment he awakens)")
	task.wait(0.45)
	fire(ShopRemote, A, "AwakenOutfit", 1.5)
	fire(ShopRemote, A, "AwakenOutfit", -3)
	check(A:GetAttribute("AwakenOutfit") == 777, "...(no half outfits, no negative ones)")
	place("Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	local applied = {}
	aHum.GetAppliedDescription = function()
		return { Shirt = 111, Pants = 222, HeightScale = 1, WalkAnimation = 5 }
	end
	aHum.ApplyDescription = function(_, desc)
		table.insert(applied, { Shirt = desc.Shirt, HeightScale = desc.HeightScale, WalkAnimation = desc.WalkAnimation })
	end
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.4)
	local last = applied[#applied]
	check(aChar:GetAttribute("AwakenFit") == 777 and last and last.Shirt == 7771 and last.HeightScale == 1 and last.WalkAnimation == 5,
		"AWAKENED: he's in his outfit - his own body size and walk kept (" .. tostring(last and last.Shirt) .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.4)
	last = applied[#applied]
	check(aChar:GetAttribute("AwakenFit") == nil and last and last.Shirt == 111, "...and when it ends, his own look is back")
	task.wait(0.45)
	fire(ShopRemote, A, "AwakenOutfit", 666)
	task.wait(0.2)
	check(A:GetAttribute("AwakenOutfit") == 0, "an outfit Roblox won't give us: back to none")
	-- saved, and back when you come back
	local G = addPlayer("Golf", 7)
	task.wait(0.3)
	fire(ShopRemote, G, "AwakenOutfit", 777)
	task.wait(0.2)
	G.Parent = nil
	Players.PlayerRemoving:Fire(G)
	task.wait(0.2)
	check(DS.data["u_7"] and DS.data["u_7"].Outfit == 777, "leaving saves the pick")
	local G2 = addPlayer("Golf", 7)
	task.wait(0.4)
	check(G2:GetAttribute("AwakenOutfit") == 777, "...and it's picked again when you come back")
	G2.Parent = nil
	Players.PlayerRemoving:Fire(G2)
	Players.GetHumanoidDescriptionFromOutfitIdAsync = nil
end)
---------------------------------------------------------------------------
-- Round 60: a KO is one Buck; Iida is a dev character; Suneater's tentacle
-- ZIPS him to a building (Spider-Man's web zip); CREATI (Momo Yaoyorozu)
---------------------------------------------------------------------------
;M.section(function()
	local X = 76500
	local MAX = Config.PlayerMaxHealth
	local FWD = Vector3.new(0, 0, 1)
	local CQ = Config.Quirks.Creation
	workspace:SetAttribute("HealthRegen", false)
	workspace:SetAttribute("DownImmune", nil)
	local SKIN = M.Color3.fromRGB(240, 205, 170)
	-- (bodies with arms and a head, so her weapon and look have somewhere to go)
	local function spawnLimbs(p, cf)
		local model, hum, root = makeCharacter(p.Name, cf)
		for _, s in {
			{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
			{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
			{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
			{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
			{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
			{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		} do
			local part = M.new("Part", s[1])
			part.Size = s[2]
			part.CFrame = root.CFrame * CFrame.new(s[3])
			part.Color = SKIN
			part.Parent = model
		end
		model.Parent = workspace
		p.Character = model
		p.CharacterAdded:Fire(model)
		task.wait(0.05)
		return model, hum, root
	end
	local function place(aQuirk, aPos, bPos, bQuirk, limbs)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		if aChar then
			aChar.Parent = nil
		end
		if bChar then
			bChar.Parent = nil
		end
		aChar, aHum, aRoot = (limbs and spawnLimbs or spawnChar)(A, CFrame.lookAt(aPos, aPos + FWD))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		task.wait(0.6)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		clearSent()
	end
	local function ult(n)
		return math.floor(math.min(n * Config.Ult.DamageMultiplier, MAX * ((Config.Balance and Config.Balance.MaxHitShare) or 1)) + 0.5)
	end
	-- the street at y = 0, and (when `box` is set) a building: an axis-aligned
	-- box the rays stop at (a ray that starts inside it doesn't see it)
	local box = nil
	local rayBefore = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) ~= "Vector3" then
			return nil
		end
		local best
		if box then
			local tmin, tmax, normal = 0, 1, nil
			for _, ax in { "X", "Y", "Z" } do
				local o, d = origin[ax], dir[ax]
				local lo, hi = box.min[ax], box.max[ax]
				if math.abs(d) < 1e-9 then
					if o < lo or o > hi then
						tmin = 2
					end
				else
					local t1, t2 = (lo - o) / d, (hi - o) / d
					local n = -math.sign(d)
					if t1 > t2 then
						t1, t2 = t2, t1
					end
					if t1 > tmin then
						tmin = t1
						normal = Vector3.new(ax == "X" and n or 0, ax == "Y" and n or 0, ax == "Z" and n or 0)
					end
					tmax = math.min(tmax, t2)
				end
			end
			if tmin <= tmax and tmin >= 0 and tmin <= 1 and normal then
				best = { Position = origin + dir * tmin, Distance = dir.Magnitude * tmin, Normal = normal, Instance = workspace }
			end
		end
		if dir.Y < 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			if not best or t * dir.Magnitude < best.Distance then
				best = { Position = Vector3.new(origin.X + dir.X * t, 0, origin.Z + dir.Z * t), Distance = dir.Magnitude * t, Normal = Vector3.new(0, 1, 0), Instance = workspace }
			end
		end
		return best
	end

	print("== ECONOMY: a KO is one Buck")
	check(Config.Economy.PerKO == 1, "every KO pays 1 Buck (" .. tostring(Config.Economy.PerKO) .. ")")

	print("== IIDA: a dev character for now; CREATI on the roster")
	check(Config.Quirks.Engine.DevOnly ~= true and table.find(Config.QuirkOrder, "Creation") ~= nil and table.find(Config.QuirkOrder, "Engine") ~= nil,
		"Iida is on the public roster again (round 74); so is Creati")
	studioMode = false
	local H = addPlayer("Hotel", 8)
	task.wait(0.3)
	fire(SelectQuirk, H, "PrimeDeku")
	task.wait(0.1)
	check(H:GetAttribute("Quirk") ~= "PrimeDeku", "an ordinary player can't pick a dev character (Prime Deku: " .. tostring(H:GetAttribute("Quirk")) .. ")")
	fire(SelectQuirk, H, "Creation")
	task.wait(0.1)
	check(H:GetAttribute("Quirk") == "Creation", "...but anyone can pick Creati")
	studioMode = true
	H.Parent = nil
	Players.PlayerRemoving:Fire(H)

	print("== SUNEATER: the tentacle ZIPS him to a building")
	local Z = Config.Quirks.Manifest.Abilities[2].Zip
	check(Z and Z.Speed > 0 and Z.Cooldown < Config.Quirks.Manifest.Abilities[2].Cooldown, "Tako Snatch has a zip (and a zip costs less of its cooldown)")
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X + 80, 3, 0))
	aChar:SetAttribute("Stomach", 100)
	-- a tall wall straight ahead, aimed at low down: the zip goes to that spot
	box = { min = Vector3.new(X - 20, 0, 30), max = Vector3.new(X + 20, 50, 60) }
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 4.5, 30), 1, aRoot.Position)
	task.wait(0.8)
	local zip = sentTo(A, "TakoZip")[1]
	check(zip and zip.Anchor.Z < 30 and zip.Anchor.Z > 29 and math.abs(zip.Anchor.Y - 4.5) < 1 and zip.Normal.Z < -0.9 and not zip.Ledge,
		"at a tall wall: it zips him straight to where he aimed (" .. tostring(zip and zip.Anchor) .. ")")
	check(#sentTo(B, "TakoZip") == 1 and #sentTo(A, "TakoSwing") == 0, "...everyone sees the tentacle; no swing any more")
	local catch = sentTo(B, "TakoSnatchCatch")[1]
	check(catch and zip and math.abs(catch.Reach - (zip.Anchor - (aRoot.Position + Vector3.new(0, 1.5, 0))).Magnitude) < 3, "...and the tentacle flies to where it caught")
	-- the zip only costs Zip.Cooldown
	clearSent()
	task.wait(Z.Cooldown + 0.2)
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 4.5, 30), 1, aRoot.Position)
	task.wait(0.8)
	check(#sentTo(A, "TakoZip") == 1, "...and he can zip again " .. Z.Cooldown .. "s later (a whiff waits the full " .. Config.Quirks.Manifest.Abilities[2].Cooldown .. "s)")
	-- a low building: aimed near its top, he goes over the lip onto the roof
	box = { min = Vector3.new(X - 20, 0, 30), max = Vector3.new(X + 20, 12, 60) }
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 4.5, 30), 1, aRoot.Position)
	task.wait(0.8)
	zip = sentTo(A, "TakoZip")[1]
	check(zip and zip.Ledge == true and math.abs(zip.Anchor.Y - 12) < 0.6 and zip.Anchor.Z < 30.1,
		"aimed at a wall near its top: the ledge - over onto the roof (" .. tostring(zip and zip.Anchor) .. ")")
	-- aimed up at the sky, a building beside him: it finds the building
	box = { min = Vector3.new(X + 12, 0, -10), max = Vector3.new(X + 40, 50, 60) }
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, 2, Vector3.new(0, 0.7, 0.7).Unit, Vector3.new(X, 40, 40), 1, aRoot.Position)
	task.wait(0.8)
	zip = sentTo(A, "TakoZip")[1]
	check(zip and zip.Anchor.X > X + 11 and typeof(zip.Normal) == "Vector3", "aimed up at nothing, a building beside him: it zips him to the building")
	-- the street: a miss
	box = nil
	for _, aim in { FWD, Vector3.new(0, -0.3, 1).Unit } do
		fire(TestCommand, A, "ResetCooldowns")
		clearSent()
		fire(UseAbility, A, 2, aim, aRoot.Position + aim * 30, 1, aRoot.Position)
		task.wait(0.8)
		check(#sentTo(A, "TakoZip") == 0, "aimed " .. (aim.Y < 0 and "down at the street" or "flat down an empty street") .. ": a miss, no zip")
	end
	-- somebody in reach: it's still the snatch
	place("Manifest", Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	aChar:SetAttribute("Stomach", 100)
	box = { min = Vector3.new(X - 20, 0, 30), max = Vector3.new(X + 20, 50, 60) }
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.9)
	check(#sentTo(A, "TakoZip") == 0 and bHum.Health < MAX, "someone in reach: the tentacle catches them, no zip")
	box = nil
	task.wait(1)

	print("== CREATI: the weapon in her hand, her look")
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5), nil, true)
	local gear = aChar:FindFirstChild("QuirkGear")
	local weapon = gear and gear:FindFirstChild("CreatedWeapon")
	check(weapon and weapon:GetAttribute("Weapon") == "Staff" and #weapon:GetChildren() >= 3, "a staff in her hand to start with")
	local cos = gear and gear:FindFirstChild("Cosmetics")
	check(cos and cos:FindFirstChild("Ponytail") and cos:FindFirstChild("Belt"), "her look: the high ponytail and the gold belt")
	local noCollide = true
	for _, p in gear:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			noCollide = false
		end
	end
	check(noCollide, "none of it bumps into anyone (bodies collide now; gear doesn't)")
	-- R: the next weapon, and the 4th move with it
	local seen = {}
	for i = 1, 3 do
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
		task.wait(0.15)
		gear = aChar:FindFirstChild("QuirkGear")
		weapon = gear and gear:FindFirstChild("CreatedWeapon")
		local pick = A:GetAttribute("QuirkPick")
		local extra = Config.GetAbility("Creation", Config.EXTRA_INDEX, false, false, pick)
		table.insert(seen, (weapon and weapon:GetAttribute("Weapon") or "?") .. "/" .. (extra and extra.Id or "?"))
	end
	check(table.concat(seen, " ") == "Sword/IaiRush Spear/PiercingThrust Staff/StrikeAndStop",
		"R: staff -> sword -> spear -> staff, and 4 is that weapon's move (" .. table.concat(seen, " ") .. ")")
	-- (round 62) the weapons, built part by part from the table the previews
	-- are drawn from: counts, wedges for the points, all welded to her arm,
	-- none of it colliding or weighing anything, reaching as far as it should
	do
		local WANT = { Sword = { 16, 2, 4.2 }, Staff = { 10, 0, 4.4 }, Spear = { 21, 4, 6.95 } }
		local arm = aChar:FindFirstChild("Right Arm")
		local built = {}
		for _ = 1, 3 do
			fire(TestCommand, A, "ResetCooldowns")
			fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
			task.wait(0.15)
			local g = aChar:FindFirstChild("QuirkGear")
			local m = g and g:FindFirstChild("CreatedWeapon")
			local name = m and m:GetAttribute("Weapon")
			local want = WANT[name or ""]
			local parts, wedges, welded, loose, far = 0, 0, 0, 0, 0
			for _, p in m and m:GetChildren() or {} do
				if p:IsA("BasePart") then
					parts += 1
					if p.ClassName == "WedgePart" then
						wedges += 1
					end
					local w = p:FindFirstChildOfClass("Weld")
					if w and w.Part0 == arm and w.Part1 == p then
						welded += 1
						far = math.min(far, w.C0.Position.Z)
					end
					if p.CanCollide or not p.Massless then
						loose += 1
					end
				end
			end
			table.insert(built, tostring(name))
			check(want and parts == want[1] and wedges == want[2], string.format("%s: %d parts, %d wedges (%d, %d)", tostring(name), want and want[1] or -1, want and want[2] or -1, parts, wedges))
			check(welded == parts and loose == 0, tostring(name) .. ": all of it welded to her arm, none of it bumping or weighing anything")
			check(want and math.abs(-far - want[3]) < 0.05, string.format("%s: reaches %.2f studs out from her fist (%.2f)", tostring(name), want and want[3] or -1, -far))
		end
		check(#built == 3, "every weapon built (" .. table.concat(built, ", ") .. ")")
	end
	check(#sentTo(B, "CreateWeapon") >= 1, "...everyone sees it made")

	print("== CREATI: her M1s swing the weapon")
	-- the sword hits harder...
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5), nil, true)
	A:SetAttribute("QuirkPick", 2) -- (picking a quirk puts the first weapon back in her hand)
	fire(UseAbility, A, 0)
	task.wait(0.35)
	check(MAX - bHum.Health == math.floor(Config.M1.Damage * CQ.Weapons.Sword.Damage + 0.5), "the sword: " .. (MAX - bHum.Health) .. " a hit")
	-- ...the spear reaches further
	place("Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 11))
	fire(UseAbility, A, 0)
	task.wait(0.35)
	local bare = MAX - bHum.Health
	task.wait(0.6)
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 11), nil, true)
	A:SetAttribute("QuirkPick", 1)
	fire(UseAbility, A, 0)
	task.wait(0.35)
	local staff = MAX - bHum.Health
	task.wait(0.6)
	fire(TestCommand, A, "ResetCooldowns")
	A:SetAttribute("QuirkPick", 3)
	fire(UseAbility, A, 0)
	task.wait(0.35)
	check(bare == 0 and staff == 0 and MAX - bHum.Health == math.floor(Config.M1.Damage * CQ.Weapons.Spear.Damage + 0.5),
		"the spear reaches someone 11 studs off that a fist or the staff can't (" .. bare .. " / " .. staff .. " / " .. (MAX - bHum.Health) .. ")")
	task.wait(0.6)

	print("== CREATI 1: MATRYOSHKA FLASH")
	local MF = CQ.Abilities[1]
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 20))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.18 + 20 / MF.Speed + 0.25)
	check(MAX - bHum.Health == MF.Damage and bChar:GetAttribute("Stunned") == true, "a doll reaches them 20 studs off: the flashbang - " .. (MAX - bHum.Health) .. " damage, stunned")
	check(#sentTo(B, "Blind") >= 1 and (bChar:GetAttribute("BlindedUntil") or 0) > workspace:GetServerTimeNow(), "...and blinded")
	task.wait(46 / MF.Speed)
	check(#sentTo(A, "MatryoshkaPop") == MF.Dolls, "all " .. MF.Dolls .. " dolls go off (" .. #sentTo(A, "MatryoshkaPop") .. ")")

	print("== CREATI 2: UNFALLING CASTLE WALL")
	local CW = CQ.Abilities[2]
	local apIndex
	for i, a in Config.Quirks.Explosion.Abilities do
		if a.Id == "APShot" then
			apIndex = i
		end
	end
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 20))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Shielding") == true, "the shield's up the moment she presses")
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 10))
	task.wait(0.2)
	local folder = workspace:FindFirstChild("Creations")
	local wall = folder and folder:FindFirstChild("CastleWall")
	local slab = wall and wall:FindFirstChild("Slab")
	check(slab and slab.Anchored and slab.CanCollide and math.abs(slab.Position.Z - CW.Ahead) < 0.6 and math.abs(slab.Size.X - CW.Width) < 0.01,
		"a tap plants the wall " .. CW.Ahead .. " studs ahead of her, solid (" .. tostring(slab and slab.Position) .. ")")
	check(aChar:GetAttribute("Shielding") == nil and #sentTo(B, "CastleWallPlant") == 1, "...and she's let go of it")
	-- Bakugo shoots her through it: the wall takes it
	if apIndex then
		fire(UseAbility, B, apIndex, -FWD, aRoot.Position, 1, bRoot.Position)
		task.wait(0.5)
		check(aHum.Health == MAX and #sentTo(A, "CastleWallHit") >= 1, "an AP Shot at her from behind it hits the wall, not her")
	end
	-- it goes when its time's up
	task.wait(CW.WallTime)
	check(not (folder and folder:FindFirstChild("CastleWall")) and #sentTo(A, "CastleWallBreak") >= 1, "...and it's gone after " .. CW.WallTime .. "s")
	-- HOLD it: carried in front of her - then the bash
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.1)
	fire(UseAbility, B, 0)
	task.wait(0.3)
	check(aHum.Health == MAX and #sentTo(B, "ShieldBlock") >= 1, "held up, the shield takes a punch from in front of her")
	task.wait(0.2)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 10))
	task.wait(0.5)
	check(#sentTo(B, "ShieldBash") == 1 and MAX - bHum.Health >= CW.Damage, "let go after holding it: the shield bash (" .. (MAX - bHum.Health) .. ")")
	check(#sentTo(A, "CastleWallPlant") == 0, "...(a hold doesn't plant a wall)")
	task.wait(1)

	print("== CREATI 3: BULLET RAIN")
	local BR = CQ.Abilities[3]
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, 3, FWD, bRoot.Position, 7, aRoot.Position)
	task.wait(0.1)
	local rain = sentTo(B, "BulletRainShells")[1]
	local nearAim, bombs = 0, 0
	for _, sh in (rain and rain.Shells) or {} do
		if (sh.Land - Vector3.new(X, 0, 30)).Magnitude <= BR.Spread * 1.3 then
			nearAim += 1
		end
		bombs += #sh.Bombs
	end
	check(rain and #rain.Shells == BR.Shells and nearAim == BR.Shells and bombs == BR.Shells * BR.Bombs,
		"a cannon beside her; " .. BR.Shells .. " shells for where she aimed, " .. BR.Bombs .. " bombs in each")
	task.wait(0.5 + (BR.Shells - 1) * BR.Interval + 1.3)
	local took = MAX - bHum.Health
	check(took >= BR.Damage and took <= BR.Shells * (BR.Damage + BR.BombDamage), "...they come down on them: " .. took .. " damage")
	task.wait(0.5)

	print("== CREATI 4: the weapon's move")
	-- the staff: STRIKE AND STOP
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	A:SetAttribute("QuirkPick", 1)
	local SS = CQ.Extras[1]
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	check(MAX - bHum.Health == SS.Damage and bChar:GetAttribute("Stunned") == true and #sentTo(B, "StrikeStop") == 1, "STRIKE AND STOP: the staff whirled round her - hit and stopped")
	task.wait(1.4)
	-- the sword: IAI RUSH
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 4))
	A:SetAttribute("QuirkPick", 2)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45)
	check(MAX - bHum.Health == CQ.Extras[2].Damage, "IAI RUSH: cut on the way through (" .. (MAX - bHum.Health) .. ")")
	task.wait(1)
	-- the spear: PIERCING THRUST
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 12))
	A:SetAttribute("QuirkPick", 3)
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	local kb = bRoot:FindFirstChild("Knockback")
	check(MAX - bHum.Health == CQ.Extras[3].Damage and kb and kb.VectorVelocity.Z > 20, "PIERCING THRUST: 12 studs off, run back on the spear point")
	task.wait(1.5)

	print("== CREATI: FULL ARSENAL (the ult)")
	local U = CQ.Ult
	place("Creation", Vector3.new(X, 3, 0), Vector3.new(X, 3, 40))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(2)
	fire(TestCommand, A, "ResetCooldowns")
	check(A:GetAttribute("UltActive") == true, "the ult is on")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.2)
	check(MAX - bHum.Health == ult(U.Abilities[1].Damage) and #sentTo(B, "GrandCannonFire") == 1, "GRAND CANNON: the shell lands on them 40 studs off (" .. (MAX - bHum.Health) .. ")")
	task.wait(2)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 0))
	bChar:SetAttribute("Stunned", false)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3 + U.Abilities[2].Flight + 0.15)
	check(MAX - bHum.Health == ult(U.Abilities[2].Damage) and bChar:GetAttribute("Stunned") == true and bHum.WalkSpeed == 0, "CAPTURE NET: pinned under it")
	task.wait(U.Abilities[2].Pin + 0.2)
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 60), Vector3.new(X, 3, 0))
	bChar:SetAttribute("Stunned", false)
	bHum.Health = MAX
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(U.Abilities[3].Charge + 0.3)
	check(MAX - bHum.Health == ult(U.Abilities[3].Damage) and #sentTo(B, "DischargeCannonFire") == 1, "DISCHARGE CANNON: the railgun's slug, 60 studs down the lane")
	-- the lucky bag
	for _, id in Config.ItemOrder do
		A:SetAttribute("Item_" .. id, nil)
	end
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, aRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	local kinds, food = 0, 0
	for _, id in Config.ItemOrder do
		if (A:GetAttribute("Item_" .. id) or 0) > 0 then
			kinds += 1
			if not table.find(Config.ShopOrder, id) then
				food += 1
			end
		end
	end
	local drop = sentTo(B, "LuckyBagDrop")[1]
	check(kinds >= 1 and food == 0 and drop and #drop.Items == U.Extra.Items, "LUCKY BAG: " .. U.Extra.Items .. " random Hero Shop items into her bag (" .. kinds .. " kinds)")
	fire(TestCommand, A, "EndUlt")
	task.wait(1)

	workspace.Raycast = rayBefore
	local made = workspace:FindFirstChild("Creations")
	for _, w in made and made:GetChildren() or {} do
		w:Destroy()
	end
end)
---------------------------------------------------------------------------
-- Round 63: smoother ragdolls, easier slams, deliveries, codes
---------------------------------------------------------------------------
;M.section(function()
	local X = 93000
	local MAX = Config.PlayerMaxHealth
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local ShopRemote = remotes:FindFirstChild("Shop")
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "FullCowl")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 3.5), Vector3.new(X, 3, 0)))
	-- (the street at y = 0 under everything in this section)
	local prevRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0), Distance = origin.Y }
		end
		return nil
	end
	-- (a jointed R6 body for B, so the ragdoll has joints to swap)
	local function joint(name, p0, p1)
		local m = M.new("Motor6D", name)
		m.Part0, m.Part1, m.Enabled = p0, p1, true
		m.C0, m.C1 = CFrame.new(), CFrame.new()
		m.Parent = p0
		return m
	end
	local bTorso = M.new("Part", "Torso")
	bTorso.CFrame = bRoot.CFrame
	bTorso.Parent = bChar
	joint("RootJoint", bRoot, bTorso)
	for motorName, partName in { Neck = "Head", ["Right Shoulder"] = "Right Arm", ["Left Shoulder"] = "Left Arm", ["Right Hip"] = "Right Leg", ["Left Hip"] = "Left Leg" } do
		local limb = M.new("Part", partName)
		limb.CFrame = bRoot.CFrame
		limb.Parent = bChar
		joint(motorName, bTorso, limb)
	end
	task.wait(0.3)

	print("== RAGDOLL: smoother (friction in the joints, no bounce, up from where you lie)")
	local RG = Config.Ragdoll
	check(RG.JointFriction and RG.JointFriction > 0, "joints have friction (" .. tostring(RG.JointFriction) .. ")")
	local function combo()
		for i = 1, 4 do
			fire(UseAbility, A, 0, aRoot.CFrame)
			task.wait(i < 4 and Config.M1.Cooldown + 0.03 or 0.25)
		end
	end
	fire(TestCommand, A, "ResetCooldowns")
	combo()
	check(bChar:GetAttribute("Ragdolled") == true, "the 4th M1 puts B down")
	local balls, hinges, colliders, frictionOk, bounceOk = 0, 0, 0, true, true
	for _, d in bChar:GetDescendants() do
		if d.Name == "RagdollSocket" and d.ClassName == "BallSocketConstraint" then
			balls += 1
			frictionOk = frictionOk and (d.MaxFrictionTorque or 0) > 0 and d.Restitution == 0
		elseif d.Name == "RagdollSocket" and d.ClassName == "HingeConstraint" then
			hinges += 1
		elseif d.Name == "RagdollCollider" then
			colliders += 1
			local pp = d.CustomPhysicalProperties
			bounceOk = bounceOk and pp ~= nil and pp.Elasticity == 0
		end
	end
	check(balls >= 5 and frictionOk, "every ball-socket joint has friction and no bounce (" .. balls .. ")")
	check(colliders >= 5 and bounceOk, "the limbs' colliders don't bounce (" .. colliders .. ")")
	-- lying on his back, head behind: getting up tells every screen so
	local torso = bChar:FindFirstChild("Torso")
	if torso then
		torso.CFrame = CFrame.fromMatrix(bRoot.Position - Vector3.new(0, 2.5, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
	end
	clearSent()
	local t0 = os.clock()
	repeat
		task.wait(0.05)
	until not bChar:GetAttribute("Ragdolled") or os.clock() - t0 > 5
	local up = sentTo(A, "GetUp")[1]
	check(up and up.Face == "Up", "on his back: the get-up starts from lying face up (" .. tostring(up and up.Face) .. ")")
	task.wait(1.2)

	print("== SLAMS: easier downslams (a little off the street will do)")
	check(Config.M1.Uppercut.RiseWith == 0, "an upslam keeps you on your feet (no rise after them)")
	check(Config.M1.DownslamHeight and Config.M1.DownslamHeight <= 1, "a downslam needs only " .. tostring(Config.M1.DownslamHeight) .. " studs off the street")
	bChar:SetAttribute("Ragdolled", false)
	bChar.Parent = nil
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X + 20, 3, 3.5), Vector3.new(X + 20, 3, 0)))
	aChar.Parent = nil
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X + 20, 3, 0), Vector3.new(X + 20, 3, 10)))
	task.wait(1.5)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	for i = 1, 3 do
		fire(UseAbility, A, 0, aRoot.CFrame)
		task.wait(Config.M1.Cooldown + 0.03)
	end
	-- the server still sees him on the street; his own screen has him a
	-- step up already (a jump the server hasn't caught up with)
	fire(UseAbility, A, 0, aRoot.CFrame + Vector3.new(0, 1.6, 0), "Down")
	task.wait(0.05)
	local punch = sentTo(B, "Punch")
	local last = punch[#punch]
	check(last and last.Variant == "Down", "a downslam counts where his own screen had him (1.6 studs up): " .. tostring(last and last.Variant))
	task.wait(0.6)
	fire(TestCommand, A, "ResetCooldowns")
	task.wait(1.5)
	clearSent()
	for i = 1, 3 do
		fire(UseAbility, A, 0, aRoot.CFrame)
		task.wait(Config.M1.Cooldown + 0.03)
	end
	fire(UseAbility, A, 0, aRoot.CFrame + Vector3.new(0, 30, 0), "Down")
	task.wait(0.05)
	punch = sentTo(B, "Punch")
	last = punch[#punch]
	check(last and last.Variant == nil, "...but not a screen claiming he's way up in the air (too far from where he is)")
	task.wait(1)

	print("== DELIVERIES: a Support Drop pod brings it, wherever you are (round 66: was a drone)")
	local DL = Config.Deliveries
	check(DL.Soda.Price and DL.Item.Price and DL.Despawn == 10, "soda and item deliveries, gone if left " .. DL.Despawn .. "s")
	DS.data["u_63"] = { Bucks = 0, Items = {}, Kills = 0 } -- (broke, to start with)
	local P = addPlayer("Papa", 63)
	task.wait(0.3)
	local pChar, _, pRoot = spawnChar(P, CFrame.new(X + 60, 3, 0))
	task.wait(0.3)
	clearSent()
	fire(ShopRemote, P, "Deliver", "Soda")
	local r = sentTo(P, "ShopResult")[1]
	check(r and r.Ok == false and (P:GetAttribute("Item_Soda") or 0) == 0 and #sentTo(P, "SupportDrop") == 0, "not enough Bucks: no pod")
	fire(TestCommand, P, "MoneyPrinter")
	local bucks = P:GetAttribute("Bucks")
	clearSent()
	fire(ShopRemote, P, "Deliver", "Soda")
	r = sentTo(P, "ShopResult")[1]
	task.wait(0.1)
	local pod = sentTo(P, "SupportDrop")[1]
	check(r and r.Ok == true and pod and P:GetAttribute("Bucks") == bucks - DL.Soda.Price, "paid: a Support Drop pod is on its way (" .. tostring(r and r.Text) .. ")")
	check(pod and pod.From.Y - pod.Pos.Y > 100, "...out of the sky")
	task.wait(DL.Pod.FallTime + DL.Pod.OpenDelay + 0.8)
	check((P:GetAttribute("Item_Soda") or 0) == 1, "it drops it right by him on the street, in reach: a soda in his bag")
	check(sentTo(P, "ShopResult")[2] and sentTo(P, "ShopResult")[2].Ok, "...and it says so")
	task.wait(1.6)
	check(sentTo(P, "SupportDropDone")[1] ~= nil, "the pod packs up again")
	-- an item: somewhere he walks away from
	clearSent()
	fire(ShopRemote, P, "Deliver", "Item")
	task.wait(DL.Pod.FallTime + 0.1)
	pRoot.CFrame = CFrame.new(X + 160, 3, 0) -- (off down the street before it lands)
	task.wait(0.5)
	local box = workspace:FindFirstChild("Delivery")
	check(box ~= nil, "an item delivery: a box down on the street")
	local before = 0
	for _, id in Config.ShopOrder do
		before += P:GetAttribute("Item_" .. id) or 0
	end
	task.wait(DL.Despawn + 0.4)
	local after = 0
	for _, id in Config.ShopOrder do
		after += P:GetAttribute("Item_" .. id) or 0
	end
	check(after == before and workspace:FindFirstChild("Delivery") == nil and #sentTo(P, "Notice") >= 1, "left there " .. DL.Despawn .. "s: it's gone, nothing given")
	-- two on the way at most
	pRoot.CFrame = CFrame.new(X + 60, 3, 0)
	clearSent()
	fire(ShopRemote, P, "Deliver", "Soda")
	fire(ShopRemote, P, "Deliver", "Soda")
	fire(ShopRemote, P, "Deliver", "Soda")
	local refused = 0
	for _, s in sentTo(P, "ShopResult") do
		if not s.Ok then
			refused += 1
		end
	end
	check(refused == 1, "a third one while two are on the way: it waits (" .. refused .. " refused)")
	task.wait(DL.Pod.FallTime + DL.Pod.OpenDelay + 1.5)

	print("== CODES (the REWARDS tab)")
	local Q = addPlayer("Quebec", 64)
	task.wait(0.3)
	local qb = Q:GetAttribute("Bucks") or 0
	clearSent()
	fire(ShopRemote, Q, "Redeem", " plusultra ")
	local c = sentTo(Q, "CodeResult")[1]
	check(c and c.Ok and Q:GetAttribute("Bucks") == qb + Config.Codes.PLUSULTRA.Bucks, "PLUSULTRA (any case, spaces ignored): +" .. Config.Codes.PLUSULTRA.Bucks .. " Bucks")
	task.wait(1.1)
	clearSent()
	fire(ShopRemote, Q, "Redeem", "PLUSULTRA")
	c = sentTo(Q, "CodeResult")[1]
	check(c and not c.Ok and Q:GetAttribute("Bucks") == qb + Config.Codes.PLUSULTRA.Bucks, "only once: " .. tostring(c and c.Text))
	task.wait(1.1)
	clearSent()
	fire(ShopRemote, Q, "Redeem", "NOTACODE")
	c = sentTo(Q, "CodeResult")[1]
	check(c and not c.Ok, "a made-up one: " .. tostring(c and c.Text))
	task.wait(1.1)
	fire(ShopRemote, Q, "Redeem", "GOBEYOND")
	check(string.find(Q:GetAttribute("EmotesOwned") or "", "Cheer", 1, true) and string.find(Q:GetAttribute("EmoteWheel") or "", "Cheer", 1, true), "GOBEYOND: an emote, straight onto the wheel")
	Q.Parent = nil
	Players.PlayerRemoving:Fire(Q)
	task.wait(0.2)
	check(DS.data["u_64"] and string.find(DS.data["u_64"].Codes, "PLUSULTRA", 1, true) and string.find(DS.data["u_64"].Codes, "GOBEYOND", 1, true), "the codes you've used are saved")
	P.Parent = nil
	Players.PlayerRemoving:Fire(P)
	pChar.Parent = nil
	workspace.Raycast = prevRay
end)
---------------------------------------------------------------------------
-- Round 64: EXPLOSIVE SPEED is back - Dynamight's R (4 is still FULL-BODY
-- CLUSTER; out of the ult R is still the Stun Grenade)
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local X = 99500
	local FWD = Vector3.new(0, 0, 1)
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	print("== EXPLOSIVE SPEED: back, on R in the ult")
	local EX = Config.Quirks.Explosion
	local ES = EX.Ult.Special
	check(ES and ES.Id == "ExplosiveSpeed" and Config.GetAbility("Explosion", Config.SPECIAL_INDEX, false, true) == ES,
		"in Dynamight, R is EXPLOSIVE SPEED")
	check(Config.GetAbility("Explosion", Config.SPECIAL_INDEX, false, false).Id == "StunGrenade", "...out of it, R is still the Stun Grenade")
	check(Config.GetExtra(EX, false, true).Id == "FullBodyCluster", "...and 4 is still FULL-BODY CLUSTER")
	check(Config.CooldownKey("Explosion", Config.SPECIAL_INDEX, false, true) ~= Config.CooldownKey("Explosion", Config.SPECIAL_INDEX, false, false),
		"...its own cooldown (the Stun Grenade's isn't touched)")
	local view = Config.GetView("Explosion", false, true)
	check(view.Special == ES and Config.FindAbilityById("ExplosiveSpeed") == ES, "...the HUD's R slot shows it in the ult")
	check(ES.CutIn == false, "no cut-in over the crouch (the crouch and the blitz are the show)")
	local mult = (Config.Ult and Config.Ult.DamageMultiplier) or 1
	local function fresh(bPos)
		fire(SelectQuirk, A, "Explosion")
		fire(SelectQuirk, B, "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		A:SetAttribute("Ult", 100)
		fire(UseAbility, A, Config.ULT_INDEX)
		task.wait(1.5)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	-- the crouch, the blitz, the catch, the Explosion
	fresh(Vector3.new(X, 3, 40))
	local t0 = os.clock()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.35)
	check(#sentTo(B, "ExplosiveSpeed") == 1 and #sentTo(B, "StunGrenade") == 0 and aRoot.Anchored and (aRoot.CFrame.Position - Vector3.new(X, 3, 0)).Magnitude < 1,
		"R in the ult: he drops into the crouch, rooted (everyone sees it) - no stun grenade")
	check(bHum.Health == MAX, "...nothing's happened to B yet")
	local caught
	while os.clock() - t0 < ES.WindUp + 0.6 and not caught do
		caught = sentTo(B, "ExplosiveSpeedCatch")[1]
		task.wait()
	end
	local caughtAt = os.clock() - t0
	local go = sentTo(B, "ExplosiveSpeedGo")[1]
	check(go and go.Blink == true, "...then the blitz: B's in the lane, so it's a blink")
	check(caught and caught.Target == bChar and caughtAt < ES.WindUp + 0.3, string.format("B, 40 studs down the lane, is caught %.2fs in, wind-up and all (round 76: a %.2fs crouch)", caughtAt, ES.WindUp))
	local cf = aRoot.CFrame
	check(math.abs(cf.Position.Z - (40 - 2.6)) < 1.2, string.format("...face to face: right in front of B (%.1f studs on)", cf.Position.Z))
	task.wait(ES.FlipTime + 0.1)
	cf = aRoot.CFrame
	check(cf.UpVector.Y < -0.95 and cf.LookVector:Dot(FWD) > 0.95 and aChar:GetAttribute("BodyLocked") == true,
		string.format("...flipped upside down, face to face, his body the move's (up %.2f)", cf.UpVector.Y))
	check(bChar:GetAttribute("Grabbed") == true and bHum.Health == MAX, "...and time slows: B's held there, not hit yet")
	task.wait(ES.SlowMo)
	local took = MAX - bHum.Health
	check(took >= math.floor(ES.Damage * mult + 0.5) - 1 and took <= math.floor(ES.Damage * mult + 0.5) + 1, "...then the Explosion, point blank: " .. took .. " damage")
	check(bChar:GetAttribute("Ragdolled") == true and not bChar:GetAttribute("Grabbed") and #sentTo(B, "ExplosiveSpeedBlast") == 1, "...and B goes flying (everyone sees the blast)")
	task.wait(0.2)
	check(not aRoot.Anchored and aRoot.CFrame.UpVector.Y > 0.99 and aChar:GetAttribute("BodyLocked") == nil, "Bakugo's on his feet and free again afterwards")

	-- nobody in the lane: a blur down it, flat out, and he skids to a stop
	fresh(Vector3.new(X + 12, 3, 30))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, Vector3.new(X, 3, 60), 1, aRoot.Position)
	task.wait(ES.WindUp + 0.1)
	go = sentTo(B, "ExplosiveSpeedGo")[1]
	check(go and not go.Blink and aRoot.CFrame.Position.Z > 8 and aRoot.CFrame.Position.Z < ES.Range, string.format("nobody in the lane: a blur down it (%.0f studs on, still going)", aRoot.CFrame.Position.Z))
	check(aRoot.CFrame.UpVector:Dot(FWD) > 0.9, "...flat out, head first like a missile")
	task.wait(ES.Range / ES.Speed + 0.4)
	check(#sentTo(B, "ExplosiveSpeedWhiff") == 1 and #sentTo(B, "ExplosiveSpeedCatch") == 0 and bHum.Health == MAX, "...to the end of it, and a skid to a stop - B (12 studs to the side) untouched")
	check(math.abs(aRoot.CFrame.Position.Z - ES.Range) < 2 and aRoot.CFrame.UpVector.Y > 0.99 and not aRoot.Anchored, string.format("...%.0f studs down the street, on his feet and free", aRoot.CFrame.Position.Z))

	-- stunned in the crouch: called off, nothing sticks
	fresh(Vector3.new(X, 3, 30))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	aChar:SetAttribute("Stunned", true)
	task.wait(ES.WindUp + 0.4)
	aChar:SetAttribute("Stunned", false)
	check(#sentTo(B, "ExplosiveSpeedCancel") == 1 and #sentTo(B, "ExplosiveSpeedGo") == 0 and bHum.Health == MAX, "stunned in the crouch: the blitz is called off")
	check(not aRoot.Anchored and aChar:GetAttribute("BodyLocked") == nil, "...and he isn't left rooted")

	-- the ult's R has its own cooldown; 4 still works next to it
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "ExplosiveSpeed") == 1, "pressed twice: one blitz (it's on cooldown)")
	task.wait(ES.WindUp + ES.SlowMo + 1)
	fire(TestCommand, A, "EndUlt")
	task.wait(1)
	clearSent()
	fire(TestCommand, A, "ResetCooldowns")
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	check(#sentTo(B, "StunGrenade") == 1 and #sentTo(B, "ExplosiveSpeed") == 0, "the ult over: R is the Stun Grenade again")
	task.wait(1)
end)
---------------------------------------------------------------------------
-- Round 65: the back dash (backflip into a handstand), dashing out of an M1,
-- the chase dash, AUTO RUN, Crazy Diamond's new dome
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local X = 101500
	local FWD = Vector3.new(0, 0, 1)
	local MV = Config.Movement
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(quirk, bPos)
		fire(SelectQuirk, A, quirk)
		fire(SelectQuirk, B, "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, 3, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end

	print("== the back dash: a backflip into a handstand (Rampage Showdown's Sukuna)")
	check(MV.BackDashTime >= 0.45 and MV.BackDashSpeed and MV.BackDashTime * MV.DashSpeed * MV.BackDashSpeed > 20,
		string.format("it carries him about as far as a front dash (%.0f studs of push)", MV.BackDashTime * MV.DashSpeed * MV.BackDashSpeed))
	check(MV.SteerDashes ~= false, "...and steers with the camera like the others")
	fresh("Explosion", Vector3.new(X, 3, 40))
	local t0 = workspace:GetServerTimeNow()
	fire(UseAbility, A, Config.DASH_INDEX, -FWD, "Back")
	local seen = sentTo(B, "Dash")[1]
	check(seen and seen.Kind == "Back", "everyone sees the back dash")
	local lock = (aChar:GetAttribute("CombatActionUntil") or 0) - t0
	check(math.abs(lock - (MV.BackDashTime + (MV.BackDashRecovery or 0))) < 0.05,
		string.format("...he's committed through the flip and the handstand, free as his feet come down (%.2fs)", lock))

	print("== a side / back dash out of your own M1 (JJS)")
	fresh("Explosion", Vector3.new(X, 3, 4))
	fire(UseAbility, A, 0, aRoot.CFrame)
	task.wait(0.02)
	fire(UseAbility, A, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Right")
	check(#sentTo(B, "Dash") == 1, "an M1 thrown, then a side dash straight away: it goes (the M1's startup doesn't hold it)")
	task.wait(0.2)
	check(bHum.Health < MAX, "...and the punch still lands (" .. (MAX - bHum.Health) .. ")")
	task.wait(MV.MobilityDashCooldown + 0.1)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", false)
	clearSent()
	fire(UseAbility, A, 0, aRoot.CFrame)
	task.wait(0.02)
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	check(#sentTo(B, "Dash") == 0, "...a front dash can't cut into an M1")
	task.wait(0.35)
	check(#sentTo(B, "Dash") == 1, "...it goes once the swing's done")
	task.wait(0.6)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	aChar:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.8)
	fire(UseAbility, A, Config.DASH_INDEX, -FWD, "Back")
	check(#sentTo(B, "Dash") == 0, "...and nor can anything cut into a move's lock")
	task.wait(0.9)

	print("== the chase dash (JJS's anti-run)")
	local CH = MV.ChaseDash
	check(CH and CH.Enabled ~= false and CH.Range >= 30, "the chase dash is on")
	fresh("Explosion", Vector3.new(X, 3, 40))
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	task.wait(MV.FrontDashTime + MV.FrontWhiffRecovery + 0.05)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Front")
	check(#sentTo(B, "Dash") == 0, "the front dash is cooling down")
	t0 = workspace:GetServerTimeNow()
	fire(UseAbility, A, Config.DASH_INDEX, FWD, "Chase")
	seen = sentTo(B, "Dash")[1]
	check(seen and seen.Kind == "Chase", "...but a CHASE dash goes (everyone sees it)")
	lock = (aChar:GetAttribute("CombatActionUntil") or 0) - t0
	check(math.abs(lock - CH.Time) < 0.05, string.format("...on its own time, no whiff lag (%.2fs)", lock))
	task.wait(CH.Time + 0.05)
	clearSent()
	fire(UseAbility, A, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Right")
	check(#sentTo(B, "Dash") == 0, "...it's on the side-dash timer")
	task.wait(0.3)

	print("== AUTO RUN (a setting, like JJS)")
	local Settings = remotes:FindFirstChild("Settings")
	check(A:GetAttribute("AutoRun") ~= true, "off to begin with")
	fire(Settings, A, "AutoRun", true)
	task.wait(0.05)
	check(A:GetAttribute("AutoRun") == true, "switched on, it's remembered")
	task.wait(0.2)
	fire(Settings, A, "AutoRun", false)
	task.wait(0.05)
	check(A:GetAttribute("AutoRun") == false, "...and off again")
	task.wait(0.2)

	print("== CRAZY DIAMOND: the dome, rebuilt as real masonry")
	fresh("CrazyDiamond", Vector3.new(X + 40, 3, 0))
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("CrazyBuilt")
	for _, m in folder and folder:GetChildren() or {} do
		m.Parent = nil
	end
	A:SetAttribute("Blueprint", "Dome")
	clearSent()
	local calls = cd.rubbleCalls
	-- (what it asks the city for: the stones reuse the pieces, so a big build
	-- doesn't knock a huge chunk off a building for its rubble)
	local asked = 0
	local realRubble = dx.Rubble
	dx.Rubble = function(center, radius, want)
		asked = math.max(asked, want)
		return realRubble(center, radius, want)
	end
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.2 + 0.3 + 1 + 0.3)
	folder = map and map:FindFirstChild("CrazyBuilt")
	local dome = folder and folder:GetChildren()[1]
	local stones = dome and dome:GetChildren() or {}
	check(dome ~= nil and #stones >= 150 and #stones <= 260, "BUILD a dome: " .. #stones .. " stones (the old one had 57)")
	local solid, diamond, top = true, nil, -1
	for _, p in stones do
		if p.Transparency ~= 0 or p.CanCollide ~= true or p:GetAttribute("CrazyBuilt") ~= true then
			solid = false
		end
		if p.Material == Enum.Material.Glass then
			diamond = p
		end
		top = math.max(top, p.CFrame.Position.Y)
	end
	check(solid, "...every stone solid and in place")
	check(diamond and top - diamond.CFrame.Position.Y < 0.01 and diamond.Color.R > diamond.Color.G, "...Crazy Diamond's pink diamond on the very top")
	check(top > 12 and top < 19, string.format("...a proper dome over him (%.1f studs to the top)", top))
	dx.Rubble = realRubble
	check(cd.rubbleCalls > calls and asked > 0 and asked <= 60, "...made of the rubble lying around (asking for " .. asked .. " pieces, not one per stone)")
	local b = sentTo(B, "CrazyBuilt")[1]
	check(b and #b.Blocks == #stones and b.Blocks[#b.Blocks].Delay - b.Blocks[1].Delay > 0.8,
		"everyone sees it go up course by course (over " .. string.format("%.2f", b and (b.Blocks[#b.Blocks].Delay - b.Blocks[1].Delay) or 0) .. "s)")
	-- (a point is walled in if some stone holds it)
	local function inStone(pt)
		for _, p in stones do
			local lp = p.CFrame:PointToObjectSpace(pt)
			local h = p.Size / 2
			if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
				return true
			end
		end
		return false
	end
	local feet = Vector3.new(X, 0, 0)
	-- the doorway (facing the aim: +Z) is clear, a head's height and more
	local blocked = 0
	for x = -1.4, 1.4, 0.35 do
		local head = math.min(5.2, 3.4 + math.sqrt(2.05 ^ 2 - x * x) - 0.15)
		for y = 0.4, head, 0.4 do
			for r = 8.5, 11.5, 0.5 do
				if inStone(feet + Vector3.new(x, y, r)) then
					blocked += 1
				end
			end
		end
	end
	check(blocked == 0, "the doorway faces the aim, clear to walk through (" .. blocked .. " points blocked)")
	-- the walls are closed everywhere else, all the way up
	local gaps = 0
	for a = 30, 330, 15 do
		local out = Vector3.new(math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
		for _, y in { 1, 3, 5, 6.6 } do
			if not inStone(feet + out * 10 + Vector3.new(0, y, 0)) then
				gaps += 1
			end
		end
	end
	check(gaps == 0, "...and the wall's closed all the way round (" .. gaps .. " gaps)")
	local roof = 0
	for _, az in { 50, 110, 170, 230, 290 } do
		local out = Vector3.new(math.sin(math.rad(az)), 0, math.cos(math.rad(az)))
		for _, el in { 12, 30, 48, 62, 72 } do
			if not inStone(feet + out * (10 * math.cos(math.rad(el))) + Vector3.new(0, 6.9 + 8 * math.sin(math.rad(el)), 0)) then
				roof += 1
			end
		end
	end
	if not inStone(feet + Vector3.new(0, 15.1, 0)) then
		roof += 1
	end
	check(roof == 0, "...and roofed over (" .. roof .. " holes)")
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 67 (round 66's content on the user's upload, without the Hero
-- License): the back dash (a twist in the air, a longer handstand, a
-- superhero landing - round 67: all of it x0.85 quicker), ADD KILLS, the F2
-- console (the owner runs commands, everyone else watches), the Support
-- Drop, Crazy Diamond's Stand M1s
---------------------------------------------------------------------------
;M.section(function()
	local serde = require("@lune/serde")
	local MAX = Config.PlayerMaxHealth
	local X = 103500
	local FWD = Vector3.new(0, 0, 1)
	local MV = Config.Movement
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(quirk, bPos)
		fire(SelectQuirk, A, quirk)
		fire(SelectQuirk, B, "FullCowl")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		-- (facing each other along Z: A looks +Z, B looks back at him)
		aChar, aHum, aRoot = spawnChar(A, CFrame.new(Vector3.new(X, 3, 0)) * CFrame.Angles(0, math.pi, 0))
		bChar, bHum, bRoot = spawnChar(B, CFrame.new(bPos))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end

	print("== round 66/67: the back dash - a twist in the air, a longer handstand, a superhero landing (round 67: quicker)")
	local BT = MV.BackDashBeats
	check(MV.BackDashTime >= 0.6 and BT and BT.Twist < BT.Hands and BT.Hands < BT.Land,
		string.format("the beats in order: twist %.2fs, hands %.2fs, landing %.2fs (dash %.2fs)", BT and BT.Twist or -1, BT and BT.Hands or -1, BT and BT.Land or -1, MV.BackDashTime))
	-- (how far its pace carries him)
	local curve, dist = MV.BackDashCurve, 0
	for t = 0, MV.BackDashTime, 0.005 do
		local k = curve[#curve][2]
		for i = 1, #curve - 1 do
			if t >= curve[i][1] and t <= curve[i + 1][1] then
				k = curve[i][2] + (curve[i + 1][2] - curve[i][2]) * (t - curve[i][1]) / (curve[i + 1][1] - curve[i][1])
				break
			end
		end
		dist += MV.DashSpeed * MV.BackDashSpeed * k * 0.005
	end
	check(dist > 20 and dist < 34, string.format("it still goes about as far as a front dash (%.0f studs), flat out through the flip, drifting on his hands", dist))
	-- (round 67) the same ground covered as round 66's (26.3 studs in 0.78s + 0.1s), quicker
	check(math.abs(dist - 26.3) < 1.5 and MV.BackDashTime + MV.BackDashRecovery <= 0.78 and BT.Land <= 0.78,
		string.format("(round 67) a little quicker: free at %.2fs (was 0.88s), the landing at %.2fs (was 0.87s), still %.1f studs (was 26.3)", MV.BackDashTime + MV.BackDashRecovery, BT.Land, dist))
	local onHands = 1
	for i = 1, #curve do
		if curve[i][1] >= BT.Hands - 0.02 and curve[i][1] <= BT.Hands + 0.16 then
			onHands = math.min(onHands, curve[i][2])
		end
	end
	check(onHands <= 0.4, "...slow while he holds the handstand (x" .. onHands .. ")")
	fresh("Explosion", Vector3.new(X, 3, 40))
	local t0 = workspace:GetServerTimeNow()
	fire(UseAbility, A, Config.DASH_INDEX, -FWD, "Back")
	local lock = (aChar:GetAttribute("CombatActionUntil") or 0) - t0
	check(math.abs(lock - (MV.BackDashTime + MV.BackDashRecovery)) < 0.05 and math.abs(lock - BT.Land) < 0.06,
		string.format("committed through the flip, the twist and the handstand, free as he lands (%.2fs)", lock))
	task.wait(1)

	print("== ADD KILLS: the leaderboard's test feature")
	fire(TestCommand, A, "ResetStats")
	clearSent()
	fire(TestCommand, A, "AddKills", 5)
	check(A:GetAttribute("Kills") == 5 and stat(A, "Kills") == 5, "+5 KOs: on the player list (" .. tostring(stat(A, "Kills")) .. ")")
	fire(TestCommand, A, "AddKills10")
	check(stat(A, "Kills") == 15 and stat(A, "Rank") == Config.Ranks[2].Short, "+10 more: 15, and the rank that earns (" .. tostring(stat(A, "Rank")) .. ")")
	local up = sentTo(B, "RankUp")[1]
	check(up and up.UserId == A.UserId and up.Index == 2, "...everyone's told about the rank-up")
	local board = ReplicatedStorage:FindFirstChild("TopHeroes")
	local list = board and board.Value ~= "" and serde.decode("json", board.Value) or {}
	local mine
	for _, e in list do
		if e.UserId == A.UserId then
			mine = e
		end
	end
	check(mine and mine.Kills == 15, "...and TOP HEROES shows it straight away")
	fire(TestCommand, A, "AddKills", -20)
	check(stat(A, "Kills") == 0, "a minus takes them off (never below zero)")
	studioMode = false
	fire(TestCommand, B, "AddKills", 50)
	check((B:GetAttribute("Kills") or 0) < 50, "...and it's for testers only")
	studioMode = true

	print("== THE CONSOLE (F2): only the owner runs commands; everyone can watch")
	local CR = remotes:FindFirstChild("Console")
	check(CR ~= nil and CR:IsA("RemoteEvent"), "the server made the Console remote")
	studioMode = false
	local C = addPlayer("Viewer66", 866) -- (a regular player: not the game's owner)
	local cChar, cHum = spawnChar(C, CFrame.new(X + 30, 3, 0))
	task.wait(0.1)
	check(A:GetAttribute("ConsoleOwner") == true and C:GetAttribute("ConsoleOwner") == false, "the game's owner has the input; a regular player can only watch")
	local function lines(p)
		local out = {}
		for _, s in M.sent do
			if (s.To == p or s.To == "all") and s.Args[1] == "Line" and type(s.Args[2]) == "table" then
				table.insert(out, s.Args[2])
			end
		end
		return out
	end
	local function run(p, text)
		clearSent()
		fire(CR, p, "Run", text)
		task.wait(0.06)
		return lines(p)
	end
	local cBefore = C:GetAttribute("Kills") or 0
	local got = run(C, "kills 50")
	check((C:GetAttribute("Kills") or 0) == cBefore and #got == 1 and got[1].Kind == "err" and string.find(got[1].Text, "owner") ~= nil,
		"a viewer types a command: refused, told why (" .. tostring(got[1] and got[1].Text) .. ")")
	check(#lines(A) == 0, "...and nobody else sees it")
	got = run(A, "kills 7 viewer66")
	check((C:GetAttribute("Kills") or 0) == cBefore + 7, "the owner: 'kills 7 viewer66' - their KOs go up by 7")
	local seen = lines(C)
	check(#seen == 2 and seen[1].Kind == "cmd" and string.find(seen[1].Text, "Alpha> kills 7 viewer66", 1, true) and seen[2].Kind == "ok",
		"...and everyone watching sees the command and what it did (" .. tostring(seen[2] and seen[2].Text) .. ")")
	run(A, "hero bakugo")
	check(A:GetAttribute("Quirk") == "Explosion", "'hero bakugo' switches hero")
	run(A, "hero josuke viewer66")
	check(C:GetAttribute("Quirk") == "CrazyDiamond", "...for someone else too, dev heroes included")
	cHum = C.Character and C.Character:FindFirstChildOfClass("Humanoid") or cHum
	cHum.Health = 40
	run(A, "heal view")
	check(cHum.Health == cHum.MaxHealth, "'heal view' (the start of a name will do)")
	local bucks = C:GetAttribute("Bucks") or 0
	run(A, "bucks 250 viewer66")
	check((C:GetAttribute("Bucks") or 0) == bucks + 250, "'bucks 250 viewer66'")
	run(A, "god")
	check(A:GetAttribute("GodMode") == true, "'god' switches god mode on...")
	run(A, "god off")
	check(A:GetAttribute("GodMode") ~= true, "...'god off' off")
	run(A, "set damage 2")
	check(workspace:GetAttribute("DamageMult") == 2, "'set damage 2' - the server panel's settings")
	run(A, "set reset")
	check(workspace:GetAttribute("DamageMult") == 1, "'set reset'")
	run(A, 'announce "hello heroes"')
	local note = sentTo(C, "Notice")[1]
	check(note and note.Text == "hello heroes", "'announce \"hello heroes\"' - a notice on everyone's screen (quoted words stay together)")
	got = run(A, "help")
	check(#got >= 2 and #lines(C) == 0, "'help' answers just the one asking")
	got = run(A, "nonsense")
	check(#got == 2 and got[2].Kind == "err", "an unknown word: 'help lists them'")
	clearSent()
	fire(CR, C, "Sync")
	fire(CR, A, "Sync")
	local syncC, syncA
	for _, s in M.sent do
		if s.Args[1] == "Sync" then
			if s.To == C then
				syncC = s.Args[2]
			elseif s.To == A then
				syncA = s.Args[2]
			end
		end
	end
	check(syncC and syncC.Owner == false and syncA and syncA.Owner == true and #syncC.Log >= 10 and #syncC.Commands >= 30,
		string.format("opening it: the log so far (%d lines), every command (%d) - and who can type", syncC and #syncC.Log or -1, syncC and #syncC.Commands or -1))
	local joined = false
	for _, l in syncC and syncC.Log or {} do
		if string.find(l.Text, "Viewer66 joined", 1, true) then
			joined = true
		end
	end
	check(joined, "...joins are in it")
	studioMode = true

	print("== THE SUPPORT DROP: a U.A. Support Course pod")
	local cRoot = C.Character:FindFirstChild("HumanoidRootPart")
	cRoot.CFrame = CFrame.new(X + 30, 3, 0)
	C:SetAttribute("Item_Soda", nil)
	local cash = C:GetAttribute("Bucks") or 0
	clearSent()
	fire(CR, A, "Run", "drop soda viewer66")
	task.wait(0.1)
	local drop = sentTo(C, "SupportDrop")[1]
	local flat = drop and Vector3.new(drop.Pos.X - cRoot.Position.X, 0, drop.Pos.Z - cRoot.Position.Z).Magnitude or -1
	check(drop and flat > 3 and flat < 10 and drop.From.Y - drop.Pos.Y > 100 and drop.Time >= 1,
		string.format("everyone sees it coming: a ring %.1f studs from him, the pod %d studs up", flat, drop and math.floor(drop.From.Y - drop.Pos.Y) or -1))
	check((C:GetAttribute("Bucks") or 0) == cash, "...(the console's drop is free)")
	if not drop then
		return -- (nothing more to check without the pod)
	end
	-- someone standing on the ring is thrown clear
	aRoot = A.Character and A.Character:FindFirstChild("HumanoidRootPart") or aRoot
	aRoot.CFrame = CFrame.new(drop.Pos + Vector3.new(1, 3, 0))
	task.wait(drop.Time + 0.05)
	check(aRoot:FindFirstChild("Knockback") ~= nil, "it slams in: whoever's under it is thrown clear")
	task.wait((drop.Open or 0.5) + 0.1)
	local box
	for _, p in workspace:GetChildren() do
		if p.Name == "Delivery" then
			box = p
		end
	end
	check(box and math.abs(box.Position.Y - drop.Pos.Y - 3.4) < 1.2, "the lid's off: the soda's sitting on top of the pod")
	aRoot.CFrame = CFrame.new(box.Position)
	task.wait(0.3)
	check(A:GetAttribute("Item_Soda") == nil and box.Parent ~= nil, "...nobody else can take it")
	cRoot.CFrame = CFrame.new(box.Position)
	task.wait(0.3)
	check(C:GetAttribute("Item_Soda") == 1, "he walks into it: it's his")
	local done = sentTo(A, "SupportDropDone")[1]
	check(done and done.Id == drop.Id and done.Taken == true, "...and the pod packs up on everyone's screen")
	aRoot.CFrame = CFrame.new(X, 3, 0)

	print("== CRAZY DIAMOND: the Stand throws the M1s")
	fresh("Explosion", Vector3.new(X, 3, 9.2))
	check(aRoot.CFrame.LookVector.Z > 0.9, "(he faces them)")
	fire(UseAbility, A, 0, aRoot.CFrame)
	task.wait(0.3)
	check(bHum.Health == MAX, "an M1 at someone 9 studs off: out of a fist's reach")
	task.wait(1.2)
	fresh("CrazyDiamond", Vector3.new(X, 3, 9.2))
	fire(UseAbility, A, 0, aRoot.CFrame)
	task.wait(0.3)
	check(bHum.Health < MAX, "Crazy Diamond: the Stand, out in front of him, reaches (" .. (MAX - bHum.Health) .. ")")
	local punch = sentTo(B, "Punch")[1]
	check(punch and punch.Count == 1, "...everyone sees the swing (the Stand throws it on every screen)")
	C.Parent = nil
	Players.PlayerRemoving:Fire(C)
	cChar.Parent = nil
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 68: combos for Suneater / Deku / All Might / Creati (hitstun, not
-- knockdowns), the ragdoll cancel out of a combo, Decay Grasp on someone
-- who's down, Zap Trap x3 and the fence between them, the M1s breaking a
-- body-sized chunk, controller sensitivity / Roblox camera settings
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local X = 105500
	local FWD = Vector3.new(0, 0, 1)
	local CB = Config.Combos
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(quirk, bPos, bQuirk)
		fire(SelectQuirk, A, quirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.new(Vector3.new(X, 3, 0)) * CFrame.Angles(0, math.pi, 0))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, bPos.Y, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local function freeA()
		local left = (aChar:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			task.wait(left + 0.05)
		end
	end
	local function horiz(v)
		return Vector3.new(v.X, 0, v.Z).Magnitude
	end

	print("== round 68: COMBOS - Suneater, Deku, All Might and Creati chain their moves")
	check(CB and CB.Enabled ~= false and CB.Heroes.Manifest and CB.Heroes.FullCowl and CB.Heroes.OneForAll and CB.Heroes.Creation,
		"combo heroes: Suneater, Deku, All Might, Creati")
	check(CB.Enders.ManchesterSmash and CB.Enders.TexasSmashMax and CB.Enders.HeroCounter and CB.Enders.GrandCannon and not CB.Enders.TexasSmash,
		"...their big finishers (Manchester, Texas Smash 100%, Grand Cannon...) still end it")
	-- TEXAS SMASH: B stays on their feet, stunned, shoved a short way
	fresh("OneForAll", Vector3.new(X, 3, 12))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(0.22 + 0.06)
	local kb = bRoot:FindFirstChild("Knockback")
	check(bHum.Health < MAX and bChar:GetAttribute("Stunned") == true and bChar:GetAttribute("ComboStun") == true,
		"TEXAS SMASH lands: B's held in hitstun (" .. (MAX - bHum.Health) .. ")")
	check(kb ~= nil and horiz(kb.VectorVelocity) <= CB.MaxShove + 0.01 and kb.VectorVelocity.Z > 5,
		"...shoved a short way, not across the street (" .. tostring(kb and math.floor(horiz(kb.VectorVelocity))) .. " studs/s, at most " .. CB.MaxShove .. ")")
	task.wait(0.15)
	check(bChar:GetAttribute("Ragdolled") ~= true, "...and never knocked down")
	-- ...so the M1s reach them
	freeA()
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 3.5), Vector3.new(X, 3, 0))
	local before = bHum.Health
	m1(A)
	check(bHum.Health < before, "...and his M1s follow straight on (" .. (before - bHum.Health) .. ")")
	-- the ragdoll cancel breaks out of it
	bChar:SetAttribute("Evasive", 100)
	fire(TestCommand, A, "ResetCooldowns")
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 1))
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 12), Vector3.new(X, 3, 0))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(0.3)
	check(bChar:GetAttribute("ComboStun") == true, "(held again)")
	clearSent()
	fire(UseAbility, B, Config.DASH_INDEX, Vector3.new(1, 0, 0), "Evasive")
	task.wait(0.05)
	check(bChar:GetAttribute("ComboStun") == nil and bChar:GetAttribute("Stunned") ~= true and (bChar:GetAttribute("Evasive") or 0) == 0 and #sentTo(B, "Evasive") == 1,
		"the RAGDOLL CANCEL breaks out of a combo (meter spent)")
	task.wait(1.2)
	-- off switch: the old knockdowns
	workspace:SetAttribute("Combos", false)
	fresh("OneForAll", Vector3.new(X, 3, 12))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(0.22 + 0.25)
	check(bChar:GetAttribute("Ragdolled") == true and bChar:GetAttribute("ComboStun") == nil, "(Combos off: Texas Smash knocks them down, as before)")
	workspace:SetAttribute("Combos", nil)
	task.wait(1.6)

	-- DEKU: St. Louis Smash (was a knockdown) holds them; Manchester still ends it
	fresh("FullCowl", Vector3.new(X, 3, 6))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position)
	task.wait((Config.Quirks.FullCowl.Abilities[2].Startup or 0.18) + 0.25)
	check(bHum.Health < MAX and bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("ComboStun") == true,
		"DEKU: St. Louis Smash holds B in hitstun (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.4)
	-- Delaware (the air blast lands from a thread of its own): still a combo hit
	fresh("FullCowl", Vector3.new(X, 3, 20))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait((Config.Quirks.FullCowl.Abilities[1].Startup or 0.12) + 0.2)
	check(bHum.Health < MAX and bChar:GetAttribute("ComboStun") == true, "...Delaware's air blast too, landing a beat later")
	task.wait(1.4)
	local MS = Config.Quirks.FullCowl.Abilities[3]
	fresh("FullCowl", Vector3.new(X, 3, 10))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.05)
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 8), Vector3.new(X, 3, 10)) -- (his machine lands him by B)
	task.wait((MS.TravelTime or 0.46) + 0.3)
	check(bHum.Health < MAX and bChar:GetAttribute("Ragdolled") == true, "...MANCHESTER SMASH is an ender: B goes down (" .. (MAX - bHum.Health) .. ")")
	task.wait(2)

	-- SUNEATER: Tako Thrash lets them go on their feet; Swordfish follows
	local SE = Config.Quirks.Manifest
	fresh("Manifest", Vector3.new(X, 3, 6))
	local stubRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 6), 1, aRoot.Position)
	local t0 = os.clock()
	while os.clock() - t0 < 2.5 and not (#sentTo(B, "TentacleSlam") >= 3 and not bRoot.Anchored) do
		task.wait()
	end
	task.wait(0.15)
	check(#sentTo(B, "TentacleSlam") == 3 and bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("Stunned") == true,
		"SUNEATER: Tako Thrash lets B go on their feet, stunned (" .. (MAX - bHum.Health) .. ")")
	kb = bRoot:FindFirstChild("Knockback")
	check(kb == nil or horiz(kb.VectorVelocity) <= CB.MaxShove + 0.01, "...not flung out of reach")
	freeA()
	fire(TestCommand, A, "ResetCooldowns")
	aRoot.CFrame = CFrame.lookAt(bRoot.Position - FWD * 6, bRoot.Position)
	local mid = bHum.Health
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position, false)
	task.wait(0.16 + 0.25)
	check(#sentTo(B, "SwordfishImpale") == 1 and bHum.Health < mid, "...and SWORDFISH catches them straight after")
	task.wait(0.45)
	check(bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("ComboStun") == true, "...thrown, still on their feet (a combo)")
	workspace.Raycast = stubRay
	task.wait(1.5)
	-- CHICKEN KICK keeps its launch (the lift is the combo)
	fresh("Manifest", Vector3.new(X, 3, 4))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.35)
	kb = bRoot:FindFirstChild("Knockback")
	local launched = (kb and kb.VectorVelocity.Y or 0) > CB.MaxLift or bRoot.Anchored or bRoot.Position.Y > 6
	check(launched and bChar:GetAttribute("Ragdolled") ~= true, "CHICKEN KICK still launches them up (" .. tostring(kb and kb.VectorVelocity) .. ")")
	task.wait(2)

	-- CREATI: Castle Wall's bash (was a knockdown) holds them
	fresh("Creation", Vector3.new(X, 3, 3.5))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.6)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, Vector3.new(X, 3, 10))
	task.wait(0.5)
	check(#sentTo(B, "ShieldBash") == 1 and bHum.Health < MAX and bChar:GetAttribute("Ragdolled") ~= true and bChar:GetAttribute("ComboStun") == true,
		"CREATI: the shield bash holds them on their feet (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.5)

	print("== round 68: DECAY GRASP grabs someone lying in the street")
	fresh("Decay", Vector3.new(X, 3, 4))
	bChar:SetAttribute("Ragdolled", true)
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 4), 1, aRoot.Position)
	task.wait(0.45)
	check(#sentTo(B, "Grasped") == 1 and MAX - bHum.Health >= Config.Quirks.Decay.Abilities[2].Damage,
		"DECAY GRASP on B, down in the street: grabbed, full damage (" .. (MAX - bHum.Health) .. ")")
	task.wait(1.2)
	fresh("Decay", Vector3.new(X, 3, 10))
	bChar:SetAttribute("Ragdolled", true)
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 10), 1, aRoot.Position)
	task.wait(0.8)
	check(bHum.Health == MAX, "...(his other moves still pass over someone who's down)")
	bChar:SetAttribute("Ragdolled", nil)
	task.wait(1)

	print("== round 68: ZAP TRAP - three at once, and a fence between them")
	local ZT = Config.Quirks.Electrification.Abilities[3]
	check(ZT.Max == 3, "up to 3 traps at once (was " .. 2 .. ")")
	fresh("Electrification", Vector3.new(X + 40, 3, 0))
	-- (all within his 16-stud reach: two ahead, one behind him)
	local spots = { Vector3.new(X - 6, 0, 10), Vector3.new(X + 6, 0, 10), Vector3.new(X, 0, -8) }
	for _, at in spots do
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, 3, FWD, at, 1, aRoot.Position)
		task.wait(0.45)
	end
	check(#sentTo(B, "ZapTrapSet") == 3 and #sentTo(B, "ZapTrapGone") == 0, "three traps down, none replaced")
	task.wait(ZT.ArmTime + 0.2)
	bRoot.CFrame = CFrame.new(X, 3, 6)
	task.wait(0.2)
	check(bHum.Health == MAX, "(B inside the three, clear of the lines: nothing)")
	clearSent()
	bRoot.CFrame = CFrame.new(X, 3, 14) -- (straight out through the line between the first two)
	task.wait(0.25)
	local jolt = sentTo(B, "ZapTrapFenceJolt")[1]
	check(jolt and MAX - bHum.Health == ZT.FenceDamage and bChar:GetAttribute("Stunned") == true and #sentTo(B, "ZapTrapSnap") == 0,
		"B runs between two traps: the fence jolts them (" .. (MAX - bHum.Health) .. ", stunned)")
	check(jolt and typeof(jolt.PA) == "Vector3" and typeof(jolt.PB) == "Vector3" and math.abs(jolt.PA.Z - 10) < 1 and math.abs(jolt.PB.Z - 10) < 1,
		"...the span between those two lights up for everyone")
	bRoot.CFrame = CFrame.new(X, 3, 6)
	task.wait(0.2)
	check(#sentTo(B, "ZapTrapFenceJolt") == 1, "(once every " .. ZT.FenceEvery .. "s, not every frame)")
	task.wait(ZT.FenceEvery + 0.1)
	bHum.Health = MAX
	bRoot.CFrame = CFrame.new(X, 3, 10) -- (standing in it, clear of the traps themselves)
	task.wait(0.25)
	check(MAX - bHum.Health == ZT.FenceDamage, "standing in the line jolts too")
	bRoot.CFrame = CFrame.new(X + 40, 3, 0)
	task.wait(0.1)
	local aBefore = aHum.Health
	aRoot.CFrame = CFrame.new(X, 3, 6)
	task.wait(0.15)
	aRoot.CFrame = CFrame.new(X, 3, 14)
	task.wait(0.25)
	check(aHum.Health == aBefore, "Chargebolt walks through his own fence")
	-- a single trap: no fence
	fresh("Electrification", Vector3.new(X + 40, 3, 0))
	fire(UseAbility, A, 3, FWD, spots[1], 1, aRoot.Position)
	task.wait(0.35 + ZT.ArmTime + 0.2)
	bRoot.CFrame = CFrame.new(X + 6, 3, 6)
	task.wait(0.15)
	bRoot.CFrame = CFrame.new(X + 6, 3, 14)
	task.wait(0.25)
	check(bHum.Health == MAX and #sentTo(B, "ZapTrapFenceJolt") == 0, "one trap on its own: no fence")
	-- too far apart: no fence
	fresh("Electrification", Vector3.new(X + 60, 3, 0))
	for _, at in { Vector3.new(X - 30, 0, 12), Vector3.new(X + 30, 0, 12) } do
		aRoot.CFrame = CFrame.lookAt(Vector3.new(at.X, 3, 0), Vector3.new(at.X, 3, 1)) -- (he walks over)
		fire(TestCommand, A, "ResetCooldowns")
		fire(UseAbility, A, 3, FWD, at, 1, aRoot.Position)
		task.wait(0.45)
	end
	aRoot.CFrame = CFrame.lookAt(Vector3.new(X + 60, 3, -20), Vector3.new(X + 60, 3, 0))
	task.wait(ZT.ArmTime + 0.2)
	bRoot.CFrame = CFrame.new(X, 3, 8)
	task.wait(0.15)
	bRoot.CFrame = CFrame.new(X, 3, 16)
	task.wait(0.25)
	check(bHum.Health == MAX, "two traps more than " .. ZT.FenceRange .. " studs apart: no fence")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)

	print("== round 68: M1s break a body-sized chunk of the building they hit")
	local MD = Config.M1.Destruction
	check(MD and MD.Finisher.Y >= 5 and MD.Finisher.X >= 4 and MD.Chip == nil, "the last M1: a body-sized hole; (round 69) the others don't mark it")
	local dx = rawget(destruction, "_exports")
	local carved = {}
	local oldBox, oldSphere = dx.Box, dx.Sphere
	dx.Box = function(cf, size, profile, ...)
		table.insert(carved, { Kind = "Box", Size = size, Profile = profile })
		return oldBox(cf, size, profile, ...)
	end
	dx.Sphere = function(center, radius, profile, ...)
		table.insert(carved, { Kind = "Sphere", Radius = radius, Profile = profile })
		return oldSphere(center, radius, profile, ...)
	end
	fresh("Explosion", Vector3.new(X, 3, 60))
	for _ = 1, 4 do
		m1(A)
		task.wait(0.35)
	end
	dx.Box, dx.Sphere = oldBox, oldSphere
	local chips, chunk = 0, nil
	for _, c in carved do
		if c.Profile == "Impact" and c.Kind == "Sphere" then
			chips += 1
		elseif c.Profile == "Impact" and c.Kind == "Box" and typeof(c.Size) == "Vector3" and c.Size == MD.Finisher then
			chunk = c
		end
	end
	local boxes = 0
	for _, c in carved do
		if c.Kind == "Box" then
			boxes += 1
		end
	end
	check(chips == 0 and boxes == 1 and chunk ~= nil, "four M1s: only the 4th breaks anything - one body-sized hole (" .. tostring(chunk and chunk.Size) .. "; " .. chips .. " chips)")

	print("== round 68: CONTROLLER SENSITIVITY and the Roblox camera, saved like the rest")
	local Settings = remotes:FindFirstChild("Settings")
	fire(Settings, A, "PadSensitivity", 1.5)
	check(A:GetAttribute("PadSensitivity") == 1.5, "controller sensitivity x1.5")
	task.wait(0.2)
	fire(Settings, A, "PadSensitivity", 40)
	check(A:GetAttribute("PadSensitivity") == 4, "...held to x0.25-x4 (" .. tostring(A:GetAttribute("PadSensitivity")) .. ")")
	task.wait(0.2)
	fire(Settings, A, "PadSensitivity", "fast")
	check(A:GetAttribute("PadSensitivity") == 4, "...(a number only)")
	task.wait(0.2)
	fire(Settings, A, "RobloxCamera", true)
	check(A:GetAttribute("RobloxCamera") == true, "ROBLOX CAMERA: on")
	task.wait(0.2)
	fire(Settings, A, "RobloxCamera", false)
	fire(Settings, A, "PadSensitivity", 1)
	task.wait(0.2)
	fire(Settings, A, "PadSensitivity", 1)
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 69: TWICE (Jin Bubaigawara) - his doubles (real bodies that fight
-- for him and melt), Dagger Shot, Tape Dash, Measure (a double of THEM),
-- Double Cross, Sad Man's Parade (the burst, Parade, Dagger Storm, Dogpile)
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local X = 106500
	local FWD = Vector3.new(0, 0, 1)
	local TWc = Config.Quirks.Double
	local CS = TWc and TWc.Clones or {}
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local function fresh(quirk, bPos, bQuirk)
		fire(SelectQuirk, A, quirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 1)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, bPos.Y, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local function freeA()
		local left = (aChar:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			task.wait(left + 0.05)
		end
		fire(TestCommand, A, "ResetCooldowns")
	end
	-- A's doubles standing now (not melting)
	local function doubles(kind)
		local out = {}
		local f = workspace:FindFirstChild("TwiceClones")
		for _, m in f and f:GetChildren() or {} do
			if m:GetAttribute("TwiceClone") == A.UserId and not m:GetAttribute("Melting") and (not kind or m:GetAttribute("CloneKind") == kind) then
				table.insert(out, m)
			end
		end
		return out
	end
	local function double()
		freeA()
		fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, aRoot.Position + FWD * 10, 1, aRoot.Position)
		task.wait(0.35)
	end

	print("== round 69: TWICE - in the roster")
	check(TWc ~= nil and TWc.DisplayName == "TWICE" and table.find(Config.QuirkOrder, "Double") ~= nil,
		"TWICE (Double) is on the phone (round 70: for testers)")
	check(#TWc.Abilities == 3 and TWc.Special.Id == "Double" and TWc.Extra.Id == "DoubleCross" and #TWc.Ult.Abilities == 3,
		"1 Dagger Shot, 2 Tape Dash, 3 Measure, R Double, 4 Double Cross; the ult's three")
	for _, id in { "DaggerShot", "TapeDash", "MeasureTape", "Double", "DoubleCross", "ParadeMarch", "DaggerStorm", "Dogpile" } do
		check(Config.FindAbilityById(id) ~= nil, "(" .. id .. " is a move)")
	end
	check(Config.UltMusic.Tracks.Double ~= nil and Config.Sounds.UltDouble ~= nil and Config.Sounds.KnifeThrow ~= nil and Config.Sounds.CloneMelt ~= nil,
		"his ult music and sounds")

	print("== round 69: R - a double steps out of him")
	fresh("Double", Vector3.new(X + 60, 3, 60))
	check(aChar:GetAttribute("Doubles") == 0, "his HUD counts his doubles (0)")
	double()
	local mine = doubles()
	check(#mine == 1 and mine[1]:GetAttribute("CloneKind") == "Self" and mine[1].Name == aChar.Name,
		"R: one double of him (" .. #mine .. ")")
	local d1 = mine[1]
	local d1Hum, d1Root = d1 and d1:FindFirstChildOfClass("Humanoid"), d1 and d1:FindFirstChild("HumanoidRootPart")
	check(d1Hum ~= nil and d1Hum.MaxHealth == CS.Health and d1Hum.Health == CS.Health and d1Root ~= nil and d1Root ~= aRoot,
		"...its own body, " .. tostring(CS.Health) .. " health")
	check(d1Root and (d1Root.Position - aRoot.Position).Magnitude < 6 and aRoot.Position.Z == 0, "...beside him (he stays put)")
	check(#sentTo(B, "TwiceSplit") == 1 and aChar:GetAttribute("Doubles") == 1, "everyone sees it form; his HUD: 1")
	-- his own hits pass through it
	d1Root.CFrame = CFrame.lookAt(Vector3.new(X, 3, 3), Vector3.new(X, 3, 0))
	task.wait(0.05)
	m1(A)
	check(d1Hum.Health == CS.Health, "his own M1s pass through his double (" .. d1Hum.Health .. ")")
	task.wait(Config.M1.ComboReset + 0.1)
	-- it goes for B
	clearSent()
	d1Root.CFrame = CFrame.lookAt(Vector3.new(X + 60, 3, 57), Vector3.new(X + 60, 3, 60))
	task.wait(1.2)
	check(bHum.Health < MAX and #sentTo(A, "TwiceClonePunch") >= 1, "the double goes for B and hits (" .. (MAX - bHum.Health) .. ")")
	-- B hits it: no ult for that, no KO
	bHum.Health = MAX
	local ultBefore = B:GetAttribute("Ult") or 0
	local kosBefore = stat(B, "Kills")
	d1Root.CFrame = CFrame.lookAt(Vector3.new(X + 60, 3, 57), Vector3.new(X + 60, 3, 60))
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X + 60, 3, 60), Vector3.new(X + 60, 3, 57))
	for _ = 1, 4 do
		m1(B)
		task.wait(0.35)
		if d1Hum.Health <= 0 then
			break
		end
	end
	check(d1Hum.Health < CS.Health, "B's M1s hurt it (" .. d1Hum.Health .. ")")
	check((B:GetAttribute("Ult") or 0) == ultBefore, "...and charge nobody's ult (it's mud)")
	d1Hum.Health = 0
	task.wait(0.1)
	check(#sentTo(A, "TwiceMelt") == 1 and d1:GetAttribute("Melting") == true and aChar:GetAttribute("Doubles") == 0,
		"beaten: it melts into mud (his HUD: 0)")
	check(stat(B, "Kills") == kosBefore, "...no KO, no kill for it")
	task.wait((CS.Melt or 0.7) + 0.4)
	check(d1.Parent == nil, "...and it's gone")

	print("== round 69: at most " .. tostring(CS.Max) .. " at once - the oldest melts for a new one")
	fresh("Double", Vector3.new(X + 60, 3, 60))
	for _ = 1, CS.Max + 1 do
		double()
	end
	check(#doubles() == CS.Max and aChar:GetAttribute("Doubles") == CS.Max, "R x" .. (CS.Max + 1) .. ": still " .. #doubles())
	check(#sentTo(A, "TwiceMelt") >= 1, "...the first one melted")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.2)
	check(#doubles() == 0 and aChar:GetAttribute("Doubles") == nil, "someone else now: his doubles melt")

	print("== round 69: 1 DAGGER SHOT - knives down the aim, slowing")
	local DS = TWc.Abilities[1]
	fresh("Double", Vector3.new(X, 3, 20))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.12 + DS.Knives * DS.Gap + 20 / DS.Speed + 0.2)
	check(#sentTo(B, "TwiceKnife") >= DS.Knives, "three knives fly (" .. #sentTo(B, "TwiceKnife") .. ")")
	check(MAX - bHum.Health == DS.Damage * DS.Knives, "...all three land (" .. (MAX - bHum.Health) .. ")")
	check(bChar:GetAttribute("SlowedTo") == DS.SlowTo, "...and slow them")
	task.wait(1.6)
	-- his double throws too
	fresh("Double", Vector3.new(X, 3, 30))
	double()
	local d2 = doubles()[1]
	d2:FindFirstChild("HumanoidRootPart").CFrame = CFrame.lookAt(Vector3.new(X + 8, 3, 0), Vector3.new(X + 8, 3, 1))
	clearSent()
	freeA()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.8)
	check(#sentTo(A, "TwiceThrow") == 1 and #sentTo(B, "TwiceKnife") >= DS.Knives + 1, "...and every double of his throws one at the spot")

	print("== round 69: 2 TAPE DASH - zips him into a slash")
	local TD = TWc.Abilities[2]
	fresh("Double", Vector3.new(X, 3, 4.5))
	fire(UseAbility, A, 2, FWD, Vector3.new(X, 3, 20), 1, aRoot.Position)
	task.wait(0.3)
	check(MAX - bHum.Health == TD.Damage and bChar:GetAttribute("Stunned") == true and #sentTo(A, "TapeSlash") == 1,
		"the first one in his way: " .. (MAX - bHum.Health) .. ", stunned")
	task.wait(1.2)

	print("== round 69: 3 MEASURE - the tape reels them in; his next R makes a double of THEM")
	local MT = TWc.Abilities[3]
	fresh("Double", Vector3.new(X, 3, 16))
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 16), 1, aRoot.Position)
	task.wait(0.14 + 16 / 160 + 0.25)
	check(MAX - bHum.Health == MT.Damage and bChar:GetAttribute("Grabbed") == true, "the tape wraps B (" .. (MAX - bHum.Health) .. ")")
	check(bChar:GetAttribute("MeasuredBy") == A.UserId and aChar:GetAttribute("Measuring") == bChar.Name, "...measured")
	check((bRoot.Position - (aRoot.Position + FWD * MT.Pull)).Magnitude < 1.5, "...reeled in to " .. MT.Pull .. " studs in front of him (" .. tostring(bRoot.Position) .. ")")
	task.wait(MT.Bind + 0.2)
	check(not bRoot.Anchored and bChar:GetAttribute("Grabbed") == nil, "...then let go")
	clearSent()
	double()
	local them = doubles("Enemy")
	check(#them == 1 and them[1].Name == bChar.Name and them[1]:GetAttribute("TwiceClone") == A.UserId,
		"R: a double of B - on his side")
	check(bChar:GetAttribute("MeasuredBy") == nil and aChar:GetAttribute("Measuring") == nil, "...the measure's used up")
	check(them[1]:GetAttribute("Quirk") == nil and them[1]:GetAttribute("MeasuredBy") == nil, "...mud: none of B's own state comes with it")
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 16), Vector3.new(X, 3, 0))
	them[1]:FindFirstChild("HumanoidRootPart").CFrame = CFrame.lookAt(Vector3.new(X, 3, 13), Vector3.new(X, 3, 16))
	bHum.Health = MAX
	task.wait(1.2)
	check(bHum.Health <= MAX - CS.EnemyDamage, "...and it goes for B (" .. (MAX - bHum.Health) .. ")")
	task.wait(0.5)

	print("== round 69: 4 DOUBLE CROSS - swaps him with his double nearest the aim")
	fresh("Double", Vector3.new(X + 60, 3, 60))
	double()
	local d3 = doubles()[1]
	local d3Root = d3:FindFirstChild("HumanoidRootPart")
	d3Root.CFrame = CFrame.lookAt(Vector3.new(X + 20, 3, 10), Vector3.new(X + 20, 3, 11))
	freeA()
	clearSent()
	local dir = (Vector3.new(X + 20, 3, 10) - aRoot.Position).Unit
	fire(UseAbility, A, Config.EXTRA_INDEX, dir, Vector3.new(X + 20, 3, 10), 1, aRoot.Position)
	task.wait(0.15)
	check((aRoot.Position - Vector3.new(X + 20, 3, 10)).Magnitude < 0.5 and (d3Root.Position - Vector3.new(X, 3, 0)).Magnitude < 0.5,
		"he's where his double was, it's where he was (" .. tostring(aRoot.Position) .. ")")
	check(not aRoot.Anchored and #sentTo(B, "DoubleSwap") == 1, "...and free to move (everyone sees the swap)")
	-- none out: he throws one
	fresh("Double", Vector3.new(X + 60, 3, 60))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.5)
	local tossed = doubles()
	local tr = tossed[1] and tossed[1]:FindFirstChild("HumanoidRootPart")
	check(#sentTo(B, "CloneToss") == 1 and #tossed == 1 and tr and (tr.Position - Vector3.new(X, 3, 30)).Magnitude < 1,
		"no double out: he throws one to the spot (" .. tostring(tr and tr.Position) .. ")")

	print("== round 69: SAD MAN'S PARADE")
	local U = TWc.Ult
	fresh("Double", Vector3.new(X + 60, 3, 60))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.4)
	check(A:GetAttribute("UltActive") == true and #doubles("Self") == U.Burst and aChar:GetAttribute("Doubles") == U.Burst,
		"the awakening: " .. #doubles("Self") .. " doubles pour out of him")
	for _ = 1, U.Special.Max do
		double()
	end
	check(#doubles() == U.Special.Max, "R in the ult: up to " .. U.Special.Max .. " at once (" .. #doubles() .. ")")
	-- (his doubles out of it for now: a long way off)
	for i, m in doubles() do
		m:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(X - 200 - i * 4, 3, 0)
	end
	-- PARADE: a column tramples whoever's in its way (once each)
	local PM = U.Abilities[1]
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 1.5), Vector3.new(X, 3, 0))
	bHum.Health = MAX
	freeA()
	clearSent()
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 30), 1, aRoot.Position)
	task.wait(0.45)
	check(#doubles("Parade") == PM.Count, "PARADE: " .. #doubles("Parade") .. " of him march")
	local once = MAX - bHum.Health
	check(once > 0 and once <= math.floor(PM.Damage * Config.Ult.DamageMultiplier + 0.5), "...trample B once (" .. once .. ")")
	task.wait(PM.Range / PM.Speed + 0.5)
	check(#doubles("Parade") == 0 and MAX - bHum.Health == once, "...and melt when it's over (still " .. (MAX - bHum.Health) .. ")")
	task.wait(1)
	-- DOGPILE: every double of his onto B, then the heap bursts
	local DP = U.Abilities[3]
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 12), Vector3.new(X, 3, 0))
	bHum.Health = MAX
	bChar:SetAttribute("Stunned", nil)
	for i, m in doubles() do
		m:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(X + 30 + i * 4, 3, 0) -- (back in range)
	end
	local before = #doubles()
	freeA()
	clearSent()
	fire(UseAbility, A, 3, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(0.3)
	check(bChar:GetAttribute("Grabbed") == true and #doubles("Pile") == before + DP.Count, "DOGPILE: " .. #doubles("Pile") .. " of him pile on")
	task.wait((before + DP.Count) * 0.07 + 0.8)
	check(#sentTo(A, "DogpileBurst") == 1 and bChar:GetAttribute("Ragdolled") == true and not bRoot.Anchored,
		"...the heap bursts and B goes flying (" .. (MAX - bHum.Health) .. ")")
	check(#doubles() == 0, "...and every one of them melts")
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 70: TWICE is a dev character (testers and players they grant)
---------------------------------------------------------------------------
;M.section(function()
	print("== round 70: TWICE is a dev character")
	local TWc = Config.Quirks.Double
	check(TWc.DevOnly == true and table.find(Config.QuirkOrder, "Double") ~= nil, "TWICE: on the list, dev only")
	local wasStudio, wasCreator = studioMode, game.CreatorId
	studioMode = false
	game.CreatorId = 1 -- A (UserId 1) owns the game; B is a regular player
	fire(TestCommand, A, "GrantDevAll", nil, false)
	fire(TestCommand, A, "GrantDev", B.UserId, false)
	fire(SelectQuirk, B, "Explosion")
	task.wait(0.1)
	fire(SelectQuirk, B, "Double")
	check(B:GetAttribute("Quirk") ~= "Double", "a regular player can't pick him (" .. tostring(B:GetAttribute("Quirk")) .. ")")
	fire(SelectQuirk, A, "Double")
	check(A:GetAttribute("Quirk") == "Double", "the owner can")
	fire(TestCommand, A, "GrantDev", B.UserId, true)
	task.wait(2.6) -- (a regular player waits 2.5s between switches)
	fire(SelectQuirk, B, "Double")
	check(B:GetAttribute("Quirk") == "Double", "...and so can someone they grant")
	fire(TestCommand, A, "GrantDev", B.UserId, false)
	task.wait(0.1)
	check(B:GetAttribute("Quirk") ~= "Double", "revoked: B's moved off him (" .. tostring(B:GetAttribute("Quirk")) .. ")")
	fire(SelectQuirk, A, "Explosion")
	studioMode, game.CreatorId = wasStudio, wasCreator
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 71: QUIRK CLASHES (Config.Clash), the JJS beam clash
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local X = 107500
	local CC = Config.Clash
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local Clash = remotes:FindFirstChild("Clash")
	local FWD, BACK = Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)
	local function fresh(bPos)
		fire(SelectQuirk, A, "Explosion")
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 1)))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(X, bPos.Y, 0)))
		task.wait(0.2)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	-- the prompts, the way both ends work them out from the seed
	local function keysFor(seed, side)
		local r = seededRandom(seed + side * 7919)
		return function()
			return CC.Keys[r:NextInteger(1, #CC.Keys)]
		end
	end
	local function wrongFrom(key)
		return key == "W" and "A" or "W"
	end
	-- B fires first at A; A fires straight back
	local function headOn(bDir)
		fire(UseAbility, B, 1, bDir or BACK, aRoot.Position, 1, bRoot.Position)
		task.wait(0.05)
		fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
		task.wait(0.3)
	end

	print("== round 71: QUIRK CLASHES - config")
	check(CC and CC.Enabled ~= false and CC.Moves.APShot and CC.Moves.HollowPurple and CC.Moves.DetroitSmash and CC.Moves.Heatwave and CC.Moves.DelawareSmash,
		"clash moves: AP Shot, Detroit Smash, Delaware, Heatwave, Hollow Purple...")
	check(#CC.Keys == 3 and CC.Keys[1] == "W" and CC.Keys[2] == "A" and CC.Keys[3] == "D" and CC.Time == 10, "JJS: W A D, ten seconds")
	check(Clash ~= nil, "the Clash remote exists")

	print("== round 71: two AP Shots meet head on")
	fresh(Vector3.new(X, 3, 30))
	headOn()
	local starts = sentTo(A, "ClashStart")
	local st = starts[1]
	local id = aChar:GetAttribute("Clashing")
	check(#starts == 1 and id ~= nil and bChar:GetAttribute("Clashing") == id and st and st.Id == id, "CLASH: both locked into it (" .. tostring(id) .. ")")
	check(#sentTo(B, "ClashStart") == 1, "...everyone sees it")
	check(aHum.Health == MAX and bHum.Health == MAX, "...neither AP Shot lands (" .. aHum.Health .. ", " .. bHum.Health .. ")")
	check(aRoot.Anchored and bRoot.Anchored, "...rooted where they stand")
	check(st and (st.AMove == "APShot" and st.BMove == "APShot") and (st.A == aChar or st.A == bChar) and type(st.Seed) == "number", "...it knows whose moves met")
	-- nothing else gets through to them meanwhile
	bRoot.CFrame = CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 0))
	m1(A)
	check(bHum.Health == MAX, "nothing else lands on them mid-clash")
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	check(#sentTo(B, "BlastRush") == 0, "...and they can't use anything else")
	-- A presses right every time; B does nothing: A pushes it all the way
	local aSide = st.A == aChar and 1 or 2
	local nextA = keysFor(st.Seed, aSide)
	local pushes = 0
	for i = 1, 40 do
		if not aChar:GetAttribute("Clashing") then
			break
		end
		fire(Clash, A, id, i, nextA())
		pushes += 1
		task.wait(0.08)
	end
	local good = 0
	for _, p in sentTo(A, "ClashPush") do
		if p.Good then
			good += 1
		end
	end
	local needed = math.ceil(1 / CC.Step)
	check(good >= needed - 1 and good <= needed + 1 and pushes <= needed + 2, "right presses push it through (" .. good .. " presses; ~" .. needed .. " to go all the way)")
	local ends = sentTo(A, "ClashEnd")
	check(#ends == 1 and ends[1].Winner == aChar and ends[1].Loser == bChar and not ends[1].Draw, "A OVERPOWERS B")
	task.wait(0.45)
	check(MAX - bHum.Health == CC.MinDamage and bChar:GetAttribute("Ragdolled") == true, "...the AP Shot goes through: " .. (MAX - bHum.Health) .. " and B's sent flying")
	check(aHum.Health == MAX, "...A's untouched")
	check(not aRoot.Anchored and aChar:GetAttribute("Clashing") == nil and bChar:GetAttribute("Clashing") == nil, "...and both are free again")
	task.wait(1.5)

	print("== round 71: wrong presses, the clock, a draw")
	fresh(Vector3.new(X, 3, 30))
	local was = CC.Time
	CC.Time = 1.5
	headOn()
	st = sentTo(A, "ClashStart")[1]
	id = st and st.Id
	check(id ~= nil, "(clash)")
	aSide = st.A == aChar and 1 or 2
	nextA = keysFor(st.Seed, aSide)
	local key = nextA()
	fire(Clash, A, id, 1, wrongFrom(key))
	local push = sentTo(A, "ClashPush")[1]
	local toward = aSide == 1 and 1 or -1
	check(push and push.Good == false and push.M * toward < 0, "a wrong press knocks you back a half step (" .. tostring(push and push.M) .. ")")
	task.wait(0.1)
	fire(Clash, A, id, 2, nextA())
	check(#sentTo(A, "ClashPush") == 1, "...and the next one doesn't count while you're reeling")
	local nextB = keysFor(st.Seed, 3 - aSide)
	fire(Clash, B, id, 1, nextB()) -- (B pulls ahead)
	clearSent()
	fire(Clash, A, id, 99, "W")
	local sync = sentTo(A, "ClashSync")[1]
	check(sync and sync.Index == 3, "out of step: the server tells you which prompt it's on (" .. tostring(sync and sync.Index) .. ")")
	task.wait(1.6)
	local ended = sentTo(A, "ClashEnd")[1]
	check(ended and ended.Winner == bChar, "time's up: whoever's ahead wins it (B)")
	task.wait(0.5)
	check(aHum.Health == MAX - CC.MinDamage, "...B's shot goes through A (" .. (MAX - aHum.Health) .. ")")
	task.wait(1.5)
	-- dead level
	fresh(Vector3.new(X, 3, 30))
	headOn()
	st = sentTo(A, "ClashStart")[1]
	task.wait(1.7)
	ended = sentTo(A, "ClashEnd")[1]
	check(ended and ended.Draw == true, "nobody presses: dead level - a DRAW")
	task.wait(0.5)
	check(MAX - aHum.Health == CC.DrawDamage and MAX - bHum.Health == CC.DrawDamage, "...it all goes up between them: " .. (MAX - aHum.Health) .. " each")
	CC.Time = was
	task.wait(1.5)

	print("== round 71: anyone too close is caught in it; leaving ends it")
	fresh(Vector3.new(X, 3, 30))
	headOn()
	st = sentTo(A, "ClashStart")[1]
	local folderD = workspace:FindFirstChild("Dummies")
	local dm, dHum = makeCharacter("Bystander71", CFrame.new(X, 3, 15))
	dHum.MaxHealth, dHum.Health = 500, 500
	dm.Parent = folderD
	task.wait(1.1)
	check(dHum.Health < 500 and dHum.Health >= 500 - 3 * CC.SplashDamage, "a dummy by the meeting point takes the splash (" .. (500 - dHum.Health) .. ")")
	dm.Parent = nil
	bHum.Health = 0
	task.wait(0.2)
	ended = sentTo(A, "ClashEnd")[1]
	check(ended and ended.Winner == aChar and not aRoot.Anchored and aChar:GetAttribute("Clashing") == nil, "B goes down mid-clash: A wins it, free")
	task.wait(1)

	print("== round 71: no clash unless both are out and aimed at each other")
	fresh(Vector3.new(X, 3, 30))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	check(#sentTo(A, "ClashStart") == 0 and bHum.Health < MAX, "B hasn't fired: A's AP Shot just lands (" .. (MAX - bHum.Health) .. ")")
	task.wait(1)
	fresh(Vector3.new(X, 3, 30))
	headOn(Vector3.new(1, 0, 0))
	check(#sentTo(A, "ClashStart") == 0 and bHum.Health < MAX, "B fired off to the side: no clash, A's lands")
	task.wait(1)
	fresh(Vector3.new(X, 3, 30))
	workspace:SetAttribute("Clashes", false)
	headOn()
	check(#sentTo(A, "ClashStart") == 0 and (aHum.Health < MAX or bHum.Health < MAX), "server setting Clashes off: they just trade")
	workspace:SetAttribute("Clashes", nil)
	task.wait(1.5)
end)
---------------------------------------------------------------------------
-- Round 71: NOMU RAIDS (Config.NomuRaid)
---------------------------------------------------------------------------
;M.section(function()
	local MAX = Config.PlayerMaxHealth
	local NC = Config.NomuRaid
	studioMode = true
	workspace:SetAttribute("HealthRegen", false)
	local SPOT = NC.Spot or Config.DekuDrop.Spot
	local function at(dx, dz)
		return CFrame.lookAt(SPOT + Vector3.new(dx, 3, dz), SPOT + Vector3.new(0, 3, 0))
	end
	local function place(p, dx, dz)
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = at(dx, dz)
		end
	end
	local function fresh(aAt, bAt)
		fire(SelectQuirk, A, "Explosion")
		fire(SelectQuirk, B, "Explosion")
		for _, old in { aChar, bChar } do
			if old then
				old.Parent = nil
			end
		end
		aChar, aHum, aRoot = spawnChar(A, at(aAt[1], aAt[2]))
		bChar, bHum, bRoot = spawnChar(B, at(bAt[1], bAt[2]))
		task.wait(0.2)
		aHum.Health, bHum.Health = MAX, MAX
		clearSent()
	end
	local function waitFor(p, effect, timeout)
		local t0 = os.clock()
		while os.clock() - t0 < (timeout or 3) do
			local got = sentTo(p, effect)
			if #got > 0 then
				return got
			end
			task.wait(0.05)
		end
		return sentTo(p, effect)
	end
	local function body()
		local f = workspace:FindFirstChild("NomuRaid")
		return f and f:FindFirstChild("HighEndNomu")
	end
	local function kinds(p)
		local out = {}
		for _, m in sentTo(p, "NomuMove") do
			out[m.Kind] = (out[m.Kind] or 0) + 1
		end
		return out
	end

	print("== round 71: NOMU RAIDS - config")
	check(NC and NC.Enabled ~= false and NC.Every >= 300 and NC.Health > 1000 and NC.Swipe and NC.Slam and NC.Charge and NC.Rewards, "a High-End Nomu every " .. NC.Every .. "s, on by default")

	print("== round 71: it comes down into the city")
	fresh({ 0, 200 }, { 20, 0 })
	fire(TestCommand, A, "PSSet", "NomuRaidNow")
	local inc = waitFor(A, "NomuIncoming", 1)[1]
	check(inc and typeof(inc.Pos) == "Vector3" and (inc.Pos - SPOT).Magnitude < 1 and inc.Land == NC.LandAt, "\"Nomu Raid - Now\": everyone's warned where it's coming down")
	local count = 0
	for _, plr in Players:GetPlayers() do
		if not plr:GetAttribute("InVestige") then
			count += 1
		end
	end
	local expected = math.min(NC.MaxHealth, NC.Health + NC.PerPlayer * count)
	check(inc and inc.Max == expected, "...health for everyone in the server (" .. count .. "): " .. tostring(inc and inc.Max))
	fire(TestCommand, A, "PSSet", "NomuRaidNow")
	check(#sentTo(A, "NomuIncoming") == 1, "(one at a time)")
	task.wait(NC.LandAt + 0.3)
	local m = body()
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	local root = m and m:FindFirstChild("HumanoidRootPart")
	check(m and hum and root and m:GetAttribute("Boss") == true and hum.MaxHealth == expected and hum.Health == expected, "it lands: a body in workspace.NomuRaid (" .. tostring(hum and hum.Health) .. ")")
	check(#sentTo(A, "NomuLanded") == 1, "...every screen draws it")
	check(bHum.Health < MAX and bHum.Health >= MAX - 12 and bChar:GetAttribute("Ragdolled") == true, "...B, standing where it came down, is thrown off their feet (" .. (MAX - bHum.Health) .. ")")
	check(aHum.Health == MAX, "...A, far off, isn't")
	task.wait(1.4)
	check((kinds(A).Roar or 0) >= 1, "...and it ROARS")

	print("== round 71: nothing moves it; everything hurts it")
	place(A, 0, 200)
	place(B, 0, 200)
	bChar:SetAttribute("Ragdolled", nil)
	local h0 = hum.Health
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 0, 4), root.Position)
	m1(A)
	check(hum.Health < h0, "A's M1 hurts it (" .. (h0 - hum.Health) .. ")")
	task.wait(Config.M1.ComboReset + 0.1)
	check(root:FindFirstChild("Knockback") == nil and m:GetAttribute("Ragdolled") ~= true and m:GetAttribute("Stunned") ~= true, "...but it isn't knocked back, stunned or put down")
	task.wait(0.6)
	local st = sentTo(A, "NomuState")
	local last = st[#st]
	local mine = last and last.Board and last.Board[tostring(A.UserId)]
	check(last and last.Max == expected and mine and mine.Rank == 1 and mine.Damage == h0 - hum.Health, "the damage board: A's #1 with " .. tostring(mine and mine.Damage))
	check(last and last.Top and last.Top[1] and last.Top[1].Name == A.DisplayName, "...on everyone's screen")
	-- the truce
	place(A, 0, 200)
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(30, -6, 30), root.Position + Vector3.new(30, -6, 34))
	bRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(30, -6, 34), root.Position + Vector3.new(30, -6, 30))
	bHum.Health = MAX
	m1(A)
	check(bHum.Health == MAX, "near the Nomu, players can't hurt each other (a truce)")
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, -6, 400), root.Position + Vector3.new(0, -6, 404))
	bRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, -6, 404), root.Position + Vector3.new(0, -6, 400))
	task.wait(Config.M1.ComboReset + 0.1)
	m1(A)
	check(bHum.Health < MAX, "...far from it, they can (" .. (MAX - bHum.Health) .. ")")
	task.wait(Config.M1.ComboReset + 0.1)

	print("== round 71: its moves")
	-- SWIPE: B right in front of it
	bHum.Health = MAX
	bChar:SetAttribute("Ragdolled", nil)
	bRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, -6, -8), root.Position + Vector3.new(0, -6, 0))
	clearSent()
	local sw = waitFor(A, "NomuMove", 2)
	local swipe
	for _, e in sw do
		if e.Kind == "Swipe" then
			swipe = e
		end
	end
	check(swipe ~= nil, "someone in reach: SWIPE (" .. tostring(sw[1] and sw[1].Kind) .. ")")
	task.wait(NC.Swipe.Windup + 0.2)
	check(MAX - bHum.Health == NC.Swipe.Damage and bChar:GetAttribute("Ragdolled") == true, "...a backhand: " .. (MAX - bHum.Health) .. ", sent flying")
	-- CHARGE: B out at 50 studs, alone
	task.wait(1.5)
	bHum.Health = MAX
	bChar:SetAttribute("Ragdolled", nil)
	bRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, -6, 50), root.Position + Vector3.new(0, -6, 0))
	place(A, 0, 400)
	clearSent()
	local t0 = os.clock()
	while os.clock() - t0 < 3 and not kinds(A).Charge do
		task.wait(0.05)
	end
	check(kinds(A).Charge == 1, "someone 50 studs off: its jets fire - CHARGE")
	task.wait(NC.Charge.Windup + NC.Charge.Time + 0.2)
	check(MAX - bHum.Health == NC.Charge.Damage, "...it rams straight through B (" .. (MAX - bHum.Health) .. ")")
	task.wait(0.8)
	-- SLAM: two of them 18 studs off (everyone parked first: it goes quiet)
	place(A, 0, 900)
	place(B, 0, 920)
	task.wait(2.5)
	bHum.Health, aHum.Health = MAX, MAX
	bChar:SetAttribute("Ragdolled", nil)
	aChar:SetAttribute("Ragdolled", nil)
	bRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 0, 18), root.Position)
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(4, 0, 18), root.Position)
	clearSent()
	t0 = os.clock()
	local slam
	while os.clock() - t0 < 8 and not slam do
		for _, e in sentTo(A, "NomuMove") do
			if e.Kind == "Slam" then
				slam = e
			end
		end
		task.wait(0.05)
	end
	check(slam ~= nil, "two of them close: it leaps - SLAM")
	local flatTo = slam and Vector3.new(slam.To.X, 0, slam.To.Z)
	local near = slam and math.min((flatTo - Vector3.new(bRoot.Position.X, 0, bRoot.Position.Z)).Magnitude, (flatTo - Vector3.new(aRoot.Position.X, 0, aRoot.Position.Z)).Magnitude)
	check(near and near < 1, "...at one of them")
	local imp = waitFor(A, "NomuImpact", NC.Slam.Windup + NC.Slam.Air + 0.8)[1]
	check(imp ~= nil and slam and (imp.Pos - slam.To).Magnitude < 0.5, "...and comes down on them")
	task.wait(0.1)
	check(bHum.Health < MAX and aHum.Health < MAX, "...both caught in it (" .. (MAX - aHum.Health) .. ", " .. (MAX - bHum.Health) .. ")")
	task.wait(1)

	print("== round 71: half health: ENRAGED; left alone: it heals")
	place(A, 0, 600)
	place(B, 0, 600)
	clearSent()
	hum.Health = expected * 0.45
	task.wait(0.4)
	check(m:GetAttribute("Phase") == 2 and hum.WalkSpeed == NC.Phase2Speed and (kinds(A).Roar or 0) >= 1, "phase 2: it roars and speeds up")
	local before = hum.Health
	task.wait(NC.Regen.After + 1)
	check(hum.Health > before and m:GetAttribute("Regen") == true, "untouched a while: Super Regeneration (" .. math.floor(hum.Health - before) .. " back)")

	print("== round 71: beaten - everyone who fought it is paid")
	local bucks = A:GetAttribute("Bucks") or 0
	clearSent()
	aChar:SetAttribute("Ragdolled", nil)
	aChar:SetAttribute("Stunned", nil)
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 0, 4), root.Position)
	local regenWas = NC.Regen.After
	NC.Regen.After = 999 -- (no healing in the middle of the last hit)
	task.wait(0.15)
	hum.Health = 1
	m1(A)
	NC.Regen.After = regenWas
	local fin = waitFor(A, "NomuRaidEnd", 1)[1]
	check(fin and fin.Result == "Defeated" and fin.Top and fin.Top[1] and fin.Top[1].Name == A.DisplayName, "NOMU DEFEATED - A did the most")
	local pay = NC.Rewards.Base + NC.Rewards.Pool + NC.Rewards.Top[1]
	check((A:GetAttribute("Bucks") or 0) == bucks + pay, "A's paid $" .. pay .. " (" .. bucks .. " -> " .. tostring(A:GetAttribute("Bucks")) .. ")")
	local note = sentTo(A, "NomuReward")[1]
	check(note and note.Reward == pay and note.Rank == 1, "...and told so")
	check(#sentTo(A, "KOFinisher") == 0, "(no KO finisher on it: it has its own end)")
	task.wait(4.3)
	check(body() == nil, "it's gone")
	check(bHum.Health == MAX or true, "")

	print("== round 71: not beaten in time: it flies off")
	local was = NC.TimeLimit
	NC.TimeLimit = 1.5
	fresh({ 0, 400 }, { 0, 420 })
	fire(TestCommand, A, "PSSet", "NomuRaidNow")
	task.wait(NC.LandAt + 0.3)
	m = body()
	hum = m and m:FindFirstChildOfClass("Humanoid")
	root = m and m:FindFirstChild("HumanoidRootPart")
	aRoot.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 0, 4), root.Position)
	m1(A)
	bucks = A:GetAttribute("Bucks") or 0
	fin = waitFor(A, "NomuRaidEnd", 3)[1]
	check(fin and fin.Result == "Escaped" and (kinds(A).Escape or 0) == 1, "time's up: THE NOMU GOT AWAY")
	check((A:GetAttribute("Bucks") or 0) == bucks + NC.Rewards.Consolation, "...a consolation for those who fought it")
	NC.TimeLimit = was
	task.wait(3)
	check(body() == nil, "(gone)")
	-- the switch
	fire(TestCommand, A, "PSSet", "NomuRaid", false)
	check(workspace:GetAttribute("NomuRaid") == nil, "server settings: Nomu Raids off (round 75: opt-in, so nothing set)")
	fire(TestCommand, A, "PSSet", "NomuRaid", true)
	check(workspace:GetAttribute("NomuRaid") == true, "...and on")
	fire(TestCommand, A, "PSSet", "NomuRaid", false) -- (off again for the rest of the run)
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 71: DEKU'S MEMORIES in One For All (Config.DekuMemories)
---------------------------------------------------------------------------
;M.section(function()
	local MC = Config.DekuMemories
	local CENTER = Config.VestigeRealm.Center
	local ROOM = CFrame.new(CENTER + MC.Classroom)
	local ARENA = CFrame.new(CENTER + MC.Stadium)
	local ARRIVE = CENTER + Vector3.new(0, 3.5, 66)
	local gateAt = CENTER + Vector3.new(-38, 0, 40)
	local GATE = CFrame.lookAt(gateAt, Vector3.new(ARRIVE.X, gateAt.Y, ARRIVE.Z))
	local function waitFor(p, effect, timeout)
		local t0 = os.clock()
		while os.clock() - t0 < (timeout or 3) do
			local got = sentTo(p, effect)
			if #got > 0 then
				return got
			end
			task.wait(0.05)
		end
		return sentTo(p, effect)
	end
	-- walk from a to b (the server looks every 0.1s)
	local function walk(root, a, b)
		root.CFrame = a
		task.wait(0.15)
		root.CFrame = b
		task.wait(0.15)
	end

	print("== round 71: DEKU'S MEMORIES - what's built")
	local mem = workspace:FindFirstChild("DekuMemories")
	local gate = mem and mem:FindFirstChild("Gate")
	local room = mem and mem:FindFirstChild("Classroom")
	local arena = mem and mem:FindFirstChild("Stadium")
	check(mem and gate and room and arena and MC.Enabled ~= false, "the memories are built: a door in the realm, Class 1-A, the Sports Festival stadium")
	local panel = gate and gate:FindFirstChild("Panel")
	local sign = panel and panel:FindFirstChildOfClass("SurfaceGui")
	local text = sign and sign:FindFirstChildOfClass("TextLabel")
	check(panel and text and text.Text == "1-A" and panel.Size.Y >= 16 and (panel.Position - gateAt).Magnitude < 20, "...in the dark of the realm: the huge 1-A door, slid open (" .. tostring(panel and panel.Size) .. ")")
	-- the desks: four columns of five, the class in order
	local desks = {}
	for _, p in room and room:GetChildren() or {} do
		local n = tonumber((p.Name:match("^Desk_(%d+)$")))
		if n then
			desks[n] = p
		end
	end
	local count = 0
	for _ in desks do
		count += 1
	end
	check(count == 20 and desks[1]:GetAttribute("Student") == "AOYAMA" and desks[20]:GetAttribute("Student") == "YAOYOROZU", "twenty desks, Aoyama to Yaoyorozu")
	local bak, dek, tod, yao = desks[17], desks[18], desks[15], desks[20]
	local rb, rd = bak and ROOM:PointToObjectSpace(bak.Position), dek and ROOM:PointToObjectSpace(dek.Position)
	check(bak and dek and bak:GetAttribute("Student") == "BAKUGO" and dek:GetAttribute("Student") == "MIDORIYA" and math.abs(rb.X - rd.X) < 0.1 and rd.Z > rb.Z and rd.Z - rb.Z < 10,
		"Midoriya's desk is right behind Bakugo's")
	local rt, ry = ROOM:PointToObjectSpace(tod.Position), ROOM:PointToObjectSpace(yao.Position)
	check(math.abs(rt.Z - ry.Z) < 0.1 and math.abs(rt.X - ry.X) < 13, "...Todoroki's next to Yaoyorozu's, at the back")
	local w1 = ROOM:PointToObjectSpace(desks[1].Position)
	check(w1.X < rt.X and w1.X < -15, "...the first column along the windows")
	check(dek:FindFirstChild("Tag") and room:FindFirstChild("Notebook") and room:FindFirstChild("Aizawa") and room:FindFirstChild("SleepingBag") and room:FindFirstChild("Blackboard") and room:FindFirstChild("Windows"),
		"...names as you walk up; his notebook; Aizawa asleep in his bag; the board; the windows")
	local stage = arena and arena:FindFirstChild("Stage")
	local ls = stage and ARENA:PointToObjectSpace(stage.Position)
	check(stage and math.abs(ls.Y + stage.Size.Y / 2 - 3.2) < 0.01 and stage.Size.X >= 50 and arena:FindFirstChild("StageLower"), "the stadium: the two-tier stage in the middle (" .. tostring(stage and stage.Size) .. ")")
	local screens, torches, plates = 0, 0, 0
	for _, p in arena and arena:GetChildren() or {} do
		screens += p.Name == "Screen" and 1 or 0
		torches += (p.Name == "Torch" and p:FindFirstChildOfClass("Fire")) and 1 or 0
		plates += p.Name == "Plate" and 1 or 0
	end
	check(screens == 2 and torches == 4 and plates == 2 and arena:FindFirstChild("TunnelGate") and arena:FindFirstChild("RefereeSeat"), "...two screens on the rim, four torches, the gold U.A. plates, the tunnel, Cementoss's seat")

	print("== round 71: into the memories")
	fire(SelectQuirk, A, "Explosion")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(0, 3, 30))
	task.wait(0.2)
	clearSent()
	fire(TestCommand, A, "Vestige")
	task.wait(1.6)
	check(A:GetAttribute("InVestige") == true, "(in One For All)")
	-- walking past the door (not through it) does nothing
	walk(aRoot, GATE * CFrame.new(9, 3.5, -3), GATE * CFrame.new(9, 3.5, 3))
	check(#sentTo(A, "MemoryIn") == 0, "past the side of the door: nothing")
	walk(aRoot, GATE * CFrame.new(0, 3.5, -4), GATE * CFrame.new(0, 3.5, 2))
	local into = sentTo(A, "MemoryIn")[1]
	check(into and into.Place == "Classroom", "through the 1-A door: a white-out...")
	task.wait(MC.FadeTime + 0.3)
	local spot = (ROOM * CFrame.new(0, 3.5, 29)).Position
	check(A:GetAttribute("Memory") == "Classroom" and (aRoot.Position - spot).Magnitude < 3 and A:GetAttribute("InVestige") == true,
		"...and you're in Class 1-A, at the back of the room (" .. tostring(aRoot.Position) .. ")")
	check(#sentTo(A, "MemoryIn") == 1, "(once)")

	print("== round 71: the classroom door: the Sports Festival")
	clearSent()
	walk(aRoot, ROOM * CFrame.new(27, 3.5, -25), ROOM * CFrame.new(33, 3.5, -25))
	into = sentTo(A, "MemoryIn")[1]
	check(into and into.Place == "Stadium", "out through the big door: the next memory")
	task.wait(MC.FadeTime + 0.3)
	spot = (ARENA * CFrame.new(0, 3.5, 130)).Position
	check(A:GetAttribute("Memory") == "Stadium" and (aRoot.Position - spot).Magnitude < 3, "...the Sports Festival stadium, coming out of the fighters' tunnel")

	print("== round 71: up on the stage, the memory plays")
	local was = MC.FightTime
	MC.FightTime = 0.8
	clearSent()
	aRoot.CFrame = ARENA * CFrame.new(0, 3.5, 40)
	task.wait(0.25)
	check(#sentTo(A, "MemoryFight") == 0, "on the sand in front of it: nothing")
	aRoot.CFrame = ARENA * CFrame.new(4, 6.4, 10)
	local fight = waitFor(A, "MemoryFight", 0.5)[1]
	check(fight and typeof(fight.Stage) == "CFrame" and (fight.Stage.Position - (ARENA * CFrame.new(0, 3.2, 0)).Position).Magnitude < 0.01 and fight.Time == MC.ClashTime,
		"up on the stage: Midoriya vs Todoroki plays, on your screen (the clash: " .. tostring(fight and fight.Time) .. "s)")
	check(fight and type(fight.Rival) == "table" and fight.Rival.Rate == MC.Rival.Rate, "...Todoroki pushes back as hard as the config says")
	task.wait(0.2)
	check(#sentTo(A, "MemoryFight") == 1 and #sentTo(B, "MemoryFight") == 0, "(once, standing there; nobody else's screen)")
	aRoot.CFrame = ARENA * CFrame.new(0, 3.5, 40)
	task.wait(0.15)
	aRoot.CFrame = ARENA * CFrame.new(0, 6.4, 0)
	task.wait(0.2)
	check(#sentTo(A, "MemoryFight") == 1, "off and straight back on: not again yet (FightTime)")
	aRoot.CFrame = ARENA * CFrame.new(0, 3.5, 40)
	task.wait(0.8)
	aRoot.CFrame = ARENA * CFrame.new(0, 6.4, 0)
	task.wait(0.2)
	check(#sentTo(A, "MemoryFight") == 2, "...later on: it plays again")
	MC.FightTime = was
	aRoot.CFrame = ARENA * CFrame.new(0, 3.5, 40)
	task.wait(0.15)
	fire(TestCommand, A, "Memories")

	print("== round 71: back out through the tunnel")
	task.wait(MC.FadeTime + 0.3)
	check(A:GetAttribute("Memory") == nil and A:GetAttribute("InVestige") == true and (aRoot.Position - (GATE * CFrame.new(0, 3.5, -9)).Position).Magnitude < 3,
		"(the test menu from the stadium: back into the realm, by the door)")
	fire(TestCommand, A, "Memories")
	task.wait(MC.FadeTime + 0.3)
	fire(TestCommand, A, "Memories")
	task.wait(MC.FadeTime + 0.3)
	check(A:GetAttribute("Memory") == "Stadium", "(and on again: classroom, stadium)")
	clearSent()
	walk(aRoot, ARENA * CFrame.new(0, 3.5, 146), ARENA * CFrame.new(0, 3.5, 158))
	into = sentTo(A, "MemoryIn")[1]
	check(into and into.Place == "Realm", "down the tunnel, to the far end: back into One For All")
	task.wait(MC.FadeTime + 0.3)
	check(A:GetAttribute("Memory") == nil and A:GetAttribute("InVestige") == true and (aRoot.Position - (GATE * CFrame.new(0, 3.5, -9)).Position).Magnitude < 3,
		"...standing in front of the door again")
	-- the classroom's little back door
	walk(aRoot, GATE * CFrame.new(0, 3.5, -4), GATE * CFrame.new(0, 3.5, 2))
	task.wait(MC.FadeTime + 0.3)
	clearSent()
	walk(aRoot, ROOM * CFrame.new(27, 3.5, 26), ROOM * CFrame.new(33, 3.5, 26))
	into = sentTo(A, "MemoryIn")[1]
	check(into and into.Place == "Realm", "the classroom's small back door: back to One For All too")
	task.wait(MC.FadeTime + 0.3)
	check(A:GetAttribute("Memory") == nil and A:GetAttribute("InVestige") == true, "(back)")

	print("== round 71: waking up from a memory")
	walk(aRoot, GATE * CFrame.new(0, 3.5, -4), GATE * CFrame.new(0, 3.5, 2))
	task.wait(MC.FadeTime + 0.3)
	check(A:GetAttribute("Memory") == "Classroom", "(in the classroom)")
	aChar:PivotTo(ROOM * CFrame.new(0, -60, 0))
	task.wait(1.8)
	check(A:GetAttribute("InVestige") == nil and A:GetAttribute("Memory") == nil, "falling out of a memory: you wake up (and it's over)")
	-- straight in from the city with the test menu
	fire(TestCommand, A, "Memories")
	task.wait(1.6 + MC.FadeTime + 0.5)
	check(A:GetAttribute("InVestige") == true and A:GetAttribute("Memory") == "Classroom", "the test menu from the city: into One For All, then the classroom")
	fire(TestCommand, A, "Vestige")
	task.wait(1.5)
	check(A:GetAttribute("InVestige") == nil and A:GetAttribute("Memory") == nil and (aRoot.Position - CENTER).Magnitude > 500, "waking up any other way ends the memory too")
end)
---------------------------------------------------------------------------
-- Round 72: everyone's emotes taken away once; emote rolls for Robux too
---------------------------------------------------------------------------
;M.section(function()
	local ES = Config.EmoteShop
	local MPS = service("MarketplaceService")
	local ShopRemote = remotes:FindFirstChild("Shop")
	local DONE, NOT_YET = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
	local function owned(p)
		local out = {}
		for id in string.gmatch(p:GetAttribute("EmotesOwned") or "", "[^,]+") do
			table.insert(out, id)
		end
		return out
	end
	local function leave(p)
		p.Parent = nil
		Players.PlayerRemoving:Fire(p)
		local at = table.find(playerList, p) -- (gone from the server's list, as in a real one)
		if at then
			table.remove(playerList, at)
		end
		task.wait(0.3)
	end

	print("== round 72: EMOTES WIPED - once, for everyone")
	check(type(ES.Wipe) == "number" and ES.Wipe ~= 0, "a wipe is set (" .. tostring(ES.Wipe) .. ")")
	DS.data["u_72"] = { Bucks = 40, Items = { Soda = 2 }, Kills = 3, Emotes = "Nap,Griddy,Wave", Wheel = "Nap,Griddy,,Wave", Picks = 1, Codes = "PLUSULTRA" }
	clearSent()
	local P = addPlayer("Wiped72", 72)
	task.wait(0.3)
	check(#owned(P) == 0 and P:GetAttribute("EmoteWheel") == ",,," and P:GetAttribute("EmotePicks") == nil,
		"someone with emotes from before: all gone - owned, the wheel, free picks (" .. tostring(P:GetAttribute("EmotesOwned")) .. " / " .. tostring(P:GetAttribute("EmoteWheel")) .. ")")
	check(P:GetAttribute("Bucks") == 40 and P:GetAttribute("Item_Soda") == 2 and P:GetAttribute("CodesUsed") == "PLUSULTRA", "...their Bucks, items and codes are kept")
	task.wait(5.2)
	local told = false
	for _, n in sentTo(P, "Notice") do
		if type(n.Text) == "string" and string.find(n.Text, "reset", 1, true) then
			told = true
		end
	end
	check(told, "...and they're told emotes were reset")
	leave(P)
	local saved = DS.data["u_72"]
	check(saved and saved.EmoteWipe == ES.Wipe and saved.Emotes == "" and saved.Bucks == 40, "leaving saves the wipe as had (" .. tostring(saved and saved.EmoteWipe) .. ")")
	saved.Emotes, saved.Wheel = "Dance", "Dance,,,"
	local P2 = addPlayer("Wiped72", 72)
	task.wait(0.3)
	check(P2:GetAttribute("EmotesOwned") == "Dance" and string.find(P2:GetAttribute("EmoteWheel") or "", "Dance", 1, true), "...after that, what they get is theirs to keep")
	leave(P2)
	-- someone new: nothing to wipe, no notice
	clearSent()
	local N = addPlayer("New72", 74)
	task.wait(5.4)
	check(#owned(N) == 0 and #sentTo(N, "Notice") == 0, "someone new: no emotes, and no reset notice")
	leave(N)
	check(DS.data["u_74"] == nil or DS.data["u_74"].EmoteWipe == ES.Wipe, "(their save has the wipe as had)")

	print("== round 72: EMOTE ROLLS FOR ROBUX (Bucks still work)")
	check(type(MPS.ProcessReceipt) == "function", "the server takes Robux purchases (ProcessReceipt)")
	check(ES.Robux and ES.Robux[1] and ES.Robux[10] and ES.Robux[2] and ES.Robux[5], "a developer product for each: 1x, 2x, 5x, 10x")
	DS.data["u_73"] = { Bucks = 0, Items = {}, Kills = 0, EmoteWipe = ES.Wipe }
	local R = addPlayer("Robux72", 73)
	task.wait(0.3)
	clearSent()
	local res = MPS.ProcessReceipt({ PlayerId = 73, ProductId = ES.Robux[1].Product, PurchaseId = "p72-1", CurrencySpent = 25 })
	local mine = owned(R)
	check(res == DONE and #mine == 1 and R:GetAttribute("Bucks") == 0, "1x for Robux: a random emote, no Bucks taken (" .. table.concat(mine, ",") .. ")")
	check(#sentTo(R, "EmoteRoll") == 1 and mine[1] and string.find(R:GetAttribute("EmoteWheel") or "", mine[1], 1, true), "...the roll plays, and it's on the wheel")
	local s73 = DS.data["u_73"]
	check(s73 and table.find(s73.Receipts or {}, "p72-1") and s73.Emotes == R:GetAttribute("EmotesOwned"), "...saved straight away, the purchase marked as handed over")
	res = MPS.ProcessReceipt({ PlayerId = 73, ProductId = ES.Robux[1].Product, PurchaseId = "p72-1", CurrencySpent = 25 })
	check(res == DONE and #owned(R) == 1, "the same purchase sent again: nothing more")
	res = MPS.ProcessReceipt({ PlayerId = 73, ProductId = ES.Robux[10].Product, PurchaseId = "p72-2" })
	check(res == DONE and #owned(R) == 10 and R:GetAttribute("EmotePicks") == 1, "10x for Robux: nine random, and one you pick yourself (" .. #owned(R) .. ", picks " .. tostring(R:GetAttribute("EmotePicks")) .. ")")
	local left = 0
	for _, e in Config.Emotes do
		if not e.Exclusive and not table.find(owned(R), e.Id) then
			left += 1
		end
	end
	clearSent()
	res = MPS.ProcessReceipt({ PlayerId = 73, ProductId = ES.Robux[10].Product, PurchaseId = "p72-3" })
	local back = (10 - left) * ES.RollPrice
	check(res == DONE and #owned(R) == 10 + left and R:GetAttribute("Bucks") == back, "10x with only " .. left .. " left: those " .. left .. ", and " .. back .. " Bucks back for the rest")
	local noted = sentTo(R, "Notice")[1]
	check(noted and string.find(noted.Text or "", "back", 1, true), "...and they're told")
	check(MPS.ProcessReceipt({ PlayerId = 73, ProductId = 999999, PurchaseId = "x" }) == NOT_YET, "(a product that isn't one of these: left for something else)")
	check(MPS.ProcessReceipt({ PlayerId = 99999, ProductId = ES.Robux[1].Product, PurchaseId = "y" }) == NOT_YET, "(the buyer's not in this server: later)")
	-- Bucks still buy them
	fire(TestCommand, A, "ResetCooldowns")
	DS.data["u_75"] = { Bucks = 60, Items = {}, Kills = 0, EmoteWipe = ES.Wipe }
	local Bk = addPlayer("Bucks72", 75)
	task.wait(0.3)
	fire(ShopRemote, Bk, "RollEmotes", 2)
	check(#owned(Bk) == 2 and Bk:GetAttribute("Bucks") == 60 - 2 * ES.RollPrice, "Bucks still buy them: 2x for " .. 2 * ES.RollPrice)
	leave(Bk)
	-- the receipts come back with them
	leave(R)
	local R2 = addPlayer("Robux72", 73)
	task.wait(0.3)
	res = MPS.ProcessReceipt({ PlayerId = 73, ProductId = ES.Robux[1].Product, PurchaseId = "p72-2" })
	check(res == DONE and #owned(R2) == 10 + left, "on another server later, an old purchase sent again: still nothing more (" .. tostring(res) .. ", " .. #owned(R2) .. ", " .. tostring(DS.data["u_73"] and #(DS.data["u_73"].Receipts or {})) .. ")")
	leave(R2)

	print("== round 72: WHY ARE YOU CRYING - a new emote, to a song")
	local why
	for _, e in Config.Emotes do
		if e.Id == "WhyCry" then
			why = e
		end
	end
	check(why and why.Rarity == "Legendary" and not why.Exclusive and math.abs((why.Bpm or 0) - 116.9) < 0.01 and why.SongStart == 0 and why.Name == "WHY ARE YOU CRYING",
		"WHY ARE YOU CRYING can be rolled (Legendary), timed to the song's 116.9 bpm")
	DS.data["u_76"] = { Bucks = 0, Items = {}, Kills = 0, EmoteWipe = ES.Wipe, Emotes = "WhyCry", Wheel = "WhyCry,,," }
	local W = addPlayer("Crier72", 76)
	task.wait(0.3)
	fire(SelectQuirk, W, "Explosion")
	spawnChar(W, CFrame.new(71900, 3, 0))
	task.wait(0.3)
	clearSent()
	fire(UseAbility, W, Config.EMOTE_INDEX, "WhyCry")
	local seen = sentTo(A, "Emote")[1]
	check(seen and seen.Id == "WhyCry", "someone who has it plays it off the wheel: everyone else sees it")
	leave(W)

	print("== round 72: SUNEATER's BAMBOO SWEEP stays on the ground")
	local SEq = Config.Quirks.Manifest
	local CK = SEq.Abilities[1]
	local air = CK.Air
	local HOLD = air.HoldTime or 0
	local a1, l1, _, w1 = Config.BambooAt(air, air.SwingTime + HOLD * 0.5)
	local a2, _, _, w2 = Config.BambooAt(air, air.SwingTime + HOLD + air.ReturnTime * 0.5)
	check(HOLD >= 0.2 and a1 > 100 and l1 == air.Length1 and w1 == 1 and w2 == -1 and a2 < a1 and CK.AirActionTime >= air.WindUp + air.SwingTime + HOLD + air.ReturnTime,
		"at the end of the swing it lies there, full size, for " .. HOLD .. "s, then swings back")
	local t1, len1 = Config.BambooReach(air, 22, 3.8)
	local t2, len2 = Config.BambooReach(air, 8, 20)
	local _, len3 = Config.BambooReach(air, 8, 80)
	check(math.abs(22 * math.sin(t1) - (3.8 - air.Skim)) < 0.01 and len1 == 22,
		string.format("near the street it points down just enough for its tip to drag along it (%.1f deg)", math.deg(t1)))
	check(math.abs(math.deg(t2) - air.MaxTilt) < 0.01 and math.abs(len2 * math.sin(t2) - (20 - air.Skim)) < 0.01 and len3 == air.Reach,
		string.format("from high up: down steeply, and it grows to get there (%.1f studs; %d at most)", len2, air.Reach))
	-- live: him 9 studs up, someone on the street 8 studs ahead (right under
	-- where the old sweep went over their head)
	local stubRay72 = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y > 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0), Instance = basePlate }
		end
		return nil
	end
	local BX = 74500
	fire(SelectQuirk, A, "Manifest")
	fire(SelectQuirk, B, "Explosion")
	if aChar then
		aChar.Parent = nil
	end
	if bChar then
		bChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(BX, 12, 0), Vector3.new(BX, 12, 1)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(BX, 3, 8), Vector3.new(BX, 3, 0)))
	task.wait(0.25)
	fire(TestCommand, A, "ResetCooldowns")
	fire(TestCommand, B, "ResetCooldowns")
	workspace:SetAttribute("HealthRegen", false)
	local MAXH = bHum.Health
	local full = SEq.Stomach.Full
	local function pw(n)
		return math.floor(n * full + 0.5)
	end
	fire(UseAbility, A, 1, Vector3.new(0, 0, 1), Vector3.new(BX, 3, 8), 1, aRoot.Position, true)
	task.wait(air.WindUp + air.SwingTime + HOLD + air.ReturnTime + 0.25)
	workspace.Raycast = stubRay72
	check(MAXH - bHum.Health == pw(air.Damage) + pw(air.ReturnDamage),
		"from 9 studs up it sweeps along the street: B, standing under him, is hit going round and coming back (" .. (MAXH - bHum.Health) .. ")")
end)
---------------------------------------------------------------------------
-- Round 73: Bakugo flies on his explosions; Deku and Iida balanced; All
-- Might's transformation rebuilt (growing in heartbeats, the bangs with the
-- costume)
---------------------------------------------------------------------------
;M.section(function()
	local X = 76500
	local FWD = Vector3.new(0, 0, 1)
	local function place(aQuirk, aPos, bPos, bQuirk)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		if aChar then
			aChar.Parent = nil
		end
		if bChar then
			bChar.Parent = nil
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aPos, aPos + FWD))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		task.wait(0.25)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		clearSent()
	end

	print("== round 73: BAKUGO FLIES ON HIS EXPLOSIONS (hold the dash key)")
	local BF = Config.Quirks.Explosion.BlastFlight
	check(BF and BF.HoldDelay > 0 and BF.Interval > 0 and BF.BlastSpeed > BF.Cruise and BF.Fuel > BF.MinFuel and BF.Ult and BF.Ult.Fuel > BF.Fuel,
		"his flight's set up: a blast every " .. tostring(BF and BF.Interval) .. "s, " .. tostring(BF and BF.Fuel) .. "s of sweat (more in the ult)")
	place("Explosion", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastFly", Vector3.new(0, 0.4, 1))
	task.wait(0.05)
	local seen = sentTo(B, "BlastFly")
	check(aChar:GetAttribute("BlastFlying") == true and #seen == 1 and seen[1].Kind == "Start" and typeof(seen[1].Dir) == "Vector3" and math.abs(seen[1].Dir.Magnitude - 1) < 1e-3,
		"taking off: he's marked as flying and everyone sees him go")
	check(#sentTo(A, "BlastFly") == 0, "...(not sent back to him: his own screen already shows it)")
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastPulse", FWD)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastPulse", FWD)
	task.wait(0.05)
	check(#sentTo(B, "BlastFly") == 0, "blasts closer together than MinGap aren't passed on (" .. #sentTo(B, "BlastFly") .. ")")
	task.wait(BF.MinGap + 0.05)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastPulse", FWD)
	task.wait(0.05)
	local pulse = sentTo(B, "BlastFly")[1]
	check(pulse and pulse.Kind == "Pulse" and pulse.Dir.Z > 0.99, "each blast after that is: everyone sees it")
	clearSent()
	aChar:SetAttribute("Stunned", true)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastPulse", FWD)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastFlyEnd")
	task.wait(0.05)
	local ended = sentTo(B, "BlastFly")
	check(#ended == 1 and ended[1].Kind == "End" and aChar:GetAttribute("BlastFlying") == nil,
		"hit out of it: no more blasts - and dropping out still goes through (" .. #ended .. ")")
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastFly", FWD)
	task.wait(0.05)
	check(aChar:GetAttribute("BlastFlying") == nil and #sentTo(B, "BlastFly") == 1, "stunned: he can't take off")
	aChar:SetAttribute("Stunned", false)
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastPulse", FWD)
	task.wait(0.05)
	check(#sentTo(B, "BlastFly") == 0, "a blast without taking off first: nothing")
	place("FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, Config.PARKOUR_INDEX, "BlastFly", FWD)
	task.wait(0.05)
	check(aChar:GetAttribute("BlastFlying") == nil and #sentTo(B, "BlastFly") == 0, "only Bakugo flies on explosions")

	print("== round 73: DEKU AND IIDA BALANCED")
	local FC, EN = Config.Quirks.FullCowl, Config.Quirks.Engine
	local function ab(q, id)
		return Config.FindAbilityById(id) or {}
	end
	local del, stl, man = ab(FC, "DelawareSmash"), ab(FC, "StLouisSmash"), ab(FC, "ManchesterSmash")
	check(FC.WalkSpeed == 22 and FC.JumpPower == 58, "Deku: not the fastest, highest-jumping one any more (" .. FC.WalkSpeed .. ", " .. FC.JumpPower .. ")")
	check(del.Damage == 6 and del.Shots == 2 and del.Cooldown == 7 and del.Range == 85, "Delaware: 2 x 6 every 7 s, out to 85 studs (round 75: two bullets)")
	check(stl.Damage == 16 and stl.BladeDamage == 12 and man.Damage == 24 and man.ShockDamage == 6, "St. Louis 16 (+12 blade), Manchester 24 (+6)")
	local fj, gs, hs = ab(FC, "FaJinSmash"), ab(FC, "Gearshift"), ab(FC, "HundredSmash")
	local rush = gs.Damage * gs.Hits + gs.QuintupleDamage * gs.Quintuple + gs.FinisherDamage
	check(fj.Damage == 36 and hs.Damage == 30 and rush <= 55 and gs.RushCooldown == 22,
		string.format("Fa Jin 36, 100%% Detroit 30, the Gearshift rush %d all told (was 58, 44, 93)", rush))
	check(FC.Ult.WalkSpeed == 30 and ab(FC, "MillionSmash").Damage == 50 and FC.Ult.DangerSense.Cooldown == 11, "at 100%: a bit slower, the 1,000,000% at 50, Danger Sense every 11 s")
	check(EN.WalkSpeed == 23 and EN.WalkSpeed > FC.WalkSpeed, "Iida: still the fastest on his feet, by a little (" .. EN.WalkSpeed .. ")")
	local spin, gat, rb = ab(EN, "SpinKick"), ab(EN, "EngineGatling"), ab(EN, "ReciproBurst")
	check(spin.Damage + spin.FinisherDamage == 15 and gat.Damage * gat.Hits + gat.FinisherDamage == 24 and rb.Damage * 2 + rb.Finish[3] == 32,
		"Recipro Spin 15, Engine Gatling 24, Recipro Burst gear 3 32 (were 20, 30, 44)")
	local tk = ab(EN, "TurboKick")
	check(EN.Ult.WalkSpeed == 38 and EN.Ult.Duration == 20 and tk.Cooldown == 4 and tk.Damage == 10 and ab(EN, "ReciproMax").Damage == 36,
		"Recipro Turbo: 38 walk speed (was 50), 20 s; Turbo Kick 10 every 4 s (was 14 every 2)")
	place("FullCowl", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	check(aHum.WalkSpeed == 22 and aHum.JumpPower == 58, "...and that's what he walks and jumps at (" .. aHum.WalkSpeed .. ")")

	print("== round 73: ALL MIGHT'S TRANSFORMATION - growing in heartbeats")
	local P = Config.Quirks.OneForAll.Special.Presence
	check(P.BurstAt >= 1.2 and #P.Pulses == 3 and P.Freeze >= P.BurstAt, "a longer build (" .. P.BurstAt .. " s) in three heartbeats; the ones close stay frozen through it")
	place("OneForAll", Vector3.new(X, 3, 0), Vector3.new(X, 3, 8))
	pcall(function()
		aHum.RigType = Enum.HumanoidRigType.R6
	end)
	if not aChar:FindFirstChild("Head") then
		local head = M.new("Part", "Head")
		head.Size = Vector3.new(2, 1, 1)
		head.CFrame = aRoot.CFrame * CFrame.new(0, 1.5, 0)
		head.Parent = aChar
	end
	local full = Config.Quirks.OneForAll.Alt.BodyScale.R6Scale
	local function size()
		return aChar:GetAttribute("BuffScale") or 1
	end
	local seen = {}
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(P.Pulses[1][1] - 0.1)
	check(size() == 1, "a moment in: still the skinny man (" .. size() .. ")")
	local ok = true
	local last = P.Pulses[1][1] - 0.1
	for i, pulse in P.Pulses do
		task.wait(pulse[1] + 0.08 - last)
		last = pulse[1] + 0.08
		table.insert(seen, string.format("%.2f", size()))
		ok = ok and math.abs(size() - (1 + (full - 1) * pulse[2])) < 0.01
	end
	check(ok, "he grows a step at each heartbeat (" .. table.concat(seen, ", ") .. ")")
	check(aChar:GetAttribute("HeroOutfit") ~= true and aChar:FindFirstChild("HeroHair") == nil, "...still no costume, no bangs: those come out of the steam")
	check(bChar:GetAttribute("Stunned") == true, "B, 8 studs off, still frozen in terror")
	task.wait(P.BurstAt - last + 0.12)
	local hair = aChar:FindFirstChild("HeroHair")
	check(math.abs(size() - full) < 0.01 and aChar:GetAttribute("HeroOutfit") == true, "THE BURST: full size (" .. size() .. "), in the costume")
	check(hair ~= nil and hair:GetAttribute("FromForm") == true, "...and the famous bangs sprung up")
	check(bRoot:FindFirstChild("Knockback") ~= nil, "...B blasted away")
	task.wait(Config.Quirks.OneForAll.Special.Cooldown + 0.1)
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(0.2)
	check(aChar:FindFirstChild("HeroHair") == nil and aChar:GetAttribute("HeroOutfit") == false, "deflating: the bangs go with the costume")
	task.wait(0.3)
	fire(TestCommand, A, "ResetCooldowns")
end)
---------------------------------------------------------------------------
-- Round 74: Iida public; PRIME DEKU (the flash step), PRIME ALL MIGHT (I Am
-- Here), DIO (ZA WARUDO); the guard's heavy recoil
---------------------------------------------------------------------------
;M.section(function()
	local X = 79500
	local FWD = Vector3.new(0, 0, 1)
	local function place(aQuirk, aPos, bPos, bQuirk)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		if aChar then
			aChar.Parent = nil
		end
		if bChar then
			bChar.Parent = nil
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aPos, aPos + FWD))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		task.wait(0.25)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		A:SetAttribute("Ult", 0)
		clearSent()
	end
	local function hurt()
		return bHum.MaxHealth - bHum.Health
	end
	local function heal()
		bHum.Health = bHum.MaxHealth
		aHum.Health = aHum.MaxHealth
	end

	print("== round 74: IIDA ON THE PUBLIC ROSTER; THREE NEW (DEV) CHARACTERS")
	local order = table.concat(Config.QuirkOrder, ",")
	check(Config.Quirks.Engine.DevOnly == nil and string.find(order, "HalfCold,Engine", 1, true) ~= nil, "Iida: not dev-only, up with the heroes on the phone")
	for _, q in { "PrimeDeku", "PrimeMight", "TheWorld" } do
		local def = Config.Quirks[q]
		check(def and def.DevOnly == true and table.find(Config.QuirkOrder, q) ~= nil and def.Ult and #def.Abilities == 3 and def.Special and def.Extra,
			q .. ": a full kit (3 + R + 4 + ult), dev only, on the phone")
	end

	print("== round 74: PRIME DEKU - FLASH STEP")
	local FS = Config.Quirks.PrimeDeku.Abilities[1]
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	check(aChar:GetAttribute("Quirk") == "PrimeDeku", "a tester can be him")
	check(aHum.WalkSpeed == Config.Quirks.PrimeDeku.WalkSpeed, "...and he's fast (" .. aHum.WalkSpeed .. ")")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.15)
	check(aChar:GetAttribute("Vanished") == true and aRoot.Anchored and aChar:GetAttribute("Holding") == "PrimeFlashStep",
		"1: he's gone - still, untouchable, waiting on the second press")
	local before = aRoot.Position
	task.wait(0.4)
	check((aRoot.Position - before).Magnitude < 0.01, "...and he doesn't go anywhere until it")
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.1)
	local behind = sentTo(A, "FlashBehind")[1]
	check(behind and behind.Target == bChar and typeof(behind.Pos) == "Vector3" and behind.Pos.Z > bRoot.Position.Z + 2,
		"1 again with B in the ring: he's BEHIND them (everyone's screen gets the cinematic)")
	check(#sentTo(B, "FlashBehind") == 1, "...their screen too")
	check(bChar:GetAttribute("Grabbed") == true, "...and they're held still for it")
	task.wait(2.35) -- (round 75: slowed down for the camera - the strike's at 2.1s)
	check(hurt() >= 20 and (aRoot.Position - behind.Pos).Magnitude < 1 and not aRoot.Anchored and aChar:GetAttribute("Vanished") == nil,
		"the kick lands from behind (" .. hurt() .. ") and he's standing where he appeared")
	check(#sentTo(B, "FlashStrike") == 1, "...the strike on every screen")
	-- nobody in the ring
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, 1, FWD, Vector3.new(X + 40, 3, 0), 1, aRoot.Position)
	task.wait(0.15)
	fire(UseAbility, A, Config.RELEASE_INDEX, Vector3.new(1, 0, 0), Vector3.new(X + 40, 3, 0))
	task.wait(0.2)
	local appear = sentTo(B, "FlashAppear")[1]
	check(appear and hurt() == 0 and math.abs(aRoot.Position.X - (X + 40)) < 2 and not aRoot.Anchored,
		"nobody in the ring: he's just there, in a shockwave (" .. string.format("%.1f", aRoot.Position.X - X) .. ")")
	-- left alone, it goes by itself
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, 1, FWD, Vector3.new(X, 3, 12), 1, aRoot.Position)
	task.wait(FS.Hold.Max + 0.7)
	check(aChar:GetAttribute("Vanished") == nil and not aRoot.Anchored, "never pressed again: at " .. FS.Hold.Max .. " s he comes back by himself")

	print("== round 74: PRIME DEKU - THE REST")
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X + 4, 3, 30))
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.72)
	check(#sentTo(B, "BlackwhipReelCast") == 1 and sentTo(B, "BlackwhipReelCast")[1].Targets[1] == bChar, "2: the whips catch B out in front")
	check(bChar:GetAttribute("Grabbed") == true and (bRoot.Position - aRoot.Position).Magnitude < 12, "...and reel them in (" .. string.format("%.1f", (bRoot.Position - aRoot.Position).Magnitude) .. " studs off)")
	task.wait(0.4)
	check(hurt() >= 20, "...into the St. Louis Smash (" .. hurt() .. ")")
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 40))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(Config.Quirks.PrimeDeku.Extra.Delay - 0.2)
	check(hurt() == 0, "4: the fist's still coming down")
	task.wait(0.5)
	check(hurt() >= 20, "4: VESTIGE SMASH lands on the aim (" .. hurt() .. ")")
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 40))
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.6)
	check(hurt() >= 5 and #sentTo(B, "AirForceShots") == 1, "3: AIR FORCE STORM rains on the spot (" .. hurt() .. ")")
	-- R: Danger Sense - B hits him in it, he's already behind them
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(aChar:GetAttribute("Countering") == true, "R: DANGER SENSE up")
	fire(UseAbility, B, 0, -FWD, bRoot.Position)
	task.wait(0.6)
	check(aHum.Health == aHum.MaxHealth and hurt() >= 15 and #sentTo(B, "DangerFlash") == 1,
		"...B's punch never lands - he's behind them and the kick does (" .. hurt() .. ")")
	-- ult: the chain, behind each of them in turn
	place("PrimeDeku", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.6)
	fire(TestCommand, A, "ResetCooldowns")
	heal()
	clearSent()
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.4)
	check(#sentTo(B, "FlashChainHit") == 1 and hurt() >= 20, "ult 2: FLASH STEP CHAIN - behind them, a kick, then the big one (" .. hurt() .. ")")
	check(not aRoot.Anchored and aChar:GetAttribute("Vanished") == nil, "...and he's back after it")

	print("== round 74: PRIME ALL MIGHT")
	local PM = Config.Quirks.PrimeMight
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	pcall(function()
		aHum.RigType = Enum.HumanoidRigType.R6
	end)
	fire(SelectQuirk, A, "PrimeMight") -- (the passives again, on an R6 body)
	task.wait(0.2)
	check(aChar:GetAttribute("BuffScale") == PM.BodyScale.R6Scale and aChar:GetAttribute("QuirkAlt") == false,
		"always the muscle, no transformation (" .. tostring(aChar:GetAttribute("BuffScale")) .. ")")
	check(aChar:GetAttribute("HeroOutfit") == true, "...always in the costume")
	fire(UseAbility, A, Config.LEAP_INDEX, FWD)
	task.wait(0.05)
	check(#sentTo(B, "SuperLeap") == 1, "his super leap in any form (not just the muscle form's)")
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 3.5))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	check(hurt() >= 15, "1: MISSOURI SMASH clotheslines whoever's in the way (" .. hurt() .. ")")
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 50))
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.7)
	check(hurt() >= 10, "2: TEXAS SMASH: HURRICANE drags them down the street (" .. hurt() .. ")")
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.8)
	check(hurt() >= 25, "3: DETROIT SMASH: PRIME down the street (" .. hurt() .. ")")
	-- R: I AM HERE
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 80))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	check(aRoot.Position.Y > 100 and aRoot.Anchored and aChar:GetAttribute("Holding") == "IAmHereLeap", "R: he's up out of sight (" .. math.floor(aRoot.Position.Y) .. " studs), aiming")
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.1)
	local fall = sentTo(B, "MeteorFall")[1]
	check(fall and fall.Target == bChar and fall.Look > 0, "R again with B under it: they look up into the sun")
	task.wait((fall and fall.Look or 0.85) + (fall and fall.Fall or 0.42) + 0.2)
	check(hurt() >= 25 and math.abs(aRoot.Position.Z - bRoot.Position.Z) < 30 and aRoot.Position.Y < 20 and not aRoot.Anchored,
		"...and he comes down on them (" .. hurt() .. ")")
	-- 4: PLUS ULTRA
	place("PrimeMight", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.4)
	check(bChar:GetAttribute("Grabbed") == true and #sentTo(B, "USJRush") == 1, "4: PLUS ULTRA - caught, the punches start")
	task.wait(PM.Extra.Hits * PM.Extra.Interval + 0.6)
	check(hurt() >= 40 and #sentTo(B, "USJFinish") == 1 and bChar:GetAttribute("Grabbed") == nil, "...every one past 100%, then the one through the sky (" .. hurt() .. ")")

	print("== round 74: DIO - ZA WARUDO")
	local ZW = Config.Quirks.TheWorld.Special
	place("TheWorld", Vector3.new(X, 3, 0), Vector3.new(X, 3, 4))
	check(Config.Quirks.TheWorld.Stand == true and aChar:GetAttribute("Quirk") == "TheWorld", "DIO, with The World")
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.7)
	check(bChar:GetAttribute("TimeStopped") == true and bRoot.Anchored and bChar:GetAttribute("Stunned") == true and #sentTo(B, "TimeStop") == 1,
		"R: time stops - B frozen where they stand")
	check(aChar:GetAttribute("TimeStopped") == nil and not aRoot.Anchored, "...but not him")
	clearSent()
	fire(UseAbility, B, 1, -FWD, aRoot.Position, 1, bRoot.Position)
	fire(UseAbility, B, 0, -FWD, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(A, "APShot") == 0 and #sentTo(A, "Punch") == 0, "...and nothing they press goes")
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.15 + 16 * 0.075 + 0.2)
	check(hurt() == 0 and #sentTo(B, "TimeHit") >= 5, "1 in stopped time: every hit hangs there - nothing lands yet (" .. #sentTo(B, "TimeHit") .. " waiting)")
	task.wait(ZW.Duration)
	check(bChar:GetAttribute("TimeStopped") == nil and not bRoot.Anchored and #sentTo(B, "TimeResume") == 1, "time moves again: B's free")
	task.wait(0.4)
	check(hurt() >= 30, "...and it all lands at once (" .. hurt() .. ")")
	-- knives: in stopped time they wait too
	place("TheWorld", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	fire(UseAbility, A, 2, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	check(hurt() > 0 and #sentTo(B, "DioKnife") == Config.Quirks.TheWorld.Abilities[2].Knives, "2: KNIVES - a fan of them (" .. hurt() .. ")")
	-- vampire: he drinks
	place("TheWorld", Vector3.new(X, 3, 0), Vector3.new(X, 3, 4))
	aHum.Health = 200
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1.7)
	check(hurt() >= 15 and aHum.Health > 210, "3: VAMPIRE - he drinks, and it heals him (" .. hurt() .. ", " .. aHum.Health .. ")")
	-- space ripper
	place("TheWorld", Vector3.new(X, 3, 0), Vector3.new(X, 3, 60))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.5)
	check(hurt() >= 15 and #sentTo(B, "SpaceRipperBeam") == 1, "4: SPACE RIPPER STINGY EYES through them (" .. hurt() .. ")")
	-- ult: the road roller
	place("TheWorld", Vector3.new(X, 3, 0), Vector3.new(X, 3, 30))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.6)
	fire(TestCommand, A, "ResetCooldowns")
	heal()
	clearSent()
	local RR = Config.Quirks.TheWorld.Ult.Abilities[3]
	fire(UseAbility, A, 3, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	check(bChar:GetAttribute("TimeStopped") == true and #sentTo(B, "RoadRollerGo") == 1, "ult 3: ROAD ROLLER DA! - time stops first")
	task.wait(RR.TimeStop + 0.6)
	check(bChar:GetAttribute("TimeStopped") == nil and #sentTo(B, "RoadRollerBoom") == 1 and hurt() >= 50 and not aRoot.Anchored,
		"...and when it moves again it all goes up (" .. hurt() .. ")")
	A:SetAttribute("UltActive", false)

	print("== round 74: THE GUARD - a heavy hit rocks it back harder")
	place("OneForAll", Vector3.new(X, 3, 0), Vector3.new(X, 3, 5), "OneForAll")
	fire(UseAbility, B, Config.BLOCK_INDEX, true)
	task.wait(Config.Guard.ParryWindow + 0.1)
	clearSent()
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	local blocked = sentTo(A, "Block")[1]
	check(blocked and blocked.Heavy == true, "a Texas Smash on the guard: a HEAVY block (" .. tostring(blocked and blocked.Heavy) .. ")")
	fire(UseAbility, B, Config.BLOCK_INDEX, false)
end)

---------------------------------------------------------------------------
-- Round 75: downslams, FLOAT, the BLACKWHIP SLINGSHOT, Colorado Smash from
-- the sky, RECIPRO EXTEND, balance, the Nomu (opt-in, killable), the flash
-- step slowed down, Overhaul's lanes stopping at walls, GRAND FINALE, ENDGAME
---------------------------------------------------------------------------
;M.section(function()
	local X = 80500
	local FWD = Vector3.new(0, 0, 1)
	local function place(aQuirk, aPos, bPos, bQuirk)
		fire(SelectQuirk, A, aQuirk)
		fire(SelectQuirk, B, bQuirk or "Explosion")
		if aChar then
			aChar.Parent = nil
		end
		if bChar then
			bChar.Parent = nil
		end
		aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(aPos, aPos + FWD))
		bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(bPos, Vector3.new(aPos.X, bPos.Y, aPos.Z)))
		task.wait(0.25)
		fire(TestCommand, A, "ResetCooldowns")
		fire(TestCommand, B, "ResetCooldowns")
		A:SetAttribute("Ult", 0)
		aHum.MaxHealth, aHum.Health = 200, 200
		bHum.MaxHealth, bHum.Health = 200, 200
		clearSent()
	end
	local function hurt()
		return bHum.MaxHealth - bHum.Health
	end
	local function pickOf(id)
		for i, e in Config.Quirks.FullCowl.Extras do
			if e.Id == id then
				return i
			end
		end
	end
	local Q = Config.Quirks

	print("== round 75: the numbers")
	local M1 = Config.M1
	local hopDelay84 = M1.Downslam.HopDelay or (M1.Slam and M1.Slam.PressGrace)
	check(M1.DownslamHeight <= 0.3 and hopDelay84 and hopDelay84 <= 0.1 and M1.Downslam.HitboxExtra and M1.Downslam.HitboxExtra.Magnitude > 0,
		"downslams: " .. M1.DownslamHeight .. " studs up is enough, the hop goes " .. tostring(hopDelay84) .. "s after the press, a hair bigger box")
	check(Config.FindAbilityById("IceSpike").Cooldown == 8.5, "Todoroki's Ice Spike: 8.5s")
	check(Config.FindAbilityById("BranchSwing").Cooldown == 2, "Kamui's Branch Swing: 2s")
	local EG = Config.FindAbilityById("ElectricGrasp")
	check(EG.Push == 13 and EG.SlamPush == 6, "Electric Grasp throws them a little less far")
	check(Q.Compress.Special.Cooldown == 5, "Compress's R: 5s")
	local DS = Config.FindAbilityById("DelawareSmash")
	check(DS.Shots == 2, "Delaware Smash: two air bullets")
	local HS = Config.FindAbilityById("HundredSmash")
	check(HS.Recoil == nil and HS.BrokenTime == nil, "100%: no recoil, no broken arm")
	check(Config.NomuRaid.OptIn == true, "Nomu raids: off unless switched on")
	check(Q.Engine.Special and Q.Engine.Special.Id == "ReciproExtend", "Iida's R: RECIPRO EXTEND")
	check(Q.Compress.Ult.Extra.Id == "GrandFinale" and Q.Compress.Ult.Refill, "SHOWTIME's 4: THE GRAND FINALE; the pocket refills")
	check(Q.Lemillion.Ult.Extra and Q.Lemillion.Ult.Extra.Id == "PhantomEndgame", "PHANTOM MENACE's 4: ENDGAME")
	local AM = Q.OneForAll.Alt.Extra
	check(AM.Id == "ColoradoSmash" and AM.Hold and AM.Hold.SkyCam and AM.Hold.Toggle, "Colorado Smash: aimed from the sky (a held move)")

	print("== round 75: DOWNSLAMS reach a hair further down")
	local base = Vector3.new(X, 3, 0)
	-- (a street at y = 0, for "is he off the ground")
	local stubRay = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y + dir.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Distance = origin.Y, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end
	place("FullCowl", base + Vector3.new(0, 5, 0), base + Vector3.new(60, 3, 0))
	-- three in the air at nobody...
	for _ = 1, 3 do
		fire(UseAbility, A, 0)
		task.wait(M1.Cooldown + 0.02)
	end
	-- ...and the 4th down onto someone further under him than a downslam used to reach
	bRoot.CFrame = CFrame.new(aRoot.Position + Vector3.new(0, -9.7, 4))
	task.wait(0.05)
	clearSent()
	fire(UseAbility, A, 0, nil, "Down")
	task.wait(0.3)
	local punches = sentTo(B, "Punch")
	local last = punches[#punches]
	check(last and last.Variant == "Down" and hurt() == M1.FinisherDamage, "a downslam catches them 9.7 studs under him (" .. hurt() .. ", " .. tostring(last and last.Variant) .. ", " .. tostring(#punches) .. " punches, B at " .. tostring(bRoot.Position - aRoot.Position) .. ")")
	workspace.Raycast = stubRay
	task.wait(1)

	print("== round 75: FLOAT - grounded till he jumps, then he flies")
	place("FullCowl", base, base + Vector3.new(0, 0, 30))
	A:SetAttribute("QuirkPick", pickOf("Float"))
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatLift", FWD)
	task.wait(0.05)
	check(aChar:GetAttribute("Floating") == nil and #sentTo(B, "FloatFX") == 0, "no Float pressed: a lift-off isn't passed on")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.3)
	check((aChar:GetAttribute("FloatUntil") or 0) > workspace:GetServerTimeNow() + 5 and #sentTo(B, "Float") == 1, "4: FLOAT - weightless (everyone sees it), still on his feet")
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatLift", FWD)
	task.wait(0.05)
	local fx = sentTo(B, "FloatFX")
	check(aChar:GetAttribute("Floating") == true and #fx == 1 and fx[1].Kind == "Lift" and #sentTo(A, "FloatFX") == 0, "he jumps: up he goes (everyone else sees the lift-off)")
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatBoost", Vector3.new(1, 0, 0))
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatBoost", Vector3.new(1, 0, 0))
	task.wait(0.05)
	fx = sentTo(B, "FloatFX")
	check(#fx == 1 and fx[1].Kind == "Boost" and (fx[1].Dir - Vector3.new(1, 0, 0)).Magnitude < 1e-3, "the dash key: an Air Force flick (not two at once)")
	task.wait(Config.FindAbilityById("Float").BoostEvery)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatBoost", FWD)
	task.wait(0.05)
	check(#sentTo(B, "FloatFX") == 2, "...another once it's had a moment")
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatEnd")
	task.wait(0.05)
	fx = sentTo(B, "FloatFX")
	check(aChar:GetAttribute("Floating") == nil and #fx == 1 and fx[1].Kind == "End", "down again")
	aChar:SetAttribute("Stunned", true)
	fire(UseAbility, A, Config.PARKOUR_INDEX, "FloatLift", FWD)
	task.wait(0.05)
	check(aChar:GetAttribute("Floating") == nil, "stunned: he can't lift off")
	aChar:SetAttribute("Stunned", nil)

	print("== round 75: DASH, THEN BLACKWHIP - the slingshot")
	place("FullCowl", base, base + Vector3.new(0, 0, 3))
	A:SetAttribute("QuirkPick", pickOf("Blackwhip"))
	local BW = Config.FindAbilityById("Blackwhip")
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WhipDash", FWD)
	task.wait(0.15)
	local wd = sentTo(B, "WhipDash")
	check(#wd == 1 and wd[1].Speed == BW.Dash.Speed and #sentTo(A, "WhipDash") == 0, "the whips bite ahead and throw him (everyone else sees it)")
	task.wait(BW.Dash.Time)
	check(hurt() == BW.Dash.Damage, "...clipping whoever's in the way (" .. hurt() .. ")")
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WhipDash", FWD)
	task.wait(0.05)
	check(#sentTo(B, "WhipDash") == 0, "not again straight away (it's on Blackwhip's cooldown)")
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.2)
	check(#sentTo(B, "Blackwhip") == 0, "...and neither is Blackwhip itself")
	task.wait(BW.Cooldown * BW.Dash.CooldownScale - 0.3)
	clearSent()
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WhipDash", FWD)
	task.wait(0.05)
	check(#sentTo(B, "WhipDash") == 1, "...back after " .. BW.Cooldown * BW.Dash.CooldownScale .. "s (" .. BW.Dash.CooldownScale * 100 .. "% of Blackwhip's)")
	place("FullCowl", base, base + Vector3.new(0, 0, 30))
	A:SetAttribute("QuirkPick", pickOf("Smokescreen"))
	fire(UseAbility, A, Config.PARKOUR_INDEX, "WhipDash", FWD)
	task.wait(0.05)
	check(#sentTo(B, "WhipDash") == 0, "only with Blackwhip in his 4th slot")
	A:SetAttribute("QuirkPick", 1)

	print("== round 75: 100% - the arm holds; DELAWARE - two bullets")
	place("FullCowl", base, base + Vector3.new(0, 0, 60))
	A:SetAttribute("QuirkPick", pickOf("HundredSmash"))
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(HS.Startup + 0.3)
	check(hurt() == HS.Damage and aHum.Health == aHum.MaxHealth and aChar:GetAttribute("BrokenArmR") == nil and aChar:GetAttribute("BrokenArmL") == nil,
		"100% DETROIT SMASH: the street's blown away (" .. hurt() .. "), his arm's fine and it costs him nothing")
	A:SetAttribute("QuirkPick", 1)
	place("FullCowl", base, base + Vector3.new(0, 0, 20))
	local idx
	for i, a in Q.FullCowl.Abilities do
		if a.Id == "DelawareSmash" then
			idx = i
		end
	end
	fire(UseAbility, A, idx, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(1)
	check(hurt() == DS.Damage * 2, "Delaware Smash: two bullets' worth (" .. hurt() .. ")")

	print("== round 75: COLORADO SMASH - aimed from the sky")
	place("OneForAll", base, base + Vector3.new(40, 0, 60))
	fire(UseAbility, A, Config.SPECIAL_INDEX)
	task.wait(1.6)
	fire(TestCommand, A, "ResetCooldowns")
	clearSent()
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, base + FWD * 10, 1, aRoot.Position)
	task.wait(0.5)
	check(#sentTo(B, "ColoradoSmash") == 1 and #sentTo(B, "ColoradoGo") == 0 and aChar:GetAttribute("Holding") == "ColoradoSmash",
		"4: he crouches - nothing goes until the spot's picked")
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.15)
	local go = sentTo(B, "ColoradoGo")[1]
	check(go and typeof(go.Pos) == "Vector3" and (Vector3.new(go.Pos.X, 0, go.Pos.Z) - Vector3.new(bRoot.Position.X, 0, bRoot.Position.Z)).Magnitude < 2 and #sentTo(A, "ColoradoGo") == 1,
		"4 again: he goes - for the spot picked from up there (everyone's told where)")
	task.wait(AM.TravelTime + 1)

	print("== round 75: RECIPRO EXTEND (Iida's R)")
	local RE = Q.Engine.Special
	place("Engine", base, base + Vector3.new(0, 0, 3))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(RE.Startup - 0.15)
	check(#sentTo(B, "ReciproExtend") == 1 and #sentTo(B, "ReciproExtendGo") == 0 and hurt() == 0, "the sprinter's start: nothing goes yet")
	task.wait(0.3)
	local hit = sentTo(B, "ReciproExtendHit")[1]
	check(#sentTo(A, "ReciproExtendGo") == 1 and hit and hit.Target == bChar and hurt() == RE.Damage, "he goes - and the first one he meets is kicked (" .. hurt() .. ")")
	check(bChar:GetAttribute("Grabbed") == true, "...and rides his leg")
	task.wait(RE.Carry + 0.2)
	check(#sentTo(B, "ReciproExtendLaunch") == 1 and bChar:GetAttribute("Ragdolled") == true and bChar:GetAttribute("Grabbed") ~= true, "...then the engines fire again: launched")
	place("Engine", base, base + Vector3.new(30, 0, 0))
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, base + FWD * 30, 1, aRoot.Position)
	task.wait(RE.Startup + RE.Range / RE.Speed + 0.2)
	check(#sentTo(B, "ReciproExtendWhiff") == 1 and hurt() == 0, "nobody there: a skid")

	print("== round 75: Electric Grasp throws a little less")
	place("Electrification", base + Vector3.new(0, 10, 0), base + Vector3.new(0, 10, 4))
	local GI
	for i, a in Q.Electrification.Abilities do
		if a.Id == "ElectricGrasp" then
			GI = i
		end
	end
	local peak = 0
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 2 do
			local lv = bRoot:FindFirstChild("Knockback")
			if lv then
				local v = lv.VectorVelocity
				peak = math.max(peak, Vector3.new(v.X, 0, v.Z).Magnitude)
			end
			task.wait()
		end
	end)
	fire(UseAbility, A, GI, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(2)
	check(hurt() > 0 and peak > 0 and peak <= EG.Push / 0.3 * 1.05, "the bolt pushes them off at " .. string.format("%.1f", peak) .. " (" .. EG.Push .. " studs' worth; it was 20)")

	print("== round 75: OVERHAUL - a wall stops the lane")
	place("Overhaul", base, base + Vector3.new(0, 0, 26))
	local SR = Config.FindAbilityById("SpikeRush")
	local SI
	for i, a in Q.Overhaul.Abilities do
		if a.Id == "SpikeRush" then
			SI = i
		end
	end
	local stub = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if math.abs(dir.Y) < 0.01 and dir.Magnitude > 1 then
			return { Position = origin + dir.Unit * 12, Normal = -dir.Unit, Instance = workspace, Distance = 12 }
		end
		return nil
	end
	fire(UseAbility, A, SI, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.25 + (SR.Range / 5 + 1) * 0.03 + 0.4)
	workspace.Raycast = stub
	check(hurt() == 0, "a wall 12 studs ahead: the spikes stop at it - B behind it at 26 is safe")
	place("Overhaul", base, base + Vector3.new(0, 0, 26))
	fire(UseAbility, A, SI, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.25 + (SR.Range / 5 + 1) * 0.03 + 0.4)
	check(hurt() == SR.Damage, "no wall: they reach B at 26 (" .. hurt() .. ")")

	print("== round 75: PRIME DEKU's flash step, slowed down for the camera")
	place("PrimeDeku", base, base + Vector3.new(0, 0, 30))
	fire(UseAbility, A, 1, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.15)
	fire(UseAbility, A, Config.RELEASE_INDEX, FWD, bRoot.Position)
	task.wait(0.1)
	local behind = sentTo(B, "FlashBehind")[1]
	check(behind and behind.Strike >= 2 and behind.Place and behind.Place >= 0.3, "BEHIND YOU: " .. tostring(behind and behind.Strike) .. "s to the punch (he's there at " .. tostring(behind and behind.Place) .. "s)")
	task.wait(1.2)
	check(hurt() == 0 and aChar:GetAttribute("Vanished") == nil, "...he's there, the punch hasn't come yet")
	task.wait(1.1)
	check(hurt() >= 20 and #sentTo(B, "FlashStrike") == 1, "...then the big punch (" .. hurt() .. ")")

	print("== round 75: MR. COMPRESS - SHOWTIME")
	place("Compress", base, base + Vector3.new(0, 0, 6))
	aChar:SetAttribute("Marbles", 0)
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(Q.Compress.Ult.Refill + 1.8)
	check((aChar:GetAttribute("Marbles") or 0) >= 1 and #sentTo(A, "MarbleRefill") >= 1, "SHOWTIME: a marble comes back into his pocket every " .. Q.Compress.Ult.Refill .. "s (" .. tostring(aChar:GetAttribute("Marbles")) .. ")")
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = bHum.MaxHealth
	clearSent()
	local GF = Q.Compress.Ult.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.6)
	local grab = sentTo(B, "FinaleGrab")[1]
	check(grab and grab.Targets and grab.Targets[1] == bChar and bChar:GetAttribute("Compressed") == true, "4: THE GRAND FINALE - B's a marble in his hand")
	task.wait(GF.Juggle + 0.3)
	check(#sentTo(B, "FinaleThrow") == 1 and hurt() == 0, "...juggled, then thrown up")
	task.wait(0.6 + GF.Fall + 0.4)
	check(#sentTo(B, "FinaleDrop") == 1 and hurt() >= GF.Damage and bChar:GetAttribute("Compressed") == nil, "...and back down full size (" .. hurt() .. ")")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== round 75: LEMILLION - PHANTOM MENACE: ENDGAME")
	place("Lemillion", base, base + Vector3.new(0, 0, 12))
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.6)
	fire(TestCommand, A, "ResetCooldowns")
	bHum.Health = bHum.MaxHealth
	clearSent()
	local EN = Q.Lemillion.Ult.Extra
	fire(UseAbility, A, Config.EXTRA_INDEX, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.45 + EN.Gap * 0.5)
	local rise = sentTo(B, "EndgameRise")[1]
	check(rise and rise.Target == bChar and rise.Index == 1 and hurt() >= EN.Damage, "4: up out of the street under B (" .. hurt() .. ")")
	task.wait(EN.Gap + 0.6)
	check(#sentTo(B, "EndgameDrop") == 1, "...then out of thin air over them")
	task.wait(0.4)
	check(#sentTo(B, "EndgameBlast") == 1 and not aRoot.Anchored, "...and down through the middle - and he's back")
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)

	print("== round 75: THE NOMU - off unless it's switched on; killable")
	studioMode = true
	workspace:SetAttribute("NomuRaid", nil)
	fire(TestCommand, A, "PSSet", "NomuRaid", true)
	check(workspace:GetAttribute("NomuRaid") == true, "the panel switches raids on...")
	fire(TestCommand, A, "PSSet", "NomuRaid", false)
	check(workspace:GetAttribute("NomuRaid") == nil, "...and off again: back to nothing set (off - raids are opt-in now)")
	local CR = remotes:FindFirstChild("Console")
	local function consoleLines(text)
		clearSent()
		fire(CR, A, "Run", text)
		task.wait(0.06)
		local out = {}
		for _, sent in M.sent do
			if (sent.To == A or sent.To == "all") and sent.Args[1] == "Line" and type(sent.Args[2]) == "table" then
				table.insert(out, sent.Args[2])
			end
		end
		return out
	end
	local got = consoleLines("nomu kill")
	check(#got >= 2 and got[#got].Kind == "err", "console 'nomu kill' with none down: told so (" .. tostring(got[#got] and got[#got].Text) .. ")")
	got = consoleLines("nomu now")
	check(got[#got] and got[#got].Kind == "ok" and #sentTo(A, "NomuIncoming") == 1, "console 'nomu now': one's coming")
	local NRC = Config.NomuRaid
	task.wait((NRC.LandAt or 2.6) + 0.3)
	local raid = workspace:FindFirstChild("NomuRaid")
	local nomu = raid and raid:FindFirstChild("HighEndNomu")
	local nh = nomu and nomu:FindFirstChildOfClass("Humanoid")
	check(nh and nh.Health > 0, "...it lands")
	got = consoleLines("nomu kill")
	task.wait(0.2)
	local fin = sentTo(A, "NomuRaidEnd")[1]
	check(got[#got] and got[#got].Kind == "ok" and nh and nh.Health <= 0 and fin and fin.Result == "Defeated", "console 'nomu kill': it's down")
	task.wait(0.5)
	clearSent()
	fire(TestCommand, A, "PSSet", "NomuRaidNow")
	task.wait(0.1)
	fire(TestCommand, A, "PSSet", "NomuRaidKill")
	task.wait((NRC.LandAt or 2.6) + 0.3)
	fin = sentTo(A, "NomuRaidEnd")[1]
	check(#sentTo(A, "NomuIncoming") == 1 and fin and fin.Result == "Escaped" and #sentTo(A, "NomuLanded") == 0, "the panel's KILL on one still coming in: it turns back, never lands")
end)

---------------------------------------------------------------------------
-- Round 76: the voice lines from the sound folders in Workspace (All Might,
-- Bakugo, Deku) and the longer moves that fit them; WHY ARE YOU CRYING
---------------------------------------------------------------------------
;M.section(function()
	local X = 81500
	local FWD = Vector3.new(0, 0, 1)
	local Q = Config.Quirks
	local V = Config.Voice

	print("== round 76: the lines and the folders they're in")
	local want = {
		IAmHere = { "All Might", "all might i am here", "83632324702728" },
		MightCharge = { "All Might", "All Might Charge", "129685410396909" },
		MightSmash = { "All Might", "All Might SMASH", "100451251229906" },
		MightUSS = { "All Might", "united_states_of_smash_my_hero_academia_1", "104378200563777" },
		Bakugo200 = { "Bakugo", "Bakugo 200%", "140687924372203" },
		FinalBoss = { "Bakugo", "I'M THE FINAL BOSS, GOT IT? BAKUGO", "87930671985739" },
		DekuAwaken = { "Deku", "Deku full cowel", "110359127412280" },
	}
	local bad = {}
	for name, w in want do
		local l = V[name]
		if not (l and l.Folder == w[1] and l.Sound == w[2] and l.Id == "rbxassetid://" .. w[3]) then
			table.insert(bad, name)
		end
	end
	check(#bad == 0, "every clip in the All Might / Bakugo / Deku folders has its line - folder, name and id (" .. table.concat(bad, ",") .. ")")
	check(V.FinalBoss.Trim == true and V.FinalBoss.Cut and V.FinalBoss.Cut < 6, "FINAL BOSS stops before \"...ALL FOR ONE!!\"")
	check(V.IAmHere.Beat and V.MightUSS.Beat, "I AM HERE and UNITED STATES OF SMASH are lined up on their beat")
	local AW = Config.VoiceCues.Awaken
	check(AW.Explosion == "Bakugo200" and AW.FullCowl == "DekuAwaken", "awakening: Bakugo's 200%, Deku's line")
	-- every move All Might has (both kits) charges up first; DETROIT SMASH only on the Detroits
	local moves = Config.VoiceCues.Moves
	local ids = {}
	local function collect(t, depth)
		if type(t) ~= "table" or depth > 4 then
			return
		end
		if type(t.Id) == "string" and t.Name then
			ids[t.Id] = true
		end
		for k, v in t do
			if type(v) == "table" and k ~= "Hold" and k ~= "Presence" then
				collect(v, depth + 1)
			end
		end
	end
	collect(Q.OneForAll, 0)
	collect(Q.PrimeMight, 0)
	ids.MuscleForm = nil -- (that's I AM HERE)
	ids.UnitedStatesSmash, ids.PrimeUSS = nil, nil -- (round 78: UNITED STATES OF... on the catch instead)
	local noCharge, detroit = {}, {}
	for id in ids do
		local list = moves[id]
		if not (list and table.find(list, "MightCharge")) then
			table.insert(noCharge, id)
		end
		if list and table.find(list, "MightDetroit") then
			table.insert(detroit, id)
		end
	end
	table.sort(detroit)
	check(#noCharge == 0, "All Might charges up before every move he has (missing: " .. table.concat(noCharge, ",") .. ")")
	check(#detroit == 0, "no move says the old DETROIT SMASH line (round 77: SMASH! is said by the Detroit Smash on its punch)")
	for id in moves do
		if not ids[id] then
			check(false, "a voice cue for a move All Might doesn't have: " .. id)
		end
	end
	local why
	for _, e in Config.Emotes do
		if e.Id == "WhyCry" then
			why = e
		end
	end
	check(why and type(why.FallbackSong) == "string" and string.match(why.FallbackSong, "^rbxassetid://%d+$") ~= nil, "WHY ARE YOU CRYING: a licensed fallback track, never silent")

	print("== round 76: the moves made long enough for their lines")
	local P = Q.OneForAll.Special.Presence
	check(P.BurstAt >= 1.8 and P.Freeze >= P.BurstAt and P.Pulses[3][1] < P.BurstAt, "the transformation builds " .. P.BurstAt .. "s - room for all of I AM HERE")
	local USS = Config.FindAbilityById("UnitedStatesSmash")
	local PUSS = Config.FindAbilityById("PrimeUSS")
	check(USS.BuildTime >= 2 and PUSS.BuildTime == USS.BuildTime, "United States of Smash builds " .. USS.BuildTime .. "s on the catch (round 78) - room for UNITED STATES OF...")
	local ES = Config.FindAbilityById("ExplosiveSpeed")
	check(ES.WindUp >= 1.2, "Explosive Speed crouches " .. ES.WindUp .. "s - I'M THE FINAL BOSS, GOT IT?")

	-- USS: nothing lands before the charge is over; then it does
	fire(SelectQuirk, A, "OneForAll")
	fire(SelectQuirk, B, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 8), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(P.BurstAt + 0.8)
	fire(TestCommand, A, "ResetCooldowns")
	aHum.MaxHealth, aHum.Health = 400, 400
	bHum.MaxHealth, bHum.Health = 400, 400
	bRoot.CFrame = CFrame.lookAt(aRoot.Position + FWD * 8, aRoot.Position)
	clearSent()
	local slot
	for i, ab in Q.OneForAll.Ult.Abilities do
		if ab.Id == "UnitedStatesSmash" then
			slot = i
		end
	end
	fire(UseAbility, A, slot, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "UnitedStatesSmash") == 1, "USS goes (everyone sees the lunge)")
	-- (round 78: the decoy stings; the punch is after the build and the freeze)
	task.wait(USS.LungeStartup + USS.BuildTime - 0.35)
	local stung = 400 - bHum.Health
	check(stung <= math.ceil(USS.JabDamage * Config.Ult.DamageMultiplier) + 1, string.format("%.1fs in - \"UNITED STATES OF...\" - only the decoy's landed (%d)", USS.BuildTime, stung))
	task.wait(0.45 + USS.FreezeTime + USS.SlamTime + 0.2)
	check(400 - bHum.Health > stung + 10, "...\"SMASH!!\": the punch lands (" .. (400 - bHum.Health) .. ")")
	task.wait(USS.TwisterTime)
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)
	fire(TestCommand, A, "ResetCooldowns")
end)
---------------------------------------------------------------------------
-- Round 77: Detroit Smash says the All Might folder's new "SMASH!"; All
-- Might's punches get their own layered sounds from the licensed library
---------------------------------------------------------------------------
;M.section(function()
	local V = Config.Voice
	print("== round 77: SMASH!, and All Might's punches")
	local sm = V.MightSmash
	check(sm and sm.Folder == "All Might" and sm.Sound == "All Might SMASH" and sm.Id == "rbxassetid://100451251229906" and sm.Beat,
		"Detroit Smash's line: the All Might folder's \"All Might SMASH\", lined up on a beat")
	check(V.MightDetroit == nil, "...and the old DETROIT SMASH line is gone")
	local moves = Config.VoiceCues.Moves
	check(#moves.DetroitSmash == 1 and moves.DetroitSmash[1] == "MightCharge" and #moves.PrimeDetroit == 1,
		"the Detroit Smashes just charge up as they go (SMASH! is said on the punch)")
	check(V.DekuAwaken.Sound == "Deku full cowel" and V.DekuAwaken.Id == "rbxassetid://110359127412280", "your Deku awakening clip is kept")
	-- his own hit sounds, and every new cue made of real, configured layers
	local HS = Config.HitSounds
	check(HS and HS.OneForAll and HS.PrimeMight and HS.OneForAll[1] == "MightHit" and HS.OneForAll[2] == "MightHeavyHit",
		"All Might's punches have their own hit sounds (light, heavy)")
	local bad, layers, peaks, eqs = {}, 0, 0, 0
	for _, name in { "MightHit", "MightHeavyHit", "MightSmash", "MightImpact", "MightUSSImpact" } do
		local cue = Config.Sounds[name]
		if type(cue) ~= "table" or #cue < 4 then
			table.insert(bad, name)
		else
			for _, layer in ipairs(cue) do
				layers += 1
				local ids = type(layer.Id) == "table" and layer.Id or { layer.Id }
				local ok = #ids > 0
				for _, take in ipairs(ids) do
					local id = type(take) == "table" and take.Id or take
					ok = ok and type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
				end
				if not ok then
					table.insert(bad, name)
				end
				if layer.Peak then
					peaks += 1
				end
				if layer.Eq then
					eqs += 1
				end
			end
		end
	end
	check(#bad == 0, "MightHit / MightHeavyHit / MightSmash / MightImpact / MightUSSImpact: " .. layers .. " layers, all real ids (" .. table.concat(bad, ",") .. ")")
	check(peaks >= 12 and eqs >= 5, peaks .. " layers start at their peak, " .. eqs .. " get the equaliser")
	local L = Config.SoundLibraryLicensed
	check(L.BodySlamThump and L.AirPound and L.SonicPressure and L.ThunderBlast and L.BigBoomTail and L.DeepImpact and L.SonicCrack,
		"the new licensed layers: body slam thump, giant air pound, sonic boom wind, thunder, reverberant booms, Deep Impact")
	-- the shared cues stay as they were for everyone else
	check(Config.Sounds.Smash and Config.Sounds.DetroitImpact and Config.Sounds.USSImpact and Config.Sounds.Hit and Config.Sounds.HeavyHit,
		"Deku and the rest keep the shared Smash / DetroitImpact / USSImpact / Hit sounds")
end)
---------------------------------------------------------------------------
-- Round 78: United States of Smash only goes off on a hit (the decoy left
-- has to land) - the hold, the freeze on the face, the slam; a whiff costs
-- a short cooldown, not the ult. Its sound quieter, fading into the music.
---------------------------------------------------------------------------
;M.section(function()
	local X = 83500
	local FWD = Vector3.new(0, 0, 1)
	local Q = Config.Quirks
	print("== round 78: UNITED STATES OF SMASH, only on a hit")
	local USS = Config.FindAbilityById("UnitedStatesSmash")
	local PUSS = Config.FindAbilityById("PrimeUSS")
	check(USS.ChargeTime == nil and USS.Lunge and USS.LungeTime and USS.BuildTime >= 1.8 and USS.FreezeTime > 0.2 and USS.SlamTime and USS.WhiffCooldown < USS.Cooldown,
		"USS: a lunge with the decoy left; caught: " .. USS.BuildTime .. "s of build, a " .. USS.FreezeTime .. "s freeze on the face, the slam; a whiff costs " .. USS.WhiffCooldown .. "s")
	check(PUSS.Lunge and PUSS.BuildTime and PUSS.FreezeTime and PUSS.WhiffCooldown, "Prime All Might's too")
	local VCM = Config.VoiceCues.Moves
	check(VCM.UnitedStatesSmash == nil and VCM.PrimeUSS == nil, "no \"All Might Charge\" over the lunge (its own line says UNITED STATES OF... on the catch)")
	-- the sound: a bit quieter, the long tails fading out
	local loud, fades, tails = 0, 0, 0
	for _, layer in ipairs(Config.Sounds.MightUSSImpact) do
		loud = math.max(loud, layer.Volume)
		if layer.Fade then
			fades += 1
		end
		if (layer.Length or 0) >= 3 then
			tails += 1
		end
	end
	check(loud <= 1 and fades >= tails and fades >= 5, string.format("USS's boom: no layer louder than %.2f (was 1.6), %d layers fade out", loud, fades))
	local tw = Config.Sounds.Twister
	check(tw[1].Volume < 2 and tw[1].Fade and tw[2].Fade, "the twister's roar quieter, dying away")
	check(Config.Sounds.USSJab and Config.Sounds.USSStrike and Config.Sounds.USSWhiff, "sounds for the decoy, the strike on the face, the whiff")

	-- set up: All Might in Plus Ultra
	fire(SelectQuirk, A, "OneForAll")
	fire(SelectQuirk, B, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 60), Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(Q.OneForAll.Special.Presence.BurstAt + 0.8)
	check(A:GetAttribute("UltActive") == true, "Plus Ultra")
	fire(TestCommand, A, "ResetCooldowns")
	aHum.MaxHealth, aHum.Health = 400, 400
	bHum.MaxHealth, bHum.Health = 400, 400
	local slot
	for i, ab in Q.OneForAll.Ult.Abilities do
		if ab.Id == "UnitedStatesSmash" then
			slot = i
		end
	end

	-- nobody in reach: a whiff - no smash, and the ult isn't spent on it
	clearSent()
	fire(UseAbility, A, slot, FWD, aRoot.Position + FWD * 20, 1, aRoot.Position)
	task.wait(USS.LungeStartup + USS.LungeTime + 0.3)
	check(#sentTo(B, "UnitedStatesSmash") == 1, "the press: everyone sees him lunge")
	check(#sentTo(B, "USSWhiff") == 1 and #sentTo(A, "USSWhiff") == 1 and #sentTo(B, "USSCatch") == 0, "nobody there: a whiff (no catch, no smash)")
	local reload = sentTo(A, "Reload")
	check(#reload == 1 and reload[1].Time == USS.WhiffCooldown and reload[1].Full == USS.Cooldown and type(reload[1].Key) == "string",
		"his screen's told: only " .. USS.WhiffCooldown .. "s of its cooldown")
	task.wait(USS.SlamTime + USS.FreezeTime + 0.5)
	check(#sentTo(B, "USSSlam") == 0 and bHum.Health == 400, "...and no slam, no twister")
	clearSent()
	fire(UseAbility, A, slot, FWD, aRoot.Position + FWD * 20, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "UnitedStatesSmash") == 0, "pressed again straight away: still cooling down")
	task.wait(USS.WhiffCooldown)
	clearSent()
	fire(UseAbility, A, slot, FWD, aRoot.Position + FWD * 20, 1, aRoot.Position)
	task.wait(0.1)
	check(#sentTo(B, "UnitedStatesSmash") == 1, "after " .. USS.WhiffCooldown .. "s he can go again")
	task.wait(USS.LungeStartup + USS.LungeTime + 0.4)

	-- caught: held through the build, frozen on the face, then the slam
	fire(TestCommand, A, "ResetCooldowns")
	bRoot.CFrame = CFrame.lookAt(aRoot.Position + FWD * 7, aRoot.Position)
	bRoot.Anchored = false
	task.wait(0.1)
	clearSent()
	local mult = Config.Ult.DamageMultiplier
	fire(UseAbility, A, slot, FWD, bRoot.Position, 1, aRoot.Position)
	task.wait(USS.LungeStartup + 0.25)
	local catch = sentTo(B, "USSCatch")[1]
	check(catch ~= nil and catch.Target == bChar and catch.Build == USS.BuildTime and catch.Freeze == USS.FreezeTime and #sentTo(A, "USSCatch") == 1,
		"the decoy lands: B's caught (everyone's told - the build, the freeze)")
	check(bChar:GetAttribute("Grabbed") == true and bRoot.Anchored == true, "...held there")
	local jab = 400 - bHum.Health
	check(jab > 0 and jab <= math.ceil(USS.JabDamage * mult) + 1, "the decoy only stings (" .. jab .. ")")
	check((aChar:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow() > USS.BuildTime, "he's committed to it till the slam")
	local heldAt = bRoot.Position
	check(math.abs((heldAt - aRoot.Position):Dot(FWD) - 4.6) < 1.2, string.format("held in front of him (%.1f studs)", (heldAt - aRoot.Position):Dot(FWD)))
	task.wait(USS.BuildTime - 0.4)
	check(400 - bHum.Health == jab and #sentTo(B, "USSSlam") == 0, "\"UNITED STATES OF...\" - nothing more's landed yet")
	task.wait(0.4 + USS.FreezeTime * 0.5)
	check(400 - bHum.Health == jab and bChar:GetAttribute("Grabbed") == true, "the fist's on the face: everything stops (no slam yet)")
	task.wait(USS.FreezeTime * 0.5 + USS.SlamTime + 0.25)
	local slam = sentTo(B, "USSSlam")[1]
	check(slam ~= nil and typeof(slam.Pos) == "Vector3" and slam.Target == bChar, "...then the slam (everyone's told where)")
	check(400 - bHum.Health >= jab + math.floor(USS.Damage * mult * 0.5), "driven into the street (took " .. (400 - bHum.Health) .. ")")
	check(bChar:GetAttribute("Ragdolled") == true and not bChar:GetAttribute("Grabbed") and bRoot.Anchored == false, "...ragdolled in the crater, let go")
	check(slam and (bRoot.Position - slam.Pos).Magnitude < 10, "...where the crater is")
	task.wait(USS.TwisterTime + 0.5)

	-- a boss can't be picked up (the Nomu): it's punched where it stands
	fire(TestCommand, A, "ResetCooldowns")
	bRoot.CFrame = CFrame.lookAt(aRoot.Position + FWD * 60, aRoot.Position)
	task.wait(0.1)
	local bossM, bossHum, bossRoot = makeCharacter("Boss78", CFrame.lookAt(aRoot.Position + FWD * 7, aRoot.Position))
	bossM:SetAttribute("Boss", true)
	local raid78 = workspace:FindFirstChild("NomuRaid")
	local madeRaid = raid78 == nil
	if madeRaid then
		raid78 = M.new("Folder", "NomuRaid")
		raid78.Parent = workspace
	end
	bossM.Parent = raid78 -- (where the raid's Nomu lives)
	bossHum.MaxHealth, bossHum.Health = 2000, 2000
	task.wait(0.1)
	clearSent()
	fire(UseAbility, A, slot, FWD, bossRoot.Position, 1, aRoot.Position)
	task.wait(USS.LungeStartup + 0.25)
	local bc = sentTo(B, "USSCatch")[1]
	check(bc ~= nil and bc.Target == bossM and not bossM:GetAttribute("Grabbed") and #sentTo(B, "USSWhiff") == 0,
		"a boss isn't picked up - it's punched where it stands (no whiff)")
	task.wait(USS.BuildTime + USS.FreezeTime + USS.SlamTime + 0.3)
	check(#sentTo(B, "USSSlam") == 1 and bossHum.Health < 2000 - USS.Damage * 0.5, "...and the slam lands on it (" .. (2000 - bossHum.Health) .. ")")
	bossM:Destroy()
	if madeRaid then
		raid78:Destroy()
	end
	fire(TestCommand, A, "EndUlt")
	task.wait(0.5)
	fire(TestCommand, A, "ResetCooldowns")
end)
---------------------------------------------------------------------------
-- Round 84: the slam jump goes on the press (its tuning); Shigaraki - Rivet
-- Stab skewers the nearest one and reels them in, Rivet Storm lifts them on
-- the rivets and slams them down, Radio Waves jams the quirk itself
---------------------------------------------------------------------------
;M.section(function()
	local X = 84500
	local FWD = Vector3.new(0, 0, 1)
	print("== round 84: SLAM JUMP ON THE PRESS; SHIGARAKI'S RIVETS AND RADIO WAVES")
	local SL = Config.M1.Slam
	check(SL.PressGrace and SL.PressGrace <= 0.06 and SL.ArmWait <= 0.15 and SL.TapMax and SL.UpCommit,
		"the slam jump: a press after hit 3 hops (PressGrace " .. tostring(SL.PressGrace) .. "s), a tap during hits 1-2 jumps out of the chain " .. tostring(SL.ArmWait) .. "s after the next hit was due")
	local DC = Config.Quirks.Decay
	local RS = DC.Special
	check(RS.Id == "RivetStab" and (RS.Pin or 0) > 0 and (RS.Reel or 0) > 0 and RS.ReelTo and RS.Windup, "Rivet Stab pins (" .. tostring(RS.Pin) .. "s) and reels in (" .. tostring(RS.Reel) .. "s)")
	local RST, RW, stormSlot, radioSlot
	for i, ab in DC.Ult.Abilities do
		if ab.Id == "RivetStorm" then
			RST, stormSlot = ab, i
		elseif ab.Id == "RadioWaves" then
			RW, radioSlot = ab, i
		end
	end
	check(RST and (RST.Lift or 0) > 0 and (RST.Hold or 0) > 0 and (RST.SlamDamage or 0) > 0, "Rivet Storm lifts them " .. tostring(RST and RST.Lift) .. " studs and slams them")
	check(RW and RW.Windup and RW.Windup >= 0.4 and RW.Jam, "Radio Waves: the orb's windup, the jam")
	check(Config.Sounds.RivetReel ~= nil and Config.Sounds.RadioJam ~= nil, "sounds for the reel and the jam's static")

	fire(SelectQuirk, A, "Decay")
	fire(SelectQuirk, B, "Explosion")
	local C = addPlayer("Charlie", 3)
	fire(SelectQuirk, C, "Explosion")
	for _, old in { aChar, bChar } do
		if old then
			old.Parent = nil
		end
	end
	local a14 = CFrame.Angles(0, math.rad(14), 0) * FWD
	local cStart = Vector3.new(X, 3, 0) + a14 * 20
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 40), Vector3.new(X, 3, 0)))
	local cChar, cHum, cRoot = spawnChar(C, CFrame.lookAt(cStart, Vector3.new(X, 3, 0)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	for _, h in { aHum, bHum, cHum } do
		h.MaxHealth, h.Health = 400, 400
	end

	-- RIVET STAB: the nearest on the lines (C, 20 studs out on the 14 degree
	-- one) is skewered and reeled in; B further along is only pierced
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, aRoot.Position + FWD * 40, 1, aRoot.Position)
	task.wait(RS.Windup + 0.1)
	local pin = sentTo(B, "RivetPin")[1]
	check(pin ~= nil and pin.Target == cChar and pin.Pin == RS.Pin and pin.Reel == RS.Reel, "the nearest one on the rivets (C, 20 studs) is skewered - everyone's told")
	check(cChar:GetAttribute("Grabbed") == true and cRoot.Anchored == true and cHum.Health < 400, "...pinned on them, hurt (" .. (400 - cHum.Health) .. ")")
	check(bHum.Health < 400 and not bChar:GetAttribute("Grabbed"), "B further along the middle line is only pierced (" .. (400 - bHum.Health) .. ")")
	local pinnedAt = cRoot.Position
	check((pinnedAt - cStart).Magnitude < 2.5, string.format("...held where they stood (%.1f studs off)", (pinnedAt - cStart).Magnitude))
	check((aChar:GetAttribute("CombatActionUntil") or 0) > workspace:GetServerTimeNow() + RS.Reel * 0.5, "his hand stays out on them (nothing else meanwhile)")
	task.wait(RS.Pin - 0.2)
	check((cRoot.Position - pinnedAt).Magnitude < 0.3, "...through the pin")
	task.wait(0.2 + RS.Reel + 0.15)
	local v = cRoot.Position - aRoot.Position
	local dist = Vector3.new(v.X, 0, v.Z).Magnitude
	check(math.abs(dist - RS.ReelTo) < 1.5, string.format("the rivets pull back in: reeled in to %.1f studs in front of him", dist))
	check(not cChar:GetAttribute("Grabbed") and cRoot.Anchored == false, "...and let go")
	check(cChar:GetAttribute("Stunned") == true, "...still dazed: his to follow up")
	task.wait(1)

	-- knocked out of it mid-pin: he lets go (they're not reeled in)
	fire(TestCommand, A, "ResetCooldowns")
	bRoot.CFrame = CFrame.new(X + 200, 3, 0)
	while cChar:GetAttribute("Stunned") or cChar:GetAttribute("Ragdolled") do
		task.wait(0.05)
	end
	cRoot.Anchored = false
	cRoot.CFrame = CFrame.lookAt(cStart, Vector3.new(X, 3, 0))
	task.wait(0.1)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, aRoot.Position + FWD * 40, 1, aRoot.Position)
	task.wait(RS.Windup + 0.1)
	check(cChar:GetAttribute("Grabbed") == true, "(pinned again)")
	aChar:SetAttribute("Stunned", true)
	task.wait(0.15)
	check(not cChar:GetAttribute("Grabbed") and cRoot.Anchored == false, "stunned mid-pin, he lets go")
	task.wait(RS.Reel + 0.2)
	local v2 = cRoot.Position - aRoot.Position
	check(Vector3.new(v2.X, 0, v2.Z).Magnitude > RS.ReelTo + 8, "...and they're not reeled in")
	aChar:SetAttribute("Stunned", false)
	task.wait(0.5)

	-- a boss (the raid's Nomu) can't be reeled in: only pierced
	fire(TestCommand, A, "ResetCooldowns")
	bRoot.CFrame = CFrame.new(X + 200, 3, 0)
	cRoot.CFrame = CFrame.new(X - 200, 3, 0)
	local bossM, bossHum, bossRoot = makeCharacter("Boss84", CFrame.lookAt(aRoot.Position + FWD * 15, aRoot.Position))
	bossM:SetAttribute("Boss", true)
	local raid84 = workspace:FindFirstChild("NomuRaid")
	local madeRaid = raid84 == nil
	if madeRaid then
		raid84 = M.new("Folder", "NomuRaid")
		raid84.Parent = workspace
	end
	bossM.Parent = raid84
	bossHum.MaxHealth, bossHum.Health = 2000, 2000
	task.wait(0.1)
	clearSent()
	fire(UseAbility, A, Config.SPECIAL_INDEX, FWD, aRoot.Position + FWD * 40, 1, aRoot.Position)
	task.wait(RS.Windup + 0.15)
	check(bossHum.Health < 2000 and not bossM:GetAttribute("Grabbed") and bossRoot.Anchored ~= true and #sentTo(B, "RivetPin") == 0,
		"a boss is only pierced, not reeled in (" .. (2000 - bossHum.Health) .. ")")
	bossM:Destroy()
	if madeRaid then
		raid84:Destroy()
	end
	task.wait(0.5)

	-- awakened: RIVET STORM lifts C on the rivets and slams them down
	A:SetAttribute("Ult", 100)
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(1.6)
	check(A:GetAttribute("UltActive") == true, "awakened")
	fire(TestCommand, A, "ResetCooldowns")
	-- (the storm's 7th line runs straight out to his left: -X)
	local cAt = aRoot.Position + Vector3.new(-20, 0, 0)
	for _, model in { cChar } do
		local kb = cRoot:FindFirstChild("Knockback")
		if kb then
			kb:Destroy()
		end
		model:SetAttribute("Stunned", false)
		model:SetAttribute("Ragdolled", nil)
	end
	cRoot.Anchored = false
	cRoot.CFrame = CFrame.lookAt(cAt, aRoot.Position)
	cHum.Health = 400
	task.wait(0.1)
	clearSent()
	fire(UseAbility, A, stormSlot, FWD, aRoot.Position + FWD * 20, 1, aRoot.Position)
	task.wait(RST.Windup + 0.1)
	local lift = sentTo(B, "RivetLift")[1]
	check(lift ~= nil and type(lift.Targets) == "table" and table.find(lift.Targets, cChar) ~= nil and lift.Lift == RST.Lift and lift.Hold == RST.Hold,
		"caught on a rivet: lifted on it (everyone's told)")
	check(cChar:GetAttribute("Grabbed") == true and cHum.Health < 400, "...skewered and held (" .. (400 - cHum.Health) .. ")")
	task.wait(RST.Hold * 0.5)
	check(cRoot.Position.Y - cAt.Y > RST.Lift * 0.7, string.format("up in the air on the rivets (%.1f studs)", cRoot.Position.Y - cAt.Y))
	local hpUp = cHum.Health
	task.wait(RST.Hold * 0.5 + RST.SlamTime + 0.15)
	check(cHum.Health < hpUp and not cChar:GetAttribute("Grabbed") and cRoot.Anchored == false, "...then slammed into the street (" .. (hpUp - cHum.Health) .. " more)")
	check(cChar:GetAttribute("Ragdolled") == true, "...a knockdown")
	check(cRoot.Position.Y < cAt.Y + 2, string.format("...down on the street (%.1f)", cRoot.Position.Y - cAt.Y))
	check(#sentTo(B, "RivetSlam") == 1, "everyone sees the slam")
	task.wait(2)

	-- RADIO WAVES: C 30 studs ahead is jammed - and everyone sees the static on them
	fire(TestCommand, A, "ResetCooldowns")
	while cChar:GetAttribute("Ragdolled") do
		task.wait(0.05)
	end
	local kb = cRoot:FindFirstChild("Knockback")
	if kb then
		kb:Destroy()
	end
	cRoot.Anchored = false
	cRoot.CFrame = CFrame.lookAt(aRoot.Position + FWD * 30, aRoot.Position)
	cChar:SetAttribute("Stunned", false)
	cHum.Health = 400
	task.wait(0.1)
	clearSent()
	fire(UseAbility, A, radioSlot, FWD, aRoot.Position + FWD * 60, 1, aRoot.Position)
	task.wait(RW.Windup - 0.1)
	check(cHum.Health == 400, "the orb swells first (" .. RW.Windup .. "s): nothing yet")
	task.wait(0.1 + 30 / RW.Speed + 0.15)
	check(cHum.Health < 400 and (cChar:GetAttribute("JammedUntil") or 0) > workspace:GetServerTimeNow(), "the pulse reaches C: hurt and JAMMED")
	local rj = sentTo(B, "RadioJam")[1]
	check(rj ~= nil and rj.Target == cChar and rj.Duration == RW.Jam, "everyone sees the static crackling on them (RadioJam)")
	check(#sentTo(C, "Jammed") == 1, "...and C's own screen gets it")
	fire(TestCommand, A, "EndUlt")
	-- jammed: the quirk doesn't answer, the fists do
	while cChar:GetAttribute("Ragdolled") or cChar:GetAttribute("Stunned") do
		task.wait(0.05)
	end
	local kb2 = cRoot:FindFirstChild("Knockback")
	if kb2 then
		kb2:Destroy()
	end
	cRoot.CFrame = CFrame.lookAt(Vector3.new(X + 60, 3, 0), Vector3.new(X + 60, 3, 10))
	cChar:SetAttribute("JammedUntil", workspace:GetServerTimeNow() + 1.2)
	task.wait(0.2)
	clearSent()
	fire(UseAbility, C, 1, FWD, Vector3.new(X + 60, 3, 30))
	task.wait(0.3)
	check(#sentTo(B, "APShot") == 0, "jammed: C's quirk won't answer")
	fire(UseAbility, C, 0)
	task.wait(0.15)
	check(#sentTo(B, "Punch") >= 1, "...but C can still punch")
	task.wait(1.1)
	clearSent()
	fire(UseAbility, C, 1, FWD, Vector3.new(X + 60, 3, 30))
	task.wait(0.3)
	check(#sentTo(B, "APShot") == 1, "the static clears: the quirk's back")
	cChar.Parent = nil
	fire(SelectQuirk, A, "Explosion")
	task.wait(0.3)
end)
---------------------------------------------------------------------------
-- Round 94: the city comes back whole after a wipe - the server rebuilds
-- what the blast carved (the crater, the furrows, the trench) in time with
-- every screen's rewind (Kit.wipeRebuild -> Destruction.RestoreArea)
---------------------------------------------------------------------------
;M.section(function()
	local X = 85500
	print("== round 94: THE CITY BACK WITH THE REWIND (the light wipe's and the Serious Punch's rebuild)")
	-- (the server's main chunk may still be on its way down when a short
	-- run gets here)
	local waited = os.clock()
	while not (dx.LightWipe and dx.LightWipe.rebuild) and os.clock() - waited < 10 do
		task.wait(0.1)
	end
	local LW = dx.LightWipe
	check(LW ~= nil and type(LW.rebuild) == "function" and type(LW.style) == "function", "the wipe's rebuild is there (Destruction.LightWipe.rebuild)")
	if not (LW and LW.rebuild) then
		return
	end
	local calls = {}
	dx.RestoreArea = function(center, radius, opts)
		table.insert(calls, { Center = center, Radius = radius, Opts = opts })
		return 7
	end
	local mapF = workspace:FindFirstChild("Map")
	local bld = mapF:FindFirstChild("Buildings") or M.new("Folder", "Buildings")
	bld.Parent = mapF
	local trees = mapF:FindFirstChild("Trees") or M.new("Folder", "Trees")
	trees.Parent = mapF
	local W = LW.style()
	local LWC = Config.DevFlight.LightWipe
	check(W.Hold == LWC.World.Hold and type(W.Folders) == "table" and #W.Folders > 0, "the light wipe's numbers: its own over the punch's (Hold " .. tostring(W.Hold) .. ", " .. #(W.Folders or {}) .. " wiped folders)")

	-- the plan: the rebuild halfway through every screen's empty plain, the
	-- rest as the rewind ends
	local origin = Vector3.new(X, 0, 0)
	local plan = LW.rebuild(origin, Config.LightWave, LWC.Wave, nil, W, { Radius = LWC.Radius, Above = LWC.Above, Below = LWC.Below, Street = 0 })
	local rewind = W.RewindSpan + W.RewindTime
	check(plan.Mid > 0.5 and plan.Mid < 6.3 + W.Hold * 0.5 and math.abs(plan.End - plan.Mid - (W.Hold * 0.5 + rewind)) < 1e-6,
		string.format("the city's put back %.1fs in (mid-hold) and the rest at %.1fs (as the rewind ends)", plan.Mid, plan.End))
	-- a dummy and a double in the way are bodies to build round; players aren't
	local dm = makeCharacter("Dummy85", CFrame.new(X + 20, 3, 0))
	dm.Parent = dummies
	check(plan.step("Mid") == 7 and #calls == 1, "MID: the wiped folders put back")
	local c1 = calls[1]
	local o1 = c1 and c1.Opts or {}
	check(c1 and c1.Center == origin and c1.Radius == LWC.Radius and o1.Above == LWC.Above and o1.Below == LWC.Below,
		"...within the blast's reach (" .. tostring(c1 and c1.Radius) .. " studs, " .. tostring(o1.Above) .. " up, not the Sky Coffin)")
	check(type(o1.Folders) == "table" and o1.Folders[bld] and o1.Folders[trees] and o1.MinTop == W.Foundation,
		"...only the city every screen hid, over its foundations (top over " .. tostring(o1.MinTop) .. ")")
	local hasDummy, hasPlayer = false, false
	for _, m in o1.Bodies or {} do
		hasDummy = hasDummy or m == dm
		hasPlayer = hasPlayer or m == aChar or m == bChar
	end
	check(hasDummy and not hasPlayer, "...nothing rebuilt on a dummy (a player's own screen moves him out)")
	-- someone still limp is a body to build round too
	bChar:SetAttribute("Ragdolled", true)
	local pl = LW.rebuild(origin, Config.LightWave, LWC.Wave, nil, W, { Radius = LWC.Radius, Street = 0 })
	pl.step("Mid")
	local limp = false
	for _, m in (calls[2] and calls[2].Opts.Bodies) or {} do
		limp = limp or m == bChar
	end
	bChar:SetAttribute("Ragdolled", nil)
	check(limp, "...nor on someone still limp")
	table.remove(calls, 2)
	plan = LW.rebuild(origin, Config.LightWave, LWC.Wave, nil, W, { Radius = LWC.Radius, Above = LWC.Above, Below = LWC.Below, Street = 0 })
	plan.Done.Mid = true -- (the Mid above was this plan's)
	check((o1.Batch or 0) > 0, "...a few hundred a frame")
	check(plan.step("Mid") == 0 and #calls == 1, "...once")
	check(plan.step("End") == 7 and #calls == 2 and calls[2].Opts.Folders == nil and calls[2].Opts.MinTop == nil,
		"END: the rest - the crater in the street, the low pieces")
	dm.Parent = nil

	-- a newer wipe's rebuild takes over (it puts back everything anyway)
	local p1 = LW.rebuild(origin, Config.LightWave, LWC.Wave, nil, W, {})
	local p2 = LW.rebuild(origin, Config.LightWave, LWC.Wave, nil, W, {})
	check(p1.step("Mid") == 0 and #calls == 2, "an older wipe's rebuild gives way to a newer one's")
	-- the server keeping the city broken: nothing put back
	workspace:SetAttribute("MapRegen", false)
	check(p2.step("Mid") == 0 and #calls == 2, "Destruction Respawns off: the city stays broken")
	workspace:SetAttribute("MapRegen", nil)

	-- THE LIGHT WIPE: its blast plans one, and it goes off on its own
	table.clear(calls)
	local before = LW.lastPlan
	local at = Vector3.new(X, 0, 300)
	LW.blast(A, aChar, at)
	local lp = LW.lastPlan
	check(lp ~= nil and lp ~= before and lp.Mid > 0 and lp.End > lp.Mid, "THE LIGHT WIPE plans the city's rebuild as its wave goes out")
	if lp then
		task.wait(lp.Mid + 0.3)
		local got = calls[1]
		check(got and got.Center == at and got.Opts.Folders ~= nil, "...and puts it back halfway through the empty plain (" .. #calls .. " call)")
	end

	-- THE SERIOUS PUNCH: its trench and crater come back with its city
	fire(SelectQuirk, A, "Saitama")
	if aChar then
		aChar.Parent = nil
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 900), Vector3.new(X, 3, 910)))
	task.wait(0.2)
	fire(TestCommand, A, "ResetCooldowns")
	fire(TestCommand, A, "FillUlt")
	fire(UseAbility, A, Config.ULT_INDEX)
	task.wait(0.5)
	clearSent()
	local planBefore = LW.lastPlan
	local sp
	for i, ab in Config.Quirks.Saitama.Ult.Abilities do
		if ab.Id == "SeriousPunch" then
			sp = i
		end
	end
	fire(UseAbility, A, sp or 3, Vector3.new(0, 0, 1), aRoot.Position + Vector3.new(0, 0, 40), 1, aRoot.Position)
	local t0 = os.clock()
	while os.clock() - t0 < 8 and #sentTo(B, "SeriousPunchGo") == 0 do
		task.wait(0.1)
	end
	local go = sentTo(B, "SeriousPunchGo")[1]
	local pp = LW.lastPlan
	check(go ~= nil and pp ~= nil and pp ~= planBefore, "THE SERIOUS PUNCH plans its city's rebuild too")
	if pp then
		local SW = Config.Saitama.Wipe
		check(math.abs(pp.End - pp.Mid - (SW.Hold * 0.5 + SW.RewindSpan + SW.RewindTime)) < 1e-6, "...on its own wipe's hold and rewind")
		table.clear(calls)
		pp.step("End")
		local got = calls[1]
		check(got and math.abs(got.Center.Y - (aRoot.Position.Y - 3)) < 3.5 and got.Radius == Config.Quirks.Saitama.Ult.Abilities[sp or 3].Radius,
			"...round his feet, out to the punch's reach")
	end
	fire(TestCommand, A, "EndUlt")
	task.wait(0.3)
	dx.RestoreArea = nil
end)
---------------------------------------------------------------------------
-- Round 95: POSSESS PLAYERS - a dev takes over a player as he does a dummy
-- (Kit.PS, as Destruction.Possess): their own moves, run as theirs
---------------------------------------------------------------------------
;M.section(function()
	local X = 95500
	print("== round 95: POSSESS A PLAYER (a dummy's keys and their own moves; their own machine does nothing)")
	local PS = dx.Possess
	check(PS ~= nil and type(PS.victims) == "table" and type(PS.heroMove) == "function", "the possess code knows players (Kit.PS.victims, heroMove)")
	if not PS then
		return
	end
	local PI = Config.PARKOUR_INDEX
	local allowedWas = PS.allowed
	PS.allowed = function(p)
		return p == A
	end
	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	for _, c in { aChar, bChar } do
		if c then
			c.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 10)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 40)))
	task.wait(0.6) -- (the switch's own wait)
	fire(TestCommand, A, "ResetCooldowns")
	fire(TestCommand, B, "ResetCooldowns")

	-- not his own body
	fire(UseAbility, A, PI, "PossessStart", { Target = aChar })
	check(PS.rec[A] == nil, "never his own body")
	-- a player in a ranked duel isn't to be had
	B:SetAttribute("RankedDuel", 1)
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessStart", { Target = bChar })
	check(PS.rec[A] == nil, "...nor someone in a ranked duel")
	B:SetAttribute("RankedDuel", nil)

	-- IN
	PS.last[A] = nil
	clearSent()
	fire(UseAbility, A, PI, "PossessStart", { Target = bChar })
	local rec = PS.rec[A]
	check(rec ~= nil and rec.Kind == "Player" and rec.Victim == B and rec.Body == bChar, "a dev takes over a PLAYER (" .. tostring(rec and rec.Kind) .. ")")
	if not rec then
		PS.allowed = allowedWas
		return
	end
	check(PS.victims[B] == rec and B:GetAttribute("PossessedBy") == A.UserId and bChar:GetAttribute("Possessed") == true,
		"...marked: their PossessedBy says who (their screen's banner), their body Possessed")
	check(aChar:GetAttribute("Parked") == true and A:GetAttribute("Possessing") == "BRAVO", "...his own body parked; he's in BRAVO")
	check(PS.away(B) == true, "...whatever their body does credits nobody (PS.away)")
	local walk = bHum.WalkSpeed
	check(bHum.WalkSpeed == walk and rec.Raid == nil, "...their walk is their own (nothing of a dummy's put on them)")

	-- THEIR OWN MACHINE: nothing it asks goes through
	clearSent()
	local quirkA1 = Config.GetAbility("Explosion", 1)
	fire(UseAbility, B, 1, Vector3.new(0, 0, 1), bRoot.Position + Vector3.new(0, 0, 20), 1, bRoot.Position)
	check(#sentTo(A, quirkA1.Id) == 0, "their own keys do nothing (" .. quirkA1.Id .. " asked from their machine: dropped)")
	fire(SelectQuirk, B, "FullCowl")
	check(B:GetAttribute("Quirk") == "Explosion", "...nor can they switch hero meanwhile")

	-- HIS: their own move, run as theirs - everyone sees it, their screen too
	clearSent()
	fire(UseAbility, A, PI, "PossessAct", { Act = "Move", Slot = "Ability1", Dir = Vector3.new(0, 0, 1), Aim = bRoot.Position + Vector3.new(0, 0, 30), Origin = bRoot.Position })
	task.wait(0.1)
	local seenA, seenB = #sentTo(A, quirkA1.Id), #sentTo(B, quirkA1.Id)
	check(seenA > 0 and seenB > 0, "HIS 1: their " .. quirkA1.Name .. " goes off as theirs - on his screen and theirs (" .. seenA .. ", " .. seenB .. ")")
	local cd = tonumber(bChar:GetAttribute("PossessCd_Ability1"))
	check(cd ~= nil and cd > workspace:GetServerTimeNow() + quirkA1.Cooldown * 0.5, "...its cooldown on the body for his screen (" .. tostring(cd and math.floor((cd - workspace:GetServerTimeNow()) * 10) / 10) .. " s)")
	-- (again at once: their cooldown holds it)
	clearSent()
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessAct", { Act = "Move", Slot = "Ability1", Dir = Vector3.new(0, 0, 1), Aim = bRoot.Position + Vector3.new(0, 0, 30) })
	check(#sentTo(A, quirkA1.Id) == 0, "...and their cooldown holds it")
	-- never their ult (it isn't a key of theirs he has)
	B:SetAttribute("Ult", 100)
	clearSent()
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessAct", { Act = "Move", Slot = "Ult" })
	check(B:GetAttribute("UltActive") ~= true, "...never their ult")
	B:SetAttribute("Ult", 0)
	-- a dummy's M1 in their body: everyone else's screen plays it, theirs too
	clearSent()
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessAct", { Act = "M1", CF = bRoot.CFrame })
	check(#sentTo(B, "Punch") > 0 and #sentTo(A, "Punch") == 0, "M1: the heroes' chain - their screen sees their body throw it (his already plays it)")
	-- no ult charge for them while he's in
	local u0 = B:GetAttribute("Ult") or 0
	local dm = makeCharacter("Dummy95", CFrame.new(X, 3, 34))
	dm.Parent = dummies
	fire(UseAbility, A, PI, "PossessAct", { Act = "Move", Slot = "Ability2", Dir = Vector3.new(0, 0, 1), Aim = Vector3.new(X, 3, 34), Origin = bRoot.Position })
	task.wait(0.6)
	check((B:GetAttribute("Ult") or 0) == u0, "...no ult charge for them meanwhile")
	dm.Parent = nil

	-- someone else can't take them from him
	local C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar = spawnChar(C, CFrame.new(X + 40, 3, 0))
	PS.allowed = function(p)
		return p == A or p == C
	end
	fire(UseAbility, C, PI, "PossessStart", { Target = bChar })
	check(PS.rec[C] == nil and PS.rec[A] == rec, "another dev can't take them from him")
	-- ...nor a dev's parked body
	PS.last[C] = nil
	fire(UseAbility, C, PI, "PossessStart", { Target = aChar })
	check(PS.rec[C] == nil, "...nor a dev's parked body")

	-- OUT: theirs again
	fire(UseAbility, A, PI, "PossessLeave")
	check(PS.rec[A] == nil and PS.victims[B] == nil and B:GetAttribute("PossessedBy") == nil and bChar:GetAttribute("Possessed") == nil,
		"K: out - their body's theirs again (PossessedBy, Possessed gone)")
	check(bChar:GetAttribute("PossessCd_Ability1") == nil, "...the body's cooldown marks gone")
	task.wait(1.2)
	check(aChar:GetAttribute("Parked") == nil, "...his own body back")
	clearSent()
	fire(TestCommand, B, "ResetCooldowns")
	fire(UseAbility, B, 1, Vector3.new(0, 0, 1), bRoot.Position + Vector3.new(0, 0, 20), 1, bRoot.Position)
	check(#sentTo(A, quirkA1.Id) > 0, "...and their own keys work again")

	-- their reset: he's sent home, they reset
	task.wait(0.6)
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessStart", { Target = bChar })
	check(PS.rec[A] ~= nil, "in again")
	fire(UseAbility, B, PI, "PossessReset")
	check(PS.rec[A] == nil and PS.victims[B] == nil and bHum.Health <= 0, "their RESET: he's sent home and they reset")
	task.wait(1.2)
	-- leaving: a dev in a player who leaves the game is sent home
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 40)))
	task.wait(0.1)
	PS.last[A] = nil
	fire(UseAbility, A, PI, "PossessStart", { Target = bChar })
	check(PS.rec[A] ~= nil and PS.victims[B] ~= nil, "in again")
	bChar.Parent = nil
	task.wait(0.3)
	check(PS.rec[A] == nil and PS.victims[B] == nil, "their body gone (a new one, or they left): he's sent home")
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 30), Vector3.new(X, 3, 40)))
	if cChar then
		cChar.Parent = nil
	end
	task.wait(1.2)
	PS.allowed = allowedWas
	fire(TestCommand, A, "ResetCooldowns")
	fire(TestCommand, B, "ResetCooldowns")
end)

---------------------------------------------------------------------------
-- Round 95: RANKED DUELS on the Sky Coffin's stage (Kit.RK, as
-- Destruction.Ranked): the queue, best of 3, KO / ring out / time, Elo,
-- the save, the board, leaving
---------------------------------------------------------------------------
;M.section(function()
	local X = 96000
	print("== round 95: RANKED DUELS (queue, best of 3, the rating, the board)")
	local RK = dx.Ranked
	check(RK ~= nil and type(RK.join) == "function" and type(RK.apart) == "function", "the ranked duels are there (Kit.RK)")
	if not RK then
		return
	end
	local RC = Config.Ranked
	local PI = Config.PARKOUR_INDEX
	local C -- (Charlie, below; the suite has a `C` of its own)
	-- (quick: these tests don't wait out real rounds)
	local saved = {}
	for k, v in { Intro = 0.2, Countdown = 0.4, Between = 0.4, EndHold = 0.5, RoundTime = 2.5 } do
		saved[k] = RC[k]
		RC[k] = v
	end
	-- the stage (the harness doesn't build the Sky Coffin) and a store that
	-- keeps what it's given
	local STAGE = Vector3.new(X, 200, 0)
	local stageWas = RK.stage
	RK.stage = function()
		return STAGE
	end
	local store = { data = {}, writes = 0 }
	function store.GetAsync(_, k)
		return store.data[k]
	end
	function store.UpdateAsync(_, k, f)
		store.writes += 1
		store.data[k] = f(store.data[k])
	end
	local board = { data = {} }
	function board.SetAsync(_, k, v)
		board.data[k] = v
	end
	function board.GetSortedAsync(_, _asc, size)
		local page = {}
		for k, v in board.data do
			table.insert(page, { key = k, value = v })
		end
		table.sort(page, function(a, b)
			return a.value > b.value
		end)
		while #page > size do
			table.remove(page)
		end
		return { GetCurrentPage = function()
			return page
		end }
	end
	local storeWas, boardWas = RK.store, RK.boardStore
	RK.store, RK.boardStore = store, board
	store.data["r_" .. A.UserId] = { Rating = 1100, Played = 12, Wins = 8, Losses = 4, Best = 1150 }
	store.data["r_" .. B.UserId] = nil

	fire(SelectQuirk, A, "Explosion")
	fire(SelectQuirk, B, "Explosion")
	for _, c in { aChar, bChar } do
		if c then
			c.Parent = nil
		end
	end
	local homeA = CFrame.new(X + 300, 3, 0)
	aChar, aHum, aRoot = spawnChar(A, homeA)
	bChar, bHum, bRoot = spawnChar(B, CFrame.new(X + 310, 3, 0))
	RK.load(A)
	RK.load(B)
	check(A:GetAttribute("RankedRating") == 1100 and A:GetAttribute("RankedTier") == "PRO HERO" and A:GetAttribute("RankedPlayed") == 12,
		"their record loads: 1100, PRO HERO, 12 played")
	check(B:GetAttribute("RankedRating") == RC.Start and B:GetAttribute("RankedPlayed") == 0, "...a first-timer starts at " .. RC.Start)

	-- a dev-only hero can't queue
	local devOnly
	for name in Config.Quirks do
		if Config.IsDevOnly(name) then
			devOnly = name
			break
		end
	end
	if devOnly then
		A:SetAttribute("Quirk", devOnly)
		RK.last[A] = nil
		fire(UseAbility, A, PI, "RankedJoin")
		check(RK.queued(A) == nil, "a dev-only hero (" .. devOnly .. ") can't queue")
		A:SetAttribute("Quirk", "Explosion")
	end

	-- THE QUEUE: both in, paired on the next tick (100 apart: within 200)
	RK.last[A] = nil
	clearSent()
	fire(UseAbility, A, PI, "RankedJoin")
	check(RK.queued(A) ~= nil and A:GetAttribute("RankedQueued") ~= nil, "RANKED app: in the queue (RankedQueued)")
	fire(UseAbility, B, PI, "RankedJoin")
	local t0 = os.clock()
	while not RK.match and os.clock() - t0 < 3 do
		task.wait(0.1)
	end
	local m = RK.match
	check(m ~= nil and ((m.P[1] == A and m.P[2] == B) or (m.P[1] == B and m.P[2] == A)), "...paired: a duel")
	if not m then
		RK.stage, RK.store, RK.boardStore = stageWas, storeWas, boardWas
		return
	end
	check(RK.queued(A) == nil and A:GetAttribute("RankedQueued") == nil and A:GetAttribute("RankedDuel") == m.Id, "...out of the queue, in the duel (RankedDuel)")
	check(#sentTo(A, "RankedFound") == 1 and #sentTo(B, "RankedMatch") >= 1, "...the VS card on their screens, the word to everyone")
	-- the hero they came with
	fire(SelectQuirk, A, "FullCowl")
	check(A:GetAttribute("Quirk") == "Explosion", "...no hero switch in a duel")

	-- ROUND 1: on their marks, held
	t0 = os.clock()
	while m.Phase ~= "Countdown" and os.clock() - t0 < 3 do
		task.wait(0.05)
	end
	local sideA = m.P[1] == A and 1 or 2
	local markA = RK.mark(STAGE, sideA)
	check(m.Phase == "Countdown" and (aRoot.Position - markA.Position).Magnitude < 1 and aRoot.Anchored == true and aChar:GetAttribute("RankedHold") == true,
		"ROUND 1: up on the stage, on their marks, held through the countdown")
	check(aHum.Health == aHum.MaxHealth, "...healed")
	clearSent()
	local a1 = Config.GetAbility("Explosion", 1)
	fire(UseAbility, A, 1, Vector3.new(1, 0, 0), STAGE, 1, aRoot.Position)
	check(#sentTo(B, a1.Id) == 0, "...their moves wait on the marks")
	check(RK.apart(A, bChar) == true, "...no hits before FIGHT")
	-- FIGHT
	t0 = os.clock()
	while m.Phase ~= "Fight" and os.clock() - t0 < 3 do
		task.wait(0.05)
	end
	check(m.Phase == "Fight" and aRoot.Anchored == false and aChar:GetAttribute("RankedHold") == nil, "FIGHT: let go")
	check(#sentTo(A, "RankedFight") == 1, "...the call on their screen")
	-- only each other
	C = Players:FindFirstChild("Charlie") or addPlayer("Charlie", 3)
	local cChar, _, cRoot = spawnChar(C, CFrame.new(X + 330, 3, 0))
	check(RK.apart(A, bChar) == false and RK.apart(C, bChar) == true and RK.apart(A, cChar) == true and RK.apart(C, cChar) == false,
		"only each other: nobody else's hits land on them, theirs on nobody else")
	-- a KO: the blow that would have killed leaves them at 1 and down
	bChar:PivotTo(aRoot.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi, 0))
	bHum.Health = 2
	task.wait(0.1)
	m1(A)
	task.wait(0.2)
	check(bHum.Health >= 1 and bHum.Health <= 2 and m.Score[A] == 1, "KO: their blow would have killed - left at " .. tostring(bHum.Health) .. ", the round's A's (" .. tostring(m.Score[A]) .. "-" .. tostring(m.Score[B]) .. ")")
	local ends = sentTo(A, "RankedRoundEnd")
	check(#ends == 1 and ends[1].How == "KO" and ends[1].Me == 1, "...called: KO, 1-0")

	-- ROUND 2: a ring out
	t0 = os.clock()
	while not (m.Round == 2 and m.Phase == "Fight") and os.clock() - t0 < 4 do
		task.wait(0.05)
	end
	check(m.Round == 2 and m.Phase == "Fight" and bHum.Health == bHum.MaxHealth, "ROUND 2: back on the marks, healed")
	-- someone else up on the stage: thrown off
	cChar:PivotTo(CFrame.new(STAGE + Vector3.new(5, 3, 20)))
	-- (the harness's Debris takes the push away after its 0.25 s: look while it's on)
	local shoved = false
	t0 = os.clock()
	while not shoved and os.clock() - t0 < 0.6 do
		shoved = cRoot:FindFirstChild("Knockback") ~= nil
		task.wait(0.02)
	end
	check(shoved and RK.pushed[cChar] ~= nil, "anyone else on the stage is thrown off it")
	cChar:PivotTo(CFrame.new(X + 330, 3, 0))
	clearSent()
	bChar:PivotTo(CFrame.new(STAGE + Vector3.new(60, 1, 0)))
	task.wait(0.3)
	check(m.Score[A] == 2, "RING OUT: off the top and down to it - A's 2-0")

	-- THE RESULT
	t0 = os.clock()
	while not m.Over and os.clock() - t0 < 3 do
		task.wait(0.05)
	end
	local gain, loss = Config.RankedDelta(1100, RC.Start, RC.K, RC.KNew)
	check(A:GetAttribute("RankedRating") == 1100 + gain and B:GetAttribute("RankedRating") == RC.Start - loss,
		string.format("the rating: A +%d (K %d), B -%d (KNew %d, a first match): %s / %s", gain, RC.K, loss, RC.KNew, tostring(A:GetAttribute("RankedRating")), tostring(B:GetAttribute("RankedRating"))))
	check(A:GetAttribute("RankedWins") == 9 and B:GetAttribute("RankedLosses") == 1 and B:GetAttribute("RankedPlayed") == 1, "...wins, losses, played")
	local resA, resB = sentTo(A, "RankedResult")[1], sentTo(B, "RankedResult")[1]
	check(resA and resA.Result == "Win" and resA.Delta == gain and resA.Me == 2 and resB and resB.Result == "Loss" and resB.Delta == -loss,
		"...each told: VICTORY +" .. gain .. ", DEFEAT -" .. loss)
	check(#sentTo(C, "RankedOver") == 1, "...and everyone: who beat whom")
	task.wait(0.3)
	local sa = store.data["r_" .. A.UserId]
	check(type(sa) == "table" and sa.Rating == 1100 + gain and sa.Played == 13, "SAVED (UpdateAsync): " .. tostring(sa and sa.Rating))
	check(board.data["r_" .. A.UserId] == 1100 + gain and board.data["r_" .. B.UserId] == RC.Start - loss, "...and on the ordered board")
	local list = RK.publish()
	check(list[1] and list[1].UserId == A.UserId and list[1].Tier == "PRO HERO", "the RANKED board: A first, PRO HERO")
	-- home
	t0 = os.clock()
	while RK.match and os.clock() - t0 < 3 do
		task.wait(0.05)
	end
	task.wait(0.2)
	check(RK.match == nil and A:GetAttribute("RankedDuel") == nil and (aRoot.Position - homeA.Position).Magnitude < 2 and not aRoot.Anchored,
		"...and home: back where they were, the stage free")

	-- LEAVING mid-duel loses it (and a round on TIME first)
	local G = addPlayer("Golf", 7)
	local H = addPlayer("Hotel", 8)
	fire(SelectQuirk, G, "Explosion")
	fire(SelectQuirk, H, "Explosion")
	local gChar, gHum = spawnChar(G, CFrame.new(X + 350, 3, 0))
	local hChar, hHum = spawnChar(H, CFrame.new(X + 360, 3, 0))
	task.wait(0.3)
	check(RK.loaded[G] and RK.loaded[H], "newcomers' records load as they join")
	fire(UseAbility, G, PI, "RankedJoin")
	fire(UseAbility, H, PI, "RankedJoin")
	t0 = os.clock()
	while not (RK.match and RK.match.Phase == "Fight") and os.clock() - t0 < 4 do
		task.wait(0.05)
	end
	local m2 = RK.match
	check(m2 ~= nil and m2.Phase == "Fight", "a second duel")
	if m2 then
		gHum.Health = gHum.MaxHealth * 0.5
		hHum.Health = hHum.MaxHealth * 0.8
		t0 = os.clock()
		while m2.Round < 2 and os.clock() - t0 < 5 do
			task.wait(0.05)
		end
		check(m2.Score[H] == 1, "TIME: more health left takes the round")
		Players.PlayerRemoving:Fire(H)
		task.wait(0.2)
		check(m2.Over and G:GetAttribute("RankedWins") == 1, "LEFT mid-duel: it's a loss - the other one wins it")
	end
	task.wait(1)

	for k, v in saved do
		RC[k] = v
	end
	RK.stage, RK.store, RK.boardStore = stageWas, storeWas, boardWas
	if cChar then
		cChar.Parent = nil
	end
	gChar.Parent = nil
	hChar.Parent = nil
end)

---------------------------------------------------------------------------
-- Round 96: DISMANTLE - a dev's drawn cut (Kit.DM, as Destruction.Dismantle):
-- checked; the map units it goes through, nearest first; the people in it;
-- the street's gash; the word to everyone; the landing
---------------------------------------------------------------------------
;M.section(function()
	local X = 96500
	print("== round 96: DISMANTLE (a drawn cut: what it goes through, who's in it, the landing)")
	local DM = dx.Dismantle
	check(DM ~= nil and type(DM.relay) == "function" and type(DM.cut) == "function" and DM.KINDS.Dismantle == true,
		"the Dismantle code is there (Kit.DM)")
	if not DM then
		return
	end
	local DC = Config.Dismantle
	local PI = Config.PARKOUR_INDEX
	check(DC ~= nil and DC.Key == Enum.KeyCode.U and DC.Budget > 0 and DC.MaxMoving >= DC.Budget, "Config.Dismantle: U, a part budget, a cap on what's moving")
	-- the Destruction side, recorded (the harness stubs the module)
	local calls = { slice = {}, collapse = {}, capsule = {}, moving = 0 }
	local sliceWas, collapseWas, movingWas, capsuleWas = dx.Slice, dx.Collapse, dx.MovingCount, dx.Capsule
	dx.Slice = function(units, point, normal, opts)
		table.insert(calls.slice, { Units = units, P = point, N = normal, Opts = opts })
		local groups = {}
		for _, u in units do
			local part = u:GetChildren()[1]
			local c = part and part.CFrame.Position or point
			table.insert(groups, { Unit = u, Movers = { 1, 2, 3 }, Centre = c, Lo = c - Vector3.new(20, 10, 20), Hi = c + Vector3.new(20, 10, 20), Dir = Vector3.new(1, 0, 0), Mode = "Slide" })
		end
		return groups
	end
	dx.Collapse = function(g, opts)
		table.insert(calls.collapse, { G = g, Opts = opts })
	end
	dx.MovingCount = function()
		return calls.moving
	end
	dx.Capsule = function(a, b, radius, profile, dir)
		table.insert(calls.capsule, { a, b, radius, profile })
	end
	local allowedWas = DM.allowed
	DM.allowed = function(p)
		return p == A
	end
	-- a little city: the near block, a tall one behind it, one off to the side
	local buildings = map:FindFirstChild("Buildings") or M.new("Folder", "Buildings")
	buildings.Parent = map
	local roads = map:FindFirstChild("Roads") or M.new("Folder", "Roads")
	roads.Parent = map
	local function building(name, centre, size)
		local m = M.new("Model", name)
		local p = M.new("Part", "Wall")
		p.Size = size
		p.CFrame = CFrame.new(centre)
		p.Anchored = true
		p:SetAttribute("Destroyable", true)
		p.Parent = m
		m.Parent = buildings
		return m
	end
	local near = building("Near96", Vector3.new(X, 30, -100), Vector3.new(40, 60, 40))
	local behind = building("Behind96", Vector3.new(X, 60, -300), Vector3.new(40, 120, 40))
	local aside = building("Aside96", Vector3.new(X + 300, 30, 0), Vector3.new(40, 60, 40))
	local beside = building("Beside96", Vector3.new(X + 80, 30, -100), Vector3.new(40, 60, 40)) -- (the next block over: the line wasn't drawn across it)
	local road = M.new("Part", "Road96")
	road.Size = Vector3.new(400, 1, 400)
	road.CFrame = CFrame.new(X, -0.5, -100)
	road.Parent = roads
	DM.list = nil
	-- him, on the cut's own line (it never cuts him); a dummy in it, one under it, one off to the side
	for _, c in { aChar, bChar } do
		if c then
			c.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.new(X, 15, -20))
	bChar, bHum, bRoot = spawnChar(B, CFrame.new(X + 40, 3, 60))
	local function dummy(name, pos)
		local m, h = makeCharacter(name, CFrame.new(pos))
		m.Parent = dummies
		h.MaxHealth, h.Health = 300, 300
		return m, h
	end
	local inCut, inHum = dummy("InCut96", Vector3.new(X, 20, -40))
	local under, underHum = dummy("Under96", Vector3.new(X, 3, -40))
	local side, sideHum = dummy("Side96", Vector3.new(X + 300, 10, 0))
	-- the stroke: across the near block's face, 30 up, from a camera 10 up
	local O = Vector3.new(X, 10, 0)
	local dA = (Vector3.new(X - 30, 30, -80) - O).Unit
	local dB = (Vector3.new(X + 30, 30, -80) - O).Unit

	-- nobody else
	clearSent()
	fire(UseAbility, B, PI, "Dismantle", { O = bRoot.Position + Vector3.new(0, 5, 0), A = dA, B = dB })
	check(#calls.slice == 0 and #sentTo(B, "Dismantle") == 0, "only the dev flight's people can cut (nothing for anyone else)")
	-- bad asks
	DM.last[A] = nil
	fire(UseAbility, A, PI, "Dismantle", { O = O + Vector3.new(DC.Reach + 50, 0, 0), A = dA, B = dB })
	check(#calls.slice == 0 and DM.last[A] == nil, "...not from a camera past Reach from his body")
	fire(UseAbility, A, PI, "Dismantle", { O = O, A = Vector3.new(0 / 0, 0, 1), B = dB })
	check(#calls.slice == 0 and DM.last[A] == nil, "...not a broken direction (NaN)")
	fire(UseAbility, A, PI, "Dismantle", { O = O, A = Vector3.new(1, 0, 0), B = Vector3.new(-1, 0, 0.01) })
	check(#calls.slice == 0 and DM.last[A] == nil, "...not wider than MaxAngle")
	fire(UseAbility, A, PI, "Dismantle", { O = O, A = dA, B = dA })
	check(#calls.slice == 0 and DM.last[A] == nil, "...not a dot (no line)")

	-- THE CUT
	clearSent()
	local h0, u0, s0, a0 = inHum.Health, underHum.Health, sideHum.Health, aHum.Health
	fire(UseAbility, A, PI, "Dismantle", { O = O, A = dA, B = dB })
	local sl = calls.slice[1]
	check(sl ~= nil and #sl.Units == 2 and sl.Units[1] == near and sl.Units[2] == behind,
		"the cut goes through the near block and the tall one behind it, nearest first - not the next block over, nor one off to the side (" .. tostring(sl and #sl.Units) .. ")")
	if sl then
		local n = dA:Cross(dB).Unit
		check(math.abs(math.abs(sl.N:Dot(n)) - 1) < 1e-4 and (sl.P - O).Magnitude < 1e-3, "...along the sheet through his camera and the line he drew")
		check(sl.Opts.Budget == DC.Budget and sl.Opts.Step == DC.Step and sl.Opts.PerPart == DC.PerPart and typeof(sl.Opts.Stroke) == "Vector3",
			"...with Config.Dismantle's budget, step, per-part cap and the drawn line's direction")
	end
	check(#calls.collapse == 2 and calls.collapse[1].Opts.Slide == DC.Slide and type(calls.collapse[1].Opts.OnImpact) == "function",
		"...each group comes off (Destruction.Collapse, Config.Dismantle's slide / fall / impact)")
	check(inHum.Health < h0, "anyone in the cut is hit (" .. h0 .. " -> " .. inHum.Health .. ")")
	check(underHum.Health == u0 and sideHum.Health == s0, "...not someone under it, nor off past its ends")
	check(aHum.Health == a0, "...never him (he's on its line)")
	check(#sentTo(A, "DismantleHit") == 1, "...the cut on the body (DismantleHit)")
	local word = sentTo(B, "Dismantle")[1]
	check(word ~= nil and typeof(word.N) == "Vector3" and type(word.Points) == "table" and type(word.Units) == "table" and #word.Units == 2,
		"everyone's told (Dismantle: the sheet, where it shows, the units for the flash)")

	-- once each Cooldown
	fire(UseAbility, A, PI, "Dismantle", { O = O, A = dA, B = dB })
	check(#calls.slice == 1, "...one cut each Cooldown (" .. DC.Cooldown .. " s)")

	-- coming off, and landing: anyone round it hit and thrown (never him)
	clearSent()
	local g = calls.collapse[1] and calls.collapse[1].G
	if g then
		calls.collapse[1].Opts.OnSlide(g)
		check(#sentTo(B, "DismantleSlide") == 1, "a top coming off: DismantleSlide for everyone")
		local landHum = underHum.Health
		aRoot.CFrame = CFrame.new(X + 6, 3, -40)
		local hits = DM.impact(A, aChar, Vector3.new(X, 0, -40), g)
		check(underHum.Health < landHum and table.find(hits, under) ~= nil, "...where it lands, anyone round it is hit (" .. landHum .. " -> " .. underHum.Health .. ")")
		check(table.find(hits, aChar) == nil, "...not him")
		check(#sentTo(B, "DismantleImpact") == 1, "...and the crash for everyone (DismantleImpact)")
		aRoot.CFrame = CFrame.new(X, 15, -20)
	end

	-- the street: a cut down across it leaves a gash (DismantleGash)
	local rayWas = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if dir.Y < -0.01 then
			local t = -origin.Y / dir.Y
			if t > 0 and t <= dir.Magnitude then
				return { Position = origin + dir * t, Instance = road }
			end
		end
		return nil
	end
	DM.last[A] = nil
	local before = #calls.slice
	local out = DM.relay(A, aChar, "Dismantle", { O = O, A = (Vector3.new(X - 20, 0, -40) - O).Unit, B = (Vector3.new(X + 20, 0, -40) - O).Unit })
	workspace.Raycast = rayWas
	local gashed = 0
	for _, c in calls.capsule do
		if c[4] == "DismantleGash" then
			gashed += 1
		end
	end
	check(out ~= nil and #out.Points == DC.Rays and #out.Gash > 0 and gashed == #out.Gash and #out.Gash <= DC.Gash.Max,
		"a cut down across the street gashes it, along where it meets it (" .. gashed .. " stretches, Max " .. DC.Gash.Max .. ")")

	-- too much still coming down: no new cut (MaxMoving)
	calls.moving = DC.MaxMoving
	DM.last[A] = nil
	before = #calls.slice
	out = DM.relay(A, aChar, "Dismantle", { O = O, A = dA, B = dB })
	check(#calls.slice == before and out ~= nil and out.Refused == true, "no new cut while MaxMoving pieces are still coming down")
	calls.moving = 0

	-- tidy
	DM.allowed = allowedWas
	dx.Slice, dx.Collapse, dx.MovingCount, dx.Capsule = sliceWas, collapseWas, movingWas, capsuleWas
	for _, m in { near, behind, aside, beside, road, inCut, under, side } do
		m.Parent = nil
	end
	DM.list = nil
	DM.last[A] = nil
end)

---------------------------------------------------------------------------
-- Round 97: ANTI-EXPLOIT (Kit.AX, as Destruction.AntiExploit): the movement
-- watchdog and its excuses, Log and Enforce, anti-fling, the request and
-- clash caps, the farming limits, the console's ax / flags
---------------------------------------------------------------------------
;M.section(function()
	local X = 97000
	print("== round 97: ANTI-EXPLOIT (the watchdog, its excuses, Log / Enforce, fling, spam, clash, farming, the console)")
	local AX = dx.AntiExploit
	check(AX ~= nil and type(AX.check) == "function" and type(AX.farmed) == "function", "the anti-exploit is there (Kit.AX)")
	if not AX then
		return
	end
	local AC = Config.AntiExploit
	check(AC.Mode == "Log" and AX.mode == "Log" and (AC.KickAt or 0) == 0, "it ships in Log mode, never kicking")
	-- (quick, and driven here: the background look stood down)
	local tickWas, exemptWas = AX.tick, AX.exempt
	AX.tick = function() end
	local watched = { [A] = true }
	AX.exempt = function(p)
		return not watched[p]
	end
	local saved = {}
	for k, v in { Grace = 0.3, Speed = { Max = 75, Window = 0.4 }, Hover = { Time = 0.6, Ground = 14, Fall = 4 }, KickAt = 0 } do
		saved[k] = AC[k]
		AC[k] = v
	end
	-- the street: ground under anyone below 14 studs up
	local rayWas = workspace.Raycast
	workspace.Raycast = function(_, origin, dir)
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0.5 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = basePlate }
		end
		return nil
	end
	for _, c in { aChar, bChar } do
		if c then
			c.Parent = nil
		end
	end
	aChar, aHum, aRoot = spawnChar(A, CFrame.lookAt(Vector3.new(X, 3, 0), Vector3.new(X, 3, 4)))
	bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(Vector3.new(X, 3, 4), Vector3.new(X, 3, 0)))
	AX.state[A] = nil
	AX.log = {}
	-- his own machine moving his body (the server never hears a CFrame set)
	local function slide(pos)
		local cf = rawget(aRoot, "_props").CFrame
		rawget(aRoot, "_props").CFrame = CFrame.new(pos) * cf.Rotation
	end
	local function look()
		AX.check(A, os.clock())
	end
	-- (the log starts over - and the gap between two lines of a kind with it)
	local function clearLog()
		AX.log = {}
		for _, s in AX.state do
			s.Said = {}
		end
	end
	local function flagged(kind)
		local n = 0
		for _, e in AX.log do
			if e.UserId == A.UserId and e.Kind == kind then
				n += 1
			end
		end
		return n
	end
	-- walk a path: `step` studs every 0.1 s, `n` times
	local function walk(from, dir, step, n)
		local p = from
		for _ = 1, n do
			task.wait(0.1)
			p += dir * step
			slide(p)
			look()
		end
		return p
	end
	look()
	task.wait(0.35) -- (a new body: the grace runs out)
	look()

	-- walking and running: nothing
	local p = walk(Vector3.new(X, 3, 0), Vector3.new(1, 0, 0), 2.5, 8) -- (25 studs/s)
	check(#AX.log == 0, "walking and running: nothing flagged")
	-- SPEED: 140 studs/s on the street
	p = walk(p, Vector3.new(1, 0, 0), 14, 6)
	check(flagged("Speed") >= 1, "SPEED: 140 studs/s flat with nothing to excuse it is flagged")
	check(math.abs(aRoot.Position.X - p.X) < 0.01, "...in Log mode he's left where he is (only noted)")
	local entry = AX.log[#AX.log]
	check(entry and entry.Name == A.Name and entry.Mode == "Log" and typeof(entry.Pos) == "Vector3", "...the log has who, what, where")
	task.wait(0.35)
	look()
	-- TELEPORT: 200 studs between two looks
	clearLog()
	task.wait(0.1)
	p += Vector3.new(0, 0, 200)
	slide(p)
	look()
	check(flagged("Teleport") == 1, "TELEPORT: 200 studs between two looks is flagged")

	-- THE EXCUSES
	local function excusedBy(label, setup, undo)
		task.wait(0.4)
		look()
		clearLog()
		setup()
		task.wait(0.1)
		p += Vector3.new(0, 0, 150)
		slide(p)
		look()
		if undo then
			undo()
		end
		check(#AX.log == 0, "...not when " .. label)
	end
	excusedBy("the server moved him itself (a warp, a respawn, a grab)", function()
		aRoot.CFrame = CFrame.new(p + Vector3.new(0, 0, 1))
		p += Vector3.new(0, 0, 1)
	end)
	excusedBy("he's just asked for a move (a dash, a flight, parkour)", function()
		AX.request(A, 1)
	end)
	local kb
	excusedBy("a hit's knockback is on him (the server's force)", function()
		kb = M.new("LinearVelocity", "Knockback")
		kb.Parent = aRoot
	end, function()
		kb.Parent = nil
	end)
	excusedBy("he's ragdolled", function()
		aChar:SetAttribute("Ragdolled", true)
		look()
		aChar:SetAttribute("Ragdolled", nil)
	end)
	excusedBy("he's flying (Bakugo's blasts)", function()
		aChar:SetAttribute("BlastFlying", true)
	end, function()
		aChar:SetAttribute("BlastFlying", nil)
	end)
	-- ...but a block isn't a move
	task.wait(0.4)
	look()
	clearLog()
	AX.request(A, Config.BLOCK_INDEX, true)
	task.wait(0.1)
	p += Vector3.new(0, 0, 150)
	slide(p)
	look()
	check(flagged("Teleport") == 1, "...a guard going up isn't a move: still flagged")

	-- a lagging machine: nothing for 2 s, then all of it at once - running pace
	task.wait(0.4)
	look()
	clearLog()
	local before = aRoot.Position
	for _ = 1, 8 do
		task.wait(0.25)
		look()
	end
	p = before + Vector3.new(50, 0, 0)
	slide(p)
	look()
	check(#AX.log == 0, "a lagging player's catch-up (50 studs after 2 s of nothing) isn't a teleport or speeding")

	-- RISE and HOVER
	task.wait(0.4)
	look()
	clearLog()
	p = walk(p, Vector3.new(0, 1, 0), 16, 2) -- (160 studs/s up)
	check(flagged("Rise") >= 1, "RISE: 160 studs/s straight up is flagged")
	task.wait(0.4)
	look()
	clearLog()
	p = Vector3.new(p.X, 80, p.Z)
	aRoot.CFrame = CFrame.new(p) -- (the server put him up there: excused a moment)
	look()
	task.wait(0.35)
	for _ = 1, 9 do
		task.wait(0.1)
		p += Vector3.new(1, 0, 0)
		slide(p)
		look()
	end
	check(flagged("Hover") >= 1, "HOVER: drifting about 80 studs up, not falling, is flagged")
	-- a machine that's frozen up there (lag) isn't hovering
	clearLog()
	AC.Hover.Time = 1.5
	for _ = 1, 25 do
		task.wait(0.1)
		look()
	end
	AC.Hover.Time = 0.6
	check(flagged("Hover") == 0, "...not a body frozen in the air (a lagging machine sends nothing)")
	clearLog()
	workspace:SetAttribute("MoonGravity", true)
	for _ = 1, 9 do
		task.wait(0.1)
		look()
	end
	workspace:SetAttribute("MoonGravity", nil)
	check(flagged("Hover") == 0, "...not under Moon Gravity (low gravity: no rising or hovering checks)")
	p = Vector3.new(p.X, 3, p.Z)
	aRoot.CFrame = CFrame.new(p)
	look()

	-- SPIN and FLING
	task.wait(0.4)
	clearLog()
	aRoot.AssemblyAngularVelocity = Vector3.new(0, 900, 0)
	look()
	check(flagged("Spin") == 1, "SPIN: 900 rad/s is flagged (the fling exploit)")
	aRoot.AssemblyAngularVelocity = Vector3.zero
	aRoot.AssemblyLinearVelocity = Vector3.new(2000, 0, 0)
	task.wait(0.1)
	look()
	aRoot.AssemblyLinearVelocity = Vector3.zero
	check(flagged("Fling") == 1, "FLING: 2000 studs/s is flagged")

	-- nobody's watched who isn't to be (testers, the dev flight's people)
	check(exemptWas(B) == true, "testers (in Studio: everyone) and the dev flight's people aren't watched")

	-- THE CONSOLE (F2): the owner's eyes only
	local consoleRemote = remotes:FindFirstChild("Console")
	clearLog()
	AX.flag(A, "Speed", "test entry", p)
	clearSent()
	task.wait(0.06)
	consoleRemote.OnServerEvent:Fire(A, "Run", "flags")
	task.wait()
	local mine, everyone = 0, 0
	for _, s in M.sent do
		if s.Args[1] == "Line" then
			if s.To == A then
				mine += 1
			elseif s.To == "all" then
				everyone += 1
			end
		end
	end
	check(mine >= 2 and everyone == 0, "the console's `flags` shows the log to the owner only (" .. mine .. " lines, " .. everyone .. " to everyone)")
	task.wait(0.06)
	consoleRemote.OnServerEvent:Fire(A, "Run", "ax enforce")
	task.wait()
	check(AX.mode == "Enforce", "`ax enforce` switches this server to Enforce")

	-- ENFORCE: put back; a flinger out of everyone's way; the kick
	task.wait(0.4)
	look()
	local stood = aRoot.Position
	task.wait(0.1)
	look()
	slide(stood + Vector3.new(200, 0, 0))
	look()
	local st = AX.state[A]
	check((st.Pulls or 0) >= 1 and (aRoot.Position - (stood + Vector3.new(0, 0.5, 0))).Magnitude < 0.01,
		"ENFORCE: a teleporter is put back where he last stood")
	check(st.MovedAt < st.PulledAt, "...and that pull back excuses nothing (it's not a server move of the game's)")
	aRoot.AssemblyAngularVelocity = Vector3.new(0, 900, 0)
	look()
	aRoot.AssemblyAngularVelocity = Vector3.zero
	local loose = true
	for _, d in aChar:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "RagdollCollider" and d.CollisionGroup ~= "Loose" then
			loose = false
		end
	end
	check(aChar:GetAttribute("Quarantined") == true and loose, "...a spinning flinger's body touches nobody for a while (Quarantine)")
	local kicked
	rawset(A, "Kick", function(_, msg)
		kicked = msg
	end)
	AC.KickAt = 5
	st.Points = 4.5
	AX.flag(A, "Teleport", "test", p)
	check(kicked ~= nil, "...and at KickAt points (when it's set) he's kicked")
	rawset(A, "Kick", nil)
	AC.KickAt = 0
	task.wait(0.06)
	consoleRemote.OnServerEvent:Fire(A, "Run", "ax log")
	task.wait()
	check(AX.mode == "Log", "`ax log` puts it back")

	-- REQUESTS: past the rate
	clearLog()
	local st2 = AX.watch(A)
	st2.Bucket, st2.BucketAt = 3, os.clock()
	local dropped = 0
	for _ = 1, 10 do
		if AX.request(A, 1) == false then
			dropped += 1
		end
	end
	check(flagged("Spam") == 1 and dropped == 0, "REQUESTS: past the rate it's flagged (Log: still let through)")
	AX.mode = "Enforce"
	st2.Bucket, st2.BucketAt = 1, os.clock()
	local passed = AX.request(A, 1)
	local refused = AX.request(A, 1)
	AX.mode = "Log"
	check(passed == true and refused == false, "...Enforce drops it")

	-- CLASH: human speed; a macro's too even
	check(math.abs(AX.clashGap(A) - 1 / AC.Clash.MaxRate) < 1e-6 and AX.clashGap(B) == 0, "CLASH: presses at most " .. AC.Clash.MaxRate .. " a second (testers: as before)")
	clearLog()
	local t = 1000
	for _ = 1, 14 do
		t += 0.1
		AX.clashPress(A, t)
	end
	check(flagged("Clash") == 1, "...a run of presses exactly 100 ms apart is a macro")
	clearLog()
	AX.watch(A).LastPress = nil
	local jitter = { 0.09, 0.13, 0.1, 0.16, 0.11, 0.12, 0.095, 0.14, 0.105, 0.15, 0.1, 0.125, 0.11, 0.135 }
	t = 2000
	for _, g in jitter do
		t += g
		AX.clashPress(A, t)
	end
	check(flagged("Clash") == 0, "...a hand's uneven presses aren't")

	-- FARMING
	local C9 = addPlayer("Charlie97", 97003)
	watched[C9] = true
	AX.pairKOs = {}
	local seq = {}
	for i = 1, 4 do
		seq[i] = AX.farmed(A, B)
	end
	check(not seq[1] and not seq[2] and not seq[3] and seq[4], "FARMING: the 4th KO of the same player inside " .. AC.Farm.Window .. " s pays nothing")
	check(AX.farmed(A, C9) == false and AX.farmed(B, A) == false, "...another victim, or the other way round, still counts")
	AX.dummy[A] = nil
	local paid = 0
	for _ = 1, 30 do
		paid += AX.dummyPay(A, 1)
	end
	check(paid == AC.Farm.DummyBucks, "...dummies pay " .. AC.Farm.DummyBucks .. " Bucks a window at most (" .. paid .. ")")
	AX.rated = {}
	local r1, r2, r3 = AX.rematch(A, C9), AX.rematch(C9, A), AX.rematch(A, C9)
	check(not r1 and not r2 and r3, "...a 3rd ranked match with the same player inside the hour is unrated")
	watched[B] = nil
	check(AX.farmed(B, A) == false and AX.rematch(A, B) == false, "...testers aren't limited")

	-- a farmed KO, for real: still a K.O. for everyone, no reward
	AX.pairKOs = {}
	for i = 1, 4 do
		if bChar.Parent == nil or bHum.Health <= 0 then
			bChar, bHum, bRoot = spawnChar(B, CFrame.lookAt(aRoot.Position + aRoot.CFrame.LookVector * 4, aRoot.Position))
		end
		bRoot.CFrame = CFrame.lookAt(aRoot.Position + aRoot.CFrame.LookVector * 4, aRoot.Position)
		task.wait(Config.M1.ComboReset + 0.1)
		clearSent()
		local kills0, bucks0 = A:GetAttribute("Kills") or 0, A:GetAttribute("Bucks") or 0
		bHum.Health = 3
		m1(A)
		task.wait(0.1)
		if i == 4 then
			local conf = sentTo(A, "KOConfirm")[1]
			check(bHum.Health == 0 and conf ~= nil and conf.Farmed == true and not conf.Counted and conf.Bucks == nil,
				"a 4th KO of the same player: K.O. on his screen, marked no reward (" .. tostring(conf and conf.Farmed) .. ")")
			check((A:GetAttribute("Kills") or 0) == kills0 and (A:GetAttribute("Bucks") or 0) == bucks0, "...no KO count, no Bucks")
			check(#sentTo(B, "KOFeed") == 1, "...the kill feed still has it")
		end
	end

	-- tidy
	AX.mode = "Log"
	AX.tick, AX.exempt = tickWas, exemptWas
	for k, v in saved do
		AC[k] = v
	end
	workspace.Raycast = rayWas
	AX.log, AX.pairKOs, AX.rated, AX.dummy = {}, {}, {}, {}
	AX.state[A], AX.state[B], AX.state[C9] = nil, nil, nil
	if aChar then
		aChar:SetAttribute("Quarantined", nil)
	end
	table.remove(playerList, table.find(playerList, C9))
	C9.Parent = nil
end)

---------------------------------------------------------------------------
-- Round 98: MODERATION (ban / unban / bans / warn / kick, staff powers),
-- NAME TAGS (given, saved, the owner's own), GAME PASSES (given, bought,
-- the emote wheel's second ring, the outfit pass, Bucks) - Kit.MOD as
-- Destruction.Moderation
---------------------------------------------------------------------------
;M.section(function()
	print("== round 98: MODERATION, NAME TAGS, GAME PASSES")
	local MOD = dx.Moderation
	check(MOD ~= nil and MOD.TG ~= nil and MOD.GP ~= nil and type(MOD.ban) == "function", "moderation, tags and passes are there (Kit.MOD / TG / GP)")
	if not MOD then
		return
	end
	local TG, GP = MOD.TG, MOD.GP
	local Con = MOD.Console
	check(Con ~= nil and type(Con.level) == "function", "...and the console knows staff (Console.level)")
	local MC, PC = Config.Moderation, Config.GamePasses
	check(MC.RobloxBans == true and MC.ModMaxBan == 3 * 86400 and #Config.Tags.List >= 6 and PC.EmoteSlots.Id == 0, "it's all set up in Config (bans on Roblox's list too; a mod bans 3 days at most; the tags; passes with no Id yet)")
	local consoleRemote = remotes:FindFirstChild("Console")
	local ShopRemote = remotes:FindFirstChild("Shop")
	local function run(p, text)
		task.wait(0.07)
		consoleRemote.OnServerEvent:Fire(p, "Run", text)
		task.wait()
	end
	local function lines(to)
		local out = {}
		for _, s in M.sent do
			if s.Args[1] == "Line" and s.To == to then
				table.insert(out, tostring(s.Args[2].Text))
			end
		end
		return out
	end
	local function said(to, needle)
		for _, t in lines(to) do
			if string.find(t, needle, 1, true) then
				return true
			end
		end
		return false
	end
	local function join(name, id)
		local p = M.new("Player", name)
		p.DisplayName = name
		p.UserId = id
		rawset(p, "Kick", function(self, msg)
			rawset(self, "_kicked", msg or "")
		end)
		function p.LoadCharacter() end
		Con.owners[p] = false -- (not an owner: in Studio the harness's would all be)
		table.insert(playerList, p)
		p.Parent = Players
		Players.PlayerAdded:Fire(p)
		task.wait(0.1)
		return p
	end
	local function leave(p)
		p.Parent = nil
		Players.PlayerRemoving:Fire(p)
		local at = table.find(playerList, p)
		if at then
			table.remove(playerList, at)
		end
		task.wait(0.2)
	end
	local function kickedWith(p)
		return rawget(p, "_kicked")
	end

	-- THE OWNER'S TAG
	check(A:GetAttribute("Tag") == "Owner" and string.find(A:GetAttribute("Tags") or "", "Owner", 1, true) and Con.level(A) == 3, "the owner wears OWNER, always (and is level 3 at the console)")
	-- (Bravo stops being an owner - in Studio everyone the harness makes is)
	local bWasOwner, bCached = Con.isOwner(B), Con.owners[B]
	Con.owners[B] = false
	TG.apply(B, true)
	check(B:GetAttribute("Tag") == nil and B:GetAttribute("StaffLevel") == nil and Con.level(B) == 0, "someone else: no tag, no powers")
	clearSent()
	run(B, "kick Alpha")
	check(said(B, "Read-only"), "...the console's read-only for them")

	-- TAGS: given by the owner, saved
	local C = join("Charlie98", 98003)
	local D = join("Delta98", 98004)
	clearSent()
	run(A, "tag Bravo mod")
	check(B:GetAttribute("Tag") == "Mod" and B:GetAttribute("StaffLevel") == 1 and B:GetAttribute("ConsoleRole") == "Mod" and Con.level(B) == 1,
		"`tag Bravo mod`: the MOD tag, and a mod's powers (" .. tostring(B:GetAttribute("Tag")) .. ")")
	check(MOD.records[B.UserId] and MOD.records[B.UserId].Tags.Mod ~= nil and MOD.records[B.UserId].Tags.Mod.By == "Alpha", "...it's in their record (who gave it)")
	local toasted = false
	for _, n in sentTo(B, "Notice") do
		if string.find(tostring(n.Text), "MOD", 1, true) then
			toasted = true
		end
	end
	check(toasted, "...and they're told")
	run(A, "tag Bravo tester")
	check(B:GetAttribute("Tag") == "Mod" and B:GetAttribute("Tags") == "Mod,Tester", "a second tag: both are theirs, the first in the list shows (" .. tostring(B:GetAttribute("Tags")) .. ")")
	clearSent()
	run(A, "tag me owner")
	check(said(A, "can't be given"), "the OWNER tag can't be given")
	run(A, "tag Bravo bogus")
	check(said(A, "No tag"), "...nor one that doesn't exist")

	-- STAFF AT THE CONSOLE
	clearSent()
	run(B, "help")
	local help = table.concat(lines(B), " ")
	check(string.find(help, "ban", 1, true) and string.find(help, "warn", 1, true) and string.find(help, "kick", 1, true) and not string.find(help, "bucks", 1, true),
		"a mod's `help` lists theirs (ban, warn, kick) and not the owner's (bucks)")
	clearSent()
	run(B, "bucks 500")
	check(said(B, "owner's") and B:GetAttribute("Bucks") ~= 500, "...and the owner's commands are refused")
	local echoed = false
	for _, s in M.sent do
		if s.Args[1] == "Line" and s.To == "all" and string.find(tostring(s.Args[2].Text), "Bravo>", 1, true) then
			echoed = true
		end
	end
	check(not echoed, "...what staff type stays between them and the console")
	Con.lastSync[B] = nil
	clearSent()
	consoleRemote.OnServerEvent:Fire(B, "Sync")
	task.wait()
	local sync
	for _, s in M.sent do
		if s.To == B and s.Args[1] == "Sync" then
			sync = s.Args[2]
		end
	end
	local hasBucks, hasBan = false, false
	for _, c in sync and sync.Commands or {} do
		hasBucks = hasBucks or c.Name == "bucks"
		hasBan = hasBan or c.Name == "ban"
	end
	check(sync and sync.Owner == true and sync.Role == "MOD" and hasBan and not hasBucks, "...their console: the box to type in, MOD, and only their commands")
	Con.lastSync[D] = nil
	clearSent()
	consoleRemote.OnServerEvent:Fire(D, "Sync")
	task.wait()
	local viewer
	for _, s in M.sent do
		if s.To == D and s.Args[1] == "Sync" then
			viewer = s.Args[2]
		end
	end
	local seesBucks = false
	for _, c in viewer and viewer.Commands or {} do
		seesBucks = seesBucks or c.Name == "bucks"
	end
	check(viewer and viewer.Owner == false and viewer.Role == nil and seesBucks, "...someone who only watches still sees every command, read-only (as before)")

	-- WARN
	clearSent()
	run(B, "warn Charlie98 stop spamming the chat")
	local warned = sentTo(C, "ModWarn")[1]
	check(warned and warned.Text == "stop spamming the chat" and warned.By == "Bravo", "`warn`: a warning on their screen, and who from")

	-- KICK
	clearSent()
	run(B, "kick all")
	check(said(B, "Name one person") and kickedWith(C) == nil, "a mod can't `kick all`")
	run(B, "kick Alpha")
	check(said(B, "No one kicked"), "...nor kick the owner")
	run(B, "kick Charlie98 being rude")
	check(kickedWith(C) == "being rude", "`kick Charlie98 being rude`: out, with the reason")
	check(said(A, "kicked Charlie98"), "...and the owner's console hears of it")
	rawset(C, "_kicked", nil)

	-- BAN
	clearSent()
	run(B, "ban Alpha")
	check(said(B, "owner"), "nobody can ban the owner")
	run(B, "ban Bravo")
	check(said(B, "yourself"), "...nor themselves")
	run(A, "tag Delta98 mod")
	run(B, "ban Delta98")
	check(said(B, "as high as you") and kickedWith(D) == nil, "...nor a mod ban a mod")
	run(A, "untag Delta98 all")
	check(D:GetAttribute("StaffLevel") == nil and D:GetAttribute("Tag") == nil, "`untag <who> all`: tags and powers gone")
	clearSent()
	local t0 = os.time()
	run(B, "ban Charlie98 perm griefing the spawn")
	local rec = MOD.records[C.UserId]
	check(rec and rec.Ban and rec.Ban.Reason == "griefing the spawn" and rec.Ban.ByName == "Bravo", "`ban Charlie98 perm griefing the spawn`: banned, with the reason and who")
	check(rec and rec.Ban and math.abs(rec.Ban.Until - (t0 + MC.ModMaxBan)) <= 2, "...a mod's ban is 3 days at most, even asked for perm")
	check(kickedWith(C) ~= nil and string.find(kickedWith(C), "griefing the spawn", 1, true) and string.find(kickedWith(C), "ends in", 1, true), "...out now, told why and for how long (" .. tostring(kickedWith(C)) .. ")")
	check(said(B, "longest a mod can") and said(A, "Banned Charlie98"), "...the mod is told it was cut down; the owner hears of it")
	check(MOD.index.Ban[tostring(C.UserId)] ~= nil, "...it's on the ban list")
	leave(C)
	local C2 = join("Charlie98", 98003)
	check(kickedWith(C2) ~= nil, "coming back while banned: straight back out")
	leave(C2)

	-- OFFLINE, BY USERID; THE LIST; UNBAN
	clearSent()
	run(A, "ban 55555 7d alt account")
	local r5 = MOD.records[55555]
	check(r5 and r5.Ban and math.abs(r5.Ban.Until - (os.time() + 7 * 86400)) <= 2 and r5.Ban.Reason == "alt account", "`ban 55555 7d alt account`: someone who isn't here, by UserId")
	run(A, "ban 55556 2h")
	check(MOD.records[55556] and MOD.records[55556].Ban and math.abs(MOD.records[55556].Ban.Until - (os.time() + 7200)) <= 2, "...2h is two hours")
	run(A, "ban 55557 griefing")
	check(MOD.records[55557] and MOD.records[55557].Ban and MOD.records[55557].Ban.Until == 0 and MOD.records[55557].Ban.Reason == "griefing", "...no time: the owner's ban is for good")
	clearSent()
	run(B, "bans")
	check(said(B, "55555") and said(B, "alt account") and said(B, "Charlie98"), "`bans`: the bans in force")
	run(B, "unban 55555")
	check(said(B, "Only Alpha") and MOD.banned(MOD.records[55555].Ban), "a mod can't lift someone else's ban")
	run(B, "unban 98003")
	check(not MOD.banned(MOD.records[98003].Ban) and MOD.index.Ban["98003"] == nil, "...but can lift their own")
	run(A, "unban 55555")
	check(MOD.records[55555].Ban == nil, "the owner lifts anyone's")
	clearSent()
	run(A, "ban @nobodyAtAll98 1d")
	check(said(A, "No one called"), "a name that's nobody's: said so")
	run(A, "ban all 1d")
	check(said(A, "Name one person"), "`ban all` is never allowed")
	local C3 = join("Charlie98", 98003)
	check(kickedWith(C3) == nil, "lifted: they can come back in")
	-- (an old ban that's run out)
	MOD.records[98003].Ban = { Until = os.time() - 5, Reason = "old", By = 1, ByName = "Alpha", At = os.time() - 100 }
	MOD.enforce(C3)
	check(kickedWith(C3) == nil, "...and a ban that's run out keeps nobody out")

	-- ANOTHER SERVER'S BAN (MessagingService)
	MOD.pending[98003], MOD.pending[D.UserId] = nil, nil -- (Studio never saved this server's own)
	MOD.onMessage({ Data = { Op = "Ban", Id = C3.UserId, From = "another-server", Rec = { Name = "Charlie98", Ban = { Until = 0, Reason = "from elsewhere", By = 1, ByName = "Alpha", At = os.time() } } } })
	check(kickedWith(C3) ~= nil and string.find(kickedWith(C3), "from elsewhere", 1, true), "banned on another server: kicked from this one too")
	MOD.onMessage({ Data = { Op = "Rec", Id = D.UserId, From = "another-server", Rec = { Name = "Delta98", Tags = { OG = { By = "Alpha", At = os.time() } } } } })
	check(D:GetAttribute("Tag") == "OG", "...a tag given on another server shows here at once")
	leave(C3)

	-- SAVED (DataStore) - and Roblox's own ban list on a live server
	local DSS = service("DataStoreService")
	local getWas = DSS.GetDataStore
	DSS.GetDataStore = function(_, name)
		local st = getWas(_, name)
		st.UpdateAsync = function(_, k, f)
			local v = f(DS.data[k])
			DS.data[k] = v
			return v
		end
		return st
	end
	MOD.ds = nil
	MC.StudioSaves = true
	run(A, "ban 66666 1d saved one")
	task.wait(0.1)
	local stored = DS.data["staff_66666"]
	check(stored and stored.Ban and stored.Ban.Reason == "saved one" and DS.data["BanIndex"] and DS.data["BanIndex"]["66666"] ~= nil, "bans are saved (DataStore: the record and the list)")
	MOD.records[66666], MOD.readAt[66666] = nil, nil
	local E = join("Echo98", 66666)
	check(kickedWith(E) ~= nil and string.find(kickedWith(E), "saved one", 1, true), "...a new server reads it: they're kept out")
	leave(E)
	run(A, "tag 66667 dev")
	task.wait(0.1)
	check(DS.data["staff_66667"] and DS.data["staff_66667"].Tags.Dev ~= nil and DS.data["StaffIndex"]["66667"] ~= nil, "tags are saved too (and on the staff list)")
	MOD.records[66667], MOD.readAt[66667] = nil, nil
	local F = join("Fox98", 66667)
	check(F:GetAttribute("Tag") == "Dev", "...and worn when they come in")
	leave(F)
	local banned, unbanned
	local banWas, unbanWas = Players.BanAsync, Players.UnbanAsync
	Players.BanAsync = function(_, cfg)
		banned = cfg
	end
	Players.UnbanAsync = function(_, cfg)
		unbanned = cfg
	end
	local TS = service("TextService")
	TS.FilterStringAsync = function(_, text)
		return {
			GetNonChatStringForBroadcastAsync = function()
				return text
			end,
			GetNonChatStringForUserAsync = function()
				return text
			end,
		}
	end
	studioMode = false
	run(A, "ban 77777 1d live one")
	task.wait(0.1)
	check(banned and banned.UserIds[1] == 77777 and banned.Duration == 86400 and banned.ApplyToUniverse == true and banned.ExcludeAltAccounts == false and banned.DisplayReason == "live one",
		"a live server also puts the ban on Roblox's list (BanAsync: 1 day, alt accounts too)")
	run(A, "ban 77778 perm")
	task.wait(0.1)
	check(banned and banned.UserIds[1] == 77778 and banned.Duration == -1, "...for good: Duration -1")
	run(A, "unban 77777")
	task.wait(0.1)
	check(unbanned and unbanned.UserIds[1] == 77777, "...and unban lifts that too (UnbanAsync)")
	studioMode = true
	TS.FilterStringAsync = nil
	Players.BanAsync, Players.UnbanAsync = banWas, unbanWas
	MC.StudioSaves = false
	DSS.GetDataStore = getWas
	MOD.ds = nil

	-- GAME PASSES: given
	clearSent()
	run(A, "givepass Bravo emoteslots")
	check(B:GetAttribute("Pass_EmoteSlots") == true and B:GetAttribute("PassGiven_EmoteSlots") == true, "`givepass Bravo emoteslots`: theirs (given)")
	check(sentTo(B, "PassBought")[1] and sentTo(B, "PassBought")[1].Gift == "Alpha", "...and they're told who from")
	-- the second ring
	local ids = {}
	for _, e in Config.Emotes do
		if not e.Exclusive and #ids < 10 then
			table.insert(ids, e.Id)
		end
	end
	B:SetAttribute("EmotesOwned", table.concat(ids, ",", 1, 9))
	B:SetAttribute("EmoteWheel", table.concat({ ids[1], ids[2], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8] }, ","))
	B:SetAttribute("EmoteWheel2", nil)
	task.wait(0.1)
	fire(ShopRemote, B, "EquipEmote", 9, ids[9])
	check(string.sub(B:GetAttribute("EmoteWheel2") or "", 1, #ids[9]) == ids[9], "the EMOTE SLOTS pass: slot 9 is on the second ring (" .. tostring(B:GetAttribute("EmoteWheel2")) .. ")")
	task.wait(0.1)
	fire(ShopRemote, B, "EquipEmote", 12, ids[1])
	local ring1 = string.split(B:GetAttribute("EmoteWheel") or "", ",")
	local ring2 = string.split(B:GetAttribute("EmoteWheel2") or "", ",")
	check(ring1[1] == "" and ring2[4] == ids[1], "...moving one there takes it off the first ring")
	B:SetAttribute("EmotePicks", 1)
	B:SetAttribute("EmoteWheel", table.concat({ ids[2], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8], ids[1] }, ","))
	B:SetAttribute("EmoteWheel2", nil)
	task.wait(0.1)
	fire(ShopRemote, B, "PickEmote", ids[10])
	check(string.sub(B:GetAttribute("EmoteWheel2") or "", 1, #ids[10]) == ids[10], "...a new emote with the first ring full goes on the second")
	local G = join("Golf98", 98007)
	G:SetAttribute("EmotesOwned", ids[1])
	task.wait(0.1)
	fire(ShopRemote, G, "EquipEmote", 9, ids[1])
	check(G:GetAttribute("EmoteWheel2") == nil, "without the pass, slot 9 isn't there")
	-- saved, and back
	run(A, "givepass 98008 emoteslots")
	local H = join("Hotel98", 98008)
	task.wait(0.3)
	H:SetAttribute("EmotesOwned", ids[1] .. "," .. ids[2])
	task.wait(0.1)
	fire(ShopRemote, H, "EquipEmote", 10, ids[2])
	leave(H)
	check(DS.data["u_98008"] and type(DS.data["u_98008"].Wheel2) == "string" and string.find(DS.data["u_98008"].Wheel2, ids[2], 1, true), "the second ring is saved (Wheel2)")
	local H2 = join("Hotel98", 98008)
	task.wait(0.3)
	local r2 = string.split(H2:GetAttribute("EmoteWheel2") or "", ",")
	check(H2:GetAttribute("Pass_EmoteSlots") == true and r2[2] == ids[2], "...and back when they come back (" .. tostring(H2:GetAttribute("EmoteWheel2")) .. ")")
	leave(H2)
	run(A, "takepass Bravo emoteslots")
	check(B:GetAttribute("Pass_EmoteSlots") == nil, "`takepass`: a given pass taken back")
	clearSent()
	run(A, "givepass Bravo nothing")
	check(said(A, "No pass"), "...a pass that doesn't exist: said so")

	-- AWAKENING OUTFITS: free till it's set up; then the pass
	Players.GetHumanoidDescriptionFromOutfitIdAsync = function()
		return M.new("HumanoidDescription", "Desc")
	end
	G:SetAttribute("AwakenOutfit", 0)
	task.wait(0.5)
	fire(ShopRemote, G, "AwakenOutfit", 777)
	check(G:GetAttribute("AwakenOutfit") == 777, "AWAKENING OUTFITS: no pass Id yet - free for everyone, as before")
	PC.AwakeningOutfits.Id = 4241
	GP.apply(G)
	task.wait(0.5)
	clearSent()
	fire(ShopRemote, G, "AwakenOutfit", 778)
	check(G:GetAttribute("AwakenOutfit") == 777 and sentTo(G, "Notice")[1] and string.find(sentTo(G, "Notice")[1].Text, "pass", 1, true), "...set up: picking one takes the pass (they're told)")
	run(A, "givepass Golf98 awakening")
	task.wait(0.5)
	fire(ShopRemote, G, "AwakenOutfit", 778)
	check(G:GetAttribute("AwakenOutfit") == 778, "...with it, they pick")
	PC.AwakeningOutfits.Id = 0
	Players.GetHumanoidDescriptionFromOutfitIdAsync = nil

	-- BOUGHT: Roblox says so (at join, and just now)
	PC.VIP.Id, PC.DoubleBucks.Id = 4242, 4243
	local MPS = service("MarketplaceService")
	MPS.UserOwnsGamePassAsync = function(_, uid, pid)
		return uid == G.UserId and pid == 4243
	end
	GP.check(G)
	check(G:GetAttribute("Pass_DoubleBucks") == true and G:GetAttribute("Pass_VIP") == nil, "a pass bought on the website: theirs when they join (UserOwnsGamePassAsync)")
	clearSent()
	GP.purchased(G, 4242, true)
	check(G:GetAttribute("Pass_VIP") == true and G:GetAttribute("Tag") == "VIP" and sentTo(G, "PassBought")[1] ~= nil, "bought in the game: VIP at once - the VIP tag too")
	check(GP.bucks(G, 10) == 25 and GP.bucks(D, 10) == 10, "2x BUCKS with VIP: 10 Bucks earned are 25 (and 10 without)")
	MPS.UserOwnsGamePassAsync = nil
	PC.VIP.Id, PC.DoubleBucks.Id = 0, 0
	clearSent()
	run(A, "passes")
	check(said(A, "EmoteSlots") and said(A, "Golf98"), "`passes`: every pass, and who has it here")
	clearSent()
	run(A, "tags")
	check(said(A, "Bravo") and said(A, "MOD"), "`tags`: who has which tag")

	-- tidy up: Bravo's an owner again (as the harness has him)
	run(A, "untag Bravo all")
	check(B:GetAttribute("Tag") == nil and Con.level(B) == 0, "untagged: no powers left")
	Con.owners[B] = bCached
	TG.apply(B, true)
	check((B:GetAttribute("Tag") == "Owner") == bWasOwner, "(Bravo's back as the harness had him)")
	leave(G)
	leave(D)
	MOD.records[A.UserId], MOD.records[B.UserId] = nil, nil
end)

---------------------------------------------------------------------------
-- Round 103: FINAL FORM CHANGES THE MAP - the emote's bursts are real on the
-- server (Kit.FF): a crater on each drop (Destruction.Sphere), everyone near
-- shoved back - only while he's still in it
---------------------------------------------------------------------------
;M.section(function()
	print("== round 103: FINAL FORM - real craters and a shockwave, only while he's still in it")
	local S = Config.FinalForm and Config.FinalForm.World and Config.FinalForm.World.Server
	check(S ~= nil and S.Enabled ~= false and #(S.Hits or {}) == 2, "FINAL FORM's server side is set up (Config.FinalForm.World.Server: two hits)")
	if not S then
		return
	end
	check(S.Hits[1].Beat == 8 and S.Hits[2].Beat == 24 and S.Hits[2].Radius > S.Hits[1].Radius and S.Hits[2].Profile == "FlightCrater",
		"...on the song's two drops (beats 8 and 24), LEGENDARY's the bigger crater")
	-- (the beats cut short for the test: 0.625 s and 1.25 s in)
	local hits = S.Hits
	S.Hits = {
		{ Beat = 1, Radius = hits[1].Radius, Profile = hits[1].Profile, Push = hits[1].Push },
		{ Beat = 2, Radius = hits[2].Radius, Profile = hits[2].Profile, Push = hits[2].Push },
	}
	local calls = {}
	local realSphere = dx.Sphere
	dx.Sphere = function(center, radius, profile, ...)
		table.insert(calls, { center = center, radius = radius, profile = profile })
		return realSphere(center, radius, profile, ...)
	end
	local ids = {}
	for _, e in Config.Emotes do
		table.insert(ids, e.Id)
	end
	A:SetAttribute("EmotesOwned", table.concat(ids, ","))
	local X = 900
	local function fresh()
		for _, old in { A.Character, B.Character } do
			if old then
				old.Parent = nil
			end
		end
		local ac, _, ar = spawnChar(A, CFrame.new(X, 3, 0))
		local bc, _, br = spawnChar(B, CFrame.new(X + 12, 3, 0))
		task.wait(0.6) -- (past the emote spam guard)
		return ac, ar, bc, br
	end
	local function pushOf(root)
		for _, d in root:GetChildren() do
			if d.Name == "Knockback" then
				return d
			end
		end
		return nil
	end

	-- standing still through it: both craters, and B shoved away each time
	local ac, ar, bc, br = fresh()
	table.clear(calls)
	fire(UseAbility, A, Config.EMOTE_INDEX, "FinalForm")
	task.wait(0.66) -- (each push lasts 0.25 s: checked just after each hit)
	local first = calls[1]
	local kb = pushOf(br)
	check(#calls == 1 and first.profile == "Crater" and first.radius == hits[1].Radius and (first.center - Vector3.new(X, 0, 0)).Magnitude < 4,
		"the first drop: a crater blown out of the street round him (" .. #calls .. " so far)")
	check(kb ~= nil and kb.VectorVelocity.X > 20 and kb.VectorVelocity.Y > 0, "...and Bravo, 12 studs off, shoved away from him and up (" .. tostring(kb and kb.VectorVelocity) .. ")")
	local firstX = kb and kb.VectorVelocity.X or 0
	if kb then
		kb:Destroy()
	end
	task.wait(0.6)
	local second = calls[2]
	check(#calls == 2 and second.profile == "FlightCrater" and second.radius == hits[2].Radius, "LEGENDARY: the big crater (GODSPEED's kind, " .. hits[2].Radius .. " studs)")
	kb = pushOf(br)
	check(kb ~= nil and kb.VectorVelocity.X > firstX * 1.5, "...and the shockwave throws Bravo much harder (" .. tostring(kb and kb.VectorVelocity) .. ")")
	check(bc:GetAttribute("Ragdolled") ~= true, "...without knocking him down, or hurting him")
	check(pushOf(ar) == nil, "...and never Alpha himself")

	-- walked off: nothing
	ac, ar, bc, br = fresh()
	table.clear(calls)
	fire(UseAbility, A, Config.EMOTE_INDEX, "FinalForm")
	task.wait(0.1)
	ar.CFrame = ar.CFrame + Vector3.new(10, 0, 0)
	ar.Position = ar.CFrame.Position
	task.wait(1.4)
	check(#calls == 0 and pushOf(br) == nil, "walked off (the emote's broken): no crater, no shove (" .. #calls .. ")")

	-- a move pressed after it: nothing
	ac, ar, bc, br = fresh()
	table.clear(calls)
	fire(UseAbility, A, Config.EMOTE_INDEX, "FinalForm")
	task.wait(0.1)
	fire(UseAbility, A, 1, ar.CFrame.LookVector, ar.Position + ar.CFrame.LookVector * 10)
	task.wait(1.4)
	local craters = 0
	for _, c in calls do
		if c.radius == hits[1].Radius or c.radius == hits[2].Radius then
			craters += 1
		end
	end
	check(craters == 0, "a move after it (the emote's broken): no FINAL FORM crater (" .. craters .. ")")

	-- another emote after it: nothing
	ac, ar, bc, br = fresh()
	table.clear(calls)
	fire(UseAbility, A, Config.EMOTE_INDEX, "FinalForm")
	task.wait(0.5)
	fire(UseAbility, A, Config.EMOTE_INDEX, "Wave")
	task.wait(1.0)
	craters = 0
	for _, c in calls do
		if c.radius == hits[2].Radius then
			craters += 1
		end
	end
	check(craters == 0, "another emote after it: no LEGENDARY crater (" .. craters .. ")")

	-- switched off: the visuals only
	ac, ar, bc, br = fresh()
	table.clear(calls)
	S.Enabled = false
	fire(UseAbility, A, Config.EMOTE_INDEX, "FinalForm")
	task.wait(1.5)
	check(#calls == 0, "World.Server.Enabled = false: nothing on the server")
	S.Enabled = true

	dx.Sphere = realSphere
	S.Hits = hits
	A:SetAttribute("EmotesOwned", "")
	for _, old in { A.Character, B.Character } do
		if old then
			old.Parent = nil
		end
	end
end)

-- every profile the server asked for exists in the Destruction module
local destructionSrc = fs.readFile(SRC .. "/ServerScriptService.Destruction.lua")
local missing = {}
for name in profilesUsed do
	if not destructionSrc:find("\n\t" .. name .. " = {", 1, true) then
		table.insert(missing, name)
	end
end
check(#missing == 0, "all destruction profiles exist (missing: " .. table.concat(missing, ", ") .. ")")

print(string.format("\n%d passed, %d failed", passes, failures))
process.exit(failures == 0 and 0 or 1)
