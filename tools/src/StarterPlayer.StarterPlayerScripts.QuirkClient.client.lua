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
local lockTarget = nil -- lock-on (T / L3): the model the camera follows
-- parkour (set up below): Busy while a vault / climb / wall hop has the body;
-- Running = sprinting; Latched = double-tapped W; WallNear = a wall hop is on
local Parkour = { Busy = false, Running = false, Latched = false, WallNear = nil }
local scoped = false -- looking down the sniper scope

-- a move you're holding down (set up below)
local Hold = { active = nil }
local BlastFly = { active = false } -- (round 73) Bakugo's explosion flight (filled in by the dash key)
local FloatFly = { active = false } -- (round 75) Deku's Float (filled in below)
local WhipDash = { dashAt = 0 } -- (round 75) dash, then Blackwhip: the slingshot (filled in below)
-- the testers' free camera and flight (set up with the test menu)
local FreeCam = { on = false }
local dashing = false
local activeDashCleanup
local CombatInput = { untilAt = 0, pending = nil, buffer = 0.14 }

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
	-- locked on: every move goes at them
	local lockRoot = lockTarget and not scoped and lockTarget:FindFirstChild("HumanoidRootPart")
	if lockRoot then
		local v = lockRoot.Position - root.Position
		return v.Magnitude > 1 and v.Unit or root.CFrame.LookVector, lockRoot.Position
	end
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
local function erased(char)
	if (char:GetAttribute("ErasedUntil") or 0) > workspace:GetServerTimeNow() then
		HUD.Callout("QUIRK ERASED", Color3.fromRGB(255, 60, 60))
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
	if ability.AimAssist and not lockTarget then
		dir, pos = assistAim(root, dir, pos, ability.AimAssist, ability.Range or 60)
	end
	-- seed + origin: everyone (and the server's destruction) builds the same shapes
	local seed = math.random(1, 2 ^ 30)
	local origin = root.Position
	-- (your side of the air variants: off the ground when you pressed it)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local air = hum ~= nil and hum.FloorMaterial == Enum.Material.Air
	CombatInput.pending = nil
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
-- you let go). DOWNSLAM: TAP jump during the chain - you hop the moment you
-- let go - and throw the 4th anywhere off the ground.
local slamJump = { downAt = nil, swung = false, holdUp = false, hopped = false, hopAt = 0 }
local function jumpHeld(hum)
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or (hum and hum.Jump) then
		return true
	end
	local ok, down = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	end)
	return ok and down == true
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
	if slamJump.hopped and os.clock() - slamJump.hopAt < 0.6 then
		return "Down"
	end
	if jumpHeld(hum) then
		return "Up"
	end
	return nil
end

local function useM1(bufferPress)
	if BlastFly.active and BlastFly.stop then
		BlastFly.stop("Action") -- (round 73: an M1 drops him out of his flight)
	end
	if FloatFly.active and FloatFly.pause then
		FloatFly.pause(0.3) -- (round 75)
	end
	local char, hum, root = getCharacter()
	if scoped and char then
		fireSniper()
		return
	end
	if busy(char) or player:GetAttribute("NoMelee") then
		return
	end
	local now = os.clock()
	local remaining = math.max(actionRemaining(char), m1Next - now)
	if remaining > 0 or dashing then
		if bufferPress ~= false then
			bufferInput(char, remaining, function() useM1(false) end)
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
	if now - m1Last > Config.M1.ComboReset then
		m1Count = 0
	end
	m1Count = m1Count % Config.M1.ComboLength + 1
	m1Last = now
	local finisher = m1Count == Config.M1.ComboLength
	m1Next = now + (finisher and Config.M1.FinisherCooldown or Config.M1.Cooldown)
	predictAction(finisher and (Config.M1.FinisherActionTime or 0.4) or (Config.M1.ActionTime or 0.18))
	CombatInput.m1Until = CombatInput.untilAt -- (round 65: a side / back dash may cut into it)
	-- (round 63) a swing with jump held: it's the upslam you're holding it
	-- for, not a hop
	if hum and jumpHeld(hum) then
		slamJump.swung = true
	end
	local variant = finisher and hum and root and m1Variant(hum, root) or nil
	if variant == "Up" then
		slamJump.holdUp = true -- (and you stay down till you let go)
	end
	-- M1 tracking (like JJS): the swing turns to the nearest opponent close
	-- in front of you (Config.M1.Assist)
	local assist = Config.M1.Assist
	if assist and root and not lockTarget then
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
-- feet); TAPPED it's a hop for the downslam, the moment you let go. Still
-- held when the chain runs out (ComboReset): an ordinary jump.
do
	local suppressedOn -- the Humanoid we switched jumping off on
	RunService:BindToRenderStep("QuirkM1Jump", Enum.RenderPriority.Input.Value + 1, function()
		local _, hum = getCharacter()
		local held = hum ~= nil and jumpHeld(hum)
		local now = os.clock()
		local len = Config.M1.ComboLength
		local chain = m1Count >= 1 and m1Count < len and now - m1Last < Config.M1.ComboReset
		local grounded = hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
		local hop = false
		if not held then
			-- a tap in the chain: up you go as you let go
			hop = slamJump.downAt ~= nil and not slamJump.swung and not slamJump.hopped and chain and grounded
			slamJump.downAt, slamJump.swung, slamJump.holdUp, slamJump.hopped = nil, false, false, false
		elseif not slamJump.downAt then
			slamJump.downAt = now
		end
		-- (round 75) held in the chain: no waiting for the let-go - up you go
		-- as soon as the swing's lock lets you (HopDelay after the press),
		-- unless an M1 goes out with it held (that's the upslam)
		if held and slamJump.downAt and not slamJump.swung and not slamJump.hopped and not slamJump.holdUp and chain and grounded
			and now - slamJump.downAt >= ((Config.M1.Downslam or {}).HopDelay or 0.07) then
			local c = player.Character
			if c and actionRemaining(c) <= 0 and not CombatInput.pending then
				hop = true
			end
		end
		local suppress = hum ~= nil and held and grounded and not hop and not slamJump.hopped and (slamJump.holdUp or chain)
		if suppress and suppressedOn ~= hum then
			suppressedOn = hum
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		elseif not suppress and suppressedOn then
			if suppressedOn.Parent then
				suppressedOn:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
			suppressedOn = nil
		end
		if hop and hum and hum.Health > 0 and not busy(player.Character) then
			slamJump.hopped = true
			slamJump.hopAt = now
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
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
		or char:GetAttribute("Submerged") or Parkour.Busy or Hold.active or FreeCam.on or dashing or actionRemaining(char) > 0 then
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
		or char:GetAttribute("BeingFinished") or char:GetAttribute("Submerged") or FreeCam.on then
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
			if lockTarget and lockTarget:FindFirstChild("HumanoidRootPart") then
				look = flat(lockTarget.HumanoidRootPart.Position - root.Position) -- (locked on: round them)
			end
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
			or VFX.InOwnCinematic() or FreeCam.on
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
			if up then
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
		if not FloatFly.active and FloatFly.armed() then
			local _, hum = getCharacter()
			if hum and hum.FloorMaterial ~= Enum.Material.Air then
				task.defer(FloatFly.lift) -- (off the ground first: the jump's own push)
			end
		end
	end)
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
	elseif sprinting ~= lastSprinting and cam and not scoped then
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
				hum.AutoRotate = true -- (shift lock / lock-on take it back each frame if they're on)
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
		if PK.Enabled == false or player:GetAttribute("NoParkour") then
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
			or char:GetAttribute("BeingFinished") or char:GetAttribute("Kaiju") or hum.Sit then
			return
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
		local occupied = Parkour.Busy or dashing or hum.PlatformStand or root.Anchored
			or char:GetAttribute("Ragdolled") or char:GetAttribute("Stunned") or char:GetAttribute("Submerged")
			or char:GetAttribute("Frozen") or char:GetAttribute("Finishing") or char:GetAttribute("BeingFinished")
			or char:GetAttribute("Holding")
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
end

local function closePanels()
	HUD.ToggleShop(false)
	HUD.ShowMenu(false)
	HUD.HideVendor()
	HUD.ToggleSettings(false)
	HUD.ToggleBoard(false)
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
			or player:GetAttribute("NoSkills") or player:GetAttribute("Flight") == true
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
	end)
end
bindButton("QuirkDash", "DASH", Config.DashKeys, function()
	if FloatFly.active then
		FloatFly.boost() -- (round 75: floating - an Air Force flick behind him)
		return
	end
	dash()
	BlastFly.press()
end, nil, function()
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
local m1Held = false
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
-- Lock-on (T / L3): the camera keeps the target in view and you face them
---------------------------------------------------------------------------
local LOCK = Config.LockOn or {}
local lockMarker = Instance.new("BillboardGui")
lockMarker.Name = "LockOnMarker"
lockMarker.Size = UDim2.fromOffset(46, 46)
lockMarker.AlwaysOnTop = true
lockMarker.Enabled = false
local lockRing = Instance.new("Frame")
lockRing.AnchorPoint = Vector2.new(0.5, 0.5)
lockRing.Position = UDim2.fromScale(0.5, 0.5)
lockRing.Size = UDim2.fromScale(0.7, 0.7)
lockRing.Rotation = 45
lockRing.BackgroundTransparency = 1
lockRing.Parent = lockMarker
local lockStroke = Instance.new("UIStroke")
lockStroke.Color = Color3.fromRGB(255, 70, 60)
lockStroke.Thickness = 3
lockStroke.Parent = lockRing
lockMarker.Parent = player:WaitForChild("PlayerGui")

local function setLock(target)
	lockTarget = target
	local r = target and target:FindFirstChild("HumanoidRootPart")
	if r then
		lockMarker.Adornee = r
	end
	lockMarker.Enabled = r ~= nil
	local _, hum = getCharacter()
	if hum and not target then
		hum.AutoRotate = true
	end
end

local function findLockTarget(root)
	local cam = workspace.CurrentCamera
	local look = flat(cam.CFrame.LookVector)
	look = look.Magnitude > 0.05 and look.Unit or flat(root.CFrame.LookVector).Unit
	local best, bestScore = nil, math.huge
	for _, model in fightTargets() do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local r = model:FindFirstChild("HumanoidRootPart")
		if hum and r and hum.Health > 0 then
			local offset = flat(r.Position - root.Position)
			local dist = offset.Magnitude
			local angle = dist > 0.5 and math.deg(math.acos(math.clamp(offset.Unit:Dot(look), -1, 1))) or 0
			if dist <= (LOCK.Range or 90) and angle <= (LOCK.Angle or 75) then
				local score = dist * (1 + angle / 30)
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

bindButton("QuirkLockOn", "LOCK", Config.LockOnKeys or { Enum.KeyCode.ButtonL3 }, function()
	local char, _, root = getCharacter()
	if lockTarget or not char or (char:GetAttribute("JammedUntil") or 0) > workspace:GetServerTimeNow() then
		-- (jammed by Radio Waves: no lock-on until it clears)
		setLock(nil)
	else
		setLock(findLockTarget(root))
	end
end)

RunService:BindToRenderStep("QuirkLockOn", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not lockTarget then
		return
	end
	local char, hum, root = getCharacter()
	local tHum = lockTarget:FindFirstChildOfClass("Humanoid")
	local tr = lockTarget:FindFirstChild("HumanoidRootPart")
	if not char or not tr or not tHum or tHum.Health <= 0 or not lockTarget.Parent
		or (tr.Position - root.Position).Magnitude > (LOCK.BreakRange or 140) then
		setLock(nil)
		return
	end
	if scoped or VFX.InCinematic() then
		return
	end
	local cam = workspace.CurrentCamera
	local focus = root.Position + Vector3.new(0, 2, 0)
	local toTarget = flat(tr.Position - focus)
	if toTarget.Magnitude < 1 then
		return
	end
	local dir = toTarget.Unit
	local dist = math.clamp((cam.CFrame.Position - focus).Magnitude, 8, 40)
	local camPos = focus - dir * dist + Vector3.new(0, dist * 0.32, 0)
	local lookAt = focus:Lerp(tr.Position, 0.55)
	cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, lookAt), math.min(1, dt * ((Config.Look or {}).LockOnFollow or 12)))
	-- face them (unless a dash, parkour, a stun or a move has the body)
	if not dashing and not Parkour.Busy and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled")
		and not char:GetAttribute("BodyLocked") then
		hum.AutoRotate = false
		root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + dir), math.min(1, dt * 24))
	end
end)

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
	-- lock-on (that camera turns itself), a menu or the emote wheel the stick
	-- is driving, or a scope)
	local function ours()
		local cam = workspace.CurrentCamera
		return PAD.Enabled ~= false and LK.mode ~= "roblox" and inputMode == "Gamepad" and cam ~= nil
			and player:GetAttribute("RobloxCamera") ~= true -- (round 68: the settings' ROBLOX CAMERA)
			and cam.CameraType == Enum.CameraType.Custom and not VFX.InCinematic() and not FreeCam.on
			and not lockTarget and not scoped and not uiOpen() and not HUD.EmoteWheelVisible()
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
	if not char or not id or char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") or VFX.InOwnCinematic() then
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
	local open = HUD.ToggleShop()
	if open and lockTarget then
		setLock(nil)
	end
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
		setLock(nil)
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
	if processed then
		return
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
	m1Count, m1Last, m1Next = 0, 0, 0
	guardHeld, m1Held = false, false
	VFX.CancelCinematic()
	setScoped(false)
	setLock(nil)
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
	if effectId == "Jammed" then
		setLock(nil) -- (Radio Waves: the lock-on's jammed too)
	end
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
	for _, list in { Config.AbilityKeys[1], Config.AbilityKeys[2], Config.AbilityKeys[3], Config.SpecialKeys, Config.UltKeys, Config.ExtraKeys, Config.FinisherKeys, Config.BlockKeys, Config.LockOnKeys } do
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
		and not char:GetAttribute("Grabbed") and not root.Anchored
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

local function refreshTestToggles()
	HUD.SetTestToggle("GodMode", player:GetAttribute("GodMode") == true)
	HUD.SetTestToggle("NoCooldowns", player:GetAttribute("NoCooldowns") == true)
	HUD.SetTestToggle("Destruction", workspace:GetAttribute("DestructionEnabled") ~= false)
	HUD.SetTestToggle("DummiesBlock", workspace:GetAttribute("DummiesBlock") == true)
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
		if ConsoleUI.ready and input.KeyCode == (CON.Key or Enum.KeyCode.F2) then
			HUD.ToggleConsole()
		end
	end)
end
