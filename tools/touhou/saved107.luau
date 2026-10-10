-- Round 107: the animations whose keyframes the Touhou place itself still
-- has (saved copies in AnimSaves and the like - 27 of the 185, matched by
-- their names on Roblox: saved107.json). Each goes to
-- reupload107/<old id>.rbxm (for reupload_anims.py --upload-only, from the
-- new account alone), and all of them into one model (to publish by hand).
--   lune run saved107.luau <Touhou place.rbxl> saved107.json <out dir>
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local matches = serde.decode("json", fs.readFile(process.args[2]))
local outDir = process.args[3]
local weak = { ["17373814145"] = true, ["18810371910"] = true, ["128675044478123"] = true, ["137701041431404"] = true,
	["138941292691749"] = true, ["114680013127948"] = true, ["128875824406345"] = true }
local byPath = {}
for _, d in game:GetDescendants() do
	if d:IsA("KeyframeSequence") and not byPath[d:GetFullName()] then
		byPath[d:GetFullName()] = d
	end
end
local root = roblox.Instance.new("Folder")
root.Name = "Touhou saved animations (round 107)"
local sure = roblox.Instance.new("Folder")
sure.Name = "Name matches"
sure.Parent = root
local maybe = roblox.Instance.new("Folder")
maybe.Name = "Check these (generic or shared names)"
maybe.Parent = root
local n = 0
for id, m in matches do
	local ks = byPath[m.path]
	assert(ks, "not found: " .. m.path)
	local one = ks:Clone()
	one.Name = id
	one:SetAttribute("OldId", id)
	one:SetAttribute("RobloxName", m.name)
	fs.writeFile(outDir .. "/reupload107/" .. id .. ".rbxm", roblox.serializeModel({ one }))
	local copy = ks:Clone()
	copy.Name = id .. "  " .. tostring(m.name)
	copy:SetAttribute("OldId", id)
	copy.Parent = weak[id] and maybe or sure
	n += 1
end
fs.writeFile(outDir .. "/touhou_saved_anims.rbxm", roblox.serializeModel({ root }))
print(n, "exported")
