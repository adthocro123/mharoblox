-- (round 78) Add clips to the place's ReplicatedStorage.Animations without
-- touching the rest of it (whatever's been made or edited there in Studio
-- stays): a clip of the same name is replaced, the others are added.
-- lune run append_ks.luau place.rbxl clips.json out.rbxm
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Animations")
assert(folder, "no ReplicatedStorage.Animations in the place")
local before = #folder:GetChildren()
local clips = serde.decode("json", fs.readFile(process.args[2]))
local CHILDREN = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local added, replaced = 0, 0
for _, c in clips do
	local old = folder:FindFirstChild(c.name)
	if old then
		old:Destroy()
		replaced += 1
	else
		added += 1
	end
	local ks = Instance.new("KeyframeSequence")
	ks.Name = c.name
	ks.Loop = c.loop == true
	ks.Priority = Enum.AnimationPriority[c.priority or "Action"]
	for _, k in c.keys do
		local kf = Instance.new("Keyframe")
		kf.Name = k.name
		kf.Time = k.t
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		local function pose(name, parent)
			local p = Instance.new("Pose")
			p.Name = name
			p.CFrame = CFrame.new(table.unpack(k.poses[name]))
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle[k.style]
			p.EasingDirection = Enum.PoseEasingDirection[k.dir]
			p.Parent = parent
			return p
		end
		local torso = pose("Torso", root)
		for _, name in CHILDREN do
			pose(name, torso)
		end
		kf.Parent = ks
	end
	ks.Parent = folder
end
fs.writeFile(process.args[3], roblox.serializeModel({ folder }))
local back = roblox.deserializeModel(fs.readFile(process.args[3]))[1]
print(string.format("%s: %d clips before, %d added, %d replaced -> %d", process.args[3], before, added, replaced, #back:GetChildren()))
