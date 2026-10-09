-- Headless client run: loads the real QuirkClient + VFX + HUD on Lune's
-- reflection-checked Instances (a misspelled property or wrong type errors),
-- then plays every new effect and HUD flow and fails on any warning/error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local r = require("@lune/roblox")
local Instance, Vector3, Vector2, Enum = r.Instance, r.Vector3, r.Vector2, r.Enum

local SRC = process.args[1] or "../src"
local problems = {}
local function problem(msg)
	table.insert(problems, msg)
	print("  !! " .. msg)
end

---------------------------------------------------------------------------
-- Engine shims
---------------------------------------------------------------------------
local signals = setmetatable({}, { __mode = "k" })
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local e = { fn = fn, live = true }
		table.insert(self.handlers, e)
		return { Disconnect = function() e.live = false end }
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Fire(...)
		local list = {}
		for _, h in self.handlers do
			if h.live then
				table.insert(list, h)
			end
		end
		self.handlers = table.clone(list)
		for _, h in list do
			if h.live then
				task.spawn(function(...)
					local ok, err = pcall(h.fn, ...)
					if not ok then
						problem("signal handler error: " .. tostring(err))
					end
				end, ...)
			end
		end
	end
	function s:Wait()
		local th = coroutine.running()
		self:Once(function(...)
			task.spawn(th, ...)
		end)
		return coroutine.yield()
	end
	return s
end
-- Lune returns a fresh userdata per lookup, so key signals by a stable id
local nextId = 0
local byId = {}
local function signalOf(inst, key)
	local id = inst:GetAttribute("__sigid")
	if not id then
		nextId += 1
		id = nextId
		inst:SetAttribute("__sigid", id)
	end
	byId[id] = byId[id] or {}
	byId[id][key] = byId[id][key] or newSignal()
	return byId[id][key]
end
local _ = signals

local EVENTS = {
	Instance = { "ChildAdded", "DescendantAdded", "AncestryChanged", "Destroying", "Changed" },
	Humanoid = { "Died", "HealthChanged", "StateChanged" },
	GuiButton = { "MouseButton1Click", "Activated", "MouseEnter", "MouseLeave" },
	GuiObject = { "SelectionGained", "SelectionLost", "InputBegan", "InputEnded" },
	Sound = { "Ended", "Loaded", "Played" },
	Player = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded" },
	RunService = { "RenderStepped", "Heartbeat", "Stepped" },
	UserInputService = { "InputBegan", "InputEnded", "JumpRequest", "LastInputTypeChanged" },
	RemoteEvent = { "OnClientEvent" },
	BindableEvent = { "Event" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	ProximityPromptService = { "PromptShown", "PromptHidden" },
	TextBox = { "FocusLost", "Focused" },
}
for className, list in EVENTS do
	for _, ev in list do
		r.implementProperty(className, ev, function(self)
			return signalOf(self, ev)
		end)
	end
end
local attrSignals = setmetatable({}, { __mode = "k" })
r.implementMethod("Instance", "GetAttributeChangedSignal", function(self, k)
	return signalOf(self, "attr:" .. k)
end)
r.implementMethod("Instance", "GetPropertyChangedSignal", function(self, k)
	return signalOf(self, "prop:" .. k)
end)
r.implementMethod("TextBox", "CaptureFocus", function(self)
	self:SetAttribute("__focused", true)
end)
r.implementMethod("TextBox", "ReleaseFocus", function(self)
	self:SetAttribute("__focused", nil)
	signalOf(self, "FocusLost"):Fire(false)
end)
r.implementMethod("TextBox", "IsFocused", function(self)
	return self:GetAttribute("__focused") == true
end)
r.implementMethod("Instance", "WaitForChild", function(self, name)
	for _ = 1, 50 do
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		task.wait(0.02)
	end
	return nil
end)
local function setAttr(inst, k, v)
	inst:SetAttribute(k, v)
	signalOf(inst, "attr:" .. k):Fire()
end
local _ = attrSignals

local noop = function() end
for _, pair in {
	{ "ParticleEmitter", "Emit" }, { "ParticleEmitter", "Clear" }, { "Sound", "Play" }, { "Sound", "Stop" }, { "Sound", "Pause" },
	{ "Humanoid", "TakeDamage" }, { "Humanoid", "Move" }, { "StarterGui", "SetCoreGuiEnabled" },
	{ "ContentProvider", "PreloadAsync" }, { "Debris", "AddItem" }, { "BasePart", "ApplyImpulse" },
	{ "ContextActionService", "SetTitle" },
	{ "ContextActionService", "SetPosition" }, { "ContextActionService", "UnbindAction" },
} do
	r.implementMethod(pair[1], pair[2], noop)
end
-- (the states the client asks its Humanoid for, in order)
local changedStates = {}
r.implementMethod("Humanoid", "ChangeState", function(_, st)
	table.insert(changedStates, st.Name)
end)
local promptPresses = 0
r.implementMethod("ProximityPrompt", "InputHoldBegin", function()
	promptPresses += 1
end)
r.implementMethod("ProximityPrompt", "InputHoldEnd", function() end)
r.implementMethod("Humanoid", "GetState", function()
	return Enum.HumanoidStateType.Running
end)
r.implementMethod("Players", "GetPlayers", function(self)
	return self:GetChildren()
end)
r.implementMethod("Players", "GetPlayerFromCharacter", function(self, char)
	for _, p in self:GetChildren() do
		if p.Character == char then
			return p
		end
	end
	return nil
end)
r.implementMethod("Model", "GetBoundingBox", function(self)
	local root = self:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame or r.CFrame.new(), Vector3.new(4, 5, 2)
end)
r.implementMethod("Model", "GetPivot", function(self)
	local root = self:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame or r.CFrame.new()
end)
r.implementMethod("Model", "GetExtentsSize", function()
	return Vector3.new(4, 5, 2)
end)
r.implementMethod("Workspace", "GetPartBoundsInRadius", function()
	return {}
end)
-- (scenarios can put bodies inside a box: boundsImpl)
local boundsImpl = function()
	return {}
end
r.implementMethod("Workspace", "GetPartBoundsInBox", function(...)
	return boundsImpl(...)
end)
r.implementMethod("RunService", "IsStudio", function()
	return true
end)
-- no world geometry by default; scenarios can swap in a ground (setRaycast)
local raycastImpl = function()
	return nil
end
local function setRaycast(fn)
	raycastImpl = fn or function()
		return nil
	end
end
r.implementMethod("Workspace", "Raycast", function(...)
	return raycastImpl(...)
end)
r.implementMethod("Workspace", "Blockcast", function(_, cf, size, dir, params)
	if blockcastImpl68 then
		return blockcastImpl68(cf, size, dir, params)
	end
	return nil
end)
r.implementMethod("Workspace", "GetServerTimeNow", function()
	return os.clock()
end)
-- keys held down (scenarios set them), and the Humanoid's jump switch
local keysDown = {}
r.implementMethod("UserInputService", "IsKeyDown", function(_, key)
	return keysDown[key.Name] == true -- (by name: Lune hands out a new EnumItem each time)
end)
r.implementMethod("UserInputService", "IsGamepadButtonDown", function()
	return false
end)
r.implementMethod("UserInputService", "IsMouseButtonPressed", function()
	return false
end)
local jumpStateEnabled = true
local stateEnabled = {} -- [state name] = what the client last set it to
r.implementMethod("Humanoid", "SetStateEnabled", function(_, state, on)
	stateEnabled[state.Name] = on
	if state == Enum.HumanoidStateType.Jumping then
		jumpStateEnabled = on
	end
end)
r.implementMethod("Humanoid", "GetStateEnabled", function(_, state)
	return state ~= Enum.HumanoidStateType.Jumping or jumpStateEnabled
end)
r.implementMethod("UserInputService", "GetMouseLocation", function()
	return mouseAt62 or Vector2.new(400, 300) -- (a global: the suite is at its local limit)
end)
local lastInputType = Enum.UserInputType.Keyboard
r.implementMethod("UserInputService", "GetLastInputType", function()
	return lastInputType
end)
local stickPos = Vector3.zero
local stick2Pos = Vector3.zero -- (the right stick)
r.implementMethod("UserInputService", "GetGamepadState", function()
	return { { KeyCode = Enum.KeyCode.Thumbstick1, Position = stickPos }, { KeyCode = Enum.KeyCode.Thumbstick2, Position = stick2Pos } }
end)
r.implementMethod("Camera", "ViewportPointToRay", function(self)
	return r.Ray.new(self.CFrame.Position, Vector3.new(0, 0, -1))
end)
r.implementMethod("Model", "PivotTo", function(self, cf)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end)
getValueImpl = function(_, a) -- (a global: the suite is at its 200-local limit)
	return a
end
r.implementMethod("TweenService", "GetValue", function(...)
	return getValueImpl(...)
end)
-- tweens apply their goal immediately, so every tweened property is type-checked
r.implementMethod("TweenService", "Create", function(_, obj, _info, props)
	return {
		Play = function()
			for k, v in props do
				local ok, err = pcall(function()
					obj[k] = v
				end)
				if not ok then
					problem("tween sets bad property " .. tostring(k) .. " on " .. obj.ClassName .. ": " .. tostring(err))
				end
			end
		end,
		Cancel = noop,
		Pause = noop,
	}
end)
-- animations
local tracks = {}
r.implementMethod("Animator", "LoadAnimation", function(_, anim)
	local t = { Animation = anim, IsPlaying = false, TimePosition = 0, Priority = nil, Looped = false, Length = 3 }
	function t:Play()
		self.IsPlaying = true
		table.insert(tracks, { Id = anim.AnimationId, Track = self })
	end
	function t:Stop()
		self.IsPlaying = false
	end
	function t:AdjustSpeed() end
	return t
end)
-- ContextActionService: remember bindings so the test can press buttons
local actions = {}
local touchButtons = {}
r.implementMethod("ContextActionService", "BindAction", function(_, name, fn, touch)
	actions[name] = fn
	touchButtons[name] = touch
end)
r.implementMethod("ContextActionService", "BindActionAtPriority", function(_, name, fn)
	actions[name] = fn
end)

local game = Instance.new("DataModel")
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- a real frame loop: BindToRenderStep callbacks in priority order, then Stepped
local renderBinds = {}
r.implementMethod("RunService", "BindToRenderStep", function(_, name, priority, fn)
	renderBinds[name] = { p = priority, fn = fn }
end)
r.implementMethod("RunService", "UnbindFromRenderStep", function(_, name)
	renderBinds[name] = nil
end)
task.spawn(function()
	local rs = game:GetService("RunService")
	while true do
		local list = {}
		for _, b in renderBinds do
			table.insert(list, b)
		end
		table.sort(list, function(a, b)
			return a.p < b.p
		end)
		for _, b in list do
			local ok, err = pcall(b.fn, 1 / 60)
			if not ok then
				problem("render step error: " .. tostring(err))
			end
		end
		signalOf(rs, "RenderStepped"):Fire(1 / 60)
		signalOf(rs, "Stepped"):Fire(os.clock(), 1 / 60)
		task.wait(1 / 60)
	end
end)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local cam = Instance.new("Camera")
cam.Parent = workspace
workspace.CurrentCamera = cam
local uis = game:GetService("UserInputService")
for k, v in { TouchEnabled = false, MouseEnabled = true, KeyboardEnabled = true, GamepadEnabled = false } do
	pcall(function()
		uis[k] = v
	end)
end
cam.CFrame = r.CFrame.new(0, 10, 20)
pcall(function()
	cam.ViewportSize = Vector2.new(1280, 720)
end)

local localPlayer = Instance.new("Player")
localPlayer.Name = "Tester"
-- (Roblox's defaults; Lune has none for these)
localPlayer.CameraMinZoomDistance = 0.5
localPlayer.CameraMode = Enum.CameraMode.Classic
uis.MouseDeltaSensitivity = 1
localPlayer.CameraMaxZoomDistance = 128
localPlayer.UserId = 1
localPlayer.Parent = Players
local playerGui = Instance.new("PlayerGui")
playerGui.Parent = localPlayer
pcall(function()
	Players.LocalPlayer = localPlayer
end)
if Players.LocalPlayer ~= localPlayer then
	r.implementProperty("Players", "LocalPlayer", function()
		return localPlayer
	end)
end
print("LocalPlayer ok:", Players.LocalPlayer == localPlayer)
-- read-only engine state that Lune has no default for
local DEFAULTS = {
	Sound = { IsLoaded = true, TimeLength = 1 },
	Part = { Position = Vector3.zero, AssemblyLinearVelocity = Vector3.zero },
	ScreenGui = { AbsoluteSize = Vector2.new(1280, 720) },
	TextButton = { AbsolutePosition = Vector2.new(600, 300), AbsoluteSize = Vector2.new(120, 40) },
	ImageButton = { AbsolutePosition = Vector2.new(600, 300), AbsoluteSize = Vector2.new(120, 40) },
	Humanoid = { MoveDirection = Vector3.zero, FloorMaterial = Enum.Material.Plastic, MaxHealth = 100, Health = 100, Sit = false, CameraOffset = Vector3.zero, Jump = false, HipHeight = 2, PlatformStand = false, AutoRotate = true },
}
padHits = {}
r.implementMethod("PlayerGui", "GetGuiObjectsAtPosition", function()
	return padHits
end)
local InstanceShim = {
	new = function(className, parent)
		local inst = r.Instance.new(className)
		for k, v in DEFAULTS[className] or {} do
			inst[k] = v
		end
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}
local characterRef
r.implementProperty("Player", "Character", function(self)
	return self == localPlayer and characterRef or nil
end, function(self, v)
	if self == localPlayer then
		characterRef = v
	end
end)
r.implementProperty("Player", "DisplayName", function(self)
	return self.Name
end)

-- Random isn't part of Lune's roblox library
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
				return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
			end,
		}
	end,
}
local TweenInfoShim = {
	new = function(...)
		return { ... }
	end,
}

---------------------------------------------------------------------------
-- Rigs
---------------------------------------------------------------------------
local function part(name, parent, size)
	local p = Instance.new("Part")
	p.Position = Vector3.zero
	p.AssemblyLinearVelocity = Vector3.zero
	p.Name = name
	p.Size = size or Vector3.one
	p.Parent = parent
	return p
end
local function motor(name, part0, part1, holder)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = r.CFrame.new(0, 0.5, 0)
	m.Transform = r.CFrame.new() -- (Roblox always has one; Lune needs it set)
	m.Parent = holder or part1
	return m
end

local function makeR15(name, pos)
	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", model, Vector3.new(2, 2, 1))
	root.CFrame = r.CFrame.new(pos)
	root.Position = pos
	local lt = part("LowerTorso", model)
	local ut = part("UpperTorso", model)
	part("Head", model)
	local function rig(m)
		local a = Instance.new("Attachment")
		a.Name = m.Name .. "RigAttachment"
		a.CFrame = m.C0 -- Roblox builds R15 joints from these attachments
		a.Parent = m.Part0
	end
	rig(motor("Root", root, lt))
	rig(motor("Waist", lt, ut))
	rig(motor("Neck", ut, model.Head))
	for _, side in { "Right", "Left" } do
		local ua = part(side .. "UpperArm", model)
		local la = part(side .. "LowerArm", model)
		local hand = part(side .. "Hand", model)
		local ul = part(side .. "UpperLeg", model)
		local ll = part(side .. "LowerLeg", model)
		part(side .. "Foot", model)
		rig(motor(side .. "Shoulder", ut, ua))
		rig(motor(side .. "Elbow", ua, la))
		rig(motor(side .. "Wrist", la, hand))
		rig(motor(side .. "Hip", lt, ul))
		rig(motor(side .. "Knee", ul, ll))
	end
	local hum = InstanceShim.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	model.PrimaryPart = root
	model.Parent = workspace
	return model, hum, root
end

local function makeR6(name, pos)
	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", model, Vector3.new(2, 2, 1))
	root.CFrame = r.CFrame.new(pos)
	root.Position = pos
	local torso = part("Torso", model)
	part("Head", model)
	motor("RootJoint", root, torso, root)
	motor("Neck", torso, model.Head, torso)
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local limb = part(n, model)
		local joint = n:gsub("Arm", "Shoulder"):gsub("Leg", "Hip")
		motor(joint, torso, limb, torso)
	end
	local hum = InstanceShim.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	model.Parent = workspace
	return model, hum, root
end

---------------------------------------------------------------------------
-- Load the real client code
---------------------------------------------------------------------------
local function env(scriptInst)
	local e = {
		game = game,
		workspace = workspace,
		script = scriptInst,
		Instance = InstanceShim,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = r.CFrame,
		Color3 = r.Color3,
		Font = r.Font, -- (round 102: the HUD uses Font.new since the owner's round 100)
		ColorSequence = r.ColorSequence,
		ColorSequenceKeypoint = r.ColorSequenceKeypoint,
		NumberSequence = r.NumberSequence,
		NumberSequenceKeypoint = r.NumberSequenceKeypoint,
		NumberRange = r.NumberRange,
		UDim = r.UDim,
		UDim2 = r.UDim2,
		Enum = Enum,
		Ray = r.Ray,
		Random = RandomShim,
		TweenInfo = TweenInfoShim,
		RaycastParams = { new = function() return {} end },
		OverlapParams = { new = function() return {} end },
		task = task,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			problem("warn: " .. table.concat(parts, " "))
		end,
	}
	e.require = function(mod)
		local cached = rawget(env, "_cache_" .. mod:GetFullName())
		return cached
	end
	return setmetatable(e, { __index = _G })
end
local moduleCache = {}
local function loadModule(path, inst)
	local e = env(inst)
	e.require = function(mod)
		return moduleCache[mod]
	end
	local fn = luau.load(fs.readFile(path), { debugName = inst.Name, environment = e })
	moduleCache[inst] = fn()
	return moduleCache[inst]
end

local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local fired = {}
for _, n in { "UseAbility", "SelectQuirk", "PlayVFX", "TestCommand", "Shop", "Settings", "Uno", "Console" } do
	local re = Instance.new("RemoteEvent")
	re.Name = n
	re.Parent = remotes
end
r.implementMethod("RemoteEvent", "FireServer", function(self, ...)
	table.insert(fired, { self.Name, ... })
end)

local function newModule(name)
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Parent = shared
	return m
end
local Config = loadModule(SRC .. "/ReplicatedStorage.Shared.QuirkConfig.lua", newModule("QuirkConfig"))
for n, spec in Config.EmoteShop.Robux do
	spec.Product = 72000 + n
end
prompts72 = {}
r.implementMethod("MarketplaceService", "PromptProductPurchase", function(_, _plr, id)
	table.insert(prompts72, id)
end)
r.implementMethod("MarketplaceService", "GetProductInfo", function(_, id)
	return { PriceInRobux = 30 + (id - 72000) }
end)
loadModule(SRC .. "/ReplicatedStorage.Shared.SpikeLayouts.lua", newModule("SpikeLayouts"))
local VFX = loadModule(SRC .. "/ReplicatedStorage.Shared.VFX.lua", newModule("VFX"))
local HUD = loadModule(SRC .. "/ReplicatedStorage.Shared.HUD.lua", newModule("HUD"))

local myChar, myHum, myRoot = makeR15("Tester", Vector3.new(0, 3, 0))
myHum.MaxHealth = 200
myHum.Health = 200
characterRef = myChar
localPlayer.Character = myChar
print("Character ok:", localPlayer.Character == myChar)

local clientScript = Instance.new("LocalScript")
clientScript.Name = "QuirkClient"
clientScript.Parent = StarterPlayer
local ce = env(clientScript)
ce.require = function(mod)
	return moduleCache[mod]
end
local clientFn = luau.load(fs.readFile(SRC .. "/StarterPlayer.StarterPlayerScripts.QuirkClient.client.lua"), { debugName = "QuirkClient", environment = ce })
local ok, err = pcall(clientFn)
if not ok then
	problem("QuirkClient top level: " .. tostring(err))
end
localPlayer.CharacterAdded:Fire(myChar)
task.wait(0.2)
Config.__startPhone67 = HUD.MenuVisible()
localPlayer:SetAttribute("Quirk", "Explosion")
signalOf(localPlayer, "attr:Quirk"):Fire()
task.wait(0.1)

print("== sounds")
local soundCount = 0
for name in Config.Sounds do
	VFX.PlaySound(name, Vector3.new(0, 3, 0), 1)
	VFX.PlaySound(name, nil, 1)
	soundCount += 1
end
local sounds = 0
for _, d in game:GetService("SoundService"):GetDescendants() do
	if d:IsA("Sound") then
		sounds += 1
	end
end
for _, d in workspace.Terrain:GetDescendants() do
	if d:IsA("Sound") then
		sounds += 1
	end
end
print(string.format("  %d cues fired, %d Sound instances alive", soundCount, sounds))
if sounds == 0 then
	problem("no sounds were created")
end
for _, d in game:GetService("SoundService"):GetDescendants() do
	if d:IsA("Sound") and d.SoundGroup == nil then
		problem("sound without SoundGroup")
		break
	end
end
-- takes: every Sound plays a configured id, and a take's own Start is honoured
local known = {}
-- (the ult themes: licensed music, not fight-sound takes)
for _, spec in (Config.UltMusic and Config.UltMusic.Tracks) or {} do
	known[spec.Id] = spec.Start or 0
end
if Config.UltMusic and Config.UltMusic.Default then
	known[Config.UltMusic.Default.Id] = 0
end
for _, cue in Config.Sounds do
	for _, layer in ipairs(type(cue) == "table" and cue or {}) do
		for _, t in ipairs(type(layer.Id) == "table" and layer.Id or { layer.Id }) do
			if type(t) == "table" then
				known[t.Id] = t.Start or layer.Start or 0
			else
				known[t] = layer.Start or 0
			end
		end
	end
end
local checked = 0
for _, root in { game:GetService("SoundService"), workspace.Terrain } do
	for _, d in root:GetDescendants() do
		if d:IsA("Sound") then
			checked += 1
			if known[d.SoundId] == nil then
				problem("sound plays an unconfigured id: " .. tostring(d.SoundId))
			end
		end
	end
end
Config.Sounds.__TakeTest = { { Id = { { Id = "rbxassetid://9113960355", Start = 0.26 }, { Id = "rbxassetid://9113961593", Start = 0.16 } }, Volume = 1 } }
local seenTakes = {}
-- (sounds never end in this harness, so the effects before this can fill
-- every voice until the 12 s fallback lets them go: keep playing until both
-- takes have turned up)
for _ = 1, 260 do
	if seenTakes["rbxassetid://9113960355"] and seenTakes["rbxassetid://9113961593"] then
		break
	end
	VFX.PlaySound("__TakeTest", nil, 1)
	task.wait(0.05)
	for _, d in game:GetService("SoundService"):GetDescendants() do
		if d:IsA("Sound") and (d.SoundId == "rbxassetid://9113960355" or d.SoundId == "rbxassetid://9113961593") then
			local want = d.SoundId == "rbxassetid://9113960355" and 0.26 or 0.16
			if math.abs(d.TimePosition - want) > 1e-3 then
				problem(string.format("take %s started at %.2f, wants %.2f", d.SoundId, d.TimePosition, want))
			end
			seenTakes[d.SoundId] = true
			d:Destroy()
		end
	end
end
Config.Sounds.__TakeTest = nil
local nTakes = 0
for _ in seenTakes do
	nTakes += 1
end
print(string.format("  %d sounds use configured ids; random takes seen: %d of 2", checked, nTakes))
if nTakes < 2 then
	problem("random takes never varied")
end

print("== effects (R15)")
local other, otherHum = makeR15("Other", Vector3.new(0, 3, -6))
local function play(id, data, char)
	VFX.Play(id, char or myChar, data, true)
end
for count = 1, 4 do
	play("Punch", { Count = count, Finisher = count == 4 })
end
play("Hit", { Target = other, Amount = 5, Attacker = localPlayer })
play("Hit", { Target = other, Amount = 30, Attacker = localPlayer })
for _, kind in { "Front", "Back", "Left", "Right", "Side" } do
	play("Dash", { Dir = Vector3.new(0, 0, -1), Kind = kind, Quirk = "Engine" })
end
local aim = { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -30), Seed = 42, Origin = Vector3.new(0, 3, 0) }
for _, id in { "Howitzer", "DetroitSmash", "IceWall", "ReciproBurst", "StunGrenade", "SuperLeap" } do
	play(id, aim)
end
play("SuperLand", { Pos = Vector3.new(0, 0, 0) })
play("MuscleForm", { Alt = true })
play("MuscleForm", { Alt = false })
task.wait(0.1)
local flexPlays = 0
for _, t in tracks do
	if t.Id == Config.Animations.Moves.MuscleForm.Id then
		flexPlays += 1
	end
end
if flexPlays ~= 1 then
	problem("flex animation played " .. flexPlays .. " times (expected 1: power-up only)")
end
play("SideSwap", { Alt = true })
play("SideSwap", { Alt = false })
for _, q in Config.QuirkOrder do
	play("UltActivate", { Quirk = q })
end
task.wait(1.5)
local ids = {}
for _, t in tracks do
	ids[t.Id] = true
end
if not ids[Config.Animations.Land.Id] then
	problem("Hero Landing slot didn't play on SuperLand")
end
if not ids[Config.Animations.Moves.MuscleForm.Id] then
	problem("Bodybuilder slot didn't play on MuscleForm")
end
for _, q in Config.QuirkOrder do
	local slot = Config.Animations.Ult[q]
	if type(slot) == "table" and not ids[slot.Id] then
		problem("awakening animation missing for " .. q)
	end
end

print("== guard / parry / break / KO")
play("Guard", { On = true, Target = myChar })
task.wait(0.1)
if not myChar:FindFirstChild("GuardShield") then
	problem("guard shield not created")
end
setAttr(myChar, "Guard", 30)
play("Block", { Target = myChar, From = Vector3.new(0, 3, -6) })
play("Parry", { Target = myChar, Attacker = other })
play("Guard", { On = true, Target = myChar })
play("GuardBreak", { Target = myChar, Duration = 0.5 })
play("Guard", { On = false, Target = myChar })
play("KO", { Target = other, Pos = other.HumanoidRootPart.Position })
play("Freeze", { Target = other, Duration = 0.2 })

print("== motion on R6")
local r6 = makeR6("R6Guy", Vector3.new(10, 3, 0))
for count = 1, 4 do
	VFX.Play("Punch", r6, { Count = count, Finisher = count == 4 }, false)
end
VFX.Play("Guard", r6, { On = true, Target = r6 }, false)
VFX.Play("Guard", r6, { On = false, Target = r6 }, false)
VFX.Play("UltActivate", r6, { Quirk = "OneForAll" }, false)
VFX.Play("Hit", nil, { Target = r6, Amount = 25 }, false)
task.wait(1.2)
local shoulder = r6.Torso:FindFirstChild("Right Shoulder")
if not shoulder then
	problem("R6 rig missing shoulder")
end

print("== HUD flows via PlayVFX")
local PlayVFX = remotes:FindFirstChild("PlayVFX")
print("  PlayVFX handlers:", #signalOf(PlayVFX, "OnClientEvent").handlers, "gui:", playerGui:FindFirstChild("QuirkHUD"))
PlayVFX.OnClientEvent:Fire("Hit", nil, { Target = other, Amount = 7, Attacker = localPlayer })
PlayVFX.OnClientEvent:Fire("Hit", nil, { Target = other, Amount = 9, Attacker = localPlayer })
PlayVFX.OnClientEvent:Fire("Hit", nil, { Target = other, Amount = 12, Attacker = localPlayer })
PlayVFX.OnClientEvent:Fire("Parry", nil, { Target = myChar, Attacker = other, By = localPlayer })
PlayVFX.OnClientEvent:Fire("Parry", nil, { Target = other, Attacker = myChar, Against = localPlayer })
PlayVFX.OnClientEvent:Fire("GuardBreak", nil, { Target = myChar, Duration = 0.3 })
PlayVFX.OnClientEvent:Fire("KOFeed", nil, { Killer = "Tester", KillerQuirk = "Explosion", Victim = "Other", VictimQuirk = "Engine", Streak = 3, Callout = "ON A ROLL" })
PlayVFX.OnClientEvent:Fire("KOFeed", nil, { Victim = "Faller", Shutdown = 5 })
PlayVFX.OnClientEvent:Fire("KOFeed", nil, { Killer = "Tester", Victim = "Training Dummy", Dummy = true })
PlayVFX.OnClientEvent:Fire("KOConfirm", nil, { Victim = "Other", Streak = 3, Counted = true, Callout = "ON A ROLL", Heal = 30 })
PlayVFX.OnClientEvent:Fire("KOConfirm", nil, { Victim = "Training Dummy", Streak = 0, Counted = false, Heal = 0 })
PlayVFX.OnClientEvent:Fire("Recap", nil, { Killer = "Other", KillerQuirk = "Engine", KillerHealth = 54, KillerMaxHealth = 200, Dealt = 120, Taken = 200, Hits = 18, KOs = 1, Parries = 2, Blocked = 5, BiggestHit = 40, Time = 95.4, StreakEnded = 3, TotalKOs = 7, BestStreak = 4 })
PlayVFX.OnClientEvent:Fire("Recap", nil, { Dealt = 0, Taken = 0, Hits = 0, KOs = 0, Parries = 0, Blocked = 0, BiggestHit = 0, Time = 3 })
task.wait(0.2)
local gui = playerGui:FindFirstChild("QuirkHUD")
local feed = gui and gui:FindFirstChild("KillFeed")
local rows = 0
for _, c in feed and feed:GetChildren() or {} do
	if c:IsA("TextLabel") then
		rows += 1
	end
end
if rows ~= 3 then
	problem("kill feed rows: " .. rows)
end
if not (gui and gui:FindFirstChild("Recap")) then
	problem("recap panel missing")
end
local combo = gui and gui:FindFirstChild("Combo")
local hitsLabel = combo and combo:FindFirstChildOfClass("TextLabel")
print("  combo label:", hitsLabel and hitsLabel.Text)
if not (hitsLabel and hitsLabel.Text == "3 HITS") then
	problem("combo counter didn't reach 3 HITS")
end

print("== guard input (hold F)")
table.clear(fired)
local blockFn = actions.QuirkBlock
if not blockFn then
	problem("QuirkBlock action not bound")
else
	blockFn("QuirkBlock", Enum.UserInputState.Begin, {})
	task.wait(0.05)
	local sentOn = fired[1] and fired[1][1] == "UseAbility" and fired[1][2] == Config.BLOCK_INDEX and fired[1][3] == true
	if not sentOn then
		problem("pressing block didn't send BLOCK true")
	end
	-- attacks are refused while guarding
	table.clear(fired)
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, {})
	if #fired ~= 0 then
		problem("ability fired while guarding")
	end
	-- the server breaks the guard -> client drops it without echoing
	setAttr(myChar, "Blocking", true)
	setAttr(myChar, "Blocking", false)
	task.wait(0.05)
	table.clear(fired)
	blockFn("QuirkBlock", Enum.UserInputState.End, {})
	if #fired ~= 0 then
		problem("releasing after a server-side drop re-sent BLOCK false")
	end
	blockFn("QuirkBlock", Enum.UserInputState.Begin, {})
	blockFn("QuirkBlock", Enum.UserInputState.End, {})
	local last = fired[#fired]
	if not (last and last[2] == Config.BLOCK_INDEX and last[3] == false) then
		problem("releasing block didn't send BLOCK false")
	end
end


print("== DECAY effects")
local near = makeR15("Near", Vector3.new(0, 3, -12))
play("DecayWave", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -30) })
play("DecayGrasp", { Dir = Vector3.new(0, 0, -1) })
play("RivetStab", { Dir = Vector3.new(0, 0, -1) })
play("RadioWaves", { Dir = Vector3.new(0, 0, -1) })
play("RivetStorm", {})
play("Grasped", { Target = near }, myChar)
play("Decaying", { Target = near, Duration = 0.6 }, myChar)
play("Dash", { Dir = Vector3.new(0, 0, -1), Kind = "Front", Quirk = "Decay" })
myChar:SetAttribute("UltActive", true)
myChar:SetAttribute("Quirk", "Decay")
play("Punch", { Count = 4, Finisher = true })
task.wait(1.5)
myChar:SetAttribute("UltActive", false)

print("== cinematics")
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Custom
cam.FieldOfView = 70
local hudGui = playerGui:FindFirstChild("QuirkHUD")
-- (globals: this chunk is at Luau's 200-local limit further down)
WHEEL58 = { "Wave", "Dance", "Flex", "Kamehameha" }
function fullWheel58()
	local all = {}
	for _, e in Config.Emotes do
		table.insert(all, e.Id)
	end
	setAttr(localPlayer, "EmotesOwned", table.concat(all, ","))
	setAttr(localPlayer, "EmoteWheel", table.concat(WHEEL58, ","))
	task.wait(0.05)
end
fullWheel58()
local function restoredOk(label)
	local ok = cam.CameraType == Enum.CameraType.Custom and math.abs(cam.FieldOfView - 70) < 0.01 and hudGui.Enabled and not VFX.InCinematic()
	if not ok then
		problem(label .. string.format(" (type %s, fov %.1f, hud %s, active %s)", tostring(cam.CameraType), cam.FieldOfView, tostring(hudGui.Enabled), tostring(VFX.InCinematic())))
	else
		print("  ok    " .. label)
	end
end
local function shotLength(key)
	local t = 0
	for _, shot in VFX.Shots[key] do
		t += shot.T
	end
	return t
end

play("TotalDecay", aim)
task.wait(0.3)
if not (cam.CameraType == Enum.CameraType.Scriptable and VFX.InOwnCinematic()) then
	problem("Total Decay didn't start the caster's cutscene")
end
if hudGui.Enabled then
	problem("HUD should step aside during your cutscene")
end
if not playerGui:FindFirstChild("QuirkCinema") then
	problem("letterbox missing")
end
table.clear(fired)
actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, {})
if #fired ~= 0 then
	problem("abilities should be held during your own cutscene")
end
-- someone else's big move can't steal your camera mid-cutscene
VFX.Play("USSCatch", near, { Dir = aim.Dir, Build = 2, Freeze = 0.38, Slam = 0.12 }, false) -- (round 78: its cutscene starts on the catch)
task.wait(0.1)
if not VFX.InOwnCinematic() then
	problem("a witness cut interrupted the caster's cutscene")
end
task.wait(shotLength("TotalDecay") + 0.3)
restoredOk("camera + HUD restored after Total Decay")

-- witnesses: someone nearby fires a finisher
VFX.Play("USSCatch", near, { Dir = aim.Dir, Build = 2, Freeze = 0.38, Slam = 0.12 }, false) -- (round 78: its cutscene starts on the catch)
task.wait(0.2)
if not (VFX.InCinematic() and not VFX.InOwnCinematic()) then
	problem("nearby players should get a witness cut")
end
table.clear(fired)
actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, {})
if #fired == 0 then
	problem("a witness cut shouldn't lock your inputs")
end
task.wait(1.2)
restoredOk("camera restored after a witness cut")
-- far away: nothing
local far = makeR15("Far", Vector3.new(0, 3, -400))
VFX.Play("UnitedStatesSmash", far, aim, false)
task.wait(0.2)
if VFX.InCinematic() then
	problem("far-away players shouldn't get a cut")
end
task.wait(0.2)

-- every finisher's own cutscene plays out and hands the camera back
for _, key in { "USSCatch", "HeatwaveMax", "ReciproMax", "TotalDecay" } do -- (round 78: USS's cutscene is on the catch)
	lastUsedWait = nil
	play(key, aim)
	task.wait(0.2)
	if not VFX.InOwnCinematic() then
		problem(key .. " didn't start its cutscene")
	end
	task.wait(shotLength(key) + 0.4)
	restoredOk("restored after " .. key)
end

-- awakening sweep, then cancelled early (e.g. respawn)
play("UltActivate", { Quirk = "Decay" })
task.wait(0.2)
if not VFX.InOwnCinematic() then
	problem("awakening didn't start its sweep")
end
VFX.CancelCinematic()
task.wait(0.2)
restoredOk("cancel restores immediately")

-- the caster's body is cut off mid-cutscene: camera must still come back
local victim = makeR15("Victim", Vector3.new(5, 3, 0))
VFX.Cinematic(victim, VFX.Shots.TotalDecay, { Own = true, Title = "TEST" })
task.wait(0.3)
victim:Destroy()
task.wait(0.3)
restoredOk("restored when the subject disappears")

print("== quirk menu")
local function menuButtons()
	local shown, decayBtn = 0, nil
	for _, d in hudGui:GetDescendants() do
		if d:IsA("TextButton") and Config.Quirks[d.Name] then
			if d.Visible then
				shown += 1
			end
			if d.Name == "Decay" then
				decayBtn = d
			end
		end
	end
	return shown, decayBtn
end
local total, public = 0, 0
for _, q in Config.Quirks do
	total += 1
	if not q.DevOnly then
		public += 1
	end
end
HUD.SetDevAccess(false)
local shown, decayBtn = menuButtons()
if not (shown == public and decayBtn and decayBtn.Visible) then
	problem("non-testers should see " .. public .. " quirks, Decay among them now (saw " .. shown .. ")")
end
HUD.SetDevAccess(true)
shown = menuButtons()
if shown ~= total then
	problem("testers should see " .. total .. " quirks (saw " .. shown .. ")")
end
print(string.format("  menu: %d public, %d with dev access", public, total))


print("== ONE FOR ALL: V slot (a 4th move in every form), Colorado Smash, United States of Smash")
local function slotSays(slot, text)
	for _, c in slot and slot:GetChildren() or {} do
		if c:IsA("TextLabel") and c.Text == text then
			return true
		end
	end
	return false
end
HUD.SetQuirk("OneForAll", false, true, false)
local vslot = hudGui:FindFirstChild("Slot4", true) -- (the 4th move: key 4, was V)
if not (vslot and vslot.Visible and slotSays(vslot, "HERO'S COUNTER")) then
	problem("V slot should show Hero's Counter in true form")
end
HUD.SetQuirk("OneForAll", true, false, false)
if not (vslot and vslot.Visible and slotSays(vslot, "COLORADO SMASH")) then
	problem("V slot should show Colorado Smash in muscle form")
end
HUD.SetQuirk("OneForAll", true, false, true)
if not (vslot and vslot.Visible and slotSays(vslot, "WEATHER CHANGER")) then
	problem("V slot should show Weather Changer during Plus Ultra")
end
-- every quirk has a 4th move, in every form
for _, q in Config.QuirkOrder do
	for _, form in { { false, false }, { true, false }, { false, true } } do
		HUD.SetQuirk(q, form[1], false, form[2], 1)
		if not (vslot and vslot.Visible) then
			problem(q .. " should have a 4th move (alt " .. tostring(form[1]) .. ", ult " .. tostring(form[2]) .. ")")
		end
	end
end
-- Deku: the V slot is whichever quirk R has picked, R says what's next
HUD.SetQuirk("FullCowl", false, false, false, 1)
local rslot = hudGui:FindFirstChild("SlotR", true)
if not slotSays(vslot, "BLACKWHIP") or not slotSays(rslot, "NEXT: SMOKESCREEN") then
	problem("Deku's V slot should be Blackwhip, with R showing what's next")
end
HUD.SetQuirk("FullCowl", false, false, false, 2)
if not slotSays(vslot, "SMOKESCREEN") or not slotSays(rslot, "NEXT: FLOAT") then
	problem("after R, Deku's V slot should be Smokescreen")
end
HUD.SetQuirk("OneForAll", true, false, true)
local aimFar = { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 3, -60), Seed = 3, Origin = Vector3.new(0, 3, 0) }
play("ColoradoSmash", aimFar)
task.wait(0.2)
play("ColoradoGo", { Pos = Vector3.new(0, 3, -60), Time = 1.5 }) -- (round 75: aimed from the sky - the server says go)
task.wait(0.1)
if not VFX.InOwnCinematic() then
	problem("Colorado Smash should play its cutscene")
end
task.wait(0.3 + 1.5 + 1.2)
restoredOk("restored after Colorado Smash")
play("ColoradoLand", { Pos = Vector3.new(0, 0, -60) })
-- someone else lands next to you
VFX.Play("ColoradoAim", near, { Pos = myChar.HumanoidRootPart.Position + Vector3.new(10, 0, 0), Time = 1 }, false)
task.wait(0.2)
if not (VFX.InCinematic() and not VFX.InOwnCinematic()) then
	problem("standing near a Colorado Smash landing should cut to it")
end
task.wait(1.2)
restoredOk("restored after the landing witness cut")
play("USSCatch", aim) -- (round 78: the cutscene's on the catch)
task.wait(0.2)
if not VFX.InOwnCinematic() then
	problem("United States of Smash should play its cutscene")
end
task.wait(shotLength("USSCatch") + 0.4)
restoredOk("restored after United States of Smash")

print("== DEV ACCESS panel")
local friend = Instance.new("Player")
friend.Name = "Friend"
pcall(function()
	friend.DisplayName = "Friend"
end)
friend.UserId = 4242
friend.Parent = Players
localPlayer:SetAttribute("Tester", true)
signalOf(localPlayer, "attr:Tester"):Fire()
task.wait(0.1)
signalOf(Players, "PlayerAdded"):Fire(friend)
task.wait(0.2)
local panel = hudGui:FindFirstChild("DevAccess")
local grantButton
for _, d in panel and panel:GetDescendants() or {} do
	if d:IsA("TextButton") and d.Text == "GRANT" then
		grantButton = d
	end
end
if not grantButton then
	problem("the panel should list Friend with a GRANT button")
else
	table.clear(fired)
	signalOf(grantButton, "MouseButton1Click"):Fire()
	task.wait(0.05)
	local f = fired[1]
	if not (f and f[1] == "TestCommand" and f[2] == "GrantDev" and f[3] == 4242 and f[4] == true) then
		problem("GRANT should send GrantDev for Friend")
	end
end
friend:SetAttribute("DevAccess", true)
signalOf(friend, "attr:DevAccess"):Fire()
task.wait(0.1)
local revoke
for _, d in panel and panel:GetDescendants() or {} do
	if d:IsA("TextButton") and d.Text == "REVOKE" then
		revoke = d
	end
end
if not revoke then
	problem("a granted player should show REVOKE")
end
-- the dummy spawner: every kind has a button that asks the server for it
do
	local dpanel = hudGui:FindFirstChild("DummySpawner")
	if not dpanel then
		problem("the test menu should have a dummy spawner panel")
	else
		local found = 0
		for _, kind in Config.DummyKinds do
			local b = dpanel:FindFirstChild(kind.Id)
			if b then
				found += 1
				table.clear(fired)
				signalOf(b, "MouseButton1Click"):Fire()
				task.wait(0.02)
				local f = fired[1]
				if not (f and f[1] == "TestCommand" and f[2] == "SpawnDummy" and f[3] == kind.Id) then
					problem("the " .. kind.Id .. " button should send SpawnDummy " .. kind.Id)
				end
			end
		end
		if found ~= #Config.DummyKinds then
			problem("the spawner should list every dummy kind (" .. found .. "/" .. #Config.DummyKinds .. ")")
		end
		print("  dummy spawner:", found, "kinds")
	end
end
PlayVFX.OnClientEvent:Fire("Notice", nil, { Text = "Tester gave you access to DEV characters (press M)" })
task.wait(0.1)
local noticed = false
for _, d in hudGui:GetChildren() do
	if d:IsA("TextLabel") and d.Text:find("DEV characters") then
		noticed = true
	end
end
if not noticed then
	problem("notice toast missing")
end

print("== ONE FOR ALL: 9TH (Deku)")
local RS = game:GetService("RunService")
local function beat(n)
	for _ = 1, n do
		signalOf(RS, "Heartbeat"):Fire(1 / 60)
		task.wait(1 / 60)
	end
end
local function lit(char)
	-- visible green arc segments near this character
	local root = char:FindFirstChild("HumanoidRootPart")
	local n = 0
	for _, p in VFX.Folder:GetChildren() do
		local c = p:IsA("BasePart") and p.Color
		local cowl = c and ((math.abs(c.R * 255 - 148) < 1 and math.abs(c.B * 255 - 203) < 1) or (math.abs(c.R * 255 - 242) < 1 and math.abs(c.B * 255 - 249) < 1))
		if cowl and p.Material == Enum.Material.Neon and p.Transparency < 1 and p.Size.X <= 0.13 and root and (p.Position - root.Position).Magnitude < 6 then
			n += 1
		end
	end
	return n
end
-- (the harness never cleans up old effect parts, so count against a baseline)
local baseline = lit(myChar)
myChar:SetAttribute("Quirk", "Explosion")
myChar:SetAttribute("QuirkAlt", false)
beat(6)
if lit(myChar) > baseline then
	problem("no Full Cowl lightning on anyone but Deku")
end
myChar:SetAttribute("Quirk", "FullCowl") -- (always in Full Cowl: no form to switch on)
local arcs = 0
for _ = 1, 8 do
	beat(1)
	arcs = math.max(arcs, lit(myChar) - baseline)
end
if arcs <= 0 then
	problem("Deku should always crawl with Full Cowl's green lightning")
end
myChar:SetAttribute("UltActive", true)
beat(8)
print(string.format("  Full Cowl arcs lit: %d (45%%), %d (100%%)", arcs, lit(myChar) - baseline))
myChar:SetAttribute("UltActive", false)
local deku = {
	{ "QuirkCycle", {} }, { "DelawareSmash", aim }, { "Blackwhip", aim }, { "Smokescreen", aim },
	{ "StLouisSmash", aim }, { "FaJinSmash", aim }, { "GearshiftRush", aim }, { "BlackwhipSlam", aim },
}
for _, e in deku do
	play(e[1], e[2])
	task.wait(0.05)
end
VFX.Play("BlackwhipCatch", other, { Target = myChar, Dir = Vector3.new(0, 0, 1) }, false)
VFX.Play("BlackwhipBind", myChar, { Targets = { other } }, false)
VFX.Play("ManchesterLand", myChar, { Pos = Vector3.new(0, 0, -20) }, false)
VFX.Play("Smoked", nil, { Duration = 1 }, false)
task.wait(1.5)
for _ = 1, 3 do
	play("Punch", { Count = 1 })
	task.wait(0.35)
end
play("Float", aim)
task.wait(0.1)
if myChar.HumanoidRootPart:FindFirstChild("Float") then
	problem("Float (round 75): pressed on the street, it doesn't lift him (the jump does - round 75's own tests)")
end
play("ManchesterSmash", aimFar)
task.wait(1.5)
-- INFINITE 100% (the fist storm): the launch, the catch, the strikes, the finish - and a cancel
play("FistRain", aim)
task.wait(0.25)
VFX.Play("FistRainCatch", myChar, { Target = other, Air = true, Hits = 8, Interval = 0.075, RiseTime = 0.2 }, false)
task.wait(0.2)
for i = 1, 8 do
	VFX.Play("FistRainStrike", myChar, { Target = other, Pos = other.HumanoidRootPart.Position, Index = i, Final = false }, false)
	task.wait(0.075)
end
VFX.Play("FistRainFinish", myChar, { Target = other, Pos = Vector3.new(0, 0, -6), Air = true }, false)
task.wait(0.4)
VFX.Play("FistRainCatch", myChar, { Target = other, Air = false, Hits = 8, Interval = 0.075, RiseTime = 0.2 }, false)
task.wait(0.1)
VFX.Play("FistRainCancel", myChar, { Target = other }, false)
VFX.Play("CowlKickHit", myChar, { Pos = Vector3.new(0, 3, -6), Dir = Vector3.new(0, 0, -1), Air = false }, false)
VFX.Play("CowlKickHit", myChar, { Pos = Vector3.new(0, 3, -6), Dir = Vector3.new(0, -1, 0), Air = true }, false)
task.wait(2)
if VFX.InOwnCinematic() then
	problem("Infinite 100%'s cutscene ends by itself (it shouldn't leave one running)")
end
VFX.Play("UltActivate", other, { Quirk = "FullCowl" }, false)
task.wait(1)
myChar:SetAttribute("Quirk", "Explosion")
local before = lit(myChar)
beat(10)
if lit(myChar) >= before and before > 0 then
	problem("the lightning stops when he's not Deku any more")
end

print("== LIMITLESS")
myChar:SetAttribute("Quirk", "Limitless")
myChar:SetAttribute("Infinity", true)
beat(3)
local shell = false
for _, p in VFX.Folder:GetChildren() do
	if p:IsA("BasePart") and p.Material == Enum.Material.ForceField and p.Shape == Enum.PartType.Ball then
		shell = true
	end
end
if not shell then
	problem("Infinity should shimmer around him")
end
myChar:SetAttribute("Infinity", false)
beat(3)
play("Infinity", aim)
VFX.Play("InfinityStop", nil, { Target = myChar, From = Vector3.new(0, 3, -5) }, false)
play("LapseBlue", aim)
play("ReversalRed", aim)
task.wait(0.5)
VFX.Play("RedBurst", myChar, { Pos = Vector3.new(0, 3, -25), Radius = 20 }, false)
task.wait(2)
local startPos = myChar.HumanoidRootPart.CFrame.Position
play("Blink", { Dir = Vector3.new(0, 0, -1), Pos = startPos + Vector3.new(0, 0, -30), Origin = startPos })
task.wait(0.1)
-- (Lune keeps Position and CFrame separately; Roblox moves both)
local moved = (myChar.HumanoidRootPart.CFrame.Position - startPos).Magnitude
myChar.HumanoidRootPart.CFrame = r.CFrame.new(startPos)
if moved < 20 then
	problem("Blink should move you toward the aim point (moved " .. moved .. ")")
end
play("HollowPurple", aim)
task.wait(0.2)
if not VFX.InOwnCinematic() then
	problem("Hollow Purple should play its cutscene")
end
task.wait(shotLength("HollowPurple") + 0.4)
restoredOk("restored after Hollow Purple")
VFX.Play("Domain", other, { Pos = Vector3.new(0, 0, 0), Radius = 60, Duration = 3 }, false)
task.wait(1.2)
local dome = VFX.Folder:FindFirstChild("UnlimitedVoid")
local panels = 0
for _, p in dome and dome:GetChildren() or {} do
	if p:IsA("BasePart") and p.Size.X > 10 then
		panels += 1
	end
end
if panels < 60 then
	problem("the domain dome should be built from panels (got " .. panels .. ")")
end
workspace.CurrentCamera.CFrame = r.CFrame.new(0, 5, 10) -- standing inside the dome
beat(15)
if not game:GetService("Lighting"):FindFirstChild("UnlimitedVoid") then
	problem("inside the domain the view should be tinted")
end
VFX.Play("VoidOverload", nil, { Duration = 1 }, false)
VFX.Play("DomainEnd", other, { Pos = Vector3.new(0, 0, 0), Radius = 60 }, false)
task.wait(1)
beat(15)
if VFX.Folder:FindFirstChild("UnlimitedVoid") then
	problem("the dome should collapse")
end
if game:GetService("Lighting"):FindFirstChild("UnlimitedVoid") then
	problem("the tint should clear once the domain is gone")
end
VFX.Play("UltActivate", other, { Quirk = "Limitless" }, false)
task.wait(1.5)

print("== M1 step-in + movement animations")
local function lunges(root)
	local n = 0
	for _, d in root:GetChildren() do
		if d.Name == "LungeAttachment" then
			n += 1
		end
	end
	return n
end
myChar:SetAttribute("Quirk", "Explosion")
myChar:SetAttribute("QuirkAlt", false)
myChar:SetAttribute("UltActive", false)
local rootNow = myChar.HumanoidRootPart
local before = lunges(rootNow)
play("Punch", { Count = 1 })
task.wait(0.07)
local lvFound
for _, d in rootNow:GetChildren() do
	if d:IsA("LinearVelocity") and d.VelocityConstraintMode == Enum.VelocityConstraintMode.Plane then
		lvFound = d
	end
end
if lunges(rootNow) ~= before + 1 or not lvFound then
	problem("the M1 step-in should slide you along the ground (Plane LinearVelocity)")
elseif lvFound.MaxForce == math.huge then
	problem("the step-in must use a bounded force")
end
-- someone right in front: no step-in (shoving into a body is what flings people)
local dummiesFolder = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
dummiesFolder.Name = "Dummies"
dummiesFolder.Parent = workspace
local blocker = makeR15("Blocker", rootNow.Position + rootNow.CFrame.LookVector * 3)
blocker.Parent = dummiesFolder
task.wait(0.5)
before = lunges(rootNow)
play("Punch", { Count = 2 })
task.wait(0.07)
if lunges(rootNow) ~= before then
	problem("no step-in when someone is already in reach")
end
blocker:Destroy()
-- movement set applied to a fresh character's Animate script
local mover, moverHum = makeR15("Mover", Vector3.new(40, 3, 0))
moverHum.MaxHealth = 200
moverHum.Health = 200
local animate = Instance.new("LocalScript")
animate.Name = "Animate"
for folderName, names in { idle = { "Animation1", "Animation2" }, walk = { "WalkAnim" }, run = { "RunAnim" }, jump = { "JumpAnim" }, fall = { "FallAnim" }, climb = { "ClimbAnim" } } do
	local f = Instance.new("StringValue")
	f.Name = folderName
	for _, n in names do
		local a = Instance.new("Animation")
		a.Name = n
		a.AnimationId = "rbxassetid://1"
		a.Parent = f
	end
	f.Parent = animate
end
animate.Parent = mover
localPlayer.CharacterAdded:Fire(mover)
task.wait(0.3)
local mv = Config.Animations.Movement
local got = {
	idle1 = animate.idle.Animation1.AnimationId, idle2 = animate.idle.Animation2.AnimationId,
	walk = animate.walk.WalkAnim.AnimationId, run = animate.run.RunAnim.AnimationId,
}
if got.idle1 ~= mv.Idle[1] or got.idle2 ~= mv.Idle[2] then
	problem("idle + look-around clips not applied (" .. tostring(got.idle1) .. ", " .. tostring(got.idle2) .. ")")
end
if got.walk ~= mv.Walk or got.run ~= mv.Run then
	problem("walk / run clips not applied")
end
print(string.format("  idle %s / %s, walk %s, run %s", got.idle1, got.idle2, got.walk, got.run))
localPlayer.CharacterAdded:Fire(myChar)
task.wait(0.2)
mover:Destroy()

print("== finisher prompt (E on a nearly-beaten dummy)")
do
	local root = myChar.HumanoidRootPart
	-- (you aim with the camera: here it always looks down -Z)
	local folderD = workspace:FindFirstChild("Dummies")
	local victim, vHum = makeR15("LowDummy", root.Position + Vector3.new(0, 0, -5)) -- (in your sights)
	vHum.MaxHealth = 500
	vHum.Health = 40
	victim.Parent = folderD
	beat(15)
	local gui = playerGui:FindFirstChild("FinishPrompt")
	if not gui or not gui.Enabled or gui.Adornee ~= victim:FindFirstChild("Head") then
		problem("no FINISH prompt over a dummy at its last sliver of health")
	end
	table.clear(fired)
	actions.QuirkFinish("QuirkFinish", Enum.UserInputState.Begin, {})
	task.wait(0.05)
	local sent = fired[1]
	if not (sent and sent[1] == "UseAbility" and sent[2] == Config.FINISH_INDEX and sent[3] == victim) then
		problem("E didn't ask the server to finish them")
	end
	vHum.Health = 400
	beat(15)
	if gui and gui.Enabled then
		problem("the FINISH prompt should go away once they're healthy")
	end
	-- someone behind you doesn't get a prompt
	vHum.Health = 40
	victim:PivotTo(r.CFrame.new(root.Position + Vector3.new(0, 0, 5)))
	victim.HumanoidRootPart.Position = root.Position + Vector3.new(0, 0, 5)
	beat(15)
	if gui and gui.Enabled then
		problem("no FINISH prompt for someone behind you")
	end
	-- the finished body flies: a wind streak rides along with it
	local torsoPart = victim:FindFirstChild("UpperTorso") or victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")
	VFX.Play("FinisherLaunch", victim, { Velocity = Vector3.new(0, 120, -300) }, false)
	task.wait(0.05)
	if not torsoPart or not torsoPart:FindFirstChildOfClass("Trail") then
		problem("a launched body should leave a wind streak")
	end
	victim:Destroy()
	print("  finisher prompt checked")
end

print("== OVERHAUL's kaiju (client)")
do
	local RSvc = game:GetService("RunService")
	local function frames(n)
		for _ = 1, n do
			signalOf(RSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end
	myChar:SetAttribute("Kaiju", nil)
	VFX.Play("Kaiju", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	VFX.CancelCinematic()
	frames(40)
	myChar:SetAttribute("Kaiju", true) -- the server: it's up
	frames(20)
	local k = VFX.KaijuOf(myChar)
	if not k then
		problem("the kaiju should be built around him")
	else
		if localPlayer.CameraMinZoomDistance < 40 then
			problem("the camera should pull back to take in the kaiju")
		end
		if myChar.Head.LocalTransparencyModifier ~= 1 then
			problem("his own body should hide inside the kaiju")
		end
		-- the default camera resets its own character's LocalTransparencyModifier
		myChar.Head.LocalTransparencyModifier = 0
		frames(1)
		if myChar.Head.LocalTransparencyModifier ~= 1 then
			problem("his body should stay hidden even when the camera un-hides it")
		end
		local count, wedges, mask = 0, 0, false
		for _, d in k.model:GetDescendants() do
			if d:IsA("BasePart") then
				count += 1
				if d:IsA("WedgePart") then
					wedges += 1
				end
				if d.Material == Enum.Material.Metal then
					mask = true -- the gold band of Katsukame's mask
				end
			end
		end
		if count < 250 or wedges < 20 or not mask then
			problem(("the kaiju should be the full construct (parts %d, rock teeth %d, mask %s)"):format(count, wedges, tostring(mask)))
		end
		VFX.Play("Punch", myChar, { Count = 1 }, true)
		task.wait(0.05)
		if not k.slam[1] then
			problem("an M1 should bring the kaiju's right arm down")
		end
		frames(40)
	end
	myChar:SetAttribute("Kaiju", nil) -- the form ends
	frames(10)
	if VFX.KaijuOf(myChar) then
		problem("the kaiju should come apart when the form ends")
	end
	if localPlayer.CameraMinZoomDistance > 1 then
		problem("the camera should come back afterwards")
	end
	task.wait(0.7) -- he pulls himself back together where it stood
	if myChar.Head.LocalTransparencyModifier ~= 0 then
		problem("his body should come back afterwards")
	end
	print("  kaiju checked")
end

print("== every move's effect (every quirk, every form)")
do
	local foe = makeR15("SweepFoe", Vector3.new(0, 3, -12))
	local sweepAim = {
		Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -30), Seed = 7, Origin = Vector3.new(0, 3, 0),
		Target = foe, Targets = { foe }, Alt = true, Duration = 0.6,
	}
	local played = 0
	for _, q in Config.QuirkOrder do
		local quirk = Config.Quirks[q]
		local list = {}
		for _, set in { quirk.Abilities, quirk.Alt and quirk.Alt.Abilities, quirk.Ult and quirk.Ult.Abilities } do
			for _, ability in set or {} do
				table.insert(list, ability.Id)
			end
		end
		for _, extra in { quirk.Special, quirk.Extra, quirk.Alt and quirk.Alt.Extra, quirk.Ult and quirk.Ult.Extra } do
			if extra then
				table.insert(list, extra.Id)
			end
		end
		for _, extra in quirk.Extras or {} do
			table.insert(list, extra.Id)
		end
		for _, id in list do
			VFX.Play(id, myChar, sweepAim, true)
			played += 1
			task.wait(0.05)
		end
		VFX.Play("Dash", myChar, { Dir = Vector3.new(0, 0, -1), Kind = "Front", Quirk = q, Alt = true }, true)
		VFX.Play("Dash", myChar, { Dir = Vector3.new(0, 0, -1), Kind = "Back", Quirk = q, Alt = false }, true)
		-- this quirk's finisher on the foe (as the server broadcasts it)
		VFX.Play("Finisher", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1), Style = q, Time = 0.5 }, false)
		task.wait(0.1)
		VFX.CancelCinematic()
	end
	VFX.Play("Finisher", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1), Style = "Nobody", Time = 0.4 }, false)
	VFX.Play("Disassembled", myChar, { Target = foe }, false)
	VFX.Play("Burn", nil, { Target = foe, Duration = 0.5 }, false)
	print("  played", played, "move effects")
	task.wait(4)
	VFX.CancelCinematic()
end

print("== round 35: Deku's INFINITE 100% (Eri on his back, the storm of fists), the rebuilt kaiju")
do
	local seen = {}
	for _, d in VFX.Folder:GetChildren() do
		seen[d] = true
	end
	local function fresh(name)
		local out = {}
		for _, d in VFX.Folder:GetChildren() do
			if d.Name == name and not seen[d] then
				table.insert(out, d)
			end
		end
		return out
	end
	local function faded(model)
		for _, p in model and model:GetDescendants() or {} do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Parent then
				return false
			end
		end
		return true
	end
	local up = other.HumanoidRootPart.Position + Vector3.new(0, 26, 0)
	-- Eri climbs onto his back as it starts
	play("FistRain", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.05)
	local eri = fresh("EriRide")[1]
	local horn, welded = false, eri ~= nil
	for _, d in eri and eri:GetDescendants() or {} do
		if d:IsA("PointLight") then
			horn = true
		elseif d:IsA("BasePart") and (d.Anchored or d.CanCollide or not d:FindFirstChildOfClass("WeldConstraint")) then
			welded = false
		end
	end
	if not (eri and #eri:GetChildren() >= 12 and horn) then
		problem("INFINITE 100%: Eri rides on his back, her horn glowing (" .. tostring(eri and #eri:GetChildren()) .. " pieces)")
	end
	if not welded then
		problem("...held on to him (welded, no collisions)")
	end
	task.wait(0.2)
	VFX.Play("FistRainCatch", myChar, { Target = other, Air = true, Hits = 14, Interval = 0.07, RiseTime = 0.3, At = up }, false)
	task.wait(0.35)
	local n0 = #fresh("InfiniteFist")
	VFX.Play("FistRainStrike", myChar, { Target = other, Pos = up, Index = 1, Final = false }, false)
	local n1 = #fresh("InfiniteFist") - n0
	if n1 ~= 1 then
		problem("...the first punch: one huge fist slams in (" .. n1 .. ")")
	end
	VFX.Play("FistRainStrike", myChar, { Target = other, Pos = up, Index = 1, Final = false }, false)
	if #fresh("InfiniteFist") - n0 ~= 1 then
		problem("...a hit that arrives twice is drawn once")
	end
	if #fresh("InfiniteBackdrop") ~= 1 then
		problem("...the sky behind them goes magenta")
	end
	for i = 2, 14 do
		VFX.Play("FistRainStrike", myChar, { Target = other, Pos = up, Index = i, Final = false }, false)
		task.wait(0.07)
	end
	VFX.Play("FistRainFinish", myChar, { Target = other, Pos = Vector3.new(0, 0, -6), Air = true, From = up, Time = 0.16 }, false)
	task.wait(1.4)
	if not faded(eri) then
		problem("...once they're down in the street, Eri lets go")
	end
	if not faded(fresh("InfiniteBackdrop")[1]) then
		problem("...and the magenta's gone")
	end
	-- a whiff: she lets go again straight away
	play("FistRain", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.05)
	local eri2 = fresh("EriRide")[2]
	task.wait(0.8)
	if not (eri2 and faded(eri2)) then
		problem("...a whiffed kick: Eri lets go again")
	end

	-- the kaiju, rebuilt to the anime: the maw, the mask's red eyes, eight hands
	VFX.Play("Kaiju", myChar, {}, false)
	task.wait(0.3)
	local kaiju = fresh("Kaiju")[1]
	local parts, eyes, palms, light = 0, 0, 0, false
	for _, d in kaiju and kaiju:GetDescendants() or {} do
		if d:IsA("BasePart") then
			parts += 1
			local c = d.Color
			if d.Material == Enum.Material.Neon and math.floor(c.R * 255 + 0.5) == 255 and math.floor(c.G * 255 + 0.5) == 40 then
				eyes += 1
			end
			if d:FindFirstChildOfClass("SpecialMesh") and math.abs(d.Size.X - d.Size.Z) < 0.01 and math.abs(d.Size.X / d.Size.Y - 3.8 / 1.6) < 0.01 then
				palms += 1
			end
		elseif d:IsA("PointLight") then
			light = true
		end
	end
	if not (kaiju and parts > 450) then
		problem("THE KAIJU: rebuilt, rock plates over every limb (" .. parts .. " parts)")
	end
	if eyes ~= 2 then
		problem("...Katsukame's mask, its two eyes glowing red (" .. eyes .. ")")
	end
	if palms ~= 8 then
		problem("...eight hands, like the anime's (" .. palms .. ")")
	end
	if not light then
		problem("...a red glow down its throat")
	end
	VFX.Play("KaijuEnd", myChar, {}, false)
	task.wait(0.4)
end

print("== round 36: settings, hero ranks, Top Heroes, Fa Jin's tap, the Auto-Cannon's live aim, INFINITE's rain")
local ok36, err36 = pcall(function()
	local serde = require("@lune/serde")
	local seen = {}
	for _, d in VFX.Folder:GetChildren() do
		seen[d] = true
	end
	local function fresh(name)
		local out = {}
		for _, d in VFX.Folder:GetChildren() do
			if d.Name == name and not seen[d] then
				table.insert(out, d)
			end
		end
		return out
	end
	local function sentOf(index)
		local out = {}
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == index then
				table.insert(out, f)
			end
		end
		return out
	end

	-- the rank card
	HUD.SetRank(12, 3)
	local card = hudGui:FindFirstChild("RankCard")
	if not (card and card.Rank.Text == "LICENSED PRE-HERO" and card.Stats.Text:find("KILLS 12") and card.Progress.Fill.Size.X.Scale > 0.05) then
		problem("the rank card: LICENSED PRE-HERO, 12 kills, on the way to the next (" .. tostring(card and card.Rank.Text) .. ")")
	end
	HUD.SetRank(0, 0)
	if not card or card.Rank.Text ~= "STUDENT" then
		problem("...no kills yet: STUDENT")
	end
	-- a rank-up: yours gets the banner, someone else's a line in the feed
	PlayVFX.OnClientEvent:Fire("RankUp", nil, { Player = "Tester", UserId = localPlayer.UserId, Rank = "SEMI-PRO", Index = 4 })
	task.wait(0.1)
	local banner = hudGui:FindFirstChild("RankUp")
	if not (banner and banner.RankName.Text == "SEMI-PRO") then
		problem("your rank-up: a big banner (SEMI-PRO)")
	end
	PlayVFX.OnClientEvent:Fire("RankUp", nil, { Player = "Rival", UserId = 999, Rank = "PRO HERO", Index = 5 })
	task.wait(0.05)
	local line = false
	local feed = hudGui:FindFirstChild("KillFeed")
	for _, row in feed and feed:GetChildren() or {} do
		if row:IsA("TextLabel") and row.Text:find("Rival", 1, true) and row.Text:find("PRO HERO", 1, true) then
			line = true
		end
	end
	if not line then
		problem("someone else's rank-up: a line in the feed")
	end

	-- SETTINGS
	local sbtn = hudGui:FindFirstChild("SettingsButton")
	if sbtn then
		signalOf(sbtn, "MouseButton1Click"):Fire()
	end
	local panel = hudGui:FindFirstChild("Settings")
	if not (panel and panel.Visible) then
		problem("SETTINGS opens the settings panel")
	end
	table.clear(fired)
	local wear = panel and panel:FindFirstChild("WearCosmetics")
	if wear then
		signalOf(wear.Switch, "MouseButton1Click"):Fire()
	end
	local told = false
	for _, f in fired do
		if f[1] == "Settings" and f[2] == "WearCosmetics" and f[3] == false then
			told = true
		end
	end
	if not (told and wear and wear.Switch.Text == "OFF") then
		problem("MY COSMETICS: the switch goes OFF and the server's told (it takes your look off)")
	end
	if wear then
		signalOf(wear.Switch, "MouseButton1Click"):Fire()
	end
	-- SHOW COSMETICS off: someone else's look vanishes on your screen only
	local rival = Instance.new("Player")
	rival.Name = "Rival"
	rival.Parent = Players
	local rchar = Instance.new("Model")
	rchar.Name = "Rival"
	local rgear = Instance.new("Model")
	rgear.Name = "QuirkGear"
	rgear.Parent = rchar
	local rcos = Instance.new("Model")
	rcos.Name = "Cosmetics"
	rcos.Parent = rgear
	local hat = Instance.new("Part")
	hat.Name = "Hat"
	hat.Parent = rcos
	local engine = Instance.new("Part")
	engine.Name = "Pipe"
	engine.Parent = rgear
	hat.LocalTransparencyModifier = 0
	engine.LocalTransparencyModifier = 0
	rchar.Parent = workspace
	rival.Character = rchar
	setAttr(localPlayer, "ShowCosmetics", false)
	task.wait(0.6)
	if not (panel and panel.ShowCosmetics.Switch.Text == "OFF") then
		problem("the saved setting shows on its switch")
	end
	if hat.LocalTransparencyModifier ~= 1 or engine.LocalTransparencyModifier ~= 0 then
		problem("SHOW COSMETICS off: other players' looks vanish on your screen (the rest of their gear stays)")
	end
	setAttr(localPlayer, "ShowCosmetics", true)
	task.wait(0.1)
	if hat.LocalTransparencyModifier ~= 0 then
		problem("...and come back when it's on")
	end
	rival.Parent = nil
	rchar:Destroy()
	-- the music switch is in there too (and matches the HUD's)
	local music = panel and panel:FindFirstChild("Music")
	if music then
		signalOf(music.Switch, "MouseButton1Click"):Fire()
	end
	local mbtn = hudGui:FindFirstChild("MusicToggle")
	if not (music and music.Switch.Text == "OFF" and mbtn and mbtn.Text:find("OFF")) then
		problem("ULT MUSIC in the settings turns the music off (and the HUD switch says so)")
	end
	if music then
		signalOf(music.Switch, "MouseButton1Click"):Fire()
	end
	if panel then
		signalOf(panel.Close, "MouseButton1Click"):Fire()
	end
	if panel and panel.Visible then
		problem("X closes the settings")
	end

	-- TOP HEROES (L)
	r.implementMethod("HttpService", "JSONDecode", function(_, s)
		return serde.decode("json", s)
	end)
	local tv = Instance.new("StringValue")
	tv.Name = "TopHeroes"
	tv.Value = serde.encode("json", { { UserId = 7, Name = "Deku", Kills = 160 }, { UserId = localPlayer.UserId, Name = "Tester", Kills = 12 } })
	tv.Parent = ReplicatedStorage
	HUD.SetRank(12, 0)
	if actions.QuirkBoard then
		actions.QuirkBoard("QuirkBoard", Enum.UserInputState.Begin, {})
	end
	local board = hudGui:FindFirstChild("TopHeroes")
	if not (board and board.Visible) then
		problem("L opens TOP HEROES")
	elseif not (board.Row1.PlayerName.Text == "Deku" and board.Row1.Kills.Text == "160" and board.Row1.Rank.Text == "Pro Hero") then
		problem("...#1 Deku, 160 kills, Pro Hero (" .. board.Row1.PlayerName.Text .. ", " .. board.Row1.Kills.Text .. ", " .. board.Row1.Rank.Text .. ")")
	elseif board.Row3.PlayerName.Text ~= "-" then
		problem("...empty places left blank")
	elseif not (board.You.Text:find("LICENSED PRE-HERO", 1, true) and board.You.Text:find("in 18", 1, true)) then
		problem("...your own line: your rank and how far to the next (" .. board.You.Text .. ")")
	end
	if actions.QuirkBoard then
		actions.QuirkBoard("QuirkBoard", Enum.UserInputState.Begin, {})
	end
	if board and board.Visible then
		problem("L again closes it")
	end
	HUD.SetRank(0, 0)
	tv:Destroy()

	-- FA JIN: tap 4 to wind up, tap 4 again to let go
	localPlayer:SetAttribute("Quirk", "FullCowl")
	myChar:SetAttribute("Quirk", "FullCowl")
	localPlayer:SetAttribute("QuirkPick", 4)
	localPlayer:SetAttribute("NoCooldowns", true)
	task.wait(0.3)
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	setAttr(myChar, "Holding", "FaJinSmash")
	local started = #sentOf(Config.EXTRA_INDEX) == 1
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	task.wait(0.9)
	if not started or #sentOf(Config.RELEASE_INDEX) > 0 then
		problem("FA JIN: 4 starts the wind-up, and letting go of the key doesn't fire it")
	end
	if #fresh("FaJinSwirl") + #VFX.Folder:GetChildren() == 0 then
		problem("...the wind-up draws something")
	end
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	setAttr(myChar, "Holding", nil)
	if #sentOf(Config.RELEASE_INDEX) ~= 1 or #sentOf(Config.EXTRA_INDEX) ~= 0 then
		problem("...4 again lets it go (and isn't a new Fa Jin)")
	end
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	task.wait(1.2)

	-- AP SHOT: AUTO-CANNON streams your aim while it fires
	localPlayer:SetAttribute("Quirk", "Explosion")
	myChar:SetAttribute("Quirk", "Explosion")
	setAttr(localPlayer, "UltActive", true)
	task.wait(0.3)
	table.clear(fired)
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, {})
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.End, {})
	task.wait(0.7)
	local aims = 0
	for _, f in sentOf(Config.AIM_INDEX) do
		if typeof(f[3]) == "Vector3" then
			aims += 1
		end
	end
	if #sentOf(1) ~= 1 or aims < 5 then
		problem("AUTO-CANNON: where you aim streams to the server while it fires (" .. aims .. " updates)")
	end
	task.wait(1)
	table.clear(fired)
	task.wait(0.3)
	if #sentOf(Config.AIM_INDEX) > 0 then
		problem("...and stops once it's done")
	end
	setAttr(localPlayer, "UltActive", false)
	VFX.Play("AutoCannonShot", other, { Dir = Vector3.new(1, 0, 0), Index = 1 }, false)
	localPlayer:SetAttribute("NoCooldowns", nil)
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
	task.wait(0.5)

	-- INFINITE 100%: the camera goes up with them, the punches speed up, the
	-- fists rain down, and it all goes off
	local up = other.HumanoidRootPart.Position + Vector3.new(0, 26, 0)
	local cam = workspace.CurrentCamera
	play("FistRain", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.2)
	-- (Barrage: this loop's own pace - the harness runs slower than the real storm)
	VFX.Play("FistRainCatch", myChar, { Target = other, Air = true, Hits = 16, RiseTime = 0.3, Barrage = 1.6, RainTime = 0.6, At = up, Pos = Vector3.new(0, 0, -6) }, false)
	task.wait(0.05)
	if not VFX.InOwnCinematic() then
		problem("INFINITE 100%: your camera goes with them (a cutscene)")
	end
	local y0 = cam.CFrame.Position.Y
	task.wait(0.45)
	if cam.CFrame.Position.Y < y0 + 10 then
		problem(string.format("...panning up into the sky after them (%.1f -> %.1f)", y0, cam.CFrame.Position.Y))
	end
	local early, late = 0, 0
	for i = 1, 16 do
		local counted = i == 1 or i == 12
		local n0 = counted and #fresh("InfiniteFist") or 0
		VFX.Play("FistRainStrike", myChar, { Target = other, Pos = up, Index = i, Final = false }, false)
		local n = counted and #fresh("InfiniteFist") - n0 or 0
		if i == 1 then
			early = n
		elseif i == 12 then
			late = n
		end
		task.wait(0.05)
	end
	if not (early == 1 and late == 4) then
		problem("...faster and faster: one fist at first, four at a time later on (" .. early .. ", " .. late .. ")")
	end
	local f0 = #fresh("InfiniteFist")
	VFX.Play("FistRainFall", myChar, { Target = other, From = up, Pos = Vector3.new(0, 0, -6), Time = 0.6, Hits = 4 }, false)
	task.wait(0.35)
	local rained = #fresh("InfiniteFist") - f0
	if rained < 10 then
		problem("...then the fists come raining down (" .. rained .. ")")
	end
	if #fresh("InfiniteBackdrop") > 0 and fresh("InfiniteBackdrop")[1].Parent and fresh("InfiniteBackdrop")[1].Transparency < 1 then
		problem("...(the magenta sky's gone for the rain)")
	end
	task.wait(0.35)
	VFX.Play("FistRainFinish", myChar, { Target = other, Pos = Vector3.new(0, 0, -6), Air = true, From = up }, false)
	task.wait(0.15)
	local fireball = false
	for _, d in VFX.Folder:GetChildren() do
		if not seen[d] and d:IsA("BasePart") and d.Size.X >= 30 and d:FindFirstChildOfClass("SpecialMesh") then
			fireball = true
		end
	end
	if not fireball then
		problem("...and it all goes off: a huge blast")
	end
	task.wait(1.3)
	if VFX.InOwnCinematic() or cam.CameraType == Enum.CameraType.Scriptable then
		problem("...then the camera comes back to you")
	end
	VFX.Play("FistRainCancel", myChar, {}, false)
end)
if not ok36 then
	problem("round 36 client scenario crashed: " .. tostring(err36))
end

print("== round 37: Kamui Woods, the swings, the controller's emote menu, UNO at Tony's")
local ok37, err37 = pcall(function()
	local CFrame, Color3 = r.CFrame, r.Color3
	-- (the engine's frames, while this runs: swings move on Heartbeat)
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	-- (nothing open: the character menu, the shop, a vendor)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local seen = {}
	for _, d in VFX.Folder:GetChildren() do
		seen[d] = true
	end
	local function sentOf(index)
		local out = {}
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == index then
				table.insert(out, f)
			end
		end
		return out
	end
	local function newParts()
		local n = 0
		for _, d in VFX.Folder:GetDescendants() do
			if d:IsA("BasePart") and not seen[d] then
				n += 1
			end
		end
		return n
	end
	local root = myChar.HumanoidRootPart
	-- a block of flats in front of him (he and the camera face -Z), 60 high
	local function building(zNear)
		return function(_, origin, dir)
			if dir.Z >= 0 then
				return nil
			end
			local t = (zNear - origin.Z) / dir.Z
			if t < 0 or t > 1 then
				return nil
			end
			local p = origin + dir * t
			if p.Y < 0 or p.Y > 60 or math.abs(p.X - root.Position.X) > 30 then
				return nil
			end
			return { Position = p, Normal = Vector3.new(0, 0, 1), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Concrete }
		end
	end
	root.CFrame = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	root.AssemblyLinearVelocity = Vector3.zero

	-- where a swing can go
	setRaycast(nil)
	if VFX.SwingAnchor(myChar, Vector3.new(0, 0.5, -1), 80) then
		problem("SWING: nothing around, nothing to swing from")
	end
	setRaycast(building(-30))
	local anchor = VFX.SwingAnchor(myChar, Vector3.new(0, 0.5, -1).Unit, 80)
	if not (anchor and anchor.Y > root.Position.Y + 3 and math.abs(anchor.Z + 30) < 1) then
		problem("...a building ahead: a point high up on it (" .. tostring(anchor) .. ")")
	end
	setRaycast(function(_, origin, dir)
		-- (a low wall: only as tall as him)
		local hit = building(-12)(nil, origin, dir)
		if hit and hit.Position.Y < 4 then
			return hit
		end
		return nil
	end)
	if VFX.SwingAnchor(myChar, Vector3.new(0, 0, -1), 80) then
		problem("...a wall no taller than him isn't something to swing from")
	end

	-- KAMUI's R
	localPlayer:SetAttribute("Quirk", "Arbor")
	myChar:SetAttribute("Quirk", "Arbor")
	localPlayer:SetAttribute("NoCooldowns", true)
	task.wait(0.3)
	setRaycast(nil)
	table.clear(fired)
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	task.wait(0.1)
	if #sentOf(Config.SPECIAL_INDEX) ~= 0 or VFX.Swinging(myChar) then
		problem("KAMUI R: nothing tall enough about - it doesn't go (and costs nothing)")
	end
	setRaycast(building(-30))
	table.clear(fired)
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	task.wait()
	local swinging = VFX.Swinging(myChar) and root:FindFirstChild("SwingAttachment") ~= nil
	local lv = root:FindFirstChildOfClass("LinearVelocity")
	task.wait(1 / 30)
	local speed = lv and lv.VectorVelocity.Magnitude or 0
	local sent = sentOf(Config.SPECIAL_INDEX)[1]
	local swung = sent and typeof(sent[4]) == "Vector3" and sent[4].Y > 5 and math.abs(sent[4].Z + 30) < 1
	if not swung then
		problem("KAMUI R at a building: the server's told where the branch caught")
	end
	if not swinging then
		problem("...and he swings off it")
	end
	if speed < 5 then
		problem("...moving along the arc (" .. speed .. ")")
	end
	local branch = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("BasePart") and not seen[d] and d.Material == Enum.Material.Wood then
			branch += 1
		end
	end
	if branch < 6 then
		problem("...on a blocky wooden branch out of his arm (" .. branch .. " pieces)")
	end
	task.wait(1.6)
	if VFX.Swinging(myChar) or root:FindFirstChild("SwingAttachment") then
		problem("...then lets go")
	elseif root.AssemblyLinearVelocity.Magnitude < 20 then
		problem("...flying on off the end of it (" .. string.format("%.1f", root.AssemblyLinearVelocity.Magnitude) .. ")")
	end
	root.AssemblyLinearVelocity = Vector3.zero
	-- the server says no: it stops
	root.CFrame = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	task.wait(0.05)
	PlayVFX.OnClientEvent:Fire("SwingDenied", myChar, {})
	task.wait(0.1)
	if VFX.Swinging(myChar) then
		problem("...and if the server finds nothing there, the swing's called off")
	end
	-- a move lets go of the swing
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	task.wait(0.1)
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.Begin, {})
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.End, {})
	task.wait(0.1)
	if VFX.Swinging(myChar) then
		problem("...a move mid-swing lets go of it")
	end
	task.wait(1)
	setRaycast(nil)

	-- all of his effects, as others see them
	local n0 = newParts()
	local fwd = { Dir = Vector3.new(0, 0, 1), Pos = Vector3.new(0, 3, 25), Seed = 7, Origin = Vector3.new(0, 3, 0) }
	for _, id in { "ChainPrison", "TimberSlingshot", "RootBreaker", "TreeHammer", "ThousandBranch", "TimberTorrent", "SequoiaSpear", "GreatSlingshot" } do
		VFX.Play(id, other, fwd, false)
	end
	VFX.Play("BranchSwing", other, { Pos = Vector3.new(0, 30, 20) }, false)
	VFX.Play("ChainPrisonCatch", other, { Target = myChar, Dir = Vector3.new(0, 0, 1), Reach = 25, Duration = 1.6 }, false)
	VFX.Play("ChainPrisonCatch", other, { Dir = Vector3.new(0, 0, 1), Reach = 50 }, false)
	task.wait(0.3)
	local o = other.HumanoidRootPart.Position
	VFX.Play("TimberToss", other, { Target = myChar, From = o, Apex = o + Vector3.new(0, 24, 4), Anchor = o + Vector3.new(0, 20, -16), Toss = 0.4, Shoot = 0.12, Pull = 0.26, Fling = 0.24, Drop = 0.18 }, false)
	task.wait(0.8)
	VFX.Play("TimberDive", other, { Target = myChar, From = o + Vector3.new(0, 30, 0), Pos = o, Time = 0.18 }, false)
	task.wait(0.2)
	VFX.Play("TimberSlam", other, { Target = myChar, Pos = o }, false)
	VFX.Play("TimberToss", other, { Target = myChar, From = o, Apex = o + Vector3.new(0, 24, 4), Anchor = o + Vector3.new(4, 26, 0), Pillar = true, Big = true, Toss = 0.4, Shoot = 0.12, Pull = 0.26, Fling = 0.24, Drop = 0.18 }, false)
	task.wait(0.3)
	VFX.Play("TimberCancel", other, { Target = myChar }, false)
	VFX.Play("TimberWhiff", other, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("ThousandBranchCatch", other, { Targets = { myChar }, Duration = 0.5, Center = o }, false)
	task.wait(0.6)
	VFX.Play("ThousandBranchCrush", other, { Targets = { myChar }, Center = o }, false)
	VFX.Play("Punch", other, { Count = 2, Quirk = "Arbor" }, false)
	VFX.Play("Dash", other, { Dir = Vector3.new(0, 0, -1), Kind = "Front", Quirk = "Arbor" }, false)
	task.wait(0.2)
	if newParts() - n0 < 60 then
		problem("KAMUI's moves: branches, cages, stakes, trunks, logs (" .. newParts() - n0 .. " pieces)")
	end
	-- (all the cages come off and the timber goes)
	task.wait(2.5)
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("BasePart") and not seen[d] and d.Material == Enum.Material.Wood and d.Transparency < 0.5 and d.Parent then -- (fading ones: Debris takes them)
			problem("...and his timber all goes away afterwards (" .. d:GetFullName() .. " " .. tostring(d.Size) .. " at " .. tostring(d.Position) .. " " .. tostring(d.Color) .. " left)")
			break
		end
	end

	-- SUNEATER's tentacle swing
	localPlayer:SetAttribute("Quirk", "Manifest")
	myChar:SetAttribute("Quirk", "Manifest")
	root.CFrame = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	PlayVFX.OnClientEvent:Fire("TakoSwing", myChar, { Anchor = Vector3.new(0, 26, -24), Time = 1 })
	task.wait()
	if not VFX.Swinging(myChar) then
		problem("TAKO SNATCH caught a building: he swings off the tentacle")
	end
	task.wait(1.3)
	if VFX.Swinging(myChar) then
		problem("...and lets go at the end")
	end
	PlayVFX.OnClientEvent:Fire("TakoSwing", other, { Anchor = Vector3.new(0, 26, -24), Time = 1 })
	task.wait(0.1)
	if VFX.Swinging(other) then
		problem("...(someone else's swing only draws the tentacle: their own screen moves them)")
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
	localPlayer:SetAttribute("NoCooldowns", nil)
	task.wait(0.3)

	-- EMOTES on a controller: a menu of cards
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	task.wait(0.05)
	local pad = { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonR3 }
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, pad)
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.End, pad)
	local menu = hudGui:FindFirstChild("EmoteMenu", true)
	local wheel = hudGui:FindFirstChild("EmoteWheel", true)
	if not (menu and menu.Visible) or (wheel and wheel.Visible) then
		problem("EMOTES on a controller: the emote button opens a menu of cards (not the wheel)")
	end
	local cards = 0
	for _, c in menu and menu:GetDescendants() or {} do
		if c:IsA("GuiButton") and c.Name:sub(1, 10) == "EmoteCard_" then
			cards += 1
		end
	end
	if cards ~= Config.EmoteSlots then
		problem("...one card per slot on the wheel (" .. cards .. "/" .. Config.EmoteSlots .. ")")
	end
	local gs = game:GetService("GuiService")
	local okSel, selected = pcall(function()
		return gs.SelectedObject
	end)
	if okSel and not (selected and selected.Name == "EmoteCard_" .. WHEEL58[1]) then
		problem("...the pad's selection starts on the first card (" .. tostring(selected) .. ")")
	end
	if not (actions.QuirkEmoteMenuBack) then
		problem("...and B backs out")
	end
	table.clear(fired)
	local third = menu and menu:FindFirstChild("EmoteCard_" .. WHEEL58[3], true)
	if third then
		signalOf(third, "Activated"):Fire()
	end
	task.wait(0.05)
	local picked
	for _, f in fired do
		if f[2] == Config.EMOTE_INDEX then
			picked = f[3]
		end
	end
	if picked ~= WHEEL58[3] or menu.Visible then
		problem("...A on a card plays it and the menu closes (" .. tostring(picked) .. ")")
	end
	task.wait(0.6)
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, pad)
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.End, pad)
	if actions.QuirkEmoteMenuBack then
		actions.QuirkEmoteMenuBack("QuirkEmoteMenuBack", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonB })
	end
	if menu.Visible then
		problem("...B closes it without playing anything")
	end
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	task.wait(0.05)

	-- UNO
	local Uno = remotes:FindFirstChild("Uno")
	local panel = hudGui:FindFirstChild("Uno", true)
	if not (Uno and panel) then
		problem("UNO: the table's panel is built")
		return
	end
	local base = {
		Table = 1, Seated = { "Tester", "Rival" }, Deck = 80, TurnTime = 20,
		Players = {
			{ Name = "Tester", UserId = localPlayer.UserId, Count = 5 },
			{ Name = "Rival", UserId = 9, Count = 1, Exposed = true },
		},
	}
	local function state(extra)
		local s = table.clone(base)
		for k, v in extra do
			s[k] = v
		end
		return s
	end
	Uno.OnClientEvent:Fire("State", state({ Phase = "Lobby", StartIn = 8, Players = nil }))
	task.wait(0.05)
	local start = panel:FindFirstChild("StartButton", true)
	if not (panel.Visible and start and start.Visible and panel:FindFirstChild("Lobby", true).Visible) then
		problem("UNO: sat down with a friend - the panel's up, DEAL! and the count to the deal")
	end
	table.clear(fired)
	if start then
		signalOf(start, "Activated"):Fire()
	end
	local dealt = false
	for _, f in fired do
		if f[1] == "Uno" and f[2] == "Start" then
			dealt = true
		end
	end
	if not dealt then
		problem("...DEAL! starts the game")
	end
	Uno.OnClientEvent:Fire("State", state({
		Phase = "Game", Hand = { "R5", "G7", "WF", "Y3", "B1" }, Top = "R3", Color = "R", Dir = 1,
		MyTurn = true, TurnEnds = workspace:GetServerTimeNow() + 12, CanCatch = true,
	}))
	task.wait(0.05)
	local hand = panel:FindFirstChild("Hand", true)
	local c1 = hand and hand:FindFirstChild("Card1", true)
	local c2 = hand and hand:FindFirstChild("Card2", true)
	local c3 = hand and hand:FindFirstChild("Card3", true)
	if not (c1 and c2 and c3 and hand:FindFirstChild("Card5", true)) then
		problem("...your 5 cards in your hand")
	elseif not (c1.Selectable and not c2.Selectable and c3.Selectable) then
		problem("...the ones you can play stand out (the red 5 and the wild, not the green 7)")
	end
	local top = panel:FindFirstChild("Top", true)
	if not top then
		problem("...the pile shows the top card")
	end
	local catch = panel:FindFirstChild("CatchButton", true)
	if not (catch and catch.Visible) then
		problem("...someone's on one card without calling it: CATCH! is up")
	end
	if not panel:FindFirstChild("Player2", true) then
		problem("...everyone at the table, with how many cards they hold")
	end
	table.clear(fired)
	signalOf(c2, "Activated"):Fire()
	signalOf(c1, "Activated"):Fire()
	local plays = {}
	for _, f in fired do
		if f[1] == "Uno" and f[2] == "Play" then
			table.insert(plays, f[3])
		end
	end
	if not (#plays == 1 and plays[1] == 1) then
		problem("...tap a card you can play: it's played (and one you can't does nothing)")
	end
	table.clear(fired)
	signalOf(c3, "Activated"):Fire()
	local picker = panel:FindFirstChild("ColorPicker", true)
	if not (picker and picker.Visible) or #fired > 0 then
		problem("...a wild: first pick a colour")
	end
	local blue = picker and picker:FindFirstChild("PickB", true)
	if blue then
		signalOf(blue, "Activated"):Fire()
	end
	local wild
	for _, f in fired do
		if f[1] == "Uno" and f[2] == "Play" then
			wild = { f[3], f[4] }
		end
	end
	if not (wild and wild[1] == 3 and wild[2] == "B") or picker.Visible then
		problem("...blue: the wild's played as blue")
	end
	table.clear(fired)
	local deck = panel:FindFirstChild("Deck", true)
	if deck then
		signalOf(deck, "Activated"):Fire()
	end
	local drew = false
	for _, f in fired do
		if f[1] == "Uno" and f[2] == "Draw" then
			drew = true
		end
	end
	if not drew then
		problem("...tap the deck to draw")
	end
	-- a controller: on your turn the selection jumps to a card you can play
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	task.wait(0.05)
	Uno.OnClientEvent:Fire("State", state({
		Phase = "Game", Hand = { "G7", "R5" }, Top = "R3", Color = "R", Dir = -1, MyTurn = true, CanUno = true,
	}))
	task.wait(0.05)
	local padRing = playerGui:FindFirstChild("PadCursor") and playerGui.PadCursor:FindFirstChild("Cursor")
	local before = padRing and padRing.Position
	Uno.OnClientEvent:Fire("State", state({
		Phase = "Game", Hand = { "G7", "R5" }, Top = "R3", Color = "R", Dir = -1, MyTurn = true, CanUno = true, Deck = 59,
	}))
	task.wait(0.1)
	if not (padRing and padRing.Position == before) then
		problem("...on a controller the table updating doesn't drag your cursor about (" .. tostring(before) .. " -> " .. tostring(padRing and padRing.Position) .. ")")
	end
	local unoBtn = panel:FindFirstChild("UnoButton", true)
	if not (unoBtn and unoBtn.Visible) then
		problem("...two cards and it's your go: UNO! is up to call")
	end
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	Uno.OnClientEvent:Fire("Toast", "Rival played a RED 7", Color3.fromRGB(226, 52, 52))
	Uno.OnClientEvent:Fire("End", { Winner = "Tester", You = true })
	task.wait(0.4)
	if not panel:FindFirstChild("UnoWin", true) then
		problem("...going out: YOU WIN!")
	end
	Uno.OnClientEvent:Fire("State", state({ Phase = "Lobby", Players = nil }))
	task.wait(0.05)
	if hand:FindFirstChild("Card1", true) then
		problem("...back to the lobby: the hand's cleared")
	end
	-- stood up
	Uno.OnClientEvent:Fire("Closed")
	task.wait(0.05)
	if panel.Visible then
		problem("...stand up: the panel's gone")
	end
	task.wait(2.5)
	ticking = false
end)
if not ok37 then
	problem("round 37 client scenario crashed: " .. tostring(err37))
end
setRaycast(nil)
print("== round 38: swinging in a straight line (Spider-Man style), easier to chain")
local ok38, err38 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local cam = workspace.CurrentCamera
	-- (Roblox's lookAt: Lune's flips the frame when it looks down -Z)
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	local function reset()
		VFX.SwingRelease(myChar)
		task.wait(0.05)
		root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
		root.AssemblyLinearVelocity = Vector3.zero
		cam.CFrame = lookAt(Vector3.new(0, 8, 12), Vector3.new(0, 6, -20))
	end
	-- a block of flats along the right-hand side of the street (x 15..40)
	local function sideBuilding(_, origin, dir)
		if dir.X <= 0 then
			return nil
		end
		local t = (15 - origin.X) / dir.X
		if t < 0 or t > 1 then
			return nil
		end
		local p = origin + dir * t
		if p.Y < 0 or p.Y > 60 or p.Z < -150 or p.Z > 20 then
			return nil
		end
		return { Position = p, Normal = Vector3.new(-1, 0, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Concrete }
	end
	local function horiz(v)
		return Vector3.new(v.X, 0, v.Z)
	end

	-- the search finds the building beside the street
	reset()
	setRaycast(sideBuilding)
	local anchor = VFX.SwingAnchor(myChar, Vector3.new(0, 0.3, -1).Unit, 110)
	if not (anchor and anchor.X > 14 and anchor.X < 15.5 and anchor.Z < -5 and anchor.Y > 10) then
		problem("SWING: looking down the street, the search finds the building beside it, up ahead (" .. tostring(anchor) .. ")")
	end

	-- off a building to the side, he still goes straight down the street
	reset()
	local st = VFX.Swing(myChar, Vector3.new(14.7, 40, -40), { Time = 1.3 })
	task.wait(3 / 60)
	local lv = root:FindFirstChildOfClass("LinearVelocity")
	local v = lv and horiz(lv.VectorVelocity) or Vector3.zero
	if not (st and st.Dir and st.Dir.Z < -0.99) then
		problem("...swinging off a building beside the street: his line is straight on down it (" .. tostring(st and st.Dir) .. ")")
	elseif not (v.Magnitude > 5 and math.abs(v.X) < 0.1 * v.Magnitude and v.Z < 0) then
		problem("...and he moves along it, not sideways at the building (" .. tostring(v) .. ")")
	end
	task.wait(1.6)
	local out = root.AssemblyLinearVelocity
	if VFX.Swinging(myChar) or not (out.Z < -30 and math.abs(out.X) < 0.15 * math.abs(out.Z) and out.Y > 0) then
		problem("...and lets go flying on straight ahead, and up (" .. tostring(out) .. ")")
	end

	-- a swing out of a swing: his momentum sets the line, and carries through
	-- (the same geometry both times, one standing, one flying along)
	setRaycast(nil)
	reset()
	st = VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3 })
	local standing = st and st.T
	task.wait(1.6)
	reset()
	root.AssemblyLinearVelocity = Vector3.new(110, 0, 0)
	st = VFX.Swing(myChar, Vector3.new(40, 40, 0), { Time = 1.3 })
	if not (st and st.Dir and st.Dir.X > 0.99) then
		problem("...already flying along: the next swing keeps him on that line, whatever the camera says (" .. tostring(st and st.Dir) .. ")")
	end
	if not (standing and st and st.T and st.T < standing * 0.85) then
		problem("...and faster: momentum carries into the next swing (" .. tostring(standing) .. "s standing, " .. tostring(st and st.T) .. "s flying)")
	end
	task.wait(1.6)
	out = root.AssemblyLinearVelocity
	if not (out.X > 70) then
		problem("...and he lets go faster too (" .. tostring(out) .. ")")
	end
	setRaycast(sideBuilding)

	-- holding a direction bends the next swing that way (a little)
	reset()
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	local okMove = pcall(function()
		hum.MoveDirection = Vector3.new(1, 0, 0)
	end)
	if okMove and hum.MoveDirection.X > 0.9 then
		st = VFX.Swing(myChar, Vector3.new(14.7, 40, -40), { Time = 1.3 })
		local turned = st and math.deg(math.acos(math.clamp(st.Dir:Dot(Vector3.new(0, 0, -1)), -1, 1))) or 0
		if not (turned > 35 and turned < 45) then
			problem("...holding right turns the swing 40 degrees that way, not all the way (" .. string.format("%.1f", turned) .. ")")
		end
		pcall(function()
			hum.MoveDirection = Vector3.zero
		end)
		task.wait(1.6)
	end

	-- a wall across his way: he doesn't splat into it, he glances up it
	reset()
	setRaycast(function(_, origin, dir)
		if dir.Z >= 0 then
			return nil
		end
		local t = (-4 - origin.Z) / dir.Z
		if t < 0 or t > 1 then
			return nil
		end
		local p = origin + dir * t
		if p.Y < 0 or p.Y > 60 then
			return nil
		end
		return { Position = p, Normal = Vector3.new(0, 0, 1), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Concrete }
	end)
	VFX.Swing(myChar, Vector3.new(0, 40, -3.7), { Time = 1.3 })
	task.wait(0.2)
	out = root.AssemblyLinearVelocity
	if VFX.Swinging(myChar) or not (out.Z >= 0 and out.Y > 15) then
		problem("...a wall across his way: he glances off it and on up it, not into it (" .. tostring(out) .. ")")
	end

	-- KAMUI's R chains: half a second between swings
	reset()
	setRaycast(sideBuilding)
	localPlayer:SetAttribute("Quirk", "Arbor")
	myChar:SetAttribute("Quirk", "Arbor")
	task.wait(0.3)
	table.clear(fired)
	local function pressR()
		actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
		actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	end
	pressR()
	task.wait(0.55)
	pressR()
	local n = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.SPECIAL_INDEX then
			n += 1
		end
	end
	if n ~= 1 then
		problem("KAMUI R (round 75): not again half a second later - 2s between swings (" .. n .. " swings)")
	end
	task.wait(Config.Quirks.Arbor.Special.Cooldown - 0.4)
	pressR()
	n = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.SPECIAL_INDEX then
			n += 1
		end
	end
	if n ~= 2 then
		problem("KAMUI R (round 75): ...again once it's back (" .. n .. " swings)")
	end
	task.wait(1.6)
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
	reset()
	setRaycast(nil)
	ticking = false
	task.wait(0.3)
end)
if not ok38 then
	problem("round 38 client scenario crashed: " .. tostring(err38))
end
setRaycast(nil)
print("== round 39: Root Breaker from his arms, the Tree Hammer, Fa Jin's red veins, the controller cursor")
local ok39, err39 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	local seen = {}
	for _, d in VFX.Folder:GetDescendants() do
		seen[d] = true
	end
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and d:IsA("BasePart") and d.Transparency < 0.5 and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function wood(d)
		return d.Material == Enum.Material.Wood
	end
	local FWD = Vector3.new(0, 0, -1)

	-- ROOT BREAKER: out of his arms, into the street, weaving along it
	VFX.Play("RootBreaker", myChar, { Dir = FWD, Pos = Vector3.new(0, 3, -40) }, true)
	task.wait(0.62)
	local parts = fresh(wood)
	local above, below, far = 0, 0, 0
	for _, p in parts do
		local y = p.CFrame.Position.Y
		if y > 3.8 then
			above += 1
		elseif y < 2.6 then
			below += 1
		end
		if p.CFrame.Position.Z < -30 then
			far += 1
		end
	end
	if #parts < 30 then
		problem("ROOT BREAKER: two roots of blocky wood run down the street (" .. #parts .. " pieces)")
	elseif not (above >= 6 and below >= 4) then
		problem("...weaving up out of the street and back into it (" .. above .. " up, " .. below .. " down)")
	elseif far < 3 then
		problem("...all the way down it (" .. far .. " pieces past 30 studs)")
	end
	local nearHands = 0
	for _, p in parts do
		if (p.CFrame.Position - root.Position).Magnitude < 4 then
			nearHands += 1
		end
	end
	if nearHands < 3 then
		problem("...and it comes out of his arms (" .. nearHands .. " pieces at his hands)")
	end
	task.wait(1.6)
	if #fresh(wood) > 0 then
		problem("...then sinks back into the street")
	end
	for _, d in VFX.Folder:GetDescendants() do
		seen[d] = true
	end

	-- GREAT TREE HAMMER: the mallet from the drawing (on a street at y = 0)
	setRaycast(function(_, origin, dir)
		if dir.Y >= 0 or origin.Y + dir.Y > 0 then
			return nil
		end
		local t = origin.Y / -dir.Y
		local p = origin + dir * t
		return { Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.new(0, 1, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Asphalt }
	end)
	VFX.Play("TreeHammer", myChar, { Dir = FWD, Pos = Vector3.new(0, 3, -16) }, true)
	task.wait(0.2)
	local head, rings = nil, 0
	for _, p in fresh(wood) do
		if p.Size.Y > 4 and math.abs(p.Size.Y - p.Size.Z) < 0.01 and p.Size.X > p.Size.Y then
			head = p
		elseif p.Size.X < 0.1 and p.Size.Y > 0.2 and math.abs(p.Size.Y - p.Size.Z) < 0.01 then
			rings += 1
		end
	end
	if not head then
		problem("GREAT TREE HAMMER: a big blocky log for a head")
	elseif rings ~= 14 then
		problem("...with the growth rings in squares on both ends (" .. rings .. " ring plates)")
	elseif head.CFrame.Position.Y < root.Position.Y + 6 then
		problem("...raised up over his head first (" .. string.format("%.1f", head.CFrame.Position.Y) .. ")")
	end
	task.wait(0.3)
	if head then
		local p = head.CFrame.Position
		local lowest = p.Y - head.Size.Y / 2
		if not (p.Z < -10 and math.abs(lowest - 0) < 1.2) then
			problem("...then down in front of him, the head resting on the street (" .. tostring(p) .. ")")
		end
		local across = head.CFrame.RightVector
		if math.abs(across.X) < 0.9 then
			problem("...lying across his swing, rings out to the sides (" .. tostring(across) .. ")")
		end
	end
	task.wait(1)
	setRaycast(nil)
	for _, d in VFX.Folder:GetDescendants() do
		seen[d] = true
	end

	-- FA JIN: the red veins of One For All creep up his arm as it charges
	local function red(d)
		return d.Name == "Vein" and d.Color.R > 0.9 and d.Color.G < 0.4
	end
	local arm = myChar:FindFirstChild("RightUpperArm")
	local hand = myChar:FindFirstChild("RightHand")
	local function onArm(list)
		local n, top = 0, 0
		for _, p in list do
			for _, limbPart in { arm, myChar:FindFirstChild("RightLowerArm"), hand } do
				if limbPart then
					local l = limbPart.CFrame:PointToObjectSpace(p.CFrame.Position)
					if math.abs(l.X) < limbPart.Size.X / 2 + 0.15 and math.abs(l.Z) < limbPart.Size.Z / 2 + 0.15 and math.abs(l.Y) < limbPart.Size.Y / 2 + 0.2 then
						n += 1
						if limbPart == arm then
							top += 1
						end
						break
					end
				end
			end
		end
		return n, top
	end
	VFX.Play("FaJinSmash", myChar, { Dir = FWD }, true)
	task.wait(0.5)
	local early, earlyTop = onArm(fresh(red))
	task.wait(1.9)
	local full, fullTop = onArm(fresh(red))
	if early < 4 then
		problem("FA JIN: red veins light up on his arm as he charges (" .. early .. ")")
	elseif not (full > early * 1.5 and fullTop > earlyTop) then
		problem("...and creep on up it to the shoulder (" .. early .. "/" .. earlyTop .. " -> " .. full .. "/" .. fullTop .. ")")
	end
	VFX.Play("FaJinSmashRelease", myChar, { Dir = FWD, Level = 3, Power = 1 }, true)
	task.wait(0.5)
	local after = onArm(fresh(red))
	if after > 0 then
		problem("...and they burn out as it fires (" .. after .. " left)")
	end
	task.wait(1)

	-- THE CONTROLLER CURSOR
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	task.wait(0.05)
	local cursorGui = playerGui:FindFirstChild("PadCursor")
	if not cursorGui or cursorGui.Enabled then
		problem("CURSOR: no menu open - no cursor")
	end
	HUD.ToggleShop(true)
	task.wait(0.1)
	if not (cursorGui and cursorGui.Enabled and actions.QuirkPadCursor) then
		problem("...a menu open on a controller: a cursor to move about like a mouse")
	end
	local ring = cursorGui and cursorGui:FindFirstChild("Cursor")
	local x0 = ring and ring.Position.X.Offset or 0
	stickPos = Vector3.new(1, 0, 0)
	task.wait(0.3)
	local x1 = ring and ring.Position.X.Offset or 0
	if x1 < x0 + 80 then
		problem("...the left stick moves it (" .. x0 .. " -> " .. x1 .. ")")
	end
	stickPos = Vector3.zero
	task.wait(0.1)
	local x2 = ring and ring.Position.X.Offset or 0
	task.wait(0.2)
	if (ring and ring.Position.X.Offset or 0) ~= x2 then
		problem("...and stops when you let go")
	end
	-- over a button: it lights up (selected), and A goes to it
	local shopButton
	for _, d in hudGui:GetDescendants() do
		if d:IsA("TextButton") and d.Visible and d.Selectable then
			shopButton = d
			break
		end
	end
	padHits = { shopButton }
	task.wait(0.1)
	local gs = game:GetService("GuiService")
	local okSel, sel = pcall(function()
		return gs.SelectedObject
	end)
	if okSel and sel ~= shopButton then
		problem("...over a button: it lights up, ready for A (" .. tostring(sel) .. ")")
	end
	local res = actions.QuirkPadCursor and actions.QuirkPadCursor("QuirkPadCursor", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonA, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.zero })
	if res ~= Enum.ContextActionResult.Pass then
		problem("...and A presses it")
	end
	padHits = {}
	task.wait(0.1)
	res = actions.QuirkPadCursor and actions.QuirkPadCursor("QuirkPadCursor", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonA, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.zero })
	if res ~= Enum.ContextActionResult.Sink then
		problem("...over nothing, A does nothing (not a jump)")
	end
	HUD.ToggleShop(false)
	task.wait(0.1)
	if cursorGui and cursorGui.Enabled then
		problem("...close the menu: the cursor goes")
	end
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	HUD.ToggleShop(true)
	task.wait(0.1)
	if cursorGui and cursorGui.Enabled then
		problem("...(on keyboard and mouse there's no pad cursor: you have the mouse)")
	end
	HUD.ToggleShop(false)
	ticking = false
	task.wait(0.2)
end)
if not ok39 then
	problem("round 39 client scenario crashed: " .. tostring(err39))
end
print("== round 40: the controller cursor only moves when you move it")
local ok40, err40 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.HideVendor()
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	HUD.ToggleShop(true)
	task.wait(0.15)
	local ring = playerGui:FindFirstChild("PadCursor") and playerGui.PadCursor:FindFirstChild("Cursor")
	local function at()
		return ring and ring.Position or UDim2.new()
	end
	if not ring then
		problem("CURSOR: it's up with the shop open on a controller")
		return
	end
	-- a worn stick resting a little off centre: it stays put
	stickPos = Vector3.new(0.16, -0.12, 0)
	local p0 = at()
	task.wait(0.4)
	if at() ~= p0 then
		problem("...a stick resting slightly off centre doesn't creep it (" .. tostring(p0) .. " -> " .. tostring(at()) .. ")")
	end
	-- a stale "the stick moved" with no "let go" after it: it reads the stick
	-- as it is now, which is centred, so nothing
	stickPos = Vector3.zero
	if actions.QuirkPadCursor then
		actions.QuirkPadCursor("QuirkPadCursor", Enum.UserInputState.Change, { KeyCode = Enum.KeyCode.Thumbstick1, UserInputType = Enum.UserInputType.Gamepad1, Position = Vector3.new(0.9, 0, 0) })
	end
	p0 = at()
	task.wait(0.4)
	if at() ~= p0 then
		problem("...a missed 'let go' doesn't leave it drifting (" .. tostring(p0) .. " -> " .. tostring(at()) .. ")")
	end
	-- the UNO table updating on your turn (what used to jump it onto your
	-- first playable card, every update): it stays where you put it
	HUD.ToggleShop(false)
	local Uno = remotes:FindFirstChild("Uno")
	local function state(hand)
		return {
			Table = 1, Phase = "Game", Seated = { "Tester", "Rival" }, Deck = 60, TurnTime = 20,
			Players = { { Name = "Tester", UserId = localPlayer.UserId, Count = #hand, Turn = true }, { Name = "Rival", UserId = 9, Count = 4 } },
			Hand = hand, Top = "R3", Color = "R", Dir = 1, MyTurn = true,
		}
	end
	Uno.OnClientEvent:Fire("State", state({ "G7", "R5", "B2" }))
	task.wait(0.15)
	stickPos = Vector3.new(0, 1, 0)
	task.wait(0.2)
	stickPos = Vector3.zero
	task.wait(0.05)
	p0 = at()
	for i = 1, 3 do
		Uno.OnClientEvent:Fire("State", state({ "G7", "R5", "B2", "R" .. i }))
		task.wait(0.1)
	end
	if at() ~= p0 then
		problem("...nothing but your stick moves it - not the table updating (" .. tostring(p0) .. " -> " .. tostring(at()) .. ")")
	end
	-- and a push really does move it
	stickPos = Vector3.new(-1, 0, 0)
	task.wait(0.2)
	stickPos = Vector3.zero
	if at().X.Offset >= p0.X.Offset - 40 then
		problem("...your stick does move it (" .. tostring(p0) .. " -> " .. tostring(at()) .. ")")
	end
	Uno.OnClientEvent:Fire("Closed")
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	ticking = false
	task.wait(0.1)
end)
if not ok40 then
	problem("round 40 client scenario crashed: " .. tostring(err40))
end
stickPos = Vector3.zero
print("== round 41: Kamui's swing flings harder, orange leaves, the root prison; frozen stops you dead")
local ok41, err41 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	local KW = VFX.KW
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	local function reset()
		VFX.SwingRelease(myChar)
		task.wait(0.05)
		root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
		root.AssemblyLinearVelocity = Vector3.zero
		cam.CFrame = lookAt(Vector3.new(0, 8, 12), Vector3.new(0, 6, -20))
	end
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	mark()
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and d:IsA("BasePart") and d.Transparency < 0.5 and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function all(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and d:IsA("BasePart") and filter(d) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function wood(d)
		return d.Material == Enum.Material.Wood and d.ClassName ~= "WedgePart"
	end
	local function leafy(d)
		return d.Material == Enum.Material.Grass
	end
	local function street(_, origin, dir)
		if dir.Y >= 0 or origin.Y + dir.Y > 0 then
			return nil
		end
		local t = origin.Y / -dir.Y
		local p = origin + dir * t
		return { Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.new(0, 1, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Asphalt }
	end

	-- BRANCH SWING: letting go - harder, higher, and the speed stays with him
	setRaycast(nil)
	hum.FloorMaterial = Enum.Material.Air
	reset()
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3 })
	task.wait(1.6)
	local plain = root.AssemblyLinearVelocity
	reset()
	local BS = Config.Quirks.Arbor.Special
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3, Speed = BS.SwingSpeed, Exit = BS.ExitSpeed, Lift = BS.ExitLift, Carry = BS.Carry })
	local t0 = os.clock()
	while VFX.Swinging(myChar) and os.clock() - t0 < 2 do
		task.wait()
	end
	local flung = root.AssemblyLinearVelocity
	print(string.format("  (a plain swing lets go at %s, Kamui's at %s)", tostring(plain), tostring(flung)))
	if not (flung.Y > plain.Y + 15 and -flung.Z > -plain.Z + 10) then
		problem("BRANCH SWING: Kamui lets go further forward and higher than a plain swing (" .. tostring(plain) .. " -> " .. tostring(flung) .. ")")
	end
	if not VFX.SwingCarrying(myChar) then
		problem("...and the fling keeps its speed a while")
	end
	-- (the air steering pulls him back to a walk - the fling tops it back up)
	root.AssemblyLinearVelocity = Vector3.new(3, flung.Y - 5, -12)
	task.wait(3 / 60)
	local kept = root.AssemblyLinearVelocity
	if not (kept.Z < -45 and kept.X > 1) then
		problem("...steering in the air bends it but can't eat it (" .. tostring(kept) .. ")")
	end
	task.wait(BS.Carry + 0.1)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -12)
	task.wait(3 / 60)
	if VFX.SwingCarrying(myChar) or root.AssemblyLinearVelocity.Z < -13 then
		problem("...for a while, not forever (" .. tostring(root.AssemblyLinearVelocity) .. ")")
	end
	-- landing ends it, and so does a dash (or a move)
	reset()
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3, Exit = 80, Carry = 2 })
	task.wait(1.6)
	hum.FloorMaterial = Enum.Material.Plastic
	task.wait(3 / 60)
	if VFX.SwingCarrying(myChar) then
		problem("...landing ends the fling")
	end
	hum.FloorMaterial = Enum.Material.Air
	reset()
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3, Exit = 80, Carry = 2 })
	task.wait(1.6)
	VFX.SwingRelease(myChar)
	if VFX.SwingCarrying(myChar) then
		problem("...and a dash or a move takes over from it")
	end
	-- a wall in the way: he stops against it rather than sticking to it
	reset()
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3, Exit = 80, Carry = 2 })
	task.wait(1.6)
	setRaycast(function(_, origin, dir)
		if dir.Z < 0 and dir.Y > -0.5 and dir.Y < 0.5 then
			return { Position = origin + dir, Normal = Vector3.new(0, 0, 1), Distance = dir.Magnitude, Instance = workspace, Material = Enum.Material.Concrete }
		end
		return nil
	end)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -5)
	task.wait(3 / 60)
	if VFX.SwingCarrying(myChar) or root.AssemblyLinearVelocity.Z < -6 then
		problem("...a wall ahead: the fling stops against it (" .. tostring(root.AssemblyLinearVelocity) .. ")")
	end
	setRaycast(nil)

	-- the search: an invisible wall in front of a building is no anchor
	reset()
	local ghost = Instance.new("Part")
	ghost.Transparency = 1
	ghost.CanCollide = true
	setRaycast(function(_, origin, dir)
		if dir.Z >= 0 then
			return nil
		end
		for _, wall in { { z = -8, inst = ghost }, { z = -40, inst = workspace } } do
			if origin.Z > wall.z then
				local t = (wall.z - origin.Z) / dir.Z
				if t >= 0 and t <= 1 then
					local p = origin + dir * t
					if p.Y >= 0 and p.Y <= 60 and math.abs(p.X) <= 60 then
						return { Position = p, Normal = Vector3.new(0, 0, 1), Distance = (p - origin).Magnitude, Instance = wall.inst, Material = Enum.Material.Concrete }
					end
				end
				return nil
			end
		end
		return nil
	end)
	local anchor = VFX.SwingAnchor(myChar, Vector3.new(0, 0.3, -1).Unit, 110)
	if not (anchor and anchor.Z < -39) then
		problem("SWING SEARCH: an invisible wall isn't something to swing from - the building behind it is (" .. tostring(anchor) .. ")")
	end
	ghost.Transparency = 0
	anchor = VFX.SwingAnchor(myChar, Vector3.new(0, 0.3, -1).Unit, 110)
	if not (anchor and anchor.Z > -8 and anchor.Z < -7) then
		problem("...a wall you can see is (" .. tostring(anchor) .. ")")
	end
	-- (a dense fan: a narrow tower off to one side, between the old rays, is found)
	setRaycast(function(_, origin, dir)
		-- a 6-stud-wide tower 40 studs out, 16 degrees off ahead (the old fan's
		-- rays went at 0 and 30: both miss it by 10 studs)
		local c = Vector3.new(math.sin(math.rad(16)) * 40, 0, -math.cos(math.rad(16)) * 40)
		for t = 0, 1, 0.004 do
			local p = origin + dir * t
			if math.abs(p.X - c.X) < 3 and math.abs(p.Z - c.Z) < 3 and p.Y >= 0 and p.Y <= 50 then
				return { Position = p, Normal = Vector3.new(0, 0, 1), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Concrete }
			end
		end
		return nil
	end)
	anchor = VFX.SwingAnchor(myChar, Vector3.new(0, 0, -1), 110)
	if not anchor then
		problem("...a narrow tower off to one side is found (the fan is denser)")
	end
	setRaycast(nil)
	hum.FloorMaterial = Enum.Material.Plastic
	reset()

	-- LEAVES: orange, and plenty of them
	for _, c in { KW.LEAF, KW.LEAF_DARK, KW.LEAF_GOLD } do
		if not (c.R > c.G and c.G > c.B and c.R > 0.7) then
			problem("KAMUI'S LEAVES are autumn orange (" .. tostring(c) .. ")")
		end
	end
	local b = KW.branch(0.7, 12)
	local leaves = 0
	for _, t in b.twigs do
		if t.leaf then
			leaves += 1
		end
	end
	if leaves < 5 then
		problem("...a leaf off every other segment of a branch (" .. leaves .. ", was 1)")
	end
	b.fade(0)
	mark()
	setRaycast(street)
	VFX.Play("TreeHammer", myChar, { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 3, -16) }, true)
	task.wait(0.2)
	local onHammer = all(leafy)
	if #onHammer < 6 then
		problem("...sprouting off the Tree Hammer's log (" .. #onHammer .. " leaves)")
	end
	task.wait(0.35)
	local fallen = all(leafy)
	if #fallen < #onHammer + 10 then
		problem("...and plenty coming down where it lands (" .. #fallen - #onHammer .. ")")
	end
	for _, p in fallen do
		if not (p.Color.R > p.Color.G and p.Color.G > p.Color.B) then
			problem("...every one of them orange (" .. tostring(p.Color) .. ")")
			break
		end
	end
	task.wait(1.5)
	mark()

	-- THOUSAND-BRANCH PRISON: roots, not spikes
	local dummy = Instance.new("Model")
	dummy.Name = "PrisonDummy"
	local droot = Instance.new("Part")
	droot.Name = "HumanoidRootPart"
	droot.Size = Vector3.new(2, 2, 1)
	droot.CFrame = CFrame.new(0, 3, -15)
	droot.Position = Vector3.new(0, 3, -15)
	droot.Parent = dummy
	dummy.Parent = workspace
	VFX.Play("ThousandBranch", myChar, {}, true)
	task.wait(0.4)
	local stakes, roots, farOut = 0, fresh(wood), 0
	for _, d in VFX.Folder:GetDescendants() do
		if not seen[d] and d.ClassName == "WedgePart" and d.Transparency < 0.5 then
			stakes += 1
		end
	end
	for _, p in roots do
		local flat = Vector3.new(p.CFrame.Position.X, 0, p.CFrame.Position.Z)
		if flat.Magnitude > 15 then
			farOut += 1
		end
	end
	if stakes > 0 then
		problem("THOUSAND-BRANCH PRISON: no spikes any more (" .. stakes .. " stake points)")
	elseif #roots < 40 or farOut < 8 then
		problem("...roots racing out through the street all round him (" .. #roots .. " pieces, " .. farOut .. " past 15 studs)")
	end
	mark()
	VFX.Play("ThousandBranchCatch", myChar, { Targets = { dummy }, Duration = 1.8, Center = Vector3.new(0, 3, 0) }, true)
	task.wait(0.4)
	local cage = KW.cages[dummy]
	local coil, over, bars = 0, 0, 0
	for _, p in fresh(wood) do
		local rel = p.CFrame.Position - droot.CFrame.Position
		if Vector3.new(rel.X, 0, rel.Z).Magnitude < 4.2 then
			coil += 1
			if rel.Y > 2.5 then
				over += 1
			end
		end
		if math.abs(p.Size.X - 0.42) < 0.01 and math.abs(p.Size.Y - 0.42) < 0.01 then
			bars += 1
		end
	end
	if not cage then
		problem("...whoever it catches is caged")
	elseif bars > 0 or coil < 30 then
		problem("...in roots coiled up round them, not square bars (" .. coil .. " root pieces, " .. bars .. " bars)")
	elseif over < 5 then
		problem("...closing over their head (" .. over .. " up top)")
	end
	VFX.Play("ThousandBranchCrush", myChar, { Targets = { dummy }, Center = Vector3.new(0, 3, 0) }, true)
	task.wait(0.1)
	if KW.cages[dummy] then
		problem("...and crushed apart at the end")
	end
	task.wait(1.6)
	setRaycast(nil)
	dummy.Parent = nil
	mark()

	-- a block of ice round someone breaks early (Glacier Breaker shatters it)
	local ice = Instance.new("Model")
	local iroot = Instance.new("Part")
	iroot.Name = "HumanoidRootPart"
	iroot.CFrame = CFrame.new(10, 3, 0)
	iroot.Position = Vector3.new(10, 3, 0)
	iroot.Parent = ice
	ice.Parent = workspace
	VFX.Play("Freeze", nil, { Target = ice, Duration = 3 }, false)
	task.wait(0.25)
	local function iceNear()
		local n = 0
		for _, p in fresh(function(d)
			return d.Material == Enum.Material.Ice
		end) do
			if (p.CFrame.Position - iroot.CFrame.Position).Magnitude < 2 then
				n += 1
			end
		end
		return n
	end
	if iceNear() ~= 1 then
		problem("FREEZE: a block of ice round them")
	end
	VFX.Play("Thaw", nil, { Target = ice }, false)
	task.wait(0.1)
	if iceNear() ~= 0 then
		problem("...and a Thaw shatters it early")
	end
	ice.Parent = nil

	-- frozen solid: your own swing (and its fling) stops dead
	reset()
	hum.FloorMaterial = Enum.Material.Air
	VFX.Swing(myChar, Vector3.new(0, 40, -40), { Time = 1.3 })
	task.wait(0.2)
	setAttr(myChar, "Frozen", true)
	task.wait(3 / 60)
	if VFX.Swinging(myChar) or VFX.SwingCarrying(myChar) then
		problem("FROZEN: your swing stops dead")
	end
	setAttr(myChar, "Frozen", nil)
	hum.FloorMaterial = Enum.Material.Plastic
	reset()
	ticking = false
	task.wait(0.3)
end)
if not ok41 then
	problem("round 41 client scenario crashed: " .. tostring(err41))
end
setRaycast(nil)
print("== round 42: EXPLOSIVE SPEED's slow motion, the DAD MODE party")
local ok42, err42 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	root.Position = Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	workspace.CurrentCamera.CFrame = lookAt(Vector3.new(0, 8, 12), Vector3.new(0, 3, -10))
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	mark()
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and d:IsA("BasePart") and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function slowMo()
		for _, d in Lighting:GetChildren() do
			if d.Name == "BlitzSlowMo" then
				return true
			end
		end
		return false
	end
	local FWD = Vector3.new(0, 0, -1)
	local ES = Config.Quirks.Explosion.Ult.Extra

	-- (round 63) FULL-BODY CLUSTER: his last stand. The walk at them, the
	-- beads popping all over him, what he says
	VFX.Play("FullBodyCluster", myChar, { Dir = FWD }, true)
	task.wait(0.4)
	local beads = fresh(function(d)
		return d.Material == Enum.Material.Neon
	end)
	if #beads < 8 then
		problem("FULL-BODY CLUSTER: the beads popping all over him on the walk (" .. #beads .. ")")
	end
	local said
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "GOTTA WIN", 1, true) then
			said = d
		end
	end
	if not said then
		problem("FULL-BODY CLUSTER: \"IZUKU... YOU'VE GOTTA WIN.\" over his head")
	end
	task.wait(ES.WalkTime - 0.4)
	-- the blink: gone, and in their face with a mass of stored Cluster
	local target = Instance.new("Model")
	local troot = Instance.new("Part")
	troot.Name = "HumanoidRootPart"
	troot.CFrame = CFrame.new(0, 3, -12)
	troot.Position = Vector3.new(0, 3, -12)
	troot.Parent = target
	target.Parent = workspace
	mark()
	VFX.Play("FullBodyClusterBlink", myChar, { From = Vector3.new(0, 3, 0), To = Vector3.new(0, 3, -9.4), Dir = FWD, Target = target }, true)
	task.wait(0.3)
	if #fresh() < 15 then
		problem("...the blink, and the palm going off in their face (" .. #fresh() .. " pieces)")
	end
	-- from every side: explosions off his whole body, bigger each time
	local spots = { Vector3.new(2, 3, -14), Vector3.new(-2.5, 3, -10), Vector3.new(0, 4, -15) }
	local counts = {}
	for i, at in spots do
		mark()
		VFX.Play("FullBodyClusterHit", myChar, { Pos = at, At = Vector3.new(0, 3.5, -12), Target = target, Level = i * 2 - 1, Of = ES.Hits }, true)
		task.wait(0.12)
		counts[i] = #fresh()
	end
	if not (counts[1] >= 12 and counts[3] > counts[1]) then
		problem("...all round them, off his whole body, bigger each time (" .. table.concat(counts, ", ") .. ")")
	end
	-- the white void (on his own screen): the words to All Might
	VFX.Play("FullBodyClusterVoid", myChar, { Time = ES.VoidTime }, true)
	task.wait(0.35)
	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	local void = pg and pg:FindFirstChild("WhiteVoid")
	local words = false
	for _, d in void and void:GetDescendants() or {} do
		if d:IsA("TextLabel") and string.find(d.Text, "sign my card", 1, true) then
			words = true
		end
	end
	if not (void and words) then
		problem("...the white void: \"I always wanted you to sign my card\"")
	end
	task.wait(ES.VoidTime)
	-- all he has left, point blank; the card floats down
	mark()
	VFX.Play("FullBodyClusterFinal", myChar, { Pos = Vector3.new(0, 3, -11), Dir = FWD, Target = target }, true)
	task.wait(0.2)
	if #fresh() < 25 then
		problem("...everything he has left, point blank (" .. #fresh() .. " pieces)")
	end
	if void and void.Parent and void:FindFirstChildWhichIsA("Frame").BackgroundTransparency < 0.9 then
		problem("...and it cuts back to the fight")
	end
	task.wait(0.4)
	local card = fresh(function(d)
		return d.Name == "AllMightCard"
	end)[1]
	if not (card and card:FindFirstChildWhichIsA("SurfaceGui")) then
		problem("...and his All Might card floats down")
	end
	-- called off: he lets go of the pose
	VFX.Play("FullBodyCluster", myChar, { Dir = FWD }, true)
	task.wait(0.1)
	VFX.Play("FullBodyClusterCancel", myChar, {}, true)
	target.Parent = nil
	task.wait(1)
	VFX.ReleasePose(myChar, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	mark()

	-- DAD MODE: the dance floor, the disco ball, the song
	local dad
	for _, e in Config.Emotes do
		if e.Id == "DadMode" then
			dad = e
		end
	end
	local total = 0
	for _, step in ipairs(VFX.Motions and VFX.Motions.EmoteDadMode or {}) do
		total += (step.t or 0.08) + (step.hold or 0)
	end
	VFX.Play("Emote", myChar, { Id = "DadMode" }, true)
	task.wait(0.2)
	local tiles = fresh(function(d)
		return d.Material == Enum.Material.Neon and math.abs(d.Size.X - 1.9) < 0.01 and math.abs(d.Size.Z - 1.9) < 0.01
	end)
	local balls = fresh(function(d)
		return d.Material == Enum.Material.Foil and d.Shape == Enum.PartType.Ball
	end)
	local song = root:FindFirstChild("PartySong")
	if #tiles ~= 9 then
		problem("DAD MODE: a light-up dance floor under him (" .. #tiles .. " tiles)")
	end
	if #balls ~= 1 or balls[1].CFrame.Position.Y < root.CFrame.Position.Y + 4 then
		problem("...a disco ball over his head")
	end
	if not (song and song:IsA("Sound")) then
		problem("...and the song playing off him")
	elseif dad and dad.Song == "" and song.SoundId ~= Config.Music.Disco then
		problem("...(until the uploaded song's id is filled in, the disco track) " .. tostring(song.SoundId))
	elseif song.RollOffMaxDistance > 150 then
		problem("...heard nearby, not across the map")
	end
	local before = {}
	for i, t in tiles do
		before[i] = t.Color
	end
	task.wait(60 / 128 + 0.05)
	local changed = 0
	for i, t in tiles do
		if t.Color ~= before[i] then
			changed += 1
		end
	end
	if changed < 3 then
		problem("...the floor flips colours on the beat (" .. changed .. " tiles changed)")
	end
	if math.abs(total - 32 * 60 / 128) > 0.05 then
		problem(string.format("...32 beats of dancing, as long as the song (%.2fs)", total))
	end
	-- walking off ends it: the party packs up and the music stops
	root.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
	task.wait(0.5)
	root.AssemblyLinearVelocity = Vector3.zero
	local still = root:FindFirstChild("PartySong")
	if still and still.Volume > 0.05 then
		problem("...walking off stops the song")
	end
	local left = 0
	for _, t in tiles do
		if t.Parent and t.Transparency < 0.9 then
			left += 1
		end
	end
	if left > 0 then
		problem("...and the dance floor goes (" .. left .. " tiles left)")
	end
	ticking = false
	task.wait(0.3)
end)
if not ok42 then
	problem("round 42 client scenario crashed: " .. tostring(err42))
end
print("== round 43: moves wound up and followed through, KO finishers, Kamui's joined-up roots and root cage")
local ok43, err43 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	root.Position = Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	mark()
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function wood(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.Wood and d.Transparency < 0.5
	end
	local FWD = Vector3.new(0, 0, -1)

	-- every strike: drawn back, snapped a touch past, then followed through
	local punch = VFX.PoseArc and VFX.PoseArc("PunchR", { RightArm = 95, LeftArm = { 20, 0, 10 }, LeftElbow = 70, Waist = { -6, 22, 0 } })
	if not (punch and punch.wind and punch.over and punch.follow) then
		problem("POSES: a punch winds up, snaps past and follows through (not straight to the pose)")
	else
		local wr, fr = punch.wind.RightArm, punch.full.RightArm
		local w, f = type(wr) == "table" and wr[1] or wr, type(fr) == "table" and fr[1] or fr
		if not (w < f) then
			problem("...the wind-up draws the arm back first (" .. tostring(w) .. " vs " .. tostring(f) .. ")")
		end
		if not (punch.full.RightKnee or punch.full.Hips) then
			problem("...and he's in a fighting stance for it, knees bent (not stood up straight)")
		end
	end
	local guard = VFX.PoseArc and VFX.PoseArc("Guard", { RightArm = { 80, 0, 60 }, LeftArm = { 80, 0, 60 } })
	if guard and guard.wind then
		problem("...(a guard just goes up: no wind-up on a hold)")
	end

	-- KO FINISHER: the killer's own screen
	local target = Instance.new("Model")
	local troot = Instance.new("Part")
	troot.Name = "HumanoidRootPart"
	troot.CFrame = CFrame.new(0, 3, -12)
	troot.Position = Vector3.new(0, 3, -12)
	troot.Parent = target
	target.Parent = workspace
	workspace.CurrentCamera.CFrame = lookAt(Vector3.new(0, 8, 12), Vector3.new(0, 3, -10))
	myChar:SetAttribute("Quirk", "Explosion")
	VFX.Play("KOFinisher", myChar, { Target = target, Move = "APShot", Name = "AP SHOT", Dir = FWD, Pos = Vector3.new(0, 3, -12) }, true)
	task.wait(0.1)
	local text
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "K.O.!" then
			text = d
		end
	end
	if not text then
		problem("KO FINISHER: \"K.O.!\" bursts off the body")
	end
	if not target:FindFirstChildOfClass("Highlight") then
		problem("...the body flashes white")
	end
	local slow = false
	for _, d in Lighting:GetChildren() do
		if d.Name == "BlitzSlowMo" then
			slow = true
		end
	end
	if not slow then
		problem("...time slows around it")
	end
	if not VFX.InCinematic() then
		problem("...and the killer's camera swings round to watch the body fly")
	end
	if #fresh(function(d)
		return d:IsA("BasePart")
	end) < 6 then
		problem("...in a burst of the killer's quirk (Bakugo's: an explosion)")
	end
	myChar:SetAttribute("Quirk", nil)
	task.wait(2)
	if VFX.InCinematic() then
		problem("...then the camera comes back")
	end
	for _, d in Lighting:GetChildren() do
		if d.Name == "BlitzSlowMo" then
			problem("...and time speeds up again")
			break
		end
	end
	target.Parent = nil
	VFX.ReleasePose(myChar, 0)
	mark()

	-- LACQUERED CHAIN PRISON: the ult's round cage of roots coiling up them
	local caught = Instance.new("Model")
	local croot = Instance.new("Part")
	croot.Name = "HumanoidRootPart"
	croot.CFrame = CFrame.new(0, 3, -14)
	croot.Position = Vector3.new(0, 3, -14)
	croot.Parent = caught
	caught.Parent = workspace
	VFX.Play("ChainPrisonCatch", myChar, { Target = caught, Duration = 1.6 }, true)
	task.wait(0.5)
	local roots = fresh(wood)
	local angles = {}
	for _, p in roots do
		local off = p.CFrame.Position - croot.Position
		if Vector3.new(off.X, 0, off.Z).Magnitude < 5 then
			angles[math.floor((math.atan2(off.Z, off.X) + math.pi) / (math.pi / 3)) % 6] = true
		end
	end
	local sides = 0
	for _ in angles do
		sides += 1
	end
	if #roots < 30 or sides < 5 then
		problem("CHAIN PRISON: roots coil up all round them, like the ult's cage (" .. #roots .. " pieces, " .. sides .. "/6 sides)")
	end
	task.wait(1.8)
	if #fresh(wood) > 0 then
		problem("...and it lets go when the bind ends")
	end
	caught.Parent = nil
	mark()

	-- ROOT BREAKER: one joined-up root, half sunk in the street between the
	-- arches (not humps) - from the air too
	setRaycast(function(_, origin, dir)
		if dir.Y >= 0 or origin.Y + dir.Y > 0 then
			return nil
		end
		local t = origin.Y / -dir.Y
		local p = origin + dir * t
		return { Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.new(0, 1, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Asphalt }
	end)
	for _, height in { 3, 14 } do
		root.CFrame = lookAt(Vector3.new(0, height, 0), Vector3.new(0, height, -10))
		root.Position = Vector3.new(0, height, 0)
		VFX.Play("RootBreaker", myChar, { Dir = FWD, Pos = Vector3.new(0, 3, -40) }, true)
		task.wait(0.66)
		local segs = {}
		for _, p in fresh(wood) do
			local c = p.CFrame.Position
			-- (the street-running roots, not the forearms diving in at his feet)
			if p.Size.Z > p.Size.X * 1.05 and c.Y < 6 and c.Z < -3.5 then
				table.insert(segs, p)
			end
		end
		-- (joined: along each root, one piece ends where the next starts. From
		-- the centres and lengths - Lune's lookAt with a sideways up vector
		-- doesn't give the axis Roblox does)
		local buried, loose = 0, 0
		for _, p in segs do
			if p.CFrame.Position.Y + p.Size.Y * 0.5 < 0.05 then
				buried += 1
			end
		end
		-- (every piece has the next one further down the street touching it,
		-- bar the two tips)
		local lastZ = math.huge
		for _, p in segs do
			lastZ = math.min(lastZ, p.CFrame.Position.Z)
		end
		for _, p in segs do
			local c = p.CFrame.Position
			if c.Z > lastZ + 2.5 then
				local joined = false
				for _, q in segs do
					local qc = q.CFrame.Position
					if q ~= p and qc.Z < c.Z and (qc - c).Magnitude <= (p.Size.Z + q.Size.Z) / 2 + 0.3 then
						joined = true
						break
					end
				end
				if not joined then
					loose += 1
				end
			end
		end
		local from = height > 5 and " (from the air)" or ""
		if #segs < 20 then
			problem("ROOT BREAKER" .. from .. ": the roots run down the street (" .. #segs .. " pieces)")
		elseif buried > 0 then
			problem("...no stretch of root lost under the street, so it's not just humps" .. from .. " (" .. buried .. " hidden)")
		elseif loose > 0 then
			problem("...one continuous root, every piece joined to the next" .. from .. " (" .. loose .. " gaps)")
		end
		task.wait(1.6)
		mark()
	end
	setRaycast(nil)
	root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	root.Position = Vector3.new(0, 3, 0)

	-- BRANCH SWING: a real swing - trailing, hanging, tucking, kicking out
	local arc = VFX.Motions and VFX.Motions.SwingArc
	if not (arc and #arc >= 4) then
		problem("BRANCH SWING: a swinging motion (trail, hang, tuck, kick out)")
	end
	ticking = false
	task.wait(0.3)
end)
if not ok43 then
	problem("round 43 client scenario crashed: " .. tostring(err43))
end
print("== round 44: Mr. Compress's marbles, Chargebolt's pointers")
local ok44, err44 = pcall(function()
	local CFrame, Color3 = r.CFrame, r.Color3
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	local root = myChar.HumanoidRootPart
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		return CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	root.CFrame = lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -10))
	root.Position = Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	mark()
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function neon(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.Neon
	end
	local function glassBall(d)
		return d:IsA("BasePart") and d.Shape == Enum.PartType.Ball and d.Material == Enum.Material.Glass
	end
	local function brick(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.Brick
	end
	local FWD = Vector3.new(0, 0, -1)

	-- the quirk menu: Decay, Mr. Compress and Chargebolt for everyone
	local public = 0
	for _, name in Config.QuirkOrder do
		if not Config.Quirks[name].DevOnly then
			public += 1
		end
	end
	if public < 12 or Config.Quirks.Decay.DevOnly or not Config.Quirks.Compress or not Config.Quirks.Electrification then
		problem("the quirk menu: Decay, MR. COMPRESS and CHARGEBOLT for everyone (" .. public .. " public)")
	end
	HUD.SetDevAccess(false)
	local shown = 0
	for _, d in hudGui:GetDescendants() do
		if d:IsA("TextButton") and Config.Quirks[d.Name] and d.Visible then
			shown += 1
		end
	end
	if shown ~= public then
		problem("...all of them on the menu for a regular player (" .. shown .. " of " .. public .. ")")
	end

	-- the pips over the health bar
	HUD.SetPips({ Label = "MARBLES", Count = 2, Max = 3, Color = Color3.fromRGB(150, 214, 255), Hint = "R: POCKET A PIECE OF THE STREET" })
	local pips = hudGui:FindFirstChild("Pips", true)
	if not (pips and pips.Visible) then
		problem("MARBLES: a row of pips over the health bar")
	else
		local full, dots = 0, 0
		for _, d in pips:GetChildren() do
			if d:IsA("Frame") and d.Name:match("^Pip%d") and d.Visible then
				dots += 1
				if d.BackgroundTransparency < 0.5 then
					full += 1
				end
			end
		end
		if dots ~= 3 or full ~= 2 then
			problem("...2 of 3 filled (" .. full .. " of " .. dots .. ")")
		end
		local label = pips:FindFirstChildOfClass("TextLabel")
		if not (label and label.Text:find("2/3")) then
			problem("...and the count (" .. tostring(label and label.Text) .. ")")
		end
	end
	-- driven off the body's attributes, the way the server does it
	setAttr(myChar, "Marbles", 0)
	local label = pips and pips:FindFirstChildOfClass("TextLabel")
	if not (pips and pips.Visible and label and label.Text:find("POCKET")) then
		problem("...an empty pocket: the hint to use R (" .. tostring(label and label.Text) .. ")")
	end
	setAttr(myChar, "Marbles", nil)
	if pips and pips.Visible then
		problem("...gone when he's someone else")
	end
	setAttr(myChar, "Pointers", 1)
	if not (pips and pips.Visible and label and label.Text:find("POINTERS 1/2")) then
		problem("POINTERS: the clip on the same pips (" .. tostring(label and label.Text) .. ")")
	end
	setAttr(myChar, "Pointers", nil)
	PlayVFX.OnClientEvent:Fire("Reload", nil, { Index = Config.SPECIAL_INDEX, Time = 4 })

	-- POINTER: the disc sticks to them, rides them, and goes when it expires
	local target = Instance.new("Model")
	local troot = Instance.new("Part")
	troot.Name = "HumanoidRootPart"
	troot.CFrame = CFrame.new(0, 3, -14)
	troot.Position = Vector3.new(0, 3, -14)
	troot.Parent = target
	target.Parent = workspace
	VFX.Play("PointerShot", myChar, { From = Vector3.new(0, 4.5, 0), To = Vector3.new(0, 3, -14), Dir = FWD }, true)
	VFX.Play("PointerStick", myChar, { Id = 7, Target = target, Pos = Vector3.new(0, 3, -14), Normal = Vector3.new(0, 0, 1), Life = 20 }, true)
	task.wait(0.3)
	local discs = fresh(function(d)
		-- (the stuck one carries its own light; the streak's disc doesn't)
		return d:IsA("BasePart") and d.Shape == Enum.PartType.Cylinder and d:FindFirstChildOfClass("PointLight") ~= nil and d.Transparency < 0.5
	end)
	if #discs < 1 then
		problem("POINTER: an orange disc stuck on them")
	end
	troot.CFrame = CFrame.new(5, 3, -14)
	troot.Position = Vector3.new(5, 3, -14)
	task.wait(0.12)
	if discs[1] and (discs[1].CFrame.Position - Vector3.new(5, 3, -14)).Magnitude > 3 then
		problem("...riding on them as they move")
	end
	VFX.Play("PointerGone", myChar, { Id = 7 }, true)
	task.wait(0.35)
	if discs[1] and discs[1].Parent and discs[1].Transparency < 0.9 then
		problem("...and gone when it expires")
	end
	mark()

	-- DISCHARGE: one jagged line of lightning to the pointer
	VFX.Play("DischargeLine", myChar, { From = Vector3.new(0, 4, 0), To = Vector3.new(0, 3, -30), Target = target, Width = 4 }, true)
	task.wait(0.32)
	local bolts = fresh(neon)
	local far = 0
	for _, b in bolts do
		if b.CFrame.Position.Z < -20 then
			far += 1
		end
	end
	if #bolts < 20 then
		problem("DISCHARGE: one jagged line of lightning to the pointer (" .. #bolts .. " pieces)")
	elseif far < 4 then
		problem("...all the way to it (" .. far .. " pieces past 20 studs)")
	end
	task.wait(0.6)
	VFX.Play("Shocked", nil, { Target = target, Duration = 1 }, false)
	task.wait(0.2)
	if not troot:FindFirstChildOfClass("ParticleEmitter") then
		problem("...jolted: sparks all over them")
	end
	task.wait(1.2)
	mark()

	-- WHEEEY
	VFX.Play("Wheey", myChar, { Duration = 1.5 }, true)
	task.wait(0.2)
	local word
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "WHEEEY" then
			word = d
		end
	end
	if not word then
		problem("WHEEEY: the word over his head, thumbs up")
	end
	task.wait(1.6)
	VFX.ReleasePose(myChar, 0)
	mark()

	-- COMPRESS: a piece of the street shrinks into a marble in his hand
	setRaycast(function(_, origin, dir)
		if dir.Y >= 0 or origin.Y + dir.Y > 0 then
			return nil
		end
		local t = origin.Y / -dir.Y
		local p = origin + dir * t
		return { Position = Vector3.new(p.X, 0, p.Z), Normal = Vector3.new(0, 1, 0), Distance = (p - origin).Magnitude, Instance = workspace, Material = Enum.Material.Asphalt }
	end)
	VFX.Play("CompressTake", myChar, { Pos = Vector3.new(0, 0, -8), Radius = 5, Color = Color3.fromRGB(123, 111, 99), Material = Enum.Material.Brick, Dir = FWD }, true)
	task.wait(0.03)
	local chunk = fresh(brick)
	if #chunk < 4 then
		problem("COMPRESS: the piece of the street, in the street's own brick (" .. #chunk .. " pieces)")
	end
	task.wait(0.5)
	if #fresh(glassBall) < 1 then
		problem("...shrinks into a glass marble in his hand")
	end
	local left = 0
	for _, p in chunk do
		if p.Parent and p.Transparency < 0.9 and p.Size.X > 0.2 then
			left += 1
		end
	end
	if left > 0 then
		problem("...and the piece is gone, into it (" .. left .. " left)")
	end
	task.wait(0.5)
	mark()

	-- VANISHING ACT: they're gone (a marble in his hand), then popped back out
	VFX.Play("VanishingGrab", myChar, { Target = target, Dir = FWD, Held = 0.8 }, true)
	task.wait(0.3)
	if troot.LocalTransparencyModifier < 0.9 then
		problem("VANISHING ACT: their body's gone - THEY'RE the marble")
	end
	if #fresh(glassBall) < 1 then
		problem("...a marble in his hand")
	end
	VFX.Play("VanishingPop", myChar, { Target = target, Pos = Vector3.new(0, 3, -25), Dir = FWD }, true)
	task.wait(0.15)
	if troot.LocalTransparencyModifier > 0.1 then
		problem("...popped back out: the body's back")
	end
	task.wait(1)
	mark()

	-- RUBBLE THROW: the marble pops into a lump of the city on its way down
	VFX.Play("RubbleLob", myChar, { From = Vector3.new(0, 5, 0), Vel = Vector3.new(0, 20, -50), Gravity = 196.2, Land = Vector3.new(0, 0, -20), LandTime = 0.5, Big = true, Color = Color3.fromRGB(123, 111, 99), Material = Enum.Material.Brick }, true)
	task.wait(0.35)
	chunk = fresh(brick)
	if #chunk < 4 then
		problem("RUBBLE THROW: the marble pops into a lump of the street in mid-air (" .. #chunk .. " pieces)")
	end
	task.wait(0.9)
	mark()

	-- MAGICIAN'S CHOICE: he's gone, then back over there
	VFX.Play("MagiciansFly", myChar, { From = Vector3.new(0, 3, 0), To = Vector3.new(0, 3, -20), Time = 0.25, Dir = FWD }, true)
	task.wait(0.1)
	if root.LocalTransparencyModifier < 0.9 then
		problem("MAGICIAN'S CHOICE: he's the marble - gone in a puff of smoke")
	end
	task.wait(0.4)
	if root.LocalTransparencyModifier > 0.1 then
		problem("...and back")
	end
	VFX.Play("MagiciansPop", myChar, { Pos = Vector3.new(0, 3, -20), Dir = FWD }, true)
	task.wait(0.6)
	VFX.ReleasePose(myChar, 0)
	mark()

	-- 1,300,000 VOLTS: lightning everywhere
	VFX.Play("IndiscriminateBoom", myChar, { Radius = 34 }, true)
	task.wait(0.55)
	bolts = fresh(neon)
	if #bolts < 60 then
		problem("1,300,000 VOLTS: lightning everywhere (" .. #bolts .. " pieces)")
	end
	task.wait(1)
	target.Parent = nil
	setRaycast(nil)
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.3)
end)
if not ok44 then
	problem("round 44 client scenario crashed: " .. tostring(err44))
end
print("== round 45: a swapped-in body's Animate restarted; Kamui's Great Slingshot plays")
local ok45, err45 = pcall(function()
	r.implementMethod("Animator", "GetPlayingAnimationTracks", function()
		local out = {}
		for _, t in tracks do
			if t.Track.IsPlaying then
				table.insert(out, t.Track)
			end
		end
		return out
	end)
	-- a body the server built and handed over, its Animate never started, a
	-- clip left over on its Animator
	local body, bodyHum = makeR15(localPlayer.Name, Vector3.new(0, 3, 0))
	local animate = Instance.new("LocalScript")
	animate.Name = "Animate"
	animate.Parent = body
	local animator = bodyHum:FindFirstChildOfClass("Animator")
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://1"
	local stale = animator and animator:LoadAnimation(anim)
	if stale then
		stale:Play()
	end
	body:SetAttribute("ClassicJoints", true)
	localPlayer.Character = body
	localPlayer.CharacterAdded:Fire(body)
	task.wait(0.6)
	local now = body:FindFirstChild("Animate")
	if not (now and now ~= animate and now:GetAttribute("Restarted")) then
		problem("ANIMATE: a body handed over by the server gets a fresh Animate started on your side")
	elseif animate.Parent == body then
		problem("...the one that never started is taken out")
	end
	if stale and stale.IsPlaying then
		problem("...and anything left playing on the body is stopped first")
	end
	localPlayer.Character = myChar
	localPlayer.CharacterAdded:Fire(myChar)
	task.wait(0.1)
	body:Destroy()
	-- Kamui's ult slingshot: the same opening as the Timber Slingshot
	local seen = {}
	for _, d in VFX.Folder:GetDescendants() do
		seen[d] = true
	end
	VFX.Play("GreatSlingshot", myChar, { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 3, -20) }, true)
	task.wait(0.3)
	local wood = 0
	for _, d in VFX.Folder:GetDescendants() do
		if not seen[d] and d:IsA("BasePart") and d.Material == Enum.Material.Wood then
			wood += 1
		end
	end
	if wood < 4 then
		problem("GREAT TIMBER SLINGSHOT: the branch shoots out of his arm (it used to do nothing at all) (" .. wood .. ")")
	end
	task.wait(1)
	VFX.ReleasePose(myChar, 0)
end)
if not ok45 then
	problem("round 45 client scenario crashed: " .. tostring(err45))
end
print("== round 46: the blitz's catch (upside down, pops and stars), the Sky Coffin's gates and barrier")
local ok46, err46 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	mark()
	local FWD = Vector3.new(0, 0, -1)
	local ES = Config.Quirks.Explosion.Ult.Extra
	local target = Instance.new("Model")
	local troot = Instance.new("Part")
	troot.Name = "HumanoidRootPart"
	troot.CFrame = r.CFrame.new(0, 3, -3)
	troot.Position = Vector3.new(0, 3, -3)
	troot.Parent = target
	target.Parent = workspace

	-- (round 63) FULL-BODY CLUSTER's hits: little explosions popping off
	-- him, stars of light thrown off the blasts
	mark()
	VFX.Play("FullBodyClusterHit", myChar, { Pos = Vector3.new(2, 3, -4), At = Vector3.new(0, 3.5, -3), Target = target, Level = 3, Of = ES.Hits }, true)
	task.wait(0.2)
	local pops = fresh(function(d)
		return d:IsA("BasePart") and d.Shape == Enum.PartType.Ball and d.Material == Enum.Material.Neon
	end)
	local stars = fresh(function(d)
		return d:IsA("TextLabel") and d.Text == "\u{2605}"
	end)
	if #pops < 5 then
		problem("FULL-BODY CLUSTER: explosions going off all over him (" .. #pops .. ")")
	end
	if #stars < 3 then
		problem("...stars of light thrown off them (" .. #stars .. ")")
	end
	VFX.Play("FullBodyClusterCancel", myChar, {}, true)
	task.wait(1)
	VFX.ReleasePose(myChar, 0)
	mark()

	-- the Sky Coffin's gates: the mist at both ends, and where you are
	local called
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called = text
	end
	VFX.Play("SkyWarp", myChar, { From = Vector3.new(0, 3, 0), To = Vector3.new(0, 603, 0), Up = true }, false)
	task.wait(0.3)
	VFX.Hooks.Callout = realCallout
	local into = #fresh(function(d)
		return d:IsA("BasePart")
	end)
	mark()
	-- (out of the other one: sent once they're there - here, the camera's spot)
	VFX.Play("SkyWarpOut", myChar, { To = Vector3.new(20, 3, 0) }, false)
	task.wait(0.2)
	local outOf = #fresh(function(d)
		return d:IsA("BasePart") and d.CFrame.Position.X > 10
	end)
	if into < 3 or outOf < 3 then
		problem(string.format("SKY WARP: Kurogiri's mist at the gate you walk into and the one you come out of (%d, %d)", into, outOf))
	end
	if called ~= "THE SKY COFFIN" then
		problem("...and it tells you where you are (" .. tostring(called) .. ")")
	end
	task.wait(1)
	mark()

	-- the barrier's jolt: gold lightning crawling over its face
	VFX.Play("BarrierZap", nil, { Pos = Vector3.new(0, 4, -10), Normal = Vector3.new(0, 0, 1) }, false)
	task.wait(0.05)
	local bolts = fresh(function(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.Neon
	end)
	-- (the lightning crawls out across the barrier's face, the plane z = -10)
	local across = 0
	for _, b in bolts do
		local p = b.CFrame.Position
		if math.abs(p.Z + 10) < 1.2 and Vector3.new(p.X, p.Y - 4, 0).Magnitude > 3 then
			across += 1
		end
	end
	if #bolts < 12 then
		problem("BARRIER: a burst of gold lightning where you touched it (" .. #bolts .. ")")
	elseif across < 8 then
		problem("...crawling out across its face (" .. across .. " pieces)")
	end
	task.wait(0.5)
	target.Parent = nil
	ticking = false
	task.wait(0.2)
end)
if not ok46 then
	problem("round 46 client scenario crashed: " .. tostring(err46))
end
print("== round 48: the Sky Coffin's plates, the ride, Best Jeanist's fibers; Iida's muffler nuke")
local ok48, err48 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local seen = {}
	local function mark()
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
	end
	local function fresh(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not seen[d] and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function named(n)
		return function(d)
			return d:IsA("BasePart") and d.Name == n
		end
	end
	mark()
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end

	-- THE PLATES (the island moved to the camera for the test)
	local SC = Config.SkyCoffin
	local realCenter = SC.Center
	SC.Center = Vector3.new(0, 0, 0)
	VFX.Play("SkyTiles", nil, { Tiles = { { 0, -2 }, { 1, -2 }, { -1, -2 }, { 0, -3 } }, From = Vector3.new(6, 0, -18) }, false)
	task.wait(0.15)
	local plates = fresh(named("Plate"))
	if #plates < 4 then
		problem("SKY COFFIN vs DECAY: each plate the decay reaches greys over (" .. #plates .. " of 4)")
	end
	task.wait(0.35)
	local sockets = fresh(named("Socket"))
	local flown = 0
	for _, p in plates do
		if p.CFrame.Position.Y > 30 then
			flown += 1
		end
	end
	if #sockets < 4 or flown < 4 then
		problem(string.format("...then it's fired off into the sky (%d up), leaving its socket (%d)", flown, #sockets))
	end
	-- (round 49: Best Jeanist stitches the holes shut now - see round 49)
	task.wait(3)
	local left = 0
	for _, d in fresh(function(d)
		-- (still showing: the harness's Debris never removes anything, so faded ones stay parented here)
		return d:IsA("BasePart") and (d.Name == "Plate" or d.Name == "Socket" or d.Name == "Spare") and d.Parent ~= nil and d.Transparency < 0.95
	end) do
		left += 1
	end
	if left > 0 then
		problem("...and it all clears up after (" .. left .. " left)")
	end
	SC.Center = realCenter
	mark()

	-- (round 49: Total Decay no longer takes him up into the barrier)
	local root = myChar.HumanoidRootPart
	-- IIDA'S PRANK
	VFX.Play("MufflerNuke", myChar, {}, true)
	task.wait(0.1)
	local bubble = false
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "EVERYONE, PLEASE STAND BACK!!" then
			bubble = true
		end
	end
	if not bubble then
		problem("MUFFLER NUKE: the class rep asks everyone to please stand back")
	end
	if #fresh(named("Muffler")) < 1 then
		problem("...a muffler out of his calf")
	end
	if not called["MUFFLER... NUKE?!"] then
		problem("...(and his screen names it)")
	end
	task.wait(0.4)
	mark()
	local target = Instance.new("Model")
	local troot = Instance.new("Part")
	troot.Name = "HumanoidRootPart"
	troot.CFrame = r.CFrame.new(0, 3, -40)
	troot.Position = Vector3.new(0, 3, -40)
	troot.Parent = target
	target.Parent = workspace
	VFX.Play("MufflerThrow", myChar, { From = Vector3.new(0, 4.5, -2), Target = target, To = Vector3.new(0, 3, -40), Speed = 150 }, false)
	task.wait(0.12)
	local thrown = fresh(named("Muffler"))
	if #thrown < 1 or thrown[1].CFrame.Position.Z > -5 then
		problem("...lobbed at them, tumbling (" .. (thrown[1] and string.format("%.1f", thrown[1].CFrame.Position.Z) or "none") .. ")")
	end
	mark()
	VFX.Play("MufflerBoom", myChar, { Pos = Vector3.new(0, 3, -40), Radius = 200, WaveSpeed = 480 }, false)
	task.wait(0.3)
	if thrown[1] and thrown[1].Parent then
		problem("...the muffler's gone when it hits")
	end
	if #fresh(function(d)
		return d:IsA("BasePart")
	end) < 30 then
		problem("...IT'S A NUKE")
	end
	task.wait(3)
	target.Parent = nil
	VFX.Hooks.Callout = realCallout
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.2)
end)
if not ok48 then
	problem("round 48 client scenario crashed: " .. tostring(err48))
end
print("== round 49: Best Jeanist stitches the Sky Coffin; All Might vs All For One in the sky; Fa Jin in the legs; Gearshift")
local ok49, err49 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end
	local function find(name)
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name and d.Parent then
				return d
			end
		end
		return nil
	end
	local function count(filter)
		local n = 0
		for _, d in VFX.Folder:GetDescendants() do
			if d:IsA("BasePart") and d.Parent and d.Transparency < 0.95 and filter(d) then
				n += 1
			end
		end
		return n
	end
	local function says(model, text)
		for _, d in model:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == text then
				return true
			end
		end
		return false
	end

	-- BEST JEANIST (the island moved to the camera for the test)
	local SC = Config.SkyCoffin
	local realCenter = SC.Center
	SC.Center = Vector3.new(0, 0, 0)
	local tiles = { { 0, -2 }, { 1, -2 }, { -1, -2 }, { 0, -3 }, { 1, -3 } }
	VFX.Play("SkyTiles", nil, { Tiles = tiles, From = Vector3.new(6, 0, -24), Reach = 20 }, false)
	task.wait(0.4)
	local jeanist = find("BestJeanist")
	if not jeanist then
		problem("SKY COFFIN vs DECAY: Best Jeanist comes down out of the sky to the holes")
	end
	task.wait(0.6)
	if jeanist and not says(jeanist, "FIBER MASTER!") then
		problem("...\"FIBER MASTER!\" as he lands")
	end
	local head = jeanist and jeanist:FindFirstChildWhichIsA("BasePart")
	local landedY = head and head.CFrame.Position.Y or 999
	if landedY > 8 then
		problem(string.format("...standing on the island (%.1f up)", landedY))
	end
	task.wait(0.35)
	local fibers = count(function(d)
		return d.Material == Enum.Material.Fabric and d.Size.X < 0.2 and d.Size.Z > 4
	end)
	if fibers < #tiles then
		problem("...a fiber from his fingers to every hole (" .. fibers .. " for " .. #tiles .. ")")
	end
	task.wait(3.6)
	if find("BestJeanist") then
		problem("...and when they're all mended, he's gone again")
	end
	local sockets = count(function(d)
		return d.Name == "Socket"
	end)
	if sockets > 0 then
		problem("...every hole stitched shut (" .. sockets .. " left)")
	end
	SC.Center = realCenter

	-- ALL MIGHT vs ALL FOR ONE
	VFX.Play("SkyBattle", nil, { Seed = 3, Length = 6 }, false)
	task.wait(0.4)
	local am, afo = find("AllMight"), find("AllForOne")
	if not am or not afo then
		problem("SKY BATTLE: All Might and All For One, up in the sky")
	end
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not (gui and gui:FindFirstChild("SkyBattleBanner")) then
		problem("...and a banner: look up!")
	end
	local cam = workspace.CurrentCamera
	local amPart = am and am:FindFirstChildWhichIsA("BasePart")
	local p0 = amPart and amPart.CFrame.Position
	if p0 then
		local base = (VFX.AB and VFX.AB.run and VFX.AB.run.base) or cam.Focus.Position
		local flat = Vector3.new(p0.X - base.X, 0, p0.Z - base.Z).Magnitude
		if p0.Y < base.Y + 80 or flat < 150 or flat > 760 then
			problem(string.format("...off in the sky over where you are (%.0f up, %.0f away)", p0.Y - base.Y, flat))
			local run = VFX.AB and VFX.AB.run
			print("  sky debug:", p0, base, cam.Focus.Position, run and (os.clock() - run.t0), run and run.amAt, run and run.S, am and am:GetFullName(), amPart and amPart.Name)
		end
	end
	task.wait(1.5)
	local p1 = amPart and amPart.CFrame.Position
	if p0 and p1 and (p1 - p0).Magnitude < 20 then
		problem("...flying at each other")
	end
	VFX.Play("SkyBattle", nil, { Seed = 4, Length = 6 }, false)
	task.wait(0.2)
	local nAM = 0
	for _, d in VFX.Folder:GetChildren() do
		if d.Name == "AllMight" then
			nAM += 1
		end
	end
	if nAM ~= 1 then
		problem("...(a new one replaces the old one: " .. nAM .. " All Mights)")
	end
	task.wait(6.6)
	if find("AllMight") or find("AllForOne") or game:GetService("Lighting"):FindFirstChild("SkyBattle") then
		problem("...and it's all gone when it's over")
	end

	-- FA JIN: the squats, the legs, the launch
	local root = myChar.HumanoidRootPart
	VFX.Play("FaJinSmash", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(1.4)
	local rootY = root.CFrame.Position.Y
	local legVeins, armVeins = 0, 0
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Vein" and d.Transparency < 0.95 then
			if d.CFrame.Position.Y < rootY - 1 then
				legVeins += 1
			else
				armVeins += 1
			end
		end
	end
	if legVeins < 6 or armVeins > legVeins / 4 then
		problem(string.format("FA JIN: the red veins climb his legs as he squats (%d on the legs, %d above)", legVeins, armVeins))
	end
	VFX.Play("FaJinSmashRelease", myChar, { Level = 3, Power = 1, Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.05)
	local lv
	for _, c in root:GetChildren() do
		-- (the harness never clears old ones away: the fastest is his launch)
		if c:IsA("LinearVelocity") and (not lv or c.VectorVelocity.Magnitude > lv.VectorVelocity.Magnitude) then
			lv = c
		end
	end
	if not lv or lv.VectorVelocity.Magnitude < 150 or lv.VectorVelocity.Z > -100 then
		problem("...let go: it all goes out through his legs and he rockets forward (" .. tostring(lv and math.floor(lv.VectorVelocity.Magnitude)) .. ")")
	end
	task.wait(1)

	-- GEARSHIFT
	local before = count(function(d)
		return d.Material == Enum.Material.Neon
	end)
	myChar:SetAttribute("Gearshift", 2)
	task.wait(0.2)
	local cogs = count(function(d)
		return d.Material == Enum.Material.Neon
	end) - before
	if cogs < 48 then
		problem("GEARSHIFT: a cog of light spinning round each fist and ankle (" .. cogs .. ")")
	end
	myChar:SetAttribute("Gearshift", nil)
	task.wait(0.3)
	VFX.Play("Gearshift", myChar, {}, true)
	task.wait(0.1)
	if not called["LOW GEAR"] then
		problem("...each press: the next gear (LOW GEAR first)")
	end
	myChar:SetAttribute("Gearshift", 4)
	VFX.Play("Gearshift", myChar, {}, true)
	task.wait(0.1)
	myChar:SetAttribute("Gearshift", nil)
	VFX.Play("GearshiftHit", myChar, { Pos = root.CFrame.Position + Vector3.new(0, 1, -5), N = 10, Hits = 9, Dir = Vector3.new(0, 0, -1), Final = true }, false)
	task.wait(0.1)
	if not called["DETROIT SMASH!!"] then
		problem("...and the last punch is a Detroit Smash")
	end
	task.wait(0.5)

	VFX.Hooks.Callout = realCallout
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.2)
end)
if not ok49 then
	problem("round 49 client scenario crashed: " .. tostring(err49))
end
print("== round 50: phone buttons; a real R6 crouch; Deku's new moves")
local ok50, err50 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end

	-- PHONE: our own round buttons, not Roblox's
	for name, touch in touchButtons do
		if touch == true then
			problem("PHONE: Roblox's own touch button for " .. name .. " (the HUD draws them now)")
		end
	end
	HUD.ShowMenu(false)
	HUD.SetInputMode("Touch")
	task.wait(0.1)
	local pad = hudGui:FindFirstChild("TouchPad")
	if not (pad and pad.Visible) then
		problem("PHONE: the touch buttons come up in touch mode")
	end
	local function btn(label)
		return pad and pad:FindFirstChild("Touch" .. label)
	end
	for _, label in { "HIT", "BLOCK", "RUN", "ULT", "EMOTE", "LOCK", "FINISH" } do
		if not btn(label) then
			problem("...a " .. label .. " button")
		end
	end
	local moved = 0
	for _, c in (pad and pad:GetChildren() or {}) do
		if c.Name:sub(1, 4) == "Slot" and c:FindFirstChild("Tap") then
			moved += 1
		end
	end
	if moved < 5 then
		problem("...the move boxes turn into round buttons round the jump button (" .. moved .. ")")
	end
	local bar = hudGui:FindFirstChild("Abilities", true)
	if bar and bar.Visible then
		problem("...and the keyboard's row of boxes is gone")
	end
	if btn("FINISH") and btn("FINISH").Visible then
		problem("...FINISH only shows up when there's someone to finish")
	end
	-- a finger on it and off it
	local function press(button)
		local changed = Instance.new("BindableEvent")
		local finger = { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin }
		function finger:GetPropertyChangedSignal()
			return changed.Event
		end
		signalOf(button, "InputBegan"):Fire(finger)
		return function()
			finger.UserInputState = Enum.UserInputState.End
			signalOf(changed, "Event"):Fire()
		end
	end
	localPlayer:SetAttribute("Quirk", "Explosion")
	task.wait(1)
	table.clear(fired)
	local lift = press(btn("HIT"))
	task.wait(0.05)
	lift()
	local hitSent = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == 0 then
			hitSent = true
		end
	end
	if not hitSent then
		problem("...HIT punches")
	end
	task.wait(1.2)
	table.clear(fired)
	lift = press(btn("BLOCK"))
	task.wait(0.05)
	local up, down = false, false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.BLOCK_INDEX and f[3] == true then
			up = true
		end
	end
	lift()
	task.wait(0.05)
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.BLOCK_INDEX and f[3] == false then
			down = true
		end
	end
	if not (up and down) then
		problem("...hold BLOCK to guard, let go to drop it")
	end
	local runColor = btn("RUN") and btn("RUN").BackgroundColor3
	lift = press(btn("RUN"))
	lift()
	if btn("RUN") and btn("RUN").BackgroundColor3 == runColor then
		problem("...RUN is a switch, and shows when it's on")
	end
	lift = press(btn("RUN"))
	lift()
	HUD.ShowMenu(true)
	if pad and pad.Visible then
		problem("...the buttons step aside for the quirk menu")
	end
	HUD.ShowMenu(false)
	if pad and not pad.Visible then
		problem("...and come back when it closes")
	end
	HUD.SetInputMode("Keyboard")
	task.wait(0.1)
	if pad and pad.Visible then
		problem("...back on a keyboard: no touch buttons")
	end
	local backInBar = 0
	for _, c in (bar and bar:GetChildren() or {}) do
		if c.Name:sub(1, 4) == "Slot" then
			backInBar += 1
		end
	end
	if not bar or not bar.Visible or backInBar < 5 then
		problem("...and the move boxes back in their row (" .. backInBar .. ")")
	end

	-- A REAL CROUCH: on R6 the whole body goes down, not just the legs
	-- (a fresh R6 with Roblox's own RootJoint: X left, Y back, Z up)
	local squatter = makeR6("R6Squat", Vector3.new(24, 3, 0))
	for _, n in { "Right Leg", "Left Leg" } do
		squatter[n].Size = Vector3.new(1, 2, 1) -- (a real R6 leg)
	end
	local rj = squatter.HumanoidRootPart:FindFirstChild("RootJoint")
	rj.C0 = r.CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	rj.C1 = r.CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local function torsoY()
		return (rj.C0 * rj.C1:Inverse()).Position.Y
	end
	local stand = torsoY()
	local low = stand
	VFX.Motion(squatter, "FaJinSquat1")
	local t0 = os.clock()
	while os.clock() - t0 < 1 do
		low = math.min(low, torsoY())
		task.wait()
	end
	if stand - low < 1.2 then
		problem(string.format("CROUCH: Deku's squat takes his whole body down on R6 (%.2f studs)", stand - low))
	end
	squatter.Parent = nil

	-- DEKU
	local root = myChar.HumanoidRootPart
	local Delaware = Config.FindAbilityById("DelawareSmash")
	VFX.Play("DelawareSmash", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	local shots = 0
	local seen = {}
	t0 = os.clock()
	while os.clock() - t0 < 0.8 do
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == "DelawarePressure" and not seen[d] then
				seen[d] = true
				shots += 1
			end
		end
		task.wait()
	end
	if shots < (Delaware.Shots or 3) then
		problem("DELAWARE SMASH: AIR FORCE - a flick from each hand, one after another (" .. shots .. ")")
	end
	VFX.Play("DangerSense", myChar, { From = root.CFrame.Position + Vector3.new(0, 0, 8) }, false)
	task.wait(0.1)
	if not called["DANGER SENSE!"] then
		problem("DANGER SENSE: warns him (\"DANGER SENSE!\")")
	end
	VFX.Play("TransmissionRush", myChar, { Target = r6 }, true)
	for n = 1, 5 do
		VFX.Play("GearshiftHit", myChar, { Pos = root.CFrame.Position + Vector3.new(0, 1, -5), N = n, Hits = 8, Dir = Vector3.new(0, 0, -1) }, false)
		task.wait(0.05)
	end
	VFX.Play("GearshiftHit", myChar, { Pos = root.CFrame.Position + Vector3.new(0, 1, -5), N = 9, Hits = 8, Dir = Vector3.new(0, 0, -1), Quintuple = 1 }, false)
	task.wait(0.1)
	if not called["TRANSMISSION!!"] or not called["DETROIT SMASH: QUINTUPLE!!"] then
		problem("TRANSMISSION: the callout, then DETROIT SMASH: QUINTUPLE")
	end
	VFX.Play("GearedDown", r6, { Time = 1 }, false)
	task.wait(0.1)
	if not r6:FindFirstChildOfClass("Highlight") then
		problem("...and whoever eats it is geared down (a blue glow)")
	end
	task.wait(1.2)

	VFX.Hooks.Callout = realCallout
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.2)
end)
if not ok50 then
	problem("round 50 client scenario crashed: " .. tostring(err50))
end
print("== round 51: Chargebolt's lightning and zap traps; Deku's 100% (purple arms); Deku drops in")
local ok51, err51 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end
	local DK = VFX.DK
	local function lit(filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if d:IsA("BasePart") and d.Parent and d.Transparency < 0.95 and filter(d) then
				table.insert(out, d)
			end
		end
		return out
	end

	-- THE NEW LIGHTNING: a white core in a glow, forks, re-striking
	local function onBolt(d)
		local p = d.CFrame.Position
		return d.Material == Enum.Material.Neon and p.Y > 12 and p.Y < 28 and p.X > -4 and p.X < 34 and math.abs(p.Z - 300) < 10
	end
	DK.zig(Vector3.new(0, 20, 300), Vector3.new(30, 20, 300), DK.YELLOW, 0.45, 0.4, 0.8)
	task.wait(0.03)
	local first = lit(onBolt)
	local whites, glows = 0, 0
	for _, d in first do
		if d.Color.R > 0.99 and d.Color.G > 0.99 and d.Color.B > 0.99 then
			whites += 1
		else
			glows += 1
		end
	end
	if #first < 30 or whites < 10 or glows < 10 then
		problem(string.format("CHARGEBOLT's lightning: a white-hot core in a glow, with forks (%d parts: %d core, %d glow)", #first, whites, glows))
	end
	local was = {}
	for _, d in first do
		was[d] = d.CFrame.Position
	end
	task.wait(0.14)
	local moved = 0
	for d, p in was do
		if d.Parent and (d.CFrame.Position - p).Magnitude > 0.05 then
			moved += 1
		end
	end
	if moved < 5 then
		problem("...it re-strikes along a new path before it fades (" .. moved .. " moved)")
	end
	task.wait(0.6)
	if #lit(onBolt) > 0 then
		problem("...and then it's gone")
	end

	-- ZAP TRAP
	local root = myChar.HumanoidRootPart
	local trapAt = root.CFrame.Position + Vector3.new(6, -3, 6)
	VFX.Play("ZapTrapSet", myChar, { Id = 7701, Pos = trapAt, Arm = 0.3, Life = 4 }, false)
	task.wait(0.6)
	local rec = DK.traps[7701]
	if not rec or not rec.armed then
		problem("ZAP TRAP: tossed onto the street, and it arms")
	end
	local near = lit(function(d)
		return (d.CFrame.Position - trapAt).Magnitude < 3
	end)
	if #near < 15 then
		problem("...a real little device: disc, hazard ring, prongs, coil, lamp (" .. #near .. " parts)")
	end
	local r6root = r6:FindFirstChild("HumanoidRootPart")
	VFX.Play("ZapTrapSnap", nil, { Id = 7701, Pos = trapAt, Targets = { r6 } }, false)
	task.wait(0.1)
	if DK.traps[7701] then
		problem("...stepped on: it goes up through them and it's spent")
	end
	VFX.Play("ZapTrapSet", myChar, { Id = 7702, Pos = trapAt, Arm = 0.1, Life = 4, WireTo = r6 }, false)
	task.wait(0.4)
	rec = DK.traps[7702]
	if not rec or rec.wireTo ~= r6 then
		problem("...set near a pointer: a live wire to it")
	end
	VFX.Play("ZapTrapWireJolt", nil, { Id = 7702, Target = r6 }, false)
	VFX.Play("ZapTrapWireCut", nil, { Id = 7702 }, false)
	VFX.Play("ZapTrapOverload", nil, { Id = 7702, Pos = trapAt, Radius = 14 }, false)
	task.wait(0.1)
	if DK.traps[7702] then
		problem("...a Stun Bolt into it: it overloads")
	end
	VFX.Play("StunBoltHit", myChar, { Points = { root.CFrame.Position, root.CFrame.Position + Vector3.new(0, 0, 20), r6root.CFrame.Position, r6root.CFrame.Position + Vector3.new(8, 0, 0) }, Hit = true, Relay = 2 }, false)
	VFX.Play("ThunderDive", myChar, { From = root.CFrame.Position + Vector3.new(0, 30, 0), To = root.CFrame.Position, Time = 0.2 }, false)
	VFX.Play("DischargeBurst", myChar, { Radius = 16, Air = true }, false)
	task.wait(0.8)

	-- DEKU: 100% - the arm goes purple
	VFX.Play("HundredSmash", myChar, { Dir = Vector3.new(0, 0, -1) }, true, Config.FindAbilityById("HundredSmash"))
	task.wait(0.4)
	if not called["ONE FOR ALL... 100%!!"] then
		problem("100% DETROIT SMASH: \"ONE FOR ALL... 100%!!\"")
	end
	local veins = lit(function(d)
		return d.Name == "Vein"
	end)
	if #veins < 6 then
		problem("...the veins up the arm as it gathers (" .. #veins .. ")")
	end
	VFX.Play("HundredSmashBlast", myChar, { Dir = Vector3.new(0, 0, -1), Side = "R", Range = 100, Width = 26 }, false)
	task.wait(0.3)
	if not called["DETROIT SMASH!!"] then
		problem("...\"DETROIT SMASH!!\"")
	end
	myChar:SetAttribute("BrokenArmR", workspace:GetServerTimeNow() + 30)
	task.wait(0.5)
	local bruise = myChar:FindFirstChild("OFABruiseR")
	local purple, welded = 0, 0
	for _, d in bruise and bruise:GetDescendants() or {} do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Color.B > d.Color.G + 0.1 then
			purple += 1
		elseif d:IsA("WeldConstraint") then
			welded += 1
		end
	end
	if purple < 3 or welded < 3 then
		problem(string.format("THE ARM BREAKS: his right arm goes purple, black at the hand (%d purple pieces, %d welded on)", purple, welded))
	end
	if myChar:FindFirstChild("OFABruiseL") then
		problem("...only the arm that threw it")
	end
	myChar:SetAttribute("BrokenArmR", nil)
	task.wait(0.5)
	local left = 0
	for _, d in bruise and bruise:GetDescendants() or {} do
		if d:IsA("BasePart") and d.Transparency < 1 then
			left += 1
		end
	end
	if left > 0 then
		problem("...healed: the bruise fades away")
	end

	-- DEKU DROPS IN (the real timings)
	local DDC = Config.DekuDrop
	local ground = Vector3.new(200, 0, 260)
	VFX.Play("DekuDrop", nil, { Pos = ground, Seed = 5, Impact = DDC.ImpactAt, Jump = DDC.JumpAt, Length = DDC.Length }, false)
	local t0 = os.clock()
	local function dekuY()
		local deku = VFX.Folder:FindFirstChild("Deku")
		local part = deku and deku:FindFirstChildWhichIsA("BasePart")
		return part and part.CFrame.Position.Y or nil
	end
	local function at(t)
		while os.clock() - t0 < t do
			task.wait(0.02)
		end
		return dekuY()
	end
	local y = at(DDC.ImpactAt * 0.4)
	if not y or y < 60 then
		problem("DEKU DROPS IN: coming down out of the sky (" .. tostring(y and math.floor(y)) .. ")")
	end
	y = at(DDC.ImpactAt + 0.4)
	if not y or y > 4 then
		problem(string.format("...landed, down on one knee (%s)", tostring(y)))
	end
	y = at(DDC.ImpactAt + 3)
	local standing = y
	if not y or y < 3.5 or y > 5 then
		problem(string.format("...up on his feet (%s)", tostring(y)))
	end
	y = at(DDC.JumpAt - 0.3)
	if not y or not standing or y > standing - 1 then
		problem(string.format("...crouched to jump (%s, standing %s)", tostring(y), tostring(standing)))
	end
	y = at(DDC.JumpAt + 0.6)
	if not y or y < 150 then
		problem("...and blasted back up into the sky (" .. tostring(y and math.floor(y)) .. ")")
	end
	at(DDC.Length + 0.3)
	if VFX.Folder:FindFirstChild("Deku") then
		problem("...gone when it's over")
	end

	VFX.Hooks.Callout = realCallout
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.2)
end)
if not ok51 then
	problem("round 51 client scenario crashed: " .. tostring(err51))
end
print("== round 52: the fire model (BLAZE); Endeavor and Dabi; blood; Deku's broken arm")
local ok52, err52 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end
	-- a street at y = 0
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			return { Position = origin + dir * t, Normal = Vector3.new(0, 1, 0), Instance = workspace.Terrain, Distance = dir.Magnitude * t, Material = Enum.Material.Concrete }
		end
		return nil
	end)
	local B = VFX.BLAZE
	local function count(filter)
		local n = 0
		for _, d in VFX.Folder:GetDescendants() do
			if filter(d) then
				n += 1
			end
		end
		return n
	end

	-- A FLAME: tongues of beams that lick (their tips wander), particles,
	-- a light; killed, it dies down and goes
	local f = B.flame({ CF = r.CFrame.new(40, 0, 40), Pal = "hell", Height = 6, Width = 3, Grow = 0.1 })
	task.wait(0.25)
	local beams = 0
	for _, d in f.holder:GetChildren() do
		if d:IsA("Beam") then
			beams += 1
		end
	end
	if #f.tongues < 3 or beams < #f.tongues * 6 then
		problem(string.format("BLAZE: a flame is tongues of layered beams (%d tongues, %d beams)", #f.tongues, beams))
	end
	local t1 = f.tongues[1]
	local tip1 = t1.a1.CFrame.Position
	task.wait(0.2)
	if (t1.a1.CFrame.Position - tip1).Magnitude < 0.02 then
		problem("...and they lick: the tips wander")
	end
	if t1.bodyA.Width1 <= t1.bodyA.Width0 or t1.bodyHi.Width0 >= t1.bodyLo.Width0 or t1.bodyHi.Width1 ~= 0 then
		problem("...a teardrop: widest at the belly, pointed at the tip")
	end
	if not f.holder:FindFirstChildOfClass("ParticleEmitter") or not f.holder:FindFirstChildOfClass("PointLight") then
		problem("...with the particles and a flickering light")
	end
	f.kill(0.1)
	task.wait(2.6)
	if f.holder.Parent or table.find(B.live, f) then
		problem("...killed: it dies down and it's gone")
	end

	-- A JET, a BURST, a PILLAR, THREADS, a FIST, a RING - blue too
	local j = B.jet({ From = Vector3.new(40, 4, 60), Dir = Vector3.new(1, 0, 0), Length = 30, Width = 8, Pal = "blue" })
	task.wait(0.2)
	if #j.layers < 4 or not j.head or #j.rolls < 3 then
		problem("BLAZE: a jet - layered beams, the fire rolling off it, the billow at the end")
	end
	j.stop(0.1)
	B.burst(Vector3.new(60, 4, 60), 4, { Pal = "hell" })
	B.pillar(Vector3.new(70, 0, 60), 20, 4, "blue", 0.5)
	local th = B.thread(Vector3.new(80, 4, 60), Vector3.new(80, 1, 90), "white", 0.3, 0.5)
	th.set(Vector3.new(80, 4, 60), Vector3.new(84, 1, 90))
	local fist = B.fist(r.CFrame.new(90, 5, 60), 5, "hell")
	fist.move(r.CFrame.new(90, 5, 70))
	if count(function(d)
		return d.Name == "BlazeFist"
	end) < 10 then
		problem("BLAZE: a fist of fire - knuckles, fingers, thumb, wrist")
	end
	fist.kill(0.1)
	B.ring(Vector3.new(100, 0, 60), 8, 5, "blue", 0.5)
	task.wait(0.8)

	-- ENDEAVOR: every move, on his screen and everyone else's
	myChar:SetAttribute("Quirk", "Hellflame")
	local root = myChar.HumanoidRootPart
	local EN = Config.Quirks.Hellflame
	for _, spec in {
		{ "HellSpider", EN.Abilities[1] }, { "JetBurn", EN.Abilities[2] }, { "VanishingFist", EN.Abilities[3] }, { "FlashfireJet", EN.Special },
		{ "HellsCurtain", EN.Extra }, { "HellSpiderWeb", EN.Ult.Abilities[1] }, { "VanishingJetBurn", EN.Ult.Abilities[2] }, { "ProminenceNova", EN.Ult.Abilities[3] },
		{ "SkyProminence", EN.Ult.Extra },
	} do
		VFX.Play(spec[1], myChar, { Dir = Vector3.new(0, 0, -1), Pos = root.Position + Vector3.new(0, 0, -20) }, true, spec[2])
		task.wait(0.15)
	end
	task.wait(1.2)
	-- (the harness's bodies don't place their limbs: put the dummy's arm
	-- where it hangs, and sweep its threads down across the street)
	local rArm = r6:FindFirstChild("Right Arm")
	rArm.CFrame = r6.HumanoidRootPart.CFrame * r.CFrame.new(1.5, 0, 0)
	VFX.HF.sweep(r6, r6.HumanoidRootPart, Vector3.new(0, 0, -1), 42, 40, 5, true, "white", 0.22)
	if count(function(d)
		return d.Name == "BlazeCut"
	end) == 0 then
		problem("HELL SPIDER: the threads cut glowing seams into the street")
	end
	VFX.Play("VanishingFistHit", myChar, { Target = r6, Dir = Vector3.new(0, 0, -1), At = root.Position + Vector3.new(0, 0, -5) }, false)
	VFX.Play("FlameFistFly", myChar, { From = root.Position, To = root.Position + Vector3.new(0, 0, -40), Time = 0.2, Pal = "hell", Scale = 8, Id = 77 }, false)
	task.wait(0.1)
	VFX.Play("FlameFistBoom", myChar, { Pos = root.Position + Vector3.new(0, 0, -40), Radius = 18, Pal = "hell", Id = 77 }, false)
	VFX.Play("ProminenceNovaBurst", myChar, { Pos = root.Position, Radius = 34, Heat = 0.5 }, false)
	VFX.Play("SkyProminenceRise", myChar, { Target = r6, From = root.Position, Top = root.Position + Vector3.new(0, 100, 0), Time = 0.3 }, false)
	task.wait(0.4)
	VFX.Play("SkyProminenceBurst", myChar, { Pos = root.Position + Vector3.new(0, 100, 0) }, false)
	VFX.Play("Overheat", myChar, { Time = 0.5 }, false)
	task.wait(0.3)
	if not called["PLUS ULTRA!!"] then
		problem("PLUS ULTRA: PROMINENCE BURN - \"PLUS ULTRA!!\"")
	end

	-- his costume of fire: every FireSpot on a look is lit, and goes out
	-- while his flames are out (Vanishing Fist)
	local gear = Instance.new("Model")
	gear.Name = "QuirkGear"
	local cos = Instance.new("Model")
	cos.Name = "Cosmetics"
	cos.Parent = gear
	local holder = Instance.new("Part")
	holder.Name = "FireSpots"
	holder.CFrame = root.CFrame
	holder.Parent = cos
	local spot = Instance.new("Attachment")
	spot.Name = "FireSpot"
	spot:SetAttribute("Height", 2)
	spot:SetAttribute("Width", 1)
	spot:SetAttribute("Pal", "hell")
	spot.Parent = holder
	gear.Parent = myChar
	task.wait(0.9)
	local HF = VFX.HF
	if not HF.spots[spot] then
		problem("ENDEAVOR's costume: the fire on his beard, brows, shoulders and boots is lit")
	end
	HF.out[myChar] = os.clock() + 1.5
	task.wait(0.9)
	if HF.spots[spot] then
		problem("...and goes out while his flames are out (Vanishing Fist)")
	end
	HF.out[myChar] = nil
	gear:Destroy()
	task.wait(0.5)

	-- DABI
	myChar:SetAttribute("Quirk", "Blueflame")
	local DB = Config.Quirks.Blueflame
	for _, spec in {
		{ "Cremation", DB.Abilities[1] }, { "HellMinefield", DB.Abilities[2] }, { "BlueSpider", DB.Abilities[3] }, { "BlueWall", DB.Special },
		{ "BlueJetBurn", DB.Extra }, { "BlueProminence", DB.Ult.Abilities[1] }, { "SekotoPeak", DB.Ult.Abilities[2] }, { "BlueVanishing", DB.Ult.Abilities[3] },
	} do
		VFX.Play(spec[1], myChar, { Dir = Vector3.new(0, 0, -1), Pos = root.Position + Vector3.new(0, 0, -25) }, true, spec[2])
		task.wait(0.15)
	end
	VFX.Play("CremationPatches", myChar, { Points = { root.Position + Vector3.new(0, -3, -10) }, Radius = 4, Life = 0.5 }, false)
	VFX.Play("MinefieldErupt", myChar, { Pos = root.Position + Vector3.new(0, -3, -20), Radius = 6.5 }, false)
	VFX.Play("BlueJetBurnHit", myChar, { Target = r6, Dir = Vector3.new(0, 0, -1), At = root.Position + Vector3.new(0, 0, -5) }, false)
	VFX.Play("Seared", myChar, { Amount = 3 }, false)
	VFX.Play("Burn", nil, { Target = r6, Duration = 0.6, Pal = "blue" }, false)
	task.wait(1.6)

	-- BLOOD: a hard hit sprays drops that land and splat; a light one
	-- doesn't; switched off, none
	local BL = VFX.BLOOD
	local function bloodCount()
		return count(function(d)
			return d.Name == "Blood"
		end)
	end
	local before = bloodCount()
	VFX.Play("Hit", nil, { Target = r6, Amount = 3, Attacker = localPlayer }, false)
	task.wait(0.05)
	if bloodCount() > before then
		problem("BLOOD: a light hit doesn't bleed")
	end
	VFX.Play("Hit", nil, { Target = r6, Amount = 22, Heavy = true, Attacker = localPlayer }, false)
	task.wait(0.05)
	local flying = #BL.drops
	if flying < 5 then
		problem("BLOOD: a hard hit sprays drops out of them (" .. flying .. ")")
	end
	task.wait(3)
	local stains = #BL.stains
	if stains < 3 or #BL.drops > 0 then
		problem(string.format("...they fly, fall and splat on the street (%d stains, %d still flying)", stains, #BL.drops))
	end
	VFX.Play("KO", nil, { Target = r6, Pos = r6.HumanoidRootPart.Position }, false)
	task.wait(1)
	BL.on = false
	local n0 = #BL.drops
	VFX.Play("Hit", nil, { Target = r6, Amount = 30, Heavy = true, Attacker = localPlayer }, false)
	task.wait(0.05)
	if #BL.drops > n0 then
		problem("BLOOD off in the settings: none")
	end
	BL.on = true

	-- DEKU's broken arm drips
	myChar:SetAttribute("Quirk", "FullCowl")
	local drips = 0
	local realDrip = BL.drip
	BL.drip = function(...)
		drips += 1
		return realDrip(...)
	end
	r6:SetAttribute("BrokenArmR", workspace:GetServerTimeNow() + 30)
	-- (the watcher looks at players' characters: borrow the local one's slot)
	myChar:SetAttribute("BrokenArmR", workspace:GetServerTimeNow() + 30)
	task.wait(3)
	BL.drip = realDrip
	myChar:SetAttribute("BrokenArmR", nil)
	r6:SetAttribute("BrokenArmR", nil)
	if drips == 0 then
		problem("DEKU: his broken arm drips blood")
	end

	-- the HEAT gauge on Endeavor's HUD
	myChar:SetAttribute("Heat", 64)
	signalOf(myChar, "attr:Heat"):Fire()
	task.wait(0.3)
	local heat = HUD.Heat
	if not heat or not heat.Bar.Visible or not string.find(heat.Text.Text, "HEAT 64") then
		problem("ENDEAVOR's HEAT gauge over his health bar (" .. tostring(heat and heat.Text.Text) .. ")")
	end
	myChar:SetAttribute("Overheated", true)
	signalOf(myChar, "attr:Overheated"):Fire()
	task.wait(0.2)
	if not heat or not string.find(heat.Text.Text, "OVERHEATED") then
		problem("...OVERHEATED at the top")
	end
	myChar:SetAttribute("Heat", nil)
	myChar:SetAttribute("Overheated", nil)
	signalOf(myChar, "attr:Heat"):Fire()
	task.wait(0.2)
	if heat and heat.Bar.Visible then
		problem("...and gone when he's someone else")
	end
	myChar:SetAttribute("Quirk", "Explosion")

	VFX.Hooks.Callout = realCallout
	setRaycast(nil)
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.3)
end)
if not ok52 then
	problem("round 52 client scenario crashed: " .. tostring(err52))
end
print("== round 53: Deku at 100% like the movies; the anime fire; Prominence Burn in black and white; more emotes")
do
local ok53, err53 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			return { Position = origin + dir * t, Normal = Vector3.new(0, 1, 0), Instance = workspace.Terrain, Distance = dir.Magnitude * t, Material = Enum.Material.Concrete }
		end
		return nil
	end)
	local cam = workspace.CurrentCamera
	local function look(at)
		pcall(function()
			cam.Focus = r.CFrame.new(at)
			cam.CFrame = r.CFrame.new(at + Vector3.new(0, 6, 16), at)
		end)
	end
	local function count(filter, root)
		local n = 0
		for _, d in (root or VFX.Folder):GetDescendants() do
			if filter(d) then
				n += 1
			end
		end
		return n
	end
	local function named(name)
		return count(function(d)
			return d.Name == name
		end)
	end
	local lighting = game:GetService("Lighting")
	local function mono()
		local cc = lighting:FindFirstChild("MangaMono")
		return cc ~= nil and cc.Enabled and cc.Saturation <= -0.99
	end
	local MG, B, D9, EM = VFX.MANGA, VFX.BLAZE, VFX.D9, VFX.EMOTES
	if not (MG and B and D9 and EM) then
		problem("round 53 modules: MANGA, BLAZE, D9, EMOTES")
		return
	end

	-- THE MANGA LANGUAGE: black and white, speed lines, a lens flare, the rainbow
	look(Vector3.new(0, 3, 0))
	MG.mono(0.12)
	if not mono() then
		problem("MANGA: the screen snaps to black and white")
	end
	task.wait(0.4)
	if lighting:FindFirstChild("MangaMono") and lighting.MangaMono.Enabled then
		problem("...and the colour comes back")
	end
	MG.lines(0.3, { Kind = "focus" })
	task.wait(0.05)
	local layer = playerGui:FindFirstChild("MangaFX")
	local lines = layer and layer:FindFirstChild("SpeedLines")
	if not lines or #lines:GetChildren() < 30 then
		problem("MANGA: focus lines rushing in from the edges (" .. tostring(lines and #lines:GetChildren()) .. ")")
	end
	task.wait(0.45)
	if layer and layer:FindFirstChild("SpeedLines") then
		problem("...gone after")
	end
	MG.lines(0.2, { Kind = "stream", Colors = { r.Color3.new(1, 0, 0), r.Color3.new(0, 1, 0) } })
	task.wait(0.05)
	lines = layer and layer:FindFirstChild("SpeedLines")
	local tilted = lines and lines:FindFirstChildOfClass("Frame")
	if not tilted or tilted.Rotation == 0 then
		problem("MANGA: colour streaming past at an angle")
	end
	local before = count(function(d)
		return d:IsA("BillboardGui")
	end)
	MG.flare(Vector3.new(0, 4, 0), r.Color3.new(0.4, 0.9, 1), 3, 0.3)
	MG.rainbow(Vector3.new(0, 4, 0), Vector3.new(0, 0, -1), 10, 0.3)
	task.wait(0.25)
	if count(function(d)
		return d:IsA("BillboardGui")
	end) <= before then
		problem("MANGA: a lens-flare star")
	end
	if count(function(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.ForceField
	end) < 5 then
		problem("MANGA: the rainbow of shock rings")
	end
	if MG.impact(Vector3.new(5000, 0, 5000), 0.1) then
		problem("...an impact frame only if you're close enough to see it")
	end
	task.wait(0.4)

	-- THE ANIME FIRE: flat tones, hard edges, nested tongues, on twos, blobs tearing off
	local f = B.flame({ CF = r.CFrame.new(40, 0, 40), Pal = "hell", Height = 6, Width = 3, Grow = 0.05, Frags = 12 })
	task.wait(0.3)
	local t1 = f.tongues[1]
	local beams = count(function(d)
		return d:IsA("Beam")
	end, f.holder)
	if beams < #f.tongues * 7 then
		problem("FIRE: every tongue is 7 beams - the glow, the shade, the body, the inner tongue, the core (" .. beams .. ")")
	end
	local keys = t1 and t1.shadeHi.Color.Keypoints
	if not keys or #keys < 4 or math.abs(keys[3].Time - keys[2].Time) > 0.02 then
		problem("FIRE: cel-shaded - one tone snaps to the next (hard edges)")
	end
	if t1 and ((t1.ai.CFrame.Position - t1.a0.CFrame.Position).Magnitude >= (t1.a1.CFrame.Position - t1.a0.CFrame.Position).Magnitude) then
		problem("FIRE: the inner tongue is shorter than the flame round it")
	end
	if f.holder:FindFirstChild("BlazeFlecks") == nil then
		problem("FIRE: dark cinders drifting off it")
	end
	if count(function(d)
		return d:IsA("BasePart") and d.Name == "BlazeHeart"
	end) > 0 then
		problem("FIRE: no glowing ball at the root (the anime doesn't draw one)")
	end
	-- on twos: the shape holds between drawings, then jumps
	local seen, last = 0, nil
	local held = 0
	for _ = 1, 30 do
		local p = t1.a1.CFrame.Position
		if last and (p - last).Magnitude < 1e-4 then
			held += 1
		elseif last then
			seen += 1
		end
		last = p
		task.wait(1 / 60)
	end
	if held < 10 or seen < 3 then
		problem(string.format("FIRE: drawn on twos - held between drawings, then a new shape (%d held, %d changes)", held, seen))
	end
	task.wait(0.8)
	if #B.frags == 0 and named("BlazeFragments") == 0 then
		problem("FIRE: blobs of flame tear off the tips and float away")
	end
	f.kill(0.1)
	-- Dabi's and the black-and-white one
	local blue = B.flame({ CF = r.CFrame.new(50, 0, 40), Pal = "blue", Height = 4, Width = 2 })
	local ink = B.flame({ CF = r.CFrame.new(60, 0, 40), Pal = "mono", Height = 4, Width = 2 })
	task.wait(0.2)
	local bc = blue.tongues[1].bodyLo.Color.Keypoints[1].Value
	local ic = ink.tongues[1].shadeLo.Color.Keypoints[1].Value
	local ib = ink.tongues[1].bodyLo.Color.Keypoints[1].Value
	if not (bc.B > bc.R) then
		problem("FIRE: Dabi's is blue")
	end
	if not (ic.R < 0.2 and ib.R > 0.9) then
		problem("FIRE: the black-and-white one is white fire inked in black")
	end
	blue.kill(0.1)
	ink.kill(0.1)
	local j = B.jet({ From = Vector3.new(0, 3, 60), Dir = Vector3.new(0, 0, -1), Length = 30, Width = 6, Pal = "hell", Life = 0.4 })
	task.wait(0.2)
	local flat = 0
	for _, L in j.layers do
		if L.beam.LightEmission <= 0.15 and not L.tex then
			flat += 1
		end
	end
	if flat < 4 then
		problem("FIRE: a jet is flat tones too (" .. flat .. " flat layers)")
	end
	task.wait(0.6)

	-- PROMINENCE BURN: so hot it goes black and white
	local guy = other
	look(Vector3.new(0, 3, -20))
	VFX.Play("ProminenceNovaBurst", guy, { Pos = Vector3.new(0, 3, -20), Radius = 34, Heat = 0.8 }, false)
	task.wait(0.15)
	if not mono() then
		problem("PROMINENCE BURN: the screen goes black and white")
	end
	local inked = count(function(d)
		return d:IsA("Beam") and d.Color.Keypoints[1].Value.R < 0.12 and d.Color.Keypoints[1].Value.G < 0.12
	end)
	if inked < 10 then
		problem("...and the fire is drawn white, inked in black (" .. inked .. " black shades)")
	end
	task.wait(1.6)
	if mono() then
		problem("...then the colour comes back")
	end
	look(Vector3.new(0, 3, 0))
	VFX.Play("ProminenceNovaBurst", guy, { Pos = Vector3.new(4000, 3, 0), Radius = 34 }, false)
	task.wait(0.1)
	if mono() then
		problem("...only for anyone close enough to see it")
	end
	task.wait(1.5)

	-- DEKU AT 100%: the cape and the eyes, the awakening
	look(Vector3.new(0, 3, 0))
	myChar:SetAttribute("Quirk", "FullCowl")
	myChar:SetAttribute("UltActive", true)
	VFX.Play("UltActivate", myChar, { Quirk = "FullCowl" }, false)
	task.wait(0.5)
	local cape = VFX.Folder:FindFirstChild("DekuCape")
	if not cape or named("Cape") < 20 or named("Eye") ~= 2 then
		problem("DEKU 100%: the tattered cape streaming off his shoulders and his eyes burning white (" .. named("Cape") .. " cloth, " .. named("Eye") .. " eyes)")
	end
	if named("CowlDisc") == 0 then
		problem("...the awakening: the white-hot disc under him")
	end
	local seg = cape and cape:FindFirstChild("Cape")
	local p1 = seg and seg.CFrame.Position
	task.wait(0.3)
	if seg and (seg.CFrame.Position - p1).Magnitude < 1e-4 then
		problem("...the cape flutters")
	end
	local torso = myChar:FindFirstChild("Torso") or myChar:FindFirstChild("UpperTorso")
	if seg and torso and torso.CFrame:PointToObjectSpace(seg.CFrame.Position).Z < 0 then
		problem("...behind him, not in front")
	end
	myChar:SetAttribute("UltActive", false)
	task.wait(0.2)
	if VFX.Folder:FindFirstChild("DekuCape") then
		problem("...gone when the ult ends")
	end
	myChar:SetAttribute("UltActive", true)
	task.wait(0.8)
	if not VFX.Folder:FindFirstChild("DekuCape") then
		problem("...and any Deku at 100% you come across has his")
	end

	-- SHOOT STYLE RUSH: the blitz
	local center = Vector3.new(0, 3, -8)
	local pts = {}
	for i = 1, 7 do
		local a = math.rad((i % 2 == 1 and 1 or -1) * (48 + (i - 1) * 21))
		pts[i] = center + r.CFrame.fromAxisAngle(Vector3.new(0, 1, 0), a) * Vector3.new(0, 0, 4.6)
	end
	local ghosts0 = named("Afterimage")
	VFX.Play("RushBlitz", myChar, { From = Vector3.new(0, 3, 0), Center = center, Points = pts, Gap = 0.07, Finish = center + Vector3.new(0, 0, 3.6), Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(0.3)
	if named("Afterimage") <= ghosts0 then
		problem("SHOOT STYLE RUSH: afterimages where he was")
	end
	local kicked = false
	for _ = 1, 50 do
		if mono() then
			kicked = true
		end
		task.wait(1 / 60)
	end
	if not kicked then
		problem("...the big kick at the end: black and white")
	end
	task.wait(0.3)

	-- INFINITE 100%: the fists multiply
	VFX.Play("FistRainStrike", myChar, { Target = other, Pos = Vector3.new(0, 6, -6), Index = 3, Final = false }, false)
	task.wait(0.03)
	if named("GhostFist") < 2 then
		problem("INFINITE 100%: the fists multiply")
	end
	task.wait(0.3)

	-- 1,000,000%: GO... BEYOND... PLUS ULTRA!! (All Might behind him)
	local M = Config.Quirks.FullCowl.Ult.Extra
	VFX.Play("MillionSmash", myChar, { Dir = Vector3.new(0, 0, -1) }, true, M)
	task.wait(0.8)
	local spirit = VFX.Folder:FindFirstChild("AllMightSpirit")
	if not spirit or not called["GO..."] or not called["...BEYOND!"] then
		problem("1,000,000%: GO... BEYOND... - All Might there behind him")
	end
	local head = spirit and spirit:FindFirstChild("head")
	if head and head.Transparency > 0.8 then
		problem("...faded in")
	end
	local hair = spirit and spirit:FindFirstChild("hairL")
	if not hair then
		problem("...his two bangs")
	end
	local arm = spirit and spirit:FindFirstChild("armR")
	local wound = arm and arm.CFrame.Position
	task.wait(0.9)
	if not called["PLUS ULTRA!!"] then
		problem("...PLUS ULTRA!!")
	end
	if arm and arm.Parent and (arm.CFrame.Position - wound).Magnitude < 1 then
		problem("...and they throw it together (his arm swings through)")
	end
	task.wait(1.2)
	if VFX.Folder:FindFirstChild("AllMightSpirit") then
		problem("...then he's gone")
	end
	myChar:SetAttribute("UltActive", false)
	myChar:SetAttribute("Quirk", "Explosion")
	task.wait(0.4)

	-- MORE EMOTES: every one plays, with its props (standing still)
	pcall(function()
		myChar.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end)
	VFX.ReleasePose(myChar, 0)
	local function emote(id, wait)
		VFX.Play("Emote", myChar, { Id = id }, false)
		task.wait(wait)
	end
	emote("Kamehameha", 1)
	if named("EmoteProp") == 0 then
		problem("KAMEHAMEHA: the ball of energy in his cupped hands")
	end
	task.wait(1.5)
	local beam = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d.Name == "EmoteProp" and d:IsA("BasePart") and d.Size.X > 20 then
			beam += 1
		end
	end
	if beam == 0 then
		problem("...HA!! - the beam down the street")
	end
	task.wait(1.5)
	VFX.ReleasePose(myChar, 0)
	emote("DubiousFood", 0.4)
	local metal = count(function(d)
		return d.Name == "EmoteProp" and d:IsA("BasePart") and d.Material == Enum.Material.Metal
	end)
	if metal < 2 then
		problem("DUBIOUS FOOD: the cooking pot on its fire")
	end
	task.wait(4)
	local box = false
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "Dubious Food" then
			box = true
		end
	end
	if not box then
		problem("...and what came out of it: Dubious Food")
	end
	task.wait(2.5)
	VFX.ReleasePose(myChar, 0)
	emote("HeroLanding", 1.1)
	if named("EmoteProp") == 0 then
		problem("HERO LANDING: the street cracks where he lands")
	end
	task.wait(2.6)
	VFX.ReleasePose(myChar, 0)
	emote("Nap", 1)
	local bubble = false
	for _, d in VFX.Folder:GetDescendants() do
		if d.Name == "EmoteProp" and d:IsA("BasePart") and d.Material == Enum.Material.Glass then
			bubble = true
		end
	end
	if not bubble then
		problem("NAP: the snot bubble")
	end
	task.wait(5.5)
	VFX.ReleasePose(myChar, 0)
	emote("FakeDeath", 2.3)
	local soul = count(function(d)
		return d.Name == "EmoteProp" and d:IsA("BasePart") and d.Material == Enum.Material.Neon
	end)
	if soul < 3 then
		problem("FAKE DEATH: his soul floating up, halo and all (" .. soul .. ")")
	end
	task.wait(2.8)
	VFX.ReleasePose(myChar, 0)
	emote("TPose", 0.5)
	emote("Griddy", 0.5)
	-- moving breaks one off, props and all
	VFX.ReleasePose(myChar, 0)
	emote("Kamehameha", 0.6)
	local root = myChar.HumanoidRootPart
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
	end)
	task.wait(0.3)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	if named("EmoteProps") > 0 and count(function(d)
		return d.Name == "EmoteProp" and d.Parent and d.Parent.Name == "EmoteProps" and d:IsA("BasePart") and d.Shape == Enum.PartType.Ball
	end) > 0 then
		problem("...moving breaks it off, props and all")
	end
	VFX.ReleasePose(myChar, 0)

	-- THE WHEEL: two rings once there are this many
	local hud = playerGui:FindFirstChild("QuirkHUD")
	local wheel = hud and hud:FindFirstChild("EmoteWheel", true)
	local topB = wheel and wheel:FindFirstChild("Emote_" .. WHEEL58[1], true)
	local downB = wheel and wheel:FindFirstChild("Emote_" .. WHEEL58[3], true)
	local n = 0
	for _, d in wheel and wheel:GetDescendants() or {} do
		if d:IsA("TextButton") and string.sub(d.Name, 1, 6) == "Emote_" then
			n += 1
		end
	end
	local function dist(b)
		return Vector2.new(b.Position.X.Offset, b.Position.Y.Offset).Magnitude
	end
	if n ~= Config.EmoteSlots or not topB or not downB or topB.Position.Y.Offset >= 0 or downB.Position.Y.Offset <= 0 or math.abs(dist(topB) - dist(downB)) > 1 then
		problem(string.format("THE WHEEL: its %d slots in a ring, the first at the top (%d buttons)", Config.EmoteSlots, n))
	end

	VFX.Hooks.Callout = realCallout
	setRaycast(nil)
	VFX.ReleasePose(myChar, 0)
	ticking = false
	task.wait(0.3)
end)
if not ok53 then
	problem("round 53 client scenario crashed: " .. tostring(err53))
end
end
print("== round 57: the fire a step further; All Might vs All For One v2 (on the user's place, Deku as he was)")
do
local ok54, err54 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local called = {}
	local realCallout, realFlash = VFX.Hooks.Callout, VFX.Hooks.Flash
	VFX.Hooks.Callout = function(text)
		called[text] = true
	end
	VFX.Hooks.Flash = function()
		called.Flash = true
	end
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			return { Position = origin + dir * t, Normal = Vector3.new(0, 1, 0), Instance = workspace.Terrain, Distance = dir.Magnitude * t, Material = Enum.Material.Concrete }
		end
		return nil
	end)
	local cam = workspace.CurrentCamera
	local function look(at)
		pcall(function()
			cam.Focus = r.CFrame.new(at)
			cam.CFrame = r.CFrame.new(at + Vector3.new(0, 6, 16), at)
		end)
	end
	local function count(filter, root)
		local n = 0
		for _, d in (root or VFX.Folder):GetDescendants() do
			if filter(d) then
				n += 1
			end
		end
		return n
	end
	local function named(name, root)
		return count(function(d)
			return d.Name == name
		end, root)
	end
	local lighting = game:GetService("Lighting")
	local B, AB, MG = VFX.BLAZE, VFX.AB, VFX.MANGA
	if not (B and AB and MG) then
		problem("round 57 modules: BLAZE, AB, MANGA")
		return
	end
	local root = myChar.HumanoidRootPart
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		myChar.Torso.AssemblyLinearVelocity = Vector3.zero
	end)

	-- THE FIRE, A STEP FURTHER
	look(Vector3.new(0, 3, 0))
	local f = B.flame({ CF = r.CFrame.new(0, 0, 0), Pal = "hell", Height = 7, Width = 3.2 })
	task.wait(0.3)
	local t1 = f.tongues[1]
	if not (t1 and t1.shadeA and t1.bodyA and t1.innerLo and t1.innerHi and t1.core and t1.glow and t1.shadeHi and t1.bodyHi) then
		problem("FIRE v3: every tongue is a belly, a waist, a whip of a tip, an inner belly and tip, and a core")
	end
	if named("BlazeFork", f.holder) < 2 then
		problem("FIRE v3: forked tips (" .. named("BlazeFork", f.holder) .. " fork beams)")
	end
	if named("BlazeBelly", f.holder) < #f.tongues * 2 then
		problem("FIRE v3: a lobed belly on every tongue")
	end
	local back, front = 0, 0
	local P = B.PAL.hell
	for _, t in f.tongues do
		local c = t.bodyLo.Color.Keypoints[1].Value
		if t.depth >= 1 then
			back += 1
			if (c.R + c.G + c.B) >= (P.body.R + P.body.G + P.body.B) - 0.05 then
				problem("FIRE v3: the tongues at the back are drawn a shade darker")
				break
			end
		elseif t.depth == 0 then
			front += 1
		end
	end
	if back == 0 or front == 0 or f.tongues[1].depth ~= 0 then
		problem(string.format("FIRE v3: licks in front of licks (%d front, %d back; the tallest in front)", front, back))
	end
	if named("BlazeHaze", f.holder) ~= 1 then
		problem("FIRE v3: the red haze behind a big fire")
	end
	local small = B.flame({ CF = r.CFrame.new(20, 0, 0), Pal = "hell", Height = 2, Width = 1 })
	task.wait(0.1)
	if named("BlazeHaze", small.holder) ~= 0 or named("BlazeFork", small.holder) ~= 0 then
		problem("...and none on a small one, nor forks")
	end
	small.kill(0)
	f.kill(0)
	-- the drawing beat breathes: over 1.5s some drawings are held two beats
	local big = B.flame({ CF = r.CFrame.new(40, 0, 0), Pal = "hell", Height = 12, Width = 5, Frags = 6, Smoke = true })
	local held2, seen, last, since = 0, 0, nil, os.clock()
	local t0 = os.clock()
	while os.clock() - t0 < 1.5 do
		local p = big.tongues[1].a1.CFrame.Position
		if not (last and (p - last).Magnitude < 1e-4) then
			if last and os.clock() - since >= 1.5 / 12 then
				held2 += 1 -- (held 1.5 drawings or more: the long one, at 12 a second)
			end
			since = os.clock()
			seen += 1
		end
		last = p
		task.wait(1 / 60)
	end
	if held2 < 1 then
		problem("FIRE v3: every so often a drawing is held a beat longer (" .. held2 .. " long holds in " .. seen .. " drawings)")
	end
	task.wait(1.2)
	if named("BlazePuff") < 1 then
		problem("FIRE v3: the burnt-out fragments leave lumps of smoke (" .. named("BlazePuff") .. ")")
	end
	big.kill(0)
	task.wait(1.7) -- (its last fragments and their smoke gone)
	-- a burst stars out in spikes, sparkles, and rolls up into smoke lumps
	B.burst(Vector3.new(60, 3, 0), 5, { Pal = "hell" })
	task.wait(0.05)
	if named("BlazeSpike") < 20 then
		problem("FIRE v3: a burst stars out in flat spikes (" .. named("BlazeSpike") .. " beams)")
	end
	local puffs0 = named("BlazePuff")
	task.wait(0.6)
	if named("BlazePuff") <= puffs0 then
		problem("...and rolls up into lumps of smoke")
	end
	task.wait(1.5)
	for _, fl in B.live do
		fl.kill(0)
	end
	task.wait(0.4)

	-- DEKU: as the user has him - none of rounds 54-56's Deku work
	if VFX.DX or VFX.MV or VFX.MP then
		problem("DEKU: exactly as on the user's place (no DX / MV / MP)")
	end

	-- ALL MIGHT vs ALL FOR ONE v2
	look(Vector3.new(0, 3, 0))
	VFX.Play("SkyBattle", nil, { Seed = 3, Length = 60 }, false)
	task.wait(0.3)
	local run54 = AB.run
	if not run54 then
		problem("SKY BATTLE v2: running")
		return
	end
	for _, p in { "held", "sprint", "splat", "grab", "slam" } do
		if not AB.P[p] then
			problem("SKY BATTLE v2: the new poses (" .. p .. ")")
		end
	end
	-- blow for blow: the fists leave smears
	run54.t0 = os.clock() - 7.1
	task.wait(1)
	if named("Smear") < 1 then
		problem("SKY BATTLE v2: fists too fast to draw leave smears")
	end
	-- Spring-like Limbs: the tendrils, then the slam into the street
	run54.t0 = os.clock() - 15.45
	task.wait(0.25)
	if named("Tendril") < 7 then
		problem("SKY BATTLE v2: the tendrils take hold of him (" .. named("Tendril") .. ")")
	end
	run54.t0 = os.clock() - 17.2
	local flickered = false
	for _ = 1, 24 do
		impact = lighting:FindFirstChild("ImpactFrame")
		flickered = flickered or (impact ~= nil and impact.Enabled)
		task.wait(1 / 60)
	end
	if not flickered then
		problem("SKY BATTLE v2: hammered into the street - the frame goes black and white")
	end
	local amPart = run54.am.parts[1].part
	local amY = amPart.CFrame.Position.Y
	task.wait(0.6)
	if amPart.CFrame.Position.Y - cam.Focus.Position.Y > 40 then
		problem(string.format("...down on the street (%.0f up)", amPart.CFrame.Position.Y - cam.Focus.Position.Y))
	end
	run54.t0 = os.clock() - 18.35
	task.wait(0.5)
	if not run54.sprint then
		problem("SKY BATTLE v2: flat out along the street")
	end
	local p0 = amPart.CFrame.Position
	task.wait(0.4)
	if (amPart.CFrame.Position - p0).Magnitude < 10 then
		problem("...and he's moving")
	end
	-- the barrage, and the UNITED STATES OF SMASH: the lava web under you
	called.Flash = nil
	run54.t0 = os.clock() - 41.25
	task.wait(1.2)
	if not called.Flash then
		problem("SKY BATTLE v2: the UNITED STATES OF SMASH goes white")
	end
	if named("LavaWeb") < 20 then
		problem("SKY BATTLE v2: the street under you glows in a web of cracks (" .. named("LavaWeb") .. ")")
	end
	AB.stop(run54)
	task.wait(0.3)
	if named("LavaWeb") > 0 then
		-- (they fade on their own; give them their life)
		task.wait(3.5)
	end
	VFX.Hooks.Callout, VFX.Hooks.Flash = realCallout, realFlash
	ticking = false
end)
if not ok54 then
	problem("round 57 checks crashed: " .. tostring(err54))
end
end
print("== round 58: the top bar and the hero phone; emotes bought in the shop, a 4-slot wheel; the test menu; One For All's realm")
do
local ok58, err58 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			task.wait(1 / 60)
		end
	end)
	local me = Players.LocalPlayer
	local function press(b)
		signalOf(b, "Activated"):Fire()
		task.wait(0.05)
	end
	local function click(b)
		signalOf(b, "MouseButton1Click"):Fire()
		task.wait(0.05)
	end

	-- THE TOP BAR: next to Roblox's buttons - CHARACTER, then EMOTES, then nothing
	local top = playerGui:FindFirstChild("QuirkTopBar")
	local bar = top and top:FindFirstChild("Bar")
	local charB = bar and bar:FindFirstChild("CharacterButton")
	local emoteB = bar and bar:FindFirstChild("EmoteButton")
	local reserved = bar and bar:FindFirstChild("Reserved")
	if not (top and charB and emoteB and reserved) then
		problem("TOP BAR: a CHARACTER button, an EMOTES button, and a slot kept free")
		return
	end
	if not (charB.LayoutOrder < emoteB.LayoutOrder and emoteB.LayoutOrder < reserved.LayoutOrder and not reserved.Visible) then
		problem("TOP BAR: CHARACTER first, EMOTES on its right, nothing (yet) after that")
	end
	if not (top.IgnoreGuiInset and bar.Position.X.Offset >= 100 and bar.Position.Y.Offset < 30) then
		problem(string.format("TOP BAR: up in the top bar, right of Roblox's own buttons (%d, %d)", bar.Position.X.Offset, bar.Position.Y.Offset))
	end
	if not charB:FindFirstChild("Caret") or not string.find(charB:FindFirstChild("Label").Text, "CHARACTER", 1, true) then
		problem("TOP BAR: it says CHARACTER, with a drop-down arrow")
	end

	-- THE PHONE: out of the CHARACTER button
	mouseAt62 = Vector2.new(5, 700) -- (round 62: the cursor off the phone - over it, it leans)
	HUD.ShowMenu(false)
	local phone = hudGui:FindFirstChild("QuirkMenu")
	press(charB)
	if not (phone and phone.Visible and HUD.MenuVisible()) then
		problem("THE PHONE: the CHARACTER button drops it down")
	end
	local screen = phone and phone:FindFirstChild("Screen")
	local list = screen and screen:FindFirstChild("Heroes")
	local rows = 0
	for _, name in Config.QuirkOrder do
		local row = list and list:FindFirstChild(name)
		if row and row:IsA("TextButton") then
			rows += 1
		end
	end
	if rows ~= #Config.QuirkOrder then
		problem("THE PHONE: every hero on it (" .. rows .. "/" .. #Config.QuirkOrder .. ")")
	end
	local dock = screen and screen:FindFirstChild("Dock")
	for _, app in { "Shop", "Emotes", "Settings", "Board" } do
		if not (dock and dock:FindFirstChild("App_" .. app)) then
			problem("THE PHONE: the " .. app .. " app on its dock")
		end
	end
	if phone and phone.Position.X.Offset ~= bar.Position.X.Offset then
		problem("THE PHONE: it hangs from the CHARACTER button")
	end
	if charB.Caret.Text ~= "▴" then
		problem("THE PHONE: the arrow flips while it's down")
	end
	press(charB)
	if HUD.MenuVisible() or charB.Caret.Text ~= "▾" then
		problem("THE PHONE: the button again puts it away")
	end
	task.wait(0.25)
	HUD.PhoneStep(1 / 60) -- (it drops back in, then it's gone)
	if phone.Visible then
		problem("THE PHONE: ...gone once it's dropped back in")
	end
	-- the hero you're playing: on the button and marked on the phone
	local first = Config.QuirkOrder[1]
	HUD.SetQuirk(first)
	task.wait(0.05)
	local q = Config.Quirks[first]
	if charB:FindFirstChild("Hero").Text ~= string.upper(q.DisplayName) then
		problem("THE BUTTON: says who you are (" .. charB:FindFirstChild("Hero").Text .. ")")
	end
	if not (list and list[first].Playing.Visible) then
		problem("THE PHONE: the hero you're playing is marked ACTIVE")
	end
	-- pick one off it: it's sent, and the phone goes away
	HUD.ShowMenu(true)
	table.clear(fired)
	local second = Config.QuirkOrder[2]
	press(list:FindFirstChild(second))
	local sent = false
	for _, f in fired do
		if f[1] == "SelectQuirk" and f[2] == second then
			sent = true
		end
	end
	if not sent or HUD.MenuVisible() then
		problem("THE PHONE: tap a hero - that's who you are, and it goes away")
	end
	-- the apps
	HUD.ShowMenu(true)
	press(dock:FindFirstChild("App_Emotes"))
	local shop = hudGui:FindFirstChild("Shop")
	local emoteShop = shop and shop:FindFirstChild("EmoteShop")
	if not (shop and shop.Visible and emoteShop and emoteShop.Visible and not HUD.MenuVisible()) then
		problem("THE PHONE: its EMOTES app opens the shop on the emotes")
	end
	HUD.ToggleShop(false)
	HUD.ShowMenu(true)
	press(dock:FindFirstChild("App_Shop"))
	if not (shop.Visible and not emoteShop.Visible) then
		problem("THE PHONE: its SHOP app opens the shop on the items")
	end
	HUD.ToggleShop(false)

	mouseAt62 = nil
	-- EMOTES: none to start with - the wheel's four slots are empty
	setAttr(me, "EmotesOwned", "")
	setAttr(me, "EmoteWheel", ",,,")
	task.wait(0.1)
	local wheel = hudGui:FindFirstChild("EmoteWheel")
	local slots, empties = 0, 0
	for _, d in wheel and wheel:GetDescendants() or {} do
		if d:IsA("TextButton") and string.sub(d.Name, 1, 6) == "Emote_" then
			slots += 1
			if string.sub(d.Name, 1, 11) == "Emote_Empty" then
				empties += 1
			end
		end
	end
	if slots ~= 4 or empties ~= 4 then
		problem(string.format("THE WHEEL: four slots, all empty to start with (%d slots, %d empty)", slots, empties))
	end
	-- the EMOTES button opens it; an empty slot takes you to the shop
	press(emoteB)
	if not HUD.EmoteWheelVisible() then
		problem("TOP BAR: the EMOTES button opens the wheel")
	end
	local empty1 = wheel and wheel:FindFirstChild("Emote_Empty1", true)
	if empty1 then
		press(empty1)
	end
	if not (shop.Visible and emoteShop.Visible) then
		problem("THE WHEEL: an empty slot opens the shop on the emotes")
	end
	-- (round 63) the emotes page lists only yours (none yet): new ones come
	-- from the EMOTES banner on the shop page
	local kame = emoteShop:FindFirstChild("EmoteShop_Kamehameha", true)
	if kame and kame.Visible then
		problem("THE SHOP: only the emotes you have on the emotes page")
	end
	if not shop:FindFirstChild("RollEmotes", true) then
		problem("THE SHOP: the EMOTES banner to roll for them")
	end
	-- bought two (the server says so), one on the wheel
	setAttr(me, "EmotesOwned", "Wave,Dance")
	setAttr(me, "EmoteWheel", "Wave,,Dance,")
	task.wait(0.1)
	wheel = hudGui:FindFirstChild("EmoteWheel")
	local wave = wheel and wheel:FindFirstChild("Emote_Wave", true)
	local dance = wheel and wheel:FindFirstChild("Emote_Dance", true)
	if not (wave and dance and wheel:FindFirstChild("Emote_Empty2", true) and wheel:FindFirstChild("Emote_Empty4", true)) then
		problem("THE WHEEL: what's on it, where it is - slot 1 and 3, 2 and 4 empty")
	elseif not (wave.Position.Y.Offset < 0 and dance.Position.Y.Offset > 0) then
		problem("THE WHEEL: slot 1 at the top, 3 at the bottom")
	end
	local wCard = emoteShop:FindFirstChild("EmoteShop_Wave", true)
	if not (wCard and string.find(wCard.Pill.Text, "ON WHEEL", 1, true)) then
		problem("THE SHOP: one on your wheel says so (" .. tostring(wCard and wCard.Pill.Text) .. ")")
	end
	-- an owned one off the wheel goes onto the first free slot...
	setAttr(me, "EmoteWheel", ",,Dance,")
	task.wait(0.1)
	table.clear(fired)
	click(wCard)
	if not (fired[1] and fired[1][2] == "EquipEmote" and fired[1][3] == 1 and fired[1][4] == "Wave") then
		problem("THE SHOP: tap one you own: onto the first free slot")
	end
	-- ...or the slot you picked
	local slot4 = emoteShop:FindFirstChild("Slot4", true)
	click(slot4)
	table.clear(fired)
	click(wCard)
	if not (fired[1] and fired[1][2] == "EquipEmote" and fired[1][3] == 4 and fired[1][4] == "Wave") then
		problem("THE SHOP: pick a slot, then an emote: it goes there")
	end
	-- a slot tapped twice empties it
	local slot3 = emoteShop:FindFirstChild("Slot3", true)
	click(slot3)
	table.clear(fired)
	click(slot3)
	if not (fired[1] and fired[1][2] == "EquipEmote" and fired[1][3] == 3 and fired[1][4] == "") then
		problem("THE SHOP: a slot tapped twice is emptied")
	end
	HUD.ToggleShop(false)

	-- THE TEST MENU: wider, in groups, real switches
	local test = hudGui:FindFirstChild("TestMenu")
	if test then
		if test.Size.X.Offset < 320 then
			problem("TEST MENU: wider (" .. test.Size.X.Offset .. ")")
		end
		local tlist = test:FindFirstChild("List")
		for _, g in { "You", "Dummies", "World", "Extras" } do
			if not (tlist and tlist:FindFirstChild("Group_" .. g)) then
				problem("TEST MENU: the " .. g .. " group")
			end
		end
		local god = test:FindFirstChild("GodMode", true)
		if not (god and god:FindFirstChild("Switch")) then
			problem("TEST MENU: toggles have a switch")
		else
			HUD.SetTestToggle("GodMode", true)
			local on = god.Switch:FindFirstChildOfClass("Frame").Position.X.Scale == 1
			HUD.SetTestToggle("GodMode", false)
			if not on then
				problem("TEST MENU: the switch slides over when it's on")
			end
		end
		table.clear(fired)
		local vest = test:FindFirstChild("Vestige", true)
		if vest then
			click(vest)
		end
		if not (fired[1] and fired[1][1] == "TestCommand" and fired[1][2] == "Vestige") then
			problem("TEST MENU: One For All in / out")
		end
		local dev = hudGui:FindFirstChild("DevPanel") or hudGui:FindFirstChild("DevAccess")
		if dev and dev.Position.X.Offset < 12 + test.Size.X.Offset then
			problem("TEST MENU: its side panels open beside it, not over it")
		end
	end

	-- ONE FOR ALL: drifting off, and the dark in there
	local L = game:GetService("Lighting")
	VFX.Play("VestigeIn", nil, {}, false)
	task.wait(0.4)
	local vs = playerGui:FindFirstChild("VestigeScreen")
	local black = vs and vs:FindFirstChild("Black")
	if not (black and black.BackgroundTransparency < 0.9) then
		problem("DRIFTING OFF: the screen goes dark")
	end
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local before = L.FogEnd
	local center = Config.VestigeRealm.Center
	pcall(function()
		root.CFrame = r.CFrame.new(center + Vector3.new(0, 3.5, 66))
		root.Position = center + Vector3.new(0, 3.5, 66)
	end)
	task.wait(0.4)
	if not (L.FogEnd <= 500 and L.Brightness < 1) then
		problem("INSIDE ONE FOR ALL: the world goes dark round you (fog " .. tostring(L.FogEnd) .. ")")
	end
	-- walk up to one of them: who they were comes up
	local fake = Instance.new("Model")
	fake.Name = "VestigeRealm"
	local fig = Instance.new("Model")
	fig.Name = "Vestige_7"
	fig:SetAttribute("VestigeName", "NANA SHIMURA")
	fig:SetAttribute("VestigeTitle", "The Seventh · Float")
	fig:SetAttribute("VestigeLine", "The one you can see clearly.")
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart" -- (the harness pivots a model on that)
	body.Anchored = true
	body.CFrame = r.CFrame.new(center + Vector3.new(0, 4, 60))
	body.Position = center + Vector3.new(0, 4, 60)
	body.Parent = fig
	fig.PrimaryPart = body
	fig.Parent = fake
	fake.Parent = workspace
	task.wait(0.5)
	local nameBox = vs and vs:FindFirstChild("Vestige")
	if not (nameBox and nameBox.Name == "Vestige" and nameBox:FindFirstChild("Name").Text == "NANA SHIMURA") then
		problem("INSIDE ONE FOR ALL: walk up to a vestige - their name comes up (" .. tostring(nameBox and nameBox:FindFirstChild("Name").Text) .. ")")
	end
	pcall(function()
		root.CFrame = r.CFrame.new(Vector3.new(0, 3, 0))
		root.Position = Vector3.new(0, 3, 0)
	end)
	task.wait(0.4)
	if L.FogEnd ~= before then
		problem("WAKING UP: your screen's lighting is put back (" .. tostring(L.FogEnd) .. " / " .. tostring(before) .. ")")
	end
	fake:Destroy()
	fullWheel58()
	ticking = false
end)
if not ok58 then
	problem("round 58 checks crashed: " .. tostring(err58))
end
end
print("== round 59: Suneater's glide, Bamboo Sweep and Urchin Spikes; the held Vanishing Act; Zap Traps only Denki sees; the OUTFIT app")
do
local ok59, err59 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			-- (a frame keeps coming even if something on it errors)
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	local me = Players.LocalPlayer
	local myRoot59 = myChar:FindFirstChild("HumanoidRootPart")
	local myHum59 = myChar:FindFirstChildOfClass("Humanoid")
	local function sent(index)
		local out = {}
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == index then
				table.insert(out, f)
			end
		end
		return out
	end
	local function colored(color, tol)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.99 then
				local c = d.Color
				if math.abs(c.R - color.R) + math.abs(c.G - color.G) + math.abs(c.B - color.B) < (tol or 0.02) then
					table.insert(out, d)
				end
			end
		end
		return out
	end
	local SEC = VFX.SE
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Ragdolled", nil)

	-- SUNEATER'S GLIDE: falling half a second, the wings - and the fall held
	setAttr(me, "Quirk", "Manifest")
	setAttr(myChar, "Quirk", "Manifest")
	local G = Config.Quirks.Manifest.Glide
	myHum59.FloorMaterial = Enum.Material.Air
	table.clear(fired)
	local t0 = os.clock()
	local glideAt
	while os.clock() - t0 < 1.2 do
		pcall(function()
			myRoot59.AssemblyLinearVelocity = Vector3.new(0, math.min(myRoot59.AssemblyLinearVelocity.Y, -1) - 196 / 60, 0)
		end)
		if not glideAt then
			for _, f in sent(Config.PARKOUR_INDEX) do
				if f[3] == "Glide" then
					glideAt = os.clock() - t0
				end
			end
		end
		task.wait(1 / 60)
	end
	local vy = myRoot59.AssemblyLinearVelocity.Y
	if not glideAt or glideAt < G.After - 0.1 or glideAt > G.After + 0.3 then
		problem("GLIDE: half a second into a fall, the wings go out (" .. tostring(glideAt) .. "s)")
	end
	if vy < -(G.FallSpeed + 4) then
		problem(string.format("...and his fall is held to %d (%.0f)", G.FallSpeed, vy))
	end
	if not (SEC.gliders[myChar]) then
		problem("...his own screen shows the wings")
	end
	-- landing: folded away, and everyone's told
	myHum59.FloorMaterial = Enum.Material.Plastic
	pcall(function()
		myRoot59.AssemblyLinearVelocity = Vector3.zero
	end)
	task.wait(0.1)
	local ended = false
	for _, f in sent(Config.PARKOUR_INDEX) do
		if f[3] == "GlideEnd" then
			ended = true
		end
	end
	if not ended or SEC.gliders[myChar] then
		problem("...landing folds them away (and tells everyone)")
	end
	-- a short hop (under half a second falling) is just a hop
	table.clear(fired)
	myHum59.FloorMaterial = Enum.Material.Air
	pcall(function()
		myRoot59.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
	end)
	task.wait(0.3)
	myHum59.FloorMaterial = Enum.Material.Plastic
	pcall(function()
		myRoot59.AssemblyLinearVelocity = Vector3.zero
	end)
	task.wait(0.1)
	if #sent(Config.PARKOUR_INDEX) > 0 then
		problem("...a short drop doesn't bring the wings out")
	end
	-- someone else's glide (the relay): the wings on their body, folded when told
	local glider = makeR15("Glider59", Vector3.new(40, 9, 40))
	VFX.Play("Parkour", glider, { Kind = "Glide" }, false)
	task.wait(0.1)
	local wingsOn = SEC.gliders[glider] ~= nil
	VFX.Play("Parkour", glider, { Kind = "GlideEnd" }, false)
	task.wait(0.4)
	if not wingsOn or SEC.gliders[glider] then
		problem("someone else gliding: their wings out, then folded away")
	end

	-- BAMBOO SWEEP (1 in the air): a green stalk that grows round the swing
	-- (found once, then watched: the effects folder is big by now)
	local air = Config.Quirks.Manifest.Abilities[1].Air
	local function named(name)
		local out = {}
		for _, c in VFX.Folder:GetChildren() do
			if c.Name == name and c.Transparency < 0.99 then
				table.insert(out, c)
			end
		end
		return out
	end
	for _, old in named("Bamboo") do
		old:Destroy()
	end
	VFX.Play("ChickenKick", myChar, { Dir = Vector3.new(0, 0, -1), Air = true }, true)
	local culm
	local tw = os.clock()
	while not culm and os.clock() - tw < 0.5 do
		culm = VFX.Folder:FindFirstChild("Bamboo")
		task.wait()
	end
	local nodes, leaves = #named("BambooNode"), #named("BambooLeaf")
	local minL, maxL = math.huge, 0
	tw = os.clock()
	while culm and os.clock() - tw < air.WindUp + air.SwingTime + 0.1 do
		if culm.Transparency < 0.99 and culm.Size.X > 0.5 then
			minL = math.min(minL, culm.Size.X)
			maxL = math.max(maxL, culm.Size.X)
		end
		task.wait(1 / 60)
	end
	if not (culm and minL < air.Length0 + 3 and maxL > air.Length1 - 3) then
		problem(string.format("BAMBOO SWEEP: a stalk of bamboo, medium to huge through the swing (%.1f -> %.1f)", minL, maxL))
	end
	if nodes < 6 or leaves < 3 then
		problem("...with its nodes, and leaves at the tip (" .. nodes .. ", " .. leaves .. ")")
	end
	task.wait((air.HoldTime or 0) + air.ReturnTime + 0.3)
	if culm and culm.Parent and culm.Transparency < 0.99 then
		problem("...then back round and into his arm")
	end

	-- URCHIN SPIKES (3 in the air): spines all over him
	VFX.Play("TakoThrash", myChar, { Dir = Vector3.new(0, 0, -1), Air = true }, true)
	task.wait(0.28)
	local spines = named("UrchinSpine")
	local longest = 0
	for _, p in spines do
		longest = math.max(longest, p.Size.X)
	end
	local tt = Config.Quirks.Manifest.Abilities[3]
	if #spines < tt.UrchinSpines * 0.9 or longest < 3 then
		problem(string.format("URCHIN SPIKES: spines out of every inch of him (%d, %.1f long)", #spines, longest))
	end
	task.wait(0.5)
	if #named("UrchinSpine") > 0 then
		problem("...and they pull back in")
	end

	-- THE VANISHING ACT, held: a ring where it'll land, 3 again flicks it
	setAttr(me, "Quirk", "Compress")
	setAttr(myChar, "Quirk", "Compress")
	setAttr(me, "NoCooldowns", true)
	task.wait(0.3)
	table.clear(fired)
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.Begin, {})
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.End, {})
	setAttr(myChar, "Holding", "VanishingAct")
	task.wait(0.3)
	local ring = VFX.Folder:FindFirstChild("HoldTarget")
	if not (#sent(3) == 1 and #sent(Config.RELEASE_INDEX) == 0 and ring) then
		problem("VANISHING ACT: 3 takes them - and he keeps them (a ring where they'll land)")
	end
	table.clear(fired)
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.Begin, {})
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.End, {})
	setAttr(myChar, "Holding", nil)
	task.wait(0.1)
	if #sent(Config.RELEASE_INDEX) ~= 1 or #sent(3) ~= 0 or VFX.Folder:FindFirstChild("HoldTarget") then
		problem("...3 again flicks it where he's aiming (and the ring goes)")
	end
	setAttr(me, "NoCooldowns", false)

	-- ZAP TRAP: only Denki sees it
	local before = #VFX.Folder:GetDescendants()
	VFX.Play("ZapTrapSet", other, { Id = 5901, Pos = Vector3.new(10, 0, 10), Arm = 0.1, Life = 3 }, false)
	task.wait(0.4)
	if #VFX.Folder:GetDescendants() > before + 2 or (VFX.DK and VFX.DK.traps and VFX.DK.traps[5901]) then
		problem("ZAP TRAP: someone else's - nothing there on my screen")
	end
	VFX.Play("ZapTrapSet", myChar, { Id = 5902, Pos = Vector3.new(12, 0, 12), Arm = 0.1, Life = 3 }, true)
	task.wait(0.4)
	if not (VFX.DK and VFX.DK.traps and VFX.DK.traps[5902]) then
		problem("...my own: there it is")
	end

	-- THE OUTFIT APP: your saved outfits, the one you'll wear awakened
	local answer = Enum.AvatarPromptResult.PermissionDenied
	r.implementProperty("AvatarEditorService", "PromptAllowInventoryReadAccessCompleted", function(self)
		return signalOf(self, "InvAccess")
	end)
	r.implementMethod("AvatarEditorService", "PromptAllowInventoryReadAccess", function(self)
		task.delay(0.05, function()
			signalOf(self, "InvAccess"):Fire(answer)
		end)
	end)
	r.implementMethod("AvatarEditorService", "GetOutfitsAsync", function()
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return { { Id = 101, Name = "Hero Fit", IsEditable = true }, { Id = 102, Name = "Villain Fit", IsEditable = true } }
			end,
		}
	end)
	local phone = hudGui:FindFirstChild("QuirkMenu")
	local dock = phone and phone:FindFirstChild("Dock", true)
	local apps = 0
	for _, c in dock and dock:GetChildren() or {} do
		if c:IsA("TextButton") and string.sub(c.Name, 1, 4) == "App_" then
			apps += 1
		end
	end
	local app = dock and dock:FindFirstChild("App_Outfit")
	if apps ~= 6 or not app or not dock:FindFirstChild("App_Ranked") or app.Size.X.Offset * 6 + 5 * 3 > 260 then
		problem("THE PHONE: OUTFIT and (round 95) RANKED apps on the dock - six apps that fit (" .. apps .. ")")
	end
	HUD.ShowMenu(true)
	signalOf(app, "Activated"):Fire()
	task.wait(0.3)
	local panel = hudGui:FindFirstChild("Outfits")
	local status = panel and panel:FindFirstChild("Status")
	local allow = panel and panel:FindFirstChild("Allow")
	if not (panel and panel.Visible and status and status.Visible and allow and allow.Visible) then
		problem("OUTFIT: it asks Roblox first - said no: it says so, and offers to ask again")
	end
	answer = Enum.AvatarPromptResult.Success
	signalOf(allow, "MouseButton1Click"):Fire()
	task.wait(0.3)
	local grid = panel and panel:FindFirstChild("Grid")
	local mine = grid and grid:FindFirstChild("Fit_101")
	local thumb = mine and mine:FindFirstChild("Thumb")
	if not (mine and grid:FindFirstChild("Fit_102") and grid:FindFirstChild("Fit_0") and thumb and string.find(thumb.Image, "type=Outfit&id=101", 1, true)) then
		problem("...said yes: your saved outfits, each with its picture (and your own avatar)")
	end
	if allow.Visible or status.Visible then
		problem("...(the question's gone)")
	end
	table.clear(fired)
	signalOf(mine, "MouseButton1Click"):Fire()
	task.wait(0.05)
	if not (fired[1] and fired[1][1] == "Shop" and fired[1][2] == "AwakenOutfit" and fired[1][3] == 101) then
		problem("...tap one: it's the one you'll wear")
	end
	setAttr(me, "AwakenOutfit", 101)
	task.wait(0.05)
	if not (mine.Chip.Visible and mine.Ring.Transparency == 0 and not grid.Fit_0.Chip.Visible and string.find(panel.Now.Text, "HERO FIT", 1, true)) then
		problem("...marked on it, and named at the top (" .. tostring(panel.Now.Text) .. ")")
	end
	HUD.ToggleOutfits(false)
	setAttr(me, "Quirk", "Explosion")
	setAttr(myChar, "Quirk", "Explosion")
	ticking = false
end)
if not ok59 then
	problem("round 59 checks crashed: " .. tostring(err59))
end
end
print("== round 60: Suneater's zip (and the point launch); Creati's effects; her M1 weapon; the phone")
do
local ok60, err60 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local uis60 = game:GetService("UserInputService")
	local ticking = true
	task.spawn(function()
		while ticking do
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	local me = Players.LocalPlayer
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local function named(name)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name and d.Parent then
				table.insert(out, d)
			end
		end
		return out
	end
	local function zipMover()
		return root:FindFirstChild("Zip")
	end
	-- (the harness keeps CFrame and Position apart: set both)
	local function put(pos)
		root.CFrame = CFrame.new(pos)
		root.Position = pos
	end
	-- (and nothing's ever cleaned up: the mover that's new since `before`)
	local function movers()
		local set = {}
		for _, d in root:GetChildren() do
			if d:IsA("LinearVelocity") then
				set[d] = true
			end
		end
		return set
	end
	local function newMover(before)
		for _, d in root:GetChildren() do
			if d:IsA("LinearVelocity") and not before[d] then
				return d
			end
		end
		return nil
	end
	local function sent(index)
		local out = {}
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == index then
				table.insert(out, f)
			end
		end
		return out
	end
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Ragdolled", nil)
	setAttr(me, "Quirk", "Manifest")
	setAttr(myChar, "Quirk", "Manifest")
	local Z = Config.Quirks.Manifest.Abilities[2].Zip

	-- THE ZIP, to a wall: reeled in along a straight line, and he clings there
	put(Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	PlayVFX.OnClientEvent:Fire("TakoZip", myChar, { Anchor = Vector3.new(0, 5, -30), Normal = Vector3.new(0, 0, 1) })
	task.wait(0.1)
	local lv = zipMover()
	if not (VFX.Zipping(myChar) and lv and lv.VectorVelocity.Z < -40 and math.abs(lv.VectorVelocity.X) < 1) then
		problem("THE ZIP: the tentacle reels him in straight at the spot (" .. tostring(lv and lv.VectorVelocity) .. ")")
	end
	task.wait(0.3)
	lv = zipMover()
	if not (lv and lv.VectorVelocity.Magnitude > Z.Speed * 0.9) then
		problem("...quicker as he goes, up to " .. Z.Speed .. " (" .. tostring(lv and lv.VectorVelocity.Magnitude) .. ")")
	end
	-- (the harness has no physics: put him there)
	put(Vector3.new(0, 3, -28.4))
	task.wait(0.15)
	lv = zipMover()
	if not (VFX.Zipping(myChar) and lv and lv.VectorVelocity.Magnitude < 0.1) then
		problem("...at the wall: he clings to it a moment")
	end
	signalOf(uis60, "JumpRequest"):Fire()
	task.wait(0.1)
	local v = root.AssemblyLinearVelocity
	if VFX.Zipping(myChar) or zipMover() or v.Y < Z.LaunchUp * 0.8 or v.Z < 20 then
		problem("...a jump on the wall: launched up and off it (" .. tostring(v) .. ")")
	end
	task.wait(0.5)

	-- POINT LAUNCH: jump on the way, and he doesn't stop at it
	put(Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	PlayVFX.OnClientEvent:Fire("TakoZip", myChar, { Anchor = Vector3.new(0, 10, -30), Normal = Vector3.new(0, 0, 1), Ledge = true })
	task.wait(0.15)
	signalOf(uis60, "JumpRequest"):Fire()
	put(Vector3.new(0, 8.6, -28.3))
	task.wait(0.15)
	v = root.AssemblyLinearVelocity
	if VFX.Zipping(myChar) or v.Y < Z.LaunchUp * 0.9 or v.Z > -Z.LaunchForward * 0.8 then
		problem("POINT LAUNCH: jump on the way - flung up and on over it (" .. tostring(v) .. ")")
	end
	task.wait(0.8)

	-- a ledge, no jump: over the lip onto the roof
	put(Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	PlayVFX.OnClientEvent:Fire("TakoZip", myChar, { Anchor = Vector3.new(0, 10, -30), Normal = Vector3.new(0, 0, 1), Ledge = true })
	task.wait(0.1)
	put(Vector3.new(0, 8.6, -28.3))
	task.wait(0.1)
	lv = zipMover()
	if not (lv and lv.VectorVelocity.Y > 20 and lv.VectorVelocity.Z < -5) then
		problem("A LEDGE: up and over the lip onto the roof (" .. tostring(lv and lv.VectorVelocity) .. ")")
	end
	task.wait(0.5)
	if VFX.Zipping(myChar) or zipMover() then
		problem("...and then he's stood on it (the zip's done)")
	end

	-- someone else's zip: the tentacle, not a zip on my screen
	PlayVFX.OnClientEvent:Fire("TakoZip", other, { Anchor = Vector3.new(20, 8, -20), Normal = Vector3.new(-1, 0, 0) })
	task.wait(0.1)
	if VFX.Zipping(other) or not (VFX.SE and VFX.SE.arms and VFX.SE.arms[other]) then
		problem("someone else's zip: the tentacle shows; their own screen moves them")
	end

	-- a zip only costs Zip.Cooldown of Tako Snatch
	put(Vector3.new(0, 3, 0))
	task.wait(0.8)
	table.clear(fired)
	actions.QuirkAbility2("QuirkAbility2", Enum.UserInputState.Begin, {})
	actions.QuirkAbility2("QuirkAbility2", Enum.UserInputState.End, {})
	task.wait(0.1)
	PlayVFX.OnClientEvent:Fire("TakoZip", myChar, { Anchor = Vector3.new(0, 5, -30), Normal = Vector3.new(0, 0, 1) })
	task.wait(0.1)
	put(Vector3.new(0, 3, -28.4))
	task.wait(Z.Cooldown + 0.4)
	put(Vector3.new(0, 3, 0))
	actions.QuirkAbility2("QuirkAbility2", Enum.UserInputState.Begin, {})
	actions.QuirkAbility2("QuirkAbility2", Enum.UserInputState.End, {})
	task.wait(0.1)
	if #sent(2) ~= 2 then
		problem("THE ZIP: Tako Snatch is back " .. Z.Cooldown .. "s after a zip (" .. #sent(2) .. " sent)")
	end
	task.wait(0.8)

	-- CREATI
	setAttr(me, "Quirk", "Creation")
	setAttr(myChar, "Quirk", "Creation")
	if not (VFX.M1Sets and VFX.M1Sets.Weapon and Config.M1.Styles.Creation == "Weapon") then
		problem("CREATI: her M1s are weapon swings")
	end
	for i = 1, 4 do
		VFX.Play("Punch", myChar, { Count = i, Finisher = i == 4 }, true)
		task.wait(0.25)
	end
	-- R: the new weapon grows out of her hand
	local gear = myChar:FindFirstChild("QuirkGear") or Instance.new("Model")
	gear.Name = "QuirkGear"
	gear.Parent = myChar
	VFX.Play("CreateWeapon", myChar, {}, true)
	task.wait(0.05)
	local w = Instance.new("Model")
	w.Name = "CreatedWeapon"
	local blade = Instance.new("Part")
	blade.Size = Vector3.new(0.1, 0.3, 3.6)
	blade.Parent = w
	w.Parent = gear
	task.wait(0.2)
	if not w:FindFirstChild("CreationGlow") then
		problem("R: CREATE - the new weapon glows as it comes out of her hand")
	end
	w:Destroy()

	-- 1: MATRYOSHKA FLASH - three dolls in a fan; one goes off where it's told
	local dollsBefore = #named("Matryoshka")
	VFX.Play("MatryoshkaFlash", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.3)
	local thrown = #named("Matryoshka") - dollsBefore
	if thrown ~= 3 then
		problem("MATRYOSHKA FLASH: three nesting dolls thrown (" .. thrown .. ")")
	end
	local before = #named("Matryoshka")
	PlayVFX.OnClientEvent:Fire("MatryoshkaPop", myChar, { Index = 2, Pos = Vector3.new(0, 4, -12) })
	task.wait(0.1)
	if #named("Matryoshka") ~= before then -- (doll 2 goes; the smaller doll inside tumbles out)
		problem("...the second doll splits open where the server says (" .. before .. " -> " .. #named("Matryoshka") .. ")")
	end
	local lights = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("PointLight") and d.Brightness >= 8 then
			lights += 1
		end
	end
	if lights < 1 then
		problem("...and the flashbang goes off (a blinding light)")
	end

	-- 2: the shield on her arm while "Shielding"; a tap plants it; the bash
	VFX.Play("CastleWall", myChar, {}, true)
	setAttr(myChar, "Shielding", true)
	task.wait(0.3)
	local shield = VFX.YM.shields[myChar]
	if not (shield and #shield:GetChildren() >= 5) then
		problem("CASTLE WALL: a tower shield out of her forearm")
	end
	local welded = shield and shield:FindFirstChildWhichIsA("BasePart")
	if welded and not welded:FindFirstChildOfClass("Weld") then
		problem("...held on her arm (welded to it)")
	end
	setAttr(myChar, "Shielding", nil)
	task.wait(0.3)
	if VFX.YM.shields[myChar] then
		problem("...and put away when she lets go")
	end
	PlayVFX.OnClientEvent:Fire("CastleWallPlant", myChar, { CF = CFrame.new(0, 4.3, -5), Size = Vector3.new(12, 9, 1.2) })
	PlayVFX.OnClientEvent:Fire("CastleWallHit", nil, { Pos = Vector3.new(0, 4, -5.6), CF = CFrame.new(0, 4.3, -5) })
	PlayVFX.OnClientEvent:Fire("CastleWallBreak", nil, { CF = CFrame.new(0, 4.3, -5), Size = Vector3.new(12, 9, 1.2), Broken = true })
	put(Vector3.new(0, 3, 0))
	local m0 = movers()
	PlayVFX.OnClientEvent:Fire("ShieldBash", myChar, { Dir = Vector3.new(0, 0, -1), Dist = 14, Time = 0.22 })
	task.wait(0.05)
	local dashing = newMover(m0)
	if not (dashing and dashing.VectorVelocity.Z < -50) then
		problem("SHIELD BASH: she drives it forward (" .. tostring(dashing and dashing.VectorVelocity) .. ")")
	end
	PlayVFX.OnClientEvent:Fire("ShieldBlock", myChar, { Pos = Vector3.new(0, 4, -2) })
	task.wait(0.5)

	-- 3: BULLET RAIN - the cannon, the shells, the little dolls
	local cannons0 = #named("CreatiCannon")
	VFX.Play("BulletRain", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	PlayVFX.OnClientEvent:Fire("BulletRainShells", myChar, {
		Cannon = Vector3.new(3, 0, 0), Dir = Vector3.new(0, 0, -1), Muzzle = Vector3.new(3, 2.4, -1.6),
		Shells = { { Land = Vector3.new(0, 0, -30), Bombs = { Vector3.new(4, 0, -30), Vector3.new(-4, 0, -30), Vector3.new(0, 0, -26), Vector3.new(0, 0, -34) }, At = 0.2, Flight = 0.4 } },
	})
	task.wait(0.1)
	if #named("CreatiCannon") ~= cannons0 + 1 then
		problem("BULLET RAIN: a cannon beside her")
	end
	local dolls0 = #named("Matryoshka")
	task.wait(0.75)
	if #named("Matryoshka") < dolls0 + 3 then
		problem("...the shell lands and the matryoshka bombs hop out (" .. (#named("Matryoshka") - dolls0) .. ")")
	end

	-- 4: the weapons' moves
	VFX.Play("StrikeAndStop", myChar, {}, true)
	PlayVFX.OnClientEvent:Fire("StrikeStop", other, {})
	task.wait(0.05)
	if not VFX.Folder:FindFirstChild("StopMark") then
		problem("STRIKE AND STOP: STOP! over whoever it caught")
	end
	put(Vector3.new(0, 3, 0))
	m0 = movers()
	VFX.Play("IaiRush", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	dashing = newMover(m0)
	local IR = Config.Quirks.Creation.Extras[2]
	if not (dashing and math.abs(dashing.VectorVelocity.Z + IR.Dash / IR.DashTime) < 1) then
		problem("IAI RUSH: she dashes through (" .. tostring(dashing and dashing.VectorVelocity) .. ")")
	end
	task.wait(0.4)
	VFX.Play("PiercingThrust", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	PlayVFX.OnClientEvent:Fire("SpearRun", myChar, { Target = other, Dir = Vector3.new(0, 0, -1) })
	task.wait(0.4)

	-- the ult's creations
	local c0 = #named("CreatiCannon")
	VFX.Play("GrandCannon", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.6)
	if #named("CreatiCannon") ~= c0 + 1 then
		problem("GRAND CANNON: it rises out of the street beside her")
	end
	PlayVFX.OnClientEvent:Fire("GrandCannonFire", myChar, { Muzzle = Vector3.new(4, 8, -4), Target = Vector3.new(0, 0, -60), Flight = 0.3 })
	VFX.Play("CaptureNet", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	PlayVFX.OnClientEvent:Fire("CaptureNetFly", myChar, { From = Vector3.new(0, 7, 3), Pos = Vector3.new(0, 0, -30), Flight = 0.3, Radius = 12, Pin = 1 })
	task.wait(0.5)
	local net = VFX.Folder:FindFirstChild("CreatiNet")
	if not (net and #net:GetChildren() > 40) then
		problem("CAPTURE NET: a net comes down over the spot (" .. (net and #net:GetChildren() or 0) .. " pieces)")
	end
	VFX.Play("DischargeCannon", myChar, { Dir = Vector3.new(0, 0, -1) }, true, { Charge = 0.3 })
	task.wait(0.1)
	local rail = VFX.Folder:FindFirstChild("CreatiRailgun")
	if not (rail and #rail:GetChildren() >= 5) then
		problem("DISCHARGE CANNON: the railgun on her shoulder")
	end
	PlayVFX.OnClientEvent:Fire("DischargeCannonFire", myChar, { Origin = Vector3.new(0, 5, 0), Dir = Vector3.new(0, 0, -1), Length = 100, Width = 7 })
	VFX.Play("LuckyBag", myChar, {}, true)
	PlayVFX.OnClientEvent:Fire("LuckyBagDrop", myChar, { Pos = Vector3.new(0, 0, -3), Items = { "Soda", "Bomb" } })
	task.wait(0.1)
	if not VFX.Folder:FindFirstChild("LuckyBag") then
		problem("LUCKY BAG: the bag drops at her feet")
	end
	task.wait(0.8)
	-- the finisher: a cannon out of her forearm, point blank
	local c1 = #named("CreatiCannon")
	VFX.Play("Finisher", myChar, { Target = other, Dir = Vector3.new(0, 0, -1), Style = "Creation", Time = 0.6 }, true)
	task.wait(0.3)
	if #named("CreatiCannon") ~= c1 + 1 then
		problem("THE FINISHER: a cannon, point blank")
	end
	task.wait(0.6)
	VFX.CancelCinematic() -- (her finisher's camera: over, like the other finisher checks)
	setAttr(me, "Quirk", nil)
	setAttr(myChar, "Quirk", nil)

	-- THE PHONE: Creati's on it; Iida's only for testers
	HUD.SetDevAccess(false)
	HUD.ShowMenu(true)
	task.wait(0.05)
	local found, iida = nil, nil
	for _, d in hudGui:GetDescendants() do
		if d:IsA("GuiButton") and d.Name == "Creation" then
			found = d
		elseif d:IsA("GuiButton") and d.Name == "Engine" then
			iida = d
		end
	end
	if not found then
		problem("THE PHONE: Creati's on it")
	end
	if not (iida and iida.Visible) then
		problem("THE PHONE: Iida's on it again (round 74: public)")
	end
	HUD.ShowMenu(false)
	ticking = false -- (this section's frames stop here, like round 59's)
end)
if not ok60 then
	problem("round 60 client tests crashed: " .. tostring(err60))
end
pcall(VFX.CancelCinematic)
pcall(VFX.ReleasePose, myChar, 0)
end
print("== round 61: real keyframed animations - the M1 combo's KeyframeSequences, played on every client")
do
local ok61, err61 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	local ticking = true
	task.spawn(function()
		while ticking do
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	-- (this section eases for real - the harness's TweenService:GetValue is
	-- linear - so the in-engine frames can be held against the reference)
	local EASE_IN = {
		Linear = function(a) return a end,
		Sine = function(a) return 1 - math.cos(a * math.pi / 2) end,
		Quad = function(a) return a * a end,
		Cubic = function(a) return a * a * a end,
		Quart = function(a) return a ^ 4 end,
		Quint = function(a) return a ^ 5 end,
	}
	getValueImpl = function(_, a, style, dir)
		local f = EASE_IN[style and style.Name or "Linear"] or EASE_IN.Linear
		local d = dir and dir.Name or "In"
		if d == "In" then
			return f(a)
		elseif d == "Out" then
			return 1 - f(1 - a)
		end
		return a < 0.5 and f(a * 2) / 2 or 1 - f((1 - a) * 2) / 2
	end
	-- the place's animations: the very model file the build splices into
	-- ReplicatedStorage (anim/out/Animations.rbxm)
	local anims = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1]
	anims.Parent = game:GetService("ReplicatedStorage")
	local NAMES = { "M1Brawler1", "M1Brawler2", "M1Brawler3", "M1Brawler4", "M1Uppercut", "M1Downslam" }
	for _, name in NAMES do
		local ks = anims:FindFirstChild(name)
		local clip = VFX.GetClip(name)
		if not (ks and ks:IsA("KeyframeSequence") and clip and clip.hit and clip.length > clip.hit) then
			problem("THE CLIPS: " .. name .. " is a KeyframeSequence with a Hit key (" .. tostring(clip and clip.hit) .. ")")
		end
		local n = 0
		for _ in clip and clip.tracks or {} do
			n += 1
		end
		if n ~= 6 then
			problem("THE CLIPS: " .. name .. " moves all six R6 joints (" .. n .. ")")
		end
	end
	local c1 = VFX.GetClip("M1Brawler1")
	if not (c1 and math.abs(c1.hit - 0.095) < 1e-3 and math.abs(c1.length - 0.42) < 1e-3) then
		problem("THE CLIPS: the first hit lands at 0.095s and settles by 0.42s")
	end

	-- a street under everyone
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0), Distance = origin.Y }
		end
		return nil
	end)
	local body = makeR6("Clip61", Vector3.new(30, 3, 0))
	local troot = body.HumanoidRootPart
	local torso = body.Torso
	local motors = {
		Torso = troot.RootJoint, Head = torso.Neck,
		["Right Arm"] = torso["Right Shoulder"], ["Left Arm"] = torso["Left Shoulder"],
		["Right Leg"] = torso["Right Hip"], ["Left Leg"] = torso["Left Hip"],
	}
	local rest = {}
	for part, m in motors do
		rest[part] = m.C0
	end
	-- the joint's offset from rest (what the clip's Pose.CFrame is)
	local function offset(part)
		return rest[part]:Inverse() * motors[part].C0
	end
	local function keyPose(clipName, keyName, part)
		local kf = anims[clipName]:FindFirstChild(keyName)
		local root = kf and kf:FindFirstChild("HumanoidRootPart")
		if part == "Torso" then
			return root.Torso.CFrame
		end
		return root.Torso[part].CFrame
	end
	-- how far apart two limb orientations are (degrees, along the limb)
	local function apart(a, b)
		local d = a:VectorToWorldSpace(Vector3.new(0, 1, 0)):Dot(b:VectorToWorldSpace(Vector3.new(0, 1, 0)))
		return math.deg(math.acos(math.clamp(d, -1, 1)))
	end
	-- the limb sits on the way from the Hit key to the key after it (the
	-- hold: robust to which frame the harness happens to sample)
	local function nextKey(clipName)
		local ks = anims[clipName]
		local hit = ks.Hit.Time
		local best
		for _, kf in ks:GetChildren() do
			if kf.Time > hit + 1e-4 and (not best or kf.Time < best.Time) then
				best = kf
			end
		end
		return best
	end
	local function between(clipName, part)
		local a0 = keyPose(clipName, "Hit", part)
		local nk = nextKey(clipName).HumanoidRootPart
		local a1 = part == "Torso" and nk.Torso.CFrame or nk.Torso[part].CFrame
		local o = offset(part)
		return apart(o, a0) + apart(o, a1) - apart(a0, a1)
	end
	local function holdTime(clipName)
		local ks = anims[clipName]
		return (ks.Hit.Time + nextKey(clipName).Time) / 2
	end
	local function atRest()
		for part in motors do
			local o = offset(part)
			if o.Position.Magnitude > 1e-3 or apart(o, CFrame.new()) > 0.5 then
				return false, part
			end
		end
		return true
	end

	-- 1: THE RIGHT STRAIGHT, on a body standing in the street
	local t0 = os.clock()
	VFX.Play("Punch", body, { Count = 1, Finisher = false }, false)
	task.wait(0.02)
	local early = apart(offset("Right Arm"), CFrame.new())
	local fullAt = apart(keyPose("M1Brawler1", "Keyframe", "Right Arm"), CFrame.new())
	if early <= 0.01 then
		problem("THE RIGHT STRAIGHT: the clip takes the arm the moment it's thrown")
	end
	task.wait(math.max(holdTime("M1Brawler1") - (os.clock() - t0), 0))
	local d = between("M1Brawler1", "Right Arm")
	if d > 10 then
		problem(string.format("THE RIGHT STRAIGHT: through the contact the right arm is where the Hit key has it (%.1f degrees off)", d))
	end
	local twist = between("M1Brawler1", "Torso")
	if twist > 10 then
		problem(string.format("...and the body's turned into it like the Hit key (%.1f off)", twist))
	end
	local _ = fullAt
	-- hitstop (a landed hit): the pose freezes and picks up where it stopped
	-- (a long freeze; the samples are taken after the pose driver has really
	-- stepped - counted - since a harness frame can run long)
	local steps = 0
	local stepConn = RunSvc.Stepped:Connect(function()
		steps += 1
	end)
	local h0 = os.clock()
	VFX.Hitstop(body, 0.6)
	repeat
		task.wait()
	until steps >= 3 or os.clock() - h0 > 0.25
	local a = offset("Right Arm")
	steps = 0
	repeat
		task.wait()
	until steps >= 3 or os.clock() - h0 > 0.5
	local b = offset("Right Arm")
	stepConn:Disconnect()
	if os.clock() - h0 < 0.58 and (apart(a, b) > 0.05 or (a.Position - b.Position).Magnitude > 1e-3) then
		problem(string.format("HITSTOP: the clip freezes on a landed hit (moved %.2f degrees)", apart(a, b)))
	end
	task.wait(math.max(0.7 - (os.clock() - h0), 0)) -- (the rest of the freeze)
	-- then it plays out and eases back to standing
	task.wait(0.42 + 0.25 + 0.3)
	local still, which = atRest()
	if not still then
		problem("THE RIGHT STRAIGHT: afterwards every joint is back at rest (" .. tostring(which) .. ")")
	end

	-- 2: A CHAIN - the hook fades in from wherever the straight had got to
	t0 = os.clock()
	VFX.Play("Punch", body, { Count = 1, Finisher = false }, false)
	task.wait(0.28)
	local mid = offset("Left Arm")
	local t1 = os.clock()
	VFX.Play("Punch", body, { Count = 2, Finisher = false }, false)
	-- (the pose clock held at the switch - one frame's worth of blend depends
	-- on when the harness happens to step - so: the new hit starts exactly
	-- where the arm was, no snap)
	VFX.Hitstop(body, 0.1)
	task.wait(0.05)
	local jump = apart(mid, offset("Left Arm"))
	if jump > 3 then
		problem(string.format("THE CHAIN: the next hit blends in from where the arm was rather than snapping (%.1f degrees)", jump))
	end
	task.wait(math.max(holdTime("M1Brawler2") + 0.1 - (os.clock() - t1), 0))
	d = between("M1Brawler2", "Left Arm")
	if d > 10 then
		problem(string.format("THE LEFT HOOK: the left arm reaches its contact pose (%.1f off)", d))
	end
	task.wait(0.44 + 0.25 + 0.3)

	-- 3 and the finisher
	for count, name in { [3] = "M1Brawler3", [4] = "M1Brawler4" } do
		t1 = os.clock()
		VFX.Play("Punch", body, { Count = count, Finisher = count == 4 }, false)
		task.wait(math.max(holdTime(name) - (os.clock() - t1), 0))
		d = between(name, "Right Arm")
		if d > 10 then
			problem(string.format("%s: the right arm at its contact pose (%.1f off)", name, d))
		end
		task.wait(VFX.GetClip(name).length + 0.6)
	end

	-- the finisher's variants: the uppercut springs off the street (the
	-- body rises), the downslam in the air uses its own legs
	t1 = os.clock()
	VFX.Play("Punch", body, { Count = 4, Finisher = true, Variant = "Up" }, false)
	task.wait(math.max(holdTime("M1Uppercut") - (os.clock() - t1), 0))
	d = between("M1Uppercut", "Right Arm")
	if d > 10 then
		problem(string.format("THE UPPERCUT: the fist goes straight up (%.1f off)", d))
	end
	task.wait(1.4)
	troot.CFrame = CFrame.new(30, 14, 0)
	troot.Position = Vector3.new(30, 14, 0)
	t1 = os.clock()
	VFX.Play("Punch", body, { Count = 4, Finisher = true, Variant = "Down" }, false)
	task.wait(math.max(holdTime("M1Downslam") - (os.clock() - t1), 0))
	d = between("M1Downslam", "Right Leg")
	if d > 10 then
		problem(string.format("THE DOWNSLAM (in the air): its legs kick out behind (%.1f off)", d))
	end
	task.wait(1.4)
	-- a plain hit thrown in the air: the arms punch, the legs are left alone
	t1 = os.clock()
	VFX.Play("Punch", body, { Count = 1, Finisher = false }, false)
	task.wait(math.max(0.12 - (os.clock() - t1), 0))
	local legs = apart(offset("Right Leg"), CFrame.new()) + apart(offset("Left Leg"), CFrame.new())
	if legs > 1 or apart(offset("Right Arm"), CFrame.new()) < 30 then
		problem(string.format("AN AIR PUNCH: arms from the clip, legs left to the fall (%.1f)", legs))
	end
	task.wait(1)
	troot.CFrame = CFrame.new(30, 3, 0)
	troot.Position = Vector3.new(30, 3, 0)

	-- an R15 body: no R6 clip for it - its own motion plays instead
	if VFX.Clip(myChar, "M1Brawler1") ~= nil then
		problem("R15: the R6 clips are left to R6 bodies (R15 keeps its motion)")
	end
	-- a published copy plays through the Animator instead
	Config.Animations.Clips.M1Brawler1 = "rbxassetid://61000001"
	local before = #tracks
	local pc = VFX.Clip(body, "M1Brawler1")
	local played = tracks[#tracks]
	if not (pc and #tracks == before + 1 and played and played.Id == "rbxassetid://61000001") then
		problem("PUBLISHED: an id in Config.Animations.Clips plays through the Animator")
	end
	Config.Animations.Clips.M1Brawler1 = ""
	task.wait(0.8)
	-- no Animations folder: the old motion (nothing breaks)
	anims.Parent = nil
	if VFX.GetClip("M1Brawler1") ~= nil then
		problem("NO FOLDER: without ReplicatedStorage.Animations there's no clip")
	end
	local okNo = pcall(function()
		VFX.Play("Punch", body, { Count = 1, Finisher = false }, false)
	end)
	if not okNo then
		problem("NO FOLDER: the punch still plays its motion")
	end
	task.wait(0.8)
	anims.Parent = game:GetService("ReplicatedStorage")

	-- the in-engine frames of a whole chain (rendered by anim/engine_render.py)
	if process.env.DUMP61 then
		local frames = {}
		local start = os.clock()
		local plays = { { 0, 1, false }, { 0.28, 2, false }, { 0.56, 3, false }, { 0.84, 4, true } }
		local nextPlay = 1
		while os.clock() - start < 0.84 + 0.8 + 0.4 do
			local t = os.clock() - start
			while plays[nextPlay] and plays[nextPlay][1] <= t do
				local p = plays[nextPlay]
				p[4] = os.clock() - start
				VFX.Play("Punch", body, { Count = p[2], Finisher = p[3] }, false)
				nextPlay += 1
			end
			local f = { t = t }
			for part in motors do
				f[part] = { offset(part):GetComponents() }
			end
			table.insert(frames, f)
			task.wait(1 / 60)
		end
		fs.writeFile(process.env.DUMP61, require("@lune/serde").encode("json", { frames = frames, plays = plays }))
		print("  dumped " .. #frames .. " in-engine frames")
	end
	setRaycast(nil)
	body:Destroy()
	anims.Parent = nil
	getValueImpl = function(_, a)
		return a -- (the harness's own again)
	end
	ticking = false
end)
if not ok61 then
	problem("round 61 client tests crashed: " .. tostring(err61))
end
end
print("== round 62: the dashes and Creati's three weapons as keyframed clips (round 64: no idle / walk / run loops)")
do
local ok62, err62 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	ticking62 = true -- (globals: the suite is at its local limit)
	task.spawn(function()
		while ticking62 do
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	local anims = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1]
	anims.Parent = game:GetService("ReplicatedStorage")

	-- THE CLIPS: every one of this round's is in the place
	local HITS = {
		SwordM1_1 = 0.095, SwordM1_2 = 0.105, SwordM1_3 = 0.115, SwordM1_4 = 0.15, SwordUp = 0.13, SwordDown = 0.14, IaiRush = 0.33,
		StaffM1_1 = 0.095, StaffM1_2 = 0.105, StaffM1_3 = 0.115, StaffM1_4 = 0.15, StaffUp = 0.13, StaffDown = 0.14, StrikeAndStop = 0.15,
		SpearM1_1 = 0.095, SpearM1_2 = 0.105, SpearM1_3 = 0.115, SpearM1_4 = 0.15, SpearUp = 0.13, SpearDown = 0.14, PiercingThrust = 0.17,
	}
	for name, hit in HITS do
		local clip = VFX.GetClip(name)
		if not (clip and clip.hit and math.abs(clip.hit - hit) < 1e-3 and clip.length > hit) then
			problem("THE CLIPS: " .. name .. " lands its Hit key at " .. hit .. "s (" .. tostring(clip and clip.hit) .. ")")
		end
	end
	for _, name in { "DashFront", "DashBack", "DashLeft", "DashRight" } do
		local ks = anims:FindFirstChild(name)
		if not (ks and VFX.GetClip(name) and not ks.Loop and ks.Priority == Enum.AnimationPriority.Action) then
			problem("THE CLIPS: " .. name .. " is an Action clip")
		end
	end
	if #anims:GetChildren() < 36 then
		problem("THE CLIPS: every KeyframeSequence in the place (" .. #anims:GetChildren() .. ")")
	end

	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0), Distance = origin.Y }
		end
		return nil
	end)
	-- (real R6 sizes: the stride scales with the legs)
	local function sized(body)
		body.Torso.Size = Vector3.new(2, 2, 1)
		body.Head.Size = Vector3.new(2, 1, 1)
		for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
			body[n].Size = Vector3.new(1, 2, 1)
		end
		return body
	end
	local function motorsOf(body)
		local torso = body.Torso
		return {
			Torso = body.HumanoidRootPart.RootJoint, Head = torso.Neck,
			["Right Arm"] = torso["Right Shoulder"], ["Left Arm"] = torso["Left Shoulder"],
			["Right Leg"] = torso["Right Hip"], ["Left Leg"] = torso["Left Hip"],
		}
	end
	local function restOf(motors)
		local rest = {}
		for part, m in motors do
			rest[part] = m.C0
		end
		return rest
	end
	local function apart(a, b)
		local d = a:VectorToWorldSpace(Vector3.new(0, 1, 0)):Dot(b:VectorToWorldSpace(Vector3.new(0, 1, 0)))
		return math.deg(math.acos(math.clamp(d, -1, 1)))
	end
	-- a joint's clip pose at a key
	local function keyPose(clipName, keyName, part)
		local kf = anims[clipName]:FindFirstChild(keyName)
		local root = kf.HumanoidRootPart
		return part == "Torso" and root.Torso.CFrame or root.Torso[part].CFrame
	end

	-- 1: THE DASHES play their clips (the whole body) and ease back after
	local body = sized(makeR6("Dash62", Vector3.new(60, 3, 0)))
	local motors = motorsOf(body)
	local rest = restOf(motors)
	local function offset(part)
		return rest[part]:Inverse() * motors[part].C0
	end
	local t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(0, 0, -1), Kind = "Front" }, false)
	task.wait(math.max(0.12 - (os.clock() - t0), 0))
	local fly = apart(offset("Torso"), CFrame.new())
	if fly < 20 then
		problem(string.format("THE FRONT DASH: thrown forward through the glide (%.1f degrees of lean)", fly))
	end
	local armsBack = apart(offset("Right Arm"), keyPose("DashFront", "Keyframe", "Right Arm"))
	if apart(offset("Right Arm"), CFrame.new()) < 45 then
		problem(string.format("THE FRONT DASH: both arms swept back (%.1f)", armsBack))
	end
	task.wait(0.56 + 0.18 + 0.35)
	for part in motors do
		if apart(offset(part), CFrame.new()) > 0.5 then
			problem("THE FRONT DASH: afterwards back to standing (" .. part .. ")")
		end
	end
	t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(0, 0, 1), Kind = "Back" }, false)
	task.wait(math.max(0.2 - (os.clock() - t0), 0))
	local flip = apart(offset("Torso"), CFrame.new())
	if flip < 110 then
		problem(string.format("THE BACK DASH: a backflip - upside down mid-air (%.1f degrees over)", flip))
	end
	task.wait(0.68 + 0.18 + 0.35)
	t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(1, 0, 0), Kind = "Right" }, false)
	task.wait(math.max(0.1 - (os.clock() - t0), 0))
	local rightArm = apart(offset("Right Arm"), CFrame.new())
	local rightLegOut = offset("Left Leg")
	task.wait(0.5 + 0.18 + 0.35)
	t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(-1, 0, 0), Kind = "Left" }, false)
	task.wait(math.max(0.1 - (os.clock() - t0), 0))
	local leftArm = apart(offset("Left Arm"), CFrame.new())
	if math.abs(rightArm - leftArm) > 6 or rightArm < 30 then
		problem(string.format("THE SIDE DASHES: mirror images - the lead arm thrown out (%.1f / %.1f)", rightArm, leftArm))
	end
	if apart(rightLegOut, CFrame.new()) < 10 then
		problem("THE SIDE DASHES: the far leg pushes off wide")
	end
	task.wait(0.5 + 0.18 + 0.35)
	body:Destroy()

	-- (the harness's Animator hands back every track any test ever played:
	-- stop the stale ones, or the loops rightly step aside for them)
	for _, t in tracks do
		if t.Track then
			t.Track.IsPlaying = false
		end
	end
	-- 2: (round 64) NO LOOPS: round 62's keyframed idle / walk / run / sprint
	-- are gone - R6 bodies walk as they did before: Roblox's clips (and the
	-- MovementSystem pack), the built-in gait for any body playing none
	if Config.Animations.Procedural.R6 ~= "auto" then
		problem("NO LOOPS: R6 bodies walk as before round 62 (Procedural.R6 = \"auto\", not " .. tostring(Config.Animations.Procedural.R6) .. ")")
	end
	if Config.Animations.Strides ~= nil then
		problem("NO LOOPS: no stride table for loops that aren't there")
	end
	for _, name in { "LocoIdle", "LocoFight", "LocoWalk", "LocoRun", "LocoSprint" } do
		if anims:FindFirstChild(name) then
			problem("NO LOOPS: " .. name .. " is out of the place")
		end
	end
	local walker = sized(makeR6("Loco64", Vector3.new(90, 3, 0)))
	motors = motorsOf(walker)
	rest = restOf(motors)
	local function swing(part, side)
		local _, _, z = offset(part):ToEulerAnglesXYZ()
		return math.deg(z) * side
	end
	local function watch(seconds)
		local crossings, most, last = 0, 0, nil
		local start = os.clock()
		while os.clock() - start < seconds do
			local s = swing("Right Leg", 1)
			if last and last < 0 and s >= 0 then
				crossings += 1
			end
			last = s
			most = math.max(most, math.abs(s))
			task.wait(1 / 60)
		end
		return crossings / seconds, most
	end
	VFX.LocoOverride[walker] = { Velocity = Vector3.zero, Grounded = true }
	task.wait(1.2)
	local _, idleMost = watch(0.8)
	if idleMost > 8 then
		problem(string.format("THE GAIT (as before): standing still, the legs settle (%.1f degrees of swing)", idleMost))
	end
	VFX.LocoOverride[walker] = { Velocity = Vector3.new(0, 0, -18), Grounded = true }
	task.wait(1.2)
	local rate, runMost = watch(2)
	if rate < 0.5 or runMost < 15 then
		problem(string.format("THE GAIT (as before): a body playing no clip still runs on the built-in gait (%.2f cycles/s, %.1f degrees)", rate, runMost))
	end
	VFX.LocoOverride[walker] = nil
	task.wait(0.2)
	walker:Destroy()

	-- 3: CREATI'S WEAPONS - each its own set, sounds and ribbon
	local momo = sized(makeR6("Creati62", Vector3.new(120, 3, 0)))
	momo:SetAttribute("Quirk", "Creation")
	local gear = Instance.new("Folder")
	gear.Name = "QuirkGear"
	gear.Parent = momo
	local weaponModel = Instance.new("Model")
	weaponModel.Name = "CreatedWeapon"
	weaponModel:SetAttribute("Weapon", "Sword")
	weaponModel.Parent = gear
	motors = motorsOf(momo)
	rest = restOf(motors)
	cues62 = {}
	local realPlay = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		table.insert(cues62, name)
		return realPlay(name, ...)
	end
	local function heard(name)
		for _, c in cues62 do
			if c == name then
				return true
			end
		end
		return false
	end
	-- the weapon's arm sits on its way from the Hit key to the next key
	local function nextKey(clipName)
		local ks = anims[clipName]
		local hit = ks.Hit.Time
		local best
		for _, kf in ks:GetChildren() do
			if kf.Time > hit + 1e-4 and (not best or kf.Time < best.Time) then
				best = kf
			end
		end
		return best
	end
	local function between(clipName, part)
		local a0 = keyPose(clipName, "Hit", part)
		local nk = nextKey(clipName).HumanoidRootPart
		local a1 = part == "Torso" and nk.Torso.CFrame or nk.Torso[part].CFrame
		local o = offset(part)
		return apart(o, a0) + apart(o, a1) - apart(a0, a1)
	end
	local function swingWith(weapon, count, clipName, data)
		weaponModel:SetAttribute("Weapon", weapon)
		table.clear(cues62)
		local t1 = os.clock()
		data = data or {}
		data.Count = count
		data.Finisher = count == 4
		VFX.Play("Punch", momo, data, false)
		task.wait(0.03)
		local ribbon
		for _, c in momo["Right Arm"]:GetChildren() do
			if c:IsA("Trail") and c.FaceCamera == false then
				ribbon = c
			end
		end
		local hold = (anims[clipName].Hit.Time + nextKey(clipName).Time) / 2
		task.wait(math.max(hold - (os.clock() - t1), 0))
		local d = between(clipName, "Right Arm")
		if d > 10 then
			problem(string.format("%s: %s's right arm at its contact pose (%.1f off)", clipName, weapon, d))
		end
		hitCue62 = VFX.WeaponHitCue(momo) -- (what a hit landing now would add)
		task.wait(VFX.GetClip(clipName).length + 0.5)
		return ribbon
	end
	local ribbon = swingWith("Sword", 1, "SwordM1_1")
	if not ribbon then
		problem("THE SWORD: a ribbon off the blade through the swing")
	end
	if not heard("SwordSwing") or heard("Swing") then
		problem("THE SWORD: its own swing (" .. table.concat(cues62, ", ") .. ")")
	end
	if hitCue62 ~= "SwordHit" then
		problem("THE SWORD: a hit it lands sounds like a blade (" .. tostring(hitCue62) .. ")")
	end
	if VFX.WeaponHitCue(momo) ~= nil then
		problem("THE SWORD: long after the swing, a hit isn't the sword's")
	end
	swingWith("Sword", 4, "SwordM1_4")
	if not (heard("SwordHeavy") and heard("SwordRing")) then
		problem("THE SWORD: the cleave rings out (" .. table.concat(cues62, ", ") .. ")")
	end
	swingWith("Staff", 2, "StaffM1_2")
	if not heard("StaffSwing") or hitCue62 ~= "StaffHit" then
		problem("THE STAFF: its own whoosh (" .. table.concat(cues62, ", ") .. ")")
	end
	swingWith("Staff", 4, "StaffM1_4")
	if not heard("StaffSlam") then
		problem("THE STAFF: the overhead slam hits the street (" .. table.concat(cues62, ", ") .. ")")
	end
	swingWith("Spear", 1, "SpearM1_1")
	if not heard("SpearSwing") or hitCue62 ~= "SpearHit" then
		problem("THE SPEAR: its own sounds (" .. table.concat(cues62, ", ") .. ")")
	end
	swingWith("Spear", 3, "SpearM1_3")
	swingWith("Staff", 4, "StaffUp", { Variant = "Up" })
	momo.HumanoidRootPart.CFrame = CFrame.new(120, 14, 0)
	momo.HumanoidRootPart.Position = Vector3.new(120, 14, 0)
	swingWith("Spear", 4, "SpearDown", { Variant = "Down" })
	momo.HumanoidRootPart.CFrame = CFrame.new(120, 3, 0)
	momo.HumanoidRootPart.Position = Vector3.new(120, 3, 0)
	-- the 4th moves play their clips
	for _, m in { { "StrikeAndStop", "Staff", "StaffHeavy" }, { "IaiRush", "Sword", "SwordDraw" }, { "PiercingThrust", "Spear", "SpearHeavy" } } do
		weaponModel:SetAttribute("Weapon", m[2])
		table.clear(cues62)
		local t1 = os.clock()
		VFX.Play(m[1], momo, { Dir = Vector3.new(0, 0, -1) }, false)
		local clip = VFX.GetClip(m[1])
		task.wait(math.max(clip.hit + 0.02 - (os.clock() - t1), 0))
		local moved = apart(offset("Torso"), CFrame.new()) + apart(offset("Right Arm"), CFrame.new())
		if moved < 20 then
			problem(string.format("%s: the clip plays (%.1f)", m[1], moved))
		end
		if not heard(m[3]) then
			problem(m[1] .. ": its weapon's sound (" .. table.concat(cues62, ", ") .. ")")
		end
		task.wait(clip.length + 0.6)
	end
	-- no weapon in her hand (an old save, the gear not built yet): the round 60 set
	weaponModel.Parent = nil
	if VFX.WeaponOf(momo) ~= nil then
		problem("NO WEAPON: nothing in her hand, no weapon kit")
	end
	local okPlain = pcall(function()
		VFX.Play("Punch", momo, { Count = 1, Finisher = false }, false)
	end)
	if not okPlain then
		problem("NO WEAPON: her punch still plays")
	end
	task.wait(0.8)
	-- an R15 Creati: the round 60 motions stand in for the clips
	local r15Gear = myChar:FindFirstChild("QuirkGear") == nil and Instance.new("Folder") or nil
	if r15Gear then
		r15Gear.Name = "QuirkGear"
		r15Gear.Parent = myChar
	end
	weaponModel.Parent = myChar.QuirkGear
	local quirkBefore = myChar:GetAttribute("Quirk")
	local okR15 = pcall(function()
		myChar:SetAttribute("Quirk", "Creation")
		VFX.Play("Punch", myChar, { Count = 1, Finisher = false }, false)
		task.wait(0.5)
	end)
	myChar:SetAttribute("Quirk", quirkBefore)
	weaponModel.Parent = nil
	if r15Gear then
		r15Gear:Destroy()
	end
	if not okR15 then
		problem("R15: Creati's punch falls back to the round 60 motion")
	end
	VFX.PlaySound = realPlay
	momo:Destroy()
	setRaycast(nil)
	anims.Parent = nil
	ticking62 = false
end)
if not ok62 then
	ticking62 = false
	problem("round 62 client tests crashed: " .. tostring(err62))
end
end
print("== round 62: the hero phone - its look, the pull-out, leaning after the cursor")
do
local okP, errP = pcall(function()
	local phone = hudGui:FindFirstChild("QuirkMenu")
	if not (phone and phone:IsA("CanvasGroup")) then
		problem("THE PHONE: a CanvasGroup (it turns and fades as one piece, its screen still clipped)")
		return
	end
	local screen = phone:FindFirstChild("Screen")
	for _, name in { "Glow", "Glare", "Glint", "Boot", "Scan", "Status", "Kicker", "Headline" } do
		if not (screen and screen:FindFirstChild(name)) then
			problem("THE PHONE: its screen has " .. name)
		end
	end
	if not (phone:FindFirstChild("Bezel") and phone.Bezel:FindFirstChildOfClass("UIGradient")) then
		problem("THE PHONE: a metal frame that catches the light")
	end
	HUD.SetQuirk(Config.QuirkOrder[1])
	HUD.ShowMenu(false)
	HUD.PhoneStep(1 / 60)
	task.wait(0.3)
	HUD.PhoneStep(1 / 60)
	mouseAt62 = Vector2.new(5, 700) -- (the cursor off in a corner)
	local fit = phone:FindFirstChild("Fit")
	-- TAKING IT OUT: it starts small, turned and see-through at the button...
	HUD.ShowMenu(true)
	local fx = phoneParts62 or nil
	local base = fit.Scale
	if not (phone.Visible and HUD.MenuVisible() and phone.GroupTransparency > 0.9 and phone.Rotation < -10) then
		problem(string.format("THE PULL-OUT: it comes out small, turned and faded in (%.2f, %.1f)", phone.GroupTransparency, phone.Rotation))
	end
	local burst = hudGui:FindFirstChild("PhoneBurst")
	if not burst then
		problem("THE PULL-OUT: a burst of light off the CHARACTER button")
	end
	-- ...springs past full size and settles (driven frame by frame)
	local most, start = 0, os.clock()
	while os.clock() - start < 1 do
		HUD.PhoneStep(1 / 60)
		most = math.max(most, fit.Scale)
		task.wait(1 / 60)
	end
	local settled = fit.Scale
	if most <= settled * 1.02 then
		problem(string.format("THE PULL-OUT: it overshoots full size before settling (%.3f / %.3f)", most, settled))
	end
	if math.abs(phone.Rotation) > 0.5 or phone.GroupTransparency > 0.01 then
		problem(string.format("THE PULL-OUT: settled upright and solid (%.1f, %.2f)", phone.Rotation, phone.GroupTransparency))
	end
	local list = screen and screen:FindFirstChild("Heroes")
	for _, row in list and list:GetChildren() or {} do
		if row:IsA("TextButton") and row.Visible then
			local pad = row:FindFirstChild("Slide")
			if not pad or pad.PaddingLeft.Offset ~= 0 then
				problem("THE PULL-OUT: every hero's row has slid into place (" .. row.Name .. ")")
				break
			end
		end
	end
	local dock = screen and screen:FindFirstChild("Dock")
	for _, b in dock and dock:GetChildren() or {} do
		if b:IsA("TextButton") then
			local pop = b:FindFirstChildOfClass("Frame"):FindFirstChild("Pop")
			if not pop or math.abs(pop.Scale - 1) > 0.01 then
				problem("THE PULL-OUT: the apps have popped up to size (" .. b.Name .. ")")
				break
			end
		end
	end
	if screen.Boot.Visible or screen.Scan.Visible or screen.Glint.Visible then
		problem("THE PULL-OUT: the power-on and the glint are over")
	end
	if not burst or burst.Parent then
		task.wait(0.3)
	end
	if hudGui:FindFirstChild("PhoneBurst") then
		problem("THE PULL-OUT: the burst clears away")
	end
	-- THE CURSOR: over its right side it leans that way and lifts; away, it settles back
	local p = Vector2.new(phone.Position.X.Offset, phone.Position.Y.Offset)
	local sz = Vector2.new(300, 600) * settled
	local restX = phone.Position.X.Offset
	mouseAt62 = Vector2.new(p.X + sz.X * 0.95, p.Y + sz.Y * 0.2)
	for _ = 1, 40 do
		HUD.PhoneStep(1 / 60)
	end
	if not (phone.Rotation > 3 and phone.Position.X.Offset > restX + 6 and fit.Scale > settled * 1.02) then
		problem(string.format("THE CURSOR: the phone leans after it (%.1f degrees, %d px, x%.3f)", phone.Rotation, phone.Position.X.Offset - restX, fit.Scale / settled))
	end
	local glare = screen.Glare:FindFirstChildOfClass("UIGradient")
	if not (glare and glare.Offset.X < -0.35) then
		problem("THE CURSOR: the glare slides the other way")
	end
	mouseAt62 = Vector2.new(p.X + sz.X * 0.05, p.Y + sz.Y * 0.8)
	for _ = 1, 40 do
		HUD.PhoneStep(1 / 60)
	end
	if not (phone.Rotation < -3) then
		problem(string.format("THE CURSOR: ...and the other way on its left (%.1f)", phone.Rotation))
	end
	mouseAt62 = Vector2.new(5, 700)
	for _ = 1, 60 do
		HUD.PhoneStep(1 / 60)
	end
	if math.abs(phone.Rotation) > 0.5 or math.abs(phone.Position.X.Offset - restX) > 1 then
		problem("THE CURSOR: gone, the phone settles back")
	end
	-- PUTTING IT AWAY: away at once (the button's arrow flips), then it tips and drops back in
	HUD.ShowMenu(false)
	if HUD.MenuVisible() then
		problem("PUT AWAY: it counts as away the moment you close it")
	end
	HUD.PhoneStep(1 / 60)
	task.wait(0.08)
	HUD.PhoneStep(1 / 60)
	if not (phone.Visible and phone.GroupTransparency > 0.1) then
		problem("PUT AWAY: it fades as it drops back in")
	end
	task.wait(0.2)
	HUD.PhoneStep(1 / 60)
	if phone.Visible then
		problem("PUT AWAY: then it's gone")
	end
	-- out again straight away: it comes out again
	HUD.ShowMenu(true)
	HUD.ShowMenu(false)
	HUD.ShowMenu(true)
	if not HUD.MenuVisible() then
		problem("THE PHONE: in, out and in again - it's out")
	end
	HUD.ShowMenu(false)
	task.wait(0.25)
	HUD.PhoneStep(1 / 60)
	mouseAt62 = nil
	local _ = fx
	local _b = base
end)
if not okP then
	problem("round 62 phone tests crashed: " .. tostring(errP))
end
end
print("== round 63: the moves as keyframed clips, get-ups, the hit star, the JJS shop, no bottom-right card")
do
local ok63, err63 = pcall(function()
	local CFrame = r.CFrame
	local RunSvc = game:GetService("RunService")
	ticking63 = true -- (globals: the suite is at its local limit)
	task.spawn(function()
		while ticking63 do
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	local RS = game:GetService("ReplicatedStorage")
	local anims = RS:FindFirstChild("Animations")
	if not anims then
		anims = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1]
		anims.Parent = RS
	end
	local function click(b)
		signalOf(b, "MouseButton1Click"):Fire()
		task.wait(0.05)
	end

	-- 1: THE MOVES' CLIPS: a clip for every hero's moves, each landing where its move does
	local HITS = { MoveDetroitSmash = 0.395, MoveNewHampshire = 0.3, MoveSkyUppercut = 0.5, MoveUnitedStatesSmash = 0.93,
		MoveStLouis = 0.25, MoveManchester = 0.47, MoveDecayWave = 0.22, MoveHowitzer = 0.22, PosePunchR = 0.06, PoseBlast = 0.06 }
	for name, hit in HITS do
		local clip = VFX.GetClip(name)
		if not (clip and clip.hit and math.abs(clip.hit - hit) < 1e-3) then
			problem("MOVE CLIPS: " .. name .. " lands its Hit at " .. hit .. "s (" .. tostring(clip and clip.hit) .. ")")
		end
	end
	local moves, poses = 0, 0
	for _, ks in anims:GetChildren() do
		if string.sub(ks.Name, 1, 4) == "Move" then
			moves += 1
		elseif string.sub(ks.Name, 1, 4) == "Pose" then
			poses += 1
			if not ks:FindFirstChild("Hold") then
				problem("MOVE CLIPS: " .. ks.Name .. " has a Hold key (held as long as the move holds it)")
			end
		end
	end
	if moves < 60 or poses < 20 then
		problem(string.format("MOVE CLIPS: the heroes' moves (%d) and held poses (%d)", moves, poses))
	end
	local function sized(b)
		b.Torso.Size = Vector3.new(2, 2, 1)
		b.Head.Size = Vector3.new(2, 1, 1)
		for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
			b[n].Size = Vector3.new(1, 2, 1)
		end
		return b
	end
	local function apart(a, b)
		local d = a:VectorToWorldSpace(Vector3.new(0, 1, 0)):Dot(b:VectorToWorldSpace(Vector3.new(0, 1, 0)))
		return math.deg(math.acos(math.clamp(d, -1, 1)))
	end
	local function keyPose(clipName, keyName, part)
		local kf = anims[clipName]:FindFirstChild(keyName)
		local root = kf.HumanoidRootPart
		return part == "Torso" and root.Torso.CFrame or root.Torso[part].CFrame
	end
	local body = sized(makeR6("Moves63", Vector3.new(150, 3, 0)))
	local shoulder = body.Torso["Right Shoulder"]
	local rest = shoulder.C0
	local function arm()
		return rest:Inverse() * shoulder.C0
	end
	-- DETROIT SMASH: the fist drawn back, then thrown out on the Hit key
	local hitArm = keyPose("MoveDetroitSmash", "Hit", "Right Arm")
	local t0 = os.clock()
	VFX.Motion(body, "DetroitSmash")
	task.wait(math.max(0.3 - (os.clock() - t0), 0))
	local coil = apart(arm(), hitArm)
	task.wait(math.max(0.43 - (os.clock() - t0), 0))
	local out = apart(arm(), hitArm)
	if not (coil > 60 and out < 25) then
		problem(string.format("DETROIT SMASH (clip): drawn back (%.0f from the punch), then thrown out on the Hit key (%.0f)", coil, out))
	end
	task.wait(1.1)
	if apart(arm(), CFrame.new()) > 1 then
		problem(string.format("...and back to rest after (%.1f)", apart(arm(), CFrame.new())))
	end
	-- a held pose: snapped out, held as long as the move holds it, then back
	local punchArm = keyPose("PosePunchR", "Hold", "Right Arm")
	t0 = os.clock()
	VFX.Pose(body, "PunchR", 0.8)
	task.wait(math.max(0.12 - (os.clock() - t0), 0))
	local p1 = apart(arm(), punchArm)
	task.wait(math.max(0.6 - (os.clock() - t0), 0))
	local p2 = apart(arm(), punchArm)
	if not (p1 < 20 and p2 < 5) then
		problem(string.format("POSE CLIPS: PunchR snaps out (%.0f off) and is held (%.0f off)", p1, p2))
	end
	task.wait(math.max(1.5 - (os.clock() - t0), 0))
	if apart(arm(), CFrame.new()) > 1 then
		problem(string.format("...then lets go (%.1f)", apart(arm(), CFrame.new())))
	end
	-- R15 bodies keep the procedural motions
	if VFX.Clip(myChar, "MoveDetroitSmash") then
		problem("R15: no clips (the procedural motion instead)")
	end

	-- 2: GETTING UP from where you lie
	for _, name in { "GetUpBack", "GetUpFront" } do
		local clip = VFX.GetClip(name)
		if not (clip and clip.length < 0.6) then
			problem("GET UP: " .. name .. ", a quick clip")
		end
	end
	local g = sized(makeR6("GetUp63", Vector3.new(170, 3, 0)))
	local gs = g.HumanoidRootPart.RootJoint
	local grest = gs.C0
	VFX.Play("GetUp", g, { Face = "Up" }, false)
	task.wait(0.03)
	local lie = grest:Inverse() * gs.C0
	if not (lie.Position.Magnitude > 1.5 and apart(lie, CFrame.new()) > 60) then
		problem(string.format("GET UP: it starts lying on the street (%.2f down, %.0f over)", lie.Position.Magnitude, apart(lie, CFrame.new())))
	end
	task.wait(0.8)
	if (grest:Inverse() * gs.C0).Position.Magnitude > 0.05 then
		problem("GET UP: ...and ends standing")
	end

	-- 3: THE HIT STAR
	local target = makeR6("Hit63", Vector3.new(190, 3, 0))
	local seen = {}
	for _, d in VFX.Folder:GetDescendants() do
		seen[d] = true
	end
	VFX.Play("Hit", nil, { Target = target, Amount = 20, Heavy = true, Hitstop = 0.05 }, false)
	task.wait(0.03)
	local spikes = 0
	for _, d in VFX.Folder:GetDescendants() do
		if not seen[d] and d:IsA("Frame") and d.Parent and d.Parent:IsA("BillboardGui") then
			spikes += 1
		end
	end
	if spikes < 8 then
		problem("THE HIT STAR: a sharp star of light where it lands (" .. spikes .. " spikes)")
	end

	-- 4: THE SHOP, JJS-style
	local badge = hudGui:FindFirstChild("QuirkBadge")
	if badge and badge.Visible then
		problem("the bottom-right character card is gone")
	end
	for _, e in Config.Emotes do
		if e.Id == "DadMode" and e.Name ~= "THE JIGGY" then
			problem("DAD MODE is called THE JIGGY now")
		end
	end
	HUD.ShowMenu(false)
	HUD.ToggleShop(true)
	local shop = hudGui:FindFirstChild("Shop")
	local tabs = shop and shop:FindFirstChild("Tabs")
	for _, t in { "ShopTab", "EmotesTab", "RewardsTab" } do
		if not (tabs and tabs:FindFirstChild(t)) then
			problem("THE SHOP: the " .. t .. " along the top")
		end
	end
	HUD.ShopTab("Shop")
	local roll = shop and shop:FindFirstChild("RollEmotes", true)
	local chip = roll and roll:FindFirstChild("Multiplier")
	table.clear(fired)
	click(roll)
	if not (fired[1] and fired[1][1] == "Shop" and fired[1][2] == "RollEmotes" and fired[1][3] == 1) then
		problem("THE SHOP: the EMOTES banner rolls a random one")
	end
	click(chip)
	click(chip)
	click(chip)
	table.clear(fired)
	click(roll)
	if not (fired[1] and fired[1][3] == 10 and string.find(roll.Price.Text, "250", 1, true) and string.find(roll.Info.Text, "10th", 1, true)) then
		problem("THE SHOP: the chip goes 1x 2x 5x 10x (the price follows; ten and you pick the tenth): " .. tostring(roll and roll.Price.Text))
	end
	click(chip)
	if chip.Text ~= "1x" then
		problem("...and round again to 1x")
	end
	local odds = roll and roll:FindFirstChild("Odds")
	if not (odds and string.find(odds.Text, "LEGENDARY", 1, true)) then
		problem("THE SHOP: the odds on the banner")
	end
	for _, kind in { "Soda", "Item" } do
		table.clear(fired)
		click(shop:FindFirstChild("Deliver" .. kind, true))
		if not (fired[1] and fired[1][2] == "Deliver" and fired[1][3] == kind) then
			problem("THE SHOP: " .. kind .. " delivery orders a drone")
		end
	end
	-- the roll's reveal: face-down cards, flipped one after another
	PlayVFX.OnClientEvent:Fire("EmoteRoll", nil, { Got = { "Wave", "DadMode" }, Pick = 1 })
	task.wait(0.1)
	local reveal = hudGui:FindFirstChild("EmoteReveal")
	local row = reveal and reveal:FindFirstChildWhichIsA("Frame")
	if not (reveal and reveal.Visible) then
		problem("THE ROLL: the reveal comes up")
	end
	local cardsN = 0
	for _, d in reveal and reveal:GetDescendants() or {} do
		if d.Name == "Face" then
			cardsN += 1
		end
	end
	if cardsN ~= 2 then
		problem("THE ROLL: a card for each (" .. cardsN .. ")")
	end
	task.wait(1.4)
	local named = 0
	for _, d in reveal and reveal:GetDescendants() or {} do
		if d.Name == "EmoteName" and d.Visible then
			named += 1
		end
	end
	local nice = reveal and reveal:FindFirstChild("Nice")
	if named ~= 2 or not (nice and nice.Visible) then
		problem("THE ROLL: ...all turned face up, then NICE! (" .. named .. ")")
	end
	setAttr(localPlayer, "EmotePicks", 1)
	task.wait(0.05)
	click(nice)
	local pick = hudGui:FindFirstChild("EmotePick")
	if not (pick and pick.Visible) then
		problem("THE ROLL: a 10x roll's tenth: pick it yourself")
	end
	table.clear(fired)
	click(pick and pick:FindFirstChild("Pick_Nap", true))
	if not (fired[1] and fired[1][2] == "PickEmote" and fired[1][3] == "Nap") then
		problem("THE PICK: tap one to take it")
	end
	setAttr(localPlayer, "EmotePicks", nil)
	-- codes
	HUD.ShopTab("Rewards")
	local box = shop:FindFirstChild("Code", true)
	box.Text = "PLUSULTRA"
	table.clear(fired)
	click(shop:FindFirstChild("Redeem", true))
	if not (fired[1] and fired[1][2] == "Redeem" and fired[1][3] == "PLUSULTRA") then
		problem("REWARDS: redeem a code")
	end
	-- the shopkeeper
	local bubble = shop:FindFirstChild("Bubble")
	click(shop:FindFirstChild("Poke", true))
	if not (bubble and bubble.Visible and table.find({ "OW!", "Hey!!", "That hurts, you know.", "I'm working here!", "Do you mind?!", "...ow." }, bubble.Text)) then
		problem("THE SHOPKEEPER: poke him (" .. tostring(bubble and bubble.Text) .. ")")
	end
	HUD.ToggleShop(false)
	ticking63 = false
end)
if not ok63 then
	problem("round 63 checks errored: " .. tostring(err63))
end
end

print("== round 64: EXPLOSIVE SPEED back on R in the ult - the crouch, the launch, the lane, the catch, the blast")
do
local ok64, err64 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	ticking64 = true -- (globals: the suite is at its local limit)
	task.spawn(function()
		while ticking64 do
			pcall(function()
				signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			end)
			pcall(function()
				signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			end)
			task.wait(1 / 60)
		end
	end)
	-- the HUD: R is EXPLOSIVE SPEED in Dynamight, the Stun Grenade out of it
	HUD.SetQuirk("Explosion", false, false, true)
	local rslot = hudGui:FindFirstChild("SlotR", true)
	if not (rslot and rslot.Visible and slotSays(rslot, "EXPLOSIVE SPEED")) then
		problem("HUD: in Dynamight the R slot is EXPLOSIVE SPEED")
	end
	HUD.SetQuirk("Explosion", false, false, false)
	if not (rslot and rslot.Visible and slotSays(rslot, "STUN GRENADE")) then
		problem("HUD: ...and the Stun Grenade out of it")
	end
	-- R in the ult asks the server for it
	localPlayer:SetAttribute("Quirk", "Explosion")
	myChar:SetAttribute("Quirk", "Explosion")
	setAttr(localPlayer, "UltActive", true)
	task.wait(0.3)
	table.clear(fired)
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.End, {})
	task.wait(0.1)
	local sentR = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.SPECIAL_INDEX then
			sentR = true
		end
	end
	if not sentR then
		problem("R in Dynamight: EXPLOSIVE SPEED goes to the server")
	end
	task.wait(2.5)
	VFX.Play("ExplosiveSpeedCancel", myChar, {}, true)
	setAttr(localPlayer, "UltActive", false)
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
	task.wait(0.2)

	-- the clips
	for _, name in { "MoveBlitzCrouch", "PoseBlitzFly", "MoveBlitzFlip" } do
		if not VFX.GetClip(name) then
			problem("EXPLOSIVE SPEED: the " .. name .. " clip is in the place")
		end
	end
	local body = makeR6("Blitz64", Vector3.new(230, 3, 0))
	body.Torso.Size = Vector3.new(2, 2, 1)
	body.Head.Size = Vector3.new(2, 1, 1)
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		body[n].Size = Vector3.new(1, 2, 1)
	end
	local target = makeR6("BlitzTarget64", Vector3.new(230, 3, -40))
	local rs, rj = body.Torso["Right Shoulder"], body.HumanoidRootPart.RootJoint
	local rsRest, rjRest = rs.C0, rj.C0
	local function fresh(before, filter)
		local out = {}
		for _, d in VFX.Folder:GetDescendants() do
			if not before[d] and (not filter or filter(d)) then
				table.insert(out, d)
			end
		end
		return out
	end
	local function mark()
		local seen = {}
		for _, d in VFX.Folder:GetDescendants() do
			seen[d] = true
		end
		return seen
	end
	local named = function(name)
		return function(d)
			return d.Name == name
		end
	end
	local FWD = Vector3.new(0, 0, -1)
	local ES = Config.Quirks.Explosion.Ult.Special
	-- (the camera on the scene: the slow motion is for anyone near it)
	local cam = workspace.CurrentCamera
	local camWas, focusWas = cam.CFrame, cam.Focus
	cam.CFrame = r.CFrame.lookAt(Vector3.new(230, 8, 12), Vector3.new(230, 3, -20))
	cam.Focus = r.CFrame.new(230, 3, -20)

	-- 1: THE CROUCH: sunk low, arms swept back; the street cracking, grit
	-- lifting, both palms swelling white-hot, the beads popping
	local seen = mark()
	VFX.Play("ExplosiveSpeed", body, { Dir = FWD }, false)
	task.wait(0.4)
	local arm = rsRest:Inverse() * rs.C0
	local sink = (rjRest:Inverse() * rj.C0).Position.Y
	local _, _, back = arm:ToEulerAnglesXYZ()
	if not (math.abs(math.deg(back)) > 25 and sink < -0.3) then
		problem(string.format("THE CROUCH (clip): sunk low (%.2f), arms swept back (%.0f degrees)", sink, math.deg(back)))
	end
	local cracks, grit, glows = #fresh(seen, named("BlitzCrack")), #fresh(seen, named("BlitzGrit")), #fresh(seen, named("BlitzPalmGlow"))
	if cracks < 5 or grit < 5 or glows ~= 2 then
		problem(string.format("THE CROUCH: the street cracks under him (%d), grit lifts off it (%d), both palms glow (%d)", cracks, grit, glows))
	end
	local beads = #fresh(seen, function(d)
		return d:IsA("BasePart") and d.Material == Enum.Material.Neon
	end)
	if beads < 8 then
		problem("THE CROUCH: the beads popping all over him (" .. beads .. ")")
	end
	task.wait(ES.WindUp - 0.4 + 0.1)
	if #fresh(seen, named("BlitzPalmGlow")) > 0 then
		problem("THE CROUCH: ...the palm glows gone when he goes")
	end

	-- 2: THE LAUNCH: palm jets, a sonic boom, a burning streak down the lane,
	-- and the street going off behind him
	seen = mark()
	VFX.Play("ExplosiveSpeedGo", body, { From = Vector3.new(230, 3, 0), Dir = FWD, Length = 37, Speed = ES.Speed }, false)
	task.wait(0.1)
	local streak = fresh(seen, named("BlitzStreak"))[1]
	if not (streak and math.abs(streak.Size.Z - 37) < 1) then
		problem("THE LAUNCH: a burning streak the length of the lane")
	end
	local rings = #fresh(seen, function(d)
		return d:IsA("BasePart") and d.Shape == Enum.PartType.Cylinder and d.Material == Enum.Material.ForceField
	end)
	if rings < 3 then
		problem("THE LAUNCH: a sonic boom off the front of him (" .. rings .. " rings)")
	end
	local laneSeen = mark()
	task.wait(0.3)
	local laneBlasts = #fresh(laneSeen, function(d)
		return d:IsA("BasePart") and d.Shape == Enum.PartType.Ball and d.CFrame.Position.Z < -8
	end)
	if laneBlasts < 5 then
		problem("THE LAUNCH: the street going off down the lane behind him (" .. laneBlasts .. ")")
	end
	if not body.HumanoidRootPart:FindFirstChildOfClass("Trail") then
		problem("THE LAUNCH: a fire trail off him")
	end

	-- 3: THE CATCH: time crawls, a flare swells in his palm, heat ripples off it
	seen = mark()
	VFX.Play("ExplosiveSpeedCatch", body, { Target = target, Pos = Vector3.new(230, 3, -40), Dir = FWD, Time = ES.SlowMo }, false)
	task.wait(0.5)
	local slow = false
	for _, e in Lighting:GetChildren() do
		if e.Name == "BlitzSlowMo" then
			slow = true
		end
	end
	local flare = fresh(seen, named("BlitzFlare"))[1]
	local bb = flare and flare:FindFirstChildOfClass("BillboardGui")
	if not (slow and bb and bb.Size.X.Scale > 1.5) then
		problem(string.format("THE CATCH: time slows, a flare swelling in his palm (%s)", tostring(bb and bb.Size.X.Scale)))
	end
	if #fresh(seen, named("BlitzRipple")) < 1 then
		problem("THE CATCH: heat rippling off his palm")
	end
	task.wait(ES.SlowMo - 0.5)

	-- 4: THE EXPLOSION: the flash, time snapped back, the flare gone; the
	-- one it hits flies off trailing fire
	seen = mark()
	VFX.Play("ExplosiveSpeedBlast", body, { Pos = Vector3.new(230, 3, -40), Dir = FWD, Target = target }, false)
	task.wait(0.05)
	slow = false
	for _, e in Lighting:GetChildren() do
		if e.Name == "BlitzSlowMo" then
			slow = true
		end
	end
	if slow then
		problem("THE EXPLOSION: time snaps back")
	end
	if #fresh(seen, named("BlitzFlash")) ~= 1 or #fresh(seen) < 30 then
		problem("THE EXPLOSION: a white flash and a big layered blast (" .. #fresh(seen) .. " pieces)")
	end
	if not target.HumanoidRootPart:FindFirstChildOfClass("Trail") then
		problem("THE EXPLOSION: the one it hits flies off trailing fire")
	end
	task.wait(0.3)
	local anyFlare = false
	for _, d in VFX.Folder:GetDescendants() do
		if d.Name == "BlitzFlare" then
			anyFlare = true
		end
	end
	if anyFlare then
		problem("THE EXPLOSION: ...the palm's flare gone")
	end

	-- 5: NOBODY IN THE LANE: skids to a stop
	seen = mark()
	VFX.Play("ExplosiveSpeedWhiff", body, { Pos = Vector3.new(230, 3, -75), Dir = FWD }, false)
	task.wait(0.05)
	if #fresh(seen, named("BlitzSkid")) ~= 2 then
		problem("THE WHIFF: two skid marks behind his feet")
	end
	-- 6: CALLED OFF in the slow motion: the screen comes back
	VFX.Play("ExplosiveSpeed", body, { Dir = FWD }, false)
	VFX.Play("ExplosiveSpeedCatch", body, { Target = target, Pos = Vector3.new(230, 3, -40), Dir = FWD, Time = 3 }, false)
	task.wait(0.2)
	VFX.Play("ExplosiveSpeedCancel", body, {}, false)
	task.wait(0.1)
	for _, e in Lighting:GetChildren() do
		if e.Name == "BlitzSlowMo" then
			problem("CALLED OFF: the screen comes back")
			break
		end
	end
	task.wait(1)
	body:Destroy()
	target:Destroy()
	cam.CFrame, cam.Focus = camWas, focusWas
	ticking64 = false
end)
if not ok64 then
	problem("round 64 checks errored: " .. tostring(err64))
end
end

print("== round 65: the back dash (backflip into a handstand), instant looking round, dashing out of an M1, the chase dash, AUTO RUN, parkour clips")
do
local ok65, err65 = pcall(function()
	local MV = Config.Movement
	myRoot.AssemblyMass = 12 -- (the harness has no physics)
	local anims65 = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1]
	local RS65 = game:GetService("ReplicatedStorage")
	if not RS65:FindFirstChild("Animations") then
		r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1].Parent = RS65
	end
	-- 1: THE BACK DASH clip: up, over, onto the hands, onto the feet
	local body = makeR6("Back65", Vector3.new(90, 3, 0))
	body.Torso.Size = Vector3.new(2, 2, 1)
	body.Head.Size = Vector3.new(2, 1, 1)
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		body[n].Size = Vector3.new(1, 2, 1)
	end
	local rj = body.HumanoidRootPart.RootJoint
	local rest = rj.C0
	local function tilt()
		local off = rest:Inverse() * rj.C0
		return math.deg(math.acos(math.clamp(off:VectorToWorldSpace(Vector3.new(0, 1, 0)).Y, -1, 1)))
	end
	if not (anims65:FindFirstChild("DashBack") and anims65.DashBack:FindFirstChild("Hands") and anims65.DashBack:FindFirstChild("Land")) then
		problem("THE BACK DASH: the clip has its handstand and landing keys")
	end
	local t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(0, 0, 1), Kind = "Back" }, false)
	local maxFlip, hands = 0, 0
	while os.clock() - t0 < 0.36 do
		maxFlip = math.max(maxFlip, tilt())
		task.wait(1 / 60)
	end
	while os.clock() - t0 < 0.62 do
		hands = math.max(hands, tilt())
		task.wait(1 / 60)
	end
	if maxFlip < 150 then
		problem(string.format("THE BACK DASH: a backflip first - over the top in the air (%.0f degrees)", maxFlip))
	end
	if hands < 165 then
		problem(string.format("THE BACK DASH: ...then upside down on his hands (%.0f degrees)", hands))
	end
	task.wait(math.max(0.98 - (os.clock() - t0), 0))
	if tilt() > 45 then
		problem(string.format("THE BACK DASH: ...then onto his feet (%.0f degrees at 0.98s)", tilt()))
	end
	task.wait(1.07 + 0.3)
	if tilt() > 1 then
		problem("THE BACK DASH: afterwards standing again")
	end
	body:Destroy()

	-- 2: the back dash steers with the camera, and goes about as far as a front dash
	local was = cam.CFrame
	local function lv()
		for _, c in myRoot:GetChildren() do
			if c:IsA("LinearVelocity") and c.Attachment0 and c.Attachment0.Name == "MobilityDashAttachment" then
				return Vector3.new(c.PlaneVelocity.X, 0, c.PlaneVelocity.Y)
			end
		end
		return nil
	end
	localPlayer:SetAttribute("Quirk", "Explosion")
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	cam.CFrame = r.CFrame.new(0, 5, 10) -- (looking down -Z)
	myHum.MoveDirection = Vector3.new(0, 0, 1)
	table.clear(fired)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.05)
	local v0 = lv()
	cam.CFrame = r.CFrame.new(0, 5, 0) * r.CFrame.Angles(0, -math.pi / 2, 0) -- (swung round to +X)
	task.wait(0.08)
	local v1 = lv()
	local sentBack = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.DASH_INDEX and f[4] == "Back" then
			sentBack = true
		end
	end
	if not sentBack or not v0 or v0.Z < MV.DashSpeed * MV.BackDashSpeed * 0.9 then
		problem("THE BACK DASH: holding back, dash goes back (" .. tostring(v0) .. ")")
	end
	if not v1 or v1.X > -MV.DashSpeed * MV.BackDashSpeed * 0.6 then
		problem("THE BACK DASH: ...and steers with the camera (" .. tostring(v1) .. ")")
	end
	task.wait(MV.BackDashTime + 0.1)
	if lv() then
		problem("THE BACK DASH: its push ends after " .. MV.BackDashTime .. "s")
	end
	task.wait(MV.MobilityDashCooldown + 0.2)
	myHum.MoveDirection = Vector3.zero
	cam.CFrame = was

	-- 3: a side dash cuts into your own M1 (a front dash doesn't)
	task.wait(0.4)
	table.clear(fired)
	cam.CFrame = r.CFrame.new(0, 5, 10)
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
	task.wait(0.03)
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	local punched, sideAfter = false, false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == 0 then
			punched = true
		elseif punched and f[1] == "UseAbility" and f[2] == Config.DASH_INDEX and (f[4] == "Right" or f[4] == "Left") then
			sideAfter = true
		end
	end
	if not (punched and sideAfter) then
		problem("DASH OUT OF AN M1: a side dash straight after a punch goes (JJS)")
	end
	task.wait(MV.SideDashTime + MV.MobilityDashCooldown + 0.3)
	table.clear(fired)
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
	task.wait(0.03)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.DASH_INDEX then
			problem("DASH OUT OF AN M1: ...but a front dash waits for the swing")
			break
		end
	end
	myHum.MoveDirection = Vector3.zero
	task.wait(1.2)

	-- 4: the chase dash - front dash cooling down, someone running from you
	local runner = Instance.new("Player")
	runner.Name = "Runner65"
	runner.Parent = Players
	local rChar = makeR6("Runner65Body", Vector3.new(0, 3, -20))
	runner.Character = rChar
	rChar.HumanoidRootPart.CFrame = r.CFrame.new(0, 3, -20) -- (back to you: facing -Z, away)
	rChar.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -24)
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	table.clear(fired)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(MV.FrontDashTime + MV.FrontWhiffRecovery + 0.1)
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	local kinds = {}
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.DASH_INDEX and f[4] ~= "Punch" then
			table.insert(kinds, tostring(f[4]))
		end
	end
	if kinds[1] ~= "Front" or kinds[2] ~= "Chase" then
		problem("THE CHASE DASH: front dash cooling down, they're running from you: dash throws you after them (" .. table.concat(kinds, ",") .. ")")
	end
	task.wait(0.4)
	-- (they turn to face you: no chase dash)
	task.wait(MV.MobilityDashCooldown)
	rChar.HumanoidRootPart.CFrame = r.CFrame.new(0, 3, -20) * r.CFrame.Angles(0, math.pi, 0) -- (facing you)
	table.clear(fired)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.DASH_INDEX then
			problem("THE CHASE DASH: ...not on someone facing you (" .. tostring(f[4]) .. ")")
		end
	end
	runner.Parent = nil
	rChar:Destroy()
	myHum.MoveDirection = Vector3.zero
	task.wait(MV.FrontDashCooldown)

	-- 5: AUTO RUN
	local base = myChar:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(0.2)
	if myHum.WalkSpeed > base + 0.5 then
		problem("AUTO RUN: off, moving is walking")
	end
	setAttr(localPlayer, "AutoRun", true)
	task.wait(0.3)
	if myHum.WalkSpeed < base * MV.SprintMultiplier * 0.8 then
		problem("AUTO RUN: on, moving is running (" .. myHum.WalkSpeed .. ")")
	end
	local row = hudGui:FindFirstChild("AutoRun", true)
	local switch = row and row:FindFirstChild("Switch")
	if not (switch and switch.Text == "ON") then
		problem("AUTO RUN: the settings panel shows it ON")
	end
	setAttr(localPlayer, "AutoRun", false)
	task.wait(0.3)
	if myHum.WalkSpeed > base + 0.5 or not (switch and switch.Text == "OFF") then
		problem("AUTO RUN: ...and off again")
	end
	myHum.MoveDirection = Vector3.zero

	-- 6: LOOKING ROUND on a controller: the right stick turns the camera at once
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	lastInputType = Enum.UserInputType.Gamepad1
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	cam.CameraType = Enum.CameraType.Custom
	cam.CFrame = r.CFrame.new(0, 8, 12) * r.CFrame.fromEulerAnglesYXZ(-0.3, 0, 0)
	local padLook = actions.QuirkPadLook
	if not padLook then
		problem("LOOKING ROUND: the controller look is bound")
	else
		local res = padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.zero, KeyCode = Enum.KeyCode.Thumbstick2 })
		if res ~= Enum.ContextActionResult.Pass then
			problem("LOOKING ROUND: a centred stick still reaches Roblox's camera first (it must see it let go)")
		end
		res = padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.new(1, 0, 0), KeyCode = Enum.KeyCode.Thumbstick2 })
		if res ~= Enum.ContextActionResult.Sink then
			problem("LOOKING ROUND: ...then the stick is ours (Roblox's eased camera doesn't see it)")
		end
		local function yaw()
			local l = cam.CFrame.LookVector
			return math.deg(math.atan2(-l.X, -l.Z))
		end
		local frames = 0
		local counter = signalOf(game:GetService("RunService"), "RenderStepped"):Connect(function()
			frames += 1
		end)
		local function perFrame(stick, time, f)
			stick2Pos = stick
			task.wait(0.3) -- (the first strong push: a few frames of checking first)
			local f0, y0, p0 = frames, yaw(), cam.CFrame.LookVector.Y
			task.wait(time)
			local n = math.max(frames - f0, 1)
			return f(y0, p0) / n
		end
		local full = perFrame(Vector3.new(1, 0, 0), 0.3, function(y0)
			return (y0 - yaw() + 180) % 360 - 180
		end)
		local want = (Config.Look.Pad.Speed or 250) / 60
		if full < want * 0.85 or full > want * 1.15 then
			problem(string.format("LOOKING ROUND: stick right turns the view right at once, full speed (%.2f degrees a frame, want %.2f)", full, want))
		end
		-- a small push turns it too, in proportion (no dead start)
		local small = perFrame(Vector3.new(0.35, 0, 0), 0.3, function(y0)
			return (y0 - yaw() + 180) % 360 - 180
		end)
		if small < want * 0.08 or small > want * 0.4 then
			problem(string.format("LOOKING ROUND: a small push turns it slower, but at once (%.2f degrees a frame)", small))
		end
		-- up on the stick looks up
		local up = perFrame(Vector3.new(0, 1, 0), 0.15, function(_, p0)
			return cam.CFrame.LookVector.Y - p0
		end)
		if up <= 0 then
			problem("LOOKING ROUND: stick up looks up")
		end
		stick2Pos = Vector3.zero
		counter:Disconnect()
		-- the emote wheel open: the stick picks an emote, the camera stays put
		HUD.ShowEmoteWheel(true)
		task.wait(0.05)
		stick2Pos = Vector3.new(1, 0, 0)
		local yw = yaw()
		task.wait(0.2)
		if math.abs(yaw() - yw) > 0.5 then
			problem("LOOKING ROUND: the emote wheel open, the stick picks an emote - the camera stays put")
		end
		stick2Pos = Vector3.zero
		HUD.ShowEmoteWheel(false)
		task.wait(0.05)
		-- a menu open: the stick drives the menu, not the camera
		HUD.ToggleShop(true)
		task.wait(0.05)
		res = padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.new(1, 0, 0), KeyCode = Enum.KeyCode.Thumbstick2 })
		if res ~= Enum.ContextActionResult.Pass then
			problem("LOOKING ROUND: ...a menu open, it leaves the stick alone")
		end
		HUD.ToggleShop(false)
		padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.zero, KeyCode = Enum.KeyCode.Thumbstick2 })
	end
	lastInputType = Enum.UserInputType.Keyboard
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	cam.CFrame = was
	-- (and the mouse: shift lock turns the body the same frame; the head keeps up)
	local ssl = fs.readFile(SRC .. "/Workspace.MovementSystem.StarterPlayerScripts.CustomShiftLock.SmoothShiftLock.lua")
	if not ssl:find('%["CHARACTER_SMOOTH_ROTATION"%]%s*=%s*false') then
		problem("SHIFT LOCK: the body turns with the camera the same frame (no easing)")
	end
	local head = fs.readFile(SRC .. "/Workspace.MovementSystem.StarterCharacterScript.Realistic Head Movement.client.lua")
	if not head:find("math.exp", 1, true) then
		problem("THE HEAD: follows the look at any frame rate, faster")
	end

	-- 7: the parkour moves play their keyframed clips (R6)
	for _, name in { "MovePkVault", "MovePkMantle", "MovePkClimb", "MovePkSlide", "MovePkWallRunL", "MovePkWallRunR", "MovePkWallKick", "MovePkRoll" } do
		if not VFX.GetClip(name) then
			problem("PARKOUR: the " .. name .. " clip is in the place")
		end
	end
	local pk = makeR6("Pk65", Vector3.new(120, 3, 0))
	pk.Torso.Size = Vector3.new(2, 2, 1)
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		pk[n].Size = Vector3.new(1, 2, 1)
	end
	local hip = pk.Torso["Right Hip"]
	local hipRest = hip.C0
	for _, kind in { "Vault", "Mantle", "Slide", "Roll" } do
		VFX.Play("Parkour", pk, { Kind = kind, Dir = Vector3.new(0, 0, -1), Side = "R", Time = 0.4 }, false)
		task.wait(0.12)
		local moved = math.deg(math.acos(math.clamp((hipRest:Inverse() * hip.C0).UpVector.Y, -1, 1)))
		if moved < 20 then
			problem(string.format("PARKOUR: the %s clip moves the legs (%.0f degrees)", kind, moved))
		end
		task.wait(0.8)
	end
	pk:Destroy()
	localPlayer:SetAttribute("Quirk", nil)
end)
if not ok65 then
	problem("round 65 scenario crashed: " .. tostring(err65))
end
end

print("== round 67 (round 66 on the user's upload): the back dash's twist, handstand and landing - quicker; the F2 console; no Hero License; the Support Drop; Crazy Diamond's Stand M1s")
do
local ok66, err66 = pcall(function()
	local MV = Config.Movement
	myRoot.AssemblyMass = 12
	local anims66 = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1]
	local RS66 = game:GetService("ReplicatedStorage")
	if not RS66:FindFirstChild("Animations") then
		r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "Animations.rbxm"))[1].Parent = RS66
	end

	-- 1: THE BACK DASH clip: the twist while he's flat in the air, the longer
	-- handstand, the superhero landing
	local db = anims66:FindFirstChild("DashBack")
	if not (db and db:FindFirstChild("Twist") and db:FindFirstChild("Hands") and db:FindFirstChild("Land")) then
		problem("BACK DASH 66: the clip has its twist, handstand and landing keys")
	end
	local BT = MV.BackDashBeats or {}
	if db and db:FindFirstChild("Hands") and db:FindFirstChild("Land") then
		if math.abs(db.Hands.Time - BT.Hands) > 0.02 or math.abs(db.Land.Time - BT.Land) > 0.02 or math.abs(db.Twist.Time - BT.Twist) > 0.02 then
			problem(string.format("BACK DASH 66: the effects keep time with the clip (hands %.2f / %.2f, land %.2f / %.2f)", db.Hands.Time, BT.Hands, db.Land.Time, BT.Land))
		end
	end
	-- (round 67) all of it a little quicker: the clip is x0.85 (1.26s -> 1.07s)
	local P67 = 0.85
	local lastKey = 0
	for _, kf in (db and db:GetChildren() or {}) do
		if kf:IsA("Keyframe") then
			lastKey = math.max(lastKey, kf.Time)
		end
	end
	if not (lastKey > 1 and lastKey < 1.1 and BT.Land < 0.78) then
		problem(string.format("BACK DASH 67: a little quicker (the clip %.2fs, was 1.26; the landing at %.2fs, was 0.87)", lastKey, BT.Land or -1))
	end
	local body = makeR6("Back66", Vector3.new(120, 3, 0))
	body.Torso.Size = Vector3.new(2, 2, 1)
	body.Head.Size = Vector3.new(2, 1, 1)
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		body[n].Size = Vector3.new(1, 2, 1)
	end
	local rj = body.HumanoidRootPart.RootJoint
	local rest = rj.C0
	local function off()
		return rest:Inverse() * rj.C0
	end
	local function angleBetween(a, b)
		local _, ang = (a:Inverse() * b):ToAxisAngle()
		return math.deg(math.abs(ang))
	end
	local function tilt()
		return math.deg(math.acos(math.clamp(off():VectorToWorldSpace(Vector3.new(0, 1, 0)).Y, -1, 1)))
	end
	local samples = {}
	local t0 = os.clock()
	VFX.Play("Dash", body, { Dir = Vector3.new(0, 0, 1), Kind = "Back" }, false)
	local handsFrames, lowest = 0, 0
	while os.clock() - t0 < 1.0 do
		local t = os.clock() - t0
		table.insert(samples, { t = t, cf = off() })
		if t > BT.Hands - 0.02 and t < BT.Hands + 0.2 * P67 and tilt() > 160 then
			handsFrames += 1
		end
		if t > BT.Land and t < BT.Land + 0.12 then
			lowest = math.max(lowest, -off().Position.Z, off().Position.Magnitude)
		end
		task.wait(1 / 60)
	end
	local function at(t)
		local best = samples[1]
		for _, s in samples do
			if math.abs(s.t - t) < math.abs(best.t - t) then
				best = s
			end
		end
		return best.cf
	end
	-- (a quarter turn a key: a half turn apart two keys on, back round by four)
	local a0 = at(BT.Twist)
	local half = angleBetween(a0, at(BT.Twist + 0.08 * P67))
	local quarter = angleBetween(a0, at(BT.Twist + 0.04 * P67))
	local full = angleBetween(a0, at(BT.Twist + 0.16 * P67))
	if not (half > 140 and quarter > 60 and quarter < 125 and full < 60) then
		problem(string.format("BACK DASH 66: a full 360 on his own axis while he's flat in the air (quarter %.0f, half %.0f, all the way round %.0f degrees)", quarter, half, full))
	end
	if handsFrames < 6 then
		problem("BACK DASH 66: the handstand is held (" .. handsFrames .. " frames upside down)")
	end
	if lowest < 0.8 then
		problem(string.format("BACK DASH 66: ...and he lands low - the superhero landing (%.2f)", lowest))
	end
	task.wait(0.7)
	if tilt() > 2 then
		problem("BACK DASH 66: afterwards standing again")
	end
	body:Destroy()

	-- 2: its pace: flat out through the flip, drifting on his hands
	local function lv()
		for _, c in myRoot:GetChildren() do
			if c:IsA("LinearVelocity") and c.Attachment0 and c.Attachment0.Name == "MobilityDashAttachment" then
				return Vector3.new(c.PlaneVelocity.X, 0, c.PlaneVelocity.Y)
			end
		end
		return nil
	end
	task.wait(MV.MobilityDashCooldown + 0.3)
	localPlayer:SetAttribute("Quirk", "Explosion")
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	cam.CFrame = r.CFrame.new(0, 5, 10)
	myHum.MoveDirection = Vector3.new(0, 0, 1)
	local d0 = os.clock()
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(math.max(0.3 - (os.clock() - d0), 0))
	local fast = lv()
	task.wait(math.max(BT.Hands + 0.06 - (os.clock() - d0), 0))
	local slow = lv()
	local full66 = MV.DashSpeed * MV.BackDashSpeed
	if not fast or fast.Magnitude < full66 * 0.9 then
		problem("BACK DASH 66: flat out through the flip (" .. tostring(fast) .. ")")
	end
	if not slow or slow.Magnitude > full66 * 0.45 then
		problem("BACK DASH 66: ...drifting while he's on his hands (" .. tostring(slow) .. ")")
	end
	myHum.MoveDirection = Vector3.zero
	task.wait(MV.BackDashTime + 0.2)

	-- 3: THE CONSOLE (F2)
	local cg = playerGui:FindFirstChild("QuirkConsole")
	local croot = cg and cg:FindFirstChild("Console")
	local box = croot and croot:FindFirstChild("Input") and croot.Input:FindFirstChildOfClass("TextBox")
	local CR = remotes:FindFirstChild("Console")
	if not (croot and box and CR) then
		problem("CONSOLE: built for everyone")
	else
		local function logLabels()
			local out = {}
			for _, c in croot.Log:GetChildren() do
				if c:IsA("TextLabel") then
					table.insert(out, c)
				end
			end
			return out
		end
		table.clear(fired)
		uis.InputBegan:Fire({ KeyCode = Enum.KeyCode.F2, UserInputType = Enum.UserInputType.Keyboard }, false)
		task.wait(0.05)
		if not HUD.ConsoleVisible() then
			problem("CONSOLE: F2 opens it")
		end
		signalOf(CR, "OnClientEvent"):Fire("Sync", {
			Log = { { Text = "Server started", Kind = "event", Time = 0 }, { Text = "Alpha> kills 5", Kind = "cmd", Time = 0 }, { Text = "+5 KOs for Alpha", Kind = "ok", Time = 0 } },
			Commands = { { Name = "kills", Usage = "kills <amount> [who]", Help = "Add KOs" }, { Name = "help", Usage = "help [command]", Help = "Every command" } },
			Owner = false,
		})
		task.wait(0.05)
		if #logLabels() ~= 3 then
			problem("CONSOLE: opening it shows the server's log so far (" .. #logLabels() .. " lines)")
		end
		if box.TextEditable ~= false or not string.find(box.PlaceholderText, "View only", 1, true) then
			problem("CONSOLE: a viewer sees it read-only")
		end
		table.clear(fired)
		box.Text = "kills 99"
		signalOf(box, "FocusLost"):Fire(true)
		task.wait(0.05)
		for _, f in fired do
			if f[1] == "Console" and f[2] == "Run" then
				problem("CONSOLE: ...and nothing a viewer types is sent")
			end
		end
		setAttr(localPlayer, "ConsoleOwner", true)
		task.wait(0.05)
		local badge
		for _, d in croot:GetDescendants() do
			if d:IsA("TextLabel") and (d.Text == "OWNER" or d.Text == "VIEW ONLY") then
				badge = d
			end
		end
		if box.TextEditable ~= true or not badge or badge.Text ~= "OWNER" then
			problem("CONSOLE: the owner gets the input")
		end
		box.Text = "kil"
		signalOf(box, "prop:Text"):Fire()
		if not string.find(croot.Hint.Text, "kills <amount>", 1, true) then
			problem("CONSOLE: a hint of what the word being typed does (" .. croot.Hint.Text .. ")")
		end
		table.clear(fired)
		box.Text = "kills 5"
		signalOf(box, "FocusLost"):Fire(true)
		task.wait(0.05)
		local ran = false
		for _, f in fired do
			if f[1] == "Console" and f[2] == "Run" and f[3] == "kills 5" then
				ran = true
			end
		end
		if not ran or box.Text ~= "" then
			problem("CONSOLE: Enter sends the owner's command to the server (and clears the line)")
		end
		signalOf(CR, "OnClientEvent"):Fire("Line", { Text = "+5 KOs for Tester", Kind = "ok", Time = 0 })
		task.wait(0.05)
		local last
		for _, l in logLabels() do
			if string.find(l.Text, "+5 KOs for Tester", 1, true) then
				last = l
			end
		end
		if not last or last.TextColor3.G < last.TextColor3.R then
			problem("CONSOLE: the server's answer shows up (green: it worked)")
		end
		table.clear(fired)
		box.Text = "clear"
		signalOf(box, "FocusLost"):Fire(true)
		task.wait(0.05)
		if #logLabels() ~= 0 or #fired > 0 then
			problem("CONSOLE: 'clear' clears your own view (and isn't sent)")
		end
		uis.InputBegan:Fire({ KeyCode = Enum.KeyCode.F2, UserInputType = Enum.UserInputType.Keyboard }, true)
		task.wait(0.05)
		if HUD.ConsoleVisible() then
			problem("CONSOLE: F2 closes it (even while typing)")
		end
	end

	-- 4: (round 67) NO HERO LICENSE: a player with no hero yet gets the phone,
	-- and tapping a hero on it picks them straight away
	if HUD.ShowHeroSelect ~= nil or HUD.HeroSelectVisible ~= nil or playerGui:FindFirstChild("QuirkHeroSelect", true) or Config.HeroSelect ~= nil then
		problem("NO HERO LICENSE: it's gone (the HUD, the screen, the setting)")
	end
	if not Config.__startPhone67 then
		problem("NO HERO LICENSE: a player with no hero yet starts on the phone")
	end
	do
		HUD.ShowMenu(true)
		local menu = hudGui and hudGui:FindFirstChild("QuirkMenu") or playerGui:FindFirstChild("QuirkMenu", true)
		local row = menu and menu:FindFirstChild("FullCowl", true)
		table.clear(fired)
		if row then
			signalOf(row, "Activated"):Fire()
			task.wait(0.05)
		end
		local picked = false
		for _, f in fired do
			if f[1] == "SelectQuirk" and f[2] == "FullCowl" then
				picked = true
			end
		end
		if not (row and picked and not HUD.MenuVisible()) then
			problem("NO HERO LICENSE: the phone's hero list picks the one you tap, straight away")
		end
		HUD.ShowMenu(false)
	end

	-- 5: THE SUPPORT DROP
	local drop = { Id = 66, Pos = Vector3.new(60, 0, 60), From = Vector3.new(60, 170, 0), Time = 0.4, Open = 0.2, Name = "Tester", Icon = "🥤", Despawn = 3 }
	VFX.Play("SupportDrop", nil, drop)
	task.wait(0.15)
	local pod = VFX.Folder:FindFirstChild("SupportPod")
	if not pod then
		problem("SUPPORT DROP: the pod comes down on everyone's screen")
	else
		local function top()
			local y = -math.huge
			for _, p in pod:GetChildren() do
				if p:IsA("BasePart") and p.Parent == pod then
					y = math.max(y, p.CFrame.Position.Y)
				end
			end
			return y
		end
		local y1 = top()
		task.wait(0.35)
		local y2 = top()
		if not (y1 > 30 and y2 < 8) then
			problem(string.format("SUPPORT DROP: ...out of the sky onto the ring (%.0f then %.1f)", y1, y2))
		end
		task.wait(0.35)
		VFX.Play("SupportDropDone", nil, { Id = 66, Taken = true })
		task.wait(0.5)
		local shownParts = 0
		for _, p in pod:GetChildren() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				shownParts += 1
			end
		end
		if VFX.POD.drops[66] ~= nil or shownParts > 0 then
			problem("SUPPORT DROP: taken: the pod sinks away (" .. shownParts .. " parts still showing)")
		end
	end

	-- 6: CRAZY DIAMOND: the Stand throws the M1s; Josuke points
	local josuke = makeR6("Josuke66", Vector3.new(140, 3, 0))
	local jp = Instance.new("Player")
	jp.Name = "Josuke66"
	jp.Parent = Players
	jp.Character = josuke
	jp:SetAttribute("Quirk", "CrazyDiamond")
	-- (what Josuke himself does: a punch clip, or a pose)
	local realClip, realPose, clips, poses = VFX.Clip, VFX.Pose, {}, {}
	VFX.Clip = function(c, name, ...)
		if c == josuke then
			table.insert(clips, name)
		end
		return realClip(c, name, ...)
	end
	VFX.Pose = function(c, name, ...)
		if c == josuke then
			table.insert(poses, name)
		end
		return realPose(c, name, ...)
	end
	VFX.Play("Punch", josuke, { Count = 1, Finisher = false }, false)
	task.wait(0.2)
	local jr = josuke.HumanoidRootPart.CFrame.Position
	local front, stands = 0, 0
	for _, m in VFX.Folder:GetChildren() do
		if m.Name == "CrazyDiamond" and m:IsA("Model") then
			stands += 1
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and (p.CFrame.Position - jr).Magnitude < 12 then
					front = math.max(front, (jr - p.CFrame.Position):Dot(Vector3.new(0, 0, 1)))
				end
			end
		end
	end
	if stands == 0 then
		problem("CRAZY DIAMOND: an M1 brings the Stand out")
	else
		if front < 4 then
			problem(string.format("CRAZY DIAMOND: the Stand throws it, out in front of him (%.1f studs)", front))
		end
	end
	VFX.Clip, VFX.Pose = realClip, realPose
	for _, name in clips do
		if string.find(name, "M1", 1, true) then
			problem("CRAZY DIAMOND: ...and Josuke doesn't throw a punch himself (" .. name .. ")")
		end
	end
	if poses[1] ~= "StandCommand" then
		problem("CRAZY DIAMOND: ...he points the way (" .. tostring(poses[1]) .. ")")
	end
	task.wait(1)
	jp.Parent = nil
	josuke:Destroy()
end)
if not ok66 then
	problem("round 66 section errored: " .. tostring(err66))
end
end

print("== round 68: the dash punch takes the first one in your path (a gut punch); the ragdoll cancel out of a combo; controller sensitivity; no fight-stance wobble")
do
local ok68, err68 = pcall(function()
	local DASH = Config.DASH_INDEX
	local cam68 = workspace.CurrentCamera
	local function sentDash(kind)
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == DASH and f[4] == kind then
				return f
			end
		end
		return nil
	end
	local function pressDash()
		actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	end
	myHum.Health = myHum.MaxHealth
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.AssemblyMass = 12
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	setAttr(myChar, "Ragdolled", false)
	setAttr(myChar, "Stunned", false)

	-- 1: THE DASH PUNCH - the first one in the lane, not whoever's nearest
	local dummiesF = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
	dummiesF.Name = "Dummies"
	dummiesF.Parent = workspace
	local beside = makeR15("Beside68", Vector3.new(2.9, 3, -1)) -- (nearest, but off to the side: the old cone took them)
	local first = makeR15("First68", Vector3.new(0.6, 3, -3.6))
	local second = makeR15("Second68", Vector3.new(0, 3, -5.4))
	for _, m in { beside, first, second } do
		m.Parent = dummiesF
		m.Humanoid.Health = 100
	end
	cam68.CFrame = r.CFrame.new(0, 5, 10)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(Config.Movement.FrontDashCooldown + 0.1)
	table.clear(fired)
	pressDash()
	task.wait(0.1)
	local punch = sentDash("Punch")
	if not punch or punch[5] ~= first then
		problem("DASH PUNCH 68: the first one in your path takes it, not the nearest off to the side (" .. tostring(punch and punch[5]) .. ")")
	end
	for _, m in { beside, first, second } do
		m:Destroy()
	end
	-- nobody in the lane: no punch (someone off to the side isn't in your path)
	local offside = makeR15("Offside68", Vector3.new(3.2, 3, -2.5))
	offside.Parent = dummiesF
	offside.Humanoid.Health = 100
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	task.wait(Config.Movement.FrontDashCooldown + 0.2)
	table.clear(fired)
	pressDash()
	task.wait(0.15)
	if sentDash("Punch") then
		problem("DASH PUNCH 68: someone off to the side of your dash isn't punched")
	end
	offside:Destroy()
	task.wait(0.5)
	myHum.MoveDirection = Vector3.zero

	-- 2: the gut punch: they double over it
	local puncher = makeR6("Puncher68", Vector3.new(200, 3, 0))
	local victim = makeR6("Victim68", Vector3.new(200, 3, -3))
	local rj = victim.HumanoidRootPart:FindFirstChild("RootJoint")
	local rest = rj and rj.C0
	VFX.Play("DashPunch", puncher, { Target = victim, Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(0.5)
	local bent = 0
	if rj then
		local d = (rest:Inverse() * rj.C0):VectorToWorldSpace(Vector3.new(0, 1, 0))
		bent = math.deg(math.acos(math.clamp(d.Y, -1, 1)))
	end
	if bent < 20 then
		problem(string.format("DASH PUNCH 68: the one punched doubles over it (bent %.0f degrees)", bent))
	end
	puncher:Destroy()
	victim:Destroy()

	-- 3: the ragdoll cancel works out of a combo's hitstun too
	setAttr(myChar, "Evasive", 100)
	setAttr(myChar, "ComboStun", true)
	setAttr(myChar, "Stunned", true)
	task.wait(0.05)
	table.clear(fired)
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	pressDash()
	task.wait(0.05)
	if not sentDash("Evasive") then
		problem("COMBOS 68: DASH in a combo's hitstun, the meter full: the ragdoll cancel")
	end
	setAttr(myChar, "ComboStun", nil)
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Evasive", 0)
	myHum.MoveDirection = Vector3.zero
	task.wait(0.4)

	-- 4: no fight-stance wobble
	if (Config.Animations or {}).FightStance ~= false then
		problem("WOBBLE 68: the fight stance is off")
	end

	-- 5: the settings: CONTROLLER SENSITIVITY (a step at a time) and ROBLOX CAMERA
	HUD.ShowMenu(false)
	local sensRow = hudGui:FindFirstChild("PadSensitivity", true)
	local sensBtn = sensRow and sensRow:FindFirstChild("Switch")
	local rcRow = hudGui:FindFirstChild("RobloxCamera", true)
	local rcBtn = rcRow and rcRow:FindFirstChild("Switch")
	if not (sensBtn and sensBtn.Text == "100%") then
		problem("SETTINGS 68: a CONTROLLER SENSITIVITY row, at 100% (" .. tostring(sensBtn and sensBtn.Text) .. ")")
	end
	if not (rcBtn and rcBtn.Text == "OFF") then
		problem("SETTINGS 68: a ROBLOX CAMERA switch, off (" .. tostring(rcBtn and rcBtn.Text) .. ")")
	end
	if sensBtn then
		table.clear(fired)
		signalOf(sensBtn, "MouseButton1Click"):Fire()
		task.wait(0.05)
		local sent
		for _, f in fired do
			if f[1] == "Settings" and f[2] == "PadSensitivity" then
				sent = f[3]
			end
		end
		if not (sensBtn.Text == "125%" and sent == 1.25) then
			problem("SETTINGS 68: a click steps it up: 125%, saved (" .. sensBtn.Text .. ", " .. tostring(sent) .. ")")
		end
		-- the server's word shows
		setAttr(localPlayer, "PadSensitivity", 2)
		task.wait(0.05)
		if sensBtn.Text ~= "200%" then
			problem("SETTINGS 68: ...and shows the saved value (" .. sensBtn.Text .. ")")
		end
	end

	-- 6: the stick turns the camera x the sensitivity; ROBLOX CAMERA hands it back
	lastInputType = Enum.UserInputType.Gamepad1
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	cam68.CameraType = Enum.CameraType.Custom
	local was68 = cam68.CFrame
	cam68.CFrame = r.CFrame.new(0, 8, 12) * r.CFrame.fromEulerAnglesYXZ(-0.3, 0, 0)
	local padLook = actions.QuirkPadLook
	local function yaw()
		local l = cam68.CFrame.LookVector
		return math.deg(math.atan2(-l.X, -l.Z))
	end
	local function turnOver(sens, time)
		setAttr(localPlayer, "PadSensitivity", sens)
		stick2Pos = Vector3.new(1, 0, 0)
		task.wait(0.1)
		local y0, t0 = yaw(), os.clock()
		task.wait(time)
		local turned = (y0 - yaw() + 180) % 360 - 180
		stick2Pos = Vector3.zero
		return turned / (os.clock() - t0)
	end
	if padLook then
		padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.zero, KeyCode = Enum.KeyCode.Thumbstick2 })
		padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.new(1, 0, 0), KeyCode = Enum.KeyCode.Thumbstick2 })
		task.wait(0.3)
		local one = turnOver(1, 0.3)
		local two = turnOver(2, 0.3)
		if not (one > 20 and two > one * 1.6 and two < one * 2.4) then
			problem(string.format("PAD SENSITIVITY 68: x2 turns it twice as fast (%.0f vs %.0f degrees a second)", two, one))
		end
		-- a pad that came up as another gamepad: the stick as its input reports it
		stick2Pos = Vector3.zero
		padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.new(1, 0, 0), KeyCode = Enum.KeyCode.Thumbstick2 })
		setAttr(localPlayer, "PadSensitivity", 1)
		local y0 = yaw()
		task.wait(0.25)
		if math.abs((y0 - yaw() + 180) % 360 - 180) < 5 then
			problem("PAD LOOK 68: a pad that isn't Gamepad1 still turns the camera")
		end
		padLook("QuirkPadLook", Enum.UserInputState.End, { Position = Vector3.zero, KeyCode = Enum.KeyCode.Thumbstick2 })
		task.wait(0.05)
		y0 = yaw()
		task.wait(0.15)
		if math.abs((y0 - yaw() + 180) % 360 - 180) > 0.5 then
			problem("PAD LOOK 68: ...and stops when it's let go")
		end
		-- ROBLOX CAMERA on: the stick is Roblox's again
		setAttr(localPlayer, "RobloxCamera", true)
		local res = padLook("QuirkPadLook", Enum.UserInputState.Change, { Position = Vector3.new(1, 0, 0), KeyCode = Enum.KeyCode.Thumbstick2 })
		stick2Pos = Vector3.new(1, 0, 0)
		y0 = yaw()
		task.wait(0.2)
		if res ~= Enum.ContextActionResult.Pass or math.abs((y0 - yaw() + 180) % 360 - 180) > 0.5 then
			problem("PAD LOOK 68: ROBLOX CAMERA on - the stick goes to Roblox's camera (and its sensitivity)")
		end
		stick2Pos = Vector3.zero
		padLook("QuirkPadLook", Enum.UserInputState.End, { Position = Vector3.zero, KeyCode = Enum.KeyCode.Thumbstick2 })
		setAttr(localPlayer, "RobloxCamera", false)
		if rcBtn and rcBtn.Text ~= "OFF" then
			problem("SETTINGS 68: ROBLOX CAMERA shows the saved value")
		end
	else
		problem("PAD LOOK 68: the controller look is bound")
	end
	setAttr(localPlayer, "PadSensitivity", 1)
	lastInputType = Enum.UserInputType.Keyboard
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)
	cam68.CFrame = was68
end)
if not ok68 then
	problem("round 68 client tests crashed: " .. tostring(err68))
end
end

print("== round 69: TWICE - every effect plays; his doubles walk; his HUD counts them")
do
local ok69, err69 = pcall(function()
	local AHEAD = Vector3.new(0, 0, -1)
	myHum.Health = myHum.MaxHealth
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	setAttr(myChar, "Ragdolled", false)
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Quirk", "Double")
	local foe = makeR15("Foe69", Vector3.new(0, 3, -10))
	foe.Humanoid.Health = 100
	local there = Vector3.new(0, 3, -10)

	-- his moves: on his own screen and on everyone else's
	for _, isLocal in { true, false } do
		VFX.Play("DaggerShot", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		VFX.Play("MeasureTape", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		VFX.Play("Double", myChar, {}, isLocal)
		VFX.Play("DoubleCross", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		VFX.Play("ParadeMarch", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		VFX.Play("DaggerStorm", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		VFX.Play("Dogpile", myChar, { Dir = AHEAD, Pos = there }, isLocal)
		task.wait(0.2)
	end
	-- the ones the server sends
	VFX.Play("TwiceKnife", myChar, { From = Vector3.new(0, 4, 0), To = there, Hit = foe, Speed = 190 }, false)
	VFX.Play("TwiceKnife", myChar, { From = Vector3.new(0, 4, 0), To = Vector3.new(4, 4, -30), Speed = 190 }, false)
	VFX.Play("TapeSlash", myChar, { Target = foe, Dir = AHEAD }, false)
	VFX.Play("MeasureLash", myChar, { Dir = AHEAD, To = there, Target = foe }, false)
	VFX.Play("MeasureLash", myChar, { Dir = AHEAD, To = Vector3.new(0, 4, -38) }, false)
	setAttr(foe, "MeasuredBy", 1)
	VFX.Play("Measured", myChar, { Target = foe, Time = 0.4 }, false)
	VFX.Play("DoubleSwap", myChar, { From = Vector3.new(0, 3, 0), To = Vector3.new(12, 3, -6) }, false)
	VFX.Play("CloneToss", myChar, { From = Vector3.new(0, 4, 0), To = Vector3.new(0, 3, -20) }, false)
	VFX.Play("DogpileGo", myChar, { Target = foe, Count = 6 }, false)
	VFX.Play("DogpileBurst", myChar, { Pos = there, Target = foe }, false)
	task.wait(0.6)
	setAttr(foe, "MeasuredBy", nil)
	-- a double of his: forms out of mud, swings, throws, melts
	local doublesF = workspace:FindFirstChild("TwiceClones") or Instance.new("Folder")
	doublesF.Name = "TwiceClones"
	doublesF.Parent = workspace
	local dbl = makeR15("Double69", Vector3.new(6, 3, -4))
	dbl.Parent = doublesF
	dbl.Humanoid.Health = 100
	VFX.Play("TwiceSplit", dbl, { From = myChar, Kind = "Self", Pos = Vector3.new(6, 3, -4) }, false)
	VFX.Play("TwiceClonePunch", dbl, { Target = foe, Count = 2, Dir = AHEAD }, false)
	VFX.Play("TwiceThrow", dbl, { Dir = AHEAD }, false)
	task.wait(0.5)
	-- his doubles walk (the gait drives them: no Animate of their own)
	local walker = makeR15("Walker69", Vector3.new(-20, 3, 0))
	walker.Parent = doublesF
	walker.Humanoid.Health = 100
	walker.Humanoid.WalkSpeed = 21
	walker.Humanoid.FloorMaterial = Enum.Material.Plastic
	local stray = makeR15("Stray69", Vector3.new(-30, 3, 0)) -- (not his: nothing drives it)
	stray.Humanoid.Health = 100
	stray.Humanoid.WalkSpeed = 21
	stray.Humanoid.FloorMaterial = Enum.Material.Plastic
	local function hip(m)
		return m.LowerTorso:FindFirstChild("RightHip") or m.RightUpperLeg:FindFirstChild("RightHip")
	end
	local w0, s0 = hip(walker).C0, hip(stray).C0
	for _ = 1, 20 do
		walker.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -18)
		stray.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -18)
		task.wait(0.03)
	end
	if hip(walker).C0 == w0 then
		problem("TWICE 69: his doubles walk - the gait drives them like the walking dummies")
	end
	if hip(stray).C0 ~= s0 then
		problem("TWICE 69: (a body that isn't a double or a dummy isn't driven)")
	end
	VFX.Play("TwiceMelt", dbl, { Pos = Vector3.new(6, 3, -4), Time = 0.3 }, false)
	task.wait(0.5)
	walker:Destroy()
	stray:Destroy()
	dbl:Destroy()
	-- his M1s and his awakening
	for count = 1, 4 do
		VFX.Play("Punch", myChar, { Count = count, Finisher = count == 4 }, true)
		task.wait(0.12)
	end
	VFX.Play("UltActivate", myChar, { Quirk = "Double" }, true)
	task.wait(1.4)
	local ghosts = 0
	for _, d in VFX.Folder:GetChildren() do
		if d.Name == "TwiceGhost" then
			ghosts += 1
		end
	end
	-- his KO finisher: four of him round them
	local target = makeR15("KOd69", Vector3.new(0, 3, -6))
	VFX.Play("KOFinisher", myChar, { Target = target, Move = "TapeDash", Name = "TAPE DASH", Dir = AHEAD, Pos = Vector3.new(0, 3, -6) }, true)
	task.wait(1.8)
	target:Destroy()
	foe:Destroy()
	-- the HUD: DOUBLES pips over the health bar
	setAttr(myChar, "Doubles", 1)
	task.wait(0.1)
	local pips = hudGui:FindFirstChild("Pips", true)
	local label
	for _, d in pips and pips:GetDescendants() or {} do
		if d:IsA("TextLabel") and string.find(d.Text, "DOUBLES", 1, true) then
			label = d.Text
		end
	end
	if not (pips and pips.Visible and label and string.find(label, "1/" .. Config.Quirks.Double.Clones.Max, 1, true)) then
		problem("TWICE 69: DOUBLES pips over his health bar (" .. tostring(label) .. ")")
	end
	setAttr(myChar, "Measuring", "Bravo")
	task.wait(0.1)
	label = nil
	for _, d in pips and pips:GetDescendants() or {} do
		if d:IsA("TextLabel") and string.find(d.Text, "MEASURED BRAVO", 1, true) then
			label = d.Text
		end
	end
	if not label then
		problem("TWICE 69: ...and who he's measured")
	end
	setAttr(myChar, "Measuring", nil)
	setAttr(myChar, "Doubles", nil)
	setAttr(myChar, "Quirk", nil)
	task.wait(0.1)
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	print("  (twice: " .. ghosts .. " of him on the awakening)")
end)
if not ok69 then
	problem("round 69 client tests crashed: " .. tostring(err69))
end
end

print("== round 71: QUIRK CLASHES - the prompt, the meter, the camera, the end")
do
local camSaved71 = workspace.CurrentCamera.CFrame
local ok71, err71 = pcall(function()
	local Color3, UDim2 = r.Color3, r.UDim2
	local RunSvc71 = game:GetService("RunService")
	local ticking71 = true
	task.spawn(function()
		while ticking71 do
			signalOf(RunSvc71, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	local CL = VFX.CL
	myHum.Health = myHum.MaxHealth
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	setAttr(myChar, "Ragdolled", false)
	setAttr(myChar, "Stunned", false)
	local foe = makeR15("Foe71", Vector3.new(0, 3, -30))
	foe.Humanoid.Health = 100
	local cam71 = workspace.CurrentCamera
	cam71.CameraType = Enum.CameraType.Custom
	local function press(key)
		local fn = actions.QuirkClash
		if fn then
			fn("QuirkClash", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[key] })
		end
		task.wait(0.09)
	end
	-- you're in one: A (the attacker) is you
	VFX.Play("ClashStart", nil, { Id = 71, A = myChar, B = foe, AMove = "APShot", BMove = "Heatwave", AName = "Tester", BName = "Foe", Time = 4, Seed = 4242 }, false)
	task.wait(0.2)
	local c = CL.live[71]
	local gui = playerGui:FindFirstChild("ClashGui")
	local key = gui and gui:FindFirstChild("Prompt")
	if not (c and c.me == "A" and gui and key and table.find(Config.Clash.Keys, key.Text)) then
		problem("CLASH 71: you're in it: the meter and the prompt come up (" .. tostring(key and key.Text) .. ")")
	end
	if not (renderBinds.QuirkClash and cam71.CameraType == Enum.CameraType.Scriptable and actions.QuirkClash) then
		problem("CLASH 71: ...the camera goes side-on and W / A / D are yours")
	end
	local beams = VFX.Folder:FindFirstChild("Clash")
	if not beams then
		problem("CLASH 71: ...the two beams and the knot where they meet")
	end
	-- the right key: on to the next prompt (the server's told)
	fired = {}
	local want = c and c.key
	press(want)
	local sent
	for _, f in fired do
		if f[1] == "Clash" then
			sent = f
		end
	end
	if not (c and c.index == 2) then
		problem("CLASH 71: a press moves you on to the next prompt (" .. tostring(c and c.index) .. ")")
	end
	-- the wrong one: MISSED, and it doesn't count for a moment
	local wrong
	for _, k in Config.Clash.Keys do
		if c and k ~= c.key then
			wrong = k
		end
	end
	press(wrong)
	if not (c and os.clock() < (c.lock or 0)) then
		problem("CLASH 71: a wrong press locks you out for a moment")
	end
	-- a controller: the prompt shows the pad's button
	lastInputType = Enum.UserInputType.Gamepad1
	task.wait(0.4)
	press(c.key)
	if not (key and Config.Clash.PadLabels[c.key] == key.Text) then
		problem("CLASH 71: on a controller the prompt shows Y / X / B (" .. tostring(key and key.Text) .. ")")
	end
	-- a phone: the button jumps round the screen; tapping it is pressing it
	lastInputType = Enum.UserInputType.Touch
	local was = c.index
	signalOf(key, "Activated"):Fire()
	task.wait(0.1)
	if not (c.index == was + 1 and key.Position ~= UDim2.fromScale(0.5, 0.66)) then
		problem("CLASH 71: on a phone, tap the button wherever it lands")
	end
	lastInputType = Enum.UserInputType.Keyboard
	-- the server's word on where it stands
	VFX.Play("ClashPush", nil, { Id = 71, M = 0.4, Side = "A", Good = true }, false)
	VFX.Play("ClashSync", nil, { Id = 71, Index = 9 }, false)
	task.wait(0.1)
	if not (c.target == 0.4 and c.index == 9) then
		problem("CLASH 71: the server's push and its resync land (" .. tostring(c.target) .. ", " .. tostring(c.index) .. ")")
	end
	-- the end: yours goes through
	VFX.Play("ClashEnd", nil, { Id = 71, Winner = myChar, Loser = foe, Draw = false, Point = Vector3.new(0, 4, -15), M = 1 }, false)
	task.wait(0.4)
	local over
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d.Text == "OVERPOWERED!" then
			over = d
		end
	end
	if not over then
		problem("CLASH 71: you won: OVERPOWERED!")
	end
	task.wait(1.6)
	if renderBinds.QuirkClash or cam71.CameraType ~= Enum.CameraType.Custom or CL.live[71] or (gui.Parent ~= nil and gui:FindFirstChild("Prompt") and gui:FindFirstChild("Prompt").Visible) then
		problem("CLASH 71: ...and it's all put back: the camera, the prompt")
	end
	-- somebody else's: a meter over it, no prompt for you
	local foe2 = makeR15("Foe71b", Vector3.new(20, 3, -30))
	foe2.Humanoid.Health = 100
	VFX.Play("ClashStart", nil, { Id = 72, A = foe, B = foe2, AMove = "Flashfire", BMove = "ReversalRed", AName = "Foe", BName = "Foe2", Time = 3, Seed = 7 }, false)
	task.wait(0.3)
	local c2 = CL.live[72]
	if not (c2 and c2.me == nil and c2.bb and not c2.gui) then
		problem("CLASH 71: someone else's clash: a little meter over it, nothing on your screen")
	end
	VFX.Play("ClashEnd", nil, { Id = 72, Draw = true, Point = Vector3.new(10, 4, -30), M = 0 }, false)
	task.wait(1.8)
	-- one against nobody (a memory's): press it through
	local result
	CL.solo({
		GetA = function()
			return Vector3.new(0, 4, -2)
		end,
		GetB = function()
			return Vector3.new(0, 4, -40)
		end,
		AMove = "DetroitSmash", BMove = "Heatwave", AName = "MIDORIYA", BName = "TODOROKI", Time = 6, Rate = 0.01, Accuracy = 0,
		OnEnd = function(res)
			result = res
		end,
	})
	task.wait(0.2)
	for _ = 1, 24 do
		local live
		for _, g in playerGui:GetChildren() do
			if g.Name == "ClashGui" and g:FindFirstChild("Prompt") then
				live = g
			end
		end
		local k = live and live:FindFirstChild("Prompt").Text
		if k and k ~= "" then
			press(k)
		end
	end
	task.wait(1.9)
	if result ~= "A" then
		problem("CLASH 71: a solo clash pressed right through is won (" .. tostring(result) .. ")")
	end
	foe:Destroy()
	foe2:Destroy()
	ticking71 = false
end)
if not ok71 then
	problem("round 71 clash client tests crashed: " .. tostring(err71))
end
-- (the camera back where it was: later checks hear things near you)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
workspace.CurrentCamera.CFrame = camSaved71
myRoot.CFrame = r.CFrame.new(0, 3, 0)
myRoot.Position = Vector3.new(0, 3, 0)
end

print("== round 71: NOMU RAID - the warning, the body, the bar, the moves, the end")
do
local camSaved71 = workspace.CurrentCamera.CFrame
local ok71, err71 = pcall(function()
	local Color3, UDim2 = r.Color3, r.UDim2
	local RunSvc71 = game:GetService("RunService")
	local ticking71 = true
	task.spawn(function()
		while ticking71 do
			signalOf(RunSvc71, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	local raid = workspace:FindFirstChild("NomuRaid") or Instance.new("Folder")
	raid.Name = "NomuRaid"
	raid.Parent = workspace
	VFX.Play("NomuIncoming", nil, { Pos = Vector3.new(0, 0, -60), Land = 0.6, Max = 5400 }, false)
	task.wait(0.2)
	local rg = playerGui:FindFirstChild("NomuRaidGui")
	if not rg then
		problem("NOMU 71: everyone's warned it's coming (a banner)")
	end
	task.wait(0.8)
	-- the server's body: the puppet rides it
	local body = makeR15("HighEndNomu", Vector3.new(0, 9, -60))
	body.Parent = raid
	body.Humanoid.MaxHealth = 5400
	body.Humanoid.Health = 5400
	setAttr(body, "Boss", true)
	setAttr(body, "BossName", "HIGH-END NOMU")
	VFX.Play("NomuLanded", body, { Pos = Vector3.new(0, 0, -60), Max = 5400 }, false)
	task.wait(0.3)
	local puppet
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, "Nomu", 1, true) and d ~= body then
			puppet = d
		end
	end
	if not puppet then
		problem("NOMU 71: it lands: the High-End Nomu's body is drawn")
	end
	VFX.Play("NomuState", body, { Health = 2000, Max = 5400, Phase = 2, Left = 120, Top = { { Name = "Tester", Damage = 900 }, { Name = "Foe", Damage = 400 } }, Board = { [tostring(localPlayer.UserId)] = { Damage = 900, Rank = 1 } }, Count = 2, Regen = true }, false)
	task.wait(0.2)
	local fill = rg and rg:FindFirstChild("Fill", true)
	local board
	for _, d in rg and rg:GetDescendants() or {} do
		if d:IsA("TextLabel") and string.find(d.Text, "TOP DAMAGE", 1, true) then
			board = d.Text
		end
	end
	if not (fill and math.abs(fill.Size.X.Scale - 2000 / 5400) < 0.05 and board and string.find(board, "Tester", 1, true) and string.find(board, "YOU: 900", 1, true)) then
		problem("NOMU 71: its health bar and the damage board (" .. tostring(fill and fill.Size) .. " / " .. tostring(board) .. ")")
	end
	for _, m in {
		{ Kind = "Swipe", Dir = Vector3.new(0, 0, 1), Windup = 0.2, Side = 1 },
		{ Kind = "Slam", From = Vector3.new(0, 9, -60), To = Vector3.new(0, 3, -40), Air = 0.4, Windup = 0.2 },
		{ Kind = "Charge", Dir = Vector3.new(0, 0, 1), Windup = 0.2, Dist = 40, Time = 0.3 },
		{ Kind = "Roar", Phase = 2 },
	} do
		VFX.Play("NomuMove", body, m, false)
		task.wait(0.5)
	end
	VFX.Play("NomuImpact", nil, { Pos = Vector3.new(0, 0, -40), Radius = 18 }, false)
	task.wait(0.3)
	VFX.Play("NomuRaidEnd", body, { Result = "Defeated", Top = { { Name = "Tester", Damage = 3000, Reward = 55 } }, Total = 5400, Count = 1 }, false)
	VFX.Play("NomuReward", nil, { Reward = 55, Damage = 3000, Rank = 1, Of = 1, Result = "Defeated" }, false)
	task.wait(1.6)
	local paid
	for _, d in rg and rg:GetDescendants() or {} do
		if d:IsA("TextLabel") and string.find(d.Text, "+$55", 1, true) then
			paid = d
		end
	end
	if not paid then
		problem("NOMU 71: beaten: what you're paid comes up (+$55)")
	end
	task.wait(3)
	body:Destroy()
	-- it gets away
	local body2 = makeR15("HighEndNomu", Vector3.new(0, 9, -60))
	body2.Parent = raid
	setAttr(body2, "Boss", true)
	VFX.Play("NomuLanded", body2, { Pos = Vector3.new(0, 0, -60), Max = 5400 }, false)
	task.wait(0.2)
	VFX.Play("NomuMove", body2, { Kind = "Escape" }, false)
	VFX.Play("NomuRaidEnd", body2, { Result = "Escaped", Top = {}, Total = 0, Count = 0 }, false)
	task.wait(2.6)
	body2:Destroy()
	ticking71 = false
end)
if not ok71 then
	problem("round 71 nomu client tests crashed: " .. tostring(err71))
end
-- (the camera back where it was: later checks hear things near you)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
workspace.CurrentCamera.CFrame = camSaved71
myRoot.CFrame = r.CFrame.new(0, 3, 0)
myRoot.Position = Vector3.new(0, 3, 0)
end

print("== round 71: DEKU'S MEMORIES - the white-out, the look, the fight on the stage")
do
local camSaved71 = workspace.CurrentCamera.CFrame
local ok71, err71 = pcall(function()
	local Color3, UDim2 = r.Color3, r.UDim2
	local RunSvc71 = game:GetService("RunService")
	local ticking71 = true
	task.spawn(function()
		while ticking71 do
			signalOf(RunSvc71, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	local MEM = VFX.MEM
	local MC = Config.DekuMemories
	local CENTER = Config.VestigeRealm.Center
	VFX.Play("MemoryIn", nil, { Place = "Classroom" }, false)
	task.wait(0.3)
	local screen = playerGui:FindFirstChild("MemoryScreen")
	local white = screen and screen:FindFirstChild("White")
	if not (white and white.BackgroundTransparency < 0.5) then
		problem("MEMORIES 71: through a door: a white-out")
	end
	task.wait(MC.FadeTime + 0.2)
	local title = screen and screen:FindFirstChild("Title")
	if not (title and title.Text == "U.A. HIGH SCHOOL - CLASS 1-A") then
		problem("MEMORIES 71: ...and the memory's name (" .. tostring(title and title.Text) .. ")")
	end
	-- inside one: the warm, soft look
	myRoot.CFrame = r.CFrame.new(CENTER + MC.Classroom + Vector3.new(0, 3, 20))
	myRoot.Position = CENTER + MC.Classroom + Vector3.new(0, 3, 20)
	task.wait(0.5)
	local cam71 = workspace.CurrentCamera
	if not (cam71:FindFirstChild("MemoryTint") and cam71:FindFirstChild("MemoryBloom") and cam71:FindFirstChild("MemoryHaze")) then
		problem("MEMORIES 71: inside a memory, the screen looks remembered (tint, glow, haze)")
	end
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	task.wait(0.5)
	if cam71:FindFirstChild("MemoryTint") then
		problem("MEMORIES 71: ...and not outside one")
	end
	-- THE FIGHT: up on the stage
	local stage = r.CFrame.new(0, 3.2, -80)
	cam71.CameraType = Enum.CameraType.Custom
	local seen = {}
	for _, d in myChar:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			seen[d] = d.Transparency
		end
	end
	VFX.Play("MemoryFight", nil, { Stage = stage, Time = 5, Rival = { Rate = 0.01, Accuracy = 0 } }, false)
	task.wait(0.3)
	local f = MEM.live
	local fightModel = VFX.Folder:FindFirstChild("MemoryFight")
	local deku = fightModel and fightModel:FindFirstChild("MemoryDeku")
	local todo = fightModel and fightModel:FindFirstChild("MemoryTodoroki")
	if not (f and deku and todo) then
		problem("MEMORIES 71: up on the stage: Midoriya and Todoroki, in their gym uniforms")
	end
	local hidden = true
	for d in seen do
		if d.Transparency < 1 then
			hidden = false
		end
	end
	if not (hidden and VFX.InOwnCinematic() and renderBinds.QuirkMemory and cam71.CameraType == Enum.CameraType.Scriptable) then
		problem("MEMORIES 71: ...you're not in it (hidden, your inputs held); the camera's the memory's")
	end
	VFX.Play("MemoryFight", nil, { Stage = stage, Time = 5 }, false)
	task.wait(0.1)
	if MEM.live ~= f then
		problem("MEMORIES 71: (one at a time)")
	end
	-- the ice comes, a finger breaks it
	task.wait(3.9)
	local purple = 0
	for _, p in f.deku.pp.fingers.armR do
		if p.Color == Color3.fromRGB(122, 64, 150) then
			purple += 1
		end
	end
	if purple < 1 then
		problem("MEMORIES 71: Delaware Smash: a finger flicked, and broken for it")
	end
	-- his right side freezes; the fire; Cementoss's walls; the clash
	task.wait(5)
	if not (f.frost and #f.frost > 0) then
		problem("MEMORIES 71: Todoroki's right side freezes over")
	end
	task.wait(10.2)
	local clash = f.clash
	if not (clash and clash.me == "A" and clash.solo and actions.QuirkClash and renderBinds.QuirkClash and not renderBinds.QuirkMemory) then
		problem("MEMORIES 71: the last Smash against the heat: a clash, yours to push")
	end
	for _ = 1, 26 do
		if clash and not clash.done and actions.QuirkClash then
			actions.QuirkClash("QuirkClash", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode[clash.key] })
		end
		task.wait(0.09)
	end
	task.wait(2)
	if not (f.result == "A" and f.todo.arc and renderBinds.QuirkMemory) then
		problem("MEMORIES 71: pushed through: the stage goes up, Todoroki's out of bounds (" .. tostring(f.result) .. ")")
	end
	task.wait(9.6)
	local back = true
	for d, t in seen do
		if d.Parent and d.Transparency ~= t then
			back = false
		end
	end
	if not (MEM.live == nil and f.gone and not VFX.InOwnCinematic() and not renderBinds.QuirkMemory and cam71.CameraType == Enum.CameraType.Custom and back and not VFX.Folder:FindFirstChild("MemoryFight")) then
		problem("MEMORIES 71: the memory fades: you, your camera and your inputs are back")
	end
	ticking71 = false
end)
if not ok71 then
	problem("round 71 memories client tests crashed: " .. tostring(err71))
end
-- (the camera back where it was: later checks hear things near you)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
workspace.CurrentCamera.CFrame = camSaved71
myRoot.CFrame = r.CFrame.new(0, 3, 0)
myRoot.Position = Vector3.new(0, 3, 0)
end

print("== round 72: EMOTES FOR ROBUX - the button on the banner, its price, Roblox's prompt")
do
local ownedWas72 = localPlayer:GetAttribute("EmotesOwned")
local ok72, err72 = pcall(function()
	HUD.ShowMenu(false)
	HUD.ToggleShop(true)
	HUD.ShopTab("Shop")
	task.wait(0.2)
	local shop = hudGui:FindFirstChild("Shop")
	local roll = shop and shop:FindFirstChild("RollEmotes", true)
	local robux = roll and roll:FindFirstChild("Robux")
	local chip = roll and roll:FindFirstChild("Multiplier")
	local price = roll and roll:FindFirstChild("Price")
	if not (robux and robux.Visible and robux.Text == "R$ 31" and price and string.find(price.Text, "25", 1, true)) then
		problem("ROBUX 72: the EMOTES banner: a Robux button with Roblox's price, over the Bucks one (" .. tostring(robux and robux.Text) .. " / " .. tostring(price and price.Text) .. ")")
	end
	if not (roll and roll.Size.Y.Offset >= 150) then
		problem("ROBUX 72: ...the banner's taller to fit both")
	end
	setAttr(localPlayer, "EmotesOwned", "")
	table.clear(prompts72)
	table.clear(fired)
	signalOf(robux, "MouseButton1Click"):Fire()
	task.wait(0.1)
	if not (prompts72[1] == Config.EmoteShop.Robux[1].Product and #fired == 0) then
		problem("ROBUX 72: pressing it opens Roblox's purchase prompt for 1x - no Bucks spent (" .. tostring(prompts72[1]) .. ")")
	end
	for _ = 1, 3 do
		signalOf(chip, "MouseButton1Click"):Fire()
	end
	task.wait(0.1)
	table.clear(prompts72)
	signalOf(robux, "MouseButton1Click"):Fire()
	task.wait(0.1)
	if not (robux.Text == "R$ 40" and prompts72[1] == Config.EmoteShop.Robux[10].Product and string.find(price.Text, "250", 1, true)) then
		problem("ROBUX 72: at 10x: its own price and product (" .. tostring(robux.Text) .. ", " .. tostring(prompts72[1]) .. ")")
	end
	local all = {}
	for _, e in Config.Emotes do
		table.insert(all, e.Id)
	end
	setAttr(localPlayer, "EmotesOwned", table.concat(all, ","))
	table.clear(prompts72)
	signalOf(robux, "MouseButton1Click"):Fire()
	task.wait(0.1)
	if #prompts72 ~= 0 then
		problem("ROBUX 72: owning every emote already: no prompt (nothing to pay for)")
	end
	setAttr(localPlayer, "EmotesOwned", "")
	signalOf(chip, "MouseButton1Click"):Fire()
	-- Bucks still buy them
	table.clear(fired)
	signalOf(roll, "MouseButton1Click"):Fire()
	task.wait(0.1)
	if not (fired[1] and fired[1][1] == "Shop" and fired[1][2] == "RollEmotes" and fired[1][3] == 1) then
		problem("ROBUX 72: the banner itself still buys with Bucks")
	end
	HUD.ToggleShop(false)
end)
if not ok72 then
	problem("round 72 client tests crashed: " .. tostring(err72))
end
setAttr(localPlayer, "EmotesOwned", ownedWas72) -- (what was owned before: the next checks use it)
end
print("== round 72: the roll's reveal goes by itself; WHY ARE YOU CRYING; the Bamboo Sweep along the street")
do
local ok72b, err72b = pcall(function()
	local root = myChar:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	setAttr(myChar, "Ragdolled", false)
	setAttr(myChar, "Stunned", false)
	local function faceUp(reveal)
		local n = 0
		for _, d in reveal:GetDescendants() do
			if d.Name == "EmoteName" and d.Visible then
				n += 1
			end
		end
		return n
	end
	-- THE REVEAL: NICE! from the start, quicker flips, then gone by itself
	HUD.ShowEmoteRoll({ "Wave", "Nap" }, 0)
	task.wait(0.1)
	local reveal = hudGui:FindFirstChild("EmoteReveal")
	local nice = reveal and reveal:FindFirstChild("Nice")
	local skip = reveal and reveal:FindFirstChild("Skip")
	if not (reveal and reveal.Visible and nice and nice.Visible and skip) then
		problem("REVEAL 72: NICE! is there from the start - put it away whenever")
	end
	task.wait(0.7)
	if faceUp(reveal) ~= 2 then
		problem("REVEAL 72: ...quicker: both cards over in under a second (" .. faceUp(reveal) .. ")")
	end
	task.wait((Config.EmoteShop.RevealStay or 1.8) + 0.4)
	if reveal.Visible then
		problem("REVEAL 72: ...and a moment later it goes by itself (no hanging about)")
	end
	-- a 10x: a click anywhere turns the rest over at once, another puts it away
	local ten = {}
	for i = 1, 10 do
		ten[i] = Config.Emotes[i].Id
	end
	HUD.ShowEmoteRoll(ten, 0)
	task.wait(0.05)
	signalOf(skip, "MouseButton1Click"):Fire()
	task.wait(0.3)
	if faceUp(reveal) ~= 10 then
		problem("REVEAL 72: a click turns all ten over at once (" .. faceUp(reveal) .. ")")
	end
	signalOf(skip, "MouseButton1Click"):Fire()
	task.wait(0.05)
	if reveal.Visible then
		problem("REVEAL 72: ...and another click puts it away")
	end
	-- NICE! straight off; the one before's timer can't shut the next one early
	HUD.ShowEmoteRoll({ "Wave" }, 0)
	task.wait(0.6)
	signalOf(nice, "MouseButton1Click"):Fire()
	if reveal.Visible then
		problem("REVEAL 72: NICE! puts it away straight off")
	end
	HUD.ShowEmoteRoll({ "Wave", "Nap" }, 0)
	task.wait((Config.EmoteShop.RevealStay or 1.8) + 0.2)
	if not reveal.Visible then
		problem("REVEAL 72: ...the last one's timer doesn't shut the next one early")
	end
	task.wait(1.2)
	if reveal.Visible then
		problem("REVEAL 72: ...that one goes on its own time")
	end

	-- WHY ARE YOU CRYING
	local why
	for _, e in Config.Emotes do
		if e.Id == "WhyCry" then
			why = e
		end
	end
	local m = VFX.Motions and VFX.Motions.EmoteWhyCry
	local total = 0
	for _, step in ipairs(m or {}) do
		total += (step.t or 0.08) + (step.hold or 0)
	end
	local B = 60 / 116.9
	if not (why and m and math.abs(total - 36 * B) < 0.02) then
		problem(string.format("WHY CRY 72: 36 beats, each on the song's beat (%.2f s, want %.2f)", total, 36 * B))
	end
	local function find(name, visible)
		local n, first = 0, nil
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name and (not visible or (d:IsA("BasePart") and d.Transparency < 0.9)) then
				n += 1
				first = first or d
			end
		end
		return n, first
	end
	local oldSong, oldStart = why and why.Song, why and why.SongStart
	if why then
		why.Song, why.SongStart = "rbxassetid://7272", 55.52
	end
	VFX.ReleasePose(myChar, 0)
	VFX.Play("Emote", myChar, { Id = "WhyCry" }, false)
	task.wait(0.4)
	local song = root:FindFirstChild("EmoteSong")
	if not (song and song.SoundId == "rbxassetid://7272" and math.abs(song.TimePosition - 55.52) < 0.6) then
		problem("WHY CRY 72: the song plays from where the dance is timed to (" .. tostring(song and song.TimePosition) .. ")")
	end
	local _, bb = find("WhyCryHeart")
	if not bb then
		problem("WHY CRY 72: the big pastel heart over his head")
	end
	task.wait(7.9) -- (beat 16: well into the crying)
	local tears = find("Tear", true)
	local cloud = find("RainCloud", true)
	local _, puddle = find("Puddle")
	local heart = bb and bb:FindFirstChild("Heart", true)
	local halves = 0
	for _, d in bb and bb:GetDescendants() or {} do
		if d.Name == "Half" and d.Visible then
			halves += 1
		end
	end
	if not (heart and not heart.Visible and halves == 2) then
		problem("WHY CRY 72: the heart cracked in two (" .. halves .. ")")
	end
	if tears < 20 or cloud < 5 then
		problem("WHY CRY 72: waterfall tears out of both eyes, a rain cloud over him (" .. tears .. ", " .. cloud .. ")")
	end
	if not (puddle and puddle.Transparency < 1 and puddle.Size.Y > 1) then
		problem("WHY CRY 72: a puddle growing under him (" .. tostring(puddle and puddle.Size) .. ")")
	end
	-- moving breaks it off: props, song and all
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
	end)
	task.wait(0.3)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	task.wait(0.5)
	if find("Tear") > 0 or find("WhyCryHeart") > 0 or root:FindFirstChild("EmoteSong") then
		problem("WHY CRY 72: moving breaks it off - tears, heart, song and all")
	end
	if why then
		why.Song, why.SongStart = oldSong, oldStart
	end
	VFX.ReleasePose(myChar, 0)

	-- THE BAMBOO SWEEP, from 11 studs up: down to the street, dragging along it
	local FLOOR = root.CFrame.Position.Y - 11
	setRaycast(function(_, origin, dir)
		if typeof(dir) == "Vector3" and dir.Y < 0 and origin.Y > FLOOR and origin.Y + dir.Y <= FLOOR then
			return { Position = Vector3.new(origin.X, FLOOR, origin.Z), Normal = Vector3.new(0, 1, 0), Distance = origin.Y - FLOOR, Instance = workspace }
		end
		return nil
	end)
	for _, old in VFX.Folder:GetChildren() do
		if old.Name == "Bamboo" or old.Name == "BambooScrape" then
			old:Destroy()
		end
	end
	local air = Config.Quirks.Manifest.Abilities[1].Air
	VFX.Play("ChickenKick", myChar, { Dir = Vector3.new(0, 0, -1), Air = true }, false)
	local culm
	local tw = os.clock()
	while not culm and os.clock() - tw < 0.5 do
		culm = VFX.Folder:FindFirstChild("Bamboo")
		task.wait()
	end
	local lowest = math.huge
	tw = os.clock()
	while culm and os.clock() - tw < air.WindUp + air.SwingTime + air.HoldTime do
		if culm.Transparency < 0.99 and culm.Size.X > 0.5 then
			-- (the nodes sit at 1/7 .. 6/7 along it: the tip's 7/5 as far
			-- from the middle as the lower end one)
			local c, lowNode = culm.CFrame.Position.Y, math.huge
			for _, n in VFX.Folder:GetChildren() do
				if n.Name == "BambooNode" and n.Transparency < 0.99 then
					lowNode = math.min(lowNode, n.CFrame.Position.Y)
				end
			end
			if lowNode < math.huge then
				lowest = math.min(lowest, c + (lowNode - c) * 1.4)
			end
		end
		task.wait(1 / 60)
	end
	local scrapes = find("BambooScrape")
	setRaycast(nil)
	if not (lowest < FLOOR + 1.2 and scrapes >= 3) then
		problem(string.format("BAMBOO 72: from high up the stalk comes down to the street and drags along it, tearing it up (tip %.1f above it; %d scrapes)", lowest - FLOOR, scrapes))
	end
	task.wait(air.ReturnTime + 0.4)
end)
if not ok72b then
	problem("round 72 client tests (2) crashed: " .. tostring(err72b))
end
end

print("== round 73: BAKUGO FLIES ON HIS EXPLOSIONS; ALL MIGHT'S TRANSFORMATION")
do
local ok73, err73 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	local quirkWas = localPlayer:GetAttribute("Quirk")
	local function pump(t)
		local t0 = os.clock()
		while os.clock() - t0 < t do
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end
	local function sent(kind)
		local n, last = 0, nil
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == Config.PARKOUR_INDEX and f[3] == kind then
				n += 1
				last = f
			end
		end
		return n, last
	end
	local function key(state)
		actions.QuirkDash("QuirkDash", state, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	end
	local BF = Config.Quirks.Explosion.BlastFlight
	setAttr(localPlayer, "Quirk", "Explosion")
	setAttr(myChar, "Quirk", "Explosion")
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Ragdolled", false)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyMass = 12
	end)
	hum.FloorMaterial = Enum.Material.Plastic
	pump(0.3)
	local bar = hudGui:FindFirstChild("Sweat", true)
	local text = bar and bar:FindFirstChildWhichIsA("TextLabel")
	if not (bar and bar.Visible and text and string.find(text.Text, "SWEAT 100%", 1, true)) then
		problem("FLIGHT 73: Bakugo's SWEAT bar is up, full (" .. tostring(text and text.Text) .. ")")
	end
	-- a tap is still just a dash
	table.clear(fired)
	key(Enum.UserInputState.Begin)
	pump(0.08)
	key(Enum.UserInputState.End)
	pump(BF.HoldDelay + 0.15)
	if root:FindFirstChild("BlastFlight") or sent("BlastFly") > 0 then
		problem("FLIGHT 73: a tap of the dash key is only a dash")
	end
	pump(1.6) -- (the dash's own cooldown aside, the flight has none yet)
	-- held: up he goes, on a blast off both palms
	table.clear(fired)
	key(Enum.UserInputState.Begin)
	pump(BF.HoldDelay + 0.08)
	local mover = root:FindFirstChild("BlastFlight")
	local n, first = sent("BlastFly")
	if not (mover and n == 1 and typeof(first[4]) == "Vector3" and first[4].Y > 0.3) then
		problem("FLIGHT 73: held past " .. BF.HoldDelay .. "s he takes off - up and out off the street (" .. tostring(mover) .. ", " .. n .. ")")
	end
	if not (VFX.BlastFlying and VFX.BlastFlying[myChar]) then
		problem("FLIGHT 73: ...leaning into it, palms thrown back (the blast effect's on)")
	end
	hum.FloorMaterial = Enum.Material.Air -- (off the ground)
	pump(1)
	local pulses = sent("BlastPulse")
	if pulses < 2 or pulses > 4 then
		problem("FLIGHT 73: a blast every " .. BF.Interval .. "s while it's held (" .. pulses .. " in a second)")
	end
	if not (mover.Parent and mover.VectorVelocity.Magnitude > BF.Cruise * 0.8) then
		problem("FLIGHT 73: ...flying him along (" .. tostring(mover.VectorVelocity) .. ")")
	end
	if not string.find(text.Text, "FLYING", 1, true) then
		problem("FLIGHT 73: the bar says he's flying (" .. text.Text .. ")")
	end
	-- let go: out of it
	key(Enum.UserInputState.End)
	pump(0.05)
	if root:FindFirstChild("BlastFlight") or sent("BlastFlyEnd") ~= 1 or (VFX.BlastFlying and VFX.BlastFlying[myChar]) then
		problem("FLIGHT 73: letting go drops him out of it")
	end
	-- held till the sweat runs out
	pump(BF.Cooldown + 0.1)
	table.clear(fired)
	key(Enum.UserInputState.Begin)
	pump(BF.HoldDelay + 0.05)
	if not root:FindFirstChild("BlastFlight") then
		problem("FLIGHT 73: off again once the cooldown's up (still in the air)")
	end
	pump(BF.Fuel + 0.2)
	if root:FindFirstChild("BlastFlight") or sent("BlastFlyEnd") ~= 1 or not string.find(text.Text, "DRIED UP", 1, true) then
		problem("FLIGHT 73: held till the sweat's gone: he drops out, the bar says so (" .. text.Text .. ")")
	end
	key(Enum.UserInputState.End)
	-- an M1 drops him out too
	hum.FloorMaterial = Enum.Material.Plastic
	pump(BF.RegenDelay + 2)
	if string.find(text.Text, "SWEAT 0%", 1, true) then
		problem("FLIGHT 73: back on the street, the sweat comes back (" .. text.Text .. ")")
	end
	pump(BF.Cooldown)
	table.clear(fired)
	key(Enum.UserInputState.Begin)
	pump(BF.HoldDelay + 0.05)
	hum.FloorMaterial = Enum.Material.Air
	local flyingBefore = root:FindFirstChild("BlastFlight") ~= nil
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.MouseButton1 })
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.MouseButton1 })
	pump(0.05)
	if not (flyingBefore and not root:FindFirstChild("BlastFlight") and sent("BlastFlyEnd") == 1) then
		problem("FLIGHT 73: an M1 drops him out of it (" .. tostring(flyingBefore) .. ")")
	end
	key(Enum.UserInputState.End)
	hum.FloorMaterial = Enum.Material.Plastic
	-- nobody else flies on the dash key
	setAttr(localPlayer, "Quirk", "FullCowl")
	setAttr(myChar, "Quirk", "FullCowl")
	pump(1.7)
	table.clear(fired)
	key(Enum.UserInputState.Begin)
	pump(BF.HoldDelay + 0.2)
	key(Enum.UserInputState.End)
	if root:FindFirstChild("BlastFlight") or sent("BlastFly") > 0 or (bar and bar.Visible) then
		problem("FLIGHT 73: only Bakugo flies (and has the bar)")
	end
	-- someone else flying: the blasts off their palms, and the pose let go at the end
	local foe = makeR6 and makeR6("Flyer73", Vector3.new(60, 10, 0)) or nil
	if foe then
		local before = #VFX.Folder:GetChildren()
		VFX.Play("BlastFly", foe, { Kind = "Start", Dir = Vector3.new(0, 0.3, -1).Unit }, false)
		task.wait(0.05)
		if #VFX.Folder:GetChildren() <= before or not VFX.BlastFlying[foe] then
			problem("FLIGHT 73: someone else taking off: the blasts off their palms")
		end
		VFX.Play("BlastFly", foe, { Kind = "End" }, false)
		task.wait(0.05)
		if VFX.BlastFlying[foe] then
			problem("FLIGHT 73: ...and it's over when they drop out")
		end
		foe:Destroy()
	end
	setAttr(localPlayer, "Quirk", quirkWas)
	setAttr(myChar, "Quirk", quirkWas)
	pump(0.1)

	-- ALL MIGHT'S TRANSFORMATION
	local P = Config.Quirks.OneForAll.Special.Presence
	local function has(name)
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end
	VFX.ReleasePose(myChar, 0)
	VFX.Play("MuscleForm", myChar, { Alt = true }, true)
	task.wait(0.3)
	local aura = has("MightAura")
	if not (aura and aura:IsA("Highlight")) then
		problem("MIGHT 73: powering up - a dark figure in a gold outline")
	end
	local bolts = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Size.X < 0.2 and d.Size.Z > 0.5 then
			bolts += 1
		end
	end
	if bolts == 0 then
		problem("MIGHT 73: ...gold lightning crawling over him")
	end
	task.wait(P.BurstAt - 0.3 + 0.2)
	if has("MightAura") then
		problem("MIGHT 73: the burst takes the silhouette off him")
	end
	if not has("HeroShadow") then
		problem("MIGHT 73: ...his face in shadow but for the eyes")
	end
	task.wait(1.5)
	VFX.ReleasePose(myChar, 0)
end)
if not ok73 then
	problem("round 73 client tests crashed: " .. tostring(err73))
end
end

print("== round 74: THE GUARD ON R6; PRIME DEKU, PRIME ALL MIGHT, DIO")
do
local ok74, err74 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	local function pump(t)
		local t0 = os.clock()
		while os.clock() - t0 < t do
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end
	local function has(name)
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end
	-- (the harness has no default for LocalTransparencyModifier: prime it on a test rig)
	local function rig(name, pos)
		local m = makeR6(name, pos)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 0
			end
		end
		return m
	end
	local calls = {}
	local realMotion = VFX.Motion
	VFX.Motion = function(c, name, ...)
		table.insert(calls, name)
		return realMotion(c, name, ...)
	end

	-- THE GUARD on an R6 body: the cross-guard, snapped up; the hits on it,
	-- the parry and the break each an R6 motion of their own
	local foe = makeR6("Guard74", Vector3.new(80, 10, 0))
	local torso = foe:FindFirstChild("Torso")
	local restR = torso["Right Shoulder"].C0
	VFX.Play("Guard", foe, { On = true, Target = foe }, false)
	pump(0.45)
	local raised = restR:Inverse() * torso["Right Shoulder"].C0
	local up = math.deg(math.acos(math.clamp(raised:VectorToWorldSpace(Vector3.new(0, 1, 0)).Y, -1, 1)))
	if table.find(calls, "GuardRaiseR6") == nil or up < 70 then
		problem("GUARD 74: an R6 body snaps up the cross-guard (" .. table.concat(calls, ",") .. ", arm " .. math.floor(up) .. " degrees up)")
	end
	if not has("GuardShield") and not foe:FindFirstChild("GuardShield") then
		problem("GUARD 74: ...the barrier's still there")
	end
	table.clear(calls)
	VFX.Play("Block", nil, { Target = foe, From = Vector3.new(80, 10, -4), Heavy = true }, false)
	VFX.Play("Block", nil, { Target = foe, From = Vector3.new(80, 10, -4) }, false)
	VFX.Play("Parry", nil, { Target = foe, Attacker = myChar }, false)
	task.wait(0.05)
	if not (table.find(calls, "BlockRecoilHeavyR6") and table.find(calls, "BlockRecoilR6") and table.find(calls, "ParryR6")) then
		problem("GUARD 74: a heavy hit, a hit and a parry each rock the R6 guard their own way (" .. table.concat(calls, ",") .. ")")
	end
	table.clear(calls)
	VFX.Play("GuardBreak", nil, { Target = foe, Duration = 1.6 }, false)
	task.wait(0.05)
	if not table.find(calls, "GuardBreakR6") then
		problem("GUARD 74: a broken guard throws the R6 arms wide and leaves them swaying (" .. table.concat(calls, ",") .. ")")
	end
	VFX.Play("Guard", foe, { On = false, Target = foe }, false)
	pump(0.3)
	foe:Destroy()

	-- PRIME DEKU: gone, and behind you
	local deku = rig("Deku74", Vector3.new(90, 10, 0))
	deku:SetAttribute("Vanished", true)
	VFX.Play("PrimeFlashStep", deku, {}, false)
	task.wait(0.35)
	local arm = deku:FindFirstChild("Right Arm")
	if not (arm and arm.LocalTransparencyModifier == 1) then
		problem("DEKU 74: FLASH STEP - he's gone on every screen")
	end
	local myRootNow = myChar:FindFirstChild("HumanoidRootPart")
	VFX.Play("FlashBehind", deku, { Target = myChar, Pos = myRootNow.Position + Vector3.new(0, 0, 3.3), Look = Vector3.new(0, 0, -1), Strike = 1.02, Name = "FLASH STEP" }, false)
	task.wait(0.8)
	if not VFX.InCinematic() then
		problem("DEKU 74: he's behind YOU - your camera gets the close-up")
	end
	if arm.LocalTransparencyModifier ~= 0 then
		problem("DEKU 74: ...and there he is")
	end
	task.wait(0.35)
	VFX.Play("FlashStrike", deku, { Target = myChar, Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(0.1)
	deku:SetAttribute("Vanished", nil)
	VFX.CancelCinematic()
	VFX.Play("FlashAppear", deku, { Pos = Vector3.new(90, 3, 20), Dir = Vector3.new(0, 0, 1), Radius = 10 }, false)
	VFX.Play("BlackwhipReel", deku, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("BlackwhipReelCast", deku, { Dir = Vector3.new(0, 0, 1), Targets = { myChar } }, false)
	VFX.Play("BlackwhipReelKick", deku, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("AirForceShots", deku, { Spots = { Vector3.new(90, 3, 30), Vector3.new(92, 3, 31) }, Gap = 0.05 }, false)
	VFX.Play("DangerCounter", deku, {}, false)
	VFX.Play("DangerFlash", deku, { Target = myChar, From = Vector3.new(90, 3, 0), Pos = myRootNow.Position + Vector3.new(0, 0, 3), Look = Vector3.new(0, 0, -1) }, false)
	VFX.Play("VestigeSmash", deku, { Dir = Vector3.new(0, 0, 1), Pos = Vector3.new(90, 3, 40) }, false)
	task.wait(0.4)
	if not has("VestigeFist") or not has("Vestige") then
		problem("DEKU 74: VESTIGE SMASH - the ones before him behind him, the fist coming down")
	end
	VFX.Play("FlashStepChain", deku, {}, false)
	VFX.Play("FlashChainHit", deku, { Target = myChar, Pos = myRootNow.Position + Vector3.new(0, 0, 3), Look = Vector3.new(0, 0, -1), Index = 1, Count = 1 }, false)
	VFX.Play("FlashChainEnd", deku, {}, false)
	VFX.Play("VestigeDDS", deku, { Dir = Vector3.new(0, 0, 1) }, false)
	task.wait(1.9)
	VFX.CancelCinematic()
	deku:Destroy()

	-- PRIME ALL MIGHT: I AM HERE - out of the sun
	local might = rig("Might74", Vector3.new(100, 10, 0))
	VFX.Play("IAmHereLeap", might, {}, false)
	VFX.Play("MissouriSmash", might, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("SonicBoom", might, { Pos = Vector3.new(100, 4, 10), Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("HurricaneSmash", might, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("PrimeDetroit", might, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("MeteorFall", might, { Pos = myRootNow.Position, Target = myChar, Look = 0.5, Fall = 0.3, Dir = Vector3.new(0, 0, 1) }, false)
	task.wait(0.2)
	if not VFX.InCinematic() then
		problem("MIGHT 74: under him, you look up into the sun")
	end
	task.wait(0.8)
	VFX.CancelCinematic()
	VFX.Play("PlusUltraUSJ", might, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("USJRush", might, { Target = myChar, Hits = 6, Interval = 0.03, Dir = Vector3.new(0, 0, 1) }, false)
	task.wait(0.5)
	VFX.Play("USJFinish", might, { Target = myChar, Dir = Vector3.new(0, 0, 1) }, false)
	task.wait(0.3)
	VFX.CancelCinematic()
	might:Destroy()

	-- DIO: The World, and stopped time
	local quirkWas = localPlayer:GetAttribute("Quirk")
	setAttr(localPlayer, "Quirk", "TheWorld")
	setAttr(myChar, "Quirk", "TheWorld")
	local fist = VFX.StandPunch(myChar, 1, false)
	pump(0.2)
	local CDV = VFX.CDV
	local st = CDV and CDV.stands[myChar]
	if not (fist and st and st.kind == "TheWorld" and st.model.Name == "TheWorld") then
		problem("DIO 74: The World throws his M1s (" .. tostring(st and st.kind) .. ")")
	end
	local dio = rig("Dio74", Vector3.new(110, 10, 0))
	VFX.Play("TimeStop", dio, { Duration = 1.2, Radius = 400, Frozen = { myChar } }, false)
	task.wait(0.3)
	if not (VFX.DV and VFX.DV.stoppedBy(dio)) or not Lighting:FindFirstChild("TimeStopCC") then
		problem("DIO 74: ZA WARUDO - the world goes grey on your screen, and time's stopped")
	end
	VFX.Play("TimeHit", nil, { Target = myChar, Pos = Vector3.new(110, 10, 0) }, false)
	VFX.Play("DioKnife", dio, { From = Vector3.new(110, 11, 0), To = myRootNow.Position, Hit = myChar, Speed = 200, Stopped = true }, false)
	task.wait(0.3)
	local marks = VFX.DV.marks[myChar]
	if not (marks and #marks > 0) then
		problem("DIO 74: a hit in stopped time hangs on you, gold, until it lands")
	end
	VFX.Play("TimeResume", dio, { Frozen = { myChar } }, false)
	task.wait(0.1)
	if VFX.DV.stoppedBy(dio) or VFX.DV.marks[myChar] then
		problem("DIO 74: ...and when it moves again, it all lands")
	end
	VFX.Play("ZaWarudo", myChar, {}, false)
	VFX.Play("MudaRush", myChar, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("VampireGrab", dio, { Target = myChar, Time = 0.4 }, false)
	VFX.Play("SpaceRipper", dio, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("SpaceRipperBeam", dio, { From = Vector3.new(110, 11, 0), To = Vector3.new(110, 11, 60), Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("KnifeRingSet", dio, { Pos = Vector3.new(110, 4, 20), Count = 6, Ring = 6, Hang = 0.2 }, false)
	VFX.Play("RoadRollerGo", dio, { Pos = Vector3.new(110, 3, 30), From = Vector3.new(110, 3, 0), Dir = Vector3.new(0, 0, 1), Hits = 2 }, false)
	task.wait(0.8)
	if not has("RoadRoller") then
		problem("DIO 74: ROAD ROLLER DA! - down it comes")
	end
	task.wait(0.6)
	local roller = has("RoadRoller")
	VFX.Play("RoadRollerBoom", dio, { Pos = Vector3.new(110, 3, 30) }, false)
	task.wait(0.1)
	-- (Debris is a no-op in the harness: it's thrown apart and handed to Debris)
	local body = roller and roller:FindFirstChildWhichIsA("BasePart")
	if VFX.DV.rollers[dio] or not body or body.Anchored then
		problem("DIO 74: ...and it goes up")
	end
	VFX.CancelCinematic()
	dio:Destroy()
	setAttr(localPlayer, "Quirk", quirkWas)
	setAttr(myChar, "Quirk", quirkWas)
	pump(0.2)
	VFX.Motion = realMotion
end)
if not ok74 then
	problem("round 74 client tests crashed: " .. tostring(err74))
end
end

print("== round 75: FLOAT, THE SLINGSHOT, THE BRAIDED WHIP, COLORADO FROM THE SKY, RECIPRO EXTEND, THE FLASH STEP, OVERHAUL, THE ULTS")
do
local ok75, err75 = pcall(function()
	local RunSvc = game:GetService("RunService")
	local UIS = game:GetService("UserInputService")
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	local quirkWas = localPlayer:GetAttribute("Quirk")
	local function pump(t)
		local t0 = os.clock()
		while os.clock() - t0 < t do
			signalOf(RunSvc, "Stepped"):Fire(0, 1 / 60)
			signalOf(RunSvc, "RenderStepped"):Fire(1 / 60)
			signalOf(RunSvc, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end
	local function has(name)
		for _, d in VFX.Folder:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end
	local function rig(name, pos)
		local m = makeR6(name, pos)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 0
			end
		end
		return m
	end
	local function sent(kind)
		local n, last = 0, nil
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == Config.PARKOUR_INDEX and f[3] == kind then
				n += 1
				last = f
			end
		end
		return n, last
	end
	local sounds = {}
	local realSound = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		sounds[name] = (sounds[name] or 0) + 1
		return realSound(name, ...)
	end
	setAttr(localPlayer, "Quirk", "FullCowl")
	setAttr(myChar, "Quirk", "FullCowl")
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Ragdolled", false)
	localPlayer:SetAttribute("NoCooldowns", true)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyMass = 12
	end)
	hum.FloorMaterial = Enum.Material.Plastic
	pump(0.3)

	-- FLOAT: pressed, he's still on his feet; a jump and he's up
	table.clear(fired)
	local FL = Config.FindAbilityById("Float")
	VFX.Play("Float", myChar, {}, true)
	pump(0.2)
	if root:FindFirstChild("Float") or sent("FloatLift") > 0 then
		problem("FLOAT 75: pressed on the street, he stays on his feet")
	end
	signalOf(UIS, "JumpRequest"):Fire()
	pump(0.2)
	local mover = root:FindFirstChild("Float")
	local n, lift = sent("FloatLift")
	if not (mover and n == 1 and mover.VectorVelocity.Y > 5) then
		problem("FLOAT 75: ...he jumps - and he's up, floating (" .. tostring(mover and mover.VectorVelocity) .. ", " .. n .. " lift-offs)")
	end
	hum.FloorMaterial = Enum.Material.Air
	-- the dash key: an Air Force flick behind him, thrown along the aim
	table.clear(fired)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	pump(0.05)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	local nb = sent("FloatBoost")
	mover = root:FindFirstChild("Float")
	if not (nb == 1 and mover and mover.VectorVelocity.Magnitude > FL.Speed) then
		problem("FLOAT 75: DASH while floating: an Air Force flick throws him (" .. nb .. " flicks, " .. tostring(mover and mover.VectorVelocity.Magnitude) .. ")")
	end
	if root:FindFirstChild("DashVelocity") or root:FindFirstChild("Dash") then
		problem("FLOAT 75: ...instead of a dash")
	end
	-- he settles onto something: back on his feet
	hum.FloorMaterial = Enum.Material.Plastic
	pump(0.6)
	if root:FindFirstChild("Float") or sent("FloatEnd") ~= 1 then
		problem("FLOAT 75: touching down puts him back on his feet (" .. sent("FloatEnd") .. ")")
	end
	-- and the others see it
	local foe = rig("Float75", Vector3.new(120, 10, 0))
	VFX.Play("FloatFX", foe, { Kind = "Lift", Dir = Vector3.yAxis }, false)
	VFX.Play("FloatFX", foe, { Kind = "Boost", Dir = Vector3.new(0, 0, 1) }, false)
	pump(0.3)
	if not VFX.FloatHover[foe] then
		problem("FLOAT 75: on everyone else's screen, he hangs there")
	end
	VFX.Play("FloatFX", foe, { Kind = "End" }, false)
	task.wait(0.05)
	if VFX.FloatHover[foe] then
		problem("FLOAT 75: ...until he's down")
	end
	foe:Destroy()
	pump(0.3)

	-- BLACKWHIP: a braid now - a core and strands, round, tapering
	VFX.Play("Blackwhip", myChar, { Dir = Vector3.new(0, 0, 1) }, true)
	task.wait(0.18)
	pump(0.05)
	local whip = has("Blackwhip")
	local cylinders = 0
	for _, p in whip and whip:GetChildren() or {} do
		if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
			cylinders += 1
		end
	end
	if not (whip and cylinders >= 40) then
		problem("WHIP 75: Blackwhip's a braid of round strands (" .. cylinders .. " cylinders)")
	end
	task.wait(0.3)

	-- THE SLINGSHOT: dash, then Blackwhip
	localPlayer:SetAttribute("QuirkPick", 1)
	table.clear(fired)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	pump(0.05)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	pump(0.1)
	local nw, w = sent("WhipDash")
	local att = root:FindFirstChild("WhipDashAttachment")
	local extraSent = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.EXTRA_INDEX then
			extraSent += 1
		end
	end
	if not (nw == 1 and typeof(w[4]) == "Vector3" and att and extraSent == 0) then
		problem("SLINGSHOT 75: dash then 4 - the whips throw him (" .. nw .. " slingshots, " .. extraSent .. " plain Blackwhips)")
	end
	pump(0.8)
	if root:FindFirstChild("WhipDashAttachment") then
		problem("SLINGSHOT 75: ...and let him go")
	end
	local foe2 = rig("Whip75", Vector3.new(130, 10, 0))
	VFX.Play("WhipDash", foe2, { Dir = Vector3.new(0, 0, 1), Time = 0.4, Speed = 165 }, false)
	pump(0.2)
	if not has("Blackwhip") then
		problem("SLINGSHOT 75: everyone else sees the whips")
	end
	pump(0.4)
	foe2:Destroy()
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	pump(0.1)
	local plain = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.EXTRA_INDEX then
			plain += 1
		end
	end
	if plain ~= 1 or sent("WhipDash") ~= 0 then
		problem("SLINGSHOT 75: no dash first - just Blackwhip")
	end
	pump(0.6)

	-- 100%: the arm holds - no crack, no blood
	sounds.ArmBreak = nil
	VFX.Play("HundredSmashBlast", myChar, { Dir = Vector3.new(0, 0, 1), Side = "R", Range = 100, Width = 26 }, false)
	task.wait(0.3)
	if sounds.ArmBreak then
		problem("100% 75: the arm doesn't break any more")
	end

	-- COLORADO SMASH: a crouch on the street while the camera's in the sky
	setAttr(localPlayer, "Quirk", "OneForAll")
	setAttr(myChar, "Quirk", "OneForAll")
	local CS = Config.FindAbilityById("ColoradoSmash")
	local cam = workspace.CurrentCamera
	setAttr(localPlayer, "QuirkAlt", true)
	pump(0.2)
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	setAttr(myChar, "Holding", "ColoradoSmash")
	pump(0.4)
	local camY = cam.CFrame.Position.Y - root.Position.Y
	local pressed = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.EXTRA_INDEX then
			pressed += 1
		end
	end
	if not (pressed == 1 and cam.CameraType == Enum.CameraType.Scriptable and camY > CS.Hold.SkyCam.Height * 0.5) then
		problem("COLORADO 75: 4 - he's crouched on the street, the camera's up over the city (" .. pressed .. " sent, " .. string.format("%.0f", camY) .. " up, " .. tostring(cam.CameraType) .. ")")
	end
	if not VFX.coloradoCharge[myChar] then
		problem("COLORADO 75: ...loading up in a crouch")
	end
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	setAttr(myChar, "Holding", nil)
	pump(0.2)
	local released = 0
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.RELEASE_INDEX then
			released += 1
		end
	end
	if released ~= 1 or (cam.CameraType == Enum.CameraType.Scriptable and not VFX.InCinematic()) then
		problem("COLORADO 75: 4 again - he goes for the spot, and the camera comes back down (" .. released .. " releases, " .. tostring(cam.CameraType) .. ")")
	end
	VFX.Play("HoldCancel", myChar, {}, true)
	setAttr(localPlayer, "QuirkAlt", false)
	pump(0.2)
	local might = rig("Might75", Vector3.new(140, 10, 0))
	VFX.Play("ColoradoSmash", might, { Dir = Vector3.new(0, 0, 1) }, false)
	pump(0.3)
	if not VFX.coloradoCharge[might] then
		problem("COLORADO 75: everyone sees him crouched, loading up")
	end
	VFX.Play("ColoradoGo", might, { Pos = Vector3.new(140, 3, 60), Time = 0.6 }, false)
	pump(0.2)
	if VFX.coloradoCharge[might] then
		problem("COLORADO 75: ...then he goes")
	end
	pump(1)
	might:Destroy()

	-- RECIPRO EXTEND: pipes out of his calves, and a rocket of a kick
	local iida = rig("Iida75", Vector3.new(150, 10, 0))
	VFX.Play("ReciproExtend", iida, { Dir = Vector3.new(0, 0, 1) }, false)
	pump(0.2)
	local pipes = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Metal and d.Size.X < 0.3 then
			pipes += 1
		end
	end
	if pipes < 2 then
		problem("RECIPRO EXTEND 75: the mufflers slide out of his calves (" .. pipes .. ")")
	end
	VFX.Play("ReciproExtendGo", iida, { Dir = Vector3.new(0, 0, 1), Time = 0.3, Speed = 175 }, false)
	VFX.Play("ReciproExtendHit", iida, { Target = myChar, Dir = Vector3.new(0, 0, 1), Carry = 0.2, Speed = 120 }, false)
	VFX.Play("ReciproExtendLaunch", iida, { Target = myChar, Dir = Vector3.new(0, 0, 1), Pos = Vector3.new(150, 10, 6) }, false)
	VFX.Play("ReciproExtendWhiff", iida, { Dir = Vector3.new(0, 0, 1) }, false)
	pump(0.6)
	iida:Destroy()

	-- THE FLASH STEP: he glitches out, and back in behind you, slow
	local deku = rig("Deku75", Vector3.new(160, 10, 0))
	deku:SetAttribute("Vanished", true)
	VFX.Play("PrimeFlashStep", deku, {}, false)
	task.wait(0.08)
	local ghosts = 0
	for _, d in VFX.Folder:GetChildren() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and (d.Color == VFX.PV.MAGENTA) then
			ghosts += 1
		end
	end
	if ghosts == 0 then
		problem("FLASH 75: he glitches out - a magenta copy torn off him")
	end
	task.wait(0.3)
	local arm = deku:FindFirstChild("Right Arm")
	if not (arm and arm.LocalTransparencyModifier == 1) then
		problem("FLASH 75: ...then he's gone")
	end
	local myRootNow = myChar:FindFirstChild("HumanoidRootPart")
	VFX.Play("FlashBehind", deku, { Target = myChar, Pos = myRootNow.Position + Vector3.new(0, 0, 3.3), Look = Vector3.new(0, 0, -1), Strike = 2.1, Place = 0.34, Name = "FLASH STEP" }, false)
	task.wait(0.2)
	if not VFX.InCinematic() or arm.LocalTransparencyModifier ~= 1 then
		problem("FLASH 75: behind YOU - the camera's on your face, he's not there yet")
	end
	local shots = VFX.Shots.FlashBehind
	local total = 0
	for _, s in shots do
		total += s.T
	end
	if not (#shots >= 8 and total > 2.6 and shots[1].From[1].X < 0 and shots[7].To[1].Z > 5) then
		problem("FLASH 75: the shot walks round from the left of his face to behind him (" .. #shots .. " shots, " .. total .. "s)")
	end
	task.wait(0.6)
	if arm.LocalTransparencyModifier ~= 0 then
		problem("FLASH 75: ...he glitches back in")
	end
	task.wait(1.0)
	VFX.Play("FlashStrike", deku, { Target = myChar, Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(0.1)
	if not has("VestigeFist") then
		problem("FLASH 75: the big punch - a fist of green light down the street")
	end
	task.wait(0.4)
	VFX.CancelCinematic()
	deku:SetAttribute("Vanished", nil)
	deku:Destroy()

	-- OVERHAUL: a lane that hits a wall bursts out of it
	local over = rig("Over75", Vector3.new(170, 10, 0))
	-- (a wall across the street 15 studs on; the street at y = 0)
	setRaycast(function(_, origin, dir)
		if dir.Z > 0.5 and origin.Z < 15 and origin.Z + dir.Z >= 15 then
			local t = (15 - origin.Z) / dir.Z
			return { Position = origin + dir * t, Normal = Vector3.new(0, 0, -1), Distance = dir.Magnitude * t }
		end
		if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
			local t = origin.Y / -dir.Y
			return { Position = origin + dir * t, Normal = Vector3.new(0, 1, 0), Distance = dir.Magnitude * t }
		end
		return nil
	end)
	VFX.Play("SpikeRush", over, { Dir = Vector3.new(0, 0, 1), Origin = Vector3.new(170, 10, 0) }, false)
	pump(0.9)
	local past = 0
	local spikeModel = has("SpikeRush")
	for _, p in spikeModel and spikeModel:GetDescendants() or {} do
		if p:IsA("BasePart") and p.Position.Z > 20 then
			past += 1
		end
	end
	if not spikeModel or past > 0 then
		problem("OVERHAUL 75: a wall in the way - the spikes stop at it (" .. past .. " through it)")
	end
	setRaycast(nil)
	pump(0.3)
	over:Destroy()

	-- MR. COMPRESS: SHOWTIME's spotlights, the marbles round him, THE GRAND FINALE
	local comp = rig("Compress75", Vector3.new(180, 10, 0))
	comp:SetAttribute("UltActive", true)
	comp:SetAttribute("Marbles", 2)
	VFX.Play("UltActivate", comp, { Quirk = "Compress" }, false)
	pump(0.4)
	if not VFX.MC.orbiting[comp] then
		problem("COMPRESS 75: SHOWTIME - his marbles circle him")
	end
	VFX.Play("MarbleRefill", comp, {}, false)
	local foe3 = rig("Finale75", Vector3.new(180, 10, 8))
	VFX.Play("GrandFinale", comp, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("FinaleGrab", comp, { Targets = { foe3 }, Juggle = 0.3 }, false)
	task.wait(0.1)
	local farm = foe3:FindFirstChild("Right Arm")
	if not (farm and farm.LocalTransparencyModifier == 1) then
		problem("COMPRESS 75: THE GRAND FINALE - they're marbles in his hand")
	end
	pump(0.3)
	VFX.Play("FinaleThrow", comp, { Targets = { foe3 }, Height = 30 }, false)
	VFX.Play("FinaleDrop", comp, { Spots = { Vector3.new(180, 3, 8) }, Fall = 0.3, Height = 30 }, false)
	task.wait(0.5)
	if farm.LocalTransparencyModifier ~= 0 then
		problem("COMPRESS 75: ...back down, full size")
	end
	comp:SetAttribute("UltActive", nil)
	pump(0.7)
	if VFX.MC.orbiting[comp] then
		problem("COMPRESS 75: SHOWTIME over - the marbles stop circling")
	end
	foe3:Destroy()
	comp:Destroy()

	-- LEMILLION: PHANTOM MENACE's entrance, and ENDGAME
	local lem = rig("Lem75", Vector3.new(190, 10, 0))
	VFX.Play("UltActivate", lem, { Quirk = "Lemillion" }, false)
	VFX.Play("PhantomEndgame", lem, { Dir = Vector3.new(0, 0, 1) }, false)
	VFX.Play("EndgameRise", lem, { Target = myChar, Pos = Vector3.new(190, 3, 10), Index = 1, Count = 1 }, false)
	pump(0.3)
	VFX.Play("EndgameDrop", lem, { Pos = Vector3.new(190, 3, 10), Time = 0.3 }, false)
	pump(0.4)
	VFX.Play("EndgameBlast", lem, { Pos = Vector3.new(190, 3, 10), Radius = 26 }, false)
	pump(0.5)
	VFX.CancelCinematic()
	lem:Destroy()

	VFX.PlaySound = realSound
	localPlayer:SetAttribute("NoCooldowns", nil)
	setAttr(localPlayer, "Quirk", quirkWas)
	setAttr(myChar, "Quirk", quirkWas)
	hum.FloorMaterial = Enum.Material.Plastic
	pump(0.3)
end)
if not ok75 then
	problem("round 75 client tests crashed: " .. tostring(err75))
end
end

print("== round 76: THE VOICE LINES FROM THE SOUND FOLDERS, WHY ARE YOU CRYING")
do
local ok76, err76 = pcall(function()
	local SS = game:GetService("SoundService")
	local V = Config.Voice
	local VC = VFX.VC
	local root = myChar:FindFirstChild("HumanoidRootPart")
	if not VC then
		problem("VOICE 76: the clip player (VFX.VC)")
		return
	end
	local function voices(name)
		local list = {}
		for _, d in SS:GetChildren() do
			if d:IsA("Sound") and d.Name == "Voice_" .. name then
				table.insert(list, d)
			end
		end
		return list
	end
	local function clearVoices()
		for _, d in SS:GetChildren() do
			if d:IsA("Sound") and string.sub(d.Name, 1, 6) == "Voice_" then
				d:Destroy()
			end
		end
	end
	-- a spy on the clip player: which line, lined up on what
	local calls = {}
	local realPlay = VC.play
	VC.play = function(name, where, beatAt)
		table.insert(calls, { name, beatAt, where })
		return realPlay(name, where, beatAt)
	end
	local function said(name)
		for _, c in calls do
			if c[1] == name then
				return c
			end
		end
		return nil
	end
	local function names()
		local t = {}
		for _, c in calls do
			table.insert(t, c[1])
		end
		return table.concat(t, ",")
	end

	-- a line plays its clip: the line's own id with no folder...
	clearVoices()
	VFX.Voice("Bakugo200", root)
	local v = voices("Bakugo200")[1]
	if not (v and v.SoundId == V.Bakugo200.Id and v.SoundGroup ~= nil) then
		problem("VOICE 76: a line plays its clip (" .. tostring(v and v.SoundId) .. ")")
	end
	-- ...and the folder's Sound when it's in Workspace (at its volume x Gain)
	local folder = Instance.new("Folder")
	folder.Name = "Bakugo"
	folder.Parent = workspace
	local snd = Instance.new("Sound")
	snd.Name = "Bakugo 200%"
	snd.SoundId = "rbxassetid://7676"
	snd.Volume = 0.8
	snd.Parent = folder
	clearVoices()
	VFX.Voice("Bakugo200", root)
	v = voices("Bakugo200")[1]
	if not (v and v.SoundId == "rbxassetid://7676" and math.abs(v.Volume - 0.8 * (V.Bakugo200.Gain or 2)) < 0.05) then
		problem("VOICE 76: the Sound in the Bakugo folder is what plays (" .. tostring(v and v.SoundId) .. ", " .. tostring(v and v.Volume) .. ")")
	end
	folder:Destroy()
	-- too far off to hear: nothing
	clearVoices()
	VFX.Voice("Bakugo200", root.Position + Vector3.new(0, 0, (V.Bakugo200.Range or 160) + 400))
	if #voices("Bakugo200") ~= 0 then
		problem("VOICE 76: past its range, nobody hears it")
	end

	-- the transformation: "I AM HERE!" lined up on the burst
	local P = Config.Quirks.OneForAll.Special.Presence
	table.clear(calls)
	VFX.Play("MuscleForm", myChar, { Alt = true }, true)
	task.wait(0.1)
	local c = said("IAmHere")
	if not (c and c[2] == P.BurstAt) then
		problem("VOICE 76: R into muscle form says I AM HERE, its beat on the burst (" .. names() .. ", " .. tostring(c and c[2]) .. ")")
	end
	local start, wait = VC.plan(V.IAmHere, nil, P.BurstAt)
	if not (wait > 0 and math.abs(wait + (V.IAmHere.Beat - start) - P.BurstAt) < 0.01) then
		problem(string.format("VOICE 76: ...so it starts %.2fs in and HERE lands at %.2fs", wait, wait + V.IAmHere.Beat - start))
	end
	task.wait(P.BurstAt + 0.3)
	VFX.ReleasePose(myChar, 0)

	-- All Might's moves: the charge before every one, DETROIT SMASH on the Detroit only
	local aim = { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -30), Seed = 76, Origin = Vector3.new(0, 3, 0) }
	table.clear(calls)
	local quirkWas76 = myChar:GetAttribute("Quirk")
	setAttr(myChar, "Quirk", "OneForAll") -- (round 77: SMASH! is All Might's)
	VFX.Play("DetroitSmash", myChar, aim, true)
	task.wait(0.05)
	if not (said("MightCharge") and said("MightSmash")) then
		problem("VOICE 76: Detroit Smash - the charge, then SMASH! (round 77) (" .. names() .. ")")
	end
	setAttr(myChar, "Quirk", quirkWas76)
	task.wait(0.5)
	table.clear(calls)
	VFX.Play("TexasSmash", myChar, aim, true)
	task.wait(0.05)
	if not (said("MightCharge") and not said("MightSmash")) then
		problem("VOICE 76: Texas Smash - the charge, no SMASH! line (" .. names() .. ")")
	end
	task.wait(0.5)
	VFX.ReleasePose(myChar, 0)
	-- a training dummy's counter stance is silent (it isn't All Might)
	local dummy = makeR6("CounterDummy76", Vector3.new(30, 3, 30))
	table.clear(calls)
	VFX.Play("HeroCounter", dummy, {}, false)
	task.wait(0.05)
	if #calls ~= 0 then
		problem("VOICE 76: a dummy's counter stance says nothing (" .. names() .. ")")
	end
	dummy:Destroy()

	-- the awakenings
	for q, line in { Explosion = "Bakugo200", FullCowl = "DekuAwaken" } do
		table.clear(calls)
		VFX.Play("UltActivate", myChar, { Quirk = q }, true)
		task.wait(0.05)
		if not said(line) then
			problem("VOICE 76: " .. q .. "'s awakening says " .. line .. " (" .. names() .. ")")
		end
		VFX.CancelCinematic()
		task.wait(0.2)
	end
	table.clear(calls)
	VFX.Play("UltActivate", myChar, { Quirk = "HalfCold" }, true)
	task.wait(0.05)
	if #calls ~= 0 then
		problem("VOICE 76: Todoroki's awakening has no line (" .. names() .. ")")
	end
	VFX.CancelCinematic()
	task.wait(0.2)
	VFX.ReleasePose(myChar, 0)

	-- UNITED STATES OF SMASH: the charge is long enough, "SMASH!!" on the punch
	local uss = Config.FindAbilityById("UnitedStatesSmash")
	local shots = VFX.Shots.USSCatch -- (round 78: from the catch, through the build)
	if not (uss.BuildTime and math.abs(shots[1].T + shots[2].T - uss.BuildTime) < 0.01) then
		problem("VOICE 76: USS - the camera stays on the fist through the build (" .. tostring(shots[1].T + shots[2].T) .. ")")
	end
	table.clear(calls)
	VFX.Play("USSCatch", myChar, { Dir = aim.Dir, Build = uss.BuildTime, Freeze = uss.FreezeTime, Slam = uss.SlamTime }, false)
	task.wait(0.1)
	c = said("MightUSS")
	if not (c and c[2] == uss.BuildTime and not said("MightCharge")) then
		problem("VOICE 76: USS says UNITED STATES OF SMASH, its beat on the punch (round 78: on the catch) (" .. names() .. ")")
	end
	VFX.CancelCinematic()
	task.wait(uss.BuildTime + uss.FreezeTime + 0.3)
	VFX.CancelCinematic()
	VFX.ReleasePose(myChar, 0)

	-- Bakugo's Explosive Speed: "I'M THE FINAL BOSS, GOT IT?" - trimmed
	table.clear(calls)
	VFX.Play("ExplosiveSpeed", myChar, aim, true)
	task.wait(0.05)
	if not said("FinalBoss") then
		problem("VOICE 76: Explosive Speed - I'M THE FINAL BOSS (" .. names() .. ")")
	end
	local s0, w0, stop = VC.plan(V.FinalBoss, nil, nil)
	if not (w0 == 0 and stop and stop > s0 + 1 and stop < (V.FinalBoss.Length or 8) - 1) then
		problem("VOICE 76: ...trimmed before ALL FOR ONE (" .. tostring(stop) .. ")")
	end
	VFX.Play("ExplosiveSpeedCancel", myChar, {}, true)
	task.wait(0.2)
	VFX.ReleasePose(myChar, 0)

	-- Prime All Might's meteor: "HERE!" on the landing
	table.clear(calls)
	VFX.Play("MeteorFall", myChar, { Pos = Vector3.new(0, 0, -20), Look = 0.5, Fall = 0.4, Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.05)
	c = said("IAmHere")
	if not (c and math.abs((c[2] or 0) - 0.9) < 1e-6) then
		problem("VOICE 76: the meteor says I AM HERE, its beat on the landing (" .. names() .. ")")
	end
	task.wait(1)
	VFX.ReleasePose(myChar, 0)
	VC.play = realPlay

	-- WHY ARE YOU CRYING: never silent
	local why
	for _, e in Config.Emotes do
		if e.Id == "WhyCry" then
			why = e
		end
	end
	local id = VFX.EmoteSong(why)
	if not (why.Song ~= "" or (id == why.FallbackSong and id and id ~= "")) then
		problem("WHY CRY 76: with no upload it plays the licensed fallback (" .. tostring(id) .. ")")
	end
	local ef = Instance.new("Folder")
	ef.Name = "Emotes"
	ef.Parent = workspace
	local up = Instance.new("Sound")
	up.Name = "WHY ARE YOU CRYING"
	up.SoundId = "rbxassetid://7777"
	up.Volume = 0.5
	up.Parent = ef
	local id2, vol2, at2 = VFX.EmoteSong(why)
	if not (id2 == "rbxassetid://7777" and vol2 > 0.5 and at2 == (why.SongStart or 0)) then
		problem("WHY CRY 76: a Sound in Workspace > Emotes named after it wins (" .. tostring(id2) .. ")")
	end
	VFX.ReleasePose(myChar, 0)
	pcall(function()
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	setAttr(myChar, "Stunned", false)
	setAttr(myChar, "Ragdolled", false)
	task.wait(0.1)
	VFX.Play("Emote", myChar, { Id = "WhyCry" }, false)
	task.wait(0.1)
	local song = root:FindFirstChild("EmoteSong")
	if not (song and song.SoundId == "rbxassetid://7777") then
		problem("WHY CRY 76: ...and that's the song the emote plays (" .. tostring(song and song.SoundId) .. ")")
	end
	ef:Destroy()
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
	end)
	task.wait(0.3)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
	end)
	task.wait(0.5)
	VFX.ReleasePose(myChar, 0)
	clearVoices()
end)
if not ok76 then
	problem("round 76 tests errored: " .. tostring(err76))
end
end

print("== round 77: SMASH! ON THE DETROIT SMASH, ALL MIGHT'S PUNCHES")
do
local ok77, err77 = pcall(function()
	local VC = VFX.VC
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local quirkWas77 = myChar:GetAttribute("Quirk")
	setAttr(myChar, "Quirk", "OneForAll")
	-- spies: the voice lines and the sound cues
	local said77, cues77 = {}, {}
	local realPlay77, realSound77 = VC.play, VFX.PlaySound
	VC.play = function(name, where, beatAt)
		table.insert(said77, { name, beatAt })
		return realPlay77(name, where, beatAt)
	end
	VFX.PlaySound = function(name, ...)
		cues77[name] = (cues77[name] or 0) + 1
		return realSound77(name, ...)
	end
	local function line(name)
		for _, c in said77 do
			if c[1] == name then
				return c
			end
		end
		return nil
	end
	local aim = { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -30), Seed = 77, Origin = Vector3.new(0, 3, 0) }

	-- Detroit Smash: the charge, then SMASH! on the punch; his own impact
	VFX.ReleasePose(myChar, 0)
	VFX.Play("DetroitSmash", myChar, aim, true)
	task.wait(0.5)
	local sm = line("MightSmash")
	if not (line("MightCharge") and sm and sm[2] == 0.35 and not line("MightDetroit")) then
		problem("SMASH 77: Detroit Smash - the charge, then SMASH! landing on the punch (" .. tostring(sm and sm[2]) .. ")")
	end
	if not (cues77.MightImpact and not cues77.DetroitImpact) then
		problem("SMASH 77: ...and All Might's own Detroit impact sound")
	end
	-- the smashes and the ult use his cues
	table.clear(cues77)
	VFX.Play("CarolinaSmash", myChar, aim, true)
	task.wait(0.6)
	if not (cues77.MightSmash and not cues77.Smash) then
		problem("SMASH 77: Carolina Smash sounds like All Might's smash")
	end
	VFX.ReleasePose(myChar, 0)

	-- his punches landing: his own hit sounds; anyone else's: the shared ones
	local foe = makeR6("Foe77", Vector3.new(0, 3, -6))
	table.clear(cues77)
	VFX.Play("Hit", nil, { Target = foe, Amount = 5, Attacker = localPlayer }, false)
	VFX.Play("Hit", nil, { Target = foe, Amount = 30, Attacker = localPlayer }, false)
	task.wait(0.1)
	if not (cues77.MightHit and cues77.MightHeavyHit and not cues77.Hit and not cues77.HeavyHit) then
		problem("SMASH 77: All Might's hits sound like his (light and heavy)")
	end
	setAttr(myChar, "Quirk", "Explosion")
	table.clear(cues77)
	VFX.Play("Hit", nil, { Target = foe, Amount = 5, Attacker = localPlayer }, false)
	task.wait(0.1)
	if not (cues77.Hit and not cues77.MightHit) then
		problem("SMASH 77: ...Bakugo's still sound like everyone's")
	end
	setAttr(myChar, "Quirk", "OneForAll")
	foe:Destroy()

	-- the equaliser on a layer, and a Peak layer starting just before its peak
	VC.shapes["rbxassetid://9113535176"] = { Peak = 0.5 }
	VC.shapes["rbxassetid://9113535217"] = { Peak = 0.5 }
	local eqSeen, peakAt = false, nil
	for _ = 1, 280 do
		VFX.PlaySound("MightHeavyHit", root.Position, 1)
		task.wait(0.05)
		for _, d in workspace.Terrain:GetDescendants() do
			if d:IsA("Sound") and (d.SoundId == "rbxassetid://9113535176" or d.SoundId == "rbxassetid://9113535217") and d.Parent and d.Parent.Name == "Sound_MightHeavyHit" then
				peakAt = d.TimePosition
				eqSeen = eqSeen or d:FindFirstChildOfClass("EqualizerSoundEffect") ~= nil
			end
		end
		if peakAt then
			break
		end
	end
	if not (peakAt and math.abs(peakAt - 0.44) < 1e-3) then
		problem("SMASH 77: a Peak layer starts just before its loudest moment (" .. tostring(peakAt) .. ")")
	end
	if not eqSeen then
		problem("SMASH 77: ...with the equaliser pushing its lows")
	end

	VC.play, VFX.PlaySound = realPlay77, realSound77
	setAttr(myChar, "Quirk", quirkWas77)
	VFX.ReleasePose(myChar, 0)
end)
if not ok77 then
	problem("round 77 tests errored: " .. tostring(err77))
end
end

print("== round 78: UNITED STATES OF SMASH ONLY ON A HIT, THE IMPACT FRAME, THE NEW TWISTER")
do
local ok78, err78 = pcall(function()
	local USS = VFX.USS
	local uss = Config.FindAbilityById("UnitedStatesSmash")
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local Lighting = game:GetService("Lighting")
	local quirkWas78 = myChar:GetAttribute("Quirk")
	setAttr(myChar, "Quirk", "OneForAll")
	local d = Vector3.new(0, 0, -1)
	local aim = { Dir = d, Pos = root.Position + d * 20, Seed = 78, Origin = root.Position }
	-- spies: sounds, voice lines, motions, the music duck
	local cues78, said78, motions78, ducks78 = {}, {}, {}, {}
	local realSound, realPlay, realMotion, realDuck = VFX.PlaySound, VFX.VC.play, VFX.Motion, VFX.Hooks.DuckMusic
	VFX.PlaySound = function(name, ...)
		cues78[name] = (cues78[name] or 0) + 1
		return realSound(name, ...)
	end
	VFX.VC.play = function(name, where, beatAt)
		table.insert(said78, { name, beatAt })
		return realPlay(name, where, beatAt)
	end
	VFX.Motion = function(char, name)
		if char == myChar then
			table.insert(motions78, name)
		end
		return realMotion(char, name)
	end
	VFX.Hooks.DuckMusic = function(...)
		table.insert(ducks78, { ... })
		if realDuck then
			return realDuck(...)
		end
	end
	local function moved(name)
		return table.find(motions78, name) ~= nil
	end
	-- (the place's clips: this early in the run nothing's loaded them yet)
	local RS78 = game:GetService("ReplicatedStorage")
	local anims78
	if not RS78:FindFirstChild("Animations") then
		anims78 = r.deserializeModel(fs.readFile(process.env.ANIM_RBXM or "../anim/out78/Animations_r78.rbxm"))[1]
		anims78.Parent = RS78
	end
	-- the lunge's push (the harness's Debris never removes anything: other
	-- moves' old ones are still lying about)
	local function lungeForce()
		for _, x in root:GetChildren() do
			if x.Name == "USSLunge" and x:IsA("LinearVelocity") and x.VectorVelocity:Dot(d) > (uss.Lunge / uss.LungeTime) * 0.95 then
				return x
			end
		end
		return nil
	end

	-- the clips are in the place (open them in the Animation Editor / Moon Animator)
	local build, smash = VFX.GetClip("MoveUSSBuild"), VFX.GetClip("MoveUSSSmash")
	for _, name in { "MoveUSSLunge", "MoveUSSWhiff", "MoveUSSBuild", "MoveUSSSmash", "MoveUSSVictory" } do
		if not VFX.GetClip(name) then
			problem("USS 78: the keyframed clip " .. name .. " is in ReplicatedStorage.Animations")
		end
		if not VFX.Motions[(string.gsub(name, "^Move", ""))] then
			problem("USS 78: ...and a motion for bodies without it (" .. name .. ")")
		end
	end
	if not (build and build.holdAt and smash and smash.hit and math.abs(smash.hit - 0.06) < 1e-3) then
		problem("USS 78: the build holds on its Hold key; the smash lands 0.06s in")
	end

	-- the press: the decoy left, lunging in - no cutscene yet
	VFX.CancelCinematic()
	VFX.ReleasePose(myChar, 0)
	VFX.Play("UnitedStatesSmash", myChar, aim, true)
	task.wait(uss.LungeStartup + 0.05)
	local lv = lungeForce()
	if not (lv and USS.lunges[myChar]) then
		problem("USS 78: the press lunges him in (" .. tostring(lv and lv.VectorVelocity) .. ")")
	end
	if VFX.InCinematic() or not moved("USSLunge") then
		problem("USS 78: ...with the decoy left, no cutscene unless it lands")
	end
	-- nobody there: he stumbles out of it
	VFX.Play("USSWhiff", myChar, { Dir = d }, false)
	task.wait(0.05)
	if USS.lunges[myChar] or lungeForce() or not moved("USSWhiff") or not cues78.USSWhiff then
		problem("USS 78: a whiff stops the lunge, over-reaches and stumbles")
	end
	task.wait(0.8)
	VFX.ReleasePose(myChar, 0)

	-- caught: the decoy lands, the build ("UNITED STATES OF..." - SMASH on
	-- the strike), the impact frame and the freeze
	local foe = makeR6("Foe78", root.Position + d * 4.6)
	table.clear(said78)
	table.clear(cues78)
	table.clear(motions78)
	VFX.Play("UnitedStatesSmash", myChar, aim, true)
	task.wait(0.1)
	VFX.Play("USSCatch", myChar, { Target = foe, Dir = d, Id = "UnitedStatesSmash", Build = uss.BuildTime, Freeze = uss.FreezeTime, Slam = uss.SlamTime }, false)
	task.wait(0.1)
	local line
	for _, c in said78 do
		if c[1] == "MightUSS" then
			line = c
		end
	end
	if not (line and line[2] == uss.BuildTime) then
		problem("USS 78: the catch says UNITED STATES OF..., SMASH on the strike (" .. tostring(line and line[2]) .. ")")
	end
	if not (VFX.InOwnCinematic() and cues78.USSJab and USS.caught[myChar] and not USS.lunges[myChar]) then
		problem("USS 78: the decoy lands (its hit, the cutscene, the lunge over)")
	end
	local shots = VFX.Shots.USSCatch
	local total = 0
	for _, s in shots do
		total += s.T
	end
	if not (math.abs(shots[1].T + shots[2].T - uss.BuildTime) < 0.01 and math.abs(shots[3].T - uss.FreezeTime) < 0.01) then
		problem("USS 78: the camera's on the build, then the fist on the face for the freeze")
	end
	task.wait(uss.BuildTime - 0.25)
	local cc = Lighting:FindFirstChild("USSImpactFrame")
	if cc and cc.Enabled then
		problem("USS 78: no impact frame before the strike")
	end
	task.wait(0.25)
	task.wait(0.06)
	cc = Lighting:FindFirstChild("USSImpactFrame")
	if not (cc and cc.Enabled and cc.Saturation == -1) then
		problem("USS 78: the strike: the impact frame")
	end
	if not (moved("USSSmash") and cues78.USSStrike and #ducks78 == 1 and ducks78[1][1] == uss.MusicDuck) then
		problem("USS 78: ...the overhand right, its crack, and the music drops out from under it")
	end
	task.wait(uss.FreezeTime + 0.1)
	if cc.Enabled then
		problem("USS 78: the impact frame lets go after the freeze")
	end

	-- the slam: the crater, the dust wall, the new twister, the raised fist
	local folderV = workspace:FindFirstChild("QuirkVFX") or workspace
	local pos = root.Position + d * 5.5 - Vector3.new(0, 3, 0)
	VFX.Play("USSSlam", myChar, { Pos = pos, Target = foe, Dir = d, Id = "UnitedStatesSmash" }, false)
	task.wait(0.05)
	if not cues78.MightUSSImpact then
		problem("USS 78: the slam's boom")
	end
	local tw
	for _, m in folderV:GetDescendants() do
		if m.Name == "Twister" and m:IsA("Model") then
			tw = m
		end
	end
	local beams = {}
	for _, b in (tw and tw:GetDescendants()) or {} do
		if b:IsA("Beam") then
			table.insert(beams, b)
		end
	end
	if not (tw and #beams >= 40) then
		problem("USS 78: the twister's wind is soft streaks (" .. #beams .. " beams)")
	end
	-- a streak bends round the funnel: its curve's middle stays on the circle
	local b = beams[1]
	if b then
		local a0, a1 = b.Attachment0.CFrame, b.Attachment1.CFrame
		local p0, p3 = a0.Position, a1.Position
		local p1 = p0 + a0.RightVector * b.CurveSize0
		local p2 = p3 - a1.RightVector * b.CurveSize1
		local mid = (p0 + p1 * 3 + p2 * 3 + p3) / 8
		local r0 = Vector3.new(p0.X, 0, p0.Z).Magnitude
		local rm = Vector3.new(mid.X, 0, mid.Z).Magnitude
		if not (r0 > 5 and math.abs(rm - r0) / r0 < 0.06) then
			problem(string.format("USS 78: a streak follows the circle round (ends %.1f, middle %.1f studs out)", r0, rm))
		end
	end
	local sky = Lighting:FindFirstChild("TwisterSky")
	if not sky then
		problem("USS 78: the sky darkens round it")
	end
	task.wait(1.5)
	local seen = 0
	for _, bm in beams do
		if bm.Transparency.Keypoints[2].Value < 0.9 then
			seen += 1
		end
	end
	if seen < #beams * 0.3 then
		problem("USS 78: grown, its streaks show (" .. seen .. " of " .. #beams .. ")")
	end
	if not moved("USSVictory") then
		problem("USS 78: the raised fist")
	end
	task.wait(uss.TwisterTime + 1.6 - 1.5)
	if tw.Parent then
		problem("USS 78: the twister dies away when it's done")
	end
	task.wait(1.4)
	-- (Debris takes it away in the game; here it's left, cleared)
	if sky and sky.Parent and not (sky.Brightness > -0.01 and sky.Contrast < 0.01) then
		problem("USS 78: ...and the sky clears")
	end
	foe:Destroy()

	-- a layer with Fade dies away over its last Fade seconds; one without
	-- still cuts at its Length
	table.clear(cues78)
	VFX.PlaySound("USSWhiff", root.Position, 1)
	task.wait(0.1)
	local function find(ids)
		for _, s in workspace.Terrain:GetDescendants() do
			if s:IsA("Sound") and table.find(ids, s.SoundId) then
				return s
			end
		end
		return nil
	end
	local faded = find({ "rbxassetid://9120695130", "rbxassetid://9120695365" })
	local cut = find({ "rbxassetid://9119700676", "rbxassetid://9119700795", "rbxassetid://9119700943" })
	local v0 = faded and faded.Volume
	task.wait(0.4)
	if not (faded and cut and faded.Parent and faded.Volume < v0 * 0.9 and cut.Parent) then
		problem("USS 78: a Fade layer's dying away halfway in (" .. tostring(faded and faded.Volume) .. " from " .. tostring(v0) .. ")")
	end
	task.wait(0.35)
	if faded.Parent then
		problem("USS 78: ...and gone at its Length")
	end

	-- the music: ducked down and swelling back
	if realDuck and VFX.Hooks.MusicDuck then
		realDuck(0.15, 0.04, 0.3, 1)
		task.wait(0.15)
		local low = VFX.Hooks.MusicDuck()
		task.wait(1.4)
		local back = VFX.Hooks.MusicDuck()
		if not (math.abs(low - 0.15) < 0.02 and back == 1) then
			problem(string.format("USS 78: the music ducks to %.2f and comes back (%.2f)", low, back))
		end
	else
		problem("USS 78: the client sets up the music duck")
	end

	VFX.PlaySound, VFX.VC.play, VFX.Motion, VFX.Hooks.DuckMusic = realSound, realPlay, realMotion, realDuck
	VFX.CancelCinematic()
	if anims78 then
		anims78:Destroy()
	end
	setAttr(myChar, "Quirk", quirkWas78)
	VFX.ReleasePose(myChar, 0)
end)
if not ok78 then
	problem("round 78 tests errored: " .. tostring(err78))
end
end

print("== round 84: RADIO WAVES (THE GOLD ORB, THE YELLOW-GREEN BLAST), THE RIVETS")
do
local ok84, err84 = pcall(function()
	local root = myChar:FindFirstChild("HumanoidRootPart")
	local quirkWas84 = myChar:GetAttribute("Quirk")
	setAttr(myChar, "Quirk", "Decay")
	local folder84 = VFX.Folder or workspace
	local DKP = VFX.DecayKit.PAL
	local function close(c1, c2)
		return math.abs(c1.R - c2.R) + math.abs(c1.G - c2.G) + math.abs(c1.B - c2.B) < 0.03
	end
	local function named(name)
		local out = {}
		for _, p in folder84:GetDescendants() do
			if p.Name == name and p:IsA("BasePart") then
				table.insert(out, p)
			end
		end
		return out
	end
	local cues84 = {}
	local realSound84 = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		cues84[name] = (cues84[name] or 0) + 1
		return realSound84(name, ...)
	end
	local rw = Config.FindAbilityById("RadioWaves")
	local d = Vector3.new(0, 0, -1)

	-- RADIO WAVES: Air Cannon's gold orb swells round his palm (a bright-rimmed
	-- bubble), flickering violet with black lightning across it
	VFX.CancelCinematic()
	VFX.Play("RadioWaves", myChar, { Dir = d }, true)
	task.wait(rw.Windup * 0.2)
	local orb = named("RadioOrb")[1]
	if not (orb and orb.Material == Enum.Material.ForceField and close(orb.Color, DKP.GOLD)) then
		problem("RADIO 84: the gold orb round his palm (a ForceField bubble)")
	end
	local size0 = orb and orb.Size.X or 0
	local sawViolet, biggest = false, size0
	local t0 = os.clock()
	while orb and orb.Parent and os.clock() - t0 < rw.Windup do
		sawViolet = sawViolet or close(orb.Color, DKP.VIOLET)
		biggest = math.max(biggest, orb.Size.X)
		task.wait()
	end
	-- (on a slow frame the test can miss a flicker the effect showed: the
	-- effect's own count)
	local info = VFX.DecayKit.lastOrb or {}
	if not (orb and (info.size or biggest) > size0 * 2 and (sawViolet or (info.flickers or 0) >= 2)) then
		problem("RADIO 84: ...it swells, flickering violet (" .. tostring(info.size) .. ", flickers " .. tostring(info.flickers) .. ")")
	end
	task.wait(0.12)
	if orb and orb.Parent then
		problem("RADIO 84: the orb pops when the blast goes")
	end
	-- THE YELLOW PARTS: the bright yellow streaks tearing out, the yellow-green haze
	local streaks84 = named("RadioStreak")
	local yellow = 0
	for _, p in streaks84 do
		if close(p.Color, DKP.YELLOW) and p.Material == Enum.Material.Neon then
			yellow += 1
		end
	end
	if yellow < 8 then
		problem("RADIO 84: the bright yellow streaks of the blast (" .. yellow .. ")")
	end
	-- (the harness applies a tween's goal at once: where they end up)
	local far = 0
	task.wait(0.35)
	for _, p in streaks84 do
		if (p.CFrame.Position - root.Position).Magnitude > 25 then
			far += 1
		end
	end
	if far < yellow * 0.5 then
		problem("RADIO 84: ...tearing out across the fan (" .. far .. " of " .. yellow .. " out past 25 studs)")
	end
	local haze = named("RadioHaze")
	if #haze < 3 or not close(haze[1].Color, DKP.HAZE) then
		problem("RADIO 84: the street left in yellow-green haze (" .. #haze .. ")")
	end
	local tint = game:GetService("Lighting"):FindFirstChild("RadioTint")
	if not (tint and tint.Enabled) then
		problem("RADIO 84: the air round it washed yellow-green")
	end
	if not (cues84.RadioCharge and cues84.RadioWaves) then
		problem("RADIO 84: the charge's crackle and the blast")
	end
	task.wait(1.5)
	if tint and tint.TintColor.G < 0.99 then
		problem("RADIO 84: ...for a moment")
	end

	-- the jam on someone, for everyone: static crackling round their head
	local foe = makeR6("Foe84", root.Position + Vector3.new(0, 0, -12))
	local head = foe:FindFirstChild("Head")
	head.CFrame = r.CFrame.new(root.Position + Vector3.new(0, 1.5, -12))
	head.Position = root.Position + Vector3.new(0, 1.5, -12)
	local before = {}
	for _, p in folder84:GetDescendants() do
		before[p] = true
	end
	VFX.Play("RadioJam", nil, { Target = foe, Duration = 0.4 }, false)
	task.wait(0.25)
	local static = 0
	for _, p in folder84:GetDescendants() do
		if not before[p] and p:IsA("BasePart") and close(p.Color, DKP.STATIC) and (p.CFrame.Position - head.Position).Magnitude < 4 then
			static += 1
		end
	end
	if static < 2 or not cues84.RadioJam then
		problem("JAM 84: static crackles round a jammed head, for everyone (" .. static .. ")")
	end
	task.wait(0.3)

	-- RIVET STAB: rivets grow out of the fingertips, shoot out, pull back in
	-- (the harness applies every tween's goal at once: each segment's last
	-- goal is where it ends - drawn back to nothing at its root, not
	-- crumbled to a stub)
	local rs = Config.FindAbilityById("RivetStab")
	local before3 = {}
	for _, p in folder84:GetDescendants() do
		before3[p] = true
	end
	VFX.Play("RivetStab", myChar, { Dir = d }, true)
	task.wait(rs.Windup + 0.1)
	local tendrils, back = 0, 0
	for _, p in folder84:GetDescendants() do
		if not before3[p] and p:IsA("BasePart") and close(p.Color, DKP.TENDRIL) then
			tendrils += 1
			if p.Size.Z <= 0.06 and p.Transparency >= 0.99 then
				back += 1
			end
		end
	end
	if tendrils < 5 * 4 + 5 * 2 then
		problem("RIVET 84: five rivets grow out of his fingertips and shoot out (" .. tendrils .. " segments)")
	end
	if back < tendrils * 0.8 then
		problem("RIVET 84: ...and pull back into his fingers (" .. back .. " of " .. tendrils .. ")")
	end

	-- the pin: three rivets from his hand into them, following them as
	-- they're reeled in, then pulled back in
	local torso = foe:FindFirstChild("Torso")
	local froot = foe:FindFirstChild("HumanoidRootPart")
	local function placeFoe(pos)
		for _, part in { torso, froot } do
			part.CFrame = r.CFrame.new(pos)
			part.Position = pos
		end
	end
	placeFoe(root.Position + Vector3.new(0, 0, -12))
	local before2 = {}
	for _, p in folder84:GetDescendants() do
		before2[p] = true
	end
	table.clear(cues84)
	VFX.Play("RivetPin", myChar, { Target = foe, Pin = 0.3, Reel = 0.25, ReelTo = 5 }, false)
	task.wait(0.1)
	local function reaching(pos)
		local n = 0
		for _, p in folder84:GetDescendants() do
			if not before2[p] and p:IsA("BasePart") and p.Parent and close(p.Color, DKP.TENDRIL) and p.Transparency < 0.5 then
				for _, z in { -1, 1 } do
					local tip = p.CFrame * r.CFrame.new(0, 0, z * p.Size.Z / 2)
					if (tip.Position - pos).Magnitude < 1.6 then
						n += 1
					end
				end
			end
		end
		return n
	end
	local n1 = reaching(torso.Position)
	if n1 < 2 then
		problem("RIVET 84: the pinned one is skewered on the rivets from his hand (" .. n1 .. " reach them)")
	end
	placeFoe(root.Position + Vector3.new(0, 0, -7))
	task.wait(0.1)
	local n2 = reaching(torso.Position)
	if n2 < 2 then
		problem("RIVET 84: ...and they follow them in as they're reeled (" .. n2 .. ")")
	end
	if not (cues84.Rivet) then
		problem("RIVET 84: the pierce's sound")
	end
	task.wait(0.3 + 0.25 + 0.35)
	local left = 0
	for _, p in folder84:GetDescendants() do
		if not before2[p] and p:IsA("BasePart") and p.Parent and close(p.Color, DKP.TENDRIL) and p.Transparency < 0.5 then
			left += 1
		end
	end
	if left > 0 or not cues84.RivetReel then
		problem("RIVET 84: the reel's whoosh, then the rivets are gone back into his fingers (" .. left .. " left)")
	end

	-- RIVET STORM, lifting them, the slam
	VFX.Play("RivetStorm", myChar, {}, true)
	task.wait(0.35)
	VFX.Play("RivetLift", myChar, { Targets = { foe }, Lift = 9, Hold = 0.3, Slam = 0.1 }, false)
	task.wait(0.1)
	local lifted = reaching(torso.Position)
	if lifted < 1 then
		problem("RIVET 84: Rivet Storm: the ones caught are held up on rivets out of his back (" .. lifted .. ")")
	end
	table.clear(cues84)
	VFX.Play("RivetSlam", myChar, { Points = { root.Position + Vector3.new(0, -3, -12) } }, false)
	task.wait(0.1)
	if not cues84.TentacleSlam then
		problem("RIVET 84: ...slammed into the street (its thud)")
	end
	task.wait(1)
	foe:Destroy()
	VFX.PlaySound = realSound84
	setAttr(myChar, "Quirk", quirkWas84)
	VFX.ReleasePose(myChar, 0)
end)
if not ok84 then
	problem("round 84 tests errored: " .. tostring(err84))
end
end


print("== round 94: THE CITY BACK AFTER A WIPE (a streaming place; the server's rebuild)")
do
local ok85, err85 = pcall(function()
	local WS = VFX.ST.World
	local LWX = VFX.LWX
	local LWC = Config.DevFlight.LightWipe
	local map = workspace:FindFirstChild("Map")
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map"
		map.Parent = workspace
	end
	local function folder(name)
		local f = map:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = map
		end
		return f
	end
	folder("Roads")
	local buildings = folder("Buildings")
	-- far from this screen's body (nobody's pushed out of it), on the street
	local origin = Vector3.new(900, 25.5, 900)
	local street = WS.street(origin, map)
	local block = Instance.new("Model")
	block.Name = "Block85"
	block.Parent = buildings
	local parts = {}
	for i = 1, 6 do
		local p = Instance.new("Part")
		p.Name = "Floor85_" .. i
		p.Anchored = true
		p.Size = Vector3.new(12, 10, 12)
		p.CFrame = r.CFrame.new(origin + Vector3.new(60, street - origin.Y + 5 + (i - 1) * 10, 0))
		p.Color = r.Color3.fromRGB(150, 140, 130)
		p.LocalTransparencyModifier = 0 -- (the harness's parts have no default for it)
		p.CanQuery = true
		p.Parent = block
		parts[i] = p
	end
	local lamp = Instance.new("SurfaceLight")
	lamp.Enabled = true
	lamp.Parent = parts[2]
	local function stepFor(st, elapsed, frames)
		st.at = workspace:GetServerTimeNow() - elapsed
		for _ = 1, frames or 3 do
			if st.finished then
				return
			end
			WS.step(st, 1 / 60)
		end
	end

	local st = WS.go(origin, Vector3.new(0, 0, -1), workspace:GetServerTimeNow(), LWC.Wave, nil, LWX.opts())
	if not (st and st.radial and st.kind == "light") then
		problem("WIPE 94: a light wipe runs on this screen")
		return
	end
	stepFor(st, 1.5, 4)
	local hidden = 0
	for _, p in parts do
		if p.LocalTransparencyModifier >= 1 and not p.CanCollide then
			hidden += 1
		end
	end
	if hidden < #parts or lamp.Enabled then
		problem("WIPE 94: the wave hides the block, its light off (" .. hidden .. " of " .. #parts .. ")")
	end
	-- THE STREAMING PLACE (Workspace.StreamingEnabled, opportunistic
	-- stream-out): two of its floors stream out while the city's gone - a
	-- part streamed out is only parented to nil, and streams back in as the
	-- same part
	parts[2].Parent = nil
	parts[5].Parent = nil
	-- the server's rebuild halfway through the hold: a part the blast carved
	-- comes back (a new one on this screen) - hidden till the rewind
	stepFor(st, 3.5, 4)
	if st.phase ~= "hold" then
		problem("WIPE 94: ...the empty plain (" .. tostring(st.phase) .. ")")
	end
	local back = Instance.new("Part")
	back.Name = "Restored85"
	back.Anchored = true
	back.Size = Vector3.new(12, 10, 12)
	back.LocalTransparencyModifier = 0
	back.CFrame = r.CFrame.new(origin + Vector3.new(-60, street - origin.Y + 15, 0))
	back.Parent = block
	signalOf(map, "DescendantAdded"):Fire(back)
	task.wait()
	if back.LocalTransparencyModifier < 1 then
		problem("WIPE 94: a part the server rebuilds during the hold stays hidden till the rewind")
	end
	-- the rewind, and the end
	stepFor(st, (st.holdEnd or 11) + 0.02, 2)
	if st.phase ~= "rewind" then
		problem("WIPE 94: ...the rewind (" .. tostring(st.phase) .. ")")
	end
	stepFor(st, (st.rewindEnd or 16) + 0.5, 3)
	if not st.finished then
		WS.finish(st)
		problem("WIPE 94: ...and it's over")
	end
	if back.LocalTransparencyModifier ~= 0 or not back.CanCollide then
		problem("WIPE 94: ...and comes back with the city")
	end
	-- streamed back in after it's over: as it was, not invisible for good
	parts[2].Parent = block
	parts[5].Parent = block
	local wrong = {}
	for i, p in parts do
		if p.LocalTransparencyModifier ~= 0 or not p.CanCollide or not p.CanQuery then
			table.insert(wrong, i .. ":" .. p.LocalTransparencyModifier)
		end
	end
	if #wrong > 0 then
		problem("WIPE 94: every floor's back as it was - streamed out meanwhile or not (wrong: " .. table.concat(wrong, ", ") .. ")")
	end
	if not lamp.Enabled then
		problem("WIPE 94: ...its light on again")
	end
	if next(WS.held) ~= nil then
		local n = 0
		for _ in WS.held do
			n += 1
		end
		problem("WIPE 94: nothing's still held hidden (" .. n .. ")")
	end
	block:Destroy()
end)
if not ok85 then
	problem("round 94 tests errored: " .. tostring(err85))
end
end


print("== round 95: POSSESS A PLAYER (the dev's keys; their screen) and RANKED DUELS (the app; the duel on screen)")
do
local ok95, err95 = pcall(function()
	local PS = VFX.DevFly and VFX.DevFly.PS
	if not PS then
		problem("POSSESS 95: the client's possess code (VFX.DevFly.PS)")
		return
	end
	local hud95 = playerGui:FindFirstChild("QuirkHUD")
	r.implementMethod("Players", "GetPlayerByUserId", function(self, id)
		for _, p in self:GetChildren() do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end)
	local function firedSince(n, pred)
		local out = {}
		for i = n + 1, #fired do
			if pred(fired[i]) then
				table.insert(out, fired[i])
			end
		end
		return out
	end
	local function isAct(e, act)
		return e[1] == "UseAbility" and e[2] == Config.PARKOUR_INDEX and e[3] == "PossessAct" and type(e[4]) == "table" and e[4].Act == act
	end

	-- another player, as Bakugo
	local other = Instance.new("Player")
	other.Name = "Bravo95"
	other.UserId = 95002
	other.DisplayName = "Bravo95"
	other.Parent = Players
	local oChar, oHum, oRoot = makeR15("Bravo95", Vector3.new(30, 3, 0))
	oHum.MaxHealth = 300
	oHum.Health = 300
	oChar.Parent = workspace
	other.Character = oChar
	other:SetAttribute("Quirk", "Explosion")
	localPlayer:SetAttribute("DevFlyer", true)

	-- THE DEV'S SIDE: players are bodies
	local found = false
	for _, m in PS.candidates() do
		found = found or m == oChar
	end
	if not found or PS.kindOf(oChar) ~= "Player" then
		problem("POSSESS 95: another player's body is one he can take (" .. tostring(found) .. ", " .. tostring(PS.kindOf(oChar)) .. ")")
	end
	for _, m in PS.candidates() do
		if m == myChar then
			problem("POSSESS 95: ...never his own")
		end
	end
	-- their keys: a dummy's three, then their hero's five
	local moves = PS.playerMoves(oChar)
	local a1 = Config.GetAbility("Explosion", 1)
	local heroMoves = 0
	for _, m in moves do
		if m.Act == "Move" then
			heroMoves += 1
		end
	end
	if #moves ~= 3 + heroMoves or heroMoves < 4 or moves[1].Act ~= "M1" or moves[4].Slot ~= "Ability1" or moves[4].Name ~= string.upper(a1.Name) then
		problem("POSSESS 95: a player's keys are M1 / F / Q and their own moves (" .. #moves .. ": " .. tostring(moves[4] and moves[4].Name) .. ")")
	end
	for _, m in moves do
		if m.Slot == "Ult" then
			problem("POSSESS 95: ...never their ult")
		end
	end
	-- in it (the server's word, as PS.sync would bind it)
	oChar:SetAttribute("PossessedBy", localPlayer.UserId)
	PS.bind(oChar, "BRAVO95")
	if PS.state ~= "On" or PS.kind ~= "Player" or PS.body ~= oChar then
		problem("POSSESS 95: in a player's body (" .. tostring(PS.state) .. ", " .. tostring(PS.kind) .. ")")
	end
	task.wait(1.1) -- (the wisp's flight)
	-- the dock: their eight keys
	local dockF = hud95 and hud95:FindFirstChild("PossessMoves", true)
	local shown, names = 0, {}
	for _, box in dockF and dockF:GetChildren() or {} do
		if box:IsA("Frame") and box.Visible then
			shown += 1
			local nm = box:FindFirstChild("MoveName")
			names[box.LayoutOrder] = nm and nm.Text
		end
	end
	if shown ~= #moves or names[4] ~= string.upper(a1.Name) then
		problem("POSSESS 95: the dock shows their " .. #moves .. " keys (" .. shown .. ", 4th " .. tostring(names[4]) .. ")")
	end
	-- 1: their AP Shot, asked for as theirs
	local n0 = #fired
	PS.slot("Ability1", true)
	PS.slot("Ability1", false)
	local sent = firedSince(n0, function(e)
		return isAct(e, "Move")
	end)
	if #sent ~= 1 or sent[1][4].Slot ~= "Ability1" or typeof(sent[1][4].Aim) ~= "Vector3" then
		problem("POSSESS 95: 1 asks the server for their move 1 (" .. #sent .. ")")
	end
	-- (on its cooldown: the body's PossessCd_Ability1)
	oChar:SetAttribute("PossessCd_Ability1", workspace:GetServerTimeNow() + 5)
	PS.actAt = 0
	n0 = #fired
	PS.slot("Ability1", true)
	if #firedSince(n0, function(e)
		return isAct(e, "Move")
	end) ~= 0 then
		problem("POSSESS 95: ...not while it's cooling down")
	end
	-- the ult key: nothing
	n0 = #fired
	PS.slot("Ult", true)
	if #firedSince(n0, function(e)
		return e[1] == "UseAbility"
	end) ~= 0 then
		problem("POSSESS 95: the ult key does nothing in a player's body")
	end
	-- M1: the heroes' chain (a dummy's)
	PS.m1Next = 0
	n0 = #fired
	PS.slot("M1", true)
	PS.slot("M1", false)
	if #firedSince(n0, function(e)
		return isAct(e, "M1")
	end) ~= 1 then
		problem("POSSESS 95: M1 in a player's body is a dummy's chain")
	end
	-- their pace (their hero's walk, run with sprint)
	PS.drive(1 / 60)
	local base = oChar:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	if math.abs(oHum.WalkSpeed - base) > 0.01 then
		problem("POSSESS 95: they walk at their own pace (" .. tostring(oHum.WalkSpeed) .. " vs " .. tostring(base) .. ")")
	end
	PS.exit("Server")
	oChar:SetAttribute("PossessedBy", nil)
	oChar:SetAttribute("PossessCd_Ability1", nil)
	if PS.state ~= "Off" then
		problem("POSSESS 95: ...and out")
	end

	-- THEIR SIDE: this screen's body taken
	setAttr(localPlayer, "PossessedBy", other.UserId)
	setAttr(myChar, "Possessed", true)
	task.wait(0.1)
	local banner = hud95 and hud95:FindFirstChild("PossessedBanner")
	if not (banner and banner.Visible and banner:FindFirstChild("Dev") and banner.Dev.Text == "BRAVO95") then
		problem("POSSESS 95: their screen: CONTROLLED BY BRAVO95 (" .. tostring(banner and banner.Visible) .. ")")
	end
	if not actions.QuirkPossessedSink then
		problem("POSSESS 95: ...the game's keys sunk")
	end
	n0 = #fired
	if actions.QuirkPunch then
		actions.QuirkPunch(nil, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
		task.wait()
		actions.QuirkPunch(nil, Enum.UserInputState.End, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
	end
	if #firedSince(n0, function(e)
		return e[1] == "UseAbility" and e[2] == 0
	end) ~= 0 then
		problem("POSSESS 95: ...their own M1 does nothing")
	end
	setAttr(myChar, "Possessed", nil)
	setAttr(localPlayer, "PossessedBy", nil)
	task.wait(0.1)
	if banner and banner.Visible then
		problem("POSSESS 95: ...the banner goes when he leaves")
	end
	if PS.taken ~= nil or PS.takenReset then
		problem("POSSESS 95: ...their keys and reset button theirs again")
	end
	other.Parent = nil
	oChar.Parent = nil
	localPlayer:SetAttribute("DevFlyer", nil)

	-- RANKED: the phone's app
	HUD.ToggleRanked(true)
	local panel95 = hud95 and hud95:FindFirstChild("RankedDuels")
	if not (panel95 and panel95.Visible) then
		problem("RANKED 95: the RANKED app opens")
	end
	local qb = panel95 and panel95:FindFirstChild("Queue")
	if not (qb and qb.Text == "FIND A MATCH") then
		problem("RANKED 95: ...FIND A MATCH (" .. tostring(qb and qb.Text) .. ")")
	end
	n0 = #fired
	if qb then
		signalOf(qb, "Activated"):Fire()
	end
	if #firedSince(n0, function(e)
		return e[1] == "UseAbility" and e[2] == Config.PARKOUR_INDEX and e[3] == "RankedJoin"
	end) ~= 1 then
		problem("RANKED 95: ...which asks the server to queue")
	end
	setAttr(localPlayer, "RankedQueued", workspace:GetServerTimeNow() - 12)
	task.wait(0.4)
	if not (qb and string.find(qb.Text, "SEARCHING... 0:1", 1, true)) then
		problem("RANKED 95: ...SEARCHING, how long (" .. tostring(qb and qb.Text) .. ")")
	end
	n0 = #fired
	if qb then
		signalOf(qb, "Activated"):Fire()
	end
	if #firedSince(n0, function(e)
		return e[3] == "RankedLeave"
	end) ~= 1 then
		problem("RANKED 95: ...again to stop")
	end
	setAttr(localPlayer, "RankedQueued", nil)
	setAttr(localPlayer, "RankedRating", 1112)
	setAttr(localPlayer, "RankedPlayed", 13)
	task.wait(0.05)
	local tierL = panel95 and panel95:FindFirstChild("You") and panel95.You:FindFirstChild("Tier")
	if not (tierL and tierL.Text == "PRO HERO") then
		problem("RANKED 95: your tier on the card (" .. tostring(tierL and tierL.Text) .. ")")
	end
	HUD.SetRankedBoard({ { UserId = 7, Name = "Top", Rating = 1720 }, { UserId = localPlayer.UserId, Name = "Tester", Rating = 1112 } }, localPlayer.UserId)
	local row1 = panel95 and panel95:FindFirstChild("Row1")
	local tierText
	for _, c in row1 and row1:GetChildren() or {} do
		if c:IsA("TextLabel") and c.Text == "SYMBOL OF PEACE" then
			tierText = c.Text
		end
	end
	if not tierText then
		problem("RANKED 95: the top 10, with their tiers")
	end
	HUD.ToggleRanked(false)

	-- THE DUEL ON SCREEN
	local PV = remotes:FindFirstChild("PlayVFX")
	PV.OnClientEvent:Fire("RankedFound", nil, {
		You = { Name = "Tester", UserId = localPlayer.UserId, Rating = 1112, Tier = "PRO HERO", Hero = "EXPLOSION" },
		Opp = { Name = "Bravo", UserId = 2, Rating = 983, Tier = "SIDEKICK", Hero = "EXPLOSION" },
	})
	task.wait(0.05)
	local sb = hud95 and hud95:FindFirstChild("RankedScore")
	if not (sb and sb.Visible and sb:FindFirstChild("ThemName") and sb.ThemName.Text == "BRAVO") then
		problem("RANKED 95: the scoreboard: you and them")
	end
	local card = hud95 and hud95:FindFirstChild("RankedCard")
	if not (card and card.Visible and card.Title.Text == "VS") then
		problem("RANKED 95: the VS card")
	end
	PV.OnClientEvent:Fire("RankedRound", nil, { Round = 1, Me = 0, Them = 0, Countdown = 0.6 })
	task.wait(0.05)
	local call = hud95 and hud95:FindFirstChild("RankedCall")
	if not (call and call.Visible and call.Big.Text == "ROUND 1") then
		problem("RANKED 95: ROUND 1 (" .. tostring(call and call.Big.Text) .. ")")
	end
	setAttr(myChar, "RankedHold", true)
	n0 = #fired
	if actions.QuirkPunch then
		actions.QuirkPunch(nil, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
		task.wait()
		actions.QuirkPunch(nil, Enum.UserInputState.End, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
	end
	if #firedSince(n0, function(e)
		return e[1] == "UseAbility" and e[2] == 0
	end) ~= 0 then
		problem("RANKED 95: held on the marks: no M1")
	end
	setAttr(myChar, "RankedHold", nil)
	-- (and without it, the same press does go: the check above means something)
	task.wait(1)
	n0 = #fired
	if actions.QuirkPunch then
		actions.QuirkPunch(nil, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
		task.wait()
		actions.QuirkPunch(nil, Enum.UserInputState.End, { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1 })
	end
	if #firedSince(n0, function(e)
		return e[1] == "UseAbility" and e[2] == 0
	end) == 0 then
		problem("RANKED 95: (control) an M1 off the marks does go")
	end
	PV.OnClientEvent:Fire("RankedFight", nil, { Round = 1, Me = 0, Them = 0, Ends = workspace:GetServerTimeNow() + 90 })
	task.wait(0.05)
	if not (call.Big.Text == "FIGHT!") then
		problem("RANKED 95: FIGHT!")
	end
	PV.OnClientEvent:Fire("RankedRoundEnd", nil, { Round = 1, Me = 1, Them = 0, How = "RING OUT", Winner = "Tester", WinnerId = localPlayer.UserId })
	task.wait(0.05)
	if not (call.Big.Text == "RING OUT!" and string.find(sb.Score.Text, ">1<", 1, true)) then
		problem("RANKED 95: RING OUT!, 1-0 (" .. tostring(call.Big.Text) .. ", " .. tostring(sb.Score.Text) .. ")")
	end
	PV.OnClientEvent:Fire("RankedResult", nil, { Result = "Win", How = "KO", Delta = 12, Rating = 1124, Tier = "PRO HERO", Me = 2, Them = 0, Opp = "Bravo" })
	task.wait(0.05)
	if not (card.Visible and card.Title.Text == "VICTORY" and string.find(card.Line2.Text, "+12", 1, true)) then
		problem("RANKED 95: the result: VICTORY, +12 (" .. tostring(card.Title.Text) .. ", " .. tostring(card.Line2.Text) .. ")")
	end
	-- everyone else's line
	PV.OnClientEvent:Fire("RankedOver", nil, { Winner = "Alpha", Loser = "Bravo", Score = "2-1", A = "Alpha", B = "Bravo" })
end)
if not ok95 then
	problem("round 95 tests errored: " .. tostring(err95))
end
end


print("== round 96: DISMANTLE (U arms it; a drag draws the cut; letting go sends it; the effects)")
do
local ok96, err96 = pcall(function()
	local DM = VFX.DevFly and VFX.DevFly.DM
	if not DM then
		problem("DISMANTLE 96: the client's Dismantle code (VFX.DevFly.DM)")
		return
	end
	local uis = game:GetService("UserInputService")
	local function key(k)
		signalOf(uis, "InputBegan"):Fire({ KeyCode = k, UserInputType = Enum.UserInputType.Keyboard }, false)
		task.wait()
	end
	local function mouse(began, at)
		mouseAt62 = at
		local input = { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(at.X, at.Y, 0) }
		if began then
			signalOf(uis, "InputBegan"):Fire(input, false)
		else
			signalOf(uis, "InputEnded"):Fire(input, false)
		end
		task.wait()
	end
	local function sentSince(n, kind)
		local out = {}
		for i = n + 1, #fired do
			local e = fired[i]
			if e[1] == "UseAbility" and (kind == nil or e[3] == kind) then
				table.insert(out, e)
			end
		end
		return out
	end
	local DC = Config.Dismantle
	if VFX.DevFly.PS and VFX.DevFly.PS.body ~= nil then
		problem("DISMANTLE 96: (setup) still in a body from the possess tests")
	end

	-- not one of the dev flight's people: U does nothing
	setAttr(localPlayer, "DevFlyer", nil)
	key(DC.Key)
	if DM.armed then
		problem("DISMANTLE 96: only the dev flight's people can arm it")
	end
	-- one of them: U arms it
	setAttr(localPlayer, "DevFlyer", true)
	key(DC.Key)
	local gui = playerGui:FindFirstChild("DismantleGui")
	local chip = gui and gui:FindFirstChild("Chip")
	if not DM.armed or not gui or not gui.Enabled or not chip or not string.find(chip.Text, "DISMANTLE") then
		problem("DISMANTLE 96: U arms it - the chip up top says so (" .. tostring(DM.armed) .. ")")
	end
	if gui and not gui.IgnoreGuiInset then
		problem("DISMANTLE 96: ...its screen in the mouse's own coordinates (IgnoreGuiInset)")
	end

	-- THE DRAG: a line from the press to the mouse
	local n0 = #fired
	DM.sentAt = -1e9
	mouse(true, Vector2.new(100, 200))
	if not DM.drawing then
		problem("DISMANTLE 96: pressing the left button starts the line")
	end
	if #sentSince(n0) > 0 then
		problem("DISMANTLE 96: ...and doesn't punch (no M1 while it's armed)")
	end
	mouseAt62 = Vector2.new(400, 260)
	DM.step()
	local line = gui and gui:FindFirstChild("Line")
	local want = math.sqrt(300 * 300 + 60 * 60)
	if not line or not line.Visible or math.abs(line.Size.X.Offset - want) > 1 -- (whole pixels)
		 or math.abs(line.Rotation - math.deg(math.atan2(60, 300))) > 0.1
		or math.abs(line.Position.X.Offset - 250) > 0.5 or math.abs(line.Position.Y.Offset - 230) > 0.5 then
		problem("DISMANTLE 96: ...a line from where he pressed to the mouse (" .. tostring(line and line.Size.X.Offset) .. ")")
	end
	-- let go: sent, the line flashes
	mouse(false, Vector2.new(400, 260))
	local sent = sentSince(n0, "Dismantle")
	local d = sent[1] and sent[1][4]
	if #sent ~= 1 or sent[1][2] ~= Config.PARKOUR_INDEX or type(d) ~= "table" or typeof(d.O) ~= "Vector3" or typeof(d.A) ~= "Vector3" or typeof(d.B) ~= "Vector3" then
		problem("DISMANTLE 96: letting go sends the cut (UseAbility, PARKOUR_INDEX, Dismantle: O, A, B) (" .. #sent .. ")")
	end
	if DM.drawing or (line and line.Visible) then
		problem("DISMANTLE 96: ...the line put away")
	end
	if not (gui and gui:FindFirstChild("Slash")) then
		problem("DISMANTLE 96: ...and it flashes as a slash")
	end
	-- a click (or a short drag) isn't a cut
	n0 = #fired
	DM.sentAt = -1e9
	mouse(true, Vector2.new(100, 100))
	mouse(false, Vector2.new(110, 105))
	if #sentSince(n0, "Dismantle") ~= 0 then
		problem("DISMANTLE 96: a drag under MinStroke (" .. DC.MinStroke .. " px) isn't sent")
	end
	-- once each Cooldown
	DM.sentAt = os.clock()
	mouse(true, Vector2.new(100, 100))
	mouse(false, Vector2.new(500, 100))
	if #sentSince(n0, "Dismantle") ~= 0 then
		problem("DISMANTLE 96: ...nor one inside the Cooldown")
	end
	-- U again: put away
	key(DC.Key)
	if DM.armed or (gui and gui.Enabled) then
		problem("DISMANTLE 96: U again puts it away")
	end
	-- losing DevFlyer puts it away
	DM.set(true)
	setAttr(localPlayer, "DevFlyer", nil)
	task.wait()
	if DM.armed then
		problem("DISMANTLE 96: no longer one of the dev flight's people: put away")
	end
	setAttr(localPlayer, "DevFlyer", true)
	local okMenu = pcall(DM.menu)
	if not okMenu then
		problem("DISMANTLE 96: the test menu's DISMANTLE row (DM.menu)")
	end

	-- THE EFFECTS
	for _, cue in { "DismantleArm", "DismantleCut", "DismantleSlide", "DismantleImpact", "DismantleHit" } do
		local c = Config.Sounds[cue]
		if type(c) ~= "table" or #c == 0 then
			problem("DISMANTLE 96: the sound cue " .. cue)
		end
	end
	local K = VFX.DismantleKit
	local ring = K and K.ring(Vector3.new(0, 30, -100), Vector3.new(40, 60, 40), Vector3.new(0, 30, 0), Vector3.new(0, 1, 0))
	if not ring or #ring ~= 4 then
		problem("DISMANTLE 96: a flat cut goes round a box's four sides (" .. tostring(ring and #ring) .. ")")
	end
	local function lines()
		local n = 0
		for _, p in VFX.Folder:GetDescendants() do
			if p.Name == "DismantleLine" then
				n += 1
			end
		end
		return n
	end
	local before = lines()
	local pts = {}
	for i = 0, 9 do
		table.insert(pts, Vector3.new(-20 + i * 4, 30, -80))
	end
	VFX.Play("Dismantle", nil, { O = Vector3.new(0, 30, 0), N = Vector3.new(0, 1, 0), A = Vector3.new(-0.2, 0, -1).Unit, B = Vector3.new(0.2, 0, -1).Unit,
		Points = pts, Units = { { C = Vector3.new(0, 30, -100), S = Vector3.new(40, 60, 40) } } }, false)
	task.wait(0.05)
	local cut = K and K.lastCut
	if not cut or cut.Lines ~= 9 or cut.Units ~= 1 or lines() - before ~= 9 + 4 then
		problem("DISMANTLE 96: Dismantle draws the line where it shows (9) and round the building it went through (4) (" .. tostring(lines() - before) .. ")")
	end
	VFX.Play("DismantleSlide", nil, { P = Vector3.new(0, 40, -100), S = Vector3.new(40, 20, 40) }, false)
	VFX.Play("DismantleImpact", nil, { P = Vector3.new(30, 0, -100), S = Vector3.new(40, 20, 40), N = 200 }, false)
	task.wait(0.05)
	if not (K.lastSlide and K.lastImpact and K.lastImpact.Big >= 0.8) then
		problem("DISMANTLE 96: the slide and the crash play")
	end
end)
if not ok96 then
	problem("DISMANTLE 96: errored: " .. tostring(err96))
end
end

print("== round 97: ANTI-EXPLOIT (a farmed KO: still a K.O., marked no reward)")
do
local ok97, err97 = pcall(function()
	local hud97 = playerGui:FindFirstChild("QuirkHUD")
	-- the popup the next call makes (the ones already up are left to fade)
	function newPopupTexts97(fn) -- (a global: the suite is at its local limit)
		local before = {}
		for _, d in hud97 and hud97:GetDescendants() or {} do
			if d.Name == "KOPopup" then
				before[d] = true
			end
		end
		fn()
		local out = {}
		for _, d in hud97 and hud97:GetDescendants() or {} do
			if d.Name == "KOPopup" and not before[d] then
				for _, l in d:GetDescendants() do
					if l:IsA("TextLabel") then
						table.insert(out, l.Text)
					end
				end
			end
		end
		return table.concat(out, " | ")
	end
	local texts = newPopupTexts97(function()
		HUD.KOPopup({ Victim = "Bravo97", Counted = false, Farmed = true })
	end)
	if not string.find(texts, "K.O.!", 1, true) or string.find(texts, "DUMMY DOWN", 1, true) or not string.find(texts, "NO REWARD", 1, true) then
		problem("ANTI-EXPLOIT 97: a farmed KO's popup says K.O.! and NO REWARD (" .. texts .. ")")
	end
	texts = newPopupTexts97(function()
		HUD.KOPopup({ Victim = "Dummy", Counted = false })
	end)
	if not string.find(texts, "DUMMY DOWN", 1, true) or string.find(texts, "NO REWARD", 1, true) then
		problem("ANTI-EXPLOIT 97: ...a dummy's is as it was (" .. texts .. ")")
	end
	task.wait(2.6) -- (both gone before the next section)
end)
if not ok97 then
	problem("ANTI-EXPLOIT 97: errored: " .. tostring(err97))
end
end

print("== round 98: NAME TAGS, GAME PASSES (shop, emote ring, outfits), A MODERATOR'S WARNING, THE CONSOLE FOR STAFF")
do
local ok98, err98 = pcall(function()
	local hud98 = playerGui:FindFirstChild("QuirkHUD")
	-- (what this section changes on you, put back at the end: the later
	-- sections play emotes and use the console)
	local keep98 = {}
	for _, k in { "EmotesOwned", "EmoteWheel", "EmoteWheel2", "Pass_EmoteSlots", "Pass_VIP", "PassGiven_VIP", "Pass_AwakeningOutfits", "Tag", "ConsoleOwner", "ConsoleRole" } do
		keep98[k] = { localPlayer:GetAttribute(k) }
	end
	function restore98() -- (a global: the suite is at its local limit)
		for k, v in keep98 do
			if localPlayer:GetAttribute(k) ~= v[1] then
				setAttr(localPlayer, k, v[1])
			end
		end
	end
	local function textOnScreen(needle)
		for _, d in hud98 and hud98:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and string.find(d.Text, needle, 1, true) then
				return true
			end
		end
		return false
	end

	-- (the harness: a part's LocalTransparencyModifier - the engine's, not saved
	-- in a place, so Lune has no default for it)
	local ltm98 = setmetatable({}, { __mode = "k" })
	for _, cls in { "Part", "MeshPart" } do
		r.implementProperty(cls, "LocalTransparencyModifier", function(self)
			return ltm98[self] or 0
		end, function(self, v)
			ltm98[self] = v
		end)
	end
	-- NAME TAGS: over the head (the harness keeps only your own body, so it's
	-- yours - with ShowOwn on - that wears one here)
	local NT = HUD.NameTags
	if not NT then
		problem("TAGS 98: the name tags are there (HUD.NameTags)")
		return
	end
	local TGC = Config.Tags
	local head = myChar:FindFirstChild("Head")
	local shownWas = myHum.DisplayDistanceType
	TGC.ShowOwn = true
	setAttr(localPlayer, "Tag", "Mod")
	NT.tick()
	local board = playerGui:FindFirstChild("NameTag_" .. localPlayer.Name)
	local label = board and board:FindFirstChild("Tag")
	if not (board and board.Enabled and label and string.find(label.Text, "MOD", 1, true) and board.Adornee == head) then
		problem("TAGS 98: someone with the MOD tag has it over their head (" .. tostring(label and label.Text) .. ")")
	end
	if label and label.TextColor3 ~= Config.TagSpec("Mod").Color then
		problem("TAGS 98: ...in the tag's colour")
	end
	if board and (board.MaxDistance ~= TGC.Distance or not board.AlwaysOnTop) then
		problem("TAGS 98: ...out to Distance studs, like a name")
	end
	myHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	NT.tick()
	if board and board.Enabled then
		problem("TAGS 98: ...hidden while their name is (an invisible body)")
	end
	myHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	NT.tick()
	if board and not board.Enabled then
		problem("TAGS 98: ...and back with it")
	end
	head.LocalTransparencyModifier = 1
	NT.tick()
	if board and board.Enabled then
		problem("TAGS 98: ...hidden with a see-through head (first person)")
	end
	head.LocalTransparencyModifier = 0
	setAttr(localPlayer, "Tag", "Tester")
	NT.tick()
	if not (label and string.find(label.Text, "TESTER", 1, true) and board.Enabled) then
		problem("TAGS 98: a different tag: the new one shows (" .. tostring(label and label.Text) .. ")")
	end
	-- in chat
	local props = NT.onChat({ TextSource = { UserId = localPlayer.UserId }, PrefixText = "Tester:" })
	if not (props and string.find(props.PrefixText, "[TESTER]", 1, true) and string.find(props.PrefixText, "Tester:", 1, true)) then
		problem("TAGS 98: in chat, [TESTER] before the name (" .. tostring(props and props.PrefixText) .. ")")
	end
	if NT.onChat({ TextSource = { UserId = 424242 }, PrefixText = "x:" }) ~= nil then
		problem("TAGS 98: ...no tag: chat as it was")
	end
	-- your own: not over your own head unless ShowOwn (Roblox doesn't show you your name)
	TGC.ShowOwn = false
	NT.tick()
	if board and board.Enabled then
		problem("TAGS 98: your own isn't over your own head (ShowOwn off, as shipped)")
	end
	TGC.ShowOwn = true
	setAttr(localPlayer, "Tag", nil)
	NT.tick()
	if board and board.Enabled then
		problem("TAGS 98: tag taken back: gone")
	end
	TGC.ShowOwn = false
	myHum.DisplayDistanceType = shownWas

	-- GAME PASSES in the shop
	local banners = hud98 and hud98:FindFirstChild("Banners", true)
	local vip = banners and banners:FindFirstChild("Pass_VIP")
	local slots = banners and banners:FindFirstChild("Pass_EmoteSlots")
	local db = banners and banners:FindFirstChild("Pass_DoubleBucks")
	if not (vip and slots and db) then
		problem("PASSES 98: the shop has a banner for each game pass")
	else
		local function price(b)
			local p = b:FindFirstChild("Price")
			return p and p.Text or ""
		end
		if not (slots.Visible and string.find(price(slots), "NO ID", 1, true)) then
			problem("PASSES 98: (Studio) one with no pass Id yet shows, marked (" .. price(slots) .. ")")
		end
		setAttr(localPlayer, "Pass_VIP", true)
		task.wait()
		if not string.find(price(vip), "OWNED", 1, true) then
			problem("PASSES 98: one that's yours says OWNED (" .. price(vip) .. ")")
		end
		setAttr(localPlayer, "PassGiven_VIP", true)
		task.wait()
		if not string.find(price(vip), "GIFTED", 1, true) then
			problem("PASSES 98: ...given by the owner: GIFTED (" .. price(vip) .. ")")
		end
		setAttr(localPlayer, "Pass_VIP", nil)
		setAttr(localPlayer, "PassGiven_VIP", nil)
		Config.GamePasses.DoubleBucks.Id = 4243
		HUD.RefreshPasses()
		if not string.find(price(db), "R$ 249", 1, true) then
			problem("PASSES 98: set up: its price in Robux (" .. price(db) .. ")")
		end
		Config.GamePasses.DoubleBucks.Id = 0
		HUD.RefreshPasses()
		signalOf(slots, "MouseButton1Click"):Fire()
		task.wait()
		if not textOnScreen("isn't on sale yet") then
			problem("PASSES 98: buying one that isn't set up: said so")
		end
	end

	-- THE EMOTE WHEEL'S SECOND RING
	local ids = {}
	for _, e in Config.Emotes do
		if not e.Exclusive and #ids < 10 then
			table.insert(ids, e.Id)
		end
	end
	setAttr(localPlayer, "EmotesOwned", table.concat(ids, ","))
	setAttr(localPlayer, "EmoteWheel", table.concat(ids, ",", 1, 8))
	setAttr(localPlayer, "EmoteWheel2", ids[9] .. ",,,,,,,")
	task.wait()
	local function wheelCount()
		local wheel = hud98:FindFirstChild("EmoteWheel", true)
		local n = 0
		for _, d in wheel and wheel:GetDescendants() or {} do
			if d:IsA("TextButton") and string.sub(d.Name, 1, 6) == "Emote_" then
				n += 1
			end
		end
		return n, wheel
	end
	local n8 = wheelCount()
	if n8 ~= 8 then
		problem("RING 98: without the pass the wheel has its 8 (" .. n8 .. ")")
	end
	local ringBtn = hud98:FindFirstChild("RingButton", true)
	if not (ringBtn and string.find(ringBtn.Text, "SLOTS", 1, true)) then
		problem("RING 98: ...and the end of the shop's emote row offers +8 SLOTS (" .. tostring(ringBtn and ringBtn.Text) .. ")")
	end
	setAttr(localPlayer, "Pass_EmoteSlots", true)
	task.wait()
	local n16, wheel = wheelCount()
	if n16 ~= 16 or not (wheel and wheel:FindFirstChild("Emote_" .. ids[9], true)) then
		problem("RING 98: with the EMOTE SLOTS pass, 16 round the wheel - the second ring's on it (" .. n16 .. ")")
	end
	if not (ringBtn and string.find(ringBtn.Text, "RING", 1, true)) then
		problem("RING 98: ...the row's button switches rings (" .. tostring(ringBtn and ringBtn.Text) .. ")")
	end
	if ringBtn then
		signalOf(ringBtn, "MouseButton1Click"):Fire()
		task.wait()
	end
	local shopPage = hud98:FindFirstChild("EmoteShop", true)
	local row = shopPage and shopPage:FindFirstChild("Wheel")
	local slot1 = row and row:FindFirstChild("Slot1")
	local num = slot1 and slot1:FindFirstChild("Num")
	if not (num and num.Text == "9") then
		problem("RING 98: RING 2: the tiles are slots 9 to 16 (" .. tostring(num and num.Text) .. ")")
	end
	table.clear(fired)
	HUD.EmoteSlotClicked(2)
	HUD.EmoteCardClicked(ids[1])
	local sent = false
	for _, f in fired do
		if f[1] == "Shop" and f[2] == "EquipEmote" and f[3] == 10 and f[4] == ids[1] then
			sent = true
		end
	end
	if not sent then
		problem("RING 98: ...a tile there puts an emote in its slot (10)")
	end
	if ringBtn then
		signalOf(ringBtn, "MouseButton1Click"):Fire()
	end
	setAttr(localPlayer, "Pass_EmoteSlots", nil)
	setAttr(localPlayer, "EmoteWheel2", nil)
	task.wait()

	-- THE OUTFIT APP: the AWAKENING OUTFITS pass
	HUD.OpenOutfits()
	task.wait()
	if HUD.OutfitLocked() then
		problem("OUTFITS 98: no pass Id yet: free, as before")
	end
	HUD.ToggleOutfits(false)
	Config.GamePasses.AwakeningOutfits.Id = 4241
	HUD.OpenOutfits()
	task.wait()
	if not HUD.OutfitLocked() then
		problem("OUTFITS 98: set up, without the pass: the app shows the pass")
	end
	setAttr(localPlayer, "Pass_AwakeningOutfits", true)
	task.wait()
	if HUD.OutfitLocked() then
		problem("OUTFITS 98: ...with it, the outfits")
	end
	HUD.ToggleOutfits(false)
	Config.GamePasses.AwakeningOutfits.Id = 0
	setAttr(localPlayer, "Pass_AwakeningOutfits", nil)

	-- A MODERATOR'S WARNING; A PASS GIVEN
	PlayVFX.OnClientEvent:Fire("ModWarn", nil, { Text = "stop spamming the chat", By = "Bravo" })
	task.wait()
	local card = hud98:FindFirstChild("ModWarning")
	local txt = card and card:FindFirstChild("Text")
	local from = card and card:FindFirstChild("From")
	if not (txt and txt.Text == "stop spamming the chat" and from and string.find(from.Text, "Bravo", 1, true)) then
		problem("WARN 98: a moderator's warning, in the middle of the screen")
	end
	local okb = card and card:FindFirstChild("Ok")
	if okb then
		signalOf(okb, "MouseButton1Click"):Fire()
		task.wait()
	end
	if hud98:FindFirstChild("ModWarning") then
		problem("WARN 98: ...I UNDERSTAND puts it away")
	end
	PlayVFX.OnClientEvent:Fire("PassBought", nil, { Key = "VIP", Gift = "Alpha" })
	task.wait()
	if not textOnScreen("gift from Alpha") then
		problem("PASSES 98: a pass given: who it's from")
	end

	-- THE CONSOLE: staff type commands too
	local cg = playerGui:FindFirstChild("QuirkConsole")
	local croot = cg and cg:FindFirstChild("Console")
	local box = croot and croot:FindFirstChild("Input") and croot.Input:FindFirstChildOfClass("TextBox")
	local CR = remotes:FindFirstChild("Console")
	if not (croot and box and CR) then
		problem("CONSOLE 98: the console's there")
	else
		setAttr(localPlayer, "ConsoleOwner", nil) -- (not the owner here: an owner's badge says OWNER)
		local function badge(word)
			for _, d in croot:GetDescendants() do
				if d:IsA("TextLabel") and d.Text == word then
					return true
				end
			end
			return false
		end
		signalOf(CR, "OnClientEvent"):Fire("Sync", { Log = {}, Commands = { { Name = "ban", Usage = "ban <who>", Help = "Ban" } }, Owner = true, Role = "MOD" })
		task.wait()
		if not (box.TextEditable == true and badge("MOD")) then
			problem("CONSOLE 98: a mod can type, and the console says MOD")
		end
		setAttr(localPlayer, "ConsoleRole", "Admin")
		task.wait()
		if not (box.TextEditable == true and badge("ADMIN")) then
			problem("CONSOLE 98: ...an admin (ConsoleRole): ADMIN")
		end
		setAttr(localPlayer, "ConsoleRole", nil)
		task.wait()
		if box.TextEditable ~= false then
			problem("CONSOLE 98: ...not staff any more: read-only again")
		end
		signalOf(CR, "OnClientEvent"):Fire("Sync", { Log = {}, Commands = {}, Owner = false })
		task.wait()
	end
end)
if not ok98 then
	problem("ROUND 98: errored: " .. tostring(err98))
end
if restore98 then
	restore98()
	task.wait()
end
end

print("== round 102: FINAL FORM - Broly's Legendary Super Saiyan: the whole song, the giant (bulked) double, his camera on it")
-- (in a function of its own: the main chunk is at its 200-register limit here)
;(function()
	local EM = VFX.EMOTES
	local FF = EM and EM.FF
	local FFC = Config.FinalForm
	local B = 60 / 96
	local function near(a, b, tol)
		return math.abs(a - b) <= (tol or 1e-3)
	end
	if not (FF and FFC and FF.size and FF.bulk and FF.dark) then
		problem("FINAL FORM 102: the FF kit (size, bulk, dark) and Config.FinalForm")
	else
		-- the motion and the props: 46 beats (28.75 s of the song's 30)
		local entry = EM.entry("FinalForm")
		local len = EM.length(entry)
		if not near(len, 46 * B, 0.01) or FFC.Beats ~= 46 then
			problem(string.format("FINAL FORM 102: the motion runs 46 beats, 28.75 s (%.3f s, Beats %s)", len, tostring(FFC.Beats)))
		end
		-- his size: the awakening as before (up to Go), then the surge, the
		-- silent beat, LEGENDARY, the shrink back to exactly 1
		local D = FFC.Double
		if FF.size(0) ~= 1 or not near(FF.size(5.0 + D.GoTime), D.Full, 0.002) then
			problem(string.format("FINAL FORM 102: 1 at the start, Full (%.2f) at Go (%.3f, %.3f)", D.Full, FF.size(0), FF.size(5.0 + D.GoTime)))
		end
		local last = D.Full
		for i, p in D.Surge do
			local now = FF.size(p[1] + D.SurgeTime + 0.01)
			if not (now > last and near(now, p[2], p[2] * 0.015)) then
				problem(string.format("FINAL FORM 102: the surge's hit %d pumps him to %.2f (%.3f)", i, p[2], now))
			end
			last = now
		end
		if not near(FF.size(14.375 + 0.5), D.Squeeze2[2], 0.04) then
			problem(string.format("FINAL FORM 102: squeezed to %.2f on the silent beat (%.3f)", D.Squeeze2[2], FF.size(14.875)))
		end
		local legend, top = FF.size(15.0 + D.LegendTime + 0.01), 0
		for t = 15.0, 26.25, 0.01 do
			top = math.max(top, FF.size(t))
		end
		if not (near(legend, 3.2, 0.06) and top >= 3.2 and top < 3.6) then
			problem(string.format("FINAL FORM 102: LEGENDARY x3.2 on the second drop (%.3f, peak %.3f)", legend, top))
		end
		-- a flex on each hit after it
		local h = 18.75
		if not (FF.size(h + 0.07) > FF.size(h - 0.01) + 0.1) then
			problem(string.format("FINAL FORM 102: a flex on the hits after LEGENDARY (%.3f -> %.3f)", FF.size(h - 0.01), FF.size(h + 0.07)))
		end
		local mid = FF.size(27.2)
		if FF.size(28.125) ~= 1 or FF.size(29) ~= 1 or not (mid > 1.2 and mid < 3) then
			problem(string.format("FINAL FORM 102: shrinks back to exactly 1 by 28.125 s (%.4f, %.4f; at 27.2: %.3f)", FF.size(28.125), FF.size(29), mid))
		end
		if not (FF.bulk(1) == 1 and near(FF.bulk(3.2), 1 + D.Bulk * 2.2, 1e-6)) then
			problem("FINAL FORM 102: his bulk (1 at his size, 1.33 at 3.2)")
		end
		if not (FF.dark(4.8) and not FF.dark(5.1) and FF.dark(14.5) and not FF.dark(15.01) and not FF.dark(10)) then
			problem("FINAL FORM 102: the two silent beats (the hush, the song's silent beat)")
		end
		-- the crown at LEGENDARY: green, wilder
		local shown, _, color, pop, k = FF.crownAt(16.5)
		local CC = FFC.Colors
		if not (shown and near(pop, FFC.Crown.Legend.Grow, 0.01) and k > 1.9 and near(color.G, CC.Legend.G, 0.01) and near(color.R, CC.Legend.R, 0.01)) then
			problem("FINAL FORM 102: the crown at LEGENDARY - green and x" .. FFC.Crown.Legend.Grow)
		end

		-- the whole run on a properly built R6 body (his own: the camera's his)
		local function r6(pos)
			local model = Instance.new("Model")
			model.Name = "Broly"
			local function bp(name, size, cf)
				local p = Instance.new("Part")
				p.Name = name
				p.Size = size
				p.CFrame = cf
				p.Position = cf.Position
				p.AssemblyLinearVelocity = Vector3.zero
				p.Parent = model
				return p
			end
			local at = r.CFrame.new(pos)
			local root = bp("HumanoidRootPart", Vector3.new(2, 2, 1), at)
			root.Transparency = 1
			local torso = bp("Torso", Vector3.new(2, 2, 1), at)
			local head = bp("Head", Vector3.new(2, 1, 1), at * r.CFrame.new(0, 1.5, 0))
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Parent = head
			local function j(name, p0, p1, c0, c1, holder)
				local m = Instance.new("Motor6D")
				m.Name = name
				m.Part0, m.Part1 = p0, p1
				m.C0, m.C1 = c0, c1
				m.Transform = r.CFrame.new()
				m.Parent = holder
				return m
			end
			j("RootJoint", root, torso, r.CFrame.new(), r.CFrame.new(), root)
			j("Neck", torso, head, r.CFrame.new(0, 1, 0), r.CFrame.new(0, -0.5, 0), torso)
			for _, sp in {
				{ "Right Arm", "Right Shoulder", Vector3.new(1.5, 0, 0), Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0) },
				{ "Left Arm", "Left Shoulder", Vector3.new(-1.5, 0, 0), Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0) },
				{ "Right Leg", "Right Hip", Vector3.new(0.5, -2, 0), Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0) },
				{ "Left Leg", "Left Hip", Vector3.new(-0.5, -2, 0), Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0) },
			} do
				local limb = bp(sp[1], Vector3.new(1, 2, 1), at * r.CFrame.new(sp[3]))
				j(sp[2], torso, limb, r.CFrame.new(sp[4]), r.CFrame.new(sp[5]), torso)
			end
			-- a hat on his head (welded: it rides the head, not the bulk)
			local acc = Instance.new("Accessory")
			acc.Name = "Cap"
			local handle = bp("Handle", Vector3.new(1.2, 0.4, 1.2), at * r.CFrame.new(0, 2.2, 0))
			handle.Parent = acc
			local w = Instance.new("Weld")
			w.Name = "AccessoryWeld"
			w.Part0, w.Part1 = handle, head
			w.Parent = handle
			acc.Parent = model
			local hum = InstanceShim.new("Humanoid")
			hum.RigType = Enum.HumanoidRigType.R6
			hum.Parent = model
			Instance.new("Animator").Parent = hum
			model.PrimaryPart = root
			model.Parent = workspace
			return model, hum, root, torso, head
		end
		local body, hum, root, torso, head = r6(Vector3.new(400, 3, 400))
		local wasChar = localPlayer.Character
		localPlayer.Character = body
		local camWas, focusWas = cam.CFrame, cam.Focus
		cam.Focus = r.CFrame.new(head.Position)
		cam.CFrame = r.CFrame.lookAt(head.Position + Vector3.new(0, 2, 12.34), head.Position)
		local d0 = (cam.CFrame.Position - cam.Focus.Position).Magnitude
		local minWas, maxWas = localPlayer.CameraMinZoomDistance, localPlayer.CameraMaxZoomDistance
		hum.CameraOffset = Vector3.new(0.3, 0, 0)
		local theirs = hum.CameraOffset -- (as stored: Lune's Vector3 properties don't keep every bit)
		local realParts = {}
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
				table.insert(realParts, d)
			end
		end
		local seen = { words = {} }
		local function sample(t, st)
			local s = st.s
			seen.top = math.max(seen.top or 0, s)
			for _, d in VFX.Folder:GetDescendants() do
				if d:IsA("TextLabel") and (d.Text == "LEGENDARY" or d.Text == "FINAL FORM" or d.Text == "HAHAHAHAHA!" or d.Text == "AAAAAAAAAHHH!!") then
					seen.words[d.Text] = true
				end
			end
			local Dd = st.dbl
			if t > 16.4 and t < 17.2 and Dd and not seen.giant then
				seen.giant = true
				local b = FF.bulk(s)
				local T, Hd, R = Dd.torso, Dd.head, Dd.right
				seen.s16 = s
				if not (near(T.copy.Size.X, 2 * s * b, 0.02) and near(T.copy.Size.Y, 2 * s, 0.02) and near(T.copy.Size.Z, s * b, 0.02)) then
					problem(string.format("FINAL FORM 102: the giant's torso thick, not tall (%s at x%.2f, bulk %.2f)", tostring(T.copy.Size), s, b))
				end
				if not near(Hd.copy.Size.X, 2 * s, 0.02) then
					problem("FINAL FORM 102: his head scaled, not bulked (the face and crown ride it)")
				end
				-- the right arm out on the thicker torso's side, its top at the shoulder
				local rel = T.cf:PointToObjectSpace(R.cf.Position)
				if not (R and near(rel.X, 1.5 * s * b, 0.05) and near(rel.Y, 0, 0.05) and near(R.copy.Size.Y, 2 * s, 0.02) and near(R.copy.Size.X, s * b, 0.02)) then
					problem(string.format("FINAL FORM 102: his arm on his shoulder, thick not long (%s; want x %.2f)", tostring(rel), 1.5 * s * b))
				end
				-- his legs: their soles on the street
				for _, L in Dd.legs do
					local sole = st.F:PointToObjectSpace(L.cf * Vector3.new(0, -L.copy.Size.Y / 2, 0)).Y
					if math.abs(sole) > 0.05 then
						problem(string.format("FINAL FORM 102: the giant's soles on the street (%.3f)", sole))
					end
				end
				-- the hat riding his head
				local hat
				for _, rec in Dd.twins do
					if rec.real.Name == "Handle" then
						hat = rec
					end
				end
				if not (hat and hat.host == Hd and near(Hd.cf:PointToObjectSpace(hat.cf.Position).Y, 0.7 * s, 0.05)) then
					problem("FINAL FORM 102: his hat rides his head (the giant's)")
				end
				-- his camera: lifted and zoomed out with him, his offset kept
				local off = hum.CameraOffset
				local want = math.clamp(d0 * s ^ FFC.Camera.Pow, FFC.Camera.Least, FFC.Camera.Most)
				seen.lift, seen.min = off.Y, localPlayer.CameraMinZoomDistance
				if not (near(off.Y, FFC.Camera.Lift * (s - 1), 0.15) and near(off.X, 0.3, 1e-3)) then
					problem(string.format("FINAL FORM 102: his camera lifted with him, his own offset kept (%s at x%.2f)", tostring(off), s))
				end
				if not (near(localPlayer.CameraMinZoomDistance, want, 1) and localPlayer.CameraMaxZoomDistance >= localPlayer.CameraMinZoomDistance) then
					problem(string.format("FINAL FORM 102: his camera zoomed out to take the giant in (min %.1f, want %.1f, max %.1f)", localPlayer.CameraMinZoomDistance, want, localPlayer.CameraMaxZoomDistance))
				end
				-- the crown green, the second crater, the hair
				local gr = st.ground
				if not (gr and #gr.craters == 2) then
					problem("FINAL FORM 102: a second crater at LEGENDARY, twice the size")
				end
			end
			if t > 12 and t < 12.4 and st.ground and not seen.rocks2 then
				local up = 0
				for _, rk in st.ground.rocks2 do
					if rk.up then
						up += 1
					end
				end
				for _, sb in st.ground.slabs2 do
					if sb.up then
						up += 1
					end
				end
				seen.rocks2 = up
			end
			if t > 21.5 and t < 22 and not seen.orb then
				local o = st.orb
				seen.orb = o and o.size > 0.5 * st.s and o.core.Parent ~= nil and not o.fly
				seen.orbAt = o and o.pos
			end
			if t > 24.4 and t < 24.8 and not seen.fly then
				local o = st.orb
				seen.fly = o and o.fly and seen.orbAt and o.pos.Y > seen.orbAt.Y + 20
			end
			if t > 25.3 and t < 25.8 and seen.boom == nil then
				seen.boom = st.orb and st.orb.gone == true and st.orb.core.Parent == nil
			end
			if t > 28.2 and t < 28.6 and seen.after == nil then
				seen.after = st.dbl == nil and st.cam == nil
				seen.minAfter = localPlayer.CameraMinZoomDistance
			end
		end
		VFX.ReleasePose(body, 0)
		VFX.Play("Emote", body, { Id = "FinalForm" }, false)
		local t0 = os.clock()
		local st0
		while os.clock() - t0 < 31 do
			local st = FF.last
			if st and st.char == body then
				st0 = st
				pcall(sample, st.t, st)
			elseif st0 and os.clock() - t0 > 29.5 then
				break
			end
			task.wait()
		end
		if not st0 then
			problem("FINAL FORM 102: the props never ran on an R6 body")
		else
			if not (seen.top and seen.top >= 3.2 and seen.giant) then
				problem(string.format("FINAL FORM 102: he went LEGENDARY in the run (top x%.2f)", seen.top or 0))
			end
			for _, w in { "FINAL FORM", "LEGENDARY", "AAAAAAAAAHHH!!", "HAHAHAHAHA!" } do
				if not seen.words[w] then
					problem("FINAL FORM 102: the word " .. w)
				end
			end
			if not (seen.rocks2 and seen.rocks2 >= 6) then
				problem("FINAL FORM 102: the surge's rocks and slabs up round the giant (" .. tostring(seen.rocks2) .. ")")
			end
			if not seen.orb then
				problem("FINAL FORM 102: the Eraser Cannon - the green ball in his fist")
			end
			if not seen.fly then
				problem("FINAL FORM 102: ...hurled into the sky")
			end
			if not seen.boom then
				problem("FINAL FORM 102: ...and gone off up there on the last hit")
			end
			if not (seen.after and near(seen.minAfter or -1, minWas, 1e-3)) then
				problem("FINAL FORM 102: himself again at 28.125 s - the double gone, his camera given back (min " .. tostring(seen.minAfter) .. ")")
			end
		end
		task.wait(0.5)
		-- all of it given back exactly
		local hidden = 0
		for _, p in realParts do
			if p.LocalTransparencyModifier ~= 0 then
				hidden += 1
			end
		end
		if hidden > 0 or body:FindFirstChild("FinalFormDouble", true) or workspace:FindFirstChild("FinalFormDouble", true) then
			problem("FINAL FORM 102: his own body back, no double left (" .. hidden .. " still hidden)")
		end
		if not (hum.CameraOffset == theirs and localPlayer.CameraMinZoomDistance == minWas and localPlayer.CameraMaxZoomDistance == maxWas) then
			problem(string.format("FINAL FORM 102: his camera given back exactly (offset %s, min %.2f, max %.2f)", tostring(hum.CameraOffset), localPlayer.CameraMinZoomDistance, localPlayer.CameraMaxZoomDistance))
		end
		if FF.last ~= nil then
			problem("FINAL FORM 102: the run let go (FF.last)")
		end

		-- broken off while he's a giant: everything back at once
		VFX.ReleasePose(body, 0)
		VFX.Play("Emote", body, { Id = "FinalForm" }, false)
		t0 = os.clock()
		while os.clock() - t0 < 17 do
			local st = FF.last
			if st and st.char == body and st.t > 16 then
				break
			end
			task.wait()
		end
		local big = FF.last and FF.last.s or 0
		local lifted = hum.CameraOffset.Y
		VFX.ReleasePose(body, 0)
		task.wait(0.6)
		hidden = 0
		for _, p in realParts do
			if p.LocalTransparencyModifier ~= 0 then
				hidden += 1
			end
		end
		if big < 3 or lifted < 5 then
			problem(string.format("FINAL FORM 102 (broken off): he was a lifted giant first (x%.2f, offset %.2f)", big, lifted))
		end
		if hidden > 0 or FF.last ~= nil or hum.CameraOffset ~= theirs or localPlayer.CameraMinZoomDistance ~= minWas or localPlayer.CameraMaxZoomDistance ~= maxWas then
			problem(string.format("FINAL FORM 102 (broken off): his body and camera back at once (%d hidden; offset %s, min %.2f, max %.2f)", hidden, tostring(hum.CameraOffset), localPlayer.CameraMinZoomDistance, localPlayer.CameraMaxZoomDistance))
		end

		-- someone else's camera setting while it runs is theirs: kept, and not undone
		VFX.ReleasePose(body, 0)
		VFX.Play("Emote", body, { Id = "FinalForm" }, false)
		t0 = os.clock()
		while os.clock() - t0 < 17 do
			local st = FF.last
			if st and st.char == body and st.t > 15.6 then
				break
			end
			task.wait()
		end
		localPlayer.CameraMaxZoomDistance = 300 -- (a settings menu, say)
		task.wait(0.3)
		local kept = localPlayer.CameraMaxZoomDistance
		VFX.ReleasePose(body, 0)
		task.wait(0.6)
		if kept ~= 300 or localPlayer.CameraMaxZoomDistance ~= 300 or localPlayer.CameraMinZoomDistance ~= minWas or hum.CameraOffset ~= theirs then
			problem(string.format("FINAL FORM 102: a most-zoom set meanwhile is kept (%.1f then %.1f; min %.2f)", kept, localPlayer.CameraMaxZoomDistance, localPlayer.CameraMinZoomDistance))
		end
		localPlayer.CameraMaxZoomDistance = maxWas

		localPlayer.Character = wasChar
		cam.CFrame, cam.Focus = camWas, focusWas
		body:Destroy()
	end
end)()

print("== round 103: FINAL FORM changes the world - the column of light, the black-red sky, the seams across the map, the rubble, everyone's screen red")
-- (in a function of its own: the main chunk is at its 200-register limit here)
;(function()
	local EM = VFX.EMOTES
	local FF = EM and EM.FF
	local W = Config.FinalForm and Config.FinalForm.World
	if not (FF and W and FF.world and FF.worldFrame) then
		problem("FINAL FORM 103: the world (Config.FinalForm.World, FF.world / FF.worldFrame)")
		return
	end
	local function r6(pos)
		local model = Instance.new("Model")
		model.Name = "Broly"
		local function bp(name, size, cf)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = cf
			p.Position = cf.Position
			p.AssemblyLinearVelocity = Vector3.zero
			p.Parent = model
			return p
		end
		local at = r.CFrame.new(pos)
		local root = bp("HumanoidRootPart", Vector3.new(2, 2, 1), at)
		root.Transparency = 1
		local torso = bp("Torso", Vector3.new(2, 2, 1), at)
		local head = bp("Head", Vector3.new(2, 1, 1), at * r.CFrame.new(0, 1.5, 0))
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Parent = head
		local function j(name, p0, p1, c0, c1, holder)
			local m = Instance.new("Motor6D")
			m.Name = name
			m.Part0, m.Part1 = p0, p1
			m.C0, m.C1 = c0, c1
			m.Transform = r.CFrame.new()
			m.Parent = holder
			return m
		end
		j("RootJoint", root, torso, r.CFrame.new(), r.CFrame.new(), root)
		j("Neck", torso, head, r.CFrame.new(0, 1, 0), r.CFrame.new(0, -0.5, 0), torso)
		for _, sp in {
			{ "Right Arm", "Right Shoulder", Vector3.new(1.5, 0, 0), Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0) },
			{ "Left Arm", "Left Shoulder", Vector3.new(-1.5, 0, 0), Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0) },
			{ "Right Leg", "Right Hip", Vector3.new(0.5, -2, 0), Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0) },
			{ "Left Leg", "Left Hip", Vector3.new(-0.5, -2, 0), Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0) },
		} do
			local limb = bp(sp[1], Vector3.new(1, 2, 1), at * r.CFrame.new(sp[3]))
			j(sp[2], torso, limb, r.CFrame.new(sp[4]), r.CFrame.new(sp[5]), torso)
		end
		-- a hat on his head (welded: it rides the head, not the bulk)
		local acc = Instance.new("Accessory")
		acc.Name = "Cap"
		local handle = bp("Handle", Vector3.new(1.2, 0.4, 1.2), at * r.CFrame.new(0, 2.2, 0))
		handle.Parent = acc
		local w = Instance.new("Weld")
		w.Name = "AccessoryWeld"
		w.Part0, w.Part1 = handle, head
		w.Parent = handle
		acc.Parent = model
		local hum = InstanceShim.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.Parent = model
		Instance.new("Animator").Parent = hum
		model.PrimaryPart = root
		model.Parent = workspace
		return model, hum, root, torso, head
	end

	-- yours, someone's 60 studs off, someone's 520 off (past Skip: far off)
	local mine, hum, root, torso, head = r6(Vector3.new(700, 3, 700))
	local near = r6(Vector3.new(760, 3, 700))
	local far = r6(Vector3.new(1220, 3, 700))
	local wasChar = localPlayer.Character
	localPlayer.Character = mine
	local camWas, focusWas = cam.CFrame, cam.Focus
	cam.Focus = r.CFrame.new(head.Position)
	cam.CFrame = r.CFrame.lookAt(head.Position + Vector3.new(0, 2, 12.5), head.Position)
	for _, m in { mine, near, far } do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
	local runs = {}
	local realStart = FF.start
	FF.start = function(st)
		runs[st.char] = st
		return realStart(st)
	end
	for _, m in { mine, near, far } do
		VFX.ReleasePose(m, 0)
		VFX.Play("Emote", m, { Id = "FinalForm" }, false)
	end
	local seen = {}
	local function worldGrade()
		return cam:FindFirstChild("FinalFormWorld")
	end
	local t0 = os.clock()
	while os.clock() - t0 < 30.5 do
		local st = runs[mine]
		local t = st and st.t or 0
		if t > 16.3 and t < 17 and not seen.legend then
			seen.legend = true
			local wd = st.world
			local P = W.Pillar
			local d = wd and wd.layers[1] and wd.layers[1].part.Size.Y or 0
			seen.pillar = wd and d >= P.Width[1] * 0.9 and d <= P.Width[2] * 1.05 and wd.layers[1].part.Transparency < 0.5
			local streaks = 0
			for _, sk in wd and wd.streaks or {} do
				if sk.part.Transparency < 1 then
					streaks += 1
				end
			end
			seen.streaks = streaks
			seen.sky = wd and wd.sky[1].Transparency < 0.3 and wd.sky[2].Transparency < 0.4
			-- the seams: all the way out, far across the map
			local farthest, shown = 0, 0
			for _, s in wd and wd.seams or {} do
				for _, x in s.segs do
					if (x.shown or 0) > 0.01 then
						shown += 1
						local tip = x.from + x.dir * x.shown
						farthest = math.max(farthest, (Vector3.new(tip.X, 0, tip.Z) - Vector3.new(st.g.X, 0, st.g.Z)).Magnitude)
					end
				end
			end
			seen.farthest, seen.shown = farthest, shown
			seen.scorch = wd and wd.scorch and wd.scorch.Transparency < 0.5
			local up = 0
			for _, rk in wd and wd.rocks or {} do
				if rk.up and (rk.y or 0) > 3 then
					up += 1
				end
			end
			seen.rocks = up
			-- someone else's screen: the world dark and red
			local gr = worldGrade()
			seen.grade = gr and gr.Brightness < -0.02 and gr.TintColor.G < 0.95
			seen.mineGrade = st.world and st.world.grade == nil
			local fs = runs[far]
			seen.far = fs and fs.skip and fs.world and #fs.world.seams == 0 and #fs.world.rocks == 0 and fs.world.layers[1].part.Transparency < 0.5
			local ns = runs[near]
			seen.nearSeams = ns and ns.world and #ns.world.seams > 0
		end
		if t > 20.3 and t < 21 and seen.closed == nil then
			local wd = st.world
			seen.closed = wd and wd.layers[1].part.Transparency >= 0.99 and wd.base.Transparency >= 0.99
		end
		if t > 26.6 and t < 27.2 and seen.dropped == nil then
			local left = 0
			for _, rk in st.world and st.world.rocks or {} do
				if not rk.gone then
					left += 1
				end
			end
			seen.dropped = left
		end
		task.wait()
	end
	FF.start = realStart
	task.wait(0.6)
	if not seen.legend then
		problem("FINAL FORM 103: the run never reached LEGENDARY")
	else
		if not seen.pillar then
			problem("FINAL FORM 103: LEGENDARY - him inside a column of green light " .. W.Pillar.Width[1] .. "-" .. W.Pillar.Width[2] .. " studs across")
		end
		if (seen.streaks or 0) < W.Pillar.Streaks.Count[1] then
			problem("FINAL FORM 103: ...light racing up inside it (" .. tostring(seen.streaks) .. ")")
		end
		if not seen.sky then
			problem("FINAL FORM 103: the sky closed over the city, black-red")
		end
		if not (seen.farthest and seen.farthest >= W.Lava.Reach[1] * 0.9 and seen.shown >= W.Lava.Count[1] * W.Lava.Segs) then
			problem(string.format("FINAL FORM 103: red-hot seams all the way out across the map (out to %.0f studs, %d pieces)", seen.farthest or 0, seen.shown or 0))
		end
		if not seen.scorch then
			problem("FINAL FORM 103: the ground under him scorched black")
		end
		if (seen.rocks or 0) < W.Debris.Count[1] * 0.7 then
			problem("FINAL FORM 103: the rubble lifted off the street round him (" .. tostring(seen.rocks) .. ")")
		end
		if not seen.grade then
			problem("FINAL FORM 103: someone else's screen near him goes dark and red (FinalFormWorld)")
		end
		if not seen.mineGrade then
			problem("FINAL FORM 103: ...not his own (his has its own grade)")
		end
		if not seen.far then
			problem("FINAL FORM 103: far off (past Skip): the column and the sky still, not the seams or the rubble")
		end
		if not seen.nearSeams then
			problem("FINAL FORM 103: someone else's near: the seams on their screen too")
		end
		if not seen.closed then
			problem("FINAL FORM 103: the column drawn in to nothing before the Eraser Cannon")
		end
		if seen.dropped ~= 0 then
			problem("FINAL FORM 103: the rubble dropped when the sky went off (" .. tostring(seen.dropped) .. " still up)")
		end
	end
	if worldGrade() then
		problem("FINAL FORM 103: the red let go of everyone's screen at the end")
	end
	local left = 0
	for _, d in VFX.Folder:GetDescendants() do
		if d.Name == "EmoteProps" then
			left += 1
		end
	end
	if left > 0 then
		problem("FINAL FORM 103: every bag gone at the end (" .. left .. " left)")
	end
	localPlayer.Character = wasChar
	cam.CFrame, cam.Focus = camWas, focusWas
	for _, m in { mine, near, far } do
		VFX.ReleasePose(m, 0)
		m:Destroy()
	end
end)()

print("== round 104: THE JJBA PLACE'S STANDS (VFX.JS: Star Platinum, The World, C-MOON on its own models) and STAR PLATINUM's / POM's moves")
-- (in a function of its own: the main chunk is at its register limit here)
;(function()
	local JS, CDV, CM = VFX.JS, VFX.CDV, VFX.CM
	if not (JS and CDV) then
		problem("JJBA 104: VFX.JS / VFX.CDV")
		return
	end
	-- the JJBA place's folder (the test fixture: its stands, clips and the effects the code uses)
	local okF, jj = pcall(function()
		return r.deserializeModel(fs.readFile(process.env.JJBA_RBXM or "JJBA.rbxm"))[1]
	end)
	if not okF or not jj then
		problem("JJBA 104: the fixture (" .. tostring(jj) .. ")")
		return
	end
	jj.Parent = ReplicatedStorage
	local wasChar = localPlayer.Character
	local mine = makeR6("Jotaro", Vector3.new(400, 3, 0))
	localPlayer.Character = mine
	-- (the quirk set straight on: the HUD's own quirk switch isn't what this tests)
	localPlayer:SetAttribute("Quirk", "StarPlatinum")
	mine:SetAttribute("Quirk", "StarPlatinum")
	local root = mine.HumanoidRootPart
	local fwd = { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(400, 3, -30), Seed = 3, Origin = Vector3.new(400, 3, 0) }
	-- 1: ORA ORA ORA - Star Platinum out, the JJBA model in the rush
	VFX.Play("OraRush", mine, fwd, true)
	task.wait(0.4)
	local st = CDV.stands[mine]
	local SPJ = Config.JJBA.Stands.StarPlatinum
	if not st then
		problem("JJBA 104: Star Platinum comes out for ORA ORA ORA")
	else
		if st.kind ~= "StarPlatinum" then
			problem("...as Star Platinum (" .. tostring(st.kind) .. ")")
		end
		local r1 = st.js
		if not r1 then
			problem("...drawn from the JJBA place's model (VFX.JS)")
		else
			if r1.src ~= SPJ.Barrage then
				problem("...its own barrage clip in the rush (" .. tostring(r1.src) .. ")")
			end
			local shown, total = 0, 0
			for p, b in r1.base do
				if b < 0.99 then
					total += 1
					if p.Transparency < 0.5 then
						shown += 1
					end
				end
			end
			if total < 20 or shown < total * 0.8 then
				problem("...its parts showing (" .. shown .. " of " .. total .. ")")
			end
			for _, e in st.parts do
				if e.part.Transparency < 1 then
					problem("...and the part-built figure hidden (" .. e.part.Name .. ")")
					break
				end
			end
			local arm = r1.byName["Right Arm"]
			local c = arm and r1.cf[arm]
			if not c or (c.Position - root.Position).Magnitude > 12 then
				problem("...out beside him (" .. tostring(c and (c.Position - root.Position).Magnitude) .. " studs)")
			end
			if st.fists.armR and c and (st.fists.armR.CFrame.Position - (c * r.CFrame.new(0, -arm.Size.Y / 2, 0)).Position).Magnitude > 0.05 then
				problem("...its fist (where punches come from) on the model's hand")
			end
			if not (r1.aura and #r1.aura >= 3) then
				problem("...its aura (the JJBA place's SP Auras on its torso: " .. tostring(r1.aura and #r1.aura) .. ")")
			end
		end
	end
	task.wait(2)
	-- 2: STAR FINGER - its own clip, the fingers out
	VFX.Play("StarFinger", mine, fwd, true)
	task.wait(0.1)
	if st and st.js and st.js.src ~= SPJ.Finger then
		problem("STAR FINGER: its own clip (" .. tostring(st.js and st.js.src) .. ")")
	end
	VFX.Play("StarFingerShot", mine, { From = root.Position + Vector3.new(0, 1, -2), To = root.Position + Vector3.new(0, 1, -20), Dir = Vector3.new(0, 0, -1) }, false)
	-- the rest of his moves, and their server halves
	for _, id in { "OraHeavy", "StarWorld", "BearingShot", "OraFinale" } do
		VFX.Play(id, mine, fwd, true)
		task.wait(0.1)
	end
	VFX.Play("OraHeavyHit", mine, { Pos = root.Position + Vector3.new(0, 1, -5), Dir = Vector3.new(0, 0, -1), Hit = true }, false)
	VFX.Play("BearingTrail", mine, { From = root.Position, To = root.Position + Vector3.new(0, 0, -40), Speed = 320, Hits = {} }, false)
	VFX.Play("OraFinaleGo", mine, { Hits = 6, Interval = 0.05, Dir = Vector3.new(0, 0, -1) }, false)
	VFX.Play("OraFinaleBlow", mine, { Dir = Vector3.new(0, 0, -1) }, false)
	VFX.Play("TimeStop", mine, { Radius = 100, Duration = 0.5, Frozen = {}, Kind = "StarPlatinum" }, false)
	task.wait(1)
	VFX.Play("TimeResume", mine, { Frozen = {} }, false)
	task.wait(0.5)
	-- DIO: The World on its JJBA model too; his knives and the road roller are the JJBA place's
	localPlayer:SetAttribute("Quirk", "TheWorld")
	mine:SetAttribute("Quirk", "TheWorld")
	VFX.Play("MudaRush", mine, fwd, true)
	task.wait(0.3)
	local tw = CDV.stands[mine]
	if not (tw and tw.kind == "TheWorld" and tw.js and tw.js.src == Config.JJBA.Stands.TheWorld.Barrage) then
		problem("THE WORLD: its JJBA model, its own barrage clip (" .. tostring(tw and tw.js and tw.js.src) .. ")")
	end
	task.wait(1.6)
	local k = JS.knife(r.CFrame.new(400, 5, 0))
	if not k then
		problem("DIO's knives: the JJBA place's DIOKNIFE")
	else
		k.gone(0.05)
	end
	local roller = VFX.DV and VFX.DV.roller(r.CFrame.new(400, 0, 20))
	if not (roller and roller.parts and #roller.parts == 1 and roller.parts[1].part:IsA("MeshPart")) then
		problem("ROAD ROLLER DA!: the JJBA place's road roller (" .. tostring(roller and #roller.parts) .. ")")
	end
	if roller then
		roller.model:Destroy()
	end
	-- POM: every move, and their server halves
	localPlayer:SetAttribute("Quirk", "POM")
	mine:SetAttribute("Quirk", "POM")
	for _, id in { "POMFist", "POMDouble", "POMCharge", "POMVoid", "POMSlam", "POMLastWord" } do
		VFX.Play(id, mine, fwd, true)
		task.wait(0.1)
	end
	VFX.Play("POMHit", mine, { Pos = root.Position + Vector3.new(0, 1, -4), Dir = Vector3.new(0, 0, -1), Hit = true, Heavy = true, Shock = 12 }, false)
	VFX.Play("POMChargeRelease", mine, { Dir = Vector3.new(0, 0, -1) }, false)
	VFX.Play("POMVoidBall", mine, { From = root.Position, Dir = Vector3.new(0, 0, -1), Speed = 200, Range = 30, Radius = 3 }, false)
	VFX.Play("POMSlamGo", mine, { From = root.Position, Pos = root.Position + Vector3.new(0, 0, -10), Time = 0.3, Height = 10 }, false)
	VFX.Play("POMSlamLand", mine, { Pos = root.Position + Vector3.new(0, 0, -10), Radius = 15 }, false)
	task.wait(1.5)
	-- PUCCI: C-MOON on the JJBA place's model, on his own rig's bones
	if CM then
		localPlayer:SetAttribute("Quirk", "CMoon")
		mine:SetAttribute("Quirk", "CMoon")
		task.wait(0.7)
		VFX.Play("CMoonRush", mine, fwd, true)
		task.wait(0.6)
		local rig = CM.rigs[mine]
		if not rig then
			problem("C-MOON 104: Pucci's rig")
		else
			local m = rig.js and rig.js.CMoon
			if not (rig.jsUsed and m) then
				problem("C-MOON 104: drawn from the JJBA place's C-MOON (" .. tostring(rig.jsUsed) .. ")")
			else
				local shown = 0
				for p, b in m.base do
					if b < 0.99 and p.Transparency < 0.5 then
						shown += 1
					end
				end
				if shown < 10 then
					problem("...its parts showing (" .. shown .. ")")
				end
				for _, it in rig.items do
					if it.part.Transparency < 1 then
						problem("...and the part-built C-MOON hidden")
						break
					end
				end
			end
		end
	end
	localPlayer:SetAttribute("Quirk", nil)
	mine:SetAttribute("Quirk", nil)
	task.wait(0.8)
	localPlayer.Character = wasChar
	mine:Destroy()
	jj.Parent = nil
end)()

print("== round 34: the controller legend, the wings going back in, emotes on a pad")
do
	local hud = playerGui:FindFirstChild("QuirkHUD")
	local function textOf(container, want)
		for _, d in container:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == want then
				return d
			end
		end
		return nil
	end
	-- on a controller: the legend bottom left, the pad's names on the move slots
	HUD.SetInputMode("Gamepad")
	local legend = hud and hud:FindFirstChild("PadLegend", true)
	if not (legend and legend.Visible) then
		problem("on a controller: a button legend (" .. tostring(legend) .. ")")
	else
		if legend.AnchorPoint.X ~= 0 or legend.AnchorPoint.Y ~= 1 or legend.Position.X.Scale ~= 0 or legend.Position.Y.Scale ~= 1 then
			problem("...bottom left (" .. tostring(legend.Position) .. ")")
		end
		local rows = 0
		for _, c in legend:GetChildren() do
			if c:IsA("Frame") and c:FindFirstChild("Label") and c:FindFirstChild("Glyph") then
				rows += 1
			end
		end
		if rows < 10 then
			problem("...a row per button (" .. rows .. ")")
		end
		for _, want in { "PUNCH", "BLOCK", "DASH", "JUMP", "SPECIAL", "AWAKEN", "EMOTES", "SHOP" } do
			if not textOf(legend, want) then
				problem("...with " .. want)
			end
		end
		local punch = legend:FindFirstChild("PUNCH")
		local g = punch and punch:FindFirstChild("Glyph")
		if not (g and (g:IsA("ImageLabel") or (g:IsA("TextLabel") and g.Text == "B"))) then
			problem("...PUNCH on B (" .. tostring(g and g.ClassName) .. ")")
		end
	end
	local line = textOf(hud, "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · T Lock-on · B Emotes · H Shop · M Quirk")
	local slot1 = hud and hud:FindFirstChild("Slot1", true)
	if not (slot1 and textOf(slot1, "LB")) then
		problem("...move 1's slot says LB")
	end
	-- back on the keyboard
	HUD.SetInputMode("Keyboard")
	if legend and legend.Visible then
		problem("on a keyboard the legend goes")
	end
	line = line or textOf(hud, "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · T Lock-on · B Emotes · H Shop · M Quirk")
	if not (line and line.Visible) then
		problem("...and the key line is back")
	end
	if not (slot1 and textOf(slot1, "1")) then
		problem("...move 1's slot says 1 again")
	end

	-- Suneater's dash: the wings grow out of his back, then fold back into him
	local before = {}
	for _, d in VFX.Folder:GetChildren() do
		before[d] = true
	end
	play("Dash", { Dir = Vector3.new(0, 0, -1), Kind = "Front", Quirk = "Manifest" })
	task.wait(0.15)
	local feathers = {}
	for _, d in VFX.Folder:GetChildren() do
		if not before[d] and d:IsA("BasePart") and d.Size.X > 1.5 and d.Size.Y < 0.3 then
			table.insert(feathers, d)
		end
	end
	if #feathers < 6 then
		problem("SUNEATER's dash: chicken wings out of his back (" .. #feathers .. " feathers)")
	end
	task.wait(0.65)
	for _, f in feathers do
		if f.Size.X > 0.5 or f.Transparency < 1 then
			problem("...then they fold back into his body (" .. tostring(f.Size) .. ", " .. f.Transparency .. ")")
			break
		end
	end

	-- emotes on a controller: click the right stick, tilt it at one, click again
	-- (the harness's own input shims: the last input, the right stick; and no
	-- menu open - a pad drives the menu while one is)
	HUD.ShowMenu(false)
	HUD.ToggleShop(false)
	HUD.HideVendor()
	lastInputType = Enum.UserInputType.Gamepad1
	local wheel = hud and hud:FindFirstChild("EmoteWheel", true)
	table.clear(fired)
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonR3 })
	if not (wheel and wheel.Visible) then
		problem("R3 opens the emote wheel on a controller")
	end
	local hint = wheel and wheel:FindFirstChild("Hint", true)
	if not (hint and hint.Text:find("stick")) then
		problem("...and says how to use it with the stick (" .. tostring(hint and hint.Text) .. ")")
	end
	-- straight down on the stick: the slice at the bottom of the ring
	local ringN = Config.EmoteSlots
	local want = { Id = WHEEL58[math.floor(ringN / 2) + 1] }
	local downA = math.floor(ringN / 2) / ringN * math.pi * 2
	stick2Pos = Vector3.new(math.sin(downA), math.cos(downA), 0)
	task.wait(0.1)
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonR3 })
	actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonR3 })
	task.wait(0.05)
	local sent
	for _, f in fired do
		if f[2] == Config.EMOTE_INDEX then
			sent = f[3]
		end
	end
	if wheel and wheel.Visible or sent ~= want.Id then
		problem("...tilt it down and click again: " .. want.Id .. " (" .. tostring(sent) .. ")")
	end
	stick2Pos = Vector3.zero
	lastInputType = Enum.UserInputType.Keyboard
	task.wait(0.3)
end

print("== round 33: Suneater's new kit, the emote wheel")
do
	local SEv = VFX.SE
	local function newParts(before)
		local out = {}
		for _, d in VFX.Folder:GetChildren() do
			if not before[d] and d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
		return out
	end
	local function snap()
		local b = {}
		for _, d in VFX.Folder:GetChildren() do
			b[d] = true
		end
		return b
	end
	-- the blocky tentacle (the sketch): square blocks, two suckers side by
	-- side on every segment; a thin one gets one each
	local before = snap()
	local t = SEv.tentacle(0.9, 6)
	t.set(myRoot.Position, myRoot.Position + Vector3.new(0, 0, -12), 2, 0.3)
	local blocks, discs, square = 0, 0, true
	for _, p in newParts(before) do
		if p.Shape.Name == "Block" then
			blocks += 1
			if math.abs(p.Size.X - p.Size.Y) > 0.01 then
				square = false
			end
		elseif p.Shape.Name == "Cylinder" then
			discs += 1
		end
	end
	if blocks ~= 6 or discs ~= 12 or not square then
		problem("a thick tentacle: 6 square blocks, 2 suckers on each (" .. blocks .. " blocks, " .. discs .. " suckers, square " .. tostring(square) .. ")")
	end
	t.fade(0.05)
	before = snap()
	local thin = SEv.tentacle(0.3, 5)
	thin.set(myRoot.Position, myRoot.Position + Vector3.new(0, 0, -6), 0.5, 0.2)
	discs = 0
	for _, p in newParts(before) do
		if p.Shape.Name == "Cylinder" then
			discs += 1
		end
	end
	if discs ~= 5 then
		problem("a thin tentacle: one sucker a segment (" .. discs .. ")")
	end
	thin.fade(0.05)
	task.wait(0.1)

	local function wornOn(part)
		local n, longest = 0, 0
		for _, d in VFX.Folder:GetChildren() do
			local w = d:IsA("BasePart") and d:FindFirstChildOfClass("Weld")
			if w and w.Part0 == part and d.Transparency < 1 then
				n += 1
				longest = math.max(longest, d.Size.Y)
			end
		end
		return n, longest
	end
	local leg = myChar:FindFirstChild("RightFoot") or myChar:FindFirstChild("Right Leg")
	local hand = myChar:FindFirstChild("RightHand") or myChar:FindFirstChild("Right Arm")
	local legBefore = wornOn(leg)
	-- CHICKEN KICK: a chicken leg on his leg
	VFX.Play("ChickenKick", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	local n = wornOn(leg) - legBefore
	if n < 10 then
		problem("CHICKEN KICK: a chicken leg over his leg (" .. n .. " pieces)")
	end
	task.wait(0.9)

	-- TAKO SNATCH: the arm reaches out; caught, it coils round them and
	-- follows them until the server lets go
	local foe = makeR15("SnatchFoe", myRoot.Position + Vector3.new(0, 8, -14))
	VFX.Play("TakoSnatch", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	if not SEv.arms[myChar] then
		problem("TAKO SNATCH: the octopus arm should reach out")
	end
	setAttr(foe, "Grabbed", true)
	PlayVFX.OnClientEvent:Fire("TakoSnatchCatch", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1), Reach = 16, Air = true })
	task.wait(0.4)
	local arm = SEv.arms[myChar]
	if not (arm and arm.target == foe and arm.coil) then
		problem("...it catches them and coils round them")
	else
		local tip = arm.tent.parts[#arm.tent.parts].CFrame.Position
		local fr = foe.HumanoidRootPart.CFrame.Position
		if (tip - fr).Magnitude > 3 then
			problem("...its tip on them (" .. math.floor((tip - fr).Magnitude) .. " studs off)")
		end
	end
	setAttr(foe, "Grabbed", nil)
	task.wait(0.4)
	if SEv.arms[myChar] then
		problem("...and lets go when the server does")
	end
	PlayVFX.OnClientEvent:Fire("TentacleSlam", myChar, { Pos = myRoot.Position - Vector3.new(0, 3, 6), Big = true })
	-- a miss: it comes back
	VFX.Play("TakoSnatch", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	PlayVFX.OnClientEvent:Fire("TakoSnatchCatch", myChar, { Dir = Vector3.new(0, 0, -1), Reach = 45 })
	task.wait(0.5)
	if SEv.arms[myChar] then
		problem("...a miss: the arm goes back into his hand")
	end
	-- an observer who never saw it go out still sees the catch
	PlayVFX.OnClientEvent:Fire("TakoSnatchCatch", other, { Target = foe, Dir = Vector3.new(0, 0, 1), Reach = 16 })
	task.wait(0.1)
	if not SEv.arms[other] then
		problem("...someone who missed the cast still sees the arm catch them")
	end
	task.wait(0.5)

	-- TAKO THRASH: the big tentacle holds them through the slams
	VFX.Play("TakoThrash", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.1)
	setAttr(foe, "Grabbed", true)
	PlayVFX.OnClientEvent:Fire("TakoThrashCatch", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1) })
	task.wait(0.8)
	arm = SEv.arms[myChar]
	if not (arm and arm.target == foe) then
		problem("TAKO THRASH: the tentacle holds them through the slams")
	elseif arm.tent.parts[1].Size.X < 1 then
		problem("...a big one (" .. arm.tent.parts[1].Size.X .. ")")
	end
	for i = 1, 3 do
		PlayVFX.OnClientEvent:Fire("TentacleSlam", myChar, { Pos = myRoot.Position + Vector3.new(i % 2 == 1 and -7 or 7, -3, -3), Big = i == 3 })
	end
	setAttr(foe, "Grabbed", nil)
	task.wait(0.5)

	-- SWORDFISH: the bill on his hand; lifted, flung
	local handBefore = wornOn(hand)
	VFX.Play("Swordfish", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.05)
	local worn, longest = wornOn(hand)
	if worn - handBefore < 6 or longest < 5 then
		problem("SWORDFISH: a swordfish's bill for a hand (" .. (worn - handBefore) .. " pieces, longest " .. longest .. ")")
	end
	PlayVFX.OnClientEvent:Fire("SwordfishImpale", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1) })
	task.wait(1.2)
	-- CLAM HAMMER (in the air): a clamshell hammer over his fists
	handBefore = wornOn(hand)
	VFX.Play("Swordfish", myChar, { Dir = Vector3.new(0, 0, -1), Air = true }, true)
	task.wait(0.1)
	worn = wornOn(hand)
	if worn - handBefore < 10 then
		problem("CLAM HAMMER: both fists become a clamshell hammer (" .. (worn - handBefore) .. " pieces)")
	end
	PlayVFX.OnClientEvent:Fire("ClamHammerLand", myChar, { Pos = myRoot.Position - Vector3.new(0, 3, 0), Dir = Vector3.new(0, 0, -1) })
	task.wait(1.2)
	foe:Destroy()

	-- THE EMOTE WHEEL (B)
	local wheel = playerGui:FindFirstChild("EmoteWheel", true)
	if not wheel then
		problem("an emote wheel in the HUD")
	else
		local plays = {}
		local realPlay = VFX.Play
		VFX.Play = function(id, char, data, isLocal)
			if id == "Emote" then
				table.insert(plays, data and data.Id)
			end
			return realPlay(id, char, data, isLocal)
		end
		local function sentEmote()
			for _, f in fired do
				if f[2] == Config.EMOTE_INDEX then
					return f[3]
				end
			end
			return nil
		end
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		if not wheel.Visible then
			problem("B opens the emote wheel")
		end
		if not wheel.Modal then
			problem("...and frees the mouse from shift lock")
		end
		local slices = 0
		for _, d in wheel:GetDescendants() do
			if d:IsA("TextButton") and d:GetAttribute("EmoteId") then
				slices += 1
			end
		end
		if slices ~= Config.EmoteSlots then
			problem("...one slice per slot (" .. slices .. ")")
		end
		-- click one
		table.clear(fired)
		local dance = wheel:FindFirstChild("Emote_Dance", true)
		signalOf(dance, "Activated"):Fire()
		task.wait(0.1)
		if wheel.Visible then
			problem("picking one closes the wheel")
		end
		if sentEmote() ~= "Dance" or plays[#plays] ~= "Dance" then
			problem("...and plays it here and tells the server (" .. tostring(sentEmote()) .. ", " .. tostring(plays[#plays]) .. ")")
		end
		-- hold B, point at one, let go
		table.clear(fired)
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		signalOf(wheel:FindFirstChild("Emote_Wave", true), "MouseEnter"):Fire()
		task.wait(0.4)
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		task.wait(0.05)
		if wheel.Visible or sentEmote() ~= "Wave" then
			problem("hold B, point, let go: that one (" .. tostring(sentEmote()) .. ")")
		end
		-- tap B twice: shut again, nothing played
		table.clear(fired)
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		if not wheel.Visible then
			problem("a quick tap of B leaves the wheel open to click")
		end
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		if wheel.Visible or sentEmote() then
			problem("...and B again shuts it without playing anything")
		end
		-- clicking off the slices closes it (and never punches)
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		signalOf(wheel, "Activated"):Fire()
		if wheel.Visible then
			problem("a click off the slices closes it")
		end
		-- stunned: nothing
		table.clear(fired)
		setAttr(myChar, "Stunned", true)
		actions.QuirkEmote("QuirkEmote", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
		signalOf(wheel:FindFirstChild("Emote_Flex", true), "Activated"):Fire()
		setAttr(myChar, "Stunned", false)
		if sentEmote() then
			problem("no emotes while stunned")
		end
		VFX.Play = realPlay
		-- every emote plays (on someone else too), and one stops when they move
		local released = 0
		local realRelease = VFX.ReleasePose
		VFX.ReleasePose = function(char, ...)
			if char == other then
				released += 1
			end
			return realRelease(char, ...)
		end
		for _, e in Config.Emotes do
			PlayVFX.OnClientEvent:Fire("Emote", other, { Id = e.Id })
			task.wait(0.15)
		end
		PlayVFX.OnClientEvent:Fire("Emote", other, { Id = "Dance" })
		task.wait(0.2)
		local oroot = other:FindFirstChild("HumanoidRootPart")
		oroot.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		task.wait(0.2)
		oroot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		VFX.ReleasePose = realRelease
		if released < 1 then
			problem("an emote stops the moment they move")
		end
		PlayVFX.OnClientEvent:Fire("Emote", other, { Id = "NotAnEmote" })
		task.wait(0.3)
	end
end

print("== round 32: the transformation, TERRIFIED, the two dash timers")
do
	-- MUSCLE FORM: the street cracks and the rubble lifts round him in the
	-- cloud; a heartbeat; then the burst - his face in shadow, two eyes glowing
	local cues = {}
	local realPlaySound = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		cues[name] = true
		return realPlaySound(name, ...)
	end
	local function slate()
		local n = 0
		for _, d in VFX.Folder:GetChildren() do
			if d:IsA("BasePart") and d.Material.Name == "Slate" then
				n += 1
			end
		end
		return n
	end
	local before = slate()
	local existing = {} -- (the harness never clears old effects: only look at this one's)
	for _, d in VFX.Folder:GetChildren() do
		existing[d] = true
	end
	local start76 = os.clock()
	VFX.Play("MuscleForm", myChar, { Alt = true }, true)
	local stretch76 = Config.Quirks.OneForAll.Special.Presence.BurstAt / 1.35 -- (round 76: a longer build)
	task.wait(0.5 * stretch76)
	local mid = slate() - before
	if mid < 40 then
		problem("muscle form: the street should crack and the rubble lift round him while he powers up (" .. mid .. " pieces)")
	end
	if not cues.MuscleRumble then
		problem("muscle form: a deep rumble as the pressure builds (MuscleRumble)")
	end
	task.wait(math.max(0.55, Config.Quirks.OneForAll.Special.Presence.BurstAt + 0.3 - (os.clock() - start76))) -- (past the burst; round 76: a longer build)
	if not cues.MuscleThump then
		problem("muscle form: one heartbeat before he bursts out (MuscleThump)")
	end
	if not (cues.Transform and cues.IAmHere) then
		problem("muscle form: the burst and I AM HERE")
	end
	local head = myChar:FindFirstChild("Head")
	local shade, eyes = nil, {}
	for _, d in VFX.Folder:GetChildren() do
		if existing[d] then
			continue
		end
		if d:IsA("Highlight") and d.Name == "HeroShadow" then
			shade = d
		end
		local w = d:IsA("BasePart") and d:FindFirstChildOfClass("Weld")
		if w and w.Part0 == head and d.Material.Name == "Neon" then
			table.insert(eyes, d)
		end
	end
	if not (shade and shade.Adornee == head and shade.FillTransparency < 0.5) then
		problem("muscle form: his face should be cast in shadow (a dark highlight on the head)")
	end
	if #eyes ~= 2 then
		problem("muscle form: two glowing eyes welded to his head (" .. #eyes .. ")")
	else
		local w = eyes[1]:FindFirstChildOfClass("Weld")
		if w.C0.Position.Z > -0.3 or math.abs(w.C0.Position.X) < 0.1 then
			problem("...on the front of his face, either side (" .. tostring(w.C0.Position) .. ")")
		end
		if eyes[1].Anchored or not eyes[1].Massless then
			problem("...riding along with the head (unanchored, massless)")
		end
		if not eyes[1]:FindFirstChildOfClass("PointLight") and not eyes[2]:FindFirstChildOfClass("PointLight") then
			problem("...and casting a little blue light")
		end
	end
	VFX.PlaySound = realPlaySound
	task.wait(3.5)
	if shade and shade.FillTransparency < 0.95 then
		problem("the shadow on his face should lift after a few seconds (" .. shade.FillTransparency .. ")")
	end
	for _, e in eyes do
		if e.Transparency < 0.95 then
			problem("...and the eyes fade (" .. e.Transparency .. ")")
		end
	end
	-- no head (a broken rig): the rest still plays, nothing errors
	local headless = makeR15("Headless", myRoot.Position + Vector3.new(30, 0, 0))
	headless.Head:Destroy()
	VFX.Play("MuscleForm", headless, { Alt = true }, false)
	task.wait(1.1)
	headless:Destroy()

	-- TERRIFIED: frozen in his presence (sent only to you)
	local callouts = {}
	local realCallout = VFX.Hooks.Callout
	VFX.Hooks.Callout = function(text, ...)
		table.insert(callouts, text)
		return realCallout(text, ...)
	end
	local amight = makeR15("Presence", myRoot.Position + Vector3.new(0, 0, -8))
	PlayVFX.OnClientEvent:Fire("Terrified", nil, { From = amight })
	PlayVFX.OnClientEvent:Fire("Terrified", nil, {})
	task.wait(0.2)
	VFX.Hooks.Callout = realCallout
	if table.concat(callouts, ","):find("TERRIFIED") == nil then
		problem("caught in his presence: TERRIFIED (" .. table.concat(callouts, ",") .. ")")
	end
	amight:Destroy()

	-- the two dash timers: a front dash starts the long one, a side/back
	-- step the short one - and the HUD shows both
	local started = {}
	local realStart = HUD.StartCooldown
	HUD.StartCooldown = function(key, length)
		started[key] = length
		return realStart(key, length)
	end
	local cam = workspace.CurrentCamera
	local was = cam.CFrame
	local ncWas = localPlayer:GetAttribute("NoCooldowns")
	pcall(function()
		myRoot.AssemblyMass = 12 -- (the harness has no physics)
	end)
	localPlayer:SetAttribute("NoCooldowns", nil)
	HUD.ResetCooldowns()
	cam.CFrame = r.CFrame.new(0, 5, 10)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.8)
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.1)
	HUD.StartCooldown = realStart
	if started.DashFront ~= Config.Movement.FrontDashCooldown then
		problem("a front dash: the front dash timer (" .. tostring(started.DashFront) .. ")")
	end
	if started.DashMobility ~= Config.Movement.MobilityDashCooldown then
		problem("a side step straight after: its own short timer (" .. tostring(started.DashMobility) .. ")")
	end
	local strip = playerGui:FindFirstChild("MobilityCooldown", true)
	if not (strip and strip.Size.X.Scale > 0.5) then
		problem("the HUD: the side/back step's timer drains along the dash slot (" .. tostring(strip and strip.Size) .. ")")
	end
	task.wait(Config.Movement.MobilityDashCooldown + 0.1)
	if strip and strip.Size.X.Scale > 0 then
		problem("...and is empty once it's back (" .. tostring(strip.Size) .. ")")
	end
	cam.CFrame = was
	myHum.MoveDirection = Vector3.zero
	localPlayer:SetAttribute("NoCooldowns", ncWas)
	task.wait(0.4)
end

print("== round 31: JET KINDLING, PERMEATE (walls, the dive)")
do
	-- JET KINDLING: the rush (his own machine flies him), then the fist going off
	local foe = makeR15("JkFoe", myRoot.Position + Vector3.new(0, 0, -6))
	local oldAtts = {}
	for _, c in myRoot:GetChildren() do
		oldAtts[c] = true
	end
	VFX.Play("JetKindling", myChar, { Dir = Vector3.new(0, 0, -1) }, true)
	task.wait(0.05)
	local jet
	for _, c in myRoot:GetChildren() do
		if not oldAtts[c] and c.Name == "DashAttachment" then
			jet = c
		end
	end
	if not jet then
		problem("JET KINDLING: his flames should rocket him along the aim")
	end
	VFX.Play("JetKindlingHit", myChar, { Target = foe, Dir = Vector3.new(0, 0, -1), At = foe.HumanoidRootPart.Position }, false)
	task.wait(0.05)
	if jet and jet.Parent then
		problem("...and stop on the one he punches")
	end
	VFX.Play("JetKindlingHit", myChar, { Dir = Vector3.new(0, 0, -1), At = myRoot.Position + Vector3.new(0, 0, -4) }, false)
	task.wait(1.8) -- (let them finish burning)
	foe:Destroy()

	-- WALL PHASE: the walls round him stop being solid for him; the floor never does
	local map = workspace:FindFirstChild("Map") or Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	local p0 = myRoot.Position
	local floor = Instance.new("Part")
	floor.Name = "Street"
	floor.Anchored = true
	floor.Size = Vector3.new(80, 2, 80)
	floor.CFrame = r.CFrame.new(p0.X, p0.Y - 4, p0.Z) -- (tops out at his feet)
	floor.CanCollide = true
	floor.Parent = map
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.Size = Vector3.new(20, 14, 2)
	wall.CFrame = r.CFrame.new(p0.X, p0.Y + 3, p0.Z - 3)
	wall.CanCollide = true
	wall.Parent = map
	local inWall = false
	local boundsWas = boundsImpl
	boundsImpl = function(_, _cf, size)
		if size.X > 5 then
			return { floor, wall } -- (the scan round him)
		end
		return inWall and { wall } or {} -- (what his body is inside)
	end
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Instance = floor, Position = Vector3.new(origin.X, p0.Y - 3, origin.Z), Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end)
	setAttr(myChar, "WallPhase", true)
	task.wait(0.1)
	if wall.CanCollide or not floor.CanCollide then
		problem("WALL PHASE: the wall should let him through, the floor shouldn't (wall " .. tostring(wall.CanCollide) .. ", floor " .. tostring(floor.CanCollide) .. ")")
	end
	setAttr(myChar, "WallPhase", false)
	task.wait(0.1)
	if not wall.CanCollide then
		problem("...and the wall's solid again once it's over")
	end
	-- it runs out with him inside the wall: a moment to walk out, then it spits him out
	setAttr(myChar, "WallPhase", true)
	task.wait(0.1)
	local clear = myRoot.CFrame
	inWall = true
	myRoot.CFrame = r.CFrame.new(p0.X, p0.Y, p0.Z - 3)
	myRoot.Position = Vector3.new(p0.X, p0.Y, p0.Z - 3)
	task.wait(0.05)
	setAttr(myChar, "WallPhase", false)
	task.wait(0.2)
	if wall.CanCollide then
		problem("inside the wall when it ended: it should stay open a moment for him")
	end
	task.wait(1.3)
	if not wall.CanCollide or (myRoot.CFrame.Position - clear.Position).Magnitude > 0.5 then
		problem("...then spit him back out where he was clear (" .. tostring(myRoot.CFrame.Position) .. ")")
	end
	inWall = false
	boundsImpl = boundsWas
	setRaycast(nil)
	myRoot.Position = myRoot.CFrame.Position

	-- PHASE DIVE: through everything, then steer where to come out
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Instance = floor, Position = Vector3.new(origin.X, 0, origin.Z), Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end)
	local cam = workspace.CurrentCamera
	setAttr(myChar, "PhaseDive", true)
	task.wait(0.1)
	local lv = myRoot:FindFirstChild("PhaseDive")
	local torso = myChar:FindFirstChild("UpperTorso") or myChar:FindFirstChild("Torso")
	if not (lv and lv.VectorVelocity.Y < -50 and torso and torso.CollisionGroup == "PhaseDive") then
		problem("PHASE DIVE: his body should drop through everything (" .. tostring(lv) .. ", " .. tostring(torso and torso.CollisionGroup) .. ")")
	end
	setAttr(myChar, "Submerged", true)
	task.wait(0.1)
	local marker = VFX.Folder:FindFirstChild("PermeateMarker")
	if not marker or cam.CameraSubject ~= marker or myRoot:FindFirstChild("PhaseDive") then
		problem("under the street: the fall stops and he steers a marker (camera on it)")
	end
	local m0 = marker and marker.CFrame.Position
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	task.wait(0.5)
	myHum.MoveDirection = Vector3.zero
	local moved = marker and (marker.CFrame.Position - m0).X or 0
	if moved < 15 then
		problem("...the movement keys move the marker (" .. moved .. ")")
	end
	table.clear(fired)
	signalOf(uis, "InputBegan"):Fire({ KeyCode = Enum.KeyCode.R, UserInputType = Enum.UserInputType.Keyboard }, true)
	task.wait(0.05)
	local sent
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.RELEASE_INDEX then
			sent = f
		end
	end
	if not (sent and typeof(sent[4]) == "Vector3" and marker and (sent[4] - marker.CFrame.Position).Magnitude < 1) then
		problem("R picks the spot: the release carries where the marker is")
	end
	setAttr(myChar, "Submerged", false)
	setAttr(myChar, "PhaseDive", false)
	task.wait(0.1)
	if VFX.Folder:FindFirstChild("PermeateMarker") or (torso and torso.CollisionGroup == "PhaseDive") or cam.CameraSubject ~= myHum then
		problem("out: marker gone, his body solid again, camera back on him")
	end
	VFX.Play("PermeateSpit", myChar, { Pos = myRoot.Position - Vector3.new(0, 3, 0), Dir = Vector3.new(0, 0, -1) }, false)
	VFX.Play("Permeate", myChar, { Air = true }, true)
	setRaycast(nil)
	floor:Destroy()
	wall:Destroy()
end

print("== round 30: ult music, I AM HERE, the new HUD")
do
	local MU = Config.UltMusic
	local SS = game:GetService("SoundService")
	local track = SS:FindFirstChild("UltMusic", true)
	local peak = MU.Volume * ((Config.Audio and Config.Audio.MusicVolume) or 1)
	setAttr(localPlayer, "Quirk", "OneForAll")
	setAttr(localPlayer, "UltActive", true)
	task.wait(0.6)
	local playing, owner, level = VFX.Hooks.MusicState()
	if not (playing == MU.Tracks.OneForAll.Id and owner == localPlayer and level > 0) then
		problem("your ult: its theme should start (" .. tostring(playing) .. ", " .. tostring(level) .. ")")
	end
	if not (track and track.SoundId == MU.Tracks.OneForAll.Id and track.Looped) then
		problem("the UltMusic sound should be playing All Might's theme (" .. tostring(track and track.SoundId) .. ")")
	end
	task.wait(MU.FadeIn + 0.3)
	playing, owner, level = VFX.Hooks.MusicState()
	if math.abs(level - peak) > 0.02 then
		problem("...faded up to full volume (" .. level .. " of " .. peak .. ")")
	end
	print(string.format("  theme %s at %.2f", tostring(playing), level))
	-- MUSIC on the HUD mutes it (and back)
	local btn = hudGui:FindFirstChild("MusicToggle", true)
	if not btn then
		problem("the HUD should have a MUSIC switch")
	else
		signalOf(btn, "MouseButton1Click"):Fire()
		task.wait(MU.FadeOut + 0.3)
		_, _, level = VFX.Hooks.MusicState()
		if level > 0.001 or not btn.Text:find("OFF") then
			problem("MUSIC off: it should fade to silence (" .. level .. ", " .. btn.Text .. ")")
		end
		signalOf(btn, "MouseButton1Click"):Fire()
		task.wait(MU.FadeIn + 0.3)
		_, _, level = VFX.Hooks.MusicState()
		if level < peak - 0.02 or not btn.Text:find("ON") then
			problem("MUSIC on again: back up (" .. level .. ")")
		end
	end
	-- someone else's ult: their theme, once yours is over, quieter the further away they are
	setAttr(localPlayer, "UltActive", false)
	task.wait(MU.FadeOut + 0.5)
	playing = VFX.Hooks.MusicState()
	if playing ~= nil then
		problem("ult over: the music should fade out and stop (" .. tostring(playing) .. ")")
	end
	local villain = Instance.new("Player")
	villain.Name = "Shigaraki"
	villain.Parent = Players
	local vChar = makeR15("ShigarakiBody", myRoot.Position + Vector3.new(0, 0, (MU.FullRange + MU.HearRange) / 2))
	villain.Character = vChar
	villain:SetAttribute("Quirk", "Decay")
	villain:SetAttribute("UltActive", true)
	task.wait(MU.FadeIn + 0.6)
	playing, owner, level = VFX.Hooks.MusicState()
	if not (playing == MU.Tracks.Decay.Id and owner == villain and level > 0.05 and level < peak - 0.05) then
		problem(string.format("a villain's ult nearby: their theme, quieter at a distance (%s, %.2f)", tostring(playing), level))
	end
	villain:SetAttribute("UltActive", false)
	task.wait(MU.FadeOut + 0.5)
	villain.Parent = nil
	vChar:Destroy()

	-- I AM HERE: the bubble, the voice line and the crowd
	local cues = {}
	local realPlaySound = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		cues[name] = true
		return realPlaySound(name, ...)
	end
	VFX.Play("MuscleForm", myChar, { Alt = true }, true)
	task.wait(Config.Quirks.OneForAll.Special.Presence.BurstAt + 0.3)
	VFX.PlaySound = realPlaySound
	local bubble
	for _, d in VFX.Folder:GetChildren() do
		if d.Name == "SpeechBubble" then
			bubble = d
		end
	end
	local said = bubble and bubble:FindFirstChildOfClass("TextLabel")
	if not (said and said.Text == Config.Voice.IAmHere.Bubble) then
		problem("muscle form: an I AM HERE! bubble over his head (" .. tostring(said and said.Text) .. ")")
	end
	if not cues.IAmHere then
		problem("muscle form: the crowd should roar (IAmHere cue)")
	end
	local voice = SS:FindFirstChild("Voice_IAmHere")
	if not (voice and voice:IsA("Sound") and voice.SoundId == Config.Voice.IAmHere.Id) then
		problem("muscle form: the I AM HERE clip from the All Might folder plays (round 76: " .. tostring(voice) .. ")")
	end
	-- an uploaded clip wins over text-to-speech
	local idWas76 = Config.Voice.IAmHere.Id
	Config.Voice.IAmHere.Id = "rbxassetid://123"
	local before = #SS:GetChildren()
	VFX.Voice("IAmHere", myRoot)
	local clip
	for _, d in SS:GetChildren() do
		if d:IsA("Sound") and d.SoundId == "rbxassetid://123" then
			clip = d
		end
	end
	if not clip then
		problem("a voice line with an uploaded Id should play that clip (" .. before .. ")")
	end
	Config.Voice.IAmHere.Id = idWas76

	-- the HUD: healing tag, the new name row
	setAttr(myChar, "Regenerating", true)
	task.wait(0.05)
	local regen = hudGui:FindFirstChild("Regen", true)
	if not (regen and regen.Visible) then
		problem("healing out of a fight: the HUD's green tag should show")
	end
	setAttr(myChar, "Regenerating", nil)
	task.wait(0.05)
	if regen and regen.Visible then
		problem("...and hide when it stops")
	end
	HUD.SetQuirk("Explosion", false, false, false)
	local who = hudGui:FindFirstChild("Who", true)
	if not (who and who.Text:find(Config.Quirks.Explosion.DisplayName, 1, true)) then
		problem("the name row should say who you are (" .. tostring(who and who.Text) .. ")")
	end
	HUD.SetUltMeter(100, false)
	local ultLabel
	for _, d in (hudGui:FindFirstChild("UltMeter", true) or hudGui):GetChildren() do
		if d:IsA("TextLabel") then
			ultLabel = d
		end
	end
	if not (ultLabel and ultLabel.Text:find(Config.Quirks.Explosion.Ult.Name, 1, true) and ultLabel.Text:find("READY")) then
		problem("the ult bar is named after your ult, and says when it's ready (" .. tostring(ultLabel and ultLabel.Text) .. ")")
	end
	HUD.SetUltMeter(0, false)
end

print("== round 29: SPIKE FAN draws three short lines")
do
	local SF = Config.Quirks.Overhaul.Abilities[2]
	local lvfx = VFX.Folder
	local before = {}
	for _, m in lvfx and lvfx:GetChildren() or {} do
		before[m] = true
	end
	local origin = myRoot.Position
	VFX.Play("SpikeRush", myChar, { Dir = Vector3.new(0, 0, -1), Origin = origin }, true)
	task.wait(0.25 + 0.03 * (SF.Range / 5) + 0.3)
	local model
	for _, m in lvfx and lvfx:GetChildren() or {} do
		if not before[m] and m.Name == "SpikeRush" then
			model = m
		end
	end
	local left, mid, right, far = 0, 0, 0, 0
	for _, p in model and model:GetChildren() or {} do
		if p.ClassName == "Part" then
			local v = p.CFrame.Position - origin
			v = Vector3.new(v.X, 0, v.Z)
			if v.Magnitude > 14 then
				local ang = math.deg(math.atan2(v.X, -v.Z))
				if ang < -15 then
					left += 1
				elseif ang > 15 then
					right += 1
				elseif math.abs(ang) < 8 then
					mid += 1
				end
			end
			far = math.max(far, v.Magnitude)
		end
	end
	print(string.format("  spikes: %d left, %d middle, %d right, reaching %.0f studs", left, mid, right, far))
	if not model or left == 0 or mid == 0 or right == 0 then
		problem("SPIKE FAN should draw a left, middle and right line of spikes")
	end
	if far > SF.Range + 10 then
		problem("SPIKE FAN lines should stop near " .. SF.Range .. " studs (" .. far .. ")")
	end
end

print("== round 17: item effects, PLUS ULTRA, dev toys")
do
	local foe = makeR15("ItemFoe", Vector3.new(0, 3, -8))
	local function fx(id, data, char)
		VFX.Play(id, char or myChar, data, false)
		task.wait(0.03)
	end
	fx("Soda", { Heal = 40 })
	fx("Scope", { On = true })
	fx("SniperShot", { From = Vector3.new(0, 4, 0), To = Vector3.new(0, 4, -8), Dir = Vector3.new(0, 0, -1), Target = foe, Headshot = true })
	fx("SniperShot", { From = Vector3.new(0, 4, 0), To = Vector3.new(0, 4, -60), Dir = Vector3.new(0, 0, -1) })
	fx("Scope", { On = false })
	fx("BombThrow", { From = Vector3.new(0, 5, 0), Vel = Vector3.new(0, 20, -30), Gravity = 196.2, Land = Vector3.new(0, 1, -6), LandTime = 0.2, Fuse = 0.3 })
	task.wait(0.4)
	fx("BombBoom", { Pos = Vector3.new(0, 1, -6), Radius = 16 })
	fx("HairSmash", { Dir = Vector3.new(0, 0, -1) })
	fx("HairPoof", { Pos = Vector3.new(0, 5, 0) })
	fx("Trigger", { Duration = 0.5 })
	fx("Scarf", { Dir = Vector3.new(0, 0, -1), Target = foe, To = Vector3.new(0, 4, -40) })
	fx("Scarf", { Dir = Vector3.new(0, 0, -1), To = Vector3.new(0, 4, -40) })
	fx("Erased", { Target = foe, Duration = 0.5 })
	fx("Erased", { Target = myChar, Duration = 0.5 })
	fx("GrapeDrop", { Pos = Vector3.new(0, 1, 0) })
	fx("GrapeStick", { Target = foe, Pos = Vector3.new(0, 1, -8), Duration = 0.4 })
	fx("ZeroG", { Duration = 0.5 })
	fx("Rewind", {})
	fx("NewOrder", {})
	fx("NewOrderFloat", { Targets = { foe }, Time = 0.4 })
	fx("NewOrderSlam", { Targets = { foe } })
	fx("MoneyRain", { Pos = Vector3.new(0, 3, 0) })
	fx("Boing", {})
	fx("Launch", { Target = foe })
	task.wait(1.5)
	VFX.CancelCinematic()

	print("== lemillion")
	setAttr(myChar, "Quirk", "Lemillion")
	local fwd = Vector3.new(0, 0, -1)
	VFX.Play("DeepDive", myChar, { Dir = fwd, Pos = Vector3.new(0, 0, -20) }, true)
	fx("DeepDive", { Dir = fwd, Pos = Vector3.new(0, 0, -30) }, foe)
	task.wait(0.8)
	VFX.Play("PhantomMenace", myChar, { Dir = fwd }, true)
	for i = 1, 3 do
		fx("PhantomStrike", { Target = foe, At = Vector3.new(0, 3 + (i == 3 and 4 or 0), -10), Index = i, Last = i == 3 })
	end
	fx("PhantomRush", { Dir = fwd }, foe)
	fx("PhantomMiss", { Dir = fwd })
	VFX.Play("Prediction", myChar, { Dir = fwd }, true)
	fx("PredictionTrigger", { Attacker = foe })
	fx("PredictionTrigger", { Attacker = myChar }, foe)
	fx("PredictionStrike", { Target = foe, At = Vector3.new(0, 3, -4) })
	VFX.Play("Permeate", myChar, {}, true)
	fx("Dodge", { Target = myChar, Phase = true })
	-- the see-through ghost while phasing, and back to normal after
	setAttr(myChar, "Phasing", true)
	task.wait(0.15)
	local torso = myChar:FindFirstChild("Torso") or myChar:FindFirstChild("UpperTorso")
	local glow = VFX.Folder:FindFirstChild("PhaseGlow")
	if not glow or not torso or torso.LocalTransparencyModifier < 0.5 then
		problem("phasing: no ghost look (glow " .. tostring(glow ~= nil) .. ")")
	end
	setAttr(myChar, "Phasing", false)
	setAttr(myChar, "Submerged", true)
	task.wait(0.15)
	if torso and torso.LocalTransparencyModifier < 1 then
		problem("submerged: the body still shows")
	end
	setAttr(myChar, "Submerged", false)
	task.wait(0.8)
	if torso and torso.LocalTransparencyModifier ~= 0 then
		problem("after phasing the body stays see-through (" .. torso.LocalTransparencyModifier .. ")")
	end
	if VFX.Folder:FindFirstChild("PhaseGlow") then
		problem("the phase outline outlived the phasing")
	end
	VFX.Play("MillionPunch", myChar, { Dir = fwd, Pos = Vector3.new(0, 0, -25) }, true)
	fx("MillionPunchRise", { Pos = Vector3.new(0, 0, -25), Target = foe })
	fx("MillionPunchDrop", { Target = foe, At = Vector3.new(0, 12, -24) })
	fx("MillionPunchImpact", { Pos = Vector3.new(0, 0, -25) })
	task.wait(2.2)
	VFX.CancelCinematic()
	setAttr(myChar, "Quirk", nil)

	print("== disco party")
	setAttr(workspace, "DiscoCenter", Vector3.new(0, 3, 0))
	setAttr(workspace, "Disco", true)
	task.wait(1.2)
	local party = VFX.Folder:FindFirstChild("DiscoParty")
	if not party then
		problem("disco party didn't start")
	elseif not party:FindFirstChildWhichIsA("Sound", true) then
		problem("disco party has no music")
	end
	setAttr(workspace, "Disco", false)
	task.wait(0.1)
	if VFX.Folder:FindFirstChild("DiscoParty") then
		problem("disco party didn't stop")
	end
	foe:Destroy()
end

print("== round 17: bucks, item bar, shop")
do
	local Shop = remotes:FindFirstChild("Shop")
	local gui = playerGui:FindFirstChild("QuirkHUD")
	local wallet = gui:FindFirstChild("Wallet")
	setAttr(localPlayer, "Bucks", 25)
	task.wait(0.05)
	local amount
	for _, d in wallet and wallet:GetChildren() or {} do
		if d:IsA("TextLabel") and d.Text == "25" then
			amount = d
		end
	end
	if not amount then
		problem("wallet doesn't show 25 bucks")
	end
	setAttr(localPlayer, "Item_Soda", 2)
	setAttr(localPlayer, "Item_Bomb", 1)
	task.wait(0.05)
	local bar = gui:FindFirstChild("Items")
	local shown = 0
	for _, b in bar and bar:GetChildren() or {} do
		if b:IsA("TextButton") and b.Visible then
			shown += 1
		end
	end
	if shown ~= 2 then
		problem("item bar should show 2 items (shows " .. shown .. ")")
	end
	-- the shop: B opens it, a card buys
	actions.QuirkShop("QuirkShop", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
	local shop = gui:FindFirstChild("Shop")
	if not (shop and shop.Visible) then
		problem("B didn't open the shop")
	end
	table.clear(fired)
	shop:FindFirstChild("Soda", true).MouseButton1Click:Fire()
	task.wait(0.05)
	local bought = false
	for _, f in fired do
		if f[1] == "Shop" and f[2] == "Buy" and f[3] == "Soda" then
			bought = true
		end
	end
	if not bought then
		problem("clicking a shop card doesn't buy")
	end
	PlayVFX.OnClientEvent:Fire("ShopResult", nil, { Ok = true, Item = "Soda" })
	PlayVFX.OnClientEvent:Fire("ShopResult", nil, { Ok = false, Item = "Bomb", Text = "Not enough Bucks" })
	actions.QuirkShop("QuirkShop", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B })
	if shop.Visible then
		problem("H didn't close the shop")
	end
	-- 5 uses the first item in the bag (4 is the 4th move now)
	table.clear(fired)
	signalOf(uis, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Five }, false)
	task.wait(0.05)
	local used = false
	for _, f in fired do
		if f[1] == "Shop" and f[2] == "Use" and f[3] == "Soda" and typeof(f[4]) == "Vector3" then
			used = true
		end
	end
	if not used then
		problem("pressing 5 doesn't use the first item")
	end
	PlayVFX.OnClientEvent:Fire("KOConfirm", nil, { Victim = "Other", Streak = 1, Counted = true, Heal = 30, Bucks = 5 })
	setAttr(localPlayer, "Bucks", 30)

	print("== round 17: controller (JJS layout)")
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Gamepad1)
	task.wait(0.05)
	local slot1 = gui:FindFirstChild("Slot1", true)
	local key1 = slot1 and slot1:FindFirstChildOfClass("TextLabel")
	if not (key1 and key1.Text == "LB") then
		problem("controller: move 1 should say LB (says " .. tostring(key1 and key1.Text) .. ")")
	end
	local pad = { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.DPadRight }
	-- D-pad right: tap uses, hold picks the next item
	table.clear(fired)
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.Begin, pad)
	task.wait(0.05)
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.End, pad)
	local tapUse = 0
	for _, f in fired do
		if f[1] == "Shop" and f[2] == "Use" then
			tapUse += 1
		end
	end
	if tapUse ~= 1 then
		problem("tapping D-pad right should use the item (" .. tapUse .. ")")
	end
	table.clear(fired)
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.Begin, pad)
	task.wait(0.5)
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.End, pad)
	for _, f in fired do
		if f[1] == "Shop" then
			problem("holding D-pad right should pick, not use")
		end
	end
	-- with the shop open, the buttons belong to the menu (B closes it)
	actions.QuirkShop("QuirkShop", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonSelect })
	if not HUD.ShopVisible() then
		problem("SELECT didn't open the shop")
	end
	table.clear(fired)
	local res = actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonL1 })
	if res ~= Enum.ContextActionResult.Pass or #fired > 0 then
		problem("with the shop open, LB should pass through to the menu")
	end
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonB })
	if HUD.ShopVisible() then
		problem("B should close the shop on a controller")
	end
	-- LB fires move 1
	localPlayer:SetAttribute("Quirk", "Explosion")
	table.clear(fired)
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonL1 })
	task.wait(0.05)
	local lb = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == 1 then
			lb = true
		end
	end
	if not lb then
		problem("LB should use move 1")
	end
	-- push the stick all the way: sprint
	stickPos = Vector3.new(0, 1, 0)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(Config.Movement.Feel.RunBuild + 0.25) -- (the run builds up)
	local base = myChar:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	if math.abs(myHum.WalkSpeed - base * Config.Movement.SprintMultiplier) > 0.01 then
		problem(string.format("full stick should sprint (walk speed %.1f)", myHum.WalkSpeed))
	end
	stickPos = Vector3.zero
	myHum.MoveDirection = Vector3.zero
	task.wait(0.05)
	signalOf(uis, "LastInputTypeChanged"):Fire(Enum.UserInputType.Keyboard)

	print("== round 17: lock-on, scope, erased")
	local look = cam.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	local foe = makeR15("LockFoe", myRoot.Position + look * 10)
	local dummyFolder = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
	dummyFolder.Name = "Dummies"
	dummyFolder.Parent = workspace
	foe.Parent = dummyFolder
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.T })
	local marker = playerGui:FindFirstChild("LockOnMarker")
	if not (marker and marker.Enabled) then
		problem("T should lock on to the enemy in front")
	end
	task.wait(3.5) -- (move 1's cooldown)
	table.clear(fired)
	actions.QuirkAbility2("QuirkAbility2", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Two })
	task.wait(0.05)
	local aimed = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == 2 and typeof(f[4]) == "Vector3" and (f[4] - foe.HumanoidRootPart.Position).Magnitude < 0.1 then
			aimed = true
		end
	end
	if not aimed then
		problem("locked on: moves should aim at the target")
	end
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.T })
	if marker.Enabled then
		problem("T again should let go")
	end
	-- round 29: jammed by Radio Waves - the lock-on drops, static covers the
	-- screen, and T won't lock on again until the jam clears
	local T = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.T }
	local function foeInFront()
		local lv = cam.CFrame.LookVector
		lv = Vector3.new(lv.X, 0, lv.Z)
		lv = lv.Magnitude > 0.05 and lv.Unit or Vector3.new(0, 0, -1)
		foe.HumanoidRootPart.CFrame = r.CFrame.new(myRoot.Position + lv * 10)
		foe.HumanoidRootPart.Position = myRoot.Position + lv * 10 -- (the mock keeps these apart)
	end
	foeInFront()
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, T)
	if not marker.Enabled then
		problem("(T should lock on again before the jam)")
	end
	myChar:SetAttribute("JammedUntil", workspace:GetServerTimeNow() + 0.6)
	PlayVFX.OnClientEvent:Fire("Jammed", nil, { Duration = 0.6 })
	task.wait(0.1)
	if marker.Enabled then
		problem("jammed: the lock-on should drop")
	end
	local flashGui = playerGui:FindFirstChild("QuirkFlash")
	local jamFrame = flashGui and flashGui:FindFirstChild("Jam")
	if not (jamFrame and jamFrame:FindFirstChildOfClass("TextLabel")) then
		problem("jammed: static and SIGNAL JAMMED over the screen")
	end
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, T)
	if marker.Enabled then
		problem("jammed: T shouldn't lock on")
	end
	task.wait(0.8)
	if flashGui:FindFirstChild("Jam") then
		problem("the static should clear when the jam ends")
	end
	foeInFront()
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, T)
	if not marker.Enabled then
		problem("after the jam, T locks on again")
	end
	actions.QuirkLockOn("QuirkLockOn", Enum.UserInputState.Begin, T)
	myChar:SetAttribute("JammedUntil", nil)
	-- the scope: first person, and a click fires
	PlayVFX.OnClientEvent:Fire("Scope", myChar, { On = true })
	task.wait(0.1)
	local scope = gui:FindFirstChild("Scope")
	if not (scope and scope.Visible) or localPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		problem("scoping in should show the scope in first person")
	end
	table.clear(fired)
	signalOf(uis, "InputBegan"):Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
	task.wait(0.05)
	local shot = false
	for _, f in fired do
		if f[1] == "Shop" and f[2] == "Fire" then
			shot = true
		end
	end
	if not shot then
		problem("clicking while scoped should fire the sniper")
	end
	PlayVFX.OnClientEvent:Fire("Scope", myChar, { On = false })
	task.wait(0.1)
	if scope.Visible or localPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
		problem("scoping out should put the camera back")
	end
	-- erased: the quirk is off
	myChar:SetAttribute("ErasedUntil", os.clock() + 5)
	task.wait(3)
	table.clear(fired)
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.One })
	for _, f in fired do
		if f[1] == "UseAbility" then
			problem("an erased player shouldn't be able to use their quirk")
		end
	end
	myChar:SetAttribute("ErasedUntil", nil)
	PlayVFX.OnClientEvent:Fire("CooldownReset", nil, { Keep = "Explosion:S" })
	foe:Destroy()
	-- the FUN STUFF panel
	HUD.BuildFunPanel({ { Id = "MoneyPrinter", Label = "Money Printer" } }, function(id)
		remotes:FindFirstChild("TestCommand"):FireServer(id)
	end)
	HUD.ToggleFunPanel(true)
	local fun = gui:FindFirstChild("FunStuff")
	if not (fun and fun.Visible) then
		problem("fun panel didn't open")
	end
	table.clear(fired)
	fun:FindFirstChild("MoneyPrinter").MouseButton1Click:Fire()
	task.wait(0.05)
	if not (fired[1] and fired[1][1] == "TestCommand" and fired[1][2] == "MoneyPrinter") then
		problem("fun panel buttons should send their test command")
	end
	HUD.ToggleTestMenu(false)
	if fun.Visible then
		problem("closing the test menu should close the fun panel")
	end
end

print("== round 18: food, snack machines, Tony")
do
	local gui = playerGui:FindFirstChild("QuirkHUD")
	-- a snack machine and Tony, built the way the server builds them
	local shops = Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = workspace
	local machine = Instance.new("Model")
	machine.Name = "SnackMachine"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 6.4, 3)
	body.CFrame = r.CFrame.new(20, 3.2, 0)
	body.Parent = machine
	local glass = Instance.new("Part")
	glass.CFrame = r.CFrame.new(20, 4, -1.5)
	glass.Parent = machine
	machine.Parent = shops
	local tony = makeR6("Tony", Vector3.new(30, 3, 0))
	tony.Parent = shops
	for _, id in Config.ItemOrder do
		if Config.Items[id].Heal then
			VFX.Play("Eat", myChar, { Item = id, Heal = Config.Items[id].Heal }, false)
			task.wait(0.03)
		end
	end
	VFX.Play("Vend", nil, { Machine = machine, Item = "Chips" }, false)
	VFX.Play("MachineHit", nil, { Machine = machine }, false)
	VFX.Play("SnackDrop", nil, { Machine = machine, Pos = Vector3.new(20, 0.5, -6), Item = "CandyBar" }, false)
	VFX.Play("NpcSay", nil, { Npc = tony, Text = "Ay, a hero! What'll it be?" }, false)
	task.wait(0.8)
	if (body.CFrame.Position - Vector3.new(20, 3.2, 0)).Magnitude > 1e-3 then
		problem("the machine didn't settle back after rattling")
	end
	-- Tony's menu
	local tonyRoot = tony:FindFirstChild("HumanoidRootPart")
	myRoot.CFrame = r.CFrame.new(tonyRoot.Position + Vector3.new(0, 0, 6))
	myRoot.Position = myRoot.CFrame.Position
	setAttr(localPlayer, "Bucks", 7)
	PlayVFX.OnClientEvent:Fire("VendorMenu", nil, { Vendor = "Pizza", Npc = tony, Line = "Welcome to Tony's!" })
	task.wait(0.1)
	local vendor = gui:FindFirstChild("Vendor")
	if not (vendor and vendor.Visible) then
		problem("Tony's menu didn't open")
	end
	local rows = 0
	for _, d in vendor and vendor:GetDescendants() or {} do
		if d:IsA("TextButton") and Config.Items[d.Name] then
			rows += 1
		end
	end
	if rows ~= #Config.PizzaParlor.Menu then
		problem("Tony's menu should list " .. #Config.PizzaParlor.Menu .. " things (" .. rows .. ")")
	end
	table.clear(fired)
	vendor:FindFirstChild("PizzaSlice", true).MouseButton1Click:Fire()
	task.wait(0.05)
	if not (fired[1] and fired[1][1] == "Shop" and fired[1][2] == "Buy" and fired[1][3] == "PizzaSlice" and fired[1][4] == "Pizza") then
		problem("ordering a slice should ask the server (with the vendor)")
	end
	PlayVFX.OnClientEvent:Fire("NpcSay", nil, { Npc = tony, Text = "Mangia!" })
	PlayVFX.OnClientEvent:Fire("ShopResult", nil, { Ok = true, Item = "PizzaSlice" })
	PlayVFX.OnClientEvent:Fire("ShopResult", nil, { Ok = true, Item = "WholePizza", Ate = true })
	PlayVFX.OnClientEvent:Fire("ShopResult", nil, { Ok = false, Item = "WholePizza", Text = Config.PizzaParlor.Broke })
	task.wait(0.1)
	local said = false
	for _, d in vendor:GetDescendants() do
		if d:IsA("TextLabel") and d.Text:find(Config.PizzaParlor.Broke, 1, true) then
			said = true
		end
	end
	if not said then
		problem("the menu should show what Tony just said")
	end
	-- walk off: it closes
	myRoot.CFrame = r.CFrame.new(tonyRoot.Position + Vector3.new(0, 0, 80))
	myRoot.Position = myRoot.CFrame.Position
	for _ = 1, 3 do
		signalOf(game:GetService("RunService"), "Heartbeat"):Fire(1 / 60)
		task.wait(0.05)
	end
	if vendor.Visible then
		problem("walking away from Tony should close his menu")
	end
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	-- E / D-pad right press the prompt you're standing at
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = body
	signalOf(game:GetService("ProximityPromptService"), "PromptShown"):Fire(prompt)
	task.wait(0.05)
	promptPresses = 0
	actions.QuirkFinish("QuirkFinish", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.E })
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.DPadRight })
	actions.QuirkUseItem("QuirkUseItem", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.DPadRight })
	task.wait(0.1)
	if promptPresses ~= 2 then
		problem("E and D-pad right should press the snack machine's prompt (" .. promptPresses .. ")")
	end
	signalOf(game:GetService("ProximityPromptService"), "PromptHidden"):Fire(prompt)
	shops:Destroy()
end

print("== round 21: M1 finishers, the jump hold, turning after a dash")
local okR21, errR21 = pcall(function()
	localPlayer:SetAttribute("Quirk", "Explosion")
	myRoot.AssemblyMass = 12
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myHum.FloorMaterial = Enum.Material.Plastic
	-- a dash hands turning back to the Humanoid (shift lock had it off)
	myHum.AutoRotate = false
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.05)
	actions.QuirkDash("QuirkDash", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.55)
	if myHum.AutoRotate ~= true then
		problem("after a dash the body should turn freely again (stuck facing one way)")
	end
	local function punch()
		table.clear(fired)
		myRoot.AssemblyLinearVelocity = Vector3.zero -- (round 84: no gravity here - the top of any hop)
		actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
		actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
		task.wait(Config.M1.Cooldown + 0.05)
		local f = fired[#fired]
		return f and f[1] == "UseAbility" and f[2] == 0 and f, f and f[4]
	end
	local function chain3()
		task.wait(Config.M1.ComboReset + 0.1)
		for _ = 1, 3 do
			punch()
		end
	end
	-- (round 63) held jump through the chain: no hop, and the 4th is an
	-- UPSLAM that keeps you on your feet (still no hop until you let go)
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end)
	task.wait(Config.M1.ComboReset + 0.1)
	punch()
	punch()
	keysDown.Space = true
	task.wait(0.05)
	if jumpStateEnabled then
		problem("holding jump mid-chain should not hop you (charging the upslam)")
	end
	punch()
	task.wait(0.05)
	if jumpStateEnabled then
		problem("...and still held through the 3rd hit it keeps charging")
	end
	local sent, variant = punch()
	if not sent or variant ~= "Up" then
		problem("jump held into the 4th hit should send an upslam (" .. tostring(variant) .. ")")
	end
	task.wait(0.15)
	if jumpStateEnabled then
		problem("UPSLAM: you stay on your feet while jump's still held (round 63)")
	end
	keysDown.Space = nil
	task.wait(0.05)
	if not jumpStateEnabled then
		problem("...and jumping comes back once you let go")
	end
	-- (round 63) pressed AFTER the 3rd hit and clicked straight away: still the upslam, no hop
	chain3()
	table.clear(changedStates)
	keysDown.Space = true
	task.wait(0.03)
	sent, variant = punch()
	if not sent or variant ~= "Up" or table.find(changedStates, "Jumping") then
		problem("jump pressed after the 3rd hit, the 4th thrown right away: an upslam, no hop (" .. tostring(variant) .. ")")
	end
	keysDown.Space = nil
	task.wait(0.05)
	-- a TAP after the 3rd hit: the hop, as you let go (the way into a downslam)
	chain3()
	table.clear(changedStates)
	keysDown.Space = true
	task.wait(0.04)
	keysDown.Space = nil
	task.wait(0.05)
	if not table.find(changedStates, "Jumping") then
		problem("a tap of jump after the 3rd hit should hop you as you let go (downslam setup)")
	end
	-- (round 75) held after the 3rd hit, no click: up you go as soon as the
	-- swing lets you - no waiting to let go - and the 4th is the downslam
	chain3()
	table.clear(changedStates)
	keysDown.Space = true
	task.wait(0.4)
	if not table.find(changedStates, "Jumping") then
		problem("jump held after the 3rd hit: the hop goes straight away, no waiting for the let-go (round 75)")
	end
	sent, variant = punch()
	if not sent or variant ~= "Down" then
		problem("...and the 4th thrown then is the downslam (" .. tostring(variant) .. ")")
	end
	keysDown.Space = nil
	task.wait(0.05)
	-- held with the chain left to run out: an ordinary jump again
	chain3()
	table.clear(changedStates)
	keysDown.Space = true
	task.wait(0.1)
	if not table.find(changedStates, "Jumping") then
		problem("jump held mid-chain: the hop goes (round 75)")
	end
	task.wait(Config.M1.ComboReset + 0.1)
	if jumpStateEnabled then
		problem("...the chain's run out, still holding the press that hopped you: no second jump (round 84)")
	end
	keysDown.Space = nil
	task.wait(0.05)
	if not jumpStateEnabled then
		problem("...let go: it's a jump again")
	end
	task.wait(Config.M1.ComboReset + 0.1)
	-- no jump: the plain 4th hit
	chain3()
	sent, variant = punch()
	if not sent or variant ~= nil then
		problem("the 4th hit with no jump should be the normal finisher (" .. tostring(variant) .. ")")
	end
	-- in the air: a downslam
	chain3()
	myHum.FloorMaterial = Enum.Material.Air
	myRoot.CFrame = r.CFrame.new(0, 10, 0)
	myRoot.Position = Vector3.new(0, 10, 0)
	sent, variant = punch()
	if not sent or variant ~= "Down" then
		problem("the 4th hit in the air should send a downslam (" .. tostring(variant) .. ")")
	end
	-- (round 63) just off the ground is enough now: a foot up...
	chain3()
	myRoot.CFrame = r.CFrame.new(0, 4, 0)
	myRoot.Position = Vector3.new(0, 4, 0)
	sent, variant = punch()
	if not sent or variant ~= "Down" then
		problem("a foot off the ground is enough for a downslam now (" .. tostring(variant) .. ")")
	end
	-- ...but not a few inches (still on the street, really)
	chain3()
	myRoot.CFrame = r.CFrame.new(0, 3.15, 0)
	myRoot.Position = Vector3.new(0, 3.15, 0)
	sent, variant = punch()
	if not sent or variant == "Down" then
		problem("a couple of inches up isn't a downslam (round 75: " .. Config.M1.DownslamHeight .. " studs is)")
	end
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	setRaycast(nil)
	-- the effects play for every variant and both styles
	for _, q in { "Explosion", "Engine" } do
		setAttr(myChar, "Quirk", q)
		for _, v in { "Up", "Down" } do
			VFX.Play("Punch", myChar, { Count = 4, Finisher = true, Variant = v }, true)
			task.wait(0.35)
		end
	end
	setAttr(myChar, "Quirk", nil)
	VFX.Play("Downslam", nil, { Pos = Vector3.new(0, 0, -6), Target = myChar }, false)
	-- St. Louis Smash, aimed up
	setAttr(myChar, "Quirk", "FullCowl")
	VFX.Play("StLouisSmash", myChar, { Dir = Vector3.new(0, 0.7, -0.7).Unit, Pos = Vector3.new(0, 20, -20) }, true)
	task.wait(0.5)
	setAttr(myChar, "Quirk", nil)
	localPlayer:SetAttribute("Quirk", nil)
end)
if not okR21 then
	problem("round 21 scenario crashed: " .. tostring(errR21))
end

print("== round 84: THE SLAM JUMP GOES ON THE PRESS")
local ok84j, err84j = pcall(function()
	localPlayer:SetAttribute("Quirk", "Explosion")
	setAttr(myChar, "Quirk", "Explosion")
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myHum.FloorMaterial = Enum.Material.Plastic
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end)
	local function click()
		actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
		actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Unknown })
	end
	local function punch()
		table.clear(fired)
		click()
		task.wait(Config.M1.Cooldown + 0.05)
	end
	local function lastM1()
		for i = #fired, 1, -1 do
			local f = fired[i]
			if f[1] == "UseAbility" and f[2] == 0 then
				return f, f[4]
			end
		end
		return nil
	end
	local function hopped()
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == Config.PARKOUR_INDEX and f[3] == "SlamHop" then
				return true
			end
		end
		return false
	end
	-- (the harness has no gravity: an earlier test's upward speed would
	-- hang on forever, and the downslam waits for the top of the hop)
	local function still()
		myRoot.AssemblyLinearVelocity = Vector3.zero
	end
	local function reset()
		keysDown.Space = nil
		still()
		task.wait(0.1)
		task.wait(Config.M1.ComboReset + 0.1)
	end
	local SL = Config.M1.Slam

	-- 1. Space after hit 3 (its swing done): up you go on the press - no
	-- waiting for the let-go - and the 4th then is the downslam
	reset()
	punch()
	punch()
	punch()
	table.clear(changedStates)
	table.clear(fired)
	keysDown.Space = true
	task.wait(SL.PressGrace + 0.06)
	if not (table.find(changedStates, "Jumping") and hopped()) then
		problem("SLAM 84: Space after hit 3 hops you on the press, still held (" .. tostring(table.find(changedStates, "Jumping")) .. ")")
	end
	still() -- (the top of the hop)
	table.clear(fired)
	click()
	task.wait(0.3)
	local f, variant = lastM1()
	if not f or variant ~= "Down" then
		problem("SLAM 84: ...and the 4th is the downslam (" .. tostring(variant) .. ")")
	end
	-- one press, one jump: still held once you're down, it doesn't jump you again
	task.wait(0.6)
	if jumpStateEnabled then
		problem("SLAM 84: still holding the press that hopped you: no second jump")
	end
	keysDown.Space = nil
	task.wait(0.05)
	if not jumpStateEnabled then
		problem("SLAM 84: ...let go and jumping's back")
	end

	-- 2. pressed during hit 3's swing: the hop the moment the swing (on your
	-- own screen) lets you - not when the server's late copy of it ends
	reset()
	punch()
	punch()
	table.clear(changedStates)
	table.clear(fired)
	click()
	local clickAt = os.clock()
	setAttr(myChar, "CombatActionUntil", workspace:GetServerTimeNow() + 0.7) -- (the server's copy, a ping late)
	task.wait(0.03)
	keysDown.Space = true
	task.wait(0.05)
	if table.find(changedStates, "Jumping") then
		problem("SLAM 84: pressed in hit 3's swing - not before the swing's done")
	end
	task.wait(math.max((Config.M1.ActionTime or 0.18) + SL.PressGrace + 0.1 - (os.clock() - clickAt), 0))
	if not (table.find(changedStates, "Jumping") and hopped()) then
		problem(string.format("SLAM 84: ...hops as soon as the swing ends on your screen (%.2fs after the click), not the server's copy", os.clock() - clickAt))
	end
	setAttr(myChar, "CombatActionUntil", nil)

	-- 3. held through hit 3's swing with the 4th clicked into it: the upslam
	-- (the input buffer runs on Heartbeat, which the harness doesn't drive:
	-- driven here)
	local hb84 = true
	task.spawn(function()
		local rs = game:GetService("RunService")
		while hb84 do
			signalOf(rs, "Heartbeat"):Fire(1 / 60)
			task.wait(1 / 60)
		end
	end)
	reset()
	punch()
	punch()
	table.clear(changedStates)
	table.clear(fired)
	click()
	task.wait(0.03)
	keysDown.Space = true
	task.wait(0.05)
	click() -- (the 4th, early: kept for the upslam)
	task.wait((Config.M1.Cooldown or 0.3) + 0.15)
	f, variant = lastM1()
	if table.find(changedStates, "Jumping") or hopped() or not f or variant ~= "Up" then
		problem("SLAM 84: Space held through hit 3's swing with the 4th clicked into it: the upslam, no hop (" .. tostring(variant) .. ")")
	end
	keysDown.Space = nil
	hb84 = false

	-- 4. still the upslam: Space held from before hit 3 (round 83)
	reset()
	punch()
	keysDown.Space = true
	task.wait(0.05)
	punch()
	punch()
	table.clear(changedStates)
	table.clear(fired)
	click()
	task.wait(0.15)
	f, variant = lastM1()
	if table.find(changedStates, "Jumping") or not f or variant ~= "Up" then
		problem("SLAM 84: held from before hit 3: never a hop, the upslam (" .. tostring(variant) .. ")")
	end
	keysDown.Space = nil

	-- 5. a tap after hit 1 and no more clicks: you jump out of the chain
	-- soon after the next hit was due (ArmWait), not much later
	reset()
	punch()
	local hit1 = os.clock() - (Config.M1.Cooldown + 0.05)
	table.clear(changedStates)
	keysDown.Space = true
	task.wait(0.05)
	keysDown.Space = nil
	local due = hit1 + Config.M1.Cooldown + SL.ArmWait + 0.08
	task.wait(math.max(due - os.clock(), 0))
	if not table.find(changedStates, "Jumping") then
		problem(string.format("SLAM 84: a tap after hit 1 with no more clicks jumps by %.2fs after it (ArmWait %.2f)", os.clock() - hit1, SL.ArmWait))
	end
	reset()

	-- 6. jammed by Radio Waves: the quirk's moves don't go (M1s do)
	setAttr(myChar, "JammedUntil", workspace:GetServerTimeNow() + 1)
	table.clear(fired)
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.Begin, {})
	actions.QuirkAbility1("QuirkAbility1", Enum.UserInputState.End, {})
	task.wait(0.1)
	for _, ff in fired do
		if ff[1] == "UseAbility" and ff[2] == 1 then
			problem("JAM 84: jammed, a move doesn't go")
		end
	end
	setAttr(myChar, "JammedUntil", nil)
	setRaycast(nil)
	localPlayer:SetAttribute("Quirk", nil)
	setAttr(myChar, "Quirk", nil)
end)
if not ok84j then
	problem("round 84 slam jump tests errored: " .. tostring(err84j))
end


print("== parkour, player-driven (round 27): jump vaults/climbs, dash slides, one press per wall hop")
local okR22, errR22 = pcall(function()
	-- a little world made of boxes, and a ray caster for it
	local boxes = {}
	local stone = Instance.new("Part")
	stone.Transparency = 0
	local function box(center, size)
		table.insert(boxes, { lo = center - size / 2, hi = center + size / 2 })
	end
	local function rayBox(o, d, b)
		local tmin, tmax, axisN = -math.huge, math.huge, nil
		for _, ax in { "X", "Y", "Z" } do
			local oo, dd, lo, hi = o[ax], d[ax], b.lo[ax], b.hi[ax]
			if math.abs(dd) < 1e-9 then
				if oo < lo or oo > hi then
					return nil
				end
			else
				local t1, t2 = (lo - oo) / dd, (hi - oo) / dd
				local sign = -1
				if t1 > t2 then
					t1, t2 = t2, t1
					sign = 1
				end
				if t1 > tmin then
					tmin = t1
					local n = { X = 0, Y = 0, Z = 0 }
					n[ax] = (dd > 0) and -1 or 1
					axisN = Vector3.new(n.X, n.Y, n.Z)
				end
				tmax = math.min(tmax, t2)
				local _ = sign
			end
		end
		if tmin < 0 or tmin > tmax or tmin > 1 then
			return nil -- (starting inside a box counts as no hit)
		end
		return tmin, axisN
	end
	setRaycast(function(_, origin, dir)
		local best, bestN
		for _, b in boxes do
			local t, n = rayBox(origin, dir, b)
			if t and (not best or t < best) then
				best, bestN = t, n
			end
		end
		if not best then
			return nil
		end
		return { Position = origin + dir * best, Normal = bestN, Instance = stone, Distance = dir.Magnitude * best }
	end)
	-- (round 68) the body-sized box parkour sweeps along its path, through
	-- the same boxes (a box it starts inside doesn't count, as in Roblox)
	blockcastImpl68 = function(cf, size, dir)
		local half = size / 2
		local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(rx.X) * half.X + math.abs(ry.X) * half.Y + math.abs(rz.X) * half.Z,
			math.abs(rx.Y) * half.X + math.abs(ry.Y) * half.Y + math.abs(rz.Y) * half.Z,
			math.abs(rx.Z) * half.X + math.abs(ry.Z) * half.Y + math.abs(rz.Z) * half.Z)
		local function overlaps(c, b)
			return c.X + ext.X > b.lo.X and c.X - ext.X < b.hi.X and c.Y + ext.Y > b.lo.Y and c.Y - ext.Y < b.hi.Y
				and c.Z + ext.Z > b.lo.Z and c.Z - ext.Z < b.hi.Z
		end
		local start = cf.Position
		for i = 1, 12 do
			local c = start + dir * (i / 12)
			for _, b in boxes do
				if not overlaps(start, b) and overlaps(c, b) then
					return { Position = c, Normal = -dir.Unit, Instance = stone, Distance = dir.Magnitude * i / 12 }
				end
			end
		end
		return nil
	end
	local function reset(world)
		table.clear(boxes)
		box(Vector3.new(0, -1, 0), Vector3.new(2000, 2, 2000)) -- the street
		for _, b in world or {} do
			box(b[1], b[2])
		end
	end
	local function place(pos, look)
		myRoot.CFrame = r.CFrame.lookAt(pos, pos + look)
		myRoot.Position = pos
		myRoot.AssemblyLinearVelocity = Vector3.zero
	end
	local function parkourSent()
		local kinds = {}
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == Config.PARKOUR_INDEX then
				table.insert(kinds, f[3])
			end
		end
		return kinds
	end
	local fwd = Vector3.new(0, 0, -1)
	localPlayer:SetAttribute("Quirk", "Explosion")
	myRoot.AssemblyMass = 12
	myHum.MaxHealth, myHum.Health = 200, 200
	myHum.FloorMaterial = Enum.Material.Plastic
	-- run (hold Left Ctrl) forward
	actions.QuirkSprint("QuirkSprint", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftControl })
	myHum.MoveDirection = fwd
	-- (the press: jump for vaults / climbs / run-ups, dash for slides)
	local function press(how)
		if how == "Dash" then
			actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
		else
			keysDown.Space = true
			task.wait(0.05)
			keysDown.Space = nil
		end
	end
	local function runInto(world, label, want, check, how)
		reset(world)
		place(Vector3.new(0, 3, 0), fwd)
		table.clear(fired)
		task.wait(0.15)
		press(how)
		task.wait(0.65)
		local kinds = parkourSent()
		if kinds[1] ~= want then
			problem(label .. ": expected " .. want .. ", got " .. tostring(kinds[1]))
		elseif check then
			check()
		end
		task.wait(0.4)
	end
	-- a low wall, thin: over it
	runInto({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) } }, "a low wall", "Vault", function()
		if myRoot.CFrame.Position.Z > -4 then
			problem("the vault should land past the wall (z " .. math.floor(myRoot.CFrame.Position.Z * 10) / 10 .. ")")
		end
	end)
	-- a ledge 10 up: climb onto it
	runInto({ { Vector3.new(0, 5, -4), Vector3.new(6, 10, 3) } }, "a 10-stud ledge", "Climb", function()
		local p = myRoot.CFrame.Position
		if p.Y < 12 or p.Z > -3 then
			problem("the climb should end standing on top (" .. tostring(p) .. ")")
		end
	end)
	-- a low but deep block: onto it
	runInto({ { Vector3.new(0, 1.5, -6), Vector3.new(6, 3, 7) } }, "a low deep block", "Mantle")
	-- a wall too tall to top out: run up it
	runInto({ { Vector3.new(0, 20, -4), Vector3.new(6, 40, 3) } }, "a tall wall", "WallUp", function()
		if myRoot.CFrame.Position.Y < 10 then
			problem("running up a tall wall should gain height (y " .. myRoot.CFrame.Position.Y .. ")")
		end
	end)
	-- a bar with room beneath: dash under it
	runInto({ { Vector3.new(0, 4, -3.2), Vector3.new(6, 2, 1.2) } }, "a bar at head height", "Slide", function()
		if myRoot.CFrame.Position.Z > -4 then
			problem("the slide should come out past the bar")
		end
	end, "Dash")
	task.wait(Config.Movement.DashCooldown)
	-- (round 68) NEVER THROUGH A WALL: whatever it does, no frame of it puts
	-- the body (torso and head) inside anything solid
	local function intoWall(world, label, how)
		reset(world)
		place(Vector3.new(0, 3, 0), fwd)
		table.clear(fired)
		task.wait(0.15)
		local worst, t0 = 0, os.clock()
		local watching = true
		task.spawn(function()
			while watching do
				local c = myRoot.CFrame.Position + Vector3.new(0, 0.45, 0)
				for i = 2, #boxes do -- (not the street)
					local b = boxes[i]
					local dx = math.min(c.X + 0.55, b.hi.X) - math.max(c.X - 0.55, b.lo.X)
					local dy = math.min(c.Y + 1.25, b.hi.Y) - math.max(c.Y - 1.25, b.lo.Y)
					local dz = math.min(c.Z + 0.35, b.hi.Z) - math.max(c.Z - 0.35, b.lo.Z)
					if dx > 0 and dy > 0 and dz > 0 then
						worst = math.max(worst, math.min(dx, dy, dz))
					end
				end
				task.wait()
			end
		end)
		press(how)
		task.wait(0.9)
		watching = false
		if worst > 0.05 then
			problem(string.format("PARKOUR 68: %s - went %.2f studs into the wall (%s)", label, worst, table.concat(parkourSent(), ",")))
		end
		task.wait(0.4)
		return parkourSent()
	end
	-- a low wall with a beam right over it: no vault through the beam
	local k1 = intoWall({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) }, { Vector3.new(0, 6.2, -4), Vector3.new(6, 1.4, 4) } }, "a vault under a beam")
	if k1[1] == "Vault" then
		problem("PARKOUR 68: no room over the wall (a beam): no vault")
	end
	-- a ledge with a slab over it (it climbs on up onto the slab: never into it)
	intoWall({ { Vector3.new(0, 5, -4), Vector3.new(6, 10, 3) }, { Vector3.new(0, 12.6, -5.5), Vector3.new(6, 1.2, 6) } }, "a climb under an overhang")
	-- a low wall with the building straight behind it: no vault into it
	intoWall({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) }, { Vector3.new(0, 10, -5.2), Vector3.new(6, 20, 1.6) } }, "a vault into the building behind")
	-- the plain vault and climb still go (the sweep finds nothing in the way)
	runInto({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) } }, "(round 68, swept) a low wall", "Vault")
	runInto({ { Vector3.new(0, 5, -4), Vector3.new(6, 10, 3) } }, "(round 68, swept) a 10-stud ledge", "Climb")
	-- running into a low wall WITHOUT pressing anything: nothing - it's up to you
	reset({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) } })
	place(Vector3.new(0, 3, 0), fwd)
	table.clear(fired)
	task.wait(0.6)
	if #parkourSent() > 0 then
		problem("running into a wall without pressing jump shouldn't parkour by itself: " .. table.concat(parkourSent(), ","))
	end
	-- or a bar, without the dash
	reset({ { Vector3.new(0, 4, -3.2), Vector3.new(6, 2, 1.2) } })
	place(Vector3.new(0, 3, 0), fwd)
	table.clear(fired)
	task.wait(0.6)
	if #parkourSent() > 0 then
		problem("running at a bar without dashing shouldn't slide by itself")
	end
	-- a curb: nothing (you just step up it)
	reset({ { Vector3.new(0, 0.5, -3), Vector3.new(6, 1, 1) } })
	place(Vector3.new(0, 3, 0), fwd)
	table.clear(fired)
	task.wait(0.15)
	press()
	task.wait(0.4)
	if #parkourSent() > 0 then
		problem("a curb shouldn't trigger parkour")
	end
	-- walking (not running) into a wall: nothing
	actions.QuirkSprint("QuirkSprint", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftControl })
	task.wait(0.1) -- (the run state updates on the next frame)
	reset({ { Vector3.new(0, 1.5, -3), Vector3.new(6, 3, 1) } })
	place(Vector3.new(0, 3, 0), fwd)
	table.clear(fired)
	task.wait(0.15)
	press()
	task.wait(0.4)
	if #parkourSent() > 0 then
		problem("walking into a wall shouldn't vault (only running): " .. table.concat(parkourSent(), ","))
	end

	-- WALL HOPS: a jump press beside a wall while moving; hops by health
	local kickOut = 0
	local function hops(health, holdIt)
		myHum.Health = health
		reset({ { Vector3.new(2.2, 10, 0), Vector3.new(1, 20, 60) } })
		myHum.FloorMaterial = Enum.Material.Plastic
		place(Vector3.new(0, 3, 0), fwd)
		task.wait(0.2) -- (landed: a fresh set)
		myHum.FloorMaterial = Enum.Material.Air
		place(Vector3.new(0, 8, 0), fwd)
		table.clear(fired)
		keysDown.Space = true
		local strongest = 0
		local t0 = os.clock()
		local lastPress = t0
		while os.clock() - t0 < 2.6 do
			for _, c in myRoot:GetChildren() do
				if c:IsA("LinearVelocity") then
					strongest = math.max(strongest, -c.VectorVelocity.X) -- (the wall is on +X: out is -X)
				end
			end
			if not holdIt then
				-- press, let go, press again (one press per hop)
				if os.clock() - lastPress > 0.55 then
					lastPress = os.clock()
					keysDown.Space = true
				elseif os.clock() - lastPress > 0.06 then
					keysDown.Space = nil
				end
			end
			task.wait(0.02)
		end
		kickOut = math.max(kickOut, strongest)
		keysDown.Space = nil
		local runs, kicks = 0, 0
		for _, k in parkourSent() do
			if k == "WallRun" then
				runs += 1
			elseif k == "WallKick" then
				kicks += 1
			end
		end
		return runs, kicks
	end
	local runs, kicks = hops(200)
	if kickOut < Config.Parkour.WallHop.KickOut * 0.9 then
		problem("the wall kick should shove you off hard (" .. math.floor(kickOut) .. " out)")
	end
	if runs ~= 3 or kicks ~= 3 then
		problem("full health: 3 wall hops (run + kick), got " .. runs .. "/" .. kicks)
	end
	runs = hops(100)
	if runs ~= 2 then
		problem("half health: 2 wall hops, got " .. runs)
	end
	runs = hops(40)
	if runs ~= 1 then
		problem("low health: 1 wall hop, got " .. runs)
	end
	runs = hops(200, true)
	if runs ~= 1 then
		problem("holding jump down should only hop once (one press, one hop), got " .. runs)
	end
	myHum.Health = 200
	-- no wall: jump does nothing special
	reset()
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 8, 0), fwd)
	table.clear(fired)
	keysDown.Space = true
	task.wait(0.4)
	keysDown.Space = nil
	if #parkourSent() > 0 then
		problem("no wall: no wall hop")
	end

	-- LANDING ROLL: a big fall, jump pressed just before the ground
	reset()
	myHum.FloorMaterial = Enum.Material.Plastic
	place(Vector3.new(0, 3, 0), fwd)
	task.wait(0.15)
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 24, 0), fwd)
	task.wait(0.1)
	place(Vector3.new(0, 6, 0), fwd)
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -70, 0)
	table.clear(fired)
	task.wait(0.05)
	keysDown.Space = true
	task.wait(0.1)
	keysDown.Space = nil
	myHum.FloorMaterial = Enum.Material.Plastic
	place(Vector3.new(0, 3, 0), fwd)
	task.wait(0.7)
	local kinds = parkourSent()
	if kinds[1] ~= "Roll" then
		problem("jump just before landing a big fall should roll (" .. tostring(kinds[1]) .. ")")
	elseif myRoot.CFrame.Position.Z > -8 then
		problem("the roll should carry you forward (z " .. math.floor(myRoot.CFrame.Position.Z) .. ")")
	end
	-- a small hop: no roll
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 6, 0), fwd)
	task.wait(0.1)
	place(Vector3.new(0, 5, 0), fwd)
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
	table.clear(fired)
	keysDown.Space = true
	task.wait(0.1)
	keysDown.Space = nil
	myHum.FloorMaterial = Enum.Material.Plastic
	place(Vector3.new(0, 3, 0), fwd)
	task.wait(0.5)
	if #parkourSent() > 0 then
		problem("a small hop shouldn't roll")
	end

	-- (round 65) LEDGE CATCH: in the air at a ledge a little too high to jump
	-- onto, jump pressed as the hands reach it: pulled up onto the top
	reset({ { Vector3.new(0, 4.5, -4), Vector3.new(6, 9, 3) } })
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 6.5, -1.3), fwd)
	myHum.MoveDirection = fwd
	task.wait(0.35) -- (clear of the last move's cooldown)
	place(Vector3.new(0, 6.5, -1.3), fwd)
	table.clear(fired)
	keysDown.Space = true
	task.wait(0.06)
	keysDown.Space = nil
	task.wait(0.8)
	local caught = parkourSent()
	if caught[1] ~= "Climb" and caught[1] ~= "Mantle" then
		problem("LEDGE CATCH: jump at a ledge in reach, in the air: pulled up onto it (" .. tostring(caught[1]) .. ")")
	elseif myRoot.CFrame.Position.Y < 11 or myRoot.CFrame.Position.Z > -2.5 then
		problem("LEDGE CATCH: ...standing on top afterwards (" .. tostring(myRoot.CFrame.Position) .. ")")
	end
	-- (a wall with nothing to catch within reach: no catch - a wall hop's the thing there)
	reset({ { Vector3.new(0, 30, -4), Vector3.new(6, 60, 3) } })
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 6.5, -1.3), fwd)
	task.wait(0.35)
	place(Vector3.new(0, 6.5, -1.3), fwd)
	table.clear(fired)
	keysDown.Space = true
	task.wait(0.06)
	keysDown.Space = nil
	task.wait(0.4)
	for _, k in parkourSent() do
		if k == "Climb" or k == "Mantle" then
			problem("LEDGE CATCH: a wall with no top in reach isn't a ledge (" .. k .. ")")
		end
	end
	task.wait(0.6)

	-- (round 65, JJS) THE ROLL turns the fall into speed out of it
	reset()
	myHum.FloorMaterial = Enum.Material.Plastic
	place(Vector3.new(0, 3, 0), fwd)
	task.wait(0.4)
	myHum.FloorMaterial = Enum.Material.Air
	place(Vector3.new(0, 24, 0), fwd)
	task.wait(0.1)
	place(Vector3.new(0, 6, 0), fwd)
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -70, 0)
	table.clear(fired)
	task.wait(0.05)
	keysDown.Space = true
	task.wait(0.1)
	keysDown.Space = nil
	myHum.FloorMaterial = Enum.Material.Plastic
	place(Vector3.new(0, 3, 0), fwd)
	local fastest = 0
	local tr = os.clock()
	while os.clock() - tr < 0.8 do
		for _, c in myRoot:GetChildren() do
			if c:IsA("LinearVelocity") and c.VelocityConstraintMode.Name == "Plane" then
				fastest = math.max(fastest, Vector2.new(c.PlaneVelocity.X, c.PlaneVelocity.Y).Magnitude)
			end
		end
		task.wait(1 / 60)
	end
	local walk = myHum.WalkSpeed
	if parkourSent()[1] ~= "Roll" or fastest < walk + 15 then
		problem(string.format("THE ROLL: a big fall's speed carries on out of it (%.0f studs/s out, walking %.0f)", fastest, walk))
	end
	myHum.MoveDirection = fwd

	-- DOUBLE-TAP W: run
	reset()
	local base = myChar:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	myHum.WalkSpeed = base
	local W = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.W }
	signalOf(uis, "InputBegan"):Fire(W, false)
	signalOf(uis, "InputEnded"):Fire(W, false)
	task.wait(0.1)
	signalOf(uis, "InputBegan"):Fire(W, false)
	task.wait(0.2)
	if myHum.WalkSpeed <= base + 0.5 then
		problem("double-tapping W should break into a run (" .. myHum.WalkSpeed .. ")")
	end
	signalOf(uis, "InputEnded"):Fire(W, false)
	task.wait(0.2)
	if myHum.WalkSpeed > base + 0.5 then
		problem("letting go of W should stop the run")
	end
	myHum.MoveDirection = Vector3.zero
	-- nothing left over
	if myHum.PlatformStand then
		problem("parkour left the body platform-standing")
	end
	if not myHum.AutoRotate then
		problem("parkour left turning switched off")
	end
	-- the effects for every move (as someone else sees them)
	for _, k in { "Vault", "Mantle", "Climb", "WallUp", "Slide", "WallRun", "WallKick", "Roll" } do
		VFX.Play("Parkour", myChar, { Kind = k, Dir = fwd, Side = "L", Time = 0.3 }, false)
		task.wait(0.05)
	end
	task.wait(0.6)
	setRaycast(nil)
	localPlayer:SetAttribute("Quirk", nil)
end)
blockcastImpl68 = nil
if not okR22 then
	problem("round 22 scenario crashed: " .. tostring(errR22))
end

print("== round 24: JJS movement (no build-up, no skid, fixed jumps, normal gravity, no landing stagger, speed follows HP)")
local okR23, errR23 = pcall(function()
	local FEEL = Config.Movement.Feel
	local changed = changedStates
	local function parkourSent(kind)
		local n = 0
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == Config.PARKOUR_INDEX and f[3] == kind then
				n += 1
			end
		end
		return n
	end
	local street = Instance.new("Part")
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 and origin.Y > 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Normal = Vector3.new(0, 1, 0), Instance = street, Distance = origin.Y }
		end
		return nil
	end)
	localPlayer:SetAttribute("Quirk", "Explosion")
	setAttr(myChar, "BaseWalkSpeed", 18)
	myHum.Health = myHum.MaxHealth
	myRoot.AssemblyMass = 12
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myHum.FloorMaterial = Enum.Material.Plastic
	myHum.MoveDirection = Vector3.zero
	task.wait(0.2)
	-- a standing start is full walking speed straight away
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(0.05)
	if math.abs(myHum.WalkSpeed - 18) > 0.05 then
		problem("walking should start at full speed at once, like JJS (" .. myHum.WalkSpeed .. ")")
	end
	-- speed follows health
	myHum.Health = myHum.MaxHealth * 0.5
	task.wait(0.05)
	local hurt = 18 * (1 - FEEL.HurtSlow * 0.5)
	if math.abs(myHum.WalkSpeed - hurt) > 0.05 then
		problem("at half HP you should walk a little slower (" .. myHum.WalkSpeed .. ", wanted " .. hurt .. ")")
	end
	myHum.Health = myHum.MaxHealth
	task.wait(0.05)
	-- into a run: it picks up over RunBuild
	actions.QuirkSprint("QuirkSprint", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftControl })
	task.wait(0.05)
	local mid = myHum.WalkSpeed
	task.wait(FEEL.RunBuild + 0.1)
	local full = 18 * Config.Movement.SprintMultiplier
	if not (mid > 18.5 and mid < full - 0.5) or math.abs(myHum.WalkSpeed - full) > 0.05 then
		problem("the run should pick up quickly (" .. mid .. " -> " .. myHum.WalkSpeed .. ")")
	end
	-- letting go mid-run: a dead stop, no skid
	myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, -full)
	table.clear(fired)
	myHum.MoveDirection = Vector3.zero
	task.wait(0.1)
	if parkourSent("Skid") ~= 0 then
		problem("stopping out of a run shouldn't skid any more")
	end
	actions.QuirkSprint("QuirkSprint", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftControl })
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(0.05)
	if math.abs(myHum.WalkSpeed - 18) > 0.05 then
		problem("dropping out of a run should be back to walking at once (" .. myHum.WalkSpeed .. ")")
	end
	myHum.MoveDirection = Vector3.zero
	myRoot.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.3)

	-- COYOTE TIME: ran off an edge, jump a moment later
	myHum.FloorMaterial = Enum.Material.Plastic
	task.wait(0.1)
	myHum.FloorMaterial = Enum.Material.Air
	myRoot.CFrame = r.CFrame.new(0, 6, 0)
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
	table.clear(changed)
	task.wait(0.03)
	keysDown.Space = true
	task.wait(0.04)
	keysDown.Space = nil
	if not table.find(changed, "Jumping") then
		problem("coyote time: a jump just after running off an edge should still jump")
	end
	-- ...but not long after
	myHum.FloorMaterial = Enum.Material.Plastic
	task.wait(0.1)
	myHum.FloorMaterial = Enum.Material.Air
	task.wait(0.3)
	table.clear(changed)
	keysDown.Space = true
	task.wait(0.05)
	keysDown.Space = nil
	if table.find(changed, "Jumping") then
		problem("coyote time shouldn't last (a late press in the air did a jump)")
	end
	-- JUMP BUFFER: pressed just before landing
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
	task.wait(0.05)
	keysDown.Space = true
	task.wait(0.03)
	keysDown.Space = nil
	table.clear(changed)
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.05)
	if not table.find(changed, "Jumping") then
		problem("a jump pressed just before landing should go off on landing")
	end
	task.wait(0.2)

	-- every jump is the same height: letting go early doesn't cut it
	keysDown.Space = true
	myHum.FloorMaterial = Enum.Material.Air
	myRoot.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
	signalOf(myHum, "StateChanged"):Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping)
	task.wait(0.05)
	keysDown.Space = nil
	task.wait(0.05)
	if math.abs(myRoot.AssemblyLinearVelocity.Y - 50) > 0.5 then
		problem("letting go of jump shouldn't cut the jump (" .. myRoot.AssemblyLinearVelocity.Y .. ")")
	end
	-- FALLING: normal gravity (no extra pull), capped
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
	task.wait(0.05)
	local gravity = myRoot:FindFirstChild("FallGravity")
	if gravity and gravity.Force.Y ~= 0 then
		problem("falling shouldn't pull harder than normal gravity")
	end
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -400, 0)
	task.wait(0.05)
	if myRoot.AssemblyLinearVelocity.Y < -FEEL.MaxFallSpeed - 0.5 then
		problem("falling should top out at " .. FEEL.MaxFallSpeed)
	end
	-- a big drop: you land and keep going (no stagger)
	myRoot.AssemblyLinearVelocity = Vector3.new(0, -130, 0)
	task.wait(0.05)
	table.clear(fired)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.08)
	if parkourSent("Land") ~= 0 or math.abs(myHum.WalkSpeed - 18) > 0.05 then
		problem("a hard landing shouldn't stagger you (" .. myHum.WalkSpeed .. ")")
	end
	myHum.MoveDirection = Vector3.zero
	-- the air poses: takeoff, running jump, a long drop, a landing
	VFX.LocoOverride[myChar] = { Velocity = Vector3.new(0, 45, -28), Grounded = false }
	task.wait(0.3)
	VFX.LocoOverride[myChar] = { Velocity = Vector3.new(0, -90, 0), Grounded = false }
	task.wait(1.4)
	VFX.LocoOverride[myChar] = { Velocity = Vector3.zero, Grounded = true }
	task.wait(0.4)
	VFX.LocoOverride[myChar] = nil
	setRaycast(nil)
	localPlayer:SetAttribute("Quirk", nil)
end)
if not okR23 then
	problem("round 24 movement scenario crashed: " .. tostring(errR23))
end

print("== round 25: M1 tracking, finishers aimed with the crosshair")
local okBal, errBal = pcall(function()
	localPlayer:SetAttribute("Quirk", "Explosion")
	myHum.Health = myHum.MaxHealth
	setAttr(myChar, "Stunned", false)
	local folderD = workspace:FindFirstChild("Dummies")
	local here = Vector3.new(0, 3, 0)
	-- (Lune keeps Position and CFrame apart: set both. And its CFrame.lookAt
	-- flips the Z axis, so turn the body with a yaw angle instead)
	local face = Vector3.new(0.08, 0, -1).Unit
	local function faceCF(f)
		return r.CFrame.new(here) * r.CFrame.Angles(0, math.atan2(-f.X, -f.Z), 0)
	end
	-- M1 tracking: someone close, a little off to one side of where you face
	-- (round 27: a nudge within Assist.Angle - it doesn't swing you round)
	myRoot.CFrame = faceCF(face)
	myRoot.Position = here
	local side = here + (r.CFrame.Angles(0, math.rad(-25), 0) * face) * 7
	local foe = makeR15("M1Foe", side)
	foe.Parent = folderD
	task.wait(Config.M1.ComboReset + 0.1)
	table.clear(fired)
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, {})
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, {})
	task.wait(0.05)
	local swing = fired[1]
	local sentCF = swing and swing[1] == "UseAbility" and swing[2] == 0 and swing[3]
	local toFoe = Vector3.new(side.X - here.X, 0, side.Z - here.Z).Unit
	if not (typeof(sentCF) == "CFrame" and sentCF.LookVector:Dot(toFoe) > 0.97) then
		problem("an M1 should turn to track someone close in front (sent " .. tostring(sentCF and sentCF.LookVector) .. ")")
	end
	-- ...but not someone behind you
	foe:FindFirstChild("HumanoidRootPart").CFrame = r.CFrame.new(here - face * 7)
	foe:FindFirstChild("HumanoidRootPart").Position = here - face * 7
	myRoot.CFrame = faceCF(face)
	task.wait(Config.M1.ComboReset + 0.1)
	table.clear(fired)
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.Begin, {})
	actions.QuirkPunch("QuirkPunch", Enum.UserInputState.End, {})
	task.wait(0.05)
	local swing2 = fired[1] and fired[1][3]
	if not (typeof(swing2) == "CFrame" and swing2.LookVector:Dot(face) > 0.97) then
		problem("an M1 shouldn't spin you round to someone behind you")
	end
	foe:Destroy()
	-- finishers: the one nearest the crosshair (straight down -Z here), not the
	-- one your body happens to face
	myRoot.CFrame = faceCF(Vector3.new(1, 0, 0))
	myRoot.Position = here
	local inSights, inSightsHum = makeR15("InSights", here + Vector3.new(0, 0, -7))
	local beside, besideHum = makeR15("Beside", here + Vector3.new(4, 0, -1))
	for _, pair in { { inSights, inSightsHum }, { beside, besideHum } } do
		pair[2].MaxHealth = 500
		pair[2].Health = 40
		pair[1].Parent = folderD
	end
	beat(15)
	table.clear(fired)
	actions.QuirkFinish("QuirkFinish", Enum.UserInputState.Begin, {})
	task.wait(0.05)
	local sent = fired[1]
	if not (sent and sent[2] == Config.FINISH_INDEX and sent[3] == inSights) then
		problem("E should finish whoever is nearest the crosshair (got " .. tostring(sent and sent[3]) .. ")")
	end
	local aimSent = sent and sent[4]
	if not (typeof(aimSent) == "Vector3" and aimSent.Unit:Dot(Vector3.new(0, 0, -1)) > 0.9) then
		problem("the finisher should tell the server where you're aiming (" .. tostring(aimSent) .. ")")
	end
	inSights:Destroy()
	beside:Destroy()
	localPlayer:SetAttribute("Quirk", nil)
end)
if not okBal then
	problem("balance scenario crashed: " .. tostring(errBal))
end

print("== round 25: CRAZY DIAMOND (the Stand, building from rubble, restoring)")
local okCD, errCD = pcall(function()
	localPlayer:SetAttribute("Quirk", "CrazyDiamond")
	myHum.Health = myHum.MaxHealth
	task.wait(0.1)
	local function stand()
		for _, m in VFX.Folder:GetChildren() do
			if m.Name == "CrazyDiamond" then
				return m
			end
		end
		return nil
	end
	local function shown(m)
		local n = 0
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p.Transparency < 0.5 then
				n += 1
			end
		end
		return n
	end
	-- an M1: the Stand comes out and throws it with him
	play("Punch", { Count = 1 })
	task.wait(0.4)
	local st = stand()
	if not st or shown(st) < 40 then
		problem("the Stand should come out when he punches (" .. (st and shown(st) or 0) .. " parts showing)")
	end
	local torso = st and st:FindFirstChildWhichIsA("BasePart")
	if torso and (torso.CFrame.Position - myRoot.CFrame.Position).Magnitude > 8 then
		problem("the Stand should be right beside him")
	end
	-- every move plays without errors
	play("Dorarara", aim)
	task.wait(0.3)
	play("CrazyBuild", aim)
	local blocks = {}
	for i = 1, 12 do
		blocks[i] = { From = Vector3.new(i * 3, 1, 20), To = r.CFrame.new(0, i, -20), Size = Vector3.new(3, 3, 3), Color = r.Color3.fromRGB(120, 110, 100), Material = Enum.Material.Brick, Delay = 0.3 + i * 0.02 }
	end
	VFX.Play("CrazyBuilt", myChar, { Kind = "Wall", Blocks = blocks }, false)
	play("YoAngelo", aim)
	task.wait(0.8)
	local fixed = Instance.new("Part")
	fixed.Parent = workspace
	play("CrazyRestore", aim)
	VFX.Play("Restored", myChar, {
		Center = Vector3.new(0, 3, 0), Radius = 80, Parts = { fixed },
		Flights = { { From = Vector3.new(0, 3, 10), To = Vector3.new(0, 5, 30), Size = Vector3.one * 2, Color = r.Color3.new(1, 1, 1), Material = Enum.Material.Brick } },
	}, false)
	task.wait(0.3)
	if not VFX.Folder:FindFirstChildWhichIsA("SelectionBox") then
		problem("what RESTORE put back should glow pink for a moment")
	end
	localPlayer:SetAttribute("UltActive", true)
	VFX.Play("UltActivate", myChar, { Quirk = "CrazyDiamond" }, true)
	play("BreakRestore", aim)
	VFX.Play("Restored", myChar, { Center = Vector3.new(0, 3, 0), Radius = 70, Flights = {}, Parts = {}, Big = true }, false)
	play("Dash", { Dir = Vector3.new(0, 0, -1), Kind = "Front", Quirk = "CrazyDiamond" })
	task.wait(1.6)
	localPlayer:SetAttribute("UltActive", false)
	-- nobody else's character grows a Stand
	local other = makeR15("NotAStandUser", Vector3.new(30, 3, 0))
	VFX.Play("Dorarara", other, aim, false)
	task.wait(0.3)
	local stands = 0
	for _, m in VFX.Folder:GetChildren() do
		if m.Name == "CrazyDiamond" then
			stands += 1
		end
	end
	if stands ~= 1 then
		problem("only a Crazy Diamond user has the Stand (" .. stands .. ")")
	end
	-- BUILD says what it'll make, and V changes it
	setAttr(localPlayer, "Blueprint", "Stairs")
	task.wait(0.1)
	if HUD.Blueprint ~= "Stairs" then
		problem("the HUD should know the blueprint is Stairs")
	end
	-- switching away puts the Stand away for good
	localPlayer:SetAttribute("Quirk", "Explosion")
	task.wait(0.2)
	if stand() then
		problem("the Stand should go when he stops being Crazy Diamond")
	end
	localPlayer:SetAttribute("Quirk", nil)
	setAttr(localPlayer, "Blueprint", nil)
end)
if not okCD then
	problem("CRAZY DIAMOND scenario crashed: " .. tostring(errCD))
end

print("== round 27: BAKUGO (air variants, Eruption Orbit, Scorched Earth, the blinding grenade, Howitzer ult)")
local okBK, errBK = pcall(function()
	myHum.Health = myHum.MaxHealth
	localPlayer:SetAttribute("Quirk", "Explosion")
	myChar:SetAttribute("Quirk", "Explosion")
	local foe = makeR15("BakuFoe", Vector3.new(0, 3, -9))
	local foeRoot = foe.HumanoidRootPart
	-- every M1 goes off in his palm
	local popped = 0
	local realPlaySound = VFX.PlaySound
	VFX.PlaySound = function(name, ...)
		if name == "PalmPop" or name == "Explosion" then
			popped += 1
		end
		return realPlaySound(name, ...)
	end
	for count = 1, 4 do
		play("Punch", { Count = count, Finisher = count == 4 })
		task.wait(0.12)
	end
	task.wait(0.3)
	VFX.PlaySound = realPlaySound
	if popped < 4 then
		problem("every Bakugo M1 should go off in a palm blast (" .. popped .. ")")
	end
	-- the moves, ground and air
	play("APShot", { Dir = Vector3.new(0, -0.7, -0.7).Unit, Pos = Vector3.new(0, 0, -6) })
	play("APShot", { Dir = Vector3.new(0, -0.7, -0.7).Unit, Pos = Vector3.new(0, 0, -6), Air = true })
	play("BlastRush", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -20), Air = true })
	task.wait(0.9)
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	play("BlastOrbit", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -9) })
	task.wait(0.5)
	-- the orbit: his own screen flies him round B
	local center = Vector3.new(0, 20, -9)
	play("BlastOrbitCatch", { Targets = { foe }, Center = center, Dir = Vector3.new(0, 0, -1) })
	task.wait(0.3)
	if not myHum.PlatformStand then
		problem("the orbit should fly his body (PlatformStand while it does)")
	end
	local dist = (myRoot.CFrame.Position - center).Magnitude
	if dist > 13 then
		problem("the orbit should circle close round them (" .. math.floor(dist) .. " studs)")
	end
	task.wait(0.8)
	if myHum.PlatformStand then
		problem("the body should be his again after the orbit")
	end
	if (myRoot.CFrame.Position - (center + Vector3.new(0, 9, 0))).Magnitude > 3 then
		problem("the orbit should end right over them (" .. tostring(myRoot.CFrame.Position) .. ")")
	end
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	-- someone else's orbit doesn't move you
	local other2 = makeR15("OtherBaku", Vector3.new(20, 3, 0))
	VFX.Play("BlastOrbitCatch", other2, { Targets = { foe }, Center = center, Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(0.2)
	if myHum.PlatformStand then
		problem("someone else's orbit shouldn't fly YOUR body")
	end
	task.wait(1)
	other2:Destroy()
	VFX.Play("BlastOrbitCatch", myChar, { Targets = {} }, false)
	play("ScorchedEarth", { Dir = Vector3.new(0, 0, -1) })
	play("ScorchedEarthCatch", { Target = foe, Dir = Vector3.new(0, 0, -1) })
	play("ScorchedEarthCatch", { Target = foe, Dir = Vector3.new(0, 0, -1), Air = true })
	play("ScorchedEarthCatch", { Dir = Vector3.new(0, 0, -1) })
	task.wait(1)
	play("StunGrenade", { Dir = Vector3.new(0, 0, -1) })
	-- caught by someone else's grenade: white-out
	local flashFrame = playerGui:FindFirstChild("QuirkFlash") and playerGui.QuirkFlash:FindFirstChild("Flash")
	remotes:FindFirstChild("PlayVFX").OnClientEvent:Fire("Blind", nil, { Duration = 2.6 })
	task.wait(0.3)
	if not flashFrame or flashFrame.BackgroundTransparency > 0.05 then
		problem("blinded: the screen should be solid white (" .. tostring(flashFrame and flashFrame.BackgroundTransparency) .. ")")
	end
	task.wait(3)
	if flashFrame and flashFrame.BackgroundTransparency < 0.95 then
		problem("...and it should clear afterwards")
	end
	setAttr(localPlayer, "UltActive", true)
	play("Howitzer", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -60) })
	play("AutoCannon", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -60) })
	task.wait(2.2)
	setAttr(localPlayer, "UltActive", false)
	foe:Destroy()
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
end)
if not okBK then
	problem("BAKUGO scenario crashed: " .. tostring(errBK))
end

print("== round 27: ALL MIGHT (New Hampshire Smash, Hero's Counter, Backdrop Driver, Weather Changer)")
local okAM, errAM = pcall(function()
	myHum.Health = myHum.MaxHealth
	myChar:SetAttribute("Quirk", "OneForAll")
	local foe = makeR15("AMFoe", Vector3.new(0, 3, -6))
	play("NewHampshireSmash", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.8)
	setAttr(myChar, "Countering", true)
	play("HeroCounter", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.3)
	play("HeroCounterHit", { Target = foe })
	setAttr(myChar, "Countering", nil)
	task.wait(0.8)
	play("BackdropDriver", { Dir = Vector3.new(0, 0, -1) })
	play("BackdropCatch", { Target = foe, Dir = Vector3.new(0, 0, -1) })
	task.wait(1)
	play("BackdropCatch", { Dir = Vector3.new(0, 0, -1) })
	play("WeatherChanger", { Dir = Vector3.new(0, 0, -1) })
	task.wait(3.5)
	foe:Destroy()
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myChar:SetAttribute("Quirk", nil)
end)
if not okAM then
	problem("ALL MIGHT scenario crashed: " .. tostring(errAM))
end

print("== round 27: DEKU (R swaps the quirk in his 4th slot; Blackwhip throws)")
local okDK, errDK = pcall(function()
	myHum.Health = myHum.MaxHealth
	localPlayer:SetAttribute("Quirk", "FullCowl")
	myChar:SetAttribute("Quirk", "FullCowl")
	setAttr(localPlayer, "QuirkPick", 1)
	task.wait(0.1)
	table.clear(fired)
	actions.QuirkSpecial("QuirkSpecial", Enum.UserInputState.Begin, {})
	task.wait(0.1)
	if localPlayer:GetAttribute("QuirkPick") ~= 2 then
		problem("R should put the next quirk in the 4th slot right away (" .. tostring(localPlayer:GetAttribute("QuirkPick")) .. ")")
	end
	local sent = fired[1]
	if not sent or sent[2] ~= Config.SPECIAL_INDEX then
		problem("R should tell the server")
	end
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	task.wait(0.1)
	local v = fired[1]
	if not v or v[2] ~= Config.EXTRA_INDEX then
		problem("V should use the picked quirk")
	end
	if VFX.CowlLevel(myChar) ~= 1 then
		problem("Deku should always be in Full Cowl")
	end
	local foe = makeR15("DekuFoe", Vector3.new(0, 3, -20))
	play("Blackwhip", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 3, -20) })
	play("BlackwhipCatch", { Target = foe, Dir = Vector3.new(0, 0, -1), Throw = true })
	play("QuirkCycle", {})
	play("Smokescreen", {})
	task.wait(1.2)
	foe:Destroy()
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
	setAttr(localPlayer, "QuirkPick", 1)
end)
if not okDK then
	problem("DEKU scenario crashed: " .. tostring(errDK))
end

print("== round 27: TODOROKI (solid ice from a sheet at his foot, held up off ledges; Glacier Breaker, Ice Slider, Scorching Grip, the giant wall)")
local okTD, errTD = pcall(function()
	myHum.Health = myHum.MaxHealth
	myChar:SetAttribute("Quirk", "HalfCold")
	-- standing at a ledge: the street drops 40 studs, 20 studs ahead of him
	setRaycast(function(_, origin, dir)
		if dir.Y < 0 then
			local y = origin.Z < -20 and -40 or 0
			if origin.Y + dir.Y > y then
				return nil
			end
			return { Position = Vector3.new(origin.X, y, origin.Z), Instance = workspace, Normal = Vector3.new(0, 1, 0) }
		end
		return nil
	end)
	local before = {}
	for _, d in VFX.Folder:GetDescendants() do
		before[d] = true
	end
	play("IceSpike", { Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 0, -40), Seed = 5, Origin = Vector3.new(0, 3, 0) })
	task.wait(0.8)
	local sheets, columns, glassy = 0, 0, 0
	for _, d in VFX.Folder:GetDescendants() do
		if not before[d] and d:IsA("BasePart") then
			if d.Material == Enum.Material.Glass then
				glassy += 1
			end
			if d.Material == Enum.Material.Ice and d.CanCollide and d.Size.Y > 30 and d.CFrame.Position.Z < -18 then
				columns += 1 -- (a column holding the sheet up off the drop)
			elseif d.Material == Enum.Material.Ice and d.CanCollide and math.abs(d.Size.Y - 2.4) < 0.01 then
				sheets += 1
			end
		end
	end
	if sheets < 4 then
		problem("the ice should grow out of a sheet laid from his foot (" .. sheets .. " slabs)")
	end
	if columns < 2 then
		problem("past the ledge, columns of ice should hold the sheet up from the ground below (" .. columns .. ")")
	end
	if glassy > 0 then
		problem("his ice should be solid ice, not see-through glass (" .. glassy .. " glass parts)")
	end
	setRaycast(nil)
	task.wait(3)
	local foe = makeR15("IceFoe", Vector3.new(0, 3, -5))
	play("GlacierBreaker", { Dir = Vector3.new(0, 0, -1) })
	play("GlacierPin", { Target = foe, Dir = Vector3.new(0, 0, -1), Pos = Vector3.new(0, 3, -7.5), Time = 0.5 })
	play("GlacierPin", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.8)
	-- Ice Slider: his own screen skates him up the ramp and off the lip
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	play("IceSlider", { Dir = Vector3.new(0, 0, -1) })
	task.wait(0.4)
	if not myHum.PlatformStand or myRoot.CFrame.Position.Z > -10 then
		problem("ICE SLIDER should carry him up the ramp (" .. tostring(myRoot.CFrame.Position) .. ")")
	end
	task.wait(0.6)
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myChar:SetAttribute("QuirkAlt", true)
	play("JetKindling", { Dir = Vector3.new(0, 0, -1) })
	play("JetKindlingHit", { Target = foe, Dir = Vector3.new(0, 0, -1) })
	task.wait(0.9)
	myChar:SetAttribute("QuirkAlt", nil)
	setAttr(localPlayer, "UltActive", true)
	play("IceWall", { Dir = Vector3.new(0, 0, -1), Seed = 9, Origin = Vector3.new(0, 3, 0) })
	task.wait(2.5)
	VFX.CancelCinematic()
	setAttr(localPlayer, "UltActive", false)
	foe:Destroy()
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myChar:SetAttribute("Quirk", nil)
end)
if not okTD then
	problem("TODOROKI scenario crashed: " .. tostring(errTD))
end

print("== round 27: IIDA (hold Recipro Burst through the gears, steer the strikes with the camera)")
local okIR, errIR = pcall(function()
	myHum.Health = myHum.MaxHealth
	localPlayer:SetAttribute("Quirk", "Engine")
	myChar:SetAttribute("Quirk", "Engine")
	localPlayer:SetAttribute("NoCooldowns", true)
	local RB = Config.FindAbilityById("ReciproBurst")
	local callouts = {}
	local realCallout = HUD.Callout
	HUD.Callout = function(text, ...)
		table.insert(callouts, text)
		return realCallout(text, ...)
	end
	table.clear(fired)
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.Begin, {})
	setAttr(myChar, "Holding", "ReciproBurst") -- (the server has it)
	task.wait(RB.Hold.Levels[2] + 0.15)
	local joined = table.concat(callouts, ",")
	if not joined:find("GEAR 2") or not joined:find("GEAR 3") then
		problem("holding Recipro Burst should call out each gear (" .. joined .. ")")
	end
	table.clear(fired)
	actions.QuirkAbility3("QuirkAbility3", Enum.UserInputState.End, {})
	setAttr(myChar, "Holding", nil)
	local rel = fired[1]
	if not rel or rel[2] ~= Config.RELEASE_INDEX then
		problem("letting go of the key should release it")
	end
	-- the strikes follow the camera: turn it mid-dash and the dash turns
	local cam = workspace.CurrentCamera
	local was = cam.CFrame
	task.wait(0.05)
	cam.CFrame = r.CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(10, 5, 0))
	task.wait(0.1)
	if myRoot.CFrame.LookVector.X < 0.9 then
		problem("the dash strikes should turn with the camera (" .. tostring(myRoot.CFrame.LookVector) .. ")")
	end
	cam.CFrame = was
	task.wait(1)
	HUD.Callout = realCallout
	-- the other kicks
	play("SpinKick", { Dir = Vector3.new(0, 0, -1) })
	play("EngineGatling", { Dir = Vector3.new(0, 0, -1) })
	play("SkywardKick", { Dir = Vector3.new(0, 0, -1) })
	local watcher = makeR15("IidaOther", Vector3.new(30, 3, 0))
	VFX.Play("ReciproBurst", watcher, {}, false)
	task.wait(0.4)
	VFX.Play("HoldCancel", watcher, {}, false)
	VFX.Play("ReciproBurstRelease", watcher, { Level = 2, Dir = Vector3.new(0, 0, -1) }, false)
	task.wait(1.5)
	watcher:Destroy()
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	localPlayer:SetAttribute("NoCooldowns", nil)
	localPlayer:SetAttribute("Quirk", nil)
	myChar:SetAttribute("Quirk", nil)
end)
if not okIR then
	problem("IIDA scenario crashed: " .. tostring(errIR))
end

print("== round 27: the new 4th moves (Phantom Grasp, Sinkhole, Pillar Rise)")
local ok4, err4 = pcall(function()
	local foe = makeR15("FourthFoe", Vector3.new(0, 3, -20))
	myChar:SetAttribute("Quirk", "Lemillion")
	play("PhantomGrasp", { Dir = Vector3.new(0, 0, -1) })
	play("PhantomGraspCatch", { Target = foe, Time = 0.4 })
	myChar:SetAttribute("Quirk", "Decay")
	play("Sinkhole", { Dir = Vector3.new(0, 0, -1) })
	myChar:SetAttribute("Quirk", "Overhaul")
	play("PillarRise", {})
	task.wait(1.2)
	foe:Destroy()
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	myChar:SetAttribute("Quirk", nil)
end)
if not ok4 then
	problem("4th moves scenario crashed: " .. tostring(err4))
end

print("== round 27: aimed dashes (front and side dashes follow the camera)")
local okDash, errDash = pcall(function()
	myRoot.AssemblyMass = 12
	myHum.Health = myHum.MaxHealth
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	local cam = workspace.CurrentCamera
	local was = cam.CFrame
	-- (the harness never clears old effects' velocities: find the dash's own)
	local before = {}
	local function snapshot()
		table.clear(before)
		for _, c in myRoot:GetChildren() do
			before[c] = true
		end
	end
	local function dashVelocity()
		for _, c in myRoot:GetChildren() do
			if c:IsA("LinearVelocity") and not before[c] then
				if c.VelocityConstraintMode.Name == "Plane" then
					return Vector3.new(c.PlaneVelocity.X, 0, c.PlaneVelocity.Y)
				end
				return c.VectorVelocity
			end
		end
		return nil
	end
	-- front dash, then the camera swings to the right: the dash swings with it
	cam.CFrame = r.CFrame.new(0, 5, 10) -- (looking down -Z)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	snapshot()
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.05)
	cam.CFrame = r.CFrame.new(0, 5, 0) * r.CFrame.Angles(0, -math.pi / 2, 0) -- (swung round to +X)
	task.wait(0.08)
	local v = dashVelocity()
	if not v or v.X < Config.Movement.DashSpeed * 0.9 then
		problem("a front dash should turn with the camera (" .. tostring(v) .. ")")
	end
	task.wait(Config.Movement.DashCooldown + 0.3)
	-- side dash: it stays at right angles to where you look (it curves)
	cam.CFrame = r.CFrame.new(0, 5, 10) -- (looking down -Z)
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	snapshot()
	actions.QuirkDash("QuirkDash", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	task.wait(0.05)
	cam.CFrame = r.CFrame.new(0, 5, 0) * r.CFrame.Angles(0, -math.pi / 2, 0) -- (swung round to +X)
	task.wait(0.08)
	v = dashVelocity()
	if not v or math.abs(v.X) > 20 or math.abs(v.Z) < Config.Movement.DashSpeed * 0.9 then
		problem("a side dash should curve with the camera (" .. tostring(v) .. ")")
	end
	task.wait(Config.Movement.DashCooldown + 0.3)
	cam.CFrame = was
	myHum.MoveDirection = Vector3.zero
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
end)
if not okDash then
	problem("aimed dash scenario crashed: " .. tostring(errDash))
end

do
print("== round 28: ragdoll cancel, dash punch, no tripping over, flight, free cam, server settings, NUKE hold, solid ice, SUNEATER")
local ok28, err28 = pcall(function()
	local DASH = Config.DASH_INDEX
	local cam = workspace.CurrentCamera
	myHum.Health = myHum.MaxHealth
	myHum.FloorMaterial = Enum.Material.Plastic
	myRoot.AssemblyMass = 12
	myRoot.CFrame = r.CFrame.new(0, 3, 0)
	myRoot.Position = Vector3.new(0, 3, 0)
	local function find(name)
		return hudGui and hudGui:FindFirstChild(name, true)
	end
	local function sentDash(kind)
		for _, f in fired do
			if f[1] == "UseAbility" and f[2] == DASH and f[4] == kind then
				return f
			end
		end
		return nil
	end
	local function press(action, state)
		actions[action](action, state or Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q })
	end

	-- Roblox's own trip-and-fall states are off for your body
	if stateEnabled.FallingDown ~= false or stateEnabled.Ragdoll ~= false then
		problem("the FallingDown / Ragdoll humanoid states should be switched off (random ragdolls)")
	end

	-- the ragdoll cancel's meter on the HUD
	setAttr(myChar, "Evasive", 40)
	task.wait(0.05)
	local evBar = find("EvasiveMeter")
	local evText = evBar and evBar:FindFirstChildOfClass("TextLabel")
	if not evText or not evText.Text:find("40") then
		problem("the evasive meter should show 40% (" .. tostring(evText and evText.Text) .. ")")
	end
	-- down with it full: it says what to press, and dash cancels
	setAttr(myChar, "Evasive", 100)
	setAttr(myChar, "Ragdolled", true)
	task.wait(0.05)
	if not evText or not evText.Text:find("ESCAPE") then
		problem("ragdolled with the meter full, the HUD should say how to escape (" .. tostring(evText and evText.Text) .. ")")
	end
	table.clear(fired)
	myHum.MoveDirection = Vector3.new(1, 0, 0)
	press("QuirkDash")
	task.wait(0.05)
	local ev = sentDash("Evasive")
	if not ev or not (typeof(ev[3]) == "Vector3" and ev[3].X > 0.9) then
		problem("DASH while ragdolled with a full meter should ask for the ragdoll cancel, the way you're holding")
	end
	task.wait(0.5)
	table.clear(fired)
	setAttr(myChar, "Evasive", 50)
	press("QuirkDash")
	task.wait(0.05)
	if sentDash("Evasive") then
		problem("no ragdoll cancel with the meter half full")
	end
	-- the server stood us up: the quickstep plays on our machine
	setAttr(myChar, "Ragdolled", false)
	PlayVFX.OnClientEvent:Fire("Evasive", myChar, { Dir = Vector3.new(1, 0, 0) })
	PlayVFX.OnClientEvent:Fire("GetUp", myChar, {})
	task.wait(0.3)
	myHum.MoveDirection = Vector3.zero

	-- a front dash that reaches someone ends in a punch
	local dummiesF = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
	dummiesF.Name = "Dummies"
	dummiesF.Parent = workspace
	local foe = makeR15("PunchDummy", Vector3.new(0, 3, -3))
	foe.Parent = dummiesF
	foe.Humanoid.Health = 100
	cam.CFrame = r.CFrame.new(0, 5, 10)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(Config.Movement.FrontDashCooldown + 0.1)
	local before = {}
	for _, c in myRoot:GetChildren() do
		before[c] = true
	end
	table.clear(fired)
	press("QuirkDash")
	task.wait(0.1)
	local punch = sentDash("Punch")
	if not punch or punch[5] ~= foe then
		problem("a front dash into someone should punch them (" .. tostring(punch and punch[5]) .. ")")
	end
	for _, c in myRoot:GetChildren() do
		if c:IsA("LinearVelocity") and not before[c] and c.Parent and c.Name ~= "Knockback" then
			problem("...and the punch should stop the dash there")
		end
	end
	foe:Destroy()
	-- hit mid-dash: the dash is over at once (no tug-of-war with the hit)
	task.wait(Config.Movement.FrontDashCooldown + 0.1)
	table.clear(before)
	for _, c in myRoot:GetChildren() do
		before[c] = true
	end
	press("QuirkDash")
	task.wait(0.03)
	local dashLv
	for _, c in myRoot:GetChildren() do
		if c:IsA("LinearVelocity") and not before[c] then
			dashLv = c
		end
	end
	local kb = Instance.new("LinearVelocity")
	kb.Name = "Knockback"
	kb.Parent = myRoot
	task.wait(0.05)
	if not dashLv or dashLv.Parent ~= nil then
		problem("a knockback landing mid-dash should end the dash (" .. tostring(dashLv and dashLv.Parent) .. ")")
	end
	kb:Destroy()
	myHum.MoveDirection = Vector3.zero

	-- Suneater's stomach on the HUD (only while he's who you are)
	setAttr(myChar, "Stomach", 20)
	task.wait(0.05)
	local st = find("Stomach")
	local stText = st and st:FindFirstChildOfClass("TextLabel")
	if not st or not st.Visible or not stText or not stText.Text:find("HUNGRY") then
		problem("the stomach meter should show, and say he's hungry at 20% (" .. tostring(stText and stText.Text) .. ")")
	end
	setAttr(myChar, "Stomach", nil)
	task.wait(0.05)
	if st and st.Visible then
		problem("...and hide when he's someone else")
	end

	-- flight (server settings, or N): a flight mover while it's on
	setAttr(localPlayer, "Flight", true)
	cam.CFrame = r.CFrame.new(0, 5, 10)
	myHum.MoveDirection = Vector3.new(0, 0, -1)
	task.wait(0.1)
	local fly = myRoot:FindFirstChild("Flight")
	if not fly or not myHum.PlatformStand or not (fly.VectorVelocity.Z < -30) then
		problem("Flight on: you fly where you look (" .. tostring(fly and fly.VectorVelocity) .. ")")
	end
	setAttr(localPlayer, "Flight", nil)
	task.wait(0.1)
	if myRoot:FindFirstChild("Flight") or myHum.PlatformStand then
		problem("...and off again lands you back on your feet")
	end
	myHum.MoveDirection = Vector3.zero

	-- free cam: Ctrl + P
	keysDown.LeftControl = true
	uis.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	task.wait(0.05)
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		problem("Ctrl+P should take the camera off you (free cam)")
	end
	uis.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	task.wait(0.05)
	keysDown.LeftControl = nil
	if cam.CameraType ~= Enum.CameraType.Custom then
		problem("...and Ctrl+P again gives it back")
	end
	-- N: flight on/off (the server does it)
	table.clear(fired)
	uis.InputBegan:Fire({ KeyCode = Enum.KeyCode.N, UserInputType = Enum.UserInputType.Keyboard }, false)
	task.wait(0.05)
	local nFlight = false
	for _, f in fired do
		if f[1] == "TestCommand" and f[2] == "PSPlayer" and f[3] == "Flight" then
			nFlight = true
		end
	end
	if not nFlight then
		problem("N should toggle your flight")
	end

	-- the SERVER SETTINGS panel
	local panel = find("ServerSettings")
	if not panel then
		problem("the test menu should have a SERVER SETTINGS panel")
	else
		table.clear(fired)
		local row = panel:FindFirstChild("DamageMult", true)
		for _, b in row and row:GetChildren() or {} do
			if b:IsA("TextButton") and b.Text == "+" then
				b.MouseButton1Click:Fire()
			end
		end
		local toggleRow = panel:FindFirstChild("GodMode", true)
		local toggle = toggleRow and toggleRow:FindFirstChildOfClass("TextButton")
		if toggle then
			toggle.MouseButton1Click:Fire()
		end
		task.wait(0.05)
		local set, who = nil, nil
		for _, f in fired do
			if f[1] == "TestCommand" and f[2] == "PSSet" and f[3] == "DamageMult" then
				set = f[4]
			elseif f[1] == "TestCommand" and f[2] == "PSPlayer" and f[3] == "GodMode" then
				who = f[4]
			end
		end
		if set ~= 1.5 then
			problem("Damage Multiplier + should step 1 -> 1.5 (" .. tostring(set) .. ")")
		end
		if who ~= 0 then
			problem("a player switch applies to everyone by default (" .. tostring(who) .. ")")
		end
	end

	-- the NUKE: hold V as the dev kit, a red target circle, let go to throw
	localPlayer:SetAttribute("Quirk", "PlusUltra")
	myChar:SetAttribute("Quirk", "PlusUltra")
	signalOf(localPlayer, "attr:Quirk"):Fire()
	task.wait(0.1)
	table.clear(fired)
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.Begin, {})
	setAttr(myChar, "Holding", "Nuke")
	task.wait(0.2)
	local ring = VFX.Folder:FindFirstChild("NukeTarget")
	if not ring then
		problem("holding the NUKE shows where it'll land")
	end
	actions.QuirkExtra("QuirkExtra", Enum.UserInputState.End, {})
	task.wait(0.1)
	setAttr(myChar, "Holding", nil)
	local released = false
	for _, f in fired do
		if f[1] == "UseAbility" and f[2] == Config.RELEASE_INDEX then
			released = true
		end
	end
	if not released then
		problem("letting go of V throws the NUKE")
	end
	task.wait(0.1)
	if VFX.Folder:FindFirstChild("NukeTarget") then
		problem("...and the target circle goes")
	end
	task.wait(2.5)
	localPlayer:SetAttribute("Quirk", "Explosion")
	myChar:SetAttribute("Quirk", "Explosion")
	signalOf(localPlayer, "attr:Quirk"):Fire()

	-- ice is only solid once it's grown, and never inside someone
	-- (only what's new in the effects folder is looked at: the harness
	-- never cleans up, so the folder is full of old effects)
	local function newIce(oldKids)
		local list = {}
		for _, kid in VFX.Folder:GetChildren() do
			if not oldKids[kid] then
				for _, d in kid:GetDescendants() do
					if d:IsA("BasePart") and d.Material.Name == "Ice" then
						list[d] = true
					end
				end
			end
		end
		return list
	end
	local function kidsNow()
		local set = {}
		for _, kid in VFX.Folder:GetChildren() do
			set[kid] = true
		end
		return set
	end
	local oldKids = kidsNow()
	play("IceSpike", { Dir = Vector3.new(0, 0, -1), Seed = 11, Origin = Vector3.new(0, 3, 40) })
	-- watch each new piece of ice from the moment it appears
	local fresh, solidEarly = {}, 0
	local t0 = os.clock()
	while os.clock() - t0 < 3 do
		for p in newIce(oldKids) do
			if not fresh[p] then
				fresh[p] = true
				if p.CanCollide then
					solidEarly += 1
				end
			end
		end
		if next(fresh) ~= nil then
			break
		end
		task.wait()
	end
	if next(fresh) == nil or solidEarly > 0 then
		problem("growing ice mustn't be solid (it shoves whoever it grows under): " .. solidEarly .. (next(fresh) == nil and " (no ice seen)" or ""))
	end
	task.wait(0.8)
	local solid = 0
	for p in newIce(oldKids) do
		if p.CanCollide then
			solid += 1
		end
	end
	if solid == 0 then
		problem("...but once grown it's solid ice you can stand on")
	end
	-- with someone standing in it, it stays passable to them
	local boundsWas = boundsImpl
	boundsImpl = function()
		return { myRoot }
	end
	oldKids = kidsNow()
	play("IceSpike", { Dir = Vector3.new(0, 0, -1), Seed = 12, Origin = Vector3.new(0, 3, 80) })
	task.wait(1.2)
	for p in newIce(oldKids) do
		if p.CanCollide then
			problem("ice that grew up round a body mustn't turn solid round them")
			break
		end
	end
	boundsImpl = boundsWas

	-- SUNEATER's effects
	local target = makeR15("SeFoe", Vector3.new(0, 3, -20))
	local before2 = #VFX.Folder:GetChildren()
	play("TakoSnatchCatch", { Target = target, Dir = Vector3.new(0, 0, -1), Reach = 20 })
	task.wait(0.1)
	if #VFX.Folder:GetChildren() <= before2 then
		problem("TAKO SNATCH's arm should reach out")
	end
	PlayVFX.OnClientEvent:Fire("Poisoned", nil, { Target = target, Duration = 1 })
	task.wait(0.05)
	if not target.HumanoidRootPart:FindFirstChildOfClass("ParticleEmitter") then
		problem("Scorpius Toxin's venom should bubble on its target")
	end
	-- Octopus Mirage hides him from everyone else, then he's back
	target:SetAttribute("Mirage", true)
	PlayVFX.OnClientEvent:Fire("OctopusMirage", target, {})
	task.wait(0.5)
	local head = target:FindFirstChild("Head")
	if not head or head.Transparency < 0.9 then
		problem("OCTOPUS MIRAGE should hide him (" .. tostring(head and head.Transparency) .. ")")
	end
	setAttr(target, "Mirage", nil)
	task.wait(0.2)
	if head and head.Transparency > 0.1 then
		problem("...and he comes back when it's over (" .. tostring(head.Transparency) .. ")")
	end
	play("PlasmaCannon", { Dir = Vector3.new(0, 0, -1) }, target)
	task.wait(0.3)
	play("PlasmaCannonRelease", { Dir = Vector3.new(0, 0, -1), Level = 3 }, target)
	task.wait(1)
	target:Destroy()
end)
if not ok28 then
	problem("round 28 scenario crashed: " .. tostring(err28))
end

end

print("== the camera follows your new body (live servers swap it in after you spawn)")
local okCam, errCam = pcall(function()
	local camera = workspace.CurrentCamera
	local heartbeat = function()
		task.wait(0.55)
		signalOf(game:GetService("RunService"), "Heartbeat"):Fire(1 / 60)
		task.wait()
	end
	camera.CameraSubject = myHum
	camera.CameraType = Enum.CameraType.Scriptable
	local body, bodyHum = makeR15(localPlayer.Name, Vector3.new(0, 3, 0))
	bodyHum.MaxHealth, bodyHum.Health = 200, 200
	localPlayer.Character = body
	localPlayer.CharacterAdded:Fire(body)
	task.wait(0.1)
	if camera.CameraSubject ~= bodyHum then
		problem("the camera should follow the body the server swapped in")
	end
	if camera.CameraType ~= Enum.CameraType.Custom then
		problem("...and go back to following you")
	end
	-- anything that leaves it on the old body (or on nothing) is put right
	camera.CameraSubject = myHum
	heartbeat()
	if camera.CameraSubject ~= bodyHum then
		problem("a camera left on your old body should come back to you")
	end
	local gone = InstanceShim.new("Humanoid") -- (a body that's been deleted)
	camera.CameraSubject = gone
	heartbeat()
	if camera.CameraSubject ~= bodyHum then
		problem("a camera left on a deleted body should come back to you")
	end
	-- (but it doesn't fight something else looking at another thing)
	camera.CameraSubject = other:FindFirstChildOfClass("Humanoid")
	heartbeat()
	if camera.CameraSubject ~= other:FindFirstChildOfClass("Humanoid") then
		problem("the watchdog shouldn't steal a camera that's on someone else on purpose")
	end
	localPlayer.Character = myChar
	localPlayer.CharacterAdded:Fire(myChar)
	task.wait(0.1)
	body:Destroy()
	if camera.CameraSubject ~= myHum then
		problem("the camera should follow you back")
	end
end)
if not okCam then
	problem("camera scenario crashed: " .. tostring(errCam))
end

-- let every delayed effect finish so late errors surface
task.wait(3)
print(string.format("\n%d problem(s)", #problems))
process.exit(#problems == 0 and 0 or 1)
