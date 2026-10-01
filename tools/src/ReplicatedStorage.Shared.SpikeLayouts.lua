-- SpikeLayouts (ModuleScript) — ReplicatedStorage.Shared.SpikeLayouts
-- Deterministic ice-spike layouts. The caster picks a seed; every client builds
-- the spikes from it and the server carves the buildings with the exact same
-- spikes, so the holes in the map match the ice you see.
--
-- Each layout takes the ground point under the caster (and optionally a
-- snap(pos) -> the ground point under pos, or nil) and returns:
--   list      { { Base, Dir, Length, Thick, Delay, Collide }, ... }
--   growTime  seconds each spike takes to grow
--   anchor    the point the layout is built around (used by Heatwave's blast)
-- With snap, every spike grows out of the street right where it stands (a
-- curb, a slope, the street below a ledge) instead of the caster's height -
-- so nothing floats and nothing is buried. The caster's machine and the
-- server both snap against the same map, so the holes still match.

local UP = Vector3.new(0, 1, 0)

local Layouts = {}

-- Taper of one spike: { from, len, thick } as fractions of its length/thickness
Layouts.SEGMENTS = {
	{ from = 0.0, len = 0.58, thick = 1.0 },
	{ from = 0.5, len = 0.32, thick = 0.62 },
	{ from = 0.78, len = 0.22, thick = 0.3 },
}

local function add(list, base, dir, length, thick, delay, collide)
	table.insert(list, { Base = base, Dir = dir, Length = length, Thick = thick, Delay = delay, Collide = collide })
end

-- where a spike's base sits: `depth` studs into the street under `pos`
-- (the snapped ground if it's a sensible distance from the caster's)
local function seat(ground, pos, depth, snap)
	local y = ground.Y
	if snap then
		local hit = snap(Vector3.new(pos.X, ground.Y, pos.Z))
		if typeof(hit) == "Vector3" and hit.Y > ground.Y - 120 and hit.Y < ground.Y + 12 then
			y = hit.Y
		end
	end
	return Vector3.new(pos.X, y - depth, pos.Z)
end
Layouts.seat = seat

function Layouts.IceSpike(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 3
	local right = d:Cross(UP)
	local list = {}
	for i = 1, 8 do
		local s = i * 5.2
		local base = seat(ground, origin + d * s + right * rng:NextNumber(-1.5, 1.5), 1.5, snap)
		local dir = (UP + d * 0.55 + rng:NextUnitVector() * 0.25).Unit
		local length = 7 + i * 0.9 + rng:NextNumber(0, 3)
		add(list, base, dir, length, 1.6 + length * 0.1, i * 0.035, true)
	end
	return list, 0.14, origin
end

function Layouts.FrostBurst(ground, _d, seed, snap)
	local rng = Random.new(seed)
	local list = {}
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = seat(ground, ground + out * rng:NextNumber(5, 9), 1.5, snap)
		local dir = (UP * 1.2 + out * 0.8 + rng:NextUnitVector() * 0.2).Unit
		local length = rng:NextNumber(6, 11)
		add(list, base, dir, length, 1.5 + length * 0.12, rng:NextNumber(0, 0.08), true)
	end
	return list, 0.16, ground
end

-- HEAVEN-PIERCING ICE WALL (the ult): a glacier that starts at his foot
-- and fans out as it runs ahead of him - Width studs across at the far end,
-- climbing past the rooftops into the sky (the tallest spire is Height
-- studs). A spine of the biggest towers down the middle, two walls of
-- towers flanking it, a field of spikes between, ground cover at his feet.
-- Everything grows out of the ice sheet he lays down (the VFX builds that
-- sheet along d, just as wide).
Layouts.HEAVEN = { Length = 200, Height = 330, Width = 170 }
function Layouts.IceWall(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 5
	local right = d:Cross(UP)
	local list = {}
	local L, H, W = Layouts.HEAVEN.Length, Layouts.HEAVEN.Height, Layouts.HEAVEN.Width
	local function spreadAt(s)
		return 7 + s * (W / 2 - 7) / L -- half the width, at s studs out
	end
	for _ = 1, 64 do
		local k = rng:NextNumber() ^ 0.7 -- (more of them further out)
		local s = L * k
		local spread = spreadAt(s)
		local lat = rng:NextNumber(-1, 1) * spread
		local base = seat(ground, origin + d * s + right * lat, 2, snap)
		local dir = (UP * 2.4 + d * rng:NextNumber(0.2, 0.55) + right * (lat / spread) * rng:NextNumber(0.15, 0.4) + rng:NextUnitVector() * 0.08).Unit
		-- low near him, towering over the city at the far end (lower out at the edges)
		local edge = 1 - 0.45 * math.abs(lat / spread)
		local length = 14 + H * 0.8 * (k ^ 1.3) * edge * rng:NextNumber(0.5, 1)
		add(list, base, dir, length, 3.5 + length * 0.1, s / 160, true)
	end
	-- the spine: a row of the biggest towers down the middle, the last one
	-- the spire that pierces the sky
	for i = 1, 9 do
		local k = i / 9
		local s = L * (0.3 + 0.7 * k)
		local base = seat(ground, origin + d * s + right * rng:NextNumber(-3, 3), 2, snap)
		local dir = (UP * 3 + d * 0.22 + rng:NextUnitVector() * 0.04).Unit
		local length = H * (0.38 + 0.62 * k ^ 1.2)
		add(list, base, dir, length, 9 + length * 0.075, s / 160, true)
	end
	-- the walls: towers down both flanks, leaning out, a little shorter
	for side = -1, 1, 2 do
		for i = 1, 7 do
			local k = i / 7
			local s = L * (0.25 + 0.75 * k)
			local lat = side * spreadAt(s) * rng:NextNumber(0.5, 0.7)
			local base = seat(ground, origin + d * s + right * lat, 2, snap)
			local dir = (UP * 3 + d * 0.2 + right * side * 0.45 + rng:NextUnitVector() * 0.05).Unit
			local length = H * (0.22 + 0.45 * k) * rng:NextNumber(0.85, 1)
			add(list, base, dir, length, 7 + length * 0.07, s / 160 + 0.03, true)
		end
	end
	-- low ground cover round the root of the glacier (all the way across)
	for i = 1, 16 do
		local s = i * 3.2
		local lat = rng:NextNumber(-1, 1) * spreadAt(s)
		local base = seat(ground, origin + d * s + right * lat, 1.5, snap)
		local dir = (UP * 0.7 + d + right * (lat / math.max(spreadAt(s), 1)) * 0.5 + rng:NextUnitVector() * 0.3).Unit
		add(list, base, dir, rng:NextNumber(6, 12), 3.5, i * 0.02, true)
	end
	return list, 0.3, origin
end

function Layouts.Heatwave(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 6
	local right = d:Cross(UP)
	local list = {}
	for _ = 1, 22 do
		local s = rng:NextNumber(4, 34)
		local lat = rng:NextNumber(-1, 1) * (6 + s * 0.3)
		local base = seat(ground, origin + d * s + right * lat, 1.5, snap)
		local dir = (UP + d * rng:NextNumber(0.2, 0.7) + rng:NextUnitVector() * 0.25).Unit
		local length = rng:NextNumber(10, 22)
		add(list, base, dir, length, 2.4 + length * 0.1, s / 120, false)
	end
	return list, 0.18, origin
end

-- Ult: a huge frozen field. Spikes erupt in rings all around the caster.
function Layouts.GlacialField(ground, _d, seed, snap)
	local rng = Random.new(seed)
	local list = {}
	for ring = 1, 3 do
		local radius = 10 + ring * 9
		local count = 8 + ring * 6
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = seat(ground, ground + out * (radius + rng:NextNumber(-3, 3)), 2, snap)
			local dir = (UP * 1.3 + out * 0.6 + rng:NextUnitVector() * 0.2).Unit
			local length = 8 + ring * 6 + rng:NextNumber(0, 8)
			add(list, base, dir, length, 2 + length * 0.1, radius / 70 + rng:NextNumber(0, 0.06), true)
		end
	end
	return list, 0.2, ground
end

-- Ult: Flashfreeze Heatwave at full power. A glacier-sized ice mass to blow up.
function Layouts.HeatwaveMax(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 6
	local right = d:Cross(UP)
	local list = {}
	for _ = 1, 30 do
		local s = 60 * rng:NextNumber() ^ 0.8
		local spread = 6 + s * 0.4
		local lat = rng:NextNumber(-1, 1) * spread
		local base = seat(ground, origin + d * s + right * lat, 2, snap)
		local dir = (UP + d * rng:NextNumber(0.3, 0.9) + right * (lat / spread) * 0.5 + rng:NextUnitVector() * 0.2).Unit
		local length = 16 + s * 0.45 + rng:NextNumber(0, 12)
		add(list, base, dir, length, 2.8 + length * 0.09, s / 130, false)
	end
	return list, 0.2, origin
end

return Layouts
