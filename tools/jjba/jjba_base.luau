-- jjba_base.luau <jjba.rbxl> <out.rbxm>
-- Builds the round 104 base model: ReplicatedStorage.JJBA's folders, and the
-- JJBA place's Moon Animator 2 saves the stand loops only live in, turned
-- into KeyframeSequences (JJBA.Clips). A Moon save keeps each joint's C1 as
-- the animator moved it: the joint's Transform is v:Inverse() * C1 (C1 of
-- the rig's own joint).
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Instance = roblox.Instance
local Enum = roblox.Enum

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local RS = game:GetService("ReplicatedStorage")
local saves = game:GetService("ServerStorage"):FindFirstChild("MoonAnimatorSaves")

-- the rigs the saves were made on -> that rig's joint C1s (by Part1 name)
local RIGS = {
	StarPlatinum = RS.Stands.StarPlatinum.StarPlatinum,
	TheWorld = RS.Stands.TheWorld.TheWorld,
	Cmoon_Rig = RS.Stands.C_Moon.Cmoon,
	MadeInHeaven = RS.Stands.MadeInHeaven.MadeInHeaven,
}
local MAIN = { RootJoint = true, Neck = true, ["Left Shoulder"] = true, ["Right Shoulder"] = true, ["Left Hip"] = true, ["Right Hip"] = true }
local function joints(model)
	-- the rig's own joints first (an accessory's Motor6D can name a main limb
	-- as its Part1 - Star Platinum's knuckles), then any other chain (MIH's legs)
	local out = {}
	for pass = 1, 2 do
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 and not out[d.Part1.Name] then
				if (pass == 1 and MAIN[d.Name]) or (pass == 2 and not MAIN[d.Name] and string.find(d.Part0.Name, "Stand") ~= nil or (pass == 2 and d.Name == "LowerHip")) then
					out[d.Part1.Name] = { C1 = d.C1, Part0 = d.Part0.Name }
				end
			end
		end
	end
	return out
end

-- (a Pose eases only Linear / Constant / Elastic / Bounce / Cubic(V2): Moon's
-- smooth ones - Sine, Quad, Back... - become CubicV2 the same way round)
local EASE = { Linear = "Linear", Constant = "Constant", Elastic = "Elastic", Bounce = "Bounce" }

local function convert(saveName, outName)
	local s = saves:FindFirstChild(saveName)
	assert(s, "no save " .. saveName)
	local info = serde.decode("json", s.Value)
	local fps = (info.Information and info.Information.FPS) or 60
	local loop = info.Information and info.Information.Looped or false
	local item = info.Items[1]
	local rigName = item.Path.InstanceNames[#item.Path.InstanceNames]
	local rig = RIGS[rigName]
	assert(rig, "no rig for " .. saveName .. " (" .. tostring(rigName) .. ")")
	local J = joints(rig)
	local root = s:FindFirstChild("1"):FindFirstChild("Rig")
	-- frame -> { [part1] = { cf, style, dir } }
	local frames, order = {}, {}
	for _, track in root:GetChildren() do
		local part1 = string.match(track.Name, "%.([^%.]+)$") or track.Name
		local j = J[part1]
		assert(j, saveName .. ": no joint for " .. part1)
		for _, fr in track:GetChildren() do
			local n = tonumber(fr.Name)
			local v = fr.Values:FindFirstChild("0").Value
			local style, dir = "Linear", "In"
			local e = fr:FindFirstChild("Eases")
			local e0 = e and e:FindFirstChild("0")
			if e0 then
				local t = e0:FindFirstChild("Type")
				style = EASE[t and t.Value or "Linear"] or "CubicV2"
				local p = e0:FindFirstChild("Params")
				local d = p and p:FindFirstChild("Direction")
				dir = d and d.Value or "In"
			end
			if not frames[n] then
				frames[n] = {}
				table.insert(order, n)
			end
			frames[n][part1] = { cf = v:Inverse() * j.C1, style = style, dir = dir, parent = j.Part0 }
		end
	end
	table.sort(order)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = outName
	ks.Loop = loop
	ks.Priority = Enum.AnimationPriority.Action
	for _, n in order do
		local kf = Instance.new("Keyframe")
		kf.Time = n / fps
		kf.Parent = ks
		-- the pose tree: HumanoidRootPart > Torso > the rest (by each joint's Part0)
		local made = {}
		local hrp = Instance.new("Pose")
		hrp.Name = "HumanoidRootPart"
		hrp.Weight = 0
		hrp.Parent = kf
		made.HumanoidRootPart = hrp
		local function poseFor(name)
			if made[name] then
				return made[name]
			end
			local j = J[name]
			local parent = j and poseFor(j.Part0) or hrp
			local p = Instance.new("Pose")
			p.Name = name
			p.Weight = 0
			p.Parent = parent
			made[name] = p
			return p
		end
		for part1, k in frames[n] do
			local p = poseFor(part1)
			p.CFrame = k.cf
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle[k.style]
			p.EasingDirection = Enum.PoseEasingDirection[k.dir] or Enum.PoseEasingDirection.In
		end
	end
	print(("%s -> %s: %d keys, %.2fs at %d fps on %s, loop %s"):format(saveName, outName, #order, order[#order] / fps, fps, rigName, tostring(loop)))
	return ks
end

local jjba = Instance.new("Folder")
jjba.Name = "JJBA"
for _, n in { "Stands", "Clips" } do
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = jjba
end
for _, pair in {
	{ "SPBarrage.xsixx", "SP_BarrageLoop" },
	{ "TWBarrage.xsixx", "TW_BarrageLoop" },
	{ "CmoonBarrage.xsixx", "CM_BarrageLoop" },
	{ "MIH_Barrage.xsixx", "MIH_BarrageLoop" },
	{ "Cmoon_HeavyPunch.xsixx", "CM_HeavyPunch" },
	{ "Cmoon_Block.xsixx", "CM_Block" },
	{ "BlockTheWorld.xsixx", "TW_Block" },
	{ "starplatinum.xsixx", "SP_IdleMoon" },
} do
	local ok, ks = pcall(convert, pair[1], pair[2])
	if ok then
		ks.Parent = jjba.Clips
	else
		print("SKIP", pair[1], ks)
	end
end
fs.writeFile(process.args[2], roblox.serializeModel({ jjba }))
print("wrote", process.args[2])
