-- js_check.luau <assets104.rbxl> <vfx_js.lua> <cfg_jjba.lua> <out.json>
-- Runs VFX.JS's own rig code (cut out of the piece) on the JJBA place's
-- stands: builds each rig, poses it (CDV angles, its own clips, C-MOON bones)
-- and checks the limbs land where they should; writes frames for the render.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local CFrame, Vector3, Color3, Enum = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum
local args = process.args
local place = roblox.deserializePlace(fs.readFile(args[1]))
local src = fs.readFile(args[2])
local JJBA = place:GetService("ReplicatedStorage"):FindFirstChild("JJBA")
assert(JJBA, "no JJBA folder")

local Config = { Pucci = { Model = { Bones = { upperR = { "chest", Vector3.new(1.17, 0.42, 0) } } } } }
luau.load(fs.readFile(args[3]), { environment = setmetatable({ Config = Config, Color3 = Color3, Vector3 = Vector3, CFrame = CFrame, Enum = Enum }, { __index = _G }) })()

local function cut(from, to)
	local a = string.find(src, from, 1, true)
	assert(a, "no " .. from)
	local b = string.find(src, to, a, true)
	assert(b, "no " .. to)
	return string.sub(src, a, b - 1)
end
local code = cut("\tlocal function ease(u, style, dir)", "\t-- shown at alpha")
	.. cut("\tJS.ACTIONS = ", "\tfunction JS.cdv(")
	.. cut("\tfunction JS.limbRot(a, b)", "\tif CM then")
local moved = 0
local JS = {
	clips = {},
	folder = function(name)
		return name and JJBA:FindFirstChild(name) or JJBA
	end,
	on = function()
		return true
	end,
	show = function() end,
	dress = function() end,
	cmHide = function() end,
}
local env = setmetatable({
	JS = JS, JC = Config.JJBA, IDENT = CFrame.new(), Config = Config,
	MAIN = { RootJoint = true, Neck = true, ["Left Shoulder"] = true, ["Right Shoulder"] = true, ["Left Hip"] = true, ["Right Hip"] = true },
	TweenService = { GetValue = function(_, u)
		return u
	end },
	workspace = { BulkMoveTo = function(_, parts, cfs)
		for i, p in parts do
			p.CFrame = cfs[i]
			moved += 1
		end
	end },
	warnOnce = function(k, e)
		print("WARN", k, e)
	end,
	CFrame = CFrame, Vector3 = Vector3, Color3 = Color3, Enum = Enum,
}, { __index = _G })
luau.load(code, { environment = env })()

local frames, fails = {}, 0
local function check(ok, what)
	if not ok then
		fails += 1
		print("FAIL", what)
	else
		print("ok  ", what)
	end
end
local function dump(r, label, dx)
	local parts = {}
	for _, p in r.parts do
		local c = p.CFrame + Vector3.new(dx or 0, 0, 0)
		local comps = { c:GetComponents() }
		local alpha = (r.base[p] or 0) >= 0.99 and 0.12 or 1
		local shape = "box"
		pcall(function()
			if p.Shape == Enum.PartType.Ball then
				shape = "ball"
			elseif p.Shape == Enum.PartType.Cylinder then
				shape = "cyl"
			end
		end)
		table.insert(parts, { cf = comps, size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { p.Color.R, p.Color.G, p.Color.B }, alpha = alpha, shape = shape })
	end
	return parts
end
local function frame(label, ...)
	local parts = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(parts, p)
		end
	end
	table.insert(frames, { label = label, parts = parts })
end
local function angle(a, b)
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- CDV's poses (VFX: CDV.POSES)
local POSES = {
	idle = { armR = { 78, 58, 0 }, armL = { 72, 58, 0 }, legR = { 12, 0, 5 }, legL = { -8, 0, 6 }, head = { -6, 0 }, lean = -4 },
	jabR = { armR = { 96, 2, 0 }, armL = { 52, 36, 0 }, legR = { -22, 0, 4 }, legL = { 28, 0, 4 }, head = { -6, 0 }, lean = -18, twist = 30 },
	zero = { armR = { 0, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 }, lean = 0, twist = 0 },
}
local base = CFrame.new(0, 5, 0)
for _, kind in { "StarPlatinum", "TheWorld" } do
	local holder = roblox.Instance.new("Folder")
	local r = JS.build(kind, holder)
	local nAnim = 0
	for _ in r.animBy do
		nAnim += 1
	end
	check(nAnim == 6, kind .. ": 6 moving joints (" .. nAnim .. ")")
	-- the rest pose: every main part where the R6 rig puts it
	local T = {}
	JS.poseT(r, POSES.zero, T)
	JS.solve(r, base, T)
	local torso, arm = r.byName.Torso, r.byName["Right Arm"]
	check((torso.CFrame.Position - base.Position).Magnitude < 0.6, kind .. ": torso on the root at rest")
	local rel = torso.CFrame:PointToObjectSpace(arm.CFrame.Position)
	check(rel.X > 1.2 and math.abs(rel.Y) < 0.6, kind .. ": right arm at the torso's right at rest (" .. tostring(rel) .. ")")
	check(angle(-arm.CFrame.UpVector, Vector3.new(0, -1, 0)) < 3, kind .. ": right arm hangs straight down at rest")
	frame(kind .. " rest", dump(r, "rest"))
	-- the jab: the right arm straight out in front
	table.clear(T)
	JS.poseT(r, { armR = { 90, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 } }, T)
	JS.solve(r, base, T)
	check(angle(-arm.CFrame.UpVector, base.LookVector) < 3, kind .. ": pitch 90 puts the right arm out in front (" .. string.format("%.1f", angle(-arm.CFrame.UpVector, base.LookVector)) .. " deg)")
	table.clear(T)
	JS.poseT(r, POSES.jabR, T)
	JS.solve(r, base, T)
	frame(kind .. " jabR", dump(r, "jab"))
	table.clear(T)
	JS.poseT(r, POSES.idle, T)
	JS.solve(r, base, T)
	frame(kind .. " CDV idle (arms crossed)", dump(r, "idle"))
	-- its own clips
	local spec = Config.JJBA.Stands[kind]
	for _, key in { "Idle", "Barrage", "Heavy" } do
		local c = spec[key] and JS.clip(spec[key])
		check(c ~= nil, kind .. ": clip " .. tostring(spec[key]))
		if c then
			table.clear(T)
			JS.sample(c, c.length * 0.4, T)
			local n = 0
			for _ in T do
				n += 1
			end
			check(n >= 5, kind .. ": " .. spec[key] .. " moves " .. n .. " joints")
			JS.solve(r, base, T)
			frame(kind .. " clip " .. spec[key] .. " @40%", dump(r, key))
		end
	end
end

-- C-MOON on synthetic bones (CM.fk's offsets): at rest, then the right arm
-- raised straight forward (shoulder pitch 90) and the left one out to the side
local function bones(rootCF, armR, armL, legR)
	local W = {}
	W.pelvis = rootCF
	W.waist = W.pelvis * CFrame.new(0, 0.42, 0)
	W.chest = W.waist * CFrame.new(0, 1.3, 0)
	W.head = W.chest * CFrame.new(0, 0.98, 0.04)
	W.upperR = W.chest * CFrame.new(1.17, 0.42, 0) * (armR or CFrame.new())
	W.upperL = W.chest * CFrame.new(-1.17, 0.42, 0) * (armL or CFrame.new())
	W.foreR, W.foreL = W.upperR * CFrame.new(0, -1.25, 0), W.upperL * CFrame.new(0, -1.25, 0)
	W.fistR, W.fistL = W.foreR * CFrame.new(0, -1.12, 0), W.foreL * CFrame.new(0, -1.12, 0)
	W.thighR = W.pelvis * CFrame.new(0.47, -0.16, 0) * (legR or CFrame.new())
	W.thighL = W.pelvis * CFrame.new(-0.47, -0.16, 0)
	W.shinR, W.shinL = W.thighR * CFrame.new(0, -1.36, 0), W.thighL * CFrame.new(0, -1.36, 0)
	W.footR, W.footL = W.shinR * CFrame.new(0, -1.18, 0), W.shinL * CFrame.new(0, -1.18, 0)
	-- MADE IN HEAVEN's horse (Heaven.Horse offsets don't matter here: only turns are used)
	W.hbody = W.pelvis * CFrame.new(0, -0.3, 1.2)
	W.hupR, W.hupL = W.hbody * CFrame.new(0.6, -0.6, -1), W.hbody * CFrame.new(-0.6, -0.6, -1)
	W.hlowR, W.hlowL = W.hupR * CFrame.new(0, -1.2, 0), W.hupL * CFrame.new(0, -1.2, 0)
	return W
end
local function partsOf(r, names)
	local out = {}
	for _, n in names do
		out[n] = r.byName[n]
	end
	return out
end
for _, case in { { "CMoon", false }, { "MadeInHeaven", true } } do
	local kind, heaven = case[1], case[2]
	local holder = roblox.Instance.new("Model")
	local rig = { model = holder, heaven = heaven, s = 1 }
	rig.W = bones(base)
	local used = JS.cmPlace(rig)
	check(used == true, kind .. ": placed on Pucci's bones")
	local r = rig.js[kind]
	local P = partsOf(r, { "Torso", "Right Arm", "Left Arm", "Right Leg", "Head", "StandLowerTorso" })
	check(angle(P.Torso.CFrame.UpVector, Vector3.new(0, 1, 0)) < 2, kind .. ": torso upright at rest")
	check(angle(-P["Right Arm"].CFrame.UpVector, Vector3.new(0, -1, 0)) < 3, kind .. ": right arm down at rest")
	local rest = dump(r, "rest")
	-- (the rest pose of its own rig: every joint at T = I from the torso)
	if heaven then
		local tr = P.Torso.CFrame:ToObjectSpace(P.StandLowerTorso.CFrame)
		local j
		for _, jj in r.joints do
			if jj.name == "LowerHip" then
				j = jj
			end
		end
		local want = j.c0 * j.c1:Inverse()
		check(angle(tr.LookVector, want.LookVector) < 2 and (tr.Position - want.Position).Magnitude < 0.05, kind .. ": the horse half sits as the rig has it at rest")
	end
	-- the right arm forward, the left out to the side, the right leg kicked forward
	rig.W = bones(base, CFrame.Angles(math.rad(90), 0, 0), CFrame.Angles(0, 0, math.rad(-80)), CFrame.Angles(math.rad(60), 0, 0))
	JS.cmPlace(rig)
	local wantR = (rig.W.fistR.Position - rig.W.upperR.Position)
	check(angle(-P["Right Arm"].CFrame.UpVector, wantR) < 3, kind .. ": right arm follows shoulder->fist (" .. string.format("%.1f", angle(-P["Right Arm"].CFrame.UpVector, wantR)) .. " deg)")
	local wantL = (rig.W.fistL.Position - rig.W.upperL.Position)
	check(angle(-P["Left Arm"].CFrame.UpVector, wantL) < 3, kind .. ": left arm follows shoulder->fist")
	if P["Right Leg"] then
		local wantLeg = rig.W.footR.Position - rig.W.thighR.Position
		check(angle(-P["Right Leg"].CFrame.UpVector, wantLeg) < 3, kind .. ": right leg follows hip->foot")
	end
	local shoulderGap = (P["Right Arm"].CFrame * Vector3.new(0, P["Right Arm"].Size.Y / 2, 0) - rig.W.upperR.Position).Magnitude
	print(string.format("     %s: right arm's top %.2f studs from C-MOON's shoulder bone", kind, shoulderGap))
	frame(kind .. " rest", rest)
	frame(kind .. " R arm fwd / L arm out / R leg kick", dump(r, "posed"))
end

fs.writeFile(args[4], serde.encode("json", frames))
print(fails == 0 and "ALL OK" or (fails .. " FAILED"), "parts moved", moved)
