-- export_fixture.luau <assets.rbxl> <out.rbxm>: ReplicatedStorage.JJBA,
-- trimmed for the tests (the stands, the clips, the effects the code uses);
-- (round 106) and a second root: the clips of ReplicatedStorage.Animations
-- the Stand arrow and the Rokakaka play
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local J = game:GetService("ReplicatedStorage").JJBA
local out = roblox.Instance.new("Folder")
out.Name = "JJBA"
J.Stands:Clone().Parent = out
J.Clips:Clone().Parent = out
local fx = roblox.Instance.new("Folder")
fx.Name = "Effects"
fx.Parent = out
for _, n in { "DIOKNIFE", "RoadRoller", "POM", "LightHit", "HeavyHit", "Cmoon" } do -- (round 105: Cmoon - the C-MOON cinematic's scene)
	local e = J.Effects:FindFirstChild(n)
	if e then
		e:Clone().Parent = fx
	end
end
local pe = roblox.Instance.new("Folder")
pe.Name = "ParticleEffect"
pe.Parent = fx
for _, n in { "SP", "TW", "Cmoon", "MIH", "POM", "GetStand" } do -- (round 106: GetStand - the arrow's burst)
	local e = J.Effects.ParticleEffect:FindFirstChild(n)
	if e then
		e:Clone().Parent = pe
	end
end
-- (round 106) the Stand arrows and the Rokakaka: on the street and in the hand
for _, n in { "Items", "Held" } do
	local f = J:FindFirstChild(n)
	if f then
		f:Clone().Parent = out
	end
end
local anims = roblox.Instance.new("Folder")
anims.Name = "Animations"
for _, n in { "MoveStandArrow", "MoveRokakakaEat" } do
	local ks = game:GetService("ReplicatedStorage").Animations:FindFirstChild(n)
	if ks then
		ks:Clone().Parent = anims
	end
end
fs.writeFile(process.args[2], roblox.serializeModel({ out, anims }))
print("wrote", process.args[2], #out:GetDescendants(), "instances +", #anims:GetChildren(), "clips")
