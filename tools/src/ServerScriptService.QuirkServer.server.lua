-- QuirkServer (Script) — ServerScriptService.QuirkServer
-- Authoritative side: validates cooldowns, runs hitboxes on the same timeline
-- the clients animate, applies damage / knockback / stun / freeze, and relays
-- each cast to the other players so they can render it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("QuirkConfig"))
local SpikeLayouts = require(Shared:WaitForChild("SpikeLayouts"))
local Destruction = require(script.Parent:WaitForChild("Destruction"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseAbility = Remotes:WaitForChild("UseAbility")
local SelectQuirk = Remotes:WaitForChild("SelectQuirk")
local PlayVFX = Remotes:WaitForChild("PlayVFX")
local TestCommand = Remotes:WaitForChild("TestCommand")
-- the shop's remote is made here, so older copies of the place work too
local SettingsRemote = Remotes:FindFirstChild("Settings")
if not SettingsRemote then
	SettingsRemote = Instance.new("RemoteEvent")
	SettingsRemote.Name = "Settings"
	SettingsRemote.Parent = Remotes
end
local ShopRemote = Remotes:FindFirstChild("Shop")
if not ShopRemote then
	ShopRemote = Instance.new("RemoteEvent")
	ShopRemote.Name = "Shop"
	ShopRemote.Parent = Remotes
end

Players.RespawnTime = (Config.Fights and Config.Fights.RespawnTime) or 3

local UP = Vector3.new(0, 1, 0)
local COOLDOWN_TOLERANCE = 0.15

local cooldowns = {} -- [player] = { [key] = lastUsed }
-- Bucks, the shop, items, the hero outfit and the dev toys (filled in near the
-- end of the script, once everything they use exists)
local Store = {}
local m1State = {} -- [player] = { Count, Last, NextAllowed }
local stunTokens = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Moves in progress: each runs in its own thread, which knows whose move
-- it is. When someone's moves are cut short (frozen solid: cutMoves), every
-- check a move of theirs makes on them from then on - alive(char), between
-- its steps - says no, so it stops the way it would if they'd been knocked
-- out (and cleans up the same way). Hits on them, and everyone else's
-- moves, go on as normal.
local Moves = {
	of = setmetatable({}, { __mode = "k" }), -- [thread] = { Char, Epoch }
	cuts = setmetatable({}, { __mode = "k" }), -- [char] = how many times their moves were cut short
}

local function alive(char)
	local hum = char and char.Parent and char:FindFirstChildOfClass("Humanoid")
	if hum == nil or hum.Health <= 0 then
		return false
	end
	local move = Moves.of[coroutine.running()]
	return not (move and move.Cuttable and move.Char == char and (Moves.cuts[char] or 0) > move.Epoch)
end

-- the move this thread is running (so a helper it starts can carry on as
-- part of it), and marking a thread as one
function Moves.current()
	return Moves.of[coroutine.running()]
end
function Moves.join(move)
	Moves.of[coroutine.running()] = move
end

-- cut short every move they have going
function Moves.cut(char)
	Moves.cuts[char] = (Moves.cuts[char] or 0) + 1
end

-- is this thread a move that's been cut short? (it lands nothing more)
function Moves.stopped()
	local move = Moves.of[coroutine.running()]
	return move ~= nil and move.Cuttable and (Moves.cuts[move.Char] or 0) > move.Epoch
end

-- Roblox's Avatar Joint Upgrade swaps R15 characters' Motor6Ds for
-- AnimationConstraints on live servers. Every move pose, the ragdoll and the
-- movement pack work on Motor6Ds, so a body that arrives upgraded gets its
-- Motor6Ds back (the place also opts out: StarterPlayer.AvatarJointUpgrade =
-- Disabled). Clients wait for the ClassicJoints attribute before posing it.
local function classicJoints(model)
	local replaced = 0
	for _, joint in model:GetDescendants() do
		if joint:IsA("AnimationConstraint") then
			local a0, a1 = joint.Attachment0, joint.Attachment1
			local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local motor = Instance.new("Motor6D")
				motor.Name = joint.Name
				motor.Part0 = p0
				motor.Part1 = p1
				motor.C0 = a0.CFrame
				motor.C1 = a1.CFrame
				motor.Parent = joint.Parent
				joint:Destroy()
				replaced += 1
			end
		end
	end
	if replaced > 0 then
		-- (the loose ball sockets that come with the upgrade: our ragdoll makes its own)
		for _, socket in model:GetDescendants() do
			if socket:IsA("BallSocketConstraint") then
				socket:Destroy()
			end
		end
	end
	model:SetAttribute("ClassicJoints", true)
	return replaced
end

local function flatten(v, root)
	local f = typeof(v) == "Vector3" and Vector3.new(v.X, 0, v.Z) or Vector3.zero
	if f.Magnitude < 0.05 or f.Magnitude ~= f.Magnitude then
		local look = root.CFrame.LookVector
		f = Vector3.new(look.X, 0, look.Z)
	end
	return f.Unit
end

local function sanitizeDir(v, root)
	if typeof(v) ~= "Vector3" or v.Magnitude ~= v.Magnitude or v.Magnitude < 0.01 then
		return root.CFrame.LookVector
	end
	return v.Unit
end

local function sanitizePos(v, root, dir)
	if typeof(v) ~= "Vector3" or v.Magnitude ~= v.Magnitude then
		return root.Position + dir * 30
	end
	local offset = v - root.Position
	if offset.Magnitude > 300 then
		return root.Position + offset.Unit * 300
	end
	return v
end

-- one set of query params per attacker (rebuilt if the map/shops folders change)
local paramsCache = setmetatable({}, { __mode = "k" })
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" or child.Name == "Shops" then
		table.clear(paramsCache)
	end
end)
local function overlapParams(caster)
	local cached = caster and paramsCache[caster]
	if cached then
		return cached
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { caster }
	-- (the map, and the snack machines and shopkeepers: attacks pass through them)
	for _, name in { "Map", "Shops" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	params.FilterDescendantsInstances = list
	if caster then
		paramsCache[caster] = params
	end
	return params
end

local function collect(parts, hitSet)
	local seen, out = {}, {}
	for _, part in parts do
		local model = part.Parent
		if model and model:IsA("Accessory") then
			model = model.Parent
		end
		if model and model:IsA("Model") and not seen[model] and not (hitSet and hitSet[model]) then
			seen[model] = true
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart") then
				table.insert(out, model)
			end
		end
	end
	return out
end

local function queryRadius(caster, pos, radius, hitSet)
	return collect(workspace:GetPartBoundsInRadius(pos, radius, overlapParams(caster)), hitSet)
end

local function queryBox(caster, cf, size, hitSet)
	return collect(workspace:GetPartBoundsInBox(cf, size, overlapParams(caster)), hitSet)
end

-- Lag compensation (Config.Hitboxes): a short history of where every body
-- stood, so a player's hitbox also counts whoever was inside it on their
-- screen. Rewind.QueryBox / QueryRadius = queryBox / queryRadius plus that.
local Rewind = {}
do
	local HB = Config.Hitboxes or {}
	local SIZE, STEP = 16, 1 / 30 -- ~half a second kept
	local history = setmetatable({}, { __mode = "k" }) -- [model] = ring buffer of { time, position }
	local BODY = Vector3.new(1, 2.5, 1) -- half a body: its centre within this of the box counts
	local function record(model, now)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local h = history[model]
		if not h then
			h = { i = 0, t = {}, p = {} }
			history[model] = h
		end
		h.i = h.i % SIZE + 1
		h.t[h.i] = now
		h.p[h.i] = root.Position
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < STEP or HB.LagCompensation == false then
			return
		end
		acc = 0
		local now = os.clock()
		for _, plr in Players:GetPlayers() do
			if plr.Character then
				record(plr.Character, now)
			end
		end
		local dummies = workspace:FindFirstChild("Dummies")
		for _, model in dummies and dummies:GetChildren() or {} do
			record(model, now)
		end
	end)

	-- where a body stood at time t (os.clock), between the two samples around it
	function Rewind.PositionAt(model, t)
		local h = history[model]
		if not h then
			return nil
		end
		local newerT, newerP
		for k = 0, SIZE - 1 do
			local idx = (h.i - k - 1) % SIZE + 1
			local st = h.t[idx]
			if not st then
				break
			end
			if st <= t then
				if newerT then
					return h.p[idx]:Lerp(newerP, math.clamp((t - st) / math.max(newerT - st, 1e-3), 0, 1))
				end
				return h.p[idx]
			end
			newerT, newerP = st, h.p[idx]
		end
		return newerP
	end

	-- how far back this player sees everyone else (0: no rewind)
	function Rewind.Delay(player)
		if not player or HB.LagCompensation == false then
			return 0
		end
		local ok, ping = pcall(function()
			return player:GetNetworkPing()
		end)
		if not ok or type(ping) ~= "number" or ping ~= ping then
			return 0
		end
		return math.clamp(ping + (HB.InterpDelay or 0.05), 0, HB.MaxRewind or 0.25)
	end

	-- anyone not already found whose body was where `inside(pos)` says, back then
	local function rewound(player, caster, found, hitSet, inside)
		local delay = Rewind.Delay(player)
		if delay <= 0.01 then
			return found
		end
		local seen = {}
		for _, m in found do
			seen[m] = true
		end
		local t = os.clock() - delay
		for model in history do
			if model ~= caster and not seen[model] and not (hitSet and hitSet[model]) and model.Parent then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local p = hum and hum.Health > 0 and Rewind.PositionAt(model, t)
				if p and inside(p) then
					table.insert(found, model)
				end
			end
		end
		return found
	end

	function Rewind.QueryBox(player, caster, cf, size, hitSet)
		local half = size / 2 + BODY
		return rewound(player, caster, queryBox(caster, cf, size, hitSet), hitSet, function(p)
			local lp = cf:PointToObjectSpace(p)
			return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
		end)
	end

	function Rewind.QueryRadius(player, caster, pos, radius, hitSet)
		return rewound(player, caster, queryRadius(caster, pos, radius, hitSet), hitSet, function(p)
			return (p - pos).Magnitude <= radius + 1.5
		end)
	end
end

local function nonMapStuff(caster)
	local list = { caster }
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	for _, name in { "Dummies", "MapDebris", "TwiceClones", "NomuRaid" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	return list
end

local function groundBelow(pos, caster)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(caster)
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

local function isGrounded(root, caster, reach)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	return workspace:Raycast(root.Position, Vector3.new(0, -(reach or 7), 0), params) ~= nil
end

local function broadcast(effectId, casterChar, data, exceptPlayer)
	for _, plr in Players:GetPlayers() do
		if plr ~= exceptPlayer then
			PlayVFX:FireClient(plr, effectId, casterChar, data)
		end
	end
end

local ULT = Config.Ult
local studioCharge = RunService:IsStudio() and (ULT.StudioChargeMultiplier or 1) or 1
local iFrames = setmetatable({}, { __mode = "k" }) -- [model] = os.clock() until invulnerable
-- Limitless: Infinity. Nothing reaches him while it's up (no damage, no knockback)
local infinityUntil = setmetatable({}, { __mode = "k" }) -- [model] = os.clock()
local function untouchable(model)
	-- (Infinity - and anyone sat at an UNO table in Tony's: no fighting there)
	return (infinityUntil[model] or 0) > os.clock() or model:GetAttribute("PlayingUno") == true
end
-- Finishers: [victim] = the player finishing them (nobody else can hit them
-- meanwhile), and who went down to one (the kill feed says FINISHED)
local finishing = setmetatable({}, { __mode = "k" })
local finishedBy = setmetatable({}, { __mode = "k" })
-- Overhaul's kaiju shrugs off part of every hit
local KAIJU = (Config.FindAbilityById and Config.FindAbilityById("Kaiju")) or {}

local function addUlt(player, amount)
	if not player or player:GetAttribute("UltActive") then
		return
	end
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	if not quirk or not quirk.Ult then
		return
	end
	local rate = tonumber(workspace:GetAttribute("UltRate")) or 1 -- (server settings)
	player:SetAttribute("Ult", math.min(100, (player:GetAttribute("Ult") or 0) + amount * studioCharge * rate))
end

local GUARD = Config.Guard or {}
local FIGHTS = Config.Fights or {}
local guardState = setmetatable({}, { __mode = "k" }) -- [character] = guard meter + blocking state
local parryImmune = setmetatable({}, { __mode = "k" }) -- [character] = os.clock() until the parried combo can't land
local lastHit = setmetatable({}, { __mode = "k" }) -- [character] = { Player, Time } for KO credit
local lives = {} -- [player] = fight stats since the last spawn (the KO recap)

-- Set up in the GUARD section below (it needs stun + knockback, defined later).
-- Returns true when the hit was absorbed by a guard (blocked, parried or it broke the guard).
local resolveGuard
-- Lemillion's Permeation (set up with his moves): Pass(attacker, model, opts)
-- is true when a hit goes straight through him; OnAttack(char) ends Permeate
local Permeation = {}

local function newLife()
	return { Start = os.clock(), Dealt = 0, Taken = 0, Hits = 0, KOs = 0, Parries = 0, Blocked = 0, BiggestHit = 0 }
end

-- opts (optional): { GuardDamage = extra guard-meter damage, From = Vector3 the hit came from,
--   Hitstop = seconds both fighters freeze on contact, Heavy = true for the big hit reaction,
--   Unblockable = true when no guard or parry can stop it (the NUKE),
--   NoCap = true to go past Config.Balance.MaxHitShare }
-- things a character can do when a hit is about to land on them (set up
-- with the moves below: All Might's Hero's Counter)
local Reactions = {}
-- when each body last fought ([model] = os.clock() of its last hit given,
-- taken or blocked): out-of-combat healing waits on it (Config.Regen)
Reactions.fought = setmetatable({}, { __mode = "k" })
-- super armour ([model] = { Until = os.clock(), Scale = x damage }): hits
-- still land (for Scale of their damage) but can't stun, ragdoll or move him
Reactions.armor = setmetatable({}, { __mode = "k" })
function Reactions.armored(model)
	local a = Reactions.armor[model]
	return a ~= nil and a.Until > os.clock() and a or nil
end
-- the ragdoll cancel's meter (Config.Evasive; set up with the ragdoll below)
local Evasive = {}

local function damage(attacker, model, amount, opts)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or Moves.stopped() then
		return false
	end
	-- (round 69) one of Twice's doubles: his own hits go through it, and
	-- hitting one charges nobody's ult (it's mud)
	local double = model:GetAttribute("TwiceClone")
	if double and attacker and attacker.UserId == double then
		return false
	end
	-- (round 71: Config.Clash) locked in a clash, nothing else touches them -
	-- and a clash move landing on someone whose own is out and aimed back is
	-- a clash, not a hit
	if model:GetAttribute("Clashing") or (Reactions.CL and Reactions.CL.try(attacker, model)) then
		return false
	end
	-- (round 71: Config.NomuRaid) a Nomu in the city: near it, it's a truce
	if Reactions.NR and Reactions.NR.truce(attacker, model) then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and victim:GetAttribute("GodMode") then
		return false
	end
	-- (round 74) stopped in DIO's time: the hit waits for it to move (Kit.TS)
	if Reactions.TS and Reactions.TS.hold(attacker, model, amount, opts) then
		return true
	end
	if (iFrames[model] or 0) > os.clock() then
		broadcast("Dodge", nil, { Target = model })
		return false
	end
	if untouchable(model) then
		-- the hit slows to a stop just short of him
		local ac = attacker and attacker.Character
		local ar = ac and ac:FindFirstChild("HumanoidRootPart")
		broadcast("InfinityStop", nil, { Target = model, From = (opts and opts.From) or (ar and ar.Position) or nil })
		return false
	end
	if (parryImmune[model] or 0) > os.clock() then
		return false
	end
	if finishing[model] and finishing[model] ~= attacker then
		return false -- someone is finishing them: nobody steals it
	end
	if not finishing[model] and Permeation.Pass and Permeation.Pass(attacker, model, opts) then
		return false -- it went straight through him
	end
	-- (round 59: Config.Ragdoll.DownImmune) nobody hits someone lying in the
	-- street - only a downslam, the move that put them there, a finisher
	if model:GetAttribute("Ragdolled") and not Reactions.hitsDowned(attacker, model, opts) then
		return false
	end
	-- (round 60) Creati's shield held up, or a wall she planted, between them
	if Reactions.shielded and Reactions.shielded(attacker, model, amount, opts) then
		return false
	end
	if Reactions.Counter and attacker and Reactions.Counter(attacker, model, opts) then
		return false -- All Might saw it coming
	end
	if Reactions.DangerSense and attacker and Reactions.DangerSense(attacker, model, opts) then
		return false -- Deku felt it coming and he's already moved
	end
	if attacker and attacker:GetAttribute("UltActive") then
		amount *= ULT.DamageMultiplier
	end
	local attackerChar = attacker and attacker.Character
	local gear = attackerChar and attackerChar:GetAttribute("Gearshift")
	if gear then
		if not Reactions.gearBonus then
			local gs = Config.FindAbilityById("Gearshift")
			Reactions.gearBonus = gs and gs.DamagePerGear or 0
		end
		amount *= 1 + Reactions.gearBonus * gear -- (Deku's Gearshift: harder a gear at a time)
	end
	if attackerChar and (attackerChar:GetAttribute("TriggeredUntil") or 0) > workspace:GetServerTimeNow() then
		amount *= Config.Items.Trigger.DamageBoost or 1.25 -- on Trigger
	end
	if model:GetAttribute("Kaiju") then
		amount *= KAIJU.DamageTaken or 0.5
	end
	amount *= tonumber(workspace:GetAttribute("DamageMult")) or 1 -- (server settings)
	-- (down on the street: only the move that put them there hits them in full)
	amount *= Reactions.downedScale(model, opts)
	local armor = Reactions.armored(model)
	if armor then
		amount *= armor.Scale or 0.5
	end
	-- (Config.Balance) nothing one-shots: no single hit takes more than a share
	-- of their max health
	local share = Config.Balance and Config.Balance.MaxHitShare
	if share and not (opts and opts.NoCap) and not double then
		amount = math.min(amount, hum.MaxHealth * share)
	end
	-- (a fight: both of them stop healing - a blocked hit counts too)
	Reactions.fought[model] = os.clock()
	if attackerChar then
		Reactions.fought[attackerChar] = os.clock()
	end
	if resolveGuard and not (opts and opts.Unblockable) and resolveGuard(attacker, model, amount, opts) then
		return false -- the guard took it: no knockback / stun follow-up
	end
	amount = math.floor(amount + 0.5)
	-- credit first: a lethal TakeDamage can fire Died before this function returns
	model:SetAttribute("LastHitBy", attacker and attacker.Name or "")
	if attacker then
		lastHit[model] = { Player = attacker, Time = os.clock(), Amount = amount }
		local life = lives[attacker]
		if life then
			life.Dealt += amount
			life.Hits += 1
			life.BiggestHit = math.max(life.BiggestHit, amount)
		end
	end
	if victim and lives[victim] then
		lives[victim].Taken += amount
	end
	if Reactions.NR and model:GetAttribute("Boss") then
		Reactions.NR.hit(attacker, model, amount) -- (round 71: the raid's damage board)
	end
	hum:TakeDamage(amount)
	if hum.Health <= 0 then
		Reactions.ko(attacker, model, opts)
	else
		Reactions.knockdown(model, amount, opts)
		Reactions.comboHit(model, amount, attacker and attacker.Character) -- (round 68: Config.Combos)
	end
	broadcast("Hit", nil, {
		Target = model,
		Amount = amount,
		Attacker = attacker,
		Hitstop = opts and opts.Hitstop or nil,
		Heavy = opts and opts.Heavy or nil,
	})
	if not double then
		addUlt(attacker, amount * ULT.GainPerDamageDealt)
	end
	addUlt(victim, amount * ULT.GainPerDamageTaken)
	if Evasive.gain and not double then
		Evasive.gain(model, amount, false)
		if attackerChar and attackerChar ~= model then
			Evasive.gain(attackerChar, amount, true)
		end
	end
	return true
end

local RAGDOLL = Config.Ragdoll or {}
local ragdoll -- (model, seconds) - defined with the ragdoll below; big knockbacks use it

-- Inserting a LinearVelocity replicates to whoever owns the target's physics,
-- so this works on players (client-owned) and NPCs (server-owned) alike.
-- A hit this hard knocks you off your feet (Config.Ragdoll.MinSpeed), and a
-- limp body is pushed with a bounded force so it tumbles instead of launching.
-- raw: an M1 or the dash punch - their push is the combo's spacing, so
-- Config.Knockback (moves shove less far) leaves it alone
local function knockback(model, velocity, duration, raw)
	-- (round 74) stopped in DIO's time: the push waits too
	if Reactions.TS and Reactions.TS.push(model, velocity, duration) then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored or untouchable(model) or Reactions.armored(model) then
		return
	end
	-- (the dev menu's knockback multiplier)
	velocity *= tonumber(workspace:GetAttribute("KnockbackMult")) or 1
	-- how hard the hit was (whether it knocks them off their feet, and for how
	-- long) is judged on the move's full force...
	local strength = velocity.Magnitude
	-- ...but (Config.Knockback) a move shoves them less far: sideways x
	-- MoveScale, the lift x MoveLift; a spike down keeps its full force
	if not raw then
		local KB = Config.Knockback or {}
		local side = KB.MoveScale or 1
		velocity = Vector3.new(velocity.X * side, velocity.Y > 0 and velocity.Y * (KB.MoveLift or 1) or velocity.Y, velocity.Z * side)
	end
	-- a spike down on someone already standing on the street would just drive
	-- them into it (the solver spits them out sideways): it stays flat
	if velocity.Y < -20 and isGrounded(root, model, 3.8) then
		velocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
	-- one push at a time: a new hit replaces the last one instead of two
	-- pushes fighting over the body (that tug-of-war threw people about)
	for _, d in root:GetChildren() do
		if d.Name == "Knockback" or d.Name == "KnockbackAttachment" then
			d:Destroy()
		end
	end
	-- (round 68: Config.Combos) held in a combo: the shove kept short, so
	-- they're still in reach of the next hit, and it never knocks them off
	-- their feet (a launcher's lift - Keep - is left alone)
	local held = not raw and Reactions.comboHeld(model)
	if held and not Reactions.comboKeep() then
		local C = Config.Combos or {}
		local across = Vector3.new(velocity.X, 0, velocity.Z)
		local cap = C.MaxShove or 38
		if across.Magnitude > cap then
			across = across.Unit * cap
		end
		velocity = Vector3.new(across.X, math.min(velocity.Y, C.MaxLift or 42), across.Z)
	end
	local speed = strength
	local minSpeed = RAGDOLL.MinSpeed or 100
	if RAGDOLL.OnMoves ~= false and speed >= minSpeed and not held and not model:GetAttribute("Ragdolled") then
		local t = RAGDOLL.Time or 1.3
		ragdoll(model, math.clamp(t + (speed - minSpeed) / 250, t, RAGDOLL.MaxTime or 2.2))
	end
	local limp = model:GetAttribute("Ragdolled") == true
	if limp then
		velocity *= RAGDOLL.KnockbackScale or 0.8
	end
	local att = Instance.new("Attachment")
	att.Name = "KnockbackAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Knockback"
	lv.Attachment0 = att
	-- strong but finite: an unlimited push into a wall or the street is what
	-- makes the physics spit a body out sideways
	local okMass, mass = pcall(function()
		return root.AssemblyMass
	end)
	mass = (okMass and type(mass) == "number" and mass > 0) and mass or 10
	lv.MaxForce = limp and (RAGDOLL.MaxForce or 30000) or mass * 12000
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = velocity
	lv.Parent = root
	Debris:AddItem(lv, duration or 0.2)
	Debris:AddItem(att, duration or 0.2)
	-- body slam: strong knockback smashes the target through whatever it flies into
	local slamSpeed = Config.Destruction and Config.Destruction.SlamSpeed or 110
	if velocity.Magnitude >= slamSpeed then
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.5 and root.Parent do
				local v = root.AssemblyLinearVelocity
				if v.Magnitude < 30 then
					v = velocity
				end
				Destruction.Sphere(root.Position + v.Unit * 2.5, 3.4, "Impact", v.Unit)
				task.wait(0.06)
			end
		end)
	end
end

local function restoreMovement(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	model:SetAttribute("Stunned", false)
	model:SetAttribute("StunUntil", nil)
	hum.WalkSpeed = model:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
	hum.JumpPower = model:GetAttribute("BaseJumpPower") or Config.BaseJumpPower
	if model:GetAttribute("Frozen") then
		model:SetAttribute("Frozen", false)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
	end
end

-- (server settings: a player given No Stun can't be stunned or ragdolled)
function Reactions.stunProof(model)
	local owner = Players:GetPlayerFromCharacter(model)
	return (owner ~= nil and owner:GetAttribute("NoStun") == true) or Reactions.armored(model) ~= nil
end

local function stun(model, duration, walkSpeed)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or Reactions.stunProof(model) then
		return
	end
	local now = workspace:GetServerTimeNow()
	duration = math.max(duration, (model:GetAttribute("StunUntil") or 0) - now)
	local token = (stunTokens[model] or 0) + 1
	stunTokens[model] = token
	model:SetAttribute("StunUntil", now + duration)
	model:SetAttribute("CombatActionUntil", nil)
	model:SetAttribute("Stunned", true)
	hum.UseJumpPower = true
	hum.WalkSpeed = walkSpeed or 3
	hum.JumpPower = 0
	task.delay(duration, function()
		if stunTokens[model] == token and model.Parent then
			restoreMovement(model)
		end
	end)
end

---------------------------------------------------------------------------
-- (round 68) COMBOS (Config.Combos): Suneater's, Deku's, All Might's and
-- Creati's moves chain. A hit from one of their moves (not one of their
-- Enders) holds the target in HITSTUN where they stand instead of knocking
-- them down or ragdolling them - nothing hits someone lying in the street,
-- so every move used to end the combo - and the shove is kept short
-- (knockback: Reactions.comboHeld) so the next move or the M1s reach. The
-- ragdoll cancel breaks out of it (Evasive.use: ComboStun).
---------------------------------------------------------------------------
Reactions.comboHold = setmetatable({}, { __mode = "k" }) -- [model] = { Until = os.clock(), By = the comboer's char }
Reactions.comboTokens = setmetatable({}, { __mode = "k" })
function Reactions.combosOn()
	local C = Config.Combos
	return C ~= nil and C.Enabled ~= false and workspace:GetAttribute("Combos") ~= false
end
-- the move this thread is running, if it's a combo hero's that chains (not
-- an Ender) and it's landing on someone else: its ability and their body.
-- A hit from a thread a move started on the side (an air blast on its way,
-- a shell coming down) has no move of its own: `by`'s latest one counts,
-- if it's that recent (Reactions.lastMove: Kit.lastMove)
function Reactions.comboMove(model, by)
	if not Reactions.combosOn() then
		return nil
	end
	local move = Moves.of[coroutine.running()]
	local ability = move and move.Ability
	local char = move and move.Char
	if not move and by and Reactions.lastMove then
		local last = Reactions.lastMove[by]
		if last and os.clock() - last.Time < 2.5 then
			ability, char = last.Ability, by
		end
	end
	if not ability or not char or char == model then
		return nil
	end
	local C = Config.Combos
	if not (C.Heroes or {})[char:GetAttribute("Quirk") or ""] or ability.Ender or (C.Enders or {})[ability.Id or ""]
		or (C.UltMovesEnd ~= false and Reactions.ultMove(ability)) then
		return nil
	end
	return ability, char
end
-- one of an ult form's moves (they end a combo: Config.Combos.UltMovesEnd)
function Reactions.ultMove(ability)
	local set = Reactions.ultIds
	if not set then
		set = {}
		for _, spec in Config.Quirks do
			local U = type(spec) == "table" and spec.Ult
			if type(U) == "table" then
				for _, a in U.Abilities or {} do
					set[a.Id or ""] = true
				end
				for _, k in { "Extra", "Special" } do
					if type(U[k]) == "table" and U[k].Id then
						set[U[k].Id] = true
					end
				end
			end
		end
		set[""] = nil
		Reactions.ultIds = set
	end
	return set[ability.Id or ""] == true
end
-- a launcher (Config.Combos.Keep): its lift is the combo - left alone
function Reactions.comboKeep()
	local move = Moves.of[coroutine.running()]
	local ability = move and move.Ability
	return ability ~= nil and ((Config.Combos or {}).Keep or {})[ability.Id or ""] == true
end
-- held in a combo right now: by this thread's move, or - a beat after one of
-- its hits, from a thread with no move of its own (a shove or a slam it
-- left to happen a moment later). Any other move - an Ender, someone
-- else's - isn't held back.
function Reactions.comboHeld(model)
	if Reactions.comboMove(model) then
		return true
	end
	local hold = Reactions.comboHold[model]
	if not hold or hold.Until <= os.clock() or not Reactions.combosOn() then
		return false
	end
	return Moves.of[coroutine.running()] == nil
end
-- a combo hit landed (damage): hitstun where they stand - Base + damage x
-- PerDamage, at most Max (a move's own longer stun still wins) - flagged
-- ComboStun so the ragdoll cancel can break out of it
function Reactions.comboHit(model, amount, by)
	local ability, char = Reactions.comboMove(model, by)
	if not ability then
		return
	end
	local S = Config.Combos.Stun or {}
	local t = math.min((S.Base or 0.65) + (amount or 0) * (S.PerDamage or 0.02), S.Max or 1.2)
	Reactions.comboHold[model] = { Until = os.clock() + t + 0.25, By = char }
	if model:GetAttribute("Ragdolled") or Reactions.stunProof(model) then
		return
	end
	stun(model, t)
	Reactions.comboFlag(model, t)
end
-- ComboStun on them for as long as the stun lasts
function Reactions.comboFlag(model, t)
	if not model:GetAttribute("Stunned") then
		return
	end
	local left = math.max(t, (model:GetAttribute("StunUntil") or 0) - workspace:GetServerTimeNow())
	local token = (Reactions.comboTokens[model] or 0) + 1
	Reactions.comboTokens[model] = token
	model:SetAttribute("ComboStun", true)
	task.delay(left, function()
		if Reactions.comboTokens[model] == token and model.Parent then
			model:SetAttribute("ComboStun", nil)
		end
	end)
end
-- a ragdoll a combo move asks for (the end of a slam, a throw) keeps them
-- on their feet instead: hitstun, in reach
function Reactions.comboRagdoll(model, duration)
	if not Reactions.comboHeld(model) then
		return false
	end
	local S = Config.Combos.Stun or {}
	local t = math.min(math.max((duration or 1) * 0.8, S.Base or 0.65), S.Max or 1.2)
	stun(model, t)
	Reactions.comboFlag(model, t)
	return true
end
-- the rest of this move ends the combo, whatever it is (CLAM HAMMER, the
-- air Swordfish: spiked into the street - a knockdown, like a downslam)
function Reactions.comboEnder()
	local co = coroutine.running()
	local move = Moves.of[co]
	if move and move.Ability and not move.Ability.Ender then
		Moves.of[co] = { Char = move.Char, Epoch = move.Epoch, Cuttable = move.Cuttable, Ability = setmetatable({ Ender = true }, { __index = move.Ability }) }
	end
end

-- Slow without stunning (you can still fight back). Players' clients cap
-- their speed at the SlowedTo attribute; NPCs are slowed directly.
local slowTokens = setmetatable({}, { __mode = "k" })
local function slow(model, duration, speed)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local token = (slowTokens[model] or 0) + 1
	slowTokens[model] = token
	model:SetAttribute("SlowedTo", speed)
	if not model:GetAttribute("Stunned") then
		hum.WalkSpeed = math.min(hum.WalkSpeed, speed)
	end
	task.delay(duration, function()
		if slowTokens[model] ~= token or not model.Parent then
			return
		end
		model:SetAttribute("SlowedTo", nil)
		if not model:GetAttribute("Stunned") then
			hum.WalkSpeed = model:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
		end
	end)
end

-- Ragdoll: swap every joint (except the root) for a physical joint - elbows
-- and knees become hinges that only bend the natural way, the rest get
-- ball-sockets with per-joint limits - and give the limbs hidden colliders so
-- they rest on the ground. Joined parts never collide with each other (that
-- fight is what used to fling bodies across the map), and on the way back up
-- the body is stood upright above the ground before the joints snap back.
local ragdollTokens = setmetatable({}, { __mode = "k" })

-- degrees: Cone = how far off-axis, Twist = the swing around the joint's X axis
-- (forward / back for arms, legs and the spine on R15)
local JOINT_LIMITS = {
	Neck = { Cone = 25, Twist = { -25, 25 } },
	Waist = { Cone = 20, Twist = { -25, 30 } },
	RightShoulder = { Cone = 80, Twist = { -80, 110 } },
	LeftShoulder = { Cone = 80, Twist = { -80, 110 } },
	RightHip = { Cone = 45, Twist = { -60, 90 } },
	LeftHip = { Cone = 45, Twist = { -60, 90 } },
	RightWrist = { Cone = 15, Twist = { -20, 20 } },
	LeftWrist = { Cone = 15, Twist = { -20, 20 } },
	RightAnkle = { Cone = 15, Twist = { -20, 20 } },
	LeftAnkle = { Cone = 15, Twist = { -20, 20 } },
}
-- elbows bend forward (+), knees bend backward (-)
local HINGES = {
	RightElbow = { -5, 140 },
	LeftElbow = { -5, 140 },
	RightKnee = { -140, 5 },
	LeftKnee = { -140, 5 },
}

-- (round 63) Which way up a ragdolled body lies: "Up" on its back, "Down"
-- face down, nil if it isn't lying down (still more or less upright)
function Reactions.lyingFace(model)
	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
	if not torso then
		return nil
	end
	if torso.CFrame.UpVector.Y > 0.55 then
		return nil
	end
	return torso.CFrame.LookVector.Y < -0.2 and "Down" or "Up"
end

-- Stand a body upright on the ground where it lies. (round 63) Lying down:
-- right under the torso, turned so the get-up clip starts where it lies -
-- on its back with its head behind it (it sits up facing its feet), face
-- down with its head in front (it pushes up facing that way). Otherwise it
-- keeps its heading.
local function standUp(model, face)
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local torso = model:FindFirstChild("LowerTorso") or model:FindFirstChild("Torso") or root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local head = Vector3.new(torso.CFrame.UpVector.X, 0, torso.CFrame.UpVector.Z)
	if face and head.Magnitude > 0.3 then
		look = face == "Down" and head or -head
	elseif look.Magnitude < 0.2 then
		look = Vector3.new(-root.CFrame.UpVector.X, 0, -root.CFrame.UpVector.Z) -- lying face down
	end
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local ground = groundBelow(torso.Position + UP * 2, model)
	local hip = hum.HipHeight
	local height = ((hip and hip > 0) and hip or 2) + root.Size.Y / 2
	local pos = Vector3.new(torso.Position.X, math.max(ground.Y + height, face and ground.Y + height or torso.Position.Y), torso.Position.Z)
	root.CFrame = CFrame.lookAt(pos, pos + look.Unit)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function setRagdoll(model, on)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
	if on then
		for _, motor in model:GetDescendants() do
			if motor:IsA("Motor6D") and motor.Enabled and motor.Name ~= "Root" and motor.Name ~= "RootJoint"
				and motor.Part0 and motor.Part1 and not motor:FindFirstAncestorOfClass("Accessory") then
				local a0 = Instance.new("Attachment")
				a0.Name = "RagdollAttachment"
				a0.CFrame = motor.C0
				a0.Parent = motor.Part0
				local a1 = Instance.new("Attachment")
				a1.Name = "RagdollAttachment"
				a1.CFrame = motor.C1
				a1.Parent = motor.Part1
				local hinge = HINGES[motor.Name]
				local joint
				if hinge then
					joint = Instance.new("HingeConstraint")
					joint.LimitsEnabled = true
					joint.LowerAngle = hinge[1]
					joint.UpperAngle = hinge[2]
				else
					local lim = JOINT_LIMITS[motor.Name] or { Cone = motor.Name:find("Neck") and 30 or 60, Twist = { -35, 35 } }
					joint = Instance.new("BallSocketConstraint")
					joint.LimitsEnabled = true
					joint.UpperAngle = lim.Cone
					joint.TwistLimitsEnabled = true
					joint.TwistLowerAngle = lim.Twist[1]
					joint.TwistUpperAngle = lim.Twist[2]
				end
				-- (round 63) friction in the joint: heavy limbs, no flailing or shivering
				local friction = RAGDOLL.JointFriction or 25
				if joint:IsA("BallSocketConstraint") then
					joint.Restitution = 0
					joint.MaxFrictionTorque = motor.Name:find("Neck") and friction * 0.6 or friction
				else
					joint.Restitution = 0
					joint.ActuatorType = Enum.ActuatorType.Motor
					joint.AngularVelocity = 0
					joint.MotorMaxTorque = friction * 0.6
				end
				joint.Name = "RagdollSocket"
				joint.Attachment0 = a0
				joint.Attachment1 = a1
				joint.Parent = motor.Part1
				-- the two halves of a joint never push each other apart
				local nc = Instance.new("NoCollisionConstraint")
				nc.Name = "RagdollSocket"
				nc.Part0 = motor.Part0
				nc.Part1 = motor.Part1
				nc.Parent = motor.Part1
				motor.Enabled = false
			end
		end
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local c = Instance.new("Part")
				c.Name = "RagdollCollider"
				c.Size = Vector3.new(math.max(part.Size.X * 0.7, 0.4), math.max(part.Size.Y * 0.7, 0.4), math.max(part.Size.Z * 0.7, 0.4))
				c.CFrame = part.CFrame
				c.Transparency = 1
				c.CanCollide = true
				c.CanQuery = false
				c.CanTouch = false
				c.Massless = true
				-- (no bounce, a grip on the street: it comes to rest, it doesn't skate)
				c.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.9, 0, 1, 100)
				local w = Instance.new("WeldConstraint")
				w.Part0 = part
				w.Part1 = c
				w.Parent = c
				c.Parent = part
				c.CollisionGroup = "Ragdoll" -- (after parenting: nothing may move it back to Characters)
			end
		end
		-- the root box would dig into the ground while he's lying down
		if root then
			if model:GetAttribute("RootCollide") == nil then
				model:SetAttribute("RootCollide", root.CanCollide)
			end
			root.CanCollide = false
		end
		model:SetAttribute("Ragdolled", true)
		-- players' own clients switch their Humanoid to Physics (they own it)
		if hum and not isPlayer then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			-- (round 63) the limbs set off with the body (they don't trail the push)
			if root then
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") and part ~= root then
						part.AssemblyLinearVelocity = root.AssemblyLinearVelocity
					end
				end
			end
		end
	else
		local face = Reactions.lyingFace(model) -- (round 63: read before the joints come back)
		local remove = {}
		for _, d in model:GetDescendants() do
			if d.Name == "RagdollSocket" or d.Name == "RagdollAttachment" or d.Name == "RagdollCollider" then
				table.insert(remove, d)
			end
		end
		for _, d in remove do
			d:Destroy()
		end
		-- NPCs: stand up first, then the joints snap back (players' clients do
		-- the same for themselves - they own their bodies)
		if hum and not isPlayer and hum.Health > 0 then
			standUp(model, face)
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and not d:GetAttribute("Limp") then
				d.Enabled = true
			end
		end
		if root and model:GetAttribute("RootCollide") ~= nil then
			root.CanCollide = model:GetAttribute("RootCollide")
			model:SetAttribute("RootCollide", nil)
		end
		model:SetAttribute("Ragdolled", false)
		if hum and not isPlayer and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if hum and hum.Health > 0 then
			broadcast("GetUp", model, { Face = face }) -- (the get-up animation, on every screen)
		end
	end
end

ragdoll = function(model, duration)
	if Reactions.TS and Reactions.TS.rag(model, duration) then
		return -- (round 74: stopped in DIO's time - later)
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or model:GetAttribute("Frozen") or RAGDOLL.Enabled == false or Reactions.stunProof(model) then
		return
	end
	-- (round 68: Config.Combos) a combo hero's move keeps them on their feet,
	-- in hitstun and in reach
	if Reactions.comboRagdoll(model, duration) then
		return
	end
	-- (Config.Ragdoll.Strength) the harder the hit that put them down, the
	-- longer they stay down: x (Base + damage / PerDamage), Min..Max - and a
	-- touch longer across the board (Longer), never past Cap
	local RS = RAGDOLL.Strength
	if RS then
		local hit = lastHit[model]
		local amount = hit and hit.Amount and os.clock() - hit.Time < 0.8 and hit.Amount
		if amount then
			duration *= math.clamp((RS.Base or 0.7) + amount / (RS.PerDamage or 40), RS.Min or 0.8, RS.Max or 1.45)
		end
		duration = math.min(duration * (RS.Longer or 1), RS.Cap or 3)
	end
	local token = (ragdollTokens[model] or 0) + 1
	ragdollTokens[model] = token
	if not model:GetAttribute("Ragdolled") then
		setRagdoll(model, true)
		-- (which move put them down: its own follow-ups still hit in full)
		Reactions.downedBy[model] = Moves.of[coroutine.running()]
	end
	task.delay(duration, function()
		if ragdollTokens[model] == token and model.Parent and model:GetAttribute("Ragdolled") then
			setRagdoll(model, false)
			Reactions.downedBy[model] = nil
			Evasive.woke(model)
		end
	end)
end

-- RAGDOLL CANCEL (Config.Evasive): the meter lives on the body ("Evasive",
-- 0-100); dash while ragdolled with it full to get straight back up
do
	local EV = Config.Evasive or {}
	function Evasive.gain(model, amount, dealt)
		if EV.Enabled == false or not model or not model.Parent then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local now = model:GetAttribute("Evasive")
		if not hum or type(now) ~= "number" or now >= 100 then
			return
		end
		local low = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth <= (EV.LowHealth or 0.5)
		local per = dealt and 100 / (EV.DealtToFill or 260) or 100 / (EV.TakenToFill or 120)
		if low then
			per *= dealt and (EV.LowDealtMult or 2) or (EV.LowTakenMult or 1.23)
		end
		model:SetAttribute("Evasive", math.min(100, now + amount * per))
	end
	function Evasive.fill(model)
		if model and model.Parent and EV.Enabled ~= false then
			model:SetAttribute("Evasive", 100)
		end
	end
	-- back on your feet: a moment where M1s can't stun you again
	function Evasive.woke(model)
		-- (Config.Ragdoll.Knockdown) up again: a moment where no move knocks them straight back down
		Reactions.wakeGuard[model] = os.clock() + ((RAGDOLL.Knockdown and RAGDOLL.Knockdown.WakeGuard) or 1)
		model:SetAttribute("WakeImmune", os.clock() + (EV.WakeImmune or 0.75))
	end
	function Evasive.immune(model)
		return (model:GetAttribute("WakeImmune") or 0) > os.clock()
	end
	-- the cancel itself (dash pressed while ragdolled)
	-- (player is nil for the Evasive Dummy)
	function Evasive.use(player, char, root, dir)
		if EV.Enabled == false or workspace:GetAttribute("EvasiveEnabled") == false
			or not (char:GetAttribute("Ragdolled") or char:GetAttribute("ComboStun")) -- (round 68: or held in a combo)
			or (char:GetAttribute("Evasive") or 0) < 100
			or (player and player:GetAttribute("NoEvade")) or char:GetAttribute("Grabbed") or char:GetAttribute("BeingFinished")
			or char:GetAttribute("Frozen") or char:GetAttribute("Finishing") or char:GetAttribute("Submerged")
			or root.Anchored then
			return false
		end
		char:SetAttribute("Evasive", 0)
		ragdollTokens[char] = (ragdollTokens[char] or 0) + 1
		stunTokens[char] = (stunTokens[char] or 0) + 1
		for _, d in root:GetChildren() do
			if d.Name == "Knockback" or d.Name == "KnockbackAttachment" then
				d:Destroy()
			end
		end
		if char:GetAttribute("Ragdolled") then
			setRagdoll(char, false)
		end
		restoreMovement(char)
		char:SetAttribute("ComboStun", nil)
		Reactions.comboHold[char] = nil
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + (EV.IFrames or 1))
		Evasive.woke(char)
		if typeof(dir) ~= "Vector3" or dir ~= dir or dir.Magnitude < 0.1 then
			dir = root.CFrame.RightVector
		end
		dir = Vector3.new(dir.X, 0, dir.Z)
		dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.RightVector
		broadcast("Evasive", char, { Dir = dir })
		return true
	end
end

-- Going down: instead of falling apart (Roblox breaks the joints on death),
-- the body goes limp and carries whatever motion the finishing blow gave it
local function deathRagdoll(model)
	if RAGDOLL.OnDeath == false or RAGDOLL.Enabled == false then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if model:GetAttribute("Frozen") then
		-- thaw so the body can fall
		model:SetAttribute("Frozen", false)
		if root then
			root.Anchored = false
		end
	end
	ragdollTokens[model] = (ragdollTokens[model] or 0) + 1 -- no timed get-up
	if not model:GetAttribute("Ragdolled") then
		setRagdoll(model, true)
	end
	-- a killing blow's knockback pushes a limp body with bounded force, so it
	-- tumbles off with the hit instead of being dragged by the root
	if root then
		for _, d in root:GetChildren() do
			if d:IsA("LinearVelocity") and d.Name == "Knockback" then
				d.MaxForce = RAGDOLL.MaxForce or 30000
			end
		end
	end
end

-- frozen solid: they can't move, and whatever move they were in the
-- middle of stops dead (cutMoves) - on their own screen too (Frozen)
local function freeze(model, duration)
	if Reactions.stunProof(model) then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	stun(model, duration, 0)
	Moves.cut(model)
	if root then
		model:SetAttribute("Frozen", true)
		root.Anchored = true
	end
	broadcast("Freeze", nil, { Target = model, Duration = duration })
end

-- the ice round someone breaks (still stunned, but loose): true if they
-- were frozen
function Reactions.thaw(model)
	if not model:GetAttribute("Frozen") then
		return false
	end
	model:SetAttribute("Frozen", false)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and not model:GetAttribute("Grabbed") and not model:GetAttribute("Sealed") then
		root.Anchored = false
	end
	broadcast("Thaw", nil, { Target = model })
	return true
end

---------------------------------------------------------------------------
-- GUARD: hold to block frontal hits, a breakable meter, and parries
---------------------------------------------------------------------------

local function isDummy(model)
	local folder = workspace:FindFirstChild("Dummies")
	return folder ~= nil and model:IsDescendantOf(folder)
end

local function guardOf(model)
	local g = guardState[model]
	if not g then
		g = { Value = GUARD.Max or 100, Blocking = false, Broken = false, LastHit = 0, LastRaise = -math.huge, ParryUntil = 0 }
		guardState[model] = g
		model:SetAttribute("Guard", g.Value)
	end
	return g
end

local function setGuardValue(model, g, value)
	g.Value = math.clamp(value, 0, GUARD.Max or 100)
	local shown = math.floor(g.Value + 0.5)
	if model:GetAttribute("Guard") ~= shown then
		model:SetAttribute("Guard", shown)
	end
end

local function setBlocking(model, on)
	local g = guardOf(model)
	on = on and not g.Broken
	if g.Blocking == on then
		return
	end
	g.Blocking = on
	model:SetAttribute("Blocking", on)
	if on then
		local now = os.clock()
		-- only a fresh raise can parry, so mashing the key isn't a free parry
		local fresh = now - g.LastRaise >= (GUARD.ParryLockout or 0.8)
		g.ParryUntil = (fresh and not isDummy(model)) and now + (GUARD.ParryWindow or 0.2) or 0
		g.LastRaise = now
	end
	-- the owner already shows their own guard locally
	broadcast("Guard", model, { On = on, Target = model }, Players:GetPlayerFromCharacter(model))
end

local function guardBreak(model, g)
	g.Broken = true
	setBlocking(model, false)
	model:SetAttribute("GuardBroken", true)
	local stunTime = GUARD.BreakStun or 1.8
	stun(model, stunTime)
	broadcast("GuardBreak", nil, { Target = model, Duration = stunTime })
	task.delay(stunTime, function()
		if guardState[model] ~= g or not model.Parent then
			return
		end
		g.Broken = false
		g.LastHit = os.clock() -- the regen delay starts over from the refill
		model:SetAttribute("GuardBroken", false)
		setGuardValue(model, g, (GUARD.Max or 100) * (GUARD.BreakRefill or 0.5))
		if isDummy(model) and workspace:GetAttribute("DummiesBlock") then
			setBlocking(model, true)
		end
	end)
end

local function inFront(root, fromPos)
	if not fromPos then
		return true
	end
	local v = Vector3.new(fromPos.X - root.Position.X, 0, fromPos.Z - root.Position.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if v.Magnitude < 0.5 or look.Magnitude < 0.05 then
		return true
	end
	return v.Unit:Dot(look.Unit) >= math.cos(math.rad((GUARD.BlockAngle or 150) / 2))
end

resolveGuard = function(attacker, model, amount, opts)
	local g = guardState[model]
	if not g or not g.Blocking or g.Broken then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	-- (opts.AttackerModel: an attacker with no player, e.g. an attack dummy)
	local attackerChar = (attacker and attacker.Character) or (opts and opts.AttackerModel)
	local aroot = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
	local fromPos = (opts and opts.From) or (aroot and aroot.Position)
	-- dummies can't turn to face you, so their guard covers every side
	if not root or not (isDummy(model) or inFront(root, fromPos)) then
		setBlocking(model, false) -- caught from behind: the guard drops
		return false
	end
	local now = os.clock()
	local victim = Players:GetPlayerFromCharacter(model)

	-- PARRY: the guard went up just as the hit landed
	if now <= g.ParryUntil and aroot and (aroot.Position - root.Position).Magnitude <= (GUARD.ParryRange or 22) then
		g.ParryUntil = 0
		parryImmune[model] = now + (GUARD.ParryImmunity or 0.4)
		local away = Vector3.new(aroot.Position.X - root.Position.X, 0, aroot.Position.Z - root.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or root.CFrame.LookVector
		stun(attackerChar, GUARD.ParryStun or 1.2)
		knockback(attackerChar, away * 35 + UP * 12, 0.15)
		broadcast("Parry", nil, { Target = model, Attacker = attackerChar, By = victim, Against = attacker })
		addUlt(victim, GUARD.ParryUlt or 0)
		if victim and lives[victim] then
			lives[victim].Parries += 1
		end
		return true
	end

	-- BLOCK: chip damage goes through, the meter pays for the rest
	local loss = amount * (GUARD.GuardDamagePerDamage or 1.6) + ((opts and opts.GuardDamage) or 0)
	setGuardValue(model, g, g.Value - loss)
	g.LastHit = now
	local chip = math.floor(amount * (GUARD.ChipDamage or 0) + 0.5)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if chip > 0 and hum then
		if attacker then
			lastHit[model] = { Player = attacker, Time = now }
			if lives[attacker] then
				lives[attacker].Dealt += chip
			end
		end
		if victim and lives[victim] then
			lives[victim].Taken += chip
		end
		hum:TakeDamage(chip)
	end
	if victim and lives[victim] then
		lives[victim].Blocked += 1
	end
	addUlt(attacker, chip * ULT.GainPerDamageDealt) -- (round 59: the chip that got through - damage dealt)
	if g.Value <= 0 then
		guardBreak(model, g)
	else
		broadcast("Block", nil, { Target = model, From = fromPos, Heavy = ((opts and opts.Heavy) or amount >= 14) or nil })
		if fromPos then
			local push = Vector3.new(root.Position.X - fromPos.X, 0, root.Position.Z - fromPos.Z)
			if push.Magnitude > 0.1 then
				knockback(model, push.Unit * 14, 0.08)
			end
		end
	end
	return true
end

-- the meter refills while the guard is down
do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for model, g in guardState do
			if model.Parent and not g.Blocking and not g.Broken and g.Value < (GUARD.Max or 100)
				and now - g.LastHit >= (GUARD.RegenDelay or 1.4) then
				setGuardValue(model, g, g.Value + (GUARD.RegenPerSecond or 24) * step)
			end
		end
	end)
end

-- Damage over time. Ticks are quiet (no hit flash) so the burn VFX reads clearly.
local burnTokens = setmetatable({}, { __mode = "k" })
local function burn(model, ticks, perTick, pal)
	if not ticks or ticks <= 0 then
		return
	end
	local token = (burnTokens[model] or 0) + 1
	burnTokens[model] = token
	model:SetAttribute("Burning", true)
	broadcast("Burn", nil, { Target = model, Duration = ticks * 0.5, Pal = pal })
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if burnTokens[model] ~= token or not model.Parent then
				return
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				break
			end
			local victim = Players:GetPlayerFromCharacter(model)
			if not (victim and victim:GetAttribute("GodMode")) then
				hum:TakeDamage(perTick or 2)
			end
		end
		if burnTokens[model] == token and model.Parent then
			model:SetAttribute("Burning", false)
		end
	end)
end

-- Decay: damage over time that keeps crediting whoever touched you
local decayTokens = setmetatable({}, { __mode = "k" })
local function decayDot(attacker, model, ticks, perTick)
	if not ticks or ticks <= 0 then
		return
	end
	local token = (decayTokens[model] or 0) + 1
	decayTokens[model] = token
	model:SetAttribute("Decaying", true)
	broadcast("Decaying", nil, { Target = model, Duration = ticks * 0.5 })
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if decayTokens[model] ~= token or not model.Parent then
				return
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				break
			end
			local victim = Players:GetPlayerFromCharacter(model)
			if not (victim and victim:GetAttribute("GodMode")) then
				local amount = perTick or 3
				if attacker and attacker.Parent then
					lastHit[model] = { Player = attacker, Time = os.clock() }
					if lives[attacker] then
						lives[attacker].Dealt += amount
					end
				end
				if victim and lives[victim] then
					lives[victim].Taken += amount
				end
				hum:TakeDamage(amount)
			end
		end
		if decayTokens[model] == token and model.Parent then
			model:SetAttribute("Decaying", false)
		end
	end)
end

-- Clamp an aim point to a max horizontal range and drop it onto the ground
local function groundTarget(root, pos, range, caster)
	local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	if flat.Magnitude > range then
		flat = flat.Unit * range
	end
	local xz = root.Position + flat
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	local hit = workspace:Raycast(Vector3.new(xz.X, root.Position.Y + 25, xz.Z), Vector3.new(0, -90, 0), params)
	return hit and hit.Position or Vector3.new(xz.X, root.Position.Y - 3, xz.Z)
end

local function awayFrom(center, model, fallback)
	local r = model:FindFirstChild("HumanoidRootPart")
	if not r then
		return fallback
	end
	local v = Vector3.new(r.Position.X - center.X, 0, r.Position.Z - center.Z)
	return v.Magnitude > 0.1 and v.Unit or fallback
end

-- Repeating hitbox that follows the caster (dashes, dive kicks)
local function sweep(player, char, root, duration, radius, forwardOffset, dir, onHit)
	local hitSet = {}
	local t0 = os.clock()
	while os.clock() - t0 < duration and alive(char) do
		for _, model in Rewind.QueryRadius(player, char, root.Position + dir * forwardOffset, radius, hitSet) do
			hitSet[model] = true
			onHit(model)
		end
		task.wait(0.04)
	end
	return hitSet
end

-- Dashes bore through walls: carve just ahead of the caster while they move.
-- dirFn returns the travel direction (default: along their velocity).
local function tunnel(char, root, duration, radius, lookahead, dirFn, profile)
	local move = Moves.current()
	task.spawn(function()
		Moves.join(move)
		local t0 = os.clock()
		while os.clock() - t0 < duration and alive(char) do
			local d
			if dirFn then
				d = dirFn()
			else
				local v = root.AssemblyLinearVelocity
				d = v.Magnitude > 20 and v.Unit or root.CFrame.LookVector
			end
			Destruction.Sphere(root.Position + d * lookahead + Vector3.new(0, 1.5, 0), radius, profile or "Tunnel", d)
			task.wait(0.06)
		end
	end)
end

-- Ice layouts: same seed + origin as the caster's client, so holes match the ice
local function carveIce(layoutName, cast, d, char, budget, profile)
	-- (each spike on the street where it stands - the same snap his machine does)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local function snap(pos)
		local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -140, 0), params)
		return hit and hit.Position or nil
	end
	local list, growTime, anchor = SpikeLayouts[layoutName](groundBelow(cast.Origin, char), d, cast.Seed, snap)
	Destruction.Spikes(list, growTime, budget, profile)
	return anchor
end

---------------------------------------------------------------------------
-- Grabs: the victim's body is taken off their hands (anchored, moved by the
-- server) and carried wherever the move says, then let go with a shove.
-- A guard doesn't stop a grab; a dodge, Infinity or god mode does.
---------------------------------------------------------------------------

local Grab = {}

function Grab.take(model, duration)
	local troot = model:FindFirstChild("HumanoidRootPart")
	local victim = Players:GetPlayerFromCharacter(model)
	if not troot or troot.Anchored or untouchable(model) or not alive(model) or Moves.stopped()
		or model:GetAttribute("Grabbed") or model:GetAttribute("BeingFinished") or model:GetAttribute("Finishing") or model:GetAttribute("Boss")
		or (victim and victim:GetAttribute("GodMode")) then
		return nil
	end
	if (iFrames[model] or 0) > os.clock() then
		broadcast("Dodge", nil, { Target = model })
		return nil
	end
	if guardState[model] and guardState[model].Blocking then
		setBlocking(model, false)
	end
	-- (knocked down a moment ago: the grab picks them up off the street)
	if model:GetAttribute("Ragdolled") then
		ragdollTokens[model] = (ragdollTokens[model] or 0) + 1
		setRagdoll(model, false)
		Reactions.downedBy[model] = nil
	end
	model:SetAttribute("Grabbed", true)
	stun(model, duration + 0.3, 0)
	troot.Anchored = true
	return { Model = model, Root = troot }
end

-- hold them at cf
function Grab.place(g, cf)
	if g and g.Root.Parent then
		g.Root.CFrame = cf
	end
end

-- let go, with a shove (velocity for time seconds)
function Grab.release(g, velocity, time)
	if not g then
		return
	end
	if g.Root.Parent then
		g.Root.Anchored = false
	end
	g.Model:SetAttribute("Grabbed", nil)
	if velocity and g.Model.Parent then
		knockback(g.Model, velocity, time or 0.2)
	end
end

-- the closest one in front of him within range (a cone of `dot`)
function Grab.nearest(char, root, d, range, dot)
	local best, bestDist
	for _, model in queryRadius(char, root.Position + d * (range / 2), range / 2 + 4) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		if mr then
			local v = mr.Position - root.Position
			local flat = Vector3.new(v.X, 0, v.Z)
			if v.Magnitude <= range and (flat.Magnitude < 3 or flat.Unit:Dot(d) > (dot or 0.3))
				and (not bestDist or v.Magnitude < bestDist) then
				best, bestDist = model, v.Magnitude
			end
		end
	end
	return best
end

-- per-character helpers for the moves below
local Kit = {}
Kit.liveAim = setmetatable({}, { __mode = "k" }) -- [player] = { Dir, Time }: where he's aiming now (AIM_INDEX)
Kit.lastMove = setmetatable({}, { __mode = "k" }) -- [char] = { Ability, Time }: the last move they used
Reactions.lastMove = Kit.lastMove -- (round 68: the combo rules read it)

---------------------------------------------------------------------------
-- KNOCKDOWNS (Config.Ragdoll.Knockdown): a move's solid hit puts them on
-- the street instead of just stunning them; while they're down other hits
-- are scaled down, and getting up gives a moment's guard from the next one
---------------------------------------------------------------------------
Reactions.downedBy = setmetatable({}, { __mode = "k" }) -- [model] = the move that put them down
Reactions.wakeGuard = setmetatable({}, { __mode = "k" }) -- [model] = os.clock() until no knockdown
Reactions.koAt = setmetatable({}, { __mode = "k" }) -- [model] = os.clock() of their last KO finisher

function Reactions.knockdownsOn()
	local KD = RAGDOLL.Knockdown
	return KD ~= nil and KD.Enabled ~= false and RAGDOLL.Enabled ~= false and workspace:GetAttribute("Knockdowns") ~= false
end

-- (round 59) what can still hit someone who's down: a DOWNSLAM (the 4th
-- M1 from the air), the move that put them there (its own follow-ups), a
-- finisher on them. Nothing else - no M1s, no uppercuts, no other moves.
function Reactions.hitsDowned(attacker, model, opts)
	if RAGDOLL.DownImmune == false or workspace:GetAttribute("DownImmune") == false then
		return true
	end
	if opts and (opts.Downslam or opts.Tick or opts.HitsDowned) then
		return true -- (round 68: HitsDowned - Decay Grasp grabs you off the street)
	end
	if attacker and finishing[model] == attacker then
		return true
	end
	local move = Moves.of[coroutine.running()]
	return move ~= nil and move == Reactions.downedBy[model]
end

-- how much of a hit lands on someone lying in the street
function Reactions.downedScale(model, opts)
	if not model:GetAttribute("Ragdolled") or not Reactions.knockdownsOn() or (opts and (opts.Downslam or opts.HitsDowned)) then
		return 1 -- (a downslam lands in full: round 59)
	end
	local move = Moves.of[coroutine.running()]
	if move and move == Reactions.downedBy[model] then
		return 1 -- (the move that put them there: its own follow-ups)
	end
	return RAGDOLL.Knockdown.DownedScale or 0.6
end

function Reactions.knockdown(model, amount, opts)
	if not Reactions.knockdownsOn() or Reactions.comboMove(model) then
		return -- (round 68: a combo hero's move holds them in hitstun instead)
	end
	local move = Moves.of[coroutine.running()]
	local ability = move and move.Ability
	if not ability or ability.NoKnockdown or ability.Bind or ability.FreezeTime or (opts and opts.NoKnockdown)
		or amount < (RAGDOLL.Knockdown.MinDamage or 7) or (Reactions.wakeGuard[model] or 0) > os.clock() then
		return
	end
	-- (a beat later: a move that grabs, freezes or seals them right after the
	-- hit keeps hold of them, and its own shove goes first)
	task.delay(0.08, function()
		local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not root or root.Anchored or model:GetAttribute("Ragdolled") or model:GetAttribute("Grabbed")
			or model:GetAttribute("Frozen") or model:GetAttribute("Sealed") or model:GetAttribute("BeingFinished") then
			return
		end
		ragdoll(model, RAGDOLL.Knockdown.Time or 1.1)
		if model:GetAttribute("Ragdolled") then
			Reactions.downedBy[model] = move
		end
	end)
end

-- KO FINISHERS (Config.KOFinisher): a move's killing blow plays out on
-- every screen (Effects.KOFinisher) and the body is launched along the hit
function Reactions.ko(attacker, model, _opts)
	local KF = Config.KOFinisher
	local attackerChar = attacker and attacker.Character
	if model:GetAttribute("TwiceClone") or model:GetAttribute("Boss") then
		return -- (round 69: a double of Twice's just melts; round 71: the Nomu has its own end)
	end
	if not KF or KF.Enabled == false or not attackerChar or attackerChar == model or os.clock() - (Reactions.koAt[model] or -10) < 3 then
		return -- (one finisher a KO: a body that's still falling doesn't get another)
	end
	local move = Moves.of[coroutine.running()]
	local ability = move and move.Ability
	if not ability then
		local last = Kit.lastMove[attackerChar]
		ability = last and os.clock() - last.Time < 2.5 and last.Ability or nil
	end
	local ar, vr = attackerChar:FindFirstChild("HumanoidRootPart"), model:FindFirstChild("HumanoidRootPart")
	if not ability or not ar or not vr then
		return -- (an M1, a knock off the map...: no finisher)
	end
	Reactions.koAt[model] = os.clock()
	local dir = flatten(vr.Position - ar.Position, ar)
	broadcast("KOFinisher", attackerChar, { Target = model, Move = ability.Id, Name = ability.Name, Dir = dir, Pos = vr.Position })
	-- (after the move's own shove: this one is the send-off)
	task.delay(0.05, function()
		if vr.Parent then
			knockback(model, dir * (KF.Launch or 95) + UP * (KF.Lift or 70), 0.3)
		end
	end)
end

-- Moves you HOLD (ability.Hold): the charge starts when the key goes down
-- and ends when it comes back up (RELEASE_INDEX) - or at Hold.Max. While
-- it charges he's "Holding" (nothing else goes) and slowed to Hold.Speed.
local HoldMoves = { active = setmetatable({}, { __mode = "k" }) }

-- blocks until he lets go: how long he held it and the hold (its Dir / Aim
-- are what he let go with); nil if he was knocked out or lost the body
function HoldMoves.wait(player, char, ability)
	local spec = ability.Hold or {}
	local hold = { Released = false, Start = os.clock() }
	HoldMoves.active[player] = hold
	char:SetAttribute("Holding", ability.Id)
	if spec.Speed then
		char:SetAttribute("SlowedTo", spec.Speed)
	end
	local max = spec.Max or 2
	-- (the extra moment is for his own screen's release to get here)
	while alive(char) and player.Character == char and not hold.Released and os.clock() - hold.Start < max + 0.4 do
		task.wait()
	end
	HoldMoves.active[player] = nil
	char:SetAttribute("Holding", nil)
	if spec.Speed then
		char:SetAttribute("SlowedTo", nil)
	end
	if not alive(char) or player.Character ~= char then
		broadcast("HoldCancel", char, {})
		return nil
	end
	return math.min(os.clock() - hold.Start, max), hold
end

-- the power level a hold reached (1 = a tap); a little slack for the trip
-- from his machine
function HoldMoves.level(ability, held)
	local level = 1
	for i, t in (ability.Hold and ability.Hold.Levels) or {} do
		if held >= t - 0.12 then
			level = i + 1
		end
	end
	return level
end

-- his key came up
function HoldMoves.release(player, aimDir, aimPos)
	local hold = HoldMoves.active[player]
	if not hold or hold.Released then
		return
	end
	if typeof(aimDir) == "Vector3" and aimDir == aimDir and aimDir.Magnitude > 0.01 then
		hold.Dir = aimDir.Unit
	end
	if typeof(aimPos) == "Vector3" and aimPos == aimPos then
		hold.Aim = aimPos
	end
	hold.Released = true
end

---------------------------------------------------------------------------
-- Ability handlers (timings mirror VFX.luau)
---------------------------------------------------------------------------

local Handlers = {}

-- EXPLOSION
-- Destruction shapes follow each move's look:
--   explosions blow spherical holes with scorched rims,
--   wind smashes punch long boxes and throw debris forward,
--   ice carves the exact spike shapes and frosts the edges,
--   fire burns columns / scorches walls, kicks and dashes bore tunnels.

-- EXPLOSION
-- Blast Rush: a rocket charge that blasts through whatever's in the way.
-- In the air it's a dive-bomb: he rockets at the aim point and the landing
-- goes off.
function Handlers.BlastRush(player, char, root, ability, dir, pos, cast)
	if cast.Air then
		local target = groundTarget(root, pos, ability.Range or 55, char)
		local v = target - root.Position
		local d = v.Magnitude > 1 and v.Unit or -UP
		local flight = math.clamp(v.Magnitude / 170, 0.2, 0.7)
		tunnel(char, root, flight, 7, 6, function()
			return d
		end)
		sweep(player, char, root, flight, 7, 2, d, function(model)
			if damage(player, model, ability.Damage) then
				knockback(model, d * 60 + UP * 20, 0.2)
				stun(model, ability.Stun or 0.8)
			end
		end)
		if not alive(char) then
			return
		end
		local center = groundBelow(root.Position, char)
		for _, model in queryRadius(char, center + UP * 3, ability.Radius or 18) do
			if damage(player, model, ability.FinisherDamage or 20, { Heavy = true, From = center }) then
				knockback(model, awayFrom(center, model, flatten(d, root)) * 95 + UP * 60, 0.24)
				stun(model, (ability.Stun or 0.8) + 0.2)
			end
		end
		Destruction.Sphere(center + UP * 3, 17, "BigExplosion")
		return
	end
	local d = flatten(dir, root)
	tunnel(char, root, 0.42, 8, 8, function()
		return d
	end)
	sweep(player, char, root, 0.42, 9, 3, d, function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, d * 80 + UP * 30, 0.2)
			stun(model, ability.Stun or 0.7)
		end
	end)
	if alive(char) then
		local center = root.Position + d * 6
		for _, model in queryRadius(char, center, ability.Radius or 17) do
			if damage(player, model, ability.FinisherDamage or 22) then
				knockback(model, awayFrom(center, model, d) * 90 + UP * 50, 0.24)
				stun(model, (ability.Stun or 0.7) + 0.2)
			end
		end
		Destruction.Sphere(center, 17, "Explosion")
	end
end

-- ERUPTION ORBIT: palm to the street - it erupts under whoever's in front
-- and throws them up; he rockets up after them, circles them blasting from
-- every side, then the last blast from above drives them into the street.
-- In the air there's no eruption: he goes straight for the nearest one.
function Handlers.BlastOrbit(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	local caught = {}
	if not cast.Air then
		task.wait(0.28)
		if not alive(char) then
			return
		end
		local center = groundBelow(root.Position + d * ((ability.Range or 16) * 0.55), char)
		Destruction.Sphere(center, 9, "Explosion")
		for _, model in queryRadius(char, center + UP * 3, ability.Radius or 10) do
			if damage(player, model, ability.Damage, { From = center, Hitstop = 0.06 }) then
				knockback(model, UP * (ability.Launch or 95) + d * 4, 0.22)
				stun(model, 2.5)
				table.insert(caught, model)
			end
		end
		task.wait(0.42) -- (they're at the top of the throw)
	else
		task.wait(0.12)
		local model = alive(char) and Grab.nearest(char, root, d, (ability.Range or 16) * 1.5, 0.2)
		if model and damage(player, model, ability.Damage, { Hitstop = 0.06 }) then
			table.insert(caught, model)
		end
	end
	if not alive(char) or #caught == 0 then
		broadcast("BlastOrbitCatch", char, { Targets = {} })
		return
	end
	-- held up there while he circles them
	local holds = {}
	for _, model in caught do
		local g = Grab.take(model, 1.2)
		if g then
			if cast.Air then
				Grab.place(g, g.Root.CFrame + UP * 3)
			end
			table.insert(holds, g)
		end
	end
	local first = holds[1] and holds[1].Root.Position or root.Position + d * 6 + UP * 18
	broadcast("BlastOrbitCatch", char, { Targets = caught, Center = first, Dir = d })
	for _ = 1, ability.OrbitHits or 3 do
		task.wait(0.2)
		if not alive(char) then
			break -- (frozen, or down: he lets them go)
		end
		for _, g in holds do
			if g.Model.Parent then
				damage(player, g.Model, ability.OrbitDamage or 5, { Hitstop = 0.04, From = first })
			end
		end
	end
	task.wait(0.28)
	-- the last one, from above: straight down into the street
	for _, g in holds do
		Grab.release(g, -UP * 170 + d * 10, 0.2)
		if g.Model.Parent and damage(player, g.Model, ability.SlamDamage or 18, { Heavy = true, Hitstop = 0.1, From = first + UP * 8 }) then
			ragdoll(g.Model, 1.5)
			stun(g.Model, ability.SlamStun or 1.6)
		end
		task.delay(0.2, function()
			if g.Root.Parent then
				Destruction.Sphere(groundBelow(g.Root.Position, char), 11, "Crater")
			end
		end)
	end
end

-- SCORCHED EARTH (V): he grabs the face in front of him, rockets forward
-- dragging them along the street (a trench behind them, anything in the way
-- blown through) and blows up in their face. In the air: he rockets them
-- DOWN, head first into the street.
function Handlers.ScorchedEarth(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	task.wait(0.12)
	if not alive(char) then
		return
	end
	local model = Grab.nearest(char, root, d, ability.Range or 9, 0.3)
	local g = model and Grab.take(model, (ability.DragTime or 0.7) + 0.4)
	broadcast("ScorchedEarthCatch", char, { Target = g and model or nil, Dir = d, Air = cast.Air })
	if not g then
		return
	end
	damage(player, model, ability.DragDamage or 4, { Hitstop = 0.05 })
	local t0 = os.clock()
	local dragTime = ability.DragTime or 0.7
	local lastTick = t0
	while os.clock() - t0 < dragTime and alive(char) and g.Root.Parent do
		-- held out in front of his palm (his own machine flies him)
		local ahead = cast.Air and (root.CFrame.Position - UP * 3.5 + d * 1.5) or (root.CFrame.Position + d * 3.2 - UP * 0.6)
		Grab.place(g, CFrame.lookAt(ahead, ahead - d))
		if os.clock() - lastTick > 0.15 then
			lastTick = os.clock()
			if cast.Air then
				Destruction.Sphere(ahead - UP * 2, 5, "Impact", -UP)
			else
				Destruction.Sphere(ahead + d * 2, 6, "Explosion", d) -- through whatever's in the way
				Destruction.Box(CFrame.lookAt(ahead - UP * 3, ahead - UP * 3 + d), Vector3.new(5, 3, 6), "Crater", d) -- the trench
			end
		end
		task.wait(0.03)
	end
	local center = g.Root.Position
	Grab.release(g, cast.Air and (UP * 60 + d * 30) or (d * 130 + UP * 55), 0.24)
	if alive(char) and damage(player, model, ability.Damage, { Heavy = true, Hitstop = 0.1, From = center - d * 2 }) then
		ragdoll(model, 1.6)
		stun(model, ability.Stun or 1.5)
	end
	Destruction.Sphere(center, cast.Air and 16 or 13, cast.Air and "BigExplosion" or "Explosion")
end

-- ONE FOR ALL: true form
function Handlers.TexasSmash(player, char, root, ability, dir)
	task.wait(0.22)
	if not alive(char) then
		return
	end
	local d = flatten(dir, root)
	local length = 52
	local look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 0, -length / 2), Vector3.new(14, 12, length)) do
		if damage(player, model, ability.Damage) then
			knockback(model, d * 95 + UP * 20, 0.2)
			stun(model, 0.7)
		end
	end
	-- air-pressure punch: a tunnel of wind blown straight forward
	Destruction.Box(look * CFrame.new(0, 1, -28), Vector3.new(12, 12, 50), "Wind", d)
end

-- NEW HAMPSHIRE SMASH: he crouches with both fists cocked, then the air
-- pressure of his own punch fires him forward like a missile, fists first.
-- Whoever he runs into is carried on his fists the whole way (walls in the
-- road are blown open) and the wind he's pushing goes off at the end.
function Handlers.NewHampshireSmash(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.25)
	if not alive(char) then
		return
	end
	local travel = ability.TravelTime or 0.4
	tunnel(char, root, travel, 7, 7, function()
		return d
	end, "Wind")
	local hitSet, carried = {}, {}
	local t0 = os.clock()
	while os.clock() - t0 < travel and alive(char) do
		for _, model in Rewind.QueryRadius(player, char, root.Position + d * 3, 7, hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage, { Hitstop = 0.05 }) then
				local g = Grab.take(model, travel + 0.3)
				if g then
					table.insert(carried, g)
				end
			end
		end
		for i, g in carried do
			local at = root.Position + d * (3.5 + i)
			Grab.place(g, CFrame.lookAt(at, at - d))
		end
		task.wait(0.04)
	end
	if not alive(char) then
		for _, g in carried do
			Grab.release(g)
		end
		return
	end
	local center = root.Position + d * 5
	for _, g in carried do
		Grab.release(g, d * 150 + UP * 45, 0.25)
		if damage(player, g.Model, ability.FinisherDamage or 14, { Heavy = true, Hitstop = 0.1, From = center - d * 4 }) then
			stun(g.Model, 1.2)
		end
	end
	for _, model in queryRadius(char, center, 13, hitSet) do
		if damage(player, model, ability.FinisherDamage or 14, { From = center - d * 4 }) then
			knockback(model, awayFrom(center, model, d) * 90 + UP * 35, 0.2)
			stun(model, 0.9)
		end
	end
	Destruction.Box(CFrame.lookAt(center, center + d) * CFrame.new(0, 2, -10), Vector3.new(18, 16, 24), "Wind", d)
end

function Handlers.CarolinaSmash(player, char, root, ability, dir)
	local d = flatten(dir, root)
	tunnel(char, root, 0.22, 5, 6, function()
		return d
	end)
	task.delay(0.2, function()
		if not alive(char) then
			return
		end
		-- the cross chop cuts an X-shaped gash into whatever is in front
		local p = root.Position + d * 3 + UP * 0.8
		for _, angle in { 45, -45 } do
			local cf = CFrame.lookAt(p, p + d) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(0, 0, -13)
			Destruction.Box(cf, Vector3.new(2.4, 20, 26), "Slash", d)
		end
	end)
	task.wait(0.1)
	sweep(player, char, root, 0.26, 6.5, 3, d, function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, d * 85 + UP * 30, 0.2)
			stun(model, 0.8)
		end
	end)
end

-- HERO'S COUNTER (V, true form): he stands his ground a moment (Window).
-- A hit that lands in it doesn't: for an instant he's the Symbol of Peace
-- again, and the Detroit Smash that answers it sends them flying.
Kit.counters = setmetatable({}, { __mode = "k" }) -- [character] = the stance

function Handlers.HeroCounter(player, char, _root, ability)
	local stance = { Until = os.clock() + (ability.Window or 0.9), Player = player, Ability = ability }
	Kit.counters[char] = stance
	char:SetAttribute("Countering", true)
	task.wait(ability.Window or 0.9)
	if Kit.counters[char] == stance then
		Kit.counters[char] = nil
	end
	char:SetAttribute("Countering", nil)
end

function Reactions.Counter(attacker, model, opts)
	local stance = Kit.counters[model]
	if not stance or stance.Fired or os.clock() > stance.Until or attacker == stance.Player then
		return false
	end
	stance.Fired = true
	Kit.counters[model] = nil
	model:SetAttribute("Countering", nil)
	if stance.React then
		return stance.React(attacker, model, opts, stance) ~= false -- (round 74)
	end
	local ac = attacker.Character
	local ar = ac and ac:FindFirstChild("HumanoidRootPart")
	local mr = model:FindFirstChild("HumanoidRootPart")
	broadcast("HeroCounterHit", model, { Target = ac, From = opts and opts.From or (ar and ar.Position) })
	iFrames[model] = math.max(iFrames[model] or 0, os.clock() + 0.5)
	task.spawn(function()
		task.wait(0.14)
		if not (ar and mr and alive(model) and alive(ac)) or (ar.Position - mr.Position).Magnitude > 32 then
			return -- (from too far away to answer: it just doesn't land)
		end
		local d = flatten(ar.Position - mr.Position, mr)
		if damage(stance.Player, ac, stance.Ability.Damage, { Heavy = true, Unblockable = true, Hitstop = 0.14, From = mr.Position }) then
			knockback(ac, d * 160 + UP * 45, 0.3)
			stun(ac, 1.6)
			ragdoll(ac, 1.6)
		end
		Destruction.Box(CFrame.lookAt(mr.Position, mr.Position + d) * CFrame.new(0, 2, -30), Vector3.new(14, 14, 50), "Wind", d)
	end)
	return true
end

-- DANGER SENSE (Deku at 100%, the 4th user's quirk): the hair on his neck
-- stands on end and he's already moved - someone else's hit is dodged, once
-- every Config.Quirks.FullCowl.Ult.DangerSense.Cooldown seconds
Kit.dangerAt = setmetatable({}, { __mode = "k" })
function Reactions.DangerSense(attacker, model, opts)
	if not opts or not opts.From or model:GetAttribute("Quirk") ~= "FullCowl" or model:GetAttribute("UltActive") ~= true
		or attacker.Character == model then
		return false
	end
	local spec = Config.Quirks.FullCowl.Ult and Config.Quirks.FullCowl.Ult.DangerSense
	if not spec or (Kit.dangerAt[model] or 0) > os.clock() or model:GetAttribute("Stunned") or model:GetAttribute("Ragdolled") or model:GetAttribute("Grabbed") then
		return false
	end
	Kit.dangerAt[model] = os.clock() + (spec.Cooldown or 8)
	iFrames[model] = math.max(iFrames[model] or 0, os.clock() + (spec.Grace or 0.35))
	broadcast("DangerSense", model, { From = opts.From })
	return true
end

-- ONE FOR ALL: muscle form
function Handlers.DetroitSmash(player, char, root, ability, dir)
	task.wait(0.35)
	if not alive(char) then
		return
	end
	local d = flatten(dir, root)
	local length = 80
	local look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 4, -length / 2), Vector3.new(28, 26, length)) do
		if damage(player, model, ability.Damage) then
			knockback(model, d * 125 + UP * 40, 0.25)
			stun(model, 1.1)
		end
	end
	-- the whole street in front of him, gone
	Destruction.Box(look * CFrame.new(0, 7, -58), Vector3.new(28, 26, 110), "Wind", d)
end

function Handlers.OklahomaSmash(player, char, root, ability, dir)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local center = root.Position
	for _, model in queryRadius(char, center, 17) do
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, flatten(dir, root)) * 110 + UP * 45, 0.22)
			stun(model, 1)
		end
	end
	-- spinning whirlwind: a ring of wreckage thrown outward
	Destruction.Cylinder(center + UP * 4, 24, 14, "Whirl")
end


-- HALF-COLD
function Handlers.IceSpike(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	task.wait(0.12)
	if not alive(char) then
		return
	end
	carveIce("IceSpike", cast, d, char, 120)
	task.wait(0.03)
	local length = 44
	local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -(length / 2 + 3))
	for _, model in queryBox(char, cf, Vector3.new(10, 14, length)) do
		if damage(player, model, ability.Damage) then
			freeze(model, ability.FreezeTime or 1.6)
		end
	end
end

function Handlers.FrostBurst(player, char, root, ability, dir, _pos, cast)
	task.wait(0.15)
	if not alive(char) then
		return
	end
	carveIce("FrostBurst", cast, flatten(dir, root), char, 150)
	task.wait(0.05)
	for _, model in queryRadius(char, root.Position, 16) do
		if damage(player, model, ability.Damage) then
			freeze(model, ability.FreezeTime or 2)
		end
	end
end

-- GLACIER BREAKER: a punch drives whoever's in front back into a wall of
-- ice that erupts behind them - they're pinned there, frozen in - then he
-- stomps and a pillar of ice bursts up under them, shattering the wall
function Handlers.GlacierBreaker(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.14)
	if not alive(char) then
		return
	end
	local model = Grab.nearest(char, root, d, ability.Range or 10, 0.3)
	local pin = ability.PinTime or 0.55
	-- (already frozen solid: the punch shatters their ice - a little extra -
	-- and drives them on into the wall all the same)
	local shattered = model ~= nil and not untouchable(model) and (iFrames[model] or 0) <= os.clock() and Reactions.thaw(model)
	local g = model and Grab.take(model, pin + 0.4)
	local wallAt = root.Position + d * 7.5
	broadcast("GlacierPin", char, { Target = g and model or nil, Dir = d, Pos = wallAt, Time = pin, Shatter = shattered and g ~= nil })
	if not g then
		return
	end
	damage(player, model, ability.Damage + (shattered and (ability.ShatterDamage or 0) or 0), { Hitstop = shattered and 0.12 or 0.08 })
	local at = root.Position + d * 5.6
	Grab.place(g, CFrame.lookAt(at, at - d)) -- (back against the ice)
	task.wait(pin)
	Grab.release(g, UP * 115 + d * 40, 0.25)
	if alive(char) and damage(player, model, ability.PillarDamage or 20, { Heavy = true, Hitstop = 0.1, From = at - UP * 3 }) then
		ragdoll(model, 1.6)
		stun(model, 1.4)
	end
	Destruction.Sphere(wallAt, 7, "Ice")
end

-- ICE SLIDER (ice V): a ramp of ice shoots out along the aim and he skates
-- up it (his own machine rides it); anyone it erupts under is thrown up
-- and frozen, and off the lip at the end he's flung into the air
function Handlers.IceSlider(player, char, root, ability, dir)
	local d = flatten(dir, root)
	local hitSet = {}
	local t0 = os.clock()
	while os.clock() - t0 < (ability.RideTime or 0.75) and alive(char) do
		local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, -1, -6)
		for _, model in queryBox(char, cf, Vector3.new(10, 10, 12), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage) then
				knockback(model, UP * 55 + d * 25, 0.15)
				task.delay(0.15, function()
					if model.Parent then
						freeze(model, ability.FreezeTime or 1)
					end
				end)
			end
		end
		task.wait(0.05)
	end
end

-- HEAVEN-PIERCING ICE WALL (the ult): a glacier from his foot that climbs
-- into the sky as it runs out ahead of him - everything in its path is
-- thrown up with the ice and frozen in it
function Handlers.IceWall(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	task.wait(0.55)
	if not alive(char) then
		return
	end
	carveIce("IceWall", cast, d, char, 1200)
	local length = ability.Length or 190
	local look = CFrame.lookAt(root.Position, root.Position + d)
	local hitSet = {}
	-- it runs out along the street: further along, a moment later
	for k = 1, 4 do
		local near, far = length * (k - 1) / 4, length * k / 4
		task.delay(near / 160, function()
			if not alive(char) then
				return
			end
			-- (as wide as the glacier: it fans out to SpikeLayouts.HEAVEN.Width)
			local width = 18 + far * ((SpikeLayouts.HEAVEN and SpikeLayouts.HEAVEN.Width or 170) - 14) / length
			local cf = look * CFrame.new(0, 45, -(near + far) / 2 - 5)
			for _, model in queryBox(char, cf, Vector3.new(width, 130, far - near + 6), hitSet) do
				hitSet[model] = true
				if damage(player, model, ability.Damage, { Heavy = true, Unblockable = true, From = root.Position }) then
					knockback(model, UP * 90 + d * 15, 0.2)
					task.delay(0.2, function()
						if model.Parent then
							freeze(model, ability.FreezeTime or 3.5)
						end
					end)
				end
			end
		end)
	end
end

-- HALF-HOT (fire side of Half-Cold)
function Handlers.Flashfire(player, char, root, ability, dir)
	task.wait(0.1)
	if not alive(char) then
		return
	end
	local d = flatten(dir, root)
	-- the flamethrower scorches a black streak onto walls without breaking them
	task.delay(0.25, function()
		if alive(char) then
			local look = CFrame.lookAt(root.Position, root.Position + d)
			Destruction.Box(look * CFrame.new(0, 0.5, -24), Vector3.new(10, 9, 40), "Scorch", d)
		end
	end)
	local hitSet = {}
	local t0 = os.clock()
	while os.clock() - t0 < 0.45 and alive(char) do
		local length = 42
		local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0.5, -(length / 2 + 1.5))
		for _, model in queryBox(char, cf, Vector3.new(11, 10, length), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage) then
				knockback(model, d * 40 + UP * 12, 0.15)
				stun(model, 0.55)
				burn(model, ability.BurnTicks, ability.BurnDamage)
			end
		end
		task.wait(0.08)
	end
end

function Handlers.FlamePillar(player, char, root, ability, dir, pos)
	local target = groundTarget(root, pos, ability.Range or 70, char)
	task.wait(0.42)
	if not alive(char) then
		return
	end
	local cf = CFrame.new(target + Vector3.new(0, 12, 0))
	for _, model in queryBox(char, cf, Vector3.new(18, 28, 18)) do
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(target, model, flatten(dir, root)) * 20 + UP * 95, 0.2)
			stun(model, 0.9)
			burn(model, ability.BurnTicks, ability.BurnDamage)
		end
	end
	-- a column of fire burns straight up through floors and balconies
	Destruction.Cylinder(target + UP * 22, 7.5, 44, "Fire")
end

function Handlers.Heatwave(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	-- stage 1: ice rises and pins anyone in front
	task.wait(0.4)
	if not alive(char) then
		return
	end
	local anchor = carveIce("Heatwave", cast, d, char, 200)
	task.wait(0.05)
	local iceCf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 6, -20)
	for _, model in queryBox(char, iceCf, Vector3.new(34, 24, 30)) do
		if damage(player, model, 4) then
			stun(model, 0.9)
		end
	end
	-- stage 2: fire hits the ice -> superheated air blast
	task.wait(0.7)
	if not alive(char) then
		return
	end
	local blastCf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 8, -32)
	for _, model in queryBox(char, blastCf, Vector3.new(56, 40, 64)) do
		if damage(player, model, ability.Damage) then
			knockback(model, d * 150 + UP * 60, 0.28)
			stun(model, 1.4)
			burn(model, ability.BurnTicks, ability.BurnDamage)
		end
	end
	Destruction.Sphere(anchor + d * 18 + UP * 7, 20, "BigExplosion")
end

-- JET KINDLING (fire V): flames jet from his elbow and rocket him along the
-- aim (his own machine flies him; in the air the aim can take him up or
-- down). The first person he reaches takes the white-hot fist - and the
-- blast bursts on out of his arm, through them, into anyone behind. Nobody
-- reached: the fist goes off at the end of the jet anyway.
function Handlers.JetKindling(player, char, root, ability, dir, _pos, cast)
	local d = cast and cast.Air and typeof(dir) == "Vector3" and dir.Magnitude > 0.1 and dir.Unit or flatten(dir, root)
	if cast and cast.Air then
		-- (steep enough to dive on someone, never straight up or down)
		local flat = Vector3.new(d.X, 0, d.Z)
		flat = flat.Magnitude > 0.05 and flat.Unit or flatten(root.CFrame.LookVector, root)
		d = (flat + UP * math.clamp(d.Y, -0.9, 0.45)).Unit
	end
	local dashTime = ability.DashTime or 0.32
	tunnel(char, root, dashTime, 5, 6, function()
		return d
	end)
	-- the first body he reaches
	local target
	local hitSet = {}
	local t0 = os.clock()
	while not target and os.clock() - t0 < dashTime + 0.05 and alive(char) do
		target = Rewind.QueryRadius(player, char, root.Position + d * 2.5, ability.Reach or 6, hitSet)[1]
		if not target then
			task.wait(0.03)
		end
	end
	if not alive(char) then
		return
	end
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local at = troot and troot.Position or (root.Position + d * 4)
	broadcast("JetKindlingHit", char, { Target = target, Dir = d, At = at })
	if target and damage(player, target, ability.Damage, { Heavy = true, Hitstop = 0.14, From = root.Position }) then
		knockback(target, d * 125 + UP * 38, 0.26)
		stun(target, 1.4)
		ragdoll(target, 1.3)
		burn(target, ability.BurnTicks, ability.BurnDamage)
	end
	-- the explosion of flame out of his arm: on through them (or where the fist went off)
	local length = ability.BlastLength or 22
	local cf = CFrame.lookAt(at, at + d) * CFrame.new(0, 0, target and -(length / 2) or -(length / 4))
	local size = target and Vector3.new(12, 11, length) or Vector3.new(14, 12, length / 2 + 6)
	for _, model in queryBox(char, cf, size) do
		if model ~= target and damage(player, model, ability.BlastDamage or 12, { From = at, Hitstop = 0.06 }) then
			knockback(model, (awayFrom(at, model, d) + d).Unit * 80 + UP * 30, 0.2)
			stun(model, 0.9)
			burn(model, ability.BurnTicks, ability.BurnDamage)
		end
	end
	Destruction.Sphere(at + d * 3, 8, "Explosion", d)
	Destruction.Box(cf, Vector3.new(9, 8, length), "Scorch", d)
end

-- ENGINE
-- RECIPRO SPIN: a whirling roundhouse, engines roaring - one kick round
-- him, then the second throws everyone away
function Handlers.SpinKick(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.1)
	for i = 1, 2 do
		if not alive(char) then
			return
		end
		local last = i == 2
		for _, model in queryRadius(char, root.Position, ability.Radius or 11) do
			if damage(player, model, last and (ability.FinisherDamage or 12) or ability.Damage, { Hitstop = 0.05, From = root.Position }) then
				if last then
					knockback(model, awayFrom(root.Position, model, d) * 85 + UP * 45, 0.22)
					stun(model, 1)
				else
					stun(model, 0.6)
				end
			end
		end
		task.wait(0.22)
	end
	Destruction.Cylinder(root.Position + UP * 2, 12, 5, "Whirl")
end

-- ENGINE GATLING: a blur of kicks that holds them there, then the heel comes
-- down and spikes them into the street
function Handlers.EngineGatling(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.08)
	for _ = 1, ability.Hits or 8 do
		if not alive(char) then
			return
		end
		local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -4)
		for _, model in queryBox(char, cf, Vector3.new(8, 8, 8)) do
			if damage(player, model, ability.Damage, { Hitstop = 0.02 }) then
				stun(model, 0.5)
			end
		end
		task.wait(ability.Interval or 0.07)
	end
	task.wait(0.12)
	if not alive(char) then
		return
	end
	local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -4)
	for _, model in queryBox(char, cf, Vector3.new(9, 12, 9)) do
		if damage(player, model, ability.FinisherDamage or 14, { Heavy = true, Hitstop = 0.1 }) then
			knockback(model, -UP * 150 + d * 10, 0.18)
			ragdoll(model, 1.4)
			stun(model, 1.4)
		end
	end
	Destruction.Sphere(groundBelow(root.Position + d * 4, char), 8, "Crater")
end

-- RECIPRO BURST (held): the longer he holds it, the higher the gear - one
-- dash strike per gear, each one steered by his camera (his own machine
-- flies him), the last one hardest. Gear 3's last strike breaks the sound
-- barrier.
function Handlers.ReciproBurst(player, char, root, ability)
	local held, hold = HoldMoves.wait(player, char, ability)
	if not held then
		return
	end
	local level = HoldMoves.level(ability, held)
	broadcast("ReciproBurstRelease", char, { Level = level, Dir = hold.Dir }, player)
	local finish = ability.Finish or { 14, 16, 24 }
	for i = 1, level do
		if not alive(char) then
			return
		end
		local last = i == level
		local d = flatten(root.CFrame.LookVector, root)
		local dashTime = ability.DashTime or 0.18
		tunnel(char, root, dashTime, last and level == 3 and 7 or 5, 6)
		sweep(player, char, root, dashTime, 7, 3, d, function(model)
			if damage(player, model, last and (finish[level] or 14) or ability.Damage, { Hitstop = last and 0.1 or 0.04, Heavy = last }) then
				if last then
					knockback(model, flatten(root.CFrame.LookVector, root) * (80 + 40 * level) + UP * 30, 0.25)
					stun(model, 1.1)
					if level == 3 then
						ragdoll(model, 1.6)
					end
				else
					stun(model, 0.9)
				end
			end
		end)
		if not last then
			task.wait(0.08) -- (the pivot into the next one)
		end
	end
	if alive(char) and level == 3 then
		Destruction.Sphere(root.Position + root.CFrame.LookVector * 5, 8, "Wind", root.CFrame.LookVector)
	end
end

-- NUKE (the PLUS ULTRA dev kit's V): he HOLDS it - a sun-sized bomb grows
-- over his head (he can still walk, slowly) - and LETS GO to throw it where
-- he's aiming; it throws itself once fully grown. The blast wave rolls out
-- at WaveSpeed: people further out are hit (and buildings further out come
-- down) a moment later. It never hurts him, and it goes by the per-hit cap.
Kit.nuke = {}
function Kit.nuke.detonate(player, char, center, ability, scale)
	local radius = (ability.Radius or 260) * scale
	local wave = math.max(ability.WaveSpeed or 480, 1)
	local core = (ability.CoreRadius or 60) * scale
	for _, model in queryRadius(char, center, radius) do
		local troot = model:FindFirstChild("HumanoidRootPart")
		local dist = troot and (troot.Position - center).Magnitude or radius
		-- full damage in the core, falling off to EdgeDamage at the rim
		local k = math.clamp((dist - core) / math.max(radius - core, 1), 0, 1)
		local amount = ability.Damage + ((ability.EdgeDamage or ability.Damage * 0.5) - ability.Damage) * k
		task.delay(dist / wave, function()
			if model.Parent and damage(player, model, amount, { From = center, Heavy = true, Unblockable = true, Hitstop = 0.12 }) then
				knockback(model, awayFrom(center, model, UP) * (240 - 110 * k) + UP * (150 - 70 * k), 0.4)
				stun(model, 3 - k)
				ragdoll(model, 3 - k)
			end
		end)
	end
	-- the city goes with it, ring by ring as the wave passes
	local ground = groundBelow(center + UP * 6, char)
	local crater = (ability.Crater or 150) * scale
	for i, frac in { 0.35, 0.7, 1 } do
		task.delay((i - 1) * crater / 3 / wave, function()
			Destruction.Sphere(ground + UP * 4, crater * frac, "Nuke")
		end)
	end
end

function Handlers.Nuke(player, char, root, ability, _dir, pos)
	local held, hold = HoldMoves.wait(player, char, ability)
	if not held then
		return -- (knocked out holding it: it fizzles out - HoldCancel)
	end
	local maxCharge = (ability.Hold and ability.Hold.Max) or ability.MaxCharge or 3
	local minCharge = ability.MinCharge or 0.6
	local k = math.clamp((held - minCharge) / math.max(maxCharge - minCharge, 0.1), 0, 1)
	local minScale = ability.MinScale or 0.7
	local scale = minScale + (1 - minScale) * k
	local target = groundTarget(root, hold.Aim or pos, ability.Range or 300, char)
	local from = root.Position + UP * (8 + (ability.BombSize or 40) * scale / 2)
	-- (his own screen threw it already)
	broadcast("NukeThrow", char, { Target = target, From = from, Scale = scale }, player)
	task.wait(math.clamp((target - from).Magnitude / 200, 0.5, 1.6))
	Kit.nuke.detonate(player, char, target + UP * 6, ability, scale)
end

-- IIDA'S PRANK (the ult's, in the air: LB + RB together). "EVERYONE, PLEASE
-- STAND BACK!!" - he pulls one of the mufflers out of his calf and lobs it,
-- tumbling, at whoever he's aiming at. It homes in. It's a nuke (it never
-- hurts him).
function Handlers.MufflerNuke(player, char, root, ability, dir, pos, cast)
	if not (cast and cast.Air) then
		return -- (only off the ground: his own screen checks too)
	end
	task.wait(0.35) -- (it comes out of his calf)
	if not alive(char) then
		return
	end
	local range, speed = ability.Range or 180, math.max(ability.Speed or 150, 1)
	-- whoever's closest to where he's aiming, else the spot
	local aim = typeof(dir) == "Vector3" and dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
	local target, troot, best
	for _, model in queryRadius(char, root.Position, range) do
		local r = model:FindFirstChild("HumanoidRootPart")
		local v = r and (r.Position - root.Position)
		if v and v.Magnitude > 1 then
			local off = math.deg(math.acos(math.clamp(v.Unit:Dot(aim), -1, 1)))
			if off < 40 and (not best or off + v.Magnitude * 0.05 < best) then
				target, troot, best = model, r, off + v.Magnitude * 0.05
			end
		end
	end
	local spot = troot and troot.Position or groundTarget(root, pos, range, char)
	local p = root.Position + UP * 1.5 + aim * 2
	broadcast("MufflerThrow", char, { From = p, Target = target, To = spot, Speed = speed })
	local t0 = os.clock()
	while os.clock() - t0 < 3 do
		local dt = task.wait()
		local goal = (troot and troot.Parent and alive(target)) and troot.Position or spot
		local to = goal - p
		local step = speed * dt
		if to.Magnitude <= step + 2.5 then
			p = goal
			break
		end
		p += to.Unit * step
	end
	broadcast("MufflerBoom", char, { Pos = p, Radius = ability.Radius or 200, WaveSpeed = ability.WaveSpeed or 480 })
	Kit.nuke.detonate(player, char, p, ability, 1)
end

-- SKYWARD KICK (V): a rising kick that launches whoever's in front straight
-- up (and he hops up after them)
function Handlers.SkywardKick(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.14)
	if not alive(char) then
		return
	end
	local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 1, -4)
	for _, model in queryBox(char, cf, Vector3.new(8, 10, 8)) do
		if damage(player, model, ability.Damage, { Hitstop = 0.08 }) then
			knockback(model, UP * (ability.Launch or 95) + d * 8, 0.2)
			stun(model, 1.3)
		end
	end
end

function Handlers.ReciproTurbo(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.45) -- engine rev
	tunnel(char, root, 0.6, 5, 9) -- follows the zig-zag via his velocity
	local hitSet = sweep(player, char, root, 0.6, 9, 2, d, function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, d * 25, 0.12)
			stun(model, 1.6)
		end
	end)
	-- flurry on everyone caught, then the finishing kick
	for _ = 1, 2 do
		task.wait(0.09)
		for model in hitSet do
			if model.Parent then
				damage(player, model, math.floor(ability.Damage * 0.75))
			end
		end
	end
	task.wait(0.12)
	for model in hitSet do
		if model.Parent and damage(player, model, ability.FinisherDamage or 12) then
			knockback(model, d * 150 + UP * 55, 0.28)
			stun(model, 1)
		end
	end
	if alive(char) then
		Destruction.Sphere(root.Position + d * 5, 7, "Wind", d)
	end
end

-- 3D box along a beam (AP Shot, Phosphor): hits everything it passes through
local function beamHit(char, origin, dir, length, width, onHit)
	local cf = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -length / 2)
	for _, model in queryBox(char, cf, Vector3.new(width, width, length)) do
		onHit(model)
	end
end

-- EXPLOSION (later seasons)
-- AP Shot: straight out on the ground (it never dives into the street at
-- his feet - Aim), anywhere below him in the air (AirAim), where the
-- recoil kicks him up and back
function Handlers.APShot(player, char, root, ability, dir, _pos, cast)
	task.wait(0.18)
	if not alive(char) then
		return
	end
	local d = Config.AimedDirection(dir, root.CFrame.LookVector, cast.Air and ability.AirAim or ability.Aim)
	local origin = root.Position + UP * 1.5
	local length = ability.Range or 160
	beamHit(char, origin, d, length, 9, function(model)
		if damage(player, model, ability.Damage, { From = origin }) then
			knockback(model, d * 85 + UP * 18, 0.2)
			stun(model, ability.Stun or 0.7)
		end
	end)
	-- armour-piercing: drills a tunnel straight through buildings, and blows
	-- a hole wherever it first strikes
	Destruction.Capsule(origin + d * 3, origin + d * (length - 10), 4.5, "Beam", d)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local hit = workspace:Raycast(origin, d * length, params)
	if hit then
		Destruction.Sphere(hit.Position, 9, "Explosion", d)
	end
end

function Handlers.AutoCannon(player, char, root, ability, dir)
	Kit.liveAim[player] = nil
	task.wait(0.12)
	for i = 1, ability.Shots or 6 do
		if not alive(char) then
			return
		end
		-- (he aims while he shoots: each shot goes where he's aiming now)
		local live = Kit.liveAim[player]
		if live and os.clock() - live.Time < 0.4 then
			dir = live.Dir
		end
		broadcast("AutoCannonShot", char, { Dir = dir, Index = i }, player)
		local origin = root.Position + UP
		beamHit(char, origin, dir, 150, 7, function(model)
			if damage(player, model, ability.Damage) then
				knockback(model, dir * 40, 0.1)
				stun(model, ability.Stun or 0.45)
			end
		end)
		if i % 2 == 1 then
			Destruction.Capsule(origin + dir * 3, origin + dir * 140, 2.2, "Beam", dir)
		end
		task.wait(0.15)
	end
end

-- STUN GRENADE (R): a flash so bright it BLINDS anyone caught in it who
-- isn't guarding (their screen goes white and only slowly comes back). A
-- raised guard takes it on the arms: no blind, no stun. In the air the
-- light carries further.
function Handlers.StunGrenade(player, char, root, ability, _dir, _pos, cast)
	task.wait(0.25)
	if not alive(char) then
		return
	end
	local center = root.Position
	local radius = (ability.Radius or 34) * (cast.Air and 1.3 or 1)
	for _, model in queryRadius(char, center, radius) do
		if damage(player, model, ability.Damage, { From = center }) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 50 + UP * 25, 0.15)
			stun(model, ability.Stun or 1.6)
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then
				PlayVFX:FireClient(plr, "Blind", nil, { Duration = ability.Blind or 2.6, From = center })
			end
			model:SetAttribute("BlindedUntil", workspace:GetServerTimeNow() + (ability.Blind or 2.6))
		end
	end
end

-- HOWITZER IMPACT (ult): he rockets up and at the aim point, spinning
-- into a tornado of explosions, and crashes down in one enormous blast -
-- a crater and a ring of explosions round it
function Handlers.Howitzer(player, char, root, ability, dir, pos)
	local target = groundTarget(root, pos, ability.Range or 120, char)
	-- (the climb and the spin, then the dive: the same timing as his screen)
	local v = target - root.Position
	task.wait(0.95 + math.clamp(v.Magnitude / 220, 0.25, 0.7))
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	local radius = ability.Radius or 44
	for _, model in queryRadius(char, center + UP * 4, radius) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		local dist = mr and (mr.Position - center).Magnitude or radius
		local k = math.clamp(dist / radius, 0, 1)
		if damage(player, model, ability.Damage * (1 - 0.45 * k), { Heavy = true, Unblockable = true, Hitstop = 0.12, From = center }) then
			knockback(model, awayFrom(center, model, flatten(dir, root)) * (170 - 60 * k) + UP * (90 - 30 * k), 0.3)
			stun(model, 1.8)
			ragdoll(model, 1.8)
		end
	end
	Destruction.Sphere(center + UP * 4, ability.Crater or 40, "HugeExplosion")
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		task.delay(0.1 + i * 0.05, function()
			Destruction.Sphere(center + Vector3.new(math.cos(a) * radius * 0.8, 3, math.sin(a) * radius * 0.8), 12, "Explosion")
		end)
	end
end

function Handlers.Cluster(player, char, root, ability, dir, pos, cast)
	local target = groundTarget(root, pos, ability.Range or 90, char)
	-- same seeded ring as the VFX
	local ring = Random.new(cast.Seed)
	local offset = ring:NextNumber(0, math.pi * 2)
	local bombed = {}
	for i = 1, 8 do
		local a = offset + i / 8 * math.pi * 2
		local r = 11 + (i % 2) * 12
		local p = target + Vector3.new(math.cos(a) * r, 2, math.sin(a) * r)
		task.delay(0.35 + (i - 1) * 0.075 + 0.15, function()
			if not alive(char) then
				return
			end
			for _, model in queryRadius(char, p, 13) do
				-- (the ring overlaps: it only hits each target once)
				if not bombed[model] and damage(player, model, ability.Damage) then
					bombed[model] = true
					knockback(model, awayFrom(p, model, UP) * 50 + UP * 45, 0.15)
					stun(model, ability.BombStun or 0.9)
				end
			end
			Destruction.Sphere(p, 9, "SmallExplosion")
		end)
	end
	task.wait(1.05)
	local t0 = os.clock()
	repeat
		task.wait()
	until not alive(char) or os.clock() - t0 > 0.7 or (os.clock() - t0 > 0.05 and isGrounded(root, char))
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	for _, model in queryRadius(char, center, ability.Radius or 46) do
		if damage(player, model, ability.FinisherDamage or 65) then
			knockback(model, awayFrom(center, model, flatten(dir, root)) * 165 + UP * 80, 0.3)
			stun(model, 1.8)
			ragdoll(model, 1.6)
		end
	end
	Destruction.Sphere(center + UP * 4, 34, "BigExplosion")
end

-- FULL-BODY CLUSTER (the ult's 4, round 63): his last stand against
-- Shigaraki - chapter 362, "Light Fades to Rain" (Episode 149 of the anime).
-- Beaten half to death, he gets up and simply WALKS at them (WalkTime,
-- WalkDistance: nothing touches him - he reads every attack) - "Izuku...
-- you've gotta win." Then he's gone, and in their face: his palm lets off a
-- mass of stored Cluster point blank (BlinkDamage). He's stored so many
-- beads of sweat that they can't stay in his palms and burst out all over
-- his body: he's all round them, dodging and blasting from every side (Hits
-- x HitDamage, one more every other hit), each blast quicker than the last
-- (FirstGap, x Ramp). A moment in a white void (VoidTime - on his own screen:
-- he always wanted All Might to sign his card), then everything he has left
-- (FinalDamage, a launch, SplashDamage round them in Radius). His body pays
-- for it (SelfDamage - never his last point of health). Nobody in reach
-- (Range, a cone in front): he blasts off down the aim into one explosion.
function Handlers.FullBodyCluster(player, char, root, ability, dir)
	local d = flatten(dir, root)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local walkTime, hits = ability.WalkTime or 0.9, ability.Hits or 5
	local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
	local g, caught
	local completed = false
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + walkTime + 0.5 + hits * 0.25 + (ability.VoidTime or 0.7) + 0.6)
	char:SetAttribute("BodyLocked", true) -- (his own screen keeps its hands off his body)
	if hum then
		hum.AutoRotate = false
	end
	root.Anchored = true -- (the server carries him)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + walkTime + 0.3)
	local function valid()
		return player.Character == char and alive(char) and root.Parent ~= nil
			and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled")
	end
	local ok, err = xpcall(function()
		-- 1: the walk - a few steps straight at them, the beads popping off him
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local from = root.Position
		local wall = workspace:Raycast(from, d * (ability.WalkDistance or 5), params)
		local walkLen = wall and math.max((wall.Position - from).Magnitude - 2, 0) or (ability.WalkDistance or 5)
		local t0 = os.clock()
		while os.clock() - t0 < walkTime do
			if not valid() then
				return
			end
			local at = from + d * walkLen * math.clamp((os.clock() - t0) / walkTime, 0, 1)
			root.CFrame = CFrame.lookAt(at, at + d)
			task.wait()
		end
		-- 2: who's in reach
		local target = Grab.nearest(char, root, d, ability.Range or 55, 0.35)
		g = target and Grab.take(target, hits * 0.3 + (ability.VoidTime or 0.7) + 1)
		if not g then
			-- nobody (or they slipped it): he blasts off down the aim into one explosion
			local go = root.Position
			local far = workspace:Raycast(go, d * 16, params)
			local len = far and math.max((far.Position - go).Magnitude - 2.5, 0) or 16
			broadcast("FullBodyClusterWhiff", char, { From = go, Dir = d, Length = len })
			root.CFrame = CFrame.lookAt(go + d * len, go + d * (len + 1))
			task.wait(0.08)
			local boom = root.Position + d * 2.5
			for _, model in queryRadius(char, boom, 8) do
				if damage(player, model, ability.SplashDamage or 5, { From = boom }) then
					knockback(model, awayFrom(boom, model, d) * 70 + UP * 30, 0.2)
					stun(model, 0.6)
				end
			end
			Destruction.Sphere(boom, 8, "Explosion", d)
			completed = true
			return
		end
		caught = target
		local center = g.Root.Position
		local toward = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
		local faceDir = toward.Magnitude > 0.2 and toward.Unit or d
		-- 3: gone - and in their face, the palm going off point blank
		local at = center - faceDir * 2.6
		broadcast("FullBodyClusterBlink", char, { From = root.Position, To = at, Target = caught, Dir = faceDir })
		root.CFrame = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + hits * 0.3 + (ability.VoidTime or 0.7) + 1)
		task.wait(0.12)
		if not valid() then
			return
		end
		damage(player, caught, ability.BlinkDamage or 5, { Heavy = true, Hitstop = 0.06, From = at })
		-- 4: all round them, every side, quicker and quicker, higher and higher
		local ANGLES = { 115, -125, 30, 190, -55, 150, -170 }
		local gap = ability.FirstGap or 0.24
		local lift = 0
		for i = 1, hits do
			task.wait(gap)
			if not valid() or not alive(caught) then
				return
			end
			gap = math.max(gap * (ability.Ramp or 0.8), 0.07)
			lift += 0.7
			local c = center + UP * lift
			Grab.place(g, CFrame.lookAt(c, c - faceDir))
			local around = CFrame.fromAxisAngle(UP, math.rad(ANGLES[(i - 1) % #ANGLES + 1])):VectorToWorldSpace(faceDir)
			local spot = c - around * 3 + UP * ((i % 3 == 0) and 2.8 or ((i % 2 == 0) and 1 or 0))
			root.CFrame = CFrame.lookAt(spot, c)
			broadcast("FullBodyClusterHit", char, { Pos = spot, At = c, Target = caught, Level = i, Of = hits })
			damage(player, caught, (ability.HitDamage or 2) + math.floor((i - 1) / 2), { Hitstop = 0.03, From = spot })
		end
		-- 5: the white void (his screen) while both palms fill with everything he has
		local c = g.Root.Position
		local spot = c - faceDir * 3 + UP * 1.4
		root.CFrame = CFrame.lookAt(spot, c)
		broadcast("FullBodyClusterVoid", char, { Pos = c, From = spot, Dir = faceDir, Target = caught, Time = ability.VoidTime or 0.7 })
		task.wait(ability.VoidTime or 0.7)
		if not valid() then
			return
		end
		-- 6: all of it
		broadcast("FullBodyClusterFinal", char, { Pos = c, From = spot, Dir = faceDir, Target = caught })
		Grab.release(g, faceDir * 150 + UP * 60, 0.3)
		g = nil
		if damage(player, caught, ability.FinalDamage or 12, { Heavy = true, Hitstop = 0.14, From = spot }) then
			ragdoll(caught, 2.2)
			stun(caught, 1.8)
		end
		for _, model in queryRadius(char, c, ability.Radius or 12) do
			if model ~= caught and damage(player, model, ability.SplashDamage or 5, { From = c }) then
				knockback(model, awayFrom(c, model, faceDir) * 80 + UP * 35, 0.2)
				stun(model, 0.7)
			end
		end
		Destruction.Sphere(c, 13, "BigExplosion", faceDir)
		completed = true
	end, debug.traceback)
	-- every exit lets both bodies go
	if g then
		Grab.release(g)
	end
	if root.Parent then
		-- (the right way up again - he was looking down at them - facing the same way)
		local look = flatten(root.CFrame.LookVector, root)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		root.Anchored = anchored
		-- (the recoil of his own blast throws him back)
		root.AssemblyLinearVelocity = caught and completed and (-flatten(root.CFrame.LookVector, root) * 34 + UP * 24) or Vector3.zero
		if not anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end
	if hum and hum.Parent then
		hum.AutoRotate = autoRotate
	end
	char:SetAttribute("BodyLocked", nil)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.1)
	if completed and caught and hum and hum.Health > 1 then
		-- the beads burst out through skin that isn't made for it
		hum.Health = math.max(1, hum.Health - (ability.SelfDamage or 8))
	end
	if not completed then
		broadcast("FullBodyClusterCancel", char, { Target = caught })
	end
	if not ok then
		warn("[FullBodyCluster] " .. tostring(err))
	end
end


-- EXPLOSIVE SPEED (the ult's R - round 64, back): Explosive Speed: Cluster. He crouches like
-- a sprinter while the sweat beads pop all over him (WindUp), then the
-- server flies him straight down the aim at Speed - stopping short of a
-- wall - and the first one in his lane is caught face to face. Time slows
-- (SlowMo) while his palm comes up to their face, then the Explosion goes
-- off point blank. Every exit lets both bodies go.
function Handlers.ExplosiveSpeed(player, char, root, ability, dir)
	local d = flatten(dir, root)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local windUp, speed, slowMo = ability.WindUp or 0.6, ability.Speed or 230, ability.SlowMo or 0.75
	local range, width = ability.Range or 75, ability.Width or 4.5
	local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
	local g, caught, standAt
	local completed = false
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + windUp + range / speed + slowMo + 0.5)
	root.Anchored = true -- (rooted in the crouch; the server flies him)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
	-- (his own screen keeps its hands off his body meanwhile: the shift lock
	-- and the lock-on would stand him back upright every frame - flat out on
	-- the blitz, upside down at the catch)
	char:SetAttribute("BodyLocked", true)
	if hum then
		hum.AutoRotate = false
	end
	local function valid()
		return player.Character == char and alive(char) and root.Parent ~= nil
			and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled")
	end
	local ok, err = xpcall(function()
		local t0 = os.clock()
		while os.clock() - t0 < windUp do
			if not valid() then
				return
			end
			task.wait()
		end
		-- the lane: straight ahead, stopping short of a wall
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local from = root.Position
		local wall = workspace:Raycast(from, d * range, params)
		local length = wall and math.max((wall.Position - from).Magnitude - 2.5, 0) or range
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + length / speed + slowMo + 0.3)
		local tried = {}
		local traveled, last = 0, os.clock()
		-- anyone in the lane right now: he's on them the instant the crouch
		-- ends - a blink, not a run (that's how fast he is). Nobody: a blur
		-- down the lane, catching whoever steps into it
		local first, firstAlong
		for _, model in queryRadius(char, from + d * length / 2, length / 2 + width + 2) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			local rel = mr and mr.Position - from
			local along = rel and rel:Dot(d)
			local off = along and rel - d * along
			if along and along >= 1 and along <= length + 3 and Vector3.new(off.X, 0, off.Z).Magnitude <= width
				and math.abs(off.Y) <= 6 and (not firstAlong or along < firstAlong) then
				first, firstAlong = model, along
			end
		end
		if first then
			tried[first] = true
			g = Grab.take(first, slowMo + 0.6)
			if g then
				caught = first
				traveled = math.clamp(firstAlong - 2.6, 0, length)
			end
		end
		broadcast("ExplosiveSpeedGo", char, { From = from, Dir = d, Length = caught and traveled or length, Speed = speed, Blink = caught ~= nil })
		if caught then
			root.CFrame = CFrame.lookAt(from + d * traveled, from + d * traveled + d)
			task.wait() -- (a frame: the afterimages where he was)
			if not valid() then
				return
			end
		end
		while traveled < length and not caught do
			task.wait()
			if not valid() then
				return
			end
			local now = os.clock()
			local step = math.min(speed * (now - last), length - traveled)
			last = now
			-- anyone in the lane between here and the next spot
			local here = from + d * traveled
			local best, bestAlong
			for _, model in queryRadius(char, here + d * step / 2, step / 2 + width + 2) do
				local mr = model:FindFirstChild("HumanoidRootPart")
				if mr and not tried[model] then
					local rel = mr.Position - from
					local along = rel:Dot(d)
					local off = rel - d * along
					if along >= traveled - 2 and along <= traveled + step + 3 and Vector3.new(off.X, 0, off.Z).Magnitude <= width
						and math.abs(off.Y) <= 6 and (not bestAlong or along < bestAlong) then
						best, bestAlong = model, along
					end
				end
			end
			if best then
				tried[best] = true
				g = Grab.take(best, slowMo + 0.6)
				if g then
					caught = best
					traveled = math.clamp(bestAlong - 2.6, 0, length)
				end
			end
			if not caught then
				traveled += step
			end
			-- (flat out, face down, head first: a missile, not a man sliding)
			local at = from + d * traveled
			root.CFrame = CFrame.lookAt(at, at + d) * CFrame.Angles(math.rad(-80), 0, 0)
		end
		if not caught then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + d) -- (back on his feet)
			broadcast("ExplosiveSpeedWhiff", char, { Pos = root.Position, Dir = d })
			completed = true
			return
		end
		-- face to face: time slows as his palm comes up to their face - and he
		-- flips over as he gets there, upside down in front of them, his head
		-- level with theirs (chapter 406, his palm in All For One's face)
		local at = root.Position
		standAt = at
		local face = at + d * 2.6
		Grab.place(g, CFrame.lookAt(face, face - d))
		broadcast("ExplosiveSpeedCatch", char, { Target = caught, Pos = face, Dir = d, Time = slowMo })
		local hang = at + UP * (ability.FlipRise or 3)
		local flipped = CFrame.lookAt(hang, hang + d) * CFrame.Angles(0, 0, math.pi)
		local was, t1 = root.CFrame, os.clock()
		local flip = math.min(ability.FlipTime or 0.14, slowMo)
		while os.clock() - t1 < flip do
			root.CFrame = was:Lerp(flipped, math.clamp((os.clock() - t1) / flip, 0, 1))
			task.wait()
			if not valid() then
				return
			end
		end
		root.CFrame = flipped
		task.wait(slowMo - (os.clock() - t1))
		if not valid() then
			return
		end
		-- the Explosion, point blank
		Grab.release(g, d * 140 + UP * 55, 0.3)
		g = nil
		if damage(player, caught, ability.Damage, { Heavy = true, Hitstop = 0.14, From = at }) then
			ragdoll(caught, 2)
			stun(caught, 1.6)
		end
		for _, model in queryRadius(char, face, ability.Radius or 10) do
			if model ~= caught and damage(player, model, ability.SplashDamage or 6, { From = face }) then
				knockback(model, awayFrom(face, model, d) * 70 + UP * 35, 0.2)
				stun(model, 0.6)
			end
		end
		Destruction.Sphere(face, 12, "BigExplosion", d)
		broadcast("ExplosiveSpeedBlast", char, { Pos = face, Dir = d, Target = caught })
		completed = true
	end, debug.traceback)
	-- every exit lets both bodies go
	if g then
		Grab.release(g)
	end
	if root.Parent then
		if standAt then
			root.CFrame = CFrame.lookAt(standAt, standAt + d) -- (right way up again, feet back under him)
		end
		root.Anchored = anchored
		-- (the recoil of his own blast knocks him back a step)
		root.AssemblyLinearVelocity = caught and completed and (-d * 30 + UP * 22) or Vector3.zero
		if not anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end
	if hum and hum.Parent then
		hum.AutoRotate = autoRotate
	end
	char:SetAttribute("BodyLocked", nil)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.1)
	if not completed then
		broadcast("ExplosiveSpeedCancel", char, { Target = caught })
	end
	if not ok then
		warn("[ExplosiveSpeed] " .. tostring(err))
	end
end


-- BACKDROP DRIVER (muscle form): arms round whoever's in front, he arches
-- back and leaps - they go over his head and are driven into the street
-- behind him, and the shock throws everyone near off their feet
function Handlers.BackdropDriver(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.15)
	local model = alive(char) and Grab.nearest(char, root, d, ability.Range or 9, 0.3)
	local g = model and Grab.take(model, 1.2)
	broadcast("BackdropCatch", char, { Target = g and model or nil, Dir = d })
	if not g then
		return
	end
	damage(player, model, ability.GrabDamage or 6, { Hitstop = 0.05 })
	local over = ability.OverTime or 0.55
	local t0 = os.clock()
	local base = root.Position
	while os.clock() - t0 < over and alive(char) and g.Root.Parent do
		local a = math.clamp((os.clock() - t0) / over, 0, 1)
		-- from in front of him, up over his head, down behind him
		local ang = math.pi * a
		local at = root.Position + d * math.cos(ang) * 3.5 + UP * (math.sin(ang) * 5 + 0.5)
		Grab.place(g, CFrame.lookAt(at, at + d) * CFrame.Angles(ang, 0, 0))
		task.wait(0.03)
	end
	local impact = groundBelow((alive(char) and root.Position or base) - d * 3.5, char)
	Grab.release(g, -UP * 60, 0.15)
	if not alive(char) then
		return
	end
	if damage(player, model, ability.Damage, { Heavy = true, Hitstop = 0.14, From = impact + UP * 6 }) then
		ragdoll(model, 2)
		stun(model, 2)
	end
	for _, other in queryRadius(char, impact + UP * 2, ability.Radius or 16) do
		if other ~= model and damage(player, other, ability.ShockDamage or 10, { From = impact }) then
			knockback(other, awayFrom(impact, other, -d) * 80 + UP * 55, 0.22)
			stun(other, 1)
		end
	end
	Destruction.Sphere(impact, ability.Crater or 16, "Crater")
end

-- ONE FOR ALL: Plus Ultra (ult)
function Handlers.PlusUltraRush(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.2)
	for k = 1, ability.Hits or 12 do
		if not alive(char) then
			return
		end
		local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -5)
		for _, model in queryBox(char, cf, Vector3.new(8, 9, 10)) do
			if damage(player, model, ability.Damage) then
				knockback(model, d * 10, 0.08)
				stun(model, 0.5)
			end
		end
		if k % 4 == 0 then
			Destruction.Sphere(root.Position + d * 6, 3.5, "Impact", d)
		end
		task.wait(0.1)
	end
	task.wait(0.05)
	if not alive(char) then
		return
	end
	local look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 0, -7), Vector3.new(10, 10, 14)) do
		if damage(player, model, ability.FinisherDamage or 20) then
			knockback(model, d * 175 + UP * 45, 0.28)
			stun(model, 1.2)
		end
	end
	Destruction.Box(look * CFrame.new(0, 2, -24), Vector3.new(14, 14, 40), "Wind", d)
end

function Handlers.TexasSmashMax(player, char, root, ability, dir)
	task.wait(0.35)
	if not alive(char) then
		return
	end
	local d = flatten(dir, root)
	local look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 4, -70), Vector3.new(30, 30, 140)) do
		if damage(player, model, ability.Damage) then
			knockback(model, d * 190 + UP * 45, 0.3)
			stun(model, 1.3)
		end
	end
	Destruction.Box(look * CFrame.new(0, 7, -70), Vector3.new(24, 24, 130), "Wind", d)
end

-- HALF-COLD HALF-HOT: Phosphor (ult)
function Handlers.Phosphor(player, char, root, ability, dir)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local origin = root.Position + UP
	beamHit(char, origin, dir, 110, 9, function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, dir * 80 + UP * 20, 0.2)
			stun(model, 0.8)
			burn(model, ability.BurnTicks, ability.BurnDamage)
		end
	end)
	Destruction.Capsule(origin + dir * 3, origin + dir * 106, 3, "Beam", dir)
end

function Handlers.GlacialField(player, char, root, ability, dir, _pos, cast)
	task.wait(0.2)
	if not alive(char) then
		return
	end
	carveIce("GlacialField", cast, flatten(dir, root), char, 380)
	task.wait(0.3)
	for _, model in queryRadius(char, root.Position, 42) do
		if damage(player, model, ability.Damage) then
			freeze(model, ability.FreezeTime or 3)
		end
	end
end

function Handlers.HeatwaveMax(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	task.wait(0.45)
	if not alive(char) then
		return
	end
	local anchor = carveIce("HeatwaveMax", cast, d, char, 300)
	local look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 8, -30), Vector3.new(50, 30, 50)) do
		if damage(player, model, 6) then
			stun(model, 1.2)
		end
	end
	task.wait(0.8)
	if not alive(char) then
		return
	end
	look = CFrame.lookAt(root.Position, root.Position + d)
	for _, model in queryBox(char, look * CFrame.new(0, 12, -48), Vector3.new(84, 56, 100)) do
		if damage(player, model, ability.Damage) then
			knockback(model, d * 200 + UP * 70, 0.3)
			stun(model, 1.6)
			burn(model, ability.BurnTicks, ability.BurnDamage)
		end
	end
	Destruction.Sphere(anchor + d * 30 + UP * 10, 30, "BigExplosion")
end

-- LEMILLION: PHANTOM GRASP (V) - his arm sinks through the street and comes
-- up under whoever's ahead: it drags them down to the waist, then flings them
function Handlers.PhantomGrasp(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local model = Grab.nearest(char, root, d, ability.Range or 35, 0.6)
	local hold = ability.HoldTime or 1.2
	local g = model and Grab.take(model, hold + 0.4)
	broadcast("PhantomGraspCatch", char, { Target = g and model or nil, Time = hold })
	if not g then
		return
	end
	Grab.place(g, g.Root.CFrame - UP * (ability.Sink or 2.6))
	damage(player, model, ability.Damage, { Hitstop = 0.05 })
	task.wait(hold)
	Grab.release(g, UP * (ability.Launch or 90), 0.2)
	if alive(char) and damage(player, model, ability.LaunchDamage or 14, { Heavy = true, Hitstop = 0.08 }) then
		stun(model, 1.2)
	end
end

-- DECAY: SINKHOLE (V) - the street in front of him crumbles away and
-- swallows whoever's on it to the waist, decaying while they're stuck
function Handlers.Sinkhole(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.35)
	if not alive(char) then
		return
	end
	local range, width = ability.Range or 30, ability.Width or 24
	local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -range / 2 - 2)
	local holds = {}
	for _, model in queryBox(char, cf, Vector3.new(width, 12, range)) do
		if damage(player, model, ability.Damage, { From = root.Position }) then
			decayDot(player, model, ability.DecayTicks, ability.DecayDamage)
			local g = Grab.take(model, (ability.HoldTime or 1.5) + 0.3)
			if g then
				Grab.place(g, g.Root.CFrame - UP * (ability.Sink or 3))
				table.insert(holds, g)
			end
		end
	end
	Destruction.Box(cf * CFrame.new(0, -2, 0), Vector3.new(width, 5, range), "Decay", d)
	if Kit.SC then
		Kit.SC.onDecay(cf.Position, range / 2)
	end
	task.wait(ability.HoldTime or 1.5)
	for _, g in holds do
		Grab.release(g, UP * 30, 0.15)
	end
end

-- OVERHAUL: PILLAR RISE (V) - the street under him is rebuilt as a pillar
-- that throws him up (his own machine rides it), spikes round its foot
function Handlers.PillarRise(player, char, root, ability)
	task.wait(0.15)
	if not alive(char) then
		return
	end
	local base = groundBelow(root.Position, char)
	for _, model in queryRadius(char, base + UP * 3, ability.Radius or 12) do
		if damage(player, model, ability.Damage, { From = base }) then
			knockback(model, awayFrom(base, model, root.CFrame.LookVector) * 70 + UP * 50, 0.2)
			stun(model, 0.9)
		end
	end
	Destruction.Sphere(base, 6, "Overhaul")
end

-- ENGINE: Recipro Turbo (ult)
function Handlers.TurboKick(player, char, root, ability)
	local connected = false
	tunnel(char, root, 0.25, 3.5, 5)
	-- centred on him: the client picks the target and blinks there
	sweep(player, char, root, 0.35, 7, 0, Vector3.zero, function(model)
		if connected then
			return
		end
		if damage(player, model, ability.Damage) then
			connected = true
			local f = flatten(root.CFrame.LookVector, root)
			knockback(model, f * 90 + UP * 25, 0.2)
			stun(model, 0.6)
		end
	end)
end

function Handlers.ReciproMax(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.6)
	tunnel(char, root, 0.55, 9, 14, function()
		return d
	end)
	sweep(player, char, root, 0.55, 10, 3, d, function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, d * 200 + UP * 60, 0.3)
			stun(model, 1.5)
		end
	end)
	if alive(char) then
		Destruction.Sphere(root.Position + d * 6, 12, "Wind", d)
	end
end

---------------------------------------------------------------------------
-- DECAY (fully awakened). Timings mirror the VFX / cinematics.
---------------------------------------------------------------------------

-- everyone inside a vertical cylinder (decay climbs whole buildings)
local function queryCylinder(char, base, radius, height, hitSet)
	local out = {}
	local cf = CFrame.new(base + UP * (height / 2))
	for _, model in queryBox(char, cf, Vector3.new(radius * 2, height, radius * 2), hitSet) do
		local r = model:FindFirstChild("HumanoidRootPart")
		if r and Vector3.new(r.Position.X - base.X, 0, r.Position.Z - base.Z).Magnitude <= radius then
			table.insert(out, model)
		end
	end
	return out
end

-- Decay racing outward from a point: every step widens the ring, crumbles
-- the map inside it and catches whoever it reaches (once each)
local function decaySpread(char, center, maxRadius, duration, height, profile, onHit)
	local hitSet = {}
	local steps = math.max(3, math.floor(duration / 0.15 + 0.5))
	for i = 1, steps do
		if not alive(char) then
			return
		end
		local r = maxRadius * i / steps
		for _, model in queryCylinder(char, center - UP * 2, r, height, hitSet) do
			hitSet[model] = true
			onHit(model)
		end
		Destruction.Cylinder(center + UP * (height / 2 - 1.5), r, height, profile, UP)
		if Kit.SC then
			Kit.SC.onDecay(center, r, maxRadius) -- (on the Sky Coffin its plates fire themselves off)
		end
		task.wait(duration / steps)
	end
end

-- straight finger lances (Rivet Stab / Rivet Storm), each target hit once
local function lances(char, origin, dirs, length, radius, hitSet, onHit)
	for _, v in dirs do
		beamHit(char, origin, v, length, 3.5, function(model)
			if not hitSet[model] then
				hitSet[model] = true
				onHit(model, v)
			end
		end)
		Destruction.Capsule(origin + v * 2, origin + v * length, radius, "Rivet", v)
	end
end

function Handlers.DecayWave(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.25) -- palm to the ground
	if not alive(char) then
		return
	end
	local start = groundBelow(root.Position, char)
	local range = ability.Range or 64
	local steps = 8
	local seg = range / steps
	local hitSet = {}
	for i = 1, steps do
		if not alive(char) then
			return
		end
		local p = start + d * (seg * i)
		local cf = CFrame.lookAt(p, p + d) * CFrame.new(0, 7, seg / 2)
		for _, model in queryBox(char, cf, Vector3.new(12, 16, seg + 2), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage) then
				knockback(model, UP * 30 + d * 10, 0.15)
				stun(model, 0.8)
				decayDot(player, model, ability.DecayTicks, ability.DecayDamage)
			end
		end
		Destruction.Box(cf, Vector3.new(10, 16, seg + 1), "Decay", d)
		if Kit.SC then
			Kit.SC.onDecay(p, 6)
		end
		task.wait(0.075)
	end
end

function Handlers.DecayGrasp(player, char, root, ability, dir)
	local d = flatten(dir, root)
	tunnel(char, root, 0.4, 4.5, 6, function()
		return d
	end, "Decay")
	local caught = false
	sweep(player, char, root, 0.4, 6, 2.5, d, function(model)
		if caught then
			return
		end
		-- (round 68) someone lying in the street is grabbed too
		if damage(player, model, ability.Damage, { HitsDowned = true }) then
			caught = true
			stun(model, 1.4)
			decayDot(player, model, ability.DecayTicks, ability.DecayDamage)
			broadcast("Grasped", char, { Target = model })
			-- let the crumble set in, then shove them away
			task.delay(0.6, function()
				if model.Parent then
					knockback(model, d * 60 + UP * 35, 0.2)
				end
			end)
		end
	end)
end

function Handlers.Collapse(player, char, root, ability)
	task.wait(0.55) -- the cinematic: both hands come down
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	decaySpread(char, center, ability.Radius or 46, 0.9, 130, "Decay", function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 40 + UP * 50, 0.2)
			stun(model, 1.2)
			decayDot(player, model, ability.DecayTicks, ability.DecayDamage)
		end
	end)
end

function Handlers.RivetStab(player, char, root, ability, dir)
	task.wait(0.2)
	if not alive(char) then
		return
	end
	local dirs = {}
	for _, a in { -14, -7, 0, 7, 14 } do
		table.insert(dirs, CFrame.Angles(0, math.rad(a), 0) * dir)
	end
	lances(char, root.Position + UP, dirs, ability.Range or 110, 1.1, {}, function(model, v)
		if damage(player, model, ability.Damage) then
			knockback(model, v * 45 + UP * 10, 0.15)
			stun(model, 0.7)
		end
	end)
end

-- RADIO WAVES (a stolen quirk): black lightning builds in his arms, then an
-- electromagnetic pulse ripples out in a wide fan. The wave travels (Speed):
-- whoever it reaches is hurt, hurled back and jammed - static over their
-- screen, their lock-on gone - for Jam seconds
function Handlers.RadioWaves(player, char, root, ability, dir)
	task.wait(0.4)
	if not alive(char) then
		return
	end
	local d = flatten(dir, root)
	local range = ability.Range or 85
	local cosHalf = math.cos(math.rad(ability.Angle or 60))
	local speed = math.max(ability.Speed or 220, 1)
	local center = root.Position
	for _, model in queryRadius(char, center + d * range * 0.4, range * 0.75) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		local v = mr and Vector3.new(mr.Position.X - center.X, 0, mr.Position.Z - center.Z)
		if v and v.Magnitude <= range and (v.Magnitude < 4 or v.Unit:Dot(d) >= cosHalf) then
			task.delay(v.Magnitude / speed, function()
				if not model.Parent or not alive(char) then
					return
				end
				if damage(player, model, ability.Damage or 26, { Heavy = true, Hitstop = 0.08, From = center }) then
					local away = v.Magnitude > 0.5 and v.Unit or d
					knockback(model, away * 140 + UP * 35, 0.28)
					stun(model, 1.2)
					model:SetAttribute("JammedUntil", workspace:GetServerTimeNow() + (ability.Jam or 2.5))
					local victim = Players:GetPlayerFromCharacter(model)
					if victim then
						PlayVFX:FireClient(victim, "Jammed", nil, { Duration = ability.Jam or 2.5 })
					end
				end
			end)
		end
	end
	-- the pulse shoves everything loose in front of him
	local look = CFrame.lookAt(center, center + d)
	Destruction.Box(look * CFrame.new(0, 6, -range * 0.45), Vector3.new(range * 0.9, 16, range * 0.8), "Wind", d)
end

-- 14 lances erupting in a ring (alternating slightly up / level)
local function stormDirs()
	local dirs = {}
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		table.insert(dirs, Vector3.new(math.cos(a), i % 2 == 0 and 0.18 or -0.04, math.sin(a)).Unit)
	end
	return dirs
end

function Handlers.RivetStorm(player, char, root, ability)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	lances(char, root.Position + UP, stormDirs(), ability.Range or 90, 1.4, {}, function(model, v)
		if damage(player, model, ability.Damage) then
			knockback(model, Vector3.new(v.X, 0, v.Z) * 70 + UP * 25, 0.2)
			stun(model, 1)
		end
	end)
end

function Handlers.TotalDecay(player, char, root, ability)
	task.wait(1.3) -- the cinematic: he rises, then slams both hands down
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	decaySpread(char, center, ability.Radius or 120, 2.4, 170, "DecayHuge", function(model)
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 30 + UP * 60, 0.25)
			stun(model, 1.6)
			decayDot(player, model, ability.DecayTicks, ability.DecayDamage)
		end
	end)
end

---------------------------------------------------------------------------
-- ONE FOR ALL: United States of Smash (rebuilt to match the anime) and
-- Colorado Smash (muscle form's V leap)
---------------------------------------------------------------------------

-- (round 78) a move that didn't come off costs only `wait` seconds of its
-- cooldown (his own screen is told, so its timer agrees)
function Kit.shortCooldown(player, ability, wait)
	local quirkName = player:GetAttribute("Quirk")
	local alt, ult, pick = player:GetAttribute("QuirkAlt") == true, player:GetAttribute("UltActive") == true, player:GetAttribute("QuirkPick")
	for _, index in { 1, 2, 3, Config.EXTRA_INDEX, Config.SPECIAL_INDEX } do
		if Config.GetAbility(quirkName, index, alt, ult, pick) == ability then
			local key = Config.CooldownKey(quirkName, index, alt, ult, pick)
			local cds = cooldowns[player] or {}
			cooldowns[player] = cds
			cds[key] = os.clock() + wait - (ability.Cooldown or 0)
			PlayVFX:FireClient(player, "Reload", nil, { Key = key, Time = wait, Full = ability.Cooldown or 0 })
			return key
		end
	end
	return nil
end

-- (round 78) The way it went against All For One at Kamino. The left is a
-- decoy: he lunges in with it and it has to land - nobody caught is a whiff,
-- nothing more (and the ult isn't spent on it: WhiffCooldown). Caught, they're
-- held there dazed while the last embers of One For All pour into his right
-- arm ("UNITED STATES OF..."); the overhand right lands on the face - the
-- impact frame, everything stops (FreezeTime) - then it drives them down into
-- the street. The wind pressure craters it and blows everyone else away, and
-- a twister grows out of the crater, lifting everyone near and tearing the
-- buildings round it apart.
function Handlers.UnitedStatesSmash(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(ability.LungeStartup or 0.16)
	if not alive(char) then
		return
	end
	-- the lunge (his own screen carries him): the first one he reaches
	local target
	local tried = {}
	local t0 = os.clock()
	while not target and alive(char) and os.clock() - t0 < (ability.LungeTime or 0.32) + 0.08 do
		for _, model in Rewind.QueryRadius(player, char, root.Position + d * 3.5, 5.5, tried) do
			tried[model] = true
			target = target or model
		end
		if not target then
			task.wait(0.03)
		end
	end
	-- (a little forgiveness: anyone right in front of him as he stops)
	if not target and alive(char) then
		target = Grab.nearest(char, root, d, 8, 0.35)
	end
	local build, freeze, slamTime = ability.BuildTime or 2, ability.FreezeTime or 0.38, ability.SlamTime or 0.12
	local g = target and alive(char) and Grab.take(target, build + freeze + slamTime + 0.4)
	-- (a boss can't be picked up - the Nomu: it's punched where it stands)
	local boss = not g and target ~= nil and target:GetAttribute("Boss") == true and alive(target) and alive(char)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	if not g and not (boss and troot) then
		-- a whiff: no smash, and the ult isn't spent on it
		broadcast("USSWhiff", char, { Dir = d, Id = ability.Id })
		Kit.shortCooldown(player, ability, ability.WhiffCooldown or 5)
		iFrames[char] = math.min(iFrames[char] or 0, os.clock())
		return
	end
	-- caught: armoured right through to the end, and nothing else till then
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + build + freeze + slamTime + 0.5)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + build + freeze + slamTime + 0.6)
	damage(player, target, ability.JabDamage or 6, { Hitstop = 0.1, Unblockable = true, NoKnockdown = true, From = root.Position })
	broadcast("USSCatch", char, { Target = target, Dir = d, Id = ability.Id, Build = build, Freeze = freeze, Slam = slamTime })
	-- held there in front of him, dazed, reeling a little
	local tb = os.clock()
	while os.clock() - tb < build and alive(char) and (not g or g.Root.Parent) do
		if g then
			local a = (os.clock() - tb) / build
			local at = root.Position + d * 4.6 + UP * (0.3 + 0.35 * a)
			Grab.place(g, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)) * CFrame.Angles(math.rad(-10 * a), 0, 0))
		end
		task.wait(0.03)
	end
	if not alive(char) then
		Grab.release(g)
		return
	end
	-- the overhand right on the face: knocked back half a step - and everything stops
	if g then
		local face = g.Root.Position
		Grab.place(g, CFrame.lookAt(face + d * 0.8, face + d * 0.8 - d) * CFrame.Angles(math.rad(14), 0, 0))
	end
	task.wait(freeze)
	-- ...then down through them into the street
	local impact = groundBelow(g and (root.Position + d * 5.5) or troot.Position, char)
	if g then
		local from = g.Root.Position
		local ts = os.clock()
		while os.clock() - ts < slamTime and g.Root.Parent do
			local a = math.clamp((os.clock() - ts) / slamTime, 0, 1) ^ 2
			local at = from:Lerp(impact + UP * 1.1, a)
			Grab.place(g, CFrame.lookAt(at, at - d) * CFrame.Angles(math.rad(14 + 66 * a), 0, 0))
			task.wait(1 / 60)
		end
		Grab.release(g, -UP * 30, 0.12)
	else
		task.wait(slamTime)
	end
	broadcast("USSSlam", char, { Pos = impact, Target = target, Dir = d, Id = ability.Id })
	local hitSet = { [target] = true }
	if damage(player, target, ability.Damage, { Heavy = true, Unblockable = true, Hitstop = 0.06, From = impact + UP * 8 }) then
		stun(target, 2.6)
		ragdoll(target, 2.3)
	end
	Destruction.Sphere(impact, 30, "Crater")
	-- the wind pressure blows everyone else away
	for _, model in queryRadius(char, impact, ability.WindRadius or 46, hitSet) do
		hitSet[model] = true
		if damage(player, model, ability.WindDamage or 24) then
			knockback(model, awayFrom(impact, model, d) * 140 + UP * 60, 0.3)
			stun(model, 1.4)
		end
	end
	-- the twister: a towering funnel grows out of the crater. Anyone near it is
	-- dragged in; inside they're whirled round and carried up, then thrown out
	-- of the top. It rips through the buildings around its base as it spins.
	-- (The one he buried stays in the crater.)
	local duration = ability.TwisterTime or 6.5
	local height = ability.TwisterHeight or 300
	local topR = ability.TwisterTopRadius or 110
	local baseR = math.max(topR * 0.12, 10)
	local pullR = ability.TwisterPull or 90
	local swept = {}
	local t1 = os.clock()
	while os.clock() - t1 < duration do
		local k = (os.clock() - t1) / duration
		local grown = math.min(1, (os.clock() - t1) / 1.1)
		for _, model in queryCylinder(char, impact, pullR, height, { [target] = true }) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr then
				local rel = mr.Position - impact
				local out = Vector3.new(rel.X, 0, rel.Z)
				local dist = out.Magnitude
				out = dist > 0.1 and out.Unit or d
				local h = math.clamp(rel.Y, 0, height)
				local funnelR = baseR + (topR - baseR) * (h / height) ^ 1.7
				local spin = UP:Cross(out)
				if dist <= funnelR + 8 then
					-- caught: round and up (and flung out once near the top)
					local nearTop = h > height * 0.8 * grown
					knockback(model, spin * 75 - out * 20 + UP * (nearTop and 20 or 70) + (nearTop and out * 90 or Vector3.zero), 0.26)
					if not swept[model] then
						swept[model] = true
						if damage(player, model, ability.TwisterDamage or 10) then
							stun(model, 1.4)
						end
					end
				elseif h < 60 then
					-- the suction around its foot drags people in
					knockback(model, -out * 38 + spin * 22 + UP * 6, 0.26)
				end
			end
		end
		local r = baseR + 6 + k * 14
		Destruction.Cylinder(impact + UP * 40, r, 80, "Whirl", UP)
		task.wait(0.25)
	end
end

-- WEATHER CHANGER (ult V): an uppercut at the sky so strong its wind
-- pressure makes an updraft - everyone around is sucked up high and held
-- there, the clouds split open... then the whole sky comes down on them
function Handlers.WeatherChanger(player, char, root, ability)
	task.wait(0.45)
	if not alive(char) then
		return
	end
	local center = root.Position
	local caught = {}
	for _, model in queryRadius(char, center, ability.Radius or 45) do
		if damage(player, model, ability.Damage, { From = center }) then
			local mr = model:FindFirstChild("HumanoidRootPart")
			local inward = mr and Vector3.new(center.X - mr.Position.X, 0, center.Z - mr.Position.Z) or Vector3.zero
			knockback(model, UP * 140 + inward * 0.6, 0.35)
			stun(model, (ability.HangTime or 1.1) + 1.5)
			table.insert(caught, model)
		end
	end
	Destruction.Cylinder(center + UP * 6, (ability.Radius or 45) * 0.45, 14, "Whirl")
	task.wait(ability.HangTime or 1.1)
	for _, model in caught do
		if model.Parent then
			knockback(model, -UP * 180, 0.25)
			if damage(player, model, ability.DropDamage or 26, { Heavy = true, Hitstop = 0.1, From = center + UP * 60 }) then
				ragdoll(model, 1.6)
				stun(model, 1.4)
			end
			local mr = model:FindFirstChild("HumanoidRootPart")
			task.delay(0.35, function()
				if mr and mr.Parent then
					Destruction.Sphere(groundBelow(mr.Position, char), 9, "Crater")
				end
			end)
		end
	end
end

function Handlers.ColoradoSmash(player, char, root, ability, _dir, pos)
	local aim = pos
	if ability.Hold then
		-- (round 75) on his feet, crouched, while his camera's up in the sky
		-- aiming it; the second press goes
		local held, hold = HoldMoves.wait(player, char, ability)
		if not held or not alive(char) then
			return
		end
		aim = (hold and hold.Aim) or pos
	end
	local target = groundTarget(root, aim, ability.Range or 160, char)
	local travel = ability.TravelTime or 1.5
	broadcast("ColoradoGo", char, { Pos = target, Time = travel })
	task.wait(0.3) -- crouch
	if not alive(char) then
		return
	end
	-- the takeoff alone cracks the street
	local takeoff = groundBelow(root.Position, char)
	for _, model in queryRadius(char, takeoff, 12) do
		if damage(player, model, 8) then
			knockback(model, awayFrom(takeoff, model, UP) * 60 + UP * 50, 0.2)
		end
	end
	Destruction.Sphere(takeoff, 7, "Crater")
	-- coming down: bore through everything between him and the landing
	task.delay(travel * 0.5, function()
		if not alive(char) then
			return
		end
		tunnel(char, root, travel * 0.55 + 0.3, 7.5, 6)
		sweep(player, char, root, travel * 0.55, 8, 0, Vector3.zero, function(model)
			if damage(player, model, ability.DiveDamage or 18) then
				knockback(model, -UP * 60 + awayFrom(root.Position, model, UP) * 40, 0.15)
				stun(model, 0.8)
			end
		end)
	end)
	local t0 = os.clock()
	repeat
		task.wait(0.03)
	until not alive(char) or os.clock() - t0 > travel + 1.2 or (os.clock() - t0 > travel * 0.6 and isGrounded(root, char))
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	broadcast("ColoradoLand", char, { Pos = center })
	for _, model in queryRadius(char, center, ability.LandRadius or 30) do
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 120 + UP * 70, 0.3)
			stun(model, 1.4)
		end
	end
	Destruction.Sphere(center, 22, "Crater")
end

---------------------------------------------------------------------------
-- ONE FOR ALL: 9TH (Deku). Timings mirror the VFX.
---------------------------------------------------------------------------

-- the nearest model along a line (Delaware Smash, Blackwhip, Red)
local function firstInLine(char, origin, d, length, width)
	local best, bestDist
	beamHit(char, origin, d, length, width, function(model)
		local r = model:FindFirstChild("HumanoidRootPart")
		local dist = r and (r.Position - origin):Dot(d)
		if dist and dist > -2 and (not bestDist or dist < bestDist) then
			best, bestDist = model, dist
		end
	end)
	return best, bestDist
end

-- how far a shot travels before the map stops it
local function wallDistance(char, origin, d, length)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local hit = workspace:Raycast(origin, d * length, params)
	return hit and hit.Distance or length
end

function Kit.cowlActive(player, char)
	return player.Character == char and alive(char) and not char:GetAttribute("Stunned")
		and not char:GetAttribute("Ragdolled") and not char:GetAttribute("Grabbed")
end

-- DELAWARE SMASH: AIR FORCE - flick after flick (alternate hands), each a
-- bullet of compressed air down the aim; the last one blows them away
function Handlers.DelawareSmash(player, char, root, ability, dir, _pos, cast)
	task.wait(ability.Startup or 0.12)
	local shots = ability.Shots or 1
	for i = 1, shots do
		if not Kit.cowlActive(player, char) then return end
		local last = i == shots
		local aim = Kit.liveAim[player] and os.clock() - Kit.liveAim[player].Time < 0.5 and Kit.liveAim[player].Dir or dir
		local origin = root.Position + UP
		local length = cast and cast.Air and 80 or (ability.Range or 110)
		local target, distance = firstInLine(char, origin, aim, length, 5)
		local reach = target and math.max(distance, 1) or length
		task.spawn(function()
			task.wait(reach / 420)
			if target and Kit.cowlActive(player, char) and damage(player, target, ability.Damage, { Hitstop = last and 0.06 or 0.03, Heavy = last, From = origin }) then
				knockback(target, aim * (last and 70 or 14) + UP * (last and 20 or 4), last and 0.2 or 0.08)
				stun(target, last and 0.6 or 0.4)
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					broadcast("AirForceHit", char, { Pos = tr.Position + UP, Dir = aim, Last = last })
				end
			end
			Destruction.Capsule(origin + aim * 3, origin + aim * reach, last and 2.4 or 1.7, "Wind", aim)
		end)
		if not last then
			task.wait(ability.Gap or 0.13)
		end
	end
end

-- BLACKWHIP (Deku's 4th slot): black tendrils snag the first person in
-- line, reel them in, whirl them round overhead once and hurl them where he
-- was aiming (into whatever's there)
function Handlers.Blackwhip(player, char, root, ability, dir)
	task.wait(0.12)
	if not Kit.cowlActive(player, char) then return end
	local model = firstInLine(char, root.Position + UP, dir, ability.Range or 48, 5)
	if not model or not damage(player, model, ability.Damage, { Hitstop = 0.035, From = root.Position }) or not alive(model) then return end
	local g = Grab.take(model, 0.35)
	if not g then return end
	broadcast("BlackwhipCatch", char, { Target = model, Dir = dir, Throw = false, Duration = 0.32 })
	local from, d, t0 = g.Root.Position, flatten(dir, root), os.clock()
	while os.clock() - t0 < 0.32 and Kit.cowlActive(player, char) and alive(model) and g.Root.Parent do
		local alpha = math.clamp((os.clock() - t0) / 0.32, 0, 1)
		alpha = 1 - (1 - alpha) ^ 3
		local at = from:Lerp(root.Position + d * 7 + UP * 0.3, alpha)
		Grab.place(g, CFrame.lookAt(at, root.Position))
		task.wait(1 / 60)
	end
	Grab.release(g)
end

-- Deku's R: the next of the earlier holders' quirks into his 4th slot
function Handlers.QuirkCycle(player)
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	local n = quirk and quirk.Extras and #quirk.Extras or 0
	if n > 0 then
		player:SetAttribute("QuirkPick", ((player:GetAttribute("QuirkPick") or 1) % n) + 1)
	end
end

function Handlers.Smokescreen(player, char, root, ability)
	task.wait(0.1)
	if not alive(char) then
		return
	end
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.8) -- gone in the smoke
	local center = root.Position
	local radius = ability.Radius or 24
	local seen = {}
	local t0 = os.clock()
	-- (it lifts if he's knocked out; it never chokes him, even in a new body)
	while os.clock() - t0 < (ability.Duration or 5) and alive(char) do
		for _, model in queryRadius(char, center, radius, seen) do
			seen[model] = true
			if Players:GetPlayerFromCharacter(model) == player then
				continue
			end
			if damage(player, model, ability.Damage) then
				stun(model, 0.6)
			end
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then
				PlayVFX:FireClient(plr, "Smoked", nil, { Duration = 2.2 })
			end
		end
		task.wait(0.3)
	end
end

function Handlers.StLouisSmash(player, char, root, ability, dir, _pos, cast)
	local a = Config.AimedDirection(dir, root.CFrame.LookVector, ability.Aim)
	local d = flatten(a, root)
	task.wait(ability.Startup or 0.18)
	if not Kit.cowlActive(player, char) then return end
	local look = CFrame.lookAt(root.Position, root.Position + a)
	local seen = {}
	for _, model in Rewind.QueryBox(player, char, look * CFrame.new(0, 0.5, -7), Vector3.new(11, 10, 15), seen) do
		seen[model] = true
		if damage(player, model, ability.Damage, { Hitstop = 0.055, Heavy = true, From = root.Position }) then
			local air = cast and cast.Air and a.Y < -0.15
			knockback(model, air and (d * 32 - UP * 65) or (d * 26 + UP * 28), 0.14)
			stun(model, 0.55)
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr then broadcast("CowlKickHit", char, { Pos = mr.Position + UP, Dir = a, Air = air }) end
		end
	end
	Destruction.Box(look * CFrame.new(0, 1, -8), Vector3.new(10, 3, 14), "Slash", d)
	-- AIR FORCE: the kick fires a blade of compressed air on down the aim
	local range = ability.Range or 45
	if range > 16 then
		task.wait(0.06)
		local from = root.Position
		local width = ability.BladeWidth or 16
		local blade = CFrame.lookAt(from, from + a)
		for _, model in queryBox(char, blade * CFrame.new(0, 0.5, -range / 2), Vector3.new(width, 9, range), seen) do
			seen[model] = true
			if damage(player, model, ability.BladeDamage or 18, { Hitstop = 0.05, Heavy = true, From = from }) then
				knockback(model, d * 60 + UP * 26, 0.2)
				stun(model, 0.5)
				local mr = model:FindFirstChild("HumanoidRootPart")
				if mr then broadcast("CowlKickHit", char, { Pos = mr.Position + UP, Dir = a, Air = false }) end
			end
		end
		Destruction.Box(blade * CFrame.new(0, 2, -range / 2), Vector3.new(width * 0.6, 4, range), "Slash", d)
	end
end

function Handlers.ManchesterSmash(player, char, root, ability)
	local travel = ability.TravelTime or 0.46
	task.wait(travel)
	local deadline = os.clock() + 0.22
	while Kit.cowlActive(player, char) and not isGrounded(root, char, 6) and os.clock() < deadline do
		task.wait(1 / 60)
	end
	if not Kit.cowlActive(player, char) then return end
	local center = groundBelow(root.Position, char)
	broadcast("ManchesterLand", char, { Pos = center, Dir = root.CFrame.LookVector, Radius = ability.LandRadius, Shock = ability.ShockRadius })
	local hitSet = {}
	for _, model in queryRadius(char, center, ability.LandRadius or 12) do
		hitSet[model] = true
		if damage(player, model, ability.Damage, { Heavy = true, Hitstop = 0.075, From = center }) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 38 + UP * 48, 0.2)
			stun(model, 0.85)
			ragdoll(model, 1)
		end
	end
	-- the shockwave rolls out past the crater
	for _, model in queryRadius(char, center, ability.ShockRadius or 0, hitSet) do
		if damage(player, model, ability.ShockDamage or 0, { From = center }) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 46 + UP * 18, 0.18)
			stun(model, 0.5)
		end
	end
	Destruction.Sphere(center, 10, "Crater")
end

-- FA JIN: DETROIT SMASH - press it and he squats, quicker and quicker, the
-- kinetic energy piling up in his legs; press it again (or squat it all the
-- way up) and every bit of it goes out through them: he rockets forward
-- (his own machine flies him, Launch studs) straight into one Detroit Smash
-- - a gale down the street, the longer he stored it the further he goes and
-- the harder, further and wider it blows. It catches everyone from where he
-- took off to the end of the gale.
function Handlers.FaJinSmash(player, char, root, ability, dir)
	local held, hold = HoldMoves.wait(player, char, ability)
	if not held then
		return
	end
	local spec = ability.Hold or {}
	local k = math.clamp(held / (spec.Max or 2.4), 0, 1)
	local level = HoldMoves.level(ability, held)
	local d = flatten(hold.Dir or dir, root)
	local L = ability.Launch or {}
	local launch = (L.Min or 16) + ((L.Max or 62) - (L.Min or 16)) * k
	local start = root.Position
	broadcast("FaJinSmashRelease", char, { Level = level, Dir = d, Power = k }, player)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + (L.Time or 0.24) + 0.5)
	task.wait((L.Time or 0.24) + 0.08)
	if not alive(char) then
		return
	end
	local min = ability.MinScale or 0.5
	local power = min + (1 - min) * k
	local length = (ability.Range or 110) * (0.65 + 0.35 * k)
	local width = (ability.Width or 26) * (0.7 + 0.3 * k)
	local look = CFrame.lookAt(start, start + d)
	local reach = launch + length
	for _, model in queryBox(char, look * CFrame.new(0, 3, -reach / 2), Vector3.new(width, width, reach)) do
		if damage(player, model, math.floor(ability.Damage * power + 0.5), { Heavy = true, Hitstop = 0.08 + 0.06 * k, From = root.Position }) then
			knockback(model, d * (110 + 100 * k) + UP * (30 + 30 * k), 0.3)
			stun(model, 1 + 0.6 * k)
			if level > #(spec.Levels or {}) then
				ragdoll(model, 1.6)
			end
		end
	end
	Destruction.Box(look * CFrame.new(0, 6, -launch - length / 2 - 3), Vector3.new(width * 0.75, width * 0.75, length), "Wind", d)
end

-- GEARSHIFT: each press shifts him up a gear (faster on his feet, for a
-- while after the last shift); at TOP GEAR the next press is TRANSMISSION:
-- he's on whoever he's aiming at and the punches come faster and faster,
-- the last sending them flying - then the recoil, back to neutral
Kit.GS = { tokens = setmetatable({}, { __mode = "k" }) }
function Kit.GS.set(player, char, gear, ability)
	local token = {}
	Kit.GS.tokens[char] = token
	char:SetAttribute("Gearshift", gear > 0 and gear or nil)
	if Kit.applyPassives then
		Kit.applyPassives(player, char, false) -- (the new walk speed; defined further down)
	end
	if gear > 0 then
		task.delay((ability and ability.GearTime) or 12, function()
			if Kit.GS.tokens[char] == token and char.Parent then
				Kit.GS.set(player, char, 0)
				broadcast("GearshiftDown", char, {})
			end
		end)
	end
end

function Handlers.Gearshift(player, char, root, ability, dir)
	local top = ability.TopGear or 4
	local gear = char:GetAttribute("Gearshift") or 0
	if gear < top then
		Kit.GS.set(player, char, gear + 1, ability)
		return
	end
	-- TRANSMISSION
	local d = flatten(dir, root)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local anchored = root.Anchored
	local target = Grab.nearest(char, root, d, ability.Range or 55, 0.5)
	local g = target and Grab.take(target, 3)
	local hits = ability.Hits or 9
	local quint = ability.Quintuple or 0
	local interval = ability.Interval or 0.2
	local total, step = 0, interval
	for _ = 1, hits do
		total += step
		step = math.max(ability.MinInterval or 0.04, step * (ability.Speedup or 0.78))
	end
	total += quint * 0.16
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + total + 1)
	local tr = g and g.Root
	local face
	if tr then
		-- he's just there, right in front of them
		local flat = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
		d = flat.Magnitude > 0.5 and flat.Unit or d
		face = tr.Position - d * 4
		root.Anchored = true
		char:SetAttribute("BodyLocked", true)
		root.CFrame = CFrame.lookAt(face, face + d)
		Grab.place(g, CFrame.lookAt(tr.Position, tr.Position - d))
	end
	-- OVERDRIVE (Gearshift + Fa Jin, 120%) gets him there; TRANSMISSION
	broadcast("TransmissionRush", char, { Target = target, Dir = d, Hits = hits, Quintuple = quint, Total = total })
	local ok, err = pcall(function()
		task.wait(0.12)
		step = interval
		for i = 1, hits do
			if not alive(char) then
				return
			end
			local at = tr and tr.Position or root.Position + d * 5
			for _, model in queryRadius(char, at, 6) do
				if damage(player, model, ability.Damage or 3, { Hitstop = 0.012, From = root.Position }) and model ~= target then
					stun(model, 0.3)
				end
			end
			broadcast("GearshiftHit", char, { Pos = at + UP * 1.5, N = i, Hits = hits, Dir = d })
			-- (each punch drives them back a step, and he stays right on them)
			if tr and tr.Parent then
				local nextAt = tr.Position + d * 0.9
				Grab.place(g, CFrame.lookAt(nextAt, nextAt - d))
				local me = nextAt - d * 4
				root.CFrame = CFrame.lookAt(me, me + d)
			end
			task.wait(step)
			step = math.max(ability.MinInterval or 0.04, step * (ability.Speedup or 0.78))
		end
		-- DETROIT SMASH: QUINTUPLE - five of them, one after another
		for q = 1, quint do
			if not alive(char) then
				return
			end
			local at = tr and tr.Position or root.Position + d * 5
			for _, model in queryRadius(char, at, 7) do
				if damage(player, model, ability.QuintupleDamage or 7, { Hitstop = 0.05, Heavy = true, From = root.Position }) and model ~= target then
					stun(model, 0.4)
				end
			end
			broadcast("GearshiftHit", char, { Pos = at + UP * 1.5, N = hits + q, Hits = hits, Dir = d, Quintuple = q })
			if tr and tr.Parent then
				local nextAt = tr.Position + d * 1.6
				Grab.place(g, CFrame.lookAt(nextAt, nextAt - d))
				local me = nextAt - d * 4
				root.CFrame = CFrame.lookAt(me, me + d)
			end
			task.wait(0.16)
		end
		-- the last one: everything the gears built up
		local at = tr and tr.Position or root.Position + d * 5
		for _, model in queryRadius(char, at, 8) do
			if damage(player, model, ability.FinisherDamage or 24, { Heavy = true, Hitstop = 0.09, From = root.Position }) and model ~= target then
				knockback(model, d * 120 + UP * 40, 0.3)
				ragdoll(model, 1.4)
			end
		end
		broadcast("GearshiftHit", char, { Pos = at + UP * 1.5, N = hits + quint + 1, Hits = hits, Dir = d, Final = true })
		Destruction.Sphere(at + d * 6, 8, "Impact", d)
	end)
	if g then
		Grab.release(g, d * 130 + UP * 45, 0.3)
		if alive(g.Model) then
			ragdoll(g.Model, 1.6)
			-- geared down: Gearshift works on whatever he touches
			slow(g.Model, ability.SlowTime or 3, (g.Model:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed) * (ability.Slow or 0.5))
			broadcast("GearedDown", g.Model, { Time = ability.SlowTime or 3 })
		end
	end
	if root.Parent then
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
		if not anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end
	char:SetAttribute("BodyLocked", nil)
	if not ok then
		warn("[Gearshift] " .. tostring(err))
	end
	-- the recoil: back to neutral, locked up a moment, and it needs time
	Kit.GS.set(player, char, 0)
	if alive(char) then
		stun(char, ability.Recoil or 0.6)
		broadcast("GearshiftRecoil", char, { Time = ability.Recoil or 0.6 })
	end
	local key = Config.CooldownKey(player:GetAttribute("Quirk"), Config.EXTRA_INDEX, player:GetAttribute("QuirkAlt") == true, player:GetAttribute("UltActive") == true, player:GetAttribute("QuirkPick"))
	local cds = cooldowns[player] or {}
	cooldowns[player] = cds
	local wait = ability.RushCooldown or 18
	cds[key] = os.clock() + wait - (ability.Cooldown or 0)
	PlayVFX:FireClient(player, "Reload", nil, { Key = key, Time = wait })
	if hum and hum.Parent and hum.Health <= 0 then
		return
	end
end

-- 100%: SHOOT STYLE RUSH - the lightning blitz from the movies: he's a
-- streak of green lightning zig-zagging round them faster than they can turn.
-- He takes the one in front (or the spot he's aiming at) and is on them from
-- one side, then the other, then round the back - a kick every time he lands
-- (Hits, Gap apart, Orbit studs out), the server carrying him from point to
-- point - then he's back in front for the finisher, the big kick that sends
-- them flying. Anyone else caught in the storm (Radius) is kicked too.
function Handlers.GearshiftRush(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.12)
	if not Kit.cowlActive(player, char) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local from = root.Position
	local target = Grab.nearest(char, root, d, ability.Range or 26, 0.4)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local center
	if troot then
		center = Vector3.new(troot.Position.X, from.Y, troot.Position.Z)
	else
		local wall = workspace:Raycast(from, d * 9, params)
		center = from + d * (wall and math.max(wall.Distance - 3, 2) or 9)
	end
	-- the zig-zag: side to side and round them, never through a wall
	local hits, gap, orbit = ability.Hits or 7, ability.Gap or 0.07, ability.Orbit or 4.6
	local points = {}
	for i = 1, hits do
		local side = i % 2 == 1 and 1 or -1
		local out = CFrame.fromAxisAngle(UP, math.rad(side * (48 + (i - 1) * 21))) * -d
		local wall = workspace:Raycast(center, out * orbit, params)
		points[i] = center + out * (wall and math.max(wall.Distance - 1.4, 1.6) or orbit)
	end
	local finishAt = center - d * 3.6
	local total = hits * gap + 0.2
	local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
	root.Anchored = true
	char:SetAttribute("BodyLocked", true)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + total + 0.3)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + total + 0.2)
	if hum then hum.AutoRotate = false end
	broadcast("RushBlitz", char, { From = from, Center = center, Points = points, Gap = gap, Finish = finishAt, Dir = d, Target = target })
	local ok, err = xpcall(function()
		for _, p in points do
			if not Kit.cowlActive(player, char) then return end
			root.CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z))
			for _, model in queryRadius(char, center, ability.Radius or 6.5) do
				if damage(player, model, ability.Damage, { Hitstop = 0.015, From = p }) then
					local mr = model:FindFirstChild("HumanoidRootPart")
					local push = mr and Vector3.new(mr.Position.X - p.X, 0, mr.Position.Z - p.Z)
					knockback(model, (push and push.Magnitude > 0.1 and push.Unit or d) * 5 + UP * 3, 0.05)
					stun(model, 0.3)
				end
			end
			task.wait(gap)
		end
		if not Kit.cowlActive(player, char) then return end
		-- back in front of them: the big one
		root.CFrame = CFrame.lookAt(finishAt, Vector3.new(center.X, finishAt.Y, center.Z))
		task.wait(0.08)
		if not Kit.cowlActive(player, char) then return end
		local look = CFrame.lookAt(finishAt, finishAt + d)
		for _, model in queryBox(char, look * CFrame.new(0, 2, -5), Vector3.new(10, 12, 12)) do
			if damage(player, model, ability.FinisherDamage or 14, { Heavy = true, Hitstop = 0.065, From = finishAt }) then
				knockback(model, d * 42 + UP * 48, 0.18)
				stun(model, 0.8)
			end
		end
		Destruction.Box(look * CFrame.new(0, 3, -7), Vector3.new(10, 10, 12), "Impact", d)
	end, debug.traceback)
	if root.Parent then
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if not anchored then pcall(function() root:SetNetworkOwnershipAuto() end) end
	end
	if hum and hum.Parent then hum.AutoRotate = autoRotate end
	char:SetAttribute("BodyLocked", nil)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.1)
	if not ok then warn("[GearshiftRush] " .. tostring(err)) end
end

function Handlers.BlackwhipSlam(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.25)
	if not Kit.cowlActive(player, char) then return end
	local range = ability.Range or 45
	local grabs, targets, starts = {}, {}, {}
	for _, model in queryRadius(char, root.Position + d * range / 2, range / 2 + 3) do
		if #grabs >= (ability.MaxTargets or 3) then break end
		local mr = model:FindFirstChild("HumanoidRootPart")
		local v = mr and mr.Position - root.Position
		if v and v.Magnitude <= range and (v.Magnitude < 3 or v.Unit:Dot(d) > 0.55)
			and damage(player, model, ability.CatchDamage or 4, { From = root.Position }) and alive(model) then
			local g = Grab.take(model, 0.75)
			if g then
				table.insert(grabs, g)
				table.insert(targets, model)
				table.insert(starts, g.Root.Position)
			end
		end
	end
	if #grabs == 0 then return end
	broadcast("BlackwhipBind", char, { Targets = targets, SlamDelay = 0.6, Duration = 0.75 })
	local t0 = os.clock()
	while os.clock() - t0 < 0.6 and Kit.cowlActive(player, char) do
		local alpha = math.clamp((os.clock() - t0) / 0.3, 0, 1)
		for i, g in grabs do
			if g.Root.Parent and alive(g.Model) then
				local at = starts[i] + UP * (8 * math.sin(alpha * math.pi / 2))
				Grab.place(g, CFrame.lookAt(at, at + d))
			end
		end
		task.wait(1 / 60)
	end
	for _, g in grabs do
		if Kit.cowlActive(player, char) and alive(g.Model) and g.Root.Parent then
			local impact = groundBelow(g.Root.Position, char)
			Grab.place(g, CFrame.new(impact + UP * 3))
			local landed = damage(player, g.Model, ability.Damage, { Heavy = true, Hitstop = 0.065, From = root.Position })
			Grab.release(g, UP * 18 + d * 18, 0.12)
			if landed then ragdoll(g.Model, 1); stun(g.Model, 1) end
			Destruction.Sphere(impact, 6, "Crater")
		else
			Grab.release(g)
		end
	end
end

-- INFINITE 100% - the end of the Overhaul fight (ep. 76), Eri on his back
-- healing him as fast as the power breaks him: the kick has to land, and it
-- blasts them high into the air; he's up after them, punching faster and
-- faster, then the fists come raining down on them and drive them into the
-- street - and it all goes off. The server owns both bodies and every hit;
-- a whiff never locks anyone, and he can't be touched while it runs.
-- (the barrage's rhythm: each punch a little quicker than the last)
function Kit.rainIntervals(ability)
	local out, total = {}, 0
	for i = 1, ability.Hits or 16 do
		local gap = math.max(ability.MinInterval or 0.035, (ability.Interval or 0.12) * (ability.Speedup or 0.86) ^ (i - 1))
		out[i] = gap
		total += gap
	end
	return out, total
end

function Handlers.FistRain(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(ability.Startup or 0.18)
	if not Kit.cowlActive(player, char) then return end
	local target = Grab.nearest(char, root, d, ability.Range or 22, 0.6)
	if not target or not damage(player, target, ability.LaunchDamage or 8, { Heavy = true, Hitstop = 0.05, From = root.Position }) or not alive(target) then return end
	local rise, rainTime = ability.RiseTime or 0.3, ability.RainTime or 0.6
	local gaps, barrage = Kit.rainIntervals(ability)
	local total = rise + barrage + 0.1 + rainTime
	local g = Grab.take(target, total + 0.6)
	if not g then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
	local completed = false
	char:SetAttribute("FistRainActive", true)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + total + 0.4)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + total + 0.5)
	root.Anchored = true
	if hum then hum.AutoRotate = false end
	local function valid()
		return Kit.cowlActive(player, char) and alive(target) and g.Root.Parent ~= nil and root.Parent ~= nil
	end
	local ok, err = xpcall(function()
		local from, casterFrom = g.Root.Position, root.Position
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char, target }
		-- as high as the kick can send them under whatever's overhead
		local most = ability.Lift or 26
		local ceiling = workspace:Raycast(from + UP * 2, UP * (most + 9), rp)
		local lift = ceiling and math.clamp(ceiling.Distance - 9, 0, most) or most
		local air = lift >= 8
		local at = from + UP * (air and lift or 0)
		local casterAt = air and (at - d * 5.5 + UP * 0.5) or casterFrom
		if workspace:Raycast(casterFrom, casterAt - casterFrom, rp) then
			air, at, casterAt = false, from, casterFrom
		end
		local impact = groundBelow(at, char)
		broadcast("FistRainCatch", char, {
			Target = target, Air = air, Hits = #gaps, RiseTime = rise, Barrage = barrage, RainTime = rainTime, At = at, Pos = impact,
		})
		-- the kick sends them up; he's after them a beat later
		local t0 = os.clock()
		while os.clock() - t0 < rise do
			if not valid() then return end
			local t = os.clock() - t0
			local a1 = 1 - (1 - math.clamp(t / rise, 0, 1)) ^ 3
			local a2 = 1 - (1 - math.clamp((t - rise * 0.3) / (rise * 0.7), 0, 1)) ^ 2
			local victimPos = from:Lerp(at, a1)
			Grab.place(g, CFrame.lookAt(victimPos, victimPos + d))
			root.CFrame = CFrame.lookAt(casterFrom:Lerp(casterAt, a2), victimPos)
			task.wait(1 / 60)
		end
		-- the storm: faster and faster, every hit jolting them about
		local right = d:Cross(UP)
		for i, gap in gaps do
			if not valid() then return end
			local jolt = right * math.random(-25, 25) / 100 + UP * math.random(-20, 20) / 100 + d * 0.3
			Grab.place(g, CFrame.lookAt(at + jolt, at + jolt + d))
			root.CFrame = CFrame.lookAt(casterAt + right * (i % 2 == 0 and 0.4 or -0.4), at)
			broadcast("FistRainStrike", char, { Target = target, Pos = at, Index = i, Final = false })
			damage(player, target, ability.Damage or 1, { Hitstop = 0, From = root.Position })
			task.wait(gap)
		end
		task.wait(0.1)
		if not valid() then return end
		-- then the fists come raining down on them and drive them into the street
		local victimEnd = impact + UP * 3
		local casterTop = casterAt + UP * 5 - d * 2
		broadcast("FistRainFall", char, { Target = target, From = at, Pos = impact, Time = rainTime, Hits = ability.RainHits or 4 })
		local rainHits, landed = ability.RainHits or 4, 0
		local r0 = os.clock()
		while os.clock() - r0 < rainTime do
			if not valid() then return end
			local a = math.clamp((os.clock() - r0) / rainTime, 0, 1)
			local victimPos = at:Lerp(victimEnd, a * a)
			Grab.place(g, CFrame.lookAt(victimPos, victimPos + d))
			root.CFrame = CFrame.lookAt(casterAt:Lerp(casterTop, math.min(1, a * 2)), victimPos)
			while landed < rainHits and a >= (landed + 0.5) / rainHits do
				landed += 1
				damage(player, target, ability.RainDamage or 4, { Hitstop = 0, From = casterTop })
			end
			task.wait(1 / 60)
		end
		if not valid() then return end
		Grab.place(g, CFrame.lookAt(victimEnd, victimEnd + d))
		-- and it all goes off
		broadcast("FistRainFinish", char, { Target = target, Pos = impact, Air = air, From = at })
		Kit.breakArm(char, "R", 30) -- (INFINITE 100%: both arms black and blue after)
		Kit.breakArm(char, "L", 30)
		local hit = damage(player, target, ability.FinisherDamage or 22, { Heavy = true, Hitstop = 0.1, From = impact + UP * 6 })
		-- (left lying in the crater)
		Grab.release(g, UP * 4, 0.1)
		if hit then stun(target, 1.2); ragdoll(target, 1.5) end
		for _, other in queryRadius(char, impact, ability.Radius or 16) do
			if other ~= target and damage(player, other, ability.ShockDamage or 10, { From = impact }) then
				knockback(other, awayFrom(impact, other, d) * 45 + UP * 30, 0.16)
			end
		end
		Destruction.Sphere(impact + UP, 11, "Crater", UP)
		-- he comes back down beside the crater
		local casterEnd = air and (groundBelow(casterTop - d * 3, char) + UP * 3) or casterFrom
		local c0 = os.clock()
		while os.clock() - c0 < 0.18 and root.Parent do
			local a = math.clamp((os.clock() - c0) / 0.18, 0, 1)
			root.CFrame = CFrame.lookAt(casterTop:Lerp(casterEnd, a * a), casterEnd + d)
			task.wait(1 / 60)
		end
		root.CFrame = CFrame.lookAt(casterEnd, casterEnd + d)
		completed = true
	end, debug.traceback)
	-- Every exit, including interruption, death and errors, releases both bodies.
	Grab.release(g)
	if root.Parent then
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if not anchored then pcall(function() root:SetNetworkOwnershipAuto() end) end
	end
	if hum and hum.Parent then hum.AutoRotate = autoRotate end
	char:SetAttribute("FistRainActive", nil)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.1)
	if not completed then broadcast("FistRainCancel", char, { Target = target }) end
	if not ok then warn("[FistRain] " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- KAMUI WOODS (Shinji Nishiya): Arbor
---------------------------------------------------------------------------

-- a ray that only stops on solid map: invisible walls, walk-through props
-- and anyone's stuff let it on through (what a swing line can hold on to)
function Kit.solidHit(origin, ray, range, params)
	local dir = ray.Unit
	local from, left = origin, range
	for _ = 1, 4 do
		local hit = workspace:Raycast(from, dir * left, params)
		local part = hit and hit.Instance
		if not (part and part:IsA("BasePart") and (part.Transparency > 0.95 or not part.CanCollide)) then
			return hit
		end
		local gone = (hit.Position - from).Magnitude + 0.05
		from, left = from + dir * gone, left - gone
		if left <= 1 then
			return nil
		end
	end
	return nil
end

-- something solid at `anchor`, above his head and within reach: what a
-- branch (or a tentacle) can swing him from. Checked from where his own
-- screen had him when he pressed it (`origin`) as well as where the server
-- has him - flying along a chain of swings the two are a few studs apart,
-- and a good line shouldn't be turned down for it.
function Kit.swingAnchorOk(char, root, anchor, range, origin)
	if typeof(anchor) ~= "Vector3" or anchor ~= anchor then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local slack = math.min(root.AssemblyLinearVelocity.Magnitude * 0.25, 30)
	for _, at in { typeof(origin) == "Vector3" and origin == origin and origin or nil, root.Position } do
		local from = at + UP * 2
		local v = anchor - from
		if v.Magnitude <= range + 8 + slack and anchor.Y >= at.Y + 2.5 - slack * 0.25 then
			local hit = Kit.solidHit(from, v, v.Magnitude + 3, params)
			if hit and (hit.Position - anchor).Magnitude < 4 then
				return true
			end
		end
	end
	return false
end

-- somewhere to swing from, the way a swinger's own screen looks: where he's
-- aiming if that's up at something, else the best of a fan up, ahead and to
-- either side (Config.SwingFan, scored by Config.SwingScore)
function Kit.swingSearch(char, root, aim, range)
	local bestNormal -- (round 60: the zip wants the face it caught, too)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local origin = root.Position + UP * 2
	local look = flatten(aim, root)
	local right = look:Cross(UP)
	local best, bestScore
	local function try(ray, bonus)
		local hit = Kit.solidHit(origin, ray, range, params)
		if hit and hit.Position.Y > root.Position.Y + 3 then
			local rel = hit.Position - root.Position
			local ahead = rel:Dot(look)
			local score = Config.SwingScore(ahead, rel.Y, math.abs(rel:Dot(right))) + (bonus or 0)
			if ahead > -4 and (not bestScore or score > bestScore) then
				best, bestScore, bestNormal = hit.Position + hit.Normal * 0.4, score, hit.Normal
			end
		end
	end
	if aim.Y > 0.15 then
		try(aim, 25)
	end
	for _, pitch in Config.SwingFan.Pitches do
		for _, yaw in Config.SwingFan.Yaws do
			local a, p = math.rad(yaw), math.rad(pitch)
			try((look * math.cos(a) + right * math.sin(a)) * math.cos(p) + UP * math.sin(p))
		end
	end
	return best, bestNormal
end

-- (round 60) where Suneater's ZIP goes: the first solid thing down his aim
-- (Zip.Range) - not the street at his feet, nothing nearer than MinDistance
-- - or, aimed up at open sky, the best spot round there (swingSearch). On a
-- wall close under its top (Zip.Ledge studs) it's the ledge he's going to,
-- so he ends up standing on the roof. { Anchor, Normal, Ledge } or nil.
function Kit.zipPoint(char, root, aim, Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local origin = root.Position + UP * 1.5
	local range = Z.Range or 95
	local hit = Kit.solidHit(origin, aim, range, params)
	local at, normal
	if hit and (hit.Position - origin).Magnitude >= (Z.MinDistance or 8) and not (hit.Normal.Y > 0.6 and hit.Position.Y < root.Position.Y + 2) then
		at, normal = hit.Position, hit.Normal
	elseif not hit and aim.Y > 0.12 then
		at, normal = Kit.swingSearch(char, root, aim, range)
	end
	if not at then
		return nil
	end
	normal = normal or -aim.Unit
	local ledge = normal.Y > 0.6 -- (a roof: he lands on it)
	if math.abs(normal.Y) < 0.6 then
		-- (near the top of a wall: over the lip - if there's open roof up there)
		local snap = Z.Ledge or 12
		local top = workspace:Raycast(at - normal * 1.2 + UP * (snap + 1), -UP * (snap + 1.5), params)
		if top and top.Normal.Y > 0.7 and top.Position.Y > at.Y - 0.5 then
			local lip = Vector3.new(at.X, top.Position.Y, at.Z)
			if not workspace:Raycast(lip + normal * 1 + UP * 2.5, -normal * 3, params) then
				at, ledge = lip, true
			end
		end
	end
	return { Anchor = at + normal * 0.4, Normal = normal, Ledge = ledge }
end

-- a zip costs only Zip.Cooldown seconds of Tako Snatch's cooldown (his own
-- screen does the same when it sees the zip)
function Kit.zipCooldown(player, ability)
	local quirkName = player:GetAttribute("Quirk")
	local q = Config.Quirks[quirkName or ""]
	local left = (ability.Cooldown or 8) - ((ability.Zip and ability.Zip.Cooldown) or 2.5)
	for i, a in (q and q.Abilities) or {} do
		if a == ability and cooldowns[player] then
			local key = Config.CooldownKey(quirkName, i, false, false)
			if cooldowns[player][key] then
				cooldowns[player][key] -= math.max(left, 0)
			end
		end
	end
end

-- where the Timber Slingshot branch grabs: the nearest building face up off
-- the street round him (behind or beside him first - he flies back over
-- them), or - nothing in reach - a trunk bursting out of the street behind him
function Kit.woodAnchor(char, root, d, range, apex)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local origin = root.Position + UP * 2
	local right = d:Cross(UP)
	local best, bestScore
	for _, yaw in { 180, 150, 210, 120, 240, 90, 270, 60, 300, 0 } do
		local a = math.rad(yaw)
		local flat = d * math.cos(a) + right * math.sin(a)
		for _, pitch in { 30, 50, 70 } do
			local p = math.rad(pitch)
			local ray = (flat * math.cos(p) + UP * math.sin(p)).Unit
			local hit = workspace:Raycast(origin, ray * range, params)
			if hit and hit.Position.Y > root.Position.Y + 5 then
				local score = hit.Distance + (yaw == 0 and 25 or 0)
				if not bestScore or score < bestScore then
					best, bestScore = hit.Position + hit.Normal * 1, score
				end
			end
		end
	end
	if best then
		return best, false
	end
	local base = groundBelow(root.Position - d * 9, char)
	return base + UP * math.max(14, (apex.Y - base.Y) * 0.8), true
end

-- LACQUERED CHAIN PRISON: branches along the aim, and the first one they
-- reach is caged in wood where they stand
function Handlers.ChainPrison(player, char, root, ability, dir)
	local d = flatten(dir, root)
	local aim = Config.AimedDirection(dir, d, { Up = 60, Down = 30 })
	task.wait(0.12)
	if not alive(char) then
		return
	end
	local origin = root.Position + UP * 1.5
	local range = ability.Range or 50
	local target = Kit.snatchTarget(char, origin, aim, range, ability.AimAssist or 12)
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local reach = tr and (tr.Position - origin).Magnitude or wallDistance(char, origin, aim, range)
	task.wait(math.min(reach / 180, 0.25)) -- (the branches' flight)
	local caught = target and alive(char) and damage(player, target, ability.Damage or 8, { Hitstop = 0.06, From = root.Position })
		and alive(target)
	local bind = ability.Bind or 1.6
	broadcast("ChainPrisonCatch", char, { Target = caught and target or nil, Dir = aim, Reach = reach, Duration = bind })
	if caught then
		stun(target, bind, 0)
		local troot = target:FindFirstChild("HumanoidRootPart")
		if troot then
			-- (held where the cage closed: in the air too)
			knockback(target, Vector3.zero, math.min(bind, 0.8), true)
		end
	end
end

-- TIMBER SLINGSHOT: up they go; a branch to a building (or a trunk out of
-- the street), he's pulled up it, flung off it over them, and drives them
-- into the street. Both bodies are held and moved here (like the barrage).
function Handlers.TimberSlingshot(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.15)
	if not alive(char) then
		return
	end
	local target = Grab.nearest(char, root, d, ability.Range or 12, 0.4)
	if not target or not damage(player, target, ability.LaunchDamage or 6, { Heavy = true, Hitstop = 0.05, From = root.Position }) or not alive(target) then
		broadcast("TimberWhiff", char, { Dir = d })
		return
	end
	local TOSS, SHOOT, PULL, FLING, DROP = 0.4, 0.12, 0.26, 0.24, 0.18
	local total = TOSS + SHOOT + PULL + FLING + DROP
	local g = Grab.take(target, total + 0.6)
	if not g then
		broadcast("TimberWhiff", char, { Dir = d })
		return
	end
	local big = ability.Id == "GreatSlingshot"
	local hum = char:FindFirstChildOfClass("Humanoid")
	local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
	local completed = false
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + total + 0.3)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + total + 0.3)
	root.Anchored = true
	if hum then
		hum.AutoRotate = false
	end
	local function valid()
		return player.Character == char and alive(char) and alive(target) and g.Root.Parent ~= nil and root.Parent ~= nil
	end
	local ok, err = xpcall(function()
		local from, casterFrom = g.Root.Position, root.Position
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = nonMapStuff(char)
		-- as high as there's room for overhead
		local most = ability.Lift or 24
		local ceiling = workspace:Raycast(from + UP * 2, UP * (most + 6), rp)
		local lift = ceiling and math.clamp(ceiling.Distance - 6, 4, most) or most
		local apex = from + UP * lift + d * 4
		local anchor, pillar = Kit.woodAnchor(char, root, d, ability.AnchorRange or 45, apex)
		broadcast("TimberToss", char, {
			Target = target, From = from, Apex = apex, Anchor = anchor, Pillar = pillar or nil,
			Toss = TOSS, Shoot = SHOOT, Pull = PULL, Fling = FLING, Drop = DROP, Big = big or nil,
		})
		-- up they go
		local t0 = os.clock()
		while os.clock() - t0 < TOSS do
			if not valid() then
				return
			end
			local a = 1 - (1 - math.clamp((os.clock() - t0) / TOSS, 0, 1)) ^ 3
			local p = from:Lerp(apex, a)
			Grab.place(g, CFrame.lookAt(p, p + d))
			task.wait(1 / 60)
		end
		-- the branch shoots out to the anchor...
		task.wait(SHOOT)
		if not valid() then
			return
		end
		-- ...he's pulled up to it (they drift on up)...
		local toAnchor = anchor - casterFrom
		local pullTo = anchor - (toAnchor.Magnitude > 3 and toAnchor.Unit * 2.5 or Vector3.zero)
		t0 = os.clock()
		while os.clock() - t0 < PULL do
			if not valid() then
				return
			end
			local a = math.clamp((os.clock() - t0) / PULL, 0, 1)
			root.CFrame = CFrame.lookAt(casterFrom:Lerp(pullTo, a * a), apex)
			Grab.place(g, CFrame.lookAt(apex + UP * a, apex + UP * a + d))
			task.wait(1 / 60)
		end
		-- ...and flung off it, up over them
		local held = apex + UP
		local over = held + UP * 6
		local mid = (pullTo + over) / 2 + UP * 5
		t0 = os.clock()
		while os.clock() - t0 < FLING do
			if not valid() then
				return
			end
			local a = math.clamp((os.clock() - t0) / FLING, 0, 1)
			local p = pullTo:Lerp(mid, a):Lerp(mid:Lerp(over, a), a)
			root.CFrame = CFrame.lookAt(p, held)
			task.wait(1 / 60)
		end
		-- the downslam: the two of them straight into the street
		local impact = groundBelow(held, char)
		local victimEnd = impact + UP * 2.5
		local casterEnd = impact + UP * 3 - d * 2.5
		broadcast("TimberDive", char, { Target = target, From = over, Pos = impact, Time = DROP })
		t0 = os.clock()
		while os.clock() - t0 < DROP do
			if not valid() then
				return
			end
			local a = math.clamp((os.clock() - t0) / DROP, 0, 1)
			a *= a
			local vp = held:Lerp(victimEnd, a)
			Grab.place(g, CFrame.lookAt(vp, vp + d))
			root.CFrame = CFrame.lookAt(over:Lerp(casterEnd, a), vp)
			task.wait(1 / 60)
		end
		if not valid() then
			return
		end
		Grab.place(g, CFrame.lookAt(victimEnd, victimEnd + d))
		root.CFrame = CFrame.lookAt(casterEnd, casterEnd + d)
		broadcast("TimberSlam", char, { Target = target, Pos = impact, Big = big or nil })
		local hit = damage(player, target, ability.SlamDamage or 20, { Heavy = true, Hitstop = 0.1, From = over })
		Grab.release(g, UP * 30 + d * 12, 0.15)
		if hit then
			stun(target, 1)
			ragdoll(target, big and 1.6 or 1.3)
		end
		for _, other in queryRadius(char, impact, ability.Radius or 12) do
			if other ~= target and damage(player, other, ability.ShockDamage or 8, { From = impact }) then
				knockback(other, awayFrom(impact, other, d) * 45 + UP * 30, 0.16)
			end
		end
		Destruction.Sphere(impact + UP, big and 12 or 9, "Crater", UP)
		completed = true
	end, debug.traceback)
	-- every exit (a KO, an error, the target gone) lets both of them go
	Grab.release(g)
	if root.Parent then
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
		if not anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end
	if hum and hum.Parent then
		hum.AutoRotate = autoRotate
	end
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + 0.1)
	if not completed then
		broadcast("TimberCancel", char, { Target = target })
	end
	if not ok then
		warn("[TimberSlingshot] " .. tostring(err))
	end
end
Handlers.GreatSlingshot = Handlers.TimberSlingshot

-- ROOT BREAKER: his forearms plunge into the street and two roots weave
-- away down the aim, throwing up everyone along it as they pass
function Handlers.RootBreaker(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.2)
	if not alive(char) then
		return
	end
	local range, width = ability.Range or 42, ability.Width or 8
	local start = root.Position
	local hitSet = {}
	for i = 1, 6 do
		if not alive(char) then
			return
		end
		local center = start + d * range * (i - 0.5) / 6
		for _, model in queryBox(char, CFrame.lookAt(center, center + d), Vector3.new(width, 10, range / 6 + 2), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage or 13, { Hitstop = 0.06, From = start }) then
				knockback(model, UP * (ability.Launch or 55) + d * 12, 0.2, true)
				stun(model, 1)
			end
		end
		task.wait(0.06)
	end
	Destruction.Box(CFrame.lookAt(start + d * range / 2, start + d * range) * CFrame.new(0, -2.5, 0), Vector3.new(width * 0.6, 4, range), "Crater", UP)
end

-- GREAT TREE HAMMER: the trunk grows, then comes down on the street in front
function Handlers.TreeHammer(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.42)
	if not alive(char) then
		return
	end
	local range, width = ability.Range or 20, ability.Width or 10
	local center = root.Position + d * (range / 2 + 2)
	for _, model in queryBox(char, CFrame.lookAt(center, center + d), Vector3.new(width, 12, range)) do
		if damage(player, model, ability.Damage or 20, { Heavy = true, Hitstop = 0.1, From = root.Position }) then
			knockback(model, d * 30 + UP * 22, 0.18)
			stun(model, 1.1)
			ragdoll(model, 1.2)
		end
	end
	Destruction.Box(CFrame.lookAt(center, center + d) * CFrame.new(0, -3, 0), Vector3.new(width * 0.7, 5, range), "Crater", UP)
end

-- BRANCH SWING (R): his screen already found something tall enough and is
-- swinging him off it (everyone else saw the branch go out); here that's
-- checked, and if there's nothing there his swing is called off
function Handlers.BranchSwing(player, char, root, ability, _dir, pos, cast)
	if not Kit.swingAnchorOk(char, root, pos, ability.Range or 80, cast and cast.Origin) then
		PlayVFX:FireClient(player, "SwingDenied", char, {})
	end
end

-- THOUSAND-BRANCH PRISON (ult): branches out of the street all round him
-- cage everyone near, then crush
function Handlers.ThousandBranch(player, char, root, ability)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local center = root.Position
	local bind = ability.Bind or 1.8
	local caught = {}
	for _, model in queryRadius(char, center, ability.Radius or 28) do
		if damage(player, model, ability.Damage or 8, { From = center }) then
			stun(model, bind + 0.2, 0)
			table.insert(caught, model)
		end
	end
	broadcast("ThousandBranchCatch", char, { Targets = caught, Duration = bind, Center = center })
	task.wait(bind)
	for _, model in caught do
		if alive(model) and damage(player, model, ability.CrushDamage or 14, { Heavy = true, Hitstop = 0.08, From = center }) then
			knockback(model, awayFrom(center, model, UP) * 40 + UP * 45, 0.2)
			ragdoll(model, 1.2)
		end
	end
	broadcast("ThousandBranchCrush", char, { Targets = caught, Center = center })
end

-- TIMBER TORRENT (ult): a wave of logs rolls down the lane
function Handlers.TimberTorrent(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.25)
	local range, width = ability.Range or 80, ability.Width or 16
	local start = root.Position
	local hitSet = {}
	for i = 1, 8 do
		if not alive(char) then
			return
		end
		local center = start + d * range * (i - 0.5) / 8
		for _, model in queryBox(char, CFrame.lookAt(center, center + d), Vector3.new(width, 12, range / 8 + 3), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage or 18, { Heavy = true, Hitstop = 0.06, From = start }) then
				knockback(model, d * 70 + UP * 40, 0.25)
				stun(model, 1)
				ragdoll(model, 1.3)
			end
		end
		if i % 2 == 0 then
			Destruction.Sphere(center - UP * 2, 5, "Crater", d)
		end
		task.wait(0.07)
	end
end

-- SEQUOIA SPEAR (ult 4): a giant tree bursts out of the street under the aim
function Handlers.SequoiaSpear(player, char, root, ability, _dir, pos)
	local target = groundTarget(root, pos, ability.Range or 70, char)
	task.wait(0.45)
	if not alive(char) then
		return
	end
	for _, model in queryRadius(char, target + UP * 3, ability.Radius or 9) do
		if damage(player, model, ability.Damage or 28, { Heavy = true, Hitstop = 0.1, From = target }) then
			knockback(model, UP * (ability.Launch or 110), 0.3, true)
			stun(model, 1.4)
			ragdoll(model, 1.6)
		end
	end
	Destruction.Sphere(target, 10, "Crater", UP)
end

---------------------------------------------------------------------------
-- LIMITLESS (dev character)
---------------------------------------------------------------------------

function Handlers.Infinity(_player, char, _root, ability)
	local duration = ability.Duration or 4
	infinityUntil[char] = os.clock() + duration
	char:SetAttribute("Infinity", true)
	task.delay(duration, function()
		if char.Parent and not untouchable(char) then
			char:SetAttribute("Infinity", false)
		end
	end)
end

-- Blue: an attraction point. Pulls everyone (and the rubble) in, crushing
-- them together; each tick deals damage and caves in the map around it.
local function blueField(player, char, center, ability, crushRadius)
	local radius = ability.Radius or 24
	local duration = ability.Duration or 1.8
	local ticks = ability.Ticks or 6
	local every = duration / ticks
	local nextTick = 0
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		local now = os.clock() - t0
		local tick = now >= nextTick
		if tick then
			nextTick += every
		end
		for _, model in queryRadius(char, center, radius) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr then
				local v = center - mr.Position
				if v.Magnitude > 2.5 then
					knockback(model, v.Unit * math.clamp(v.Magnitude * 4, 20, 90), 0.12)
				end
				if tick and damage(player, model, ability.Damage) then
					stun(model, 0.5)
				end
			end
		end
		if tick then
			Destruction.Sphere(center, crushRadius, "Implode")
		end
		task.wait(0.1)
	end
end

function Handlers.LapseBlue(player, char, root, ability, _dir, pos)
	local center = groundTarget(root, pos, ability.Range or 70, char) + UP * 6
	task.wait(0.25)
	if alive(char) then
		blueField(player, char, center, ability, 10)
	end
end

function Handlers.BlueMax(player, char, root, ability, _dir, pos)
	local center = groundTarget(root, pos, ability.Range or 80, char) + UP * 10
	task.wait(0.35)
	if alive(char) then
		blueField(player, char, center, ability, 17)
	end
end

-- Red: a repulsion point flicked off the fingertip; bursts on the first
-- person or wall it meets (or at full range)
local function redShot(player, char, root, ability, dir, windup, speed, crater)
	task.wait(windup)
	if not alive(char) then
		return
	end
	local origin = root.Position + UP * 1.5 + dir * 2
	local length = ability.Range or 80
	local _, dist = firstInLine(char, origin, dir, length, 5)
	local reach = math.min(dist or length, wallDistance(char, origin, dir, length))
	task.wait(reach / speed)
	local center = origin + dir * reach
	broadcast("RedBurst", char, { Pos = center, Radius = ability.Radius })
	local radius = ability.Radius or 20
	for _, model in queryRadius(char, center, radius) do
		if damage(player, model, ability.Damage, { Heavy = true, Hitstop = 0.08, From = center }) then
			knockback(model, awayFrom(center, model, dir) * 170 + UP * 50, 0.3)
			stun(model, 1.2)
		end
	end
	Destruction.Sphere(center, crater, "Crater")
end

function Handlers.ReversalRed(player, char, root, ability, dir)
	redShot(player, char, root, ability, dir, 0.3, 260, (ability.Radius or 20) * 0.6)
end

function Handlers.RedMax(player, char, root, ability, dir)
	redShot(player, char, root, ability, dir, 0.45, 220, (ability.Radius or 32) * 0.65)
end

-- Hollow Purple: imaginary mass. Rolls down a straight line erasing
-- everything it touches (it doesn't stop for walls - that's the point).
local function purple(player, char, root, ability, dir, windup, speed)
	local d = flatten(dir, root)
	task.wait(windup)
	if not alive(char) then
		return
	end
	local origin = root.Position + UP * 2 + d * 3
	local length = ability.Range or 220
	local radius = ability.Radius or 10
	local hitSet = {}
	local traveled = 0
	while traveled < length do
		local step = math.min(speed * 0.1, length - traveled)
		local a, b = origin + d * traveled, origin + d * (traveled + step)
		local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -step / 2)
		for _, model in queryBox(char, cf, Vector3.new(radius * 2 + 4, radius * 2 + 4, step + 2), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage, { Heavy = true, Hitstop = 0.1, From = a }) then
				knockback(model, d * 120 + UP * 40, 0.3)
				stun(model, 1.5)
				ragdoll(model, 1.5)
			end
		end
		Destruction.Capsule(a, b, radius, "Erase", d)
		traveled += step
		task.wait(0.1)
	end
end

function Handlers.HollowPurple(player, char, root, ability, dir)
	purple(player, char, root, ability, dir, 1.25, 170)
end

function Handlers.PurpleMax(player, char, root, ability, dir)
	purple(player, char, root, ability, dir, 1.7, 210)
end

---------------------------------------------------------------------------
-- PLUS ULTRA (the dev kit)
---------------------------------------------------------------------------

-- 1,000,000% Delaware Detroit Smash: after the charge, a wall of wind
-- pressure rolls down the street, fanning out as it goes
-- ONE FOR ALL AT 100% breaks the arm that throws it: it goes purple
-- (BrokenArmR / BrokenArmL on the character: the server time it heals at;
-- every client dresses the arm in the bruise). Healed on a new body or
-- another quirk.
function Kit.breakArm(char, side, time)
	if Kit.LIMP then
		Kit.LIMP.watch(char)
	end
	local now = workspace:GetServerTimeNow()
	char:SetAttribute("BrokenArm" .. side, math.max(tonumber(char:GetAttribute("BrokenArm" .. side)) or 0, now + (time or 30)))
end

-- 100%: DETROIT SMASH - One For All at 100% through one arm, the way he had
-- to use it before Full Cowl: the street in front of him is blown away.
-- (Round 75: the arm holds now - no break, no recoil.)
function Handlers.HundredSmash(player, char, root, ability, dir)
	local d = flatten(dir, root)
	local now = workspace:GetServerTimeNow()
	local rBroken = (tonumber(char:GetAttribute("BrokenArmR")) or 0) > now
	local lBroken = (tonumber(char:GetAttribute("BrokenArmL")) or 0) > now
	local side = (not rBroken or lBroken) and "R" or "L"
	task.wait(ability.Startup or 0.55)
	if not alive(char) then
		return
	end
	local live = Kit.liveAim[player]
	if live and os.clock() - live.Time < 0.5 then
		d = flatten(live.Dir, root) -- (still aimable through the wind-up)
	end
	local length, width = ability.Range or 100, ability.Width or 26
	local look = CFrame.lookAt(root.Position, root.Position + d)
	broadcast("HundredSmashBlast", char, { Dir = d, Side = side, Range = length, Width = width })
	for _, model in queryBox(char, look * CFrame.new(0, 4, -length / 2), Vector3.new(width, 28, length)) do
		if damage(player, model, ability.Damage or 44, { Heavy = true, Hitstop = 0.1, From = root.Position }) then
			knockback(model, d * 150 + UP * 50, 0.3)
			ragdoll(model, 2)
		end
	end
	Destruction.Box(look * CFrame.new(0, 8, -length * 0.55), Vector3.new(width * 0.9, 30, length * 0.9), "Wind", d)
	-- (round 75) no price any more: the arm holds, no recoil
end

function Handlers.MillionSmash(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(ability.Charge or 1.45) -- the charge: "GO... BEYOND..." - All Might there behind him
	if not alive(char) then
		return
	end
	local origin = root.Position
	local range, width = ability.Range or 230, ability.Width or 60
	local look = CFrame.lookAt(origin, origin + d)
	local hitSet = {}
	local segments = 6
	for i = 1, segments do
		local a, b = (i - 1) / segments * range, i / segments * range
		local mid = (a + b) / 2
		local w = width * (0.55 + 0.45 * i / segments)
		for _, model in queryBox(char, look * CFrame.new(0, 10, -mid), Vector3.new(w, 60, b - a + 6), hitSet) do
			hitSet[model] = true
			if damage(player, model, ability.Damage, { Heavy = true, From = origin }) then
				knockback(model, d * 260 + UP * 90, 0.35)
				stun(model, 2)
			end
		end
		Destruction.Box(look * CFrame.new(0, 12, -mid), Vector3.new(w * 0.8, 44, b - a + 4), "Wind", d)
		task.wait(0.05)
	end
	Kit.breakArm(char, "R", 30) -- (1,000,000%: the arm's in pieces - it goes purple)
end

-- Endeavor's Prominence Burn: he goes supernova where he stands
function Handlers.ProminenceBurn(player, char, root, ability)
	task.wait(0.7) -- the heat builds
	if not alive(char) then
		return
	end
	local center = root.Position
	local radius = ability.Radius or 36
	for _, model in queryRadius(char, center, radius) do
		if damage(player, model, ability.Damage, { Heavy = true, From = center }) then
			burn(model, ability.BurnTicks, ability.BurnDamage)
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 130 + UP * 70, 0.28)
			stun(model, 1.2)
		end
	end
	Destruction.Sphere(center, radius * 0.55, "Fire")
	Destruction.Cylinder(center + UP * 30, radius * 0.3, 60, "Fire", UP)
end

-- Kurogiri's Warp Gate: into the mist here, out of it at the aim point.
-- Whoever is standing where it opens is swallowed and spat out.
function Handlers.WarpGate(player, char, root, ability, dir, pos)
	local target = groundTarget(root, pos, ability.Range or 250, char)
	task.wait(0.35)
	if not alive(char) then
		return
	end
	local look = flatten(dir, root)
	local dest = target + UP * 3.2
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.3)
	char:PivotTo(CFrame.lookAt(dest, dest + look))
	for _, model in queryRadius(char, target, ability.Radius or 12) do
		if damage(player, model, ability.Damage, { From = target }) then
			knockback(model, awayFrom(target, model, look) * 40 + UP * 70, 0.25)
			stun(model, 1.2)
		end
	end
end

-- Eri's Rewind: back to full health, every other cooldown ready, ult charge
function Handlers.Rewind(player, char, _root, ability)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
	end
	local keep = Config.CooldownKey(player:GetAttribute("Quirk"), Config.SPECIAL_INDEX)
	local mine = cooldowns[player] or {}
	cooldowns[player] = { [keep] = mine[keep] }
	addUlt(player, ability.UltGain or 50)
	PlayVFX:FireClient(player, "CooldownReset", nil, { Keep = keep })
end

-- Star and Stripe's New Order: "everyone around me floats"... then they don't
function Handlers.NewOrder(player, char, root, ability)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local center = root.Position
	local floatTime = ability.FloatTime or 2.6
	local caught = {}
	for _, model in queryRadius(char, center, ability.Radius or 100) do
		if not untouchable(model) and #caught < 12 then
			table.insert(caught, model)
			stun(model, floatTime + 0.8)
			knockback(model, UP * 24, floatTime)
		end
	end
	broadcast("NewOrderFloat", char, { Targets = caught, Time = floatTime })
	task.wait(floatTime + 0.05)
	for _, model in caught do
		local mr = model:FindFirstChild("HumanoidRootPart")
		if mr and damage(player, model, ability.Damage, { Heavy = true }) then
			knockback(model, -UP * 190, 0.4)
			task.delay(0.35, function()
				Destruction.Sphere(groundBelow(mr.Position, char), 7, "Crater")
			end)
		end
	end
	broadcast("NewOrderSlam", char, { Targets = caught })
end

---------------------------------------------------------------------------
-- LEMILLION (Mirio Togata): Permeation
---------------------------------------------------------------------------
-- While he's "under the street" (Submerged) he's hidden, anchored and can't
-- be touched; every client draws him sinking and bursting back out.
do
	local SINK = 0.3 -- seconds to drop through the street
	local subTokens = setmetatable({}, { __mode = "k" })
	local phaseTokens = setmetatable({}, { __mode = "k" })
	local predictionUntil = setmetatable({}, { __mode = "k" })

	local function emerge(char, root, cf)
		subTokens[char] = (subTokens[char] or 0) + 1
		if cf then
			char:PivotTo(cf)
		end
		if not char:GetAttribute("Frozen") then
			root.Anchored = false
		end
		char:SetAttribute("Submerged", false)
	end

	local function submerge(char, root, seconds)
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + seconds + 0.2)
		char:SetAttribute("Submerged", true)
		root.Anchored = true
		local token = (subTokens[char] or 0) + 1
		subTokens[char] = token
		-- never left stuck under the street
		task.delay(seconds + 1.5, function()
			if subTokens[char] == token and char.Parent and char:GetAttribute("Submerged") then
				emerge(char, root, nil)
			end
		end)
	end

	-- is there street (or a roof) under this spot? (never pop out over the
	-- void past the edge of the map, or under the street)
	local function hasGround(char, at)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		return workspace:Raycast(at + UP * 2, Vector3.new(0, -120, 0), params) ~= nil
	end

	-- the flat way a body faces
	local function facing(r)
		local l = r.CFrame.LookVector
		local f = Vector3.new(l.X, 0, l.Z)
		return f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, -1)
	end

	-- the first person ahead, else whoever is closest in front of him
	local function lockTarget(char, root, d, range)
		local target = firstInLine(char, root.Position, d, range, 8)
		if target then
			return target
		end
		local best, bestDist
		for _, model in queryRadius(char, root.Position + d * range * 0.5, range * 0.55) do
			local r = model:FindFirstChild("HumanoidRootPart")
			local v = r and (r.Position - root.Position)
			if v and v:Dot(d) > 0 and (not bestDist or v.Magnitude < bestDist) then
				best, bestDist = model, v.Magnitude
			end
		end
		return best
	end

	function Handlers.DeepDive(player, char, root, ability, dir, pos)
		local look = flatten(dir, root)
		local target = groundTarget(root, pos, ability.Range or 55, char)
		-- aimed past the edge of the map: he comes up at the last bit of street
		-- on the way there (or where he went down)
		if not hasGround(char, target) then
			local start = root.Position
			target = groundBelow(start, char)
			for k = 9, 1, -1 do
				local try = groundTarget(root, start + (Vector3.new(pos.X, start.Y, pos.Z) - start) * (k / 10), ability.Range or 55, char)
				if hasGround(char, try) then
					target = try
					break
				end
			end
		end
		if Kit.SC then
			target = Kit.SC.keepIn(root.Position, target)
		end
		local travel = 0.12 + (target - root.Position).Magnitude / 260
		submerge(char, root, SINK + travel)
		task.wait(SINK + travel)
		if not char.Parent then
			return
		end
		local dest = target + UP * 3.2
		emerge(char, root, CFrame.lookAt(dest, dest + look))
		for _, model in queryRadius(char, target + UP * 2, ability.Radius or 9) do
			if damage(player, model, ability.Damage, { From = target, Heavy = true, Hitstop = 0.08 }) then
				stun(model, 1.1)
				knockback(model, awayFrom(target, model, look) * 18 + UP * 85, 0.25)
			end
		end
	end

	-- Phantom Menace: straight through them, then blind spot after blind spot.
	-- spots: { Angle = degrees round the target (0 = in front, 180 = behind),
	-- Height = studs above them }
	local MENACE_SPOTS = {
		{ Angle = 180, Height = 0 },
		{ Angle = 95, Height = 0 },
		{ Angle = 200, Height = 4.5 },
	}
	local RUSH_SPOTS = {
		{ Angle = 180, Height = 0 }, { Angle = 60, Height = 0 }, { Angle = 300, Height = 0 }, { Angle = 125, Height = 3 },
		{ Angle = 235, Height = 0 }, { Angle = 10, Height = 0 }, { Angle = 150, Height = 5 }, { Angle = 180, Height = -1 },
	}
	local function blindSpots(player, char, root, ability, dir, spots)
		local d = flatten(dir, root)
		local target = lockTarget(char, root, d, ability.Range or 40)
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		if not troot then
			-- nobody there: he phases straight ahead instead
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.4)
			broadcast("PhantomMiss", char, { Dir = d })
			return
		end
		local count = math.min(ability.Hits or #spots, #spots)
		stun(target, 0.3 * count + 0.8) -- they can't turn fast enough to follow him
		submerge(char, root, 0.18)
		task.wait(0.18)
		for i = 1, count do
			if not alive(char) or not alive(target) or not troot.Parent then
				break
			end
			local spot = spots[i]
			local last = i == count
			local front = facing(troot)
			local around = (CFrame.Angles(0, math.rad(spot.Angle), 0) * front).Unit
			local at = troot.Position + around * 3.4 + UP * spot.Height
			if not hasGround(char, at) then
				break -- (they've been knocked off the map: he doesn't follow)
			end
			local lookAt = spot.Height > 1 and troot.Position or Vector3.new(troot.Position.X, at.Y, troot.Position.Z)
			emerge(char, root, CFrame.lookAt(at, lookAt))
			root.Anchored = true -- he hangs where he struck from until the next one
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.3)
			broadcast("PhantomStrike", char, { Target = target, At = at, Index = i, Last = last })
			local dmg = last and (ability.FinisherDamage or ability.Damage) or ability.Damage
			local push = Vector3.new(troot.Position.X - at.X, 0, troot.Position.Z - at.Z)
			push = push.Magnitude > 0.1 and push.Unit or front
			if damage(player, target, dmg, { From = at, Hitstop = last and 0.1 or 0.04, Heavy = last }) then
				if last and #spots > 3 then
					-- the rush ends with them launched skyward
					stun(target, 1.4)
					knockback(target, push * 20 + UP * 120, 0.2)
				elseif last then
					-- the axe kick from above: face-first into the street
					stun(target, 1.3)
					ragdoll(target, 1.1)
					knockback(target, push * 34 - UP * 30, 0.18)
				else
					knockback(target, push * 6, 0.06)
				end
			end
			task.wait(last and 0.12 or (#spots > 3 and 0.14 or 0.22))
		end
		if char.Parent then
			emerge(char, root, nil) -- (lets go: from up high he drops)
		end
	end

	function Handlers.PhantomMenace(player, char, root, ability, dir)
		blindSpots(player, char, root, ability, dir, MENACE_SPOTS)
	end

	function Handlers.PhantomRush(player, char, root, ability, dir)
		blindSpots(player, char, root, ability, dir, RUSH_SPOTS)
	end

	-- Prediction: the stance. The first hit that lands on him passes straight
	-- through, and he comes up out of the street behind whoever threw it.
	function Handlers.Prediction(_player, char, _root, ability)
		local duration = ability.Duration or 1
		predictionUntil[char] = os.clock() + duration
		char:SetAttribute("Countering", true)
		slow(char, duration, 5)
		task.delay(duration, function()
			if char.Parent and (predictionUntil[char] or 0) <= os.clock() then
				predictionUntil[char] = nil
				char:SetAttribute("Countering", false)
			end
		end)
	end

	local function counterStrike(char, attackerChar)
		local player = Players:GetPlayerFromCharacter(char)
		local root = char:FindFirstChild("HumanoidRootPart")
		local ability = Config.FindAbilityById("Prediction") or {}
		if not root then
			return
		end
		broadcast("PredictionTrigger", char, { Attacker = attackerChar })
		submerge(char, root, 0.32)
		task.wait(0.32)
		if not char.Parent then
			return
		end
		local aroot = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart")
		if not alive(char) or not aroot or not alive(attackerChar) or (aroot.Position - root.Position).Magnitude > (ability.Range or 60) then
			emerge(char, root, nil)
			return
		end
		local back = facing(aroot)
		local at = aroot.Position - back * 3.2
		emerge(char, root, CFrame.lookAt(at, at + back))
		broadcast("PredictionStrike", char, { Target = attackerChar, At = at })
		if damage(player, attackerChar, ability.Damage or 24, { From = at, Heavy = true, Hitstop = 0.14, GuardDamage = 40 }) then
			stun(attackerChar, 1.6)
			ragdoll(attackerChar, 1.2)
			knockback(attackerChar, back * 75 + UP * 35, 0.22)
		end
	end

	-- the lowest surface under a spot: the street, under any roofs and
	-- floors (each ray starts just inside the surface above: it skips it)
	local function streetUnder(char, at)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local from, last = at + UP * 2, nil
		for _ = 1, 16 do
			local hit = workspace:Raycast(from, Vector3.new(0, -600, 0), params)
			if not hit then
				break
			end
			last = hit.Position
			if hit.Instance and hit.Instance:GetAttribute("SkyFloor") then
				break -- (the Sky Coffin's ground: the "street" up there, not the city's below)
			end
			from = hit.Position - UP * 0.05
		end
		return last
	end

	-- the top surface at a spot (a roof, else the street)
	local function topAt(char, xz, fromY)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local hit = workspace:Raycast(Vector3.new(xz.X, fromY, xz.Z), Vector3.new(0, -800, 0), params)
		return hit and hit.Position or nil
	end

	-- the ground spitting him out: a clean launch on his own body (a hit's
	-- knockback would ragdoll anything that fast)
	local function spitOut(root, velocity)
		for _, d in root:GetChildren() do
			if d.Name == "PhaseLaunch" or d.Name == "PhaseLaunchAttachment" then
				d:Destroy()
			end
		end
		local att = Instance.new("Attachment")
		att.Name = "PhaseLaunchAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "PhaseLaunch"
		lv.Attachment0 = att
		local okMass, mass = pcall(function()
			return root.AssemblyMass
		end)
		lv.MaxForce = ((okMass and type(mass) == "number" and mass > 0) and mass or 10) * 12000
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = velocity
		lv.Parent = root
		Debris:AddItem(lv, 0.22)
		Debris:AddItem(att, 0.22)
	end

	local function endPhase(char)
		phaseTokens[char] = (phaseTokens[char] or 0) + 1
		char:SetAttribute("Phasing", false)
		char:SetAttribute("WallPhase", false)
	end

	-- R in the air: PHASE DIVE. He lets everything go and drops through it all
	-- (his machine puts his body in the PhaseDive collision group while
	-- PhaseDive is set); once he's under the street he's held there, hidden,
	-- while he steers his way (the marker on his screen - the release carries
	-- where it is); then the ground spits him out at it.
	local function phaseDive(player, char, root, ability)
		local start = root.Position
		local street = streetUnder(char, start)
		if not street then
			return -- (over nothing: it doesn't go)
		end
		local token = (phaseTokens[char] or 0) + 1
		phaseTokens[char] = token
		char:SetAttribute("Phasing", true)
		char:SetAttribute("PhaseDive", true)
		local choose = ability.ChooseTime or 2.5
		-- the drop (his machine drives it at DiveSpeed)
		local fall = math.clamp((start.Y - street.Y) / (ability.DiveSpeed or 110) + 0.8, 0.5, 4)
		local t0 = os.clock()
		while alive(char) and char:GetAttribute("PhaseDive") and root.Position.Y > street.Y - 3 and os.clock() - t0 < fall do
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.5)
			task.wait()
		end
		if not alive(char) or phaseTokens[char] ~= token then
			char:SetAttribute("PhaseDive", false)
			return
		end
		-- under the street: held there, hidden, while he picks where to come out
		local under = Vector3.new(root.Position.X, street.Y - 6, root.Position.Z)
		root.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(CFrame.new(under) * root.CFrame.Rotation)
		submerge(char, root, choose + 1)
		local hold = { Released = false, Start = os.clock() }
		HoldMoves.active[player] = hold
		while alive(char) and not hold.Released and os.clock() - hold.Start < choose + 0.4 do
			task.wait()
		end
		if HoldMoves.active[player] == hold then
			HoldMoves.active[player] = nil
		end
		if not char.Parent then
			return
		end
		-- where: within DiveRange of where he went under, on something solid
		local aim = typeof(hold.Aim) == "Vector3" and hold.Aim or under
		local flat = Vector3.new(aim.X - under.X, 0, aim.Z - under.Z)
		local range = ability.DiveRange or 80
		if flat.Magnitude > range then
			flat = flat.Unit * range
		end
		local spot = under + flat
		if Kit.SC then
			spot = Kit.SC.keepIn(start, spot)
			flat = Vector3.new(spot.X - under.X, 0, spot.Z - under.Z)
		end
		local exit = topAt(char, spot, math.max(start.Y, street.Y) + 250)
		if not exit or not hasGround(char, exit) then
			flat = Vector3.zero
			exit = street -- (nothing there: straight back up where he went in)
		end
		local look = flat.Magnitude > 1 and flat.Unit or facing(root)
		local out = exit + UP * 3.2
		emerge(char, root, CFrame.lookAt(out, out + look))
		char:SetAttribute("PhaseDive", false)
		endPhase(char)
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.5)
		broadcast("PermeateSpit", char, { Pos = exit, Dir = look })
		-- the ground spits him out
		spitOut(root, UP * (ability.Launch or 105) + look * 14)
		for _, model in queryRadius(char, exit + UP * 2, ability.SpitRadius or 9) do
			if damage(player, model, ability.SpitDamage or 8, { From = exit, Hitstop = 0.05 }) then
				knockback(model, awayFrom(exit, model, look) * 70 + UP * 45, 0.2)
				stun(model, 0.7)
			end
		end
	end

	-- R: PERMEATE. On the ground: WALL PHASE - for Duration he goes straight
	-- through walls, never the floor (his own machine lets the walls near him
	-- through while WallPhase is set), and nothing lands on him; attacking
	-- lets the world back in. In the air: the PHASE DIVE above.
	function Handlers.Permeate(player, char, root, ability, _dir, _pos, cast)
		if cast and cast.Air then
			phaseDive(player, char, root, ability)
			return
		end
		local t = ability.Duration or 3
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + t)
		char:SetAttribute("Phasing", true)
		char:SetAttribute("WallPhase", true)
		local token = (phaseTokens[char] or 0) + 1
		phaseTokens[char] = token
		task.delay(t, function()
			if phaseTokens[char] == token and char.Parent then
				char:SetAttribute("Phasing", false)
				char:SetAttribute("WallPhase", false)
			end
		end)
	end

	-- The ult's finisher: up out of the street under them, then out of thin
	-- air above them, and down they go
	function Handlers.MillionPunch(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = lockTarget(char, root, d, ability.Range or 60)
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		local spot = troot and troot.Position or groundTarget(root, pos, ability.Range or 60, char)
		if target then
			stun(target, 2.6)
		end
		submerge(char, root, 0.55)
		task.wait(0.55)
		if not char.Parent then
			return
		end
		local g = groundBelow(troot and troot.Position or spot, char)
		local up = g + UP * 3.2
		emerge(char, root, CFrame.lookAt(up, up + d))
		broadcast("MillionPunchRise", char, { Pos = g, Target = target })
		local launched = {}
		for _, model in queryRadius(char, g + UP * 2, target and 7 or (ability.Radius or 16)) do
			if damage(player, model, ability.LaunchDamage or 20, { From = g, Heavy = true, Hitstop = 0.1 }) then
				stun(model, 2)
				knockback(model, UP * 110 + awayFrom(g, model, d) * 6, 0.18)
				table.insert(launched, model)
			end
		end
		if not target or not table.find(launched, target) then
			return
		end
		task.wait(0.5)
		if not alive(char) or not troot.Parent then
			return
		end
		-- out of thin air, right above them
		local above = troot.Position + UP * 5 - d * 1.5
		if not hasGround(char, above) then
			emerge(char, root, nil)
			return
		end
		emerge(char, root, CFrame.lookAt(above, troot.Position))
		root.Anchored = true
		broadcast("MillionPunchDrop", char, { Target = target, At = above })
		if damage(player, target, ability.Damage, { From = above, Heavy = true, Hitstop = 0.16 }) then
			stun(target, 2)
			ragdoll(target, 1.8)
			knockback(target, -UP * 190, 0.3)
			task.delay(0.3, function()
				local r = target:FindFirstChild("HumanoidRootPart")
				local ground = groundBelow((r or troot).Position, char)
				Destruction.Sphere(ground, 9, "Impact", -UP)
				broadcast("MillionPunchImpact", nil, { Pos = ground })
			end)
		end
		task.wait(0.25)
		if char.Parent then
			emerge(char, root, nil)
		end
	end

	-- damage() asks first: does this hit pass straight through him?
	Permeation.Pass = function(attacker, model, opts)
		if (predictionUntil[model] or 0) > os.clock() then
			local attackerChar = (attacker and attacker.Character) or (opts and opts.AttackerModel)
			if attackerChar and attackerChar ~= model then
				predictionUntil[model] = nil
				model:SetAttribute("Countering", false)
				iFrames[model] = math.max(iFrames[model] or 0, os.clock() + 0.5)
				task.spawn(counterStrike, model, attackerChar)
				return true
			end
		end
		local victim = Players:GetPlayerFromCharacter(model)
		if victim and victim:GetAttribute("UltActive") and victim:GetAttribute("Quirk") == "Lemillion" then
			local quirk = Config.Quirks.Lemillion
			if math.random() < ((quirk and quirk.Ult and quirk.Ult.PhaseChance) or 0) then
				broadcast("Dodge", nil, { Target = model, Phase = true })
				return true
			end
		end
		return false
	end

	-- attacking lets the world back in
	Permeation.OnAttack = function(char)
		if char:GetAttribute("Phasing") and not char:GetAttribute("PhaseDive") then
			endPhase(char)
			iFrames[char] = os.clock()
		end
	end
end

---------------------------------------------------------------------------
-- SUNEATER (Tamaki Amajiki): Manifest
---------------------------------------------------------------------------

-- The stomach: every manifestation eats into it (ability.Cost) and the
-- fuller it is, the harder they hit (Stomach.Empty x .. Stomach.Full x).
-- In his Vast Hybrid Chimera ult everything is full size and free.
Kit.stomach = {}
function Kit.stomach.use(player, char, ability)
	local spec = Config.Quirks.Manifest.Stomach or {}
	local empty, full, max = spec.Empty or 0.8, spec.Full or 1.1, spec.Max or 100
	if player:GetAttribute("UltActive") then
		return full
	end
	local now = tonumber(char:GetAttribute("Stomach")) or max
	char:SetAttribute("Stomach", math.max(0, now - (ability.Cost or 0)))
	return empty + (full - empty) * math.clamp(now / max, 0, 1)
end

-- Scorpius Toxin's venom: PoisonDamage every half second, Ticks times
function Kit.poison(model, ticks, perTick)
	broadcast("Poisoned", nil, { Target = model, Duration = ticks * 0.5 })
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				return
			end
			local victim = Players:GetPlayerFromCharacter(model)
			if not (victim and victim:GetAttribute("GodMode")) then
				hum:TakeDamage(perTick)
			end
		end
	end)
end

-- (round 59) BAMBOO SWEEP (1 in the air): a stalk of bamboo grows out of his
-- arm and sweeps round him - from his left round to his right, tilted down
-- at the street, growing as it goes (biggest at the end of the swing) - then
-- swings back to where it started, shrinking, and goes back into his arm
-- (Config.BambooAt: every screen draws the same stalk). Whoever it passes
-- through is hit once on the way out and once on the way back.
-- (round 72) Down on the street: it points down till its tip drags along
-- the ground (Config.BambooAim), and lies there a moment before going back.
function Kit.bambooSweep(player, char, root, spec, power, d)
	task.wait(spec.WindUp or 0.12)
	local right = d:Cross(UP)
	local struck = { [1] = {}, [-1] = {} }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = nonMapStuff(char)
	local function floorY(p)
		local hit = workspace:Raycast(p + UP * 3, UP * -90, params)
		return hit and hit.Position.Y
	end
	local t0 = os.clock()
	while alive(char) do
		local ang, len, thick, way = Config.BambooAt(spec, os.clock() - t0)
		if not ang then
			break
		end
		local a = math.rad(ang)
		local flat = d * math.cos(a) + right * math.sin(a)
		local from = root.Position + UP * 0.8
		local dir
		dir, len = Config.BambooAim(spec, from, flat, len, floorY)
		local reach = (spec.Width or 2.5) + thick / 2
		for _, model in queryRadius(char, from + dir * (len / 2), len / 2 + reach + 2) do
			local set = struck[way]
			local mr = model:FindFirstChild("HumanoidRootPart")
			if not set[model] and mr then
				local v = mr.Position - from
				local along = math.clamp(v:Dot(dir), 0, len)
				if (v - dir * along).Magnitude <= reach + 1.5 then
					set[model] = true
					local amount = (way == 1 and (spec.Damage or 12) or (spec.ReturnDamage or 8)) * power
					if damage(player, model, amount, { Heavy = way == 1 or nil, Hitstop = 0.05, From = from }) then
						-- swept along with the stalk, and off the end of it
						local tangent = (right * math.cos(a) - d * math.sin(a)) * way
						knockback(model, tangent * 55 + flat * 18 + UP * 16, 0.18)
						stun(model, 0.8)
					end
				end
			end
		end
		task.wait(1 / 30)
	end
end

-- CHICKEN KICK: a chicken leg kicks straight up - whoever's in front is
-- launched and held up there for a follow-up (Tako Snatch, the Clam Hammer).
-- In the air: the BAMBOO SWEEP (round 59)
function Handlers.ChickenKick(player, char, root, ability, dir, _pos, cast)
	local power = Kit.stomach.use(player, char, ability)
	local d = flatten(dir, root)
	if cast and cast.Air then
		Kit.bambooSweep(player, char, root, ability.Air or {}, power, d)
		return
	end
	task.wait(0.16)
	if not alive(char) then
		return
	end
	local range = ability.Range or 8
	local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 1, -range / 2)
	for _, model in Rewind.QueryBox(player, char, cf, Vector3.new(8, 11, range + 2)) do
		if damage(player, model, (ability.Damage or 10) * power, { Hitstop = 0.08, From = root.Position }) then
			-- (under the ragdoll speed: they fly up still able to be caught; a
			-- launcher keeps its full height - it's the combo)
			knockback(model, UP * (ability.Launch or 92) + d * 6, 0.22, true)
			stun(model, ability.Stun or 1.3)
		end
	end
	Destruction.Sphere(groundBelow(root.Position + d * 2, char), 3, "Crater")
end

-- who the Tako Snatch arm goes for: along the aim (within AimAssist
-- degrees), nothing solid in between, and anyone up in the air first
function Kit.snatchTarget(char, origin, aim, range, assist)
	local cosA = math.cos(math.rad(assist or 22))
	local best, bestScore
	for _, model in queryRadius(char, origin, range) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		local v = mr and mr.Position - origin
		local dist = v and v.Magnitude or 0
		if v and dist > 0.5 and dist <= range and v.Unit:Dot(aim) >= cosA
			and wallDistance(char, origin, v.Unit, dist) >= dist - 1.5 then
			local airborne = not isGrounded(mr, model, 4)
			local score = dist - (airborne and 15 or 0) - v.Unit:Dot(aim) * 8
			if not bestScore or score < bestScore then
				best, bestScore = model, score
			end
		end
	end
	return best
end

-- TAKO SNATCH: an octopus arm shoots out along the aim, catches the first
-- one it reaches and swings them over into the street in front of him -
-- harder if it plucked them out of the air
function Handlers.TakoSnatch(player, char, root, ability, dir)
	local power = Kit.stomach.use(player, char, ability)
	local d = flatten(dir, root)
	local aim = Config.AimedDirection(dir, d, { Up = 75, Down = 30 })
	task.wait(0.12)
	if not alive(char) then
		return
	end
	local range = ability.Range or 45
	local origin = root.Position + UP * 1.5
	local target = Kit.snatchTarget(char, origin, aim, range, ability.AimAssist)
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local midair = tr ~= nil and not isGrounded(tr, target, 4)
	local reach = tr and (tr.Position - origin).Magnitude or wallDistance(char, origin, aim, range)
	task.wait(math.min(reach / 160, 0.28)) -- (the arm's flight)
	local bonus = midair and (ability.AirBonus or 1.4) or 1
	local g = target and alive(char) and damage(player, target, (ability.Damage or 6) * power * bonus, { Hitstop = 0.05, From = root.Position })
		and alive(target) and Grab.take(target, 0.9)
	-- (round 60) nobody in reach, but it struck a building: THE ZIP - it
	-- latches on and reels him in (his own screen moves him; everyone sees
	-- the tentacle). A zip costs only Zip.Cooldown of the move's cooldown.
	local zip = nil
	if not target and alive(char) then
		zip = Kit.zipPoint(char, root, aim, ability.Zip or {})
		if zip then
			-- (the tentacle flies to where it caught)
			aim = (zip.Anchor - origin).Unit
			reach = (zip.Anchor - origin).Magnitude
		end
	end
	broadcast("TakoSnatchCatch", char, { Target = g and target or nil, Dir = aim, Reach = reach, Air = (g and midair) or nil, Swing = zip and zip.Anchor or nil })
	if zip then
		broadcast("TakoZip", char, { Anchor = zip.Anchor, Normal = zip.Normal, Ledge = zip.Ledge or nil })
		Kit.zipCooldown(player, ability)
	end
	if not g then
		return
	end
	local from = g.Root.Position
	local slam = groundBelow(root.Position + d * 6, char) + UP * 2.5
	local apex = (from + slam) / 2 + UP * 8
	local t0 = os.clock()
	while os.clock() - t0 < 0.32 and alive(char) and g.Root.Parent do
		local k = (os.clock() - t0) / 0.32
		k *= k
		local p = from:Lerp(apex, k):Lerp(apex:Lerp(slam, k), k)
		Grab.place(g, CFrame.lookAt(p, root.Position))
		task.wait(1 / 60)
	end
	if not (alive(char) and g.Root.Parent) then
		Grab.release(g)
		return
	end
	Grab.place(g, CFrame.lookAt(slam, slam + d))
	Grab.release(g, UP * 18 + d * 8, 0.12)
	if damage(player, target, (ability.SlamDamage or 10) * power * bonus, { Heavy = true, Hitstop = 0.09, From = root.Position }) then
		stun(target, 1)
		ragdoll(target, 1.1)
	end
	broadcast("TentacleSlam", char, { Pos = slam - UP * 2.5, Big = midair or nil })
	Destruction.Sphere(slam - UP * 2, 4.5, "Crater")
end

-- TAKO THRASH: a huge tentacle grabs the one in front and slams them into
-- the street to his right, his left, and his right again - then lets them
-- fly off the last one
function Handlers.TakoThrash(player, char, root, ability, dir, _pos, cast)
	local power = Kit.stomach.use(player, char, ability)
	local d = flatten(dir, root)
	if cast and cast.Air then
		-- (round 59) URCHIN SPIKES: in the air, sea urchin spines burst out of
		-- every inch of him - everyone round him is run through and knocked
		-- away - then they pull back in
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local center = root.Position
		for _, model in queryRadius(char, center, ability.UrchinRadius or 11) do
			if damage(player, model, (ability.UrchinDamage or 14) * power, { Heavy = true, Hitstop = 0.08, From = center }) then
				knockback(model, awayFrom(center, model, d) * 55 + UP * 22, 0.2)
				stun(model, 0.9)
			end
		end
		return
	end
	task.wait(0.18)
	if not alive(char) then
		return
	end
	local target = Grab.nearest(char, root, d, ability.Range or 16, 0.45)
	local g = target and damage(player, target, (ability.Damage or 4) * power, { Hitstop = 0.05, From = root.Position })
		and alive(target) and Grab.take(target, 1.5)
	broadcast("TakoThrashCatch", char, { Target = g and target or nil, Dir = d })
	if not g then
		return
	end
	local right = d:Cross(UP)
	local sides = { 1, -1, 1 }
	for i, side in sides do
		if not (alive(char) and alive(target) and g.Root.Parent) then
			break
		end
		local from = g.Root.Position
		local land = groundBelow(root.Position + right * side * 7 + d * 3, char) + UP * 2.5
		local apex = root.Position + UP * 9 + d * 2
		local t0 = os.clock()
		while os.clock() - t0 < 0.24 and alive(char) and g.Root.Parent do
			local k = (os.clock() - t0) / 0.24
			k *= k
			local p = from:Lerp(apex, k):Lerp(apex:Lerp(land, k), k)
			Grab.place(g, CFrame.lookAt(p, root.Position))
			task.wait(1 / 60)
		end
		if not g.Root.Parent then
			break
		end
		Grab.place(g, CFrame.lookAt(land, land + d))
		local final = i == #sides
		damage(player, target, (final and (ability.FinalDamage or 10) or (ability.SlamDamage or 6)) * power,
			{ Heavy = final, Hitstop = final and 0.1 or 0.06, From = root.Position })
		broadcast("TentacleSlam", char, { Pos = land - UP * 2.5, Big = final or nil })
		Destruction.Sphere(land - UP * 2, final and 5 or 3.5, "Crater")
		if not final then
			task.wait(0.08)
		end
	end
	-- off the last slam, flung away to his right
	Grab.release(g, right * 70 + UP * 30, 0.2)
	if alive(target) then
		stun(target, 1.1)
		ragdoll(target, 1.3)
	end
end

-- R: a snack from his pouches. Knocked about while eating, he drops it.
function Handlers.Snack(_player, char, _root, ability)
	task.wait(0.55)
	if not alive(char) or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") then
		return
	end
	local spec = Config.Quirks.Manifest.Stomach or {}
	local max = spec.Max or 100
	char:SetAttribute("Stomach", math.min(max, (tonumber(char:GetAttribute("Stomach")) or max) + (ability.Refill or 50)))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + (ability.Heal or 10))
	end
end

-- SWORDFISH: a lunge (his own machine carries him), the bill goes into the
-- first one in line, lifts them on it, and flings them straight on ahead
-- (round 59: not off to the side). In
-- the air: CLAM HAMMER - brought down from over his head; whoever's under it
-- is spiked into the street, and his landing jolts anyone round it
function Handlers.Swordfish(player, char, root, ability, dir, _pos, cast)
	local power = Kit.stomach.use(player, char, ability)
	local d = flatten(dir, root)
	if cast and cast.Air then
		Reactions.comboEnder() -- (round 68: a spike into the street ends the combo)
		task.wait(0.18) -- (the hammer up over his head)
		if not alive(char) then
			return
		end
		local spiked = {}
		local cf = CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, -2.5, -3.5)
		for _, model in Rewind.QueryBox(player, char, cf, Vector3.new(9, 10, 9)) do
			spiked[model] = true
			if damage(player, model, (ability.HammerDamage or 16) * power, { Heavy = true, Hitstop = 0.1, From = root.Position }) then
				knockback(model, -UP * 110 + d * 12, 0.2)
				stun(model, 1.1)
				ragdoll(model, 1.2)
			end
		end
		-- he comes down with it (his machine drops him: at most 0.6s)
		local t0 = os.clock()
		while alive(char) and not isGrounded(root, char, 4) and os.clock() - t0 < 0.6 do
			task.wait(1 / 30)
		end
		if not alive(char) then
			return
		end
		local land = groundBelow(root.Position, char)
		broadcast("ClamHammerLand", char, { Pos = land, Dir = d })
		for _, model in queryRadius(char, land, ability.HammerRadius or 9) do
			if not spiked[model] and damage(player, model, (ability.ShockDamage or 6) * power, { From = land }) then
				knockback(model, awayFrom(land, model, d) * 45 + UP * 30, 0.16)
				stun(model, 0.6)
			end
		end
		Destruction.Sphere(land, 6, "Crater")
		return
	end
	task.wait(0.16) -- (the lunge)
	if not alive(char) then
		return
	end
	local origin = root.Position + UP * 0.8
	local reach = wallDistance(char, origin, d, ability.Range or 15)
	local target = firstInLine(char, origin, d, reach, 4.5)
	local g = target and damage(player, target, (ability.Damage or 9) * power, { Hitstop = 0.08, From = root.Position })
		and alive(target) and Grab.take(target, 0.9)
	broadcast("SwordfishImpale", char, { Target = g and target or nil, Dir = d })
	if not g then
		return
	end
	-- lifted on the bill...
	local t0 = os.clock()
	while os.clock() - t0 < 0.4 and alive(char) and g.Root.Parent do
		local k = math.min((os.clock() - t0) / 0.2, 1)
		local at = root.Position + d * 5 + UP * (0.8 + 2.4 * k)
		Grab.place(g, CFrame.lookAt(at, root.Position + UP * 2))
		task.wait(1 / 60)
	end
	-- ...and flung off it, straight on ahead of him
	Grab.release(g, d * 100 + UP * 35, 0.22)
	if alive(char) and damage(player, target, (ability.ThrowDamage or 9) * power, { Heavy = true, Hitstop = 0.08, From = root.Position }) then
		stun(target, 1.1)
		ragdoll(target, 1.4)
	end
end

-- VAST HYBRID CHIMERA (the ult) ----------------------------------------

-- KRAKEN: eight giant tentacles thrash round him in a rotating wave
function Handlers.Kraken(player, char, root, ability)
	task.wait(0.35)
	local radius = ability.Radius or 30
	for i = 1, ability.Hits or 4 do
		if not alive(char) then
			return
		end
		local center = root.Position
		for _, model in queryRadius(char, center, radius) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr and damage(player, model, ability.Damage or 5, { Hitstop = 0.04, From = center }) then
				-- swept round with the wave
				local out = awayFrom(center, model, root.CFrame.LookVector)
				local tangent = Vector3.new(-out.Z, 0, out.X)
				knockback(model, tangent * 30 + UP * 16, 0.12)
				stun(model, 0.7)
			end
		end
		local a = i / (ability.Hits or 4) * math.pi * 2
		Destruction.Sphere(center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.7, 7, "Whirl")
		task.wait(0.2)
	end
	if not alive(char) then
		return
	end
	local center = root.Position
	for _, model in queryRadius(char, center, radius) do
		if damage(player, model, ability.FinisherDamage or 14, { Heavy = true, Hitstop = 0.1, From = center }) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 110 + UP * 55, 0.25)
			stun(model, 1.4)
			ragdoll(model, 1.5)
		end
	end
	Destruction.Cylinder(center, radius * 0.75, 12, "Whirl")
end

-- CENTAUR: bull legs, horns, vines swinging hard fruit - a stampede down a
-- lane (his machine gallops him); whoever's in it is trampled and batted aside
function Handlers.Centaur(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.3) -- he rears up
	if not alive(char) then
		return
	end
	local run = 0.7
	local right = d:Cross(UP)
	tunnel(char, root, run, 6, 5, function()
		return d
	end, "Impact")
	sweep(player, char, root, run, (ability.Width or 14) / 2, 3, d, function(model)
		local mr = model:FindFirstChild("HumanoidRootPart")
		if mr and damage(player, model, ability.Damage or 20, { Heavy = true, Hitstop = 0.08, From = root.Position }) then
			local side = (mr.Position - root.Position):Dot(right) >= 0 and 1 or -1
			knockback(model, right * side * 80 + d * 55 + UP * 55, 0.25)
			stun(model, 1.3)
			ragdoll(model, 1.3)
		end
	end)
end

-- OCTOPUS MIRAGE into SCORPIUS TOXIN: he fades into the street, comes up
-- behind whoever's nearest the aim, and a scorpion tail stings them
function Handlers.OctopusMirage(player, char, root, ability, dir, pos)
	local d = flatten(dir, root)
	local range = ability.Range or 45
	local target, best
	for _, model in queryRadius(char, root.Position, range) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		local score = mr and (mr.Position - pos).Magnitude
		if score and (not best or score < best) then
			target, best = model, score
		end
	end
	local vanish = ability.Vanish or 1.4
	char:SetAttribute("Mirage", true)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + vanish)
	task.wait(vanish)
	char:SetAttribute("Mirage", nil)
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	if not alive(char) or not tr or not alive(target) or (tr.Position - root.Position).Magnitude > range + 30 then
		broadcast("MirageStrike", char, { Dir = d })
		return
	end
	local back = Vector3.new(tr.CFrame.LookVector.X, 0, tr.CFrame.LookVector.Z)
	back = back.Magnitude > 0.1 and back.Unit or -d
	local behind = tr.Position - back * 4
	char:PivotTo(CFrame.lookAt(behind, Vector3.new(tr.Position.X, behind.Y, tr.Position.Z)))
	broadcast("MirageStrike", char, { Target = target, Dir = back })
	task.wait(0.14)
	if alive(char) and damage(player, target, ability.Damage or 16, { Heavy = true, Unblockable = true, Hitstop = 0.1, From = behind }) then
		stun(target, 1.1)
		Kit.poison(target, ability.Poison or 5, ability.PoisonDamage or 3)
	end
end

-- PLASMA CANNON (ult V): HOLD to charge it (three levels), let go to fire -
-- a beam that goes straight through walls
function Handlers.PlasmaCannon(player, char, root, ability, dir)
	local held, hold = HoldMoves.wait(player, char, ability)
	if not held then
		return
	end
	local level = HoldMoves.level(ability, held)
	local aim = Config.AimedDirection(hold.Dir or dir, flatten(root.CFrame.LookVector, root), { Up = 35, Down = 35 })
	broadcast("PlasmaCannonRelease", char, { Level = level, Dir = aim }, player)
	task.wait(0.15)
	if not alive(char) then
		return
	end
	local length = ability.Range or 260
	local width = (ability.LevelWidth and ability.LevelWidth[level]) or 12
	local amount = (ability.LevelDamage and ability.LevelDamage[level]) or ability.Damage or 26
	local origin = root.Position + UP * 1.5 + flatten(aim, root) * 3
	beamHit(char, origin, aim, length, width, function(model)
		if damage(player, model, amount, { Heavy = true, Hitstop = 0.12, From = origin }) then
			knockback(model, aim * 130 + UP * 40, 0.3)
			stun(model, 1.4)
			ragdoll(model, 1.6)
		end
	end)
	Destruction.Capsule(origin + aim * 6, origin + aim * length, width * 0.5, "Beam", aim)
end

---------------------------------------------------------------------------
-- OVERHAUL: take apart whatever he touches, put it back together as spikes
---------------------------------------------------------------------------

-- A bare-handed lunge: whoever he touches cracks red, comes apart and is
-- slammed back together a moment later (walls he runs into come apart too)
function Handlers.Disassemble(player, char, root, ability, dir)
	local d = flatten(dir, root)
	tunnel(char, root, 0.35, 4, 6, function()
		return d
	end, "Overhaul")
	local caught = false
	sweep(player, char, root, 0.35, 6, 2.5, d, function(model)
		if caught then
			return
		end
		if damage(player, model, ability.Damage) then
			caught = true
			stun(model, ability.Stun or 1.2)
			broadcast("Disassembled", char, { Target = model })
			task.delay(0.45, function()
				if model.Parent then
					knockback(model, d * 45 + UP * 30, 0.2)
				end
			end)
		end
	end)
end

-- Palm on the ground: a crack races ahead and the street behind it erupts
-- into a line of spikes that throws anyone on it into the air. (The VFX
-- raises its spikes on the same timeline: one step every 0.03s.)
local SPIKE_STEP, SPIKE_STEP_TIME = 5, 0.03
-- SPIKE FAN: three short lines of spikes fanning out from his palm (Lanes
-- lines, Spread degrees apart); each target is hit once, by whichever line
-- reaches them first
function Handlers.SpikeRush(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	local origin = cast and cast.Origin or root.Position
	task.wait(0.25) -- the palm comes down
	if not alive(char) then
		return
	end
	local lanes = ability.Lanes or 3
	local spread = math.rad(ability.Spread or 26)
	local dirs = {}
	for i = 1, lanes do
		local a = (i - (lanes + 1) / 2) * spread
		local c, sn = math.cos(a), math.sin(a)
		table.insert(dirs, Vector3.new(d.X * c - d.Z * sn, 0, d.X * sn + d.Z * c).Unit)
	end
	local start = groundBelow(origin + d * 3, char)
	local hitSet = {}
	-- (round 75) where a wall stops each lane
	local stopAt = {}
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.FilterDescendantsInstances = nonMapStuff(char)
	for i, ld in dirs do
		local hit = workspace:Raycast(start + UP * 3, ld * (ability.Range or 40), wallParams)
		if hit and math.abs(hit.Normal.Y) < 0.6 then
			stopAt[i] = (hit.Position - (start + UP * 3)).Magnitude
		end
	end
	for dist = 0, ability.Range or 40, SPIKE_STEP do
		for i, ld in dirs do
			if stopAt[i] and dist > stopAt[i] + SPIKE_STEP then
				continue
			end
			local p = start + ld * dist
			for _, model in queryBox(char, CFrame.lookAt(p + UP * 4, p + UP * 4 + ld), Vector3.new(7, 10, SPIKE_STEP + 2), hitSet) do
				hitSet[model] = true
				if damage(player, model, ability.Damage) then
					knockback(model, UP * 75 + ld * 22, 0.22)
					stun(model, 1.1)
				end
			end
			if dist % (SPIKE_STEP * 2) == 0 then
				Destruction.Sphere(p + UP * 2, 4, "Overhaul", UP)
			end
		end
		task.wait(SPIKE_STEP_TIME)
	end
end

-- Reassembly: the ground around the aim point folds up into a ring of stone
-- walls (whoever's inside is stuck), then spikes lance in from every side
function Handlers.SpikePrison(player, char, root, ability, _dir, pos)
	local center = groundTarget(root, pos, ability.Range or 60, char)
	local radius = ability.Radius or 12
	task.wait(0.3) -- the walls rise
	if not alive(char) then
		return
	end
	for _, model in queryCylinder(char, center - UP * 2, radius, 16) do
		stun(model, ability.Hold or 1.6, 0)
	end
	task.wait(0.6) -- the spikes stab in
	for _, model in queryCylinder(char, center - UP * 2, radius + 1, 16) do
		if damage(player, model, ability.Damage) then
			knockback(model, UP * 55, 0.2)
			stun(model, 0.8)
		end
	end
	Destruction.Sphere(center + UP * 2, radius * 0.5, "Overhaul", UP)
end

-- R: he takes his own body apart and rebuilds it whole. Burns and decay stop
-- - there's nothing left of the old body for them to eat.
function Handlers.Restore(_player, char, _root, ability)
	local hum = char:FindFirstChildOfClass("Humanoid")
	task.wait(0.35)
	if not alive(char) then
		return
	end
	hum.Health = math.min(hum.MaxHealth, hum.Health + (ability.Heal or 45))
	burnTokens[char] = (burnTokens[char] or 0) + 1
	decayTokens[char] = (decayTokens[char] or 0) + 1
	char:SetAttribute("Burning", false)
	char:SetAttribute("Decaying", false)
end

-- Fused: all four hands down, and pillars of stone burst out of the ground
-- one after another, marching toward the aim point
function Handlers.PillarBarrage(player, char, root, ability, dir, _pos, cast)
	local d = flatten(dir, root)
	local origin = cast and cast.Origin or root.Position
	local hits = ability.Hits or 6
	local range = ability.Range or 90
	task.wait(0.3)
	for i = 1, hits do
		if not alive(char) then
			return
		end
		local p = groundBelow(origin + d * (10 + (i - 1) * (range - 10) / math.max(hits - 1, 1)), char)
		local final = i == hits
		for _, model in queryCylinder(char, p - UP * 2, final and 12 or 9, final and 28 or 24) do
			if damage(player, model, final and (ability.FinisherDamage or 18) or ability.Damage, { Heavy = final, Hitstop = final and 0.09 or 0.03, From = p }) then
				knockback(model, UP * (final and 115 or 65) + d * (final and 65 or 35), 0.22)
				stun(model, final and 1.2 or 0.55)
			end
		end
		Destruction.Sphere(p + UP * 3, final and 10 or 7, "Overhaul", UP)
		task.wait(0.12)
	end
end

-- Fused arms catch a small group in front, draw them together, then slam.
-- The opening contact respects guard and evasive frames before the grab starts.
function Handlers.MassGrasp(player, char, root, ability, dir)
	local d = flatten(dir, root)
	task.wait(0.3)
	if not alive(char) then
		return
	end
	local range = ability.Range or 55
	local candidates = {}
	for _, model in queryRadius(char, root.Position + d * (range / 2), range / 2 + 6) do
		local mr = model:FindFirstChild("HumanoidRootPart")
		local v = mr and mr.Position - root.Position
		local flat = v and Vector3.new(v.X, 0, v.Z)
		if v and v.Magnitude <= range and (flat.Magnitude < 3 or flat.Unit:Dot(d) > 0.48) then
			table.insert(candidates, { Model = model, Distance = v.Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	local caught, targets = {}, {}
	for _, candidate in candidates do
		if #caught >= (ability.MaxTargets or 3) then
			break
		end
		local model = candidate.Model
		if damage(player, model, ability.Damage or 10, { Hitstop = 0.05, From = root.Position }) and alive(model) then
			local g = Grab.take(model, 1.2)
			if g then
				table.insert(caught, g)
				table.insert(targets, model)
			end
		end
	end
	if #caught == 0 then
		return
	end
	broadcast("MassGraspCatch", char, { Targets = targets })
	local from = {}
	for i, g in caught do
		from[i] = g.Root.Position
	end
	local t0 = os.clock()
	while os.clock() - t0 < 0.55 and alive(char) and not char:GetAttribute("Stunned") do
		local alpha = math.clamp((os.clock() - t0) / 0.55, 0, 1)
		for i, g in caught do
			if g.Root.Parent and alive(g.Model) then
				local side = d:Cross(UP) * ((i - (#caught + 1) / 2) * 6)
				local dest = root.Position + d * 18 + side + UP * 11
				local at = from[i]:Lerp(dest, alpha)
				Grab.place(g, CFrame.lookAt(at, at + d))
			end
		end
		task.wait(0.03)
	end
	for _, g in caught do
		if g.Root.Parent then
			local impact = groundBelow(g.Root.Position, char)
			Grab.release(g, d * 30 - UP * 125, 0.2)
			if alive(char) and not char:GetAttribute("Stunned") and alive(g.Model) and damage(player, g.Model, ability.FinisherDamage or 18, { Heavy = true, Hitstop = 0.08, From = root.Position }) then
				stun(g.Model, 1.2)
				ragdoll(g.Model, 1.2)
			end
			Destruction.Sphere(impact + UP * 2, 7, "Overhaul", UP)
		else
			Grab.release(g)
		end
	end
end

-- The cinematic: the whole block cracks red and comes apart in a spreading
-- wave... and is rebuilt as a forest of spikes that impales everything in it
function Handlers.TotalOverhaul(player, char, root, ability)
	task.wait(1.1) -- gloves off, four hands on the ground, the cracks spread
	if not alive(char) then
		return
	end
	local center = groundBelow(root.Position, char)
	local radius = ability.Radius or 85
	for step = 1, 5 do
		Destruction.Cylinder(center + UP * 20, radius * step / 5, 40, "OverhaulHuge", UP)
		task.wait(0.1)
	end
	task.wait(0.3)
	for _, model in queryCylinder(char, center - UP * 4, radius, 80) do
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 50 + UP * 130, 0.28)
			stun(model, 2)
		end
	end
end

-- FUSION: KATSUKAME - the kaiju from the Deku fight. It rises out of the
-- ground (blasting everyone near), then for Duration seconds: his M1s are
-- giant arm slams, a hurtbox the size of the monster, no jumping, and it
-- crushes whatever it walks through. Every client draws the creature.
local kaijuTokens = setmetatable({}, { __mode = "k" })

-- While the kaiju stands he's inside it: his body, his gear, their particles
-- and outlines are hidden for everyone (whatever gets added meanwhile too),
-- and come back exactly as they were when it comes apart.
local kaijuHidden = setmetatable({}, { __mode = "k" }) -- [char] = what was hidden
local HIDE_ENABLED = { "ParticleEmitter", "Light", "Highlight", "Beam", "Trail", "Fire", "Smoke", "Sparkles" }
local function hideForKaiju(char, hidden)
	local saved = kaijuHidden[char]
	if hidden then
		if saved then
			return
		end
		saved = { transparency = {}, enabled = {} }
		kaijuHidden[char] = saved
		local function hide(d)
			if d.Name == "KaijuHurtbox" then
				return
			end
			if d:IsA("BasePart") or d:IsA("Decal") then -- Decal covers Texture too
				if saved.transparency[d] == nil then
					saved.transparency[d] = d.Transparency
				end
				d.Transparency = 1
				return
			end
			for _, className in HIDE_ENABLED do
				if d:IsA(className) then
					if saved.enabled[d] == nil then
						saved.enabled[d] = d.Enabled
					end
					d.Enabled = false
					return
				end
			end
		end
		for _, d in char:GetDescendants() do
			hide(d)
		end
		saved.conn = char.DescendantAdded:Connect(hide)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			saved.display = hum.DisplayDistanceType
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	elseif saved then
		kaijuHidden[char] = nil
		saved.conn:Disconnect()
		for d, t in saved.transparency do
			if d.Parent then
				d.Transparency = t
			end
		end
		for d, on in saved.enabled do
			if d.Parent then
				d.Enabled = on
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and saved.display then
			hum.DisplayDistanceType = saved.display
		end
	end
end

local function endKaiju(char)
	kaijuTokens[char] = (kaijuTokens[char] or 0) + 1
	hideForKaiju(char, false) -- he steps back out of it (before the clients hear it ended)
	if not char:GetAttribute("Kaiju") then
		return
	end
	char:SetAttribute("Kaiju", nil)
	local box = char:FindFirstChild("KaijuHurtbox")
	if box then
		box:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.JumpPower = char:GetAttribute("BaseJumpPower") or Config.BaseJumpPower
	end
	broadcast("KaijuEnd", char, {})
end

function Handlers.Kaiju(player, char, root, ability)
	local token = (kaijuTokens[char] or 0) + 1
	kaijuTokens[char] = token
	task.wait(0.5) -- his body comes apart (the cinematic)...
	if not alive(char) or kaijuTokens[char] ~= token or not player:GetAttribute("UltActive") then
		return
	end
	hideForKaiju(char, true)
	task.wait(1.1) -- ...and puts itself back together as the monster
	if not alive(char) or kaijuTokens[char] ~= token or not player:GetAttribute("UltActive") then
		if kaijuTokens[char] == token then
			hideForKaiju(char, false)
		end
		return
	end
	local center = root.Position
	for _, model in queryRadius(char, center, ability.Radius or 32) do
		if damage(player, model, ability.Damage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 90 + UP * 70, 0.3)
			stun(model, 1.5)
		end
	end
	Destruction.Sphere(center + UP * 6, 22, "OverhaulHuge", UP)
	-- the monster's body can be hit anywhere, not just where he stands inside it
	local box = Instance.new("Part")
	box.Name = "KaijuHurtbox"
	box.Size = Vector3.new(26, 36, 50)
	box.Transparency = 1
	box.CanCollide = false
	box.CanTouch = false
	box.CanQuery = true
	box.Massless = true
	box.CFrame = root.CFrame * CFrame.new(0, 15, -2)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = box
	w.Parent = box
	box.Parent = char
	char:SetAttribute("Kaiju", true)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = 0
	end
	local last = root.Position
	local t0 = os.clock()
	while os.clock() - t0 < (ability.Duration or 14) and alive(char) and kaijuTokens[char] == token and player:GetAttribute("UltActive") do
		local moved = root.Position - last
		if Vector3.new(moved.X, 0, moved.Z).Magnitude > 4 then
			-- whatever it walks through comes apart
			local ahead = flatten(moved, root)
			Destruction.Sphere(root.Position + UP * 12 + ahead * 8, 12, "Overhaul", ahead)
			last = root.Position
		end
		task.wait(0.2)
	end
	if kaijuTokens[char] == token then
		endKaiju(char)
	end
end

-- the kaiju's M1: an arm comes down 20 studs ahead (right, then left)
local function kaijuSlam(player, char, root)
	local st = m1State[player] or { Count = 0, Last = 0, NextAllowed = 0 }
	m1State[player] = st
	local now = os.clock()
	if now < st.NextAllowed then
		return
	end
	st.Count = st.Count % 2 + 1
	st.Last = now
	st.NextAllowed = now + (KAIJU.SlamCooldown or 0.85) - 0.08
	local arm = st.Count
	broadcast("Punch", char, { Count = arm, Finisher = false }, player)
	task.delay(0.34, function() -- the fist lands (the VFX's timeline)
		if not alive(char) or not char:GetAttribute("Kaiju") then
			return
		end
		local f = flatten(root.CFrame.LookVector, root)
		local point = groundBelow(root.Position + f * 20 + f:Cross(UP) * (arm == 1 and 5 or -5), char)
		for _, model in queryRadius(char, point, KAIJU.SlamRadius or 14) do
			if damage(player, model, KAIJU.SlamDamage or 24, { Heavy = true, Hitstop = 0.1 }) then
				knockback(model, awayFrom(point, model, f) * 70 + UP * 80, 0.25)
				stun(model, 1.2)
			end
		end
		Destruction.Sphere(point, 10, "Crater", UP)
	end)
end

-- Domain Expansion: Unlimited Void. Everyone caught inside when it closes is
-- paralysed; anyone inside afterwards is slowed until the domain collapses.
local function expandDomain(char, center, ult, token, stillActive)
	local radius = ult.DomainRadius or 60
	broadcast("Domain", char, { Pos = center, Radius = radius, Duration = ult.Duration })
	task.wait(0.9) -- the void closes around them
	if not stillActive(token) then
		return
	end
	for _, model in queryRadius(char, center, radius) do
		if not untouchable(model) then
			stun(model, ult.DomainStun or 4, 0)
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then
				PlayVFX:FireClient(plr, "VoidOverload", nil, { Duration = ult.DomainStun or 4 })
			end
		end
	end
	while stillActive(token) and alive(char) do
		task.wait(0.5)
		for _, model in queryRadius(char, center, radius) do
			slow(model, 0.7, ult.DomainSlow or 9)
		end
	end
	broadcast("DomainEnd", char, { Pos = center, Radius = radius })
end

---------------------------------------------------------------------------
-- M1 combo
---------------------------------------------------------------------------

-- Parkour runs on the player's own machine (it owns its physics); the server
-- just passes the move on so everyone else sees the vault / climb / hop
local relayParkour
do
	local KINDS = {
		Vault = true, Mantle = true, Climb = true, WallUp = true, Slide = true, WallRun = true, WallKick = true, Roll = true,
		Glide = true, GlideEnd = true, -- (round 59: Suneater's wings)
	}
	local last = setmetatable({}, { __mode = "k" })
	relayParkour = function(player, char, kind, dir, side, time)
		if not KINDS[kind] then
			return
		end
		local now = os.clock()
		if now - (last[player] or 0) < 0.08 then
			return
		end
		last[player] = now
		local d = (typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.01) and dir.Unit or nil
		broadcast("Parkour", char, {
			Kind = kind,
			Dir = d,
			Side = (side == "L" or side == "R") and side or nil,
			Time = (type(time) == "number" and time == time) and math.clamp(time, 0, 2) or nil,
		}, player)
	end
end

-- (round 73) BAKUGO'S EXPLOSION FLIGHT (Config.Quirks.Explosion.BlastFlight):
-- his own machine flies him; the server marks him (BlastFlying, on the body)
-- and passes the take-off, every blast and the drop-out on to everyone else.
-- Only Bakugo, only on his feet (not stunned, down, held, frozen); a blast no
-- sooner than MinGap after the last. Dropping out always goes through.
do
	local BF = { KINDS = { BlastFly = true, BlastPulse = true, BlastFlyEnd = true } }
	Kit.BF = BF
	local last = setmetatable({}, { __mode = "k" })
	function BF.relay(player, char, kind, dir)
		if not char or not char.Parent then
			return
		end
		if kind == "BlastFlyEnd" then
			if char:GetAttribute("BlastFlying") then
				char:SetAttribute("BlastFlying", nil)
				broadcast("BlastFly", char, { Kind = "End" }, player)
			end
			return
		end
		local spec = (Config.Quirks.Explosion or {}).BlastFlight or {}
		local root = char:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("Quirk") ~= "Explosion" or not root or not alive(char) or char:GetAttribute("Stunned")
			or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") or char:GetAttribute("Frozen") or player:GetAttribute("NoSkills") then
			return
		end
		local now = os.clock()
		if kind == "BlastPulse" and (not char:GetAttribute("BlastFlying") or now - (last[player] or 0) < (spec.MinGap or 0.2)) then
			return
		end
		last[player] = now
		local d = (typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.01) and dir.Unit or root.CFrame.LookVector
		if kind == "BlastFly" then
			char:SetAttribute("BlastFlying", true)
		end
		broadcast("BlastFly", char, { Kind = kind == "BlastFly" and "Start" or "Pulse", Dir = d }, player)
	end
end

-- where the attacker stood, and which way they faced, on their own screen
-- when they swung (trusted within Config.Hitboxes.MaxOriginDrift)
local function swingOrigin(root, clientCF)
	local HB = Config.Hitboxes or {}
	if typeof(clientCF) == "CFrame" and clientCF.Position == clientCF.Position then
		local drift = (clientCF.Position - root.Position).Magnitude
		local l = clientCF.LookVector
		local f = Vector3.new(l.X, 0, l.Z)
		if drift <= (HB.MaxOriginDrift or 8) + root.AssemblyLinearVelocity.Magnitude * 0.15 and f.Magnitude > 0.05 then
			return clientCF.Position, f.Unit
		end
	end
	local look = root.CFrame.LookVector
	local f = Vector3.new(look.X, 0, look.Z)
	return root.Position, f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, -1)
end

-- how high a body is off the street (a standing one reads ~3: hips + half the root)
local function heightAboveGround(root, char)
	return root.Position.Y - groundBelow(root.Position, char).Y
end

-- The 4th hit's JJS variants (Config.M1.Uppercut / Downslam), and air combos
local M1V = {}
do
	local UPC = Config.M1.Uppercut or {}
	local DS = Config.M1.Downslam or {}
	local AJ = Config.M1.AirJuggle or {}

	-- straight up: stunned in the air (not limp), ready for an air combo
	function M1V.Uppercut(model, f)
		stun(model, UPC.Stun or 1.3)
		knockback(model, f * (UPC.Forward or 8) + UP * (UPC.Lift or 55), UPC.LiftTime or 0.12, true)
	end

	-- spiked into the street: a crater where they land, and a bounce off it
	function M1V.Downslam(model, f)
		local troot = model:FindFirstChild("HumanoidRootPart")
		local drop = DS.Drop or 150
		stun(model, (DS.Ragdoll or 1.5) + 0.3)
		ragdoll(model, DS.Ragdoll or 1.5)
		knockback(model, f * (DS.Forward or 10) - UP * drop, 0.18, true)
		local fall = troot and math.max(heightAboveGround(troot, model) - 3, 0) or 0
		task.delay(math.clamp(fall / drop, 0.05, 0.6), function()
			local r = model:FindFirstChild("HumanoidRootPart")
			if not r or not model.Parent then
				return
			end
			local g = groundBelow(r.Position, model)
			Destruction.Sphere(g, DS.Crater or 3.2, "Impact", -UP)
			broadcast("Downslam", nil, { Pos = g, Target = model })
			-- the street stops the spike (drop the push), and they bounce off it
			for _, c in r:GetChildren() do
				if c.Name == "Knockback" or c.Name == "KnockbackAttachment" then
					c:Destroy()
				end
			end
			knockback(model, UP * (DS.Bounce or 26) + f * 4, 0.1, true)
		end)
	end

	-- both of you in the air: every hit keeps them floating up there with you
	function M1V.Juggle(model, f)
		knockback(model, f * (AJ.Forward or 3) + UP * (AJ.Up or 26), 0.1, true)
		stun(model, AJ.Stun or 0.7)
	end
end

-- (round 65) when each body's current M1 lock ends: a side / back dash may
-- cut into it (Config.Movement.DashOutOfM1)
Kit.m1Until = setmetatable({}, { __mode = "k" })

local function handleM1(player, char, root, clientCF, variant)
	if char:GetAttribute("Kaiju") then
		kaijuSlam(player, char, root)
		return
	end
	local st = m1State[player] or { Count = 0, Last = 0, NextAllowed = 0 }
	m1State[player] = st
	local now = os.clock()
	if now < st.NextAllowed then
		return
	end
	if now - st.Last > Config.M1.ComboReset then
		st.Count = 0
	end
	st.Count = st.Count % Config.M1.ComboLength + 1
	st.Last = now
	local finisher = st.Count == Config.M1.ComboLength
	st.NextAllowed = now + (finisher and Config.M1.FinisherCooldown or Config.M1.Cooldown) - 0.05
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + (finisher and (Config.M1.FinisherActionTime or 0.42) or (Config.M1.ActionTime or 0.18)))
	Kit.m1Until[char] = char:GetAttribute("CombatActionUntil")
	-- only the 4th hit has variants; a downslam needs you off the ground
	-- (lenient: the server sees you a little late)
	local height = heightAboveGround(root, char)
	-- (round 63) where your own screen had you counts too (the server sees a
	-- jump a moment late), within reason - and a little off the street is
	-- enough (Config.M1.DownslamHeight)
	if typeof(clientCF) == "CFrame" and clientCF.Position == clientCF.Position
		and (clientCF.Position - root.Position).Magnitude <= 10 then
		height = math.max(height, clientCF.Position.Y - groundBelow(clientCF.Position, char).Y)
	end
	local airborne = height > 3 + (Config.M1.DownslamHeight or 0.6) * 0.5
	if not finisher or (variant ~= "Up" and variant ~= "Down") or (variant == "Down" and not airborne) then
		variant = nil
	end

	broadcast("Punch", char, { Count = st.Count, Finisher = finisher, Variant = variant }, player)

	local origin0, f = swingOrigin(root, clientCF)
	-- a downslam reaches down to whoever is under you
	local boxSize = variant == "Down" and Config.M1.HitboxSize + Vector3.new(0, 5, 0) + (Config.M1.Downslam.HitboxExtra or Vector3.zero) or Config.M1.HitboxSize
	local boxDrop = variant == "Down" and -3 or 0 -- (round 75: a hair bigger, a hair lower)
	-- (round 60) Creati's weapon: further reach, x its damage
	local reach, weaponHit = 0, 1
	if Kit.YM then
		reach, weaponHit = Kit.YM.m1(player)
	end
	-- (round 66) Crazy Diamond: the Stand throws it, from out in front of him
	local standQuirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	if standQuirk and standQuirk.Stand then
		reach += standQuirk.StandReach or 2.5 -- (round 74: The World's too)
	end
	boxSize += Vector3.new(0, 0, reach)
	local pressedAt = root.Position
	local frames = math.max(1, (Config.Hitboxes and Config.Hitboxes.M1ActiveFrames) or 1)
	local hitSet = {}
	-- the finisher winds up longer before it lands (matches the animation)
	task.delay(finisher and 0.14 or 0.08, function()
		for frame = 1, frames do
			if frame > 1 then
				task.wait(1 / 30)
			end
			if not alive(char) or player.Character ~= char or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") then
				return -- (a swing dies with the body that threw it)
			end
			-- (the swing stays live for a few frames, carried along as they move)
			local origin = origin0 + (root.Position - pressedAt)
			local cf = CFrame.lookAt(origin, origin + f) * CFrame.new(0, boxDrop, -(Config.M1.HitboxForward or 3.5) - reach / 2)
			if finisher and not variant and frame == 1 then
				-- (Config.M1.Destruction; round 69: only the 4th) a hole the
				-- size of a body in whatever it lands on
				local size = (Config.M1.Destruction or {}).Finisher or Vector3.new(4.5, 6, 4)
				Destruction.Box(CFrame.lookAt(origin, origin + f) * CFrame.new(0, -0.3, -(2.5 + size.Z / 2)), size, "Impact", f)
			end
			for _, model in Rewind.QueryBox(player, char, cf, boxSize, hitSet) do
				hitSet[model] = true
				if Players:GetPlayerFromCharacter(model) == player then
					continue -- never your own (new) body
				end
				local dmg = (finisher and Config.M1.FinisherDamage or Config.M1.Damage) * weaponHit
				local hitstop = (variant == "Up" and Config.M1.Uppercut.Hitstop) or (variant == "Down" and Config.M1.Downslam.Hitstop)
					or Config.M1.FinisherHitstop
				local opts = finisher and { GuardDamage = GUARD.FinisherGuardDamage or 30, Hitstop = hitstop, Heavy = true, Downslam = variant == "Down" or nil }
					or { Hitstop = Config.M1.Hitstop }
				if damage(player, model, dmg, opts) then
					local troot = model:FindFirstChild("HumanoidRootPart")
					if variant == "Up" then
						M1V.Uppercut(model, f)
					elseif variant == "Down" then
						M1V.Downslam(model, f)
					elseif not finisher and airborne and troot and heightAboveGround(troot, model) > 4.5 then
						M1V.Juggle(model, f)
					elseif finisher then
						-- go limp first, so the launch is the soft ragdoll push
						-- (not on someone just back on their feet: no loops)
						local immune = Evasive.immune(model)
						if Config.M1.RagdollOnFinisher and not immune then
							stun(model, Config.M1.RagdollTime + 0.3)
							ragdoll(model, Config.M1.RagdollTime)
						elseif not immune then
							stun(model, 0.8)
						end
						knockback(model, f * Config.M1.FinisherKnockback + UP * (Config.M1.FinisherLift or 15), 0.2, true)
					else
						knockback(model, f * 10, 0.1, true)
						if not Evasive.immune(model) then
							stun(model, 0.45)
						end
					end
				end
			end
			-- punching a snack machine knocks a free snack loose
			if frame == 1 and Store.PunchMachine then
				Store.PunchMachine(cf.Position)
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Quirk gear: cosmetic parts welded to the character (visible to everyone)
---------------------------------------------------------------------------

local function gearPart(parent, size, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(part0, part1, c0)
	part1.CFrame = part0.CFrame * c0
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
end

local function findLimb(char, r15Name, r6Name)
	return char:FindFirstChild(r15Name) or char:FindFirstChild(r6Name)
end

-- Iida-style exhaust pipes sticking out of the back of each calf
local function addEnginePipes(gear, char, turbo)
	local isR15 = char:FindFirstChild("UpperTorso") ~= nil
	for _, names in { { "RightLowerLeg", "Right Leg" }, { "LeftLowerLeg", "Left Leg" } } do
		local leg = findLimb(char, names[1], names[2])
		if leg then
			local yCenter = isR15 and leg.Size.Y * 0.08 or -leg.Size.Y * 0.22
			for i = -1, 1 do
				local len = 0.95
				local pipe = gearPart(gear, Vector3.new(len, 0.34, 0.34), Color3.fromRGB(60, 62, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
				pipe.Name = "Pipe"
				-- cylinder axis is X; rotate so +X points out the back of the calf
				local c0 = CFrame.new(0, yCenter + i * leg.Size.Y * 0.16, leg.Size.Z / 2 + len / 2 - 0.12)
					* CFrame.Angles(0, math.rad(-90), 0)
				weld(leg, pipe, c0)
				local tip = Instance.new("Attachment")
				tip.Position = Vector3.new(len / 2, 0, 0)
				tip.Parent = pipe
				local pe = Instance.new("ParticleEmitter")
				pe.Texture = "rbxasset://textures/particles/fire_main.dds"
				pe.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255), Color3.fromRGB(90, 160, 255))
				pe.LightEmission = 1
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
				pe.Transparency = NumberSequence.new(0.2, 1)
				pe.Speed = NumberRange.new(4, 7)
				pe.Lifetime = NumberRange.new(0.12, 0.22)
				pe.Rate = turbo and 60 or 10
				if turbo then
					pe.Speed = NumberRange.new(10, 16)
					pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
				end
				pe.EmissionDirection = Enum.NormalId.Right
				pe.SpreadAngle = Vector2.new(8, 8)
				pe.Parent = tip
			end
		end
	end
end

-- Real flames licking up off a part (same look as the VFX fire): a hot
-- core, the body cooling from yellow to red as it rises, smoke and embers
local FIRE_TEXTURE = (Config.Assets and Config.Assets.FireTexture) or "rbxasset://textures/particles/fire_main.dds"
local function addFlames(holder, s)
	local NS, NK, CK = NumberSequence.new, NumberSequenceKeypoint.new, ColorSequenceKeypoint.new
	local function pe(props)
		local e = Instance.new("ParticleEmitter")
		for k, v in props do
			e[k] = v
		end
		e.Parent = holder
	end
	pe({
		Texture = FIRE_TEXTURE, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new({
			CK(0, Color3.fromRGB(255, 240, 190)), CK(0.2, Color3.fromRGB(255, 190, 80)), CK(0.5, Color3.fromRGB(255, 120, 34)),
			CK(0.8, Color3.fromRGB(214, 56, 18)), CK(1, Color3.fromRGB(110, 28, 14)),
		}),
		Size = NS({ NK(0, s * 0.35), NK(0.3, s * 0.5), NK(1, 0) }),
		Transparency = NS({ NK(0, 1), NK(0.1, 0.2), NK(0.6, 0.4), NK(1, 1) }),
		Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(s * 0.6, s * 1.3), Drag = 2.5,
		Acceleration = Vector3.new(0, s * 5, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-140, 140),
		SpreadAngle = Vector2.new(15, 15), Rate = 26, ZOffset = 0.5,
	})
	pe({
		Texture = FIRE_TEXTURE, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 236), Color3.fromRGB(255, 214, 120)),
		Size = NS({ NK(0, s * 0.2), NK(1, 0) }), Transparency = NS({ NK(0, 0.3), NK(1, 1) }),
		Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(s * 0.5, s), Drag = 2,
		Rotation = NumberRange.new(0, 360), SpreadAngle = Vector2.new(10, 10), Rate = 18, ZOffset = 1,
	})
	pe({
		Texture = (Config.Assets and Config.Assets.SmokeTexture) or "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 56), Color3.fromRGB(36, 33, 33)), LightInfluence = 0.3,
		Size = NS({ NK(0, s * 0.3), NK(1, s * 0.9) }), Transparency = NS({ NK(0, 1), NK(0.3, 0.7), NK(1, 1) }),
		Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(s * 0.8, s * 1.4), Drag = 1.2,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), SpreadAngle = Vector2.new(15, 15), Rate = 4, ZOffset = -1,
	})
	pe({
		Texture = "rbxasset://textures/particles/sparkles_main.dds", LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 90, 24)),
		Size = NS({ NK(0, 0.18), NK(1, 0) }), Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(s, s * 2.2),
		Drag = 1.5, Acceleration = Vector3.new(0, s, 0), SpreadAngle = Vector2.new(45, 45), Rate = 6,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = s * 4
	light.Brightness = 1.8
	light.Parent = holder
end

-- Half-Cold/Half-Hot: left arm burns on the fire side, right arm frosts on the ice side
local function addSideAura(gear, char, fireSide)
	local arm = fireSide and findLimb(char, "LeftLowerArm", "Left Arm") or findLimb(char, "RightLowerArm", "Right Arm")
	if not arm then
		return
	end
	-- (on the fire side the holder is arm-sized: the flames rise off the whole forearm)
	local holder = gearPart(gear, fireSide and arm.Size * 0.8 or Vector3.one * 0.2, Color3.new(), nil, nil)
	holder.Transparency = 1
	weld(arm, holder, CFrame.new())
	if fireSide then
		addFlames(holder, 2.4)
		local shoulder = findLimb(char, "LeftUpperArm", "Left Arm")
		if shoulder and shoulder ~= arm then
			local upper = gearPart(gear, shoulder.Size * 0.7, Color3.new(), nil, nil)
			upper.Transparency = 1
			weld(shoulder, upper, CFrame.new())
			addFlames(upper, 1.8)
		end
	else
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 248, 255), Color3.fromRGB(140, 205, 255))
		pe.LightEmission = 0.6
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Speed = NumberRange.new(0.5, 2)
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Rate = 12
		pe.Acceleration = Vector3.new(0, -3, 0)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = holder
	end
end

-- Decay: dust constantly sifting off both hands (thicker while ulting)
local function addDecayDust(gear, char, ult)
	for _, names in { { "RightHand", "Right Arm" }, { "LeftHand", "Left Arm" } } do
		local hand = findLimb(char, names[1], names[2])
		if hand then
			local h = gearPart(gear, Vector3.one * 0.2, Color3.new(), nil, nil)
			h.Transparency = 1
			weld(hand, h, CFrame.new(0, -hand.Size.Y / 2, 0))
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
			pe.Color = ColorSequence.new(Color3.fromRGB(150, 140, 142), Color3.fromRGB(90, 80, 84))
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) })
			pe.Transparency = NumberSequence.new(0.35, 1)
			pe.Speed = NumberRange.new(0.5, 1.5)
			pe.Lifetime = NumberRange.new(0.6, 1.2)
			pe.Acceleration = Vector3.new(0, -4, 0)
			pe.SpreadAngle = Vector2.new(40, 40)
			pe.Rate = ult and 30 or 8
			pe.Parent = h
		end
	end
end

-- Full Cowl: green light and energy leaking off the limbs (the crawling
-- lightning itself is drawn by every client - see VFX)
local function addCowlGlow(gear, char, full)
	local torso = findLimb(char, "UpperTorso", "Torso")
	if torso then
		local holder = gearPart(gear, Vector3.one * 0.2, Color3.new(), nil, nil)
		holder.Transparency = 1
		weld(torso, holder, CFrame.new())
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(96, 255, 140)
		light.Range = full and 16 or 10
		light.Brightness = full and 2.5 or 1.4
		light.Parent = holder
	end
	for _, names in { { "RightLowerArm", "Right Arm" }, { "LeftLowerArm", "Left Arm" }, { "RightLowerLeg", "Right Leg" }, { "LeftLowerLeg", "Left Leg" } } do
		local part = findLimb(char, names[1], names[2])
		if part then
			local h = gearPart(gear, Vector3.one * 0.2, Color3.new(), nil, nil)
			h.Transparency = 1
			weld(part, h, CFrame.new())
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(Color3.fromRGB(220, 255, 230), Color3.fromRGB(96, 255, 140))
			pe.LightEmission = 1
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, full and 0.5 or 0.35), NumberSequenceKeypoint.new(1, 0) })
			pe.Speed = NumberRange.new(1, 3)
			pe.Lifetime = NumberRange.new(0.2, 0.4)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Rate = full and 14 or 6
			pe.Parent = h
		end
	end
end

-- OVERHAUL's look: the black plague-doctor beak mask (strapped on, with
-- breathing filters), the fur collar of his coat, and gloves - he only ever
-- bares his hands to use his quirk. Fused (ult): the gloves are off, the
-- beak has grown into flesh, and a second pair of arms reaches out of his back.
local MASK_BLACK = Color3.fromRGB(34, 28, 40)
-- fused with Nemoto (the anime's look): his own arms turn pink and cracked, the
-- two new ones are dark brown rock with hooked claws, tatters of Nemoto's cape
-- trail off them, and the mask runs red with a gold stripe
local FUSED_DARK = Color3.fromRGB(62, 36, 36)
local FUSED_MASK = Color3.fromRGB(150, 30, 42)
local CLAW_BLACK = Color3.fromRGB(24, 16, 18)
local CAPE_BLACK = Color3.fromRGB(16, 14, 18)
local GOLD = Color3.fromRGB(212, 170, 72)

local function ellipsoid(gear, size, color, material)
	local p = gearPart(gear, size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- a rounded rod (cylinder) from a to b, in part0's space
local function rod(gear, part0, a, b, thick, color, material)
	local span = b - a
	local x = span.Unit
	local ref = math.abs(x.Y) < 0.95 and UP or Vector3.new(1, 0, 0)
	local z = x:Cross(ref).Unit
	local p = gearPart(gear, Vector3.new(span.Magnitude, thick, thick), color, material, Enum.PartType.Cylinder)
	weld(part0, p, CFrame.fromMatrix((a + b) / 2, x, z:Cross(x)))
	return p
end

-- what you actually see of the head: R6 draws its 2x1x1 head part with a
-- head mesh ~1.2 studs across; R15 heads are their own size
local function visibleHead(head)
	if head:IsA("MeshPart") or not head:FindFirstChildOfClass("SpecialMesh") then
		return head.Size
	end
	local v = head.Size.Y * 1.2
	return Vector3.new(v, v, v)
end

local function addMask(gear, head, fused)
	local v = visibleHead(head)
	local material = fused and Enum.Material.SmoothPlastic or Enum.Material.Leather
	-- the muzzle over nose, mouth and chin
	local muzzle = ellipsoid(gear, Vector3.new(v.X * 0.96, v.Y * 0.52, v.Z * 0.62), fused and FUSED_MASK or MASK_BLACK, material)
	weld(head, muzzle, CFrame.new(0, -v.Y * 0.2, -v.Z * 0.26))
	-- the beak: tapering, curving down (grown into flesh once he's fused)
	local beakColor = fused and FUSED_MASK or MASK_BLACK
	local segs = {
		{ size = Vector3.new(0.36, 0.32, 0.5), pos = Vector3.new(0, -0.19, -0.6), pitch = -8 },
		{ size = Vector3.new(0.27, 0.24, 0.46), pos = Vector3.new(0, -0.24, -0.9), pitch = -16 },
		{ size = Vector3.new(0.17, 0.15, 0.4), pos = Vector3.new(0, -0.32, -1.14), pitch = -26 },
	}
	local grow = fused and 1.3 or 1
	for _, sg in segs do
		local b = ellipsoid(gear, sg.size * v * grow, beakColor, material)
		weld(head, b, CFrame.new(sg.pos.X * v.X, sg.pos.Y * v.Y, sg.pos.Z * v.Z * grow) * CFrame.Angles(math.rad(sg.pitch), 0, 0))
	end
	-- breathing filters on either cheek
	for _, side in { 1, -1 } do
		local filter = gearPart(gear, Vector3.new(v.X * 0.06, v.Y * 0.2, v.Y * 0.2), Color3.fromRGB(150, 146, 156), Enum.Material.Metal, Enum.PartType.Cylinder)
		weld(head, filter, CFrame.new(side * v.X * 0.47, -v.Y * 0.2, -v.Z * 0.2))
	end
	-- the strap round the back of the head (a thin disc: only its rim shows)
	local strap = gearPart(gear, Vector3.new(v.Y * 0.07, v.X * 1.04, v.Z * 1.04), Color3.fromRGB(20, 18, 24), Enum.Material.Leather, Enum.PartType.Cylinder)
	weld(head, strap, CFrame.new(0, -v.Y * 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)))
	if fused then
		-- the gold stripe down the beak of the mask he's fused into his face
		local stripe = ellipsoid(gear, Vector3.new(v.X * 0.1, v.Y * 0.06, v.Z * 0.95), GOLD, Enum.Material.Metal)
		weld(head, stripe, CFrame.new(0, -v.Y * 0.05, -v.Z * 0.82) * CFrame.Angles(math.rad(-14), 0, 0))
		for i = 0, 3 do
			local stud = ellipsoid(gear, Vector3.one * v.X * 0.07, GOLD, Enum.Material.Metal)
			weld(head, stud, CFrame.new(0, -v.Y * (0.06 + i * 0.08), -v.Z * (0.66 + i * 0.1)))
		end
	end
end

-- the fur collar of his coat
local function addCollar(gear, torso)
	local ts = torso.Size
	local count = 16
	for i = 1, count do
		local a = i / count * math.pi * 2
		local tuft = ellipsoid(gear, Vector3.new(ts.X * 0.24, ts.Y * 0.16, ts.X * 0.24), Color3.fromRGB(122 + (i % 3) * 8, 70 + (i % 2) * 8, 166), Enum.Material.Fabric)
		weld(torso, tuft, CFrame.new(math.cos(a) * ts.X * 0.44, ts.Y * 0.47 + (i % 2) * ts.Y * 0.03, math.sin(a) * ts.Z * 0.62))
	end
end

-- gloves (or, gloves off, bare hands crackling red)
local function addHands(gear, char, bare, cos)
	for _, names in { { "RightHand", "Right Arm" }, { "LeftHand", "Left Arm" } } do
		local hand = findLimb(char, names[1], names[2])
		if hand then
			local r15 = hand.Name == names[1]
			local gloveLen = r15 and hand.Size.Y or hand.Size.Y * 0.3
			local gloveY = r15 and 0 or -hand.Size.Y / 2 + gloveLen / 2
			if not bare then
				local glove = gearPart(cos or gear, Vector3.new(hand.Size.X * 1.06, gloveLen * 1.02, hand.Size.Z * 1.06), Color3.fromRGB(26, 24, 30), Enum.Material.Leather)
				weld(hand, glove, CFrame.new(0, gloveY, 0))
				local cuff = gearPart(cos or gear, Vector3.new(hand.Size.X * 1.14, gloveLen * 0.18, hand.Size.Z * 1.14), Color3.fromRGB(46, 42, 54), Enum.Material.Leather)
				weld(hand, cuff, CFrame.new(0, gloveY + gloveLen * 0.45, 0))
			end
			local h = gearPart(gear, Vector3.one * 0.3, Color3.new(), nil, nil)
			h.Transparency = 1
			weld(hand, h, CFrame.new(0, -hand.Size.Y / 2, 0))
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(Color3.fromRGB(255, 130, 140), Color3.fromRGB(200, 20, 40))
			pe.LightEmission = 1
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, bare and 0.45 or 0.25), NumberSequenceKeypoint.new(1, 0) })
			pe.Speed = NumberRange.new(1, 3)
			pe.Lifetime = NumberRange.new(0.2, 0.4)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Rate = bare and 16 or 3
			pe.Parent = h
		end
	end
end

-- one of the fused form's extra arms (the anime's look, fused with Nemoto):
-- out of his back behind the shoulder, thicker than his own, built of dark
-- brown rock plates with black cracks between them; a big hand of hooked
-- black claws at his thigh, and tatters of Nemoto's cape flying off it
local function addFusedArm(gear, torso, side)
	local ts = torso.Size
	local k = ts.X / 2
	local rng = Random.new(side == 1 and 71 or 93)
	local BROWN = { Color3.fromRGB(92, 50, 44), Color3.fromRGB(78, 42, 38), Color3.fromRGB(104, 58, 50) }
	local shoulder = Vector3.new(side * 0.72, 0.72, 0.5) * k
	local elbow = Vector3.new(side * 2.3, 0.3, 0.8) * k
	local wrist = Vector3.new(side * 2.55, -1.55, 0.2) * k
	-- a knot of rock where it grows out of his back
	local knot = ellipsoid(gear, Vector3.new(1.3, 1.1, 1) * k, FUSED_DARK, Enum.Material.Slate)
	weld(torso, knot, CFrame.new(shoulder))
	-- a bone: a dark core, rock plates round it at random turns
	local function bone(a, b, thick)
		local core = rod(gear, torso, a, b, thick, CLAW_BLACK, Enum.Material.Slate)
		core.Name = "FusedArm"
		local d = b - a
		local len = d.Magnitude
		local x = d.Unit
		local ref = math.abs(x.Y) < 0.95 and UP or Vector3.new(1, 0, 0)
		local z0 = x:Cross(ref).Unit
		local y0 = z0:Cross(x)
		for i = 1, 3 do
			for j = 1, 2 do
				local t = (i - 0.5) / 3 + rng:NextNumber(-0.04, 0.04)
				local ang = (j / 2 + i * 0.29) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local out = y0 * math.cos(ang) + z0 * math.sin(ang)
				local pos = a + d * t + out * thick * 0.4
				local chunk = gearPart(gear, Vector3.new(len / 3 * rng:NextNumber(0.85, 1.05), thick * 0.5, thick * rng:NextNumber(0.62, 0.78)), BROWN[rng:NextInteger(1, 3)], Enum.Material.Slate)
				weld(torso, chunk, CFrame.fromMatrix(pos, x, out) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, 0))
			end
		end
	end
	bone(shoulder, elbow, 0.98 * k)
	local joint = ellipsoid(gear, Vector3.one * 1.08 * k, FUSED_DARK, Enum.Material.Slate)
	weld(torso, joint, CFrame.new(elbow))
	bone(elbow, wrist, 0.9 * k)
	-- the hand: a broad palm, four fingers hooking into black claws, a thumb
	local down = (wrist - elbow).Unit
	local inward = Vector3.new(-side, 0, 0)
	local across = down:Cross(inward).Unit
	local palmAt = wrist + down * 0.45 * k
	local palm = ellipsoid(gear, Vector3.new(1.4, 1.1, 0.72) * k, BROWN[1], Enum.Material.Slate)
	weld(torso, palm, CFrame.fromMatrix(palmAt, across, -down))
	for f = -1.5, 1.5 do
		local base = palmAt + down * 0.48 * k + across * f * 0.32 * k
		local knuckle = base + (down + inward * 0.25 + across * f * 0.08).Unit * 0.62 * k
		local hook = knuckle + (down * 0.5 + inward * 0.8).Unit * 0.44 * k
		rod(gear, torso, base, knuckle, 0.3 * k, BROWN[2], Enum.Material.Slate)
		local claw = rod(gear, torso, knuckle, hook, 0.2 * k, CLAW_BLACK, Enum.Material.SmoothPlastic)
		claw.Name = "FusedClaw"
		local point = ellipsoid(gear, Vector3.new(0.12, 0.3, 0.12) * k, CLAW_BLACK, Enum.Material.SmoothPlastic)
		weld(torso, point, CFrame.lookAt(hook, hook + (inward - down * 0.2)) * CFrame.Angles(math.rad(90), 0, 0))
	end
	local thumbBase = palmAt + inward * 0.35 * k - down * 0.05 * k
	local thumbTip = thumbBase + (down * 0.6 + inward * 0.6 + Vector3.new(0, 0, -0.3)).Unit * 0.55 * k
	rod(gear, torso, thumbBase, thumbTip, 0.24 * k, BROWN[3], Enum.Material.Slate)
	-- Nemoto's cape, torn to tatters, flying off behind the shoulder
	for i = 1, 3 do
		local at = shoulder:Lerp(elbow, 0.1 + i * 0.22) + Vector3.new(0, 0.2 * k, 0.4 * k)
		local strip = gearPart(gear, Vector3.new(0.05 * k, (0.9 + (i % 2) * 0.5) * k, 0.34 * k), CAPE_BLACK, Enum.Material.Fabric)
		weld(torso, strip, CFrame.new(at) * CFrame.Angles(math.rad(-40 - i * 10), math.rad(side * 20), math.rad(side * (30 + i * 16))) * CFrame.new(0, strip.Size.Y / 2, 0))
	end
end

-- his own arms, fused: salmon-pink plates cut apart by black cracks, from
-- shoulder to fingertips, and hooked claws on his fingers
local function addFusedSkin(gear, char)
	local rng = Random.new(157)
	local PINKS = { Color3.fromRGB(228, 126, 122), Color3.fromRGB(216, 112, 110), Color3.fromRGB(236, 140, 134) }
	for _, names in { { "RightUpperArm", "Right Arm" }, { "LeftUpperArm", "Left Arm" }, { "RightLowerArm" }, { "LeftLowerArm" }, { "RightHand" }, { "LeftHand" } } do
		local limb = findLimb(char, names[1], names[2] or names[1])
		if limb then
			local sz = limb.Size
			-- the black between the plates
			local sleeve = gearPart(gear, sz * 1.02, CLAW_BLACK, Enum.Material.SmoothPlastic)
			sleeve.Name = "FusedSkin"
			weld(limb, sleeve, CFrame.new())
			-- each face: two columns of plates, rows down the arm
			local rows = math.max(1, math.floor(sz.Y / 0.62 + 0.5))
			-- (the three faces you see: front, back and the outside)
			local outside = Vector3.new(string.find(limb.Name, "Left") and -1 or 1, 0, 0)
			for _, face in { { Vector3.new(0, 0, -1), sz.X }, { Vector3.new(0, 0, 1), sz.X }, { outside, sz.Z } } do
				local n, w = face[1], face[2]
				local across = n:Cross(UP)
				local depth = math.abs(n.X) > 0 and sz.X or sz.Z
				for row = 1, rows do
					for col = -1, 1, 2 do
						local cw, ch = w / 2, sz.Y / rows
						local pos = n * (depth / 2 + 0.03) + across * col * cw / 2 + UP * (sz.Y / 2 - ch * (row - 0.5))
						pos += across * rng:NextNumber(-0.02, 0.02) + UP * rng:NextNumber(-0.03, 0.03)
						local plate = gearPart(gear, Vector3.new(cw * rng:NextNumber(0.84, 0.94), ch * rng:NextNumber(0.82, 0.92), 0.06), PINKS[rng:NextInteger(1, 3)], Enum.Material.Slate)
						plate.Name = "FusedSkin"
						weld(limb, plate, CFrame.fromMatrix(pos, across, UP) * CFrame.Angles(0, 0, rng:NextNumber(-0.18, 0.18)))
					end
				end
			end
			-- hooked claws off the fingertips
			if limb.Name == "Right Arm" or limb.Name == "Left Arm" or names[1] == "RightHand" or names[1] == "LeftHand" then
				for i = -1, 1 do
					local base = Vector3.new(i * sz.X * 0.3, -sz.Y / 2 + 0.05, -sz.Z * 0.3)
					local claw = rod(gear, limb, base, base + Vector3.new(0, -0.32, -0.16), 0.13, CLAW_BLACK)
					claw.Name = "FusedClaw"
				end
			end
		end
	end
end

local function addOverhaulGear(gear, char, fused, cos)
	local head = char:FindFirstChild("Head")
	if head then
		addMask(cos or gear, head, fused)
	end
	local torso = findLimb(char, "UpperTorso", "Torso")
	if torso then
		addCollar(cos or gear, torso)
	end
	addHands(gear, char, fused, cos)
	if not fused or not torso then
		return
	end
	addFusedSkin(gear, char)
	for _, side in { 1, -1 } do
		addFusedArm(gear, torso, side)
	end
	local holder = gearPart(gear, Vector3.one * 0.2, Color3.new(), nil, nil)
	holder.Transparency = 1
	weld(torso, holder, CFrame.new())
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 80)
	light.Range = 12
	light.Brightness = 1.6
	light.Parent = holder
end

-- Ult aura: coloured outline, rising particles, and per-quirk extras
---------------------------------------------------------------------------
-- CRAZY DIAMOND (dev character): Josuke Higashikata's Stand. It punches
-- through anything, and puts things back together: RESTORE fixes whatever's
-- broken (the pieces fly home, through whoever is in the way), and BUILD
-- turns the rubble into something new - a wall, stairs, a pillar, a bridge
-- or a dome (V picks which) - or, with YO ANGELO, a rock with someone
-- sealed inside it.
---------------------------------------------------------------------------
do
	local CDS = { structures = {} } -- (helpers, packed: this script is near Luau's local limit)
	local CD_CONFIG = Config.Quirks.CrazyDiamond or {}
	local BLUEPRINTS = CD_CONFIG.Blueprints or { "Wall", "Stairs", "Pillar", "Bridge", "Dome" }
	local SHAPES = {}

	function CDS.folder()
		local map = workspace:FindFirstChild("Map")
		if not map then
			map = Instance.new("Folder")
			map.Name = "Map"
			map.Parent = workspace
		end
		local f = map:FindFirstChild("CrazyBuilt")
		if not f then
			f = Instance.new("Folder")
			f.Name = "CrazyBuilt"
			f.Parent = map
		end
		return f
	end

	-- Each shape is a list of { CFrame, Size } blocks, bottom first (that's the
	-- order they fly in). A little jitter so it reads as rubble put together.
	local function jitter(cf, amount)
		local a = math.rad(amount or 2.5)
		return cf * CFrame.Angles(math.random() * a * 2 - a, math.random() * a * 2 - a, math.random() * a * 2 - a)
	end

	-- a wall across the aim line: stops people and shots, and whoever it comes
	-- up under is thrown clear
	function SHAPES.Wall(site, d, s)
		local blocks = {}
		local W, H, T, cols, rows = 24 * s, 12 * s, 3 * s, 8, 4
		local base = CFrame.lookAt(site, site + d)
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				local cf = base * CFrame.new((col + 0.5) * W / cols - W / 2, (row + 0.5) * H / rows, 0)
				table.insert(blocks, { jitter(cf), Vector3.new(W / cols + 0.2, H / rows + 0.1, T) })
			end
		end
		return blocks, { Box = base * CFrame.new(0, H / 2, 0), Size = Vector3.new(W, H, T + 3) }
	end

	-- a staircase from your feet up toward the aim (10 steps, two stones each)
	function SHAPES.Stairs(_, d, s, feet)
		local blocks = {}
		local depth, rise, width = 3 * s, 1.8 * s, 8 * s
		local start = feet + d * 3
		local base = CFrame.lookAt(start, start + d)
		for i = 0, 9 do
			local h = (i + 1) * rise
			for side = -1, 1, 2 do
				local cf = base * CFrame.new(side * width / 4, h / 2, -(i * depth + depth / 2))
				table.insert(blocks, { cf, Vector3.new(width / 2 + 0.1, h, depth + 0.1) })
			end
		end
		return blocks
	end

	-- a column that erupts under the aim point and launches whoever's on it
	function SHAPES.Pillar(site, d, s)
		local blocks = {}
		local w, h = 3.5 * s, 3.25 * s
		local base = CFrame.lookAt(site, site + d)
		for layer = 0, 7 do
			for ix = -1, 1, 2 do
				for iz = -1, 1, 2 do
					table.insert(blocks, { jitter(base * CFrame.new(ix * w / 2, (layer + 0.5) * h, iz * w / 2), 1.5), Vector3.new(w + 0.1, h + 0.05, w + 0.1) })
				end
			end
		end
		return blocks, { Box = base * CFrame.new(0, 4, 0), Size = Vector3.new(2 * w + 2, 8, 2 * w + 2) }
	end

	-- a walkway (with low rails) from your feet to the aim point: across a gap,
	-- up onto a roof
	function SHAPES.Bridge(site, d, s, feet)
		local blocks = {}
		local a = feet + d * 2
		local flat = Vector3.new(site.X - a.X, 0, site.Z - a.Z)
		if flat.Magnitude < 12 then
			site = Vector3.new(a.X, site.Y, a.Z) + d * 12
			flat = d * 12
		end
		-- no steeper than 35 degrees
		local maxRise = flat.Magnitude * math.tan(math.rad(35))
		local b = Vector3.new(site.X, a.Y + math.clamp(site.Y - a.Y, -maxRise, maxRise), site.Z)
		local len = (b - a).Magnitude
		local seg = 4 * s
		local count = math.clamp(math.ceil(len / seg), 3, 18)
		local width = 7 * s
		local line = CFrame.lookAt(a, b)
		for i = 0, count - 1 do
			local cf = line * CFrame.new(0, -0.45 * s, -(i + 0.5) * len / count)
			table.insert(blocks, { cf, Vector3.new(width, 0.9 * s, len / count + 0.15) })
			for side = -1, 1, 2 do
				table.insert(blocks, { cf * CFrame.new(side * (width / 2 - 0.25 * s), 1.05 * s, 0), Vector3.new(0.5 * s, 1.2 * s, len / count + 0.1) })
			end
		end
		return blocks
	end

	-- (round 65) THE DOME, rebuilt as real masonry: a round drum of coursed
	-- stone (a heavy plinth course at the foot, stones of every width laid
	-- in running bond, joints never over joints), a cornice ring where the
	-- dome springs, then the dome itself - courses leaning in, each one
	-- smaller, every stone turned to lie on the curve - closed by an
	-- octagonal capstone with Crazy Diamond's diamond on top. A proper arched
	-- doorway faces the aim: jambs, a ring of voussoirs, a keystone.
	-- (Blocks are listed bottom first: that's the order they fly in.)
	function SHAPES.Dome(_, d, s, feet)
		local blocks = {}
		local R, T = 10 * s, 2.2 * s -- radius to the wall's middle, wall thickness
		local doorW, jambH, archR = 4.1 * s, 3.4 * s, 2.05 * s -- clear opening
		local jambW, voussoir = 1.1 * s, 0.9 * s
		local plinthH, courseH, courses = 0.9 * s, 1.35 * s, 4 -- (the arch's crown meets the cornice)
		local drumTop = plinthH + courseH * courses
		local corniceH = 0.6 * s
		local spring = drumTop + corniceH -- where the dome starts
		local Rv = 0.8 * R -- (a touch lower than a half-sphere)
		local doorAngle = math.atan2(d.Z, d.X)
		local UPV = Vector3.new(0, 1, 0)
		local function around(angle)
			return Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		-- the doorway's half-width at height y: the opening (straight sides,
		-- then the arch), and the outside of the arch's ring of stones
		local function opening(y)
			if y < jambH then
				return doorW / 2
			end
			local up = y - jambH
			return up < archR and math.sqrt(archR * archR - up * up) or 0
		end
		local function extrados(y)
			local up = y - jambH
			local outer = archR + voussoir
			if y < jambH then
				return doorW / 2 + jambW
			end
			return up < outer and math.sqrt(outer * outer - up * up) or 0
		end
		-- one course of stones round the ring between angles a0 and a1, each a
		-- random width (then scaled to fit exactly)
		local function course(y, h, radius, thick, a0, a1, target, tilt, depthOut)
			local span = a1 - a0
			local arc = span * radius
			local widths, total = {}, 0
			while total < arc - 0.01 do
				local w = target * (0.84 + math.random() * 0.32)
				table.insert(widths, w)
				total += w
			end
			local scale = arc / total
			local a = a0
			for _, w in widths do
				local da = w * scale / radius
				local mid = a + da / 2
				local out = around(mid)
				local pos = feet + out * (radius + (depthOut or 0)) + UPV * (y + h / 2)
				-- (facing in, turned by tilt to lie on the curve; built from its axes)
				local t = tilt or 0
				local cf = CFrame.fromMatrix(pos, (-out):Cross(UPV), UPV * math.cos(t) + out * math.sin(t))
				-- (Crazy Diamond puts things back perfectly: only the slightest play)
				cf = cf * CFrame.Angles(math.rad(math.random() - 0.5), math.rad(math.random() - 0.5), math.rad(math.random() - 0.5))
				table.insert(blocks, { cf, Vector3.new(2 * radius * math.sin(da / 2) + 0.12 * s, h + 0.08 * s, thick * (0.96 + math.random() * 0.06)) })
				a += da
			end
		end
		-- a full ring, or the ring with the doorway left out: a course never
		-- reaches into the opening (it stops just clear of it at the course's
		-- foot), and where the arch curves away above that, a filler stone
		-- closes the gap to the voussoirs (they're thicker: they hide the seams)
		local dd = around(doorAngle)
		local across = Vector3.new(-dd.Z, 0, dd.X)
		local function ring(y, h, radius, thick, target, offset, depthOut, whole)
			local y1 = y + h
			if whole or y >= jambH + archR + voussoir then
				local a0 = doorAngle + (offset or 0)
				course(y, h, radius, thick, a0, a0 + 2 * math.pi, target, 0, depthOut)
				return
			end
			local cutX = (y < jambH and doorW / 2 + jambW * 0.5 or opening(y) + 0.15 * s)
			local half = math.asin(math.clamp(cutX / radius, 0, 0.99))
			course(y, h, radius, thick, doorAngle + half, doorAngle + 2 * math.pi - half, target, 0, depthOut)
			local ext = extrados(y1)
			if y1 > jambH and cutX > ext + 0.05 * s then
				local outer = archR + voussoir
				local yLow = math.max(y, jambH + math.sqrt(math.max(outer * outer - cutX * cutX, 0)))
				if y1 - yLow > 0.05 * s then
					for side = -1, 1, 2 do
						local pos = feet + dd * (radius + (depthOut or 0)) + across * (side * (ext + cutX) / 2) + UPV * ((yLow + y1) / 2)
						table.insert(blocks, { CFrame.fromMatrix(pos, across, UPV), Vector3.new(cutX - ext + 0.1 * s, y1 - yLow + 0.06 * s, thick * 0.97) })
					end
				end
			end
		end
		-- the plinth (a heavier course, a little proud), then the drum in
		-- running bond (each course starts half a stone round from the last)
		ring(0, plinthH, R + 0.15 * s, T + 0.6 * s, 3.8 * s, 0, 0)
		for c = 0, courses - 1 do
			ring(plinthH + c * courseH, courseH, R, T, 3.3 * s, (c % 2) * 0.17, 0)
		end
		-- the doorway: two jambs, a ring of voussoirs, the keystone
		local face = feet + dd * R
		for side = -1, 1, 2 do
			local x = side * (doorW / 2 + jambW / 2)
			for k = 0, 1 do
				local h = jambH / 2
				local pos = face + across * x + UPV * (k * h + h / 2)
				table.insert(blocks, { CFrame.fromMatrix(pos, across, UPV), Vector3.new(jambW, h + 0.05 * s, T + 0.5 * s) })
			end
		end
		local centre = face + UPV * jambH
		local stones = 7
		for i = 0, stones - 1 do
			local a = (i + 0.5) / stones * math.pi
			local mid = archR + voussoir / 2
			local pos = centre + across * (math.cos(a) * mid) + UPV * (math.sin(a) * mid)
			local key = i == (stones - 1) / 2
			local len = 2 * mid * math.sin(math.pi / stones / 2) + 0.1 * s
			-- (each voussoir points at the arch's centre; the keystone stands proud)
			local cf = CFrame.fromMatrix(pos, across * -math.sin(a) + UPV * math.cos(a), across * math.cos(a) + UPV * math.sin(a))
			table.insert(blocks, { cf, Vector3.new(len * (key and 1.25 or 1), voussoir * (key and 1.3 or 1), T + (key and 0.9 or 0.55) * s) })
		end
		-- the cornice: a ring that stands out where the dome begins
		-- (whole: the arch tucks up under it, the keystone standing through)
		ring(drumTop, corniceH, R + 0.35 * s, T + 0.7 * s, 3.6 * s, 0.09, 0, true)
		-- the dome: courses on the curve (an ellipse R across, Rv high), every
		-- stone tipped to lie on it, fewer and smaller toward the top
		local domeCourses = 7
		local topAt = math.rad(78)
		for c = 0, domeCourses - 1 do
			local a0 = topAt * c / domeCourses
			local a1 = topAt * (c + 1) / domeCourses
			local am = (a0 + a1) / 2
			local radius = R * math.cos(am)
			local y = spring + Rv * math.sin(am)
			-- the curve's slope here: how far the stones lean in
			local lean = math.atan2(Rv * math.cos(am), R * math.sin(am))
			local h = math.sqrt((R * (math.cos(a0) - math.cos(a1))) ^ 2 + (Rv * (math.sin(a1) - math.sin(a0))) ^ 2)
			local a = doorAngle + (c % 2) * 0.13
			course(y - h / 2, h, radius, T * (0.8 - c * 0.04), a, a + 2 * math.pi, math.max(3.1 * s * math.cos(am) ^ 0.5, 1.7 * s), -(math.pi / 2 - lean))
		end
		-- the capstone (two squares at 45 degrees: an octagon) and the diamond
		local capY = spring + Rv * math.sin(topAt) + 0.35 * s
		local capR = R * math.cos(topAt) + 0.7 * s
		for k = 0, 1 do
			table.insert(blocks, { CFrame.new(feet + UPV * (capY + k * 0.15 * s)) * CFrame.Angles(0, doorAngle + k * math.pi / 4, 0), Vector3.new(capR * 1.75, 0.9 * s, capR * 1.75) })
		end
		table.insert(blocks, {
			CFrame.new(feet + UPV * (capY + 1.45 * s)) * CFrame.Angles(0, doorAngle + math.pi / 4, 0) * CFrame.Angles(-math.atan(1 / math.sqrt(2)), 0, math.pi / 4),
			Vector3.new(1.3, 1.3, 1.3) * s,
			{ Color = Color3.fromRGB(236, 132, 196), Material = Enum.Material.Glass },
		})
		return blocks, { Center = feet, Radius = R }
	end

	-- YO ANGELO: a rough rock closed round someone (they're sealed inside)
	function SHAPES.Prison(at)
		local blocks = {}
		for layer, spec in { { -2.3, 2.4, 7 }, { -0.7, 2.9, 8 }, { 0.9, 2.9, 8 }, { 2.5, 2.3, 7 } } do
			local y, r, n = spec[1], spec[2], spec[3]
			for k = 0, n - 1 do
				local ang = (k + (layer % 2) * 0.5) / n * math.pi * 2
				local pos = at + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)
				local cf = CFrame.lookAt(pos, at + Vector3.new(0, y, 0)) * CFrame.Angles(math.rad(math.random(-12, 12)), 0, math.rad(math.random(-12, 12)))
				table.insert(blocks, { cf, Vector3.new(2.9, 1.9, 1.5) * (0.9 + math.random() * 0.25) })
			end
		end
		table.insert(blocks, { CFrame.new(at + Vector3.new(0, 3.9, 0)) * CFrame.Angles(0, math.random() * 6, 0), Vector3.new(4, 1.6, 4) })
		table.insert(blocks, { CFrame.new(at + Vector3.new(0, -3.6, 0)), Vector3.new(5, 1.4, 5) })
		return blocks
	end

	-- What it's made of: rubble lying around, the holes in buildings nearby -
	-- and if there isn't enough, Crazy Diamond knocks a chunk off the nearest
	-- building. On an open street it's the pavement.
	function CDS.rubble(site, want, char)
		local src = Destruction.Rubble and Destruction.Rubble(site, 90, want) or {}
		if #src < math.ceil(want / 3) and Destruction.NearestBreakable then
			local part, point = Destruction.NearestBreakable(site, 70)
			if part then
				Destruction.Sphere(point, math.clamp(4 + want * 0.06, 4, 9), "Stand", (point - site).Magnitude > 0.1 and (point - site).Unit or UP)
				for _, extra in Destruction.Rubble(site, 90, want - #src) do
					table.insert(src, extra)
				end
			end
		end
		if #src == 0 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = nonMapStuff(char)
			local hit = workspace:Raycast(site + UP * 4, Vector3.new(0, -20, 0), params)
			local inst = hit and hit.Instance
			local color = inst and inst:IsA("BasePart") and inst.Color or Color3.fromRGB(120, 116, 112)
			local material = inst and inst:IsA("BasePart") and inst.Material or Enum.Material.Concrete
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				table.insert(src, { Position = site + Vector3.new(math.cos(a) * 9, 0.5, math.sin(a) * 9), Size = Vector3.one * 2, Color = color, Material = material })
			end
		end
		return src
	end

	-- Crumble a structure into loose rubble (its time is up)
	function CDS.crumble(rec)
		if rec.Gone then
			return
		end
		rec.Gone = true
		local list = CDS.structures[rec.Owner]
		if list then
			local i = table.find(list, rec)
			if i then
				table.remove(list, i)
			end
		end
		local debris = workspace:FindFirstChild("MapDebris")
		for _, p in rec.Parts do
			if p.Parent == rec.Model then
				p:SetAttribute("Destroyable", nil)
				p.Anchored = false
				p.CanCollide = true
				p.Transparency = 0
				p.CollisionGroup = "Debris"
				p.Parent = debris or workspace
				p.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(2, 12), math.random(-8, 8))
				Debris:AddItem(p, 3 + math.random())
			end
		end
		rec.Model:Destroy()
	end

	-- Take a structure apart: every stone flies back to the rubble it came from
	function CDS.dismantle(rec, flights)
		if rec.Gone then
			return
		end
		rec.Gone = true
		local list = CDS.structures[rec.Owner]
		if list then
			local i = table.find(list, rec)
			if i then
				table.remove(list, i)
			end
		end
		for i, p in rec.Parts do
			if p.Parent == rec.Model and p.Transparency < 1 and #flights < 160 then
				table.insert(flights, { From = p.Position, To = rec.Sources[i], Size = p.Size, Color = p.Color, Material = p.Material })
			end
		end
		rec.Model:Destroy()
	end

	-- Build: the stones are made (invisible, not solid) and appear one by one,
	-- bottom first, as their piece of rubble flies in on everyone's screen
	function CDS.build(player, char, kind, blocks, sources, lifetime, limit)
		local model = Instance.new("Model")
		model.Name = player.Name .. "'s " .. kind
		model.Parent = CDS.folder()
		local rec = { Owner = player, Model = model, Parts = {}, Sources = {}, Kind = kind }
		local flights = {}
		-- (a big one - the dome - goes up course by course, over a second)
		local spread = 0.45 * math.min(1, #blocks / 30) + math.clamp((#blocks - 60) / 300, 0, 0.5)
		for i, b in blocks do
			local src = sources[(i - 1) % #sources + 1]
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.Transparency = 1
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = b[2]
			p.CFrame = b[1]
			local own = type(b[3]) == "table" and b[3] or {}
			p.Color = typeof(own.Color) == "Color3" and own.Color or src.Color
			p.Material = typeof(own.Material) == "EnumItem" and own.Material or src.Material
			p:SetAttribute("Destroyable", true)
			p:SetAttribute("CrazyBuilt", true)
			p.Parent = model
			rec.Parts[i] = p
			rec.Sources[i] = src.Position
			flights[i] = { From = src.Position, To = b[1], Size = b[2], Color = p.Color, Material = p.Material, Delay = 0.3 + (i - 1) / math.max(#blocks - 1, 1) * spread }
		end
		broadcast("CrazyBuilt", char, { Kind = kind, Blocks = flights })
		for i, p in rec.Parts do
			task.delay(flights[i].Delay, function()
				if p.Parent == model then
					p.Transparency = 0
					p.CanCollide = true
				end
			end)
		end
		CDS.structures[player] = CDS.structures[player] or {}
		local list = CDS.structures[player]
		table.insert(list, rec)
		-- (only so many standing at once: the oldest crumbles; rocks don't count)
		while limit do
			local built, oldest = 0, nil
			for _, other in list do
				if other.Kind ~= "Prison" then
					built += 1
					oldest = oldest or other
				end
			end
			if built <= limit or not oldest then
				break
			end
			CDS.crumble(oldest)
		end
		task.delay(lifetime or 45, function()
			CDS.crumble(rec)
		end)
		return rec, 0.3 + spread
	end

	-- Anyone standing inside something that just came back is put outside it
	-- (through the nearest side, not flung)
	function CDS.pushOut(parts, center, radius, char)
		for _, model in queryRadius(char, center, radius + 20) do
			local r = model:FindFirstChild("HumanoidRootPart")
			if r then
				for _, part in parts do
					local lp = part.CFrame:PointToObjectSpace(r.Position)
					local h = part.Size / 2
					if math.abs(lp.X) < h.X and math.abs(lp.Y) < h.Y and math.abs(lp.Z) < h.Z then
						local dx, dz = h.X - math.abs(lp.X), h.Z - math.abs(lp.Z)
						local out = dx < dz and Vector3.new((h.X + 2) * math.sign(lp.X + 1e-3), lp.Y, lp.Z)
							or Vector3.new(lp.X, lp.Y, (h.Z + 2) * math.sign(lp.Z + 1e-3))
						r.CFrame = CFrame.new(part.CFrame:PointToWorldSpace(out)) * r.CFrame.Rotation
						break
					end
				end
			end
		end
	end

	-- The pieces flying home hit whoever's in the way (each piece that passes
	-- within 4 studs counts, up to maxHits)
	function CDS.flightHits(player, char, flights, center, radius, perHit, maxHits)
		if #flights == 0 or (perHit or 0) <= 0 then
			return
		end
		task.delay(0.25, function()
			for _, model in queryRadius(char, center, radius + 10) do
				local r = model:FindFirstChild("HumanoidRootPart")
				local hits, push = 0, Vector3.zero
				for _, f in flights do
					local ab = f.To - f.From
					local t = ab.Magnitude > 0.01 and math.clamp((r.Position - f.From):Dot(ab) / ab:Dot(ab), 0, 1) or 0
					if (f.From + ab * t - r.Position).Magnitude <= 4 then
						hits += 1
						push += ab.Magnitude > 0.01 and ab.Unit or Vector3.zero
					end
				end
				hits = math.min(hits, maxHits or 4)
				if hits > 0 and damage(player, model, perHit * hits, { From = center }) then
					local flat = Vector3.new(push.X, 0, push.Z)
					knockback(model, (flat.Magnitude > 0.1 and flat.Unit or UP) * (30 + hits * 12) + UP * 25, 0.18)
					stun(model, 0.6 + hits * 0.15)
				end
			end
		end)
	end

	---------------------------------------------------------------------------
-- ALL MIGHT vs ALL FOR ONE in the sky (Config.SkyBattle): every few minutes
-- everyone's told to look up; each screen stages the fight over wherever
-- that player is. The test menu's switch turns it off; its button starts one.
---------------------------------------------------------------------------
do
	local cfg = Config.SkyBattle or {}
	local AB = { next = os.clock() + (cfg.First or 90) }
	Kit.AB = AB
	function AB.start()
		AB.next = os.clock() + math.max(cfg.Every or 300, (cfg.Length or 53) + 5)
		broadcast("SkyBattle", nil, { Seed = math.random(1, 100000), Length = cfg.Length or 53 })
	end
	if cfg.Enabled ~= false then
		RunService.Heartbeat:Connect(function()
			if os.clock() < AB.next then
				return
			end
			-- (off until someone switches it on in the test menu)
			if workspace:GetAttribute("SkyBattle") == true and #Players:GetPlayers() > 0 then
				AB.start()
			else
				AB.next = os.clock() + 30
			end
		end)
	end
end

---------------------------------------------------------------------------
-- DEKU DROPS IN (Config.DekuDrop): every few minutes Deku comes down out of
-- the sky into the middle of the city - a crater, the street thrown up,
-- anyone near blown off their feet (not hurt) - gets up, looks round, and
-- blasts back up into the sky. Every screen plays him; the server does the
-- craters at the moments he hits and leaves.
---------------------------------------------------------------------------
do
	local cfg = Config.DekuDrop or {}
	local DD = { next = os.clock() + (cfg.First or 150), running = false }
	Kit.DD = DD
	local function blow(center, radius, up)
		for _, plr in Players:GetPlayers() do
			local c = plr.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r and alive(c) then
				local off = r.Position - center
				if off.Magnitude < radius then
					local flat = Vector3.new(off.X, 0, off.Z)
					local out = flat.Magnitude > 0.5 and flat.Unit or Vector3.new(1, 0, 0)
					knockback(c, out * (cfg.Push or 70) * (1 - off.Magnitude / radius * 0.5) + UP * up, 0.25)
					ragdoll(c, 1)
				end
			end
		end
	end
	function DD.start()
		if DD.running then
			return
		end
		DD.running = true
		DD.next = os.clock() + math.max(cfg.Every or 300, (cfg.Length or 11) + 5)
		local spot = cfg.Spot or Vector3.new(-70, 26, 868)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(nil)
		local hit = workspace:Raycast(spot + UP * 60, Vector3.new(0, -160, 0), params)
		local ground = hit and hit.Position or spot
		broadcast("DekuDrop", nil, { Pos = ground, Seed = math.random(1, 100000), Impact = cfg.ImpactAt or 2.4, Jump = cfg.JumpAt or 7.4, Length = cfg.Length or 11 })
		task.delay(cfg.ImpactAt or 2.4, function()
			Destruction.Sphere(ground, cfg.Crater or 11, "Impact", -UP)
			Destruction.Sphere(ground + UP * 4, (cfg.Crater or 11) * 1.4, "Wind", UP)
			blow(ground, cfg.Radius or 28, 40)
		end)
		task.delay(cfg.JumpAt or 7.4, function()
			Destruction.Sphere(ground, (cfg.Crater or 11) * 0.8, "Impact", -UP)
			blow(ground, (cfg.Radius or 28) * 0.8, 70)
		end)
		task.delay(cfg.Length or 11, function()
			DD.running = false
		end)
	end
	if cfg.Enabled ~= false then
		RunService.Heartbeat:Connect(function()
			if os.clock() < DD.next then
				return
			end
			-- (off until someone switches it on in the test menu)
			if workspace:GetAttribute("DekuDrop") == true and #Players:GetPlayers() > 0 then
				DD.start()
			else
				DD.next = os.clock() + 30
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
		for _, rec in table.clone(CDS.structures[player] or {}) do
			CDS.crumble(rec)
		end
		CDS.structures[player] = nil
	end)

	-- 1: DORARARARA! The Stand's rush: a flurry in front of him that follows
	-- where he faces, smashing a hole deeper into whatever's there, then one
	-- last DORA! that sends them flying
	function Handlers.Dorarara(player, char, root, ability)
		local hits = ability.Hits or 14
		local range = ability.Range or 7
		local depth = ability.BreakDepth or 16
		local wide = ability.Rage and 10 or 7
		task.wait(0.15)
		for k = 1, hits do
			if not alive(char) then
				return
			end
			local d = flatten(root.CFrame.LookVector, root)
			local look = CFrame.lookAt(root.Position, root.Position + d)
			for _, model in Rewind.QueryBox(player, char, look * CFrame.new(0, 0.5, -(range / 2 + 1.5)), Vector3.new(wide + 1, 9, range)) do
				if damage(player, model, ability.Damage, { From = root.Position }) then
					knockback(model, d * 6, 0.08)
					stun(model, 0.45)
				end
			end
			if k % 3 == 0 then
				local reach = depth * k / hits
				Destruction.Box(look * CFrame.new(0, 1.5, -(2 + reach / 2)), Vector3.new(wide, 8, reach), "Stand", d)
			end
			task.wait(ability.Interval or 0.085)
		end
		if not alive(char) then
			return
		end
		local d = flatten(root.CFrame.LookVector, root)
		local look = CFrame.lookAt(root.Position, root.Position + d)
		for _, model in Rewind.QueryBox(player, char, look * CFrame.new(0, 0.5, -(range / 2 + 2)), Vector3.new(wide + 2, 10, range + 2)) do
			if damage(player, model, ability.FinisherDamage or 16, { From = root.Position, Heavy = true, Hitstop = 0.1 }) then
				knockback(model, d * (ability.Rage and 190 or 140) + UP * 40, 0.25)
				stun(model, 1.1)
				ragdoll(model, 1.2)
			end
		end
		Destruction.Sphere(root.Position + d * (depth * 0.6 + 2) + UP * 1.5, ability.Rage and 9 or 6, "Crater", d)
	end

	-- 2: BUILD what's on the blueprint (V) out of the rubble at the aim point
	function Handlers.CrazyBuild(player, char, root, ability, dir, pos)
		local kind = player:GetAttribute("Blueprint")
		if not SHAPES[kind] or kind == "Prison" then
			kind = BLUEPRINTS[1]
		end
		local s = ability.Scale or 1
		local d = flatten(dir, root)
		local site = groundTarget(root, pos, ability.Range or 60, char)
		local feet = groundBelow(root.Position, char)
		local blocks, zone = SHAPES[kind](site, d, s, feet)
		task.wait(0.2) -- (the Stand's fist hits the ground)
		if not alive(char) then
			return
		end
		local sources = CDS.rubble(site, math.min(#blocks, 60), char) -- (stones reuse the pieces)
		local _, doneIn = CDS.build(player, char, kind, blocks, sources, ability.Lifetime or 45, ability.MaxStructures or 6)
		if not zone then
			return
		end
		task.wait(doneIn)
		-- whoever it came up under
		if zone.Box then
			for _, model in queryBox(char, zone.Box, zone.Size) do
				if damage(player, model, ability.Damage, { From = site }) then
					local r = model:FindFirstChild("HumanoidRootPart")
					local side = r and (r.Position - site):Dot(d) >= 0 and 1 or -1
					local up = kind == "Pillar" and 110 or 45
					knockback(model, (kind == "Pillar" and Vector3.zero or d * side * 35) + UP * up, 0.2)
					stun(model, 0.9)
				end
			end
		elseif zone.Radius then
			-- the dome shoves anyone else out
			for _, model in queryRadius(char, zone.Center, zone.Radius) do
				if damage(player, model, ability.Damage * 0.5, { From = zone.Center }) then
					knockback(model, awayFrom(zone.Center, model, d) * 70 + UP * 20, 0.2)
					stun(model, 0.6)
				end
			end
		end
	end

	-- V: change what BUILD makes
	function Handlers.Blueprint(player)
		local i = table.find(BLUEPRINTS, player:GetAttribute("Blueprint") or BLUEPRINTS[1]) or 1
		player:SetAttribute("Blueprint", BLUEPRINTS[i % #BLUEPRINTS + 1])
	end

	-- 3: YO, ANGELO. The Stand pounds the street in front of whoever's there,
	-- the rubble climbs them, and they're sealed in the rock for a few seconds
	function Handlers.YoAngelo(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = firstInLine(char, root.Position, d, ability.Range or 30, 8)
		for _ = 1, 6 do
			task.wait(0.11)
			if not alive(char) then
				return
			end
			if target and alive(target) and damage(player, target, ability.TickDamage or 2, { From = root.Position }) then
				stun(target, 0.5)
			end
		end
		local troot = target and alive(target) and target:FindFirstChild("HumanoidRootPart")
		local at = troot and troot.Position or (groundTarget(root, pos, ability.Range or 30, char) + UP * 3)
		local blocks = SHAPES.Prison(at)
		local trap = ability.TrapTime or 3
		CDS.build(player, char, "Prison", blocks, CDS.rubble(at, #blocks, char), trap + 0.6)
		task.wait(0.55)
		if troot and troot.Parent and alive(target) and damage(player, target, ability.Damage, { From = root.Position, Heavy = true }) then
			stun(target, trap, 0)
			target:SetAttribute("Sealed", true)
			troot.Anchored = true
			task.delay(trap, function()
				if target.Parent then
					target:SetAttribute("Sealed", nil)
					if troot.Parent then
						troot.Anchored = false
					end
				end
			end)
		end
	end

	-- R: RESTORE. Everything broken around him goes back the way it was - the
	-- pieces fly home through whoever's in the way - and his own structures
	-- come apart back into the rubble they were made of.
	function CDS.restore(player, char, center, radius, perHit, maxHits, big)
		local flights = {}
		for _, list in CDS.structures do
			for _, rec in table.clone(list) do
				if rec.Kind ~= "Prison" and rec.Parts[1] and (rec.Parts[1].Position - center).Magnitude <= radius + 20 then
					CDS.dismantle(rec, flights)
				end
			end
		end
		local restored, back = {}, {}
		if Destruction.RestoreNear then
			restored, back = Destruction.RestoreNear(center, radius, big and 140 or 90)
		end
		for _, f in back do
			table.insert(flights, f)
		end
		CDS.pushOut(restored, center, radius, char)
		CDS.flightHits(player, char, flights, center, radius, perHit, maxHits)
		local shown = {}
		for i = 1, math.min(#restored, 60) do
			shown[i] = restored[i]
		end
		broadcast("Restored", char, { Center = center, Radius = radius, Flights = flights, Parts = shown, Big = big or nil })
		return #restored, #flights
	end

	function Handlers.CrazyRestore(player, char, root, ability)
		task.wait(0.25) -- (the Stand's open hands)
		if not alive(char) then
			return
		end
		CDS.restore(player, char, root.Position, ability.Radius or 80, ability.Damage or 7, ability.MaxHitsPerTarget or 4)
	end

	-- Ult 3: BREAK AND RESTORE. One punch to the street and everything around
	-- shatters and blows everyone away - then it all comes flying home at once.
	function Handlers.BreakRestore(player, char, root, ability)
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.5)
		task.wait(0.4)
		if not alive(char) then
			return
		end
		local radius = ability.Radius or 60
		local center = groundBelow(root.Position, char)
		for _, model in queryRadius(char, center, radius) do
			if damage(player, model, ability.Damage, { From = center, Heavy = true }) then
				knockback(model, awayFrom(center, model, UP) * 110 + UP * 60, 0.25)
				stun(model, 1.6)
				ragdoll(model, 1.2)
			end
		end
		Destruction.Sphere(center + UP * 3, radius * 0.75, "Shatter")
		task.wait(ability.Hold or 1.3)
		if not alive(char) then
			return
		end
		-- everything flying home sweeps the whole area
		for _, model in queryRadius(char, center, radius + 25) do
			if damage(player, model, ability.ReturnDamage or ability.Damage, { From = center, Heavy = true }) then
				local r = model:FindFirstChild("HumanoidRootPart")
				local inward = r and Vector3.new(center.X - r.Position.X, 0, center.Z - r.Position.Z) or Vector3.zero
				knockback(model, (inward.Magnitude > 0.1 and inward.Unit or UP) * 60 + UP * 45, 0.2)
				stun(model, 1.4)
			end
		end
		CDS.restore(player, char, center, radius + 10, 0, 0, true)
	end
end

-- LEMILLION, kept minimal: the red cape off his shoulders (a collar at the
-- back of the neck, clasps at the front) and the white visor with yellow
-- lenses pushed up on his forehead
function Kit.lemillionCostume(gear, char)
	local WHITE, YELLOW = Color3.fromRGB(244, 244, 240), Color3.fromRGB(255, 206, 40)
	local RED, DARK_RED = Color3.fromRGB(204, 32, 38), Color3.fromRGB(150, 20, 28)
	local torso = findLimb(char, "UpperTorso", "Torso")
	if torso then
		local ts = torso.Size
		-- the cape: a collar round the back of the neck, then two panels
		-- hanging off his shoulders and flaring out behind him
		local collar = gearPart(gear, Vector3.new(ts.X * 0.86, 0.3, 0.3), DARK_RED, Enum.Material.Fabric)
		collar.Name = "Cape"
		weld(torso, collar, CFrame.new(0, ts.Y / 2 + 0.06, ts.Z / 2 - 0.05))
		local upper = gearPart(gear, Vector3.new(ts.X * 1.08, ts.Y * 0.75, 0.08), RED, Enum.Material.Fabric)
		upper.Name = "Cape"
		weld(torso, upper, CFrame.new(0, ts.Y * 0.12, ts.Z / 2 + 0.1) * CFrame.Angles(math.rad(-6), 0, 0))
		local lower = gearPart(gear, Vector3.new(ts.X * 1.22, ts.Y * 0.95, 0.08), RED, Enum.Material.Fabric)
		lower.Name = "Cape"
		weld(torso, lower, CFrame.new(0, -ts.Y * 0.7, ts.Z / 2 + 0.36) * CFrame.Angles(math.rad(-14), 0, 0))
		for _, side in { 1, -1 } do
			local clasp = ellipsoid(gear, Vector3.new(0.3, 0.3, 0.2), YELLOW, Enum.Material.Metal)
			weld(torso, clasp, CFrame.new(side * ts.X * 0.34, ts.Y / 2 - 0.08, -(ts.Z / 2 + 0.02)))
			local strap = gearPart(gear, Vector3.new(0.22, 0.12, ts.Z + 0.1), RED, Enum.Material.Fabric)
			weld(torso, strap, CFrame.new(side * ts.X * 0.34, ts.Y / 2 + 0.02, 0))
		end
	end
	-- the visor, pushed up on his forehead
	local head = char:FindFirstChild("Head")
	if head then
		local v = visibleHead(head)
		local band = gearPart(gear, Vector3.new(v.Y * 0.16, v.X * 1.03, v.Z * 1.03), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		band.Name = "Visor"
		weld(head, band, CFrame.new(0, v.Y * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for _, side in { 1, -1 } do
			local lens = gearPart(gear, Vector3.new(v.X * 0.32, v.Y * 0.13, 0.06), YELLOW, Enum.Material.Glass)
			lens.Name = "Visor"
			lens.Transparency = 0.15
			weld(head, lens, CFrame.new(side * v.X * 0.18, v.Y * 0.3, -v.Z * 0.52))
		end
	end
end

-- SUNEATER, kept minimal: his utility belt (a dark strap, a buckle, pouches
-- all round), a fringe of dark indigo hair and his pointed ears. In the ult
-- (Vast Hybrid Chimera): shell plates over his shoulders and chest, and
-- tentacles curling off his back.
function Kit.suneaterCostume(gear, char, chimera, cos)
	local BEIGE = Color3.fromRGB(204, 184, 146)
	local HAIR = Color3.fromRGB(44, 38, 84)
	local head = char:FindFirstChild("Head")
	local SKIN = head and head.Color or Color3.fromRGB(236, 214, 196)
	local torso = findLimb(char, "UpperTorso", "Torso")
	if torso and chimera then
		local ts = torso.Size
		-- VAST HYBRID CHIMERA: clam and crab shell plates, tentacles off his back
		for _, side in { -1, 1 } do
			local shell = ellipsoid(gear, Vector3.new(ts.X * 0.62, 0.7, ts.Z * 1.6), Color3.fromRGB(226, 214, 196), Enum.Material.Slate)
			weld(torso, shell, CFrame.new(side * ts.X * 0.62, ts.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(side * -20)))
			for k = 1, 3 do
				local ridge = gearPart(gear, Vector3.new(0.08, 0.1, ts.Z * 1.5), Color3.fromRGB(150, 128, 110), Enum.Material.Slate)
				weld(torso, ridge, CFrame.new(side * ts.X * (0.44 + k * 0.1), ts.Y * 0.5 + 0.3 - k * 0.04, 0) * CFrame.Angles(0, 0, math.rad(side * -20)))
			end
		end
		local plate = gearPart(gear, Vector3.new(ts.X * 0.8, ts.Y * 0.5, 0.25), Color3.fromRGB(120, 60, 50), Enum.Material.Slate)
		weld(torso, plate, CFrame.new(0, ts.Y * 0.05, -(ts.Z / 2 + 0.28)))
		local TENT = Color3.fromRGB(150, 64, 110)
		for i = 1, 4 do
			local side = i <= 2 and -1 or 1
			local up = (i % 2 == 0) and 1 or -0.4
			local prev = Vector3.new(side * ts.X * 0.25, ts.Y * 0.15 + up * 0.3, ts.Z / 2 + 0.2)
			for k = 1, 5 do
				local curl = k / 5
				local nextP = prev + Vector3.new(side * 0.55, up * 0.45 + math.sin(curl * 3) * 0.3, 0.45 - curl * 0.2)
				rod(gear, torso, prev, nextP, 0.62 - curl * 0.42, TENT, Enum.Material.SmoothPlastic)
				prev = nextP
			end
		end
	end
	-- his utility belt: a dark strap round the waist, a metal buckle, and
	-- beige pouches with flaps - two at the front, one on each hip, two behind
	local waist = findLimb(char, "LowerTorso", "Torso")
	if waist then
		local look = cos or gear
		local ws = waist.Size
		local y = waist.Name == "Torso" and -ws.Y / 2 + 0.22 or ws.Y * 0.12
		local STRAP, METAL = Color3.fromRGB(52, 50, 58), Color3.fromRGB(176, 178, 186)
		local belt = gearPart(look, Vector3.new(ws.X + 0.12, 0.34, ws.Z + 0.12), STRAP, Enum.Material.Fabric)
		belt.Name = "Belt"
		weld(waist, belt, CFrame.new(0, y, 0))
		local buckle = gearPart(look, Vector3.new(0.44, 0.3, 0.08), METAL, Enum.Material.Metal)
		buckle.Name = "Buckle"
		weld(waist, buckle, CFrame.new(0, y, -(ws.Z / 2 + 0.1)))
		for _, at in {
			{ -ws.X * 0.3, -1, 0 }, { ws.X * 0.3, -1, 0 }, -- (front)
			{ -(ws.X / 2 + 0.13), 0, 90 }, { ws.X / 2 + 0.13, 0, -90 }, -- (hips)
			{ -ws.X * 0.26, 1, 180 }, { ws.X * 0.26, 1, 180 }, -- (back)
		} do
			local z = at[2] * (ws.Z / 2 + 0.14)
			local place = CFrame.new(at[1], y - 0.06, z) * CFrame.Angles(0, math.rad(at[3]), 0)
			local pouch = gearPart(look, Vector3.new(0.36, 0.4, 0.2), BEIGE, Enum.Material.Fabric)
			pouch.Name = "Pouch"
			weld(waist, pouch, place)
			local flap = gearPart(look, Vector3.new(0.38, 0.14, 0.22), BEIGE:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Fabric)
			flap.Name = "Pouch"
			weld(waist, flap, place * CFrame.new(0, 0.15, -0.02))
		end
	end
	if head then
		gear = cos or gear -- (his look: the fringe and the ears)
		local v = visibleHead(head)
		-- dark indigo bangs over his forehead
		for i = -2, 2 do
			local lock = gearPart(gear, Vector3.new(v.X * 0.13, v.Y * 0.24, 0.1), HAIR, Enum.Material.SmoothPlastic, Enum.PartType.Wedge)
			weld(head, lock, CFrame.new(i * v.X * 0.12, v.Y * 0.3 - math.abs(i) * v.Y * 0.03, -v.Z * 0.47 + math.abs(i) * v.Z * 0.04) * CFrame.Angles(math.rad(180), 0, math.rad(i * 8)))
		end
		-- pointed ears poking out at the sides
		for _, side in { -1, 1 } do
			local ear = gearPart(gear, Vector3.new(0.12, v.Y * 0.42, v.Z * 0.3), SKIN, Enum.Material.SmoothPlastic, Enum.PartType.Wedge)
			ear.Name = "Ear"
			weld(head, ear, CFrame.new(side * v.X * 0.56, v.Y * 0.06, 0) * CFrame.Angles(0, math.rad(side * 90), math.rad(side * -18)))
		end
	end
end

---------------------------------------------------------------------------
-- SIGNATURE LOOKS: one or two pieces per hero that say who they are, over
-- the player's own avatar - kept minimal on purpose. Bakugo's grenade
-- gauntlets, Todoroki's burn scar, Iida's glasses, All Might's two bangs,
-- Deku's red boots, the hand on Shigaraki's face, Gojo's blindfold.
-- (Lemillion's cape and visor, Suneater's belt and ears, Overhaul's mask
-- and Josuke's pompadour are built with their quirk's gear above.)
---------------------------------------------------------------------------
do
	-- a point on the front of the head, `lift` studs out along the surface:
	-- R6 heads draw as a round-sided block v across, rounded off top and bottom
	local function onHead(v, x, y, lift)
		local r = v.X / 2
		local over = math.max(0, math.abs(y) - v.Y * 0.2)
		local rr = math.sqrt(math.max(r * r - over * over, 0.0004))
		local z = -math.sqrt(math.max(rr * rr - x * x, 0.0004))
		local n = Vector3.new(x, math.sign(y) * over, z).Unit
		return Vector3.new(x, y, z) + n * (lift or 0), n
	end
	-- a flat blade (two wedges back to back): base at `a`, the point at `b`,
	-- `width` across, `thick` through, lying across `across`
	local function blade(gear, part0, a, b, width, thick, across, color, material)
		local d = b - a
		local len = d.Magnitude
		local up = d / len
		local z = across - up * across:Dot(up)
		z = z.Magnitude > 1e-3 and z.Unit or Vector3.new(0, 0, 1)
		local x = up:Cross(z)
		local base = CFrame.fromMatrix(a, x, up, z)
		for _, half in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(thick, len, width / 2)
			w.Color = color
			w.Material = material or Enum.Material.SmoothPlastic
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.Massless = true
			w.CastShadow = false
			w.Parent = gear
			local cf = base * CFrame.new(0, len / 2, half * width / 4)
			weld(part0, w, half == -1 and cf or cf * CFrame.Angles(0, math.pi, 0))
		end
	end

	-- BAKUGO: the Grenadier Bracers - a dark green pineapple grenade over each
	-- forearm (segments cut by black grooves), the silver fuze collar at the
	-- wrist his fist comes out of, the safety lever down the outside and the
	-- pin ring; green gloves with orange palms
	function Kit.grenadeBracers(gear, char)
		local GREEN = { Color3.fromRGB(48, 102, 62), Color3.fromRGB(42, 92, 56), Color3.fromRGB(54, 110, 68) }
		local GROOVE, SILVER = Color3.fromRGB(14, 26, 18), Color3.fromRGB(200, 202, 208)
		local STEEL, GLOVE, ORANGE = Color3.fromRGB(150, 152, 160), Color3.fromRGB(38, 80, 50), Color3.fromRGB(240, 116, 38)
		for _, spec in { { "RightLowerArm", "Right Arm", 1 }, { "LeftLowerArm", "Left Arm", -1 } } do
			local arm = findLimb(char, spec[1], spec[2])
			if arm then
				local side = spec[3]
				local s = arm.Size
				local r15 = arm.Name == spec[1]
				local R = math.max(s.X, s.Z) * 0.8 -- (past the corners of a blocky arm)
				local bottom = -s.Y / 2
				local collarH = s.Y * (r15 and 0.22 or 0.14)
				local collarY = bottom + s.Y * (r15 and 0.14 or 0.12) + collarH / 2
				local len = r15 and s.Y * 0.62 or s.Y * 0.44
				local mid = collarY + collarH / 2 + len / 2
				local function ring(h, dia, y, color, material)
					local p = gearPart(gear, Vector3.new(h, dia, dia), color, material or Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
					weld(arm, p, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)))
					return p
				end
				-- the grenade: a black core, and 4 rows x 7 raised segments round it,
				-- the end rows tucked in (its rounded ends)
				ring(len * 0.98, R * 1.84, mid, GROOVE)
				local rows, cols = 4, 7
				local profile = { 0.9, 1, 1, 0.92 }
				local h = len / rows
				for row = 1, rows do
					local rho = R * profile[row]
					local y = mid - len / 2 + h * (row - 0.5)
					local w = 2 * math.pi * rho / cols * 0.8
					for col = 1, cols do
						local a = (col - 0.5) / cols * math.pi * 2
						local seg = gearPart(gear, Vector3.new(w, h * 0.8, 0.14), GREEN[(row + col) % 3 + 1], Enum.Material.SmoothPlastic)
						seg.Name = "Bracer"
						weld(arm, seg, CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -rho))
					end
				end
				-- the fuze collar at the wrist, a steel rim where it meets the body
				ring(collarH, R * 2.08, collarY, SILVER, Enum.Material.Metal)
				ring(collarH * 0.28, R * 2.14, collarY + collarH / 2, STEEL, Enum.Material.Metal)
				-- the safety lever: off the collar and down the outside of the grenade
				local o = side * R * 1.08
				local a0 = Vector3.new(side * R * 1.02, collarY, 0)
				local a1 = Vector3.new(o + side * 0.1, collarY + collarH, 0)
				local a2 = Vector3.new(o + side * 0.1, mid + len * 0.36, 0)
				local a3 = Vector3.new(o + side * 0.3, mid + len * 0.55, 0)
				for _, seg in { { a0, a1 }, { a1, a2 }, { a2, a3 } } do
					local span = seg[2] - seg[1]
					local lever = gearPart(gear, Vector3.new(0.08, span.Magnitude + 0.06, s.Z * 0.3), SILVER, Enum.Material.Metal)
					weld(arm, lever, CFrame.lookAt((seg[1] + seg[2]) / 2, (seg[1] + seg[2]) / 2 + Vector3.new(0, 0, -1)) * CFrame.Angles(0, 0, math.atan2(span.X, span.Y) * -1))
				end
				-- the pin ring, on the front of the collar
				local ringAt = Vector3.new(0, collarY, -R * 1.04)
				local pin = gearPart(gear, Vector3.new(0.05, 0.36, 0.36), SILVER, Enum.Material.Metal, Enum.PartType.Cylinder)
				weld(arm, pin, CFrame.new(ringAt) * CFrame.Angles(0, math.rad(90), 0))
				local hole = gearPart(gear, Vector3.new(0.06, 0.22, 0.22), GROOVE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
				weld(arm, hole, CFrame.new(ringAt + Vector3.new(0, 0, -0.01)) * CFrame.Angles(0, math.rad(90), 0))
				-- the glove: green, the palm orange (R6: the fist below the collar)
				local hand = r15 and findLimb(char, side == 1 and "RightHand" or "LeftHand", "") or arm
				local hs = hand.Size
				local gy = r15 and 0 or bottom + (collarY - collarH / 2 - bottom) / 2
				local gh = r15 and hs.Y or (collarY - collarH / 2 - bottom) + 0.02
				local glove = gearPart(gear, Vector3.new(hs.X + 0.08, gh, hs.Z + 0.08), GLOVE, Enum.Material.Leather)
				weld(hand, glove, CFrame.new(0, gy, 0))
				local palm = gearPart(gear, Vector3.new(0.05, gh * 0.8, hs.Z * 0.72), ORANGE, Enum.Material.Leather)
				weld(hand, palm, CFrame.new(-side * (hs.X / 2 + 0.05), gy, 0))
			end
		end
	end

	-- TODOROKI: the burn scar round his left eye - dark red, from the bridge of
	-- his nose out to the temple, brow to cheekbone, his eye showing in the
	-- middle of it
	function Kit.todorokiScar(gear, char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local v = visibleHead(head)
		local k = v.X / 1.2
		local SCAR = Color3.fromRGB(138, 38, 40)
		-- (x, y on the face, width, height, a twist): a ragged ring of burn
		-- round the eye (at about -0.19, 0.1)
		for _, s in {
			{ -0.24, 0.27, 0.4, 0.14, 6 },
			{ -0.43, 0.12, 0.2, 0.42, -10 },
			{ -0.26, -0.05, 0.38, 0.13, -8 },
			{ -0.06, 0.13, 0.1, 0.22, 0 },
			{ -0.4, -0.05, 0.2, 0.16, 20 },
			{ -0.38, 0.28, 0.18, 0.16, -18 },
		} do
			local p, n = onHead(v, s[1] * k, s[2] * k, 0.012 * k)
			local patch = ellipsoid(gear, Vector3.new(s[3] * k, s[4] * k, 0.05 * k), SCAR, Enum.Material.SmoothPlastic)
			patch.Name = "Scar"
			patch.Transparency = 0.1
			weld(head, patch, CFrame.lookAt(p, p + n) * CFrame.Angles(0, 0, math.rad(s[5])))
		end
	end

	-- IIDA: his rectangular glasses (thin dark frames)
	function Kit.iidaGlasses(gear, char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local v = visibleHead(head)
		local k = v.X / 1.2
		local FRAME = Color3.fromRGB(26, 28, 38)
		local y, z = 0.1 * k, -0.64 * k
		local w, h, t = 0.34 * k, 0.19 * k, 0.034 * k
		local function bar(size, cf)
			local p = gearPart(gear, size, FRAME, Enum.Material.Metal)
			p.Name = "Glasses"
			weld(head, p, cf)
		end
		for _, side in { 1, -1 } do
			local cx = side * 0.215 * k
			bar(Vector3.new(w + t, t, t), CFrame.new(cx, y + h / 2, z))
			bar(Vector3.new(w + t, t, t), CFrame.new(cx, y - h / 2, z))
			bar(Vector3.new(t, h, t), CFrame.new(cx + side * w / 2, y, z))
			bar(Vector3.new(t, h, t), CFrame.new(cx - side * w / 2, y, z))
			local lens = gearPart(gear, Vector3.new(w, h, 0.012), Color3.fromRGB(210, 230, 255), Enum.Material.Glass)
			lens.Transparency = 0.82
			weld(head, lens, CFrame.new(cx, y, z))
			-- the arm, back over the ear
			local hinge = Vector3.new(side * (0.215 * k + w / 2), y + h / 2 - t, z)
			local ear = Vector3.new(side * 0.59 * k, y + 0.01, -0.22 * k)
			local back = Vector3.new(side * 0.61 * k, y - 0.02, 0.26 * k)
			rod(gear, head, hinge, ear, t, FRAME, Enum.Material.Metal)
			rod(gear, head, ear, back, t, FRAME, Enum.Material.Metal)
		end
		bar(Vector3.new(0.09 * k, t, t), CFrame.new(0, y + h * 0.22, z))
	end

	-- ALL MIGHT: the two blond bangs standing up off his forehead in a V
	function Kit.allMightBangs(gear, char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local v = visibleHead(head)
		local k = v.X / 1.2
		local BLOND, SHADE = Color3.fromRGB(255, 222, 92), Color3.fromRGB(232, 184, 58)
		for _, side in { 1, -1 } do
			local root = onHead(v, side * 0.14 * k, 0.4 * k, -0.02 * k)
			local knee = Vector3.new(side * 0.5 * k, 0.98 * k, -0.5 * k)
			local tip = Vector3.new(side * 1.12 * k, 1.78 * k, -0.34 * k)
			-- the thick lower lock, a shaded underside, then the long point
			local d = knee - root
			local lock = ellipsoid(gear, Vector3.new(0.44 * k, d.Magnitude + 0.3 * k, 0.13 * k), BLOND, Enum.Material.SmoothPlastic)
			lock.Name = "Bang"
			local x = d.Unit:Cross(Vector3.new(0, 0, -1)).Unit
			weld(head, lock, CFrame.fromMatrix((root + knee) / 2, x, d.Unit))
			local under = ellipsoid(gear, Vector3.new(0.26 * k, d.Magnitude * 0.9, 0.12 * k), SHADE, Enum.Material.SmoothPlastic)
			weld(head, under, CFrame.fromMatrix((root + knee) / 2 + Vector3.new(0, 0, 0.05 * k) - x * side * 0.05 * k, x, d.Unit))
			blade(gear, head, knee - d.Unit * 0.12 * k, tip, 0.42 * k, 0.12 * k, Vector3.new(side, 0, 0), BLOND)
		end
	end

	-- DEKU: the red high-tops - chunky, a thick dark sole, white laces
	function Kit.dekuBoots(gear, char)
		local RED, DARK = Color3.fromRGB(214, 42, 46), Color3.fromRGB(160, 26, 32)
		local SOLE, LACE = Color3.fromRGB(56, 50, 54), Color3.fromRGB(238, 234, 226)
		for _, names in { { "RightFoot", "Right Leg" }, { "LeftFoot", "Left Leg" } } do
			local leg = findLimb(char, names[1], names[2])
			if leg then
				local s = leg.Size
				local r15 = leg.Name == names[1]
				local b = -s.Y / 2
				local shaft = r15 and s.Y * 1.4 or s.Y * 0.36
				local function box(size, pos, color, material)
					local p = gearPart(gear, size, color, material or Enum.Material.SmoothPlastic)
					p.Name = "Boot"
					weld(leg, p, CFrame.new(pos))
					return p
				end
				box(Vector3.new(s.X + 0.12, shaft, s.Z + 0.12), Vector3.new(0, b + shaft / 2 + 0.06, 0), RED)
				box(Vector3.new(s.X + 0.17, 0.1, s.Z + 0.17), Vector3.new(0, b + shaft + 0.06, 0), DARK)
				-- the toe, out past the front of the leg, rounded off
				box(Vector3.new(s.X + 0.12, 0.34, s.Z * 0.5), Vector3.new(0, b + 0.22, -(s.Z / 2 + s.Z * 0.2)), RED)
				local cap = ellipsoid(gear, Vector3.new(s.X + 0.12, 0.36, s.Z * 0.5), RED, Enum.Material.SmoothPlastic)
				weld(leg, cap, CFrame.new(0, b + 0.2, -(s.Z / 2 + s.Z * 0.38)))
				-- the sole
				box(Vector3.new(s.X + 0.18, 0.14, s.Z * 1.36), Vector3.new(0, b + 0.02, -s.Z * 0.2), SOLE)
				local nose = ellipsoid(gear, Vector3.new(s.X + 0.18, 0.14, s.Z * 0.46), SOLE, Enum.Material.SmoothPlastic)
				weld(leg, nose, CFrame.new(0, b + 0.02, -s.Z * 0.9))
				-- laces up the front, and the heel tab
				for i = 0, 2 do
					box(Vector3.new(s.X * 0.56, 0.05, 0.05), Vector3.new(0, b + 0.3 + i * shaft * 0.2, -(s.Z / 2 + 0.07)), LACE)
				end
				box(Vector3.new(s.X * 0.3, shaft * 0.4, 0.06), Vector3.new(0, b + shaft * 0.72, s.Z / 2 + 0.08), DARK)
			end
		end
	end

	-- SHIGARAKI: "Father" - the pale severed hand gripping his face, the palm
	-- over his mouth, the fingers splayed up over his face to the hairline
	-- (one eye showing between two of them), the thumb along his cheek, a
	-- brass cuff round the wrist under his chin
	function Kit.shigarakiHand(gear, char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local v = visibleHead(head)
		local k = v.X / 1.2
		local SKIN, SHADE, CUFF = Color3.fromRGB(212, 212, 206), Color3.fromRGB(172, 174, 172), Color3.fromRGB(180, 148, 84)
		local function at(x, y, lift)
			return (onHead(v, x * k, y * k, lift * k))
		end
		local function knob(size, pos, color)
			local p = ellipsoid(gear, Vector3.one * size * k, color or SKIN, Enum.Material.SmoothPlastic)
			p.Name = "Father"
			weld(head, p, CFrame.new(pos))
		end
		-- the palm, cupped over his mouth and chin
		local palmAt = at(0.02, -0.2, 0.08)
		local palm = ellipsoid(gear, Vector3.new(0.7, 0.56, 0.22) * k, SKIN, Enum.Material.SmoothPlastic)
		palm.Name = "Father"
		weld(head, palm, CFrame.new(palmAt) * CFrame.Angles(math.rad(-10), 0, 0))
		-- the wrist, hanging below his chin, and its cuff
		local wristTop = at(0.02, -0.42, 0.1)
		local wristLow = wristTop + Vector3.new(0, -0.34, 0.08) * k
		rod(gear, head, wristTop, wristLow, 0.3 * k, SKIN)
		rod(gear, head, wristTop + Vector3.new(0, -0.2, 0.05) * k, wristLow + Vector3.new(0, -0.08, 0.02) * k, 0.38 * k, CUFF, Enum.Material.Metal)
		-- four fingers: knuckle, middle joint, tip curling over the forehead
		for _, f in {
			{ -0.24, -0.32, -0.38 },
			{ -0.08, -0.1, -0.12 },
			{ 0.06, 0.1, 0.13 },
			{ 0.3, 0.42, 0.5 },
		} do
			local base = at(f[1], 0.02, 0.1)
			local mid = at(f[2], 0.3, 0.08)
			local tip = at(f[3], 0.52, 0.07)
			rod(gear, head, base, mid, 0.17 * k, SKIN)
			rod(gear, head, mid, tip, 0.15 * k, SKIN)
			knob(0.175, mid)
			knob(0.155, tip)
			knob(0.19, base)
			-- a crease across the middle joint
			local crease = gearPart(gear, Vector3.new(0.14 * k, 0.025 * k, 0.03 * k), SHADE, Enum.Material.SmoothPlastic)
			crease.Name = "Father"
			weld(head, crease, CFrame.lookAt(mid, mid + (mid - Vector3.new(0, mid.Y, 0)).Unit) * CFrame.new(0, 0, -0.085 * k))
		end
		-- the thumb, round his left cheek
		local t0, t1, t2 = at(-0.26, -0.24, 0.1), at(-0.44, -0.1, 0.08), at(-0.52, 0.06, 0.07)
		rod(gear, head, t0, t1, 0.19 * k, SKIN)
		rod(gear, head, t1, t2, 0.165 * k, SKIN)
		knob(0.2, t1)
		knob(0.17, t2)
	end

	-- GOJO: the black blindfold, knotted at the back
	function Kit.gojoBlindfold(gear, char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local v = visibleHead(head)
		local k = v.X / 1.2
		local CLOTH = Color3.fromRGB(18, 18, 24)
		local band = gearPart(gear, Vector3.new(0.34 * k, v.X * 1.07, v.Z * 1.07), CLOTH, Enum.Material.Fabric, Enum.PartType.Cylinder)
		band.Name = "Blindfold"
		weld(head, band, CFrame.new(0, 0.1 * k, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local knot = ellipsoid(gear, Vector3.new(0.24, 0.2, 0.16) * k, CLOTH, Enum.Material.Fabric)
		weld(head, knot, CFrame.new(0, 0.1 * k, 0.66 * k))
		for _, side in { 1, -1 } do
			local tail = gearPart(gear, Vector3.new(0.13, 0.36, 0.03) * k, CLOTH, Enum.Material.Fabric)
			weld(head, tail, CFrame.new(side * 0.05 * k, -0.08 * k, 0.7 * k) * CFrame.Angles(math.rad(12), 0, math.rad(side * 14)))
		end
	end

	-- KAMUI WOODS: his wooden forearms with the tan riveted armbands above
	-- them, and the bundle of red roses on his left hip (no helmet: the
	-- player's own face shows)
	function Kit.kamuiLook(gear, char)
		local WOOD, GRAIN = Color3.fromRGB(150, 94, 52), Color3.fromRGB(104, 62, 34)
		local TAN, RIVET = Color3.fromRGB(222, 198, 146), Color3.fromRGB(92, 72, 52)
		for _, spec in { { "RightLowerArm", "Right Arm", "RightUpperArm" }, { "LeftLowerArm", "Left Arm", "LeftUpperArm" } } do
			local arm = findLimb(char, spec[1], spec[2])
			if arm then
				local s = arm.Size
				local r15 = arm.Name == spec[1]
				-- the wood: the forearm (R6: the lower half of the arm), bark stripes down it
				local len = r15 and s.Y or s.Y * 0.55
				local y = r15 and 0 or -s.Y / 2 + len / 2
				local bark = gearPart(gear, Vector3.new(s.X + 0.1, len, s.Z + 0.1), WOOD, Enum.Material.Wood)
				bark.Name = "Bark"
				weld(arm, bark, CFrame.new(0, y, 0))
				for i = -1, 1, 2 do
					local grain = gearPart(gear, Vector3.new(0.08, len * 0.8, 0.04), GRAIN, Enum.Material.Wood)
					grain.Name = "Bark"
					weld(arm, grain, CFrame.new(i * s.X * 0.22, y, -(s.Z / 2 + 0.07)))
				end
				-- the armband, up the arm, and its rivets
				local upper = r15 and findLimb(char, spec[3], "") or arm
				local us = upper.Size
				local by = r15 and us.Y * 0.1 or s.Y * 0.18
				local band = gearPart(gear, Vector3.new(us.X + 0.14, 0.3, us.Z + 0.14), TAN, Enum.Material.SmoothPlastic)
				band.Name = "Armband"
				weld(upper, band, CFrame.new(0, by, 0))
				for i = -1, 1 do
					local rivet = gearPart(gear, Vector3.new(0.05, 0.1, 0.1), RIVET, Enum.Material.Metal, Enum.PartType.Cylinder)
					rivet.Name = "Rivet"
					weld(upper, rivet, CFrame.new(i * us.X * 0.3, by, -(us.Z / 2 + 0.09)) * CFrame.Angles(0, math.rad(90), 0))
				end
			end
		end
		-- the roses: a little bundle on his left hip
		local torso = findLimb(char, "LowerTorso", "Torso")
		if torso then
			local ts = torso.Size
			local low = torso.Name == "Torso" and -ts.Y * 0.4 or 0
			for i, off in { Vector3.new(0, 0, 0), Vector3.new(0.2, 0.14, 0.04), Vector3.new(-0.12, 0.18, 0.02), Vector3.new(0.08, -0.16, 0.03) } do
				local rose = ellipsoid(gear, Vector3.new(0.26, 0.24, 0.22), i % 2 == 0 and Color3.fromRGB(206, 44, 60) or Color3.fromRGB(232, 64, 78), Enum.Material.SmoothPlastic)
				rose.Name = "Rose"
				weld(torso, rose, CFrame.new(Vector3.new(-ts.X * 0.36, low, -(ts.Z / 2 + 0.1)) + off))
			end
		end
	end

	-- MR. COMPRESS: a black top hat with an orange band, his white mask (two
	-- eye slits and the grin) and the cane in his right hand (the player's
	-- own coat under it)
	function Kit.compressLook(gear, char)
		local head = char:FindFirstChild("Head")
		local BLACK, BAND = Color3.fromRGB(28, 26, 30), Color3.fromRGB(214, 110, 36)
		if head then
			local v = visibleHead(head)
			local k = v.X / 1.2
			local top = v.Y * 0.5
			local brim = gearPart(gear, Vector3.new(0.16 * k, v.X * 1.6, v.Z * 1.6), BLACK, Enum.Material.Fabric, Enum.PartType.Cylinder)
			brim.Name = "Hat"
			weld(head, brim, CFrame.new(0, top + 0.04 * k, 0) * CFrame.Angles(0, 0, math.rad(90)))
			local crown = gearPart(gear, Vector3.new(1.05 * k, v.X * 1.04, v.Z * 1.04), BLACK, Enum.Material.Fabric, Enum.PartType.Cylinder)
			crown.Name = "Hat"
			weld(head, crown, CFrame.new(0, top + 0.6 * k, 0) * CFrame.Angles(0, 0, math.rad(90)))
			local band = gearPart(gear, Vector3.new(0.22 * k, v.X * 1.1, v.Z * 1.1), BAND, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			band.Name = "Hat"
			weld(head, band, CFrame.new(0, top + 0.24 * k, 0) * CFrame.Angles(0, 0, math.rad(90)))
			local mask = gearPart(gear, Vector3.new(v.X * 0.98, v.Y * 0.86, 0.12 * k), Color3.fromRGB(240, 238, 232), Enum.Material.SmoothPlastic)
			mask.Name = "Mask"
			weld(head, mask, CFrame.new(0, -0.02 * k, -(v.Z / 2 + 0.05 * k)))
			for _, side in { -1, 1 } do
				local eye = gearPart(gear, Vector3.new(0.22 * k, 0.1 * k, 0.04 * k), BLACK, Enum.Material.SmoothPlastic)
				eye.Name = "Mask"
				weld(head, eye, CFrame.new(side * 0.24 * k, 0.16 * k, -(v.Z / 2 + 0.12 * k)) * CFrame.Angles(0, 0, math.rad(side * -18)))
			end
			local grin = gearPart(gear, Vector3.new(0.5 * k, 0.06 * k, 0.04 * k), BLACK, Enum.Material.SmoothPlastic)
			grin.Name = "Mask"
			weld(head, grin, CFrame.new(0, -0.22 * k, -(v.Z / 2 + 0.12 * k)))
		end
		local hand = findLimb(char, "RightHand", "Right Arm")
		if hand then
			local hs = hand.Size
			local y = hand.Name == "Right Arm" and -hs.Y / 2 + 0.3 or 0
			-- (held by the knob: the shaft hangs from the hand to the ground)
			local shaft = gearPart(gear, Vector3.new(2.6, 0.14, 0.14), Color3.fromRGB(24, 22, 26), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			shaft.Name = "Cane"
			weld(hand, shaft, CFrame.new(0, y - 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
			local knob = ellipsoid(gear, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(214, 176, 70), Enum.Material.Metal)
			knob.Name = "Cane"
			weld(hand, knob, CFrame.new(0, y + 0.1, 0))
		end
	end

	-- CHARGEBOLT: just his Shooter - one bracer on the right forearm (a band
	-- flush round it, the housing on top with its light), welded snug so it
	-- moves with the arm
	function Kit.denkiLook(gear, char)
		local arm = findLimb(char, "RightLowerArm", "Right Arm")
		if not arm then
			return
		end
		local s = arm.Size
		local r15 = arm.Name == "RightLowerArm"
		local h = r15 and s.Y * 0.62 or s.Y * 0.3
		local y = r15 and 0 or -s.Y * 0.22 -- (R6: the forearm is the lower half of the arm)
		local function piece(size, pos, color, material)
			local p = gearPart(gear, size, color, material or Enum.Material.SmoothPlastic)
			p.Name = "Shooter"
			weld(arm, p, CFrame.new(pos))
			return p
		end
		piece(Vector3.new(s.X + 0.1, h, s.Z + 0.1), Vector3.new(0, y, 0), Color3.fromRGB(236, 236, 240))
		local front = -(s.Z / 2 + 0.05)
		piece(Vector3.new(s.X * 0.62, h * 0.8, 0.2), Vector3.new(0, y, front - 0.1), Color3.fromRGB(44, 46, 56), Enum.Material.Metal)
		piece(Vector3.new(s.X * 0.36, 0.08, 0.04), Vector3.new(0, y + h * 0.18, front - 0.22), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	end

	-- TWICE: the full-head mask (black, the grey patch over the left side
	-- stitched on down the middle, two small eye holes) and the red
	-- wristbands his measuring tapes come out of (a yellow reel on each)
	function Kit.twiceLook(gear, char)
		local head = char:FindFirstChild("Head")
		if head then
			local v = visibleHead(head)
			local mask = ellipsoid(gear, v * 1.08, Color3.fromRGB(30, 30, 34), Enum.Material.Fabric)
			mask.Name = "TwiceMask"
			weld(head, mask, CFrame.new(0, 0, -v.Z * 0.02))
			local patch = ellipsoid(gear, Vector3.new(v.X * 0.62, v.Y * 1.1, v.Z * 1.1), Color3.fromRGB(150, 150, 156), Enum.Material.Fabric)
			patch.Name = "TwiceMask"
			weld(head, patch, CFrame.new(-v.X * 0.26, 0, -v.Z * 0.02))
			for i = -3, 3 do
				local stitch = gearPart(gear, Vector3.new(0.18, 0.05, 0.05), Color3.fromRGB(236, 236, 236))
				stitch.Name = "TwiceMask"
				local y = i * v.Y * 0.12
				local z = -math.sqrt(math.max(0.25 - (y / (v.Y * 1.08)) ^ 2, 0.02)) * v.Z * 1.08 - 0.02
				weld(head, stitch, CFrame.new(-v.X * 0.04, y, z))
			end
			for side = -1, 1, 2 do
				local eye = gearPart(gear, Vector3.new(v.X * 0.13, v.Y * 0.1, 0.05), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic)
				eye.Name = "TwiceMask"
				weld(head, eye, CFrame.new(side * v.X * 0.2, v.Y * 0.08, -v.Z * 0.54))
			end
		end
		for _, names in { { "RightLowerArm", "Right Arm" }, { "LeftLowerArm", "Left Arm" } } do
			local arm = findLimb(char, names[1], names[2])
			if arm then
				local s = arm.Size
				local r15 = arm.Name == names[1]
				local y = r15 and -s.Y * 0.2 or -s.Y * 0.32
				local band = gearPart(gear, Vector3.new(s.X + 0.12, s.Y * (r15 and 0.4 or 0.18), s.Z + 0.12), Color3.fromRGB(196, 34, 44))
				band.Name = "TwiceBand"
				weld(arm, band, CFrame.new(0, y, 0))
				local stripe = gearPart(gear, Vector3.new(s.X + 0.14, 0.08, s.Z + 0.14), Color3.fromRGB(60, 150, 70))
				stripe.Name = "TwiceBand"
				weld(arm, stripe, CFrame.new(0, y + s.Y * 0.05, 0))
				local out = names[1] == "RightLowerArm" and 1 or -1
				local reel = gearPart(gear, Vector3.new(0.18, 0.5, 0.5), Color3.fromRGB(240, 202, 58), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
				reel.Name = "TwiceReel"
				weld(arm, reel, CFrame.new(out * (s.X / 2 + 0.12), y, 0))
			end
		end
	end


	-- a spot on the body where a flame burns (the client lights it: VFX.BLAZE).
	-- `up` is the way it burns; Height / Width in studs; Pal "hell" | "blue"
	local function fireSpot(part, pos, up, height, width, pal, tongues)
		local a = Instance.new("Attachment")
		a.Name = "FireSpot"
		up = up.Unit
		local ref = math.abs(up.Z) < 0.9 and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local x = up:Cross(ref).Unit
		a.CFrame = CFrame.fromMatrix(pos, x, up)
		a:SetAttribute("Height", height)
		a:SetAttribute("Width", width)
		a:SetAttribute("Pal", pal or "hell")
		a:SetAttribute("Tongues", tongues or 2)
		a.Parent = part
		return a
	end
	Kit.fireSpot = fireSpot

	-- ENDEAVOR: his fire IS his costume - a beard and moustache of flame,
	-- flames for eyebrows, flames standing off his shoulders and burning
	-- round his boots (the client lights every FireSpot). And the solid bits:
	-- the armoured bracers with the grilles on the backs of his hands (the
	-- slits glow - that's where the fire comes out), his belt, and the scar
	-- down over his left eye (from the High-End fight)
	function Kit.endeavorLook(gear, char)
		local head = char:FindFirstChild("Head")
		local anchors = gearPart(gear, Vector3.one * 0.1, Color3.new(), nil, nil)
		anchors.Name = "FireSpots"
		anchors.Transparency = 1
		if head then
			local v = visibleHead(head)
			local k = v.X / 1.2
			-- (the spots ride on invisible parts welded to him, so they move
			-- with his head and body and go when the look does)
			local hp = gearPart(gear, Vector3.one * 0.1, Color3.new(), nil, nil)
			hp.Name = "FireSpots"
			hp.Transparency = 1
			weld(head, hp, CFrame.new())
			for _, side in { 1, -1 } do
				-- the brows: up and back off the brow ridge
				local p = onHead(v, side * 0.21 * k, 0.26 * k, 0.03 * k)
				fireSpot(hp, p, Vector3.new(side * 0.35, 1, 0.55), 0.6 * k, 0.28 * k, "hell", 2)
				-- the beard up the jaw
				local j = onHead(v, side * 0.42 * k, -0.26 * k, 0.02 * k)
				fireSpot(hp, j, Vector3.new(side * 0.55, 1, 0.1), 0.85 * k, 0.36 * k, "hell", 2)
				-- the moustache, out to the side
				local m = onHead(v, side * 0.12 * k, -0.12 * k, 0.04 * k)
				fireSpot(hp, m, Vector3.new(side * 1, 0.45, -0.2), 0.5 * k, 0.22 * k, "hell", 1)
			end
			-- the chin, licking forward and up
			local c = onHead(v, 0, -0.4 * k, 0.03 * k)
			fireSpot(hp, c, Vector3.new(0, 0.6, -0.8), 0.85 * k, 0.4 * k, "hell", 2)
			-- the scar: down through his left eye, brow to cheek, a little slanted
			local SCAR = Color3.fromRGB(150, 60, 56)
			for i = 0, 5 do
				local t = i / 5
				local p, n = onHead(v, (-0.25 + t * 0.07) * k, (0.36 - t * 0.52) * k, 0.012 * k)
				local seg = ellipsoid(gear, Vector3.new(0.05 * k, 0.12 * k, 0.03 * k), SCAR, Enum.Material.SmoothPlastic)
				seg.Name = "Scar"
				weld(head, seg, CFrame.lookAt(p, p + n) * CFrame.Angles(0, 0, math.rad(-8)))
			end
		end
		local torso = findLimb(char, "UpperTorso", "Torso")
		if torso then
			local ts = torso.Size
			local tp = gearPart(gear, Vector3.one * 0.1, Color3.new(), nil, nil)
			tp.Name = "FireSpots"
			tp.Transparency = 1
			weld(torso, tp, CFrame.new())
			for _, side in { 1, -1 } do
				-- the big flames off his shoulders
				fireSpot(tp, Vector3.new(side * ts.X * 0.36, ts.Y / 2, 0.05), Vector3.new(side * 0.35, 1, 0.2), 1.7, 0.95, "hell", 3)
			end
			-- round the collar
			fireSpot(tp, Vector3.new(0, ts.Y / 2, -ts.Z * 0.3), Vector3.new(0, 1, -0.2), 0.75, 0.8, "hell", 2)
			-- the belt, the buckle
			local lower = findLimb(char, "LowerTorso", "Torso")
			if lower then
				local ls = lower.Size
				local y = lower == torso and -ls.Y * 0.42 or 0
				local belt = gearPart(gear, Vector3.new(ls.X + 0.08, 0.26, ls.Z + 0.08), Color3.fromRGB(34, 34, 44), Enum.Material.SmoothPlastic)
				belt.Name = "Belt"
				weld(lower, belt, CFrame.new(0, y, 0))
				local buckle = gearPart(gear, Vector3.new(0.52, 0.34, 0.08), Color3.fromRGB(226, 120, 36), Enum.Material.Metal)
				buckle.Name = "Buckle"
				weld(lower, buckle, CFrame.new(0, y, -(ls.Z / 2 + 0.06)))
			end
		end
		-- the bracers: armour round each forearm, with the grille on the back
		-- of the hand - its slits glowing where the flames come out
		local STEEL, DARK, GLOW = Color3.fromRGB(58, 66, 88), Color3.fromRGB(28, 30, 40), Color3.fromRGB(255, 140, 40)
		for _, spec in { { "RightLowerArm", "Right Arm", 1 }, { "LeftLowerArm", "Left Arm", -1 } } do
			local arm = findLimb(char, spec[1], spec[2])
			if arm then
				local s, side = arm.Size, spec[3]
				local r15 = arm.Name == spec[1]
				local h = r15 and s.Y * 0.8 or s.Y * 0.42
				local y = r15 and 0 or -s.Y * 0.24
				local cuff = gearPart(gear, Vector3.new(s.X + 0.12, h, s.Z + 0.12), STEEL, Enum.Material.Metal)
				cuff.Name = "Bracer"
				weld(arm, cuff, CFrame.new(0, y, 0))
				-- a ridge down the outside, and the rims
				local ridge = gearPart(gear, Vector3.new(0.12, h * 0.9, s.Z * 0.5), DARK, Enum.Material.Metal)
				ridge.Name = "Bracer"
				weld(arm, ridge, CFrame.new(side * (s.X / 2 + 0.1), y, 0))
				for _, dy in { -h / 2, h / 2 } do
					local rim = gearPart(gear, Vector3.new(s.X + 0.18, 0.08, s.Z + 0.18), DARK, Enum.Material.Metal)
					rim.Name = "Bracer"
					weld(arm, rim, CFrame.new(0, y + dy, 0))
				end
				-- the grille on the back of the hand (R6: the bottom of the arm,
				-- outer face) - three glowing slits
				local gy = -s.Y / 2 + (r15 and 0.15 or 0.28)
				local plate = gearPart(gear, Vector3.new(0.07, 0.42, s.Z * 0.8), DARK, Enum.Material.Metal)
				plate.Name = "Grille"
				weld(arm, plate, CFrame.new(side * (s.X / 2 + 0.05), gy, 0))
				for i = -1, 1 do
					local slit = gearPart(gear, Vector3.new(0.04, 0.05, s.Z * 0.6), GLOW, Enum.Material.Neon)
					slit.Name = "Grille"
					weld(arm, slit, CFrame.new(side * (s.X / 2 + 0.09), gy + i * 0.11, 0))
				end
			end
		end
		-- his boots are on fire
		for _, spec in { { "RightFoot", "Right Leg" }, { "LeftFoot", "Left Leg" } } do
			local leg = findLimb(char, spec[1], spec[2])
			if leg then
				local lp = gearPart(gear, Vector3.one * 0.1, Color3.new(), nil, nil)
				lp.Name = "FireSpots"
				lp.Transparency = 1
				weld(leg, lp, CFrame.new())
				fireSpot(lp, Vector3.new(0, -leg.Size.Y / 2 + 0.35, -0.05), Vector3.new(0, 1, 0.25), 1.1, 0.95, "hell", 2)
			end
		end
		anchors:Destroy()
	end

	-- DABI: the purple scarred skin - under both eyes, down his cheeks to his
	-- jaw, round his neck and his forearms - held on at the edges by rows of
	-- surgical staples; the rings through his ears; the spiky hair he dyes
	-- black (white again once it's washed out: the ult, the reveal); and the
	-- dark navy coat's high, frayed collar and its ripped tails
	function Kit.dabiLook(gear, char, ult)
		local SCAR, SCAR_DARK = Color3.fromRGB(104, 58, 92), Color3.fromRGB(72, 36, 64)
		local STAPLE = Color3.fromRGB(196, 198, 206)
		local COAT, COAT_DARK = Color3.fromRGB(30, 40, 68), Color3.fromRGB(20, 26, 46)
		local HAIR = ult and Color3.fromRGB(238, 238, 244) or Color3.fromRGB(26, 26, 32)
		local head = char:FindFirstChild("Head")
		if head then
			local v = visibleHead(head)
			local k = v.X / 1.2
			-- the scars: under each eye to the jaw, and the chin
			local function patch(x, y, w, h, twist, color)
				local p, n = onHead(v, x * k, y * k, 0.012 * k)
				local e = ellipsoid(gear, Vector3.new(w * k, h * k, 0.045 * k), color or SCAR, Enum.Material.SmoothPlastic)
				e.Name = "Scar"
				weld(head, e, CFrame.lookAt(p, p + n) * CFrame.Angles(0, 0, math.rad(twist or 0)))
				return e
			end
			-- one burnt stretch from under his eyes down over his cheeks and jaw
			-- to the chin, overlapping so it follows the face (clear round his
			-- mouth, so his face still shows through)
			for _, row in { { -0.12, 0.46 }, { -0.24, 0.48 }, { -0.36, 0.42 }, { -0.46, 0.28 } } do
				local y, reach = row[1], row[2]
				for x = -reach, reach + 0.01, reach / 3.5 do
					if not (math.abs(x) < 0.24 and y > -0.4) then
						patch(x, y, 0.22, 0.17, math.random(-20, 20), math.random() < 0.3 and SCAR_DARK or SCAR)
					end
				end
			end
			for _, side in { 1, -1 } do
				-- wrinkles in it
				for i = 1, 3 do
					patch(side * (0.24 + i * 0.06), -0.14 - i * 0.08, 0.18, 0.025, side * (20 + i * 12), SCAR_DARK)
				end
				-- the staples along the top edge, under the eye, and down the side
				for i = 0, 6 do
					local x = side * (0.06 + i * 0.066)
					local y = -0.035 - (i >= 5 and (i - 4) * 0.09 or 0)
					local p, n = onHead(v, x * k, y * k, 0.03 * k)
					local st = gearPart(gear, Vector3.new(0.02 * k, 0.09 * k, 0.02 * k), STAPLE, Enum.Material.Metal)
					st.Name = "Staple"
					weld(head, st, CFrame.lookAt(p, p + n) * CFrame.Angles(0, 0, math.rad(side * 10)))
				end
				-- the rings through his ear
				for i = 0, 2 do
					local ring = gearPart(gear, Vector3.new(0.04, 0.12 * k, 0.12 * k), STAPLE, Enum.Material.Metal, Enum.PartType.Cylinder)
					ring.Name = "Piercing"
					weld(head, ring, CFrame.new(side * v.X * 0.5, (0.06 - i * 0.1) * k, 0.05 * k))
				end
			end
			-- the hair: a crop over the crown and spikes standing up and falling
			-- over his eyes
			local cap = ellipsoid(gear, Vector3.new(v.X * 1.04, v.Y * 0.55, v.Z * 1.06), HAIR, Enum.Material.SmoothPlastic)
			cap.Name = "Hair"
			weld(head, cap, CFrame.new(0, v.Y * 0.3, 0.02))
			local spikes = {
				-- (from, out: where it points; its length and width) - swept back
				-- off the crown, messy
				{ Vector3.new(0, 0.5, -0.05), Vector3.new(0.1, 0.75, 0.65), 0.38, 0.3 },
				{ Vector3.new(0.22, 0.47, 0.1), Vector3.new(0.45, 0.55, 0.75), 0.42, 0.28 },
				{ Vector3.new(-0.22, 0.47, 0.1), Vector3.new(-0.45, 0.6, 0.7), 0.4, 0.28 },
				{ Vector3.new(0.3, 0.44, -0.12), Vector3.new(0.8, 0.5, -0.15), 0.32, 0.24 },
				{ Vector3.new(-0.3, 0.44, -0.12), Vector3.new(-0.8, 0.45, -0.1), 0.34, 0.24 },
				{ Vector3.new(0, 0.36, 0.44), Vector3.new(0, -0.35, 1), 0.44, 0.32 },
				-- down round the sides and over the ears, and at the nape
				{ Vector3.new(0.46, 0.24, 0), Vector3.new(0.4, -0.85, 0.1), 0.4, 0.26 },
				{ Vector3.new(-0.46, 0.24, 0), Vector3.new(-0.4, -0.85, 0.15), 0.42, 0.26 },
				{ Vector3.new(0.36, 0.3, 0.34), Vector3.new(0.6, -0.55, 0.6), 0.42, 0.26 },
				{ Vector3.new(-0.36, 0.3, 0.34), Vector3.new(-0.6, -0.5, 0.6), 0.42, 0.26 },
				{ Vector3.new(0.16, 0.12, 0.47), Vector3.new(0.3, -0.9, 0.35), 0.36, 0.24 },
				{ Vector3.new(-0.16, 0.12, 0.47), Vector3.new(-0.25, -0.9, 0.4), 0.38, 0.24 },
				-- the fringe, down over his eyes
				{ Vector3.new(0.1, 0.42, -0.42), Vector3.new(0.12, -0.8, -0.5), 0.4, 0.22 },
				{ Vector3.new(-0.1, 0.42, -0.42), Vector3.new(-0.18, -0.8, -0.5), 0.44, 0.22 },
				{ Vector3.new(0.3, 0.38, -0.36), Vector3.new(0.4, -0.78, -0.45), 0.38, 0.2 },
				{ Vector3.new(-0.3, 0.38, -0.36), Vector3.new(-0.4, -0.78, -0.45), 0.36, 0.2 },
			}
			for _, s in spikes do
				local a = Vector3.new(s[1].X * v.X, s[1].Y * v.Y, s[1].Z * v.Z) * 1.02
				local b = a + s[2].Unit * s[3] * k
				blade(gear, head, a, b, s[4] * k, 0.08 * k, Vector3.new(0, 0, 1):Cross(s[2].Unit).Magnitude > 0.1 and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0), HAIR)
			end
		end
		local torso = findLimb(char, "UpperTorso", "Torso")
		if torso then
			local ts = torso.Size
			-- the scar round his neck, stapled along its lower edge
			for i = -1, 1 do
				local neck = ellipsoid(gear, Vector3.new(0.4, 0.36 - math.abs(i) * 0.06, 0.06), SCAR, Enum.Material.SmoothPlastic)
				neck.Name = "Scar"
				weld(torso, neck, CFrame.new(i * 0.24, ts.Y / 2 - 0.14 + math.abs(i) * 0.03, -(ts.Z / 2 + 0.01)) * CFrame.Angles(0, 0, math.rad(i * -12)))
			end
			for i = -3, 3 do
				local st = gearPart(gear, Vector3.new(0.03, 0.12, 0.03), STAPLE, Enum.Material.Metal)
				st.Name = "Staple"
				weld(torso, st, CFrame.new(i * 0.1, ts.Y / 2 - 0.32 + math.abs(i) * 0.035, -(ts.Z / 2 + 0.05)) * CFrame.Angles(0, 0, math.rad(i * 6)))
			end
			-- the high collar: standing up round the back and sides, open at
			-- the front, frayed along the top
			for i = -4, 4 do
				local a = math.rad(i * 26)
				local r = ts.Z * 0.62
				local pos = Vector3.new(math.sin(a) * ts.X * 0.3, ts.Y / 2 + 0.28, math.cos(a) * r)
				if math.abs(i) <= 3 then
					local tall = 0.62 - math.abs(i) * 0.06
					local panel = gearPart(gear, Vector3.new(0.36, tall, 0.07), COAT, Enum.Material.Fabric)
					panel.Name = "Collar"
					weld(torso, panel, CFrame.new(pos + Vector3.new(0, tall / 2 - 0.3, 0)) * CFrame.Angles(math.rad(-12), a, 0))
					-- the frayed edge: ragged teeth along the top
					local tooth = Instance.new("WedgePart")
					tooth.Size = Vector3.new(0.07, 0.16, 0.18)
					tooth.Color = COAT_DARK
					tooth.Material = Enum.Material.Fabric
					tooth.CanCollide, tooth.CanQuery, tooth.CanTouch, tooth.Massless, tooth.CastShadow = false, false, false, true, false
					tooth.Name = "Collar"
					tooth.Parent = gear
					weld(torso, tooth, CFrame.new(pos + Vector3.new(0, tall - 0.22, 0)) * CFrame.Angles(math.rad(-12), a + math.pi / 2, 0))
				end
			end
			-- the coat's tails: down past his knees behind, ripped at the hem
			local lower = findLimb(char, "LowerTorso", "Torso")
			if lower then
				local ls = lower.Size
				local base = lower == torso and -ls.Y / 2 or -ls.Y / 2
				for i, spec in ipairs({ { -0.55, 1.7, 0.2 }, { 0, 1.95, 0 }, { 0.55, 1.6, -0.2 } }) do
					local len = spec[2]
					local tail = gearPart(gear, Vector3.new(ls.X * 0.36, len, 0.06), COAT, Enum.Material.Fabric)
					tail.Name = "CoatTail"
					weld(lower, tail, CFrame.new(spec[1] * ls.X * 0.5, base - len / 2 + 0.3, ls.Z / 2 + 0.06) * CFrame.Angles(math.rad(8), 0, math.rad(spec[3] * 6)))
					-- the ripped hem: a torn point off the bottom
					local rip = Instance.new("WedgePart")
					rip.Size = Vector3.new(0.06, 0.4, ls.X * 0.18)
					rip.Color = COAT_DARK
					rip.Material = Enum.Material.Fabric
					rip.CanCollide, rip.CanQuery, rip.CanTouch, rip.Massless, rip.CastShadow = false, false, false, true, false
					rip.Name = "CoatTail"
					rip.Parent = gear
					weld(lower, rip, CFrame.new(spec[1] * ls.X * 0.5 + (i - 2) * 0.1, base - len + 0.12, ls.Z / 2 + 0.1) * CFrame.Angles(math.rad(8), math.pi / 2, math.pi))
				end
			end
		end
		-- the forearms: scarred from the elbow down, stapled round the top
		for _, spec in { { "RightLowerArm", "Right Arm" }, { "LeftLowerArm", "Left Arm" } } do
			local arm = findLimb(char, spec[1], spec[2])
			if arm then
				local s = arm.Size
				local r15 = arm.Name == spec[1]
				local h = r15 and s.Y * 0.9 or s.Y * 0.45
				local y = r15 and 0 or -s.Y / 2 + h / 2 + 0.05
				local wrap = gearPart(gear, Vector3.new(s.X + 0.03, h, s.Z + 0.03), SCAR, Enum.Material.SmoothPlastic)
				wrap.Name = "Scar"
				weld(arm, wrap, CFrame.new(0, y, 0))
				local top = y + h / 2
				for i = 0, 7 do
					local a = i / 8 * math.pi * 2
					local st = gearPart(gear, Vector3.new(0.03, 0.14, 0.03), STAPLE, Enum.Material.Metal)
					st.Name = "Staple"
					local out = Vector3.new(math.cos(a) * (s.X / 2 + 0.03), top, math.sin(a) * (s.Z / 2 + 0.03))
					weld(arm, st, CFrame.new(out) * CFrame.Angles(0, -a, 0))
				end
			end
		end
	end

	-- which look goes with which quirk
	function Kit.signatureLook(gear, char, quirkName)
		local build = ({
			Explosion = Kit.grenadeBracers,
			HalfCold = Kit.todorokiScar,
			Engine = Kit.iidaGlasses,
			OneForAll = Kit.allMightBangs,
			FullCowl = Kit.dekuBoots,
			PrimeDeku = Kit.dekuBoots,
			Decay = Kit.shigarakiHand,
			Limitless = Kit.gojoBlindfold,
			Arbor = Kit.kamuiLook,
			Compress = Kit.compressLook,
			Electrification = Kit.denkiLook,
			Double = Kit.twiceLook,
			Creation = Kit.YM and Kit.YM.look,
		})[quirkName or ""]
		if build then
			build(gear, char)
		end
	end
end

local function addUltAura(gear, char, quirkName, ult)
	local outline = Instance.new("Highlight")
	outline.Adornee = char
	outline.FillColor = ult.Color
	outline.FillTransparency = 0.85
	outline.OutlineColor = ult.AccentColor
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = gear
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if torso then
		local holder = gearPart(gear, Vector3.one * 0.2, Color3.new(), nil, nil)
		holder.Transparency = 1
		weld(torso, holder, CFrame.new(0, -1, 0))
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(ult.AccentColor, ult.Color)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		pe.Speed = NumberRange.new(4, 9)
		pe.Lifetime = NumberRange.new(0.4, 0.8)
		pe.Rate = 26
		pe.EmissionDirection = Enum.NormalId.Top
		pe.SpreadAngle = Vector2.new(35, 35)
		pe.Acceleration = Vector3.new(0, 8, 0)
		pe.Parent = holder
		local light = Instance.new("PointLight")
		light.Color = ult.Color
		light.Range = 14
		light.Brightness = 2
		light.Parent = holder
	end
	if quirkName == "Explosion" then
		-- palms crackling with sparks
		for _, names in { { "RightHand", "Right Arm" }, { "LeftHand", "Left Arm" } } do
			local hand = findLimb(char, names[1], names[2])
			if hand then
				local h = gearPart(gear, Vector3.one * 0.5, Color3.new(), nil, nil)
				h.Transparency = 1
				weld(hand, h, CFrame.new(0, -hand.Size.Y / 2, 0))
				addFlames(h, 1.6)
			end
		end
	elseif quirkName == "HalfCold" then
		-- both sides at once
		addSideAura(gear, char, true)
		addSideAura(gear, char, false)
	end
end

-- Josuke's pompadour (swept up and forward over the forehead, the sides
-- slicked back) and the gold heart and peace-sign pins on his collar
function Kit.josukeLook(gear, char)
	local HAIR, GOLD = Color3.fromRGB(28, 26, 32), Color3.fromRGB(255, 205, 60)
	local head = findLimb(char, "Head", "Head")
	if head then
		local hs = head.Size
		local roll = ellipsoid(gear, Vector3.new(hs.X * 0.92, hs.Y * 0.6, hs.Z * 1.3), HAIR, Enum.Material.SmoothPlastic)
		weld(head, roll, CFrame.new(0, hs.Y * 0.52, -hs.Z * 0.28) * CFrame.Angles(math.rad(-14), 0, 0))
		local back = ellipsoid(gear, Vector3.new(hs.X * 1.06, hs.Y * 0.62, hs.Z * 1.06), HAIR, Enum.Material.SmoothPlastic)
		weld(head, back, CFrame.new(0, hs.Y * 0.3, hs.Z * 0.08))
	end
	local torso = findLimb(char, "UpperTorso", "Torso")
	if torso then
		local ts = torso.Size
		for side = -1, 1, 2 do
			local pin = gearPart(gear, Vector3.new(0.32, 0.32, 0.08), GOLD, Enum.Material.Metal)
			weld(torso, pin, CFrame.new(side * ts.X * 0.3, ts.Y * 0.38, -(ts.Z / 2 + 0.04)))
		end
	end
end

-- (round 74) DIO: the golden hair swept up and back in spikes, the green
-- headband with a heart on it, the hearts on his knees
function Kit.dioLook(gear, char)
	local HAIR, BAND, HEART = Color3.fromRGB(250, 220, 104), Color3.fromRGB(38, 116, 84), Color3.fromRGB(252, 206, 64)
	local function heart(part, cf, size)
		for side = -1, 1, 2 do
			local lobe = gearPart(gear, Vector3.one * size * 0.62, HEART, Enum.Material.Metal, Enum.PartType.Ball)
			weld(part, lobe, cf * CFrame.new(side * size * 0.24, size * 0.14, 0))
		end
		local tip = gearPart(gear, Vector3.new(size * 0.58, size * 0.58, size * 0.3), HEART, Enum.Material.Metal)
		weld(part, tip, cf * CFrame.new(0, -size * 0.12, 0) * CFrame.Angles(0, 0, math.rad(45)))
	end
	local head = findLimb(char, "Head", "Head")
	if head then
		local hs = head.Size
		local top = ellipsoid(gear, Vector3.new(hs.X * 1.1, hs.Y * 0.62, hs.Z * 1.18), HAIR, Enum.Material.SmoothPlastic)
		weld(head, top, CFrame.new(0, hs.Y * 0.36, hs.Z * 0.06))
		-- the spikes: bangs over the brow, flicks at the sides and the back
		for _, s in {
			{ 0, 0.44, -0.46, -52, 0, 0.9 }, { -0.3, 0.4, -0.42, -44, 20, 0.8 }, { 0.3, 0.4, -0.42, -44, -20, 0.8 },
			{ -0.52, 0.22, 0.05, 0, 0, 0.72 }, { 0.52, 0.22, 0.05, 0, 0, 0.72 },
			{ -0.3, 0.34, 0.5, 48, 26, 0.85 }, { 0.3, 0.34, 0.5, 48, -26, 0.85 }, { 0, 0.52, 0.42, 60, 0, 0.95 },
		} do
			local spike = gearPart(gear, Vector3.new(hs.X * 0.24, hs.Y * s[6] * 0.55, hs.Z * 0.26), HAIR, Enum.Material.SmoothPlastic, Enum.PartType.Wedge)
			local roll = s[1] ~= 0 and s[4] == 0 and math.rad(s[1] > 0 and -62 or 62) or 0
			weld(head, spike, CFrame.new(s[1] * hs.X, s[2] * hs.Y, s[3] * hs.Z) * CFrame.Angles(math.rad(s[4]), math.rad(s[5]), roll))
		end
		local band = gearPart(gear, Vector3.new(hs.Y * 0.16, hs.X * 1.06, hs.X * 1.06), BAND, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weld(head, band, CFrame.new(0, hs.Y * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		heart(head, CFrame.new(0, hs.Y * 0.2, -hs.Z * 0.55), hs.Y * 0.2)
	end
	for _, names in { { "RightLowerLeg", "Right Leg" }, { "LeftLowerLeg", "Left Leg" } } do
		local leg = findLimb(char, names[1], names[2])
		if leg then
			local ls = leg.Size
			local y = leg.Name == names[1] and ls.Y * 0.32 or 0
			heart(leg, CFrame.new(0, y, -ls.Z / 2 - 0.08), math.min(ls.X, 1) * 0.62)
		end
	end
end

local function buildGear(player, char)
	if not char or not char.Parent then
		return
	end
	local old = char:FindFirstChild("QuirkGear")
	if old then
		old:Destroy()
	end
	local quirkName = player:GetAttribute("Quirk")
	local quirk = Config.Quirks[quirkName or ""]
	local alt = player:GetAttribute("QuirkAlt") == true
	local ult = player:GetAttribute("UltActive") == true and quirk and quirk.Ult or nil
	local gear = Instance.new("Model")
	gear.Name = "QuirkGear"
	-- the hero's look goes in a model of its own: the settings can leave it
	-- off (your own, for everyone) or hide everyone's on one screen
	local cos = Instance.new("Model")
	cos.Name = "Cosmetics"
	cos.Parent = gear
	if quirkName == "Engine" then
		addEnginePipes(gear, char, ult ~= nil)
	elseif quirkName == "HalfCold" and not ult then
		addSideAura(gear, char, alt)
	elseif quirkName == "Decay" then
		addDecayDust(gear, char, ult ~= nil)
	elseif quirkName == "FullCowl" then
		addCowlGlow(gear, char, ult ~= nil) -- (always in Full Cowl)
	elseif quirkName == "PrimeDeku" then
		addCowlGlow(gear, char, true) -- (round 74: always at full)
	elseif quirkName == "Overhaul" then
		addOverhaulGear(gear, char, ult ~= nil, cos)
	elseif quirkName == "Lemillion" then
		Kit.lemillionCostume(cos, char)
	elseif quirkName == "Manifest" then
		Kit.suneaterCostume(gear, char, ult ~= nil, cos)
	elseif quirkName == "CrazyDiamond" then
		Kit.josukeLook(cos, char)
	elseif quirkName == "TheWorld" then
		Kit.dioLook(cos, char) -- (round 74)
	elseif quirkName == "Hellflame" then
		Kit.endeavorLook(cos, char)
	elseif quirkName == "Blueflame" then
		Kit.dabiLook(cos, char, ult ~= nil)
	elseif quirkName == "Creation" and Kit.YM then
		Kit.YM.arm(char, Kit.YM.weapon(player), gear) -- (round 60: Creati's weapon, in her hand)
	end
	Kit.signatureLook(cos, char, quirkName)
	if player:GetAttribute("WearCosmetics") == false then
		cos:Destroy()
	end
	-- (round 59) Dabi's hair goes over the head: the avatar's own hair comes off
	Kit.avatarHair(char, (quirkName == "Blueflame" or quirkName == "TheWorld") and player:GetAttribute("WearCosmetics") ~= false)
	if ult then
		addUltAura(gear, char, quirkName, ult)
	end
	gear.Parent = char
end

-- (round 59) The avatar's own hair, hidden while a hero's hair goes over the
-- head (Dabi's): each hair accessory's handle goes see-through, and back as
-- it was when he's someone else. Hair put on later (an outfit, a slow-loading
-- avatar) is caught as it arrives.
Kit.hairWatch = setmetatable({}, { __mode = "k" })
function Kit.avatarHair(char, hide)
	char:SetAttribute("HideAvatarHair", hide or nil)
	local function isHair(acc)
		local ok, hair = pcall(function()
			return acc.AccessoryType == Enum.AccessoryType.Hair
		end)
		if ok and hair then
			return true
		end
		local handle = acc:FindFirstChild("Handle")
		return handle ~= nil and handle:FindFirstChild("HairAttachment") ~= nil
	end
	local function apply(acc)
		local handle = acc:FindFirstChild("Handle")
		if not (handle and handle:IsA("BasePart") and isHair(acc)) then
			return
		end
		if char:GetAttribute("HideAvatarHair") then
			if handle:GetAttribute("LookTransparency") == nil then
				handle:SetAttribute("LookTransparency", handle.Transparency)
			end
			handle.Transparency = 1
		elseif handle:GetAttribute("LookTransparency") ~= nil then
			handle.Transparency = handle:GetAttribute("LookTransparency")
			handle:SetAttribute("LookTransparency", nil)
		end
	end
	for _, acc in char:GetChildren() do
		if acc:IsA("Accessory") then
			apply(acc)
		end
	end
	if hide and not Kit.hairWatch[char] then
		Kit.hairWatch[char] = char.ChildAdded:Connect(function(acc)
			if acc:IsA("Accessory") then
				task.defer(apply, acc)
			end
		end)
	end
end

-- Gear is built a moment after any body rescale so it fits the new limb sizes
local gearTokens = setmetatable({}, { __mode = "k" })
local function applyGear(player, char, delayTime)
	local old = char and char:FindFirstChild("QuirkGear")
	if old then
		old:Destroy()
	end
	local token = (gearTokens[char] or 0) + 1
	gearTokens[char] = token
	task.delay(delayTime or 0, function()
		if gearTokens[char] == token then
			buildGear(player, char)
		end
	end)
end

---------------------------------------------------------------------------
-- Body scaling (muscle form)
---------------------------------------------------------------------------

local SCALE_VALUES = { "BodyWidthScale", "BodyDepthScale", "BodyHeightScale", "HeadScale" }

-- scale = a BodyScale table from the config, or nil to restore the original body.
-- size multiplies on top of it (the test menu's Giant / Tiny modes).
local function applyBody(char, scale, size)
	size = size or 1
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	local changed = false
	if hum.RigType == Enum.HumanoidRigType.R15 then
		for _, name in SCALE_VALUES do
			local v = hum:FindFirstChild(name)
			if v and v:IsA("NumberValue") then
				local key = "Orig" .. name
				local orig = char:GetAttribute(key)
				if orig == nil then
					orig = v.Value
					char:SetAttribute(key, orig)
				end
				local target = (scale and orig * (scale[name] or 1) or orig) * size
				if math.abs(v.Value - target) > 1e-3 then
					v.Value = target
					changed = true
				end
			end
		end
	else
		local current = char:GetAttribute("BuffScale") or 1
		local target = (scale and (scale.R6Scale or 1.2) or 1) * size
		if math.abs(current - target) > 1e-3 then
			local ok = pcall(function()
				char:ScaleTo(target)
			end)
			if ok then
				char:SetAttribute("BuffScale", target)
				changed = true
			end
		end
	end
	return changed
end

---------------------------------------------------------------------------
-- Passives (speed, body, gear) for the current quirk + form
---------------------------------------------------------------------------

local function applyPassives(player, char, fresh)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	local quirkName = player:GetAttribute("Quirk")
	local quirk = Config.Quirks[quirkName or ""]
	local alt = player:GetAttribute("QuirkAlt") == true
	local ult = player:GetAttribute("UltActive") == true and quirk and quirk.Ult or nil
	local form = ult or (alt and quirk and quirk.Alt) or quirk
	local walkSpeed = (form and form.WalkSpeed) or (quirk and quirk.WalkSpeed) or Config.BaseWalkSpeed
	local jumpPower = (form and form.JumpPower) or (quirk and quirk.JumpPower) or Config.BaseJumpPower
	if (char:GetAttribute("TriggeredUntil") or 0) > workspace:GetServerTimeNow() then
		walkSpeed *= Config.Items.Trigger.SpeedBoost or 1.2 -- on Trigger
	end
	-- Deku's Gearshift: faster a gear at a time (see Handlers.Gearshift)
	local gear = char:GetAttribute("Gearshift")
	if gear and quirkName == "FullCowl" then
		local gs = Config.FindAbilityById("Gearshift") or {}
		walkSpeed *= 1 + (gs.SpeedPerGear or 0.1) * gear
	elseif gear then
		char:SetAttribute("Gearshift", nil)
	end
	-- (server settings)
	walkSpeed *= tonumber(workspace:GetAttribute("SpeedMult")) or 1
	jumpPower *= tonumber(workspace:GetAttribute("JumpMult")) or 1
	char:SetAttribute("BaseWalkSpeed", walkSpeed)
	char:SetAttribute("BaseJumpPower", jumpPower)
	-- Suneater's stomach (Config.Quirks.Manifest.Stomach): full on a new body,
	-- gone when he's someone else
	if quirkName == "Manifest" then
		if fresh or char:GetAttribute("Stomach") == nil then
			char:SetAttribute("Stomach", (quirk.Stomach and quirk.Stomach.Max) or 100)
		end
	else
		char:SetAttribute("Stomach", nil)
	end
	-- Mr. Compress's pocket and Chargebolt's clip (Kit.MC / Kit.DK): empty /
	-- full on a new body, dropped when he's someone else
	if Kit.MC then
		Kit.MC.setup(char, quirkName == "Compress", fresh)
	end
	if Kit.DK then
		Kit.DK.setup(char, quirkName == "Electrification", fresh)
	end
	-- (round 69) Twice's doubles and his mark: dropped on a new body / when he's someone else
	if Kit.TW then
		Kit.TW.setup(char, quirkName == "Double", fresh)
	end
	-- Endeavor's heat gauge (Kit.HF): cold on a new body, gone when he's someone else
	if Kit.HF then
		Kit.HF.setup(char, quirkName == "Hellflame", fresh)
	end
	-- mirrored on the character so every client's VFX can read them
	char:SetAttribute("Quirk", quirkName)
	char:SetAttribute("QuirkAlt", alt)
	if quirkName ~= "FullCowl" then
		char:SetAttribute("BrokenArmR", nil)
		char:SetAttribute("BrokenArmL", nil)
	end
	char:SetAttribute("UltActive", ult ~= nil)
	hum.UseJumpPower = true
	if fresh then
		char:SetAttribute("Stunned", false)
	end
	if hum.MaxHealth ~= Config.PlayerMaxHealth then
		-- new character: set health once (switching quirks mid-fight doesn't heal)
		hum.MaxHealth = Config.PlayerMaxHealth
		hum.Health = Config.PlayerMaxHealth
	end
	if not char:GetAttribute("Stunned") then
		hum.WalkSpeed = walkSpeed
		hum.JumpPower = jumpPower
	end
	local bodyScale = (ult and ult.BodyScale) or (alt and quirk and quirk.Alt and quirk.Alt.BodyScale) or (quirk and quirk.BodyScale) or nil
	local rescaled = applyBody(char, bodyScale, player:GetAttribute("SizeMode"))
	applyGear(player, char, rescaled and 0.2 or 0)
	-- (round 59) the awakening outfit on (or off) with the ult - first, so the
	-- hero costume below goes on (or back) over whichever look is on
	Store.AwakenOutfit(player, char, ult ~= nil)
	-- All Might's hero costume goes on with the muscle
	Store.Outfit(char, form ~= nil and form.Outfit == true)
end
Kit.applyPassives = applyPassives

---------------------------------------------------------------------------
-- R special (side swap / transformation), with optional time limit
---------------------------------------------------------------------------

local altTokens = {}
local recoverUntil = {} -- [player] = { [quirkName] = os.clock() when that quirk's form can be entered again }

local function checkCooldown(player, key, length)
	if player:GetAttribute("NoCooldowns") then
		return true
	end
	local now = os.clock()
	local playerCds = cooldowns[player] or {}
	cooldowns[player] = playerCds
	if playerCds[key] and now - playerCds[key] < length - COOLDOWN_TOLERANCE then
		return false
	end
	playerCds[key] = now
	return true
end

-- notifyCaster: true when the server changed the form on its own (time limit),
-- so the caster didn't already play the effect locally
local function setAlt(player, char, on, notifyCaster)
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	local special = quirk and quirk.Special
	player:SetAttribute("QuirkAlt", on)
	local token = (altTokens[player] or 0) + 1
	altTokens[player] = token
	if on and special and special.Duration and special.Duration > 0 then
		player:SetAttribute("AltEnds", workspace:GetServerTimeNow() + special.Duration)
		task.delay(special.Duration, function()
			if altTokens[player] == token and player:GetAttribute("QuirkAlt") == true then
				setAlt(player, player.Character, false, true)
			end
		end)
	else
		player:SetAttribute("AltEnds", nil)
		if not on and special and special.RecoverTime then
			recoverUntil[player] = recoverUntil[player] or {}
			recoverUntil[player][player:GetAttribute("Quirk")] = os.clock() + special.RecoverTime
		end
	end
	if char and char.Parent then
		local reveal = on and special and special.Presence
		if reveal then
			-- (round 73) he grows in heartbeats before it: each pulse a step of
			-- the way to his full size (Presence.Pulses)
			local full = (player:GetAttribute("UltActive") and quirk.Ult and quirk.Ult.BodyScale) or (quirk.Alt and quirk.Alt.BodyScale)
			for _, pulse in reveal.Pulses or {} do
				task.delay(pulse[1], function()
					if full and altTokens[player] == token and char.Parent and player:GetAttribute("QuirkAlt") == true then
						local part = {}
						for key, v in full do
							part[key] = 1 + (v - 1) * pulse[2]
						end
						if applyBody(char, part, player:GetAttribute("SizeMode")) then
							applyGear(player, char, 0.1)
						end
					end
				end)
			end
			-- (All Might: the muscle and the costume come out of the steam at
			-- the burst - not while the smoke is still gathering)
			task.delay(reveal.BurstAt or 0.85, function()
				if altTokens[player] == token and char.Parent and player:GetAttribute("QuirkAlt") == true then
					applyPassives(player, char, false)
				end
			end)
		else
			applyPassives(player, char, false)
		end
		if special then
			broadcast(special.Id, char, { Alt = on }, (not notifyCaster) and player or nil)
		end
		-- All Might's presence: anyone close is frozen in terror while he
		-- powers up, then the steam blast of the burst shoves them away
		local P = on and special and special.Presence
		local root = P and char:FindFirstChild("HumanoidRootPart")
		if root then
			local center = root.Position
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + (P.BurstAt or 0.85) + 0.1)
			local caught = queryRadius(char, center, P.Radius or 18)
			for _, model in caught do
				stun(model, P.Freeze or 0.95)
				local victim = Players:GetPlayerFromCharacter(model)
				if victim then
					PlayVFX:FireClient(victim, "Terrified", nil, { From = char })
				end
			end
			task.delay(P.BurstAt or 0.85, function()
				if altTokens[player] ~= token or not char.Parent then
					return
				end
				local now = root.Position
				for _, model in caught do
					local r = model:FindFirstChild("HumanoidRootPart")
					if r and model.Parent and (r.Position - now).Magnitude <= (P.Radius or 18) + 4 then
						knockback(model, awayFrom(now, model, root.CFrame.LookVector) * (P.Push or 75) + UP * (P.Lift or 28), 0.22)
					end
				end
			end)
		end
	end
end

local function handleSpecial(player, char, quirkName, special)
	if player:GetAttribute("UltActive") then
		return
	end
	local goingAlt = player:GetAttribute("QuirkAlt") ~= true
	local waitUntil = recoverUntil[player] and recoverUntil[player][quirkName] or 0
	if goingAlt and not player:GetAttribute("NoCooldowns") and os.clock() < waitUntil - COOLDOWN_TOLERANCE then
		return
	end
	if not checkCooldown(player, Config.CooldownKey(quirkName, Config.SPECIAL_INDEX), special.Cooldown) then
		return
	end
	setAlt(player, char, goingAlt, false)
end

---------------------------------------------------------------------------
-- Ultimates (G)
---------------------------------------------------------------------------

local ultTokens = {}

local function endUlt(player, char, silent)
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	if char then
		endKaiju(char) -- the kaiju comes apart with the ult
	end
	ultTokens[player] = (ultTokens[player] or 0) + 1
	player:SetAttribute("UltActive", false)
	player:SetAttribute("UltEnds", nil)
	player:SetAttribute("Ult", 0)
	cooldowns[player] = {}
	if quirk and quirk.Ult and quirk.Ult.ForceAlt and player:GetAttribute("QuirkAlt") then
		-- All Might deflates when Plus Ultra runs out
		setAlt(player, char, false, true)
	elseif char and char.Parent then
		applyPassives(player, char, false)
	end
	if not silent and char and char.Parent then
		broadcast("UltEnd", char, {})
		-- (Chargebolt: that much at once fries his brain for a moment - "wheeey")
		local wheey = quirk and quirk.Ult and quirk.Ult.Wheey
		if wheey and wheey > 0 then
			stun(char, wheey, 8)
			char:SetAttribute("Wheey", true)
			task.delay(wheey, function()
				if char.Parent then
					char:SetAttribute("Wheey", nil)
				end
			end)
			broadcast("Wheey", char, { Duration = wheey })
		end
	end
end

local function activateUlt(player, char, root)
	local quirkName = player:GetAttribute("Quirk")
	local quirk = Config.Quirks[quirkName or ""]
	if not quirk or not quirk.Ult or player:GetAttribute("UltActive") or (player:GetAttribute("Ult") or 0) < 100 then
		return
	end
	local ult = quirk.Ult
	local token = (ultTokens[player] or 0) + 1
	ultTokens[player] = token
	altTokens[player] = (altTokens[player] or 0) + 1 -- pauses a running muscle-form timer
	cooldowns[player] = {}
	player:SetAttribute("Ult", 0)
	player:SetAttribute("UltActive", true)
	player:SetAttribute("UltEnds", workspace:GetServerTimeNow() + ult.Duration)
	if ult.ForceAlt then
		player:SetAttribute("QuirkAlt", true)
		player:SetAttribute("AltEnds", nil)
	end
	applyPassives(player, char, false)
	-- (popping it is never punished: untouchable through the awakening)
	local cine = Config.Cinematics
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + math.max(ULT.ActivationArmor or 1.3, (cine and cine.AwakeningArmor) or 0))
	broadcast("UltActivate", char, { Quirk = quirkName }, player)
	if Kit.TW and quirkName == "Double" then
		task.spawn(Kit.TW.parade, player, char) -- (round 69: Sad Man's Parade - they pour out of him)
	end
	-- the awakening blasts everyone nearby away
	local center = root.Position
	for _, model in queryRadius(char, center, ULT.ActivationRadius) do
		if damage(player, model, ULT.ActivationDamage) then
			knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 95 + UP * 45, 0.25)
			stun(model, 0.8)
		end
	end
	Destruction.Sphere(center, quirkName == "Decay" and 18 or 10, quirkName == "Decay" and "Decay" or "Crater")
	if ult.DomainRadius then
		task.spawn(expandDomain, char, center, ult, token, function(t)
			return ultTokens[player] == t and player:GetAttribute("UltActive") == true
		end)
	end
	-- (server settings: Infinite Ult keeps it going - the timer stays full)
	local function timer(wait)
		task.delay(wait, function()
			if ultTokens[player] ~= token or not player:GetAttribute("UltActive") then
				return
			end
			local now = workspace:GetServerTimeNow()
			if player:GetAttribute("InfiniteUlt") then
				player:SetAttribute("UltEnds", now + ult.Duration)
				timer(1)
				return
			end
			local left = (player:GetAttribute("UltEnds") or now) - now
			if left > 0.05 then
				timer(left)
				return
			end
			endUlt(player, player.Character, false)
		end)
	end
	timer(ult.Duration)
end

-- passive charge (round 59: none - Config.Ult.PassivePerSecond is 0; the
-- ult is earned by dealing damage)
task.spawn(function()
	while (ULT.PassivePerSecond or 0) > 0 do
		task.wait(1)
		for _, plr in Players:GetPlayers() do
			addUlt(plr, ULT.PassivePerSecond)
		end
	end
end)

---------------------------------------------------------------------------
-- Dash (movement is client-side; the server grants i-frames and relays VFX)
---------------------------------------------------------------------------

Kit.frontDashes = setmetatable({}, { __mode = "k" }) -- [player] = { At = os.clock(), Punched = bool }

-- JJS: a front dash that reaches someone ends in a punch. The dasher's own
-- machine sees the contact (and stops them there); this checks they really
-- were that close (on their screen: lag-compensated) and lands it.
function Kit.dashPunch(player, char, dir, target)
	local cfg = workspace:GetAttribute("DashPunchEnabled") ~= false and Config.Movement.DashPunch
	local dash = Kit.frontDashes[player]
	local root = char:FindFirstChild("HumanoidRootPart")
	if not cfg or not dash or dash.Punched or not root or typeof(target) ~= "Instance" or not target:IsA("Model")
		or target == char or not alive(target) then
		return
	end
	local window = (Config.Movement.FrontDashTime or 0.3) + 0.3 + Rewind.Delay(player)
	if os.clock() - dash.At > window then
		return
	end
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not troot then
		return
	end
	local reach = (cfg.Reach or 5.5) + 3
	local seen = Rewind.PositionAt(target, os.clock() - Rewind.Delay(player)) or troot.Position
	local near = math.min((troot.Position - root.Position).Magnitude, (seen - root.Position).Magnitude)
	if near > reach then
		return
	end
	dash.Punched = true
	local d = Vector3.new(dir.X, 0, dir.Z)
	d = d.Magnitude > 0.1 and d.Unit or root.CFrame.LookVector
	broadcast("DashPunch", char, { Target = target, Dir = d }, player)
	local landed = damage(player, target, cfg.Damage or 5, { Hitstop = cfg.Hitstop, From = root.Position })
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + (landed and (Config.Movement.DashHitRecovery or 0.08) or (Config.Movement.FrontWhiffRecovery or 0.18)))
	if landed then
		-- JJS: the dash hit is a combo starter - they're stunned where they
		-- stand (can't walk out of it) and barely pushed, right in front of you
		-- for the M1s
		if not Evasive.immune(target) then
			stun(target, cfg.Stun or 1, cfg.StunWalk or 0)
		end
		knockback(target, d * (cfg.Push or 4), 0.1, true)
	end
end

local function handleDash(player, char, dir, kind, target)
	if kind == "Punch" then
		if typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.1 then
			Kit.dashPunch(player, char, dir.Unit, target)
		end
		return
	end
	-- (round 65: "Chase" - JJS's anti-run, a forward dash on the side-dash timer)
	local chase = kind == "Chase" and (Config.Movement.ChaseDash or {}).Enabled ~= false
	if kind ~= "Front" and kind ~= "Back" and kind ~= "Left" and kind ~= "Right" and kind ~= "Side" and not chase then kind = "Front" end
	local front = kind == "Front"
	local cooldown = front and (Config.Movement.FrontDashCooldown or 5) or (Config.Movement.MobilityDashCooldown or 2)
	if not checkCooldown(player, front and "DashFront" or "DashMobility", cooldown) then return end
	local duration = front and (Config.Movement.FrontDashTime or 0.28) or kind == "Back" and (Config.Movement.BackDashTime or 0.24)
		or chase and ((Config.Movement.ChaseDash or {}).Time or 0.24) or (Config.Movement.SideDashTime or 0.2)
	char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + duration
		+ (front and (Config.Movement.FrontWhiffRecovery or 0.18) or kind == "Back" and (Config.Movement.BackDashRecovery or 0) or 0))
	-- (only a front dash can end in a punch)
	Kit.frontDashes[player] = kind == "Front" and { At = os.clock(), Punched = false } or nil
	iFrames[char] = os.clock() + Config.Movement.DashIFrames
	if typeof(dir) ~= "Vector3" or dir ~= dir or dir.Magnitude < 0.1 then
		dir = char.HumanoidRootPart.CFrame.LookVector
	end
	if kind ~= "Front" and kind ~= "Back" and kind ~= "Left" and kind ~= "Right" and kind ~= "Side" and not chase then
		kind = "Front"
	end
	broadcast("Dash", char, {
		Dir = dir.Unit,
		Kind = kind,
		Quirk = player:GetAttribute("Quirk"),
		Alt = player:GetAttribute("QuirkAlt") == true,
	}, player)
end

---------------------------------------------------------------------------
-- Finishers (E on someone at their last sliver of health). Both fighters
-- are locked in place facing each other while the attacker's quirk plays
-- its execution; nobody else can hit the victim meanwhile. Then the KO, and
-- the body flies off ragdolled with the blow.
---------------------------------------------------------------------------

local FINISH = Config.Finishers or {}

local function finishStyle(player)
	local styles = FINISH.Styles or {}
	return styles[player:GetAttribute("Quirk") or ""] or styles.Default or { Time = 1.1, Forward = 90, Up = 45 }
end

-- The finishing blow sends the body flying. Every limb of the ragdoll gets the
-- velocity at once (so it doesn't trail behind the root), it tumbles, the
-- server takes over its physics (a dead player's own client would otherwise
-- keep simulating it and shrug the push off), and it smashes through
-- whatever it flies into.
local launchTokens = setmetatable({}, { __mode = "k" })
local function launchBody(model, velocity, spin, carry)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.Anchored = false
	deathRagdoll(model) -- limp now, not a frame later when Died is handled
	local token = (launchTokens[model] or 0) + 1
	launchTokens[model] = token
	local axis = velocity:Cross(UP)
	axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.new(1, 0, 0)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			pcall(function()
				p:SetNetworkOwner(nil)
			end)
			p.AssemblyLinearVelocity = velocity
			p.AssemblyAngularVelocity = axis * (spin or 0)
		end
	end
	for _, d in root:GetChildren() do
		if d.Name == "Knockback" or d.Name == "KnockbackAttachment" or d.Name == "FinisherLaunch" or d.Name == "FinisherLaunchAttachment" then
			d:Destroy()
		end
	end
	if carry and carry > 0 then
		-- hold the speed through the first scrape along the ground
		local att = Instance.new("Attachment")
		att.Name = "FinisherLaunchAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "FinisherLaunch"
		lv.Attachment0 = att
		lv.MaxForce = (FINISH.Launch and FINISH.Launch.Force) or 250000
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = velocity
		lv.Parent = root
		Debris:AddItem(lv, carry)
		Debris:AddItem(att, carry)
	end
	broadcast("FinisherLaunch", model, { Velocity = velocity })
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.6 and root.Parent and launchTokens[model] == token do
			local v = root.AssemblyLinearVelocity
			if os.clock() - t0 < 0.1 then
				v = velocity
			end
			if v.Magnitude < 60 then
				break -- it's come down
			end
			Destruction.Sphere(root.Position + v.Unit * 3, 4, "Impact", v.Unit)
			task.wait(0.06)
		end
	end)
end

-- aim (optional): where the finisher sends them flying (the player's crosshair
-- / mouse direction); without it, straight on
local function handleFinisher(player, char, root, target, aim)
	if not FINISH.Enabled or typeof(target) ~= "Instance" or not target:IsA("Model") or target == char or not target.Parent then
		return
	end
	local troot = target:FindFirstChild("HumanoidRootPart")
	local thum = target:FindFirstChildOfClass("Humanoid")
	if not troot or not thum or thum.Health <= 0 or thum.Health > thum.MaxHealth * (FINISH.Threshold or 0.15) + 0.01 then
		return
	end
	if finishing[target] or target:GetAttribute("Finishing") or char:GetAttribute("Finishing") then
		return
	end
	if (troot.Position - root.Position).Magnitude > (FINISH.Range or 10) + 4 then
		return
	end
	local victim = Players:GetPlayerFromCharacter(target)
	if (victim and victim:GetAttribute("GodMode")) or (iFrames[target] or 0) > os.clock() or untouchable(target) then
		return -- mid-dodge / behind Infinity: it doesn't connect
	end
	if not checkCooldown(player, "Finisher", FINISH.Cooldown or 1) then
		return
	end
	local style = finishStyle(player)
	local time = style.Time or 1.1
	finishing[target] = player
	char:SetAttribute("Finishing", true)
	target:SetAttribute("BeingFinished", true)
	if guardState[target] and guardState[target].Blocking then
		setBlocking(target, false)
	end
	-- face each other at arm's length, both held still - lined up so the blow
	-- sends them where the attacker is aiming (their crosshair / mouse)
	local d = flatten(troot.Position - root.Position, root)
	if typeof(aim) == "Vector3" and aim == aim then
		local flatAim = Vector3.new(aim.X, 0, aim.Z)
		if flatAim.Magnitude > 0.1 then
			d = flatAim.Unit
		end
	end
	local stand = Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z) - d * 4.5
	root.CFrame = CFrame.lookAt(stand, stand + d)
	troot.CFrame = CFrame.lookAt(troot.Position, troot.Position - d)
	iFrames[char] = math.max(iFrames[char] or 0, os.clock() + time + (FINISH.AfterArmor or 0.8))
	stun(target, time + 0.2, 0)
	local wasAnchored = troot.Anchored
	troot.Anchored = true
	broadcast("Finisher", char, { Target = target, Dir = d, Style = player:GetAttribute("Quirk"), Time = time })
	local t0 = os.clock()
	while os.clock() - t0 < time and alive(char) and alive(target) do
		task.wait(0.05)
	end
	troot.Anchored = wasAnchored
	char:SetAttribute("Finishing", false)
	target:SetAttribute("BeingFinished", false)
	if alive(char) and alive(target) then
		-- the KO is theirs: credit first, then the body flies with the blow
		lastHit[target] = { Player = player, Time = os.clock() }
		target:SetAttribute("LastHitBy", player.Name)
		finishedBy[target] = player
		local life = lives[player]
		if life then
			life.Dealt += thum.Health
			life.Hits += 1
		end
		thum.Health = 0
		-- and the body goes flying: huge, far, tumbling
		local L = FINISH.Launch or {}
		local scale = L.Scale or 2.4
		local forward = math.max((style.Forward or 90) * scale, L.MinForward or 140)
		local up = style.Up or 45
		local function capped(v)
			local most = L.MaxSpeed or 340
			return v.Magnitude > most and v.Unit * most or v
		end
		if up < 0 then
			-- slammed into the street first, then it ricochets off it
			launchBody(target, UP * up * scale + d * 20, 0, 0)
			task.delay(L.Bounce or 0.14, function()
				if target.Parent then
					launchBody(target, capped(d * forward + UP * (L.MinUp or 70) * 1.5), L.Spin or 12, L.Carry or 0.2)
				end
			end)
		else
			launchBody(target, capped(d * forward + UP * math.max(up * scale, L.MinUp or 70)), L.Spin or 12, L.Carry or 0.2)
		end
	end
	finishing[target] = nil
end

---------------------------------------------------------------------------
-- All Might's super leap: the client launches itself; the server waits for
-- the landing and slams the ground
---------------------------------------------------------------------------

local function handleLeap(player, char, root)
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	local leap = quirk and quirk.SuperLeap
	if not leap or not (leap.Always or player:GetAttribute("QuirkAlt") or player:GetAttribute("UltActive")) then
		return
	end
	if not checkCooldown(player, "Leap", leap.Cooldown) then
		return
	end
	broadcast("SuperLeap", char, {}, player)
	task.spawn(function()
		task.wait(0.35)
		local t0 = os.clock()
		repeat
			task.wait(0.03)
		until not alive(char) or os.clock() - t0 > 4 or isGrounded(root, char)
		if not alive(char) or os.clock() - t0 > 4 then
			return
		end
		local center = groundBelow(root.Position, char)
		broadcast("SuperLand", char, { Pos = center })
		for _, model in queryRadius(char, center, leap.LandRadius) do
			if damage(player, model, leap.LandDamage) then
				knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 70 + UP * 45, 0.2)
				stun(model, 0.7)
			end
		end
		Destruction.Sphere(center, 6, "Crater")
	end)
end

---------------------------------------------------------------------------
-- FIGHTS: KO credit, streaks, the kill feed and the knocked-out recap
---------------------------------------------------------------------------

local function statValue(player, name)
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	return v
end

-- HERO RANKS: your lifetime kills (saved) move you up the ladder, from
-- Student to the No. 1 Hero (Config.Ranks). quiet: no rank-up fanfare (a
-- load, a reset)
function Kit.setKills(player, kills, quiet)
	kills = math.max(0, math.floor(kills))
	local before = player:GetAttribute("RankIndex") or 1
	local index, rank = Config.RankOf(kills)
	local stats = player:FindFirstChild("leaderstats")
	local kv = stats and stats:FindFirstChild("Kills")
	local rv = stats and stats:FindFirstChild("Rank")
	if kv then
		kv.Value = kills
	end
	if rv then
		rv.Value = rank.Short or rank.Name
	end
	player:SetAttribute("Kills", kills)
	player:SetAttribute("RankIndex", index)
	player:SetAttribute("Rank", rank.Name)
	if not quiet and index > before then
		broadcast("RankUp", nil, { Player = player.DisplayName, UserId = player.UserId, Rank = rank.Name, Index = index, Color = rank.Color })
	end
	if not quiet and Store.PublishBoard then
		Store.PublishBoard() -- (the board shows a kill straight away)
	end
end

local function setupStats(player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	-- (the player list shows these in order: kills - your lifetime total,
	-- saved - then the hero rank they've earned you)
	for _, name in { "Kills", "Rank", "Streak", (Config.Economy and Config.Economy.Currency) or "Bucks" } do
		local v = Instance.new(name == "Rank" and "StringValue" or "IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player
	player:SetAttribute("BestStreak", 0)
	Kit.setKills(player, 0, true)
end

local function quirkOf(player)
	return player and player:GetAttribute("Quirk") or nil
end

local function onKnockedOut(model)
	local victim = Players:GetPlayerFromCharacter(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local rec = lastHit[model]
	local killer = rec and os.clock() - rec.Time <= (FIGHTS.CreditWindow or 15) and rec.Player or nil
	if killer and (killer == victim or not killer.Parent) then
		killer = nil
	end
	broadcast("KO", nil, { Target = model, Pos = root and root.Position or nil })

	-- the one who went down: streak ends, recap on their screen
	local ended = 0
	if victim then
		local streak = statValue(victim, "Streak")
		ended = streak and streak.Value or 0
		if streak then
			streak.Value = 0
		end
		local life = lives[victim] or newLife()
		local killerChar = killer and killer.Character
		local killerHum = killerChar and killerChar:FindFirstChildOfClass("Humanoid")
		local kos = statValue(victim, "Kills")
		PlayVFX:FireClient(victim, "Recap", nil, {
			Killer = killer and killer.DisplayName or nil,
			KillerQuirk = quirkOf(killer),
			KillerHealth = killerHum and math.ceil(killerHum.Health) or nil,
			KillerMaxHealth = killerHum and killerHum.MaxHealth or nil,
			Dealt = math.floor(life.Dealt),
			Taken = math.floor(life.Taken),
			Hits = life.Hits,
			KOs = life.KOs,
			Parries = life.Parries,
			Blocked = life.Blocked,
			BiggestHit = life.BiggestHit,
			Time = os.clock() - life.Start,
			StreakEnded = ended,
			TotalKOs = kos and kos.Value or 0,
			BestStreak = victim:GetAttribute("BestStreak") or 0,
		})
	end

	-- the one who landed it: KO count, streak, a heal and some ult
	local finished = killer ~= nil and finishedBy[model] == killer
	finishedBy[model] = nil
	local feed = {
		Killer = killer and killer.DisplayName or nil,
		KillerQuirk = quirkOf(killer),
		Victim = victim and victim.DisplayName or model.Name,
		VictimQuirk = quirkOf(victim),
		Dummy = victim == nil,
		Finisher = finished or nil,
	}
	if Kit.Console then
		Kit.Console.print(string.format("KO: %s -> %s%s", feed.Killer or "?", feed.Victim or "?", feed.Finisher and " (finisher)" or ""), "event")
	end
	if killer then
		local counts = victim ~= nil or FIGHTS.DummyKOsCount == true
		local streakNow = 0
		if counts then
			local streak = statValue(killer, "Streak")
			Kit.setKills(killer, (killer:GetAttribute("Kills") or 0) + 1)
			if Store.MarkDirty then
				Store.MarkDirty(killer)
			end
			if streak then
				streak.Value += 1
				streakNow = streak.Value
				if streakNow > (killer:GetAttribute("BestStreak") or 0) then
					killer:SetAttribute("BestStreak", streakNow)
				end
			end
			if lives[killer] then
				lives[killer].KOs += 1
			end
			addUlt(killer, FIGHTS.UltOnKO or 0)
			Evasive.fill(killer.Character)
		end
		local killerChar = killer.Character
		local hum = killerChar and killerChar:FindFirstChildOfClass("Humanoid")
		if counts and hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + (FIGHTS.HealOnKO or 0))
		end
		local callout = counts and FIGHTS.StreakCallouts and FIGHTS.StreakCallouts[streakNow] or nil
		-- payday: every KO puts Bucks in the killer's pocket
		local econ = Config.Economy or {}
		local pay = victim and (econ.PerKO or 5) or (econ.PerDummyKO or 0)
		Store.AddBucks(killer, pay)
		PlayVFX:FireClient(killer, "KOConfirm", nil, {
			Victim = feed.Victim,
			Streak = streakNow,
			Counted = counts,
			Callout = callout,
			Heal = counts and (FIGHTS.HealOnKO or 0) or 0,
			Finisher = finished or nil,
			Bucks = pay > 0 and pay or nil,
		})
		feed.Streak = streakNow
		feed.Callout = callout
		feed.Shutdown = ended >= (FIGHTS.ShutdownStreak or 3) and ended or nil
		if counts then
			for _, plr in Players:GetPlayers() do
				PlayVFX:FireClient(plr, "KOFeed", nil, feed)
			end
		else
			PlayVFX:FireClient(killer, "KOFeed", nil, feed) -- dummy practice stays private
		end
	elseif victim then
		feed.Shutdown = ended >= (FIGHTS.ShutdownStreak or 3) and ended or nil
		for _, plr in Players:GetPlayers() do
			PlayVFX:FireClient(plr, "KOFeed", nil, feed) -- fell / reset: no one gets credit
		end
	end
end

---------------------------------------------------------------------------
-- The edge of the world (Config.MapBounds). The city stands on thin base
-- plates ("Undestroyable") with nothing round them. Off the edge is the void:
-- knocked (or walking) off it, you fall, and far enough down it's a KO -
-- credited to whoever put you there. (Invisible walls round the edge are
-- optional: Walls.) Under the street is different: a thick invisible floor
-- under the plates (exactly their size - no ledge past the edge) stops a hard
-- slam punching anyone through, and anyone who still ends up under the
-- street is put back where they last stood.
---------------------------------------------------------------------------
do
	local B = Config.MapBounds or {}
	local map = workspace:FindFirstChild("Map")
	local plates = {}
	for _, p in map and map:GetDescendants() or {} do
		if p:IsA("BasePart") and p.Name == "Undestroyable" and p.Size.X >= 60 and p.Size.Z >= 60 then
			table.insert(plates, p)
		end
	end
	if B.Enabled ~= false and #plates > 0 then
		local folder = Instance.new("Folder")
		folder.Name = "MapBounds"
		folder.Parent = workspace
		local function block(name, cf, size)
			local w = Instance.new("Part")
			w.Name = name
			w.Anchored = true
			w.CanCollide = true
			w.CanQuery = false -- (aim, camera and parkour rays pass through)
			w.CanTouch = false
			w.CastShadow = false
			w.Transparency = 1
			w.Size = size
			w.CFrame = cf
			w.Parent = folder
			return w
		end
		local H, T, F = B.WallHeight or 700, B.WallThickness or 8, B.FloorThickness or 30
		local floorY = math.huge
		for _, p in plates do
			local c, h = p.Position, p.Size / 2
			floorY = math.min(floorY, c.Y + h.Y)
			-- (with no walls, exactly the plate's size: no invisible ledge past the edge)
			block("Floor", CFrame.new(c.X, c.Y - h.Y - F / 2, c.Z), Vector3.new(p.Size.X + (B.Walls and 2 * T or 0), F, p.Size.Z + (B.Walls and 2 * T or 0)))
			if not B.Walls then
				continue
			end
			-- each edge: { runs along X or Z, where it is, which way is out }
			for _, e in { { "X", c.Z - h.Z, -1 }, { "X", c.Z + h.Z, 1 }, { "Z", c.X - h.X, -1 }, { "Z", c.X + h.X, 1 } } do
				local along, at, out = e[1], e[2], e[3]
				local lo = along == "X" and c.X - h.X or c.Z - h.Z
				local hi = along == "X" and c.X + h.X or c.Z + h.Z
				-- leave a gap wherever another plate carries the street on past this edge
				local spans = { { lo, hi } }
				for _, q in plates do
					local qc, qh = q.Position, q.Size / 2
					local qEdge = along == "X" and (out < 0 and qc.Z + qh.Z or qc.Z - qh.Z) or (out < 0 and qc.X + qh.X or qc.X - qh.X)
					if q ~= p and math.abs(qEdge - at) < 2 then
						local qlo = along == "X" and qc.X - qh.X or qc.Z - qh.Z
						local qhi = along == "X" and qc.X + qh.X or qc.Z + qh.Z
						local kept = {}
						for _, sp in spans do
							if qhi <= sp[1] or qlo >= sp[2] then
								table.insert(kept, sp)
							else
								if qlo > sp[1] then
									table.insert(kept, { sp[1], qlo })
								end
								if qhi < sp[2] then
									table.insert(kept, { qhi, sp[2] })
								end
							end
						end
						spans = kept
					end
				end
				for _, sp in spans do
					-- (walls meet edge to edge at the corners: nothing slips between)
					local a, b = sp[1], sp[2]
					if b - a > 0.5 then
						local mid, len = (a + b) / 2, b - a
						local y = c.Y + h.Y + H / 2 - F
						if along == "X" then
							block("Wall", CFrame.new(mid, y, at + out * T / 2), Vector3.new(len, H + F, T))
						else
							block("Wall", CFrame.new(at + out * T / 2, y, mid), Vector3.new(T, H + F, len))
						end
					end
				end
			end
		end

		-- the safety net: where each body last stood on something solid
		local safe = setmetatable({}, { __mode = "k" })
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local lastScan = 0
		local function fallback()
			local best
			for _, d in (map and map:GetDescendants() or {}) do
				if d:IsA("SpawnLocation") then
					best = best or d
				end
			end
			local p = plates[1]
			return best and (best.Position + UP * 4) or (p.Position + UP * (p.Size.Y / 2 + 4))
		end
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - lastScan < 0.25 then
				return
			end
			lastScan = now
			local bodies = {}
			for _, plr in Players:GetPlayers() do
				if plr.Character then
					table.insert(bodies, plr.Character)
				end
			end
			local dummies = workspace:FindFirstChild("Dummies")
			for _, m in dummies and dummies:GetChildren() or {} do
				table.insert(bodies, m)
			end
			rayParams.FilterDescendantsInstances = nonMapStuff(nil)
			for _, model in bodies do
				local root = model:FindFirstChild("HumanoidRootPart")
				local hum = model:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and not root.Anchored and not model:GetAttribute("PhaseDive") then
					local pos = root.Position
					-- (over a plate, or off the edge of the world?)
					local over = false
					for _, p in plates do
						local rel = pos - p.Position
						if math.abs(rel.X) <= p.Size.X / 2 + 2 and math.abs(rel.Z) <= p.Size.Z / 2 + 2 then
							over = true
							break
						end
					end
					if not over and not B.Walls then
						-- off the edge: into the void. Far enough down, that's a KO
						-- (for whoever knocked them off, if anyone did lately)
						if pos.Y < floorY - (B.VoidDepth or 150) then
							hum.Health = 0
						end
					elseif pos.Y < floorY - (B.RescueDepth or 30) then
						-- fallen out: back where they last stood, on their feet
						for _, c in root:GetChildren() do
							if c:IsA("LinearVelocity") and c.Name == "Knockback" then
								c:Destroy()
							end
						end
						if model:GetAttribute("Ragdolled") then
							setRagdoll(model, false)
						end
						local back = safe[model] or fallback()
						model:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
						root.AssemblyLinearVelocity = Vector3.zero
						iFrames[model] = math.max(iFrames[model] or 0, now + (B.RescueImmunity or 1.5))
					elseif pos.Y > floorY - 5 then
						local hit = workspace:Raycast(pos, Vector3.new(0, -8, 0), rayParams)
						if hit and hit.Instance and hit.Instance:IsDescendantOf(map) then
							safe[model] = hit.Position + UP * 3.5
						end
					end
				end
			end
		end)
	end
end

local function watchKO(model)
	local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	-- the body stays in one piece on death: deathRagdoll takes it from there
	hum.BreakJointsOnDeath = false
	-- and ONLY health decides a KO. With RequiresNeck on (Roblox's default) a
	-- neck that comes apart kills on the spot - and the ragdoll swaps the Neck
	-- for a ball joint that a violent launch (Iida's gear-3 Recipro Burst,
	-- his Gatling heel slam) could pull apart for a frame: a full-health KO,
	-- the "one-shot".
	hum.RequiresNeck = false
	local fired = false
	hum.Died:Connect(function()
		if not fired then
			fired = true
			deathRagdoll(model)
			onKnockedOut(model)
			if Kit.MC then
				Kit.MC.reset(model)
			end
			if Kit.DK then
				Kit.DK.reset(model)
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Dummy kinds (Config.DummyKinds, spawned from the test menu): what each one
-- does. The Dummies script builds them; the fighting happens here.
---------------------------------------------------------------------------

local function dummyBusy(model)
	return model:GetAttribute("Stunned") or model:GetAttribute("Ragdolled") or model:GetAttribute("Frozen") or model:GetAttribute("BeingFinished")
end

local function nearestFighter(root, range)
	local best, bestDist = nil, range
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and alive(c) then
			local dist = (r.Position - root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = c, dist
			end
		end
	end
	return best, bestDist
end

-- ATTACK dummy: walks at the nearest player and throws M1 combos. The hits
-- go through the real guard code, so they can be blocked and parried.
local function attackDummy(model, hum, root, kind)
	local combo, nextSwing = 0, 0
	local length = kind.ComboLength or 4
	local dmg = kind.Damage or 6
	while model.Parent and hum.Health > 0 do
		local foe, dist = nearestFighter(root, kind.Sight or 70)
		if foe and not dummyBusy(model) then
			local fr = foe:FindFirstChild("HumanoidRootPart")
			local flat = Vector3.new(fr.Position.X - root.Position.X, 0, fr.Position.Z - root.Position.Z)
			flat = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
			if dist > 5 then
				hum:MoveTo(fr.Position - flat * 3.5)
			else
				hum:MoveTo(root.Position)
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				if os.clock() >= nextSwing then
					combo = combo % length + 1
					local last = combo == length
					broadcast("Punch", model, { Count = combo, Finisher = last })
					task.wait(0.12) -- the swing lands
					if alive(foe) and model.Parent and not dummyBusy(model) and (fr.Position - root.Position).Magnitude < 7.5 then
						local hit = damage(nil, foe, last and dmg * 2 or dmg, {
							From = root.Position, AttackerModel = model, Hitstop = last and 0.1 or 0.05, Heavy = last or nil,
						})
						if hit then
							if last then
								knockback(foe, flat * 55 + UP * 15, 0.2)
							else
								stun(foe, 0.35)
							end
						end
					end
					nextSwing = os.clock() + (last and (kind.ComboRest or 1.3) or 0.42)
				end
			end
		else
			hum:MoveTo(root.Position)
			if not foe then
				combo = 0
			end
		end
		task.wait(0.1)
	end
end

local function dummyBrain(model)
	local kind = Config.DummyKind and Config.DummyKind(model:GetAttribute("DummyKind") or "")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not kind or not hum or not root then
		return
	end
	local function running()
		return model.Parent ~= nil and hum.Health > 0
	end
	if kind.Id == "Attack" then
		attackDummy(model, hum, root, kind)
	elseif kind.Id == "Block" then
		-- guard always up (it comes back up once a broken guard recovers)
		while running() do
			local g = guardOf(model)
			if not g.Blocking and not g.Broken and not dummyBusy(model) then
				setBlocking(model, true)
			end
			task.wait(0.4)
		end
	elseif kind.Id == "Moving" then
		local home = root.Position
		local right = root.CFrame.RightVector
		local side = 1
		while running() do
			if not dummyBusy(model) then
				hum:MoveTo(home + right * (kind.Stride or 10) * side)
				side = -side
			end
			task.wait(1.4)
		end
	elseif kind.Evasive then
		-- EVASIVE: ragdoll-cancels as soon as it can, its meter over its head
		model:SetAttribute("Evasive", 100)
		local head = model:FindFirstChild("Head")
		local board = head and head:FindFirstChild("DummyLabel")
		local label = board and board:FindFirstChildOfClass("TextLabel")
		local downAt
		while running() do
			local meter = model:GetAttribute("Evasive") or 0
			if label then
				label.Text = string.format("%s  %d%%", kind.Label or "EVASIVE", math.floor(meter))
			end
			if model:GetAttribute("Ragdolled") then
				downAt = downAt or os.clock()
				if meter >= 100 and os.clock() - downAt >= (kind.Reaction or 0.2) then
					local foe = nearestFighter(root, 60)
					local fr = foe and foe:FindFirstChild("HumanoidRootPart")
					local away = fr and (root.Position - fr.Position) or root.CFrame.RightVector
					Evasive.use(nil, model, root, Vector3.new(-away.Z, 0, away.X)) -- (a sidestep round them)
				end
			else
				downAt = nil
			end
			task.wait(0.1)
		end
	elseif kind.Stance then
		-- COUNTER: in and out of a counter stance - hit it in one and it
		-- hits back (and ragdolls you: a chance to practise the cancel)
		while running() do
			if not dummyBusy(model) then
				local stance = { Until = os.clock() + kind.Stance, Ability = { Damage = kind.Damage or 10 } }
				Kit.counters[model] = stance
				model:SetAttribute("Countering", true)
				broadcast("HeroCounter", model, {})
				task.wait(kind.Stance)
				if Kit.counters[model] == stance then
					Kit.counters[model] = nil
				end
				model:SetAttribute("Countering", nil)
			end
			task.wait(kind.Rest or 1.6)
		end
	elseif kind.RegenDelay then
		-- TANK: back to full health once you stop hitting it
		local lastHurt, lastHealth = 0, hum.Health
		while running() do
			if hum.Health < lastHealth then
				lastHurt = os.clock()
			end
			if hum.Health < hum.MaxHealth and os.clock() - lastHurt > kind.RegenDelay then
				hum.Health = hum.MaxHealth
			end
			lastHealth = hum.Health
			task.wait(0.25)
		end
	end
end

task.spawn(function()
	local folder = workspace:WaitForChild("Dummies", 30)
	if not folder then
		return
	end
	local function onDummy(model)
		if not model:IsA("Model") then
			return
		end
		classicJoints(model)
		-- (no tripping over by themselves either: only real hits put them down)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			end)
		end
		task.spawn(watchKO, model)
		task.spawn(dummyBrain, model)
		task.delay(0.5, function()
			if model.Parent and workspace:GetAttribute("DummiesBlock") then
				setBlocking(model, true)
			end
		end)
	end
	for _, model in folder:GetChildren() do
		onDummy(model)
	end
	folder.ChildAdded:Connect(onDummy)
end)

---------------------------------------------------------------------------
-- Testing menu (Studio, the game's creator, or Config.TestMenu.AllowedUserIds)
---------------------------------------------------------------------------

local function canTest(player)
	local cfg = Config.TestMenu
	if not cfg or not cfg.Enabled then
		return false
	end
	if cfg.Public or RunService:IsStudio() or player.UserId == game.CreatorId then
		return true
	end
	return table.find(cfg.AllowedUserIds or {}, player.UserId) ~= nil
end

-- Switch a player's quirk (fresh form and ult meter). Cooldowns and the
-- muscle form's recovery are kept per quirk, so switching away and back
-- doesn't refresh them.
local function applyQuirk(player, quirkName)
	altTokens[player] = (altTokens[player] or 0) + 1 -- cancels any running time limit
	ultTokens[player] = (ultTokens[player] or 0) + 1
	player:SetAttribute("UltActive", false)
	player:SetAttribute("UltEnds", nil)
	player:SetAttribute("Ult", 0)
	player:SetAttribute("Quirk", quirkName)
	player:SetAttribute("QuirkAlt", false)
	player:SetAttribute("AltEnds", nil)
	player:SetAttribute("QuirkPick", 1)
	if player.Character then
		applyPassives(player, player.Character, true)
	end
end

---------------------------------------------------------------------------
-- MR. COMPRESS (Atsuhiro Sako): Compress
---------------------------------------------------------------------------
-- Anything he touches shrinks into a marble. R pockets a piece of the city
-- (Destruction.Compress: those parts stay gone till the marble's thrown),
-- up to Marbles.Max at a time - the count's on his HUD ("Marbles"). A
-- marble in his pocket is a weapon: 1 throws it (it pops back to full size
-- on the way down), and every other move ends with one flicked at whoever
-- it hit (Marbles.BonusDamage: "another hit").
do
	local MC = { pocket = setmetatable({}, { __mode = "k" }) } -- [char] = { { Hold, Look } ... }: the map marbles, oldest first
	Kit.MC = MC
	local STREET = { Color = Color3.fromRGB(120, 118, 112), Material = Enum.Material.Concrete }

	local function spec()
		return Config.Quirks.Compress.Marbles or {}
	end
	local function count(char)
		return tonumber(char:GetAttribute("Marbles")) or 0
	end
	local function setCount(char, n)
		char:SetAttribute("Marbles", math.clamp(n, 0, spec().Max or 3))
	end

	-- the pocket emptied (a new body, someone else's quirk, knocked out): the
	-- pieces go back on the timer
	function MC.reset(char, keepAttr)
		for _, m in MC.pocket[char] or {} do
			if m.Hold then
				Destruction.Release(m.Hold)
			end
		end
		MC.pocket[char] = nil
		if not keepAttr then
			char:SetAttribute("Marbles", nil)
		end
	end
	function MC.setup(char, mine, fresh)
		if mine then
			if fresh or char:GetAttribute("Marbles") == nil then
				MC.reset(char, true)
				setCount(char, 0)
			end
		elseif char:GetAttribute("Marbles") ~= nil then
			MC.reset(char)
		end
	end
	-- the map marble on top of the pocket, thrown away (its piece of the
	-- street starts coming back); nil: the pocket's empty
	function MC.take(char)
		local list = MC.pocket[char]
		local m = list and table.remove(list)
		if m then
			if m.Hold then
				Destruction.Release(m.Hold) -- (round 75: a juggled one has no piece of the street)
			end
			setCount(char, count(char) - 1)
		end
		return m
	end
	-- a lob from `from` to land at `pos`: the flight, and where it comes down
	-- (the first thing it hits on the way)
	function MC.arc(char, from, pos, speed, maxDist)
		local g = workspace.Gravity
		local flat = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
		local dist = math.min(flat.Magnitude, maxDist or 60)
		local d = flat.Magnitude > 0.5 and flat.Unit or Vector3.new(0, 0, 1)
		local flight = math.clamp(dist / (speed or 90), 0.3, 1.2)
		local dy = math.clamp(pos.Y - from.Y, -60, 40)
		local vel = d * (dist / flight) + UP * ((dy + 0.5 * g * flight * flight) / flight)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local p, t = from, 0
		local land, landT
		while t < flight + 0.8 do
			local t2 = t + 1 / 30
			local p2 = from + vel * t2 - UP * (0.5 * g * t2 * t2)
			local hit = workspace:Raycast(p, p2 - p, params)
			if hit then
				land = hit.Position + hit.Normal * 0.5
				landT = t + (1 / 30) * math.clamp((hit.Position - p).Magnitude / math.max((p2 - p).Magnitude, 1e-3), 0, 1)
				break
			end
			p, t = p2, t2
		end
		return { From = from, Vel = vel, Gravity = g, Land = land or p, LandTime = landT or t, Dir = d }
	end
	-- a piece of the city comes down at `land`: everyone under it is hit
	function MC.rubbleLand(player, char, land, radius, dmg, d)
		for _, model in queryRadius(char, land + UP * 2, radius) do
			if damage(player, model, dmg, { Heavy = dmg >= 12, Hitstop = 0.06, From = land }) then
				knockback(model, awayFrom(land, model, d) * 40 + UP * 40, 0.2)
				stun(model, 0.6)
			end
		end
		Destruction.Sphere(land, math.max(radius * 0.6, 3), dmg >= 12 and "Impact" or "Tunnel", d)
	end
	-- "another hit": a marble flicked at whoever a move just hit (a magician's
	-- marble - it comes back to his hand)
	function MC.bonus(player, char, model)
		if count(char) < 1 or not model.Parent then
			return
		end
		local move = Moves.current()
		task.delay(0.18, function()
			Moves.join(move)
			local mr = model.Parent and model:FindFirstChild("HumanoidRootPart")
			if mr and alive(char) then
				broadcast("MarblePop", char, { Target = model, Pos = mr.Position })
				damage(player, model, spec().BonusDamage or 4, { NoKnockdown = true, From = mr.Position })
			end
		end)
	end
	-- somewhere to land at `pos`, at most `range` from him: the ground under it
	local function landingAt(root, pos, range, char)
		return groundTarget(root, pos, range, char) + UP * 2.6
	end
	-- them, a marble in his palm (every client hides the body), untouchable
	local function pocketBody(model, held)
		model:SetAttribute("Compressed", true)
		iFrames[model] = math.max(iFrames[model] or 0, os.clock() + held + 0.1)
	end
	local function unpocketBody(model)
		model:SetAttribute("Compressed", nil)
		iFrames[model] = 0
	end
	-- a marble's flight from a to b over `time` (the body's carried along it)
	local function fly(g, a, b, time, height)
		local t0 = os.clock()
		while os.clock() - t0 < time and g.Model.Parent do
			task.wait()
			local s = math.clamp((os.clock() - t0) / time, 0, 1)
			Grab.place(g, CFrame.new(a:Lerp(b, s) + UP * (height * 4 * s * (1 - s))))
		end
	end

	-- R: COMPRESS - the piece of the city he's pointing at (within Reach)
	-- shrinks into a marble in his hand. Nothing to take there: the street
	-- under the spot
	function Handlers.CompressMap(player, char, root, _ability, dir, pos)
		local sp = spec()
		if count(char) >= (sp.Max or 3) then
			PlayVFX:FireClient(player, "Notice", nil, { Text = "Pockets full: throw one (1)", Color = Color3.fromRGB(255, 150, 120) })
			return
		end
		local v = pos - root.Position
		local reach = sp.Reach or 16
		local at = v.Magnitude > reach and root.Position + v.Unit * reach or pos
		local part, point = Destruction.NearestBreakable(at, 7)
		if not part then
			part, point = Destruction.NearestBreakable(groundBelow(at + UP, char), 4)
		end
		if not part or not point then
			PlayVFX:FireClient(player, "Notice", nil, { Text = "Nothing there to compress", Color = Color3.fromRGB(255, 150, 120) })
			return
		end
		local hold = Destruction.Compress(point, sp.Radius or 5)
		local look = { Color = part.Color, Material = part.Material }
		local list = MC.pocket[char] or {}
		MC.pocket[char] = list
		table.insert(list, { Hold = hold, Look = look })
		setCount(char, count(char) + 1)
		broadcast("CompressTake", char, { Pos = point, Radius = sp.Radius or 5, Color = look.Color, Material = look.Material, Dir = flatten(dir, root) })
	end

	-- 1: RUBBLE THROW - a marble lobbed at the aim point; it pops back to
	-- full size on the way down and the piece of the city lands on them.
	-- Empty pocket: a rock off the street
	function Handlers.RubbleThrow(player, char, root, ability, _dir, pos)
		task.wait(0.22) -- the wind-up
		if not alive(char) then
			return
		end
		local m = MC.take(char)
		local from = root.Position + UP * 2 + root.CFrame.LookVector * 1.2
		local arc = MC.arc(char, from, pos, ability.ThrowSpeed or 90, ability.Range or 60)
		local look = m and m.Look or STREET
		broadcast("RubbleLob", char, { From = from, Vel = arc.Vel, Gravity = arc.Gravity, Land = arc.Land, LandTime = arc.LandTime, Big = m ~= nil, Color = look.Color, Material = look.Material })
		local move = Moves.current()
		task.delay(arc.LandTime, function()
			Moves.join(move)
			if not alive(char) then
				return
			end
			if m then
				MC.rubbleLand(player, char, arc.Land, ability.Radius or 7, ability.Damage or 16, arc.Dir)
			else
				-- (a rock: one of them, a knock on the head)
				for _, model in queryRadius(char, arc.Land + UP * 1.5, 4) do
					if damage(player, model, ability.RockDamage or 8, { From = arc.Land, NoKnockdown = true }) then
						stun(model, 0.4)
						break
					end
				end
			end
		end)
	end

	-- 2: SURPRISE ATTACK - the cane's pommel in the face. With room in his
	-- pocket, the trick: the cane shrinks into a marble he drops at their
	-- feet, a straight punch, and the cane pops back out under their chin -
	-- up they go - and he catches it coming down
	function Handlers.SurpriseAttack(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.15)
		local model = alive(char) and Grab.nearest(char, root, d, ability.Range or 7, 0.3)
		if not model or not damage(player, model, ability.Damage or 7, { Hitstop = 0.05, NoKnockdown = true }) then
			broadcast("CaneTrick", char, { Dir = d })
			return
		end
		stun(model, ability.Stun or 0.5)
		local trick = count(char) < (spec().Max or 3)
		broadcast("CaneTrick", char, { Target = model, Dir = d, Trick = trick })
		if not trick then
			MC.bonus(player, char, model)
			return
		end
		setCount(char, count(char) + 1) -- (the cane, for the moment)
		task.wait(0.28)
		if alive(char) and model.Parent and damage(player, model, ability.PunchDamage or 6, { NoKnockdown = true }) then
			stun(model, 0.5)
		end
		task.wait(0.27)
		if alive(char) and model.Parent and damage(player, model, ability.CaneDamage or 9, { Heavy = true, Hitstop = 0.08 }) then
			knockback(model, d * 45 + UP * 42, 0.22)
			MC.bonus(player, char, model)
		end
		task.wait(0.4) -- (the catch)
		setCount(char, count(char) - 1)
	end

	-- 3: VANISHING ACT - a hand on them and THEY'RE the marble, in his palm,
	-- untouchable. (Round 59) He keeps it: free to walk about with it
	-- (Hold.Speed) and aim; 3 again flicks it at the aim point (Throw studs at
	-- most) - at Hold.Max it goes by itself - and they pop back out there,
	-- into the street. Knocked down or stunned with it, he drops it: they pop
	-- out at his feet.
	function Handlers.VanishingAct(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local held, hold, done = nil, nil, false
		task.spawn(function()
			held, hold = HoldMoves.wait(player, char, ability)
			done = true
		end)
		local function letGo()
			local h = HoldMoves.active[player]
			if h then
				h.Released = true
			end
		end
		task.wait(0.18)
		local model = alive(char) and not done and Grab.nearest(char, root, d, ability.Range or 8, 0.3)
		local max = (ability.Hold and ability.Hold.Max) or ability.Held or 1
		local g = model and Grab.take(model, max + 1)
		if not g then
			broadcast("VanishingGrab", char, { Dir = d })
			letGo() -- (nothing in his hand: the hold's over)
			return
		end
		pocketBody(model, max + 0.6)
		broadcast("VanishingGrab", char, { Target = model, Dir = d, Held = max })
		local dropped = false
		while not done and alive(char) and model.Parent do
			task.wait()
			if char:GetAttribute("Ragdolled") or char:GetAttribute("Stunned") or char:GetAttribute("Grabbed") then
				dropped = true
				break
			end
			Grab.place(g, root.CFrame * CFrame.new(0.9, 0.5, -1.4))
		end
		if dropped or not held or not alive(char) or not model.Parent then
			letGo()
			unpocketBody(model)
			local at = g.Root.Parent and g.Root.Position or root.Position
			Grab.release(g)
			broadcast("VanishingPop", char, { Target = model, Pos = at, Dir = d, Dropped = true })
			return
		end
		-- flicked at wherever he's aiming now
		local aimDir = flatten((hold and hold.Dir) or dir, root)
		local land = landingAt(root, (hold and hold.Aim) or pos, ability.Throw or 60, char)
		local from = g.Root.Position
		broadcast("VanishingThrow", char, { Target = model, From = from, To = land, Time = 0.32 })
		fly(g, from, land, 0.32, 6)
		unpocketBody(model)
		Grab.release(g, aimDir * 18 + UP * 8, 0.15)
		if damage(player, model, ability.Damage or 18, { Heavy = true, Hitstop = 0.1, From = land }) then
			ragdoll(model, 1.6)
			MC.bonus(player, char, model)
		end
		for _, other in queryRadius(char, land, 6) do
			if other ~= model and damage(player, other, ability.SplashDamage or 6, { From = land }) then
				knockback(other, awayFrom(land, other, aimDir) * 45 + UP * 30, 0.2)
			end
		end
		Destruction.Sphere(land - UP * 1.5, 4.5, "Impact", aimDir)
		broadcast("VanishingPop", char, { Target = model, Pos = land, Dir = aimDir })
	end


	-- 4: MAGICIAN'S CHOICE - he compresses HIMSELF: a puff of smoke where he
	-- stood, the marble flies to the aim point and he pops back out there,
	-- throwing off whoever's on the spot. Untouchable on the way.
	function Handlers.MagiciansChoice(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local range, speed = ability.Range or 40, ability.Speed or 160
		local v = pos - root.Position
		if v.Magnitude > range then
			v = v.Unit * range
		end
		-- (short of a wall on the way, and never into the street)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local from = root.Position
		local hit = workspace:Raycast(from + UP, v, params)
		local to = hit and hit.Position + hit.Normal * 2.5 or from + v
		local floor = groundBelow(to + UP * 2, char)
		if to.Y < floor.Y + 2.6 then
			to = Vector3.new(to.X, floor.Y + 3, to.Z)
		end
		local flight = math.clamp((to - from).Magnitude / speed, 0.12, 0.45)
		local anchored = root.Anchored
		char:SetAttribute("Compressed", true)
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + flight + 0.25)
		root.Anchored = true
		-- (the smoke bomb at his feet: a cough of it for anyone right there)
		for _, model in queryRadius(char, from, 4) do
			damage(player, model, 3, { NoKnockdown = true, From = from })
		end
		broadcast("MagiciansFly", char, { From = from, To = to, Time = flight, Dir = d })
		local t0 = os.clock()
		while os.clock() - t0 < flight and root.Parent do
			task.wait()
			local s = math.clamp((os.clock() - t0) / flight, 0, 1)
			root.CFrame = CFrame.lookAt(from:Lerp(to, s) + UP * (5 * 4 * s * (1 - s)), to + d)
		end
		char:SetAttribute("Compressed", nil)
		if root.Parent then
			root.CFrame = CFrame.lookAt(to, to + d)
			root.Anchored = anchored
			root.AssemblyLinearVelocity = Vector3.zero
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
		for _, model in queryRadius(char, to, ability.Radius or 6) do
			if damage(player, model, ability.Damage or 8, { From = to }) then
				knockback(model, awayFrom(to, model, d) * 55 + UP * 35, 0.2)
				stun(model, 0.5)
				MC.bonus(player, char, model)
			end
		end
		broadcast("MagiciansPop", char, { Pos = to, Dir = d })
	end

	-- ULT 1: GRAND ILLUSION - MARBLE STORM: a fan of marbles thrown down the
	-- aim, each one a piece of the city coming down
	function Handlers.MarbleStorm(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local n = ability.Count or 7
		local from = root.Position + UP * 2.2
		local move = Moves.current()
		for i = 1, n do
			local a = math.rad((i - (n + 1) / 2) / math.max(n - 1, 1) * 60)
			local dd = CFrame.Angles(0, a, 0) * d
			local dist = (ability.Range or 55) * (0.45 + 0.55 * ((i * 7) % n) / n)
			local target = groundTarget(root, root.Position + dd * dist, dist + 1, char) + UP
			local arc = MC.arc(char, from, target, 95, dist + 2)
			broadcast("RubbleLob", char, { From = from, Vel = arc.Vel, Gravity = arc.Gravity, Land = arc.Land, LandTime = arc.LandTime, Big = true, Color = STREET.Color, Material = STREET.Material })
			task.delay(arc.LandTime, function()
				Moves.join(move)
				if alive(char) then
					MC.rubbleLand(player, char, arc.Land, ability.Radius or 6, ability.Damage or 12, arc.Dir)
				end
			end)
			task.wait(0.09)
			if not alive(char) then
				return
			end
		end
	end

	-- ULT 2: CURTAIN CALL - a whole slab of the city, compressed on the spot,
	-- dropped out of the sky onto the aim point
	function Handlers.CurtainCall(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = groundTarget(root, pos, ability.Range or 60, char)
		task.wait(0.35)
		if not alive(char) then
			return
		end
		-- the slab: the nearest breakable thing to him (and it's coming right
		-- back down: that piece of the street starts restoring at once)
		local part, point = Destruction.NearestBreakable(root.Position + d * 8 + UP * 4, 30)
		local look = part and { Color = part.Color, Material = part.Material } or STREET
		if point then
			Destruction.Release(Destruction.Compress(point, 9))
		end
		broadcast("CurtainSlab", char, { Pos = target, From = point, Color = look.Color, Material = look.Material, Time = 1, Dir = d })
		task.wait(1)
		if not alive(char) then
			return
		end
		for _, model in queryRadius(char, target + UP * 3, ability.Radius or 16) do
			if damage(player, model, ability.Damage or 30, { Heavy = true, Hitstop = 0.12, From = target }) then
				knockback(model, awayFrom(target, model, d) * 70 + UP * 60, 0.25)
				ragdoll(model, 1.8)
			end
		end
		Destruction.Sphere(target + UP * 2, 10, "Crater", d)
		broadcast("CurtainDrop", char, { Pos = target, Dir = d })
	end

	-- ULT 3: DISAPPEARING ACT - everyone round him is a marble in his hand
	-- for Held seconds; then he throws the lot into the street in front of
	-- him and they pop out in a heap
	function Handlers.DisappearingAct(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local held = ability.Held or 1.2
		local grabs, targets = {}, {}
		for _, model in queryRadius(char, root.Position, ability.Radius or 20) do
			local g = Grab.take(model, held + 1)
			if g then
				pocketBody(model, held)
				table.insert(grabs, g)
				table.insert(targets, model)
			end
		end
		broadcast("DisappearingGrab", char, { Targets = targets, Held = held, Dir = d })
		if #grabs == 0 then
			return
		end
		local t0 = os.clock()
		while os.clock() - t0 < held and alive(char) do
			task.wait()
			for i, g in grabs do
				Grab.place(g, root.CFrame * CFrame.new(0.9 + (i % 3) * 0.15, 0.5 + math.floor(i / 3) * 0.15, -1.4))
			end
		end
		if not alive(char) then
			for _, g in grabs do
				unpocketBody(g.Model)
				Grab.release(g)
			end
			return
		end
		local heap = landingAt(root, root.Position + d * 12, 14, char)
		local move = Moves.current()
		for i, g in grabs do
			local model = g.Model
			local spot = heap + Vector3.new(math.cos(i * 2.1), 0, math.sin(i * 2.1)) * 2
			task.spawn(function()
				Moves.join(move)
				fly(g, g.Root.Position, spot, 0.28, 5)
				unpocketBody(model)
				Grab.release(g, d * 15 + UP * 8, 0.15)
				if damage(player, model, ability.Damage or 22, { Heavy = true, Hitstop = 0.1, From = spot }) then
					ragdoll(model, 1.8)
				end
				broadcast("VanishingPop", char, { Target = model, Pos = spot, Dir = d })
			end)
			task.wait(0.08)
		end
		Destruction.Sphere(heap - UP, 6, "Impact", d)
	end

	-- (round 75) THE GRAND FINALE (SHOWTIME's 4): everyone round him is a
	-- marble in his hand; he juggles them over his head, throws the lot
	-- straight up, and they all come back down full size at once
	function Handlers.GrandFinale(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.35)
		if not alive(char) then
			return
		end
		local juggle = ability.Juggle or 1.4
		local fall = ability.Fall or 0.7
		local height = ability.Height or 70
		local total = juggle + 0.6 + fall + 1
		local grabs, targets = {}, {}
		for _, model in queryRadius(char, root.Position, ability.Radius or 30) do
			local g = Grab.take(model, total)
			if g then
				pocketBody(model, total)
				table.insert(grabs, g)
				table.insert(targets, model)
			end
		end
		broadcast("FinaleGrab", char, { Targets = targets, Juggle = juggle })
		if #grabs == 0 then
			return
		end
		-- the juggle: round and round over his head
		local t0 = os.clock()
		while os.clock() - t0 < juggle and alive(char) do
			task.wait()
			local t = os.clock() - t0
			for i, g in grabs do
				local a = t * 5 + i / #grabs * math.pi * 2
				Grab.place(g, CFrame.new(root.Position + UP * (4 + math.abs(math.sin(t * 6 + i)) * 2.5) + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.2))
			end
		end
		if not alive(char) then
			for _, g in grabs do
				unpocketBody(g.Model)
				Grab.release(g)
			end
			return
		end
		-- up they all go, out over the street round him...
		local spots = {}
		local move = Moves.current()
		for i, g in grabs do
			local a = i / #grabs * math.pi * 2 + math.atan2(d.X, d.Z)
			spots[i] = landingAt(root, root.Position + Vector3.new(math.sin(a), 0, math.cos(a)) * (6 + #grabs * 1.5), 30, char)
			task.spawn(function()
				Moves.join(move)
				fly(g, g.Root.Position, spots[i] + UP * height, 0.5, 0)
			end)
		end
		broadcast("FinaleThrow", char, { Targets = targets, Height = height })
		task.wait(0.6)
		-- ...and back down, full size, all at once
		broadcast("FinaleDrop", char, { Spots = spots, Fall = fall, Height = height })
		for i, g in grabs do
			local model, spot = g.Model, spots[i]
			task.spawn(function()
				Moves.join(move)
				fly(g, spot + UP * height, spot, fall, 0)
				unpocketBody(model)
				Grab.release(g, -UP * 20, 0.1)
				if damage(player, model, ability.Damage or 26, { Heavy = true, Hitstop = 0.1, From = spot }) then
					ragdoll(model, 2)
					stun(model, 1.2)
				end
				for _, other in queryRadius(char, spot + UP * 2, 8) do
					if not table.find(targets, other) and damage(player, other, ability.SplashDamage or 8, { From = spot }) then
						knockback(other, awayFrom(spot, other, d) * 50 + UP * 30, 0.2)
					end
				end
				Destruction.Sphere(spot - UP, 5, "Impact", -UP)
			end)
		end
	end

	-- (round 75) while SHOWTIME lasts, a marble comes back into his pocket
	-- every Ult.Refill seconds (a juggled one, from the act - no piece of
	-- the street goes with it)
	task.spawn(function()
		local last = setmetatable({}, { __mode = "k" })
		while true do
			task.wait(0.5)
			local every = ((Config.Quirks.Compress or {}).Ult or {}).Refill
			for _, plr in Players:GetPlayers() do
				local c = plr.Character
				if every and c and plr:GetAttribute("Quirk") == "Compress" and plr:GetAttribute("UltActive") == true and alive(c) then
					local now = os.clock()
					last[plr] = last[plr] or now
					if now - last[plr] >= every then
						last[plr] = now
						if count(c) < (spec().Max or 3) then
							MC.pocket[c] = MC.pocket[c] or {}
							table.insert(MC.pocket[c], { Hold = false, Look = STREET })
							setCount(c, count(c) + 1)
							broadcast("MarbleRefill", c, {})
						end
					end
				else
					last[plr] = nil
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- CHARGEBOLT (Denki Kaminari): Electrification
---------------------------------------------------------------------------
-- His Sharpshooting Gear fires POINTERS (Pointers.Max in the clip,
-- "Pointers" on his HUD): a disc that sticks to the first thing it hits -
-- a person or the map - for Pointers.Life seconds, then comes back to the
-- clip. His electricity is drawn to a pointer within Pointers.Vicinity:
-- Discharge becomes one line; a Stun Bolt into one ricochets on. ZAP TRAPS
-- (DK.traps) wait on the street for someone to step on them. After his ult
-- he's fried for a moment ("wheeey": endUlt).
do
	local DK = { placed = setmetatable({}, { __mode = "k" }), nextId = 0 } -- [char] = { { Model?, Pos, Id, Dead? } ... }
	Kit.DK = DK

	local function spec()
		return Config.Quirks.Electrification.Pointers or {}
	end
	local function clip(char)
		return tonumber(char:GetAttribute("Pointers")) or 0
	end
	local function setClip(char, n)
		char:SetAttribute("Pointers", math.clamp(n, 0, spec().Max or 2))
	end
	local function rootOf(model)
		return model and model.Parent and model:FindFirstChild("HumanoidRootPart")
	end

	function DK.remove(char, p)
		if p.Dead then
			return
		end
		p.Dead = true
		local list = DK.placed[char]
		local i = list and table.find(list, p)
		if i then
			table.remove(list, i)
		end
		if rootOf(p.Model) then
			local n = (tonumber(p.Model:GetAttribute("Pointed")) or 1) - 1
			p.Model:SetAttribute("Pointed", n > 0 and n or nil)
		end
		broadcast("PointerGone", char, { Id = p.Id, Target = p.Model })
	end
	function DK.reset(char, keepAttr)
		for _, p in table.clone(DK.placed[char] or {}) do
			DK.remove(char, p)
		end
		DK.placed[char] = nil
		if DK.clearTraps then
			DK.clearTraps(char)
		end
		if not keepAttr then
			char:SetAttribute("Pointers", nil)
		end
	end
	function DK.setup(char, mine, fresh)
		if mine then
			if fresh or char:GetAttribute("Pointers") == nil then
				DK.reset(char, true)
				setClip(char, spec().Max or 2)
			end
		elseif char:GetAttribute("Pointers") ~= nil then
			DK.reset(char)
		end
	end
	-- where a pointer is now (on someone: wherever they are)
	function DK.where(p)
		local mr = rootOf(p.Model)
		return mr and mr.Position or p.Pos
	end
	-- his pointers within `range` of `pos`, nearest first
	function DK.near(char, pos, range)
		local out = {}
		for _, p in DK.placed[char] or {} do
			local at = DK.where(p)
			if not p.Dead and (at - pos).Magnitude <= range then
				table.insert(out, { P = p, At = at, Dist = (at - pos).Magnitude })
			end
		end
		table.sort(out, function(a, b)
			return a.Dist < b.Dist
		end)
		return out
	end
	-- a pointer stuck on someone (or a spot); back in the clip after Life
	function DK.stick(char, model, pos, normal)
		DK.nextId += 1
		local life = spec().Life or 20
		local p = { Model = model, Pos = pos, Id = DK.nextId }
		local list = DK.placed[char] or {}
		DK.placed[char] = list
		table.insert(list, p)
		if model then
			model:SetAttribute("Pointed", (tonumber(model:GetAttribute("Pointed")) or 0) + 1)
		end
		broadcast("PointerStick", char, { Id = p.Id, Target = model, Pos = pos, Normal = normal, Life = life })
		task.delay(life, function()
			if not p.Dead then
				DK.remove(char, p)
				if char.Parent and char:GetAttribute("Pointers") ~= nil then
					setClip(char, clip(char) + 1)
				end
			end
		end)
		return p
	end
	-- the clip's empty: R reloads (the HUD shows it on the R slot)
	local function reload(player, char)
		if clip(char) > 0 then
			return
		end
		local wait = spec().Reload or 4
		local cds = cooldowns[player] or {}
		cooldowns[player] = cds
		cds[Config.CooldownKey("Electrification", Config.SPECIAL_INDEX)] = os.clock() + wait - (Config.Quirks.Electrification.Special.Cooldown or 0)
		PlayVFX:FireClient(player, "Reload", nil, { Index = Config.SPECIAL_INDEX, Time = wait })
	end
	-- a jolt: hurt, stunned stiff, sparking (the Shocked effect)
	function DK.shock(player, model, dmg, stunTime, opts)
		if damage(player, model, dmg, opts) then
			stun(model, stunTime)
			broadcast("Shocked", nil, { Target = model, Duration = stunTime })
			return true
		end
		return false
	end
	-- the first one along a line from `from` down `d` (within `len`)
	local function firstAlong(char, from, d, len, width)
		local best, bestAlong
		for _, model in queryRadius(char, from + d * len / 2, len / 2 + width + 2) do
			local mr = rootOf(model)
			local rel = mr and mr.Position - from
			local along = rel and rel:Dot(d)
			if along and along > 0 and along <= len + 1 and (rel - d * along).Magnitude <= width and (not bestAlong or along < bestAlong) then
				best, bestAlong = model, along
			end
		end
		return best, bestAlong
	end
	local function wallAlong(char, from, d, len)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		return workspace:Raycast(from, d * len, params)
	end

	-- R: POINTER - a disc straight down the aim, sticking to the first thing
	-- it hits (a person, or the map)
	function Handlers.Pointer(player, char, root, _ability, dir)
		if clip(char) < 1 then
			PlayVFX:FireClient(player, "Notice", nil, { Text = "No pointers: they come back when the ones out expire", Color = Color3.fromRGB(255, 150, 120) })
			return
		end
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		local from = root.Position + UP * 1.5 + d * 1.5
		local range = spec().Range or 60
		local wall = wallAlong(char, from, d, range)
		local len = wall and (wall.Position - from).Magnitude or range
		local model = firstAlong(char, from, d, len + 1, 3.2)
		setClip(char, clip(char) - 1)
		local at
		if model then
			at = rootOf(model).Position
			DK.stick(char, model, at, -d)
		elseif wall then
			at = wall.Position
			DK.stick(char, nil, at, wall.Normal)
		else
			-- (nothing in range: it clatters down at the end of its flight)
			at = from + d * range
			DK.stick(char, nil, at, UP)
		end
		broadcast("PointerShot", char, { From = from, To = at, Dir = d })
		reload(player, char)
	end

	-- 1: DISCHARGE - electricity out of his whole body; a pointer within
	-- Vicinity and it all goes down ONE line to it instead
	function Handlers.Discharge(player, char, root, ability)
		task.wait(0.25)
		if not alive(char) then
			return
		end
		local near = DK.near(char, root.Position, spec().Vicinity or 40)
		if #near == 0 and DK.dive(player, char, root, ability) then
			return -- (in the air: he came down as the bolt)
		end
		if #near == 0 then
			local center = root.Position
			for _, model in queryRadius(char, center, ability.Radius or 12) do
				if DK.shock(player, model, ability.Damage or 10, ability.Stun or 1, { From = center, NoKnockdown = true }) then
					knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 30 + UP * 20, 0.15)
				end
			end
			Destruction.Sphere(groundBelow(center, char), 4, "Scorch")
			broadcast("DischargeBurst", char, { Radius = ability.Radius or 12 })
			return
		end
		local p, to = near[1].P, near[1].At
		local from = root.Position + UP
		local v = to - from
		local d = v.Magnitude > 0.1 and v.Unit or root.CFrame.LookVector
		local len, width = v.Magnitude, ability.LineWidth or 4
		broadcast("DischargeLine", char, { From = from, To = to, Target = p.Model, Width = width })
		for _, model in queryRadius(char, from + d * len / 2, len / 2 + width + 2) do
			local mr = rootOf(model)
			local rel = mr and mr.Position - from
			local along = rel and rel:Dot(d)
			if along and along >= -1 and along <= len + 2 and (rel - d * along).Magnitude <= width + 1.5 then
				if model == p.Model then
					if damage(player, model, ability.TagDamage or 16, { Heavy = true, Hitstop = 0.08, From = from }) then
						knockback(model, d * 70 + UP * 40, 0.25)
						ragdoll(model, 1.5)
						broadcast("Shocked", nil, { Target = model, Duration = 1.5 })
					end
				else
					DK.shock(player, model, ability.LineDamage or 12, ability.LineStun or 2, { From = from, NoKnockdown = true })
				end
			end
		end
		Destruction.Capsule(from, to, 1.5, "Scorch")
	end

	-- 2: ELECTRIC GRASP - a hand on their face, filled with electricity and
	-- slammed into the street. A pointer in the clip: thrown UP instead,
	-- tagged, and the bolt after them blows them back
	function Handlers.ElectricGrasp(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.15)
		local model = alive(char) and Grab.nearest(char, root, d, ability.Range or 8, 0.3)
		local g = model and Grab.take(model, 1.6)
		if not g then
			broadcast("ElectricGraspHold", char, { Dir = d })
			return
		end
		local air = clip(char) >= 1
		broadcast("ElectricGraspHold", char, { Target = model, Dir = d, Air = air })
		if not damage(player, model, ability.Damage or 6, { NoKnockdown = true, Hitstop = 0.05 }) then
			Grab.release(g)
			return
		end
		local function hold(time, cf)
			local t0 = os.clock()
			while os.clock() - t0 < time do
				task.wait()
				if not alive(char) or not model.Parent then
					return false
				end
				Grab.place(g, root.CFrame * cf)
			end
			return true
		end
		if not air then
			-- the current, then the slam
			for _ = 1, ability.Ticks or 2 do
				if not hold(0.22, CFrame.new(0, 0.3, -2.4)) then
					Grab.release(g)
					return
				end
				damage(player, model, ability.TickDamage or 2, { NoKnockdown = true })
			end
			if not hold(0.12, CFrame.new(0, 0.9, -2.2)) then
				Grab.release(g)
				return
			end
			local down = groundBelow(root.Position + d * 3, char) + UP * 1.5
			Grab.place(g, CFrame.lookAt(down, down + d) * CFrame.Angles(math.rad(-80), 0, 0))
			Grab.release(g, d * (ability.SlamPush or 6), 0.1) -- (round 75: less)
			if damage(player, model, ability.SlamDamage or 10, { Heavy = true, Hitstop = 0.08, From = down }) then
				ragdoll(model, 1.3)
				broadcast("Shocked", nil, { Target = model, Duration = 1 })
			end
			Destruction.Sphere(down - UP, 3.5, "Impact", d)
			broadcast("GraspSlam", char, { Target = model, Pos = down, Dir = d })
			return
		end
		if not hold(0.2, CFrame.new(0, 0.3, -2.4)) then
			Grab.release(g)
			return
		end
		setClip(char, clip(char) - 1)
		local up = root.Position + d * 3 + UP * (ability.Lift or 26)
		local from = g.Root.Position
		local t0 = os.clock()
		while os.clock() - t0 < 0.3 and model.Parent do
			task.wait()
			local s = math.clamp((os.clock() - t0) / 0.3, 0, 1)
			Grab.place(g, CFrame.new(from:Lerp(up, 1 - (1 - s) ^ 2)))
		end
		DK.stick(char, model, up, -UP)
		broadcast("PointerShot", char, { From = root.Position + UP * 1.5, To = up, Dir = (up - root.Position).Unit })
		task.wait(0.15)
		reload(player, char)
		if not model.Parent then
			Grab.release(g)
			return
		end
		broadcast("GraspBolt", char, { Target = model, From = root.Position + UP * 1.5, To = up })
		-- (Push studs in the 0.3s shove, with a move's knockback scaled the way it is)
		Grab.release(g, d * ((ability.Push or 13) / 0.3 / ((Config.Knockback or {}).MoveScale or 1)) + UP * 9, 0.3) -- (round 75: less)
		if damage(player, model, ability.BoltDamage or 14, { Heavy = true, Hitstop = 0.1, From = root.Position }) then
			ragdoll(model, 1.5)
			broadcast("Shocked", nil, { Target = model, Duration = 1.5 })
		end
	end

	-- 1 in the air: THUNDER DIVE - he comes down as a bolt of lightning onto
	-- the street under him and it all goes off where he lands (AirRadius,
	-- AirDamage). Only with AirHeight studs or more under him.
	function DK.dive(player, char, root, ability)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -300, 0), params)
		local drop = hit and root.Position.Y - hit.Position.Y - 3
		if not drop or drop < (ability.AirHeight or 6) then
			return false
		end
		local from, land = root.Position, hit.Position + UP * 3
		local time = math.clamp(drop / (ability.DiveSpeed or 160), 0.06, 0.6)
		local anchored = root.Anchored
		root.Anchored = true
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + time + 0.1)
		broadcast("ThunderDive", char, { From = from, To = land, Time = time })
		local look = flatten(root.CFrame.LookVector, root)
		local t0 = os.clock()
		while os.clock() - t0 < time and root.Parent do
			task.wait()
			local k = math.clamp((os.clock() - t0) / time, 0, 1)
			local at = from:Lerp(land, k * k)
			root.CFrame = CFrame.lookAt(at, at + look)
		end
		if root.Parent then
			root.CFrame = CFrame.lookAt(land, land + look)
			root.Anchored = anchored
			root.AssemblyLinearVelocity = Vector3.zero
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
		if not alive(char) then
			return true
		end
		local center = land
		local radius = ability.AirRadius or 16
		for _, model in queryRadius(char, center, radius) do
			if DK.shock(player, model, ability.AirDamage or 13, ability.Stun or 1, { From = center, Heavy = true, Hitstop = 0.06 }) then
				knockback(model, awayFrom(center, model, look) * 55 + UP * 30, 0.2)
			end
		end
		Destruction.Sphere(hit.Position, 6, "Scorch")
		Destruction.Sphere(hit.Position, 4, "Impact", -UP)
		broadcast("DischargeBurst", char, { Radius = radius, Air = true })
		return true
	end

	-- 3: ZAP TRAP - a trap on the street where he's aiming. Once it's armed,
	-- whoever steps on it (Radius) is jolted stiff and it's spent. Max out at
	-- once (a new one replaces the oldest); gone after Life. Set down near one
	-- of his pointers (WireRange): a live wire runs from the trap to the
	-- pointer, and crossing it jolts you too. A Stun Bolt into a trap
	-- overloads it (DK.overload).
	DK.traps = setmetatable({}, { __mode = "k" }) -- [char] = { { Id, Pos, Player, ArmAt, Expires, Wire?, WireHit } ... }
	local function trapSpec()
		for _, a in Config.Quirks.Electrification.Abilities do
			if a.Id == "ZapTrap" then
				return a
			end
		end
		return {}
	end
	function DK.removeTrap(char, t, how)
		if t.Dead then
			return
		end
		t.Dead = true
		local list = DK.traps[char]
		local i = list and table.find(list, t)
		if i then
			table.remove(list, i)
		end
		broadcast("ZapTrapGone", char, { Id = t.Id, Pos = t.Pos, How = how })
	end
	function DK.clearTraps(char)
		for _, t in table.clone(DK.traps[char] or {}) do
			DK.removeTrap(char, t)
		end
		DK.traps[char] = nil
	end
	-- distance from p to the segment a-b
	local function toSegment(p, a, b)
		local ab = b - a
		local len2 = ab:Dot(ab)
		local k = len2 > 1e-6 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
		return (p - (a + ab * k)).Magnitude
	end
	-- (round 68) THE FENCE: with two or more of his traps armed, an unseen
	-- current runs between every pair of them (at most FenceRange apart) -
	-- walk, run or dash through it and you're jolted (FenceDamage, FenceStun;
	-- once every FenceEvery seconds). Caught by being in the line or by being
	-- on the other side of it than a moment ago (so a dash can't skip it).
	-- Only he sees it; crossing it lights it up for everyone.
	DK.fenceSide = setmetatable({}, { __mode = "k" }) -- [trap] = { [trap] = { [model] = { side, at } } }
	DK.fenceHit = setmetatable({}, { __mode = "k" }) -- [model] = os.clock() when it can jolt them again
	function DK.fences(list, now)
		local spec = trapSpec()
		local range = spec.FenceRange or 40
		local armed = {}
		for _, t in list do
			if not t.Dead and now >= t.ArmAt then
				table.insert(armed, t)
			end
		end
		local out = {}
		for i = 1, #armed - 1 do
			for j = i + 1, #armed do
				local a, b = armed[i], armed[j]
				local ab = Vector3.new(b.Pos.X - a.Pos.X, 0, b.Pos.Z - a.Pos.Z)
				if ab.Magnitude > 0.5 and ab.Magnitude <= range then
					table.insert(out, { a, b })
				end
			end
		end
		return out
	end
	function DK.checkFences(char, list)
		local now = os.clock()
		local pairsNow = DK.fences(list, now)
		if #pairsNow == 0 then
			return
		end
		local spec = trapSpec()
		local width, height = spec.FenceWidth or 1.6, spec.FenceHeight or 9
		for _, pair in pairsNow do
			local a, b = pair[1], pair[2]
			local pa, pb = a.Pos, b.Pos
			local ab = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
			local len = ab.Magnitude
			local sides = DK.fenceSide[a] or setmetatable({}, { __mode = "k" })
			DK.fenceSide[a] = sides
			local memo = sides[b] or setmetatable({}, { __mode = "k" })
			sides[b] = memo
			for _, model in queryRadius(char, (pa + pb) / 2 + UP * 3, len / 2 + 8) do
				local mr = rootOf(model)
				if mr then
					local rel = mr.Position - pa
					local along = (rel.X * ab.X + rel.Z * ab.Z) / (len * len)
					local off = (ab.X * rel.Z - ab.Z * rel.X) / len -- (signed: which side, and how far)
					local k = math.clamp(along, 0, 1)
					local onLine = pa + (pb - pa) * k
					local dy = mr.Position.Y - onLine.Y
					local inSpan = along >= -0.03 and along <= 1.03 and dy > -2.5 and dy < height
					local side = off >= 0 and 1 or -1
					local last = memo[model]
					memo[model] = { side, now }
					local crossed = last ~= nil and last[1] ~= side and now - last[2] < 0.35
					if inSpan and (crossed or math.abs(off) <= width) and (DK.fenceHit[model] or 0) <= now then
						DK.fenceHit[model] = now + (spec.FenceEvery or 1)
						DK.shock(a.Player, model, spec.FenceDamage or 7, spec.FenceStun or 0.9, { From = onLine + UP * 2, NoKnockdown = true })
						broadcast("ZapTrapFenceJolt", char, { A = a.Id, B = b.Id, PA = pa, PB = pb, Target = model, Pos = onLine })
					end
				end
			end
		end
	end
	-- one pass over every trap: triggered, wired, expired
	function DK.checkTraps()
		local now = os.clock()
		for char, list in DK.traps do
			if not char.Parent then
				DK.traps[char] = nil
				continue
			end
			for _, t in table.clone(list) do
				if t.Dead then
					continue
				end
				if now >= t.Expires then
					DK.removeTrap(char, t, "Expired")
					continue
				end
				local spec3 = t.Spec
				-- the live wire to a pointer
				if t.Wire then
					local p = t.Wire
					local to = not p.Dead and DK.where(p)
					if not to or (to - t.Pos).Magnitude > (spec3.WireRange or 30) * 1.3 then
						t.Wire = nil
						broadcast("ZapTrapWireCut", char, { Id = t.Id })
					else
						local a = t.Pos + UP * 1.2
						for _, model in queryRadius(char, (a + to) / 2, (to - a).Magnitude / 2 + 4) do
							local mr = model ~= p.Model and rootOf(model)
							if mr and (t.WireHit[model] or 0) <= now and toSegment(mr.Position, a, to) <= 2.4 then
								t.WireHit[model] = now + (spec3.WireEvery or 1.2)
								DK.shock(t.Player, model, spec3.WireDamage or 6, spec3.WireStun or 1.2, { From = mr.Position, NoKnockdown = true })
								broadcast("ZapTrapWireJolt", char, { Id = t.Id, Target = model })
							end
						end
					end
				end
				-- stepped on
				if now >= t.ArmAt then
					local caught = {}
					for _, model in queryRadius(char, t.Pos + UP * 2.5, (spec3.Radius or 5) + 2) do
						local mr = rootOf(model)
						local rel = mr and mr.Position - t.Pos
						if rel and Vector3.new(rel.X, 0, rel.Z).Magnitude <= (spec3.Radius or 5) and rel.Y > -2 and rel.Y < 6 then
							table.insert(caught, model)
						end
					end
					if #caught > 0 then
						DK.removeTrap(char, t, "Snap")
						broadcast("ZapTrapSnap", char, { Id = t.Id, Pos = t.Pos, Targets = caught })
						for _, model in caught do
							DK.shock(t.Player, model, spec3.Damage or 8, spec3.Stun or 1.8, { From = t.Pos, NoKnockdown = true, Hitstop = 0.05 })
						end
					end
				end
			end
			DK.checkFences(char, list) -- (round 68)
			if #list == 0 then
				DK.traps[char] = nil
			end
		end
	end
	local trapClock = 0
	RunService.Heartbeat:Connect(function(dt)
		trapClock += dt
		if trapClock < 0.05 or next(DK.traps) == nil then
			return
		end
		trapClock = 0
		DK.checkTraps()
	end)
	function DK.placeTrap(player, char, pos, ability)
		local list = DK.traps[char] or {}
		DK.traps[char] = list
		while #list >= (ability.Max or 2) do
			DK.removeTrap(char, list[1], "Replaced")
		end
		DK.nextId += 1
		local t = {
			Id = DK.nextId, Pos = pos, Player = player, Spec = ability,
			ArmAt = os.clock() + (ability.ArmTime or 0.5), Expires = os.clock() + (ability.Life or 25), WireHit = {},
		}
		-- near a pointer: the live wire
		local near = DK.near(char, pos, ability.WireRange or 30)
		t.Wire = near[1] and near[1].P or nil
		table.insert(list, t)
		broadcast("ZapTrapSet", char, {
			Id = t.Id, Pos = pos, Arm = ability.ArmTime or 0.5, Life = ability.Life or 25,
			WireTo = t.Wire and (t.Wire.Model or DK.where(t.Wire)) or nil,
		})
		return t
	end
	function Handlers.ZapTrap(player, char, root, ability, _dir, pos)
		local spot = groundTarget(root, typeof(pos) == "Vector3" and pos or root.Position + root.CFrame.LookVector * 8, ability.Range or 16, char)
		task.wait(0.22)
		if not alive(char) then
			return
		end
		DK.placeTrap(player, char, spot, ability)
	end
	-- a Stun Bolt into his own trap: it overloads - a burst all round it
	function DK.overload(player, char, t)
		local zt = trapSpec()
		DK.removeTrap(char, t, "Overload")
		local radius = zt.OverRadius or 14
		broadcast("ZapTrapOverload", char, { Id = t.Id, Pos = t.Pos, Radius = radius })
		for _, model in queryRadius(char, t.Pos + UP * 2, radius) do
			if damage(player, model, zt.OverDamage or 18, { Heavy = true, Hitstop = 0.08, From = t.Pos }) then
				knockback(model, awayFrom(t.Pos, model, UP) * 50 + UP * 45, 0.22)
				ragdoll(model, 1.2)
				broadcast("Shocked", nil, { Target = model, Duration = 1.2 })
			end
		end
		Destruction.Sphere(t.Pos, 4, "Scorch")
	end
	-- a bolt bouncing on: from `at` to the nearest one within RicochetRange
	-- not hit yet, and from them to the next... (Ricochets of them)
	function DK.ricochet(player, char, at, points, hit, ability)
		local chain = {}
		local last = at
		for _ = 1, ability.Ricochets or 4 do
			local best, bestDist
			for _, model in queryRadius(char, last, ability.RicochetRange or 10) do
				local mr = not hit[model] and rootOf(model)
				local dist = mr and (mr.Position - last).Magnitude
				if dist and (not bestDist or dist < bestDist) then
					best, bestDist = model, dist
				end
			end
			if not best then
				break
			end
			hit[best] = true
			last = rootOf(best).Position
			table.insert(points, last)
			table.insert(chain, best)
		end
		local move = Moves.current()
		local base = #points - #chain
		for k, model in chain do
			task.delay(0.08 * k, function()
				Moves.join(move)
				if model.Parent and alive(char) then
					DK.shock(player, model, ability.RicochetDamage or 7, (ability.Stun or 1.4) * 0.8, { From = points[base + k - 1], NoKnockdown = true })
				end
			end)
		end
		return #chain
	end

	-- 4: STUN BOLT - a finger gun: one bolt down the aim; the first one it
	-- hits is jolted stiff, and it jumps to the next within ChainRange
	function Handlers.StunBolt(player, char, root, ability, dir)
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		local from = root.Position + UP * 1.4
		local range = ability.Range or 45
		local wall = wallAlong(char, from, d, range)
		local len = wall and (wall.Position - from).Magnitude or range
		local first, firstAt = firstAlong(char, from, d, len, 3.5)
		-- his own things on the line before that: a pointer on the map (the
		-- bolt ricochets off it) or a trap (it overloads)
		local reach = firstAt or len
		local relay, relayAt, relayTrap
		local function consider(pos, rec, isTrap)
			local rel = pos - from
			local along = rel:Dot(d)
			if along > 0 and along <= reach + 1 and (rel - d * along).Magnitude <= (ability.RelayWidth or 3.5) and (not relayAt or along < relayAt) then
				relay, relayAt, relayTrap = rec, along, isTrap
			end
		end
		for _, p in DK.placed[char] or {} do
			if not p.Dead and not rootOf(p.Model) then
				consider(p.Pos, p, false)
			end
		end
		for _, t in DK.traps[char] or {} do
			if not t.Dead then
				consider(t.Pos + UP * 0.6, t, true)
			end
		end
		if relay and relayTrap then
			broadcast("StunBoltHit", char, { Points = { from, relay.Pos + UP * 0.6 }, Hit = true, Trap = true })
			DK.overload(player, char, relay)
			return
		end
		if relay then
			local points = { from, relay.Pos }
			local n = DK.ricochet(player, char, relay.Pos, points, {}, ability)
			broadcast("StunBoltHit", char, { Points = points, Hit = n > 0, Relay = 2 })
			return
		end
		local to = first and rootOf(first).Position or from + d * len
		local points = { from, to }
		if first and DK.shock(player, first, ability.Damage or 9, ability.Stun or 1.4, { From = from, NoKnockdown = true }) then
			if (tonumber(first:GetAttribute("Pointed")) or 0) > 0 then
				-- a pointer on them: it relays the bolt on and on
				DK.ricochet(player, char, to, points, { [first] = true }, ability)
				broadcast("StunBoltHit", char, { Points = points, Hit = true, Relay = 2 })
				return
			end
			local second, best
			for _, model in queryRadius(char, to, ability.ChainRange or 10) do
				local mr = model ~= first and rootOf(model)
				local dist = mr and (mr.Position - to).Magnitude
				if dist and (not best or dist < best) then
					second, best = model, dist
				end
			end
			if second then
				table.insert(points, rootOf(second).Position)
				task.delay(0.1, function()
					if second.Parent then
						DK.shock(player, second, ability.ChainDamage or 6, (ability.Stun or 1.4) * 0.7, { From = to, NoKnockdown = true })
					end
				end)
			end
		end
		broadcast("StunBoltHit", char, { Points = points, Hit = first ~= nil })
	end

	-- ULT 1: INDISCRIMINATE DISCHARGE - the works, all round him
	function Handlers.IndiscriminateDischarge(player, char, root, ability)
		task.wait(0.45)
		if not alive(char) then
			return
		end
		local center = root.Position
		for _, model in queryRadius(char, center, ability.Radius or 34) do
			if damage(player, model, ability.Damage or 26, { Heavy = true, Hitstop = 0.1, From = center }) then
				knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 80 + UP * 45, 0.25)
				ragdoll(model, 1.8)
				broadcast("Shocked", nil, { Target = model, Duration = 1.8 })
			end
		end
		local g = groundBelow(center, char)
		Destruction.Sphere(g, 9, "Scorch")
		Destruction.Sphere(g + UP, 5, "Explosion")
		broadcast("IndiscriminateBoom", char, { Radius = ability.Radius or 34 })
	end

	-- ULT 2: LIGHTNING ROD - lightning out of the sky onto the aim point and
	-- onto every pointer he has out
	function Handlers.LightningRod(player, char, root, ability, _dir, pos)
		task.wait(0.35)
		if not alive(char) then
			return
		end
		local spots = { groundTarget(root, pos, ability.Range or 70, char) }
		for _, p in DK.placed[char] or {} do
			if not p.Dead then
				table.insert(spots, DK.where(p))
			end
		end
		broadcast("LightningStrikes", char, { Spots = spots })
		local move = Moves.current()
		for i, spot in spots do
			task.delay(0.25 + (i - 1) * 0.12, function()
				Moves.join(move)
				if not alive(char) then
					return
				end
				for _, model in queryRadius(char, spot + UP * 2, ability.Radius or 8) do
					if damage(player, model, ability.Damage or 20, { Heavy = true, Hitstop = 0.08, From = spot }) then
						knockback(model, awayFrom(spot, model, UP) * 40 + UP * 50, 0.22)
						broadcast("Shocked", nil, { Target = model, Duration = 1.2 })
					end
				end
				Destruction.Sphere(spot, 4.5, "Explosion")
			end)
		end
	end

	-- ULT 3: CHAIN LIGHTNING - a bolt into the nearest one, and from them to
	-- the next within JumpRange, and the next...
	function Handlers.ChainLightning(player, char, root, ability)
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local points, chain, hit = { root.Position + UP * 1.5 }, {}, {}
		local last = root.Position
		for _ = 1, ability.Jumps or 6 do
			local best, bestDist
			for _, model in queryRadius(char, last, ability.JumpRange or 30) do
				local mr = not hit[model] and rootOf(model)
				local dist = mr and (mr.Position - last).Magnitude
				if dist and (not bestDist or dist < bestDist) then
					best, bestDist = model, dist
				end
			end
			if not best then
				break
			end
			hit[best] = true
			last = rootOf(best).Position
			table.insert(points, last)
			table.insert(chain, best)
		end
		broadcast("ChainBolts", char, { Points = points })
		local move = Moves.current()
		for k, model in chain do
			task.delay((k - 1) * 0.09, function()
				Moves.join(move)
				if model.Parent and alive(char) then
					DK.shock(player, model, ability.Damage or 16, ability.Stun or 1.5, { Hitstop = 0.06, From = points[k] })
				end
			end)
		end
	end
end


---------------------------------------------------------------------------
-- ENDEAVOR (Enji Todoroki): Hellflame - and DABI (Toya Todoroki): Blueflame
---------------------------------------------------------------------------
-- Endeavor HEATS UP (Config.Quirks.Hellflame.Heat): every fire move adds
-- its Heat ("Heat" on him, his HUD's gauge); it bleeds off once he's gone a
-- moment without fire. At the top he OVERHEATS ("Overheated"): slowed, his
-- fire won't come. The Prominence Burns vent it all - and hit harder the
-- hotter he was. Dabi's fire SEARS him: every move costs him SelfBurn
-- health (never the last of it); in his ult he burns all over instead
-- (Ult.Drain a second, down to Ult.Floor of his health).
do
	local HF = { last = setmetatable({}, { __mode = "k" }), slowTokens = setmetatable({}, { __mode = "k" }), fistId = 0 }
	Kit.HF = HF

	local function heatSpec()
		return (Config.Quirks.Hellflame and Config.Quirks.Hellflame.Heat) or {}
	end
	function HF.setup(char, mine, fresh)
		if mine then
			if fresh or char:GetAttribute("Heat") == nil then
				char:SetAttribute("Heat", 0)
			end
		elseif char:GetAttribute("Heat") ~= nil then
			char:SetAttribute("Heat", nil)
			char:SetAttribute("Overheated", nil)
		end
	end
	-- (a fire move while overheated: refused)
	function HF.refuse(player, char, quirkName, ability)
		if quirkName == "Hellflame" and ability.Heat and char:GetAttribute("Overheated") then
			PlayVFX:FireClient(player, "Notice", nil, { Text = "OVERHEATED - your fire won't come till you cool down", Color = Color3.fromRGB(255, 140, 90) })
			return true
		end
		return false
	end
	-- a move went: heat him up / sear him
	function HF.used(player, char, quirkName, ability)
		if quirkName == "Hellflame" and ability.Heat then
			HF.heat(player, char, ability.Heat)
		elseif quirkName == "Blueflame" and ability.SelfBurn and not player:GetAttribute("UltActive") then
			HF.sear(player, char, ability.SelfBurn)
		end
	end
	function HF.heat(player, char, amount)
		local S = heatSpec()
		local q = Config.Quirks.Hellflame
		local scale = player:GetAttribute("UltActive") and q and q.Ult and q.Ult.HeatScale or 1
		local max = S.Max or 100
		local heat = math.min((tonumber(char:GetAttribute("Heat")) or 0) + amount * scale, max)
		char:SetAttribute("Heat", heat)
		HF.last[char] = os.clock()
		if heat >= max and not char:GetAttribute("Overheated") then
			HF.overheat(char)
		end
	end
	function HF.overheat(char)
		local S = heatSpec()
		local lock = S.Lock or 2.5
		char:SetAttribute("Overheated", true)
		local token = (HF.slowTokens[char] or 0) + 1
		HF.slowTokens[char] = token
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and not char:GetAttribute("Stunned") then
			hum.WalkSpeed = S.Slow or 8
		end
		broadcast("Overheat", char, { Time = lock })
		task.delay(lock, function()
			if HF.slowTokens[char] ~= token or not char.Parent then
				return
			end
			char:SetAttribute("Overheated", nil)
			if char:GetAttribute("Heat") ~= nil then
				char:SetAttribute("Heat", S.Reset or 55)
			end
			local h = char:FindFirstChildOfClass("Humanoid")
			if h and not char:GetAttribute("Stunned") then
				h.WalkSpeed = char:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
			end
		end)
	end
	-- Prominence Burn: all of it out - how hot he was (0..1), and he's cold
	function HF.vent(char)
		local max = heatSpec().Max or 100
		local hot = math.clamp((tonumber(char:GetAttribute("Heat")) or 0) / max, 0, 1)
		if char:GetAttribute("Heat") ~= nil then
			char:SetAttribute("Heat", 0)
		end
		return hot
	end
	function HF.sear(player, char, amount)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 1 or player:GetAttribute("GodMode") then
			return
		end
		hum.Health = math.max(hum.Health - amount, 1)
		broadcast("Seared", char, { Amount = amount })
	end
	-- cooling off (Endeavor) and burning up (Dabi's ult)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			local S = heatSpec()
			for _, plr in Players:GetPlayers() do
				local ch = plr.Character
				local heat = ch and tonumber(ch:GetAttribute("Heat"))
				if heat and heat > 0 and not ch:GetAttribute("Overheated") and os.clock() - (HF.last[ch] or 0) > (S.CoolDelay or 1.6) then
					ch:SetAttribute("Heat", math.max(heat - (S.Cool or 10) * 0.25, 0))
				end
				local ult = ch and plr:GetAttribute("UltActive") and plr:GetAttribute("Quirk") == "Blueflame" and Config.Quirks.Blueflame.Ult
				local hum = ult and ch:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and not plr:GetAttribute("GodMode") then
					local floor = hum.MaxHealth * (ult.Floor or 0.15)
					if hum.Health > floor then
						hum.Health = math.max(hum.Health - (ult.Drain or 1.5) * 0.25, floor)
						if tick % 6 == 0 then
							broadcast("Seared", ch, { Amount = 1 })
						end
					end
				end
			end
		end
	end)

	-- the street under a point high in the air (groundBelow only looks 40 down)
	function HF.floor(pos, char)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local hit = workspace:Raycast(pos, Vector3.new(0, -600, 0), params)
		return hit and hit.Position or groundBelow(pos, char)
	end

	-- which way a move goes: along the street; in the air he can aim it down
	function HF.aim(dir, root, cast)
		local d = flatten(dir, root)
		if cast and cast.Air and typeof(dir) == "Vector3" and dir.Magnitude > 0.1 then
			d = (d + UP * math.clamp(dir.Unit.Y, -0.85, 0.35)).Unit
		end
		return d
	end
	-- everyone in a fan in front: within range, within spread degrees of d
	-- (flat), and not far off the line up or down
	function HF.fan(char, origin, d, range, spread)
		local out = {}
		local flatD = Vector3.new(d.X, 0, d.Z)
		flatD = flatD.Magnitude > 1e-3 and flatD.Unit or Vector3.new(0, 0, -1)
		local cosHalf = math.cos(math.rad(math.min(spread / 2 + 6, 89)))
		for _, model in queryRadius(char, origin + d * range / 2, range / 2 + 4) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr then
				local v = mr.Position - origin
				local flat = Vector3.new(v.X, 0, v.Z)
				local slope = flat.Magnitude * (d.Y / math.max(math.sqrt(1 - d.Y * d.Y), 0.2))
				if v.Magnitude <= range + 2 and (flat.Magnitude < 3 or flat.Unit:Dot(flatD) >= cosHalf) and math.abs(v.Y - slope) < 9 then
					table.insert(out, model)
				end
			end
		end
		return out
	end
	-- the first one along a line, or the first wall: where a thrown fist goes off
	function HF.firstAlong(char, from, d, range, width)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local wall = workspace:Raycast(from, d * range, params)
		local len = wall and wall.Distance or range
		local best, bestAlong
		for _, model in queryRadius(char, from + d * len / 2, len / 2 + width + 2) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			local rel = mr and mr.Position - from
			local along = rel and rel:Dot(d)
			if along and along > 0 and along <= len and (rel - d * along).Magnitude <= width and (not bestAlong or along < bestAlong) then
				best, bestAlong = model, along
			end
		end
		return best, bestAlong or len
	end
	-- the rush in (Vanishing Fist, Dabi's Jet Burn): the first one reached
	function HF.rush(player, char, root, d, range, speed)
		local time = range / speed
		tunnel(char, root, time, 4, 5, function()
			return d
		end)
		local target, hitSet = nil, {}
		local t0 = os.clock()
		while not target and os.clock() - t0 < time + 0.05 and alive(char) do
			target = Rewind.QueryRadius(player, char, root.Position + d * 2.5, 6, hitSet)[1]
			if not target then
				task.wait(0.03)
			end
		end
		return target
	end
	-- a fist of fire thrown down d: it flies, and goes off where it stops
	function HF.throwFist(player, char, root, ability, d, pal, scale)
		local from = root.Position + d * 3 + UP
		local _, along = HF.firstAlong(char, from, d, ability.Range or 110, 6)
		local to = from + d * along
		local time = along / (ability.Speed or 170)
		HF.fistId += 1
		local id = HF.fistId
		broadcast("FlameFistFly", char, { From = from, To = to, Time = time, Pal = pal, Scale = scale, Id = id })
		task.wait(time)
		local radius = ability.Radius or 16
		broadcast("FlameFistBoom", char, { Pos = to, Radius = radius, Pal = pal, Id = id })
		for _, model in queryRadius(char, to, radius) do
			if damage(player, model, ability.Damage or 30, { Heavy = true, Hitstop = 0.1, From = to }) then
				knockback(model, awayFrom(to, model, d) * 110 + UP * 60, 0.26)
				ragdoll(model, 1.8)
				burn(model, ability.BurnTicks, ability.BurnDamage, pal)
			end
		end
		Destruction.Sphere(to, radius * 0.6, "BigExplosion", d)
	end

	-- HELL SPIDER: the threads, swept across; everyone in the fan is cut
	-- Hits times (the last one throws them back), and so is the city
	function HF.spider(player, char, root, ability, d, pal, blast)
		local range, spread = ability.Range or 42, ability.Spread or 40
		local hits = ability.Hits or 3
		local targets = HF.fan(char, root.Position, d, range, spread)
		for i = 1, hits do
			for _, model in targets do
				local last = i == hits
				if damage(player, model, ability.Damage or 5, { From = root.Position, Hitstop = last and 0.06 or 0.02, NoKnockdown = not last }) then
					if last then
						knockback(model, d * 45 + UP * 18, 0.18)
						burn(model, ability.BurnTicks, ability.BurnDamage, pal)
					else
						stun(model, 0.45)
					end
				end
			end
			task.wait(0.08)
		end
		for k = -2, 2 do
			local dd = CFrame.fromAxisAngle(UP, math.rad(k * spread / 4)) * d
			local cf = CFrame.lookAt(root.Position, root.Position + dd) * CFrame.new(0, 1, -range / 2)
			Destruction.Box(cf, Vector3.new(0.8, 7, range), "Slash", dd)
		end
		if blast then
			task.wait(0.3)
			for _, model in HF.fan(char, root.Position, d, range, spread) do
				if damage(player, model, blast, { Heavy = true, From = root.Position, Hitstop = 0.08 }) then
					knockback(model, d * 70 + UP * 45, 0.22)
					burn(model, ability.BurnTicks, ability.BurnDamage, pal)
				end
			end
		end
	end
	function Handlers.HellSpider(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.26)
		if alive(char) then
			HF.spider(player, char, root, ability, d, "hell")
		end
	end
	function Handlers.HellSpiderWeb(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.33)
		if alive(char) then
			HF.spider(player, char, root, ability, d, "hell", ability.BlastDamage or 12)
		end
	end

	-- JET BURN: a torrent down the aim - Ticks hits, the last one throws them
	function Handlers.JetBurn(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.2)
		local len, wid = ability.Range or 60, ability.Width or 10
		local ticks = ability.Ticks or 4
		for i = 1, ticks do
			if not alive(char) then
				return
			end
			local from = root.Position + d * 1.5
			local cf = CFrame.lookAt(from, from + d) * CFrame.new(0, 0, -len / 2)
			local last = i == ticks
			for _, model in queryBox(char, cf, Vector3.new(wid, wid, len)) do
				if damage(player, model, (ability.Damage or 20) / ticks, { From = from, Hitstop = 0.02, NoKnockdown = not last }) then
					knockback(model, d * (last and 75 or 22) + UP * (last and 28 or 6), 0.16)
					if last then
						burn(model, ability.BurnTicks, ability.BurnDamage, "hell")
					end
				end
			end
			if i == 1 then
				Destruction.Box(cf, Vector3.new(wid * 0.8, wid * 0.7, len), "Scorch", d)
			end
			task.wait((ability.Duration or 0.7) / ticks)
		end
	end

	-- VANISHING FIST: the rush with his fire out, then the fist
	function Handlers.VanishingFist(player, char, root, ability, dir)
		local d = flatten(dir, root)
		local target = HF.rush(player, char, root, d, ability.Range or 34, ability.Speed or 150)
		if not alive(char) then
			return
		end
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		local at = troot and troot.Position or (root.Position + d * 4)
		broadcast("VanishingFistHit", char, { Target = target, Dir = d, At = at })
		if target and damage(player, target, ability.Damage or 26, { Heavy = true, Hitstop = 0.14, From = root.Position }) then
			knockback(target, d * 130 + UP * 50, 0.26)
			ragdoll(target, 1.6)
			burn(target, ability.BurnTicks, ability.BurnDamage, "hell")
		end
		for _, model in queryRadius(char, at + d * 4, ability.Radius or 11) do
			if model ~= target and damage(player, model, ability.SplashDamage or 8, { From = at, Hitstop = 0.05 }) then
				knockback(model, (awayFrom(at, model, d) + d).Unit * 70 + UP * 30, 0.2)
				burn(model, ability.BurnTicks, ability.BurnDamage, "hell")
			end
		end
		Destruction.Sphere(at + d * 3, 9, "Explosion", d)
	end

	-- HELL'S CURTAIN: the sheet of fire, then the wall it leaves standing
	function Handlers.HellsCurtain(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.34)
		if not alive(char) then
			return
		end
		local width, range = ability.Width or 38, ability.Range or 24
		local origin = root.Position
		local cf = CFrame.lookAt(origin, origin + d) * CFrame.new(0, 2, -range / 2)
		for _, model in queryBox(char, cf, Vector3.new(width, 14, range + 4)) do
			if damage(player, model, ability.Damage or 12, { From = origin, Heavy = true, Hitstop = 0.05 }) then
				knockback(model, d * 90 + UP * 35, 0.2)
				burn(model, ability.BurnTicks, ability.BurnDamage, "hell")
			end
		end
		Destruction.Box(cf, Vector3.new(width, 5, range), "Scorch", d)
		local wall = CFrame.lookAt(origin + d * range, origin + d * (range + 1)) * CFrame.new(0, 3, 0)
		local lastHit = {}
		local t0 = os.clock()
		while os.clock() - t0 < (ability.Duration or 4) and char.Parent do
			task.wait(0.25)
			for _, model in queryBox(char, wall, Vector3.new(width, 10, 5)) do
				if os.clock() - (lastHit[model] or 0) > 0.5 then
					lastHit[model] = os.clock()
					if damage(player, model, ability.TickDamage or 4, { From = wall.Position, NoKnockdown = true, Unblockable = true }) then
						burn(model, 1, 2, "hell")
					end
				end
			end
		end
	end

	-- ult: VANISHING JET BURN - the fist thrown
	function Handlers.VanishingJetBurn(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.42)
		if alive(char) then
			HF.throwFist(player, char, root, ability, d, "hell", 9)
		end
	end

	-- ult: PROMINENCE BURN - everything, out of his whole body (and it
	-- vents his heat: the hotter he was, the harder)
	function Handlers.ProminenceNova(player, char, root, ability)
		task.wait(0.7)
		if not alive(char) then
			return
		end
		local hot = HF.vent(char)
		local dmg = (ability.Damage or 38) * (1 + hot * (heatSpec().PerHeat or 0.6))
		local center = root.Position
		local radius = ability.Radius or 34
		broadcast("ProminenceNovaBurst", char, { Pos = center, Radius = radius, Heat = hot })
		for _, model in queryRadius(char, center, radius) do
			if damage(player, model, dmg, { Heavy = true, Hitstop = 0.12, From = center }) then
				knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 140 + UP * 75, 0.28)
				ragdoll(model, 2)
				burn(model, ability.BurnTicks, ability.BurnDamage, "hell")
			end
		end
		Destruction.Sphere(center, radius * 0.5, "Fire")
		Destruction.Cylinder(center + UP * 40, radius * 0.25, 80, "Fire", UP)
	end

	-- ult 4: PLUS ULTRA: PROMINENCE BURN - he takes hold of whoever's in
	-- front, rockets straight up with them, and lets it all out up there;
	-- they come down into the street. Nobody to take: he brings it down.
	function Handlers.SkyProminence(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.25)
		if not alive(char) then
			return
		end
		local rise = ability.Rise or 1.1
		local target = Grab.nearest(char, root, d, ability.Reach or 12, 0.3)
		local g = target and Grab.take(target, rise + 1.2)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local anchored, autoRotate = root.Anchored, hum and hum.AutoRotate
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + rise + 1.8)
		root.Anchored = true
		if hum then
			hum.AutoRotate = false
		end
		local ok, err = xpcall(function()
			local from = root.Position
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { char, target }
			local most = ability.Height or 110
			local ceiling = workspace:Raycast(from + UP * 3, UP * most, rp)
			local height = ceiling and math.max(ceiling.Distance - 8, 20) or most
			local top = from + UP * height
			broadcast("SkyProminenceRise", char, { Target = target, From = from, Top = top, Time = rise })
			local t0 = os.clock()
			while os.clock() - t0 < rise do
				if not alive(char) then
					return
				end
				local a = math.clamp((os.clock() - t0) / rise, 0, 1)
				local p = from:Lerp(top, 1 - (1 - a) ^ 2)
				root.CFrame = CFrame.lookAt(p, p + d)
				if g then
					Grab.place(g, CFrame.lookAt(p + d * 2.4 + UP * 0.4, p))
				end
				task.wait(1 / 60)
			end
			local hot = HF.vent(char)
			local mult = 1 + hot * (heatSpec().PerHeat or 0.6)
			broadcast("SkyProminenceBurst", char, { Pos = top + d * 1.5, Target = target })
			local land = HF.floor(top + d * 2.4, char)
			if g then
				local hit = damage(player, target, (ability.Damage or 44) * mult, { Heavy = true, Hitstop = 0.15, From = top })
				Grab.release(g, -UP * 150 + d * 20, 0.35)
				g = nil
				if hit then
					ragdoll(target, 2.4)
					burn(target, 4, 3, "hell")
				end
			end
			-- the street below: where they come down (or where it comes down)
			task.delay(target and math.clamp(height / 160, 0.3, 1) or 0.35, function()
				if not target then
					broadcast("ProminenceNovaBurst", char, { Pos = land + UP * 2, Radius = ability.Radius or 26, Heat = hot })
				end
				for _, model in queryRadius(char, land + UP * 2, ability.Radius or 26) do
					if model ~= target and damage(player, model, (ability.SkyDamage or 18) * (target and 1 or 2), { Heavy = true, From = land }) then
						knockback(model, awayFrom(land, model, d) * 90 + UP * 50, 0.22)
						burn(model, 2, 2, "hell")
					end
				end
				Destruction.Sphere(land, target and 9 or 14, target and "Crater" or "Fire", UP)
			end)
			task.wait(0.6)
			-- and he comes down on his flames
			local landAt = HF.floor(top - d * 3, char) + UP * 3
			local c0 = os.clock()
			while os.clock() - c0 < 0.9 and root.Parent do
				local a = math.clamp((os.clock() - c0) / 0.9, 0, 1)
				local p = top:Lerp(landAt, a * a)
				root.CFrame = CFrame.lookAt(p, p + d)
				task.wait(1 / 60)
			end
		end, debug.traceback)
		if g then
			Grab.release(g)
		end
		if root.Parent then
			root.Anchored = anchored
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if not anchored then
				pcall(function()
					root:SetNetworkOwnershipAuto()
				end)
			end
		end
		if hum and hum.Parent then
			hum.AutoRotate = autoRotate
		end
		if not ok then
			warn("[SkyProminence] " .. tostring(err))
		end
	end

	-------------------------------------------------------------------------
	-- DABI
	-------------------------------------------------------------------------

	-- CREMATION: the wave, then the street stays alight
	function Handlers.Cremation(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.16)
		if not alive(char) then
			return
		end
		local len, wid = ability.Range or 40, ability.Width or 12
		local hitSet = {}
		local t0 = os.clock()
		while os.clock() - t0 < 0.6 and alive(char) do
			local from = root.Position + d * 1.5
			local cf = CFrame.lookAt(from, from + d) * CFrame.new(0, 0, -len / 2)
			for _, model in queryBox(char, cf, Vector3.new(wid, wid, len), hitSet) do
				hitSet[model] = true
				if damage(player, model, ability.Damage or 14, { From = from, Hitstop = 0.04 }) then
					knockback(model, d * 45 + UP * 16, 0.16)
					burn(model, ability.BurnTicks, ability.BurnDamage, "blue")
				end
			end
			task.wait(0.1)
		end
		if not char.Parent then
			return
		end
		local across = d:Cross(UP)
		local pts = {}
		local n = ability.Patches or 5
		for i = 1, n do
			table.insert(pts, groundBelow(root.Position + Vector3.new(d.X, 0, d.Z).Unit * (len * i / (n + 1)) + across * (math.random(-25, 25) / 10) + UP * 3, char))
		end
		local r = ability.PatchRadius or 4
		broadcast("CremationPatches", char, { Points = pts, Radius = r, Life = ability.PatchLife or 5 })
		Destruction.Box(CFrame.lookAt(root.Position, root.Position + d) * CFrame.new(0, 0, -len / 2), Vector3.new(wid * 0.7, wid * 0.6, len), "Scorch", d)
		local lastHit = {}
		local t1 = os.clock()
		while os.clock() - t1 < (ability.PatchLife or 5) and char.Parent do
			task.wait(0.5)
			for _, p in pts do
				for _, model in queryRadius(char, p + UP * 2, r) do
					if os.clock() - (lastHit[model] or 0) >= 0.45 then
						lastHit[model] = os.clock()
						damage(player, model, ability.PatchDamage or 3, { From = p, NoKnockdown = true, Unblockable = true })
					end
				end
			end
		end
	end

	-- HELL MINEFIELD: pillars bursting out of the street one after another,
	-- up to the aim point
	function Handlers.HellMinefield(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = groundTarget(root, pos, ability.Range or 46, char)
		local start = groundBelow(root.Position + d * 3, char)
		local v = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
		if v.Magnitude < 8 then
			v = d * 20
		end
		task.wait(ability.Delay or 0.45)
		local n = ability.Count or 6
		local across = d:Cross(UP)
		for i = 1, n do
			if not char.Parent then
				return
			end
			local p = groundBelow(start + v * (i / n) + across * (math.random(-15, 15) / 10) + UP * 4, char)
			broadcast("MinefieldErupt", char, { Pos = p, Radius = ability.Radius or 6.5 })
			for _, model in queryRadius(char, p + UP * 3, ability.Radius or 6.5) do
				if damage(player, model, ability.Damage or 15, { From = p, Hitstop = 0.05 }) then
					knockback(model, UP * (ability.Lift or 60) + awayFrom(p, model, d) * 12, 0.22)
					burn(model, ability.BurnTicks, ability.BurnDamage, "blue")
				end
			end
			Destruction.Cylinder(p + UP * 8, 3.5, 16, "Fire", UP)
			task.wait(ability.Gap or 0.13)
		end
	end

	-- HELL SPIDER (his): the five streams
	function Handlers.BlueSpider(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local range, spread = ability.Range or 46, ability.Spread or 30
		local hits = ability.Hits or 3
		for i = 1, hits do
			if not alive(char) then
				return
			end
			local last = i == hits
			for _, model in HF.fan(char, root.Position, d, range, spread) do
				if damage(player, model, ability.Damage or 6, { From = root.Position, Hitstop = 0.03, NoKnockdown = not last }) then
					knockback(model, d * (last and 55 or 15) + UP * (last and 20 or 4), 0.15)
					if last then
						burn(model, ability.BurnTicks, ability.BurnDamage, "blue")
					end
				end
			end
			task.wait(0.17)
		end
		for k = -2, 2 do
			local dd = CFrame.fromAxisAngle(UP, math.rad(k * spread / 4)) * d
			Destruction.Box(CFrame.lookAt(root.Position, root.Position + dd) * CFrame.new(0, 1, -range / 2), Vector3.new(2.5, 3, range), "Scorch", dd)
		end
	end

	-- BLUE WALL: the ring bursts up round him (whoever's on it is thrown
	-- out), then crossing it burns
	function Handlers.BlueWall(player, char, root, ability)
		task.wait(0.17)
		if not alive(char) then
			return
		end
		local center = groundBelow(root.Position, char)
		local r = ability.Radius or 16
		local function onRing(model, band)
			local mr = model:FindFirstChild("HumanoidRootPart")
			if not mr then
				return false
			end
			local v = mr.Position - center
			return math.abs(Vector3.new(v.X, 0, v.Z).Magnitude - r) <= band and math.abs(v.Y) < 12
		end
		for _, model in queryRadius(char, center + UP * 3, r + 5) do
			if onRing(model, 4) and damage(player, model, ability.Damage or 8, { From = center, Hitstop = 0.04 }) then
				knockback(model, awayFrom(center, model, root.CFrame.LookVector) * (ability.Push or 60) + UP * 30, 0.2)
				burn(model, 2, 2, "blue")
			end
		end
		Destruction.Cylinder(center + UP * 3, r, 5, "Scorch")
		local lastHit = {}
		local t0 = os.clock()
		while os.clock() - t0 < (ability.Duration or 5) and char.Parent do
			task.wait(0.25)
			for _, model in queryRadius(char, center + UP * 3, r + 4) do
				if onRing(model, 2.5) and os.clock() - (lastHit[model] or 0) > 0.6 then
					lastHit[model] = os.clock()
					if damage(player, model, ability.TickDamage or 4, { From = center, NoKnockdown = true, Unblockable = true }) then
						burn(model, 1, 2, "blue")
					end
				end
			end
		end
	end

	-- JET BURN (his): the rush, and the blast in the face
	function Handlers.BlueJetBurn(player, char, root, ability, dir)
		local d = flatten(dir, root)
		local target = HF.rush(player, char, root, d, ability.Range or 40, ability.Speed or 140)
		if not alive(char) then
			return
		end
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		local at = troot and troot.Position or (root.Position + d * 4)
		broadcast("BlueJetBurnHit", char, { Target = target, Dir = d, At = at })
		if target and damage(player, target, ability.Damage or 20, { Heavy = true, Hitstop = 0.12, From = root.Position }) then
			knockback(target, d * 115 + UP * 45, 0.24)
			ragdoll(target, 1.5)
			burn(target, ability.BurnTicks, ability.BurnDamage, "blue")
		end
		for _, model in queryRadius(char, at + d * 3, ability.Radius or 8) do
			if model ~= target and damage(player, model, ability.SplashDamage or 7, { From = at }) then
				knockback(model, (awayFrom(at, model, d) + d).Unit * 60 + UP * 25, 0.2)
				burn(model, 2, 2, "blue")
			end
		end
		Destruction.Sphere(at + d * 3, 7, "Explosion", d)
	end

	-- ult: PROMINENCE BURN (his) - the beam out of his chest
	function Handlers.BlueProminence(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.5)
		if not alive(char) then
			return
		end
		local len, wid = ability.Range or 120, ability.Width or 14
		local ticks = 5
		for i = 1, ticks do
			if not alive(char) then
				return
			end
			local last = i == ticks
			local from = root.Position + UP * 0.6 + d * 1.5
			local cf = CFrame.lookAt(from, from + d) * CFrame.new(0, 0, -len / 2)
			for _, model in queryBox(char, cf, Vector3.new(wid, wid, len)) do
				if damage(player, model, (ability.Damage or 40) / ticks, { From = from, Hitstop = last and 0.1 or 0.02, Heavy = last, NoKnockdown = not last }) then
					knockback(model, d * (last and 120 or 20) + UP * (last and 50 or 5), 0.2)
					if last then
						ragdoll(model, 1.8)
						burn(model, ability.BurnTicks, ability.BurnDamage, "blue")
					end
				end
			end
			if i == 1 then
				Destruction.Box(cf, Vector3.new(wid * 0.6, wid * 0.6, len), "Beam", d)
			end
			task.wait(0.2)
		end
	end

	-- ult: SEKOTO PEAK - blue fire spreading out over the street
	function Handlers.SekotoPeak(player, char, root, ability)
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local center = groundBelow(root.Position, char)
		local R = ability.Radius or 38
		for _, model in queryRadius(char, center + UP * 3, R * 0.5) do
			if damage(player, model, ability.Damage or 10, { From = center, Hitstop = 0.05 }) then
				knockback(model, awayFrom(center, model, root.CFrame.LookVector) * 50 + UP * 30, 0.2)
				burn(model, 2, 2, "blue")
			end
		end
		Destruction.Cylinder(center + UP * 2, R * 0.6, 4, "Scorch")
		local lastHit = {}
		local t0 = os.clock()
		while os.clock() - t0 < (ability.Duration or 6) and char.Parent do
			task.wait(ability.Tick or 0.5)
			-- (it spreads: the first half second it's still reaching out)
			local r = R * math.clamp((os.clock() - t0 + 0.14) / 0.56, 0.25, 1)
			for _, model in queryRadius(char, center + UP * 3, r) do
				if os.clock() - (lastHit[model] or 0) >= (ability.Tick or 0.5) * 0.9 then
					lastHit[model] = os.clock()
					if damage(player, model, ability.TickDamage or 3, { From = center, NoKnockdown = true, Unblockable = true }) and math.random() < 0.35 then
						burn(model, 1, 1, "blue")
					end
				end
			end
		end
	end

	-- ult: VANISHING FIST (thrown)
	function Handlers.BlueVanishing(player, char, root, ability, dir, _pos, cast)
		local d = HF.aim(dir, root, cast)
		task.wait(0.42)
		if alive(char) then
			HF.throwFist(player, char, root, ability, d, "blue", 7)
		end
	end
end

---------------------------------------------------------------------------
-- (round 69) TWICE (Jin Bubaigawara): Double
---------------------------------------------------------------------------
-- His doubles are real bodies in workspace.TwiceClones: a copy of his own
-- character - or of whoever he's measured - with the scripts taken out,
-- run here (TW.think, ten times a second). Anyone can hit them; damage()
-- lets his own hits pass through them ("TwiceClone" = his UserId), hitting
-- one charges nobody's ult and never plays a KO finisher. Hit enough, their
-- time up, or him gone, they melt into mud (TW.melt).
do
	local TW = { list = {}, measured = setmetatable({}, { __mode = "k" }) }
	Kit.TW = TW

	function TW.spec()
		return Config.Quirks.Double or {}
	end
	function TW.cs()
		return TW.spec().Clones or {}
	end
	function TW.folder()
		local f = workspace:FindFirstChild("TwiceClones")
		if not f then
			f = Instance.new("Folder")
			f.Name = "TwiceClones"
			f.Parent = workspace
		end
		return f
	end
	-- how many at once (the ult: Ult.Special.Max)
	function TW.max(char)
		local ult = TW.spec().Ult
		if char:GetAttribute("UltActive") and ult and ult.Special and ult.Special.Max then
			return ult.Special.Max
		end
		return TW.cs().Max or 2
	end
	-- his HUD: the pips over his health bar (QuirkClient reads "Doubles")
	function TW.count(player)
		local char = player.Character
		if char and char:GetAttribute("Doubles") ~= nil then
			char:SetAttribute("Doubles", #TW.of(player, true))
		end
	end
	-- one of his?
	function TW.mine(player, model)
		return model ~= nil and model:GetAttribute("TwiceClone") == player.UserId
	end
	-- his doubles out now (counted: the ones that fight on - not a parade's
	-- marchers or a dogpile's), oldest first
	function TW.of(player, counted)
		local out = {}
		for _, r in TW.list do
			if r.Owner == player and not r.Gone and (not counted or r.Kind == "Self" or r.Kind == "Enemy") then
				table.insert(out, r)
			end
		end
		return out
	end
	-- the first one in line that isn't his (a double of his is stepped past)
	function TW.firstInLine(player, caster, origin, d, length, width)
		local best, bestDist
		local cf = CFrame.lookAt(origin, origin + d) * CFrame.new(0, 0, -length / 2)
		for _, model in queryBox(caster, cf, Vector3.new(width, width, length)) do
			if model ~= player.Character and not TW.mine(player, model) then
				local r = model:FindFirstChild("HumanoidRootPart")
				local dist = r and (r.Position - origin):Dot(d)
				if dist and dist > -2 and (not bestDist or dist < bestDist) then
					best, bestDist = model, dist
				end
			end
		end
		return best, bestDist
	end
	-- who his doubles go for: everyone else, training dummies, other
	-- people's doubles
	function TW.enemies(player)
		local out = {}
		local own = player.Character
		for _, plr in Players:GetPlayers() do
			if plr.Character and plr.Character ~= own then
				table.insert(out, plr.Character)
			end
		end
		local dummies = workspace:FindFirstChild("Dummies")
		for _, m in dummies and dummies:GetChildren() or {} do
			table.insert(out, m)
		end
		local raid = workspace:FindFirstChild("NomuRaid") -- (round 71: and the Nomu)
		for _, m in raid and raid:GetChildren() or {} do
			table.insert(out, m)
		end
		for _, r in TW.list do
			if r.Owner ~= player and not r.Gone then
				table.insert(out, r.Model)
			end
		end
		return out
	end

	-- A DOUBLE: a copy of `src` standing at cf, his (kind: "Self" | "Enemy" |
	-- "Parade" | "Pile"). opts: Life, Health, Speed, Damage, Quiet
	function TW.spawn(player, char, src, cf, kind, opts)
		opts = opts or {}
		local cs = TW.cs()
		if src ~= char and (not alive(src) or src:GetAttribute("Ragdolled") or src:GetAttribute("Frozen") or src:GetAttribute("Grabbed")) then
			src, kind = char, "Self" -- (someone lying limp or held: a copy of him instead)
		end
		local was = src.Archivable
		src.Archivable = true
		local ok, m = pcall(function()
			return src:Clone()
		end)
		src.Archivable = was
		if not ok or not m then
			return nil
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		local root = m:FindFirstChild("HumanoidRootPart")
		if not hum or not root then
			m:Destroy()
			return nil
		end
		-- (mud in his shape: no scripts, no shoves, no auras, no name tags)
		for _, d in m:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Highlight") or d:IsA("BillboardGui")
				or d:IsA("LinearVelocity") or d:IsA("BodyMover") or d:IsA("AlignPosition") or d:IsA("AlignOrientation")
				or d:IsA("VectorForce") or d:IsA("Sound") or d:IsA("BallSocketConstraint") or d:IsA("HingeConstraint") then
				d:Destroy()
			end
		end
		local joints = src:GetAttribute("ClassicJoints")
		for k in m:GetAttributes() do
			m:SetAttribute(k, nil)
		end
		for k in hum:GetAttributes() do
			hum:SetAttribute(k, nil)
		end
		m:SetAttribute("ClassicJoints", joints)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
			elseif p:IsA("Motor6D") then
				p.Enabled = true
			end
		end
		local health = opts.Health or cs.Health or 32
		hum.MaxHealth = health
		hum.Health = health
		hum.WalkSpeed = opts.Speed or cs.Speed or 21
		hum.UseJumpPower = true
		hum.JumpPower = 50
		hum.AutoRotate = true
		hum.PlatformStand = false
		hum.Sit = false
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		m:SetAttribute("TwiceClone", player.UserId)
		m:SetAttribute("CloneKind", kind)
		m:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
		m:PivotTo(cf)
		m.Parent = TW.folder()
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local r = {
			Model = m, Hum = hum, Root = root, Owner = player, Char = char, Kind = kind,
			Until = os.clock() + (opts.Life or cs.Life or 16), Next = os.clock() + 0.45,
			Damage = opts.Damage or (kind == "Enemy" and cs.EnemyDamage or cs.Damage) or 4,
		}
		table.insert(TW.list, r)
		TW.count(player)
		hum.Died:Connect(function()
			TW.melt(r)
		end)
		if not opts.Quiet then
			broadcast("TwiceSplit", m, { From = char, Kind = kind, Pos = root.Position })
		end
		TW.run()
		return r
	end

	-- back into mud: every screen melts it (Effects.TwiceMelt), then it's gone
	function TW.melt(r)
		if r.Gone then
			return
		end
		r.Gone = true
		local i = table.find(TW.list, r)
		if i then
			table.remove(TW.list, i)
		end
		TW.count(r.Owner)
		local m = r.Model
		if not m.Parent then
			return
		end
		m:SetAttribute("Melting", true)
		broadcast("TwiceMelt", m, { Pos = r.Root.Position, Time = TW.cs().Melt or 0.7 })
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
			end
		end
		if r.Hum.Health > 0 then
			r.Hum.Health = 0
		end
		task.delay((TW.cs().Melt or 0.7) + 0.25, function()
			if m.Parent then
				m:Destroy()
			end
		end)
	end

	-- ten times a second, every double: go for the nearest enemy, hit them
	function TW.run()
		if TW.running then
			return
		end
		TW.running = true
		task.spawn(function()
			while #TW.list > 0 do
				local now = os.clock()
				local foes = {}
				for _, r in table.clone(TW.list) do
					if not r.Gone then
						local ok, err = pcall(TW.think, r, now, foes)
						if not ok then
							warn("[QuirkServer] a double of Twice's:", err)
							TW.melt(r)
						end
					end
				end
				task.wait(0.1)
			end
			TW.running = false
		end)
	end
	function TW.think(r, now, foesOf)
		local m, hum, root = r.Model, r.Hum, r.Root
		if not m.Parent or hum.Health <= 0 or now >= r.Until or not r.Owner.Parent or r.Owner.Character ~= r.Char or not alive(r.Char) then
			TW.melt(r)
			return
		end
		if r.Kind == "Parade" or r.Kind == "Pile" then
			return -- (their move drives them)
		end
		if m:GetAttribute("Stunned") or m:GetAttribute("Ragdolled") or m:GetAttribute("Grabbed") or m:GetAttribute("Frozen") or root.Anchored then
			return
		end
		local cs = TW.cs()
		local foes = foesOf[r.Owner]
		if not foes then
			foes = TW.enemies(r.Owner)
			foesOf[r.Owner] = foes
		end
		-- the nearest one it can see (it sticks with the one it's on)
		local best, bestDist = nil, cs.Sight or 70
		for _, f in foes do
			local fr = f:FindFirstChild("HumanoidRootPart")
			local fh = f:FindFirstChildOfClass("Humanoid")
			if fr and fh and fh.Health > 0 and f ~= m and not f:GetAttribute("PlayingUno") and not f:GetAttribute("Melting") then
				local dist = (fr.Position - root.Position).Magnitude - (f == r.Target and 6 or 0)
				if dist < bestDist then
					best, bestDist = f, dist
				end
			end
		end
		r.Target = best
		if not best then
			-- nobody about: back to his side
			local oroot = r.Char:FindFirstChild("HumanoidRootPart")
			local back = oroot and oroot.Position - root.Position
			if back and back.Magnitude > 9 then
				hum:MoveTo(oroot.Position - back.Unit * 4)
			end
			return
		end
		local tr = best:FindFirstChild("HumanoidRootPart")
		local off = tr.Position - root.Position
		local flat = Vector3.new(off.X, 0, off.Z)
		local reach = cs.Reach or 4.2
		if flat.Magnitude > reach then
			hum:MoveTo(tr.Position - (flat.Magnitude > 0.1 and flat.Unit or Vector3.zero) * 2.6)
			if off.Y > 4 and flat.Magnitude < 14 then
				hum.Jump = true
			end
			return
		end
		if now < r.Next then
			return
		end
		r.Next = now + (cs.Every or 0.8)
		hum:MoveTo(root.Position)
		local d = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
		root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
		r.Count = (r.Count or 0) % 4 + 1
		broadcast("TwiceClonePunch", m, { Target = best, Count = r.Count, Dir = d })
		task.delay(0.12, function()
			local tr2 = not r.Gone and best.Parent and best:FindFirstChild("HumanoidRootPart")
			if not tr2 or (tr2.Position - root.Position).Magnitude > reach + 2.5 then
				return
			end
			if damage(r.Owner, best, r.Damage, { From = root.Position, Hitstop = 0.03 }) then
				knockback(best, d * 12, 0.1)
				stun(best, cs.Stun or 0.35)
			end
		end)
	end

	-- a body of his, a new one, or someone else: drop his doubles / his mark
	function TW.setup(char, on, fresh)
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		char:SetAttribute("Doubles", on and #TW.of(player, true) or nil)
		if on and not fresh then
			return
		end
		for _, r in TW.of(player) do
			TW.melt(r)
		end
		TW.unmeasure(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, r in TW.of(player) do
			TW.melt(r)
		end
		TW.unmeasure(player)
	end)

	-- MEASURED: whoever the tape wrapped - his next R makes a double of them
	function TW.measure(player, target, time)
		TW.unmeasure(player)
		local mark = { Model = target, Until = os.clock() + time }
		TW.measured[player] = mark
		target:SetAttribute("MeasuredBy", player.UserId)
		if player.Character then
			player.Character:SetAttribute("Measuring", target.Name)
		end
		broadcast("Measured", player.Character, { Target = target, Time = time })
		task.delay(time, function()
			if TW.measured[player] == mark then
				TW.unmeasure(player)
			end
		end)
	end
	function TW.unmeasure(player)
		local mark = TW.measured[player]
		TW.measured[player] = nil
		if player.Character and player.Character:GetAttribute("Measuring") ~= nil then
			player.Character:SetAttribute("Measuring", nil)
		end
		if mark and mark.Model.Parent and mark.Model:GetAttribute("MeasuredBy") == player.UserId then
			mark.Model:SetAttribute("MeasuredBy", nil)
		end
	end

	-- the Ult's awakening: they pour out of him (Ult.Burst)
	function TW.parade(player, char)
		local ult = TW.spec().Ult or {}
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local max = (ult.Special and ult.Special.Max) or 6
		local n = math.min(ult.Burst or 4, max - #TW.of(player, true))
		for i = 1, n do
			local a = (i / math.max(n, 1)) * math.pi * 2
			local at = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 4
			TW.spawn(player, char, char, CFrame.lookAt(at, at + (at - root.Position)), "Self")
		end
	end

	-- a knife from `from` towards `to` (Speed, Range): the first one in its
	-- way that isn't his takes Damage and is slowed
	function TW.knife(player, thrower, from, to, ability)
		local d = to - from
		if d.Magnitude < 0.5 then
			return
		end
		d = d.Unit
		local range = ability.Range or 70
		local target, dist = TW.firstInLine(player, thrower, from, d, range, 3)
		local reach = target and math.max(dist, 1) or wallDistance(thrower, from, d, range)
		broadcast("TwiceKnife", thrower, { From = from, To = from + d * reach, Hit = target, Speed = ability.Speed or 190 })
		if not target then
			return
		end
		task.wait(reach / (ability.Speed or 190))
		if target.Parent and damage(player, target, ability.Damage or 4, { From = from, Hitstop = 0.02 }) then
			slow(target, ability.SlowTime or 1.4, ability.SlowTo or 9)
		end
	end
	-- DAGGER SHOT / DAGGER STORM: his knives down the aim, a fan; every
	-- double of his throws at the spot he's aiming at
	function TW.volley(player, char, root, ability, dir, pos)
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		local range = ability.Range or 70
		local spot = pos
		if typeof(spot) ~= "Vector3" or (spot - root.Position).Magnitude > range then
			spot = root.Position + UP + d * range
		end
		local perClone = ability.Id == "DaggerStorm" and (ability.Knives or 4) or 1
		for _, r in TW.of(player, true) do
			if not r.Model:GetAttribute("Stunned") and (r.Root.Position - root.Position).Magnitude < 90 then
				task.spawn(function()
					broadcast("TwiceThrow", r.Model, { Dir = (spot - r.Root.Position).Unit })
					for _ = 1, perClone do
						if r.Gone then
							return
						end
						task.spawn(TW.knife, player, r.Model, r.Root.Position + UP * 1.2, spot + UP * 0.8, ability)
						task.wait(ability.Gap or 0.1)
					end
				end)
			end
		end
		local n = ability.Knives or 3
		for k = 1, n do
			if not alive(char) then
				return
			end
			local live = Kit.liveAim[player]
			local aim = live and os.clock() - live.Time < 0.5 and live.Dir or d
			aim = CFrame.fromAxisAngle(UP, math.rad((k - (n + 1) / 2) * 3.5)):VectorToWorldSpace(aim)
			local from = root.Position + UP * 1.2 + root.CFrame.RightVector * 0.6
			task.spawn(TW.knife, player, char, from, from + aim * range, ability)
			task.wait(ability.Gap or 0.1)
		end
	end
	function Handlers.DaggerShot(player, char, root, ability, dir, pos)
		TW.volley(player, char, root, ability, dir, pos)
	end
	function Handlers.DaggerStorm(player, char, root, ability, dir, pos)
		TW.volley(player, char, root, ability, dir, pos)
	end

	-- TAPE DASH: his machine zips him along the tape (Effects.TapeDash); the
	-- knife catches the first one in his way
	function Handlers.TapeDash(player, char, root, ability, dir)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		task.wait(0.08)
		if not alive(char) then
			return
		end
		local caught = false
		sweep(player, char, root, (ability.Time or 0.32) + 0.1, 4.5, 2, flatten(d, root), function(model)
			if caught or TW.mine(player, model) then
				return
			end
			if damage(player, model, ability.Damage or 9, { From = root.Position, Hitstop = 0.06 }) then
				caught = true
				stun(model, ability.Stun or 0.9)
				knockback(model, flatten(d, root) * 18 + UP * 6, 0.12)
				broadcast("TapeSlash", char, { Target = model, Dir = d })
			end
		end)
	end

	-- MEASURE: the tape lashes out, wraps the first one in line and reels
	-- them in; measured, his next R is a double of them
	function Handlers.MeasureTape(player, char, root, ability, dir)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		task.wait(0.14)
		if not alive(char) then
			return
		end
		local origin = root.Position + UP
		local range = ability.Range or 38
		local target, dist = TW.firstInLine(player, char, origin, d, range, 4)
		local reach = target and math.max(dist, 1) or wallDistance(char, origin, d, range)
		broadcast("MeasureLash", char, { Dir = d, To = origin + d * reach, Target = target })
		if not target then
			return
		end
		task.wait(reach / 160)
		if not alive(char) or not target.Parent then
			return
		end
		if not damage(player, target, ability.Damage or 7, { From = origin, Hitstop = 0.05 }) then
			return
		end
		if not target:GetAttribute("TwiceClone") then
			TW.measure(player, target, ability.Measured or 25)
		end
		local g = Grab.take(target, (ability.Bind or 0.9) + 0.2)
		if not g then
			return
		end
		local fd = flatten(d, root)
		local from = g.Root.Position
		local pull = ability.Pull or 4.5
		local pullT = math.clamp((from - (root.Position + fd * pull)).Magnitude / 90, 0.08, 0.4)
		local t0 = os.clock()
		while os.clock() - t0 < pullT and alive(char) and g.Root.Parent do
			local at = from:Lerp(root.Position + fd * pull, (os.clock() - t0) / pullT)
			Grab.place(g, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
			task.wait(1 / 30)
		end
		if g.Root.Parent and alive(char) then
			local at = root.Position + fd * pull
			Grab.place(g, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
		end
		task.wait(math.max((ability.Bind or 0.9) - pullT, 0.1))
		Grab.release(g)
		stun(target, 0.35)
	end

	-- R: DOUBLE - one steps out of him (of whoever he's measured, if anyone):
	-- at the limit, his oldest melts to make room
	function Handlers.Double(player, char, root, ability)
		local max = ability.Max or TW.max(char)
		local mine = TW.of(player, true)
		while #mine >= max do
			TW.melt(table.remove(mine, 1))
		end
		local src, kind = char, "Self"
		local mark = TW.measured[player]
		if mark and mark.Until > os.clock() and mark.Model.Parent and alive(mark.Model) then
			src, kind = mark.Model, "Enemy"
			TW.unmeasure(player)
		end
		task.wait(0.22) -- (the mud bubbling out of him)
		if not alive(char) then
			return
		end
		local side = root.CFrame.RightVector * ((#mine % 2 == 0) and 3 or -3)
		local at = root.Position + side - root.CFrame.LookVector
		TW.spawn(player, char, src, CFrame.lookAt(at, at + root.CFrame.LookVector), kind)
	end

	-- 4: DOUBLE CROSS - he and his double nearest the aim swap places; none
	-- out, he throws one at the aim spot
	function Handlers.DoubleCross(player, char, root, ability, dir, pos)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		local best, bestScore
		for _, r in TW.of(player, true) do
			local v = r.Root.Position - root.Position
			if v.Magnitude > 1 and v.Magnitude <= (ability.Range or 90) and not r.Root.Anchored and not r.Model:GetAttribute("Grabbed") then
				local score = (1 - v.Unit:Dot(d)) * 60 + v.Magnitude * 0.2 -- (off the aim counts most)
				if not bestScore or score < bestScore then
					best, bestScore = r, score
				end
			end
		end
		if best then
			local a, b = root.CFrame, best.Root.CFrame
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 0.35)
			broadcast("DoubleSwap", char, { From = a.Position, To = b.Position, Clone = best.Model })
			local anchored = root.Anchored
			root.Anchored = true
			root.CFrame = b
			best.Root.CFrame = a
			best.Next = os.clock() + 0.3
			task.wait(0.05)
			root.Anchored = anchored
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end
		-- nobody to swap with: he throws one (it lands on its feet, fighting)
		local land = groundTarget(root, typeof(pos) == "Vector3" and pos or root.Position + d * 20, ability.Toss or 40, char)
		broadcast("CloneToss", char, { From = root.Position + UP, To = land + UP * 3 })
		task.wait(0.35)
		if alive(char) then
			local fd = flatten(d, root)
			local mine = TW.of(player, true)
			if #mine >= TW.max(char) then
				TW.melt(mine[1])
			end
			TW.spawn(player, char, char, CFrame.lookAt(land + UP * 3, land + UP * 3 + fd), "Self")
		end
	end

	-- ULT 1: PARADE - a column of doubles stampedes down the aim
	function Handlers.ParadeMarch(player, char, root, ability, dir)
		local d = flatten(dir, root)
		local right = d:Cross(UP)
		task.wait(0.2)
		if not alive(char) then
			return
		end
		local speed = ability.Speed or 38
		local dur = (ability.Range or 55) / speed
		local marchers = {}
		for i = 1, ability.Count or 8 do
			local row = math.floor((i - 1) / 2)
			local at = root.Position - d * (1 + row * 2.2) + right * (((i - 1) % 2 == 0) and -1.6 or 1.6)
			local r = TW.spawn(player, char, char, CFrame.lookAt(at, at + d), "Parade", { Life = dur + 1.5, Speed = speed, Health = 12, Quiet = true })
			if r then
				table.insert(marchers, r)
			end
		end
		local hit = {}
		local t0 = os.clock()
		while os.clock() - t0 < dur + 0.3 do
			for _, r in marchers do
				if not r.Gone then
					r.Hum:MoveTo(r.Root.Position + d * 10)
					for _, model in queryRadius(r.Model, r.Root.Position + d * 1.5, (ability.Width or 5) * 0.6) do
						if not hit[model] and model ~= char and not TW.mine(player, model) then
							hit[model] = true
							if damage(player, model, ability.Damage or 6, { From = r.Root.Position, Hitstop = 0.03 }) then
								knockback(model, d * 45 + UP * 20, 0.16)
								stun(model, 0.6)
							end
						end
					end
				end
			end
			task.wait(0.08)
		end
		for _, r in marchers do
			TW.melt(r)
		end
	end

	-- ULT 3: DOGPILE - every double of his, and Count more out of the
	-- ground, pile onto the first one in front; then the heap bursts
	function Handlers.Dogpile(player, char, root, ability, dir)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		task.wait(0.15)
		if not alive(char) then
			return
		end
		local target = TW.firstInLine(player, char, root.Position + UP, d, ability.Range or 45, 7)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr then
			return
		end
		local pile = {}
		for _, r in TW.of(player, true) do
			if (r.Root.Position - tr.Position).Magnitude < 70 then
				r.Kind = "Pile" -- (it's in the heap now)
				r.Model:SetAttribute("CloneKind", "Pile")
				table.insert(pile, r)
			end
		end
		local count = ability.Count or 6
		for i = 1, count do
			local a = (i / count) * math.pi * 2
			local at = tr.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 7
			local r = TW.spawn(player, char, char, CFrame.lookAt(at, tr.Position), "Pile", { Life = 3.5, Health = 12, Quiet = true })
			if r then
				table.insert(pile, r)
			end
		end
		broadcast("DogpileGo", char, { Target = target, Count = #pile })
		local g = Grab.take(target, #pile * 0.07 + 0.9)
		for i, r in pile do
			task.delay((i - 1) * 0.07, function()
				if r.Gone or not tr.Parent then
					return
				end
				r.Root.Anchored = true
				local from = r.Root.Position
				local land = tr.Position + Vector3.new(math.random(-12, 12) / 10, 0.6 + i * 0.45, math.random(-12, 12) / 10)
				for s = 1, 6 do
					local k = s / 6
					if r.Gone then
						return
					end
					r.Root.CFrame = CFrame.lookAt(from:Lerp(land, k) + UP * 12 * k * (1 - k), tr.Position)
					task.wait(1 / 30)
				end
				damage(player, target, ability.Damage or 3, { From = land, Hitstop = 0.02 })
			end)
		end
		task.wait(#pile * 0.07 + 0.55)
		if g then
			Grab.release(g)
		end
		broadcast("DogpileBurst", char, { Pos = tr.Position, Target = target })
		if damage(player, target, ability.BurstDamage or 14, { From = tr.Position - flatten(d, root) * 2, Heavy = true, Hitstop = 0.1 }) then
			knockback(target, flatten(d, root) * 50 + UP * 60, 0.25)
			ragdoll(target, 1.4)
		end
		for _, r in pile do
			TW.melt(r)
		end
	end
end


---------------------------------------------------------------------------
-- (round 71) QUIRK CLASHES (Config.Clash), the Jujutsu Shenanigans beam
-- clash: two big moves aimed at each other meet in the middle and push.
-- A clash move that's just gone off is "out" (CL.fire, from onUseAbility);
-- when one lands on someone whose own clash move is out and aimed back
-- (damage() asks CL.try first), it's a clash instead of a hit: both are
-- rooted, facing each other, and press the prompts (the Clash remote) to
-- push the meeting point. It ends when one side's pushed all the way, or
-- when Time runs out (whoever's ahead). Every screen draws it (ClashStart /
-- ClashPush / ClashEnd); the two in it get the prompts and the camera.
---------------------------------------------------------------------------
do
	local CL = { fired = setmetatable({}, { __mode = "k" }), active = {}, seq = 0 }
	Kit.CL = CL
	Reactions.CL = CL -- (damage() comes before Kit: it asks through Reactions)
	local ClashRemote = Remotes:FindFirstChild("Clash") or Instance.new("RemoteEvent")
	ClashRemote.Name = "Clash"
	ClashRemote.Parent = Remotes

	function CL.cfg()
		return Config.Clash or {}
	end
	function CL.on()
		return CL.cfg().Enabled ~= false and workspace:GetAttribute("Clashes") ~= false
	end
	function CL.spec(id)
		local moves = CL.cfg().Moves
		return moves and moves[id or ""] or nil
	end
	-- a clash move just went: it's out for Window seconds
	function CL.fire(player, char, ability, dir)
		if CL.on() and ability and CL.spec(ability.Id) and typeof(dir) == "Vector3" then
			CL.fired[char] = { Player = player, Ability = ability, Dir = dir, Time = os.clock(), Ult = player:GetAttribute("UltActive") == true }
		end
	end
	function CL.live(char)
		local f = char and CL.fired[char]
		if f and not f.Used and os.clock() - f.Time <= (CL.cfg().Window or 1.2) then
			return f
		end
		return nil
	end
	function CL.flat(v)
		local f = Vector3.new(v.X, 0, v.Z)
		return f.Magnitude > 0.01 and f.Unit or nil
	end

	-- (damage() asks first) true = this hit is a clash now: it lands nothing
	function CL.try(attacker, model)
		if not attacker or not CL.on() then
			return false
		end
		local ac = attacker.Character
		if not ac or ac == model or ac:GetAttribute("Clashing") then
			return false
		end
		local victim = Players:GetPlayerFromCharacter(model)
		local a, b = CL.live(ac), victim and CL.live(model)
		if not a or not b then
			return false
		end
		-- (one of his other moves landing meanwhile isn't the one that's out)
		local move = Moves.current()
		if move and move.Ability and move.Ability ~= a.Ability then
			return false
		end
		local ar, br = ac:FindFirstChild("HumanoidRootPart"), model:FindFirstChild("HumanoidRootPart")
		if not ar or not br or not alive(ac) or not alive(model) or model:GetAttribute("Ragdolled") or ac:GetAttribute("Ragdolled") then
			return false
		end
		local cfg = CL.cfg()
		local gap = br.Position - ar.Position
		local line, da, db = CL.flat(gap), CL.flat(a.Dir), CL.flat(b.Dir)
		if not line or not da or not db or gap.Magnitude < (cfg.MinRange or 4) or gap.Magnitude > (cfg.MaxRange or 160) then
			return false
		end
		-- aimed at each other
		local facing = cfg.Facing or 0.55
		if da:Dot(line) < facing or db:Dot(-line) < facing then
			return false
		end
		CL.start(a, b)
		return true
	end

	-- the prompt after this one (the same on both ends: the seed is shared)
	function CL.nextKey(side)
		local keys = CL.cfg().Keys or { "W", "A", "D" }
		return keys[side.Rng:NextInteger(1, #keys)]
	end

	function CL.start(a, b)
		local cfg = CL.cfg()
		CL.seq += 1
		local c = { Id = CL.seq, M = 0, Ends = os.clock() + (cfg.Time or 10), Seed = math.random(1, 2 ^ 30) }
		a.Used, b.Used = true, true
		for i, f in { a, b } do
			local char = f.Player.Character
			local side = { Player = f.Player, Char = char, Root = char:FindFirstChild("HumanoidRootPart"), Fire = f, Index = 1, Lock = 0, Last = 0, Good = 0 }
			side.Rng = Random.new(c.Seed + i * 7919)
			side.Key = CL.nextKey(side)
			c[i == 1 and "A" or "B"] = side
		end
		for _, s in { c.A, c.B } do
			local other = s == c.A and c.B or c.A
			Moves.cut(s.Char) -- (the moves that met stop where they are)
			if guardState[s.Char] and guardState[s.Char].Blocking then
				setBlocking(s.Char, false)
			end
			s.Char:SetAttribute("Clashing", c.Id)
			s.Char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + (cfg.Time or 10) + 1)
			s.Root.Anchored = true
			local at, to = s.Root.Position, other.Root.Position
			s.Root.CFrame = CFrame.lookAt(at, Vector3.new(to.X, at.Y, to.Z))
		end
		CL.active[c.Id] = c
		broadcast("ClashStart", nil, {
			Id = c.Id, A = c.A.Char, B = c.B.Char, AMove = a.Ability.Id, BMove = b.Ability.Id,
			AName = a.Player.DisplayName, BName = b.Player.DisplayName, Time = cfg.Time or 10, Seed = c.Seed,
		})
		task.spawn(CL.run, c)
		return c
	end

	-- where the two moves meet right now
	function CL.point(c)
		return c.A.Root.Position:Lerp(c.B.Root.Position, 0.5 + 0.45 * c.M) + UP
	end

	-- a press from one of the two: index = which prompt it answers
	function CL.press(player, id, index, key)
		local c = CL.active[id]
		if not c or c.Done or type(index) ~= "number" or type(key) ~= "string" then
			return
		end
		local s = (c.A.Player == player and c.A) or (c.B.Player == player and c.B) or nil
		if not s then
			return
		end
		local cfg = CL.cfg()
		local now = os.clock()
		if index ~= s.Index or now - s.Last < (cfg.MinGap or 0.07) * 0.75 then
			PlayVFX:FireClient(player, "ClashSync", nil, { Id = id, Index = s.Index })
			return
		end
		s.Last = now
		local want = s.Key
		s.Index += 1
		s.Key = CL.nextKey(s)
		if now < s.Lock then
			return -- (still reeling from a wrong one)
		end
		local toward = s == c.A and 1 or -1
		local step = (s.Fire.Ult and cfg.UltStep or cfg.Step) or 0.055
		local good = key == want
		if good then
			c.M += step * toward
			s.Good += 1
		else
			c.M -= step * 0.5 * toward
			s.Lock = now + (cfg.WrongPenalty or 0.35)
		end
		c.M = math.clamp(c.M, -1, 1)
		broadcast("ClashPush", nil, { Id = id, M = c.M, Side = s == c.A and "A" or "B", Good = good })
		if math.abs(c.M) >= 1 then
			CL.finish(c)
		end
	end
	ClashRemote.OnServerEvent:Connect(function(player, id, index, key)
		CL.press(player, id, index, key)
	end)

	-- the clock, the two of them still there, and anyone who wanders into it
	function CL.run(c)
		local cfg = CL.cfg()
		local nextSplash = os.clock() + 0.5
		while not c.Done do
			local now = os.clock()
			for _, s in { c.A, c.B } do
				if not s.Player.Parent or s.Player.Character ~= s.Char or not alive(s.Char) then
					CL.finish(c, s == c.A and c.B or c.A)
					return
				end
			end
			if now >= c.Ends then
				CL.finish(c)
				return
			end
			if now >= nextSplash then
				nextSplash = now + 0.5
				local point = CL.point(c)
				for _, model in queryRadius(c.A.Char, point, cfg.SplashRadius or 11) do
					if model ~= c.B.Char and not model:GetAttribute("Clashing") and damage(nil, model, cfg.SplashDamage or 5, { From = point }) then
						knockback(model, awayFrom(point, model, UP) * 45 + UP * 20, 0.2)
					end
				end
			end
			task.wait(0.05)
		end
	end

	-- over: the winner's move goes through (or, dead level, it all goes up)
	function CL.finish(c, forced)
		if c.Done then
			return
		end
		c.Done = true
		CL.active[c.Id] = nil
		local cfg = CL.cfg()
		local win, lose
		if forced then
			win = forced
		elseif math.abs(c.M) > (cfg.Draw or 0.06) then
			win = c.M > 0 and c.A or c.B
		end
		if win then
			lose = win == c.A and c.B or c.A
		end
		local point = CL.point(c)
		for _, s in { c.A, c.B } do
			if s.Char.Parent then
				s.Char:SetAttribute("Clashing", nil)
				s.Char:SetAttribute("CombatActionUntil", nil)
				if s.Root.Parent and not s.Char:GetAttribute("Frozen") and not s.Char:GetAttribute("Grabbed") then
					s.Root.Anchored = false
				end
			end
		end
		broadcast("ClashEnd", nil, { Id = c.Id, Winner = win and win.Char, Loser = lose and lose.Char, Draw = win == nil, Point = point, M = c.M })
		c.Result = win and (win == c.A and "A" or "B") or "Draw"
		task.delay(0.35, function()
			if win then
				iFrames[win.Char] = math.max(iFrames[win.Char] or 0, os.clock() + 0.9)
				if not lose.Char.Parent or not lose.Root.Parent then
					return
				end
				iFrames[lose.Char] = nil -- (their move's armour doesn't save them from this)
				local ab = win.Fire.Ability
				local amount = math.clamp((ab.Damage or 20) * (cfg.WinDamage or 1.5), cfg.MinDamage or 28, cfg.MaxDamage or 80)
				local d = CL.flat(lose.Root.Position - win.Root.Position) or UP
				if damage(win.Player, lose.Char, amount, { From = win.Root.Position, Heavy = true, Unblockable = true, NoCap = true, Hitstop = 0.12 }) then
					knockback(lose.Char, d * 115 + UP * 45, 0.3)
					ragdoll(lose.Char, 2)
				end
				-- (the trench it tears on its way through)
				for k = 0, 3 do
					Destruction.Sphere(point:Lerp(lose.Root.Position, k / 3) + d * k * 2, 6 + k, "Impact", d)
				end
			else
				for _, s in { c.A, c.B } do
					local other = s == c.A and c.B or c.A
					if s.Char.Parent and damage(other.Player, s.Char, cfg.DrawDamage or 16, { From = point, Heavy = true, Unblockable = true }) then
						knockback(s.Char, awayFrom(point, s.Char, UP) * 95 + UP * 50, 0.3)
						ragdoll(s.Char, 1.4)
					end
				end
				Destruction.Sphere(point, 12, "Impact", UP)
			end
		end)
	end
end


---------------------------------------------------------------------------
-- (round 71) NOMU RAIDS (Config.NomuRaid): a High-End Nomu drops into the
-- city and the whole server takes it on. The body here is plain - a big
-- Humanoid with an invisible hitbox (workspace.NomuRaid.HighEndNomu) - and
-- every screen draws the Nomu itself over it (VFX: NMV). It can't be
-- knocked back, stunned, ragdolled, frozen or grabbed (armour for good:
-- Reactions.armor), its KO isn't a finisher, and damage() tells it who's
-- hitting it (NR.hit) for the damage board and the pay-out at the end.
---------------------------------------------------------------------------
do
	local NR = { next = os.clock() + ((Config.NomuRaid or {}).First or 240) }
	Kit.NR = NR
	Reactions.NR = NR -- (damage() asks through Reactions: it comes before Kit)

	function NR.cfg()
		return Config.NomuRaid or {}
	end
	function NR.on()
		local cfg = NR.cfg()
		if cfg.Enabled == false then
			return false
		end
		if cfg.OptIn then
			return workspace:GetAttribute("NomuRaid") == true -- (round 75: off unless it's switched on)
		end
		return workspace:GetAttribute("NomuRaid") ~= false
	end
	-- (round 75) the server panel / console kills the one that's down (a
	-- defeat: whoever fought it is paid as usual); one still on its way in
	-- just turns back
	function NR.kill()
		local r = NR.active
		if not r then
			return false
		end
		if r.Hum and r.Hum.Health > 0 then
			r.Hum.Health = 0
		else
			NR.finish(r, "Escaped")
		end
		return true
	end
	function NR.folder()
		local f = workspace:FindFirstChild("NomuRaid")
		if not f then
			f = Instance.new("Folder")
			f.Name = "NomuRaid"
			f.Parent = workspace
		end
		return f
	end
	function NR.ground(spot)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(nil)
		local hit = workspace:Raycast(spot + UP * 60, Vector3.new(0, -200, 0), params)
		return hit and hit.Position or spot
	end
	function NR.rootOf(char)
		return char:FindFirstChild("HumanoidRootPart")
	end
	function NR.flat(v)
		local f = Vector3.new(v.X, 0, v.Z)
		return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
	end

	-- the body: root + a hitbox the size of it
	function NR.build(cf, hp)
		local cfg = NR.cfg()
		local m = Instance.new("Model")
		m.Name = "HighEndNomu"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(6, 7, 4)
		root.Transparency = 1
		root.CanCollide = false
		root.CanTouch = false
		root.CFrame = cf
		root.Parent = m
		local box = Instance.new("Part")
		box.Name = "Hitbox"
		box.Size = Vector3.new(9, 15, 6)
		box.Transparency = 1
		box.CanCollide = true
		box.CanTouch = false
		box.Massless = true
		box.CFrame = cf * CFrame.new(0, -2, 0)
		box.Parent = m
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = box
		weld.Parent = box
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R15
		hum.HipHeight = cfg.HipHeight or 6
		hum.MaxHealth = hp
		hum.Health = hp
		hum.WalkSpeed = cfg.WalkSpeed or 22
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.Parent = m
		m.PrimaryPart = root
		m:SetAttribute("Boss", true)
		m:SetAttribute("BossName", "HIGH-END NOMU")
		m:SetAttribute("Phase", 1)
		m:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
		m.Parent = NR.folder()
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		Reactions.armor[m] = { Until = math.huge, Scale = 1 }
		return m, hum, root
	end

	-- who's fair game: players in the city, alive, not off in One For All
	-- or at an UNO table, within Aggro of it
	function NR.targets(r)
		local out = {}
		for _, plr in Players:GetPlayers() do
			local c = plr.Character
			local cr = c and c:FindFirstChild("HumanoidRootPart")
			if cr and alive(c) and not plr:GetAttribute("InVestige") and not c:GetAttribute("PlayingUno")
				and (cr.Position - r.Root.Position).Magnitude <= (NR.cfg().Aggro or 260) then
				table.insert(out, c)
			end
		end
		return out
	end
	function NR.target(r)
		local best, bestDist
		for _, c in NR.targets(r) do
			local d = (NR.rootOf(c).Position - r.Root.Position).Magnitude - (c == r.Target and 8 or 0)
			if not bestDist or d < bestDist then
				best, bestDist = c, d
			end
		end
		r.Target = best
		return best, best and (NR.rootOf(best).Position - r.Root.Position).Magnitude
	end

	-- everyone near a point knocked flying (the landing, the slam)
	function NR.blast(r, center, radius, amount, push, lift, ragdollTime)
		for _, model in queryRadius(r.Model, center, radius) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			local falloff = mr and 1 - math.clamp((mr.Position - center).Magnitude / radius, 0, 1) * 0.45 or 1
			if amount <= 0 or damage(nil, model, math.floor(amount * falloff + 0.5), { From = center, Heavy = true }) then
				knockback(model, awayFrom(center, model, UP) * push * falloff + UP * lift, 0.3)
				if ragdollTime then
					ragdoll(model, ragdollTime)
				end
			end
		end
	end

	-- A RAID
	function NR.start()
		if NR.active then
			return false
		end
		local cfg = NR.cfg()
		local spot = cfg.Spot or (Config.DekuDrop or {}).Spot or Vector3.new(-70, 26, 868)
		local ground = NR.ground(spot)
		local count = 0
		for _, plr in Players:GetPlayers() do
			if not plr:GetAttribute("InVestige") then
				count += 1
			end
		end
		local hp = math.min(cfg.MaxHealth or 16000, (cfg.Health or 2600) + (cfg.PerPlayer or 1400) * math.max(count, 1))
		local r = { Ground = ground, Max = hp, Phase = 1, Dealt = {}, LastHit = os.clock(), Next = { Swipe = 0, Slam = 0, Charge = 0 }, Side = 1 }
		NR.active = r
		NR.next = os.clock() + (cfg.Every or 600)
		broadcast("NomuIncoming", nil, { Pos = ground, Land = cfg.LandAt or 2.6, Max = hp })
		task.delay(cfg.LandAt or 2.6, function()
			if NR.active == r then
				NR.land(r)
			end
		end)
		return true
	end

	function NR.land(r)
		local cfg = NR.cfg()
		local hip = (cfg.HipHeight or 6) + 3.5
		local m, hum, root = NR.build(CFrame.new(r.Ground + UP * hip), r.Max)
		r.Model, r.Hum, r.Root, r.Hip = m, hum, root, hip
		r.Ends = os.clock() + (cfg.TimeLimit or 240)
		Destruction.Sphere(r.Ground, cfg.Crater or 13, "Impact", -UP)
		NR.blast(r, r.Ground, cfg.LandRadius or 34, 12, 80, 45, 1.2)
		broadcast("NomuLanded", m, { Pos = r.Ground, Max = r.Max })
		hum.Died:Connect(function()
			NR.finish(r, "Defeated")
		end)
		r.Busy = true
		task.delay(1.1, function()
			r.Busy = false
			NR.roar(r)
		end)
		task.spawn(NR.run, r)
	end

	function NR.run(r)
		local nextState = 0
		while not r.Done and NR.active == r do
			local now = os.clock()
			local ok, err = pcall(NR.think, r, now)
			if not ok then
				warn("[QuirkServer] Nomu: " .. tostring(err))
			end
			if now >= nextState then
				nextState = now + 0.5
				NR.state(r, now)
			end
			task.wait(0.1)
		end
	end

	-- the damage board, the health, the clock: every half second, to everyone
	function NR.state(r, now)
		if r.Done or not r.Hum then
			return
		end
		local list = {}
		for plr, dmg in r.Dealt do
			if plr.Parent then
				table.insert(list, { Name = plr.DisplayName, Damage = math.floor(dmg), UserId = plr.UserId })
			end
		end
		table.sort(list, function(a, b)
			return a.Damage > b.Damage
		end)
		local byId = {}
		for i, e in list do
			byId[tostring(e.UserId)] = { Damage = e.Damage, Rank = i }
		end
		broadcast("NomuState", r.Model, {
			Health = math.floor(r.Hum.Health), Max = r.Max, Phase = r.Phase, Left = math.max(0, math.floor(r.Ends - now)),
			Top = { list[1], list[2], list[3] }, Board = byId, Count = #list, Regen = r.Model:GetAttribute("Regen") == true,
		})
	end

	function NR.think(r, now)
		if r.Done or not r.Model.Parent or r.Hum.Health <= 0 then
			return
		end
		local cfg = NR.cfg()
		if now >= r.Ends then
			NR.escape(r)
			return
		end
		if r.Phase == 1 and r.Hum.Health <= r.Max * 0.5 then
			r.Phase = 2
			r.Model:SetAttribute("Phase", 2)
			r.Hum.WalkSpeed = cfg.Phase2Speed or 29
			r.Model:SetAttribute("BaseWalkSpeed", r.Hum.WalkSpeed)
			NR.roar(r)
			return
		end
		-- Super Regeneration: left alone a while, it heals
		local regen = cfg.Regen or {}
		local healing = now - r.LastHit > (regen.After or 6) and r.Hum.Health < r.Max
		if healing then
			r.Hum.Health = math.min(r.Max, r.Hum.Health + r.Max * (regen.PerSecond or 0.012) * 0.1)
		end
		if (r.Model:GetAttribute("Regen") == true) ~= healing then
			r.Model:SetAttribute("Regen", healing or nil)
		end
		if r.Busy then
			return
		end
		local target, dist = NR.target(r)
		if not target then
			if (r.Root.Position - r.Ground).Magnitude > 20 then
				r.Hum:MoveTo(r.Ground)
			end
			return
		end
		local tr = NR.rootOf(target)
		local crowd = 0
		for _, c in NR.targets(r) do
			if (NR.rootOf(c).Position - r.Root.Position).Magnitude < 22 then
				crowd += 1
			end
		end
		local sw, sl, ch = cfg.Swipe or {}, cfg.Slam or {}, cfg.Charge or {}
		if dist <= (sw.Reach or 12) and now >= r.Next.Swipe then
			task.spawn(NR.swipe, r, target)
		elseif (crowd >= 2 or (dist > 14 and dist <= 30)) and now >= r.Next.Slam then
			task.spawn(NR.slam, r, target)
		elseif dist > 30 and dist <= (ch.Range or 80) and now >= r.Next.Charge then
			task.spawn(NR.charge, r, target)
		else
			r.Hum:MoveTo(tr.Position - NR.flat(tr.Position - r.Root.Position) * 6)
		end
	end
	-- (phase 2: everything comes round quicker)
	function NR.cool(r, t)
		return os.clock() + t * (r.Phase == 2 and 0.72 or 1)
	end

	-- SWIPE: a backhand the size of a car
	function NR.swipe(r, target)
		local s = NR.cfg().Swipe or {}
		r.Busy = true
		r.Next.Swipe = NR.cool(r, s.Cooldown or 1.5)
		local d = NR.flat(NR.rootOf(target).Position - r.Root.Position)
		r.Hum:MoveTo(r.Root.Position)
		r.Root.CFrame = CFrame.lookAt(r.Root.Position, r.Root.Position + d)
		r.Side = -r.Side
		broadcast("NomuMove", r.Model, { Kind = "Swipe", Dir = d, Windup = s.Windup or 0.45, Side = r.Side })
		task.wait(s.Windup or 0.45)
		if r.Done then
			return
		end
		for _, model in queryRadius(r.Model, r.Root.Position + d * 5, (s.Reach or 12) + 2) do
			local mr = model:FindFirstChild("HumanoidRootPart")
			if mr and NR.flat(mr.Position - r.Root.Position):Dot(d) > 0.1
				and damage(nil, model, s.Damage or 18, { From = r.Root.Position, Heavy = true }) then
				knockback(model, d * 85 + r.Root.CFrame.RightVector * r.Side * 30 + UP * 35, 0.3)
				ragdoll(model, 1.1)
			end
		end
		task.wait(0.35)
		r.Busy = false
	end

	-- SLAM: up, and down on top of them
	function NR.slam(r, target)
		local s = NR.cfg().Slam or {}
		r.Busy = true
		r.Next.Slam = NR.cool(r, s.Cooldown or 7)
		local land = groundTarget(r.Root, NR.rootOf(target).Position, 70, r.Model)
		local from = r.Root.Position
		local d = NR.flat(land - from)
		local air = s.Air or 0.85
		broadcast("NomuMove", r.Model, { Kind = "Slam", From = from, To = land, Air = air, Windup = s.Windup or 0.35 })
		r.Hum:MoveTo(from)
		task.wait(s.Windup or 0.35)
		if r.Done then
			return
		end
		r.Root.Anchored = true
		local to = land + UP * r.Hip
		local steps = 12
		for i = 1, steps do
			if r.Done then
				break
			end
			local k = i / steps
			local at = from:Lerp(to, k) + UP * 34 * 4 * k * (1 - k)
			r.Root.CFrame = CFrame.lookAt(at, at + d)
			task.wait(air / steps)
		end
		if r.Done then
			return
		end
		r.Root.CFrame = CFrame.lookAt(to, to + d)
		r.Root.Anchored = false
		broadcast("NomuImpact", nil, { Pos = land, Radius = s.Radius or 18 })
		NR.blast(r, land, s.Radius or 18, s.Damage or 26, 90, 55, 1.5)
		Destruction.Sphere(land, s.Crater or 9, "Impact", -UP)
		task.wait(0.6)
		r.Busy = false
	end

	-- CHARGE: the shoulder jets fire and it rams straight through
	function NR.charge(r, target)
		local s = NR.cfg().Charge or {}
		r.Busy = true
		r.Next.Charge = NR.cool(r, s.Cooldown or 6)
		local from = r.Root.Position
		local d = NR.flat(NR.rootOf(target).Position - from)
		local want = math.min((NR.rootOf(target).Position - from).Magnitude + 14, s.Range or 80)
		local reach = math.min(want, wallDistance(r.Model, from, d, want))
		r.Hum:MoveTo(from)
		r.Root.CFrame = CFrame.lookAt(from, from + d)
		broadcast("NomuMove", r.Model, { Kind = "Charge", Dir = d, Windup = s.Windup or 0.6, Dist = reach, Time = s.Time or 0.5 })
		task.wait(s.Windup or 0.6)
		if r.Done then
			return
		end
		r.Root.Anchored = true
		local hit = {}
		local steps = 10
		for i = 1, steps do
			if r.Done then
				break
			end
			local at = from + d * reach * (i / steps)
			r.Root.CFrame = CFrame.lookAt(at, at + d)
			for _, model in queryRadius(r.Model, at, s.Width or 7, hit) do
				hit[model] = true
				if damage(nil, model, s.Damage or 20, { From = at, Heavy = true }) then
					knockback(model, d * 110 + UP * 35, 0.3)
					ragdoll(model, 1.2)
				end
			end
			task.wait((s.Time or 0.5) / steps)
		end
		if r.Done then
			return
		end
		r.Root.Anchored = false
		if reach < want - 1 then
			Destruction.Sphere(from + d * (reach + 3), 8, "Impact", d) -- (it hit a wall: through it)
		end
		task.wait(0.5)
		r.Busy = false
	end

	-- ROAR: everyone near is blown back (the landing, and phase 2)
	function NR.roar(r)
		if r.Done then
			return
		end
		local s = NR.cfg().Roar or {}
		r.Busy = true
		broadcast("NomuMove", r.Model, { Kind = "Roar", Phase = r.Phase })
		for _, model in queryRadius(r.Model, r.Root.Position, s.Radius or 36) do
			knockback(model, awayFrom(r.Root.Position, model, UP) * (s.Push or 70) + UP * 25, 0.3)
			stun(model, 0.6)
		end
		task.delay(1.4, function()
			r.Busy = false
		end)
	end

	-- out of time: it takes off on its jets
	function NR.escape(r)
		if r.Done then
			return
		end
		r.Busy = true
		broadcast("NomuMove", r.Model, { Kind = "Escape" })
		r.Root.Anchored = true
		local from = r.Root.Position
		task.spawn(function()
			for i = 1, 20 do
				if not r.Root.Parent then
					return
				end
				r.Root.CFrame = CFrame.new(from + UP * (i * i * 0.6))
				task.wait(0.1)
			end
		end)
		NR.finish(r, "Escaped")
	end

	-- (from damage(), before it lands) who's hurting it
	function NR.hit(attacker, model, amount)
		local r = NR.active
		if not r or r.Done or model ~= r.Model then
			return
		end
		r.LastHit = os.clock()
		if attacker then
			r.Dealt[attacker] = (r.Dealt[attacker] or 0) + amount
		end
	end
	-- (from damage()) the truce: near it, players can't hurt each other
	function NR.truce(attacker, model)
		local r = NR.active
		local cfg = NR.cfg()
		if not r or r.Done or not r.Root or cfg.Truce == false or not attacker or not Players:GetPlayerFromCharacter(model) then
			return false
		end
		local ac = attacker.Character
		local ar, vr = ac and ac:FindFirstChild("HumanoidRootPart"), model:FindFirstChild("HumanoidRootPart")
		local radius = cfg.TruceRadius or 260
		return ar ~= nil and vr ~= nil and ac ~= model and (ar.Position - r.Root.Position).Magnitude <= radius and (vr.Position - r.Root.Position).Magnitude <= radius
	end

	-- over: beaten ("Defeated") or flown off ("Escaped"): everyone who fought it is paid
	function NR.finish(r, result)
		if r.Done then
			return
		end
		r.Done = true
		if NR.active == r then
			NR.active = nil
		end
		local cfg = NR.cfg()
		local pay = cfg.Rewards or {}
		local list, total = {}, 0
		for plr, dmg in r.Dealt do
			total += dmg
			if plr.Parent then
				table.insert(list, { Player = plr, Damage = dmg })
			end
		end
		table.sort(list, function(a, b)
			return a.Damage > b.Damage
		end)
		for i, e in list do
			local share = total > 0 and e.Damage / total or 0
			local earned = share >= (pay.MinShare or 0.02) or e.Damage >= (pay.MinDamage or 60)
			e.Reward = 0
			if result == "Defeated" and earned then
				e.Reward = (pay.Base or 5) + math.floor(share * (pay.Pool or 40)) + ((pay.Top or {})[i] or 0)
			elseif result == "Escaped" and earned then
				e.Reward = pay.Consolation or 1
			end
			if e.Reward > 0 and Store.AddBucks then
				Store.AddBucks(e.Player, e.Reward)
			end
		end
		local top = {}
		for i = 1, math.min(5, #list) do
			top[i] = { Name = list[i].Player.DisplayName, Damage = math.floor(list[i].Damage), Reward = list[i].Reward }
		end
		broadcast("NomuRaidEnd", r.Model, { Result = result, Top = top, Total = math.floor(total), Count = #list })
		for i, e in list do
			PlayVFX:FireClient(e.Player, "NomuReward", nil, { Reward = e.Reward, Damage = math.floor(e.Damage), Rank = i, Of = #list, Result = result })
		end
		if r.Model then
			Reactions.armor[r.Model] = nil
			local model = r.Model
			task.delay(result == "Defeated" and 4 or 2.5, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end
	end

	-- the schedule
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < NR.next then
			return
		end
		local cfg = NR.cfg()
		if NR.on() and not NR.active and #Players:GetPlayers() >= (cfg.MinPlayers or 1) then
			NR.start()
		else
			NR.next = now + 30
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if NR.active then
			NR.active.Dealt[player] = nil
		end
	end)
end


---------------------------------------------------------------------------
-- (round 75) FLOAT, the BLACKWHIP SLINGSHOT, RECIPRO EXTEND, PHANTOM
-- MENACE: ENDGAME
---------------------------------------------------------------------------
do
	-- FLOAT (Deku's 4th, Nana Shimura's quirk): his own machine floats him -
	-- he stays on his feet until he jumps, then flies where he looks. The
	-- server marks how long he's got (FloatUntil, on the body), and passes
	-- the lift-off, every Air Force flick and the touch-down on to everyone
	-- else. (Dropping out goes through even when he's been hit.)
	local FL = { KINDS = { FloatLift = true, FloatBoost = true, FloatEnd = true } }
	Kit.FL = FL
	local lastBoost = setmetatable({}, { __mode = "k" })
	function Handlers.Float(_player, char, _root, ability)
		char:SetAttribute("FloatUntil", workspace:GetServerTimeNow() + (ability.Window or 8) + (ability.Duration or 7) + 1)
	end
	function FL.relay(player, char, kind, dir)
		if not char or not char.Parent then
			return
		end
		if kind == "FloatEnd" then
			if char:GetAttribute("Floating") then
				char:SetAttribute("Floating", nil)
				broadcast("FloatFX", char, { Kind = "End" }, player)
			end
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not alive(char) or (char:GetAttribute("FloatUntil") or 0) < workspace:GetServerTimeNow()
			or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") then
			return
		end
		local spec = Config.FindAbilityById("Float") or {}
		local now = os.clock()
		if kind == "FloatBoost" then
			if not char:GetAttribute("Floating") or now - (lastBoost[player] or 0) < (spec.BoostEvery or 0.55) - 0.12 then
				return
			end
			lastBoost[player] = now
		else
			char:SetAttribute("Floating", true)
		end
		local d = (typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.01) and dir.Unit or root.CFrame.LookVector
		broadcast("FloatFX", char, { Kind = kind == "FloatLift" and "Lift" or "Boost", Dir = d }, player)
	end

	-- DASH, THEN BLACKWHIP: the slingshot. His own machine flies him; here
	-- it's checked (Deku, Blackwhip in his 4th slot - not at 100% - and its
	-- cooldown, which this shares at Dash.CooldownScale), everyone else sees
	-- it, and whoever's in the way gets clipped aside
	local WD = { KINDS = { WhipDash = true } }
	Kit.WD = WD
	function WD.relay(player, char, _kind, dir)
		local quirkName = player:GetAttribute("Quirk")
		local quirk = Config.Quirks[quirkName or ""]
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local pick = quirk and Config.PickedExtra(quirk, player:GetAttribute("QuirkPick"))
		if not root or not alive(char) or not pick or pick.Id ~= "Blackwhip" or not pick.Dash or player:GetAttribute("UltActive") == true
			or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") or char:GetAttribute("Frozen")
			or char:GetAttribute("Holding") or player:GetAttribute("NoSkills")
			or (char:GetAttribute("ErasedUntil") or 0) > workspace:GetServerTimeNow() then
			return false
		end
		local spec = pick.Dash
		local key = Config.CooldownKey(quirkName, Config.EXTRA_INDEX, false, false, player:GetAttribute("QuirkPick"))
		local cds = cooldowns[player] or {}
		cooldowns[player] = cds
		local now = os.clock()
		local full = pick.Cooldown or 10
		local length = full * (spec.CooldownScale or 0.6)
		if cds[key] and now - cds[key] < full - COOLDOWN_TOLERANCE and not player:GetAttribute("NoCooldowns") then
			return false
		end
		cds[key] = now - (full - length) -- (Blackwhip's back in `length` seconds)
		local d = (typeof(dir) == "Vector3" and dir == dir and dir.Magnitude > 0.01) and dir.Unit or root.CFrame.LookVector
		broadcast("WhipDash", char, { Dir = d, Time = spec.Time or 0.55, Speed = spec.Speed or 165 }, player)
		local f = flatten(d, root)
		task.spawn(function()
			sweep(player, char, root, spec.Time or 0.55, spec.Radius or 5, 2, f, function(model)
				if damage(player, model, spec.Damage or 8, { From = root.Position, Hitstop = 0.05 }) then
					local side = f:Cross(UP)
					local r = model:FindFirstChild("HumanoidRootPart")
					local sign = (r and (r.Position - root.Position):Dot(side) < 0) and -1 or 1
					knockback(model, side * sign * 55 + f * 20 + UP * 30, 0.2)
					stun(model, 0.6)
				end
			end)
		end)
		return true
	end

	-- RECIPRO EXTEND (Iida's R): the sprinter's start, then one rocket of a
	-- kick down the aim. The first body he meets rides his leg along
	-- (Carry) and is launched; nobody: he skids to a stop. His own machine
	-- moves him (ReciproExtendGo / ReciproExtendHit tell it how)
	function Handlers.ReciproExtend(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(ability.Startup or 0.45)
		if not alive(char) then
			return
		end
		local live = Kit.liveAim[player]
		if live and os.clock() - live.Time < 0.6 then
			d = flatten(live.Dir, root) -- (still aimable through the start)
		end
		local speed, range = ability.Speed or 175, ability.Range or 95
		local time = range / speed
		broadcast("ReciproExtendGo", char, { Dir = d, Time = time, Speed = speed })
		tunnel(char, root, time, 6, 6)
		local caught
		local hitSet = {}
		-- (his machine steers the run with his camera: go by where he's really heading)
		local function heading()
			local v = root.AssemblyLinearVelocity
			local f = Vector3.new(v.X, 0, v.Z)
			if f.Magnitude > 30 then
				d = f.Unit
			end
			return d
		end
		local t0 = os.clock()
		while os.clock() - t0 < time and alive(char) and not caught do
			for _, model in Rewind.QueryRadius(player, char, root.Position + heading() * 3, ability.Radius or 6, hitSet) do
				hitSet[model] = true
				if not caught and alive(model) then
					caught = model
				end
			end
			if not caught then
				task.wait(0.03)
			end
		end
		if not caught then
			broadcast("ReciproExtendWhiff", char, { Dir = d })
			return
		end
		local g = Grab.take(caught, (ability.Carry or 0.4) + 0.4)
		damage(player, caught, ability.Damage or 24, { From = root.Position, Heavy = true, Hitstop = 0.1, NoKnockdown = true })
		broadcast("ReciproExtendHit", char, { Target = caught, Dir = d, Carry = ability.Carry or 0.4, Speed = ability.CarrySpeed or 120 })
		if g then
			local c0 = os.clock()
			while os.clock() - c0 < (ability.Carry or 0.4) and alive(char) and g.Root.Parent do
				local h = heading()
				Grab.place(g, CFrame.lookAt(root.Position + h * 3.4 + UP * 0.6, root.Position + UP * 0.6))
				task.wait()
			end
			Grab.release(g)
		end
		if caught.Parent and alive(caught) then
			knockback(caught, d * (ability.Launch or 140) + UP * (ability.Lift or 55), 0.3)
			ragdoll(caught, 1.8)
			stun(caught, 1.2)
		end
		broadcast("ReciproExtendLaunch", char, { Target = caught, Dir = d, Pos = root.Position + d * 4 })
		Destruction.Sphere(root.Position + d * 5 + UP, 7, "Wind", d)
	end

	-- PHANTOM MENACE: ENDGAME (Lemillion's ult 4): down into the street,
	-- up under each of them in turn (launched), then out of thin air over
	-- them all and down through the middle - the street erupts
	function Handlers.PhantomEndgame(player, char, root, ability)
		local PR = Kit.PR
		if not PR then
			return
		end
		local start = root.Position
		local list = {}
		for _, model in queryRadius(char, start, ability.Radius or 45) do
			local r = model:FindFirstChild("HumanoidRootPart")
			if r and alive(model) and not (Kit.TW and Kit.TW.mine(player, model)) then
				table.insert(list, { Model = model, Dist = (r.Position - start).Magnitude })
			end
		end
		table.sort(list, function(a, b)
			return a.Dist < b.Dist
		end)
		local count = math.min(#list, ability.Targets or 5)
		local gap = ability.Gap or 0.42
		PR.vanish(char, root, 0.5 + count * gap + 1.6, false)
		-- into the street
		local sink = groundBelow(start, char)
		PR.place(root, CFrame.new(sink - UP * 6) * root.CFrame.Rotation)
		task.wait(0.45)
		local hit = {}
		for i = 1, count do
			local model = list[i].Model
			local r = model.Parent and model:FindFirstChild("HumanoidRootPart")
			if r and alive(model) and alive(char) then
				local g = groundBelow(r.Position, model)
				local d = flatten(r.Position - root.Position, root)
				broadcast("EndgameRise", char, { Target = model, Pos = g, Index = i, Count = count })
				-- up out of the street under them...
				PR.place(root, CFrame.lookAt(g + UP * 2.6, g + UP * 2.6 + d))
				if damage(player, model, ability.Damage or 12, { From = g, Heavy = true, Hitstop = 0.06, Unblockable = true }) then
					knockback(model, UP * (ability.Lift or 70) + d * 6, 0.25)
					stun(model, 1.6)
				end
				table.insert(hit, model)
				task.wait(gap * 0.6)
				-- ...and back down into it
				PR.place(root, CFrame.new(g - UP * 6) * root.CFrame.Rotation)
				task.wait(gap * 0.4)
			end
		end
		if not alive(char) then
			PR.appear(char, root)
			return
		end
		local center = start
		if #hit > 0 then
			local sum = Vector3.zero
			for _, m in hit do
				local r = m:FindFirstChild("HumanoidRootPart")
				sum += r and r.Position or start
			end
			center = sum / #hit
		end
		local ground = groundBelow(center + UP * 4, char)
		-- out of thin air over them all, and down
		local from = ground + UP * 34
		PR.place(root, CFrame.new(from))
		broadcast("EndgameDrop", char, { Pos = ground, Time = 0.5 })
		local t0 = os.clock()
		while os.clock() - t0 < 0.5 do
			local k = math.clamp((os.clock() - t0) / 0.5, 0, 1) ^ 2
			PR.place(root, CFrame.new(from:Lerp(ground + UP * 3, k)))
			task.wait()
		end
		PR.appear(char, root, CFrame.new(ground + UP * 3), 0.4)
		broadcast("EndgameBlast", char, { Pos = ground, Radius = ability.Blast or 26 })
		for _, model in queryRadius(char, ground + UP * 2, ability.Blast or 26) do
			if damage(player, model, ability.FinisherDamage or 24, { From = ground, Heavy = true, Hitstop = 0.12 }) then
				knockback(model, awayFrom(ground, model, UP) * 90 + UP * 30, 0.25)
				ragdoll(model, 1.8)
			end
		end
		Destruction.Sphere(ground, 12, "Crater", -UP)
	end
end

---------------------------------------------------------------------------
-- (round 74) PRIME DEKU and PRIME ALL MIGHT (dev characters)
---------------------------------------------------------------------------
-- Prime Deku's FLASH STEP (and Prime All Might's I AM HERE) are held moves
-- with a ring (Hold.Marker): the key goes down and he's gone - untouchable,
-- still, "Vanished" (every screen hides him) - while his own screen draws
-- the ring where he'll come back; the key again and he's there. Anyone in
-- the ring is caught: held still for the cinematic (their camera and his),
-- and the blow lands at the end of it.
do
	-- (round 75) BEHIND slowed right down for the camera's walk round her
	local PR = { BEHIND = { Place = 0.34, Strike = 2.1 }, METEOR = { Look = 0.85, Fall = 0.42, Height = 130 } }
	Kit.PR = PR

	-- the street under the aim, at most `range` out from `origin` - the way
	-- his screen draws the ring (Hold.spot): straight down from above him
	function PR.ground(char, origin, aim, range, reach, floorY)
		local pos = (typeof(aim) == "Vector3" and aim == aim) and aim or origin
		local flat = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z)
		if flat.Magnitude > range then
			flat = flat.Unit * range
		end
		local xz = origin + flat
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = nonMapStuff(char)
		local hit = workspace:Raycast(Vector3.new(xz.X, origin.Y + 25, xz.Z), Vector3.new(0, -(reach or 90), 0), params)
		return hit and hit.Position or Vector3.new(xz.X, floorY or origin.Y - 3, xz.Z)
	end

	-- whoever's nearest the middle of the ring (within radius across, and
	-- about level with it)
	function PR.nearestTo(player, char, spot, radius)
		local best, bestDist
		for _, model in queryRadius(char, spot + UP * 2, radius + 4) do
			local r = model:FindFirstChild("HumanoidRootPart")
			if r and alive(model) and not (Kit.TW and Kit.TW.mine(player, model)) then
				local v = r.Position - spot
				local across = Vector3.new(v.X, 0, v.Z).Magnitude
				if across <= radius and v.Y > -6 and v.Y < 16 and (not bestDist or across < bestDist) then
					best, bestDist = model, across
				end
			end
		end
		return best
	end

	-- gone: held still where he is and nothing touches him
	function PR.vanish(char, root, t, hidden)
		if hidden ~= false then
			char:SetAttribute("Vanished", true)
		end
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + t)
		root.Anchored = true
	end
	-- (still gone) somewhere else
	function PR.place(root, cf)
		if root.Parent then
			root.CFrame = cf
		end
	end
	-- back, standing at cf
	function PR.appear(char, root, cf, grace)
		if root.Parent then
			if cf then
				root.CFrame = cf
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = false
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
		char:SetAttribute("Vanished", nil)
		iFrames[char] = os.clock() + (grace or 0.25)
	end

	-- someone in the ring: he's behind them. Everyone's screen gets the
	-- FlashBehind (theirs and his: the close-up), the kick lands at Strike
	function PR.behind(player, char, root, target, ability)
		local troot = target:FindFirstChild("HumanoidRootPart")
		local look = flatten(troot.CFrame.LookVector, troot)
		local g = Grab.take(target, PR.BEHIND.Strike + 0.4)
		local at = troot.Position - look * 3.3
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + PR.BEHIND.Strike + 0.4)
		broadcast("FlashBehind", char, { Target = target, Pos = at, Look = look, Strike = PR.BEHIND.Strike, Place = PR.BEHIND.Place, Name = ability.Name })
		task.wait(PR.BEHIND.Place)
		PR.place(root, CFrame.lookAt(at, at + look))
		char:SetAttribute("Vanished", nil) -- (there he is)
		task.wait(PR.BEHIND.Strike - PR.BEHIND.Place)
		if g then
			Grab.release(g)
		end
		PR.appear(char, root, CFrame.lookAt(at, at + look), 0.3)
		if not alive(char) or not target.Parent then
			return
		end
		if damage(player, target, ability.Damage or 30, { From = at, Heavy = true, Hitstop = 0.22, Unblockable = true }) then
			knockback(target, look * (ability.Launch or 150) * 1.15 + UP * (ability.Lift or 55), 0.3) -- (round 75: the big punch)
			ragdoll(target, ability.Ragdoll or 2)
		end
		broadcast("FlashStrike", char, { Target = target, Dir = look, Pos = troot.Position })
		Destruction.Box(CFrame.lookAt(troot.Position, troot.Position + look) * CFrame.new(0, 1.5, -20), Vector3.new(12, 11, 36), "Wind", look)
	end

	-- 1: FLASH STEP
	function Handlers.PrimeFlashStep(player, char, root, ability, _dir, pos)
		local max = (ability.Hold and ability.Hold.Max) or 2.6
		PR.vanish(char, root, max + 1.2)
		local _, hold = HoldMoves.wait(player, char, ability)
		if not alive(char) or player.Character ~= char then
			char:SetAttribute("Vanished", nil)
			return
		end
		local spot = PR.ground(char, root.Position, (hold and hold.Aim) or pos, ability.Range or 75)
		local target = PR.nearestTo(player, char, spot, ability.Radius or 11)
		if target then
			PR.behind(player, char, root, target, ability)
			return
		end
		-- nobody there: he lands in a shockwave
		local d = flatten(spot - root.Position, root)
		local at = spot + UP * 3
		PR.appear(char, root, CFrame.lookAt(at, at + d))
		broadcast("FlashAppear", char, { Pos = spot, Dir = d, Radius = ability.MissRadius or 10 })
		for _, model in queryRadius(char, spot + UP * 2, ability.MissRadius or 10) do
			if damage(player, model, ability.MissDamage or 8, { From = spot }) then
				knockback(model, awayFrom(spot, model, d) * 60 + UP * 30, 0.2)
				stun(model, 0.5)
			end
		end
		Destruction.Sphere(spot, 4.5, "Impact", -UP)
	end

	-- 2: BLACKWHIP REEL - the whips catch everyone in the fan, reel them in,
	-- and the St. Louis Smash sends them all flying
	function Handlers.BlackwhipReel(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.16)
		if not alive(char) then
			return
		end
		local range = ability.Range or 58
		local half = math.rad(ability.Spread or 50) / 2
		local origin = root.Position + UP * 1.2
		local list = {}
		for _, model in queryRadius(char, root.Position + d * range * 0.5, range * 0.62) do
			local r = model:FindFirstChild("HumanoidRootPart")
			if r then
				local v = r.Position - root.Position
				local flat = Vector3.new(v.X, 0, v.Z)
				local to = r.Position - origin
				if flat.Magnitude > 0.5 and flat.Magnitude <= range and math.acos(math.clamp(flat.Unit:Dot(d), -1, 1)) <= half + 0.05
					and wallDistance(char, origin, to.Unit, to.Magnitude) >= to.Magnitude - 2.5 then
					table.insert(list, { m = model, dist = flat.Magnitude })
				end
			end
		end
		table.sort(list, function(a, b)
			return a.dist < b.dist
		end)
		local caught = {}
		for i = 1, math.min(#list, ability.MaxTargets or 4) do
			table.insert(caught, list[i].m)
		end
		broadcast("BlackwhipReelCast", char, { Dir = d, Targets = caught })
		task.wait(0.22)
		local held = {}
		for i, model in caught do
			if alive(char) and damage(player, model, ability.CatchDamage or 6, { From = root.Position, NoKnockdown = true }) then
				local g = Grab.take(model, 1.3)
				if g then
					table.insert(held, { g = g, from = g.Root.Position, slot = i, n = #caught })
				end
			end
		end
		if #held == 0 then
			return
		end
		-- reeled in to him, fanned out in front
		local reel = 0.32
		local t0 = os.clock()
		while os.clock() - t0 < reel and alive(char) do
			local k = math.clamp((os.clock() - t0) / reel, 0, 1) ^ 1.6
			for _, h in held do
				local a = (h.n > 1) and ((h.slot - 1) / (h.n - 1) - 0.5) * 1.6 or 0
				local to = root.Position + (CFrame.fromAxisAngle(UP, a) * d) * 4.6
				local at = h.from:Lerp(Vector3.new(to.X, root.Position.Y, to.Z), k)
				Grab.place(h.g, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
			end
			task.wait(1 / 30)
		end
		broadcast("BlackwhipReelKick", char, { Dir = d })
		task.wait(0.14)
		for _, h in held do
			Grab.release(h.g)
			local m = h.g.Model
			if alive(char) and damage(player, m, ability.Damage or 20, { From = root.Position, Heavy = true, Hitstop = 0.08 }) then
				knockback(m, awayFrom(root.Position, m, d) * 125 + UP * 48, 0.25)
				ragdoll(m, 1.5)
			end
		end
		Destruction.Cylinder(root.Position, 9, 6, "Wind", d)
	end

	-- 3: AIR FORCE STORM - up on Float (his machine lifts him), the bullets
	-- come down all over the spot, one after another
	function Handlers.AirForceStorm(player, char, root, ability, dir, pos)
		local spot = groundTarget(root, pos, ability.Range or 90, char)
		local n, radius = ability.Shots or 12, ability.Radius or 13
		local rng = Random.new(math.floor(os.clock() * 1000) % 100000)
		local spots = {}
		for i = 1, n do
			local a = rng:NextNumber() * math.pi * 2
			local r = (i == 1) and 0 or radius * math.sqrt(rng:NextNumber())
			spots[i] = groundBelow(spot + Vector3.new(math.cos(a) * r, 8, math.sin(a) * r), char)
		end
		task.wait(0.28)
		if not alive(char) then
			return
		end
		broadcast("AirForceShots", char, { Spots = spots, Gap = ability.Gap or 0.07 })
		local gap = ability.Gap or 0.07
		for i, at in spots do
			task.delay(0.09, function()
				for _, model in queryRadius(char, at + UP * 2, ability.Splash or 7) do
					if damage(player, model, ability.Damage or 5, { From = at + UP * 6, NoKnockdown = true, Hitstop = 0.02 }) then
						knockback(model, awayFrom(at, model, UP) * 18 + UP * 14, 0.12)
						stun(model, 0.55)
					end
				end
				if i % 2 == 1 then
					Destruction.Sphere(at, 3.2, "Impact", -UP)
				end
			end)
			task.wait(gap)
			if not alive(char) then
				return
			end
		end
	end

	-- R: DANGER SENSE - a counter stance (Kit.counters, like Hero's
	-- Counter); what answers the hit is his own (stance.React)
	function PR.dangerReact(attacker, model, opts, stance)
		local ac = attacker.Character
		local ar = ac and ac:FindFirstChild("HumanoidRootPart")
		local mr = model:FindFirstChild("HumanoidRootPart")
		iFrames[model] = math.max(iFrames[model] or 0, os.clock() + 0.7)
		if not (ar and mr) or (ar.Position - mr.Position).Magnitude > 60 then
			broadcast("DangerSense", model, { From = opts and opts.From })
			return true -- (too far off to answer: he's just not there)
		end
		local look = flatten(ar.CFrame.LookVector, ar)
		local at = ar.Position - look * 3.2
		broadcast("DangerFlash", model, { Target = ac, From = mr.Position, Pos = at, Look = look })
		task.spawn(function()
			PR.vanish(model, mr, 0.6)
			task.wait(0.16)
			PR.appear(model, mr, CFrame.lookAt(at, at + look), 0.35)
			task.wait(0.1)
			if alive(model) and alive(ac) and damage(stance.Player, ac, stance.Ability.Damage or 22, { Heavy = true, Unblockable = true, Hitstop = 0.12, From = at }) then
				knockback(ac, look * 140 + UP * 50, 0.28)
				ragdoll(ac, 1.6)
			end
		end)
		return true
	end
	function Handlers.DangerCounter(player, char, _root, ability)
		local stance = { Until = os.clock() + (ability.Window or 1), Player = player, Ability = ability, React = PR.dangerReact }
		Kit.counters[char] = stance
		char:SetAttribute("Countering", true)
		task.wait(ability.Window or 1)
		if Kit.counters[char] == stance then
			Kit.counters[char] = nil
		end
		char:SetAttribute("Countering", nil)
	end

	-- 4: VESTIGE SMASH - the fist comes down on the aim point
	function Handlers.VestigeSmash(player, char, root, ability, dir, pos)
		local spot = groundTarget(root, pos, ability.Range or 95, char)
		task.wait(ability.Delay or 0.85)
		if not alive(char) then
			return
		end
		local d = flatten(dir, root)
		for _, model in queryRadius(char, spot + UP * 4, ability.Radius or 22) do
			if damage(player, model, ability.Damage or 30, { From = spot + UP * 30, Heavy = true, Hitstop = 0.1 }) then
				knockback(model, awayFrom(spot, model, d) * 75 + UP * 55, 0.25)
				ragdoll(model, 1.8)
			end
		end
		Destruction.Sphere(spot, ability.Crater or 20, "Crater")
	end

	-- ULT 2: FLASH STEP CHAIN - behind each of them in turn (nearest first),
	-- a kick each; the last one sends them all flying
	function Handlers.FlashStepChain(player, char, root, ability)
		local list = {}
		for _, model in queryRadius(char, root.Position, ability.Range or 85) do
			local r = model:FindFirstChild("HumanoidRootPart")
			if r and alive(model) and not model:GetAttribute("Ragdolled") and not (Kit.TW and Kit.TW.mine(player, model)) then
				table.insert(list, { m = model, dist = (r.Position - root.Position).Magnitude })
			end
		end
		table.sort(list, function(a, b)
			return a.dist < b.dist
		end)
		local n = math.min(#list, ability.Targets or 5)
		if n == 0 then
			broadcast("FlashChainWhiff", char, {})
			return
		end
		local gap = ability.Gap or 0.32
		PR.vanish(char, root, n * gap + 1.2)
		local hit = {}
		for i = 1, n do
			local target = list[i].m
			local troot = target:FindFirstChild("HumanoidRootPart")
			if troot and alive(target) and alive(char) then
				local look = flatten(troot.CFrame.LookVector, troot)
				local at = troot.Position - look * 3
				PR.place(root, CFrame.lookAt(at, at + look))
				broadcast("FlashChainHit", char, { Target = target, Pos = at, Look = look, Index = i, Count = n })
				task.wait(0.07)
				if damage(player, target, ability.Damage or 10, { From = at, Hitstop = 0.05, Unblockable = true, NoKnockdown = true }) then
					stun(target, gap * (n - i) + 0.9, 0)
					table.insert(hit, { m = target, look = look })
				end
				task.wait(math.max(gap - 0.07, 0.05))
			end
		end
		PR.appear(char, root, nil, 0.35)
		broadcast("FlashChainEnd", char, {})
		task.wait(0.12)
		for _, h in hit do
			if alive(h.m) and damage(player, h.m, ability.FinisherDamage or 18, { From = root.Position, Heavy = true, Unblockable = true }) then
				knockback(h.m, h.look * 150 + UP * 60, 0.28)
				ragdoll(h.m, 1.8)
			end
		end
	end

	-- ULT 3: 1,000,000% DELAWARE DETROIT SMASH - the eight at his back
	function Handlers.VestigeDDS(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(ability.Charge or 1.5)
		if not alive(char) then
			return
		end
		local origin = root.Position
		local range, width = ability.Range or 260, ability.Width or 70
		local look = CFrame.lookAt(origin, origin + d)
		local hitSet = {}
		local segments = 7
		for i = 1, segments do
			local a, b = (i - 1) / segments * range, i / segments * range
			local w = width * (0.5 + 0.5 * i / segments)
			for _, model in queryBox(char, look * CFrame.new(0, 12, -(a + b) / 2), Vector3.new(w, 70, b - a + 6), hitSet) do
				hitSet[model] = true
				if damage(player, model, ability.Damage or 52, { Heavy = true, From = origin }) then
					knockback(model, d * 280 + UP * 100, 0.35)
					stun(model, 2)
				end
			end
			Destruction.Box(look * CFrame.new(0, 14, -(a + b) / 2), Vector3.new(w * 0.8, 50, b - a + 4), "Wind", d)
			task.wait(0.05)
		end
	end

	-----------------------------------------------------------------------
	-- PRIME ALL MIGHT
	-----------------------------------------------------------------------

	-- 1: MISSOURI SMASH - his own machine carries him down the aim (the
	-- lariat); everyone he meets goes down
	function Handlers.MissouriSmash(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.1)
		if not alive(char) then
			return
		end
		local t = ability.Time or 0.3
		tunnel(char, root, t, 7, 5, function()
			return d
		end, "Wind")
		sweep(player, char, root, t + 0.08, (ability.Width or 8) * 0.6, 2.5, d, function(model)
			if damage(player, model, ability.Damage or 20, { From = root.Position, Heavy = true, Hitstop = 0.06 }) then
				local side = model:FindFirstChild("HumanoidRootPart")
				local off = side and (side.Position - root.Position) or d
				local lateral = Vector3.new(off.X, 0, off.Z) - d * Vector3.new(off.X, 0, off.Z):Dot(d)
				local away = lateral.Magnitude > 0.5 and lateral.Unit or d:Cross(UP)
				knockback(model, d * 90 + away * 45 + UP * 55, 0.25)
				ragdoll(model, 1.4)
			end
		end)
		if alive(char) then
			broadcast("SonicBoom", char, { Pos = root.Position, Dir = d })
		end
	end

	-- 2: TEXAS SMASH: HURRICANE - a twister lying down the street
	function Handlers.HurricaneSmash(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.32)
		if not alive(char) then
			return
		end
		local origin = root.Position
		local range, width = ability.Range or 140, ability.Width or 26
		local look = CFrame.lookAt(origin, origin + d)
		local ticks = ability.Ticks or 5
		local per = (ability.Damage or 18) / ticks
		local caught = {}
		local time = ability.Time or 1.1
		for k = 1, ticks do
			local reach = range * math.min(1, k / ticks + 0.25)
			for _, model in queryBox(char, look * CFrame.new(0, 4, -reach / 2), Vector3.new(width, 18, reach)) do
				local r = model:FindFirstChild("HumanoidRootPart")
				if r then
					caught[model] = true
					if damage(player, model, per, { From = origin, NoKnockdown = true, Hitstop = 0.02 }) then
						-- dragged along it, spinning up
						local toAxis = (origin + d * (r.Position - origin):Dot(d)) - r.Position
						toAxis = Vector3.new(toAxis.X, 0, toAxis.Z)
						knockback(model, d * 70 + toAxis * 3 + UP * 22, 0.2)
						stun(model, 0.6)
					end
				end
			end
			Destruction.Box(look * CFrame.new(0, 6, -reach / 2), Vector3.new(width * 0.7, 14, reach), "Wind", d)
			task.wait(time / ticks)
		end
		-- thrown out the end of it
		for model in caught do
			if alive(model) then
				knockback(model, d * 130 + UP * 70, 0.3)
				ragdoll(model, 1.6)
			end
		end
	end

	-- 3: DETROIT SMASH: PRIME - the street in front of him, gone
	function Handlers.PrimeDetroit(player, char, root, ability, dir)
		task.wait(0.4)
		if not alive(char) then
			return
		end
		local d = flatten(dir, root)
		local length, width = ability.Range or 120, ability.Width or 40
		local look = CFrame.lookAt(root.Position, root.Position + d)
		for _, model in queryBox(char, look * CFrame.new(0, 6, -length / 2), Vector3.new(width, 34, length)) do
			if damage(player, model, ability.Damage or 30, { Heavy = true, From = root.Position, Hitstop = 0.08 }) then
				knockback(model, d * 160 + UP * 55, 0.3)
				stun(model, 1.2)
				ragdoll(model, 1.6)
			end
		end
		Destruction.Box(look * CFrame.new(0, 9, -length * 0.55), Vector3.new(width * 0.8, 34, length), "Wind", d)
	end

	-- R: I AM HERE - out of sight, then down like a meteor on the ring
	function Handlers.IAmHereLeap(player, char, root, ability, _dir, pos)
		local M = PR.METEOR
		local start = root.Position
		local max = (ability.Hold and ability.Hold.Max) or 3
		-- up and gone (Effects.IAmHereLeap): he waits up there - it's where
		-- his own screen aims from
		task.wait(0.22)
		if not alive(char) then
			return
		end
		PR.vanish(char, root, max + 3, false)
		PR.place(root, CFrame.new(start + UP * M.Height) * root.CFrame.Rotation)
		local _, hold = HoldMoves.wait(player, char, ability)
		if not alive(char) or player.Character ~= char then
			return
		end
		local sky = root.Position
		local spot = PR.ground(char, sky, (hold and hold.Aim) or pos, ability.Range or 160, M.Height + 200, start.Y - 3)
		local d = flatten(spot - start, root)
		local target = PR.nearestTo(player, char, spot, ability.Radius or 12)
		local g = target and Grab.take(target, M.Look + M.Fall + 0.4)
		if target and not g then
			target = nil -- (can't be held still: he just comes down)
		end
		local look = target and M.Look or 0
		broadcast("MeteorFall", char, { Pos = spot, Target = target, Look = look, Fall = M.Fall, Dir = d })
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + look + M.Fall + 0.4)
		-- (the look up: he's a speck against the sun, right above them)
		local high = spot + UP * (M.Height * 0.8) - d * 12
		PR.place(root, CFrame.lookAt(high, high + d))
		task.wait(look)
		local from = root.Position
		local t0 = os.clock()
		while os.clock() - t0 < M.Fall and root.Parent do
			local k = math.clamp((os.clock() - t0) / M.Fall, 0, 1) ^ 1.8
			local p = from:Lerp(spot + UP * 3, k)
			PR.place(root, CFrame.lookAt(p, p + d)) -- (upright: the dive is his pose)
			task.wait()
		end
		PR.appear(char, root, CFrame.lookAt(spot + UP * 3, spot + UP * 3 + d), 0.3)
		if g then
			Grab.release(g)
		end
		if target and alive(target) and damage(player, target, ability.Damage or 30, { From = spot + UP * 20, Heavy = true, Hitstop = 0.14, Unblockable = true }) then
			knockback(target, d * 40 + UP * 20, 0.2)
			ragdoll(target, 2)
		end
		for _, model in queryRadius(char, spot + UP * 3, ability.Splash or 24) do
			if model ~= target and damage(player, model, ability.SplashDamage or 12, { From = spot, Heavy = true }) then
				knockback(model, awayFrom(spot, model, d) * 90 + UP * 50, 0.25)
				ragdoll(model, 1.3)
			end
		end
		Destruction.Sphere(spot, ability.Crater or 18, "Crater")
	end

	-- 4: PLUS ULTRA - the USJ: the first one in front, held, punched past
	-- 100% Hits times, and the last one through the roof of the sky
	function Handlers.PlusUltraUSJ(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local target = Grab.nearest(char, root, d, ability.Range or 12, 0.2)
		local hits, interval = ability.Hits or 24, ability.Interval or 0.05
		local total = hits * interval + 0.4
		local g = target and Grab.take(target, total + 0.5)
		if not g then
			broadcast("USJWhiff", char, { Dir = d })
			return
		end
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + total + 0.3)
		local anchored = root.Anchored
		root.Anchored = true
		local at = root.Position + d * 4.6
		Grab.place(g, CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
		broadcast("USJRush", char, { Target = target, Hits = hits, Interval = interval, Dir = d })
		task.wait(0.25)
		for i = 1, hits do
			if not alive(char) or not target.Parent then
				break
			end
			damage(player, target, ability.Damage or 2, { From = root.Position, Unblockable = true, NoKnockdown = true, Hitstop = i % 6 == 0 and 0.03 or nil })
			Grab.place(g, CFrame.lookAt(at + UP * math.min(i * 0.12, 2.4), Vector3.new(root.Position.X, at.Y, root.Position.Z)))
			task.wait(interval)
		end
		root.Anchored = anchored
		Grab.release(g)
		if alive(char) and alive(target) and damage(player, target, ability.FinisherDamage or 24, { From = root.Position, Heavy = true, Hitstop = 0.16, Unblockable = true, NoCap = true }) then
			knockback(target, d * (ability.Launch or 60) + UP * (ability.Lift or 190), 0.45)
			ragdoll(target, 3)
		end
		broadcast("USJFinish", char, { Target = target, Dir = d })
		Destruction.Cylinder(at + UP * 20, 6, 40, "Wind", UP)
	end

	-- ULT 3: UNITED STATES OF SMASH - All Might's own, bigger numbers
	function Handlers.PrimeUSS(...)
		return Handlers.UnitedStatesSmash(...)
	end
end

---------------------------------------------------------------------------
-- (round 74) DIO: THE WORLD (dev character)
---------------------------------------------------------------------------
-- ZA WARUDO (TS): everyone within Radius but him is frozen where they stand
-- - "TimeStopped", the root anchored, stunned, their moves cut, nothing
-- they press goes through. Whatever he does to them in it is HELD: damage()
-- (TS.hold), knockback() (TS.push) and ragdoll() (TS.rag) put it on their
-- tab instead, and when time moves again (TS.resume) it all arrives at
-- once. A move of his that needs stopped time (the road roller) starts it
-- itself if it isn't already.
do
	local TS = { frozen = setmetatable({}, { __mode = "k" }), active = setmetatable({}, { __mode = "k" }) }
	Kit.TS = TS
	Reactions.TS = TS

	-- the stopped time this body is caught in (nil: time moves for them)
	function TS.of(model)
		local e = model and TS.frozen[model]
		return (e and not e.Releasing) and e or nil
	end

	function TS.freeze(stop, model)
		local r = model:FindFirstChild("HumanoidRootPart")
		if not r or TS.frozen[model] then
			return
		end
		local e = { Stop = stop, Hits = {}, Push = Vector3.zero, PushTime = 0, Rag = 0, Anchored = r.Anchored }
		TS.frozen[model] = e
		table.insert(stop.Models, model)
		if guardState[model] and guardState[model].Blocking then
			setBlocking(model, false)
		end
		Moves.cut(model)
		for _, d in r:GetChildren() do
			if d.Name == "Knockback" or d.Name == "KnockbackAttachment" then
				d:Destroy()
			end
		end
		model:SetAttribute("TimeStopped", true)
		r.Anchored = true
		stun(model, math.max(stop.Until - os.clock(), 0) + 0.25, 0)
	end

	-- time stops: everyone within radius but him
	function TS.stop(player, char, duration, radius)
		local root = char:FindFirstChild("HumanoidRootPart")
		local now = TS.active[char]
		if now and not now.Done then
			now.Until = math.max(now.Until, os.clock() + duration)
			return now
		end
		if not root then
			return nil
		end
		local stop = { Player = player, Char = char, Until = os.clock() + duration, Models = {}, Radius = radius }
		TS.active[char] = stop
		char:SetAttribute("StoppedTime", true)
		for _, model in queryRadius(char, root.Position, radius) do
			if model ~= char and alive(model) then
				TS.freeze(stop, model)
			end
		end
		broadcast("TimeStop", char, { Radius = radius, Duration = duration, Frozen = stop.Models })
		task.spawn(function()
			while not stop.Done and os.clock() < stop.Until and alive(char) and player.Character == char do
				task.wait(0.05)
			end
			TS.resume(stop)
		end)
		return stop
	end

	-- ...and moves again: everything held lands now
	function TS.resume(stop)
		if stop.Done then
			return
		end
		stop.Done = true
		if TS.active[stop.Char] == stop then
			TS.active[stop.Char] = nil
		end
		stop.Char:SetAttribute("StoppedTime", nil)
		broadcast("TimeResume", stop.Char, { Frozen = stop.Models })
		for _, model in stop.Models do
			local e = TS.frozen[model]
			if e and e.Stop == stop then
				e.Releasing = true
				TS.frozen[model] = nil
				if model.Parent then
					model:SetAttribute("TimeStopped", nil)
					local r = model:FindFirstChild("HumanoidRootPart")
					if r and not model:GetAttribute("Grabbed") then
						r.Anchored = e.Anchored and model:GetAttribute("Frozen") == true
					end
					task.spawn(TS.deliver, model, e)
				end
			end
		end
	end

	function TS.deliver(model, e)
		if #e.Hits > 0 then
			broadcast("TimeHits", nil, { Target = model, Count = #e.Hits })
		end
		for i, h in e.Hits do
			if not alive(model) then
				break
			end
			local opts = table.clone(h.Opts or {})
			opts.Hitstop = nil
			damage(h.Attacker, model, h.Amount, opts)
			if i % 4 == 0 then
				task.wait()
			end
		end
		if not alive(model) then
			return
		end
		if e.Push.Magnitude > 1 then
			local v = e.Push
			if v.Magnitude > 230 then
				v = v.Unit * 230
			end
			knockback(model, v, math.max(e.PushTime, 0.2))
		end
		if e.Rag > 0 then
			ragdoll(model, math.min(e.Rag, 3))
		end
	end

	-- (the hooks in damage / knockback / ragdoll) a hit on a stopped body is
	-- held for when time moves; true: it's been taken
	function TS.hold(attacker, model, amount, opts)
		local e = TS.of(model)
		if not e then
			return false
		end
		table.insert(e.Hits, { Attacker = attacker, Amount = amount, Opts = opts })
		broadcast("TimeHit", nil, { Target = model, Pos = opts and opts.From or nil, Heavy = opts and opts.Heavy or nil })
		return true
	end
	function TS.push(model, velocity, duration)
		local e = TS.of(model)
		if not e then
			return false
		end
		e.Push += velocity
		e.PushTime = math.max(e.PushTime, duration or 0.2)
		return true
	end
	function TS.rag(model, duration)
		local e = TS.of(model)
		if not e then
			return false
		end
		e.Rag = math.max(e.Rag, duration or 1)
		return true
	end

	-- R: ZA WARUDO
	function Handlers.ZaWarudo(player, char, _root, ability)
		task.wait(0.55) -- ("ZA WARUDO!" - The World throws its arms wide)
		if not alive(char) then
			return
		end
		TS.stop(player, char, ability.Duration or 5, ability.Radius or 220)
	end

	-- 1: MUDA MUDA - the Stand's rush (Crazy Diamond's, in gold)
	function Handlers.MudaRush(...)
		return Handlers.Dorarara(...)
	end

	-- a knife from `from` down d: the first one in its way (short of the
	-- wall) takes it. In stopped time the hit is held like any other.
	function TS.knife(player, char, from, d, ability, stopped)
		local range = ability.Range or 90
		local target, dist = firstInLine(char, from, d, range, 2.8)
		local wall = wallDistance(char, from, d, range)
		if target and dist > wall then
			target = nil
		end
		local reach = target and math.max(dist, 1) or wall
		broadcast("DioKnife", char, { From = from, To = from + d * reach, Hit = target, Speed = ability.Speed or 200, Stopped = stopped })
		if not target then
			return
		end
		if not stopped then
			task.wait(reach / (ability.Speed or 200))
		end
		if target.Parent and damage(player, target, ability.Damage or 4, { From = from, Hitstop = 0.02, NoKnockdown = true }) then
			stun(target, 0.35)
			knockback(target, flatten(d, target:FindFirstChild("HumanoidRootPart") or char.PrimaryPart) * 10, 0.08)
		end
	end

	-- 2: KNIVES - a fan of them down the aim
	function Handlers.KnifeVolley(player, char, root, ability, dir)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		task.wait(0.14)
		if not alive(char) then
			return
		end
		local n = ability.Knives or 8
		local spread = ability.Spread or 30
		local stopped = TS.active[char] ~= nil
		local right = root.CFrame.RightVector
		for k = 1, n do
			local a = math.rad(((k - 1) / math.max(n - 1, 1) - 0.5) * spread)
			local aim = CFrame.fromAxisAngle(UP, a):VectorToWorldSpace(d)
			local from = root.Position + UP * 1.3 + right * (((k % 2) == 0) and 0.7 or -0.7)
			task.spawn(TS.knife, player, char, from, aim, ability, stopped)
			if k % 2 == 0 then
				task.wait(0.03)
			end
		end
	end

	-- ULT 2: KNIFE RING - all round the one nearest the aim, hanging, then in
	function Handlers.KnifeRing(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		task.wait(0.15)
		if not alive(char) then
			return
		end
		local spot = groundTarget(root, pos, ability.Range or 80, char)
		local target = Kit.PR and Kit.PR.nearestTo(player, char, spot, 18)
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		local center = troot and troot.Position or (spot + UP * 3)
		local stopped = TS.active[char] ~= nil
		local n = ability.Knives or 20
		broadcast("KnifeRingSet", char, { Pos = center, Target = target, Count = n, Ring = ability.Ring or 7, Hang = ability.Hang or 0.7, Stopped = stopped, Dir = d })
		task.wait(stopped and 0.2 or (ability.Hang or 0.7))
		if not alive(char) then
			return
		end
		local hitSet = {}
		for k = 1, n do
			for _, model in queryRadius(char, center, 3.5) do
				if damage(player, model, ability.Damage or 2, { From = center + Vector3.new(math.cos(k), 0.4, math.sin(k)) * 6, NoKnockdown = true }) then
					hitSet[model] = true
				end
			end
			if k % 5 == 0 then
				task.wait()
			end
		end
		for model in hitSet do
			stun(model, 0.9)
		end
	end

	-- 3: VAMPIRE - a hand on their head and he drinks
	function Handlers.VampireDrain(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.12)
		if not alive(char) then
			return
		end
		local target = Grab.nearest(char, root, d, ability.Range or 7, 0.3)
		if not target then
			broadcast("VampireGrab", char, { Dir = d })
			return
		end
		local time, ticks = ability.Time or 1.2, ability.Ticks or 6
		local frozen = TS.of(target) -- (in stopped time: already still where they stand)
		local g = not frozen and Grab.take(target, time + 0.4) or nil
		if not g and not frozen then
			return
		end
		broadcast("VampireGrab", char, { Target = target, Dir = d, Time = time })
		local hum = char:FindFirstChildOfClass("Humanoid")
		for _ = 1, ticks do
			if not alive(char) or not alive(target) then
				break
			end
			if g then
				Grab.place(g, root.CFrame * CFrame.new(0, 0.4, -2.7) * CFrame.Angles(0, math.pi, 0))
			end
			if damage(player, target, ability.Damage or 4, { From = root.Position, NoKnockdown = true, Unblockable = true }) and hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + (ability.Damage or 4) * (ability.Heal or 1))
			end
			task.wait(time / ticks)
		end
		if g then
			Grab.release(g, d * 75 + UP * 30, 0.2)
		elseif frozen then
			knockback(target, d * 75 + UP * 30, 0.2)
		end
	end

	-- 4: SPACE RIPPER STINGY EYES - through everyone down the aim
	function Handlers.SpaceRipper(player, char, root, ability, dir)
		local d = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local head = char:FindFirstChild("Head")
		local from = (head and head.Position or root.Position + UP * 1.5) + d * 0.8
		local reach = wallDistance(char, from, d, ability.Range or 140)
		local hitSet = {}
		beamHit(char, from, d, reach, ability.Width or 2.6, function(model)
			if hitSet[model] then
				return
			end
			hitSet[model] = true
			if damage(player, model, ability.Damage or 18, { From = from, Heavy = true, Hitstop = 0.06 }) then
				knockback(model, flatten(d, root) * 45 + UP * 12, 0.15)
				stun(model, 0.7)
			end
		end)
		broadcast("SpaceRipperBeam", char, { From = from, To = from + d * reach, Dir = d })
		Destruction.Capsule(from + d * 4, from + d * reach, 1.6, "Beam", d)
	end

	-- ULT 3: ROAD ROLLER DA!
	function Handlers.RoadRoller(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local spot = groundTarget(root, pos, ability.Range or 100, char)
		local target = Kit.PR and Kit.PR.nearestTo(player, char, spot, 18)
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		if troot then
			spot = groundBelow(troot.Position, char)
		end
		local hold = ability.TimeStop or 3.4
		local stop = TS.stop(player, char, hold, 240)
		if not stop then
			return
		end
		stop.Until = math.max(stop.Until, os.clock() + hold)
		local start = root.Position
		local anchored = root.Anchored
		root.Anchored = true
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + hold + 0.8)
		broadcast("RoadRollerGo", char, { Pos = spot, From = start, Target = target, Dir = d, Hits = ability.Hits or 10 })
		-- the leap: up over the spot
		local peak = spot + UP * 38 - d * 4
		local function fly(a, b, t, arc)
			local t0 = os.clock()
			while os.clock() - t0 < t and root.Parent do
				local k = math.clamp((os.clock() - t0) / t, 0, 1)
				root.CFrame = CFrame.lookAt(a:Lerp(b, k) + UP * (arc or 0) * 4 * k * (1 - k), spot)
				task.wait()
			end
		end
		fly(start + UP * 2, peak, 0.55, 10)
		-- down on it, riding the roller
		fly(peak, spot + UP * 7.5, 0.34, 0)
		for _, model in queryRadius(char, spot + UP * 2, 9) do
			damage(player, model, 6, { From = spot + UP * 8, Heavy = true, Unblockable = true })
		end
		-- MUDA MUDA on the roller: every blow drives it (and them) down
		for _ = 1, ability.Hits or 10 do
			if not alive(char) then
				break
			end
			for _, model in queryRadius(char, spot + UP * 2, 8) do
				damage(player, model, 2, { From = spot + UP * 8, Unblockable = true, NoKnockdown = true })
			end
			task.wait(0.12)
		end
		-- he's off it; the roller waits for time to move
		local off = spot - d * 10 + UP * 3
		root.CFrame = CFrame.lookAt(off, Vector3.new(spot.X, off.Y, spot.Z))
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
		pcall(function()
			root:SetNetworkOwnershipAuto()
		end)
		while not stop.Done do
			task.wait(0.05)
		end
		task.wait(0.15)
		broadcast("RoadRollerBoom", char, { Pos = spot })
		for _, model in queryRadius(char, spot + UP * 3, ability.Radius or 16) do
			if damage(player, model, ability.Damage or 50, { From = spot, Heavy = true, Hitstop = 0.12 }) then
				knockback(model, awayFrom(spot, model, d) * 110 + UP * 80, 0.3)
				ragdoll(model, 2.5)
			end
		end
		Destruction.Sphere(spot, 14, "BigExplosion")
	end
end

---------------------------------------------------------------------------
-- (round 60) CREATI (Momo Yaoyorozu): Creation
---------------------------------------------------------------------------
-- What she makes comes out of her skin. R (CREATE) puts the next weapon in
-- her hand - the player's QuirkPick, like Deku's R: the 4th slot is that
-- weapon's move - built onto her right hand in her gear ("CreatedWeapon"),
-- and her M1s reach and hit with it (YM.m1). Her shields: the one she's
-- holding up ("Shielding" on her) or a wall she planted (YM.walls: real,
-- solid parts in workspace.Creations) takes any hit that comes at whoever's
-- behind it (Reactions.shielded, in damage()).
do
	local YM = { walls = {} } -- [slab] = { HP, Owner }
	Kit.YM = YM

	function YM.spec()
		return Config.Quirks.Creation or {}
	end
	-- the weapon in her hand: "Staff" | "Sword" | "Spear"
	function YM.weapon(player)
		local ex = Config.PickedExtra(YM.spec(), player and player:GetAttribute("QuirkPick"))
		return (ex and ex.Weapon) or "Staff"
	end
	-- the M1s: studs more reach, x damage (anyone else: 0, 1)
	function YM.m1(player)
		if not player or player:GetAttribute("Quirk") ~= "Creation" then
			return 0, 1
		end
		local w = (YM.spec().Weapons or {})[YM.weapon(player)] or {}
		return w.Reach or 0, w.Damage or 1
	end

	-- (round 62) the weapons, part by part: { kind, size x, y, z, at x, y, z,
	-- turned x, y, z (degrees), colour, material, transparency } in the right
	-- arm's own space at the fist, the weapon's length along the arm's
	-- forward axis (-Z, across the fist). Cylinders are sized (diameter,
	-- diameter, length) along Z. The previews are drawn from the same table.
	YM.PARTS = {
		Staff = {
			{ "cyl", 0.3, 0.3, 6.6, 0, 0, -1.1, 0, 0, 0, "LACQUER", "Wood", 0 },
			{ "cyl", 0.36, 0.36, 0.46, 0, 0, 1.97, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.36, 0.36, 0.46, 0, 0, -4.17, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "ball", 0.34, 0.34, 0.34, 0, 0, 2.22, 0, 0, 0, "GOLD_DARK", "Metal", 0 },
			{ "ball", 0.34, 0.34, 0.34, 0, 0, -4.42, 0, 0, 0, "GOLD_DARK", "Metal", 0 },
			{ "cyl", 0.34, 0.34, 0.08, 0, 0, 1.62, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.34, 0.34, 0.08, 0, 0, -3.82, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.34, 0.34, 0.12, 0, 0, -1.1, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.34, 0.34, 0.7, 0, 0, 0, 0, 0, 0, "RED", "Fabric", 0 },
			{ "cyl", 0.34, 0.34, 0.7, 0, 0, -2.2, 0, 0, 0, "RED", "Fabric", 0 },
		},
		Sword = {
			{ "cyl", 0.22, 0.22, 0.9, 0, 0, 0.12, 0, 0, 0, "RED", "Fabric", 0 },
			{ "cyl", 0.26, 0.26, 0.06, 0, 0, -0.22, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.26, 0.26, 0.06, 0, 0, 0.12, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.26, 0.26, 0.06, 0, 0, 0.46, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "ball", 0.36, 0.36, 0.36, 0, 0, 0.66, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "ball", 0.16, 0.16, 0.16, 0, 0, 0.84, 0, 0, 0, "GEM", "Glass", 0 },
			{ "block", 1.4, 0.14, 0.2, 0, 0, -0.42, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "block", 0.36, 0.26, 0.32, 0, 0, -0.42, 0, 0, 0, "GOLD_DARK", "Metal", 0 },
			{ "ball", 0.22, 0.22, 0.22, 0.72, 0, -0.42, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "ball", 0.22, 0.22, 0.22, -0.72, 0, -0.42, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "block", 0.09, 0.36, 3.3, 0, 0, -2.2, 0, 0, 0, "STEEL", "Metal", 0 },
			{ "block", 0.11, 0.09, 2.6, 0, 0, -1.95, 0, 0, 0, "STEEL_DARK", "Metal", 0 },
			{ "block", 0.1, 0.035, 3.3, 0, 0.17, -2.2, 0, 0, 0, "EDGE", "Neon", 0.35 },
			{ "block", 0.1, 0.035, 3.3, 0, -0.17, -2.2, 0, 0, 0, "EDGE", "Neon", 0.35 },
			{ "wedge", 0.09, 0.18, 0.7, 0, 0.09, -4.2, 0, 0, 0, "STEEL", "Metal", 0 },
			{ "wedge", 0.09, 0.18, 0.7, 0, -0.09, -4.2, 0, 0, 180, "STEEL", "Metal", 0 },
		},
		Spear = {
			{ "cyl", 0.24, 0.24, 6.9, 0, 0, -1.55, 0, 0, 0, "LACQUER", "Wood", 0 },
			{ "cyl", 0.28, 0.28, 1.1, 0, 0, 0.05, 0, 0, 0, "WRAP", "Fabric", 0 },
			{ "cyl", 0.3, 0.3, 0.08, 0, 0, 0.7, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.3, 0.3, 0.08, 0, 0, -0.6, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.3, 0.3, 0.08, 0, 0, -3.6, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.3, 0.3, 0.36, 0, 0, 1.95, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "ball", 0.3, 0.3, 0.3, 0, 0, 2.15, 0, 0, 0, "GOLD_DARK", "Metal", 0 },
			{ "cyl", 0.34, 0.34, 0.5, 0, 0, -5.05, 0, 0, 0, "GOLD", "Metal", 0 },
			{ "cyl", 0.26, 0.26, 0.24, 0, 0, -5.4, 0, 0, 0, "GOLD_DARK", "Metal", 0 },
			{ "block", 0.07, 0.07, 1, 0.1, 0.12, -4.45, -18, 8, 0, "TASSEL", "Fabric", 0 },
			{ "block", 0.07, 0.07, 1, -0.1, 0.12, -4.45, -18, -8, 0, "TASSEL", "Fabric", 0 },
			{ "block", 0.07, 0.07, 1.1, 0, 0.18, -4.4, -24, 0, 0, "TASSEL", "Fabric", 0 },
			{ "block", 0.07, 0.07, 0.9, 0.06, -0.06, -4.5, -12, 14, 0, "TASSEL", "Fabric", 0 },
			{ "block", 0.08, 0.46, 0.9, 0, 0, -6.05, 0, 0, 0, "STEEL", "Metal", 0 },
			{ "wedge", 0.08, 0.23, 0.45, 0, 0.115, -5.38, 0, 180, 0, "STEEL", "Metal", 0 },
			{ "wedge", 0.08, 0.23, 0.45, 0, -0.115, -5.38, 0, 180, 180, "STEEL", "Metal", 0 },
			{ "wedge", 0.08, 0.23, 0.9, 0, 0.115, -6.95, 0, 0, 0, "STEEL", "Metal", 0 },
			{ "wedge", 0.08, 0.23, 0.9, 0, -0.115, -6.95, 0, 0, 180, "STEEL", "Metal", 0 },
			{ "block", 0.12, 0.06, 2.1, 0, 0, -6.2, 0, 0, 0, "STEEL_DARK", "Metal", 0 },
			{ "block", 0.09, 0.03, 0.9, 0, 0.22, -6.05, 0, 0, 0, "EDGE", "Neon", 0.35 },
			{ "block", 0.09, 0.03, 0.9, 0, -0.22, -6.05, 0, 0, 0, "EDGE", "Neon", 0.35 },
		},
	}
	YM.COLORS = {
		STEEL = Color3.fromRGB(214, 220, 230), STEEL_DARK = Color3.fromRGB(120, 128, 144), EDGE = Color3.fromRGB(246, 250, 255),
		GOLD = Color3.fromRGB(255, 196, 70), GOLD_DARK = Color3.fromRGB(196, 134, 40), RED = Color3.fromRGB(196, 32, 52),
		LACQUER = Color3.fromRGB(70, 20, 30), WRAP = Color3.fromRGB(30, 28, 34), GEM = Color3.fromRGB(255, 70, 110),
		TASSEL = Color3.fromRGB(220, 40, 60),
	}

	-- the weapon, in her right hand (everyone sees it; R swaps it). Along the
	-- arm's forward axis from the fist, so every swing of the arm swings it.
	function YM.arm(char, weapon, gear)
		gear = gear or char:FindFirstChild("QuirkGear")
		if not gear then
			return nil
		end
		local old = gear:FindFirstChild("CreatedWeapon")
		if old then
			old:Destroy()
		end
		local hand = findLimb(char, "RightHand", "Right Arm")
		if not hand then
			return nil
		end
		local parts = YM.PARTS[weapon] or YM.PARTS.Staff
		local m = Instance.new("Model")
		m.Name = "CreatedWeapon"
		m:SetAttribute("Weapon", YM.PARTS[weapon] and weapon or "Staff")
		m.Parent = gear
		local y = hand.Name == "Right Arm" and -hand.Size.Y / 2 + 0.15 or -0.1
		local ALONG = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder's length is its X: turned onto Z)
		for _, p in parts do
			local kind = p[1]
			local color = YM.COLORS[p[11]] or YM.COLORS.STEEL
			local material = Enum.Material[p[12]] or Enum.Material.Metal
			local part
			if kind == "wedge" then
				part = Instance.new("WedgePart")
				part.Size = Vector3.new(p[2], p[3], p[4])
				part.Color = color
				part.Material = material
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.CastShadow = false
				part.Parent = m
			elseif kind == "cyl" then
				part = gearPart(m, Vector3.new(p[4], p[2], p[3]), color, material, Enum.PartType.Cylinder)
			else
				part = gearPart(m, Vector3.new(p[2], p[3], p[4]), color, material, kind == "ball" and Enum.PartType.Ball or nil)
			end
			part.Name = weapon
			part.Transparency = p[13] or 0
			local cf = CFrame.new(p[5], y + p[6], p[7]) * CFrame.Angles(math.rad(p[8]), math.rad(p[9]), math.rad(p[10]))
			weld(hand, part, kind == "cyl" and cf * ALONG or cf)
		end
		return m
	end

	-- her look (the anime): a high black ponytail, spiky, and the gold utility
	-- belt with its pouches (the costume's cosmetics; the weapon isn't one)
	function YM.look(gear, char)
		local head = char:FindFirstChild("Head")
		if head then
			local v = visibleHead(head)
			local k = v.X / 1.2
			local HAIR = Color3.fromRGB(22, 20, 26)
			-- the knot at the top of the back of her head, the tie round it, and
			-- the tail: thick spikes sweeping up, back and down behind her
			local knotAt = Vector3.new(0, v.Y * 0.36, v.Z * 0.46)
			local knot = ellipsoid(gear, Vector3.new(0.62, 0.62, 0.62) * k, HAIR, Enum.Material.SmoothPlastic)
			knot.Name = "Ponytail"
			weld(head, knot, CFrame.new(knotAt))
			local tie = gearPart(gear, Vector3.new(0.2, 0.44, 0.44) * k, Color3.fromRGB(196, 32, 52), Enum.Material.Fabric, Enum.PartType.Cylinder)
			tie.Name = "Ponytail"
			weld(head, tie, CFrame.new(knotAt + Vector3.new(0, 0.1, 0.12) * k) * CFrame.Angles(math.rad(45), 0, math.rad(90))) -- (round the tail, up and back)
			-- { length, width, back (degrees from straight up), sideways }
			for _, t in {
				{ 1.4, 0.58, 30, 0 }, { 1.7, 0.52, 58, 14 }, { 1.7, 0.52, 58, -14 }, { 1.6, 0.46, 84, 22 },
				{ 1.6, 0.46, 84, -22 }, { 1.5, 0.44, 106, 8 }, { 1.3, 0.4, 128, -6 },
			} do
				local spike = ellipsoid(gear, Vector3.new(t[2], t[1], t[2] * 0.85) * k, HAIR, Enum.Material.SmoothPlastic)
				spike.Name = "Ponytail"
				weld(head, spike, CFrame.new(knotAt + Vector3.new(0, 0, 0.18) * k) * CFrame.Angles(math.rad(t[3]), 0, math.rad(t[4])) * CFrame.new(0, t[1] * 0.46 * k, 0))
			end
		end
		local torso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
		if torso then
			local s = torso.Size
			local r15 = torso.Name == "LowerTorso"
			local y = r15 and 0 or -s.Y / 2 + 0.2
			local GOLD = Color3.fromRGB(255, 196, 70)
			local belt = gearPart(gear, Vector3.new(s.X + 0.08, 0.3, s.Z + 0.08), GOLD, Enum.Material.Metal)
			belt.Name = "Belt"
			weld(torso, belt, CFrame.new(0, y, 0))
			local buckle = gearPart(gear, Vector3.new(0.42, 0.34, 0.08), Color3.fromRGB(196, 32, 52), Enum.Material.SmoothPlastic)
			buckle.Name = "Belt"
			weld(torso, buckle, CFrame.new(0, y, -(s.Z / 2 + 0.07)))
			for _, x in { -0.72, -0.38, 0.38, 0.72 } do
				local pouch = gearPart(gear, Vector3.new(0.3, 0.34, 0.22), Color3.fromRGB(226, 168, 52), Enum.Material.SmoothPlastic)
				pouch.Name = "Belt"
				weld(torso, pouch, CFrame.new(x * s.X / 2, y - 0.05, s.Z / 2 + 0.1)) -- (round the back)
			end
		end
	end

	-- R: CREATE - the next weapon into her hand
	function Handlers.CreateWeapon(player, char)
		local n = #(YM.spec().Extras or {})
		if n > 0 then
			player:SetAttribute("QuirkPick", ((player:GetAttribute("QuirkPick") or 1) % n) + 1)
		end
		YM.arm(char, YM.weapon(player))
	end

	-- 1: MATRYOSHKA FLASH - the dolls fly on the fan, each to the first body
	-- or wall in its way, and each one's flashbang goes off there
	function Handlers.MatryoshkaFlash(player, char, root, ability, dir)
		local d = Config.AimedDirection(dir, flatten(dir, root), { Up = 30, Down = 30 })
		task.wait(0.18) -- (the dolls come out of her palm, and she throws)
		if not alive(char) then
			return
		end
		local origin = root.Position + UP * 1.2
		local n, range = ability.Dolls or 3, ability.Range or 46
		local caught = {}
		local move = Moves.current()
		for i = 1, n do
			local yaw = math.rad(((i - 1) - (n - 1) / 2) * (ability.Spread or 13))
			local di = CFrame.fromAxisAngle(UP, yaw):VectorToWorldSpace(d)
			local target, along = firstInLine(char, origin, di, range, 3)
			local dist = math.min(target and math.max(along or 1, 1) or range, wallDistance(char, origin, di, range))
			local at = origin + di * math.max(dist - 0.8, 1)
			task.delay(dist / (ability.Speed or 95), function()
				Moves.join(move)
				broadcast("MatryoshkaPop", char, { Index = i, Pos = at })
				for _, model in queryRadius(char, at, ability.Radius or 7) do
					if not caught[model] then
						caught[model] = true
						if damage(player, model, ability.Damage, { From = at }) then
							stun(model, ability.Stun or 1.2)
							local plr = Players:GetPlayerFromCharacter(model)
							if plr then
								PlayVFX:FireClient(plr, "Blind", nil, { Duration = ability.Blind or 1.8, From = at })
							end
							model:SetAttribute("BlindedUntil", workspace:GetServerTimeNow() + (ability.Blind or 1.8))
						end
					end
				end
			end)
		end
	end

	-- is the line a -> b through this wall? (a slab test in its own space)
	function YM.crosses(part, a, b)
		local cf, half = part.CFrame, part.Size / 2
		local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
		local v = lb - la
		local t0, t1 = 0, 1
		for _, axis in { "X", "Y", "Z" } do
			local p, dv, h = la[axis], v[axis], half[axis]
			if math.abs(dv) < 1e-6 then
				if math.abs(p) > h then
					return false
				end
			else
				local ta, tb = (-h - p) / dv, (h - p) / dv
				if ta > tb then
					ta, tb = tb, ta
				end
				t0, t1 = math.max(t0, ta), math.min(t1, tb)
				if t0 > t1 then
					return false
				end
			end
		end
		return true
	end

	function YM.breakWall(slab)
		local w = YM.walls[slab]
		YM.walls[slab] = nil
		local model = slab.Parent
		if w and model then
			broadcast("CastleWallBreak", nil, { Pos = slab.Position, CF = slab.CFrame, Size = slab.Size, Broken = w.HP <= 0 })
			model:Destroy()
		end
	end

	-- a hit caught on the wall: it takes the damage instead
	function YM.chip(slab, w, amount, from)
		w.HP -= amount
		broadcast("CastleWallHit", nil, { Pos = slab.CFrame:PointToWorldSpace(Vector3.new(math.clamp(slab.CFrame:PointToObjectSpace(from).X, -slab.Size.X / 2, slab.Size.X / 2), 0, 0)), CF = slab.CFrame })
		if w.HP <= 0 then
			YM.breakWall(slab)
		end
	end

	-- (in damage()) her shield, or a wall she planted, took the hit
	function Reactions.shielded(attacker, model, amount, opts)
		if opts and (opts.Tick or opts.Unblockable) then
			return false -- (a burn, poison - already on them)
		end
		local mr = model:FindFirstChild("HumanoidRootPart")
		local ac = attacker and attacker.Character
		if not mr or ac == model then
			return false
		end
		local ar = ac and ac:FindFirstChild("HumanoidRootPart")
		local from = (opts and typeof(opts.From) == "Vector3" and opts.From) or (ar and ar.Position)
		if not from then
			return false
		end
		if model:GetAttribute("Shielding") then
			local v = Vector3.new(from.X - mr.Position.X, 0, from.Z - mr.Position.Z)
			local look = mr.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.1 and (v.Magnitude < 1 or v.Unit:Dot(flat.Unit) > 0.2) then
				broadcast("ShieldBlock", model, { Pos = mr.Position + flat.Unit * 2 + UP * 0.8 })
				return true
			end
		end
		for slab, w in YM.walls do
			if not slab.Parent then
				YM.walls[slab] = nil
			elseif YM.crosses(slab, from, mr.Position) then
				YM.chip(slab, w, amount, from)
				return true
			end
		end
		return false
	end

	-- TAP: the shield planted where she's aiming - a real wall
	function YM.plant(player, char, root, ability, d)
		local folder = workspace:FindFirstChild("Creations")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Creations"
			folder.Parent = workspace
		end
		local w, h = ability.Width or 12, ability.Height or 9
		local ground = groundBelow(root.Position + d * (ability.Ahead or 5), char)
		local center = ground + UP * (h / 2 - 0.2)
		local cf = CFrame.lookAt(center, center + d)
		local model = Instance.new("Model")
		model.Name = "CastleWall"
		model:SetAttribute("Owner", player.UserId)
		local function part(size, offset, color, material)
			local p = Instance.new("Part")
			p.Size = size
			p.CFrame = cf * offset
			p.Color = color
			p.Material = material or Enum.Material.Metal
			p.Anchored = true
			p.CanTouch = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = model
			return p
		end
		local slab = part(Vector3.new(w, h, 1.2), CFrame.identity, Color3.fromRGB(196, 200, 210))
		slab.Name = "Slab"
		-- (the gold rim and the crest on the front: only the slab stops anything)
		local GOLD = Color3.fromRGB(255, 196, 70)
		for _, rim in {
			{ Vector3.new(w + 0.3, 0.45, 1.4), CFrame.new(0, h / 2, 0) }, { Vector3.new(w + 0.3, 0.45, 1.4), CFrame.new(0, -h / 2 + 0.2, 0) },
			{ Vector3.new(0.45, h, 1.4), CFrame.new(w / 2, 0, 0) }, { Vector3.new(0.45, h, 1.4), CFrame.new(-w / 2, 0, 0) },
			{ Vector3.new(0.5, h * 0.7, 0.2), CFrame.new(0, 0, -0.66) }, { Vector3.new(w * 0.55, 0.5, 0.2), CFrame.new(0, h * 0.12, -0.66) },
		} do
			local p = part(rim[1], rim[2], GOLD)
			p.CanCollide = false
			p.CanQuery = false
		end
		model.PrimaryPart = slab
		model.Parent = folder
		YM.walls[slab] = { HP = ability.WallHP or 70, Owner = player }
		broadcast("CastleWallPlant", char, { CF = cf, Size = slab.Size })
		task.delay(ability.WallTime or 7, function()
			if YM.walls[slab] then
				YM.breakWall(slab)
			end
		end)
		return slab
	end

	-- HOLD, then let go: she drives the shield forward
	function YM.bash(player, char, root, ability, d)
		broadcast("ShieldBash", char, { Dir = d, Dist = ability.Bash or 14, Time = ability.BashTime or 0.22 })
		sweep(player, char, root, (ability.BashTime or 0.22) + 0.08, (ability.BashWidth or 6) / 2 + 1, 3, d, function(model)
			if damage(player, model, ability.Damage, { From = root.Position, Heavy = true }) then
				knockback(model, d * 95 + UP * 30, 0.2)
				stun(model, 0.8)
			end
		end)
	end

	-- 2: UNFALLING CASTLE WALL - the shield's up from the moment she presses;
	-- a tap plants it, a hold carries it and the release bashes
	function Handlers.CastleWall(player, char, root, ability, dir)
		char:SetAttribute("Shielding", true)
		local held, hold = HoldMoves.wait(player, char, ability)
		char:SetAttribute("Shielding", nil)
		if not held or not alive(char) then
			return
		end
		local d = flatten((hold and hold.Dir) or dir, root)
		if HoldMoves.level(ability, held) <= 1 then
			YM.plant(player, char, root, ability, d)
		else
			YM.bash(player, char, root, ability, d)
		end
	end

	-- 3: BULLET RAIN - the cannon beside her, the shells, the bombs; every
	-- screen draws them from the one broadcast (BulletRainShells)
	function Handlers.BulletRain(player, char, root, ability, dir, pos, cast)
		local d = flatten(dir, root)
		local right = d:Cross(UP)
		local rng = Random.new(cast.Seed or 1)
		local target = groundTarget(root, pos, ability.Range or 85, char)
		local cannon = groundBelow(root.Position + right * 3.2 - d * 0.4, char)
		local muzzle = cannon + UP * 2.4 + d * 1.6
		local spread = ability.Spread or 6
		local shells = {}
		for i = 1, ability.Shells or 3 do
			local land = groundBelow(target + right * rng:NextNumber(-1, 1) * spread + d * rng:NextNumber(-0.6, 0.6) * spread + UP * 4, char)
			local bombs = {}
			for b = 1, ability.Bombs or 4 do
				local a = (b / (ability.Bombs or 4) + rng:NextNumber(-0.1, 0.1)) * math.pi * 2
				bombs[b] = groundBelow(land + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3.5, 7) + UP * 4, char)
			end
			local at = 0.5 + (i - 1) * (ability.Interval or 0.45)
			shells[i] = { Land = land, Bombs = bombs, At = at, Flight = 0.55 + (land - muzzle).Magnitude / 230 }
		end
		broadcast("BulletRainShells", char, { Cannon = cannon, Dir = d, Muzzle = muzzle, Shells = shells })
		local move = Moves.current()
		local t0 = os.clock()
		for _, sh in shells do
			task.delay(sh.At + sh.Flight - (os.clock() - t0), function()
				Moves.join(move)
				for _, model in queryRadius(char, sh.Land + UP * 1.5, ability.Radius or 7) do
					if damage(player, model, ability.Damage, { From = sh.Land }) then
						knockback(model, awayFrom(sh.Land, model, d) * 35 + UP * 18, 0.12)
						stun(model, 0.5)
					end
				end
				task.wait(0.35)
				local bombed = {}
				for _, b in sh.Bombs do
					for _, model in queryRadius(char, b + UP * 1.2, ability.BombRadius or 4.5) do
						if not bombed[model] then
							bombed[model] = true
							if damage(player, model, ability.BombDamage or 2, { From = b }) then
								stun(model, 0.35)
							end
						end
					end
				end
			end)
		end
	end

	-- 4 (staff): STRIKE AND STOP - the staff whirled round her; everyone it
	-- catches is stopped dead: their move cut off, stunned
	function Handlers.StrikeAndStop(player, char, root, ability)
		task.wait(0.14)
		if not alive(char) then
			return
		end
		for _, model in Rewind.QueryRadius(player, char, root.Position, ability.Radius or 9) do
			if damage(player, model, ability.Damage, { From = root.Position, Heavy = true }) then
				Moves.cut(model)
				stun(model, ability.Stun or 1.2)
				knockback(model, awayFrom(root.Position, model, root.CFrame.LookVector) * 28 + UP * 8, 0.12)
				broadcast("StrikeStop", model, {})
			end
		end
	end

	-- 4 (sword): IAI RUSH - her own screen dashes her; this cuts whoever
	-- she passes
	function Handlers.IaiRush(player, char, root, ability, dir)
		local d = flatten(dir, root)
		task.wait(0.05)
		sweep(player, char, root, (ability.DashTime or 0.24) + 0.12, (ability.Width or 5) / 2 + 1.5, 1.5, d, function(model)
			if damage(player, model, ability.Damage, { From = root.Position, Heavy = true }) then
				knockback(model, d * 26 + d:Cross(UP) * 18 + UP * 22, 0.15)
				stun(model, 0.7)
			end
		end)
	end

	-- 4 (spear): PIERCING THRUST - the first one on the point is run back
	function Handlers.PiercingThrust(player, char, root, ability, dir)
		local d = Config.AimedDirection(dir, flatten(dir, root), { Up = 20, Down = 20 })
		task.wait(0.15)
		if not alive(char) then
			return
		end
		local origin = root.Position + UP * 0.5
		local target = firstInLine(char, origin, d, ability.Range or 15, ability.Width or 3.5)
		if target and damage(player, target, ability.Damage, { From = origin, Heavy = true }) then
			local flat = flatten(d, root)
			knockback(target, flat * ((ability.Push or 14) / 0.2) + UP * 14, 0.2)
			broadcast("SpearRun", char, { Target = target, Dir = flat })
		end
	end

	-- ULT 1: GRAND CANNON
	function Handlers.GrandCannon(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = groundTarget(root, pos, ability.Range or 140, char)
		local base = groundBelow(root.Position + d:Cross(UP) * 4.5, char)
		task.wait(0.55) -- (it rises out of the street)
		if not alive(char) then
			return
		end
		local muzzle = base + UP * 4.4 + d * 4.5
		local flight = 0.25 + (target - muzzle).Magnitude / (ability.Speed or 190)
		broadcast("GrandCannonFire", char, { Base = base, Muzzle = muzzle, Target = target, Flight = flight, Dir = d })
		task.wait(flight)
		for _, model in queryRadius(char, target + UP * 2, ability.Radius or 15) do
			if damage(player, model, ability.Damage, { From = target, Heavy = true }) then
				knockback(model, awayFrom(target, model, d) * 110 + UP * 60, 0.25)
			end
		end
		Destruction.Sphere(target, 10, "Explosion", d)
	end

	-- ULT 2: CAPTURE NET - the catapult, the net's flight, and everyone under
	-- it pinned
	function Handlers.CaptureNet(player, char, root, ability, dir, pos)
		local d = flatten(dir, root)
		local target = groundTarget(root, pos, ability.Range or 70, char)
		task.wait(0.3) -- (the catapult)
		if not alive(char) then
			return
		end
		local from = root.Position - d * 1.5 + UP * 4
		broadcast("CaptureNetFly", char, { From = from, Pos = target, Flight = ability.Flight or 0.7, Radius = ability.Radius or 12, Pin = ability.Pin or 2.8 })
		task.wait(ability.Flight or 0.7)
		for _, model in queryRadius(char, target + UP * 2, ability.Radius or 12) do
			if damage(player, model, ability.Damage, { From = target }) then
				stun(model, ability.Pin or 2.8, 0)
			end
		end
	end

	-- ULT 3: DISCHARGE CANNON - the railgun on her shoulder: a charge, then one
	-- slug down the aim, through everyone in the lane and through the city
	function Handlers.DischargeCannon(player, char, root, ability, dir)
		local d = Config.AimedDirection(dir, flatten(dir, root), { Up = 30, Down = 25 })
		task.wait(ability.Charge or 0.9)
		if not alive(char) then
			return
		end
		local origin = root.Position + UP * 2
		local length = ability.Range or 220
		broadcast("DischargeCannonFire", char, { Origin = origin, Dir = d, Length = length, Width = ability.Width or 7 })
		beamHit(char, origin, d, length, ability.Width or 7, function(model)
			if damage(player, model, ability.Damage, { From = origin, Heavy = true }) then
				knockback(model, d * 140 + UP * 30, 0.25)
			end
		end)
		Destruction.Capsule(origin + d * 4, origin + d * (length - 10), 3.5, "Beam", d)
	end

	-- ULT 4: LUCKY BAG - Items random Hero Shop items into her bag (no room:
	-- Heal instead)
	function Handlers.LuckyBag(player, char, root, ability)
		task.wait(0.3)
		if not alive(char) then
			return
		end
		local got = {}
		for _ = 1, ability.Items or 2 do
			local id = Store.LuckyItem and Store.LuckyItem(player)
			if id then
				table.insert(got, id)
			else
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = math.min(hum.MaxHealth, hum.Health + (ability.Heal or 20))
				end
				table.insert(got, "Heal")
			end
		end
		broadcast("LuckyBagDrop", char, { Pos = groundBelow(root.Position + root.CFrame.LookVector * 2.5, char), Items = got })
	end
end

---------------------------------------------------------------------------
-- DEKU'S BROKEN ARMS (Config.BrokenArms): 100% breaks the arm, and it
-- stops working - the shoulder joint lets go, and the arm hangs off him on
-- a ball socket (limited to a natural swing, a little friction), light, so
-- it flops about as he runs, jumps and dashes and swings back to hanging.
-- It comes back when the arm heals (BrokenArmR / BrokenArmL runs out, or a
-- new quirk / body clears it). The ragdoll leaves it alone, and getting up
-- doesn't re-attach it.
---------------------------------------------------------------------------
do
	local LIMP = { watched = setmetatable({}, { __mode = "k" }), tokens = setmetatable({}, { __mode = "k" }), props = setmetatable({}, { __mode = "k" }) }
	Kit.LIMP = LIMP
	-- side = { motor names (R6, R15), sign }
	local SIDES = { R = { "Right Shoulder", "RightShoulder", 1 }, L = { "Left Shoulder", "LeftShoulder", -1 } }

	local function motorOf(char, side)
		local spec = SIDES[side]
		for _, m in char:GetDescendants() do
			if m:IsA("Motor6D") and (m.Name == spec[1] or m.Name == spec[2]) and m.Part0 and m.Part1 then
				return m
			end
		end
		return nil
	end

	-- on: the joint lets go and the arm hangs on the socket; off: back on
	function LIMP.set(char, side, on)
		local motor = motorOf(char, side)
		if not motor then
			return false
		end
		local arm, torso = motor.Part1, motor.Part0
		local tag = "LimpArm" .. side
		local socket = arm:FindFirstChild(tag)
		if on then
			if socket or (Config.BrokenArms and Config.BrokenArms.Limp == false) then
				return false
			end
			-- the pivot where the joint was; the attachments' X axes point down
			-- the hanging arm, so the cone opens round "hanging"
			local down = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, -1))
			local a0 = Instance.new("Attachment")
			a0.Name = tag
			a0.CFrame = CFrame.new(motor.C0.Position) * down
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Name = tag
			a1.CFrame = CFrame.new(motor.C1.Position) * down
			a1.Parent = arm
			local ball = Instance.new("BallSocketConstraint")
			ball.Name = tag
			ball.Attachment0 = a0
			ball.Attachment1 = a1
			ball.LimitsEnabled = true
			ball.UpperAngle = 95
			ball.TwistLimitsEnabled = true
			ball.TwistLowerAngle = -45
			ball.TwistUpperAngle = 45
			ball.Restitution = 0.15
			ball.MaxFrictionTorque = 4
			ball.Parent = arm
			local nc = Instance.new("NoCollisionConstraint")
			nc.Name = tag
			nc.Part0 = torso
			nc.Part1 = arm
			nc.Parent = arm
			-- light, so a flopping arm doesn't haul him about
			local props = LIMP.props[arm] or {}
			LIMP.props[arm] = props
			props.old = arm.CustomPhysicalProperties
			pcall(function()
				arm.CustomPhysicalProperties = PhysicalProperties.new(0.15, 0.3, 0.1)
			end)
			motor:SetAttribute("Limp", true)
			motor.Enabled = false
			-- (the arm is its own piece now: whoever runs his body runs it)
			local owner = Players:GetPlayerFromCharacter(char)
			if owner then
				pcall(function()
					arm:SetNetworkOwner(owner)
				end)
			end
			return true
		end
		if not socket and not motor:GetAttribute("Limp") then
			return false
		end
		for _, d in { torso, arm } do
			for _, c in d:GetChildren() do
				if c.Name == tag then
					c:Destroy()
				end
			end
		end
		local props = LIMP.props[arm]
		if props then
			pcall(function()
				arm.CustomPhysicalProperties = props.old
			end)
			LIMP.props[arm] = nil
		end
		motor:SetAttribute("Limp", nil)
		-- (down on the street: the ragdoll puts it back when he gets up)
		if not char:GetAttribute("Ragdolled") then
			motor.Enabled = true
		end
		return true
	end

	-- follow BrokenArmR / BrokenArmL on a body: limp while it's ahead of the
	-- clock, back when it runs out (or is cleared)
	function LIMP.watch(char)
		if LIMP.watched[char] then
			return
		end
		LIMP.watched[char] = true
		for side in SIDES do
			local key = "BrokenArm" .. side
			local function sync()
				local token = (LIMP.tokens[char] and LIMP.tokens[char][side] or 0) + 1
				LIMP.tokens[char] = LIMP.tokens[char] or {}
				LIMP.tokens[char][side] = token
				local untilT = tonumber(char:GetAttribute(key)) or 0
				local left = untilT - workspace:GetServerTimeNow()
				if left > 0 then
					LIMP.set(char, side, true)
					task.delay(left + 0.05, function()
						if char.Parent and LIMP.tokens[char] and LIMP.tokens[char][side] == token then
							local l = (tonumber(char:GetAttribute(key)) or 0) - workspace:GetServerTimeNow()
							if l <= 0 then
								LIMP.set(char, side, false)
							end
						end
					end)
				else
					LIMP.set(char, side, false)
				end
			end
			char:GetAttributeChangedSignal(key):Connect(sync)
		end
	end
end

---------------------------------------------------------------------------
-- Dev characters (DevOnly quirks). Testers always have them and can hand
-- access to anyone in this server from the test menu's DEV ACCESS panel.
-- A grant lasts for this server (it survives leaving and rejoining it)
-- until it's revoked.
---------------------------------------------------------------------------

local devGrants = {} -- [userId] = display name of whoever granted it

local function canUseDev(player)
	return canTest(player) or devGrants[player.UserId] ~= nil
end

local function notice(player, text, color)
	PlayVFX:FireClient(player, "Notice", nil, { Text = text, Color = color })
end

local function refreshDevAccess(player)
	player:SetAttribute("DevAccess", canUseDev(player))
	-- lost access while playing a dev character: back to a regular quirk
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	if quirk and quirk.DevOnly and not canUseDev(player) then
		for _, name in Config.QuirkOrder do
			if not Config.Quirks[name].DevOnly then
				applyQuirk(player, name)
				break
			end
		end
	end
end

local function setGrant(granter, target, on)
	if not target or target == granter or not target:IsA("Player") or canTest(target) then
		return false -- testers already have access and can't be revoked
	end
	if on then
		if devGrants[target.UserId] then
			return false
		end
		devGrants[target.UserId] = granter.DisplayName
		refreshDevAccess(target)
		notice(target, granter.DisplayName .. " gave you access to DEV characters (press M)", Color3.fromRGB(255, 212, 64))
	else
		if not devGrants[target.UserId] then
			return false
		end
		devGrants[target.UserId] = nil
		refreshDevAccess(target)
		notice(target, "Your DEV character access was removed", Color3.fromRGB(255, 120, 100))
	end
	return true
end

---------------------------------------------------------------------------
-- Bucks + the shop. Bucks and your bag of items live in player attributes
-- ("Bucks", "Item_<Id>") so the HUD can read them, mirrored in leaderstats,
-- and saved to a DataStore. Items are used through the Shop remote:
--   ("Buy", id)  ("Use", id, aimDir, aimPos)  ("Fire", aimDir, aimPos)
---------------------------------------------------------------------------

-- (in a function of its own: this script is close to Luau's 200-local limit)
local function setupStore()
	local ECON = Config.Economy or {}
	local ITEMS = Config.Items or {}
	local CURRENCY = ECON.Currency or "Bucks"
	local MAX_STACK = ECON.MaxStack or 9
	local saveStore = nil
	if ECON.SaveData ~= false then
		pcall(function()
			saveStore = game:GetService("DataStoreService"):GetDataStore(ECON.DataStore or "QuirkBattlegrounds_Bucks_v1")
		end)
	end
	local loaded = {} -- [player] = true once their save was read (never save over data we couldn't read)
	local dirty = {} -- [player] = true when there's something new to save
	local lastUse = {} -- [player] = os.clock() of the last item used
	local lastShot = {} -- [player] = os.clock() of the last sniper shot
	local scoped = {} -- [player] = true while looking down the sniper scope
	local grapes = {} -- [player] = the grape balls they have out
	local outfitTokens = setmetatable({}, { __mode = "k" })
	local ownClothes = setmetatable({}, { __mode = "k" }) -- [character] = { Shirt, Pants } before the costume

	local function itemCount(player, id)
		return player:GetAttribute("Item_" .. id) or 0
	end

	local function kindsHeld(player)
		local n = 0
		for _, id in Config.ItemOrder do
			if itemCount(player, id) > 0 then
				n += 1
			end
		end
		return n
	end

	function Store.GetBucks(player)
		return player:GetAttribute("Bucks") or 0
	end

	local function setBucks(player, amount)
		amount = math.max(0, math.floor(amount))
		player:SetAttribute("Bucks", amount)
		local stats = player:FindFirstChild("leaderstats")
		local v = stats and stats:FindFirstChild(CURRENCY)
		if v then
			v.Value = amount
		end
		dirty[player] = true
	end

	function Store.AddBucks(player, amount)
		if not player or not player.Parent or type(amount) ~= "number" or amount == 0 then
			return
		end
		setBucks(player, Store.GetBucks(player) + amount)
	end

	local function setItem(player, id, count)
		local before = itemCount(player, id)
		count = math.clamp(math.floor(count), 0, MAX_STACK)
		player:SetAttribute("Item_" .. id, count > 0 and count or nil)
		dirty[player] = true
		if id == "AllMightHair" then
			-- used up: it poofs off once the smash is thrown
			Store.RefreshHair(player, count < before and 0.55 or 0)
		end
	end

	-- the dev toys hand items out past the bag limits
	function Store.GiveItem(player, id, count)
		if ITEMS[id] then
			setItem(player, id, itemCount(player, id) + (count or 1))
		end
	end

	---------------------------------------------------------------------------
	-- EMOTES (round 58): sold in the Hero Shop - the only way to get one is to
	-- spend Bucks on it. What you own (EmotesOwned: "Id,Id") and the four on
	-- your wheel (EmoteWheel: "Id,,Id," - a blank is an empty slot) live in
	-- player attributes so the HUD can read them, and are saved with the rest.
	---------------------------------------------------------------------------
	local EMOTES = {}
	for _, e in Config.Emotes or {} do
		EMOTES[e.Id] = e
	end
	local SLOTS = Config.EmoteSlots or 4
	local lastEquip = setmetatable({}, { __mode = "k" }) -- [player] = os.clock()

	local function ownedSet(player)
		local out = {}
		for id in string.gmatch(player:GetAttribute("EmotesOwned") or "", "[^,]+") do
			if EMOTES[id] then
				out[id] = true
			end
		end
		return out
	end

	local function wheelList(player)
		local out, i = {}, 0
		for id in string.gmatch((player:GetAttribute("EmoteWheel") or "") .. ",", "([^,]*),") do
			i += 1
			if i > SLOTS then
				break
			end
			out[i] = EMOTES[id] and id or ""
		end
		for k = i + 1, SLOTS do
			out[k] = ""
		end
		return out
	end

	-- (round 63) what you own is kept in the order you got it (the shop's
	-- EMOTES tab lists them newest first). set: { [Id] = true }; order: the
	-- Ids, oldest first (anything in set but not in it goes after, in the
	-- shop's order)
	local function setOwned(player, set, order)
		local ids, seen = {}, {}
		for _, id in order or {} do
			if set[id] and not seen[id] and EMOTES[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
		for _, e in Config.Emotes or {} do
			if set[e.Id] and not seen[e.Id] then
				seen[e.Id] = true
				table.insert(ids, e.Id)
			end
		end
		player:SetAttribute("EmotesOwned", table.concat(ids, ","))
		dirty[player] = true
	end
	local function ownedOrder(player)
		local out = {}
		for id in string.gmatch(player:GetAttribute("EmotesOwned") or "", "[^,]+") do
			if EMOTES[id] then
				table.insert(out, id)
			end
		end
		return out
	end

	local function setWheel(player, list)
		local out = {}
		for i = 1, SLOTS do
			out[i] = list[i] or ""
		end
		player:SetAttribute("EmoteWheel", table.concat(out, ","))
		dirty[player] = true
	end

	function Store.OwnsEmote(player, id)
		return type(id) == "string" and ownedSet(player)[id] == true
	end

	-- (round 63) THE EMOTE ROLL, the way Jujutsu Shenanigans sells them:
	-- n at a time (Config.EmoteShop.Multipliers), RollPrice each - each one
	-- a random emote you don't have yet (never a repeat), picked by rarity
	-- (Rarities: Weight). Buying PickAt at once, the last is yours to CHOOSE
	-- (EmotePicks: a free pick waiting, saved - "PICK LATER"). Not that many
	-- left: you get (and pay for) what's left. Every one goes straight onto
	-- a free slot of the wheel.
	local ES = Config.EmoteShop or {}
	local RARITY = {}
	for _, r in ES.Rarities or {} do
		RARITY[r.Id] = r
	end
	local function unowned(player)
		local owned, pool = ownedSet(player), {}
		for _, e in Config.Emotes or {} do
			if not owned[e.Id] and not e.Exclusive then
				table.insert(pool, e)
			end
		end
		return pool
	end
	local function drawOne(pool)
		-- a rarity by its weight (among the rarities still in the pool), then
		-- one of that rarity
		local by, total = {}, 0
		for _, e in pool do
			local r = e.Rarity or "Common"
			if not by[r] then
				by[r] = {}
				total += (RARITY[r] and RARITY[r].Weight) or 1
			end
			table.insert(by[r], e)
		end
		local roll = math.random() * total
		for r, list in by do
			roll -= (RARITY[r] and RARITY[r].Weight) or 1
			if roll <= 0 then
				return list[math.random(1, #list)]
			end
		end
		local _, list = next(by)
		return list and list[1]
	end
	-- n rolls handed over (already paid for, in Bucks or Robux): out of what's
	-- left to get, the PickAt-th one a free pick. How many it gave.
	local function grantRolls(player, n, pool)
		pool = pool or unowned(player)
		local count = math.min(n, #pool)
		if count <= 0 then
			return 0
		end
		local picks = (n >= (ES.PickAt or 10) and count == n) and 1 or 0
		local owned, order, got = ownedSet(player), ownedOrder(player), {}
		for _ = 1, count - picks do
			local e = drawOne(pool)
			if not e then
				break
			end
			table.remove(pool, table.find(pool, e))
			owned[e.Id] = true
			table.insert(order, e.Id)
			table.insert(got, e.Id)
		end
		setOwned(player, owned, order)
		local wheel = wheelList(player)
		for _, id in got do
			local free = table.find(wheel, "")
			if free then
				wheel[free] = id
			end
		end
		setWheel(player, wheel)
		if picks > 0 then
			player:SetAttribute("EmotePicks", (player:GetAttribute("EmotePicks") or 0) + picks)
			dirty[player] = true
		end
		PlayVFX:FireClient(player, "EmoteRoll", nil, { Got = got, Pick = picks })
		return count
	end
	local lastRoll = setmetatable({}, { __mode = "k" })
	local function rollEmotes(player, n)
		if type(n) ~= "number" or not table.find(ES.Multipliers or { 1, 2, 5, 10 }, n) then
			return
		end
		local now = os.clock()
		if now - (lastRoll[player] or 0) < 0.5 then
			return
		end
		lastRoll[player] = now
		local pool = unowned(player)
		if #pool == 0 then
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Item = "Roll", Text = "You have all the emotes already!!!" })
			return
		end
		local count = math.min(n, #pool)
		local price = count * (ES.RollPrice or 25)
		if Store.GetBucks(player) < price then
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Item = "Roll", Text = "Not enough " .. CURRENCY .. " for " .. count .. " (" .. price .. ") - every KO pays " .. (ECON.PerKO or 5) })
			return
		end
		setBucks(player, Store.GetBucks(player) - price)
		grantRolls(player, n, pool)
	end

	-- a free pick (the tenth of a 10x roll): any one you don't have yet
	local function pickEmote(player, id)
		local e = EMOTES[id]
		local picks = player:GetAttribute("EmotePicks") or 0
		if not e or e.Exclusive or picks <= 0 or ownedSet(player)[id] then
			return
		end
		player:SetAttribute("EmotePicks", picks - 1 > 0 and picks - 1 or nil)
		local owned, order = ownedSet(player), ownedOrder(player)
		owned[id] = true
		table.insert(order, id)
		setOwned(player, owned, order)
		local wheel = wheelList(player)
		local free = table.find(wheel, "")
		if free then
			wheel[free] = id
			setWheel(player, wheel)
		end
		PlayVFX:FireClient(player, "EmoteRoll", nil, { Got = { id }, Pick = 0 })
	end

	-- put an emote you own in a slot of the wheel ("" empties it); it leaves
	-- any other slot it was in
	local function equipEmote(player, slot, id)
		if slot ~= math.floor(slot) or slot < 1 or slot > SLOTS then
			return
		end
		if id ~= "" and not ownedSet(player)[id] then
			return
		end
		local now = os.clock()
		if now - (lastEquip[player] or 0) < 0.08 then
			return
		end
		lastEquip[player] = now
		local wheel = wheelList(player)
		for i = 1, SLOTS do
			if id ~= "" and wheel[i] == id then
				wheel[i] = ""
			end
		end
		wheel[slot] = id
		setWheel(player, wheel)
	end

	-- (round 63) CODES (the REWARDS tab, Config.Codes): each works once per
	-- player (CodesUsed, saved) - Bucks, an emote, or both
	local lastCode = setmetatable({}, { __mode = "k" })
	local function redeem(player, code)
		local now = os.clock()
		if now - (lastCode[player] or 0) < 1 then
			return
		end
		lastCode[player] = now
		code = string.upper((code:gsub("%s", "")))
		local spec = (Config.Codes or {})[code]
		local used = {}
		for c in string.gmatch(player:GetAttribute("CodesUsed") or "", "[^,]+") do
			used[c] = true
		end
		if type(spec) ~= "table" then
			PlayVFX:FireClient(player, "CodeResult", nil, { Ok = false, Text = "That code doesn't work." })
			return
		end
		if used[code] then
			PlayVFX:FireClient(player, "CodeResult", nil, { Ok = false, Text = "You've already used that one." })
			return
		end
		used[code] = true
		local list = {}
		for c in used do
			table.insert(list, c)
		end
		player:SetAttribute("CodesUsed", table.concat(list, ","))
		dirty[player] = true
		local gave = {}
		if type(spec.Bucks) == "number" and spec.Bucks > 0 then
			Store.AddBucks(player, spec.Bucks)
			table.insert(gave, spec.Bucks .. " " .. CURRENCY)
		end
		if type(spec.Emote) == "string" and EMOTES[spec.Emote] and not ownedSet(player)[spec.Emote] then
			local owned, order = ownedSet(player), ownedOrder(player)
			owned[spec.Emote] = true
			table.insert(order, spec.Emote)
			setOwned(player, owned, order)
			local wheel = wheelList(player)
			local free = table.find(wheel, "")
			if free then
				wheel[free] = spec.Emote
				setWheel(player, wheel)
			end
			table.insert(gave, "the " .. (EMOTES[spec.Emote].Name or spec.Emote) .. " emote")
		end
		PlayVFX:FireClient(player, "CodeResult", nil, { Ok = true, Text = "Redeemed! " .. (#gave > 0 and table.concat(gave, " + ") or "") })
	end
	Store.RollEmotes, Store.PickEmote, Store.EquipEmote, Store.Redeem = rollEmotes, pickEmote, equipEmote, redeem
	Store.GrantRolls = grantRolls
	-- (round 72) the rolls for ROBUX (Config.EmoteShop.Robux): which roll each
	-- developer product is, and the purchases already handed over ([player] =
	-- their PurchaseIds, the last 50 - saved, so none is ever handed over twice)
	local robuxRolls = {}
	for n, spec in ES.Robux or {} do
		local id = type(spec) == "table" and tonumber(spec.Product)
		if id and id > 0 then
			robuxRolls[id] = n
		end
	end
	local receipts = setmetatable({}, { __mode = "k" })
	Store.EmoteOwned, Store.EmoteWheel, Store.SetEmotes = ownedSet, wheelList, function(player, set, list)
		setOwned(player, set)
		setWheel(player, list)
	end

	---------------------------------------------------------------------------
	-- Saving
	---------------------------------------------------------------------------

	local function saveData(player)
		if not saveStore or not loaded[player] then
			return
		end
		local items = {}
		for _, id in Config.ItemOrder do
			local c = itemCount(player, id)
			if c > 0 then
				items[id] = c
			end
		end
		local kills = player:GetAttribute("Kills") or 0
		local data = {
			Bucks = Store.GetBucks(player),
			Items = items,
			Kills = kills,
			Emotes = player:GetAttribute("EmotesOwned") or "",
			Wheel = player:GetAttribute("EmoteWheel") or "",
			Picks = player:GetAttribute("EmotePicks") or 0, -- (round 63) free picks waiting
			Codes = player:GetAttribute("CodesUsed") or "",
			Receipts = receipts[player] or {}, -- (round 72) Robux purchases handed over
			EmoteWipe = ES.Wipe or 0, -- (round 72) the emote wipe they've had
			Outfit = player:GetAttribute("AwakenOutfit") or 0,
			Settings = { WearCosmetics = player:GetAttribute("WearCosmetics") ~= false, ShowCosmetics = player:GetAttribute("ShowCosmetics") ~= false, Music = player:GetAttribute("Music") ~= false, Blood = player:GetAttribute("Blood") ~= false, AutoRun = player:GetAttribute("AutoRun") == true,
				RobloxCamera = player:GetAttribute("RobloxCamera") == true, PadSensitivity = tonumber(player:GetAttribute("PadSensitivity")) or 1 },
		}
		local ok = pcall(function()
			saveStore:SetAsync("u_" .. player.UserId, data)
		end)
		if ok then
			dirty[player] = nil
		end
		if Store.killBoard and kills > 0 then
			pcall(function()
				Store.killBoard:SetAsync("u_" .. player.UserId, kills)
			end)
		end
		return ok
	end

	local function loadData(player)
		setBucks(player, ECON.StartingBucks or 0)
		-- (no emotes to start with: they're bought in the shop)
		setOwned(player, {})
		setWheel(player, {})
		dirty[player] = nil
		if not saveStore then
			return
		end
		local ok, data = pcall(function()
			return saveStore:GetAsync("u_" .. player.UserId)
		end)
		if not ok or not player.Parent then
			return -- (Studio without API access, or DataStores are down: play on, don't save)
		end
		loaded[player] = true
		if type(data) == "table" then
			if type(data.Bucks) == "number" then
				setBucks(player, data.Bucks)
			end
			if type(data.Items) == "table" then
				for id, c in data.Items do
					if ITEMS[id] and type(c) == "number" then
						setItem(player, id, c)
					end
				end
			end
			if type(data.Kills) == "number" then
				Kit.setKills(player, data.Kills, true)
			end
			-- (round 72: Config.EmoteShop.Wipe) a wipe they haven't had yet: none
			-- of their emotes, their wheel or their picks come back
			local wiped = (ES.Wipe or 0) ~= 0 and data.EmoteWipe ~= ES.Wipe
			if type(data.Receipts) == "table" then
				local list = {}
				for _, r in data.Receipts do
					if type(r) == "string" then
						table.insert(list, r)
					end
				end
				receipts[player] = list
			end
			if type(data.Emotes) == "string" and not wiped then
				local set, order = {}, {}
				for id in string.gmatch(data.Emotes, "[^,]+") do
					if EMOTES[id] then
						set[id] = true
						table.insert(order, id)
					end
				end
				setOwned(player, set, order)
				local list, n = {}, 0
				for id in string.gmatch((type(data.Wheel) == "string" and data.Wheel or "") .. ",", "([^,]*),") do
					n += 1
					if n > SLOTS then
						break
					end
					list[n] = set[id] and id or ""
				end
				setWheel(player, list)
			end
			if type(data.Outfit) == "number" and data.Outfit > 0 then
				Store.PickOutfit(player, data.Outfit, true)
			end
			if type(data.Picks) == "number" and data.Picks > 0 and not wiped then
				player:SetAttribute("EmotePicks", math.floor(data.Picks))
			end
			if type(data.Codes) == "string" then
				player:SetAttribute("CodesUsed", data.Codes)
			end
			if type(data.Settings) == "table" then
				for _, key in { "WearCosmetics", "ShowCosmetics", "Music", "Blood", "AutoRun", "RobloxCamera" } do
					if type(data.Settings[key]) == "boolean" then
						player:SetAttribute(key, data.Settings[key])
					end
				end
				local sens = data.Settings.PadSensitivity
				if type(sens) == "number" and sens == sens then
					player:SetAttribute("PadSensitivity", math.clamp(sens, 0.25, 4))
				end
				if data.Settings.WearCosmetics == false and player.Character then
					applyGear(player, player.Character, 0)
				end
			end
			dirty[player] = nil
			if wiped then
				dirty[player] = true -- (saved as had)
				if (type(data.Emotes) == "string" and data.Emotes ~= "") or (tonumber(data.Picks) or 0) > 0 then
					task.delay(5, function()
						if player.Parent then
							PlayVFX:FireClient(player, "Notice", nil, { Text = "Emotes were reset for everyone! Get new ones in the shop - for Bucks or Robux", Color = Color3.fromRGB(255, 220, 120) })
						end
					end)
				end
			end
		end
	end

	function Store.PlayerJoined(player)
		task.spawn(loadData, player)
	end

	function Store.MarkDirty(player)
		dirty[player] = true
	end

	-- (round 72) A ROBUX PURCHASE: Roblox hands it over here - maybe more than
	-- once, maybe later on another server if this one never said it's done.
	-- Each PurchaseId is handed over once, and it's only done once it's saved.
	-- Fewer emotes left to get than were paid for: the rest back as Bucks.
	function Store.ProcessReceipt(info)
		local NOT_YET, DONE = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
		local n = type(info) == "table" and robuxRolls[info.ProductId]
		if not n then
			return NOT_YET
		end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return NOT_YET
		end
		-- (their save has to be read first: give it a moment)
		local t0 = os.clock()
		while saveStore and not loaded[player] and player.Parent and os.clock() - t0 < 30 do
			task.wait(0.25)
		end
		if not player.Parent or (saveStore and not loaded[player]) then
			return NOT_YET
		end
		local list = receipts[player] or {}
		receipts[player] = list
		if table.find(list, info.PurchaseId) then
			return DONE
		end
		table.insert(list, info.PurchaseId)
		while #list > 50 do
			table.remove(list, 1)
		end
		local gave = grantRolls(player, n)
		if gave < n then
			local back = (n - gave) * (ES.RollPrice or 25)
			Store.AddBucks(player, back)
			PlayVFX:FireClient(player, "Notice", nil, {
				Text = (gave == 0 and "You have every emote already" or ("Only " .. gave .. " left to get")) .. " - " .. back .. " " .. CURRENCY .. " back for the rest",
				Color = Color3.fromRGB(150, 255, 160),
			})
		end
		dirty[player] = true
		if saveStore and not saveData(player) then
			return NOT_YET
		end
		return DONE
	end
	pcall(function()
		game:GetService("MarketplaceService").ProcessReceipt = Store.ProcessReceipt
	end)

	-- SETTINGS: MY COSMETICS (wear your hero's look - everyone sees it or
	-- doesn't) and SHOW COSMETICS (see anyone's, on your own screen). Saved.
	local lastSetting = {}
	SettingsRemote.OnServerEvent:Connect(function(player, key, value)
		-- (round 68) CONTROLLER SENSITIVITY is a number; the rest are switches
		if key == "PadSensitivity" then
			if type(value) ~= "number" or value ~= value then
				return
			end
			value = math.clamp(value, 0.25, 4)
		elseif type(value) ~= "boolean" or (key ~= "WearCosmetics" and key ~= "ShowCosmetics" and key ~= "Music" and key ~= "Blood" and key ~= "AutoRun" and key ~= "RobloxCamera") then
			return
		end
		local now = os.clock()
		if now - (lastSetting[player] or 0) < 0.15 then
			return
		end
		lastSetting[player] = now
		player:SetAttribute(key, value)
		dirty[player] = true
		if key == "WearCosmetics" and player.Character then
			applyGear(player, player.Character, 0)
		end
	end)

	-- TOP HEROES: the most kills of all time (every server), plus whoever's
	-- here now, published for the HUD's leaderboard
	local LB = Config.Leaderboard or {}
	if ECON.SaveData ~= false and LB.Enabled ~= false then
		pcall(function()
			Store.killBoard = game:GetService("DataStoreService"):GetOrderedDataStore(LB.Store or "QuirkBattlegrounds_Kills_v1")
		end)
	end
	local board = ReplicatedStorage:FindFirstChild("TopHeroes") or Instance.new("StringValue")
	board.Name = "TopHeroes"
	board.Parent = ReplicatedStorage
	local names = {}
	local stored = {} -- the last page read from the ordered store
	function Store.PublishBoard()
		local byId = {}
		for _, e in stored do
			byId[e.UserId] = { UserId = e.UserId, Name = e.Name, Kills = e.Kills }
		end
		for _, plr in Players:GetPlayers() do
			local k = plr:GetAttribute("Kills") or 0
			local e = byId[plr.UserId]
			if not e or k > e.Kills then
				byId[plr.UserId] = { UserId = plr.UserId, Name = plr.DisplayName, Kills = k }
			end
		end
		local list = {}
		for _, e in byId do
			if e.Kills > 0 then
				local _, rank = Config.RankOf(e.Kills)
				e.Rank = rank.Name
				table.insert(list, e)
			end
		end
		table.sort(list, function(a, b)
			return a.Kills > b.Kills or (a.Kills == b.Kills and a.UserId < b.UserId)
		end)
		while #list > (LB.Size or 10) do
			table.remove(list)
		end
		pcall(function()
			board.Value = game:GetService("HttpService"):JSONEncode(list)
		end)
	end
	local function readBoard()
		if not Store.killBoard then
			return
		end
		pcall(function()
			local page = Store.killBoard:GetSortedAsync(false, LB.Size or 10):GetCurrentPage()
			local fresh = {}
			for _, entry in page do
				local id = tonumber(string.match(entry.key, "%d+"))
				if id then
					if not names[id] then
						local ok, name = pcall(function()
							return Players:GetNameFromUserIdAsync(id)
						end)
						names[id] = ok and name or ("Hero " .. id)
					end
					table.insert(fresh, { UserId = id, Name = names[id], Kills = entry.value })
				end
			end
			stored = fresh
		end)
	end
	task.spawn(function()
		while true do
			readBoard()
			Store.PublishBoard()
			task.wait(LB.Refresh or 60)
		end
	end)

	function Store.PlayerLeft(player)
		scoped[player] = nil
		lastUse[player] = nil
		lastShot[player] = nil
		for _, ball in grapes[player] or {} do
			ball:Destroy()
		end
		grapes[player] = nil
		task.spawn(function()
			saveData(player)
			loaded[player] = nil
			dirty[player] = nil
		end)
	end

	task.spawn(function()
		while true do
			task.wait(ECON.AutoSave or 90)
			for _, plr in Players:GetPlayers() do
				if dirty[plr] then
					task.spawn(saveData, plr)
				end
			end
		end
	end)
	pcall(function()
		game:BindToClose(function()
			for _, plr in Players:GetPlayers() do
				task.spawn(saveData, plr)
			end
			task.wait(2.5)
		end)
	end)

	---------------------------------------------------------------------------
	-- The hero costume (All Might's muscle form): swap the shirt and pants
	-- through a HumanoidDescription, and put the player's own back after.
	---------------------------------------------------------------------------

	-- (round 59) A body's look changes one at a time, in the order asked: the
	-- awakening outfit and the hero costume can both want it at once.
	Store.lookQueue = setmetatable({}, { __mode = "k" })
	function Store.dress(char, fn)
		local q = Store.lookQueue[char]
		if not q then
			q = {}
			Store.lookQueue[char] = q
		end
		table.insert(q, fn)
		if #q > 1 then
			return -- (the one running now picks it up)
		end
		task.spawn(function()
			while #q > 0 do
				pcall(q[1])
				table.remove(q, 1)
			end
		end)
	end

	function Store.Outfit(char, on)
		local cfg = Config.AllMightOutfit
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not cfg or not cfg.Enabled or not hum then
			return
		end
		on = on == true
		-- (awakened in their own outfit: that's what they wear till it ends)
		if char:GetAttribute("AwakenFit") then
			return
		end
		if (char:GetAttribute("HeroOutfit") == true) == on then
			return
		end
		char:SetAttribute("HeroOutfit", on)
		-- (round 73) the famous bangs spring up with the muscle
		local hair = char:FindFirstChild("HeroHair")
		if on and not hair and Store.buildHair then
			local built = Store.buildHair(char)
			if built then
				built:SetAttribute("FromForm", true)
			end
		elseif not on and hair and hair:GetAttribute("FromForm") then
			hair:Destroy()
			local owner = Players:GetPlayerFromCharacter(char)
			if owner and Store.RefreshHair then
				Store.RefreshHair(owner) -- (his own, if he's got one in his bag)
			end
		end
		local token = (outfitTokens[char] or 0) + 1
		outfitTokens[char] = token
		Store.dress(char, function()
			local ok, desc = pcall(hum.GetAppliedDescription, hum)
			if not ok or not desc or outfitTokens[char] ~= token then
				return
			end
			if on then
				ownClothes[char] = ownClothes[char] or { Shirt = desc.Shirt, Pants = desc.Pants }
				desc.Shirt = cfg.Shirt or desc.Shirt
				desc.Pants = cfg.Pants or desc.Pants
			else
				local own = ownClothes[char]
				if not own then
					return
				end
				desc.Shirt = own.Shirt
				desc.Pants = own.Pants
			end
			pcall(hum.ApplyDescription, hum, desc)
		end)
	end

	---------------------------------------------------------------------------
	-- (round 59) AWAKENING OUTFITS (Config.AwakeningOutfits): one of their own
	-- saved Roblox outfits, picked on the phone (the OUTFIT app), worn while
	-- they're awakened - their own look comes back after. Its body size and
	-- the way it moves stay theirs.
	---------------------------------------------------------------------------
	Store.fits = setmetatable({}, { __mode = "k" }) -- [player] = { Id, Desc }: fetched when picked
	Store.fitPicked = setmetatable({}, { __mode = "k" }) -- [player] = os.clock() of the last pick
	Store.ownLook = setmetatable({}, { __mode = "k" }) -- [char] = their look before the outfit

	-- an outfit's look, from Roblox (nil if it can't be had)
	function Store.fetchFit(id)
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromOutfitIdAsync(id)
		end)
		if not (ok and desc) then
			ok, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromOutfitId(id)
			end)
		end
		return ok and desc or nil
	end

	-- the pick (0 = none): kept on the player (AwakenOutfit), saved, and its
	-- look fetched now so it's ready the moment they awaken
	function Store.PickOutfit(player, id, fromSave)
		local cfg = Config.AwakeningOutfits
		if not cfg or cfg.Enabled == false or type(id) ~= "number" or id ~= id or id < 0 or id > 2 ^ 53 or id % 1 ~= 0 then
			return
		end
		local now = os.clock()
		if not fromSave and now - (Store.fitPicked[player] or -10) < 0.4 then
			return
		end
		Store.fitPicked[player] = now
		player:SetAttribute("AwakenOutfit", id)
		if not fromSave then
			Store.MarkDirty(player)
		end
		if id == 0 then
			Store.fits[player] = nil
			return
		end
		task.spawn(function()
			local desc = Store.fetchFit(id)
			if player:GetAttribute("AwakenOutfit") ~= id then
				return
			end
			if desc then
				Store.fits[player] = { Id = id, Desc = desc }
			elseif not fromSave then
				player:SetAttribute("AwakenOutfit", 0) -- (not an outfit Roblox would give us)
			end
		end)
	end

	-- on with the ult, off when it ends
	function Store.AwakenOutfit(player, char, on)
		local cfg = Config.AwakeningOutfits
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not cfg or cfg.Enabled == false or not hum then
			return
		end
		local id = tonumber(player:GetAttribute("AwakenOutfit")) or 0
		local want = (on == true and id > 0) and id or nil
		if char:GetAttribute("AwakenFit") == want then
			return
		end
		char:SetAttribute("AwakenFit", want)
		if want then
			Store.dress(char, function()
				local fit = Store.fits[player]
				local desc = (fit and fit.Id == want and fit.Desc) or Store.fetchFit(want)
				if not desc or char:GetAttribute("AwakenFit") ~= want then
					return
				end
				local ok, mine = pcall(hum.GetAppliedDescription, hum)
				if not ok or not mine then
					return
				end
				Store.ownLook[char] = Store.ownLook[char] or mine
				local look = desc:Clone()
				-- (their body stays theirs: its size, and the way it moves)
				for _, key in {
					"HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale",
					"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation",
				} do
					pcall(function()
						look[key] = mine[key]
					end)
				end
				pcall(hum.ApplyDescription, hum, look)
			end)
		else
			Store.dress(char, function()
				local mine = Store.ownLook[char]
				Store.ownLook[char] = nil
				if mine and not char:GetAttribute("AwakenFit") then
					pcall(hum.ApplyDescription, hum, mine)
				end
			end)
		end
	end


	---------------------------------------------------------------------------
	-- All Might's hair: worn for as long as you have one in your bag
	---------------------------------------------------------------------------

	local HAIR_GOLD = Color3.fromRGB(252, 218, 84)
	local HAIR_SHADE = Color3.fromRGB(226, 172, 46)

	local function buildHair(char)
		local head = char:FindFirstChild("Head")
		if not head then
			return
		end
		local hair = Instance.new("Model")
		hair.Name = "HeroHair"
		local v = visibleHead(head)
		-- swept-back blond hair over the top and back of the head
		weld(head, ellipsoid(hair, Vector3.new(v.X * 1.08, v.Y * 0.6, v.Z * 1.1), HAIR_GOLD), CFrame.new(0, v.Y * 0.3, v.Z * 0.04))
		weld(head, ellipsoid(hair, Vector3.new(v.X * 1.02, v.Y * 0.7, v.Z * 0.56), HAIR_SHADE), CFrame.new(0, v.Y * 0.06, v.Z * 0.3))
		for _, side in { 1, -1 } do
			-- the two famous bangs: thick tufts off his forehead that sweep up
			-- and out into a V, curving further out towards the tips
			local lower = CFrame.new(side * v.X * 0.12, v.Y * 0.4, -v.Z * 0.34) * CFrame.Angles(math.rad(-8), 0, math.rad(-side * 16))
			weld(head, ellipsoid(hair, Vector3.new(v.X * 0.46, v.Y * 0.8, v.Z * 0.3), HAIR_GOLD), lower * CFrame.new(0, v.Y * 0.35, 0))
			local upper = lower * CFrame.new(0, v.Y * 0.6, 0) * CFrame.Angles(math.rad(-6), 0, math.rad(-side * 24))
			weld(head, ellipsoid(hair, Vector3.new(v.X * 0.3, v.Y * 0.7, v.Z * 0.22), HAIR_GOLD), upper * CFrame.new(0, v.Y * 0.3, 0))
			-- and the strands that hang down beside his face
			local strand = ellipsoid(hair, Vector3.new(v.X * 0.16, v.Y * 0.62, v.Z * 0.16), HAIR_SHADE)
			weld(head, strand, CFrame.new(side * v.X * 0.46, v.Y * 0.02, -v.Z * 0.2) * CFrame.Angles(0, 0, math.rad(side * 8)))
		end
		hair.Parent = char
		return hair
	end
	Store.buildHair = buildHair

	-- delay: how long before a hair that's been used up poofs off
	function Store.RefreshHair(player, delay)
		local char = player.Character
		if not char then
			return
		end
		local want = itemCount(player, "AllMightHair") > 0
		local has = char:FindFirstChild("HeroHair")
		if want and not has then
			buildHair(char)
		elseif not want and has then
			task.delay(delay or 0, function()
				if itemCount(player, "AllMightHair") <= 0 and has.Parent then
					local head = char:FindFirstChild("Head")
					broadcast("HairPoof", char, { Pos = head and head.Position or nil })
					has:Destroy()
				end
			end)
		end
	end

	function Store.CharacterAdded(player, char)
		scoped[player] = nil
		task.delay(0.3, function()
			if player.Character == char then
				Store.RefreshHair(player)
			end
		end)
	end

	---------------------------------------------------------------------------
	-- The sniper: out while you're scoped in
	---------------------------------------------------------------------------

	local function buildRifle(char)
		local arm = findLimb(char, "RightHand", "Right Arm")
		if not arm then
			return
		end
		local rifle = Instance.new("Model")
		rifle.Name = "HeroSniper"
		local grip = arm:IsA("MeshPart") and arm.Size.Y * 0.3 or arm.Size.Y * 0.45
		local base = CFrame.new(0, -grip, -0.2) * CFrame.Angles(math.rad(-90), 0, 0)
		local dark, metal = Color3.fromRGB(34, 36, 42), Color3.fromRGB(88, 92, 100)
		weld(arm, gearPart(rifle, Vector3.new(0.34, 0.42, 3.4), dark, Enum.Material.Metal), base * CFrame.new(0, 0.1, -0.9))
		local barrel = gearPart(rifle, Vector3.new(2.6, 0.16, 0.16), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		weld(arm, barrel, base * CFrame.new(0, 0.18, -3.8) * CFrame.Angles(0, math.rad(90), 0))
		local scope = gearPart(rifle, Vector3.new(1.3, 0.26, 0.26), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
		weld(arm, scope, base * CFrame.new(0, 0.52, -1.2) * CFrame.Angles(0, math.rad(90), 0))
		local lens = gearPart(rifle, Vector3.new(0.05, 0.22, 0.22), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		weld(arm, lens, base * CFrame.new(0, 0.52, -1.87) * CFrame.Angles(0, math.rad(90), 0))
		weld(arm, gearPart(rifle, Vector3.new(0.3, 0.6, 1), Color3.fromRGB(110, 76, 48), Enum.Material.Wood), base * CFrame.new(0, -0.05, 1.1))
		rifle.Parent = char
	end

	local function setScope(player, char, on)
		on = on == true
		scoped[player] = on or nil
		if char then
			local old = char:FindFirstChild("HeroSniper")
			if old then
				old:Destroy()
			end
			if on then
				buildRifle(char)
			end
			char:SetAttribute("Scoped", on)
			-- (everyone sees the rifle come up; the shooter's screen goes to the scope)
			broadcast("Scope", char, { On = on })
		end
	end

	local function fireSniper(player, aimDir, aimPos)
		local item = ITEMS.Sniper
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not item or not scoped[player] or not root or not alive(char) or itemCount(player, "Sniper") <= 0 then
			return
		end
		if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Frozen") then
			return
		end
		local now = os.clock()
		if now - (lastShot[player] or -math.huge) < (item.FireRate or 0.9) - COOLDOWN_TOLERANCE then
			return
		end
		lastShot[player] = now
		local head = char:FindFirstChild("Head") or root
		local from = head.Position
		local dir
		if typeof(aimPos) == "Vector3" and aimPos == aimPos and (aimPos - from).Magnitude > 1 then
			dir = (aimPos - from).Unit
		elseif typeof(aimDir) == "Vector3" and aimDir == aimDir and aimDir.Magnitude > 0.1 then
			dir = aimDir.Unit
		else
			dir = root.CFrame.LookVector
		end
		local range = item.Range or 450
		local ignore = { char }
		for _, name in { "ItemDrops", "MapDebris" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(ignore, f)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, dir * range, params)
		local to = hit and hit.Position or from + dir * range
		local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		local headshot = hit ~= nil and hit.Instance.Name == "Head"
		setItem(player, "Sniper", itemCount(player, "Sniper") - 1)
		local struck = nil
		if model and model ~= char and model:FindFirstChildOfClass("Humanoid") then
			local amount = (item.Damage or 35) * (headshot and (item.HeadshotBonus or 1.5) or 1)
			if damage(player, model, amount, { From = from }) then
				knockback(model, dir * 45 + UP * 10, 0.12)
				stun(model, 0.4)
				struck = model
			end
		elseif hit then
			Destruction.Sphere(to, 1.3, "Impact", dir) -- a bullet hole
		end
		broadcast("SniperShot", char, { From = from, To = to, Dir = dir, Target = struck, Headshot = (struck and headshot) or nil })
		if itemCount(player, "Sniper") <= 0 then
			setScope(player, char, false)
		end
	end

	---------------------------------------------------------------------------
	-- Items. Each returns false when using it doesn't use one up.
	---------------------------------------------------------------------------

	local ItemUse = {}

	local function heal(char, amount)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
		end
	end

	function ItemUse.Soda(_, char, _, item)
		broadcast("Soda", char, { Heal = item.Heal })
		task.delay(0.45, heal, char, item.Heal or 40)
	end

	-- any food: a few bites, then the health
	function Store.Eat(player, id)
		local item = ITEMS[id]
		local char = player.Character
		if not item or not item.Heal or not char or not alive(char) then
			return
		end
		if id == "Soda" then
			ItemUse.Soda(player, char, nil, item)
			return
		end
		broadcast("Eat", char, { Item = id, Heal = math.min(item.Heal, 200) })
		task.delay(0.5, heal, char, item.Heal)
	end

	function ItemUse.Sniper(player, char)
		setScope(player, char, not scoped[player])
		return false
	end

	-- lobbed to the aim point: fly the arc until it hits something, stick, then boom
	function ItemUse.Bomb(player, char, root, item, dir, pos)
		local g = workspace.Gravity
		local d = flatten(dir, root)
		local from = root.Position + UP * 2.5 + d * 1.5
		local flat = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
		local dist = math.min(flat.Magnitude, 130)
		if flat.Magnitude > 0.5 then
			d = flat.Unit
		end
		local flight = math.clamp(dist / (item.ThrowSpeed or 85), 0.35, 1.5)
		local dy = math.clamp(pos.Y - from.Y, -60, 60)
		local vel = d * (dist / flight) + UP * ((dy + 0.5 * g * flight * flight) / flight)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local step, maxT = 1 / 30, item.MaxFlight or 2.5
		local p, t = from, 0
		local land, landT = nil, nil
		while t < maxT do
			local t2 = t + step
			local p2 = from + vel * t2 - UP * (0.5 * g * t2 * t2)
			local hit = workspace:Raycast(p, p2 - p, params)
			if hit then
				land = hit.Position + hit.Normal * 0.9
				landT = t + step * math.clamp((hit.Position - p).Magnitude / math.max((p2 - p).Magnitude, 1e-3), 0, 1)
				break
			end
			p, t = p2, t2
		end
		land, landT = land or p, landT or t
		local fuse = item.Fuse or 0.7
		broadcast("BombThrow", char, { From = from, Vel = vel, Gravity = g, Land = land, LandTime = landT, Fuse = fuse })
		task.delay(landT + fuse, function()
			local radius = item.Radius or 16
			for _, model in queryRadius(char, land, radius) do
				if damage(player, model, item.Damage or 32, { From = land, Heavy = true }) then
					knockback(model, awayFrom(land, model, d) * 110 + UP * 55, 0.25)
					stun(model, 0.9)
				end
			end
			Destruction.Sphere(land, radius * 0.65, "Explosion")
			broadcast("BombBoom", nil, { Pos = land, Radius = radius })
		end)
	end

	-- one Detroit Smash, then the hair's gone
	function ItemUse.AllMightHair(player, char, root, item, dir)
		local d = flatten(dir, root)
		broadcast("HairSmash", char, { Dir = d })
		task.delay(0.4, function()
			if not alive(char) then
				return
			end
			local range, width = item.Range or 110, item.Width or 30
			local look = CFrame.lookAt(root.Position, root.Position + d)
			for _, model in queryBox(char, look * CFrame.new(0, 4, -range / 2), Vector3.new(width, 28, range)) do
				if damage(player, model, item.Damage or 45, { Heavy = true }) then
					knockback(model, d * 170 + UP * 45, 0.28)
					stun(model, 1.2)
				end
			end
			Destruction.Box(look * CFrame.new(0, 6, -range / 2 - 4), Vector3.new(width * 0.75, 22, range), "Wind", d)
		end)
	end

	function ItemUse.Trigger(player, char, _, item)
		local ends = workspace:GetServerTimeNow() + (item.Duration or 10)
		char:SetAttribute("TriggeredUntil", ends)
		applyPassives(player, char, false)
		broadcast("Trigger", char, { Duration = item.Duration or 10 })
		task.delay(item.Duration or 10, function()
			if char.Parent and char:GetAttribute("TriggeredUntil") == ends then
				char:SetAttribute("TriggeredUntil", nil)
				applyPassives(player, char, false)
			end
		end)
	end

	-- Eraser Head: the scarf snags the first one in line and reels them in,
	-- and his stare switches their quirk off for a few seconds
	function ItemUse.CaptureScarf(player, char, root, item, dir)
		local origin = root.Position + UP * 1.2
		local target = firstInLine(char, origin, dir, item.Range or 55, 5)
		if target and untouchable(target) then
			target = nil
		end
		broadcast("Scarf", char, { Dir = dir, Target = target, To = origin + dir * (item.Range or 55) })
		if not target then
			return
		end
		task.wait(0.2)
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr or not alive(target) then
			return
		end
		target:SetAttribute("ErasedUntil", workspace:GetServerTimeNow() + (item.Erase or 5))
		broadcast("Erased", nil, { Target = target, Duration = item.Erase or 5 })
		local pull = Vector3.new(root.Position.X - tr.Position.X, 0, root.Position.Z - tr.Position.Z)
		if pull.Magnitude > 5 then
			knockback(target, pull.Unit * math.clamp(pull.Magnitude * 3, 40, 130) + UP * 14, 0.22)
		end
		stun(target, item.Stun or 1.4)
		lastHit[target] = { Player = player, Time = os.clock() }
	end

	-- Mineta: a sticky purple ball on the ground; the first one to step on it is stuck
	function ItemUse.GrapeBalls(player, char, root, item)
		local folder = workspace:FindFirstChild("ItemDrops")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "ItemDrops"
			folder.Parent = workspace
		end
		local pos = groundBelow(root.Position, char) + UP * 0.7
		local ball = Instance.new("Part")
		ball.Name = "GrapeBall"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.5, 1.5, 1.5)
		ball.Color = Color3.fromRGB(120, 44, 170)
		ball.Material = Enum.Material.SmoothPlastic
		ball.Reflectance = 0.15
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CFrame = CFrame.new(pos)
		ball:SetAttribute("Owner", player.UserId)
		ball.Parent = folder
		local mine = grapes[player] or {}
		grapes[player] = mine
		table.insert(mine, ball)
		while #mine > (item.MaxOut or 6) do
			table.remove(mine, 1):Destroy()
		end
		broadcast("GrapeDrop", char, { Pos = pos })
		task.spawn(function()
			local t0 = os.clock()
			while ball.Parent and os.clock() - t0 < (item.Life or 20) do
				local victim = queryRadius(char, pos, 2.4)[1]
				if victim then
					stun(victim, item.Root or 2.2, 0)
					broadcast("GrapeStick", nil, { Target = victim, Pos = pos, Duration = item.Root or 2.2 })
					break
				end
				task.wait(0.1)
			end
			local i = table.find(mine, ball)
			if i then
				table.remove(mine, i)
			end
			ball:Destroy()
		end)
	end

	-- Uraraka's Zero Gravity on yourself: most of your weight is lifted off
	function ItemUse.ZeroGravity(_, char, root, item)
		local old = root:FindFirstChild("ZeroGravity")
		if old then
			old:Destroy()
		end
		local att = root:FindFirstChild("ZeroGravityAttachment") or Instance.new("Attachment")
		att.Name = "ZeroGravityAttachment"
		att.Parent = root
		local force = Instance.new("VectorForce")
		force.Name = "ZeroGravity"
		force.Attachment0 = att
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Parent = root
		local ends = workspace:GetServerTimeNow() + (item.Duration or 10)
		char:SetAttribute("ZeroGUntil", ends)
		broadcast("ZeroG", char, { Duration = item.Duration or 10 })
		task.spawn(function()
			local t0 = os.clock()
			while force.Parent and os.clock() - t0 < (item.Duration or 10) do
				-- (kept up to date: muscle form changes how heavy you are)
				force.Force = UP * root.AssemblyMass * workspace.Gravity * (1 - (item.Gravity or 0.25))
				task.wait(0.2)
			end
			force:Destroy()
			if char:GetAttribute("ZeroGUntil") == ends then
				char:SetAttribute("ZeroGUntil", nil)
			end
		end)
	end

	---------------------------------------------------------------------------

	-- room in the bag for one more of these?
	local function fits(player, id)
		local have = itemCount(player, id)
		return have < MAX_STACK and (have > 0 or kindsHeld(player) < (ECON.MaxKinds or 4))
	end

	-- vendors out in the world (the snack machines, Tony) hand over food:
	-- into the bag if there's room, otherwise it's eaten right there
	function Store.GiveOrEat(player, id)
		local item = ITEMS[id]
		if not item then
			return false
		end
		if fits(player, id) then
			setItem(player, id, itemCount(player, id) + (item.Gives or 1))
			return true
		end
		Store.Eat(player, id)
		return false
	end

	-- (round 60) Creati's LUCKY BAG: one random Hero Shop item into the bag
	-- (never food), if there's room for one; its id, or nil
	function Store.LuckyItem(player)
		local pool = {}
		for _, id in Config.ShopOrder or {} do
			if ITEMS[id] and fits(player, id) then
				table.insert(pool, id)
			end
		end
		if #pool == 0 then
			return nil
		end
		local id = pool[math.random(1, #pool)]
		setItem(player, id, itemCount(player, id) + (ITEMS[id].Gives or 1))
		return id
	end


	-- (round 63) DELIVERIES (Config.Deliveries, the way Jujutsu Shenanigans
	-- does them): pay, and a drone flies in from over the rooftops - wherever
	-- you are on the map - and drops it by you. Walk into it to take it
	-- (it's yours: nobody else can); leave it Despawn seconds and it's gone.
	-- SODA: a soda. ITEM: a random one out of the shop (one that fits your bag).
	local DL = Config.Deliveries or {}
	local enRoute = setmetatable({}, { __mode = "k" }) -- [player] = deliveries on the way
	local function cargoFor(player, id)
		local item = ITEMS[id]
		local box = Instance.new("Part")
		box.Name = "Delivery"
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		if id == "Soda" then
			box.Shape = Enum.PartType.Cylinder
			box.Size = Vector3.new(1.3, 0.8, 0.8)
			box.Color = item and item.Color or Color3.fromRGB(70, 200, 255)
			box.Material = Enum.Material.Metal
		else
			box.Size = Vector3.new(1.3, 1.1, 1.3)
			box.Color = Color3.fromRGB(176, 128, 76)
			box.Material = Enum.Material.Cardboard
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = "Tag"
		tag.Size = UDim2.fromOffset(120, 40)
		tag.StudsOffset = Vector3.new(0, 2.2, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 90
		tag.Parent = box
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.PatrickHand
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = (item and item.Icon or "📦") .. " " .. player.DisplayName
		text.Parent = tag
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 230, 150)
		glow.Range = 8
		glow.Brightness = 1.5
		glow.Parent = box
		return box
	end
	-- (free: the console's drop - no charge)
	local function deliver(player, kind, free)
		local spec = DL[kind]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if type(spec) ~= "table" or not root or not alive(char) then
			return
		end
		if (enRoute[player] or 0) >= (DL.MaxAtOnce or 2) then
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Item = "Deliver" .. kind, Text = "Your delivery's still on its way!" })
			return
		end
		local id = spec.Item
		if not id then
			local pool = {}
			for _, it in Config.ShopOrder or {} do
				if ITEMS[it] and it ~= "Soda" and fits(player, it) then
					table.insert(pool, it)
				end
			end
			id = #pool > 0 and pool[math.random(1, #pool)] or nil
		end
		local price = free and 0 or (spec.Price or 5)
		local reason
		if not id or not ITEMS[id] or not fits(player, id) then
			reason = "Your bag is full: use something up first"
		elseif not free and Store.GetBucks(player) < price then
			reason = "Not enough " .. CURRENCY .. " (KOs pay " .. (ECON.PerKO or 5) .. ")"
		end
		if reason then
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Item = "Deliver" .. kind, Text = reason })
			return
		end
		if price > 0 then
			setBucks(player, Store.GetBucks(player) - price)
		end
		enRoute[player] = (enRoute[player] or 0) + 1
		PlayVFX:FireClient(player, "ShopResult", nil, { Ok = true, Item = "Deliver" .. kind, Text = "Support Drop incoming - watch the sky!" })
		-- (round 66) the SUPPORT DROP: no drone - a U.A. Support Course drop
		-- pod (one of Mei Hatsume's "babies") comes down out of the sky on a
		-- smoke trail, aimed at a ring it paints on the street beside you
		-- (everyone sees it coming: stand under it and you're thrown clear),
		-- slams in, vents steam and pops its lid - and your delivery rises out
		-- of it. Walk into it to take it (it's yours: nobody else can); leave
		-- it Despawn seconds and it's gone. Every screen draws the pod; the
		-- server only says where and when (Effects.SupportDrop).
		task.spawn(function()
			local POD = DL.Pod or {}
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local here = r and r.Position or root.Position
			local a = math.random() * math.pi * 2
			local spot = here + Vector3.new(math.cos(a), 0, math.sin(a)) * (POD.Offset or 6)
			local ground = groundBelow(spot + Vector3.new(0, 6, 0), player.Character)
			local land = Vector3.new(spot.X, ground.Y, spot.Z)
			local fall = POD.FallTime or 1.6
			Store.dropSeq = (Store.dropSeq or 0) + 1
			local dropId = Store.dropSeq
			-- (in from high over the rooftops, off to one side)
			local from = land + Vector3.new(math.cos(a + 2.2) * (POD.Drift or 60), POD.Height or 170, math.sin(a + 2.2) * (POD.Drift or 60))
			broadcast("SupportDrop", nil, {
				Id = dropId, Pos = land, From = from, Time = fall, Open = POD.OpenDelay or 0.5,
				Owner = player.UserId, Name = player.DisplayName, Icon = ITEMS[id].Icon, Despawn = DL.Despawn or 10,
			})
			task.wait(fall)
			-- the slam: anyone else close is thrown clear of it
			for _, plr in Players:GetPlayers() do
				local c = plr.Character
				local rr = c and c:FindFirstChild("HumanoidRootPart")
				if rr and plr ~= player and alive(c) then
					local off = rr.Position - land
					if off.Magnitude < (POD.Radius or 8) then
						local out = Vector3.new(off.X, 0, off.Z)
						out = out.Magnitude > 0.1 and out.Unit or Vector3.new(1, 0, 0)
						knockback(c, out * (POD.Push or 55) + UP * (POD.Lift or 30), 0.25)
					end
				end
			end
			task.wait(POD.OpenDelay or 0.5)
			-- the lid's off: it rises out of the pod
			local cargo = cargoFor(player, id)
			cargo.CFrame = CFrame.new(land + Vector3.new(0, (POD.Pedestal or 3.4) + cargo.Size.Y / 2, 0))
			cargo.Parent = workspace
			-- yours for the taking (walk into it)
			local t3 = os.clock()
			local claimed = false
			while os.clock() - t3 < (DL.Despawn or 10) and cargo.Parent and player.Parent do
				local rp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if rp and alive(player.Character) and (rp.Position - cargo.Position).Magnitude < 6.5 then
					if fits(player, id) then
						setItem(player, id, itemCount(player, id) + (ITEMS[id].Gives or 1))
						claimed = true
						PlayVFX:FireClient(player, "ShopResult", nil, { Ok = true, Item = id, Text = "Got it: " .. ITEMS[id].Name })
						break
					end
				end
				task.wait(0.1)
			end
			enRoute[player] = math.max((enRoute[player] or 1) - 1, 0)
			if not claimed and player.Parent then
				PlayVFX:FireClient(player, "Notice", nil, { Text = "Your Support Drop was left too long and it's gone.", Color = Color3.fromRGB(255, 180, 120) })
			end
			broadcast("SupportDropDone", nil, { Id = dropId, Taken = claimed })
			cargo:Destroy()
		end)
	end
	Store.Deliver = deliver

	-- take Bucks if they have them
	function Store.Spend(player, amount)
		if Store.GetBucks(player) < amount then
			return false
		end
		setBucks(player, Store.GetBucks(player) - amount)
		return true
	end

	-- vendor: nil for the Hero Shop, or a key of Store.Vendors (e.g. "Pizza"),
	-- which says whether they sell it here and now, and reacts to the sale
	Store.Vendors = {}
	local function buy(player, id, vendor)
		local item = ITEMS[id]
		local seller = vendor ~= nil and Store.Vendors[vendor] or nil
		if vendor ~= nil then
			if not seller or not seller.Sells(player, id) then
				return
			end
		elseif not table.find(Config.ShopOrder or Config.ItemOrder, id) then
			return -- (food is only sold where the food is)
		end
		local have = itemCount(player, id)
		local price = item.Price or 5
		local reason
		if Store.GetBucks(player) < price then
			reason = (seller and seller.Broke) or ("Not enough " .. CURRENCY .. " (KOs pay " .. (ECON.PerKO or 5) .. ")")
		elseif not seller and have == 0 and kindsHeld(player) >= (ECON.MaxKinds or 4) then
			reason = "Your bag is full: use something up first"
		elseif not seller and have >= MAX_STACK then
			reason = "You can't carry any more " .. item.Name
		end
		if reason then
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Item = id, Text = reason })
			return
		end
		setBucks(player, Store.GetBucks(player) - price)
		local bagged = true
		if seller then
			bagged = Store.GiveOrEat(player, id)
			seller.Sold(player, id)
		else
			setItem(player, id, have + (item.Gives or 1))
		end
		PlayVFX:FireClient(player, "ShopResult", nil, { Ok = true, Item = id, Ate = not bagged or nil })
	end

	local function use(player, id, aimDir, aimPos)
		local item = ITEMS[id]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not alive(char) or itemCount(player, id) <= 0 then
			return
		end
		if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Frozen") or char:GetAttribute("Kaiju")
			or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished") then
			return
		end
		local now = os.clock()
		if now - (lastUse[player] or -math.huge) < (ECON.UseCooldown or 0.5) - COOLDOWN_TOLERANCE then
			return
		end
		lastUse[player] = now
		if id ~= "Sniper" and scoped[player] then
			setScope(player, char, false)
		end
		local dir = sanitizeDir(aimDir, root)
		local pos = sanitizePos(aimPos, root, dir)
		local handler = ItemUse[id]
		if handler then
			if handler(player, char, root, item, dir, pos) == false then
				return
			end
		elseif item.Heal then
			Store.Eat(player, id)
		else
			return
		end
		setItem(player, id, itemCount(player, id) - 1)
	end

	ShopRemote.OnServerEvent:Connect(function(player, action, a, b, c)
		if action == "Buy" and type(a) == "string" and ITEMS[a] and (b == nil or type(b) == "string") then
			buy(player, a, b)
		elseif action == "Use" and type(a) == "string" and ITEMS[a] then
			use(player, a, b, c)
		elseif action == "Fire" then
			fireSniper(player, a, b)
		elseif action == "Unscope" and scoped[player] then
			setScope(player, player.Character, false)
		elseif action == "RollEmotes" and type(a) == "number" then
			Store.RollEmotes(player, a) -- (round 63: a random one you don't have, JJS-style)
		elseif action == "PickEmote" and type(a) == "string" then
			Store.PickEmote(player, a)
		elseif action == "Deliver" and (a == "Soda" or a == "Item") then
			Store.Deliver(player, a)
		elseif action == "Redeem" and type(a) == "string" and #a <= 40 then
			Store.Redeem(player, a)
		elseif action == "EquipEmote" and type(a) == "number" and type(b) == "string" then
			Store.EquipEmote(player, a, b)
		elseif action == "AwakenOutfit" and type(a) == "number" then
			Store.PickOutfit(player, a) -- (round 59: 0 = none)
		end
	end)
end
setupStore()

---------------------------------------------------------------------------
-- UNO at Tony's (Config.Uno). Every table in the pizzeria gets a seat by
-- each of its chairs; sit down and the table plays: the server runs the
-- game (the deck, whose turn, what's allowed) and tells each player what
-- they can see - their own hand, everyone's card counts, the pile. The
-- table itself shows it too: the discard pile face up on it, the deck,
-- everyone's cards face down in front of them, whose turn it is.
-- (In a function of its own: the main chunk is near Luau's local limit.)
---------------------------------------------------------------------------
local function setupUno()
	local U = Config.Uno or {}
	if U.Enabled == false then
		return
	end
	local UnoRemote = Remotes:FindFirstChild("Uno") or Instance.new("RemoteEvent")
	UnoRemote.Name = "Uno"
	UnoRemote.Parent = Remotes
	local COLORS = { "R", "Y", "G", "B" }
	local SHOW = {
		R = Color3.fromRGB(226, 52, 52), Y = Color3.fromRGB(246, 200, 44), G = Color3.fromRGB(60, 172, 84), B = Color3.fromRGB(40, 112, 222), W = Color3.fromRGB(28, 28, 34),
	}
	local NAMES = { R = "RED", Y = "YELLOW", G = "GREEN", B = "BLUE" }
	local tables = {}
	local seatedAt = setmetatable({}, { __mode = "k" }) -- [player] = { table, seat index }
	local lastAction = setmetatable({}, { __mode = "k" })
	Kit.uno = { tables = tables, seatedAt = seatedAt }

	-- cards are strings: a colour letter and a value - "R7", "GS" (skip),
	-- "BR" (reverse), "YD" (draw two), and the wilds "WW" and "WF" (draw four)
	local function colorOf(card)
		return string.sub(card, 1, 1)
	end
	local function valueOf(card)
		return string.sub(card, 2)
	end
	local function isWild(card)
		return colorOf(card) == "W"
	end
	local function playable(card, top, color)
		return isWild(card) or colorOf(card) == color or valueOf(card) == valueOf(top)
	end
	local function describe(card, color)
		local v = valueOf(card)
		if card == "WW" then
			return "a WILD (" .. (NAMES[color] or "?") .. ")"
		elseif card == "WF" then
			return "a WILD DRAW FOUR (" .. (NAMES[color] or "?") .. ")"
		end
		local what = ({ S = "SKIP", R = "REVERSE", D = "DRAW TWO" })[v] or v
		return (NAMES[colorOf(card)] or "") .. " " .. what
	end
	local function shuffle(list)
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	local function newDeck()
		local deck = {}
		for _, c in COLORS do
			table.insert(deck, c .. "0")
			for _, v in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "S", "R", "D" } do
				table.insert(deck, c .. v)
				table.insert(deck, c .. v)
			end
		end
		for _ = 1, 4 do
			table.insert(deck, "WW")
			table.insert(deck, "WF")
		end
		shuffle(deck)
		return deck
	end

	---------------------------------------------------------------------------
	-- the tables: the pizzeria's, found on the map, a Seat by each chair
	---------------------------------------------------------------------------
	local function bounds(model)
		local lo, hi
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local c, h = p.Position, p.Size / 2
				local a, b = c - h, c + h
				lo = lo and Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
				hi = hi and Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
			end
		end
		return lo, hi
	end

	-- where you actually sit on a chair: the top of its widest flat part at
	-- sitting height (the seat board, the cushion, the stool's top) - not the
	-- top of the whole chair, which is the backrest (you'd float up there)
	local function sittingSpot(model, lo)
		local parts, widest = {}, 0
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				-- (its box in the world, turned however it's turned)
				local r, h = p.CFrame, p.Size / 2
				local ext = Vector3.new(
					math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
					math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
					math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z
				)
				local top = r.Position.Y + ext.Y
				if top - lo.Y > 0.6 and top - lo.Y < 3.4 then
					local area = ext.X * ext.Z * 4
					table.insert(parts, { top = top, area = area, at = r.Position })
					widest = math.max(widest, area)
				end
			end
		end
		local best
		for _, c in parts do
			if c.area >= widest * 0.8 and (not best or c.top > best.top) then
				best = c
			end
		end
		return best and Vector3.new(best.at.X, best.top, best.at.Z) or nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "UnoTables"
	folder.Parent = workspace

	local function part(name, size, cf, color, material, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	-- a card lying face up on the table: its colour, the white oval, the value
	local function faceGui(p, card, color)
		local gui = p:FindFirstChild("Face") or Instance.new("SurfaceGui")
		gui.Name = "Face"
		gui.Face = Enum.NormalId.Top
		gui.CanvasSize = Vector2.new(130, 190)
		gui.LightInfluence = 0.2
		gui.Parent = p
		local bg = gui:FindFirstChild("Card") or Instance.new("Frame")
		bg.Name = "Card"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local label = bg:FindFirstChild("Value") or Instance.new("TextLabel")
		label.Name = "Value"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Parent = bg
		if card then
			local v = valueOf(card)
			bg.BackgroundColor3 = SHOW[isWild(card) and (color or "W") or colorOf(card)] or SHOW.W
			label.Text = card == "WW" and "W" or card == "WF" and "+4" or ({ S = "⊘", R = "⇄", D = "+2" })[v] or v
		else
			bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
			label.Text = "UNO"
			label.TextColor3 = Color3.fromRGB(246, 200, 44)
		end
	end

	local function buildTable(model, seatModels)
		local lo, hi = bounds(model)
		if not lo then
			return
		end
		local center = (lo + hi) / 2
		local T = { id = #tables + 1, model = model, center = Vector3.new(center.X, hi.Y, center.Z), seats = {}, game = nil, startAt = nil }
		T.folder = Instance.new("Folder")
		T.folder.Name = "Table" .. T.id
		T.folder.Parent = folder
		for _, sm in seatModels do
			local slo, shi = bounds(sm)
			if slo then
				local sc = (slo + shi) / 2
				local at = sittingSpot(sm, slo) or Vector3.new(sc.X, shi.Y + 0.15, sc.Z)
				local look = Vector3.new(T.center.X - at.X, 0, T.center.Z - at.Z)
				local seat = Instance.new("Seat")
				seat.Name = "UnoSeat"
				seat.Size = Vector3.new(2, 0.3, 2)
				seat.CFrame = CFrame.lookAt(at, at + (look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)))
				seat.Anchored = true
				seat.CanCollide = false
				seat.CanTouch = false -- (you sit with the prompt, not by walking into it)
				seat.Transparency = 1
				seat.Parent = T.folder
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "PlayUno"
				prompt.ActionText = "Play UNO"
				prompt.ObjectText = "Tony's table"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 8
				prompt.RequiresLineOfSight = false
				prompt.Parent = seat
				-- (face down in front of him: his cards, as many as he holds, up to 7)
				local edge = T.center + (at - T.center) * Vector3.new(1, 0, 1) * 0.55
				local tag = Instance.new("BillboardGui")
				tag.Name = "Count"
				tag.Size = UDim2.fromOffset(120, 34)
				tag.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
				tag.AlwaysOnTop = true
				tag.MaxDistance = 60
				tag.Enabled = false
				local tagText = Instance.new("TextLabel")
				tagText.Name = "Text"
				tagText.Size = UDim2.fromScale(1, 1)
				tagText.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
				tagText.BackgroundTransparency = 0.25
				tagText.Font = Enum.Font.GothamBlack
				tagText.TextScaled = true
				tagText.TextColor3 = Color3.new(1, 1, 1)
				tagText.Parent = tag
				local anchorPart = part("CountAnchor", Vector3.one * 0.2, CFrame.new(edge + Vector3.new(0, 0.4, 0)), Color3.new(), nil, T.folder)
				anchorPart.Transparency = 1
				tag.Parent = anchorPart
				local S = { seat = seat, prompt = prompt, pos = at, edge = edge, tag = tag, tagText = tagText, cards = {} }
				table.insert(T.seats, S)
				local index = #T.seats
				prompt.Triggered:Connect(function(player)
					local char = player.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health <= 0 or seat.Occupant or seatedAt[player] then
						return
					end
					if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed")
						or (char:GetAttribute("CombatActionUntil") or 0) > workspace:GetServerTimeNow() then
						return
					end
					pcall(function()
						seat:Sit(hum)
					end)
				end)
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					local hum = seat.Occupant
					local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
					if player and not S.player then
						Kit.uno.join(T, index, player)
					elseif not player and S.player then
						Kit.uno.leave(T, S.player)
					end
				end)
			end
		end
		-- the pile and the deck, lying on the table (hidden until a game)
		local top = T.center + Vector3.new(0, 0.03, 0)
		T.discard = part("Discard", Vector3.new(1.3, 0.05, 1.9), CFrame.new(top + Vector3.new(0.9, 0, 0)), Color3.new(1, 1, 1), nil, T.folder)
		T.deckPart = part("Deck", Vector3.new(1.3, 0.4, 1.9), CFrame.new(top + Vector3.new(-0.9, 0.18, 0)), Color3.fromRGB(20, 20, 24), nil, T.folder)
		T.ring = part("ColorRing", Vector3.new(0.04, 2.6, 2.6), CFrame.new(top + Vector3.new(0.9, -0.01, 0)) * CFrame.Angles(0, 0, math.rad(90)), SHOW.R, Enum.Material.Neon, T.folder)
		T.ring.Shape = Enum.PartType.Cylinder
		faceGui(T.deckPart, nil)
		for _, p in { T.discard, T.deckPart, T.ring } do
			p.Transparency = 1
		end
		table.insert(tables, T)
		return T
	end

	local function findTables()
		local map = workspace:FindFirstChild("Map")
		local tony = (Config.PizzaParlor and Config.PizzaParlor.Position) or Vector3.zero
		if not map then
			return
		end
		local tableModels, seatModels = {}, {}
		for _, d in map:GetDescendants() do
			if d:IsA("Model") and (d.Name == "Table" or d.Name == "Big Seat" or d.Name == "Chair" or d.Name == "Seat") then
				local lo, hi = bounds(d)
				if lo and ((lo + hi) / 2 - tony).Magnitude <= (U.Range or 110) then
					table.insert(d.Name == "Table" and tableModels or seatModels, { model = d, center = (lo + hi) / 2 })
				end
			end
		end
		-- each seat goes to the table it's closest to (if it's close enough)
		local groups = {}
		for _, s in seatModels do
			local best, bestD
			for i, t in tableModels do
				local dist = Vector3.new(s.center.X - t.center.X, 0, s.center.Z - t.center.Z).Magnitude
				if dist <= (U.SeatRange or 9) and (not bestD or dist < bestD) then
					best, bestD = i, dist
				end
			end
			if best then
				groups[best] = groups[best] or {}
				if #groups[best] < (U.MaxPlayers or 4) then
					table.insert(groups[best], s.model)
				end
			end
		end
		for i, t in tableModels do
			if groups[i] and #groups[i] >= 2 then
				buildTable(t.model, groups[i])
			end
		end
	end

	---------------------------------------------------------------------------
	-- telling everyone at a table what they can see
	---------------------------------------------------------------------------
	local function atTable(T)
		local out = {}
		for _, S in T.seats do
			if S.player then
				table.insert(out, S.player)
			end
		end
		return out
	end

	local function toast(T, text, color)
		for _, p in atTable(T) do
			UnoRemote:FireClient(p, "Toast", text, color)
		end
	end

	-- the table itself: pile face up, the colour ring, the cards in front
	-- of everyone, whose turn
	local function showTable(T)
		local G = T.game
		local live = G ~= nil
		T.discard.Transparency = live and 0 or 1
		T.deckPart.Transparency = live and 0 or 1
		T.ring.Transparency = live and 0.35 or 1
		if live then
			local top = G.discard[#G.discard]
			faceGui(T.discard, top, G.color)
			T.ring.Color = SHOW[G.color] or SHOW.W
		end
		local face = T.discard:FindFirstChild("Face")
		if face then
			face.Enabled = live
		end
		local deckFace = T.deckPart:FindFirstChild("Face")
		if deckFace then
			deckFace.Enabled = live
		end
		for _, S in T.seats do
			local count = live and S.player and G.hands[S.player] and #G.hands[S.player] or 0
			S.prompt.Enabled = S.player == nil
			S.tag.Enabled = live and S.player ~= nil
			if S.tag.Enabled then
				local turn = G.order[G.turn] == S.player
				S.tagText.Text = (turn and "▶ " or "") .. count .. (count == 1 and " CARD" or " CARDS") .. (G.safe[S.player] and count <= 1 and "  UNO!" or "")
				S.tagText.TextColor3 = turn and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1)
			end
			-- the fan of face-down cards
			local want = math.min(count, 7)
			while #S.cards < want do
				local p = part("Card", Vector3.new(0.9, 0.04, 1.3), CFrame.new(), Color3.fromRGB(20, 20, 24), nil, T.folder)
				table.insert(S.cards, p)
			end
			while #S.cards > want do
				table.remove(S.cards):Destroy()
			end
			local toward = (T.center - S.edge) * Vector3.new(1, 0, 1)
			local base = CFrame.lookAt(S.edge, S.edge + (toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)))
			for i, p in S.cards do
				local k = i - (want + 1) / 2
				p.CFrame = base * CFrame.new(k * 0.32, 0.03 + i * 0.01, 0) * CFrame.Angles(0, math.rad(k * 9), 0)
				p.Color = i % 2 == 0 and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(196, 32, 38)
			end
		end
	end

	local function sendState(T)
		local G = T.game
		local seated = atTable(T)
		for _, p in seated do
			local state = { Table = T.id, Phase = G and "Game" or "Lobby", Seated = {} }
			for _, q in seated do
				table.insert(state.Seated, q.DisplayName)
			end
			if T.startAt then
				state.StartIn = math.max(0, math.ceil(T.startAt - os.clock()))
			end
			if G then
				state.Players = {}
				local catchable = false
				for i, q in G.order do
					local n = #G.hands[q]
					local exposed = n == 1 and not G.safe[q]
					table.insert(state.Players, { Name = q.DisplayName, UserId = q.UserId, Count = n, Uno = G.safe[q] == true and n <= 2, Turn = i == G.turn, Exposed = exposed })
					if q ~= p and exposed then
						catchable = true
					end
				end
				state.Hand = table.clone(G.hands[p] or {})
				state.Top = G.discard[#G.discard]
				state.Color = G.color
				state.Dir = G.dir
				state.MyTurn = G.order[G.turn] == p
				state.Drawn = G.order[G.turn] == p and G.drawn or nil
				state.TurnEnds = G.turnEnds and (workspace:GetServerTimeNow() + (G.turnEnds - os.clock())) or nil
				state.TurnTime = U.TurnTime or 20
				state.CanCatch = catchable
				state.CanUno = #(G.hands[p] or {}) <= 2 and not G.safe[p]
				state.Deck = #G.deck
			end
			UnoRemote:FireClient(p, "State", state)
		end
		showTable(T)
	end

	---------------------------------------------------------------------------
	-- the game
	---------------------------------------------------------------------------
	local function drawCard(G)
		if #G.deck == 0 then
			-- (the deck's out: the pile, bar its top card, shuffled back in)
			local top = table.remove(G.discard)
			G.deck = G.discard
			G.discard = { top }
			shuffle(G.deck)
		end
		return table.remove(G.deck)
	end

	local function give(G, p, n)
		local hand = G.hands[p]
		for _ = 1, n do
			local card = drawCard(G)
			if card then
				table.insert(hand, card)
			end
		end
		G.safe[p] = nil
	end

	local function step(G)
		G.turn = ((G.turn - 1 + G.dir) % #G.order) + 1
	end

	local function nextPlayer(G)
		return G.order[((G.turn - 1 + G.dir) % #G.order) + 1]
	end

	local function startTurn(T)
		local G = T.game
		G.drawn = nil
		G.turnEnds = os.clock() + (U.TurnTime or 20)
		sendState(T)
	end

	local function endGame(T, winner, text)
		local G = T.game
		if not G then
			return
		end
		T.game = nil
		for _, p in G.order do
			local char = p.Character
			if char and p.Parent then
				UnoRemote:FireClient(p, "End", { Winner = winner and winner.DisplayName, You = p == winner })
			end
		end
		if winner then
			toast(T, text or (winner.DisplayName .. " WINS!"), Color3.fromRGB(255, 212, 64))
			if Store.AddBucks and (U.WinBucks or 0) > 0 then
				Store.AddBucks(winner, U.WinBucks)
			end
		elseif text then
			toast(T, text)
		end
		T.startAt = #atTable(T) >= 2 and os.clock() + (U.NextRound or 8) or nil
		sendState(T)
	end

	function Kit.uno.start(T)
		if T.game then
			return
		end
		local order = atTable(T)
		if #order < 2 then
			return
		end
		local G = { order = order, hands = {}, deck = newDeck(), discard = {}, color = "R", turn = math.random(1, #order), dir = 1, safe = {} }
		T.game = G
		T.startAt = nil
		for _, p in order do
			G.hands[p] = {}
			give(G, p, U.HandSize or 7)
		end
		-- the first card up is a number (anything else goes back in)
		local first = drawCard(G)
		while first and not string.match(valueOf(first), "^%d$") do
			table.insert(G.deck, 1, first)
			first = drawCard(G)
		end
		G.discard = { first }
		G.color = colorOf(first)
		toast(T, "UNO! " .. order[G.turn].DisplayName .. " goes first", Color3.fromRGB(255, 212, 64))
		startTurn(T)
	end

	local function play(T, p, index, color)
		local G = T.game
		if G.order[G.turn] ~= p then
			return
		end
		local hand = G.hands[p]
		local card = hand[index]
		local top = G.discard[#G.discard]
		if not card or (G.drawn and index ~= G.drawn) or not playable(card, top, G.color) then
			return
		end
		if isWild(card) and not table.find(COLORS, color) then
			return
		end
		table.remove(hand, index)
		table.insert(G.discard, card)
		G.color = isWild(card) and color or colorOf(card)
		G.drawn = nil
		if #hand > 1 then
			G.safe[p] = nil
		end
		toast(T, p.DisplayName .. " played " .. describe(card, G.color), SHOW[G.color])
		if #hand == 0 then
			endGame(T, p)
			return
		end
		local v = valueOf(card)
		if v == "R" then
			G.dir = -G.dir
			if #G.order == 2 then
				step(G) -- (two players: a reverse is a skip)
			end
		elseif v == "S" then
			step(G)
		elseif v == "D" or v == "F" then
			local victim = nextPlayer(G)
			give(G, victim, v == "D" and 2 or 4)
			toast(T, victim.DisplayName .. " draws " .. (v == "D" and 2 or 4) .. "!")
			step(G)
		end
		step(G)
		startTurn(T)
	end

	local function draw(T, p)
		local G = T.game
		if G.order[G.turn] ~= p or G.drawn then
			return
		end
		local card = drawCard(G)
		if not card then
			step(G)
			startTurn(T)
			return
		end
		local hand = G.hands[p]
		table.insert(hand, card)
		G.safe[p] = nil
		if playable(card, G.discard[#G.discard], G.color) then
			G.drawn = #hand -- (they can play it, or pass)
			sendState(T)
		else
			step(G)
			startTurn(T)
		end
	end

	local function pass(T, p)
		local G = T.game
		if G.order[G.turn] ~= p or not G.drawn then
			return
		end
		step(G)
		startTurn(T)
	end

	local function callUno(T, p)
		local G = T.game
		local hand = G.hands[p]
		if hand and #hand <= 2 and not G.safe[p] then
			G.safe[p] = true
			toast(T, p.DisplayName .. ": UNO!", Color3.fromRGB(255, 212, 64))
			sendState(T)
		end
	end

	local function catch(T, catcher)
		local G = T.game
		local caught = false
		for _, q in G.order do
			if q ~= catcher and #G.hands[q] == 1 and not G.safe[q] then
				give(G, q, U.CatchPenalty or 2)
				toast(T, catcher.DisplayName .. " caught " .. q.DisplayName .. " - draw " .. (U.CatchPenalty or 2) .. "!", Color3.fromRGB(255, 120, 90))
				caught = true
			end
		end
		if caught then
			sendState(T)
		end
	end

	-- someone sits down: they're at the table (in the next deal)
	function Kit.uno.join(T, index, player)
		local S = T.seats[index]
		if seatedAt[player] then
			return
		end
		S.player = player
		seatedAt[player] = { T = T, index = index }
		if player.Character then
			player.Character:SetAttribute("PlayingUno", true)
		end
		toast(T, player.DisplayName .. " sat down")
		if not T.game and #atTable(T) >= 2 and not T.startAt then
			T.startAt = os.clock() + (U.AutoStart or 10)
		end
		sendState(T)
	end

	-- someone gets up (or goes): their cards go back in the deck
	function Kit.uno.leave(T, player)
		local at = seatedAt[player]
		if not at or at.T ~= T then
			return
		end
		seatedAt[player] = nil
		T.seats[at.index].player = nil
		local char = player.Character
		if char then
			char:SetAttribute("PlayingUno", nil)
		end
		if player.Parent then
			UnoRemote:FireClient(player, "Closed")
		end
		local G = T.game
		if G then
			local i = table.find(G.order, player)
			if i then
				for _, card in G.hands[player] or {} do
					table.insert(G.deck, 1, card)
				end
				G.hands[player] = nil
				local wasTurn = G.turn == i
				table.remove(G.order, i)
				if i < G.turn then
					G.turn -= 1
				end
				if #G.order < 2 then
					endGame(T, G.order[1], G.order[1] and (G.order[1].DisplayName .. " wins - everyone else left") or nil)
					return
				end
				if G.turn > #G.order then
					G.turn = 1
				end
				toast(T, player.DisplayName .. " left the table")
				if wasTurn then
					startTurn(T)
					return
				end
			end
		end
		if #atTable(T) < 2 then
			T.startAt = nil
		end
		sendState(T)
	end

	-- (the test menu: set your hand, the card on the pile, or make it your go)
	function Kit.uno.rig(player, what, value)
		local at = seatedAt[player]
		local G = at and at.T.game
		if not G or not G.hands[player] or type(value) ~= "string" then
			return
		end
		if what == "Hand" then
			local hand = {}
			for card in string.gmatch(value, "[^,%s]+") do
				table.insert(hand, card)
			end
			G.hands[player] = hand
		elseif what == "Top" then
			table.insert(G.discard, value)
			G.color = isWild(value) and "R" or colorOf(value)
		elseif what == "Turn" then
			G.turn = table.find(G.order, player) or G.turn
		end
		startTurn(at.T)
	end

	UnoRemote.OnServerEvent:Connect(function(player, action, a, b)
		local at = seatedAt[player]
		if not at or type(action) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.12 then
			return
		end
		lastAction[player] = now
		local T = at.T
		if action == "Start" then
			Kit.uno.start(T)
			return
		elseif action == "Leave" then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = false
			end
			Kit.uno.leave(T, player)
			return
		end
		if not T.game or not T.game.hands[player] then
			return
		end
		if action == "Play" and type(a) == "number" then
			play(T, player, math.floor(a), b)
		elseif action == "Draw" then
			draw(T, player)
		elseif action == "Pass" then
			pass(T, player)
		elseif action == "Uno" then
			callUno(T, player)
		elseif action == "Catch" then
			catch(T, player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local at = seatedAt[player]
		if at then
			Kit.uno.leave(at.T, player)
		end
	end)

	-- the clock: deals that are due, turns that ran out (they draw, and pass)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, T in tables do
				local G = T.game
				if G then
					if G.turnEnds and now > G.turnEnds then
						local p = G.order[G.turn]
						if G.drawn then
							pass(T, p)
						else
							draw(T, p)
							if T.game == G and G.drawn and G.order[G.turn] == p then
								pass(T, p)
							end
						end
					end
				elseif T.startAt then
					if #atTable(T) < 2 then
						T.startAt = nil
						sendState(T)
					elseif now >= T.startAt then
						Kit.uno.start(T)
					end
				end
			end
		end
	end)

	findTables()
end
task.spawn(setupUno)

---------------------------------------------------------------------------
-- Food around the city: snack machines on the sidewalks (buy one, or punch
-- one for a free snack) and Tony behind the diner's counter. All of it is
-- built when the server starts, in workspace.Shops (attacks pass through it
-- and the map's destruction leaves it alone).
---------------------------------------------------------------------------

local function setupFood()
	local ITEMS = Config.Items or {}
	local MACHINE = Config.SnackMachine or {}
	local PIZZA = Config.PizzaParlor or {}
	local shops = workspace:FindFirstChild("Shops") or Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = workspace
	local lastPrompt = {} -- [player] = os.clock(): one purchase per press, however the prompt fired
	local machines = {} -- { Model, Body, Base (CFrame at its feet, facing out), RestockAt }

	local function busyPrompt(player)
		local now = os.clock()
		if now - (lastPrompt[player] or -math.huge) < 0.5 then
			return true
		end
		lastPrompt[player] = now
		return false
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
	end)

	local function block(parent, size, cf, color, material, collide)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = collide == true
		p.CanTouch = false
		p.CastShadow = collide == true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	local function label(part, face, text, color, bg, font)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = part
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = bg or Color3.new(0, 0, 0)
		t.BackgroundTransparency = bg and 0 or 1
		t.TextScaled = true
		t.Font = font or Enum.Font.Bangers
		t.TextColor3 = color
		t.Text = text
		t.Parent = gui
		return t
	end

	local function prompt(parent, action, object, range)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = action
		pp.ObjectText = object
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.GamepadKeyCode = Enum.KeyCode.DPadRight
		pp.HoldDuration = 0
		pp.MaxActivationDistance = range or 8
		pp.RequiresLineOfSight = false
		pp.Parent = parent
		return pp
	end

	---------------------------------------------------------------------------
	-- Snack machines
	---------------------------------------------------------------------------

	local MACHINE_RED = Color3.fromRGB(200, 36, 44)
	local TRIM = Color3.fromRGB(245, 245, 250)
	local SNACK_COLORS = {
		Color3.fromRGB(240, 190, 60), Color3.fromRGB(120, 70, 40), Color3.fromRGB(70, 200, 255),
		Color3.fromRGB(230, 70, 90), Color3.fromRGB(110, 200, 90), Color3.fromRGB(255, 140, 40),
	}

	local function buildMachine(spot, index)
		local face = Vector3.new(spot.Face.X, 0, spot.Face.Z).Unit
		local base = CFrame.lookAt(spot.Position, spot.Position + face)
		local m = Instance.new("Model")
		m.Name = "SnackMachine"
		m:SetAttribute("Machine", index)
		local body = block(m, Vector3.new(4, 6.4, 3), base * CFrame.new(0, 3.2, 0), MACHINE_RED, Enum.Material.SmoothPlastic, true)
		body.Name = "Body"
		m.PrimaryPart = body
		-- the lit header: SNACKS
		local header = block(m, Vector3.new(4.1, 1.2, 3.1), base * CFrame.new(0, 7, 0), TRIM, Enum.Material.SmoothPlastic, true)
		label(header, Enum.NormalId.Front, "SNACKS", MACHINE_RED)
		-- the window full of snacks on four shelves
		local glassCf = base * CFrame.new(-0.5, 4.1, -1.53)
		block(m, Vector3.new(2.7, 4.3, 0.06), glassCf * CFrame.new(0, 0, 0.3), Color3.fromRGB(30, 30, 38))
		for row = 0, 3 do
			local y = -1.7 + row * 1.08
			block(m, Vector3.new(2.6, 0.08, 0.35), glassCf * CFrame.new(0, y, 0.12), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
			for col = 0, 3 do
				local c = SNACK_COLORS[(row * 4 + col + index) % #SNACK_COLORS + 1]
				block(m, Vector3.new(0.5, 0.7, 0.18), glassCf * CFrame.new(-0.97 + col * 0.65, y + 0.4, 0.12), c)
			end
		end
		local glass = block(m, Vector3.new(2.8, 4.4, 0.05), glassCf, Color3.fromRGB(190, 225, 255), Enum.Material.Glass)
		glass.Transparency = 0.55
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = glass
		-- keypad, price and coin slot
		local pad = block(m, Vector3.new(0.85, 2.2, 0.06), base * CFrame.new(1.45, 4.5, -1.52), Color3.fromRGB(40, 40, 48))
		label(pad, Enum.NormalId.Front, (MACHINE.Price or 3) .. "$", Color3.fromRGB(120, 255, 140), Color3.fromRGB(10, 20, 10), Enum.Font.Code)
		block(m, Vector3.new(0.3, 0.5, 0.06), base * CFrame.new(1.45, 3.1, -1.53), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
		-- the flap at the bottom the snacks drop out of
		block(m, Vector3.new(2.7, 0.75, 0.06), base * CFrame.new(-0.5, 1.05, -1.53), Color3.fromRGB(20, 20, 24))
		block(m, Vector3.new(4.1, 0.3, 3.1), base * CFrame.new(0, 0.15, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, true)
		local pp = prompt(body, "Buy a snack", string.format("Snack Machine · %d Bucks", MACHINE.Price or 3), 8)
		m.Parent = shops
		local entry = { Model = m, Body = body, Base = base, RestockAt = 0 }
		table.insert(machines, entry)
		pp.Triggered:Connect(function(player)
			if busyPrompt(player) then
				return
			end
			local snacks = MACHINE.Snacks or { "Chips" }
			local id = snacks[math.random(1, #snacks)]
			if not Store.Spend(player, MACHINE.Price or 3) then
				PlayVFX:FireClient(player, "ShopResult", nil, { Ok = false, Text = "Not enough Bucks for a snack (KOs pay " .. ((Config.Economy and Config.Economy.PerKO) or 5) .. ")" })
				return
			end
			local bagged = Store.GiveOrEat(player, id)
			broadcast("Vend", nil, { Machine = m, Item = id })
			PlayVFX:FireClient(player, "ShopResult", nil, { Ok = true, Item = id, Ate = not bagged or nil })
		end)
	end

	-- a free snack pops out onto the pavement a few steps in front (every
	-- client flies it there); after a moment, the first one to walk over it eats it
	local function dropSnack(entry)
		local snacks = MACHINE.Snacks or { "Chips" }
		local id = snacks[math.random(1, #snacks)]
		local item = ITEMS[id]
		local spot = entry.Base * CFrame.new(math.random(-20, 20) / 10, 0.5, -math.random(75, 90) / 10)
		local snack = block(shops, Vector3.new(0.9, 0.9, 0.9), spot, item.Color or TRIM, Enum.Material.SmoothPlastic)
		snack.Name = "FreeSnack"
		snack.Transparency = 1
		snack:SetAttribute("Item", id)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(44, 44)
		bb.StudsOffset = Vector3.new(0, 1.4, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 80
		bb.Parent = snack
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.TextScaled = true
		icon.Text = item.Icon or "?"
		icon.Parent = bb
		broadcast("SnackDrop", nil, { Machine = entry.Model, Pos = spot.Position, Item = id })
		task.spawn(function()
			task.wait(0.4) -- (in the air)
			snack.Transparency = 0
			task.wait(0.15)
			local t0 = os.clock()
			while snack.Parent and os.clock() - t0 < (MACHINE.PickupLife or 20) do
				for _, plr in Players:GetPlayers() do
					local char = plr.Character
					local r = char and char:FindFirstChild("HumanoidRootPart")
					if r and alive(char) then
						local off = r.Position - snack.Position
						if Vector3.new(off.X, 0, off.Z).Magnitude < 2.6 and math.abs(off.Y) < 5 then
							Store.Eat(plr, id)
							snack:Destroy()
							break
						end
					end
				end
				task.wait(0.1)
			end
			if snack.Parent then
				snack:Destroy()
			end
		end)
	end

	-- the M1 landed around `point`: any machine there rattles, and drops a
	-- free snack if it's stocked
	function Store.PunchMachine(point)
		for _, entry in machines do
			local c = entry.Body.Position
			local flat = Vector3.new(point.X - c.X, 0, point.Z - c.Z).Magnitude
			if flat < 4.2 and math.abs(point.Y - c.Y) < 5 then
				broadcast("MachineHit", nil, { Machine = entry.Model })
				if os.clock() >= entry.RestockAt then
					entry.RestockAt = os.clock() + (MACHINE.Restock or 30)
					dropSnack(entry)
				end
			end
		end
	end

	for i, spot in MACHINE.Spots or {} do
		local ok, err = pcall(buildMachine, spot, i)
		if not ok then
			warn("[Food] snack machine " .. i .. ": " .. tostring(err))
		end
	end

	---------------------------------------------------------------------------
	-- Tony's Pizzeria
	---------------------------------------------------------------------------

	if PIZZA.Enabled == false or not PIZZA.Position then
		return
	end
	local SKIN = Color3.fromRGB(234, 184, 146)
	local WHITE = Color3.fromRGB(246, 246, 246)
	local R6_JOINTS = {
		-- name, part1, C0, C1 (Roblox's stock R6 rig)
		{ "Neck", "Head", CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)), CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)) },
		{ "Right Shoulder", "Right Arm", CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0) },
		{ "Left Shoulder", "Left Arm", CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0) },
		{ "Right Hip", "Right Leg", CFrame.new(1, -1, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0) },
		{ "Left Hip", "Left Leg", CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, math.rad(-90), 0) },
	}

	local function buildTony()
		local face = Vector3.new(PIZZA.Face.X, 0, PIZZA.Face.Z).Unit
		local feet = PIZZA.Position
		local rootCf = CFrame.lookAt(feet + UP * 3, feet + UP * 3 + face)
		local tony = Instance.new("Model")
		tony.Name = PIZZA.Cook or "Tony"
		tony:SetAttribute("Shopkeeper", true)
		local function limb(name, size, offset, color)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = rootCf * offset
			p.Color = color
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = tony
			return p
		end
		local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), SKIN)
		root.Transparency = 1
		root.Anchored = true
		local torso = limb("Torso", Vector3.new(2, 2, 1), CFrame.new(), WHITE)
		local head = limb("Head", Vector3.new(2, 1, 1), CFrame.new(0, 1.5, 0), SKIN)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = head
		local faceDecal = Instance.new("Decal")
		faceDecal.Name = "face"
		faceDecal.Texture = "rbxasset://textures/face.png"
		faceDecal.Parent = head
		limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0), WHITE)
		limb("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), WHITE)
		limb("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0), Color3.fromRGB(52, 52, 60))
		limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0), Color3.fromRGB(52, 52, 60))
		local rootJoint = Instance.new("Motor6D")
		rootJoint.Name = "RootJoint"
		rootJoint.Part0 = root
		rootJoint.Part1 = torso
		rootJoint.C0 = CFrame.Angles(math.rad(-90), 0, math.rad(180))
		rootJoint.C1 = CFrame.Angles(math.rad(-90), 0, math.rad(180))
		rootJoint.Parent = root
		for _, j in R6_JOINTS do
			local m6 = Instance.new("Motor6D")
			m6.Name = j[1]
			m6.Part0 = torso
			m6.Part1 = tony:FindFirstChild(j[2])
			m6.C0 = j[3]
			m6.C1 = j[4]
			m6.Parent = torso
		end
		-- the chef's whites: hat, red neckerchief, apron, and a big moustache
		local gear = Instance.new("Model")
		gear.Name = "ChefGear"
		local hatBand = gearPart(gear, Vector3.new(1.1, 1.2, 1.2), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weld(head, hatBand, CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
		weld(head, ellipsoid(gear, Vector3.new(1.7, 1.1, 1.7), WHITE), CFrame.new(0, 1.65, 0))
		weld(torso, gearPart(gear, Vector3.new(1.2, 0.35, 1.05), Color3.fromRGB(200, 40, 40)), CFrame.new(0, 0.85, 0))
		weld(torso, gearPart(gear, Vector3.new(1.7, 2.6, 0.08), Color3.fromRGB(230, 230, 225)), CFrame.new(0, -0.7, -0.54))
		for _, side in { 1, -1 } do
			local tache = ellipsoid(gear, Vector3.new(0.5, 0.18, 0.2), Color3.fromRGB(60, 36, 22))
			weld(head, tache, CFrame.new(side * 0.22, -0.12, -0.6) * CFrame.Angles(0, 0, math.rad(side * -14)))
		end
		gear.Parent = tony
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.DisplayName = PIZZA.Cook or "Tony"
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance = 60
		hum.Parent = tony
		tony.PrimaryPart = root
		tony.Parent = shops
		return tony, root
	end

	local function buildDecor()
		-- the sign over the counter
		local signPos = PIZZA.SignPosition
		if signPos then
			local face = Vector3.new(PIZZA.Face.X, 0, PIZZA.Face.Z).Unit
			local sign = block(shops, Vector3.new(12, 2.2, 0.3), CFrame.lookAt(signPos, signPos + face), Color3.fromRGB(30, 110, 50))
			sign.Name = "PizzeriaSign"
			label(sign, Enum.NormalId.Front, "🍕 " .. (PIZZA.Name or "PIZZA") .. " 🍕", Color3.new(1, 1, 1), Color3.fromRGB(200, 40, 40))
		end
		-- a fresh pepperoni pie on the counter
		local at = PIZZA.PizzaOnCounter
		if at then
			local flat = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
			local crust = block(shops, Vector3.new(0.14, 2.4, 2.4), flat, Color3.fromRGB(222, 170, 90))
			crust.Shape = Enum.PartType.Cylinder
			local sauce = block(shops, Vector3.new(0.16, 2.05, 2.05), flat * CFrame.new(0.02, 0, 0), Color3.fromRGB(245, 205, 110))
			sauce.Shape = Enum.PartType.Cylinder
			for i = 1, 7 do
				local a = i / 7 * math.pi * 2
				local r = i == 7 and 0 or 0.6
				local pep = block(shops, Vector3.new(0.18, 0.4, 0.4), CFrame.new(at + Vector3.new(math.cos(a) * r, 0.02, math.sin(a) * r)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 40, 30))
				pep.Shape = Enum.PartType.Cylinder
			end
		end
	end

	local ok, tony, tonyRoot = pcall(buildTony)
	if not ok then
		warn("[Food] Tony: " .. tostring(tony))
		return
	end
	pcall(buildDecor)
	local function say(text)
		broadcast("NpcSay", nil, { Npc = tony, Text = text })
	end
	local function pick(list)
		return list and #list > 0 and list[math.random(1, #list)] or ""
	end
	local function nearTony(player)
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return r ~= nil and (r.Position - tonyRoot.Position).Magnitude <= (PIZZA.TalkRange or 14) + 4
	end
	Store.Vendors.Pizza = {
		Broke = PIZZA.Broke,
		Sells = function(player, id)
			return table.find(PIZZA.Menu or {}, id) ~= nil and nearTony(player)
		end,
		Sold = function()
			say(pick(PIZZA.Thanks))
		end,
	}
	local talk = prompt(tonyRoot, "Order food", (PIZZA.Cook or "Tony") .. " · " .. (PIZZA.Name or "Pizza"), PIZZA.TalkRange or 14)
	talk.Triggered:Connect(function(player)
		if busyPrompt(player) then
			return
		end
		local line = pick(PIZZA.Greetings)
		say(line)
		PlayVFX:FireClient(player, "VendorMenu", nil, { Vendor = "Pizza", Npc = tony, Line = line })
	end)
end
setupFood()


local DUMMY_AREA = CFrame.lookAt(Vector3.new(-77, 32, 668), Vector3.new(-77, 32, 651))

local TestCommands = {}

-- UNO: rig your own game (arg: "Hand:R5,WW" / "Top:R3" / "Turn:")
function TestCommands.UnoRig(player, _char, arg)
	local what, value = string.match(tostring(arg or ""), "^(%a+):(.*)$")
	if what and Kit.uno and Kit.uno.rig then
		Kit.uno.rig(player, what, value)
	end
end

function TestCommands.FillUlt(player)
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	if quirk and quirk.Ult and not player:GetAttribute("UltActive") then
		player:SetAttribute("Ult", 100)
	end
end

function TestCommands.EndUlt(player, char)
	if player:GetAttribute("UltActive") then
		endUlt(player, char, false)
	end
end

function TestCommands.ResetCooldowns(player)
	cooldowns[player] = {}
	recoverUntil[player] = nil
end

function TestCommands.Heal(_, char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
	end
end

function TestCommands.GodMode(player)
	player:SetAttribute("GodMode", not player:GetAttribute("GodMode"))
end

function TestCommands.NoCooldowns(player)
	player:SetAttribute("NoCooldowns", not player:GetAttribute("NoCooldowns"))
	cooldowns[player] = {}
	recoverUntil[player] = nil
end

local function dummyControl()
	local dummies = script.Parent:FindFirstChild("Dummies")
	return dummies and dummies:FindFirstChild("DummyControl")
end

-- kind: an Id from Config.DummyKinds (Normal, Finisher, Attack, Block, Moving, Tank, R6)
function TestCommands.SpawnDummy(_, char, kind)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local control = dummyControl()
	if type(kind) ~= "string" or not (Config.DummyKind and Config.DummyKind(kind)) then
		kind = "Normal"
	end
	if root and control then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local pos = root.Position + look * 12 + UP * 2
		control:Fire("Spawn", CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z)), kind)
	end
end

-- remove every dummy you spawned (the default row stays)
function TestCommands.ClearDummies()
	local control = dummyControl()
	if control then
		control:Fire("Clear")
	end
end

function TestCommands.ResetDummies()
	local control = dummyControl()
	if control then
		control:Fire("Reset")
	end
end

function TestCommands.RebuildMap()
	Destruction.RegenerateAll()
end

function TestCommands.Destruction()
	Destruction.SetEnabled(not workspace:GetAttribute("DestructionEnabled"))
end

function TestCommands.TeleportDummies(_, char)
	if char and char.Parent then
		char:PivotTo(DUMMY_AREA)
	end
end

function TestCommands.Respawn(player)
	player:LoadCharacter()
end

-- dummies hold their guard (to practise breaking it)
function TestCommands.DummiesBlock()
	local on = not workspace:GetAttribute("DummiesBlock")
	workspace:SetAttribute("DummiesBlock", on)
	local folder = workspace:FindFirstChild("Dummies")
	for _, model in folder and folder:GetChildren() or {} do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			setBlocking(model, on)
		end
	end
end

function TestCommands.GrantDev(player, _, userId, on)
	if typeof(userId) ~= "number" or type(on) ~= "boolean" then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if setGrant(player, target, on) then
		notice(player, (on and "Gave " or "Removed ") .. target.DisplayName .. (on and " DEV character access" or "'s DEV character access"), Color3.fromRGB(150, 220, 255))
	end
end

function TestCommands.GrantDevAll(player, _, _, on)
	if type(on) ~= "boolean" then
		return
	end
	local count = 0
	for _, target in Players:GetPlayers() do
		if setGrant(player, target, on) then
			count += 1
		end
	end
	notice(player, string.format("%s DEV access %s %d player%s", on and "Granted" or "Removed", on and "to" or "from", count, count == 1 and "" or "s"), Color3.fromRGB(150, 220, 255))
end

function TestCommands.ResetStats(player)
	Kit.setKills(player, 0, true)
	if Store.MarkDirty then
		Store.MarkDirty(player)
	end
	for _, name in { "Streak" } do
		local v = statValue(player, name)
		if v then
			v.Value = 0
		end
	end
	player:SetAttribute("BestStreak", 0)
	lives[player] = newLife()
end

-- (round 66) the leaderboard's test feature: +amount KOs (a minus takes them
-- off) - the Kills on the player list, the hero rank they earn (a rank-up
-- shows for everyone), the TOP HEROES board - saved like real ones
function TestCommands.AddKills(player, _, amount)
	local n = (type(amount) == "number" and amount == amount) and math.clamp(math.floor(amount), -100000, 100000) or 1
	Kit.setKills(player, (player:GetAttribute("Kills") or 0) + n)
	if Store.MarkDirty then
		Store.MarkDirty(player)
	end
end

function TestCommands.AddKills10(player)
	TestCommands.AddKills(player, nil, 10)
end

---------------------------------------------------------------------------
-- SERVER SETTINGS (the test menu's panel: Jujutsu Shenanigans' private-
-- server "+" menu). The world's settings live on workspace attributes
-- (everyone's machine can read them); per-player ones on the player.
---------------------------------------------------------------------------

do
	-- id = { attribute, min, max, default } (the panel steps through values)
	local NUMBERS = {
		DamageMult = { "DamageMult", 0, 10, 1 },
		KnockbackMult = { "KnockbackMult", 0, 5, 1 },
		SpeedMult = { "SpeedMult", 0.25, 4, 1 },
		JumpMult = { "JumpMult", 0.25, 4, 1 },
		UltRate = { "UltRate", 0, 20, 1 },
	}
	-- on/off world settings (default on)
	local TOGGLES = { MapRegen = "MapRegen", RagdollCancel = "EvasiveEnabled", DashPunches = "DashPunchEnabled", HealthRegen = "HealthRegen", Knockdowns = "Knockdowns", Clashes = "Clashes" }
	-- ...and the ones that are off until someone switches them on (the
	-- prank, and the world events: the sky battle, Deku dropping in)
	local OPT_IN = { MufflerPrank = "MufflerPrank", SkyBattle = "SkyBattle", DekuDrop = "DekuDrop", NomuRaid = "NomuRaid" } -- (round 75: the Nomu too)
	-- per-player switches ("Skills" / "Melee" / "Parkour" / "Evade" are
	-- stored the other way round: on = allowed)
	local FLAGS = {
		GodMode = "GodMode", NoCooldowns = "NoCooldowns", InfiniteUlt = "InfiniteUlt", NoStun = "NoStun", Flight = "Flight",
		Skills = "NoSkills", Melee = "NoMelee", Parkour = "NoParkour", Evade = "NoEvade",
	}
	local INVERTED = { Skills = true, Melee = true, Parkour = true, Evade = true }
	local forAll = {} -- [attribute] = value: "everyone" switches also go to whoever joins later
	local normalGravity = workspace.Gravity

	local function refreshEveryone()
		for _, plr in Players:GetPlayers() do
			if plr.Character and alive(plr.Character) then
				applyPassives(plr, plr.Character, false)
			end
		end
	end

	function TestCommands.PSSet(_, _, id, value)
		if type(id) ~= "string" then
			return
		end
		local num = NUMBERS[id]
		if id == "Destruction" then
			Destruction.SetEnabled(value == true)
		elseif TOGGLES[id] then
			workspace:SetAttribute(TOGGLES[id], value == true)
		elseif OPT_IN[id] then
			workspace:SetAttribute(OPT_IN[id], value == true or nil)
		elseif id == "Gravity" then
			if type(value) == "number" and value == value then
				workspace.Gravity = math.clamp(value, 10, 600)
			end
		elseif num then
			if type(value) ~= "number" or value ~= value then
				return
			end
			workspace:SetAttribute(num[1], math.clamp(value, num[2], num[3]))
			if id == "SpeedMult" or id == "JumpMult" then
				refreshEveryone()
			end
		elseif id == "SkyBattleNow" then
			if Kit.AB then
				Kit.AB.start()
			end
		elseif id == "DekuDropNow" then
			if Kit.DD then
				Kit.DD.start()
			end
		elseif id == "NomuRaidNow" then
			if Kit.NR then
				Kit.NR.start() -- (round 71)
			end
		elseif id == "NomuRaidKill" then
			if Kit.NR then
				Kit.NR.kill() -- (round 75)
			end
		elseif id == "ClearRubble" then
			local debris = workspace:FindFirstChild("MapDebris")
			if debris then
				debris:ClearAllChildren()
			end
		elseif id == "RebuildMap" then
			Destruction.RegenerateAll()
		elseif id == "ResetSettings" then
			for _, n in NUMBERS do
				workspace:SetAttribute(n[1], n[4])
			end
			for _, attr in TOGGLES do
				workspace:SetAttribute(attr, true)
			end
			for _, attr in OPT_IN do
				workspace:SetAttribute(attr, nil)
			end
			workspace.Gravity = normalGravity
			Destruction.SetEnabled(true)
			refreshEveryone()
		end
	end

	local function targetsOf(userId)
		if userId == 0 then
			return Players:GetPlayers(), true
		end
		local one = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
		return one and { one } or {}, false
	end

	local function setFlag(plr, attr, on)
		plr:SetAttribute(attr, on or nil)
		if attr == "NoCooldowns" then
			cooldowns[plr] = {}
			recoverUntil[plr] = nil
		elseif attr == "InfiniteUlt" and on and not plr:GetAttribute("UltActive") then
			local quirk = Config.Quirks[plr:GetAttribute("Quirk") or ""]
			if quirk and quirk.Ult then
				plr:SetAttribute("Ult", 100)
			end
		end
	end

	function TestCommands.PSPlayer(player, char, action, userId)
		if type(action) ~= "string" then
			return
		end
		local targets, everyone = targetsOf(userId)
		local attr = FLAGS[action]
		if attr then
			-- a switch: on for all of them unless they all have it already
			local allOn = #targets > 0
			for _, plr in targets do
				local has = plr:GetAttribute(attr) == true
				if INVERTED[action] then
					has = not has
				end
				allOn = allOn and has
			end
			local turnOn = not allOn
			local value = turnOn
			if INVERTED[action] then
				value = not turnOn
			end
			for _, plr in targets do
				setFlag(plr, attr, value)
			end
			if everyone then
				forAll[attr] = value
			end
			return
		end
		for _, plr in targets do
			local c = plr.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if action == "Heal" and hum and hum.Health > 0 then
				hum.Health = hum.MaxHealth
			elseif action == "Kill" and hum then
				hum.Health = 0
			elseif action == "Respawn" then
				plr:LoadCharacter()
			elseif action == "Bring" and c and char and plr ~= player then
				c:PivotTo(char:GetPivot() * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0))
			elseif action == "GoTo" and c and char and plr ~= player and not everyone then
				char:PivotTo(c:GetPivot() * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0))
			elseif action == "ResetCooldowns" then
				cooldowns[plr] = {}
				recoverUntil[plr] = nil
				PlayVFX:FireClient(plr, "ResetCooldowns", nil, {})
			elseif action == "FillUlt" then
				TestCommands.FillUlt(plr)
			elseif action == "Evasive" and c then
				Evasive.fill(c)
			elseif action == "Kick" and plr ~= player and not canTest(plr) then
				plr:Kick("Kicked from this server.")
			end
		end
	end

	-- "everyone" switches stick for players who join (or respawn) later
	local function applyForAll(plr)
		for attr, value in forAll do
			if plr:GetAttribute(attr) ~= (value or nil) then
				setFlag(plr, attr, value)
			end
		end
	end
	Players.PlayerAdded:Connect(applyForAll)
	-- Infinite Ult: the meter stays full
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, plr in Players:GetPlayers() do
				if plr:GetAttribute("InfiniteUlt") and not plr:GetAttribute("UltActive") and (plr:GetAttribute("Ult") or 0) < 100 then
					local quirk = Config.Quirks[plr:GetAttribute("Quirk") or ""]
					if quirk and quirk.Ult then
						plr:SetAttribute("Ult", 100)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Dev toys (the test menu's FUN STUFF panel)
---------------------------------------------------------------------------

do
	local normalGravity = workspace.Gravity

	-- everyone but you: players and dummies
	local function everyoneElse(char)
		local list = {}
		for _, plr in Players:GetPlayers() do
			local c = plr.Character
			if c and c ~= char and alive(c) then
				table.insert(list, c)
			end
		end
		local folder = workspace:FindFirstChild("Dummies")
		for _, model in folder and folder:GetChildren() or {} do
			if alive(model) then
				table.insert(list, model)
			end
		end
		return list
	end

	function TestCommands.MoneyPrinter(player, char)
		Store.AddBucks(player, 100)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			broadcast("MoneyRain", char, { Pos = root.Position })
		end
	end

	local function setSize(player, char, size)
		player:SetAttribute("SizeMode", player:GetAttribute("SizeMode") ~= size and size or nil)
		if char and char.Parent then
			applyPassives(player, char, false)
		end
	end

	function TestCommands.GiantMode(player, char)
		setSize(player, char, 3)
	end

	function TestCommands.TinyMode(player, char)
		setSize(player, char, 0.4)
	end

	-- a head three times too big (the neck stays where it was)
	function TestCommands.Bobblehead(player, char)
		local head = char and char:FindFirstChild("Head")
		if not head then
			return
		end
		local on = char:GetAttribute("Bobblehead") ~= true
		char:SetAttribute("Bobblehead", on)
		local k = on and 2.6 or 1 / 2.6
		local hum = char:FindFirstChildOfClass("Humanoid")
		local headScale = hum and hum:FindFirstChild("HeadScale")
		if headScale and headScale:IsA("NumberValue") then
			headScale.Value *= k -- R15
		else
			head.Size *= k
			local mesh = head:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh.Scale *= k
			end
			local torso = char:FindFirstChild("Torso")
			local neck = torso and torso:FindFirstChild("Neck")
			if neck then
				neck.C1 = CFrame.new(neck.C1.Position * k) * neck.C1.Rotation
			end
		end
		local hair = char:FindFirstChild("HeroHair")
		if hair then
			hair:Destroy() -- rebuilt to fit the new head
			Store.RefreshHair(player)
		end
		broadcast("Boing", char, {})
	end

	function TestCommands.MoonGravity()
		local on = not workspace:GetAttribute("MoonGravity")
		workspace:SetAttribute("MoonGravity", on)
		workspace.Gravity = on and 45 or normalGravity
	end

	function TestCommands.LaunchEveryone(_, char)
		for _, model in everyoneElse(char) do
			local a = math.random() * math.pi * 2
			knockback(model, Vector3.new(math.cos(a) * 45, 230, math.sin(a) * 45), 0.3)
			broadcast("Launch", nil, { Target = model })
		end
	end

	function TestCommands.DummyRain(_, char)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local control = dummyControl()
		if not root or not control then
			return
		end
		local kinds = Config.DummyKinds or {}
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local pos = root.Position + Vector3.new(math.cos(a) * 24, 80 + i * 8, math.sin(a) * 24)
			local kind = kinds[math.random(1, math.max(#kinds, 1))]
			control:Fire("Spawn", CFrame.new(pos), kind and kind.Id or "Normal")
		end
	end

	-- a disco ball over your head: lights, music, and everyone nearby dances
	function TestCommands.DiscoParty(_, char)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local on = not workspace:GetAttribute("Disco")
		if on and root then
			workspace:SetAttribute("DiscoCenter", root.Position)
		end
		workspace:SetAttribute("Disco", on)
	end

	function TestCommands.HairForAll()
		for _, plr in Players:GetPlayers() do
			Store.GiveItem(plr, "AllMightHair", 1)
		end
	end
end

TestCommand.OnServerEvent:Connect(function(player, command, arg, flag)
	if typeof(command) ~= "string" or not canTest(player) then
		return
	end
	local fn = TestCommands[command]
	if fn then
		fn(player, player.Character, arg, flag)
	end
end)

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------

-- The action lock (CombatActionUntil) and a press the client held back for
-- the end of a recovery: the client lets it go the moment the recovery ends
-- as it sees it, and a network hiccup can land it a few hundredths before
-- the server's own lock is up. Dropping it would leave the client showing a
-- move (or a raised guard) the server never made - so a press that arrives
-- inside the last LOCK_GRACE seconds waits out the lock instead, once.
Kit.DEFERRED = {} -- (a table no client can send: marks the waited-out retry)
Kit.LOCK_GRACE = 0.25
Kit.guardSeq = setmetatable({}, { __mode = "k" }) -- [char] = guard presses so far
-- the emote wheel (Config.Emotes): which ones exist, and a little spam guard
Kit.emoteIds = {}
for _, e in Config.Emotes or {} do
	Kit.emoteIds[e.Id] = true
end
Kit.lastEmote = setmetatable({}, { __mode = "k" }) -- [player] = os.clock()

function Kit.onUseAbility(player, index, aimDir, aimPos, seed, origin, air, deferred)
	if typeof(index) ~= "number" then
		return
	end
	deferred = deferred == Kit.DEFERRED
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	-- (round 74) stopped in DIO's time: nothing
	if char and char:GetAttribute("TimeStopped") and not (index == Config.BLOCK_INDEX and aimDir ~= true) then
		return
	end
	if index == Config.BLOCK_INDEX then
		if char and not deferred then
			Kit.guardSeq[char] = (Kit.guardSeq[char] or 0) + 1
		end
		-- lowering the guard always works; raising it needs you on your feet
		if aimDir == true then
			if root and alive(char) and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled")
				and not char:GetAttribute("Frozen") and not char:GetAttribute("Grabbed") then
				local wait = (char:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow()
				if wait <= 0.04 then
					setBlocking(char, true)
				elseif not deferred and wait <= Kit.LOCK_GRACE then
					-- (still held when the lock is up - not let go meanwhile)
					local seq = Kit.guardSeq[char]
					task.delay(wait, function()
						if Kit.guardSeq[char] == seq and player.Character == char then
							Kit.onUseAbility(player, index, true, nil, nil, nil, nil, Kit.DEFERRED)
						end
					end)
				end
			end
		elseif char then
			setBlocking(char, false)
		end
		return
	end
	if index == Config.AIM_INDEX then
		-- where he's aiming right now (a move that follows the aim is going)
		if typeof(aimDir) == "Vector3" and aimDir == aimDir and aimDir.Magnitude > 0.01 then
			Kit.liveAim[player] = { Dir = aimDir.Unit, Time = os.clock() }
		end
		return
	end
	if index == Config.RELEASE_INDEX then
		-- letting go of a held move (it goes even if he's been hit meanwhile)
		if root and alive(char) then
			HoldMoves.release(player, aimDir, aimPos)
		end
		return
	end
	-- (round 73) Bakugo's explosion flight: taking off, each blast, dropping
	-- out (dropping out goes through even stunned - Kit.BF)
	if index == Config.PARKOUR_INDEX and Kit.BF and Kit.BF.KINDS[aimDir] then
		Kit.BF.relay(player, char, aimDir, aimPos)
		return
	end
	-- (round 75) Deku's Float (lift-off, the Air Force flicks, touch-down) and
	-- the Blackwhip slingshot
	if index == Config.PARKOUR_INDEX and Kit.FL and Kit.FL.KINDS[aimDir] then
		Kit.FL.relay(player, char, aimDir, aimPos)
		return
	end
	if index == Config.PARKOUR_INDEX and Kit.WD and Kit.WD.KINDS[aimDir] then
		Kit.WD.relay(player, char, aimDir, aimPos)
		return
	end
	if index == Config.DASH_INDEX and aimPos == "Evasive" then
		-- the ragdoll cancel: the one thing you can do while you're down
		if root and alive(char) then
			Evasive.use(player, char, root, aimDir)
		end
		return
	end
	if not root or not alive(char) or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled")
		or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished") or char:GetAttribute("Submerged")
		or char:GetAttribute("PlayingUno") or char:GetAttribute("Clashing") then
		return
	end
	-- (parkour is movement, not a combat action: the lock doesn't hold it -
	-- the vault already happened on the player's screen, this only shows it)
	if index == Config.PARKOUR_INDEX then
		if not player:GetAttribute("NoParkour") then
			relayParkour(player, char, aimDir, aimPos, seed, origin) -- (movement, not a quirk: works while erased)
		end
		return
	end
	-- A front dash contact is the continuation of that dash, not a new action;
	-- and Deku's R only swaps which quirk is in his 4th slot (no attack).
	local quirkDef = index == Config.SPECIAL_INDEX and Config.Quirks[player:GetAttribute("Quirk") or ""]
	local cycling = quirkDef and quirkDef.Special and quirkDef.Special.Cycle == true
	-- (round 65, JJS) a side / back dash may cut into the dasher's own M1 -
	-- the M1's lock only (the swing still lands, from where the dash goes)
	local m1Dash = index == Config.DASH_INDEX and (aimPos == "Back" or aimPos == "Left" or aimPos == "Right" or aimPos == "Side")
		and Config.Movement.DashOutOfM1 ~= false and (Kit.m1Until[char] or -1) >= (char:GetAttribute("CombatActionUntil") or 0) - 0.01
	if not (index == Config.DASH_INDEX and aimPos == "Punch") and not cycling and not m1Dash then
		local wait = (char:GetAttribute("CombatActionUntil") or 0) - workspace:GetServerTimeNow()
		if wait > 0.04 then
			if not deferred and wait <= Kit.LOCK_GRACE then
				task.delay(wait, function()
					if player.Character == char then
						Kit.onUseAbility(player, index, aimDir, aimPos, seed, origin, air, Kit.DEFERRED)
					end
				end)
			end
			return
		end
	end
	-- an emote off the wheel: everyone else plays it (his own screen already is)
	if index == Config.EMOTE_INDEX then
		-- (only the ones you've bought: round 58)
		if typeof(aimDir) == "string" and Kit.emoteIds[aimDir] and (not Store.OwnsEmote or Store.OwnsEmote(player, aimDir))
			and os.clock() - (Kit.lastEmote[player] or 0) > 0.4
			and not char:GetAttribute("Holding") and not char:GetAttribute("Grabbed") then
			Kit.lastEmote[player] = os.clock()
			broadcast("Emote", char, { Id = aimDir }, player)
		end
		return
	end
	-- (server settings: Melee / Skills switched off for this player)
	if (index == 0 and player:GetAttribute("NoMelee")) or (index ~= 0 and player:GetAttribute("NoSkills")) then
		return
	end
	if char:GetAttribute("Holding") then
		return -- charging a held move: nothing else until he lets go
	end
	if index ~= 0 and index ~= Config.DASH_INDEX and index ~= Config.FINISH_INDEX
		and (char:GetAttribute("ErasedUntil") or 0) > workspace:GetServerTimeNow() then
		return -- Eraser Head's capture scarf: no quirk for a few seconds
	end
	if guardState[char] and guardState[char].Blocking then
		setBlocking(char, false) -- attacking or dashing lowers the guard
	end
	if index ~= Config.DASH_INDEX and index ~= Config.SPECIAL_INDEX and Permeation.OnAttack then
		Permeation.OnAttack(char)
	end

	if index == 0 then
		-- (an M1 sends where the attacker stood on their screen, and the 4th
		-- hit's variant: "Up" uppercut / "Down" downslam)
		handleM1(player, char, root, aimDir, aimPos)
		return
	elseif index == Config.DASH_INDEX then
		handleDash(player, char, aimDir, aimPos, seed)
		return
	elseif index == Config.ULT_INDEX then
		activateUlt(player, char, root)
		return
	elseif index == Config.LEAP_INDEX then
		handleLeap(player, char, root)
		return
	elseif index == Config.FINISH_INDEX then
		handleFinisher(player, char, root, aimDir, aimPos) -- (the target, then the aim)
		return
	end

	local quirkName = player:GetAttribute("Quirk")
	local alt = player:GetAttribute("QuirkAlt") == true
	local ult = player:GetAttribute("UltActive") == true
	local pick = player:GetAttribute("QuirkPick")
	local ability = Config.GetAbility(quirkName, index, alt, ult, pick)
	if not ability then
		return
	end

	if index == Config.SPECIAL_INDEX and ability.Form then
		handleSpecial(player, char, quirkName, ability)
		return
	end

	if Kit.HF and Kit.HF.refuse(player, char, quirkName, ability) then
		return
	end
	if not checkCooldown(player, Config.CooldownKey(quirkName, index, alt, ult, pick), ability.Cooldown) then
		return
	end
	if Kit.HF then
		Kit.HF.used(player, char, quirkName, ability)
	end
	if ability.ActionTime then
		char:SetAttribute("CombatActionUntil", workspace:GetServerTimeNow() + ((air == true and ability.AirActionTime) or ability.ActionTime))
	end
	if ability.CinematicArmor and Config.Cinematics and Config.Cinematics.Enabled then
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + ability.CinematicArmor)
	end
	if ult and (Config.Ult.MoveArmor or 0) > 0 then
		-- an ult move is never traded mid-swing
		iFrames[char] = math.max(iFrames[char] or 0, os.clock() + math.max(ability.ActionTime or 0, Config.Ult.MoveArmor))
	end

	local dir = sanitizeDir(aimDir, root)
	local pos = sanitizePos(aimPos, root, dir)
	-- seed + origin let every client (and the destruction) build identical ice spikes
	if typeof(seed) ~= "number" or seed ~= seed or math.abs(seed) > 2 ^ 31 then
		seed = math.random(1, 2 ^ 30)
	end
	seed = math.floor(math.abs(seed))
	if typeof(origin) ~= "Vector3" or origin ~= origin or (origin - root.Position).Magnitude > 16 then
		origin = root.Position
	end
	-- air variants: whether he was off the ground when he used it (his own
	-- machine knows best - it moves his body)
	local cast = { Seed = seed, Origin = origin, Air = air == true }

	broadcast(ability.Id, char, { Dir = dir, Pos = pos, Seed = seed, Origin = origin, Air = cast.Air }, player)
	if Kit.CL then
		Kit.CL.fire(player, char, ability, dir) -- (round 71: out, for a clash)
	end

	local handler = Handlers[ability.Id]
	if handler then
		task.spawn(Kit.runMove, handler, player, char, root, ability, dir, pos, cast)
	end
end

-- a move, run as his (freezing him cuts it short) - except the ones that
-- put him in a lasting state (a stance, a transformation, Infinity: those
-- last their Duration) and the cinematic ones (armoured anyway)
function Kit.runMove(handler, player, char, root, ability, ...)
	local cuttable = not (ability.Duration or ability.Cinematic or ability.Form or ability.Cycle or ability.Uninterruptible)
	Moves.join({ Char = char, Epoch = Moves.cuts[char] or 0, Ability = ability, Cuttable = cuttable })
	Kit.lastMove[char] = { Ability = ability, Time = os.clock() }
	handler(player, char, root, ability, ...)
end

UseAbility.OnServerEvent:Connect(Kit.onUseAbility)

local lastSwitch = {} -- [player] = os.clock() of the last quirk switch
local SWITCH_COOLDOWN = 2.5

SelectQuirk.OnServerEvent:Connect(function(player, quirkName)
	if typeof(quirkName) ~= "string" or not Config.Quirks[quirkName] then
		return
	end
	if Config.Quirks[quirkName].DevOnly and not canUseDev(player) then
		return -- dev-only quirk: testers and players they've granted
	end
	local now = os.clock()
	if not canTest(player) and not player:GetAttribute("NoCooldowns") and now - (lastSwitch[player] or -math.huge) < SWITCH_COOLDOWN then
		PlayVFX:FireClient(player, "Notice", nil, { Text = "Wait a moment before switching quirks again", Color = Color3.fromRGB(255, 150, 120) })
		return
	end
	lastSwitch[player] = now
	applyQuirk(player, quirkName)
end)

---------------------------------------------------------------------------
-- (round 66) THE CONSOLE (F2, Config.Console): every test feature as a
-- typed command. Only the game's OWNER runs commands - the account that
-- made the game (a group game: the group's owner), anyone in
-- Config.Console.Owners, and in Studio the one testing it (Player1 in a
-- local server test) - checked here on every line, whatever a client says.
-- Anyone else can open it with F2 and watch: the server keeps the log (the
-- last History lines) and sends every new line to everyone.
---------------------------------------------------------------------------
-- (in a function of its own: the server's main chunk is at its 200-local
-- limit when Studio compiles it with full debug info - and an error in
-- here is only warned about, never stopping the server)
xpcall(function()
	local CON = Config.Console or {}
	local ConsoleRemote = Remotes:FindFirstChild("Console") or Instance.new("RemoteEvent")
	ConsoleRemote.Name = "Console"
	ConsoleRemote.Parent = Remotes
	local Console = { log = {}, owners = setmetatable({}, { __mode = "k" }), commands = {}, order = {}, lastRun = setmetatable({}, { __mode = "k" }), lastSync = setmetatable({}, { __mode = "k" }) }
	Kit.Console = Console

	function Console.isOwner(player)
		if CON.Enabled == false or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false
		end
		local known = Console.owners[player]
		if known ~= nil then
			return known
		end
		local id = player.UserId
		local yes = table.find(CON.Owners or {}, id) ~= nil
		local creator = tonumber(game.CreatorId) or 0
		if not yes then
			local okType, group = pcall(function()
				return game.CreatorType == Enum.CreatorType.Group
			end)
			if okType and group then
				local ok, rank = pcall(player.GetRankInGroup, player, creator)
				yes = ok and rank == 255
			else
				yes = id == creator and id ~= 0
			end
		end
		-- Studio: the one testing it (play solo; Player1 of a local server
		-- test - the others there are viewers, to try it from their side)
		if not yes and RunService:IsStudio() then
			yes = id == -1 or (id > 0 and (creator == 0 or id == creator))
		end
		Console.owners[player] = yes
		return yes
	end

	-- a line for everyone's console (kind: "cmd", "ok", "err", "info", "event"),
	-- or just for one player's (onlyTo: help, a refusal)
	function Console.print(text, kind, onlyTo)
		local line = { Text = string.sub(tostring(text), 1, 600), Kind = kind or "info", Time = os.time() }
		if onlyTo then
			ConsoleRemote:FireClient(onlyTo, "Line", line)
			return
		end
		table.insert(Console.log, line)
		while #Console.log > (CON.History or 200) do
			table.remove(Console.log, 1)
		end
		ConsoleRemote:FireAllClients("Line", line)
	end

	local function add(names, usage, help, fn)
		local cmd = { Name = names[1], Usage = usage, Help = help, Fn = fn }
		for _, n in names do
			Console.commands[string.lower(n)] = cmd
		end
		table.insert(Console.order, cmd)
	end

	-- who a command is for: "me" (the default), "all", "others", "random",
	-- or the start of someone's name or display name
	local function targets(player, word)
		word = string.lower(word or "me")
		local everyone = Players:GetPlayers()
		if word == "me" then
			return { player }
		elseif word == "all" or word == "everyone" or word == "*" then
			return everyone
		elseif word == "others" then
			local list = {}
			for _, plr in everyone do
				if plr ~= player then
					table.insert(list, plr)
				end
			end
			return list
		elseif word == "random" then
			return #everyone > 0 and { everyone[math.random(1, #everyone)] } or {}
		end
		local list = {}
		for _, plr in everyone do
			local n, d = string.lower(plr.Name), string.lower(plr.DisplayName)
			if n == word or d == word then
				return { plr } -- (a whole name beats the start of one)
			end
			if string.sub(n, 1, #word) == word or string.sub(d, 1, #word) == word then
				table.insert(list, plr)
			end
		end
		return list
	end
	local function names(list)
		local out = {}
		for _, plr in list do
			table.insert(out, plr.DisplayName)
		end
		return #out > 0 and table.concat(out, ", ") or "nobody"
	end
	-- runs fn(target) for each; the reply names who it reached
	local function each(player, word, fn)
		local list = targets(player, word)
		if #list == 0 then
			return "No player matches '" .. tostring(word) .. "'", "err"
		end
		for _, plr in list do
			fn(plr)
		end
		return nil, nil, list
	end
	local function onOff(word, current)
		word = string.lower(word or "")
		if word == "on" or word == "true" or word == "1" or word == "yes" then
			return true
		elseif word == "off" or word == "false" or word == "0" or word == "no" then
			return false
		end
		return not current
	end

	-- heroes by id, by name on the phone, or by who they are
	local HEROES = {
		bakugo = "Explosion", katsuki = "Explosion", allmight = "OneForAll", toshinori = "OneForAll",
		deku = "FullCowl", izuku = "FullCowl", midoriya = "FullCowl", todoroki = "HalfCold", shoto = "HalfCold",
		momo = "Creation", yaoyorozu = "Creation", creati = "Creation", mirio = "Lemillion", suneater = "Manifest",
		tamaki = "Manifest", kamui = "Arbor", kamuiwoods = "Arbor", denki = "Electrification", kaminari = "Electrification",
		chargebolt = "Electrification", chisaki = "Overhaul", kai = "Overhaul", shigaraki = "Decay", tomura = "Decay",
		sako = "Compress", mrcompress = "Compress", twice = "Double", jin = "Double", bubaigawara = "Double", gojo = "Limitless", josuke = "CrazyDiamond", cd = "CrazyDiamond",
		primedeku = "PrimeDeku", primeallmight = "PrimeMight", primemight = "PrimeMight", dio = "TheWorld", theworld = "TheWorld",
		iida = "Engine", tenya = "Engine", endeavor = "Hellflame", enji = "Hellflame", dabi = "Blueflame", toya = "Blueflame",
	}
	local function findHero(word)
		word = string.lower((string.gsub(word or "", "[%s_%-%.]", "")))
		if word == "" then
			return nil
		end
		if HEROES[word] and Config.Quirks[HEROES[word]] then
			return HEROES[word]
		end
		for _, q in Config.QuirkOrder or {} do
			local spec = Config.Quirks[q]
			local shown = string.lower((string.gsub(spec and spec.DisplayName or "", "[%s_%-%.]", "")))
			if string.lower(q) == word or shown == word then
				return q
			end
		end
		for _, q in Config.QuirkOrder or {} do
			local spec = Config.Quirks[q]
			local shown = string.lower((string.gsub(spec and spec.DisplayName or "", "[%s_%-%.]", "")))
			if string.sub(string.lower(q), 1, #word) == word or string.sub(shown, 1, #word) == word then
				return q
			end
		end
		return nil
	end
	local function findItem(word)
		word = string.lower(word or "")
		local ITEMS = Config.Items or {}
		for id, it in ITEMS do
			if string.lower(id) == word or string.lower(it.Name or "") == word then
				return id
			end
		end
		for id, it in ITEMS do
			if string.sub(string.lower(id), 1, #word) == word or string.sub(string.lower(it.Name or ""), 1, #word) == word then
				return id
			end
		end
		return nil
	end
	local function count(word, default, lo, hi)
		local n = tonumber(word)
		if not n or n ~= n then
			return default
		end
		return math.clamp(math.floor(n), lo, hi)
	end

	---------------------------------------------------------------------------
	-- the commands (fn(player, args) -> reply, kind)
	---------------------------------------------------------------------------
	add({ "help", "?", "commands" }, "help [command]", "Every command, or how one works", function(player, args)
		if args[1] then
			local cmd = Console.commands[string.lower(args[1])]
			if not cmd then
				return "No command '" .. args[1] .. "'", "err"
			end
			Console.print(cmd.Usage .. "  -  " .. cmd.Help, "info", player)
			return nil
		end
		local list = {}
		for _, cmd in Console.order do
			table.insert(list, cmd.Name)
		end
		Console.print("Commands: " .. table.concat(list, "  "), "info", player)
		Console.print("Targets: me (default), all, others, random, or the start of a name.  'help <command>' for more.", "info", player)
		return nil
	end)
	add({ "players", "who", "list" }, "players", "Everyone here: hero, health, KOs, Bucks", function()
		local lines = {}
		for _, plr in Players:GetPlayers() do
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			local q = Config.Quirks[plr:GetAttribute("Quirk") or ""]
			table.insert(lines, string.format("%s (@%s)  %s  %d HP  %d KOs  $%d%s", plr.DisplayName, plr.Name, q and (q.DisplayName or "?") or "no hero",
				hum and math.floor(hum.Health) or 0, plr:GetAttribute("Kills") or 0, plr:GetAttribute("Bucks") or 0, Console.isOwner(plr) and "  [OWNER]" or ""))
		end
		return table.concat(lines, "\n"), "info"
	end)
	add({ "heal" }, "heal [who]", "Full health", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.PSPlayer(player, player.Character, "Heal", plr.UserId)
		end)
		return err or ("Healed " .. names(list)), kind or "ok"
	end)
	add({ "kill", "ko" }, "kill [who]", "Knock them out", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.PSPlayer(player, player.Character, "Kill", plr.UserId)
		end)
		return err or ("KO'd " .. names(list)), kind or "ok"
	end)
	add({ "respawn", "re" }, "respawn [who]", "A fresh body at a spawn", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			plr:LoadCharacter()
		end)
		return err or ("Respawned " .. names(list)), kind or "ok"
	end)
	-- the switches (per player): the test menu's and the server panel's
	local SWITCHES = {
		god = { "GodMode", "GodMode", "god mode" }, nocd = { "NoCooldowns", "NoCooldowns", "no cooldowns" },
		infult = { "InfiniteUlt", "InfiniteUlt", "infinite ult" }, nostun = { "NoStun", "NoStun", "no stun" },
		fly = { "Flight", "Flight", "flight" },
		noskills = { "Skills", "NoSkills", "moves off", true }, nomelee = { "Melee", "NoMelee", "M1s off", true },
		noparkour = { "Parkour", "NoParkour", "parkour off", true }, noevade = { "Evade", "NoEvade", "evasive off", true },
	}
	for word, sw in SWITCHES do
		add({ word }, word .. " [who] [on|off]", "Switches " .. sw[3] .. " for them", function(player, args)
			local who, state = args[1], args[2]
			if who and (string.lower(who) == "on" or string.lower(who) == "off") then
				who, state = nil, who
			end
			local err, kind, list = each(player, who, function(plr)
				local has = plr:GetAttribute(sw[2]) == true
				local want = onOff(state, has)
				if want ~= has then
					TestCommands.PSPlayer(player, player.Character, sw[1], plr.UserId)
				end
			end)
			if err then
				return err, kind
			end
			local first = list[1]
			return string.format("%s %s for %s", sw[3], first and first:GetAttribute(sw[2]) == true and "ON" or "OFF", names(list)), "ok"
		end)
	end
	add({ "ult", "fillult" }, "ult [who]", "Fill the ult meter", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.FillUlt(plr)
		end)
		return err or ("Ult ready for " .. names(list)), kind or "ok"
	end)
	add({ "endult" }, "endult [who]", "End an ult early", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.EndUlt(plr, plr.Character)
		end)
		return err or ("Ended the ult for " .. names(list)), kind or "ok"
	end)
	add({ "cd", "resetcd" }, "cd [who]", "Reset cooldowns", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.PSPlayer(player, player.Character, "ResetCooldowns", plr.UserId)
		end)
		return err or ("Cooldowns reset for " .. names(list)), kind or "ok"
	end)
	add({ "evasive" }, "evasive [who]", "Fill the evasive (ragdoll cancel) bar", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.PSPlayer(player, player.Character, "Evasive", plr.UserId)
		end)
		return err or ("Evasive full for " .. names(list)), kind or "ok"
	end)
	add({ "hero", "quirk", "char" }, "hero <name> [who]", "Switch hero (any, dev ones too): bakugo, deku, josuke...", function(player, args)
		local q = findHero(args[1])
		if not q then
			return "No hero '" .. tostring(args[1]) .. "' - try: " .. table.concat(Config.QuirkOrder or {}, ", "), "err"
		end
		local err, kind, list = each(player, args[2], function(plr)
			applyQuirk(plr, q)
		end)
		return err or string.format("%s -> %s", names(list), Config.Quirks[q].DisplayName or q), kind or "ok"
	end)
	add({ "dummy", "dummies" }, "dummy [kind|clear|reset|block|tp|rain] [count]", "Spawn dummies (Normal, Finisher, Attack, Block, Moving, Tank, R6), or clear / reset / block / tp / rain", function(player, args)
		local word = string.lower(args[1] or "normal")
		local verbs = { clear = "ClearDummies", reset = "ResetDummies", block = "DummiesBlock", tp = "TeleportDummies", rain = "DummyRain" }
		if verbs[word] then
			TestCommands[verbs[word]](player, player.Character)
			return "Dummies: " .. word, "ok"
		end
		local kind
		for _, k in Config.DummyKinds or {} do
			if string.lower(k.Id) == word then
				kind = k.Id
			end
		end
		if not kind then
			return "No dummy kind '" .. word .. "'", "err"
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local control = dummyControl()
		if not root or not control then
			return "You need a body (and the dummies script)", "err"
		end
		local n = count(args[2], 1, 1, 12)
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local side = look:Cross(UP)
		for i = 1, n do
			local pos = root.Position + look * 12 + side * ((i - (n + 1) / 2) * 5) + UP * 2
			control:Fire("Spawn", CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z)), kind)
		end
		return string.format("Spawned %d %s dumm%s", n, kind, n == 1 and "y" or "ies"), "ok"
	end)
	add({ "tp", "goto" }, "tp <who>", "Go to them", function(player, args)
		local plr = targets(player, args[1] or "")[1]
		local c, mine = plr and plr.Character, player.Character
		if not c or not mine or plr == player then
			return "No one to go to", "err"
		end
		mine:PivotTo(c:GetPivot() * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0))
		return "Went to " .. plr.DisplayName, "ok"
	end)
	add({ "bring" }, "bring <who>", "Bring them to you", function(player, args)
		local err, kind, list = each(player, args[1] or "", function(plr)
			TestCommands.PSPlayer(player, player.Character, "Bring", plr.UserId)
		end)
		return err or ("Brought " .. names(list)), kind or "ok"
	end)
	add({ "kick" }, "kick <who> [reason]", "Kick them from this server (never an owner)", function(player, args)
		local list = targets(player, args[1] or "")
		local kicked = {}
		local reason = #args > 1 and table.concat(args, " ", 2) or "Kicked from this server."
		for _, plr in list do
			if plr ~= player and not Console.isOwner(plr) then
				table.insert(kicked, plr)
				plr:Kick(reason)
			end
		end
		return #kicked > 0 and ("Kicked " .. names(kicked)) or "No one kicked", #kicked > 0 and "ok" or "err"
	end)
	add({ "bucks", "money", "cash" }, "bucks <amount> [who]", "Give (or take, with a minus) Bucks", function(player, args)
		local n = count(args[1], nil, -1000000, 1000000)
		if not n then
			return "How many? e.g. bucks 500", "err"
		end
		local err, kind, list = each(player, args[2], function(plr)
			Store.AddBucks(plr, n)
		end)
		return err or string.format("%+d Bucks for %s", n, names(list)), kind or "ok"
	end)
	add({ "kills", "addkills" }, "kills <amount> [who]", "Add KOs: the leaderboard, their rank and the TOP HEROES board (saved)", function(player, args)
		local n = count(args[1], 1, -100000, 100000)
		local err, kind, list = each(player, args[2], function(plr)
			TestCommands.AddKills(plr, plr.Character, n)
		end)
		if err then
			return err, kind
		end
		local first = list[1]
		return string.format("%+d KOs for %s%s", n, names(list), #list == 1 and string.format(" (now %d, %s)", first:GetAttribute("Kills") or 0, first:GetAttribute("Rank") or "?") or ""), "ok"
	end)
	add({ "setkills" }, "setkills <n> [who]", "Set their KO count", function(player, args)
		local n = count(args[1], nil, 0, 1000000)
		if not n then
			return "To what? e.g. setkills 100", "err"
		end
		local err, kind, list = each(player, args[2], function(plr)
			TestCommands.AddKills(plr, plr.Character, n - (plr:GetAttribute("Kills") or 0))
		end)
		return err or string.format("%s now on %d KOs", names(list), n), kind or "ok"
	end)
	add({ "resetstats" }, "resetstats [who]", "KOs and streaks back to zero", function(player, args)
		local err, kind, list = each(player, args[1], function(plr)
			TestCommands.ResetStats(plr)
		end)
		return err or ("Stats reset for " .. names(list)), kind or "ok"
	end)
	add({ "give", "item" }, "give <item> [count] [who]", "Put a shop item in their bag", function(player, args)
		local id = findItem(args[1])
		if not id then
			local ids = {}
			for k in Config.Items or {} do
				table.insert(ids, k)
			end
			table.sort(ids)
			return "No item '" .. tostring(args[1]) .. "' - items: " .. table.concat(ids, ", "), "err"
		end
		local n = count(args[2], 1, 1, 99)
		local err, kind, list = each(player, args[3], function(plr)
			Store.GiveItem(plr, id, n)
		end)
		return err or string.format("%d x %s for %s", n, (Config.Items[id] or {}).Name or id, names(list)), kind or "ok"
	end)
	add({ "drop", "deliver" }, "drop [soda|item] [who]", "A free Support Drop, right where they're standing", function(player, args)
		local what = string.lower(args[1] or "item") == "soda" and "Soda" or "Item"
		local err, kind, list = each(player, args[2], function(plr)
			Store.Deliver(plr, what, true)
		end)
		return err or string.format("%s drop on its way to %s", what, names(list)), kind or "ok"
	end)
	-- the server panel's settings
	local NUMBERS = { damage = "DamageMult", knockback = "KnockbackMult", speed = "SpeedMult", jump = "JumpMult", ultrate = "UltRate" }
	local TOGGLES = {
		destruction = "Destruction", mapregen = "MapRegen", ragdollcancel = "RagdollCancel", dashpunches = "DashPunches",
		regen = "HealthRegen", knockdowns = "Knockdowns", skybattle = "SkyBattle", dekudrop = "DekuDrop", muffler = "MufflerPrank",
		nomu = "NomuRaid",
	}
	local ATTRS = {
		Destruction = "DestructionEnabled", MapRegen = "MapRegen", RagdollCancel = "EvasiveEnabled", DashPunches = "DashPunchEnabled",
		HealthRegen = "HealthRegen", Knockdowns = "Knockdowns", SkyBattle = "SkyBattle", DekuDrop = "DekuDrop", MufflerPrank = "MufflerPrank",
		NomuRaid = "NomuRaid",
	}
	add({ "set" }, "set <setting> <value>", "damage / knockback / speed / jump / ultrate <x>, gravity <n>, destruction / mapregen / ragdollcancel / dashpunches / regen / knockdowns / skybattle / dekudrop / muffler <on|off>, reset", function(player, args)
		local what = string.lower(args[1] or "")
		if what == "reset" then
			TestCommands.PSSet(player, nil, "ResetSettings")
			return "Server settings back to normal", "ok"
		elseif what == "gravity" then
			local g = tonumber(args[2])
			if not g then
				return "set gravity <number> (normal is 196.2)", "err"
			end
			TestCommands.PSSet(player, nil, "Gravity", g)
			return string.format("Gravity %.1f", workspace.Gravity), "ok"
		elseif NUMBERS[what] then
			local v = tonumber(args[2])
			if not v then
				return "set " .. what .. " <number>", "err"
			end
			TestCommands.PSSet(player, nil, NUMBERS[what], v)
			return string.format("%s = %s", NUMBERS[what], tostring(workspace:GetAttribute(NUMBERS[what]))), "ok"
		elseif TOGGLES[what] then
			local id = TOGGLES[what]
			local now = workspace:GetAttribute(ATTRS[id])
			local on = onOff(args[2], now == true or (now == nil and id ~= "SkyBattle" and id ~= "DekuDrop" and id ~= "MufflerPrank" and id ~= "NomuRaid"))
			TestCommands.PSSet(player, nil, id, on)
			return string.format("%s %s", id, on and "ON" or "OFF"), "ok"
		end
		return "No setting '" .. what .. "' (help set)", "err"
	end)
	-- (round 75) the Nomu: bring one down now, or kill the one that's down
	add({ "nomu" }, "nomu <now|kill>", "A Nomu raid now, or kill the one that's down", function(player, args)
		local what = string.lower(args[1] or "")
		if what == "now" then
			TestCommands.PSSet(player, nil, "NomuRaidNow")
			return "A High-End Nomu is coming", "ok"
		elseif what == "kill" then
			if not (Kit.NR and Kit.NR.active) then
				return "There's no Nomu down", "err"
			end
			TestCommands.PSSet(player, nil, "NomuRaidKill")
			return "The Nomu's down for good", "ok"
		end
		return "nomu now / nomu kill", "err"
	end)
	add({ "event" }, "event <skybattle|dekudrop>", "Start a world event now", function(player, args)
		local what = string.lower(args[1] or "")
		if what == "skybattle" then
			TestCommands.PSSet(player, nil, "SkyBattleNow")
		elseif what == "dekudrop" then
			TestCommands.PSSet(player, nil, "DekuDropNow")
		else
			return "event skybattle / event dekudrop", "err"
		end
		return "Event: " .. what, "ok"
	end)
	add({ "map" }, "map <rebuild|rubble>", "Put the city back, or sweep the rubble away", function(player, args)
		local what = string.lower(args[1] or "rebuild")
		TestCommands.PSSet(player, nil, what == "rubble" and "ClearRubble" or "RebuildMap")
		return what == "rubble" and "Rubble cleared" or "Map rebuilt", "ok"
	end)
	-- the FUN STUFF panel
	for _, fun in {
		{ { "giant" }, "GiantMode", "Three times the hero (toggle)" }, { { "tiny" }, "TinyMode", "Mineta-sized (toggle)" },
		{ { "bobble", "bobblehead" }, "Bobblehead", "A head three times too big (toggle)" }, { { "printer" }, "MoneyPrinter", "+100 Bucks, money rain" },
	} do
		add(fun[1], fun[1][1] .. " [who]", fun[3], function(player, args)
			local err, kind, list = each(player, args[1], function(plr)
				TestCommands[fun[2]](plr, plr.Character)
			end)
			return err or (fun[1][1] .. ": " .. names(list)), kind or "ok"
		end)
	end
	for _, fun in {
		{ { "moon" }, "MoonGravity", "Moon gravity for everyone (toggle)" }, { { "launch" }, "LaunchEveryone", "Every other player and dummy to orbit" },
		{ { "disco" }, "DiscoParty", "A disco ball over you (toggle)" }, { { "hairforall" }, "HairForAll", "An All Might hair for everyone" },
		{ { "vestige" }, "Vestige", "One For All's vestige realm: in / out" },
		{ { "memories", "memory" }, "Memories", "Deku's memories: the classroom, the Sports Festival, back (each go: the next one)" },
	} do
		add(fun[1], fun[1][1], fun[3], function(player)
			TestCommands[fun[2]](player, player.Character)
			return fun[1][1] .. "!", "ok"
		end)
	end
	add({ "dev" }, "dev <who> [on|off]", "Give or take DEV character access", function(player, args)
		local list = targets(player, args[1] or "")
		if #list == 0 then
			return "No player matches '" .. tostring(args[1]) .. "'", "err"
		end
		for _, plr in list do
			local on = onOff(args[2], plr:GetAttribute("DevAccess") == true)
			TestCommands.GrantDev(player, nil, plr.UserId, on)
		end
		return "DEV access: " .. names(list), "ok"
	end)
	add({ "announce", "say" }, "announce <text>", "A notice on everyone's screen", function(_, args)
		local text = table.concat(args, " ")
		if text == "" then
			return "announce what?", "err"
		end
		PlayVFX:FireAllClients("Notice", nil, { Text = text, Color = Color3.fromRGB(255, 212, 64) })
		return "Announced: " .. text, "ok"
	end)
	add({ "time" }, "time <0-24>", "Time of day", function(_, args)
		local h = tonumber(args[1])
		if not h then
			return "time <hour>, e.g. time 18.5", "err"
		end
		game:GetService("Lighting").ClockTime = h % 24
		return string.format("Clock %.1f", h % 24), "ok"
	end)
	Console.commands.help.Quiet = true
	-- (the console itself handles: clear, freecam, menu)
	Console.clientOnly = {
		{ Name = "clear", Usage = "clear", Help = "Clear your console" },
		{ Name = "freecam", Usage = "freecam", Help = "Free camera (Ctrl + P)" },
		{ Name = "menu", Usage = "menu", Help = "The test menu (P)" },
	}

	-- a line from someone's console: split into words ("quoted words" stay together)
	function Console.run(player, text)
		if type(text) ~= "string" then
			return
		end
		text = string.sub((string.gsub(text, "%c", " ")), 1, 240)
		local args = {}
		local i = 1
		while i <= #text do
			local c = string.sub(text, i, i)
			if c == '"' then
				local j = string.find(text, '"', i + 1, true) or (#text + 1)
				table.insert(args, string.sub(text, i + 1, j - 1))
				i = j + 1
			elseif string.find(c, "%s") then
				i += 1
			else
				local j = string.find(text, "%s", i) or (#text + 1)
				table.insert(args, string.sub(text, i, j - 1))
				i = j
			end
		end
		if #args == 0 then
			return
		end
		if not Console.isOwner(player) then
			Console.print("Read-only: only the owner of this game can run commands here.", "err", player)
			return
		end
		local now = os.clock()
		if now - (Console.lastRun[player] or 0) < 0.05 then
			return
		end
		Console.lastRun[player] = now
		local cmd = Console.commands[string.lower(table.remove(args, 1))]
		-- (everyone watching sees what the owner runs - but help is just theirs)
		Console.print(player.DisplayName .. "> " .. text, "cmd", cmd and cmd.Quiet and player or nil)
		if not cmd then
			Console.print("Unknown command - 'help' lists them", "err")
			return
		end
		local ok, reply, kind = pcall(cmd.Fn, player, args)
		if not ok then
			Console.print("Error: " .. tostring(reply), "err")
		elseif reply then
			Console.print(reply, kind or "ok")
		end
	end

	ConsoleRemote.OnServerEvent:Connect(function(player, action, text)
		if action == "Run" then
			Console.run(player, text)
		elseif action == "Sync" then
			-- (the whole log: once a second at most)
			local now = os.clock()
			if now - (Console.lastSync[player] or -10) < 1 then
				return
			end
			Console.lastSync[player] = now
			local list = {}
			for _, cmd in Console.order do
				table.insert(list, { Name = cmd.Name, Usage = cmd.Usage, Help = cmd.Help })
			end
			for _, cmd in Console.clientOnly do
				table.insert(list, cmd)
			end
			ConsoleRemote:FireClient(player, "Sync", { Log = Console.log, Commands = list, Owner = Console.isOwner(player) })
		end
	end)
	-- (the client shows the input box to the owner; the server checks anyway)
	local function mark(plr)
		plr:SetAttribute("ConsoleOwner", Console.isOwner(plr))
	end
	Players.PlayerAdded:Connect(function(plr)
		mark(plr)
		Console.print(plr.DisplayName .. " joined", "event")
	end)
	Players.PlayerRemoving:Connect(function(plr)
		Console.print(plr.DisplayName .. " left", "event")
	end)
	for _, plr in Players:GetPlayers() do
		mark(plr)
	end
	Console.print("Server started: " .. #Console.order .. " commands ready (F2)", "event")
end, function(err)
	warn("[QuirkServer] console: " .. tostring(err))
end)

---------------------------------------------------------------------------
-- Bodies: R6 with Motor6D joints, the way the whole game is built
---------------------------------------------------------------------------

-- If the experience's avatar settings let an R15 body in (Config.ForceR6),
-- it's swapped straight away for an R6 body built from that player's own
-- avatar (skin, clothes, hair and accessories), standing in the same spot.
-- onSwapped(rig) runs once the new body is in (it gets the same setup as a
-- normal spawn).
local function forceR6(player, char, onSwapped)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if Config.ForceR6 == false or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local ok, rig = pcall(function()
		-- the saved avatar is complete even before this body's look has loaded
		local okDesc, desc = false, nil
		if player.UserId > 0 then
			okDesc, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
		end
		if not okDesc or not desc then
			desc = hum:GetAppliedDescription()
		end
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not rig or not rig:FindFirstChildOfClass("Humanoid") then
		if not script:GetAttribute("R6Failed") then
			script:SetAttribute("R6Failed", true)
			warn("[QuirkServer] couldn't build an R6 body; R15 players stay R15: " .. tostring(rig))
		end
		return false
	end
	rig.Name = player.Name
	-- what a normal spawn would get from StarterPlayer
	local starter = game:GetService("StarterPlayer")
	local rigHum = rig:FindFirstChildOfClass("Humanoid")
	rigHum.DisplayName = player.DisplayName
	rigHum.WalkSpeed = starter.CharacterWalkSpeed
	rigHum.UseJumpPower = starter.CharacterUseJumpPower
	rigHum.JumpPower = starter.CharacterJumpPower
	rigHum.JumpHeight = starter.CharacterJumpHeight
	rigHum.MaxSlopeAngle = starter.CharacterMaxSlopeAngle
	rigHum.BreakJointsOnDeath = starter.CharacterBreakJointsOnDeath
	rigHum.RequiresNeck = false -- (only health decides a KO: see watchKO)
	-- the scripts a normal spawn would copy in (a custom Animate wins)
	local charScripts = starter:FindFirstChild("StarterCharacterScripts")
	if charScripts then
		for _, s in charScripts:GetChildren() do
			local old = rig:FindFirstChild(s.Name)
			if old then old:Destroy() end
			s:Clone().Parent = rig
		end
	end
	task.defer(function()
		if not player.Parent or player.Character ~= char then
			rig:Destroy()
			return
		end
		local pivot = char:GetPivot()
		rig:PivotTo(pivot)
		rig.Parent = workspace
		player.Character = rig
		char:Destroy()
		if onSwapped then
			task.delay(0.2, onSwapped, rig)
		end
	end)
	return true
end

-- Spawn pads are invisible, and where one sits on the ground it doesn't
-- collide either (no invisible step to trip over)
do
	local function hideSpawn(pad)
		pad.Transparency = 1
		for _, d in pad:GetChildren() do
			if d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { pad }
		if workspace:Raycast(pad.Position, Vector3.new(0, -(pad.Size.Y / 2 + 1.5), 0), params) then
			pad.CanCollide = false
		end
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			hideSpawn(d)
		end
	end
end

local function onPlayer(player)
	player:SetAttribute("Tester", canTest(player))
	player:SetAttribute("DevAccess", canUseDev(player))
	setupStats(player)
	Store.PlayerJoined(player)
	lives[player] = newLife()
	-- the custom shift lock (the movement pack) owns Shift; the built-in one
	-- would take the key first for anyone with Shift Lock Switch on
	player.DevEnableMouseLock = false
	local function onCharacter(char)
		if char:GetAttribute("CharSetup") then
			return
		end
		local swapping = forceR6(player, char, function(rig)
			if rig.Parent and player.Character == rig then
				onCharacter(rig) -- (in case the engine didn't fire CharacterAdded for it)
				-- CharacterAppearanceLoaded never fires for a body built here
				applyGear(player, rig, 0.1)
				Store.RefreshHair(player)
			end
		end)
		if swapping then
			return -- (this R15 body is replaced by an R6 one straight away)
		end
		char:SetAttribute("CharSetup", true)
		classicJoints(char)
		Destruction.RegisterCharacter(char)
		Store.CharacterAdded(player, char)
		lives[player] = newLife()
		guardOf(char)
		Evasive.fill(char) -- (a fresh body starts with its ragdoll cancel ready)
		task.spawn(watchKO, char)
		if player:GetAttribute("UltActive") then
			-- dying ends the ult (the meter starts over)
			ultTokens[player] = (ultTokens[player] or 0) + 1
			player:SetAttribute("UltActive", false)
			player:SetAttribute("UltEnds", nil)
			player:SetAttribute("Ult", 0)
		end
		local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
		if quirk and quirk.Special and quirk.Special.ResetOnRespawn and player:GetAttribute("QuirkAlt") then
			altTokens[player] = (altTokens[player] or 0) + 1
			player:SetAttribute("QuirkAlt", false)
			player:SetAttribute("AltEnds", nil)
			recoverUntil[player] = recoverUntil[player] or {}
			recoverUntil[player][player:GetAttribute("Quirk")] = os.clock() + (quirk.Special.RecoverTime or 0)
		end
		applyPassives(player, char, true)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterAppearanceLoaded:Connect(function(char)
		if player.Character ~= char then
			return -- (an R15 body that was already swapped out)
		end
		applyGear(player, char, 0.1)
		Store.RefreshHair(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

---------------------------------------------------------------------------
-- OUT-OF-COMBAT HEALING (Config.Regen): Delay seconds after your last hit
-- given, taken or blocked (or any other damage), health starts coming back -
-- slowly, building up. The character's Regenerating attribute lights the
-- HUD. Roblox's own Health script (a flat 1%/s, fight or no fight) goes.
---------------------------------------------------------------------------
do
	local REGEN = Config.Regen or {}
	local STEP = 0.25
	local lastHealth = setmetatable({}, { __mode = "k" })
	local function dropDefault(char)
		local h = char:WaitForChild("Health", 5)
		if h and h:IsA("Script") then
			h:Destroy()
		end
	end
	local function hook(plr)
		plr.CharacterAdded:Connect(dropDefault)
		if plr.Character then
			task.spawn(dropDefault, plr.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, plr in Players:GetPlayers() do
		hook(plr)
	end
	task.spawn(function()
		while true do
			task.wait(STEP)
			local on = REGEN.Enabled ~= false and workspace:GetAttribute("HealthRegen") ~= false
			local now = os.clock()
			for _, plr in Players:GetPlayers() do
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					-- (damage from anywhere - a fall, poison - is a fight too)
					if lastHealth[hum] and hum.Health < lastHealth[hum] - 0.01 then
						Reactions.fought[char] = now
					end
					local since = now - (Reactions.fought[char] or -math.huge)
					local delay = REGEN.Delay or 7
					local healing = on and hum.Health > 0 and hum.Health < hum.MaxHealth and since >= delay
						and not char:GetAttribute("Ragdolled") and not char:GetAttribute("Decaying")
					if healing then
						local lo, hi = REGEN.Rate or 0.015, REGEN.MaxRate or 0.06
						local rate = lo + (hi - lo) * math.clamp((since - delay) / (REGEN.Ramp or 5), 0, 1)
						hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * rate * STEP)
					end
					lastHealth[hum] = hum.Health
					if (char:GetAttribute("Regenerating") == true) ~= healing then
						char:SetAttribute("Regenerating", healing or nil)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- THE SKY COFFIN (Config.SkyCoffin), the final war's battlefield: the U.A.
-- grounds lifted into the sky on propulsion jets to fight Shigaraki. A round
-- slab of lawn - the main building at the back, a belt of trees round the
-- rim - twelve black pillars on the rim, and strung between them the
-- electromagnetic barrier: a gold wall and a low tent of a roof, cables from
-- every pillar top to the peak. Touch it and it locks you up for a moment.
-- Outside it, on its own little platform piped into the side, the generator
-- that powers the barrier and keeps the lot aloft. In front of the main
-- building: the Sports Festival stage. The place file only carries scripts,
-- so it's all built here; Kurogiri's warp gates run between it and the
-- plaza by the middle spawn.
---------------------------------------------------------------------------
do
	local SC = { cfg = Config.SkyCoffin or {}, gates = {}, cool = setmetatable({}, { __mode = "k" }), zapped = setmetatable({}, { __mode = "k" }) }
	Kit.SC = SC

	function SC.build()
		local cfg = SC.cfg
		local R, RP, BH = cfg.Radius or 425, cfg.Barrier or 418, cfg.BarrierHeight or 290
		local O = CFrame.new(cfg.Center or Vector3.new(-70, 600, 888)) -- (y = the lawn's surface)
		local model = Instance.new("Model")
		model.Name = "SkyCoffin"
		SC.model = model
		local rng = Random.new(406)
		local BLACK = Color3.fromRGB(26, 27, 31)
		local GOLD = Color3.fromRGB(255, 210, 92)
		local HULL = Color3.fromRGB(56, 58, 64)
		local HULL_DARK = Color3.fromRGB(40, 42, 47)
		local SEAM = Color3.fromRGB(88, 92, 100)
		local CONCRETE = Color3.fromRGB(196, 204, 186)
		local FRAME = Color3.fromRGB(228, 231, 236)
		local RED = Color3.fromRGB(240, 34, 36)
		local VOLT = Color3.fromRGB(255, 226, 70)
		local function part(size, cf, color, material, shape, class)
			local p = Instance.new(class or "Part")
			p.Anchored = true
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			if shape then
				p.Shape = shape
			end
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = model
			return p
		end
		local function at(x, y, z)
			return O * CFrame.new(x, y, z)
		end
		local function pt(x, y, z)
			return O * Vector3.new(x, y, z)
		end
		-- round, standing on end (a Cylinder's axis is its X)
		local function disc(dia, h, cf, color, material)
			return part(Vector3.new(h, dia, dia), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
		end
		-- a round bar from a to b
		local function bar(a, b, thick, color)
			return part(Vector3.new((b - a).Magnitude, thick, thick), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		-- looks only: nothing collides with it, rays pass through, no shadow
		local function ghost(p)
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			return p
		end
		-- (the destruction carves it like the city's buildings, and rebuilds it)
		local function breakable(p)
			p:SetAttribute("Destroyable", true)
			return p
		end
		-- round the rim: angle a from the front (+Z), r out, y up; X runs along it
		local function ring(a, r, y)
			return O * CFrame.Angles(0, a, 0) * CFrame.new(0, y, r)
		end
		local function sign(p, face, text, color, font)
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 0
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = text
			t.TextScaled = true
			t.Font = font or Enum.Font.GothamBlack
			t.TextColor3 = color
			t.Parent = gui
			gui.Parent = p
		end
		-- a flat triangle out of two wedges (the barrier's roof)
		local function triangle(a, b, c, color, transparency)
			local ab, ac, bc = b - a, c - a, c - b
			local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
			if abd > acd and abd > bcd then
				c, a = a, c
			elseif acd > bcd and acd > abd then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local up = bc:Cross(right).Unit
			local back = bc.Unit
			local height = math.abs(ab:Dot(up))
			for _, w in {
				{ Vector3.new(0.3, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back) },
				{ Vector3.new(0.3, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back) },
			} do
				local p = ghost(part(w[1], w[2], color, Enum.Material.SmoothPlastic, nil, "WedgePart"))
				p.Transparency = transparency
				p.Name = "BarrierRoof"
			end
		end
		local function emitter(parent, props)
			local pe = Instance.new("ParticleEmitter")
			for k, v in props do
				pe[k] = v
			end
			pe.Parent = parent
			return pe
		end
		local function light(parent, color, range, brightness)
			local l = Instance.new("PointLight")
			l.Color = color
			l.Range = range
			l.Brightness = brightness
			l.Parent = parent
			return l
		end

		-- (the big slabs cast no shadow: half the city in the dark under it all
		-- day is no fun)
		local function unshaded(p)
			p.CastShadow = false
			return p
		end
		-- the island's ground: what Lemillion's dive stops under (not the city's
		-- street 600 studs down), and what nobody phases through
		local function ground(p)
			p:SetAttribute("SkyFloor", true)
			p:SetAttribute("NoPhase", true)
			return unshaded(p)
		end
		local SZ, GATE_Z = -10, 130 -- the stage's middle, the warp gate, along the front

		-- THE HULL: the slab the grounds sit on, stepped in underneath
		ground(disc(2 * R, 24, at(0, -13.5, 0), HULL, Enum.Material.Concrete)).Name = "Hull"
		ghost(disc(2 * R + 1, 1.5, at(0, -18, 0), SEAM, Enum.Material.Metal))
		ground(disc(R * 1.76, 10, at(0, -30.5, 0), HULL_DARK, Enum.Material.Metal))
		ground(disc(R * 1.36, 10, at(0, -40.5, 0), HULL_DARK, Enum.Material.Metal))
		ground(disc(R * 0.75, 10, at(0, -50.5, 0), HULL_DARK, Enum.Material.Metal))
		-- the propulsion jets: eight round the underside, a big one in the middle
		local function jet(x, z, dia, y)
			local h = 8 + dia * 0.1
			unshaded(disc(dia, h, at(x, y - h / 2, z), Color3.fromRGB(34, 36, 40), Enum.Material.Metal))
			ghost(disc(dia + 3, 1.6, at(x, y - h + 0.8, z), SEAM, Enum.Material.Metal))
			local glow = ghost(disc(dia * 0.75, 0.5, at(x, y - h - 0.25, z), Color3.fromRGB(176, 228, 255), Enum.Material.Neon))
			glow.Name = "Jet"
			emitter(glow, {
				Texture = "rbxasset://textures/particles/fire_main.dds",
				EmissionDirection = Enum.NormalId.Left, -- (the disc's -X: straight down)
				Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(80, 160, 255)),
				LightEmission = 1,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dia * 0.35), NumberSequenceKeypoint.new(1, dia * 0.08) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(40 + dia, 60 + dia * 1.5),
				SpreadAngle = Vector2.new(5, 5),
				Rate = 28,
			})
			light(glow, Color3.fromRGB(150, 210, 255), math.min(60, dia * 1.6), 2.5)
		end
		for i = 0, 7 do
			local a = (i + 0.5) / 8 * math.pi * 2
			jet(math.sin(a) * R * 0.78, math.cos(a) * R * 0.78, 36, -35.5)
		end
		jet(0, 0, 90, -55.5)

		-- THE GROUNDS: the lawn, a dark wall round the edge and inside it a belt
		-- of trees
		local LR = R - 21 -- (the lawn inside the belt)
		ground(disc(2 * (R - 5), 1.5, at(0, -0.75, 0), Color3.fromRGB(128, 166, 72), Enum.Material.Grass)).Name = "Lawn"
		local SEGS = 96
		for i = 0, SEGS - 1 do
			local a = i / SEGS * math.pi * 2
			unshaded(part(Vector3.new(2 * math.pi * R / SEGS + 0.9, 11, 5), ring(a, R - 2.5, 3.5), HULL_DARK, Enum.Material.Concrete)):SetAttribute("NoPhase", true)
			unshaded(part(Vector3.new(2 * math.pi * (R - 13) / SEGS + 1, 6, 16), ring(a, R - 13, 2), Color3.fromRGB(54, 94, 44), Enum.Material.LeafyGrass)):SetAttribute("NoPhase", true)
		end
		local GREENS = { Color3.fromRGB(46, 86, 40), Color3.fromRGB(62, 104, 48), Color3.fromRGB(80, 122, 58), Color3.fromRGB(38, 72, 36) }
		for i = 1, 260 do
			local a = (i + rng:NextNumber() * 0.8) / 260 * math.pi * 2
			local s = rng:NextNumber(8, 16)
			ghost(part(Vector3.new(s, s * 0.8, s), ring(a, rng:NextNumber(R - 19, R - 7), 5 + s * 0.15), GREENS[rng:NextInteger(1, #GREENS)], Enum.Material.LeafyGrass, Enum.PartType.Ball))
		end
		-- worn sandy patches (kept off the stage, the building, the stand and the gate)
		local function clear(x, z, pad)
			return not ((math.abs(x) < 66 + pad and math.abs(z - SZ) < 66 + pad)
				or (math.abs(x) < 94 + pad and z < -82 + pad and z > -258 - pad)
				or (math.abs(x + 84) < 10 + pad and math.abs(z - SZ + 20) < 10 + pad)
				or (math.abs(x) < 14 + pad and math.abs(z - GATE_Z) < 14 + pad))
		end
		local placed = 0
		for _ = 1, 1000 do
			local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * (LR - 25)
			local x, z = math.sin(a) * r, math.cos(a) * r
			local w, d = rng:NextNumber(20, 60), rng:NextNumber(14, 36)
			if placed < 40 and clear(x, z, math.max(w, d) / 2) then
				placed += 1
				local cf = at(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				ghost(part(Vector3.new(0.12, d, w), cf * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(208, 190, 134), Enum.Material.Sand, Enum.PartType.Cylinder))
				for _ = 1, 2 do
					local s = rng:NextNumber(6, 16)
					local blot = cf * CFrame.new(rng:NextNumber(-d / 2, d / 2), 0.01, rng:NextNumber(-w / 2, w / 2))
					ghost(part(Vector3.new(0.1, s, s * rng:NextNumber(0.7, 1.3)), blot * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(200, 184, 128), Enum.Material.Sand, Enum.PartType.Cylinder))
				end
			end
		end
		-- the seams between the floor's tile segments (the development course
		-- made them to be thrown off, so the decay can't cross a missing one)
		for k = -5, 5 do
			local c = k * 76
			local half = math.sqrt(LR ^ 2 - c ^ 2)
			ghost(part(Vector3.new(0.5, 0.05, 2 * half), at(c, 0.02, 0), Color3.fromRGB(106, 140, 60), Enum.Material.Grass))
			ghost(part(Vector3.new(2 * half, 0.05, 0.5), at(0, 0.02, c), Color3.fromRGB(106, 140, 60), Enum.Material.Grass))
		end

		-- THE BARRIER: twelve pillars, the wall between them, the roof up to a
		-- peak, and the cables from every pillar top to it
		local tops = {}
		for i = 0, 11 do
			local base = ring(i / 12 * math.pi * 2, RP, 0)
			disc(16, BH + 2, base * CFrame.new(0, BH / 2 - 1, 0), BLACK).Name = "Pillar"
			disc(24, 8, base * CFrame.new(0, 3, 0), BLACK, Enum.Material.Metal)
			disc(19, 5, base * CFrame.new(0, BH + 2.5, 0), BLACK, Enum.Material.Metal)
			ghost(disc(17, 2.4, base * CFrame.new(0, BH - 12, 0), GOLD, Enum.Material.Neon))
			tops[i] = (base * CFrame.new(0, BH + 5, 0)).Position
		end
		SC.pillar = 8
		local apex = pt(0, BH + math.floor(BH * 0.27), 0)
		local chord, inR = 2 * RP * math.sin(math.pi / 12), RP * math.cos(math.pi / 12)
		for i = 0, 11 do
			local a = (i + 0.5) / 12 * math.pi * 2
			local wall = ghost(part(Vector3.new(chord - 14, BH, 0.6), ring(a, inR, BH / 2), GOLD))
			wall.Transparency = 0.8
			wall.Name = "BarrierWall"
			-- (what you actually bump into: invisible, so the camera never snags on
			-- it, and thick, so nobody knocked into it hard goes through)
			local solid = part(Vector3.new(chord + 3, BH + 40, 6), ring(a, inR + 3, (BH + 40) / 2 - 2), GOLD)
			solid.Transparency = 1
			solid.CanTouch = false
			solid.CastShadow = false
			solid.Name = "Barrier"
			solid:SetAttribute("NoPhase", true) -- (an electromagnetic wall: not matter he can slip through)
			local j = (i + 1) % 12
			triangle(tops[i], tops[j], apex, GOLD, 0.8)
			bar(tops[i], apex, 1.4, BLACK)
			bar(tops[i], tops[j], 1.4, BLACK)
		end
		local lid = disc(2 * RP + 10, 6, at(0, BH + 3, 0), GOLD)
		lid.Transparency = 1
		lid.CanQuery = false -- (nothing aimed up there lands on top of it)
		lid.CanTouch = false
		lid.CastShadow = false
		lid.Name = "Barrier"
		lid:SetAttribute("NoPhase", true)
		disc(14, 8, CFrame.new(apex), BLACK, Enum.Material.Metal)
		ghost(disc(15.6, 1.6, CFrame.new(apex), GOLD, Enum.Material.Neon))

		-- U.A. HIGH's main building: from above an H - two tall glass wings and
		-- a lower block between them - white frames over blue glass (floors
		-- every 7.5 studs, a frame every 6)
		local function block(cx, cz, w, d, h, ends)
			local body = breakable(part(Vector3.new(w, h, d), at(cx, h / 2, cz), Color3.fromRGB(118, 156, 190), Enum.Material.Glass))
			body.Reflectance = 0.12
			body.Name = "UA"
			breakable(part(Vector3.new(w + 0.8, 4, d + 0.8), at(cx, 2, cz), Color3.fromRGB(204, 206, 210), Enum.Material.Concrete))
			for y = 7.5, h - 4, 7.5 do
				breakable(part(Vector3.new(w + 0.7, 0.7, d + 0.7), at(cx, y, cz), FRAME))
			end
			breakable(part(Vector3.new(w + 1, 2, d + 1), at(cx, h + 0.5, cz), FRAME))
			-- the mullions, every six studs or so round the outside
			local x0, x1, z0, z1 = cx - w / 2 - 0.2, cx + w / 2 + 0.2, cz - d / 2 - 0.2, cz + d / 2 + 0.2
			local sides = { { x0, z1, x1, z1 }, { x1, z0, x0, z0 } }
			if ends then
				table.insert(sides, { x1, z1, x1, z0 })
				table.insert(sides, { x0, z0, x0, z1 })
			end
			for _, s in sides do
				local len = math.sqrt((s[3] - s[1]) ^ 2 + (s[4] - s[2]) ^ 2)
				local n = math.max(1, math.floor(len / 6 + 0.5))
				for k = 0, n - 1 do
					local t = k / n
					breakable(part(Vector3.new(0.6, h, 0.6), at(s[1] + (s[3] - s[1]) * t, h / 2, s[2] + (s[4] - s[2]) * t), FRAME))
				end
			end
		end
		block(-68, -170, 44, 168, 172, true)
		block(68, -170, 44, 168, 172, true)
		block(0, -170, 92, 60, 148, false)
		for _, u in { { -68, -206, 16, 8, 24 }, { 68, -206, 16, 8, 24 }, { -68, -126, 12, 6, 12 }, { 68, -126, 12, 6, 12 }, { 0, -182, 28, 6, 16 } } do
			local top = u[1] == 0 and 148 or 172
			breakable(part(Vector3.new(u[3], u[4], u[5]), at(u[1], top + 1.5 + u[4] / 2, u[2]), Color3.fromRGB(150, 154, 160), Enum.Material.Metal))
		end
		-- the entrance: a canopy over the glass doors, the crest high above
		breakable(part(Vector3.new(56, 2, 18), at(0, 20, -131), FRAME))
		breakable(part(Vector3.new(36, 18, 0.4), at(0, 9, -139.4), Color3.fromRGB(40, 56, 72), Enum.Material.Glass))
		local crest = breakable(part(Vector3.new(28, 14, 1), at(0, 128, -139.3), Color3.fromRGB(22, 22, 26)))
		sign(crest, Enum.NormalId.Back, "UA", Color3.fromRGB(240, 196, 40))

		-- THE SPORTS FESTIVAL STAGE (the one-on-one tournament's): a square of
		-- concrete in two tiers on a tiled plaza, a white line round the top,
		-- stairs up the sides, the U.A. crest set in the paving front and back,
		-- red flames at the corners, the referee's stand to one side
		ground(part(Vector3.new(124, 0.4, 124), at(0, 0.2, SZ), Color3.fromRGB(190, 198, 182), Enum.Material.Concrete)).Name = "Plaza"
		for k = 1, 9 do
			local c = -62 + k * 12.4
			ghost(part(Vector3.new(0.25, 0.05, 124), at(c, 0.42, SZ), Color3.fromRGB(146, 156, 140)))
			ghost(part(Vector3.new(124, 0.05, 0.25), at(0, 0.42, SZ + c), Color3.fromRGB(146, 156, 140)))
		end
		breakable(part(Vector3.new(96, 1.6, 96), at(0, 1.2, SZ), Color3.fromRGB(176, 186, 168), Enum.Material.Concrete))
		breakable(part(Vector3.new(84, 2.8, 84), at(0, 3.4, SZ), CONCRETE, Enum.Material.Concrete)).Name = "Stage"
		for _, e in { { 0, 41.4, 84, 1.2 }, { 0, -41.4, 84, 1.2 }, { 41.4, 0, 1.2, 81.6 }, { -41.4, 0, 1.2, 81.6 } } do
			breakable(part(Vector3.new(e[3], 0.05, e[4]), at(e[1], 4.82, SZ + e[2]), Color3.fromRGB(172, 182, 164), Enum.Material.Concrete))
		end
		for _, e in { { 0, 35, 70.6, 0.6 }, { 0, -35, 70.6, 0.6 }, { 35, 0, 0.6, 70.6 }, { -35, 0, 0.6, 70.6 } } do
			breakable(part(Vector3.new(e[3], 0.05, e[4]), at(e[1], 4.83, SZ + e[2]), Color3.fromRGB(242, 244, 240))).Name = "Line"
		end
		for side = -1, 1, 2 do
			breakable(part(Vector3.new(6, 2.8, 14), at(side * 45, 3.4, SZ), CONCRETE, Enum.Material.Concrete))
			for j = 1, 5 do
				local h = 4.4 - 0.733 * j
				breakable(part(Vector3.new(1.5, h, 14), at(side * (48 + 1.5 * j - 0.75), 0.4 + h / 2, SZ), CONCRETE, Enum.Material.Concrete))
			end
		end
		for _, zOff in { 55.5, -55.5 } do
			local plate = at(0, 0.55, SZ + zOff) * CFrame.Angles(0, zOff < 0 and math.pi or 0, 0)
			part(Vector3.new(15, 0.3, 8.5), plate, Color3.fromRGB(226, 180, 36), Enum.Material.Metal)
			sign(part(Vector3.new(13.4, 0.32, 6.9), plate, Color3.fromRGB(24, 24, 28)), Enum.NormalId.Top, "UA", Color3.fromRGB(240, 196, 40))
		end
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local x, z = sx * 52, SZ + sz * 52
				disc(3.6, 1.8, at(x, 1.3, z), Color3.fromRGB(46, 46, 52), Enum.Material.Metal)
				local base = ghost(part(Vector3.new(2.8, 4, 2.8), at(x, 4, z), RED, Enum.Material.Neon, Enum.PartType.Ball))
				base.Name = "Flame"
				ghost(part(Vector3.new(2, 8, 2), at(x, 8, z), Color3.fromRGB(226, 26, 40), Enum.Material.Neon, Enum.PartType.Ball)).Transparency = 0.1
				ghost(part(Vector3.new(1.1, 8, 1.1), at(x, 13, z), Color3.fromRGB(206, 18, 52), Enum.Material.Neon, Enum.PartType.Ball)).Transparency = 0.25
				local fire = Instance.new("Fire")
				fire.Color = Color3.fromRGB(255, 36, 30)
				fire.SecondaryColor = Color3.fromRGB(255, 110, 40)
				fire.Size = 7
				fire.Heat = 16
				fire.Parent = base
				light(base, RED, 18, 2)
			end
		end
		part(Vector3.new(8, 3.4, 6), at(-84, 1.7, SZ - 20), Color3.fromRGB(150, 152, 158), Enum.Material.Metal)
		part(Vector3.new(8, 1.7, 2), at(-84, 0.85, SZ - 16), Color3.fromRGB(150, 152, 158), Enum.Material.Metal)
		for _, r in { { 0, -2.9, 8, 0.3 }, { -3.9, 0, 0.3, 6 }, { 3.9, 0, 0.3, 6 } } do
			part(Vector3.new(r[3], 1.6, r[4]), at(-84 + r[1], 4.2, SZ - 20 + r[2]), Color3.fromRGB(120, 122, 128), Enum.Material.Metal)
		end

		-- THE GENERATOR, outside the barrier: its own round platform and a plant
		-- house on it (the electric-quirk students inside power the barrier and
		-- keep the lot up), piped into the side of the grounds
		local GX, GZ = -(R + 130), 40
		ground(disc(140, 16, at(GX, -16, GZ), HULL, Enum.Material.Metal)).Name = "Generator"
		ghost(disc(141.2, 1.6, at(GX, -12, GZ), SEAM, Enum.Material.Metal))
		ground(disc(100, 10, at(GX, -29, GZ), HULL_DARK, Enum.Material.Metal))
		jet(GX, GZ, 40, -34)
		part(Vector3.new(52, 24, 36), at(GX - 8, 4, GZ), Color3.fromRGB(148, 152, 158), Enum.Material.Concrete)
		part(Vector3.new(56, 2, 40), at(GX - 8, 17, GZ), Color3.fromRGB(118, 122, 130), Enum.Material.Metal)
		part(Vector3.new(24, 6, 16), at(GX - 12, 21, GZ + 4), Color3.fromRGB(108, 112, 120), Enum.Material.Metal)
		part(Vector3.new(0.5, 14, 10), at(GX + 18.2, -1, GZ), Color3.fromRGB(36, 38, 44))
		part(Vector3.new(0.5, 4, 28), at(GX + 18.2, 10, GZ), Color3.fromRGB(40, 56, 72), Enum.Material.Glass)
		for _, dz in { -24, 24 } do
			local coil = disc(8, 12, at(GX + 36, -2, GZ + dz), Color3.fromRGB(70, 72, 80), Enum.Material.Metal)
			ghost(disc(9, 1.2, at(GX + 36, -5, GZ + dz), VOLT, Enum.Material.Neon))
			ghost(disc(9, 1.2, at(GX + 36, 1, GZ + dz), VOLT, Enum.Material.Neon))
			emitter(coil, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.new(1, 1, 1), VOLT),
				LightEmission = 1,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
				Lifetime = NumberRange.new(0.15, 0.35),
				Speed = NumberRange.new(6, 14),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 18,
			})
			light(coil, VOLT, 20, 1.5)
		end
		for k = -2, 2 do
			local zb = GZ + k * 24
			bar(pt(GX + 69, -16, GZ + k * 12), pt(-math.sqrt((R - 2) ^ 2 - zb ^ 2), -16, zb), 5, Color3.fromRGB(66, 68, 76))
		end

		-- clouds drifting under it
		for c = 1, 9 do
			local a = c / 9 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(R + 60, R + 380)
			local cx, cz, cy = math.sin(a) * r, math.cos(a) * r, rng:NextNumber(-260, -120)
			for _ = 1, 6 do
				local s = rng:NextNumber(50, 100)
				local puff = ghost(part(Vector3.new(s, s * 0.42, s * 0.8), at(cx + rng:NextNumber(-60, 60), cy + rng:NextNumber(-8, 12), cz + rng:NextNumber(-45, 45)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(246, 248, 252), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
				puff.Transparency = 0.2
				puff.Name = "Cloud"
			end
		end

		-- KUROGIRI'S WARP GATES: a ring of dark purple mist on a plinth. Walk in
		local function gate(cf, title, sub)
			part(Vector3.new(15, 1, 5), cf * CFrame.new(0, -6, 0), Color3.fromRGB(34, 30, 40), Enum.Material.Slate)
			for k = 0, 23 do
				ghost(part(Vector3.new(1.75, 0.9, 0.9), cf * CFrame.Angles(0, 0, k / 24 * math.pi * 2) * CFrame.new(0, 6, 0), Color3.fromRGB(150, 80, 230), Enum.Material.Neon))
			end
			local void = ghost(part(Vector3.new(0.4, 11.6, 11.6), cf * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(34, 10, 52), Enum.Material.Neon, Enum.PartType.Cylinder))
			void.Transparency = 0.08
			void.Name = "WarpGate"
			emitter(void, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(96, 50, 130), Color3.fromRGB(30, 10, 50)),
				LightEmission = 0.3,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 7) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(1.2, 2),
				Speed = NumberRange.new(0.5, 1.5),
				SpreadAngle = Vector2.new(180, 180),
				RotSpeed = NumberRange.new(-30, 30),
				Rate = 10,
			})
			light(void, Color3.fromRGB(150, 80, 230), 14, 1.5)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(16, 4) -- (in studs: it shrinks with distance, like a sign)
			bb.StudsOffset = Vector3.new(0, 9, 0)
			bb.LightInfluence = 0
			bb.MaxDistance = 250
			for n, spec in { { title, 0, 0.62, Color3.fromRGB(255, 214, 64), Enum.Font.GothamBlack }, { sub, 0.62, 0.38, Color3.new(1, 1, 1), Enum.Font.GothamBold } } do
				local t = Instance.new("TextLabel")
				t.Name = n == 1 and "Title" or "Sub"
				t.BackgroundTransparency = 1
				t.Position = UDim2.fromScale(0, spec[2])
				t.Size = UDim2.fromScale(1, spec[3])
				t.Text = spec[1]
				t.TextScaled = true
				t.Font = spec[5]
				t.TextColor3 = spec[4]
				t.TextStrokeTransparency = 0
				t.Parent = bb
			end
			bb.Parent = void
			local g = { CFrame = cf, Void = void }
			table.insert(SC.gates, g)
			return g
		end
		local up = gate(at(0, 6.5, GATE_Z), "BACK TO THE CITY", "walk in: warp down")
		up.Up = true
		local cg = cfg.CityGate or Vector3.new(-72, 26, 857)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model }
		local hit = workspace:Raycast(cg + UP * 14, Vector3.new(0, -40, 0), params)
		local gy = hit and hit.Position.Y or cg.Y
		local down = gate(CFrame.new(cg.X, gy + 6.5, cg.Z) * CFrame.Angles(0, math.pi, 0), "THE SKY COFFIN", "walk in: warp up")
		up.To, down.To = down, up
		-- (always loaded for everyone: it's seen from all over the city, and
		-- nobody warps up onto a floor that hasn't streamed in yet)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		model.Parent = workspace:FindFirstChild("Map") or workspace
	end

	-- in a gate's mist: out of the other one (a moment for the far end to
	-- stream in first)
	function SC.warp(plr, char, root, to)
		SC.cool[char] = os.clock() + 3
		local look = to.CFrame.LookVector
		local dest = to.CFrame.Position + look * 7 - UP * 3.5
		broadcast("SkyWarp", char, { From = root.Position, To = dest, Up = to.Up == true })
		task.spawn(function()
			pcall(function()
				plr:RequestStreamAroundAsync(dest, 3)
			end)
			if not (alive(char) and root.Parent and plr.Character == char) then
				return
			end
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 1)
			char:PivotTo(CFrame.lookAt(dest, dest + look))
			root.AssemblyLinearVelocity = Vector3.zero
			broadcast("SkyWarpOut", char, { To = dest })
		end)
	end

	-- somewhere to come up out of the ground (Lemillion): if he went under on
	-- the Sky Coffin it stays inside the barrier - never out past it, over the
	-- sky (or down in the city: every ray out there finds the street far below)
	function SC.keepIn(from, to)
		local cfg = SC.cfg
		local center = cfg.Center or Vector3.new(-70, 600, 888)
		local RP = cfg.Barrier or 418
		local rel = from - center
		if Vector3.new(rel.X, 0, rel.Z).Magnitude > RP + 20 or rel.Y < -80 or rel.Y > (cfg.BarrierHeight or 290) + 100 then
			return to -- (he wasn't on the island)
		end
		local inside = RP * math.cos(math.pi / 12) - 10
		local flat = Vector3.new(to.X - center.X, 0, to.Z - center.Z)
		if flat.Magnitude <= inside and to.Y > center.Y - 30 then
			return to
		end
		if flat.Magnitude > inside then
			flat = flat.Unit * inside
		end
		return Vector3.new(center.X + flat.X, center.Y, center.Z + flat.Z)
	end

	-- DECAY on the Sky Coffin's ground (chapter 346, "Super Hyper Unfair
	-- Broken Stage"): the floor is tile segments of metal plate over the hull,
	-- and it defends itself. Every plate the decay reaches is cut loose and
	-- fired up into the sky, where it crumbles to nothing, and Best Jeanist's
	-- fibers stitch a new one into the gap. It's all for the eyes: the decay
	-- itself hits exactly as it does in the city, and nobody's thrown about.
	SC.TILE = 12
	SC.ejected = {} -- ["ix,iz"] = when that plate is back
	-- (plates, not the stage's plaza or the building on top of them)
	function SC.onLawn(x, z)
		return not ((math.abs(x) < 68 and math.abs(z + 10) < 68) or (math.abs(x) < 96 and z < -80 and z > -260))
	end
	-- (reach: how far this decay will spread in all, so Jeanist lands clear of it)
	function SC.onDecay(pos, radius, reach)
		local cfg = SC.cfg
		local center = cfg.Center or Vector3.new(-70, 600, 888)
		local rel = pos - center
		local LR = (cfg.Radius or 425) - 21
		if not SC.model or math.abs(rel.Y) > 14 or Vector3.new(rel.X, 0, rel.Z).Magnitude > LR + radius then
			return
		end
		local T, now = SC.TILE, os.clock()
		local tiles = {}
		for ix = math.floor((rel.X - radius) / T), math.floor((rel.X + radius) / T) do
			for iz = math.floor((rel.Z - radius) / T), math.floor((rel.Z + radius) / T) do
				local cx, cz = (ix + 0.5) * T, (iz + 0.5) * T
				local key = ix .. "," .. iz
				if (cx - rel.X) ^ 2 + (cz - rel.Z) ^ 2 <= radius * radius and cx * cx + cz * cz <= (LR - T) ^ 2
					and (SC.ejected[key] or 0) < now and SC.onLawn(cx, cz) and #tiles < 220 then
					SC.ejected[key] = now + 3.2
					table.insert(tiles, { ix, iz })
				end
			end
		end
		if #tiles > 0 then
			broadcast("SkyTiles", nil, { Tiles = tiles, From = pos, Reach = reach or radius })
		end
	end

	-- the barrier: a jolt that locks them up and throws them back off it
	function SC.zap(char, root, away)
		local Z = SC.cfg.Zap or {}
		SC.zapped[char] = os.clock() + (Z.Cooldown or 1.2)
		local time = Z.Stun or 0.7
		stun(char, time)
		knockback(char, away * (Z.Push or 55) + UP * (away.Y < -0.5 and 0 or 20), 0.2, true)
		broadcast("Shocked", nil, { Target = char, Duration = time })
		broadcast("BarrierZap", nil, { Pos = root.Position - away * 1.5, Normal = away })
	end

	function SC.tick()
		local cfg = SC.cfg
		local center = cfg.Center or Vector3.new(-70, 600, 888)
		local RP, BH = cfg.Barrier or 418, cfg.BarrierHeight or 290
		local inR, step = RP * math.cos(math.pi / 12), math.pi / 6
		local now = os.clock()
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and alive(char) then
				local pos = root.Position
				if not root.Anchored and not char:GetAttribute("Grabbed") and (SC.cool[char] or 0) < now then
					for _, g in SC.gates do
						local rel = g.CFrame:PointToObjectSpace(pos)
						if g.To and math.abs(rel.Z) < 2.5 and math.sqrt(rel.X * rel.X + rel.Y * rel.Y) < 5.8 then
							SC.warp(plr, char, root, g.To)
							break
						end
					end
				end
				local rel = pos - center
				local flat = Vector3.new(rel.X, 0, rel.Z)
				local r = flat.Magnitude
				if r > 1 and r < RP + 12 and rel.Y > -6 and rel.Y < BH + 40 and (SC.zapped[char] or 0) < now then
					-- how far out along the nearest panel's facing, and from the nearest pillar
					local phi = math.atan2(rel.X, rel.Z)
					local depth = r * math.cos(phi - (math.floor(phi / step) + 0.5) * step)
					local near = math.floor(phi / step + 0.5) * step
					local pillar = Vector3.new(math.sin(near), 0, math.cos(near)) * RP
					local wall = math.abs(depth - inR) < 2.6 or (flat - pillar).Magnitude < (SC.pillar or 4) + 2.5
					if wall then
						SC.zap(char, root, depth < inR and -flat.Unit or flat.Unit)
					elseif r < RP and rel.Y > BH - 6 then
						SC.zap(char, root, -UP)
					end
				end
			end
		end
	end

	if SC.cfg.Enabled ~= false then
		local ok, err = pcall(SC.build)
		if not ok then
			warn("[SkyCoffin] " .. tostring(err))
		end
		local last = 0
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - last >= 0.08 then
				last = now
				SC.tick()
			end
		end)
	end
end

---------------------------------------------------------------------------
-- ONE FOR ALL: THE VESTIGE REALM (Config.VestigeRealm, round 58). The space
-- inside the quirk where Deku - asleep, dreaming - first met the ones who
-- held it before him: a black void in the depths of One For All. Only Nana
-- Shimura is clear; the others are draped in shifting colours, two of them
-- nothing but shadow; All Might stands there as a spirit; the first, Yoichi,
-- stands at the flame they all passed on. Far out, pieces of the ruined city
-- from the first user's time drift in the dark, and at the rim All For One's
-- tendrils reach in. The way in is easy to miss: the lone bench on a roof at
-- the north end of the city - rest there a while and you drift off. The way
-- out: the pale doorway behind where you woke (or off the edge: you wake up).
-- (In a function of its own: the main chunk is near Luau's local limit.)
---------------------------------------------------------------------------
;(function()
	local VR = {
		cfg = Config.VestigeRealm or {},
		inside = setmetatable({}, { __mode = "k" }), -- [player] = the character that went in
		busy = setmetatable({}, { __mode = "k" }),
		back = setmetatable({}, { __mode = "k" }), -- [player] = where to wake up
	}
	Kit.VR = VR
	if VR.cfg.Enabled == false then
		return
	end
	local CENTER = VR.cfg.Center or Vector3.new(2600, 1400, -2600)
	local O = CFrame.new(CENTER) -- (y = the floor's surface; the flame is off towards -Z)
	local ARRIVE = O * CFrame.new(0, 3.5, 66)
	local CORE = O * CFrame.new(0, 0, -22)
	local BENCH = VR.cfg.Bench or Vector3.new(39.3, 157.1, 1144.5)
	local WAKE = CFrame.lookAt(BENCH + Vector3.new(0, 2.6, -4), BENCH + Vector3.new(0, 2.6, -14))
	VR.ARRIVE, VR.CORE, VR.CENTER = ARRIVE, CORE, CENTER

	local model
	local function part(size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	-- looks only: nothing collides with it, rays pass through, no shadow
	local function ghost(p)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end
	local function disc(dia, h, cf, color, material)
		return part(Vector3.new(h, dia, dia), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
	end
	local function bar(a, b, thick, color, material)
		return part(Vector3.new(thick, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or Enum.Material.Neon)
	end

	-- A vestige: a figure of parts, feet at `at`, facing `look`. Look:
	-- "clear" (Nana: seen as she was), "colors" (draped in shifting colour:
	-- ForceField), "shadow" (a silhouette, nothing more), "spirit" (All
	-- Might, glowing), "first" (Yoichi: pale, a little see-through)
	local SKIN = Color3.fromRGB(236, 196, 164)
	local function vestige(spec, at, look)
		local fig = Instance.new("Model")
		fig.Name = "Vestige_" .. spec.Order
		fig:SetAttribute("VestigeName", spec.Name)
		fig:SetAttribute("VestigeTitle", spec.Title)
		fig:SetAttribute("VestigeLine", spec.Line)
		local S, W, A = spec.Scale or 1.6, spec.Bulk or 1, spec.Arms or 1
		local B = CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z))
		local colorIndex = 0
		local function paint(p, role)
			if spec.Look == "shadow" then
				p.Color = Color3.fromRGB(5, 5, 7)
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0
			elseif spec.Look == "colors" then
				colorIndex += 1
				p.Color = spec.Colors[(colorIndex - 1) % #spec.Colors + 1]
				p.Material = Enum.Material.ForceField
			elseif spec.Look == "spirit" then
				p.Color = role == "hair" and Color3.fromRGB(255, 226, 110) or Color3.fromRGB(255, 240, 196)
				p.Material = Enum.Material.ForceField
			elseif spec.Look == "first" then
				p.Color = role == "hair" and Color3.fromRGB(246, 246, 250) or role == "skin" and Color3.fromRGB(240, 232, 226) or Color3.fromRGB(214, 220, 232)
				p.Material = Enum.Material.Glass
				p.Transparency = 0.3
			else -- clear
				p.Color = spec.Palette and spec.Palette[role] or SKIN
			end
			ghost(p).Parent = fig
			return p
		end
		local function piece(size, off, role, shape)
			local p = part(size * S, B * CFrame.new(off * S), Color3.new(), nil, shape)
			return paint(p, role)
		end
		local function tilted(size, off, rot, role)
			local p = part(size * S, B * CFrame.new(off * S) * rot, Color3.new())
			return paint(p, role)
		end
		-- legs, torso, arms (a touch out from the body), head
		piece(Vector3.new(0.95, 2, 0.95), Vector3.new(-0.5 * W, 1, 0), "legs")
		piece(Vector3.new(0.95, 2, 0.95), Vector3.new(0.5 * W, 1, 0), "legs")
		piece(Vector3.new(2 * W, 2, 1.05 * W), Vector3.new(0, 3, 0), "body")
		tilted(Vector3.new(A, 2, A), Vector3.new(-(W + 0.5 * A + 0.05), 3, 0), CFrame.Angles(0, 0, math.rad(-7)), "arms")
		tilted(Vector3.new(A, 2, A), Vector3.new(W + 0.5 * A + 0.05, 3, 0), CFrame.Angles(0, 0, math.rad(7)), "arms")
		piece(Vector3.new(1.15, 1.15, 1.15), Vector3.new(0, 4.62, 0), "skin")
		for _, x in spec.Extra or {} do
			if x[1] == "hair" then
				piece(x[2], x[3], "hair")
			elseif x[1] == "spike" then
				tilted(x[2], x[3], CFrame.Angles(math.rad(x[4] or 0), 0, math.rad(x[5] or 0)), "hair")
			elseif x[1] == "cape" then
				tilted(x[2], x[3], CFrame.Angles(math.rad(-8), 0, 0), "cape")
			elseif x[1] == "coat" then
				piece(x[2], x[3], "coat")
			elseif x[1] == "smoke" then
				local p = piece(x[2], x[3], "smoke", Enum.PartType.Ball)
				p.Material = Enum.Material.SmoothPlastic
				p.Color = Color3.fromRGB(150, 150, 160)
				p.Transparency = 0.55
			end
		end
		-- a faint light on them in the dark (none on the shadows)
		if spec.Look ~= "shadow" then
			local anchor = ghost(part(Vector3.new(0.2, 0.2, 0.2), B * CFrame.new(0, 3 * S, -2.5 * S), Color3.new()))
			anchor.Transparency = 1
			anchor.Parent = fig
			local light = Instance.new("PointLight")
			light.Color = spec.Glow or Color3.fromRGB(190, 255, 220)
			light.Range = 9 * S
			light.Brightness = spec.Look == "spirit" and 2.4 or 1.1
			light.Shadows = false
			light.Parent = anchor
		end
		fig.Parent = model
		return fig
	end

	local VESTIGES = {
		{ Order = 1, Name = "YOICHI SHIGARAKI", Title = "The First", Line = "It started with him - a quirk to pass on.", Look = "first", Scale = 1.35,
			Extra = { { "hair", Vector3.new(1.3, 0.55, 1.3), Vector3.new(0, 5.25, 0.05) }, { "hair", Vector3.new(1.28, 0.9, 0.3), Vector3.new(0, 4.8, 0.55) } } },
		{ Order = 2, Name = "THE SECOND", Title = "Gearshift", Line = "A shadow. He hasn't shown you his face yet.", Look = "shadow", Scale = 1.7, Bulk = 1.15,
			Extra = { { "spike", Vector3.new(0.35, 1.1, 0.35), Vector3.new(-0.35, 5.5, 0), 0, 20 }, { "spike", Vector3.new(0.35, 1.2, 0.35), Vector3.new(0, 5.6, 0), -10, 0 }, { "spike", Vector3.new(0.35, 1.1, 0.35), Vector3.new(0.35, 5.5, 0), 0, -20 } } },
		{ Order = 3, Name = "THE THIRD", Title = "Fa Jin", Line = "A shadow - only the outline of him.", Look = "shadow", Scale = 1.65,
			Extra = { { "hair", Vector3.new(1.2, 0.4, 1.2), Vector3.new(0, 5.25, 0) }, { "hair", Vector3.new(0.9, 1.5, 0.3), Vector3.new(0, 4.4, 0.6) } } },
		{ Order = 4, Name = "HIKAGE SHINOMORI", Title = "The Fourth · Danger Sense", Line = "Draped in colours. He sees what's coming.", Look = "colors", Scale = 1.75,
			Colors = { Color3.fromRGB(80, 200, 220), Color3.fromRGB(140, 90, 230), Color3.fromRGB(60, 130, 255) },
			Extra = { { "coat", Vector3.new(2.3, 2.6, 1.25), Vector3.new(0, 2.2, 0) }, { "hair", Vector3.new(1.25, 0.35, 1.25), Vector3.new(0, 5.25, 0) } } },
		{ Order = 5, Name = "DAIGORO BANJO", Title = "The Fifth · Blackwhip", Line = "Draped in colours - loud, even like this.", Look = "colors", Scale = 1.75, Bulk = 1.3, Arms = 1.25,
			Colors = { Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 60, 90), Color3.fromRGB(255, 190, 70) },
			Extra = { { "hair", Vector3.new(1.4, 0.6, 1.4), Vector3.new(0, 5.35, 0) } } },
		{ Order = 6, Name = "EN", Title = "The Sixth · Smokescreen", Line = "Draped in colours, wrapped in smoke.", Look = "colors", Scale = 1.65,
			Colors = { Color3.fromRGB(170, 170, 255), Color3.fromRGB(110, 230, 170), Color3.fromRGB(200, 120, 255) },
			Extra = { { "smoke", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-0.7, 5.1, 0.2) }, { "smoke", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0.75, 5.3, 0) }, { "smoke", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 5.6, 0.3) } } },
		{ Order = 7, Name = "NANA SHIMURA", Title = "The Seventh · Float", Line = "The one you can see clearly. She's smiling.", Look = "clear", Scale = 1.6, Glow = Color3.fromRGB(255, 244, 220),
			Palette = { skin = SKIN, hair = Color3.fromRGB(22, 22, 28), body = Color3.fromRGB(40, 44, 78), arms = Color3.fromRGB(40, 44, 78), legs = Color3.fromRGB(34, 36, 60), cape = Color3.fromRGB(232, 232, 238) },
			Extra = { { "hair", Vector3.new(1.3, 0.5, 1.3), Vector3.new(0, 5.2, 0) }, { "hair", Vector3.new(1.3, 0.8, 0.35), Vector3.new(0, 4.75, 0.5) }, { "cape", Vector3.new(2.2, 3.6, 0.15), Vector3.new(0, 2.6, 0.72) } } },
		{ Order = 8, Name = "TOSHINORI YAGI", Title = "The Eighth · All Might", Line = "A spirit now. Still standing tall.", Look = "spirit", Scale = 1.85, Bulk = 1.35, Arms = 1.3, Glow = Color3.fromRGB(255, 226, 140),
			Extra = { { "hair", Vector3.new(1.25, 0.45, 1.25), Vector3.new(0, 5.2, 0) }, { "spike", Vector3.new(0.3, 1.6, 0.3), Vector3.new(-0.35, 5.8, -0.2), -25, 18 }, { "spike", Vector3.new(0.3, 1.6, 0.3), Vector3.new(0.35, 5.8, -0.2), -25, -18 } } },
	}

	function VR.build()
		model = Instance.new("Model")
		model.Name = "VestigeRealm"
		local rng = Random.new(58)
		local VOID = Color3.fromRGB(5, 6, 9)
		local OFA = Color3.fromRGB(150, 255, 190)
		local GOLD = Color3.fromRGB(255, 226, 150)
		-- the floor: black glass, nothing past the dark
		local floor = disc(360, 2, O * CFrame.new(0, -1, 0), VOID, Enum.Material.Glass)
		floor.Name = "Floor"
		floor.Reflectance = 0.12
		-- light pooled on the floor under the flame, and where you wake
		for i, r in { 7, 13, 22, 34, 50 } do
			local pool = ghost(disc(r * 2, 0.05, CORE * CFrame.new(0, 0.02 * i, 0), OFA, Enum.Material.Neon))
			pool.Transparency = 0.86 + i * 0.02
		end
		for i, r in { 4, 9, 16 } do
			local pool = ghost(disc(r * 2, 0.05, ARRIVE * CFrame.new(0, -3.5 + 0.02 * i, 0), GOLD, Enum.Material.Neon))
			pool.Transparency = 0.9 + i * 0.02
		end
		-- ripples: faint rings out across the glass round the flame
		for _, r in { 16, 38, 66, 100 } do
			local n = math.max(24, math.floor(r * 0.9))
			for k = 1, n do
				local a0, a1 = (k - 1) / n * math.pi * 2, k / n * math.pi * 2
				local p0 = (CORE * CFrame.new(math.sin(a0) * r, 0.06, math.cos(a0) * r)).Position
				local p1 = (CORE * CFrame.new(math.sin(a1) * r, 0.06, math.cos(a1) * r)).Position
				local seg = ghost(bar(p0, p1, 0.12, OFA))
				seg.Transparency = 0.55 + r / 260
			end
		end
		-- THE FLAME: One For All itself - a column of light going up out of
		-- sight, a heart of it at head height, rings of it turning
		local pillar = ghost(disc(3.2, 190, CORE * CFrame.new(0, 95, 0), OFA, Enum.Material.Neon))
		pillar.Transparency = 0.45
		pillar.Name = "Flame"
		local halo = ghost(disc(9, 190, CORE * CFrame.new(0, 95, 0), OFA, Enum.Material.ForceField))
		halo.Transparency = 0.2
		local heart = ghost(part(Vector3.new(7, 7, 7), CORE * CFrame.new(0, 9, 0), Color3.fromRGB(230, 255, 236), Enum.Material.Neon, Enum.PartType.Ball))
		heart.Name = "Heart"
		heart.Transparency = 0.15
		local light = Instance.new("PointLight")
		light.Color = OFA
		light.Range = 60
		light.Brightness = 3
		light.Parent = heart
		for i = 1, 3 do
			local ringR = 6 + i * 3
			local n = 28
			local tilt = CORE * CFrame.new(0, 9, 0) * CFrame.Angles(math.rad(70 + i * 12), math.rad(i * 50), 0)
			for k = 1, n do
				local a0, a1 = (k - 1) / n * math.pi * 2, k / n * math.pi * 2
				local seg = ghost(bar((tilt * CFrame.new(math.sin(a0) * ringR, 0, math.cos(a0) * ringR)).Position, (tilt * CFrame.new(math.sin(a1) * ringR, 0, math.cos(a1) * ringR)).Position, 0.25, i == 2 and GOLD or OFA))
				seg.Transparency = 0.25
				seg.Name = "FlameRing" .. i
			end
		end
		-- THE VESTIGES: the first at the flame, the rest round behind it in
		-- a half-circle, all looking your way
		local look = ARRIVE.Position
		vestige(VESTIGES[1], (CORE * CFrame.new(0, 0, 7)).Position, look)
		for i = 2, 8 do
			local a = math.rad(-78 + (i - 2) * 26)
			vestige(VESTIGES[i], (CORE * CFrame.new(math.sin(a) * 30, 0, -math.cos(a) * 30 + 6)).Position, look)
		end
		-- the first user's time: pieces of a ruined city adrift in the dark
		for i = 1, 22 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(110, 230)
			local at = O * CFrame.new(math.sin(a) * r, rng:NextNumber(-30, 110), math.cos(a) * r - 20)
			local w, h, d = rng:NextNumber(8, 26), rng:NextNumber(2, 5), rng:NextNumber(6, 18)
			local tone = rng:NextInteger(38, 70)
			local slab = ghost(part(Vector3.new(w, h, d), at * CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 6.28), rng:NextNumber(-0.7, 0.7)), Color3.fromRGB(tone, tone, tone + 6), Enum.Material.Concrete))
			slab.Name = "Memory"
			if i % 4 == 0 then
				-- a wall of a building, still standing on the slab, its windows dark
				local wall = ghost(part(Vector3.new(w * 0.8, h * 4, 1.2), slab.CFrame * CFrame.new(0, h * 2.5, 0), Color3.fromRGB(tone + 10, tone + 8, tone + 4), Enum.Material.Concrete))
				wall.Name = "Memory"
				for wx = -1, 1 do
					for wy = 0, 1 do
						local win = ghost(part(Vector3.new(w * 0.14, h * 0.7, 1.4), wall.CFrame * CFrame.new(wx * w * 0.22, (wy - 0.2) * h * 1.3, 0), Color3.fromRGB(12, 12, 16)))
						win.Name = "Memory"
					end
				end
			end
		end
		-- ALL FOR ONE, reaching in at the rim: red-black tendrils up out of the dark
		for i = 1, 7 do
			local a = math.rad(-140 + (i - 1) * 16 + rng:NextNumber(-4, 4))
			local r = rng:NextNumber(150, 176)
			local p = (O * CFrame.new(math.sin(a) * r, -30, -math.cos(a) * r)).Position
			local inward = (Vector3.new(CENTER.X, p.Y, CENTER.Z) - p).Unit
			local side = inward:Cross(Vector3.new(0, 1, 0))
			for k = 1, 9 do
				local q = p + inward * 3.2 + Vector3.new(0, 11, 0) + side * math.sin(k * 0.9 + i) * 3.5
				local t = ghost(bar(p, q, math.max(3.4 - k * 0.32, 0.5), k % 2 == 0 and Color3.fromRGB(120, 8, 24) or Color3.fromRGB(34, 4, 10)))
				t.Name = "Tendril"
				p = q
			end
		end
		-- THE WAY OUT: a pale doorway of light just behind where you woke
		local doorAt = ARRIVE * CFrame.new(0, 4.5, 16)
		for _, x in { -5.6, 5.6 } do
			local post = ghost(part(Vector3.new(0.8, 17, 0.8), doorAt * CFrame.new(x, 0, 0), GOLD, Enum.Material.Neon))
			post.Transparency = 0.35
		end
		local door = part(Vector3.new(10.4, 16, 0.6), doorAt, Color3.fromRGB(255, 246, 222), Enum.Material.Neon)
		door.Name = "WakeDoor"
		door.Transparency = 0.62
		door.CanCollide = false
		door.CanQuery = false
		door.CastShadow = false
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(220, 40)
		tag.StudsOffset = Vector3.new(0, 10.5, 0)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamMedium
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 244, 220)
		text.TextTransparency = 0.25
		text.Text = "wake up"
		text.Parent = tag
		tag.Parent = door
		door.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if plr and VR.inside[plr] then
				VR.leave(plr)
			end
		end)
		VR.door = door
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model.Parent = workspace
		VR.model = model
	end

	-- THE WAY IN: an ember over the rooftop bench, barely there. Rest a while.
	function VR.buildWay()
		local folder = Instance.new("Folder")
		folder.Name = "VestigeWay"
		local ember = Instance.new("Part")
		ember.Name = "Ember"
		ember.Shape = Enum.PartType.Ball
		ember.Size = Vector3.new(0.28, 0.28, 0.28)
		ember.CFrame = CFrame.new(BENCH + Vector3.new(0.4, 1.9, 0.2))
		ember.Color = Color3.fromRGB(150, 255, 190)
		ember.Material = Enum.Material.Neon
		ember.Anchored = true
		ember.CanCollide = false
		ember.CanQuery = false
		ember.CanTouch = false
		ember.CastShadow = false
		ember.Parent = folder
		local glow = Instance.new("PointLight")
		glow.Color = ember.Color
		glow.Range = 5
		glow.Brightness = 1.1
		glow.Parent = ember
		local motes = Instance.new("ParticleEmitter")
		motes.Rate = 2
		motes.Lifetime = NumberRange.new(1.6, 2.6)
		motes.Speed = NumberRange.new(0.3, 0.7)
		motes.SpreadAngle = Vector2.new(40, 40)
		motes.Size = NumberSequence.new(0.1, 0)
		motes.Color = ColorSequence.new(Color3.fromRGB(170, 255, 200), Color3.fromRGB(255, 230, 150))
		motes.LightEmission = 1
		motes.Parent = ember
		local seat = Instance.new("Part")
		seat.Name = "RestSpot"
		seat.Size = Vector3.new(1, 1, 1)
		seat.CFrame = CFrame.new(BENCH + Vector3.new(0, 0.4, 0))
		seat.Transparency = 1
		seat.Anchored = true
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Rest"
		prompt.ActionText = "Rest a while"
		prompt.ObjectText = ""
		prompt.HoldDuration = VR.cfg.RestTime or 2
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
		prompt.Triggered:Connect(function(plr)
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - BENCH).Magnitude < 12 then
				VR.enter(plr, WAKE)
			end
		end)
		folder.Parent = workspace
		VR.way = folder
	end

	-- drifting off: the screen goes dark, you wake up inside One For All
	function VR.enter(player, backTo)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not alive(char) or VR.inside[player] or VR.busy[player] or not model then
			return false
		end
		VR.busy[player] = true
		VR.back[player] = backTo or root.CFrame
		PlayVFX:FireClient(player, "VestigeIn", nil, {})
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(ARRIVE.Position, 3)
			end)
			task.wait(1.3)
			VR.busy[player] = nil
			if player.Character ~= char or not alive(char) or not root.Parent then
				return
			end
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 2)
			char:PivotTo(ARRIVE)
			root.AssemblyLinearVelocity = Vector3.zero
			VR.inside[player] = char
			player:SetAttribute("InVestige", true)
		end)
		return true
	end

	-- waking up: back where you dozed off
	function VR.leave(player)
		if not VR.inside[player] or VR.busy[player] then
			return false
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local back = VR.back[player] or WAKE
		VR.busy[player] = true
		PlayVFX:FireClient(player, "VestigeOut", nil, {})
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(back.Position, 3)
			end)
			task.wait(1.1)
			VR.busy[player] = nil
			VR.inside[player] = nil
			player:SetAttribute("InVestige", nil)
			if root and root.Parent and alive(char) and player.Character == char then
				iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 1.5)
				char:PivotTo(back)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		return true
	end

	-- (testers: straight in, or straight out)
	function TestCommands.Vestige(player)
		if VR.inside[player] then
			VR.leave(player)
		else
			VR.enter(player)
		end
	end

	local ok, err = pcall(VR.build)
	if not ok then
		warn("[VestigeRealm] " .. tostring(err))
	end
	ok, err = pcall(VR.buildWay)
	if not ok then
		warn("[VestigeRealm] " .. tostring(err))
	end
	-- off the edge of the glass: you wake up. A new body (you died in there)
	-- starts back in the city.
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < 0.25 then
			return
		end
		last = now
		for plr, char in VR.inside do
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not plr.Parent then
				VR.inside[plr] = nil
			elseif plr.Character ~= char or not alive(char) then
				if plr.Character ~= char then
					VR.inside[plr] = nil
					plr:SetAttribute("InVestige", nil)
				end
			elseif root and root.Position.Y < CENTER.Y - 40 then
				VR.leave(plr)
			end
		end
	end)
end)()

---------------------------------------------------------------------------
-- (round 71) DEKU'S MEMORIES (Config.DekuMemories), off the vestige realm.
-- A lone door stands in the dark of the realm: the huge "barrier-free" door
-- of Class 1-A, open, warm light spilling out of it. Through it, U.A. High,
-- Class 1-A: the desks in their rows (Midoriya's behind Bakugo's), the
-- class-rep vote still on the board, Aizawa asleep in his sleeping bag. The
-- room's big door opens onto the U.A. Sports Festival stadium - the white
-- bowl of seats, the blue wall and its banners, the screens on the rim, the
-- two-tier stage with its torches. Step up onto the stage and the memory
-- plays on your screen (MemoryFight): Midoriya vs Todoroki. The tunnel out
-- of the stadium (and the classroom's small back door) lead back into the
-- realm. You're still "inside" all the while (Kit.VR): off the edge of any
-- of it, you wake up.
-- (In a function of its own: the main chunk is near Luau's local limit.)
---------------------------------------------------------------------------
;(function()
	local VR = Kit.VR
	local cfg = Config.DekuMemories or {}
	local weak = { __mode = "k" }
	local DM = {
		at = setmetatable({}, weak), -- [player] = "Classroom" | "Stadium"
		busy = setmetatable({}, weak),
		last = setmetatable({}, weak), -- [player] = where they were a moment ago
		stage = setmetatable({}, weak), -- [player] = true while they're up on the stage
		again = setmetatable({}, weak), -- [player] = when the stage plays it for them again
	}
	Kit.DM = DM
	if cfg.Enabled == false or not VR or not VR.CENTER then
		return
	end
	local CENTER = VR.CENTER
	local ROOM = CFrame.new(CENTER + (cfg.Classroom or Vector3.new(0, 0, -900)))
	local ARENA = CFrame.new(CENTER + (cfg.Stadium or Vector3.new(0, 0, -1800)))
	-- the door in the realm, off to the side of where you wake, facing you
	local gateAt = CENTER + Vector3.new(-38, 0, 40)
	local GATE = CFrame.lookAt(gateAt, Vector3.new(VR.ARRIVE.X, gateAt.Y, VR.ARRIVE.Z))
	local STAGE_TOP, STAGE_HALF = 3.2, 27
	local FIELD = 100 -- (the sand's radius; the stands rise from just past it)
	DM.ROOM, DM.ARENA, DM.GATE, DM.STAGE_TOP, DM.STAGE_HALF = ROOM, ARENA, GATE, STAGE_TOP, STAGE_HALF
	local function facing(at, dir)
		return CFrame.lookAt(at, at + dir)
	end
	DM.SPOTS = {
		Classroom = facing((ROOM * CFrame.new(0, 3.5, 29)).Position, Vector3.new(0, 0, -1)),
		Stadium = facing((ARENA * CFrame.new(0, 3.5, FIELD + 30)).Position, Vector3.new(0, 0, -1)),
		Realm = facing((GATE * CFrame.new(0, 3.5, -9)).Position, GATE.LookVector),
	}
	-- the doorways: walk through one (either way) and the memory changes
	DM.doors = {
		{ Name = "Gate", CF = GATE, W = 5, H = 16, To = "Classroom" },
		{ Name = "ClassDoor", CF = ROOM * CFrame.new(30.5, 0, -25) * CFrame.Angles(0, math.rad(90), 0), W = 5, H = 16.5, To = "Stadium" },
		{ Name = "BackDoor", CF = ROOM * CFrame.new(30.5, 0, 26) * CFrame.Angles(0, math.rad(90), 0), W = 3.2, H = 9, To = "Realm" },
		{ Name = "Tunnel", CF = ARENA * CFrame.new(0, 0, FIELD + 54), W = 6, H = 12, To = "Realm" },
	}

	local model, holder
	local function part(size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = holder
		return p
	end
	-- looks only: nothing collides with it, rays pass through, no shadow
	local function deco(p)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end
	-- words painted on a face of a part
	local function paint(p, face, text, color, font, bg)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = bg and 0 or 1
		t.BackgroundColor3 = bg or Color3.new(0, 0, 0)
		t.BorderSizePixel = 0
		t.TextScaled = true
		t.TextWrapped = true
		t.Font = font or Enum.Font.GothamBlack
		t.TextColor3 = color
		t.Text = text
		t.Parent = gui
		gui.Parent = p
		return t
	end
	-- a name that comes up over something as you walk up to it
	local function tag(p, name, line, far, y)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(260, line and 56 or 30)
		bb.StudsOffsetWorldSpace = Vector3.new(0, y or 3, 0)
		bb.MaxDistance = far or 14
		bb.LightInfluence = 0
		local a = Instance.new("TextLabel")
		a.Name = "Name"
		a.Size = UDim2.new(1, 0, 0, 26)
		a.BackgroundTransparency = 1
		a.Font = Enum.Font.GothamBlack
		a.TextSize = 20
		a.TextColor3 = Color3.new(1, 1, 1)
		a.TextStrokeTransparency = 0.5
		a.Text = name
		a.Parent = bb
		if line then
			local b = Instance.new("TextLabel")
			b.Name = "Line"
			b.Position = UDim2.fromOffset(0, 26)
			b.Size = UDim2.new(1, 0, 0, 30)
			b.BackgroundTransparency = 1
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 13
			b.TextWrapped = true
			b.TextColor3 = Color3.fromRGB(255, 236, 196)
			b.TextStrokeTransparency = 0.6
			b.Text = line
			b.Parent = bb
		end
		bb.Parent = p
		return bb
	end
	local function glow(p, color, face, range, brightness)
		local l = Instance.new("SurfaceLight")
		l.Face = face or Enum.NormalId.Front
		l.Color = color
		l.Range = range or 16
		l.Brightness = brightness or 1.5
		l.Angle = 120
		l.Shadows = false
		l.Parent = p
		return l
	end
	local function motes(p, rate, color)
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = rate or 4
		pe.Lifetime = NumberRange.new(5, 9)
		pe.Speed = NumberRange.new(0.2, 0.6)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.14), NumberSequenceKeypoint.new(1, 0) })
		pe.Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 200))
		pe.LightEmission = 0.7
		pe.Parent = p
		return pe
	end
	local WARM = Color3.fromRGB(255, 240, 214)
	local OFA = Color3.fromRGB(150, 255, 190)
	local CREAM = Color3.fromRGB(236, 228, 206)
	local WOOD = Color3.fromRGB(160, 116, 74)
	local DOOR = Color3.fromRGB(212, 216, 220)

	---------------------------------------------------------------- the door in the realm
	-- a piece of a school corridor adrift in the dark: a stretch of wall, the
	-- floor in front of it, and the huge 1-A door slid wide open
	function DM.buildGate()
		holder = Instance.new("Model")
		holder.Name = "Gate"
		holder.Parent = model
		local G = function(x, y, z)
			return GATE * CFrame.new(x, y, z)
		end
		part(Vector3.new(34, 0.4, 12), G(3, 0.2, -3), Color3.fromRGB(196, 200, 188), Enum.Material.SmoothPlastic).Name = "CorridorFloor"
		for _, s in { { -10.4, 9.2 }, { 12.1, 12.6 } } do
			part(Vector3.new(s[2], 21, 1), G(s[1], 10.5, 0.9), CREAM)
			deco(part(Vector3.new(s[2], 1.2, 1.1), G(s[1], 0.6, 0.85), WOOD))
		end
		part(Vector3.new(11.6, 3.6, 1), G(0, 19.2, 0.9), CREAM)
		for _, x in { -5.8, 5.8 } do
			part(Vector3.new(0.8, 17.5, 1.3), G(x, 8.75, 0.9), WOOD)
		end
		part(Vector3.new(12.4, 0.8, 1.3), G(0, 17.4, 0.9), WOOD)
		-- the door itself, slid open along the wall: "1-A" on it, huge
		local panel = part(Vector3.new(10.6, 17, 0.5), G(11.6, 8.7, 0.1), DOOR)
		panel.Name = "Panel"
		paint(panel, Enum.NormalId.Front, "1-A", Color3.fromRGB(46, 52, 78), Enum.Font.GothamBlack)
		-- the little room plate sticking out over the door
		local plate = part(Vector3.new(0.3, 1.4, 3.2), G(-7.6, 18.2, -0.6), Color3.fromRGB(246, 246, 240))
		paint(plate, Enum.NormalId.Left, "1-A", Color3.fromRGB(30, 34, 50))
		paint(plate, Enum.NormalId.Right, "1-A", Color3.fromRGB(30, 34, 50))
		-- the light of the memory, spilling out of the doorway
		local light = deco(part(Vector3.new(10.4, 16.6, 0.3), G(0, 8.5, 1.1), WARM, Enum.Material.Neon))
		light.Name = "Light"
		light.Transparency = 0.45
		glow(light, WARM, Enum.NormalId.Front, 26, 2)
		motes(light, 5)
		tag(light, "DEKU'S MEMORIES", "U.A. High - Class 1-A", 70, 11)
	end

	---------------------------------------------------------------- Class 1-A
	-- the seats, in their order (column 1 by the windows, front to back)
	DM.CLASS = {
		{ "AOYAMA", "Sparkling. Of course." }, { "ASHIDO" }, { "ASUI", "\"Call me Tsu.\"" }, { "IIDA", "Squared perfectly to the board." },
		{ "URARAKA", "She's the one who made \"Deku\" mean \"you can do it\"." },
		{ "OJIRO" }, { "KAMINARI", "Wheyyy." }, { "KIRISHIMA", "Unbreakable." }, { "KODA" }, { "SATO" },
		{ "SHOJI" }, { "JIRO" }, { "SERO" }, { "TOKOYAMI" }, { "TODOROKI", "Half cold, half hot. He only ever used the one side." },
		{ "HAGAKURE", "The chair's pulled out. She's here - you just can't see her." }, { "BAKUGO", "Boot marks on the desk. Feet up, every day." },
		{ "MIDORIYA", "His notebook's still out: Hero Analysis for the Future." }, { "MINETA", "Something purple and sticky under the desk." },
		{ "YAOYOROZU", "Vice-rep." },
	}
	function DM.buildClassroom()
		holder = Instance.new("Model")
		holder.Name = "Classroom"
		holder.Parent = model
		local R = function(x, y, z)
			return ROOM * CFrame.new(x, y, z)
		end
		local floor = part(Vector3.new(62, 1, 74), R(0, -0.5, 0), Color3.fromRGB(184, 140, 98), Enum.Material.WoodPlanks)
		floor.Name = "Floor"
		part(Vector3.new(62, 1, 74), R(0, 23.5, 0), Color3.fromRGB(238, 238, 234))
		part(Vector3.new(62, 24, 1), R(0, 11.5, 36.5), CREAM)
		part(Vector3.new(62, 24, 1), R(0, 11.5, -36.5), CREAM)
		-- the corridor wall: the big door at the front, the small one at the back
		part(Vector3.new(1, 24, 6), R(30.5, 11.5, -33), CREAM)
		part(Vector3.new(1, 6.5, 10), R(30.5, 20.25, -25), CREAM)
		part(Vector3.new(1, 24, 43), R(30.5, 11.5, 1.5), CREAM)
		part(Vector3.new(1, 15, 6.4), R(30.5, 16, 26), CREAM)
		part(Vector3.new(1, 24, 6.8), R(30.5, 11.5, 32.6), CREAM)
		-- the window wall: glass from waist height, the sky outside
		part(Vector3.new(1, 4, 74), R(-30.5, 2, 0), CREAM)
		part(Vector3.new(1, 6, 74), R(-30.5, 20.5, 0), CREAM)
		local glass = part(Vector3.new(0.3, 14, 72), R(-30.5, 11, 0), Color3.fromRGB(206, 228, 246), Enum.Material.Glass)
		glass.Transparency = 0.6
		glass.Name = "Windows"
		for z = -36, 36, 12 do
			part(Vector3.new(0.9, 14, 0.8), R(-30.3, 11, z), Color3.fromRGB(196, 198, 200), Enum.Material.Metal)
		end
		part(Vector3.new(0.9, 0.6, 72), R(-30.3, 13.5, 0), Color3.fromRGB(196, 198, 200), Enum.Material.Metal)
		-- sunlight through the windows
		for z = -24, 24, 16 do
			local beam = deco(part(Vector3.new(0.2, 26, 9), R(-18, 8, z) * CFrame.Angles(0, 0, math.rad(-58)), Color3.fromRGB(255, 244, 214), Enum.Material.Neon))
			beam.Transparency = 0.93
			beam.Name = "Sunbeam"
		end
		-- wood trim round the room
		for _, t in { { Vector3.new(60, 3.2, 0.3), R(0, 1.6, 35.9) }, { Vector3.new(60, 3.2, 0.3), R(0, 1.6, -35.9) }, { Vector3.new(0.3, 3.2, 72), R(29.9, 1.6, 0) } } do
			deco(part(t[1], t[2], WOOD, Enum.Material.Wood))
		end
		-- the front: a raised platform, the podium, the board
		part(Vector3.new(44, 0.6, 9), R(0, 0.3, -31.5), Color3.fromRGB(150, 108, 70), Enum.Material.WoodPlanks)
		local podium = part(Vector3.new(6, 4, 3), R(0, 2.6, -28.5), Color3.fromRGB(142, 98, 60), Enum.Material.Wood)
		podium.Name = "Podium"
		part(Vector3.new(37, 12.2, 0.3), R(0, 11, -35.85), WOOD, Enum.Material.Wood)
		local board = part(Vector3.new(36, 11, 0.4), R(0, 11, -35.6), Color3.fromRGB(38, 72, 54))
		board.Name = "Blackboard"
		paint(board, Enum.NormalId.Back, "CLASS REP ELECTION\nMIDORIYA  III     YAOYOROZU  II\n\nHero Basic Training - 1:00", Color3.fromRGB(236, 238, 228), Enum.Font.PatrickHand)
		part(Vector3.new(36, 0.3, 0.9), R(0, 5.3, -35.2), WOOD, Enum.Material.Wood)
		local clock = part(Vector3.new(0.3, 2.6, 2.6), R(0, 19.5, -35.9) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(246, 246, 242), nil, Enum.PartType.Cylinder)
		deco(clock).Name = "Clock"
		-- lights in the ceiling
		for _, x in { -15, 15 } do
			for _, z in { -20, 0, 20 } do
				local l = deco(part(Vector3.new(8, 0.3, 2), R(x, 22.8, z), Color3.fromRGB(252, 250, 240), Enum.Material.Neon))
				glow(l, Color3.fromRGB(255, 248, 232), Enum.NormalId.Bottom, 26, 0.9)
			end
		end
		-- the cubbies along the back
		part(Vector3.new(58, 5, 2), R(0, 2.5, 34.8), Color3.fromRGB(150, 170, 160))
		-- THE DESKS: four columns of five, in the class's order
		local cols, rows = { -18, -6, 6, 18 }, { -17, -8, 1, 10, 19 }
		for i, who in DM.CLASS do
			local x, z = cols[math.floor((i - 1) / 5) + 1], rows[(i - 1) % 5 + 1]
			local top = part(Vector3.new(4.2, 0.35, 3), R(x, 2.75, z), Color3.fromRGB(206, 170, 120), Enum.Material.Wood)
			top.Name = "Desk_" .. i
			top:SetAttribute("Student", who[1])
			part(Vector3.new(4, 2.4, 0.2), R(x, 1.4, z - 1.4), Color3.fromRGB(140, 146, 150), Enum.Material.Metal)
			for _, s in { -1, 1 } do
				part(Vector3.new(0.2, 2.6, 2.8), R(x + s * 1.95, 1.3, z), Color3.fromRGB(140, 146, 150), Enum.Material.Metal)
			end
			-- the chair behind it (Hagakure's pulled right out)
			local out = who[1] == "HAGAKURE" and 1.6 or 0
			part(Vector3.new(2.6, 0.3, 2.4), R(x, 1.6, z + 2.8 + out), Color3.fromRGB(196, 158, 108), Enum.Material.Wood)
			part(Vector3.new(2.6, 2.2, 0.25), R(x, 2.9, z + 4 + out), Color3.fromRGB(196, 158, 108), Enum.Material.Wood)
			for _, s in { -1, 1 } do
				part(Vector3.new(0.2, 1.5, 2.2), R(x + s * 1.2, 0.75, z + 2.8 + out), Color3.fromRGB(140, 146, 150), Enum.Material.Metal)
			end
			tag(top, i .. " · " .. who[1], who[2], 13, 2.6)
			if who[1] == "MIDORIYA" then
				local book = deco(part(Vector3.new(1.5, 0.12, 2), R(x - 0.4, 2.99, z + 0.1) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(240, 236, 216)))
				book.Name = "Notebook"
				paint(book, Enum.NormalId.Top, "HERO ANALYSIS FOR THE FUTURE", Color3.fromRGB(40, 44, 60), Enum.Font.GothamBold)
			end
		end
		-- AIZAWA, asleep in his yellow sleeping bag by the door
		local bag = part(Vector3.new(6.4, 2.2, 2.2), R(24, 1.1, -29.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(238, 200, 52), nil, Enum.PartType.Cylinder)
		bag.Name = "SleepingBag"
		part(Vector3.new(2.2, 2.2, 2.2), R(24, 1.1, -26.3), Color3.fromRGB(238, 200, 52), nil, Enum.PartType.Ball)
		deco(part(Vector3.new(0.1, 0.1, 6), R(24.6, 2.15, -29.5), Color3.fromRGB(120, 100, 40)))
		local head = part(Vector3.new(1.3, 1.3, 1.3), R(24, 1.1, -33.2), Color3.fromRGB(232, 198, 172))
		head.Name = "Aizawa"
		for _, h in { { 0, 0.55, -0.1, 1 }, { 0.45, 0.25, -0.3, 0.8 }, { -0.45, 0.25, -0.3, 0.8 }, { 0, 0.2, -0.6, 0.9 } } do
			deco(part(Vector3.one * h[4], R(24 + h[1], 1.1 + h[2], -33.2 + h[3]), Color3.fromRGB(26, 24, 28), nil, Enum.PartType.Ball))
		end
		deco(part(Vector3.new(1.9, 0.6, 0.8), R(24, 0.9, -32.4), Color3.fromRGB(196, 196, 202)))
		tag(head, "AIZAWA-SENSEI", "\"It took you eight seconds to settle down. Not rational.\"", 16, 2.4)
		-- the big door: slid open, and the memory after this one past it
		for _, z in { -30.4, -19.6 } do
			part(Vector3.new(1.4, 17.5, 0.8), R(30.5, 8.75, z), WOOD, Enum.Material.Wood)
		end
		part(Vector3.new(1.4, 0.8, 11.6), R(30.5, 17.4, -25), WOOD, Enum.Material.Wood)
		local panel = part(Vector3.new(0.5, 17, 10.6), R(29.4, 8.7, -14.4), DOOR)
		panel.Name = "Panel"
		paint(panel, Enum.NormalId.Left, "1-A", Color3.fromRGB(46, 52, 78))
		local light = deco(part(Vector3.new(0.3, 16.6, 10.2), R(31, 8.4, -25), WARM, Enum.Material.Neon))
		light.Name = "ToStadium"
		light.Transparency = 0.45
		glow(light, WARM, Enum.NormalId.Left, 22, 1.6)
		tag(light, "THE SPORTS FESTIVAL", "through the door", 40, 10)
		-- the little door at the back: back into One For All
		for _, z in { 22.6, 29.4 } do
			part(Vector3.new(1.2, 9.4, 0.6), R(30.5, 4.7, z), WOOD, Enum.Material.Wood)
		end
		local back = deco(part(Vector3.new(0.3, 9, 6.4), R(31, 4.5, 26), OFA, Enum.Material.Neon))
		back.Name = "ToRealm"
		back.Transparency = 0.55
		tag(back, "back to One For All", nil, 24, 6)
		-- dust turning in the sunlight
		local air = deco(part(Vector3.new(56, 16, 68), R(0, 10, 0), WARM))
		air.Transparency = 1
		air.Name = "Air"
		motes(air, 7)
	end

	---------------------------------------------------------------- the stadium
	function DM.buildStadium()
		holder = Instance.new("Model")
		holder.Name = "Stadium"
		holder.Parent = model
		local A = function(x, y, z)
			return ARENA * CFrame.new(x, y, z)
		end
		-- round the bowl: a CFrame at angle a (0 = the tunnel), r out, y up
		local function around(a, r, y)
			return ARENA * CFrame.Angles(0, a, 0) * CFrame.new(0, y, r)
		end
		local N = 60
		local function width(r)
			return 2 * r * math.tan(math.pi / N) + 0.3
		end
		local field = part(Vector3.new(1, FIELD * 2 + 2, FIELD * 2 + 2), A(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(222, 196, 150), Enum.Material.Sand, Enum.PartType.Cylinder)
		field.Name = "Field"
		local BANNERS = { Color3.fromRGB(214, 46, 52), Color3.fromRGB(244, 196, 48), Color3.fromRGB(60, 170, 90), Color3.fromRGB(240, 240, 240), Color3.fromRGB(240, 130, 40) }
		local WORDS = { "PLUS ULTRA", "U.A.", "GO BEYOND", "HERO", "U.A. HIGH" }
		for k = 0, N - 1 do
			local a = k / N * math.pi * 2
			local tunnel = k == 0
			if not tunnel then
				-- the blue wall round the field, and the banners on it
				part(Vector3.new(width(FIELD + 1.5), 8, 1.5), around(a, FIELD + 1.5, 4), Color3.fromRGB(36, 84, 184))
				if k % 3 == 1 then
					local n = (math.floor(k / 3) % #BANNERS) + 1
					local b = deco(part(Vector3.new(width(FIELD + 0.6) * 0.82, 4.4, 0.2), around(a, FIELD + 0.6, 4.2), BANNERS[n]))
					paint(b, Enum.NormalId.Front, WORDS[n], n == 4 and Color3.fromRGB(36, 84, 184) or Color3.new(1, 1, 1))
				end
			end
			-- the seats: tier on tier of white (over the tunnel, only above its roof)
			for i = 0, 10 do
				local r, h = FIELD + 6 + i * 6, 9 + i * 3.3
				local color = i % 2 == 0 and Color3.fromRGB(242, 242, 246) or Color3.fromRGB(224, 226, 232)
				if not tunnel then
					part(Vector3.new(width(r + 3), h, 6.2), around(a, r, h / 2), color, Enum.Material.SmoothPlastic)
				elseif h > 13.5 then
					part(Vector3.new(width(r + 3), h - 13.5, 6.2), around(a, r, (h + 13.5) / 2), color, Enum.Material.SmoothPlastic)
				end
			end
			-- the rim
			part(Vector3.new(width(FIELD + 74), 3, 4), around(a, FIELD + 70, 45.5), Color3.fromRGB(96, 102, 118), Enum.Material.Metal)
		end
		-- the two big screens on the rim, over the far side
		for _, deg in { -40, 40 } do
			local a = math.rad(deg)
			local frame = part(Vector3.new(46, 26, 2), around(a, FIELD + 64, 62), Color3.fromRGB(28, 30, 38), Enum.Material.Metal)
			frame.Name = "Screen"
			for _, x in { -14, 14 } do
				part(Vector3.new(2, 16, 2), around(a, FIELD + 65, 44) * CFrame.new(x, 0, 0), Color3.fromRGB(70, 74, 86), Enum.Material.Metal)
			end
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 12
			local function box(x, w, bg, text, size)
				local f = Instance.new("TextLabel")
				f.Position = UDim2.fromScale(x, 0.24)
				f.Size = UDim2.fromScale(w, 0.7)
				f.BackgroundColor3 = bg
				f.BorderSizePixel = 0
				f.Font = Enum.Font.GothamBlack
				f.TextScaled = true
				f.TextColor3 = Color3.new(1, 1, 1)
				f.Text = text
				f.Parent = gui
				return f
			end
			box(0.03, 0.43, Color3.fromRGB(40, 140, 96), "MIDORIYA")
			box(0.54, 0.43, Color3.fromRGB(196, 50, 54), "TODOROKI")
			local vs = box(0.43, 0.14, Color3.fromRGB(20, 20, 26), "VS")
			vs.TextColor3 = Color3.fromRGB(255, 220, 90)
			local top = Instance.new("TextLabel")
			top.Size = UDim2.fromScale(1, 0.2)
			top.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
			top.BorderSizePixel = 0
			top.Font = Enum.Font.GothamBlack
			top.TextScaled = true
			top.TextColor3 = Color3.fromRGB(255, 220, 90)
			top.Text = "U.A. SPORTS FESTIVAL - FINAL TOURNAMENT"
			top.Parent = gui
			gui.Parent = frame
		end
		-- THE STAGE: two tiers of pale concrete tiles, stairs front and back
		local lower = part(Vector3.new(64, 1.6, 64), A(0, 0.8, 0), Color3.fromRGB(170, 182, 172), Enum.Material.Concrete)
		lower.Name = "StageLower"
		local stage = part(Vector3.new(54, 1.6, 54), A(0, 2.4, 0), Color3.fromRGB(186, 198, 188), Enum.Material.Concrete)
		stage.Name = "Stage"
		for i = -4, 4 do
			deco(part(Vector3.new(0.18, 0.06, 54), A(i * 6, 3.23, 0), Color3.fromRGB(120, 132, 124)))
			deco(part(Vector3.new(54, 0.06, 0.18), A(0, 3.23, i * 6), Color3.fromRGB(120, 132, 124)))
		end
		for _, s in { -1, 1 } do
			part(Vector3.new(14, 0.8, 1.6), A(0, 0.4, s * 32.8), Color3.fromRGB(170, 182, 172), Enum.Material.Concrete)
			part(Vector3.new(14, 0.8, 1.6), A(0, 2, s * 27.8), Color3.fromRGB(186, 198, 188), Enum.Material.Concrete)
		end
		-- the gold U.A. plates
		local GOLDEN = Color3.fromRGB(214, 172, 60)
		for _, s in { -1, 1 } do
			local side = part(Vector3.new(0.3, 1.3, 12), A(s * 32.1, 0.8, 0), GOLDEN, Enum.Material.Metal)
			paint(side, s > 0 and Enum.NormalId.Right or Enum.NormalId.Left, "U.A.", Color3.fromRGB(60, 40, 10))
			local front = part(Vector3.new(10, 1.3, 0.3), A(s * 18, 0.8, -32.1), GOLDEN, Enum.Material.Metal)
			front.Name = "Plate"
			paint(front, Enum.NormalId.Front, "U.A.", Color3.fromRGB(60, 40, 10))
		end
		-- the torches at the corners: red flame, smoke curling off them
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local base = part(Vector3.new(2.4, 3.2, 2.4), A(c[1] * 30, 3.2, c[2] * 30), Color3.fromRGB(70, 70, 78), Enum.Material.Metal)
			local bowl = part(Vector3.new(1.2, 3.4, 3.4), A(c[1] * 30, 5.4, c[2] * 30) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(56, 56, 62), Enum.Material.Metal, Enum.PartType.Cylinder)
			bowl.Name = "Torch"
			local fire = Instance.new("Fire")
			fire.Size = 7
			fire.Heat = 12
			fire.Color = Color3.fromRGB(255, 60, 100)
			fire.SecondaryColor = Color3.fromRGB(255, 170, 190)
			fire.Parent = bowl
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(210, 196, 206)
			smoke.Opacity = 0.12
			smoke.RiseVelocity = 5
			smoke.Size = 4
			smoke.Parent = bowl
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 110, 140)
			l.Range = 16
			l.Brightness = 1.4
			l.Parent = bowl
			base.Name = "TorchStand"
		end
		-- Cementoss's seat beside the stage
		part(Vector3.new(3, 2, 3), A(46, 1, -12), Color3.fromRGB(90, 94, 104), Enum.Material.Metal)
		local seat = part(Vector3.new(3, 0.5, 3), A(46, 2.25, -12), Color3.fromRGB(190, 40, 46))
		part(Vector3.new(0.5, 3.4, 3), A(47.3, 4.2, -12), Color3.fromRGB(90, 94, 104), Enum.Material.Metal)
		seat.Name = "RefereeSeat"
		tag(seat, "CEMENTOSS", "the referee's seat", 20, 4)
		-- THE TUNNEL the fighters come out of (and the way back)
		local mid = FIELD + 31
		part(Vector3.new(12, 0.6, 62), A(0, -0.3, mid), Color3.fromRGB(110, 110, 116), Enum.Material.Concrete)
		for _, s in { -1, 1 } do
			part(Vector3.new(1, 13, 62), A(s * 6.5, 6.5, mid), Color3.fromRGB(150, 150, 158), Enum.Material.Concrete)
			part(Vector3.new(1.6, 13.5, 1.6), A(s * 7.3, 6.75, FIELD + 0.4), Color3.fromRGB(60, 64, 76), Enum.Material.Metal)
		end
		part(Vector3.new(14, 1, 62), A(0, 13.5, mid), Color3.fromRGB(130, 130, 138), Enum.Material.Concrete)
		local gate = part(Vector3.new(16.2, 2.6, 1.6), A(0, 14.6, FIELD + 0.4), Color3.fromRGB(60, 64, 76), Enum.Material.Metal)
		gate.Name = "TunnelGate"
		paint(gate, Enum.NormalId.Front, "U.A.", Color3.fromRGB(255, 220, 90))
		for z = FIELD + 10, FIELD + 50, 20 do
			local l = deco(part(Vector3.new(4, 0.2, 1), A(0, 12.9, z), Color3.fromRGB(250, 248, 240), Enum.Material.Neon))
			glow(l, Color3.fromRGB(255, 246, 228), Enum.NormalId.Bottom, 16, 0.8)
		end
		part(Vector3.new(12, 13, 1), A(0, 6.5, FIELD + 62.5), Color3.fromRGB(150, 150, 158), Enum.Material.Concrete)
		local out = deco(part(Vector3.new(11, 12, 0.3), A(0, 6, FIELD + 61.8), OFA, Enum.Material.Neon))
		out.Name = "ToRealm"
		out.Transparency = 0.5
		tag(out, "back to One For All", nil, 30, 7.5)
		-- where you step up onto the stage (the memory plays)
		tag(stage, "THE STAGE", "Midoriya vs Todoroki - step up", 60, 8)
	end

	function DM.build()
		model = Instance.new("Model")
		model.Name = "DekuMemories"
		for _, step in { DM.buildGate, DM.buildClassroom, DM.buildStadium } do
			local ok, err = pcall(step)
			if not ok then
				warn("[DekuMemories] " .. tostring(err))
			end
		end
		model.Parent = workspace
		DM.model = model
	end

	---------------------------------------------------------------- going through
	-- did they go through this doorway (a to b), or are they standing in it?
	function DM.through(door, a, b)
		local p, q = door.CF:PointToObjectSpace(a), door.CF:PointToObjectSpace(b)
		local function within(v)
			return math.abs(v.X) <= door.W and v.Y > -2 and v.Y < door.H
		end
		if math.abs(q.Z) < 1.2 and within(q) then
			return true
		end
		if (p.Z > 0) ~= (q.Z > 0) and math.abs(p.Z - q.Z) > 1e-3 then
			return within(p:Lerp(q, p.Z / (p.Z - q.Z)))
		end
		return false
	end

	-- a white-out, and you're somewhere else in his memories
	function DM.go(player, where)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local spot = DM.SPOTS[where]
		if not spot or not root or not alive(char) or DM.busy[player] or VR.busy[player] or VR.inside[player] ~= char then
			return false
		end
		DM.busy[player] = true
		DM.last[player] = nil
		PlayVFX:FireClient(player, "MemoryIn", nil, { Place = where })
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(spot.Position, 3)
			end)
			task.wait(cfg.FadeTime or 1)
			DM.busy[player] = nil
			if player.Character ~= char or not alive(char) or not root.Parent or VR.inside[player] ~= char then
				return
			end
			iFrames[char] = math.max(iFrames[char] or 0, os.clock() + 1.5)
			char:PivotTo(spot)
			root.AssemblyLinearVelocity = Vector3.zero
			DM.last[player] = nil
			DM.stage[player] = nil
			DM.at[player] = where ~= "Realm" and where or nil
			player:SetAttribute("Memory", DM.at[player])
		end)
		return true
	end

	-- up onto the stage: the memory plays (on your screen)
	function DM.fight(player)
		local now = os.clock()
		if (DM.again[player] or 0) > now then
			return false
		end
		DM.again[player] = now + (cfg.FightTime or 40)
		PlayVFX:FireClient(player, "MemoryFight", nil, {
			Stage = ARENA * CFrame.new(0, STAGE_TOP, 0), Time = cfg.ClashTime or 9, Rival = cfg.Rival,
		})
		return true
	end

	function DM.check(player, char)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or DM.busy[player] or VR.busy[player] or not alive(char) then
			return
		end
		local pos = root.Position
		local prev = DM.last[player] or pos
		DM.last[player] = pos
		for _, door in DM.doors do
			if DM.through(door, prev, pos) then
				DM.go(player, door.To)
				return
			end
		end
		local lp = ARENA:PointToObjectSpace(pos)
		local on = math.abs(lp.X) <= STAGE_HALF and math.abs(lp.Z) <= STAGE_HALF and lp.Y > STAGE_TOP - 1 and lp.Y < STAGE_TOP + 14
		if on and not DM.stage[player] then
			DM.fight(player)
		end
		DM.stage[player] = on or nil
	end

	-- (testers: into the memories, and on through them)
	function TestCommands.Memories(player)
		local char = player.Character
		if VR.inside[player] ~= char then
			if VR.enter(player) then
				task.delay(1.6, function()
					DM.go(player, "Classroom")
				end)
			end
			return
		end
		local here = DM.at[player]
		DM.go(player, here == nil and "Classroom" or here == "Classroom" and "Stadium" or "Realm")
	end

	DM.build()
	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < 0.1 then
			return
		end
		lastCheck = now
		for plr, char in VR.inside do
			if plr.Parent and plr.Character == char then
				DM.check(plr, char)
			end
		end
		-- (out of the realm some other way: the memory's over)
		for plr in DM.at do
			if VR.inside[plr] == nil or plr.Character ~= VR.inside[plr] then
				DM.at[plr] = nil
				DM.stage[plr] = nil
				DM.last[plr] = nil
				plr:SetAttribute("Memory", nil)
			end
		end
	end)
end)()


Players.PlayerRemoving:Connect(function(player)
	Store.PlayerLeft(player)
	lastSwitch[player] = nil
	cooldowns[player] = nil
	m1State[player] = nil
	altTokens[player] = nil
	recoverUntil[player] = nil
	ultTokens[player] = nil
	lives[player] = nil
end)
