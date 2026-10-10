-- Round 108: standin108.py's clips as real KeyframeSequences (what Studio's
-- Animation Editor saves): one file per slot, reupload107/<old id>.rbxm
-- (a KeyframeSequence at the top, ready for `reupload_anims.py
-- --upload-only`), and all of them in one model, touhou_new_anims.rbxm
-- (a Folder per character), to look at or publish by hand in Studio.
--   lune run standin108.luau clips.json <out dir>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local clips = serde.decode("json", fs.readFile(process.args[1]))
local out = process.args[2]
fs.writeDir(out .. "/reupload107")

local CHILDREN = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function build(c)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = c.slot
	ks.Loop = c.loop == true
	ks.Priority = Enum.AnimationPriority[c.priority or "Action"]
	ks:SetAttribute("OldId", c.id)
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
	return ks
end

local model = Instance.new("Folder")
model.Name = "TouhouNewAnimations"
local groups = {}
for _, c in clips do
	fs.writeFile(out .. "/reupload107/" .. c.id .. ".rbxm", roblox.serializeModel({ build(c) }))
	local who = string.match(c.slot, "^(%S+)") or "Other"
	if who ~= "Mokou" and who ~= "Remilia" then
		who = "Reactions"
	end
	if not groups[who] then
		groups[who] = Instance.new("Folder")
		groups[who].Name = who
		groups[who].Parent = model
	end
	local ks = build(c)
	ks.Name = c.id .. "  " .. c.slot
	ks.Parent = groups[who]
end
fs.writeFile(out .. "/touhou_new_anims.rbxm", roblox.serializeModel({ model }))

-- read every file back: one KeyframeSequence, the right keys, times in order
local bad, keys = 0, 0
for _, c in clips do
	local got = roblox.deserializeModel(fs.readFile(out .. "/reupload107/" .. c.id .. ".rbxm"))
	local ks = got[1]
	local kfs = ks and ks:GetChildren() or {}
	table.sort(kfs, function(a, b)
		return a.Time < b.Time
	end)
	local ok = #got == 1 and ks.ClassName == "KeyframeSequence" and #kfs == #c.keys and ks.Loop == (c.loop == true)
	for i, kf in kfs do
		local torso = kf:FindFirstChild("HumanoidRootPart") and kf.HumanoidRootPart:FindFirstChild("Torso")
		ok = ok and math.abs(kf.Time - c.keys[i].t) < 1e-4 and torso ~= nil and #torso:GetChildren() == 5
	end
	keys += #kfs
	if not ok then
		bad += 1
		print("MISMATCH", c.id, c.slot)
	end
end
local back = roblox.deserializeModel(fs.readFile(out .. "/touhou_new_anims.rbxm"))[1]
local n = 0
for _, d in back:GetDescendants() do
	if d.ClassName == "KeyframeSequence" then
		n += 1
	end
end
print(#clips, "files,", keys, "keyframes,", bad, "mismatches; combined model:", n, "sequences")
