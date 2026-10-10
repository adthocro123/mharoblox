-- Round 107: the new folders the Touhou place's things go in, and the game's
-- own stand-ins (ServerStorage.Touhou.Bridge, ReplicatedStorage.Packages.Knit),
-- as a place to graft from (assets107.py):
--   lune run kit107.luau <tools/src> <out.rbxl>
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local src, out = process.args[1], process.args[2]
local game = roblox.Instance.new("DataModel")
local function folder(parent, name)
	local f = roblox.Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function module(parent, name, file)
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Source = fs.readFile(src .. "/" .. file)
	m.Parent = parent
	return m
end
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local assets = folder(RS, "Assets")
folder(assets, "VFX")
local anims = folder(assets, "Animations")
folder(anims, "Characters")
folder(anims, "Combats")
local mods = folder(RS, "Modules")
folder(mods, "Util")
local packages = folder(RS, "Packages")
module(packages, "Knit", "ReplicatedStorage.Packages.Knit.lua")
local th = folder(RS, "Touhou")
folder(th, "Combats")
folder(RS, "Voicelines")
local sth = folder(SS, "Touhou")
folder(sth, "Attacks")
module(sth, "Bridge", "ServerStorage.Touhou.Bridge.lua")
folder(SS, "ModelStorage")
local ra = folder(SS, "ReplicatedAssets123")
folder(ra, "Models")
fs.writeFile(out, roblox.serializePlace(game))
print("kit ->", out)
