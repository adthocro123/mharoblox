-- Every instance's full name and class, sorted (diff two of these to see
-- what changed in a place): lune run dump_names.luau place.rbxl out.txt
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local out = {}
for _, d in game:GetDescendants() do
	table.insert(out, d:GetFullName() .. " [" .. d.ClassName .. "]")
end
table.sort(out)
fs.writeFile(process.args[2], table.concat(out, "\n"))
