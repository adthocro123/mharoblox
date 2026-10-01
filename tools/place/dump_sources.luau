-- Every script in a place as a file named by its full path, the way the
-- tests and rbxl_write.py expect (Script -> .server.lua, LocalScript ->
-- .client.lua, ModuleScript -> .lua):
-- lune run dump_sources.luau place.rbxl outdir
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local out = process.args[2]
fs.writeDir(out)
local SUFFIX = { Script = ".server.lua", LocalScript = ".client.lua", ModuleScript = ".lua" }
local n = 0
for _, d in game:GetDescendants() do
	local suffix = SUFFIX[d.ClassName]
	if suffix then
		fs.writeFile(out .. "/" .. d:GetFullName() .. suffix, d.Source)
		n += 1
	end
end
print(n .. " scripts -> " .. out)
