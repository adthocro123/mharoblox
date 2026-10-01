-- Dummies (Script) — ServerScriptService.Dummies
-- Training dummies to test moves on. They respawn a few seconds after dying.
-- The test menu can spawn other kinds (Config.DummyKinds): a finisher dummy
-- at its last sliver of health, one that fights back, one that always
-- blocks, one that moves, a tank, an R6 body. What they DO lives in
-- QuirkServer (it has the combat code); this script builds and respawns them.

local Players = game:GetService("Players")
local Destruction = require(script.Parent:WaitForChild("Destruction"))

workspace:WaitForChild("Map", 30)

-- On the street next to the first ground-level spawn of the city map, facing it
local LOOK_AT = Vector3.new(-27, 30, 601)
local SPAWNS = {}
for _, x in { -97, -87, -77, -67, -57 } do
	local pos = Vector3.new(x, 30, 651)
	table.insert(SPAWNS, CFrame.lookAt(pos, Vector3.new(LOOK_AT.X, pos.Y, LOOK_AT.Z)))
end

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("QuirkConfig"))
local MAX_HEALTH = Config.DummyMaxHealth or 500
local RESPAWN_TIME = Config.DummyRespawnTime or 5 -- seconds the limp body lies there
local DUMMY_COLOR = Color3.fromRGB(226, 196, 156)
local LEG_COLOR = Color3.fromRGB(60, 70, 110)

local folder = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
folder.Name = "Dummies"
folder.Parent = workspace

local function kindOf(id)
	return (Config.DummyKind and Config.DummyKind(id or "Normal")) or { Id = "Normal", Label = "DUMMY" }
end

local function fallbackDummy(color)
	-- Simple block dummy if avatar creation is unavailable
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = color
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = color
	head.Parent = model
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Color = LEG_COLOR
	legs.Parent = model
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	for _, p in { torso, head, legs } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = root
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

-- the kind's name floating over its head (the plain dummy goes without)
local function addLabel(model, kind)
	if kind.Id == "Normal" then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "DummyLabel"
	board.Size = UDim2.fromOffset(150, 22)
	board.StudsOffset = Vector3.new(0, 1.7, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 90
	board.Adornee = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = kind.Color or Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Text = kind.Label or kind.Id
	text.Parent = board
	board.Parent = head
end

local function makeDummy(cf, kindId, isDefault)
	local kind = kindOf(kindId)
	local color = kind.Color or DUMMY_COLOR
	local rig = kind.Rig == "R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = color
		desc.TorsoColor = color
		desc.LeftArmColor = color
		desc.RightArmColor = color
		desc.LeftLegColor = LEG_COLOR
		desc.RightLegColor = LEG_COLOR
		return Players:CreateHumanoidModelFromDescription(desc, rig)
	end)
	if not ok or not model then
		model = fallbackDummy(color)
	end
	model.Name = "Training Dummy"
	model:SetAttribute("DummyKind", kind.Id)
	model:SetAttribute("DefaultDummy", isDefault == true)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local maxHealth = kind.MaxHealth or MAX_HEALTH
	hum.MaxHealth = maxHealth
	hum.Health = math.max(1, math.floor(maxHealth * (kind.HealthShare or 1)))
	hum.DisplayName = "Training Dummy"
	-- dummies that walk (attack / moving) get a speed; the rest stay put
	local speed = kind.WalkSpeed or 0
	hum.WalkSpeed = speed
	-- going down, the dummy ragdolls with the hit (QuirkServer) instead of falling apart
	hum.BreakJointsOnDeath = false
	model:SetAttribute("BaseWalkSpeed", speed)
	model:SetAttribute("BaseJumpPower", 0)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	model:PivotTo(cf)
	addLabel(model, kind)
	model.Parent = folder
	Destruction.RegisterCharacter(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	hum.Died:Connect(function()
		task.wait(RESPAWN_TIME)
		if model.Parent then -- skipped if a reset already cleared it
			model:Destroy()
			makeDummy(cf, kind.Id, isDefault)
		end
	end)
	return model
end

local function spawnDefaults()
	for _, cf in SPAWNS do
		task.spawn(makeDummy, cf, "Normal", true)
	end
end
spawnDefaults()

-- Test menu hooks (fired by QuirkServer): ("Spawn", cframe, kind), ("Clear")
-- to remove the spawned ones, or ("Reset") to start over with the defaults
local control = Instance.new("BindableEvent")
control.Name = "DummyControl"
control.Parent = script
control.Event:Connect(function(action, cf, kindId)
	if action == "Spawn" and typeof(cf) == "CFrame" then
		task.spawn(makeDummy, cf, type(kindId) == "string" and kindOf(kindId).Id or "Normal", false)
	elseif action == "Clear" then
		for _, model in folder:GetChildren() do
			if not model:GetAttribute("DefaultDummy") then
				model:Destroy()
			end
		end
	elseif action == "Reset" then
		folder:ClearAllChildren()
		spawnDefaults()
	end
end)
