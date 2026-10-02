-- HUD (ModuleScript) — ReplicatedStorage.Shared.HUD
-- The fight HUD (JJS-style: dark glass panels with thin light edges, clean
-- type, one accent colour per character): health / guard / evasive / ult
-- stacked over the skill boxes at the bottom, the character card
-- bottom-right. Plus comic-panel cut-ins, the quirk select menu and the
-- full-screen dim/flash overlays.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HUD = {}

local Config
local callbacks = {}
local gui, overlayGui, flashGui
local healthFill, healthText, healthChip
local vitals -- the health / ult / guard stack above the move bar
local badge, badgeName, badgeMode, badgeGradient
local specialSlot, dashSlot, extraSlot
local ultBar, ultFill, ultText, ultGlow
local ultReady = false
local modeTimer, modeTimerFill, modeTimerText
local timerEnds, timerLength, timerLabel, timerColor
local slots = {}
local cooldowns = {}
local menu, menuGrid
local devAccess = false
local activeCutIn
local healthConn
local hintLabel, changeLabel
-- key names shown on the HUD (swapped for controller buttons by HUD.SetInputMode)
local keyText = { Guard = "F", Ult = "G", Dash = "Q" }

local COMIC_FONT = Enum.Font.Bangers
local UI_FONT = Enum.Font.GothamBold
local HEAD_FONT = Enum.Font.GothamBlack
-- the glass every fight panel is made of
local GLASS = { Color = Color3.fromRGB(12, 12, 17), T = 0.22, Edge = 0.8 }
local accent = Color3.fromRGB(255, 200, 60) -- (the current character's colour)
local ultName = "ULT"
local regenLabel, healthShine
local autoScales = {} -- UIScales that follow the screen size

local rng = Random.new()

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function stroke(thickness, color)
	return make("UIStroke", {
		Thickness = thickness or 2,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textStroke(thickness)
	return make("UIStroke", { Thickness = thickness or 2, Color = Color3.new(0, 0, 0) })
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 6) })
end

local function gradient(c0, c1, rotation)
	return make("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rotation or 90 })
end

-- a thin light edge (the glass panels' outline)
local function edge(transparency)
	return make("UIStroke", {
		Thickness = 1,
		Color = Color3.new(1, 1, 1),
		Transparency = transparency or GLASS.Edge,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- a group of HUD bits that grows with the screen (1 at 720p) - scaled about
-- its anchor, so a bottom-centre dock stays bottom-centre
local function autoScale(frame)
	local sc = make("UIScale", { Name = "AutoScale", Parent = frame })
	for i = #autoScales, 1, -1 do
		local ok, parent = pcall(function()
			return autoScales[i].Parent
		end)
		if not (ok and parent) then
			table.remove(autoScales, i) -- (a rebuilt wheel or menu's old one)
		end
	end
	table.insert(autoScales, sc)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize
	if vp and vp.Y > 0 then
		sc.Scale = math.clamp(vp.Y / 720, 0.75, 1.5)
	end
	return sc
end

---------------------------------------------------------------------------

function HUD.Init(player, config, cbs)
	Config = config
	callbacks = cbs or {}
	local playerGui = player:WaitForChild("PlayerGui")

	overlayGui = make("ScreenGui", {
		Name = "QuirkOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 0,
		Parent = playerGui,
	})
	make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = overlayGui,
	})

	gui = make("ScreenGui", {
		Name = "QuirkHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	flashGui = make("ScreenGui", {
		Name = "QuirkFlash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = playerGui,
	})
	make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = flashGui,
	})

	-- The dock (bottom-centre): health, guard / evasive and the ult over the
	-- skill boxes - where your eyes already are in a fight
	local dock = make("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(560, 230),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	autoScale(dock)
	vitals = make("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(548, 68),
		BackgroundTransparency = 1,
		Parent = dock,
	})
	-- name row: who you are, and your health in numbers
	HUD.NameLabel = make("TextLabel", {
		Name = "Who",
		Size = UDim2.new(1, -140, 0, 16),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextSize = 15,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = vitals,
	}, { textStroke(1) })
	healthText = make("TextLabel", {
		Name = "HP",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(120, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "100 / 100",
		Parent = vitals,
	}, { textStroke(1) })
	-- (healing out of a fight: a green tag by the numbers)
	regenLabel = make("TextLabel", {
		Name = "Regen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 1),
		Size = UDim2.fromOffset(90, 14),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(120, 255, 150),
		Text = "+ RECOVERING",
		Visible = false,
		Parent = vitals,
	}, { textStroke(1) })
	local healthBar = make("Frame", {
		Name = "Health",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		ClipsDescendants = true,
		Parent = vitals,
	}, { edge(0.7), corner(2) })
	healthChip = make("Frame", {
		Name = "Chip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 244, 236),
		BorderSizePixel = 0,
		Parent = healthBar,
	}, { corner(2) })
	healthFill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 222, 96),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = healthBar,
	}, { corner(2), gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175), 90) })
	-- (the shine that sweeps along it while you heal)
	healthShine = make("Frame", {
		Name = "Shine",
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.fromScale(0.25, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
		Parent = healthBar,
	}, { make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}) })

	-- Ult meter (the bottom of the stack, just over the skill boxes)
	ultBar = make("Frame", {
		Name = "UltMeter",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Parent = vitals,
	}, { corner(2) })
	ultFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 50),
		BorderSizePixel = 0,
		Parent = ultBar,
	}, { corner(2), gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190), 90) })
	ultText = make("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "ULT 0%",
		ZIndex = 2,
		Parent = ultBar,
	}, { textStroke(1) })
	-- (its outline: faint, or throbbing in your colour when the ult is ready)
	ultGlow = make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ultBar })

	-- (round 63) the old character card (bottom-right) is gone: the CHARACTER
	-- button up top (the phone) picks your hero. (Still built, hidden: the
	-- labels are kept current for anything that reads them.)
	badge = make("TextButton", {
		Name = "QuirkBadge",
		Visible = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -26),
		Size = UDim2.fromOffset(200, 70),
		AutoButtonColor = true,
		Text = "",
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Parent = gui,
	}, { edge(), corner(3) })
	autoScale(badge)
	local strip = make("Frame", {
		Name = "Strip",
		Size = UDim2.new(0, 5, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = badge,
	}, { corner(2) })
	badgeGradient = gradient(Color3.fromRGB(90, 90, 90), Color3.fromRGB(40, 40, 40), 90)
	badgeGradient.Parent = strip
	badgeMode = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 13),
		Position = UDim2.fromOffset(16, 9),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "",
		ZIndex = 2,
		Parent = badge,
	})
	badgeName = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(16, 23),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "NO QUIRK",
		ZIndex = 2,
		Parent = badge,
	}, { make("UITextSizeConstraint", { MaxTextSize = 20 }) })
	changeLabel = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 12),
		Position = UDim2.fromOffset(16, 50),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.45,
		Text = "[M] CHANGE",
		ZIndex = 2,
		Parent = badge,
	})
	badge.MouseButton1Click:Connect(function()
		HUD.ToggleMenu()
	end)

	-- Skill boxes (bottom-centre)
	local bar = make("Frame", {
		Name = "Abilities",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(560, 70),
		BackgroundTransparency = 1,
		Parent = dock,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function makeSlot(order, keyText, width)
		local slot = make("Frame", {
			Name = "Slot" .. keyText,
			Size = UDim2.fromOffset(width, 70),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			ClipsDescendants = true,
			LayoutOrder = order,
			Parent = bar,
		}, { edge(), corner(3) })
		local key = make("TextLabel", {
			Size = UDim2.fromOffset(40, 16),
			Position = UDim2.fromOffset(6, 5),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.35,
			Text = keyText,
			ZIndex = 3,
			Parent = slot,
		})
		local name = make("TextLabel", {
			Size = UDim2.new(1, -10, 0, 38),
			Position = UDim2.new(0, 5, 1, -44),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "—",
			ZIndex = 2,
			Parent = slot,
		}, { make("UITextSizeConstraint", { MaxTextSize = 13 }) })
		-- (the character's colour along the top)
		local strip = make("Frame", {
			Name = "Accent",
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = slot,
		})
		local cover = make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = slot,
		})
		local cdText = make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 5,
			Parent = slot,
		}, { textStroke(1) })
		return { Frame = slot, Key = key, Name = name, Cover = cover, Text = cdText, Accent = strip, BoundKey = nil }
	end
	for i = 1, 3 do
		slots[i] = makeSlot(i, tostring(i), 92)
	end
	specialSlot = makeSlot(4, "R", 80)
	specialSlot.Frame.Visible = false
	slots[4] = specialSlot
	dashSlot = makeSlot(0, "Q", 60)
	dashSlot.Name.Text = "DASH"
	dashSlot.Accent.BackgroundColor3 = Color3.fromRGB(210, 214, 225)
	-- two dash timers: the front dash's (the long one) sweeps the slot; the
	-- side/back step's short one drains along a strip at its foot
	dashSlot.BoundKey = "DashFront"
	dashSlot.SubKey = "DashMobility"
	dashSlot.Sub = make("Frame", {
		Name = "MobilityCooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(210, 214, 225),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = dashSlot.Frame,
	})
	slots[5] = dashSlot
	-- (the 4th move sits with the other three; R comes after it)
	specialSlot.Frame.LayoutOrder = 5
	extraSlot = makeSlot(4, "4", 92)
	extraSlot.Frame.Visible = false
	slots[6] = extraSlot

	-- Form time limit (All Might's muscle form): a slim bar over the stack
	modeTimer = make("Frame", {
		Name = "ModeTimer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -178),
		Size = UDim2.fromOffset(260, 12),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Visible = false,
		Parent = dock,
	}, { edge(0.7), corner(2) })
	modeTimerFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 212, 64),
		BorderSizePixel = 0,
		Parent = modeTimer,
	}, { corner(2) })
	modeTimerText = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 2,
		Parent = modeTimer,
	}, { textStroke(1) })

	hintLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.fromOffset(760, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.4,
		Text = "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · T Lock-on · B Emotes · H Shop · M Quirk",
		Parent = gui,
	}, { make("UIStroke", { Thickness = 1, Transparency = 0.6 }) })

	-- the scales follow the screen (a phone to a 4K monitor)
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local vp = cam.ViewportSize
			if HUD.Touch and HUD.Touch.on then
				HUD.Touch.place() -- (a phone turned round, a tablet split-screened)
			elseif vp.Y > 0 then
				for _, sc in autoScales do
					sc.Scale = math.clamp(vp.Y / 720, 0.75, 1.5)
				end
			end
		end)
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if ultReady then
			-- (ready: the outline throbs in your colour so you can't miss it)
			local k = (math.sin(now * 7) + 1) / 2
			ultGlow.Color = accent:Lerp(Color3.new(1, 1, 1), k)
			ultGlow.Transparency = 0
			ultGlow.Thickness = 1.5 + 1.5 * k
		end
		if healthShine.Visible then
			healthShine.Position = UDim2.fromScale((now * 0.6) % 1.6 - 0.3, 0)
		end
		for key, cd in cooldowns do
			if now >= cd.Ends then
				cooldowns[key] = nil
				for _, slot in slots do
					if slot.BoundKey == key and slot.Frame.Visible then
						-- (ready again: the edge flashes in your colour)
						local s = slot.Frame:FindFirstChildOfClass("UIStroke")
						if s then
							s.Color = accent
							s.Transparency = 0
							tween(s, 0.4, { Color = Color3.new(1, 1, 1), Transparency = GLASS.Edge })
						end
					end
				end
			end
		end
		if timerEnds then
			local remaining = math.max(timerEnds - workspace:GetServerTimeNow(), 0)
			modeTimerFill.Size = UDim2.fromScale(math.clamp(remaining / timerLength, 0, 1), 1)
			modeTimerText.Text = string.format("%s  %ds", timerLabel, math.ceil(remaining))
			-- blink red for the last 5 seconds
			local blink = remaining < 5 and (now * 4) % 1 < 0.5
			modeTimerFill.BackgroundColor3 = blink and Color3.fromRGB(235, 60, 60) or timerColor
		end
		for _, slot in slots do
			local cd = slot.BoundKey and cooldowns[slot.BoundKey]
			if cd then
				local remaining = cd.Ends - now
				slot.Cover.Size = UDim2.fromScale(1, math.clamp(remaining / cd.Length, 0, 1))
				slot.Text.Text = string.format("%.1f", remaining)
			else
				slot.Cover.Size = UDim2.fromScale(1, 0)
				slot.Text.Text = ""
			end
			if slot.Round and slot.Round.Visible then
				HUD.TouchFill(slot, slot.Cover.Size.Y.Scale)
			end
			if slot.Sub then
				local sub = cooldowns[slot.SubKey]
				slot.Sub.Size = UDim2.new(sub and math.clamp((sub.Ends - now) / sub.Length, 0, 1) or 0, 0, 0, 4)
			end
		end
	end)

	HUD.BuildMenu()
	HUD.BuildTopBar(playerGui)
	HUD.InitFight(player)
end

---------------------------------------------------------------------------

function HUD.BindHumanoid(hum)
	if healthConn then
		healthConn:Disconnect()
	end
	local chipToken = 0
	local function update()
		local ratio = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
		tween(healthFill, 0.12, { Size = UDim2.fromScale(ratio, 1) })
		-- green while you're fine, amber under half, red when it's nearly over
		local green, amber, red = Color3.fromRGB(84, 214, 112), Color3.fromRGB(240, 180, 60), Color3.fromRGB(230, 60, 60)
		healthFill.BackgroundColor3 = ratio > 0.5 and green or ratio > 0.25 and red:Lerp(amber, (ratio - 0.25) * 4) or red
		healthText.Text = string.format("%d / %d", math.ceil(hum.Health), hum.MaxHealth)
		-- the chip: what you just lost stays white a moment, then drains
		chipToken += 1
		local token = chipToken
		if healthChip.Size.X.Scale <= ratio then
			healthChip.Size = UDim2.fromScale(ratio, 1)
		else
			task.delay(0.45, function()
				if token == chipToken then
					tween(healthChip, 0.35, { Size = UDim2.fromScale(ratio, 1) })
				end
			end)
		end
	end
	healthConn = hum.HealthChanged:Connect(update)
	update()
end

-- what Crazy Diamond's BUILD makes right now (the client keeps it current)
HUD.Blueprint = nil

-- alt = second side/form, ult = G ultimate active, pick = which of the
-- quirk's 4th moves is picked. resetCooldowns on quirk change only.
function HUD.SetQuirk(quirkName, alt, resetCooldowns, ult, pick)
	if HUD.MarkHero then
		HUD.MarkHero(quirkName) -- (the top bar's button, the phone)
	end
	local view = Config.GetView(quirkName, alt, ult, pick)
	local quirk = quirkName and Config.Quirks[quirkName]
	ultName = quirk and quirk.Ult and quirk.Ult.Name or "ULT"
	if view then
		accent = view.Color:Lerp(Color3.new(1, 1, 1), 0.15)
		badgeName.Text = view.DisplayName
		badgeMode.Text = view.ModeName or ""
		badgeMode.TextColor3 = view.AccentColor or accent
		badgeGradient.Color = ColorSequence.new(view.AccentColor, view.Color)
		if HUD.NameLabel then
			local a = view.AccentColor or accent
			HUD.NameLabel.Text = string.format('%s  <font size="11" color="#%02X%02X%02X">%s</font>', view.DisplayName,
				math.floor(a.R * 255), math.floor(a.G * 255), math.floor(a.B * 255), view.ModeName or "")
		end
		ultFill.BackgroundColor3 = accent
		for i = 1, 3 do
			local slot = slots[i]
			local ability = view.Abilities[i]
			slot.Name.Text = ability and ability.Name or "—"
			if ability and ability.Blueprint then
				-- (Crazy Diamond's BUILD says what it'll make: V changes it)
				local quirk = Config.Quirks[quirkName]
				local first = quirk and quirk.Blueprints and quirk.Blueprints[1] or "Wall"
				slot.Name.Text = ability.Name .. ": " .. string.upper(HUD.Blueprint or first)
			end
			slot.BoundKey = Config.CooldownKey(quirkName, i, alt, ult)
			slot.Frame.BackgroundColor3 = GLASS.Color:Lerp(view.Color, view.IsUlt and 0.3 or 0.12)
			slot.Accent.BackgroundColor3 = accent
		end
		if view.Special then
			specialSlot.Frame.Visible = true
			specialSlot.BoundKey = Config.CooldownKey(quirkName, Config.SPECIAL_INDEX, alt, ult)
			specialSlot.Name.Text = view.OtherModeName or view.Special.Name
			if view.Special.Cycle and view.NextExtra then
				specialSlot.Name.Text = "NEXT: " .. view.NextExtra.Name -- (Deku: what R puts in the 4th slot)
			end
			-- tint with the colour of the side you'd switch TO (an ult's own R:
			-- the ult's)
			local other = (ult and quirk and quirk.Ult and quirk.Ult.Special) and view or Config.GetView(quirkName, not alt)
			specialSlot.Frame.BackgroundColor3 = GLASS.Color:Lerp(other.Color, 0.12)
			specialSlot.Accent.BackgroundColor3 = other.Color:Lerp(Color3.new(1, 1, 1), 0.15)
		else
			specialSlot.Frame.Visible = false
			specialSlot.BoundKey = nil
		end
		if view.Extra then
			extraSlot.Frame.Visible = true
			extraSlot.BoundKey = Config.CooldownKey(quirkName, Config.EXTRA_INDEX, alt, ult, pick)
			extraSlot.Name.Text = view.Extra.Name
			extraSlot.Frame.BackgroundColor3 = GLASS.Color:Lerp(view.Color, view.IsUlt and 0.3 or 0.12)
			extraSlot.Accent.BackgroundColor3 = accent
		else
			extraSlot.Frame.Visible = false
			extraSlot.BoundKey = nil
		end
	else
		badgeName.Text = "NO QUIRK"
		badgeMode.Text = ""
		if HUD.NameLabel then
			HUD.NameLabel.Text = ""
		end
		badgeGradient.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90), Color3.fromRGB(40, 40, 40))
		for i = 1, 4 do
			slots[i].Name.Text = "—"
			slots[i].BoundKey = nil
		end
		specialSlot.Frame.Visible = false
		extraSlot.Frame.Visible = false
		extraSlot.BoundKey = nil
	end
	if resetCooldowns then
		HUD.ResetCooldowns()
	end
end

-- A row of pips over the health bar (nil hides it): Mr. Compress's marbles,
-- Chargebolt's pointers. spec = { Label, Count, Max, Color, Hint }
function HUD.SetPips(spec)
	local pp = HUD.Pips
	if not pp then
		if spec == nil or not vitals then
			return
		end
		pp = { Dots = {} }
		HUD.Pips = pp
		pp.Bar = make("Frame", {
			Name = "Pips",
			Position = UDim2.fromOffset(0, -18),
			Size = UDim2.fromOffset(270, 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = vitals,
		}, { edge(0.7), corner(2) })
		pp.Text = make("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 2,
			Parent = pp.Bar,
		}, { textStroke(1.5) })
	end
	pp.Bar.Visible = spec ~= nil
	if spec == nil then
		return
	end
	local max, count = spec.Max or 3, spec.Count or 0
	for i = 1, max do
		local dot = pp.Dots[i]
		if not dot then
			dot = make("Frame", {
				Name = "Pip" .. i,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6 - (i - 1) * 16, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = pp.Bar,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.3 }) })
			pp.Dots[i] = dot
		end
		dot.Visible = true
		dot.BackgroundColor3 = spec.Color or Color3.new(1, 1, 1)
		dot.BackgroundTransparency = i <= count and 0 or 0.8
	end
	for i = max + 1, #pp.Dots do
		pp.Dots[i].Visible = false
	end
	pp.Text.Text = (count == 0 and spec.Hint) and string.format("%s  -  %s", spec.Label or "", spec.Hint) or string.format("%s %d/%d", spec.Label or "", count, max)
	pp.Text.TextColor3 = count == 0 and Color3.fromRGB(255, 150, 130) or Color3.new(1, 1, 1)
end

-- SUNEATER's stomach (nil hides it): a bar over the health bar - what his
-- manifestations run on (low: they're weaker - eat something, R)
function HUD.SetStomach(value)
	local st = HUD.Stomach
	if not st then
		if value == nil or not vitals then
			return
		end
		st = {}
		HUD.Stomach = st
		st.Bar = make("Frame", {
			Name = "Stomach",
			Position = UDim2.fromOffset(0, -18),
			Size = UDim2.fromOffset(270, 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = vitals,
		}, { edge(0.7), corner(2) })
		st.Fill = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(236, 170, 90),
			BorderSizePixel = 0,
			Parent = st.Bar,
		}, { corner(2), gradient(Color3.fromRGB(255, 226, 160), Color3.fromRGB(210, 120, 60)) })
		st.Text = make("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "STOMACH",
			ZIndex = 2,
			Parent = st.Bar,
		}, { textStroke(1.5) })
	end
	st.Bar.Visible = value ~= nil
	if value == nil then
		return
	end
	value = math.clamp(value, 0, 100)
	tween(st.Fill, 0.2, { Size = UDim2.fromScale(value / 100, 1) })
	st.Text.Text = value < 25 and string.format("STOMACH %d%%  -  HUNGRY: R TO EAT", math.floor(value))
		or string.format("STOMACH %d%%", math.floor(value))
	st.Text.TextColor3 = value < 25 and Color3.fromRGB(255, 150, 130) or Color3.new(1, 1, 1)
end

-- ENDEAVOR's heat (nil hides it): a bar over the health bar, filling as he
-- uses fire - red-hot near the top; OVERHEATED at it
function HUD.SetHeat(value, overheated)
	local ht = HUD.Heat
	if not ht then
		if value == nil or not vitals then
			return
		end
		ht = {}
		HUD.Heat = ht
		ht.Bar = make("Frame", {
			Name = "Heat",
			Position = UDim2.fromOffset(0, -18),
			Size = UDim2.fromOffset(270, 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = vitals,
		}, { edge(0.7), corner(2) })
		ht.Fill = make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.fromRGB(255, 140, 40),
			BorderSizePixel = 0,
			Parent = ht.Bar,
		}, { corner(2), gradient(Color3.fromRGB(255, 214, 96), Color3.fromRGB(226, 60, 20)) })
		ht.Text = make("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "HEAT",
			ZIndex = 2,
			Parent = ht.Bar,
		}, { textStroke(1.5) })
	end
	ht.Bar.Visible = value ~= nil
	if value == nil then
		return
	end
	value = math.clamp(value, 0, 100)
	tween(ht.Fill, 0.15, { Size = UDim2.fromScale(value / 100, 1) })
	ht.Fill.BackgroundColor3 = overheated and Color3.fromRGB(255, 60, 40) or Color3.fromRGB(255, 140, 40)
	ht.Text.Text = overheated and "OVERHEATED  -  YOUR FIRE WON'T COME" or (value >= 75 and string.format("HEAT %d%%  -  RUNNING HOT", math.floor(value)) or string.format("HEAT %d%%", math.floor(value)))
	ht.Text.TextColor3 = (overheated or value >= 75) and Color3.fromRGB(255, 170, 130) or Color3.new(1, 1, 1)
end

-- (round 73) BAKUGO's sweat (nil hides it): a bar over the health bar - what
-- his explosion flight runs on (hold the dash key); it fills back up on the
-- ground
function HUD.SetSweat(value, flying)
	local sw = HUD.Sweat
	if not sw then
		if value == nil or not vitals then
			return
		end
		sw = {}
		HUD.Sweat = sw
		sw.Bar = make("Frame", {
			Name = "Sweat",
			Position = UDim2.fromOffset(0, -18),
			Size = UDim2.fromOffset(270, 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = vitals,
		}, { edge(0.7), corner(2) })
		sw.Fill = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 176, 60),
			BorderSizePixel = 0,
			Parent = sw.Bar,
		}, { corner(2), gradient(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 120, 30)) })
		sw.Text = make("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "SWEAT",
			ZIndex = 2,
			Parent = sw.Bar,
		}, { textStroke(1.5) })
	end
	sw.Bar.Visible = value ~= nil
	if value == nil then
		return
	end
	value = math.clamp(value, 0, 100)
	sw.Fill.Size = UDim2.fromScale(value / 100, 1)
	sw.Text.Text = flying and string.format("SWEAT %d%%  -  FLYING", math.floor(value))
		or value < 18 and string.format("SWEAT %d%%  -  DRIED UP: LAND TO GET IT BACK", math.floor(value))
		or string.format("SWEAT %d%%  -  HOLD DASH: FLY", math.floor(value))
	sw.Text.TextColor3 = value < 18 and Color3.fromRGB(255, 150, 130) or Color3.new(1, 1, 1)
end

-- the ragdoll cancel's meter: filling while you fight; while you're down
-- with it full it flashes the key to press
function HUD.SetEvasive(value, ragdolled)
	local ev = HUD.Evasive
	if not ev or not ev.Bar then
		return
	end
	value = math.clamp(value or 0, 0, 100)
	local ready = value >= 100
	tween(ev.Fill, 0.2, { Size = UDim2.fromScale(value / 100, 1) })
	ev.Fill.BackgroundColor3 = ready and Color3.fromRGB(150, 235, 255) or Color3.fromRGB(80, 118, 150)
	if ready and ragdolled then
		ev.Text.Text = "ESCAPE: PRESS " .. (keyText.Dash or "Q")
		ev.Stroke.Color = Color3.fromRGB(150, 235, 255)
		ev.Stroke.Transparency = 0
		ev.Stroke.Thickness = 2
	else
		ev.Text.Text = ready and "EVASIVE READY" or string.format("EVASIVE %d%%", math.floor(value))
		ev.Stroke.Color = Color3.new(1, 1, 1)
		ev.Stroke.Transparency = 0.7
		ev.Stroke.Thickness = 1
	end
end

function HUD.SetUltMeter(value, active)
	value = math.clamp(value or 0, 0, 100)
	tween(ultFill, 0.2, { Size = UDim2.fromScale(active and 1 or value / 100, 1) })
	local ready = value >= 100 and not active
	if active then
		ultText.Text = ultName .. "  ·  ACTIVE"
	elseif ready then
		ultText.Text = ultName .. "  ·  READY  [" .. keyText.Ult .. "]"
	else
		ultText.Text = string.format("%s  ·  %d%%", ultName, math.floor(value))
	end
	if ready ~= ultReady then
		ultReady = ready
		if HUD.SetTouchUlt then
			HUD.SetTouchUlt(ready)
		end
		if not ready then
			ultGlow.Thickness = 1
			ultGlow.Color = Color3.new(1, 1, 1)
			ultGlow.Transparency = 0.7
		end
	end
end

-- Full-screen ult banner: the shout across a band of speed lines
function HUD.UltBanner(view, shout)
	local band = make("Frame", {
		Name = "UltBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1.6, 0, 0.42, 0),
		Size = UDim2.new(1.3, 0, 0, 150),
		Rotation = -5,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 40,
		Parent = gui,
	}, { stroke(5), gradient(view.AccentColor, view.Color, 0) })
	for _ = 1, 26 do
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1.05, 0, rng:NextNumber(0, 1), 0),
			Size = UDim2.new(rng:NextNumber(0.2, 0.5), 0, 0, rng:NextInteger(2, 6)),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = rng:NextNumber(0.1, 0.5),
			BorderSizePixel = 0,
			ZIndex = 41,
			Parent = band,
		})
		TweenService:Create(line, TweenInfo.new(rng:NextNumber(0.2, 0.4), Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, rng:NextNumber(0, 0.2)), {
			Position = UDim2.new(-0.6, 0, line.Position.Y.Scale, 0),
		}):Play()
	end
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.7, 0, 0.62, 0),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = shout or view.ModeName,
		ZIndex = 43,
		Parent = band,
	}, { textStroke(4) })
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.new(0.6, 0, 0.18, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "ULTIMATE: " .. (view.ModeName or ""),
		ZIndex = 43,
		Parent = band,
	}, { textStroke(2) })
	tween(band, 0.22, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	task.delay(1.5, function()
		tween(band, 0.2, { Position = UDim2.new(-0.7, 0, 0.42, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.22)
		band:Destroy()
	end)
end

-- ends is in server time (workspace:GetServerTimeNow()); pass nil to hide
function HUD.SetModeTimer(ends, length, color, label)
	if not ends or not length or length <= 0 then
		timerEnds = nil
		modeTimer.Visible = false
		return
	end
	timerEnds, timerLength = ends, length
	timerLabel = label or ""
	timerColor = color or Color3.fromRGB(255, 212, 64)
	modeTimer.Visible = true
end

function HUD.StartCooldown(key, length)
	cooldowns[key] = { Ends = os.clock() + length, Length = length }
end

function HUD.ResetCooldowns()
	table.clear(cooldowns)
end

function HUD.Flash(color, time)
	local f = flashGui.Flash
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.05
	tween(f, time or 0.3, { BackgroundTransparency = 1 })
end

-- Blinded (a Stun Grenade you didn't guard): pure white, held, then it
-- only slowly clears - with the world a blur until it does
local blindToken = 0
function HUD.Blind(duration)
	duration = duration or 2.6
	blindToken += 1
	local token = blindToken
	local f = flashGui.Flash
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0
	local blur = game:GetService("Lighting"):FindFirstChild("QuirkBlind") or Instance.new("BlurEffect")
	blur.Name = "QuirkBlind"
	blur.Size = 28
	blur.Parent = game:GetService("Lighting")
	task.delay(duration * 0.4, function()
		if token ~= blindToken then
			return
		end
		tween(f, duration * 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(blur, duration * 0.6, { Size = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration * 0.6 + 0.05, function()
			if token == blindToken then
				blur:Destroy()
			end
		end)
	end)
end

-- Jammed (Radio Waves): TV static all over the screen and SIGNAL JAMMED,
-- flickering, for `duration` seconds
local jamToken = 0
function HUD.Jam(duration)
	duration = duration or 2.5
	jamToken += 1
	local token = jamToken
	local old = flashGui:FindFirstChild("Jam")
	if old then
		old:Destroy()
	end
	local frame = make("Frame", {
		Name = "Jam",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 16, 28),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = flashGui,
	})
	local COLS, ROWS = 16, 9
	local cells = {}
	for x = 0, COLS - 1 do
		for y = 0, ROWS - 1 do
			table.insert(cells, make("Frame", {
				Position = UDim2.fromScale(x / COLS, y / ROWS),
				Size = UDim2.fromScale(1 / COLS, 1 / ROWS),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.8,
				ZIndex = 6,
				Parent = frame,
			}))
		end
	end
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(460, 60),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 48,
		TextColor3 = Color3.fromRGB(200, 150, 255),
		Text = "SIGNAL JAMMED",
		ZIndex = 7,
		Parent = frame,
	}, { textStroke(3) })
	task.spawn(function()
		local t0 = os.clock()
		while token == jamToken and frame.Parent and os.clock() - t0 < duration do
			local fade = math.clamp((os.clock() - t0) / duration, 0, 1) ^ 3
			for _, c in cells do
				local v = rng:NextNumber()
				c.BackgroundColor3 = Color3.new(v, v, v * 1.1):Lerp(Color3.fromRGB(120, 60, 200), rng:NextNumber() < 0.1 and 0.6 or 0)
				c.BackgroundTransparency = 0.55 + 0.4 * rng:NextNumber() + 0.4 * fade
			end
			frame.BackgroundTransparency = 0.55 + 0.45 * fade
			label.Position = UDim2.new(0.5, rng:NextInteger(-6, 6), 0.42, rng:NextInteger(-4, 4))
			label.TextTransparency = fade
			task.wait(0.05)
		end
		if token == jamToken then
			frame:Destroy()
		end
	end)
end

function HUD.Dim(amount, time)
	local d = overlayGui.Dim
	tween(d, 0.08, { BackgroundTransparency = 1 - (amount or 0.5) })
	task.delay(time or 0.4, function()
		tween(d, 0.25, { BackgroundTransparency = 1 })
	end)
end

---------------------------------------------------------------------------
-- Comic-panel cut-in
---------------------------------------------------------------------------

local CORNERS = {
	TopLeft = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 12, 0, 70), fromX = -1 },
	TopRight = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -12, 0, 90), fromX = 1 },
	BottomLeft = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 12, 1, -110), fromX = -1 },
	BottomRight = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -160, 1, -110), fromX = 1 },
}

function HUD.CutIn(quirk, moveName)
	if activeCutIn then
		activeCutIn:Destroy()
	end
	local spot = CORNERS[quirk.CutInCorner] or CORNERS.TopLeft
	local width, height = 340, 190
	local shown = spot.pos
	local hidden = spot.pos + UDim2.fromOffset(spot.fromX * (width + 40), 0)

	local panel = make("Frame", {
		Name = "CutIn",
		AnchorPoint = spot.anchor,
		Position = hidden,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 20,
		Parent = gui,
	}, {
		stroke(4),
		gradient(quirk.AccentColor, quirk.Color, 25),
		make("UISizeConstraint", { MaxSize = Vector2.new(width, height) }),
	})
	activeCutIn = panel

	if quirk.CutInImage and quirk.CutInImage ~= "" then
		make("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = quirk.CutInImage,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 21,
			Parent = panel,
		})
	end

	-- speed lines
	for _ = 1, 16 do
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1.1, 0, rng:NextNumber(0, 1), 0),
			Size = UDim2.new(rng:NextNumber(0.25, 0.7), 0, 0, rng:NextInteger(2, 5)),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = rng:NextNumber(0.1, 0.5),
			BorderSizePixel = 0,
			ZIndex = 22,
			Parent = panel,
		})
		local tw = TweenService:Create(
			line,
			TweenInfo.new(rng:NextNumber(0.18, 0.35), Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, rng:NextNumber(0, 0.2)),
			{ Position = UDim2.new(-0.8, 0, line.Position.Y.Scale, 0) }
		)
		tw:Play()
	end

	-- diagonal ink slash
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(1.4, 0, 0, 34),
		Rotation = -8,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 23,
		Parent = panel,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.new(0.94, 0, 0.36, 0),
		Rotation = -8,
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = moveName,
		ZIndex = 24,
		Parent = panel,
	}, { textStroke(3) })
	make("TextLabel", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.6, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = quirk.DisplayName,
		ZIndex = 24,
		Parent = panel,
	}, { textStroke(2) })

	tween(panel, 0.2, { Position = shown }, Enum.EasingStyle.Back)
	task.delay(1.25, function()
		if panel.Parent then
			tween(panel, 0.18, { Position = hidden }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.2)
			panel:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Quirk select menu
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- THE TOP BAR and THE HERO PHONE (round 58). Top left, right after Roblox's
-- own buttons (the menu, the chat, the mic): CHARACTER - who you are, with a
-- drop-down - then EMOTES (the wheel); the slot after that is kept free. The
-- drop-down is your hero phone: every hero on it like contacts, the one
-- you're playing marked, and a dock of apps - the shop, your emotes, your
-- settings, the top heroes.
---------------------------------------------------------------------------
local topBar, charButton, charName, charIcon, caret, emoteButton, emoteKey
local phoneParts = {} -- the bits of the phone that follow your hero's colour
local topCallbacks = {}
local PHONE_W, PHONE_H = 300, 600

-- the room Roblox leaves in the top bar (GuiService.TopbarInset: the space
-- to the right of its own buttons)
local function topInset()
	local ok, r = pcall(function()
		return game:GetService("GuiService").TopbarInset
	end)
	if ok and typeof(r) == "Rect" and r.Width > 0 and r.Height > 0 then
		return r.Min.X, r.Min.Y, r.Height
	end
	return 150, 0, 44 -- (nothing to read: about where Roblox's buttons end)
end

local function initials(name)
	local out = ""
	for word in string.gmatch(name or "", "[%w']+") do
		out ..= string.upper(string.sub(word, 1, 1))
		if #out >= 2 then
			break
		end
	end
	return out ~= "" and out or "?"
end

-- a round pill like Roblox's own top bar buttons
local function pill(name, width, parent, order)
	local b = make("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, 40),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	b:SetAttribute("W", width)
	return b
end

function HUD.BuildTopBar(playerGui)
	if topBar then
		return
	end
	local top = make("ScreenGui", {
		Name = "QuirkTopBar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	topBar = make("Frame", {
		Name = "Bar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 40),
		Parent = top,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- CHARACTER: the hero you are, and the phone to change it
	charButton = pill("CharacterButton", 200, topBar, 1)
	charIcon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = accent,
		Parent = charButton,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "📱",
		Parent = charIcon,
	}, { make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }) })
	make("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 42, 0.5, -15),
		Size = UDim2.new(1, -66, 0, 11),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.35,
		Text = "CHARACTER",
		Parent = charButton,
	})
	charName = make("TextLabel", {
		Name = "Hero",
		Position = UDim2.new(0, 42, 0.5, -3),
		Size = UDim2.new(1, -66, 0, 17),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "PICK A HERO",
		Parent = charButton,
	}, { make("UITextSizeConstraint", { MaxTextSize = 14 }) })
	caret = make("TextLabel", {
		Name = "Caret",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "▾",
		Parent = charButton,
	})
	charButton.Activated:Connect(function()
		HUD.ToggleMenu()
		if HUD.MenuVisible() and HUD.ToggleShop then
			HUD.ToggleShop(false)
		end
		if topCallbacks.OnCharacter then
			topCallbacks.OnCharacter(HUD.MenuVisible())
		end
	end)
	-- EMOTES: the wheel
	emoteButton = pill("EmoteButton", 132, topBar, 2)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "🕺",
		Parent = emoteButton,
	})
	make("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 38, 0.5, 0),
		Size = UDim2.new(1, -72, 0, 16),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "EMOTES",
		Parent = emoteButton,
	}, { make("UITextSizeConstraint", { MaxTextSize = 13 }) })
	emoteKey = make("TextLabel", {
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		Font = UI_FONT,
		TextSize = 12,
		TextColor3 = Color3.new(0, 0, 0),
		Text = "B",
		Parent = emoteButton,
	}, { corner(5) })
	emoteButton.Activated:Connect(function()
		if topCallbacks.OnEmotes then
			topCallbacks.OnEmotes()
		end
	end)
	-- (the next one along: nothing there yet)
	make("Frame", { Name = "Reserved", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40), Visible = false, Parent = topBar })
	pcall(function()
		game:GetService("GuiService"):GetPropertyChangedSignal("TopbarInset"):Connect(HUD.PlaceTopBar)
	end)
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(HUD.PlaceTopBar)
	end
	HUD.PlaceTopBar()
end

-- cbs: OnEmotes(), OnCharacter(open)
function HUD.SetTopBarCallbacks(cbs)
	topCallbacks = cbs or {}
end

-- line the bar up with Roblox's buttons; the phone hangs under it
function HUD.PlaceTopBar()
	if not topBar then
		return
	end
	local x, y, h = topInset()
	local bh = math.clamp(h - 14, 30, 44)
	topBar.Position = UDim2.fromOffset(x + 6, y + math.floor((h - bh) / 2))
	topBar.Size = UDim2.fromOffset(420, bh)
	for _, b in { charButton, emoteButton } do
		b.Size = UDim2.fromOffset(b:GetAttribute("W"), bh)
	end
	if menu then
		local fx = phoneParts.fx
		menu.Position = UDim2.fromOffset(x + 6, y + h + 6)
		if fx then
			fx.base = menu.Position
		end
		local cam = workspace.CurrentCamera
		local vpY = cam and cam.ViewportSize.Y or 720
		local fit = menu:FindFirstChild("Fit")
		if fit and vpY > 0 then
			fit.Scale = math.clamp((vpY - (y + h + 16)) / PHONE_H, 0.5, 1.1)
			if fx then
				fx.fitScale = fit.Scale
			end
		end
	end
end

-- the key hint on the EMOTES button follows the input
function HUD.SetTopBarKeys(mode)
	if emoteKey then
		emoteKey.Visible = mode == "Keyboard"
	end
end

-- the hero you're playing: on the button, on the phone
function HUD.MarkHero(quirkName)
	local q = quirkName and Config.Quirks[quirkName]
	if not q then
		return
	end
	if charName then
		charName.Text = string.upper(q.DisplayName or quirkName)
		charIcon.BackgroundColor3 = q.Color
	end
	local wall = phoneParts.Wallpaper
	if wall then
		wall.Color = ColorSequence.new(q.Color:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(8, 9, 14))
		phoneParts.NowName.Text = string.upper(q.DisplayName or quirkName)
		phoneParts.NowInfo.Text = q.Description or ""
		phoneParts.NowStrip.BackgroundColor3 = q.Color
		phoneParts.NowAvatar.BackgroundColor3 = q.Color
		phoneParts.NowAvatar.Initials.Text = initials(q.DisplayName or quirkName)
		if phoneParts.Glow then
			phoneParts.Glow.BackgroundColor3 = q.Color
		end
	end
	for _, row in menuGrid and menuGrid:GetChildren() or {} do
		if row:IsA("TextButton") then
			local on = row.Name == quirkName
			row.Playing.Visible = on
			row.Arrow.Visible = not on
			row.BackgroundTransparency = on and 0.8 or 0.92
		end
	end
end

function HUD.BuildMenu()
	-- (round 62) the phone is a CanvasGroup: it renders flat, then turns,
	-- scales and fades as one piece - so its screen still clips cleanly while
	-- it's tilted - for the pull-out and for leaning after the cursor (the
	-- driver at the end of this function)
	menu = make("CanvasGroup", {
		Name = "QuirkMenu",
		Position = UDim2.fromOffset(160, 56),
		Size = UDim2.fromOffset(PHONE_W, PHONE_H),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 60,
		Parent = gui,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 42) }),
		make("UIScale", { Name = "Fit" }),
	})
	-- the frame: brushed titanium catching the light, a black band inside it
	make("Frame", {
		Name = "Bezel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 58,
		Parent = menu,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 42) }),
		make("UIGradient", {
			Rotation = 35,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 96, 108)),
				ColorSequenceKeypoint.new(0.32, Color3.fromRGB(222, 226, 234)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(84, 88, 100)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(176, 180, 192)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(104, 108, 120)),
			}),
		}),
	})
	make("Frame", {
		Name = "Rim",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		ZIndex = 59,
		Parent = menu,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 38) }) })
	-- (the buttons down its sides, set into the frame)
	for _, b in { { 0, 118, 44 }, { 0, 176, 44 }, { PHONE_W - 3, 150, 64 } } do
		make("Frame", {
			Position = UDim2.fromOffset(b[1], b[2]),
			Size = UDim2.fromOffset(3, b[3]),
			BackgroundColor3 = Color3.fromRGB(46, 48, 58),
			BorderSizePixel = 0,
			ZIndex = 59,
			Parent = menu,
		}, { corner(2) })
	end
	-- the glass: a CanvasGroup too, so everything on it is clipped to its
	-- rounded corners (a plain frame clips square - the glare and the glow
	-- would show on the rim)
	local screen = make("CanvasGroup", {
		Name = "Screen",
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.new(1, -18, 1, -18),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 61,
		Parent = menu,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 32) }) })
	-- (the wallpaper on a frame of its own: a gradient on the group would tint all of it)
	phoneParts.Wallpaper = make("UIGradient", {
		Color = ColorSequence.new(accent:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(8, 9, 14)),
		Rotation = 90,
		Parent = make("Frame", {
			Name = "Wallpaper",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = screen,
		}),
	})
	-- your hero's colour glowing up behind it all (it drifts as the phone leans)
	phoneParts.Glow = make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.8, 0.12),
		Size = UDim2.fromOffset(360, 360),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.45,
		ZIndex = 61,
		Parent = screen,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.45, 0.8),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	phoneParts.Clock = make("TextLabel", {
		Name = "Clock",
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.fromOffset(60, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "9:41",
		ZIndex = 62,
		Parent = screen,
	})
	make("Frame", {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(84, 22),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 63,
		Parent = screen,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- (the island's camera)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(28, 34, 60),
		ZIndex = 64,
		Parent = screen:FindFirstChild("Island"),
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- signal, 5G, the battery
	local status = make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 11),
		Size = UDim2.fromOffset(72, 14),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = screen,
	})
	for i = 1, 4 do
		make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset((i - 1) * 4, 12),
			Size = UDim2.fromOffset(3, 3 + i * 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 62,
			Parent = status,
		}, { corner(1) })
	end
	make("TextLabel", {
		Position = UDim2.fromOffset(19, 0),
		Size = UDim2.fromOffset(20, 13),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "5G",
		ZIndex = 62,
		Parent = status,
	})
	local battery = make("Frame", {
		Name = "Battery",
		Position = UDim2.fromOffset(44, 1),
		Size = UDim2.fromOffset(23, 11),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = status,
	}, {
		corner(3),
		make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	make("Frame", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(0.8, -2, 1, -4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 63,
		Parent = battery,
	}, { corner(2) })
	make("Frame", {
		Position = UDim2.new(1, 2, 0.5, -2),
		Size = UDim2.fromOffset(2, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = battery,
	}, { corner(1) })
	-- the app: HERO NETWORK
	local kicker = make("TextLabel", {
		Name = "Kicker",
		Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(1, -36, 0, 14),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "HERO NETWORK",
		ZIndex = 62,
		Parent = screen,
	}, { make("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	make("Frame", { -- (live)
		Name = "Live",
		Position = UDim2.new(0, -12, 0.5, -3),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(255, 70, 90),
		ZIndex = 63,
		Parent = kicker,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	make("TextLabel", {
		Name = "Headline",
		Position = UDim2.fromOffset(18, 54),
		Size = UDim2.new(1, -36, 0, 26),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Who are you today?",
		ZIndex = 62,
		Parent = screen,
	})
	-- who you are now
	local now = make("Frame", {
		Name = "Now",
		Position = UDim2.fromOffset(12, 88),
		Size = UDim2.new(1, -24, 0, 72),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.86,
		ZIndex = 62,
		Parent = screen,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 16) }) })
	phoneParts.NowStrip = make("Frame", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(0, 4, 1, -32),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 63,
		Parent = now,
	}, { corner(2) })
	phoneParts.NowAvatar = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = accent,
		ZIndex = 63,
		Parent = now,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	make("TextLabel", {
		Name = "Initials",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextSize = 17,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "?",
		ZIndex = 64,
		Parent = phoneParts.NowAvatar,
	}, { textStroke(1) })
	make("TextLabel", {
		Position = UDim2.fromOffset(70, 10),
		Size = UDim2.new(1, -80, 0, 12),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.3,
		Text = "NOW PLAYING AS",
		ZIndex = 63,
		Parent = now,
	})
	phoneParts.NowName = make("TextLabel", {
		Position = UDim2.fromOffset(70, 22),
		Size = UDim2.new(1, -80, 0, 20),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "NO ONE YET",
		ZIndex = 63,
		Parent = now,
	}, { make("UITextSizeConstraint", { MaxTextSize = 17 }) })
	phoneParts.NowInfo = make("TextLabel", {
		Position = UDim2.fromOffset(70, 44),
		Size = UDim2.new(1, -80, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.25,
		Text = "Pick one below",
		ZIndex = 63,
		Parent = now,
	})
	make("TextLabel", {
		Position = UDim2.fromOffset(20, 168),
		Size = UDim2.new(1, -40, 0, 14),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.35,
		Text = "HEROES",
		ZIndex = 62,
		Parent = screen,
	})
	-- every hero, like contacts
	local list = make("ScrollingFrame", {
		Name = "Heroes",
		Position = UDim2.fromOffset(10, 186),
		Size = UDim2.new(1, -20, 1, -186 - 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 62,
		Parent = screen,
	}, {
		make("UIListLayout", { Name = "List", Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }),
	})
	menuGrid = list
	for order, quirkName in Config.QuirkOrder do
		local q = Config.Quirks[quirkName]
		local row = make("TextButton", {
			Name = quirkName,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.92,
			AutoButtonColor = true,
			Text = "",
			ZIndex = 63,
			Parent = list,
		}, { make("UICorner", { CornerRadius = UDim.new(0, 14) }) })
		local avatar = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = q.Color,
			ZIndex = 64,
			Parent = row,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150), 90),
			make("UIStroke", { Thickness = 1.5, Color = q.Color:Lerp(Color3.new(1, 1, 1), 0.5), Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		-- (round 62) a stripe of the hero's colour down the row's edge
		make("Frame", {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -22),
			BackgroundColor3 = q.Color,
			BorderSizePixel = 0,
			ZIndex = 64,
			Parent = row,
		}, { corner(2) })
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = initials(q.DisplayName or quirkName),
			ZIndex = 65,
			Parent = avatar,
		}, { textStroke(1) })
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(58, 9),
			Size = UDim2.new(1, -120, 0, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = q.DisplayName or quirkName,
			ZIndex = 64,
			Parent = row,
		}, { make("UITextSizeConstraint", { MaxTextSize = 14 }) })
		make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(58, 29),
			Size = UDim2.new(1, -118, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.3,
			Text = q.Description or "",
			ZIndex = 64,
			Parent = row,
		})
		make("TextLabel", {
			Name = "Playing", -- (not "Active": a button has a property of that name)
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(46, 18),
			BackgroundColor3 = Color3.fromRGB(60, 200, 110),
			Font = UI_FONT,
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "ACTIVE",
			Visible = false,
			ZIndex = 65,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		make("TextLabel", {
			Name = "Arrow",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(12, 20),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.4,
			Text = "›",
			ZIndex = 64,
			Parent = row,
		})
		if q.DevOnly then
			row.Visible = devAccess
			make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -30, 0, 6),
				Size = UDim2.fromOffset(30, 14),
				BackgroundColor3 = Color3.fromRGB(255, 212, 64),
				Font = UI_FONT,
				TextSize = 9,
				TextColor3 = Color3.new(0, 0, 0),
				Text = "DEV",
				ZIndex = 65,
				Parent = row,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		row.Activated:Connect(function()
			if callbacks.OnSelect then
				callbacks.OnSelect(quirkName)
			end
			HUD.ShowMenu(false)
		end)
	end
	-- the dock: the other apps
	local dock = make("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -20, 0, 80),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.84,
		ZIndex = 62,
		Parent = screen,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 24) }),
		make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local APPS = {
		{ "Shop", "SHOP", "🛒", Color3.fromRGB(70, 190, 100), function()
			HUD.ToggleShop(true)
			if HUD.ShopTab then
				HUD.ShopTab("Items")
			end
		end },
		{ "Emotes", "EMOTES", "🕺", Color3.fromRGB(230, 90, 160), function()
			if HUD.OpenEmoteShop then
				HUD.OpenEmoteShop()
			end
		end },
		-- (round 59) your saved Roblox outfits: the one you'll wear awakened
		{ "Outfit", "OUTFIT", "👕", Color3.fromRGB(80, 130, 230), function()
			if HUD.OpenOutfits then
				HUD.OpenOutfits()
			end
		end },
		{ "Settings", "SETTINGS", "⚙️", Color3.fromRGB(110, 116, 136), function()
			HUD.ToggleSettings(true)
		end },
		{ "Board", "TOP", "🏆", Color3.fromRGB(240, 180, 40), function()
			HUD.ToggleBoard(true)
		end },
	}
	for i, app in APPS do
		local b = make("TextButton", {
			Name = "App_" .. app[1],
			LayoutOrder = i,
			Size = UDim2.fromOffset(46, 64),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 63,
			Parent = dock,
		})
		local icon = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(42, 42),
			BackgroundColor3 = app[4],
			ZIndex = 64,
			Parent = b,
		}, { make("UICorner", { CornerRadius = UDim.new(0, 13) }), gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90) })
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = app[3],
			ZIndex = 65,
			Parent = icon,
		}, { make("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }) })
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 8, 0, 12),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			Text = app[2],
			ZIndex = 64,
			Parent = b,
		})
		b.Activated:Connect(function()
			HUD.ShowMenu(false)
			app[5]()
		end)
	end
	-- the home bar
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(110, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		ZIndex = 63,
		Parent = screen,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- (round 62) THE GLASS: a glare that slides as the phone leans, a glint
	-- that sweeps across as it comes out, and the screen powering on (black,
	-- a bright line drawn across it that opens into the picture)
	phoneParts.Glare = make("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.84),
			NumberSequenceKeypoint.new(0.3, 0.94),
			NumberSequenceKeypoint.new(0.34, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = make("Frame", {
			Name = "Glare",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 90,
			Parent = screen,
		}),
	})
	phoneParts.Glint = make("UIGradient", {
		Rotation = 25,
		Offset = Vector2.new(-1.2, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.43, 1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(0.57, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = make("Frame", {
			Name = "Glint",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 91,
			Parent = screen,
		}),
	})
	phoneParts.Boot = make("Frame", {
		Name = "Boot",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		ZIndex = 92,
		Parent = screen,
	})
	phoneParts.Scan = make("Frame", {
		Name = "Scan",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 93,
		Parent = screen,
	})

	-- what comes in after it: the header slides in, the card pops, the heroes
	-- slide in one after another, the apps bounce up out of the dock
	local fx = { rows = {}, rowList = {}, apps = {}, appList = {}, hx = 0, hy = 0, hover = 0 }
	phoneParts.fx = fx
	HUD.PhoneFx = fx -- (tests and previews can read / scrub it)
	fx.fit = menu:FindFirstChild("Fit")
	fx.kicker = screen:FindFirstChild("Kicker")
	fx.headline = screen:FindFirstChild("Headline")
	fx.live = fx.kicker and fx.kicker:FindFirstChild("Live")
	fx.nowPop = make("UIScale", { Name = "Pop", Parent = now })
	for _, row in list:GetChildren() do
		if row:IsA("TextButton") then
			fx.rows[row] = make("UIPadding", { Name = "Slide", Parent = row })
			table.insert(fx.rowList, row)
			-- the cursor over a hero lights its row and nudges its arrow
			row.MouseEnter:Connect(function()
				tween(row, 0.12, { BackgroundTransparency = 0.78 })
				tween(row.Arrow, 0.12, { TextTransparency = 0, Position = UDim2.new(1, -6, 0.5, 0) })
			end)
			row.MouseLeave:Connect(function()
				tween(row, 0.2, { BackgroundTransparency = row.Playing.Visible and 0.8 or 0.92 })
				tween(row.Arrow, 0.2, { TextTransparency = 0.4, Position = UDim2.new(1, -12, 0.5, 0) })
			end)
		end
	end
	table.sort(fx.rowList, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for _, b in dock:GetChildren() do
		if b:IsA("TextButton") then
			local icon = b:FindFirstChildOfClass("Frame")
			local app = { pop = make("UIScale", { Name = "Pop", Parent = icon }), hover = 0, over = false }
			fx.apps[b] = app
			table.insert(fx.appList, b)
			b.MouseEnter:Connect(function()
				app.over = true
			end)
			b.MouseLeave:Connect(function()
				app.over = false
			end)
		end
	end
	table.sort(fx.appList, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	-- THE DRIVER: every frame the phone's out, from how long since it came
	-- out (or started going away) and where the cursor is
	local function clamp01(x)
		return math.clamp(x, 0, 1)
	end
	local function outCubic(x)
		return 1 - (1 - x) ^ 3
	end
	local function backOut(x, s)
		x -= 1
		return 1 + (s + 1) * x * x * x + s * x * x
	end
	local uis = game:GetService("UserInputService")
	function HUD.PhoneStep(dt)
		if not menu.Visible then
			return
		end
		local now = os.clock()
		dt = math.min(dt or 1 / 60, 0.1)
		local t = now - (fx.openAt or -10)
		-- out of the button: it springs up to size from where it hangs, turned
		-- and swinging, overshoots and settles (away: it tips and drops back in)
		local scale, rot, lift, fade
		if fx.closeAt then
			local v = clamp01((now - fx.closeAt) / 0.18)
			local e = v * v * v
			scale, rot, lift, fade = 1 - 0.3 * e, 10 * e, -30 * e, v
			if v >= 1 then
				fx.closeAt = nil
				menu.Visible = false
				return
			end
		else
			local u = clamp01(t / 0.52)
			scale = 0.35 + 0.65 * backOut(u, 1.9)
			rot = -20 * (1 - outCubic(u)) + 5 * math.sin(u * math.pi * 2) * (1 - u)
			lift = -48 * (1 - outCubic(u))
			fade = 1 - clamp01(t / 0.1)
		end
		-- the cursor over it: it leans after it, lifts a touch, the glare and
		-- the glow slide the other way (the glass catching the light). (Where
		-- it rests, not where it's leaning to - so it never chases itself.)
		local tx, ty, over = 0, 0, 0
		if not fx.closeAt then
			pcall(function()
				if uis.MouseEnabled then
					local m = uis:GetMouseLocation()
					local at = fx.base or menu.Position
					local p = Vector2.new(at.X.Offset, at.Y.Offset)
					local s = Vector2.new(PHONE_W, PHONE_H) * (fx.fitScale or 1)
					if m.X > p.X - 18 and m.X < p.X + s.X + 18 and m.Y > p.Y - 18 and m.Y < p.Y + s.Y + 18 then
						tx = math.clamp((m.X - (p.X + s.X / 2)) / (s.X / 2), -1, 1)
						ty = math.clamp((m.Y - (p.Y + s.Y / 2)) / (s.Y / 2), -1, 1)
						over = 1
					end
				end
			end)
		end
		local k = 1 - math.exp(-dt * 9)
		fx.hx += (tx - fx.hx) * k
		fx.hy += (ty - fx.hy) * k
		fx.hover += (over - fx.hover) * k
		local base = fx.base or menu.Position
		menu.Position = base + UDim2.fromOffset(math.floor(fx.hx * 14 + 0.5), math.floor(lift + fx.hy * 10 + 0.5))
		menu.Rotation = rot + fx.hx * 6
		menu.GroupTransparency = fade
		if fx.fit then
			fx.fit.Scale = (fx.fitScale or 1) * scale * (1 + 0.035 * fx.hover)
		end
		phoneParts.Glare.Offset = Vector2.new(-0.25 - fx.hx * 0.3, -fx.hy * 0.25)
		phoneParts.Glow.Position = UDim2.new(0.8, math.floor(-fx.hx * 18 + 0.5), 0.12, math.floor(-fx.hy * 18 + 0.5))
		-- the live dot on HERO NETWORK breathes
		if fx.live then
			fx.live.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * 5))
		end
		-- (all of the rest is the pull-out: done after a second)
		if t > 1.3 then
			for _, b in fx.appList do
				local app = fx.apps[b]
				app.hover += ((app.over and 1 or 0) - app.hover) * k
				app.pop.Scale = 1 + 0.16 * app.hover
			end
			return
		end
		-- the screen powers on: black, a line drawn across it, opening into the picture
		local boot, scan = phoneParts.Boot, phoneParts.Scan
		boot.Visible = t < 0.42 and not fx.closeAt
		boot.BackgroundTransparency = clamp01((t - 0.14) / 0.24)
		scan.Visible = t < 0.36 and not fx.closeAt
		local across, open = outCubic(clamp01((t - 0.02) / 0.12)), outCubic(clamp01((t - 0.14) / 0.2))
		scan.Size = UDim2.new(across, 0, open, 2)
		scan.BackgroundTransparency = open * 0.92
		scan.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(phoneParts.Glow.BackgroundColor3, open)
		-- a glint across the glass
		local g = clamp01((t - 0.24) / 0.42)
		phoneParts.Glint.Parent.Visible = g > 0 and g < 1
		phoneParts.Glint.Offset = Vector2.new(-1.2 + 2.4 * outCubic(g), 0)
		local function step(delay, length)
			return clamp01((t - delay) / length)
		end
		if fx.kicker then
			fx.kicker.Position = UDim2.fromOffset(18 + math.floor(36 * (1 - outCubic(step(0.14, 0.3))) + 0.5), 40)
			fx.kicker.TextTransparency = 1 - step(0.14, 0.2)
		end
		if fx.headline then
			fx.headline.Position = UDim2.fromOffset(18 + math.floor(48 * (1 - outCubic(step(0.18, 0.32))) + 0.5), 54)
			fx.headline.TextTransparency = 1 - step(0.18, 0.2)
		end
		fx.nowPop.Scale = math.max(backOut(step(0.2, 0.34), 2.2), 0.01)
		local i = 0
		for _, row in fx.rowList do
			if row.Visible then
				local e = outCubic(step(0.26 + math.min(i, 7) * 0.035, 0.3)) -- (the ones below the fold land together)
				local pad = math.floor(56 * (1 - e) + 0.5)
				fx.rows[row].PaddingLeft = UDim.new(0, pad)
				fx.rows[row].PaddingRight = UDim.new(0, -pad)
				i += 1
			end
		end
		for j, b in fx.appList do
			local app = fx.apps[b]
			app.hover += ((app.over and 1 or 0) - app.hover) * k
			app.pop.Scale = math.max(backOut(step(0.3 + (j - 1) * 0.04, 0.3), 2.4), 0) * (1 + 0.16 * app.hover)
		end
	end
	RunService.RenderStepped:Connect(HUD.PhoneStep)
	HUD.SetDevAccess(devAccess)
	HUD.PlaceTopBar()
end

-- Dev-only quirks (Config DevOnly = true) only show for testers
function HUD.SetDevAccess(on)
	devAccess = on == true
	if not menuGrid then
		return
	end
	local shown = 0
	for _, button in menuGrid:GetChildren() do
		if button:IsA("TextButton") then
			local q = Config.Quirks[button.Name]
			if q and q.DevOnly then
				button.Visible = devAccess
			end
			if button.Visible then
				shown += 1
			end
		end
	end
	local layout = menuGrid:FindFirstChild("Layout")
	if layout then
		-- 2x2 for four, 3 across for up to six, 4 across beyond that
		local cols = shown <= 4 and 2 or shown <= 6 and 3 or 4
		local rows = math.max(1, math.ceil(shown / cols))
		-- (UDim offsets are whole pixels: round the gaps up so the row still fits)
		local gap = math.ceil(10 * (cols - 1) / cols)
		layout.CellSize = UDim2.new(1 / cols, -gap, 1 / rows, -math.ceil(10 * (rows - 1) / rows))
	end
	local size = menu and menu:FindFirstChildOfClass("UISizeConstraint")
	if size then
		size.MaxSize = shown > 6 and Vector2.new(900, 480) or Vector2.new(720, 460)
	end
end

-- (round 62) a burst of light off the CHARACTER button as the phone comes
-- out of it: a ring and rays in your hero's colour
local function phoneBurst()
	if not (gui and charIcon and topBar) then
		return
	end
	-- (the icon: 5 px into the button, 30 across, halfway down the bar)
	local c = Vector2.new(topBar.Position.X.Offset + 20, topBar.Position.Y.Offset + topBar.Size.Y.Offset / 2)
	local holder = make("Frame", {
		Name = "PhoneBurst",
		Position = UDim2.fromOffset(c.X, c.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 58,
		Parent = gui,
	})
	local ring = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = 58,
		Parent = holder,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIStroke", { Thickness = 3, Color = accent, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	tween(ring, 0.42, { Size = UDim2.fromOffset(170, 170) }, Enum.EasingStyle.Quart)
	tween(ring:FindFirstChildOfClass("UIStroke"), 0.42, { Transparency = 1, Thickness = 1 })
	for i = 0, 9 do
		local arm = make("Frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Rotation = i * 36 + rng:NextNumber(-8, 8),
			ZIndex = 58,
			Parent = holder,
		})
		local ray = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(0, -16),
			Size = UDim2.fromOffset(3, 8),
			BackgroundColor3 = i % 2 == 0 and accent or Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 58,
			Parent = arm,
		}, { corner(2) })
		tween(ray, 0.34, { Position = UDim2.fromOffset(0, -62 - (i % 3) * 10), Size = UDim2.fromOffset(2, 26), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
	end
	-- the button's icon pops
	local pop = charIcon:FindFirstChild("Pop") or make("UIScale", { Name = "Pop", Parent = charIcon })
	pop.Scale = 1.35
	tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.6, function()
		holder:Destroy()
	end)
end

-- Taking the phone out: it springs up out of the button - turned, swinging,
-- overshooting and settling - its screen powers on, a glint crosses the
-- glass and everything on it slides in after (HUD.PhoneStep drives it).
-- Putting it away: it tips and drops back in.
function HUD.ShowMenu(visible)
	if menu then
		local fx = phoneParts.fx
		local was = menu.Visible and not (fx and fx.closeAt)
		if visible == true and not was then
			-- (its clock set to now)
			HUD.PlaceTopBar()
			local clock = phoneParts.Clock
			if clock then
				local ok, t = pcall(os.date, "%H:%M")
				if ok and type(t) == "string" then
					clock.Text = t
				end
			end
			menu.Visible = true
			if fx then
				fx.openAt = os.clock()
				fx.closeAt = nil
				fx.hx, fx.hy, fx.hover = 0, 0, 0
				HUD.PhoneStep(0)
			end
			phoneBurst()
		elseif visible ~= true and was then
			if fx then
				fx.closeAt = os.clock()
			else
				menu.Visible = false
			end
		end
	end
	if caret then
		caret.Text = HUD.MenuVisible() and "▴" or "▾"
	end
	if HUD.TouchSync then
		HUD.TouchSync()
	end
end

function HUD.ToggleMenu()
	HUD.ShowMenu(not HUD.MenuVisible())
end

---------------------------------------------------------------------------
-- Radial anime speed lines (the skydive shot in the reference clip)
---------------------------------------------------------------------------

function HUD.SpeedLines(duration)
	local size = gui.AbsoluteSize
	local maxDim = math.max(size.X, size.Y)
	local holder = make("Frame", {
		Name = "SpeedLines",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = gui,
	})
	local lines = {}
	for i = 1, 40 do
		local angle = i / 40 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = maxDim * rng:NextNumber(0.42, 0.62)
		local len = maxDim * rng:NextNumber(0.25, 0.45)
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * r, 0.5, math.sin(angle) * r),
			Size = UDim2.fromOffset(len, rng:NextInteger(2, 5)),
			Rotation = math.deg(angle),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = rng:NextNumber(0.2, 0.6),
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = holder,
		})
		table.insert(lines, line)
	end
	-- flicker like hand-drawn focus lines, then fade
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration and holder.Parent do
			for _, line in lines do
				line.BackgroundTransparency = rng:NextNumber(0.15, 0.8)
			end
			task.wait(0.05)
		end
		for _, line in lines do
			tween(line, 0.2, { BackgroundTransparency = 1 })
		end
		task.wait(0.22)
		holder:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Testing menu
---------------------------------------------------------------------------

local testPanel, testOpenButton
local TEST_W = 340 -- (round 58: the test menu's width; its side panels open beside it)
local testRows = {}

-- items: { { Id, Label, Toggle = bool } }, onCommand(id)
function HUD.BuildTestMenu(items, onCommand)
	if testPanel then
		return
	end
	testOpenButton = make("TextButton", {
		Name = "TestButton",
		Position = UDim2.new(0, 12, 0, 70),
		Size = UDim2.fromOffset(64, 30),
		BackgroundColor3 = Color3.fromRGB(255, 196, 40),
		Font = UI_FONT,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		Text = "TEST",
		ZIndex = 20,
		Parent = gui,
	}, { stroke(2.5), corner(6) })
	-- (round 58) wider, and laid out: a header, then the buttons in groups,
	-- two to a row, with real on/off switches on the toggles
	testPanel = make("Frame", {
		Name = "TestMenu",
		Position = UDim2.new(0, 12, 0, 108),
		Size = UDim2.fromOffset(TEST_W, 520),
		BackgroundColor3 = Color3.fromRGB(17, 18, 27),
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		corner(12),
		make("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(255, 212, 64), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 30),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "TEST MENU",
		ZIndex = 21,
		Parent = testPanel,
	}, { textStroke(1.5) })
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -70, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 194, 214),
		Text = "For testers  ·  P opens and closes it",
		ZIndex = 21,
		Parent = testPanel,
	})
	local close = make("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(46, 48, 66),
		Font = UI_FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		ZIndex = 22,
		Parent = testPanel,
	}, { corner(15) })
	close.MouseButton1Click:Connect(function()
		HUD.ToggleTestMenu(false)
	end)
	make("Frame", {
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = testPanel,
	})
	-- (a scrolling list: it keeps growing)
	local list = make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -18, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = testPanel,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	})
	-- the groups, in the order they first come up
	local order, groups = {}, {}
	for _, item in items do
		local g = item.Group or "More"
		if not groups[g] then
			groups[g] = {}
			table.insert(order, g)
		end
		table.insert(groups[g], item)
	end
	local lo, height = 0, 76
	local IDLE = Color3.fromRGB(42, 44, 62)
	for _, g in order do
		lo += 1
		make("TextLabel", {
			Name = "Group_" .. g,
			LayoutOrder = lo,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = string.upper(g),
			ZIndex = 21,
			Parent = list,
		})
		lo += 1
		local rows = math.ceil(#groups[g] / 2)
		local grid = make("Frame", {
			LayoutOrder = lo,
			Size = UDim2.new(1, 0, 0, rows * 34 + (rows - 1) * 6),
			BackgroundTransparency = 1,
			ZIndex = 21,
			Parent = list,
		}, {
			make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 34), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		height += 24 + rows * 40
		for i, item in groups[g] do
			local button = make("TextButton", {
				Name = item.Id,
				LayoutOrder = i,
				BackgroundColor3 = IDLE,
				AutoButtonColor = true,
				Text = "",
				ZIndex = 22,
				Parent = grid,
			}, { corner(8), make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.88, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			local label = make("TextLabel", {
				Name = "Label",
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, item.Toggle and -50 or -24, 1, 0),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = item.Label,
				ZIndex = 23,
				Parent = button,
			}, { make("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }) })
			local row = { Button = button, Item = item, Label = label }
			if item.Toggle then
				row.Track = make("Frame", {
					Name = "Switch",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(32, 18),
					BackgroundColor3 = Color3.fromRGB(78, 80, 98),
					ZIndex = 23,
					Parent = button,
				}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				row.Knob = make("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 2, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 24,
					Parent = row.Track,
				}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			elseif string.sub(item.Label, -3) == "..." then
				label.Text = string.sub(item.Label, 1, -4)
				make("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(12, 18),
					BackgroundTransparency = 1,
					Font = UI_FONT,
					TextSize = 16,
					TextColor3 = Color3.fromRGB(255, 212, 64),
					Text = "›",
					ZIndex = 23,
					Parent = button,
				})
			end
			testRows[item.Id] = row
			button.MouseButton1Click:Connect(function()
				onCommand(item.Id)
				if not item.Toggle then
					button.BackgroundColor3 = Color3.fromRGB(255, 212, 64)
					tween(button, 0.35, { BackgroundColor3 = IDLE })
				end
			end)
		end
	end
	testPanel.Size = UDim2.fromOffset(TEST_W, math.min(height, 560))
	testOpenButton.MouseButton1Click:Connect(function()
		HUD.ToggleTestMenu()
	end)
end

function HUD.ToggleTestMenu(force)
	if not testPanel then
		return
	end
	if force ~= nil then
		testPanel.Visible = force
	else
		testPanel.Visible = not testPanel.Visible
	end
	if not testPanel.Visible then
		-- its side panels close with it
		HUD.ToggleDevPanel(false)
		HUD.ToggleDummyPanel(false)
		HUD.ToggleFunPanel(false)
		HUD.ToggleServerPanel(false)
	end
end

function HUD.SetTestToggle(id, on)
	local row = testRows[id]
	if not row then
		return
	end
	if row.Track then
		row.Track.BackgroundColor3 = on and Color3.fromRGB(60, 200, 110) or Color3.fromRGB(78, 80, 98)
		row.Knob.Position = on and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	end
	row.Button.BackgroundColor3 = on and Color3.fromRGB(34, 64, 48) or Color3.fromRGB(42, 44, 62)
	row.Button:SetAttribute("On", on == true)
end

---------------------------------------------------------------------------
-- Fight feedback: guard meter, KO stats, combo counter, kill feed, KO popup,
-- callouts and the knocked-out recap
---------------------------------------------------------------------------

local guardBar, guardFill, guardText, guardConns
local comboFrame, comboHits, comboDamage, comboCount, comboTotal, comboToken = nil, nil, nil, 0, 0, 0
local feedList
local recapPanel

local GUARD_COLOR = Color3.fromRGB(120, 210, 255)
local GUARD_LOW = Color3.fromRGB(255, 90, 70)

local function quirkLabel(q)
	local quirk = q and Config.Quirks[q]
	return quirk and quirk.DisplayName or nil, quirk and quirk.Color or Color3.fromRGB(200, 200, 210)
end

function HUD.InitFight(player)
	-- guard meter (under the ult meter)
	guardBar = make("Frame", {
		Name = "GuardMeter",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.5, -4, 0, 12),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Parent = vitals or gui,
	}, { edge(0.7), corner(2) })
	guardFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GUARD_COLOR,
		BorderSizePixel = 0,
		Parent = guardBar,
	}, { corner(2) })
	guardText = make("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "GUARD [F]",
		ZIndex = 2,
		Parent = guardBar,
	}, { textStroke(1) })

	-- the ragdoll cancel's meter (beside the guard meter)
	HUD.Evasive = {}
	HUD.Evasive.Bar = make("Frame", {
		Name = "EvasiveMeter",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(0.5, -4, 0, 12),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Parent = vitals or gui,
	}, { corner(2) })
	HUD.Evasive.Fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 235, 255),
		BorderSizePixel = 0,
		Parent = HUD.Evasive.Bar,
	}, { corner(2), gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 210)) })
	HUD.Evasive.Text = make("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "EVASIVE READY",
		ZIndex = 2,
		Parent = HUD.Evasive.Bar,
	}, { textStroke(1) })
	HUD.Evasive.Stroke = make("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = HUD.Evasive.Bar })

	-- your hero rank (Config.Ranks, by all-time kills) + kills and streak,
	-- and the SETTINGS / TOP HEROES buttons under it
	HUD.BuildRankCard(player)

	-- kill feed (top-right, newest on top)
	feedList = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 160),
		Size = UDim2.fromOffset(330, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- combo counter (right side)
	comboFrame = make("Frame", {
		Name = "Combo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -28, 0.46, 0),
		Size = UDim2.fromOffset(190, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	comboHits = make("TextLabel", {
		Size = UDim2.new(1, 0, 0.62, 0),
		BackgroundTransparency = 1,
		Font = HEAD_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 226, 92),
		Text = "",
		Parent = comboFrame,
	}, { textStroke(2) })
	comboDamage = make("TextLabel", {
		Position = UDim2.fromScale(0, 0.66),
		Size = UDim2.new(1, 0, 0.3, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = comboFrame,
	}, { textStroke(1.5) })
end

-- MUSIC on/off (the ult themes): a small glass switch under the rank card
function HUD.BuildMusicToggle(onToggle)
	if HUD.MusicButton or not gui then
		return
	end
	local b = make("TextButton", {
		Name = "MusicToggle",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 130),
		Size = UDim2.fromOffset(150, 22),
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Font = UI_FONT,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "♪ MUSIC: ON",
		AutoButtonColor = true,
		Parent = gui,
	}, { edge(), corner(3) })
	HUD.MusicButton = b
	b.MouseButton1Click:Connect(function()
		if onToggle then
			onToggle()
		end
	end)
end

function HUD.SetMusic(on)
	if HUD.MusicButton then
		HUD.MusicButton.Text = on and "♪ MUSIC: ON" or "♪ MUSIC: OFF"
		HUD.MusicButton.TextTransparency = on and 0 or 0.45
	end
	HUD.SetSetting("Music", on)
end

function HUD.BindGuard(char)
	for _, c in guardConns or {} do
		c:Disconnect()
	end
	guardConns = {}
	local max = (Config.Guard and Config.Guard.Max) or 100
	local function update()
		local value = char:GetAttribute("Guard") or max
		local ratio = math.clamp(value / max, 0, 1)
		tween(guardFill, 0.12, { Size = UDim2.fromScale(ratio, 1) })
		guardFill.BackgroundColor3 = GUARD_LOW:Lerp(GUARD_COLOR, ratio)
		if char:GetAttribute("GuardBroken") then
			guardText.Text = "GUARD BROKEN"
			guardFill.BackgroundColor3 = GUARD_LOW
		elseif char:GetAttribute("Blocking") then
			guardText.Text = string.format("GUARDING  %d", value)
		else
			guardText.Text = value >= max and ("GUARD [" .. keyText.Guard .. "]") or string.format("GUARD  %d", value)
		end
	end
	for _, attr in { "Guard", "Blocking", "GuardBroken" } do
		table.insert(guardConns, char:GetAttributeChangedSignal(attr):Connect(update))
	end
	update()
	-- out of a fight, healing: the green tag and a shine along the bar
	local function regen()
		local on = char:GetAttribute("Regenerating") == true
		if regenLabel then
			regenLabel.Visible = on
		end
		if healthShine then
			healthShine.Visible = on
		end
	end
	table.insert(guardConns, char:GetAttributeChangedSignal("Regenerating"):Connect(regen))
	regen()
end

-- Big mid-screen word: PARRY!, GUARD BROKEN, ...
function HUD.Callout(text, color)
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextScaled = true,
		TextColor3 = color or Color3.new(1, 1, 1),
		Text = text,
		Rotation = rng:NextNumber(-6, 6),
		ZIndex = 35,
		Parent = gui,
	}, { textStroke(3) })
	local scale = make("UIScale", { Scale = 1.8, Parent = label })
	tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.7, function()
		tween(label, 0.25, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.26) })
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			tween(st, 0.25, { Transparency = 1 })
		end
		task.wait(0.27)
		label:Destroy()
	end)
end

-- Your landed hits chain into a combo; it resets after Config.Fights.ComboTimeout
function HUD.ComboHit(amount)
	comboCount += 1
	comboTotal += amount or 0
	comboToken += 1
	local token = comboToken
	if comboCount >= 2 then
		comboFrame.Visible = true
		comboHits.Text = string.format("%d HITS", comboCount)
		comboDamage.Text = string.format("%d DMG", math.floor(comboTotal))
		comboHits.TextTransparency = 0
		comboDamage.TextTransparency = 0
		local sc = comboHits:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = comboHits })
		sc.Scale = 1.35
		tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local timeout = (Config.Fights and Config.Fights.ComboTimeout) or 1.4
	task.delay(timeout, function()
		if comboToken == token then
			HUD.ComboBreak()
		end
	end)
end

function HUD.ComboBreak()
	comboToken += 1
	comboCount, comboTotal = 0, 0
	if comboFrame and comboFrame.Visible then
		tween(comboHits, 0.25, { TextTransparency = 1 })
		tween(comboDamage, 0.25, { TextTransparency = 1 })
		local token = comboToken
		task.delay(0.26, function()
			if comboToken == token then
				comboFrame.Visible = false
			end
		end)
	end
end

-- data: { Killer, KillerQuirk, Victim, VictimQuirk, Streak, Callout, Shutdown, Dummy }
function HUD.KillFeed(data)
	if not feedList then
		return
	end
	local _, killerColor = quirkLabel(data.KillerQuirk)
	local _, victimColor = quirkLabel(data.VictimQuirk)
	local function hex(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
	end
	local text
	if data.Killer then
		local verb = data.Finisher and '<font color="#FF5A4A"><b>FINISHED</b></font>' or "<b>KO</b>"
		text = string.format('<font color="%s">%s</font>  %s  <font color="%s">%s</font>', hex(killerColor), data.Killer, verb, hex(victimColor), data.Victim or "?")
		if data.Callout then
			text ..= string.format('  <font color="#FFD440">%s x%d</font>', data.Callout, data.Streak or 0)
		end
	else
		text = string.format('<font color="%s">%s</font>  went down', hex(victimColor), data.Victim or "?")
	end
	if data.Shutdown then
		text ..= string.format('  <font color="#FF8A70">(ended a %d streak)</font>', data.Shutdown)
	end
	for _, child in feedList:GetChildren() do
		if child:IsA("GuiObject") then
			child.LayoutOrder += 1
			if child.LayoutOrder > 5 then
				child:Destroy()
			end
		end
	end
	local row = make("TextLabel", {
		LayoutOrder = 0,
		Size = UDim2.fromOffset(330, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = GLASS.Color,
		BackgroundTransparency = GLASS.T,
		Font = UI_FONT,
		TextSize = 13,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = feedList,
	}, { corner(3), edge(), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10) }) })
	make("Frame", {
		Name = "Strip",
		Position = UDim2.new(0, -12, 0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = data.Killer and killerColor or victimColor,
		BorderSizePixel = 0,
		Parent = row,
	})
	task.delay(7, function()
		if row.Parent then
			tween(row, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
			task.wait(0.42)
			row:Destroy()
		end
	end)
end

-- You landed a KO. data: { Victim, Streak, Counted, Callout, Heal, Finisher }
function HUD.KOPopup(data)
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(460, 130),
		BackgroundTransparency = 1,
		ZIndex = 36,
		Parent = gui,
	})
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0.62, 0),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 70, 60),
		Text = data.Finisher and "FINISHED!" or data.Counted and "K.O.!" or "DUMMY DOWN",
		Rotation = -5,
		ZIndex = 37,
		Parent = holder,
	}, { textStroke(4) })
	local sub = { "KNOCKED OUT " .. string.upper(data.Victim or "?") }
	if data.Counted and (data.Streak or 0) >= 2 then
		table.insert(sub, string.format("STREAK x%d%s", data.Streak, data.Callout and ("  —  " .. data.Callout) or ""))
	end
	if data.Heal and data.Heal > 0 then
		table.insert(sub, string.format("+%d HP", data.Heal))
	end
	if data.Bucks and data.Bucks > 0 then
		table.insert(sub, string.format("+%d BUCKS", data.Bucks))
	end
	make("TextLabel", {
		Position = UDim2.fromScale(0, 0.64),
		Size = UDim2.new(1, 0, 0.3, 0),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextScaled = true,
		TextColor3 = data.Callout and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1),
		Text = table.concat(sub, "   ·   "),
		ZIndex = 37,
		Parent = holder,
	}, { textStroke(2) })
	local scale = make("UIScale", { Scale = 2.2, Parent = holder })
	tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	HUD.Flash(Color3.fromRGB(255, 240, 220), 0.18)
	task.delay(data.Callout and 2.2 or 1.5, function()
		tween(scale, 0.2, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.2, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.2, { Transparency = 1 })
			end
		end
		task.wait(0.22)
		holder:Destroy()
	end)
end

-- You went down: who did it and how the fight went
function HUD.ShowRecap(data)
	if recapPanel then
		recapPanel:Destroy()
	end
	HUD.ComboBreak()
	recapPanel = make("Frame", {
		Name = "Recap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 300),
		BackgroundColor3 = Color3.fromRGB(16, 16, 26),
		BackgroundTransparency = 0.08,
		ZIndex = 45,
		Parent = gui,
	}, { stroke(4), corner(10) })
	local panel = recapPanel
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 50,
		TextColor3 = Color3.fromRGB(255, 80, 70),
		Text = "KNOCKED OUT",
		ZIndex = 46,
		Parent = panel,
	}, { textStroke(3) })
	local byLine
	if data.Killer then
		local quirkName = quirkLabel(data.KillerQuirk)
		byLine = "by " .. data.Killer .. (quirkName and ("  (" .. quirkName .. ")") or "")
		if data.KillerHealth and data.KillerMaxHealth then
			byLine ..= string.format("  —  they had %d / %d HP left", data.KillerHealth, data.KillerMaxHealth)
		end
	else
		byLine = "no one gets the credit this time"
	end
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 222, 240),
		Text = byLine,
		ZIndex = 46,
		Parent = panel,
	})
	local grid = make("Frame", {
		Position = UDim2.fromOffset(16, 96),
		Size = UDim2.new(1, -32, 0, 150),
		BackgroundTransparency = 1,
		ZIndex = 46,
		Parent = panel,
	}, {
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 32), CellPadding = UDim2.fromOffset(12, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local t = math.floor(data.Time or 0)
	local rows = {
		{ "DAMAGE DEALT", tostring(data.Dealt or 0) },
		{ "DAMAGE TAKEN", tostring(data.Taken or 0) },
		{ "HITS LANDED", tostring(data.Hits or 0) },
		{ "BIGGEST HIT", tostring(data.BiggestHit or 0) },
		{ "KOs THIS LIFE", tostring(data.KOs or 0) },
		{ "PARRIES / BLOCKS", string.format("%d / %d", data.Parries or 0, data.Blocked or 0) },
		{ "SURVIVED", string.format("%d:%02d", t // 60, t % 60) },
		{ "STREAK LOST", tostring(data.StreakEnded or 0) },
	}
	for i, row in rows do
		local cell = make("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(34, 34, 52),
			ZIndex = 46,
			Parent = grid,
		}, { corner(5) })
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.62, -8, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(170, 174, 200),
			Text = row[1],
			ZIndex = 47,
			Parent = cell,
		})
		make("TextLabel", {
			Position = UDim2.fromScale(0.62, 0),
			Size = UDim2.new(0.38, -8, 1, 0),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.new(1, 1, 1),
			Text = row[2],
			ZIndex = 47,
			Parent = cell,
		})
	end
	make("TextLabel", {
		Position = UDim2.new(0, 12, 1, -42),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = string.format("TOTAL KILLS %d   ·   BEST STREAK %d", data.TotalKOs or 0, data.BestStreak or 0),
		ZIndex = 46,
		Parent = panel,
	})
	local countdown = make("TextLabel", {
		Position = UDim2.new(0, 12, 1, -22),
		Size = UDim2.new(1, -24, 0, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(150, 154, 180),
		Text = "",
		ZIndex = 46,
		Parent = panel,
	})
	local scale = make("UIScale", { Scale = 0.7, Parent = panel })
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	local shown = (Config.Fights and Config.Fights.RecapTime) or 5
	task.spawn(function()
		local t0 = os.clock()
		while panel.Parent and os.clock() - t0 < shown do
			countdown.Text = string.format("back in the fight in %d...", math.ceil(shown - (os.clock() - t0)))
			task.wait(0.1)
		end
		if panel.Parent then
			tween(scale, 0.18, { Scale = 0.8 })
			for _, d in panel:GetDescendants() do
				if d:IsA("TextLabel") then
					tween(d, 0.18, { TextTransparency = 1 })
				elseif d:IsA("Frame") then
					tween(d, 0.18, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					tween(d, 0.18, { Transparency = 1 })
				end
			end
			tween(panel, 0.18, { BackgroundTransparency = 1 })
			task.wait(0.2)
			panel:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- DEV ACCESS panel (testers hand dev characters to people in the server)
-- + small notices
---------------------------------------------------------------------------

local devPanel, devList
local devCallbacks = {}

-- onGrant(userId, on) for one player; onGrantAll(on) for everyone
function HUD.BuildDevPanel(onGrant, onGrantAll)
	devCallbacks = { Grant = onGrant, All = onGrantAll }
	if devPanel then
		return
	end
	devPanel = make("Frame", {
		Name = "DevAccess",
		Position = UDim2.new(0, 22 + TEST_W, 0, 108),
		Size = UDim2.fromOffset(300, 340),
		BackgroundColor3 = Color3.fromRGB(24, 24, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { stroke(3), corner(8) })
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "DEV ACCESS",
		ZIndex = 21,
		Parent = devPanel,
	}, { textStroke(1.5) })
	make("TextLabel", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(190, 194, 220),
		Text = "Let players in this server use DEV characters",
		ZIndex = 21,
		Parent = devPanel,
	})
	local function allButton(text, x, color, on)
		local b = make("TextButton", {
			Position = UDim2.new(x, x == 0 and 10 or 5, 0, 50),
			Size = UDim2.new(0.5, -15, 0, 28),
			BackgroundColor3 = color,
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			Text = text,
			ZIndex = 22,
			Parent = devPanel,
		}, { corner(5), stroke(1.5) })
		b.MouseButton1Click:Connect(function()
			if devCallbacks.All then
				devCallbacks.All(on)
			end
		end)
	end
	allButton("GRANT EVERYONE", 0, Color3.fromRGB(46, 150, 80), true)
	allButton("REVOKE ALL", 0.5, Color3.fromRGB(170, 60, 60), false)
	devList = make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 86),
		Size = UDim2.new(1, -20, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 21,
		Parent = devPanel,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

-- rows: { { UserId, Name, Status = "tester" | "granted" | "none" } }
function HUD.RefreshDevPanel(rows)
	if not devList then
		return
	end
	for _, child in devList:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #rows == 0 then
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(170, 174, 200),
			Text = "No one else is in this server yet",
			ZIndex = 22,
			Parent = devList,
		})
		return
	end
	for i, row in rows do
		local frame = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 32),
			BackgroundColor3 = Color3.fromRGB(40, 42, 60),
			ZIndex = 22,
			Parent = devList,
		}, { corner(5) })
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -110, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.new(1, 1, 1),
			Text = row.Name,
			ZIndex = 23,
			Parent = frame,
		})
		local tester = row.Status == "tester"
		local granted = row.Status == "granted"
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(92, 24),
			BackgroundColor3 = tester and Color3.fromRGB(80, 80, 96) or granted and Color3.fromRGB(170, 60, 60) or Color3.fromRGB(46, 150, 80),
			AutoButtonColor = not tester,
			Font = UI_FONT,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			Text = tester and "TESTER" or granted and "REVOKE" or "GRANT",
			ZIndex = 23,
			Parent = frame,
		}, { corner(4) })
		if not tester then
			button.MouseButton1Click:Connect(function()
				if devCallbacks.Grant then
					devCallbacks.Grant(row.UserId, not granted)
				end
			end)
		end
	end
end

function HUD.ToggleDevPanel(force)
	if not devPanel then
		return
	end
	if force ~= nil then
		devPanel.Visible = force
	else
		devPanel.Visible = not devPanel.Visible
	end
	return devPanel.Visible
end

-- Test menu: pick a kind of training dummy to spawn in front of you.
-- kinds = Config.DummyKinds; onSpawn(kindId); onClear() removes the spawned ones
local dummyPanel
function HUD.BuildDummyPanel(kinds, onSpawn, onClear)
	if dummyPanel then
		return
	end
	dummyPanel = make("Frame", {
		Name = "DummySpawner",
		Position = UDim2.new(0, 22 + TEST_W, 0, 108),
		Size = UDim2.fromOffset(470, 88 + math.ceil(#kinds / 2) * 50), -- (two columns)
		BackgroundColor3 = Color3.fromRGB(24, 24, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { stroke(3), corner(8) })
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "SPAWN DUMMIES",
		ZIndex = 21,
		Parent = dummyPanel,
	}, { textStroke(1.5) })
	make("TextLabel", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 16),
		BackgroundTransparency = 1,
		Font = UI_FONT,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(190, 194, 220),
		Text = "Each one appears 12 studs in front of you",
		ZIndex = 21,
		Parent = dummyPanel,
	})
	for i, kind in kinds do
		local button = make("TextButton", {
			Name = kind.Id,
			Position = UDim2.new((i - 1) % 2 * 0.5, (i - 1) % 2 == 0 and 10 or 4, 0, 48 + math.floor((i - 1) / 2) * 50),
			Size = UDim2.new(0.5, -14, 0, 44),
			BackgroundColor3 = Color3.fromRGB(44, 46, 64),
			AutoButtonColor = true,
			Text = "",
			ZIndex = 22,
			Parent = dummyPanel,
		}, { corner(6), stroke(1.5) })
		make("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(0, 6, 1, -12),
			BackgroundColor3 = kind.Color or Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = button,
		}, { corner(3) })
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 3),
			Size = UDim2.new(1, -26, 0, 20),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = kind.Label or kind.Id,
			ZIndex = 23,
			Parent = button,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 22),
			Size = UDim2.new(1, -26, 0, 18),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.fromRGB(180, 184, 210),
			Text = kind.Info or "",
			ZIndex = 23,
			Parent = button,
		})
		button.MouseButton1Click:Connect(function()
			onSpawn(kind.Id)
			button.BackgroundColor3 = Color3.fromRGB(255, 212, 64)
			tween(button, 0.35, { BackgroundColor3 = Color3.fromRGB(44, 46, 64) })
		end)
	end
	local clear = make("TextButton", {
		Position = UDim2.new(0, 10, 1, -36),
		Size = UDim2.new(1, -20, 0, 28),
		BackgroundColor3 = Color3.fromRGB(170, 60, 60),
		Font = UI_FONT,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "CLEAR SPAWNED DUMMIES",
		ZIndex = 22,
		Parent = dummyPanel,
	}, { corner(5), stroke(1.5) })
	clear.MouseButton1Click:Connect(onClear)
end

function HUD.ToggleDummyPanel(force)
	if not dummyPanel then
		return
	end
	if force ~= nil then
		dummyPanel.Visible = force
	else
		dummyPanel.Visible = not dummyPanel.Visible
	end
	return dummyPanel.Visible
end

-- a short message across the top of the screen
function HUD.Notice(text, color)
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 30),
		BackgroundColor3 = Color3.fromRGB(16, 16, 24),
		BackgroundTransparency = 0.15,
		Font = UI_FONT,
		TextSize = 15,
		TextColor3 = color or Color3.new(1, 1, 1),
		Text = text,
		ZIndex = 60,
		Parent = gui,
	}, { corner(6), stroke(2) })
	task.delay(4, function()
		tween(label, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
		local st = label:FindFirstChildOfClass("UIStroke")
		if st then
			tween(st, 0.4, { Transparency = 1 })
		end
		task.wait(0.42)
		label:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Cinematic letterbox + title card
---------------------------------------------------------------------------

local cinemaGui, barTop, barBottom, cineTitle, cineSub, cineStripe
local letterboxToken = 0

function HUD.Letterbox(on, title, subtitle, color)
	letterboxToken += 1
	local token = letterboxToken
	if not cinemaGui then
		cinemaGui = make("ScreenGui", {
			Name = "QuirkCinema",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 5,
			Parent = gui.Parent,
		})
		barTop = make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = cinemaGui,
		})
		barBottom = make("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = cinemaGui,
		})
		cineStripe = make("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = barBottom,
		})
		cineTitle = make("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 40, 0.45, 0),
			Size = UDim2.new(0.7, 0, 0.55, 0),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			Parent = barBottom,
		}, { textStroke(2) })
		cineSub = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -40, 0.5, 0),
			Size = UDim2.new(0.35, 0, 0.3, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Text = "",
			Parent = barBottom,
		})
	end
	if on then
		gui.Enabled = false -- the regular HUD steps aside for the shot
		cineTitle.Text = title or ""
		cineSub.Text = subtitle or ""
		cineStripe.BackgroundColor3 = color or Color3.new(1, 1, 1)
		cineTitle.TextColor3 = Color3.new(1, 1, 1):Lerp(color or Color3.new(1, 1, 1), 0.25)
		cineTitle.Position = UDim2.new(0, -200, 0.45, 0)
		cineTitle.TextTransparency = 0
		cineSub.TextTransparency = 0
		tween(barTop, 0.2, { Position = UDim2.fromScale(0, 0.12) })
		tween(barBottom, 0.2, { Position = UDim2.fromScale(0, 0.88) })
		tween(cineTitle, 0.3, { Position = UDim2.new(0, 40, 0.45, 0) }, Enum.EasingStyle.Back)
	else
		tween(barTop, 0.25, { Position = UDim2.fromScale(0, 0) })
		tween(barBottom, 0.25, { Position = UDim2.fromScale(0, 1) })
		tween(cineTitle, 0.2, { TextTransparency = 1 })
		tween(cineSub, 0.2, { TextTransparency = 1 })
		task.delay(0.1, function()
			if letterboxToken == token then
				gui.Enabled = true
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Bucks, the item bar, the shop, the sniper scope, and controller labels
---------------------------------------------------------------------------

local funPanel

do
	local wallet, walletAmount, shopButton
	local itemBar
	local itemSlots = {}
	local shopPanel, shopWallet, shopGrid, shopHint, quirkButton
	local cards = {} -- [itemId] = { Button, Price, Have }
	local scopeGui, scopeCircle, scopeFrames
	local shopCallbacks = {}
	local inputMode = "Keyboard"
	local selectedItem = 1
	local bucks = 0
	-- (round 58) the emotes side of the shop
	local emoteTab, emoteGrid, emoteSlotRow = nil, nil, nil
	local tabButtons, emoteCards, emoteSlots = {}, {}, {}
	local ownedEmotes, wheelEmotes, pickedSlot = {}, {}, nil
	local SH = {} -- (round 63) the JJS-style shop's pieces (one local: the chunk is near its limit)


	local function currency()
		return (Config.Economy and Config.Economy.Currency) or "Bucks"
	end

	-- cbs: OnBuy(itemId), OnUse(itemId), OnToggle(open), OnQuirks()
	function HUD.BuildShop(cbs)
		shopCallbacks = cbs or {}
		if wallet then
			return
		end
		-- wallet (top-right, beside the health bar)
		wallet = make("Frame", {
			Name = "Wallet",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -178, 0, 58),
			Size = UDim2.fromOffset(132, 42),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = gui,
		}, { edge(), corner(3) })
		make("Frame", {
			Name = "Strip",
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Color3.fromRGB(96, 200, 110),
			BorderSizePixel = 0,
			Parent = wallet,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = "💵",
			ZIndex = 2,
			Parent = wallet,
		})
		walletAmount = make("TextLabel", {
			Position = UDim2.fromOffset(40, 3),
			Size = UDim2.new(1, -44, 0, 24),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "0",
			ZIndex = 2,
			Parent = wallet,
		}, { textStroke(2) })
		make("TextLabel", {
			Position = UDim2.fromOffset(40, 26),
			Size = UDim2.new(1, -44, 0, 13),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(220, 255, 220),
			Text = string.upper(currency()),
			ZIndex = 2,
			Parent = wallet,
		}, { textStroke(1) })
		shopButton = make("TextButton", {
			Name = "ShopButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -178, 0, 104),
			Size = UDim2.fromOffset(132, 24),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Font = UI_FONT,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = "SHOP [H]",
			AutoButtonColor = true,
			Parent = gui,
		}, { make("UIStroke", { Thickness = 1, Color = Color3.fromRGB(255, 212, 64), Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), corner(3) })
		shopButton.MouseButton1Click:Connect(function()
			HUD.ToggleShop()
		end)

		-- item bar (left side, middle): what's in your bag
		itemBar = make("Frame", {
			Name = "Items",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(64, 4 * 64 + 3 * 8),
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local maxKinds = (Config.Economy and Config.Economy.MaxKinds) or 4
		for i = 1, maxKinds do
			local button = make("TextButton", {
				Name = "Item" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(64, 64),
				BackgroundColor3 = Color3.fromRGB(28, 28, 38),
				BackgroundTransparency = 0.1,
				AutoButtonColor = true,
				Text = "",
				Visible = false,
				Parent = itemBar,
			}, { stroke(2.5), corner(8) })
			local icon = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.62, 0.62),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = "",
				ZIndex = 2,
				Parent = button,
			})
			local key = make("TextLabel", {
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.fromOffset(20, 18),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Font = UI_FONT,
				TextSize = 12,
				TextColor3 = Color3.new(0, 0, 0),
				Text = tostring(i + 4),
				ZIndex = 3,
				Parent = button,
			}, { corner(4) })
			local count = make("TextLabel", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -2),
				Size = UDim2.fromOffset(34, 18),
				BackgroundTransparency = 1,
				Font = COMIC_FONT,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				ZIndex = 3,
				Parent = button,
			}, { textStroke(1.5) })
			local slot = { Button = button, Icon = icon, Key = key, Count = count, Id = nil }
			itemSlots[i] = slot
			button.MouseButton1Click:Connect(function()
				if slot.Id and shopCallbacks.OnUse then
					shopCallbacks.OnUse(slot.Id)
				end
			end)
		end

		-- (round 63) THE SHOP, the way Jujutsu Shenanigans does it: a light
		-- panel, tabs across the top (SHOP / EMOTES / REWARDS) with the one
		-- you're on underlined, wide banners each with its price - EMOTES (a
		-- random one you don't have yet: 1x / 2x / 5x / 10x, ten at once and
		-- you pick the tenth), SODA DELIVERY and ITEM DELIVERY (a Support
		-- Course drop pod brings it to you) - then everything else by name; the shopkeeper at his desk
		-- in the corner (poke him).
		SH.font = Enum.Font.PatrickHand
		SH.ink = Color3.fromRGB(24, 24, 28)
		SH.mult = 1
		shopPanel = make("Frame", {
			Name = "Shop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.8),
			BackgroundColor3 = Color3.fromRGB(236, 236, 240),
			BackgroundTransparency = 0.12,
			Visible = false,
			ZIndex = 50,
			Parent = gui,
		}, {
			make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			corner(3),
			make("UISizeConstraint", { MaxSize = Vector2.new(900, 540) }),
		})
		SH.scale = make("UIScale", { Parent = shopPanel })
		-- the tab bar, the wallet, the X
		SH.bar = make("Frame", {
			Name = "Tabs",
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Color3.fromRGB(250, 250, 252),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 51,
			Parent = shopPanel,
		})
		SH.underline = make("Frame", {
			Name = "Underline",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(0.22, 0, 0, 4),
			BackgroundColor3 = Color3.fromRGB(78, 226, 240),
			BorderSizePixel = 0,
			ZIndex = 53,
			Parent = SH.bar,
		})
		for i, tab in { { "Shop", "Shop" }, { "Emotes", "Emotes" }, { "Rewards", "Rewards" } } do
			local b = make("TextButton", {
				Name = tab[1] .. "Tab",
				Position = UDim2.new((i - 1) * 0.22, 0, 0, 0),
				Size = UDim2.new(0.22, 0, 1, -4),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextSize = 28,
				TextColor3 = SH.ink,
				Text = tab[2],
				ZIndex = 52,
				Parent = SH.bar,
			})
			tabButtons[tab[1]] = b
			b.MouseButton1Click:Connect(function()
				HUD.ShopTab(tab[1])
			end)
		end
		shopWallet = make("TextLabel", {
			Name = "Wallet",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -54, 0.5, -1),
			Size = UDim2.fromOffset(140, 34),
			BackgroundColor3 = Color3.fromRGB(46, 46, 52),
			BackgroundTransparency = 0.12,
			Font = SH.font,
			TextSize = 26,
			TextColor3 = Color3.fromRGB(150, 255, 150),
			Text = "💵 0",
			ZIndex = 53,
			Parent = SH.bar,
		}, { corner(8) })
		local close = make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, -1),
			Size = UDim2.fromOffset(38, 34),
			BackgroundColor3 = Color3.fromRGB(46, 46, 52),
			BackgroundTransparency = 0.12,
			Font = SH.font,
			TextSize = 26,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "X",
			ZIndex = 53,
			Parent = SH.bar,
		}, { corner(8) })
		close.MouseButton1Click:Connect(function()
			HUD.ToggleShop(false)
		end)
		shopHint = make("TextLabel", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -4),
			Size = UDim2.new(0.7, -20, 0, 20),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(70, 70, 80),
			Text = "",
			ZIndex = 51,
			Parent = shopPanel,
		})
		-- the right-hand column: the way to the rest, and the shopkeeper
		quirkButton = make("TextButton", {
			Name = "QuirkButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 56),
			Size = UDim2.new(0.25, -12, 0, 34),
			BackgroundColor3 = Color3.fromRGB(52, 78, 160),
			Font = SH.font,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "CHANGE HERO",
			ZIndex = 52,
			Parent = shopPanel,
		}, { corner(6) })
		quirkButton.MouseButton1Click:Connect(function()
			HUD.ToggleShop(false)
			HUD.ShowMenu(true)
			if shopCallbacks.OnQuirks then
				shopCallbacks.OnQuirks()
			end
		end)
		for i, b in { { "SETTINGS", "Settings" }, { "TOP HEROES", "Board" } } do
			local btn = make("TextButton", {
				Name = b[2] .. "Button",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12 - (2 - i) * 0, 0, 56 + 40 * i),
				Size = UDim2.new(0.25, -12, 0, 32),
				BackgroundColor3 = Color3.fromRGB(70, 72, 86),
				Font = SH.font,
				TextSize = 20,
				TextColor3 = Color3.new(1, 1, 1),
				Text = b[1],
				ZIndex = 52,
				Parent = shopPanel,
			}, { corner(6) })
			btn.MouseButton1Click:Connect(function()
				HUD.ToggleShop(false)
				if b[2] == "Settings" then
					HUD.ToggleSettings(true)
				else
					HUD.ToggleBoard(true)
				end
			end)
		end
		HUD.BuildShopkeeper()

		-- the tabs' pages (left of the column)
		local function page(name)
			return make("Frame", {
				Name = name,
				Position = UDim2.fromOffset(12, 54),
				Size = UDim2.new(0.75, -18, 1, -82),
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = 51,
				Parent = shopPanel,
			})
		end
		local shopPage = page("ShopPage")
		shopGrid = make("ScrollingFrame", {
			Name = "Banners",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 51,
			Parent = shopPage,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
		})
		SH.shopPage = shopPage
		-- a wide banner: manga-ish art behind, the name, a line about it
		local WHITE = Color3.new(1, 1, 1)
		local function banner(name, order, title, info, emoji, tint, height)
			local b = make("TextButton", {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, height or 116),
				BackgroundColor3 = WHITE,
				AutoButtonColor = true,
				ClipsDescendants = true,
				Text = "",
				ZIndex = 52,
				Parent = shopGrid,
			}, {
				make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(46, 46, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				corner(2),
				gradient(tint:Lerp(WHITE, 0.8), tint:Lerp(WHITE, 0.3), 12),
			})
			-- (the art: slashes of ink and the big picture, faded)
			for k = 1, 4 do
				make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.42 + k * 0.13, 0.5),
					Size = UDim2.new(0, 6 + k * 5, 2.4, 0),
					Rotation = 28,
					BackgroundColor3 = tint:Lerp(Color3.new(0, 0, 0), 0.4),
					BackgroundTransparency = 0.78,
					BorderSizePixel = 0,
					ZIndex = 52,
					Parent = b,
				})
			end
			make("TextLabel", {
				Name = "Art",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.52),
				Size = UDim2.fromScale(0.3, 1.25),
				Rotation = -9,
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = emoji,
				TextTransparency = 0.3,
				ZIndex = 52,
				Parent = b,
			})
			make("TextLabel", {
				Name = "Title",
				Position = UDim2.fromOffset(12, 2),
				Size = UDim2.new(0.75, 0, 0, height and height * 0.42 or 46),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SH.ink,
				Text = title,
				ZIndex = 53,
				Parent = b,
			}, { make("UITextSizeConstraint", { MaxTextSize = 42 }) })
			make("TextLabel", {
				Name = "Info",
				Position = UDim2.new(0, 14, 0, height and height * 0.44 or 48),
				Size = UDim2.new(0.62, 0, 0, height and height * 0.4 or 44),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = SH.ink,
				Text = info,
				ZIndex = 53,
				Parent = b,
			}, { make("UITextSizeConstraint", { MaxTextSize = 24 }) })
			return b
		end
		local function pill(parent, text, width)
			return make("TextLabel", {
				Name = "Price",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -10),
				Size = UDim2.fromOffset(width or 112, 42),
				BackgroundColor3 = Color3.fromRGB(46, 46, 52),
				BackgroundTransparency = 0.12,
				Font = SH.font,
				TextSize = 32,
				TextColor3 = Color3.new(1, 1, 1),
				Text = text,
				ZIndex = 54,
				Parent = parent,
			}, { corner(8) })
		end
		local ES = Config.EmoteShop or {}
		-- EMOTES: a random one (the odds by rarity on it), 1x / 2x / 5x / 10x
		-- (round 72: Config.EmoteShop.Robux) set up for Robux too: a taller
		-- banner, the Robux button over the Bucks one
		local robuxOn = false
		for _, spec in ES.Robux or {} do
			if type(spec) == "table" and (tonumber(spec.Product) or 0) > 0 then
				robuxOn = true
			end
		end
		SH.roll = banner("RollEmotes", 1, "EMOTES", "Buy a random emote to taunt players and have fun!", "🕺", Color3.fromRGB(240, 120, 170), robuxOn and 156 or nil)
		SH.rollPrice = pill(SH.roll, "💵 " .. (ES.RollPrice or 25), 124)
		SH.robuxPrices = SH.robuxPrices or {}
		SH.rollRobux = make("TextButton", {
			Name = "Robux",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -58),
			Size = UDim2.fromOffset(124, 42),
			BackgroundColor3 = Color3.fromRGB(0, 150, 96),
			AutoButtonColor = true,
			Font = SH.font,
			TextSize = 30,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "R$",
			Visible = false,
			ZIndex = 56,
			Parent = SH.roll,
		}, { corner(8), make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(0, 90, 58), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		SH.rollRobux.MouseButton1Click:Connect(function()
			if shopCallbacks.OnRobuxRoll then
				shopCallbacks.OnRobuxRoll(SH.mult)
			end
		end)
		SH.multChip = make("TextButton", {
			Name = "Multiplier",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(62, 40),
			BackgroundColor3 = Color3.fromRGB(46, 46, 52),
			BackgroundTransparency = 0.12,
			Font = SH.font,
			TextSize = 32,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "1x",
			ZIndex = 55,
			Parent = SH.roll,
		}, { corner(8) })
		local odds = {}
		local total = 0
		for _, r in ES.Rarities or {} do
			total += r.Weight or 0
		end
		for _, r in ES.Rarities or {} do
			table.insert(odds, string.format('<font color="#%s">%s %d%%</font>', SH.hex(r.Color), r.Name, math.floor((r.Weight or 0) / math.max(total, 1) * 100 + 0.5)))
		end
		SH.odds = make("TextLabel", {
			Name = "Odds",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -6),
			Size = UDim2.new(0.66, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 17,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SH.ink,
			TextStrokeTransparency = 0.6,
			Text = table.concat(odds, "  ·  "),
			ZIndex = 54,
			Parent = SH.roll,
		})
		SH.multChip.MouseButton1Click:Connect(function()
			local list = ES.Multipliers or { 1, 2, 5, 10 }
			local at = table.find(list, SH.mult) or 1
			SH.mult = list[at % #list + 1]
			HUD.RefreshShopPrices()
		end)
		SH.roll.MouseButton1Click:Connect(function()
			if shopCallbacks.OnRollEmotes then
				shopCallbacks.OnRollEmotes(SH.mult)
			end
		end)
		-- the deliveries: a drop pod brings it to you, wherever you are
		local DL = Config.Deliveries or {}
		for i, kind in { "Soda", "Item" } do
			local spec = DL[kind] or {}
			local b = banner("Deliver" .. kind, 1 + i, spec.Name or (string.upper(kind) .. " DELIVERY"), spec.Info or "", kind == "Soda" and "🥤" or "📦",
				kind == "Soda" and Color3.fromRGB(90, 190, 255) or Color3.fromRGB(250, 180, 70))
			SH["deliver" .. kind] = b
			SH["deliver" .. kind .. "Price"] = pill(b, "💵 " .. (spec.Price or 5))
			b.MouseButton1Click:Connect(function()
				if shopCallbacks.OnDelivery then
					shopCallbacks.OnDelivery(kind)
				end
			end)
		end
		make("TextLabel", {
			Name = "ByName",
			LayoutOrder = 10,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SH.ink,
			Text = "Everything else, by name:",
			ZIndex = 52,
			Parent = shopGrid,
		})
		for order, id in Config.ShopOrder or Config.ItemOrder do
			local item = Config.Items[id]
			local card = banner(id, 10 + order, item.Name .. ((item.Gives or 1) > 1 and (" x" .. item.Gives) or ""), item.Info or "", item.Icon or "?", item.Color, 76)
			local price = pill(card, "💵 " .. (item.Price or 5), 96)
			price.Size = UDim2.fromOffset(96, 36)
			price.TextSize = 26
			local have = make("TextLabel", {
				Name = "Have",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 6),
				Size = UDim2.fromOffset(80, 20),
				BackgroundColor3 = Color3.fromRGB(46, 46, 52),
				BackgroundTransparency = 0.3,
				Font = SH.font,
				TextSize = 18,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				Visible = false,
				ZIndex = 54,
				Parent = card,
			}, { corner(5) })
			cards[id] = { Button = card, Price = price, Have = have }
			card.MouseButton1Click:Connect(function()
				if shopCallbacks.OnBuy then
					shopCallbacks.OnBuy(id)
				end
			end)
		end

		-- EMOTES: the ones you've got (newest first, or A-Z; a search), and
		-- the four on your wheel
		emoteTab = page("EmoteShop")
		emoteSlotRow = make("Frame", {
			Name = "Wheel",
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			ZIndex = 52,
			Parent = emoteTab,
		}, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local slotsN = Config.EmoteSlots or 4
		for i = 1, slotsN do
			local slot = make("TextButton", {
				Name = "Slot" .. i,
				LayoutOrder = i,
				Size = UDim2.new(1 / slotsN, -8 * (slotsN - 1) / slotsN, 1, 0),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.15,
				AutoButtonColor = true,
				Text = "",
				ZIndex = 53,
				Parent = emoteSlotRow,
			}, {
				corner(4),
				make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(46, 46, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				make("UIStroke", { Name = "Ring", Thickness = 3, Color = Color3.fromRGB(78, 226, 240), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			make("TextLabel", {
				Position = UDim2.fromOffset(4, 3),
				Size = UDim2.fromOffset(18, 16),
				BackgroundColor3 = Color3.fromRGB(46, 46, 52),
				Font = SH.font,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
				Text = tostring(i),
				ZIndex = 55,
				Parent = slot,
			}, { corner(3) })
			local icon = make("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 24, 0.5, 0),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = "＋",
				TextColor3 = SH.ink,
				ZIndex = 54,
				Parent = slot,
			})
			local name = make("TextLabel", {
				Position = UDim2.new(0, 60, 0, 0),
				Size = UDim2.new(1, -64, 1, 0),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SH.ink,
				Text = "EMPTY",
				ZIndex = 54,
				Parent = slot,
			}, { make("UITextSizeConstraint", { MaxTextSize = 20 }) })
			emoteSlots[i] = { Button = slot, Icon = icon, Name = name }
			slot.MouseButton1Click:Connect(function()
				HUD.EmoteSlotClicked(i)
			end)
		end
		SH.tools = make("Frame", {
			Name = "Tools",
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			ZIndex = 52,
			Parent = emoteTab,
		})
		SH.count = make("TextLabel", {
			Name = "Count",
			Size = UDim2.new(0.3, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SH.ink,
			Text = "0 / 0",
			ZIndex = 53,
			Parent = SH.tools,
		})
		SH.sortNewest = true
		SH.sort = make("TextButton", {
			Name = "Sort",
			Position = UDim2.new(0.3, 0, 0, 0),
			Size = UDim2.new(0.18, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(46, 46, 52),
			BackgroundTransparency = 0.12,
			Font = SH.font,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "NEWEST ▾",
			ZIndex = 53,
			Parent = SH.tools,
		}, { corner(6) })
		SH.sort.MouseButton1Click:Connect(function()
			SH.sortNewest = not SH.sortNewest
			HUD.RefreshEmoteShop()
		end)
		SH.search = make("TextBox", {
			Name = "Search",
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.1,
			ClearTextOnFocus = false,
			Font = SH.font,
			TextSize = 22,
			TextColor3 = SH.ink,
			PlaceholderText = "Search emote name",
			PlaceholderColor3 = Color3.fromRGB(140, 140, 150),
			Text = "",
			ZIndex = 53,
			Parent = SH.tools,
		}, { corner(4), make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(46, 46, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		SH.search:GetPropertyChangedSignal("Text"):Connect(function()
			HUD.RefreshEmoteShop()
		end)
		SH.pickButton = make("TextButton", {
			Name = "FreePick",
			Position = UDim2.fromOffset(0, 98),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Color3.fromRGB(255, 206, 70),
			Font = SH.font,
			TextSize = 24,
			TextColor3 = SH.ink,
			Text = "🎁 PICK YOUR FREE EMOTE",
			Visible = false,
			ZIndex = 53,
			Parent = emoteTab,
		}, { corner(6) })
		SH.pickButton.MouseButton1Click:Connect(function()
			HUD.ShowEmotePick(true)
		end)
		emoteGrid = make("ScrollingFrame", {
			Name = "Emotes",
			Position = UDim2.fromOffset(0, 98),
			Size = UDim2.new(1, 0, 1, -98),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 52,
			Parent = emoteTab,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
		})
		SH.empty = make("TextLabel", {
			Name = "NoneYet",
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 24,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(80, 80, 90),
			Text = "No emotes yet - roll some in the SHOP tab!",
			LayoutOrder = 0,
			ZIndex = 53,
			Parent = emoteGrid,
		})
		for order, e in Config.Emotes or {} do
			local row = make("TextButton", {
				Name = "EmoteShop_" .. e.Id,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.15,
				AutoButtonColor = true,
				Text = "",
				Visible = false,
				ZIndex = 53,
				Parent = emoteGrid,
			}, { corner(3), make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(46, 46, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			make("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(32, 32),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = e.Icon or "★",
				ZIndex = 54,
				Parent = row,
			})
			make("TextLabel", {
				Position = UDim2.fromOffset(48, 0),
				Size = UDim2.new(0.45, 0, 1, 0),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextSize = 26,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SH.ink,
				Text = e.Name or e.Id,
				ZIndex = 54,
				Parent = row,
			})
			local rarity = HUD.EmoteRarity(e)
			make("TextLabel", {
				Name = "Rarity",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(96, 22),
				BackgroundColor3 = rarity.Color,
				Font = SH.font,
				TextSize = 18,
				TextColor3 = SH.ink,
				Text = rarity.Name,
				ZIndex = 54,
				Parent = row,
			}, { corner(5) })
			local pillLabel = make("TextLabel", {
				Name = "Pill",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.3, 0, 0, 30),
				BackgroundColor3 = Color3.fromRGB(46, 46, 52),
				Font = SH.font,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				ZIndex = 54,
				Parent = row,
			}, { corner(6), make("UITextSizeConstraint", { MaxTextSize = 20 }), make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }) })
			emoteCards[e.Id] = { Button = row, Pill = pillLabel }
			row.MouseButton1Click:Connect(function()
				HUD.EmoteCardClicked(e.Id)
			end)
		end

		-- REWARDS: codes from updates and events
		SH.rewards = page("RewardsPage")
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SH.ink,
			Text = "Redeem codes given from updates and events!",
			ZIndex = 52,
			Parent = SH.rewards,
		})
		SH.codeBox = make("TextBox", {
			Name = "Code",
			Position = UDim2.new(0.08, 0, 0, 54),
			Size = UDim2.new(0.56, 0, 0, 46),
			BackgroundColor3 = WHITE,
			ClearTextOnFocus = false,
			Font = SH.font,
			TextSize = 32,
			TextColor3 = SH.ink,
			PlaceholderText = "Code",
			PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
			Text = "",
			ZIndex = 53,
			Parent = SH.rewards,
		}, { make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(30, 30, 34), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		SH.redeem = make("TextButton", {
			Name = "Redeem",
			Position = UDim2.new(0.66, 0, 0, 54),
			Size = UDim2.new(0.22, 0, 0, 46),
			BackgroundColor3 = Color3.fromRGB(226, 226, 230),
			Font = SH.font,
			TextSize = 32,
			TextColor3 = SH.ink,
			Text = "Redeem",
			ZIndex = 53,
			Parent = SH.rewards,
		}, { make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(90, 90, 96), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		SH.codeResult = make("TextLabel", {
			Name = "Result",
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 26,
			TextColor3 = SH.ink,
			Text = "",
			ZIndex = 53,
			Parent = SH.rewards,
		})
		SH.redeem.MouseButton1Click:Connect(function()
			local code = SH.codeBox.Text:gsub("%s", "")
			if code ~= "" and shopCallbacks.OnRedeem then
				shopCallbacks.OnRedeem(code)
			end
		end)
		HUD.BuildEmoteReveal()

		-- the sniper scope: a round window with a crosshair, black everywhere else
		scopeGui = make("Frame", {
			Name = "Scope",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 25,
			Parent = gui,
		})
		scopeCircle = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 25,
			Parent = scopeGui,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 200 }) })
		for _, spec in { { UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 0.5) }, { UDim2.new(0, 2, 1, 0), UDim2.fromScale(0.5, 0) } } do
			make("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				Size = spec[1],
				Position = spec[2],
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 26,
				Parent = scopeCircle,
			})
		end
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(255, 40, 40),
			ZIndex = 27,
			Parent = scopeCircle,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		scopeFrames = {}
		for i = 1, 2 do
			scopeFrames[i] = make("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 25,
				Parent = scopeGui,
			})
		end
		HUD.SetBucks(bucks)
		HUD.SetInputMode(inputMode)
		HUD.ShopTab("Items")
	end

	-- fit the scope to the screen: a circle 90% of the height, bars either side
	local function layoutScope()
		local size = gui.AbsoluteSize
		local d = size.Y * 0.9
		scopeCircle.Size = UDim2.fromOffset(d, d)
		local stroke = scopeCircle:FindFirstChildOfClass("UIStroke")
		stroke.Thickness = d * 0.3
		local side = math.max((size.X - d) / 2 - d * 0.28, 0)
		scopeFrames[1].Size = UDim2.new(0, side + 2, 1, 0)
		scopeFrames[1].Position = UDim2.fromScale(0, 0)
		scopeFrames[2].Size = UDim2.new(0, side + 2, 1, 0)
		scopeFrames[2].Position = UDim2.new(1, -side - 2, 0, 0)
	end

	function HUD.SetScope(on)
		if not scopeGui then
			return
		end
		scopeGui.Visible = on == true
		if on then
			layoutScope()
		end
	end

	function HUD.SetBucks(amount, gained)
		bucks = amount or 0
		if not walletAmount then
			return
		end
		walletAmount.Text = tostring(bucks)
		shopWallet.Text = "💵 " .. tostring(bucks)
		for id, card in cards do
			local item = Config.Items[id]
			card.Price.TextColor3 = bucks >= (item.Price or 5) and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 140)
		end
		if HUD.RefreshEmoteShop then
			HUD.RefreshEmoteShop()
			HUD.RefreshShopPrices()
		end
		if gained and gained > 0 then
			local pop = make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -178, 0, 58),
				Size = UDim2.fromOffset(132, 30),
				BackgroundTransparency = 1,
				Font = COMIC_FONT,
				TextSize = 28,
				TextColor3 = Color3.fromRGB(140, 255, 140),
				Text = "+" .. tostring(gained),
				ZIndex = 5,
				Parent = gui,
			}, { textStroke(2) })
			tween(pop, 0.9, { Position = UDim2.new(1, -178, 0, 128), TextTransparency = 1 })
			task.delay(0.95, function()
				pop:Destroy()
			end)
			local sc = wallet:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = wallet })
			sc.Scale = 1.25
			tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end

	-- list: { { Id, Count } } in bag order; selected: the controller's pick
	function HUD.SetItems(list, selected)
		selectedItem = selected or 1
		for i, slot in itemSlots do
			local entry = list[i]
			slot.Id = entry and entry.Id or nil
			slot.Button.Visible = entry ~= nil
			if entry then
				local item = Config.Items[entry.Id]
				slot.Icon.Text = item and item.Icon or "?"
				slot.Count.Text = entry.Count > 1 and ("x" .. entry.Count) or ""
				slot.Button.BackgroundColor3 = item and item.Color:Lerp(Color3.new(0, 0, 0), 0.6) or Color3.fromRGB(28, 28, 38)
			end
			local s = slot.Button:FindFirstChildOfClass("UIStroke")
			local picked = inputMode == "Gamepad" and i == selectedItem and entry ~= nil
			if s then
				s.Color = picked and Color3.fromRGB(255, 212, 64) or Color3.new(0, 0, 0)
				s.Thickness = picked and 3.5 or 2.5
			end
			slot.Key.Text = inputMode == "Gamepad" and (picked and "▶" or "") or tostring(i + 4)
			slot.Key.Visible = slot.Key.Text ~= "" and inputMode ~= "Touch"
		end
		for id, card in cards do
			local have = 0
			for _, entry in list do
				if entry.Id == id then
					have = entry.Count
				end
			end
			card.Have.Visible = have > 0
			card.Have.Text = "HAVE " .. have
		end
	end

	-- (round 63) small helpers for the shop
	function SH.hex(c)
		return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	-- an emote's rarity (Config.EmoteShop.Rarities): { Id, Name, Weight, Color }
	function HUD.EmoteRarity(e)
		local ES = Config.EmoteShop or {}
		for _, r in ES.Rarities or {} do
			if r.Id == (e and e.Rarity or "Common") then
				return r
			end
		end
		return (ES.Rarities or {})[1] or { Id = "Common", Name = "COMMON", Weight = 1, Color = Color3.fromRGB(190, 196, 210) }
	end

	-- THE SHOPKEEPER (bottom-right of the shop): sat at his desk in a U.A.
	-- tracksuit and cap, an All Might plushie beside him and the till; a word
	-- bubble over him. Poke him and he'll let you know about it.
	SH.lines = {
		Greet = { "What's up?", "Looking for something, hero?", "Welcome to the Hero Shop!", "Plus Ultra prices today!" },
		Poke = { "OW!", "Hey!!", "That hurts, you know.", "I'm working here!", "Do you mind?!", "...ow." },
		Roll = { "Nice pull!", "Ooh, that's a good one.", "Go on, try it out!", "Put it on your wheel!" },
		Legend = "NO WAY. A LEGENDARY?!",
		Thanks = { "Here you go!", "Pleasure doing business.", "Thanks, hero!" },
	}
	function HUD.BuildShopkeeper()
		if SH.keeper or not shopPanel then
			return
		end
		local vp = make("ViewportFrame", {
			Name = "Shopkeeper",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -6),
			Size = UDim2.new(0.25, -4, 0.5, 0),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(165, 165, 176),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-0.6, -1, 0.5),
			ZIndex = 52,
			Parent = shopPanel,
		})
		SH.keeper = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 32
		cam.CFrame = CFrame.lookAt(Vector3.new(2.6, 4.6, -9.5), Vector3.new(0, 2.5, -0.4))
		cam.Parent = vp
		vp.CurrentCamera = cam
		local world = Instance.new("WorldModel")
		world.Parent = vp
		local function block(name, size, cf, color, material)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = world
			return p
		end
		local SKIN, SUIT, WOOD = Color3.fromRGB(234, 190, 150), Color3.fromRGB(44, 74, 168), Color3.fromRGB(150, 104, 66)
		-- the desk, the till
		block("Desk", Vector3.new(5, 0.3, 2.2), CFrame.new(0, 2.25, -1.3), WOOD, Enum.Material.Wood)
		block("DeskFront", Vector3.new(5, 2.25, 0.2), CFrame.new(0, 1.1, -2.3), WOOD:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
		block("Till", Vector3.new(1.1, 0.7, 0.9), CFrame.new(-1.8, 2.75, -1.3) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(70, 72, 84))
		block("TillScreen", Vector3.new(0.9, 0.35, 0.08), CFrame.new(-1.8, 3.15, -1.72) * CFrame.Angles(0.35, 0.3, 0), Color3.fromRGB(90, 230, 120), Enum.Material.Neon)
		-- him: sat behind it, leaning on it
		local torso = block("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.3, 0.1) * CFrame.Angles(math.rad(-10), 0, 0), SUIT)
		local stripe = block("Stripe", Vector3.new(0.3, 2.02, 1.02), torso.CFrame, Color3.new(1, 1, 1))
		stripe.CFrame = torso.CFrame * CFrame.new(0.72, 0, 0)
		local head = block("Head", Vector3.new(2, 1, 1), torso.CFrame * CFrame.new(0, 1.5, 0), SKIN)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = head
		local faceDecal = Instance.new("Decal")
		faceDecal.Texture = "rbxasset://textures/face.png"
		faceDecal.Face = Enum.NormalId.Front
		faceDecal.Parent = head
		local cap = block("Cap", Vector3.new(1.35, 0.4, 1.35), head.CFrame * CFrame.new(0, 0.62, 0), Color3.fromRGB(226, 60, 60))
		block("Brim", Vector3.new(1.3, 0.12, 0.7), cap.CFrame * CFrame.new(0, -0.16, -0.85), Color3.fromRGB(200, 50, 50))
		local armL = block("LeftArm", Vector3.new(1, 2, 1), torso.CFrame * CFrame.new(-1.5, 0.1, -0.7) * CFrame.Angles(math.rad(-80), 0, 0), SUIT)
		local armR = block("RightArm", Vector3.new(1, 2, 1), torso.CFrame * CFrame.new(1.5, 0.35, -0.55) * CFrame.Angles(math.rad(-155), 0, math.rad(-8)), SUIT)
		-- the All Might plushie on the desk
		local plush = block("PlushBody", Vector3.new(0.75, 0.8, 0.5), CFrame.new(1.75, 2.8, -1.45) * CFrame.Angles(0, -0.4, 0), Color3.fromRGB(46, 84, 190))
		local ph = block("PlushHead", Vector3.new(0.62, 0.6, 0.55), plush.CFrame * CFrame.new(0, 0.66, 0), SKIN)
		for side = -1, 1, 2 do
			local tuft = block("PlushHair", Vector3.new(0.12, 0.62, 0.12), ph.CFrame * CFrame.new(0.14 * side, 0.52, -0.05) * CFrame.Angles(0, 0, math.rad(-24 * side)), Color3.fromRGB(255, 220, 70))
			tuft.Material = Enum.Material.SmoothPlastic
		end
		SH.parts = { Torso = torso, Head = head, Cap = cap, LeftArm = armL, RightArm = armR, Stripe = stripe }
		SH.rest = {}
		for k, p in SH.parts do
			SH.rest[k] = p.CFrame
		end
		-- (a click anywhere on him)
		local poke = make("TextButton", {
			Name = "Poke",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 53,
			Parent = vp,
		})
		poke.MouseButton1Click:Connect(function()
			HUD.PokeShopkeeper()
		end)
		SH.bubble = make("TextLabel", {
			Name = "Bubble",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 0.5, -6),
			Size = UDim2.new(0.23, -8, 0, 54),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Font = SH.font,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = SH.ink,
			Text = "What's up?",
			ZIndex = 54,
			Parent = shopPanel,
		}, { corner(10), make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }), make("UITextSizeConstraint", { MaxTextSize = 24 }) })
	end

	-- a word from the shopkeeper (a table of lines: one of them)
	function HUD.ShopkeeperSay(text, time)
		if not SH.bubble then
			return
		end
		if type(text) == "table" then
			text = text[math.random(1, #text)]
		end
		SH.sayToken = (SH.sayToken or 0) + 1
		local token = SH.sayToken
		SH.bubble.Text = text
		SH.bubble.Visible = true
		local sc = SH.bubble:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = SH.bubble })
		sc.Scale = 0.7
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(time or 3, function()
			if SH.sayToken == token and SH.bubble then
				SH.bubble.Visible = false
			end
		end)
	end

	-- poked: he jolts, throws his arms up, and says so
	function HUD.PokeShopkeeper()
		HUD.ShopkeeperSay(SH.lines.Poke, 1.8)
		if shopCallbacks.OnSound then
			shopCallbacks.OnSound("ShopNo")
		end
		local P, R = SH.parts, SH.rest
		if not P then
			return
		end
		local jolt = CFrame.new(0, 0.25, 0.1)
		P.Torso.CFrame = R.Torso * jolt * CFrame.Angles(math.rad(8), 0, 0)
		P.Stripe.CFrame = R.Stripe * jolt
		P.Head.CFrame = R.Head * CFrame.new(0, 0.35, 0.15) * CFrame.Angles(math.rad(12), 0, math.rad(8))
		P.Cap.CFrame = R.Cap * CFrame.new(0, 0.5, 0.15) * CFrame.Angles(math.rad(14), 0, math.rad(10))
		P.LeftArm.CFrame = R.Torso * CFrame.new(-1.6, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-160))
		P.RightArm.CFrame = R.Torso * CFrame.new(1.6, 1.3, 0) * CFrame.Angles(0, 0, math.rad(160))
		SH.pokeToken = (SH.pokeToken or 0) + 1
		local token = SH.pokeToken
		task.delay(0.35, function()
			if SH.pokeToken ~= token then
				return
			end
			for k, p in P do
				tween(p, 0.25, { CFrame = R[k] }, Enum.EasingStyle.Back)
			end
		end)
	end

	-- the emote banner's price for the multiplier on it; red when you can't
	function HUD.RefreshShopPrices()
		if not SH.roll then
			return
		end
		local ES = Config.EmoteShop or {}
		local each = ES.RollPrice or 25
		SH.multChip.Text = SH.mult .. "x"
		local price = each * SH.mult
		SH.rollPrice.Text = "💵 " .. price
		SH.rollPrice.TextColor3 = bucks >= price and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 140)
		SH.rollPrice.Size = UDim2.fromOffset(math.max(124, 36 + 18 * #tostring(price)), 42)
		-- (round 72) the same roll for Robux, if that one's set up
		if SH.rollRobux then
			local spec = (ES.Robux or {})[SH.mult]
			local id = type(spec) == "table" and tonumber(spec.Product) or 0
			local rp = SH.robuxPrices[SH.mult] or (type(spec) == "table" and spec.Price) or nil
			SH.rollRobux.Visible = id > 0
			SH.rollRobux.Text = "R$ " .. tostring(rp or "?")
			SH.rollRobux.Size = UDim2.fromOffset(math.max(124, 40 + 18 * #tostring(rp or "?")), 42)
		end
		local info = SH.roll:FindFirstChild("Info")
		if info then
			info.Text = SH.mult >= (ES.PickAt or 10) and "Buy " .. SH.mult .. " random emotes - and you pick the " .. SH.mult .. "th yourself!"
				or SH.mult > 1 and "Buy " .. SH.mult .. " random emotes to taunt players and have fun!"
				or "Buy a random emote to taunt players and have fun!"
		end
		for kind, key in { Soda = "deliverSodaPrice", Item = "deliverItemPrice" } do
			local spec = (Config.Deliveries or {})[kind] or {}
			if SH[key] then
				SH[key].TextColor3 = bucks >= (spec.Price or 5) and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 140)
			end
		end
	end

	-- (round 72) what Roblox says each Robux roll really costs ([n] = price)
	function HUD.SetRobuxPrices(prices)
		SH.robuxPrices = type(prices) == "table" and prices or {}
		HUD.RefreshShopPrices()
	end

	-- a purchase went through (flash the card) or didn't (shake it; he says why)
	function HUD.ShopResult(ok, itemId, text)
		local card = itemId and (cards[itemId] or emoteCards[itemId])
		local button = card and card.Button or (itemId == "Soda" and SH.deliverSoda) or (itemId == "Delivery" and SH.deliverItem) or (itemId == "Roll" and SH.roll)
		if itemId == "DeliverSoda" then
			button = SH.deliverSoda
		elseif itemId == "DeliverItem" then
			button = SH.deliverItem
		end
		if button then
			local sc = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
			sc.Scale = ok and 1.04 or 0.96
			tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if not ok and text then
			HUD.Notice(text, Color3.fromRGB(255, 130, 110))
			HUD.ShopkeeperSay(text, 2.6)
		elseif ok then
			HUD.ShopkeeperSay(text or SH.lines.Thanks, 2)
		end
	end

	-- the shop's three tabs ("Items" is the SHOP tab too)
	function HUD.ShopTab(which)
		if not shopGrid then
			return
		end
		if which == "Items" then
			which = "Shop"
		end
		if not tabButtons[which] then
			which = "Shop"
		end
		SH.tab = which
		SH.shopPage.Visible = which == "Shop"
		emoteTab.Visible = which == "Emotes"
		SH.rewards.Visible = which == "Rewards"
		local b = tabButtons[which]
		tween(SH.underline, 0.18, { Position = UDim2.new(b.Position.X.Scale, 0, 1, 0) }, Enum.EasingStyle.Quad)
		for name, tb in tabButtons do
			tb.TextTransparency = name == which and 0 or 0.35
		end
		pickedSlot = nil
		HUD.RefreshEmoteShop()
		HUD.RefreshShopPrices()
	end

	function HUD.ShopTabShown()
		return SH.tab == "Emotes" and "Emotes" or SH.tab == "Rewards" and "Rewards" or "Items"
	end

	-- straight to your emotes (the phone's app, an empty slot on the wheel)
	function HUD.OpenEmoteShop()
		HUD.ShowMenu(false)
		HUD.ToggleShop(true)
		HUD.ShopTab("Emotes")
	end

	-- owned: { [Id] = true }; wheel: the Id in each slot ("" = empty);
	-- order: the ones owned, oldest first (as they were got)
	function HUD.SetEmotes(owned, wheel, order)
		ownedEmotes = owned or {}
		wheelEmotes = wheel or {}
		SH.order = order or SH.order or {}
		HUD.RefreshEmoteShop()
	end

	local emoteById
	local function emoteOf(id)
		if not emoteById then
			emoteById = {}
			for _, e in Config.Emotes or {} do
				emoteById[e.Id] = e
			end
		end
		return emoteById[id or ""]
	end

	function HUD.RefreshEmoteShop()
		for i, s in emoteSlots do
			local e = emoteOf(wheelEmotes[i])
			s.Icon.Text = e and (e.Icon or "★") or "＋"
			s.Name.Text = e and (e.Name or e.Id) or "EMPTY"
			s.Name.TextTransparency = e and 0 or 0.5
			s.Icon.TextTransparency = e and 0 or 0.5
			s.Button.Ring.Transparency = pickedSlot == i and 0 or 1
		end
		-- newest first (as got), or A-Z; the search filters by name
		local rank = {}
		for i, id in SH.order or {} do
			rank[id] = i
		end
		local query = SH.search and string.lower(SH.search.Text) or ""
		local names = {}
		for _, e in Config.Emotes or {} do
			table.insert(names, e)
		end
		table.sort(names, function(a, b)
			return (a.Name or a.Id) < (b.Name or b.Id)
		end)
		local alpha = {}
		for i, e in names do
			alpha[e.Id] = i
		end
		local have, total = 0, 0
		for id, card in emoteCards do
			local e = emoteOf(id)
			total += 1
			local owned = ownedEmotes[id] == true
			if owned then
				have += 1
			end
			local match = query == "" or string.find(string.lower(e.Name or id), query, 1, true) ~= nil
			card.Button.Visible = owned and match
			card.Button.LayoutOrder = SH.sortNewest and (1000 - (rank[id] or 0)) or (alpha[id] or 0)
			local at = table.find(wheelEmotes, id)
			if at then
				card.Pill.Text = "ON WHEEL  ·  " .. at
				card.Pill.BackgroundColor3 = Color3.fromRGB(214, 160, 30)
			else
				card.Pill.Text = pickedSlot and ("PUT IN SLOT " .. pickedSlot) or "EQUIP"
				card.Pill.BackgroundColor3 = Color3.fromRGB(46, 46, 52)
			end
		end
		if SH.count then
			SH.count.Text = have .. " / " .. total .. " COLLECTED"
			SH.sort.Text = SH.sortNewest and "NEWEST ▾" or "A-Z ▾"
			SH.empty.Visible = have == 0
		end
	end

	-- a slot: pick it (the next emote you tap goes there); tap it again to
	-- empty it
	function HUD.EmoteSlotClicked(i)
		if pickedSlot == i then
			pickedSlot = nil
			if (wheelEmotes[i] or "") ~= "" and shopCallbacks.OnEquipEmote then
				shopCallbacks.OnEquipEmote(i, "")
			end
		else
			pickedSlot = i
		end
		HUD.RefreshEmoteShop()
	end

	-- one of yours: put it on the wheel (the slot you picked, or the first
	-- empty one); on the wheel already, take it off. (Not yours: they come
	-- from the rolls in the SHOP tab.)
	function HUD.EmoteCardClicked(id)
		if not ownedEmotes[id] then
			HUD.ShopTab("Shop")
			return
		end
		local at = table.find(wheelEmotes, id)
		if at and not pickedSlot then
			if shopCallbacks.OnEquipEmote then
				shopCallbacks.OnEquipEmote(at, "")
			end
			return
		end
		local slot = pickedSlot or table.find(wheelEmotes, "")
		if not slot then
			HUD.Notice("Your wheel's full: tap a slot first to swap one out", Color3.fromRGB(255, 212, 64))
			return
		end
		pickedSlot = nil
		if shopCallbacks.OnEquipEmote then
			shopCallbacks.OnEquipEmote(slot, id)
		end
		HUD.RefreshEmoteShop()
	end

	-- free picks waiting (a 10x roll's tenth, "PICK LATER")
	function HUD.SetEmotePicks(n)
		SH.picks = n or 0
		if SH.pickButton then
			SH.pickButton.Visible = SH.picks > 0
			SH.pickButton.Text = "🎁 PICK YOUR FREE EMOTE" .. (SH.picks > 1 and ("  x" .. SH.picks) or "")
			emoteGrid.Position = UDim2.fromOffset(0, SH.picks > 0 and 138 or 98)
			emoteGrid.Size = UDim2.new(1, 0, 1, SH.picks > 0 and -138 or -98)
		end
	end

	-- a code: it worked (what it gave) or didn't (why)
	function HUD.CodeResult(ok, text)
		if SH.codeResult then
			SH.codeResult.Text = text or (ok and "Redeemed!" or "That code doesn't work.")
			SH.codeResult.TextColor3 = ok and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(200, 60, 50)
			if ok then
				SH.codeBox.Text = ""
			end
		end
		HUD.ShopkeeperSay(ok and "Lucky you!" or "Never heard of that one.", 2)
	end

	-- THE ROLL: the cards you got, face down, flipped one after another -
	-- the rarity's colour bursting off each; a legendary shakes the screen.
	-- Then, for a 10x roll, the tenth is yours to pick (or PICK LATER).
	function HUD.BuildEmoteReveal()
		if SH.reveal then
			return
		end
		SH.reveal = make("Frame", {
			Name = "EmoteReveal",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Visible = false,
			ZIndex = 80,
			Parent = gui,
		})
		SH.revealTitle = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.new(0.8, 0, 0, 64),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 60,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "YOU GOT...",
			ZIndex = 81,
			Parent = SH.reveal,
		}, { textStroke(2) })
		SH.revealRow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(5 * 138, 2 * 184),
			BackgroundTransparency = 1,
			ZIndex = 81,
			Parent = SH.reveal,
		}, {
			make("UIGridLayout", {
				CellSize = UDim2.fromOffset(128, 174),
				CellPadding = UDim2.fromOffset(10, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			make("UIScale", {}),
		})
		SH.revealOk = make("TextButton", {
			Name = "Nice",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.92, 0),
			Size = UDim2.fromOffset(220, 54),
			BackgroundColor3 = Color3.fromRGB(250, 250, 252),
			Font = SH.font,
			TextSize = 38,
			TextColor3 = SH.ink,
			Text = "NICE!",
			Visible = false,
			ZIndex = 82,
			Parent = SH.reveal,
		}, { corner(8), make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		-- (round 72) it goes by itself a moment after the last card's turned
		-- over (the bar under NICE! runs down); NICE! closes it straight away;
		-- a click anywhere else turns the rest of the cards over at once
		SH.revealBar = make("Frame", {
			Name = "Timer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Color3.fromRGB(240, 120, 170),
			BorderSizePixel = 0,
			ZIndex = 83,
			Parent = SH.revealOk,
		})
		SH.revealSkip = make("TextButton", {
			Name = "Skip",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 80,
			Parent = SH.reveal,
		})
		SH.revealOk.MouseButton1Click:Connect(function()
			HUD.CloseEmoteReveal()
		end)
		SH.revealSkip.MouseButton1Click:Connect(function()
			local flips, done = SH.revealFlips, SH.revealDone
			if flips then
				SH.revealFlips = nil
				for k, flip in flips do
					flip(k > 1)
				end
				task.delay(0.3, function()
					if done then
						done()
					end
				end)
			else
				HUD.CloseEmoteReveal()
			end
		end)
		-- the tenth: pick one yourself (searchable), or later
		SH.pick = make("Frame", {
			Name = "EmotePick",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, 440),
			BackgroundColor3 = Color3.fromRGB(236, 236, 240),
			BackgroundTransparency = 0.08,
			Visible = false,
			ZIndex = 85,
			Parent = gui,
		}, { corner(3), make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 6),
			BackgroundTransparency = 1,
			Font = SH.font,
			TextSize = 30,
			TextColor3 = SH.ink,
			Text = "Pick one - on the house!",
			ZIndex = 86,
			Parent = SH.pick,
		})
		SH.pickSearch = make("TextBox", {
			Position = UDim2.fromOffset(12, 46),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClearTextOnFocus = false,
			Font = SH.font,
			TextSize = 26,
			TextColor3 = SH.ink,
			PlaceholderText = "Search emote name",
			PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
			Text = "",
			ZIndex = 86,
			Parent = SH.pick,
		}, { make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		SH.pickList = make("ScrollingFrame", {
			Position = UDim2.fromOffset(12, 94),
			Size = UDim2.new(1, -24, 1, -160),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 86,
			Parent = SH.pick,
		}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		SH.pickRows = {}
		for order, e in Config.Emotes or {} do
			if not e.Exclusive then
				local row = make("TextButton", {
					Name = "Pick_" .. e.Id,
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 42),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.1,
					Font = SH.font,
					TextSize = 26,
					TextColor3 = SH.ink,
					Text = (e.Icon or "★") .. "  " .. (e.Name or e.Id),
					ZIndex = 87,
					Parent = SH.pickList,
				}, { make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
				SH.pickRows[e.Id] = row
				row.MouseButton1Click:Connect(function()
					if shopCallbacks.OnPickEmote then
						shopCallbacks.OnPickEmote(e.Id)
					end
					HUD.ShowEmotePick(false)
				end)
			end
		end
		SH.pickSearch:GetPropertyChangedSignal("Text"):Connect(function()
			HUD.ShowEmotePick(SH.pick.Visible)
		end)
		local later = make("TextButton", {
			Name = "PickLater",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 48),
			BackgroundColor3 = Color3.fromRGB(226, 226, 230),
			Font = SH.font,
			TextSize = 34,
			TextColor3 = SH.ink,
			Text = "Pick later",
			ZIndex = 86,
			Parent = SH.pick,
		}, { make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 40, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		later.MouseButton1Click:Connect(function()
			HUD.ShowEmotePick(false)
		end)
	end

	function HUD.ShowEmotePick(on)
		if not SH.pick then
			return
		end
		SH.pick.Visible = on == true and (SH.picks or 0) > 0
		local query = string.lower(SH.pickSearch.Text)
		for id, row in SH.pickRows do
			local e = emoteOf(id)
			row.Visible = not ownedEmotes[id] and (query == "" or string.find(string.lower(e.Name or id), query, 1, true) ~= nil)
		end
	end

	function HUD.EmotePickVisible()
		return SH.pick ~= nil and SH.pick.Visible
	end

	-- got: the emote Ids the roll gave; pick: free picks it left you
	function HUD.ShowEmoteRoll(got, pick)
		HUD.BuildEmoteReveal()
		for _, c in SH.revealRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		SH.reveal.Visible = true
		SH.revealOk.Visible = true -- (round 72: there from the start - close it whenever)
		SH.revealBar.Size = UDim2.new(1, 0, 0, 4)
		SH.pickAfter = (pick or 0) > 0 or nil
		SH.revealTitle.Text = "YOU GOT..."
		local sc = SH.revealRow:FindFirstChildOfClass("UIScale")
		sc.Scale = #got > 5 and 0.92 or 1.15
		local best
		local flips = {}
		for i, id in got do
			local e = emoteOf(id) or { Id = id, Name = id }
			local r = HUD.EmoteRarity(e)
			local cell = make("Frame", { Name = "Card" .. i, LayoutOrder = i, BackgroundTransparency = 1, ZIndex = 81, Parent = SH.revealRow })
			local card = make("Frame", {
				Name = "Face",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(34, 34, 42),
				ZIndex = 82,
				Parent = cell,
			}, { corner(8), make("UIStroke", { Name = "Edge", Thickness = 3, Color = Color3.fromRGB(90, 90, 100), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			local q = make("TextLabel", {
				Name = "Back",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextSize = 80,
				TextColor3 = Color3.fromRGB(200, 200, 210),
				Text = "?",
				ZIndex = 83,
				Parent = card,
			})
			local icon = make("TextLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.08),
				Size = UDim2.fromScale(0.62, 0.42),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = e.Icon or "★",
				Visible = false,
				ZIndex = 83,
				Parent = card,
			})
			local name = make("TextLabel", {
				Name = "EmoteName",
				Position = UDim2.fromScale(0.05, 0.54),
				Size = UDim2.fromScale(0.9, 0.24),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = e.Name or id,
				Visible = false,
				ZIndex = 83,
				Parent = card,
			})
			local tag = make("TextLabel", {
				Name = "Rarity",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(0.86, 0, 0, 22),
				BackgroundColor3 = r.Color,
				Font = SH.font,
				TextSize = 20,
				TextColor3 = SH.ink,
				Text = r.Name,
				Visible = false,
				ZIndex = 83,
				Parent = card,
			}, { corner(5) })
			if not best or (r.Weight or 100) < (best.Weight or 100) then
				best = r
			end
			-- flip it: squash to an edge, turn the face up, back out - with a
			-- burst (round 72: quicker; a click turns the rest over at once)
			local flipped = false
			local function flip(quiet)
				if flipped or not card.Parent then
					return
				end
				flipped = true
				tween(card, 0.09, { Size = UDim2.fromScale(0.04, 1.04) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.09, function()
					if not card.Parent then
						return
					end
					q.Visible = false
					icon.Visible, name.Visible, tag.Visible = true, true, true
					card.BackgroundColor3 = r.Color:Lerp(Color3.fromRGB(20, 20, 26), 0.72)
					card.Edge.Color = r.Color
					card.Edge.Thickness = 4
					tween(card, 0.16, { Size = UDim2.fromScale(1.08, 1.08) }, Enum.EasingStyle.Back)
					task.delay(0.16, function()
						if card.Parent then
							tween(card, 0.12, { Size = UDim2.fromScale(1, 1) })
						end
					end)
					HUD.RevealBurst(cell, r, (r.Weight or 100) <= 5)
					if shopCallbacks.OnSound and not quiet then
						shopCallbacks.OnSound((r.Weight or 100) <= 5 and "RankUp" or "Purchase")
					end
				end)
			end
			table.insert(flips, flip)
			task.delay(0.2 + (i - 1) * 0.12, flip)
		end
		-- all face up: the title, the shopkeeper - and a moment later it goes by
		-- itself (the bar under NICE! runs down), or on to the free pick
		local token = (SH.revealToken or 0) + 1
		SH.revealToken = token
		SH.revealFlips = flips
		local shown = false
		local function allUp()
			if shown or SH.revealToken ~= token or not SH.reveal.Visible then
				return
			end
			shown = true
			SH.revealFlips = nil
			if best and (best.Weight or 100) <= 5 then
				SH.revealTitle.Text = best.Name .. "!!"
				HUD.ShopkeeperSay(SH.lines.Legend, 3)
			else
				HUD.ShopkeeperSay(SH.lines.Roll, 2.5)
			end
			local ES = Config.EmoteShop or {}
			local stay = (ES.RevealStay or 1.8) + (#got > 5 and 1 or 0)
			SH.revealBar.Size = UDim2.new(1, 0, 0, 4)
			tween(SH.revealBar, stay, { Size = UDim2.new(0, 0, 0, 4) }, Enum.EasingStyle.Linear)
			task.delay(stay, function()
				if SH.revealToken == token then
					HUD.CloseEmoteReveal()
				end
			end)
		end
		SH.revealDone = allUp
		task.delay(0.2 + #got * 0.12 + 0.2, allUp)
	end

	-- the colour bursting off a card as it turns face up (rays for the rare ones)
	function HUD.RevealBurst(cell, rarity, big)
		local rays = big and 12 or ((rarity.Weight or 100) <= 15 and 8 or 5)
		for k = 1, rays do
			local ray = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(big and 10 or 6, 10),
				Rotation = (k / rays) * 360 + math.random(-8, 8),
				BackgroundColor3 = rarity.Color,
				BorderSizePixel = 0,
				ZIndex = 81,
				Parent = cell,
			})
			tween(ray, 0.35, { Size = UDim2.fromOffset(big and 4 or 3, big and 170 or 110), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
			task.delay(0.4, function()
				ray:Destroy()
			end)
		end
		if big and SH.revealRow then
			local base = SH.revealRow.Position
			for s = 1, 6 do
				task.delay(s * 0.03, function()
					SH.revealRow.Position = base + UDim2.fromOffset(math.random(-8, 8), math.random(-6, 6))
				end)
			end
			task.delay(0.21, function()
				SH.revealRow.Position = base
			end)
		end
	end

	-- (round 72) the reveal put away (and on to the free pick, if there is one)
	function HUD.CloseEmoteReveal()
		if not (SH.reveal and SH.reveal.Visible) then
			return
		end
		SH.revealToken = (SH.revealToken or 0) + 1
		SH.revealFlips, SH.revealDone = nil, nil
		SH.reveal.Visible = false
		if (SH.picks or 0) > 0 and SH.pickAfter then
			SH.pickAfter = nil
			HUD.ShowEmotePick(true)
		end
	end

	function HUD.EmoteRevealVisible()
		return SH.reveal ~= nil and SH.reveal.Visible
	end

	function HUD.ToggleShop(force)
		if not shopPanel then
			return false
		end
		local open = force
		if open == nil then
			open = not shopPanel.Visible
		end
		local was = shopPanel.Visible
		shopPanel.Visible = open
		if open then
			HUD.ShowMenu(false)
			HUD.HideVendor()
			if not was then
				SH.scale.Scale = 0.92
				tween(SH.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
				HUD.ShopkeeperSay(SH.lines.Greet, 3)
				HUD.RefreshShopPrices()
			end
		else
			HUD.ShowEmotePick(false)
		end
		if shopCallbacks.OnToggle then
			shopCallbacks.OnToggle(open)
		end
		return open
	end

	function HUD.ShopVisible()
		return shopPanel ~= nil and shopPanel.Visible
	end

	function HUD.MenuVisible()
		-- (going away counts as away)
		return menu ~= nil and menu.Visible and not (phoneParts.fx and phoneParts.fx.closeAt)
	end

	-- where a controller's selection starts when a panel opens
	function HUD.FirstButton(which)
		if which == "Shop" then
			-- (round 63) the page you're on: your first emote (or the first
			-- slot), the code box, or the emote banner
			if emoteTab and emoteTab.Visible then
				for _, e in Config.Emotes or {} do
					local c = emoteCards[e.Id]
					if c and c.Button.Visible then
						return c.Button
					end
				end
				return emoteSlots[1] and emoteSlots[1].Button or nil
			elseif SH.rewards and SH.rewards.Visible then
				return SH.redeem
			end
			return SH.roll
		elseif which == "Vendor" then
			return HUD.VendorFirstButton()
		end
		for _, name in Config.QuirkOrder do
			local b = menuGrid and menuGrid:FindFirstChild(name)
			if b and b.Visible then
				return b
			end
		end
		return nil
	end

	-- "Keyboard", "Gamepad" or "Touch": every key hint on the HUD follows it
	function HUD.SetInputMode(mode)
		inputMode = mode
		if HUD.SetTopBarKeys then
			HUD.SetTopBarKeys(mode)
		end
		if not gui then
			return
		end
		local pad = mode == "Gamepad"
		local C = Config
		local keys = pad and {
			HUD.PadGlyph(C.AbilityKeys[1]), HUD.PadGlyph(C.AbilityKeys[2]), HUD.PadGlyph(C.AbilityKeys[3]),
			HUD.PadGlyph(C.SpecialKeys), HUD.PadGlyph(C.DashKeys), HUD.PadGlyph(C.ContextKeys),
		} or { "1", "2", "3", "R", "Q", "4" }
		for i = 1, 6 do
			local slot = slots[i]
			if slot then
				slot.Key.Text = keys[i]
				slot.Key.TextSize = (utf8.len(keys[i]) or #keys[i]) > 1 and 11 or 14
				slot.Key.Visible = mode ~= "Touch"
			end
		end
		keyText.Guard = pad and HUD.PadGlyph(C.BlockKeys) or "F"
		keyText.Ult = pad and HUD.PadGlyph(C.UltKeys) or "G"
		keyText.Dash = pad and HUD.PadGlyph(C.DashKeys) or mode == "Touch" and "DASH" or "Q"
		-- a controller gets the button legend, bottom left, instead of the line
		HUD.ShowPadLegend(pad)
		if hintLabel then
			hintLabel.Visible = mode == "Keyboard"
			hintLabel.Text = pad
					and "B Punch · LB/LT/RT Moves · RB Finish/Extra · ◀ Special · ▲ Ult · Y Dash · X Block · L3 Lock-on · ▼ Shift Lock · ▶ Item · SELECT Shop"
				or "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · T Lock-on · B Emotes · H Shop · M Quirk"
		end
		if changeLabel then
			changeLabel.Text = pad and "SELECT: QUIRKS & SHOP" or mode == "Touch" and "TAP: CHANGE" or "[M] CHANGE"
		end
		if shopButton then
			shopButton.Text = pad and "SHOP [SELECT]" or mode == "Touch" and "SHOP" or "SHOP [H]"
			shopHint.Text = pad and "A: buy   ·   B: close   ·   every KO pays " .. ((Config.Economy and Config.Economy.PerKO) or 5) .. " " .. currency()
				or "Every KO pays " .. ((Config.Economy and Config.Economy.PerKO) or 5) .. " " .. currency() .. "  ·  poke the shopkeeper, he loves it"
		end
		if guardText and guardText.Text:find("GUARD %[") then
			guardText.Text = "GUARD [" .. keyText.Guard .. "]"
		end
		if ultReady then
			ultText.Text = ultName .. "  ·  READY  [" .. keyText.Ult .. "]"
		end
		if HUD.ApplyTouch and (mode == "Touch") ~= (HUD.Touch and HUD.Touch.on or false) then
			HUD.ApplyTouch(mode == "Touch")
		end
	end
end

-- FUN STUFF (test menu side panel): items { { Id, Label, Info, Color } }, onPick(id)
function HUD.BuildFunPanel(items, onPick)
	if funPanel then
		return
	end
	funPanel = make("Frame", {
		Name = "FunStuff",
		Position = UDim2.new(0, 22 + TEST_W, 0, 108),
		Size = UDim2.fromOffset(300, 48 + #items * 42),
		BackgroundColor3 = Color3.fromRGB(24, 24, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { stroke(3), corner(8) })
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "FUN STUFF",
		ZIndex = 21,
		Parent = funPanel,
	}, { textStroke(1.5) })
	for i, item in items do
		local button = make("TextButton", {
			Name = item.Id,
			Position = UDim2.fromOffset(10, 36 + (i - 1) * 42),
			Size = UDim2.new(1, -20, 0, 38),
			BackgroundColor3 = Color3.fromRGB(44, 46, 64),
			AutoButtonColor = true,
			Text = "",
			ZIndex = 22,
			Parent = funPanel,
		}, { corner(6), stroke(1.5) })
		make("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(0, 6, 1, -12),
			BackgroundColor3 = item.Color or Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = button,
		}, { corner(3) })
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 2),
			Size = UDim2.new(1, -26, 0, 18),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = item.Label,
			ZIndex = 23,
			Parent = button,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(20, 19),
			Size = UDim2.new(1, -26, 0, 16),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.fromRGB(180, 184, 210),
			Text = item.Info or "",
			ZIndex = 23,
			Parent = button,
		})
		button.MouseButton1Click:Connect(function()
			onPick(item.Id)
			button.BackgroundColor3 = Color3.fromRGB(255, 212, 64)
			tween(button, 0.35, { BackgroundColor3 = Color3.fromRGB(44, 46, 64) })
		end)
	end
end

function HUD.ToggleFunPanel(force)
	if not funPanel then
		return false
	end
	if force ~= nil then
		funPanel.Visible = force
	else
		funPanel.Visible = not funPanel.Visible
	end
	return funPanel.Visible
end

---------------------------------------------------------------------------
-- SERVER SETTINGS (test menu side panel) - Jujutsu Shenanigans' private
-- server "+" menu: a SERVER tab (the world: destruction, multipliers,
-- gravity, speeds...) and a PLAYERS tab (pick everyone or one player, then
-- toggles and actions for them).
-- spec = { Server = { rows }, Players = { rows } }; a row is
-- { Id, Label, Kind = "Toggle" | "Number" | "Button", Steps = { ... } (Number) }
-- cb = { get(id) -> value, set(id, value), players() -> { { UserId, Name } },
--        playerFlag(id, userId) -> bool, player(id, userId) }
-- (userId 0 = every player)
---------------------------------------------------------------------------

local PSPanel = { rows = {}, target = 0 }

local function psFormat(v)
	if type(v) ~= "number" then
		return tostring(v)
	end
	if math.abs(v - math.floor(v)) < 0.001 then
		return tostring(math.floor(v))
	end
	local out = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
	return out
end

function HUD.BuildServerPanel(spec, cb)
	if PSPanel.frame then
		return
	end
	PSPanel.cb = cb
	local frame = make("Frame", {
		Name = "ServerSettings",
		Position = UDim2.new(0, 22 + TEST_W, 0, 108),
		Size = UDim2.fromOffset(340, 520),
		BackgroundColor3 = Color3.fromRGB(24, 24, 34),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, { stroke(3), corner(8) })
	PSPanel.frame = frame
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = COMIC_FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 212, 64),
		Text = "SERVER SETTINGS",
		ZIndex = 21,
		Parent = frame,
	}, { textStroke(1.5) })
	-- the tabs
	local pages, tabs = {}, {}
	local function show(name)
		for n, page in pages do
			page.Visible = n == name
			tabs[n].BackgroundColor3 = n == name and Color3.fromRGB(255, 212, 64) or Color3.fromRGB(52, 54, 72)
			tabs[n].TextColor3 = n == name and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		end
		HUD.RefreshServerPanel()
	end
	for i, name in { "Server", "Players" } do
		tabs[name] = make("TextButton", {
			Position = UDim2.new((i - 1) * 0.5, i == 1 and 10 or 4, 0, 34),
			Size = UDim2.new(0.5, -14, 0, 28),
			BackgroundColor3 = Color3.fromRGB(52, 54, 72),
			Font = UI_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = string.upper(name),
			ZIndex = 22,
			Parent = frame,
		}, { corner(5), stroke(1.5) })
		tabs[name].MouseButton1Click:Connect(function()
			show(name)
		end)
		local top = name == "Players" and 104 or 68
		pages[name] = make("ScrollingFrame", {
			Position = UDim2.fromOffset(8, top),
			Size = UDim2.new(1, -16, 1, -top - 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			ZIndex = 21,
			Parent = frame,
		}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	end
	-- PLAYERS: who it applies to (everyone, or one player)
	local picker = make("TextButton", {
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundColor3 = Color3.fromRGB(70, 60, 110),
		Font = UI_FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "◀  EVERYONE  ▶",
		ZIndex = 22,
		Parent = frame,
	}, { corner(5), stroke(1.5) })
	PSPanel.picker = picker
	picker.MouseButton1Click:Connect(function()
		local list = cb.players()
		local ids = { 0 }
		for _, p in list do
			table.insert(ids, p.UserId)
		end
		local at = table.find(ids, PSPanel.target) or 1
		PSPanel.target = ids[at % #ids + 1]
		HUD.RefreshServerPanel()
	end)
	pages.Players:GetPropertyChangedSignal("Visible"):Connect(function()
		picker.Visible = pages.Players.Visible
	end)
	for pageName, rows in { Server = spec.Server or {}, Players = spec.Players or {} } do
		for i, row in rows do
			local holder = make("Frame", {
				Name = row.Id,
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 32),
				BackgroundColor3 = Color3.fromRGB(44, 46, 64),
				ZIndex = 22,
				Parent = pages[pageName],
			}, { corner(5) })
			local label = make("TextLabel", {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -130, 1, 0),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = row.Label,
				ZIndex = 23,
				Parent = holder,
			})
			local entry = { Row = row, Page = pageName, Holder = holder, Label = label }
			PSPanel.rows[pageName .. ":" .. row.Id] = entry
			local function button(x, w, text)
				return make("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(w, 24),
					BackgroundColor3 = Color3.fromRGB(70, 72, 96),
					Font = UI_FONT,
					TextSize = 13,
					TextColor3 = Color3.new(1, 1, 1),
					Text = text,
					ZIndex = 24,
					Parent = holder,
				}, { corner(4) })
			end
			if row.Kind == "Toggle" then
				entry.Button = button(-6, 64, "OFF")
				entry.Button.MouseButton1Click:Connect(function()
					if pageName == "Server" then
						cb.set(row.Id, not cb.get(row.Id))
					else
						cb.player(row.Id, PSPanel.target)
					end
				end)
			elseif row.Kind == "Number" then
				local plus = button(-6, 26, "+")
				entry.Value = make("TextLabel", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -36, 0.5, 0),
					Size = UDim2.fromOffset(52, 24),
					BackgroundTransparency = 1,
					Font = UI_FONT,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(255, 212, 64),
					Text = "1",
					ZIndex = 24,
					Parent = holder,
				})
				local minus = button(-92, 26, "-")
				local function step(by)
					local steps = row.Steps or { 1 }
					local now = cb.get(row.Id)
					local best, bestD = 1, math.huge
					for k, v in steps do
						local d = math.abs(v - (tonumber(now) or 0))
						if d < bestD then
							best, bestD = k, d
						end
					end
					cb.set(row.Id, steps[math.clamp(best + by, 1, #steps)])
				end
				plus.MouseButton1Click:Connect(function()
					step(1)
				end)
				minus.MouseButton1Click:Connect(function()
					step(-1)
				end)
			else
				local go = button(-6, 64, row.Button or "GO")
				go.BackgroundColor3 = Color3.fromRGB(96, 70, 150)
				go.MouseButton1Click:Connect(function()
					if pageName == "Server" then
						cb.set(row.Id, true)
					else
						cb.player(row.Id, PSPanel.target)
					end
					go.BackgroundColor3 = Color3.fromRGB(255, 212, 64)
					tween(go, 0.35, { BackgroundColor3 = Color3.fromRGB(96, 70, 150) })
				end)
			end
		end
	end
	show("Server")
end

-- re-read every row's state (settings changed, players came and went)
function HUD.RefreshServerPanel()
	local cb = PSPanel.cb
	if not cb or not PSPanel.frame then
		return
	end
	-- the picked player left: back to everyone
	local name
	if PSPanel.target ~= 0 then
		for _, p in cb.players() do
			if p.UserId == PSPanel.target then
				name = p.Name
			end
		end
		if not name then
			PSPanel.target = 0
		end
	end
	PSPanel.picker.Text = "◀  " .. (name or "EVERYONE") .. "  ▶"
	for _, entry in PSPanel.rows do
		local row = entry.Row
		if row.Kind == "Toggle" then
			local on
			if entry.Page == "Server" then
				on = cb.get(row.Id) == true
			else
				on = cb.playerFlag(row.Id, PSPanel.target) == true
			end
			entry.Button.Text = on and "ON" or "OFF"
			entry.Button.BackgroundColor3 = on and Color3.fromRGB(70, 190, 100) or Color3.fromRGB(150, 60, 60)
		elseif row.Kind == "Number" then
			entry.Value.Text = psFormat(cb.get(row.Id)) .. (row.Suffix or "")
		end
	end
end

function HUD.ToggleServerPanel(force)
	local frame = PSPanel.frame
	if not frame then
		return false
	end
	if force ~= nil then
		frame.Visible = force
	else
		frame.Visible = not frame.Visible
	end
	if frame.Visible then
		HUD.RefreshServerPanel()
	end
	return frame.Visible
end

---------------------------------------------------------------------------
-- A shopkeeper's menu (Tony's Pizzeria): what he says, and what he sells
---------------------------------------------------------------------------

do
	local panel, title, line, list
	local rows = {} -- { { Id, Button, Price } }
	local onBuy
	local ITALY = { Color3.fromRGB(0, 146, 70), Color3.fromRGB(245, 245, 245), Color3.fromRGB(206, 43, 55) }

	local function build()
		panel = make("Frame", {
			Name = "Vendor",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(440, 200),
			BackgroundColor3 = Color3.fromRGB(18, 20, 34),
			BackgroundTransparency = 0.05,
			Visible = false,
			ZIndex = 50,
			Parent = gui,
		}, { stroke(4), corner(10) })
		-- the green-white-red stripe along the top
		for i, c in ITALY do
			make("Frame", {
				Position = UDim2.new((i - 1) / 3, 0, 0, 0),
				Size = UDim2.new(1 / 3, 0, 0, 8),
				BackgroundColor3 = c,
				BorderSizePixel = 0,
				ZIndex = 51,
				Parent = panel,
			})
		end
		title = make("TextLabel", {
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 34,
			TextColor3 = Color3.fromRGB(255, 226, 120),
			Text = "",
			ZIndex = 51,
			Parent = panel,
		}, { textStroke(2.5) })
		line = make("TextLabel", {
			Position = UDim2.fromOffset(16, 52),
			Size = UDim2.new(1, -32, 0, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Font = UI_FONT,
			TextSize = 15,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(30, 30, 36),
			Text = "",
			ZIndex = 51,
			Parent = panel,
		}, { corner(12), make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
		list = make("Frame", {
			Position = UDim2.fromOffset(16, 106),
			Size = UDim2.new(1, -32, 1, -118),
			BackgroundTransparency = 1,
			ZIndex = 51,
			Parent = panel,
		}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local close = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 14),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.fromRGB(170, 60, 60),
			Font = UI_FONT,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "X",
			ZIndex = 52,
			Parent = panel,
		}, { corner(6), stroke(2) })
		close.MouseButton1Click:Connect(function()
			HUD.HideVendor()
		end)
	end

	local function row(order, id)
		local item = Config.Items[id]
		local button = make("TextButton", {
			Name = id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = item.Color:Lerp(Color3.new(0, 0, 0), 0.55),
			AutoButtonColor = true,
			Text = "",
			ZIndex = 52,
			Parent = list,
		}, { corner(8), stroke(2) })
		make("TextLabel", {
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.fromOffset(44, 44),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = item.Icon or "?",
			ZIndex = 53,
			Parent = button,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(58, 4),
			Size = UDim2.new(1, -150, 0, 26),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = item.Name .. ((item.Gives or 1) > 1 and (" x" .. item.Gives) or ""),
			ZIndex = 53,
			Parent = button,
		}, { textStroke(1.5) })
		make("TextLabel", {
			Position = UDim2.fromOffset(58, 30),
			Size = UDim2.new(1, -150, 0, 18),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(215, 220, 235),
			Text = item.Info or "",
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 53,
			Parent = button,
		})
		local price = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(78, 32),
			BackgroundColor3 = Color3.fromRGB(56, 170, 84),
			Font = COMIC_FONT,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			Text = string.format("%d BUCKS", item.Price or 5),
			ZIndex = 53,
			Parent = button,
		}, { corner(6), stroke(1.5), textStroke(1.2) })
		button.MouseButton1Click:Connect(function()
			if onBuy then
				onBuy(id)
			end
			local sc = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
			sc.Scale = 0.95
			tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		return { Id = id, Button = button, Price = price }
	end

	-- spec: { Title, Line, Items = { item ids }, Bucks, OnBuy(id) }
	function HUD.ShowVendor(spec)
		if not panel then
			build()
		end
		for _, r in rows do
			r.Button:Destroy()
		end
		table.clear(rows)
		onBuy = spec.OnBuy
		title.Text = spec.Title or "SHOP"
		line.Text = "“" .. tostring(spec.Line or "") .. "”"
		for i, id in spec.Items or {} do
			if Config.Items[id] then
				table.insert(rows, row(i, id))
			end
		end
		panel.Size = UDim2.fromOffset(440, 118 + #rows * 62)
		HUD.SetVendorBucks(spec.Bucks or 0)
		panel.Visible = true
		HUD.ToggleShop(false)
		HUD.ShowMenu(false)
	end

	function HUD.VendorSay(text)
		if line then
			line.Text = "“" .. tostring(text or "") .. "”"
		end
	end

	-- prices you can pay are green, the rest grey
	function HUD.SetVendorBucks(amount)
		for _, r in rows do
			local item = Config.Items[r.Id]
			r.Price.BackgroundColor3 = amount >= (item.Price or 5) and Color3.fromRGB(56, 170, 84) or Color3.fromRGB(80, 82, 96)
		end
	end

	function HUD.HideVendor()
		if panel then
			panel.Visible = false
		end
	end

	function HUD.VendorVisible()
		return panel ~= nil and panel.Visible
	end

	function HUD.VendorFirstButton()
		return rows[1] and rows[1].Button or nil
	end
end

---------------------------------------------------------------------------
-- The emote wheel (B): the emotes round a ring. Point at one with the mouse
-- (and let go of B) or click / tap it. It covers the screen with a button
-- that frees the mouse from shift lock while it's up, and takes any click
-- that misses a slice (that closes it - it never throws a punch).
---------------------------------------------------------------------------
do
	local wheel, centerLabel, ring, pickFn, watch
	local buttons = {}
	local hover = nil
	local layout = { inner = 0, outer = 0, size = 380 }
	-- which one is in a direction (turn: 0..1 round from the top), on the
	-- inner ring or the outer one
	local function slotAt(turn, outer)
		if layout.outer == 0 then
			outer = false
		end
		local n = outer and layout.outer or layout.inner
		if n == 0 then
			return nil
		end
		local k = math.floor(turn * n + 0.5 - (outer and 0.5 or 0)) % n + 1
		return outer and layout.inner + k or k
	end

	local function setHover(i)
		if hover == i then
			return
		end
		hover = i
		for k, b in buttons do
			local on = k == i
			b.BackgroundColor3 = on and accent or GLASS.Color
			b.BackgroundTransparency = on and 0.05 or GLASS.T
			b.TextColor3 = on and Color3.new(0.05, 0.05, 0.07) or Color3.new(1, 1, 1)
		end
		if centerLabel then
			centerLabel.Text = i and buttons[i] and buttons[i]:GetAttribute("Label") or "EMOTES"
		end
	end

	function HUD.BuildEmoteWheel(list, onPick)
		pickFn = onPick
		if wheel then
			wheel:Destroy()
		end
		table.clear(buttons)
		hover = nil
		layout.inner = #list > 10 and 8 or #list
		layout.outer = #list - layout.inner
		layout.size = layout.outer > 0 and 560 or 380
		wheel = make("TextButton", {
			Name = "EmoteWheel",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.65,
			Text = "",
			AutoButtonColor = false,
			Modal = true,
			Visible = false,
			ZIndex = 40,
			Parent = gui,
		})
		ring = make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(layout.size, layout.size),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.45,
			ZIndex = 41,
			Parent = wheel,
		}, { corner(layout.size / 2), edge(0.6) })
		autoScale(ring)
		centerLabel = make("TextLabel", {
			Name = "Center",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(132, 132),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.1,
			Font = HEAD_FONT,
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "EMOTES",
			ZIndex = 43,
			Parent = ring,
		}, { corner(66), edge(0.5), textStroke(1) })
		make("TextLabel", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 12),
			Size = UDim2.fromOffset(380, 20),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.2,
			Text = "Click one  ·  or hold B, point, let go",
			ZIndex = 43,
			Parent = ring,
		}, { textStroke(1) })
		for i, e in list do
			local outer = i > layout.inner
			local n = math.max(outer and layout.outer or layout.inner, 1)
			local k = outer and i - layout.inner or i
			local a = (k - 1 + (outer and 0.5 or 0)) / n * math.pi * 2 - math.pi / 2
			local r = outer and 222 or (layout.outer > 0 and 130 or 132)
			local b = make("TextButton", {
				Name = e.Empty and ("Emote_Empty" .. i) or ("Emote_" .. tostring(e.Id)),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
				Size = UDim2.fromOffset(100, 54),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				Font = HEAD_FONT,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = e.Empty and "EMPTY\n+ SHOP" or (e.Name or e.Id),
				AutoButtonColor = false,
				ZIndex = 42,
				Parent = ring,
			}, { corner(8), edge(0.5), make("UITextSizeConstraint", { MaxTextSize = 13 }) })
			b:SetAttribute("Label", e.Empty and "GET EMOTES IN THE SHOP" or (e.Name or e.Id))
			b:SetAttribute("EmoteId", e.Id)
			if e.Empty then
				b.TextTransparency = 0.4
			end
			b.MouseEnter:Connect(function()
				setHover(i)
			end)
			b.Activated:Connect(function()
				HUD.PickEmote(i)
			end)
			buttons[i] = b
		end
		wheel.Activated:Connect(function()
			HUD.ShowEmoteWheel(false)
		end)
	end

	function HUD.EmoteWheelVisible()
		return wheel ~= nil and wheel.Visible
	end

	function HUD.EmoteHover()
		return hover
	end

	-- the last thing pressed was on a controller
	function HUD.UsingGamepad()
		local ok, last = pcall(function()
			return game:GetService("UserInputService"):GetLastInputType()
		end)
		return ok and last ~= nil and string.sub(last.Name, 1, 7) == "Gamepad"
	end

	function HUD.ShowEmoteWheel(on)
		if not wheel then
			return
		end
		wheel.Visible = on == true
		setHover(nil)
		if watch then
			watch:Disconnect()
			watch = nil
		end
		if not on then
			pcall(function()
				game:GetService("ContextActionService"):UnbindAction("EmoteWheelStick")
			end)
			return
		end
		ring.Size = UDim2.fromOffset(layout.size * 0.8, layout.size * 0.8)
		tween(ring, 0.12, { Size = UDim2.fromOffset(layout.size, layout.size) }, Enum.EasingStyle.Back)
		local padNow = HUD.UsingGamepad()
		local hint = ring:FindFirstChild("Hint")
		if hint then
			hint.Text = padNow and ("Right stick to pick  ·  " .. HUD.PadGlyph(Config.EmoteKeys) .. " to play") or "Click one  ·  or hold B, point, let go"
		end
		if padNow then
			pcall(function()
				game:GetService("ContextActionService"):BindActionAtPriority("EmoteWheelStick", function()
					return Enum.ContextActionResult.Sink
				end, false, 3000, Enum.KeyCode.Thumbstick2)
			end)
		end
		-- the slice in the mouse's direction from the middle lights up (the
		-- wheel sits mid-screen in a ScreenGui that ignores the top bar inset,
		-- the same space the mouse position is in)
		-- (only once the mouse moves: opening it doesn't pick whatever the
		-- cursor happened to be pointing at)
		local uis = game:GetService("UserInputService")
		local function mouseAt()
			local okMouse, m = pcall(function()
				return uis:GetMouseLocation()
			end)
			return okMouse and typeof(m) == "Vector2" and m or nil
		end
		local function stick()
			local okPad, state = pcall(function()
				return uis:GetGamepadState(Enum.UserInputType.Gamepad1)
			end)
			for _, io in okPad and state or {} do
				if io.KeyCode == Enum.KeyCode.Thumbstick2 then
					return Vector2.new(io.Position.X, -io.Position.Y)
				end
			end
			return nil
		end
		local last = mouseAt()
		watch = RunService.RenderStepped:Connect(function()
			-- (a controller: the right stick points at one)
			local s = stick()
			if s and s.Magnitude > 0.5 and #buttons > 0 then
				-- (pushed right to the edge: the outer ring)
				local turn = (math.atan2(s.Y, s.X) + math.pi / 2) / (math.pi * 2)
				setHover(slotAt(turn, s.Magnitude > 0.93))
				return
			end
			local cam = workspace.CurrentCamera
			local m = mouseAt()
			if not m or not cam or #buttons == 0 or (last and (m - last).Magnitude < 1) then
				return
			end
			last = m
			local off = m - cam.ViewportSize / 2
			if off.Magnitude < 50 then
				return
			end
			local turn = (math.atan2(off.Y, off.X) + math.pi / 2) / (math.pi * 2)
			local scale = ring.AbsoluteSize.X > 0 and ring.AbsoluteSize.X / layout.size or 1
			setHover(slotAt(turn, off.Magnitude > 176 * scale))
		end)
	end

	-- play the one given (or the one pointed at) and close
	function HUD.PickEmote(i)
		local b = buttons[i or hover or 0]
		HUD.ShowEmoteWheel(false)
		if b and pickFn then
			pickFn(b:GetAttribute("EmoteId"))
		end
	end

	-- ON A CONTROLLER: a menu instead of the wheel - a grid of big cards you
	-- move between with the D-pad / left stick, A to play one, B to close
	local menuPanel
	local menuCards = {}
	function HUD.BuildEmoteMenu(list)
		if menuPanel then
			menuPanel:Destroy()
		end
		table.clear(menuCards)
		local cols = #list > 12 and 6 or 4
		local rows = math.max(math.ceil(#list / cols), 1)
		local W, H, GAP = 132, 104, 10
		menuPanel = make("Frame", {
			Name = "EmoteMenu",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(cols * W + (cols - 1) * GAP + 32, rows * H + (rows - 1) * GAP + 96),
			BackgroundColor3 = Color3.fromRGB(14, 15, 22),
			BackgroundTransparency = 0.08,
			Visible = false,
			ZIndex = 45,
			Parent = gui,
		}, { corner(12), edge(0.55) })
		autoScale(menuPanel)
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.new(1, -32, 0, 38),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = "EMOTES",
			ZIndex = 46,
			Parent = menuPanel,
		}, { textStroke(2) })
		make("TextLabel", {
			Name = "Hint",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(260, 22),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(200, 204, 225),
			Text = "A  PLAY      B  BACK",
			ZIndex = 46,
			Parent = menuPanel,
		})
		for i, e in list do
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			local card = make("TextButton", {
				Name = e.Empty and ("EmoteCard_Empty" .. i) or ("EmoteCard_" .. tostring(e.Id)),
				Position = UDim2.fromOffset(16 + col * (W + GAP), 56 + row * (H + GAP)),
				Size = UDim2.fromOffset(W, H),
				BackgroundColor3 = Color3.fromRGB(34, 37, 54),
				AutoButtonColor = false,
				Selectable = true,
				Text = "",
				ZIndex = 46,
				Parent = menuPanel,
			}, { corner(10), make("UIStroke", { Name = "Ring", Thickness = 3, Color = accent, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			card:SetAttribute("EmoteId", e.Id)
			make("TextLabel", {
				Name = "Icon",
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = e.Empty and "＋" or (e.Icon or "★"),
				ZIndex = 47,
				Parent = card,
			})
			make("TextLabel", {
				Name = "Label",
				Position = UDim2.new(0, 6, 1, -38),
				Size = UDim2.new(1, -12, 0, 30),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = e.Empty and "EMPTY SLOT" or (e.Name or e.Id),
				ZIndex = 47,
				Parent = card,
			}, { textStroke(1), make("UITextSizeConstraint", { MaxTextSize = 13 }) })
			-- (the one the controller is on lights up)
			local function lit(on)
				card.BackgroundColor3 = on and Color3.fromRGB(58, 62, 88) or Color3.fromRGB(34, 37, 54)
				card.Ring.Transparency = on and 0 or 1
			end
			card.SelectionGained:Connect(function()
				lit(true)
			end)
			card.SelectionLost:Connect(function()
				lit(false)
			end)
			card.MouseEnter:Connect(function()
				lit(true)
			end)
			card.MouseLeave:Connect(function()
				lit(false)
			end)
			card.Activated:Connect(function()
				HUD.ShowEmoteMenu(false)
				if pickFn then
					pickFn(e.Id)
				end
			end)
			menuCards[i] = card
		end
		-- (a solid 4-wide grid: the pad moves card to card, wrapping round the rows)
		for i, card in menuCards do
			card.NextSelectionLeft = menuCards[i - 1] or menuCards[#menuCards]
			card.NextSelectionRight = menuCards[i + 1] or menuCards[1]
			card.NextSelectionUp = menuCards[i - cols] or card
			card.NextSelectionDown = menuCards[i + cols] or card
		end
	end

	function HUD.ShowEmoteMenu(on)
		if not menuPanel then
			return
		end
		menuPanel.Visible = on == true
		if on then
			HUD.ShowEmoteWheel(false)
			local hint = menuPanel:FindFirstChild("Hint")
			if hint and HUD.PadGlyph then
				hint.Text = HUD.PadGlyph({ Enum.KeyCode.ButtonA }) .. "  PLAY      " .. HUD.PadGlyph({ Enum.KeyCode.ButtonB }) .. "  BACK"
			end
			local sc = menuPanel:FindFirstChildOfClass("UIScale")
			local full = sc and sc.Scale or 1
			if sc then
				sc.Scale = full * 0.85
				tween(sc, 0.14, { Scale = full }, Enum.EasingStyle.Back)
			end
		end
	end

	function HUD.EmoteMenuVisible()
		return menuPanel ~= nil and menuPanel.Visible
	end

	-- (where a controller's selection starts: the first card)
	function HUD.EmoteMenuFirst()
		return menuCards[1]
	end
end

---------------------------------------------------------------------------
-- The controller legend (the way Jujutsu Shenanigans does it on console):
-- on a controller, what each button does, bottom left - with Roblox's own
-- picture of each button for whichever pad it is (Xbox or PlayStation), a
-- coloured chip with its name if there's no picture
---------------------------------------------------------------------------
do
	local legend
	local XBOX = {
		ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonL1 = "LB", ButtonL2 = "LT", ButtonR1 = "RB", ButtonR2 = "RT",
		ButtonL3 = "L3", ButtonR3 = "R3", ButtonSelect = "VIEW", ButtonStart = "MENU", DPadLeft = "◀", DPadRight = "▶", DPadUp = "▲", DPadDown = "▼",
	}
	local PS = { ButtonA = "✕", ButtonB = "○", ButtonX = "□", ButtonY = "△", ButtonL1 = "L1", ButtonL2 = "L2", ButtonR1 = "R1", ButtonR2 = "R2", ButtonSelect = "SHARE", ButtonStart = "OPTIONS" }
	local FACE = {
		ButtonA = Color3.fromRGB(106, 180, 76), ButtonB = Color3.fromRGB(214, 64, 58),
		ButtonX = Color3.fromRGB(58, 120, 216), ButtonY = Color3.fromRGB(232, 190, 48),
	}
	local uis = game:GetService("UserInputService")

	-- the first controller button in a key list
	local function padKey(list)
		for _, k in list or {} do
			local n = k.Name
			if string.sub(n, 1, 6) == "Button" or string.sub(n, 1, 4) == "DPad" then
				return k
			end
		end
		return nil
	end

	local function playStation()
		local ok, s = pcall(function()
			return uis:GetStringForKeyCode(Enum.KeyCode.ButtonA)
		end)
		return ok and type(s) == "string" and string.find(s, "Cross") ~= nil
	end

	-- a button's name as it's printed on the pad (LB / L1, Y / △, ▲ ...)
	function HUD.PadGlyph(list)
		local key = padKey(list)
		if not key then
			return ""
		end
		return (playStation() and PS[key.Name]) or XBOX[key.Name] or key.Name
	end

	local function glyph(key, parent)
		local ok, img = pcall(function()
			return uis:GetImageForKeyCode(key)
		end)
		if ok and type(img) == "string" and img ~= "" then
			return make("ImageLabel", { Name = "Glyph", Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Image = img, Parent = parent })
		end
		local face = FACE[key.Name]
		local text = HUD.PadGlyph({ key })
		local chars = utf8.len(text) or #text -- (the D-pad arrows are one character, three bytes)
		return make("TextLabel", {
			Name = "Glyph",
			Size = UDim2.fromOffset(chars > 2 and 34 or (chars > 1 and 26 or 22), 22),
			BackgroundColor3 = face or Color3.fromRGB(44, 46, 58),
			BackgroundTransparency = face and 0.05 or 0.1,
			Font = HEAD_FONT,
			TextSize = chars > 2 and 9 or 12,
			TextColor3 = Color3.new(1, 1, 1),
			Text = text,
			Parent = parent,
		}, { corner(face and 11 or 5), textStroke(1) })
	end

	function HUD.BuildPadLegend()
		if legend then
			legend:Destroy()
		end
		local C = Config
		local rows = {
			{ C.M1Keys, "PUNCH" }, { C.BlockKeys, "BLOCK" }, { C.DashKeys, "DASH" },
			{ { Enum.KeyCode.ButtonA }, "JUMP" }, { C.SpecialKeys, "SPECIAL" }, { C.UltKeys, "AWAKEN" },
			{ C.ShiftLockKeys, "SHIFT LOCK" }, { C.UseItemKeys, "ITEM" }, { C.LockOnKeys, "LOCK ON" },
			{ C.EmoteKeys, "EMOTES" }, { C.ShopKeys, "SHOP" }, { C.ContextKeys, "FINISH" },
		}
		legend = make("Frame", {
			Name = "PadLegend",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.fromOffset(2 * 136 + 14, 6 * 24 + 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.35,
			Parent = gui,
		}, {
			corner(8),
			edge(0.7),
			make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
			make("UIGridLayout", {
				CellSize = UDim2.fromOffset(136, 22),
				CellPadding = UDim2.fromOffset(0, 2),
				FillDirection = Enum.FillDirection.Vertical,
				FillDirectionMaxCells = 6,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		autoScale(legend)
		for i, row in rows do
			local key = padKey(row[1])
			if key then
				local cell = make("Frame", { Name = row[2], BackgroundTransparency = 1, LayoutOrder = i, Parent = legend }, {
					make("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				})
				glyph(key, cell).LayoutOrder = 1
				make("TextLabel", {
					Name = "Label",
					Size = UDim2.fromOffset(92, 22),
					BackgroundTransparency = 1,
					Font = UI_FONT,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.new(1, 1, 1),
					Text = row[2],
					LayoutOrder = 2,
					Parent = cell,
				}, { textStroke(1) })
			end
		end
		return legend
	end

	function HUD.ShowPadLegend(on)
		if on and not legend and gui then
			HUD.BuildPadLegend()
		end
		if legend then
			legend.Visible = on == true
		end
	end
end

---------------------------------------------------------------------------
-- HERO RANK (Config.Ranks: all-time kills), SETTINGS (cosmetics, music)
-- and TOP HEROES (the kills leaderboard, L)
---------------------------------------------------------------------------
do
	local card, rankName, statsLine, rankFill, strip
	local settingsPanel, settingsCbs = nil, {}
	local settingRows, settingValues = {}, { WearCosmetics = true, ShowCosmetics = true, Music = true, Blood = true }
	local boardPanel, boardRows, boardMe, ladder
	local myKills = 0
	local ON_GREEN = Color3.fromRGB(56, 170, 84)
	local OFF_GREY = Color3.fromRGB(80, 82, 96)
	local SETTINGS = {
		{ Key = "WearCosmetics", Label = "MY COSMETICS", Info = "Wear your character's signature look (everyone sees it)" },
		{ Key = "ShowCosmetics", Label = "SHOW COSMETICS", Info = "See other players' cosmetics on your screen" },
		{ Key = "Music", Label = "ULT MUSIC", Info = "Ult themes while someone's ult is up" },
		{ Key = "Blood", Label = "BLOOD", Info = "Blood on hard hits and KOs (on your screen)" },
		-- (round 65, like JJS) off until you switch it on
		{ Key = "AutoRun", Label = "AUTO RUN", Info = "Moving is running - no double tap or Ctrl", Default = false },
		-- (round 68) the controller's camera: a step at a time (click cycles)
		{
			Key = "PadSensitivity", Label = "CONTROLLER SENSITIVITY", Info = "How fast the right stick turns the camera (click to change)",
			-- (the steps here: this list is built before the HUD is handed Config)
			Steps = { 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3 }, Default = 1,
		},
		{ Key = "RobloxCamera", Label = "ROBLOX CAMERA", Info = "Controller: Roblox's own camera and its sensitivity setting", Default = false },
	}

	local function hex(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
	end

	-- a glass panel in the middle of the screen, with its title and an X
	local function panel(name, title, subtitle, w, h, onClose)
		local p = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = Color3.fromRGB(16, 18, 28),
			BackgroundTransparency = 0.06,
			Visible = false,
			ZIndex = 60,
			Parent = gui,
		}, { stroke(3), corner(10) })
		autoScale(p)
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(18, 10),
			Size = UDim2.new(1, -70, 0, 36),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 36,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = title,
			ZIndex = 61,
			Parent = p,
		}, { textStroke(2.5) })
		make("TextLabel", {
			Name = "Subtitle",
			Position = UDim2.fromOffset(20, 46),
			Size = UDim2.new(1, -40, 0, 14),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(170, 176, 204),
			Text = subtitle,
			ZIndex = 61,
			Parent = p,
		})
		local close = make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.fromRGB(170, 60, 60),
			Font = UI_FONT,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "X",
			ZIndex = 62,
			Parent = p,
		}, { corner(6), stroke(2) })
		close.MouseButton1Click:Connect(onClose)
		return p
	end

	-- the rank card (top-right, beside the wallet) and its two buttons
	function HUD.BuildRankCard(player)
		if card or not gui then
			return
		end
		card = make("Frame", {
			Name = "RankCard",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 58),
			Size = UDim2.fromOffset(150, 42),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			Parent = gui,
		}, { edge(), corner(3) })
		strip = make("Frame", {
			Name = "Strip",
			Size = UDim2.new(0, 3, 1, 0),
			BorderSizePixel = 0,
			Parent = card,
		})
		rankName = make("TextLabel", {
			Name = "Rank",
			Position = UDim2.fromOffset(9, 3),
			Size = UDim2.new(1, -14, 0, 17),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "STUDENT",
			ZIndex = 2,
			Parent = card,
		}, { textStroke(1.5), make("UITextSizeConstraint", { MaxTextSize = 15 }) })
		statsLine = make("TextLabel", {
			Name = "Stats",
			Position = UDim2.fromOffset(9, 20),
			Size = UDim2.new(1, -14, 0, 12),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "KILLS 0   STREAK 0",
			ZIndex = 2,
			Parent = card,
		}, { textStroke(1) })
		local bar = make("Frame", {
			Name = "Progress",
			Position = UDim2.new(0, 9, 1, -7),
			Size = UDim2.new(1, -16, 0, 3),
			BackgroundColor3 = Color3.fromRGB(60, 62, 76),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = card,
		})
		rankFill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = bar,
		})
		for i, b in { { "⚙ SETTINGS", "SettingsButton" }, { "🏆 TOP [L]", "BoardButton" } } do
			local btn = make("TextButton", {
				Name = b[2],
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, i == 1 and -93 or -16, 0, 104),
				Size = UDim2.fromOffset(73, 22),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				Font = UI_FONT,
				TextSize = 10,
				TextColor3 = Color3.new(1, 1, 1),
				Text = b[1],
				AutoButtonColor = true,
				Parent = gui,
			}, { edge(), corner(3) })
			btn.MouseButton1Click:Connect(function()
				if i == 1 then
					HUD.ToggleSettings()
				else
					HUD.ToggleBoard()
				end
			end)
		end
		HUD.SetRank(0, 0)
		task.spawn(function()
			local stats = player:WaitForChild("leaderstats", 30)
			if not stats then
				return
			end
			local kills, streak = stats:WaitForChild("Kills", 10), stats:WaitForChild("Streak", 10)
			if not kills or not streak then
				return
			end
			local function update()
				HUD.SetRank(kills.Value, streak.Value)
			end
			kills.Changed:Connect(update)
			streak.Changed:Connect(update)
			update()
		end)
	end

	-- what the leaderboard's own line says about you
	local function refreshMe()
		if not boardMe then
			return
		end
		local index, rank, nextRank = Config.RankOf(myKills)
		local text = string.format('YOU  <font color="%s"><b>%s</b></font>  ·  %d KILLS', hex(rank.Color), rank.Name, myKills)
		if nextRank then
			text ..= string.format('  ·  <font color="%s">%s</font> in %d', hex(nextRank.Color), nextRank.Name, nextRank.Kills - myKills)
		else
			text ..= "  ·  THE TOP"
		end
		boardMe.Text = text
		for i, step in ladder or {} do
			step.Row.BackgroundTransparency = i == index and 0.1 or 0.75
			step.Here.Visible = i == index
		end
	end

	-- your kills and streak: the rank, its colour, the way to the next one
	function HUD.SetRank(kills, streak)
		myKills = kills or 0
		if not card then
			return
		end
		local _, rank, nextRank = Config.RankOf(myKills)
		rankName.Text = rank.Name
		rankName.TextColor3 = rank.Color
		strip.BackgroundColor3 = rank.Color
		rankFill.BackgroundColor3 = rank.Color
		statsLine.Text = string.format("KILLS %d   STREAK %d", myKills, streak or 0)
		statsLine.TextColor3 = (streak or 0) >= 3 and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1)
		local k = 1
		if nextRank then
			k = math.clamp((myKills - rank.Kills) / math.max(nextRank.Kills - rank.Kills, 1), 0, 1)
		end
		rankFill.Size = UDim2.fromScale(k, 1)
		refreshMe()
	end

	-- a new rank: a big banner for yours, a line in the feed for anyone else's
	function HUD.RankUp(data, mine)
		local rank = Config.Ranks[data.Index or 1] or Config.Ranks[1]
		local color = rank.Color
		if not mine then
			if not feedList then
				return
			end
			for _, child in feedList:GetChildren() do
				if child:IsA("GuiObject") then
					child.LayoutOrder += 1
					if child.LayoutOrder > 5 then
						child:Destroy()
					end
				end
			end
			local row = make("TextLabel", {
				LayoutOrder = 0,
				Size = UDim2.fromOffset(330, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				Font = UI_FONT,
				TextSize = 13,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.new(1, 1, 1),
				Text = string.format('%s is now <font color="%s"><b>%s</b></font>', tostring(data.Player or "?"), hex(color), rank.Name),
				Parent = feedList,
			}, { corner(3), edge(), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10) }) })
			task.delay(6, function()
				if row.Parent then
					tween(row, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
					task.wait(0.42)
					row:Destroy()
				end
			end)
			return
		end
		if not gui then
			return
		end
		local old = gui:FindFirstChild("RankUp")
		if old then
			old:Destroy()
		end
		local banner = make("Frame", {
			Name = "RankUp",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.2),
			Size = UDim2.fromOffset(560, 118),
			BackgroundColor3 = Color3.fromRGB(10, 10, 14),
			BackgroundTransparency = 0.25,
			ZIndex = 70,
			Parent = gui,
		}, {
			make("UIStroke", { Thickness = 3, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.18, 0),
					NumberSequenceKeypoint.new(0.82, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		local top = make("TextLabel", {
			Name = "Label",
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "R A N K   U P",
			ZIndex = 71,
			Parent = banner,
		}, { textStroke(2) })
		local name = make("TextLabel", {
			Name = "RankName",
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 60,
			TextColor3 = color,
			Text = rank.Name,
			ZIndex = 71,
			Parent = banner,
		}, { textStroke(3) })
		local nextRank = Config.Ranks[(data.Index or 1) + 1]
		local sub = make("TextLabel", {
			Name = "Next",
			Position = UDim2.new(0, 0, 1, -26),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(200, 204, 225),
			Text = nextRank and string.format("NEXT: %s AT %d KILLS", nextRank.Name, nextRank.Kills) or "THE SYMBOL OF PEACE",
			ZIndex = 71,
			Parent = banner,
		}, { textStroke(1) })
		local scale = make("UIScale", { Scale = 1.6, Parent = banner })
		tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3.2, function()
			if banner.Parent then
				tween(banner, 0.5, { BackgroundTransparency = 1 })
				for _, label in { top, name, sub } do
					tween(label, 0.5, { TextTransparency = 1 })
				end
				task.wait(0.52)
				banner:Destroy()
			end
		end)
	end

	-- SETTINGS: switches for your cosmetics, everyone's, and the music
	-- cbs: OnSet(key, on)
	function HUD.BuildSettings(cbs)
		settingsCbs = cbs or {}
		if settingsPanel or not gui then
			return
		end
		settingsPanel = panel("Settings", "SETTINGS", "Saved with your progress", 380, 72 + #SETTINGS * 58 + 12, function()
			HUD.ToggleSettings(false)
		end)
		for i, def in SETTINGS do
			local row = make("Frame", {
				Name = def.Key,
				Position = UDim2.fromOffset(14, 72 + (i - 1) * 58),
				Size = UDim2.new(1, -28, 0, 50),
				BackgroundColor3 = Color3.fromRGB(28, 31, 46),
				ZIndex = 61,
				Parent = settingsPanel,
			}, { corner(6) })
			make("TextLabel", {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -110, 0, 20),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = def.Label,
				ZIndex = 62,
				Parent = row,
			})
			make("TextLabel", {
				Position = UDim2.fromOffset(12, 27),
				Size = UDim2.new(1, -110, 0, 16),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 10,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(160, 166, 196),
				Text = def.Info,
				ZIndex = 62,
				Parent = row,
			})
			local switch = make("TextButton", {
				Name = "Switch",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(78, 30),
				Font = HEAD_FONT,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 62,
				Parent = row,
			}, { corner(6), stroke(1.5) })
			settingRows[def.Key] = switch
			switch.MouseButton1Click:Connect(function()
				local on
				if def.Steps then
					-- (a stepped setting: the next step, round to the first)
					local now, at = tonumber(settingValues[def.Key]) or def.Default or 1, 0
					for k, v in def.Steps do
						if math.abs(v - now) < 1e-3 then
							at = k
						end
					end
					on = def.Steps[at % #def.Steps + 1]
				else
					on = not settingValues[def.Key]
				end
				HUD.SetSetting(def.Key, on)
				if settingsCbs.OnSet then
					settingsCbs.OnSet(def.Key, on)
				end
			end)
			local value = settingValues[def.Key]
			if value == nil then
				if def.Steps then
					value = def.Default or 1
				else
					value = def.Default ~= false
				end
			end
			HUD.SetSetting(def.Key, value)
		end
	end

	-- how a switch reads (the saved value coming back, or a click)
	function HUD.SetSetting(key, on)
		if type(on) == "number" then
			-- (round 68) a stepped setting: its value, as a percentage
			settingValues[key] = on
			local row = settingRows[key]
			if row then
				row.Text = string.format("%d%%", math.floor(on * 100 + 0.5))
				row.BackgroundColor3 = Color3.fromRGB(64, 104, 196)
			end
			return
		end
		settingValues[key] = on ~= false
		local switch = settingRows[key]
		if switch then
			switch.Text = settingValues[key] and "ON" or "OFF"
			switch.BackgroundColor3 = settingValues[key] and ON_GREEN or OFF_GREY
		end
	end

	function HUD.GetSetting(key)
		return settingValues[key]
	end

	function HUD.ToggleSettings(force)
		if not settingsPanel then
			return false
		end
		local open = force
		if open == nil then
			open = not settingsPanel.Visible
		end
		settingsPanel.Visible = open
		if open and boardPanel then
			boardPanel.Visible = false
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Settings")
		end
		return open
	end

	function HUD.SettingsVisible()
		return settingsPanel ~= nil and settingsPanel.Visible
	end

	-- (round 59) AWAKENING OUTFIT (the phone's OUTFIT app): your saved Roblox
	-- outfits, a card each, and your own avatar; whichever you pick, you wear
	-- while you're awakened (Config.AwakeningOutfits). The list itself comes
	-- from your own machine (callbacks.OnOpen - it asks Roblox, with your say-so).
	local fitPanel, fitGrid, fitStatus, fitAllow, fitNow
	local fitCbs, fitCards, fitNames, fitChosen = {}, {}, {}, 0

	function HUD.SetOutfitCallbacks(cbs)
		fitCbs = cbs or {}
	end

	local function fitCard(id, name, order)
		local card = make("TextButton", {
			Name = "Fit_" .. id,
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(28, 31, 46),
			Text = "",
			ZIndex = 61,
			Parent = fitGrid,
		}, {
			corner(8),
			make("UIStroke", { Name = "Ring", Color = Color3.fromRGB(255, 212, 64), Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		if id == 0 then
			make("TextLabel", {
				Name = "Thumb",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 104),
				BackgroundColor3 = Color3.fromRGB(40, 44, 64),
				Font = HEAD_FONT,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = Color3.fromRGB(200, 206, 230),
				Text = "YOUR OWN\nAVATAR",
				ZIndex = 62,
				Parent = card,
			}, { corner(6) })
		else
			make("ImageLabel", {
				Name = "Thumb",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 104),
				BackgroundColor3 = Color3.fromRGB(40, 44, 64),
				Image = "rbxthumb://type=Outfit&id=" .. id .. "&w=150&h=150",
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 62,
				Parent = card,
			}, { corner(6) })
		end
		make("TextLabel", {
			Name = "Label",
			Position = UDim2.new(0, 6, 1, -32),
			Size = UDim2.new(1, -12, 0, 26),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.new(1, 1, 1),
			Text = id == 0 and "NONE" or string.upper(name),
			ZIndex = 62,
			Parent = card,
		})
		make("TextLabel", {
			Name = "Chip",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(40, 18),
			BackgroundColor3 = Color3.fromRGB(255, 212, 64),
			Font = HEAD_FONT,
			TextSize = 10,
			TextColor3 = Color3.new(0, 0, 0),
			Text = "ON",
			Visible = false,
			ZIndex = 63,
			Parent = card,
		}, { corner(9) })
		fitNames[id] = id == 0 and "your own avatar" or name
		fitCards[id] = card
		card.MouseButton1Click:Connect(function()
			if fitCbs.OnPick then
				fitCbs.OnPick(id)
			end
		end)
		return card
	end

	local function buildFits()
		if fitPanel or not gui then
			return
		end
		fitPanel = panel("Outfits", "AWAKENING OUTFIT", "Pick one of your saved Roblox outfits - you'll wear it while you're awakened", 600, 460, function()
			HUD.ToggleOutfits(false)
		end)
		fitNow = make("TextLabel", {
			Name = "Now",
			Position = UDim2.fromOffset(20, 68),
			Size = UDim2.new(1, -160, 0, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = "AWAKENED IN: YOUR OWN AVATAR",
			ZIndex = 61,
			Parent = fitPanel,
		})
		fitAllow = make("TextButton", {
			Name = "Allow",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 64),
			Size = UDim2.fromOffset(120, 26),
			BackgroundColor3 = Color3.fromRGB(52, 110, 200),
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "ALLOW ACCESS",
			Visible = false,
			ZIndex = 62,
			Parent = fitPanel,
		}, { corner(6), stroke(1.5) })
		fitAllow.MouseButton1Click:Connect(function()
			if fitCbs.OnRetry then
				fitCbs.OnRetry()
			end
		end)
		fitGrid = make("ScrollingFrame", {
			Name = "Grid",
			Position = UDim2.fromOffset(14, 98),
			Size = UDim2.new(1, -28, 1, -112),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 61,
			Parent = fitPanel,
		}, { make("UIGridLayout", { CellSize = UDim2.fromOffset(128, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
		fitStatus = make("TextLabel", {
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.new(1, -40, 0, 44),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 206, 230),
			Text = "",
			Visible = false,
			ZIndex = 62,
			Parent = fitPanel,
		})
		fitCard(0, "", 0)
		HUD.MarkOutfit(fitChosen)
	end

	function HUD.ToggleOutfits(force)
		buildFits()
		if not fitPanel then
			return false
		end
		local open = force
		if open == nil then
			open = not fitPanel.Visible
		end
		fitPanel.Visible = open
		if open then
			if settingsPanel then
				settingsPanel.Visible = false
			end
			if boardPanel then
				boardPanel.Visible = false
			end
			if fitCbs.OnOpen then
				fitCbs.OnOpen()
			end
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Outfits")
		end
		return open
	end

	function HUD.OpenOutfits()
		return HUD.ToggleOutfits(true)
	end

	function HUD.OutfitsVisible()
		return fitPanel ~= nil and fitPanel.Visible
	end

	-- the outfits ({ Id, Name } each) and a line under them (asking, none
	-- saved, no access - askAgain shows the button to ask again)
	function HUD.SetOutfitList(list, status, askAgain)
		buildFits()
		if not fitPanel then
			return
		end
		for id, card in fitCards do
			if id ~= 0 then
				card:Destroy()
				fitCards[id] = nil
			end
		end
		for i, o in list or {} do
			if type(o.Id) == "number" and o.Id > 0 and not fitCards[o.Id] then
				fitCard(o.Id, tostring(o.Name or "Outfit"), i)
			end
		end
		fitStatus.Text = status or ""
		fitStatus.Visible = (status or "") ~= ""
		fitAllow.Visible = askAgain == true
		HUD.MarkOutfit(fitChosen)
	end

	-- the one you'll wear (0: your own avatar)
	function HUD.MarkOutfit(id)
		fitChosen = id or 0
		for cid, card in fitCards do
			local on = cid == fitChosen
			card.Ring.Transparency = on and 0 or 1
			card.Chip.Visible = on
		end
		if fitNow then
			local name = fitNames[fitChosen] or (fitChosen == 0 and "your own avatar" or "a saved outfit")
			fitNow.Text = "AWAKENED IN: " .. string.upper(name)
		end
	end

	-- TOP HEROES: the all-time kills board, and the ladder of ranks beside it
	function HUD.BuildBoard()
		if boardPanel or not gui then
			return
		end
		local size = (Config.Leaderboard and Config.Leaderboard.Size) or 10
		boardPanel = panel("TopHeroes", "TOP HEROES", "Most kills of all time - every server", 560, 74 + size * 25 + 44, function()
			HUD.ToggleBoard(false)
		end)
		boardRows = {}
		for i = 1, size do
			local row = make("Frame", {
				Name = "Row" .. i,
				Position = UDim2.fromOffset(14, 70 + (i - 1) * 25),
				Size = UDim2.fromOffset(330, 23),
				BackgroundColor3 = i % 2 == 1 and Color3.fromRGB(30, 33, 48) or Color3.fromRGB(24, 26, 38),
				ZIndex = 61,
				Parent = boardPanel,
			}, { corner(4) })
			local place = make("TextLabel", {
				Name = "Place",
				Size = UDim2.fromOffset(34, 23),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 13,
				TextColor3 = i == 1 and Color3.fromRGB(255, 212, 64) or i == 2 and Color3.fromRGB(210, 214, 230) or i == 3 and Color3.fromRGB(215, 140, 80) or Color3.fromRGB(150, 154, 178),
				Text = "#" .. i,
				ZIndex = 62,
				Parent = row,
			})
			local name = make("TextLabel", {
				Name = "PlayerName",
				Position = UDim2.fromOffset(36, 0),
				Size = UDim2.fromOffset(140, 23),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "-",
				ZIndex = 62,
				Parent = row,
			})
			local rank = make("TextLabel", {
				Name = "Rank",
				Position = UDim2.fromOffset(178, 0),
				Size = UDim2.fromOffset(90, 23),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(150, 154, 178),
				Text = "",
				ZIndex = 62,
				Parent = row,
			})
			local kills = make("TextLabel", {
				Name = "Kills",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.fromOffset(60, 23),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				ZIndex = 62,
				Parent = row,
			})
			boardRows[i] = { Row = row, Place = place, Name = name, Rank = rank, Kills = kills }
		end
		-- the ladder: every rank and the kills it takes, yours lit up
		ladder = {}
		make("TextLabel", {
			Position = UDim2.fromOffset(356, 50),
			Size = UDim2.fromOffset(190, 16),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(170, 176, 204),
			Text = "HERO RANKS",
			ZIndex = 61,
			Parent = boardPanel,
		})
		for i, r in Config.Ranks do
			local row = make("Frame", {
				Name = "Rank" .. i,
				Position = UDim2.fromOffset(356, 70 + (#Config.Ranks - i) * 30),
				Size = UDim2.fromOffset(190, 27),
				BackgroundColor3 = Color3.fromRGB(34, 37, 54),
				BackgroundTransparency = 0.75,
				ZIndex = 61,
				Parent = boardPanel,
			}, { corner(4), make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = r.Color, BorderSizePixel = 0, ZIndex = 62 }) })
			make("TextLabel", {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -60, 1, 0),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = r.Color,
				Text = r.Name,
				ZIndex = 62,
				Parent = row,
			}, { textStroke(1) })
			make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.fromOffset(50, 27),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(200, 204, 225),
				Text = r.Kills .. "+",
				ZIndex = 62,
				Parent = row,
			})
			local here = make("TextLabel", {
				Name = "Here",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(0, -4, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 12,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "▶",
				Visible = false,
				ZIndex = 62,
				Parent = row,
			})
			ladder[i] = { Row = row, Here = here }
		end
		boardMe = make("TextLabel", {
			Name = "You",
			Position = UDim2.new(0, 14, 1, -36),
			Size = UDim2.new(1, -28, 0, 24),
			BackgroundColor3 = Color3.fromRGB(34, 37, 54),
			Font = UI_FONT,
			TextSize = 12,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 61,
			Parent = boardPanel,
		}, { corner(4), make("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })
		refreshMe()
	end

	-- the board's rows: { { UserId, Name, Kills }, ... } best first
	function HUD.SetBoard(list, myUserId)
		if not boardRows then
			HUD.BuildBoard()
		end
		for i, row in boardRows or {} do
			local e = list and list[i]
			if e then
				local _, rank = Config.RankOf(e.Kills or 0)
				row.Name.Text = tostring(e.Name or "?")
				row.Name.TextColor3 = e.UserId == myUserId and Color3.fromRGB(255, 226, 92) or Color3.new(1, 1, 1)
				row.Rank.Text = rank.Short or rank.Name
				row.Rank.TextColor3 = rank.Color
				row.Kills.Text = tostring(e.Kills or 0)
			else
				row.Name.Text = "-"
				row.Name.TextColor3 = Color3.fromRGB(110, 114, 136)
				row.Rank.Text = ""
				row.Kills.Text = ""
			end
		end
	end

	function HUD.ToggleBoard(force)
		if not boardPanel then
			HUD.BuildBoard()
		end
		if not boardPanel then
			return false
		end
		local open = force
		if open == nil then
			open = not boardPanel.Visible
		end
		boardPanel.Visible = open
		if open and settingsPanel then
			settingsPanel.Visible = false
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Board")
		end
		return open
	end

	function HUD.BoardVisible()
		return boardPanel ~= nil and boardPanel.Visible
	end

	-- (a controller's first pick in either panel)
	function HUD.SettingsFirstButton(which)
		if which == "Board" then
			return boardPanel and boardPanel:FindFirstChild("Close")
		elseif which == "Outfits" then
			return fitCards[0]
		end
		return settingRows[SETTINGS[1].Key]
	end
end

---------------------------------------------------------------------------
-- UNO at Tony's: the table's panel along the bottom of the screen while
-- you're sat at one. The others round the top (their card counts, whose
-- turn, UNO!), the pile and the deck in the middle, your hand along the
-- bottom - real UNO cards: the colour, a white oval tilted across it, the
-- value big in the middle and small in the corners.
---------------------------------------------------------------------------
do
	local UNO = { cbs = {}, state = nil, cards = {}, chips = {} }
	local CARD = {
		R = Color3.fromRGB(226, 52, 52), Y = Color3.fromRGB(246, 200, 44), G = Color3.fromRGB(60, 172, 84), B = Color3.fromRGB(40, 112, 222), W = Color3.fromRGB(28, 28, 34),
	}
	local COLOR_NAMES = { R = "RED", Y = "YELLOW", G = "GREEN", B = "BLUE" }

	local function valueText(card)
		if card == "WW" then
			return "W"
		elseif card == "WF" then
			return "+4"
		end
		local v = string.sub(card, 2)
		return ({ S = "⊘", R = "⇄", D = "+2" })[v] or v
	end

	-- a card: w x h, the look above (a wild's oval is the four colours)
	local function makeCard(parent, card, w, h, z)
		local color = string.sub(card or "W", 1, 1)
		local fill = card and (CARD[color] or CARD.W) or Color3.fromRGB(20, 20, 24)
		local b = make("TextButton", {
			Name = "Card",
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = fill,
			AutoButtonColor = false,
			Text = "",
			ZIndex = z,
			Parent = parent,
		}, { corner(math.floor(w * 0.12)), make("UIStroke", { Name = "Border", Thickness = 3, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local oval = make("Frame", {
			Name = "Oval",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.58),
			Rotation = -24,
			BackgroundColor3 = card and Color3.new(1, 1, 1) or Color3.fromRGB(196, 32, 38),
			ZIndex = z + 1,
			Parent = b,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		if card and color == "W" then
			-- (a wild: the four colours in the oval)
			for i, c in { "R", "B", "Y", "G" } do
				make("Frame", {
					Position = UDim2.fromScale(((i - 1) % 2) * 0.5, math.floor((i - 1) / 2) * 0.5),
					Size = UDim2.fromScale(0.5, 0.5),
					BackgroundColor3 = CARD[c],
					BorderSizePixel = 0,
					ZIndex = z + 1,
					Parent = oval,
				})
			end
		end
		make("TextLabel", {
			Name = "Value",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			Text = card and valueText(card) or "UNO",
			TextColor3 = card and (color == "W" and Color3.new(1, 1, 1) or fill) or Color3.fromRGB(246, 200, 44),
			ZIndex = z + 2,
			Parent = b,
		}, { make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }), make("UIPadding", {
			PaddingTop = UDim.new(0.26, 0), PaddingBottom = UDim.new(0.26, 0), PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0),
		}) })
		if card then
			for k, spot in { { UDim2.fromOffset(4, 2), Enum.TextXAlignment.Left }, { UDim2.new(1, -4 - w * 0.4, 1, -2 - h * 0.2), Enum.TextXAlignment.Right } } do
				make("TextLabel", {
					Name = k == 1 and "Corner" or "Corner2",
					Position = spot[1],
					Size = UDim2.fromOffset(w * 0.4, h * 0.2),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					TextScaled = true,
					TextXAlignment = spot[2],
					Text = valueText(card),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = z + 2,
					Parent = b,
				}, { make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0) }) })
			end
		end
		return b
	end
	HUD.MakeUnoCard = makeCard

	local function button(name, text, color, pos, size, parent)
		return make("TextButton", {
			Name = name,
			Position = pos,
			Size = size,
			BackgroundColor3 = color,
			Font = HEAD_FONT,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			Text = text,
			AutoButtonColor = true,
			Selectable = true,
			ZIndex = 72,
			Parent = parent,
		}, { corner(8), stroke(2), textStroke(1.5) })
	end

	-- cbs: OnPlay(index, color), OnDraw(), OnPass(), OnUno(), OnCatch(), OnStart(), OnLeave()
	function HUD.BuildUno(cbs)
		UNO.cbs = cbs or {}
		if UNO.panel or not gui then
			return
		end
		local panel = make("Frame", {
			Name = "Uno",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(980, 340),
			BackgroundColor3 = Color3.new(1, 1, 1), -- (the gradient is the felt: it multiplies this)
			BackgroundTransparency = 0,
			Visible = false,
			ZIndex = 70,
			Parent = gui,
		}, { corner(14), make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(196, 150, 70), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(34, 92, 60), Color3.fromRGB(16, 52, 34)), Rotation = 90 }) })
		autoScale(panel)
		UNO.panel = panel
		-- the logo
		local logo = make("Frame", {
			Name = "Logo",
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.fromOffset(92, 52),
			BackgroundColor3 = CARD.R,
			Rotation = -8,
			ZIndex = 71,
			Parent = panel,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1) }) })
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextSize = 34,
			TextColor3 = CARD.Y,
			Text = "UNO",
			ZIndex = 72,
			Parent = logo,
		}, { make("UIStroke", { Thickness = 2.5, Color = Color3.new(0, 0, 0) }) })
		-- the others round the top
		UNO.chipRow = make("Frame", {
			Name = "Players",
			Position = UDim2.fromOffset(120, 12),
			Size = UDim2.new(1, -250, 0, 48),
			BackgroundTransparency = 1,
			ZIndex = 71,
			Parent = panel,
		}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		UNO.leave = button("Leave", "LEAVE", Color3.fromRGB(120, 50, 50), UDim2.new(1, -118, 0, 14), UDim2.fromOffset(104, 32), panel)
		UNO.leave.TextSize = 13
		-- the middle: the deck, the pile, the colour, whose turn
		UNO.deck = makeCard(panel, nil, 72, 106, 72)
		UNO.deck.Name = "Deck"
		UNO.deck.Position = UDim2.new(0.5, -176, 0, 70)
		make("TextLabel", {
			Name = "DrawLabel",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(90, 16),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "DRAW",
			ZIndex = 72,
			Parent = UNO.deck,
		}, { textStroke(1) })
		UNO.pileHolder = make("Frame", {
			Name = "Pile",
			Position = UDim2.new(0.5, -86, 0, 62),
			Size = UDim2.fromOffset(82, 120),
			BackgroundTransparency = 1,
			ZIndex = 71,
			Parent = panel,
		})
		UNO.colorTag = make("TextLabel", {
			Name = "Color",
			Position = UDim2.new(0.5, 10, 0, 70),
			Size = UDim2.fromOffset(170, 28),
			BackgroundColor3 = CARD.R,
			Font = HEAD_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "RED",
			ZIndex = 72,
			Parent = panel,
		}, { corner(6), textStroke(1.5) })
		UNO.status = make("TextLabel", {
			Name = "Status",
			Position = UDim2.new(0.5, 10, 0, 104),
			Size = UDim2.fromOffset(300, 26),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 72,
			Parent = panel,
		}, { textStroke(1.5) })
		UNO.toast = make("TextLabel", {
			Name = "Toast",
			Position = UDim2.new(0.5, 10, 0, 132),
			Size = UDim2.fromOffset(320, 20),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(230, 236, 230),
			Text = "",
			ZIndex = 72,
			Parent = panel,
		}, { textStroke(1) })
		local timer = make("Frame", {
			Name = "Timer",
			Position = UDim2.new(0.5, 10, 0, 158),
			Size = UDim2.fromOffset(170, 8),
			BackgroundColor3 = Color3.fromRGB(10, 20, 14),
			ZIndex = 72,
			Parent = panel,
		}, { corner(4) })
		UNO.timerFill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 212, 64),
			BorderSizePixel = 0,
			ZIndex = 73,
			Parent = timer,
		}, { corner(4) })
		-- the buttons, right
		UNO.unoButton = button("UnoButton", "UNO!", CARD.R, UDim2.new(1, -150, 0, 64), UDim2.fromOffset(136, 44), panel)
		UNO.unoButton.TextSize = 22
		UNO.unoButton.Font = Enum.Font.FredokaOne
		UNO.catchButton = button("CatchButton", "CATCH!", Color3.fromRGB(236, 120, 30), UDim2.new(1, -150, 0, 114), UDim2.fromOffset(136, 34), panel)
		UNO.passButton = button("PassButton", "PASS", Color3.fromRGB(70, 74, 96), UDim2.new(1, -150, 0, 154), UDim2.fromOffset(136, 30), panel)
		UNO.startButton = button("StartButton", "DEAL!", Color3.fromRGB(56, 170, 84), UDim2.new(0.5, -70, 0, 120), UDim2.fromOffset(140, 42), panel)
		UNO.lobby = make("TextLabel", {
			Name = "Lobby",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 66),
			Size = UDim2.fromOffset(600, 48),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 20,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 72,
			Parent = panel,
		}, { textStroke(1.5) })
		-- your hand
		UNO.hand = make("ScrollingFrame", {
			Name = "Hand",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -28, 0, 138),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 6,
			ZIndex = 71,
			Parent = panel,
		}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }) })
		-- a wild: pick its colour
		UNO.picker = make("Frame", {
			Name = "ColorPicker",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(330, 120),
			BackgroundColor3 = Color3.fromRGB(16, 18, 26),
			Visible = false,
			ZIndex = 80,
			Parent = panel,
		}, { corner(12), stroke(3) })
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "PICK A COLOUR",
			ZIndex = 81,
			Parent = UNO.picker,
		})
		UNO.swatches = {}
		for i, c in { "R", "Y", "G", "B" } do
			local sw = make("TextButton", {
				Name = "Pick" .. c,
				Position = UDim2.fromOffset(16 + (i - 1) * 76, 38),
				Size = UDim2.fromOffset(70, 66),
				BackgroundColor3 = CARD[c],
				Font = HEAD_FONT,
				TextSize = 12,
				TextColor3 = Color3.new(1, 1, 1),
				Text = COLOR_NAMES[c],
				Selectable = true,
				ZIndex = 82,
				Parent = UNO.picker,
			}, { corner(10), stroke(2), textStroke(1) })
			sw.Activated:Connect(function()
				UNO.picker.Visible = false
				local index = UNO.pendingWild
				UNO.pendingWild = nil
				if index and UNO.cbs.OnPlay then
					UNO.cbs.OnPlay(index, c)
				end
			end)
			UNO.swatches[i] = sw
		end
		-- the buttons' jobs
		UNO.deck.Activated:Connect(function()
			if UNO.state and UNO.state.MyTurn and not UNO.state.Drawn and UNO.cbs.OnDraw then
				UNO.cbs.OnDraw()
			end
		end)
		for _, pair in { { UNO.unoButton, "OnUno" }, { UNO.catchButton, "OnCatch" }, { UNO.passButton, "OnPass" }, { UNO.startButton, "OnStart" }, { UNO.leave, "OnLeave" } } do
			pair[1].Activated:Connect(function()
				local fn = UNO.cbs[pair[2]]
				if fn then
					fn()
				end
			end)
		end
		-- the turn clock
		RunService.RenderStepped:Connect(function()
			local s = UNO.state
			if not panel.Visible or not s then
				return
			end
			if s.TurnEnds then
				local left = s.TurnEnds - workspace:GetServerTimeNow()
				local k = math.clamp(left / (s.TurnTime or 20), 0, 1)
				UNO.timerFill.Size = UDim2.fromScale(k, 1)
				UNO.timerFill.BackgroundColor3 = k < 0.25 and Color3.fromRGB(236, 80, 60) or Color3.fromRGB(255, 212, 64)
			end
			if s.Phase == "Lobby" and UNO.startAt then
				local n = math.max(0, math.ceil(UNO.startAt - os.clock()))
				UNO.lobby.Text = string.format("%d/4 AT THE TABLE  ·  DEALING IN %d", #(s.Seated or {}), n)
			end
		end)
	end

	local function isPlayable(card, top, color)
		local c = string.sub(card, 1, 1)
		return c == "W" or c == color or string.sub(card, 2) == string.sub(top or "", 2)
	end

	-- the state from the server: redraw everything
	function HUD.UnoState(s)
		if not UNO.panel then
			return
		end
		UNO.state = s
		UNO.panel.Visible = true
		if HUD.TouchSync then
			HUD.TouchSync()
		end
		local game_ = s.Phase == "Game"
		UNO.startAt = s.StartIn and os.clock() + s.StartIn or nil
		-- the lobby
		UNO.lobby.Visible = not game_
		UNO.startButton.Visible = not game_ and #(s.Seated or {}) >= 2
		if not game_ then
			UNO.lobby.Text = #(s.Seated or {}) >= 2 and string.format("%d/4 AT THE TABLE  ·  DEAL WHEN YOU'RE READY", #s.Seated)
				or "WAITING FOR SOMEONE TO SIT DOWN...  (2-4 PLAYERS)"
		end
		for _, name in { "deck", "pileHolder", "colorTag", "status", "toast", "unoButton", "catchButton", "passButton" } do
			UNO[name].Visible = game_
		end
		UNO.timerFill.Parent.Visible = game_
		UNO.picker.Visible = UNO.picker.Visible and game_
		-- the others
		for _, chip in UNO.chips do
			chip:Destroy()
		end
		table.clear(UNO.chips)
		for i, p in (game_ and s.Players or {}) do
			local chip = make("Frame", {
				Name = "Player" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(160, 46),
				BackgroundColor3 = p.Turn and Color3.fromRGB(70, 60, 20) or Color3.fromRGB(14, 30, 22),
				BackgroundTransparency = 0.1,
				ZIndex = 72,
				Parent = UNO.chipRow,
			}, { corner(8), make("UIStroke", { Thickness = p.Turn and 3 or 1, Color = p.Turn and Color3.fromRGB(255, 212, 64) or Color3.fromRGB(120, 150, 130), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			make("TextLabel", {
				Name = "Name",
				Position = UDim2.fromOffset(8, 3),
				Size = UDim2.new(1, -16, 0, 20),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = (p.Turn and "▶ " or "") .. tostring(p.Name),
				ZIndex = 73,
				Parent = chip,
			})
			make("TextLabel", {
				Name = "Count",
				Position = UDim2.fromOffset(8, 23),
				Size = UDim2.new(1, -16, 0, 18),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = p.Exposed and Color3.fromRGB(255, 140, 90) or Color3.fromRGB(210, 226, 214),
				Text = p.Count .. (p.Count == 1 and " card" or " cards") .. (p.Uno and "  ·  UNO!" or "") .. (p.Exposed and "  ·  CATCH THEM!" or ""),
				ZIndex = 73,
				Parent = chip,
			})
			UNO.chips[i] = chip
		end
		if not game_ then
			for _, c in UNO.cards do
				c:Destroy()
			end
			table.clear(UNO.cards)
			return
		end
		-- the pile, the colour, whose turn
		for _, c in UNO.pileHolder:GetChildren() do
			c:Destroy()
		end
		local top = makeCard(UNO.pileHolder, s.Top or "WW", 82, 120, 72)
		top.Name = "Top"
		top.Border.Color = CARD[s.Color] or Color3.new(1, 1, 1)
		top.Border.Thickness = 4
		UNO.colorTag.BackgroundColor3 = CARD[s.Color] or CARD.W
		UNO.colorTag.Text = (COLOR_NAMES[s.Color] or "?") .. "  ·  " .. ((s.Dir or 1) == 1 and "⟳" or "⟲") .. "  ·  DECK " .. tostring(s.Deck or "")
		local whose
		for _, p in s.Players or {} do
			if p.Turn then
				whose = p.Name
			end
		end
		UNO.status.Text = s.MyTurn and (s.Drawn and "PLAY IT, OR PASS" or "YOUR TURN!") or ((whose or "?") .. "'S TURN")
		UNO.status.TextColor3 = s.MyTurn and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1)
		UNO.passButton.Visible = s.MyTurn and s.Drawn ~= nil
		UNO.unoButton.Visible = s.CanUno == true
		UNO.catchButton.Visible = s.CanCatch == true
		UNO.deck.Border.Color = (s.MyTurn and not s.Drawn) and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1)
		-- your hand: the ones you can play stand up, the rest sit dim
		for _, c in UNO.cards do
			c:Destroy()
		end
		table.clear(UNO.cards)
		for i, card in s.Hand or {} do
			local can = s.MyTurn and isPlayable(card, s.Top, s.Color) and (s.Drawn == nil or s.Drawn == i)
			local holder = make("Frame", {
				Name = "Slot" .. i,
				LayoutOrder = i,
				Size = UDim2.fromOffset(74, 124),
				BackgroundTransparency = 1,
				ZIndex = 72,
				Parent = UNO.hand,
			})
			local b = makeCard(holder, card, 74, 108, 73)
			b.Name = "Card" .. i
			b.Position = UDim2.fromOffset(0, can and 0 or 16)
			b.Selectable = can
			if not can then
				local shade = make("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 76, Parent = b }, { corner(8) })
				shade.Active = false
			end
			b.Activated:Connect(function()
				if not can then
					return
				end
				if string.sub(card, 1, 1) == "W" then
					UNO.pendingWild = i
					UNO.picker.Visible = true
					if UNO.cbs.OnPicker then
						UNO.cbs.OnPicker(UNO.swatches[1])
					end
				elseif UNO.cbs.OnPlay then
					UNO.cbs.OnPlay(i)
				end
			end)
			UNO.cards[i] = holder
		end
	end

	-- a line of news (who played what, UNO!, who got caught)
	function HUD.UnoToast(text, color)
		if not UNO.toast then
			return
		end
		UNO.toast.Text = tostring(text or "")
		UNO.toast.TextColor3 = typeof(color) == "Color3" and color:Lerp(Color3.new(1, 1, 1), 0.35) or Color3.fromRGB(230, 236, 230)
		UNO.toast.TextTransparency = 0
	end

	-- somebody went out: a big banner for a moment
	function HUD.UnoEnd(data)
		if not UNO.panel then
			return
		end
		local banner = make("TextLabel", {
			Name = "UnoWin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(520, 70),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextSize = 46,
			TextColor3 = data.You and Color3.fromRGB(255, 212, 64) or Color3.new(1, 1, 1),
			Text = data.You and "YOU WIN!" or ((data.Winner and (tostring(data.Winner) .. " WINS!")) or "GAME OVER"),
			ZIndex = 85,
			Parent = UNO.panel,
		}, { textStroke(3) })
		local sc = make("UIScale", { Scale = 1.8, Parent = banner })
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(2.6, function()
			if banner.Parent then
				tween(banner, 0.4, { TextTransparency = 1 })
				task.wait(0.42)
				banner:Destroy()
			end
		end)
	end

	function HUD.UnoHide()
		if UNO.panel then
			UNO.panel.Visible = false
			UNO.picker.Visible = false
			UNO.state = nil
		end
		if HUD.TouchSync then
			HUD.TouchSync()
		end
	end

	function HUD.UnoVisible()
		return UNO.panel ~= nil and UNO.panel.Visible
	end

	-- (a controller's pick when it's your turn: the first card you can play, else the deck)
	function HUD.UnoFirstButton()
		for _, holder in UNO.cards do
			local b = holder:FindFirstChildWhichIsA("TextButton")
			if b and b.Selectable then
				return b
			end
		end
		return UNO.deck
	end
end

---------------------------------------------------------------------------
-- TOUCH (a phone or a tablet): its own layout. The move boxes become round
-- buttons in reach of the right thumb, round the jump button, the way
-- Jujutsu Shenanigans lays them out - with HIT, BLOCK, RUN, ULT, EMOTE and a
-- FINISH that shows up when there's someone to finish. Everything else
-- shrinks to fit the screen and moves out from under your thumbs: health
-- and the ult at the bottom between the stick and the buttons, your
-- character up in the top bar, the kill feed top-centre, the wallet and
-- rank tucked into the top-right corner. (Roblox's own touch buttons for
-- the moves are off - these replace them.)
---------------------------------------------------------------------------
do
	local TOUCH = { on = false, saved = {}, buttons = {}, pad = nil, corner = nil }
	HUD.Touch = TOUCH
	-- name, the move box it wears (slots[i]) or a label, offset from the
	-- jump button's centre, size (a phone; a tablet's are bigger)
	TOUCH.LAYOUT = {
		{ "QuirkPunch", "HIT", -92, -2, 84 },
		{ "QuirkAbility1", 1, -172, 8, 60 },
		{ "QuirkAbility2", 2, -168, -70, 60 },
		{ "QuirkAbility3", 3, -104, -104, 60 },
		{ "QuirkExtra", 6, -30, -118, 60 },
		{ "QuirkSpecial", 4, -236, -40, 46 },
		{ "QuirkUlt", "ULT", -238, -102, 50 },
		{ "QuirkDash", 5, -2, -186, 50 },
		{ "QuirkBlock", "BLOCK", -70, -186, 50 },
		{ "QuirkSprint", "RUN", -138, -178, 46 },
		{ "QuirkFinish", "FINISH", -104, -250, 64 },
		{ "QuirkEmote", "EMOTE", -236, 24, 40 },
		{ "QuirkLockOn", "LOCK", -206, -166, 40 },
	}

	-- how far the HUD shrinks on this screen
	function HUD.TouchScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(vp.X / 1280, vp.Y / 620), 0.5, 1)
	end

	-- where the jump button is (Roblox's own layout), and how big to go
	function TOUCH.metrics()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		if math.min(vp.X, vp.Y) <= 500 then
			return -60, -55, 1
		end
		return -110, -150, 1.45
	end

	-- (round 82) A FINGER ON A BUTTON: a tap, a hold or a camera drag. The
	-- buttons sit right where a right thumb turns the camera, so nothing goes
	-- off the moment a finger lands; what it does next decides
	-- (Config.Look.Touch):
	--   it moves more than Slop from where it landed: a DRAG. It never fires,
	--     not even back over a button; it turns the camera instead
	--   it stays still for Commit (FastCommit for BLOCK and DASH): HELD. Down
	--     now, up when that finger lifts (at least TapHold after the down). A
	--     held finger that moves on keeps holding and turns the camera too
	--     (aiming a charge, a guard, an M1 chain)
	--   it lifts first: a TAP. Down on the lift, and for a move you can hold,
	--     up TapHold later (a BLOCK tap is a short guard: a parry try)
	-- A finger that starts on EMOTE never turns the camera.
	-- Only a finger that STARTS on a button counts: Roblox also hands a
	-- button the InputBegan of a finger that slides onto it from somewhere
	-- else (a camera swipe across the buttons). The finger is followed, not
	-- the button: the button's InputEnded fires when a finger slides off it,
	-- so only the finger's own End or Cancel lets go.
	-- [input] = { name, start, last, moved, t0, commit, state = "pending" /
	-- "held" / "drag", hold (an up is owed on the lift), heldAt, touch, conn }
	TOUCH.fingers = {}
	TOUCH.look = Vector2.zero -- this frame's drag for the camera (GUI pixels)
	TOUCH.tapUps = {} -- [name] = the up still owed a moment from now (TOUCH.owe)

	function TOUCH.cfg()
		return (Config and Config.Look and Config.Look.Touch) or {}
	end

	-- where the finger is (nil: no position to read - the test harness's
	-- finger, which counts as not moving)
	function TOUCH.at(input)
		local p = input.Position
		return p and Vector2.new(p.X, p.Y) or nil
	end

	-- each down / up goes in a thread of its own (as each button's own
	-- InputBegan was before): a move whose handler errors can't stop another
	-- finger's press in the same frame, or a tap's let-go being set up. It
	-- runs at once up to its first wait, so a RUN tap still shows on the lift.
	function TOUCH.fire(name, down)
		task.spawn(TOUCH.send, name, down)
	end

	function TOUCH.send(name, down)
		if callbacks.TouchAction then
			callbacks.TouchAction(name, down)
		end
	end

	-- a move a finger can hold (it has a let-go); the rest only press
	function TOUCH.holdable(name)
		if callbacks.TouchHoldable then
			return callbacks.TouchHoldable(name) == true
		end
		return true
	end

	-- down (a tap's up still owed on that button goes first: one up per down)
	function TOUCH.press(name)
		if TOUCH.tapUps[name] then
			TOUCH.tapUps[name] = nil
			TOUCH.fire(name, false)
		end
		TOUCH.fire(name, true)
	end

	-- an up owed a moment from now (a press, the pad hiding, Roblox's menu
	-- or the like sends it sooner: still only the one)
	function TOUCH.owe(name, after)
		local token = {}
		TOUCH.tapUps[name] = token
		task.delay(after, function()
			if TOUCH.tapUps[name] == token then
				TOUCH.tapUps[name] = nil
				TOUCH.fire(name, false)
			end
		end)
	end

	-- a tap: down now (straight away, inside the lift), up TapHold later
	function TOUCH.tap(name)
		TOUCH.press(name)
		if TOUCH.holdable(name) then
			TOUCH.owe(name, TOUCH.cfg().TapHold or 0.1)
		end
	end

	-- how far the finger's got from where it landed (the furthest so far)
	function TOUCH.track(f, input)
		local p = TOUCH.at(input)
		if p and f.start then
			f.moved = math.max(f.moved, (p - f.start).Magnitude)
			if f.state == "pending" and f.moved > (TOUCH.cfg().Slop or 10) then
				f.state = "drag"
			end
		end
		return p
	end

	-- the finger came up (or was cancelled: a pending press is dropped)
	function TOUCH.lift(input, cancelled)
		local f = TOUCH.fingers[input]
		if not f then
			return
		end
		TOUCH.fingers[input] = nil
		if f.conn then
			f.conn:Disconnect()
		end
		TOUCH.track(f, input) -- (a flick between two frames is still a drag)
		if f.state == "pending" and not cancelled then
			TOUCH.tap(f.name)
		elseif f.state == "held" and f.hold then
			-- (a hold that only just went down still lasts a tap's TapHold:
			-- a BLOCK lifted just past FastCommit would guard for a frame,
			-- shorter than a quicker tap's - and no parry)
			local left = (TOUCH.cfg().TapHold or 0.1) - (os.clock() - (f.heldAt or 0))
			if cancelled or left <= 0 then
				TOUCH.fire(f.name, false)
			else
				TOUCH.owe(f.name, left)
			end
		end
	end

	function TOUCH.wire(button, name)
		button.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if input.UserInputState ~= Enum.UserInputState.Begin or TOUCH.fingers[input] then
				return -- (slid on from somewhere else: a swipe across the buttons, not a press)
			end
			for _, g in TOUCH.fingers do
				if g.name == name and g.state ~= "drag" then
					return -- (a second finger on the same button)
				end
			end
			local cfg = TOUCH.cfg()
			local p = TOUCH.at(input)
			local f = {
				name = name, start = p, last = p, moved = 0, t0 = os.clock(), state = "pending", hold = false,
				commit = (cfg.FastCommit or {})[name] or cfg.Commit or 0.1, touch = kind == Enum.UserInputType.Touch,
			}
			TOUCH.fingers[input] = f
			f.conn = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				-- (read again every time: the test harness's finger has one
				-- signal for all its properties)
				local s = input.UserInputState
				if s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
					TOUCH.lift(input, s == Enum.UserInputState.Cancel)
				end
			end)
		end)
	end

	-- every frame, before the camera: each finger's movement and time
	function TOUCH.step()
		TOUCH.look = Vector2.zero -- (cleared every frame, used or not: no turn is saved up to jump later)
		if next(TOUCH.fingers) == nil then
			return
		end
		local now = os.clock()
		local slop = TOUCH.cfg().Slop or 10
		local due, gone = nil, nil
		for input, f in TOUCH.fingers do
			local s = input.UserInputState
			if s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
				gone = gone or {}
				gone[input] = s == Enum.UserInputState.Cancel -- (its signal never came: let go below)
			else
				local p = TOUCH.track(f, input)
				-- a drag turns the camera, and so does a held finger moved
				-- on past the slop (never one that started on EMOTE: that
				-- one only taps)
				if p and f.last and f.touch and f.moved > slop and f.name ~= "QuirkEmote" and (f.state == "drag" or f.state == "held") then
					TOUCH.look += p - f.last
				end
				f.last = p or f.last
				if f.state == "pending" and now - f.t0 >= f.commit then
					f.state = "held"
					due = due or {}
					table.insert(due, input)
				end
			end
		end
		for input, cancelled in gone or {} do
			TOUCH.lift(input, cancelled)
		end
		for _, input in due or {} do
			local f = TOUCH.fingers[input]
			if f and f.state == "held" then -- (still there: a press before it can hide the pad)
				f.hold = TOUCH.holdable(f.name)
				f.heldAt = os.clock()
				TOUCH.press(f.name)
			end
		end
	end

	-- let go of everything: every down that went gets its one up, a press
	-- still deciding is dropped (the pad hiding, Roblox's menu, a respawn,
	-- the app losing focus, leaving touch)
	function TOUCH.releaseAll()
		local list, owed = TOUCH.fingers, TOUCH.tapUps
		TOUCH.fingers, TOUCH.tapUps = {}, {}
		TOUCH.look = Vector2.zero
		for _, f in list do
			if f.conn then
				f.conn:Disconnect()
			end
		end
		for _, f in list do
			if f.state == "held" and f.hold then
				TOUCH.fire(f.name, false)
			end
		end
		for name in owed do
			TOUCH.fire(name, false)
		end
	end
	HUD.TouchRelease = TOUCH.releaseAll

	-- the drag since last asked, for the camera (QuirkClient), and cleared
	function HUD.TakeTouchLook()
		local d = TOUCH.look
		TOUCH.look = Vector2.zero
		return d
	end

	function TOUCH.build()
		if TOUCH.pad or not gui then
			return
		end
		TOUCH.pad = make("Frame", {
			Name = "TouchPad",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 5,
			Parent = gui,
		})
		-- the top-right corner's cards, all shrunk toward the corner together
		TOUCH.corner = make("Frame", {
			Name = "TouchCorner",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 6),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = gui,
		}, { make("UIScale", { Name = "TouchScale" }) })
		-- (round 82) the fingers on the buttons, every frame before the camera
		-- runs; and nothing stays held when Roblox's menu opens or the app
		-- loses focus (a swipe home, the notification shade)
		RunService:BindToRenderStep("QuirkTouchFingers", Enum.RenderPriority.Input.Value + 1, TOUCH.step)
		pcall(function()
			game:GetService("GuiService").MenuOpened:Connect(TOUCH.releaseAll)
		end)
		pcall(function()
			game:GetService("UserInputService").WindowFocusReleased:Connect(TOUCH.releaseAll)
		end)
		for _, spec in TOUCH.LAYOUT do
			if type(spec[2]) == "string" then
				local b = make("TextButton", {
					Name = "Touch" .. spec[2],
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = GLASS.Color,
					BackgroundTransparency = 0.25,
					AutoButtonColor = true,
					Font = HEAD_FONT,
					TextScaled = true,
					TextColor3 = Color3.new(1, 1, 1),
					Text = spec[2],
					Visible = spec[2] ~= "FINISH",
					Parent = TOUCH.pad,
				}, {
					make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					make("UIPadding", { PaddingLeft = UDim.new(0.16, 0), PaddingRight = UDim.new(0.16, 0), PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0) }),
				})
				if spec[2] == "HIT" then
					b.BackgroundColor3 = Color3.fromRGB(150, 34, 34)
				elseif spec[2] == "FINISH" then
					b.BackgroundColor3 = Color3.fromRGB(200, 40, 30)
				end
				TOUCH.buttons[spec[1]] = b
				TOUCH.wire(b, spec[1])
			end
		end
	end

	-- the finger-sized positions (they follow the screen size)
	function TOUCH.place()
		local jx, jy, k = TOUCH.metrics()
		for _, spec in TOUCH.LAYOUT do
			local pos = UDim2.new(1, jx + spec[3] * k, 1, jy + spec[4] * k)
			local size = UDim2.fromOffset(spec[5] * k, spec[5] * k)
			if type(spec[2]) == "string" then
				local b = TOUCH.buttons[spec[1]]
				if b then
					b.Position, b.Size = pos, size
				end
			else
				local slot = slots[spec[2]]
				if slot then
					slot.Frame.Position, slot.Frame.Size = pos, size
				end
			end
		end
		TOUCH.corner.TouchScale.Scale = HUD.TouchScale()
		for _, sc in autoScales do
			sc.Scale = HUD.TouchScale()
		end
	end

	-- a move box as a round button (or back the way it was)
	function TOUCH.slot(slot, name, on)
		local f = slot.Frame
		local saved = TOUCH.saved[f]
		local cornerObj = f:FindFirstChildOfClass("UICorner")
		local limit = slot.Name:FindFirstChildOfClass("UITextSizeConstraint")
		if on then
			if not saved then
				saved = {
					Parent = f.Parent, AnchorPoint = f.AnchorPoint, Position = f.Position, Size = f.Size,
					Corner = cornerObj and cornerObj.CornerRadius, NamePos = slot.Name.Position, NameSize = slot.Name.Size,
					Limit = limit and limit.MaxTextSize, T = f.BackgroundTransparency,
				}
				TOUCH.saved[f] = saved
			end
			if not slot.Tap then
				-- (round 82: round like the button it covers - a UICorner on
				-- the box doesn't round what's inside it, and a square Tap
				-- caught fingers in its corners)
				slot.Tap = make("TextButton", {
					Name = "Tap",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 10,
					Parent = f,
				}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
				TOUCH.wire(slot.Tap, name)
			end
			slot.Tap.Visible = true
			-- (the cooldown drains a round button as a circle, not a box)
			if not slot.Round then
				slot.Round = make("Frame", {
					Name = "Round",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BorderSizePixel = 0,
					ZIndex = 4,
					Parent = f,
				}, {
					make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1) }),
				})
			end
			slot.Round.Visible = true
			slot.Cover.Visible = false
			slot.Accent.Visible = false
			if slot.Sub then
				slot.Sub.Visible = false
			end
			local edge = f:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Thickness = 2
			end
			f.Parent = TOUCH.pad
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BackgroundTransparency = 0.25
			if cornerObj then
				cornerObj.CornerRadius = UDim.new(0.5, 0)
			end
			slot.Name.Position = UDim2.fromScale(0.12, 0.22)
			slot.Name.Size = UDim2.fromScale(0.76, 0.56)
			if limit then
				limit.MaxTextSize = 12
			end
		elseif saved then
			if slot.Tap then
				slot.Tap.Visible = false
			end
			if slot.Round then
				slot.Round.Visible = false
			end
			slot.Cover.Visible = true
			slot.Accent.Visible = true
			if slot.Sub then
				slot.Sub.Visible = true
			end
			local edge = f:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Thickness = 1
			end
			f.Parent = saved.Parent
			f.AnchorPoint, f.Position, f.Size = saved.AnchorPoint, saved.Position, saved.Size
			f.BackgroundTransparency = saved.T
			if cornerObj and saved.Corner then
				cornerObj.CornerRadius = saved.Corner
			end
			slot.Name.Position, slot.Name.Size = saved.NamePos, saved.NameSize
			if limit and saved.Limit then
				limit.MaxTextSize = saved.Limit
			end
		end
	end

	-- move a top-level piece (remembering where it was)
	function TOUCH.move(obj, on, anchor, pos, parent)
		if not obj then
			return
		end
		local saved = TOUCH.saved[obj]
		if on then
			if not saved then
				saved = { Parent = obj.Parent, AnchorPoint = obj.AnchorPoint, Position = obj.Position }
				TOUCH.saved[obj] = saved
			end
			if parent and obj.Parent ~= parent then
				obj.Parent = parent
			end
			if anchor then
				obj.AnchorPoint, obj.Position = anchor, pos
			end
		elseif saved then
			if obj.Parent ~= saved.Parent then
				obj.Parent = saved.Parent
			end
			obj.AnchorPoint, obj.Position = saved.AnchorPoint, saved.Position
		end
	end

	-- a UIScale of its own that only works while touch is on
	function TOUCH.shrink(obj, on, k)
		if not obj then
			return
		end
		local sc = obj:FindFirstChild("TouchScale")
		if not sc then
			sc = make("UIScale", { Name = "TouchScale", Parent = obj })
		end
		sc.Scale = on and HUD.TouchScale() * (k or 1) or 1
	end

	function HUD.ApplyTouch(on)
		if not gui then
			return
		end
		TOUCH.build()
		TOUCH.on = on
		HUD.TouchSync()
		for _, spec in TOUCH.LAYOUT do
			if type(spec[2]) == "number" and slots[spec[2]] then
				TOUCH.slot(slots[spec[2]], spec[1], on)
			end
		end
		-- health and the ult at the bottom, between the stick and the buttons
		local dock = vitals and vitals.Parent
		if dock then
			TOUCH.move(dock, on, Vector2.new(0.5, 1), UDim2.new(0.4, 0, 1, 0))
			local bar = dock:FindFirstChild("Abilities")
			if bar then
				bar.Visible = not on
			end
		end
		TOUCH.move(vitals, on, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8))
		TOUCH.move(modeTimer, on, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -84))
		-- the kill feed top-centre, the combo on the left
		TOUCH.move(feedList, on, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 48))
		TOUCH.shrink(feedList, on, 0.9)
		TOUCH.move(comboFrame, on, Vector2.new(0, 0.5), UDim2.new(0, 170, 0.36, 0))
		TOUCH.shrink(comboFrame, on)
		-- your bag on the left, above the stick
		local items = gui:FindFirstChild("Items")
		TOUCH.move(items, on, Vector2.new(0, 0), UDim2.fromOffset(8, 52))
		TOUCH.shrink(items, on)
		-- the wallet, shop, rank, settings, leaderboard, music: into the corner
		for _, name in { "Wallet", "ShopButton", "RankCard", "SettingsButton", "BoardButton", "MusicToggle" } do
			local obj = gui:FindFirstChild(name) or TOUCH.corner:FindFirstChild(name)
			if obj then
				TOUCH.move(obj, on, nil, nil, on and TOUCH.corner or nil)
			end
		end
		if on then
			TOUCH.place()
		else
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize
			for _, sc in autoScales do
				sc.Scale = vp and vp.Y > 0 and math.clamp(vp.Y / 720, 0.75, 1.5) or 1
			end
		end
	end

	-- (the buttons step aside while the quirk menu or a card game's up)
	function HUD.TouchSync()
		if TOUCH.pad then
			TOUCH.pad.Visible = TOUCH.on and not HUD.MenuVisible() and not HUD.UnoVisible()
			if not TOUCH.pad.Visible then
				TOUCH.releaseAll() -- (round 82: nothing stays held under a hidden pad - leaving touch too)
			end
		end
	end

	-- how much of the cooldown's left, as the dark part of the circle
	function HUD.TouchFill(slot, frac)
		local g = slot.Round:FindFirstChildOfClass("UIGradient")
		if not g then
			return
		end
		frac = math.clamp(frac, 0, 1)
		if frac <= 0.001 then
			g.Transparency = NumberSequence.new(1)
		elseif frac >= 0.999 then
			g.Transparency = NumberSequence.new(0.4)
		else
			local cut = 1 - frac
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(cut, 1),
				NumberSequenceKeypoint.new(math.min(cut + 0.002, 0.999), 0.4),
				NumberSequenceKeypoint.new(1, 0.4),
			})
		end
	end

	-- someone to finish: the FINISH button lights up
	function HUD.SetTouchFinish(visible)
		local b = TOUCH.buttons.QuirkFinish
		if b then
			b.Visible = visible == true
		end
	end

	-- RUN is a toggle on a phone: it shows when it's on
	function HUD.SetTouchRun(on)
		local b = TOUCH.buttons.QuirkSprint
		if b then
			b.BackgroundColor3 = on and Color3.fromRGB(40, 150, 90) or GLASS.Color
		end
	end

	-- the ULT button in your colour when it's ready
	function HUD.SetTouchUlt(ready)
		local b = TOUCH.buttons.QuirkUlt
		if b then
			b.BackgroundColor3 = ready and accent or GLASS.Color
			b.TextColor3 = ready and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		end
	end
end

---------------------------------------------------------------------------
-- (round 66) THE CONSOLE (F2): a dev console dropped from the top of the
-- screen - the server's log (every command the owner runs and what it did,
-- joins, KOs) and, for the owner only, a line to type commands into (Up /
-- Down: the last ones again, Tab: finish the word, a hint of what it does as
-- you type). Everyone else sees the same log, read-only.
---------------------------------------------------------------------------
do
	local CS = { lines = {}, commands = {}, history = {}, hIndex = 0, owner = false, max = 250 }
	local KIND_COLOR = {
		cmd = Color3.fromRGB(150, 200, 255), ok = Color3.fromRGB(140, 235, 160), err = Color3.fromRGB(255, 120, 110),
		info = Color3.fromRGB(215, 215, 225), event = Color3.fromRGB(255, 205, 110),
	}
	local CODE = Enum.Font.Code

	function HUD.BuildConsole(cbs)
		if CS.root then
			return
		end
		CS.cbs = cbs or {}
		local playerGui = gui and gui.Parent
		if not playerGui then
			return
		end
		CS.screen = make("ScreenGui", { Name = "QuirkConsole", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Parent = playerGui })
		local _, top = topInset()
		CS.root = make("Frame", {
			Name = "Console",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, top + 6),
			Size = UDim2.new(0.64, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(10, 10, 15),
			BackgroundTransparency = 0.06,
			Active = true, -- (clicks in it don't throw punches)
			Visible = false,
			Parent = CS.screen,
		}, {
			corner(10),
			edge(0.7),
			make("UISizeConstraint", { MinSize = Vector2.new(360, 240), MaxSize = Vector2.new(1100, 620) }),
		})
		-- (a Modal button frees a shift-locked mouse while it's open)
		make("TextButton", { Name = "Modal", Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true, Parent = CS.root })
		local bar = make("Frame", {
			Name = "Bar",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(22, 22, 30),
			BorderSizePixel = 0,
			Parent = CS.root,
		}, { corner(10) })
		make("TextLabel", {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = "⌨  QUIRK CONSOLE",
			Parent = bar,
		})
		CS.badge = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -44, 0.5, 0),
			Size = UDim2.fromOffset(96, 20),
			BackgroundColor3 = Color3.fromRGB(80, 80, 92),
			Font = UI_FONT,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "VIEW ONLY",
			Parent = bar,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local close = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(26, 22),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "✕",
			Parent = bar,
		})
		close.Activated:Connect(function()
			HUD.ToggleConsole(false)
		end)
		CS.log = make("ScrollingFrame", {
			Name = "Log",
			Position = UDim2.fromOffset(10, 38),
			Size = UDim2.new(1, -20, 1, -38 - 62),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Color3.new(1, 1, 1),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = CS.root,
		}, {
			make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
		})
		CS.hint = make("TextLabel", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -42),
			Size = UDim2.new(1, -28, 0, 18),
			BackgroundTransparency = 1,
			Font = CODE,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.fromRGB(160, 160, 175),
			Text = "",
			Parent = CS.root,
		})
		local row = make("Frame", {
			Name = "Input",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -8),
			Size = UDim2.new(1, -20, 0, 32),
			BackgroundColor3 = Color3.fromRGB(26, 26, 36),
			Parent = CS.root,
		}, { corner(6), edge(0.85) })
		make("TextLabel", {
			Size = UDim2.fromOffset(24, 32),
			BackgroundTransparency = 1,
			Font = CODE,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = ">",
			Parent = row,
		})
		CS.box = make("TextBox", {
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -30, 1, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			Font = CODE,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			PlaceholderColor3 = Color3.fromRGB(120, 120, 135),
			PlaceholderText = "",
			Text = "",
			Parent = row,
		})
		CS.box.FocusLost:Connect(function(enter)
			if not enter or not CS.owner then
				return
			end
			local text = CS.box.Text
			CS.box.Text = ""
			if string.find(text, "%S") then
				if CS.history[#CS.history] ~= text then
					table.insert(CS.history, text)
				end
				CS.hIndex = #CS.history + 1
				if CS.cbs.OnRun then
					CS.cbs.OnRun(text)
				end
			end
			-- (keep typing: straight back into the box)
			task.defer(function()
				if CS.root.Visible and CS.owner then
					CS.box:CaptureFocus()
				end
			end)
		end)
		CS.box:GetPropertyChangedSignal("Text"):Connect(function()
			if string.find(CS.box.Text, "\t") then
				CS.box.Text = string.gsub(CS.box.Text, "\t", "") -- (Tab completes; it never types)
				return
			end
			HUD.ConsoleHint()
		end)
		game:GetService("UserInputService").InputBegan:Connect(function(input)
			if not CS.root.Visible or not CS.box:IsFocused() then
				return
			end
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down then
				local step = input.KeyCode == Enum.KeyCode.Up and -1 or 1
				CS.hIndex = math.clamp(CS.hIndex + step, 1, #CS.history + 1)
				CS.box.Text = CS.history[CS.hIndex] or ""
				CS.box.CursorPosition = #CS.box.Text + 1
			elseif input.KeyCode == Enum.KeyCode.Tab then
				local word = string.lower(string.match(CS.box.Text, "^%s*(%S*)$") or "")
				if word ~= "" then
					for _, cmd in CS.commands do
						if string.sub(cmd.Name, 1, #word) == word then
							CS.box.Text = cmd.Name .. " "
							CS.box.CursorPosition = #CS.box.Text + 1
							break
						end
					end
				end
			end
		end)
		HUD.SetConsoleOwner(CS.owner)
		for _, line in CS.lines do
			HUD.ConsoleLine(line, true)
		end
	end

	-- what the word being typed does (the first command it could be)
	function HUD.ConsoleHint()
		if not CS.hint then
			return
		end
		local word = string.lower(string.match(CS.box.Text, "^%s*(%S*)") or "")
		local shown = ""
		if word ~= "" then
			for _, cmd in CS.commands do
				if string.sub(cmd.Name, 1, #word) == word then
					shown = cmd.Usage .. "   -   " .. cmd.Help
					break
				end
			end
		elseif CS.owner then
			shown = "help · players · hero bakugo · kills 10 · bucks 500 · dummy tank 3 · god · drop item · set damage 2"
		end
		CS.hint.Text = shown
	end

	function HUD.SetConsoleCommands(list)
		CS.commands = type(list) == "table" and list or {}
		HUD.ConsoleHint()
	end

	function HUD.SetConsoleOwner(isOwner)
		CS.owner = isOwner == true
		if not CS.box then
			return
		end
		CS.box.TextEditable = CS.owner
		CS.box.PlaceholderText = CS.owner and "Type a command ('help' lists them) - Enter runs it, Up/Down for the last ones, Tab finishes the word"
			or "View only - only the owner of this game can run commands"
		CS.badge.Text = CS.owner and "OWNER" or "VIEW ONLY"
		CS.badge.BackgroundColor3 = CS.owner and Color3.fromRGB(50, 170, 90) or Color3.fromRGB(80, 80, 92)
		HUD.ConsoleHint()
	end

	-- a line in the log: { Text, Kind, Time }
	function HUD.ConsoleLine(line, rebuilding)
		if type(line) ~= "table" then
			return
		end
		if not rebuilding then
			table.insert(CS.lines, line)
			while #CS.lines > CS.max do
				table.remove(CS.lines, 1)
			end
		end
		if not CS.log then
			return
		end
		-- (it follows the newest line, unless you've scrolled up to read)
		local okAt, atBottom = pcall(function()
			return CS.log.CanvasPosition.Y >= CS.log.AbsoluteCanvasSize.Y - CS.log.AbsoluteSize.Y - 24
		end)
		atBottom = not okAt or atBottom
		CS.order = (CS.order or 0) + 1
		local stamp = type(line.Time) == "number" and os.date("%H:%M:%S", line.Time) or ""
		make("TextLabel", {
			LayoutOrder = CS.order,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = CODE,
			TextSize = 14,
			TextWrapped = true,
			RichText = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = KIND_COLOR[line.Kind] or KIND_COLOR.info,
			Text = (stamp ~= "" and "[" .. stamp .. "] " or "") .. tostring(line.Text),
			Parent = CS.log,
		})
		local labels = {}
		for _, c in CS.log:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(labels, c)
			end
		end
		if #labels > CS.max then
			table.sort(labels, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, #labels - CS.max do
				labels[i]:Destroy()
			end
		end
		if atBottom or rebuilding then
			task.defer(function()
				pcall(function()
					CS.log.CanvasPosition = Vector2.new(0, math.max(CS.log.AbsoluteCanvasSize.Y - CS.log.AbsoluteSize.Y, 0))
				end)
			end)
		end
	end

	function HUD.ConsoleReset(lines)
		CS.lines = {}
		HUD.ConsoleClear()
		for _, line in type(lines) == "table" and lines or {} do
			HUD.ConsoleLine(line)
		end
	end

	function HUD.ConsoleClear()
		if not CS.log then
			return
		end
		for _, c in CS.log:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
	end

	function HUD.ToggleConsole(force)
		if not CS.root then
			return false
		end
		local on = force
		if on == nil then
			on = not CS.root.Visible
		end
		CS.root.Visible = on
		if on then
			CS.root.Position = UDim2.new(0.5, 0, 0, -40)
			tween(CS.root, 0.18, { Position = UDim2.new(0.5, 0, 0, select(2, topInset()) + 6) }, Enum.EasingStyle.Back)
			if CS.owner then
				task.defer(function()
					CS.box:CaptureFocus()
				end)
			end
			if CS.cbs.OnOpen then
				CS.cbs.OnOpen()
			end
		elseif CS.box:IsFocused() then
			CS.box:ReleaseFocus()
		end
		return on
	end

	function HUD.ConsoleVisible()
		return CS.root ~= nil and CS.root.Visible
	end
end

return HUD
