-- Minimal Roblox engine mock for running QuirkServer headless under Lune.
local task = require("@lune/task")
-- Real math types (Vector3, CFrame, Color3, Enum) come from @lune/roblox.
local roblox = require("@lune/roblox")

local M = {}
M.Vector3 = roblox.Vector3
-- Lune's CFrame.lookAt / CFrame.new(pos, target) face AWAY from the target
-- (Roblox faces toward it), so rebuild them with fromMatrix.
local RealCF = roblox.CFrame
local CF = setmetatable({}, { __index = RealCF })
function CF.lookAt(at, target, up)
	local look = (target - at).Unit
	local right = look:Cross(up or roblox.Vector3.new(0, 1, 0))
	if right.Magnitude < 1e-5 then
		right = look:Cross(roblox.Vector3.new(0, 0, 1))
	end
	right = right.Unit
	return RealCF.fromMatrix(at, right, right:Cross(look), -look)
end
function CF.new(...)
	local a, b = ...
	if select("#", ...) == 2 and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
		return CF.lookAt(a, b)
	end
	return RealCF.new(...)
end
M.CFrame = CF
M.Color3 = roblox.Color3
M.Enum = roblox.Enum

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local entry = { fn = fn, live = true }
		table.insert(self.handlers, entry)
		return {
			Disconnect = function()
				entry.live = false
			end,
		}
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
		for _, h in self.handlers do
			if h.live then
				task.spawn(h.fn, ...)
			end
		end
	end
	function s:Wait()
		local thread = coroutine.running()
		self:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	return s
end
M.newSignal = newSignal

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local ISA = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	Seat = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	RemoteEvent = {},
	Humanoid = {},
	PointLight = { "Light" },
}

local Instance = {}
Instance.__index = function(self, key)
	local method = rawget(Instance, key)
	if method then
		return method
	end
	local props = rawget(self, "_props")
	if key == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	if key == "Name" then
		return props.Name
	end
	local changed = rawget(self, "_signals")[key]
	if changed then
		return changed
	end
	if key == "Died" or key == "ChildAdded" or key == "DescendantAdded" or key == "CharacterAdded"
		or key == "CharacterAppearanceLoaded" or key == "OnServerEvent" or key == "Event"
		or key == "PlayerAdded" or key == "PlayerRemoving" or key == "Heartbeat" or key == "Changed" or key == "Triggered" or key == "Touched" then
		local s = newSignal()
		rawget(self, "_signals")[key] = s
		return s
	end
	return props[key]
end
Instance.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local kids = rawget(old, "_children")
			local i = table.find(kids, self)
			if i then
				table.remove(kids, i)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
			value.ChildAdded:Fire(self)
			-- like Roblox: every ancestor hears about a new descendant
			local anc = value
			while anc do
				local sig = rawget(anc, "_signals").DescendantAdded
				if sig then
					sig:Fire(self)
				end
				anc = rawget(anc, "_parent")
			end
		end
		return
	end
	local props = rawget(self, "_props")
	if key == "Position" and typeof(value) == "Vector3" then
		props.CFrame = M.CFrame.new(value) * (props.CFrame or M.CFrame.new()).Rotation
		return
	end
	local old = props[key]
	-- like Roblox: a Humanoid dies whenever its health reaches 0, however it got there
	local dies = key == "Health" and props.ClassName == "Humanoid" and type(value) == "number" and value <= 0 and self.Health > 0
	props[key] = value
	if dies then
		self.Died:Fire()
	end
	local watch = rawget(self, "_signals")["prop:" .. key]
	if watch and old ~= value then
		watch:Fire()
	end
	if key == "Value" and old ~= value then
		local s = rawget(self, "_signals").Changed
		if s then
			s:Fire(value)
		end
	end
end
Instance.__tostring = function(self)
	return "Instance<" .. tostring(self.ClassName) .. " " .. tostring(self.Name) .. ">"
end

local DEFAULTS = {
	Part = function()
		return { Size = M.Vector3.one, CFrame = M.CFrame.new(), AssemblyLinearVelocity = M.Vector3.zero, Anchored = false, Transparency = 0, CanCollide = true }
	end,
	Seat = function()
		return { Size = M.Vector3.one, CFrame = M.CFrame.new(), AssemblyLinearVelocity = M.Vector3.zero, Anchored = false, Transparency = 0, CanCollide = true }
	end,
	Decal = function()
		return { Transparency = 0 }
	end,
	ParticleEmitter = function()
		return { Enabled = true }
	end,
	PointLight = function()
		return { Enabled = true }
	end,
	IntValue = function()
		return { Value = 0 }
	end,
	Humanoid = function()
		return { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, HipHeight = 2, RigType = M.Enum.HumanoidRigType.R15 }
	end,
}

function M.new(className, name)
	local props = DEFAULTS[className] and DEFAULTS[className]() or {}
	props.ClassName = className
	props.Name = name or className
	local self = setmetatable({ _props = props, _children = {}, _attrs = {}, _attrSignals = {}, _signals = {}, _parent = nil }, Instance)
	return self
end

function Instance:GetPropertyChangedSignal(key)
	local signals = rawget(self, "_signals")
	signals["prop:" .. key] = signals["prop:" .. key] or newSignal()
	return signals["prop:" .. key]
end
function Instance:IsA(className)
	if self.ClassName == className or className == "Instance" then
		return true
	end
	return table.find(ISA[self.ClassName] or {}, className) ~= nil
end
function Instance:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Instance:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, c in rawget(inst, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Instance:FindFirstChild(name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Instance:WaitForChild(name)
	return self:FindFirstChild(name)
end
function Instance:FindFirstChildOfClass(className)
	for _, c in rawget(self, "_children") do
		if c.ClassName == className then
			return c
		end
	end
	return nil
end
function Instance:FindFirstChildWhichIsA(className)
	for _, c in rawget(self, "_children") do
		if c:IsA(className) then
			return c
		end
	end
	return nil
end
function Instance:FindFirstAncestorOfClass(className)
	local p = self.Parent
	while p do
		if p.ClassName == className then
			return p
		end
		p = p.Parent
	end
	return nil
end
function Instance:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function Instance:SetAttribute(k, v)
	local attrs = rawget(self, "_attrs")
	if attrs[k] == v then
		return
	end
	attrs[k] = v
	local s = rawget(self, "_attrSignals")[k]
	if s then
		s:Fire()
	end
end
function Instance:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Instance:GetAttributeChangedSignal(k)
	local sigs = rawget(self, "_attrSignals")
	sigs[k] = sigs[k] or newSignal()
	return sigs[k]
end
function Instance:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Instance:ClearAllChildren()
	for _, c in self:GetChildren() do
		c:Destroy()
	end
end
function Instance:GetPivot()
	return self.PrimaryPart and self.PrimaryPart.CFrame or M.CFrame.new()
end
function Instance:PivotTo(cf)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end
-- Humanoid
function Instance:TakeDamage(amount)
	if self.Health <= 0 then
		return
	end
	self.Health = math.max(0, self.Health - amount) -- (the Health setter fires Died)
end
function Instance:ChangeState() end
-- BindableEvent:Fire -> .Event
function Instance:Fire(...)
	self.Event:Fire(...)
end
-- Humanoid:MoveTo just records where it was sent (tests read MoveToTarget)
function Instance:MoveTo(pos)
	rawget(self, "_props").MoveToTarget = pos
end
function Instance:SetNetworkOwner() end
function Instance:ScaleTo() end
-- (round 69: Twice's doubles) every attribute; a deep copy - properties,
-- attributes and children (signals are its own)
function Instance:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end
local function cloneInto(src, map)
	local copy = M.new(src.ClassName, src.Name)
	map[src] = copy
	local props = rawget(copy, "_props")
	for k, v in rawget(src, "_props") do
		props[k] = v
	end
	for k, v in rawget(src, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(src, "_children") do
		cloneInto(c, map).Parent = copy
	end
	return copy
end
function Instance:Clone()
	-- (like Roblox: references inside the copied tree - PrimaryPart, a
	-- joint's Part0 / Part1 - point at the copies)
	local map = {}
	local copy = cloneInto(self, map)
	for _, c in map do
		local props = rawget(c, "_props")
		for k, v in props do
			if type(v) == "table" and map[v] then
				props[k] = map[v]
			end
		end
	end
	return copy
end
-- Remotes: record everything the server sends
function Instance:FireClient(player, ...)
	M.sent[#M.sent + 1] = { To = player, Args = table.pack(...) }
end
function Instance:FireAllClients(...)
	M.sent[#M.sent + 1] = { To = "all", Args = table.pack(...) }
end
M.sent = {}

return M
