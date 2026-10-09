-- cd_check.luau <place.rbxl> <src/ReplicatedStorage.Shared.VFX.lua> <src/ReplicatedStorage.Shared.QuirkConfig.lua> <out.json>
-- (round 105) Crazy Diamond on the owner's Star Platinum model: VFX.JS's own
-- rig code and JS.paint (cut out of the VFX source), with Config.JJBA (cut
-- out of the config source), on the real model in the place - painted, its
-- hearts on, posed; frames written for render_parts.py.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local CFrame, Vector3, Color3, Enum, Instance = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum, roblox.Instance
local args = process.args
local place = roblox.deserializePlace(fs.readFile(args[1]))
local src = fs.readFile(args[2])
local cfgSrc = fs.readFile(args[3])
local JJBA = place:GetService("ReplicatedStorage"):FindFirstChild("JJBA")
local Config = { Pucci = { Model = { Bones = { upperR = { "chest", Vector3.new(1.17, 0.42, 0) } } } } }
local cenv = setmetatable({ Config = Config, Color3 = Color3, Vector3 = Vector3, CFrame = CFrame, Enum = Enum }, { __index = _G })
-- (Config.JJBA and what follows it, up to All Might's outfit: the JJBA
-- place's Stands, Jotaro, POM, the C-MOON cinematic, Crazy Diamond)
do
	local a = string.find(cfgSrc, "\nConfig.JJBA = {", 1, true)
	local b = a and string.find(cfgSrc, "\nConfig.AllMightOutfit = {", a, true)
	assert(a and b, "no Config.JJBA block in the config")
	luau.load(string.sub(cfgSrc, a, b), { environment = cenv })()
end
local function cut(from, to)
	local a = string.find(src, from, 1, true)
	assert(a, "no " .. from)
	local b = string.find(src, to, a, true)
	assert(b, "no " .. to)
	return string.sub(src, a, b - 1)
end
local code = cut("\tlocal function ease(u, style, dir)", "\t-- shown at alpha")
	.. cut("\tJS.ACTIONS = ", "\tfunction JS.cdv(")
	.. cut("\tfunction JS.paint(model, paint)", "\t-- THE CURVES")
local JS = { clips = {}, folder = function(name)
	return name and JJBA:FindFirstChild(name) or JJBA
end }
local env = setmetatable({
	JS = JS, JC = Config.JJBA, IDENT = CFrame.new(), Config = Config,
	MAIN = { RootJoint = true, Neck = true, ["Left Shoulder"] = true, ["Right Shoulder"] = true, ["Left Hip"] = true, ["Right Hip"] = true },
	TweenService = { GetValue = function(_, u)
		return u
	end },
	workspace = { BulkMoveTo = function(_, parts, cfs)
		for i, p in parts do
			p.CFrame = cfs[i]
		end
	end },
	warnOnce = function(k, e)
		print("WARN", k, e)
	end,
	CFrame = CFrame, Vector3 = Vector3, Color3 = Color3, Enum = Enum, Instance = Instance, ColorSequence = roblox.ColorSequence,
}, { __index = _G })
-- (the cut ends inside a block: "-- THE CURVES" sits under a divider line)
code = string.gsub(code, "\t%-%-%-%-%-*%s*$", "")
luau.load(code, { environment = env })()

local fails = 0
local function check(ok, what)
	fails += ok and 0 or 1
	print(ok and "ok  " or "FAIL", what)
end
local frames = {}
local function dump(r, dx)
	local parts = {}
	for _, p in r.parts do
		if (r.base[p] or 0) < 0.99 then
			local c = p.CFrame + Vector3.new(dx or 0, 0, 0)
			local shape = "box"
			pcall(function()
				if p.Shape == Enum.PartType.Ball then
					shape = "ball"
				end
			end)
			table.insert(parts, { cf = { c:GetComponents() }, size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { p.Color.R, p.Color.G, p.Color.B }, shape = shape, name = p.Name })
		end
	end
	return parts
end
local spec = Config.JJBA.Stands.CrazyDiamond
local C = spec.Paint.Colors
local base = CFrame.new(0, 5, 0)
local holder = Instance.new("Folder")
local r = JS.build("CrazyDiamond", holder)
local sp = JS.build("StarPlatinum", Instance.new("Folder"))
check(r ~= nil and r.byName.Torso ~= nil, "built from Star Platinum's model")
check(r.byName.Torso.Color == C.pink and r.byName["Right Arm"].Color == C.pink, "body pink (" .. tostring(r.byName.Torso.Color) .. ")")
check(sp.byName.Torso.Color ~= C.pink, "(Star Platinum itself untouched: " .. tostring(sp.byName.Torso.Color) .. ")")
check(r.base[r.byName.Hair] == 1, "hair hidden")
local hearts = {}
for _, p in r.parts do
	if p.Name == "Heart" then
		table.insert(hearts, p)
	end
end
check(#hearts == #spec.Paint.Hearts * 3, "hearts on (" .. #hearts .. " parts)")
check(r.byName.LeftArmDecor3.Color == C.armor and r.byName.LLegDecor1.Color == C.armor and r.base[r.byName.Skirt3] == 1, "shoulder pads and shins light blue, no loincloth")
local un = r.byName.LKnuckles
check(un and un.Color == C.trim, "the knuckles (a union) painted")
-- the hearts ride their limbs: pose the right arm out front and find the shoulder heart still on it
local T = {}
JS.poseT(r, { armR = { 0, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 } }, T)
JS.solve(r, base, T)
local arm = r.byName["Right Arm"]
local function nearest(p)
	local best, bd = nil, math.huge
	for _, h in hearts do
		local d = (h.CFrame.Position - p).Magnitude
		if d < bd then
			best, bd = h, d
		end
	end
	return best, bd
end
local h0 = nearest(arm.CFrame * Vector3.new(0.9, 0.45, 0))
local rel0 = arm.CFrame:ToObjectSpace(h0.CFrame)
table.clear(T)
JS.poseT(r, { armR = { 90, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 } }, T)
JS.solve(r, base, T)
local rel1 = arm.CFrame:ToObjectSpace(h0.CFrame)
check((rel0.Position - rel1.Position).Magnitude < 1e-3, "the shoulder heart rides the arm when it punches")
local outward = arm.CFrame:VectorToObjectSpace(h0.CFrame.LookVector)
print("     shoulder heart faces (arm space)", outward)
-- rest / jab / its barrage clip, beside Star Platinum
table.clear(T)
JS.poseT(r, { armR = { 0, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 } }, T)
JS.solve(r, base, T)
local T2 = {}
JS.poseT(sp, { armR = { 0, 0, 0 }, armL = { 0, 0, 0 }, legR = { 0, 0, 0 }, legL = { 0, 0, 0 }, head = { 0, 0 } }, T2)
JS.solve(sp, base, T2)
table.insert(frames, { label = "Star Platinum (the owner's model)", parts = dump(sp, 0) })
table.insert(frames, { label = "Crazy Diamond (painted)", parts = dump(r, 0) })
local c = JS.clip(spec.Barrage)
check(c ~= nil, "its barrage clip")
table.clear(T)
JS.sample(c, c.length * 0.4, T)
JS.solve(r, base, T)
table.insert(frames, { label = "Crazy Diamond: DORARARA (SP_BarrageLoop)", parts = dump(r, 0) })
c = JS.clip(spec.Pose)
table.clear(T)
JS.sample(c, c.length * 0.6, T)
JS.solve(r, base, T)
table.insert(frames, { label = "Crazy Diamond: its pose (SP_Pose)", parts = dump(r, 0) })
fs.writeFile(args[4], serde.encode("json", frames))
print(fails == 0 and "ALL OK" or (fails .. " FAILED"))
