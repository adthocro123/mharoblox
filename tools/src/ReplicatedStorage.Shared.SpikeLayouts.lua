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

-- Taper of one spike: { from, len, thick } as fractions of its length/thickness.
-- (round 81) The crystals themselves are pointed blades now (VFX makeSpike:
-- two wedges folded into a V, half-width 0.52 * Thick at the base tapering to
-- the point), which sit inside the server's carve - 0.55 * Thick round the
-- lower 58%, 0.32 * Thick from half way to the tip (Destruction.Spikes).
-- This old three-step taper is kept for anything still reading it.
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

-- (round 81) A jagged wave racing out along the street: crystals zigzag
-- either side of the line, leaning forward (the way it's going) and out,
-- getting bigger as it goes, with low teeth along both flanks.
function Layouts.IceSpike(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 3
	local right = d:Cross(UP)
	local list = {}
	local side = rng:NextNumber() < 0.5 and 1 or -1
	for i = 1, 11 do
		local s = 1.5 + i * 3.9
		side = -side
		local base = seat(ground, origin + d * s + right * side * rng:NextNumber(0.3, 2.2), 1.5, snap)
		local dir = (UP + d * rng:NextNumber(0.45, 0.75) + right * side * rng:NextNumber(0.12, 0.4) + rng:NextUnitVector() * 0.12).Unit
		local length = 6 + i * 1.05 + rng:NextNumber(0, 3)
		add(list, base, dir, length, 2.2 + length * 0.14, s / 150, true)
	end
	for i = 1, 3 do
		local s = 6 + (i - 1) * 14 + rng:NextNumber(0, 5)
		local sd = i % 2 == 0 and 1 or -1
		local base = seat(ground, origin + d * s + right * sd * rng:NextNumber(3, 4.2), 1.5, snap)
		local dir = (UP * 0.8 + d * 0.4 + right * sd * 0.8 + rng:NextUnitVector() * 0.2).Unit
		local length = rng:NextNumber(4, 6.5)
		add(list, base, dir, length, 1.6 + length * 0.16, s / 150 + 0.02, true)
	end
	return list, 0.14, origin
end

-- (round 81) An explosion of frost round him: an inner ring of big crystals
-- bursting out and leaning away from him, and a second ring of smaller ones
-- thrown further out, a beat later and leaning harder.
function Layouts.FrostBurst(ground, _d, seed, snap)
	local rng = Random.new(seed)
	local list = {}
	local a0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, 11 do
		local a = a0 + (i / 11) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = seat(ground, ground + out * rng:NextNumber(4, 6.5), 1.5, snap)
		local dir = (UP * 1.1 + out * 0.9 + rng:NextUnitVector() * 0.2).Unit
		local length = rng:NextNumber(8, 13.5)
		add(list, base, dir, length, 2.6 + length * 0.2, rng:NextNumber(0, 0.05), true)
	end
	for i = 1, 13 do
		local a = a0 + ((i + 0.5) / 13) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = seat(ground, ground + out * rng:NextNumber(9, 12.5), 1.5, snap)
		local dir = (UP + out * 0.95 + rng:NextUnitVector() * 0.2).Unit
		local length = rng:NextNumber(4.5, 8)
		add(list, base, dir, length, 1.8 + length * 0.16, 0.07 + rng:NextNumber(0, 0.05), true)
	end
	return list, 0.16, ground
end

-- HEAVEN-PIERCING ICE WALL (the ult). (round 81) Rebuilt to the anime's
-- shape (the Sero match): his stomp sends a low RUN of feathered blades
-- racing out along the street, and 160 studs out the ice bursts into a
-- SUNBURST - dozens of long pointed blades fanned out from one point, the
-- middle one Height studs tall, the outer ones leaning 76 degrees out over
-- the street - round a MOUND of billowy ice, with a back row leaning on
-- like a breaking wave, teeth (the skirt) leaning back at him on its front,
-- and a low RIDGE of chunky blades out at both edges, so the hit's whole
-- width (it fans out to Width studs at the far end) is visibly iced.
-- Every entry keeps the fields the server's carve and the tests read
-- (Base, Dir, Length, Thick, Delay, Collide) and adds the blade's shape for
-- the VFX: Kind, Width, Depth (its thickness), Face (the way its broad face
-- looks: back toward him, mostly), Star (two blades crossed, so it's
-- pointed from every side), Hero (a highlight line down its ridge) and Grow
-- (its own growth time). Thick = 0.7 Width, so the carve (0.55 Thick)
-- matches the blade. Delays are seconds after the stomp: the run is laid at
-- 160 studs/s (the server's hits go at the same speed) and the crest bursts
-- at 0.9 s. A 4th return value, Peak, is the centre blade's tip (the VFX
-- aims the cloud punch at it).
Layouts.HEAVEN = { Length = 200, Height = 330, Width = 170, Focus = 160 }
function Layouts.IceWall(ground, d, seed, snap)
	local rng = Random.new(seed)
	local origin = ground + d * 5
	local right = d:Cross(UP)
	local list = {}
	local L, H, W = Layouts.HEAVEN.Length, Layouts.HEAVEN.Height, Layouts.HEAVEN.Width
	local FOCUS = Layouts.HEAVEN.Focus or 160
	local function U(a, b)
		return rng:NextNumber(a, b)
	end
	local function spreadAt(s)
		return 7 + s * (W / 2 - 7) / L -- half the width, at s studs out
	end
	-- the way a blade's broad face looks: back toward him (across the blade),
	-- turned `roll` radians about the blade
	local function faceOf(dir, roll)
		local n = -d - dir * (-d):Dot(dir)
		n = n.Magnitude > 1e-3 and n.Unit or right
		if roll and roll ~= 0 then
			n = (n * math.cos(roll) + dir:Cross(n) * math.sin(roll)).Unit
		end
		return n
	end
	-- a direction in the fan: phi out from straight up (+ = his right), then
	-- leaning `lean` radians on toward the far side (- = back at him)
	local function fan(phi, lean)
		local v = (UP * math.cos(phi) + right * math.sin(phi)).Unit
		return (v * math.cos(lean) + d * math.sin(lean)).Unit
	end
	local function blade(kind, base, dir, length, width, depth, delay, grow, face, star, hero)
		table.insert(list, {
			Base = base, Dir = dir, Length = length, Thick = width * 0.7, Delay = delay, Collide = true,
			Kind = kind, Width = width, Depth = depth, Face = face, Star = star == true, Hero = hero == true, Grow = grow,
		})
	end
	-- THE RUN: feathered shards out of his foot, lying almost flat along the
	-- street and pointing the way the ice goes, rearing up as they near the
	-- crest (tips ~6 high near him, ~45 halfway, ~70 at the crest)
	for i = 1, 44 do
		local k = (i - 1 + U(0, 1)) / 44
		local s = 4 + 142 * k ^ 0.9
		local spread = spreadAt(s)
		local lat = U(-0.95, 0.95) * spread
		local elev = math.rad(16 + 40 * k ^ 1.2 + U(-6, 6))
		local dir = (d * math.cos(elev) + UP * math.sin(elev) + right * (lat / spread) * 0.35).Unit
		local length = (8 + 84 * k ^ 1.4) * U(0.75, 1.15)
		local base = seat(ground, origin + d * s + right * lat, 2, snap)
		blade("Run", base, dir, length, math.max(2.5, length * 0.26), math.max(1.4, length * 0.11), s / 160, 0.22, faceOf(dir, math.rad(U(-35, 35))))
	end
	local F = origin + d * FOCUS
	-- THE MOUND: billowy frozen surf at the heart of the fan (the anime buries
	-- Sero in it)
	for _ = 1, 12 do
		local size = U(14, 30)
		local base = seat(ground, F + right * U(-32, 32) + d * U(-16, 16), 2, snap)
		blade("Mound", base, UP, size, size, size, FOCUS / 160 - 0.15, 0.2, -d)
	end
	-- THE CREST: the front row of the sunburst, fanned -76..76 degrees and
	-- leaning on 8-14 degrees; the middle one pierces heaven
	local peak
	for i = 0, 26 do
		local phi = math.rad(-76 + 152 * i / 26 + U(-3, 3))
		local c = math.abs(math.cos(phi))
		local dir = fan(phi, math.rad(U(8, 14)))
		local length = H * (0.28 + 0.72 * c ^ 1.8) * U(0.86, 1)
		if i == 13 then
			length = H
		end
		local base = seat(ground, F + right * math.sin(phi) * 16 + d * U(-5, 5), 2, snap)
		blade("Crest", base, dir, length, length * 0.15, math.max(1, length * 0.035), 0.9 + 0.18 * (1 - c), 0.35, faceOf(dir), c > 0.7, c > 0.9)
		if i == 13 then
			peak = base + dir * length
		end
	end
	-- the infill: shorter blades in front of the crest, massing its lower half
	for _ = 1, 12 do
		local phi = math.rad(U(-65, 65))
		local c = math.abs(math.cos(phi))
		local dir = fan(phi, math.rad(U(4, 16)))
		local length = U(70, 150) * (0.6 + 0.4 * c)
		local base = seat(ground, F - d * U(4, 12) + right * math.sin(phi) * 24, 2, snap)
		blade("Mid", base, dir, length, length * 0.2, math.max(1, length * 0.09), 0.92 + 0.12 * (1 - c), 0.3, faceOf(dir))
	end
	-- the back row, leaning on 20-28 degrees: the wave breaking on
	for i = 0, 12 do
		local phi = math.rad(-60 + 120 * i / 12 + U(-5, 5))
		local c = math.abs(math.cos(phi))
		local dir = fan(phi, math.rad(U(20, 28)))
		local length = H * (0.25 + 0.42 * c ^ 1.5) * U(0.85, 1)
		local base = seat(ground, F + d * U(12, 22) + right * math.sin(phi) * 20, 2, snap)
		blade("Back", base, dir, length, length * 0.15, math.max(1, length * 0.035), 1.02 + 0.15 * (1 - c), 0.4, faceOf(dir), true, c > 0.93)
	end
	-- the skirt: teeth on the crest's front, leaning back at him
	for _ = 1, 10 do
		local dir = fan(math.rad(U(-45, 45)), -math.rad(U(15, 35)))
		local length = U(30, 85)
		local base = seat(ground, F - d * U(12, 24) + right * U(-40, 40), 2, snap)
		blade("Skirt", base, dir, length, length * 0.24, length * 0.1, 0.95, 0.25, faceOf(dir, math.rad(U(-35, 35))))
	end
	-- the ridge: chunky low blades out at both edges of the far end
	for i = 1, 10 do
		local side = i % 2 == 0 and 1 or -1
		local s = U(150, 200)
		local base = seat(ground, origin + d * s + right * side * U(55, 85), 2, snap)
		local dir = (UP + d * 0.4 + right * side * 0.5 + rng:NextUnitVector() * 0.15).Unit
		local length = U(12, 30)
		blade("Ridge", base, dir, length, length * 0.3, length * 0.14, s / 160, 0.25, faceOf(dir, math.rad(U(-35, 35))))
	end
	return list, 0.3, origin, peak
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

-- Ult: a huge frozen field. (round 81) Not neat rings: clusters of crystals
-- erupt all over it - a tall one in the middle of each with smaller ones
-- leaning out of its foot, like a druse - taller out toward the rim, with
-- loose crystals scattered between, all in a wave out from the caster.
function Layouts.GlacialField(ground, _d, seed, snap)
	local rng = Random.new(seed)
	local list = {}
	local clusters = 11
	local a0 = rng:NextNumber(0, math.pi * 2)
	for c = 1, clusters do
		local a = a0 + (c / clusters) * math.pi * 2 + rng:NextNumber(-0.22, 0.22)
		local radius = rng:NextNumber(14, 36)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local center = ground + out * radius
		local big = 0.6 + 0.4 * (radius - 14) / 22 -- (taller toward the rim)
		for k = 1, rng:NextInteger(5, 8) do
			local lead = k == 1
			local spin = rng:NextNumber(0, math.pi * 2)
			local off = lead and Vector3.zero or Vector3.new(math.cos(spin), 0, math.sin(spin)) * rng:NextNumber(1.8, 6)
			local base = seat(ground, center + off, 2, snap)
			local lean = lead and out or off.Unit
			local dir = (UP * 1.3 + out * 0.45 + lean * (lead and 0.1 or 0.75) + rng:NextUnitVector() * 0.15).Unit
			local length = (lead and rng:NextNumber(24, 34) or rng:NextNumber(9, 19)) * big
			add(list, base, dir, length, 3 + length * 0.17, (center + off - ground).Magnitude / 70 + rng:NextNumber(0, 0.06), true)
		end
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(8, 40)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = seat(ground, ground + out * radius, 2, snap)
		local dir = (UP * 1.2 + out * 0.6 + rng:NextUnitVector() * 0.25).Unit
		local length = rng:NextNumber(6, 13)
		add(list, base, dir, length, 2.4 + length * 0.14, radius / 70 + rng:NextNumber(0, 0.06), true)
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

-- (round 81) ORIGIN: HALF-COLD HALF-HOT (the ult's R). The freezing wave he
-- opens every fight with (Deku vs Todoroki): low and fast down the street
-- from his right foot - spikes leaning the way it runs, growing as it goes
-- (about 3 studs at his foot, 9 at the far end) in two staggered rows across
-- the Lane, and a low crust down the middle. Range studs long, laid at Speed
-- studs a second (Delay = how far out / Speed). Not solid: it's the catch,
-- not a wall.
Layouts.ORIGIN = { Range = 48, Speed = 170, Lane = 9 }
function Layouts.OriginWave(ground, d, seed, snap)
	local rng = Random.new(seed)
	local O = Layouts.ORIGIN
	local right = d:Cross(UP)
	local origin = ground + d * 2 + right * 0.5
	local list = {}
	local n = 18
	for i = 1, n do
		local s = (i - 0.5) / n * O.Range
		local k = s / O.Range
		local lat = (i % 2 == 0 and 1 or -1) * O.Lane * rng:NextNumber(0.08, 0.42)
		local base = seat(ground, origin + d * s + right * lat, 1.2, snap)
		local dir = (UP + d * rng:NextNumber(0.55, 0.9) + right * (lat / O.Lane) * 0.5 + rng:NextUnitVector() * 0.12).Unit
		local length = 3.5 + 5.5 * k ^ 0.8 + rng:NextNumber(0, 1.5)
		add(list, base, dir, length, 1.6 + length * 0.2, s / O.Speed, false)
	end
	for i = 1, 8 do
		local s = i / 8 * O.Range
		local base = seat(ground, origin + d * s + right * rng:NextNumber(-1.5, 1.5), 1, snap)
		local dir = (UP * 0.6 + d + rng:NextUnitVector() * 0.2).Unit
		add(list, base, dir, rng:NextNumber(2.5, 4), 2.6, s / O.Speed, false)
	end
	return list, 0.12, origin
end

-- ...caught: a cage of glacier spikes round them where they stand - from a
-- ring round their feet, leaning in to chest height - with the wave's crest
-- piled up against them on its side (d = the way it ran). Not solid.
function Layouts.OriginCage(ground, d, seed, snap)
	local rng = Random.new(seed + 7)
	local list = {}
	local n = 9
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = seat(ground, ground + out * rng:NextNumber(2.6, 3.4), 0.8, snap)
		local tip = Vector3.new(ground.X, base.Y, ground.Z) + UP * rng:NextNumber(4.4, 6) + out * rng:NextNumber(0.9, 1.4)
		local v = tip - base
		add(list, base, v.Unit, v.Magnitude, 1.3 + v.Magnitude * 0.12, rng:NextNumber(0, 0.05), false)
	end
	local right = d:Cross(UP)
	for i = 1, 4 do
		local base = seat(ground, ground - d * rng:NextNumber(2.8, 3.6) + right * (i - 2.5) * 1.3, 1, snap)
		local dir = (UP * 1.3 + d * 0.8 + rng:NextUnitVector() * 0.1).Unit
		add(list, base, dir, rng:NextNumber(4.5, 6.5), 2.2, 0.02 * i, false)
	end
	return list, 0.14, ground
end

-- ...and the field (the shot at 2:11): tall white pillars standing out over
-- the street round them and between them, a clear lane left down the middle
-- for the fire and the ground round his own feet left clear (Clear studs:
-- he's framed close there). dist = how far along d they stand. Erupts from
-- him outward (Delay = s / 220). Only drawn, never carved or solid.
Layouts.ORIGIN.Clear = 11
function Layouts.OriginField(ground, d, seed, snap, dist)
	local rng = Random.new(seed + 13)
	dist = math.max(dist or 24, 8)
	local right = d:Cross(UP)
	local clear = Layouts.ORIGIN.Clear
	local list = {}
	for i = 1, 16 do
		local s = rng:NextNumber(math.min(clear * 0.75, dist), dist + 16)
		local near = math.abs(s - dist) < 6
		local lat = (i % 2 == 0 and 1 or -1) * rng:NextNumber(near and 6 or 4.5, 9 + s * 0.3)
		-- (pushed out along its row till it's clear of him)
		if s * s + lat * lat < clear * clear then
			s = math.sqrt(clear * clear - lat * lat)
		end
		local base = seat(ground, ground + d * s + right * lat, 2, snap)
		local dir = (UP * 3 + right * (lat > 0 and 1 or -1) * 0.25 + rng:NextUnitVector() * 0.3).Unit
		local length = rng:NextNumber(10, 26)
		add(list, base, dir, length, 2.8 + length * 0.12, s / 220, false)
	end
	return list, 0.16, ground + d * dist
end

return Layouts
