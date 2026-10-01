-- compiles every source at every optimization / debug / coverage level
-- (Studio keeps full debug info: constant locals then take registers too)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local dir = process.args[1]
local bad = 0
for _, name in fs.readDir(dir) do
	if name:match("%.lua$") then
		local src = fs.readFile(dir .. "/" .. name)
		for o = 0, 2 do
			for g = 0, 2 do
				for c = 0, 2 do
					local ok, err = pcall(luau.compile, src, { optimizationLevel = o, debugLevel = g, coverageLevel = c })
					if not ok then
						bad += 1
						print(string.format("FAIL %s O%d g%d c%d: %s", name, o, g, c, (tostring(err):match("^[^\n]*"))))
					end
				end
			end
		end
	end
end
print(bad == 0 and ("all sources compile at every level: " .. dir) or (bad .. " failures: " .. dir))
