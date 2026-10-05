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
		Text = "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · B Emotes · H Shop · M Quirk",
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
	-- (round 88) the bar's words now, not at the meter's next change (a
	-- switch at 0% kept the last hero's ult name)
	if HUD.ultLast then
		HUD.SetUltMeter(HUD.ultLast[1], HUD.ultLast[2])
	end
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
	if HUD.HawksBar then
		HUD.HawksBar(quirkName, alt, ult) -- (round 92, hawksair: Hawks flying - R says LAND; carrying - 1-4 are the follow-ups)
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

-- (round 86) HAWKS' feathers (nil hides it): a bar over the health bar -
-- his wings ARE his ammo. A crimson fill (out of max: 150 in the ult), ten
-- ticks along it, a pale chip that shows what he just spent draining away,
-- and the state: "RUNNING THIN" under Low, "PLUCKED - REGROWING" at 0, an
-- orange flash when fire burns them. state = { Plucked, Flying, Storm, Low,
-- Burned } (Storm: the Thousand-Feather Storm has every one of them out -
-- "ALL OUT", not plucked, and no flash: round 86 review)
function HUD.SetFeathers(value, max, state)
	local fb = HUD.Feathers
	if not fb then
		if value == nil or not vitals then
			return
		end
		fb = { shown = nil, token = 0 }
		HUD.Feathers = fb
		fb.Bar = make("Frame", {
			Name = "Feathers",
			Position = UDim2.fromOffset(0, -18),
			Size = UDim2.fromOffset(270, 12),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			ClipsDescendants = true,
			Parent = vitals,
		}, { edge(0.7), corner(2) })
		fb.Chip = make("Frame", {
			Name = "Chip",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 226, 214),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Parent = fb.Bar,
		}, { corner(2) })
		fb.Fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(220, 50, 50),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = fb.Bar,
		}, { corner(2), gradient(Color3.fromRGB(255, 120, 100), Color3.fromRGB(170, 20, 30)) })
		-- (a sheen along the top of the fill: glossy feathers)
		make("Frame", {
			Name = "Sheen",
			Size = UDim2.new(1, 0, 0.4, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = fb.Fill,
		}, { corner(2) })
		for i = 1, 9 do
			make("Frame", {
				Name = "Tick" .. i,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(i / 10, 0, 0, 0),
				Size = UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = Color3.fromRGB(12, 10, 14),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = fb.Bar,
			})
		end
		fb.Flash = make("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = fb.Bar,
		})
		fb.Text = make("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "FEATHERS",
			ZIndex = 6,
			Parent = fb.Bar,
		}, { textStroke(1.5) })
		fb.State = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(255, 170, 150),
			Text = "",
			ZIndex = 6,
			Parent = fb.Bar,
		}, { textStroke(1.5) })
	end
	fb.Bar.Visible = value ~= nil
	if value == nil then
		fb.shown = nil
		return
	end
	state = state or {}
	max = math.max(tonumber(max) or 100, 1)
	value = math.clamp(value, 0, max)
	local ratio = value / max
	local before = fb.shown
	fb.shown = value
	tween(fb.Fill, 0.12, { Size = UDim2.fromScale(ratio, 1) })
	-- the chip: what he just spent stays pale a moment, then drains after it
	fb.token += 1
	local token = fb.token
	if before == nil or value >= before then
		fb.Chip.Size = UDim2.fromScale(ratio, 1)
	else
		task.delay(0.35, function()
			if fb.token == token then
				tween(fb.Chip, 0.3, { Size = UDim2.fromScale(ratio, 1) })
			end
		end)
	end
	local storm = state.Storm == true and state.Plucked ~= true
	local plucked = not storm and (state.Plucked == true or value <= 0)
	local low = not plucked and not storm and value < (state.Low or 20)
	local over = max > 100 and value > 100
	fb.Fill.BackgroundColor3 = plucked and Color3.fromRGB(110, 20, 26) or over and Color3.fromRGB(255, 196, 120) or Color3.fromRGB(220, 50, 50)
	fb.Text.Text = string.format("FEATHERS %d", math.floor(value + 0.5))
	fb.State.Text = storm and "ALL OUT" or plucked and "PLUCKED - REGROWING" or low and "RUNNING THIN" or over and "OVERGROWTH" or state.Flying and "FLYING" or ""
	fb.State.TextColor3 = (plucked or low) and Color3.fromRGB(255, 150, 130) or (over or storm) and Color3.fromRGB(255, 232, 150) or Color3.fromRGB(235, 235, 240)
	fb.Text.TextColor3 = (plucked or low) and Color3.fromRGB(255, 170, 150) or Color3.new(1, 1, 1)
	-- a flash: orange as fire burns them, white as they run out
	if state.Burned or (plucked and before and before > 0) then
		fb.Flash.BackgroundColor3 = state.Burned and Color3.fromRGB(255, 140, 40) or Color3.new(1, 1, 1)
		fb.Flash.BackgroundTransparency = 0.25
		tween(fb.Flash, 0.45, { BackgroundTransparency = 1 })
	end
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
	HUD.ultLast = { value, active }
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
		-- (round 86) every row has both pills: the roster switch can make any
		-- hero DEV ONLY, or release one (NEW), live - HUD.SetDevAccess shows them
		local dev = Config.IsDevOnly(quirkName)
		row.Visible = devAccess or not dev
		make("TextLabel", {
			Name = "DevPill",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -30, 0, 4),
			Size = UDim2.fromOffset(30, 14),
			BackgroundColor3 = Color3.fromRGB(255, 212, 64),
			Font = UI_FONT,
			TextSize = 9,
			TextColor3 = Color3.new(0, 0, 0),
			Text = "DEV",
			Visible = dev,
			ZIndex = 65,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		make("TextLabel", {
			Name = "NewPill",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -30, 0, 4),
			Size = UDim2.fromOffset(32, 14),
			BackgroundColor3 = Color3.fromRGB(60, 200, 110),
			Font = UI_FONT,
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "NEW",
			Visible = not dev and Config.RosterNew(quirkName),
			ZIndex = 65,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 1, Color = Color3.fromRGB(190, 255, 210), Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
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

-- Dev-only quirks only show for testers (round 86: DEV ONLY as the live
-- roster has it, Config.IsDevOnly - so this is called again when it changes)
function HUD.SetDevAccess(on)
	devAccess = on == true
	if not menuGrid then
		return
	end
	local shown = 0
	local now = os.time()
	for _, button in menuGrid:GetChildren() do
		if button:IsA("TextButton") then
			if Config.Quirks[button.Name] then
				local dev = Config.IsDevOnly(button.Name)
				button.Visible = devAccess or not dev
				local devPill, newPill = button:FindFirstChild("DevPill"), button:FindFirstChild("NewPill")
				if devPill then
					devPill.Visible = dev
				end
				if newPill then
					newPill.Visible = not dev and Config.RosterNew(button.Name, now)
				end
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
		HUD.ToggleRosterPanel(false) -- (round 86)
		if HUD.ToggleEventsPanel then
			HUD.ToggleEventsPanel(false) -- (round 87)
		end
		if HUD.TogglePossessPanel then
			HUD.TogglePossessPanel(false) -- (round 87)
		end
		if HUD.ToggleFlightGrantPanel then
			HUD.ToggleFlightGrantPanel(false) -- (round 92: GIVE FLIGHT)
		end
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
-- (round 86) DEV FLIGHT on the screen (Config.DevFlight; the flight itself
-- is in QuirkClient). Speed lines that stay up while he's fast - streaming
-- in from the sides at FAST, a ring of focus lines boiling at HYPERSONIC
-- (hand-drawn: redrawn 12 times a second); the flight meter over the dock
-- (the tier, the speed, the Mach number, the boom's mark on the bar); the
-- white rush of the mach burst; the crash's dust swallowing the camera; and
-- the test menu's DEV FLIGHT row - shown only to those who fly - with its
-- controls on a card beside the menu.
---------------------------------------------------------------------------
do
	local FL = { lines = {}, k = 0, mode = "stream", at = 0, dustToken = 0, infoToken = 0 }
	HUD.Flight = FL

	-- k: 0 (none) .. 1; mode: "stream" (FAST) or "focus" (HYPERSONIC)
	-- (round 90: or "light" - LIGHTSPEED: longer, thinner, in threes of
	-- colour - red, white, cyan - the light split at the edges)
	FL.LIGHT_COLORS = { Color3.fromRGB(255, 96, 150), Color3.new(1, 1, 1), Color3.fromRGB(96, 220, 255) }
	function HUD.FlightLines(k, mode)
		k = math.clamp(tonumber(k) or 0, 0, 1)
		FL.k = k
		FL.mode = mode or FL.mode
		if k <= 0.01 then
			if FL.frame then
				FL.frame.Visible = false
			end
			return
		end
		if not FL.frame then
			FL.frame = make("Frame", {
				Name = "FlightLines",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 0,
				Parent = gui,
			})
			for i = 1, 40 do
				FL.lines[i] = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 0,
					Parent = FL.frame,
				})
			end
			FL.conn = RunService.RenderStepped:Connect(function()
				FL.boil(false)
			end)
		end
		FL.frame.Visible = true
	end
	function FL.boil(now)
		if not (FL.frame and FL.frame.Visible) then
			return
		end
		local t = os.clock()
		if not now and t - FL.at < 1 / 12 then
			return
		end
		FL.at = t
		local size = gui.AbsoluteSize
		local maxDim = math.max(size.X, size.Y, 1)
		local light = FL.mode == "light"
		local focus = FL.mode == "focus" or light
		local count = math.floor((focus and 40 or 22) * FL.k + 0.5)
		for i, line in FL.lines do
			if i > count then
				line.BackgroundTransparency = 1
				continue
			end
			local angle
			if focus then
				angle = rng:NextNumber(0, math.pi * 2)
			else
				-- (from the sides: the world rushing past either side of him)
				angle = (rng:NextNumber() < 0.5 and 0 or math.pi) + rng:NextNumber(-0.6, 0.6)
			end
			local len = maxDim * (focus and rng:NextNumber(0.16, 0.36) or rng:NextNumber(0.1, 0.26)) * (0.55 + 0.45 * FL.k)
			local r = maxDim * (focus and rng:NextNumber(0.3, 0.42) or rng:NextNumber(0.36, 0.5)) + len / 2
			if light then
				-- (round 90) LIGHTSPEED: a third red, a third white, a third cyan
				-- - each colour a little farther out than the last
				local c = (i - 1) % 3 + 1
				len = maxDim * rng:NextNumber(0.22, 0.46)
				r = maxDim * (0.26 + 0.035 * c + rng:NextNumber(0, 0.12)) + len / 2
				line.BackgroundColor3 = FL.LIGHT_COLORS[c]
			elseif line.BackgroundColor3 ~= Color3.new(1, 1, 1) then
				line.BackgroundColor3 = Color3.new(1, 1, 1)
			end
			line.Position = UDim2.new(0.5, math.cos(angle) * r, 0.5, math.sin(angle) * r)
			line.Size = UDim2.fromOffset(len, rng:NextInteger(focus and 2 or 1, (focus and not light) and 5 or 3))
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 1 - (light and 0.62 or (focus and 0.7 or 0.8)) * FL.k * rng:NextNumber(0.35, 1)
		end
	end

	-- the tiers' colours on the meter
	FL.COLOR = {
		HOVER = Color3.fromRGB(226, 232, 244), CRUISE = Color3.fromRGB(150, 206, 255), FAST = Color3.fromRGB(110, 236, 255),
		HYPERSONIC = Color3.fromRGB(255, 214, 150), ["MACH BURST"] = Color3.new(1, 1, 1), BRAKING = Color3.fromRGB(255, 170, 120),
		["DIVE SLAM"] = Color3.fromRGB(255, 110, 90), LAUNCH = Color3.fromRGB(255, 236, 170),
		LIGHTSPEED = Color3.new(1, 1, 1), ["HOVER LOCK"] = Color3.fromRGB(120, 255, 200), -- (round 90)
	}
	-- (round 90) LIGHTSPEED's prism (the tier's name, the light barrier's strip)
	FL.PRISM = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 96, 150)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 214, 110)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 255, 180)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(96, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 130, 255)),
	})
	FL.TOP = 980 -- (the bar's end: the mach burst's cap)
	-- info: { Tier = "CRUISE", Speed = studs/s, Mach = n, Boom = studs/s (the mark), Hot = true while the burst runs }; nil hides it
	-- (round 90: Charge = the light barrier's charge 0..1, Light = at
	-- LIGHTSPEED, Hint = the key that gets there ("HOLD Q") - a prismatic
	-- strip under the bar fills with the charge and shimmers at LIGHTSPEED,
	-- the tier's name in the prism, the caption saying what's happening)
	function HUD.FlightMeter(info)
		-- (round 92) the phone's LOCK (the hover-lock) is up exactly while this is
		if HUD.SetTouchHoverLock then
			HUD.SetTouchHoverLock(info ~= nil)
		end
		if not info then
			if FL.meter then
				FL.meter.Visible = false
			end
			return
		end
		if not FL.meter then
			local dock = gui:FindFirstChild("Dock")
			local m = make("Frame", {
				Name = "FlightMeter",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = dock and UDim2.new(0.5, 0, 0, -10) or UDim2.new(0.5, 0, 1, -244),
				Size = UDim2.fromOffset(300, 46),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				Parent = dock or gui,
			}, { corner(6), edge(0.65) })
			FL.caption = make("TextLabel", {
				Name = "Caption",
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.fromOffset(212, 11), -- (round 90: 120 -> 212, room for the light barrier's words)
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(170, 176, 196),
				Text = "DEV FLIGHT",
				Parent = m,
			})
			FL.tier = make("TextLabel", {
				Name = "Tier",
				Position = UDim2.fromOffset(10, 11),
				Size = UDim2.fromOffset(150, 22),
				BackgroundTransparency = 1,
				Font = COMIC_FONT,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "HOVER",
				Parent = m,
			}, { textStroke(1.5), make("UIGradient", { Name = "Prism", Color = FL.PRISM, Enabled = false }) })
			FL.speed = make("TextLabel", {
				Name = "Speed",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 6),
				Size = UDim2.fromOffset(120, 20),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "0",
				Parent = m,
			}, { textStroke(1) })
			FL.mach = make("TextLabel", {
				Name = "Mach",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 25),
				Size = UDim2.fromOffset(150, 10),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(190, 196, 214),
				Text = "STUDS/S  ·  MACH 0.00",
				Parent = m,
			})
			local bar = make("Frame", {
				Name = "Bar",
				Position = UDim2.new(0, 10, 1, -8),
				Size = UDim2.new(1, -20, 0, 3),
				BackgroundColor3 = Color3.fromRGB(60, 62, 78),
				BorderSizePixel = 0,
				Parent = m,
			}, { corner(2) })
			FL.fill = make("Frame", {
				Name = "Fill",
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = bar,
			}, { corner(2), gradient(Color3.fromRGB(150, 206, 255), Color3.new(1, 1, 1), 0) })
			-- the tiers' marks, and the boom's (brighter, taller)
			for _, mark in { 90, 220, 420, 520 } do
				local boom = mark == 420
				make("Frame", {
					Name = boom and "BoomMark" or "Mark",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(mark / FL.TOP, 0, 0.5, 0),
					Size = UDim2.fromOffset(boom and 2 or 1, boom and 9 or 6),
					BackgroundColor3 = boom and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(200, 204, 220),
					BorderSizePixel = 0,
					ZIndex = 2,
					Parent = bar,
				})
			end
			-- (round 90) the light barrier's strip, under the bar
			local lightBar = make("Frame", {
				Name = "LightBar",
				Position = UDim2.new(0, 10, 1, -3),
				Size = UDim2.new(1, -20, 0, 2),
				BackgroundColor3 = Color3.fromRGB(44, 46, 62),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				Visible = false,
				Parent = m,
			}, { corner(1) })
			FL.lightFill = make("Frame", {
				Name = "Fill",
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = lightBar,
			}, { corner(1), make("UIGradient", { Name = "Prism", Color = FL.PRISM }) })
			FL.lightBar = lightBar
			FL.meter = m
		end
		-- (a phone: a touch to the left, clear of the ULT button's corner)
		if FL.meter.Parent ~= gui then
			FL.meter.Position = UDim2.new(0.5, gui.AbsoluteSize.Y < 520 and -40 or 0, 0, -10)
		end
		local name = tostring(info.Tier or "HOVER")
		local color = FL.COLOR[name] or Color3.new(1, 1, 1)
		local speed = math.max(tonumber(info.Speed) or 0, 0)
		FL.meter.Visible = true
		FL.tier.Text = name
		FL.tier.TextColor3 = color
		FL.speed.Text = tostring(math.floor(speed + 0.5))
		FL.mach.Text = string.format("STUDS/S  ·  MACH %.2f", tonumber(info.Mach) or speed / FL.TOP)
		FL.fill.Size = UDim2.fromScale(math.clamp(speed / FL.TOP, 0, 1), 1)
		FL.fill.BackgroundColor3 = info.Hot and Color3.new(1, 1, 1) or color
		-- (round 90) the light barrier: charging, broken (LIGHTSPEED), or how
		-- to get there (at HYPERSONIC)
		local charge = math.clamp(tonumber(info.Charge) or 0, 0, 1)
		local lit = info.Light == true
		local prism = FL.tier:FindFirstChild("Prism")
		if prism then
			prism.Enabled = lit
			prism.Offset = Vector2.new(lit and math.sin(os.clock() * 2.2) * 0.3 or 0, 0)
		end
		if FL.lightBar then
			FL.lightBar.Visible = lit or charge > 0
			FL.lightFill.Size = UDim2.fromScale(lit and 1 or charge, 1)
			local g = FL.lightFill:FindFirstChild("Prism")
			if g then
				g.Offset = Vector2.new(lit and (os.clock() * 0.8) % 1 - 0.5 or 0, 0)
			end
		end
		if FL.caption then
			FL.caption.Text = lit and "LIGHT BARRIER BROKEN" or (charge > 0 and string.format("LIGHT BARRIER  %d%%", math.floor(charge * 100))
				or (info.Hint and ("DEV FLIGHT  ·  " .. tostring(info.Hint) .. ": LIGHTSPEED") or "DEV FLIGHT"))
			FL.caption.TextColor3 = (lit or charge > 0) and Color3.fromRGB(214, 226, 255) or Color3.fromRGB(170, 176, 196)
		end
	end

	-- the mach burst on his screen: thick white streaks rushing in from the
	-- edges for a blink (the anime's radial smear)
	function HUD.FlightBurst(t)
		t = tonumber(t) or 0.3
		local size = gui.AbsoluteSize
		local maxDim = math.max(size.X, size.Y, 1)
		local holder = make("Frame", {
			Name = "FlightBurst",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 31,
			Parent = gui,
		})
		for i = 1, 26 do
			local angle = i / 26 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
			local len = maxDim * rng:NextNumber(0.25, 0.45)
			local r = maxDim * rng:NextNumber(0.34, 0.5) + len / 2
			local line = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(angle) * r, 0.5, math.sin(angle) * r),
				Size = UDim2.fromOffset(len, rng:NextInteger(5, 14)),
				Rotation = math.deg(angle),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = rng:NextNumber(0.55, 0.75),
				BorderSizePixel = 0,
				ZIndex = 31,
				Parent = holder,
			})
			tween(line, t, { BackgroundTransparency = 1, Position = UDim2.new(0.5, math.cos(angle) * r * 0.82, 0.5, math.sin(angle) * r * 0.82) })
		end
		task.delay(t + 0.05, function()
			holder:Destroy()
		end)
	end

	-- the crash's dust over the camera: the screen goes the dust's colour,
	-- big soft billows rolling across, the world blurred, then it clears
	function HUD.FlightDust(t, color)
		t = tonumber(t) or 0.9
		color = typeof(color) == "Color3" and color or Color3.fromRGB(176, 164, 148)
		FL.dustToken += 1
		local token = FL.dustToken
		local veil = make("Frame", {
			Name = "FlightDust",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Parent = overlayGui,
		})
		for _ = 1, 9 do
			local s = rng:NextNumber(0.35, 0.7)
			local x, y = rng:NextNumber(-0.1, 1.1), rng:NextNumber(-0.1, 1.1)
			local puff = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromScale(s, s),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25)):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Parent = veil,
			}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			tween(puff, t, { Position = UDim2.fromScale(x + rng:NextNumber(-0.25, 0.25), y - rng:NextNumber(0.05, 0.2)), BackgroundTransparency = 1, Size = UDim2.fromScale(s * 1.4, s * 1.4) })
		end
		local blur = Instance.new("BlurEffect")
		blur.Name = "FlightDust"
		blur.Size = 10
		blur.Parent = game:GetService("Lighting")
		task.delay(t * 0.3, function()
			tween(veil, t * 0.7, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(blur, t * 0.7, { Size = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(t + 0.05, function()
			veil:Destroy()
			blur:Destroy()
		end)
		return token
	end

	-- the test menu's DEV FLIGHT row: only for those who fly (a group with
	-- nothing left showing hides, header and all)
	function HUD.ShowTestRow(id, on)
		local row = testRows[id]
		if not row then
			return
		end
		row.Button.Visible = on == true
		local grid = row.Button.Parent
		local any = false
		for _, b in grid and grid:GetChildren() or {} do
			if b:IsA("GuiButton") and b.Visible then
				any = true
			end
		end
		if grid then
			grid.Visible = any
			local header = grid.Parent and grid.Parent:FindFirstChild("Group_" .. tostring(row.Item.Group or "More"))
			if header then
				header.Visible = any
			end
		end
	end

	-- a card of notes beside the test menu for one row: up while the mouse
	-- is on it, and for a few seconds after it's pressed (a phone has no hover)
	function HUD.SetTestInfo(id, title, lines)
		local row = testRows[id]
		if not row or row.Info then
			return
		end
		local card = make("Frame", {
			Name = "TestInfo_" .. id,
			Position = UDim2.new(0, 12 + TEST_W + 10, 0, 108),
			Size = UDim2.fromOffset(330, 40 + #lines * 17),
			BackgroundColor3 = Color3.fromRGB(17, 18, 27),
			BackgroundTransparency = 0.04,
			Visible = false,
			ZIndex = 40,
			Parent = gui,
		}, {
			corner(10),
			make("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(255, 212, 64), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 22),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 212, 64),
			Text = title,
			ZIndex = 41,
			Parent = card,
		}, { textStroke(1.2) })
		for i, text in lines do
			make("TextLabel", {
				Position = UDim2.fromOffset(14, 32 + (i - 1) * 17),
				Size = UDim2.new(1, -28, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(214, 218, 232),
				Text = text,
				ZIndex = 41,
				Parent = card,
			})
		end
		row.Info = card
		-- (a "?" on the row: there's more to it)
		make("TextLabel", {
			Name = "InfoMark",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, row.Track and -46 or -10, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(255, 212, 64),
			Font = UI_FONT,
			TextSize = 10,
			TextColor3 = Color3.new(0, 0, 0),
			Text = "?",
			ZIndex = 24,
			Parent = row.Button,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		row.Label.Size = UDim2.new(1, row.Track and -68 or -40, 1, 0)
		local function show(on, hold)
			FL.infoToken += 1
			local token = FL.infoToken
			-- (round 86 review: not over a side panel - DEV ACCESS, DUMMIES,
			-- FUN, SERVER open at the same spot beside the menu)
			for _, name in { "DevAccess", "DummySpawner", "FunStuff", "ServerSettings", "AdminEvents", "FlightGrants" } do -- (round 87: ADMIN EVENTS too; round 92: GIVE FLIGHT)
				local panel = gui:FindFirstChild(name)
				if panel and panel:IsA("GuiObject") and panel.Visible then
					on = false
				end
			end
			card.Visible = on and testPanel ~= nil and testPanel.Visible
			if on and hold then
				task.delay(hold, function()
					if FL.infoToken == token then
						card.Visible = false
					end
				end)
			end
		end
		row.Button.MouseEnter:Connect(function()
			show(true)
		end)
		row.Button.MouseLeave:Connect(function()
			show(false)
		end)
		row.Button.MouseButton1Click:Connect(function()
			show(true, 5)
		end)
	end
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
		Name = "KOPopup", -- (round 86: a NEW HERO banner waits for it to go)
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

---------------------------------------------------------------------------
-- (round 86) HERO ROSTER (a test menu side panel): every hero with a
-- PUBLIC / DEV ONLY switch. The server's roster switch (Kit.Roster) does
-- the switching - saved, and live on every server - and this follows the
-- live roster (Config.IsDevOnly) whoever switched it, wherever. A click
-- moves the switch at once (dimmed till the server's state agrees, or back
-- after 5 s). cb = { Set(quirk, "public" | "dev"), Reset(), Editor() -> bool:
-- may this player switch (view only if not) }.
-- And the NEW HERO banner (HUD.RosterBanner) for a hero just released.
---------------------------------------------------------------------------
do
	local RP = { rows = {}, pending = {}, drawn = {}, chips = {}, banners = {}, cb = {} }
	HUD.Roster = RP
	local W = 384
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local GREEN = Color3.fromRGB(60, 200, 110)
	local GOLD = Color3.fromRGB(255, 212, 64)
	local AMBER = Color3.fromRGB(255, 166, 64)
	local DIM = Color3.fromRGB(150, 154, 180)
	local TRACK = Color3.fromRGB(18, 19, 28)
	local ROW = Color3.fromRGB(38, 40, 57)
	local SYNC = {
		Live = { "LIVE ON EVERY SERVER", GREEN },
		Saving = { "SAVING...", GOLD },
		Local = { "THIS SERVER ONLY", AMBER },
		Studio = { "STUDIO SESSION ONLY", Color3.fromRGB(110, 190, 255) }, -- (review: Studio never writes the live roster)
		Loading = { "LOADING...", DIM },
	}
	local function hexOf(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	local function ago(t)
		local s = math.max(0, os.time() - (tonumber(t) or os.time()))
		if s < 60 then
			return "just now"
		elseif s < 3600 then
			return math.floor(s / 60) .. " min ago"
		elseif s < 86400 then
			return math.floor(s / 3600) .. " h ago"
		end
		return math.floor(s / 86400) .. " d ago"
	end
	-- the round initials badge in the hero's colour (as on the phone)
	local function badge(parent, q, size, textSize, font)
		local b = make("Frame", {
			Name = "Avatar",
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = q.Color,
			ZIndex = 23,
			Parent = parent,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			gradient(WHITE, Color3.fromRGB(150, 150, 150), 90),
			make("UIStroke", { Thickness = 1.5, Color = q.Color:Lerp(WHITE, 0.5), Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Name = "Initials",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = font or HEAD_FONT,
			TextSize = textSize,
			TextColor3 = WHITE,
			Text = initials(q.DisplayName),
			ZIndex = 24,
			Parent = b,
		}, { textStroke(1) })
		return b
	end

	local function makeRow(order, name)
		local q = Config.Quirks[name]
		local row = make("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = ROW,
			ZIndex = 22,
			Parent = RP.list,
		}, { corner(7) })
		local flash = make("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = row,
		}, { corner(7) })
		make("Frame", {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -16),
			BackgroundColor3 = q.Color,
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = row,
		}, { corner(2) })
		local avatar = badge(row, q, 30, 12)
		avatar.Position = UDim2.fromOffset(11, 7)
		local title = make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(50, 5),
			Size = UDim2.new(1, -200, 0, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = q.DisplayName or name,
			ZIndex = 23,
			Parent = row,
		}, { make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }) })
		local sub = make("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(50, 24),
			Size = UDim2.new(1, -198, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = q.ModeName or "",
			ZIndex = 23,
			Parent = row,
		})
		-- the switch: PUBLIC on the left (green), DEV ONLY on the right (gold)
		local sw = make("Frame", {
			Name = "Switch",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(140, 26),
			BackgroundColor3 = TRACK,
			ZIndex = 23,
			Parent = row,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local knob = make("Frame", {
			Name = "Knob",
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(0.5, -2, 1, -4),
			BackgroundColor3 = GREEN,
			ZIndex = 24,
			Parent = sw,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(205, 205, 205), 90) })
		local function half(id, x, text)
			return make("TextButton", {
				Name = id,
				Position = UDim2.fromScale(x, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 11,
				TextColor3 = DIM,
				Text = text,
				ZIndex = 25,
				Parent = sw,
			})
		end
		local pub, dev = half("Public", 0, "PUBLIC"), half("Dev", 0.5, "DEV ONLY")
		RP.rows[name] = { Row = row, Flash = flash, Title = title, Sub = sub, Switch = sw, Knob = knob, Public = pub, Dev = dev, Quirk = q }
		pub.MouseButton1Click:Connect(function()
			RP.press(name, "public")
		end)
		dev.MouseButton1Click:Connect(function()
			RP.press(name, "dev")
		end)
	end

	-- cb: see above
	function HUD.BuildRosterPanel(cb)
		RP.cb = cb or {}
		if RP.frame or not gui then
			return
		end
		local frame = make("Frame", {
			Name = "Roster",
			Position = UDim2.new(0, 22 + TEST_W, 0, 108),
			Size = UDim2.fromOffset(W, 520),
			BackgroundColor3 = Color3.fromRGB(24, 24, 34),
			BackgroundTransparency = 0.04,
			Visible = false,
			ZIndex = 20,
			Parent = gui,
		}, { stroke(3), corner(8) })
		RP.frame = frame
		-- a little of the gold light from the top
		make("Frame", {
			Name = "Glow",
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = frame,
		}, { corner(8), make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1) }) })
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(14, 5),
			Size = UDim2.new(1, -190, 0, 32),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 27,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = GOLD,
			Text = "HERO ROSTER",
			ZIndex = 21,
			Parent = frame,
		}, { textStroke(1.5) })
		-- how it stands: live everywhere, saving, or this server only
		RP.sync = make("Frame", {
			Name = "Sync",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(164, 22),
			BackgroundColor3 = TRACK,
			ZIndex = 21,
			Parent = frame,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Name = "Edge", Thickness = 1, Color = GREEN, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		RP.syncDot = make("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = GREEN,
			ZIndex = 22,
			Parent = RP.sync,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		RP.syncText = make("TextLabel", {
			Name = "Text",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -28, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = "LOADING...",
			ZIndex = 22,
			Parent = RP.sync,
		}, { make("UITextSizeConstraint", { MaxTextSize = 10, MinTextSize = 7 }) })
		RP.sub = make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(14, 37),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(190, 194, 220),
			Text = "Who can pick each hero. Saved, and live on every server.", -- (review: fits its 356 px line)
			ZIndex = 21,
			Parent = frame,
		})
		-- the counts
		for i, def in { { "Public", "PUBLIC", GREEN }, { "Dev", "DEV ONLY", GOLD }, { "Changed", "SWITCHED", AMBER } } do
			local chip = make("Frame", {
				Name = def[1],
				Position = UDim2.fromOffset(14 + (i - 1) * 120, 58),
				Size = UDim2.fromOffset(112, 22),
				BackgroundColor3 = def[3]:Lerp(BLACK, 0.74),
				ZIndex = 21,
				Parent = frame,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 1, Color = def[3], Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			RP.chips[def[1]] = {
				Frame = chip,
				Word = def[2],
				Color = def[3],
				Label = make("TextLabel", {
					Name = "Text",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = UI_FONT,
					TextSize = 11,
					RichText = true,
					TextColor3 = WHITE,
					Text = def[2],
					ZIndex = 22,
					Parent = chip,
				}),
			}
		end
		RP.topLine = make("Frame", {
			Name = "Line",
			Position = UDim2.fromOffset(12, 88),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		RP.list = make("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(8, 94),
			Size = UDim2.new(1, -12, 1, -94 - 74),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = WHITE,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 21,
			Parent = frame,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }),
		})
		for order, name in Config.QuirkOrder do
			if Config.Quirks[name] then
				makeRow(order, name)
			end
		end
		RP.footLine = make("Frame", {
			Name = "FootLine",
			Position = UDim2.new(0, 12, 1, -72),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		RP.info = make("TextLabel", {
			Name = "Last",
			Position = UDim2.new(0, 14, 1, -66),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 21,
			Parent = frame,
		})
		RP.reset = make("TextButton", {
			Name = "Reset",
			Position = UDim2.new(0, 12, 1, -44),
			Size = UDim2.new(1, -24, 0, 32),
			BackgroundColor3 = Color3.fromRGB(170, 60, 60),
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = WHITE,
			Text = "RESET EVERY HERO TO DEFAULT",
			ZIndex = 22,
			Parent = frame,
		}, { corner(6), stroke(1.5) })
		-- (two clicks: the first arms it for 3 s)
		RP.reset.MouseButton1Click:Connect(function()
			if not RP.canReset then
				return
			end
			if RP.armed and os.clock() - RP.armed < 3 then
				RP.armed = nil
				if RP.cb.Reset then
					RP.cb.Reset()
				end
			else
				RP.armed = os.clock()
				local at = RP.armed
				task.delay(3, function()
					if RP.armed == at then
						RP.armed = nil
						HUD.RefreshRosterPanel()
					end
				end)
			end
			HUD.RefreshRosterPanel()
		end)
		-- (a phone turned round, a window resized: it fits itself again)
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if RP.frame.Visible then
					RP.layout()
				end
			end)
		end
		HUD.RefreshRosterPanel()
	end

	-- a switch clicked: moved at once, dimmed till the server agrees
	function RP.press(name, state)
		if not (RP.cb.Editor and RP.cb.Editor()) then
			return
		end
		local live = Config.IsDevOnly(name) and "dev" or "public"
		local pend = RP.pending[name]
		if ((pend and pend.State) or live) == state then
			return
		end
		local token = os.clock()
		RP.pending[name] = { State = state, At = token }
		if RP.cb.Set then
			RP.cb.Set(name, state)
		end
		HUD.RefreshRosterPanel()
		task.delay(5, function()
			local p = RP.pending[name]
			if p and p.At == token then
				RP.pending[name] = nil -- (the server never agreed: back to how it is)
				HUD.RefreshRosterPanel()
			end
		end)
	end

	-- fits the screen: on a short one (a phone) it starts just under the top
	-- bar, and the header and footer shrink
	function RP.layout()
		local cam = workspace.CurrentCamera
		local vpY = (cam and cam.ViewportSize.Y) or 720
		local y0 = vpY < 500 and 52 or 108
		local h = math.clamp(vpY - y0 - 12, 200, 540)
		local compact = h < 340
		RP.frame.Position = UDim2.new(0, 22 + TEST_W, 0, y0)
		RP.frame.Size = UDim2.fromOffset(W, h)
		RP.sub.Visible = not compact
		RP.info.Visible = not compact
		local chipY = compact and 38 or 58
		for _, chip in RP.chips do
			chip.Frame.Position = UDim2.fromOffset(chip.Frame.Position.X.Offset, chipY)
		end
		local top, bottom = chipY + 36, compact and 50 or 74
		RP.topLine.Position = UDim2.fromOffset(12, top - 6)
		RP.list.Position = UDim2.fromOffset(8, top)
		RP.list.Size = UDim2.new(1, -12, 1, -top - bottom)
		RP.footLine.Position = UDim2.new(0, 12, 1, -bottom + 2)
	end

	-- re-read the live roster (a switch here or on another server, the
	-- sync state, who may switch)
	function HUD.RefreshRosterPanel()
		if not RP.frame then
			return
		end
		local editor = RP.cb.Editor and RP.cb.Editor() == true
		local counts = { Public = 0, Dev = 0, Changed = 0 }
		for _, name in Config.QuirkOrder do
			local r = RP.rows[name]
			local live = Config.IsDevOnly(name) and "dev" or "public"
			local pend = RP.pending[name]
			if pend and pend.State == live then
				RP.pending[name] = nil
				pend = nil
			end
			local o = Config.RosterOverride(name)
			counts[live == "dev" and "Dev" or "Public"] += 1
			if o then
				counts.Changed += 1
			end
			if r then
				local dev = ((pend and pend.State) or live) == "dev"
				tween(r.Knob, 0.2, {
					Position = dev and UDim2.new(0.5, 0, 0, 2) or UDim2.new(0, 2, 0, 2),
					BackgroundColor3 = dev and GOLD or GREEN,
					BackgroundTransparency = pend and 0.5 or editor and 0 or 0.4,
				}, Enum.EasingStyle.Quint)
				r.Public.TextColor3 = dev and DIM or WHITE
				r.Dev.TextColor3 = dev and BLACK or DIM
				r.Public.TextTransparency = editor and 0 or 0.35
				r.Dev.TextTransparency = editor and 0 or 0.35
				r.Public.AutoButtonColor = editor
				r.Dev.AutoButtonColor = editor
				r.Switch.BackgroundTransparency = editor and 0 or 0.45
				if o == "public" then
					r.Sub.Text = "RELEASED · was DEV ONLY" -- (review: fits its 162 px label)
					r.Sub.TextColor3 = Color3.fromRGB(130, 236, 160)
				elseif o == "dev" then
					r.Sub.Text = "PULLED · was PUBLIC"
					r.Sub.TextColor3 = AMBER
				else
					r.Sub.Text = r.Quirk.ModeName or ""
					r.Sub.TextColor3 = DIM
				end
				-- (no second line: the name sits in the middle of the row)
				r.Title.Position = UDim2.fromOffset(50, r.Sub.Text == "" and 13 or 5)
				-- its state changed (here or anywhere): a flash across the row
				if RP.drawn[name] ~= nil and RP.drawn[name] ~= live then
					r.Flash.BackgroundColor3 = live == "dev" and GOLD or GREEN
					r.Flash.BackgroundTransparency = 0.55
					tween(r.Flash, 0.7, { BackgroundTransparency = 1 })
				end
				RP.drawn[name] = live
			end
		end
		for key, chip in RP.chips do
			chip.Label.Text = string.format('<font color="%s"><b>%d</b></font>  %s', hexOf(chip.Color:Lerp(WHITE, 0.2)), counts[key], chip.Word)
		end
		local sync = SYNC[workspace:GetAttribute("RosterSync") or "Loading"] or SYNC.Loading
		RP.syncText.Text = sync[1]
		RP.syncDot.BackgroundColor3 = sync[2]
		RP.sync.Edge.Color = sync[2]
		local by, at = workspace:GetAttribute("RosterBy"), workspace:GetAttribute("RosterAt")
		local state = workspace:GetAttribute("RosterSync")
		if state == "Local" then
			RP.info.Text = "Not saved yet: this server only (the store isn't answering)"
			RP.info.TextColor3 = AMBER
		elseif state == "Studio" then
			RP.info.Text = "Studio: switches stay in this session (StudioSaves is off)"
			RP.info.TextColor3 = SYNC.Studio[2]
		elseif by and at then
			RP.info.Text = string.format("Last switch: %s, %s", tostring(by), ago(at))
			RP.info.TextColor3 = DIM
		else
			RP.info.Text = "Every hero is on the default"
			RP.info.TextColor3 = DIM
		end
		-- reset: only with something switched, and only for an editor
		RP.canReset = editor and counts.Changed > 0
		RP.reset.Visible = editor
		if not editor then
			RP.info.Text = "VIEW ONLY: the owner and listed testers switch heroes"
			RP.info.TextColor3 = AMBER
			RP.info.Visible = true
		end
		local armed = RP.armed ~= nil and RP.canReset
		RP.reset.AutoButtonColor = RP.canReset
		RP.reset.BackgroundColor3 = armed and Color3.fromRGB(226, 92, 48) or RP.canReset and Color3.fromRGB(170, 60, 60) or Color3.fromRGB(58, 60, 78)
		RP.reset.TextColor3 = RP.canReset and WHITE or DIM
		RP.reset.Text = armed and string.format("SURE? CLICK AGAIN: %d HERO%s BACK", counts.Changed, counts.Changed == 1 and "" or "ES")
			or RP.canReset and "RESET EVERY HERO TO DEFAULT" or "EVERY HERO IS ON THE DEFAULT"
	end

	function HUD.ToggleRosterPanel(force)
		local frame = RP.frame
		if not frame then
			return false
		end
		if force ~= nil then
			frame.Visible = force
		else
			frame.Visible = not frame.Visible
		end
		if frame.Visible then
			RP.layout()
			HUD.RefreshRosterPanel()
		end
		return frame.Visible
	end

	-- fade a whole banner out (its text, frames and strokes)
	local function fadeAll(root, t)
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, t, { TextTransparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, t, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, t, { Transparency = 1 })
			end
		end
	end

	-- (review) a line's width at a text size, as the engine lays it out (in
	-- offsets: no UIScale in it). nil where it can't say.
	function RP.textWidth(text, size, font)
		local ok, v = pcall(function()
			return game:GetService("TextService"):GetTextSize(text, size, font, Vector2.new(4000, 1000))
		end)
		return (ok and typeof(v) == "Vector2") and v.X or nil
	end

	-- the banner's move line: his first two moves and his ult (just the first
	-- and the ult when that's too long for the line: ~58 letters at 12 px)
	function RP.headline(q, accent)
		local plain, rich = {}, {}
		for i, a in q.Abilities or {} do
			if i > 2 then
				break
			end
			if type(a) == "table" and type(a.Name) == "string" then
				table.insert(plain, a.Name)
				table.insert(rich, a.Name)
			end
		end
		if type(q.Ult) == "table" and type(q.Ult.Name) == "string" then
			table.insert(plain, "ULT " .. q.Ult.Name)
			table.insert(rich, string.format('<font color="%s">ULT</font> %s', accent, q.Ult.Name))
		end
		local line = table.concat(plain, "  ·  ")
		if #plain == 3 and (utf8.len(line) or #line) > 58 then
			table.remove(plain, 2)
			table.remove(rich, 2)
		end
		return table.concat(plain, "  ·  "), table.concat(rich, string.format('  <font color="%s">·</font>  ', accent))
	end

	-- the phone opened from the banner (a tap): his row scrolled to and lit
	function RP.focusRow(name)
		local row = menuGrid and menuGrid:FindFirstChild(name)
		if not (row and row:IsA("GuiObject")) then
			return
		end
		local y = 2
		for _, other in menuGrid:GetChildren() do
			if other:IsA("GuiObject") and other.Visible and Config.Quirks[other.Name] and other.LayoutOrder < row.LayoutOrder then
				y += other.Size.Y.Offset + 6
			end
		end
		pcall(function()
			menuGrid.CanvasPosition = Vector2.new(0, math.max(0, y - 12))
		end)
		local was = row.BackgroundTransparency
		row.BackgroundTransparency = math.max(0, was - 0.35)
		tween(row, 1, { BackgroundTransparency = was })
	end

	-- a camera-flash off the top and bottom of the screen, a little of his colour in it
	function RP.edgeFlash(color)
		local flash = make("Frame", {
			Name = "RosterFlash",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 69,
			Parent = gui,
		})
		for _, y in { 0, 1 } do
			local edgeGlow = make("Frame", {
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, 0.2),
				BackgroundColor3 = color:Lerp(WHITE, 0.55),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 69,
				Parent = flash,
			}, {
				make("UIGradient", { Rotation = y == 0 and 90 or -90, Transparency = NumberSequence.new(0, 1) }),
			})
			tween(edgeGlow, 0.08, { BackgroundTransparency = 0.45 })
			task.delay(0.1, function()
				tween(edgeGlow, 0.75, { BackgroundTransparency = 1 })
			end)
		end
		task.delay(0.95, function()
			flash:Destroy()
		end)
	end

	-- NEW HERO: the band (640x150) pops in over a sunburst of his colour - his
	-- badge with a burst ring and sparks, his name, his headline moves ticking
	-- in, how to play him on a pill, his name again huge and faint drifting
	-- behind - and a camera-flash off the screen's edges. Held 3.8 s (cut
	-- short if the phone comes out). Returns true if it was cut short.
	function RP.showBanner(b)
		local q = Config.Quirks[b.Quirk]
		local color = q.Color
		local bright = color:Lerp(WHITE, 0.18)
		-- (the holder follows the screen size; the banner inside it pops. A
		-- tap on it, on a touch screen, opens the phone on his row)
		local holder = make(b.Tap and "TextButton" or "Frame", {
			Name = "RosterBanner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.24),
			Size = UDim2.fromOffset(640, 150),
			BackgroundTransparency = 1,
			ZIndex = 70,
			Parent = gui,
		})
		if b.Tap then
			holder.Text = ""
			holder.AutoButtonColor = false
			holder.Activated:Connect(function()
				if HUD.ToggleShop then
					HUD.ToggleShop(false)
				end
				HUD.ShowMenu(true)
				RP.focusRow(b.Quirk)
			end)
		end
		autoScale(holder)
		local banner = make("Frame", {
			Name = "Banner",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 10, 14),
			BackgroundTransparency = 0.18,
			ZIndex = 70,
			Parent = holder,
		}, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.14, 0),
					NumberSequenceKeypoint.new(0.86, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		local pop = make("UIScale", { Scale = 1.5, Parent = banner })
		-- his colour washing in from behind his badge
		make("Frame", {
			Name = "Tint",
			Size = UDim2.fromScale(0.6, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			ZIndex = 70,
			Parent = banner,
		}, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.14, 0.3),
					NumberSequenceKeypoint.new(0.42, 0.72),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		-- (review) his name again, huge and faint, drifting behind the right of
		-- the band (clipped to it, fading off both ways)
		local ghostClip = make("Frame", {
			Name = "Ghost",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 70,
			Parent = banner,
		})
		local ghost = make("TextLabel", {
			Name = "GhostName",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 40, 0.5, 6),
			Size = UDim2.fromOffset(640, 150),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 150,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = bright,
			TextTransparency = 0.84,
			Text = string.upper(q.DisplayName or b.Quirk),
			ZIndex = 70,
			Parent = ghostClip,
		}, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.45, 0.2),
					NumberSequenceKeypoint.new(0.78, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		-- a sunburst turning slowly behind the badge (it breaks out of the band)
		local rays = {}
		for k = 0, 5 do
			table.insert(rays, make("Frame", {
				Name = "Ray",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(110, 75),
				Size = UDim2.fromOffset(k % 2 == 0 and 7 or 4, k % 2 == 0 and 230 or 180),
				Rotation = k * 30 + 15,
				BackgroundColor3 = bright,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 70,
				Parent = banner,
			}, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }),
				make("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.3, 0.3),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(0.7, 0.3),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}))
		end
		-- the hero's colour along the top and the bottom
		for _, y in { 0, 1 } do
			make("Frame", {
				Name = "Edge",
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = bright,
				BorderSizePixel = 0,
				ZIndex = 71,
				Parent = banner,
			}, {
				make("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.2, 0),
						NumberSequenceKeypoint.new(0.8, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			})
		end
		-- a ring bursting off his badge
		local ring = make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(110, 75),
			Size = UDim2.fromOffset(92, 92),
			BackgroundTransparency = 1,
			ZIndex = 71,
			Parent = banner,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 4, Color = bright, Transparency = 0.1 }),
		})
		local avatar = badge(banner, q, 92, 42, COMIC_FONT)
		avatar.AnchorPoint = Vector2.new(0.5, 0.5)
		avatar.Position = UDim2.fromOffset(110, 75)
		avatar.ZIndex = 72
		avatar.Initials.ZIndex = 73
		avatar:FindFirstChildOfClass("UIStroke").Thickness = 3
		local avatarPop = make("UIScale", { Scale = 0.01, Parent = avatar })
		make("TextLabel", {
			Name = "Kicker",
			Position = UDim2.fromOffset(176, 11),
			Size = UDim2.fromOffset(440, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = "N E W   H E R O",
			ZIndex = 72,
			Parent = banner,
		}, { textStroke(2) })
		-- (the news, on the same line at the right: big enough on a phone)
		make("TextLabel", {
			Name = "OutNow",
			Position = UDim2.fromOffset(176, 12),
			Size = UDim2.fromOffset(440, 16),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = bright:Lerp(WHITE, 0.4),
			Text = "OUT NOW FOR EVERYONE",
			ZIndex = 72,
			Parent = banner,
		}, { textStroke(1.5) })
		-- his name, sized to fit by measuring it (TextService: the same in any
		-- UIScale, so the underline under it is right on a phone too)
		local NAME_W, NAME_H = 440, 50
		local nameText = string.upper(q.DisplayName or b.Quirk)
		local nameSize, nameWide = NAME_H, RP.textWidth(nameText, NAME_H, COMIC_FONT)
		if nameWide and nameWide > NAME_W then
			nameSize = math.max(20, math.floor(NAME_H * NAME_W / nameWide))
			nameWide = RP.textWidth(nameText, nameSize, COMIC_FONT) or NAME_W
		end
		local title = make("TextLabel", {
			Name = "HeroName",
			Position = UDim2.fromOffset(174, 29),
			Size = UDim2.fromOffset(NAME_W, NAME_H),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = nameSize,
			TextScaled = nameWide == nil, -- (nothing to measure with: it fits itself)
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = bright,
			Text = nameText,
			ZIndex = 72,
			Parent = banner,
		}, { textStroke(3), make("UITextSizeConstraint", { MaxTextSize = NAME_H, MinTextSize = 20 }) })
		local underline = make("Frame", {
			Name = "Underline",
			Position = UDim2.fromOffset(176, 81),
			Size = UDim2.fromOffset(0, 3),
			BackgroundColor3 = bright,
			BorderSizePixel = 0,
			ZIndex = 72,
			Parent = banner,
		}, { corner(2) })
		-- his headline moves, ticking in
		local movesPlain, movesRich = RP.headline(q, hexOf(bright:Lerp(WHITE, 0.25)))
		local moves = make("TextLabel", {
			Name = "Moves",
			Position = UDim2.fromOffset(176, 89),
			Size = UDim2.fromOffset(NAME_W, 16),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			RichText = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(232, 234, 244),
			Text = movesRich,
			MaxVisibleGraphemes = 0,
			ZIndex = 72,
			Parent = banner,
		}, { textStroke(1) })
		-- his other mode (left), how to play him on a pill (right)
		local pillW = b.Hint and 200 or 0
		make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(176, 112),
			Size = UDim2.fromOffset(NAME_W - pillW - (b.Hint and 12 or 0), 26),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(214, 217, 236),
			Text = (q.ModeName and q.ModeName ~= "") and string.format('<font color="%s">MODE</font>  %s', hexOf(bright:Lerp(WHITE, 0.25)), q.ModeName) or "",
			ZIndex = 72,
			Parent = banner,
		}, { textStroke(1), make("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }) })
		local glow
		if b.Hint then
			glow = make("Frame", {
				Name = "PlayGlow",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -20, 0, 125),
				Size = UDim2.fromOffset(pillW + 8, 36),
				BackgroundColor3 = bright,
				BackgroundTransparency = 1,
				ZIndex = 71,
				Parent = banner,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			make("Frame", {
				Name = "Play",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -24, 0, 125),
				Size = UDim2.fromOffset(pillW, 28),
				BackgroundColor3 = color,
				ZIndex = 72,
				Parent = banner,
			}, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }),
				gradient(WHITE, Color3.fromRGB(190, 190, 190), 90),
				make("UIStroke", { Thickness = 2, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				make("TextLabel", {
					Name = "Hint",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -18, 1, -8),
					BackgroundTransparency = 1,
					Font = HEAD_FONT,
					TextScaled = true,
					TextColor3 = WHITE,
					Text = b.Hint,
					ZIndex = 73,
				}, { textStroke(1.5), make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 10 }) }),
			})
		end
		-- sparks thrown off the badge as it lands
		local sparks = {}
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local spark = make("Frame", {
				Name = "Spark",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(110, 75),
				Size = UDim2.fromOffset(i % 3 == 0 and 7 or 5, i % 3 == 0 and 7 or 5),
				Rotation = 45,
				BackgroundColor3 = i % 2 == 0 and WHITE or bright,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 73,
				Parent = banner,
			})
			table.insert(sparks, { spark, a, rng:NextNumber(70, 128) })
		end
		-- a glint across it
		local shine = make("Frame", {
			Name = "Shine",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 74,
			Parent = banner,
		}, {
			make("UIGradient", {
				Rotation = 20,
				Offset = Vector2.new(-1.2, 0),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.45, 1),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(0.55, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		if b.OnShow then
			task.spawn(b.OnShow)
		end
		tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.08, function()
			tween(avatarPop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(ring, 0.65, { Size = UDim2.fromOffset(170, 170) }, Enum.EasingStyle.Quart)
			tween(ring.UIStroke, 0.65, { Transparency = 1, Thickness = 1 })
			for i, ray in rays do
				tween(ray, 0.3, { BackgroundTransparency = i % 2 == 0 and 0.2 or 0.05 })
				tween(ray, 4.2, { Rotation = ray.Rotation + 40 }, Enum.EasingStyle.Linear)
			end
			for _, s in sparks do
				local spark, a, dist = s[1], s[2], s[3]
				spark.BackgroundTransparency = 0
				tween(spark, 0.55, {
					Position = UDim2.fromOffset(110 + math.cos(a) * dist, 75 + math.sin(a) * dist * 0.75),
					Rotation = 45 + rng:NextNumber(-160, 160),
					BackgroundTransparency = 1,
				}, Enum.EasingStyle.Quart)
			end
		end)
		RP.edgeFlash(color)
		task.delay(0.16, function()
			local wide = nameWide
			if not wide then
				-- (nothing measured it: what the label laid out, over its width, in offsets)
				local ok, w = pcall(function()
					return title.TextBounds.X / math.max(1, title.AbsoluteSize.X) * NAME_W
				end)
				wide = (ok and w == w and w > 0) and w or 240
			end
			tween(underline, 0.5, { Size = UDim2.fromOffset(math.min(wide, NAME_W) + 6, 3) }, Enum.EasingStyle.Quint)
		end)
		task.delay(0.22, function()
			tween(shine.UIGradient, 0.75, { Offset = Vector2.new(1.2, 0) }, Enum.EasingStyle.Sine)
		end)
		-- (the moves tick in, a letter or two a frame)
		task.delay(0.3, function()
			local n = utf8.len(movesPlain) or #movesPlain
			for i = 2, n, 2 do
				if not moves.Parent then
					return
				end
				moves.MaxVisibleGraphemes = i
				task.wait(1 / 60)
			end
			moves.MaxVisibleGraphemes = -1
		end)
		tween(ghost, 4.3, { Position = UDim2.new(1, -10, 0.5, 6) }, Enum.EasingStyle.Linear)
		-- held, the pill breathing - cut short if the phone comes out (it says the rest)
		local t0, cut = os.clock(), false
		while holder.Parent and os.clock() - t0 < 3.8 do
			if HUD.MenuVisible and HUD.MenuVisible() then
				cut = true
				break
			end
			if glow then
				glow.BackgroundTransparency = 0.55 + 0.35 * (0.5 + 0.5 * math.cos((os.clock() - t0) * 5))
			end
			task.wait(0.05)
		end
		if holder.Parent then
			local out = cut and 0.2 or 0.45
			fadeAll(banner, out)
			tween(banner, out, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -18) })
			task.wait(out + 0.03)
			holder:Destroy()
		end
		return cut
	end

	-- NEW HERO: a hero just released to everyone (one at a time; a reset
	-- releasing lots shows the first four). hint: how to play him (the pill).
	-- onShow runs as it comes up (its sound). opts: { Still = fn -> is it
	-- still news (checked as it comes up), Tap = true: a tap on it opens the
	-- phone on his row (touch) }.
	-- (review) Each waits for the phone, a rank-up or a K.O. to go first; one
	-- whose hero's been pulled back meanwhile is dropped; and the phone coming
	-- out ends it and drops the rest (the phone shows them, NEW).
	function HUD.RosterBanner(quirkName, hint, onShow, opts)
		if not gui or not Config.Quirks[quirkName or ""] or #RP.banners >= 4 then
			return
		end
		for _, b in RP.banners do
			if b.Quirk == quirkName then
				return -- (already waiting)
			end
		end
		opts = type(opts) == "table" and opts or {}
		table.insert(RP.banners, { Quirk = quirkName, Hint = hint, OnShow = onShow, Still = opts.Still, Tap = opts.Tap == true })
		if RP.showing then
			return
		end
		RP.showing = true
		task.spawn(function()
			local function phoneOut()
				return HUD.MenuVisible ~= nil and HUD.MenuVisible()
			end
			while #RP.banners > 0 do
				local b = table.remove(RP.banners, 1)
				local t = os.clock()
				while os.clock() - t < 12 and (phoneOut() or gui:FindFirstChild("RankUp") or gui:FindFirstChild("KOPopup")) do
					task.wait(0.2)
				end
				-- (still news? Not with his hero pulled back meanwhile, or with the
				-- phone still out: it's showing him, NEW)
				if not (Config.IsDevOnly(b.Quirk) or phoneOut() or (b.Still and not b.Still())) then
					local ok, cut = pcall(RP.showBanner, b)
					if not ok then
						warn("[HUD] roster banner: " .. tostring(cut))
					elseif cut then
						table.clear(RP.banners)
					end
				end
			end
			RP.showing = false
		end)
	end
end

---------------------------------------------------------------------------
-- (round 87) ADMIN EVENTS on the screen (Config.AdminEvents; the server's
-- Kit.AE runs them, QuirkClient reads what's running off workspace):
--  HUD.BuildEventsPanel(cb) / HUD.RefreshEventsPanel() / HUD.ToggleEventsPanel
--   (force): the devs' ADMIN EVENTS side panel off the test menu - a card
--   per event (its icon and colour, its name, one line about it, START;
--   running: its time left, a bar running down, STOP), THIS SERVER | ALL
--   SERVERS, how long (AUTO: each event's own), STOP EVERY EVENT (two
--   clicks). cb = { Start(id, seconds | nil, all), Stop(id | "*", all) }.
--  HUD.EventBanner(spec): ADMIN ABUSE - the full-width band as one starts.
--  HUD.EventOver(list): EVENT OVER, stamped.
--  HUD.SetEventChips(list) / HUD.SetEventChipNote(id, text): a countdown
--   chip each, top centre.
--  HUD.ShuffleReel(hero, spin, opts): HERO SHUFFLE's slot machine.
---------------------------------------------------------------------------
do
	local EP = { cards = {}, chips = {}, notes = {}, queue = {}, pending = {}, cb = {}, all = false, seconds = nil }
	HUD.AE = EP
	local W = 384
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local HOT = Color3.fromRGB(255, 92, 60)
	local GREEN = Color3.fromRGB(60, 200, 110)
	local GOLD = Color3.fromRGB(255, 212, 64)
	local AMBER = Color3.fromRGB(255, 166, 64)
	local BLUE = Color3.fromRGB(110, 190, 255)
	local DIM = Color3.fromRGB(150, 154, 180)
	local TRACK = Color3.fromRGB(18, 19, 28)
	local ROW = Color3.fromRGB(38, 40, 57)
	local STOPRED = Color3.fromRGB(214, 58, 58)
	EP.SYNC = {
		Live = { "ALL SERVERS READY", GREEN },
		Local = { "MESSAGING DOWN", AMBER },
		Studio = { "STUDIO SESSION ONLY", BLUE },
		Loading = { "CONNECTING...", DIM },
	}
	local function AEC()
		return (Config and Config.AdminEvents) or {}
	end
	local function def(id)
		return AEC().Events and AEC().Events[id] or nil
	end
	local function clock(s)
		s = math.max(0, math.ceil((tonumber(s) or 0) - 0.05))
		return string.format("%d:%02d", s // 60, s % 60)
	end
	local function now()
		return workspace:GetServerTimeNow()
	end
	local function running()
		return Config.AdminEventsRunning and Config.AdminEventsRunning() or {}
	end
	EP.clock = clock

	-- an event's icon in a circle of its colour
	local function iconDisc(parent, d, size, textSize, z)
		local disc = make("Frame", {
			Name = "Icon",
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = d.Color:Lerp(BLACK, 0.5),
			ZIndex = z,
			Parent = parent,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 1.5, Color = d.Color, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Name = "Glyph",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = textSize,
			TextColor3 = WHITE,
			Text = d.Icon or "★",
			ZIndex = z + 1,
			Parent = disc,
		})
		return disc
	end

	---------------------------------------------------------------- the panel
	local function makeCard(order, id)
		local d = def(id)
		local card = make("Frame", {
			Name = id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = ROW,
			ZIndex = 22,
			Parent = EP.list,
		}, { corner(8), make("UIStroke", { Name = "Edge", Thickness = 1.5, Color = d.Color, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local flash = make("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = d.Color,
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = card,
		}, { corner(8) })
		make("Frame", {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -16),
			BackgroundColor3 = d.Color,
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = card,
		}, { corner(2) })
		local icon = iconDisc(card, d, 36, 20, 23)
		icon.Position = UDim2.fromOffset(11, 11)
		local title = make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(1, -150, 0, 17),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = d.Name,
			ZIndex = 23,
			Parent = card,
		}, { make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }) })
		local blurb = make("TextLabel", {
			Name = "Blurb",
			Position = UDim2.fromOffset(56, 23),
			Size = UDim2.new(1, -150, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(196, 199, 220),
			Text = d.Blurb or "",
			ZIndex = 23,
			Parent = card,
		})
		local meta = make("TextLabel", {
			Name = "Meta",
			Position = UDim2.fromOffset(56, 38),
			Size = UDim2.new(1, -150, 0, 13),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			RichText = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 23,
			Parent = card,
		})
		local button = make("TextButton", {
			Name = "Go",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(80, 32),
			BackgroundColor3 = d.Color,
			AutoButtonColor = true,
			Font = HEAD_FONT,
			TextSize = 13,
			TextColor3 = WHITE,
			Text = "START",
			ZIndex = 24,
			Parent = card,
		}, { corner(7), gradient(WHITE, Color3.fromRGB(196, 196, 196), 90), make("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), make("UIStroke", { Name = "TextEdge", Thickness = 1.2, Color = BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }) })
		local barBack = make("Frame", {
			Name = "BarBack",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -4),
			Size = UDim2.new(1, -110, 0, 3),
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 23,
			Parent = card,
		}, { corner(2) })
		local bar = make("Frame", {
			Name = "Bar",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = d.Color,
			BorderSizePixel = 0,
			ZIndex = 24,
			Parent = barBack,
		}, { corner(2) })
		EP.cards[id] = { Card = card, Flash = flash, Title = title, Blurb = blurb, Meta = meta, Go = button, BarBack = barBack, Bar = bar, Def = d }
		button.MouseButton1Click:Connect(function()
			EP.press(id)
		end)
	end

	-- a pill switch: THIS SERVER | ALL SERVERS
	local function scopeSwitch(parent)
		local sw = make("Frame", {
			Name = "Scope",
			Position = UDim2.fromOffset(14, 58),
			Size = UDim2.fromOffset(156, 26),
			BackgroundColor3 = TRACK,
			ZIndex = 21,
			Parent = parent,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local knob = make("Frame", {
			Name = "Knob",
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(0.5, -2, 1, -4),
			BackgroundColor3 = GOLD,
			ZIndex = 22,
			Parent = sw,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(205, 205, 205), 90) })
		local function half(name, x, text, all)
			local b = make("TextButton", {
				Name = name,
				Position = UDim2.fromScale(x, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 10,
				TextColor3 = DIM,
				Text = text,
				ZIndex = 23,
				Parent = sw,
			})
			b.MouseButton1Click:Connect(function()
				if EP.all ~= all then
					EP.all = all
					if EP.cb.Tick then
						EP.cb.Tick()
					end
					HUD.RefreshEventsPanel()
				end
			end)
			return b
		end
		EP.scope = { Frame = sw, Knob = knob, This = half("This", 0, "THIS SERVER", false), All = half("All", 0.5, "ALL SERVERS", true) }
	end

	-- how long: AUTO (each event's own) or a set time
	local function durationChips(parent)
		EP.durs = {}
		local list = { false }
		for _, s in AEC().Durations or { 60, 120, 180, 300 } do
			table.insert(list, s)
		end
		local w = 34 -- (5 of them: 186 px, clear of the scope switch's 156)
		for i, s in list do
			local b = make("TextButton", {
				Name = "Dur" .. i,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14 - (#list - i) * (w + 4), 0, 58),
				Size = UDim2.fromOffset(w, 26),
				BackgroundColor3 = TRACK,
				AutoButtonColor = true,
				Font = UI_FONT,
				TextSize = 10,
				TextColor3 = DIM,
				Text = s and (s % 60 == 0 and (s // 60 .. "m") or clock(s)) or "AUTO",
				ZIndex = 21,
				Parent = parent,
			}, { corner(7), make("UIStroke", { Name = "Edge", Thickness = 1, Color = WHITE, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			b:SetAttribute("Seconds", s or 0)
			b.MouseButton1Click:Connect(function()
				EP.seconds = s or nil
				if EP.cb.Tick then
					EP.cb.Tick()
				end
				HUD.RefreshEventsPanel()
			end)
			table.insert(EP.durs, { Button = b, Seconds = s or nil })
		end
	end

	function HUD.BuildEventsPanel(cb)
		EP.cb = cb or {}
		if EP.frame or not gui then
			return
		end
		local frame = make("Frame", {
			Name = "AdminEvents",
			Position = UDim2.new(0, 22 + TEST_W, 0, 108),
			Size = UDim2.fromOffset(W, 540),
			BackgroundColor3 = Color3.fromRGB(24, 22, 30),
			BackgroundTransparency = 0.04,
			Visible = false,
			ZIndex = 20,
			Parent = gui,
		}, { stroke(3), corner(8) })
		EP.frame = frame
		-- a little of the red light from the top
		make("Frame", {
			Name = "Glow",
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = HOT,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = frame,
		}, { corner(8), make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.3, 1) }) })
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(14, 5),
			Size = UDim2.new(1, -190, 0, 32),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 27,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = HOT,
			Text = "ADMIN EVENTS",
			ZIndex = 21,
			Parent = frame,
		}, { textStroke(1.5) })
		EP.sync = make("Frame", {
			Name = "Sync",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(164, 22),
			BackgroundColor3 = TRACK,
			ZIndex = 21,
			Parent = frame,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Name = "Edge", Thickness = 1, Color = GREEN, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		EP.syncDot = make("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = GREEN,
			ZIndex = 22,
			Parent = EP.sync,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		EP.syncText = make("TextLabel", {
			Name = "Text",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -28, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = "CONNECTING...",
			ZIndex = 22,
			Parent = EP.sync,
		}, { make("UITextSizeConstraint", { MaxTextSize = 10, MinTextSize = 7 }) })
		EP.sub = make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(14, 37),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(196, 190, 214),
			Text = "Server-wide events. Everyone plays them.",
			ZIndex = 21,
			Parent = frame,
		})
		scopeSwitch(frame)
		durationChips(frame)
		EP.topLine = make("Frame", {
			Name = "Line",
			Position = UDim2.fromOffset(12, 92),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		EP.list = make("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(8, 98),
			Size = UDim2.new(1, -12, 1, -98 - 74),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = WHITE,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 21,
			Parent = frame,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }),
		})
		for order, id in AEC().Order or {} do
			if def(id) then
				makeCard(order, id)
			end
		end
		EP.footLine = make("Frame", {
			Name = "FootLine",
			Position = UDim2.new(0, 12, 1, -72),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		EP.info = make("TextLabel", {
			Name = "Last",
			Position = UDim2.new(0, 14, 1, -66),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 21,
			Parent = frame,
		})
		EP.stopAll = make("TextButton", {
			Name = "StopAll",
			Position = UDim2.new(0, 12, 1, -44),
			Size = UDim2.new(1, -24, 0, 32),
			BackgroundColor3 = STOPRED,
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = WHITE,
			Text = "STOP EVERY EVENT",
			ZIndex = 22,
			Parent = frame,
		}, { corner(6), stroke(1.5) })
		-- (two clicks: the first arms it for 3 s)
		EP.stopAll.MouseButton1Click:Connect(function()
			if not EP.canStopAll then
				return
			end
			if EP.armed and os.clock() - EP.armed < 3 then
				EP.armed = nil
				if EP.cb.Stop then
					EP.cb.Stop("*", EP.all)
				end
			else
				EP.armed = os.clock()
				local at = EP.armed
				task.delay(3, function()
					if EP.armed == at then
						EP.armed = nil
						HUD.RefreshEventsPanel()
					end
				end)
			end
			HUD.RefreshEventsPanel()
		end)
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if EP.frame.Visible then
					EP.layout()
				end
			end)
		end
		HUD.RefreshEventsPanel()
	end

	-- a card's button: START (or, running, STOP); dimmed till the server's state changes
	function EP.press(id)
		if EP.pending[id] then
			return
		end
		local live = running()[id] ~= nil
		local token = os.clock()
		EP.pending[id] = { At = token, Was = live }
		if live then
			if EP.cb.Stop then
				EP.cb.Stop(id, EP.all)
			end
		elseif EP.cb.Start then
			EP.cb.Start(id, EP.seconds, EP.all)
		end
		HUD.RefreshEventsPanel()
		task.delay(4, function()
			local p = EP.pending[id]
			if p and p.At == token then
				EP.pending[id] = nil -- (the server didn't do it: back as it is)
				HUD.RefreshEventsPanel()
			end
		end)
	end

	-- fits the screen: on a short one (a phone) it starts just under the top
	-- bar, and the line under the title goes
	function EP.layout()
		local cam = workspace.CurrentCamera
		local vpY = (cam and cam.ViewportSize.Y) or 720
		local y0 = vpY < 500 and 52 or 108
		local h = math.clamp(vpY - y0 - 12, 200, 540)
		local compact = h < 340
		EP.frame.Position = UDim2.new(0, 22 + TEST_W, 0, y0)
		EP.frame.Size = UDim2.fromOffset(W, h)
		EP.sub.Visible = not compact
		EP.info.Visible = not compact
		local rowY = compact and 38 or 58
		EP.scope.Frame.Position = UDim2.fromOffset(14, rowY)
		for _, d in EP.durs do
			d.Button.Position = UDim2.new(d.Button.Position.X.Scale, d.Button.Position.X.Offset, 0, rowY)
		end
		local top, bottom = rowY + 40, compact and 50 or 74
		EP.topLine.Position = UDim2.fromOffset(12, top - 6)
		EP.list.Position = UDim2.fromOffset(8, top)
		EP.list.Size = UDim2.new(1, -12, 1, -top - bottom)
		EP.footLine.Position = UDim2.new(0, 12, 1, -bottom + 2)
	end

	-- what's running, the scope, the time picked, the sync
	function HUD.RefreshEventsPanel()
		if not EP.frame then
			return
		end
		local map = running()
		local t = now()
		local n = 0
		for _ in map do
			n += 1
		end
		for id, c in EP.cards do
			local e = map[id]
			local p = EP.pending[id]
			if p and p.Was ~= (e ~= nil) then
				EP.pending[id] = nil
				p = nil
			end
			local d = c.Def
			if e then
				local left = math.max(0, e.Ends - t)
				local bits = { string.format('<font color="#FFFFFF">%s LEFT</font>', clock(left)) }
				if e.Global then
					table.insert(bits, "EVERY SERVER")
				end
				if e.By then
					table.insert(bits, "BY " .. string.upper(e.By))
				end
				c.Meta.Text = table.concat(bits, "  ·  ")
				c.Meta.TextColor3 = d.Color:Lerp(WHITE, 0.35)
				c.Go.Text = p and "..." or "STOP"
				c.Go.BackgroundColor3 = STOPRED
				c.Card:FindFirstChild("Edge").Transparency = 0.15
				c.Card.BackgroundColor3 = ROW:Lerp(d.Color, 0.14)
				c.BarBack.Visible = true
				c.Bar.Size = UDim2.fromScale(math.clamp(left / math.max(e.Length or 1, 1), 0, 1), 1)
			else
				local clash
				for _, other in (AEC().Clash or {})[id] or {} do
					if map[other] then
						clash = def(other).Name
					end
				end
				local secs = EP.seconds or d.Duration or 90
				c.Meta.Text = clash and string.format('<font color="#FFA640">ENDS %s</font>  ·  %s', clash, clock(secs)) or (EP.seconds and clock(secs) or ("AUTO " .. clock(secs)))
				c.Meta.TextColor3 = DIM
				c.Go.Text = p and "..." or "START"
				c.Go.BackgroundColor3 = d.Color
				c.Card:FindFirstChild("Edge").Transparency = 1
				c.Card.BackgroundColor3 = ROW
				c.BarBack.Visible = false
			end
			c.Go.AutoButtonColor = p == nil
			c.Go.BackgroundTransparency = p and 0.45 or 0
			-- (it changed, here or on another server: a flash across the card)
			local state = e ~= nil
			if EP.drawn and EP.drawn[id] ~= nil and EP.drawn[id] ~= state then
				c.Flash.BackgroundTransparency = 0.5
				tween(c.Flash, 0.7, { BackgroundTransparency = 1 })
			end
			EP.drawn = EP.drawn or {}
			EP.drawn[id] = state
		end
		-- the scope switch and the time picked
		local s = EP.scope
		tween(s.Knob, 0.2, { Position = EP.all and UDim2.new(0.5, 0, 0, 2) or UDim2.new(0, 2, 0, 2), BackgroundColor3 = EP.all and HOT or GOLD }, Enum.EasingStyle.Quint)
		s.This.TextColor3 = EP.all and DIM or BLACK
		s.All.TextColor3 = EP.all and WHITE or DIM
		for _, d in EP.durs do
			local on = d.Seconds == EP.seconds
			d.Button.BackgroundColor3 = on and GOLD or TRACK
			d.Button.TextColor3 = on and BLACK or DIM
		end
		local syncKey = workspace:GetAttribute("AdminEventsSync") or "Loading"
		local sync = EP.SYNC[syncKey] or EP.SYNC.Loading
		EP.syncText.Text = sync[1]
		EP.syncDot.BackgroundColor3 = sync[2]
		EP.sync.Edge.Color = sync[2]
		if EP.all and syncKey == "Studio" then
			EP.info.Text = "Studio: ALL SERVERS stays in this session (StudioSends is off)"
			EP.info.TextColor3 = BLUE
		elseif EP.all and syncKey ~= "Live" then
			EP.info.Text = "Messaging isn't answering: ALL SERVERS reaches this server only"
			EP.info.TextColor3 = AMBER
		else
			EP.info.Text = string.format("%d running (%d at most)  ·  %s", n, AEC().MaxRunning or 4, EP.all and "START reaches every server" or "START: this server")
			EP.info.TextColor3 = DIM
		end
		EP.canStopAll = n > 0
		local armed = EP.armed ~= nil and EP.canStopAll
		EP.stopAll.AutoButtonColor = EP.canStopAll
		EP.stopAll.BackgroundColor3 = armed and Color3.fromRGB(226, 92, 48) or EP.canStopAll and STOPRED or Color3.fromRGB(58, 60, 78)
		EP.stopAll.TextColor3 = EP.canStopAll and WHITE or DIM
		EP.stopAll.Text = armed and string.format("SURE? CLICK AGAIN: STOP %d EVENT%s%s", n, n == 1 and "" or "S", EP.all and " EVERYWHERE" or "")
			or EP.canStopAll and (EP.all and "STOP EVERY EVENT, EVERY SERVER" or "STOP EVERY EVENT") or "NOTHING'S RUNNING"
	end

	function HUD.ToggleEventsPanel(force)
		local frame = EP.frame
		if not frame then
			return false
		end
		if force ~= nil then
			frame.Visible = force
		else
			frame.Visible = not frame.Visible
		end
		if frame.Visible then
			EP.layout()
			HUD.RefreshEventsPanel()
			-- (the countdowns run while it's open)
			EP.tickToken = (EP.tickToken or 0) + 1
			local token = EP.tickToken
			task.spawn(function()
				while EP.tickToken == token and frame.Visible do
					task.wait(0.25)
					if next(running()) ~= nil then
						HUD.RefreshEventsPanel()
					end
				end
			end)
		end
		return frame.Visible
	end

	---------------------------------------------------------------- the banner
	-- a camera-flash off the screen's top and bottom, in the event's colour
	function EP.edgeFlash(color)
		local holder = make("Frame", { Name = "AdminEventFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 74, Parent = gui })
		for _, y in { 0, 1 } do
			local glow = make("Frame", {
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, 0.24),
				BackgroundColor3 = color:Lerp(WHITE, 0.35),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 74,
				Parent = holder,
			}, { make("UIGradient", { Rotation = y == 0 and 90 or -90, Transparency = NumberSequence.new(0, 1) }) })
			tween(glow, 0.06, { BackgroundTransparency = 0.3 })
			task.delay(0.08, function()
				tween(glow, 0.8, { BackgroundTransparency = 1 })
			end)
		end
		task.delay(1, function()
			holder:Destroy()
		end)
	end
	-- a strip of hazard stripes (the event's colour and black), scrolling
	local function hazard(parent, y, color, z)
		local strip = make("Frame", {
			Name = "Hazard",
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 12),
			BackgroundColor3 = Color3.fromRGB(14, 12, 14),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = z,
			Parent = parent,
		})
		local slide = make("Frame", {
			Name = "Slide",
			Size = UDim2.new(1, 64, 1, 0),
			Position = UDim2.fromOffset(-64, 0),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = strip,
		})
		for i = 0, 70 do
			make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, i * 32, 0.5, 0),
				Size = UDim2.fromOffset(14, 34),
				Rotation = 35,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = slide,
			})
		end
		return strip, slide
	end
	-- spec: { Id, Name, Icon, Color, Blurb, Length, Global, By }. Returns when it's gone.
	function EP.showBanner(spec)
		local color = spec.Color or HOT
		local bright = color:Lerp(WHITE, 0.25)
		-- (the band as tall as the words in it: they follow the screen size)
		local cam = workspace.CurrentCamera
		local k = math.clamp(((cam and cam.ViewportSize.Y) or 720) / 720, 0.75, 1.5)
		local holder = make("Frame", {
			Name = "AdminEventBanner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.new(1, 0, 0, math.floor(196 * k)),
			BackgroundTransparency = 1,
			ZIndex = 75,
			Parent = gui,
		})
		local band = make("Frame", {
			Name = "Band",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(12, 10, 14),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 75,
			Parent = holder,
		})
		local squash = make("UIScale", { Scale = 1, Parent = band })
		-- the colour washing in at the middle
		make("Frame", {
			Name = "Tint",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 75,
			Parent = band,
		}, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.55),
					NumberSequenceKeypoint.new(0.5, 0.25),
					NumberSequenceKeypoint.new(0.7, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		local _, slideTop = hazard(band, 0, color, 76)
		local _, slideBottom = hazard(band, 1, color, 76)
		local flash = make("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 79,
			Parent = band,
		})
		-- the words, in a block that follows the screen size
		local content = make("Frame", {
			Name = "Content",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1000, 196),
			BackgroundTransparency = 1,
			ZIndex = 77,
			Parent = band,
		})
		autoScale(content)
		local kicker = make("TextLabel", {
			Name = "Kicker",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 18),
			Size = UDim2.fromOffset(800, 26),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 22,
			TextColor3 = Color3.fromRGB(255, 226, 90),
			Text = "⚠   A D M I N   A B U S E   ⚠",
			TextTransparency = 1,
			ZIndex = 78,
			Parent = content,
		}, { textStroke(2) })
		local nameText = string.format("%s  %s  %s", spec.Icon or "", string.upper(spec.Name or "EVENT"), spec.Icon or "")
		local nameHolder = make("Frame", {
			Name = "NameHolder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(960, 84),
			BackgroundTransparency = 1,
			ZIndex = 78,
			Parent = content,
		})
		local slam = make("UIScale", { Scale = 2.4, Parent = nameHolder })
		make("TextLabel", {
			Name = "Shadow",
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextScaled = true,
			TextColor3 = color:Lerp(BLACK, 0.35),
			Text = nameText,
			TextTransparency = 1,
			ZIndex = 78,
			Parent = nameHolder,
		}, { make("UITextSizeConstraint", { MaxTextSize = 86, MinTextSize = 30 }) })
		local name = make("TextLabel", {
			Name = "EventName",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextScaled = true,
			TextColor3 = WHITE,
			Text = nameText,
			TextTransparency = 1,
			ZIndex = 79,
			Parent = nameHolder,
		}, { make("UIStroke", { Thickness = 3.5, Color = BLACK }), make("UITextSizeConstraint", { MaxTextSize = 86, MinTextSize = 30 }), gradient(WHITE, bright:Lerp(WHITE, 0.45), 90) })
		local blurb = make("TextLabel", {
			Name = "Blurb",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 134),
			Size = UDim2.fromOffset(900, 20),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 17,
			TextColor3 = WHITE,
			Text = spec.Blurb or "",
			TextTransparency = 1,
			ZIndex = 78,
			Parent = content,
		}, { textStroke(1.5) })
		-- the pills: how long, every server, who
		local pills = make("Frame", {
			Name = "Pills",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 160),
			Size = UDim2.fromOffset(700, 20),
			BackgroundTransparency = 1,
			ZIndex = 78,
			Parent = content,
		}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function pillOf(order, text, bg, fg)
			local p = make("TextLabel", {
				Name = "Pill",
				LayoutOrder = order,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 20),
				BackgroundColor3 = bg,
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 12,
				TextColor3 = fg,
				TextTransparency = 1,
				Text = text,
				ZIndex = 78,
				Parent = pills,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
			return p
		end
		local pillList = { pillOf(1, "⏱ " .. clock(spec.Length or 0), color, WHITE) }
		if spec.Global then
			table.insert(pillList, pillOf(2, "ON EVERY SERVER", GOLD, BLACK))
		end
		if spec.By then
			table.insert(pillList, pillOf(3, "BY " .. string.upper(spec.By), Color3.fromRGB(40, 40, 52), Color3.fromRGB(220, 222, 236)))
		end
		-- sparks thrown off the name as it lands
		local sparks = {}
		for i = 1, 18 do
			local spark = make("Frame", {
				Name = "Spark",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 90),
				Size = UDim2.fromOffset(i % 3 == 0 and 9 or 6, i % 3 == 0 and 9 or 6),
				Rotation = 45,
				BackgroundColor3 = i % 2 == 0 and WHITE or bright,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 79,
				Parent = content,
			})
			table.insert(sparks, { spark, (i / 18) * math.pi * 2 + rng:NextNumber(-0.2, 0.2), rng:NextNumber(160, 420) })
		end
		if spec.OnShow then
			task.spawn(spec.OnShow)
		end
		-- in: the band opens from a line, the kicker, then the name slams down
		band.Size = UDim2.new(1, 0, 0, 6)
		band.Position = UDim2.new(0, 0, 0.5, -3)
		tween(band, 0.18, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quart)
		tween(kicker, 0.2, { TextTransparency = 0 })
		task.spawn(function()
			-- (the stripes crawl)
			local t0 = os.clock()
			while holder.Parent do
				local x = -64 + ((os.clock() - t0) * 90) % 32
				slideTop.Position = UDim2.fromOffset(x, 0)
				slideBottom.Position = UDim2.fromOffset(-64 + 32 - ((os.clock() - t0) * 90) % 32, 0)
				task.wait(1 / 30)
			end
		end)
		task.delay(0.3, function()
			for _, l in { name, nameHolder.Shadow } do
				tween(l, 0.12, { TextTransparency = 0 })
			end
			tween(slam, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
		-- THE SLAM (on the sting's hit): a flash, the band jolts, sparks, the edges flash
		task.delay(0.58, function()
			if not holder.Parent then
				return
			end
			flash.BackgroundTransparency = 0.35
			tween(flash, 0.35, { BackgroundTransparency = 1 })
			squash.Scale = 1.06
			tween(squash, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			EP.edgeFlash(color)
			for _, s in sparks do
				local spark, a, dist = s[1], s[2], s[3]
				spark.BackgroundTransparency = 0
				tween(spark, 0.6, {
					Position = UDim2.new(0.5, math.cos(a) * dist, 0, 90 + math.sin(a) * dist * 0.28),
					Rotation = 45 + rng:NextNumber(-180, 180),
					BackgroundTransparency = 1,
				}, Enum.EasingStyle.Quart)
			end
			tween(blurb, 0.25, { TextTransparency = 0 })
			for _, p in pillList do
				tween(p, 0.25, { TextTransparency = 0, BackgroundTransparency = 0 })
			end
			-- (the shake)
			local t0 = os.clock()
			while os.clock() - t0 < 0.32 and holder.Parent do
				local k = 1 - (os.clock() - t0) / 0.32
				holder.Position = UDim2.new(0.5, rng:NextNumber(-10, 10) * k, 0.3, rng:NextNumber(-6, 6) * k)
				task.wait(1 / 30)
			end
			holder.Position = UDim2.fromScale(0.5, 0.3)
		end)
		-- held, then out to the side
		local hold = (AEC().Banner and AEC().Banner.Hold) or 3.2
		task.wait(0.6 + hold)
		if holder.Parent then
			tween(holder, 0.32, { Position = UDim2.fromScale(-0.55, 0.3) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			task.wait(0.34)
			holder:Destroy()
		end
	end
	-- queued: one at a time (a burst of starts shows the first four)
	function HUD.EventBanner(spec)
		if not gui or type(spec) ~= "table" or #EP.queue >= 4 then
			return
		end
		table.insert(EP.queue, spec)
		if EP.showing then
			return
		end
		EP.showing = true
		task.spawn(function()
			while #EP.queue > 0 do
				local s = table.remove(EP.queue, 1)
				if not s.Still or s.Still() then
					local ok, err = pcall(EP.showBanner, s)
					if not ok then
						warn("[HUD] event banner: " .. tostring(err))
					end
				end
			end
			EP.showing = false
		end)
	end

	-- EVENT OVER: list = { { Name, Color, Icon } } (one band, however many ended)
	function HUD.EventOver(list)
		if not gui or type(list) ~= "table" or #list == 0 then
			return
		end
		local first = list[1]
		local color = (first.Color or HOT):Lerp(Color3.fromRGB(150, 150, 160), 0.4)
		local holder = make("Frame", {
			Name = "AdminEventOver",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(640, 96),
			BackgroundTransparency = 1,
			ZIndex = 74,
			Parent = gui,
		})
		autoScale(holder)
		local band = make("Frame", {
			Name = "Band",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(12, 12, 16),
			BackgroundTransparency = 0.2,
			ZIndex = 74,
			Parent = holder,
		}, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.15, 0),
					NumberSequenceKeypoint.new(0.85, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		local names = {}
		for _, e in list do
			table.insert(names, string.upper(e.Name or "EVENT"))
		end
		local nameText = table.concat(names, "  ·  ")
		local label = make("TextLabel", {
			Name = "Names",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromOffset(560, 34),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextColor3 = color,
			Text = nameText,
			ZIndex = 75,
			Parent = band,
		}, { textStroke(1.5), make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }) })
		-- struck through
		local strike = make("Frame", {
			Name = "Strike",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.5, -230, 0.36, 0),
			Size = UDim2.fromOffset(0, 4),
			Rotation = -2,
			BackgroundColor3 = Color3.fromRGB(255, 70, 60),
			BorderSizePixel = 0,
			ZIndex = 76,
			Parent = band,
		}, { corner(2) })
		local stamp = make("TextLabel", {
			Name = "Stamp",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.74),
			Size = UDim2.fromOffset(300, 40),
			Rotation = -5,
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 38,
			TextColor3 = Color3.fromRGB(255, 76, 64),
			TextTransparency = 1,
			Text = #list > 1 and "EVENTS OVER" or "EVENT OVER",
			ZIndex = 77,
			Parent = band,
		}, { make("UIStroke", { Thickness = 2.5, Color = WHITE, Transparency = 1 }) })
		local stampScale = make("UIScale", { Scale = 1.9, Parent = stamp })
		tween(strike, 0.32, { Size = UDim2.fromOffset(460, 4) }, Enum.EasingStyle.Quint)
		task.delay(0.16, function()
			tween(stamp, 0.1, { TextTransparency = 0 })
			tween(stamp.UIStroke, 0.1, { Transparency = 0 })
			tween(stampScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		task.delay(2.2, function()
			for _, d in holder:GetDescendants() do
				if d:IsA("TextLabel") then
					tween(d, 0.4, { TextTransparency = 1 })
				elseif d:IsA("Frame") then
					tween(d, 0.4, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					tween(d, 0.4, { Transparency = 1 })
				end
			end
			tween(holder, 0.4, { Position = UDim2.new(0.5, 0, 0.3, -16) })
			task.wait(0.42)
			holder:Destroy()
		end)
	end

	---------------------------------------------------------------- the chips
	-- top centre, one per event running: its icon, name, time left (red and
	-- pulsing the last 10 s), a bar running down, a note (EVERY SERVER, your
	-- bills...). Under the raid boss's bar while a Nomu's in the city; on a
	-- narrow screen in two rows (clear of the rank card on the right).
	EP.CHIP_W, EP.CHIP_H, EP.CHIP_GAP = 190, 36, 6
	local function chipRow()
		if EP.row or not gui then
			return EP.row
		end
		EP.row = make("Frame", {
			Name = "AdminEventChips",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 46),
			Size = UDim2.fromOffset(EP.CHIP_W, EP.CHIP_H),
			BackgroundTransparency = 1,
			ZIndex = 15,
			Parent = gui,
		})
		EP.rowScale = autoScale(EP.row)
		return EP.row
	end
	local function makeChip(order, id, d)
		local chip = make("Frame", {
			Name = id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(EP.CHIP_W, EP.CHIP_H),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = GLASS.T,
			ZIndex = 15,
			Parent = EP.row,
		}, { corner(6), make("UIStroke", { Name = "Edge", Thickness = 1, Color = d.Color, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local icon = iconDisc(chip, d, 26, 15, 16)
		icon.Position = UDim2.fromOffset(5, 5)
		local name = make("TextLabel", {
			Name = "EventName",
			Position = UDim2.fromOffset(36, 4),
			Size = UDim2.new(1, -86, 0, 14),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = d.Name,
			ZIndex = 16,
			Parent = chip,
		}, { make("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 7 }) })
		local note = make("TextLabel", {
			Name = "Note",
			Position = UDim2.fromOffset(36, 18),
			Size = UDim2.new(1, -86, 0, 11),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 9,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = d.Color:Lerp(WHITE, 0.4),
			Text = "",
			ZIndex = 16,
			Parent = chip,
		})
		local time = make("TextLabel", {
			Name = "Time",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, -1),
			Size = UDim2.fromOffset(48, 20),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 16,
			Parent = chip,
		}, { textStroke(1) })
		local bar = make("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -2),
			Size = UDim2.new(1, -8, 0, 2),
			BackgroundColor3 = d.Color,
			BorderSizePixel = 0,
			ZIndex = 16,
			Parent = chip,
		})
		local pop = make("UIScale", { Scale = 0.4, Parent = chip })
		tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		EP.chips[id] = { Chip = chip, Name = name, Note = note, Time = time, Bar = bar, Def = d, Pop = pop }
	end
	-- list: { { Id, Ends, Length, Global } } in Order (empty: none)
	function HUD.SetEventChips(list)
		if not gui then
			return
		end
		local row = chipRow()
		local keep = {}
		for order, e in list do
			local d = def(e.Id)
			if d then
				keep[e.Id] = true
				if not EP.chips[e.Id] then
					makeChip(order, e.Id, d)
				end
				local c = EP.chips[e.Id]
				c.Chip.LayoutOrder = order
				c.Ends, c.Length, c.Global = e.Ends, e.Length, e.Global
			end
		end
		for id, c in EP.chips do
			if not keep[id] then
				EP.chips[id] = nil
				local chip = c.Chip
				tween(c.Pop, 0.2, { Scale = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.21, function()
					chip:Destroy()
				end)
			end
		end
		EP.drawChips()
		if next(EP.chips) ~= nil and not EP.chipsTicking then
			EP.chipsTicking = true
			task.spawn(function()
				while next(EP.chips) ~= nil do
					EP.drawChips()
					task.wait(0.1)
				end
				EP.chipsTicking = false
			end)
		end
		return row
	end
	function HUD.SetEventChipNote(id, text)
		EP.notes[id] = text
		EP.drawChips()
	end
	function EP.drawChips()
		if not EP.row then
			return
		end
		-- (a Nomu raid's boss bar is up there: under it)
		local raid = gui.Parent and gui.Parent:FindFirstChild("NomuRaidGui")
		local boss = raid and raid:FindFirstChild("Boss", true)
		EP.row.Position = UDim2.new(0.5, 0, 0, (boss and boss:IsA("GuiObject") and boss.Visible) and 100 or 46)
		-- (as many to a row as fit between the rank card's column and its twin on the left)
		local cam = workspace.CurrentCamera
		local vpX = (cam and cam.ViewportSize.X) or 1280
		local k = (EP.rowScale and EP.rowScale.Scale) or 1
		local step = EP.CHIP_W + EP.CHIP_GAP
		local perRow = math.max(1, math.floor(((vpX - 352) / k + EP.CHIP_GAP) / step))
		local list = {}
		for _, c in EP.chips do
			table.insert(list, c)
		end
		table.sort(list, function(a, b)
			return a.Chip.LayoutOrder < b.Chip.LayoutOrder
		end)
		local n = #list
		local wide = math.max(math.min(n, perRow) * step - EP.CHIP_GAP, EP.CHIP_W)
		EP.row.Size = UDim2.fromOffset(wide, math.max(1, math.ceil(n / perRow)) * (EP.CHIP_H + EP.CHIP_GAP) - EP.CHIP_GAP)
		for i, c in list do
			local r, col = (i - 1) // perRow, (i - 1) % perRow
			local m = math.min(perRow, n - r * perRow)
			c.Chip.Position = UDim2.fromOffset((wide - (m * step - EP.CHIP_GAP)) / 2 + col * step, r * (EP.CHIP_H + EP.CHIP_GAP))
		end
		local t = now()
		for id, c in EP.chips do
			local left = math.max(0, (c.Ends or t) - t)
			c.Time.Text = clock(left)
			local hurry = left <= 10
			c.Time.TextColor3 = hurry and Color3.fromRGB(255, 90 + 80 * (0.5 + 0.5 * math.cos(os.clock() * 8)), 80) or WHITE
			c.Bar.Size = UDim2.new(math.clamp(left / math.max(c.Length or 1, 1), 0, 1), -8, 0, 2)
			c.Note.Text = EP.notes[id] or (c.Global and "EVERY SERVER" or "")
		end
	end

	---------------------------------------------------------------- the reel
	-- HERO SHUFFLE's slot machine: heroes rolling past, slowing, landing on
	-- yours at spin s. opts: { Pool = { ids }, OnTick = fn (a hero going by),
	-- OnLand = fn }
	function HUD.ShuffleReel(hero, spin, opts)
		opts = type(opts) == "table" and opts or {}
		local q = Config.Quirks[hero or ""]
		if not gui or not q then
			return
		end
		local old = gui:FindFirstChild("AdminShuffleReel")
		if old then
			old:Destroy()
		end
		spin = math.clamp(tonumber(spin) or 2.6, 0.5, 6)
		local CELL = 40
		local holder = make("Frame", {
			Name = "AdminShuffleReel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(380, 212),
			BackgroundColor3 = Color3.fromRGB(20, 16, 12),
			BackgroundTransparency = 0.08,
			ZIndex = 72,
			Parent = gui,
		}, { corner(14), make("UIStroke", { Thickness = 3, Color = GOLD, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		autoScale(holder)
		local pop = make("UIScale", { Scale = 0.6, Parent = holder })
		tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 32,
			TextColor3 = GOLD,
			Text = "🎰  HERO SHUFFLE  🎰",
			ZIndex = 73,
			Parent = holder,
		}, { textStroke(2) })
		local window = make("Frame", {
			Name = "Window",
			Position = UDim2.fromOffset(20, 44),
			Size = UDim2.new(1, -40, 0, CELL * 3),
			BackgroundColor3 = Color3.fromRGB(8, 8, 12),
			ClipsDescendants = true,
			ZIndex = 73,
			Parent = holder,
		}, { corner(8) })
		local strip = make("Frame", {
			Name = "Strip",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 74,
			Parent = window,
		})
		-- the heroes going by: the pool shuffled, three times round, ending on his
		local pool = type(opts.Pool) == "table" and opts.Pool or Config.QuirkOrder
		local seq = {}
		for _ = 1, 3 do
			local round = table.clone(pool)
			for i = #round, 2, -1 do
				local j = rng:NextInteger(1, i)
				round[i], round[j] = round[j], round[i]
			end
			for _, h in round do
				if Config.Quirks[h] then
					table.insert(seq, h)
				end
			end
		end
		table.insert(seq, hero)
		table.insert(seq, pool[1] or hero) -- (one under it, so the window's full)
		local cells = {}
		for i, h in seq do
			local hq = Config.Quirks[h]
			local cell = make("Frame", {
				Name = "Cell",
				Position = UDim2.fromOffset(0, (i - 1) * CELL),
				Size = UDim2.new(1, 0, 0, CELL),
				BackgroundTransparency = 1,
				ZIndex = 74,
				Parent = strip,
			})
			local b = make("Frame", {
				Name = "Badge",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 70, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = hq.Color,
				ZIndex = 75,
				Parent = cell,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(150, 150, 150), 90) })
			make("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 12,
				TextColor3 = WHITE,
				Text = initials(hq.DisplayName),
				ZIndex = 76,
				Parent = b,
			}, { textStroke(1) })
			make("TextLabel", {
				Name = "HeroName",
				Position = UDim2.fromOffset(110, 0),
				Size = UDim2.new(1, -120, 1, 0),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = WHITE,
				Text = string.upper(hq.DisplayName or h),
				ZIndex = 75,
				Parent = cell,
			}, { textStroke(1) })
			cells[i] = cell
		end
		-- the payline across the middle
		local line = make("Frame", {
			Name = "Payline",
			Position = UDim2.fromOffset(0, CELL),
			Size = UDim2.new(1, 0, 0, CELL),
			BackgroundTransparency = 1,
			ZIndex = 77,
			Parent = window,
		}, { make("UIStroke", { Thickness = 2, Color = GOLD, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		for _, y in { 0, 1 } do
			make("Frame", {
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.new(1, 0, 0, CELL),
				BackgroundColor3 = Color3.fromRGB(8, 8, 12),
				BorderSizePixel = 0,
				ZIndex = 77,
				Parent = window,
			}, { make("UIGradient", { Rotation = y == 0 and 90 or -90, Transparency = NumberSequence.new(0.1, 1) }) })
		end
		local result = make("TextLabel", {
			Name = "Result",
			Position = UDim2.new(0, 0, 1, -44),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 19,
			TextColor3 = q.Color:Lerp(WHITE, 0.3),
			TextTransparency = 1,
			Text = (opts.Back and "BACK TO " or "YOU'RE ") .. string.upper(q.DisplayName or hero) .. "!",
			ZIndex = 73,
			Parent = holder,
		}, { textStroke(1.5) })
		-- the roll: fast, then slowing onto his row (cubic ease out)
		local final = (#seq - 3) * CELL -- (his cell, #seq - 1, in the middle row: its top at CELL)
		local t0, lastCell = os.clock(), 0
		while holder.Parent do
			local a = math.clamp((os.clock() - t0) / spin, 0, 1)
			local y = final * (1 - (1 - a) ^ 3)
			strip.Position = UDim2.fromOffset(0, -y)
			local passing = math.floor(y / CELL + 0.5)
			if passing ~= lastCell then
				lastCell = passing
				if opts.OnTick then
					task.spawn(opts.OnTick)
				end
			end
			if a >= 1 then
				break
			end
			task.wait()
		end
		if not holder.Parent then
			return
		end
		-- (the shuffle ended while it rolled: the server deals nothing)
		if opts.Still and not opts.Still() then
			result.Text = "HERO SHUFFLE'S OVER"
			result.TextColor3 = DIM
			tween(result, 0.15, { TextTransparency = 0 })
			task.wait(0.8)
			if holder.Parent then
				holder:Destroy()
			end
			return
		end
		-- landed: the payline lights in his colour, his row jumps, the result
		line.BackgroundColor3 = q.Color
		line.BackgroundTransparency = 0.5
		tween(line, 0.6, { BackgroundTransparency = 0.85 })
		line.UIStroke.Color = q.Color:Lerp(WHITE, 0.3)
		local mine = cells[#seq - 1]
		if mine then
			local s = make("UIScale", { Scale = 1.25, Parent = mine })
			tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		tween(result, 0.15, { TextTransparency = 0 })
		if opts.OnLand then
			task.spawn(opts.OnLand)
		end
		task.wait(0.95)
		if holder.Parent then
			tween(pop, 0.25, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, d in holder:GetDescendants() do
				if d:IsA("TextLabel") then
					tween(d, 0.25, { TextTransparency = 1 })
				elseif d:IsA("Frame") then
					tween(d, 0.25, { BackgroundTransparency = 1 })
				end
			end
			tween(holder, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.27)
			holder:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- (round 87) THE DIRECTOR CAMERA on the screen (Config.Director; the camera
-- itself is in QuirkClient). Two screens of its own over everything (the
-- game's HUD is off while it runs):
--  THE FRAME (DirectorFrame): the letterbox - 2.39:1 bars top and bottom,
--   or a 9:16 frame for TikTok (dimmed outside while the overlay's up, black
--   when it isn't: crop the recording to it). It slides in and out.
--  THE OVERLAY (DirectorOverlay) - one key hides all of it (and the mouse),
--   so the frame is clean for recording: a viewfinder's corners and centre;
--   the slate (top left: the shot - its chips click -, the target, the
--   speed, zoom, roll, time and how it moves; what's on: focus, grade,
--   shake, frame, grid, body, cutscenes; a running time code, an exit); the
--   keys for the shot you're in (bottom left: a controller's on a
--   controller, buttons on a phone); slow motion or the freeze frame big at
--   the top right; the dolly's keys and its progress (bottom middle); the
--   rule-of-thirds grid; a marker round the target; a word on each switch;
--   the shutter's flash. In the 9:16 frame the slate and the keys stand
--   outside it, where they're not in the shot.
---------------------------------------------------------------------------
do
	local HD = { cb = {}, frameMode = "Off", overlay = true, grid = false, toastToken = 0, keysText = "" }
	HUD.Director = HD
	local WHITE = Color3.new(1, 1, 1)
	local ACC = Color3.fromRGB(255, 196, 64)
	local REC = Color3.fromRGB(255, 64, 64)
	local DIM = Color3.fromRGB(150, 156, 180)
	local TXT = Color3.fromRGB(226, 230, 242)
	local CHIP = Color3.fromRGB(38, 40, 57)
	local SLOWC = Color3.fromRGB(110, 190, 255)
	local MODES = { "FREE", "ORBIT", "TRACK", "FOLLOW", "DOLLY" }
	local PILLS = { "FOCUS", "GRADE", "SHAKE", "FRAME", "GRID", "BODY", "CUTS" }

	local function label(props, children)
		props.BackgroundTransparency = 1
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		props.TextColor3 = props.TextColor3 or TXT
		return make("TextLabel", props, children)
	end
	-- a thin line (the viewfinder, the grid, the marker)
	local function line(parent, name, transparency, color)
		return make("Frame", {
			Name = name,
			BackgroundColor3 = color or WHITE,
			BackgroundTransparency = transparency or 0.3,
			BorderSizePixel = 0,
			Parent = parent,
		})
	end
	-- the part of the screen that's in the shot: x, y, w, h
	function HD.frameRect(mode, W, H)
		local FR = (Config and Config.Director or {}).Frame or {}
		if mode == "Scope" then
			local h = math.min(H, W / (FR.Scope or 2.39))
			return 0, (H - h) / 2, W, h
		elseif mode == "Vertical" then
			local w = math.min(W, H * (FR.Vertical or 9 / 16))
			return (W - w) / 2, 0, w, H
		end
		return 0, 0, W, H
	end
	function HD.size()
		local s = HD.frame and HD.frame.AbsoluteSize
		if s and s.X > 0 and s.Y > 0 then
			return s.X, s.Y
		end
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		return vp and vp.X > 0 and vp.X or 1280, vp and vp.Y > 0 and vp.Y or 720
	end

	-- a piece that grows with the screen (its own scale: layout sets it)
	function HD.scaled(frame)
		local sc = make("UIScale", { Name = "DirectorScale", Parent = frame })
		table.insert(HD.scales, sc)
		return sc
	end

	function HD.build()
		local parent = gui.Parent
		HD.scales = {}
		HD.frame = make("ScreenGui", { Name = "DirectorFrame", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 57, Parent = parent })
		HD.bars = {}
		for _, name in { "Top", "Bottom", "Left", "Right" } do
			HD.bars[name] = make("Frame", {
				Name = name,
				Size = UDim2.fromOffset(0, 0),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Parent = HD.frame,
			})
		end
		HD.bars.Bottom.AnchorPoint = Vector2.new(0, 1)
		HD.bars.Bottom.Position = UDim2.fromScale(0, 1)
		HD.bars.Right.AnchorPoint = Vector2.new(1, 0)
		HD.bars.Right.Position = UDim2.fromScale(1, 0)
		-- (round 87 review) a phone has no H: with the overlay hidden for
		-- the recording, a tap anywhere on the screen brings it back (this
		-- invisible button is all there is - nothing shows in the shot)
		HD.reveal = make("TextButton", {
			Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Font = UI_FONT, TextSize = 1, Text = "",
			ZIndex = 5, Visible = false, Parent = HD.frame,
		})
		HD.reveal.Activated:Connect(function()
			if HD.cb.Reveal then
				HD.cb.Reveal()
			end
		end)

		local ov = make("ScreenGui", { Name = "DirectorOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 58, Parent = parent })
		HD.gui = ov
		-- the shutter's flash
		HD.flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = ov })
		-- the viewfinder: four corners, the centre
		HD.corners = {}
		for i = 1, 4 do
			HD.corners[i] = { h = line(ov, "CornerH" .. i, 0.25), v = line(ov, "CornerV" .. i, 0.25) }
		end
		HD.cross = { h = line(ov, "CrossH", 0.55), v = line(ov, "CrossV", 0.55) }
		-- the rule of thirds
		HD.gridLines = {}
		for i = 1, 4 do
			HD.gridLines[i] = line(ov, "Third" .. i, 0.55)
			HD.gridLines[i].Visible = false
		end
		-- the marker round the target
		HD.marker = make("Frame", { Name = "Marker", BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = ov })
		for i = 1, 4 do
			local sx, sy = (i == 1 or i == 3) and 0 or 1, (i <= 2) and 0 or 1
			local h = line(HD.marker, "MarkH" .. i, 0, ACC)
			h.AnchorPoint = Vector2.new(sx, sy)
			h.Position = UDim2.fromScale(sx, sy)
			h.Size = UDim2.new(0.28, 0, 0, 2)
			local v = line(HD.marker, "MarkV" .. i, 0, ACC)
			v.AnchorPoint = Vector2.new(sx, sy)
			v.Position = UDim2.fromScale(sx, sy)
			v.Size = UDim2.new(0, 2, 0.28, 0)
		end
		HD.markerName = label({
			Name = "Name", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(200, 16),
			Font = HEAD_FONT, TextSize = 12, TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = HD.marker,
		}, { textStroke(1) })

		-- THE SLATE (top left)
		local slate = make("Frame", {
			Name = "Slate", Size = UDim2.fromOffset(300, 152), BackgroundColor3 = GLASS.Color, BackgroundTransparency = 0.18, Parent = ov,
		}, { corner(10), edge(0.82) })
		HD.scaled(slate)
		HD.slate = slate
		HD.rec = make("Frame", { Name = "Rec", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = REC, Parent = slate }, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		label({ Name = "Title", Position = UDim2.fromOffset(26, 3), Size = UDim2.fromOffset(150, 24), Font = COMIC_FONT, TextSize = 24, TextColor3 = WHITE, Text = "DIRECTOR", Parent = slate }, { textStroke(1) })
		HD.tc = label({
			Name = "Timecode", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 9), Size = UDim2.fromOffset(90, 14),
			Font = UI_FONT, TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Text = "00:00.0", Parent = slate,
		})
		HD.exit = make("TextButton", {
			Name = "Exit", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 6), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = CHIP, AutoButtonColor = true, Font = UI_FONT, TextSize = 12, TextColor3 = WHITE, Text = "X", Parent = slate,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		HD.exit.Activated:Connect(function()
			if HD.cb.Exit then
				HD.cb.Exit()
			end
		end)
		HD.chips = {}
		for i, name in MODES do
			local chip = make("TextButton", {
				Name = "Chip_" .. name, Position = UDim2.fromOffset(10 + (i - 1) * 57, 33), Size = UDim2.fromOffset(53, 21),
				BackgroundColor3 = CHIP, AutoButtonColor = false, Font = HEAD_FONT, TextSize = 10, TextColor3 = TXT, Text = name, Parent = slate,
			}, { corner(5) })
			chip.Activated:Connect(function()
				if HD.cb.Mode then
					HD.cb.Mode(name)
				end
			end)
			HD.chips[name] = chip
		end
		label({ Name = "TargetLabel", Position = UDim2.fromOffset(12, 63), Size = UDim2.fromOffset(52, 12), Font = UI_FONT, TextSize = 9, TextColor3 = DIM, Text = "TARGET", Parent = slate })
		HD.target = label({ Name = "Target", Position = UDim2.fromOffset(62, 59), Size = UDim2.fromOffset(226, 18), Font = HEAD_FONT, TextSize = 13, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = slate })
		HD.stats = {}
		for i, key in { "Speed", "Fov", "Roll", "Time", "Move" } do
			local x = 12 + (i - 1) * 57
			HD.stats[key] = {
				name = label({ Name = key .. "Label", Position = UDim2.fromOffset(x, 84), Size = UDim2.fromOffset(56, 11), Font = UI_FONT, TextSize = 9, TextColor3 = DIM, Text = "", Parent = slate }),
				value = label({ Name = key, Position = UDim2.fromOffset(x, 95), Size = UDim2.fromOffset(54, 18), Font = HEAD_FONT, TextScaled = true, TextColor3 = WHITE, Text = "", Parent = slate },
					{ make("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }) }),
			}
		end
		HD.pills = {}
		for i, name in PILLS do
			HD.pills[name] = make("TextLabel", {
				Name = "Pill_" .. name, Position = UDim2.fromOffset(10 + (i - 1) * 41.5, 123), Size = UDim2.fromOffset(39, 17),
				BackgroundColor3 = CHIP, Font = HEAD_FONT, TextScaled = true, TextColor3 = DIM, Text = name, Parent = slate,
			}, { corner(4), make("UITextSizeConstraint", { MaxTextSize = 9, MinTextSize = 6 }), make("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }) })
		end

		-- THE KEYS (bottom left)
		HD.keys = make("Frame", {
			Name = "Keys", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(300, 60), BackgroundColor3 = GLASS.Color, BackgroundTransparency = 0.25, Parent = ov,
		}, { corner(10), edge(0.85) })
		HD.scaled(HD.keys)
		HD.keysTitle = label({ Name = "Title", Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(276, 13), Font = HEAD_FONT, TextSize = 10, TextColor3 = ACC, Text = "KEYS", Parent = HD.keys })
		HD.keyLines = {}

		-- a phone: buttons for what a thumb can do
		HD.touch = make("Frame", { Name = "Touch", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(330, 34), BackgroundTransparency = 1, Visible = false, Parent = ov })
		HD.scaled(HD.touch)
		-- (round 87 review: each as wide as its word - NEXT TARGET ran out of
		-- its button on a phone; HIDE takes the overlay off for the recording;
		-- layout puts them in rows that fit)
		HD.touchButtons = {}
		for i, spec in { { "Next", "NEXT TARGET", 100 }, { "Slow", "SLOW-MO", 80 }, { "Freeze", "FREEZE", 74 }, { "Frame", "FRAME", 68 }, { "Hide", "HIDE", 62 } } do
			local b = make("TextButton", {
				Name = spec[1], Position = UDim2.fromOffset((i - 1) * 84, 0), Size = UDim2.fromOffset(spec[3], 32), BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = 0.15, Font = HEAD_FONT, TextSize = 11, TextColor3 = WHITE, Text = spec[2], Parent = HD.touch,
			}, { corner(8), edge(0.7) })
			table.insert(HD.touchButtons, b)
			b.Activated:Connect(function()
				local fn = HD.cb[spec[1]]
				if fn then
					fn()
				end
			end)
		end

		-- slow motion / the freeze frame (top right)
		HD.badge = make("Frame", {
			Name = "Time", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(176, 62), BackgroundColor3 = GLASS.Color, BackgroundTransparency = 0.2, Visible = false, Parent = ov,
		}, { corner(10), edge(0.8) })
		HD.scaled(HD.badge)
		HD.badgeLabel = label({ Name = "Label", Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(152, 12), Font = HEAD_FONT, TextSize = 10, TextColor3 = DIM, Text = "SLOW MOTION", Parent = HD.badge })
		HD.badgeValue = label({ Name = "Value", Position = UDim2.fromOffset(12, 18), Size = UDim2.fromOffset(152, 38), Font = COMIC_FONT, TextSize = 38, TextColor3 = SLOWC, Text = "", Parent = HD.badge }, { textStroke(1.5) })

		-- the dolly (bottom middle)
		HD.dolly = make("Frame", {
			Name = "Dolly", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(380, 50), BackgroundColor3 = GLASS.Color, BackgroundTransparency = 0.2, Visible = false, Parent = ov,
		}, { corner(10), edge(0.82) })
		HD.scaled(HD.dolly)
		label({ Name = "Title", Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(60, 14), Font = HEAD_FONT, TextSize = 11, TextColor3 = ACC, Text = "DOLLY", Parent = HD.dolly })
		-- (round 87 review: sized by the bar, which layout narrows to the
		-- margin beside a phone's 9:16 frame - it used to stick into the shot)
		HD.dollyInfo = label({ Name = "Info", Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -78, 0, 14), Font = UI_FONT, TextSize = 12, TextScaled = true, TextColor3 = TXT, Text = "", Parent = HD.dolly },
			{ make("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }) })
		HD.dollyTrack = make("Frame", { Name = "Track", Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = CHIP, BorderSizePixel = 0, Parent = HD.dolly }, { corner(3) })
		HD.dollyFill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACC, BorderSizePixel = 0, Parent = HD.dollyTrack }, { corner(3) })
		HD.dollyTicks = {}

		-- a word on each switch
		HD.toast = label({
			Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 40), Font = COMIC_FONT, TextSize = 32,
			TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Text = "", Parent = ov,
		}, { textStroke(2) })
		HD.toastStroke = HD.toast:FindFirstChildOfClass("UIStroke")
	end

	-- where everything goes, for the screen and the frame it's in
	function HD.layout()
		if not HD.gui then
			return
		end
		local W, H = HD.size()
		local fx, fy, fw, fh = HD.frameRect(HD.frameMode, W, H)
		HD.rect = { fx, fy, fw, fh }
		-- the viewfinder, inset from the frame
		local inset, arm = 8, 30
		for i, c in HD.corners do
			local right, bottom = i == 2 or i == 4, i >= 3
			local x = right and (fx + fw - inset) or (fx + inset)
			local y = bottom and (fy + fh - inset) or (fy + inset)
			c.h.AnchorPoint = Vector2.new(right and 1 or 0, bottom and 1 or 0)
			c.h.Position = UDim2.fromOffset(x, y)
			c.h.Size = UDim2.fromOffset(arm, 2)
			c.v.AnchorPoint = c.h.AnchorPoint
			c.v.Position = UDim2.fromOffset(x, y)
			c.v.Size = UDim2.fromOffset(2, arm)
		end
		HD.cross.h.AnchorPoint, HD.cross.v.AnchorPoint = Vector2.new(0.5, 0.5), Vector2.new(0.5, 0.5)
		HD.cross.h.Position = UDim2.fromOffset(fx + fw / 2, fy + fh / 2)
		HD.cross.v.Position = HD.cross.h.Position
		HD.cross.h.Size, HD.cross.v.Size = UDim2.fromOffset(14, 1), UDim2.fromOffset(1, 14)
		for i, g in HD.gridLines do
			if i <= 2 then
				g.Position = UDim2.fromOffset(fx + fw * i / 3, fy)
				g.Size = UDim2.fromOffset(1, fh)
			else
				g.Position = UDim2.fromOffset(fx, fy + fh * (i - 2) / 3)
				g.Size = UDim2.fromOffset(fw, 1)
			end
			g.Visible = HD.grid
		end
		-- the slate and the keys: in the frame's corners - or, in the 9:16
		-- frame, beside it (where there's room)
		local side = HD.frameMode == "Vertical" and fx >= 160
		local lx = side and 18 or fx + 18
		local top = side and 18 or fy + 18
		local bottom = side and (H - 18) or (fy + fh - 18)
		HD.slate.Position = UDim2.fromOffset(lx, top)
		HD.keys.Position = UDim2.fromOffset(lx, bottom)
		HD.touch.Position = UDim2.fromOffset(lx, bottom)
		HD.badge.Position = UDim2.fromOffset(side and (W - 18) or (fx + fw - 18), top)
		-- (its own size on the screen: a phone's still readable)
		local k = math.clamp(H / 720, 0.8, 1.4)
		for _, sc in HD.scales do
			sc.Scale = k
		end
		-- (the dolly's bar under the frame; beside it in the 9:16, right; on a
		-- narrow screen in the right corner, clear of the keys)
		local right = side or fw < 1000
		HD.dolly.Size = UDim2.fromOffset(side and math.clamp((W - fx - fw - 36) / k, 220, 380) or 380, 50)
		HD.dolly.AnchorPoint = right and Vector2.new(1, 1) or Vector2.new(0.5, 1)
		HD.dolly.Position = side and UDim2.fromOffset(W - 18, H - 18)
			or (right and UDim2.fromOffset(fx + fw - 18, bottom) or UDim2.fromOffset(fx + fw / 2, bottom))
		HD.toast.Position = UDim2.fromOffset(fx + fw / 2, fy + fh * 0.82) -- (under a centred subject)
		-- (round 87 review) a phone's buttons in rows that fit where they
		-- stand (beside the 9:16 frame there's only its margin)
		local avail = math.max(((side and fx or fw) - 36) / k, 120)
		local x, y, widest = 0, 0, 0
		for _, b in HD.touchButtons or {} do
			local w = b.Size.X.Offset
			if x > 0 and x + w > avail then
				x, y = 0, y + 38
			end
			b.Position = UDim2.fromOffset(x, y)
			x += w + 6
			widest = math.max(widest, x - 6)
		end
		HD.touch.Size = UDim2.fromOffset(widest, y + 32)
		-- (with the overlay hidden on a phone, a tap anywhere brings it back)
		if HD.reveal then
			HD.reveal.Visible = not HD.overlay and HD.input == "Touch"
		end
		-- (round 87 review) the screen changed size (a window resized, full
		-- screen, a phone turned): the letterbox's bars follow at once
		if HD.frame and HD.barsFor and (HD.barsFor.X ~= W or HD.barsFor.Y ~= H) then
			HD.setBars(0)
		end
	end

	-- on: build it (cb: what its buttons do - Mode(name), Exit, Next, Slow,
	-- Freeze, Frame); off: every piece of it gone
	function HUD.DirectorShow(on, cb)
		if on then
			HD.cb = cb or HD.cb
			if not HD.gui then
				HD.build()
			end
			HD.frameMode, HD.overlay, HD.grid = HD.frameMode or "Off", true, HD.grid == true
			HD.gui.Enabled = true
			HD.layout()
			return
		end
		for _, key in { "frame", "gui" } do
			if HD[key] then
				HD[key]:Destroy()
				HD[key] = nil
			end
		end
		HD.cb = {}
		table.clear(HD.keyLines)
		table.clear(HD.dollyTicks)
		HD.keysText = ""
		HD.toastToken += 1
		HD.barsFor, HD.reveal = nil, nil
	end

	-- the letterbox: Off, Scope (2.39:1), Vertical (9:16) - sliding in
	function HUD.DirectorFrame(mode)
		HD.frameMode = mode or "Off"
		if not HD.frame then
			return
		end
		HD.setBars(((Config and Config.Director or {}).Frame or {}).Slide or 0.35)
		HD.layout()
	end
	-- the bars for the frame as the screen is now, over t s (0: at once - a
	-- new tween on them takes over from one still sliding)
	function HD.setBars(t)
		local FR = (Config and Config.Director or {}).Frame or {}
		local W, H = HD.size()
		local fx, fy, fw, fh = HD.frameRect(HD.frameMode, W, H)
		HD.barsFor = Vector2.new(W, H)
		local dim = (HD.overlay and HD.frameMode == "Vertical") and (FR.Dim or 0.45) or 0
		tween(HD.bars.Top, t, { Size = UDim2.fromOffset(W, fy) }, Enum.EasingStyle.Quint)
		tween(HD.bars.Bottom, t, { Size = UDim2.fromOffset(W, H - fy - fh) }, Enum.EasingStyle.Quint)
		tween(HD.bars.Left, t, { Size = UDim2.fromOffset(fx, H), BackgroundTransparency = dim }, Enum.EasingStyle.Quint)
		tween(HD.bars.Right, t, { Size = UDim2.fromOffset(W - fx - fw, H), BackgroundTransparency = dim }, Enum.EasingStyle.Quint)
	end

	-- the overlay up / hidden (hidden: only the frame is left on the screen)
	function HUD.DirectorOverlay(on)
		HD.overlay = on == true
		if HD.gui then
			HD.gui.Enabled = HD.overlay
		end
		if HD.frame then
			HUD.DirectorFrame(HD.frameMode) -- (the 9:16 frame's outside goes black for the recording)
		end
	end

	function HUD.DirectorGrid(on)
		HD.grid = on == true
		HD.layout()
	end

	-- the target marker: at screen point p (nil: none), size px, its name
	function HUD.DirectorMarker(p, size, name)
		if not HD.marker then
			return
		end
		HD.marker.Visible = p ~= nil
		if p then
			HD.marker.Position = UDim2.fromOffset(p.X, p.Y)
			HD.marker.Size = UDim2.fromOffset(size, size * 1.4) -- (a body's about 4 studs wide, 5.5 tall)
			HD.markerName.Text = name or ""
		end
	end

	-- a word on a switch: up, held, gone
	function HUD.DirectorToast(text, color)
		if not HD.toast then
			return
		end
		HD.toastToken += 1
		local token = HD.toastToken
		HD.toast.Text = text
		HD.toast.TextColor3 = color or WHITE
		HD.toast.TextTransparency = 0
		if HD.toastStroke then
			HD.toastStroke.Transparency = 0
		end
		task.delay(0.9, function()
			if HD.toastToken == token and HD.toast then
				tween(HD.toast, 0.35, { TextTransparency = 1 })
				if HD.toastStroke then
					tween(HD.toastStroke, 0.35, { Transparency = 1 })
				end
			end
		end)
	end

	-- the shutter's flash (the freeze frame)
	function HUD.DirectorFlash()
		if HD.flash then
			HD.flash.BackgroundTransparency = 0.3
			tween(HD.flash, 0.3, { BackgroundTransparency = 1 })
		end
	end

	-- the keys card: its title and lines (rich text: <b>keys</b>)
	function HD.setKeys(title, lines)
		local text = title .. "\n" .. table.concat(lines, "\n")
		if text == HD.keysText then
			return
		end
		HD.keysText = text
		HD.keysTitle.Text = title
		for i, s in lines do
			local l = HD.keyLines[i]
			if not l then
				l = label({ Name = "Line" .. i, Position = UDim2.fromOffset(12, 23 + (i - 1) * 15), Size = UDim2.fromOffset(280, 15), Font = Enum.Font.GothamMedium, TextSize = 11, RichText = true, Text = "", Parent = HD.keys })
				HD.keyLines[i] = l
			end
			l.Text = s
			l.Visible = true
		end
		for i = #lines + 1, #HD.keyLines do
			HD.keyLines[i].Visible = false
		end
		HD.keys.Size = UDim2.fromOffset(300, 30 + #lines * 15)
	end

	-- st: { mode, target, speedName, speed, fov, roll, time, timeName, move,
	--   pills = { [name] = text or false }, tc (s), input, keysTitle, keys = { lines },
	--   slow = nil | "0.25x" | "FREEZE", dolly = nil | { info, progress, marks = { 0..1 } } }
	function HUD.DirectorUpdate(st)
		if not HD.gui then
			return
		end
		for name, chip in HD.chips do
			local on = name == st.mode
			chip.BackgroundColor3 = on and ACC or CHIP
			chip.TextColor3 = on and Color3.new(0, 0, 0) or TXT
		end
		HD.target.Text = st.target or ""
		local stats = HD.stats
		stats.Speed.name.Text, stats.Speed.value.Text = st.speedName or "SPEED", st.speed or ""
		stats.Fov.name.Text, stats.Fov.value.Text = "ZOOM", st.fov or ""
		stats.Roll.name.Text, stats.Roll.value.Text = "ROLL", st.roll or ""
		stats.Time.name.Text, stats.Time.value.Text = "TIME", st.time or ""
		stats.Time.value.TextColor3 = (st.slow and st.slow ~= "") and SLOWC or WHITE
		stats.Move.name.Text, stats.Move.value.Text = "MOVES", st.move or ""
		for name, pill in HD.pills do
			local v = st.pills and st.pills[name]
			pill.Text = type(v) == "string" and v or name
			pill.BackgroundColor3 = v and ACC or CHIP
			pill.TextColor3 = v and Color3.new(0, 0, 0) or DIM
		end
		HD.tc.Text = string.format("%02d:%04.1f", math.floor((st.tc or 0) / 60), (st.tc or 0) % 60)
		HD.rec.BackgroundTransparency = (math.floor((st.tc or 0) * 2) % 2 == 0) and 0 or 0.6
		local touch = st.input == "Touch"
		HD.input = st.input
		HD.keys.Visible = not touch
		HD.touch.Visible = touch
		if not touch then
			HD.setKeys(st.keysTitle or "KEYS", st.keys or {})
		end
		HD.badge.Visible = st.slow ~= nil
		if st.slow then
			local frozen = st.slow == "FREEZE"
			HD.badgeLabel.Text = frozen and "FREEZE FRAME" or "SLOW MOTION"
			HD.badgeValue.Text = st.slow
			HD.badgeValue.TextColor3 = frozen and WHITE or SLOWC
		end
		local d = st.dolly
		HD.dolly.Visible = d ~= nil
		if d then
			HD.dollyInfo.Text = d.info or ""
			HD.dollyFill.Size = UDim2.fromScale(math.clamp(d.progress or 0, 0, 1), 1)
			for i, m in d.marks or {} do
				local tick = HD.dollyTicks[i]
				if not tick then
					tick = make("Frame", { Name = "Key" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = HD.dollyTrack })
					HD.dollyTicks[i] = tick
				end
				tick.Position = UDim2.fromScale(m, 0.5)
				tick.Visible = true
			end
			for i = #(d.marks or {}) + 1, #HD.dollyTicks do
				HD.dollyTicks[i].Visible = false
			end
		end
		HD.layout()
	end
end

---------------------------------------------------------------------------
-- (round 87) POSSESS on the screen (Config.Possess; the possession itself
-- is QuirkClient's DevFly.PS and the server's Kit.PS). While a dev's in a
-- body: a chip over the health bar - POSSESSING <its name>, K to leave -
-- and the body's own keys in place of the hero's move boxes, each with its
-- cooldown (the body's PossessCd_<act>: when it's ready, server time); the
-- health bar is the body's (HUD.BindHumanoid). On a phone the round buttons
-- say what they do in the body. And the test menu's POSSESS panel: every
-- body there is to take (the dummies, the raid's Nomu), how far off, who's
-- in it - TAKE one, or LEAVE the one you're in.
---------------------------------------------------------------------------
do
	local PH = { boxes = {}, rows = {}, cb = {}, cdLen = {}, cdAt = {} }
	HUD.PossessHud = PH
	local PW = 360
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local INK = Color3.fromRGB(20, 12, 34)
	local DIM = Color3.fromRGB(160, 154, 186)
	-- (read when used: Config arrives with HUD.Init)
	local function violet()
		return (Config and Config.Possess and Config.Possess.Color) or Color3.fromRGB(150, 70, 255)
	end
	local function light(c)
		return c:Lerp(WHITE, 0.55)
	end
	function PH.width(text, size, font)
		local ok, w = pcall(function()
			return HUD.Roster.textWidth(text, size, font)
		end)
		if ok and type(w) == "number" and w > 0 then
			return w
		end
		-- (nothing to measure with: a generous guess - Gotham Black's capitals
		-- run ~0.74 of its size)
		return #text * size * (font == HEAD_FONT and 0.76 or 0.64)
	end

	-- the chip over the health bar (it rides with the bar, a phone's too)
	function PH.chip()
		if PH.chipFrame and PH.chipFrame.Parent then
			return PH.chipFrame
		end
		if not vitals then
			return nil
		end
		local v = violet()
		local chip = make("Frame", {
			Name = "PossessChip",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.fromOffset(PW, 26),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.1,
			Visible = false,
			ZIndex = 5,
			Parent = vitals,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Name = "Edge", Thickness = 1.5, Color = v, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 170)), Rotation = 90 }),
		})
		-- (a heartbeat: the soul in the body)
		make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = chip,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 1.5, Color = v, Transparency = 0.2 }) })
		make("Frame", {
			Name = "Pulse",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = light(v),
			ZIndex = 7,
			Parent = chip,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		make("TextLabel", {
			Name = "Kicker",
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(0, 84, 1, 0),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = light(v),
			Text = "POSSESSING",
			ZIndex = 6,
			Parent = chip,
		})
		make("TextLabel", {
			Name = "Body",
			Position = UDim2.fromOffset(106, 0),
			Size = UDim2.new(1, -196, 1, 0),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 6,
			Parent = chip,
		}, { textStroke(1) })
		make("TextLabel", {
			Name = "Key",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -54, 0.5, 0),
			Size = UDim2.fromOffset(20, 18),
			BackgroundColor3 = WHITE,
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = BLACK,
			Text = "K",
			ZIndex = 6,
			Parent = chip,
		}, { corner(4) })
		make("TextLabel", {
			Name = "Leave",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(38, 18),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(214, 206, 232),
			Text = "LEAVE",
			ZIndex = 6,
			Parent = chip,
		})
		PH.chipFrame = chip
		return chip
	end

	-- the body's keys, where the hero's move boxes were
	function PH.dock()
		if PH.dockFrame and PH.dockFrame.Parent then
			return PH.dockFrame
		end
		local dock = vitals and vitals.Parent
		if not dock then
			return nil
		end
		local f = make("Frame", {
			Name = "PossessMoves",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -26),
			Size = UDim2.fromOffset(560, 70),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = dock,
		}, {
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i = 1, 4 do
			local box = make("Frame", {
				Name = "Move" .. i,
				Size = UDim2.fromOffset(104, 70),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				ClipsDescendants = true,
				LayoutOrder = i,
				Parent = f,
			}, { edge(), corner(3) })
			local key = make("TextLabel", {
				Name = "Key",
				Position = UDim2.fromOffset(6, 5),
				Size = UDim2.fromOffset(70, 16),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = WHITE,
				TextTransparency = 0.3,
				Text = "",
				ZIndex = 3,
				Parent = box,
			})
			local name = make("TextLabel", {
				Name = "MoveName",
				Position = UDim2.new(0, 5, 1, -40),
				Size = UDim2.new(1, -10, 0, 32),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextScaled = true,
				TextColor3 = WHITE,
				Text = "",
				ZIndex = 2,
				Parent = box,
			}, { make("UITextSizeConstraint", { MaxTextSize = 15 }) })
			local strip = make("Frame", {
				Name = "Accent",
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = violet(),
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = box,
			})
			local cover = make("Frame", {
				Name = "Cover",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0),
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = box,
			})
			local cd = make("TextLabel", {
				Name = "Cd",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 20,
				TextColor3 = WHITE,
				Text = "",
				ZIndex = 5,
				Parent = box,
			}, { textStroke(1) })
			PH.boxes[i] = { Frame = box, Key = key, Name = name, Cover = cover, Cd = cd, Accent = strip }
		end
		PH.dockFrame = f
		return f
	end

	-- every frame while it's up: the heartbeat, the cooldowns, the guard
	function PH.tick()
		local info = PH.info
		local chip = PH.chipFrame
		if not info or not chip then
			return
		end
		for _, bar2 in PH.heroBars or {} do
			if bar2 and bar2.Visible then
				bar2.Visible = false
			end
		end
		local now = os.clock()
		local k = (math.sin(now * 5.2) + 1) / 2
		local ring = chip:FindFirstChild("Ring")
		if ring then
			local s = 8 + 10 * ((now * 1.3) % 1)
			ring.Size = UDim2.fromOffset(s, s)
			local st = ring:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 0.15 + 0.85 * ((now * 1.3) % 1)
			end
		end
		local edgeStroke = chip:FindFirstChild("Edge")
		if edgeStroke then
			edgeStroke.Transparency = 0.1 + 0.35 * k
		end
		local body = info.Body
		local serverNow = workspace:GetServerTimeNow()
		local busy = body and body:GetAttribute("PossessBusy") == true
		for i, box in PH.boxes do
			local m = info.Moves and info.Moves[i]
			if m and box.Frame.Visible then
				local ready = body and tonumber(body:GetAttribute("PossessCd_" .. (m.Act or ""))) or nil
				local left = ready and ready - serverNow or 0
				-- (how long it was, from when this cooldown was first seen)
				if ready and PH.cdAt[m.Act] ~= ready then
					PH.cdAt[m.Act] = ready
					PH.cdLen[m.Act] = math.max(left, 0.05)
				end
				if left > 0.02 then
					box.Cover.Size = UDim2.fromScale(1, math.clamp(left / (PH.cdLen[m.Act] or left), 0, 1))
					box.Cd.Text = left >= 1 and string.format("%d", math.ceil(left)) or string.format("%.1f", left)
				else
					box.Cover.Size = UDim2.fromScale(1, busy and 1 or 0)
					box.Cd.Text = ""
				end
				local guard = m.Act == "Block" and body and body:GetAttribute("Blocking") == true
				box.Accent.Size = UDim2.new(1, 0, 0, guard and 6 or 3)
				box.Accent.BackgroundColor3 = guard and Color3.fromRGB(120, 210, 255) or violet()
			end
		end
	end

	-- info: { Name, Body (the model), Moves (Config.Possess.Moves[kind]),
	-- Mode ("Keyboard" / "Gamepad" / "Touch") } - nil: back to the hero's
	function HUD.Possess(info)
		PH.info = info
		local chip, dockF = PH.chip(), PH.dock()
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		local bar = vitals and vitals.Parent and vitals.Parent:FindFirstChild("Abilities")
		if not info then
			if chip then
				chip.Visible = false
			end
			if dockF then
				dockF.Visible = false
			end
			if bar then
				bar.Visible = not touch
			end
			-- (the name row and the phone's button names as they were)
			for s, text in PH.savedSlots or {} do
				s.Name.Text = text
			end
			PH.savedSlots = nil
			if PH.savedName and HUD.NameLabel then
				HUD.NameLabel.Text = PH.savedName
			end
			PH.savedName = nil
			for bar2, shown in PH.savedBars or {} do
				bar2.Visible = shown
			end
			PH.savedBars = nil
			PH.heroBars = nil
			if PH.conn then
				PH.conn:Disconnect()
				PH.conn = nil
			end
			table.clear(PH.cdLen)
			table.clear(PH.cdAt)
			return
		end
		if not chip or not dockF then
			return
		end
		local mode = info.Mode or "Keyboard"
		local name = string.upper(tostring(info.Name or ""))
		chip.Body.Text = name
		local keyed = mode == "Keyboard"
		chip.Key.Visible = keyed
		chip.Leave.Text = keyed and "LEAVE" or "TEST MENU › LEAVE"
		chip.Leave.Size = UDim2.fromOffset(keyed and 38 or 112, 18)
		-- (as wide as its words need: a long name, the pad's longer hint)
		-- (the name starts where POSSESSING ends, measured: Gotham Black runs wide)
		local kick = math.ceil(PH.width(chip.Kicker.Text, 11, HEAD_FONT)) + 10
		chip.Kicker.Size = UDim2.new(0, kick, 1, 0)
		chip.Body.Position = UDim2.fromOffset(28 + kick, 0)
		local w = 28 + kick + PH.width(name, 14, HEAD_FONT) + 14 + (keyed and 92 or 124)
		chip.Size = UDim2.fromOffset(math.clamp(math.ceil(w), 280, 520), 26)
		chip.Body.Size = UDim2.new(1, -(28 + kick + (keyed and 82 or 128)), 1, 0)
		chip.Visible = true
		local bySlot = {}
		for i, box in PH.boxes do
			local m = info.Moves and info.Moves[i]
			box.Frame.Visible = m ~= nil
			if m then
				box.Key.Text = (mode == "Gamepad" and m.Pad) or (mode == "Touch" and m.Touch) or m.Key or ""
				box.Name.Text = m.Name or ""
				if m.Slot then
					bySlot[m.Slot] = m.Name
				end
			end
		end
		dockF.Visible = not touch
		if bar then
			bar.Visible = false
		end
		-- (a phone's round buttons wear the move boxes: they say what they do
		-- in the body now; all put back as they were after)
		PH.savedSlots = PH.savedSlots or {}
		for i, slotName in { "Ability1", "Ability2", "Ability3", "Special", "Dash", "Extra" } do
			local s = slots[i]
			if s and s.Name then
				if PH.savedSlots[s] == nil then
					PH.savedSlots[s] = s.Name.Text
				end
				s.Name.Text = bySlot[slotName] or "—"
			end
		end
		-- (a body with no guard - the raid's Nomu - shows neither the guard
		-- nor the ragdoll cancel's meter: they'd be his parked body's)
		PH.savedBars = PH.savedBars or {}
		for _, bar2 in { guardBar, HUD.Evasive and HUD.Evasive.Bar } do
			if bar2 then
				if PH.savedBars[bar2] == nil then
					PH.savedBars[bar2] = bar2.Visible
				end
				bar2.Visible = info.Guard ~= false and PH.savedBars[bar2]
			end
		end
		-- (round 87, in Studio) nor the hero's own meters - the ult, Bakugo's
		-- sweat, Endeavor's heat, Hawks' feathers: they're his parked body's
		-- (PH.tick keeps them down: their setters show them on every update)
		PH.heroBars = { ultBar, HUD.Sweat and HUD.Sweat.Bar, HUD.Heat and HUD.Heat.Bar, HUD.Feathers and HUD.Feathers.Bar }
		for _, bar2 in PH.heroBars do
			if bar2 then
				if PH.savedBars[bar2] == nil then
					PH.savedBars[bar2] = bar2.Visible
				end
				bar2.Visible = false
			end
		end
		-- (the key line along the bottom: the body's keys - HUD.SetInputMode
		-- puts the hero's back)
		if hintLabel then
			local bits = {}
			for _, m in info.Moves or {} do
				local word = string.upper(string.sub(m.Name or "", 1, 1)) .. string.lower(string.sub(m.Name or "", 2))
				table.insert(bits, (m.Key == "M1" and "CLICK" or m.Key or "") .. " " .. word)
			end
			if info.Run then
				table.insert(bits, "CTRL Run")
			end
			table.insert(bits, "K Leave") -- ((round 92) no "T Lock-on": gone)
			hintLabel.Text = table.concat(bits, " · ")
		end
		-- (the name over the health bar: the body's - it's its health)
		if HUD.NameLabel then
			if PH.savedName == nil then
				PH.savedName = HUD.NameLabel.Text
			end
			local v = violet():Lerp(WHITE, 0.4)
			HUD.NameLabel.Text = string.format('%s  <font size="11" color="#%02X%02X%02X">POSSESSED</font>', name,
				math.floor(v.R * 255), math.floor(v.G * 255), math.floor(v.B * 255))
		end
		if not PH.conn then
			PH.conn = RunService.RenderStepped:Connect(function()
				local ok, err = pcall(PH.tick)
				if not ok then
					warn("[HUD] possess: " .. tostring(err))
				end
			end)
		end
	end

	---------------------------------------------------------------------------
	-- the test menu's POSSESS panel. cb = { List() -> { { Model, Name, Sub,
	-- Color, State = "Free" | "Mine" | "Taken" } }, Pick(model), Leave(),
	-- In() -> the name of the body you're in (nil: your own) }
	---------------------------------------------------------------------------
	function HUD.BuildPossessPanel(cb)
		if PH.frame then
			return
		end
		PH.cb = cb or {}
		local v = violet()
		local frame = make("Frame", {
			Name = "PossessBodies",
			Position = UDim2.new(0, 22 + TEST_W, 0, 108),
			Size = UDim2.fromOffset(PW, 430),
			BackgroundColor3 = Color3.fromRGB(17, 18, 27),
			BackgroundTransparency = 0.04,
			Visible = false,
			ZIndex = 20,
			Parent = gui,
		}, {
			corner(12),
			make("UIStroke", { Thickness = 1.5, Color = v, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -60, 0, 30),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = light(v),
			Text = "POSSESS",
			ZIndex = 21,
			Parent = frame,
		}, { textStroke(1.5) })
		PH.sub = make("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(16, 36),
			Size = UDim2.new(1, -32, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(190, 194, 214),
			Text = "Take over a body. K aims at one, K again to leave.",
			ZIndex = 21,
			Parent = frame,
		})
		local close = make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Color3.fromRGB(46, 48, 66),
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = WHITE,
			Text = "X",
			ZIndex = 22,
			Parent = frame,
		}, { corner(14) })
		close.MouseButton1Click:Connect(function()
			HUD.TogglePossessPanel(false)
		end)
		-- where you are: in your own body, or in one (and the way out)
		PH.status = make("Frame", {
			Name = "Status",
			Position = UDim2.fromOffset(12, 58),
			Size = UDim2.new(1, -24, 0, 36),
			BackgroundColor3 = Color3.fromRGB(30, 31, 44),
			ZIndex = 21,
			Parent = frame,
		}, { corner(8) })
		PH.statusText = make("TextLabel", {
			Name = "Where",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -130, 1, 0),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 12,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 22,
			Parent = PH.status,
		})
		PH.leave = make("TextButton", {
			Name = "Leave",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(112, 26),
			BackgroundColor3 = Color3.fromRGB(190, 60, 96),
			AutoButtonColor = true,
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = WHITE,
			Text = "LEAVE BODY",
			Visible = false,
			ZIndex = 22,
			Parent = PH.status,
		}, { corner(6) })
		PH.leave.MouseButton1Click:Connect(function()
			if PH.cb.Leave then
				PH.cb.Leave()
			end
		end)
		PH.list = make("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(8, 102),
			Size = UDim2.new(1, -12, 1, -160),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 21,
			Parent = frame,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }),
		})
		PH.empty = make("TextLabel", {
			Name = "Empty",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = DIM,
			Text = "No bodies about - spawn a dummy (TEST > Spawn Dummies...)",
			LayoutOrder = 9999,
			Visible = false,
			ZIndex = 22,
			Parent = PH.list,
		})
		PH.foot = make("TextLabel", {
			Name = "Keys",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14, 1, -8),
			Size = UDim2.new(1, -28, 0, 44),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextColor3 = Color3.fromRGB(196, 190, 220),
			-- ((round 92 review) no "· T locks on": the lock-on's gone)
			Text = "<b>DUMMY</b>  M1 punch · F guard · Q dash (down: cancel)\n<b>NOMU</b>  M1 swipe · 1 slam · 2 charge · 3 roar\nWalk, run, jump as yourself",
			ZIndex = 21,
			Parent = frame,
		})
		PH.frame = frame
		PH.layout()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(PH.layout)
		end
	end
	-- fits the screen: beside the menu at 720p; under the top bar, compact, on a phone
	function PH.layout()
		if not PH.frame then
			return
		end
		local cam = workspace.CurrentCamera
		local vpY = (cam and cam.ViewportSize.Y) or 720
		local y0 = vpY < 500 and 52 or 108
		local h = math.clamp(vpY - y0 - 12, 220, 430)
		local compact = h < 340
		PH.frame.Position = UDim2.new(0, 22 + TEST_W, 0, y0)
		PH.frame.Size = UDim2.fromOffset(PW, h)
		PH.sub.Visible = not compact
		PH.foot.Visible = not compact
		local top = compact and 40 or 58
		PH.status.Position = UDim2.fromOffset(12, top)
		PH.list.Position = UDim2.fromOffset(8, top + 44)
		PH.list.Size = UDim2.new(1, -12, 1, -(top + 44) - (compact and 8 or 58))
	end

	local function makeRow(i)
		local row = make("Frame", {
			Name = "Body" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = Color3.fromRGB(38, 40, 57),
			ZIndex = 22,
			Parent = PH.list,
		}, { corner(7) })
		local stripe = make("Frame", {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -14),
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = row,
		})
		local name = make("TextLabel", {
			Name = "BodyName",
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -120, 0, 18),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 23,
			Parent = row,
		})
		local sub = make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(12, 22),
			Size = UDim2.new(1, -120, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 23,
			Parent = row,
		})
		local take = make("TextButton", {
			Name = "Take",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(92, 26),
			BackgroundColor3 = violet(),
			AutoButtonColor = true,
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = WHITE,
			Text = "TAKE",
			ZIndex = 23,
			Parent = row,
		}, { corner(6) })
		local r = { Frame = row, Stripe = stripe, Name = name, Sub = sub, Take = take }
		take.MouseButton1Click:Connect(function()
			local e = r.Entry
			if e and e.State == "Free" and PH.cb.Pick then
				PH.cb.Pick(e.Model)
				take.Text = "..."
			end
		end)
		return r
	end
	function HUD.RefreshPossessPanel()
		if not PH.frame then
			return
		end
		local inName = PH.cb.In and PH.cb.In() or nil
		local v = violet()
		if inName then
			PH.statusText.Text = string.format('<font color="#%02X%02X%02X">IN</font>  %s', math.floor(light(v).R * 255), math.floor(light(v).G * 255), math.floor(light(v).B * 255), string.upper(inName))
		else
			PH.statusText.Text = '<font color="#A0A0B4">YOU\'RE IN YOUR OWN BODY</font>'
		end
		PH.leave.Visible = inName ~= nil
		local list = PH.cb.List and PH.cb.List() or {}
		for i, e in list do
			local r = PH.rows[i]
			if not r then
				r = makeRow(i)
				PH.rows[i] = r
			end
			r.Entry = e
			r.Frame.Visible = true
			r.Name.Text = e.Name or ""
			r.Sub.Text = e.Sub or ""
			r.Stripe.BackgroundColor3 = e.Color or WHITE
			local mine, taken = e.State == "Mine", e.State == "Taken"
			r.Take.Text = mine and "YOU'RE IN" or (taken and "TAKEN" or "TAKE")
			r.Take.Active = not (mine or taken)
			r.Take.AutoButtonColor = not (mine or taken)
			r.Take.BackgroundColor3 = mine and Color3.fromRGB(60, 150, 100) or (taken and Color3.fromRGB(70, 72, 90) or v)
			r.Take.TextColor3 = taken and DIM or WHITE
			r.Frame.BackgroundColor3 = mine and Color3.fromRGB(44, 36, 66) or Color3.fromRGB(38, 40, 57)
		end
		for i = #list + 1, #PH.rows do
			PH.rows[i].Frame.Visible = false
			PH.rows[i].Entry = nil
		end
		PH.empty.Visible = #list == 0
	end
	-- (open: it keeps itself current - bodies come and go, people move)
	function HUD.TogglePossessPanel(force)
		if not PH.frame then
			return false
		end
		if force ~= nil then
			PH.frame.Visible = force
		else
			PH.frame.Visible = not PH.frame.Visible
		end
		if PH.frame.Visible then
			HUD.RefreshPossessPanel()
			if not PH.loop then
				local token = {}
				PH.loop = token
				task.spawn(function()
					while PH.loop == token and PH.frame and PH.frame.Visible do
						task.wait(0.5)
						if PH.loop == token and PH.frame.Visible then
							pcall(HUD.RefreshPossessPanel)
						end
					end
					if PH.loop == token then
						PH.loop = nil
					end
				end)
			end
		else
			PH.loop = nil
		end
		return PH.frame.Visible
	end
end

---------------------------------------------------------------------------
-- (round 88) THE CARRY on the screen (Config.DevFlight.Carry; the carry
-- itself is QuirkClient's DevFly.CR and the server's Kit.CR). While he
-- flies: his hero's move boxes as ever plus a 5th, GRAB (its key, the
-- flight's cyan, a slow glow so it's the one you see), and the dash box
-- says BURST (it's the mach burst up there). Holding someone: the boxes are
-- the carry's - SLAM / THROW / RAM / DROP, each its key and colour, the one
-- going lit - and a chip over the health bar: CARRYING <who>, the time left
-- before he lets go by himself draining under it. On a phone: a round GRAB
-- button by the others (DROP while he holds someone), the 1 / 2 / 3
-- buttons say SLAM / THROW / RAM and his other moves' buttons dim (HIT, 4,
-- the extra, ULT: his hands are full). The one being carried gets a chip of his
-- own: HELD BY <who>, and how long. HUD.Carry(nil) / HUD.CarryHeld(nil)
-- put back exactly what was there.
---------------------------------------------------------------------------
do
	local CH = { boxes = {}, saved = nil }
	HUD.CarryHud = CH
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local INK = Color3.fromRGB(10, 22, 30)
	local function cfg()
		return (Config and Config.DevFlight and Config.DevFlight.Carry) or {}
	end
	local function cyan()
		return cfg().Color or Color3.fromRGB(120, 220, 255)
	end
	function CH.bar()
		local dock = vitals and vitals.Parent
		return dock and dock:FindFirstChild("Abilities"), dock
	end
	-- the words as wide as they'll be (the possession chip's measure)
	function CH.width(text, size, font)
		if HUD.PossessHud and HUD.PossessHud.width then
			return HUD.PossessHud.width(text, size, font)
		end
		return #text * size * 0.72
	end

	-- the 5th box: GRAB, in the move bar after the others
	function CH.grabSlot()
		if CH.slot and CH.slot.Frame.Parent then
			return CH.slot
		end
		local bar = CH.bar()
		if not bar then
			return nil
		end
		local c = cyan()
		local f = make("Frame", {
			Name = "SlotGrab",
			Size = UDim2.fromOffset(96, 70),
			BackgroundColor3 = GLASS.Color:Lerp(c, 0.16),
			BackgroundTransparency = GLASS.T,
			ClipsDescendants = true,
			LayoutOrder = 6,
			Visible = false,
			Parent = bar,
		}, { corner(3) })
		local glow = make("UIStroke", { Name = "Glow", Thickness = 1.5, Color = c, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
		local key = make("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(40, 16),
			Position = UDim2.fromOffset(6, 5),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			TextTransparency = 0.2,
			Text = "Z",
			ZIndex = 3,
			Parent = f,
		})
		make("TextLabel", {
			Name = "Tag",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 6),
			Size = UDim2.fromOffset(44, 12),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = c:Lerp(WHITE, 0.35),
			Text = "FLIGHT",
			ZIndex = 3,
			Parent = f,
		})
		local name = make("TextLabel", {
			Name = "MoveName",
			Size = UDim2.new(1, -10, 0, 38),
			Position = UDim2.new(0, 5, 1, -44),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextColor3 = WHITE,
			Text = "GRAB",
			ZIndex = 2,
			Parent = f,
		}, { make("UITextSizeConstraint", { MaxTextSize = 16 }), textStroke(1) })
		make("Frame", {
			Name = "Accent",
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = f,
		})
		CH.slot = { Frame = f, Key = key, Name = name, Glow = glow }
		return CH.slot
	end

	-- the carry's own boxes, where the move bar was
	function CH.dock()
		if CH.dockFrame and CH.dockFrame.Parent then
			return CH.dockFrame
		end
		local _, dock = CH.bar()
		if not dock then
			return nil
		end
		local f = make("Frame", {
			Name = "CarryMoves",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -26),
			Size = UDim2.fromOffset(560, 70),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = dock,
		}, {
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i = 1, 4 do
			local box = make("Frame", {
				Name = "Move" .. i,
				Size = UDim2.fromOffset(110, 70),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				ClipsDescendants = true,
				LayoutOrder = i,
				Parent = f,
			}, { corner(3) })
			local st = make("UIStroke", { Thickness = 1, Color = WHITE, Transparency = GLASS.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
			local key = make("TextLabel", {
				Name = "Key",
				Position = UDim2.fromOffset(6, 5),
				Size = UDim2.fromOffset(70, 16),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = WHITE,
				TextTransparency = 0.25,
				Text = "",
				ZIndex = 3,
				Parent = box,
			})
			local alt = make("TextLabel", {
				Name = "Alt",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(60, 12),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = WHITE,
				TextTransparency = 0.45,
				Text = "",
				ZIndex = 3,
				Parent = box,
			})
			local name = make("TextLabel", {
				Name = "MoveName",
				Position = UDim2.new(0, 5, 1, -42),
				Size = UDim2.new(1, -10, 0, 34),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextScaled = true,
				TextColor3 = WHITE,
				Text = "",
				ZIndex = 2,
				Parent = box,
			}, { make("UITextSizeConstraint", { MaxTextSize = 18 }), textStroke(1) })
			local strip = make("Frame", {
				Name = "Accent",
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = cyan(),
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = box,
			})
			CH.boxes[i] = { Frame = box, Stroke = st, Key = key, Alt = alt, Name = name, Accent = strip }
		end
		CH.dockFrame = f
		return f
	end

	-- a pill over the health bar: CARRYING <who> (or, his own: HELD BY <who>),
	-- the time he's got left draining under it
	function CH.pill(name, kicker, color)
		local frame = CH[name]
		if frame and frame.Parent then
			return frame
		end
		if not vitals then
			return nil
		end
		local chip = make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.fromOffset(320, 26),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.1,
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 5,
			Parent = vitals,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Name = "Edge", Thickness = 1.5, Color = color, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Name = "Kicker",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(0, 84, 1, -3),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color:Lerp(WHITE, 0.45),
			Text = kicker,
			ZIndex = 6,
			Parent = chip,
		})
		make("TextLabel", {
			Name = "Who",
			Position = UDim2.fromOffset(100, 0),
			Size = UDim2.new(1, -190, 1, -3),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 6,
			Parent = chip,
		}, { textStroke(1) })
		make("TextLabel", {
			Name = "Left",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.fromOffset(80, 23),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(210, 222, 232),
			Text = "",
			ZIndex = 6,
			Parent = chip,
		})
		-- (the time left: a thin bar along the bottom, draining)
		make("Frame", {
			Name = "Time",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = chip,
		})
		CH[name] = chip
		return chip
	end
	-- (over whatever else sits on the health bar - a hero's own meter, at
	-- -18 like Bakugo's SWEAT - never on top of it)
	function CH.lift(chip)
		if not (chip and vitals) then
			return
		end
		local top = 0
		for _, c in vitals:GetChildren() do
			if c ~= chip and c:IsA("GuiObject") and c.Visible and c.Name ~= "CarryChip" and c.Name ~= "HeldChip" and c.Name ~= "PossessChip"
				and c.Position.Y.Scale == 0 and c.Position.Y.Offset < 0 then
				top = math.min(top, c.Position.Y.Offset - c.AnchorPoint.Y * c.Size.Y.Offset)
			end
		end
		local want = UDim2.new(0.5, 0, 0, top - 8)
		if chip.Position ~= want then
			chip.Position = want
		end
	end

	-- the phone's round GRAB / DROP button (beside the others, over DASH)
	function CH.touchButton()
		local T = HUD.Touch
		if CH.button and CH.button.Parent then
			return CH.button
		end
		if not (T and T.pad and T.wire) then
			return nil
		end
		local b = make("TextButton", {
			Name = "TouchGRAB",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = GLASS.Color:Lerp(cyan(), 0.35),
			BackgroundTransparency = 0.2,
			AutoButtonColor = true,
			Font = HEAD_FONT,
			TextScaled = true,
			TextColor3 = WHITE,
			Text = "GRAB",
			Visible = false,
			Parent = T.pad,
		}, {
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			make("UIStroke", { Name = "Glow", Thickness = 2.5, Color = cyan(), Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			make("UIPadding", { PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0), PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0) }),
		})
		T.wire(b, "QuirkCarryGrab")
		CH.button = b
		return b
	end
	-- (where: off the jump button like the rest - over RUN, left of FINISH:
	-- clear of the wallet and rank tucked in a phone's top-right corner)
	CH.SPOT = { -172, -244, 56 }
	function CH.placeButton()
		local T = HUD.Touch
		local b = CH.button
		if not (b and T and T.metrics) then
			return
		end
		local jx, jy, k = T.metrics()
		b.Position = UDim2.new(1, jx + CH.SPOT[1] * k, 1, jy + CH.SPOT[2] * k)
		b.Size = UDim2.fromOffset(CH.SPOT[3] * k, CH.SPOT[3] * k)
	end

	-- (a phone, holding someone: his own moves' buttons - HIT, 4, the extra,
	-- ULT - stay where they are but dimmed, his hands are full; a cover over
	-- each, so nothing of theirs is changed and taking it off is exact)
	function CH.dim(on)
		local T = HUD.Touch
		local list = {}
		if T and T.buttons then
			table.insert(list, T.buttons.QuirkPunch)
			table.insert(list, T.buttons.QuirkUlt)
		end
		for _, i in { 4, 6 } do
			if slots[i] and slots[i].Frame then
				table.insert(list, slots[i].Frame)
			end
		end
		for _, f in list do
			local cover = f:FindFirstChild("CarryDim")
			if on and not cover then
				cover = make("Frame", {
					Name = "CarryDim",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = BLACK,
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					ZIndex = 9,
					Parent = f,
				}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			end
			if cover then
				cover.Visible = on == true
			end
		end
	end

	-- the key a move is on, the way this device shows it
	function CH.cap(m, mode)
		if mode == "Gamepad" then
			for _, k in m.Keys or {} do
				if string.sub(k.Name, 1, 6) == "Button" or string.sub(k.Name, 1, 4) == "DPad" then
					local g = HUD.PadGlyph and HUD.PadGlyph({ k }) or ""
					return g ~= "" and g or (m.Pad or "")
				end
			end
			return m.Pad or ""
		end
		return mode == "Touch" and (m.Touch or "") or (m.Cap or "")
	end

	-- every frame while it's up: GRAB's glow, the time left, the move going
	function CH.tick()
		local info = CH.info
		local now = os.clock()
		-- (the phone's layout switched on or off meanwhile: drawn for it again)
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		if info and touch ~= CH.touchWas then
			CH.touchWas = touch
			HUD.Carry(info)
		end
		local k = (math.sin(now * 4.2) + 1) / 2
		if info and info.Mode == "Flight" and CH.slot then
			CH.slot.Glow.Transparency = 0.05 + 0.5 * k
			CH.slot.Glow.Thickness = 1.5 + 1.5 * k
		end
		if CH.button and CH.button.Visible then
			local g = CH.button:FindFirstChild("Glow")
			if g then
				g.Transparency = 0.05 + 0.45 * k
			end
		end
		local serverNow = workspace:GetServerTimeNow()
		for _, spec in { { "CarryChip", info }, { "HeldChip", CH.held } } do
			local chip, data = CH[spec[1]], spec[2]
			if chip and chip.Visible then
				CH.lift(chip)
			end
			-- (after round 88: no time limit - no clock on the chip)
			if chip and chip.Visible and data then
				chip.Time.Visible = data.Ends ~= nil
				chip.Left.Visible = data.Ends ~= nil
			end
			if chip and chip.Visible and data and data.Ends then
				local left = math.max(data.Ends - serverNow, 0)
				local frac = math.clamp(left / math.max(data.Max or 6, 0.1), 0, 1)
				chip.Time.Size = UDim2.new(frac, 0, 0, 3)
				chip.Left.Text = string.format("%.1fs", left)
				chip.Time.BackgroundColor3 = (left < 1.5 and (now * 6) % 1 < 0.5) and Color3.fromRGB(255, 90, 80) or (spec[1] == "HeldChip" and Color3.fromRGB(255, 120, 90) or cyan())
			end
		end
		if info and info.Mode == "Carry" then
			for i, box in CH.boxes do
				local m = info.Moves and info.Moves[i]
				local on = m and info.Busy == m.Act
				box.Accent.Size = UDim2.new(1, 0, 0, on and 6 or 3)
				box.Stroke.Transparency = on and 0 or GLASS.Edge
				box.Stroke.Color = on and (m.Color or WHITE) or WHITE
				box.Frame.BackgroundTransparency = (info.Busy and not on) and 0.45 or GLASS.T
			end
		end
	end
	function CH.loop(on)
		if on and not CH.conn then
			CH.conn = RunService.RenderStepped:Connect(function()
				local ok, err = pcall(CH.tick)
				if not ok then
					warn("[HUD] carry: " .. tostring(err))
				end
			end)
		elseif not on and CH.conn and not CH.info and not CH.held then
			CH.conn:Disconnect()
			CH.conn = nil
		end
	end

	-- what was on the bar before (put back as it was; the move boxes' own
	-- names are the hero's - the client has HUD.SetQuirk write them again
	-- when the carry's are taken off a phone's buttons)
	function CH.save()
		if CH.saved then
			return CH.saved
		end
		CH.saved = { Dash = slots[5] and slots[5].Name.Text }
		return CH.saved
	end

	-- info: { Mode = "Flight" | "Carry", Input = "Keyboard" | "Gamepad" |
	-- "Touch", Name (who he holds), Ends (server time he lets go), Max,
	-- Busy (the move going), Moves (Config.DevFlight.Carry.Moves) } - nil:
	-- back to exactly what was there
	function HUD.Carry(info)
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		local bar = CH.bar()
		local saved = CH.saved
		if not info then
			CH.info = nil
			if CH.slot then
				CH.slot.Frame.Visible = false
			end
			if CH.dockFrame then
				CH.dockFrame.Visible = false
			end
			if CH.CarryChip then
				CH.CarryChip.Visible = false
			end
			if CH.button then
				CH.button.Visible = false
			end
			CH.dim(false)
			if saved then
				if bar then
					bar.Visible = not touch
				end
				if slots[5] and saved.Dash then
					slots[5].Name.Text = saved.Dash
				end
			end
			CH.saved = nil
			CH.loop(false)
			return
		end
		saved = CH.save()
		CH.info = info
		local mode = info.Input or "Keyboard"
		local slot = CH.grabSlot()
		local dockF = CH.dock()
		local chip = CH.pill("CarryChip", "CARRYING", cyan())
		if touch then
			CH.touchButton()
			CH.placeButton()
		end
		if info.Mode == "Flight" then
			if slot then
				slot.Frame.Visible = true
				slot.Key.Text = mode == "Gamepad" and (HUD.PadGlyph and HUD.PadGlyph({ cfg().PadKey or Enum.KeyCode.ButtonR3 }) or "R3")
					or (cfg().Key and cfg().Key.Name or "Z")
				slot.Key.Visible = mode ~= "Touch"
			end
			if dockF then
				dockF.Visible = false
			end
			if bar then
				bar.Visible = not touch
			end
			if slots[5] then
				slots[5].Name.Text = "BURST" -- (the dash key is the mach burst up here)
			end
			if chip then
				chip.Visible = false
			end
			if CH.button then
				CH.button.Visible = touch
				CH.button.Text = "GRAB"
			end
			CH.dim(false)
			if hintLabel and mode == "Keyboard" then
				-- ((round 92) T: the hover-lock - its keys are the flight's own now)
				hintLabel.Text = "CLICK Punch · 1/2/3/4 Moves · Z Grab · Q Burst · X Dive · F Brake · T Lock · CTRL Fast · SPACE / C Up / Down · V Land"
			end
		else
			if slot then
				slot.Frame.Visible = false
			end
			if bar then
				bar.Visible = false
			end
			if dockF then
				dockF.Visible = not touch
			end
			for i, box in CH.boxes do
				local m = info.Moves and info.Moves[i]
				box.Frame.Visible = m ~= nil
				if m then
					box.Name.Text = m.Name or ""
					box.Key.Text = CH.cap(m, mode)
					box.Accent.BackgroundColor3 = m.Color or cyan()
					-- (the flight's own key that means the same, small)
					local alt = ""
					if mode == "Keyboard" then
						local names = {}
						for j, key in m.Keys or {} do
							if j > 1 and string.sub(key.Name, 1, 6) ~= "Button" then
								table.insert(names, key.Name)
							end
						end
						alt = #names > 0 and ("or " .. table.concat(names, " / ")) or ""
					end
					box.Alt.Text = alt
				end
			end
			-- (a phone's 1 / 2 / 3 say what they do now; GRAB is DROP)
			if touch then
				for i = 1, 3 do
					local m = info.Moves and info.Moves[i]
					if slots[i] and m then
						slots[i].Name.Text = m.Touch or m.Name
					end
				end
			end
			if CH.button then
				CH.button.Visible = touch
				CH.button.Text = "DROP"
			end
			CH.dim(touch)
			if chip then
				local who = string.upper(tostring(info.Name or ""))
				chip.Who.Text = who
				local kick = math.ceil(CH.width("CARRYING", 11, HEAD_FONT)) + 10
				chip.Kicker.Size = UDim2.new(0, kick, 1, -3)
				chip.Who.Position = UDim2.fromOffset(14 + kick, 0)
				local w = 14 + kick + CH.width(who, 14, HEAD_FONT) + 16 + 70
				chip.Size = UDim2.fromOffset(math.clamp(math.ceil(w), 240, 460), 26)
				chip.Who.Size = UDim2.new(1, -(14 + kick + 76), 1, -3)
				chip.Visible = true
				CH.lift(chip)
			end
			if hintLabel and mode == "Keyboard" then
				hintLabel.Text = "1 Slam · 2 Throw · 3 Ram · 4 / Z Drop · F Brake · CTRL Fast · SPACE / C Up / Down"
			end
		end
		CH.loop(true)
	end

	-- the one being carried: HELD BY <who> and the time left (nil: gone)
	function HUD.CarryHeld(info)
		CH.held = info
		local chip = CH.pill("HeldChip", "HELD BY", Color3.fromRGB(255, 120, 90))
		if not chip then
			return
		end
		if not info then
			chip.Visible = false
			CH.loop(false)
			return
		end
		local who = string.upper(tostring(info.By or ""))
		chip.Who.Text = who
		local kick = math.ceil(CH.width("HELD BY", 11, HEAD_FONT)) + 10
		chip.Kicker.Size = UDim2.new(0, kick, 1, -3)
		chip.Who.Position = UDim2.fromOffset(14 + kick, 0)
		chip.Size = UDim2.fromOffset(math.clamp(math.ceil(14 + kick + CH.width(who, 14, HEAD_FONT) + 16 + 70), 220, 420), 26)
		chip.Who.Size = UDim2.new(1, -(14 + kick + 76), 1, -3)
		chip.Visible = true
		CH.lift(chip)
		CH.loop(true)
	end
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
		-- the ones on your wheel
		emoteTab = page("EmoteShop")
		emoteSlotRow = make("Frame", {
			Name = "Wheel",
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			ZIndex = 52,
			Parent = emoteTab,
		}, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		-- (round 92) every slot of the wheel (8 now) in the one row, so the
		-- list below keeps its room on a phone: a tile each - its number, the
		-- emote's icon and its name under it, shrunk to fit (the list's ON
		-- WHEEL · n says which slot each one's in)
		local slotsN = Config.EmoteSlots or 4
		for i = 1, slotsN do
			local slot = make("TextButton", {
				Name = "Slot" .. i,
				LayoutOrder = i,
				Size = UDim2.new(1 / slotsN, -6 * (slotsN - 1) / slotsN, 1, 0),
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
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.fromOffset(15, 15),
				BackgroundColor3 = Color3.fromRGB(46, 46, 52),
				Font = SH.font,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				Text = tostring(i),
				ZIndex = 55,
				Parent = slot,
			}, { corner(3) })
			local icon = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 4, 0, 3), -- (a little right: clear of the number on a phone's narrow tile)
				Size = UDim2.fromOffset(26, 28),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = "＋",
				TextColor3 = SH.ink,
				ZIndex = 54,
				Parent = slot,
			})
			local name = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.new(1, -6, 0, 17),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextColor3 = SH.ink,
				Text = "EMPTY",
				ZIndex = 54,
				Parent = slot,
			}, { make("UITextSizeConstraint", { MaxTextSize = 16 }) })
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
			-- (round 85) the name shrinks to fit (26 at most) in the room up to
			-- the rarity pill, so a long one still fits on a phone. 30 tall, not
			-- the row's 44: TextScaled wraps too, and two lines in 30 are 15 at
			-- most, so a long name stays on one line (16+) instead of going to
			-- two 22s that fill the row
			make("TextLabel", {
				Name = "RowName",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 48, 0.5, 0),
				Size = UDim2.new(0.5, -56, 0, 30),
				BackgroundTransparency = 1,
				Font = SH.font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SH.ink,
				Text = e.Name or e.Id,
				ZIndex = 54,
				Parent = row,
			}, { make("UITextSizeConstraint", { MaxTextSize = 26 }) })
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
			-- (round 85) from 8 px after the rarity pill to 8 px from the end
			-- (it was 0.3 wide, which ran 6 px over the rarity pill on a phone)
			local pillLabel = make("TextLabel", {
				Name = "Pill",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0.5, -112, 0, 30),
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
			-- ((round 92) no "T Lock-on" / "L3 Lock-on" any more: the lock-on's gone)
			hintLabel.Text = pad
					and "B Punch · LB/LT/RT Moves · RB Finish/Extra · ◀ Special · ▲ Ult · Y Dash · X Block · ▼ Shift Lock · ▶ Item · SELECT Shop"
				or "CLICK Punch · 1/2/3/4 Moves · R Special · G Ult · Q Dash · F Block · CTRL Sprint · B Emotes · H Shop · M Quirk"
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
			local label = b:FindFirstChild("Label") -- (round 92: the name under the icon)
			if label then
				label.TextColor3 = b.TextColor3
			end
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
		-- (round 92) the wheel holds 8 now (Config.EmoteSlots): one ring of 8
		-- buttons, each the emote's icon over its name (88 x 64), 138 out -
		-- just far enough that neighbours don't touch - in a 400 ring, about
		-- the size the 4 were
		layout.size = layout.outer > 0 and 560 or (layout.inner > 4 and 400 or 380)
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
		local mid = (layout.outer == 0 and layout.inner > 4) and 116 or 132 -- (round 92: 8 round it - a little smaller)
		centerLabel = make("TextLabel", {
			Name = "Center",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(mid, mid),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.1,
			Font = HEAD_FONT,
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "EMOTES",
			ZIndex = 43,
			Parent = ring,
		}, { corner(mid / 2), edge(0.5), textStroke(1), make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
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
			local r = outer and 222 or (layout.outer > 0 and 130 or (layout.inner > 4 and 138 or 132))
			-- (round 92) the icon over the name (it was the name alone): with 8
			-- round the ring the picture is what the eye finds first
			local b = make("TextButton", {
				Name = e.Empty and ("Emote_Empty" .. i) or ("Emote_" .. tostring(e.Id)),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
				Size = UDim2.fromOffset(88, 64),
				BackgroundColor3 = GLASS.Color,
				BackgroundTransparency = GLASS.T,
				Font = HEAD_FONT,
				TextSize = 13,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				AutoButtonColor = false,
				ZIndex = 42,
				Parent = ring,
			}, { corner(8), edge(0.5) })
			make("TextLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 5),
				Size = UDim2.fromOffset(32, 28),
				BackgroundTransparency = 1,
				TextScaled = true,
				Text = e.Empty and "＋" or (e.Icon or "★"),
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = e.Empty and 0.4 or 0,
				ZIndex = 43,
				Parent = b,
			})
			make("TextLabel", {
				Name = "Label",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -8, 0, 24),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = e.Empty and 0.4 or 0,
				Text = e.Empty and "EMPTY" or (e.Name or e.Id),
				ZIndex = 43,
				Parent = b,
			}, { make("UITextSizeConstraint", { MaxTextSize = 13 }) })
			b:SetAttribute("Label", e.Empty and "GET EMOTES IN THE SHOP" or (e.Name or e.Id))
			b:SetAttribute("EmoteId", e.Id)
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
			{ C.ShiftLockKeys, "SHIFT LOCK" }, { C.UseItemKeys, "ITEM" }, -- ((round 92) no LOCK ON row: gone)
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
		-- (round 86) Hawks' wings can fill your own view: hide yours (only on your screen)
		{ Key = "HideMyWings", Label = "HIDE MY WINGS", Info = "Hawks: your own wings hidden on your screen (everyone else still sees them)", Default = false },
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
		-- ((round 92) the lock-on's LOCK is gone: this one's the DEV FLIGHT's
		-- HOVER-LOCK, shown only while he flies - HUD.SetTouchHoverLock)
		{ "QuirkHoverLock", "LOCK", -206, -166, 40 },
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
					Visible = spec[2] ~= "FINISH" and spec[1] ~= "QuirkHoverLock",
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

	-- (round 92) LOCK: the dev flight's hover-lock - up while he flies
	-- (HUD.FlightMeter shows / hides it with the meter), never on foot
	function HUD.SetTouchHoverLock(visible)
		local b = TOUCH.buttons.QuirkHoverLock
		if b and b.Visible ~= (visible == true) then
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

---------------------------------------------------------------------------
-- (round 89) THE JOIN THE DISCORD CARD (Config.Discord; QuirkClient's
-- DiscordClient opens it from the kiosk's prompt, and says which words):
-- the HUD's glass with a blurple pill along the top, a chat badge, the
-- title and a line. For a player Roblox allows Discord links: the invite in
-- a box to select and copy (a TextBox nobody can type in, kept when it's
-- clicked - clicking it selects all of it, SELECT does the same), what to
-- press on this device, and CLOSE. Anyone else gets the neutral title and
-- line, no invite (not even hidden). It grows with the screen and always
-- fits (a phone's too); B, CLOSE, the X or walking off closes it.
---------------------------------------------------------------------------
do
	local DC = { invite = "", mode = "Keyboard", words = {} }
	HUD.DiscordCard = DC
	local W, TALL, SHORT = 460, 248, 150
	local BLURPLE = Color3.fromRGB(88, 101, 242)
	local DIM = Color3.fromRGB(190, 194, 220)
	local HINT = Color3.fromRGB(150, 156, 190)
	local HOT = Color3.fromRGB(170, 180, 255)

	function DC.build()
		if DC.root and DC.root.Parent then
			return DC.root
		end
		if not gui then
			return nil
		end
		local root = make("Frame", {
			Name = "DiscordCard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(W, TALL),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.04,
			Active = true, -- (clicks on it don't throw punches)
			Visible = false,
			ZIndex = 55,
			Parent = gui,
		}, { corner(12), edge(0.72) })
		DC.scale = make("UIScale", { Name = "Fit", Parent = root })
		-- (a Modal button frees a shift-locked mouse while it's open)
		make("TextButton", { Name = "Modal", Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true, ZIndex = 55, Parent = root })
		DC.pill = make("Frame", {
			Name = "Pill",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -32, 0, 4),
			BackgroundColor3 = BLURPLE,
			BorderSizePixel = 0,
			ZIndex = 56,
			Parent = root,
		}, { corner(2), gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 196, 255), 0) })
		DC.badge = make("Frame", {
			Name = "Badge",
			Position = UDim2.fromOffset(18, 22),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = BLURPLE,
			ZIndex = 56,
			Parent = root,
		}, { corner(12), gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 204, 230), 90) })
		make("TextLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			TextScaled = true,
			Font = UI_FONT,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "💬",
			ZIndex = 57,
			Parent = DC.badge,
		})
		DC.title = make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(74, 20),
			Size = UDim2.new(1, -120, 0, 26),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			ZIndex = 56,
			Parent = root,
		})
		DC.line = make("TextLabel", {
			Name = "Line",
			Position = UDim2.fromOffset(74, 48),
			Size = UDim2.new(1, -92, 0, 34),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 56,
			Parent = root,
		})
		local x = make("TextButton", {
			Name = "X",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 14),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Color3.fromRGB(36, 37, 48),
			BackgroundTransparency = 0.2,
			Font = HEAD_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "✕",
			ZIndex = 57,
			Parent = root,
		}, { corner(8) })
		x.Activated:Connect(function()
			HUD.HideDiscord()
		end)
		-- the invite: in a box you can select (and copy) but not type in
		DC.row = make("Frame", {
			Name = "InviteRow",
			Position = UDim2.fromOffset(18, 92),
			Size = UDim2.new(1, -36, 0, 50),
			BackgroundColor3 = Color3.fromRGB(6, 6, 10),
			ZIndex = 56,
			Parent = root,
		}, {
			corner(10),
			make("UIStroke", { Name = "Edge", Thickness = 1.5, Color = BLURPLE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		DC.box = make("TextBox", {
			Name = "Invite",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -132, 1, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			TextEditable = false,
			Font = Enum.Font.Code,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			PlaceholderText = "",
			Text = "",
			ZIndex = 57,
			Parent = DC.row,
		})
		DC.box.Focused:Connect(function()
			DC.selectAll()
		end)
		DC.box.FocusLost:Connect(function()
			DC.hintFor(false)
		end)
		-- (nothing can change it: it's always the invite, or nothing)
		DC.box:GetPropertyChangedSignal("Text"):Connect(function()
			if DC.box.Text ~= DC.invite then
				DC.box.Text = DC.invite
			end
		end)
		DC.select = make("TextButton", {
			Name = "Select",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -7, 0.5, 0),
			Size = UDim2.fromOffset(104, 36),
			BackgroundColor3 = BLURPLE,
			Font = HEAD_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "SELECT",
			ZIndex = 57,
			Parent = DC.row,
		}, { corner(8) })
		DC.select.Activated:Connect(function()
			if DC.box and DC.invite ~= "" then
				pcall(function()
					DC.box:CaptureFocus()
				end)
				DC.selectAll()
			end
		end)
		DC.hint = make("TextLabel", {
			Name = "Hint",
			Position = UDim2.fromOffset(20, 150),
			Size = UDim2.new(1, -40, 0, 32),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = HINT,
			Text = "",
			ZIndex = 56,
			Parent = root,
		})
		DC.close = make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.fromOffset(150, 36),
			BackgroundColor3 = Color3.fromRGB(36, 38, 52),
			Font = HEAD_FONT,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "CLOSE",
			ZIndex = 57,
			Parent = root,
		}, { corner(8), edge(0.8) })
		DC.close.Activated:Connect(function()
			HUD.HideDiscord()
		end)
		DC.root = root
		return root
	end

	-- all of the invite selected (after the click that focused it has put
	-- its cursor down), and the hint says what's next
	function DC.selectAll()
		if not DC.box or DC.invite == "" then
			return
		end
		DC.hintFor(true)
		task.defer(function()
			pcall(function()
				DC.box.CursorPosition = #DC.box.Text + 1
				DC.box.SelectionStart = 1
			end)
		end)
	end

	function DC.hintFor(selected)
		if not DC.hint then
			return
		end
		local set = selected and DC.words.Selected or DC.words.Hint
		DC.hint.Text = type(set) == "table" and (set[DC.mode] or set.Keyboard or "") or ""
		DC.hint.TextColor3 = selected and HOT or HINT
	end

	-- the card's size for this screen: bigger on a big one, never off a small one
	function DC.fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		if not (DC.scale and vp and vp.X > 0 and vp.Y > 0) then
			return
		end
		local h = DC.root.Size.Y.Offset
		DC.scale.Scale = math.min(math.clamp(vp.Y / 720, 1, 1.5), (vp.X - 24) / W, (vp.Y - 24) / h)
	end

	-- spec: { Allowed, Invite (only when allowed), Words = Config.Discord's
	-- Allowed or Neutral, Mode = "Keyboard" / "Touch" / "Gamepad", Color }
	function HUD.ShowDiscord(spec)
		spec = type(spec) == "table" and spec or {}
		local root = DC.build()
		if not root then
			return
		end
		local allowed = spec.Allowed == true and type(spec.Invite) == "string" and spec.Invite ~= ""
		DC.words = type(spec.Words) == "table" and spec.Words or {}
		DC.mode = spec.Mode or "Keyboard"
		DC.invite = allowed and spec.Invite or ""
		local color = typeof(spec.Color) == "Color3" and spec.Color or BLURPLE
		DC.pill.BackgroundColor3 = color
		DC.badge.BackgroundColor3 = color
		DC.select.BackgroundColor3 = color
		DC.title.Text = DC.words.Title or ""
		DC.line.Text = DC.words.Line or ""
		DC.box.Text = DC.invite
		DC.row.Visible = allowed
		DC.hint.Visible = allowed
		DC.select.Visible = allowed and DC.mode ~= "Gamepad"
		root.Size = UDim2.fromOffset(W, allowed and TALL or SHORT)
		DC.hintFor(false)
		DC.fit()
		HUD.HideVendor()
		root.Visible = true
		DC.scale.Scale = DC.scale.Scale * 0.92
		tween(DC.scale, 0.16, { Scale = DC.scale.Scale / 0.92 }, Enum.EasingStyle.Back)
	end

	-- the device changed while it's open: the hint (and SELECT) follow
	function HUD.SetDiscordMode(mode)
		DC.mode = mode or DC.mode
		if DC.root and DC.root.Visible then
			DC.select.Visible = DC.invite ~= "" and DC.mode ~= "Gamepad"
			DC.hintFor(DC.box:IsFocused())
		end
	end

	function HUD.HideDiscord()
		if DC.root then
			if DC.box and DC.box:IsFocused() then
				DC.box:ReleaseFocus()
			end
			DC.root.Visible = false
		end
	end

	function HUD.DiscordVisible()
		return DC.root ~= nil and DC.root.Visible
	end

	function HUD.DiscordFirstButton()
		return DC.close
	end
end

---------------------------------------------------------------------------
-- (round 92) FLIGHTGRANT on the screen (Config.FlightGrant; QuirkClient's
-- DevFly.FG feeds it, the server's Kit.FG decides everything):
--   GIVE FLIGHT - the devs' test menu side panel (beside the menu, like
--     HERO ROSTER): everyone else in this server with a switch each - OFF |
--     SERVER | SAVED - and FULL POWER under it; then the saved grants of
--     those who aren't here (SERVER can't be picked for them). A dev shows a
--     DEV pill (he flies already). A click moves the switch at once, dimmed
--     till the server's word agrees (or back after Pending s), and the row
--     flashes when the server's word changes. The header: the sync chip (the
--     saved list: LIVE ON EVERY SERVER / SAVING... / THIS SERVER ONLY /
--     STUDIO SESSION ONLY / LOADING...) and the counts (FLYING here, SAVED,
--     FULL POWER); the footer: who changed it last, and TAKE BACK EVERY
--     GRANT (two clicks). cb = { State() -> { Rows, Sync, By, At },
--     Set(userId, "off" | "server" | "perm" | "full", full), TakeAll() }.
--   THE TOAST (HUD.FlightGrantToast) - the one given it (or whose it was
--     taken back) is told who, which kind, full power, and how to take off
--     on this device.
--   FLY (HUD.SetTouchFly) - a round button on a phone's pad for whoever
--     flies, lit while he does (Config.FlightGrant.Touch: its spot in
--     TOUCH.LAYOUT, from the jump button; put in as the pad's first built).
---------------------------------------------------------------------------
do
	local GP = {
		rows = {}, data = {}, pendKind = {}, pendFull = {}, drawn = {}, chips = {}, cb = {},
		fly = { show = false, on = false }, toastToken = 0,
	}
	HUD.FlightGrants = GP
	local W = 420
	local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local SKY = Color3.fromRGB(120, 205, 255)
	local GREEN = Color3.fromRGB(60, 200, 110)
	local GOLD = Color3.fromRGB(255, 212, 64)
	local AMBER = Color3.fromRGB(255, 166, 64)
	local RED = Color3.fromRGB(255, 92, 76)
	local DIM = Color3.fromRGB(150, 154, 180)
	local TRACK = Color3.fromRGB(18, 19, 28)
	local ROW = Color3.fromRGB(38, 40, 57)
	local OFF = Color3.fromRGB(92, 94, 116)
	local SYNC = {
		Live = { "LIVE ON EVERY SERVER", GREEN },
		Saving = { "SAVING...", GOLD },
		Local = { "THIS SERVER ONLY", AMBER },
		Studio = { "STUDIO SESSION ONLY", Color3.fromRGB(110, 190, 255) },
		Loading = { "LOADING...", DIM },
	}
	local SEGS = { "off", "server", "perm" }
	local SEG_TEXT = { off = "OFF", server = "SERVER", perm = "SAVED" }
	local SEG_COLOR = { off = OFF, server = GREEN, perm = SKY }
	local KIND = { Server = "server", Perm = "perm" }

	local function cfg()
		return (Config and Config.FlightGrant) or {}
	end
	local function hexOf(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	local function ago(t)
		local s = math.max(0, os.time() - (tonumber(t) or os.time()))
		if s < 60 then
			return "just now"
		elseif s < 3600 then
			return math.floor(s / 60) .. " min ago"
		elseif s < 86400 then
			return math.floor(s / 3600) .. " h ago"
		end
		return math.floor(s / 86400) .. " d ago"
	end
	-- a colour of his own from his name (the same on every screen)
	local function hueOf(name)
		local h = 0
		for i = 1, #name do
			h = (h * 31 + string.byte(name, i)) % 7919
		end
		return Color3.fromHSV((h % 360) / 360, 0.5, 0.86)
	end

	-- one player's row: his badge, name and line; the switch (OFF | SERVER |
	-- SAVED) and FULL POWER under it; or, for a dev, the DEV pill
	local function makeRow(id)
		local row = make("Frame", {
			Name = "Row_" .. tostring(id),
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = ROW,
			ZIndex = 22,
			Parent = GP.list,
		}, { corner(7) })
		local flash = make("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = row,
		}, { corner(7) })
		local stripe = make("Frame", {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -16),
			BackgroundColor3 = OFF,
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = row,
		}, { corner(2) })
		local avatar = make("Frame", {
			Name = "Avatar",
			Position = UDim2.fromOffset(11, 10),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = DIM,
			ZIndex = 23,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(150, 150, 150), 90) })
		local avEdge = make("UIStroke", { Thickness = 1.5, Color = WHITE, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = avatar })
		local ini = make("TextLabel", {
			Name = "Initials",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 12,
			TextColor3 = WHITE,
			Text = "?",
			ZIndex = 24,
			Parent = avatar,
		}, { textStroke(1) })
		local title = make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(50, 7),
			Size = UDim2.new(1, -238, 0, 18),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 23,
			Parent = row,
		}, { make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }) })
		local sub = make("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(50, 27),
			Size = UDim2.new(1, -176, 0, 14), -- (under the switch's row, up to FULL POWER)
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 23,
			Parent = row,
		})
		local sw = make("Frame", {
			Name = "Switch",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 6),
			Size = UDim2.fromOffset(168, 22),
			BackgroundColor3 = TRACK,
			ZIndex = 23,
			Parent = row,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local knob = make("Frame", {
			Name = "Knob",
			Position = UDim2.new(0, 2, 0, 2),
			Size = UDim2.new(1 / 3, -2, 1, -4),
			BackgroundColor3 = OFF,
			ZIndex = 24,
			Parent = sw,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(205, 205, 205), 90) })
		local segs = {}
		for i, k in SEGS do
			local b = make("TextButton", {
				Name = "Seg_" .. k,
				Position = UDim2.fromScale((i - 1) / 3, 0),
				Size = UDim2.fromScale(1 / 3, 1),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 10,
				TextColor3 = DIM,
				Text = SEG_TEXT[k],
				ZIndex = 25,
				Parent = sw,
			})
			segs[k] = b
			b.MouseButton1Click:Connect(function()
				GP.press(id, k)
			end)
		end
		local full = make("TextButton", {
			Name = "Full",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 31),
			Size = UDim2.fromOffset(112, 16),
			BackgroundColor3 = TRACK,
			AutoButtonColor = true,
			Text = "",
			ZIndex = 23,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local fullEdge = make("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = full })
		local ftrack = make("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(20, 10),
			BackgroundColor3 = Color3.fromRGB(70, 72, 92),
			ZIndex = 24,
			Parent = full,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local fknob = make("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 1, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = WHITE,
			ZIndex = 25,
			Parent = ftrack,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local flabel = make("TextLabel", {
			Name = "Label",
			Position = UDim2.fromOffset(29, 0),
			Size = UDim2.new(1, -33, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "FULL POWER",
			ZIndex = 24,
			Parent = full,
		})
		full.MouseButton1Click:Connect(function()
			GP.pressFull(id)
		end)
		local devPill = make("TextLabel", {
			Name = "DevPill",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(64, 20),
			BackgroundColor3 = GOLD,
			Font = HEAD_FONT,
			TextSize = 11,
			TextColor3 = BLACK,
			Text = "DEV",
			Visible = false,
			ZIndex = 24,
			Parent = row,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local r = {
			Row = row, Flash = flash, Stripe = stripe, Avatar = avatar, AvEdge = avEdge, Initials = ini, Title = title, Sub = sub,
			Switch = sw, Knob = knob, Segs = segs, Full = full, FullEdge = fullEdge, FullTrack = ftrack, FullKnob = fknob, FullLabel = flabel,
			DevPill = devPill,
		}
		GP.rows[id] = r
		return r
	end

	function HUD.BuildFlightGrantPanel(cb)
		GP.cb = cb or {}
		if GP.frame or not gui then
			return
		end
		local frame = make("Frame", {
			Name = "FlightGrants",
			Position = UDim2.new(0, 22 + TEST_W, 0, 108),
			Size = UDim2.fromOffset(W, 520),
			BackgroundColor3 = Color3.fromRGB(24, 24, 34),
			BackgroundTransparency = 0.04,
			Visible = false,
			ZIndex = 20,
			Parent = gui,
		}, { stroke(3), corner(8) })
		GP.frame = frame
		-- a little of the sky from the top
		make("Frame", {
			Name = "Glow",
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = SKY,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = frame,
		}, { corner(8), make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1) }) })
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(14, 5),
			Size = UDim2.new(1, -190, 0, 32),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 27,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SKY,
			Text = "GIVE FLIGHT",
			ZIndex = 21,
			Parent = frame,
		}, { textStroke(1.5) })
		GP.sync = make("Frame", {
			Name = "Sync",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(164, 22),
			BackgroundColor3 = TRACK,
			ZIndex = 21,
			Parent = frame,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		GP.syncEdge = make("UIStroke", { Thickness = 1, Color = DIM, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = GP.sync })
		GP.syncDot = make("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = DIM,
			ZIndex = 22,
			Parent = GP.sync,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		GP.syncText = make("TextLabel", {
			Name = "Text",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -28, 1, 0),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = "LOADING...",
			ZIndex = 22,
			Parent = GP.sync,
		}, { make("UITextSizeConstraint", { MaxTextSize = 10, MinTextSize = 7 }) })
		GP.sub = make("TextLabel", {
			Name = "Info",
			Position = UDim2.fromOffset(14, 37),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(190, 194, 220),
			Text = "The dev flight for anyone here: this server, or saved for good.",
			ZIndex = 21,
			Parent = frame,
		})
		-- the counts
		for i, def in { { "Flying", "FLYING", GREEN }, { "Saved", "SAVED", SKY }, { "Full", "FULL POWER", RED } } do
			local chip = make("Frame", {
				Name = def[1],
				Position = UDim2.fromOffset(14 + (i - 1) * 124, 58),
				Size = UDim2.fromOffset(116, 22),
				BackgroundColor3 = def[3]:Lerp(BLACK, 0.74),
				ZIndex = 21,
				Parent = frame,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 1, Color = def[3], Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			GP.chips[def[1]] = {
				Frame = chip,
				Word = def[2],
				Color = def[3],
				Label = make("TextLabel", {
					Name = "Text",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Font = UI_FONT,
					TextSize = 11,
					RichText = true,
					TextColor3 = WHITE,
					Text = def[2],
					ZIndex = 22,
					Parent = chip,
				}),
			}
		end
		GP.topLine = make("Frame", {
			Name = "Line",
			Position = UDim2.fromOffset(12, 88),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		GP.list = make("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(8, 94),
			Size = UDim2.new(1, -12, 1, -94 - 74),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = WHITE,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 21,
			Parent = frame,
		}, {
			make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }),
		})
		local function head(name, order)
			return make("TextLabel", {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SKY,
				Text = "",
				ZIndex = 22,
				Parent = GP.list,
			})
		end
		GP.headHere = head("HeadHere", 0)
		GP.empty = make("TextLabel", {
			Name = "Empty",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 12,
			TextColor3 = DIM,
			Text = "Nobody else is in this server yet",
			Visible = false,
			ZIndex = 22,
			Parent = GP.list,
		})
		GP.headAway = head("HeadAway", 5000)
		GP.footLine = make("Frame", {
			Name = "FootLine",
			Position = UDim2.new(0, 12, 1, -72),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = frame,
		})
		GP.info = make("TextLabel", {
			Name = "Last",
			Position = UDim2.new(0, 14, 1, -66),
			Size = UDim2.new(1, -28, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = DIM,
			Text = "",
			ZIndex = 21,
			Parent = frame,
		})
		GP.takeAll = make("TextButton", {
			Name = "TakeAll",
			Position = UDim2.new(0, 12, 1, -44),
			Size = UDim2.new(1, -24, 0, 32),
			BackgroundColor3 = Color3.fromRGB(170, 60, 60),
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = WHITE,
			Text = "TAKE BACK EVERY GRANT",
			ZIndex = 22,
			Parent = frame,
		}, { corner(6), stroke(1.5) })
		-- (two clicks: the first arms it for 3 s)
		GP.takeAll.MouseButton1Click:Connect(function()
			if not GP.canTake then
				return
			end
			if GP.armed and os.clock() - GP.armed < 3 then
				GP.armed = nil
				if GP.cb.TakeAll then
					GP.cb.TakeAll()
				end
			else
				GP.armed = os.clock()
				local at = GP.armed
				task.delay(3, function()
					if GP.armed == at then
						GP.armed = nil
						HUD.RefreshFlightGrantPanel()
					end
				end)
			end
			HUD.RefreshFlightGrantPanel()
		end)
		-- (a phone turned round, a window resized: it fits itself again)
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if GP.frame.Visible then
					GP.layout()
				end
			end)
		end
		HUD.RefreshFlightGrantPanel()
	end

	-- a click: the switch moves at once, dimmed till the server's word agrees
	function GP.press(id, kind)
		local d = GP.data[id]
		if not d or d.Dev or (kind == "server" and not d.Here) then
			return
		end
		local live = KIND[d.Kind or ""] or "off"
		local pend = GP.pendKind[id]
		if ((pend and pend.V) or live) == kind then
			return
		end
		local token = os.clock()
		GP.pendKind[id] = { V = kind, At = token }
		if kind == "off" then
			GP.pendFull[id] = nil
		end
		if GP.cb.Set then
			GP.cb.Set(id, kind, nil)
		end
		HUD.RefreshFlightGrantPanel()
		task.delay(cfg().Pending or 5, function()
			local p = GP.pendKind[id]
			if p and p.At == token then
				GP.pendKind[id] = nil -- (the server never agreed: back to how it is)
				HUD.RefreshFlightGrantPanel()
			end
		end)
	end
	-- FULL POWER on / off (only on a grant)
	function GP.pressFull(id)
		local d = GP.data[id]
		if not d or d.Dev then
			return
		end
		local pend = GP.pendKind[id]
		if ((pend and pend.V) or KIND[d.Kind or ""] or "off") == "off" then
			return -- (no flight to give full power to)
		end
		local pf = GP.pendFull[id]
		local cur
		if pf then
			cur = pf.V
		else
			cur = d.Full == true
		end
		local token = os.clock()
		GP.pendFull[id] = { V = not cur, At = token }
		if GP.cb.Set then
			GP.cb.Set(id, "full", not cur)
		end
		HUD.RefreshFlightGrantPanel()
		task.delay(cfg().Pending or 5, function()
			local p = GP.pendFull[id]
			if p and p.At == token then
				GP.pendFull[id] = nil
				HUD.RefreshFlightGrantPanel()
			end
		end)
	end

	-- fits the screen: on a short one (a phone) it starts just under the top
	-- bar, and the header and footer shrink (HERO ROSTER's way)
	function GP.layout()
		local cam = workspace.CurrentCamera
		local vpY = (cam and cam.ViewportSize.Y) or 720
		local y0 = vpY < 500 and 52 or 108
		local h = math.clamp(vpY - y0 - 12, 200, 540)
		local compact = h < 340
		GP.frame.Position = UDim2.new(0, 22 + TEST_W, 0, y0)
		GP.frame.Size = UDim2.fromOffset(W, h)
		GP.sub.Visible = not compact
		GP.info.Visible = not compact
		local chipY = compact and 38 or 58
		for _, chip in GP.chips do
			chip.Frame.Position = UDim2.fromOffset(chip.Frame.Position.X.Offset, chipY)
		end
		local top, bottom = chipY + 36, compact and 50 or 74
		GP.topLine.Position = UDim2.fromOffset(12, top - 6)
		GP.list.Position = UDim2.fromOffset(8, top)
		GP.list.Size = UDim2.new(1, -12, 1, -top - bottom)
		GP.footLine.Position = UDim2.new(0, 12, 1, -bottom + 2)
	end

	-- one row drawn from what the server says (and a click on its way)
	function GP.draw(d, order, counts)
		local id = d.UserId
		local r = GP.rows[id] or makeRow(id)
		r.Row.LayoutOrder = order
		local live = KIND[d.Kind or ""] or "off"
		local pk = GP.pendKind[id]
		if pk and pk.V == live then
			GP.pendKind[id] = nil
			pk = nil
		end
		local pf = GP.pendFull[id]
		if pf and pf.V == (d.Full == true) then
			GP.pendFull[id] = nil
			pf = nil
		end
		local kind = (pk and pk.V) or live
		local full
		if pf then
			full = pf.V
		else
			full = d.Full == true
		end
		full = full and kind ~= "off"
		if not d.Dev and live ~= "off" then
			counts.Any += 1
			if d.Here then
				counts.Flying += 1
			end
			if d.Full == true then
				counts.Full += 1
			end
		end
		if live == "perm" then
			counts.Saved += 1
		end
		local shown = tostring(d.Display or d.Name or id)
		local hue = hueOf(tostring(d.Name or shown))
		r.Title.Text = shown
		r.Initials.Text = initials(shown)
		r.Avatar.BackgroundColor3 = hue
		r.AvEdge.Color = hue:Lerp(WHITE, 0.5)
		r.Stripe.BackgroundColor3 = d.Dev and GOLD or SEG_COLOR[kind]
		r.Stripe.Visible = d.Dev == true or kind ~= "off"
		local who = (type(d.By) == "string" and d.By ~= "") and (" · by " .. d.By .. (tonumber(d.At) and (", " .. ago(d.At)) or "")) or ""
		if d.Dev then
			r.Sub.Text = "@" .. tostring(d.Name) .. " · a dev: flies already"
			r.Sub.TextColor3 = GOLD:Lerp(DIM, 0.3)
		elseif live == "perm" then
			r.Sub.Text = (d.Here and "SAVED" or "SAVED · not here") .. who
			r.Sub.TextColor3 = SKY
		elseif live == "server" then
			r.Sub.Text = "THIS SERVER" .. who
			r.Sub.TextColor3 = Color3.fromRGB(130, 236, 160)
		else
			r.Sub.Text = "@" .. tostring(d.Name) .. " · can't fly"
			r.Sub.TextColor3 = DIM
		end
		r.Switch.Visible = not d.Dev
		r.Full.Visible = not d.Dev
		r.DevPill.Visible = d.Dev == true
		local i = kind == "server" and 1 or kind == "perm" and 2 or 0
		tween(r.Knob, 0.2, {
			Position = UDim2.new(i / 3, i == 0 and 2 or (i == 1 and 1 or 0), 0, 2),
			BackgroundColor3 = SEG_COLOR[kind],
			BackgroundTransparency = pk and 0.5 or 0,
		}, Enum.EasingStyle.Quint)
		for k, b in r.Segs do
			local can = not (k == "server" and not d.Here)
			b.TextColor3 = (k == kind) and (k == "off" and WHITE or BLACK) or DIM
			b.TextTransparency = can and 0 or 0.65
			b.AutoButtonColor = can
		end
		local canFull = kind ~= "off"
		r.Full.BackgroundColor3 = full and RED:Lerp(BLACK, 0.55) or TRACK
		r.FullEdge.Color = full and RED or WHITE
		r.FullEdge.Transparency = full and 0.3 or 0.86
		r.FullTrack.BackgroundColor3 = full and RED or Color3.fromRGB(70, 72, 92)
		r.FullKnob.Position = full and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 1, 0.5, 0)
		r.FullLabel.TextColor3 = full and WHITE or DIM
		r.FullLabel.TextTransparency = canFull and (pf and 0.4 or 0) or 0.6
		r.Full.AutoButtonColor = canFull
		-- the server's word changed (here or anywhere): a flash across the row
		local key = live .. ((d.Full == true) and "+" or "")
		if GP.drawn[id] ~= nil and GP.drawn[id] ~= key then
			r.Flash.BackgroundColor3 = SEG_COLOR[live] == OFF and AMBER or SEG_COLOR[live]
			r.Flash.BackgroundTransparency = 0.55
			tween(r.Flash, 0.7, { BackgroundTransparency = 1 })
		end
		GP.drawn[id] = key
	end

	-- re-read who's here and the server's word
	function HUD.RefreshFlightGrantPanel()
		if not GP.frame then
			return
		end
		local st = (GP.cb.State and GP.cb.State()) or {}
		local here, away, data = {}, {}, {}
		for _, d in type(st.Rows) == "table" and st.Rows or {} do
			if type(d) == "table" and tonumber(d.UserId) then
				data[d.UserId] = d
				table.insert(d.Here and here or away, d)
			end
		end
		GP.data = data
		-- (here: by name, the devs last; saved but not here: the newest first)
		table.sort(here, function(a, b)
			if (a.Dev == true) ~= (b.Dev == true) then
				return not a.Dev
			end
			return string.lower(tostring(a.Display or a.Name)) < string.lower(tostring(b.Display or b.Name))
		end)
		table.sort(away, function(a, b)
			return (tonumber(a.At) or 0) > (tonumber(b.At) or 0)
		end)
		for id, r in GP.rows do
			if not data[id] then
				r.Row:Destroy()
				GP.rows[id], GP.drawn[id], GP.pendKind[id], GP.pendFull[id] = nil, nil, nil, nil
			end
		end
		local counts = { Flying = 0, Saved = 0, Full = 0, Any = 0 }
		for i, d in here do
			GP.draw(d, i + 1, counts)
		end
		for i, d in away do
			GP.draw(d, 5000 + i, counts)
		end
		GP.headHere.Text = "IN THIS SERVER  ·  " .. #here
		GP.empty.Visible = #here == 0
		GP.headAway.Visible = #away > 0
		GP.headAway.Text = "SAVED  ·  NOT HERE  ·  " .. #away
		for key, chip in GP.chips do
			chip.Label.Text = string.format('<font color="%s"><b>%d</b></font>  %s', hexOf(chip.Color:Lerp(WHITE, 0.2)), counts[key] or 0, chip.Word)
		end
		local sync = SYNC[st.Sync or "Loading"] or SYNC.Loading
		GP.syncText.Text = sync[1]
		GP.syncDot.BackgroundColor3 = sync[2]
		GP.syncEdge.Color = sync[2]
		if st.Sync == "Local" then
			GP.info.Text = "Saved grants not saved yet: this server only (the store isn't answering)"
			GP.info.TextColor3 = AMBER
		elseif st.Sync == "Studio" then
			GP.info.Text = "Studio: saved grants stay in this session (StudioSaves is off)"
			GP.info.TextColor3 = SYNC.Studio[2]
		elseif st.By and tonumber(st.At) then
			GP.info.Text = string.format("Last change: %s, %s", tostring(st.By), ago(st.At))
			GP.info.TextColor3 = DIM
		else
			GP.info.Text = "Nobody has it yet: pick SERVER or SAVED on someone"
			GP.info.TextColor3 = DIM
		end
		GP.canTake = counts.Any > 0
		local armed = GP.armed ~= nil and GP.canTake
		GP.takeAll.AutoButtonColor = GP.canTake
		GP.takeAll.BackgroundColor3 = armed and Color3.fromRGB(226, 92, 48) or GP.canTake and Color3.fromRGB(170, 60, 60) or Color3.fromRGB(58, 60, 78)
		GP.takeAll.TextColor3 = GP.canTake and WHITE or DIM
		GP.takeAll.Text = armed and string.format("SURE? CLICK AGAIN: %d GRANT%s GO", counts.Any, counts.Any == 1 and "" or "S")
			or GP.canTake and "TAKE BACK EVERY GRANT" or "NOBODY HAS A GRANT"
	end

	function HUD.ToggleFlightGrantPanel(force)
		local frame = GP.frame
		if not frame then
			return false
		end
		if force ~= nil then
			frame.Visible = force
		else
			frame.Visible = not frame.Visible
		end
		if frame.Visible then
			GP.layout()
			HUD.RefreshFlightGrantPanel()
		end
		return frame.Visible
	end

	-- THE TOAST: the one given it (or whose it was taken back). info = {
	-- Event = Granted / Changed / Revoked / Join, By, Kind, Full, WasKind,
	-- WasFull, Flying, Hint }
	function HUD.FlightGrantToast(info)
		if not gui or type(info) ~= "table" then
			return nil
		end
		local T = cfg().Toast or {}
		GP.toastToken += 1
		local token = GP.toastToken
		local old = gui:FindFirstChild("FlightGrantToast")
		if old then
			old:Destroy()
		end
		local ev = info.Event
		local by = (type(info.By) == "string" and info.By ~= "") and info.By or "A dev"
		local perm = info.Kind == "Perm"
		local col, title, line, tag, tagCol, hint
		if ev == "Revoked" then
			col, title, tag, tagCol = AMBER, "FLIGHT TAKEN BACK", "TAKEN BACK", AMBER
			line = by .. " took the dev flight back" .. (info.Flying and " - down you go" or "")
		else
			col = info.Full and RED or SKY
			tag, tagCol = perm and "SAVED · EVERY SERVER" or "THIS SERVER", perm and SKY or GREEN
			if ev == "Join" then
				title, line, hint = "READY TO FLY", "Your saved dev flight, from " .. by, info.Hint
			elseif ev == "Changed" and info.Full and not info.WasFull then
				title, line = "FULL POWER!", by .. ": bombs, all the way down, the shield"
			elseif ev == "Changed" and info.WasFull and not info.Full then
				title, line = "FULL POWER OFF", by .. ": flight and the carry - no bombs" -- ((round 92 review) the holes and the crater are still the flight's)
			elseif ev == "Changed" and perm then
				title, line = "SAVED FOR GOOD", by .. " saved it: every server, every visit"
			elseif ev == "Changed" then
				title, line = "THIS SERVER ONLY", by .. " made it this server's only"
			else
				title, hint = "YOU CAN FLY!", info.Hint
				line = by .. " gave you the dev flight" -- (FULL POWER has its own tag)
			end
		end
		local hasHint = type(hint) == "string" and hint ~= ""
		local h = hasHint and 114 or 88
		-- (on a phone: left of the move buttons, under the top bar)
		local touchOn = HUD.Touch ~= nil and HUD.Touch.on == true
		local x = touchOn and (T.TouchX or 0.4) or 0.5
		local y = touchOn and (T.TouchY or 56) or (T.Y or 64)
		local holder = make("Frame", {
			Name = "FlightGrantToast",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(x, 0, 0, y - 14),
			Size = UDim2.fromOffset(420, h),
			BackgroundTransparency = 1,
			ZIndex = 62,
			Parent = gui,
		})
		-- (its own scale, the screen's as it comes up - not an autoScale: it's
		-- gone in seconds, and a destroyed one would sit in that shared list)
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		make("UIScale", {
			Name = "Fit",
			Scale = touchOn and (T.TouchScale or 0.8) or ((vp and vp.Y > 0) and math.clamp(vp.Y / 720, 0.75, 1.5) or 1),
			Parent = holder,
		})
		local card = make("Frame", {
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = GLASS.Color,
			BackgroundTransparency = 0.08,
			ClipsDescendants = true,
			ZIndex = 62,
			Parent = holder,
		}, { corner(10), make("UIScale", { Name = "Pop", Scale = 0.86 }) })
		make("UIStroke", { Name = "Edge", Thickness = 1.5, Color = col, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		make("Frame", {
			Name = "Glow",
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = col,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			ZIndex = 62,
			Parent = card,
		}, { make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) }) })
		make("Frame", {
			Name = "Accent",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 1, -20),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			ZIndex = 63,
			Parent = card,
		}, { corner(2) })
		-- the badge: two chevrons, up (given) or down (taken back)
		local icon = make("Frame", {
			Name = "Icon",
			Position = UDim2.fromOffset(16, 16),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = col,
			ZIndex = 63,
			Parent = card,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			gradient(WHITE, Color3.fromRGB(140, 140, 140), 90),
			make("UIStroke", { Thickness = 2, Color = col:Lerp(WHITE, 0.55), Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local down = ev == "Revoked"
		for n, cy in { 21, 31 } do
			for _, side in { -1, 1 } do
				make("Frame", {
					Name = "Chevron" .. n,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(27 + side * 5, down and (54 - cy) or cy),
					Size = UDim2.fromOffset(16, 4),
					Rotation = (down and -1 or 1) * side * 45, -- (up: / \ ; down: \ /)
					BackgroundColor3 = WHITE,
					BackgroundTransparency = n == 1 and 0 or 0.35,
					BorderSizePixel = 0,
					ZIndex = 64,
					Parent = icon,
				}, { corner(2) })
			end
		end
		make("TextLabel", {
			Name = "Kicker",
			Position = UDim2.fromOffset(86, 11),
			Size = UDim2.fromOffset(120, 14),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = col,
			Text = "DEV FLIGHT",
			ZIndex = 63,
			Parent = card,
		})
		local tagW = 18 + #tag * 6
		local tagF = make("Frame", {
			Name = "Tag",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(tagW, 18),
			BackgroundColor3 = tagCol:Lerp(BLACK, 0.7),
			ZIndex = 63,
			Parent = card,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Thickness = 1, Color = tagCol, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		make("TextLabel", {
			Name = "TagText",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = UI_FONT,
			TextSize = 10,
			TextColor3 = tagCol:Lerp(WHITE, 0.35),
			Text = tag,
			ZIndex = 64,
			Parent = tagF,
		})
		if info.Full and ev ~= "Revoked" then
			local fullF = make("Frame", {
				Name = "FullTag",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -18 - tagW, 0, 10),
				Size = UDim2.fromOffset(84, 18),
				BackgroundColor3 = RED:Lerp(BLACK, 0.6),
				ZIndex = 63,
				Parent = card,
			}, {
				make("UICorner", { CornerRadius = UDim.new(1, 0) }),
				make("UIStroke", { Thickness = 1, Color = RED, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			make("TextLabel", {
				Name = "FullText",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = UI_FONT,
				TextSize = 10,
				TextColor3 = RED:Lerp(WHITE, 0.4),
				Text = "FULL POWER",
				ZIndex = 64,
				Parent = fullF,
			})
		end
		make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(86, 25),
			Size = UDim2.new(1, -98, 0, 34),
			BackgroundTransparency = 1,
			Font = COMIC_FONT,
			TextSize = 31,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Text = title,
			ZIndex = 63,
			Parent = card,
		}, { textStroke(1.5) })
		make("TextLabel", {
			Name = "Line",
			Position = UDim2.fromOffset(86, 60),
			Size = UDim2.new(1, -98, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(205, 209, 230),
			Text = line,
			ZIndex = 63,
			Parent = card,
		}, { make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9 }) })
		if hasHint then
			local pillF = make("Frame", {
				Name = "Hint",
				Position = UDim2.fromOffset(86, 82),
				Size = UDim2.fromOffset(212, 22),
				BackgroundColor3 = col,
				ZIndex = 63,
				Parent = card,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(WHITE, Color3.fromRGB(205, 205, 205), 90) })
			make("TextLabel", {
				Name = "HintText",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = HEAD_FONT,
				TextSize = 12,
				TextColor3 = BLACK,
				Text = hint,
				ZIndex = 64,
				Parent = pillF,
			})
		end
		-- a glint across it
		local glint = make("Frame", {
			Name = "Glint",
			Position = UDim2.new(0, -90, 0, -20),
			Size = UDim2.new(0, 46, 1, 40),
			Rotation = 18,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = 65,
			Parent = card,
		}, { make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
		-- in: down into place with a pop, the glint across; held; out: up and away
		tween(holder, 0.34, { Position = UDim2.new(x, 0, 0, y) }, Enum.EasingStyle.Back)
		tween(card.Pop, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.18, function()
			if glint.Parent then
				tween(glint, 0.55, { Position = UDim2.new(1, 40, 0, -20) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			end
		end)
		task.delay(T.Hold or 4.6, function()
			if GP.toastToken ~= token or not holder.Parent then
				return
			end
			for _, dsc in holder:GetDescendants() do
				if dsc:IsA("TextLabel") then
					tween(dsc, 0.4, { TextTransparency = 1 })
				elseif dsc:IsA("Frame") then
					tween(dsc, 0.4, { BackgroundTransparency = 1 })
				elseif dsc:IsA("UIStroke") then
					tween(dsc, 0.4, { Transparency = 1 })
				end
			end
			tween(holder, 0.4, { Position = UDim2.new(x, 0, 0, y - 12) })
			task.wait(0.45)
			if holder.Parent then
				holder:Destroy()
			end
		end)
		return holder
	end

	-- FLY on a phone's pad: shown to whoever flies, lit while he does
	function HUD.SetTouchFly(show, on)
		GP.fly.show, GP.fly.on = show == true, on == true
		local T = HUD.Touch
		local b = T and T.buttons and T.buttons.QuirkDevFly
		if b then
			b.Visible = GP.fly.show
			b.BackgroundColor3 = GP.fly.on and SKY:Lerp(BLACK, 0.2) or GLASS.Color
			b.TextColor3 = GP.fly.on and BLACK or WHITE
		end
	end
	-- (its spot goes in the pad's layout before the pad's first built - the
	-- pad makes the button, places it and wires the finger to it; then it's
	-- shown or hidden for who flies)
	do
		local apply = HUD.ApplyTouch
		if apply then
			HUD.ApplyTouch = function(on)
				local T = HUD.Touch
				if T and T.LAYOUT and not GP.flyIn then
					GP.flyIn = true
					local c = cfg().Touch or {}
					table.insert(T.LAYOUT, { "QuirkDevFly", "FLY", c.X or -310, c.Y or -140, c.Size or 40 })
				end
				-- (shown or hidden whatever happens in there: the pad makes it visible)
				local ok, err = pcall(apply, on)
				HUD.SetTouchFly(GP.fly.show, GP.fly.on)
				if not ok then
					error(err, 0)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- (round 92) hawksair - HAWKS' FLYING BAR (Config.Quirks.FierceWings.Alt).
-- Flying, his bar is his alt form's (HUD.SetQuirk draws it from
-- Config.GetView: ON THE WING, RAZOR STRAFE / PEREGRINE STOOP / GALE BEAT /
-- FEATHER DRILL with their own cooldowns); on top of that, here: each of
-- those boxes gets the sky's colour along its top and a small AIR tag (so
-- the switch reads at a glance), and R says LAND. Holding someone on his
-- feathers (HUD.HawksCarry(info)): the boxes are the carry's follow-ups -
-- SKY TOSS, FEATHER FLURRY, GALE THROW, LET GO - gold, tagged CARRY, no
-- cooldown on them (one a carry), and a chip over the health bar says
-- CARRYING <who> with the time left draining (the dev carry's chip, its
-- look and place). The phone's buttons are these same boxes' names. Back on
-- his feet HUD.SetQuirk writes his own bar again and this leaves it be.
---------------------------------------------------------------------------
do
	local HB = { carry = nil, tags = {} }
	HUD.HawksAirHud = HB
	local SKY = Color3.fromRGB(150, 212, 255)
	local GOLD = Color3.fromRGB(255, 196, 92)
	-- the little tag in a box's top-right corner (made once a box)
	function HB.tag(slot)
		local t = HB.tags[slot]
		if t and t.Parent then
			return t
		end
		if not (slot and slot.Frame) then
			return nil
		end
		t = make("TextLabel", {
			Name = "HawksTag",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 6),
			Size = UDim2.fromOffset(44, 12),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = SKY,
			Text = "AIR",
			Visible = false,
			ZIndex = 3,
			Parent = slot.Frame,
		})
		HB.tags[slot] = t
		return t
	end
	-- HUD.SetQuirk's last word: Hawks' flying bar / carry on top of his alt view
	function HUD.HawksBar(quirkName, alt, ult)
		HB.last = { quirkName, alt, ult }
		local q = Config and Config.Quirks and Config.Quirks.FierceWings
		local A = q and q.Alt
		local flying = quirkName == "FierceWings" and alt == true and not ult and A ~= nil
		-- (round 92 review) from the hook on, not only once he's up: 1-4 ARE
		-- the follow-ups from the moment the server says he holds someone
		-- (HawksFly.follow / Kit.HA.route don't wait for his lift-off) - the
		-- bar named his ground moves until the lift-off came back, and up to
		-- LiftWait if his flight never came up
		local carrying = quirkName == "FierceWings" and not ult and A ~= nil and HB.carry ~= nil
		local boxes = { slots[1], slots[2], slots[3], slots[6] }
		-- (a phone's round buttons: the names alone - a tag over them would read as part of the name)
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		for i, slot in boxes do
			local tag = slot and HB.tag(slot)
			if tag then
				tag.Visible = (flying or carrying) and not touch
				tag.Text = carrying and "CARRY" or "AIR"
				tag.TextColor3 = carrying and GOLD or SKY
			end
			if slot and (flying or carrying) then
				slot.Accent.BackgroundColor3 = carrying and GOLD or SKY
				if carrying then
					local m = A.Carry and A.Carry.Moves and A.Carry.Moves[i]
					slot.Name.Text = m and m.Name or "—"
					slot.BoundKey = nil -- (ready, all of them: one follow-up a carry)
					slot.Frame.BackgroundColor3 = GLASS.Color:Lerp(GOLD, 0.16)
				end
			end
		end
		-- R: LAND up there; on his feet his wings' own name (the alt-form view
		-- would name the form R switches to: ON THE WING)
		if quirkName == "FierceWings" and not ult and A and specialSlot and specialSlot.Frame.Visible then
			specialSlot.Name.Text = flying and (A.LandName or "LAND") or (q.Special and q.Special.Name or specialSlot.Name.Text)
		end
		HB.chip(carrying and HB.carry or nil)
	end
	-- (the client says who's on his feathers, and when he lets go; then it
	-- has HUD.SetQuirk draw the bar again - this rides on that)
	function HUD.HawksCarry(info)
		HB.carry = info
		if not info then
			HB.chip(nil)
		end
	end
	-- (a phone switched on or off: the tags follow - HUD.ApplyTouch moves the
	-- boxes, this puts them right on top)
	local applyTouch = HUD.ApplyTouch
	if applyTouch then
		function HUD.ApplyTouch(on)
			applyTouch(on)
			if HB.last then
				HUD.HawksBar(HB.last[1], HB.last[2], HB.last[3])
			end
		end
	end
	-- CARRYING <who>, the time left draining under it
	function HB.chip(info)
		local CH = HUD.CarryHud
		local chip = HB.chipFrame
		if info and not (chip and chip.Parent) and CH and CH.pill then
			chip = CH.pill("HawksCarryChip", "CARRYING", GOLD)
			HB.chipFrame = chip
		end
		if not chip then
			return
		end
		HB.info = info
		chip.Visible = info ~= nil
		if not info then
			if HB.conn then
				HB.conn:Disconnect()
				HB.conn = nil
			end
			return
		end
		local who = string.upper(tostring(info.Name or ""))
		chip.Who.Text = who
		local width = (CH and CH.width) or function(text, size)
			return #text * size * 0.72
		end
		local kick = math.ceil(width("CARRYING", 11, HEAD_FONT)) + 10
		chip.Kicker.Size = UDim2.new(0, kick, 1, -3)
		chip.Who.Position = UDim2.fromOffset(14 + kick, 0)
		chip.Size = UDim2.fromOffset(math.clamp(math.ceil(14 + kick + width(who, 14, HEAD_FONT) + 16 + 70), 240, 460), 26)
		chip.Who.Size = UDim2.new(1, -(14 + kick + 76), 1, -3)
		HB.tick()
		if not HB.conn then
			HB.conn = RunService.RenderStepped:Connect(function()
				local ok, err = pcall(HB.tick)
				if not ok then
					warn("[HUD] hawks carry: " .. tostring(err))
				end
			end)
		end
	end
	function HB.tick()
		local chip, info = HB.chipFrame, HB.info
		if not (chip and chip.Visible and info) then
			return
		end
		if HUD.CarryHud and HUD.CarryHud.lift then
			HUD.CarryHud.lift(chip)
		end
		local has = type(info.Ends) == "number"
		chip.Time.Visible = has
		chip.Left.Visible = has
		if has then
			local left = math.max(info.Ends - workspace:GetServerTimeNow(), 0)
			chip.Time.Size = UDim2.new(math.clamp(left / math.max(info.Max or 3.5, 0.1), 0, 1), 0, 0, 3)
			chip.Left.Text = string.format("%.1fs", left)
			chip.Time.BackgroundColor3 = (left < 1 and (os.clock() * 6) % 1 < 0.5) and Color3.fromRGB(255, 90, 80) or GOLD
		end
	end
end

---------------------------------------------------------------------------
-- (round 90) DEVFLY2 - LIGHTSPEED and the hover-lock on his screen
-- (Config.DevFlight.Light / Control.Lock; QuirkClient's DevFly drives it).
-- Over the world and under the HUD (the overlay):
--   THE TUNNEL - the edges darkening in toward the middle as the light
--     barrier charges, and while he's at LIGHTSPEED;
--   THE SPLIT - a red edge and a cyan edge inset from it round the screen:
--     the colours coming apart at the edge of the lens;
--   THE CHARGE - a thin ring closing in on the middle as it fills.
-- HUD.LightBreak: the break - the ring blown out, the split rings racing to
-- the edges (red ahead, cyan behind). HUD.LightOut: a ring let go. And the
-- hover-lock's sight in the middle (HUD.FlightReticle). Built the first time
-- it's wanted; HUD.FlightLight(nil) hides it.
---------------------------------------------------------------------------
do
	local LH = {
		NAVY = Color3.fromRGB(6, 8, 22), RED = Color3.fromRGB(255, 70, 130), CYAN = Color3.fromRGB(70, 210, 255),
		MINT = Color3.fromRGB(120, 255, 200), token = 0,
	}
	HUD.FlightLightParts = LH

	function LH.ring(parent, color, size, thickness, transp)
		return make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(size, size),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Parent = parent,
		}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), make("UIStroke", { Color = color, Thickness = thickness, Transparency = transp }) })
	end

	function LH.build()
		if LH.root and LH.root.Parent then
			return
		end
		local root = make("Frame", {
			Name = "FlightLight",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = overlayGui,
		})
		-- the tunnel: four edges, dark at the rim, clear toward the middle
		LH.edges = {}
		for i, spec in {
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), 90 },
			{ UDim2.fromScale(0, 0.7), UDim2.fromScale(1, 0.3), -90 },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.24, 1), 0 },
			{ UDim2.fromScale(0.76, 0), UDim2.fromScale(0.24, 1), 180 },
		} do
			LH.edges[i] = make("Frame", {
				Name = "Tunnel",
				Position = spec[1],
				Size = spec[2],
				BackgroundColor3 = LH.NAVY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			}, { make("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.65), NumberSequenceKeypoint.new(1, 1) }) }) })
		end
		-- the split: the colours coming apart at the edge of the lens - red
		-- bleeding in off the left and the top, cyan off the right and the
		-- bottom, each fading inward
		LH.split = {}
		for i, spec in {
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.05, 1), 0, LH.RED },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.07), 90, LH.RED },
			{ UDim2.fromScale(0.95, 0), UDim2.fromScale(0.05, 1), 180, LH.CYAN },
			{ UDim2.fromScale(0, 0.93), UDim2.fromScale(1, 0.07), -90, LH.CYAN },
		} do
			LH.split[i] = make("Frame", {
				Name = "Split",
				Position = spec[1],
				Size = spec[2],
				BackgroundColor3 = spec[4],
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			}, { make("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
		end
		-- the charge's ring
		LH.charge = LH.ring(root, Color3.fromRGB(214, 236, 255), 0.95, 2, 1)
		LH.root = root
	end

	-- info: { K = LIGHTSPEED 0..1, Charge = the light barrier's 0..1 }; nil hides it
	function HUD.FlightLight(info)
		if not info then
			if LH.root then
				LH.root.Visible = false
			end
			return
		end
		LH.build()
		local k = math.clamp(tonumber(info.K) or 0, 0, 1)
		local c = math.clamp(tonumber(info.Charge) or 0, 0, 1)
		local t = os.clock()
		LH.root.Visible = true
		local dark = math.max(0.55 * k, 0.42 * c)
		for _, e in LH.edges do
			e.BackgroundTransparency = 1 - dark
		end
		local pulse = 0.5 + 0.5 * math.sin(t * 9)
		local split = math.clamp((0.3 + 0.06 * pulse) * k + 0.1 * c, 0, 0.4)
		for _, sp in LH.split do
			sp.BackgroundTransparency = 1 - split
		end
		local ring = LH.charge
		local stroke = ring:FindFirstChildOfClass("UIStroke")
		if c > 0 and k <= 0 then
			local s = 0.95 + (0.14 - 0.95) * c ^ 0.8
			ring.Size = UDim2.fromScale(s, s)
			stroke.Thickness = 1.5 + 2.5 * c
			stroke.Transparency = 0.62 - 0.34 * c
			stroke.Color = Color3.fromRGB(214, 236, 255):Lerp(LH.CYAN, c)
		else
			stroke.Transparency = 1
		end
	end

	-- THE BREAK on his screen: the charge's ring blown out, then three rings
	-- racing out to the edges - red a beat ahead, white, cyan behind
	function HUD.LightBreak()
		LH.build()
		LH.token += 1
		local holder = make("Frame", {
			Name = "LightBreak",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = overlayGui,
		})
		for i, spec in { { LH.RED, 0, 1.75 }, { Color3.new(1, 1, 1), 0.03, 1.6 }, { LH.CYAN, 0.06, 1.45 } } do
			local ring = LH.ring(holder, spec[1], 0.12, 10 - i * 2, 0.15)
			task.delay(spec[2], function()
				tween(ring, 0.45, { Size = UDim2.fromScale(spec[3], spec[3]) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				local st = ring:FindFirstChildOfClass("UIStroke")
				if st then
					tween(st, 0.45, { Transparency = 1, Thickness = 2 })
				end
			end)
		end
		local blown = LH.ring(holder, Color3.fromRGB(214, 236, 255), 0.14, 4, 0)
		tween(blown, 0.2, { Size = UDim2.fromScale(0.6, 0.6) })
		local bs = blown:FindFirstChildOfClass("UIStroke")
		if bs then
			tween(bs, 0.2, { Transparency = 1 })
		end
		task.delay(0.6, function()
			holder:Destroy()
		end)
	end
	-- out of LIGHTSPEED: one faint ring let go outward
	function HUD.LightOut()
		local holder = make("Frame", {
			Name = "LightOut",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = overlayGui,
		})
		local ring = LH.ring(holder, LH.CYAN, 0.5, 3, 0.45)
		tween(ring, 0.35, { Size = UDim2.fromScale(1.4, 1.4) })
		local st = ring:FindFirstChildOfClass("UIStroke")
		if st then
			tween(st, 0.35, { Transparency = 1 })
		end
		task.delay(0.45, function()
			holder:Destroy()
		end)
	end

	-- THE HOVER-LOCK's sight: a thin ring, a dot and four ticks in the middle
	function HUD.FlightReticle(on)
		if not on then
			if LH.reticle then
				LH.reticle.Visible = false
			end
			return
		end
		if not LH.reticle then
			local r = make("Frame", {
				Name = "FlightReticle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 1,
				ZIndex = 0,
				Parent = gui,
			})
			LH.ring(r, LH.MINT, 1, 1.5, 0.25).SizeConstraint = Enum.SizeConstraint.RelativeXY
			make("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = LH.MINT,
				BorderSizePixel = 0,
				Parent = r,
			}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			for _, spec in { { 0.5, -0.32, 2, 7 }, { 0.5, 1.32, 2, 7 }, { -0.32, 0.5, 7, 2 }, { 1.32, 0.5, 7, 2 } } do
				make("Frame", {
					Name = "Tick",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(spec[1], spec[2]),
					Size = UDim2.fromOffset(spec[3], spec[4]),
					BackgroundColor3 = LH.MINT,
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					Parent = r,
				})
			end
			LH.reticle = r
		end
		LH.reticle.Visible = true
	end
end

return HUD
