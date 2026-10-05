-- QuirkClient (LocalScript) — StarterPlayer.StarterPlayerScripts.QuirkClient
-- Input, aiming, local prediction (your own moves play instantly), the R
-- special, the G ultimate, the movement system (sprint + dash), and rendering
-- everyone else's moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("QuirkConfig"))
local VFX = require(Shared:WaitForChild("VFX"))
local HUD = require(Shared:WaitForChild("HUD"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseAbility = Remotes:WaitForChild("UseAbility")
local SelectQuirk = Remotes:WaitForChild("SelectQuirk")
local PlayVFX = Remotes:WaitForChild("PlayVFX")
local TestCommand = Remotes:WaitForChild("TestCommand")
local ShopRemote = Remotes:WaitForChild("Shop") -- (made by the server when it starts)
local SettingsRemote = Remotes:WaitForChild("Settings")

local SPECIAL = Config.SPECIAL_INDEX
local ULT = Config.ULT_INDEX
local DASH = Config.DASH_INDEX
local BLOCK = Config.BLOCK_INDEX
local MOVE = Config.Movement
local GUARD = Config.Guard or {}

-- Hide default health bar and hotbar (1/2/3 are ours now)
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

-- where a controller's menu selection sits (nil = no selection)
local padCursor = { on = false } -- (a controller's free cursor: it decides what's selected)
local function selectGui(obj)
	if padCursor.on then
		return -- (with the cursor up only your stick moves it - nothing jumps it about)
	end
	pcall(function()
		GuiService.SelectedObject = obj
	end)
end

-- ON A PHONE the HUD draws its own round buttons (Roblox's are off); this is
-- what each one does, finger down and finger up
local Touch = { handlers = {} }
HUD.Init(player, Config, {
	OnSelect = function(quirkName)
		SelectQuirk:FireServer(quirkName)
		selectGui(nil)
	end,
	TouchAction = function(name, down)
		local h = Touch.handlers[name]
		local fn = h and (down and h.down or h.up)
		if fn then
			fn()
		end
	end,
	-- (round 82) a button a finger can HOLD: it has a let-go (HIT, BLOCK,
	-- DASH, the moves). EMOTE only taps on a phone: a tap opens the wheel
	-- and a tap on one plays it (its let-go needs a mouse to point with)
	TouchHoldable = function(name)
		local h = Touch.handlers[name]
		return h ~= nil and h.up ~= nil and name ~= "QuirkEmote"
	end,
})
VFX.Hooks.Flash = HUD.Flash
VFX.Hooks.Blind = HUD.Blind
VFX.Hooks.Jam = HUD.Jam
VFX.Hooks.Dim = HUD.Dim
VFX.Hooks.SpeedLines = HUD.SpeedLines
VFX.Hooks.Letterbox = HUD.Letterbox
VFX.Hooks.Callout = HUD.Callout

local blocking = false -- guard held (F / L2 / BLOCK button)
local guardHeld = false
local lastUsed = {}
local m1Count, m1Last, m1Next = 0, 0, 0
local altMode = false -- predicted locally, corrected by the server's QuirkAlt attribute
local ultMode = false -- predicted locally, corrected by the server's UltActive attribute
local recoverUntil = 0 -- after leaving a timed form (muscle form) you must wait to re-enter
local inputMode = "Keyboard" -- "Keyboard", "Gamepad" or "Touch": the last thing you pressed
-- (round 92) no lock-on any more ("remove lock-on"): see "LOCK-ON, GONE" below
-- parkour (set up below): Busy while a vault / climb / wall hop has the body;
-- Running = sprinting; Latched = double-tapped W; WallNear = a wall hop is on
local Parkour = { Busy = false, Running = false, Latched = false, WallNear = nil }
local scoped = false -- looking down the sniper scope

-- a move you're holding down (set up below)
local Hold = { active = nil }
local BlastFly = { active = false } -- (round 73) Bakugo's explosion flight (filled in by the dash key)
local FloatFly = { active = false } -- (round 75) Deku's Float (filled in below)
local WhipDash = { dashAt = 0 } -- (round 75) dash, then Blackwhip: the slingshot (filled in below)
local HawksFly = { active = false } -- (round 86) Hawks' Fierce Wings flight (filled in below)
-- the testers' free camera and flight (set up with the test menu)
local FreeCam = { on = false }
local DevFly = { active = false } -- (round 86) the owner's / Devs' flight (Config.DevFlight; filled in with the test menu)
local dashing = false
local activeDashCleanup
local CombatInput = { untilAt = 0, pending = nil, buffer = 0.14 }
local m1Held -- (round 84: set up with the M1 key below; the slam jump reads it)

local function actionRemaining(char)
	local serverUntil = char and tonumber(char:GetAttribute("CombatActionUntil")) or 0
	return math.max(CombatInput.untilAt, serverUntil or 0) - workspace:GetServerTimeNow()
end

local function predictAction(duration)
	if type(duration) == "number" and duration > 0 then
		CombatInput.untilAt = math.max(CombatInput.untilAt, workspace:GetServerTimeNow() + duration)
	end
end

-- Keep only the most recent deliberate press near recovery. Long stuns,
-- held charges and cinematics never store an attack for later.
local function bufferInput(char, remaining, run)
	if remaining > 0 and remaining <= CombatInput.buffer then
		CombatInput.pending = { char = char, run = run, readyAt = workspace:GetServerTimeNow() + remaining,
			expires = os.clock() + CombatInput.buffer + 0.025 }
	end
end

-- your own move's cutscene holds your other inputs until it ends (and so
-- does charging a held move: letting go of its key is what's next)
local function busy(char)
	return not char or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Submerged")
		or char:GetAttribute("Frozen") or char:GetAttribute("Grabbed") or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished")
		or blocking or VFX.InOwnCinematic() or Parkour.Busy or char:GetAttribute("Holding") or Hold.active ~= nil or FreeCam.on
		or char:GetAttribute("PlayingUno") or char:GetAttribute("TimeStopped")
		or FreeCam.directing -- (round 87: the director camera has the keys; the body stands still)
		or char:GetAttribute("Parked") -- (round 87: he's in another body - this one waits, doing nothing)
		or char:GetAttribute("DevCarrying") -- (round 88: holding someone in the dev flight - his hands are full: the carry's moves only)
end

-- which of the quirk's 4th moves is picked (Deku's R cycles through them)
local function pickNow()
	return player:GetAttribute("QuirkPick") or 1
end

local function getCharacter()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function getAim(root)
	local cam = workspace.CurrentCamera
	-- the mouse on PC (in shift lock that's the middle of the screen anyway);
	-- the middle of the screen with a controller, on touch and down a scope
	local screenPoint
	if inputMode ~= "Keyboard" or not UserInputService.MouseEnabled or scoped then
		screenPoint = cam.ViewportSize / 2
	else
		screenPoint = UserInputService:GetMouseLocation()
	end
	local ray = cam:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	aimParams.FilterDescendantsInstances = { player.Character, VFX.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, aimParams)
	local pos = hit and hit.Position or (ray.Origin + ray.Direction * 600)
	local dir = pos - root.Position
	if dir.Magnitude < 1 then
		dir = cam.CFrame.LookVector
	end
	return dir.Unit, pos
end

-- A move you HOLD (ability.Hold = { Max = seconds, Levels = { ... } }):
-- pressing its key starts the charge (the server starts it too), letting
-- go of the key - or holding it to Max - lets it go, wherever you're aiming
-- right then. Each power level it reaches (Levels: seconds held) flashes up.

-- which power level a hold has reached (1 = just pressed)
function Hold.level(h, now)
	local level = 1
	for i, t in (h.ability.Hold and h.ability.Hold.Levels) or {} do
		if now - h.t0 >= t then
			level = i + 1
		end
	end
	return level
end

function Hold.release()
	local h = Hold.active
	if not h then
		return
	end
	Hold.active = nil
	local char, _, root = getCharacter()
	if not char then
		return
	end
	local dir, pos = getAim(root)
	UseAbility:FireServer(Config.RELEASE_INDEX, dir, pos)
	VFX.Play(h.ability.Id .. "Release", char, { Dir = dir, Pos = pos, Level = Hold.level(h, os.clock()) }, true)
end

-- the NUKE (dev kit): a red circle where it'll land (the way the server
-- works it out) and how far the blast will reach, growing with the bomb
function Hold.ring(h, root, now)
	local a = h.ability
	local _, pos = getAim(root)
	local flatAim = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	local range = a.Range or 300
	if flatAim.Magnitude > range then
		flatAim = flatAim.Unit * range
	end
	local xz = root.Position + flatAim
	aimParams.FilterDescendantsInstances = { player.Character, VFX.Folder }
	local hit = workspace:Raycast(Vector3.new(xz.X, root.Position.Y + 25, xz.Z), Vector3.new(0, -90, 0), aimParams)
	local spot = hit and hit.Position or Vector3.new(xz.X, root.Position.Y - 3, xz.Z)
	local maxCharge = (a.Hold and a.Hold.Max) or 3
	local minCharge = a.MinCharge or 0.6
	local k = math.clamp((now - h.t0 - minCharge) / math.max(maxCharge - minCharge, 0.1), 0, 1)
	local reach = (a.Radius or 260) * ((a.MinScale or 0.7) + (1 - (a.MinScale or 0.7)) * k) * 2
	local ring = Hold.marker
	if not ring or not ring.Parent then
		ring = Instance.new("Part")
		ring.Name = "NukeTarget"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 60, 40)
		ring.Transparency = 0.82
		ring.Parent = VFX.Folder
		Hold.marker = ring
	end
	ring.Size = Vector3.new(0.3, reach, reach)
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

-- (round 59) a held move that lands somewhere (Hold.Marker - the Vanishing
-- Act): a ring on the street where it'll come down, as far as it reaches
function Hold.spot(h, root)
	local a = h.ability
	local spec = a.Hold or {}
	local _, pos = getAim(root)
	local flatAim = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	local range = a.Throw or a.Range or 60
	if flatAim.Magnitude > range then
		flatAim = flatAim.Unit * range
	end
	local xz = root.Position + flatAim
	aimParams.FilterDescendantsInstances = { player.Character, VFX.Folder }
	local hit = workspace:Raycast(Vector3.new(xz.X, root.Position.Y + 25, xz.Z), Vector3.new(0, -(spec.Reach or 90), 0), aimParams)
	-- (nothing under it - off the edge: level with where he pressed it, not the sky he's in)
	h.floor = h.floor or (root.Position.Y - 3)
	local spot = hit and hit.Position or Vector3.new(xz.X, h.floor, xz.Z)
	local size = spec.MarkerSize or 7
	local ring = Hold.marker
	if not ring or not ring.Parent then
		ring = Instance.new("Part")
		ring.Name = "HoldTarget"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = spec.Color or Color3.fromRGB(255, 160, 60)
		ring.Transparency = 0.55
		ring.Size = Vector3.new(0.3, size, size)
		ring.Parent = VFX.Folder
		Hold.marker = ring
	end
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	-- (round 74) someone standing in it
	if spec.MarkerSize then
		local caught = false
		for _, model in Hold.bodies() do
			local mr = model ~= player.Character and model:FindFirstChild("HumanoidRootPart")
			if mr then
				local v = mr.Position - spot
				if Vector3.new(v.X, 0, v.Z).Magnitude <= size / 2 and v.Y > -6 and v.Y < 16 then
					caught = true
					break
				end
			end
		end
		ring.Color = caught and Color3.fromRGB(255, 60, 60) or (spec.Color or Color3.fromRGB(255, 160, 60))
		ring.Transparency = caught and 0.3 or 0.55
	end
end

-- (round 74) everyone a ring could catch: the other players, the dummies, Twice's doubles
function Hold.bodies()
	local list = {}
	for _, plr in game:GetService("Players"):GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	for _, name in { "Dummies", "TwiceClones" } do
		local f = workspace:FindFirstChild(name)
		for _, m in f and f:GetChildren() or {} do
			table.insert(list, m)
		end
	end
	return list
end

-- where you're aiming right now (a move following the aim is going: the
-- server takes it, and your own screen draws each shot along it)
function VFX.Hooks.Aim()
	local _, _, root = getCharacter()
	if root then
		return getAim(root)
	end
end

RunService.RenderStepped:Connect(function()
	local h = Hold.active
	local now = os.clock()
	if (Hold.aimUntil or 0) > now and now - (Hold.aimSent or 0) >= 0.06 then
		Hold.aimSent = now
		local _, _, root = getCharacter()
		if root then
			UseAbility:FireServer(Config.AIM_INDEX, (getAim(root)))
		end
	end
	if Hold.marker and not (h and (h.ability.Id == "Nuke" or h.ability.Hold.Marker)) then
		Hold.marker:Destroy()
		Hold.marker = nil
	end
	if not h then
		return
	end
	local char = getCharacter()
	if not char then
		Hold.active = nil -- (knocked out mid-charge)
		return
	end
	-- (the server never started it, or has ended it: let it go)
	if char:GetAttribute("Holding") then
		h.seen = true
	elseif h.seen or now - h.t0 > 1.2 then
		Hold.active = nil
		VFX.Play("HoldCancel", char, {}, true)
		return
	end
	local level = Hold.level(h, now)
	if level > h.level then
		h.level = level
		local names = h.ability.Hold.Names
		HUD.Callout(names and names[level] or ("LEVEL " .. level), h.ability.Hold.Color or Color3.fromRGB(150, 210, 255))
	end
	if h.ability.Id == "Nuke" then
		local _, _, root = getCharacter()
		if root then
			Hold.ring(h, root, now)
		end
	elseif h.ability.Hold.Marker then
		local _, _, root = getCharacter()
		if root then
			Hold.spot(h, root)
		end
	end
	if now - h.t0 >= (h.ability.Hold.Max or 2) then
		Hold.release()
	end
end)

-- (round 75) a held move aimed from the sky (Hold.SkyCam - Colorado
-- Smash): he stays crouched on the street, the camera goes up over the
-- city; WASD / the left stick pans it (no further than the move reaches),
-- the ring follows the cursor (the middle of the screen with a controller)
do
	local on = false
	local focus, yawLook
	local function flatv(v)
		return Vector3.new(v.X, 0, v.Z)
	end
	RunService:BindToRenderStep("QuirkSkyAim", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local h = Hold.active
		local sky = h and h.ability.Hold and h.ability.Hold.SkyCam
		local cam = workspace.CurrentCamera
		local _, hum, root = getCharacter()
		if not sky or not root or not hum or not cam then
			if on then
				on = false
				if cam then
					cam.CameraType = Enum.CameraType.Custom
					if hum then
						cam.CameraSubject = hum
					end
				end
			end
			return
		end
		if not on then
			on = true
			local f = flatv(cam.CFrame.LookVector)
			yawLook = f.Magnitude > 0.05 and f.Unit or flatv(root.CFrame.LookVector).Unit
			focus = root.Position + yawLook * 30
			cam.CameraType = Enum.CameraType.Scriptable
		end
		-- the pan (camera-relative, like walking)
		focus += flatv(hum.MoveDirection) * (sky.Pan or 80) * dt
		local range = h.ability.Range or 160
		local off = flatv(focus - root.Position)
		if off.Magnitude > range then
			off = off.Unit * range
		end
		focus = Vector3.new(root.Position.X + off.X, root.Position.Y, root.Position.Z + off.Z)
		local eye = focus + Vector3.new(0, sky.Height or 95, 0) - yawLook * (sky.Back or 40)
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(eye, focus), math.min(1, dt * 7))
	end)
end

local function onCooldown(key, length)
	if player:GetAttribute("NoCooldowns") then
		return false
	end
	local now = os.clock()
	if lastUsed[key] and now - lastUsed[key] < length then
		return true
	end
	lastUsed[key] = now
	return false
end

-- cooldown UI (hidden while the test menu's No Cooldowns is on)
local function startCd(key, length)
	if not player:GetAttribute("NoCooldowns") then
		HUD.StartCooldown(key, length)
	end
end

local function refreshHud(resetCooldowns)
	HUD.SetQuirk(player:GetAttribute("Quirk"), altMode, resetCooldowns, ultMode, pickNow())
end

-- Eraser Head's capture scarf caught you: no quirk for a few seconds
-- (round 84: nor while Radio Waves has you jammed)
local function erased(char)
	if (char:GetAttribute("ErasedUntil") or 0) > workspace:GetServerTimeNow() then
		HUD.Callout("QUIRK ERASED", Color3.fromRGB(255, 60, 60))
		return true
	end
	if (char:GetAttribute("JammedUntil") or 0) > workspace:GetServerTimeNow() then
		HUD.Callout("SIGNAL JAMMED", Color3.fromRGB(200, 150, 255))
		return true
	end
	return false
end

-- Sniper: while scoped, every attack button pulls the trigger
local lastShot = 0
local function fireSniper()
	local char, _, root = getCharacter()
	local item = Config.Items.Sniper
	local now = os.clock()
	if not char or now - lastShot < (item.FireRate or 0.9) then
		return
	end
	lastShot = now
	local dir, pos = getAim(root)
	ShopRemote:FireServer("Fire", dir, pos)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(2.5), 0, 0) -- recoil
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------

-- Aim assist (ability.AimAssist degrees): an aim that's just off someone
-- lands on them
local function assistAim(root, dir, pos, degrees, range)
	local best, bestAngle = nil, math.rad(degrees)
	local function consider(model)
		local r = model ~= player.Character and model:FindFirstChild("HumanoidRootPart")
		local hum = r and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local v = r.Position - root.Position
			if v.Magnitude > 1 and v.Magnitude <= range then
				local angle = math.acos(math.clamp(v.Unit:Dot(dir), -1, 1))
				if angle < bestAngle then
					best, bestAngle = r, angle
				end
			end
		end
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			consider(plr.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	for _, model in dummies and dummies:GetChildren() or {} do
		consider(model)
	end
	if best then
		return (best.Position - root.Position).Unit, best.Position
	end
	return dir, pos
end

local function useAbility(index)
	if BlastFly.active and BlastFly.stop then
		BlastFly.stop("Action") -- (round 73: a move drops him out of his flight - its air version)
	end
	if FloatFly.active and FloatFly.pause then
		FloatFly.pause(0.55) -- (round 75: a move while floating - he hangs there for it)
	end
	if DevFly.active and DevFly.pause then
		DevFly.pause(0.55) -- (round 86: a move in dev flight - he hangs there for it)
	end
	-- (round 86) Hawks flying: R again is down (no cooldown for that)
	if HawksFly.active and index == SPECIAL and HawksFly.stop then
		HawksFly.stop("Key")
		return
	end
	-- (a move you tap to start and tap again to let go - Fa Jin: the key a
	-- second time is the release, not a new press)
	local h = Hold.active
	if h and h.index == index and h.ability.Hold.Toggle then
		if os.clock() - h.t0 > 0.18 then
			Hold.release()
		end
		return
	end
	local char, _, root = getCharacter()
	if scoped and char and index <= 3 then
		fireSniper()
		return
	end
	if busy(char) or erased(char) or player:GetAttribute("NoSkills") then
		return -- (server settings can switch a player's moves off)
	end
	if HawksFly.follow and HawksFly.follow(index) then
		return -- (round 92, hawksair: Hawks holding someone on his feathers - 1-4 are the carry's follow-ups)
	end
	local quirkName = player:GetAttribute("Quirk")
	local pick = pickNow()
	local ability = Config.GetAbility(quirkName, index, altMode, ultMode, pick)
	if not ability then
		if not quirkName then
			HUD.ShowMenu(true)
		end
		return
	end
	-- (round 75) dash, then Blackwhip: the slingshot
	if WhipDash.ready and WhipDash.ready(ability) then
		WhipDash.go(ability, Config.CooldownKey(quirkName, index, altMode, ultMode, pick))
		return
	end
	local remaining = actionRemaining(char)
	-- (Deku's R only swaps which quirk is in his 4th slot - no attack, so the
	-- action lock doesn't hold it up)
	if (remaining > 0 or dashing) and not ability.Cycle then
		if not ability.Hold then
			bufferInput(char, remaining, function() useAbility(index) end)
		end
		return
	end
	-- (a swing - Kamui's R - only goes off something taller than him: with
	-- nothing in reach it doesn't go, and costs nothing)
	local swingAnchor = nil
	if ability.Swing then
		swingAnchor = VFX.SwingAnchor(char, (getAim(root)), ability.Range or 80)
		if not swingAnchor then
			HUD.Callout("NOTHING TO SWING FROM", Color3.fromRGB(255, 180, 120))
			return
		end
	end
	-- (round 86) Hawks: a move his feathers can't pay for (or plucked) doesn't
	-- go - not played here, no cooldown (the server would refuse it anyway)
	if ability.Feathers and quirkName == "FierceWings" then
		local f = tonumber(char:GetAttribute("Feathers")) or 0
		local plucked = char:GetAttribute("Plucked") == true
		local free = ability.FreeFlying and HawksFly.active
		if plucked or (not free and f < (ability.MinFeathers or ability.Feathers)) then
			-- (round 86 review: mashed, it's said once every 0.4 s, not on every press)
			if os.clock() - (HawksFly.refusedAt or 0) >= 0.4 then
				HawksFly.refusedAt = os.clock()
				HUD.Callout(plucked and "PLUCKED - REGROWING" or "NOT ENOUGH FEATHERS", Color3.fromRGB(255, 130, 115))
				VFX.Play("FeathersOut", char, { Plucked = plucked }, true)
			end
			return
		end
	end
	local key = Config.CooldownKey(quirkName, index, altMode, ultMode, pick)
	if onCooldown(key, ability.Cooldown) then
		return
	end
	if not swingAnchor and (VFX.Swinging(char) or VFX.SwingCarrying(char)) then
		VFX.SwingRelease(char) -- (a move lets go of the swing, and of its fling)
	end

	local dir, pos = getAim(root)
	if swingAnchor then
		pos = swingAnchor
	end
	if ability.AimAssist then
		dir, pos = assistAim(root, dir, pos, ability.AimAssist, ability.Range or 60)
	end
	-- seed + origin: everyone (and the server's destruction) builds the same shapes
	local seed = math.random(1, 2 ^ 30)
	local origin = root.Position
	-- (your side of the air variants: off the ground when you pressed it)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local air = hum ~= nil and hum.FloorMaterial == Enum.Material.Air
	if air and index == SPECIAL and quirkName == "FierceWings" and HawksFly.airStart then
		air = HawksFly.airStart(ability, root, hum) -- (round 90 review: Hawks' R just off the street is the takeoff - the catch past AirHeight, the same on every screen)
	end
	CombatInput.pending = nil
	-- (round 86) a move while Hawks flies: he hangs in the air for it (R
	-- itself is the takeoff)
	if HawksFly.active and HawksFly.pause and index ~= SPECIAL then
		-- (round 92, hawksair: a flying move says how long it holds him - FlyHang; 0, he flies on through it)
		HawksFly.pause(ability.FlyHang or math.max((ability.ActionTime or 0.4) + 0.1, 0.45))
	elseif air and quirkName == "FierceWings" and index ~= SPECIAL and HawksFly.hang then
		HawksFly.hang(math.max((ability.ActionTime or 0.4) + 0.1, 0.45)) -- (round 90: off the street, his wings hold him there for it)
	end
	predictAction((air and ability.AirActionTime) or ability.ActionTime)
	UseAbility:FireServer(index, dir, pos, seed, origin, air)
	if ability.LiveAim then
		-- (a move that keeps following your aim while it goes: where you're
		-- aiming streams up until it's done)
		Hold.aimUntil = os.clock() + (ability.Shots or 6) * ability.LiveAim + 0.35
	end
	startCd(key, ability.Cooldown)
	if ability.CutIn then
		HUD.CutIn(Config.GetView(quirkName, altMode, ultMode, pick), ability.Name)
	end
	VFX.Play(ability.Id, char, { Dir = dir, Pos = pos, Seed = seed, Origin = origin, Air = air }, true)
	if ability.Hold then
		Hold.active = { t0 = os.clock(), ability = ability, index = index, level = 1 }
		if ability.Hold.Toggle then
			HUD.Callout(((ability.Hold.Names or {})[1] or ability.Name) .. " - PRESS AGAIN", ability.Hold.Color)
		end
	end
	if ability.Cycle then
		-- Deku's R: the next quirk into the 4th slot (the server confirms)
		local list = Config.Quirks[quirkName].Extras or {}
		player:SetAttribute("QuirkPick", #list > 0 and (pick % #list) + 1 or 1)
		local now = Config.PickedExtra(Config.Quirks[quirkName], player:GetAttribute("QuirkPick"))
		if now then
			-- (round 60: Creati's weapon, and the move that goes with it)
			local weapon = now.Weapon and Config.Quirks[quirkName].Weapons and Config.Quirks[quirkName].Weapons[now.Weapon]
			HUD.Callout(weapon and (weapon.Name .. ": " .. now.Name) or now.Name, Config.Quirks[quirkName].AccentColor)
		end
	end
end

---------------------------------------------------------------------------
-- Forms: R special, G ultimate, and the timer bar
---------------------------------------------------------------------------

local function refreshTimer()
	local quirkName = player:GetAttribute("Quirk")
	local quirk = Config.Quirks[quirkName or ""]
	if ultMode and quirk and quirk.Ult then
		local ends = player:GetAttribute("UltEnds")
		if ends then
			local view = Config.GetView(quirkName, altMode, true)
			HUD.SetModeTimer(ends, quirk.Ult.Duration, view.AccentColor, "ULT: " .. quirk.Ult.Name)
			return
		end
	end
	local special = Config.GetAbility(quirkName, SPECIAL)
	local ends = player:GetAttribute("AltEnds")
	if altMode and special and special.Duration and ends then
		local view = Config.GetView(quirkName, true)
		HUD.SetModeTimer(ends, special.Duration, view.AccentColor, view.ModeName)
	else
		HUD.SetModeTimer(nil)
	end
end

-- Leaving the alt form: start the recovery wait (or the normal swap cooldown)
local function startRecover(quirkName, special)
	if player:GetAttribute("NoCooldowns") then
		return
	end
	local key = Config.CooldownKey(quirkName, SPECIAL)
	if special.RecoverTime then
		recoverUntil = os.clock() + special.RecoverTime
		startCd(key, special.RecoverTime)
	else
		startCd(key, special.Cooldown)
	end
end

local function syncMode()
	local quirkName = player:GetAttribute("Quirk")
	local serverAlt = player:GetAttribute("QuirkAlt") == true
	local special = Config.GetAbility(quirkName, SPECIAL)
	if altMode and not serverAlt and special then
		-- the server ended the form on its own (time limit / ult ended / respawn)
		startRecover(quirkName, special)
	end
	altMode = serverAlt
	ultMode = player:GetAttribute("UltActive") == true
	local char = player.Character
	if char then
		-- undo any local prediction the server didn't go along with
		char:SetAttribute("QuirkAlt", altMode)
		char:SetAttribute("UltActive", ultMode)
	end
	refreshHud(false)
	refreshTimer()
end

local function useSpecial()
	local char = getCharacter()
	if busy(char) or dashing or actionRemaining(char) > 0 or ultMode or erased(char) then
		return
	end
	local quirkName = player:GetAttribute("Quirk")
	local special = Config.GetAbility(quirkName, SPECIAL)
	if not special then
		return
	end
	local goingAlt = not altMode
	if goingAlt and os.clock() < recoverUntil then
		return
	end
	local key = Config.CooldownKey(quirkName, SPECIAL)
	if onCooldown(key, special.Cooldown) then
		return
	end
	UseAbility:FireServer(SPECIAL)

	-- predict the change so it feels instant; the server confirms via QuirkAlt
	altMode = goingAlt
	char:SetAttribute("QuirkAlt", altMode) -- form visuals (Full Cowl) + M1 style switch at once
	refreshHud(false)
	if goingAlt then
		startCd(key, special.Cooldown)
		if special.Duration and special.Duration > 0 then
			local view = Config.GetView(quirkName, true)
			HUD.SetModeTimer(workspace:GetServerTimeNow() + special.Duration, special.Duration, view.AccentColor, view.ModeName)
		end
		if special.CutIn then
			HUD.CutIn(Config.GetView(quirkName, true), special.Name)
		end
	else
		startRecover(quirkName, special)
		HUD.SetModeTimer(nil)
	end
	VFX.Play(special.Id, char, { Alt = altMode }, true)
	task.delay(0.8, syncMode) -- falls back to the server's truth if it rejected us
end

local function useUlt()
	local char = getCharacter()
	if busy(char) or dashing or actionRemaining(char) > 0 or ultMode or erased(char) then
		return
	end
	if HawksFly.carry then
		return -- (round 92, hawksair: not with someone on his feathers - the server waits too)
	end
	local quirkName = player:GetAttribute("Quirk")
	local quirk = Config.Quirks[quirkName or ""]
	if not quirk or not quirk.Ult or (player:GetAttribute("Ult") or 0) < 100 then
		return
	end
	UseAbility:FireServer(ULT)
	ultMode = true
	if quirk.Ult.ForceAlt then
		altMode = true
		char:SetAttribute("QuirkAlt", true)
	end
	char:SetAttribute("UltActive", true)
	lastUsed = {}
	refreshHud(false)
	local view = Config.GetView(quirkName, altMode, true)
	HUD.UltBanner(view, quirk.Ult.Shout)
	HUD.SetUltMeter(0, true)
	HUD.SetModeTimer(workspace:GetServerTimeNow() + quirk.Ult.Duration, quirk.Ult.Duration, view.AccentColor, "ULT: " .. quirk.Ult.Name)
	VFX.Play("UltActivate", char, { Quirk = quirkName }, true)
	task.delay(1, syncMode)
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------

-- JJS / TSB M1 finishers (Config.M1.Uppercut / Downslam). (round 63)
-- UPSLAM: hold jump and throw the 4th - you stay on your feet: holding jump
-- through a grounded chain never hops you, whenever you pressed it and
-- however long you hold it, and it still doesn't once the 4th is out (until
-- you let go). DOWNSLAM: TAP jump during the chain (round 83: press and let
-- go inside Config.M1.Slam.TapMax) - you hop (after hit 3, once its swing
-- lets you) - and the 4th goes at the top of the hop.
-- (round 83) downAt: when jump went down; holdUp: the 4th went out as the
-- upslam (you stay down till you let go); hopAt: the slam hop; armedAt: a tap
-- waiting for hit 3 to hop; commitAt: a 4th waiting a moment to see whether
-- jump was a tap (Slam.UpCommit); fixAt: the hop's speed still to set; raw /
-- rawAt: this frame's jump input, read before it's cleared; groundAt: the
-- last frame the feet were on something; suppressing: a grounded chain, where
-- a jump press is the slam's, not a jump; apexAt: a downslam waiting for the
-- top of the hop (round 81)
-- (round 84) seenAt: the press QuirkM1Jump has looked at; pressArm: armed by
-- that press itself (one after hit 3 - it hops without waiting for the
-- let-go); upAt: a press decided as the upslam (held through hit 3's swing
-- with the 4th clicked into it); hopPress: the press that hopped you (still
-- held when you land, it doesn't jump you again)
local slamJump = { downAt = nil, holdUp = false, hopAt = -1, groundAt = -1, raw = false, suppressing = false }
-- the jump input itself: Space, the pad's A, or the phone's jump button
-- (that one only shows as Humanoid.Jump, which Roblox's control script sets
-- every frame)
function slamJump.read(hum)
	if FreeCam.directing then
		return false -- (round 87 review: Space / A are the director camera's - its freeze, its next target - not a jump the dev flight, Hawks' wings or parkour read off the keys)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or (hum and hum.Jump) then
		return true
	end
	local ok, down = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	end)
	return ok and down == true
end
-- jump just went down: a tap still armed is dropped (pressed again and held,
-- it's the upslam now; let go quickly, it arms again)
function slamJump.pressed(now)
	slamJump.downAt, slamJump.armedAt = now, nil
end
local function jumpHeld(hum)
	-- (round 83) QuirkM1Jump clears Humanoid.Jump to keep you on the street in
	-- a chain, so what it read this frame (before the clear) still counts -
	-- plus the keys, read now
	if slamJump.rawAt and os.clock() - slamJump.rawAt < 0.1 then
		return slamJump.raw or slamJump.read(nil)
	end
	return slamJump.read(hum)
end
-- studs between your feet and the street
local function feetHeight(root, hum)
	aimParams.FilterDescendantsInstances = { player.Character, VFX.Folder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), aimParams)
	local hip = ((hum.HipHeight > 0) and hum.HipHeight or 2) + root.Size.Y / 2
	return hit and (root.Position.Y - hit.Position.Y - hip) or 60
end
-- the 4th hit: thrown anywhere off the ground = downslam, jump held on the
-- ground = upslam
local function m1Variant(hum, root)
	if hum.FloorMaterial == Enum.Material.Air and feetHeight(root, hum) > (Config.M1.DownslamHeight or 0.6) then
		return "Down"
	end
	-- (round 75) just hopped for it: it's the downslam, however low you are yet
	-- (round 81: while the hop lasts - a jump is ~0.51s; later than this the
	-- server already has you back on the street)
	-- (round 83: by the hop's time alone - the old flag was wiped the frame
	-- after a tap's hop)
	if os.clock() - slamJump.hopAt < 0.5 then
		return "Down"
	end
	if jumpHeld(hum) then
		return "Up"
	end
	return nil
end

-- bufferPress = false: a retry (held M1, a buffered press); atApex = true:
-- the downslam held for the top of the hop goes now whatever (round 81)
local function useM1(bufferPress, atApex)
	if BlastFly.active and BlastFly.stop then
		BlastFly.stop("Action") -- (round 73: an M1 drops him out of his flight)
	end
	if FloatFly.active and FloatFly.pause then
		FloatFly.pause(0.3) -- (round 75)
	end
	if DevFly.active and DevFly.pause then
		DevFly.pause(0.3) -- (round 86)
	end
	if HawksFly.active and HawksFly.pause then
		HawksFly.pause(0.3) -- (round 86: the blades in the air - he holds his height)
	end
	local char, hum, root = getCharacter()
	if scoped and char then
		fireSniper()
		return
	end
	if busy(char) or player:GetAttribute("NoMelee") then
		return
	end
	if HawksFly.carry then
		return -- (round 92, hawksair: someone on his feathers - his blades wait; 1-4 are the follow-ups)
	end
	local now = os.clock()
	local remaining = math.max(actionRemaining(char), m1Next - now)
	if remaining > 0 or dashing then
		if bufferPress ~= false then
			local run = function() useM1(false) end
			bufferInput(char, remaining, run)
			-- (round 84) the 4th clicked into hit 3's swing with jump held down is
			-- kept however early (the buffer's 0.14s is shorter than the swing):
			-- that's the upslam, and the slam jump waits on it
			local fourthNext = (now - m1Last > Config.M1.ComboReset and 1 or m1Count % Config.M1.ComboLength + 1) == Config.M1.ComboLength
			if not (CombatInput.pending and CombatInput.pending.run == run) and fourthNext and hum and remaining <= 0.4
				and not dashing and jumpHeld(hum) then
				CombatInput.pending = { char = char, run = run, readyAt = workspace:GetServerTimeNow() + remaining, expires = os.clock() + remaining + 0.1 }
			end
			if CombatInput.pending and CombatInput.pending.run == run then
				CombatInput.pending.m1 = true -- (round 84: the slam jump asks whether an M1's coming)
			end
		end
		return
	end
	CombatInput.pending = nil
	if char:GetAttribute("Kaiju") then
		-- Overhaul's kaiju: each M1 brings one giant arm down (right, then left)
		local kaiju = Config.FindAbilityById("Kaiju") or {}
		m1Count = m1Count % 2 + 1
		m1Last = now
		m1Next = now + (kaiju.SlamCooldown or 0.85)
		UseAbility:FireServer(0)
		VFX.Play("Punch", char, { Count = m1Count, Finisher = false }, true)
		return
	end
	-- (round 81) THE DOWNSLAM GOES AT THE TOP OF THE HOP: thrown while you're
	-- still on the way up, it's held (not dropped) until you start to come
	-- down - up, then down, never a hammer on the way up
	local fresh = now - m1Last > Config.M1.ComboReset
	-- (round 83: and the frame or two after the slam hop, before the body's
	-- had its push up)
	local fourth = (fresh and 1 or m1Count % Config.M1.ComboLength + 1) == Config.M1.ComboLength
	if not atApex and hum and root and fourth and (root.AssemblyLinearVelocity.Y > 0.5 or now - slamJump.hopAt < 0.12)
		and m1Variant(hum, root) == "Down" then
		slamJump.apexAt = slamJump.apexAt or now
		return
	end
	slamJump.apexAt = nil
	-- (round 83) the 4th with jump only just pressed (Config.M1.Slam.UpCommit):
	-- it waits that moment - let go by then and it was a tap (the hop, then
	-- the downslam at its top); still held, it's the upslam. And with a tap's
	-- hop still to go (armed), it waits for the hop (a frame: both wait out
	-- hit 3's lock)
	local SL = Config.M1.Slam or {}
	-- (a jump pressed in this same frame - the click came first - isn't
	-- seen by QuirkM1Jump yet: it counts as just pressed here)
	if not slamJump.downAt and hum and fourth and jumpHeld(hum) then
		slamJump.pressed(now)
	end
	-- (round 84: a press already decided as the upslam doesn't wait)
	if not atApex and hum and root and fourth and (slamJump.armedAt
		or (slamJump.downAt and slamJump.upAt ~= slamJump.downAt and now - slamJump.downAt < (SL.UpCommit or 0.1)
			and m1Variant(hum, root) == "Up")) then
		slamJump.commitAt = slamJump.commitAt or now
		return
	end
	slamJump.commitAt = nil
	if fresh then
		m1Count = 0
	end
	m1Count = m1Count % Config.M1.ComboLength + 1
	m1Last = now
	local finisher = m1Count == Config.M1.ComboLength
	m1Next = now + (finisher and Config.M1.FinisherCooldown or Config.M1.Cooldown)
	predictAction(finisher and (Config.M1.FinisherActionTime or 0.4) or (Config.M1.ActionTime or 0.18))
	CombatInput.m1Until = CombatInput.untilAt -- (round 65: a side / back dash may cut into it)
	-- (round 81) chaining slows your walk (Config.M1.ChainWalk): through the
	-- swing and the next one's window, and a beat after
	CombatInput.m1SlowUntil = now + (finisher and (Config.M1.FinisherActionTime or 0.42) or math.max(Config.M1.Cooldown, Config.M1.ActionTime or 0.18)) + 0.1
	local variant = finisher and hum and root and m1Variant(hum, root) or nil
	if variant == "Up" then
		slamJump.holdUp = true -- (and you stay down till you let go)
	end
	-- M1 tracking (like JJS): the swing turns to the nearest opponent close
	-- in front of you (Config.M1.Assist)
	local assist = Config.M1.Assist
	if assist and root then
		local l = root.CFrame.LookVector
		local look = Vector3.new(l.X, 0, l.Z)
		if look.Magnitude > 0.1 then
			local d = assistAim(root, look.Unit, nil, assist.Angle or 55, assist.Range or 11)
			local toward = Vector3.new(d.X, 0, d.Z)
			if toward.Magnitude > 0.1 then
				-- (a nudge, not a lock: it turns you partway toward them)
				local from = math.atan2(-look.Unit.X, -look.Unit.Z)
				local to = math.atan2(-toward.Unit.X, -toward.Unit.Z)
				local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
				local most = math.rad(assist.MaxTurn or 30)
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, from + math.clamp(delta, -most, most), 0)
			end
		end
	end
	-- where you stand and face on your screen: the server measures the swing
	-- from here (and the 4th hit's variant)
	UseAbility:FireServer(0, root and root.CFrame, variant)
	VFX.Play("Punch", char, { Count = m1Count, Finisher = finisher, Variant = variant }, true)
end

-- (round 63) Jump during a grounded M1 chain: HELD it's the upslam (no hop,
-- however long you hold it - the 4th is thrown standing and you stay on your
-- feet); TAPPED it's a hop for the downslam. Still held when the chain runs
-- out (ComboReset): an ordinary jump.
-- (round 83) Round 75's "held: hop as soon as the swing lets you" is gone (it
-- was the owner's "holding space makes you jump": Space pressed in the first
-- ~0.23s of any beat hopped you, and then Roblox's held jump bunny-hopped you
-- through the chain into a downslam). Now:
--  * held: never a hop in a grounded chain. It's stopped by clearing
--    Humanoid.Jump every frame here (Input + 1, after Roblox's control script
--    sets it at Input) - that's what stops the keys, the pad AND the phone's
--    jump button. Off a phone the Jumping state is switched off too (on one
--    that would hide Roblox's jump button and drop the finger on it, which
--    read as a let-go: every press hopped).
--  * a tap (pressed and let go inside Slam.TapMax): after hit 3 the hop goes
--    as you let go (once hit 3's swing lets you); after hit 1 or 2 it's kept
--    (armed) and goes once hit 3's swing lets you - so the 4th is the one
--    thrown at the top of the hop. If no more M1s come (Cooldown +
--    Slam.ArmWait after the last one) it was a jump out of the chain: an
--    ordinary jump then (not eaten). Pressed again and held, the arm's
--    dropped (the upslam); a jump pressed the same frame as the 4th's click
--    counts as just pressed (UpCommit).
--  * (round 84) AFTER HIT 3 IT'S THE PRESS, NOT THE LET-GO: Space down
--    after hit 3's click hops you the moment hit 3's swing lets you (your
--    own screen's count of it - the server's copy comes a ping late), or
--    Slam.PressGrace after the press if it already has. Still held as the
--    swing ends with the 4th clicked into it (buffered, or M1 held down),
--    it's the upslam instead (JJS / TSB: hold jump through the 3rd's
--    recovery and M1); Space and the 4th pressed together, UpCommit
--    decides as before. Held from before hit 3, still never a hop; and one
--    press is one jump - still held when you land, it doesn't jump you again.
--  * the slam hop rises at Downslam.HopSpeed whatever the quirk's
--    JumpPower, so the hammer meets the head for everyone.
--  * the feet off the street for a frame (a curb, a slope) isn't leaving it
--    (Slam.AirGrace), and nothing else jumps you while you chain: the jump
--    feel's coyote / buffer jumps and Float's lift check `suppressing`, and
--    a phone's auto-jump is off.
do
	local SJ = slamJump
	-- the slam hop: up at HopSpeed (set once it's seen rising: the jump's own
	-- push comes in the physics step after ChangeState), its pose here, and
	-- everyone else is told (the parkour relay). `plain`: a tap that no hit 3
	-- followed - you were jumping out, so it's your own jump, no slam pose
	function SJ.hop(char, hum, now, plain)
		SJ.hopAt, SJ.fixAt = now, not plain and now or nil
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		if plain then
			return
		end
		if VFX.M1Kit and VFX.M1Kit.slamHop then
			VFX.M1Kit.slamHop(char, true)
		end
		UseAbility:FireServer(Config.PARKOUR_INDEX, "SlamHop")
	end
	-- (round 84) hit 3's swing on your own screen (the server's lock comes a
	-- ping late: waiting on it was half the "takes too long to jump")
	local function ownLock()
		return CombatInput.untilAt - workspace:GetServerTimeNow()
	end
	RunService:BindToRenderStep("QuirkM1Jump", Enum.RenderPriority.Input.Value + 1, function()
		local char, hum, root = getCharacter()
		local now = os.clock()
		-- this frame's jump input, before anything below clears it
		local raw = hum ~= nil and SJ.read(hum)
		SJ.raw, SJ.rawAt = raw, now
		local SL = Config.M1.Slam or {}
		local len = Config.M1.ComboLength
		local chain = m1Count >= 1 and m1Count < len and now - m1Last < Config.M1.ComboReset
		local floor = hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
		if floor then
			SJ.groundAt = now
		end
		-- (a one-frame Air reading isn't leaving the street; the slam hop is)
		local grounded = floor or (hum ~= nil and now - SJ.groundAt < (SL.AirGrace or 0.1) and now - SJ.hopAt > 0.3)
		local hop = false
		if raw then
			if not SJ.downAt then
				SJ.pressed(now)
			end
			-- (round 84) a press after hit 3 is armed as it goes down - it hops
			-- as soon as hit 3's swing lets you, held or not (the 4th clicked in
			-- the same frame is UpCommit's to decide)
			if SJ.seenAt ~= SJ.downAt then
				SJ.seenAt = SJ.downAt
				if chain and m1Count == len - 1 and grounded and not SJ.holdUp and not SJ.commitAt then
					SJ.armedAt, SJ.pressArm = now, SJ.downAt
				end
			end
		elseif SJ.downAt then
			-- let go: a tap in the chain is the slam hop (armed till hit 3's
			-- swing lets you); a longer hold let go before the 4th is nothing
			-- (round 84: a press after hit 3 armed itself already)
			if SJ.pressArm ~= SJ.downAt and now - SJ.downAt <= (SL.TapMax or 0.2) and chain and grounded and not SJ.holdUp then
				SJ.armedAt = now
			end
			SJ.downAt, SJ.holdUp = nil, false
		end
		-- (hop: "slam" - hit 3's out, the 4th goes at its top; "plain" - no
		-- hit 3 came by Cooldown + ArmWait after the last M1, sized so a
		-- clicked chain's next hit beats it: a jump out of the chain)
		if SJ.armedAt then
			-- (round 84) armed by a press that's still held
			local pressing = SJ.pressArm ~= nil and SJ.pressArm == SJ.downAt
			if not char or not grounded or m1Count >= len or dashing or busy(char) then
				SJ.armedAt = nil
			elseif pressing and SJ.commitAt then
				-- the 4th clicked inside PressGrace: it's waiting on UpCommit - held
				-- on, the upslam; let go, a tap (armed again as you let go)
				SJ.armedAt, SJ.pressArm = nil, nil
			elseif m1Count == len - 1 and ownLock() <= 0 and (not pressing or now - SJ.downAt >= (SL.PressGrace or 0.04)) then
				SJ.armedAt = nil
				local m1Coming = (CombatInput.pending and CombatInput.pending.m1) or m1Held
				if pressing and m1Coming then
					-- held through hit 3's swing with the 4th clicked into it: the upslam
					SJ.pressArm, SJ.upAt = nil, SJ.downAt
				else
					hop = "slam"
				end
			elseif m1Count < len - 1 and not CombatInput.pending and now - m1Last > Config.M1.Cooldown + (SL.ArmWait or 0.3) then
				SJ.armedAt = nil
				hop = "plain"
			end
		end
		-- held in a grounded chain (or after the upslam till you let go): no jump
		-- (round 84: nor still holding the press that hopped you; and never
		-- while the hop's own push is still going on)
		local heldOn = SJ.hopPress ~= nil and SJ.hopPress == SJ.downAt
		SJ.suppressing = hum ~= nil and grounded and hop == false and now - SJ.hopAt > 0.3 and (SJ.holdUp or chain or heldOn)
		local suppress = SJ.suppressing and raw
		if suppress then
			hum.Jump = false
		end
		local stateOff = suppress and inputMode ~= "Touch"
		if stateOff and SJ.stateOff ~= hum then
			if SJ.stateOff and SJ.stateOff.Parent then
				SJ.stateOff:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
			SJ.stateOff = hum
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		elseif not stateOff and SJ.stateOff then
			if SJ.stateOff.Parent then
				SJ.stateOff:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
			SJ.stateOff = nil
		end
		-- a phone's auto-jump (a body pressed against you) is off while you chain
		if SJ.suppressing and SJ.autoOff ~= hum then
			if SJ.autoOff and SJ.autoOff.Parent then
				SJ.autoOff.AutoJumpEnabled = true
			end
			SJ.autoOff = nil
			if hum.AutoJumpEnabled then
				SJ.autoOff = hum
				hum.AutoJumpEnabled = false
			end
		elseif not SJ.suppressing and SJ.autoOff then
			if SJ.autoOff.Parent then
				SJ.autoOff.AutoJumpEnabled = true
			end
			SJ.autoOff = nil
		end
		if hop and hum and hum.Health > 0 and not busy(char) then
			SJ.hop(char, hum, now, hop == "plain")
			SJ.hopPress = raw and SJ.downAt or nil
		end
		if SJ.fixAt and root then
			local v = root.AssemblyLinearVelocity
			if now - SJ.fixAt > 0.2 then
				SJ.fixAt = nil
			elseif v.Y > 8 then
				SJ.fixAt = nil
				local g = tonumber(workspace.Gravity) or 196.2
				local up = ((Config.M1.Downslam or {}).HopSpeed or 50) - g * math.max(now - SJ.hopAt - 1 / 60, 0)
				root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(up, 8), v.Z)
			end
		end
		-- (round 81) a downslam thrown on the way up goes at the top of the hop
		local apexRoot = SJ.apexAt and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if SJ.apexAt and (not apexRoot or (apexRoot.AssemblyLinearVelocity.Y <= 0.5 and now - SJ.hopAt >= 0.12) or now - SJ.apexAt > 0.6) then
			SJ.apexAt = nil
			if apexRoot then
				useM1(false, true)
			end
		end
		-- (round 83) a 4th held back a moment (UpCommit): let go first, it was a
		-- tap (the hop above, then the downslam held for the top); held on, the
		-- upslam
		if SJ.commitAt and (not raw or now - (SJ.downAt or now) >= (SL.UpCommit or 0.1) or now - SJ.commitAt > (SL.UpCommit or 0.1) + 0.1) then
			SJ.commitAt = nil
			useM1(false)
		end
	end)
end

---------------------------------------------------------------------------
-- Guard: hold to block. The server owns the meter, parries and breaks.
---------------------------------------------------------------------------

-- notifyServer = false when the server already dropped it (guard break / hit from behind)
local function stopBlock(notifyServer)
	if not blocking then
		return
	end
	blocking = false
	local char = player.Character
	if notifyServer ~= false then
		UseAbility:FireServer(BLOCK, false)
	end
	if char then
		VFX.Play("Guard", char, { On = false, Target = char }, true)
	end
end

local function startBlock()
	local char = getCharacter()
	if blocking or not char or char:GetAttribute("Stunned") or char:GetAttribute("GuardBroken") or VFX.InOwnCinematic()
		or char:GetAttribute("Ragdolled") or char:GetAttribute("Frozen") or char:GetAttribute("Holding")
		or char:GetAttribute("Grabbed") or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished")
		or char:GetAttribute("Submerged") or Parkour.Busy or Hold.active or FreeCam.on or dashing or actionRemaining(char) > 0
		or char:GetAttribute("Parked") then -- (round 87: he's in another body)
		return
	end
	blocking = true
	UseAbility:FireServer(BLOCK, true)
	VFX.Play("Guard", char, { On = true, Target = char }, true)
end

---------------------------------------------------------------------------
-- Movement: sprint + directional dash (one extra dash in the air)
---------------------------------------------------------------------------

local sprintHeld = false
local sprintToggle = false -- mobile button toggles
local airDashesLeft = MOVE.AirDashes

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- JJS: a front dash that reaches someone ends in a punch. Checked every
-- frame of the dash on your own machine (it stops you the moment you get
-- there); the server checks the distance and lands it. (round 68) It's the
-- FIRST one IN YOUR PATH that takes it - a lane as wide as a body (Width
-- either side) down the way you're dashing, Reach ahead - a gut punch.
local DashPunch = {}
function DashPunch.check(char, root, lv, dir)
	local cfg = MOVE.DashPunch
	if not cfg or workspace:GetAttribute("DashPunchEnabled") == false then
		return false
	end
	local look = flat(root.AssemblyLinearVelocity)
	look = look.Magnitude > 1 and look.Unit or dir
	local reach, width = cfg.Reach or 6, cfg.Width or 2.2
	local best, bestAlong = nil, math.huge
	local function consider(model)
		local r = model ~= char and model:FindFirstChild("HumanoidRootPart")
		local h = r and model:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then
			return
		end
		local off = r.Position - root.Position
		local across = flat(off)
		local along = across:Dot(look)
		local side = (across - look * along).Magnitude
		if math.abs(off.Y) > (cfg.Height or 5) or along < -0.5 or along > reach or side > width then
			return -- (not in the lane)
		end
		if along < bestAlong then
			best, bestAlong = model, along -- (the nearest along it: the first you'd run into)
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			consider(other.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	for _, model in dummies and dummies:GetChildren() or {} do
		consider(model)
	end
	if not best then
		return false
	end
	lv:Destroy()
	local toward = flat(best.HumanoidRootPart.Position - root.Position)
	toward = toward.Magnitude > 0.1 and toward.Unit or look
	root.CFrame = CFrame.lookAt(root.Position, root.Position + toward)
	root.AssemblyLinearVelocity = toward * 8 + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	VFX.Play("DashPunch", char, { Target = best, Dir = toward }, true)
	UseAbility:FireServer(DASH, toward, "Punch", best)
	return true
end

-- The ragdoll cancel (Config.Evasive): DASH while you're down with the
-- meter full - the server stands you up, and the quickstep goes the way
-- you're holding (or to your right)
function DashPunch.evasive(char, hum)
	local EV = Config.Evasive
	if not EV or EV.Enabled == false or (char:GetAttribute("Evasive") or 0) < 100
		or player:GetAttribute("NoEvade") or workspace:GetAttribute("EvasiveEnabled") == false then
		return
	end
	if os.clock() - (DashPunch.lastEvasive or 0) < 0.4 then
		return
	end
	DashPunch.lastEvasive = os.clock()
	local cam = workspace.CurrentCamera
	local move = flat(hum.MoveDirection)
	local dir = move.Magnitude > 0.1 and move.Unit or (cam and flat(cam.CFrame.RightVector)) or Vector3.new(1, 0, 0)
	UseAbility:FireServer(DASH, dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0), "Evasive")
end

-- (round 65, JJS's anti-run: Config.Movement.ChaseDash) the player you're
-- aiming at who has turned their back and is running from you, if any
function DashPunch.fleeing(root, look)
	local CH = MOVE.ChaseDash or {}
	if CH.Enabled == false then
		return nil
	end
	local best, bestDist = nil, nil
	for _, plr in Players:GetPlayers() do
		local c = plr ~= player and plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and not c:GetAttribute("Ragdolled") then
			local to = flat(r.Position - root.Position)
			local dist = to.Magnitude
			if dist > 4 and dist <= (CH.Range or 45) then
				local away = to.Unit
				local angle = math.deg(math.acos(math.clamp(away:Dot(look), -1, 1)))
				local facing = flat(r.CFrame.LookVector)
				if angle <= (CH.Angle or 22) and facing.Magnitude > 0.1 and facing.Unit:Dot(away) > 0.3
					and flat(r.AssemblyLinearVelocity):Dot(away) >= (CH.MinSpeed or 12) and (not bestDist or dist < bestDist) then
					best, bestDist = c, dist
				end
			end
		end
	end
	return best
end

local function dash()
	local char, hum, root = getCharacter()
	if char and (char:GetAttribute("Ragdolled") or char:GetAttribute("ComboStun")) then
		DashPunch.evasive(char, hum) -- (round 68: out of a combo's hitstun too)
		return
	end
	if player:GetAttribute("NoSkills") then
		return -- (server settings: moves and dashes switched off)
	end
	if not char or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or dashing or VFX.InOwnCinematic()
		or char:GetAttribute("Kaiju") or Parkour.Busy or char:GetAttribute("Holding") or Hold.active
		or char:GetAttribute("Frozen") or char:GetAttribute("Grabbed") or char:GetAttribute("Finishing")
		or char:GetAttribute("BeingFinished") or char:GetAttribute("Submerged") or FreeCam.on
		or char:GetAttribute("Parked") then -- (round 87: he's in another body)
		return -- (a kaiju doesn't dash)
	end
	-- (round 65, JJS) a side or back dash can cut into your own M1 (thrown
	-- in the swing's startup, the punch still comes out from wherever the
	-- dash takes you). Only an M1's lock - never a move's (the server's own
	-- copy of the lock can trail it by the ping).
	local lockLeft = actionRemaining(char)
	local m1Until = CombatInput.m1Until or -1
	local m1Only = lockLeft > 0 and MOVE.DashOutOfM1 ~= false and CombatInput.untilAt <= m1Until + 0.01
		and (tonumber(char:GetAttribute("CombatActionUntil")) or 0) <= m1Until + 0.35
	if lockLeft > 0 and not m1Only then
		return
	end
	-- running at a gap you fit under: the dash key slides you through it
	if lockLeft <= 0 and Parkour.TrySlide and Parkour.TrySlide() then
		return
	end
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if not grounded and airDashesLeft <= 0 then
		return
	end
	-- direction: where you're moving (or forward), relative to the camera
	local camLook = flat(workspace.CurrentCamera.CFrame.LookVector)
	camLook = camLook.Magnitude > 0.05 and camLook.Unit or flat(root.CFrame.LookVector).Unit
	local move = flat(hum.MoveDirection)
	local dir = move.Magnitude > 0.1 and move.Unit or flat(root.CFrame.LookVector).Unit
	local dot = dir:Dot(camLook)
	local kind = dot > 0.5 and "Front" or dot < -0.5 and "Back" or (camLook:Cross(dir).Y > 0 and "Left" or "Right")
	-- (round 65, JJS's anti-run) the front dash is cooling down and they're
	-- running from you: the dash key still throws you after them
	if kind == "Front" and not player:GetAttribute("NoCooldowns") and lastUsed.DashFront
		and os.clock() - lastUsed.DashFront < (MOVE.FrontDashCooldown or 5) and DashPunch.fleeing(root, camLook) then
		kind = "Chase"
		dir = camLook
	end
	if lockLeft > 0 and (kind == "Front" or kind == "Chase") then
		return -- (only a side or back dash cuts into an M1)
	end
	local cooldown = kind == "Front" and (MOVE.FrontDashCooldown or 5) or (MOVE.MobilityDashCooldown or 2)
	local cooldownKey = kind == "Front" and "DashFront" or "DashMobility"
	if onCooldown(cooldownKey, cooldown) then
		return
	end
	stopBlock()
	CombatInput.pending = nil
	if scoped then
		ShopRemote:FireServer("Unscope")
	end
	if not grounded then
		airDashesLeft -= 1
	end

	dashing = true
	WhipDash.dashAt = os.clock() -- (round 75: Blackwhip right after it is the slingshot)
	VFX.SwingRelease(char) -- (a dash lets go of a swing, and of its fling)
	if kind ~= "Front" then
		-- sidestep / backstep keep facing the camera direction
		hum.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + camLook)
	else
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
	local att = Instance.new("Attachment")
	att.Name = "MobilityDashAttachment"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	-- strong but finite: an unlimited push into another player's body flings you both
	lv.MaxForce = math.max(root.AssemblyMass, 1) * 6000
	lv.ForceLimitsEnabled = true
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	-- Drive the ground plane only: jumping/falling keeps its natural arc.
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	local dashTime = (kind == "Front" and MOVE.FrontDashTime or kind == "Back" and MOVE.BackDashTime
		or kind == "Chase" and (MOVE.ChaseDash or {}).Time or MOVE.SideDashTime) or MOVE.DashTime
	local speed = MOVE.DashSpeed * (kind == "Back" and (MOVE.BackDashSpeed or 0.8) or 1)
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	if kind == "Back" and grounded then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, MOVE.BackDashHop or 16), v.Z)
	end
	lv.Parent = root
	predictAction(dashTime + (kind == "Front" and (MOVE.FrontWhiffRecovery or 0.18) or kind == "Back" and (MOVE.BackDashRecovery or 0) or 0))
	local function interrupted()
		return not root.Parent or not hum.Parent or hum.Health <= 0 or player.Character ~= char
			or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed")
			or root:FindFirstChild("Knockback") ~= nil
	end
	-- (round 65: the back dash steers too, like JJS / Rampage)
	local steerOn = MOVE.SteerDashes ~= false
	local side = kind == "Left" and -1 or kind == "Right" and 1 or 0
	local back = kind == "Back"
	local t0 = os.clock()
	local steer
	local finished = false
	local function finishDash(reason)
		if finished then return end
		finished = true
		if steer then steer:Disconnect() end
		lv:Destroy()
		att:Destroy()
		if activeDashCleanup == finishDash then activeDashCleanup = nil end
		dashing = false
		if hum.Parent then hum.AutoRotate = true end
		local recovery = kind == "Front" and (MOVE.FrontWhiffRecovery or 0.18) or kind == "Back" and (MOVE.BackDashRecovery or 0) or 0
		if reason == "Hit" then recovery = MOVE.DashHitRecovery or 0.08 end
		if reason == "Interrupted" then
			recovery = 0
			CombatInput.pending = nil
		end
		CombatInput.untilAt = workspace:GetServerTimeNow() + recovery
		if root.Parent and reason ~= "Interrupted" and reason ~= "Hit" then
			local v = root.AssemblyLinearVelocity
			local horizontal = flat(v)
			local exitSpeed = reason == "Wall" and 0 or math.min(horizontal.Magnitude, hum.WalkSpeed)
			root.AssemblyLinearVelocity = (horizontal.Magnitude > 0.1 and horizontal.Unit * exitSpeed or Vector3.zero) + Vector3.new(0, v.Y, 0)
		end
	end
	activeDashCleanup = finishDash
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.FilterDescendantsInstances = { char, VFX.Folder }
	wallParams.RespectCanCollide = true
	steer = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - t0
		if interrupted() or not lv.Parent then finishDash("Interrupted"); return end
		if elapsed >= dashTime then finishDash("Ended"); return end
		if kind == "Front" and DashPunch.check(char, root, lv, dir) then
			finishDash("Hit")
			return
		end
		if steerOn then
			local cam = workspace.CurrentCamera
			local look = cam and flat(cam.CFrame.LookVector)
			if look and look.Magnitude >= 0.05 then
				look = look.Unit
				dir = back and -look or side == 0 and look or look:Cross(Vector3.new(0, 1, 0)) * side
				root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
			end
		end
		local hit = workspace:Raycast(root.Position, dir * math.max(2.5, speed * math.min(dt, 0.05) + 1.2), wallParams)
		if hit and math.abs(hit.Normal.Y) < 0.65 and hit.Normal:Dot(dir) < -0.15 then
			finishDash("Wall")
			return
		end
		local tail = math.clamp((elapsed / dashTime - 0.62) / 0.38, 0, 1)
		local easedSpeed = speed * (1 - 0.65 * tail * tail)
		if back and MOVE.BackDashCurve then
			-- (round 66) the back dash keeps its own pace: flat out through the
			-- flip and the twist, only drifting while he's on his hands
			local c, k = MOVE.BackDashCurve, nil
			for i = 1, #c - 1 do
				if not k and elapsed <= c[i + 1][1] then
					local a = math.clamp((elapsed - c[i][1]) / math.max(c[i + 1][1] - c[i][1], 1e-3), 0, 1)
					k = c[i][2] + (c[i + 1][2] - c[i][2]) * a
				end
			end
			easedSpeed = speed * (k or c[#c][2])
		end
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * easedSpeed
	end)
	task.delay(dashTime + 0.05, function() finishDash("Ended") end)

	startCd(cooldownKey, cooldown)
	UseAbility:FireServer(DASH, dir, kind)
	VFX.Play("Dash", char, { Dir = dir, Kind = kind, Quirk = player:GetAttribute("Quirk"), Alt = altMode }, true)
end

-- (round 75) DEKU'S FLOAT (Nana Shimura's quirk - Config FullCowl's Float).
-- Pressing it doesn't lift him: he stays on his feet (it's armed for
-- Window seconds). Jump and he's up (Lift) - and flying for Duration where
-- the camera looks: W/S along the look (up and down with it), A/D across,
-- Space to rise; easing in and out (Accel), bobbing when he's still. The
-- DASH key flicks an Air Force behind him and he's thrown along the aim
-- (Boost, every BoostEvery). Coming down onto something puts him back on
-- his feet - jump to go up again while the time lasts. Gravity comes back
-- gently (Settle) when it runs out; a hit drops him out of it. A move or
-- an M1 holds him still in the air while it goes. This machine flies him;
-- the server passes the lift-off, the flicks and the touch-down on.
do
	local spec = {}
	local lv, att, vf, conn
	local vel = Vector3.zero
	local liftedAt, flyUntil, armedUntil, lastBoost, pauseUntil = 0, nil, 0, 0, 0
	local function look()
		local cam = workspace.CurrentCamera
		local l = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		return l.Magnitude > 0.01 and l.Unit or Vector3.new(0, 0, -1)
	end
	local function blocked(char, hum, root)
		return not (char and hum and root) or hum.Health <= 0 or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled")
			or char:GetAttribute("Grabbed") or char:GetAttribute("Frozen") or char:GetAttribute("Finishing")
			or char:GetAttribute("BeingFinished") or root:FindFirstChild("Knockback") ~= nil or player:GetAttribute("Quirk") ~= "FullCowl"
			or VFX.InOwnCinematic() or FreeCam.on or DevFly.active -- (round 86: one flight at a time)
	end
	local function clear()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for _, x in { lv, vf, att } do
			if x then
				x:Destroy()
			end
		end
		lv, vf, att = nil, nil, nil
	end
	-- gravity coming back gently: a lift that fades out over `time`
	local function settle(root, time)
		local a = Instance.new("Attachment")
		a.Parent = root
		local f = Instance.new("VectorForce")
		f.Attachment0 = a
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Parent = root
		local mass = root.AssemblyMass
		local t0 = os.clock()
		local c
		c = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - t0) / time
			if k >= 1 or not root.Parent then
				c:Disconnect()
				f:Destroy()
				a:Destroy()
				return
			end
			f.Force = Vector3.new(0, mass * workspace.Gravity * 0.85 * (1 - k), 0)
		end)
	end
	function FloatFly.armed()
		local now = os.clock()
		return now < armedUntil or (flyUntil ~= nil and now < flyUntil)
	end
	function FloatFly.stop(reason)
		if not FloatFly.active then
			return
		end
		FloatFly.active = false
		clear()
		local char, hum, root = getCharacter()
		if hum and hum.Parent then
			hum.AutoRotate = true
		end
		if reason == "Time" or reason == "Hit" then
			armedUntil, flyUntil = 0, nil
		end
		UseAbility:FireServer(Config.PARKOUR_INDEX, "FloatEnd")
		if char then
			VFX.Play("FloatFX", char, { Kind = "End" }, true)
		end
		if root and root.Parent and reason == "Time" then
			settle(root, spec.Settle or 1.2)
		end
	end
	-- a move or an M1 while he's up: held still in the air while it goes
	function FloatFly.pause(t)
		if FloatFly.active then
			pauseUntil = os.clock() + (t or 0.45)
		end
	end
	function FloatFly.lift()
		local char, hum, root = getCharacter()
		if FloatFly.active or not FloatFly.armed() or blocked(char, hum, root) then
			return false
		end
		local now = os.clock()
		flyUntil = flyUntil or (now + (spec.Duration or 7))
		armedUntil = 0
		FloatFly.active = true
		liftedAt = now
		att = Instance.new("Attachment")
		att.Name = "FloatAttachment"
		att.Parent = root
		lv = Instance.new("LinearVelocity")
		lv.Name = "Float"
		lv.Attachment0 = att
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 6000
		lv.ForceLimitsEnabled = true
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		local v = root.AssemblyLinearVelocity
		vel = Vector3.new(v.X, 0, v.Z) * 0.6 + Vector3.new(0, spec.Lift or 18, 0)
		lv.VectorVelocity = vel
		lv.Parent = root
		-- (while a move holds him still: gravity off, nothing else)
		vf = Instance.new("VectorForce")
		vf.Attachment0 = att
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = true
		vf.Force = Vector3.zero
		vf.Parent = root
		hum.AutoRotate = false
		UseAbility:FireServer(Config.PARKOUR_INDEX, "FloatLift", Vector3.yAxis)
		VFX.Play("FloatFX", char, { Kind = "Lift", Dir = Vector3.yAxis }, true)
		HUD.Callout("FLOAT - DASH: AIR FORCE", Color3.fromRGB(235, 255, 246))
		conn = RunService.Heartbeat:Connect(function(dt)
			local c, h, r = getCharacter()
			if c ~= char or blocked(c, h, r) or not lv or not lv.Parent then
				FloatFly.stop("Hit")
				return
			end
			local t = os.clock()
			if t > flyUntil then
				FloatFly.stop("Time")
				return
			end
			if t < pauseUntil then
				lv.Enabled = false
				vf.Force = Vector3.new(0, r.AssemblyMass * workspace.Gravity, 0)
				vel = r.AssemblyLinearVelocity * 0.5
				return
			end
			lv.Enabled = true
			vf.Force = Vector3.zero
			-- where he wants to go: along the look (pitch and all), across it,
			-- up on Space - and a slow bob when he's not going anywhere
			local l = look()
			local cam = workspace.CurrentCamera
			local fl = flat(l)
			fl = fl.Magnitude > 0.05 and fl.Unit or flat(r.CFrame.LookVector).Unit
			local fr = flat(cam and cam.CFrame.RightVector or r.CFrame.RightVector)
			fr = fr.Magnitude > 0.05 and fr.Unit or Vector3.zero
			local md = h.MoveDirection
			local want = l * md:Dot(fl) + fr * md:Dot(fr)
			if want.Magnitude > 1 then
				want = want.Unit
			end
			want *= spec.Speed or 34
			local up = UserInputService:IsKeyDown(Enum.KeyCode.Space)
			pcall(function()
				up = up or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
			end)
			if up and not FreeCam.directing then -- (round 87 review: Space is the director camera's freeze)
				want += Vector3.new(0, spec.Rise or 22, 0)
			elseif md.Magnitude < 0.1 then
				want += Vector3.new(0, math.sin(t * 2.4) * 1.4, 0)
			end
			vel = vel + (want - vel) * (1 - math.exp(-(spec.Accel or 4) * dt))
			lv.VectorVelocity = vel
			local fv = flat(vel)
			r.CFrame = CFrame.lookAt(r.Position, r.Position + ((fv.Magnitude > 4) and fv.Unit or fl))
			-- back on his feet (settling onto something): he walks; jump to go up again
			if t - liftedAt > 0.45 and h.FloorMaterial ~= Enum.Material.Air and vel.Y < 2 then
				FloatFly.stop("Landed")
			end
		end)
		return true
	end
	-- the dash key while he's up: an Air Force flick behind him, and he's off
	-- down the aim
	function FloatFly.boost()
		local now = os.clock()
		if not FloatFly.active or now - lastBoost < (spec.BoostEvery or 0.55) then
			return
		end
		lastBoost = now
		local d = look()
		vel = d * (spec.Boost or 95)
		pauseUntil = 0
		local char = getCharacter()
		UseAbility:FireServer(Config.PARKOUR_INDEX, "FloatBoost", d)
		if char then
			VFX.Play("FloatFX", char, { Kind = "Boost", Dir = d }, true)
		end
	end
	-- pressed: armed (on his feet till he jumps; already in the air - he's up)
	function FloatFly.arm(ability)
		spec = ability or Config.FindAbilityById("Float") or {}
		armedUntil = os.clock() + (spec.Window or 8)
		flyUntil = nil
		local _, hum = getCharacter()
		if hum and hum.FloorMaterial == Enum.Material.Air then
			FloatFly.lift()
		else
			HUD.Callout("FLOAT - JUMP TO LIFT OFF", Color3.fromRGB(235, 255, 246))
		end
	end
	VFX.Hooks.FloatArm = FloatFly.arm
	UserInputService.JumpRequest:Connect(function()
		-- (round 83: not in a grounded M1 chain - jump there is the slam's)
		if not FloatFly.active and FloatFly.armed() and not slamJump.suppressing then
			local _, hum = getCharacter()
			if hum and hum.FloorMaterial ~= Enum.Material.Air then
				task.defer(FloatFly.lift) -- (off the ground first: the jump's own push)
			end
		end
	end)
end

-- (round 86) HAWKS' FIERCE WINGS (Config FierceWings.Special, his R) - Float's
-- way: this machine flies him, the server opens the window and passes the
-- lift-off, the boosts and the landing on (Kit.HK.relay). A crouch (Crouch
-- seconds: he stays put - the clip's crouch), one huge downstroke throws him
-- up (Lift studs/s for LiftTime), then he flies for
-- Duration where the camera looks: W/S along the look (up and down with it),
-- A/D across, Space (pad A) up; easing in and out (Accel), bobbing when he's
-- still. His top speed is Speed x (Weak + (1 - Weak) x his feathers / 100):
-- thin wings fly slower. The dash key: a tuck dive down the aim (Boost
-- studs/s for BoostTime, BoostCost feathers, every BoostEvery). R again, the
-- time up, or no feathers left: he glides down (no faster than Glide) and
-- lands. A move or an M1 holds him still in the air while it goes; a hit
-- drops him out of it. Flying drains his feathers (the server's count).
do
	local spec = {}
	local lv, att, vf, conn
	local vel = Vector3.zero
	local startedAt, flyUntil, pauseUntil, boostUntil, lastBoost = 0, 0, 0, 0, 0
	local liftAt, carry, launched, seenServer = 0, Vector3.zero, false, false
	local airStart, catchUntil = false, 0 -- (round 90: R off the street - no crouch, no launch)
	local flyChar -- (the body that took off: a respawn mid-flight cleans up that one)
	local boostDir = Vector3.new(0, 0, -1)
	local gliding = false
	local kick = { vel = Vector3.zero, untilAt = 0 } -- (round 92, hawksair: a move throwing him - the stoop's swoop, the gale's recoil)
	-- (round 92, hawksair) his flying bar: the alt form while he flies, put on
	-- and off here at the moments the server puts it on and off (it's told the
	-- lift-off and the landing just before) - his keys and the HUD follow it
	function HawksFly.air(on)
		on = on == true and player:GetAttribute("Quirk") == "FierceWings"
		if altMode ~= on then
			altMode = on
			local c = player.Character
			if c then
				c:SetAttribute("QuirkAlt", on)
			end
			refreshHud(false)
		end
	end
	-- (round 92, hawksair) thrown by a move of his own: this velocity for
	-- `time` (eased into), then the flight's own steering again
	function HawksFly.kick(v, time)
		if HawksFly.active and typeof(v) == "Vector3" and v == v then
			kick.vel, kick.untilAt = v, os.clock() + (time or 0.3)
			pauseUntil = 0
		end
	end
	local function look()
		local cam = workspace.CurrentCamera
		local l = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		return l.Magnitude > 0.01 and l.Unit or Vector3.new(0, 0, -1)
	end
	local function feathers(char)
		return tonumber(char and char:GetAttribute("Feathers")) or 0
	end
	local function shiftLocked()
		return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	end
	-- (not his quirk, knocked about, in someone's hands, a cutscene - or the
	-- test menu's flight / the dev flight have him: theirs, not his)
	local function blocked(char, hum, root)
		return not (char and hum and root) or hum.Health <= 0 or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled")
			or char:GetAttribute("Grabbed") or char:GetAttribute("Frozen") or char:GetAttribute("Finishing")
			or char:GetAttribute("BeingFinished") or root:FindFirstChild("Knockback") ~= nil or player:GetAttribute("Quirk") ~= "FierceWings"
			or VFX.InOwnCinematic() or FreeCam.on or player:GetAttribute("Flight") == true or char:GetAttribute("DevFlying") ~= nil
	end
	local function clear()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for _, x in { lv, vf, att } do
			if x then
				x:Destroy()
			end
		end
		lv, vf, att = nil, nil, nil
	end
	-- the wings still out on the way down: gravity back over `time`
	local function settle(root, time)
		local a = Instance.new("Attachment")
		a.Name = "HawksSettleAttachment"
		a.Parent = root
		local f = Instance.new("VectorForce")
		f.Attachment0 = a
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Parent = root
		local mass = root.AssemblyMass
		local t0 = os.clock()
		local c
		c = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - t0) / time
			if k >= 1 or not root.Parent then
				c:Disconnect()
				f:Destroy()
				a:Destroy()
				return
			end
			f.Force = Vector3.new(0, mass * workspace.Gravity * 0.8 * (1 - k), 0)
		end)
	end
	function HawksFly.stop(reason)
		if not HawksFly.active then
			return
		end
		HawksFly.active = false
		clear()
		local char = flyChar
		flyChar = nil
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Parent then
			hum.AutoRotate = true
		end
		UseAbility:FireServer(Config.PARKOUR_INDEX, "HawksFlyEnd", reason == "Landed" and "Land" or tostring(reason))
		kick.untilAt = 0
		-- (round 92 review) down, the carry's over too (the server lets go on
		-- the landing it's just been sent): 1-4 are his own moves from now -
		-- they were still sent as follow-ups until the server's word came back
		-- (the server, carry gone, ran them as his moves with nothing shown here)
		local hadCarry = HawksFly.carry ~= nil
		if hadCarry then
			HawksFly.carry = nil
			HUD.HawksCarry(nil)
		end
		HawksFly.air(false) -- (round 92, hawksair: down - his own bar back, the moment the server's told)
		if hadCarry then
			refreshHud(false)
		end
		if char then
			if VFX.HK then
				VFX.HK.localFlying(char, false)
			end
			VFX.Play("HawksFlyFX", char, { Kind = "End", Land = reason == "Landed", Reason = tostring(reason) }, true)
		end
		if root and root.Parent and reason ~= "Landed" and reason ~= "Hit" then
			settle(root, 0.9)
		end
		-- (on his feet again: a moment before he can take off again - the
		-- server says the same)
		if reason == "Landed" and spec.LandCooldown and player:GetAttribute("Quirk") == "FierceWings" then
			local key = Config.CooldownKey("FierceWings", SPECIAL, altMode, ultMode)
			lastUsed[key] = os.clock() - math.max((spec.Cooldown or 4) - spec.LandCooldown, 0)
			startCd(key, spec.LandCooldown)
		end
	end
	-- a move or an M1 while he's up: held still in the air while it goes
	function HawksFly.pause(t)
		if HawksFly.active then
			pauseUntil = math.max(pauseUntil, os.clock() + (t or 0.45))
		end
	end
	-- (round 90 review) R off the street is the catch only past AirHeight
	-- studs over it (lower, it's the takeoff): decided here once - useAbility
	-- sends it with the cast, so every screen plays what his body does
	function HawksFly.airStart(ability, root, hum)
		return root ~= nil and hum ~= nil and hum.FloorMaterial == Enum.Material.Air
			and feetHeight(root, hum) > ((ability and ability.AirHeight) or 3)
	end
	function HawksFly.start(ability, air, opts)
		spec = ability or Config.FindAbilityById("FierceWings") or {}
		-- (round 92, hawksair) FEATHER CARRY takes off with them (opts.Carry):
		-- no crouch (the flick was it), straight into the downstroke; up
		-- already, he flies on with a fresh window
		local carrying = type(opts) == "table" and opts.Carry == true
		if carrying and HawksFly.active then
			flyUntil = math.max(flyUntil, os.clock() + (spec.Duration or 10))
			gliding = false
			return true
		end
		local char, hum, root = getCharacter()
		if HawksFly.active or blocked(char, hum, root) or root.Anchored then
			return false
		end
		local now = os.clock()
		HawksFly.active = true
		flyChar = char
		if HawksFly.fallOff then
			HawksFly.fallOff(char) -- (round 90: out of the braked fall - he's flying)
		end
		-- (round 90) already in the air (pressed off the street): no crouch, no
		-- launch - the wings catch him (his fall and drift arrested over
		-- AirCatch, a little lift at the end: AirPop) and he's flying at once
		-- (AirHeight: only that far off the street - lower, it's the takeoff)
		airStart = air == true and HawksFly.airStart(spec, root, hum)
		catchUntil = airStart and now + (spec.AirCatch or 0.22) or 0
		-- (round 86 review) the crouch first: he stays put for the clip's crouch
		-- (its Hit) and THEN the downstroke throws him - it used to lift him at
		-- once, so the crouch played 8 studs up and the dust spawned under nothing
		liftAt = now + ((airStart or carrying) and 0 or (spec.Crouch or 0.12))
		startedAt, flyUntil = now, liftAt + (spec.Duration or 10)
		pauseUntil, boostUntil = 0, 0
		gliding, launched, seenServer = false, airStart, false
		att = Instance.new("Attachment")
		att.Name = "HawksFlightAttachment"
		att.Parent = root
		lv = Instance.new("LinearVelocity")
		lv.Name = "HawksFlight"
		lv.Attachment0 = att
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 6000
		lv.ForceLimitsEnabled = true
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		local v = root.AssemblyLinearVelocity
		carry = Vector3.new(v.X, 0, v.Z) * 0.5
		vel = airStart and v or Vector3.zero -- (round 90: caught as he was moving)
		lv.VectorVelocity = vel
		lv.Parent = root
		-- (while a move holds him still: gravity off, nothing else)
		vf = Instance.new("VectorForce")
		vf.Attachment0 = att
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = true
		vf.Force = Vector3.zero
		vf.Parent = root
		hum.AutoRotate = false
		UseAbility:FireServer(Config.PARKOUR_INDEX, "HawksLift", Vector3.yAxis)
		HawksFly.air(true) -- (round 92, hawksair: up - his flying bar, the moment the server's told)
		kick.untilAt = 0
		if VFX.HK then
			VFX.HK.localFlying(char, true)
		end
		VFX.Play("HawksFlyFX", char, { Kind = "Lift", Dir = Vector3.yAxis }, true)
		if not carrying then
			HUD.Callout("FIERCE WINGS - DASH: DIVE  ·  R: LAND", Color3.fromRGB(255, 196, 186))
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			local c, h, r = getCharacter()
			if c ~= char or blocked(c, h, r) or not lv or not lv.Parent then
				HawksFly.stop("Hit")
				return
			end
			local t = os.clock()
			-- (a move holding him there, or the server carrying him: hands off)
			if t < pauseUntil or r.Anchored then
				lv.Enabled = false
				vf.Force = Vector3.new(0, r.AssemblyMass * workspace.Gravity, 0)
				vel = r.AssemblyLinearVelocity * 0.5
				return
			end
			lv.Enabled = true
			vf.Force = Vector3.zero
			-- (round 86 review) the server never let him up (it refused R: a
			-- cooldown race), or it's put him down since: so does this machine
			if c:GetAttribute("HawksFlying") == true then
				seenServer = true
			elseif seenServer or t - startedAt > 2 then
				HawksFly.stop("Server")
				return
			end
			local f = feathers(c)
			if not gliding and (t > flyUntil or f <= 0 or c:GetAttribute("Plucked")) then
				gliding = true -- (spent: down he comes)
			end
			local l = look()
			local cam = workspace.CurrentCamera
			local fl = flat(l)
			fl = fl.Magnitude > 0.05 and fl.Unit or flat(r.CFrame.LookVector).Unit
			if t < liftAt then
				vel = Vector3.zero -- (the crouch: held where he is)
			elseif t < catchUntil then
				-- (round 90) caught in the air: the fall and the drift arrested
				-- hard, a little lift as the downstroke ends
				vel = vel + (Vector3.new(vel.X * 0.25, spec.AirPop or 6, vel.Z * 0.25) - vel) * (1 - math.exp(-16 * dt))
			elseif t < liftAt + (spec.LiftTime or 0.2) and not airStart then
				-- the downstroke throws him straight up
				if not launched then
					launched = true
					vel = carry
				end
				vel = Vector3.new(vel.X * 0.9, spec.Lift or 70, vel.Z * 0.9)
			elseif t < kick.untilAt then
				vel = vel + (kick.vel - vel) * (1 - math.exp(-14 * dt)) -- (round 92, hawksair: thrown by his own move)
			elseif t < boostUntil and not gliding then
				vel = vel + (boostDir * (spec.Boost or 120) - vel) * (1 - math.exp(-12 * dt))
			else
				local weak = spec.Weak or 0.55
				local speed = (spec.Speed or 62) * (weak + (1 - weak) * math.clamp(f / 100, 0, 1))
					* (HawksFly.carry and (Config.HawksAir.spec().SpeedMult or 0.8) or 1) -- (round 92, hawksair: someone on his feathers)
				local fr = flat(cam and cam.CFrame.RightVector or r.CFrame.RightVector)
				fr = fr.Magnitude > 0.05 and fr.Unit or Vector3.zero
				local md = h.MoveDirection
				local want = l * md:Dot(fl) + fr * md:Dot(fr)
				if want.Magnitude > 1 then
					want = want.Unit
				end
				want *= speed
				-- (Space, the pad's A - and the phone's jump button: round 86 review)
				local up = jumpHeld(h)
				if gliding then
					-- coming down: carried on at half pace, falling no faster than Glide
					want = Vector3.new(want.X * 0.5, -(spec.Glide or 20), want.Z * 0.5)
				elseif up then
					want += Vector3.new(0, spec.Rise or 30, 0)
				elseif md.Magnitude < 0.1 then
					want += Vector3.new(0, math.sin(t * 2.2) * 1.6, 0)
				end
				vel = vel + (want - vel) * (1 - math.exp(-(spec.Accel or 3.5) * dt))
			end
			lv.VectorVelocity = vel
			local fv = flat(vel)
			local facing = (fv.Magnitude > 4) and fv.Unit or fl
			-- (round 86 review) shift-locked: he faces where you look and strafes
			-- (SmoothShiftLock turns him to the camera; this turned him back)
			local okLock, locked = pcall(shiftLocked)
			if okLock and locked then
				facing = fl
			end
			r.CFrame = CFrame.lookAt(r.Position, r.Position + facing)
			-- back on his feet (settling onto something): the flight's over -
			-- (round 92 review) not while a move of his throws him (the stoop's
			-- swoop starts on the street: that's not a landing)
			if t - liftAt > 0.5 and t >= kick.untilAt and h.FloorMaterial ~= Enum.Material.Air and vel.Y < 2 then
				HawksFly.stop("Landed")
			end
		end)
		return true
	end
	-- the dash key while he's up: the peregrine's tuck, down the aim
	function HawksFly.boost()
		local now = os.clock()
		if not HawksFly.active or now - lastBoost < (spec.BoostEvery or 0.9) or gliding then
			return
		end
		local char = getCharacter()
		if not char or feathers(char) < (spec.BoostCost or 5) or char:GetAttribute("Plucked") then
			HUD.Callout("NOT ENOUGH FEATHERS", Color3.fromRGB(255, 130, 115))
			return
		end
		lastBoost = now
		boostDir = look()
		boostUntil = now + (spec.BoostTime or 0.5)
		pauseUntil = 0
		UseAbility:FireServer(Config.PARKOUR_INDEX, "HawksBoost", boostDir)
		VFX.Play("HawksFlyFX", char, { Kind = "Boost", Dir = boostDir }, true)
	end
	VFX.Hooks.HawksFly = HawksFly.start
	VFX.Hooks.HawksKick = HawksFly.kick -- (round 92, hawksair: the stoop's swoop back up, the gale's recoil)
end

-- (round 90) hawks - HAWKS' WING-BRAKED FALL (Config FierceWings.Fall): off a real
-- drop (MinDrop studs under his feet - never an ordinary jump), once he's
-- falling faster than Engage for Delay seconds, his wings open into a
-- canopy and he falls no faster than Terminal (full wings) .. Bare (thin
-- ones): quadratic air drag (a VectorForce, at most MaxForce x his weight),
-- so it eases in. Jump held: spread wider (x Hold). No feathers / plucked:
-- the wings can't hold him. Not while he flies, is knocked about or held,
-- in a cutscene, in the storm. His own machine moves him; the server is
-- told on / off (HawksFall: HawksFalling on him) for everyone's wings and
-- pose. And a move or a held move in the air holds him up (HawksFly.hang:
-- the air barrage, the cyclone in the air - AirHover)
do
	local F = (Config.Quirks.FierceWings or {}).Fall or {}
	local att, force, on, since, hangUntil = nil, nil, false, nil, 0
	local fallChar, braked = nil, 0
	-- (round 90 review) asked: when the server was last told; filtered: the
	-- body the ray's filter is set for (not a new list every frame); byId: a
	-- held move looked up once (Config.FindAbilityById builds tables as it
	-- searches - not every frame)
	local memo = { asked = 0, byId = {} }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function relay(state)
		memo.asked = os.clock()
		UseAbility:FireServer(Config.PARKOUR_INDEX, "HawksFall", state)
	end
	local function off(char)
		if force then
			force:Destroy()
			force = nil
		end
		if att then
			att:Destroy()
			att = nil
		end
		since = nil
		if on then
			on = false
			if VFX.HK then
				VFX.HK.localFalling(fallChar or char, false)
			end
			relay(false)
		end
		fallChar = nil
	end
	HawksFly.fallOff = off
	-- (a move thrown in the air: he hangs there for it)
	function HawksFly.hang(t)
		hangUntil = math.max(hangUntil, os.clock() + (t or 0.45))
	end
	local function feetUp(char, root, hum)
		if memo.filtered ~= char then
			memo.filtered = char
			params.FilterDescendantsInstances = { char, VFX.Folder }
		end
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -400, 0), params)
		local hip = ((hum.HipHeight > 0) and hum.HipHeight or 2) + root.Size.Y / 2
		return hit and (root.Position.Y - hit.Position.Y - hip) or 400
	end
	local function blockedFall(char, hum, root)
		return hum.Health <= 0 or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed")
			or char:GetAttribute("Frozen") or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished") or char:GetAttribute("HawksStorm")
			or root.Anchored or root:FindFirstChild("Knockback") ~= nil or char:GetAttribute("DevFlying") ~= nil or player:GetAttribute("Flight") == true
			or VFX.InOwnCinematic() or FreeCam.on or HawksFly.active
	end
	local function ensureForce(root)
		if force and force.Parent and att and att.Parent == root then
			return force
		end
		if force then
			force:Destroy()
		end
		if att then
			att:Destroy()
		end
		att = Instance.new("Attachment")
		att.Name = "HawksFallAttachment"
		att.Parent = root
		force = Instance.new("VectorForce")
		force.Name = "HawksFall"
		force.Attachment0 = att
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.zero
		force.Parent = root
		return force
	end
	RunService.Heartbeat:Connect(function(dt)
		local char, hum, root = getCharacter()
		local mine = char and hum and root and player:GetAttribute("Quirk") == "FierceWings"
		if fallChar and fallChar ~= char then
			off(fallChar) -- (a new body, or not Hawks any more)
		end
		if not mine then
			if on or force then
				off(char)
			end
			return
		end
		-- (round 90 review) the server still has him falling and this machine
		-- doesn't: an "off" it never took (everything he sends is dropped in
		-- DIO's stopped time; a possession's parked body) - every screen would
		-- hold him in the canopy, its wind on, standing in the street. Told
		-- again every Fall.Resend seconds till it agrees
		if not on and char:GetAttribute("HawksFalling") ~= nil and os.clock() - memo.asked > (F.Resend or 0.5) then
			relay(false)
		end
		local airborne = hum.FloorMaterial == Enum.Material.Air
		local f = tonumber(char:GetAttribute("Feathers")) or 0
		local blockedNow = blockedFall(char, hum, root)
		local able = airborne and not blockedNow and f > 0 and not char:GetAttribute("Plucked")
		local v = root.AssemblyLinearVelocity
		local g = workspace.Gravity
		-- held up in the air for a move (it hangs there while it goes; a held
		-- move only if it says so - AirHover, the cyclone)
		local held = char:GetAttribute("Holding")
		local heldAb = held and memo.byId[held]
		if held and heldAb == nil then
			heldAb = Config.FindAbilityById(held) or false
			memo.byId[held] = heldAb
		end
		local hanging = airborne and not blockedNow
			and (os.clock() < hangUntil or (heldAb and heldAb.AirHover == true and feetUp(char, root, hum) > 2.5))
		if hanging then
			local fc = ensureForce(root)
			fc.Force = Vector3.new(0, root.AssemblyMass * g * (1 + math.clamp(-v.Y * 0.06, -0.6, 0.6)), 0)
			return
		end
		if not on then
			if force then
				local keep = since
				off(char) -- (a hang that's over: its force goes)
				since = keep
			end
			if able and v.Y < -(F.Engage or 18) then
				since = since or os.clock()
				if os.clock() - since >= (F.Delay or 0.12) and feetUp(char, root, hum) > (F.MinDrop or 12) then
					on, fallChar, braked = true, char, os.clock()
					ensureForce(root)
					if VFX.HK then
						VFX.HK.localFalling(char, true)
					end
					relay(true)
				end
			else
				since = nil
			end
			if not on then
				return
			end
		end
		if not able then
			off(char)
			return
		end
		-- (a long way down - from the sky arena, off the flight - he doesn't
		-- float all of it: once he's been under the canopy Stoop.After seconds
		-- with more than Stoop.Above studs still under his feet, the wings
		-- tuck and he stoops like a falcon, no faster than Stoop.Speed, and
		-- flares the canopy open again Stoop.Above over the street to land -
		-- higher when he's fast, so the canopy has room to slow him: the
		-- braking is (MaxForce - 1) g, plus Stoop.Above / 4 to spare)
		local ST = F.Stoop or {}
		local up = feetUp(char, root, hum)
		local stooping = on == "Stoop"
		local brakeA = math.max(((F.MaxForce or 1.6) - 1) * g, 1)
		local flare = math.max(ST.Above or 40, math.max(v.Y * v.Y - (F.Terminal or 22) ^ 2, 0) / (2 * brakeA) + (ST.Above or 40) / 4)
		if not stooping and os.clock() - braked > (ST.After or 2.5) and up > (ST.Above or 40) + 20 and not jumpHeld(hum) then
			on, stooping = "Stoop", true
			if VFX.HK then
				VFX.HK.localFalling(char, "Stoop")
			end
			relay("Stoop")
		elseif stooping and (up <= flare or jumpHeld(hum)) then
			on, stooping, braked = true, false, os.clock()
			if VFX.HK then
				VFX.HK.localFalling(char, true)
			end
			relay(true)
		end
		-- the canopy: thin wings hold him less (Bare at Feathers.Low and under)
		local Fe = (Config.Quirks.FierceWings or {}).Feathers or {}
		local w = math.clamp((f - (Fe.Low or 20)) / math.max((Fe.Max or 100) - (Fe.Low or 20), 1), 0, 1)
		local terminal = (F.Bare or 46) + ((F.Terminal or 22) - (F.Bare or 46)) * w
		if stooping then
			terminal = ST.Speed or 140
		elseif jumpHeld(hum) then
			terminal *= F.Hold or 0.6
		end
		local fall = -v.Y
		local k = fall > 0 and math.min((fall / terminal) ^ 2, F.MaxForce or 1.6) or 0
		ensureForce(root).Force = Vector3.new(0, root.AssemblyMass * g * k, 0)
	end)
end

-- (round 92) hawksair - HAWKS' CARRY on his own machine (Config.Quirks.
-- FierceWings.Alt.Carry; the server's Kit.HA). FEATHER CARRY's hook took
-- someone: the server says so on his body (HawksCarrying: who;
-- HawksCarryEnds: when he lets go by himself) and tells every screen
-- (FeatherCarryLift with Carry) - this machine takes off with them on it
-- (VFX's FeatherCarryLift: HawksFly.start with opts.Carry). While he holds
-- them his flying bar's 1-4 are the follow-ups (HawksFly.follow, from
-- useAbility: SKY TOSS, FEATHER FLURRY, GALE THROW, LET GO - sent as the slot
-- pressed, the server runs it), the bar says so (HUD.HawksCarry: their
-- names, a CARRYING chip with the time left), and his blades and his ult
-- wait. The one carried sees HELD BY <him> and the time left (HUD.CarryHeld,
-- the dev carry's chip). (Here, next to HawksFly: it shares that table and
-- runs in Hawks' own area - no new top-level locals.)
do
	local CA = { conns = {}, showing = false }
	HawksFly.CA = CA
	local GOLD = Color3.fromRGB(255, 206, 120)
	function CA.byId(id)
		if type(id) ~= "number" then
			return nil
		end
		for _, plr in Players:GetPlayers() do
			if plr.UserId == id then
				return plr
			end
		end
		return nil
	end
	-- his own carry: on (who, and when it ends) or off - the bar follows
	function CA.sync()
		local char = player.Character
		local who = char and char:GetAttribute("HawksCarrying")
		local on = who ~= nil and player:GetAttribute("Quirk") == "FierceWings"
		local was = HawksFly.carry
		if on then
			HawksFly.carry = {
				Name = tostring(who), Ends = char:GetAttribute("HawksCarryEnds"), Max = Config.HawksAir.spec().MaxHold or 3.5,
				acted = was and was.acted or nil,
			}
		else
			HawksFly.carry = nil
		end
		HUD.HawksCarry(HawksFly.carry and { Name = HawksFly.carry.Name, Ends = HawksFly.carry.Ends, Max = HawksFly.carry.Max } or nil)
		refreshHud(false)
		if on and not was then
			HUD.Callout("CARRYING " .. string.upper(tostring(who)), GOLD) -- (the bar says what 1-4 do now)
		end
	end
	-- the one carried (this screen's own body): HELD BY him, the time left
	function CA.heldSync()
		local char = player.Character
		local by = char and CA.byId(char:GetAttribute("HawksCarriedBy"))
		if by then
			CA.showing = true
			HUD.CarryHeld({ By = by.DisplayName, Ends = char:GetAttribute("HawksCarryEnds"), Max = (Config.HawksAir.spec().MaxHold or 3.5) + 0.35 })
		elseif CA.showing then
			CA.showing = false
			HUD.CarryHeld(nil)
		end
	end
	function CA.watch(char)
		for _, c in CA.conns do
			c:Disconnect()
		end
		table.clear(CA.conns)
		if char then
			for _, a in { "HawksCarrying", "HawksCarryEnds" } do
				table.insert(CA.conns, char:GetAttributeChangedSignal(a):Connect(CA.sync))
			end
			for _, a in { "HawksCarriedBy", "HawksCarryEnds" } do
				table.insert(CA.conns, char:GetAttributeChangedSignal(a):Connect(CA.heldSync))
			end
		end
		CA.sync()
		CA.heldSync()
	end
	player.CharacterAdded:Connect(CA.watch)
	player:GetAttributeChangedSignal("Quirk"):Connect(CA.sync)
	task.defer(CA.watch, player.Character)

	-- 1-4 while he holds someone: that slot's follow-up (true: handled here;
	-- R is still the landing, the dash his flight's dive)
	function HawksFly.follow(index)
		local c = HawksFly.carry
		if not c then
			return false
		end
		local slot = (index == 1 or index == 2 or index == 3) and index or (index == Config.EXTRA_INDEX and 4) or nil
		if not slot then
			return false
		end
		local m = Config.HawksAir.move(slot)
		local char, _, root = getCharacter()
		if not (m and char and root) then
			return true
		end
		-- (one at a time: the server lets one through every Gap)
		if c.acted and os.clock() - c.acted < math.max(Config.HawksAir.spec().Gap or 0.25, 0.3) then
			return true
		end
		local cost = m.Feathers or 0
		if cost > 0 and ((tonumber(char:GetAttribute("Feathers")) or 0) < cost or char:GetAttribute("Plucked")) then
			if os.clock() - (HawksFly.refusedAt or 0) >= 0.4 then
				HawksFly.refusedAt = os.clock()
				HUD.Callout(char:GetAttribute("Plucked") and "PLUCKED - REGROWING" or "NOT ENOUGH FEATHERS", Color3.fromRGB(255, 130, 115))
				VFX.Play("FeathersOut", char, { Plucked = char:GetAttribute("Plucked") == true }, true)
			end
			return true
		end
		c.acted = os.clock()
		local dir, pos = getAim(root)
		if m.ActionTime then
			if HawksFly.pause then
				HawksFly.pause(m.ActionTime + 0.1) -- (he hangs there for it)
			end
			predictAction(m.ActionTime)
		end
		UseAbility:FireServer(index, dir, pos)
		VFX.Play("HawksCarry", char, { Kind = "Press", Move = m.Id, Dir = dir }, true) -- (his own clip at once; the rest comes with the server's word)
		return true
	end
end

-- (round 75) DASH, THEN BLACKWHIP: the slingshot (Config FullCowl's
-- Blackwhip.Dash). Within Window seconds of a dash going off, Blackwhip
-- (4, with it picked) doesn't grab - the tendrils shoot out ahead and latch
-- on, the tension catapults him (Speed, a little Lift) out to Range, and
-- he keeps some of it when he lets go. Shares Blackwhip's cooldown (x
-- CooldownScale). His machine flies him; the server checks it, shows it
-- to everyone and clips whoever's in the way.
do
	function WhipDash.ready(ability)
		return ability and ability.Id == "Blackwhip" and ability.Dash ~= nil and not ultMode
			and (dashing or os.clock() - WhipDash.dashAt < (ability.Dash.Window or 0.5))
	end
	function WhipDash.go(ability, key)
		local char, hum, root = getCharacter()
		if not char or not hum or not root then
			return false
		end
		local spec = ability.Dash
		local full = ability.Cooldown or 10
		local length = full * (spec.CooldownScale or 0.6)
		if not player:GetAttribute("NoCooldowns") then
			if lastUsed[key] and os.clock() - lastUsed[key] < full then
				return false
			end
			lastUsed[key] = os.clock() - (full - length)
		end
		startCd(key, length)
		if activeDashCleanup then
			activeDashCleanup("Interrupted") -- (the dash snaps straight into the slingshot)
		end
		local cam = workspace.CurrentCamera
		local l = cam and cam.CFrame.LookVector or root.CFrame.LookVector
		local f = flat(l)
		f = f.Magnitude > 0.05 and f.Unit or flat(root.CFrame.LookVector).Unit
		-- along the aim (a little up off the street, never into it)
		local d = (f + Vector3.new(0, math.max(l.Y, spec.Lift or 0.12), 0)).Unit
		local speed = spec.Speed or 165
		local time = math.min(spec.Time or 0.55, (spec.Range or 85) / speed)
		UseAbility:FireServer(Config.PARKOUR_INDEX, "WhipDash", d)
		VFX.Play("WhipDash", char, { Dir = d, Time = time, Speed = speed }, true)
		predictAction(time * 0.6)
		dashing = true
		hum.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + f)
		local att = Instance.new("Attachment")
		att.Name = "WhipDashAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 6000
		lv.ForceLimitsEnabled = true
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = d * speed * 0.4
		lv.Parent = root
		local wallParams = RaycastParams.new()
		wallParams.FilterType = Enum.RaycastFilterType.Exclude
		wallParams.FilterDescendantsInstances = { char, VFX.Folder }
		wallParams.RespectCanCollide = true
		local t0 = os.clock()
		local done = false
		local conn
		local function finish(keep)
			if done then
				return
			end
			done = true
			conn:Disconnect()
			lv:Destroy()
			att:Destroy()
			dashing = false
			if hum.Parent then
				hum.AutoRotate = true
			end
			if root.Parent and keep then
				root.AssemblyLinearVelocity = d * speed * 0.45 -- (he flies on a little when he lets go)
			end
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - t0
			if not root.Parent or hum.Health <= 0 or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled")
				or char:GetAttribute("Grabbed") or root:FindFirstChild("Knockback") then
				finish(false)
				return
			end
			if t >= time then
				finish(true)
				return
			end
			-- the tension: slow off the mark, then it yanks him
			local k = math.clamp(t / time, 0, 1)
			local s = speed * (0.4 + 0.9 * math.sin(math.min(k * 1.25, 1) * math.pi * 0.5))
			local hit = workspace:Raycast(root.Position, d * math.max(3, s * math.min(dt, 0.05) + 1.5), wallParams)
			if hit and math.abs(hit.Normal.Y) < 0.65 then
				finish(false)
				return
			end
			lv.VectorVelocity = d * s
		end)
		task.delay(time + 0.1, function()
			finish(true)
		end)
		return true
	end
end

-- All Might: jump again in mid-air (muscle form / ult) for a huge leap
local airborneSince = nil
local leapUsed = false

UserInputService.JumpRequest:Connect(function()
	local char, hum, root = getCharacter()
	if not char or char:GetAttribute("Stunned") or dashing or Parkour.Busy or Parkour.WallNear then
		return -- (beside a wall, jump is a wall hop)
	end
	local quirk = Config.Quirks[player:GetAttribute("Quirk") or ""]
	local leap = quirk and quirk.SuperLeap
	if not leap or not (leap.Always or altMode or ultMode) or leapUsed or (char:GetAttribute("ErasedUntil") or 0) > workspace:GetServerTimeNow() then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air or not airborneSince or os.clock() - airborneSince < 0.2 then
		return
	end
	if onCooldown("Leap", leap.Cooldown) then
		return
	end
	leapUsed = true
	local move = flat(hum.MoveDirection)
	local dir = move.Magnitude > 0.1 and move.Unit or flat(root.CFrame.LookVector).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	root.AssemblyLinearVelocity = dir * leap.Forward + Vector3.new(0, leap.Up, 0)
	UseAbility:FireServer(Config.LEAP_INDEX, dir)
	VFX.Play("SuperLeap", char, {}, true)
end)

-- how far the left stick is pushed (0..1)
local function stickMagnitude()
	local ok, state = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
	if not ok or type(state) ~= "table" then
		return 0
	end
	for _, input in state do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			return Vector2.new(input.Position.X, input.Position.Y).Magnitude
		end
	end
	return 0
end

-- Sprint + camera FOV kick
local fovTween
local sprintTrack
local lastSprinting = false
-- (Config.Movement.Feel) the speed a run has picked up to so far
local feel = { speed = nil }
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(tonumber(dt) or 1 / 60, 0.1)
	local char, hum = getCharacter()
	local cam = workspace.CurrentCamera
	local sprinting = false
	-- (a controller sprints by pushing the stick all the way, like JJS)
	local stickSprint = inputMode == "Gamepad" and stickMagnitude() >= (Config.AutoSprintStick or 0.9)
	-- (round 65) AUTO RUN (the settings, like JJS): moving is running
	local autoRun = player:GetAttribute("AutoRun") == true
	if char and (sprintHeld or sprintToggle or stickSprint or Parkour.Latched or autoRun) and not char:GetAttribute("Stunned") and not blocking
		and not scoped and hum.MoveDirection.Magnitude > 0.1 then
		sprinting = true
	end
	Parkour.Running = sprinting
	if char and not char:GetAttribute("Stunned") then
		local FEEL = MOVE.Feel or {}
		local base = char:GetAttribute("BaseWalkSpeed") or Config.BaseWalkSpeed
		-- (JJS) the more hurt you are, the slower you move
		local walk = base
		if hum.MaxHealth > 0 then
			walk *= 1 - (FEEL.HurtSlow or 0) * (1 - math.clamp(hum.Health / hum.MaxHealth, 0, 1))
		end
		local target = sprinting and walk * MOVE.SprintMultiplier or walk
		if blocking then
			target = math.min(base, GUARD.BlockWalkSpeed or 7)
		end
		-- (round 81) chaining M1s: about half a walk, so walking can't outrun
		-- the swings (the step and the pull on a landed hit do the closing)
		if (CombatInput.m1SlowUntil or 0) > os.clock() then
			target = math.min(target, walk * (Config.M1.ChainWalk or 0.5))
		end
		local slowedTo = char:GetAttribute("SlowedTo")
		if type(slowedTo) == "number" then
			target = math.min(target, slowedTo) -- e.g. caught inside a domain
		end
		if VFX.InOwnCinematic() then
			target = 0
		end
		-- walking starts and stops on a dime; a run picks up over RunBuild
		if sprinting then
			local from = feel.speed or math.min(walk, target)
			local rate = math.max(target - walk, 0) / math.max(FEEL.RunBuild or 0.15, 0.01)
			feel.speed = math.min(target, from + rate * dt)
		else
			feel.speed = nil
		end
		local want = feel.speed or target
		if math.abs(hum.WalkSpeed - want) > 0.01 then
			hum.WalkSpeed = want
		end
	end
	if sprinting ~= lastSprinting and char then
		local id = Config.Animations and Config.Animations.Sprint
		local rig = Config.Animations and Config.Animations.Rig
		local rigOk = hum ~= nil and (not rig or rig == "" or hum.RigType.Name == rig)
		if sprinting and id and id ~= "" and rigOk then
			sprintTrack = VFX.PlayAnimation(char, id, { Looped = true, Priority = Enum.AnimationPriority.Movement })
		elseif sprintTrack then
			sprintTrack:Stop(0.2)
			sprintTrack = nil
		end
	end
	if VFX.InCinematic() then
		if fovTween then fovTween:Cancel(); fovTween = nil end
	elseif sprinting ~= lastSprinting and cam and not scoped and not DevFly.active then -- (round 86: dev flight drives the view itself)
		lastSprinting = sprinting
		if fovTween then
			fovTween:Cancel()
		end
		fovTween = TweenService:Create(cam, TweenInfo.new(0.25), { FieldOfView = sprinting and MOVE.SprintFov or MOVE.NormalFov })
		fovTween:Play()
	end
end)

---------------------------------------------------------------------------
-- Parkour (Config.Parkour). Nothing happens by itself - YOU do it: running
-- at something, press jump to vault it, climb it or run up it, and dash to
-- slide under it; press jump beside a wall while moving to run along it and
-- kick off (one press, one hop - hops by health); press jump just before
-- landing a big fall to roll out of it. Your own machine moves you (it owns
-- your physics); the server passes the move on so others see it.
---------------------------------------------------------------------------
do
	local PK = Config.Parkour or {}
	local HOP = PK.WallHop or {}
	local ROLL = PK.Roll or {}
	local UPV = Vector3.new(0, 1, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function()
		params.RespectCanCollide = true -- (bushes and decorations you walk through aren't walls)
	end)
	-- (state kept in one table: this script watches its local count)
	local S = { hops = 0, groundedAt = 0, lastMove = 0, peakY = nil, rollAt = nil, jumpWas = false, lastHop = 0, wTap = 0 }

	-- only the map counts: not people, dummies, effects, rubble or the shops
	-- (the list is rebuilt once a frame, before any of this frame's rays)
	local function refreshFilter()
		local list = { player.Character, VFX.Folder }
		for _, plr in Players:GetPlayers() do
			if plr.Character then
				table.insert(list, plr.Character)
			end
		end
		for _, name in { "Dummies", "MapDebris", "Shops" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
		params.FilterDescendantsInstances = list
	end
	local function cast(origin, dir)
		local hit = workspace:Raycast(origin, dir, params)
		-- (see-through walls - map edges - aren't parkour)
		if hit and hit.Instance and hit.Instance:IsA("BasePart") and hit.Instance.Transparency >= 0.95 then
			return nil
		end
		return hit
	end
	local function upright(hit)
		return hit ~= nil and hit.Normal.Y > 0.7
	end
	local function wall(hit)
		return hit ~= nil and math.abs(hit.Normal.Y) < 0.35
	end

	-- (round 68) NEVER THROUGH A WALL: a vault, climb, run up or slide drives
	-- the body along a path (it can't catch on the ledge it goes over), so
	-- first a body-sized box - torso and head: the feet may brush the edge
	-- they go over - is swept along the whole path, and if it meets anything
	-- solid (a wall behind a low one, an overhang, the building past the
	-- ledge) the move doesn't happen; and while one plays, a step that would
	-- put the body into something stops it right there, short of it
	local BODY = Vector3.new(1.3, 2.7, 0.8)
	local SMALL = Vector3.new(0.7, 0.7, 0.7) -- (a slide: the hips, low down - a wall stops it, a bar overhead doesn't)
	local function swept(fromCF, toCF, size)
		local delta = toCF.Position - fromCF.Position
		if delta.Magnitude < 1e-3 then
			return nil
		end
		-- (the body box sits over the torso and head; a slide's, at the hips)
		local lift = size == SMALL and -0.6 or 0.45
		local ok, hit = pcall(function()
			return workspace:Blockcast(CFrame.new(fromCF.Position + UPV * lift) * fromCF.Rotation, size or BODY, delta, params)
		end)
		return ok and hit or nil
	end
	local function pathClear(path, size, steps)
		steps = steps or 14
		local last = path(0)
		for i = 1, steps do
			local cf = path(i / steps)
			if swept(last, cf, size) then
				return false
			end
			last = cf
		end
		return true
	end
	Parkour.PathClear = pathClear -- (for the tests)

	local function tell(kind, dir, side, time)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, dir, side, time)
	end

	-- Move the body along a path (CFrame-driven, so it can't catch on the
	-- ledge it's going over). path(a) -> root CFrame for a in 0..1.
	local function drive(char, hum, root, duration, path, done, size)
		Parkour.Busy = true
		char:SetAttribute("Parkour", true)
		hum.PlatformStand = true
		hum.AutoRotate = false
		local t0 = os.clock()
		local last = root.CFrame
		local finished = false
		local function finish(ok)
			if finished then
				return
			end
			finished = true
			RunService:UnbindFromRenderStep("QuirkParkour")
			if hum.Parent then
				hum.PlatformStand = false
				hum.AutoRotate = true -- (shift lock takes it back each frame if it's on)
			end
			char:SetAttribute("Parkour", nil)
			Parkour.Busy = false
			S.lastMove = os.clock()
			if done then
				done(ok)
			end
		end
		RunService:BindToRenderStep("QuirkParkour", Enum.RenderPriority.Camera.Value + 5, function(dt)
			if not root.Parent or not hum.Parent or hum.Health <= 0 or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") then
				finish(false)
				return
			end
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			local cf = path(a)
			-- (round 68) about to go into something: stop short of it
			if swept(last, cf, size) then
				root.CFrame = last
				root.AssemblyLinearVelocity = Vector3.zero
				finish(false)
				return
			end
			root.CFrame = cf
			root.AssemblyLinearVelocity = (cf.Position - last.Position) / math.max(dt, 1 / 240)
			last = cf
			if a >= 1 then
				finish(true)
			end
		end)
		return finish
	end

	-- a push for a moment (wall running / kicking off), with a bounded force
	local function push(root, velocity, duration)
		local att = Instance.new("Attachment")
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 5000
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = velocity
		lv.Parent = root
		task.delay(duration, function()
			lv:Destroy()
			att:Destroy()
		end)
		return lv
	end

	-- a push on the flat only (gravity still has the up and down)
	local function pushFlat(root, velocity, duration)
		local att = Instance.new("Attachment")
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 2500
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = root
		task.delay(duration, function()
			lv:Destroy()
			att:Destroy()
		end)
		return lv
	end
	Parkour.PushFlat = pushFlat

	local function facing(f, pos)
		return CFrame.lookAt(pos, pos + f)
	end

	-- keep the speed you came in with
	local function carry(root, f, speed)
		root.AssemblyLinearVelocity = f * speed + Vector3.new(0, -4, 0)
	end

	local function vault(char, hum, root, f, hit, top, feetY)
		local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude, hum.WalkSpeed)
		-- where you come down: just past the far side
		local far = hit.Position + f * 3.6
		local land = cast(Vector3.new(far.X, top.Position.Y + 2, far.Z), Vector3.new(0, -24, 0))
		local landY = land and land.Position.Y or feetY
		local from = root.CFrame.Position
		local to = Vector3.new(far.X, landY + 3, far.Z) + f * 1.2
		local mid = (from.Y + to.Y) / 2
		local lift = math.max(top.Position.Y + 3.5 - mid, 1)
		local time = (PK.VaultTime or 0.36) * math.clamp((to - from).Magnitude / 9, 0.8, 1.4)
		local function path(a)
			local p = from:Lerp(to, a) + UPV * lift * 4 * a * (1 - a)
			return facing(f, p)
		end
		if not pathClear(path) then
			return false -- (round 68: something solid in the way - a plain jump instead)
		end
		tell("Vault", f, nil, time)
		VFX.Play("Parkour", char, { Kind = "Vault", Dir = f, Time = time }, true)
		drive(char, hum, root, time, path, function(ok)
			if ok then
				carry(root, f, speed)
			end
		end)
		return true
	end

	-- up onto the top of it: hands on the edge, knees up, over
	local function climb(char, hum, root, f, hit, top, feetY)
		local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude * 0.6, hum.WalkSpeed * 0.8)
		local from = root.CFrame.Position
		local face = hit.Position
		local hang = Vector3.new(face.X, top.Position.Y + 2.4, face.Z) - f * 1.05
		local stand = Vector3.new(face.X, top.Position.Y + 3, face.Z) + f * 1.6
		local height = hang.Y - from.Y
		local up = math.max(height / (PK.ClimbSpeed or 34), 0.14)
		local over = 0.22
		local time = up + over
		local low = top.Position.Y - feetY <= (PK.VaultMax or 4.6)
		local function path(a)
			local t = a * time
			if t < up then
				local k = t / up
				-- hug the wall on the way up
				local p = from:Lerp(Vector3.new(hang.X, from.Y, hang.Z), math.min(k * 3, 1))
				return facing(f, Vector3.new(p.X, from.Y + height * k, p.Z))
			end
			local k = (t - up) / over
			return facing(f, hang:Lerp(stand, k) + UPV * 0.8 * math.sin(math.pi * k))
		end
		if not pathClear(path) then
			return false -- (round 68: no room up there - an overhang, or the building behind it)
		end
		tell(low and "Mantle" or "Climb", f, nil, time)
		VFX.Play("Parkour", char, { Kind = low and "Mantle" or "Climb", Dir = f, Time = time }, true)
		drive(char, hum, root, time, path, function(ok)
			if ok then
				carry(root, f, speed)
			end
		end)
		return true
	end

	-- too tall to top out: run a way up it, then it's up to your wall hops
	local function runUp(char, hum, root, f, hit)
		local from = root.CFrame.Position
		local rise = PK.WallRunUp or 10
		local at = Vector3.new(hit.Position.X, from.Y, hit.Position.Z) - f * 1.05
		local time = rise / (PK.ClimbSpeed or 34)
		local function path(a)
			local p = from:Lerp(at, math.min(a * 3, 1))
			return facing(f, Vector3.new(p.X, from.Y + rise * a, p.Z))
		end
		if not pathClear(path) then
			return false -- (round 68: a balcony or a ledge in the way)
		end
		tell("WallUp", f, nil, time)
		VFX.Play("Parkour", char, { Kind = "WallUp", Dir = f, Time = time }, true)
		drive(char, hum, root, time, path, function(ok)
			if ok then
				root.AssemblyLinearVelocity = UPV * 12 - f * 2
				S.hops = 0 -- (a fresh set of wall hops from up here)
			end
		end)
	end

	-- under it, feet first, lying back
	local function slide(char, hum, root, f, dist, feetY)
		local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude, hum.WalkSpeed)
		local from = root.CFrame.Position
		local to = Vector3.new(from.X, feetY + 3, from.Z) + f * dist
		local time = PK.SlideTime or 0.45
		local function path(a)
			local p = from:Lerp(to, a)
			local low = math.sin(math.pi * math.min(a * 1.4, 1))
			-- (lie back: the whole body tips over while it's low)
			return CFrame.lookAt(Vector3.new(p.X, feetY + 3 - 1.7 * low, p.Z), Vector3.new(p.X, feetY + 3 - 1.7 * low, p.Z) + f)
				* CFrame.Angles(math.rad(70) * low, 0, 0)
		end
		if not pathClear(path, SMALL) then
			return false -- (round 68: it doesn't go through)
		end
		tell("Slide", f, nil, time)
		VFX.Play("Parkour", char, { Kind = "Slide", Dir = f, Time = time }, true)
		drive(char, hum, root, time, path, function(ok)
			if ok then
				carry(root, f, speed)
			end
		end, SMALL)
		return true
	end

	-- (round 65) LEDGE CATCH (Config.Parkour.LedgeCatch): in the air, moving
	-- at a ledge your hands can reach - jump pressed, or held as you get
	-- there - and you pull yourself up onto it
	local function ledge(char, hum, root)
		local LC = PK.LedgeCatch or {}
		if LC.Enabled == false then
			return false
		end
		local f = flat(hum.MoveDirection)
		if f.Magnitude < 0.3 then
			return false
		end
		f = f.Unit
		local pos = root.CFrame.Position
		local hit = cast(pos + UPV * 0.6, f * (LC.Reach or 3.2))
		if not wall(hit) then
			return false
		end
		local n = flat(hit.Normal)
		if n.Magnitude < 0.1 or f:Dot(-n.Unit) < 0.5 then
			return false -- (only going at it, not along it: that's a wall hop)
		end
		local lowest, highest = pos.Y - (LC.Below or 1.2), pos.Y + (LC.Above or 4.2)
		local inside = hit.Position + f * 0.6
		local top = cast(Vector3.new(inside.X, highest + 0.5, inside.Z), Vector3.new(0, -(highest + 0.5 - lowest), 0))
		if not upright(top) or top.Position.Y < lowest or cast(top.Position + UPV * 0.2, UPV * 5.2) then
			return false -- (out of reach, or no room to stand up there)
		end
		return climb(char, hum, root, f, hit, top, pos.Y - 3) == true
	end
	Parkour.Ledge = ledge

	-- out of a big fall: a forward roll, further the bigger the fall
	local function roll(char, hum, root, fall)
		local move = flat(hum.MoveDirection)
		local f = move.Magnitude > 0.1 and move.Unit or flat(root.CFrame.LookVector).Unit
		local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude, hum.WalkSpeed)
		local g = cast(root.CFrame.Position, Vector3.new(0, -8, 0))
		local feetY = g and g.Position.Y or (root.CFrame.Position.Y - 3)
		local dist = math.clamp((ROLL.Base or 8) + fall * (ROLL.PerStud or 0.35), ROLL.Base or 8, ROLL.Max or 26)
		local ahead = cast(root.CFrame.Position, f * (dist + 1.5))
		if ahead then
			dist = math.max(ahead.Distance - 1.5, 0.5) -- (not into a wall)
		end
		local from = Vector3.new(root.CFrame.Position.X, feetY + 3, root.CFrame.Position.Z)
		local to = from + f * dist
		local time = ROLL.Time or 0.45
		-- (round 65, JJS) the fall's speed turns into speed out of the roll
		local boost = math.min((S.rollFall or 0) * (ROLL.Convert or 0.3), ROLL.MaxBoost or 22)
		S.rollFall = nil
		tell("Roll", f, nil, time)
		VFX.Play("Parkour", char, { Kind = "Roll", Dir = f, Time = time }, true)
		drive(char, hum, root, time, function(a)
			local p = from:Lerp(to, a) - UPV * 1.3 * math.sin(math.pi * a)
			return facing(f, p) * CFrame.Angles(-math.pi * 2 * a, 0, 0)
		end, function(ok)
			if ok then
				local out = math.max(speed, hum.WalkSpeed) + boost
				carry(root, f, out)
				if boost > 1 then
					pushFlat(root, f * out, ROLL.Carry or 0.25)
				end
			end
		end)
	end

	-- a wall beside you (either side, or ahead at an angle): the closest one
	local function sideWall(root)
		local right = flat(root.CFrame.RightVector)
		local look = flat(root.CFrame.LookVector)
		if right.Magnitude < 0.1 or look.Magnitude < 0.1 then
			return nil
		end
		right, look = right.Unit, look.Unit
		local best, side
		local reach = (HOP.Range or 2.8) + 0.5
		for _, probe in { { right, "R" }, { -right, "L" }, { (right + look).Unit, "R" }, { (look - right).Unit, "L" } } do
			local hit = cast(root.CFrame.Position, probe[1] * reach)
			if wall(hit) and (not best or hit.Distance < best.Distance) then
				best, side = hit, probe[2]
			end
		end
		return best, side
	end

	-- hops in a row allowed at this much health (Config: ByHealth)
	local function hopsAllowed(hum)
		local share = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
		for _, row in HOP.ByHealth or { { 0, 3 } } do
			if share > row[1] then
				return row[2]
			end
		end
		return 1
	end

	local function wallHop(char, hum, root, hit, side)
		local n = flat(hit.Normal)
		n = n.Magnitude > 0.05 and n.Unit or -flat(root.CFrame.RightVector).Unit
		local move = flat(hum.MoveDirection)
		local along = move - n * move:Dot(n)
		if along.Magnitude < 0.2 then
			local look = flat(root.CFrame.LookVector)
			along = look - n * look:Dot(n)
		end
		if along.Magnitude < 0.1 then
			return false
		end
		along = along.Unit
		S.hops += 1
		S.lastHop = os.clock()
		Parkour.Busy = true
		char:SetAttribute("Parkour", true)
		hum.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.CFrame.Position, root.CFrame.Position + along)
		tell("WallRun", along, side, HOP.RunTime or 0.3)
		VFX.Play("Parkour", char, { Kind = "WallRun", Dir = along, Side = side, Time = HOP.RunTime or 0.3 }, true)
		-- along the wall, rising, pressed into it
		local run = push(root, along * (HOP.RunSpeed or 30) + UPV * (HOP.RunRise or 16) - n * 2, HOP.RunTime or 0.3)
		task.delay(HOP.RunTime or 0.3, function()
			local kickTime = HOP.KickTime or 0.16
			if root.Parent and hum.Health > 0 and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled") then
				-- (the run's push goes first, so the two never fight over the body)
				if run.Parent then
					run:Destroy()
				end
				local out = n * (HOP.KickOut or 58) + along * (HOP.KickAlong or 22)
				push(root, out + UPV * (HOP.KickUp or 58), kickTime)
				-- then keep flying outward a moment: your air steering can't eat the kick
				task.delay(kickTime, function()
					if root.Parent and hum.Health > 0 then
						root.AssemblyLinearVelocity = Vector3.new(out.X, root.AssemblyLinearVelocity.Y, out.Z)
						pushFlat(root, out * 0.85, HOP.Carry or 0.25)
					end
				end)
				tell("WallKick", n)
				VFX.Play("Parkour", char, { Kind = "WallKick", Dir = n }, true)
			end
			task.wait(kickTime)
			if hum.Parent then
				hum.AutoRotate = true
			end
			char:SetAttribute("Parkour", nil)
			Parkour.Busy = false
			S.lastMove = os.clock()
		end)
		return true
	end

	-- running at something and jump pressed: what is it, and what do we do
	-- about it? (slide: only when asked for - see Parkour.TrySlide)
	local function obstacle(char, hum, root, slideOnly)
		local f = flat(hum.MoveDirection)
		if f.Magnitude < 0.5 then
			return
		end
		f = f.Unit
		local g = cast(root.CFrame.Position, Vector3.new(0, -8, 0))
		if not upright(g) then
			return
		end
		local feetY = g.Position.Y
		local reach = PK.Reach or 3.2
		local base = Vector3.new(root.CFrame.Position.X, feetY, root.CFrame.Position.Z)
		local shin = cast(base + UPV * 0.9, f * reach)
		local waist = cast(base + UPV * 2.3, f * reach)
		local head = cast(base + UPV * 4.4, f * reach)
		if wall(shin) and not slideOnly then
			-- find its top (from above, just inside the face)
			local climbMax = PK.ClimbMax or 16
			local inside = shin.Position + f * 0.6
			local top = cast(Vector3.new(inside.X, feetY + climbMax + 2, inside.Z), Vector3.new(0, -(climbMax + 1.2), 0))
			if upright(top) and not cast(top.Position + UPV * 0.2, UPV * 5.2) then
				local h = top.Position.Y - feetY
				if h < 1.4 then
					return -- (a step: the Humanoid walks up it)
				end
				if h <= (PK.VaultMax or 4.6) then
					-- thin (the top ends within a couple of studs): over it; deep: onto it
					local past = shin.Position + f * 3.2
					local beyond = cast(Vector3.new(past.X, top.Position.Y + 1, past.Z), Vector3.new(0, -1.6, 0))
					if beyond then
						climb(char, hum, root, f, shin, top, feetY)
					else
						vault(char, hum, root, f, shin, top, feetY)
					end
				else
					climb(char, hum, root, f, shin, top, feetY)
				end
				return
			end
			-- (a real wall: wide, not a lamp post)
			local side = f:Cross(UPV).Unit * 1.3
			local wide = wall(cast(base + UPV * 2.3 + side, f * reach)) and wall(cast(base + UPV * 2.3 - side, f * reach))
			if wide and wall(waist) and wall(head) and os.clock() - (S.runUpAt or 0) > 1.2 then
				S.runUpAt = os.clock()
				runUp(char, hum, root, f, shin) -- too tall to top out
			end
			return
		end
		-- something at head height with room underneath: slide under it
		if wall(head) and not waist then
			local under = head.Position + f * 0.6
			local bottom = cast(Vector3.new(under.X, feetY + 0.3, under.Z), UPV * 4.5)
			if bottom and bottom.Position.Y - feetY >= (PK.SlideGap or 2.4) then
				-- how far to the open air on the other side
				local dist = head.Distance + 1
				for step = 1, 8 do
					local p = head.Position + f * (step * 1.2)
					if not cast(Vector3.new(p.X, feetY + 0.3, p.Z), UPV * 4.5) then
						dist = head.Distance + step * 1.2 + 1.5
						break
					end
				end
				return slide(char, hum, root, f, dist, feetY) == true
			end
		end
	end

	-- the dash key while running at a gap you fit under: slide through it
	-- instead of dashing (true when it slid)
	function Parkour.TrySlide()
		local char, hum, root = getCharacter()
		if PK.Enabled == false or not char or not Parkour.Running or Parkour.Busy or hum.FloorMaterial == Enum.Material.Air
			or player:GetAttribute("NoParkour") then
			return false
		end
		refreshFilter()
		return obstacle(char, hum, root, true) == true
	end

	-- double-tap W to run (JJS); letting go of W stops it
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or input.KeyCode ~= Enum.KeyCode.W or PK.DoubleTapRun == false then
			return
		end
		local now = os.clock()
		if now - S.wTap < 0.3 then
			Parkour.Latched = true
		end
		S.wTap = now
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.W then
			Parkour.Latched = false
		end
	end)

	RunService:BindToRenderStep("QuirkParkourSense", Enum.RenderPriority.Input.Value + 2, function()
		if PK.Enabled == false or player:GetAttribute("NoParkour") or DevFly.active then -- (round 86: no wall hops mid-flight)
			return
		end
		local char, hum, root = getCharacter()
		if not char then
			return
		end
		local now = os.clock()
		refreshFilter()
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local held = jumpHeld(hum)
		local pressed = held and not S.jumpWas
		S.jumpWas = held
		if pressed then
			S.jumpAt = now
		end
		Parkour.WallNear = nil
		-- the fall you're in (for the roll) and your wall hops, reset on landing
		if grounded then
			if S.peakY and S.rollAt and now - S.rollAt < 0.45 and not Parkour.Busy then
				local fall = S.peakY - root.CFrame.Position.Y
				S.peakY, S.rollAt = nil, nil
				roll(char, hum, root, fall)
				return
			end
			S.peakY, S.rollAt = nil, nil
			if now - S.groundedAt > 0.1 then
				S.hops = 0
			end
		else
			S.groundedAt = now
			S.peakY = math.max(S.peakY or root.CFrame.Position.Y, root.CFrame.Position.Y)
		end
		if Parkour.Busy or dashing or blocking or busy(char) or (VFX.Zipping and VFX.Zipping(char)) or char:GetAttribute("Frozen") or char:GetAttribute("Finishing")
			or char:GetAttribute("BeingFinished") or char:GetAttribute("Kaiju") or hum.Sit or HawksFly.active then
			return -- (round 86 review: Hawks flying - Space climbs, it isn't a ledge grab or a wall hop)
		end
		if now - S.lastMove < (PK.Cooldown or 0.3) then
			return
		end
		if not grounded then
			-- the landing roll: jump pressed just before you land a big fall
			local fall = (S.peakY or root.CFrame.Position.Y) - root.CFrame.Position.Y
			if pressed and fall > (ROLL.MinFall or 10) - 3 and root.AssemblyLinearVelocity.Y < -25 then
				local below = cast(root.CFrame.Position, Vector3.new(0, -(3 + (ROLL.Window or 4.5)), 0))
				if below then
					S.rollAt = now
					S.rollFall = -root.AssemblyLinearVelocity.Y
					return
				end
			end
			-- (round 65) a ledge in reach in front: pull up onto it
			if (pressed or held) and ledge(char, hum, root) then
				return
			end
			-- wall hops: a jump PRESS beside a wall while moving (one press, one
			-- hop - holding it down doesn't keep hopping)
			local hit, side = sideWall(root)
			if hit and S.hops < hopsAllowed(hum) and flat(hum.MoveDirection).Magnitude > 0.3 then
				Parkour.WallNear = hit
				if pressed and now - S.lastHop > (HOP.RunTime or 0.3) + (HOP.Gap or 0.15) then
					wallHop(char, hum, root, hit, side)
					return
				end
			end
			-- a jump pressed just before reaching it still vaults / climbs
			if Parkour.Running and now - (S.jumpAt or -1) < 0.3 then
				obstacle(char, hum, root)
			end
			return
		end
		-- running at something: jump is what vaults / climbs / runs up it
		if Parkour.Running and (pressed or now - (S.jumpAt or -1) < 0.3) then
			obstacle(char, hum, root)
		end
	end)
end

---------------------------------------------------------------------------
-- Jumping and falling (Config.Movement.Feel), JJS-style: every jump is the
-- same height and you fall at normal gravity. Two helpers you never notice
-- so a press is never eaten - coyote time off an edge and a jump buffer
-- before landing - and falls top out at MaxFallSpeed.
---------------------------------------------------------------------------
do
	local FEEL = MOVE.Feel or {}
	local J = { groundedAt = 0, jumpWas = false, bufferedAt = -1, airborne = false, jumped = false }

	RunService:BindToRenderStep("QuirkJumpFeel", Enum.RenderPriority.Input.Value + 3, function()
		local char, hum, root = getCharacter()
		if not char then
			return
		end
		local now = os.clock()
		if J.hum ~= hum then
			-- a new body
			J.hum, J.jumped, J.airborne, J.groundedAt = hum, false, false, now
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					J.jumped = true
				end
			end)
		end
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local held = jumpHeld(hum)
		local pressed = held and not J.jumpWas
		J.jumpWas = held
		local v = root.AssemblyLinearVelocity
		-- (something else has the body: a vault, a dash, a stun, a ragdoll...)
		-- (round 83: ...or a grounded M1 chain - a jump there is the slam's:
		-- QuirkM1Jump keeps you down or hops you itself)
		local occupied = Parkour.Busy or dashing or hum.PlatformStand or root.Anchored
			or char:GetAttribute("Ragdolled") or char:GetAttribute("Stunned") or char:GetAttribute("Submerged")
			or char:GetAttribute("Frozen") or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished")
			or char:GetAttribute("Holding") or slamJump.suppressing
		if grounded then
			if J.airborne then
				J.airborne = false
				-- a jump pressed just before landing goes off now
				if now - J.bufferedAt <= (FEEL.JumpBuffer or 0.1) and not held and not occupied then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
				J.bufferedAt = -1
			end
			J.groundedAt = now
			J.jumped = false
			return
		end
		J.airborne = true
		if occupied then
			return
		end
		-- coyote time: you ran off an edge without jumping - a press still jumps
		if pressed and not J.jumped and now - J.groundedAt <= (FEEL.CoyoteTime or 0.1) and not Parkour.WallNear then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			return
		end
		-- a press on the way down: it goes off as you land (the jump buffer)
		if pressed and v.Y < 0 and not Parkour.WallNear then
			J.bufferedAt = now
		end
		local maxFall = FEEL.MaxFallSpeed or 150
		if v.Y < -maxFall then
			root.AssemblyLinearVelocity = Vector3.new(v.X, -maxFall, v.Z)
		end
	end)
end

---------------------------------------------------------------------------
-- Input bindings (+ automatic mobile buttons). The controller layout copies
-- Jujutsu Shenanigans: see Config.AbilityKeys and the notes above it.
---------------------------------------------------------------------------

-- a menu or the shop is open: a controller's buttons drive the menu instead
local function uiOpen()
	return HUD.ShopVisible() or HUD.MenuVisible() or HUD.VendorVisible() or HUD.SettingsVisible() or HUD.BoardVisible()
		or HUD.EmoteMenuVisible() or HUD.UnoVisible() or HUD.ConsoleVisible()
		or HUD.DiscordVisible() -- (round 89: the JOIN THE DISCORD card - a controller's cursor, B closes it)
end

local function closePanels()
	HUD.ToggleShop(false)
	HUD.ShowMenu(false)
	HUD.HideVendor()
	HUD.ToggleSettings(false)
	HUD.ToggleBoard(false)
	HUD.HideDiscord() -- (round 89)
	selectGui(nil)
end

-- the snack machine / shopkeeper prompt you're standing at. E and D-pad
-- right are taken by the finisher and your items, so they press it for you.
local shownPrompt = nil
ProximityPromptService.PromptShown:Connect(function(prompt)
	shownPrompt = prompt
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if shownPrompt == prompt then
		shownPrompt = nil
	end
end)
local function pressPrompt()
	local prompt = shownPrompt
	if not prompt or not prompt.Parent or not prompt.Enabled then
		return false
	end
	pcall(function()
		prompt:InputHoldBegin()
	end)
	task.delay(0.05, function()
		pcall(function()
			prompt:InputHoldEnd()
		end)
	end)
	return true
end

local function fromGamepad(input)
	local inputType = input and input.UserInputType
	return inputType ~= nil and inputType.Name:sub(1, 7) == "Gamepad"
end

-- touch = false: no mobile button for this one (the HUD draws the buttons)
local function bindButton(name, _title, keys, fn, touch, onRelease)
	if touch ~= false then
		Touch.handlers[name] = { down = fn, up = onRelease }
	end
	ContextActionService:BindAction(name, function(_, state, input)
		if uiOpen() and fromGamepad(input) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			fn()
		elseif onRelease and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) then
			onRelease()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(keys))
end

-- IIDA'S PRANK: in his ult, in the air, LB + RB together (1 + 4 on a
-- keyboard). Either one on its own still does its own move - a hair later
-- (PrankWindow), in case the other one's coming.
local Prank = { pending = nil }
function Prank.ready()
	local char, hum = getCharacter()
	return char ~= nil and hum ~= nil and ultMode and hum.FloorMaterial == Enum.Material.Air
		and Config.GetAbility(player:GetAttribute("Quirk"), Config.PRANK_INDEX, altMode, true) ~= nil
end
function Prank.press(side, normal)
	if not Prank.ready() then
		normal()
		return
	end
	local window = Config.PrankWindow or 0.18
	local p = Prank.pending
	if p and p.side ~= side and os.clock() - p.t < window then
		Prank.pending = nil
		useAbility(Config.PRANK_INDEX)
		return
	end
	local mine = { side = side, t = os.clock() }
	Prank.pending = mine
	task.delay(window, function()
		if Prank.pending == mine then
			Prank.pending = nil
			normal()
		end
	end)
end

for i, keys in Config.AbilityKeys do
	bindButton("QuirkAbility" .. i, tostring(i), keys, function()
		if i == 1 then
			Prank.press("L", function()
				useAbility(1)
			end)
		else
			useAbility(i)
		end
	end, nil, function()
		if Hold.active and Hold.active.index == i and not Hold.active.ability.Hold.Toggle then
			Hold.release() -- (letting go of a held move's key)
		end
	end)
end

bindButton("QuirkSpecial", "R", Config.SpecialKeys, function()
	local special = Config.GetAbility(player:GetAttribute("Quirk"), SPECIAL, altMode, ultMode)
	if special and not special.Form then
		useAbility(SPECIAL) -- e.g. Bakugo's Stun Grenade
	else
		useSpecial()
	end
end)
bindButton("QuirkUlt", "ULT", Config.UltKeys, useUlt)
bindButton("QuirkExtra", "4", Config.ExtraKeys or { Enum.KeyCode.Four }, function()
	Prank.press("R", function()
		useAbility(Config.EXTRA_INDEX)
	end)
end, nil, function()
	if Hold.active and Hold.active.index == Config.EXTRA_INDEX and not Hold.active.ability.Hold.Toggle then
		Hold.release()
	end
end)
-- (round 73) BAKUGO FLIES ON HIS EXPLOSIONS (Config.Quirks.Explosion.BlastFlight).
-- Hold the dash key (Q / Y / the phone's DASH): the dash goes off as usual,
-- and still held after HoldDelay he takes off - both palms thrown back, a
-- blast every Interval kicking him along wherever the camera's looking,
-- coasting and sagging a little between them. It runs on the nitro-sweat in
-- his palms (the SWEAT bar), which comes back once he's on the ground. Let
-- go, land, get hit, or throw an M1 or a move (its air version) and he drops
-- out of it. This machine flies him; the server passes the blasts on so
-- everyone else sees them.
do
	local BF = (Config.Quirks.Explosion and Config.Quirks.Explosion.BlastFlight) or {}
	local held, heldToken = false, 0
	local fuel, onGroundAt, cdUntil, lastChar = BF.Fuel or 3.5, nil, 0, nil
	local lv, att, conn
	local speed, dir, sinceBlast, flewAt = 0, Vector3.new(0, 0, -1), 0, 0
	local shown, shownFlying = false, false
	-- (in the ult, Dynamight's numbers)
	local function num(key)
		local u = player:GetAttribute("UltActive") == true and BF.Ult or nil
		return (u and u[key]) or BF[key]
	end
	local function isBakugo()
		return player:GetAttribute("Quirk") == "Explosion"
	end
	local function blocked(char, hum, root)
		return not (char and hum and root) or hum.Health <= 0 or not isBakugo()
			or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed")
			or char:GetAttribute("Frozen") or char:GetAttribute("Holding") or char:GetAttribute("Finishing")
			or char:GetAttribute("BeingFinished") or char:GetAttribute("Submerged") or char:GetAttribute("Kaiju")
			or char:GetAttribute("Clashing") or root.Anchored or root:FindFirstChild("Knockback") ~= nil
			or Hold.active ~= nil or Parkour.Busy or VFX.InOwnCinematic() or FreeCam.on
			or player:GetAttribute("NoSkills") or player:GetAttribute("Flight") == true or DevFly.active -- (round 86)
	end
	local function aim()
		local cam = workspace.CurrentCamera
		local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	end
	local function blast(char, hum, first)
		sinceBlast = 0
		local a = aim()
		-- off the street he always goes up and out, never into it
		local up = BF.TakeOffUp or 0.45
		if hum.FloorMaterial ~= Enum.Material.Air and a.Y < up then
			local f = flat(a)
			a = ((f.Magnitude > 0.05 and f.Unit or flat(char.HumanoidRootPart.CFrame.LookVector).Unit) * math.sqrt(1 - up * up) + Vector3.new(0, up, 0)).Unit
		end
		dir = a
		speed = num("BlastSpeed") or 82
		UseAbility:FireServer(Config.PARKOUR_INDEX, first and "BlastFly" or "BlastPulse", a)
		VFX.Play("BlastFly", char, { Kind = first and "Start" or "Pulse", Dir = a }, true)
	end
	function BlastFly.stop(reason)
		if not BlastFly.active then
			return
		end
		BlastFly.active = false
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if lv then
			lv:Destroy()
			lv = nil
		end
		if att then
			att:Destroy()
			att = nil
		end
		local char, hum, root = getCharacter()
		if hum and hum.Parent then
			hum.AutoRotate = true
		end
		if root and root.Parent and reason ~= "Hit" and reason ~= "Landed" then
			root.AssemblyLinearVelocity = dir * speed * (BF.Carry or 0.55) -- (he keeps some of it)
		end
		cdUntil = os.clock() + (BF.Cooldown or 1.5)
		BlastFly.reason = reason
		UseAbility:FireServer(Config.PARKOUR_INDEX, "BlastFlyEnd")
		if char then
			VFX.Play("BlastFly", char, { Kind = "End" }, true)
		end
	end
	function BlastFly.start()
		if BlastFly.active or os.clock() < cdUntil then
			return false
		end
		local char, hum, root = getCharacter()
		if blocked(char, hum, root) or fuel < (BF.MinFuel or 0.6) then
			return false
		end
		if activeDashCleanup then
			activeDashCleanup("Interrupted") -- (the dash blasts straight into the flight)
		end
		BlastFly.active = true
		BlastFly.reason = nil
		flewAt = os.clock()
		att = Instance.new("Attachment")
		att.Name = "BlastFlightAttachment"
		att.Parent = root
		lv = Instance.new("LinearVelocity")
		lv.Name = "BlastFlight"
		lv.Attachment0 = att
		-- strong but finite (an unlimited push into someone flings you both)
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 6000
		lv.ForceLimitsEnabled = true
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = root.AssemblyLinearVelocity
		lv.Parent = root
		hum.AutoRotate = false
		blast(char, hum, true)
		conn = RunService.Heartbeat:Connect(function(dt)
			local c, h, r = getCharacter()
			if c ~= char or not held or blocked(c, h, r) or not lv or not lv.Parent then
				BlastFly.stop((r and r:FindFirstChild("Knockback")) and "Hit" or (held and "Interrupted" or "Released"))
				return
			end
			fuel -= dt
			if fuel <= 0 then
				fuel = 0
				BlastFly.stop("Empty")
				return
			end
			sinceBlast += dt
			local every = BF.Interval or 0.32
			if sinceBlast >= every then
				blast(char, h, false)
			end
			-- turning toward the aim between blasts, coasting, sagging
			local a = aim()
			dir = dir + (a - dir) * math.min(1, (BF.Turn or 5) * dt)
			dir = dir.Magnitude > 0.01 and dir.Unit or a
			local cruise = num("Cruise") or 44
			speed = cruise + (speed - cruise) * math.exp(-(BF.Drag or 3) * dt)
			local sag = (BF.Sag or 14) * math.min(1, sinceBlast / every)
			lv.VectorVelocity = dir * speed - Vector3.new(0, sag, 0)
			local f = flat(dir)
			if f.Magnitude > 0.05 then
				r.CFrame = CFrame.lookAt(r.Position, r.Position + f.Unit)
			end
			-- touched down (a moment after taking off, not climbing): out of it
			if os.clock() - flewAt > 0.35 and h.FloorMaterial ~= Enum.Material.Air and dir.Y < 0.25 then
				BlastFly.stop("Landed")
			end
		end)
		return true
	end
	function BlastFly.press()
		held = true
		heldToken += 1
		local token = heldToken
		task.delay(BF.HoldDelay or 0.22, function()
			if held and heldToken == token then
				BlastFly.start()
			end
		end)
	end
	function BlastFly.release()
		held = false
		if BlastFly.active then
			BlastFly.stop("Released")
		end
	end
	function BlastFly.fuel()
		return fuel
	end
	function BlastFly.setFuel(v)
		fuel = v
	end
	-- the sweat: full on a new body, back on the ground; the bar (Bakugo only)
	RunService.Heartbeat:Connect(function(dt)
		local char, hum = getCharacter()
		local mx = num("Fuel") or 3.5
		if char ~= lastChar then
			lastChar = char
			fuel = mx
		end
		if not isBakugo() or not hum then
			if shown ~= nil then
				shown = nil
				HUD.SetSweat(nil)
				if VFX.CosA then
					VFX.CosA.mySweat(nil) -- (round 88)
				end
			end
			return
		end
		fuel = math.min(fuel, mx)
		if not BlastFly.active then
			if hum.FloorMaterial ~= Enum.Material.Air then
				onGroundAt = onGroundAt or os.clock()
				if os.clock() - onGroundAt >= (BF.RegenDelay or 0.6) then
					fuel = math.min(mx, fuel + (BF.Regen or 1.2) * dt)
				end
			else
				onGroundAt = nil
			end
		else
			onGroundAt = nil
		end
		local pct = math.floor(fuel / mx * 100 + 0.5)
		if pct ~= shown or BlastFly.active ~= shownFlying then
			shown, shownFlying = pct, BlastFly.active
			HUD.SetSweat(pct, BlastFly.active)
		end
		-- (round 88) ...and the gauges on his gauntlets show it, exactly
		if VFX.CosA and (not VFX.CosA.mine or VFX.CosA.mine.char ~= char or VFX.CosA.mine.pct ~= pct) then
			VFX.CosA.mySweat(char, pct)
		end
	end)
end
bindButton("QuirkDash", "DASH", Config.DashKeys, function()
	-- (round 86: dev flight - the mach burst. Knocked down or in a combo's
	-- hitstun it's still the ragdoll cancel, below - the review's catch)
	local dc = DevFly.active and player.Character
	if DevFly.active and not (dc and (dc:GetAttribute("Ragdolled") or dc:GetAttribute("ComboStun"))) then
		DevFly.boost()
		return
	end
	if FloatFly.active then
		FloatFly.boost() -- (round 75: floating - an Air Force flick behind him)
		return
	end
	if HawksFly.active and HawksFly.boost then
		HawksFly.boost() -- (round 86: Hawks flying - a tuck dive down the aim)
		return
	end
	dash()
	BlastFly.press()
end, nil, function()
	if DevFly.Light then
		DevFly.Light.dashUp() -- (round 90: the burst key let go - the light barrier's charge stops)
	end
	BlastFly.release()
end)

---------------------------------------------------------------------------
-- Finishers: someone at their last sliver of health just in front of you
-- gets a FINISH prompt over their head; E (RB / the FINISH button) does it
---------------------------------------------------------------------------
local FINISH = Config.Finishers or {}
local finishTarget = nil
local finishPrompt = Instance.new("BillboardGui")
finishPrompt.Name = "FinishPrompt"
finishPrompt.Size = UDim2.fromOffset(160, 44)
finishPrompt.StudsOffset = Vector3.new(0, 3.4, 0)
finishPrompt.AlwaysOnTop = true
finishPrompt.Enabled = false
local finishLabel = Instance.new("TextLabel")
finishLabel.Size = UDim2.fromScale(1, 1)
finishLabel.BackgroundColor3 = Color3.fromRGB(24, 8, 10)
finishLabel.BackgroundTransparency = 0.2
finishLabel.TextColor3 = Color3.fromRGB(255, 96, 76)
finishLabel.Font = Enum.Font.GothamBlack
finishLabel.TextScaled = true
finishLabel.Text = "[E] FINISH"
finishLabel.Parent = finishPrompt
local finishCorner = Instance.new("UICorner")
finishCorner.CornerRadius = UDim.new(0, 8)
finishCorner.Parent = finishLabel
local finishStroke = Instance.new("UIStroke")
finishStroke.Color = Color3.fromRGB(255, 200, 90)
finishStroke.Thickness = 2
finishStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
finishStroke.Parent = finishLabel
local finishScale = Instance.new("UIScale")
finishScale.Parent = finishLabel
finishPrompt.Parent = player:WaitForChild("PlayerGui")

-- everyone you could fight: other players and the dummies
local function fightTargets()
	local list = {}
	for _, plr in Players:GetPlayers() do
		if plr ~= player and plr.Character then
			table.insert(list, plr.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	for _, model in dummies and dummies:GetChildren() or {} do
		table.insert(list, model)
	end
	return list
end

-- the one closest to where you're aiming (the mouse, or the dot in the middle
-- of the screen with a controller / shift lock), within reach
local function findFinishTarget(char, root)
	if not FINISH.Enabled or busy(char) or char:GetAttribute("Finishing") or char:GetAttribute("Frozen") then
		return nil
	end
	local look = flat((getAim(root)))
	if look.Magnitude < 0.1 then
		look = flat(root.CFrame.LookVector)
	end
	local best, bestScore = nil, -math.huge
	for _, model in fightTargets() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local r = model:FindFirstChild("HumanoidRootPart")
		if hum and r and hum.Health > 0 and hum.Health <= hum.MaxHealth * (FINISH.Threshold or 0.15)
			and not model:GetAttribute("BeingFinished") then
			local offset = r.Position - root.Position
			local ahead = flat(offset)
			local facing = (ahead.Magnitude < 1.5 or look.Magnitude < 0.1) and 1 or ahead.Unit:Dot(look.Unit)
			if offset.Magnitude <= (FINISH.Range or 10) and facing > 0.1 then
				-- nearest the crosshair first, then nearest to you
				local score = facing - offset.Magnitude * 0.01
				if score > bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

local lastFinishScan = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if finishPrompt.Enabled then
		finishScale.Scale = 1 + 0.07 * math.sin(now * 9)
	end
	if now - lastFinishScan < 0.1 then
		return
	end
	lastFinishScan = now
	local char, _, root = getCharacter()
	finishTarget = char and findFinishTarget(char, root) or nil
	local anchorPart = finishTarget and (finishTarget:FindFirstChild("Head") or finishTarget:FindFirstChild("HumanoidRootPart"))
	finishPrompt.Enabled = anchorPart ~= nil
	HUD.SetTouchFinish(anchorPart ~= nil)
	if anchorPart then
		finishPrompt.Adornee = anchorPart
		finishLabel.Text = inputMode == "Gamepad" and "[RB] FINISH" or inputMode == "Touch" and "FINISH!" or "[E] FINISH"
	end
end)

local function tryFinish()
	local char = getCharacter()
	if not finishTarget and pressPrompt() then
		return -- (E buys a snack / talks to Tony when nobody's there to finish)
	end
	if not char or not finishTarget or busy(char) then
		return
	end
	-- the blow sends them where you're aiming
	local root = char:FindFirstChild("HumanoidRootPart")
	local aimDir = root and (getAim(root)) or nil
	UseAbility:FireServer(Config.FINISH_INDEX, finishTarget, aimDir)
	finishTarget = nil
	finishPrompt.Enabled = false
	HUD.SetTouchFinish(false)
end
bindButton("QuirkFinish", "FINISH", Config.FinisherKeys or { Enum.KeyCode.E }, tryFinish)

-- EMOTES (B): the wheel. Tap B and click one - or hold B, point at one and
-- let go. Your own screen plays it straight away; the server passes it on.
do
	local openedAt = 0
	-- (round 58) the wheel holds the ones you've put on it - bought in the
	-- shop, the only way to get them; an empty slot takes you to the shop
	local function pick(id)
		if HUD.EmoteMenuClosed then
			HUD.EmoteMenuClosed() -- (picked off the controller menu: it closes)
		end
		if not id then
			HUD.OpenEmoteShop()
			if inputMode == "Gamepad" then
				selectGui(HUD.FirstButton("Shop"))
			end
			return
		end
		local char = getCharacter()
		if not char or busy(char) or dashing or actionRemaining(char) > 0 or char:GetAttribute("Holding") then
			return
		end
		UseAbility:FireServer(Config.EMOTE_INDEX, id)
		VFX.Play("Emote", char, { Id = id }, true)
	end
	local byId = {}
	for _, e in Config.Emotes or {} do
		byId[e.Id] = e
	end
	local function rebuild()
		local list, owned, wheel, n, order = {}, {}, {}, 0, {}
		for id in string.gmatch(player:GetAttribute("EmotesOwned") or "", "[^,]+") do
			owned[id] = byId[id] ~= nil or nil
			if byId[id] then
				table.insert(order, id) -- (as they were got: the shop lists the newest first)
			end
		end
		for id in string.gmatch((player:GetAttribute("EmoteWheel") or "") .. ",", "([^,]*),") do
			n += 1
			if n > (Config.EmoteSlots or 4) then
				break
			end
			wheel[n] = (byId[id] and owned[id]) and id or ""
		end
		for k = 1, Config.EmoteSlots or 4 do
			wheel[k] = wheel[k] or ""
			list[k] = byId[wheel[k]] or { Empty = true, Slot = k }
		end
		HUD.BuildEmoteWheel(list, pick)
		-- (a controller gets the menu: cards to move between, A plays, B closes)
		HUD.BuildEmoteMenu(list)
		HUD.SetEmotes(owned, wheel, order)
	end
	rebuild()
	player:GetAttributeChangedSignal("EmotesOwned"):Connect(rebuild)
	-- (round 63) a 10x roll's free pick, waiting ("PICK LATER")
	local function picks()
		HUD.SetEmotePicks(player:GetAttribute("EmotePicks") or 0)
	end
	picks()
	player:GetAttributeChangedSignal("EmotePicks"):Connect(picks)
	player:GetAttributeChangedSignal("EmoteWheel"):Connect(rebuild)
	local function closeMenu()
		HUD.ShowEmoteMenu(false)
		selectGui(nil)
		ContextActionService:UnbindAction("QuirkEmoteMenuBack")
	end
	local function openMenu()
		HUD.ShowEmoteMenu(true)
		selectGui(HUD.EmoteMenuFirst())
		-- B (or the emote button again) backs out; a pick closes it too
		ContextActionService:BindActionAtPriority("QuirkEmoteMenuBack", function(_, state)
			if state == Enum.UserInputState.Begin then
				closeMenu()
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.ButtonB, table.unpack(Config.EmoteKeys or { Enum.KeyCode.ButtonR3 }))
	end
	HUD.EmoteMenuClosed = closeMenu
	-- (round 58) the top bar: its EMOTES button does what B does; the
	-- CHARACTER button's phone puts a controller on its first hero
	HUD.SetTopBarCallbacks({
		OnEmotes = function()
			if HUD.EmoteMenuVisible() then
				closeMenu()
			elseif inputMode == "Gamepad" then
				openMenu()
			else
				HUD.ShowEmoteWheel(not HUD.EmoteWheelVisible())
			end
		end,
		OnCharacter = function(open)
			if inputMode == "Gamepad" then
				selectGui(open and HUD.FirstButton("Menu") or nil)
			end
		end,
	})
	bindButton("QuirkEmote", "EMOTE", Config.EmoteKeys or { Enum.KeyCode.B }, function()
		if HUD.EmoteMenuVisible() then
			closeMenu()
			return
		end
		if inputMode == "Gamepad" and not HUD.EmoteWheelVisible() then
			openMenu()
			return
		end
		if HUD.EmoteWheelVisible() then
			-- (a controller: click the stick again to play the one it points at)
			if HUD.UsingGamepad() and HUD.EmoteHover() then
				HUD.PickEmote()
				return
			end
			HUD.ShowEmoteWheel(false)
		else
			openedAt = os.clock()
			HUD.ShowEmoteWheel(true)
		end
	end, nil, function()
		-- (held, pointed, let go: that one)
		if HUD.EmoteWheelVisible() and os.clock() - openedAt > 0.3 and HUD.EmoteHover() then
			HUD.PickEmote()
		end
	end)
end
-- RB: finish whoever is ready for it, otherwise the form's bonus move
bindButton("QuirkContext", "RB", Config.ContextKeys or {}, function()
	Prank.press("R", function()
		if finishTarget then
			tryFinish()
		else
			useAbility(Config.EXTRA_INDEX)
		end
	end)
end, false)

-- Punch: tap or HOLD (mouse, B or the mobile HIT button) to keep the combo going.
-- With a menu open, B closes it instead.
m1Held = false
ContextActionService:BindAction("QuirkPunch", function(_, state, input)
	if uiOpen() and fromGamepad(input) then
		if state == Enum.UserInputState.Begin then
			closePanels()
		end
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		m1Held = true
		useM1()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		m1Held = false
	end
	return Enum.ContextActionResult.Sink
end, false, table.unpack(Config.M1Keys or { Enum.KeyCode.ButtonB }))
Touch.handlers.QuirkPunch = {
	down = function()
		m1Held = true
		useM1()
	end,
	up = function()
		m1Held = false
	end,
}
RunService.Heartbeat:Connect(function()
	if guardHeld then
		startBlock() -- a held guard raises on the first available recovery frame
	end
	local pending = CombatInput.pending
	if pending then
		local char = getCharacter()
		if char ~= pending.char or busy(char) or os.clock() > pending.expires then
			CombatInput.pending = nil
		elseif not dashing and actionRemaining(char) <= 0 and workspace:GetServerTimeNow() >= pending.readyAt then
			CombatInput.pending = nil
			pending.run()
		end
	end
	if m1Held and not scoped and not CombatInput.pending then
		useM1(false) -- held input retries without replacing a deliberate queued skill
	end
end)

-- Sprint: hold on keyboard, toggle with the mobile RUN button (a controller
-- sprints by pushing the stick all the way)
ContextActionService:BindAction("QuirkSprint", function(_, state, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Enum.UserInputState.Begin then
			sprintToggle = not sprintToggle
		end
	else
		sprintHeld = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	end
	return Enum.ContextActionResult.Pass
end, false, table.unpack(Config.SprintKeys))
Touch.handlers.QuirkSprint = {
	down = function()
		sprintToggle = not sprintToggle
		HUD.SetTouchRun(sprintToggle)
	end,
}

-- Guard: hold F / X, or hold the mobile BLOCK button
ContextActionService:BindAction("QuirkBlock", function(_, state, input)
	if uiOpen() and fromGamepad(input) then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		guardHeld = true
		CombatInput.pending = nil
		startBlock()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		guardHeld = false
		stopBlock()
	end
	return Enum.ContextActionResult.Sink
end, false, table.unpack(Config.BlockKeys or { Enum.KeyCode.F }))
Touch.handlers.QuirkBlock = {
	down = function()
		guardHeld = true
		CombatInput.pending = nil
		startBlock()
	end,
	up = function()
		guardHeld = false
		stopBlock()
	end,
}

---------------------------------------------------------------------------
-- (round 92) tweaks - LOCK-ON, GONE (the owner: "remove lock-on"). Nothing
-- locks the camera onto anyone any more: no key, no phone button, no marker,
-- no camera or body turned to a target; moves aim where you aim (the mouse,
-- the middle of the screen; AimAssist and the M1's nudge as ever). The keys
-- it had (T / L3) and the phone's LOCK are the DEV FLIGHT's HOVER-LOCK now,
-- and only while he flies: Config.DevFlight.LockKeys in the flight's own
-- sink (QuirkDevFlySink), the phone's LOCK shown only with the flight's
-- meter (HUD.SetTouchHoverLock) - see the round-90 DEVFLY2 block.
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- (round 65) LOOKING AROUND ON A CONTROLLER, JJS-style (Config.Look.Pad):
-- the right stick turns the camera the moment it's pushed, in proportion to
-- how far (Roblox's own camera eases a small push in on a curve, so the
-- start of every look lagged), at the same speed at any frame rate. It turns
-- the camera just before Roblox's camera runs, which carries on from where
-- it points. (The first time the stick goes well over, it checks that
-- Roblox's camera really stepped aside - if it didn't, this stays out of it.)
---------------------------------------------------------------------------
do
	local PAD = (Config.Look or {}).Pad or {}
	-- mode: nil (not checked yet), "ours" or "roblox"; sinking: the stick is
	-- ours right now (Roblox's camera saw it centred last)
	local LK = { mode = nil, probe = nil, sinking = false }
	local UGS = nil
	pcall(function()
		UGS = UserSettings():GetService("UserGameSettings")
	end)
	local function stick2()
		local ok, state = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
		if ok and type(state) == "table" then
			for _, input in state do
				if input.KeyCode == Enum.KeyCode.Thumbstick2 then
					return Vector2.new(input.Position.X, input.Position.Y)
				end
			end
		end
		return Vector2.zero
	end
	local function yawOf(look)
		return math.atan2(-look.X, -look.Z)
	end
	-- (it only steers the everyday camera: not a cutscene, the free cam, a
	-- menu or the emote wheel the stick is driving, or a scope)
	local function ours()
		local cam = workspace.CurrentCamera
		return PAD.Enabled ~= false and LK.mode ~= "roblox" and inputMode == "Gamepad" and cam ~= nil
			and player:GetAttribute("RobloxCamera") ~= true -- (round 68: the settings' ROBLOX CAMERA)
			and cam.CameraType == Enum.CameraType.Custom and not VFX.InCinematic() and not FreeCam.on
			and not scoped and not uiOpen() and not HUD.EmoteWheelVisible()
	end
	Parkour.PadLook = LK -- (for the tests)
	ContextActionService:BindActionAtPriority("QuirkPadLook", function(_, state, input)
		-- (round 68) the stick as the input reports it - whichever gamepad
		-- it's on (reading only Gamepad1 froze the camera for a pad that
		-- came up as Gamepad2)
		if input then
			local p = input.Position
			LK.stick = (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) and Vector2.zero or Vector2.new(p.X, p.Y)
		end
		if not ours() then
			LK.sinking = false
			return Enum.ContextActionResult.Pass
		end
		if not LK.sinking then
			-- (it takes the stick over only from a centred stick: Roblox's
			-- camera has to see it let go, or it keeps turning on the last push)
			local p = input and input.Position or Vector3.zero
			if math.abs(p.X) < 0.1 and math.abs(p.Y) < 0.1 then
				LK.sinking = true
			end
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end, false, PAD.Priority or 2500, Enum.KeyCode.Thumbstick2)
	RunService:BindToRenderStep("QuirkPadLook", Enum.RenderPriority.Camera.Value - 1, function(dt)
		dt = math.min(tonumber(dt) or 1 / 60, 0.1)
		local cam = workspace.CurrentCamera
		if not cam or not LK.sinking or not ours() then
			LK.probe = nil
			return
		end
		-- (round 68) Gamepad1's stick - or, a pad that came up as another
		-- gamepad (Gamepad1 reads centred), the stick as its input reported it
		local s = stick2()
		if s.Magnitude < 0.05 and LK.stick then
			s = LK.stick
		end
		local dz = PAD.Deadzone or 0.12
		local m = s.Magnitude
		local look = cam.CFrame.LookVector
		if LK.mode == nil then
			-- the check: stick well over to one side - hold the camera still
			-- a few frames and see whether Roblox's camera turns it anyway
			if math.abs(s.X) < 0.5 then
				LK.probe = nil
				return
			end
			local yaw = yawOf(look)
			local p = LK.probe
			if not p or p.sign ~= math.sign(s.X) then
				LK.probe = { sign = math.sign(s.X), last = yaw, turned = 0, frames = 0 }
				return
			end
			local d = (yaw - p.last + math.pi) % (2 * math.pi) - math.pi
			p.last = yaw
			-- (a push right turns the view clockwise: the yaw goes down)
			p.turned += -d * p.sign
			p.frames += 1
			if p.frames >= 4 then
				LK.mode = p.turned > math.rad(1.5) and "roblox" or "ours"
				LK.probe = nil
			end
			return
		end
		if m <= dz then
			return
		end
		local k = math.clamp((m - dz) / (1 - dz), 0, 1) ^ (PAD.Curve or 1.25)
		local dir = s / m
		local invert = 1
		if UGS then
			pcall(function()
				invert = UGS:GetCameraYInvertValue()
			end)
		end
		-- (round 68) x CONTROLLER SENSITIVITY (the settings)
		local sens = math.clamp(tonumber(player:GetAttribute("PadSensitivity")) or 1, 0.25, 4)
		local yaw = yawOf(look) - dir.X * k * math.rad(PAD.Speed or 250) * sens * dt
		local pitch = math.asin(math.clamp(look.Y, -1, 1)) + dir.Y * invert * k * math.rad(PAD.PitchSpeed or 190) * sens * dt
		pitch = math.clamp(pitch, -math.rad(80), math.rad(80))
		cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	end)
end

---------------------------------------------------------------------------
-- (round 82) A DRAG THAT STARTS ON A PHONE BUTTON TURNS THE CAMERA
-- (Config.Look.Touch). The buttons keep the finger (a tap or a hold mustn't
-- nudge the view), so Roblox's camera never sees a drag that starts on one:
-- the HUD measures it (HUD.TakeTouchLook) and it's handed to Roblox's own
-- camera as if Roblox had seen it - added to what its CameraInput.getRotation
-- returns, at the same speed and sign as its own touch pan. That keeps its
-- pitch limits, and the Follow camera (a phone's default) counts it as you
-- turning the camera, so it doesn't swing back behind you. A drag that
-- starts on open screen is Roblox's already (it never fires a button now),
-- so it isn't fed twice. Nothing turns during a cutscene, the free cam, a
-- scope, a menu or the emote wheel.
-- If that PlayerModule isn't there (the test harness, or a future Roblox
-- one without it), the camera's turned just before Roblox's runs, the way
-- QuirkPadLook does it - though Roblox's Follow camera can swing a fast turn
-- back then. The player's camera mode is never changed.
---------------------------------------------------------------------------
do
	local TL = (Config.Look or {}).Touch or {}
	local TouchLook = { wrapped = false }
	Parkour.TouchLook = TouchLook -- (for the tests)
	local UGS = nil
	pcall(function()
		UGS = UserSettings():GetService("UserGameSettings")
	end)
	-- (only the everyday camera, and only on a phone)
	function TouchLook.ok()
		local cam = workspace.CurrentCamera
		return TL.Enabled ~= false and inputMode == "Touch" and cam ~= nil and cam.CameraType == Enum.CameraType.Custom
			and not VFX.InCinematic() and not FreeCam.on and not scoped
			and not uiOpen() and not HUD.EmoteWheelVisible()
	end
	-- a drag (GUI pixels) as camera turn (radians), the way Roblox's
	-- CameraInput turns a touch pan: Speed per pixel, the pitch eased off
	-- toward straight up or down (its adjustTouchPitchSensitivity, 25% at
	-- the pole), then the player's Y invert
	function TouchLook.rotation(d)
		local cam = workspace.CurrentCamera
		local pitch = cam and math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)) or 0
		local dy = d.Y
		if dy * pitch < 0 then
			local curve = 1 - (2 * math.abs(pitch) / math.pi) ^ 0.75
			dy *= curve * 0.75 + 0.25
		end
		local invert = 1
		if UGS then
			pcall(function()
				invert = UGS:GetCameraYInvertValue()
			end)
		end
		local speed = TL.Speed or {}
		return Vector2.new(d.X * math.rad(speed.Yaw or 1), dy * math.rad(speed.Pitch or 0.66) * invert)
	end
	-- this frame's drag as a turn (zero when it isn't ours to turn); the
	-- HUD's drag is taken either way, so nothing saves up
	function TouchLook.take()
		local d = HUD.TakeTouchLook()
		if d.Magnitude < 1e-4 or not TouchLook.ok() then
			return Vector2.zero
		end
		return TouchLook.rotation(d)
	end
	-- Roblox's own camera takes it (CameraInput is shared: ClassicCamera
	-- calls CameraInput.getRotation through the module's table every frame)
	task.spawn(function()
		local ok, CI = pcall(function()
			local ps = player:WaitForChild("PlayerScripts", 20)
			local pm = ps and ps:WaitForChild("PlayerModule", 20)
			local cm = pm and pm:WaitForChild("CameraModule", 20)
			local ci = cm and cm:WaitForChild("CameraInput", 20)
			return ci and require(ci)
		end)
		if not (ok and type(CI) == "table" and type(CI.getRotation) == "function") then
			return -- (not there: the turn below does it)
		end
		local base = CI.getRotation
		local hooked = pcall(function()
			CI.getRotation = function(...)
				local r = base(...)
				local fine, add = pcall(TouchLook.take)
				if fine and typeof(r) == "Vector2" and typeof(add) == "Vector2" and add.Magnitude > 0 then
					return r + add
				end
				return r
			end
		end)
		TouchLook.wrapped = hooked and CI.getRotation ~= base
	end)
	-- (the fallback) turn the camera just before Roblox's camera runs
	RunService:BindToRenderStep("QuirkTouchLook", Enum.RenderPriority.Camera.Value - 1, function()
		if TouchLook.wrapped then
			return -- (Roblox's camera takes it itself)
		end
		local rot = TouchLook.take()
		local cam = workspace.CurrentCamera
		if rot.Magnitude <= 0 or not cam then
			return
		end
		local look = cam.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z) - rot.X
		local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)) - rot.Y, -math.rad(80), math.rad(80))
		cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	end)
	-- (a new body: nothing held over from the last one)
	player.CharacterAdded:Connect(function()
		HUD.TouchRelease()
	end)
end

---------------------------------------------------------------------------
-- Items (5/6/7/8, the item bar, D-pad right) and the shop (H / SELECT)
---------------------------------------------------------------------------
local heldItems = {} -- { { Id, Count } } in bag order
local selectedItem = 1 -- the controller's pick

local function refreshItems()
	local list = {}
	for _, id in Config.ItemOrder do
		local count = player:GetAttribute("Item_" .. id) or 0
		if count > 0 then
			table.insert(list, { Id = id, Count = count })
		end
	end
	heldItems = list
	selectedItem = math.clamp(selectedItem, 1, math.max(#list, 1))
	HUD.SetItems(list, selectedItem)
end

local function useItem(id)
	local char, _, root = getCharacter()
	if not char or not id or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or VFX.InOwnCinematic()
		or char:GetAttribute("Parked") then -- (round 87: he's in another body)
		return
	end
	if (player:GetAttribute("Item_" .. id) or 0) <= 0 then
		return
	end
	stopBlock()
	local dir, pos = getAim(root)
	ShopRemote:FireServer("Use", id, dir, pos)
end

local function toggleShop()
	HUD.ToggleShop()
end

HUD.BuildShop({
	OnBuy = function(id)
		ShopRemote:FireServer("Buy", id)
	end,
	-- (round 63) JJS-style: roll n random emotes; a free pick; a drone
	-- delivery ("Soda" / "Item"); a code; the shopkeeper's squeak
	OnRollEmotes = function(n)
		ShopRemote:FireServer("RollEmotes", n)
	end,
	-- (round 72) the same roll for Robux: Roblox's own purchase prompt (the
	-- server hands the emotes over when Roblox says it's paid for)
	OnRobuxRoll = function(n)
		local spec = ((Config.EmoteShop or {}).Robux or {})[n]
		local id = type(spec) == "table" and tonumber(spec.Product)
		if not id or id <= 0 then
			return
		end
		local owned = {}
		for eid in string.gmatch(player:GetAttribute("EmotesOwned") or "", "[^,]+") do
			owned[eid] = true
		end
		local left = 0
		for _, e in Config.Emotes or {} do
			if not e.Exclusive and not owned[e.Id] then
				left += 1
			end
		end
		if left == 0 then
			HUD.ShopResult(false, "Roll", "You have all the emotes already!!!")
			return
		end
		pcall(function()
			game:GetService("MarketplaceService"):PromptProductPurchase(player, id)
		end)
	end,
	OnPickEmote = function(id)
		ShopRemote:FireServer("PickEmote", id)
	end,
	OnDelivery = function(kind)
		ShopRemote:FireServer("Deliver", kind)
	end,
	OnRedeem = function(code)
		ShopRemote:FireServer("Redeem", code)
	end,
	OnSound = function(name)
		VFX.PlaySound(name)
	end,
	OnEquipEmote = function(slot, id)
		ShopRemote:FireServer("EquipEmote", slot, id)
	end,
	OnUse = useItem,
	OnToggle = function(open)
		if inputMode == "Gamepad" then
			selectGui(open and HUD.FirstButton("Shop") or nil)
		end
	end,
	OnQuirks = function()
		if inputMode == "Gamepad" then
			selectGui(HUD.FirstButton("Menu"))
		end
	end,
})

ContextActionService:BindAction("QuirkShop", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggleShop()
	end
	return Enum.ContextActionResult.Sink
end, false, table.unpack(Config.ShopKeys or { Enum.KeyCode.H }))

-- (round 58) One For All's inner world: its dark, and who's who, on your screen
if VFX.VR then
	VFX.VR.watch()
end
-- (round 72) what each Robux emote roll really costs, from Roblox
task.spawn(function()
	local prices = {}
	for n, spec in (Config.EmoteShop or {}).Robux or {} do
		local id = type(spec) == "table" and tonumber(spec.Product)
		if id and id > 0 then
			local ok, info = pcall(function()
				return game:GetService("MarketplaceService"):GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
				prices[n] = tonumber(info.PriceInRobux)
			end
		end
	end
	HUD.SetRobuxPrices(prices)
end)
-- (round 71) Deku's memories in there: their warm, remembered look
if VFX.MEM then
	VFX.MEM.watch()
end

-- (round 59) SUNEATER'S WINGS (Config.Quirks.Manifest.Glide): falling for
-- more than After seconds, chicken wings grow out of his back and he glides
-- - his fall held to FallSpeed - until he lands. This machine flies him;
-- everyone else sees the wings (the parkour relay: Glide / GlideEnd).
do
	local G = Config.Quirks.Manifest and Config.Quirks.Manifest.Glide
	local fallingSince, gliding = nil, false
	RunService.Heartbeat:Connect(function()
		local char, hum, root = getCharacter()
		local function stop()
			fallingSince = nil
			if gliding then
				gliding = false
				UseAbility:FireServer(Config.PARKOUR_INDEX, "GlideEnd")
				if char then
					VFX.Play("Parkour", char, { Kind = "GlideEnd" }, true)
				end
			end
		end
		if not (G and char and hum and root) or player:GetAttribute("Quirk") ~= "Manifest" then
			stop()
			return
		end
		local st = hum:GetState()
		local inAir = hum.FloorMaterial == Enum.Material.Air and st ~= Enum.HumanoidStateType.Climbing and st ~= Enum.HumanoidStateType.Swimming
			and st ~= Enum.HumanoidStateType.Seated and st ~= Enum.HumanoidStateType.PlatformStanding and st ~= Enum.HumanoidStateType.Dead
		-- (not while he's down, held, mid-move, dashing, on a ledge or a tentacle)
		local tied = char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") or char:GetAttribute("Stunned") or root.Anchored
			or dashing or Parkour.Busy or (VFX.Swinging and VFX.Swinging(char))
			or (char:GetAttribute("CombatActionUntil") or 0) > workspace:GetServerTimeNow()
		if not inAir or tied then
			stop()
			return
		end
		local v = root.AssemblyLinearVelocity
		if v.Y >= -1 and not gliding then
			fallingSince = nil -- (still going up: the half second starts on the way down)
			return
		end
		fallingSince = fallingSince or os.clock()
		if not gliding and os.clock() - fallingSince >= (G.After or 0.5) then
			gliding = true
			UseAbility:FireServer(Config.PARKOUR_INDEX, "Glide")
			VFX.Play("Parkour", char, { Kind = "Glide" }, true)
		end
		if gliding and v.Y < -(G.FallSpeed or 14) then
			root.AssemblyLinearVelocity = Vector3.new(v.X, -(G.FallSpeed or 14), v.Z)
		end
	end)
end

-- (round 59) AWAKENING OUTFITS: the phone's OUTFIT app lists your saved
-- Roblox outfits - read from Roblox on this machine, once you've said yes
-- to it (Roblox asks again every session) - and the one you pick is saved
-- on the server and worn while you're awakened
do
	local AES
	pcall(function()
		AES = game:GetService("AvatarEditorService")
	end)
	local fits, asking = nil, false
	local function show()
		HUD.SetOutfitList(fits, #fits == 0 and "No saved outfits yet - make one in Roblox's avatar editor, then come back." or nil)
	end
	-- Roblox's say-so, then the list (at most Config.AwakeningOutfits.Max)
	local function load()
		if fits then
			show()
			return
		end
		if asking then
			return
		end
		if not AES then
			HUD.SetOutfitList({}, "Outfits aren't available here.")
			return
		end
		asking = true
		HUD.SetOutfitList({}, "Asking Roblox for your saved outfits...")
		task.spawn(function()
			local allowed, answered = false, false
			local okAsk = pcall(function()
				local conn = AES.PromptAllowInventoryReadAccessCompleted:Connect(function(result)
					allowed = result == Enum.AvatarPromptResult.Success
					answered = true
				end)
				AES:PromptAllowInventoryReadAccess()
				local t0 = os.clock()
				while not answered and os.clock() - t0 < 60 do
					task.wait(0.1)
				end
				conn:Disconnect()
			end)
			if not (okAsk and allowed) then
				asking = false
				HUD.SetOutfitList({}, "The game can't see your outfits yet - press ALLOW ACCESS and say yes.", true)
				return
			end
			local list = {}
			local okList = pcall(function()
				local pages
				if not pcall(function()
					pages = AES:GetOutfitsAsync(Enum.OutfitSource.Created, Enum.OutfitType.Avatar)
				end) then
					pages = AES:GetOutfitsAsync()
				end
				local max = (Config.AwakeningOutfits and Config.AwakeningOutfits.Max) or 60
				while #list < max do
					for _, o in pages:GetCurrentPage() do
						local id = tonumber(o.Id or o.id)
						if id and #list < max then
							table.insert(list, { Id = id, Name = tostring(o.Name or o.name or "Outfit") })
						end
					end
					if pages.IsFinished then
						break
					end
					pages:AdvanceToNextPageAsync()
				end
			end)
			asking = false
			if not okList then
				HUD.SetOutfitList({}, "Roblox didn't send your outfits - try again in a moment.", true)
				return
			end
			fits = list
			show()
		end)
	end
	HUD.SetOutfitCallbacks({
		OnOpen = load,
		OnRetry = function()
			fits = nil
			load()
		end,
		OnPick = function(id)
			ShopRemote:FireServer("AwakenOutfit", id)
		end,
	})
	-- the one you'll wear, as the server has it
	local function mark()
		HUD.MarkOutfit(tonumber(player:GetAttribute("AwakenOutfit")) or 0)
	end
	player:GetAttributeChangedSignal("AwakenOutfit"):Connect(mark)
	mark()
end

---------------------------------------------------------------------------
-- SETTINGS (your cosmetics, everyone's, the music - saved with your data)
-- and TOP HEROES (L: the all-time kills board, ReplicatedStorage.TopHeroes)
---------------------------------------------------------------------------
do
	HUD.BuildSettings({
		OnSet = function(key, on)
			if key == "Music" and VFX.Hooks.SetMusicOn then
				VFX.Hooks.SetMusicOn(on)
			end
			SettingsRemote:FireServer(key, on)
		end,
		OnToggle = function(open, which)
			if open then
				HUD.ToggleShop(false)
			end
			if inputMode == "Gamepad" then
				selectGui(open and HUD.SettingsFirstButton(which) or nil)
			end
		end,
	})
	-- (round 65) AUTO RUN is off unless you switch it on
	local function syncAutoRun()
		HUD.SetSetting("AutoRun", player:GetAttribute("AutoRun") == true)
	end
	player:GetAttributeChangedSignal("AutoRun"):Connect(syncAutoRun)
	task.defer(syncAutoRun)
	-- (round 86) HIDE MY WINGS (Hawks): off unless you switch it on - the
	-- wing driver (VFX.HK) reads the attribute
	local function syncWings()
		HUD.SetSetting("HideMyWings", player:GetAttribute("HideMyWings") == true)
	end
	player:GetAttributeChangedSignal("HideMyWings"):Connect(syncWings)
	task.defer(syncWings)
	-- (round 68) the controller's camera: how fast the stick turns it, or
	-- Roblox's own camera (and its own sensitivity setting) instead
	local function syncPad()
		HUD.SetSetting("RobloxCamera", player:GetAttribute("RobloxCamera") == true)
		HUD.SetSetting("PadSensitivity", tonumber(player:GetAttribute("PadSensitivity")) or 1)
	end
	player:GetAttributeChangedSignal("RobloxCamera"):Connect(syncPad)
	player:GetAttributeChangedSignal("PadSensitivity"):Connect(syncPad)
	task.defer(syncPad)
	-- (what's saved comes back as your attributes)
	for _, key in { "WearCosmetics", "ShowCosmetics", "Music", "Blood" } do
		local function sync()
			local on = player:GetAttribute(key) ~= false
			HUD.SetSetting(key, on)
			if key == "Music" and VFX.Hooks.SetMusicOn then
				VFX.Hooks.SetMusicOn(on)
			end
			if key == "Blood" and VFX.BLOOD then
				VFX.BLOOD.on = on
			end
		end
		player:GetAttributeChangedSignal(key):Connect(sync)
		task.defer(sync)
	end

	-- SHOW COSMETICS off: other players' signature looks vanish on your
	-- screen (their QuirkGear.Cosmetics - hats, capes, masks, scars)
	local hidden = setmetatable({}, { __mode = "k" }) -- [part] = true
	local function applyShow()
		if player:GetAttribute("ShowCosmetics") ~= false then
			for part in hidden do
				part.LocalTransparencyModifier = 0
			end
			table.clear(hidden)
			return
		end
		for _, plr in Players:GetPlayers() do
			local cos = plr ~= player and plr.Character and plr.Character:FindFirstChild("QuirkGear")
			cos = cos and cos:FindFirstChild("Cosmetics")
			for _, part in cos and cos:GetDescendants() or {} do
				if part:IsA("BasePart") and not hidden[part] then
					hidden[part] = true
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end
	player:GetAttributeChangedSignal("ShowCosmetics"):Connect(applyShow)
	task.spawn(function()
		while true do
			task.wait(0.5)
			applyShow()
		end
	end)

	-- the board: rebuilt whenever the server publishes it
	local HttpService = game:GetService("HttpService")
	local function readBoard()
		local value = ReplicatedStorage:FindFirstChild("TopHeroes")
		local ok, list = pcall(function()
			return HttpService:JSONDecode(value and value.Value ~= "" and value.Value or "[]")
		end)
		HUD.SetBoard(ok and type(list) == "table" and list or {}, player.UserId)
	end
	task.spawn(function()
		local value = ReplicatedStorage:WaitForChild("TopHeroes", 30)
		if value then
			value.Changed:Connect(readBoard)
			readBoard()
		end
	end)
	ContextActionService:BindAction("QuirkBoard", function(_, state)
		if state == Enum.UserInputState.Begin then
			if HUD.ToggleBoard() then
				readBoard()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(Config.BoardKeys or { Enum.KeyCode.L }))
end

---------------------------------------------------------------------------
-- UNO at Tony's (Config.Uno): sat at a table, its panel is up - the server
-- runs the game, this just shows it and sends what you pick
---------------------------------------------------------------------------
task.spawn(function()
	local UnoRemote = Remotes:WaitForChild("Uno", 20)
	if not UnoRemote then
		return
	end
	local lastTop
	HUD.BuildUno({
		OnPlay = function(index, color)
			UnoRemote:FireServer("Play", index, color)
		end,
		OnDraw = function()
			UnoRemote:FireServer("Draw")
		end,
		OnPass = function()
			UnoRemote:FireServer("Pass")
		end,
		OnUno = function()
			UnoRemote:FireServer("Uno")
		end,
		OnCatch = function()
			UnoRemote:FireServer("Catch")
		end,
		OnStart = function()
			UnoRemote:FireServer("Start")
		end,
		OnLeave = function()
			UnoRemote:FireServer("Leave")
		end,
		OnPicker = function(first)
			if inputMode == "Gamepad" then
				selectGui(first)
			end
		end,
	})
	UnoRemote.OnClientEvent:Connect(function(kind, a, b)
		if kind == "State" and type(a) == "table" then
			HUD.UnoState(a)
			if a.Top and a.Top ~= lastTop then
				VFX.PlaySound("UnoCard", nil, 1)
			end
			lastTop = a.Top
			if inputMode == "Gamepad" then
				selectGui(a.MyTurn and HUD.UnoFirstButton() or nil)
			end
		elseif kind == "Toast" then
			HUD.UnoToast(a, b)
		elseif kind == "End" and type(a) == "table" then
			HUD.UnoEnd(a)
			VFX.PlaySound(a.You and "UnoWin" or "UnoCard", nil, 1)
		elseif kind == "Closed" then
			lastTop = nil
			HUD.UnoHide()
			selectGui(nil)
		end
	end)
end)

-- D-pad right: tap to use the picked item, hold to pick the next one
local itemHoldToken = 0
ContextActionService:BindAction("QuirkUseItem", function(_, state)
	if uiOpen() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin and pressPrompt() then
		return Enum.ContextActionResult.Sink -- (at a snack machine or a shopkeeper)
	end
	if state == Enum.UserInputState.Begin then
		itemHoldToken += 1
		local token = itemHoldToken
		task.delay(0.4, function()
			if itemHoldToken == token and #heldItems > 0 then
				itemHoldToken += 1 -- held: that was a pick, not a use
				selectedItem = selectedItem % #heldItems + 1
				HUD.SetItems(heldItems, selectedItem)
			end
		end)
	elseif state == Enum.UserInputState.End then
		if itemHoldToken % 2 == 1 then
			itemHoldToken += 1
			local entry = heldItems[selectedItem]
			if entry then
				useItem(entry.Id)
			end
		end
	end
	return Enum.ContextActionResult.Sink
end, false, table.unpack(Config.UseItemKeys or { Enum.KeyCode.DPadRight }))

for _, id in Config.ItemOrder do
	player:GetAttributeChangedSignal("Item_" .. id):Connect(refreshItems)
end
refreshItems()

local lastBucks = player:GetAttribute("Bucks") or 0
HUD.SetBucks(lastBucks)
player:GetAttributeChangedSignal("Bucks"):Connect(function()
	local now = player:GetAttribute("Bucks") or 0
	local gained = now - lastBucks
	lastBucks = now
	HUD.SetBucks(now, gained)
	HUD.SetVendorBucks(now)
	if gained > 0 then
		VFX.PlaySound("Bucks")
	end
end)

-- down the sniper scope: first person, zoomed in, slower aim
local scopeFov
local savedCameraMode, savedSensitivity
local function setScoped(on)
	if scoped == on then
		return
	end
	scoped = on
	HUD.SetScope(on)
	local cam = workspace.CurrentCamera
	if on then
		savedCameraMode = player.CameraMode
		savedSensitivity = UserInputService.MouseDeltaSensitivity
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseDeltaSensitivity = (savedSensitivity or 1) * 0.3
	else
		player.CameraMode = savedCameraMode or Enum.CameraMode.Classic
		UserInputService.MouseDeltaSensitivity = savedSensitivity or 1
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			-- LockFirstPerson leaves the zoom at the minimum: back out to third person
			local min = player.CameraMinZoomDistance
			player.CameraMinZoomDistance = 12
			task.delay(0.15, function()
				player.CameraMinZoomDistance = min
			end)
		end
	end
	if cam then
		if scopeFov then
			scopeFov:Cancel()
		end
		scopeFov = TweenService:Create(cam, TweenInfo.new(0.18), { FieldOfView = on and (Config.Items.Sniper.ScopeFov or 18) or MOVE.NormalFov })
		scopeFov:Play()
	end
end

---------------------------------------------------------------------------
-- Keyboard shortcuts and the input mode (keyboard / controller / touch)
---------------------------------------------------------------------------

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		m1Held = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or FreeCam.directing then
		return -- (round 87: directing, a click picks a target - no M1, menu or item)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		m1Held = true
		useM1()
	elseif input.KeyCode == Config.MenuKey then
		HUD.ToggleMenu()
		if HUD.MenuVisible() then
			HUD.ToggleShop(false)
		end
	else
		local slot = table.find(Config.ItemKeys or {}, input.KeyCode)
		if slot and heldItems[slot] then
			useItem(heldItems[slot].Id)
		end
	end
end)

local function modeFor(inputType)
	if inputType.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType == Enum.UserInputType.Keyboard or inputType.Name:sub(1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

local function setInputMode(mode)
	if not mode or mode == inputMode then
		return
	end
	inputMode = mode
	HUD.SetInputMode(mode)
	HUD.SetItems(heldItems, selectedItem)
end
UserInputService.LastInputTypeChanged:Connect(function(inputType)
	setInputMode(modeFor(inputType))
end)
setInputMode(modeFor(UserInputService:GetLastInputType())
	or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "Touch")
	or "Keyboard")
HUD.SetInputMode(inputMode)

-- A CONTROLLER CURSOR: with a menu open on a controller you get a cursor to
-- move like a mouse. The left stick moves it (faster the further you push),
-- whatever button it's over lights up and A presses it, and the right stick
-- scrolls the list under it. While it's up the sticks don't move you or the
-- camera. (It's our own: Roblox's virtual cursor needs a setting on the place.)
do
	local cursorGui = Instance.new("ScreenGui")
	cursorGui.Name = "PadCursor"
	cursorGui.DisplayOrder = 1000
	cursorGui.ResetOnSpawn = false
	cursorGui.Enabled = false
	cursorGui.Parent = player:WaitForChild("PlayerGui")
	local ring = Instance.new("Frame")
	ring.Name = "Cursor"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(30, 30)
	ring.BackgroundColor3 = Color3.new(1, 1, 1)
	ring.BackgroundTransparency = 0.25
	ring.Active = false
	ring.Parent = cursorGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2.5
	edge.Color = Color3.fromRGB(20, 20, 24)
	edge.Parent = ring
	local pip = Instance.new("Frame")
	pip.Name = "Pip"
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.Position = UDim2.fromScale(0.5, 0.5)
	pip.Size = UDim2.fromOffset(8, 8)
	pip.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	pip.Active = false
	pip.Parent = ring
	local pipCorner = corner:Clone()
	pipCorner.Parent = pip
	local playerGui = player:WaitForChild("PlayerGui")
	local pad = Enum.UserInputType.Gamepad1
	padCursor.pos = Vector2.zero
	-- the sticks as they are right now (read fresh every frame, so a missed
	-- "let go" can't leave it drifting); a resting stick that's worn and sits
	-- a little off centre doesn't count
	local DEAD = 0.22
	local function stickNow(code)
		local ok, state = pcall(function()
			return UserInputService:GetGamepadState(pad)
		end)
		for _, input in ok and state or {} do
			if input.KeyCode == code then
				local v = Vector2.new(input.Position.X, -input.Position.Y)
				local mag = math.min(v.Magnitude, 1)
				if mag <= DEAD then
					return Vector2.zero, 0
				end
				return v.Unit, (mag - DEAD) / (1 - DEAD)
			end
		end
		return Vector2.zero, 0
	end
	-- what's under it: the button it's over (or one it's inside) and a list
	local function under()
		local button, list
		for _, obj in playerGui:GetGuiObjectsAtPosition(padCursor.pos.X, padCursor.pos.Y) do
			if not obj:IsDescendantOf(cursorGui) then
				local o = obj
				while o and not o:IsA("LayerCollector") do
					if not button and o:IsA("GuiButton") and o.Visible and o.Selectable then
						button = o
					elseif not list and o:IsA("ScrollingFrame") then
						list = o
					end
					o = o.Parent
				end
				if button then
					break
				end
			end
		end
		return button, list
	end
	local function setOn(want)
		if want == padCursor.on then
			return
		end
		if want then
			-- (it starts on whatever the menu had picked, else the middle)
			local sel = GuiService.SelectedObject
			if sel and sel:IsDescendantOf(playerGui) then
				padCursor.pos = sel.AbsolutePosition + sel.AbsoluteSize / 2
			else
				padCursor.pos = cursorGui.AbsoluteSize / 2
			end
			ContextActionService:BindActionAtPriority("QuirkPadCursor", function(_, _state, input)
				if input.UserInputType.Name:sub(1, 7) == "Gamepad" then
					pad = input.UserInputType -- (whichever controller is being used)
				end
				if input.KeyCode == Enum.KeyCode.ButtonA and padCursor.hover then
					return Enum.ContextActionResult.Pass -- (it presses the button it's over)
				end
				return Enum.ContextActionResult.Sink -- (not a jump, not a walk, not the camera)
			end, false, 3000, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2, Enum.KeyCode.ButtonA)
		else
			ContextActionService:UnbindAction("QuirkPadCursor")
			pcall(function()
				GuiService.SelectedObject = nil
			end)
			padCursor.hover = nil
		end
		padCursor.on = want
		cursorGui.Enabled = want
	end
	padCursor.set = setOn
	RunService.RenderStepped:Connect(function(dt)
		setOn(inputMode == "Gamepad" and uiOpen())
		if not padCursor.on then
			return
		end
		local dir, k = stickNow(Enum.KeyCode.Thumbstick1)
		if k > 0 then
			padCursor.pos += dir * (1100 * k * k + 140 * k) * dt
		end
		local size = cursorGui.AbsoluteSize
		padCursor.pos = Vector2.new(math.clamp(padCursor.pos.X, 0, size.X), math.clamp(padCursor.pos.Y, 0, size.Y))
		ring.Position = UDim2.fromOffset(padCursor.pos.X, padCursor.pos.Y)
		local button, list = under()
		if button ~= padCursor.hover or GuiService.SelectedObject ~= button then
			padCursor.hover = button
			pcall(function()
				GuiService.SelectedObject = button
			end)
		end
		ring.Size = button and UDim2.fromOffset(38, 38) or UDim2.fromOffset(30, 30)
		ring.BackgroundColor3 = button and Color3.fromRGB(255, 226, 120) or Color3.new(1, 1, 1)
		local sdir, sk = stickNow(Enum.KeyCode.Thumbstick2)
		if list and sk > 0 then
			list.CanvasPosition += sdir * 900 * sk * dt
		end
	end)
end

---------------------------------------------------------------------------
-- Character + attribute sync
---------------------------------------------------------------------------

-- Custom idle/walk/run/jump/fall: written into Roblox's Animate script values
local ANIMATE_SLOTS = {
	Idle = { "idle", { "Animation1", "Animation2" } },
	Walk = { "walk", { "WalkAnim" } },
	Run = { "run", { "RunAnim" } },
	Jump = { "jump", { "JumpAnim" } },
	Fall = { "fall", { "FallAnim" } },
	Climb = { "climb", { "ClimbAnim" } },
}
local function applyMovementAnimations(char)
	local set = Config.Animations and Config.Animations.Movement
	if not set then
		return
	end
	local hum = char:WaitForChild("Humanoid", 5)
	local rig = Config.Animations.Rig
	if hum and rig and rig ~= "" and hum.RigType.Name ~= rig then
		return -- these clips are made for another rig type; keep Roblox's defaults
	end
	local animate = char:WaitForChild("Animate", 5)
	if not animate then
		return
	end
	for key, slot in ANIMATE_SLOTS do
		local id = set[key]
		local folder = animate:FindFirstChild(slot[1])
		if id and id ~= "" and folder then
			for index, name in slot[2] do
				local anim = folder:FindFirstChild(name)
				-- a list gives each variant its own clip (idle + look-around)
				local useId = type(id) == "table" and (id[index] or id[1]) or id
				if anim and anim:IsA("Animation") and type(useId) == "string" and useId ~= "" then
					anim.AnimationId = useId
				end
			end
		end
	end
end

-- Roblox's Animate (the walk / idle / jump clips). A body the server builds
-- and hands over (the R15 -> R6 swap) comes with one that never starts: a
-- LocalScript already inside a model before it becomes your character doesn't
-- run. Every body gets a fresh copy started from here, anything the old one
-- left playing stopped first. (Nothing playing at all: the procedural gait
-- steps in - Config.Animations.Procedural.)
local function restartAnimate(char)
	local t0 = os.clock()
	while char.Parent and char:GetAttribute("ClassicJoints") == nil and os.clock() - t0 < 5 do
		task.wait(0.1)
	end
	local animate = char:WaitForChild("Animate", 5)
	if not animate or not animate:IsA("LocalScript") or player.Character ~= char or animate:GetAttribute("Restarted") then
		return
	end
	local fresh = animate:Clone()
	fresh:SetAttribute("Restarted", true)
	animate:Destroy()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	fresh.Parent = char
	applyMovementAnimations(char)
end

local function onCharacter(char)
	if activeDashCleanup then activeDashCleanup("Interrupted") end
	CombatInput.untilAt, CombatInput.pending = 0, nil
	CombatInput.m1SlowUntil, slamJump.apexAt = nil, nil -- (round 81)
	slamJump.armedAt, slamJump.commitAt, slamJump.fixAt, slamJump.holdUp = nil, nil, nil, false -- (round 83)
	slamJump.pressArm, slamJump.upAt, slamJump.hopPress = nil, nil, nil -- (round 84)
	m1Count, m1Last, m1Next = 0, 0, 0
	guardHeld, m1Held = false, false
	VFX.CancelCinematic()
	setScoped(false)
	local hum = char:WaitForChild("Humanoid")
	HUD.BindHumanoid(hum)
	HUD.BindGuard(char)
	blocking = false
	-- the server dropped the guard (broken, or hit from behind)
	char:GetAttributeChangedSignal("Blocking"):Connect(function()
		if blocking and char:GetAttribute("Blocking") == false then
			stopBlock(false)
		end
	end)
	char:GetAttributeChangedSignal("Stunned"):Connect(function()
		if char:GetAttribute("Stunned") then
			CombatInput.untilAt, CombatInput.pending = 0, nil
			stopBlock()
		end
	end)
	-- frozen solid: whatever you were in the middle of stops dead - a dash, a
	-- swing (and its fling), a queued move (the server cuts the move itself
	-- short, a charge included)
	char:GetAttributeChangedSignal("Frozen"):Connect(function()
		if char:GetAttribute("Frozen") then
			CombatInput.untilAt, CombatInput.pending = 0, nil
			if activeDashCleanup then activeDashCleanup("Interrupted") end
			VFX.SwingRelease(char)
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end)
	hum.Died:Connect(function()
		CombatInput.untilAt, CombatInput.pending = 0, nil
		guardHeld, m1Held = false, false
		if activeDashCleanup then activeDashCleanup("Interrupted") end
		stopBlock(false)
	end)
	sprintTrack = nil
	task.spawn(applyMovementAnimations, char)
	task.spawn(restartAnimate, char)
	-- a hit that knocks you back ends whatever your own move was carrying
	-- you along (a lunge, a dive): no tug-of-war between the two pushes
	task.spawn(function()
		local r = char:WaitForChild("HumanoidRootPart", 10)
		if not r then
			return
		end
		r.ChildAdded:Connect(function(c)
			if c.Name ~= "Knockback" then
				return
			end
			for _, d in r:GetChildren() do
				if d:IsA("LinearVelocity") and d.Attachment0 and d.Attachment0.Name == "DashAttachment" then
					d:Destroy()
				end
			end
		end)
	end)
	-- the ragdoll cancel's meter
	local function evasiveMeter()
		HUD.SetEvasive(char:GetAttribute("Evasive") or 0, char:GetAttribute("Ragdolled") == true)
	end
	char:GetAttributeChangedSignal("Evasive"):Connect(evasiveMeter)
	char:GetAttributeChangedSignal("Ragdolled"):Connect(evasiveMeter)
	evasiveMeter()
	-- Suneater's stomach (only while he's the one you're playing)
	local function stomachMeter()
		HUD.SetStomach(tonumber(char:GetAttribute("Stomach")))
	end
	char:GetAttributeChangedSignal("Stomach"):Connect(stomachMeter)
	stomachMeter()
	-- Mr. Compress's marbles and Chargebolt's pointers: pips over the health bar
	local function pipMeter()
		local marbles, pointers = tonumber(char:GetAttribute("Marbles")), tonumber(char:GetAttribute("Pointers"))
		local MC, DK = Config.Quirks.Compress, Config.Quirks.Electrification
		local doubles, TWc = tonumber(char:GetAttribute("Doubles")), Config.Quirks.Double -- (round 69: Twice's doubles out)
		if doubles and TWc then
			local ult = char:GetAttribute("UltActive") and TWc.Ult and TWc.Ult.Special
			local measuring = char:GetAttribute("Measuring")
			HUD.SetPips({
				Label = measuring and ("MEASURED " .. string.upper(tostring(measuring)) .. "  -  DOUBLES") or "DOUBLES", Count = doubles, Max = (ult and ult.Max) or (TWc.Clones or {}).Max or 2, Color = TWc.AccentColor,
				Hint = measuring and ("R: A DOUBLE OF " .. string.upper(tostring(measuring))) or "R: A DOUBLE OF HIMSELF",
			})
		elseif marbles and MC then
			HUD.SetPips({ Label = "MARBLES", Count = marbles, Max = (MC.Marbles or {}).Max or 3, Color = MC.AccentColor, Hint = "R: POCKET A PIECE OF THE STREET" })
		elseif pointers and DK then
			HUD.SetPips({ Label = "POINTERS", Count = pointers, Max = (DK.Pointers or {}).Max or 2, Color = Color3.fromRGB(255, 140, 40), Hint = "ALL OUT: BACK WHEN THEY EXPIRE" })
		else
			HUD.SetPips(nil)
		end
	end
	char:GetAttributeChangedSignal("Marbles"):Connect(pipMeter)
	char:GetAttributeChangedSignal("Pointers"):Connect(pipMeter)
	char:GetAttributeChangedSignal("Doubles"):Connect(pipMeter)
	char:GetAttributeChangedSignal("Measuring"):Connect(pipMeter)
	char:GetAttributeChangedSignal("UltActive"):Connect(pipMeter)
	pipMeter()
	-- Endeavor's heat gauge
	local function heatMeter()
		HUD.SetHeat(tonumber(char:GetAttribute("Heat")), char:GetAttribute("Overheated") == true)
	end
	char:GetAttributeChangedSignal("Heat"):Connect(heatMeter)
	char:GetAttributeChangedSignal("Overheated"):Connect(heatMeter)
	heatMeter()
	-- (round 86) Hawks' feathers (only while he's the one you're playing):
	-- out of FeathersMax (150 in the ult); fire burning them flashes it
	local function featherMeter(burned)
		local f = tonumber(char:GetAttribute("Feathers"))
		local spec = Config.Quirks.FierceWings and Config.Quirks.FierceWings.Feathers or {}
		HUD.SetFeathers(f, tonumber(char:GetAttribute("FeathersMax")) or spec.Max or 100, f and {
			Plucked = char:GetAttribute("Plucked") == true,
			Flying = char:GetAttribute("HawksFlying") == true or HawksFly.active,
			Storm = char:GetAttribute("HawksStorm") == true, -- (round 86 review: every feather out in the storm - not plucked)
			Low = spec.Low or 20,
			Burned = burned == true,
		} or nil)
	end
	for _, key in { "Feathers", "FeathersMax", "Plucked", "HawksFlying", "HawksStorm" } do
		char:GetAttributeChangedSignal(key):Connect(featherMeter)
	end
	VFX.Hooks.FeathersBurned = function(who)
		if who == char then
			featherMeter(true)
		end
	end
	featherMeter()
	-- Roblox's own trip-and-fall states: a bump from a flying chunk, a push
	-- at a ledge, a landing at speed could knock you over for a second or two
	-- by themselves (the "random ragdolls"). Only the game's ragdoll puts you
	-- down now.
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
	-- only health decides a KO: a ragdolled neck pulled apart by a violent
	-- launch mustn't kill (our machine runs our body's physics, so it's set
	-- here as well as on the server)
	hum.RequiresNeck = false
	-- ragdoll: we own our Humanoid, so we switch it to Physics and back.
	-- Getting up: stand upright above the ground right where we lie BEFORE
	-- the Humanoid takes over - letting it wrench a body that's lying in the
	-- street upright is what used to launch people into the air.
	-- (round 63) smoother: going down, the limbs set off with the body (they
	-- don't trail the push); getting up starts from where we lie - under the
	-- torso, turned so the get-up clip begins lying just as we are (on our
	-- back: head behind, we sit up; face down: head in front, we push up)
	char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if char:GetAttribute("Ragdolled") then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			VFX.ReleasePose(char, 0)
			if root then
				for _, part in char:GetChildren() do
					if part:IsA("BasePart") and part ~= root then
						part.AssemblyLinearVelocity = root.AssemblyLinearVelocity
					end
				end
			end
		elseif hum.Health > 0 and root then
			local torso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso") or root
			local up = torso.CFrame.UpVector
			local face = up.Y <= 0.55 and (torso.CFrame.LookVector.Y < -0.2 and "Down" or "Up") or nil
			local look = flat(root.CFrame.LookVector)
			local head = flat(up)
			if face and head.Magnitude > 0.3 then
				look = face == "Down" and head or -head
			elseif look.Magnitude < 0.2 then
				look = flat(-root.CFrame.UpVector) -- face down
			end
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char, VFX.Folder }
			local hit = workspace:Raycast(torso.Position + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
			local hip = hum.HipHeight
			local height = ((hip and hip > 0) and hip or 2) + root.Size.Y / 2
			local y = hit and (face and hit.Position.Y + height or math.max(hit.Position.Y + height, torso.Position.Y)) or torso.Position.Y + 1
			local pos = Vector3.new(torso.Position.X, y, torso.Position.Z)
			root.CFrame = CFrame.lookAt(pos, pos + look.Unit)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			-- (straight away on our own screen: the server's word comes a moment later)
			VFX.GetUpFrom(char, face, true)
		end
	end)
	airDashesLeft = MOVE.AirDashes
	dashing = false
	airborneSince = nil
	leapUsed = false
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airDashesLeft = MOVE.AirDashes
			airborneSince = nil
			leapUsed = false
		elseif (new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall) and not airborneSince then
			airborneSince = os.clock()
		end
	end)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

-- The camera follows YOUR body. The server swaps a fresh spawn's body for an
-- R6 one (player.Character = the new rig), and Roblox only aims the camera
-- by itself on a normal spawn: on a live server the swap lands a moment
-- after you've spawned, and the camera stayed on the old (deleted) body
-- while you walked away. Every new body gets the camera, and a watchdog
-- puts it back if it's ever left on something that isn't you.
do
	local function followBody(char)
		local hum = char:WaitForChild("Humanoid", 10)
		local cam = workspace.CurrentCamera
		if hum and cam and player.Character == char and not VFX.InCinematic() and not scoped then
			cam.CameraSubject = hum
			if cam.CameraType == Enum.CameraType.Scriptable or cam.CameraType == Enum.CameraType.Fixed then
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end
	player.CharacterAdded:Connect(followBody)
	if player.Character then
		task.spawn(followBody, player.Character)
	end
	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < 0.5 then
			return
		end
		lastCheck = now
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not hum or hum.Health <= 0 or not cam or VFX.InCinematic() or scoped then
			return
		end
		local subject = cam.CameraSubject
		-- (on an old body, a deleted one, or nothing at all: back to you)
		local lost = subject == nil or not subject:IsDescendantOf(workspace)
			or (subject:IsA("Humanoid") and subject ~= hum and subject.Parent and subject.Parent.Name == player.Name)
		if lost then
			cam.CameraSubject = hum
			if cam.CameraType == Enum.CameraType.Scriptable or cam.CameraType == Enum.CameraType.Fixed then
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end)
end

-- The movement pack in Workspace.MovementSystem (directional walking, the
-- head following the camera, smooth shift lock). LocalScripts don't run from
-- Workspace, so each spawn gets its own copies of the character scripts, and
-- the shift lock module is started from here.
task.spawn(function()
	local pack = workspace:WaitForChild("MovementSystem", 15)
	if not pack then
		return
	end
	local charScripts = pack:FindFirstChild("StarterCharacterScript")
	local function addCharacterScripts(char)
		if not charScripts then
			return
		end
		-- the pack drives R6 Motor6Ds: wait for the server to settle the joints
		-- (ClassicJoints), and leave any other kind of body alone
		local t0 = os.clock()
		while char.Parent and char:GetAttribute("ClassicJoints") == nil and os.clock() - t0 < 5 do
			task.wait(0.1)
		end
		local torso = char:WaitForChild("Torso", 5)
		local root = char:FindFirstChild("HumanoidRootPart")
		local rootJoint = root and root:FindFirstChild("RootJoint")
		if not torso or not rootJoint or not rootJoint:IsA("Motor6D") then
			return
		end
		-- (the pack's directional walking writes the same hip / waist joints as
		-- the procedural gait, which already turns the legs into the direction
		-- you move: with both, they fight every frame, so it sits out)
		-- ("auto": the pack's walking stays - the gait only covers a body with no clips)
		local gaitR6 = not Config.Animations or not Config.Animations.Procedural or Config.Animations.Procedural.R6 == true
		for _, s in charScripts:GetChildren() do
			if s:IsA("LocalScript") and not char:FindFirstChild(s.Name) and not (gaitR6 and s.Name == "Directional Walking Script") then
				s:Clone().Parent = char
			end
		end
	end
	player.CharacterAdded:Connect(addCharacterScripts)
	if player.Character then
		task.spawn(addCharacterScripts, player.Character)
	end
	local lockHolder = pack:FindFirstChild("StarterPlayerScripts")
	local lockScript = lockHolder and lockHolder:FindFirstChild("CustomShiftLock")
	local lockModule = lockScript and lockScript:FindFirstChild("SmoothShiftLock")
	if lockModule then
		local ok, shiftLock = pcall(require, lockModule)
		if ok and shiftLock then
			shiftLock:Init()
			if player.Character then
				shiftLock:CharacterAdded()
			end
			-- (a body the engine didn't announce - the R15 -> R6 swap - left
			-- the lock on the old body and Shift did nothing: re-bind whenever
			-- the body changes, and check twice a second)
			if shiftLock.Ensure then
				player:GetPropertyChangedSignal("Character"):Connect(function()
					pcall(shiftLock.Ensure, shiftLock)
				end)
				task.spawn(function()
					while true do
						task.wait(0.5)
						pcall(shiftLock.Ensure, shiftLock)
					end
				end)
			end
			-- shift lock keys come from the config (Left Shift, D-pad down)
			local edit = lockModule:FindFirstChild("EditConfig")
			if edit and Config.ShiftLockKeys then
				task.spawn(function()
					if not player.Character then
						player.CharacterAdded:Wait()
					end
					task.wait(0.5)
					edit:Fire("SHIFT_LOCK_KEYBINDS", Config.ShiftLockKeys)
					-- (round 65) the body turns with the camera the same frame
					edit:Fire("CHARACTER_SMOOTH_ROTATION", (Config.Look or {}).InstantShiftLock == false)
				end)
			end
		end
	end
end)

-- the shopkeeper whose menu is open (it closes when you walk off)
local vendorNpc = nil
RunService.Heartbeat:Connect(function()
	if not HUD.VendorVisible() then
		return
	end
	local _, _, root = getCharacter()
	local npcRoot = vendorNpc and vendorNpc:FindFirstChild("HumanoidRootPart")
	local range = ((Config.PizzaParlor and Config.PizzaParlor.TalkRange) or 14) + 8
	if not root or not npcRoot or (npcRoot.Position - root.Position).Magnitude > range then
		HUD.HideVendor()
		selectGui(nil)
	end
end)

-- Fight feedback that lives on the HUD rather than in the world
local UI_EVENTS = {
	-- (server settings: someone reset your cooldowns)
	ResetCooldowns = function()
		lastUsed = {}
		recoverUntil = 0
		HUD.ResetCooldowns()
	end,
	KOFeed = function(data)
		HUD.KillFeed(data)
	end,
	-- a new hero rank (Config.Ranks): yours gets the banner
	RankUp = function(data)
		local mine = data.UserId == player.UserId
		HUD.RankUp(data, mine)
		if mine then
			VFX.PlaySound("RankUp")
		end
	end,
	KOConfirm = function(data)
		HUD.KOPopup(data)
		VFX.PlaySound("KOConfirm")
		if data.Callout then
			VFX.PlaySound("Streak")
		end
	end,
	Recap = function(data)
		HUD.ShowRecap(data)
		VFX.PlaySound("Knocked")
	end,
	Notice = function(data)
		HUD.Notice(tostring(data.Text or ""), typeof(data.Color) == "Color3" and data.Color or nil)
	end,
	ShopResult = function(data)
		HUD.ShopResult(data.Ok == true, data.Item or data.Emote, data.Text)
		if data.Ok and data.Emote then
			for _, e in Config.Emotes or {} do
				if e.Id == data.Emote then
					HUD.Notice((e.Icon or "★") .. " " .. (e.Name or e.Id) .. " unlocked" .. (data.Slot and (": it's on your wheel (slot " .. data.Slot .. ")") or ": put it on your wheel in the shop"), Color3.fromRGB(150, 255, 160))
				end
			end
		end
		VFX.PlaySound(data.Ok and "Purchase" or "ShopNo")
		if not data.Ok and data.Text and HUD.VendorVisible() then
			HUD.VendorSay(data.Text)
		end
		local item = Config.Items[data.Item or ""]
		if data.Ok and item and data.Ate then
			HUD.Notice("Your bag was full, so you ate the " .. string.lower(item.Name) .. " right there", Color3.fromRGB(150, 255, 160))
		elseif data.Ok and item and item.Heal and not table.find(Config.ShopOrder or {}, data.Item) then
			HUD.Notice(item.Icon .. " " .. item.Name .. " is in your bag", Color3.fromRGB(150, 255, 160))
		end
	end,
	-- (round 63) what an emote roll gave (face-down cards, flipped one by one)
	EmoteRoll = function(data)
		if type(data.Got) == "table" then
			HUD.ShowEmoteRoll(data.Got, tonumber(data.Pick) or 0)
		end
	end,
	CodeResult = function(data)
		HUD.CodeResult(data.Ok == true, data.Text)
		VFX.PlaySound(data.Ok and "Purchase" or "ShopNo")
	end,
	-- a shopkeeper's menu (Tony)
	VendorMenu = function(data)
		local shop = data.Vendor == "Pizza" and Config.PizzaParlor
		if not shop then
			return
		end
		vendorNpc = typeof(data.Npc) == "Instance" and data.Npc or nil
		HUD.ShowVendor({
			Title = shop.Name,
			Line = data.Line,
			Items = shop.Menu,
			Bucks = player:GetAttribute("Bucks") or 0,
			OnBuy = function(id)
				ShopRemote:FireServer("Buy", id, data.Vendor)
			end,
		})
		if inputMode == "Gamepad" then
			selectGui(HUD.FirstButton("Vendor"))
		end
	end,
	-- Rewind: every cooldown but its own is ready again
	CooldownReset = function(data)
		local keep = data.Keep
		local kept = keep and lastUsed[keep]
		lastUsed = {}
		lastUsed[keep or ""] = kept
		recoverUntil = 0
		HUD.ResetCooldowns()
		local special = Config.GetAbility(player:GetAttribute("Quirk"), SPECIAL)
		if kept and special then
			startCd(keep, math.max(special.Cooldown - (os.clock() - kept), 0.05))
		end
	end,
}

-- Everyone else's moves + server-confirmed hits/freezes
PlayVFX.OnClientEvent:Connect(function(effectId, casterChar, data)
	local ui = UI_EVENTS[effectId]
	if ui then
		ui(data or {})
		return
	end
	data = data or {}
	local myChar = player.Character
	if effectId == "Reload" and player:GetAttribute("Quirk") then
		-- (Chargebolt's clip is empty: R is reloading - the slot shows it; or
		-- the server's put a longer wait on a move, e.g. after Transmission)
		local key = type(data.Key) == "string" and data.Key or Config.CooldownKey(player:GetAttribute("Quirk"), SPECIAL)
		startCd(key, tonumber(data.Time) or 4)
		-- (round 78) a move that didn't come off (United States of Smash, a
		-- whiff) costs only Time of its Full cooldown
		local full, left = tonumber(data.Full), tonumber(data.Time)
		if full and left and lastUsed[key] then
			lastUsed[key] = os.clock() - math.max(full - left, 0)
		end
	end
	if effectId == "Scope" and myChar and casterChar == myChar then
		setScoped(data.On == true)
	end
	if effectId == "NpcSay" and vendorNpc and data.Npc == vendorNpc and HUD.VendorVisible() then
		HUD.VendorSay(data.Text)
	end
	if effectId == "Hit" then
		if data.Attacker == player then
			HUD.ComboHit(data.Amount or 0)
		elseif myChar and data.Target == myChar then
			HUD.ComboBreak()
		end
	elseif effectId == "Parry" then
		if data.By == player then
			HUD.Callout("PARRY!", Color3.fromRGB(255, 220, 90))
		elseif data.Against == player then
			HUD.Callout("PARRIED!", Color3.fromRGB(255, 110, 90))
			HUD.ComboBreak()
		end
	elseif effectId == "GuardBreak" and myChar and data.Target == myChar then
		HUD.Callout("GUARD BROKEN", Color3.fromRGB(255, 90, 70))
	elseif effectId == "GuardBreak" then
		local target = data.Target
		if typeof(target) == "Instance" and target:GetAttribute("LastHitBy") == player.Name then
			HUD.Callout("GUARD BREAK!", Color3.fromRGB(120, 220, 255))
		end
	end
	VFX.Play(effectId, casterChar, data, false)
end)

-- (cooldowns are kept per quirk, like the server keeps them: switching
-- away and back doesn't make anything ready early)
local function refreshQuirk()
	local quirkName = player:GetAttribute("Quirk")
	altMode = player:GetAttribute("QuirkAlt") == true
	ultMode = player:GetAttribute("UltActive") == true
	recoverUntil = 0
	refreshHud(false)
	refreshTimer()
	if not quirkName then
		HUD.ShowMenu(true)
	end
end

local function refreshUltMeter()
	HUD.SetUltMeter(player:GetAttribute("Ult") or 0, player:GetAttribute("UltActive") == true)
end

local function onUltChanged()
	local was = ultMode
	syncMode()
	if was and not ultMode then
		lastUsed = {} -- fresh cooldowns when the ult ends
		refreshHud(true)
	end
	refreshUltMeter()
end

-- the test menu's disco party
local function refreshDisco()
	VFX.SetDisco(workspace:GetAttribute("Disco") == true, workspace:GetAttribute("DiscoCenter"))
end
workspace:GetAttributeChangedSignal("Disco"):Connect(refreshDisco)
if workspace:GetAttribute("Disco") then
	task.spawn(refreshDisco)
end

player:GetAttributeChangedSignal("Quirk"):Connect(refreshQuirk)
player:GetAttributeChangedSignal("QuirkAlt"):Connect(syncMode)
player:GetAttributeChangedSignal("AltEnds"):Connect(refreshTimer)
player:GetAttributeChangedSignal("UltActive"):Connect(onUltChanged)
player:GetAttributeChangedSignal("QuirkPick"):Connect(function()
	refreshHud(false) -- (Deku's R put another quirk in the 4th slot)
end)
-- Crazy Diamond's blueprint (V): BUILD's label says what it'll make
HUD.Blueprint = player:GetAttribute("Blueprint")
player:GetAttributeChangedSignal("Blueprint"):Connect(function()
	HUD.Blueprint = player:GetAttribute("Blueprint")
	refreshHud(false)
	if HUD.Blueprint then
		HUD.Notice("BLUEPRINT: " .. string.upper(HUD.Blueprint), Color3.fromRGB(240, 146, 196))
	end
end)
player:GetAttributeChangedSignal("UltEnds"):Connect(refreshTimer)
player:GetAttributeChangedSignal("Ult"):Connect(refreshUltMeter)
refreshQuirk()
refreshUltMeter()

---------------------------------------------------------------------------
-- Testing menu (only shows for players the server marks as testers)
---------------------------------------------------------------------------

local TEST_ITEMS = {
	-- (round 58: in groups, shown two to a row)
	{ Id = "FillUlt", Label = "Fill Ult Meter", Group = "You" },
	{ Id = "EndUlt", Label = "End Ult", Group = "You" },
	{ Id = "ResetCooldowns", Label = "Reset Cooldowns", Group = "You" },
	{ Id = "Heal", Label = "Heal", Group = "You" },
	{ Id = "GodMode", Label = "God Mode", Toggle = true, Group = "You" },
	{ Id = "NoCooldowns", Label = "No Cooldowns", Toggle = true, Group = "You" },
	{ Id = "ResetStats", Label = "Reset My KOs", Group = "You" },
	-- (round 66) the leaderboard's test feature
	{ Id = "AddKills", Label = "+1 KO (Leaderboard)", Group = "You" },
	{ Id = "AddKills10", Label = "+10 KOs (Leaderboard)", Group = "You" },
	{ Id = "Respawn", Label = "Respawn", Group = "You" },
	{ Id = "DummyPanel", Label = "Spawn Dummies...", Group = "Dummies" },
	{ Id = "ResetDummies", Label = "Reset Dummies", Group = "Dummies" },
	{ Id = "TeleportDummies", Label = "Teleport to Dummies", Group = "Dummies" },
	{ Id = "DummiesBlock", Label = "Dummies Block", Toggle = true, Group = "Dummies" },
	{ Id = "ServerPanel", Label = "Server Settings...", Group = "World" },
	{ Id = "Destruction", Label = "Map Destruction", Toggle = true, Group = "World" },
	{ Id = "RebuildMap", Label = "Rebuild Map Now", Group = "World" },
	{ Id = "Vestige", Label = "One For All: In / Out", Group = "World" },
	{ Id = "Memories", Label = "One For All: Deku's Memories", Group = "World" },
	{ Id = "DevAccessPanel", Label = "Dev Access...", Group = "Extras" },
	{ Id = "RosterPanel", Label = "Hero Roster...", Group = "Extras" }, -- (round 86: public / dev only, live)
	{ Id = "FunPanel", Label = "Fun Stuff...", Group = "Extras" },
}

-- the FUN STUFF panel (each one is a TestCommand on the server)
local FUN_ITEMS = {
	{ Id = "MoneyPrinter", Label = "Money Printer", Info = "+100 Bucks. It goes brrr.", Color = Color3.fromRGB(96, 190, 96) },
	{ Id = "GiantMode", Label = "Giant Mode", Info = "Three times the hero (toggle)", Color = Color3.fromRGB(255, 132, 36) },
	{ Id = "TinyMode", Label = "Tiny Mode", Info = "Mineta-sized (toggle)", Color = Color3.fromRGB(150, 70, 200) },
	{ Id = "Bobblehead", Label = "Bobblehead", Info = "A head three times too big (toggle)", Color = Color3.fromRGB(255, 150, 190) },
	{ Id = "MoonGravity", Label = "Moon Gravity", Info = "Everyone jumps sky-high (toggle)", Color = Color3.fromRGB(190, 200, 230) },
	{ Id = "LaunchEveryone", Label = "Launch Everyone", Info = "Every player and dummy goes to orbit", Color = Color3.fromRGB(80, 140, 255) },
	{ Id = "DummyRain", Label = "Dummy Rain", Info = "Eight dummies fall out of the sky", Color = Color3.fromRGB(226, 196, 156) },
	{ Id = "DiscoParty", Label = "Disco Party", Info = "Mirror ball, music, everyone dances (toggle)", Color = Color3.fromRGB(255, 60, 120) },
	{ Id = "HairForAll", Label = "All Might Hair For All", Info = "Everyone gets the legendary bangs", Color = Color3.fromRGB(252, 218, 84) },
}

-- SERVER SETTINGS (Jujutsu Shenanigans' private-server menu): the rows
local PS_SPEC = {
	Server = {
		{ Id = "Destruction", Label = "Destruction", Kind = "Toggle" },
		{ Id = "MapRegen", Label = "Destruction Respawns", Kind = "Toggle" },
		{ Id = "RagdollCancel", Label = "Ragdoll Cancel", Kind = "Toggle" },
		{ Id = "Knockdowns", Label = "Knockdowns (moves put you down)", Kind = "Toggle" },
		{ Id = "DashPunches", Label = "Dash Punches", Kind = "Toggle" },
		{ Id = "HealthRegen", Label = "Health Regen (out of combat)", Kind = "Toggle" },
		{ Id = "Clashes", Label = "Quirk Clashes (big moves meeting head-on)", Kind = "Toggle" },
		{ Id = "SkyBattle", Label = "All Might vs All For One (in the sky)", Kind = "Toggle" },
		{ Id = "SkyBattleNow", Label = "All Might vs All For One - Now", Kind = "Button", Button = "GO" },
		{ Id = "DekuDrop", Label = "Deku Drops In (middle of the city)", Kind = "Toggle" },
		{ Id = "DekuDropNow", Label = "Deku Drops In - Now", Kind = "Button", Button = "GO" },
		{ Id = "NomuRaid", Label = "Nomu Raids (off unless switched on)", Kind = "Toggle" },
		{ Id = "NomuRaidNow", Label = "Nomu Raid - Now", Kind = "Button", Button = "GO" },
		{ Id = "NomuRaidKill", Label = "Nomu Raid - Kill the Nomu", Kind = "Button", Button = "KILL" },
		{ Id = "MufflerPrank", Label = "Iida's Muffler Prank (ult: LB + RB in the air)", Kind = "Toggle" },
		{ Id = "DamageMult", Label = "Damage Multiplier", Kind = "Number", Steps = { 0, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 5, 10 }, Suffix = "x" },
		{ Id = "KnockbackMult", Label = "Knockback Multiplier", Kind = "Number", Steps = { 0, 0.25, 0.5, 1, 1.5, 2, 3, 5 }, Suffix = "x" },
		{ Id = "Gravity", Label = "Gravity", Kind = "Number", Steps = { 20, 50, 100, 150, 196.2, 250, 350, 500 } },
		{ Id = "SpeedMult", Label = "Walk Speed", Kind = "Number", Steps = { 0.5, 0.75, 1, 1.25, 1.5, 2, 3 }, Suffix = "x" },
		{ Id = "JumpMult", Label = "Jump Power", Kind = "Number", Steps = { 0.5, 0.75, 1, 1.25, 1.5, 2, 3 }, Suffix = "x" },
		{ Id = "UltRate", Label = "Ult Charge Rate", Kind = "Number", Steps = { 0, 0.5, 1, 2, 5, 10, 20 }, Suffix = "x" },
		{ Id = "ClearRubble", Label = "Clear Rubble", Kind = "Button" },
		{ Id = "RebuildMap", Label = "Rebuild Map Now", Kind = "Button" },
		{ Id = "ResetSettings", Label = "Reset All Settings", Kind = "Button", Button = "RESET" },
	},
	Players = {
		{ Id = "GodMode", Label = "God Mode", Kind = "Toggle" },
		{ Id = "NoCooldowns", Label = "No Cooldowns", Kind = "Toggle" },
		{ Id = "InfiniteUlt", Label = "Infinite Ult", Kind = "Toggle" },
		{ Id = "NoStun", Label = "No Stun", Kind = "Toggle" },
		{ Id = "Flight", Label = "Flight  [N]", Kind = "Toggle" },
		{ Id = "Skills", Label = "Moves + Dashes", Kind = "Toggle" },
		{ Id = "Melee", Label = "Melee (M1)", Kind = "Toggle" },
		{ Id = "Parkour", Label = "Parkour", Kind = "Toggle" },
		{ Id = "Evade", Label = "Ragdoll Cancel", Kind = "Toggle" },
		{ Id = "Heal", Label = "Heal", Kind = "Button" },
		{ Id = "FillUlt", Label = "Fill Ult", Kind = "Button" },
		{ Id = "Evasive", Label = "Refill Ragdoll Cancel", Kind = "Button" },
		{ Id = "ResetCooldowns", Label = "Reset Cooldowns", Kind = "Button" },
		{ Id = "Bring", Label = "Bring To Me", Kind = "Button" },
		{ Id = "GoTo", Label = "Go To Them", Kind = "Button" },
		{ Id = "Respawn", Label = "Respawn", Kind = "Button" },
		{ Id = "Kill", Label = "Kill", Kind = "Button" },
		{ Id = "Kick", Label = "Kick From Server", Kind = "Button", Button = "KICK" },
	},
}
-- (Skills / Melee / Parkour / Evade are stored the other way round: No...)
local PS_FLAGS = {
	GodMode = "GodMode", NoCooldowns = "NoCooldowns", InfiniteUlt = "InfiniteUlt", NoStun = "NoStun", Flight = "Flight",
	Skills = "-NoSkills", Melee = "-NoMelee", Parkour = "-NoParkour", Evade = "-NoEvade",
}

function FreeCam.buildPanel()
	local worldAttr = { Destruction = "DestructionEnabled", MapRegen = "MapRegen", RagdollCancel = "EvasiveEnabled", DashPunches = "DashPunchEnabled", HealthRegen = "HealthRegen", Knockdowns = "Knockdowns", Clashes = "Clashes" }
	-- (off until switched on: the prank, and the world events - round 75: the Nomu too)
	local optIn = { MufflerPrank = "MufflerPrank", SkyBattle = "SkyBattle", DekuDrop = "DekuDrop", NomuRaid = "NomuRaid" }
	local function flagOf(plr, id)
		local attr = PS_FLAGS[id]
		if not attr then
			return false
		end
		if attr:sub(1, 1) == "-" then
			return plr:GetAttribute(attr:sub(2)) ~= true
		end
		return plr:GetAttribute(attr) == true
	end
	HUD.BuildServerPanel(PS_SPEC, {
		get = function(id)
			if worldAttr[id] then
				return workspace:GetAttribute(worldAttr[id]) ~= false
			elseif optIn[id] then
				return workspace:GetAttribute(optIn[id]) == true
			elseif id == "Gravity" then
				return math.floor(workspace.Gravity * 10 + 0.5) / 10
			end
			return tonumber(workspace:GetAttribute(id)) or 1
		end,
		set = function(id, value)
			TestCommand:FireServer("PSSet", id, value)
		end,
		players = function()
			local list = {}
			for _, plr in Players:GetPlayers() do
				table.insert(list, { UserId = plr.UserId, Name = plr.DisplayName })
			end
			table.sort(list, function(a, b)
				return a.Name:lower() < b.Name:lower()
			end)
			return list
		end,
		playerFlag = function(id, userId)
			if userId ~= 0 then
				local plr = Players:GetPlayerByUserId(userId)
				return plr ~= nil and flagOf(plr, id)
			end
			for _, plr in Players:GetPlayers() do
				if not flagOf(plr, id) then
					return false
				end
			end
			return true
		end,
		player = function(id, userId)
			TestCommand:FireServer("PSPlayer", id, userId)
		end,
	})
	local function refresh()
		HUD.RefreshServerPanel()
	end
	for _, attr in { "DestructionEnabled", "MapRegen", "EvasiveEnabled", "DashPunchEnabled", "HealthRegen", "Knockdowns", "Clashes", "NomuRaid", "SkyBattle", "DekuDrop", "MufflerPrank", "DamageMult", "KnockbackMult", "SpeedMult", "JumpMult", "UltRate" } do
		workspace:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	workspace:GetPropertyChangedSignal("Gravity"):Connect(refresh)
	local function watch(plr)
		for _, attr in PS_FLAGS do
			plr:GetAttributeChangedSignal(attr:gsub("^%-", "")):Connect(refresh)
		end
	end
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(function(plr)
		watch(plr)
		refresh()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
end

-- FREE CAM (testers, Ctrl + P): the camera comes off you and flies on its
-- own - WASD to move, Q / E down and up, hold right-click to look around,
-- Shift for speed. Your character stands still meanwhile.
function FreeCam.toggle()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if FreeCam.on then
		FreeCam.on = false
		RunService:UnbindFromRenderStep("QuirkFreeCam")
		ContextActionService:UnbindAction("QuirkFreeCamSink")
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		local _, hum = getCharacter()
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
		HUD.Notice("Free cam off", Color3.fromRGB(150, 220, 255))
		return
	end
	FreeCam.on = true
	local look = cam.CFrame.LookVector
	local yaw, pitch = math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
	local pos = cam.CFrame.Position
	cam.CameraType = Enum.CameraType.Scriptable
	-- (the keys drive the camera, not you or your moves)
	local keys = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space }
	for _, list in { Config.AbilityKeys[1], Config.AbilityKeys[2], Config.AbilityKeys[3], Config.SpecialKeys, Config.UltKeys, Config.ExtraKeys, Config.FinisherKeys, Config.BlockKeys } do
		for _, k in list or {} do
			table.insert(keys, k)
		end
	end
	ContextActionService:BindActionAtPriority("QuirkFreeCamSink", function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(keys))
	RunService:BindToRenderStep("QuirkFreeCam", Enum.RenderPriority.Camera.Value + 10, function(dt)
		local look2 = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		UserInputService.MouseBehavior = look2 and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
		if look2 then
			local delta = UserInputService:GetMouseDelta()
			yaw -= delta.X * 0.004
			pitch = math.clamp(pitch - delta.Y * 0.004, -1.5, 1.5)
		end
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local move = Vector3.zero
		local function down(k)
			return UserInputService:IsKeyDown(k)
		end
		move += (down(Enum.KeyCode.W) and -1 or 0) * Vector3.zAxis + (down(Enum.KeyCode.S) and 1 or 0) * Vector3.zAxis
		move += (down(Enum.KeyCode.D) and 1 or 0) * Vector3.xAxis + (down(Enum.KeyCode.A) and -1 or 0) * Vector3.xAxis
		local lift = (down(Enum.KeyCode.E) and 1 or 0) - (down(Enum.KeyCode.Q) and 1 or 0)
		local speed = down(Enum.KeyCode.LeftShift) and 140 or 45
		pos += (rot:VectorToWorldSpace(move) + Vector3.yAxis * lift) * speed * dt
		cam.CFrame = CFrame.new(pos) * rot
	end)
	HUD.Notice("Free cam: WASD move, Q/E down/up, right-click look, Shift fast. Ctrl+P to leave", Color3.fromRGB(150, 220, 255))
end

-- FLIGHT (server settings, or N for testers): fly where you're looking -
-- move keys to go, Space to rise, sprint for speed
RunService.RenderStepped:Connect(function()
	local char, hum, root = getCharacter()
	local want = char ~= nil and player:GetAttribute("Flight") == true and not char:GetAttribute("Ragdolled")
		and not char:GetAttribute("Grabbed") and not root.Anchored and not DevFly.active -- (round 86: one flight at a time)
	local lv = FreeCam.flyLv
	if not want then
		if lv then
			FreeCam.flyLv = nil
			lv:Destroy()
			if FreeCam.flyAtt then
				FreeCam.flyAtt:Destroy()
			end
			if hum and hum.Parent then
				hum.PlatformStand = false
				hum.AutoRotate = true
			end
		end
		return
	end
	if not lv or not lv.Parent or lv.Parent ~= root then
		local att = Instance.new("Attachment")
		att.Name = "FlightAttachment"
		att.Parent = root
		lv = Instance.new("LinearVelocity")
		lv.Name = "Flight"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = math.max(root.AssemblyMass, 1) * 8000
		lv.Parent = root
		FreeCam.flyLv, FreeCam.flyAtt = lv, att
	end
	hum.PlatformStand = true
	hum.AutoRotate = false
	-- (a hit still moves you: the flight lets go while you're knocked back)
	lv.Enabled = root:FindFirstChild("Knockback") == nil and not FreeCam.on
	local cam = workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or root.CFrame.LookVector
	local right = cam and cam.CFrame.RightVector or root.CFrame.RightVector
	local md = hum.MoveDirection
	local flatLook = flat(look)
	flatLook = flatLook.Magnitude > 0.05 and flatLook.Unit or flat(root.CFrame.LookVector).Unit
	local flatRight = flat(right)
	flatRight = flatRight.Magnitude > 0.05 and flatRight.Unit or Vector3.zero
	local fwd, side = md:Dot(flatLook), md:Dot(flatRight)
	local v = look * fwd + right * side
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then
		v += Vector3.yAxis
	end
	local speed = (sprintHeld or sprintToggle) and 150 or 70
	lv.VectorVelocity = v.Magnitude > 0.05 and v.Unit * speed * math.min(v.Magnitude, 1) or Vector3.zero
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
	if os.clock() - (FreeCam.lastPose or 0) > 0.25 then
		FreeCam.lastPose = os.clock()
		VFX.Pose(char, v.Magnitude > 0.1 and "Skydive" or "FloatIdle", 0.35)
	end
end)

---------------------------------------------------------------------------
-- (round 87) THROUGH-THE-BUILDING KNOCKBACK (Config.Smash) on the thrown
-- player's own machine. It runs his body (it owns it), so it's here that a
-- wall in his way is met: the server tags a throw hard enough on its push
-- (the Knockback mover carries Smash = Splat / Through, SmashId and
-- SmashWalls), and every frame before the physics (Stepped) the way ahead
-- is looked down. A breakable wall met fast enough goes: opened on this
-- screen at once (and drawn with a body-sized hole in it till the server's
-- real hole lands, so the camera follows him through a hole, not a wall),
-- a hit-stop on it, some of his speed gone, the server told (it checks it
-- and carves the hole for everyone). Slower - or out of walls, or too thick,
-- or with the edge of the city past it - he's splatted on it: spread on the
-- wall, held there a moment, then he drops. A wall opened here that nobody
-- carved closes again once he's out of it. Nothing for anyone else's body,
-- nor for a throw the server didn't tag.
---------------------------------------------------------------------------
do
	local SMC = Config.Smash or {}
	local SK = Config.SmashKit
	-- cur: this body's throw; walls: [part] = { at = when opened, ghosts = its stand-ins }
	local SC = { cur = nil, lastId = nil, walls = {} }
	VFX.SmashClient = SC -- (the tests read it)

	-- the map only, what really stops a body
	function SC.params()
		local p = RaycastParams.new()
		local map = workspace:FindFirstChild("Map")
		if map then
			p.FilterType = Enum.RaycastFilterType.Include
			p.FilterDescendantsInstances = { map }
		else
			p.FilterType = Enum.RaycastFilterType.Exclude
			p.FilterDescendantsInstances = { player.Character, VFX.Folder }
		end
		pcall(function()
			p.RespectCanCollide = true
		end)
		return p
	end
	-- ((round 87 review) the sphere, then a ray if it sees nothing: a shape
	-- cast never sees a part it starts inside - him pressed to a wall as he's hit)
	function SC.cast(origin, vec, radius)
		SC.rp = SC.rp or SC.params()
		if radius then
			local ok, hit = pcall(function()
				return workspace:Spherecast(origin, radius, vec, SC.rp)
			end)
			if ok and hit then
				return hit
			end
		end
		return workspace:Raycast(origin, vec, SC.rp)
	end
	function SC.send(kind, data)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, data)
	end

	-- a tagged throw starts
	function SC.start(char, root, lv)
		SC.lastId = lv:GetAttribute("SmashId")
		SC.rp = SC.params()
		local tier = lv:GetAttribute("Smash")
		local cur = {
			char = char, root = root, id = SC.lastId, tier = tier, walls = 0, t0 = os.clock(),
			max = tier == "Through" and math.clamp(tonumber(lv:GetAttribute("SmashWalls")) or 0, 0, (SMC.Through or {}).MaxWalls or 4) or 0,
			limp = char:GetAttribute("Ragdolled") == true,
		}
		SC.cur = cur
		return cur
	end
	-- it's over (whatever's holding the body lets go; the walls it opened
	-- close by themselves)
	function SC.stop(_reason)
		local cur = SC.cur
		SC.cur = nil
		if cur then
			cur.over = true
			cur.holding = false
			if cur.held then
				SK.unhold(cur.held)
				cur.held = nil
			end
		end
	end
	-- something else has his body now (a grab, a finisher, ice, a stopped
	-- world, a marble, a cutscene's anchor - or he's getting up)
	function SC.taken(char, root, cur)
		if char:GetAttribute("Grabbed") or char:GetAttribute("BeingFinished") or char:GetAttribute("Frozen")
			or char:GetAttribute("TimeStopped") or char:GetAttribute("Compressed") or root:FindFirstChild("FinisherLaunch") ~= nil then
			return true
		end
		return root.Anchored or (cur.limp and char:GetAttribute("Ragdolled") ~= true)
	end

	function SC.step(_, dt)
		dt = math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 0.1)
		if next(SC.walls) then
			SC.closeWalls(false)
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local cur = SC.cur
		if cur and (cur.char ~= char or not root) then
			SC.stop("Gone")
			cur = nil
		end
		if not root or not SK or SMC.Enabled == false then
			return
		end
		-- a new push: a throw the server tagged starts (one it didn't ends this one)
		local lv = root:FindFirstChild("Knockback")
		local id = lv and lv:GetAttribute("SmashId")
		if lv and id ~= (cur and cur.id) and (id == nil or id ~= SC.lastId) then
			if cur then
				SC.stop("Replaced")
				cur = nil
			end
			if id ~= nil then
				cur = SC.start(char, root, lv)
			end
		end
		if not cur then
			return
		end
		if cur.holding then
			if cur.splat and SC.taken(char, root, cur) then
				SC.stop("Taken")
			end
			return
		end
		local now = os.clock()
		if now - cur.t0 > SMC.MaxTime or SC.taken(char, root, cur) then
			SC.stop("Over")
			return
		end
		local v = root.AssemblyLinearVelocity
		if v.Magnitude < SMC.EndSpeed and now - cur.t0 > SMC.MinTime then
			cur.slowAt = cur.slowAt or now
			if now - cur.slowAt >= SMC.SlowFor then
				SC.stop("Over")
				return
			end
		else
			cur.slowAt = nil
		end
		if cur.pending then
			SC.arrive(cur, root, v, dt, now)
			return
		end
		-- the way ahead (across: walls stand up)
		local across = Vector3.new(v.X, 0, v.Z)
		if across.Magnitude < SMC.Splat.Speed then
			return
		end
		local P = SMC.Probe
		local hit = SC.cast(root.Position, across.Unit * (across.Magnitude * dt * P.Ahead + P.Extra), P.Radius)
		local plan = hit and SK.plan(hit, v, cur.walls, cur.max, SC.cast, SK.scale(char))
		if plan then
			-- (seen a moment ahead: the wall's opened now, so nothing stops him
			-- on it; what happens on it happens as he gets there)
			if plan.Kind == "Through" then
				SC.open(cur, plan)
			end
			plan.Until = now + SMC.Arrive
			cur.pending = plan
			SC.arrive(cur, root, v, dt, now)
		end
	end
	-- the wall seen ahead: once he's at it (this frame would take him onto
	-- it), through it or splatted on it; gone past the time to get there
	-- (knocked aside), it's off
	function SC.arrive(cur, root, v, dt, now)
		local plan = cur.pending
		local gap = (root.Position - plan.Pos):Dot(plan.Normal)
		local into = math.max(-v:Dot(plan.Normal), 0)
		if gap - into * dt <= SMC.Contact then
			cur.pending = nil
			if plan.Kind == "Through" then
				SC.through(cur, plan)
			else
				SC.splat(cur, plan)
			end
		elseif now > plan.Until then
			cur.pending = nil
		end
	end

	-- THROUGH IT (he's at the wall, opened here already): held on it a
	-- moment, on through it slower; the server told, the burst played here now
	function SC.through(cur, plan)
		cur.walls += 1
		local T = SMC.Through
		local root = cur.root
		local v = root.AssemblyLinearVelocity
		local pushes = SK.pushes(root)
		SK.advance(cur.char, root, plan)
		cur.held = SK.hold(cur.char)
		cur.holding = true
		task.delay(T.HitStop, function()
			SK.unhold(cur.held)
			cur.held = nil
			local mine = SC.cur == cur
			cur.holding = false
			SK.resume(cur.char, pushes, mine and v * (1 - T.Loss) or nil, mine and 1 - T.Loss or 1)
		end)
		local part = plan.Part
		local glass = part.Material == Enum.Material.Glass or part.Transparency > 0.2
		SC.send("SmashThrough", { Id = cur.id, A = plan.A, B = plan.B, R = plan.R, Into = plan.Into, Color = part.Color, Glass = glass or nil })
		VFX.Play("Smash", cur.char, {
			Kind = "Through", A = plan.A, B = plan.B, Dir = plan.Dir, R = plan.R, N = cur.walls, Into = plan.Into, Color = part.Color, Glass = glass or nil,
		}, true)
	end

	-- SPLAT: spread on the wall (his back to it), held there, then dropped
	-- off it; the server told, the crater played here now
	function SC.splat(cur, plan)
		cur.splat = true
		local SP = SMC.Splat
		local char, root = cur.char, cur.root
		SK.pushes(root, true)
		for _, pc in SK.splay(char, SK.wallCF(plan.Pos, plan.Normal, math.random(-SP.Tilt, SP.Tilt), SK.scale(char))) do
			pc[1].CFrame = pc[2]
		end
		cur.held = SK.hold(char, true) -- ((round 87 review) his joint limits let go while he's spread)
		cur.holding = true
		local part = plan.Part
		SC.send("SmashSplat", { Id = cur.id, Pos = plan.Pos, Normal = plan.Normal, Depth = plan.Depth, Into = plan.Into, Color = part.Color })
		VFX.Play("Smash", char, { Kind = "Splat", Pos = plan.Pos, Normal = plan.Normal, Into = plan.Into, Color = part.Color, Hold = SP.Hold, N = cur.walls }, true)
		task.delay(SP.Hold, function()
			if SC.cur == cur and cur.held then
				SK.unhold(cur.held)
				cur.held = nil
				cur.holding = false
				SK.drop(char, plan.Normal)
				SC.stop("Splat")
			end
		end)
	end

	-- the breakable parts in the hole's way, opened on this screen (never
	-- the floor under him or the street at the wall's foot), each drawn
	-- with its hole in it
	function SC.open(cur, plan)
		local a, b, r = plan.A, plan.B, plan.R
		local len = math.max((b - a).Magnitude, 0.5)
		local g = SC.cast(a + Vector3.yAxis, Vector3.new(0, -14, 0))
		local under = SC.cast(cur.root.Position, Vector3.new(0, -60, 0))
		local above = SK.floorAbove(g, a.Y)
		local floor0, floor1 = g and g.Instance, under and under.Instance
		local now = os.clock()
		local function take(part)
			if SK.breakable(part) and part.CanCollide and not SC.walls[part] and part ~= floor0 and part ~= floor1 and SK.top(part) > above
				and not SK.isFloor(part, a.Y) then
				part.CanCollide = false
				SC.walls[part] = { at = now, ghosts = SC.cutout(part, plan) }
			end
		end
		take(plan.Part)
		local params = OverlapParams.new()
		local map = workspace:FindFirstChild("Map")
		if map then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { map }
		end
		local mid = (a + b) / 2
		for _, part in workspace:GetPartBoundsInBox(CFrame.lookAt(mid, b), Vector3.new(r * 2, r * 2, len), params) do
			if part:IsA("BasePart") then
				take(part)
			end
		end
	end

	-- a part with the hole in it, on this screen: the part itself hidden and
	-- up to four stand-ins round a square hole where his path crosses it
	-- (inside the server's round one, which replaces it). Solid to the
	-- camera, nothing to anyone (Config.Smash.Ghost). A part he's going
	-- along rather than through - or not a block - is just hidden
	function SC.cutout(part, plan)
		local ghosts = {}
		pcall(function()
			part.LocalTransparencyModifier = 1
		end)
		local okShape, shape = pcall(function()
			return part.Shape
		end)
		if okShape and shape ~= Enum.PartType.Block then
			return ghosts
		end
		local cf, s = part.CFrame, part.Size
		local dl = cf:VectorToObjectSpace(plan.Dir)
		local axes = { "X", "Y", "Z" }
		table.sort(axes, function(p, q)
			return math.abs(dl[p]) > math.abs(dl[q])
		end)
		local k, i, j = axes[1], axes[2], axes[3]
		-- ((round 87 review) through a wall: its thin side, even hit at a slant
		-- (the way he's most going can be along a long wall: the "hole" would
		-- be a slot the wall's whole length))
		local thin = (s.X <= s.Y and s.X <= s.Z) and "X" or (s.Y <= s.Z and "Y" or "Z")
		if thin ~= k and math.abs(dl[thin]) >= 0.3 then
			local rest = {}
			for _, a in axes do
				if a ~= thin then
					table.insert(rest, a)
				end
			end
			k, i, j = thin, rest[1], rest[2]
		end
		if math.abs(dl[k]) < 0.25 then
			return ghosts
		end
		local p0 = cf:PointToObjectSpace(plan.A)
		local c = p0 + dl * (-p0[k] / dl[k]) -- (where his path crosses the part's middle)
		local hs = plan.R * SMC.Through.Cutout
		local hi, hj = s[i] / 2, s[j] / 2
		local i0, i1 = math.clamp(c[i] - hs, -hi, hi), math.clamp(c[i] + hs, -hi, hi)
		local j0, j1 = math.clamp(c[j] - hs, -hj, hj), math.clamp(c[j] + hs, -hj, hj)
		local function box(a0, a1, b0, b1)
			if a1 - a0 < 0.05 or b1 - b0 < 0.05 then
				return
			end
			local size, at = { X = 0, Y = 0, Z = 0 }, { X = 0, Y = 0, Z = 0 }
			size[i], size[j], size[k] = a1 - a0, b1 - b0, s[k]
			at[i], at[j] = (a0 + a1) / 2, (b0 + b1) / 2
			local gh = Instance.new("Part")
			gh.Name = "SmashGhost"
			gh.Anchored = true
			gh.CanTouch = false
			gh.CastShadow = part.CastShadow
			gh.Color = part.Color
			gh.Material = part.Material
			gh.Transparency = part.Transparency
			gh.Reflectance = part.Reflectance
			gh.TopSurface = Enum.SurfaceType.Smooth
			gh.BottomSurface = Enum.SurfaceType.Smooth
			gh.Size = Vector3.new(size.X, size.Y, size.Z)
			gh.CFrame = cf * CFrame.new(at.X, at.Y, at.Z)
			local grouped = pcall(function()
				gh.CollisionGroup = SMC.Ghost
			end)
			gh.CanCollide = grouped
			gh.Parent = VFX.Folder
			table.insert(ghosts, gh)
		end
		box(-hi, i0, -hj, hj)
		box(i1, hi, -hj, hj)
		box(i0, i1, -hj, j0)
		box(i0, i1, j1, hj)
		return ghosts
	end

	-- is his body in (or right by) this part?
	function SC.inside(part, root)
		if not (root and root.Parent) then
			return false
		end
		local rel = part.CFrame:PointToObjectSpace(root.Position)
		local h = part.Size / 2 + Vector3.one * 3
		return math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z
	end
	-- walls opened here: gone with their stand-ins once the server's hole
	-- replaces them; closed again (Reopen s on) if it never did, once he's out
	function SC.closeWalls(all)
		local now = os.clock()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		for part, rec in SC.walls do
			local carved = not part:IsDescendantOf(workspace)
			if all or carved or (now - rec.at >= SMC.Reopen and not SC.inside(part, root)) then
				SC.walls[part] = nil
				for _, gh in rec.ghosts do
					gh:Destroy()
				end
				pcall(function()
					part.LocalTransparencyModifier = 0
				end)
				part.CanCollide = true
			end
		end
	end

	RunService.Stepped:Connect(SC.step)
	player.CharacterAdded:Connect(function()
		SC.stop("Gone")
		SC.closeWalls(true)
	end)
end

---------------------------------------------------------------------------
-- (round 87) ADMIN-ABUSE EVENTS (Config.AdminEvents; the server's Kit.AE).
-- What's running is one workspace attribute (Config.AdminEventsRunning),
-- and every screen follows it: an event starting is the ADMIN ABUSE banner
-- and its sting (with an ult theme ducked under it; someone who joins
-- mid-event gets a line instead), the event's music (one track at a time -
-- the newest event's - faded in and out, under an ult theme while one
-- plays, muted by the MUSIC button with the rest), a countdown chip each
-- (the last Ticks seconds tick), the sky and the world's loops (VFX.AE.set),
-- EVENT OVER as it ends. HERO SHUFFLE's slot machine comes from the server
-- (AdminShuffle). And the devs' ADMIN EVENTS panel: its row in the test
-- menu's Dev only group shows only to those the server marks DevFlyer (as
-- DEV FLIGHT's), and every START / STOP is a TestCommand the server checks.
---------------------------------------------------------------------------
do
	local AEC = Config.AdminEvents or {}
	local EV = { seen = nil, ticked = {}, want = nil, level = 0 }
	VFX.AEClient = EV -- (tests)
	local function def(id)
		return AEC.Events and AEC.Events[id] or nil
	end
	local function clock(s)
		s = math.max(0, math.ceil((tonumber(s) or 0) - 0.05))
		return string.format("%d:%02d", s // 60, s % 60)
	end
	-- what's running, in Order
	function EV.list(map)
		local out = {}
		for _, id in AEC.Order or {} do
			local e = map[id]
			if e and def(id) then
				table.insert(out, { Id = id, Ends = e.Ends, Length = e.Length, Global = e.Global, By = e.By })
			end
		end
		return out
	end
	-- one starting: the banner (its sting as it comes up), the ult theme ducked under it
	function EV.announce(e)
		local d = def(e.Id)
		HUD.EventBanner({
			Id = e.Id, Name = d.Name, Icon = d.Icon, Color = d.Color, Blurb = d.Blurb, Length = e.Length, Global = e.Global, By = e.By,
			OnShow = function()
				VFX.PlaySound("AdminEventStart")
				if e.Id == "LowGravity" then
					VFX.PlaySound("AdminGravity")
				end
				if VFX.Hooks.DuckMusic then
					VFX.Hooks.DuckMusic(0.25, 0.15, 3.4, 2)
				end
			end,
			Still = function()
				return Config.AdminEventsRunning()[e.Id] ~= nil
			end,
		})
	end
	-- the music: the newest running event's track
	function EV.pick(list)
		local best, bestAt = nil, -math.huge
		for _, e in list do
			local m = def(e.Id).Music
			local started = e.Ends - e.Length
			if type(m) == "table" and type(m.Id) == "string" and started > bestAt then
				best, bestAt = { Id = e.Id, Spec = m }, started
			end
		end
		return best
	end
	function EV.track()
		if EV.sound and EV.sound.Parent then
			return EV.sound
		end
		local SoundService = game:GetService("SoundService")
		local group = SoundService:FindFirstChild("QuirkMusic") or Instance.new("SoundGroup")
		group.Name = "QuirkMusic"
		group.Parent = SoundService
		local s = Instance.new("Sound")
		s.Name = "AdminEventMusic"
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = group
		s.Parent = group
		EV.sound = s
		return s
	end
	-- ten times a second while anything runs (or its music fades): the
	-- music's level, the chips' last seconds ticking
	function EV.loop()
		if EV.looping then
			return
		end
		EV.looping = true
		task.spawn(function()
			while EV.want or EV.playing or next(Config.AdminEventsRunning()) ~= nil do
				local dt = task.wait(0.1) or 0.1
				local M = AEC.Music or {}
				local s = EV.track()
				local want = EV.want
				-- (a different track: once the old one's faded)
				if want and EV.playing ~= want.Spec.Id and EV.level <= 0.01 then
					EV.playing = want.Spec.Id
					s:Stop()
					s.SoundId = want.Spec.Id
					s.TimePosition = want.Spec.Start or 0
					s:Play()
					local spec = want.Spec
					task.spawn(function()
						pcall(function()
							if not s.IsLoaded then
								s.Loaded:Wait()
							end
							if EV.playing == spec.Id and s.TimePosition < (spec.Start or 0) - 0.5 then
								s.TimePosition = spec.Start or 0 -- (it was still loading: in at its drop once it can)
							end
						end)
					end)
				end
				local peak = want and (tonumber(want.Spec.Volume) or 0.4) * (M.Volume or 1) * ((Config.Audio and Config.Audio.MusicVolume) or 1) or 0
				EV.peak = want and peak or EV.peak -- (the last one's level sets how fast it fades out)
				-- (under someone's ult theme)
				local ult, _, ultLevel = nil, nil, 0
				if VFX.Hooks.MusicState then
					ult, _, ultLevel = VFX.Hooks.MusicState()
				end
				local duck = (ult and (ultLevel or 0) > 0.02) and (M.UnderUlt or 0.22) or 1
				local target = (want and EV.playing == want.Spec.Id and HUD.GetSetting("Music") ~= false) and peak * duck or 0
				local rate = math.max(peak, EV.peak or 0, 0.05) / (target > EV.level and (M.FadeIn or 1.2) or (M.FadeOut or 2.4)) * dt
				EV.level = target > EV.level and math.min(target, EV.level + rate) or math.max(target, EV.level - rate)
				s.Volume = EV.level
				if not want and EV.playing and EV.level <= 0 then
					s:Stop()
					EV.playing = nil
				end
				-- the last seconds tick
				local now = workspace:GetServerTimeNow()
				for id, e in Config.AdminEventsRunning() do
					local whole = math.ceil(e.Ends - now - 0.05)
					if whole >= 1 and whole <= (AEC.Ticks or 5) and EV.ticked[id] ~= whole then
						EV.ticked[id] = whole
						VFX.PlaySound("AdminEventTick")
					end
				end
			end
			EV.looping = false
		end)
	end
	-- what's running changed (here, or on another server): the beats, the chips, the sky, the music
	function EV.changed()
		local raw = workspace:GetAttribute(AEC.Attribute or "AdminEvents")
		local map = Config.AdminEventsRunning()
		local list = EV.list(map)
		local ids = {}
		for _, e in list do
			table.insert(ids, e.Id)
		end
		local before = EV.seen
		-- (nothing from the server yet: what comes first isn't news)
		EV.seen = raw ~= nil and map or nil
		if before then
			for _, e in list do
				local b = before[e.Id]
				if not b then
					EV.announce(e)
				elseif math.abs((b.Ends or 0) - e.Ends) > 1 then
					HUD.Notice(string.format("%s %s: %s left", def(e.Id).Icon or "", def(e.Id).Name, clock(e.Ends - workspace:GetServerTimeNow())), def(e.Id).Color:Lerp(Color3.new(1, 1, 1), 0.4))
				end
			end
			local over = {}
			for _, id in AEC.Order or {} do
				if before[id] and not map[id] then
					local d = def(id)
					table.insert(over, { Name = d.Name, Color = d.Color, Icon = d.Icon })
					EV.ticked[id] = nil
				end
			end
			if #over > 0 then
				HUD.EventOver(over)
				VFX.PlaySound("AdminEventOver")
			end
		elseif raw ~= nil and #list > 0 then
			-- (joined mid-event: a line, not a banner)
			local names = {}
			for _, e in list do
				table.insert(names, string.format("%s %s (%s left)", def(e.Id).Icon or "", def(e.Id).Name, clock(e.Ends - workspace:GetServerTimeNow())))
			end
			HUD.Notice("ADMIN EVENT ON: " .. table.concat(names, "  ·  "), Color3.fromRGB(255, 212, 64))
		end
		HUD.SetEventChips(list)
		VFX.AE.set(ids)
		EV.want = EV.pick(list)
		if #list > 0 or EV.playing then
			EV.loop()
		end
		HUD.RefreshEventsPanel()
	end
	workspace:GetAttributeChangedSignal(AEC.Attribute or "AdminEvents"):Connect(EV.changed)
	workspace:GetAttributeChangedSignal("AdminEventsSync"):Connect(HUD.RefreshEventsPanel)
	-- MONEY RAIN: your bills on its chip (and when that's all you can take)
	player:GetAttributeChangedSignal("EventBills"):Connect(function()
		local got = player:GetAttribute("EventBills")
		local cap = (def("MoneyRain") or {}).Cap or 8
		HUD.SetEventChipNote("MoneyRain", got and string.format("YOUR BUCKS  %d / %d", got, cap) or nil)
		if got and got >= cap then
			HUD.Notice(string.format("MONEY RAIN: that's all you can grab (%d)", cap), Color3.fromRGB(150, 255, 160))
		end
	end)
	-- HERO SHUFFLE: your hero's being dealt (the server switches you as it lands)
	UI_EVENTS.AdminShuffle = function(data)
		local pool = {}
		for _, q in Config.QuirkOrder do
			if Config.Quirks[q] and not Config.IsDevOnly(q) then
				table.insert(pool, q)
			end
		end
		task.spawn(HUD.ShuffleReel, data.Hero, data.Spin, {
			Pool = pool,
			Still = function()
				return Config.AdminEventsRunning().Shuffle ~= nil
			end,
			OnTick = function()
				VFX.PlaySound("AdminReelTick")
			end,
			OnLand = function()
				VFX.PlaySound("AdminReelLand")
			end,
		})
	end
	EV.changed()

	-- the panel (testers; the server checks every request: Kit.AE.allowed)
	table.insert(TEST_ITEMS, { Id = "AdminEventsPanel", Label = "ADMIN EVENTS...", Group = "Dev only" })
	function EV.allowed()
		if DevFly.allowed then
			return DevFly.allowed() -- (DEV FLIGHT's rule: the server's DevFlyer)
		end
		return player:GetAttribute("DevFlyer") == true
	end
	function EV.menu()
		HUD.ShowTestRow("AdminEventsPanel", EV.allowed())
		HUD.SetTestInfo("AdminEventsPanel", "ADMIN EVENTS", {
			"Server-wide events everyone plays  -  devs only",
			"<b>START</b> on a card, <b>STOP</b> while it runs",
			"<b>THIS SERVER</b> | <b>ALL SERVERS</b> (every running server)",
			"<b>AUTO</b>: each event's own length, or 1 to 5 min",
			"Console: <b>event meteor 2m all</b>  ·  <b>event stop all</b>",
			"GIANT ends TINY (and back)  ·  4 at once at most",
		})
		if not EV.allowed() then
			HUD.ToggleEventsPanel(false)
		end
	end
	local function setup()
		if not EV.panel and player:GetAttribute("Tester") then
			EV.panel = true
			HUD.BuildEventsPanel({
				Start = function(id, seconds, all)
					VFX.PlaySound("RosterToggle")
					TestCommand:FireServer("AdminEvent", "start", { Id = id, Seconds = seconds, All = all == true })
				end,
				Stop = function(id, all)
					VFX.PlaySound("RosterToggle")
					TestCommand:FireServer("AdminEvent", "stop", { Id = id, All = all == true })
				end,
				Tick = function()
					VFX.PlaySound("RosterToggle")
				end,
			})
		end
		task.defer(EV.menu) -- (after the test menu's built)
	end
	player:GetAttributeChangedSignal("Tester"):Connect(setup)
	player:GetAttributeChangedSignal("DevFlyer"):Connect(function()
		task.defer(EV.menu)
	end)
	setup()
end

---------------------------------------------------------------------------
-- (round 87) THE DIRECTOR CAMERA (Config.Director): a free camera for
-- trailers, TikToks and thumbnails - for the owner and the Devs (the dev
-- flight's gate: the server marks them DevFlyer). All of it happens on this
-- screen: it sends the server nothing, and nobody else sees anything
-- different. J (or the test menu's DIRECTOR CAM) takes the camera off your
-- body - which stands where it is, doing nothing (Roblox's controls off,
-- the game's keys taken) - and gives everything back after, exactly.
-- The shots: FREE (flown, with smooth acceleration and damping), ORBIT round
-- a target, TRACK (where you put it, turning after the target a beat
-- behind, like a camera operator), FOLLOW (a chase cam on a spring), the
-- DOLLY (a smooth move through keys you drop: a centripetal Catmull-Rom path
-- at an even speed, eased in and out, the look, zoom and roll riding it).
-- Each shot starts from where the camera is, so switching never jumps. The
-- lens: zoom, the dutch roll, focus (depth of field), colour grades, the
-- shake. The clean frame: the HUD, Roblox's UI and chat, name tags and your
-- own body off the screen; a letterbox or a 9:16 frame; the thirds; its
-- own overlay hides with one key. Time: slow motion and the freeze frame
-- (what slows and what can't: VFX.Director). The game's cutscenes don't
-- take the camera while it's on (0 lets the target's own through).
-- (busy(), the mouse's M1 and the test menu's keys stand down while it's
-- on: FreeCam.directing)
---------------------------------------------------------------------------
do
	local DIR = Config.Director or {}
	local K = DIR.Keys or {}
	local PADK = DIR.Pad or {}
	local D = {
		on = false, bound = false, mode = "FREE", target = nil, keys = {}, loop = false, dollyRun = nil, pathVersion = 0,
		speed = (DIR.Fly or {}).Speed or 24, orbitSpeed = (DIR.Orbit or {}).Speed or 18, followSpring = (DIR.Follow or {}).Spring or 4,
		dollyTime = (DIR.Dolly or {}).Time or 6, smooth = 1, shakeMode = (DIR.Shake or {}).Mode or 2, grade = 0,
		focus = false, cuts = false, frame = 1, grid = false, overlay = true, hideBody = true, slow = 1, frozen = false, scale = 1,
		pos = Vector3.zero, vel = Vector3.zero, rot = CFrame.new(), yaw = 0, pitch = 0, yawT = 0, pitchT = 0,
		fov = 70, fovT = 70, roll = 0, rollT = 0, cOff = Vector3.zero, trackOff = Vector2.new(0, 0), orbit = {}, follow = {},
		rmb = false, latch = false, conns = {}, ACT = {}, KEEP = {}, KEEPBB = {},
	}
	FreeCam.Director = D
	VFX.DirectorCam = D -- (the tests read it through this)
	for _, name in DIR.KeepGuis or {} do
		D.KEEP[name] = true
	end
	for _, name in DIR.KeepBillboards or {} do
		D.KEEPBB[name] = true
	end

	function D.allowed()
		return DIR.Enabled ~= false and player:GetAttribute("DevFlyer") == true
	end
	-- its own sounds and words: only while its overlay's up (never in a recording)
	function D.sound(name)
		if D.on and D.overlay and DIR.Sounds ~= false then
			VFX.PlaySound(name, nil, 1)
		end
	end
	function D.toast(text, color)
		if D.on then
			HUD.DirectorToast(text, color)
		end
	end

	---------------------------------------------------------------------------
	-- the maths: angles, a spring, the ease, the dolly's curves
	---------------------------------------------------------------------------
	function D.wrap(a)
		return (a + math.pi) % (2 * math.pi) - math.pi
	end
	-- a critically damped spring, solved exactly over dt (steady at any frame rate)
	function D.spring(x, v, target, w, dt)
		local d = x - target
		local e = math.exp(-w * dt)
		local c = v + d * w
		return target + (d + c * dt) * e, (v - c * (w * dt)) * e
	end
	-- smootherstep: eased in and out, no jolt at either end
	function D.ease(u)
		u = math.clamp(u, 0, 1)
		return u * u * u * (u * (u * 6 - 15) + 10)
	end
	-- a uniform Catmull-Rom through v1..v2 (v0, v3 the neighbours)
	function D.cr(v0, v1, v2, v3, t)
		local t2 = t * t
		return 0.5 * (2 * v1 + (v2 - v0) * t + (2 * v0 - 5 * v1 + 4 * v2 - v3) * t2 + (3 * v1 - v0 - 3 * v2 + v3) * t2 * t)
	end
	-- a centripetal Catmull-Rom between P[i] and P[i+1] (no loops or cusps
	-- however unevenly the keys are spaced; the ends mirror their neighbour)
	function D.crPos(P, i, t)
		local p1, p2 = P[i], P[i + 1]
		local p0 = P[i - 1] or (p1 * 2 - p2)
		local p3 = P[i + 2] or (p2 * 2 - p1)
		local function knot(a, b)
			return math.max(math.sqrt((b - a).Magnitude), 1e-4)
		end
		local t1 = knot(p0, p1)
		local t2 = t1 + knot(p1, p2)
		local t3 = t2 + knot(p2, p3)
		local u = t1 + (t2 - t1) * t
		local a1 = p0 * ((t1 - u) / t1) + p1 * (u / t1)
		local a2 = p1 * ((t2 - u) / (t2 - t1)) + p2 * ((u - t1) / (t2 - t1))
		local a3 = p2 * ((t3 - u) / (t3 - t2)) + p3 * ((u - t2) / (t3 - t2))
		local b1 = a1 * ((t2 - u) / t2) + a2 * (u / t2)
		local b2 = a2 * ((t3 - u) / (t3 - t1)) + a3 * ((u - t1) / (t3 - t1))
		return b1 * ((t2 - u) / (t2 - t1)) + b2 * ((u - t1) / (t2 - t1))
	end

	---------------------------------------------------------------------------
	-- the target
	---------------------------------------------------------------------------
	function D.rootOf(m)
		return m and m.Parent and m:FindFirstChild("HumanoidRootPart") or nil
	end
	function D.targetModel()
		local t = D.target
		if not t then
			return nil
		end
		if t.player and t.player.Parent then
			local c = t.player.Character
			if c and c.Parent and c ~= t.model then
				t.model = c -- (they respawned: the shot stays on them)
			end
		end
		return (t.model and t.model.Parent) and t.model or nil
	end
	-- the point a shot is on: over its root (its still copy's, in a freeze frame)
	function D.targetPoint()
		local m = D.targetModel()
		if not m then
			return nil
		end
		local root = D.rootOf(VFX.Director.stillOf(m)) or D.rootOf(m)
		if not root then
			return nil
		end
		return root.Position + Vector3.new(0, (DIR.Target or {}).AimY or 1.5, 0), root
	end
	function D.setTarget(m, quiet)
		if not m then
			D.target = nil
			return
		end
		local plr = Players:GetPlayerFromCharacter(m)
		local old = D.lastCenter
		D.target = { model = m, player = plr, name = plr and plr.DisplayName or m.Name }
		local p = D.targetPoint()
		-- (from the last one to this one, eased: the shot glides over)
		D.cOff = (old and p) and (old - p) or Vector3.zero
		D.lostAt = nil
		if D.mode == "FOLLOW" then
			D.followHeading()
		end
		if not quiet then
			D.toast("TARGET  ·  " .. string.upper(D.target.name))
			D.sound("DirectorTick")
		end
	end
	-- everyone a shot can be on, nearest the camera first (your own body last)
	function D.targets()
		local cam = workspace.CurrentCamera
		local from = cam and cam.CFrame.Position or Vector3.zero
		local mine = player.Character
		local list, dist = {}, {}
		for _, m in VFX.Director.bodies() do
			if m ~= mine then
				table.insert(list, m)
				dist[m] = (D.rootOf(m).Position - from).Magnitude
			end
		end
		table.sort(list, function(a, b)
			return dist[a] < dist[b]
		end)
		if D.rootOf(mine) then
			table.insert(list, mine)
		end
		return list
	end
	function D.cycle(dir)
		local list = D.targets()
		if #list == 0 then
			D.toast("NOBODY TO FILM")
			D.sound("DirectorNo")
			return
		end
		local i = table.find(list, D.targetModel())
		if i then
			i = (i - 1 + dir) % #list + 1
		else
			i = dir > 0 and 1 or #list
		end
		D.setTarget(list[i])
	end
	-- the body nearest a ray (a click, the middle of the frame) within maxAngle degrees
	function D.nearestTo(ray, maxAngle)
		local best, bestAng = nil, math.rad(maxAngle)
		for _, m in D.targets() do
			local root = D.rootOf(m)
			for _, p in root and { root.Position, root.Position + Vector3.new(0, 1.5, 0) } or {} do
				local v = p - ray.Origin
				local dist = v.Magnitude
				if dist > 0.5 then
					-- (a body's a couple of studs wide: more lenient up close)
					local ang = math.acos(math.clamp(v.Unit:Dot(ray.Direction.Unit), -1, 1)) - math.atan(2 / dist)
					if ang < bestAng then
						best, bestAng = m, ang
					end
				end
			end
		end
		return best
	end
	function D.click()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local at = UserInputService:GetMouseLocation()
		-- (a click on the overlay's own buttons is theirs - asked with and
		-- without the top bar's inset: the overlay ignores it, the query may not)
		local onButton = false
		pcall(function()
			local inset = GuiService:GetGuiInset()
			local pg = player:FindFirstChildOfClass("PlayerGui")
			for _, p in { at, at - inset } do
				for _, g in pg:GetGuiObjectsAtPosition(p.X, p.Y) do
					if g:IsA("GuiButton") and g:FindFirstAncestor("DirectorOverlay") then
						onButton = true
					end
				end
			end
		end)
		if onButton then
			return
		end
		local m = D.nearestTo(cam:ViewportPointToRay(at.X, at.Y), (DIR.Target or {}).PickAngle or 7)
		if m then
			D.setTarget(m)
		else
			D.toast("NO BODY THERE")
			D.sound("DirectorNo")
		end
	end
	-- where a shot is aimed this frame: the target (eased over from the last
	-- one); lost, it holds a moment, then the shot lets go
	function D.center(dt)
		local p, root = D.targetPoint()
		if not p then
			if D.target and D.lastCenter then
				D.lostAt = D.lostAt or os.clock()
				if os.clock() - D.lostAt <= ((DIR.Target or {}).Lost or 1.5) then
					return D.lastCenter, nil
				end
				D.setTarget(nil)
				D.toast("TARGET LOST")
				D.sound("DirectorNo")
			end
			return nil
		end
		D.lostAt = nil
		D.cOff *= math.exp(-((DIR.Target or {}).Retarget or 4) * dt)
		D.lastCenter = p + D.cOff
		return D.lastCenter, root
	end
	-- kept out of walls: pulled in short of the first solid, seen thing
	-- between the target and the camera (like Roblox's own camera)
	function D.avoid(from, to)
		local dir = to - from
		if dir.Magnitude < 0.5 or not D.rayParams then
			return to
		end
		local hit = workspace:Raycast(from, dir, D.rayParams)
		local part = hit and hit.Instance
		if part and not (part:IsA("BasePart") and part.Transparency > 0.5) then
			local d = math.max((hit.Position - from).Magnitude - 0.8, 1.5)
			return from + dir.Unit * math.min(d, dir.Magnitude)
		end
		return to
	end

	---------------------------------------------------------------------------
	-- the shots
	---------------------------------------------------------------------------
	-- the camera's own state from where it is now (every shot starts there)
	function D.sync()
		local cam = workspace.CurrentCamera
		local cf = D.base or (cam and cam.CFrame) or CFrame.new()
		local look = cf.LookVector
		D.pos = cf.Position
		D.yaw = math.atan2(-look.X, -look.Z)
		D.pitch = math.asin(math.clamp(look.Y, -1, 1))
		D.yawT, D.pitchT = D.yaw, D.pitch
		D.rot = D.lookRot(look)
	end
	-- a rotation looking along dir, upright (Roblox's CFrame.lookAt, built by
	-- hand: the test harness's lookAt turns a frame looking down -Z round)
	function D.lookRot(dir)
		local look = dir.Unit
		local right = look:Cross(Vector3.new(0, 1, 0))
		right = right.Magnitude > 1e-4 and right.Unit or Vector3.new(1, 0, 0)
		return CFrame.fromMatrix(Vector3.zero, right, right:Cross(look), -look)
	end
	function D.smoothSpec()
		return (DIR.Smooth or {})[D.smooth] or { Move = 4, Look = 12 }
	end
	function D.flySpeed(inp)
		local FLY = DIR.Fly or {}
		return D.speed * (inp.fast and (FLY.Fast or 4) or 1) * (inp.slow and (FLY.Slow or 0.25) or 1)
	end
	-- flying the camera along a rotation (the free cam's look; TRACK's where it points)
	function D.fly(dt, inp, rot)
		local want = rot:VectorToWorldSpace(Vector3.new(inp.move.X, 0, inp.move.Z)) + Vector3.new(0, inp.move.Y, 0)
		if want.Magnitude > 1 then
			want = want.Unit
		end
		D.vel += (want * D.flySpeed(inp) - D.vel) * (1 - math.exp(-(D.smoothSpec().Move or 4) * dt))
		D.pos += D.vel * dt
	end
	-- turning the camera toward `at` (a beat behind: k)
	function D.aim(pos, at, k, dt)
		local dir = at - pos
		if dir.Magnitude > 0.05 then
			D.rot = D.rot:Lerp(D.lookRot(dir), 1 - math.exp(-k * dt))
		end
		return CFrame.new(pos) * D.rot
	end
	function D.freeStep(dt, inp)
		local pmax = math.rad((DIR.Look or {}).PitchMax or 88)
		D.yawT -= inp.look.X
		D.pitchT = math.clamp(D.pitchT - inp.look.Y, -pmax, pmax)
		local a = 1 - math.exp(-(D.smoothSpec().Look or 12) * dt)
		D.yaw += (D.yawT - D.yaw) * a
		D.pitch += (D.pitchT - D.pitch) * a
		local rot = CFrame.Angles(0, D.yaw, 0) * CFrame.Angles(D.pitch, 0, 0)
		D.fly(dt, inp, rot)
		D.rot = rot
		return CFrame.new(D.pos) * rot
	end
	-- ORBIT: round the target - W / S in and out, E / Q up and down, A / D
	-- (or the mouse held) round; the wheel sets it circling by itself
	function D.orbitStep(dt, inp)
		local c = D.center(dt)
		if not c then
			return nil
		end
		local O = DIR.Orbit or {}
		local o = D.orbit
		local k = (inp.fast and 3 or 1) * (inp.slow and 0.3 or 1)
		o.rT = math.clamp(o.rT * math.exp(inp.move.Z * (O.RadiusRate or 0.9) * k * dt), O.MinRadius or 3, O.MaxRadius or 400)
		o.hT += (inp.move.Y * (O.HeightRate or 8) * k * dt) * math.max(o.rT / (O.Radius or 14), 0.5) + inp.look.Y * o.rT
		local turn = math.rad(D.orbitSpeed + inp.move.X * (O.Turn or 70) * k) * dt - inp.look.X
		o.angle += turn
		local a = 1 - math.exp(-6 * dt)
		o.r += (o.rT - o.r) * a
		o.h += (o.hT - o.h) * a
		local want = c + Vector3.new(math.sin(o.angle) * o.r, o.h, math.cos(o.angle) * o.r)
		D.pos = O.Avoid ~= false and D.avoid(c, want) or want
		D.vel = Vector3.zero
		-- (the look turns with the orbit itself - the target stays dead centre;
		-- the ease only takes up a new target or the shot's start)
		D.rot = CFrame.Angles(0, turn, 0) * D.rot
		return D.aim(D.pos, c, O.Look or 10, dt)
	end
	-- TRACK: the camera stays where you put it (it flies like the free cam)
	-- and turns after the target a beat behind, a little ahead of where
	-- it's going; the mouse held frames them off-centre
	function D.trackStep(dt, inp)
		D.fly(dt, inp, D.rot)
		local c, root = D.center(dt)
		if not c then
			return nil
		end
		local T = DIR.Track or {}
		local lead = Vector3.zero
		if root then
			lead = root.AssemblyLinearVelocity * (T.Lead or 0.12)
			if lead.Magnitude > 12 then
				lead = lead.Unit * 12
			end
		end
		D.trackOff = Vector2.new(math.clamp(D.trackOff.X + inp.look.X, -0.6, 0.6), math.clamp(D.trackOff.Y + inp.look.Y, -0.4, 0.4))
		local dir = c + lead - D.pos
		if dir.Magnitude > 0.05 then
			local want = D.lookRot(dir) * CFrame.Angles(0, -D.trackOff.X, 0) * CFrame.Angles(-D.trackOff.Y, 0, 0)
			D.rot = D.rot:Lerp(want, 1 - math.exp(-(T.Look or 3.2) * dt))
		end
		return CFrame.new(D.pos) * D.rot
	end
	-- FOLLOW: a chase cam on a spring behind where the target faces (it
	-- swings round behind a turn); W / S distance, A / D to the side, E / Q
	-- height, the mouse held swings it round; the wheel: how tight
	function D.followHeading()
		local _, root = D.targetPoint()
		local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local f = Vector3.new(look.X, 0, look.Z)
		D.follow.heading = f.Magnitude > 0.05 and math.atan2(-f.X, -f.Z) or (D.follow.heading or 0)
	end
	function D.followStep(dt, inp)
		local c, root = D.center(dt)
		if not c then
			return nil
		end
		local F = DIR.Follow or {}
		local f = D.follow
		local k = (inp.fast and 3 or 1) * (inp.slow and 0.3 or 1)
		f.dist = math.clamp(f.dist * math.exp(inp.move.Z * 0.9 * k * dt), 2, 300)
		f.side += inp.move.X * 8 * k * dt
		f.height += inp.move.Y * 6 * k * dt + inp.look.Y * f.dist
		f.userYaw -= inp.look.X
		if root then
			local look = root.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.05 then
				local want = math.atan2(-flatLook.X, -flatLook.Z)
				f.heading += D.wrap(want - f.heading) * (1 - math.exp(-(F.Heading or 3) * dt))
			end
		end
		local basis = CFrame.new(c) * CFrame.Angles(0, f.heading + f.userYaw, 0)
		local want = basis:PointToWorldSpace(Vector3.new(f.side, f.height, f.dist))
		if F.Avoid ~= false then
			want = D.avoid(c, want)
		end
		D.pos, D.vel = D.spring(D.pos, D.vel, want, D.followSpring, dt)
		return D.aim(D.pos, c + basis.LookVector * (F.LookAhead or 3), F.Look or 8, dt)
	end
	function D.setMode(name, quiet)
		if name ~= "FREE" and name ~= "DOLLY" and not D.targetModel() then
			-- (a shot on someone: the one nearest the middle of the frame, if nobody's picked)
			local cam = workspace.CurrentCamera
			local m = cam and D.nearestTo(Ray.new(cam.CFrame.Position, cam.CFrame.LookVector), 30)
			if not m then
				D.toast("PICK A TARGET FIRST  ·  CLICK A BODY OR T")
				D.sound("DirectorNo")
				return false
			end
			D.setTarget(m, true)
		end
		D.dollyRun = nil
		D.sync()
		D.mode = name
		if name == "ORBIT" then
			local O = DIR.Orbit or {}
			local c = D.targetPoint() or D.pos
			local off = D.pos - c
			local r = Vector3.new(off.X, 0, off.Z).Magnitude
			local rT = r < (O.MinRadius or 3) and (O.Radius or 14) or math.clamp(r, O.MinRadius or 3, O.MaxRadius or 400)
			D.orbit = { r = math.max(r, 0.5), rT = rT, h = off.Y, hT = off.Y, angle = r > 0.05 and math.atan2(off.X, off.Z) or 0 }
		elseif name == "FOLLOW" then
			local F = DIR.Follow or {}
			D.follow = { dist = F.Distance or 16, side = F.Side or 0, height = F.Height or 5, userYaw = 0, heading = 0 }
			D.followHeading()
		elseif name == "TRACK" then
			D.trackOff = Vector2.new(0, 0)
			D.vel = Vector3.zero
		end
		if not quiet then
			D.toast(name .. ((name ~= "FREE" and D.target) and ("  ·  " .. string.upper(D.target.name)) or ""))
			D.sound("DirectorTick")
		end
		return true
	end
	-- a controller's X: the next shot (the dolly after FOLLOW, with its keys down)
	function D.nextMode()
		local order = { "FREE", "ORBIT", "TRACK", "FOLLOW" }
		local i = table.find(order, D.mode) or 0
		if D.mode == "FOLLOW" and #D.keys >= 2 then
			D.play(D.loop)
			return
		end
		D.setMode(order[i % #order + 1])
	end

	---------------------------------------------------------------------------
	-- the dolly
	---------------------------------------------------------------------------
	function D.addKey()
		local DL = DIR.Dolly or {}
		if #D.keys >= (DL.MaxKeys or 24) then
			D.toast("THAT'S THE MOST KEYS")
			D.sound("DirectorNo")
			return
		end
		local cam = workspace.CurrentCamera
		local base = D.base or (cam and cam.CFrame) or CFrame.new()
		local look = base.LookVector
		local aim = (D.mode == "ORBIT" or D.mode == "TRACK" or D.mode == "FOLLOW") and D.targetModel() ~= nil
		table.insert(D.keys, {
			pos = base.Position, yaw = math.atan2(-look.X, -look.Z), pitch = math.asin(math.clamp(look.Y, -1, 1)),
			roll = D.roll, fov = D.fov, aim = aim and 1 or 0,
		})
		D.dollyDirty = true
		D.pathVersion += 1
		D.toast(string.format("KEY %d%s", #D.keys, aim and "  ·  ON TARGET" or ""))
		D.sound("DirectorKey")
	end
	function D.undoKey(all)
		if #D.keys == 0 then
			return
		end
		if all then
			table.clear(D.keys)
		else
			table.remove(D.keys)
		end
		D.dollyDirty = true
		D.pathVersion += 1
		D.toast(all and "KEYS CLEARED" or ("KEY " .. (#D.keys + 1) .. " GONE"))
		D.sound("DirectorTick")
	end
	function D.setDollyTime(step, quiet)
		local DL = DIR.Dolly or {}
		D.dollyTime = math.clamp(D.dollyTime + step, DL.MinTime or 1, DL.MaxTime or 120)
		if not quiet then
			D.toast(string.format("DOLLY  ·  %.1f s", D.dollyTime))
			D.sound("DirectorTick")
		end
	end
	-- the move through the keys, measured: where along it (by length) each
	-- part of it is, so it travels at an even speed whatever the spacing
	function D.buildDolly()
		local P, ch = {}, { yaw = {}, pitch = {}, roll = {}, fov = {}, aim = {} }
		local lastYaw
		for i, k in D.keys do
			P[i] = k.pos
			local yaw = lastYaw and (lastYaw + D.wrap(k.yaw - lastYaw)) or k.yaw -- (the short way round)
			lastYaw = yaw
			ch.yaw[i], ch.pitch[i], ch.roll[i], ch.fov[i], ch.aim[i] = yaw, k.pitch, k.roll, k.fov, k.aim
		end
		local n, per = #P, 24
		local samples = { { L = 0, seg = 1, t = 0 } }
		local total, prev = 0, P[1]
		for i = 1, n - 1 do
			for s = 1, per do
				local p = D.crPos(P, i, s / per)
				total += (p - prev).Magnitude
				prev = p
				table.insert(samples, { L = total, seg = i, t = s / per })
			end
		end
		D.dollyData = { P = P, ch = ch, samples = samples, total = total, n = n }
		-- where each key comes along it (0..1)
		D.marks = { 0 }
		for i = 2, n do
			table.insert(D.marks, total > 1e-3 and samples[(i - 1) * per + 1].L / total or (i - 1) / (n - 1))
		end
		D.dollyDirty = false
	end
	-- the segment and how far through it, e of the way along the move
	function D.locate(e)
		local data = D.dollyData
		if data.total <= 1e-3 then
			local x = math.clamp(e, 0, 1) * (data.n - 1)
			local seg = math.clamp(math.floor(x) + 1, 1, data.n - 1)
			return seg, x - (seg - 1)
		end
		local L = math.clamp(e, 0, 1) * data.total
		local s = data.samples
		local lo, hi = 1, #s
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if s[mid].L < L then
				lo = mid
			else
				hi = mid
			end
		end
		local a, b = s[lo], s[hi]
		local k = (b.L - a.L) > 1e-9 and (L - a.L) / (b.L - a.L) or 0
		local ta = a.seg == b.seg and a.t or 0 -- (the end of one segment is the start of the next)
		return b.seg, ta + (b.t - ta) * k
	end
	-- the camera e of the way along the move: where it is, where it looks
	-- (at the target, from keys dropped on one), its zoom and roll
	function D.dollyAt(e)
		if D.dollyDirty or not D.dollyData then
			D.buildDolly()
		end
		local data = D.dollyData
		local seg, t = D.locate(e)
		local pos = D.crPos(data.P, seg, t)
		local function chan(list)
			local v1, v2 = list[seg], list[seg + 1]
			return D.cr(list[seg - 1] or (2 * v1 - v2), v1, v2, list[seg + 2] or (2 * v2 - v1), t)
		end
		local rot = CFrame.Angles(0, chan(data.ch.yaw), 0) * CFrame.Angles(math.clamp(chan(data.ch.pitch), -1.55, 1.55), 0, 0)
		local aim = math.clamp(chan(data.ch.aim), 0, 1)
		local p = aim > 0.001 and D.targetPoint() or nil
		if p and (p - pos).Magnitude > 0.5 then
			rot = rot:Lerp(D.lookRot(p - pos), aim)
		end
		local L = DIR.Lens or {}
		return CFrame.new(pos) * rot, math.clamp(chan(data.ch.fov), L.Min or 6, L.Max or 110), chan(data.ch.roll)
	end
	function D.play(loop)
		if #D.keys < 2 then
			D.toast("DROP TWO KEYS FIRST  ·  R")
			D.sound("DirectorNo")
			return
		end
		D.buildDolly()
		D.dollyRun = { t0 = os.clock(), loop = loop == true, e = 0 }
		D.mode = "DOLLY"
		D.toast(loop and "ACTION  ·  LOOP" or "ACTION")
		D.sound("DirectorAction")
	end
	function D.stopDolly(quiet)
		if not D.dollyRun then
			return
		end
		D.dollyRun = nil
		D.mode = "FREE"
		D.sync()
		D.vel = Vector3.zero
		if not quiet then
			D.toast("CUT")
			D.sound("DirectorTick")
		end
	end
	function D.dollyStep()
		local run = D.dollyRun
		if not run or #D.keys < 2 then
			D.dollyRun = nil
			return nil
		end
		local u = (os.clock() - run.t0) / math.max(D.dollyTime, 0.1)
		if u >= 1 and run.loop then
			run.t0 = os.clock()
			u = 0
		end
		run.e = D.ease(u)
		local cf, fov, roll = D.dollyAt(run.e)
		D.fov, D.fovT, D.roll, D.rollT = fov, fov, roll, roll
		if u >= 1 then
			-- (once: it stops on the last key, the free cam takes it from there)
			D.dollyRun = nil
			D.mode = "FREE"
			D.base = cf
			D.sync()
			D.vel = Vector3.zero
			D.toast("CUT")
		end
		return cf
	end
	-- the path, drawn in the world while the overlay's up (never in the shot)
	function D.path()
		local show = D.on and D.overlay and #D.keys > 0 and not D.dollyRun
		if not show then
			if D.pathFolder then
				D.pathFolder:Destroy()
				D.pathFolder = nil
			end
			return
		end
		if D.pathFolder and D.pathDrawn == D.pathVersion then
			return
		end
		if D.pathFolder then
			D.pathFolder:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "DirectorPath"
		folder.Parent = workspace.CurrentCamera
		D.pathFolder, D.pathDrawn = folder, D.pathVersion
		local function dot(cf, size, color, ball)
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = color
			p.Size = size
			if ball then
				p.Shape = Enum.PartType.Ball
			end
			p.CFrame = cf
			p.Parent = folder
		end
		local gold = Color3.fromRGB(255, 196, 64)
		for _, k in D.keys do
			local cf = CFrame.new(k.pos) * CFrame.Angles(0, k.yaw, 0) * CFrame.Angles(k.pitch, 0, 0)
			dot(cf, Vector3.new(0.9, 0.6, 0.6), gold)
			dot(cf * CFrame.new(0, 0, -1.4), Vector3.new(0.12, 0.12, 2), gold)
		end
		if #D.keys >= 2 then
			local n = (DIR.Dolly or {}).Dots or 56
			for i = 0, n do
				dot(CFrame.new(D.dollyAt(i / n).Position), Vector3.new(0.3, 0.3, 0.3), Color3.new(1, 1, 1), true)
			end
		end
	end

	---------------------------------------------------------------------------
	-- the lens: zoom and roll (eased), focus, grade, the shake
	---------------------------------------------------------------------------
	function D.lens(dt, inp)
		local L = DIR.Lens or {}
		local rate = (L.ZoomRate or 22) * (inp.fast and 3 or 1) * (inp.slow and 0.3 or 1)
		D.fovT = math.clamp(D.fovT - inp.zoom * rate * dt, L.Min or 6, L.Max or 110)
		D.rollT = math.clamp(D.rollT + inp.roll * (L.RollRate or 30) * dt, -(L.RollMax or 45), L.RollMax or 45)
		D.fov += (D.fovT - D.fov) * (1 - math.exp(-(L.ZoomK or 6) * dt))
		D.roll += (D.rollT - D.roll) * (1 - math.exp(-(L.RollK or 6) * dt))
	end
	function D.resetLens()
		D.fovT, D.rollT = (DIR.Lens or {}).Fov or 70, 0
		D.trackOff = Vector2.new(0, 0)
		D.toast("LENS RESET")
		D.sound("DirectorTick")
	end
	function D.setFocus(on, quiet)
		D.focus = on == true
		local cam = workspace.CurrentCamera
		if D.focus and D.on and cam then
			if not (D.dof and D.dof.Parent) then
				local F = DIR.Focus or {}
				D.dof = Instance.new("DepthOfFieldEffect")
				D.dof.Name = "DirectorFocus"
				D.dof.FarIntensity = F.FarIntensity or 0.45
				D.dof.NearIntensity = F.NearIntensity or 0.7
				D.dof.FocusDistance = 20
				D.dof.InFocusRadius = 10
				D.dof.Parent = cam
				D.focusD = nil
			end
			-- any other depth of field (the game's) steps aside meanwhile
			for _, holder in { game:GetService("Lighting"), cam } do
				for _, e in holder:GetChildren() do
					if e:IsA("DepthOfFieldEffect") and e ~= D.dof then
						VFX.Director.hold("focus", e, "Enabled", false)
					end
				end
			end
		else
			if D.dof then
				D.dof:Destroy()
				D.dof = nil
			end
			VFX.Director.release("focus")
		end
		if not quiet then
			D.toast(D.focus and "FOCUS  ·  " .. (D.target and string.upper(D.target.name) or "THE MIDDLE") or "FOCUS OFF")
			D.sound("DirectorTick")
		end
	end
	-- the focus pulled to the target (no target: what's in the middle of the frame)
	function D.focusStep(dt)
		local cam = workspace.CurrentCamera
		if not D.dof or not cam then
			return
		end
		local F = DIR.Focus or {}
		local p = D.targetPoint()
		local dist = F.Auto or 400
		if p then
			dist = (p - cam.CFrame.Position).Magnitude
		elseif D.rayParams then
			local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * (F.Auto or 400), D.rayParams)
			if hit then
				dist = (hit.Position - cam.CFrame.Position).Magnitude
			end
		end
		D.focusD = D.focusD and (D.focusD + (dist - D.focusD) * (1 - math.exp(-(F.K or 5) * dt))) or dist
		D.dof.FocusDistance = math.clamp(D.focusD, 0, 200)
		D.dof.InFocusRadius = math.clamp(D.focusD * (F.Radius or 0.12), F.MinRadius or 1.5, 50)
	end
	-- the grade (0: none), eased in
	function D.applyGrade(quiet)
		local g = (DIR.Grades or {})[D.grade]
		local cam = workspace.CurrentCamera
		if g and cam and D.on then
			if not (D.cc and D.cc.Parent) then
				D.cc = Instance.new("ColorCorrectionEffect")
				D.cc.Name = "DirectorGrade"
				D.cc.Parent = cam
			end
			TweenService:Create(D.cc, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
				Brightness = g.Brightness or 0, Contrast = g.Contrast or 0, Saturation = g.Saturation or 0, TintColor = g.Tint or Color3.new(1, 1, 1),
			}):Play()
		elseif D.cc then
			D.cc:Destroy()
			D.cc = nil
		end
		if not quiet then
			D.toast(g and ("GRADE  ·  " .. g.Name) or "NO GRADE")
			D.sound("DirectorTick")
		end
	end
	function D.setGrade(step)
		D.grade = (D.grade + step) % (#(DIR.Grades or {}) + 1)
		D.applyGrade()
	end
	-- the shake: the game's impacts (VFX.Director keeps them for this
	-- camera), and a hand-held drift - both on the slowed clock
	function D.shakeCF()
		local SH = DIR.Shake or {}
		local cf = CFrame.new()
		if D.shakeMode >= 2 then
			cf = VFX.Director.shakeOffset(SH.Gain or 0.7, SH.Freq or 16)
		end
		if D.shakeMode >= 3 then
			local h = SH.Hand or {}
			local t = VFX.WarpTime(os.clock()) * (h.Freq or 0.45)
			local function n(seed)
				return math.clamp((math.noise(t, seed, 0.71) + math.noise(t * 2.3, seed + 0.5, 0.29) * 0.35) * 2, -1, 1)
			end
			local m = h.Move or 0.05
			cf = cf * CFrame.new(n(11.1) * m, n(12.7) * m, 0)
				* CFrame.Angles(math.rad(n(13.3) * (h.Pitch or 0.25)), math.rad(n(14.9) * (h.Yaw or 0.35)), math.rad(n(15.1) * (h.Roll or 0.4)))
		end
		return cf
	end

	---------------------------------------------------------------------------
	-- the clean frame
	---------------------------------------------------------------------------
	function D.passing()
		return D.cuts and VFX.InCinematic()
	end
	-- Roblox's own UI, a part at a time (read / set; the tests listen here)
	function D.getCore(typ)
		return StarterGui:GetCoreGuiEnabled(typ)
	end
	function D.setCore(typ, on)
		StarterGui:SetCoreGuiEnabled(typ, on)
	end
	function D.clean(on)
		local DC = VFX.Director
		if not on then
			if D.conns.labels then
				D.conns.labels:Disconnect()
				D.conns.labels = nil
			end
			DC.release("frame")
			for typ, was in D.core or {} do
				pcall(D.setCore, typ, was)
			end
			D.core = nil
			if D.topbar ~= nil then
				local was = D.topbar
				pcall(function()
					StarterGui:SetCore("TopbarEnabled", was)
				end)
				D.topbar = nil
			end
			return
		end
		-- Roblox's own UI (each part as it was), the top bar, chat, prompts
		D.core = {}
		pcall(function()
			for _, typ in Enum.CoreGuiType:GetEnumItems() do
				if typ ~= Enum.CoreGuiType.All then
					local ok, was = pcall(D.getCore, typ)
					if ok and type(was) == "boolean" then
						D.core[typ] = was
					end
				end
			end
		end)
		pcall(D.setCore, Enum.CoreGuiType.All, false)
		local ok, top = pcall(function()
			return StarterGui:GetCore("TopbarEnabled")
		end)
		D.topbar = not (ok and top == false)
		pcall(function()
			StarterGui:SetCore("TopbarEnabled", false)
		end)
		pcall(function()
			local chat = game:GetService("TextChatService")
			for _, name in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" } do
				local c = chat:FindFirstChildOfClass(name)
				if c then
					DC.hold("frame", c, "Enabled", false)
				end
			end
		end)
		pcall(function()
			DC.hold("frame", game:GetService("Chat"), "BubbleChatEnabled", false) -- (the old chat's bubbles)
		end)
		DC.hold("frame", ProximityPromptService, "Enabled", false)
		-- the labels round the map (once; each new one as it comes)
		for _, d in workspace:GetDescendants() do
			if d:IsA("BillboardGui") and not D.KEEPBB[d.Name] and not d:IsDescendantOf(VFX.Folder) then
				DC.hold("frame", d, "Enabled", false)
			end
		end
		D.conns.labels = workspace.DescendantAdded:Connect(function(d)
			if D.on and d:IsA("BillboardGui") and not D.KEEPBB[d.Name] and not d:IsDescendantOf(VFX.Folder) then
				task.defer(function()
					if D.on and d.Parent then
						DC.hold("frame", d, "Enabled", false)
					end
				end)
			end
		end)
		D.sweepAt, D.bodyAt = 0, 0
		D.sweep(os.clock())
	end
	-- the screens (every frame: a new one is off before it's drawn), your own
	-- body (its new parts four times a second), every body's name tag and
	-- overheads (twice a second); held, so they come back as the game has them
	function D.sweep(now)
		local DC = VFX.Director
		local pg = player:FindFirstChildOfClass("PlayerGui")
		local passing = D.passing()
		for _, g in pg and pg:GetChildren() or {} do
			if g:IsA("LayerCollector") and g.Name ~= "DirectorFrame" and g.Name ~= "DirectorOverlay" and not D.KEEP[g.Name] then
				if passing and g.Name == (DIR.CutsceneGui or "QuirkCinema") then
					DC.unhold("frame", g, "Enabled")
				elseif not DC.held("frame", g, "Enabled") then
					DC.hold("frame", g, "Enabled", false, true)
				end
			end
		end
		local char = player.Character
		if D.hideBody and char and now >= (D.bodyAt or 0) then
			D.bodyAt = now + 0.25
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					if not DC.held("frame", d, "LocalTransparencyModifier") then
						DC.hold("frame", d, "LocalTransparencyModifier", 1, true)
					end
				elseif (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Highlight") or d:IsA("SurfaceGui")) and not DC.held("frame", d, "Enabled") then
					DC.hold("frame", d, "Enabled", false)
				end
			end
		end
		if now >= (D.sweepAt or 0) then
			D.sweepAt = now + 0.5
			for _, m in DC.bodies() do
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and not DC.held("frame", hum, "DisplayDistanceType") then
					DC.hold("frame", hum, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
				end
				for _, d in m:GetDescendants() do
					if d:IsA("BillboardGui") and not D.KEEPBB[d.Name] and not DC.held("frame", d, "Enabled") then
						DC.hold("frame", d, "Enabled", false)
					end
				end
			end
		end
	end
	function D.setFrame(i)
		local modes = (DIR.Frame or {}).Modes or { "Off", "Scope", "Vertical" }
		D.frame = (i - 1) % #modes + 1
		local m = modes[D.frame]
		HUD.DirectorFrame(m)
		D.toast(m == "Scope" and "LETTERBOX  ·  2.39 : 1" or (m == "Vertical" and "VERTICAL  ·  9 : 16" or "FULL FRAME"))
		D.sound("DirectorTick")
	end
	function D.setOverlay(on)
		D.overlay = on == true
		HUD.DirectorOverlay(D.overlay)
		D.path()
		D.toast("OVERLAY")
	end
	function D.setGrid(on)
		D.grid = on == true
		HUD.DirectorGrid(D.grid)
		D.toast(D.grid and "THIRDS" or "NO GRID")
		D.sound("DirectorTick")
	end
	function D.setBody(hide)
		D.hideBody = hide == true
		local char = player.Character
		if not D.hideBody and char then
			VFX.Director.release("frame", function(inst)
				return inst:IsDescendantOf(char)
			end)
			D.sweepAt = 0 -- (its name tag stays off)
		end
		D.bodyAt = 0
		D.toast(D.hideBody and "YOUR BODY  ·  HIDDEN" or "YOUR BODY  ·  SHOWN")
		D.sound("DirectorTick")
	end

	---------------------------------------------------------------------------
	-- time
	---------------------------------------------------------------------------
	function D.timeStep(dt)
		local TIME = DIR.Time or {}
		if D.frozen then
			D.scale = 0
		else
			local want = (TIME.Steps or { 1 })[D.slow] or 1
			D.scale += (want - D.scale) * (1 - math.exp(-(TIME.RampK or 7) * dt))
			if math.abs(D.scale - want) < 0.002 then
				D.scale = want
			end
		end
		VFX.Director.time(D.scale)
	end
	function D.setSlow(i)
		local steps = (DIR.Time or {}).Steps or { 1 }
		i = math.clamp(i, 1, #steps)
		local wasFrozen = D.frozen
		if wasFrozen then
			D.setFreeze(false, true)
		end
		if i == D.slow and not wasFrozen then
			return
		end
		local slower = i > D.slow
		D.slow = i
		local v = steps[i]
		D.toast(v < 1 and string.format("SLOW MOTION  ·  %gx", v) or "REAL TIME", Color3.fromRGB(110, 190, 255))
		D.sound(slower and "DirectorSlow" or "DirectorFast")
	end
	function D.setFreeze(on, quiet)
		on = on == true
		if on == D.frozen then
			return
		end
		D.frozen = on
		local cam = workspace.CurrentCamera
		VFX.Director.freeze(on, cam and cam.CFrame.Position, D.hideBody and player.Character or nil)
		if on then
			D.scale = 0
			VFX.Director.time(0)
			HUD.DirectorFlash()
			if not quiet then
				D.toast("FREEZE FRAME")
				D.sound("DirectorShutter")
			end
		elseif not quiet then
			D.toast("ROLLING")
			D.sound("DirectorFast")
		end
	end
	-- far from your body the map round the camera is asked for (the place streams)
	function D.stream(now, pos)
		local ST = DIR.Stream or {}
		if now < (D.streamAt or 0) or D.streaming then
			return
		end
		D.streamAt = now + (ST.Every or 1)
		local _, _, root = getCharacter()
		if root and (root.Position - pos).Magnitude < (ST.From or 300) then
			return
		end
		D.streaming = true
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(pos, ST.Timeout or 1)
			end)
			D.streaming = false
		end)
	end

	---------------------------------------------------------------------------
	-- input: everything it takes while it's on (and nothing else gets)
	---------------------------------------------------------------------------
	function D.padState()
		local out = {}
		local ok, state = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
		if ok and type(state) == "table" then
			for _, input in state do
				out[input.KeyCode.Name] = input.Position
			end
		end
		return out
	end
	function D.stick(v)
		local m = v and Vector2.new(v.X, v.Y).Magnitude or 0
		local dz = PADK.Deadzone or 0.14
		if m <= dz then
			return Vector2.new(0, 0)
		end
		return Vector2.new(v.X, v.Y).Unit * math.min(((m - dz) / (1 - dz)) ^ (PADK.Curve or 1.6), 1)
	end
	function D.mouseDelta()
		return UserInputService:GetMouseDelta()
	end
	function D.padDown(k)
		if not k then
			return false
		end
		local ok, on = pcall(function()
			return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, k)
		end)
		return ok and on == true
	end
	-- this frame's input: move (x right, y up, z back), look (radians: the
	-- mouse's way round), fast / slow, zoom, roll
	function D.read(dt)
		local function down(k)
			return k ~= nil and UserInputService:IsKeyDown(k)
		end
		local pad = D.padState()
		local s1, s2 = D.stick(pad.Thumbstick1), D.stick(pad.Thumbstick2)
		local mx = (down(Enum.KeyCode.D) and 1 or 0) - (down(Enum.KeyCode.A) and 1 or 0) + s1.X
		local mz = (down(Enum.KeyCode.S) and 1 or 0) - (down(Enum.KeyCode.W) and 1 or 0) - s1.Y
		local my = (down(K.Up) and 1 or 0) - (down(K.Down) and 1 or 0)
			+ (pad.ButtonR2 and pad.ButtonR2.Z or 0) - (pad.ButtonL2 and pad.ButtonL2.Z or 0)
		local LOOK = DIR.Look or {}
		local fovK = math.clamp(D.fov / 70, 0.1, 1.6) -- (zoomed in, it turns finer)
		local look = Vector2.new(s2.X, -s2.Y) * (LOOK.Pad or 2.2) * fovK * dt
		if D.rmb or D.latch then
			local ok, delta = pcall(D.mouseDelta)
			if ok and typeof(delta) == "Vector2" then
				look += delta * (LOOK.Mouse or 0.0042) * fovK
			end
		end
		return {
			move = Vector3.new(math.clamp(mx, -1, 1), math.clamp(my, -1, 1), math.clamp(mz, -1, 1)),
			look = look,
			fast = down(K.Fast) or down(Enum.KeyCode.RightShift) or D.padDown(PADK.Fast),
			slow = down(K.Slow) or D.padDown(PADK.Slow),
			zoom = ((down(K.ZoomIn) or D.padDown(PADK.ZoomIn)) and 1 or 0) - ((down(K.ZoomOut) or D.padDown(PADK.ZoomOut)) and 1 or 0),
			roll = (down(K.RollRight) and 1 or 0) - (down(K.RollLeft) and 1 or 0),
		}
	end
	function D.wheel(z)
		if D.mode == "ORBIT" then
			local O = DIR.Orbit or {}
			D.orbitSpeed = math.clamp(D.orbitSpeed + z * (O.Step or 4), -(O.Max or 120), O.Max or 120)
		elseif D.mode == "FOLLOW" then
			local F = DIR.Follow or {}
			D.followSpring = math.clamp(D.followSpring + z, F.MinSpring or 1, F.MaxSpring or 14)
		elseif D.mode == "DOLLY" then
			D.setDollyTime(z * 0.5, true)
		else
			local FLY = DIR.Fly or {}
			D.speed = math.clamp(D.speed * (FLY.Step or 1.18) ^ z, FLY.Min or 1, FLY.Max or 800)
		end
	end
	-- what each key does (by name: EnumItems compare that way everywhere)
	do
		local function on(k, fn)
			if typeof(k) == "EnumItem" then
				D.ACT[k.Name] = fn
			end
		end
		local steps = #((DIR.Time or {}).Steps or { 1 })
		on(K.Free, function()
			D.setMode("FREE")
		end)
		on(K.Orbit, function()
			D.setMode("ORBIT")
		end)
		on(K.Track, function()
			D.setMode("TRACK")
		end)
		on(K.Follow, function()
			D.setMode("FOLLOW")
		end)
		on(K.NextTarget, function(shift)
			D.cycle(shift and -1 or 1)
		end)
		on(K.LookLatch, function()
			D.latch = not D.latch
		end)
		on(K.DollyKey, D.addKey)
		on(K.DollyUndo, function(shift)
			D.undoKey(shift)
		end)
		on(K.DollyPlay, function()
			if D.dollyRun then
				D.stopDolly()
			else
				D.play(D.loop)
			end
		end)
		on(K.DollyLoop, function()
			D.loop = not D.loop
			if D.dollyRun then
				D.dollyRun.loop = D.loop
			end
			D.toast(D.loop and "DOLLY  ·  LOOP" or "DOLLY  ·  ONCE")
			D.sound("DirectorTick")
		end)
		on(K.DollyShorter, function()
			D.setDollyTime(-((DIR.Dolly or {}).Step or 1))
		end)
		on(K.DollyLonger, function()
			D.setDollyTime((DIR.Dolly or {}).Step or 1)
		end)
		on(K.ResetLens, D.resetLens)
		on(K.Focus, function()
			D.setFocus(not D.focus)
		end)
		on(K.Grade, function(shift)
			D.setGrade(shift and -1 or 1)
		end)
		on(K.Shake, function()
			D.shakeMode = D.shakeMode % 3 + 1
			D.toast(({ "SHAKE OFF", "SHAKE  ·  IMPACTS", "SHAKE  ·  IMPACTS + HAND-HELD" })[D.shakeMode])
			D.sound("DirectorTick")
		end)
		on(K.Slower, function()
			D.setSlow(D.slow + 1)
		end)
		on(K.Faster, function()
			D.setSlow(D.slow - 1)
		end)
		on(K.Freeze, function()
			D.setFreeze(not D.frozen)
		end)
		on(K.Letterbox, function()
			D.setFrame(D.frame + 1)
		end)
		on(K.Grid, function()
			D.setGrid(not D.grid)
		end)
		on(K.Body, function()
			D.setBody(not D.hideBody)
		end)
		on(K.Overlay, function()
			D.setOverlay(not D.overlay)
		end)
		on(K.Smooth, function()
			D.smooth = D.smooth % math.max(#(DIR.Smooth or {}), 1) + 1
			D.toast("MOVES  ·  " .. (D.smoothSpec().Name or ""))
			D.sound("DirectorTick")
		end)
		on(K.Cutscenes, function()
			D.cuts = not D.cuts
			D.toast(D.cuts and "CUTSCENES  ·  THE TARGET'S PLAY" or "CUTSCENES  ·  THE DIRECTOR'S CAMERA")
			D.sound("DirectorTick")
		end)
		-- a controller
		on(PADK.Mode, D.nextMode)
		on(PADK.Target, function()
			D.cycle(1)
		end)
		on(PADK.Freeze, function()
			D.setFreeze(not D.frozen)
		end)
		on(PADK.Slower, function()
			D.setSlow(D.slow + 1)
		end)
		on(PADK.Faster, function()
			D.setSlow(D.slow - 1)
		end)
		on(PADK.ResetLens, D.resetLens)
		on(PADK.Overlay, function()
			D.setOverlay(not D.overlay)
		end)
		on(PADK.Letterbox, function()
			D.setFrame(D.frame + 1)
		end)
		D.steps = steps
	end
	-- every key it takes while it's on: its own, moving, and every one the
	-- game binds (your body does nothing meanwhile) - never J (its own switch)
	function D.keyList()
		local list, seen = {}, {}
		local function add(k)
			if typeof(k) == "EnumItem" and not seen[tostring(k)] and tostring(k) ~= tostring(DIR.Key or Enum.KeyCode.J) then
				seen[tostring(k)] = true
				table.insert(list, k)
			end
		end
		local function addAll(keys)
			for _, k in keys or {} do
				add(k)
			end
		end
		addAll(K)
		addAll(PADK)
		addAll({
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.RightShift,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX,
			Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2,
			Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonR3, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonSelect,
			Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseWheel,
		})
		for _, keys in Config.AbilityKeys or {} do
			addAll(keys)
		end
		for _, keys in {
			Config.M1Keys, Config.SpecialKeys, Config.UltKeys, Config.DashKeys, Config.SprintKeys, Config.BlockKeys,
			Config.ExtraKeys, Config.FinisherKeys, Config.ContextKeys, Config.ShiftLockKeys,
			Config.UseItemKeys, Config.ShopKeys, Config.BoardKeys, Config.EmoteKeys,
		} do
			addAll(keys)
		end
		local DEVF = Config.DevFlight or {}
		addAll({ DEVF.Key, DEVF.DownKey, DEVF.DiveKey })
		addAll(DEVF.LockKeys) -- (round 92: the hover-lock's)
		return list
	end
	function D.onInput(_, state, input)
		if not D.on then
			return Enum.ContextActionResult.Pass
		end
		local ut = input.UserInputType and input.UserInputType.Name or ""
		local kc = input.KeyCode and input.KeyCode.Name or ""
		local began = state == Enum.UserInputState.Begin
		if ut == "MouseWheel" then
			local z = input.Position and input.Position.Z or 0
			if z ~= 0 then
				D.wheel(z > 0 and 1 or -1)
			end
		elseif ut == "MouseButton2" then
			D.rmb = began or state == Enum.UserInputState.Change
		elseif ut == "MouseButton1" then
			if began then
				D.click()
			end
		elseif PADK.Exit and kc == PADK.Exit.Name then
			-- (a controller's B held: leave)
			if began then
				local token = {}
				D.padExit = token
				task.delay(PADK.ExitHold or 0.6, function()
					if D.padExit == token and D.on then
						D.stop("Pad")
					end
				end)
			else
				D.padExit = nil
			end
		elseif began and D.ACT[kc] then
			D.ACT[kc](UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
		end
		return Enum.ContextActionResult.Sink
	end
	-- the mouse: free to click a body; held (or latched) it looks; hidden with the overlay
	function D.mouse()
		local want = D.latch and Enum.MouseBehavior.LockCenter
			or (D.rmb and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default)
		if D.get(UserInputService, "MouseBehavior") ~= want then
			UserInputService.MouseBehavior = want
		end
		local icon = D.overlay and not D.latch
		if D.get(UserInputService, "MouseIconEnabled") ~= icon then
			UserInputService.MouseIconEnabled = icon
		end
	end
	-- a property read that can't throw (nil if it can't be read)
	function D.get(inst, prop)
		local ok, v = pcall(function()
			return inst[prop]
		end)
		return ok and v or nil
	end

	---------------------------------------------------------------------------
	-- the overlay's state
	---------------------------------------------------------------------------
	function D.help()
		local mode = D.mode
		if inputMode == "Gamepad" then
			return "CONTROLLER  ·  " .. mode, {
				"<b>LS</b> fly  <b>RS</b> look  <b>RT / LT</b> up / down",
				"<b>RB / LB</b> fast / slow  <b>X</b> next shot  <b>A</b> target",
				"<b>D-pad</b> zoom (up / down), slow-mo (left / right)",
				"<b>Y</b> freeze  <b>L3</b> reset lens  <b>R3</b> hide  <b>Select</b> frame",
				"hold <b>B</b>: stop directing",
			}
		end
		local lines
		if mode == "ORBIT" then
			lines = { "<b>W / S</b> in / out  <b>A / D</b> round  <b>E / Q</b> up / down", "<b>Wheel</b> circling speed  <b>RMB</b> swing round" }
		elseif mode == "FOLLOW" then
			lines = { "<b>W / S</b> in / out  <b>A / D</b> side  <b>E / Q</b> height", "<b>Wheel</b> how tight  <b>RMB</b> swing round" }
		elseif mode == "TRACK" then
			lines = { "<b>WASD</b> move it  <b>E / Q</b> up / down  <b>Wheel</b> speed", "<b>RMB</b> frame them off-centre" }
		elseif mode == "DOLLY" then
			lines = { "<b>Enter</b> cut  <b>L</b> loop  <b>Wheel</b> or <b>[ ]</b> how long" }
		else
			lines = { "<b>WASD</b> fly  <b>E / Q</b> up / down  <b>RMB</b> look  <b>F</b> latch", "<b>Wheel</b> speed  <b>Shift</b> fast  <b>Ctrl</b> slow" }
		end
		for _, s in {
			"<b>1-4</b> free, orbit, track, follow  <b>T</b> / click: target",
			"<b>R</b> key  <b>Enter</b> roll  <b>L</b> loop  <b>[ ]</b> time  <b>Bksp</b> undo",
			"<b>Z / X</b> zoom  <b>, .</b> roll  <b>C</b> reset  <b>G</b> focus  <b>U</b> grade",
			"<b>- =</b> slow-mo  <b>Space</b> freeze  <b>Y</b> shake  <b>9</b> moves",
			"<b>B</b> frame  <b>I</b> grid  <b>O</b> body  <b>0</b> cuts  <b>H</b> hide  <b>J</b> off",
		} do
			table.insert(lines, s)
		end
		return "KEYS  ·  " .. mode, lines
	end
	function D.uiState(now)
		local steps = (DIR.Time or {}).Steps or { 1 }
		local slowV = steps[D.slow] or 1
		local speedName, speed = "SPEED", tostring(math.round(D.speed))
		if D.mode == "ORBIT" then
			speedName, speed = "ORBIT", string.format("%d°/s", math.round(D.orbitSpeed))
		elseif D.mode == "FOLLOW" then
			speedName, speed = "SPRING", string.format("%d", math.round(D.followSpring))
		elseif D.mode == "DOLLY" then
			speedName, speed = "DOLLY", string.format("%.1fs", D.dollyTime)
		end
		local grade = (DIR.Grades or {})[D.grade]
		local frameName = ((DIR.Frame or {}).Modes or {})[D.frame]
		local dolly = nil
		local n = #D.keys
		if n > 0 or D.dollyRun then
			if D.dollyDirty or not D.dollyData then
				if n >= 2 then
					D.buildDolly()
				else
					D.marks = { 0 }
				end
			end
			local info = string.format("%d KEY%s  ·  %.1f s  ·  %s", n, n == 1 and "" or "S", D.dollyTime, D.loop and "LOOP" or "ONCE")
			if D.dollyRun then
				info ..= "  ·  ROLLING"
			elseif n < 2 then
				info ..= "  ·  R: ONE MORE"
			else
				info ..= "  ·  ENTER: ACTION"
			end
			dolly = { info = info, progress = D.dollyRun and D.dollyRun.e or 0, marks = n >= 2 and D.marks or { 0 } }
		end
		local title, keys = D.help()
		return {
			mode = D.mode,
			target = D.target and ('<font color="#FFC440">' .. (string.upper(D.target.name):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) .. "</font>")
				or '<font color="#969CB4">none  ·  click a body or T</font>',
			speedName = speedName,
			speed = speed,
			fov = string.format("%d°", math.round(D.fov)),
			roll = string.format("%d°", math.round(D.roll)),
			time = D.frozen and "STILL" or string.format("%.2fx", D.scale),
			move = D.smoothSpec().Name or "",
			slow = D.frozen and "FREEZE" or (slowV < 1 and string.format("%gx", slowV) or nil),
			pills = {
				FOCUS = D.focus and "FOCUS" or false,
				GRADE = grade and grade.Name or false,
				SHAKE = (D.shakeMode == 2 and "HITS") or (D.shakeMode == 3 and "HAND") or false,
				FRAME = (frameName == "Scope" and "2.39") or (frameName == "Vertical" and "9:16") or false,
				GRID = D.grid and "GRID" or false,
				BODY = (not D.hideBody) and "BODY" or false,
				CUTS = D.cuts and "CUTS" or false,
			},
			tc = now - (D.startedAt or now),
			input = inputMode,
			keysTitle = title,
			keys = keys,
			dolly = dolly,
		}
	end
	function D.ui(now)
		if now < (D.uiAt or 0) then
			return
		end
		D.uiAt = now + 1 / 15
		HUD.DirectorUpdate(D.uiState(now))
		D.path()
	end
	-- the marker round the target, over its body
	function D.marker(cam)
		local m = D.overlay and D.targetModel()
		local root = m and (D.rootOf(VFX.Director.stillOf(m)) or D.rootOf(m))
		if not root then
			HUD.DirectorMarker(nil)
			return
		end
		local ok, v, onScreen = pcall(function()
			return cam:WorldToViewportPoint(root.Position - Vector3.new(0, 0.5, 0)) -- (the middle of the body)
		end)
		if not ok or not onScreen or v.Z <= 0.1 then
			HUD.DirectorMarker(nil)
			return
		end
		local perStud = (cam.ViewportSize.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2) / v.Z
		HUD.DirectorMarker(Vector2.new(v.X, v.Y), math.clamp(4 * perStud, 26, 320), D.target and string.upper(D.target.name))
	end

	---------------------------------------------------------------------------
	-- every frame (after the game's camera and its shakes: its frame is the one shown)
	---------------------------------------------------------------------------
	function D.step(dt)
		dt = math.clamp(tonumber(dt) or 1 / 60, 0, 0.1)
		local cam = workspace.CurrentCamera
		if not D.on or not cam then
			return
		end
		if not D.allowed() then
			D.stop("Gate")
			return
		end
		if FreeCam.on then
			FreeCam.toggle() -- (one free camera at a time)
		end
		local now = os.clock()
		D.timeStep(dt)
		local inp = D.read(dt)
		D.lens(dt, inp)
		if not D.passing() then
			if cam.CameraType ~= Enum.CameraType.Scriptable then
				cam.CameraType = Enum.CameraType.Scriptable
			end
			local base
			if D.mode == "DOLLY" then
				base = D.dollyStep()
			elseif D.mode == "ORBIT" then
				base = D.orbitStep(dt, inp)
			elseif D.mode == "TRACK" then
				base = D.trackStep(dt, inp)
			elseif D.mode == "FOLLOW" then
				base = D.followStep(dt, inp)
			end
			if not base then
				if D.mode ~= "FREE" then
					D.mode = "FREE"
					D.sync()
				end
				base = D.freeStep(dt, inp)
			end
			D.base = base
			cam.CFrame = base * CFrame.Angles(0, 0, math.rad(D.roll)) * D.shakeCF()
			cam.FieldOfView = D.fov
			local p = D.targetPoint()
			pcall(function()
				cam.Focus = CFrame.new(p or (base.Position + base.LookVector * 30))
			end)
		end
		D.focusStep(dt)
		D.stream(now, cam.CFrame.Position)
		VFX.Director.tick()
		D.sweep(now)
		D.mouse()
		D.marker(cam)
		D.ui(now)
	end

	---------------------------------------------------------------------------
	-- on and off
	---------------------------------------------------------------------------
	-- the movement pack's shift lock: off while it's on (Shift is the
	-- director's), its key off too; given back after
	function D.shiftLock(on)
		pcall(function()
			local pack = workspace:FindFirstChild("MovementSystem")
			local holder = pack and pack:FindFirstChild("StarterPlayerScripts")
			local lockScript = holder and holder:FindFirstChild("CustomShiftLock")
			local module = lockScript and lockScript:FindFirstChild("SmoothShiftLock")
			if not module then
				return
			end
			local lock = require(module)
			local toggle, edit = module:FindFirstChild("ToggleShiftLock"), module:FindFirstChild("EditConfig")
			if not on then
				D.saved.shift = lock:IsEnabled()
				if edit then
					edit:Fire("MANUALLY_TOGGLEABLE", false)
				end
				if D.saved.shift and toggle then
					toggle:Fire(false)
				end
			else
				if edit then
					edit:Fire("MANUALLY_TOGGLEABLE", true)
				end
				if D.saved and D.saved.shift and toggle then
					toggle:Fire(true)
				end
			end
		end)
	end
	-- Roblox's controls (walking, jumping; a phone's stick) off and on
	function D.controls(on)
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			local controls = module and require(module):GetControls()
			if controls then
				if on then
					controls:Enable()
				else
					controls:Disable()
				end
			end
		end)
	end
	function D.start()
		local cam = workspace.CurrentCamera
		if D.on or not cam or not D.allowed() then
			return false
		end
		if FreeCam.on then
			FreeCam.toggle()
		end
		D.on = true
		FreeCam.directing = true
		D.startedAt = os.clock()
		D.saved = {
			type = cam.CameraType, subject = cam.CameraSubject, fov = cam.FieldOfView, cf = cam.CFrame, focus = D.get(cam, "Focus"),
			mouse = D.get(UserInputService, "MouseBehavior"), icon = D.get(UserInputService, "MouseIconEnabled"),
		}
		-- it starts where the camera is
		D.base = cam.CFrame
		D.sync()
		D.vel = Vector3.zero
		D.fov, D.fovT, D.roll, D.rollT = cam.FieldOfView, cam.FieldOfView, 0, 0
		D.mode, D.dollyRun, D.rmb, D.latch, D.overlay = "FREE", nil, false, false, true
		D.frozen, D.scale, D.slow = false, 1, 1
		D.cOff, D.lastCenter, D.lostAt, D.padExit = Vector3.zero, nil, nil, nil
		D.rayParams = DevFly.params and DevFly.params() or nil
		-- your body: the shift lock off, standing still
		D.shiftLock(false)
		D.controls(false)
		pcall(HUD.ToggleTestMenu, false) -- (the menu it was switched on from)
		ContextActionService:BindActionAtPriority("QuirkDirectorSink", D.onInput, false, DIR.Priority or 3200, table.unpack(D.keyList()))
		cam.CameraType = Enum.CameraType.Scriptable
		VFX.Director.begin()
		VFX.Director.cuts = function(char)
			return D.cuts and char ~= nil and char == D.targetModel()
		end
		HUD.DirectorShow(true, {
			Mode = function(name)
				if name == "DOLLY" then
					if D.dollyRun then
						D.stopDolly()
					else
						D.play(D.loop)
					end
				else
					D.setMode(name)
				end
			end,
			Exit = function()
				D.stop("Off")
			end,
			Next = function()
				D.cycle(1)
			end,
			Slow = function()
				D.setSlow(D.slow % D.steps + 1)
			end,
			Freeze = function()
				D.setFreeze(not D.frozen)
			end,
			Frame = function()
				D.setFrame(D.frame + 1)
			end,
			-- (round 87 review) a phone has no H: HIDE takes the overlay off
			-- for the recording, a tap anywhere brings it back
			Hide = function()
				D.setOverlay(false)
			end,
			Reveal = function()
				D.setOverlay(true)
			end,
		})
		HUD.DirectorFrame(((DIR.Frame or {}).Modes or {})[D.frame] or "Off")
		HUD.DirectorGrid(D.grid)
		D.clean(true)
		if D.focus then
			D.setFocus(true, true)
		end
		if D.grade > 0 then
			D.applyGrade(true)
		end
		RunService:BindToRenderStep("QuirkDirector", Enum.RenderPriority.Camera.Value + 15, D.step)
		D.toast("DIRECTOR CAM")
		D.sound("DirectorOn")
		D.menu()
		return true
	end
	function D.stop(reason)
		if not D.on then
			return
		end
		D.sound("DirectorOff")
		D.on = false
		FreeCam.directing = false
		D.dollyRun, D.padExit, D.frozen = nil, nil, false
		pcall(function()
			RunService:UnbindFromRenderStep("QuirkDirector")
		end)
		pcall(function()
			ContextActionService:UnbindAction("QuirkDirectorSink")
		end)
		-- time back, the stills gone, everything it held given back
		VFX.Director.cuts = nil
		VFX.Director.finish()
		D.clean(false)
		for _, key in { "dof", "cc" } do
			if D[key] then
				D[key]:Destroy()
				D[key] = nil
			end
		end
		D.path()
		HUD.DirectorShow(false)
		-- (a cutscene let through ends with it)
		if VFX.InCinematic() then
			VFX.CancelCinematic()
		end
		-- the camera as it was (on the body you have now)
		local cam = workspace.CurrentCamera
		local s = D.saved or {}
		if cam then
			cam.CameraType = (s.type and s.type ~= Enum.CameraType.Scriptable) and s.type or Enum.CameraType.Custom
			local _, hum = getCharacter()
			local subject = s.subject
			if not (subject and subject.Parent and subject:IsDescendantOf(workspace)) then
				subject = hum
			end
			if subject then
				cam.CameraSubject = subject
			end
			if s.fov then
				cam.FieldOfView = s.fov
			end
			if s.cf then
				cam.CFrame = s.cf
			end
			if s.focus then
				pcall(function()
					cam.Focus = s.focus
				end)
			end
		end
		UserInputService.MouseBehavior = s.mouse or Enum.MouseBehavior.Default
		if s.icon ~= nil then
			UserInputService.MouseIconEnabled = s.icon
		end
		D.controls(true)
		D.shiftLock(true)
		D.saved = nil
		D.stopped = reason
		D.menu()
	end
	function D.toggle()
		if D.on then
			D.stop("Off")
		elseif D.allowed() then
			D.start()
		end
	end

	-- J (only for those it's for)
	function D.bind()
		if D.bound or not D.allowed() then
			return
		end
		D.bound = true
		ContextActionService:BindAction("QuirkDirectorKey", function(_, state)
			if state == Enum.UserInputState.Begin then
				D.toggle()
			end
			return Enum.ContextActionResult.Sink
		end, false, DIR.Key or Enum.KeyCode.J)
	end
	function D.unbind()
		if not D.bound then
			return
		end
		D.bound = false
		pcall(function()
			ContextActionService:UnbindAction("QuirkDirectorKey")
		end)
	end
	-- a new body (respawned while directing): stood still and hidden like
	-- the old one; the camera stays the director's
	function D.onCharacter()
		if not D.on then
			return
		end
		task.defer(function()
			if D.on then
				D.controls(false)
				D.bodyAt = 0
				D.sweep(os.clock())
			end
		end)
	end
	player:GetAttributeChangedSignal("DevFlyer"):Connect(function()
		if D.allowed() then
			D.bind()
		else
			D.unbind()
			D.stop("Gate")
		end
		D.menu()
	end)
	player.CharacterAdded:Connect(function(char)
		D.onCharacter(char)
	end)
	-- (round 87 review: the server's R15 -> R6 swap isn't always announced
	-- with a CharacterAdded - the body that takes over is stood still too)
	pcall(function()
		player:GetPropertyChangedSignal("Character"):Connect(function()
			D.onCharacter(player.Character)
		end)
	end)
	D.bind()
	-- the test menu: DIRECTOR CAM (in Dev only, under DEV FLIGHT) - shown
	-- only to those it's for, with its keys on a card
	table.insert(TEST_ITEMS, 1, { Id = "DirectorCam", Label = "DIRECTOR CAM", Toggle = true, Group = "Dev only" })
	function D.menu()
		HUD.ShowTestRow("DirectorCam", D.allowed())
		HUD.SetTestToggle("DirectorCam", D.on)
		HUD.SetTestInfo("DirectorCam", "DIRECTOR CAM", {
			"<b>J</b>  on / off  -  your body stays put, the HUD goes",
			"<b>WASD</b> fly, <b>E / Q</b> up / down, <b>RMB</b> look, <b>wheel</b> speed",
			"<b>1-4</b> FREE · ORBIT · TRACK · FOLLOW  -  <b>click / T</b> target",
			"<b>R</b> drops a dolly key, <b>Enter</b> rolls it (<b>L</b> loop)",
			"<b>Z / X</b> zoom, <b>, .</b> roll, <b>G</b> focus, <b>U</b> grade",
			"<b>- / =</b> slow motion, <b>Space</b> the freeze frame",
			"<b>B</b> letterbox / 9:16, <b>I</b> grid, <b>H</b> hides the overlay",
			"Controller: sticks + triggers, hold <b>B</b> to leave",
		})
	end
end

---------------------------------------------------------------------------
-- (round 87) POSSESS (Config.Possess): a dev takes over a training dummy or
-- the raid's Nomu (the server's Kit.PS decides everything; the dev flight's
-- people only - DevFlyer, as the DEV FLIGHT row). K takes the body he aims
-- at (or one off the test menu's POSSESS panel); K again, the panel's
-- LEAVE or his reset button brings him home. Once the server says he's in
-- (his Possessing attribute, the body's PossessedBy), this machine drives
-- it - it owns the body now: the walk / run / jump off his own controls
-- (the stick, the phone's too), shift lock turns it (round 92: no lock-on), and his
-- combat keys are the body's (a dummy: M1 the heroes' chain, F guard, Q
-- dash / the ragdoll cancel; the Nomu: M1 SWIPE, 1 SLAM, 2 CHARGE, 3 ROAR,
-- aimed where he aims) - his own parked body does nothing. The camera
-- rides the wisp across to the body (and back home), then follows it as
-- Roblox's own does (pulled back for the Nomu); the health bar is the
-- body's, a chip over it says whose, and the body's keys stand where his
-- moves were. Everything's given back as it was when he leaves: the
-- camera, the zoom, the keys, the phone's buttons, the reset button, the
-- HUD.
---------------------------------------------------------------------------
do
	local PSC = Config.Possess or {}
	local PS = {
		state = "Off", -- "Off" or "On" (in a body)
		saved = nil, -- (the camera and the zoom as they were, from the first body in)
		touch = {}, -- the phone's buttons as they were
		slotDown = {},
		readyAt = 0, askAt = -1, m1Count = 0, m1Last = 0, m1Next = 0, dashAt = 0, actAt = 0,
		m1Down = false, blocking = false,
	}
	DevFly.PS = PS -- (the tests read it as VFX.DevFly.PS)

	function PS.allowed()
		return PSC.Enabled ~= false and player:GetAttribute("DevFlyer") == true
	end
	function PS.send(kind, data)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, data)
	end
	-- his own body (alive or not, parked or not)
	function PS.own()
		local c = player.Character
		return c, c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
	end
	function PS.travel(a, b)
		local T = PSC.Travel or {}
		local d = (typeof(a) == "Vector3" and typeof(b) == "Vector3") and (a - b).Magnitude or 0
		return math.clamp(d * (T.PerStud or 0.004), T.Min or 0.38, T.Max or 0.85)
	end

	---------------------------------------------------------------------------
	-- the bodies there are (the server says yes or no)
	---------------------------------------------------------------------------
	function PS.candidates()
		local out = {}
		local function consider(m)
			if not m:IsA("Model") or Players:GetPlayerFromCharacter(m) or m:GetAttribute("TwiceClone") then
				return
			end
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				table.insert(out, m)
			end
		end
		for _, name in PSC.Folders or { "Dummies", "NomuRaid" } do
			local f = workspace:FindFirstChild(name)
			for _, m in f and f:GetChildren() or {} do
				if name ~= "NomuRaid" or m:GetAttribute("Boss") then
					consider(m)
				end
			end
		end
		for _, m in workspace:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Possessable") == true then
				consider(m)
			end
		end
		return out
	end
	function PS.kindOf(m)
		return (m:GetAttribute("Boss") and m.Parent and m.Parent.Name == "NomuRaid") and "Nomu" or "Dummy"
	end
	function PS.chest(m)
		local r = m:FindFirstChild("HumanoidRootPart")
		return r and r.Position + Vector3.new(0, math.min(r.Size.Y * 0.4, 2), 0) or m:GetPivot().Position
	end
	-- shift lock on (the mouse held in the middle)
	function PS.locked()
		local ok, mb = pcall(function()
			return UserInputService.MouseBehavior
		end)
		return ok and mb == Enum.MouseBehavior.LockCenter
	end
	-- the screen point he's aiming through: the mouse, or the middle (a
	-- controller, a phone, shift lock)
	function PS.screenPoint(cam)
		if inputMode ~= "Keyboard" or not UserInputService.MouseEnabled or PS.locked() then
			return cam.ViewportSize / 2
		end
		return UserInputService:GetMouseLocation()
	end
	-- K: the body under the aim - or the nearest one to it, within AimCone
	-- degrees (a body's width when it's close): no pixel hunting
	function PS.pick()
		local cam = workspace.CurrentCamera
		if not cam then
			return nil
		end
		local sp = PS.screenPoint(cam)
		local ray = cam:ViewportPointToRay(sp.X, sp.Y)
		local dir = ray.Direction.Unit
		local range = PSC.Range or 260
		local list = PS.candidates()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, VFX.Folder }
		local hit = workspace:Raycast(ray.Origin, dir * range, params)
		if hit and hit.Instance then
			for _, m in list do
				if m ~= PS.body and hit.Instance:IsDescendantOf(m) then
					return m
				end
			end
		end
		local best, bestAngle
		for _, m in list do
			if m ~= PS.body then
				local v = PS.chest(m) - ray.Origin
				local dist = v.Magnitude
				if dist > 0.5 and dist <= range then
					local angle = math.deg(math.acos(math.clamp(v.Unit:Dot(dir), -1, 1)))
					if angle <= math.max(PSC.AimCone or 8, math.deg(math.atan(3 / dist))) and (not bestAngle or angle < bestAngle) then
						best, bestAngle = m, angle
					end
				end
			end
		end
		return best
	end
	function PS.take(m)
		if not PS.allowed() or os.clock() - PS.askAt < (PSC.Gap or 0.5) then
			return
		end
		PS.askAt = os.clock()
		PS.send("PossessStart", { Target = m })
	end
	function PS.leave()
		if PS.state == "On" then
			PS.send("PossessLeave")
		end
	end
	-- K
	function PS.toggle()
		if not PS.allowed() then
			return
		end
		if PS.state == "On" then
			PS.leave()
			return
		end
		local m = PS.pick()
		if m then
			PS.take(m)
		else
			VFX.Play("PossessDeny", nil, { Why = "NotABody" }, true)
		end
	end

	---------------------------------------------------------------------------
	-- in and out (the server's word: his Possessing, the body's PossessedBy)
	---------------------------------------------------------------------------
	-- the body the server says he's in (not `skip`: the one he's just left)
	function PS.findMine(skip)
		for _, m in PS.candidates() do
			if m ~= skip and m:GetAttribute("PossessedBy") == player.UserId then
				return m
			end
		end
		return nil
	end
	function PS.sync()
		if player:GetAttribute("Possessing") == nil then
			PS.syncToken = nil
			if PS.state == "On" then
				PS.exit("Server")
			end
			return
		end
		-- (the body can get here a moment after the word: it's streaming in;
		-- and a new one - PossessSeq moved on - isn't the one he's in)
		local token = {}
		PS.syncToken = token
		local seq = player:GetAttribute("PossessSeq")
		local fresh = PS.state == "On" and seq ~= PS.seq
		task.spawn(function()
			local t0 = os.clock()
			while PS.syncToken == token and player:GetAttribute("Possessing") ~= nil and os.clock() - t0 < 5 do
				local body = PS.findMine(fresh and PS.body or nil) or (os.clock() - t0 > 1 and PS.findMine() or nil)
				if body then
					PS.seq = seq
					local label = tostring(player:GetAttribute("Possessing"))
					if body ~= PS.body then
						PS.bind(body, label)
					elseif PS.label ~= label then
						PS.label = label -- (its name came after it)
						PS.hud()
					end
					return
				end
				task.wait(0.05)
			end
		end)
	end

	-- his keys and buttons drive the body: every combat key, by what it is
	function PS.slots()
		if PS.keyMap then
			return PS.keyMap, PS.keyList
		end
		local map, list = {}, {}
		local function add(keys, slot)
			for _, k in keys or {} do
				if not map[k.Name] then
					map[k.Name] = slot
					table.insert(list, k)
				end
			end
		end
		add(Config.M1Keys, "M1")
		for i, keys in Config.AbilityKeys do
			add(keys, "Ability" .. i)
		end
		add(Config.SpecialKeys, "Special")
		add(Config.UltKeys, "Ult")
		add(Config.ExtraKeys or { Enum.KeyCode.Four }, "Extra")
		add(Config.DashKeys, "Dash")
		add(Config.BlockKeys, "Block")
		add(Config.FinisherKeys, "Finish")
		add(Config.ContextKeys, "Context")
		add(Config.EmoteKeys, "Emote")
		add(Config.UseItemKeys, "Item")
		PS.keyMap, PS.keyList = map, list
		return map, list
	end
	function PS.onKey(_, state, input)
		if uiOpen() and fromGamepad(input) then
			return Enum.ContextActionResult.Pass
		end
		local code = input and input.KeyCode
		local slot = code and PS.slots()[code.Name]
		if not slot then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			PS.slot(slot, true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			PS.slot(slot, false)
		end
		return Enum.ContextActionResult.Sink
	end
	-- the phone's round buttons: the body's too, while he's in it
	function PS.touchSwap()
		local function press(slot)
			return {
				down = function()
					PS.slot(slot, true)
				end,
				up = function()
					PS.slot(slot, false)
				end,
			}
		end
		local map = {
			QuirkPunch = "M1", QuirkAbility1 = "Ability1", QuirkAbility2 = "Ability2", QuirkAbility3 = "Ability3",
			QuirkDash = "Dash", QuirkBlock = "Block", QuirkSpecial = "Special", QuirkUlt = "Ult",
			QuirkExtra = "Extra", QuirkFinish = "Finish", QuirkEmote = "Emote",
		}
		for name, slot in map do
			if PS.touch[name] == nil then
				PS.touch[name] = Touch.handlers[name] or false
			end
			Touch.handlers[name] = press(slot)
		end
	end
	function PS.touchRestore()
		for name, h in PS.touch do
			Touch.handlers[name] = h or nil
		end
		table.clear(PS.touch)
	end
	-- the reset button takes him home (his own body isn't the one to reset)
	function PS.resetHook(on)
		if on then
			if not PS.resetEvent then
				PS.resetEvent = Instance.new("BindableEvent")
				PS.resetEvent.Event:Connect(function()
					PS.leave()
				end)
			end
			PS.resetSet = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", PS.resetEvent)
			end)
		elseif PS.resetSet then
			PS.resetSet = false
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", true)
			end)
		end
	end

	-- the first body: his own stops, his keys become the body's
	function PS.enter()
		local cam = workspace.CurrentCamera
		PS.saved = {
			Min = player.CameraMinZoomDistance, Max = player.CameraMaxZoomDistance,
			Zoom = cam and math.clamp((cam.CFrame.Position - cam.Focus.Position).Magnitude, 0.5, 400) or 12.5,
		}
		if DevFly.active and DevFly.stop then
			DevFly.stop("Server")
		end
		if BlastFly.active and BlastFly.stop then
			BlastFly.stop("Action")
		end
		if FloatFly.active and FloatFly.stop then
			FloatFly.stop("Hit")
		end
		if HawksFly.active and HawksFly.stop then
			HawksFly.stop("Key")
		end
		guardHeld = false
		stopBlock()
		CombatInput.pending = nil
		ContextActionService:BindActionAtPriority("QuirkPossessKeys", PS.onKey, false, 3100, table.unpack(select(2, PS.slots())))
		RunService:BindToRenderStep("QuirkPossessDrive", Enum.RenderPriority.Input.Value + 1, PS.drive)
		PS.touchSwap()
		PS.resetHook(true)
	end
	-- into a body (the first, or one straight after another)
	function PS.bind(body, label)
		local hum, root = body:FindFirstChildOfClass("Humanoid"), body:FindFirstChild("HumanoidRootPart")
		if not hum or not root then
			return
		end
		local was = PS.root and PS.root.Parent and PS.root.Position
		if PS.state == "On" then
			PS.release()
		else
			PS.enter()
		end
		PS.state = "On"
		PS.body, PS.hum, PS.root, PS.label = body, hum, root, tostring(label or body.Name)
		PS.kind = PS.kindOf(body)
		PS.moves = (PSC.Moves or {})[PS.kind] or {}
		PS.m1Count, PS.m1Last, PS.m1Next, PS.dashAt, PS.blocking = 0, 0, 0, 0, false
		-- (this machine runs it now: no tripping over by itself, as the server has it)
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end)
		HUD.BindHumanoid(hum)
		if PS.kind == "Dummy" then
			-- (its guard and its ragdoll cancel's meter on the bar, not his)
			HUD.BindGuard(body)
			local function evasive()
				HUD.SetEvasive(body:GetAttribute("Evasive") or 0, body:GetAttribute("Ragdolled") == true)
			end
			PS.bodyConns = {
				body:GetAttributeChangedSignal("Evasive"):Connect(evasive),
				body:GetAttributeChangedSignal("Ragdolled"):Connect(evasive),
			}
			evasive()
		end
		PS.hud()
		-- the camera rides the wisp across
		local _, _, myRoot = PS.own()
		local from = was or (myRoot and myRoot.Position) or root.Position
		local t = PS.travel(from, root.Position)
		PS.readyAt = os.clock() + t
		-- (the Nomu: pulled back for its size; a dummy: his own zoom)
		PS.flyTo(hum, t, PS.kind == "Nomu" and ((PSC.Nomu or {}).Zoom or 30) or (PS.saved and PS.saved.Zoom))
	end
	function PS.hud()
		if PS.state == "On" then
			HUD.Possess({ Name = PS.label, Body = PS.body, Moves = PS.moves, Mode = inputMode, Run = PS.kind == "Dummy", Guard = PS.kind == "Dummy" })
		end
	end
	-- out of this body (into another, or home)
	function PS.release()
		local hum, root = PS.hum, PS.root
		for _, c in PS.bodyConns or {} do
			c:Disconnect()
		end
		PS.bodyConns = nil
		if hum and hum.Parent then
			pcall(function()
				hum:Move(Vector3.zero, false)
			end)
			PS.lastMove = Vector3.zero
			hum.AutoRotate = true
			hum.Jump = false
		end
		if root and root.Parent then
			for _, d in root:GetChildren() do
				if d.Name == "PossessDash" or d.Name == "PossessDashAttachment" or d.Name == "LungeAttachment" then
					d:Destroy()
				end
			end
		end
		table.clear(PS.slotDown)
		PS.m1Down, PS.blocking = false, false
	end
	-- home: everything as it was
	function PS.exit(reason)
		if PS.state ~= "On" then
			return
		end
		local from = PS.root and PS.root.Parent and PS.root.Position
		PS.release()
		PS.state = "Off"
		PS.body, PS.hum, PS.root, PS.kind, PS.label, PS.moves = nil, nil, nil, nil, nil, nil
		pcall(function()
			ContextActionService:UnbindAction("QuirkPossessKeys")
		end)
		pcall(function()
			RunService:UnbindFromRenderStep("QuirkPossessDrive")
		end)
		PS.touchRestore()
		PS.resetHook(false)
		HUD.Possess(nil)
		local char, myHum, myRoot = PS.own()
		if myHum then
			HUD.BindHumanoid(myHum)
			HUD.BindGuard(char)
			HUD.SetEvasive(char:GetAttribute("Evasive") or 0, char:GetAttribute("Ragdolled") == true)
		end
		refreshQuirk() -- (the hero's move boxes, and a phone's buttons' names)
		HUD.SetInputMode(inputMode) -- (the key line along the bottom)
		local saved = PS.saved
		PS.saved = nil
		if reason ~= "Gone" and myHum and myRoot and myHum.Health > 0 and saved then
			PS.flyTo(myHum, PS.travel(from or myRoot.Position, myRoot.Position), saved.Zoom, saved)
		else
			-- (a new body: straight onto it)
			PS.endFly()
			local cam = workspace.CurrentCamera
			if cam and myHum and not VFX.InCinematic() then
				cam.CameraSubject = myHum
				cam.CameraType = Enum.CameraType.Custom
			end
			PS.setZoom(saved and saved.Zoom, saved)
		end
	end

	---------------------------------------------------------------------------
	-- the camera
	---------------------------------------------------------------------------
	-- the zoom limits his own way: lo..hi (in an order Roblox takes)
	function PS.limits(lo, hi)
		if lo > player.CameraMaxZoomDistance then
			player.CameraMaxZoomDistance = hi
			player.CameraMinZoomDistance = lo
		else
			player.CameraMinZoomDistance = lo
			player.CameraMaxZoomDistance = hi
		end
	end
	-- held at `zoom` a moment (Roblox's camera comes to it), then: home, the
	-- limits as they were; the Nomu, kept MinZoom off it; a dummy, his own
	function PS.setZoom(zoom, restore)
		if not zoom then
			return
		end
		PS.limits(zoom, zoom)
		local token = {}
		PS.zoomToken = token
		task.delay(0.12, function()
			if PS.zoomToken ~= token then
				return
			end
			if restore then
				if PS.state == "Off" then
					PS.limits(restore.Min, restore.Max)
				end
			elseif PS.state == "On" and PS.saved then
				if PS.kind == "Nomu" then
					PS.limits(math.max(PS.saved.Min, (PSC.Nomu or {}).MinZoom or 20), math.max(PS.saved.Max, zoom))
				else
					PS.limits(PS.saved.Min, PS.saved.Max)
				end
			end
		end)
	end
	-- the camera rides the wisp: from where it is to behind hum's body over
	-- t, then it's Roblox's own camera on that body, at `zoom`
	function PS.flyTo(hum, t, zoom, restore)
		local cam = workspace.CurrentCamera
		PS.endFly()
		if not cam then
			return
		end
		local token = {}
		PS.flight = token
		local function land()
			if PS.flight ~= token then
				return
			end
			PS.flight = nil
			PS.flying = false
			pcall(function()
				RunService:UnbindFromRenderStep("QuirkPossessFly")
			end)
			if hum.Parent then
				cam.CameraSubject = hum
			end
			cam.CameraType = Enum.CameraType.Custom
			PS.setZoom(zoom, restore)
		end
		local body = hum.Parent
		local root = body and body:FindFirstChild("HumanoidRootPart")
		if not root or VFX.InCinematic() or t < 0.06 then
			land()
			return
		end
		local from = cam.CFrame
		local look = cam.CFrame.LookVector
		local dist = zoom or math.clamp((cam.CFrame.Position - cam.Focus.Position).Magnitude, 0.5, 400)
		local lift = 1.5 + math.max(root.Size.Y / 2 - 1, 0)
		PS.flying = true
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		RunService:BindToRenderStep("QuirkPossessFly", Enum.RenderPriority.Camera.Value + 4, function()
			if PS.flight ~= token then
				return
			end
			local k = math.clamp((os.clock() - t0) / t, 0, 1)
			local e = k * k * (3 - 2 * k)
			local focus = root.Position + Vector3.new(0, lift, 0)
			local goal = CFrame.lookAt(focus - look * dist, focus)
			local span = (from.Position - goal.Position).Magnitude
			local pos = from.Position:Lerp(goal.Position, e) + Vector3.new(0, span * 0.08 * 4 * e * (1 - e), 0)
			cam.CFrame = CFrame.new(pos) * from.Rotation:Lerp(goal.Rotation, e)
			if k >= 1 then
				land()
			end
		end)
	end
	function PS.endFly()
		local was = PS.flight ~= nil
		PS.flight = nil
		PS.flying = false
		pcall(function()
			RunService:UnbindFromRenderStep("QuirkPossessFly")
		end)
		local cam = workspace.CurrentCamera
		if was and cam and cam.CameraType == Enum.CameraType.Scriptable and not VFX.InCinematic() then
			cam.CameraType = Enum.CameraType.Custom
		end
	end

	---------------------------------------------------------------------------
	-- driving it
	---------------------------------------------------------------------------
	-- what he's pushing: Roblox's own controls (keys, the stick, the phone's
	-- thumbstick - camera-relative), else his own Humanoid's MoveDirection
	function PS.controls()
		if PS.ctl then
			return PS.ctl
		end
		if os.clock() < (PS.ctlRetry or 0) then
			return nil
		end
		PS.ctlRetry = os.clock() + 2
		local ok, ctl = pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			return module and require(module):GetControls()
		end)
		PS.ctl = ok and ctl or nil
		return PS.ctl
	end
	function PS.moveVector()
		local ctl = PS.controls()
		if ctl then
			local ok, v = pcall(function()
				return ctl:GetMoveVector()
			end)
			if ok and typeof(v) == "Vector3" then
				return v, true
			end
		end
		local _, myHum = PS.own()
		return myHum and myHum.MoveDirection or Vector3.zero, false
	end
	-- ...in the world, flat
	function PS.worldMove()
		local v, rel = PS.moveVector()
		local cam = workspace.CurrentCamera
		if rel and cam then
			local f, r = flat(cam.CFrame.LookVector), flat(cam.CFrame.RightVector)
			f = f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, -1)
			r = r.Magnitude > 0.05 and r.Unit or Vector3.new(1, 0, 0)
			v = r * v.X - f * v.Z
		end
		return flat(v)
	end
	-- something else has the body (its own state, the server, a Nomu move)
	function PS.held()
		local b, r = PS.body, PS.root
		if r.Anchored or b:GetAttribute("PossessBusy") or r:FindFirstChild("Knockback") or r:FindFirstChild("FinisherLaunch") then
			return true
		end
		for _, flag in { "Ragdolled", "Grabbed", "Frozen", "BeingFinished" } do
			if b:GetAttribute(flag) then
				return true
			end
		end
		return false
	end
	-- free to throw something
	function PS.free()
		if os.clock() < PS.readyAt or PS.held() then
			return false
		end
		for _, flag in { "Stunned", "Clashing", "Countering" } do
			if PS.body:GetAttribute(flag) then
				return false
			end
		end
		return true
	end
	function PS.running()
		return sprintHeld or sprintToggle or stickMagnitude() >= (Config.AutoSprintStick or 0.9)
	end
	function PS.face(dir)
		local root = PS.root
		local f = flat(dir or Vector3.zero)
		if f.Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + f.Unit)
		end
	end
	-- where he's aiming (through the mouse / the middle)
	function PS.aim()
		local root = PS.root
		local cam = workspace.CurrentCamera
		local sp = PS.screenPoint(cam)
		local ray = cam:ViewportPointToRay(sp.X, sp.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, PS.body, VFX.Folder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 600, params)
		local pos = hit and hit.Position or (ray.Origin + ray.Direction.Unit * 600)
		local dir = pos - root.Position
		return dir.Magnitude > 1 and dir.Unit or cam.CFrame.LookVector, pos
	end

	-- every frame (just after Roblox reads the controls)
	function PS.drive(dt)
		if PS.state ~= "On" then
			return
		end
		local body, hum, root = PS.body, PS.hum, PS.root
		if not (body.Parent and hum.Parent and root.Parent) then
			return
		end
		local cam = workspace.CurrentCamera
		-- the camera stays on the body (a cutscene's end hands it back to him)
		local _, myHum = PS.own()
		if cam and not PS.flying and cam.CameraType == Enum.CameraType.Custom and not VFX.InCinematic()
			and (cam.CameraSubject == nil or cam.CameraSubject == myHum) then
			cam.CameraSubject = hum
		end
		local drive = os.clock() >= PS.readyAt and not PS.held() and hum.Health > 0
		local mv, rel = PS.moveVector()
		local going = drive and mv.Magnitude > 0.01
		PS.lastMove = going and mv or Vector3.zero -- (what it was told this frame: the tests read it)
		pcall(function()
			if going then
				hum:Move(mv, rel)
			else
				hum:Move(Vector3.zero, false)
			end
		end)
		if drive and myHum and slamJump.read(myHum) then
			hum.Jump = true
		end
		-- a dummy runs with sprint; its guard slows it (a stun's own speed is left alone)
		if drive and PS.kind == "Dummy" and not body:GetAttribute("Stunned") then
			local D = PSC.Dummy or {}
			local want = PS.running() and (D.RunSpeed or 26) or (D.WalkSpeed or 16)
			if PS.blocking then
				want *= D.BlockWalk or 0.45
			end
			if math.abs(hum.WalkSpeed - want) > 0.01 then
				hum.WalkSpeed = want
			end
		end
		-- facing: the camera in shift lock
		local face
		if cam and PS.locked() then
			face = flat(cam.CFrame.LookVector)
		end
		if drive and face and face.Magnitude > 0.05 then
			hum.AutoRotate = false
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + face.Unit), math.min(1, (dt or 1 / 60) * 18))
		elseif not hum.AutoRotate then
			hum.AutoRotate = true
		end
		-- held M1: the chain goes on (the Nomu's swipe comes round again)
		if drive and (m1Held or PS.m1Down) then
			PS.fire("M1")
		end
	end

	-- a key went down / up
	function PS.actFor(slot)
		for _, m in PS.moves or {} do
			if m.Slot == slot then
				return m.Act
			end
		end
		return nil
	end
	function PS.slot(slot, down)
		if PS.state ~= "On" then
			return
		end
		PS.slotDown[slot] = down or nil
		if slot == "M1" then
			PS.m1Down = down
		end
		if PS.kind == "Dummy" and slot == "Block" then
			PS.block(down)
		elseif down then
			PS.fire(slot)
		end
	end
	function PS.fire(slot)
		local act = PS.actFor(slot)
		if not act then
			return
		end
		if PS.kind == "Nomu" then
			PS.nomuAct(act)
		elseif act == "M1" then
			PS.punch()
		elseif act == "Dash" then
			PS.dash()
		end
	end

	-- A DUMMY: the heroes' M1 chain (the swing plays here at once; the
	-- server lands it), its step in, the guard, the dash
	function PS.punch()
		local now = os.clock()
		if now < PS.m1Next or not PS.free() then
			return
		end
		local M1 = Config.M1
		if now - PS.m1Last > M1.ComboReset then
			PS.m1Count = 0
		end
		PS.m1Count = PS.m1Count % M1.ComboLength + 1
		PS.m1Last = now
		local finisher = PS.m1Count == M1.ComboLength
		PS.m1Next = now + (finisher and M1.FinisherCooldown or M1.Cooldown)
		if PS.blocking then
			PS.block(false)
		end
		local dir, pos = PS.aim()
		PS.face(dir)
		VFX.Play("Punch", PS.body, { Count = PS.m1Count, Finisher = finisher }, false)
		PS.lunge(finisher)
		PS.send("PossessAct", { Act = "M1", CF = PS.root.CFrame, Aim = pos })
	end
	-- the small committed step in the coil (a walk is its own step)
	function PS.lunge(finisher)
		local K, root, hum = VFX.M1Kit, PS.root, PS.hum
		if not (K and K.glide and K.mover and K.room) or hum.FloorMaterial == Enum.Material.Air or PS.worldMove().Magnitude > 0.1 then
			return
		end
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.05 then
			return
		end
		look = look.Unit
		local STEP = Config.M1.Step or {}
		local contact = (Config.M1.Contact or {})[finisher and 4 or math.min(PS.m1Count, 3)] or 0.12
		local d = math.max(contact - 0.02, 0.06)
		local function left()
			return K.room(root, look, 99)
		end
		local room = math.min(finisher and (STEP.Finisher or 0.9) or (STEP.Distance or 0.4), left())
		if room >= 0.05 then
			K.glide(K.mover(root, "LungeAttachment", d), look, room, d, "bump", left)
		end
	end
	function PS.block(on)
		on = on == true
		if on == PS.blocking or (on and not PS.free()) then
			return
		end
		PS.blocking = on
		PS.send("PossessAct", { Act = "Block", On = on })
	end
	function PS.dash()
		local body, root = PS.body, PS.root
		-- (down: the ragdoll cancel, once its meter's full - the server checks)
		if body:GetAttribute("Ragdolled") or body:GetAttribute("ComboStun") then
			local mv = PS.worldMove()
			PS.send("PossessAct", { Act = "Evade", Dir = mv.Magnitude > 0.1 and mv.Unit or root.CFrame.RightVector })
			return
		end
		local now = os.clock()
		if now < PS.dashAt or not PS.free() then
			return
		end
		local D = (PSC.Dummy or {}).Dash or {}
		PS.dashAt = now + (D.Cooldown or 1)
		local look = flat(root.CFrame.LookVector)
		look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
		local mv = PS.worldMove()
		local dir = mv.Magnitude > 0.1 and mv.Unit or look
		local att = Instance.new("Attachment")
		att.Name = "PossessDashAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "PossessDash"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		local okMass, mass = pcall(function()
			return root.AssemblyMass
		end)
		lv.MaxForce = math.max(okMass and tonumber(mass) or 0, 1) * 6000
		lv.VectorVelocity = dir * (D.Speed or 64)
		lv.Parent = root
		task.delay(D.Time or 0.2, function()
			lv:Destroy()
			att:Destroy()
		end)
		local side = dir:Dot(look)
		local kind = side > 0.5 and "Front" or (side < -0.5 and "Back" or "Side")
		VFX.Play("Dash", body, { Kind = kind, Dir = dir }, false)
		VFX.PlaySound("Dash", root.Position, 0.9)
		PS.send("PossessAct", { Act = "Dash", Dir = dir })
	end
	-- THE NOMU: its moves, where he aims (the raid's own on the server)
	function PS.nomuAct(act)
		local now = os.clock()
		if not PS.free() or now - PS.actAt < 0.15 then
			return
		end
		local ready = tonumber(PS.body:GetAttribute("PossessCd_" .. act))
		if ready and ready > workspace:GetServerTimeNow() + 0.05 then
			return
		end
		PS.actAt = now
		local dir, pos = PS.aim()
		PS.face(dir)
		PS.send("PossessAct", { Act = act, Aim = pos })
	end

	---------------------------------------------------------------------------
	-- the key, the test menu's row and its panel (devs only)
	---------------------------------------------------------------------------
	function PS.bindKey()
		if PS.allowed() and not PS.keyBound then
			PS.keyBound = true
			ContextActionService:BindAction("QuirkPossess", function(_, state)
				if state == Enum.UserInputState.Begin then
					PS.toggle()
				end
				return Enum.ContextActionResult.Sink
			end, false, PSC.Key or Enum.KeyCode.K)
		elseif not PS.allowed() and PS.keyBound then
			PS.keyBound = false
			pcall(function()
				ContextActionService:UnbindAction("QuirkPossess")
			end)
		end
	end
	-- the panel's list: every body, the one he's in first, then nearest
	function PS.list()
		local out = {}
		local _, _, myRoot = PS.own()
		local here = (PS.root and PS.root.Parent and PS.root.Position) or (myRoot and myRoot.Position)
		for _, m in PS.candidates() do
			local root = m:FindFirstChild("HumanoidRootPart")
			local by = m:GetAttribute("PossessedBy")
			local state = (by == player.UserId and "Mine") or (by ~= nil and "Taken") or "Free"
			local name, color
			if PS.kindOf(m) == "Nomu" then
				name, color = tostring(m:GetAttribute("BossName") or "HIGH-END NOMU"), Color3.fromRGB(210, 34, 44)
			else
				local k = Config.DummyKind and Config.DummyKind(m:GetAttribute("DummyKind") or "")
				name, color = k and tostring(k.Label or k.Id) or string.upper(m.Name), k and k.Color or Color3.fromRGB(226, 196, 156)
			end
			local d = (here and root) and math.floor((root.Position - here).Magnitude + 0.5) or 0
			local sub = state == "Mine" and "you're in it" or string.format("%d studs away%s", d, state == "Taken" and "  ·  someone's in it" or "")
			if PS.kindOf(m) == "Nomu" then
				sub = "RAID BOSS  ·  " .. sub
			end
			table.insert(out, { Model = m, Name = name, Sub = sub, Color = color, State = state, Dist = state == "Mine" and -1 or d })
		end
		table.sort(out, function(a, b)
			return a.Dist < b.Dist
		end)
		return out
	end
	table.insert(TEST_ITEMS, 1, { Id = "PossessPanel", Label = "Possess...", Group = "Dev only" })
	-- (refreshTestToggles: the row for devs only; the panel, for testers who are)
	function PS.menu()
		if player:GetAttribute("Tester") then
			HUD.BuildPossessPanel({
				List = PS.list,
				Pick = PS.take,
				Leave = PS.leave,
				In = function()
					return PS.state == "On" and PS.label or nil
				end,
			})
		end
		HUD.ShowTestRow("PossessPanel", PS.allowed())
		if not PS.allowed() then
			HUD.TogglePossessPanel(false)
		end
	end

	player:GetAttributeChangedSignal("Possessing"):Connect(PS.sync)
	player:GetAttributeChangedSignal("PossessSeq"):Connect(PS.sync) -- (one body straight into another of the same name)
	player:GetAttributeChangedSignal("DevFlyer"):Connect(function()
		PS.bindKey()
		PS.menu()
	end)
	player.CharacterAdded:Connect(function()
		if PS.state == "On" then
			PS.exit("Gone") -- (a new body: the game's own camera takes it from here)
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		task.defer(PS.hud) -- (after the game's own read of it: the dock's key caps follow)
	end)
	-- (round 87 review) his hero's HUD redraws itself while he's away (his
	-- ult running out, a form's timer, Deku's 4th): the body's goes back on
	-- top, after it
	for _, attr in { "UltActive", "QuirkAlt", "QuirkPick", "Blueprint" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if PS.state == "On" then
				task.defer(PS.hud)
			end
		end)
	end
	PS.bindKey()
	if player:GetAttribute("Possessing") ~= nil then
		task.defer(PS.sync)
	end
end

---------------------------------------------------------------------------
-- (round 88) THE CARRY (Config.DevFlight.Carry) on the flyer's own screen:
-- the dev flight's 5th move. While he flies, the move bar is his hero's
-- moves (they still work) plus GRAB - Z, R3 on a controller, the phone's
-- GRAB button - which reaches out at once and asks the server for whoever's
-- in front of him (the one he's aiming at, as a hint). The server's word -
-- his body's DevCarrying - swaps the bar for the carry's moves: 1 SLAM, 2
-- THROW, 3 RAM, 4 DROP (and the flight's own keys that mean the same: X /
-- RB, the dive, is the SLAM; Q / Y, the burst, the RAM; Z / R3 again DROP;
-- the phone's 1 / 2 / 3 and DROP), and his own moves wait (his hands are
-- full: busy()). SLAM dives him (the flight's dive, steep, a little ahead)
-- and tells the server where he hit the street; THROW swings them and asks;
-- RAM flies him flat out (DevFly.fly asks CR.ramStep) and lets them go at
-- the end (RAM again, an unbreakable wall, the street, or Ram.Time); DROP
-- lets go. Let go - by him or by the server - the flight's bar again; the
-- flight over (landed, switched off, dead, a new body, a new hero), exactly
-- the bar he had before (HUD.Carry(nil), his key line, his phone's
-- buttons). The one he holds, if it's this screen's own body, gets a chip:
-- HELD BY <who>, and how long. (A block of its own: DevFly.CR - the flight
-- calls it as it starts, stops, flies, lands and hits a wall.)
---------------------------------------------------------------------------
do
	local CRC = (Config.DevFlight or {}).Carry or {}
	local CR = { mode = "Off", touch = {}, grabAt = -1e9, actAt = -1e9, ACT = {}, KEYS = {}, conns = {} }
	DevFly.CR = CR
	for _, m in CRC.Moves or {} do
		for _, k in m.Keys or {} do
			if not CR.ACT[k.Name] then
				CR.ACT[k.Name] = m.Act
				table.insert(CR.KEYS, k)
			end
		end
	end

	function CR.allowed()
		return CRC.Enabled ~= false and DevFly.canFly ~= nil and DevFly.canFly() -- (round 92: a grant's flight carries too)
	end
	local function send(kind, data)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, data)
	end
	-- his body says he holds someone (the server's word)
	function CR.holding()
		local char = player.Character
		return char ~= nil and char:GetAttribute("DevCarrying") == true
	end
	-- who (the body the server marked CarriedBy him: VFX.CRX's pair)
	function CR.victim()
		local VC = VFX.CRX
		local char = player.Character
		local p = VC and char and VC.carriers[char]
		return p and p.victim or nil
	end
	function CR.nameOf(model)
		local plr = model and Players:GetPlayerFromCharacter(model)
		return plr and plr.DisplayName or (model and model.Name) or ""
	end
	-- the move going (the bar lights it)
	function CR.busyAct()
		return (CR.slamming and "Slam") or (CR.ramming and "Ram") or (CR.throwing and "Throw") or nil
	end

	---------------------------------------------------------------------------
	-- the bar, the keys, the phone's buttons: the flight's, the carry's, his own
	---------------------------------------------------------------------------
	function CR.hud()
		if CR.mode == "Off" then
			HUD.Carry(nil)
			HUD.SetInputMode(inputMode) -- (the key line along the bottom: his own, as it was)
			return
		end
		local v = CR.victim()
		HUD.Carry({
			Mode = CR.mode, Input = inputMode, Name = CR.nameOf(v), Ends = v and v:GetAttribute("CarryEnds"),
			Max = CRC.MaxHold or 6, Busy = CR.busyAct(), Moves = CRC.Moves,
		})
	end
	function CR.grabKey()
		if CR.mode == "Carry" then
			CR.act("Drop")
		else
			CR.grab()
		end
	end
	function CR.onGrabKey(_, state, input)
		if uiOpen() and fromGamepad(input) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			CR.grabKey()
		end
		return Enum.ContextActionResult.Sink
	end
	function CR.onKey(_, state, input)
		if uiOpen() and fromGamepad(input) then
			return Enum.ContextActionResult.Pass
		end
		local code = input and input.KeyCode
		local act = code and CR.ACT[code.Name]
		if not act then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			CR.act(act)
		end
		return Enum.ContextActionResult.Sink
	end
	-- the phone's 1 / 2 / 3: SLAM / THROW / RAM while he holds someone (his
	-- own handlers kept, and put back as they were)
	function CR.touchSwap(on)
		if on then
			for name, act in { QuirkAbility1 = "Slam", QuirkAbility2 = "Throw", QuirkAbility3 = "Ram" } do
				if CR.touch[name] == nil then
					CR.touch[name] = Touch.handlers[name] or false
				end
				Touch.handlers[name] = {
					down = function()
						CR.act(act)
					end,
				}
			end
		else
			for name, h in CR.touch do
				Touch.handlers[name] = h or nil
			end
			table.clear(CR.touch)
		end
	end
	function CR.setMode(mode)
		local was = CR.mode
		if mode == was then
			if mode ~= "Off" then
				CR.hud()
			end
			return
		end
		CR.mode = mode
		pcall(function()
			ContextActionService:UnbindAction("QuirkCarryKeys")
		end)
		if mode == "Off" then
			pcall(function()
				ContextActionService:UnbindAction("QuirkCarryGrab")
			end)
		elseif was == "Off" then
			ContextActionService:BindActionAtPriority("QuirkCarryGrab", CR.onGrabKey, false, CRC.Priority or 3050,
				CRC.Key or Enum.KeyCode.Z, CRC.PadKey or Enum.KeyCode.ButtonR3)
		end
		if mode == "Carry" then
			ContextActionService:BindActionAtPriority("QuirkCarryKeys", CR.onKey, false, (CRC.Priority or 3050) + 10, table.unpack(CR.KEYS))
		end
		CR.touchSwap(mode == "Carry")
		Touch.handlers.QuirkCarryGrab = mode ~= "Off" and { down = CR.grabKey } or nil
		if mode ~= "Carry" then
			CR.ramming, CR.slamming, CR.throwing = nil, nil, nil
		end
		if was == "Carry" then
			refreshHud(false) -- (a phone's buttons: his hero's names again)
		end
		CR.hud()
	end
	-- which it is now: off the flight, flying, or holding someone
	function CR.sync()
		if not DevFly.active or not CR.allowed() then
			CR.setMode("Off")
		elseif CR.holding() then
			CR.setMode("Carry")
		else
			CR.setMode("Flight")
		end
	end
	-- (from the flight) on / off
	function CR.flightOn()
		CR.sync()
	end
	function CR.flightOff(_reason)
		-- (the server lets go with the flight anyway: this is at once. (round
		-- 88 review) Whatever ended it - "Gone" too: his own movers lost with
		-- his body still here - or the server held them off a dev on foot)
		if CR.holding() then
			send("CarryDrop")
		end
		CR.sync()
	end

	---------------------------------------------------------------------------
	-- GRAB: reach out (at once, on his screen) and ask for whoever's there
	---------------------------------------------------------------------------
	-- the one he's reaching at (a hint: the server picks for itself if it doesn't hold up)
	function CR.pick(char, root, aim)
		local F = DevFly.F
		local speed = F and F.vel and F.vel.Magnitude or 0
		local reach = math.min((CRC.Reach or 10) + speed * (CRC.PerSpeed or 0.08), CRC.MaxReach or 30)
		local list = {}
		for _, plr in Players:GetPlayers() do
			if plr.Character and plr.Character ~= char then
				table.insert(list, plr.Character)
			end
		end
		for _, name in { "Dummies", "TwiceClones" } do
			local f = workspace:FindFirstChild(name)
			for _, m in f and f:GetChildren() or {} do
				table.insert(list, m)
			end
		end
		local best, bestScore
		for _, m in list do
			local mr = m:IsA("Model") and m:FindFirstChild("HumanoidRootPart")
			local hum = mr and m:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not (m:GetAttribute("Possessed") or m:GetAttribute("Parked") or m:GetAttribute("CarriedBy") or m:GetAttribute("Boss")) then
				local v = mr.Position - root.Position
				local dist = v.Magnitude
				local dot = dist > 3 and v.Unit:Dot(aim) or 1
				if dist <= reach and dot >= (CRC.Cone or 0.35) then
					local score = dist * (2 - dot)
					if not bestScore or score < bestScore then
						best, bestScore = m, score
					end
				end
			end
		end
		return best
	end
	function CR.grab()
		if CR.mode ~= "Flight" or not DevFly.active or not CR.allowed() then
			return
		end
		local F = DevFly.F
		if not (F.state == "Fly" or F.state == "Brake" or F.state == "Ascent") then
			return
		end
		local now = os.clock()
		if now - CR.grabAt < (CRC.Gap or 0.35) then
			return
		end
		local char, _, root = getCharacter()
		if not char then
			return
		end
		CR.grabAt = now
		local dir = getAim(root)
		VFX.Play("DevCarry", char, { Kind = "Reach", Dir = dir }, true)
		send("CarryGrab", { Dir = dir, Target = CR.pick(char, root, dir) })
	end

	---------------------------------------------------------------------------
	-- holding them: SLAM, THROW, RAM, DROP
	---------------------------------------------------------------------------
	function CR.act(act)
		if CR.mode ~= "Carry" or not DevFly.active then
			return
		end
		local now = os.clock()
		if now - CR.actAt < (CRC.ActGap or 0.15) then
			return
		end
		local F = DevFly.F
		local char, _, root = getCharacter()
		if not char then
			return
		end
		if act == "Drop" then
			if not CR.throwing then
				CR.actAt = now
				CR.ramming, CR.slamming = nil, nil
				send("CarryDrop")
			end
		elseif act == "Ram" and CR.ramming then
			CR.actAt = now
			CR.ramEnd() -- (RAM again: let go of them now)
		elseif CR.slamming or CR.throwing then
			return -- (one at a time)
		elseif act == "Slam" then
			if F.state == "Fly" or F.state == "Brake" then
				CR.actAt = now
				CR.ramming = nil
				CR.slam(char, root)
			end
		elseif act == "Throw" then
			if not CR.ramming and (F.state == "Fly" or F.state == "Brake") then
				CR.actAt = now
				CR.throw(char, root)
			end
		elseif act == "Ram" then
			if F.state == "Fly" or F.state == "Brake" then
				CR.actAt = now
				CR.ram(char, root)
			end
		end
		CR.hud()
	end

	-- SLAM: the flight's dive, straight down (Ahead studs on, so he lands
	-- facing on and they're in front of him) - the street's the impact
	function CR.slam(char, root)
		local F = DevFly.F
		local cam = workspace.CurrentCamera
		local fl = flat(cam and cam.CFrame.LookVector or root.CFrame.LookVector)
		fl = fl.Magnitude > 0.05 and fl.Unit or Vector3.new(0, 0, -1)
		local below = workspace:Raycast(root.Position, Vector3.new(0, -600, 0), F.params)
		local g = below and below.Position or (root.Position - Vector3.new(0, 600, 0))
		local to = g + fl * ((CRC.Slam or {}).Ahead or 6)
		local d = to - root.Position
		F.state = "Dive"
		F.stateAt = os.clock()
		F.diveTo = to
		F.dir = d.Magnitude > 0.01 and d.Unit or -Vector3.yAxis
		F.spd = math.max(F.spd, F.vel.Magnitude, 140)
		F.hover = Vector3.zero
		F.boost = nil
		F.kick = -F.dir * 6
		CR.slamming = { t0 = os.clock(), face = fl }
		char:SetAttribute("DevFlyLocal", "Dive")
		VFX.Play("DevFly", char, { Kind = "Dive", Pos = below and to or nil }, true)
		VFX.Play("DevCarry", char, { Kind = "Slam" }, true)
		DevFly.send("DevDive", { Pos = below and to or nil })
		send("CarrySlam", { Face = fl })
	end
	-- (from the flight) down on the street: the slam's impact, or the ram's end
	function CR.landed(_kind, ground)
		local sl = CR.slamming
		if sl then
			CR.slamming = nil
			local char = player.Character
			if char and CR.holding() then
				send("CarryImpact", { Pos = ground })
				VFX.Play("DevCarry", char, { Kind = "Impact", Pos = ground, Face = sl.face, Target = CR.victim(), Radius = (CRC.Slam or {}).Crater }, true)
			end
		elseif CR.ramming then
			CR.ramEnd()
		end
	end

	-- THROW: swung back over his shoulder and hurled where he's aiming (the
	-- server lets go at the swing's Hit)
	function CR.throw(char, root)
		local dir = getAim(root)
		local token = {}
		CR.throwing = token
		VFX.Play("DevCarry", char, { Kind = "Throw", Dir = dir }, true)
		send("CarryThrow", { Dir = dir })
		task.delay(((CRC.Throw or {}).WindUp or 0.21) + 0.8, function()
			if CR.throwing == token then
				CR.throwing = nil
				CR.hud()
			end
		end)
	end

	-- RAM: flat out along his look (pitched at most Ram.Pitch), holding them
	-- out in front - the flight smashes through whatever's in the way
	function CR.flatish(look)
		local F = DevFly.F
		local fl = flat(look)
		if fl.Magnitude < 0.05 then
			fl = flat(F.dir)
		end
		fl = fl.Magnitude > 0.05 and fl.Unit or Vector3.new(0, 0, -1)
		local lim = math.rad((CRC.Ram or {}).Pitch or 20)
		local pitch = math.clamp(math.asin(math.clamp(look.Unit.Y, -1, 1)), -lim, lim)
		return (fl * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)).Unit
	end
	function CR.ram(char, root)
		local F = DevFly.F
		local cam = workspace.CurrentCamera
		local d = CR.flatish(cam and cam.CFrame.LookVector or root.CFrame.LookVector)
		CR.ramming = { t0 = os.clock(), dir = d }
		if F.spd < 40 then
			F.dir = d
		end
		F.boost = nil
		F.hover = Vector3.zero
		VFX.Play("DevCarry", char, { Kind = "Ram", Dir = d }, true)
		send("CarryRam", { Dir = d })
	end
	-- (from DevFly.fly, every frame) the ram flies him: true while it does
	function CR.ramStep(dt, now, look)
		local ram = CR.ramming
		if not ram then
			return false
		end
		local R = CRC.Ram or {}
		if not DevFly.active or CR.mode ~= "Carry" then
			CR.ramming = nil
			return false
		end
		if now - ram.t0 >= (R.Time or 1.1) then
			CR.ramEnd()
			return false
		end
		local F = DevFly.F
		local want = CR.flatish(look)
		local nd = F.dir:Lerp(want, 1 - math.exp(-(R.Turn or 1.6) * dt))
		F.dir = nd.Magnitude > 0.01 and nd.Unit or want
		F.spd += ((R.Speed or 480) - F.spd) * (1 - math.exp(-(R.Up or 7) * dt))
		F.hover = Vector3.zero
		F.boost = nil
		F.tier = "Fast"
		F.vel = F.dir * F.spd
		return true
	end
	function CR.ramEnd()
		local ram = CR.ramming
		if not ram then
			return
		end
		CR.ramming = nil
		local F = DevFly.F
		send("CarryRamEnd", { Dir = (F.vel.Magnitude > 1 and F.vel.Unit) or ram.dir })
		CR.hud()
	end
	-- (from the flight) an unbreakable wall stopped him: the ram's over
	function CR.walled()
		if CR.ramming then
			CR.ramEnd()
		end
	end

	---------------------------------------------------------------------------
	-- following the server: his body's DevCarrying (the bar), and, his body
	-- the one being carried, its CarriedBy (the HELD BY chip)
	---------------------------------------------------------------------------
	function CR.heldSync()
		local char = player.Character
		local id = char and char:GetAttribute("CarriedBy")
		local by = id and VFX.CRX and VFX.CRX.playerById(id)
		if by then
			HUD.CarryHeld({ By = by.DisplayName, Ends = char:GetAttribute("CarryEnds"), Max = CRC.MaxHold or 6 })
		else
			HUD.CarryHeld(nil)
		end
	end
	function CR.watch(char)
		for _, c in CR.conns do
			c:Disconnect()
		end
		table.clear(CR.conns)
		if not char then
			return
		end
		table.insert(CR.conns, char:GetAttributeChangedSignal("DevCarrying"):Connect(function()
			CR.sync()
		end))
		for _, a in { "CarriedBy", "CarryEnds" } do
			table.insert(CR.conns, char:GetAttributeChangedSignal(a):Connect(CR.heldSync))
		end
		CR.heldSync()
	end
	player.CharacterAdded:Connect(function(char)
		CR.watch(char)
		task.defer(CR.sync)
	end)
	CR.watch(player.Character)
	-- (his hero's HUD drawn again - an ult running out, a form, Deku's R: the
	-- carry's bar back on top of it)
	for _, a in { "UltActive", "QuirkAlt", "QuirkPick", "Blueprint", "Quirk" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			if CR.mode ~= "Off" then
				task.defer(CR.hud)
			end
		end)
	end
	player:GetAttributeChangedSignal("DevFlyer"):Connect(function()
		task.defer(CR.sync)
	end)
	-- (the device changed: the keys it shows)
	RunService.Heartbeat:Connect(function()
		if CR.mode ~= "Off" and CR.input ~= inputMode then
			CR.input = inputMode
			CR.hud()
		end
	end)
end

---------------------------------------------------------------------------
-- (round 89) FLIGHTBOOM on the flyer's own screen (Config.DevFlight.Bomb /
-- Shaft). The bomb seen at once: a crash at mach speed plays the bomb, not
-- the crater (the server decides what it does, from its own view of him);
-- the mach burst's first wall is a bomb too (and the server's told it was
-- the burst). ALL THE WAY DOWN: a crash onto a building - the burst, the
-- dive, the carry's SLAM - doesn't stop on the roof: every floor under him
-- (Config.DevFlight.Shaft.plan, this screen's map) is opened here at once
-- (he never snags, and the one he holds rides down with him), the server's
-- asked to carve the shaft (DevDrill), and on down he goes, straight to the
-- street - the crash (the bomb) is down there. (A block of its own:
-- DevFly.FB - the flight calls it as it lands, touches down and meets a wall.)
---------------------------------------------------------------------------
do
	local DEV = Config.DevFlight or {}
	local BOMB, SHAFT = DEV.Bomb or {}, DEV.Shaft or {}
	local FB = {}
	DevFly.FB = FB

	-- how big a bomb at his speed is (0..1, the blast hole's radius)
	function FB.power(speed)
		return DEV.Bomb.power(math.min(tonumber(speed) or 0, (DEV.Boost or {}).Cap or 980))
	end
	-- (round 89, in Studio) as the server has it (Kit.FB.need): Speed, or
	-- BurstSpeed for a moment after a burst - then at least BurstFloor big
	function FB.bursting()
		local F = DevFly.F
		return F ~= nil and os.clock() - (F.burstAt or -1e9) < (BOMB.BurstWindow or 1.6)
	end
	function FB.need()
		return FB.bursting() and (BOMB.BurstSpeed or 150) or (BOMB.Speed or 420)
	end
	-- (from DevFly.land, the crash) at mach speed, his own screen plays the bomb
	function FB.predict(data, speed)
		if BOMB.Enabled == false or not ((tonumber(speed) or 0) >= FB.need()) then
			return false
		end
		-- ((round 92) a dev's, or a grant's with FULL POWER: anyone else's is the crater)
		if DevFly.fullPower and not DevFly.fullPower() then
			return false
		end
		if FB.bursting() then
			speed = math.max(tonumber(speed) or 0, BOMB.BurstFloor or 860)
		end
		local k, R = FB.power(speed)
		data.Kind, data.Radius, data.K = "Bomb", R, k
		return true
	end
	-- (from DevFly.smash / DevFly.wall) a wall at the mach burst: the first
	-- one each burst is a bomb (true: the server's to be told it was). (Seen
	-- a moment ahead, as the burst's still coming up to speed: it's met at
	-- the burst's peak)
	function FB.wallBlast(char, at, normal, speed)
		local F = DevFly.F
		local bo = F and F.boost
		speed = math.max(tonumber(speed) or 0, bo and tonumber(bo.peak) or 0)
		if BOMB.Enabled == false or not bo or bo.blasted or not (speed >= FB.need()) then
			return false
		end
		if DevFly.fullPower and not DevFly.fullPower() then
			return false -- ((round 92) FULL POWER: the wall's just smashed through)
		end
		speed = math.max(speed, BOMB.BurstFloor or 860)
		bo.blasted = true
		local k, R = FB.power(speed)
		VFX.Play("DevFly", char, { Kind = "Bomb", Pos = at, Normal = normal, Radius = R * (BOMB.Wall or 0.7), K = k, Speed = speed, Wall = true }, true)
		return true
	end

	-- (from DevFly.touchdown, a crash) come down on a building: on down
	-- through every floor to the street (true: he's on his way down - no
	-- landing here)
	function FB.drill(at, part, speed)
		local F = DevFly.F
		if SHAFT.Enabled == false or not F or not DevFly.active or typeof(part) ~= "Instance" or not part:IsA("BasePart") or not DevFly.breakable(part) then
			return false
		end
		if DevFly.fullPower and not DevFly.fullPower() then
			return false -- ((round 92) all the way down: a dev's, or FULL POWER - else he lands on the roof)
		end
		local plan = DEV.Shaft.plan(at, function(origin, vec)
			return workspace:Raycast(origin, vec, F.params)
		end, DevFly.breakable)
		if not plan then
			return false -- (that's the street he's on)
		end
		local now = os.clock()
		local char = F.char
		local bottom = plan.Bottom
		local r = SHAFT.Radius or 7
		-- the floors opened on his screen at once - and anything breakable in
		-- the shaft's way (a stair, a beam), never the street at the bottom
		local function open(p)
			if p:IsA("BasePart") and p ~= plan.Street and DevFly.breakable(p) and (p.CanCollide or F.walls[p]) then
				p.CanCollide = false
				F.walls[p] = now
			end
		end
		for _, f in plan.Floors do
			open(f.Part)
		end
		local params = OverlapParams.new()
		local map = workspace:FindFirstChild("Map")
		if map then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { map }
		end
		local lo, hi = bottom.Y + 0.6, at.Y + 2
		for _, p in workspace:GetPartBoundsInBox(CFrame.new(at.X, (lo + hi) / 2, at.Z), Vector3.new(r * 2, math.max(hi - lo, 1), r * 2), params) do
			if p:IsA("BasePart") and DEV.Shaft.span(p) > lo then
				open(p)
			end
		end
		-- the server told (it carves the shaft for everyone), the beat here now
		local ys = {}
		for i, f in plan.Floors do
			ys[i] = f.Y
		end
		local spd = math.max(tonumber(speed) or 0, SHAFT.Speed or 520)
		DevFly.send("DevDrill", { Top = at, Bottom = bottom })
		VFX.Play("DevFly", char, { Kind = "Shaft", Top = at, Bottom = bottom, Floors = ys, R = r, Speed = spd }, true)
		-- and on down: straight down the shaft (the flight's dive, at the
		-- street under where he hit the roof), the crash at the bottom
		local root = F.root
		local way = root and (bottom - root.Position) or Vector3.zero
		F.state = "Dive"
		F.stateAt = now
		F.diveTo = bottom
		F.dir = (way.Magnitude > 1 and way.Unit.Y < -0.7) and way.Unit or -Vector3.yAxis
		F.spd = spd
		F.vel = F.dir * spd
		F.hover = Vector3.zero
		F.boost = nil
		F.kick = Vector3.new(0, 4, 0)
		F.fovKick = math.max(F.fovKick or 0, 6)
		if F.lv then
			F.lv.VectorVelocity = F.vel
		end
		if char then
			char:SetAttribute("DevFlyLocal", "Dive")
		end
		return true
	end
end

---------------------------------------------------------------------------
-- (round 90) polish: THE SHIELD GOES DOWN, on the flyer's own screen
-- (Config.SkyCoffin.Break; the owner: "turn off animation for the
-- shield"). Flying into the Sky Coffin's electromagnetic field at MinSpeed
-- or more he goes straight through it: the face ahead (Config's
-- Break.cross: its walls clear of the pillars, the lid under the roof, the
-- tent of the roof over it) is seen coming far enough ahead that its
-- invisible wall is let go on this screen before the flight's own rays
-- reach it (they respect CanCollide, so they never stop him on it), and
-- as he reaches the drawn face it breaks: the crack, the shards, the boom
-- and the whole shield powering down (VFX.SB, played here at once), a
-- flash and a shake on his camera (no flip, no roll), every one of its
-- colliders let go here (the server's about to), and the server's told
-- (DevBarrier: it checks it and takes the shield down for everyone). What
-- he let go of is put back once he's clear of it (or the flight's over) -
-- unless the server has the shield down: then they're the server's to put
-- back. While it's down, or booting back up, there's nothing to break.
-- Slower than MinSpeed the field stops him, as ever. (A block of its own:
-- DevFly.SB - the flight calls it as it looks ahead for walls,
-- DevFly.collide.)
---------------------------------------------------------------------------
do
	local SBC = { opened = {}, cache = nil, passFam = nil, passUntil = 0 }
	DevFly.SB = SBC

	function SBC.cfg()
		return (Config.SkyCoffin or {}).Break or {}
	end
	function SBC.model()
		local map = workspace:FindFirstChild("Map")
		return (map and map:FindFirstChild("SkyCoffin")) or workspace:FindFirstChild("SkyCoffin")
	end
	-- what stops him: the field's colliders - a face's (a wall's, or the
	-- lid), or all of them (nil). Found once (not the island's every part a frame)
	function SBC.solids(key)
		local m = SBC.model()
		if not m then
			return {}
		end
		local c = SBC.cache
		if not c or c.model ~= m or (c.all[1] and not c.all[1].Parent) or (#c.all == 0 and os.clock() - c.at > 2) then
			c = { model = m, all = {}, byKey = {}, at = os.clock() }
			for _, d in m:GetChildren() do
				local f = d:IsA("BasePart") and d.Name == "Barrier" and d:GetAttribute("BarrierFace") or nil
				if f ~= nil then
					table.insert(c.all, d)
					c.byKey[f] = c.byKey[f] or {}
					table.insert(c.byKey[f], d)
				end
			end
			SBC.cache = c
		end
		if key == nil then
			return c.all
		end
		return c.byKey[key] or {}
	end
	-- let him through on this screen (a face, or the lot)
	function SBC.open(key, now)
		for _, p in SBC.solids(key) do
			if p.CanCollide then
				p.CanCollide = false
				SBC.opened[p] = now
			elseif SBC.opened[p] then
				SBC.opened[p] = now
			end
		end
	end
	-- ...and put it back once he's clear of it (its box and 6 studs round)
	-- and a moment's gone, or the flight's over; not while the server has
	-- the shield down (it's let them go too: it puts them back)
	function SBC.restore(all)
		local now = os.clock()
		local F = DevFly.F
		local root = F and F.root
		local down = VFX.SB ~= nil and VFX.SB.serverDown()
		for p, at in SBC.opened do
			local clear = down or all or not DevFly.active or not (root and root.Parent)
			if not clear and now - at >= 0.6 then
				local rel = p.CFrame:PointToObjectSpace(root.Position)
				local h = p.Size / 2 + Vector3.one * 6
				clear = math.abs(rel.X) > h.X or math.abs(rel.Y) > h.Y or math.abs(rel.Z) > h.Z
			end
			if clear then
				SBC.opened[p] = nil
				if p.Parent and not down then
					p.CanCollide = true
				end
			end
		end
	end
	RunService.Heartbeat:Connect(function()
		if next(SBC.opened) ~= nil then
			SBC.restore(false)
		end
	end)

	-- (from DevFly.collide, every frame he's flying) the field ahead?
	function SBC.ahead(dt, now, char, root)
		local B = SBC.cfg()
		local F = DevFly.F
		if not (B.cross and F and SBC.model()) then
			return
		end
		local speed = F.vel.Magnitude
		if speed < (B.MinSpeed or 60) then
			return -- (slow: the field stops him, as ever)
		end
		if DevFly.fullPower and not DevFly.fullPower() then
			return -- ((round 92) breaking it: a dev's, or FULL POWER - the field stops anyone else, as ever)
		end
		-- (down, or booting back up: nothing there to break - it lets anyone through)
		if VFX.SB and VFX.SB.isOpen() then
			return
		end
		local d = F.vel / speed
		-- (as far ahead as the flight looks for walls, and past the wall's thickness)
		local look = speed * math.max(0.15, math.max(dt, 1 / 30) * 1.5) + 16
		local hit = B.cross(root.Position, d, look)
		if not hit then
			return
		end
		local roof = hit.Face == "Lid" or hit.Face:sub(1, 1) == "R"
		local fam = roof and "roof" or hit.Face
		SBC.open(roof and "Lid" or hit.Face, now)
		if SBC.passFam == fam and now < SBC.passUntil then
			return -- (the break's made: on through)
		end
		-- the face he'll burst out of (going up through the lid: the roof's
		-- tent over it; coming down through the tent: the lid under it)
		local data = { Face = hit.Face, Pos = hit.Pos, Dir = d, Speed = speed, R = B.radius(speed) }
		if roof then
			local beyond = B.cross(hit.Pos + d * 0.5, d, 160)
			if hit.Face == "Lid" then
				data.Lid = hit.Pos
				if beyond and beyond.Face ~= "Lid" then
					data.Face, data.Pos = beyond.Face, beyond.Pos
				end
			elseif beyond and beyond.Face == "Lid" then
				data.Lid = beyond.Pos
			end
		end
		-- it breaks as he reaches the drawn face
		local wait = math.clamp(((data.Pos - root.Position).Magnitude - 3) / speed, 0, 0.6)
		SBC.passFam, SBC.passUntil = fam, now + wait + 0.6
		local function burst()
			if not DevFly.active or char.Parent == nil then
				return
			end
			-- (the whole shield's going: every collider let go here, as the
			-- server's about to)
			SBC.open(nil, os.clock())
			local fx = table.clone(data)
			fx.Predicted = true
			fx.T = VFX.SB and VFX.SB.now() or nil
			VFX.Play("SkyBreak", char, fx, true)
			if VFX.SB then
				VFX.SB.jolt()
			end
			DevFly.send("DevBarrier", data)
		end
		if wait < 0.02 then
			burst()
		else
			task.delay(wait, burst)
		end
	end
	player.CharacterAdded:Connect(function()
		SBC.restore(true)
	end)
end

---------------------------------------------------------------------------
-- (round 90) DEVFLY2 - DEV FLIGHT 2.0 (Config.DevFlight.Control / Light /
-- Bounds; the owner: "make the dev fly a little more controllable, as well
-- as adding another level of speed to it. you can really show off here").
-- DevFly.Ctl - THE CONTROL, called from the flight's own step: the heading
-- swung round to where he aims (a big turn at once, a hard one a CARVE
-- that costs speed), A / D a strafe across his line at speed, A or D twice
-- the BARREL ROLL (the SIDESTEP in the hover), the hover stopping crisp and
-- holding its spot, the HOVER-LOCK on its own keys (dead still, turned
-- to his aim, nudged; at speed the braking flip into it), and the bounds
-- he can't fly out of (the void under -500 deletes a body).
-- DevFly.Light - LIGHTSPEED: the burst held at HYPERSONIC charges the light
-- barrier; full, it breaks (the beat on every screen: VFX.LSX); held there
-- while he keeps W and sprint; under Rearm he drops back out of it.
-- (A block of its own before the flight's; F is DevFly.F, filled in there.)
---------------------------------------------------------------------------
do
	local DEV = Config.DevFlight or {}
	local CT = DEV.Control or {}
	local LT = DEV.Light or {}
	local Ctl = { tap = { sign = 0, at = -1e9, rest = true }, rollCd = 0 }
	local Light = {}
	DevFly.Ctl = Ctl
	DevFly.Light = Light
	VFX.Hooks.LightBreak = HUD.LightBreak -- (his screen at the break: the flash, the split rings)
	VFX.Hooks.LightOut = HUD.LightOut
	local function send(kind, data)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, data)
	end
	local function ease(a)
		a = math.clamp(a, 0, 1)
		return a * a * (3 - 2 * a)
	end

	-- THE TURN: his heading swung toward `wish` (a unit vector) about the
	-- axis between them at `turn` x how far off it is - at most Knee
	-- radians' worth (a big turn swings round at once instead of creeping:
	-- the old blend all but stalled with the camera thrown round behind him),
	-- a CARVE past From degrees at speed (up to Mult x, costing Bleed of his
	-- speed a second). Straight behind him: round through his side, level.
	-- F.turnWant: the turn he's asking for (radians, + to his left - the
	-- bank's sign). Returns the carve (0..1)
	function Ctl.steer(wish, turn, dt, fr)
		local F = DevFly.F
		local TN = CT.Turn or {}
		local d = F.dir
		local ang = math.acos(math.clamp(d:Dot(wish), -1, 1))
		local fd, fw = flat(d), flat(wish)
		local want = 0
		if fd.Magnitude > 0.05 and fw.Magnitude > 0.05 then
			local a, b = fd.Unit, fw.Unit
			want = math.asin(math.clamp(a:Cross(b).Y, -1, 1))
			if a:Dot(b) < 0 then
				want = (want >= 0 and 1 or -1) * (math.pi - math.abs(want))
			end
		end
		F.turnWant = want
		if ang < 1e-4 or ang ~= ang then
			return 0
		end
		local axis = d:Cross(wish)
		if axis.Magnitude < 1e-3 then
			axis = math.abs(d.Y) < 0.9 and Vector3.yAxis or ((fr and fr.Magnitude > 0.05) and fr or Vector3.xAxis)
		end
		local carve = 0
		if F.spd > (TN.BleedFrom or 150) then
			carve = ease((math.deg(ang) - (TN.From or 30)) / math.max((TN.Full or 90) - (TN.From or 30), 1))
		end
		local rate = turn * math.min(ang, TN.Knee or 1) * (1 + ((TN.Mult or 1.8) - 1) * carve)
		local nd = CFrame.fromAxisAngle(axis.Unit, math.min(ang, rate * dt)) * d
		F.dir = (nd == nd and nd.Magnitude > 0.01) and nd.Unit or wish
		if carve > 0 then
			F.spd *= 1 - math.min((TN.Bleed or 0.9) * carve * dt, 0.5)
		end
		F.carve = carve
		return carve
	end

	-- A / D at speed: THE STRAFE across his line (level), the tier's Strafe
	-- studs/s reached at StrafeK; F.strafeK: how hard (-1..1, + to his right)
	function Ctl.strafe(side, T, dt, moving, fr)
		local F = DevFly.F
		local fd = flat(F.dir)
		local right = fd.Magnitude > 0.05 and fd.Unit:Cross(Vector3.yAxis) or (fr or Vector3.zero)
		local most = (T and T.Strafe) or 0
		local want = (moving and math.abs(side) > 0.05 and most > 0) and right * side * most or Vector3.zero
		F.strafe = (F.strafe or Vector3.zero) + (want - (F.strafe or Vector3.zero)) * (1 - math.exp(-(CT.StrafeK or 8) * dt))
		F.strafeK = most > 0 and math.clamp(F.strafe:Dot(right) / most, -1, 1) or 0
	end

	-- A or D twice quickly (the stick flicked twice): -1 / +1 (else nil)
	function Ctl.taps(side, now)
		local R = CT.Roll or {}
		local st = Ctl.tap
		local mag = math.abs(side)
		if mag >= (R.Flick or 0.7) then
			if st.rest then
				st.rest = false
				local sign = side > 0 and 1 or -1
				if st.sign == sign and now - st.at <= (R.DoubleTap or 0.3) then
					st.sign, st.at = 0, -1e9
					return sign
				end
				st.sign, st.at = sign, now
			end
		elseif mag <= (R.Rest or 0.3) then
			st.rest = true
		end
		return nil
	end

	-- THE BARREL ROLL (at speed: one full turn round his line, Dist studs
	-- across in Time s) / THE SIDESTEP (in the hover, or locked: a lean,
	-- HoverDist across). sign: +1 right, -1 left
	function Ctl.roll(sign, fr)
		local F = DevFly.F
		local R = CT.Roll or {}
		local now = os.clock()
		if not DevFly.active or now < Ctl.rollCd or F.state ~= "Fly" or now < F.pauseUntil then
			return false
		end
		Ctl.rollCd = now + (R.Cooldown or 0.55)
		local hover = F.spd < 40 or F.lock ~= nil
		local T = hover and (R.HoverTime or 0.28) or (R.Time or 0.36)
		local dist = hover and (R.HoverDist or 18) or (R.Dist or 30)
		local fd = flat(F.dir)
		local right = (not hover and fd.Magnitude > 0.05) and fd.Unit:Cross(Vector3.yAxis) or (fr or Vector3.xAxis)
		local dir = right * sign
		F.spin = { t0 = now, T = T, peak = dist * math.pi / (2 * T), dir = dir, sign = sign, hover = hover }
		F.anchor, F.stillAt = nil, nil
		VFX.Play("DevFly", F.char, { Kind = "Roll", Dir = dir, Hover = hover }, true)
		send("DevRoll", { Dir = dir, Hover = hover })
		return true
	end
	-- the roll this frame: its push across (studs/s) and how far round he is
	-- (radians about his line; + rolls him right, the right side dipping)
	function Ctl.rolling(now)
		local F = DevFly.F
		local sp = F and F.spin
		if not sp then
			return Vector3.zero, 0
		end
		local t = now - sp.t0
		if t >= sp.T then
			F.spin = nil
			return Vector3.zero, 0
		end
		local a = t / sp.T
		local angle = sp.hover and sp.sign * math.rad(24) * math.sin(math.pi * a) or sp.sign * 2 * math.pi * ease(a)
		return sp.dir * sp.peak * math.sin(math.pi * a), angle
	end

	-- THE HOVER'S HOLD: let go and still (under Settle studs/s for Still s)
	-- he keeps his spot - pulled back to it (K, at most Max) with the breath
	-- (bobY: its height off the spot, bobV: its speed) on top. The push, or
	-- nil (not held yet)
	function Ctl.hold(root, idle, bobY, bobV, now)
		local F = DevFly.F
		local HD = CT.Hold or {}
		if not idle then
			F.anchor, F.stillAt = nil, nil
			return nil
		end
		local up = Vector3.new(0, bobY, 0)
		if not F.anchor then
			local settle = HD.Settle or 2
			if (F.hover - Vector3.new(0, bobV, 0)).Magnitude < settle and F.spd < settle then
				F.stillAt = F.stillAt or now
				if now - F.stillAt >= (HD.Still or 0.2) then
					F.anchor = root.Position - up
				end
			else
				F.stillAt = nil
			end
			return nil
		end
		if (F.anchor + up - root.Position).Magnitude > (HD.Lost or 25) then
			F.anchor, F.stillAt = nil, nil -- (moved far off it by something else: not pulled back)
			return nil
		end
		local pull = (F.anchor + up - root.Position) * (HD.K or 6)
		if pull.Magnitude > (HD.Max or 12) then
			pull = pull.Unit * (HD.Max or 12)
		end
		return pull + Vector3.new(0, bobV, 0)
	end

	-- THE HOVER-LOCK key (Config.DevFlight.LockKeys: T / L3; the phone's
	-- LOCK) while he flies: on (a hover: at once; at speed: the braking flip,
	-- locked at its end), or off again
	function Ctl.lockKey()
		local F = DevFly.F
		if not DevFly.active or not F then
			return
		end
		if F.lock or F.lockAfter then
			Ctl.lock(false)
		elseif F.state == "Brake" then
			F.lockAfter = true
		elseif F.state == "Fly" then
			-- ((round 90 review) at speed it's always the flip first: with the flip
			-- still cooling down (Brake.Cooldown) the lock used to clamp on at
			-- once - a dead stop from up to 1400 studs/s in a frame. Now it waits
			-- for the flip: Ctl.pending)
			if F.vel.Magnitude >= ((DEV.Brake or {}).MinSpeed or 80) then
				F.lockAfter = true
				DevFly.brake()
			else
				Ctl.lock(true)
			end
		end
	end
	-- the key pressed at speed while the flip was cooling down: the flip as
	-- soon as it can be (or the lock at once, if he's slowed under it by
	-- then). True: he's flipping (the flight's step stops there this frame)
	function Ctl.pending()
		local F = DevFly.F
		if not (F.lockAfter and not F.lock and F.state == "Fly") then
			return false
		end
		if F.vel.Magnitude < ((DEV.Brake or {}).MinSpeed or 80) then
			Ctl.lock(true)
			return false
		end
		return DevFly.brake()
	end
	function Ctl.lock(on, quiet)
		local F = DevFly.F
		F.lockAfter = nil
		if on then
			if F.light then
				Light.drop("Out")
			end
			F.lock = { at = os.clock(), nudge = Vector3.zero }
			F.boost, F.spd, F.tier = nil, 0, "Hover"
			F.strafe, F.anchor, F.stillAt = Vector3.zero, nil, nil
			F.fovKick = math.min(F.fovKick or 0, -3)
			if not quiet then
				VFX.PlaySound("DevFlyLockOn", nil, 1)
			end
		else
			if F.lock and not quiet then
				VFX.PlaySound("DevFlyLockOff", nil, 1)
			end
			F.lock = nil
			F.anchor, F.stillAt = nil, nil
		end
		if HUD.FlightReticle then
			HUD.FlightReticle(F.lock ~= nil)
		end
	end
	-- one frame of the hover-lock: dead still at its spot, WASD / up / down
	-- nudging the spot (Nudge studs/s, eased NudgeK). Sprint and W: off it,
	-- straight on (false: the flight carries on this frame)
	function Ctl.lockStep(dt, now, root, fl, fr, fwd, side, up, down, sprint)
		local F = DevFly.F
		local L = CT.Lock or {}
		local lk = F.lock
		if sprint and fwd > 0.25 then
			Ctl.lock(false)
			return false
		end
		-- (something else moved him far off it - a carry's move, a slam that
		-- never came down: the spot is where he is now, never a yank back)
		if not lk.anchor or (lk.anchor - root.Position).Magnitude > (L.Lost or 25) then
			lk.anchor = root.Position
		end
		local want = fl * fwd + fr * side + Vector3.yAxis * ((up and 1 or 0) - (down and 1 or 0))
		want = (want.Magnitude > 1 and want.Unit or want) * (L.Nudge or 12)
		lk.nudge += (want - lk.nudge) * (1 - math.exp(-(L.NudgeK or 10) * dt))
		local push = Ctl.rolling(now)
		lk.anchor += (lk.nudge + push) * dt
		local pull = (lk.anchor - root.Position) * (L.K or 9)
		if pull.Magnitude > (L.Max or 30) then
			pull = pull.Unit * (L.Max or 30)
		end
		F.spd, F.boost, F.tier, F.turnWant, F.strafeK = 0, nil, "Hover", 0, 0
		F.strafe = Vector3.zero
		F.hover = lk.nudge + push + pull
		F.vel = F.hover
		return true
	end

	-- THE BOUNDS: never under Floor (eased level over Cushion first), over
	-- Ceiling, or out past Radius from Center (his heading turned back in).
	-- Returns the velocity he may have
	function Ctl.bounds(v, root, dt)
		local B = DEV.Bounds
		local F = DevFly.F
		if not B or not root then
			return v
		end
		local p = root.Position
		local floor, cush = B.Floor or -340, math.max(B.Cushion or 60, 1)
		if p.Y < floor + cush and v.Y < 0 then
			v = Vector3.new(v.X, v.Y * math.clamp((p.Y - floor) / cush, 0, 1), v.Z)
		end
		if p.Y < floor then
			v = Vector3.new(v.X, math.max(v.Y, (floor - p.Y) * 4), v.Z)
		end
		local ceil = B.Ceiling or 9000
		if p.Y > ceil - cush and v.Y > 0 then
			v = Vector3.new(v.X, v.Y * math.clamp((ceil - p.Y) / cush, 0, 1), v.Z)
		end
		local c = B.Center or Vector3.zero
		local off = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
		if off.Magnitude > (B.Radius or 18000) and Vector3.new(v.X, 0, v.Z):Dot(off) > 0 then
			local back = -off.Unit
			local nd = F.dir:Lerp(Vector3.new(back.X, F.dir.Y, back.Z), math.min(1, (B.Turn or 1.2) * dt))
			F.dir = nd.Magnitude > 0.01 and nd.Unit or F.dir
		end
		return v
	end

	---------------------------------------------------------------------------
	-- LIGHTSPEED
	---------------------------------------------------------------------------
	-- the burst key (Q / Y / DASH) held: its press (DevFly.boost) and its let
	-- go (the dash key's release); a keyboard's or a controller's is asked
	-- every frame as well, so a release that never came can't leave it held
	function Light.dashDown()
		local F = DevFly.F
		if F then
			F.dashHeld = true
		end
	end
	function Light.dashUp()
		local F = DevFly.F
		if F then
			F.dashHeld = false
		end
	end
	function Light.held()
		local F = DevFly.F
		if not F.dashHeld then
			return false
		end
		if inputMode == "Touch" then
			return true -- (a phone's button tells its own let go)
		end
		for _, k in Config.DashKeys or {} do
			local ok, down = pcall(function()
				if string.sub(k.Name, 1, 6) == "Button" then
					return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, k)
				end
				return UserInputService:IsKeyDown(k)
			end)
			if ok and down then
				return true
			end
		end
		F.dashHeld = false
		return false
	end

	-- one frame of it (from the flight's): the charge while the burst's held
	-- at HYPERSONIC (sprint and W held, never carrying someone, Cooldown
	-- since the last), the break when it's full; at LIGHTSPEED, dropping back
	-- out under Rearm (or the moment he's holding someone)
	function Light.step(dt, now, char, sprint, fwd)
		local F = DevFly.F
		if LT.Enabled == false then
			return
		end
		if F.light then
			local jumping = now - F.light.t0 < (LT.Jump or 0.25) + 0.15
			if char:GetAttribute("DevCarrying") or (not jumping and F.spd < (LT.Rearm or 900)) then
				Light.drop("Out")
			end
			return
		end
		local can = F.tier == "Hyper" and sprint and fwd > 0.6 and F.state == "Fly" and now >= (F.lightCd or 0)
			and now >= F.pauseUntil and not F.lock and not char:GetAttribute("DevCarrying") and Light.held()
		-- ((round 90 review) its own fields - F.barrier (0..1) and F.barrierOn:
		-- F.charge / F.charging are the take-off's crouch, and sharing them put
		-- "LIGHT BARRIER 100%", the ring and the tunnel on his screen through
		-- every held-V launch, and a stray charge-off to everyone after it)
		local charge = math.max(LT.Charge or 1.4, 0.05)
		if can then
			if not F.barrierOn then
				Light.charging(true)
			end
			F.barrier = math.min(1, (F.barrier or 0) + dt / charge)
			if F.barrier >= 1 then
				Light.go(char)
			end
		else
			if F.barrierOn then
				Light.charging(false)
			end
			F.barrier = math.max(0, (F.barrier or 0) - dt * 3 / charge)
		end
	end
	function Light.charging(on)
		local F = DevFly.F
		F.barrierOn = on
		if F.char then
			VFX.Play("DevFly", F.char, { Kind = "Charge", On = on, Time = LT.Charge }, true)
		end
		send("DevCharge", { On = on })
	end
	-- THE LIGHT BARRIER BREAKS: from where he is up to Speed in Jump s, the
	-- camera left behind, the view punched wide; everyone told
	function Light.go(char)
		local F = DevFly.F
		local now = os.clock()
		F.barrierOn = false
		F.barrier = 0
		-- ((round 90 review) the hold is spent on the break: a phone's DASH
		-- whose let go never came (a finger slid off it) charged it again by
		-- itself the next time he was HYPERSONIC - another break wants a press)
		F.dashHeld = false
		F.lightCd = now + (LT.Cooldown or 3)
		F.light = { t0 = now, from = math.max(F.spd, ((DEV.Tiers or {}).Hyper or {}).Speed or 520) }
		F.tier = "Light"
		F.boost = nil
		F.hover, F.strafe = Vector3.zero, Vector3.zero
		F.kick = -F.dir * (LT.Kick or 12)
		F.fovKick = math.max(F.fovKick or 0, (LT.BreakFov or 120) - (LT.Fov or 116) + 8)
		F.fovHold = now + 0.15
		local root = F.root
		VFX.Play("DevFly", char, { Kind = "Light", Pos = root.Position, Dir = F.dir }, true)
		send("DevLight", { Dir = F.dir })
		char:SetAttribute("DevFlyLocal", "Light")
		DevFly.relay(true)
	end
	-- out of LIGHTSPEED (under Rearm, the brake, the dive, carrying someone,
	-- a hit, the flight's end): the light snapping off him ("Quiet": nothing shown)
	function Light.drop(reason)
		local F = DevFly.F
		if not (F and F.light) then
			return
		end
		F.light = nil
		if F.tier == "Light" then
			F.tier = "Hyper"
		end
		if reason ~= "Quiet" and F.char and F.root and F.root.Parent then
			local d = F.vel.Magnitude > 1 and F.vel.Unit or F.dir
			VFX.Play("DevFly", F.char, { Kind = "LightOut", Pos = F.root.Position, Dir = d }, true)
			send("DevLightOut", { Dir = d })
		end
	end
	-- his speed through the break (from where he was, easing out to Speed
	-- over Jump s), or nil once it's done
	function Light.jump(now)
		local F = DevFly.F
		local L = F and F.light
		if not L then
			return nil
		end
		local a = (now - L.t0) / math.max(LT.Jump or 0.25, 0.01)
		if a >= 1 then
			return nil
		end
		return L.from + ((LT.Speed or 1400) - L.from) * (1 - (1 - a) ^ 3)
	end
	-- the flight's over (or he's hit): no light, no charge, its sound let go
	-- ((round 90 review) and everyone else told the charge is off: a hit,
	-- a move, a landing in the middle of it left the sheath forming on him
	-- on their screens for its whole timeout)
	function Light.reset()
		local F = DevFly.F
		if not F then
			return
		end
		if F.barrierOn then
			F.barrierOn = false
			if F.char then
				VFX.Play("DevFly", F.char, { Kind = "Charge", On = false }, true)
			end
			send("DevCharge", { On = false })
		end
		F.light, F.barrier, F.dashHeld = nil, 0, false
	end

	-- the phone's LOCK: the hover-lock, and nothing else ((round 92) the
	-- lock-on it also was is gone; the HUD shows the button only while the
	-- flight's meter is up - HUD.SetTouchHoverLock)
	Touch.handlers.QuirkHoverLock = {
		down = function()
			if DevFly.active then
				Ctl.lockKey()
			end
		end,
	}
end

---------------------------------------------------------------------------
-- (round 92) LIGHTWIPE on the flyer's own screen (Config.DevFlight.
-- LightWipe): a crash at LIGHTSPEED - into the street, or down onto a
-- building - is THE END OF THE MAP, not the bomb. Seen here at once: he's
-- put down on the street under where he hit (the building's going anyway:
-- no way down through it), held down in the crater (Hold), his screen plays
-- the impact (VFX.LWX: the white-out, the pillar of light, the deepest
-- boom), and the server's told it was the light (DevLand's Light). The
-- server decides, by its own view of him (Kit.LW), and sets it off for
-- everyone (LightWipeGo: the city, and his camera pulled up over it). Not
-- inside the cooldown (the last one's on workspace: LightWipe), not over
-- anything that isn't the city (the Sky Coffin's floor): then it's the
-- crash it always was - the bomb. (A block of its own: DevFly.LW - the
-- flight asks it as it touches down, DevFly.touchdown, and lands, DevFly.land.)
---------------------------------------------------------------------------
do
	local DEV = Config.DevFlight or {}
	local LWC = DEV.LightWipe or {}
	local LW = {}
	DevFly.LW = LW

	-- the city's street under p (the map's roads and ground - never a roof),
	-- or nil: none of the city under it within Drop studs
	function LW.street(p)
		local map = workspace:FindFirstChild("Map")
		local list = {}
		for _, name in { "Roads", "Ground" } do
			local f = map and map:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
		if #list == 0 or typeof(p) ~= "Vector3" or p ~= p then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -((LWC.Drop or 220) + 2), 0), params)
		return hit and hit.Position or nil
	end
	-- (from DevFly.touchdown, a crash) at LIGHTSPEED onto the city, the map
	-- free to go: down on the street under it, the crash there (true: that's
	-- it - no way down through the building, no landing where he hit)
	function LW.impact(at, speed)
		local F = DevFly.F
		if LWC.Enabled == false or not F or not DevFly.active or not ((tonumber(speed) or 0) >= (LWC.Speed or 1100)) then
			return false
		end
		if not (VFX.LWX and VFX.LWX.ready()) then
			return false -- (the last one's too recent: the bomb)
		end
		-- (round 92, with flightgrant's grants: a granted flyer without FULL POWER - DevFly.fullPower, once it's there)
		if DevFly.fullPower and not DevFly.fullPower() then
			return false
		end
		local ground = LW.street(at)
		if not ground then
			return false
		end
		F.lightWipe = { At = at, T = os.clock() }
		DevFly.land("Crash", ground, speed)
		return true
	end
	-- (from DevFly.land, the crash) his screen's beat is the impact, the
	-- server's told it was the light, he's held down in the crater longer
	function LW.predict(data)
		local F = DevFly.F
		local w = F and F.lightWipe
		if not w then
			return false
		end
		F.lightWipe = nil
		if os.clock() - w.T > 0.5 then
			return false
		end
		data.Kind = "LightWipe"
		data.Light = true
		data.Hit = w.At
		data.Origin = data.Pos
		F.landFor = math.max(F.landFor or 0, LWC.Hold or 2.2)
		return true
	end
	-- ((round 92 review) the server's go, and his camera pulled up over the
	-- city (VFX.LWX's cinematic): his own cutscene takes his body out of the
	-- flight's hands (DevFly.taken) - still in the crater's hold, the flight
	-- went to "Held": its movers off, PlatformStand on, nothing standing him
	-- up, and he toppled in the street for the cutscene's 5 s, drawn "hit"
	-- on every screen. The crash is over: he's on his feet now, the way its
	-- hold ends (DevFly.stop "Landed"; the view's eased home after the cutscene)
	function LW.cinematic()
		local F = DevFly.F
		if DevFly.active and F and (F.state == "Crash" or F.state == "Land") then
			DevFly.stop("Landed")
		end
	end
	VFX.Hooks.LightWipeMine = LW.cinematic
end

---------------------------------------------------------------------------
-- (round 92) FLIGHTGRANT on this screen (Config.FlightGrant; the server's
-- Kit.FG gives and takes it and says so on the player: FlightGrant
-- ("Server" / "Perm"), FlightFull, FlightGrantBy, FlightGrantAt).
--   WHO FLIES here: DevFly.canFly - a dev (DevFlyer) or a grant. The
--     flight's own gates ask it (V, the D-pad, the DEV FLIGHT row, the
--     carry). DevFly.fullPower - the destructive extras (the bomb, all the
--     way down, the shield breaking): a dev's, or a FULL POWER grant's.
--     DevFly.allowed stays the dev check (the ADMIN EVENTS row goes by it),
--     and DevFlyer - what the director camera and possess read - is never
--     a grant's.
--   GIVEN / TAKEN BACK: the toast (UI_EVENTS.FlightGrant -> HUD.
--     FlightGrantToast: who, which kind, full power, how to take off on
--     this device), the keys bound or let go - taken back mid-flight, his
--     flight stops (a fall to the street; the server's switched it off too).
--   THE PHONE: a FLY button on the pad for whoever flies (Touch.handlers.
--     QuirkDevFly: a tap takes off or lets go, held on the street it charges
--     the take-off as V does), lit while he flies (HUD.SetTouchFly).
--   GIVE FLIGHT: the devs' test menu panel (Dev only; HUD.BuildFlightGrant
--     Panel) - everyone here and the saved grants, a switch each, sent as
--     TestCommand FlightGrant / FlightGrantAll; the server decides.
---------------------------------------------------------------------------
do
	local FGC = Config.FlightGrant or {}
	local DEV = Config.DevFlight or {}
	local FGc = { built = false, lit = false }
	DevFly.FG = FGc

	-- ((round 92 review) a dev: DEV FLIGHT's own rule - and before that block
	-- has run (this one runs first, and its setup() and FLY's first sync
	-- asked DevFly.allowed while it was still nil: on a live server DevFlyer
	-- and Tester are already on him when this script starts, so neither
	-- changes again - the owner's GIVE FLIGHT panel was never built and a
	-- dev's phone had no FLY), the same rule straight off the attribute)
	function FGc.dev()
		if DevFly.allowed then
			return DevFly.allowed() == true
		end
		return DEV.Enabled ~= false and player:GetAttribute("DevFlyer") == true
	end
	-- a dev, or someone a dev gave it to
	function DevFly.canFly()
		if DEV.Enabled == false then
			return false
		end
		if FGc.dev() then
			return true
		end
		return FGC.Enabled ~= false and player:GetAttribute("FlightGrant") ~= nil
	end
	-- the bomb, all the way down, the shield breaking: a dev's, or FULL POWER
	function DevFly.fullPower()
		if FGc.dev() then
			return true
		end
		return DevFly.canFly() and player:GetAttribute("FlightFull") == true
	end
	-- who gives it (the panel): the devs only - the server checks every change
	function FGc.allowed()
		return FGC.Enabled ~= false and FGc.dev()
	end
	-- how to take off, on what he's playing on
	function FGc.hint()
		if inputMode == "Gamepad" then
			return "HOLD D-PAD DOWN TO FLY"
		elseif inputMode == "Touch" then
			return "TAP FLY TO TAKE OFF"
		end
		return "PRESS " .. string.upper((DEV.Key and DEV.Key.Name) or "V") .. " TO FLY"
	end

	-- the phone's FLY: a tap flies / stops; held on the street, the charge
	Touch.handlers.QuirkDevFly = {
		down = function()
			local F = DevFly.F
			if not F or not DevFly.toggle or not DevFly.canFly() then
				return
			end
			if DevFly.active and F.state == "Crouch" then
				return
			end
			DevFly.toggle(true)
		end,
		up = function()
			if DevFly.F then
				DevFly.F.charging = false
			end
		end,
	}
	function FGc.touch()
		FGc.lit = DevFly.active == true
		if HUD.SetTouchFly then
			HUD.SetTouchFly(DevFly.canFly(), FGc.lit)
		end
	end
	-- (lit the moment his own flight starts or stops, whatever started it)
	RunService.Heartbeat:Connect(function()
		if (DevFly.active == true) ~= FGc.lit then
			FGc.touch()
		end
	end)

	-- given or taken back (his own attribute): the keys, the row, the carry,
	-- the pad; taken back mid-flight, down he goes (the flight's own stop)
	function FGc.regate()
		if DevFly.canFly() then
			if DevFly.bind then
				DevFly.bind()
			end
		else
			if DevFly.unbind then
				DevFly.unbind()
			end
			if DevFly.active and DevFly.stop then
				DevFly.stop("Off")
			end
		end
		if DevFly.menu then
			DevFly.menu()
		end
		if DevFly.CR and DevFly.CR.sync then
			task.defer(DevFly.CR.sync)
		end
		FGc.touch()
	end
	player:GetAttributeChangedSignal("FlightGrant"):Connect(FGc.regate)
	player:GetAttributeChangedSignal("DevFlyer"):Connect(FGc.touch)

	-- the toast (the server's PlayVFX "FlightGrant": Event = Granted / Changed / Revoked / Join)
	local EVENTS = { Granted = true, Changed = true, Revoked = true, Join = true }
	UI_EVENTS.FlightGrant = function(data)
		if not EVENTS[data.Event] then
			return
		end
		HUD.FlightGrantToast({
			Event = data.Event, By = type(data.By) == "string" and data.By or "", Kind = data.Kind, Full = data.Full == true,
			WasKind = data.WasKind, WasFull = data.WasFull == true, Flying = data.Flying == true, Hint = FGc.hint(),
		})
		VFX.PlaySound(data.Event == "Revoked" and "FlightRevoked" or "FlightGranted")
	end

	-- GIVE FLIGHT (the devs' panel): everyone else here (from their
	-- attributes), then the saved grants of those who aren't (workspace's list)
	table.insert(TEST_ITEMS, 1, { Id = "FlightGrantPanel", Label = "GIVE FLIGHT...", Group = "Dev only" })
	function FGc.state()
		local rows, here = {}, {}
		for _, other in Players:GetPlayers() do
			here[other.UserId] = true
			if other ~= player then
				table.insert(rows, {
					UserId = other.UserId, Name = other.Name, Display = other.DisplayName, Here = true,
					Dev = other:GetAttribute("DevFlyer") == true, Kind = other:GetAttribute("FlightGrant"),
					Full = other:GetAttribute("FlightFull") == true, By = other:GetAttribute("FlightGrantBy"), At = other:GetAttribute("FlightGrantAt"),
				})
			end
		end
		for _, e in Config.ParseFlightGrants(workspace:GetAttribute(FGC.Attribute or "FlightGrantsSaved")) do
			if not here[e.Id] then
				table.insert(rows, { UserId = e.Id, Name = e.Name, Display = e.Name, Here = false, Kind = "Perm", Full = e.Full, By = e.By, At = e.At })
			end
		end
		return {
			Rows = rows, Sync = workspace:GetAttribute("FlightGrantSync"), By = workspace:GetAttribute("FlightGrantLastBy"),
			At = workspace:GetAttribute("FlightGrantLastAt"),
		}
	end
	function FGc.build()
		if FGc.built or not player:GetAttribute("Tester") or not FGc.allowed() then
			return
		end
		FGc.built = true
		HUD.BuildFlightGrantPanel({
			State = FGc.state,
			Set = function(userId, kind, full)
				VFX.PlaySound("RosterToggle")
				TestCommand:FireServer("FlightGrant", userId, { Kind = kind, Full = full })
			end,
			TakeAll = function()
				VFX.PlaySound("RosterToggle")
				TestCommand:FireServer("FlightGrantAll", nil, "off")
			end,
		})
		local function refresh()
			HUD.RefreshFlightGrantPanel()
		end
		local function watch(other)
			for _, a in { "FlightGrant", "FlightFull", "FlightGrantBy", "DevFlyer" } do
				other:GetAttributeChangedSignal(a):Connect(refresh)
			end
		end
		for _, other in Players:GetPlayers() do
			watch(other)
		end
		Players.PlayerAdded:Connect(function(other)
			watch(other)
			refresh()
		end)
		Players.PlayerRemoving:Connect(function()
			task.defer(refresh)
		end)
		for _, a in { FGC.Attribute or "FlightGrantsSaved", "FlightGrantSync", "FlightGrantLastBy", "FlightGrantLastAt" } do
			workspace:GetAttributeChangedSignal(a):Connect(refresh)
		end
	end
	function FGc.menu()
		-- ((round 92 review) a row with no panel behind it does nothing: built
		-- here too if it isn't yet)
		if FGc.allowed() and not FGc.built then
			FGc.build()
		end
		HUD.ShowTestRow("FlightGrantPanel", FGc.allowed())
		-- ((round 92 review) not "no destruction": without FULL POWER he still
		-- smashes through buildings and craters the street - the flight's own)
		HUD.SetTestInfo("FlightGrantPanel", "GIVE FLIGHT", {
			"The DEV FLIGHT for anyone here  -  devs only",
			"<b>SERVER</b>: till they leave  ·  <b>SAVED</b>: every server, every visit",
			"Flight, every speed, LIGHTSPEED, the carry - no bombs",
			"<b>FULL POWER</b>: the bomb, all the way down, the shield too",
			"Not the director, possess or admin events: those stay yours",
			"Console: <b>giveflight bob perm full</b>  ·  <b>takeflight bob</b>",
		})
		if not FGc.allowed() and HUD.ToggleFlightGrantPanel then
			HUD.ToggleFlightGrantPanel(false)
		end
	end
	local function setup()
		FGc.build()
		task.defer(FGc.menu) -- (after the test menu's built)
	end
	player:GetAttributeChangedSignal("Tester"):Connect(setup)
	player:GetAttributeChangedSignal("DevFlyer"):Connect(setup)
	setup()
	FGc.touch()
end

---------------------------------------------------------------------------
-- (round 86) DEV FLIGHT (Config.DevFlight): Invincible / Omni-Man flight
-- for the owner and the Devs (the server marks them DevFlyer and checks
-- everything that touches anyone else). This machine flies him - it owns
-- his body: a LinearVelocity he steers, his body laid along where he's
-- going (banked into turns, upright in the hover), the camera trailing on
-- a spring (lag, roll, the field of view by speed - always given back),
-- the wind in his ears, the speed lines. V (the test menu's DEV FLIGHT, or
-- the D-pad held down) flies / stops: on the street a crouch then the
-- launch (held: charged), in the air he catches himself. W / the stick
-- flies where the camera looks, letting go hovers; sprint is FAST, kept up
-- HYPERSONIC (the boom); dash the mach burst; guard (or S) the braking
-- flip; X / RB the dive slam. At FAST and up he goes through breakable
-- walls (opened on his screen at once, carved by the server); unbreakable
-- ones stop him dead. Into the street: the superhero landing, or the
-- Omni-Man crash. A move or an M1 hangs him in the air while it plays; a
-- hit lets go of him (he catches himself after, if he's still up).
---------------------------------------------------------------------------
do
	local DEV = Config.DevFlight or {}
	local TIERS = DEV.Tiers or {}
	local CT = DEV.Control or {} -- (round 90)
	local F = {
		state = "Off", -- Off, Crouch, Ascent, Fly, Brake, Dive, Land, Crash, Held
		tier = "Hover", vel = Vector3.zero, dir = Vector3.new(0, 0, -1), spd = 0, hover = Vector3.zero,
		boomArmed = true, bank = 0, lag = 0, lagV = 0, roll = 0, rollV = 0, fov = nil, fovKick = 0,
		kick = Vector3.zero, kickV = Vector3.zero, applied = nil, walls = {}, groups = {}, smashes = {},
		pauseUntil = 0, boostCd = 0, brakeCd = 0, ctrlAt = -1, sent = {}, at = 0, next = {},
		-- (round 90) the strafe, the camera's swing, the light barrier's charge
		-- (0..1), LIGHTSPEED (light: { t0, from }), the hover-lock (lock: {
		-- anchor, nudge }), the hover's held spot (anchor), the roll (spin)
		strafe = Vector3.zero, strafeK = 0, turnWant = 0, swing = 0, swingV = 0, charge = 0,
	}
	DevFly.F = F
	VFX.Hooks.FlightBurst = HUD.FlightBurst
	VFX.Hooks.FlightDust = HUD.FlightDust
	VFX.DevFly = DevFly -- (the tests read the flight's state through this)

	function DevFly.allowed()
		return DEV.Enabled ~= false and player:GetAttribute("DevFlyer") == true
	end
	local function send(kind, data)
		UseAbility:FireServer(Config.PARKOUR_INDEX, kind, data)
	end
	DevFly.send = send
	-- the map only (not people, rubble or effects), what really collides
	function DevFly.params()
		local p = RaycastParams.new()
		local map = workspace:FindFirstChild("Map")
		if map then
			p.FilterType = Enum.RaycastFilterType.Include
			local list = { map }
			local terrain = workspace:FindFirstChildOfClass("Terrain")
			if terrain then
				table.insert(list, terrain)
			end
			p.FilterDescendantsInstances = list
		else
			p.FilterType = Enum.RaycastFilterType.Exclude
			p.FilterDescendantsInstances = { player.Character, VFX.Folder }
		end
		pcall(function()
			p.RespectCanCollide = true
		end)
		return p
	end
	-- what takes the body out of his hands (a hit, a grab, a ragdoll, a
	-- freeze, a finisher, his own move's cutscene)
	function DevFly.taken(char, root)
		return char:GetAttribute("Ragdolled") or char:GetAttribute("Grabbed") or char:GetAttribute("Frozen")
			or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished") or char:GetAttribute("Submerged")
			or root.Anchored or root:FindFirstChild("Knockback") ~= nil or root:FindFirstChild("FinisherLaunch") ~= nil
			or VFX.InOwnCinematic()
	end
	local function round3(v)
		return Vector3.new(math.floor(v.X * 1000 + 0.5) / 1000, math.floor(v.Y * 1000 + 0.5) / 1000, math.floor(v.Z * 1000 + 0.5) / 1000)
	end
	local function finite(v)
		return v == v and v.Magnitude < 1e5
	end
	local function massOf(root)
		local ok, m = pcall(function()
			return root.AssemblyMass
		end)
		return math.max(ok and tonumber(m) or 0, 1)
	end
	-- the height of his root over his feet (standing)
	local function standHeight(hum, root)
		return ((hum.HipHeight > 0) and hum.HipHeight or 2) + root.Size.Y / 2
	end
	-- the tier he shows (his pose, everyone else's picture of him)
	function DevFly.look()
		local s = F.state
		if s == "Crouch" or s == "Ascent" or s == "Brake" or s == "Dive" or s == "Land" or s == "Crash" or s == "Held" then
			return s
		end
		if os.clock() < F.pauseUntil then
			return "Held"
		end
		if F.boost then
			return "Boost"
		end
		if F.light then
			return "Light" -- (round 90: LIGHTSPEED)
		end
		local v = F.vel.Magnitude
		return v < 30 and "Hover" or (v < 150 and "Cruise" or (v < 380 and "Fast" or "Hyper"))
	end

	---------------------------------------------------------------------------
	-- on / off
	---------------------------------------------------------------------------
	function DevFly.toggle(charging)
		if not DevFly.canFly() then -- (round 92: a dev, or a grant)
			return
		end
		if DevFly.active then
			if F.state ~= "Land" and F.state ~= "Crash" then
				DevFly.stop("Off")
			end
		else
			DevFly.start(false, charging)
		end
	end

	-- quiet: the server already switched it on (the console, the test menu)
	function DevFly.start(quiet, charging)
		local char, hum, root = getCharacter()
		if DevFly.active or not char or not DevFly.canFly() or DevFly.taken(char, root) or char:GetAttribute("Stunned") then -- (round 92: canFly)
			return false
		end
		if BlastFly.active and BlastFly.stop then
			BlastFly.stop("Action")
		end
		if FloatFly.active and FloatFly.stop then
			FloatFly.stop("Hit")
		end
		if activeDashCleanup then
			activeDashCleanup("Interrupted")
		end
		F.drop = nil
		DevFly.active = true
		F.char, F.hum, F.root = char, hum, root
		F.params = DevFly.params()
		F.att = Instance.new("Attachment")
		F.att.Name = "DevFlightAttachment"
		F.att.Parent = root
		F.lv = Instance.new("LinearVelocity")
		F.lv.Name = "DevFlight"
		F.lv.Attachment0 = F.att
		F.lv.ForceLimitsEnabled = true
		F.lv.MaxForce = massOf(root) * (DEV.MaxForce or 20000)
		F.lv.RelativeTo = Enum.ActuatorRelativeTo.World
		F.lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		F.lv.VectorVelocity = Vector3.zero
		F.lv.Parent = root
		-- (while a move holds him in the air: gravity off, his move's movers free)
		F.vf = Instance.new("VectorForce")
		F.vf.Name = "DevFlightLift"
		F.vf.Attachment0 = F.att
		F.vf.RelativeTo = Enum.ActuatorRelativeTo.World
		F.vf.ApplyAtCenterOfMass = true
		F.vf.Force = Vector3.zero
		F.vf.Parent = root
		hum.PlatformStand = true
		hum.AutoRotate = false
		F.setGroups(true)
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or root.CFrame.LookVector
		local fl = flat(look)
		F.rot = CFrame.lookAt(Vector3.zero, fl.Magnitude > 0.05 and fl.Unit or Vector3.new(0, 0, -1))
		F.vel, F.spd, F.hover, F.boost, F.boomArmed = Vector3.zero, 0, Vector3.zero, nil, true
		F.dir = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		F.tier, F.bank, F.lag, F.lagV, F.roll, F.rollV, F.fovKick = "Hover", 0, 0, 0, 0, 0, 0
		F.kick, F.kickV = Vector3.zero, Vector3.zero
		F.fov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
		F.pauseUntil, F.heldSince, F.freeSince, F.fovHold = 0, nil, nil, 0
		F.sent = {}
		-- (round 90) nothing of the last flight's control or LIGHTSPEED left over
		F.strafe, F.strafeK, F.turnWant, F.swing, F.swingV, F.carve = Vector3.zero, 0, 0, 0, 0, 0
		F.light, F.barrier, F.barrierOn, F.dashHeld, F.lock, F.lockAfter = nil, 0, false, false, nil, nil
		F.anchor, F.stillAt, F.spin, F.brakeLight, F.diveSpd = nil, nil, nil, nil, nil
		local stand = standHeight(hum, root)
		local below = workspace:Raycast(root.Position, Vector3.new(0, -(stand + 2.5), 0), F.params)
		local grounded = hum.FloorMaterial ~= Enum.Material.Air or below ~= nil
		F.stateAt = os.clock()
		if grounded then
			-- the crouch: still on the street, coiling (held: charging)
			F.state = "Crouch"
			F.charging = charging == true
			F.crouchBeats = 0
			F.ground = below and below.Position or (root.Position - Vector3.new(0, stand, 0))
			VFX.Play("DevFly", char, { Kind = "Crouch", Charge = 0 }, true)
		else
			-- caught himself in the air
			F.state = "Fly"
			F.vel = root.AssemblyLinearVelocity * 0.4
			F.hover = F.vel
			VFX.Play("DevFly", char, { Kind = "Catch" }, true)
			send("DevCatch")
		end
		char:SetAttribute("DevFlyLocal", DevFly.look())
		if VFX.DFX then
			VFX.DFX.track(char)
		end
		ContextActionService:BindActionAtPriority("QuirkDevFlySink", DevFly.onKey, false, 3000, table.unpack(DevFly.flightKeys()))
		RunService:BindToRenderStep("QuirkDevFlyStrip", Enum.RenderPriority.Camera.Value - 2, DevFly.strip)
		RunService:BindToRenderStep("QuirkDevFlyCam", Enum.RenderPriority.Camera.Value + 3, DevFly.camera)
		F.conn = RunService.Heartbeat:Connect(function(dt)
			local ok, err = pcall(DevFly.step, math.min(tonumber(dt) or 1 / 60, 0.1))
			if not ok then
				warn("[DevFly] " .. tostring(err))
				DevFly.stop("Gone")
			end
		end)
		if not quiet then
			send("DevFlyToggle", true)
		end
		DevFly.relay(true)
		if DevFly.CR then
			DevFly.CR.flightOn() -- (round 88: the flight's move bar - his moves and GRAB)
		end
		return true
	end

	-- reason: "Off" (switched off mid-air: he drops, keeping some of it),
	-- "Landed" (on his feet), "Gone" (no body), "Server" (switched off there)
	function DevFly.stop(reason)
		if not DevFly.active then
			return
		end
		DevFly.active = false
		if F.conn then
			F.conn:Disconnect()
			F.conn = nil
		end
		pcall(function()
			ContextActionService:UnbindAction("QuirkDevFlySink")
		end)
		F.down, F.padSprint = false, false
		-- (round 90) the light barrier's charge let go, out of LIGHTSPEED, the
		-- hover-lock off (its sight off the screen), no roll left turning him
		if DevFly.Light then
			DevFly.Light.reset()
		end
		if F.lock or F.lockAfter then
			DevFly.Ctl.lock(false, true)
		end
		F.spin, F.anchor, F.strafe = nil, nil, Vector3.zero
		if HUD.FlightLight then
			HUD.FlightLight(nil)
		end
		local char, hum, root = F.char, F.hum, F.root
		local carry = F.vel
		for _, x in { F.lv, F.vf, F.att } do
			if x then
				x:Destroy()
			end
		end
		F.lv, F.vf, F.att = nil, nil, nil
		F.setGroups(false)
		F.closeWalls(true)
		if hum and hum.Parent then
			hum.PlatformStand = false
			hum.AutoRotate = true
		end
		-- (round 86 review: not while a hit or a ragdoll has his body - it
		-- keeps its own fall - and never a NaN facing: lying along the street
		-- his look can be straight down)
		if root and root.Parent and reason == "Off" and finite(carry) and F.state ~= "Held" then
			-- (he drops: some of his speed carries him on)
			root.AssemblyLinearVelocity = Vector3.new(carry.X * 0.35, math.min(carry.Y * 0.5, 40), carry.Z * 0.35)
			local face = flat(carry)
			if face.Magnitude <= 1 then
				face = flat(root.CFrame.LookVector)
				if face.Magnitude <= 0.05 then
					face = flat(root.CFrame.UpVector)
				end
			end
			face = face.Magnitude > 0.05 and face.Unit or Vector3.new(0, 0, -1)
			root.CFrame = CFrame.new(root.Position) * CFrame.lookAt(Vector3.zero, face).Rotation
			F.drop = { untilAt = os.clock() + (DEV.DropWindow or 8), fall = 0 }
		end
		if char then
			char:SetAttribute("DevFlyLocal", nil)
			if VFX.DFX and reason ~= "Landed" then
				VFX.DFX.untrack(char)
			end
		end
		F.state = "Off"
		F.boost = nil
		DevFly.uncamera()
		HUD.FlightLines(0)
		HUD.FlightMeter(nil)
		if VFX.DFX then
			VFX.DFX.stopMine(reason == "Gone" and 0.15 or 0.6)
		end
		if reason ~= "Server" and reason ~= "Gone" then
			send("DevFlyToggle", false)
		end
		send("DevFlyEnd")
		if DevFly.CR then
			DevFly.CR.flightOff(reason) -- (round 88: let go of anyone, and exactly the bar he had)
		end
	end

	-- his body in the DevFlyer group (through people and rubble; only the
	-- map stops him) - and back as it was
	function F.setGroups(on)
		local char = F.char
		if on then
			for _, part in char and char:GetDescendants() or {} do
				if part:IsA("BasePart") and part.CollisionGroup ~= "DevFlyer" then
					F.groups[part] = F.groups[part] or part.CollisionGroup
					pcall(function()
						part.CollisionGroup = "DevFlyer"
					end)
				end
			end
		else
			for part, group in F.groups do
				if part.Parent then
					pcall(function()
						part.CollisionGroup = group
					end)
				end
			end
			table.clear(F.groups)
		end
	end

	-- walls opened on his screen close again Reopen s later (if the server
	-- didn't carve them, and he isn't in them); all of them when he stops
	function F.closeWalls(all)
		local now = os.clock()
		local root = F.root
		for part, at in F.walls do
			if all or now - at >= ((DEV.Smash or {}).Reopen or 1) then
				-- (round 86 review: in its box, 4 studs round - not its whole
				-- diagonal, which kept a long wall open far behind him)
				local inside = false
				if root and root.Parent and part.Parent then
					local rel = part.CFrame:PointToObjectSpace(root.Position)
					local h = part.Size / 2 + Vector3.one * 4
					inside = math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z
				end
				if all or not inside then
					F.walls[part] = nil
					if part.Parent then
						part.CanCollide = true
					end
				end
			end
		end
	end

	---------------------------------------------------------------------------
	-- the moves of the flight
	---------------------------------------------------------------------------
	-- THE MACH BURST: Add on top of his speed in a blink (at most Cap), held a
	-- moment, back to his tier (from the hover: down the camera's look)
	-- (round 90) held at HYPERSONIC, the same key charges the light barrier
	-- (DevFly.Light: the press here, the let go from the key's release); off
	-- the hover-lock it goes at once; at LIGHTSPEED there's nothing over it
	function DevFly.boost()
		local B = DEV.Boost or {}
		local now = os.clock()
		if DevFly.active and DevFly.Light then
			DevFly.Light.dashDown()
		end
		if DevFly.active and (F.lock or F.lockAfter) and F.state == "Fly" then
			DevFly.Ctl.lock(false, true)
		end
		if not DevFly.active or F.state ~= "Fly" or now < F.boostCd or now < F.pauseUntil or F.light then
			return false
		end
		F.boostCd = now + (B.Cooldown or 1.2)
		local cam = workspace.CurrentCamera
		local look = cam and cam.CFrame.LookVector or F.root.CFrame.LookVector
		if F.spd < 40 then
			F.dir = look.Unit
			F.spd = math.max(F.spd, F.vel.Magnitude)
			F.hover = Vector3.zero
		end
		local peak = math.min(F.spd + (B.Add or 460), B.Cap or 980)
		F.boost = { t0 = now, from = F.spd, peak = peak }
		F.burstAt = now -- (round 89, in Studio: any crash a moment after it is the bomb - DevFly.FB.need)
		F.kick = -F.dir * 8
		F.fovKick = math.max(F.fovKick, (B.Fov or 112) - 100)
		VFX.Play("DevFly", F.char, { Kind = "Boost", Dir = F.dir }, true)
		send("DevBoost", { Dir = F.dir })
		return true
	end

	-- THE BRAKING FLIP: from MinSpeed up - pitched back feet first, skidding
	-- on the air, then upright in the hover
	function DevFly.brake()
		local BR = DEV.Brake or {}
		local now = os.clock()
		if not DevFly.active or F.state ~= "Fly" or now < F.brakeCd or F.vel.Magnitude < (BR.MinSpeed or 80) then
			return false
		end
		F.brakeCd = now + (BR.Cooldown or 0.6)
		F.state = "Brake"
		F.stateAt = now
		F.brakeFrom = F.vel
		F.boost = nil
		-- (round 90) from LIGHTSPEED: the longer flip (Light.Brake), the light snapping off him
		F.brakeLight = F.light ~= nil or nil
		if F.light and DevFly.Light then
			DevFly.Light.drop("Out")
		end
		F.strafe, F.spin, F.anchor = Vector3.zero, nil, nil
		F.fovKick = math.min(F.fovKick, (BR.Fov or 64) - 70)
		local d = F.vel.Unit
		VFX.Play("DevFly", F.char, { Kind = "Brake", Dir = d }, true)
		send("DevBrake", { Dir = d })
		return true
	end

	-- THE DIVE SLAM: onto where the camera looks (the street within Range),
	-- or straight down at Angle - and the crash when he gets there
	function DevFly.dive()
		local DS = DEV.DiveSlam or {}
		if not DevFly.active or F.state ~= "Fly" or os.clock() < F.pauseUntil then
			return false
		end
		-- (round 90) off the hover-lock; from LIGHTSPEED he keeps his speed down
		-- (Dive's own at least - the crash is the bomb, capped as ever)
		if F.lock or F.lockAfter then
			DevFly.Ctl.lock(false, true)
		end
		F.diveSpd = F.light and F.spd or nil
		if F.light and DevFly.Light then
			DevFly.Light.drop("Quiet")
		end
		F.strafe, F.spin, F.anchor = Vector3.zero, nil, nil
		local cam = workspace.CurrentCamera
		local root = F.root
		local look = cam and cam.CFrame.LookVector or root.CFrame.LookVector
		local from = cam and cam.CFrame.Position or root.Position
		local hit = workspace:Raycast(from, look * (DS.Range or 600), F.params)
		local to
		if hit and (hit.Position - root.Position).Magnitude > 8 then
			to = hit.Position
		else
			local fl = flat(look)
			fl = fl.Magnitude > 0.05 and fl.Unit or flat(root.CFrame.LookVector).Unit
			local a = math.rad(DS.Angle or 45)
			to = root.Position + (fl * math.cos(a) - Vector3.yAxis * math.sin(a)) * (DS.Range or 600)
		end
		F.state = "Dive"
		F.stateAt = os.clock()
		F.diveTo = to
		F.dir = (to - root.Position).Unit
		F.spd = math.max(F.spd, F.vel.Magnitude)
		F.hover = Vector3.zero
		F.boost = nil
		F.kick = -F.dir * 6
		VFX.Play("DevFly", F.char, { Kind = "Dive", Pos = hit and to or nil }, true)
		send("DevDive", { Pos = hit and to or nil })
		return true
	end

	-- a move or an M1 while he's up: he hangs there for it
	function DevFly.pause(t)
		if DevFly.active and (F.state == "Fly" or F.state == "Ascent") then
			F.pauseUntil = math.max(F.pauseUntil, os.clock() + (t or 0.45))
			-- (round 90: he stops for it - out of LIGHTSPEED, the light barrier's charge let go)
			if DevFly.Light and (F.light or F.barrierOn) then
				local was = F.light
				DevFly.Light.reset()
				F.light = was
				DevFly.Light.drop("Out")
			end
		end
	end

	-- down on the street: the superhero landing ("Land"), a soft touchdown
	-- ("Soft") or the crash ("Crash") - then he's on his feet
	function DevFly.land(kind, ground, speed)
		local char, hum, root = F.char, F.hum, F.root
		local CR = DEV.Crash or {}
		F.state = kind == "Crash" and "Crash" or "Land"
		F.stateAt = os.clock()
		F.boost = nil
		-- (round 90) down on the street: out of LIGHTSPEED (the crash - the bomb - is the beat), no charge
		if DevFly.Light and (F.light or F.barrierOn) then
			DevFly.Light.reset()
		end
		if F.lock or F.lockAfter then
			DevFly.Ctl.lock(false, true)
		end
		local face = flat(F.vel)
		if face.Magnitude < 1 then
			face = flat(root.CFrame.LookVector)
		end
		face = face.Magnitude > 0.05 and face.Unit or Vector3.new(0, 0, -1)
		F.rot = CFrame.lookAt(Vector3.zero, face)
		root.CFrame = CFrame.new(ground + Vector3.new(0, standHeight(hum, root), 0)) * F.rot
		root.AssemblyLinearVelocity = Vector3.zero
		F.vel, F.spd, F.hover = Vector3.zero, 0, Vector3.zero
		if F.lv then
			F.lv.VectorVelocity = Vector3.zero -- (at once: not one more frame driving him into the street)
		end
		local data = { Kind = kind, Pos = ground, Speed = speed }
		if kind == "Crash" then
			local r0, r1 = (CR.Radius or {})[1] or 9, (CR.Radius or {})[2] or 18
			data.Radius = math.clamp(r0 + (speed - (CR.Speed or 260)) / (CR.PerStud or 45), r0, r1)
			F.fovKick = -10
			F.landFor = (CR.Hold or 0.9) + (CR.Rise or 0.55)
			if DevFly.LW and DevFly.LW.predict(data) then
				-- (round 92: at LIGHTSPEED, the end of the map - its impact is his beat, not the bomb)
			elseif DevFly.FB then
				DevFly.FB.predict(data, speed) -- (round 89: at mach speed his screen plays the bomb)
			end
		elseif kind == "Land" then
			F.fovKick = -4
			F.landFor = ((DEV.Land or {}).Hold or 0.45) + ((DEV.Land or {}).Rise or 0.4) + 0.1
		else
			F.landFor = 0.2
		end
		char:SetAttribute("DevFlyLocal", F.state)
		VFX.Play("DevFly", char, data, true)
		-- (round 88: the carry's SLAM hits the street here - told before the
		-- landing: its splash lands first, then the crash knocks them about.
		-- The other way round the crash had them off their feet already, and
		-- nobody lying in the street is hit)
		if DevFly.CR then
			DevFly.CR.landed(kind, ground, speed)
		end
		send("DevLand", { Kind = kind, Pos = ground, Speed = speed, Light = data.Light, Hit = data.Hit }) -- (round 92: Light / Hit - DevFly.LW)
	end

	-- the keys that are the flight's while he's up (sunk: no move, no guard)
	function DevFly.flightKeys()
		local keys = { DEV.DownKey or Enum.KeyCode.C, Enum.KeyCode.ButtonL2, DEV.DiveKey or Enum.KeyCode.X, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonR2 }
		for _, k in Config.BlockKeys or { Enum.KeyCode.F } do
			table.insert(keys, k)
		end
		-- (round 90) the hover-lock's keys ((round 92) its own now:
		-- Config.DevFlight.LockKeys, bound only here, only while he flies)
		for _, k in DEV.LockKeys or {} do
			table.insert(keys, k)
		end
		return keys
	end
	function DevFly.onKey(_, state, input)
		local key = input and input.KeyCode
		local down = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
		-- (round 86 review) RB with someone ready to finish: the FINISH, as on
		-- foot (passed on to it) - otherwise the dive slam
		if key == Enum.KeyCode.ButtonR1 and finishTarget and state == Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		-- (round 90) the hover-lock key (T / L3): THE HOVER-LOCK on / off
		-- ((round 92) sunk: there's no lock-on left to pass it on to)
		for _, k in DEV.LockKeys or {} do
			if key == k then
				if state == Enum.UserInputState.Begin and DevFly.Ctl then
					DevFly.Ctl.lockKey()
				end
				return Enum.ContextActionResult.Sink
			end
		end
		if key == (DEV.DownKey or Enum.KeyCode.C) or key == Enum.KeyCode.ButtonL2 then
			F.down = down
		elseif key == Enum.KeyCode.ButtonR2 then
			F.padSprint = down
		elseif key == (DEV.DiveKey or Enum.KeyCode.X) or key == Enum.KeyCode.ButtonR1 then
			if state == Enum.UserInputState.Begin then
				DevFly.dive()
			end
		elseif state == Enum.UserInputState.Begin then
			DevFly.brake() -- (the guard keys)
		end
		return Enum.ContextActionResult.Sink
	end

	---------------------------------------------------------------------------
	-- every frame (Heartbeat): where he wants to go, how fast, what's in the way
	---------------------------------------------------------------------------
	function DevFly.step(dt)
		local char, hum, root = getCharacter()
		if not char or char ~= F.char or root ~= F.root or hum.Health <= 0 then
			DevFly.stop("Gone")
			return
		end
		local now = os.clock()
		local lv, vf = F.lv, F.vf
		if not lv or not lv.Parent or not vf or not vf.Parent then
			DevFly.stop("Gone")
			return
		end
		-- (the server re-applies body groups on some changes: keep his)
		if now >= (F.next.groups or 0) then
			F.next.groups = now + 0.25
			F.setGroups(true)
			F.closeWalls(false)
		end
		-- something has his body: let go of it (and catch himself after)
		if DevFly.taken(char, root) then
			if F.state ~= "Held" then
				F.heldFrom = F.state
				F.state = "Held"
				F.boost = nil
				-- (round 90) a hit takes him out of the lock, the charge, LIGHTSPEED
				if DevFly.Light then
					DevFly.Light.reset()
				end
				if F.lock or F.lockAfter then
					DevFly.Ctl.lock(false, true)
				end
				F.spin, F.anchor, F.strafe = nil, nil, Vector3.zero
				char:SetAttribute("DevFlyLocal", "Held")
				DevFly.relay(true)
			end
			lv.Enabled = false
			vf.Force = Vector3.zero
			if char:GetAttribute("Ragdolled") then
				hum.PlatformStand = false
			end
			F.freeSince = nil
			F.vel = root.AssemblyLinearVelocity
			DevFly.frame(dt, root, char)
			return
		end
		if F.state == "Held" then
			F.freeSince = F.freeSince or now
			lv.Enabled = false
			if now - F.freeSince < 0.3 then
				DevFly.frame(dt, root, char)
				return
			end
			-- free again: up in the air he catches himself; down, he's on his feet
			local below = workspace:Raycast(root.Position, Vector3.new(0, -(standHeight(hum, root) + 2), 0), F.params)
			if below or hum.FloorMaterial ~= Enum.Material.Air then
				DevFly.stop("Landed")
				return
			end
			F.state = "Fly"
			F.tier = "Hover"
			F.vel = root.AssemblyLinearVelocity * 0.3
			F.hover, F.spd = F.vel, 0
			hum.PlatformStand = true
			VFX.Play("DevFly", char, { Kind = "Catch" }, true)
			send("DevCatch")
		end
		local paused = now < F.pauseUntil and (F.state == "Fly" or F.state == "Ascent")
		if paused then
			-- (a move's own movers have him: gravity off, nothing else)
			lv.Enabled = false
			vf.Force = Vector3.new(0, massOf(root) * workspace.Gravity, 0)
			F.vel = root.AssemblyLinearVelocity * 0.5
			F.hover, F.spd = F.vel, 0
			-- (round 90) a move may move him: the hover's spot (and the lock's)
			-- taken again where he is after it
			F.anchor, F.stillAt = nil, nil
			if F.lock then
				F.lock.anchor = nil
			end
			DevFly.frame(dt, root, char)
			return
		end
		lv.Enabled = true
		vf.Force = Vector3.zero
		hum.PlatformStand = true
		hum.AutoRotate = false -- (round 90: anything letting go of his body turns it back on)
		local s = F.state
		if s == "Crouch" then
			DevFly.crouch(dt, now, char, root)
		elseif s == "Ascent" then
			DevFly.ascent(dt, now, char, hum, root)
		elseif s == "Fly" then
			DevFly.fly(dt, now, char, hum, root)
		elseif s == "Brake" then
			-- (round 90: from LIGHTSPEED, the longer flip - Light.Brake)
			local BR = F.brakeLight and (DEV.Light or {}).Brake or DEV.Brake or {}
			local t = now - F.stateAt
			F.vel = F.brakeFrom * math.exp(-(BR.Decay or 9) * t)
			if t >= (BR.Time or 0.45) then
				F.state = "Fly"
				F.tier = "Hover"
				F.hover, F.spd = F.vel, 0
				F.brakeLight = nil
				-- (round 90) the hover-lock's key at speed: the flip, then locked here
				if F.lockAfter and DevFly.Ctl then
					DevFly.Ctl.lock(true)
				end
			end
		elseif s == "Dive" then
			local DS = DEV.DiveSlam or {}
			-- ((round 90 review) down a building's shaft from LIGHTSPEED - Kit.FB's
			-- drill: out of it, as the dive slam takes him out of it)
			if F.light and DevFly.Light then
				DevFly.Light.drop("Quiet")
			end
			local want = (F.diveTo - root.Position)
			if want.Magnitude > 2 then
				local nd = F.dir:Lerp(want.Unit, math.min(1, dt * 6))
				F.dir = nd.Magnitude > 0.01 and nd.Unit or want.Unit -- (round 90: never a NaN heading)
			end
			-- (round 90: from LIGHTSPEED he keeps his speed on down)
			F.spd = F.spd + (math.max(DS.Speed or 760, F.diveSpd or 0) - F.spd) * (1 - math.exp(-12 * dt))
			F.vel = F.dir * F.spd
			if now - F.stateAt > 2.5 then
				F.state = "Fly"
				F.tier = "Hover"
			end
		elseif s == "Land" or s == "Crash" then
			F.vel = Vector3.zero
			if now - F.stateAt >= (F.landFor or 1) then
				DevFly.stop("Landed")
				return
			end
		end
		if not DevFly.active then
			return
		end
		-- what's ahead of him and under him (the walls, the street)
		if F.state == "Fly" or F.state == "Dive" or F.state == "Brake" or F.state == "Ascent" then
			DevFly.collide(dt, now, char, hum, root)
			if not DevFly.active or F.state == "Land" or F.state == "Crash" then
				DevFly.frame(dt, root, char)
				return
			end
		end
		-- the sonic boom: once each time he passes BoomAt going up
		local speed = F.vel.Magnitude
		if F.boomArmed and speed >= (DEV.BoomAt or 420) then
			F.boomArmed = false
			local d = speed > 1 and F.vel.Unit or root.CFrame.LookVector
			VFX.Play("DevFly", char, { Kind = "Boom", Pos = root.Position, Dir = d }, true)
			send("DevBoom", { Dir = d })
			F.fovKick = math.max(F.fovKick, 8)
		elseif not F.boomArmed and speed < (DEV.BoomRearm or 340) then
			F.boomArmed = true
		end
		-- the movers, and his body laid along it
		if not finite(F.vel) then
			F.vel, F.spd, F.hover = Vector3.zero, 0, Vector3.zero
		end
		-- (round 90) never under the void's floor, over the ceiling, out past the edge
		if DevFly.Ctl then
			F.vel = DevFly.Ctl.bounds(F.vel, root, dt)
		end
		lv.MaxForce = massOf(root) * ((speed > 380 or F.boost or F.light) and (DEV.MaxForceHyper or 40000) or (DEV.MaxForce or 20000))
		lv.VectorVelocity = round3(F.vel)
		DevFly.orient(dt, root)
		DevFly.frame(dt, root, char)
	end

	-- THE CROUCH (the take-off's anticipation): still, coiling; let go (or
	-- MaxCharge) and he's gone
	function DevFly.crouch(dt, now, char, root)
		local TK = DEV.Takeoff or {}
		local t = now - F.stateAt
		F.vel = Vector3.zero
		local max = TK.MaxCharge or 0.8
		local tap = TK.Tap or 0.24
		local charge = math.clamp((t - tap) / math.max(max - tap, 0.01), 0, 1)
		if F.charging and F.crouchBeats < 2 and charge >= (F.crouchBeats == 0 and 0.4 or 0.99) then
			F.crouchBeats += 1
			VFX.Play("DevFly", char, { Kind = "Crouch", Charge = F.crouchBeats == 1 and 0.6 or 1 }, true)
		end
		if (not F.charging and t >= tap) or t >= max then
			-- THE LAUNCH: gone in a blink - the camera left below him
			local sp = TK.Speed or { 240, 400 }
			local k = F.charging and 1 or charge
			F.charge = k
			F.state = "Ascent"
			F.stateAt = now
			F.ascentV = sp[1] + (sp[2] - sp[1]) * k
			F.vel = Vector3.new(0, F.ascentV, 0)
			F.kick = Vector3.new(0, -((DEV.Camera or {}).LaunchLag or 6), 0)
			F.fovKick = 14
			F.fovHold = now + ((DEV.Camera or {}).LaunchHold or 0.16) -- (round 86 review: the street drops away under a held punch)
			VFX.Play("DevFly", char, { Kind = "Takeoff", Pos = F.ground, Charge = k }, true)
			send("DevTakeoff", { Charge = k })
		end
	end

	-- THE ASCENT: straight up, easing off into the hover (a little drift
	-- after the first beat)
	function DevFly.ascent(dt, now, char, hum, root)
		local TK = DEV.Takeoff or {}
		local t = now - F.stateAt
		local vy = F.ascentV * math.exp(-(TK.AscentK or 2) * t)
		local md = hum.MoveDirection
		local drift = t > 0.25 and Vector3.new(md.X, 0, md.Z) * ((TIERS.Hover or {}).Drift or 24) or Vector3.zero
		F.vel = Vector3.new(drift.X, vy, drift.Z)
		if t >= (TK.Ascent or 0.9) or vy < 25 then
			F.state = "Fly"
			F.tier = "Hover"
			F.hover, F.spd = F.vel, 0
		end
	end

	-- FLYING: W along the camera's look (pitch and all), A/D across, Space /
	-- C up and down; the heading swings round to it at the tier's Turn, the
	-- speed builds at Up and bleeds off at Down; let go and he hovers
	-- (round 90, devfly2: the heading swung round a big turn at once and a
	-- hard one carved (DevFly.Ctl.steer); A / D at speed strafe across his
	-- line; A or D twice: the barrel roll; let go and he stops crisp and
	-- holds the spot; T / L3: the hover-lock; the burst held at
	-- HYPERSONIC: the light barrier and LIGHTSPEED - DevFly.Light)
	function DevFly.fly(dt, now, char, hum, root)
		local cam = workspace.CurrentCamera
		local look = cam and cam.CFrame.LookVector or root.CFrame.LookVector
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		local Ctl, Light = DevFly.Ctl, DevFly.Light
		-- (round 88) the carry's RAM flies him itself: flat out, held on its line
		if DevFly.CR and DevFly.CR.ramStep(dt, now, look) then
			if F.lock then
				Ctl.lock(false, true) -- (round 90: the RAM takes him off the hover-lock)
			end
			return
		end
		local fl = flat(look)
		if fl.Magnitude <= 0.05 then
			fl = flat(F.dir) -- (round 90: straight up or down - never a NaN way)
		end
		fl = fl.Magnitude > 0.05 and fl.Unit or Vector3.new(0, 0, -1)
		local fr = flat(cam and cam.CFrame.RightVector or root.CFrame.RightVector)
		fr = fr.Magnitude > 0.05 and fr.Unit or Vector3.zero
		local md = hum.MoveDirection
		local fwd, side = md:Dot(fl), md:Dot(fr)
		local up = slamJump.read(hum)
		local down = F.down == true
		local sprint = sprintHeld or sprintToggle or F.padSprint == true
			or (inputMode == "Gamepad" and stickMagnitude() >= (Config.AutoSprintStick or 0.9))
		if char:GetAttribute("Stunned") or FreeCam.on then
			fwd, side, up, down, sprint = 0, 0, false, false, false
		end
		-- (round 90) A or D twice quickly: the barrel roll (the sidestep, hovering)
		local tapped = Ctl.taps(side, now)
		if tapped then
			Ctl.roll(tapped, fr)
		end
		-- (round 90 review) the hover-lock's key at speed waiting on the flip
		if Ctl.pending() then
			return
		end
		-- (round 90) THE HOVER-LOCK: dead still where he is, nudged (its own step)
		if F.lock and Ctl.lockStep(dt, now, root, fl, fr, fwd, side, up, down, sprint) then
			return
		end
		local H = TIERS.Hover or {}
		-- the tier he's after
		local moving = fwd > 0.25
		if not moving then
			F.tier = "Hover"
			F.sprintAt = nil
		elseif sprint then
			if F.tier ~= "Fast" and F.tier ~= "Hyper" and F.tier ~= "Light" then
				F.tier = "Fast"
				F.sprintAt = now
			end
			local HY = TIERS.Hyper or {}
			if F.tier == "Fast" and now - (F.sprintAt or now) >= (HY.Enter or 1) and F.spd >= ((TIERS.Fast or {}).Speed or 220) * 0.85 then
				F.tier = "Hyper"
			end
			if F.light then
				F.tier = "Light" -- (round 90: LIGHTSPEED, held while W and sprint are)
			end
		else
			F.tier = "Cruise"
			F.sprintAt = nil
		end
		-- (round 90) the light barrier: the burst held at HYPERSONIC charges it,
		-- full it breaks; under Rearm he drops back out of LIGHTSPEED
		Light.step(dt, now, char, sprint, fwd)
		-- S held at speed: the braking flip
		if fwd < -0.5 and F.spd >= ((DEV.Brake or {}).MinSpeed or 80) and DevFly.brake() then
			return
		end
		local T = TIERS[F.tier] or {}
		-- the heading (round 90: swung round at the tier's Turn - a big turn at
		-- once, a hard one a carve that costs speed; A / D only bend it a little
		-- now, they strafe)
		local wish = look * math.max(fwd, 0) + fr * side * (CT.SideTurn or 0.18) + Vector3.yAxis * ((up and 1 or 0) - (down and 1 or 0)) * 0.6
		if moving and wish.Magnitude > 0.05 then
			wish = wish.Unit
			local turn = F.boost and ((DEV.Boost or {}).Turn or 0.8) or (T.Turn or 6)
			Ctl.steer(wish, turn, dt, fr)
		else
			F.turnWant, F.carve = 0, 0
		end
		-- the speed: quick to go, slow to stop (the higher he is, the longer)
		local target = moving and (T.Speed or 0) * math.clamp(fwd, 0, 1) or 0
		local at = F.spd > 980 and TIERS.Light or (F.spd > 380 and TIERS.Hyper or (F.spd > 150 and TIERS.Fast or TIERS.Cruise)) or {}
		local k = target > F.spd and (T.Up or 6) or ((at or {}).Down or 3)
		local jump = Light.jump(now)
		if jump then
			F.spd = jump -- (round 90: through the light barrier)
		else
			F.spd += (target - F.spd) * (1 - math.exp(-k * dt))
		end
		-- the mach burst rides on top
		local B = DEV.Boost or {}
		local bo = F.boost
		if bo then
			local t = now - bo.t0
			local rise, hold, decay = B.Rise or 0.06, B.Hold or 0.18, B.Decay or 0.5
			if t < rise then
				F.spd = bo.from + (bo.peak - bo.from) * (t / rise)
			elseif t < rise + hold then
				F.spd = bo.peak
			elseif t < rise + hold + decay then
				local a = (t - rise - hold) / decay
				F.spd = bo.peak + (math.max(target, 0) - bo.peak) * (1 - (1 - a) * (1 - a))
			else
				F.boost = nil
			end
		end
		-- the hover: A/D/S drift, up and down, the slow bob; it fades out at speed
		local hw = Vector3.zero
		local idle, bobY, bobV = false, 0, 0
		if not moving then
			hw = fr * side * (H.Drift or 24) + fl * math.min(fwd, 0) * (H.Drift or 24)
			local rise = sprint and (H.FastRise or 64) or (H.Rise or 30)
			local sink = sprint and (H.FastSink or 40) or (H.Sink or 12)
			hw += Vector3.yAxis * ((up and rise or 0) - (down and sink or 0))
			if not up and not down and md.Magnitude < 0.1 then
				local w = 2 * math.pi / (H.BobPeriod or 3.2)
				bobY = (H.Bob or 0.5) * math.sin(now * w)
				bobV = (H.Bob or 0.5) * w * math.cos(now * w)
				hw += Vector3.yAxis * bobV
				idle = true
			end
		end
		-- (round 90: let go, he stops crisp - Control.Stop - not a slide)
		F.hover += (hw - F.hover) * (1 - math.exp(-(moving and 5 or (idle and (CT.Stop or 14) or (H.Accel or 7))) * dt))
		-- (round 90) A / D at speed: the strafe across his line
		Ctl.strafe(side, T, dt, moving, fr)
		F.vel = F.dir * F.spd + F.hover + F.strafe
		-- (round 90) once he's still he holds the spot (the breath on top)
		local held = Ctl.hold(root, idle and not F.spin, bobY, bobV, now)
		if held then
			F.hover = held
			F.vel = F.dir * F.spd + held
		end
		-- (round 90) the barrel roll / the sidestep: thrown across
		local push = Ctl.rolling(now)
		F.vel += push
		-- (a double-tap of sprint: the burst; read here, where sprint is)
		local nowSprint = sprintHeld == true
		if nowSprint and not F.ctrlDown then
			if now - F.ctrlAt < (B.DoubleTap or 0.3) then
				DevFly.boost()
				-- (round 90: a sprint double-tap isn't the burst key held)
				if DevFly.Light then
					DevFly.Light.dashUp()
				end
			end
			F.ctrlAt = now
		end
		F.ctrlDown = nowSprint
	end

	-- the walls and the street: at FAST and up a breakable wall ahead is
	-- opened at once (and carved by the server); an unbreakable one at speed
	-- stops him dead; the street coming up is a landing, a crash, or (a
	-- shallow fast pass) skimmed Skim studs over
	function DevFly.collide(dt, now, char, hum, root)
		local SM = DEV.Smash or {}
		local speed = F.vel.Magnitude
		local stand = standHeight(hum, root)
		local params = F.params
		-- the street under him (the skim, the dust)
		local below = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
		local feet = below and (root.Position.Y - below.Position.Y - stand) or math.huge
		if speed < 1 then
			-- (hovering down onto it)
			if below and feet < 0.4 and F.vel.Y <= 0 and F.state == "Fly" and F.down then
				DevFly.land("Soft", below.Position, speed)
			end
			return
		end
		local d = F.vel.Unit
		-- (round 90) the Sky Coffin's barrier ahead: he breaks through it
		-- (DevFly.SB lets it go before the rays below can stop him on it)
		if DevFly.SB then
			DevFly.SB.ahead(dt, now, char, root)
		end
		-- ahead, far, at speed: a breakable wall to go through
		if speed >= (SM.Speed or 200) and F.state ~= "Ascent" then
			local la = SM.LookAhead or { 0.15, 8 }
			local reach = speed * la[1] + la[2]
			local hit = workspace:Raycast(root.Position - d * 2, d * (reach + 2), params)
			if hit and hit.Normal.Y < 0.6 and hit.Instance and hit.Instance:IsA("BasePart") then
				if DevFly.breakable(hit.Instance) then
					DevFly.smash(char, root, hit, d, speed)
				end
			end
		end
		-- right ahead, this frame: the street, or a wall that won't break
		local near = speed * math.max(dt, 1 / 30) * 1.5 + 3 -- (a frame and a half ahead, even on a slow machine)
		local hit = workspace:Raycast(root.Position - d * 1.5, d * (near + 1.5), params)
		if hit and hit.Instance then
			local n = hit.Normal
			if n.Y >= 0.6 and F.vel.Y < 0 then
				DevFly.touchdown(hit.Position, n, speed, hit.Instance)
				return
			elseif n.Y < 0.6 and speed >= ((DEV.WallHit or {}).Speed or 200) and not DevFly.breakable(hit.Instance) then
				DevFly.wall(char, hit, speed)
				return
			end
		end
		-- (coming straight down onto it)
		if below and feet < 0.6 and F.vel.Y < -2 then
			DevFly.touchdown(below.Position, below.Normal, speed, below.Instance)
			return
		end
		-- skimming: a shallow fast pass is held over the street, not landed
		local skim = DEV.Skim or 4.5
		if below and feet < skim and F.state == "Fly" and speed > 40 then
			local lift = (skim - feet) * 8
			if F.vel.Y < lift then
				F.vel = Vector3.new(F.vel.X, lift, F.vel.Z)
				if F.dir.Y < 0 then
					local fd = Vector3.new(F.dir.X, 0, F.dir.Z)
					F.dir = fd.Magnitude > 0.01 and fd.Unit or F.dir
				end
			end
		end
	end

	-- a part the server would carve (Destruction's own rule)
	function DevFly.breakable(part)
		return part:IsA("Part") and part:GetAttribute("Destroyable") == true and workspace:GetAttribute("DestructionEnabled") ~= false
	end

	-- the street coming up: crash (fast and steep, or the dive), land
	-- (steep or slow), or a shallow pass held over it
	-- (round 89: part - what he's coming down on; a building's roof or floor
	-- isn't the end of a crash: DevFly.FB.drill takes him on down to the street)
	function DevFly.touchdown(at, normal, speed, part)
		local CR, LD = DEV.Crash or {}, DEV.Land or {}
		local into = -F.vel:Dot(normal)
		local steep = math.deg(math.asin(math.clamp(-F.vel.Y / math.max(speed, 1e-3), -1, 1)))
		if F.state == "Dive" or (speed >= (CR.Speed or 260) and steep >= (CR.Pitch or 25)) or into >= (CR.IntoSurface or 200) then
			-- (round 92) at LIGHTSPEED onto the city: the end of the map (DevFly.LW)
			if DevFly.LW and DevFly.LW.impact(at, speed) then
				return
			end
			if DevFly.FB and DevFly.FB.drill(at, part, speed) then
				return
			end
			DevFly.land("Crash", at, speed)
		elseif steep >= (LD.Steep or 20) or speed < (LD.Slow or 60) then
			DevFly.land(-F.vel.Y >= (LD.MinDown or 30) and "Land" or "Soft", at, speed)
		else
			local fd = Vector3.new(F.dir.X, 0, F.dir.Z)
			F.dir = fd.Magnitude > 0.01 and fd.Unit or F.dir
			F.vel = Vector3.new(F.vel.X, math.max(F.vel.Y, 4), F.vel.Z)
		end
	end

	-- THROUGH A WALL: the breakable parts in a capsule ahead opened on his
	-- screen at once (he never snags), the server told (it carves the hole
	-- for everyone, clamped to where it sees him), the burst played here now
	function DevFly.smash(char, root, hit, d, speed)
		local SM = DEV.Smash or {}
		local look = DevFly.look()
		local radii = SM.Radius or {}
		local r = (look == "Boost" or look == "Dive") and (radii.Boost or 8) or (speed >= 380 and (radii.Hyper or 6.5) or (radii.Fast or 4.5))
		local LS = (DEV.Light or {}).Smash or {}
		if look == "Light" then
			r = LS.Radius or 8 -- (round 90: LIGHTSPEED - the burst's hole, no speed lost)
		end
		local len = math.min(SM.SegMax or 36, speed * 0.12 + 20)
		local a = hit.Position - d * 2
		local b = a + d * len
		local params = OverlapParams.new()
		local map = workspace:FindFirstChild("Map")
		if map then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { map }
		end
		local now = os.clock()
		local opened = 0
		-- (round 86 review) never the street or a floor under him: the map's
		-- street slabs are Destroyable too (up to 218 studs long), and one
		-- opened here would drop him into it. Nothing whose top is at his
		-- feet or lower, and nothing the ray straight down from him meets
		local feet = root.Position.Y - standHeight(F.hum, root) + 0.5
		local under = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), F.params)
		local floor = under and under.Instance
		local function above(part)
			local cf, s = part.CFrame, part.Size
			local top = cf.Position.Y + (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
			return top > feet and part ~= floor
		end
		for _, part in workspace:GetPartBoundsInBox(CFrame.lookAt((a + b) / 2, b), Vector3.new(r * 2, r * 2, len), params) do
			if part:IsA("BasePart") and DevFly.breakable(part) and (part.CanCollide or F.walls[part]) and above(part) then
				part.CanCollide = false
				F.walls[part] = now
				opened += 1
			end
		end
		if hit.Instance and hit.Instance:IsA("BasePart") and DevFly.breakable(hit.Instance) and not F.walls[hit.Instance] and above(hit.Instance) then
			hit.Instance.CanCollide = false
			F.walls[hit.Instance] = now
			opened += 1
		end
		-- (the holes: at most Rate a second go to the server)
		while F.smashes[1] and now - F.smashes[1] > 1 do
			table.remove(F.smashes, 1)
		end
		if #F.smashes < (SM.Rate or 12) then
			table.insert(F.smashes, now)
			-- (round 89) the mach burst's first wall: a bomb there (the server told it was the burst)
			local blast = DevFly.FB ~= nil and DevFly.FB.wallBlast(char, hit.Position, hit.Normal, speed)
			send("DevSmash", { A = a, B = b, R = r, Bomb = blast or nil })
			VFX.Play("DevFly", char, { Kind = "Smash", A = a, B = b, Dir = d, R = r }, true)
		end
		local loss = SM.Loss or {}
		local cut = (look == "Boost" or look == "Dive") and (loss.Boost or 0) or (speed >= 380 and (loss.Hyper or 0.06) or (loss.Fast or 0.15))
		if look == "Light" then
			cut = LS.Loss or 0
		end
		F.spd *= 1 - cut
		F.vel *= 1 - cut -- (this frame too)
		F.fovKick = math.min(F.fovKick, -5)
		return opened
	end

	-- AN UNBREAKABLE WALL at speed: stopped dead, thrown back off it a little
	function DevFly.wall(char, hit, speed)
		local n = hit.Normal
		local blast = DevFly.FB ~= nil and DevFly.FB.wallBlast(char, hit.Position, n, speed) -- (round 89: into it at the burst - a bomb)
		F.vel = n * speed * ((DEV.WallHit or {}).Bounce or 0.12)
		F.hover, F.spd, F.boost = F.vel, 0, nil
		F.dir = (n * 0.3 + F.dir * 0.7).Magnitude > 0.01 and (n * 0.3 + F.dir * 0.7).Unit or n
		F.tier = "Hover"
		if F.state ~= "Fly" then
			F.state = "Fly"
		end
		if F.lv then
			F.lv.VectorVelocity = round3(F.vel)
		end
		F.kick = n * 3
		VFX.Play("DevFly", char, { Kind = "WallHit", Pos = hit.Position, Normal = n }, true)
		send("DevWall", { Pos = hit.Position, Normal = n, Bomb = blast or nil })
		if DevFly.CR then
			DevFly.CR.walled(hit) -- (round 88: a wall that won't break ends the carry's RAM)
		end
	end

	-- his body along where he's going: upright in the hover (leaning into
	-- the drift), lying along it at speed with the chest raised HeadUp,
	-- banked into turns; the braking flip pitches him back feet first
	-- (round 90, devfly2: the body follows his line tighter (the tiers'
	-- Align); the bank leans into the turn he asks for and into a strafe, not
	-- only the turn he's making; the barrel roll turns him round his line;
	-- the hover-lock turns him to where he aims)
	function DevFly.orient(dt, root)
		local cam = workspace.CurrentCamera
		local look = cam and cam.CFrame.LookVector or root.CFrame.LookVector
		local fl = flat(look)
		if fl.Magnitude <= 0.05 then
			fl = flat(F.dir) -- (round 90: never a NaN way - his body's look lies along the street in flight)
		end
		fl = fl.Magnitude > 0.05 and fl.Unit or Vector3.new(0, 0, -1)
		-- (round 90: his body lies along his heading's line - not swung round
		-- by a strafe or a roll's push across it; those bank and roll him)
		local v = F.vel
		if F.state == "Fly" and not F.lock then
			local push = DevFly.Ctl and DevFly.Ctl.rolling(os.clock()) or Vector3.zero
			local along = F.vel - push - (F.strafe or Vector3.zero)
			if along.Magnitude > 1 or F.vel.Magnitude <= 1 then
				v = along
			end
		end
		local speed = v.Magnitude
		local H = TIERS.Hover or {}
		-- the hover: facing where the camera looks, leaning a touch into the drift
		local drift = flat(F.hover)
		local lean = math.clamp(drift.Magnitude / math.max(H.Drift or 24, 1), 0, 1) * (H.Lean or 10)
		local hoverRot = CFrame.lookAt(Vector3.zero, fl)
		if drift.Magnitude > 1 then
			local axis = drift.Unit:Cross(Vector3.yAxis)
			hoverRot = CFrame.fromAxisAngle(axis.Magnitude > 0.01 and axis.Unit or Vector3.xAxis, -math.rad(lean)) * hoverRot
		end
		local goal = hoverRot
		local state = F.state
		if F.lock and state == "Fly" then
			-- (round 90) THE HOVER-LOCK: turned to where he aims, pitched with it
			local P = math.rad(((CT.Lock or {}).Pitch) or 55)
			local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -P, P)
			local aim = fl * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
			local rightV = aim:Cross(Vector3.yAxis).Unit -- (never straight up or down: Pitch < 90)
			goal = CFrame.fromMatrix(Vector3.zero, rightV, rightV:Cross(aim).Unit, -aim)
			F.bank = 0
		elseif state == "Crouch" or state == "Ascent" or state == "Land" or state == "Crash" then
			goal = CFrame.lookAt(Vector3.zero, flat(root.CFrame.LookVector).Magnitude > 0.05 and flat(root.CFrame.LookVector).Unit or fl)
			F.bank = 0
		elseif speed > 1 then
			local vd = v.Unit
			-- the bank from how fast the heading turns
			local fd = flat(vd)
			local yaw = 0
			if F.lastFlat and fd.Magnitude > 0.05 then
				local a, b = F.lastFlat, fd.Unit
				yaw = math.deg(math.asin(math.clamp(a:Cross(b).Y, -1, 1))) / math.max(dt, 1e-3)
			end
			F.lastFlat = fd.Magnitude > 0.05 and fd.Unit or F.lastFlat
			local T = TIERS[(speed > 980 and F.light and "Light") or (speed > 380 and "Hyper") or (speed > 150 and "Fast") or "Cruise"] or {}
			local maxBank = T.Bank or 35
			-- (round 90) into the turn he's asking for (BankIntent a radian of it)
			-- and the strafe (StrafeBank) as well as the one he's making
			local want = yaw * 0.45 + math.clamp(F.turnWant or 0, -1, 1) * (CT.BankIntent or 30) - (F.strafeK or 0) * (CT.StrafeBank or 28)
			F.bank += (math.clamp(want, -maxBank, maxBank) - F.bank) * (1 - math.exp(-(CT.BankK or 8) * dt))
			-- lying along it: the head down the path, the chest to the street
			-- (straight up or down: facing on along the camera's look)
			local downV = -Vector3.yAxis
			-- (both square to his line, so the frame stays square; the camera's
			-- way only breaks the tie straight up or down - on with it climbing,
			-- back against it diving, the way pitching over from level flight
			-- turns him, so a steep dive never flips him over)
			local front = downV - vd * downV:Dot(vd) + (fl - vd * fl:Dot(vd)) * (vd.Y >= 0 and 0.25 or -0.25)
			front = front.Magnitude > 0.01 and front.Unit or fl
			local headUp = math.rad(T.HeadUp or 0)
			local up2 = (vd * math.cos(headUp) - front * math.sin(headUp)).Unit
			local front2 = (front * math.cos(headUp) + vd * math.sin(headUp)).Unit
			-- banked: the chest swings to the outside of the turn
			local right = up2:Cross(-front2).Unit
			local b = math.rad(F.bank)
			local front3 = (front2 * math.cos(b) + right * math.sin(b)).Unit
			if state == "Brake" then
				-- (the flip: swung back feet first past upright - skidding on
				-- the air - then settling upright for the hover)
				local t = os.clock() - F.stateAt
				local BR = F.brakeLight and (DEV.Light or {}).Brake or DEV.Brake or {}
				local flip = t < 0.3 and 100 * math.sin(math.min(t / 0.3, 1) * math.pi / 2)
					or 100 - 10 * math.clamp((t - 0.3) / math.max((BR.Time or 0.45) - 0.3, 0.05), 0, 1)
				flip = math.rad(flip)
				local u0, f0 = up2, front3
				up2 = (u0 * math.cos(flip) - f0 * math.sin(flip)).Unit
				front3 = (f0 * math.cos(flip) + u0 * math.sin(flip)).Unit
			end
			local back = -front3
			local rx = up2:Cross(back)
			local flyRot = CFrame.fromMatrix(Vector3.zero, rx.Magnitude > 0.01 and rx.Unit or Vector3.xAxis, up2, back)
			local alpha = math.clamp((speed - 20) / 50, 0, 1)
			if state == "Brake" or state == "Dive" then
				alpha = 1
			end
			goal = hoverRot:Lerp(flyRot, alpha * alpha * (3 - 2 * alpha))
		end
		local T = TIERS[(speed > 980 and F.light and "Light") or (speed > 380 and "Hyper") or (speed > 150 and "Fast") or (speed > 30 and "Cruise") or "Hover"] or {}
		local k = (state == "Brake" or state == "Dive" or state == "Ascent") and 30 or (T.Align or 10)
		local nr = (F.rot or goal):Lerp(goal, 1 - math.exp(-k * dt))
		local x, y, z = nr:ToEulerAnglesXYZ()
		if x ~= x or y ~= y or z ~= z then
			nr = goal
		end
		F.rot = nr
		-- (round 90) the barrel roll: once round his line (the sidestep: a
		-- lean toward it) - on top, so his settled line isn't disturbed by it
		local shown = nr
		local spin = 0
		if DevFly.Ctl and F.spin then
			local _, a = DevFly.Ctl.rolling(os.clock())
			spin = a
		end
		if spin ~= 0 and spin == spin then
			local axis = (F.spin and not F.spin.hover and speed > 20) and v.Unit or nr.LookVector
			if axis.Magnitude > 0.5 and axis == axis then
				shown = CFrame.fromAxisAngle(axis.Unit, spin) * nr
			end
		end
		root.CFrame = CFrame.new(root.Position) * shown
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- each frame, whatever he's doing: his tier to his body (and the
	-- server), the HUD, his own screen's wind and specks
	function DevFly.frame(dt, root, char)
		local look = DevFly.look()
		if char:GetAttribute("DevFlyLocal") ~= look then
			char:SetAttribute("DevFlyLocal", look)
		end
		DevFly.relay(false)
		local speed = F.vel.Magnitude
		if VFX.DFX then
			VFX.DFX.frame(char, root, speed, look, dt)
		end
		local now = os.clock()
		-- the lines on the screen: streaming at FAST, focus at HYPERSONIC
		-- (round 90: and LIGHTSPEED's own, split into its colours)
		if F.light then
			HUD.FlightLines(1, "light")
		elseif speed > 380 then
			HUD.FlightLines(0.55 + 0.45 * math.clamp((speed - 380) / 140, 0, 1), "focus")
		else
			HUD.FlightLines(0.75 * math.clamp((speed - 150) / 150, 0, 1), "stream")
		end
		if now >= (F.next.meter or 0) then
			F.next.meter = now + 0.05
			local names = { Hover = "HOVER", Cruise = "CRUISE", Fast = "FAST", Hyper = "HYPERSONIC", Boost = "MACH BURST", Brake = "BRAKING", Dive = "DIVE SLAM",
				Crouch = "LAUNCH", Ascent = "LAUNCH", Land = "LANDING", Crash = "IMPACT", Held = "HIT", Light = "LIGHTSPEED" }
			-- (round 90) at HYPERSONIC, the way to LIGHTSPEED (the burst held:
			-- its key as this machine plays); never while he carries someone
			local hint = nil
			local LTh = DEV.Light or {}
			if LTh.Enabled ~= false and F.tier == "Hyper" and not F.light and not char:GetAttribute("DevCarrying") and now >= (F.lightCd or 0) then
				hint = inputMode == "Gamepad" and "HOLD Y" or (inputMode == "Touch" and "HOLD DASH" or "HOLD Q")
			end
			-- (round 86 review: the Mach number reads against the boom - MACH
			-- 1.00 is where it cracks, HYPERSONIC ~1.2, the burst's top ~2.3;
			-- SoundSpeed stays the late boom's speed for everyone else)
			HUD.FlightMeter({
				Tier = F.lock and "HOVER LOCK" or (names[look] or "HOVER"), Speed = speed, Mach = speed / (DEV.BoomAt or 420), Hot = F.boost ~= nil,
				Charge = F.barrier or 0, Light = F.light ~= nil, Hint = hint, -- (round 90)
			})
		end
		-- (round 90) LIGHTSPEED on his screen: the tunnel closing in round the
		-- edges as the barrier charges, the colours split at them once it's broken
		if HUD.FlightLight then
			local k = F.light and math.clamp((now - F.light.t0) / 0.3, 0.05, 1) or 0 -- (from its first frame: no blink between the charge and the light)
			HUD.FlightLight((k > 0 or (F.barrier or 0) > 0) and { K = k, Charge = F.barrier or 0 } or nil)
		end
		-- HYPERSONIC rattles the screen the whole time (round 90: LIGHTSPEED a faster buzz)
		local HY = TIERS.Hyper or {}
		if F.light and now >= (F.next.shake or 0) then
			F.next.shake = now + 0.12
			VFX.Shake((DEV.Light or {}).Shake or 0.35, 0.16)
		elseif speed > 380 and now >= (F.next.shake or 0) then
			F.next.shake = now + 0.2
			VFX.Shake((HY.Shake or 0.3) * math.clamp((speed - 380) / 140, 0.4, 1.4), 0.25)
		end
	end

	-- his tier to the server (everyone else draws him by it), at most Relay apart
	function DevFly.relay(force)
		local look = DevFly.look()
		if look == "Land" or look == "Crash" then
			return
		end
		local now = os.clock()
		if look ~= F.sent.tier and (force or now - (F.sent.at or 0) >= (DEV.Relay or 0.1)) then
			F.sent.tier, F.sent.at = look, now
			send("DevFly", { Tier = look })
		end
	end

	---------------------------------------------------------------------------
	-- the camera: trailing him on a spring - pulled back along its look by
	-- his speed, kicked on the launch and the burst, rolled into his turns,
	-- the field of view by speed - added after Roblox's camera every frame
	-- and taken off before its next one (it carries its own look on, so
	-- nothing builds up), and all of it given back when he stops
	---------------------------------------------------------------------------
	function DevFly.strip()
		local cam = workspace.CurrentCamera
		if F.applied and cam then
			cam.CFrame = cam.CFrame * F.applied:Inverse()
		end
		F.applied = nil
	end
	function DevFly.camera(dt)
		dt = math.min(tonumber(dt) or 1 / 60, 0.1)
		local cam = workspace.CurrentCamera
		local root = F.root
		if not DevFly.active or not cam or not root or VFX.InCinematic() or cam.CameraType ~= Enum.CameraType.Custom then
			return
		end
		local C = DEV.Camera or {}
		local speed = F.vel.Magnitude
		-- the lag: a critically damped spring on how far behind
		-- (round 90: none at all under LagFrom - the hover and CRUISE sit dead
		-- on him, on a stiffer spring; then by speed, more at LIGHTSPEED; none
		-- in the hover-lock)
		local from = C.LagFrom or 100
		local w = speed < from * 1.5 and (C.LagSpeedLow or 16) or (C.LagSpeed or 9)
		local most = F.light and ((DEV.Light or {}).Lag or 8) or (C.LagMax or 6)
		local target = F.lock and 0 or math.min((C.LagPerSpeed or 0.012) * math.max(speed - from, 0), most)
		F.lagV += (w * w * (target - F.lag) - 2 * w * F.lagV) * dt
		F.lag += F.lagV * dt
		-- (round 90) the swing: left behind across a strafe or a roll (he
		-- slides across the frame), then it catches him up
		local across = (F.strafe or Vector3.zero) + (DevFly.Ctl and DevFly.Ctl.rolling(os.clock()) or Vector3.zero)
		local sm = C.SwingMax or 1.6
		local swingTo = math.clamp(-cam.CFrame.RightVector:Dot(across) * (C.Swing or 0.022), -sm, sm)
		local sw = 7
		F.swingV = (F.swingV or 0) + (sw * sw * (swingTo - (F.swing or 0)) - 2 * sw * (F.swingV or 0)) * dt
		F.swing = (F.swing or 0) + F.swingV * dt
		-- the kick (launch, burst): left behind, catching up
		local kw = 6
		F.kickV += (-kw * kw * F.kick - 2 * kw * F.kickV) * dt
		F.kick += F.kickV * dt
		-- the roll into his turns
		local tierName = (F.light and speed > 980 and "Light") or (speed > 380 and "Hyper") or (speed > 150 and "Fast") or "Cruise"
		local maxRoll = (TIERS[tierName] or {}).Roll or 10
		local rollTarget = F.lock and 0 or math.clamp((C.RollPer or 0.35) * F.bank, -maxRoll, maxRoll)
		local rw = 6
		F.rollV += (rw * rw * (rollTarget - F.roll) - 2 * rw * F.rollV) * dt
		F.roll += F.rollV * dt
		local lift = speed > 150 and (C.Lift or 1) * math.clamp((speed - 150) / 100, 0, 1) or 0
		local kickLocal = cam.CFrame:VectorToObjectSpace(F.kick)
		local off = CFrame.new(kickLocal + Vector3.new(F.swing or 0, lift, F.lag)) * CFrame.Angles(0, 0, math.rad(F.roll))
		-- (round 86 review) Roblox's camera has already pulled itself out of
		-- the walls; the trail added after it could push it back into one
		-- (HYPERSONIC down a street of buildings, the launch's drop under the
		-- street): the move is cut short just before the first solid, seen
		-- thing it would cross
		local move = cam.CFrame:VectorToWorldSpace(off.Position)
		if move.Magnitude > 0.05 and F.params then
			local hit = workspace:Raycast(cam.CFrame.Position, move + move.Unit * 0.6, F.params)
			local part = hit and hit.Instance
			if part and not (part:IsA("BasePart") and part.Transparency > 0.25) then
				local k = math.clamp(((hit.Distance or (hit.Position - cam.CFrame.Position).Magnitude) - 0.6) / move.Magnitude, 0, 1)
				off = CFrame.new(off.Position * k) * off.Rotation
			end
		end
		cam.CFrame = cam.CFrame * off
		F.applied = off
		-- the field of view: by speed (the tiers' FOVs), punches on top
		local function fovAt(s)
			local pts = { { 0, (TIERS.Hover or {}).Fov or 70 }, { 90, (TIERS.Cruise or {}).Fov or 78 }, { 220, (TIERS.Fast or {}).Fov or 88 },
				{ 520, (TIERS.Hyper or {}).Fov or 100 }, { 980, (DEV.Boost or {}).Fov or 112 }, { 1400, (DEV.Light or {}).Fov or 116 } } -- (round 90: LIGHTSPEED)
			for i = 2, #pts do
				if s <= pts[i][1] then
					local a, b = pts[i - 1], pts[i]
					return a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1])
				end
			end
			return pts[#pts][2]
		end
		if os.clock() >= (F.fovHold or 0) then
			F.fovKick *= math.exp(-6 * dt)
		end
		-- (round 90: the hover-lock's view a touch tighter, for aim)
		local want = math.clamp((F.lock and ((CT.Lock or {}).Fov or 62) or fovAt(speed)) + F.fovKick, 40, 120)
		F.fov = F.fov or cam.FieldOfView
		F.fov += (want - F.fov) * (1 - math.exp(-(C.FovK or 6) * dt))
		cam.FieldOfView = F.fov
		if VFX.DFX then
			VFX.DFX.specks(cam, root, F.vel, dt)
		end
	end
	-- the camera given back: the offset off, the field of view eased home
	function DevFly.uncamera()
		DevFly.strip()
		pcall(function()
			RunService:UnbindFromRenderStep("QuirkDevFlyStrip")
		end)
		pcall(function()
			RunService:UnbindFromRenderStep("QuirkDevFlyCam")
		end)
		local function home()
			local cam = workspace.CurrentCamera
			if cam then
				local fov = (lastSprinting and MOVE.SprintFov or MOVE.NormalFov) or 70
				TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { FieldOfView = fov }):Play()
			end
		end
		F.fovToken = (F.fovToken or 0) + 1
		if not VFX.InCinematic() then
			home()
		else
			-- (round 86 review) stopped in a cutscene (a quirk change, a death
			-- mid-ult): the cutscene gives back the view it saved - which may
			-- be his HYPERSONIC one - so the view's eased home once it's over
			local token = F.fovToken
			task.spawn(function()
				local t0 = os.clock()
				while VFX.InCinematic() and os.clock() - t0 < 12 do
					task.wait(0.2)
				end
				if F.fovToken == token and not DevFly.active then
					task.wait(0.1)
					home()
				end
			end)
		end
		F.fov = nil
	end

	---------------------------------------------------------------------------
	-- switched off mid-air: he drops - and lands with the dust if the fall was a big one
	---------------------------------------------------------------------------
	RunService.Heartbeat:Connect(function()
		local dr = F.drop
		if not dr then
			return
		end
		local char, hum, root = getCharacter()
		if not char or DevFly.active or os.clock() > dr.untilAt then
			F.drop = nil
			return
		end
		dr.fall = math.max(dr.fall, -root.AssemblyLinearVelocity.Y)
		if hum.FloorMaterial ~= Enum.Material.Air and not char:GetAttribute("Ragdolled") then
			F.drop = nil
			if dr.fall > 55 then
				local g = root.Position - Vector3.new(0, standHeight(hum, root), 0)
				VFX.Play("DevFly", char, { Kind = "Land", Pos = g }, true)
				send("DevLand", { Kind = "Land", Pos = g, Speed = dr.fall })
			end
		end
	end)

	---------------------------------------------------------------------------
	-- the keys (devs only): V; the D-pad held down; the test menu's row
	---------------------------------------------------------------------------
	function DevFly.bind()
		if DevFly.bound or not DevFly.canFly() then -- (round 92: a dev, or a grant)
			return
		end
		DevFly.bound = true
		ContextActionService:BindAction("QuirkDevFly", function(_, state)
			if state == Enum.UserInputState.Begin then
				if DevFly.active and F.state == "Crouch" then
					return Enum.ContextActionResult.Sink
				end
				DevFly.toggle(true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				F.charging = false
			end
			return Enum.ContextActionResult.Sink
		end, false, DEV.Key or Enum.KeyCode.V)
		-- a controller: the D-pad held down PadHold s flies / stops (held on:
		-- the charge); a tap is still shift lock (passed on to it)
		ContextActionService:BindActionAtPriority("QuirkDevFlyPad", function(_, state)
			if state == Enum.UserInputState.Begin then
				local token = {}
				F.pad = token
				F.padAt = os.clock()
				task.delay(DEV.PadHold or 0.45, function()
					if F.pad == token then
						F.pad = "held"
						DevFly.toggle(true)
					end
				end)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				if F.pad == "held" then
					F.charging = false
				elseif F.pad then
					DevFly.shiftLockTap()
				end
				F.pad = nil
			end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.DPadDown)
	end
	function DevFly.unbind()
		if not DevFly.bound then
			return
		end
		DevFly.bound = false
		pcall(function()
			ContextActionService:UnbindAction("QuirkDevFly")
			ContextActionService:UnbindAction("QuirkDevFlyPad")
		end)
	end
	-- the D-pad tap passed on to the shift lock (it toggles off its own
	-- key press, which the hold above keeps from it)
	function DevFly.shiftLockTap()
		pcall(function()
			local pack = workspace:FindFirstChild("MovementSystem")
			local holder = pack and pack:FindFirstChild("StarterPlayerScripts")
			local lockScript = holder and holder:FindFirstChild("CustomShiftLock")
			local module = lockScript and lockScript:FindFirstChild("SmoothShiftLock")
			local ev = module and module:FindFirstChild("ToggleShiftLock")
			if module and ev then
				local lock = require(module)
				ev:Fire(not lock:IsEnabled())
			end
		end)
	end
	-- the phone: BLOCK at speed is the braking flip, held in the hover it sinks
	do
		local block = Touch.handlers.QuirkBlock
		if block then
			Touch.handlers.QuirkBlock = {
				down = function()
					if DevFly.active then
						if not DevFly.brake() then
							F.down = true
						end
						return
					end
					block.down()
				end,
				up = function()
					F.down = false
					block.up()
				end,
			}
		end
	end
	-- the switch went on / off on the server (V's own, the console, the menu)
	player:GetAttributeChangedSignal("DevFlight"):Connect(function()
		local on = player:GetAttribute("DevFlight") == true
		if on and not DevFly.active and DevFly.canFly() then -- (round 92: canFly)
			DevFly.start(true, false)
		elseif not on and DevFly.active and F.state ~= "Land" and F.state ~= "Crash" and os.clock() - (F.stateAt or 0) > 0.5 then
			DevFly.stop("Server")
		end
		if DevFly.menu then
			DevFly.menu()
		end
	end)
	player:GetAttributeChangedSignal("DevFlyer"):Connect(function()
		if DevFly.canFly() then -- (round 92: still granted, still flies; FlightGrant's own: DevFly.FG)
			DevFly.bind()
		else
			DevFly.unbind()
			DevFly.stop("Off")
		end
		if DevFly.menu then
			DevFly.menu()
		end
	end)
	player:GetAttributeChangedSignal("Quirk"):Connect(function()
		if DevFly.active then
			DevFly.stop("Off") -- (a new quirk: back to the ground)
		end
	end)
	player.CharacterAdded:Connect(function()
		if DevFly.active then
			DevFly.stop("Gone")
		end
		F.drop = nil
	end)
	DevFly.bind()
	-- the test menu: DEV FLIGHT - shown only to those who fly, its switch
	-- following the server's, and a card with the controls
	-- (round 86 review: "DEV FLIGHT" - the "?" narrows the label, and "[V]"
	-- shrank it to 9 px; the card names the keys)
	table.insert(TEST_ITEMS, 1, { Id = "DevFlight", Label = "DEV FLIGHT", Toggle = true, Group = "Dev only" })
	function DevFly.menu()
		HUD.ShowTestRow("DevFlight", DevFly.canFly()) -- (round 92: a tester with a grant sees it too)
		HUD.SetTestToggle("DevFlight", player:GetAttribute("DevFlight") == true)
		HUD.SetTestInfo("DevFlight", "DEV FLIGHT", {
			"<b>V</b>  fly / stop  -  held on the street: a charged take-off",
			"<b>W</b> / the stick: where you look  -  let go: hover",
			"<b>Space</b> / A up  -  <b>C</b> / LT down (sprint: faster)",
			"<b>Ctrl</b> / stick all the way / RT: FAST  -  hold 1 s: HYPERSONIC",
			"<b>Q</b> / Y (or Ctrl twice): MACH BURST",
			"<b>Hold Q</b> / Y at HYPERSONIC: <b>LIGHTSPEED</b>",
			"<b>A</b> / <b>D</b> at speed: strafe  -  twice quickly: barrel roll",
			"<b>T</b> / L3 / LOCK: hover-lock (at speed: stop and hold)",
			"<b>F</b> / X (or S) at speed: the braking flip",
			"<b>X</b> / RB: DIVE SLAM where you look",
			"Controller: hold the <b>D-pad down</b> to fly / stop",
			"FAST+ smashes through buildings  -  land fast: CRASH",
			"<b>LIGHTSPEED</b> into the ground: <b>THE WHOLE MAP GOES</b>", -- (round 92: DevFly.LW)
		})
	end
end

local function refreshTestToggles()
	HUD.SetTestToggle("GodMode", player:GetAttribute("GodMode") == true)
	HUD.SetTestToggle("NoCooldowns", player:GetAttribute("NoCooldowns") == true)
	HUD.SetTestToggle("Destruction", workspace:GetAttribute("DestructionEnabled") ~= false)
	HUD.SetTestToggle("DummiesBlock", workspace:GetAttribute("DummiesBlock") == true)
	if DevFly.menu then
		DevFly.menu() -- (round 86: DEV FLIGHT - only for those who fly)
	end
	if VFX.AEClient and VFX.AEClient.menu then
		VFX.AEClient.menu() -- (round 87: ADMIN EVENTS - the same devs)
	end
	if FreeCam.Director then
		FreeCam.Director.menu() -- (round 87: DIRECTOR CAM - the same people)
	end
	if DevFly.PS and DevFly.PS.menu then
		DevFly.PS.menu() -- (round 87: POSSESS - devs only too)
	end
end

local testMenuReady = false
local function setupTestMenu()
	if testMenuReady or not player:GetAttribute("Tester") then
		return
	end
	testMenuReady = true
	HUD.BuildTestMenu(TEST_ITEMS, function(id)
		-- the side panels (one open at a time)
		local panels = {
			DevAccessPanel = HUD.ToggleDevPanel, DummyPanel = HUD.ToggleDummyPanel,
			FunPanel = HUD.ToggleFunPanel, ServerPanel = HUD.ToggleServerPanel,
			RosterPanel = HUD.ToggleRosterPanel, -- (round 86)
			AdminEventsPanel = HUD.ToggleEventsPanel, -- (round 87)
			PossessPanel = HUD.TogglePossessPanel, -- (round 87)
			FlightGrantPanel = HUD.ToggleFlightGrantPanel, -- (round 92)
		}
		if panels[id] then
			if panels[id]() then
				for other, toggle in panels do
					if other ~= id then
						toggle(false)
					end
				end
			end
			return
		end
		if id == "DevFlight" then
			DevFly.toggle() -- (round 86: the flight itself checks you're one who flies)
			return
		end
		if id == "DirectorCam" then
			FreeCam.Director.toggle() -- (round 87: it checks the same)
			return
		end
		if id == "ResetCooldowns" or id == "NoCooldowns" then
			lastUsed = {}
			recoverUntil = 0
			HUD.ResetCooldowns()
		end
		TestCommand:FireServer(id)
	end)
	HUD.BuildDummyPanel(Config.DummyKinds or {}, function(kind)
		TestCommand:FireServer("SpawnDummy", kind)
	end, function()
		TestCommand:FireServer("ClearDummies")
	end)
	HUD.BuildFunPanel(FUN_ITEMS, function(id)
		TestCommand:FireServer(id)
	end)
	FreeCam.buildPanel()
	refreshTestToggles()
	player:GetAttributeChangedSignal("GodMode"):Connect(refreshTestToggles)
	player:GetAttributeChangedSignal("NoCooldowns"):Connect(refreshTestToggles)
	workspace:GetAttributeChangedSignal("DestructionEnabled"):Connect(refreshTestToggles)
	workspace:GetAttributeChangedSignal("DummiesBlock"):Connect(refreshTestToggles)
	UserInputService.InputBegan:Connect(function(input, processed)
		if FreeCam.directing then
			return -- (round 87: the director camera has the keys - P, Ctrl + P and N wait for it)
		end
		if not processed and input.KeyCode == Config.TestMenu.Key then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				FreeCam.toggle() -- (Ctrl + P, like a JJS private server)
			else
				HUD.ToggleTestMenu()
			end
		elseif not processed and input.KeyCode == Enum.KeyCode.N and not FreeCam.on then
			TestCommand:FireServer("PSPlayer", "Flight", player.UserId) -- N: flight on/off
		end
	end)
end
player:GetAttributeChangedSignal("Tester"):Connect(setupTestMenu)
setupTestMenu()

-- dev-only quirks show in the quirk menu for testers + players they granted
local function refreshDevAccess()
	HUD.SetDevAccess(player:GetAttribute("DevAccess") == true)
end
player:GetAttributeChangedSignal("DevAccess"):Connect(refreshDevAccess)
refreshDevAccess()

-- DEV ACCESS panel (testers only): everyone else in this server
local devPanelReady = false
local function refreshDevPanel()
	local rows = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local status = other:GetAttribute("Tester") and "tester" or other:GetAttribute("DevAccess") and "granted" or "none"
			table.insert(rows, { UserId = other.UserId, Name = other.DisplayName .. " (@" .. other.Name .. ")", Status = status })
		end
	end
	table.sort(rows, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	HUD.RefreshDevPanel(rows)
end
local function watchPlayer(other)
	other:GetAttributeChangedSignal("DevAccess"):Connect(refreshDevPanel)
	other:GetAttributeChangedSignal("Tester"):Connect(refreshDevPanel)
end
local function setupDevPanel()
	if devPanelReady or not player:GetAttribute("Tester") then
		return
	end
	devPanelReady = true
	HUD.BuildDevPanel(function(userId, on)
		TestCommand:FireServer("GrantDev", userId, on)
	end, function(on)
		TestCommand:FireServer("GrantDevAll", nil, on)
	end)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(function(other)
		watchPlayer(other)
		refreshDevPanel()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshDevPanel)
	end)
	refreshDevPanel()
end
player:GetAttributeChangedSignal("Tester"):Connect(setupDevPanel)
setupDevPanel()

---------------------------------------------------------------------------
-- (round 86) THE ROSTER SWITCH (Config.Roster; the server's Kit.Roster):
-- the phone follows the live roster (a hero released shows up at once, one
-- pulled back goes), a NEW HERO banner for whoever couldn't pick him before
-- (testers get a line), and the testers' HERO ROSTER panel
---------------------------------------------------------------------------
do
	local RS = { seen = nil, ready = false, waiting = {} }
	local function devAccessNow()
		return player:GetAttribute("DevAccess") == true
	end
	-- how to play him, the way you're playing (on a touch screen the banner's a button)
	local function hint()
		return inputMode == "Gamepad" and "SELECT TO PLAY" or inputMode == "Touch" and "TAP TO PLAY" or "PRESS M TO PLAY"
	end
	-- (review) a release waits AnnounceDelay before its banner: pulled again by
	-- then (a misclick on the panel), it's dropped; still news as it comes up?
	function RS.announce(name)
		local token = {}
		RS.waiting[name] = token
		task.delay(tonumber(Config.Roster.AnnounceDelay) or 1.5, function()
			if RS.waiting[name] ~= token then
				return
			end
			RS.waiting[name] = nil
			local function still()
				return not Config.IsDevOnly(name) and not devAccessNow() and player:GetAttribute("Quirk") ~= name
			end
			if still() then
				HUD.RosterBanner(name, hint(), function()
					VFX.PlaySound("RosterRelease")
				end, { Still = still, Tap = inputMode == "Touch" })
			end
		end)
	end
	function RS.changed()
		HUD.SetDevAccess(devAccessNow())
		HUD.RefreshRosterPanel()
		local sync = workspace:GetAttribute("RosterSync")
		if sync == nil or sync == "Loading" then
			RS.seen = nil -- (a server starting up, or its state not here yet: what comes first isn't news)
			return
		end
		local now = {}
		for name in Config.Quirks do
			now[name] = Config.IsDevOnly(name)
		end
		local before = RS.seen
		RS.seen = now
		local out, back, pulled = {}, {}, {}
		for _, name in before and Config.QuirkOrder or {} do -- (how it was when we got here isn't news either)
			if before[name] ~= nil and before[name] ~= now[name] then
				local shown = Config.Quirks[name].DisplayName or name
				if not now[name] then
					if devAccessNow() then
						table.insert(out, shown)
					elseif not Config.Quirks[name].DevOnly then
						table.insert(back, shown) -- (a public hero back after he was pulled: not new)
					elseif Config.Roster.Announce ~= false then
						RS.announce(name) -- (a DEV ONLY hero out for everyone: NEW HERO)
					else
						table.insert(out, shown) -- (no banners: a line)
					end
				else
					RS.waiting[name] = nil
					if devAccessNow() then
						table.insert(pulled, shown)
					elseif player:GetAttribute("Quirk") == name then
						VFX.PlaySound("RosterPulled") -- (the server tells them what happens to them)
					end
				end
			end
		end
		-- (one notice, however many a reset moves: notices stack in one spot)
		local lines, color = {}, nil
		local function say(list, what, c)
			if #list > 0 then
				local who = #list <= 2 and table.concat(list, " and ") or string.format("%s, %s and %d more", list[1], list[2], #list - 2)
				table.insert(lines, who .. (#list == 1 and " is " or " are ") .. what)
				color = color and Color3.new(1, 1, 1) or c
			end
		end
		say(out, "out for everyone now", Color3.fromRGB(130, 236, 160))
		say(back, "back for everyone", Color3.fromRGB(130, 236, 160))
		say(pulled, "DEV ONLY now", Color3.fromRGB(255, 176, 64))
		if #lines > 0 then
			HUD.Notice(table.concat(lines, "  ·  "), color)
		end
	end
	workspace:GetAttributeChangedSignal(Config.Roster.Attribute or "RosterOverrides"):Connect(RS.changed)
	workspace:GetAttributeChangedSignal("RosterSync"):Connect(RS.changed)
	for _, attr in { "RosterBy", "RosterAt" } do
		workspace:GetAttributeChangedSignal(attr):Connect(HUD.RefreshRosterPanel)
	end
	player:GetAttributeChangedSignal("RosterEditor"):Connect(HUD.RefreshRosterPanel)
	RS.changed()

	-- the panel (testers); the server checks every switch (Kit.Roster.canEdit)
	local function setup()
		if RS.ready or not player:GetAttribute("Tester") then
			return
		end
		RS.ready = true
		HUD.BuildRosterPanel({
			Set = function(name, state)
				VFX.PlaySound("RosterToggle")
				TestCommand:FireServer("Roster", name, state)
			end,
			Reset = function()
				VFX.PlaySound("RosterToggle")
				TestCommand:FireServer("RosterReset")
			end,
			Editor = function()
				return player:GetAttribute("RosterEditor") == true
			end,
		})
	end
	player:GetAttributeChangedSignal("Tester"):Connect(setup)
	setup()
end

---------------------------------------------------------------------------
-- LEMILLION's PERMEATE (R), the part only his own machine can do: it runs
-- his body's physics.
--  WallPhase (on the ground): each physics step the walls round him stop
--   being solid for him - never the floor (whatever he's standing on, or
--   anything that tops out at his feet). If it ends with him inside a wall,
--   the wall gets a moment to let him out, then spits him back out where he
--   was last clear.
--  PhaseDive (R in the air): his body goes into the PhaseDive collision
--   group (touches nothing) and drops at DiveSpeed through roofs, floors
--   and the street. Once the server has him under the street (Submerged) he
--   steers a marker round the surface with the movement keys (the camera
--   follows it); R, a click or jump - or ChooseTime - picks it, and the
--   ground spits him out there.
---------------------------------------------------------------------------
do
	local SPEC = (Config.Quirks.Lemillion and Config.Quirks.Lemillion.Special) or {}
	local UPV = Vector3.new(0, 1, 0)
	local Phase = { walls = {}, groups = {}, lastFree = nil, stuckSince = nil }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local function topOf(part)
		local cf, h = part.CFrame, part.Size / 2
		local top = -math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					top = math.max(top, (cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
				end
			end
		end
		return top
	end
	local function openWall(part)
		if not Phase.walls[part] then
			Phase.walls[part] = true
			part.CanCollide = false
		end
	end
	local function closeWalls(keep)
		for part in Phase.walls do
			if not (keep and keep[part]) then
				Phase.walls[part] = nil
				if part.Parent then
					part.CanCollide = true
				end
			end
		end
	end
	-- the walls his body is inside right now (of the ones let through)
	local function inside(root)
		local map = workspace:FindFirstChild("Map")
		if not map or not next(Phase.walls) then
			return {}
		end
		params.FilterDescendantsInstances = { map }
		local out = {}
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(root.Position), Vector3.new(2, 4.5, 1.2), params) do
			if Phase.walls[part] then
				out[part] = true
			end
		end
		return out
	end
	Phase.Stepped = RunService.Stepped:Connect(function()
		local char, hum, root = getCharacter()
		if not char or not hum or not root then
			closeWalls(nil)
			return
		end
		if char:GetAttribute("WallPhase") == true then
			Phase.stuckSince = nil
			local map = workspace:FindFirstChild("Map")
			if not map then
				return
			end
			params.FilterDescendantsInstances = { map }
			local feet = root.Position.Y - (hum.HipHeight + root.Size.Y / 2)
			-- (whatever's right under him is floor, whatever its shape)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { map }
			local under = workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + root.Size.Y / 2 + 2.5), 0), rp)
			local keep = {}
			for _, part in workspace:GetPartBoundsInBox(CFrame.new(root.Position + UPV), Vector3.new(12, 7, 12), params) do
				-- (NoPhase: the Sky Coffin's ground and its barrier - an electromagnetic
				-- wall, not matter he can slip through)
				if (part.CanCollide or Phase.walls[part]) and part ~= (under and under.Instance) and topOf(part) > feet + 1.6
					and not part:GetAttribute("NoPhase") then
					keep[part] = true
					openWall(part)
				end
			end
			closeWalls(keep)
			if not next(inside(root)) then
				Phase.lastFree = root.CFrame
			end
		elseif next(Phase.walls) then
			-- over, but he may still be in a wall: it lets him walk out for a
			-- moment, then spits him out where he was last clear
			local still = inside(root)
			if not next(still) then
				closeWalls(nil)
				Phase.stuckSince = nil
			else
				Phase.stuckSince = Phase.stuckSince or os.clock()
				closeWalls(still)
				if os.clock() - Phase.stuckSince > 1.2 then
					if Phase.lastFree then
						char:PivotTo(Phase.lastFree)
						root.AssemblyLinearVelocity = Vector3.zero
						VFX.Play("PermeateSpit", char, { Pos = Phase.lastFree.Position - UPV * 3, Dir = Phase.lastFree.LookVector, Wall = true }, true)
					end
					closeWalls(nil)
					Phase.stuckSince = nil
				end
			end
		end
	end)

	-- the dive
	local dive = nil -- { lv, att, marker, from, start, confirmed }
	local function restoreGroups()
		for part, group in Phase.groups do
			if part.Parent then
				part.CollisionGroup = group
			end
		end
		table.clear(Phase.groups)
	end
	local function surfaceAt(xz, y)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { VFX.Folder }
		for _, plr in Players:GetPlayers() do
			if plr.Character then
				table.insert(ignore, plr.Character)
			end
		end
		local dummies = workspace:FindFirstChild("Dummies")
		if dummies then
			table.insert(ignore, dummies)
		end
		rp.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(Vector3.new(xz.X, y, xz.Z), Vector3.new(0, -800, 0), rp)
		return hit and hit.Position or Vector3.new(xz.X, y - 250, xz.Z)
	end
	local function endDive()
		if not dive then
			return
		end
		local d = dive
		dive = nil
		for _, x in { d.lv, d.att, d.marker } do
			if x then
				x:Destroy()
			end
		end
		restoreGroups()
		local _, hum = getCharacter()
		local cam = workspace.CurrentCamera
		if cam and hum and (cam.CameraSubject == d.marker or cam.CameraSubject == nil) then
			cam.CameraSubject = hum
		end
	end
	local function confirm()
		if not dive or not dive.marker or dive.confirmed then
			return
		end
		dive.confirmed = true
		local at = dive.marker.CFrame.Position
		local v = Vector3.new(at.X - dive.from.X, 0, at.Z - dive.from.Z)
		UseAbility:FireServer(Config.RELEASE_INDEX, v.Magnitude > 0.5 and v.Unit or Vector3.new(0, 0, -1), at)
	end
	Phase.confirm = confirm
	local function startDive(char, root)
		endDive()
		dive = { start = os.clock() }
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") then
				Phase.groups[part] = part.CollisionGroup
				part.CollisionGroup = "PhaseDive"
			end
		end
		local att = Instance.new("Attachment")
		att.Name = "PhaseDiveAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "PhaseDive"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = math.huge
		lv.VectorVelocity = Vector3.new(0, -(SPEC.DiveSpeed or 110), 0)
		lv.Parent = root
		dive.lv, dive.att = lv, att
	end
	local function startChoosing(root)
		if not dive or dive.marker then
			return
		end
		if dive.lv then
			dive.lv:Destroy()
			dive.att:Destroy()
			dive.lv, dive.att = nil, nil
		end
		dive.from = root.Position
		dive.chooseStart = os.clock()
		dive.xz = Vector3.new(root.Position.X, 0, root.Position.Z)
		dive.topY = root.Position.Y + 300
		local m = Instance.new("Part")
		m.Name = "PermeateMarker"
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.CastShadow = false
		m.Shape = Enum.PartType.Cylinder
		m.Material = Enum.Material.Neon
		m.Color = Color3.fromRGB(255, 214, 60)
		m.Transparency = 0.25
		m.Size = Vector3.new(0.3, 7, 7)
		m.CFrame = CFrame.new(surfaceAt(dive.xz, dive.topY) + UPV * 0.2) * CFrame.Angles(0, 0, math.rad(90))
		m.Parent = VFX.Folder
		dive.marker = m
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraSubject = m
		end
		HUD.Notice("STEER WITH MOVE  ·  R / CLICK / JUMP: COME OUT", Color3.fromRGB(255, 214, 60))
	end
	RunService.RenderStepped:Connect(function(dt)
		local char, hum, root = getCharacter()
		local diving = char and char:GetAttribute("PhaseDive") == true
		if not diving then
			if dive then
				endDive()
			end
			return
		end
		if not dive then
			startDive(char, root)
		end
		if char:GetAttribute("Submerged") == true then
			startChoosing(root)
		elseif os.clock() - dive.start > 6 then
			endDive() -- (never left falling forever)
			return
		end
		if dive.marker and not dive.confirmed then
			-- steer it: the movement keys, the way the camera faces
			local move = hum and hum.MoveDirection or Vector3.zero
			local flat = Vector3.new(move.X, 0, move.Z)
			if flat.Magnitude > 0.05 then
				dive.xz += flat.Unit * math.min(flat.Magnitude, 1) * (SPEC.MarkerSpeed or 70) * dt
				local off = dive.xz - Vector3.new(dive.from.X, 0, dive.from.Z)
				local range = SPEC.DiveRange or 80
				if off.Magnitude > range then
					dive.xz = Vector3.new(dive.from.X, 0, dive.from.Z) + off.Unit * range
				end
			end
			local ground = surfaceAt(dive.xz, dive.topY)
			dive.marker.CFrame = CFrame.new(ground + UPV * 0.2) * CFrame.Angles(0, os.clock() * 2 % (math.pi * 2), math.rad(90))
			if os.clock() - dive.chooseStart > (SPEC.ChooseTime or 2.5) - 0.15 then
				confirm()
			end
		end
	end)
	-- R, a click or jump: come out here
	UserInputService.InputBegan:Connect(function(input)
		if not dive or not dive.marker then
			return
		end
		-- (by name: EnumItems from different places compare that way everywhere)
		local key = input.KeyCode and input.KeyCode.Name or ""
		local go = key == "Space" or key == "ButtonA" or key == "ButtonR2"
			or (input.UserInputType and input.UserInputType.Name == "MouseButton1")
		for _, k in Config.SpecialKeys or { Enum.KeyCode.R } do
			go = go or key == k.Name
		end
		if go then
			confirm()
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		if dive and dive.marker then
			confirm()
		end
	end)
	-- (tests can read it)
	VFX.Hooks.PermeateState = function()
		return dive, Phase.walls
	end
end

---------------------------------------------------------------------------
-- ULT MUSIC (Config.UltMusic): while someone's ult is up their theme plays -
-- yours at full volume, someone else's fading in as you get near them. One
-- track at a time (yours first, else the nearest), faded in and out; a new
-- theme waits for the old one to fade. MUSIC on the HUD mutes it.
---------------------------------------------------------------------------
do
	local MUSIC = Config.UltMusic or {}
	local musicOn = true
	-- (its own SoundGroup: music has its own volume, apart from the fight sounds)
	local SoundService = game:GetService("SoundService")
	local group = SoundService:FindFirstChild("QuirkMusic") or Instance.new("SoundGroup")
	group.Name = "QuirkMusic"
	group.Parent = SoundService
	local track = Instance.new("Sound")
	track.Name = "UltMusic"
	track.SoundId = (MUSIC.Default and MUSIC.Default.Id) or ""
	track.Looped = true
	track.Volume = 0
	track.SoundGroup = group
	track.Parent = group
	local playing, owner -- the theme playing, and whose ult it's for
	local level = 0
	HUD.BuildMusicToggle(function()
		musicOn = not musicOn
		HUD.SetMusic(musicOn)
		SettingsRemote:FireServer("Music", musicOn)
	end)
	-- (the SETTINGS panel's switch, and what's saved coming back)
	function VFX.Hooks.SetMusicOn(on)
		musicOn = on ~= false
		HUD.SetMusic(musicOn)
	end
	if player:GetAttribute("Music") == false then
		VFX.Hooks.SetMusicOn(false) -- (saved off, and loaded before this ran)
	end
	-- (tests / other scripts can read what's on)
	function VFX.Hooks.MusicState()
		return playing, owner, level
	end
	-- (round 78) a big hit ducks the music: down to `depth` of its volume
	-- over `attack` seconds, held `hold`, then back up over `release` (eased)
	-- - United States of Smash's impact frame drops it out from under the
	-- punch and lets it swell back with the twister
	local duck
	local function duckLevel()
		local dk = duck
		if not dk then
			return 1
		end
		local t = os.clock() - dk.t0
		if t < dk.attack then
			return 1 - (1 - dk.depth) * (t / dk.attack)
		end
		t -= dk.attack
		if t < dk.hold then
			return dk.depth
		end
		t -= dk.hold
		if t < dk.release then
			local a = t / dk.release
			return dk.depth + (1 - dk.depth) * a * a * (3 - 2 * a)
		end
		duck = nil
		return 1
	end
	function VFX.Hooks.DuckMusic(depth, attack, hold, release)
		local dk = {
			t0 = os.clock(), depth = math.clamp(tonumber(depth) or 0.2, 0, 1), attack = math.max(tonumber(attack) or 0.05, 0.01),
			hold = math.max(tonumber(hold) or 0.3, 0), release = math.max(tonumber(release) or 2, 0.05),
		}
		duck = dk
		task.spawn(function()
			while duck == dk do
				track.Volume = level * duckLevel()
				task.wait()
			end
		end)
	end
	function VFX.Hooks.MusicDuck()
		return duckLevel()
	end
	task.spawn(function()
		while true do
			local dt = task.wait(0.1) or 0.1
			local myChar = player.Character
			local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera
			local from = myRoot and myRoot.Position or (cam and cam.CFrame.Position)
			local full, hear = MUSIC.FullRange or 70, MUSIC.HearRange or 230
			local best, bestDist = nil, math.huge
			for _, plr in Players:GetPlayers() do
				local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if r and plr:GetAttribute("UltActive") then
					local d = plr == player and 0 or (from and (r.Position - from).Magnitude or math.huge)
					if d < bestDist and d <= hear then
						best, bestDist = plr, d
					end
				end
			end
			local spec = best and ((MUSIC.Tracks and MUSIC.Tracks[best:GetAttribute("Quirk") or ""]) or MUSIC.Default)
			local peak = (MUSIC.Volume or 0.5) * ((Config.Audio and Config.Audio.MusicVolume) or 1)
			-- a different theme (or someone else's ult): start it once the old one's faded
			if spec and (spec.Id ~= playing or best ~= owner) and level <= 0.01 then
				playing, owner = spec.Id, best
				track:Stop()
				track.SoundId = spec.Id
				track.TimePosition = spec.Start or 0
				track:Play()
				task.spawn(function()
					-- (still loading: skip to its drop once it can)
					pcall(function()
						if not track.IsLoaded then
							track.Loaded:Wait()
						end
						if playing == spec.Id and track.TimePosition < (spec.Start or 0) - 0.5 then
							track.TimePosition = spec.Start or 0
						end
					end)
				end)
			end
			local target = 0
			if spec and musicOn and spec.Id == playing and best == owner then
				target = peak * math.clamp(1 - (bestDist - full) / math.max(hear - full, 1), 0, 1)
			end
			local rate = peak / (target > level and (MUSIC.FadeIn or 1.2) or (MUSIC.FadeOut or 1.8)) * dt
			level = target > level and math.min(target, level + rate) or math.max(target, level - rate)
			track.Volume = level * duckLevel()
			if not spec and playing and level <= 0 then
				track:Stop()
				playing, owner = nil, nil
			end
		end
	end)
end

-- (round 60) SUNEATER'S ZIP: Tako Snatch zipped him to a building - that only
-- costs Zip.Cooldown seconds of the move's cooldown (the server does the same)
PlayVFX.OnClientEvent:Connect(function(effectId, char)
	if effectId ~= "TakoZip" or char ~= player.Character then
		return
	end
	local quirkName = player:GetAttribute("Quirk")
	local q = Config.Quirks[quirkName or ""]
	for i, a in (q and q.Abilities) or {} do
		if a.Zip then
			local key = Config.CooldownKey(quirkName, i, false, false)
			if lastUsed[key] then
				lastUsed[key] -= math.max((a.Cooldown or 8) - (a.Zip.Cooldown or 2.5), 0)
				if not player:GetAttribute("NoCooldowns") then
					HUD.StartCooldown(key, a.Zip.Cooldown or 2.5)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- (round 66) THE CONSOLE (F2): anyone can open it and watch the server's
-- log; the owner (the server decides who: Config.Console) types commands
-- into it. A few words it handles itself: clear (your view), freecam (the
-- free camera) and menu (the test menu).
---------------------------------------------------------------------------
do
	local CON = Config.Console or {}
	local ConsoleUI = { ready = false }
	task.spawn(function()
		local remote = Remotes:WaitForChild("Console", 30)
		if not remote or CON.Enabled == false or not HUD.BuildConsole then
			return
		end
		HUD.BuildConsole({
			OnRun = function(text)
				local word = string.lower(string.match(text, "^%s*(%S+)") or "")
				if word == "clear" then
					HUD.ConsoleClear()
					return
				elseif word == "freecam" and player:GetAttribute("ConsoleOwner") then
					FreeCam.toggle()
					return
				elseif word == "menu" and player:GetAttribute("Tester") then
					HUD.ToggleTestMenu()
					return
				end
				remote:FireServer("Run", text)
			end,
		})
		remote.OnClientEvent:Connect(function(kind, data)
			if kind == "Line" then
				HUD.ConsoleLine(data)
			elseif kind == "Sync" and type(data) == "table" then
				HUD.ConsoleReset(data.Log)
				HUD.SetConsoleCommands(data.Commands)
				HUD.SetConsoleOwner(data.Owner == true)
			end
		end)
		local function owner()
			HUD.SetConsoleOwner(player:GetAttribute("ConsoleOwner") == true)
		end
		player:GetAttributeChangedSignal("ConsoleOwner"):Connect(owner)
		owner()
		remote:FireServer("Sync")
		ConsoleUI.ready = true
	end)
	-- (F2 opens and shuts it even while you're typing in it)
	UserInputService.InputBegan:Connect(function(input)
		if ConsoleUI.ready and input.KeyCode == (CON.Key or Enum.KeyCode.F2) and not FreeCam.directing then -- (round 87: not under the director's frame)
			HUD.ToggleConsole()
		end
	end)
end

---------------------------------------------------------------------------
-- (round 89) JOIN THE DISCORD (Config.Discord; the server's kiosk in
-- workspace.Shops). Roblox decides who may see a Discord link: this screen
-- asks once, for its own player (PolicyService, pcall'd: no answer or a
-- failure is a no - asked again a couple of times). The kiosk is built in
-- the neutral words; only a screen that's allowed re-words its own copy -
-- the sign, the screen, the prompt (each label carries its role) - as the
-- kiosk streams in and whenever the answer changes. Its neon and light
-- breathe (local tweens). Its prompt opens the card (HUD.ShowDiscord): the
-- invite to select and copy, or the neutral line. Walk off: it closes.
---------------------------------------------------------------------------
do
	local CFG = Config.Discord or {}
	local DS = { state = "asking", allowed = false, tweens = {}, token = 0 }
	VFX.DiscordClient = DS -- (tests)

	-- a role's words on this screen (the Allowed ones only if Roblox says so)
	function DS.textFor(role)
		local words = DS.allowed and CFG.Allowed or nil
		local text = words and (role == "ScreenMain" and CFG.Invite or words[role])
		return text or (CFG.Neutral or {})[role] or ""
	end

	function DS.dress(inst)
		local role = inst:GetAttribute("DiscordRole")
		if not role then
			return
		end
		if inst:IsA("ProximityPrompt") then
			inst.ActionText = DS.textFor("Action")
			inst.ObjectText = DS.textFor("Object")
		elseif inst:IsA("TextLabel") then
			inst.Text = DS.textFor(role)
		end
	end

	-- the neon and the light breathe: one tween each while it's there (a
	-- part streamed out and back in is a new one)
	function DS.breathe(inst)
		if DS.tweens[inst] or not inst:GetAttribute("DiscordGlow") then
			return
		end
		local LOOK = CFG.Look or {}
		local goal
		if inst:IsA("BasePart") then
			local n = LOOK.Neon or { 0, 0.45 }
			inst.Transparency = n[1]
			goal = { Transparency = n[2] }
		elseif inst:IsA("PointLight") then
			local b = (LOOK.Light or {}).Brightness or { 2.2, 0.9 }
			inst.Brightness = b[1]
			goal = { Brightness = b[2] }
		end
		if not goal then
			return
		end
		local tw = TweenService:Create(inst, TweenInfo.new(CFG.Pulse or 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
		DS.tweens[inst] = tw
		tw:Play()
		local conn
		conn = inst.AncestryChanged:Connect(function()
			if not inst:IsDescendantOf(workspace) then
				conn:Disconnect()
				tw:Cancel()
				DS.tweens[inst] = nil
			end
		end)
	end

	function DS.look(inst)
		if inst:GetAttribute("DiscordRole") then
			DS.dress(inst)
		end
		if inst:GetAttribute("DiscordGlow") then
			DS.breathe(inst)
		end
	end

	function DS.dressAll()
		local shops = workspace:FindFirstChild("Shops")
		for _, k in shops and shops:GetChildren() or {} do
			if k.Name == "DiscordKiosk" then
				for _, d in k:GetDescendants() do
					DS.dress(d)
				end
			end
		end
	end

	-- the shops (the kiosk streams in and out of them)
	function DS.watch(shops)
		if DS.watching == shops then
			return
		end
		DS.watching = shops
		shops.DescendantAdded:Connect(function(d)
			DS.look(d)
		end)
		for _, d in shops:GetDescendants() do
			DS.look(d)
		end
	end

	-- Roblox's answer for this player (it yields): Discord in its list or not
	function DS.ask()
		local ok, info = pcall(function()
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
		end)
		local list = ok and type(info) == "table" and info.AllowedExternalLinkReferences
		if type(list) == "table" then
			DS.allowed = table.find(list, "Discord") ~= nil
			DS.state = "done"
		else
			DS.allowed = false
			DS.state = "failed"
		end
		DS.dressAll()
		return DS.allowed
	end

	-- the card, from the kiosk's prompt (the server's DiscordCard: Pos = the
	-- kiosk's feet). A moment for Roblox's answer if it hasn't come yet.
	function DS.open(data)
		DS.token += 1
		local token = DS.token
		local t0 = os.clock()
		while DS.state == "asking" and os.clock() - t0 < (CFG.AskWait or 3) do
			task.wait(0.1)
		end
		if token ~= DS.token then
			return
		end
		closePanels()
		DS.mode = inputMode
		HUD.ShowDiscord({
			Allowed = DS.allowed,
			Invite = DS.allowed and CFG.Invite or nil,
			Words = (DS.allowed and CFG.Allowed or CFG.Neutral) or {},
			Mode = inputMode,
			Color = (CFG.Look or {}).Blurple,
		})
		VFX.PlaySound("DiscordCard")
		if inputMode == "Gamepad" then
			selectGui(HUD.DiscordFirstButton())
		end
		local at = type(data) == "table" and typeof(data.Pos) == "Vector3" and data.Pos or nil
		while token == DS.token and HUD.DiscordVisible() do
			local _, _, root = getCharacter()
			if at and (not root or (root.Position - at).Magnitude > (CFG.CloseRange or 22)) then
				HUD.HideDiscord()
				break
			end
			if inputMode ~= DS.mode then
				DS.mode = inputMode
				HUD.SetDiscordMode(inputMode)
			end
			task.wait(0.2)
		end
	end

	if CFG.Enabled ~= false then
		UI_EVENTS.DiscordCard = function(data)
			task.spawn(DS.open, data)
		end
		local shops = workspace:FindFirstChild("Shops")
		if shops then
			DS.watch(shops)
		end
		workspace.ChildAdded:Connect(function(child)
			if child.Name == "Shops" then
				DS.watch(child)
			end
		end)
		task.spawn(function()
			DS.ask()
			local R = CFG.Retry or {}
			for _ = 1, R.Times or 0 do
				if DS.state ~= "failed" then
					break
				end
				task.wait(R.Every or 10)
				DS.ask()
			end
		end)
	end
end
