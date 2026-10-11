-- Round 109: the Arcanist's clips (anim/moves_arc.py, exported to JSON) as
-- KeyframeSequences in a place to graft from (build109.py):
-- ReplicatedStorage.Arc109.<clip name>.
--   lune run clips109.luau clips.json out.rbxl
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local clips = serde.decode("json", fs.readFile(process.args[1]))
local game = Instance.new("DataModel")
local holder = Instance.new("Folder")
holder.Name = "Arc109"
holder.Parent = game:GetService("ReplicatedStorage")
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
	ks.Parent = holder
end
fs.writeFile(process.args[2], roblox.serializePlace(game))
print(#holder:GetChildren() .. " clips -> " .. process.args[2])
