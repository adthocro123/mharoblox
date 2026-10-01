-- Build real KeyframeSequences (what Studio's Animation Editor saves) from
-- the exported clips, inside a Configuration "Animations", and save them as
-- a model file: lune run build_ks.luau clips.json out.rbxm
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local clips = serde.decode("json", fs.readFile(process.args[1]))
local folder = Instance.new("Configuration")
folder.Name = "Animations"
local CHILDREN = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
for _, c in clips do
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
fs.writeFile(process.args[2], roblox.serializeModel({ folder }))
-- read it back
local back = roblox.deserializeModel(fs.readFile(process.args[2]))[1]
local n = 0
for _, d in back:GetDescendants() do
	n += 1
end
print(process.args[2], #back:GetChildren(), "sequences", n, "instances")
local ks = back:GetChildren()[1]
local kf = ks:GetChildren()[3]
print(ks.Name, ks.Priority, kf.Name, kf.Time, kf.HumanoidRootPart.Torso["Right Arm"].CFrame, kf.HumanoidRootPart.Torso["Right Arm"].EasingStyle)
