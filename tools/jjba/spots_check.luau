-- spots_check.luau <place.rbxl>: (round 106) where Kit.JI.spots puts the Stand
-- arrows and the Rokakaka (Config.JJBA.Items.Spots: Off 9, Up 3, Down 30), worked
-- out offline (every map part as its box - meshes as their bounding box)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local ws = game:GetService("Workspace")
local map = ws:FindFirstChild("Map")
local spawns = map.Spawns
local boxes = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") and not d:IsDescendantOf(spawns) then
		local ok, cc = pcall(function() return d.CanQuery end)
		if not ok or cc ~= false then
			local okS, size = pcall(function() return d.Size end)
			local okC, cf = pcall(function() return d.CFrame end)
			if okS and okC then
				table.insert(boxes, { cf = cf, inv = cf:Inverse(), h = size / 2, name = d:GetFullName() })
			end
		end
	end
end
print(#boxes, "boxes")
-- slab test in the box's space: the nearest t in [0, 1] along o + d*t
local function hit(o, d)
	local best, which = math.huge, nil
	for _, b in boxes do
		local lo = b.inv * o
		local ld = b.inv:VectorToWorldSpace(d)
		local t0, t1 = 0, 1
		local okb = true
		for _, ax in { "X", "Y", "Z" } do
			local oo, dd, hh = lo[ax], ld[ax], b.h[ax]
			if math.abs(dd) < 1e-9 then
				if oo < -hh or oo > hh then okb = false break end
			else
				local a, c = (-hh - oo) / dd, (hh - oo) / dd
				if a > c then a, c = c, a end
				t0, t1 = math.max(t0, a), math.min(t1, c)
				if t0 > t1 then okb = false break end
			end
		end
		if okb and t0 < best then
			best, which = t0, b
		end
	end
	return which and best, which
end
local off, up, down = 9, 3, 30
for _, pad in spawns:GetChildren() do
	if pad:IsA("BasePart") then
		local top = pad.CFrame.Position + Vector3.new(0, pad.Size.Y / 2 + 2.5, 0)
		local found
		for k = 0, 7 do
			local a = k * math.pi / 4
			local dir = Vector3.new(math.cos(a), 0, math.sin(a)) * off
			if not hit(top, dir) then
				local o = top + dir + Vector3.new(0, up, 0)
				local t, b = hit(o, Vector3.new(0, -(up + down), 0))
				if t then
					found = string.format("dir %d: ground at y=%.1f (pad top %.1f) on %s", k, o.Y - t * (up + down), pad.CFrame.Position.Y + pad.Size.Y / 2, b.name)
					break
				end
			end
		end
		print(string.format("pad (%.0f, %.0f, %.0f): %s", pad.CFrame.Position.X, pad.CFrame.Position.Y, pad.CFrame.Position.Z, found or "none - the pad itself"))
	end
end
