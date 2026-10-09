-- export_fixture.luau <assets104.rbxl> <out.rbxm>: ReplicatedStorage.JJBA,
-- trimmed for the tests (the stands, the clips, the effects the code uses)
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
for _, n in { "DIOKNIFE", "RoadRoller", "POM", "LightHit", "HeavyHit" } do
	local e = J.Effects:FindFirstChild(n)
	if e then
		e:Clone().Parent = fx
	end
end
local pe = roblox.Instance.new("Folder")
pe.Name = "ParticleEffect"
pe.Parent = fx
for _, n in { "SP", "TW", "Cmoon", "MIH", "POM" } do
	local e = J.Effects.ParticleEffect:FindFirstChild(n)
	if e then
		e:Clone().Parent = pe
	end
end
fs.writeFile(process.args[2], roblox.serializeModel({ out }))
print("wrote", process.args[2], #out:GetDescendants(), "instances")
