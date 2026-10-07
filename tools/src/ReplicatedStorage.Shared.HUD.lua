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
		-- ((round 101) the one rule, so the size knob: the card table. (review) On
		-- touch what TOUCH.place gives it: a phone's own rule made it 980 wide on
		-- an 812 screen)
		local touch = HUD.Touch and HUD.Touch.on and HUD.TouchScale
		sc.Scale = touch and HUD.TouchScale() or HUD.ST.scale()
	end
	return sc
end

---------------------------------------------------------------------------
-- (round 100) STARK STREET KIT. The building blocks every surface is made of
-- (the spec: r99/ui/street/spec.md; the tokens: Config.UI). Two colours and
-- one lean: ink and paper, every container a parallelogram leaning 12 degrees
-- forward, and the one colour on screen your hero's brush slash.
--   type     ST.font / ST.label / ST.shadowText / ST.numerals / ST.measure
--   shapes   ST.slab / ST.fill / ST.hatch / ST.segments / ST.slash
--   controls ST.keyCap / ST.note / ST.closeX / ST.switch / ST.slider /
--            ST.tabs / ST.button / ST.scrollbar / ST.gear / ST.panel
--   screen   ST.screen / ST.rootOf / ST.scale / ST.isPhone / ST.onLayout,
--            ST.toast, ST.moment, ST.mono, ST.lane, ST.combat
--   motion   ST.tween / ST.slideIn / ST.slideOut / ST.stamp / ST.flash
-- Sizes are em px at 1280x720 (the spec's numbers); a UIScale per ScreenGui
-- does the rest. How it all looks offline: tools/ui (the GUI renderer).
-- Every shape is built so it doesn't depend on how Roblox maps a rotated
-- UIGradient onto a non-square frame: a slanted end is a SQUARE frame whose
-- gradient's hard stop sits on its centre (the same both ways), and a moving
-- edge is a ClipsDescendants frame plus such a square. Nothing is rotated
-- under a clip. No UICorner, no UIStroke, no glow loops.
---------------------------------------------------------------------------
local ST = { roots = {}, layouts = {}, toastQ = {}, toastLog = {}, momentQ = {}, monoHolds = {}, combatHolds = {} }
HUD.ST = ST
do
	local Lighting = game:GetService("Lighting")
	local fontCache = {}
	local seq = 0

	-- (the game's Config once HUD.Init has run; before that - a command bar, a
	-- tool - QuirkConfig itself, so the kit works on its own too)
	local function cfg()
		if Config then
			return Config
		end
		if not ST.config then
			local ok, c = pcall(function()
				return require(script.Parent:FindFirstChild("QuirkConfig"))
			end)
			ST.config = ok and c or nil
		end
		return ST.config
	end
	local function tok()
		return cfg().UI.Street
	end
	local function image(name)
		local id = cfg().UI.Images[name]
		return (type(id) == "string" and id ~= "") and id or nil
	end
	ST.image = image
	-- tan(12 degrees): a slab's top edge sits this much of its height to the right
	function ST.lean()
		return math.tan(math.rad(tok().Lean))
	end

	---------------------------------------------------------------------------
	-- type
	---------------------------------------------------------------------------
	-- role: "Display" (Oswald Bold), "Body" (BuilderSans Medium), "Mono"
	-- (BuilderMono Bold), "Note" (PermanentMarker)
	function ST.font(role)
		role = role or "Display"
		local f = fontCache[role]
		if not f then
			local spec = tok().Fonts[role] or tok().Fonts.Display
			f = Font.new(spec.Family, Enum.FontWeight[spec.Weight], Enum.FontStyle.Normal)
			fontCache[role] = f
		end
		return f
	end
	-- the TextSize for an em size (Roblox fits the font's whole line into TextSize)
	function ST.textSize(size, role)
		local spec = tok().Fonts[role or "Display"] or tok().Fonts.Display
		return math.floor(size * spec.K * 10 + 0.5) / 10
	end
	-- where things sit in a label of this em size: H = the line (= TextSize),
	-- Base = the baseline from the top, CapTop = the top of a capital
	function ST.metrics(size, role)
		local spec = tok().Fonts[role or "Display"] or tok().Fonts.Display
		local h = size * spec.K
		return { H = h, Base = size * spec.Ascent, CapTop = size * (spec.Ascent - spec.Cap) }
	end
	-- a string utf8.codes can walk (one stray byte would make it throw)
	function ST.utf8(s)
		s = tostring(s or "")
		if utf8.len(s) then
			return s
		end
		return (string.gsub(s, "[\128-\255]", ""))
	end

	-- the width of a line of text at an em size, from the font's own advances
	-- (no TextService: it works offline and before anything's on screen)
	function ST.measure(text, size, role)
		local spec = tok().Fonts[role or "Display"] or tok().Fonts.Display
		local w = 0
		for _, c in utf8.codes(ST.utf8(text)) do
			if spec.Fixed then
				w += spec.Fixed
			elseif c >= 32 and c <= 126 then
				w += spec.Adv[c - 31]
			else
				w += 550
			end
		end
		return w * size / 1000
	end

	-- a TextLabel in one of the four faces. p: Text, Size (em px), Role, Color,
	-- T (transparency), AlignX / AlignY ("Left" / "Center" / "Right"...), Pos,
	-- Anchor, Box (a UDim2; default: the measured text), Parent, Z, Name,
	-- Rotation, Wrap, Visible, LineHeight. Never TextScaled. Over 100 TextSize
	-- (Roblox's limit) a UIScale named "Big" makes up the rest.
	function ST.label(p)
		local role = p.Role or "Display"
		local size = p.Size or 16
		local ts = ST.textSize(size, role)
		local box = p.Box or UDim2.fromOffset(math.ceil(ST.measure(p.Text, size, role)) + 2, math.ceil(ts))
		local l = make("TextLabel", {
			Name = p.Name or "Label",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = ST.font(role),
			TextSize = math.min(ts, 100),
			TextScaled = false,
			RichText = false,
			TextWrapped = p.Wrap == true,
			TextColor3 = p.Color or tok().Paper,
			TextTransparency = p.T or 0,
			TextXAlignment = Enum.TextXAlignment[p.AlignX or "Left"],
			TextYAlignment = Enum.TextYAlignment[p.AlignY or "Center"],
			LineHeight = p.LineHeight or 1,
			Text = tostring(p.Text or ""),
			Size = box,
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			Rotation = p.Rotation or 0,
			ZIndex = p.Z or 1,
			Visible = p.Visible ~= false,
			Parent = p.Parent,
		})
		if ts > 100 then
			local k = ts / 100
			make("UIScale", { Name = "Big", Scale = k, Parent = l })
			l.Size = UDim2.new(box.X.Scale / k, box.X.Offset / k, box.Y.Scale / k, box.Y.Offset / k)
		end
		return l
	end

	-- text over the world: the face plus a copy offset (2, 2) in ink behind it
	-- (not a stroke, not a blur). Same props as ST.label, plus Shadow (px) and
	-- ShadowT. Returns a holder Frame (children Shadow and Face); ST.setText
	-- changes both.
	function ST.shadowText(p)
		local size = p.Size or 16
		local role = p.Role or "Display"
		local off = p.Shadow or tok().ShadowOffset
		local box = p.Box or UDim2.fromOffset(math.ceil(ST.measure(p.Text, size, role)) + 2, math.ceil(ST.textSize(size, role)))
		local holder = make("Frame", {
			Name = p.Name or "Text",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = box,
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			Rotation = p.Rotation or 0,
			ZIndex = p.Z or 1,
			Visible = p.Visible ~= false,
			Parent = p.Parent,
		})
		local function copy(name, pos, color, t)
			return ST.label({
				Name = name, Text = p.Text, Size = size, Role = role, Color = color, T = t, AlignX = p.AlignX, AlignY = p.AlignY,
				Pos = pos, Box = UDim2.fromScale(1, 1), Parent = holder, Z = p.Z, Wrap = p.Wrap, LineHeight = p.LineHeight,
			})
		end
		copy("Shadow", UDim2.fromOffset(off, off), tok().Ink, p.ShadowT or 0)
		copy("Face", UDim2.new(), p.Color or tok().Paper, p.T or 0)
		return holder
	end

	-- set the text of a label, a shadowText holder or a numerals run
	function ST.setText(obj, text)
		text = tostring(text or "")
		if obj:GetAttribute("NumSize") then
			ST.setNumerals(obj, text)
		elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
			obj.Text = text
		else
			for _, n in { "Shadow", "Face" } do
				local c = obj:FindFirstChild(n)
				if c then
					c.Text = text
				end
			end
		end
	end

	-- NUMERALS: numbers and key letters, from the uploaded sheet (Oswald Bold
	-- sheared 12 degrees: italic, honestly) or, until it's uploaded, upright
	-- Oswald Bold text. size = em px. p: Color, T, Shadow (px: an ink copy
	-- behind), Pos, Anchor, Parent, Z, Name. The holder's width is the run's
	-- advance, its height the line (size * K): anchor it like a label.
	function ST.numerals(text, size, p)
		p = p or {}
		local holder = make("Frame", {
			Name = p.Name or "Numerals",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			Visible = p.Visible ~= false,
			Parent = p.Parent,
		})
		holder:SetAttribute("NumSize", size)
		holder:SetAttribute("NumColor", p.Color or tok().Paper)
		holder:SetAttribute("NumT", p.T or 0)
		holder:SetAttribute("NumShadow", p.Shadow or 0)
		ST.setNumerals(holder, text)
		return holder
	end

	function ST.setNumerals(holder, text)
		text = ST.utf8(text)
		local size = holder:GetAttribute("NumSize") or 20
		local color = holder:GetAttribute("NumColor") or tok().Paper
		local t = holder:GetAttribute("NumT") or 0
		local sh = holder:GetAttribute("NumShadow") or 0
		local spec = tok().Fonts.Display
		local map = cfg().UI.Images.NumeralMap
		local sheet = image("Numerals")
		if sheet then
			for _, c in utf8.codes(text) do
				if c ~= 32 and not map.Glyphs[utf8.char(c)] then
					sheet = nil -- (a glyph the sheet hasn't got: the whole run as text)
					break
				end
			end
		end
		local lineH = size * spec.K
		local width = 0
		holder:SetAttribute("NumText", text)
		local z = holder.ZIndex
		if sheet then
			local k = size / map.Em
			local top = size * spec.Ascent - map.Base * k
			local i = 0
			local pen = 0
			for _, c in utf8.codes(text) do
				local g = map.Glyphs[utf8.char(c)]
				if not g then
					-- (a space: just the advance)
					pen += spec.Adv[1] * size / 1000
					continue
				end
				i += 1
				for _, layer in sh > 0 and { "S", "G" } or { "G" } do
					local name = layer .. i
					local lab = holder:FindFirstChild(name)
					if not lab then
						lab = make("ImageLabel", {
							Name = name,
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Image = sheet,
							Parent = holder,
						})
					end
					lab.ZIndex = layer == "S" and z or z + 1 -- (every shadow under every face)
					local off = layer == "S" and sh or 0
					lab.ImageRectOffset = Vector2.new(g[1], g[2])
					lab.ImageRectSize = Vector2.new(g[3], map.Cell)
					lab.Size = UDim2.fromOffset(g[3] * k, map.Cell * k)
					lab.Position = UDim2.fromOffset(pen - g[5] * k + off, top + off)
					lab.ImageColor3 = layer == "S" and tok().Ink or color
					lab.ImageTransparency = t
					lab.Visible = true
				end
				pen += g[4] * k
			end
			width = pen
			for _, c in holder:GetChildren() do
				local n = tonumber(string.sub(c.Name, 2))
				if c:IsA("ImageLabel") and (n == nil or n > i or (string.sub(c.Name, 1, 1) == "S" and sh <= 0)) then
					c:Destroy()
				end
			end
			local txt = holder:FindFirstChild("Text")
			if txt then
				txt:Destroy()
			end
		else
			for _, c in holder:GetChildren() do
				if c:IsA("ImageLabel") then
					c:Destroy()
				end
			end
			width = ST.measure(text, size, "Display")
			local face = holder:FindFirstChild("Text")
			if not face then
				face = (sh > 0 and ST.shadowText or ST.label)({
					Name = "Text", Text = text, Size = size, Shadow = sh, Color = color, T = t, Box = UDim2.fromScale(1, 1),
					Parent = holder, Z = z,
				})
			end
			ST.setText(face, text)
		end
		holder.Size = UDim2.fromOffset(math.ceil(width) + sh, math.ceil(lineH))
	end

	---------------------------------------------------------------------------
	-- shapes
	---------------------------------------------------------------------------
	-- a frame's size in its own (unscaled) units: offsets when it has no scale
	-- part, else AbsoluteSize divided by every UIScale above it
	function ST.localSize(f)
		local s = f.Size
		if s.X.Scale == 0 and s.Y.Scale == 0 then
			return s.X.Offset, s.Y.Offset
		end
		local ok, abs = pcall(function()
			return f.AbsoluteSize
		end)
		if not ok or typeof(abs) ~= "Vector2" then
			return 0, 0 -- (not laid out yet: it re-cuts when its AbsoluteSize arrives)
		end
		local k = 1
		local node = f
		while node and node:IsA("GuiObject") do
			local sc = node:FindFirstChildOfClass("UIScale")
			if sc then
				k *= sc.Scale
			end
			node = node.Parent
		end
		return abs.X / k, abs.Y / k
	end

	-- the transparency band that cuts a square on its centre line, leaning 12
	-- degrees: keep = "right" (the part right of the line) or "left"
	local function capGradient(side, px)
		local e = math.clamp(0.6 / math.max(px, 1), 0.0005, 0.2)
		local a, b = side == "right" and 1 or 0, side == "right" and 0 or 1
		return make("UIGradient", {
			Rotation = tok().Lean,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, a),
				NumberSequenceKeypoint.new(0.5 - e, a),
				NumberSequenceKeypoint.new(0.5 + e, b),
				NumberSequenceKeypoint.new(1, b),
			}),
		})
	end

	-- one flat piece of a slab: a Frame, or a tiled ImageLabel (the hatch) whose
	-- stripes line up with the other pieces' (tile.Phase gives its offset)
	local function piece(holder, name, x, y, w, h, look, z)
		local p
		if look.Tile then
			p = make("ImageLabel", {
				Name = name,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = look.Tile,
				ImageColor3 = look.Color,
				ImageTransparency = look.T,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(32, 32),
				ImageRectSize = Vector2.new(32, 32),
				-- the stripes go (x + 0.75 y) mod 8: shift the window to this piece's spot
				ImageRectOffset = Vector2.new(((look.OX or 0) + x + 0.75 * ((look.OY or 0) + y)) % 8, 0),
				ZIndex = z,
				Parent = holder,
			})
		else
			p = make("Frame", {
				Name = name,
				BackgroundColor3 = look.Color,
				BackgroundTransparency = look.T,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = holder,
			})
		end
		p.Position = UDim2.fromOffset(x, y)
		p.Size = UDim2.fromOffset(w, h)
		return p
	end

	-- build the pieces of a parallelogram w x h into holder (its old pieces go).
	-- ends: "Both" / "Right" / "Left" / "None" (which ends lean). look: { Color,
	-- T, Tile? }. With the wedge image: a body and two anti-aliased wedges;
	-- without: bands, each a body and two square cut caps (a band is never taller
	-- than the slab is wide, so the caps never overlap)
	local function buildShape(holder, w, h, ends, look, z)
		for _, c in holder:GetChildren() do
			if string.sub(c.Name, 1, 2) == "_P" then
				c:Destroy()
			end
		end
		if w < 1 or h < 1 then
			return
		end
		local t = ST.lean()
		local l = h * t
		-- ("Left" = only the left end leans, "Right" = only the right)
		local leftLean = ends == "Both" or ends == "Left"
		local rightLean = ends == "Both" or ends == "Right"
		local span = (leftLean or rightLean) and (w - l) or w
		local wedge = image("Wedge")
		if wedge and not look.Tile and w >= 2 * l + 1 then
			local lw = math.floor(l + 0.5)
			local x0, x1 = 0, w
			if leftLean then
				make("ImageLabel", {
					Name = "_PL", BackgroundTransparency = 1, BorderSizePixel = 0, Image = wedge, ImageColor3 = look.Color,
					ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(64, 64),
					ImageTransparency = look.T, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(lw, h), ZIndex = z, Parent = holder,
				})
				x0 = lw
			end
			if rightLean then
				make("ImageLabel", {
					-- (the sheet's right half: the other triangle. Not a 180-degree turn of
					-- the left one: a turned piece would slip out of a fill's clip)
					Name = "_PR", BackgroundTransparency = 1, BorderSizePixel = 0, Image = wedge, ImageColor3 = look.Color,
					ImageRectOffset = Vector2.new(64, 0), ImageRectSize = Vector2.new(64, 64),
					ImageTransparency = look.T, Position = UDim2.fromOffset(w - lw, 0), Size = UDim2.fromOffset(lw, h),
					ZIndex = z, Parent = holder,
				})
				x1 = w - lw
			end
			piece(holder, "_PB", x0, 0, math.max(x1 - x0, 0), h, look, z)
			return
		end
		if span < 1 then
			return
		end
		local n = math.max(1, math.ceil(h / span - 1e-6))
		for k = 0, n - 1 do
			local y0 = math.floor(k * h / n + 0.5)
			local y1 = math.floor((k + 1) * h / n + 0.5)
			local hb = y1 - y0
			if hb > 0 then
				local ym = (y0 + y1) / 2
				local bx0, bx1 = 0, w
				if leftLean then
					local xl = (h - ym) * t
					local cx = math.floor(xl - hb / 2 + 0.5)
					local cap = piece(holder, "_PL" .. k, cx, y0, hb, hb, look, z)
					capGradient("right", hb).Parent = cap
					bx0 = cx + hb
				end
				if rightLean then
					local xr = w - ym * t
					local cx = math.floor(xr - hb / 2 + 0.5)
					local cap = piece(holder, "_PR" .. k, cx, y0, hb, hb, look, z)
					capGradient("left", hb).Parent = cap
					bx1 = cx
				end
				if bx1 > bx0 then
					piece(holder, "_PB" .. k, bx0, y0, bx1 - bx0, hb, look, z)
				end
			end
		end
	end

	local function lookOf(f)
		return {
			Color = f:GetAttribute("StColor") or tok().Ink,
			T = f:GetAttribute("StT") or 0,
			Tile = f:GetAttribute("StTile"),
		}
	end

	-- THE SLAB: every container, bar, tab, slot and button. p: Name, Parent,
	-- Pos, Anchor, Size (a UDim2 or { w, h }), Color, T, Z, LayoutOrder, Ends
	-- ("Both" default, "Right" / "Left": only that end leans, "None"), Button
	-- (a TextButton you can click, AutoButtonColor off), Visible. Its pieces are
	-- children named _P...; put content at ZIndex Z + 1. It re-cuts itself when
	-- its size changes (ST.relayout).
	function ST.slab(p)
		local size = p.Size
		if type(size) == "table" then
			size = UDim2.fromOffset(size[1], size[2])
		end
		local f = make(p.Button and "TextButton" or "Frame", {
			Name = p.Name or "Slab",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = size or UDim2.fromOffset(100, 34),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			LayoutOrder = p.LayoutOrder or 0,
			Visible = p.Visible ~= false,
		})
		if p.Button then
			f.Text = ""
			f.AutoButtonColor = false
		end
		f:SetAttribute("StSlab", true)
		f:SetAttribute("StColor", p.Color or tok().Ink)
		f:SetAttribute("StT", p.T or 0)
		f:SetAttribute("StEnds", p.Ends or "Both")
		if p.Tile then
			f:SetAttribute("StTile", p.Tile)
		end
		ST.relayout(f)
		f:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			ST.relayout(f)
		end)
		f.Parent = p.Parent
		return f
	end

	-- re-cut a slab (and its fills) for its current size
	function ST.relayout(f)
		local w, h = ST.localSize(f)
		if w <= 0 or h <= 0 then
			return
		end
		w, h = math.floor(w + 0.5), math.floor(h + 0.5)
		if f:GetAttribute("StW") == w and f:GetAttribute("StH") == h then
			return
		end
		f:SetAttribute("StW", w)
		f:SetAttribute("StH", h)
		buildShape(f, w, h, f:GetAttribute("StEnds") or "Both", lookOf(f), f.ZIndex)
		for _, c in f:GetChildren() do
			if c:GetAttribute("StFill") then
				-- (review) a fill shares its slab's ZIndex, so the engine draws whichever
				-- was parented last on top: the new pieces would hide it. Re-parent it after them.
				c.Parent = nil
				c.Parent = f
				ST.layoutFill(c)
			end
		end
	end

	-- recolour a slab (instant: tabs and hover swap colours, they don't fade)
	function ST.paint(f, color, t)
		if color then
			f:SetAttribute("StColor", color)
		end
		if t then
			f:SetAttribute("StT", t)
		end
		local look = lookOf(f)
		for _, c in f:GetChildren() do
			if string.sub(c.Name, 1, 2) == "_P" then
				if c:IsA("ImageLabel") then
					c.ImageColor3 = look.Color
					c.ImageTransparency = look.T
				else
					c.BackgroundColor3 = look.Color
					c.BackgroundTransparency = look.T
				end
			end
		end
	end

	-- A FILL inside a slab (health, sweat, evade, a segment, the ULT button): the
	-- same shape cut short, its moving end leaning too. p: Name, Color, T, From
	-- ("Left" default, or "Right": it covers from the right, like a cooldown),
	-- Value (0-1), Z, Tile. Built from a ClipsDescendants frame holding a whole
	-- copy of the slab and a second one holding the square cut cap at the edge.
	function ST.fill(slab, p)
		p = p or {}
		local f = make("Frame", {
			Name = p.Name or "Fill",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = p.Z or slab.ZIndex,
			Parent = slab,
		})
		f:SetAttribute("StFill", true)
		f:SetAttribute("StColor", p.Color or tok().Paper)
		f:SetAttribute("StT", p.T or 0)
		f:SetAttribute("StFrom", p.From or "Left")
		f:SetAttribute("StValue", math.clamp(p.Value or 0, 0, 1))
		if p.Tile then
			f:SetAttribute("StTile", p.Tile)
		end
		make("Frame", { Name = "Clip", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = f.ZIndex, Parent = f })
		make("Frame", { Name = "Edge", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = f.ZIndex, Parent = f })
		ST.layoutFill(f)
		return f
	end

	-- where a fill's pieces go for a value (local px): the clip rect and the edge rect
	-- (whole pixels, rounded once, so the clip and the edge always meet: offsets
	-- are integers in the engine. The cap's x puts its centre on the true line.)
	local function fillRects(w, h, from, v)
		local l = h * ST.lean()
		local lr = math.floor(l + 0.5)
		local c
		if from == "Right" then
			c = (1 - v) * (w - l) -- the cover's bottom-left corner
		else
			c = v * (w - l) -- the fill's bottom-right corner
		end
		local cr = math.floor(c + 0.5)
		local capX = math.floor(c - cr + l / 2 - h / 2 + 0.5)
		if from == "Right" then
			return { cr + lr, 0, math.max(w - (cr + lr), 0), h }, { cr, 0, lr, h }, c, capX
		end
		return { 0, 0, cr, h }, { cr, 0, lr, h }, c, capX
	end

	function ST.layoutFill(f)
		local slab = f.Parent
		local w, h = slab:GetAttribute("StW"), slab:GetAttribute("StH")
		if not (w and h) then
			return
		end
		local clip, edge = f:FindFirstChild("Clip"), f:FindFirstChild("Edge")
		local look = lookOf(f)
		local z = f.ZIndex
		-- the copy of the whole slab, and the cut cap
		if f:GetAttribute("StW") ~= w or f:GetAttribute("StH") ~= h or not clip:FindFirstChild("Inner") then
			f:SetAttribute("StW", w)
			f:SetAttribute("StH", h)
			for _, c in clip:GetChildren() do
				c:Destroy()
			end
			for _, c in edge:GetChildren() do
				c:Destroy()
			end
			local inner = make("Frame", { Name = "Inner", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(w, h), ZIndex = z, Parent = clip })
			buildShape(inner, w, h, slab:GetAttribute("StEnds") or "Both", look, z)
			local cap = make("Frame", { Name = "Cap", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(h, h), ZIndex = z, Parent = edge })
			local capPiece = piece(cap, "_PC", 0, 0, h, h, look, z)
			capGradient(f:GetAttribute("StFrom") == "Right" and "right" or "left", h).Parent = capPiece
		end
		ST.setFill(f, f:GetAttribute("StValue") or 0)
	end

	-- move a fill to v (0-1); time: tween there (Linear unless style), else snap.
	-- The end state is set for sure when the time's up (frames can be skipped).
	function ST.setFill(f, v, time, style)
		v = math.clamp(tonumber(v) or 0, 0, 1)
		f:SetAttribute("StValue", v)
		local slab = f.Parent
		local w, h = slab:GetAttribute("StW"), slab:GetAttribute("StH")
		if not (w and h) then
			return
		end
		local from = f:GetAttribute("StFrom") or "Left"
		local r1, r2, c, capX = fillRects(w, h, from, v)
		local l = h * ST.lean()
		local clip, edge = f.Clip, f.Edge
		local inner = clip:FindFirstChild("Inner")
		local cap = edge:FindFirstChild("Cap")
		-- (the copy stays where the slab is: the clip moves over it)
		local goals = {
			{ clip, { Position = UDim2.fromOffset(r1[1], r1[2]), Size = UDim2.fromOffset(r1[3], r1[4]) } },
			{ inner, { Position = UDim2.fromOffset(-r1[1], 0) } },
			{ edge, { Position = UDim2.fromOffset(r2[1], r2[2]), Size = UDim2.fromOffset(r2[3], r2[4]) } },
			{ cap, { Position = UDim2.fromOffset(capX, 0) } },
		}
		-- a sliver thinner than the lean: just the clipped copy (the cap would poke
		-- out past the slab's other end)
		local capPiece = cap and cap:FindFirstChild("_PC")
		if capPiece and capPiece:IsA("ImageLabel") then
			-- (the hatch: the cap's stripes in step with the rest's, wherever the edge is)
			capPiece.ImageRectOffset = Vector2.new((r2[1] + capX) % 8, 0)
		end
		local tiny = (from == "Left" and c < l) or (from == "Right" and (w - l - c) < l)
		local showEdge, showClip = v > 0 and not tiny, v > 0
		-- (review) a tween keeps what's showing up while it moves (a drain to 0 - the
		-- chip, the ULT button over the ult - would vanish at once otherwise) and
		-- lands the end's visibility with the end state
		local turn = (f:GetAttribute("StTurn") or 0) + 1
		f:SetAttribute("StTurn", turn)
		if time and time > 0 then
			edge.Visible = edge.Visible or showEdge
			clip.Visible = clip.Visible or showClip
			task.delay(time + 0.03, function()
				if f:GetAttribute("StTurn") == turn then
					edge.Visible, clip.Visible = showEdge, showClip
				end
			end)
		else
			edge.Visible, clip.Visible = showEdge, showClip
		end
		for _, g in goals do
			if g[1] then
				if time and time > 0 then
					ST.tween(g[1], time, g[2], style or Enum.EasingStyle.Linear)
				else
					for k, val in g[2] do
						g[1][k] = val
					end
				end
			end
		end
	end

	function ST.paintFill(f, color, t)
		if color then
			f:SetAttribute("StColor", color)
		end
		if t then
			f:SetAttribute("StT", t)
		end
		local look = lookOf(f)
		for _, d in f:GetDescendants() do
			if string.sub(d.Name, 1, 2) == "_P" then
				if d:IsA("ImageLabel") then
					d.ImageColor3 = look.Color
					d.ImageTransparency = look.T
				else
					d.BackgroundColor3 = look.Color
					d.BackgroundTransparency = look.T
				end
			end
		end
	end

	-- THE HATCH: a cooldown's cover over a slot (what's left, from the right),
	-- with a 2 px paper line on its leaning edge (the sweep). Stripes from
	-- hatch.png once uploaded; a plain HATCH cover until then. ST.setHatch(h, f)
	-- (f = how much is still cooling, 0-1).
	function ST.hatch(slot, p)
		p = p or {}
		local tile = image("Hatch")
		local h = ST.fill(slot, {
			Name = p.Name or "Hatch",
			Color = tok().Hatch,
			T = tile and tok().HatchT or tok().HatchFlatT,
			From = "Right",
			Value = 0,
			Z = p.Z,
			Tile = tile,
		})
		make("Frame", {
			Name = "Sweep",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = tok().Paper,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Rotation = tok().Lean,
			ZIndex = h.ZIndex,
			Visible = false,
			Parent = h,
		})
		ST.setHatch(h, p.Value or 0)
		return h
	end

	function ST.setHatch(h, v)
		v = math.clamp(tonumber(v) or 0, 0, 1)
		ST.setFill(h, v)
		local slot = h.Parent
		local w, hh = slot:GetAttribute("StW"), slot:GetAttribute("StH")
		local sweep = h:FindFirstChild("Sweep")
		if sweep and w and hh then
			local l = hh * ST.lean()
			local c = (1 - v) * (w - l)
			sweep.Size = UDim2.fromOffset(2, hh / math.cos(math.rad(tok().Lean)))
			sweep.Position = UDim2.fromOffset(c + l / 2, hh / 2)
			sweep.Visible = v > 0 and v < 1
		end
	end

	-- SEGMENTS: the guard meter and the slider's ticks. n leaning slabs in a row.
	-- p: Size { w, h }, Gap, Parent, Pos, Anchor, Z, Color (empty), T (empty),
	-- Name. ST.setSegments(seg, value 0-1, { Color, T, EmptyColor, EmptyT }).
	function ST.segments(n, p)
		p = p or {}
		local size = p.Size or { 200, 10 }
		local gap = p.Gap or 2.5
		local holder = make("Frame", {
			Name = p.Name or "Segments",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size[1], size[2]),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		local h = size[2]
		local l = h * ST.lean()
		local sw = (size[1] - l - gap * (n - 1)) / n
		for i = 1, n do
			local s = ST.slab({
				Name = "Seg" .. i,
				Size = { math.floor(sw + l + 0.5), h },
				Pos = UDim2.fromOffset(math.floor((i - 1) * (sw + gap) + 0.5), 0),
				Color = p.Color or tok().Ink,
				T = p.T or 0.3,
				Z = holder.ZIndex,
				Button = p.Buttons,
				Parent = holder,
			})
			ST.fill(s, { Name = "Fill", Color = tok().Paper, Value = 0 })
		end
		holder:SetAttribute("SegN", n)
		return holder
	end

	function ST.setSegments(seg, value, look)
		look = look or {}
		local n = seg:GetAttribute("SegN") or 10
		value = math.clamp(tonumber(value) or 0, 0, 1)
		for i = 1, n do
			local s = seg:FindFirstChild("Seg" .. i)
			if s then
				local part = math.clamp(value * n - (i - 1), 0, 1)
				if look.EmptyColor or look.EmptyT then
					ST.paint(s, look.EmptyColor, look.EmptyT)
				end
				local fill = s:FindFirstChild("Fill")
				if fill then
					ST.paintFill(fill, look.Color or tok().Paper, look.T or 0)
					ST.setFill(fill, part)
				end
			end
		end
		seg:SetAttribute("SegValue", value)
	end

	-- THE SLASH: the hero's brush stroke (the ult meter, "selected", the kill
	-- feed, the cut-in). p: Name, Parent, Pos, Anchor, Size { w, h }, Color (the
	-- hero's), Value (how much is painted, 0-1), Rotation (default -2.5), Ghost
	-- (true: the ink stroke under it, at GhostT), T, Z. slash.png once uploaded;
	-- until then a stand-in drawn from bristle strips. ST.setSlash(s, v, time)
	-- paints it in (left to right) or drains it; ST.tintSlash(s, color).
	-- (the stand-in: overlapping bristle strips, landed on a slant, each running
	-- dry at its own point - the edges first - with a streak of ink caught again
	-- near its end, so the tail breaks up the way a dry brush's does)
	local BRISTLES = { -- { y centre, height, start, length, where it runs dry, the late streak } (fractions)
		{ 0.21, 0.10, 0.030, 0.70, 0.40, 0.78 },
		{ 0.28, 0.11, 0.025, 0.86, 0.58, 0.70 },
		{ 0.35, 0.11, 0.020, 0.94, 0.66, 0.85 },
		{ 0.42, 0.12, 0.016, 1.00, 0.72, 0.80 },
		{ 0.50, 0.12, 0.012, 0.97, 0.78, 0.90 },
		{ 0.58, 0.12, 0.009, 0.99, 0.62, 0.86 },
		{ 0.65, 0.11, 0.006, 0.90, 0.70, 0.76 },
		{ 0.72, 0.11, 0.004, 0.80, 0.52, 0.82 },
		{ 0.79, 0.10, 0.002, 0.62, 0.45, 0.72 },
	}
	local function bristleGradient(b)
		local dry, streak = b[5], b[6]
		return make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(dry, 0),
				NumberSequenceKeypoint.new(math.min(dry + 0.08, streak - 0.04), 0.55),
				NumberSequenceKeypoint.new(streak, 0.15),
				NumberSequenceKeypoint.new(math.min(streak + 0.06, 0.97), 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end

	local function slashLayer(holder, name, w, h, color, t, z)
		local layer = make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(w, h),
			ZIndex = z,
			Parent = holder,
		})
		local img = image("Slash")
		if img then
			local lab = make("ImageLabel", {
				Name = "Stroke",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = img,
				ImageColor3 = color,
				ImageTransparency = t,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = layer,
			})
			-- the paint cut: a hard stop leaning with the lean (in the image's own
			-- squashed space it's a small angle; how far it's moved = Offset.X)
			make("UIGradient", {
				Name = "Cut",
				Rotation = math.deg(math.atan(h * ST.lean() / math.max(w, 1))),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.495, 0),
					NumberSequenceKeypoint.new(0.505, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Offset = Vector2.new(0.5, 0),
				Parent = lab,
			})
		else
			for i, b in BRISTLES do
				local s = make("Frame", {
					Name = "Bristle" .. i,
					BackgroundColor3 = color,
					BackgroundTransparency = t,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(math.floor(b[3] * w + 0.5), math.floor((b[1] - b[2] / 2) * h + 0.5)),
					Size = UDim2.fromOffset(math.floor(b[4] * w + 0.5), math.max(1, math.floor(b[2] * h + 0.5))),
					ZIndex = z,
					Parent = layer,
				})
				s:SetAttribute("Len", math.floor(b[4] * w + 0.5))
				bristleGradient(b).Parent = s
			end
		end
		return layer
	end

	function ST.slash(p)
		local size = p.Size or { 430, 50 }
		local w, h = size[1], size[2]
		local holder = make("Frame", {
			Name = p.Name or "Slash",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(w, h),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			Rotation = p.Rotation or -2.5,
			ZIndex = p.Z or 1,
			Visible = p.Visible ~= false,
			Parent = p.Parent,
		})
		if p.Ghost then
			slashLayer(holder, "Ghost", w, h, p.GhostColor or tok().Ink, p.GhostT or 0.1, holder.ZIndex)
		end
		slashLayer(holder, "Paint", w, h, p.Color or tok().Paper, p.T or 0, holder.ZIndex)
		ST.setSlash(holder, p.Value == nil and 1 or p.Value)
		return holder
	end

	function ST.setSlash(s, v, time)
		v = math.clamp(tonumber(v) or 0, 0, 1)
		s:SetAttribute("SlashValue", v)
		local paint = s:FindFirstChild("Paint")
		if not paint then
			return
		end
		local stroke = paint:FindFirstChild("Stroke")
		local function go(obj, goal)
			if time and time > 0 then
				ST.tween(obj, time, goal, Enum.EasingStyle.Linear)
			else
				for k, val in goal do
					obj[k] = val
				end
			end
		end
		-- (review) what shows: hidden at 0 - but a drain to 0 over time (the ult
		-- running out) stays up while it drains and hides when it lands
		local parts = {}
		if stroke then
			table.insert(parts, stroke)
		else
			for _, b in paint:GetChildren() do
				if b:GetAttribute("Len") then
					table.insert(parts, b)
				end
			end
		end
		local turn = (s:GetAttribute("SlashTurn") or 0) + 1
		s:SetAttribute("SlashTurn", turn)
		local draining = v <= 0 and time and time > 0
		for _, part in parts do
			if not draining then
				part.Visible = v > 0
			end
		end
		if draining then
			task.delay(time + 0.03, function()
				if s:GetAttribute("SlashTurn") == turn then
					for _, part in parts do
						part.Visible = false
					end
				end
			end)
		end
		if stroke then
			go(stroke.Cut, { Offset = Vector2.new(v - 0.5, 0) })
		else
			for _, b in parts do
				go(b, { Size = UDim2.fromOffset(math.floor(b:GetAttribute("Len") * v + 0.5), b.Size.Y.Offset) })
			end
		end
	end

	function ST.tintSlash(s, color, layer)
		local l = s:FindFirstChild(layer or "Paint")
		for _, d in l and l:GetDescendants() or {} do
			if d:IsA("ImageLabel") then
				d.ImageColor3 = color
			elseif d:IsA("Frame") then
				d.BackgroundColor3 = color
			end
		end
	end

	---------------------------------------------------------------------------
	-- controls
	---------------------------------------------------------------------------
	-- a key cap: a small leaning paper slab with an ink letter from the numeral
	-- sheet. size = its height. p: Parent, Pos, Anchor, Z, Name, Ink (true: an ink
	-- cap with a paper letter, for paper surfaces)
	function ST.keyCap(letter, size, p)
		p = p or {}
		size = size or 16
		local glyph = size * 0.78
		local w = math.max(math.floor(size * 0.92 + 0.5), math.ceil(ST.measure(letter, glyph) + size * ST.lean() * 2 + 4))
		local cap = ST.slab({
			Name = p.Name or "Key",
			Size = { w, size },
			Pos = p.Pos,
			Anchor = p.Anchor,
			Color = p.Ink and tok().Ink or tok().Paper,
			Z = p.Z,
			Parent = p.Parent,
		})
		ST.numerals(letter, glyph, {
			Name = "Letter",
			Color = p.Ink and tok().Paper or tok().Ink,
			Anchor = Vector2.new(0.5, 0.5),
			Pos = UDim2.new(0.5, 1, 0.5, 0),
			Z = cap.ZIndex + 1,
			Parent = cap,
		})
		return cap
	end

	-- the one hand note per screen: PermanentMarker, lowercase, rotated +3..+6
	function ST.note(text, size, p)
		p = p or {}
		return ST.label({
			Name = p.Name or "Note",
			Role = "Note",
			Text = string.lower(tostring(text or "")),
			Size = size or tok().Sizes.Note,
			Color = p.Color or tok().Paper,
			T = p.T or 0.02,
			Rotation = p.Rotation or 4,
			Pos = p.Pos,
			Anchor = p.Anchor,
			Z = p.Z,
			Parent = p.Parent,
		})
	end

	-- the close X: two 3 px bars at +-45 degrees, never a glyph. p: Size (the
	-- X's width), Color, Parent, Pos, Anchor, Z, OnClick
	function ST.closeX(p)
		p = p or {}
		local s = p.Size or 22
		local b = make("TextButton", {
			Name = p.Name or "Close",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(s + 8, s + 8),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.new(0.5, 0.5),
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		for i, r in { 45, -45 } do
			make("Frame", {
				Name = "Bar" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(p.Thickness or 3, math.floor(s * 1.414 + 0.5)),
				BackgroundColor3 = p.Color or tok().Paper,
				BorderSizePixel = 0,
				Rotation = r,
				ZIndex = b.ZIndex + 1,
				Parent = b,
			})
		end
		if p.OnClick then
			b.Activated:Connect(p.OnClick)
		end
		return b
	end

	-- the gear (settings): icons.png once uploaded; until then drawn from frames
	-- (four bars for eight teeth, a body, an ink hole). p: Size, Color, Hole
	-- (the hole's colour), Parent, Pos, Anchor, Z
	function ST.gear(p)
		p = p or {}
		local d = p.Size or 22
		local holder = make("Frame", {
			Name = p.Name or "Gear",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(d, d),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.new(0.5, 0.5),
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		local color = p.Color or tok().Paper
		local sheet = image("Icons")
		if sheet then
			local r = cfg().UI.Images.IconMap.Gear
			make("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = sheet,
				ImageRectOffset = Vector2.new(r[1], r[2]),
				ImageRectSize = Vector2.new(r[3], r[4]),
				ImageColor3 = color,
				Size = UDim2.fromScale(1, 1),
				ZIndex = holder.ZIndex,
				Parent = holder,
			})
			return holder
		end
		for i = 0, 3 do
			make("Frame", {
				Name = "Tooth" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(math.max(2, math.floor(d * 0.26 + 0.5)), d),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Rotation = i * 45 + 22.5,
				ZIndex = holder.ZIndex,
				Parent = holder,
			})
		end
		make("Frame", {
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(d * 0.72 + 0.5), math.floor(d * 0.72 + 0.5)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = 22.5,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		make("Frame", {
			Name = "Hole",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(d * 0.26 + 0.5), math.floor(d * 0.26 + 0.5)),
			BackgroundColor3 = p.Hole or tok().Ink,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		return holder
	end

	-- A SWITCH: one leaning slab cut in two; the live half is paper. p: On,
	-- Labels { "ON", "OFF" }, Size { w, h }, Parent, Pos, Anchor, Z, OnChange(on)
	function ST.switch(p)
		p = p or {}
		local size = p.Size or { 112, 30 }
		local w, h = size[1], size[2]
		local l = h * ST.lean()
		local half = w / 2
		local holder = make("Frame", {
			Name = p.Name or "Switch",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(w + 2, h),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		local labels = p.Labels or { "ON", "OFF" }
		for i, name in { "On", "Off" } do
			local s = ST.slab({
				Name = name,
				Button = true,
				Size = { math.floor(half + l / 2 + 0.5), h },
				Pos = UDim2.fromOffset(i == 1 and 0 or math.floor(half - l / 2 + 2 + 0.5), 0),
				Z = holder.ZIndex,
				Parent = holder,
			})
			ST.label({
				Name = "Label", Text = labels[i], Size = 14, AlignX = "Center", Box = UDim2.fromScale(1, 1),
				Pos = UDim2.fromOffset(0, 0), Z = holder.ZIndex + 1, Parent = s,
			})
			s.Activated:Connect(function()
				ST.setSwitch(holder, i == 1)
				if p.OnChange then
					p.OnChange(i == 1)
				end
			end)
		end
		ST.setSwitch(holder, p.On == true)
		return holder
	end

	function ST.setSwitch(sw, on)
		sw:SetAttribute("On", on == true)
		for i, name in { "On", "Off" } do
			local s = sw:FindFirstChild(name)
			if s then
				local live = (i == 1) == (on == true)
				ST.paint(s, live and tok().Paper or tok().Ink2, 0)
				local lab = s:FindFirstChild("Label")
				if lab then
					lab.TextColor3 = live and tok().Ink or tok().Paper
					lab.TextTransparency = live and 0 or 0.6
				end
			end
		end
	end

	-- A SLIDER: n leaning ticks (the guard meter's build) and the value in
	-- numerals. p: N (10), Value (0-1), Size { w, h } of the ticks, Suffix ("%"),
	-- Max (what the full bar reads: 100), Parent, Pos, Anchor, Z, OnChange(v)
	function ST.slider(p)
		p = p or {}
		local n = p.N or 10
		local size = p.Size or { 205, 18 }
		local holder = make("Frame", {
			Name = p.Name or "Slider",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size[1] + 60, size[2]),
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		holder:SetAttribute("Max", p.Max or 100)
		holder:SetAttribute("Suffix", p.Suffix or "%")
		local seg = ST.segments(n, { Name = "Ticks", Size = size, Gap = p.Gap or 3, Color = tok().Ink2, T = 0, Z = holder.ZIndex, Buttons = true, Parent = holder })
		for i = 1, n do
			local tick = seg:FindFirstChild("Seg" .. i)
			tick.Activated:Connect(function()
				ST.setSlider(holder, i / n)
				if p.OnChange then
					p.OnChange(i / n)
				end
			end)
		end
		ST.numerals("", 18, { Name = "Value", Pos = UDim2.fromOffset(size[1] + 10, size[2] / 2), Anchor = Vector2.new(0, 0.5), Z = holder.ZIndex, Parent = holder })
		ST.setSlider(holder, p.Value or 1)
		return holder
	end

	function ST.setSlider(sl, v)
		v = math.clamp(tonumber(v) or 0, 0, 1)
		sl:SetAttribute("Value", v)
		local seg = sl:FindFirstChild("Ticks")
		local n = seg:GetAttribute("SegN") or 10
		-- (whole ticks: a slider steps)
		ST.setSegments(seg, math.floor(v * n + 0.5) / n, { Color = tok().Paper, T = 0 })
		ST.setNumerals(sl.Value, tostring(math.floor(v * (sl:GetAttribute("Max") or 100) + 0.5)) .. (sl:GetAttribute("Suffix") or ""))
	end

	-- TABS: a row of leaning ink slabs (the top bar's, the shop's). p: Items {
	-- { Id, Text, Key (hint) , Icon = "Gear" } }, H (34), Gap (4), Size (em 16),
	-- KeySize (11), T (0.16), Keys (show key hints), Active, Parent, Pos,
	-- Anchor, Z, OnPick(id). The open one is paper with ink text.
	function ST.tabs(p)
		p = p or {}
		local h = p.H or tok().Sizes.TopBar
		local gap = p.Gap or tok().Sizes.TabGap
		local size = p.Size or tok().Sizes.Tab
		local ksize = p.KeySize or tok().Sizes.KeyHint
		local l = h * ST.lean()
		local pad = l + 10
		local holder = make("Frame", {
			Name = p.Name or "Tabs",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = p.Pos or UDim2.new(),
			AnchorPoint = p.Anchor or Vector2.zero,
			ZIndex = p.Z or 1,
			Parent = p.Parent,
		})
		holder:SetAttribute("TabT", p.T or tok().HudT)
		holder:SetAttribute("TabGap", gap)
		local x = 0
		for i, it in p.Items or {} do
			local tw = it.Icon and 0 or ST.measure(it.Text, size)
			local kw = (it.Key and p.Keys ~= false) and (ST.measure(it.Key, ksize, "Mono") + 6) or 0
			local w = it.Icon and math.floor(h + l + 2 + 0.5) or math.floor(pad + tw + kw + pad * 0.7 + 0.5)
			local tab = ST.slab({ Name = it.Id, Button = true, Size = { w, h }, Pos = UDim2.fromOffset(x, 0), T = holder:GetAttribute("TabT"), Z = holder.ZIndex, LayoutOrder = i, Parent = holder })
			if it.Icon then
				ST.gear({ Name = "Icon", Size = math.floor(h * 0.6 + 0.5), Pos = UDim2.fromScale(0.5, 0.5), Z = holder.ZIndex + 1, Parent = tab })
			else
				ST.label({ Name = "Label", Text = it.Text, Size = size, Pos = UDim2.new(0, pad - 2, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = holder.ZIndex + 1, Parent = tab })
				if it.Key then
					ST.label({
						Name = "Key", Role = "Mono", Text = it.Key, Size = ksize, Color = tok().Ash, Visible = p.Keys ~= false,
						Pos = UDim2.new(0, pad - 2 + tw + 6, 0.5, 1), Anchor = Vector2.new(0, 0.5), Z = holder.ZIndex + 1, Parent = tab,
					})
				end
			end
			tab.Activated:Connect(function()
				if p.OnPick then
					p.OnPick(it.Id)
				end
			end)
			x += w + gap
		end
		holder.Size = UDim2.fromOffset(math.max(x - gap, 0), h)
		ST.setTab(holder, p.Active)
		return holder
	end

	-- ((round 100, integration) the shown tabs packed left to right: a hidden
	-- one (DISCORD for a player Roblox doesn't allow, TEST for a player) leaves
	-- no gap; the holder's width follows)
	function ST.packTabs(tabs)
		local gap = tabs:GetAttribute("TabGap") or 0
		local list = {}
		for _, tab in tabs:GetChildren() do
			if tab:GetAttribute("StSlab") then
				table.insert(list, tab)
			end
		end
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local x = 0
		for _, tab in list do
			if tab.Visible then
				tab.Position = UDim2.fromOffset(x, 0)
				x += tab.Size.X.Offset + gap
			end
		end
		tabs.Size = UDim2.fromOffset(math.max(x - gap, 0), tabs.Size.Y.Offset)
	end

	-- light the open tab (nil: none)
	function ST.setTab(tabs, id)
		tabs:SetAttribute("Active", id)
		for _, tab in tabs:GetChildren() do
			if tab:GetAttribute("StSlab") then
				local on = tab.Name == id
				ST.paint(tab, on and tok().Paper or tok().Ink, on and 0 or tabs:GetAttribute("TabT"))
				local lab = tab:FindFirstChild("Label")
				if lab then
					lab.TextColor3 = on and tok().Ink or tok().Paper
				end
				local key = tab:FindFirstChild("Key")
				if key then
					key.TextColor3 = on and tok().Ink or tok().Ash
				end
				local icon = tab:FindFirstChild("Icon")
				for _, d in icon and icon:GetChildren() or {} do
					if d.Name == "Hole" then
						d.BackgroundColor3 = on and tok().Paper or tok().Ink
					elseif d:IsA("Frame") then
						d.BackgroundColor3 = on and tok().Ink or tok().Paper
					elseif d:IsA("ImageLabel") then
						d.ImageColor3 = on and tok().Ink or tok().Paper
					end
				end
			end
		end
	end

	-- the key hints follow the input (hidden on touch and on a controller)
	function ST.tabKeys(tabs, on)
		for _, tab in tabs:GetChildren() do
			local key = tab:FindFirstChild("Key")
			if key then
				key.Visible = on
			end
		end
	end

	-- A BUTTON: Kind "Primary" (paper, ink text) or "Secondary" (ink 2, paper
	-- text). p: Text, Size { w, h } (132 x 38), TextSize (em, 21), Hint (a small
	-- mono word at the right, e.g. ENTER), Parent, Pos, Anchor, Z, OnClick
	function ST.button(p)
		p = p or {}
		local size = p.Size or { 132, 38 }
		local primary = (p.Kind or "Primary") == "Primary"
		local b = ST.slab({
			Name = p.Name or "Button",
			Button = true,
			Size = size,
			Pos = p.Pos,
			Anchor = p.Anchor,
			Color = primary and tok().Paper or tok().Ink2,
			T = 0,
			Z = p.Z,
			Parent = p.Parent,
		})
		local l = size[2] * ST.lean()
		ST.label({
			Name = "Label",
			Text = p.Text or "",
			Size = p.TextSize or 21,
			Color = primary and tok().Ink or tok().Paper,
			Pos = UDim2.new(0, math.floor(l + 12 + 0.5), 0.5, 0),
			Anchor = Vector2.new(0, 0.5),
			Z = b.ZIndex + 1,
			Parent = b,
		})
		if p.Hint then
			ST.label({
				Name = "Hint",
				Role = "Mono",
				Text = p.Hint,
				Size = tok().Sizes.KeyHint, -- ((round 101) 11, the key hints' size: 9 went under 9 real px with the size knob)
				Color = tok().Ash,
				Pos = UDim2.new(1, -math.floor(l + 10 + 0.5), 0.5, 1),
				Anchor = Vector2.new(1, 0.5),
				Z = b.ZIndex + 1,
				Parent = b,
			})
		end
		if p.OnClick then
			b.Activated:Connect(p.OnClick)
		end
		return b
	end

	-- the scroll bar: a 3 px leaning line beside a ScrollingFrame (the frame's
	-- own bar goes). ST.updateScrollbar(bar) follows CanvasPosition.
	function ST.scrollbar(sf, p)
		p = p or {}
		sf.ScrollBarThickness = 0
		local bar = make("Frame", {
			Name = (p.Name or sf.Name) .. "Bar",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = p.Color or tok().Paper,
			BackgroundTransparency = p.T or 0.3,
			BorderSizePixel = 0,
			Rotation = tok().Lean,
			ZIndex = sf.ZIndex + 1,
			Parent = sf.Parent,
		})
		bar:SetAttribute("For", sf.Name)
		local function upd()
			ST.updateScrollbar(bar, sf)
		end
		sf:GetPropertyChangedSignal("CanvasPosition"):Connect(upd)
		sf:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(upd)
		sf:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
		upd()
		return bar
	end

	function ST.updateScrollbar(bar, sf)
		sf = sf or bar.Parent:FindFirstChild(bar:GetAttribute("For"))
		if not sf then
			return
		end
		local _, viewH = ST.localSize(sf)
		local canvas = sf.CanvasSize.Y.Offset + sf.CanvasSize.Y.Scale * viewH
		local ok, abs = pcall(function()
			return sf.AbsoluteCanvasSize.Y
		end)
		if ok and abs and abs > canvas then
			canvas = abs
		end
		local frac = (canvas > 0) and math.clamp(viewH / canvas, 0.08, 1) or 1
		local at = (canvas > viewH) and math.clamp(sf.CanvasPosition.Y / (canvas - viewH), 0, 1) or 0
		local track = viewH - 8
		bar.Visible = frac < 1
		bar.Size = UDim2.fromOffset(3, math.floor(track * frac + 0.5))
		-- (it leans: lower down, it sits further left, like the panel's edge)
		local y = 4 + (track - bar.Size.Y.Offset) * at
		bar.Position = UDim2.new(sf.Position.X.Scale, sf.Position.X.Offset + sf.Size.X.Offset + 6, sf.Position.Y.Scale, sf.Position.Y.Offset + y)
	end

	---------------------------------------------------------------------------
	-- screen
	---------------------------------------------------------------------------
	local function viewport()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		if not vp or vp.X <= 0 or vp.Y <= 0 then
			return Vector2.new(1280, 720)
		end
		return vp
	end

	-- a phone: touch is the input and the screen's short side is under 500 pt.
	-- It gets its own layout (spec section 7), not a shrunk PC one.
	function ST.isPhone()
		local vp = viewport()
		local touch = HUD.Touch and HUD.Touch.on
		return touch == true and math.min(vp.X, vp.Y) <= tok().Scale.PhoneBelow
	end

	-- THE ONE UIScale RULE for every ScreenGui: on PC / console / tablet the
	-- screen's fit, min(vpX/1280, vpY/720), times Size, kept within Min and Max;
	-- a phone: clamp(vpY/375, 0.85, 1.3)
	-- ((round 101) Size is the owner's one knob (1 = the mockups' size). It
	-- never takes the UI under Readable (11 px type stays 9 real px) unless the
	-- window itself is smaller than that, and never under Min)
	-- ((round 101 review) the knob is the PC's and the console's: a touch
	-- tablet keeps its size (Size 1), so its buttons don't shrink under a thumb)
	function ST.scale()
		local vp = viewport()
		local sc = tok().Scale
		if ST.isPhone() then
			return math.clamp(math.min(vp.X, vp.Y) / sc.PhoneBaseY, sc.PhoneMin, sc.PhoneMax)
		end
		local fit = math.min(vp.X / sc.BaseX, vp.Y / sc.BaseY)
		local least = math.max(math.min(sc.Readable or sc.Min, fit), sc.Min)
		local size = (HUD.Touch and HUD.Touch.on) and 1 or (sc.Size or 1)
		return math.clamp(fit * size, least, math.max(sc.Max, least))
	end

	-- the scaled root of a ScreenGui: a frame 1/s of the screen with a UIScale s,
	-- so its children lay out in 1280x720 units (812x375 on a phone) and scale as
	-- one. Made once per ScreenGui (named StreetRoot).
	function ST.rootOf(gui)
		local root = gui:FindFirstChild("StreetRoot")
		if root then
			return root
		end
		root = make("Frame", {
			Name = "StreetRoot",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = gui,
		})
		make("UIScale", { Name = "StreetScale", Parent = root })
		for i = #ST.roots, 1, -1 do
			local ok, parent = pcall(function()
				return ST.roots[i].Parent
			end)
			if not (ok and parent) then
				table.remove(ST.roots, i) -- (a gui that's gone)
			end
		end
		table.insert(ST.roots, root)
		ST.fitRoot(root)
		return root
	end

	function ST.fitRoot(root)
		local s = ST.scale()
		root.StreetScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end

	-- a ScreenGui of our own with its scaled root: returns gui, root
	function ST.screen(name, order, parent)
		parent = parent or ST.playerGui
		local gui = parent and parent:FindFirstChild(name)
		if not gui then
			gui = make("ScreenGui", {
				Name = name,
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				DisplayOrder = order or 1,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				Parent = parent,
			})
		end
		return gui, ST.rootOf(gui)
	end

	-- (review) a layout that errors says so (a bare pcall swallowed it: a phone
	-- layout that silently never ran)
	local function runLayout(fn, phone, s)
		local ok, err = pcall(fn, phone, s)
		if not ok then
			warn("ST.onLayout: " .. tostring(err))
		end
	end

	-- call fn(phone, scale) now and whenever the layout flips or the scale moves
	-- (a phone turned round, touch switched on). Returns a function that stops it.
	function ST.onLayout(fn)
		table.insert(ST.layouts, fn)
		task.spawn(runLayout, fn, ST.isPhone(), ST.scale())
		return function()
			local i = table.find(ST.layouts, fn)
			if i then
				table.remove(ST.layouts, i)
			end
		end
	end

	-- re-fit every root and tell whoever's listening (the viewport changed, or
	-- touch went on / off: HUD.ApplyTouch calls this)
	function ST.refresh()
		local phone, s = ST.isPhone(), ST.scale()
		for i = #ST.roots, 1, -1 do
			local root = ST.roots[i]
			local ok = pcall(function()
				if root.Parent == nil then
					error("gone")
				end
				ST.fitRoot(root)
			end)
			if not ok then
				table.remove(ST.roots, i)
			end
		end
		local changed = phone ~= ST.lastPhone or s ~= ST.lastScale
		ST.lastPhone, ST.lastScale = phone, s
		if changed then
			for _, fn in table.clone(ST.layouts) do
				task.spawn(runLayout, fn, phone, s)
			end
		end
		if ST.toastNow and ST.toastNow.holder then
			ST.placeToast(ST.toastNow)
		end
		ST.placeLane()
	end

	-- a lane of the screen (spec section 4): y from, y to (1280x720 units; a
	-- phone's own in 812x375 points)
	function ST.lane(name)
		local l = (ST.isPhone() and tok().PhoneLanes or tok().Lanes)[name]
		return l[1], l[2]
	end

	-- the moment lane sits in its lane (the phone's has its own)
	function ST.placeLane()
		if ST.momentLane then
			local y0, y1 = ST.lane("Moment")
			ST.momentLane.Position = UDim2.new(0.5, 0, 0, y0)
			ST.momentLane.Size = UDim2.new(1, 0, 0, y1 - y0)
		end
	end

	-- the combat HUD's own frame in QuirkHUD: what a full menu hides (the
	-- surfaces that make up the fight HUD live in it). ST.hideCombat(key, on):
	-- counted holds, shown again only when the last lets go.
	function ST.combat()
		local c = gui and gui:FindFirstChild("Combat")
		if not c and gui then
			c = make("Frame", {
				Name = "Combat",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = gui,
			})
		end
		return c
	end

	function ST.hideCombat(key, on)
		key = key or "default"
		ST.combatHolds[key] = on and true or nil
		local c = ST.combat()
		if c then
			c.Visible = next(ST.combatHolds) == nil
		end
	end

	-- clean words for a toast: no emoji or symbol glyphs (Oswald hasn't got
	-- them and the style has none), no middots, one kind of dash
	function ST.clean(text)
		local out = {}
		for _, c in utf8.codes(ST.utf8(text)) do
			local drop = (c >= 0x2190 and c <= 0x2BFF) or (c >= 0x1F000) or (c >= 0xFE00 and c <= 0xFE0F) or c == 0x200D
				or (c >= 0x2600 and c <= 0x27BF)
			if c == 0xB7 or c == 0x2022 then
				table.insert(out, " ")
			elseif c == 0x2014 or c == 0x2013 then
				table.insert(out, "-")
			elseif not drop then
				table.insert(out, utf8.char(c))
			end
		end
		local s = table.concat(out)
		s = string.gsub(s, "%s%s%s+", "  ")
		s = string.gsub(s, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		return s
	end

	-- THE TOAST (its own ScreenGui QuirkToasts, DisplayOrder 5, over the top
	-- bar): a paper slab, top centre, an ink message in Oswald and an optional
	-- kicker (RANKED, TIP, EVENT). One at a time, queued. "[Q]" in the message
	-- is drawn as a key cap. opts: Danger (the kicker in red), Keep (keep the
	-- case: the message is in caps otherwise), Hold (seconds).
	function ST.toast(msg, kicker, opts)
		opts = opts or {}
		msg = ST.clean(msg)
		if msg == "" then
			return
		end
		if not opts.Keep then
			msg = string.upper(msg)
		end
		kicker = kicker and string.upper(ST.clean(kicker)) or nil
		local T = tok().Toast
		local key = (kicker or "") .. "|" .. msg
		table.insert(ST.toastLog, 1, { Text = msg, Kicker = kicker, At = os.clock() })
		while #ST.toastLog > T.Recent do
			table.remove(ST.toastLog)
		end
		if ST.toastNow and ST.toastNow.Key == key then
			return -- (the same thing again: once is enough)
		end
		for _, q in ST.toastQ do
			if q.Key == key then
				return
			end
		end
		seq += 1
		table.insert(ST.toastQ, { Key = key, Text = msg, Kicker = kicker, Danger = opts.Danger, Hold = opts.Hold, Seq = seq })
		while #ST.toastQ > T.Queue do
			table.remove(ST.toastQ, 1) -- (the oldest waiting one goes)
		end
		if ST.toastNow then
			-- someone's waiting: the one up now cuts its hold short
			local now = ST.toastNow
			if now.LeaveAt and now.LeaveAt - os.clock() > T.HoldBusy then
				ST.scheduleToastOut(now, T.HoldBusy)
			end
		else
			ST.nextToast()
		end
	end

	-- drop every toast (the one up and the waiting ones)
	function ST.clearToasts()
		local now = ST.toastNow
		ST.toastNow = nil
		table.clear(ST.toastQ)
		if now then
			now.Token = (now.Token or 0) + 1
			if now.holder then
				pcall(function()
					now.holder:Destroy()
				end)
			end
		end
	end

	-- is this text on a toast now, waiting, or shown lately? (any case)
	function ST.toastSays(text)
		text = string.upper(tostring(text))
		local function has(s)
			return s and string.find(string.upper(s), text, 1, true) ~= nil
		end
		if ST.toastNow and (has(ST.toastNow.Text) or has(ST.toastNow.Kicker)) then
			return true
		end
		for _, q in ST.toastQ do
			if has(q.Text) or has(q.Kicker) then
				return true
			end
		end
		for _, q in ST.toastLog do
			if has(q.Text) or has(q.Kicker) then
				return true
			end
		end
		return false
	end

	local function buildToast(item)
		local T = tok().Toast
		local phone = ST.isPhone()
		local h = phone and T.PhoneH or T.H
		local size = phone and T.PhoneText or T.Text
		local ksize = phone and T.PhoneKicker or T.Kicker
		local l = h * ST.lean()
		local holder = make("Frame", {
			Name = "Toast",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Parent = ST.toastRoot,
		})
		-- the message's parts: words, and [X] key caps
		local parts = {}
		local rest = item.Text
		while true do
			local a, b, k = string.find(rest, "%[(%w+)%]")
			if not a then
				break
			end
			if a > 1 then
				table.insert(parts, { Text = string.sub(rest, 1, a - 1) })
			end
			table.insert(parts, { Key = k })
			rest = string.sub(rest, b + 1)
		end
		if rest ~= "" then
			table.insert(parts, { Text = rest })
		end
		local x = l + 10
		local items = {}
		local function lay()
			table.clear(items)
			local total = l + 10 + 14 + l
			if item.Kicker then
				table.insert(items, { Kind = "Kicker", Text = item.Kicker, W = ST.measure(item.Kicker, ksize) })
				total += items[#items].W + 12
			end
			for _, part in parts do
				if part.Key then
					local kh = math.floor(h * 0.62 + 0.5)
					table.insert(items, { Kind = "Key", Text = part.Key, H = kh, W = math.max(kh * 0.92, ST.measure(part.Key, kh * 0.78) + kh * ST.lean() * 2 + 4) })
				else
					table.insert(items, { Kind = "Text", Text = part.Text, W = ST.measure(part.Text, size) })
				end
				total += items[#items].W + 6
			end
			return total
		end
		-- too long for the screen: smaller words (down to the minimum), then cut short
		local room = (phone and 812 or 1280) - 120
		local total = lay()
		local minimum = phone and tok().Sizes.PhoneMinimum or tok().Sizes.Minimum
		if total > room and size > minimum then
			size = math.max(minimum, math.floor(size * room / total))
			total = lay()
		end
		while total > room do
			local longest
			for _, it in items do
				if it.Kind == "Text" and (not longest or it.W > longest.W) then
					longest = it
				end
			end
			if not longest or #longest.Text <= 4 then
				break
			end
			-- (review: ST.utf8 - a byte cut can split a name's accented letter)
			local cut = ST.utf8(string.sub(longest.Text, 1, math.max(1, #longest.Text - 4)))
			for _, part in parts do
				if part.Text == longest.Text then
					part.Text = string.gsub(cut, "%.*$", "") .. "..."
					break
				end
			end
			total = lay()
		end
		-- (review: ZIndex 2, over the slab for sure - a tie is drawn in parenting order)
		local body = make("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = holder })
		for i, it in items do
			if it.Kind == "Kicker" then
				ST.label({ Name = "Kicker", Text = it.Text, Size = ksize, Color = item.Danger and tok().Red or tok().Ash, Pos = UDim2.new(0, x, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = body })
				x += it.W + 12
			elseif it.Kind == "Key" then
				ST.keyCap(it.Text, it.H, { Name = "Key" .. i, Ink = true, Pos = UDim2.new(0, x, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = body })
				x += it.W + 6
			else
				ST.label({ Name = "Message", Text = it.Text, Size = size, Color = tok().Ink, Pos = UDim2.new(0, x, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = body })
				x += it.W + 6
			end
		end
		local w = math.floor(x - 6 + 14 + l + 0.5)
		holder.Size = UDim2.fromOffset(w, h)
		ST.slab({ Name = "Back", Size = { w, h }, Color = tok().Paper, T = 0, Z = 1, Parent = holder })
		body.Parent = holder -- (after the slab: on top)
		return holder
	end

	function ST.placeToast(item)
		local T = tok().Toast
		local y = ST.isPhone() and T.PhoneY or T.Y
		item.Y = y
		if item.holder and item.State == "hold" then
			item.holder.Position = UDim2.new(0.5, 0, 0, y)
		end
	end

	function ST.scheduleToastOut(item, after)
		local T = tok().Toast
		item.Token = (item.Token or 0) + 1
		local token = item.Token
		item.LeaveAt = os.clock() + after
		task.delay(after, function()
			if item.Token ~= token or ST.toastNow ~= item then
				return
			end
			item.State = "out"
			local h = item.holder
			if h and h.Parent then
				ST.tween(h, T.Out, { Position = UDim2.new(0.5, 0, 0, item.Y - T.Drop) })
				for _, d in h:GetDescendants() do
					if d:IsA("TextLabel") then
						ST.tween(d, T.Out, { TextTransparency = 1 })
					elseif d:IsA("Frame") and string.sub(d.Name, 1, 2) == "_P" then
						ST.tween(d, T.Out, { BackgroundTransparency = 1 })
					elseif d:IsA("ImageLabel") then
						-- (review: the wedge ends and the key caps' sheet letters go with it)
						ST.tween(d, T.Out, { ImageTransparency = 1 })
					end
				end
			end
			task.delay(T.Out, function()
				if item.Token ~= token then
					return
				end
				if h then
					pcall(function()
						h:Destroy()
					end)
				end
				if ST.toastNow == item then
					ST.toastNow = nil
					ST.nextToast()
				end
			end)
		end)
	end

	function ST.nextToast()
		if not ST.toastRoot then
			ST.toastNow = nil -- (not started yet: they wait for ST.init)
			return
		end
		local item = table.remove(ST.toastQ, 1)
		ST.toastNow = item
		if not item then
			return
		end
		local T = tok().Toast
		item.holder = buildToast(item)
		ST.placeToast(item)
		item.State = "hold"
		-- drops 8 px over 0.1 s (and lands there for sure)
		item.holder.Position = UDim2.new(0.5, 0, 0, item.Y - T.Drop)
		ST.tween(item.holder, T.In, { Position = UDim2.new(0.5, 0, 0, item.Y) })
		ST.scheduleToastOut(item, T.In + (#ST.toastQ > 0 and T.HoldBusy or (item.Hold or T.Hold)))
	end

	-- HUD.Notice's way in (every older caller): the colour only says whether
	-- it's bad news; "WORD: the rest" becomes a kicker
	function ST.notice(text, color)
		local s = ST.clean(text)
		local kicker, rest = string.match(s, "^([%u][%u ]+):%s+(.+)$")
		if kicker and #kicker <= 16 then
			s = rest
		else
			kicker = nil
		end
		if string.match(s, "^RANKED DUEL") then
			kicker = kicker or "RANKED"
		end
		local danger = typeof(color) == "Color3" and color.R > 0.85 and color.G < 0.62 and color.B < 0.62
		ST.toast(s, kicker, { Danger = danger })
	end

	-- THE MOMENT LANE (centre, y 200-470): K.O. > rank-up > callout > NEW HERO,
	-- one at a time. build(lane) puts its pieces in the lane frame it's given
	-- and returns how long it holds (seconds) and optionally a cleanup function;
	-- the lane is cleared after. A moment that waited past its Wait is dropped.
	-- kind: "KO", "RankUp", "Callout", "NewHero" (or any: priority 5).
	function ST.moment(kind, build, opts)
		opts = opts or {}
		local M = tok().Moments
		seq += 1
		table.insert(ST.momentQ, {
			Kind = kind,
			Prio = M.Priority[kind] or 5,
			Build = build,
			At = os.clock(),
			Wait = opts.Wait or M.Wait[kind] or 5,
			Seq = seq,
		})
		while #ST.momentQ > M.Queue do
			-- the least important, newest one goes
			local worst = 1
			for i, q in ST.momentQ do
				local w = ST.momentQ[worst]
				if q.Prio > w.Prio or (q.Prio == w.Prio and q.Seq > w.Seq) then
					worst = i
				end
			end
			table.remove(ST.momentQ, worst)
		end
		if not ST.momentNow then
			ST.nextMoment()
		end
	end

	function ST.nextMoment()
		local now = os.clock()
		for i = #ST.momentQ, 1, -1 do
			local q = ST.momentQ[i]
			if now - q.At > q.Wait then
				table.remove(ST.momentQ, i) -- (stale: a PARRY! from a while ago means nothing)
			end
		end
		local best
		for i, q in ST.momentQ do
			if not best or q.Prio < ST.momentQ[best].Prio or (q.Prio == ST.momentQ[best].Prio and q.Seq < ST.momentQ[best].Seq) then
				best = i
			end
		end
		if not best or not ST.momentLane then
			ST.momentNow = nil
			return
		end
		local item = table.remove(ST.momentQ, best)
		ST.momentNow = item
		local holder = make("Frame", {
			Name = "Moment" .. item.Kind,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = ST.momentLane,
		})
		item.holder = holder
		local ok, hold, cleanup = pcall(item.Build, holder)
		if not ok then
			warn("moment " .. tostring(item.Kind) .. ": " .. tostring(hold))
			hold = 0
		end
		item.cleanup = cleanup
		task.delay(math.max(tonumber(hold) or 1.2, 0), function()
			ST.endMoment(item)
		end)
	end

	-- end the current moment now (or the given one, if it's still up)
	function ST.endMoment(item)
		item = item or ST.momentNow
		if not item or ST.momentNow ~= item then
			return
		end
		if type(item.cleanup) == "function" then
			pcall(item.cleanup)
		end
		if item.holder then
			item.holder:Destroy()
		end
		ST.momentNow = nil
		ST.nextMoment()
	end

	-- THE B/W WORLD (ults, the K.O. screen): Lighting's ColorCorrection, held by
	-- keys - two holders at once are fine, and the world comes back only when
	-- the last lets go, exactly as it was (the effect is ours alone, and goes).
	function ST.mono(on, key)
		key = key or "default"
		if on then
			if ST.monoHolds[key] then
				return
			end
			ST.monoHolds[key] = true
		else
			if not ST.monoHolds[key] then
				return
			end
			ST.monoHolds[key] = nil
		end
		local M = tok().Mono
		local held = next(ST.monoHolds) ~= nil
		local cc = Lighting:FindFirstChild("StreetMono")
		ST.monoToken = (ST.monoToken or 0) + 1
		local token = ST.monoToken
		if held then
			if not cc then
				cc = make("ColorCorrectionEffect", { Name = "StreetMono", Saturation = 0, Contrast = 0, Brightness = 0, Parent = Lighting })
			end
			cc.Enabled = true
			ST.tween(cc, M.In, { Saturation = M.Saturation, Contrast = M.Contrast, Brightness = M.Brightness }, Enum.EasingStyle.Linear)
		elseif cc then
			ST.tween(cc, M.Out, { Saturation = 0, Contrast = 0, Brightness = 0 }, Enum.EasingStyle.Linear)
			task.delay(M.Out, function()
				if ST.monoToken == token and next(ST.monoHolds) == nil then
					cc:Destroy()
				end
			end)
		end
	end

	function ST.monoHeld()
		local n = 0
		for _ in ST.monoHolds do
			n += 1
		end
		return n
	end

	---------------------------------------------------------------------------
	-- motion: snap, hold, settle
	---------------------------------------------------------------------------
	-- a tween that lands its end state for sure (even if frames are skipped or
	-- the object was hidden), unless a newer ST.tween on the same object took over
	function ST.tween(obj, time, props, style, dir)
		local n = (obj:GetAttribute("StTween") or 0) + 1
		obj:SetAttribute("StTween", n)
		local tw = tween(obj, time, props, style or Enum.EasingStyle.Quint, dir)
		task.delay(time + 0.03, function()
			pcall(function()
				if obj:GetAttribute("StTween") == n and obj.Parent then
					for k, v in props do
						obj[k] = v
					end
				end
			end)
		end)
		return tw
	end

	-- the offset a slide starts from: along the lean, from the left and a bit below
	local function along(dist)
		return -dist, dist * ST.lean()
	end

	-- slide in to target (a UDim2) along the lean over time (Quint Out)
	function ST.slideIn(obj, target, time, dist)
		local M = tok().Motion
		local dx, dy = along(dist or M.Slide)
		obj.Position = target + UDim2.fromOffset(dx, dy)
		return ST.tween(obj, time or M.MenuIn, { Position = target }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	-- and back out the same way (from where it is)
	function ST.slideOut(obj, from, time, dist)
		local M = tok().Motion
		local dx, dy = along(dist or M.Slide)
		return ST.tween(obj, time or M.MenuOut, { Position = from + UDim2.fromOffset(dx, dy) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end

	-- a stamp: from a touch bigger (1.12) to its size in 0.06 s, then it holds
	function ST.stamp(obj, from, time)
		local M = tok().Motion
		local sc = obj:FindFirstChild("Stamp") or make("UIScale", { Name = "Stamp", Parent = obj })
		sc.Scale = from or M.StampFrom
		return ST.tween(sc, time or M.Stamp, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	-- a slab's paper flash (a move coming back): paper for 0.12 s, then its own colour
	function ST.flash(slab, time)
		local base, t = slab:GetAttribute("StColor"), slab:GetAttribute("StT")
		if slab:GetAttribute("StFlashing") then
			return
		end
		slab:SetAttribute("StFlashing", true)
		ST.paint(slab, tok().Paper, 0)
		task.delay(time or tok().Motion.Flash, function()
			slab:SetAttribute("StFlashing", nil)
			ST.paint(slab, base, t)
		end)
	end

	---------------------------------------------------------------------------
	-- THE PANEL: a big leaning menu sheet. p: Name, Parent (a root), X (the top
	-- edge's left x), W (its width at the top), Top, Bottom (y), Ends ("Both";
	-- "Right": a sheet from the screen's left edge), T (0.05), Margin (36),
	-- Scrim (true: the world dims), HideCombat (true), Z. Returns the holder
	-- (children Scrim, Sheet, Sheet.Content). ST.openPanel / ST.closePanel;
	-- ST.leanX(panel, y): where the content's leaning margin is at y.
	function ST.panel(p)
		p = p or {}
		local top, bottom = p.Top or 66, p.Bottom or 700
		local h = bottom - top
		local l = h * ST.lean()
		local holder = make("Frame", {
			Name = p.Name or "Panel",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = p.Z or 10,
			Parent = p.Parent,
		})
		holder:SetAttribute("Top", top)
		holder:SetAttribute("Bottom", bottom)
		holder:SetAttribute("Margin", p.Margin or 36)
		holder:SetAttribute("HideCombat", p.HideCombat ~= false)
		make("Frame", {
			Name = "Scrim",
			BackgroundColor3 = tok().Ink,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = p.Scrim ~= false,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
		-- the box: the top edge runs X .. X + W, the bottom one is shifted left by l
		local x0 = (p.X or 236) - l
		local sheet = ST.slab({
			Name = "Sheet",
			Size = { math.floor((p.W or 940) + l + 0.5), h },
			Pos = UDim2.fromOffset(math.floor(x0 + 0.5), top),
			Color = tok().Ink,
			T = p.T or tok().MenuT,
			Ends = p.Ends or "Both",
			Z = holder.ZIndex,
			Parent = holder,
		})
		holder:SetAttribute("SheetX", math.floor(x0 + 0.5))
		make("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = holder.ZIndex + 1,
			Parent = sheet,
		})
		return holder
	end

	-- the content's leaning left margin at y (screen y, root units), in the
	-- sheet's own x: margin + (bottom - y) * tan(12)
	function ST.leanX(panel, y)
		local bottom = panel:GetAttribute("Bottom")
		return panel:GetAttribute("Margin") + (bottom - y) * ST.lean()
	end

	function ST.openPanel(panel)
		local M = tok().Motion
		panel:SetAttribute("Open", true)
		local n = (panel:GetAttribute("Turn") or 0) + 1
		panel:SetAttribute("Turn", n)
		panel.Visible = true
		local sheet, scrim = panel.Sheet, panel.Scrim
		local target = UDim2.fromOffset(panel:GetAttribute("SheetX"), panel:GetAttribute("Top"))
		ST.slideIn(sheet, target, M.MenuIn)
		ST.tween(scrim, M.Dim, { BackgroundTransparency = tok().ScrimT }, Enum.EasingStyle.Linear)
		-- the rows come in all at once, a beat after the sheet
		sheet.Content.Visible = false
		task.delay(M.RowsAfter, function()
			if panel:GetAttribute("Turn") == n and panel:GetAttribute("Open") then
				sheet.Content.Visible = true
			end
		end)
		if panel:GetAttribute("HideCombat") then
			ST.hideCombat(panel.Name, true)
		end
	end

	function ST.closePanel(panel)
		local M = tok().Motion
		if not panel:GetAttribute("Open") then
			return
		end
		panel:SetAttribute("Open", false)
		local n = (panel:GetAttribute("Turn") or 0) + 1
		panel:SetAttribute("Turn", n)
		local target = UDim2.fromOffset(panel:GetAttribute("SheetX"), panel:GetAttribute("Top"))
		ST.slideOut(panel.Sheet, target, M.MenuOut)
		ST.tween(panel.Scrim, M.Dim, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		ST.hideCombat(panel.Name, false)
		task.delay(M.MenuOut, function()
			if panel:GetAttribute("Turn") == n then
				panel.Visible = false
				panel.Sheet.Position = target
			end
		end)
	end

	function ST.panelOpen(panel)
		return panel:GetAttribute("Open") == true
	end

	---------------------------------------------------------------------------
	-- start: the toast and moment screens, and the scale following the screen
	function ST.init(playerGui)
		ST.playerGui = playerGui
		local _, troot = ST.screen("QuirkToasts", tok().Toast.Order, playerGui)
		ST.toastRoot = troot
		local _, mroot = ST.screen("QuirkMoments", tok().Moments.Order, playerGui)
		local y0, y1 = ST.lane("Moment")
		ST.momentLane = make("Frame", {
			Name = "Lane",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y0),
			Size = UDim2.new(1, 0, 0, y1 - y0),
			Parent = mroot,
		})
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(ST.refresh)
		end
		ST.lastPhone, ST.lastScale = ST.isPhone(), ST.scale()
		if not ST.toastNow and #ST.toastQ > 0 then
			ST.nextToast() -- (any that came before the screens did)
		end
	end
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
	-- (round 100) the Stark Street kit: the toast and moment screens, the scale rule
	ST.init(playerGui)
	make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = flashGui,
	})

	-- the scales follow the screen (a phone to a 4K monitor)
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local vp = cam.ViewportSize
			if HUD.Touch and HUD.Touch.on then
				HUD.Touch.place() -- (a phone turned round, a tablet split-screened)
				HUD.FH.layout() -- ((round 100) a new scale: the phone's own layout again)
			elseif vp.Y > 0 then
				for _, sc in autoScales do
					sc.Scale = ST.scale() -- ((round 101) the one rule: the size knob)
				end
			end
		end)
	end

	-- (round 100) the fight HUD, Stark Street: the dock (the vitals and the
	-- move slots) in the combat frame's scaled root (HUD.FH, before
	-- HUD.InitFight); every frame its hatches, seconds, ult and tabs
	HUD.FH.build(player)
	RunService.RenderStepped:Connect(HUD.FH.step)

	HUD.BuildMenu()
	HUD.BuildTopBar(playerGui)
	HUD.InitFight(player)
end

---------------------------------------------------------------------------

function HUD.BindHumanoid(hum)
	if healthConn then
		healthConn:Disconnect()
	end
	-- ((round 100) Stark Street: a PAPER fill, RED under 25%; the chip is RED,
	-- holds 0.4 s and drains 0.3 s; the numbers swap at once - HUD.FH.health)
	local function update()
		HUD.FH.health(hum.Health, hum.MaxHealth)
	end
	healthConn = hum.HealthChanged:Connect(update)
	update()
end

-- what Crazy Diamond's BUILD makes right now (the client keeps it current)
HUD.Blueprint = nil

-- alt = second side/form, ult = G ultimate active, pick = which of the
-- quirk's 4th moves is picked. resetCooldowns on quirk change only.
-- (round 100) Stark Street: the name on the slash (its colour the hero's),
-- the mode small over it, the moves' names on their slots; no hero: PICK A
-- HERO and the move row hidden (audit #18). No hero-colour tint on the
-- slots any more: the slash is the only colour.
function HUD.SetQuirk(quirkName, alt, resetCooldowns, ult, pick)
	local FH = HUD.FH
	if HUD.MarkHero then
		HUD.MarkHero(quirkName) -- (the top bar's button, the phone)
	end
	local view = Config.GetView(quirkName, alt, ult, pick)
	local quirk = quirkName and Config.Quirks[quirkName]
	ultName = quirk and quirk.Ult and quirk.Ult.Name or "ULT"
	if view then
		accent = view.Color:Lerp(Color3.new(1, 1, 1), 0.15)
	end
	FH.setHero(view)
	-- (round 88) the bar's words now, not at the meter's next change (a
	-- switch at 0% kept the last hero's ult name)
	if HUD.ultLast then
		HUD.SetUltMeter(HUD.ultLast[1], HUD.ultLast[2])
	end
	if view then
		for i = 1, 3 do
			local slot = slots[i]
			local ability = view.Abilities[i]
			local text = ability and ability.Name or "-"
			if ability and ability.Blueprint then
				-- (Crazy Diamond's BUILD says what it'll make: V changes it)
				local first = quirk and quirk.Blueprints and quirk.Blueprints[1] or "Wall"
				text = ability.Name .. ": " .. string.upper(HUD.Blueprint or first)
			end
			FH.setName(slot, text)
			slot.BoundKey = Config.CooldownKey(quirkName, i, alt, ult)
		end
		if view.Special then
			specialSlot.Frame.Visible = true
			specialSlot.BoundKey = Config.CooldownKey(quirkName, Config.SPECIAL_INDEX, alt, ult)
			local text = view.OtherModeName or view.Special.Name
			if view.Special.Cycle and view.NextExtra then
				text = "NEXT: " .. view.NextExtra.Name -- (Deku: what R puts in the 4th slot)
			end
			FH.setName(specialSlot, text)
		else
			specialSlot.Frame.Visible = false
			specialSlot.BoundKey = nil
		end
		if view.Extra then
			extraSlot.Frame.Visible = true
			extraSlot.BoundKey = Config.CooldownKey(quirkName, Config.EXTRA_INDEX, alt, ult, pick)
			FH.setName(extraSlot, view.Extra.Name)
		else
			extraSlot.Frame.Visible = false
			extraSlot.BoundKey = nil
		end
		FH.moves(true)
	else
		for i = 1, 4 do
			FH.setName(slots[i], "-")
			slots[i].BoundKey = nil
		end
		specialSlot.Frame.Visible = false
		extraSlot.Frame.Visible = false
		extraSlot.BoundKey = nil
		FH.moves(false)
	end
	if resetCooldowns then
		HUD.ResetCooldowns()
	end
	if HUD.HawksBar then
		HUD.HawksBar(quirkName, alt, ult) -- (round 92, hawksair: Hawks flying - R says LAND; carrying - 1-4 are the follow-ups)
	end
end

-- (round 100) THE RESOURCE LINE, one at a time over the health bar: a thin
-- paper fill on ink and ONE word at its right (SWEAT, HEAT, STOMACH,
-- FEATHERS, MARBLES 2/3), RED when it's trouble. The how-tos that used to
-- ride along ("HOLD DASH: FLY", "R TO EAT") are one-time TIP toasts. nil
-- hides a meter; HUD.Pips / HUD.Stomach / HUD.Heat / HUD.Feathers /
-- HUD.Sweat are each meter's { Bar, Fill, Text } as before.

-- A row of pips (nil hides it): Mr. Compress's marbles, Chargebolt's
-- pointers - segments, one a pip. spec = { Label, Count, Max, Color, Hint }
function HUD.SetPips(spec)
	local FH = HUD.FH
	if spec == nil then
		FH.setRes("Pips", nil)
		return
	end
	if not vitals then
		return
	end
	local max, count = spec.Max or 3, spec.Count or 0
	local rt = FH.res("Pips")
	rt.max = max
	if rt.pipsMax ~= max then
		FH.buildPips(rt)
	end
	FH.setRes("Pips", count / math.max(max, 1), string.format("%s %d/%d", string.upper(spec.Label or ""), count, max), count == 0)
	if count == 0 and spec.Hint then
		-- ("R: POCKET A PIECE OF THE STREET" -> [R] POCKET A PIECE OF THE STREET)
		local hint = string.gsub(spec.Hint, "^(%w):%s*", "[%1] ")
		FH.tip("Pips" .. tostring(spec.Label), hint)
	end
end

-- SUNEATER's stomach (nil hides it): what his manifestations run on (low:
-- they're weaker - eat something, R)
function HUD.SetStomach(value)
	local FH = HUD.FH
	if value == nil or not vitals then
		FH.setRes("Stomach", nil)
		return
	end
	value = math.clamp(value, 0, 100)
	local hungry = value < 25
	FH.setRes("Stomach", value / 100, hungry and "HUNGRY" or "STOMACH", hungry, 0.2)
	if hungry then
		FH.tip("Hungry", Config.UI.Hud.Tips.Hungry)
	end
end

-- ENDEAVOR's heat (nil hides it): filling as he uses fire; OVERHEATED at the top
function HUD.SetHeat(value, overheated)
	local FH = HUD.FH
	if value == nil or not vitals then
		FH.setRes("Heat", nil)
		return
	end
	value = math.clamp(value, 0, 100)
	FH.setRes("Heat", value / 100, overheated and "OVERHEATED" or "HEAT", overheated or value >= 75, 0.15)
	if overheated then
		FH.tip("Overheated", Config.UI.Hud.Tips.Overheated)
	end
end

-- (round 86) HAWKS' feathers (nil hides it): his wings ARE his ammo. Out of
-- max (150 in the ult); what he just spent stays ash a moment, then drains;
-- the word: FEATHERS, PLUCKED at 0, ALL OUT in the storm, OVERGROWTH over 100;
-- RED when it's thin; a RED beat as fire burns them. state = { Plucked,
-- Flying, Storm, Low, Burned } (Storm: the Thousand-Feather Storm has every
-- one of them out - "ALL OUT", not plucked, and no beat: round 86 review)
function HUD.SetFeathers(value, max, state)
	local FH = HUD.FH
	if value == nil or not vitals then
		local rt = FH.setRes("Feathers", nil)
		if rt then
			rt.before = nil
		end
		return
	end
	state = state or {}
	max = math.max(tonumber(max) or 100, 1)
	value = math.clamp(value, 0, max)
	local ratio = value / max
	local storm = state.Storm == true and state.Plucked ~= true
	local plucked = not storm and (state.Plucked == true or value <= 0)
	local low = not plucked and not storm and value < (state.Low or 20)
	local over = max > 100 and value > 100
	local word = storm and "ALL OUT" or plucked and "PLUCKED" or over and "OVERGROWTH" or "FEATHERS"
	local rt = FH.res("Feathers")
	local before = rt.before
	rt.before = value
	FH.setRes("Feathers", ratio, word, plucked or low, 0.12)
	-- the chip: what he just spent stays a moment, then drains after it
	rt.token = (rt.token or 0) + 1
	local token = rt.token
	if rt.Chip then
		if before == nil or value >= before then
			rt.chip = ratio
			ST.setFill(rt.Chip, ratio)
		else
			task.delay(0.35, function()
				if rt.token == token and rt.Chip then
					rt.chip = ratio
					ST.setFill(rt.Chip, ratio, 0.3, Enum.EasingStyle.Quad)
				end
			end)
		end
	end
	-- a RED beat as fire burns them, or as the last of them goes
	if rt.Flash and (state.Burned or (plucked and before and before > 0)) then
		ST.paintFill(rt.Flash, Config.UI.Street.Red, 0.25)
		rt.Flash:SetAttribute("Beat", (rt.Flash:GetAttribute("Beat") or 0) + 1)
		local beat = rt.Flash:GetAttribute("Beat")
		task.delay(0.3, function()
			if rt.Flash and rt.Flash:GetAttribute("Beat") == beat then
				ST.paintFill(rt.Flash, Config.UI.Street.Red, 1)
			end
		end)
	end
	if plucked and not storm then
		FH.tip("Plucked", Config.UI.Hud.Tips.Plucked)
	end
end

-- (round 73) BAKUGO's sweat (nil hides it): what his explosion flight runs
-- on (hold the dash key); it fills back up on the ground
function HUD.SetSweat(value, flying)
	local FH = HUD.FH
	if value == nil or not vitals then
		FH.setRes("Sweat", nil)
		return
	end
	value = math.clamp(value, 0, 100)
	local dry = value < 18
	FH.setRes("Sweat", value / 100, dry and "DRIED UP" or "SWEAT", dry)
	FH.tip("Sweat", string.format(Config.UI.Hud.Tips.Sweat, FH.keyWord(keyText.Dash or "Q")))
	if dry and not flying then
		FH.tip("DriedUp", Config.UI.Hud.Tips.DriedUp)
	end
end

-- the ragdoll cancel's meter (EVADE: one solid bar beside the guard's
-- segments); full while you're down, its word says the key that gets you out
function HUD.SetEvasive(value, ragdolled)
	local FH = HUD.FH
	if not (HUD.Evasive and HUD.Evasive.Bar) then
		return
	end
	FH.state.evade = { Value = math.clamp(value or 0, 0, 100), Ragdolled = ragdolled == true }
	FH.drawEvade()
end

-- the ult meter IS the slash under your name (round 100): it paints in as
-- it charges, the % after it; full: the key and the ult's name; up: it
-- drains back over the ult (HUD.SetModeTimer) and the seconds count down
function HUD.SetUltMeter(value, active)
	value = math.clamp(value or 0, 0, 100)
	HUD.ultLast = { value, active }
	local FH = HUD.FH
	local was = ultReady
	FH.state.ult = value
	FH.state.active = active == true
	if not active then
		FH.state.timer = nil
	end
	FH.drawUlt(true)
	if ultReady ~= was and HUD.SetTouchUlt then
		HUD.SetTouchUlt(ultReady)
	end
end

-- Full-screen ult banner: the shout across a band of speed lines
function HUD.UltBanner(view, shout, beats)
	-- (round 100) Stark Street's ult cut-in (HUD.MO.ult): the world black and
	-- white, the letterbox snapping in, one huge slash in the hero's colour, the
	-- ult's name at +6 degrees, the shout in marker, whose it is in the bar
	-- ((round 101) beats: the awakening's own timing - VFX.AK fires it on the
	-- pose's hit with Config.Awaken.CutIn; nil: Config.UI.Moments.Cut's)
	return HUD.MO.ult(view, shout, beats)
end
-- (round 101) the ult cut-in off now (an awakening called off mid-way)
function HUD.UltBannerOff()
	return HUD.MO.cutOff("ult")
end

-- ends is in server time (workspace:GetServerTimeNow()); pass nil to hide.
-- (round 100) No bar of its own any more (audit #4: it sat on the resource
-- line): the ult's time ("ULT: ...") drains the slash, its seconds after it;
-- a form's (All Might's muscle form) drains a paper line along R's foot, its
-- seconds top right in R when R isn't cooling.
function HUD.SetModeTimer(ends, length, color, label)
	local FH = HUD.FH
	if not ends or not length or length <= 0 then
		timerEnds = nil
		FH.state.form = nil
		FH.ultTimer(nil)
		return
	end
	timerEnds, timerLength = ends, length
	timerLabel = label or ""
	timerColor = color or Color3.fromRGB(255, 212, 64)
	if string.sub(timerLabel, 1, 4) == "ULT:" then
		FH.state.form = nil
		FH.ultTimer(ends, length)
	else
		FH.state.form = { Ends = ends, Length = length }
		FH.ultTimer(nil)
	end
end

-- ((round 100) left: optional, a cooldown picked up part-way - how much of
-- it is still to go; the hatch starts that far along)
function HUD.StartCooldown(key, length, left)
	cooldowns[key] = { Ends = os.clock() + (left or length), Length = length }
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

-- ((round 100 review) the corners' table went with them)
function HUD.CutIn(quirk, moveName)
	-- (round 100) the corner cut-ins are gone (Stark Street: they covered the
	-- wallet, the feed and the R / 4 slots; the ult's cut-in is the one
	-- full-screen moment now). The moves' CutIn flag stays in the data.
	return nil
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

-- (round 100) THE TOP BAR, Stark Street (spec section 4): its own ScreenGui
-- over the menus, on the one UIScale rule. Leaning ink tabs from where
-- Roblox's buttons end - HEROES M, EMOTES B, SHOP H, RANKED, TOP L, the gear
-- (and TEST P for testers) - the only route into each menu, the open one
-- paper; the wallet and rank top right (HUD.FH.placeTop / buildCorner).
-- CHARACTER / the phone pill and EMOTES' emoji pill are gone.
function HUD.BuildTopBar(playerGui)
	local FH = HUD.FH
	if FH.topRoot then
		return
	end
	local top = make("ScreenGui", {
		Name = "QuirkTopBar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	FH.topRoot = ST.rootOf(top)
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

-- line the bar up with Roblox's buttons (and the wallet / rank top right);
-- the phone, while it's still the phone, hangs under it
function HUD.PlaceTopBar()
	if not HUD.FH.topRoot then
		return
	end
	HUD.FH.placeTop()
	local x, y, h = topInset()
	if menu and menu:IsA("CanvasGroup") then
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

-- the tabs' key hints follow the input: a keyboard's only (not on touch or
-- a controller; the bar's laid out again without them)
function HUD.SetTopBarKeys(mode)
	local FH = HUD.FH
	local keys = mode == "Keyboard"
	if FH.keys ~= keys then
		FH.keys = keys
		HUD.PlaceTopBar()
		FH.fitName() -- (PICK A HERO's key)
	end
end

-- ((round 100) the DISCORD tab: shown only to a player Roblox lets see Discord
-- links (QuirkClient's DiscordClient asks PolicyService, then calls this);
-- HUD.OnDiscordTab opens the card)
function HUD.SetDiscordTab(on)
	if HUD.FH then
		HUD.FH.discordOn = on == true
		if HUD.FH.syncTabs then
			HUD.FH.syncTabs(true)
		end
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

---------------------------------------------------------------------------
-- (round 100) THE MENUS' ONE ROUTE. Each menu opens from its tab on the top
-- bar (ui_hud builds the bar): HUD.MenuRoute(id) toggles the menu for a tab,
-- HUD.OpenMenuId() says which tab's menu is open (nil: none) and
-- HUD.OnMenuChanged(fn) calls fn(id or nil) now and whenever that changes, so
-- the bar can light the open tab. Ids, left to right (HUD.MenuOrder()):
-- Heroes, Emotes, Shop, Ranked, Top, Settings. One full menu at a time:
-- opening one closes the rest. HUD.MenuOpen(): any menu is up, the emote
-- picker too (the touch pad steps aside; the full sheets also hide the combat
-- HUD - ST.panel). The menus
-- live in QuirkHUD.Menus (ZIndex 50, over the HUD) on one scaled root.
---------------------------------------------------------------------------
HUD.Menus = { closers = {}, cur = nil, fns = {} }
do
	local MN = HUD.Menus
	-- which tab each menu belongs to (the outfit window is reached from HEROES)
	MN.TAB = { Picker = "Heroes", Outfits = "Heroes", Wheel = "Emotes", Shop = "Shop", Ranked = "Ranked", Board = "Top", Settings = "Settings" }

	-- the menus' scaled root (1280 x 720 units, 812 x 375 on a phone)
	function MN.root()
		local holder = gui:FindFirstChild("Menus")
		if not holder then
			holder = make("Frame", {
				Name = "Menus",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 50,
				Parent = gui,
			})
		end
		return HUD.ST.rootOf(holder)
	end

	-- (round 100 review) the room the menus have, in the root's units (the
	-- screen over the one UIScale): 1280 x 720 on a 16:9 PC, but wider on a
	-- wide window and taller on a 4:3 tablet (1280 x 960), and about 812 x 375
	-- on a phone (a 16:9 phone is only 667 wide). Layouts anchor to this, not
	-- to the mockups' 1280 x 720.
	function MN.view()
		local vp
		pcall(function()
			vp = workspace.CurrentCamera.ViewportSize
		end)
		if typeof(vp) ~= "Vector2" or vp.X <= 0 or vp.Y <= 0 then
			vp = Vector2.new(1280, 720)
		end
		local s = HUD.ST.scale()
		return vp.X / s, vp.Y / s
	end
	-- what a menu was laid out for (it's made again when this changes): a
	-- phone's width and height; on PC only the height (height = true: the
	-- picker's full-height sheet) - the PC sheets sit on the centred stage
	function MN.viewKey(height)
		local w, h = MN.view()
		if HUD.ST.isPhone() then
			return string.format("phone:%d:%d", math.floor(w + 0.5), math.floor(h + 0.5))
		end
		return height and string.format("pc:%d", math.floor(h + 0.5)) or "pc"
	end
	-- the PC sheets' stage: the mockups' 1280 wide, centred on the screen
	-- whatever its shape, full height (a phone's sheets run edge to edge on
	-- the root itself)
	function MN.stage()
		local root = MN.root()
		if HUD.ST.isPhone() then
			return root
		end
		local st = root:FindFirstChild("Stage")
		if not st then
			st = make("Frame", {
				Name = "Stage",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0, 1280, 1, 0),
				ZIndex = 10,
				Parent = root,
			})
		end
		return st
	end
	-- a sheet on the stage: ST.panel, its world dim reaching both edges of any screen
	function MN.panel(p)
		local holder = HUD.ST.panel(p)
		local scrim = holder:FindFirstChild("Scrim")
		if scrim then
			scrim.AnchorPoint = Vector2.new(0.5, 0)
			scrim.Position = UDim2.fromScale(0.5, 0)
			scrim.Size = UDim2.fromScale(8, 1)
		end
		return holder
	end
	-- a menu made for one screen is made again for another: fn checks its own
	-- viewKey. (Each menu's own ST.onLayout makes it again at once on a phone
	-- flip; this hears the camera's ViewportSize - a window made wider or
	-- taller, a new scale - and runs once it has settled, so dragging a
	-- window's edge doesn't rebuild the menus every frame.)
	MN.relayouts = {}
	function MN.watch(fn)
		table.insert(MN.relayouts, fn)
		if not MN.vpConn then
			pcall(function()
				MN.vpConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					MN.vpTurn = (MN.vpTurn or 0) + 1
					local turn = MN.vpTurn
					task.delay(0.15, function()
						if MN.vpTurn == turn then
							for _, f in table.clone(MN.relayouts) do
								task.spawn(f)
							end
						end
					end)
				end)
			end)
		end
	end

	-- a menu came up: the others go (one full menu at a time)
	function MN.opened(key)
		for k, close in MN.closers do
			if k ~= key then
				local ok, err = pcall(close)
				if not ok then
					warn("HUD.Menus: closing " .. k .. ": " .. tostring(err))
				end
			end
		end
		if MN.cur ~= key then
			MN.cur = key
			MN.tell()
		end
	end
	function MN.closed(key)
		if MN.cur == key then
			MN.cur = nil
			MN.tell()
		end
	end
	function MN.tell()
		local id = HUD.OpenMenuId()
		for _, fn in table.clone(MN.fns) do
			task.spawn(fn, id)
		end
		if HUD.TouchSync then
			HUD.TouchSync()
		end
	end

	function HUD.MenuOrder()
		return Config.UI.Menus.Order
	end
	function HUD.OpenMenuId()
		return MN.cur and MN.TAB[MN.cur] or nil
	end
	function HUD.MenuOpen()
		return MN.cur ~= nil
	end
	function HUD.OnMenuChanged(fn)
		table.insert(MN.fns, fn)
		task.spawn(fn, HUD.OpenMenuId())
		return function()
			local i = table.find(MN.fns, fn)
			if i then
				table.remove(MN.fns, i)
			end
		end
	end
	-- a tab pressed: its menu opens, or closes if it's the one up. Returns the
	-- tab now open (nil: none). EMOTES: the picker (a controller's B / R3 and
	-- QuirkClient's own OnEmotes still open the controller's card menu)
	function HUD.MenuRoute(id)
		if id == "Heroes" then
			if HUD.OutfitsVisible and HUD.OutfitsVisible() then
				HUD.ToggleOutfits(false)
			else
				HUD.ToggleMenu()
			end
		elseif id == "Emotes" then
			if HUD.EmoteMenuVisible and HUD.EmoteMenuVisible() then
				if HUD.EmoteMenuClosed then
					HUD.EmoteMenuClosed()
				else
					HUD.ShowEmoteMenu(false)
				end
			elseif HUD.ShowEmoteWheel then
				HUD.ShowEmoteWheel(not HUD.EmoteWheelVisible())
			end
		elseif id == "Shop" then
			HUD.ToggleShop()
		elseif id == "Ranked" then
			HUD.ToggleRanked()
		elseif id == "Top" then
			HUD.ToggleBoard()
		elseif id == "Settings" then
			HUD.ToggleSettings()
		end
		return HUD.OpenMenuId()
	end

	-- an open sheet made again (a phone flip, new data): up at once, no slide
	-- (the kit's own open state: ST.openPanel without its motion)
	function MN.reopen(p)
		p:SetAttribute("Open", true)
		p:SetAttribute("Turn", (p:GetAttribute("Turn") or 0) + 1)
		p.Visible = true
		p.Sheet.Position = UDim2.fromOffset(p:GetAttribute("SheetX"), p:GetAttribute("Top"))
		p.Scrim.BackgroundTransparency = Config.UI.Street.ScrimT
		p.Sheet.Content.Visible = true
		if p:GetAttribute("HideCombat") then
			HUD.ST.hideCombat(p.Name, true)
		end
	end

	-- text placed the way the mockups place it: x, and y = the baseline.
	-- p: the rest of ST.label's props (Role, Color, T, Name, Z, AlignX...)
	function MN.text(parent, text, size, x, baseY, p)
		p = p or {}
		local ST = HUD.ST
		p.Text = text
		p.Size = size
		p.Parent = parent
		local m = ST.metrics(size, p.Role)
		local ax = p.AlignX == "Right" and 1 or (p.AlignX == "Center" and 0.5 or 0)
		p.Anchor = Vector2.new(ax, 0)
		p.Pos = UDim2.fromOffset(math.floor(x + 0.5), math.floor(baseY - m.Base + 0.5))
		return ST.label(p)
	end
	-- numerals the same way (AlignX "Right": x is where the run ends)
	function MN.num(parent, text, size, x, baseY, p)
		p = p or {}
		local ST = HUD.ST
		local m = ST.metrics(size)
		local ax = p.AlignX == "Right" and 1 or 0
		return ST.numerals(text, size, {
			Name = p.Name, Color = p.Color, T = p.T, Shadow = p.Shadow, Z = p.Z, Parent = parent,
			Anchor = Vector2.new(ax, 0), Pos = UDim2.fromOffset(math.floor(x + 0.5), math.floor(baseY - m.Base + 0.5)),
		})
	end
	-- a leaning list in a ScrollingFrame keeps its lean as it scrolls: each row
	-- (a child with a "CanvasY" attribute) is moved to the margin at the height
	-- it's shown at. xOf(screenY) -> x in the frame's own space.
	function MN.leanScroll(sf, top, xOf)
		local function place()
			local dy = sf.CanvasPosition.Y
			for _, c in sf:GetChildren() do
				local cy = c:GetAttribute("CanvasY")
				if cy then
					c.Position = UDim2.fromOffset(math.floor(xOf(top + cy - dy + (c:GetAttribute("BaseOff") or 0)) + (c:GetAttribute("XOff") or 0) + 0.5), cy)
				end
			end
		end
		sf:GetPropertyChangedSignal("CanvasPosition"):Connect(place)
		return place
	end
end

---------------------------------------------------------------------------
-- (round 100) THE HERO PICKER (Stark Street; mockups 03 and 03b). The phone
-- is gone: one full-height ink sheet from the left - the roster as a poster
-- (numbers and names in two leaning columns, the dev-only heroes in their own
-- smaller group under a rule, testers and the owner only), the shown hero's
-- detail block (No., mode, the name on its slash, one sentence - the hero's
-- ShortDescription - and six moves) and PLAY / OUTFIT bottom right, by your
-- character. Plain frames, no CanvasGroup: the open state is set at once and
-- the tweens are only for looks, so it can never stay black (audit #1).
-- A mouse: hovering shows a hero, a click plays him (as the phone's tap did).
-- Touch: a tap shows him; the same row again, or PLAY, plays. A controller:
-- the selection shows him, A plays. Enter plays the one shown; M or the tab
-- closes. A phone gets its own layout (one scrolling column, the detail on its
-- own slab, PLAY where the thumb is).
---------------------------------------------------------------------------
do
	local MN = HUD.Menus
	local PK = { rows = {} }
	HUD.Picker = PK -- (tests and the renderer can read it)

	local function C()
		return Config.UI.Menus.Picker
	end
	local function SS()
		return Config.UI.Street
	end
	local function me()
		local ok, p = pcall(function()
			return game:GetService("Players").LocalPlayer
		end)
		return ok and p or nil
	end
	-- the hero you're playing (nil: none yet)
	function PK.current()
		local p = me()
		local q = p and p:GetAttribute("Quirk")
		return (q and Config.Quirks[q]) and q or nil
	end

	-- the moves the detail block lists: { key, name } for 1-4, R, G
	function PK.moves(quirkName)
		local out = {}
		local view = Config.GetView(quirkName, false, false, 1)
		local q = Config.Quirks[quirkName]
		if not (view and q) then
			return out
		end
		for i = 1, 3 do
			local a = view.Abilities and view.Abilities[i]
			if a then
				table.insert(out, { tostring(i), a.Name })
			end
		end
		if view.Extra then
			table.insert(out, { "4", view.Extra.Name })
		end
		if view.Special then
			table.insert(out, { "R", view.OtherModeName or view.Special.Name })
		end
		if q.Ult then
			table.insert(out, { "G", q.Ult.Name })
		end
		return out
	end

	-- build it for the layout we're in (a phone flip rebuilds it, kept open or shut)
	function PK.build()
		local ST = HUD.ST
		local was = PK.panel and ST.panelOpen(PK.panel)
		if PK.panel then
			PK.panel:Destroy()
		end
		table.clear(PK.rows)
		local phone = ST.isPhone()
		PK.phone = phone
		PK.key = MN.viewKey(true)
		local c = C()
		local L = phone and c.Phone or c
		-- ((round 100 review) the screen's real room: the sheet is full height on
		-- any screen (a 4:3 tablet is 960 tall), the detail block keeps to the
		-- bottom and PLAY / OUTFIT to the bottom-right corner; a phone narrower
		-- than the mockup's 812 (a 16:9 one is 667) keeps the detail slab on its
		-- right edge and the sheet stops short of it)
		local vw, vh = MN.view()
		local bw, bh = phone and 812 or 1280, phone and 375 or 720
		PK.vw, PK.vh, PK.bw, PK.bh = vw, vh, bw, bh
		local topW = phone and math.min(L.TopW, math.floor(vw - 300)) or L.TopW
		local lean = ST.lean()
		local panel = ST.panel({
			Name = "HeroPicker", Parent = MN.root(), X = vh * lean, W = topW - vh * lean, Top = 0, Bottom = vh,
			Ends = "Right", T = c.T, Margin = L.Margin, Scrim = false, Z = 10,
		})
		PK.panel = panel
		panel.Sheet.Active = true -- (a click on the sheet stays on it: no punch through the menu)
		-- (the list leans with the sheet's right edge, which is anchored at the
		-- top: on PC its margin is measured from the mockup's bottom)
		local ref = (phone and vh or bh) - (phone and 15 or 16)
		function PK.lx(y)
			return L.Margin + (ref - y) * lean
		end
		local content = panel.Sheet.Content
		-- the shown hero's number, huge in raised ink behind the list (PC)
		PK.ghost = make("Frame", { Name = "Ghost", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Visible = not phone, Parent = content })
		-- the roster
		local list
		if phone then
			list = make("ScrollingFrame", {
				Name = "Heroes",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 44),
				Size = UDim2.fromOffset(math.min(L.TopW - 92, math.max(300, topW - 70)), vh - 44),
				CanvasSize = UDim2.fromOffset(0, 400),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 0,
				ZIndex = 2,
				Parent = content,
			})
			PK.place = MN.leanScroll(list, 44, function(y)
				return PK.lx(y)
			end)
			PK.bar = ST.scrollbar(list, { T = 0.3 })
		else
			list = make("Frame", { Name = "Heroes", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = content })
		end
		PK.list = list
		PK.devRule = ST.slab({ Name = "DevRule", Size = { phone and 300 or 500, 2 }, Color = SS().Ash, T = 0.5, Ends = "None", Z = 2, Parent = list })
		PK.devLabel = ST.label({ Name = "DevLabel", Text = c.DevOnly, Size = 11, Color = SS().Ash, Z = 2, Parent = list })
		for _, quirkName in Config.QuirkOrder do
			PK.row(quirkName)
		end
		-- the detail block (PC: on the sheet; a phone: its own slab at the right)
		if phone then
			local d = L.Detail
			local slab = ST.slab({ Name = "DetailSlab", Size = { d[3], d[4] }, Pos = UDim2.new(1, d[1] - bw, 0, d[2]), Color = SS().Ink, T = 0.1, Z = 12, Parent = panel })
			PK.detail = make("Frame", { Name = "Detail", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 13, Parent = slab })
		else
			PK.detail = make("Frame", { Name = "Detail", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		end
		-- PLAY and OUTFIT, bottom right by your character
		-- (from the right edge and the bottom: the corner where your character's thumb is)
		local right = (phone and 804 or c.Right) - bw
		local by = (phone and (bh - 12 - L.Play[2]) or c.ButtonsY) - bh
		PK.play = ST.button({
			Name = "Play", Kind = "Primary", Text = "PLAY", Size = L.Play, TextSize = phone and 24 or 26, Hint = (not phone) and "ENTER" or nil,
			Pos = UDim2.new(1, right - L.Play[1], 1, by), Z = 20, Parent = panel,
			OnClick = function()
				PK.go(PK.shown)
			end,
		})
		PK.outfit = ST.button({
			Name = "Outfit", Kind = "Secondary", Text = "OUTFIT", Size = L.Outfit, TextSize = phone and 16 or 19,
			Pos = UDim2.new(1, right - L.Play[1] - 6 - L.Outfit[1], 1, by), Z = 20, Parent = panel,
			OnClick = function()
				HUD.ShowMenu(false)
				if HUD.OpenOutfits then
					HUD.OpenOutfits()
				end
			end,
		})
		ST.paint(PK.outfit, SS().Ink, phone and 0.1 or 0.14)
		PK.layout()
		if was then
			MN.reopen(panel)
			PK.show(PK.shown or PK.current() or PK.first())
		end
	end

	-- one hero's row: its number, its name, the PLAYING tag and the "new!" note
	function PK.row(quirkName)
		local ST = HUD.ST
		local q = Config.Quirks[quirkName]
		local row = make("TextButton", {
			Name = quirkName,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Selectable = true,
			Text = "",
			ZIndex = 3,
			Parent = PK.list,
		})
		row:SetAttribute("Hero", quirkName)
		local name = string.upper(q.DisplayName or quirkName)
		ST.numerals("00", 12, { Name = "Num", Color = SS().Ash, Z = 3, Parent = row })
		ST.label({ Name = "Title", Text = name, Size = 26, Z = 3, Parent = row })
		local tag = ST.slab({ Name = "Playing", Size = { 54, 14 }, Color = SS().Paper, Z = 3, Visible = false, Parent = row })
		-- ((round 101) the tag's word at the kit's Minimum, 11: 10 went under 9 real px)
		ST.label({ Name = "Label", Text = C().Playing, Size = SS().Sizes.Minimum, Color = SS().Ink, AlignX = "Center", Box = UDim2.fromScale(1, 1), Pos = UDim2.fromOffset(1, 0), Z = 4, Parent = tag })
		ST.note(C().New, 16, { Name = "New", Rotation = 6, T = 0.1, Z = 4, Parent = row }).Visible = false
		row.MouseEnter:Connect(function()
			if not (HUD.Touch and HUD.Touch.on) then
				PK.show(quirkName)
			end
		end)
		row.SelectionGained:Connect(function()
			PK.show(quirkName)
		end)
		row.Activated:Connect(function(input)
			local touch = HUD.Touch and HUD.Touch.on
			pcall(function()
				touch = touch or input.UserInputType == Enum.UserInputType.Touch
			end)
			if touch and PK.shown ~= quirkName then
				PK.show(quirkName) -- (a tap shows him; again, or PLAY, plays)
				return
			end
			PK.go(quirkName)
		end)
		PK.rows[quirkName] = row
		return row
	end

	-- where every row goes: the public heroes in two leaning columns, numbered;
	-- the dev-only ones (testers and the owner) in a smaller group under a rule
	function PK.layout()
		local ST = HUD.ST
		if not PK.panel then
			return
		end
		local c = C()
		local phone = PK.phone
		local L = phone and c.Phone or c
		local main, dev = {}, {}
		local now = os.time()
		for _, quirkName in Config.QuirkOrder do
			local row = PK.rows[quirkName]
			if row then
				if Config.IsDevOnly(quirkName) then
					table.insert(dev, quirkName)
				else
					table.insert(main, quirkName)
				end
			end
		end
		local function place(row, x, baseY, size, numSize, canvas)
			local m = ST.metrics(size)
			local top = baseY - m.Base
			local title = row.Title
			local w = ST.measure(title.Text, size)
			title.TextSize = math.min(ST.textSize(size), 100)
			title.Size = UDim2.fromOffset(math.ceil(w) + 2, math.ceil(ST.textSize(size)))
			title.Position = UDim2.fromOffset(phone and 24 or 27, 0)
			local nm = ST.metrics(numSize)
			row.Num:SetAttribute("NumSize", numSize)
			ST.setNumerals(row.Num, row.Num:GetAttribute("NumText") or "00")
			row.Num.Position = UDim2.fromOffset(size < 20 and 4 or 0, math.floor(baseY - (size < 20 and 1 or 2) - nm.Base - top + 0.5))
			local tx = (phone and 24 or 27) + w
			row.Playing.Position = UDim2.fromOffset(math.floor(tx + 8 + 0.5), math.floor(m.Base - 16 + 0.5))
			row.New.Position = UDim2.fromOffset(math.floor(tx + 10 + 0.5), math.floor(m.Base + 2 - ST.metrics(16, "Note").Base + 0.5))
			row.Size = UDim2.fromOffset(math.ceil(tx + 70), math.ceil(m.H))
			row:SetAttribute("BaseOff", m.Base)
			if canvas then
				row:SetAttribute("CanvasY", math.floor(top + 0.5))
			else
				row:SetAttribute("CanvasY", nil)
				row.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(top + 0.5))
			end
		end
		local n = 0
		local showDev = devAccess and #dev > 0
		if phone then
			-- one column; the dev group after it; the canvas holds them all
			local y = L.ListY - 44
			for i, quirkName in main do
				n += 1
				local row = PK.rows[quirkName]
				row.Visible = true
				row:SetAttribute("Group", "Main")
				row:SetAttribute("Number", n)
				row.Num:SetAttribute("NumText", string.format("%02d", n))
				place(row, 0, y + (i - 1) * L.Pitch, L.Name, L.Num, true)
			end
			local yd = y + #main * L.Pitch - 6
			PK.devRule.Visible, PK.devLabel.Visible = showDev, showDev
			PK.devRule:SetAttribute("CanvasY", yd - 12)
			PK.devLabel.Position = UDim2.fromOffset(0, 0)
			PK.devLabel:SetAttribute("CanvasY", math.floor(yd + 8 - ST.metrics(11).Base + 0.5))
			for i, quirkName in dev do
				local row = PK.rows[quirkName]
				row.Visible = showDev
				row:SetAttribute("Group", "Dev")
				if showDev then
					n += 1
					row:SetAttribute("Number", n)
					row.Num:SetAttribute("NumText", string.format("%02d", n))
				end
				place(row, 0, yd + L.DevPitch + (i - 1) * L.DevPitch, L.DevName, L.DevNum, true)
			end
			local bottom = (showDev and (yd + L.DevPitch * (#dev + 1)) or (y + #main * L.Pitch)) + 24
			PK.list.CanvasSize = UDim2.fromOffset(0, math.max(bottom, 0))
			PK.place()
			ST.updateScrollbar(PK.bar, PK.list)
		else
			local rows = math.max(math.ceil(#main / 2), math.min(#main, c.Rows))
			local devRows = showDev and math.ceil(#dev / 2) or 0
			local devH = showDev and (c.DevGap + devRows * c.DevPitch) or 0
			local pitch = math.clamp(math.floor((c.ListBottom - devH - c.ListY) / math.max(rows, 1)), c.MinPitch, c.Pitch)
			for i, quirkName in main do
				n += 1
				local col, r = (i - 1) // rows, (i - 1) % rows
				local y = c.ListY + r * pitch
				local row = PK.rows[quirkName]
				row.Visible = true
				row:SetAttribute("Group", "Main")
				row:SetAttribute("Number", n)
				row.Num:SetAttribute("NumText", string.format("%02d", n))
				place(row, PK.lx(y) + col * c.Column, y, pitch < 30 and 22 or c.Name, c.Num, false)
			end
			local yd = c.ListY + rows * pitch - 6
			PK.devRule.Visible, PK.devLabel.Visible = showDev, showDev
			PK.devRule.Position = UDim2.fromOffset(math.floor(PK.lx(yd) - 4 + 0.5), yd - 12)
			PK.devLabel.Position = UDim2.fromOffset(math.floor(PK.lx(yd + 8) + 0.5), math.floor(yd + 8 - ST.metrics(11).Base + 0.5))
			for i, quirkName in dev do
				local col, r = (i - 1) % 2, (i - 1) // 2
				local y = yd + c.DevGap + r * c.DevPitch
				local row = PK.rows[quirkName]
				row.Visible = showDev
				row:SetAttribute("Group", "Dev")
				if showDev then
					n += 1
					row:SetAttribute("Number", n)
					row.Num:SetAttribute("NumText", string.format("%02d", n))
				end
				place(row, PK.lx(y) + col * c.Column, y, c.DevName, c.DevNum, false)
			end
		end
		for quirkName, row in PK.rows do
			row.New.Visible = row.Visible and not Config.IsDevOnly(quirkName) and Config.RosterNew(quirkName, now)
		end
		if PK.shown and not (PK.rows[PK.shown] and PK.rows[PK.shown].Visible) then
			PK.shown = nil
		end
		PK.mark()
		if ST.panelOpen(PK.panel) then
			PK.show(PK.shown or PK.current() or PK.first())
		end
	end

	-- the first hero on the list (where a controller starts)
	function PK.first()
		local best, bn = nil, math.huge
		for quirkName, row in PK.rows do
			local n = row:GetAttribute("Number")
			if row.Visible and n and n < bn then
				best, bn = quirkName, n
			end
		end
		return best
	end

	-- the hero you're playing: full white, the PLAYING tag
	function PK.mark()
		local cur = PK.current()
		for quirkName, row in PK.rows do
			row.Playing.Visible = quirkName == cur
			local on = quirkName == cur or quirkName == PK.shown
			row.Title.TextTransparency = on and 0 or (row:GetAttribute("Group") == "Dev" and 0.5 or 0.44)
		end
	end

	-- show one: its row lit and on its slash, its number behind the list, its detail
	function PK.show(quirkName)
		local ST = HUD.ST
		local q = quirkName and Config.Quirks[quirkName]
		local row = q and PK.rows[quirkName]
		if not (row and PK.panel) then
			return
		end
		PK.shown = quirkName
		local c = C()
		local phone = PK.phone
		local L = phone and c.Phone or c
		for name, r in PK.rows do
			ST.setNumerals(r.Num, r.Num:GetAttribute("NumText") or "00")
			local on = name == quirkName
			r.Num:SetAttribute("NumColor", on and SS().Paper or SS().Ash)
			ST.setNumerals(r.Num, r.Num:GetAttribute("NumText") or "00")
		end
		PK.mark()
		-- the slash under the row (it paints itself in)
		if PK.slash then
			PK.slash:Destroy()
		end
		local size = row:GetAttribute("Group") == "Dev" and (phone and L.DevName or c.DevName) or (phone and L.Name or c.Name)
		local w = ST.measure(row.Title.Text, size)
		local sh = math.floor(size * 1.5 + 0.5)
		PK.slash = ST.slash({
			Name = "Shown", Size = { math.floor(w + size * 1.7 + 0.5), sh }, Color = q.Color, Value = 0, Rotation = -2, Z = 2,
			Pos = UDim2.fromOffset(row.Position.X.Offset + (phone and 18 or 20), row.Position.Y.Offset + math.floor(row:GetAttribute("BaseOff") - size * 0.35 - sh / 2 + 0.5)),
			Parent = PK.list,
		})
		if phone then
			PK.slash:SetAttribute("CanvasY", row:GetAttribute("CanvasY") + math.floor(row:GetAttribute("BaseOff") - size * 0.35 - sh / 2 + 0.5))
			PK.slash:SetAttribute("BaseOff", size * 0.35 + sh / 2)
			PK.slash:SetAttribute("XOff", 18)
			PK.place()
		end
		ST.setSlash(PK.slash, 1, SS().Motion.SlashPaint)
		-- the number, huge behind the list
		for _, ch in PK.ghost:GetChildren() do
			ch:Destroy()
		end
		local num = string.format("%02d", row:GetAttribute("Number") or 0)
		if not phone then
			MN.num(PK.ghost, num, c.Ghost, -6, c.GhostY, { Name = "Number", Color = c.GhostColor, Z = 1 })
		end
		PK.fillDetail(quirkName, num)
	end

	function PK.fillDetail(quirkName, num)
		local ST = HUD.ST
		local q = Config.Quirks[quirkName]
		local d = PK.detail
		for _, ch in d:GetChildren() do
			ch:Destroy()
		end
		local c = C()
		local phone = PK.phone
		local L = phone and c.Phone or c
		local lean = ST.lean()
		local name = string.upper(q.DisplayName or quirkName)
		local mode = q.ModeName
		local sentence = q.ShortDescription or ""
		local moves = PK.moves(quirkName)
		local tsize = L.Title
		-- (a long name steps down so it fits: nothing is cut off. (round 100
		-- review) the room is what's left before the sheet's / slab's leaning
		-- right edge, not a round number)
		local room
		if phone then
			room = L.Detail[3] - 54 * lean - (140 * lean + 6) - 10
		else
			local ny = c.DetailY + (PK.vh - PK.bh) - 40
			room = (L.TopW - ny * lean) - math.max(PK.lx(ny), L.Margin) - 36
		end
		while ST.measure(name, tsize) > room and tsize > 20 do
			tsize -= 2
		end
		local nw = ST.measure(name, tsize)
		if phone then
			-- on its own slab (330 x 140): No., mode, the name on its slash, the sentence, 1-4
			local x = 140 * lean - 8
			MN.num(d, "No." .. num, 11, x + 22, 22, { Name = "No", Color = SS().Ash, Z = 14 })
			if mode then
				MN.text(d, mode, 11, x + 62, 21, { Name = "Mode", Color = SS().Ash, Z = 14 })
			end
			local s = ST.slash({ Name = "Slash", Size = { math.floor(nw + 40), 32 }, Color = q.Color, Value = 1, Rotation = -2, Z = 13, Pos = UDim2.fromOffset(math.floor(x + 6), 42 - 16), Parent = d })
			s:SetAttribute("Hero", quirkName)
			local t = ST.shadowText({ Name = "Name", Text = name, Size = tsize, Z = 14, Parent = d })
			t.Position = UDim2.fromOffset(math.floor(x + 14), math.floor(54 - ST.metrics(tsize).Base + 0.5))
			local sl = MN.text(d, sentence, L.Sentence, x + 8, 74, { Name = "Sentence", Role = "Body", T = 0.2, Z = 14 })
			-- ((round 100 review) the sentence ends before the slab's leaning edge:
			-- a long one takes two lines and the moves step down one)
			local sroom = math.floor(L.Detail[3] - 80 * lean - (x + 8) - 8)
			local down = 0
			if ST.measure(sentence, L.Sentence, "Body") > sroom then
				sl.TextWrapped = true
				sl.TextYAlignment = Enum.TextYAlignment.Top
				sl.Size = UDim2.fromOffset(sroom, math.ceil(ST.textSize(L.Sentence, "Body") * 2))
				down = 13
			end
			for i = 1, math.min(4, #moves) do
				local col, r = (i - 1) % 2, (i - 1) // 2
				local yy = 96 + down + r * 17
				local xx = x + 4 - r * 17 * lean + col * 150
				MN.num(d, moves[i][1], L.MoveKey, xx, yy, { Name = "Key" .. i, T = 0.5, Z = 14 })
				-- (the second column ends at the slab's leaning edge; a name too long
				-- for its column drops what follows its colon - DELAWARE SMASH - then
				-- steps down a size, never under 11)
				local room = col == 0 and 132 or 112
				local mv = moves[i][2]
				if ST.measure(mv, L.Move) > room and string.find(mv, ":", 1, true) then
					mv = string.match(mv, "^(.-):") or mv
				end
				local ms = L.Move
				while ST.measure(mv, ms) > room and ms > 11 do
					ms -= 1
				end
				MN.text(d, mv, ms, xx + 13, yy, { Name = "Move" .. i, T = 0.1, Z = 14 })
			end
			return
		end
		-- ((round 100 review) at the bottom of the screen, however tall; below the
		-- mockup's bottom the margin stops leaning - (round 101) at the sheet's
		-- margin, as in the mockup: with the size knob every PC screen is taller
		-- than the mockup's frame, and the block ran down to 18 off the screen edge)
		local by = c.DetailY + (PK.vh - PK.bh)
		local function dx(y)
			return math.max(PK.lx(y), L.Margin)
		end
		local x = dx(by)
		MN.num(d, "No." .. num, c.Kicker, x + 6 + 46 * lean, by - 50, { Name = "No", Color = SS().Ash, Z = 4 })
		if mode then
			MN.text(d, mode, c.Mode, x + 6 + 46 * lean + 50, by - 51, { Name = "Mode", Color = SS().Ash, Z = 4 })
		end
		local s = ST.slash({ Name = "Slash", Size = { math.floor(nw + 64), 56 }, Color = q.Color, Value = 1, Rotation = -2.5, Z = 3, Pos = UDim2.fromOffset(math.floor(x - 16), by - 15 - 28), Parent = d })
		s:SetAttribute("Hero", quirkName)
		local t = ST.shadowText({ Name = "Name", Text = name, Size = tsize, Shadow = 3, Z = 4, Parent = d })
		t.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(by - ST.metrics(tsize).Base + 0.5))
		MN.text(d, sentence, c.Sentence, x - 2, by + 24, { Name = "Sentence", Role = "Body", T = 0.2, Z = 4 })
		for i, mv in moves do
			local col, r = (i - 1) // 3, (i - 1) % 3
			local yy = by + 48 + r * c.MoveRow
			local xx = dx(yy) + col * c.MoveCol
			MN.num(d, mv[1], c.MoveKey, xx, yy, { Name = "Key" .. i, T = 0.5, Z = 4 })
			local ms = c.Move
			while ST.measure(mv[2], ms) > c.MoveCol - 22 and ms > 10 do
				ms -= 1
			end
			MN.text(d, mv[2], ms, xx + 15, yy, { Name = "Move" .. i, T = 0.1, Z = 4 })
		end
	end

	-- play him: the server's told, the hero's slash wipes across the bottom,
	-- the picker goes
	function PK.go(quirkName)
		local ST = HUD.ST
		quirkName = quirkName or PK.shown or PK.current()
		local q = quirkName and Config.Quirks[quirkName]
		if not q then
			return
		end
		if callbacks.OnSelect then
			callbacks.OnSelect(quirkName)
		end
		HUD.ShowMenu(false)
		pcall(function()
			-- ((round 100 review) across the bottom of whatever screen it is)
			local vw = MN.view()
			local wipe = ST.slash({ Name = "PlayWipe", Size = { math.floor(vw + 120), PK.phone and 50 or 90 }, Color = q.Color, Value = 0, Rotation = -2.5, Z = 30, Pos = UDim2.new(0, -60, 1, PK.phone and -45 or -80), Parent = MN.root() })
			ST.setSlash(wipe, 1, 0.2)
			task.delay(0.5, function()
				wipe:Destroy()
			end)
		end)
	end

	-- Enter plays the one shown (only while it's up)
	function PK.keys(on)
		pcall(function()
			local cas = game:GetService("ContextActionService")
			if on then
				cas:BindActionAtPriority("QuirkPickerPlay", function(_, state)
					if state == Enum.UserInputState.Begin then
						PK.go(PK.shown)
					end
					return Enum.ContextActionResult.Sink
				end, false, 3000, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter)
			else
				cas:UnbindAction("QuirkPickerPlay")
			end
		end)
	end

	function PK.close()
		HUD.ShowMenu(false)
	end
	MN.closers.Picker = PK.close

	function HUD.BuildMenu()
		PK.build()
		-- (a phone flip: its own layout; the hero you're playing, marked when it
		-- changes. (round 100 review) any new screen shape too: MN.watch)
		HUD.ST.onLayout(function(phone)
			if PK.panel and phone ~= PK.phone then
				PK.build()
			end
		end)
		MN.watch(function()
			if PK.panel and PK.key ~= MN.viewKey(true) then
				PK.build()
			end
		end)
		pcall(function()
			me():GetAttributeChangedSignal("Quirk"):Connect(PK.mark)
		end)
	end

	-- Dev-only heroes only show for testers (round 86: DEV ONLY as the live
	-- roster has it, Config.IsDevOnly - so this is called again when it changes)
	function HUD.SetDevAccess(on)
		devAccess = on == true
		PK.layout()
	end

	-- up (true) or away; up, it shows the hero you're playing (or the first)
	function HUD.ShowMenu(visible)
		local ST = HUD.ST
		local p = PK.panel
		if p then
			local open = ST.panelOpen(p)
			if visible == true and not open then
				MN.opened("Picker")
				ST.openPanel(p)
				PK.layout()
				PK.show(PK.current() or PK.shown or PK.first())
				PK.keys(true)
			elseif visible ~= true and open then
				ST.closePanel(p)
				PK.keys(false)
				MN.closed("Picker")
			end
		end
		if HUD.TouchSync then
			HUD.TouchSync()
		end
	end

	function HUD.ToggleMenu()
		HUD.ShowMenu(not HUD.MenuVisible())
	end

	function HUD.MenuVisible()
		return PK.panel ~= nil and HUD.ST.panelOpen(PK.panel)
	end
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
	-- (round 100) Stark Street: an ink tab, TEST in ash and its key, P
	local S = Config.UI.Street
	testOpenButton = ST.slab({ Name = "TestButton", Button = true, Size = { 78, 30 }, Color = S.Ink, T = S.HudT, Pos = UDim2.new(0, 12, 0, 70), Z = 20, Parent = gui })
	ST.label({ Name = "Label", Text = "TEST", Size = 15, Color = S.Ash, Pos = UDim2.new(0, 14, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 21, Parent = testOpenButton })
	ST.label({ Name = "Key", Role = "Mono", Text = "P", Size = 11, Color = S.Ash, Pos = UDim2.new(1, -16, 0.5, 1), Anchor = Vector2.new(1, 0.5), Z = 21, Parent = testOpenButton })
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
		Text = "For testers. P opens and closes it.",
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
	local IDLE = S.Ink2 -- ((round 100) ink 2, a paper flash on a press)
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
					button.BackgroundColor3 = S.Paper
					tween(button, 0.35, { BackgroundColor3 = IDLE })
				end
			end)
		end
	end
	testPanel.Size = UDim2.fromOffset(TEST_W, math.min(height, 560))
	testOpenButton.MouseButton1Click:Connect(function()
		HUD.ToggleTestMenu()
	end)
	-- (round 100) Stark Street's light touch: ink, paper, Oswald, no corners or strokes
	HUD.MO.skin(testPanel)
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
	-- ((round 100) Stark Street: the live switch paper with an ink knob; an ink one with an ash knob)
	local S = Config.UI.Street
	if row.Track then
		row.Track.BackgroundColor3 = on and S.Paper or S.Ink
		row.Knob.BackgroundColor3 = on and S.Ink or S.Ash
		row.Knob.Position = on and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	end
	row.Button.BackgroundColor3 = on and S.Hatch or S.Ink2
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
		-- (round 99) GODSPEED's boil faster still
		local god = FL.mode == "god"
		if not now and t - FL.at < (god and 1 / 16 or 1 / 12) then
			return
		end
		FL.at = t
		local size = gui.AbsoluteSize
		local maxDim = math.max(size.X, size.Y, 1)
		if god then
			FL.godLines(maxDim)
			return
		end
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

	-- (round 99) GODSPEED: every line up, long and thick, in its colours - gold,
	-- white, electric blue - closer in round the middle than LIGHTSPEED's
	FL.GOD_COLORS = { Color3.fromRGB(255, 206, 92), Color3.fromRGB(255, 250, 236), Color3.fromRGB(92, 170, 255) }
	function FL.godLines(maxDim)
		local count = math.floor(40 * FL.k + 0.5)
		for i, line in FL.lines do
			if i > count then
				line.BackgroundTransparency = 1
				continue
			end
			local angle = rng:NextNumber(0, math.pi * 2)
			local len = maxDim * rng:NextNumber(0.24, 0.5)
			local r = maxDim * rng:NextNumber(0.22, 0.36) + len / 2
			line.BackgroundColor3 = FL.GOD_COLORS[(i - 1) % 3 + 1]
			line.Position = UDim2.new(0.5, math.cos(angle) * r, 0.5, math.sin(angle) * r)
			line.Size = UDim2.fromOffset(len, rng:NextInteger(2, 5))
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 1 - 0.66 * FL.k * rng:NextNumber(0.4, 1)
		end
	end
	-- ((round 100) the meter's tier colours, its prism and its power gradients
	-- went with Stark Street: paper on ink, and a slash at LIGHTSPEED / GODSPEED)
	FL.TOP = 980 -- (the bar's end: the mach burst's cap)
	-- info: { Tier = "CRUISE", Speed = studs/s, Mach = n, Boom = studs/s (the mark), Hot = true while the burst runs }; nil hides it
	-- (round 90: Charge = the light barrier's charge 0..1, Light = at
	-- LIGHTSPEED, Hint = the key that gets there ("HOLD Q") - a strip under the
	-- bar fills with the charge, the caption saying what's happening)
	-- (round 99: God = at GODSPEED, GodCharge = its charge 0..1, GodHint = the
	-- key that gets there ("HOLD Q AGAIN"), GodOut = the one that gets out)
	function HUD.FlightMeter(info)
		-- (round 92) the phone's LOCK (the hover-lock) is up exactly while this is
		if HUD.SetTouchHoverLock then
			HUD.SetTouchHoverLock(info ~= nil)
		end
		-- (round 100) Stark Street (HUD.MO.meter): an ink slab over the move row -
		-- the caption, the tier (on a slash at LIGHTSPEED / GODSPEED), the speed in
		-- numerals, MACH, a paper line with the tiers' ticks, the barrier's charge
		HUD.MO.meter(info)
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

local GUARD_COLOR = Color3.fromRGB(120, 210, 255)
local GUARD_LOW = Color3.fromRGB(255, 90, 70)

local function quirkLabel(q)
	local quirk = q and Config.Quirks[q]
	return quirk and quirk.DisplayName or nil, quirk and quirk.Color or Color3.fromRGB(200, 200, 210)
end

---------------------------------------------------------------------------
-- (round 100) STARK STREET: THE COMBAT HUD (spec sections 4 and 7; mockups
-- 01, 02 and 10). Built from the kit (HUD.ST) in the combat frame's scaled
-- root (ST.combat(): a full menu hides it): the dock - the vitals bottom left
-- (the hero's name on the slash, which IS the ult meter; the resource line;
-- health with its RED chip; the guard's ten segments and the evade bar) and
-- the move slots (the hatch over what's cooling, the seconds top right) -
-- the bag on the left, the combo on the right, the kill feed top right and,
-- on touch, the leaning grid round Roblox's jump button (the TOUCH block).
-- The tabs and the wallet / rank sit in QuirkTopBar's root, over the menus.
-- A phone gets its own positions (Config.UI.Hud's Phone tables), not a
-- shrunk PC layout. The old HUD.* setters keep their contracts and draw
-- into this; what they knew (vitals, ultBar, guardBar, feedList, slots ...)
-- points at the new pieces.
---------------------------------------------------------------------------
HUD.FH = { slots = {}, resources = {}, tips = {}, state = {}, shadows = {}, keys = true }
do
	local FH = HUD.FH
	local V2 = Vector2.new
	local ARROWS = { ["◀"] = "LEFT", ["▶"] = "RIGHT", ["▲"] = "UP", ["▼"] = "DOWN", ["✕"] = "X", ["○"] = "O", ["□"] = "SQ", ["△"] = "TRI" }

	local function tok()
		return Config.UI.Street
	end
	-- the places for the layout we're in: the PC numbers, a phone's over them
	function FH.cfg(name)
		local base = Config.UI.Hud[name]
		-- (a touch tablet: the PC layout, a few things moved off the thumbs)
		local over = (FH.phone and base.Phone) or (FH.tablet and base.Tablet) or nil
		if not over then
			return base
		end
		local out = table.clone(base)
		for k, v in over do
			out[k] = v
		end
		-- ((round 100 review) a narrower phone - an iPhone SE / 8's 667 points, a
		-- 16:9 Android's 667-771 - has less room between the stick and the touch
		-- grid than mockup 02's 812: the vitals give way to the grid's bottom row
		-- (TOUCH.left, FH.layout): a little further left, shorter bars, a smaller
		-- name - never under the buttons)
		if name == "Vitals" and FH.phone and FH.vroom then
			local numW = ST.measure("300", out.Hp) + ST.measure("/300", out.HpMax) + 6
			local need = out.BarW + out.BarGap + numW
			local room = FH.vroom - out.X
			if room < need then
				out.X = math.max(out.X - (need - room), out.XMin or out.X)
				room = FH.vroom - out.X
				local bar = math.max(math.floor(room - out.BarGap - numW), out.BarMin or 100)
				out.GuardW = math.floor(out.GuardW * bar / out.BarW + 0.5)
				out.EvadeGap = math.min(out.EvadeGap, math.floor(bar * 0.06 + 0.5))
				out.BarW = bar
				out.SlashW = math.min(out.SlashW, math.floor(room + 6))
				out.NameFit = math.min(out.NameFit, math.floor(room - 8))
				out.NameMin = math.min(out.NameMin, out.NameMinTight or out.NameMin)
				out.Box = { math.max(math.floor(room), 1), out.Box[2] }
			end
		end
		return out
	end
	-- the root's design height (the bottom is what the dock hangs from)
	function FH.baseH()
		return FH.phone and 375 or 720
	end
	-- a key's word as the slots print it (Oswald has no arrows or pad shapes)
	function FH.keyWord(k)
		k = tostring(k or "")
		return ARROWS[k] or k
	end
	function FH.commas(n)
		local s = tostring(math.floor(tonumber(n) or 0))
		local out = s
		while true do
			local next_, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
			out = next_
			if k == 0 then
				break
			end
		end
		return out
	end

	-- TEXT OVER THE WORLD: a face and its ink shadow (a second label, offset),
	-- kept in step by FH.say (and by the slow step for anyone else's writes)
	function FH.pair(p)
		local sh = ST.label({
			Name = (p.Name or "Label") .. "Shadow", Text = p.Text, Size = p.Size, Role = p.Role, Color = tok().Ink, T = p.ShadowT or 0,
			AlignX = p.AlignX, AlignY = p.AlignY, Box = p.Box, Pos = (p.Pos or UDim2.new()) + UDim2.fromOffset(p.Shadow or 1, p.Shadow or 1),
			Anchor = p.Anchor, Z = p.Z or 1, Visible = p.Visible, Parent = p.Parent,
		})
		local face = ST.label({
			Name = p.Name or "Label", Text = p.Text, Size = p.Size, Role = p.Role, Color = p.Color, T = p.T, AlignX = p.AlignX, AlignY = p.AlignY,
			Box = p.Box, Pos = p.Pos, Anchor = p.Anchor, Z = (p.Z or 1) + 1, Visible = p.Visible, Parent = p.Parent,
		})
		sh:SetAttribute("Off", p.Shadow or 1)
		FH.shadows[face] = sh
		return face, sh
	end
	-- a numerals run's colour and transparency again (the kit's text stand-in
	-- keeps the ones it was made with; the sheet's glyphs take them every set)
	function FH.numStyle(holder, color, t, size, text)
		if color then
			holder:SetAttribute("NumColor", color)
		end
		if t then
			holder:SetAttribute("NumT", t)
		end
		if size then
			holder:SetAttribute("NumSize", size)
		end
		ST.setNumerals(holder, text or holder:GetAttribute("NumText") or "")
		local stand = holder:FindFirstChild("Text")
		if stand then
			local ts = math.min(ST.textSize(holder:GetAttribute("NumSize") or 20), 100)
			for _, lab in stand:IsA("TextLabel") and { stand } or stand:GetChildren() do
				if lab:IsA("TextLabel") then
					lab.TextSize = ts
					if lab.Name ~= "Shadow" then
						lab.TextColor3 = holder:GetAttribute("NumColor") or tok().Paper
						lab.TextTransparency = holder:GetAttribute("NumT") or 0
					end
				end
			end
		end
	end
	function FH.say(face, text, color)
		if not face then
			return
		end
		face.Text = tostring(text or "")
		if color then
			face.TextColor3 = color
		end
		FH.mirror(face)
	end
	-- the shadow follows its face: words, size, place, shown
	function FH.mirror(face)
		local sh = FH.shadows[face]
		if not sh then
			return
		end
		if sh.Parent == nil and face.Parent == nil then
			FH.shadows[face] = nil
			return
		end
		sh.Text = face.Text
		sh.TextSize = face.TextSize
		sh.Size = face.Size
		sh.Visible = face.Visible
		local off = sh:GetAttribute("Off") or 1
		sh.Position = face.Position + UDim2.fromOffset(off, off)
	end
	-- a label whose baseline sits at (x, base)
	local function top(base, size, role)
		return math.floor(base - ST.metrics(size, role).Base + 0.5)
	end
	FH.top = top

	-- one-time TIP toasts (the how-tos that used to sit on the bars), once a session
	function FH.tip(id, text)
		if FH.tips[id] or not text then
			return
		end
		FH.tips[id] = true
		ST.toast(text, "TIP")
	end

	-- fade a whole group to k (0-1) of how it was made (instant: older feed rows)
	function FH.fade(root, k)
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") then
				for _, prop in { "BackgroundTransparency", "TextTransparency", "ImageTransparency" } do
					local ok, v = pcall(function()
						return d[prop]
					end)
					if ok and type(v) == "number" then
						local key = "Fd" .. string.sub(prop, 1, 1)
						local was = d:GetAttribute(key)
						if was == nil then
							was = v
							d:SetAttribute(key, v)
						end
						d[prop] = 1 - (1 - was) * k
					end
				end
			end
		end
	end

	---------------------------------------------------------------------------
	-- the build (HUD.Init): the dock and its move slots, once
	function FH.build(player)
		-- (your name as the feed has it: the server sends DisplayNames)
		local ok, me = pcall(function()
			return player.DisplayName
		end)
		FH.me = ok and me or (player and player.Name)
		FH.player = player
		FH.phone = ST.isPhone()
		local combat = ST.combat()
		FH.root = ST.rootOf(combat)
		local M = Config.UI.Hud.Moves
		-- the dock: its box over the move row (the carry's and a possessed body's
		-- own boxes centre on it; the dev flight's meter sits on its top); the
		-- vitals hang off it to the left
		local dock = make("Frame", {
			Name = "Dock",
			BackgroundTransparency = 1,
			AnchorPoint = V2(0, 1),
			Position = UDim2.new(0, M.X, 1, 0),
			Size = UDim2.fromOffset(M.Width, 230),
			Parent = FH.root,
		})
		FH.dock = dock
		vitals = make("Frame", { Name = "Vitals", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 160), Parent = dock })
		local bar = make("Frame", {
			Name = "Abilities",
			BackgroundTransparency = 1,
			AnchorPoint = V2(0, 1),
			Position = UDim2.new(0, 0, 1, -(720 - M.Y - M.H)),
			Size = UDim2.fromOffset(M.Width, M.H),
			Parent = dock,
		}, {
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, M.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		FH.abilities = bar
		for i = 1, 3 do
			slots[i] = FH.makeSlot(bar, i, tostring(i), M.Move)
		end
		specialSlot = FH.makeSlot(bar, 5, "R", M.R)
		specialSlot.Frame.Visible = false
		slots[4] = specialSlot
		dashSlot = FH.makeSlot(bar, 0, "Q", M.Q)
		FH.setName(dashSlot, "DASH")
		-- two dash timers: the front dash's (the long one) is the hatch; the
		-- side/back step's short one drains a paper line along the foot
		dashSlot.BoundKey = "DashFront"
		dashSlot.SubKey = "DashMobility"
		dashSlot.Sub = FH.footLine(dashSlot, "MobilityCooldown", M.Sub)
		slots[5] = dashSlot
		extraSlot = FH.makeSlot(bar, 4, "4", M.Move)
		extraSlot.Frame.Visible = false
		slots[6] = extraSlot
		-- (a form's time - All Might's muscle form - drains along R's foot)
		specialSlot.Form = FH.footLine(specialSlot, "FormTime", M.Form)
		FH.state.moves = true
	end

	-- a thin paper line along a slot's foot (the side step's timer, a form's
	-- time): its own leaning slab, the fill drains from the right
	function FH.footLine(slot, name, h)
		local track = ST.slab({ Name = name, Size = { slot.W, h }, T = 1, Pos = UDim2.new(0, 0, 1, -h), Z = 2, Parent = slot.Frame })
		local fill = ST.fill(track, { Name = "Fill", Color = tok().Paper, T = 0.1, Value = 0 })
		return { Track = track, Fill = fill }
	end

	---------------------------------------------------------------------------
	-- A MOVE SLOT: an ink slab; its key top left (numerals, dimmed), its name
	-- bottom left (up to two lines, broken by hand), the hatch over what's
	-- still cooling (from the right, its paper sweep line on the leaning edge)
	-- with the seconds top right; over the hatch the name stays, at 0.78 with
	-- a 1 px ink shadow. On a phone the same slot is a cell of the touch grid.
	function FH.makeSlot(bar, order, key, width)
		local M = Config.UI.Hud.Moves
		local f = ST.slab({ Name = "Slot" .. key, Size = { width, M.H }, Color = tok().Ink, T = M.T, LayoutOrder = order, Z = 1, Parent = bar })
		local slot = { Frame = f, W = width, KeyText = key, BoundKey = nil, Raw = "", Laid = "" }
		slot.Hatch = ST.hatch(f)
		slot.Key = ST.numerals(key, M.Key, { Name = "Key", T = M.KeyT, Z = 3, Parent = f })
		-- ((round 100 review) the name: MoveName holds the whole of it, unseen - what
		-- HUD.SetQuirk, Hawks' bar, a body's keys write and anything reads - and each
		-- line is drawn by a label of its own placed on its baseline (NameLine1/2,
		-- each with its 1 px ink shadow). One label with LineHeight under 1 can't do
		-- it: Roblox holds LineHeight to 1.0-3.0, so a two-line name would spread
		-- half its height again up into the key and the seconds)
		slot.Name = ST.label({ Name = "MoveName", Text = "", Size = M.Name, AlignY = "Bottom", T = 1, Z = 5, Parent = f })
		slot.Lines = {}
		for i = 1, 2 do
			slot.Lines[i] = {
				Shadow = ST.label({ Name = "NameLine" .. i .. "Shadow", Text = "", Size = M.Name, Color = tok().Ink, Visible = false, Z = 4, Parent = f }),
				Face = ST.label({ Name = "NameLine" .. i, Text = "", Size = M.Name, Z = 5, Parent = f }),
			}
		end
		slot.Seconds = ST.numerals("", M.Seconds, { Name = "Seconds", Shadow = 2, Anchor = V2(1, 0), Z = 5, Parent = f })
		-- (on touch: the finger lands on this; HUD.Touch wires it)
		slot.Tap = make("TextButton", { Name = "Tap", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 8, Visible = false, Parent = f })
		table.insert(FH.slots, slot)
		FH.placeSlot(slot)
		return slot
	end

	-- the sizes inside a slot for where it is (the PC row, or a touch cell)
	function FH.placeSlot(slot)
		local M = Config.UI.Hud.Moves
		local TT = Config.UI.Hud.Touch.Text
		local f = slot.Frame
		local w, h = f.Size.X.Offset, f.Size.Y.Offset
		if w <= 0 or h <= 0 then
			return
		end
		ST.relayout(f)
		local pad = slot.OnPad == true
		local l = h * ST.lean()
		-- the key (top left): one letter big, a pad's word smaller; none on touch
		local long = (utf8.len(slot.KeyText) or #slot.KeyText) > 1
		local ksize = pad and TT.Key or (long and M.KeyLong or M.Key)
		slot.Key.Visible = ksize > 0
		if ksize > 0 then
			FH.numStyle(slot.Key, nil, nil, ksize, slot.KeyText)
			slot.Key.Position = UDim2.fromOffset(math.floor(l + 2), top(ksize + 2, ksize))
		end
		-- the seconds (top right)
		local tk = (pad and FH.tablet) and Config.UI.Hud.Touch.Tablet or 1 -- (a tablet's cells are bigger: their words too)
		local ss = pad and math.floor(TT.Seconds * tk + 0.5) or M.Seconds
		FH.numStyle(slot.Seconds, nil, nil, ss)
		slot.Seconds.Position = UDim2.fromOffset(w - (pad and 6 or 7), top(ss + 2, ss))
		-- the feet
		for _, line in { slot.Sub, slot.Form } do
			if line then
				local th = line.Track.Size.Y.Offset
				line.Track.Size = UDim2.fromOffset(w, th)
				ST.relayout(line.Track)
			end
		end
		FH.layName(slot)
	end

	-- a move's name, broken by hand: one line if it's short, else the most even
	-- split into two; smaller only when a word won't fit (never TextScaled)
	function FH.breakName(text, room, size, minSize, oneLine)
		local words = {}
		for w in string.gmatch(text, "%S+") do
			table.insert(words, w)
		end
		local flat = table.concat(words, " ")
		local best, bestSize = flat, minSize
		for s = size, minSize, -1 do
			local one = ST.measure(flat, s)
			if one <= room and (#words < 2 or one <= room * oneLine) then
				return flat, s
			end
			if #words >= 2 then
				local pick, pickW
				for i = 1, #words - 1 do
					local a = table.concat(words, " ", 1, i)
					local b = table.concat(words, " ", i + 1)
					local w = math.max(ST.measure(a, s), ST.measure(b, s))
					if not pickW or w < pickW then
						pick, pickW = a .. "\n" .. b, w
					end
				end
				if pickW <= room then
					return pick, s
				end
				best, bestSize = pick, s
			elseif one <= room then
				return flat, s
			end
		end
		return best, bestSize
	end

	-- lay a slot's name out for its size (and its shadow under it)
	function FH.layName(slot)
		local M = Config.UI.Hud.Moves
		local TT = Config.UI.Hud.Touch.Text
		local f = slot.Frame
		-- (a name someone wrote straight in since - the carry's BURST and back -
		-- is the one to lay out, not the last one laid)
		if slot.Name.Text ~= (slot.Laid or "") then
			slot.Raw = string.gsub(slot.Name.Text, "\n", " ")
		end
		local w, h = f.Size.X.Offset, f.Size.Y.Offset
		local pad = slot.OnPad == true
		local tk = (pad and FH.tablet) and Config.UI.Hud.Touch.Tablet or 1
		local size = pad and math.floor(TT.Move * tk + 0.5) or M.Name
		local minSize = pad and math.floor(TT.Move * tk + 0.5) or M.NameMin
		local x = pad and 7 or M.NameX
		local foot = pad and 6 or M.NameFoot
		local base = h - foot
		local room = w - x - (base / h) * h * ST.lean() - 1
		-- (a touch cell's one line whenever it fits: its words are small already)
		local text, s = FH.breakName(slot.Raw or "", room, size, minSize, pad and 1 or M.OneLine)
		local parts = string.split(text, "\n")
		local ts = ST.textSize(s)
		local pitch = s * M.Lines -- (baseline to baseline: tight, as the mockups set them)
		-- each line on its own baseline, the last on the slot's; its shadow 1 px down-right
		for i = 1, 2 do
			local part = parts[i] or ""
			local pair = slot.Lines[i]
			local baseline = base - (#parts - i) * pitch
			for j, lab in { pair.Face, pair.Shadow } do
				lab.Text = part
				lab.TextSize = math.min(ts, 100)
				lab.Size = UDim2.fromOffset(math.ceil(ST.measure(part, s)) + 2, math.ceil(ts))
				lab.Position = UDim2.fromOffset(x + (j == 2 and 1 or 0), top(baseline, s) + (j == 2 and 1 or 0))
			end
			pair.Face.Visible = part ~= ""
			pair.Shadow.Visible = part ~= "" and slot.cooling == true
		end
		-- the whole name, unseen, over both lines (what's written and read)
		local first = base - (#parts - 1) * pitch
		slot.Name.Text = text
		slot.Name.TextSize = math.min(ts, 100)
		slot.Name.Size = UDim2.fromOffset(math.max(w - x, 1), math.max(math.ceil(base - first + ts), 1))
		slot.Name.Position = UDim2.fromOffset(x, top(first, s))
		slot.Laid = text
	end

	-- the name's look: its colour and transparency (cooling 0.78, the flash's ink),
	-- the shadows shown while it's over the hatch
	function FH.nameLook(slot, color, t, shadows)
		for _, pair in slot.Lines or {} do
			if color then
				pair.Face.TextColor3 = color
			end
			if t then
				pair.Face.TextTransparency = t
			end
			if shadows ~= nil then
				pair.Shadow.Visible = shadows and pair.Face.Text ~= ""
			end
		end
	end

	-- a move's name (any writer: HUD.SetQuirk, Hawks' flying bar, a body's keys)
	function FH.setName(slot, text)
		if not slot then
			return
		end
		slot.Raw = string.gsub(tostring(text or ""), "\n", " ")
		slot.Laid = slot.Name.Text -- (this one wins over a write not laid out yet)
		FH.layName(slot)
	end

	-- a slot's key letter (keyboard 1 / Q / R, a pad's LB / Y / LEFT)
	function FH.setKey(slot, text)
		if not slot then
			return
		end
		slot.KeyText = FH.keyWord(text)
		FH.placeSlot(slot)
	end

	-- the move row is there (a hero) or not ("PICK A HERO": nothing to press yet)
	function FH.moves(shown)
		if FH.state.moves == shown then
			return
		end
		FH.state.moves = shown
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		if FH.abilities and not touch then
			FH.abilities.Visible = shown
		end
		if touch then
			for _, i in { 1, 2, 3, 4, 6 } do
				local slot = slots[i]
				if slot and slot.OnPad then
					slot.Frame:SetAttribute("NoHero", not shown)
				end
			end
			if HUD.Touch.place then
				HUD.Touch.place()
			end
		end
	end

	-- the 0.12 s paper flash of a move coming back, its words ink for it
	function FH.flashSlot(slot)
		local f = slot.Frame
		if not (f and f.Visible) then
			return
		end
		local M = tok().Motion
		ST.flash(f, M.Flash)
		FH.nameLook(slot, tok().Ink)
		FH.numStyle(slot.Key, tok().Ink)
		task.delay(M.Flash, function()
			FH.nameLook(slot, tok().Paper)
			FH.numStyle(slot.Key, tok().Paper)
		end)
	end

	-- the seconds as the slot prints them: 4.4 under ten, 12 over
	function FH.secs(left)
		if left >= 10 then
			return tostring(math.ceil(left))
		end
		return string.format("%.1f", math.max(left, 0))
	end

	---------------------------------------------------------------------------
	-- THE VITALS: built for the layout (again on a phone / PC flip), then
	-- drawn from FH.state
	function FH.placeDock()
		local dock = FH.dock
		if not dock then
			return
		end
		if FH.phone then
			local V = FH.cfg("Vitals")
			dock.Position = UDim2.new(0, V.X, 1, 0)
			dock.Size = UDim2.fromOffset(V.Box[1], 110)
		else
			local M = Config.UI.Hud.Moves
			dock.Position = UDim2.new(0, M.X, 1, 0)
			dock.Size = UDim2.fromOffset(M.Width, 230)
		end
	end

	function FH.buildVitals()
		if not (vitals and FH.dock) then
			return
		end
		local old = vitals:FindFirstChild("Street")
		if old then
			old:Destroy()
		end
		local V = FH.cfg("Vitals")
		local Tk = tok()
		local dockX = FH.dock.Position.X.Offset
		local vtop = V.Base + 12 - V.Box[2]
		FH.vtop = vtop
		vitals.Size = UDim2.fromOffset(V.Box[1], V.Box[2])
		vitals.Position = UDim2.new(0, V.X - dockX, 1, vtop - FH.baseH())
		local function at(x, y)
			return UDim2.fromOffset(math.floor(x - V.X + 0.5), math.floor(y - vtop + 0.5))
		end
		FH.at = at
		local holder = make("Frame", { Name = "Street", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = vitals })
		FH.holder = holder
		local nb = V.Base + V.NameBase
		FH.nb = nb
		-- THE SLASH = THE ULT METER: the ink stroke the hero's colour paints over
		local ult = make("Frame", { Name = "UltMeter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
		ultBar = ult
		FH.slash = ST.slash({
			Name = "Slash", Size = { V.SlashW, V.SlashH }, Color = FH.state.color or Tk.Paper, Value = 0, Ghost = true, GhostColor = Tk.Ink,
			GhostT = V.GhostT, Rotation = V.SlashTilt, Pos = at(V.X + V.SlashX, nb + V.SlashY - V.SlashH / 2), Parent = ult,
		})
		-- the hero's name on it (and its mode over it, small)
		local nm = ST.metrics(V.Name)
		local hero = make("Frame", {
			Name = "Hero", BackgroundTransparency = 1, Position = at(V.X + 4, nb - nm.Base), Size = UDim2.fromOffset(V.NameFit + 60, math.ceil(nm.H)),
			ZIndex = 2, Parent = holder,
		})
		FH.hero = hero
		FH.nameShadow = ST.label({ Name = "Shadow", Text = "", Size = V.Name, Color = Tk.Ink, Box = UDim2.fromScale(1, 1), Pos = UDim2.fromOffset(V.Shadow, V.Shadow), Z = 2, Parent = hero })
		HUD.NameLabel = ST.label({ Name = "Who", Text = "", Size = V.Name, Box = UDim2.fromScale(1, 1), Z = 3, Parent = hero })
		FH.nameLaid = nil
		FH.pickKey = ST.keyCap("M", math.floor(V.Name * 0.5 + 0.5), { Name = "PickKey", Anchor = V2(0, 1), Z = 4, Visible = false, Parent = holder })
		FH.mode = FH.pair({
			Name = "Mode", Text = "", Size = V.Mode, Color = Tk.Ash, Shadow = 1, Parent = holder, Z = 2,
			Pos = at(V.X + 6, top(nb - V.Name * Tk.Fonts.Display.Cap - V.ModeGap, V.Mode)),
		})
		-- after the slash: the ult's % (the ULT button carries it on a phone), or
		-- the key and its name when it's full, or the seconds while it's up
		FH.pct, FH.pctSign, FH.ultSecs, FH.readyKey, FH.readyName = nil, nil, nil, nil, nil
		if (V.Pct or 0) > 0 then
			local ex = V.X + V.SlashX + V.SlashW + 2
			local ly = nb - 2
			FH.ex, FH.ly = ex, ly
			FH.pct = ST.numerals("0", V.Pct, { Name = "UltPct", Shadow = 2, Pos = at(ex, top(ly, V.Pct)), Z = 2, Parent = ult })
			FH.pctSign = FH.pair({ Name = "UltPctSign", Text = "%", Size = V.PctSign, Shadow = 1, Pos = at(ex, top(ly, V.PctSign)), Z = 2, Parent = ult })
			FH.ultSecs = ST.numerals("", V.Pct, { Name = "UltSeconds", Shadow = 2, Pos = at(ex, top(ly, V.Pct)), Visible = false, Z = 2, Parent = ult })
			FH.buildReady()
		end
		-- HEALTH: a slab, the RED chip under the PAPER fill; the numbers after it
		local col = V.X + V.BarW + V.BarGap
		local hy = V.Base + V.HealthY
		local health = ST.slab({ Name = "Health", Size = { V.BarW, V.HealthH }, Color = Tk.Ink, T = V.HealthT, Pos = at(V.X, hy), Z = 1, Parent = holder })
		healthChip = ST.fill(health, { Name = "Chip", Color = Tk.Red, Value = FH.state.chip or 1 })
		healthFill = ST.fill(health, { Name = "Fill", Color = Tk.Paper, Value = 1 })
		local hb = hy + V.HealthH - 1
		healthText = ST.numerals("100", V.Hp, { Name = "HP", Shadow = 2, Pos = at(col - 2, top(hb, V.Hp)), Z = 2, Parent = holder })
		FH.hpMax = FH.pair({ Name = "HPMax", Text = "/100", Size = V.HpMax, Shadow = 1, Pos = at(col + 40, top(hb - 1, V.HpMax)), Z = 2, Parent = holder })
		FH.hpX = col - 2
		-- GUARD: ten leaning segments; EVADE: one solid bar beside them (they read apart)
		local gy = V.Base + V.GuardY
		local labels = (V.Label or 0) > 0
		guardBar = make("Frame", { Name = "GuardMeter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
		FH.guard = ST.segments(10, { Name = "Segments", Size = { V.GuardW, V.GuardH }, T = V.BarT, Pos = at(V.X, gy), Parent = guardBar })
		-- ((round 101) GUARD / EVADE take the kit's shadow for words over the world
		-- (2): on a bright street a 1 px one lost the G ("UARD" in the owner's shot)
		guardText = FH.pair({
			Name = "GuardLabel", Text = "GUARD", Size = labels and V.Label or 11, Shadow = Tk.ShadowOffset, Visible = labels, Z = 2, Parent = guardBar,
			Pos = at(V.X + 1, top(V.Base + V.LabelBase, labels and V.Label or 11)),
		})
		guardFill = FH.guard
		local ex2 = V.X + V.GuardW + V.EvadeGap
		local ew = V.BarW - V.GuardW - V.EvadeGap
		local ev = { Bar = make("Frame", { Name = "EvasiveMeter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder }) }
		ev.Slab = ST.slab({ Name = "Bar", Size = { ew, V.GuardH }, T = V.BarT, Pos = at(ex2, gy), Parent = ev.Bar })
		ev.Fill = ST.fill(ev.Slab, { Name = "Fill", Color = Tk.Paper, Value = 0 })
		ev.Text = FH.pair({
			Name = "EvadeLabel", Text = "EVADE", Size = labels and V.Label or 11, Shadow = Tk.ShadowOffset, Visible = labels, Z = 2, Parent = ev.Bar,
			Pos = at(ex2 + 1, top(V.Base + V.LabelBase, labels and V.Label or 11)),
		})
		HUD.Evasive = ev
		-- the resource lines that exist come back on the new layout
		for _, rt in FH.resources do
			FH.buildRes(rt)
		end
		FH.drawAll()
	end

	-- the full ult: its key cap and the ult's name, cut in after the slash
	function FH.buildReady()
		local V = FH.cfg("Vitals")
		if not (FH.at and ultBar and (V.Pct or 0) > 0) then
			return
		end
		if FH.readyKey then
			FH.readyKey:Destroy()
		end
		local shown = FH.readyName ~= nil and FH.readyName.Visible
		FH.readyKeyText = FH.keyWord(keyText.Ult or "G")
		FH.readyKey = ST.keyCap(FH.readyKeyText, V.ReadyKey, { Name = "UltKey", Pos = FH.at(FH.ex, FH.ly - V.ReadyKey), Z = 2, Parent = ultBar })
		FH.readyKey.Visible = shown
		if not FH.readyName then
			FH.readyName = FH.pair({ Name = "UltName", Text = ultName, Size = V.Ready, Shadow = 2, Z = 2, Parent = ultBar, Visible = false, Pos = UDim2.new() })
		end
		FH.readyName.Position = FH.at(FH.ex + FH.readyKey.Size.X.Offset + 6, top(FH.ly, V.Ready))
		FH.mirror(FH.readyName)
	end

	function FH.drawAll()
		FH.drawName()
		FH.drawUlt(false)
		FH.drawHealth()
		FH.drawGuard()
		FH.drawEvade()
	end

	-- the name: the hero's, or PICK A HERO and the menu's key; fitted to the
	-- slash (smaller for a long name, the baseline kept); a possessed body's
	-- rich text ("NAME <font>POSSESSED</font>") said plain
	function FH.drawName()
		local who = HUD.NameLabel
		if not who then
			return
		end
		local st = FH.state
		who.Text = st.hero and (st.name or "") or "PICK A HERO"
		FH.fitName()
		FH.say(FH.mode, st.hero and string.upper(st.mode or "") or "")
		if FH.mode then
			FH.mode.Visible = st.hero == true and (st.mode or "") ~= ""
			FH.fitLabel(FH.mode) -- ((round 100 review) as wide as its words: it was made empty)
		end
	end

	function FH.fitName()
		local who = HUD.NameLabel
		if not (who and FH.hero) then
			return
		end
		local V = FH.cfg("Vitals")
		local text = who.Text
		if string.find(text, "<", 1, true) then
			text = string.gsub(text, "<[^>]*>", "")
			who.Text = text
		end
		local size = V.Name
		while size > V.NameMin and ST.measure(text, size) > V.NameFit do
			size -= 2
		end
		local nm = ST.metrics(size)
		local ts = ST.textSize(size)
		for _, lab in { who, FH.nameShadow } do
			lab.TextSize = math.min(ts, 100)
			lab.Text = text
		end
		local w = math.ceil(ST.measure(text, size)) + 4
		FH.hero.Size = UDim2.fromOffset(w, math.ceil(nm.H))
		FH.hero.Position = FH.at(V.X + 4, top(FH.nb, size))
		FH.nameLaid = text
		-- PICK A HERO: the key that opens the heroes (a keyboard's M)
		if FH.pickKey then
			local show = not FH.state.hero and FH.keys == true and not FH.phone
			FH.pickKey.Visible = show
			FH.pickKey.Position = FH.at(V.X + 4 + w + 8, FH.nb)
		end
	end

	-- THE ULT METER: each gain paints in (0.25 s, Linear); full: one paper
	-- frame, then the key and the ult's name cut in, a paper frame every 1.5 s;
	-- up: the colour drains back over the ult and the seconds count down
	function FH.drawUlt(animate)
		local st = FH.state
		local v = math.clamp(st.ult or 0, 0, 100)
		local hero = st.hero == true
		local active = st.active == true
		local ready = hero and v >= 100 and not active
		if FH.slash then
			if not hero then
				ST.setSlash(FH.slash, 0)
			elseif active then
				if not st.timer then
					ST.setSlash(FH.slash, 1)
				end
			else
				local target = v / 100
				local cur = FH.slash:GetAttribute("SlashValue") or 0
				ST.setSlash(FH.slash, target, (animate and target > cur) and tok().Motion.UltGain or nil)
			end
		end
		if ready and not FH.wasReady then
			FH.pulseAt = os.clock() -- (the one paper frame now; one every 1.5 s after)
			FH.pulse()
		end
		FH.wasReady = ready
		if FH.pct then
			local showPct = hero and not ready and not active
			FH.pct.Visible = showPct
			ST.setNumerals(FH.pct, tostring(math.floor(v)))
			FH.pctSign.Visible = showPct
			FH.pctSign.Position = FH.at(FH.ex + FH.pct.Size.X.Offset + 2, top(FH.ly, FH.cfg("Vitals").PctSign))
			FH.mirror(FH.pctSign)
			FH.ultSecs.Visible = hero and active and st.timer ~= nil
			if FH.readyKeyText ~= FH.keyWord(keyText.Ult or "G") then
				FH.buildReady()
			end
			FH.readyKey.Visible = ready
			FH.readyName.Visible = ready
			FH.say(FH.readyName, string.upper(ultName or "ULT"))
			FH.fitLabel(FH.readyName)
		end
		ultReady = ready
		FH.touchUlt()
	end

	-- one paper frame on the slash (the full ult's beat)
	function FH.pulse()
		local s = FH.slash
		if not s then
			return
		end
		ST.tintSlash(s, tok().Paper)
		task.delay(Config.UI.Hud.Vitals.PulseFlash, function()
			if FH.slash == s then
				ST.tintSlash(s, FH.state.color or tok().Paper)
			end
		end)
	end

	-- the ult's clock (ends in server time): drain the slash over what's left
	function FH.ultTimer(ends, length)
		local st = FH.state
		if not ends then
			st.timer = nil
			FH.drawUlt(false)
			return
		end
		st.timer = { Ends = ends, Length = length }
		local left = math.max(ends - workspace:GetServerTimeNow(), 0)
		if FH.slash then
			ST.setSlash(FH.slash, math.clamp(left / math.max(length, 0.01), 0, 1))
			ST.setSlash(FH.slash, 0, left)
		end
		FH.drawUlt(false)
	end

	-- the hero you are: the name on the slash, its mode, the slash's colour
	function FH.setHero(view)
		local st = FH.state
		st.hero = view ~= nil
		st.name = view and string.upper(view.DisplayName or "") or nil
		st.mode = view and view.ModeName or nil
		st.color = view and view.Color or nil
		if FH.slash then
			ST.tintSlash(FH.slash, st.color or tok().Paper)
		end
		FH.drawName()
	end

	-- HEALTH: the chip (RED) holds what you just lost 0.4 s, then drains in
	-- 0.3 s; the fill and the numbers swap at once; under 25% the fill's RED
	function FH.health(hp, max)
		local st = FH.state
		st.hp, st.max = hp, max
		local ratio = (max and max > 0) and math.clamp(hp / max, 0, 1) or 0
		st.ratio = ratio
		FH.chipToken = (FH.chipToken or 0) + 1
		local token = FH.chipToken
		if healthChip then
			local was = healthChip:GetAttribute("StValue") or 0
			if ratio >= was then
				ST.setFill(healthChip, ratio)
				st.chip = ratio
			else
				local M = tok().Motion
				task.delay(M.ChipHold, function()
					if FH.chipToken == token and healthChip then
						st.chip = ratio
						ST.setFill(healthChip, ratio, M.ChipDrain, Enum.EasingStyle.Quad)
					end
				end)
			end
		end
		FH.drawHealth()
	end

	function FH.drawHealth()
		local st = FH.state
		local hp, max = st.hp or 100, st.max or 100
		local ratio = st.ratio or 1
		local V = FH.cfg("Vitals")
		if healthFill then
			ST.setFill(healthFill, ratio)
			ST.paintFill(healthFill, ratio < V.Low and tok().Red or tok().Paper)
		end
		if healthText then
			ST.setNumerals(healthText, tostring(math.max(math.ceil(hp), 0)))
			if FH.hpMax then
				FH.hpMax.Text = "/" .. tostring(math.floor(max))
				FH.hpMax.Size = UDim2.fromOffset(math.ceil(ST.measure(FH.hpMax.Text, V.HpMax)) + 2, FH.hpMax.Size.Y.Offset)
				FH.hpMax.Position = UDim2.fromOffset(healthText.Position.X.Offset + healthText.Size.X.Offset + 2, FH.hpMax.Position.Y.Offset)
				FH.mirror(FH.hpMax)
			end
		end
	end

	-- GUARD: paper segments; broken: RED ones (what's left bright, the rest dim)
	function FH.drawGuard()
		local g = FH.state.guard
		if not (g and FH.guard) then
			return
		end
		local Tk = tok()
		local ratio = math.clamp(g.Value / math.max(g.Max, 1), 0, 1)
		if g.Broken then
			ST.setSegments(FH.guard, ratio, { Color = Tk.Red, T = 0.1, EmptyColor = Tk.Red, EmptyT = 0.75 })
			FH.say(guardText, "GUARD BROKEN", Tk.Red)
		else
			ST.setSegments(FH.guard, ratio, { Color = Tk.Paper, T = 0, EmptyColor = Tk.Ink, EmptyT = FH.cfg("Vitals").BarT })
			FH.say(guardText, "GUARD", Tk.Paper)
		end
		FH.fitLabel(guardText)
	end

	-- EVADE: one solid bar; full while you're down: the key to get out
	function FH.drawEvade()
		local e = FH.state.evade
		local ev = HUD.Evasive
		if not (e and ev and ev.Fill) then
			return
		end
		local ready = e.Value >= 100
		ST.setFill(ev.Fill, e.Value / 100, 0.2)
		if ready and e.Ragdolled then
			FH.say(ev.Text, FH.keyWord(keyText.Dash or "Q") .. " TO ESCAPE")
		else
			FH.say(ev.Text, "EVADE")
		end
		FH.fitLabel(ev.Text)
	end

	-- a label as wide as its words (and its shadow)
	function FH.fitLabel(face)
		if not face then
			return
		end
		local size = face:GetAttribute("Em")
		if not size then
			size = face.TextSize / tok().Fonts.Display.K
			face:SetAttribute("Em", size)
		end
		face.Size = UDim2.fromOffset(math.ceil(ST.measure(face.Text, size)) + 2, face.Size.Y.Offset)
		FH.mirror(face)
	end

	---------------------------------------------------------------------------
	-- THE RESOURCE LINE (one at a time: sweat, heat, stomach, feathers, a
	-- hero's pips): a thin paper fill on ink, one word at its right. The
	-- how-tos are one-time TIP toasts now. rt.Bar / .Fill / .Text as before.
	function FH.res(kind)
		local rt = FH.resources[kind]
		if not rt then
			rt = { Kind = kind, shown = false, v = 0, word = string.upper(kind) }
			FH.resources[kind] = rt
			HUD[kind] = rt
			FH.buildRes(rt)
		end
		return rt
	end

	function FH.buildRes(rt)
		local holder = FH.holder
		if not (holder and holder.Parent and FH.at) then
			return
		end
		local V = FH.cfg("Vitals")
		local Tk = tok()
		if rt.Bar then
			rt.Bar:Destroy()
		end
		local ry = V.Base + V.ResY
		rt.Bar = make("Frame", { Name = rt.Kind, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = rt.shown == true, Parent = holder })
		rt.Fill, rt.Chip, rt.Flash, rt.Pips = nil, nil, nil, nil
		if rt.Kind == "Pips" then
			FH.buildPips(rt)
		else
			rt.Line = ST.slab({ Name = "Line", Size = { V.BarW, V.ResH }, T = V.ResT, Pos = FH.at(V.X, ry), Parent = rt.Bar })
			if rt.Kind == "Feathers" then
				-- (what he just spent stays ash a moment, then drains after)
				rt.Chip = ST.fill(rt.Line, { Name = "Chip", Color = Tk.Ash, Value = rt.chip or 0 })
			end
			rt.Fill = ST.fill(rt.Line, { Name = "Fill", Color = Tk.Paper, Value = rt.v or 0 })
			if rt.Kind == "Feathers" then
				-- (fire burning them: a RED beat over the line)
				rt.Flash = ST.fill(rt.Line, { Name = "Flash", Color = Tk.Red, T = 1, Value = 1 })
			end
		end
		rt.Text = FH.pair({
			Name = "Word", Text = rt.word or "", Size = V.ResText, Shadow = 1, Z = 2, Parent = rt.Bar,
			Pos = FH.at(V.X + V.BarW + V.BarGap, top(ry + V.ResH + 1, V.ResText)),
		})
		rt.State = rt.Text -- (one word: the state is the word)
		FH.drawRes(rt)
	end

	-- a hero's pips: one leaning segment each (made again when how many changes;
	-- the line's word stays the same label)
	function FH.buildPips(rt)
		if not (rt.Bar and FH.at) then
			return
		end
		local V = FH.cfg("Vitals")
		if rt.Pips then
			rt.Pips:Destroy()
		end
		local ry = V.Base + V.ResY
		rt.Pips = ST.segments(math.max(rt.max or 3, 1), { Name = "Line", Size = { V.BarW, math.max(V.ResH, 4) }, Gap = 4, T = V.ResT, Pos = FH.at(V.X, ry), Parent = rt.Bar })
		rt.Line = rt.Pips
		rt.pipsMax = rt.max or 3
	end

	-- show it (v 0-1, its word, RED for trouble) or hide it (v nil)
	function FH.setRes(kind, v, word, danger, tween)
		local rt = FH.resources[kind]
		if v == nil then
			if rt then
				rt.shown = false
				if rt.Bar then
					rt.Bar.Visible = false
				end
			end
			return rt
		end
		rt = FH.res(kind)
		rt.shown = true
		rt.v = math.clamp(v, 0, 1)
		rt.word = word
		rt.danger = danger == true
		rt.tween = tween
		FH.drawRes(rt)
		return rt
	end

	function FH.drawRes(rt)
		if not rt.Bar then
			return
		end
		local Tk = tok()
		rt.Bar.Visible = rt.shown == true
		if rt.Pips then
			ST.setSegments(rt.Pips, rt.v or 0, { Color = Tk.Paper, T = 0, EmptyColor = Tk.Ink, EmptyT = FH.cfg("Vitals").ResT })
		elseif rt.Fill then
			ST.setFill(rt.Fill, rt.v or 0, rt.tween)
		end
		FH.say(rt.Text, rt.word or "", rt.danger and Tk.Red or Tk.Paper)
		FH.fitLabel(rt.Text)
	end

	---------------------------------------------------------------------------
	-- THE KILL FEED (top right, newest on top, at most 4 - 2 on a phone; 6 s):
	-- KILLER [slash in the killer's colour] VICTIM, Oswald 14. Your own row is
	-- paper with ink words and says YOU. A new row slides 24 px in from the
	-- right; older ones step down at once and fade to 0.6.
	function FH.buildFeed()
		local F = FH.cfg("Feed")
		if not feedList then
			feedList = make("Frame", {
				Name = "KillFeed",
				BackgroundTransparency = 1,
				AnchorPoint = V2(1, 0),
				Parent = FH.root,
			}, {
				make("UIListLayout", { Padding = UDim.new(0, F.Gap), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
			})
		end
		FH.placeFeed()
		feedList.Size = UDim2.fromOffset(640, F.Max * (F.H + F.Gap))
		local list = feedList:FindFirstChildOfClass("UIListLayout")
		if list then
			list.Padding = UDim.new(0, F.Gap)
		end
		-- ((round 100 review) rows made at the other layout's size go with a flip)
		local flipped = FH.feedPhone ~= nil and FH.feedPhone ~= FH.phone
		FH.feedPhone = FH.phone
		for _, child in feedList:GetChildren() do
			if child:IsA("GuiObject") and (flipped or child.LayoutOrder >= F.Max) then
				child:Destroy()
			end
		end
	end

	-- the feed's place: under the corner (lower when the corner had to drop a row)
	function FH.placeFeed()
		if feedList then
			local F = FH.cfg("Feed")
			feedList.Position = UDim2.new(1, -F.Right, 0, F.Y + (FH.cornerDrop or 0))
		end
	end

	-- one row: spec { Left, Right, Color (the slash), You, Tags = { { Text, Color } } }
	function FH.feedRow(spec)
		if not feedList then
			return nil
		end
		local F = FH.cfg("Feed")
		local Tk = tok()
		local h = F.H
		local l = h * ST.lean()
		for _, child in feedList:GetChildren() do
			if child:IsA("GuiObject") then
				child.LayoutOrder += 1
				if child.LayoutOrder >= F.Max then
					child:Destroy()
				end
			end
		end
		local fg = spec.You and Tk.Ink or Tk.Paper
		local x = l + 8
		local parts = {}
		local function word(text, size, color)
			text = string.upper(tostring(text))
			table.insert(parts, { Text = text, Size = size, Color = color, X = x })
			-- ((round 101) type is drawn at a whole pixel size, so a long name can
			-- come out a few % wider than measured: Slack keeps it off the slash)
			x += ST.measure(text, size) * (1 + (F.Slack or 0)) + 8
		end
		if spec.Left then
			word(spec.Left, F.Text, fg)
		end
		if spec.Color then
			x -= 2
			table.insert(parts, { Slash = spec.Color, X = x })
			x += F.Slash[1] + 8
		end
		if spec.Right then
			word(spec.Right, F.Text, fg)
		end
		for _, tag in spec.Tags or {} do
			word(tag.Text, F.Tag, tag.Color or Tk.Ash)
		end
		local w = math.ceil(x - 8 + 8 + l)
		local row = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), LayoutOrder = 0, Parent = feedList })
		row:SetAttribute("FeedRow", true)
		local slab = ST.slab({ Name = "Slab", Size = { w, h }, Color = spec.You and Tk.Paper or Tk.Ink, T = spec.You and F.YouT or F.SlabT, Z = 1, Parent = row })
		for i, p in parts do
			if p.Slash then
				ST.slash({ Name = "Slash", Size = F.Slash, Rotation = F.SlashTilt, Color = p.Slash, Value = 1, Pos = UDim2.new(0, math.floor(p.X), 0.5, 0), Anchor = V2(0, 0.5), Z = 2, Parent = slab })
			else
				ST.label({ Name = i == 1 and "Left" or "Word", Text = p.Text, Size = p.Size, Color = p.Color, Pos = UDim2.new(0, math.floor(p.X), 0.5, 1), Anchor = V2(0, 0.5), Z = 3, Parent = slab })
			end
		end
		-- in from the right
		slab.Position = UDim2.fromOffset(F.Slide, 0)
		ST.tween(slab, tok().Motion.FeedSlide, { Position = UDim2.new() }, Enum.EasingStyle.Quad)
		task.delay(F.OldAfter, function()
			if row.Parent then
				FH.fade(row, F.Old)
			end
		end)
		task.delay(F.Life, function()
			if row.Parent then
				row:Destroy()
			end
		end)
		return row
	end

	---------------------------------------------------------------------------
	-- THE COMBO (its own lane, right; under the bag on a phone): 12 in big
	-- numerals with a 4 px ink shadow, HITS and 142 DMG after it
	function FH.buildCombo()
		local C = FH.cfg("Combo")
		local shown = comboFrame ~= nil and comboFrame.Visible
		if comboFrame then
			comboFrame:Destroy()
		end
		comboFrame = make("Frame", { Name = "Combo", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = shown, Parent = FH.root })
		-- (right-anchored on PC, left on a phone)
		local xs = FH.phone and 0 or 1
		local xo = FH.phone and C.Right or (C.Right - 1280)
		comboHits = ST.numerals(tostring(math.max(comboCount, 2)), C.Num, {
			Name = "Count", Shadow = C.Shadow, Anchor = V2(1, 0), Pos = UDim2.new(xs, xo, 0, top(C.Base, C.Num)), Parent = comboFrame,
		})
		FH.comboWord = FH.pair({ Name = "Hits", Text = "HITS", Size = C.Hits, Shadow = 2, Pos = UDim2.new(xs, xo + C.Gap, 0, top(C.HitsBase, C.Hits)), Parent = comboFrame })
		comboDamage = FH.pair({ Name = "Damage", Text = string.format("%d DMG", math.floor(comboTotal)), Size = C.Dmg, Shadow = 2, Pos = UDim2.new(xs, xo + C.Gap, 0, top(C.DmgBase, C.Dmg)), Parent = comboFrame })
		FH.fitLabel(comboDamage)
	end

	---------------------------------------------------------------------------
	-- THE BAG (left; top left under Roblox's buttons on a phone): a slab an
	-- item, its key cap (5..8), its NAME (the name is the icon) and how many
	function FH.items(list, selected, mode, onUse)
		FH.bagState = { List = list or {}, Selected = selected or 1, Mode = mode or "Keyboard", OnUse = onUse }
		FH.drawBag()
	end

	function FH.drawBag()
		local b = FH.bagState
		if not (b and FH.root) then
			return
		end
		local B = FH.cfg("Bag")
		local Tk = tok()
		if not FH.bag then
			FH.bag = make("Frame", { Name = "Items", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = FH.root })
		end
		FH.bag:ClearAllChildren()
		local maxKinds = (Config.Economy and Config.Economy.MaxKinds) or 4
		local l = B.H * ST.lean()
		for i, entry in b.List do
			if i > maxKinds then
				break
			end
			local picked = b.Mode == "Gamepad" and i == b.Selected
			local fg = picked and Tk.Ink or Tk.Paper
			local slab = ST.slab({
				Name = "Item" .. i, Button = true, Size = { B.W, B.H }, Color = picked and Tk.Paper or Tk.Ink, T = picked and 0 or B.T,
				Pos = UDim2.fromOffset(B.X, B.Y + (i - 1) * (B.H + B.Gap)), Parent = FH.bag,
			})
			slab:SetAttribute("Item", entry.Id)
			local x = math.floor(l + 6)
			if (B.Key or 0) > 0 and b.Mode == "Keyboard" then
				local cap = ST.keyCap(tostring(i + 4), B.Key, { Ink = picked, Pos = UDim2.new(0, math.floor(l + 3), 0.5, 0), Anchor = V2(0, 0.5), Z = 2, Parent = slab })
				x = math.floor(l + 3) + cap.Size.X.Offset + 6
			end
			local short = (Config.UI.Hud.ItemShort or {})[entry.Id]
			local item = Config.Items[entry.Id]
			local name = short or (item and item.Name) or tostring(entry.Id)
			ST.label({ Name = "ItemName", Text = string.upper(name), Size = B.Name, Color = fg, Pos = UDim2.new(0, x, 0.5, 1), Anchor = V2(0, 0.5), Z = 2, Parent = slab })
			ST.numerals(tostring(entry.Count or 1), B.Count, { Name = "Count", Color = fg, Anchor = V2(1, 0.5), Pos = UDim2.new(1, -math.floor(l * 0.5 + 8), 0.5, 1), Z = 2, Parent = slab })
			slab.Activated:Connect(function()
				if b.OnUse and entry.Id then
					b.OnUse(entry.Id)
				end
			end)
		end
	end

	---------------------------------------------------------------------------
	-- THE TOP BAR's tabs (QuirkTopBar): HEROES M, EMOTES B, SHOP H, RANKED,
	-- TOP L, the gear; TEST P in ash for testers. The only route into each
	-- menu: the open one is paper with ink words.
	FH.TABS = {
		{ Id = "Heroes", Text = "HEROES", Key = "M" }, { Id = "Emotes", Text = "EMOTES", Key = "B" }, { Id = "Shop", Text = "SHOP", Key = "H" },
		{ Id = "Ranked", Text = "RANKED" }, { Id = "Top", Text = "TOP", Key = "L" },
		-- ((round 100) the owner: "could we also put the join the discord thing in a
		-- better spot" - a tab: the invite card from anywhere. Only for a player
		-- Roblox lets see Discord links: HUD.SetDiscordTab, from QuirkClient's
		-- DiscordClient once PolicyService has answered; the kiosk stays)
		{ Id = "Discord", Text = "DISCORD" },
		{ Id = "Settings", Icon = "Gear" },
		{ Id = "Test", Text = "TEST", Key = "P" },
	}

	function FH.buildTabs()
		if not FH.topRoot then
			return
		end
		local TB = FH.cfg("TopBar")
		if topBar then
			topBar:Destroy()
		end
		topBar = ST.tabs({
			Name = "Bar", Items = FH.TABS, H = TB.H, Size = TB.Text, KeySize = TB.KeyText, Gap = TB.Gap, Keys = FH.keys and not FH.phone,
			Parent = FH.topRoot, OnPick = FH.pick,
		})
		FH.syncTabs(true)
	end

	-- a tab pressed: that menu opens (the others close) or, open, it closes
	function FH.pick(id)
		if id == "Discord" then
			if HUD.DiscordVisible and HUD.DiscordVisible() then
				HUD.HideDiscord()
			elseif HUD.OnDiscordTab then
				FH.closeMenus("Discord")
				HUD.OnDiscordTab()
			end
			FH.syncTabs(true)
			return
		end
		-- (the invite card shuts when any other tab is picked)
		if HUD.DiscordVisible and HUD.DiscordVisible() then
			HUD.HideDiscord()
		end
		-- ((round 100 review) ui_menus' route, once it's merged in: HUD.MenuRoute
		-- opens a tab's menu and shuts the rest itself (one full menu at a time,
		-- the outfit window counted as HEROES). EMOTES stays QuirkClient's (it
		-- knows a controller's card menu); TEST isn't a menu of theirs)
		if HUD.MenuRoute and id ~= "Emotes" and id ~= "Test" then
			HUD.MenuRoute(id)
			if id == "Heroes" and topCallbacks.OnCharacter then
				topCallbacks.OnCharacter(HUD.MenuVisible())
			end
			FH.syncTabs(true)
			return
		end
		local open = FH.activeTab() == id
		if not open then
			FH.closeMenus(id)
		end
		if id == "Heroes" then
			HUD.ToggleMenu()
			if HUD.MenuVisible() and HUD.ToggleShop then
				HUD.ToggleShop(false)
			end
			if topCallbacks.OnCharacter then
				topCallbacks.OnCharacter(HUD.MenuVisible())
			end
		elseif id == "Emotes" then
			if topCallbacks.OnEmotes then
				topCallbacks.OnEmotes()
			end
		elseif id == "Shop" then
			HUD.ToggleShop()
		elseif id == "Ranked" then
			if HUD.ToggleRanked then
				HUD.ToggleRanked()
			end
		elseif id == "Top" then
			HUD.ToggleBoard()
		elseif id == "Settings" then
			HUD.ToggleSettings()
		elseif id == "Test" then
			HUD.ToggleTestMenu()
		end
		FH.syncTabs(true)
	end

	-- every other menu shuts when a tab opens one
	function FH.closeMenus(except)
		local shut = {
			Heroes = function() HUD.ShowMenu(false) end,
			Shop = function() HUD.ToggleShop(false) end,
			Ranked = function() if HUD.ToggleRanked then HUD.ToggleRanked(false) end end,
			Top = function() HUD.ToggleBoard(false) end,
			Settings = function() HUD.ToggleSettings(false) end,
			Emotes = function() if HUD.EmoteWheelVisible and HUD.EmoteWheelVisible() then HUD.ShowEmoteWheel(false) end end,
		}
		local active = FH.activeTab()
		for id, fn in shut do
			if id ~= except and id == active then
				pcall(fn)
			end
		end
	end

	-- which menu is open now (its tab is paper)
	function FH.activeTab()
		local function on(fn)
			if not fn then
				return false
			end
			local ok, v = pcall(fn)
			return ok and v == true
		end
		if on(HUD.DiscordVisible) then
			return "Discord"
		end
		-- ((round 100 review) ui_menus' own word for it, once merged: HUD.OpenMenuId)
		if HUD.OpenMenuId then
			local ok, v = pcall(HUD.OpenMenuId)
			if ok and type(v) == "string" then
				return v
			end
		end
		if on(HUD.MenuVisible) then
			return "Heroes"
		elseif on(HUD.ShopVisible) then
			return "Shop"
		elseif on(HUD.RankedVisible) then
			return "Ranked"
		elseif on(HUD.BoardVisible) then
			return "Top"
		elseif on(HUD.SettingsVisible) then
			return "Settings"
		elseif on(HUD.EmoteWheelVisible) or on(HUD.EmoteMenuVisible) then
			return "Emotes"
		elseif testPanel and testPanel.Visible then
			return "Test"
		end
		return nil
	end

	function FH.syncTabs(force)
		if not topBar then
			return
		end
		-- TEST: only for testers (their test menu's built); the old corner button goes
		local test = topBar:FindFirstChild("Test")
		if test and test.Visible ~= (testPanel ~= nil) then
			test.Visible = testPanel ~= nil
			ST.packTabs(topBar)
			FH.buildCorner() -- ((round 100 review) the bar's longer: room for the corner again)
		end
		if testOpenButton then
			testOpenButton.Visible = false
		end
		local discord = topBar:FindFirstChild("Discord")
		if discord and discord.Visible ~= (FH.discordOn == true) then
			discord.Visible = FH.discordOn == true
			ST.packTabs(topBar)
			FH.buildCorner()
		end
		local id = FH.activeTab()
		if force or id ~= FH.tabShown then
			FH.tabShown = id
			ST.setTab(topBar, id)
			local lab = test and test:FindFirstChild("Label")
			if lab and id ~= "Test" then
				lab.TextColor3 = tok().Ash -- (the testers' tab, not a player's)
			end
		end
	end

	-- the bar's place: after Roblox's buttons, centred on their band; the
	-- wallet and rank top right on the same line
	function FH.placeTop()
		if not FH.topRoot then
			return
		end
		local x, y, h = topInset()
		local s = ST.scale()
		local TB = FH.cfg("TopBar")
		local key = tostring(FH.phone) .. tostring(FH.keys)
		if not topBar or FH.tabsKey ~= key then
			FH.tabsKey = key
			FH.buildTabs()
		end
		local ty = TB.Y
		if h and h > 0 then
			ty = math.floor((y + h / 2) / s - TB.H / 2 + 0.5)
		end
		FH.topY = ty
		topBar.Position = UDim2.fromOffset(math.floor(x / s + TB.X + 0.5), ty)
		FH.buildCorner()
	end

	---------------------------------------------------------------------------
	-- THE CORNER (top right): the wallet ([B] 1,527) and the rank (NO.1 HERO,
	-- 619 KO in ash, a 3 px paper line along its foot: the way to the next
	-- rank, full at the top); a third slab STREAK 5 from 3 up
	function FH.buildCorner()
		if not FH.topRoot then
			return
		end
		local C = FH.cfg("Corner")
		local Tk = tok()
		local st = FH.state
		if FH.corner then
			FH.corner:Destroy()
		end
		local h = C.H
		local l = h * ST.lean()
		local kills = st.kills or 0
		local _, rank, nextRank = Config.RankOf(kills)
		local rankText = string.gsub(string.upper(rank.Name), "NO%. ", "NO.")
		local koText = tostring(kills) .. " KO"
		local amount = FH.commas(st.bucks or 0)
		local streak = st.streak or 0
		-- ((round 100 review) the corner never runs into the tabs: on a narrow
		-- screen (a 667-point phone, a small window, a tester's TEST tab) the
		-- streak goes first, then the KO count, then the rank says its short
		-- name; if it still won't fit, the corner drops under the tabs' row and
		-- the feed under it)
		local function widths(ko, withStreak)
			local rw = math.ceil(ST.measure(rankText, C.Rank) + (ko and (ST.measure(koText, C.KO) + 10) or 0) + l * 2 + 16)
			local ww = math.ceil(ST.measure(amount, C.Bucks) + l * 2 + 18 + h * 0.62)
			local sw = withStreak and math.ceil(ST.measure("STREAK", C.Rank) + ST.measure(tostring(streak), C.Bucks) + l * 2 + 22) or 0
			return rw, ww, sw, rw + C.Gap + ww + (withStreak and (C.Gap + sw) or 0)
		end
		local room = math.huge
		local cam = workspace.CurrentCamera
		if topBar and cam then
			local right = 0
			for _, t in topBar:GetChildren() do
				if t:IsA("GuiObject") and t.Visible then
					right = math.max(right, t.Position.X.Offset + t.Size.X.Offset)
				end
			end
			room = cam.ViewportSize.X / ST.scale() - C.Right - (topBar.Position.X.Offset + right) - (C.Clear or 10)
		end
		local ko, withStreak = true, streak >= (C.Streak or 3)
		local rw, ww, sw, total = widths(ko, withStreak)
		if total > room and withStreak then
			withStreak = false
			rw, ww, sw, total = widths(ko, withStreak)
		end
		if total > room then
			ko = false
			rw, ww, sw, total = widths(ko, withStreak)
		end
		if total > room and rank.Short then
			-- (the rank's short name: LICENSED PRE-HERO is PRE-HERO)
			rankText = string.gsub(string.upper(rank.Short), "NO%. ", "NO.")
			rw, ww, sw, total = widths(ko, withStreak)
		end
		local drop = 0
		if total > room then
			-- (under the tabs, and under the toast lane too: a toast won't sit on the wallet)
			local _, toastBottom = ST.lane("Toast")
			drop = math.max(h + (C.Drop or 6), toastBottom + (C.Drop or 6) - (FH.topY or C.Y))
		end
		if drop ~= (FH.cornerDrop or 0) then
			FH.cornerDrop = drop
			FH.placeFeed()
		end
		local holder = make("Frame", {
			Name = "Corner", BackgroundTransparency = 1, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -C.Right, 0, (FH.topY or C.Y) + drop),
			Size = UDim2.fromOffset(0, C.H), Parent = FH.topRoot,
		})
		FH.corner = holder
		local rs = ST.slab({ Name = "RankCard", Size = { rw, h }, T = Tk.HudT, Pos = UDim2.new(1, -rw, 0, 0), Parent = holder })
		ST.label({ Name = "Rank", Text = rankText, Size = C.Rank, Pos = UDim2.new(0, math.floor(l + 8), 0.5, 1), Anchor = V2(0, 0.5), Z = 2, Parent = rs })
		ST.label({ Name = "Stats", Text = koText, Size = C.KO, Color = Tk.Ash, Visible = ko, Pos = UDim2.new(1, -math.floor(l + 8), 0.5, 1), Anchor = V2(1, 0.5), Z = 2, Parent = rs })
		local k = 1
		if nextRank then
			k = math.clamp((kills - rank.Kills) / math.max(nextRank.Kills - rank.Kills, 1), 0, 1)
		end
		local foot = ST.slab({ Name = "Progress", Size = { rw, C.Foot }, T = 1, Pos = UDim2.new(0, 0, 1, -C.Foot), Z = 2, Parent = rs })
		ST.fill(foot, { Name = "Fill", Color = Tk.Paper, Value = k })
		local x = rw + C.Gap
		-- the wallet
		local mark = math.floor(h * 0.56 + 0.5)
		local ws = ST.slab({ Name = "Wallet", Size = { ww, h }, T = Tk.HudT, Pos = UDim2.new(1, -(x + ww), 0, 0), Parent = holder })
		ST.keyCap("B", mark, { Name = "Mark", Pos = UDim2.new(0, math.floor(l + 6), 0.5, 0), Anchor = V2(0, 0.5), Z = 2, Parent = ws })
		ST.numerals(amount, C.Bucks, { Name = "Amount", Pos = UDim2.new(0, math.floor(l + 6 + h * 0.62 + 4), 0.5, 1), Anchor = V2(0, 0.5), Z = 2, Parent = ws })
		x += ww + C.Gap
		-- the streak, 3 and up (when there's room)
		if withStreak then
			local ss = ST.slab({ Name = "Streak", Size = { sw, h }, T = Tk.HudT, Pos = UDim2.new(1, -(x + sw), 0, 0), Parent = holder })
			ST.label({ Name = "Word", Text = "STREAK", Size = C.Rank, Pos = UDim2.new(0, math.floor(l + 8), 0.5, 1), Anchor = V2(0, 0.5), Z = 2, Parent = ss })
			ST.numerals(tostring(streak), C.Bucks, { Name = "Count", Anchor = V2(1, 0.5), Pos = UDim2.new(1, -math.floor(l + 8), 0.5, 1), Z = 2, Parent = ss })
		end
	end

	---------------------------------------------------------------------------
	-- the layout: PC or a phone's own (again on a flip, a new scale, touch on
	-- or off). force: whatever changed.
	function FH.layout(force)
		if not FH.root then
			return
		end
		local phone = ST.isPhone()
		local touch = HUD.Touch ~= nil and HUD.Touch.on == true
		-- ((round 100 review) the root's width too: two phones with one scale can
		-- be 667 or 812 points wide, and the vitals' room beside the grid with it)
		local cam = workspace.CurrentCamera
		local vw = cam and math.floor(cam.ViewportSize.X / ST.scale() + 0.5) or 0
		local key = tostring(phone) .. "|" .. tostring(touch) .. "|" .. tostring(ST.scale()) .. "|" .. tostring(vw)
		if not force and key == FH.layoutKey then
			return
		end
		FH.layoutKey = key
		FH.phone = phone
		FH.tablet = touch and not phone
		-- (a phone's vitals stop short of the touch grid's bottom row: FH.cfg)
		FH.vroom = nil
		if phone and touch and HUD.Touch.left then
			local left = HUD.Touch.left()
			FH.vroom = left and left - (Config.UI.Hud.Vitals.Phone.GridGap or 10) or nil
		end
		FH.placeDock()
		FH.buildVitals()
		FH.buildFeed()
		FH.buildCombo()
		FH.drawBag()
		FH.placeSlots(touch)
		HUD.PlaceTopBar()
		-- (the guard and evade have no words on a phone: one TIP says which is which)
		if phone and touch then
			FH.tip("Bars", Config.UI.Hud.Tips.Bars)
		end
	end

	-- the move slots: the PC row, or onto the touch grid
	function FH.placeSlots(touch)
		local T = HUD.Touch
		if FH.touchWas ~= touch then
			FH.touchWas = touch
			if FH.abilities then
				FH.abilities.Visible = not touch and FH.state.moves ~= false
			end
		end
		if T and T.LAYOUT and T.slot then
			for _, spec in T.LAYOUT do
				if type(spec[2]) == "number" and slots[spec[2]] then
					T.slot(slots[spec[2]], spec[1], touch)
				end
			end
			if touch and T.place then
				T.place()
			end
		end
	end

	---------------------------------------------------------------------------
	-- THE ULT BUTTON on touch IS the meter: the hero's colour fills it on the
	-- 12-degree cut; full, it's solid hero colour with ink words
	function FH.touchUlt()
		local T = HUD.Touch
		local u = T and T.ult
		if not u then
			return
		end
		local Tk = tok()
		local st = FH.state
		local v = math.clamp(st.ult or 0, 0, 100)
		local ready = st.hero == true and v >= 100 and st.active ~= true
		local color = st.color or Tk.Paper
		ST.paint(u.Button, ready and color or Tk.Ink, ready and 0 or Config.UI.Hud.Touch.T)
		ST.paintFill(u.Fill, color)
		if ready then
			ST.setFill(u.Fill, 0)
		elseif st.active and st.timer then
			local left = math.max(st.timer.Ends - workspace:GetServerTimeNow(), 0)
			ST.setFill(u.Fill, math.clamp(left / math.max(st.timer.Length, 0.01), 0, 1))
		else
			ST.setFill(u.Fill, st.hero and v / 100 or 0)
		end
		u.Label.TextColor3 = ready and Tk.Ink or Tk.Paper
		u.Pct.Visible = st.hero == true and not ready
		ST.setNumerals(u.Pct, st.active and st.timer and FH.secs(math.max(st.timer.Ends - workspace:GetServerTimeNow(), 0)) or tostring(math.floor(v)))
	end

	---------------------------------------------------------------------------
	-- EVERY FRAME: the hatches move in real time, the seconds step at 10 Hz;
	-- the ult's beat, its drain and seconds; the tabs; the names other code
	-- wrote (a possessed body's, Hawks' flying bar)
	function FH.step()
		local now = os.clock()
		local slow = now - (FH.slowAt or 0) >= 1 / (tok().Motion.CooldownHz or 10)
		if slow then
			FH.slowAt = now
		end
		-- a cooldown done: its slot flashes paper
		for key, cd in cooldowns do
			if now >= cd.Ends then
				cooldowns[key] = nil
				for _, slot in slots do
					if slot.BoundKey == key and slot.Frame.Visible then
						FH.flashSlot(slot)
					end
				end
			end
		end
		local M = Config.UI.Hud.Moves
		for _, slot in slots do
			local cd = slot.BoundKey and cooldowns[slot.BoundKey]
			local v = cd and math.clamp((cd.Ends - now) / cd.Length, 0, 1) or 0
			if v > 0 or (slot.cdShown or 0) > 0 then
				ST.setHatch(slot.Hatch, v)
			end
			slot.cdShown = v
			local cooling = v > 0
			if cooling ~= slot.cooling then
				slot.cooling = cooling
				FH.nameLook(slot, nil, cooling and M.CoolingT or 0, cooling)
				FH.numStyle(slot.Key, nil, cooling and 0.5 or M.KeyT)
			end
			if slow then
				local text = ""
				if cd then
					text = FH.secs(cd.Ends - now)
				elseif slot.Form and FH.state.form then
					local f = FH.state.form
					text = FH.secs(math.max(f.Ends - workspace:GetServerTimeNow(), 0))
				end
				if text ~= (slot.Seconds:GetAttribute("NumText") or "") then
					ST.setNumerals(slot.Seconds, text)
					slot.Seconds.Position = UDim2.fromOffset(slot.Frame.Size.X.Offset - (slot.OnPad and 6 or 7), slot.Seconds.Position.Y.Offset)
				end
				-- (someone else wrote the name: lay it out)
				if slot.Name.Text ~= slot.Laid then
					FH.setName(slot, slot.Name.Text)
				end
			end
			-- ((round 100 review) the feet only when they move: ST.setFill writes two
			-- attributes and six properties, and these were written every frame)
			if slot.Sub then
				local sub = cooldowns[slot.SubKey]
				local sv = sub and math.clamp((sub.Ends - now) / sub.Length, 0, 1) or 0
				if sv ~= slot.subShown then
					slot.subShown = sv
					ST.setFill(slot.Sub.Fill, sv)
				end
			end
		end
		-- a form's time along R's foot
		local form = FH.state.form
		if specialSlot and specialSlot.Form then
			local v = 0
			if form then
				local left = form.Ends - workspace:GetServerTimeNow()
				v = math.clamp(left / math.max(form.Length, 0.01), 0, 1)
				if left <= 0 then
					FH.state.form = nil
				end
			end
			if v ~= specialSlot.formShown then
				specialSlot.formShown = v
				ST.setFill(specialSlot.Form.Fill, v)
			end
		end
		-- the ult: the full meter's beat, the seconds while it's up
		local st = FH.state
		if FH.wasReady and now - (FH.pulseAt or 0) >= (tok().Motion.UltPulse or 1.5) then
			FH.pulseAt = now
			FH.pulse()
		end
		if slow then
			if st.active and st.timer and FH.ultSecs then
				local left = math.max(st.timer.Ends - workspace:GetServerTimeNow(), 0)
				local text = tostring(math.ceil(left))
				if text ~= FH.ultSecs:GetAttribute("NumText") then
					ST.setNumerals(FH.ultSecs, text)
				end
			end
			if st.active then
				FH.touchUlt()
			end
			-- the name (a possessed body's words, said plain), the shadows, the tabs
			local who = HUD.NameLabel
			if who and who.Text ~= FH.nameLaid then
				FH.fitName()
			end
			for face in FH.shadows do
				FH.mirror(face)
			end
			FH.syncTabs(false)
			-- a full menu hid the fight HUD: the touch pad lets go of its fingers
			local combat = gui and gui:FindFirstChild("Combat")
			local up = combat == nil or combat.Visible
			if up ~= FH.combatUp then
				FH.combatUp = up
				if HUD.TouchSync then
					HUD.TouchSync()
				end
			end
		end
	end
end

function HUD.InitFight(player)
	-- (round 100) your hero rank and the wallet, top right (the top bar's root)
	HUD.BuildRankCard(player)
	-- the vitals (guard and evade with them), the kill feed, the combo and the
	-- bag, laid out for this screen - and again on a phone / PC flip
	HUD.FH.layout(true)
	ST.onLayout(function()
		HUD.FH.layout()
	end)
end

-- MUSIC on / off (the ult themes and the event songs). (round 100) The old
-- top-right MUSIC button is gone: its switch is MUSIC in SETTINGS - the same
-- setting ("MAP MUSIC moves in here" - the game's one music switch). The
-- toggle QuirkClient hands over is kept for anything that still flips it
-- (HUD.ToggleMusic).
function HUD.BuildMusicToggle(onToggle)
	HUD.MusicToggleFn = onToggle
end

function HUD.ToggleMusic()
	if HUD.MusicToggleFn then
		HUD.MusicToggleFn()
	end
end

function HUD.SetMusic(on)
	HUD.SetSetting("Music", on)
end

function HUD.BindGuard(char)
	for _, c in guardConns or {} do
		c:Disconnect()
	end
	guardConns = {}
	local max = (Config.Guard and Config.Guard.Max) or 100
	-- ((round 100) ten leaning segments, RED when it's broken - HUD.FH.drawGuard.
	-- Healing out of a fight just moves the health bar: no "+ RECOVERING")
	local function update()
		HUD.FH.state.guard = {
			Value = char:GetAttribute("Guard") or max, Max = max,
			Broken = char:GetAttribute("GuardBroken") == true, Blocking = char:GetAttribute("Blocking") == true,
		}
		HUD.FH.drawGuard()
	end
	for _, attr in { "Guard", "Blocking", "GuardBroken" } do
		table.insert(guardConns, char:GetAttributeChangedSignal(attr):Connect(update))
	end
	update()
end

-- Big mid-screen word: PARRY!, GUARD BROKEN, ...
function HUD.Callout(text, color)
	-- (round 100) Stark Street (HUD.MO.callout): Oswald on a paper slab on the
	-- rise, in the moment lane (bad news on red); a stale one is dropped
	HUD.MO.callout(text, color)
end

-- Your landed hits chain into a combo; it resets after Config.Fights.ComboTimeout.
-- (round 100) Its own lane (right; under the bag on a phone): the count in
-- big numerals with an ink shadow, HITS and the damage beside it; each hit
-- stamps the count (1.12 to 1 in 0.06 s), a break fades it
function HUD.ComboHit(amount)
	comboCount += 1
	comboTotal += amount or 0
	comboToken += 1
	local token = comboToken
	if comboCount >= 2 and comboFrame then
		comboFrame.Visible = true
		HUD.FH.fade(comboFrame, 1)
		ST.setNumerals(comboHits, tostring(comboCount))
		HUD.FH.say(comboDamage, string.format("%d DMG", math.floor(comboTotal)))
		HUD.FH.fitLabel(comboDamage)
		ST.stamp(comboHits)
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
		local frame = comboFrame
		HUD.FH.fade(frame, 0.35)
		local token = comboToken
		task.delay(0.26, function()
			if comboToken == token and frame.Parent then
				frame.Visible = false
				HUD.FH.fade(frame, 1)
			end
		end)
	end
end

-- data: { Killer, KillerQuirk, Victim, VictimQuirk, Streak, Callout, Shutdown, Dummy, Finisher }.
-- (round 100) KILLER [slash in the killer's hero colour] VICTIM, in caps; your
-- own row paper with ink words and YOU for your name; FINISHED in RED, a
-- streak's callout and a shutdown as small ash tags; no killer: DOWN.
function HUD.KillFeed(data)
	local FH = HUD.FH
	if not feedList then
		return
	end
	local _, killerColor = quirkLabel(data.KillerQuirk)
	local S = Config.UI.Street
	local me = FH.me
	local tags = {}
	if data.Finisher then
		table.insert(tags, { Text = "FINISHED", Color = S.Red })
	end
	-- ((round 100 review) a phone's rows keep to FINISHED: its tags are 11 like its names)
	local extras = FH.cfg("Feed").Extras ~= false
	if data.Callout and extras then
		table.insert(tags, { Text = data.Callout })
	end
	if data.Shutdown and extras then
		table.insert(tags, { Text = string.format("ENDED %d", data.Shutdown) })
	end
	local you = me ~= nil and (data.Killer == me or data.Victim == me)
	local function name(n)
		return (me ~= nil and n == me) and "YOU" or tostring(n or "?")
	end
	if data.Killer then
		FH.feedRow({ Left = name(data.Killer), Right = name(data.Victim), Color = killerColor, You = you, Tags = tags })
	else
		table.insert(tags, 1, { Text = "DOWN" })
		FH.feedRow({ Left = name(data.Victim), You = you, Tags = tags })
	end
end

-- (round 100) a row of the feed for anyone's news (a rank-up: BOOCAT008 [slash]
-- SEMI-PRO): spec = { Left, Right, Color (the slash), You, Tags = { { Text, Color } } }
function HUD.FeedRow(spec)
	return HUD.FH.feedRow(spec)
end

-- You landed a KO. data: { Victim, Streak, Counted, Callout, Heal, Finisher }
function HUD.KOPopup(data)
	-- (round 100) Stark Street (HUD.MO.koPop): K.O. in red on a short band in
	-- the moment lane, who, and what it got you
	HUD.MO.koPop(data)
end

-- You went down: who did it and how the fight went
function HUD.ShowRecap(data)
	-- (round 100) Stark Street's K.O. screen (HUD.MO.down): the world black and
	-- white, one leaning band - K.O., who did it on their slash, four numbers,
	-- BACK IN stepping down
	HUD.ComboBreak()
	HUD.MO.down(data)
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
		HUD.MO.skin(frame) -- ((round 100) Stark Street's light touch: the rows get it as they're built)
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
		HUD.MO.reskin(frame) -- ((round 100) what it built after the skin went on: a light touch on all of it)
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

	-- NEW HERO: (round 100) Stark Street's - the picker's detail block, full
	-- width, in the moment lane (HUD.MO.newHero): NEW HERO, his number and mode,
	-- his name on his slash, his sentence, his moves, how to play him. Held 3.8 s
	-- (cut short if the picker comes out). Returns true if it was cut short.
	function RP.showBanner(b)
		return HUD.MO.newHero(b)
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
				-- ((round 100) a rank-up or a K.O. first: the moment lane's order sees to it)
				local t = os.clock()
				while os.clock() - t < 12 and phoneOut() do
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
		HUD.MO.skin(frame) -- ((round 100) Stark Street's light touch: the cards get it as they're built)
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
		HUD.MO.reskin(frame) -- ((round 100) what it built after the skin went on: a light touch on all of it)
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
	-- (round 100) Stark Street: ADMIN ABUSE is the cut-in recipe in the event's
	-- colour (HUD.MO.event: B/W, the letterbox, its slash, its name, its line,
	-- who and how long); EVENT(S) OVER a stamp in the status lane; the chips
	-- ink slabs in the status lane (the ranked scoreboard wins it); the reel an
	-- ink slab with your hero's slash on the payline. spec: { Id, Name, Icon,
	-- Color, Blurb, Length, Global, By, OnShow, Still }. Returns when it's gone.
	function EP.showBanner(spec)
		HUD.MO.event(spec)
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

	-- EVENT OVER: list = { { Name, Color, Icon } } (one stamp, however many ended)
	function HUD.EventOver(list)
		if not gui or type(list) ~= "table" or #list == 0 then
			return
		end
		HUD.MO.eventOver(list)
	end

	---------------------------------------------------------------- the chips
	-- the status lane, one per event running (HUD.MO.chips): its name, a note
	-- (EVERY SERVER, your bills...), the time left (red the last 10 s), a line
	-- running down; as many to a row as fit between the feed and its twin
	-- list: { { Id, Ends, Length, Global } } in Order (empty: none)
	function HUD.SetEventChips(list)
		if not gui then
			return
		end
		return HUD.MO.chips(list)
	end
	function HUD.SetEventChipNote(id, text)
		EP.notes[id] = text
		EP.drawChips()
	end
	function EP.drawChips()
		HUD.MO.drawChips()
	end

	---------------------------------------------------------------- the reel
	-- HERO SHUFFLE's slot machine: heroes rolling past, slowing, landing on
	-- yours at spin s (HUD.MO.reel). opts: { Pool = { ids }, OnTick = fn (a
	-- hero going by), OnLand = fn, Still = fn, Back = true }
	function HUD.ShuffleReel(hero, spin, opts)
		opts = type(opts) == "table" and opts or {}
		if not gui or not Config.Quirks[hero or ""] then
			return
		end
		HUD.MO.reel(hero, math.clamp(tonumber(spin) or 2.6, 0.5, 6), opts)
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
		for i = 1, 8 do -- ((round 95) a player: a dummy's 3 and their hero's 5)
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
				-- ((round 95) a player's own moves each have theirs: Cd, the slot)
				local ck = m.Cd or m.Act or ""
				local ready = body and tonumber(body:GetAttribute("PossessCd_" .. ck)) or nil
				local left = ready and ready - serverNow or 0
				-- (how long it was, from when this cooldown was first seen)
				if ready and PH.cdAt[ck] ~= ready then
					PH.cdAt[ck] = ready
					PH.cdLen[ck] = math.max(left, 0.05)
				end
				if left > 0.02 then
					box.Cover.Size = UDim2.fromScale(1, math.clamp(left / (PH.cdLen[ck] or left), 0, 1))
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
		-- ((round 95) a player's eight keys: narrower boxes)
		local boxW = #(info.Moves or {}) > 5 and 84 or 104
		for i, box in PH.boxes do
			local m = info.Moves and info.Moves[i]
			box.Frame.Visible = m ~= nil
			box.Frame.Size = UDim2.fromOffset(boxW, 70)
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
	-- (round 95) THE POSSESSED PLAYER'S SCREEN: a dev's in their body. A
	-- banner along the top - CONTROLLED BY <who>, and that they get it back
	-- when he leaves (or reset) - and the screen's edge pulses his colour.
	-- info = { By = his name } - nil: gone
	---------------------------------------------------------------------------
	function PH.takenBanner()
		if PH.taken and PH.taken.Parent then
			return PH.taken
		end
		if not gui then
			return nil
		end
		local v = violet()
		local edgeF = make("Frame", {
			Name = "PossessedEdge",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 1,
			Parent = gui,
		}, { make("UIStroke", { Name = "Glow", Thickness = 6, Color = v, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		local f = make("Frame", {
			Name = "PossessedBanner",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 74),
			Size = UDim2.new(0.92, 0, 0, 58),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.08,
			Visible = false,
			ZIndex = 30,
			Parent = gui,
		}, {
			make("UISizeConstraint", { MaxSize = Vector2.new(470, 58) }),
			corner(10),
			make("UIStroke", { Name = "Edge", Thickness = 2, Color = v, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 150, 200)), Rotation = 90 }),
		})
		make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 26, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			ZIndex = 31,
			Parent = f,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Thickness = 2, Color = v, Transparency = 0.2 }) })
		make("Frame", {
			Name = "Pulse",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 26, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = light(v),
			ZIndex = 32,
			Parent = f,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		make("TextLabel", {
			Name = "Kicker",
			Position = UDim2.fromOffset(46, 7),
			Size = UDim2.new(1, -58, 0, 14),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = light(v),
			Text = "CONTROLLED BY",
			ZIndex = 31,
			Parent = f,
		})
		make("TextLabel", {
			Name = "Dev",
			Position = UDim2.fromOffset(46, 20),
			Size = UDim2.new(1, -58, 0, 20),
			BackgroundTransparency = 1,
			Font = HEAD_FONT,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = WHITE,
			Text = "",
			ZIndex = 31,
			Parent = f,
		}, { textStroke(1) })
		make("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(46, 40),
			Size = UDim2.new(1, -58, 0, 13),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = DIM,
			Text = "A dev is in your body. It's yours again when they leave - or reset.",
			ZIndex = 31,
			Parent = f,
		})
		PH.taken, PH.takenEdge = f, edgeF
		return f
	end
	function HUD.Possessed(info)
		local f = PH.takenBanner()
		if not f then
			return
		end
		if not info then
			f.Visible = false
			PH.takenEdge.Visible = false
			if PH.takenConn then
				PH.takenConn:Disconnect()
				PH.takenConn = nil
			end
			return
		end
		f.Dev.Text = string.upper(tostring(info.By or ""))
		if not f.Visible then
			-- (it drops in)
			f.Position = UDim2.new(0.5, 0, 0, 40)
			f.Visible = true
			pcall(function()
				TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 74) }):Play()
			end)
		end
		PH.takenEdge.Visible = true
		if not PH.takenConn then
			PH.takenConn = RunService.RenderStepped:Connect(function()
				local now = os.clock()
				local k = (math.sin(now * 3.4) + 1) / 2
				local glow = PH.takenEdge:FindFirstChild("Glow")
				if glow then
					glow.Transparency = 0.35 + 0.5 * k
				end
				local ring = f:FindFirstChild("Ring")
				if ring then
					local s = 12 + 14 * ((now * 1.1) % 1)
					ring.Size = UDim2.fromOffset(s, s)
					local st = ring:FindFirstChildOfClass("UIStroke")
					if st then
						st.Transparency = 0.15 + 0.85 * ((now * 1.1) % 1)
					end
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
			Text = "Take over a body - a dummy, the Nomu, a player. K aims, K again leaves.",
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
		-- ((round 100 review) a leaning ink slab like the rest of the touch grid, its
		-- word in Oswald (GRAB / DROP: CH.word), no round corner, no glowing ring.
		-- The button's own Text still says it, unseen, for anything that reads it)
		local b = ST.slab({
			Name = "TouchGRAB", Button = true, Size = { 56, 56 }, Anchor = Vector2.new(0.5, 0.5), T = Config.UI.Hud.Touch.T, Z = 1,
			Visible = false, Parent = T.pad,
		})
		b.Text = "GRAB"
		b.TextTransparency = 1
		ST.label({ Name = "Label", Text = "GRAB", Size = Config.UI.Hud.Touch.Text.Verb, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 3, Parent = b })
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
		-- ((round 100 review) the pad lives in the combat HUD's scaled root now: its
		-- offsets are root units, so the screen pixels are divided by the scale -
		-- the same spot on the glass as before)
		local s = (T.pad and T.pad.Parent and T.pad.Parent.Name == "StreetRoot") and ST.scale() or 1
		b.Position = UDim2.new(1, (jx + CH.SPOT[1] * k) / s, 1, (jy + CH.SPOT[2] * k) / s)
		b.Size = UDim2.fromOffset(math.floor(CH.SPOT[3] * k / s + 0.5), math.floor(CH.SPOT[3] * k / s + 0.5))
		if b:GetAttribute("StSlab") then
			ST.relayout(b)
			local lab = b:FindFirstChild("Label")
			if lab then
				lab.TextSize = math.min(ST.textSize(Config.UI.Hud.Touch.Text.Verb * k), 100) -- (a tablet's bigger button: bigger words)
			end
		end
	end
	-- GRAB / DROP on the phone's button (its own Text kept in step for readers)
	function CH.word(text)
		local b = CH.button
		if b then
			b.Text = text
			local lab = b:FindFirstChild("Label")
			if lab then
				lab.Text = text
			end
		end
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
			-- ((round 100 review) the buttons lean now: the dim is an ink slab of the
			-- button's own shape over it, not a round blob)
			if on and not cover then
				cover = ST.slab({ Name = "CarryDim", Size = { f.Size.X.Offset, f.Size.Y.Offset }, Color = Config.UI.Street.Ink, T = 0.45, Z = 9, Parent = f })
			end
			if cover then
				if on and cover.Size ~= UDim2.fromOffset(f.Size.X.Offset, f.Size.Y.Offset) then
					cover.Size = UDim2.fromOffset(f.Size.X.Offset, f.Size.Y.Offset)
					ST.relayout(cover)
				end
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
				CH.word("GRAB")
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
				CH.word("DROP")
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

-- a short message across the top of the screen. (round 100) It's the kit's
-- toast now (its own ScreenGui over the top bar, one at a time, queued): the
-- colour only says whether it's bad news (a red kicker), "WORD: the rest"
-- becomes a kicker, and emoji / middots go (ST.notice)
function HUD.Notice(text, color)
	ST.notice(text, color)
end

---------------------------------------------------------------------------
-- Cinematic letterbox + title card
---------------------------------------------------------------------------

function HUD.Letterbox(on, title, subtitle, color)
	-- (round 100) Stark Street (HUD.MO.letterbox): ink bars that snap in (in
	-- QuirkCinema), the title on a slash in the bottom one; the HUD steps aside
	HUD.MO.letterbox(on, title, subtitle, color)
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

		-- (round 100) THE SHOP, Stark Street (mockup 04): one leaning ink sheet -
		-- SHOP / EMOTES / CODES as big words, your slash under the open one; the
		-- list column (EMOTE ROLL with its odds as a bar and a price button per
		-- multiplier, SODA DROP, ITEM DROP, the owner's PASSES, every item by
		-- name), the keeper on his paper slab with his one marker line, the big
		-- wallet. SH.build (below) makes it, and makes it again for a phone's own
		-- layout (the keeper hides, the prices stay on the right edge).
		SH.build()
		HUD.BuildEmoteReveal()
		HUD.ST.onLayout(function(phone)
			if shopPanel and phone ~= SH.phone then
				SH.build()
			end
		end)
		HUD.Menus.watch(function()
			if shopPanel and SH.key ~= HUD.Menus.viewKey() then
				SH.build()
			end
		end)

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
		-- (round 100) the wallet is the corner's slab top right ([B] 1,527, the top
		-- bar's root); the old one built with the shop stays hidden
		HUD.FH.state.bucks = bucks
		HUD.FH.buildCorner()
		for _, old in { wallet, shopButton } do
			if old then
				old.Visible = false
			end
		end
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
		-- ((round 100) no "+1" pop and no bounce on the wallet: a KO's +1 BUCK is
		-- the KO moment's; the number just swaps)
	end

	-- list: { { Id, Count } } in bag order; selected: the controller's pick.
	-- (round 100) THE BAG is Stark Street's (HUD.FH.items: a slab an item, its
	-- key cap, its name, how many; the pick on a pad is paper); the old item
	-- bar built with the shop stays hidden. The shop's HAVE chips as before.
	function HUD.SetItems(list, selected)
		selectedItem = selected or 1
		HUD.FH.items(list, selectedItem, inputMode, function(id)
			if shopCallbacks.OnUse then
				shopCallbacks.OnUse(id)
			end
		end)
		if itemBar then
			itemBar.Visible = false
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
	-- (round 100) a number with its thousands marked: 1527 -> 1,527
	function SH.commas(n)
		local s = tostring(math.floor(tonumber(n) or 0))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""):gsub("^%-,", "-"))
	end
	-- your hero's colour (the slash under the open tab); paper with no hero
	function SH.heroColor()
		local q
		pcall(function()
			q = Config.Quirks[game:GetService("Players").LocalPlayer:GetAttribute("Quirk") or ""]
		end)
		return q and q.Color or Config.UI.Street.Paper
	end

	-- (round 100) THE KEEPER's lines (Config.UI.Menus.Keeper: his voice, in marker)
	SH.lines = setmetatable({}, {
		__index = function(_, k)
			return Config.UI.Menus.Keeper[k]
		end,
	})

	---------------------------------------------------------------------------
	-- (round 100) BUILDING THE SHOP (mockup 04; a phone: one column, no keeper)
	---------------------------------------------------------------------------
	function SH.build()
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local M = Config.UI.Menus.Shop
		local K = M.Copy
		local ES = Config.EmoteShop or {}
		local was = shopPanel ~= nil and ST.panelOpen(shopPanel)
		if shopPanel then
			shopPanel:Destroy()
		end
		SH.keeper, SH.parts, SH.line = nil, nil, nil
		table.clear(cards)
		table.clear(tabButtons)
		table.clear(emoteCards)
		table.clear(emoteSlots)
		SH.passCards, SH.rollButtons, SH.robuxButtons, SH.prices = {}, {}, {}, {}
		local phone = ST.isPhone()
		SH.phone = phone
		SH.key = MN.viewKey()
		local lean = ST.lean()
		local T, B, X, W = M.Top, M.Bottom, M.X, M.W
		-- ((round 100 review) a phone's sheet runs to its real right edge - a
		-- 16:9 phone is 667 wide, not the mockup's 812 - and its column, prices,
		-- wallet and X keep inside it; on PC the sheet sits on the centred stage)
		local vw, vh = MN.view()
		if phone then
			T, B, X, W = 42, vh, 96, vw - 96
		end
		local margin = phone and 22 or M.Margin
		shopPanel = MN.panel({
			Name = "Shop", Parent = MN.stage(), X = X, W = W, Top = T, Bottom = B, T = S.MenuT, Margin = margin,
			Ends = phone and "Left" or "Both", Z = 10,
		})
		local ox = shopPanel:GetAttribute("SheetX")
		shopPanel.Sheet.Active = true -- (a click on the sheet stays on it: no punch through the menu)
		local content = shopPanel.Sheet.Content
		-- (the content's leaning margin and the sheet's right edge, in screen units)
		local function lx(y)
			return X - (y - T) * lean + margin
		end
		local function rx(y)
			return phone and (vw - 22) or (X + W - (y - T) * lean - 30)
		end
		local function sx(x)
			return x - ox
		end
		-- (what HUD.SetBucks / HUD.SetInputMode still write to: kept, hidden)
		shopWallet = make("TextLabel", { Name = "WalletText", BackgroundTransparency = 1, Visible = false, Text = "", Parent = content })
		shopHint = make("TextLabel", { Name = "Hint", BackgroundTransparency = 1, Visible = false, Text = "", Parent = content })

		-- the tabs: big words, your slash under the open one; the X
		local ty = phone and 76 or M.TabsY
		local tsize = phone and 22 or M.Tab
		local tabs = make("Frame", { Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		SH.tabsFrame = tabs
		local tx = lx(ty)
		for i, id in { "Shop", "Emotes", "Rewards" } do
			local word = K.Tabs[i]
			local w = ST.measure(word, tsize)
			local m = ST.metrics(tsize)
			local b = make("TextButton", {
				Name = id .. "Tab",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Size = UDim2.fromOffset(math.ceil(w) + 4, math.ceil(m.H)),
				Position = UDim2.fromOffset(math.floor(sx(tx) + 0.5), math.floor(ty - T - m.Base + 0.5)),
				ZIndex = 4,
				Parent = tabs,
			})
			ST.label({ Name = "Label", Text = word, Size = tsize, Box = UDim2.fromScale(1, 1), Z = 4, Parent = b })
			b:SetAttribute("Word", w)
			tabButtons[id] = b
			b.Activated:Connect(function()
				HUD.ShopTab(id)
			end)
			tx += w + (phone and 18 or 26)
		end
		ST.closeX({ Name = "Close", Size = phone and 14 or 18, Pos = UDim2.fromOffset(math.floor(sx(rx(ty - 12) - 6) + 0.5), ty - 12 - T), Z = 5, Parent = content, OnClick = function()
			HUD.ToggleShop(false)
		end })

		-- the pages
		local function page(name)
			return make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2, Parent = content })
		end
		local shopPage = page("ShopPage")
		SH.shopPage = shopPage
		emoteTab = page("EmoteShop")
		SH.rewards = page("RewardsPage")

		-- THE SHOP PAGE: the list column scrolls (fixed rows; more below the fold)
		local listTop = phone and 88 or 128
		local listLeft = phone and 28 or 120
		local listBottom = phone and (vh - 25) or 668
		shopGrid = make("ScrollingFrame", {
			Name = "Banners",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(math.floor(sx(listLeft) + 0.5), listTop - T),
			Size = UDim2.fromOffset(phone and math.floor(vw - 42) or 744, listBottom - listTop),
			CanvasSize = UDim2.fromOffset(0, 600),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ZIndex = 2,
			Parent = shopPage,
		})
		SH.place = MN.leanScroll(shopGrid, listTop, function(y)
			return lx(y) - listLeft
		end)
		SH.bar = ST.scrollbar(shopGrid, { T = 0.3 })
		-- a block of the list: its container sits on the margin at refY; inside
		-- it things are placed in screen units (x leans by hand, as on the poster)
		local function block(name, topY, h, refY)
			local f = make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(phone and 780 or 760, h), ZIndex = 2, Parent = shopGrid })
			f:SetAttribute("CanvasY", math.floor(topY - listTop + 0.5))
			f:SetAttribute("BaseOff", refY - topY)
			local x0 = lx(refY)
			local function bx(x)
				return x - x0
			end
			local function by(y)
				return y - topY
			end
			return f, bx, by
		end
		-- a rule across the column (leaning)
		local colW = phone and math.min(560, math.floor(vw - 252)) or M.Column
		local function rule(parent, bx, by, y)
			ST.slab({ Name = "Rule", Size = { math.floor(colW + 12), 2 }, Pos = UDim2.fromOffset(math.floor(bx(lx(y) - 6) + 0.5), math.floor(by(y) + 0.5)), Color = S.Ash, T = 0.65, Ends = "None", Z = 2, Parent = parent })
		end
		-- a price button: the multiplier, the Bucks mark, the price in numerals
		local ph = phone and 30 or M.PriceH
		local function priceButton(parent, name, x, y, w, mult, price, primary)
			local b = ST.slab({ Name = name, Button = true, Size = { w, ph }, Pos = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5)), Color = primary and S.Paper or S.Ink2, T = 0, Z = 3, Parent = parent })
			local fg = primary and S.Ink or S.Paper
			local inset = math.floor(ph * lean + 8 + 0.5)
			ST.label({ Name = "Mult", Text = mult, Size = phone and 12 or 14, Color = fg, T = 0.4, Pos = UDim2.new(0, inset + 1, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 4, Parent = b })
			local num = ST.numerals(tostring(price), phone and 18 or M.Price, { Name = "Amount", Color = fg, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -inset, 0.5, 0), Z = 4, Parent = b })
			ST.keyCap("B", math.floor(ph * 0.5 + 0.5), { Name = "Mark", Ink = primary, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -(inset + num.Size.X.Offset + 6), 0.5, 0), Z = 4, Parent = b })
			b:SetAttribute("Primary", primary == true)
			b:SetAttribute("Price", price)
			table.insert(SH.prices, b)
			return b
		end
		-- a Robux price: Roblox's own icon, then the number
		local function robuxPrice(parent, price, size, right, midY, z)
			local num = ST.numerals(tostring(price), size, { Name = "Amount", Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -right, 0, midY), Z = z, Parent = parent })
			make("ImageLabel", {
				Name = "Robux",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = Config.UI.Images.Robux,
				ImageColor3 = S.Paper,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(math.floor(size * 0.8 + 0.5), math.floor(size * 0.8 + 0.5)),
				Position = UDim2.new(1, -(right + num.Size.X.Offset + 5), 0, midY),
				ZIndex = z,
				Parent = parent,
			})
			return num
		end

		-- EMOTE ROLL: the title, its sentence, the odds as a bar, a button per multiplier
		local y = phone and 112 or 182
		local tsz = phone and 26 or M.Title
		local roll, bx, by = block("RollEmotes", y - ST.metrics(tsz).Base, phone and 150 or 170, y)
		SH.roll = roll
		MN.text(roll, K.Roll, tsz, bx(lx(y)), by(y), { Name = "Title", Z = 3 })
		MN.text(roll, K.RollInfo, phone and 12 or M.Sentence, bx(lx(y) - 4), by(y + (phone and 18 or 25)), { Name = "Info", Role = "Body", T = 0.2, Z = 3 })
		local oy = y + (phone and 30 or 44)
		local ox0 = lx(oy + 8)
		local rar = ES.Rarities or {}
		local total = 0
		for _, r in rar do
			total += r.Weight or 0
		end
		local odds = make("Frame", { Name = "Odds", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(1, 1), ZIndex = 3, Parent = roll })
		local barW = phone and 220 or M.Odds
		local cx = ox0
		local lab = ox0 - 2
		for i, r in rar do
			local pct = math.floor((r.Weight or 0) / math.max(total, 1) * 100 + 0.5)
			local w = barW * pct / 100
			local shade = M.OddsShades[i] or S.Paper
			ST.slab({ Name = "Part" .. i, Size = { math.max(math.floor(w + 8 * lean + 0.5), 3), M.OddsH }, Pos = UDim2.fromOffset(math.floor(bx(cx) + 0.5), math.floor(by(oy) + 0.5)), Color = shade, T = 0, Z = 3, Parent = odds })
			cx += w + 2
			local nm = MN.text(odds, r.Name, 11, bx(lab), by(oy + 26), { Name = "Name" .. i, T = 0.4, Z = 3 })
			local lab2 = lab + ST.measure(r.Name, 11) + 4
			local pn = MN.num(odds, tostring(pct), 12, bx(lab2), by(oy + 26), { Name = "Pct" .. i, Z = 3 })
			lab = lab2 + pn.Size.X.Offset + 14
			local _ = nm
		end
		-- the buttons, stacked at the column's right end (x1 primary)
		local mults = ES.Multipliers or { 1, 2, 5, 10 }
		local pw = phone and 128 or M.PriceW
		local py0 = phone and 96 or 150
		local gap = M.PriceGap
		for i, n in mults do
			local yy = py0 + (i - 1) * (ph + gap)
			local x = lx(yy + ph) + colW - pw
			local b = priceButton(roll, "Roll" .. n, bx(x), by(yy), pw, "x" .. n, (ES.RollPrice or 25) * n, i == 1)
			b:SetAttribute("Mult", n)
			SH.rollButtons[n] = b
			b.Activated:Connect(function()
				if shopCallbacks.OnRollEmotes then
					shopCallbacks.OnRollEmotes(n)
				end
			end)
			-- (round 72) the same roll for Robux, once its product is set up: a button to its left
			local rb = ST.slab({ Name = "Robux" .. n, Button = true, Size = { phone and 84 or 104, ph }, Pos = UDim2.fromOffset(math.floor(bx(x - (phone and 88 or 108)) + 0.5), math.floor(by(yy) + 0.5)), Color = S.Ink2, T = 0, Z = 3, Visible = false, Parent = roll })
			rb:SetAttribute("Mult", n)
			SH.robuxButtons[n] = rb
			rb.Activated:Connect(function()
				if shopCallbacks.OnRobuxRoll then
					shopCallbacks.OnRobuxRoll(n)
				end
			end)
		end
		local after = py0 + #mults * (ph + gap) - gap
		local pick = ES.PickAt or 10
		local noteY = after + (phone and 12 or 14)
		MN.text(roll, string.format(K.PickNote, pick, pick), phone and 11 or 12, bx(lx(noteY) + colW - 4), by(noteY), { Name = "PickNote", AlignX = "Right", T = 0.45, Z = 3 })
		local ruleY = noteY + (phone and 8 or 12)
		rule(roll, bx, by, ruleY)
		roll.Size = UDim2.fromOffset(roll.Size.X.Offset, math.ceil(by(ruleY) + 4))

		-- the drops: one row each, one price button
		local DL = Config.Deliveries or {}
		local rowY = ruleY + (phone and 34 or 44)
		local dsz = phone and 22 or M.Row
		for _, kind in { "Soda", "Item" } do
			local spec = DL[kind] or {}
			local dy = rowY
			local f, fx, fy = block("Deliver" .. kind, dy - ST.metrics(dsz).Base - 6, phone and 40 or 52, dy)
			SH["deliver" .. kind] = f
			MN.text(f, kind == "Soda" and K.Soda or K.Item, dsz, fx(lx(dy)), fy(dy), { Name = "Title", Z = 3 })
			local tw = ST.measure(kind == "Soda" and K.Soda or K.Item, dsz)
			MN.text(f, kind == "Soda" and K.SodaInfo or K.ItemInfo, phone and 11 or M.SentenceSmall, fx(lx(dy) + tw + 14), fy(dy - 1), { Name = "Info", Role = "Body", T = 0.3, Z = 3 })
			local bw = phone and 92 or 104
			local b = priceButton(f, "Buy", fx(lx(dy + 9) + colW - bw), fy(dy - (phone and 22 or 27)), bw, "x1", spec.Price or 5, false)
			SH["deliver" .. kind .. "Price"] = b
			b.Activated:Connect(function()
				if shopCallbacks.OnDelivery then
					shopCallbacks.OnDelivery(kind)
				end
			end)
			rule(f, fx, fy, dy + (phone and 14 or 20))
			rowY += phone and 44 or 60
		end

		-- PASSES (round 98, the owner's): a tile each, the Robux icon before its price
		local GP = Config.GamePasses or {}
		local passY = rowY - (phone and 4 or 8)
		local tile = phone and { 250, 60 } or M.Tile
		local order = GP.Order or {}
		local nRows = math.ceil(#order / 2)
		local pf, pbx, pby = block("Passes", passY - 14, 18 + nRows * (tile[2] + 8), passY)
		SH.passHeader = MN.text(pf, K.Passes, 13, pbx(lx(passY)), pby(passY), { Name = "PassesTitle", T = 0.5, Z = 3 })
		SH.studio = select(2, pcall(function()
			return game:GetService("RunService"):IsStudio()
		end)) == true
		for i, key in order do
			local spec = GP[key]
			if type(spec) == "table" then
				local col, r = (i - 1) % 2, (i - 1) // 2
				local ty0 = passY + 12 + r * (tile[2] + 8)
				local tx0 = lx(ty0) + col * (tile[1] + 10)
				local b = ST.slab({ Name = "Pass_" .. key, Button = true, Size = tile, Pos = UDim2.fromOffset(math.floor(pbx(tx0 - 6) + 0.5), math.floor(pby(ty0) + 0.5)), Color = S.Ink2, T = 0, Z = 3, Parent = pf })
				local inset = tile[2] * lean
				local nsz = phone and 16 or 20
				ST.label({ Name = "Title", Text = spec.Name or key, Size = nsz, Pos = UDim2.fromOffset(math.floor(inset + 4), math.floor((phone and 22 or 30) - ST.metrics(nsz).Base)), Z = 4, Parent = b })
				local info = (M.PassInfo and M.PassInfo[key]) or spec.Info or ""
				ST.label({ Name = "Info", Text = info, Role = "Body", Size = phone and 11 or 13, T = 0.3, Pos = UDim2.fromOffset(math.floor(inset + 3), math.floor((phone and 38 or 50) - ST.metrics(phone and 11 or 13, "Body").Base)), Z = 4, Parent = b })
				local priceHolder = make("Frame", { Name = "PriceTag", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = b })
				local price = make("TextLabel", { Name = "Price", BackgroundTransparency = 1, Visible = false, Text = "", Parent = b })
				SH.passCards[key] = { Button = b, Price = price, Tag = priceHolder }
				b.Activated:Connect(function()
					if shopCallbacks.OnPass then
						shopCallbacks.OnPass(key)
					end
				end)
			end
		end
		HUD.RefreshPasses()

		-- ITEMS, by name (below the fold): the name, its line, the price
		local iy = passY + 18 + nRows * (tile[2] + 8) + (phone and 26 or 34)
		local hf, hbx, hby = block("ByName", iy - 14, 20, iy)
		MN.text(hf, K.Items, 13, hbx(lx(iy)), hby(iy), { Name = "ItemsTitle", T = 0.5, Z = 3 })
		iy += phone and 30 or 36
		local isz = phone and 18 or M.Item
		for _, id in Config.ShopOrder or Config.ItemOrder do
			local item = Config.Items[id]
			if item then
				local f, fx, fy = block(id, iy - ST.metrics(isz).Base - 4, phone and 44 or 52, iy)
				local title = string.upper(item.Name) .. ((item.Gives or 1) > 1 and (" x" .. item.Gives) or "")
				MN.text(f, title, isz, fx(lx(iy)), fy(iy), { Name = "Title", Z = 3 })
				local have = MN.text(f, "", 11, fx(lx(iy) + ST.measure(title, isz) + 10), fy(iy), { Name = "Have", Color = S.Ash, Z = 3 })
				have.Size = UDim2.fromOffset(90, have.Size.Y.Offset)
				have.Visible = false
				local info = MN.text(f, item.Info or "", phone and 11 or 13, fx(lx(iy + 18) - 1), fy(iy + 18), { Name = "Info", Role = "Body", T = 0.3, Z = 3 })
				info.TextWrapped = true
				info.TextYAlignment = Enum.TextYAlignment.Top
				info.Size = UDim2.fromOffset(math.min(phone and 400 or 420, colW - (phone and 92 or 104) - 24), math.ceil(ST.textSize(phone and 11 or 13, "Body") * 2))
				local bw = phone and 92 or 104
				local b = priceButton(f, "Buy", fx(lx(iy + 9) + colW - bw), fy(iy - (phone and 22 or 25)), bw, "x1", item.Price or 5, false)
				local hidden = make("TextLabel", { Name = "Price", BackgroundTransparency = 1, Visible = false, Text = "", Parent = f })
				cards[id] = { Button = b, Price = hidden, Have = have, Row = f }
				b.Activated:Connect(function()
					if shopCallbacks.OnBuy then
						shopCallbacks.OnBuy(id)
					end
				end)
				iy += phone and 50 or 58
			end
		end
		shopGrid.CanvasSize = UDim2.fromOffset(0, math.ceil(iy - listTop))
		SH.place()
		ST.updateScrollbar(SH.bar, shopGrid)

		-- the footer, the keeper (PC), the big wallet
		local fy0 = phone and (vh - 7) or 680
		MN.text(content, K.Footer, phone and 11 or 13, sx(lx(fy0)), fy0 - T, { Name = "Footer", T = 0.45, Z = 3 })
		if not phone then
			local k = M.Keeper
			local kx, ky, kw, kh = k[1], k[2], k[3], k[4]
			local o2 = kh * lean
			local slab = ST.slab({ Name = "KeeperSlab", Size = { math.floor(kw + o2 + 8), kh + 8 }, Pos = UDim2.fromOffset(math.floor(sx(kx - 4) + 0.5), ky - 4 - T), Color = S.Paper, T = 0, Z = 3, Parent = content })
			SH.keeperSlot = make("Frame", {
				Name = "KeeperSlot",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(math.floor(o2 * 0.5 + 4), 4),
				Size = UDim2.fromOffset(kw - 10, kh),
				ZIndex = 4,
				Parent = slab,
			})
			HUD.BuildShopkeeper()
			SH.line = ST.note(SH.lines.Greet[1], M.NoteSize, { Name = "KeeperLine", Rotation = 4, Z = 4, Parent = content })
			SH.line.Position = UDim2.fromOffset(math.floor(sx(kx - 20) + 0.5), math.floor(ky + kh + 44 - T - ST.metrics(M.NoteSize, "Note").Base + 0.5))
		end
		local wy = phone and (vh - 7) or 650
		local wr = phone and (vw - 22) or (rx(640) - 4)
		SH.wallet = MN.num(content, SH.commas(bucks), phone and 22 or M.Wallet, sx(wr), wy - T, { Name = "Wallet", AlignX = "Right", Z = 3 })
		SH.walletMark = ST.keyCap("B", phone and 16 or 28, { Name = "WalletMark", Z = 3, Parent = content })
		if not phone then
			MN.text(content, K.Bucks, 12, sx(rx(672) - 2), 676 - T, { Name = "WalletWord", AlignX = "Right", T = 0.45, Z = 3 })
		end
		SH.walletAt = { sx(wr), wy - T, phone and 16 or 28 }

		-- THE EMOTES PAGE: your wheel (a pair at a time), what you've got, the free pick
		local ey = phone and 104 or 160
		local ex = lx(ey)
		MN.text(emoteTab, K.Wheel, 13, sx(ex), ey - T, { Name = "WheelTitle", T = 0.5, Z = 3 })
		emoteSlotRow = make("Frame", { Name = "Wheel", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(700, 60), Position = UDim2.fromOffset(math.floor(sx(lx(ey + 56)) + 0.5), ey + 8 - T), ZIndex = 3, Parent = emoteTab })
		local slotsN = Config.EmoteSlots or 4
		SH.ringOn = type((Config.GamePasses or {}).EmoteSlots) == "table"
		SH.ring = SH.ring or 1
		local sw, sh = phone and math.min(66, math.floor((vw - 196) / slotsN) - 4) or 64, 54 -- ((round 100 review) a narrow phone: narrower slots, the +8 button still on screen)
		for i = 1, slotsN do
			local s = ST.slab({ Name = "Slot" .. i, Button = true, Size = { sw, sh }, Pos = UDim2.fromOffset((i - 1) * (sw + 4), 0), Color = S.Ink2, T = 0, Z = 3, Parent = emoteSlotRow })
			local num = ST.numerals(tostring(i), phone and 11 or 13, { Name = "Num", T = 0.4, Pos = UDim2.fromOffset(math.floor(sh * lean + 2), 2), Z = 4, Parent = s })
			local name = ST.label({ Name = "Label", Text = "EMPTY", Size = 11, Wrap = true, AlignY = "Bottom", LineHeight = 0.85,
				Box = UDim2.fromOffset(sw - 12, sh - 20), Pos = UDim2.fromOffset(5, 16), Z = 4, Parent = s })
			emoteSlots[i] = { Button = s, Name = name, Num = num }
			s.Activated:Connect(function()
				HUD.EmoteSlotClicked(i)
			end)
		end
		if SH.ringOn then
			SH.ringButton = ST.slab({ Name = "RingButton", Button = true, Size = { phone and 66 or 76, sh }, Pos = UDim2.fromOffset(slotsN * (sw + 4) + 6, 0), Color = S.Paper, T = 0, Z = 3, Parent = emoteSlotRow })
			ST.label({ Name = "Label", Text = "", Size = phone and 11 or 13, Color = S.Ink, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 4, Parent = SH.ringButton })
			SH.ringButton.Activated:Connect(function()
				HUD.EmoteRingClicked()
			end)
		else
			SH.ringButton = nil
		end
		-- the tools: how many, NEWEST / A-Z, a search
		local toolY = ey + (phone and 66 or 84)
		SH.tools = make("Frame", { Name = "Tools", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(600, 32), Position = UDim2.fromOffset(math.floor(sx(lx(toolY + 28)) + 0.5), toolY - T), ZIndex = 3, Parent = emoteTab })
		SH.count = ST.numerals("0/0", phone and 14 or 18, { Name = "Count", Pos = UDim2.fromOffset(0, 4), Z = 4, Parent = SH.tools })
		SH.sortNewest = SH.sortNewest ~= false
		SH.sort = ST.switch({ Name = "Sort", Labels = { K.Newest, K.AZ }, On = SH.sortNewest, Size = { phone and 110 or 132, 28 }, Pos = UDim2.fromOffset(phone and 70 or 90, 2), Z = 4, Parent = SH.tools,
			OnChange = function(on)
				SH.sortNewest = on
				HUD.RefreshEmoteShop()
			end })
		local searchSlab = ST.slab({ Name = "SearchSlab", Size = { phone and 200 or 260, 28 }, Pos = UDim2.fromOffset(phone and 196 or 240, 2), Color = S.Ink2, T = 0, Z = 4, Parent = SH.tools })
		SH.search = make("TextBox", {
			Name = "Search",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = ST.font("Display"),
			TextSize = ST.textSize(phone and 13 or 15),
			TextColor3 = S.Paper,
			PlaceholderText = K.Search,
			PlaceholderColor3 = S.Ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Position = UDim2.fromOffset(math.floor(28 * lean + 8), 0),
			Size = UDim2.new(1, -math.floor(28 * lean * 2 + 12), 1, 0),
			ZIndex = 5,
			Parent = searchSlab,
		})
		SH.search:GetPropertyChangedSignal("Text"):Connect(function()
			HUD.RefreshEmoteShop()
		end)
		-- the free pick (a 10x roll's tenth, PICK LATER)
		local listY = toolY + (phone and 38 or 46)
		SH.pickButton = ST.button({ Name = "FreePick", Kind = "Primary", Text = K.Free, Size = { phone and 220 or 260, 32 }, TextSize = 16, Pos = UDim2.fromOffset(math.floor(sx(lx(listY + 32)) + 0.5), listY - T), Z = 4, Parent = emoteTab,
			OnClick = function()
				HUD.ShowEmotePick(true)
			end })
		SH.pickButton.Visible = false
		SH.listY = listY
		-- the list: your emotes, one leaning row each
		local gridTop = listY
		emoteGrid = make("ScrollingFrame", {
			Name = "Emotes",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(math.floor(sx(listLeft) + 0.5), gridTop - T),
			Size = UDim2.fromOffset(phone and math.floor(vw - 52) or 650, listBottom - gridTop - (phone and 0 or 16)),
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ZIndex = 3,
			Parent = emoteTab,
		})
		SH.gridTop = gridTop
		SH.placeEmotes = MN.leanScroll(emoteGrid, gridTop, function(yy)
			return lx(yy) - listLeft
		end)
		SH.emoteBar = ST.scrollbar(emoteGrid, { T = 0.3 })
		SH.empty = MN.text(emoteTab, K.NoneYet, phone and 12 or 15, sx(lx(listY + 24)), listY + 24 - T, { Name = "NoneYet", Role = "Body", T = 0.3, Z = 3 })
		local rh = phone and 32 or 36
		SH.rowH = rh
		for order, e in Config.Emotes or {} do
			local row = ST.slab({ Name = "EmoteShop_" .. e.Id, Button = true, Size = { phone and 520 or 480, rh - 4 }, Color = S.Ink2, T = 0, Z = 3, Visible = false, Parent = emoteGrid })
			row:SetAttribute("Order", order)
			local inset = math.floor((rh - 4) * lean + 10)
			ST.label({ Name = "RowName", Text = string.upper(e.Name or e.Id), Size = phone and 15 or 18, Pos = UDim2.new(0, inset, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 4, Parent = row })
			local rarity = HUD.EmoteRarity(e)
			ST.label({ Name = "Rarity", Text = rarity.Name, Size = 11, Color = S.Ash, Pos = UDim2.new(0, phone and 250 or 240, 0.5, 1), Anchor = Vector2.new(0, 0.5), Z = 4, Parent = row })
			local pillSlab = ST.slab({ Name = "PillSlab", Size = { phone and 86 or 104, rh - 12 }, Pos = UDim2.new(1, -(phone and 96 or 116), 0.5, 0), Anchor = Vector2.new(0, 0.5), Color = S.Ink, T = 0, Z = 4, Parent = row })
			local pillLabel = ST.label({ Name = "Pill", Text = "", Size = phone and 11 or 13, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 5, Parent = pillSlab })
			emoteCards[e.Id] = { Button = row, Pill = pillLabel, PillSlab = pillSlab }
			row.Activated:Connect(function()
				HUD.EmoteCardClicked(e.Id)
			end)
		end

		-- THE CODES PAGE: a box, REDEEM, what it gave
		local cy = phone and 112 or 182
		MN.text(SH.rewards, K.CodeInfo, phone and 12 or M.Sentence, sx(lx(cy)), cy - T, { Name = "Info", Role = "Body", T = 0.2, Z = 3 })
		local boxY = cy + (phone and 16 or 24)
		local box = ST.slab({ Name = "CodeSlab", Size = { phone and 300 or 380, phone and 40 or 48 }, Pos = UDim2.fromOffset(math.floor(sx(lx(boxY + 48)) + 0.5), boxY - T), Color = S.Ink2, T = 0, Z = 3, Parent = SH.rewards })
		SH.codeBox = make("TextBox", {
			Name = "Code",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = ST.font("Display"),
			TextSize = ST.textSize(phone and 18 or 22),
			TextColor3 = S.Paper,
			PlaceholderText = K.Code,
			PlaceholderColor3 = S.Ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Position = UDim2.fromOffset(math.floor(48 * lean + 10), 0),
			Size = UDim2.new(1, -math.floor(48 * lean * 2 + 16), 1, 0),
			ZIndex = 4,
			Parent = box,
		})
		SH.redeem = ST.button({ Name = "Redeem", Kind = "Primary", Text = K.Redeem, Size = { phone and 120 or 150, phone and 40 or 48 }, TextSize = phone and 18 or 22,
			Pos = UDim2.fromOffset(box.Position.X.Offset + box.Size.X.Offset + 8, boxY - T), Z = 3, Parent = SH.rewards,
			OnClick = function()
				local code = SH.codeBox.Text:gsub("%s", "")
				if code ~= "" and shopCallbacks.OnRedeem then
					shopCallbacks.OnRedeem(code)
				end
			end })
		SH.codeResult = MN.text(SH.rewards, "", phone and 12 or M.Sentence, sx(lx(boxY + 80)), boxY + 80 - T, { Name = "Result", Role = "Body", Z = 3 })

		HUD.SetEmotePicks(SH.picks or 0)
		HUD.RefreshShopPrices()
		HUD.ShopTab(SH.tab or "Shop")
		if was then
			MN.reopen(shopPanel)
		end
	end

	-- THE SHOPKEEPER (his ViewportFrame on a paper slab): sat at his desk in a
	-- U.A. tracksuit and cap, an All Might plushie beside him and the till.
	-- Poke him and he'll let you know about it. (A phone: he isn't there.)
	function HUD.BuildShopkeeper()
		if SH.keeper or not SH.keeperSlot then
			return
		end
		local vp = make("ViewportFrame", {
			Name = "Shopkeeper",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Config.UI.Street.Paper,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(165, 165, 176),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-0.6, -1, 0.5),
			ZIndex = 4,
			Parent = SH.keeperSlot,
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
			ZIndex = 5,
			Parent = vp,
		})
		poke.Activated:Connect(function()
			HUD.PokeShopkeeper()
		end)
	end

	-- a word from the shopkeeper (a table of lines: one of them), his one marker
	-- line under his slab; it goes back to his first greeting after a while
	function HUD.ShopkeeperSay(text, time)
		if not SH.line then
			return
		end
		if type(text) == "table" then
			text = text[math.random(1, #text)]
		end
		SH.sayToken = (SH.sayToken or 0) + 1
		local token = SH.sayToken
		local ST = HUD.ST
		local size = Config.UI.Menus.Shop.NoteSize
		text = tostring(text or "")
		-- (his own lines as written - HEY. is shouted; anything else in his hand, lowercase)
		local his = false
		for _, v in Config.UI.Menus.Keeper do
			if v == text or (type(v) == "table" and table.find(v, text)) then
				his = true
			end
		end
		if not his then
			text = string.lower(text)
		end
		SH.line.Text = text
		SH.line.Size = UDim2.fromOffset(math.ceil(ST.measure(text, size, "Note")) + 4, math.ceil(ST.textSize(size, "Note")))
		SH.line.Visible = true
		task.delay(time or 3, function()
			if SH.sayToken == token and SH.line then
				SH.line.Text = SH.lines.Greet[1]
				SH.line.Size = UDim2.fromOffset(math.ceil(ST.measure(SH.line.Text, size, "Note")) + 4, math.ceil(ST.textSize(size, "Note")))
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
				tween(p, 0.25, { CFrame = R[k] })
			end
		end)
	end

	-- the prices you can pay at full strength, the rest dimmed; the Robux rolls
	-- that are set up; the big wallet
	function HUD.RefreshShopPrices()
		if not SH.roll then
			return
		end
		local ST = HUD.ST
		local S = Config.UI.Street
		local ES = Config.EmoteShop or {}
		for _, b in SH.prices or {} do
			if b.Parent then
				local can = bucks >= (b:GetAttribute("Price") or 0)
				local primary = b:GetAttribute("Primary")
				local fg = primary and S.Ink or S.Paper
				local amount = b:FindFirstChild("Amount")
				if amount then
					amount:SetAttribute("NumT", can and 0 or 0.55)
					amount:SetAttribute("NumColor", fg)
					ST.setNumerals(amount, amount:GetAttribute("NumText") or "")
				end
				b:SetAttribute("CanPay", can)
			end
		end
		-- (round 72) the same rolls for Robux, the ones set up
		for n, rb in SH.robuxButtons or {} do
			local spec = (ES.Robux or {})[n]
			local id = type(spec) == "table" and tonumber(spec.Product) or 0
			local rp = (SH.robuxPrices or {})[n] or (type(spec) == "table" and spec.Price) or nil
			rb.Visible = id > 0
			if rb.Visible and rb:GetAttribute("Shows") ~= tostring(rp) then
				rb:SetAttribute("Shows", tostring(rp))
				for _, c in rb:GetChildren() do
					if c.Name == "Amount" or c.Name == "Robux" then
						c:Destroy()
					end
				end
				local h = rb.Size.Y.Offset
				local num = ST.numerals(tostring(rp or "?"), SH.phone and 16 or 19, { Name = "Amount", Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -math.floor(h * ST.lean() + 8), 0.5, 0), Z = 4, Parent = rb })
				make("ImageLabel", {
					Name = "Robux",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = Config.UI.Images.Robux,
					ImageColor3 = S.Paper,
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(15, 15),
					Position = UDim2.new(1, -(math.floor(h * ST.lean() + 8) + num.Size.X.Offset + 5), 0.5, 0),
					ZIndex = 4,
					Parent = rb,
				})
			end
			rb:SetAttribute("Price", rp)
		end
		-- the big wallet: the number, the B mark before it
		if SH.wallet and SH.wallet.Parent then
			ST.setNumerals(SH.wallet, SH.commas(bucks))
			local at = SH.walletAt
			if SH.walletMark and at then
				SH.walletMark.Position = UDim2.fromOffset(math.floor(at[1] - SH.wallet.Size.X.Offset - at[3] - 8 + 0.5), math.floor(SH.wallet.Position.Y.Offset + SH.wallet.Size.Y.Offset * 0.62 - at[3] * 0.5 + 0.5))
			end
		end
	end

	-- (round 72) what Roblox says each Robux roll really costs ([n] = price)
	function HUD.SetRobuxPrices(prices)
		SH.robuxPrices = type(prices) == "table" and prices or {}
		HUD.RefreshShopPrices()
	end

	-- a purchase went through (its button flashes paper; he says so) or didn't
	-- (a toast says why; he says no)
	function HUD.ShopResult(ok, itemId, text)
		local card = itemId and (cards[itemId] or emoteCards[itemId])
		local button = card and card.Button or nil
		if itemId == "Soda" and not button then
			button = SH.deliverSodaPrice
		elseif itemId == "DeliverSoda" then
			button = SH.deliverSodaPrice
		elseif itemId == "DeliverItem" or itemId == "Delivery" then
			button = SH.deliverItemPrice
		elseif itemId == "Roll" then
			button = SH.rollButtons and SH.rollButtons[1]
		end
		if button and button.Parent and ok and button:GetAttribute("StSlab") then
			HUD.ST.flash(button)
		end
		if not ok and text then
			HUD.Notice(text, Color3.fromRGB(255, 130, 110))
			HUD.ShopkeeperSay(SH.lines.No, 2.6)
		elseif ok then
			if text and HUD.ShopVisible() then
				HUD.ST.toast(text, "SHOP")
			end
			HUD.ShopkeeperSay(SH.lines.Thanks, 2)
		end
	end

	-- the shop's three tabs ("Items" is the SHOP tab too): instant swap, your
	-- slash under the open one (it paints itself in)
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
		local ST = HUD.ST
		SH.tab = which
		SH.shopPage.Visible = which == "Shop"
		emoteTab.Visible = which == "Emotes"
		SH.rewards.Visible = which == "Rewards"
		for name, tb in tabButtons do
			tb.Label.TextTransparency = name == which and 0 or 0.6
		end
		if SH.tabSlash then
			SH.tabSlash:Destroy()
		end
		local b = tabButtons[which]
		local w = b:GetAttribute("Word") or 60
		local h = SH.phone and 14 or 18
		SH.tabSlash = ST.slash({
			Name = "TabSlash", Size = { math.floor(w + 24), h }, Color = SH.heroColor(), Value = 0, Rotation = -2, Z = 3,
			Pos = UDim2.fromOffset(b.Position.X.Offset - 6, b.Position.Y.Offset + math.floor(ST.metrics(SH.phone and 22 or 30).Base + 6 - h / 2 + 0.5)),
			Parent = SH.tabsFrame,
		})
		ST.setSlash(SH.tabSlash, 1, Config.UI.Street.Motion.SlashPaint)
		pickedSlot = nil
		HUD.RefreshEmoteShop()
		HUD.RefreshShopPrices()
	end

	function HUD.ShopTabShown()
		return SH.tab == "Emotes" and "Emotes" or SH.tab == "Rewards" and "Rewards" or "Items"
	end

	-- straight to your emotes (an empty slot on the wheel, MORE IN THE SHOP)
	function HUD.OpenEmoteShop()
		HUD.ShowMenu(false)
		HUD.ToggleShop(true)
		HUD.ShopTab("Emotes")
	end

	-- (round 98) the GAME PASSES tiles: state = { [key] = { Owned, Given,
	-- Price } } (the price: Roblox's, once the screen has asked). Owned: OWNED;
	-- one not set up (no Id) shows in Studio only, marked, so it can be seen
	-- before it's on sale
	function HUD.RefreshPasses(state)
		SH.passState = state or SH.passState or {}
		local ST = HUD.ST
		local S = Config.UI.Street
		local K = Config.UI.Menus.Shop.Copy
		local any = false
		for key, card in SH.passCards or {} do
			local spec = (Config.GamePasses or {})[key] or {}
			local st = SH.passState[key] or {}
			local setUp = (tonumber(spec.Id) or 0) > 0
			local free = not setUp and spec.FreeUntilSetUp == true
			local show = setUp or SH.studio or (st.Owned == true and not free)
			card.Button.Visible = show
			any = any or show
			local tag = card.Tag
			for _, c in tag:GetChildren() do
				c:Destroy()
			end
			local h = card.Button.Size.Y.Offset
			local right = math.floor(22 + (h - 64) * ST.lean())
			local midY = math.floor(h - 14)
			if st.Owned and not free then
				card.Price.Text = st.Given and K.Gifted or K.Owned
				ST.label({ Name = "State", Text = card.Price.Text, Size = 15, Color = S.Ash, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -right, 0, midY), Z = 5, Parent = tag })
			elseif not setUp then
				card.Price.Text = free and K.FreeNoId or K.NoId
				ST.label({ Name = "State", Text = card.Price.Text, Size = 13, Color = S.Ash, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -right, 0, midY), Z = 5, Parent = tag })
			else
				local price = tostring(st.Price or spec.Price or "?")
				card.Price.Text = "R$ " .. price
				local num = ST.numerals(price, SH.phone and 15 or 17, { Name = "Amount", Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -right, 0, midY), Z = 5, Parent = tag })
				make("ImageLabel", {
					Name = "Robux",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = Config.UI.Images.Robux,
					ImageColor3 = S.Paper,
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(1, -(right + num.Size.X.Offset + 5), 0, midY),
					ZIndex = 5,
					Parent = tag,
				})
			end
		end
		if SH.passHeader then
			SH.passHeader.Visible = any
		end
	end

	-- owned: { [Id] = true }; wheel: the Id in each slot ("" = empty);
	-- order: the ones owned, oldest first (as they were got)
	function HUD.SetEmotes(owned, wheel, order)
		ownedEmotes = owned or {}
		wheelEmotes = wheel or {}
		SH.order = order or SH.order or {}
		-- (round 98) more than the wheel's own slots: the EMOTE SLOTS pass's ring
		SH.hasRing = #wheelEmotes > (Config.EmoteSlots or 4)
		if not SH.hasRing then
			SH.ring = 1
		end
		HUD.RefreshEmoteShop()
	end

	-- (round 98) the tiles' first slot: 0, or - showing the second ring - the
	-- wheel's own count
	function HUD.EmoteRingBase()
		return (SH.ring == 2 and SH.hasRing) and (Config.EmoteSlots or 4) or 0
	end
	-- the button at the end of the row: the other ring, or the pass
	function HUD.EmoteRingClicked()
		if SH.hasRing then
			SH.ring = SH.ring == 2 and 1 or 2
			pickedSlot = nil
			HUD.RefreshEmoteShop()
		elseif shopCallbacks.OnPass then
			shopCallbacks.OnPass("EmoteSlots")
		end
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
		local ST = HUD.ST
		local S = Config.UI.Street
		local K = Config.UI.Menus.Shop.Copy
		local base = HUD.EmoteRingBase() -- (round 98: on the second ring, its slots)
		for i, s in emoteSlots do
			local k = base + i
			local e = emoteOf(wheelEmotes[k])
			local picked = pickedSlot == k
			s.Name.Text = e and string.upper(e.Name or e.Id) or "EMPTY"
			ST.paint(s.Button, picked and S.Paper or S.Ink2, 0)
			s.Name.TextColor3 = picked and S.Ink or S.Paper
			s.Name.TextTransparency = e and 0 or 0.55
			s.Button:SetAttribute("Picked", picked)
			if s.Num then
				s.Num:SetAttribute("NumColor", picked and S.Ink or S.Paper)
				ST.setNumerals(s.Num, tostring(k))
			end
		end
		if SH.ringButton then
			local extra = ((Config.GamePasses or {}).EmoteSlots or {}).Extra or 8
			local lab = SH.ringButton:FindFirstChild("Label")
			if lab then
				lab.Text = SH.hasRing and (SH.ring == 2 and K.Ring1 or K.Ring2) or string.format(K.MoreSlots, extra)
			end
			ST.paint(SH.ringButton, SH.hasRing and S.Ink2 or S.Paper, 0)
			if lab then
				lab.TextColor3 = SH.hasRing and S.Paper or S.Ink
			end
		end
		-- newest first (as got), or A-Z; the search filters by name
		local rank = {}
		for i, id in SH.order or {} do
			rank[id] = i
		end
		local query = SH.search and string.lower(SH.search.Text) or ""
		local shown = {}
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
			if card.Button.Visible then
				table.insert(shown, id)
			end
			local at = table.find(wheelEmotes, id)
			if at then
				card.Pill.Text = string.format(K.OnWheel, at)
				ST.paint(card.PillSlab, S.Paper, 0)
				card.Pill.TextColor3 = S.Ink
			else
				card.Pill.Text = pickedSlot and string.format(K.PutIn, pickedSlot) or K.Equip
				ST.paint(card.PillSlab, S.Ink, 0)
				card.Pill.TextColor3 = S.Paper
			end
		end
		table.sort(shown, function(a, b)
			if SH.sortNewest then
				return (rank[a] or 0) > (rank[b] or 0)
			end
			local ea, eb = emoteOf(a), emoteOf(b)
			return (ea.Name or a) < (eb.Name or b)
		end)
		local rh = SH.rowH or 36
		for i, id in shown do
			local row = emoteCards[id].Button
			row.LayoutOrder = i
			row:SetAttribute("CanvasY", (i - 1) * rh)
			row:SetAttribute("BaseOff", rh / 2)
		end
		if emoteGrid then
			emoteGrid.CanvasSize = UDim2.fromOffset(0, #shown * rh + 8)
			if SH.placeEmotes then
				SH.placeEmotes()
			end
			if SH.emoteBar then
				ST.updateScrollbar(SH.emoteBar, emoteGrid)
			end
		end
		if SH.count then
			ST.setNumerals(SH.count, have .. "/" .. total)
			SH.sort:SetAttribute("On", SH.sortNewest)
			ST.setSwitch(SH.sort, SH.sortNewest)
			SH.empty.Visible = have == 0
		end
	end

	-- a slot: pick it (the next emote you tap goes there); tap it again to
	-- empty it
	function HUD.EmoteSlotClicked(i)
		i = HUD.EmoteRingBase() + i -- (round 98: a tile of the second ring is its slot)
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
	-- from the rolls on the SHOP tab.)
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
			HUD.Notice(Config.UI.Menus.Shop.Copy.Full, Color3.fromRGB(255, 212, 64))
			return
		end
		pickedSlot = nil
		if shopCallbacks.OnEquipEmote then
			shopCallbacks.OnEquipEmote(slot, id)
		end
		HUD.RefreshEmoteShop()
	end

	-- free picks waiting (a 10x roll's tenth, "LATER")
	function HUD.SetEmotePicks(n)
		SH.picks = n or 0
		if SH.pickButton then
			local K = Config.UI.Menus.Shop.Copy
			SH.pickButton.Visible = SH.picks > 0
			local lab = SH.pickButton:FindFirstChild("Label")
			if lab then
				lab.Text = K.Free .. (SH.picks > 1 and ("  x" .. SH.picks) or "")
				lab.Size = UDim2.fromOffset(math.ceil(HUD.ST.measure(lab.Text, 16)) + 2, lab.Size.Y.Offset)
			end
			if emoteGrid and SH.gridTop then
				local down = SH.picks > 0 and 40 or 0
				emoteGrid.Position = UDim2.fromOffset(emoteGrid.Position.X.Offset, SH.gridTop + down - shopPanel:GetAttribute("Top"))
			end
		end
	end

	-- a code: it worked (what it gave) or didn't (why)
	function HUD.CodeResult(ok, text)
		if SH.codeResult then
			SH.codeResult.Text = text or (ok and "Redeemed." or "That code doesn't work.")
			SH.codeResult.Size = UDim2.fromOffset(math.ceil(HUD.ST.measure(SH.codeResult.Text, SH.phone and 12 or 15, "Body")) + 4, SH.codeResult.Size.Y.Offset)
			SH.codeResult.TextTransparency = ok and 0 or 0.25
			if ok then
				SH.codeBox.Text = ""
			end
		end
		HUD.ShopkeeperSay(ok and SH.lines.CodeOk or SH.lines.CodeNo, 2)
	end

	-- THE ROLL: the cards you got, face down, turned over one after another (a
	-- snap: the face is there, a paper flash); a legendary gets your slash and
	-- shakes the row. Then, for a 10x roll, the tenth is yours to pick (or LATER).
	function SH.cardLook(face, rarity)
		-- the brighter the rarer: legendary paper, epic ash, rare raised ink, common ink
		local S = Config.UI.Street
		local w = rarity and (rarity.Weight or 100) or 100
		if w <= 5 then
			return S.Paper, S.Ink
		elseif w <= 15 then
			return S.Ash, S.Ink
		elseif w <= 30 then
			return S.Ink2, S.Paper
		end
		return S.Ink, S.Paper
	end
	function HUD.BuildEmoteReveal()
		if SH.reveal then
			return
		end
		local ST = HUD.ST
		local S = Config.UI.Street
		local K = Config.UI.Menus.Shop.Copy
		SH.reveal = make("Frame", {
			Name = "EmoteReveal",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = S.Ink,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 80,
			Parent = gui,
		})
		local root = ST.rootOf(SH.reveal)
		SH.revealTitle = ST.label({ Name = "Title", Text = K.Got, Size = 40, AlignX = "Center", Box = UDim2.fromOffset(800, 60), Anchor = Vector2.new(0.5, 0), Pos = UDim2.new(0.5, 0, 0, 92), Z = 81, Parent = root })
		SH.revealRow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(5 * 138, 2 * 184),
			BackgroundTransparency = 1,
			ZIndex = 81,
			Parent = root,
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
		-- (round 72) it goes by itself a moment after the last card's turned
		-- over (the line under NICE runs down); NICE closes it straight away;
		-- a click anywhere else turns the rest of the cards over at once
		SH.revealSkip = make("TextButton", {
			Name = "Skip",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 80,
			Parent = SH.reveal,
		})
		SH.revealOk = ST.button({ Name = "Nice", Kind = "Primary", Text = K.Nice, Size = { 180, 46 }, TextSize = 24, Anchor = Vector2.new(0.5, 1), Pos = UDim2.new(0.5, 0, 1, -64), Z = 82, Parent = root })
		SH.revealOk.Visible = false
		SH.revealBar = make("Frame", {
			Name = "Timer",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 1, 4),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = S.Paper,
			BorderSizePixel = 0,
			ZIndex = 83,
			Parent = SH.revealOk,
		})
		SH.revealOk.Activated:Connect(function()
			HUD.CloseEmoteReveal()
		end)
		SH.revealSkip.Activated:Connect(function()
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
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 85,
			Parent = gui,
		})
		local proot = ST.rootOf(SH.pick)
		local card = ST.slab({ Name = "Card", Size = { 420, 470 }, Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(0.5, 0.5), Color = S.Ink, T = S.MenuT, Z = 85, Parent = proot })
		local lean = ST.lean()
		HUD.Menus.text(card, K.PickTitle, 30, 470 * lean - 30 + 28, 50, { Name = "Title", Z = 86 })
		HUD.Menus.text(card, K.PickInfo, 14, 470 * lean - 30 + 26, 74, { Name = "Info", Role = "Body", T = 0.2, Z = 86 })
		local searchSlab = ST.slab({ Name = "SearchSlab", Size = { 330, 36 }, Pos = UDim2.fromOffset(math.floor(470 * lean - 40 + 20), 88), Color = S.Ink2, T = 0, Z = 86, Parent = card })
		SH.pickSearch = make("TextBox", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = ST.font("Display"),
			TextSize = ST.textSize(16),
			TextColor3 = S.Paper,
			PlaceholderText = K.Search,
			PlaceholderColor3 = S.Ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Position = UDim2.fromOffset(math.floor(36 * lean + 8), 0),
			Size = UDim2.new(1, -math.floor(36 * lean * 2 + 12), 1, 0),
			ZIndex = 87,
			Parent = searchSlab,
		})
		SH.pickList = make("ScrollingFrame", {
			Position = UDim2.fromOffset(math.floor(470 * lean - 60), 134),
			Size = UDim2.fromOffset(340, 270),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 86,
			Parent = card,
		}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		SH.pickRows = {}
		for order, e in Config.Emotes or {} do
			if not e.Exclusive then
				local row = make("TextButton", {
					Name = "Pick_" .. e.Id,
					LayoutOrder = order,
					Size = UDim2.fromOffset(330, 30),
					BackgroundColor3 = S.Ink2,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					FontFace = ST.font("Display"),
					TextSize = ST.textSize(16),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = S.Paper,
					Text = "  " .. string.upper(e.Name or e.Id),
					ZIndex = 87,
					Parent = SH.pickList,
				})
				SH.pickRows[e.Id] = row
				row.Activated:Connect(function()
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
		ST.button({ Name = "PickLater", Kind = "Secondary", Text = K.Later, Size = { 140, 40 }, TextSize = 19, Anchor = Vector2.new(1, 1), Pos = UDim2.new(1, -24, 1, -16), Z = 87, Parent = card,
			OnClick = function()
				HUD.ShowEmotePick(false)
			end })
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
		local ST = HUD.ST
		local S = Config.UI.Street
		local K = Config.UI.Menus.Shop.Copy
		for _, c in SH.revealRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		SH.reveal.Visible = true
		SH.revealOk.Visible = true -- (round 72: there from the start - close it whenever)
		SH.revealBar.Size = UDim2.new(1, 0, 0, 3)
		SH.pickAfter = (pick or 0) > 0 or nil
		ST.setText(SH.revealTitle, K.Got)
		local sc = SH.revealRow:FindFirstChildOfClass("UIScale")
		sc.Scale = #got > 5 and 0.92 or 1.15
		local best
		local flips = {}
		for i, id in got do
			local e = emoteOf(id) or { Id = id, Name = id }
			local r = HUD.EmoteRarity(e)
			local cell = make("Frame", { Name = "Card" .. i, LayoutOrder = i, BackgroundTransparency = 1, ZIndex = 81, Parent = SH.revealRow })
			local card = make("Frame", { Name = "Face", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 82, Parent = cell })
			local slab = ST.slab({ Name = "Slab", Size = { 128, 174 }, Color = S.Ink2, T = 0, Z = 82, Parent = card })
			local q = ST.label({ Name = "Back", Text = "?", Size = 64, Color = S.Ash, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 83, Parent = card })
			local nsize = 20
			while ST.measure(string.upper(e.Name or id), nsize) > 84 and nsize > 14 do
				nsize -= 1
			end
			local name = ST.label({ Name = "EmoteName", Text = string.upper(e.Name or id), Size = nsize, Wrap = true, AlignX = "Center", Box = UDim2.fromOffset(88, 70), Anchor = Vector2.new(0.5, 0), Pos = UDim2.new(0.5, 0, 0, 40), Z = 83, Visible = false, Parent = card })
			local tag = ST.label({ Name = "Rarity", Text = r.Name, Size = 12, AlignX = "Center", Box = UDim2.fromOffset(110, 20), Anchor = Vector2.new(0.5, 1), Pos = UDim2.new(0.5, 0, 1, -14), Z = 83, Visible = false, Parent = card })
			if not best or (r.Weight or 100) < (best.Weight or 100) then
				best = r
			end
			-- turn it over: a snap (the face is there at once), a paper flash
			local flipped = false
			local function flip(quiet)
				if flipped or not card.Parent then
					return
				end
				flipped = true
				local bg, fg = SH.cardLook(card, r)
				ST.paint(slab, bg, 0)
				q.Visible = false
				name.TextColor3, tag.TextColor3 = fg, fg
				tag.TextTransparency = 0.35
				name.Visible, tag.Visible = true, true
				ST.flash(slab, 0.08)
				HUD.RevealBurst(cell, r, (r.Weight or 100) <= 5)
				if shopCallbacks.OnSound and not quiet then
					shopCallbacks.OnSound((r.Weight or 100) <= 5 and "RankUp" or "Purchase")
				end
			end
			table.insert(flips, flip)
			task.delay(0.2 + (i - 1) * 0.12, flip)
		end
		-- all face up: the title, the keeper - and a moment later it goes by
		-- itself (the line under NICE runs down), or on to the free pick
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
				ST.setText(SH.revealTitle, best.Name)
				HUD.ShopkeeperSay(SH.lines.Legend, 3)
			else
				HUD.ShopkeeperSay(SH.lines.Roll, 2.5)
			end
			local ES = Config.EmoteShop or {}
			local stay = (ES.RevealStay or 1.8) + (#got > 5 and 1 or 0)
			SH.revealBar.Size = UDim2.new(1, 0, 0, 3)
			tween(SH.revealBar, stay, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
			task.delay(stay, function()
				if SH.revealToken == token then
					HUD.CloseEmoteReveal()
				end
			end)
		end
		SH.revealDone = allUp
		task.delay(0.2 + #got * 0.12 + 0.2, allUp)
	end

	-- a legendary turning over: your slash behind the card, the row shakes
	-- (the rest: just the flash)
	function HUD.RevealBurst(cell, rarity, big)
		if not big then
			return
		end
		pcall(function()
			local s = HUD.ST.slash({ Name = "Burst", Size = { 190, 70 }, Color = SH.heroColor(), Value = 0, Rotation = -8, Z = 81, Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromScale(0.5, 0.62), Parent = cell })
			HUD.ST.setSlash(s, 1, 0.12)
		end)
		if SH.revealRow then
			-- ((round 100 review) its home, not where it is: a second legendary
			-- mid-shake would take the shaken spot as home and leave the row off)
			local base = UDim2.fromScale(0.5, 0.5)
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

	-- up / away (nil: the other); one full menu at a time; he greets you
	function HUD.ToggleShop(force)
		if not shopPanel then
			return false
		end
		local ST = HUD.ST
		local was = ST.panelOpen(shopPanel)
		local open = force
		if open == nil then
			open = not was
		end
		if open and not was then
			HUD.Menus.opened("Shop")
			HUD.HideVendor()
			ST.openPanel(shopPanel)
			HUD.ShopTab("Shop") -- (the SHOP tab / H: the shop's own page; OpenEmoteShop turns to EMOTES after)
			HUD.ShopkeeperSay(SH.lines.Greet, 3)
			HUD.RefreshShopPrices()
		elseif not open and was then
			ST.closePanel(shopPanel)
			HUD.ShowEmotePick(false)
			HUD.Menus.closed("Shop")
		elseif not open then
			HUD.ShowEmotePick(false)
		end
		if shopCallbacks.OnToggle then
			shopCallbacks.OnToggle(open)
		end
		return open
	end
	HUD.Menus.closers.Shop = function()
		HUD.ToggleShop(false)
	end

	function HUD.ShopVisible()
		return shopPanel ~= nil and HUD.ST.panelOpen(shopPanel)
	end

	-- where a controller's selection starts when a panel opens
	function HUD.FirstButton(which)
		if which == "Shop" then
			-- the page you're on: your first emote (or the first slot), the
			-- code box, or the x1 roll
			if emoteTab and emoteTab.Visible then
				local best, bo = nil, math.huge
				for _, c in emoteCards do
					if c.Button.Visible and c.Button.LayoutOrder < bo then
						best, bo = c.Button, c.Button.LayoutOrder
					end
				end
				return best or (emoteSlots[1] and emoteSlots[1].Button or nil)
			elseif SH.rewards and SH.rewards.Visible then
				return SH.redeem
			end
			return SH.rollButtons and SH.rollButtons[(Config.EmoteShop and Config.EmoteShop.Multipliers or { 1 })[1]] or nil
		elseif which == "Vendor" then
			return HUD.VendorFirstButton()
		end
		local PK = HUD.Picker
		local first = PK and PK.first and PK.first()
		return first and PK.rows[first] or nil
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
		-- ((round 100) the key letters on the slots: numerals; a pad's arrows
		-- said as words - Oswald has no arrows)
		for i = 1, 6 do
			local slot = slots[i]
			if slot then
				HUD.FH.setKey(slot, keys[i])
			end
		end
		keyText.Guard = pad and HUD.PadGlyph(C.BlockKeys) or "F"
		keyText.Ult = pad and HUD.PadGlyph(C.UltKeys) or "G"
		keyText.Dash = pad and HUD.PadGlyph(C.DashKeys) or mode == "Touch" and "DASH" or "Q"
		-- a controller gets the button legend (left side); the keys are on the
		-- slots, so there's no hint line along the bottom any more (round 100, audit #16)
		HUD.ShowPadLegend(pad)
		if shopButton then
			shopButton.Text = pad and "SHOP [SELECT]" or mode == "Touch" and "SHOP" or "SHOP [H]"
			shopHint.Text = pad and "A: buy   ·   B: close   ·   every KO pays " .. ((Config.Economy and Config.Economy.PerKO) or 5) .. " " .. currency()
				or "Every KO pays " .. ((Config.Economy and Config.Economy.PerKO) or 5) .. " " .. currency() .. "  ·  poke the shopkeeper, he loves it"
		end
		-- (the full ult's key cap, the evade's escape key)
		HUD.FH.drawUlt(false)
		HUD.FH.drawEvade()
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
-- (round 100) THE EMOTE PICKER (B; Stark Street, mockup 06): two leaning
-- columns of four slabs either side of you, so you stay in view - 1-4 down
-- the right, 5-8 up the left (the old ring's order, clockwise from the top);
-- the +8 SLOTS pass adds a second pair of columns further out. Point at one
-- (the mouse: the slot nearest in angle from you, a 3 px pointer runs to it)
-- and let go of B, or click / tap it, or press its number (1-8); the right
-- stick picks by direction (up 1, right 3, down 5, left 7; pushed to the
-- edge, the outer pair). It covers the screen with a button that frees the
-- mouse from shift lock while it's up and takes any click that misses (that
-- closes it - it never throws a punch). It sits under the combat HUD (the
-- HUD stays in view). Empty slots aren't drawn; MORE IN THE SHOP opens the
-- shop's emotes. The hint sits under you, for the first few opens only.
---------------------------------------------------------------------------
do
	local wheel, pickFn, watch
	local buttons = {}
	local hover = nil
	local layout = { inner = 0, outer = 0 }
	local EW = { opens = 0 }
	HUD.EmotePicker = EW -- (tests and the renderer can read it)

	local function E()
		return Config.UI.Menus.Emotes
	end
	-- where slot i goes (its slab's top-left, from the centre), its side, its pair
	local function slotPlace(i, L)
		local ST = HUD.ST
		local outer = i > 8
		local k = outer and i - 8 or i
		local side = k <= 4 and 1 or -1
		local r = k <= 4 and k - 1 or 8 - k
		local sw, sh = L.Slot[1], L.Slot[2]
		local y = -1.5 * L.Pitch + r * L.Pitch
		local lean = -y * ST.lean()
		local x = side * L.Gap + lean + (side > 0 and 0 or -sw)
		if outer then
			x += side * (sw + L.Outer)
		end
		return x, y - sh / 2, side, outer
	end

	-- the slot that's lit: a paper slab with your slash under it, nudged 8 out
	local function setHover(i)
		if hover == i then
			return
		end
		local ST = HUD.ST
		local S = Config.UI.Street
		local L = EW.L
		local old = hover and buttons[hover]
		hover = i
		if old and old.Parent then
			ST.paint(old, S.Ink, 0.14)
			old.Label.TextColor3 = S.Paper
			old.Num:SetAttribute("NumColor", S.Paper)
			HUD.ST.setNumerals(old.Num, old.Num:GetAttribute("NumText") or "")
			ST.tween(old, S.Motion.Hover, { Position = old:GetAttribute("Home") }, Enum.EasingStyle.Quad)
		end
		if EW.slash then
			EW.slash:Destroy()
			EW.slash = nil
		end
		local b = i and buttons[i]
		if b and b.Parent and b.Visible then
			ST.paint(b, S.Paper, 0)
			b.Label.TextColor3 = S.Ink
			b.Num:SetAttribute("NumColor", S.Ink)
			HUD.ST.setNumerals(b.Num, b.Num:GetAttribute("NumText") or "")
			local side = b:GetAttribute("Side") or 1
			local home = b:GetAttribute("Home")
			ST.tween(b, S.Motion.Hover, { Position = home + UDim2.fromOffset(side * S.Motion.HoverNudge, 0) }, Enum.EasingStyle.Quad)
			local sw, sh = L.Slot[1], L.Slot[2]
			local col
			pcall(function()
				local q = Config.Quirks[game:GetService("Players").LocalPlayer:GetAttribute("Quirk") or ""]
				col = q and q.Color
			end)
			EW.slash = ST.slash({
				Name = "Hover", Size = { sw + 40, math.floor(sh * 1.2) }, Color = col or S.Paper, Value = 0, Rotation = -4, Z = 1,
				Pos = home + UDim2.fromOffset(side * S.Motion.HoverNudge - 22, math.floor(sh / 2 + 12 - sh * 0.6)),
				Parent = EW.center,
			})
			ST.setSlash(EW.slash, 1, S.Motion.SlashPaint)
		end
		-- the pointer: a 3 px paper bar from you to it
		local p = EW.pointer
		if p then
			p.Visible = b ~= nil and b.Visible
			if p.Visible then
				local home = b:GetAttribute("Home")
				local tx = home.X.Offset + (b:GetAttribute("Side") > 0 and 6 or L.Slot[1] - 6)
				local ty = home.Y.Offset + L.Slot[2] / 2
				local len = math.max(math.sqrt(tx * tx + ty * ty) - 20, 1)
				local ang = math.atan2(ty, tx)
				p.Size = UDim2.fromOffset(math.floor(len + 0.5), 3)
				p.Position = UDim2.fromOffset(math.floor(math.cos(ang) * (16 + len / 2) + 0.5), math.floor(math.sin(ang) * (16 + len / 2) + 0.5))
				p.Rotation = math.deg(ang)
			end
		end
	end

	-- the drawn slot in a direction (turn: 0..1 round from the top) for the
	-- stick: inner pair or outer. ((round 100 review) the stick's right half is
	-- the right column, top to bottom - up-right 1, right 2 / 3, down-right 4 -
	-- and its left half the left one, bottom to top - 5 to 8: the ring's old
	-- rounding sent a push just right of straight down to 5, on the left)
	local function slotAt(turn, outer)
		if layout.outer == 0 then
			outer = false
		end
		local k = math.floor(turn * 8 + 1e-3) % 8 + 1
		local i = outer and 8 + k or k
		local b = buttons[i]
		return (b and b.Visible) and i or nil
	end
	-- the drawn slot nearest in angle to a point (from the centre, root units)
	local function nearest(off)
		local L = EW.L
		local useOuter = layout.outer > 0 and math.abs(off.X) > L.Gap + L.Slot[1] + L.Outer / 2
		local best, bd = nil, math.huge
		local a = math.atan2(off.Y, off.X)
		for i, b in buttons do
			if b.Visible and (i > 8) == useOuter then
				local home = b:GetAttribute("Home")
				local cx = home.X.Offset + L.Slot[1] / 2
				local cy = home.Y.Offset + L.Slot[2] / 2
				local d = math.abs((math.atan2(cy, cx) - a + math.pi) % (2 * math.pi) - math.pi)
				if d < bd then
					best, bd = i, d
				end
			end
		end
		return best
	end

	function HUD.BuildEmoteWheel(list, onPick)
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = E()
		pickFn = onPick
		local open = wheel ~= nil and wheel.Visible
		if wheel then
			wheel:Destroy()
		end
		-- (the old wheel's own autoScale call kept today's list of scaled frames
		-- clear of ones that are gone; the picker scales by its root, so it prunes it)
		for i = #autoScales, 1, -1 do
			local ok, parent = pcall(function()
				return autoScales[i].Parent
			end)
			if not (ok and parent) then
				table.remove(autoScales, i)
			end
		end
		table.clear(buttons)
		hover = nil
		EW.slash = nil
		EW.list = list
		layout.inner = math.min(#list, 8)
		layout.outer = math.max(#list - 8, 0)
		local phone = ST.isPhone()
		EW.phone = phone
		local L = phone and c.Phone or c
		EW.L = L
		wheel = make("TextButton", {
			Name = "EmoteWheel",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = S.Ink,
			BackgroundTransparency = c.Dim,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Modal = true,
			Visible = false,
			-- (under the combat HUD on PC, so the HUD stays in view; on a phone over
			-- it - the touch pad sits where the right column is, and steps aside)
			ZIndex = phone and 40 or 0,
			Parent = gui,
		})
		local root = ST.rootOf(wheel)
		-- (everything placed from you: the centre of the two columns. (round 100
		-- review) from the screen's middle, where the camera keeps you, whatever
		-- the screen's shape - a 4:3 tablet, a wide window, a 16:9 phone)
		EW.base = phone and { 812, 375 } or { 1280, 720 }
		local center = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, math.floor(L.Center[1] - EW.base[1] / 2 + 0.5), 0.5, math.floor(L.Center[2] - EW.base[2] / 2 + 0.5)),
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 1,
			Parent = root,
		})
		EW.center = center
		-- the pointer and the diamond on you
		EW.pointer = make("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = S.Paper, BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.fromOffset(10, 3), Visible = false, ZIndex = 2, Parent = center })
		make("Frame", { Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = S.Paper, BorderSizePixel = 0, Size = UDim2.fromOffset(11, 11), Rotation = 45, ZIndex = 3, Parent = center })
		local sw, sh = L.Slot[1], L.Slot[2]
		local lean = ST.lean()
		for i, e in list do
			local x, y, side, outer = slotPlace(i, L)
			local home = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
			local b = ST.slab({
				Name = e.Empty and ("Emote_Empty" .. i) or ("Emote_" .. tostring(e.Id)), Button = true, Size = { sw, sh }, Pos = home,
				Color = S.Ink, T = 0.14, Z = 2, Visible = not e.Empty, Parent = center,
			})
			b:SetAttribute("Home", home)
			b:SetAttribute("Side", side)
			b:SetAttribute("Slot", i)
			b:SetAttribute("Outer", outer)
			b:SetAttribute("Label", e.Empty and c.More or string.upper(e.Name or e.Id))
			b:SetAttribute("EmoteId", e.Id)
			local num = ST.numerals(tostring(i), L.Num, { Name = "Num", T = 0.5, Z = 3, Parent = b })
			num:SetAttribute("NumText", tostring(i))
			num.Position = UDim2.fromOffset(math.floor(sh * lean + 6 + 0.5), math.floor(sh * 0.42 - ST.metrics(L.Num).Base + 0.5))
			local nsize = L.Name
			local name = e.Empty and "EMPTY" or string.upper(e.Name or e.Id)
			while ST.measure(name, nsize) > sw - sh * lean - 34 and nsize > 12 do
				nsize -= 1
			end
			ST.label({ Name = "Label", Text = name, Size = nsize, Pos = UDim2.new(0, math.floor(sh * lean + 24 + 0.5), 0.5, 1), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = b })
			b.MouseEnter:Connect(function()
				setHover(i)
			end)
			b.Activated:Connect(function()
				HUD.PickEmote(i)
			end)
			buttons[i] = b
		end
		-- under you: the hint (the first few opens), MORE IN THE SHOP
		local below = 2 * L.Pitch + (phone and 14 or 22)
		EW.hint = ST.shadowText({ Name = "Hint", Text = c.Hint, Size = phone and 11 or 13, Shadow = 1, T = 0.15, AlignX = "Center", Box = UDim2.fromOffset(300, 22), Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.fromOffset(0, below), Z = 3, Parent = center })
		EW.more = make("TextButton", { Name = "More", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(0, below + (phone and 16 or 20)), ZIndex = 3, Parent = center })
		ST.shadowText({ Name = "Label", Text = c.More, Size = phone and 11 or 12, Shadow = 1, T = 0.45, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 3, Parent = EW.more })
		EW.more.Activated:Connect(function()
			HUD.ShowEmoteWheel(false)
			if pickFn then
				pickFn(nil)
			end
		end)
		wheel.Activated:Connect(function()
			HUD.ShowEmoteWheel(false)
		end)
		if open then
			wheel.Visible = true
		end
	end

	function HUD.EmoteWheelVisible()
		return wheel ~= nil and wheel.Visible
	end

	-- ((round 100 review) where you are - the columns' centre - in the root's
	-- units: the mouse is measured from here)
	function EW.centerAt()
		local L, b = EW.L, EW.base or { 1280, 720 }
		local vw, vh = HUD.Menus.view()
		return Vector2.new(vw / 2 + L.Center[1] - b[1] / 2, vh / 2 + L.Center[2] - b[2] / 2)
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
		local ST = HUD.ST
		local c = E()
		local was = wheel.Visible
		if on and ST.isPhone() ~= EW.phone and EW.list then
			HUD.BuildEmoteWheel(EW.list, pickFn) -- (a phone flip since it was made: its own places)
		end
		wheel.Visible = on == true
		setHover(nil)
		if watch then
			watch:Disconnect()
			watch = nil
		end
		pcall(function()
			game:GetService("ContextActionService"):UnbindAction("EmoteWheelKeys")
		end)
		if not on then
			pcall(function()
				game:GetService("ContextActionService"):UnbindAction("EmoteWheelStick")
			end)
			if was then
				HUD.Menus.closed("Wheel")
			end
			return
		end
		if not was then
			HUD.Menus.opened("Wheel")
			EW.opens += 1
		end
		local padNow = HUD.UsingGamepad()
		local drawn = 0
		for _, b in buttons do
			if b.Visible then
				drawn += 1
			end
		end
		-- the hint: under you, the first few opens only (an empty wheel says where to get them)
		EW.hint.Visible = EW.opens <= c.HintOpens and drawn > 0
		ST.setText(EW.hint, padNow and string.format(c.HintPad, HUD.PadGlyph(Config.EmoteKeys)) or c.Hint)
		EW.more.Visible = true
		if padNow then
			pcall(function()
				game:GetService("ContextActionService"):BindActionAtPriority("EmoteWheelStick", function()
					return Enum.ContextActionResult.Sink
				end, false, 3000, Enum.KeyCode.Thumbstick2)
			end)
		end
		-- 1-8 play that slot while it's up (they don't throw a move)
		pcall(function()
			local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }
			game:GetService("ContextActionService"):BindActionAtPriority("EmoteWheelKeys", function(_, state, input)
				if state == Enum.UserInputState.Begin then
					local n = table.find(keys, input.KeyCode)
					if n and buttons[n] then
						HUD.PickEmote(n)
					end
				end
				return Enum.ContextActionResult.Sink
			end, false, 3000, table.unpack(keys))
		end)
		-- the slot in the mouse's direction from you lights up (only once the
		-- mouse moves: opening it doesn't pick whatever the cursor was on)
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
				local turn = (math.atan2(s.Y, s.X) + math.pi / 2) / (math.pi * 2)
				setHover(slotAt(turn, s.Magnitude > 0.93))
				return
			end
			local m = mouseAt()
			if not m or #buttons == 0 or (last and (m - last).Magnitude < 1) then
				return
			end
			last = m
			-- ((round 101, Studio) the slot the mouse is ON comes first: in the two
			-- stacked columns the nearest angle from you isn't always the slot under
			-- the cursor - clicking FINAL FORM's name (its far end, out from you) lit
			-- AURA FARM below it, the one closer to level. GetMouseLocation counts
			-- Roblox's top bar; AbsolutePosition doesn't)
			local okIn, inset = pcall(function()
				return game:GetService("GuiService"):GetGuiInset()
			end)
			local q = m - ((okIn and typeof(inset) == "Vector2") and inset or Vector2.zero)
			for i, b in buttons do
				if b.Visible then
					local okR, p, sz = pcall(function()
						return b.AbsolutePosition, b.AbsoluteSize
					end)
					if okR and sz.X > 0 and q.X >= p.X and q.X <= p.X + sz.X and q.Y >= p.Y and q.Y <= p.Y + sz.Y then
						setHover(i)
						return
					end
				end
			end
			local off = m / ST.scale() - EW.centerAt()
			if off.Magnitude < 40 then
				return
			end
			setHover(nearest(off))
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

	-- ON A CONTROLLER: a menu instead of the wheel - a leaning grid of slabs
	-- you move between with the D-pad / left stick, A to play one, B to close
	local menuPanel, menuHolder
	local menuCards = {}
	function HUD.BuildEmoteMenu(list)
		local ST = HUD.ST
		local S = Config.UI.Street
		if menuHolder then
			menuHolder:Destroy()
		end
		table.clear(menuCards)
		local cols = #list > 12 and 6 or 4
		local rows = math.max(math.ceil(#list / cols), 1)
		local W, H, GAP = 150, 64, 8
		local lean = ST.lean()
		local pw = cols * W + (cols - 1) * GAP + 56 + rows * (H + GAP) * lean
		local ph = rows * H + (rows - 1) * GAP + 92
		menuHolder = make("Frame", { Name = "EmoteMenuHolder", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 45, Parent = gui })
		local root = ST.rootOf(menuHolder)
		menuPanel = ST.slab({ Name = "EmoteMenu", Size = { math.floor(pw + ph * lean), ph }, Anchor = Vector2.new(0.5, 0.5), Pos = UDim2.new(0.5, 0, 0, 380), Color = S.Ink, T = S.MenuT, Z = 45, Visible = false, Parent = root })
		ST.label({ Name = "Title", Text = "EMOTES", Size = 30, Pos = UDim2.fromOffset(math.floor(ph * lean + 10), 10), Z = 46, Parent = menuPanel })
		ST.label({ Name = "Hint", Role = "Mono", Text = "A  PLAY      B  BACK", Size = 12, Color = S.Ash, Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, -40, 0, 22), Z = 46, Parent = menuPanel })
		for i, e in list do
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			-- (each row a little further left: the grid leans with everything else)
			local card = ST.slab({
				Name = e.Empty and ("EmoteCard_Empty" .. i) or ("EmoteCard_" .. tostring(e.Id)), Button = true, Size = { W, H },
				Pos = UDim2.fromOffset(math.floor(28 + (rows - 1 - row) * (H + GAP) * lean + col * (W + GAP) + ph * lean * 0.5 + 0.5), 60 + row * (H + GAP)),
				Color = S.Ink2, T = 0, Z = 46, Parent = menuPanel,
			})
			card.Selectable = true
			card:SetAttribute("EmoteId", e.Id)
			ST.numerals(tostring(i), 13, { Name = "Num", T = 0.5, Pos = UDim2.fromOffset(math.floor(H * lean + 4), 4), Z = 47, Parent = card })
			local name = e.Empty and "EMPTY SLOT" or string.upper(e.Name or e.Id)
			local nsize = 16
			while ST.measure(name, nsize) > W - H * lean - 16 and nsize > 11 do
				nsize -= 1
			end
			ST.label({ Name = "Label", Text = name, Size = nsize, T = e.Empty and 0.55 or 0, Pos = UDim2.new(0, math.floor(H * lean * 0.5 + 8), 1, -8), Anchor = Vector2.new(0, 1), Z = 47, Parent = card })
			-- (the one the controller is on: paper)
			local function lit(on)
				ST.paint(card, on and S.Paper or S.Ink2, 0)
				card.Label.TextColor3 = on and S.Ink or S.Paper
				card.Num:SetAttribute("NumColor", on and S.Ink or S.Paper)
				ST.setNumerals(card.Num, tostring(i))
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
		-- (a solid grid: the pad moves card to card, wrapping round the rows)
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
		local was = menuPanel.Visible
		menuPanel.Visible = on == true
		if on then
			HUD.ShowEmoteWheel(false)
			if not was then
				HUD.Menus.opened("Wheel")
			end
			local hint = menuPanel:FindFirstChild("Hint")
			if hint and HUD.PadGlyph then
				hint.Text = HUD.PadGlyph({ Enum.KeyCode.ButtonA }) .. "  PLAY      " .. HUD.PadGlyph({ Enum.KeyCode.ButtonB }) .. "  BACK"
				hint.Size = UDim2.fromOffset(math.ceil(HUD.ST.measure(hint.Text, 12, "Mono")) + 2, hint.Size.Y.Offset)
			end
		elseif was then
			HUD.Menus.closed("Wheel")
		end
	end

	function HUD.EmoteMenuVisible()
		return menuPanel ~= nil and menuPanel.Visible
	end

	-- (where a controller's selection starts: the first card)
	function HUD.EmoteMenuFirst()
		return menuCards[1]
	end
	HUD.Menus.closers.Wheel = function()
		HUD.ShowEmoteWheel(false)
		if HUD.EmoteMenuVisible() then
			if HUD.EmoteMenuClosed then
				HUD.EmoteMenuClosed()
			else
				HUD.ShowEmoteMenu(false)
			end
		end
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

	-- (round 100) THE CONTROLLER'S LEGEND, Stark Street: a leaning ink sheet on
	-- the left (over the bag's lane, clear of the vitals now bottom left), two
	-- columns of a key cap (the pad's button as a word: A, LB, UP) and what it
	-- does, Oswald. No coloured face discs, no round corners.
	function HUD.BuildPadLegend()
		if legend then
			legend:Destroy()
		end
		local C = Config
		local S = C.UI.Street
		local rows = {
			{ C.M1Keys, "PUNCH" }, { C.BlockKeys, "BLOCK" }, { C.DashKeys, "DASH" },
			{ { Enum.KeyCode.ButtonA }, "JUMP" }, { C.SpecialKeys, "SPECIAL" }, { C.UltKeys, "AWAKEN" },
			{ C.ShiftLockKeys, "SHIFT LOCK" }, { C.UseItemKeys, "ITEM" }, -- ((round 92) no LOCK ON row: gone)
			{ C.EmoteKeys, "EMOTES" }, { C.ShopKeys, "SHOP" }, { C.ContextKeys, "FINISH" },
		}
		local FH = HUD.FH
		local rowH, colW, top = 22, 132, 12
		local h = 6 * rowH + top * 2
		legend = make("Frame", {
			Name = "PadLegend",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 116),
			Size = UDim2.fromOffset(2 * colW + 40, h),
			Parent = FH.root or gui,
		})
		ST.slab({ Name = "Sheet", Size = { 2 * colW + 40, h }, T = S.HudT, Ends = "Right", Z = 1, Parent = legend })
		local n = 0
		for _, row in rows do
			local key = padKey(row[1])
			if key then
				local col, line = math.floor(n / 6), n % 6
				n += 1
				local y = top + line * rowH
				local x = 12 + col * colW
				local cell = make("Frame", {
					Name = row[2], BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(colW, rowH), ZIndex = 2, Parent = legend,
				})
				local cap = ST.keyCap(FH.keyWord(HUD.PadGlyph({ key })), 16, { Name = "Glyph", Pos = UDim2.new(0, 0, 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = cell })
				ST.label({ Name = "Label", Text = row[2], Size = 13, Pos = UDim2.new(0, cap.Size.X.Offset + 8, 0.5, 1), Anchor = Vector2.new(0, 0.5), Z = 3, Parent = cell })
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
	local card -- ((round 100) the rank card is the corner's: HUD.FH.buildCorner)
	local settingsPanel, settingsCbs = nil, {}
	local settingRows, settingValues = {}, { WearCosmetics = true, ShowCosmetics = true, Music = true, Blood = true }
	local boardPanel, boardRows, boardMe, ladder
	local myKills = 0
	-- (round 100) the settings, one line each, written to fit (no cut-off
	-- sentences). Pad: only drawn while a controller's connected (the
	-- CONTROLLER block); Hawks: only while you play Hawks. MUSIC: the game's
	-- one music switch (the ult themes and the event songs) - the old top-right
	-- MUSIC button was this same setting, so it lives here now.
	local SETTINGS = {
		{ Key = "WearCosmetics", Label = "MY COSMETICS", Info = "Wear your hero's signature look. Everyone sees it." },
		{ Key = "ShowCosmetics", Label = "SHOW COSMETICS", Info = "See other players' looks." },
		{ Key = "Music", Label = "MUSIC", Info = "Themes play during ults and events." },
		{ Key = "Blood", Label = "BLOOD", Info = "Hard hits and KOs. Only on your screen." },
		-- (round 65, like JJS) off until you switch it on
		{ Key = "AutoRun", Label = "AUTO RUN", Info = "Always run. No double tap.", Default = false },
		-- (round 86) Hawks' wings can fill your own view: hide yours (only on your screen)
		{ Key = "HideMyWings", Label = "HIDE MY WINGS", Info = "Only you stop seeing them.", Default = false, Hawks = true },
		-- (round 68) the controller's camera: how fast the stick turns it (a step at a time)
		{
			Key = "PadSensitivity", Label = "STICK SPEED", Pad = true,
			-- (the steps here: this list is built before the HUD is handed Config)
			Steps = { 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3 }, Default = 1,
		},
		{ Key = "RobloxCamera", Label = "ROBLOX CAMERA", Default = false, Pad = true },
	}
	local MS = { board = {}, fit = {} } -- (round 100) the sheets' state: settings, the board, the outfits

	local function hex(c)
		return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
	end

	-- (round 100) a menu sheet (Stark Street): one leaning ink slab in the menus'
	-- root, its title in big words (a kicker beside it, ash) and the drawn X.
	-- spec = { X, W, Top, Bottom, Margin, TitleY } (Config.UI.Menus.*); a phone
	-- gets a full-height sheet from x 96 to the right edge. Returns a sheet
	-- table: Holder (the ST.panel), Content, lx(y) (the leaning left margin at
	-- screen y), rx(y) (the right one), sx(x) / sy(y) (screen -> sheet), Phone.
	local function panel(name, title, kicker, spec, onClose)
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local phone = ST.isPhone()
		local T, B, X, W = spec.Top, spec.Bottom, spec.X, spec.W
		local margin = spec.Margin or 36
		-- ((round 100 review) a phone's sheet is laid out on its real width (a
		-- 16:9 phone is 667, not the mockup's 812): one that runs to the right
		-- edge runs to that edge; one that stops short (settings) keeps its
		-- width and moves left so it all stays on screen. PC sheets sit on the
		-- centred stage (MN.stage), so a wide or a 4:3 screen keeps them centred)
		local vw, vh = MN.view()
		local edge = false
		if phone then
			T, B, X, W, margin = 40, vh, spec.PhoneX or 96, spec.PhoneW or 716, 22
			edge = X + W >= 812
			if edge then
				W = vw - X
			elseif X + W > vw - 8 then
				X = math.max(24, math.floor(vw - 8 - W))
			end
		end
		local lean = ST.lean()
		local holder = MN.panel({
			Name = name, Parent = MN.stage(), X = X, W = W, Top = T, Bottom = B, T = S.MenuT, Margin = margin,
			Ends = edge and "Left" or "Both", Z = 10,
		})
		local ox = holder:GetAttribute("SheetX")
		holder.Sheet.Active = true -- (a click on the sheet stays on it: no punch through the menu)
		local sheet = { Holder = holder, Content = holder.Sheet.Content, Phone = phone, Top = T, Bottom = B, Lean = lean, Key = MN.viewKey(), ViewW = vw }
		function sheet.lx(y)
			return X - (y - T) * lean + margin
		end
		function sheet.rx(y)
			if edge then
				return vw - 22
			end
			return X + W - (y - T) * lean - 28
		end
		function sheet.sx(x)
			return x - ox
		end
		function sheet.sy(y)
			return y - T
		end
		local ty = phone and 74 or (spec.TitleY or 122)
		local tsize = phone and 26 or 40
		if title and title ~= "" then
			MN.text(sheet.Content, title, tsize, sheet.sx(sheet.lx(ty)), ty - T, { Name = "Title", Z = 3 })
			if kicker and kicker ~= "" then
				MN.text(sheet.Content, kicker, phone and 11 or 12, sheet.sx(sheet.lx(ty) + ST.measure(title, tsize) + 14), ty - 4 - T, { Name = "Kicker", T = 0.5, Z = 3 })
			end
		end
		sheet.TitleY = ty
		ST.closeX({ Name = "Close", Size = phone and 14 or 18, Pos = UDim2.fromOffset(math.floor(sheet.sx(sheet.rx(ty - 18) - 6) + 0.5), ty - 18 - T), Z = 5, Parent = sheet.Content, OnClick = onClose })
		return sheet
	end

	-- the rank card (top right, beside the wallet). (round 100) It's the
	-- corner's rank slab now (HUD.FH.buildCorner: NO.1 HERO, 619 KO, the way to
	-- the next rank along its foot; STREAK from 3); its SETTINGS / TOP buttons
	-- are gone - the top bar's tabs are the one route to each
	function HUD.BuildRankCard(player)
		if card or not gui then
			return
		end
		card = true
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

	-- what the board's own line says about you, and your rung on the ladder
	-- ((round 100) drawn by the board itself: MS.board.drawMe)
	local function refreshMe()
		if MS.board.drawMe then
			MS.board.drawMe()
		end
	end

	-- your kills and streak: the rank, its colour, the way to the next one
	-- (round 100: the corner's rank slab - NO.1 HERO, 619 KO - and STREAK from 3)
	function HUD.SetRank(kills, streak)
		myKills = kills or 0
		if not card then
			return
		end
		HUD.FH.state.kills = myKills
		HUD.FH.state.streak = streak or 0
		HUD.FH.buildCorner()
		refreshMe()
	end

	-- a new rank ((round 100) Stark Street, HUD.MO): yours a 1.2 s moment
	-- (RANK UP, the rank on its slash, how far to the next) and your row in the
	-- feed; anyone else's a row in the feed (NAME, a slash in the rank's colour, THE RANK)
	function HUD.RankUp(data, mine)
		local rank = Config.Ranks[data.Index or 1] or Config.Ranks[1]
		-- ((round 100 review) the slash is the player's hero's colour, as in a KO
		-- row - Stark Street has one colour, and a rank has none of its own)
		local color = HUD.MO.playerColor(data.UserId)
		if not mine then
			HUD.MO.rankRow(feedList, data.Player, rank, false, color)
			return
		end
		if not gui then
			return
		end
		HUD.MO.rankUp(data, color)
		HUD.MO.rankRow(feedList, data.Player, rank, true, color)
	end

	---------------------------------------------------------------------------
	-- (round 100) SETTINGS (mockup 07): a narrower leaning sheet; a row a
	-- setting - its name, one sentence, a two-state switch (STICK SPEED: its
	-- leaning ticks). The CONTROLLER block is only there with a controller
	-- connected, HIDE MY WINGS only while you play Hawks; the rows scroll if
	-- they're ever more than fit. cbs: OnSet(key, on), OnToggle(open, which)
	---------------------------------------------------------------------------
	local function wantRow(def)
		if def.Pad then
			local ok, on = pcall(function()
				local uis = game:GetService("UserInputService")
				return uis.GamepadEnabled == true or #uis:GetConnectedGamepads() > 0
			end)
			return ok and on == true
		end
		if def.Hawks then
			local ok, q = pcall(function()
				return game:GetService("Players").LocalPlayer:GetAttribute("Quirk")
			end)
			return ok and q == "FierceWings"
		end
		return true
	end
	MS.wantRow = wantRow

	-- a stepped setting's ticks, and its value in numerals (100%)
	function MS.showStep(sl, key, value)
		local ST = HUD.ST
		local def
		for _, d in SETTINGS do
			if d.Key == key then
				def = d
			end
		end
		local steps = def and def.Steps or { 1 }
		local at = 1
		for k, v in steps do
			if math.abs(v - value) < 1e-3 then
				at = k
			end
		end
		ST.setSlider(sl, at / #steps)
		ST.setNumerals(sl.Value, tostring(math.floor(value * 100 + 0.5)) .. "%")
	end

	function MS.buildSettings()
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Settings
		local open = settingsPanel ~= nil and ST.panelOpen(settingsPanel)
		if settingsPanel then
			settingsPanel:Destroy()
		end
		table.clear(settingRows)
		local sheet = panel("Settings", c.Title, nil, { X = c.X, W = c.W, Top = c.Top, Bottom = c.Bottom, Margin = c.Margin, TitleY = c.TitleY, PhoneX = 200, PhoneW = 520 }, function()
			HUD.ToggleSettings(false)
		end)
		settingsPanel = sheet.Holder
		MS.set = sheet
		local phone = sheet.Phone
		local top = phone and 92 or 150
		local bottom = sheet.Bottom - (phone and 6 or 24)
		local left = sheet.lx(bottom) - 14
		local width = math.floor(sheet.rx(top) - left + 8)
		local list = make("ScrollingFrame", {
			Name = "Rows",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(math.floor(sheet.sx(left) + 0.5), top - sheet.Top),
			Size = UDim2.fromOffset(width, bottom - top),
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ZIndex = 3,
			Parent = sheet.Content,
		})
		MS.setList, MS.setTop = list, top
		MS.setPlace = MN.leanScroll(list, top, function(y)
			return sheet.lx(y) - left
		end)
		MS.setBar = ST.scrollbar(list, { T = 0.3 })
		local span = sheet.rx(top) - sheet.lx(top) -- (the row's width: the margins lean together)
		local pitch = phone and 50 or c.Row
		local lsize = phone and 17 or c.Label
		local ssize = phone and 11 or c.Sentence
		local swSize = phone and { 96, 26 } or c.Switch
		MS.pitch = pitch
		for _, def in SETTINGS do
			local h = def.Info and pitch or (phone and 40 or 44)
			local row = make("Frame", { Name = def.Key, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(math.floor(span + 20), h), ZIndex = 3, Parent = list })
			row:SetAttribute("H", h)
			local base = def.Info and (phone and 18 or 22) or (phone and 24 or 28)
			row:SetAttribute("BaseOff", base)
			MN.text(row, def.Label, lsize, 0, base, { Name = "Label", Z = 4 })
			if def.Info then
				MN.text(row, def.Info, ssize, -2, base + (phone and 17 or 21), { Name = "Info", Role = "Body", T = 0.34, Z = 4 })
			end
			if def.Steps then
				local n = #def.Steps
				local sl = ST.slider({ Name = "Slider", N = n, Size = { phone and 150 or 205, phone and 14 or 18 }, Max = 100,
					Pos = UDim2.fromOffset(math.floor(span - (phone and 220 or 270) + 0.5), base - (phone and 13 or 18)), Z = 4, Parent = row,
					OnChange = function(v)
						local value = def.Steps[math.clamp(math.floor(v * n + 0.5), 1, n)]
						HUD.SetSetting(def.Key, value)
						if settingsCbs.OnSet then
							settingsCbs.OnSet(def.Key, value)
						end
					end })
				settingRows[def.Key] = sl
			else
				local sw = ST.switch({ Name = "Switch", On = true, Size = swSize,
					Pos = UDim2.fromOffset(math.floor(span - swSize[1] - 8 + 0.5), def.Info and (phone and 4 or 4) or (phone and 6 or 6)), Z = 4, Parent = row,
					OnChange = function(on)
						HUD.SetSetting(def.Key, on)
						if settingsCbs.OnSet then
							settingsCbs.OnSet(def.Key, on)
						end
					end })
				settingRows[def.Key] = sw
			end
			if def.Info then
				make("Frame", { Name = "Rule", BackgroundColor3 = S.Ash, BackgroundTransparency = 0.7, BorderSizePixel = 0, Position = UDim2.fromOffset(-4, h - 7), Size = UDim2.fromOffset(math.floor(span + 8), 1), ZIndex = 3, Parent = row })
			end
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
		MS.padLabel = make("Frame", { Name = "Controller", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(200, 30), ZIndex = 3, Parent = list })
		MS.padLabel:SetAttribute("BaseOff", 22)
		MN.text(MS.padLabel, c.Controller, 13, 0, 22, { Name = "Label", T = 0.5, Z = 4 })
		MS.layoutSettings()
		if open then
			MN.reopen(settingsPanel)
		end
	end

	-- which rows are there (the controller's, Hawks'), stacked down the sheet
	function MS.layoutSettings()
		if not MS.setList then
			return
		end
		local ST = HUD.ST
		local y = 0
		local padDone = false
		for _, def in SETTINGS do
			local row = MS.setList:FindFirstChild(def.Key)
			if row then
				local on = wantRow(def)
				row.Visible = on
				if on then
					if def.Pad and not padDone then
						padDone = true
						MS.padLabel:SetAttribute("CanvasY", y + 8)
						y += 38
					end
					row:SetAttribute("CanvasY", y)
					y += row:GetAttribute("H") or MS.pitch
				end
			end
		end
		MS.padLabel.Visible = padDone
		MS.setList.CanvasSize = UDim2.fromOffset(0, y + 8)
		MS.setPlace()
		ST.updateScrollbar(MS.setBar, MS.setList)
	end

	function HUD.BuildSettings(cbs)
		settingsCbs = cbs or settingsCbs or {}
		if settingsPanel or not gui then
			return
		end
		MS.buildSettings()
		HUD.ST.onLayout(function(phone)
			if MS.set and phone ~= MS.set.Phone then
				MS.buildSettings()
			end
		end)
		HUD.Menus.watch(function()
			if MS.set and MS.set.Key ~= HUD.Menus.viewKey() then
				MS.buildSettings()
			end
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Quirk"):Connect(MS.layoutSettings)
		end)
	end

	-- how a switch reads (the saved value coming back, or a click)
	function HUD.SetSetting(key, on)
		local ST = HUD.ST
		if type(on) == "number" then
			-- (round 68) a stepped setting: its ticks, its value as a percentage
			settingValues[key] = on
			local sl = settingRows[key]
			if sl then
				MS.showStep(sl, key, on)
			end
			return
		end
		settingValues[key] = on ~= false
		local sw = settingRows[key]
		if sw and sw:GetAttribute("On") ~= nil then
			ST.setSwitch(sw, settingValues[key])
		end
	end

	function HUD.GetSetting(key)
		return settingValues[key]
	end

	function HUD.ToggleSettings(force)
		if not settingsPanel then
			return false
		end
		local ST = HUD.ST
		local was = ST.panelOpen(settingsPanel)
		local open = force
		if open == nil then
			open = not was
		end
		if open and not was then
			HUD.Menus.opened("Settings")
			MS.layoutSettings()
			ST.openPanel(settingsPanel)
		elseif not open and was then
			ST.closePanel(settingsPanel)
			HUD.Menus.closed("Settings")
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Settings")
		end
		return open
	end
	HUD.Menus.closers.Settings = function()
		HUD.ToggleSettings(false)
	end

	function HUD.SettingsVisible()
		return settingsPanel ~= nil and HUD.ST.panelOpen(settingsPanel)
	end

	---------------------------------------------------------------------------
	-- (round 59) AWAKENING OUTFIT (the picker's OUTFIT button): your saved
	-- Roblox outfits, a card each, and your own avatar; whichever you pick,
	-- you wear while you're awakened (Config.AwakeningOutfits). The list itself
	-- comes from your own machine (OnOpen - it asks Roblox, with your say-so).
	-- (round 100) Stark Street: AWAKEN IN, the picked one on your slash; the
	-- sheet sized to its cards; the default card says YOUR AVATAR once;
	-- checking your closet... while it asks. (round 98) Locked: the pass.
	---------------------------------------------------------------------------
	local FIT = MS.fit
	FIT.cards, FIT.names, FIT.chosen, FIT.cbs, FIT.list = {}, {}, 0, {}, {}

	function HUD.SetOutfitCallbacks(cbs)
		FIT.cbs = cbs or {}
	end

	-- the hero colour your slash is in (paper with none)
	local function myColor()
		local q
		pcall(function()
			q = Config.Quirks[game:GetService("Players").LocalPlayer:GetAttribute("Quirk") or ""]
		end)
		return q and q.Color or Config.UI.Street.Paper
	end

	function FIT.build()
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = Config.UI.Menus.Outfits
		local open = FIT.panel ~= nil and ST.panelOpen(FIT.panel)
		if FIT.panel then
			FIT.panel:Destroy()
		end
		table.clear(FIT.cards)
		local phone = ST.isPhone()
		local cw, ch = c.Card[1], c.Card[2]
		if phone then
			cw, ch = 104, 124
		end
		-- ((round 100 review) a narrow phone - 16:9 is 667 wide - fits three a row)
		local cols = phone and (HUD.Menus.view() >= 760 and 4 or 3) or c.Cols
		local rows = FIT.rowsFor(cols)
		local lean = ST.lean()
		-- (sized to its cards: the sheet as tall as their rows, at most the screen)
		local gridH = rows * (ch + c.Gap)
		local top = 66
		local bottom = math.min(700, top + 120 + gridH + 60)
		local w = cols * (cw + c.Gap) + 80 + rows * (ch + c.Gap) * lean
		local sheet = panel("Outfits", c.Title, nil, { X = math.floor(640 - w / 2 + (bottom - top) * lean / 2), W = math.floor(w), Top = top, Bottom = bottom, Margin = 36, TitleY = 122, PhoneX = 120, PhoneW = 692 }, function()
			HUD.ToggleOutfits(false)
		end)
		FIT.panel, FIT.sheet = sheet.Holder, sheet
		if not FIT.watching then
			-- ((round 100 review) made again for a new screen shape, like the rest)
			FIT.watching = true
			HUD.ST.onLayout(function(phone)
				if FIT.panel and phone ~= FIT.sheet.Phone then
					FIT.build()
				end
			end)
			HUD.Menus.watch(function()
				if FIT.panel and FIT.sheet.Key ~= HUD.Menus.viewKey() then
					FIT.build()
				end
			end)
		end
		local content = sheet.Content
		-- the picked one's name on your slash, after AWAKEN IN
		FIT.now = make("Frame", { Name = "Now", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		-- the cards (each row a little further left: they lean with the sheet)
		local gy = sheet.TitleY + (phone and 22 or 34)
		local gridBottom = sheet.Bottom - (phone and 34 or 54)
		local grid = make("ScrollingFrame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(gridBottom) - 12) + 0.5), gy - sheet.Top),
			Size = UDim2.fromOffset(math.floor(cols * (cw + c.Gap) + 40 + (gridBottom - gy) * lean), gridBottom - gy),
			CanvasSize = UDim2.fromOffset(0, gridH),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ZIndex = 3,
			Parent = content,
		})
		FIT.grid = grid
		local gridLeft = sheet.lx(gridBottom) - 12
		FIT.place = HUD.Menus.leanScroll(grid, gy, function(y)
			return sheet.lx(y) - gridLeft
		end)
		FIT.rows = rows
		FIT.geo = { cols = cols, cw = cw, ch = ch, lean = lean, phone = phone }
		FIT.fillCards()
		-- the line under them: asking (in marker), none, no access (+ ALLOW)
		FIT.statusY = gridBottom + (phone and 22 or 30)
		FIT.status = make("Frame", { Name = "Status", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 4, Visible = false, Parent = content })
		FIT.allow = ST.button({ Name = "Allow", Kind = "Secondary", Text = c.Allow, Size = { phone and 96 or 110, phone and 30 or 34 }, TextSize = phone and 15 or 17,
			Pos = UDim2.fromOffset(math.floor(sheet.sx(sheet.rx(FIT.statusY) - (phone and 100 or 120)) + 0.5), FIT.statusY - (phone and 22 or 26) - sheet.Top), Z = 5, Parent = content,
			OnClick = function()
				if FIT.cbs.OnRetry then
					FIT.cbs.OnRetry()
				end
			end })
		FIT.allow.Visible = false
		-- (round 98) no AWAKENING OUTFITS pass: this over the cards
		local lock = make("Frame", { Name = "Locked", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 8, Visible = false, Parent = content })
		local ly = gy + 20
		ST.slab({ Name = "Cover", Size = { grid.Size.X.Offset, gridBottom - gy }, Pos = grid.Position, Color = S.Ink, T = 0, Z = 8, Parent = lock })
		HUD.Menus.text(lock, c.Pass, phone and 22 or 30, sheet.sx(sheet.lx(ly + 30)), ly + 30 - sheet.Top, { Name = "Title", Z = 9 })
		HUD.Menus.text(lock, c.PassInfo, phone and 11 or 14, sheet.sx(sheet.lx(ly + 54) - 2), ly + 54 - sheet.Top, { Name = "Info", Role = "Body", T = 0.25, Z = 9 })
		local buy = ST.button({ Name = "Buy", Kind = "Primary", Text = c.Get, Size = { 200, 44 }, TextSize = 22, Pos = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(ly + 110)) + 0.5), ly + 70 - sheet.Top), Z = 9, Parent = lock,
			OnClick = function()
				if FIT.cbs.OnBuyPass then
					FIT.cbs.OnBuyPass()
				end
			end })
		FIT.buy = buy
		FIT.lock = lock
		HUD.SetOutfitLocked(FIT.locked, FIT.price)
		FIT.showStatus()
		HUD.MarkOutfit(FIT.chosen)
		if open then
			HUD.Menus.reopen(FIT.panel)
		end
	end

	-- the outfits wanted on cards: your avatar first, then each saved one (by Id)
	function FIT.wanted()
		local out = { { 0, "" } }
		local seen = { [0] = true }
		for _, o in FIT.list do
			if type(o.Id) == "number" and o.Id > 0 and not seen[o.Id] then
				seen[o.Id] = true
				table.insert(out, { o.Id, tostring(o.Name or "Outfit") })
			end
		end
		return out
	end
	function FIT.rowsFor(cols)
		return math.max(1, math.ceil(#FIT.wanted() / cols))
	end

	-- one card: the picture (your own avatar's headshot for the default), its name
	function FIT.card(id, name)
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = Config.UI.Menus.Outfits
		local g = FIT.geo
		local cw, ch = g.cw, g.ch
		local b = ST.slab({ Name = "Fit_" .. id, Button = true, Size = { cw, ch }, Color = S.Ink2, T = 0, Z = 4, Parent = FIT.grid })
		local inset = math.floor(ch * g.lean * 0.5 + 0.5)
		local thumbW = cw - 2 * inset - 4
		local thumb = make("ImageLabel", {
			Name = "Thumb",
			BackgroundColor3 = S.Ink,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Image = id == 0 and "" or ("rbxthumb://type=Outfit&id=" .. id .. "&w=150&h=150"),
			ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromOffset(inset + 2, 8),
			Size = UDim2.fromOffset(thumbW, ch - 44),
			ZIndex = 5,
			Parent = b,
		})
		if id == 0 then
			pcall(function()
				thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. game:GetService("Players").LocalPlayer.UserId .. "&w=150&h=150"
			end)
		end
		local label = id == 0 and c.Default or string.upper(name)
		local lsize = g.phone and 11 or 13
		while ST.measure(label, lsize) > cw - inset * 2 and lsize > 9 do
			lsize -= 1
		end
		ST.label({ Name = "Label", Text = label, Size = lsize, Pos = UDim2.new(0, inset, 1, -8), Anchor = Vector2.new(0, 1), Z = 5, Parent = b })
		FIT.names[id] = label
		FIT.cards[id] = b
		b.Activated:Connect(function()
			if FIT.cbs.OnPick then
				FIT.cbs.OnPick(id)
			end
		end)
		return b
	end

	-- the cards for the list now: the ones still wanted kept (a controller's
	-- selection stays put), the rest made or gone, laid out in leaning rows
	function FIT.fillCards()
		local c = Config.UI.Menus.Outfits
		local g = FIT.geo
		local want = FIT.wanted()
		local keep = {}
		for _, w in want do
			keep[w[1]] = true
		end
		for id, card in FIT.cards do
			if not keep[id] then
				card:Destroy()
				FIT.cards[id] = nil
			end
		end
		for i, w in want do
			local card = FIT.cards[w[1]] or FIT.card(w[1], w[2])
			local col, r = (i - 1) % g.cols, (i - 1) // g.cols
			card:SetAttribute("CanvasY", r * (g.ch + c.Gap))
			card:SetAttribute("BaseOff", g.ch)
			card:SetAttribute("XOff", col * (g.cw + c.Gap))
		end
		FIT.grid.CanvasSize = UDim2.fromOffset(0, math.ceil(#want / g.cols) * (g.ch + c.Gap))
		FIT.place()
	end

	-- the line under the cards: "checking your closet..." in marker, anything else a sentence
	function FIT.showStatus()
		if not FIT.status then
			return
		end
		local ST = HUD.ST
		local c = Config.UI.Menus.Outfits
		for _, ch in FIT.status:GetChildren() do
			ch:Destroy()
		end
		local text = FIT.statusText or ""
		FIT.status.Visible = text ~= "" and not FIT.locked
		local sheet = FIT.sheet
		local y = FIT.statusY
		if text == c.Loading then
			local note = ST.note(text, 18, { Name = "Line", Rotation = 3, Z = 5, Parent = FIT.status })
			note.Position = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(y)) + 0.5), math.floor(y - sheet.Top - ST.metrics(18, "Note").Base + 0.5))
		elseif text ~= "" then
			local l = HUD.Menus.text(FIT.status, text, sheet.Phone and 11 or 14, sheet.sx(sheet.lx(y)), y - sheet.Top, { Name = "Line", Role = "Body", T = 0.2, Z = 5 })
			l.Text = text
		end
		FIT.allow.Visible = FIT.askAgain == true
	end

	-- (round 98) locked: the pass over the outfits (price: what its button says)
	function HUD.SetOutfitLocked(locked, price)
		FIT.locked, FIT.price = locked == true, price
		if not FIT.panel then
			FIT.build()
			return
		end
		local lock = FIT.lock
		if not lock then
			return
		end
		lock.Visible = FIT.locked
		if FIT.status then
			FIT.status.Visible = (FIT.statusText or "") ~= "" and not FIT.locked
		end
		local buy = FIT.buy
		if buy then
			for _, ch in buy:GetChildren() do
				if ch.Name == "Amount" or ch.Name == "Robux" then
					ch:Destroy()
				end
			end
			if price then
				local ST = HUD.ST
				local S = Config.UI.Street
				local h = buy.Size.Y.Offset
				local num = ST.numerals(tostring(price), 20, { Name = "Amount", Color = S.Ink, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -math.floor(h * ST.lean() + 10), 0.5, 0), Z = 10, Parent = buy })
				make("ImageLabel", {
					Name = "Robux",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = Config.UI.Images.Robux,
					ImageColor3 = S.Ink,
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(16, 16),
					Position = UDim2.new(1, -(math.floor(h * ST.lean() + 10) + num.Size.X.Offset + 5), 0.5, 0),
					ZIndex = 10,
					Parent = buy,
				})
			end
		end
	end
	function HUD.OutfitLocked()
		return FIT.lock ~= nil and FIT.lock.Visible
	end

	function HUD.ToggleOutfits(force)
		if not FIT.panel then
			FIT.build()
		end
		if not FIT.panel then
			return false
		end
		local ST = HUD.ST
		local was = ST.panelOpen(FIT.panel)
		local open = force
		if open == nil then
			open = not was
		end
		if open and not was then
			HUD.Menus.opened("Outfits")
			if FIT.sheet.Key ~= HUD.Menus.viewKey() then
				FIT.build()
			end
			ST.openPanel(FIT.panel)
			if FIT.cbs.OnOpen then
				FIT.cbs.OnOpen()
			end
		elseif not open and was then
			ST.closePanel(FIT.panel)
			HUD.Menus.closed("Outfits")
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Outfits")
		end
		return open
	end
	HUD.Menus.closers.Outfits = function()
		HUD.ToggleOutfits(false)
	end

	function HUD.OpenOutfits()
		return HUD.ToggleOutfits(true)
	end

	function HUD.OutfitsVisible()
		return FIT.panel ~= nil and HUD.ST.panelOpen(FIT.panel)
	end

	-- the outfits ({ Id, Name } each) and a line under them (asking, none
	-- saved, no access - askAgain shows the button to ask again); the sheet is
	-- made again to fit them
	function HUD.SetOutfitList(list, status, askAgain)
		FIT.list = list or {}
		FIT.statusText = status or ""
		FIT.askAgain = askAgain == true
		-- (the sheet is sized to its cards: made again only when their rows
		-- change, or the screen's shape did)
		if not FIT.panel or not FIT.geo or FIT.sheet.Key ~= HUD.Menus.viewKey() or FIT.rowsFor(FIT.geo.cols) ~= FIT.rows then
			FIT.build()
		else
			FIT.fillCards()
			FIT.showStatus()
			HUD.MarkOutfit(FIT.chosen)
		end
	end

	-- the one you'll wear (0: your own avatar): paper, on your slash; named after AWAKEN IN
	function HUD.MarkOutfit(id)
		FIT.chosen = id or 0
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = Config.UI.Menus.Outfits
		for cid, card in FIT.cards do
			local on = cid == FIT.chosen
			card:SetAttribute("Picked", on)
			ST.paint(card, on and S.Paper or S.Ink2, 0)
			local lab = card:FindFirstChild("Label")
			if lab then
				lab.TextColor3 = on and S.Ink or S.Paper
			end
			local old = card:FindFirstChild("Picked")
			if old then
				old:Destroy()
			end
			if on then
				local s = ST.slash({ Name = "Picked", Size = { card.Size.X.Offset + 30, 30 }, Color = myColor(), Value = 1, Rotation = -3, Z = 3, Pos = UDim2.new(0, -14, 1, -14), Parent = card })
				s:SetAttribute("Under", true)
			end
		end
		local now = FIT.now
		if now and FIT.sheet then
			for _, ch in now:GetChildren() do
				ch:Destroy()
			end
			local sheet = FIT.sheet
			local tsize = sheet.Phone and 26 or 40
			local name = FIT.names[FIT.chosen] or (FIT.chosen == 0 and c.Default or "")
			if name ~= "" then
				local ty = sheet.TitleY
				local x = sheet.lx(ty) + ST.measure(c.Title, tsize) + 16
				local nsize = sheet.Phone and 16 or 22
				local w = ST.measure(name, nsize)
				local s = ST.slash({ Name = "Slash", Size = { math.floor(w + 34), math.floor(nsize * 1.6) }, Color = myColor(), Value = 1, Rotation = -2, Z = 3,
					Pos = UDim2.fromOffset(math.floor(sheet.sx(x - 8) + 0.5), math.floor(ty - nsize * 0.35 - nsize * 0.8 - sheet.Top + 0.5)), Parent = now })
				s:SetAttribute("Hero", true)
				HUD.Menus.text(now, name, nsize, sheet.sx(x), ty - sheet.Top, { Name = "Name", Z = 4 })
			end
			now:SetAttribute("Text", c.Title .. " " .. name)
		end
	end

	---------------------------------------------------------------------------
	-- (round 100) TOP HEROES (mockup 05; L): No.1 across the width on paper
	-- (your slash under it if it's you), No.2 and No.3 on raised ink, 4-10 in
	-- tight zebra rows - the name column fixed at 236 px so a name never runs
	-- into its rank (audit #13); ranks in caps. The ladder on the right, your
	-- rung on your slash; the footer: where you stand, one marker note. A
	-- phone: the ladder is a tab.
	---------------------------------------------------------------------------
	local BD = MS.board
	-- a rank as the board says it: caps, NO.1 tight
	local function boardRank(r, short)
		local s = string.upper((short and r.Short) or r.Name or "")
		return (s:gsub("NO%. 1", "NO.1"))
	end
	BD.rankName = boardRank

	function BD.build()
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = Config.UI.Menus.Top
		local open = boardPanel ~= nil and ST.panelOpen(boardPanel)
		if boardPanel then
			boardPanel:Destroy()
		end
		local sheet = panel("TopHeroes", c.Title1, c.Kicker, { X = c.X, W = c.W, Top = c.Top, Bottom = c.Bottom, Margin = c.Margin, TitleY = c.TitleY }, function()
			HUD.ToggleBoard(false)
		end)
		boardPanel, BD.sheet = sheet.Holder, sheet
		local content = sheet.Content
		local phone = sheet.Phone
		boardRows = {}
		local size = (Config.Leaderboard and Config.Leaderboard.Size) or 10
		if phone then
			-- (a phone: the ten rows scroll between the tabs and the footer)
			BD.listTop, BD.listLeft = 110, 24
			BD.rowsFrame = make("ScrollingFrame", {
				Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
				Position = UDim2.fromOffset(math.floor(sheet.sx(BD.listLeft) + 0.5), BD.listTop - sheet.Top), Size = UDim2.fromOffset(520, 340 - BD.listTop),
				CanvasSize = UDim2.fromOffset(0, 400), ZIndex = 3, Parent = content,
			})
			BD.place = HUD.Menus.leanScroll(BD.rowsFrame, BD.listTop, function(y)
				return sheet.lx(y) - BD.listLeft
			end)
			BD.bar = ST.scrollbar(BD.rowsFrame, { T = 0.3 })
		else
			BD.rowsFrame = make("Frame", { Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		end
		BD.ladderFrame = make("Frame", { Name = "Ladder", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		BD.youFrame = make("Frame", { Name = "You", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		boardMe = BD.youFrame
		-- (a phone: TOP 10 / RANKS as tabs)
		if phone then
			BD.tab = BD.tab or "Board"
			local tx = sheet.lx(100)
			for _, t in { { "Board", "TOP 10" }, { "Ranks", "RANKS" } } do
				local w = ST.measure(t[2], 16)
				local b = make("TextButton", { Name = t[1] .. "Tab", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", Size = UDim2.fromOffset(math.ceil(w) + 4, 24),
					Position = UDim2.fromOffset(math.floor(sheet.sx(tx) + 0.5), 100 - sheet.Top - 19), ZIndex = 4, Parent = content })
				ST.label({ Name = "Label", Text = t[2], Size = 16, Box = UDim2.fromScale(1, 1), Z = 4, Parent = b })
				b.Activated:Connect(function()
					BD.tab = t[1]
					BD.showTab()
				end)
				tx += w + 18
			end
		end
		for i = 1, size do
			boardRows[i] = { Index = i }
		end
		BD.drawRows()
		BD.drawLadder()
		BD.drawMe()
		if phone then
			BD.showTab()
		end
		if open then
			HUD.Menus.reopen(boardPanel)
		end
	end

	function BD.showTab()
		if not (BD.sheet and BD.sheet.Phone) then
			return
		end
		BD.rowsFrame.Visible = BD.tab ~= "Ranks"
		BD.ladderFrame.Visible = BD.tab == "Ranks"
		for _, t in { "Board", "Ranks" } do
			local b = BD.sheet.Content:FindFirstChild(t .. "Tab")
			if b then
				b.Label.TextTransparency = BD.tab == t and 0 or 0.6
			end
		end
	end

	-- the rows: { { UserId, Name, Kills }, ... } best first
	function BD.drawRows()
		local sheet = BD.sheet
		if not sheet then
			return
		end
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Top
		local f = BD.rowsFrame
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
		local phone = sheet.Phone
		local lean = sheet.Lean
		local list = BD.list or {}
		local w = phone and 440 or c.Width
		local function rowFrame(i, y, h)
			local x = sheet.lx(y + h)
			local fr = make("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(math.floor(sheet.sx(x - 6) + 0.5), y - sheet.Top), Size = UDim2.fromOffset(w, h), ZIndex = 3, Parent = f })
			if phone then
				-- (in the scrolling list: placed by its canvas y, leaning as it scrolls)
				fr:SetAttribute("CanvasY", y - BD.listTop)
				fr:SetAttribute("BaseOff", h)
				fr:SetAttribute("XOff", -6)
			end
			return fr, x
		end
		for i, row in boardRows do
			local e = list[i]
			local _, rank = Config.RankOf(e and e.Kills or 0)
			local mine = e ~= nil and e.UserId == BD.me
			local name = e and string.upper(tostring(e.Name or "?")) or "-"
			local rname = e and boardRank(rank, true) or ""
			local kills = e and tostring(e.Kills or 0) or ""
			local fr, x
			if i == 1 then
				local y, h = phone and 112 or 150, phone and 56 or c.First
				fr, x = rowFrame(i, y, h)
				if mine then
					local s = ST.slash({ Name = "Mine", Size = { w - 40, phone and 26 or 34 }, Color = myColor(), Value = 1, Rotation = -1.5, Z = 3, Pos = UDim2.fromOffset(-24, h - 4 - (phone and 13 or 17)), Parent = fr })
					s:SetAttribute("Mine", true)
				end
				ST.slab({ Name = "Slab", Size = { w, h }, Color = S.Paper, T = 0, Z = 4, Parent = fr })
				row.Place = MN.num(fr, "1", phone and 56 or 92, 6 + h * lean + 6, h - 8, { Name = "Place", Color = S.Ink, Z = 5 })
				local nx = phone and 56 or 90
				local nsize = phone and 18 or 28
				while ST.measure(name, nsize) > w - nx - (phone and 90 or 130) and nsize > 14 do
					nsize -= 1
				end
				row.Name = MN.text(fr, name, nsize, nx, phone and 28 or 42, { Name = "PlayerName", Color = S.Ink, Z = 5 })
				row.Rank = MN.text(fr, rname, phone and 11 or 14, nx, phone and 46 or 64, { Name = "Rank", Color = S.Ink, T = 0.4, Z = 5 })
				if mine then
					local tw = ST.measure(rname, phone and 11 or 14)
					local tag = ST.slab({ Name = "YouTag", Size = { 34, 15 }, Pos = UDim2.fromOffset(math.floor(nx + tw + 10), (phone and 46 or 64) - 13), Color = S.Ink, Z = 5, Parent = fr })
					-- ((round 101) the tag's word at the kit's Minimum, 11: 10 went under 9 real px)
					ST.label({ Name = "Label", Text = c.You, Size = S.Sizes.Minimum, AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 6, Parent = tag })
				end
				row.Kills = MN.num(fr, kills, phone and 26 or 38, w - 24, phone and 34 or 56, { Name = "Kills", Color = S.Ink, AlignX = "Right", Z = 5 })
				MN.text(fr, "KO", 12, w - 22 - 8 * lean, phone and 48 or 73, { Name = "KO", Color = S.Ink, T = 0.4, AlignX = "Right", Z = 5 })
			elseif i <= 3 then
				local y, h = (phone and 172 or 252) + (i - 2) * (phone and 44 or 58), phone and 40 or c.Second
				fr, x = rowFrame(i, y, h)
				ST.slab({ Name = "Slab", Size = { w, h }, Color = S.Ink2, T = 0, Z = 4, Parent = fr })
				row.Place = MN.num(fr, tostring(i), phone and 36 or 50, 6 + h * lean + 4, h - 6, { Name = "Place", Z = 5 })
				local nsize = phone and 15 or 21
				while ST.measure(name, nsize) > w - 160 and nsize > 12 do
					nsize -= 1
				end
				row.Name = MN.text(fr, name, nsize, phone and 48 or 62, phone and 21 or 27, { Name = "PlayerName", Z = 5 })
				row.Rank = MN.text(fr, rname, phone and 11 or 12, phone and 48 or 62, phone and 34 or 43, { Name = "Rank", T = 0.5, Z = 5 })
				row.Kills = MN.num(fr, kills, phone and 20 or 26, w - 24, phone and 28 or 36, { Name = "Kills", AlignX = "Right", Z = 5 })
				if mine then
					local s = ST.slash({ Name = "Mine", Size = { 140, 18 }, Color = myColor(), Value = 1, Rotation = -2, Z = 4, Pos = UDim2.fromOffset(phone and 40 or 52, h - 12), Parent = fr })
					s:SetAttribute("Mine", true)
				end
			else
				local y, h = (phone and 262 or 372) + (i - 4) * (phone and 24 or 30), phone and 22 or c.Row
				fr, x = rowFrame(i, y, h)
				if i % 2 == 0 then
					ST.slab({ Name = "Slab", Size = { w, h }, Color = S.Ink2, T = 0, Z = 4, Parent = fr })
				end
				row.Place = MN.num(fr, tostring(i), phone and 14 or 18, 6 + h * lean + 6, h - 5, { Name = "Place", T = 0.25, Z = 5 })
				-- (the name column: 236 px - a 20-letter name fits; longer steps down a size)
				local nsize = phone and 13 or 16
				local col = phone and 170 or c.NameW
				while ST.measure(name, nsize) > col - 8 and nsize > 10 do
					nsize -= 1
				end
				row.Name = MN.text(fr, name, nsize, phone and 40 or 62, h - 7, { Name = "PlayerName", T = 0.1, Z = 5 })
				row.Rank = MN.text(fr, rname, phone and 11 or 12, (phone and 40 or 62) + col, h - 7, { Name = "Rank", T = 0.5, Z = 5 })
				row.Kills = MN.num(fr, kills, phone and 13 or 16, w - 24, h - 6, { Name = "Kills", AlignX = "Right", Z = 5 })
				if mine then
					row.Name.TextTransparency = 0
					local s = ST.slash({ Name = "Mine", Size = { math.floor(ST.measure(name, nsize) + 30), h }, Color = myColor(), Value = 1, Rotation = -2, Z = 4, Pos = UDim2.fromOffset((phone and 40 or 62) - 10, 2), Parent = fr })
					s:SetAttribute("Mine", true)
				end
			end
			row.Row = fr
			if not e then
				row.Name.TextTransparency = 0.7
			end
		end
		if phone then
			f.CanvasSize = UDim2.fromOffset(0, (262 + (#boardRows - 4) * 24 + 26) - BD.listTop)
			BD.place()
			ST.updateScrollbar(BD.bar, f)
		end
	end

	-- the ladder: seven rungs, brighter toward No.1, yours on your slash
	function BD.drawLadder()
		local sheet = BD.sheet
		if not sheet then
			return
		end
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Top
		local f = BD.ladderFrame
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
		local phone = sheet.Phone
		local index = Config.RankOf(myKills)
		local function lxr(y)
			if phone then
				return sheet.lx(y)
			end
			return sheet.rx(y) - c.Ladder
		end
		local y0 = phone and 112 or 182
		local pitch = phone and 34 or c.Rung
		if not phone then
			MN.text(f, c.Ranks, 13, sheet.sx(lxr(150)), 166 - sheet.Top, { Name = "Title", T = 0.5, Z = 3 })
		end
		ladder = {}
		local n = #Config.Ranks
		for k = n, 1, -1 do
			local r = Config.Ranks[k]
			local i = n - k -- (0: the top rung, No.1)
			local y = y0 + i * pitch
			local x = lxr(y + (phone and 28 or 38))
			local rung = make("Frame", { Name = "Rank" .. k, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(math.floor(sheet.sx(x) + 0.5), y - sheet.Top), Size = UDim2.fromOffset(260, pitch), ZIndex = 3, Parent = f })
			local mine = k == index
			if mine then
				local s = ST.slash({ Name = "Mine", Size = { phone and 220 or 262, phone and 36 or 52 }, Color = myColor(), Value = 1, Rotation = -2, Z = 3, Pos = UDim2.fromOffset(-14, (phone and 16 or 22) - (phone and 18 or 26)), Parent = rung })
				s:SetAttribute("Mine", true)
			end
			-- ((round 100 review) brighter toward No.1, as steep as mockup 05: the
			-- bottom rung near ash, its number nearly gone)
			local a = mine and 1 or (1 - i * 0.115)
			MN.text(rung, boardRank(r), (phone and 16) or (i < 2 and 20 or 18), 4, phone and 22 or 28, { Name = "Name", T = 1 - a, Z = 4 })
			MN.num(rung, tostring(r.Kills), phone and 15 or 18, phone and 200 or 236, phone and 22 or 28, { Name = "Kills", T = 1 - a * a * 0.9, AlignX = "Right", Z = 4 })
			MN.text(rung, "+", 12, phone and 202 or 238, phone and 22 or 28, { Name = "Plus", T = 1 - a * 0.6, Z = 4 })
			ladder[k] = { Row = rung }
		end
	end

	-- the footer: YOU, your rank, your KOs, one marker note
	function BD.drawMe()
		local sheet = BD.sheet
		if not sheet then
			return
		end
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Top
		local f = BD.youFrame
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
		local phone = sheet.Phone
		local _, rank, nextRank = Config.RankOf(myKills)
		local fy = phone and 362 or 668
		local x = sheet.lx(fy)
		make("Frame", { Name = "Bar", BackgroundColor3 = S.Paper, BorderSizePixel = 0, Rotation = S.Lean, Size = UDim2.fromOffset(3, phone and 22 or 28),
			Position = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(fy - 9) - 6) + 0.5), fy - (phone and 18 or 22) - sheet.Top), ZIndex = 4, Parent = f })
		local fs = phone and 13 or 16
		MN.text(f, c.You, fs, sheet.sx(x + 6), fy - sheet.Top, { Name = "YouWord", T = 0.4, Z = 4 })
		local rn = boardRank(rank)
		MN.text(f, rn, fs, sheet.sx(x + (phone and 36 or 44)), fy - sheet.Top, { Name = "Rank", Z = 4 })
		local kx = x + (phone and 36 or 44) + ST.measure(rn, fs) + 14
		local kn = MN.num(f, tostring(myKills), phone and 15 or 18, sheet.sx(kx), fy - sheet.Top, { Name = "Kills", Z = 4 })
		MN.text(f, "KO", 12, sheet.sx(kx + kn.Size.X.Offset + 4), fy - sheet.Top, { Name = "KO", T = 0.4, Z = 4 })
		local note = nextRank and string.format(c.NoteNext, nextRank.Kills - myKills, boardRank(nextRank, true)) or c.Note
		local nl = ST.note(note, phone and 14 or 17, { Name = "Note", Rotation = 3, Z = 4, Parent = f })
		nl.Position = UDim2.fromOffset(math.floor(sheet.sx(kx + kn.Size.X.Offset + 38) + 0.5), math.floor(fy - sheet.Top - ST.metrics(phone and 14 or 17, "Note").Base + 0.5))
		f:SetAttribute("Text", c.You .. " " .. rn .. " " .. myKills .. " KO " .. note)
		BD.drawLadder()
	end

	-- TOP HEROES: built once (and again for a phone's own layout)
	function HUD.BuildBoard()
		if boardPanel or not gui then
			return
		end
		BD.build()
		HUD.ST.onLayout(function(phone)
			if BD.sheet and phone ~= BD.sheet.Phone then
				BD.build()
			end
		end)
		HUD.Menus.watch(function()
			if BD.sheet and BD.sheet.Key ~= HUD.Menus.viewKey() then
				BD.build()
			end
		end)
	end

	-- the board's rows: { { UserId, Name, Kills }, ... } best first
	function HUD.SetBoard(list, myUserId)
		BD.list, BD.me = list or {}, myUserId
		if not boardPanel then
			HUD.BuildBoard()
		else
			BD.drawRows()
		end
	end

	function HUD.ToggleBoard(force)
		if not boardPanel then
			HUD.BuildBoard()
		end
		if not boardPanel then
			return false
		end
		local ST = HUD.ST
		local was = ST.panelOpen(boardPanel)
		local open = force
		if open == nil then
			open = not was
		end
		if open and not was then
			HUD.Menus.opened("Board")
			BD.drawMe()
			ST.openPanel(boardPanel)
		elseif not open and was then
			ST.closePanel(boardPanel)
			HUD.Menus.closed("Board")
		end
		if settingsCbs.OnToggle then
			settingsCbs.OnToggle(open, "Board")
		end
		return open
	end
	HUD.Menus.closers.Board = function()
		HUD.ToggleBoard(false)
	end

	function HUD.BoardVisible()
		return boardPanel ~= nil and HUD.ST.panelOpen(boardPanel)
	end

	---------------------------------------------------------------------------
	-- (round 95) RANKED DUELS (Config.Ranked; the server's Kit.RK). The
	-- phone's RANKED app: your tier (its colour, your rating, wins and
	-- losses, placement matches, how far to the next), the ladder of tiers,
	-- the top 10 of every server (ReplicatedStorage.RankedBoard), and FIND A
	-- MATCH / SEARCHING (how long; again to stop) / IN A DUEL. The duel on
	-- screen: the VS card, the scoreboard along the top (both of you, the
	-- round, the clock), each round's calls (ROUND 2 - 3 - 2 - 1 - FIGHT!,
	-- KO!, RING OUT!, TIME!) and the result (VICTORY / DEFEAT / DRAW, the
	-- score, the rating's move, PROMOTED). Everyone else gets a line when a
	-- duel starts and ends. (One local: RKH.)
	---------------------------------------------------------------------------
	local RKH = { rows = {}, ladder = {}, info = {}, cb = {} }
	HUD.RankedHud = RKH
	function RKH.tiers()
		return (Config and Config.Ranked and Config.Ranked.Tiers) or {}
	end
	function RKH.tierOf(rating)
		if Config and Config.RankedTier then
			return Config.RankedTier(rating)
		end
		return 1, { Name = "ROOKIE", Min = 0, Color = Color3.fromRGB(196, 140, 98) }
	end
	function RKH.label(props, parent)
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.ZIndex = props.ZIndex or 62
		props.Parent = parent
		return make("TextLabel", props)
	end

	-- (round 100) the RANKED tab (Stark Street): a sheet like TOP HEROES - your
	-- tier in big words on your slash, your rating in numerals, your record and
	-- how far to the next; the tiers as rungs (yours lit); the top 10 of every
	-- server on the right; FIND A MATCH (paper) / SEARCHING 0:12 - CANCEL /
	-- IN A DUEL at the foot. No tier colours: the slash is the only colour.
	function RKH.build()
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Ranked
		local open = RKH.panel ~= nil and ST.panelOpen(RKH.panel)
		if RKH.panel then
			RKH.panel:Destroy()
		end
		local sheet = panel("RankedDuels", c.Title, c.Kicker, { X = c.X, W = c.W, Top = c.Top, Bottom = c.Bottom, Margin = c.Margin, TitleY = c.TitleY }, function()
			HUD.ToggleRanked(false)
		end)
		RKH.panel, RKH.sheet = sheet.Holder, sheet
		local content = sheet.Content
		local phone = sheet.Phone
		RKH.youFrame = make("Frame", { Name = "You", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		RKH.tiersFrame = make("Frame", { Name = "Tiers", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content })
		RKH.boardFrame = make("Frame", { Name = "Board", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = content, Visible = not phone })
		-- (a phone: YOU / TOP 10 as tabs; the tiers stay on PC - the line under the rating says how far)
		RKH.tabs = nil
		if phone then
			RKH.tab = RKH.tab or "You"
			RKH.tabs = {}
			local tx = sheet.lx(100)
			for _, t in { { "You", "YOU" }, { "Board", "TOP 10" } } do
				local w = ST.measure(t[2], 16)
				local b = make("TextButton", { Name = t[1] .. "Tab", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", Size = UDim2.fromOffset(math.ceil(w) + 4, 24),
					Position = UDim2.fromOffset(math.floor(sheet.sx(tx) + 0.5), 100 - sheet.Top - 19), ZIndex = 4, Parent = content })
				ST.label({ Name = "Label", Text = t[2], Size = 16, Box = UDim2.fromScale(1, 1), Z = 4, Parent = b })
				b.Activated:Connect(function()
					RKH.tab = t[1]
					RKH.showTab()
				end)
				RKH.tabs[t[1]] = b
				tx += w + 18
			end
		end
		-- FIND A MATCH, at the foot
		local by = phone and 322 or 626
		local bw = phone and 260 or 340
		RKH.button = ST.slab({ Name = "Queue", Button = true, Size = { bw, phone and 40 or 52 }, Pos = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(by + (phone and 40 or 52))) + 0.5), by - sheet.Top), Color = S.Paper, T = 0, Z = 4, Parent = content })
		RKH.buttonLabel = ST.label({ Name = "Label", Text = c.Find, Size = phone and 20 or 26, Color = S.Ink, Pos = UDim2.new(0, math.floor((phone and 40 or 52) * sheet.Lean + 14), 0.5, 0), Anchor = Vector2.new(0, 0.5), Z = 5, Parent = RKH.button })
		RKH.buttonTime = ST.numerals("", phone and 18 or 22, { Name = "Time", Color = S.Ink, Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -math.floor((phone and 40 or 52) * sheet.Lean + 14), 0.5, 0), Z = 5, Parent = RKH.button })
		RKH.button.Activated:Connect(function()
			local st = RKH.state
			if st == "Queued" then
				if RKH.cb.Leave then
					RKH.cb.Leave()
				end
			elseif st == "Idle" then
				if RKH.cb.Join then
					RKH.cb.Join()
				end
			end
		end)
		RKH.refresh()
		HUD.SetRankedBoard(RKH.list, RKH.me)
		RKH.showTab()
		if open then
			MN.reopen(RKH.panel)
		end
	end
	function RKH.showTab()
		if not RKH.tabs then
			return
		end
		local you = RKH.tab ~= "Board"
		RKH.youFrame.Visible, RKH.button.Visible, RKH.boardFrame.Visible = you, you, not you
		RKH.tiersFrame.Visible = false
		for id, b in RKH.tabs do
			b.Label.TextTransparency = id == RKH.tab and 0 or 0.6
		end
	end

	function HUD.BuildRanked(cb)
		RKH.cb = cb or RKH.cb
		if RKH.panel or not gui then
			return
		end
		RKH.build()
		HUD.ST.onLayout(function(phone)
			if RKH.sheet and phone ~= RKH.sheet.Phone then
				RKH.build()
			end
		end)
		HUD.Menus.watch(function()
			if RKH.sheet and RKH.sheet.Key ~= HUD.Menus.viewKey() then
				RKH.build()
			end
		end)
	end
	function HUD.ToggleRanked(force)
		if not RKH.panel then
			HUD.BuildRanked()
		end
		if not RKH.panel then
			return false
		end
		local ST = HUD.ST
		local was = ST.panelOpen(RKH.panel)
		local open = force
		if open == nil then
			open = not was
		end
		if open and not was then
			HUD.Menus.opened("Ranked")
			ST.openPanel(RKH.panel)
			RKH.refresh()
		elseif not open and was then
			ST.closePanel(RKH.panel)
			HUD.Menus.closed("Ranked")
		end
		if RKH.cb.OnToggle then
			RKH.cb.OnToggle(open)
		end
		if open and not RKH.clock then
			-- (SEARCHING 0:12: the clock goes round while it's up)
			RKH.clock = RunService.Heartbeat:Connect(function()
				if not (RKH.panel and ST.panelOpen(RKH.panel)) then
					RKH.clock:Disconnect()
					RKH.clock = nil
					return
				end
				if RKH.state == "Queued" and os.clock() - (RKH.tickAt or 0) > 0.25 then
					RKH.tickAt = os.clock()
					RKH.refreshButton()
				end
			end)
		end
		return open
	end
	HUD.Menus.closers.Ranked = function()
		HUD.ToggleRanked(false)
	end
	function HUD.RankedVisible()
		return RKH.panel ~= nil and HUD.ST.panelOpen(RKH.panel)
	end
	function HUD.RankedFirstButton()
		return RKH.button
	end
	-- info = { Rating, Played, Wins, Losses, Queued (server time), Duel }
	function HUD.SetRanked(info)
		RKH.info = info or {}
		RKH.refresh()
	end
	-- the button: FIND A MATCH (paper) / SEARCHING 0:12 CANCEL (raised ink) / IN A DUEL (ink, dim)
	function RKH.refreshButton()
		local b = RKH.button
		if not (b and b.Parent) then
			return
		end
		local ST = HUD.ST
		local S = Config.UI.Street
		local c = Config.UI.Menus.Ranked
		local info = RKH.info
		local size = RKH.sheet and RKH.sheet.Phone and 20 or 26
		local function say(text, color, t, bg, timeText)
			ST.setText(RKH.buttonLabel, text)
			RKH.buttonLabel.Size = UDim2.fromOffset(math.ceil(ST.measure(text, size)) + 2, RKH.buttonLabel.Size.Y.Offset)
			RKH.buttonLabel.TextColor3 = color
			RKH.buttonLabel.TextTransparency = t
			ST.paint(b, bg, 0)
			RKH.buttonTime:SetAttribute("NumColor", color)
			ST.setNumerals(RKH.buttonTime, timeText or "")
		end
		if info.Duel then
			RKH.state = "Duel"
			say(c.Duel, S.Paper, 0.5, S.Ink2)
		elseif info.Queued then
			RKH.state = "Queued"
			local t = math.max(0, math.floor(workspace:GetServerTimeNow() - info.Queued))
			say(c.Cancel, S.Paper, 0, S.Ink2, string.format("%d:%02d", t // 60, t % 60))
			b:SetAttribute("Text", string.format(c.Searching, t // 60, t % 60) .. " " .. c.Cancel)
			return
		else
			RKH.state = "Idle"
			say(c.Find, S.Ink, 0, S.Paper)
		end
		b:SetAttribute("Text", RKH.buttonLabel.Text)
	end
	-- your card, the tiers, the button
	function RKH.refresh()
		if not (RKH.panel and RKH.sheet) then
			return
		end
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Ranked
		local sheet = RKH.sheet
		local phone = sheet.Phone
		local info = RKH.info
		local R = (Config and Config.Ranked) or {}
		local rating = tonumber(info.Rating) or R.Start or 1000
		local played = tonumber(info.Played) or 0
		local idx, tier = RKH.tierOf(rating)
		local tiers = RKH.tiers()
		local f = RKH.youFrame
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
		local col
		pcall(function()
			local q = Config.Quirks[game:GetService("Players").LocalPlayer:GetAttribute("Quirk") or ""]
			col = q and q.Color
		end)
		-- the tier, big, on your slash
		local ty = phone and 146 or 200
		local tname = played > 0 and string.upper(tier.Name) or c.Unranked
		local tsize = phone and 30 or 48
		local x = sheet.lx(ty)
		if played > 0 then
			local s = ST.slash({ Name = "Slash", Size = { math.floor(ST.measure(tname, tsize) + 60), math.floor(tsize * 1.15) }, Color = col or S.Paper, Value = 1, Rotation = -2.5, Z = 3,
				Pos = UDim2.fromOffset(math.floor(sheet.sx(x - 16) + 0.5), math.floor(ty - tsize * 0.3 - tsize * 0.58 - sheet.Top + 0.5)), Parent = f })
			s:SetAttribute("Hero", true)
		end
		RKH.tierName = ST.shadowText({ Name = "Tier", Text = tname, Size = tsize, Shadow = 3, Z = 4, Parent = f })
		RKH.tierName.Position = UDim2.fromOffset(math.floor(sheet.sx(x) + 0.5), math.floor(ty - ST.metrics(tsize).Base - sheet.Top + 0.5))
		-- the rating, the record
		local ry = ty + (phone and 40 or 62)
		local rx0 = sheet.lx(ry)
		RKH.rating = MN.num(f, tostring(rating), phone and 26 or 46, sheet.sx(rx0), ry - sheet.Top, { Name = "Rating", Z = 4 })
		MN.text(f, "RATING", phone and 11 or 13, sheet.sx(rx0 + RKH.rating.Size.X.Offset + 8), ry - sheet.Top, { Name = "RatingWord", T = 0.5, Z = 4 })
		local wy = ry + (phone and 24 or 32)
		local wx = sheet.lx(wy)
		RKH.record = MN.num(f, string.format("%dW %dL", tonumber(info.Wins) or 0, tonumber(info.Losses) or 0), phone and 15 or 20, sheet.sx(wx), wy - sheet.Top, { Name = "Record", Z = 4 })
		MN.text(f, played .. " PLAYED", phone and 11 or 13, sheet.sx(wx + RKH.record.Size.X.Offset + 10), wy - sheet.Top, { Name = "Played", T = 0.5, Z = 4 })
		-- how far to the next: a line and a fill
		local ny = wy + (phone and 22 or 30)
		local nextT = tiers[idx + 1]
		local nextText
		if played < (R.Placement or 10) then
			nextText = string.format(c.Placement, played, R.Placement or 10)
		elseif nextT then
			nextText = string.format(c.ToNext, nextT.Min - rating, string.upper(nextT.Name))
		else
			nextText = c.TopTier
		end
		RKH.next = MN.text(f, nextText, phone and 12 or 14, sheet.sx(sheet.lx(ny)), ny - sheet.Top, { Name = "NextText", T = 0.3, Z = 4 })
		local barY = ny + 8
		local track = ST.slab({ Name = "Next", Size = { phone and 200 or 300, 8 }, Pos = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(barY + 8)) + 0.5), barY - sheet.Top), Color = S.Ink2, T = 0, Z = 4, Parent = f })
		local frac = nextT and math.clamp((rating - tier.Min) / math.max(nextT.Min - tier.Min, 1), 0, 1) or 1
		RKH.fill = ST.fill(track, { Name = "Fill", Color = S.Paper, Value = frac })
		-- the tiers: rungs, the top one first; yours lit
		local tf = RKH.tiersFrame
		for _, ch in tf:GetChildren() do
			ch:Destroy()
		end
		table.clear(RKH.ladder)
		local ly = phone and (barY + 30) or (barY + 44)
		if not phone then
			MN.text(tf, c.Tiers, 13, sheet.sx(sheet.lx(ly)), ly - sheet.Top, { Name = "Title", T = 0.5, Z = 3 })
		end
		local pitch = phone and 20 or 30
		local n = #tiers
		for k = n, 1, -1 do
			local t = tiers[k]
			local i = n - k
			local y = ly + (phone and 4 or 14) + i * pitch
			local mine = k == idx and played > 0
			local rung = make("Frame", { Name = "Tier" .. k, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(math.floor(sheet.sx(sheet.lx(y)) + 0.5), y - sheet.Top), Size = UDim2.fromOffset(260, pitch), ZIndex = 3, Parent = tf })
			if mine then
				local s = ST.slash({ Name = "Mine", Size = { 220, math.floor(pitch * 1.1) }, Color = col or S.Paper, Value = 1, Rotation = -2, Z = 3, Pos = UDim2.fromOffset(-12, math.floor(pitch * 0.42)), Parent = rung })
				s:SetAttribute("Mine", true)
			end
			local a = mine and 1 or (0.85 - i * 0.07)
			MN.text(rung, string.upper(t.Name), phone and 13 or 17, 2, pitch - 4, { Name = "Name", T = 1 - a, Z = 4 })
			MN.num(rung, tostring(t.Min), phone and 13 or 16, 200, pitch - 4, { Name = "Min", T = 1 - a * 0.9, AlignX = "Right", Z = 4 })
			MN.text(rung, "+", 12, 202, pitch - 4, { Name = "Plus", T = 1 - a * 0.6, Z = 4 })
			RKH.ladder[k] = rung
		end
		RKH.refreshButton()
	end
	-- the board's rows: { { UserId, Name, Rating, Tier }, ... } best first
	function HUD.SetRankedBoard(list, myUserId)
		RKH.list, RKH.me = list, myUserId
		if not (RKH.panel and RKH.sheet) then
			return
		end
		local ST = HUD.ST
		local MN = HUD.Menus
		local S = Config.UI.Street
		local c = Config.UI.Menus.Ranked
		local sheet = RKH.sheet
		local f = RKH.boardFrame
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
		table.clear(RKH.rows)
		local size = (Config and Config.Ranked and Config.Ranked.BoardSize) or 10
		local lean = sheet.Lean
		local phone = sheet.Phone
		local function lxr(y)
			return phone and sheet.lx(y) or (sheet.rx(y) - 400)
		end
		if not phone then
			MN.text(f, c.Board, 13, sheet.sx(lxr(166)), 166 - sheet.Top, { Name = "Title", T = 0.5, Z = 3 })
		end
		for i = 1, size do
			local e = list and list[i]
			local y = phone and (112 + (i - 1) * 23) or (182 + (i - 1) * 30)
			local h = phone and 21 or 26
			local x = lxr(y + h)
			local row = make("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(math.floor(sheet.sx(x - 6) + 0.5), y - sheet.Top), Size = UDim2.fromOffset(400, h), ZIndex = 3, Parent = f })
			if i % 2 == 1 then
				ST.slab({ Name = "Slab", Size = { 400, h }, Color = S.Ink2, T = 0, Z = 3, Parent = row })
			end
			local place = MN.num(row, tostring(i), 16, 6 + h * lean + 4, h - 6, { Name = "Place", T = 0.25, Z = 4 })
			local name = e and string.upper(tostring(e.Name or "?")) or "-"
			local nsize = 15
			while ST.measure(name, nsize) > 168 and nsize > 10 do
				nsize -= 1
			end
			local nm = MN.text(row, name, nsize, 44, h - 7, { Name = "Name", T = e and 0.05 or 0.7, Z = 4 })
			local tierText = ""
			if e then
				local _, t = RKH.tierOf(e.Rating or 0)
				tierText = string.upper(t.Name)
			end
			local tl = MN.text(row, tierText, 11, 220, h - 7, { Name = "Tier", T = 0.5, Z = 4 })
			local rt = MN.num(row, e and tostring(e.Rating or 0) or "", 15, 400 - 22, h - 6, { Name = "Rating", AlignX = "Right", Z = 4 })
			if e and e.UserId == myUserId then
				nm.TextTransparency = 0
				local s = ST.slash({ Name = "Mine", Size = { math.floor(ST.measure(name, nsize) + 28), h }, Color = Config.UI.Street.Paper, Value = 1, Rotation = -2, Z = 3, Pos = UDim2.fromOffset(34, 3), Parent = row })
				pcall(function()
					local q = Config.Quirks[game:GetService("Players").LocalPlayer:GetAttribute("Quirk") or ""]
					if q then
						ST.tintSlash(s, q.Color)
					end
				end)
			end
			RKH.rows[i] = { Row = row, Place = place, Name = nm, Tier = tl, Rating = rt }
		end
	end

	---------------------------------------------------------------------------
	-- the duel on screen ((round 100) Stark Street, HUD.MO: the scoreboard in
	-- the status lane - both of you on your heroes' slashes, the score in
	-- numerals, the round and the clock; the calls in numerals that cut in and
	-- out with no ease; the VS and the result on a leaning band)
	---------------------------------------------------------------------------
	function RKH.board()
		return HUD.MO.board()
	end
	function RKH.setScore(me, them)
		HUD.MO.setScore(me, them)
	end
	function RKH.tick()
		HUD.MO.tick()
	end
	-- a big call in the middle of the screen (ROUND 2, 3, 2, 1, FIGHT, K.O.)
	function HUD.RankedCall(text, color, sub, hold)
		if not gui then
			return
		end
		HUD.MO.call(text, color, sub, hold)
	end
	-- the card in the middle: the VS before round 1, the result after the last
	function RKH.showCard(spec)
		return HUD.MO.card(spec)
	end
	function RKH.cardLine(card)
		card = type(card) == "table" and card or {}
		local _, tier = RKH.tierOf(card.Rating or 0)
		return string.format("%s %d", string.upper(tostring(card.Tier or tier.Name)), tonumber(card.Rating) or 0), tier
	end
	-- FOUND: the VS card, the scoreboard up
	function HUD.RankedFound(data)
		local you, opp = data.You or {}, data.Opp or {}
		local youLine = RKH.cardLine(you)
		local oppLine = RKH.cardLine(opp)
		RKH.showCard({
			Kicker = "RANKED DUEL  THE SKY COFFIN",
			Title = "VS",
			Name = opp.Name or "?",
			NameColor = HUD.MO.heroColor(opp.Hero),
			Lines = {
				{ oppLine .. ((opp.Hero and opp.Hero ~= "") and ("   " .. string.upper(tostring(opp.Hero))) or ""), nil, 0.2 },
				{ "YOU   " .. youLine, nil, 0.45 },
				{ "First to 2 rounds. KO, ring out, or more health at the bell.", nil, 0.3, "Body" },
			},
			Hold = ((Config and Config.Ranked and Config.Ranked.Intro) or 2.5) + 0.4,
		})
		local f = RKH.board()
		if f then
			HUD.MO.boardSide("me", you)
			HUD.MO.boardSide("them", opp)
			RKH.round, RKH.ends = 1, nil
			RKH.setScore(0, 0)
			HUD.MO.showBoard(true)
			if not RKH.topConn then
				RKH.topConn = RunService.Heartbeat:Connect(function()
					pcall(RKH.tick)
				end)
			end
		end
	end
	-- a round: ROUND n, then 3 2 1 (FIGHT comes from the server)
	function HUD.RankedRound(data)
		if RKH.board() then
			HUD.MO.showBoard(true)
		end
		RKH.round, RKH.ends = data.Round or 1, nil
		RKH.setScore(data.Me, data.Them)
		local span = math.max(tonumber(data.Countdown) or 3, 0.3)
		local n = math.max(1, math.floor(span + 0.5))
		local step = span / (n + 1)
		local token = {}
		RKH.countToken = token
		HUD.RankedCall("ROUND " .. tostring(data.Round or 1), nil, string.format("%d - %d", data.Me or 0, data.Them or 0), step * 0.8)
		for k = 1, n do
			task.delay(k * step, function()
				if RKH.countToken == token then
					HUD.RankedCall(tostring(n - k + 1), nil, nil, step * 0.7)
				end
			end)
		end
	end
	function HUD.RankedFight(data)
		RKH.countToken = nil
		RKH.round, RKH.ends = data.Round or RKH.round, tonumber(data.Ends)
		RKH.setScore(data.Me, data.Them)
		pcall(RKH.tick) -- ((round 100) the clock at once; Heartbeat keeps it going)
		HUD.RankedCall("FIGHT", nil, nil, 0.6)
	end
	function HUD.RankedRoundEnd(data, myUserId)
		RKH.ends = nil
		RKH.setScore(data.Me, data.Them)
		local how = tostring(data.How or "")
		local mine = data.WinnerId ~= nil and data.WinnerId == myUserId
		local big = (how == "KO" and "K.O.") or (how == "RING OUT" and "RING OUT") or (how == "TIME" and (data.WinnerId and "TIME" or "DRAW")) or how
		local sub = data.Winner and (mine and "YOU TAKE THE ROUND" or (string.upper(tostring(data.Winner)) .. " TAKES THE ROUND")) or "NOBODY TAKES IT"
		HUD.RankedCall(big, nil, sub, 1.4)
	end
	-- the result card (6 s), then the scoreboard comes down
	function HUD.RankedResult(data)
		RKH.countToken, RKH.ends = nil, nil
		if data.Result ~= "Off" then
			local win, draw = data.Result == "Win", data.Result == "Draw"
			local _, tier = RKH.tierOf(data.Rating or 0)
			local d = tonumber(data.Delta) or 0
			local extra = (data.Promoted and "PROMOTED   ") or (data.Demoted and "DEMOTED   ") or ""
			if data.Placement then
				extra ..= string.format("PLACEMENT %d / %d", data.Placement + 0, data.Of or 10)
			end
			local me = game:GetService("Players").LocalPlayer
			RKH.showCard({
				Kicker = "RANKED DUEL" .. (data.How == "LEFT" and "  THEY LEFT" or ""),
				Title = draw and "DRAW" or (win and "VICTORY" or "DEFEAT"),
				-- (a win gets your slash under it)
				Color = win and (HUD.MO.heroColor(me and me:GetAttribute("Quirk")) or accent) or nil,
				Lines = {
					{ string.format("%d - %d   VS %s", data.Me or 0, data.Them or 0, string.upper(tostring(data.Opp or "?"))), 22, 0 },
					{ string.format("%d   %s%d   %s", tonumber(data.Rating) or 0, d >= 0 and "+" or "", d, string.upper(tostring(data.Tier or tier.Name))), nil, 0.2 },
					{ extra, nil, 0.45 },
				},
				Hold = 6,
			})
			if data.Promoted then
				-- ((round 100 review) the new tier on your slash: your hero's colour, the only one)
				HUD.RankedCall(tostring(data.Tier or tier.Name), HUD.MO.heroColor(me and me:GetAttribute("Quirk")) or Config.UI.Street.Paper, "PROMOTED", 1.6)
			end
		end
		task.delay(data.Result == "Off" and 0 or 5, function()
			if RKH.top then
				HUD.MO.showBoard(false)
			end
			if RKH.topConn then
				RKH.topConn:Disconnect()
				RKH.topConn = nil
			end
		end)
	end
	-- everyone else: a duel starting, a duel won (a RANKED toast)
	function HUD.RankedFeed(kind, data, myUserId)
		if kind == "Match" then
			local a, b = data.A or {}, data.B or {}
			if a.UserId == myUserId or b.UserId == myUserId then
				return
			end
			HUD.ST.toast(string.format("%s (%s) VS %s (%s) ON THE SKY COFFIN", tostring(a.Name), tostring(a.Tier), tostring(b.Name), tostring(b.Tier)), "RANKED")
		elseif kind == "Over" then
			if data.Winner then
				HUD.ST.toast(string.format("%s beat %s %s", tostring(data.Winner), tostring(data.Loser), tostring(data.Score or "")), "RANKED")
			else
				HUD.ST.toast(string.format("%s and %s drew", tostring(data.A), tostring(data.B)), "RANKED")
			end
		end
	end

	-- (a controller's first pick in each sheet)
	function HUD.SettingsFirstButton(which)
		if which == "Board" then
			return boardPanel and boardPanel:FindFirstChild("Close", true)
		elseif which == "Outfits" then
			return MS.fit.cards[0]
		end
		local first = settingRows[SETTINGS[1].Key]
		return first and first:FindFirstChild("On") or first
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
	local TOUCH = { on = false, saved = {}, buttons = {}, pad = nil }
	HUD.Touch = TOUCH
	-- name, the move box it wears (slots[i]) or a label. (round 100) Where each
	-- goes is the leaning grid's cell (Config.UI.Hud.Touch.Cells: three rows
	-- round Roblox's jump button, ULT R HIT / 1 2 3 4 / RUN BLOCK DASH, the dev
	-- flight's AIR and LOCK a fourth; FINISH in the top row's free cell). EMOTE
	-- is the top bar's EMOTES tab now (one route). Anything added without a
	-- cell keeps the old way: { name, label, x, y, size } off the jump button.
	TOUCH.LAYOUT = {
		{ "QuirkPunch", "HIT" },
		{ "QuirkAbility1", 1 },
		{ "QuirkAbility2", 2 },
		{ "QuirkAbility3", 3 },
		{ "QuirkExtra", 6 },
		{ "QuirkSpecial", 4 },
		{ "QuirkUlt", "ULT" },
		{ "QuirkDash", 5 },
		{ "QuirkBlock", "BLOCK" },
		{ "QuirkSprint", "RUN" },
		{ "QuirkFinish", "FINISH" },
		-- ((round 92) the lock-on's LOCK is gone: this one's the DEV FLIGHT's
		-- HOVER-LOCK, shown only while he flies - HUD.SetTouchHoverLock)
		{ "QuirkHoverLock", "LOCK" },
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

	-- (round 100) THE TOUCH GRID, Stark Street (spec section 7, mockup 02):
	-- leaning ink slabs in a grid that leans 12 degrees round Roblox's jump
	-- button; verbs (HIT, BLOCK, RUN) in the middle, move names bottom left;
	-- the moves are the move slots themselves (the same hatch and seconds as
	-- PC); RUN on is paper; the ULT button is the meter. The pad sits in the
	-- combat root (a full menu hides it, and TouchSync lets go of its fingers).
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
			Parent = HUD.FH.root or gui,
		})
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
				TOUCH.button(spec)
			end
		end
	end

	-- a named button: a leaning ink slab, its word (FINISH's in RED: someone's
	-- there to finish); ULT is the meter - the hero's colour fills it on the
	-- 12-degree cut, its % top right
	function TOUCH.button(spec)
		local name, word = spec[1], spec[2]
		local TC = Config.UI.Hud.Touch
		local S = Config.UI.Street
		local b = ST.slab({
			Name = "Touch" .. word, Button = true, Size = { 62, 52 }, T = TC.T, Z = 1, Parent = TOUCH.pad,
			Visible = word ~= "FINISH" and name ~= "QuirkHoverLock" and name ~= "QuirkDevFly",
		})
		local shown = (TC.Labels or {})[word] or word
		if word == "ULT" then
			local fill = ST.fill(b, { Name = "Meter", Color = HUD.FH.state.color or S.Paper, Value = 0 })
			local label = ST.label({ Name = "Label", Text = shown, Size = TC.Text.Ult, Anchor = Vector2.new(0, 1), Z = 3, Parent = b })
			local pct = ST.numerals("0", TC.Text.UltPct, { Name = "Pct", Shadow = 1, Anchor = Vector2.new(1, 0), Z = 3, Parent = b })
			TOUCH.ult = { Button = b, Fill = fill, Label = label, Pct = pct }
		else
			ST.label({
				Name = "Label", Text = shown, Size = word == "HIT" and TC.Text.Hit or TC.Text.Verb, Color = word == "FINISH" and S.Red or S.Paper,
				AlignX = "Center", Box = UDim2.fromScale(1, 1), Z = 3, Parent = b,
			})
		end
		TOUCH.buttons[name] = b
		TOUCH.wire(b, name)
		return b
	end

	-- where the grid's cells are measured from (root units): Roblox's jump
	-- button's centre, pushed for its size; and the grid's scale (a tablet's
	-- cells are bigger). (round 100 review: TOUCH.place and the vitals' room
	-- on a narrow phone both ask this)
	function TOUCH.origin()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(812, 375)
		local s = ST.scale()
		local jx, jy, k = TOUCH.metrics()
		local kk = k > 1 and Config.UI.Hud.Touch.Tablet or 1
		-- (the cells were drawn round a phone's 35 px jump button: a bigger one -
		-- a tablet's 60, or a phone's at another scale - pushes them out up-left)
		local jr = (k > 1 and 60 or 35) / s
		local push = -(jr - 35 * kk)
		return (vp.X + jx) / s + push, (vp.Y + jy) / s + push, kk
	end

	-- the left edge of the grid's bottom row (ULT R HIT), root units: what the
	-- phone's vitals beside it must stay left of
	function TOUCH.left()
		local cx, _, kk = TOUCH.origin()
		local TC = Config.UI.Hud.Touch
		local left
		for _, cell in TC.Cells do
			if cell[2] + cell[4] > 0 then
				local x = cx + (cell[1] + TC.Shift[1]) * kk
				left = left and math.min(left, x) or x
			end
		end
		return left
	end

	-- the grid's cells (they follow the screen and Roblox's jump button: a
	-- phone's is 70 px at (-60, -55) from the corner, a tablet's 120 at (-110,
	-- -150) - TOUCH.metrics). Root units: the pad's in the combat root.
	function TOUCH.place()
		if not TOUCH.pad then
			return
		end
		local s = ST.scale()
		local _, _, k = TOUCH.metrics()
		local TC = Config.UI.Hud.Touch
		local cx, cy, kk = TOUCH.origin()
		local TT = TC.Text
		for _, spec in TOUCH.LAYOUT do
			local cell = TC.Cells[spec[1]]
			local x, y, w, h
			if cell then
				x = cx + (cell[1] + TC.Shift[1]) * kk
				y = cy + (cell[2] + TC.Shift[2]) * kk
				w, h = cell[3] * kk, cell[4] * kk
			else
				local size = (spec[5] or 50) * k
				x = cx + ((spec[3] or 0) * k - size / 2) / s
				y = cy + ((spec[4] or 0) * k - size / 2) / s
				w, h = size / s, size / s
			end
			local pos, size = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5)), UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
			if type(spec[2]) == "string" then
				local b = TOUCH.buttons[spec[1]]
				if b then
					b.Position, b.Size = pos, size
					ST.relayout(b)
					-- (a tablet's bigger cells: bigger words)
					local lab = b:FindFirstChild("Label")
					if lab then
						local em = (spec[2] == "HIT" and TT.Hit) or (spec[2] == "ULT" and TT.Ult) or TT.Verb
						lab.TextSize = math.min(ST.textSize(em * kk), 100)
						if spec[2] == "ULT" then
							lab.Size = UDim2.fromOffset(math.ceil(ST.measure(lab.Text, em * kk)) + 2, math.ceil(lab.TextSize))
						end
					end
					local u = TOUCH.ult
					if u and b == u.Button then
						-- (ULT bottom left, its % top right)
						u.Label.Position = UDim2.fromOffset(8, size.Y.Offset - 2)
						HUD.FH.numStyle(u.Pct, nil, nil, math.floor(TT.UltPct * kk + 0.5))
						u.Pct.Position = UDim2.fromOffset(size.X.Offset - 5, HUD.FH.top(TT.UltPct * kk + 4, TT.UltPct * kk))
					end
				end
			else
				local slot = slots[spec[2]]
				if slot and slot.OnPad then
					slot.Frame.Position, slot.Frame.Size = pos, size
					slot.Frame.Visible = (slot.Frame:GetAttribute("NoHero") ~= true) and TOUCH.slotShown(spec[2])
					HUD.FH.placeSlot(slot)
				end
			end
		end
		HUD.FH.touchUlt()
		for _, sc in autoScales do
			sc.Scale = HUD.TouchScale() -- (the surfaces still on the old scaling)
		end
	end

	-- a move cell's shown: R and the 4th only when the hero has them
	function TOUCH.slotShown(i)
		if i == 4 then
			return specialSlot ~= nil and specialSlot.BoundKey ~= nil
		elseif i == 6 then
			return extraSlot ~= nil and extraSlot.BoundKey ~= nil
		end
		return true
	end

	-- a move slot onto the grid (or back into the PC row): the same slot, its
	-- Tap the finger's
	function TOUCH.slot(slot, name, on)
		local f = slot.Frame
		local M = Config.UI.Hud.Moves
		if on then
			if not slot.Wired then
				slot.Wired = true
				TOUCH.wire(slot.Tap, name)
			end
			slot.Tap.Visible = true
			if not slot.OnPad then
				slot.OnPad = true
				f.Parent = TOUCH.pad
			end
		elseif slot.OnPad then
			slot.OnPad = false
			slot.Tap.Visible = false
			f.Parent = HUD.FH.abilities
			f.Position = UDim2.new()
			f.Size = UDim2.fromOffset(slot.W, M.H)
			f:SetAttribute("NoHero", nil)
			if slot == specialSlot or slot == extraSlot then
				f.Visible = slot.BoundKey ~= nil
			else
				f.Visible = true
			end
			HUD.FH.placeSlot(slot)
		end
	end

	function HUD.ApplyTouch(on)
		if not gui then
			return
		end
		TOUCH.build()
		TOUCH.on = on
		HUD.TouchSync()
		-- (round 100) the kit's roots and layouts follow the switch: a phone's
		-- own layout, the slots onto the grid (or back), the pad placed
		ST.refresh()
		HUD.FH.layout(true)
	end

	-- (the buttons step aside while the quirk menu, a full menu or a card
	-- game's up; nothing stays held under a hidden pad)
	function HUD.TouchSync()
		if TOUCH.pad then
			local combat = gui and gui:FindFirstChild("Combat")
			-- ((round 100 review) any full menu or the emote picker once ui_menus'
			-- route is merged: HUD.MenuOpen; until then the heroes)
			local menuUp = HUD.MenuOpen and HUD.MenuOpen() or HUD.MenuVisible()
			local shown = TOUCH.on and not menuUp and not HUD.UnoVisible()
			TOUCH.pad.Visible = shown
			if not shown or (combat and not combat.Visible) then
				TOUCH.releaseAll() -- (round 82: nothing stays held under a hidden pad - leaving touch too)
			end
		end
	end

	-- how much of the cooldown's left: the slot's hatch (the same as PC)
	function HUD.TouchFill(slot, frac)
		if slot and slot.Hatch then
			ST.setHatch(slot.Hatch, math.clamp(frac, 0, 1))
		end
	end

	-- someone to finish: the FINISH button shows
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

	-- RUN is a toggle on a phone: on, it's paper with ink words
	function HUD.SetTouchRun(on)
		local b = TOUCH.buttons.QuirkSprint
		if b then
			local S = Config.UI.Street
			ST.paint(b, on and S.Paper or S.Ink, on and 0 or Config.UI.Hud.Touch.T)
			local lab = b:FindFirstChild("Label")
			if lab then
				lab.TextColor3 = on and S.Ink or S.Paper
			end
			b:SetAttribute("On", on == true)
		end
	end

	-- the ULT button: full, solid hero colour with ink words (HUD.FH.touchUlt)
	function HUD.SetTouchUlt(ready)
		HUD.FH.touchUlt()
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
		HUD.MO.skin(CS.root) -- ((round 100) Stark Street's light touch: ink, BuilderMono, no corners, no emoji)
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
		HUD.SetConsoleOwner(CS.owner, CS.role)
		for _, line in CS.lines do
			HUD.ConsoleLine(line, true)
		end
		HUD.MO.reskin(CS.root) -- ((round 100) what it built after the skin went on: a light touch on all of it)
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

	-- (round 98) role: "OWNER", or staff's "MOD" / "ADMIN" (a tag's powers)
	function HUD.SetConsoleOwner(isOwner, role)
		CS.owner = isOwner == true
		CS.role = CS.owner and (role or CS.role or "OWNER") or nil
		if not CS.box then
			return
		end
		CS.box.TextEditable = CS.owner
		CS.box.PlaceholderText = CS.owner and "Type a command ('help' lists them) - Enter runs it, Up/Down for the last ones, Tab finishes the word"
			or "View only - only the owner of this game can run commands"
		CS.badge.Text = CS.owner and CS.role or "VIEW ONLY"
		CS.badge.BackgroundColor3 = not CS.owner and Color3.fromRGB(80, 80, 92) or (CS.role == "ADMIN" and Color3.fromRGB(200, 60, 60))
			or (CS.role == "MOD" and Color3.fromRGB(50, 120, 210)) or Color3.fromRGB(50, 170, 90)
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
	-- ((round 100) Stark Street: one leaning ink slab, the title on a brush
	-- slash in Discord's blurple - the card's one colour - and the invite on a
	-- paper slab; no rounded glass, no emoji. Taller to keep CLOSE clear)
	local W, TALL, SHORT = 460, 262, 170
	local BLURPLE = Color3.fromRGB(88, 101, 242)
	-- (the spec's INK / PAPER / ASH: Config isn't there yet while this module
	-- loads - it's handed over in HUD's init - so the card's own copies)
	local INK = Color3.fromRGB(12, 12, 13)
	local PAPER = Color3.fromRGB(244, 241, 234)
	local HINT = Color3.fromRGB(142, 140, 135)
	local HOT = PAPER

	function DC.build()
		if DC.root and DC.root.Parent then
			return DC.root
		end
		if not gui then
			return nil
		end
		local ST = HUD.ST
		local root = make("Frame", {
			Name = "DiscordCard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(W, TALL),
			BackgroundTransparency = 1,
			Active = true, -- (clicks on it don't throw punches)
			Visible = false,
			ZIndex = 55,
			Parent = gui,
		})
		DC.scale = make("UIScale", { Name = "Fit", Parent = root })
		-- (a Modal button frees a shift-locked mouse while it's open)
		make("TextButton", { Name = "Modal", Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true, ZIndex = 55, Parent = root })
		ST.slab({ Name = "Back", Size = UDim2.fromScale(1, 1), Color = INK, T = 0.04, Z = 55, Parent = root })
		DC.pill = ST.slash({ Name = "Slash", Size = { 300, 34 }, Color = BLURPLE, Value = 1, Pos = UDim2.fromOffset(34, 22), Z = 56, Parent = root })
		DC.title = ST.label({
			Name = "Title", Text = "", Size = 26, Box = UDim2.new(1, -120, 0, 40), Pos = UDim2.fromOffset(46, 18),
			Color = PAPER, Z = 57, Parent = root,
		})
		DC.title.TextTruncate = Enum.TextTruncate.AtEnd
		DC.line = ST.label({
			Name = "Line", Role = "Body", Text = "", Size = 14, Wrap = true, AlignY = "Top", Box = UDim2.new(1, -84, 0, 40),
			Pos = UDim2.fromOffset(46, 66), Color = PAPER, T = 0.3, Z = 56, Parent = root,
		})
		ST.closeX({ Name = "X", Size = 18, Pos = UDim2.new(1, -38, 0, 36), Z = 57, Parent = root, OnClick = function()
			HUD.HideDiscord()
		end })
		-- the invite: on paper, in a box you can select (and copy) but not type in
		DC.row = ST.slab({ Name = "InviteRow", Size = UDim2.new(1, -60, 0, 50), Pos = UDim2.fromOffset(30, 112), Color = PAPER, T = 0, Z = 56, Parent = root })
		DC.box = make("TextBox", {
			Name = "Invite",
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -150, 1, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			TextEditable = false,
			FontFace = ST.font("Mono"),
			TextSize = math.floor(ST.textSize(17, "Mono") + 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK,
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
		DC.select = ST.button({
			Name = "Select", Kind = "Secondary", Text = "SELECT", Size = { 112, 36 }, TextSize = 16,
			Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -16, 0.5, 0), Z = 57, Parent = DC.row,
		})
		DC.select.Activated:Connect(function()
			if DC.box and DC.invite ~= "" then
				pcall(function()
					DC.box:CaptureFocus()
				end)
				DC.selectAll()
			end
		end)
		DC.hint = ST.label({
			Name = "Hint", Role = "Body", Text = "", Size = 13, Wrap = true, AlignY = "Top", Box = UDim2.new(1, -84, 0, 36),
			Pos = UDim2.fromOffset(46, 172), Color = HINT, Z = 56, Parent = root,
		})
		DC.close = ST.button({
			Name = "Close", Kind = "Primary", Text = "CLOSE", Size = { 150, 38 }, TextSize = 18,
			Anchor = Vector2.new(0.5, 1), Pos = UDim2.new(0.5, 0, 1, -16), Z = 57, Parent = root,
		})
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
		-- ((round 101) on PC the one rule (the size knob); (review) on touch - a
		-- phone, a tablet - as it was, so its buttons don't shrink)
		local base = (HUD.Touch and HUD.Touch.on) and math.clamp(vp.Y / 720, 1, 1.5) or ST.scale()
		DC.scale.Scale = math.min(base, (vp.X - 24) / W, (vp.Y - 24) / h)
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
		if DC.pill and HUD.ST and HUD.ST.tintSlash then
			HUD.ST.tintSlash(DC.pill, color)
		end
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
		root.Visible = true -- ((round 100) snapped in: no pop)
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
			Scale = touchOn and (T.TouchScale or 0.8) or ((vp and vp.Y > 0) and ST.scale() or 1), -- ((round 101) the one rule)
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

	-- FLY on a phone's pad (round 100: AIR, the grid's fourth row): shown to
	-- whoever flies, paper with ink words while he does
	function HUD.SetTouchFly(show, on)
		GP.fly.show, GP.fly.on = show == true, on == true
		local T = HUD.Touch
		local b = T and T.buttons and T.buttons.QuirkDevFly
		if b then
			local S = Config.UI.Street
			b.Visible = GP.fly.show
			ST.paint(b, GP.fly.on and S.Paper or S.Ink, GP.fly.on and 0 or Config.UI.Hud.Touch.T)
			local lab = b:FindFirstChild("Label")
			if lab then
				lab.TextColor3 = GP.fly.on and S.Ink or S.Paper
			end
			b:SetAttribute("On", GP.fly.on)
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
	local GOLD = Color3.fromRGB(255, 196, 92)
	-- the little tag after a box's key (made once a box). (round 100) Oswald,
	-- AIR in ash, CARRY in paper, beside the key letter (the top right is the
	-- seconds')
	function HB.tag(slot)
		local t = HB.tags[slot]
		if t and t.Parent then
			return t
		end
		if not (slot and slot.Frame) then
			return nil
		end
		t = ST.label({ Name = "HawksTag", Text = "AIR", Size = 10, Color = Config.UI.Street.Ash, Visible = false, Z = 5, Parent = slot.Frame })
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
		local FH = HUD.FH
		for i, slot in boxes do
			local tag = slot and HB.tag(slot)
			if tag then
				tag.Visible = (flying or carrying) and not touch
				tag.Text = carrying and "CARRY" or "AIR"
				tag.TextColor3 = carrying and Config.UI.Street.Paper or Config.UI.Street.Ash
				tag.Size = UDim2.fromOffset(math.ceil(ST.measure(tag.Text, 10)) + 2, tag.Size.Y.Offset)
				local k = slot.Key
				tag.Position = UDim2.fromOffset(k.Position.X.Offset + k.Size.X.Offset + 5, k.Position.Y.Offset + math.floor((k.Size.Y.Offset - tag.Size.Y.Offset) / 2 + 1))
			end
			if slot and carrying then
				local m = A.Carry and A.Carry.Moves and A.Carry.Moves[i]
				FH.setName(slot, m and m.Name or "-")
				slot.BoundKey = nil -- (ready, all of them: one follow-up a carry)
			end
		end
		-- R: LAND up there; on his feet his wings' own name (the alt-form view
		-- would name the form R switches to: ON THE WING)
		if quirkName == "FierceWings" and not ult and A and specialSlot and specialSlot.Frame.Visible then
			FH.setName(specialSlot, flying and (A.LandName or "LAND") or (q.Special and q.Special.Name or specialSlot.Raw))
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

---------------------------------------------------------------------------
-- (round 99) GODSPEED on his screen (Config.DevFlight.God; QuirkClient's
-- DevFly.God drives it, VFX.GSX through its hooks). Over the world and under
-- the HUD (the overlay):
--   THE CHARGE - the view tightening: the edges closing in, dark and hot at
--     the rim; arcs of electricity crackling round them, more and longer as
--     it builds; streaks of light rushing in toward the middle (the power
--     drawn into him)
--   AT GODSPEED - the edges blazing: gold and electric blue licking in at
--     the rim, pulsing; arcs crackling now and then
-- HUD.GodBoom: THE BOOM on his screen - a white-out, the shock rings racing
-- out to the edges (white, gold, electric blue), the edges blown wide open.
-- HUD.GodOut: the closing boom - a gold ring and a blue one let go. Built the
-- first time it's wanted; HUD.FlightGod(nil) hides it.
---------------------------------------------------------------------------
do
	local GH = {
		DARK = Color3.fromRGB(26, 14, 6), GOLD = Color3.fromRGB(255, 206, 92), CORE = Color3.fromRGB(255, 250, 236), BLUE = Color3.fromRGB(92, 170, 255),
		arcs = {}, pulls = {}, token = 0, arcAt = 0,
	}
	HUD.GodParts = GH

	function GH.ring(parent, color, size, thickness, transp)
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
	-- four edges, each a gradient from the rim in (rot: the gradient's way)
	function GH.edges(root, name, color, depth, keys)
		local list = {}
		for i, spec in {
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, depth), 90 },
			{ UDim2.fromScale(0, 1 - depth), UDim2.fromScale(1, depth), -90 },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(depth * 0.75, 1), 0 },
			{ UDim2.fromScale(1 - depth * 0.75, 0), UDim2.fromScale(depth * 0.75, 1), 180 },
		} do
			list[i] = make("Frame", {
				Name = name,
				Position = spec[1],
				Size = spec[2],
				BackgroundColor3 = color,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			}, { make("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new(keys) }) })
		end
		return list
	end
	-- the edges sized `depth` of the screen (the view closing in)
	function GH.depth(list, depth)
		for i, e in list do
			if i <= 2 then
				e.Size = UDim2.fromScale(1, depth)
				e.Position = UDim2.fromScale(0, i == 1 and 0 or 1 - depth)
			else
				e.Size = UDim2.fromScale(depth * 0.75, 1)
				e.Position = UDim2.fromScale(i == 3 and 0 or 1 - depth * 0.75, 0)
			end
		end
	end

	function GH.build()
		if GH.root and GH.root.Parent then
			return
		end
		local root = make("Frame", {
			Name = "FlightGod",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = overlayGui,
		})
		-- the view closing in: dark and hot at the rim
		GH.dark = GH.edges(root, "Tight", GH.DARK, 0.3, { NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.6), NumberSequenceKeypoint.new(1, 1) })
		-- the power at the rim: gold (top and left), electric blue (bottom and right)
		GH.glow = GH.edges(root, "Blaze", GH.GOLD, 0.12, { NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		GH.glow[2].BackgroundColor3 = GH.BLUE
		GH.glow[4].BackgroundColor3 = GH.BLUE
		-- arcs of electricity round the edges: four strokes each
		for i = 1, 12 do
			local arc = {}
			for j = 1, 4 do
				arc[j] = make("Frame", {
					Name = "Arc",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = i % 3 == 0 and GH.BLUE or GH.CORE,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = root,
				})
			end
			GH.arcs[i] = arc
		end
		-- streaks of light rushing in toward the middle
		for i = 1, 18 do
			GH.pulls[i] = {
				frame = make("Frame", {
					Name = "Pull",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = i % 3 == 0 and GH.BLUE or GH.GOLD,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = root,
				}),
				a = (i - 1) / 18 * math.pi * 2, ph = i * 0.37 % 1,
			}
		end
		GH.root = root
	end

	-- one arc of electricity: four kinked strokes from (x, y), along `ang`
	-- (screen px), `len` long, `w` thick
	function GH.zap(arc, x, y, ang, len, w, transp)
		local px, py = x, y
		for _, seg in arc do
			local a = ang + (math.random() - 0.5) * 1.6
			local l = len / 4 * (0.6 + 0.8 * math.random())
			local nx, ny = px + math.cos(a) * l, py + math.sin(a) * l
			seg.Position = UDim2.fromOffset((px + nx) / 2, (py + ny) / 2)
			seg.Size = UDim2.fromOffset(l, w)
			seg.Rotation = math.deg(a)
			seg.BackgroundTransparency = transp
			px, py = nx, ny
		end
	end

	-- info: { K = GODSPEED 0..1, Charge = its charge 0..1 }; nil hides it
	function HUD.FlightGod(info)
		if not info then
			if GH.root then
				GH.root.Visible = false
			end
			return
		end
		GH.build()
		local k = math.clamp(tonumber(info.K) or 0, 0, 1)
		local c = math.clamp(tonumber(info.Charge) or 0, 0, 1)
		local t = os.clock()
		GH.root.Visible = true
		local okSize, size = pcall(function()
			return gui.AbsoluteSize
		end)
		size = (okSize and typeof(size) == "Vector2" and size.X > 1) and size or Vector2.new(1280, 720)
		local W, H = math.max(size.X, 1), math.max(size.Y, 1)
		-- the view closing in as it charges (dark, deeper and deeper); at it,
		-- open again - the blaze at the rim
		local tight = c > 0 and k <= 0 and c or 0
		GH.depth(GH.dark, 0.18 + 0.26 * tight)
		for _, e in GH.dark do
			e.BackgroundTransparency = 1 - (0.62 * tight + 0.25 * k)
		end
		local pulse = 0.5 + 0.5 * math.sin(t * 11)
		local blaze = math.max(k * (0.42 + 0.18 * pulse), 0.3 * c)
		for _, e in GH.glow do
			e.BackgroundTransparency = 1 - blaze
		end
		-- the arcs round the edges: more as it builds (at it: now and then)
		if t - GH.arcAt >= 1 / 15 then
			GH.arcAt = t
			local want = math.floor(12 * math.max(c, 0.35 * k) + 0.5)
			for i, arc in GH.arcs do
				if i > want or math.random() < 0.25 then
					for _, seg in arc do
						seg.BackgroundTransparency = 1
					end
				else
					-- (somewhere on the rim, reaching in)
					local side = math.random(1, 4)
					local u = math.random()
					local x = side <= 2 and u * W or (side == 3 and 0 or W)
					local y = side <= 2 and (side == 1 and 0 or H) or u * H
					local inward = math.atan2(H / 2 - y, W / 2 - x)
					GH.zap(arc, x, y, inward, (0.08 + 0.16 * math.max(c, k)) * math.min(W, H) * (0.6 + 0.6 * math.random()), math.random() < 0.3 and 3 or 2, 0.1 + 0.3 * math.random())
				end
			end
		end
		-- the power drawn into him: streaks rushing in to the middle as it charges
		local reach = 0.62 * math.max(W, H)
		for _, p in GH.pulls do
			if c <= 0 or k > 0 then
				p.frame.BackgroundTransparency = 1
			else
				local u = (t * (0.9 + 1.6 * c) + p.ph) % 1
				local r = reach * (1 - u) + 30
				local len = (40 + 120 * c) * (0.5 + 0.5 * (1 - u))
				p.frame.Position = UDim2.fromOffset(W / 2 + math.cos(p.a) * r, H / 2 + math.sin(p.a) * r)
				p.frame.Size = UDim2.fromOffset(len, 2 + math.floor(2 * c))
				p.frame.Rotation = math.deg(p.a)
				p.frame.BackgroundTransparency = 1 - (0.15 + 0.55 * c) * math.sin(math.pi * u)
			end
		end
	end

	-- THE BOOM on his screen: a white-out, three rings racing out to the
	-- edges (white, gold, electric blue), the edges blown open
	function HUD.GodBoom()
		GH.build()
		GH.token += 1
		local holder = make("Frame", {
			Name = "GodBoom",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = overlayGui,
		})
		local white = make("Frame", {
			Name = "WhiteOut",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = GH.CORE,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Parent = holder,
		})
		tween(white, 0.55, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for i, spec in { { Color3.new(1, 1, 1), 0, 2.2, 16 }, { GH.GOLD, 0.04, 2, 12 }, { GH.BLUE, 0.08, 1.8, 9 } } do
			local ring = GH.ring(holder, spec[1], 0.08, spec[4], 0.05)
			task.delay(spec[2], function()
				tween(ring, 0.5, { Size = UDim2.fromScale(spec[3], spec[3]) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				local st = ring:FindFirstChildOfClass("UIStroke")
				if st then
					tween(st, 0.5, { Transparency = 1, Thickness = 2 })
				end
			end)
		end
		task.delay(0.7, function()
			holder:Destroy()
		end)
	end
	-- the closing boom: a gold ring and a blue one let go outward
	function HUD.GodOut()
		local holder = make("Frame", {
			Name = "GodOut",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = overlayGui,
		})
		for i, c in { GH.GOLD, GH.BLUE } do
			local ring = GH.ring(holder, c, 0.4 + 0.06 * i, 4, 0.35)
			tween(ring, 0.4, { Size = UDim2.fromScale(1.5, 1.5) })
			local st = ring:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, 0.4, { Transparency = 1 })
			end
		end
		task.delay(0.5, function()
			holder:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- (round 98) A WARNING FROM THE MODERATORS (the console's warn): a red card
-- in the middle of the screen - what they said, who from - and I
-- UNDERSTAND to put it away (it's gone by itself after a minute)
---------------------------------------------------------------------------
function HUD.ModWarning(text, by)
	-- (round 100) Stark Street (HUD.MO.warn): a leaning ink card over
	-- everything (QuirkWarning), WARNING in red, I UNDERSTAND on paper
	return HUD.MO.warn(text, by)
end

---------------------------------------------------------------------------
-- (round 99) SPACE on this screen (Config.Space.Hud; VFX.SPX drives it
-- through VFX.Hooks.Space): a chip at the top - where you are (UPPER AIR /
-- SPACE / RE-ENTRY) and how high - its bar filling over the climb; OUTER
-- SPACE across the screen the first time you're out (again after Again s
-- back down); the edges glowing orange-red while you burn back in. Over the
-- world, under the HUD. HUD.Space(nil) takes it down. (Its own function:
-- this chunk's locals stay as they are.)
---------------------------------------------------------------------------
;(function()
	local SH = { shownAt = -1e9, downAt = -1e9, wasSpace = false }
	HUD.SpaceParts = SH
	function SH.phone()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		return vp ~= nil and vp.Y > 0 and vp.Y < 520
	end
	-- ((round 100) Stark Street: the chip an ink slab in the status lane - where
	-- you are, how high, a paper line filling over the climb (red burning back
	-- in); the banner a big Oswald word over the moment lane with its sentence.
	-- Everything on QuirkOverlay's scaled root (the one UIScale rule); the burn
	-- at the edges is the screen's own effect and stays.)
	function SH.build()
		if SH.root and SH.root.Parent then
			return
		end
		local root = make("Frame", { Name = "Space", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = ST.rootOf(overlayGui) })
		-- the burn at the edges
		SH.edges = {}
		for i, spec in {
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90 },
			{ UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), -90 },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0 },
			{ UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180 },
		} do
			SH.edges[i] = make("Frame", {
				Name = "Burn",
				Position = spec[1],
				Size = spec[2],
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = root,
			}, {
				make("UIGradient", {
					Rotation = spec[3],
					Color = ColorSequence.new(Color3.fromRGB(255, 70, 24), Color3.fromRGB(255, 176, 70)),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.72), NumberSequenceKeypoint.new(1, 1) }),
				}),
			})
		end
		SH.root = root
		SH.wasPhone = nil
		SH.layout()
	end
	-- the chip and the banner, built for the screen (a phone gets its own sizes)
	function SH.layout()
		local ph = SH.phone()
		local SP = Config.UI.Moments.Space
		local S = Config.UI.Street
		if ph ~= SH.wasPhone or not (SH.chip and SH.chip.Parent) then
			SH.wasPhone = ph
			local shown = SH.chip and SH.chip.Visible
			for _, old in { SH.chip, SH.banner } do
				if old then
					old:Destroy()
				end
			end
			local w, h = ph and SP.PhoneW or SP.W, ph and SP.PhoneH or SP.H
			local l = h * ST.lean()
			local chip = ST.slab({ Name = "Altitude", Size = { w, h }, Color = S.Ink, T = S.HudT, Anchor = Vector2.new(0.5, 0), Z = 2, Visible = shown == true, Parent = SH.root })
			local ws, as = ph and SP.PhoneWhere or SP.Where, ph and SP.PhoneAlt or SP.Alt
			local function top(size)
				return math.floor(h * 0.5 + size * S.Fonts.Display.Cap / 2 - 1 - ST.metrics(size).Base + 0.5)
			end
			SH.where = ST.label({ Name = "Where", Text = "UPPER AIR", Size = ws, Pos = UDim2.fromOffset(math.floor(l + 8), top(ws)), Z = 3, Parent = chip })
			SH.where.Size = UDim2.fromOffset(math.floor(w * 0.55), SH.where.Size.Y.Offset)
			SH.alt = ST.label({ Name = "Alt", Text = "", Size = as, AlignX = "Right", Pos = UDim2.fromOffset(math.floor(w - l - 8), top(as)), Anchor = Vector2.new(1, 0), Z = 3, Parent = chip })
			SH.alt.Size = UDim2.fromOffset(math.floor(w * 0.4), SH.alt.Size.Y.Offset)
			local track = ST.slab({ Name = "Bar", Size = { w - math.floor(2 * l) - 4, 3 }, Color = S.Ink, T = 1, Pos = UDim2.fromOffset(math.floor(l * 0.1) + 2, h - 3), Z = 3, Parent = chip })
			SH.fill = ST.fill(track, { Name = "Fill", Color = S.Paper, Value = 0 })
			SH.chip = chip
			-- the banner: the word, its ink shadow, its sentence, a short paper line
			local ts, ss = ph and SP.PhoneTitle or SP.Title, ph and SP.PhoneSub or SP.Sub
			local banner = make("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(ph and 700 or 1100, 140), BackgroundTransparency = 1, Parent = SH.root })
			local tm = ST.metrics(ts)
			SH.titleShadow = ST.label({ Name = "TitleShadow", Text = "", Size = ts, Color = S.Ink, AlignX = "Center", Box = UDim2.new(1, 0, 0, math.ceil(tm.H)), Pos = UDim2.fromOffset(3, 3), Z = 1, Parent = banner })
			SH.title = ST.label({ Name = "Title", Text = "", Size = ts, AlignX = "Center", Box = UDim2.new(1, 0, 0, math.ceil(tm.H)), Z = 2, Parent = banner })
			SH.title.TextTransparency = 1
			SH.titleShadow.TextTransparency = 1
			local lineY = math.floor(tm.Base + ts * 0.18 + 0.5)
			SH.line = make("Frame", {
				Name = "Line", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, lineY), Size = UDim2.fromOffset(0, 3),
				BackgroundColor3 = S.Paper, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = banner,
			})
			SH.sub = ST.label({ Name = "Sub", Text = "", Role = "Body", Size = ss, AlignX = "Center", Box = UDim2.new(1, 0, 0, math.ceil(ST.metrics(ss, "Body").H)), Pos = UDim2.fromOffset(0, lineY + 8), Z = 2, Parent = banner })
			SH.sub.TextTransparency = 1
			SH.banner = banner
		end
		-- (the chip under whatever else the status lane holds; the banner over the moment lane)
		local _, ox, oy = HUD.MO.frame()
		local y = HUD.MO.statusBelow("space")
		SH.chip.Position = UDim2.fromOffset(ox + (ph and 406 or 640), y)
		SH.banner.Position = UDim2.fromOffset(ox + (ph and 406 or 640), oy + (ph and SP.PhoneBannerY or SP.BannerY) - math.floor(ST.metrics(ph and SP.PhoneTitle or SP.Title).Base * 0.62))
	end
	-- ((round 99) MOONBASE: title / sub - the base's own words over space's)
	-- ((round 100) it cuts in - no fade - stamps, holds, and goes in 0.2 s)
	function SH.showBanner(title, sub)
		local H = (Config.Space or {}).Hud or {}
		SH.token = (SH.token or 0) + 1
		local token = SH.token
		SH.title.Text = title or H.Banner or "OUTER SPACE"
		SH.titleShadow.Text = SH.title.Text
		SH.sub.Text = sub or H.Sub or ""
		SH.title.TextTransparency, SH.titleShadow.TextTransparency, SH.sub.TextTransparency = 0, 0, 0.1
		SH.line.BackgroundTransparency = 0.1
		SH.line.Size = UDim2.fromOffset(SH.phone() and 120 or 220, 3)
		ST.stamp(SH.banner)
		task.delay((H.Hold or 2.2) + 0.6, function()
			if SH.token ~= token then
				return
			end
			for _, l in { SH.title, SH.titleShadow, SH.sub } do
				ST.tween(l, 0.2, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
			end
			ST.tween(SH.line, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		end)
	end
	-- info: { K = the climb 0..1, Space = out there, Alt = studs over the
	-- street, ReEntry = his burn 0..1 }; nil: down, all of it off
	function HUD.Space(info)
		if not info then
			if SH.root then
				SH.chip.Visible = false
				for _, e in SH.edges do
					e.BackgroundTransparency = 1
				end
			end
			if SH.wasSpace then
				SH.downAt = os.clock()
			end
			SH.wasSpace = false
			return
		end
		-- ((round 99 review) never before the HUD's made - a frame with no
		-- parent would be built again every frame - and out of the way
		-- whenever the HUD steps aside: a cut-in, the director's shot)
		if not overlayGui then
			return
		end
		SH.build()
		SH.layout()
		SH.root.Visible = gui == nil or gui.Enabled == true
		local k = math.clamp(tonumber(info.K) or 0, 0, 1)
		local burn = math.clamp(tonumber(info.ReEntry) or 0, 0, 1)
		local now = os.clock()
		local flick = 0.82 + 0.18 * math.sin(now * 31)
		for _, e in SH.edges do
			e.BackgroundTransparency = 1 - 0.62 * burn * flick
		end
		local on = info.Space == true
		-- ((round 100, integration) under a full menu (it hides the combat HUD)
		-- the chip steps aside too: it showed through the shop's sheet)
		local combat = ST.combat and ST.combat()
		local menuUp = combat ~= nil and combat.Visible == false
		SH.chip.Visible = (k > 0.02 or on or burn > 0.05) and not menuUp
		if SH.chip.Visible then
			local alt = math.max(0, tonumber(info.Alt) or 0)
			SH.alt.Text = alt >= 1000 and string.format("ALT %.1fK", alt / 1000) or string.format("ALT %d", math.floor(alt))
			-- ((round 100) RE-ENTRY in red, steady: no flicker)
			local S = Config.UI.Street
			if burn > 0.2 then
				SH.where.Text = "RE-ENTRY"
				SH.where.TextColor3 = S.Red
			else
				-- ((round 99) MOONBASE: Where - the moon base, the drop pod)
				SH.where.Text = type(info.Where) == "string" and info.Where or (on and "SPACE" or "UPPER AIR")
				SH.where.TextColor3 = S.Paper
			end
			local v = on and 1 or k
			if SH.fill:GetAttribute("StValue") ~= v then
				ST.setFill(SH.fill, v)
			end
			local hot = burn > 0.2
			if SH.fill:GetAttribute("Hot") ~= hot then
				SH.fill:SetAttribute("Hot", hot)
				ST.paintFill(SH.fill, hot and S.Red or S.Paper)
			end
		end
		if on and not SH.wasSpace then
			local H = (Config.Space or {}).Hud or {}
			if SH.shownAt < 0 or now - SH.downAt >= (H.Again or 25) then
				SH.shownAt = now
				SH.showBanner(info.Banner, info.BannerSub) -- ((round 99) MOONBASE: the base's own, on it)
			end
		elseif not on and SH.wasSpace then
			SH.downAt = now
		end
		SH.wasSpace = on
	end
end)()

---------------------------------------------------------------------------
-- (round 100, ui_moments) THE MOMENTS, IN STARK STREET: what happens TO you
-- on the screen, built from the kit's parts (HUD.ST) -
--   the ult cut-in: the world black and white, the letterbox snapping in,
--     one huge slash in your hero's colour, the title at +6 degrees breaking
--     into the bottom bar, the shout in marker (HUD.UltBanner);
--   the cutscenes' letterbox and the finishers' title card (HUD.Letterbox);
--   the K.O. screen (HUD.ShowRecap), the KO popup (HUD.KOPopup), rank-ups
--     (HUD.RankUp), callouts (HUD.Callout), NEW HERO (HUD.RosterBanner) - all
--     in the moment lane, one at a time, a K.O. never waiting behind news;
--   TIP toasts for the how-tos (HUD.Tip);
--   ADMIN ABUSE (the cut-in recipe in the event's colour) and its chips in
--     the status lane, EVENTS OVER, HERO SHUFFLE's reel;
--   the ranked duel's scoreboard (status lane), calls and cards;
--   the moderators' warning, the FINISH over a beaten body (HUD.FinishFace),
--     the dev flight's meter, Inasa's titles' look (HUD.StreetTitle), the dev
--     menus' skin (MO.skin).
-- The HUD.* functions that drew these call in here; their contracts are as
-- they were. Numbers: Config.UI.Moments. (Its own function: this chunk's
-- locals stay as they are.)
---------------------------------------------------------------------------
;(function()
	local MO = { asides = {}, laneHolds = {}, barHolds = {}, tips = {}, cutToken = 0, cineToken = 0 }
	HUD.MO = MO
	local V2 = Vector2.new
	local function tk()
		return Config.UI.Street
	end
	local function cf()
		return Config.UI.Moments
	end
	MO.tk, MO.cf = tk, cf

	---------------------------------------------------------------- basics
	-- the root's size in its own units (1280x720 on a 16:9 PC, 812x375 on a phone)
	function MO.size()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		if not vp or vp.X <= 0 or vp.Y <= 0 then
			vp = V2(1280, 720)
		end
		local s = ST.scale()
		return vp.X / s, vp.Y / s
	end
	-- the mockups' frame (1280x720, a phone's 812x375) centred in the root:
	-- phone?, its offset x, y, and the root's w, h
	function MO.frame()
		local phone = ST.isPhone()
		local w, h = MO.size()
		local bw, bh = phone and 812 or 1280, phone and 375 or 720
		return phone, math.floor((w - bw) / 2 + 0.5), math.floor((h - bh) / 2 + 0.5), w, h
	end
	-- a number for this screen: the phone's if there is one
	function MO.pick(t, key)
		if ST.isPhone() and t["Phone" .. key] ~= nil then
			return t["Phone" .. key]
		end
		return t[key]
	end
	-- a label placed by its baseline (x is its left, centre or right: AlignX).
	-- p: Text, Size, Role, Color, T, X, Y, AlignX, Rotation, Shadow, Parent, Z, Name
	function MO.text(p)
		local m = ST.metrics(p.Size, p.Role)
		local ax = (p.AlignX == "Right" and 1) or (p.AlignX == "Center" and 0.5) or 0
		local props = {
			Name = p.Name, Text = p.Text, Size = p.Size, Role = p.Role, Color = p.Color, T = p.T, AlignX = p.AlignX,
			Pos = UDim2.fromOffset(math.floor(p.X + 0.5), math.floor(p.Y - m.Base + 0.5)), Anchor = V2(ax, 0),
			Rotation = p.Rotation, Parent = p.Parent, Z = p.Z, Visible = p.Visible,
		}
		if p.Shadow then
			props.Shadow = p.Shadow
			return ST.shadowText(props)
		end
		return ST.label(props)
	end
	-- numerals placed by their baseline, like MO.text
	function MO.nums(text, size, p)
		local m = ST.metrics(size)
		local ax = (p.AlignX == "Right" and 1) or (p.AlignX == "Center" and 0.5) or 0
		return ST.numerals(text, size, {
			Name = p.Name, Color = p.Color, T = p.T, Shadow = p.Shadow, Z = p.Z, Parent = p.Parent, Visible = p.Visible,
			Pos = UDim2.fromOffset(math.floor(p.X + 0.5), math.floor(p.Y - m.Base + 0.5)), Anchor = V2(ax, 0),
		})
	end
	-- set at once, and stop whatever tween was moving it there (a running one
	-- would go on writing over it)
	function MO.snap(obj, props)
		for k, v in props do
			obj[k] = v
		end
		ST.tween(obj, 0.01, props, Enum.EasingStyle.Linear)
	end
	-- a colour reads as bad news (the old callers' reds)
	function MO.danger(color)
		return typeof(color) == "Color3" and color.R > 0.85 and color.G < 0.62 and color.B < 0.62
	end
	-- a hero's colour by his name or his display name (nil: none)
	function MO.heroColor(name)
		local q = Config.Quirks[name or ""]
		if q then
			return q.Color
		end
		for _, other in Config.Quirks do
			if type(other) == "table" and other.DisplayName == name then
				return other.Color
			end
		end
		return nil
	end
	-- ((round 100 review) a player's hero's colour by his UserId (nil: no hero,
	-- or not in this server)
	function MO.playerColor(userId)
		local ok, p = pcall(function()
			for _, plr in game:GetService("Players"):GetPlayers() do
				if plr.UserId == tonumber(userId) then
					return plr
				end
			end
			return nil
		end)
		return ok and p and MO.heroColor(p:GetAttribute("Quirk")) or nil
	end
	-- the "!" is a character's: anywhere else it's a full stop
	function MO.calm(text)
		return (string.gsub(tostring(text or ""), "!+", "."))
	end

	-- the combat HUD steps aside (counted: a cut-in and a cutscene at once give
	-- it back only when the last lets go)
	function MO.aside(key, on)
		MO.asides[key] = on and true or nil
		if gui then
			gui.Enabled = next(MO.asides) == nil
		end
	end
	-- the moment lane waits (hidden) under a cut-in
	function MO.laneHold(key, on)
		MO.laneHolds[key] = on and true or nil
		if ST.momentLane then
			ST.momentLane.Visible = next(MO.laneHolds) == nil
		end
	end
	-- a moment for the lane, ahead of a less important one that's up now (cut
	-- short: a K.O. never waits behind a NEW HERO). opts: Wait, Over (cut
	-- anything but the K.O. screen)
	function MO.push(kind, build, opts)
		opts = opts or {}
		local P = tk().Moments.Priority
		local mine = P[kind] or 5
		local now = ST.momentNow
		ST.moment(kind, build, opts)
		-- ((round 100 review) opts.Replace: a newer one of the same kind takes over
		-- at once - a second K.O. screen never waits behind the first, to go stale)
		if now and ST.momentNow == now and (now.Prio > mine or (opts.Over and now.Prio > (P.Down or 0)) or (opts.Replace and now.Kind == kind)) then
			if now.holder then
				now.holder:SetAttribute("Cut", true)
			end
			ST.endMoment(now)
		end
	end
	-- the lane's own coordinates: y in the lane from y on the mockup's frame
	function MO.laneY(y)
		local y0 = ST.lane("Moment")
		local _, _, oy = MO.frame()
		return y + oy - y0
	end

	---------------------------------------------------------------- the cinema
	-- QuirkCinema (over the toasts and the moment lane): Under (a cut-in's
	-- slash and streaks), Bars (the letterbox, its title card), Over (a
	-- cut-in's words, which may break into the bars)
	function MO.cinema()
		local root = MO.cineRoot
		if root and root.Parent and root.Parent.Parent then
			return root
		end
		local pg = gui and gui.Parent
		if not pg then
			return nil
		end
		local g
		g, root = ST.screen("QuirkCinema", cf().CinemaOrder, pg)
		g.DisplayOrder = cf().CinemaOrder
		MO.cineGui, MO.cineRoot = g, root
		local function layer(name, z)
			return make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = root })
		end
		MO.under = layer("Under", 1)
		local bars = layer("Bars", 2)
		MO.over = layer("Over", 3)
		local h = MO.barH()
		MO.barTop = make("Frame", {
			Name = "Top", BackgroundColor3 = tk().Ink, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, h),
			Position = UDim2.fromOffset(0, -h), Visible = false, ZIndex = 2, Parent = bars,
		})
		MO.barBottom = make("Frame", {
			Name = "Bottom", BackgroundColor3 = tk().Ink, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, h),
			Position = UDim2.new(0, 0, 1, 0), Visible = false, ZIndex = 2, Parent = bars,
		})
		return root
	end
	function MO.barH()
		local B = cf().Bars
		return ST.isPhone() and B.PhoneH or B.H
	end
	-- the letterbox: in at once (snapped, no tween) while anyone holds it; out
	-- along the screen's edges in Bars.Out when the last lets go
	function MO.bars(key, on)
		if not MO.cinema() then
			return
		end
		MO.barHolds[key] = on and true or nil
		local h = MO.barH()
		MO.barTurn = (MO.barTurn or 0) + 1
		local turn = MO.barTurn
		local top, bottom = MO.barTop, MO.barBottom
		top.Size, bottom.Size = UDim2.new(1, 0, 0, h), UDim2.new(1, 0, 0, h)
		if next(MO.barHolds) then
			top.Visible, bottom.Visible = true, true
			MO.snap(top, { Position = UDim2.fromOffset(0, 0) })
			MO.snap(bottom, { Position = UDim2.new(0, 0, 1, -h) })
			return
		end
		local out = cf().Bars.Out
		ST.tween(top, out, { Position = UDim2.fromOffset(0, -h) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		ST.tween(bottom, out, { Position = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(out + 0.04, function()
			if MO.barTurn == turn and next(MO.barHolds) == nil then
				top.Visible, bottom.Visible = false, false
			end
		end)
	end

	-- THE CUTSCENES' LETTERBOX (VFX.Cinematic, the finishers): the bars, and in
	-- the bottom one the shot's title on a slash in its colour, its line at the
	-- right. The HUD steps aside while it's up. (A cut-in up at the same time
	-- has the bottom bar: the card waits under it.)
	function MO.letterbox(on, title, subtitle, color)
		MO.cineToken += 1
		local token = MO.cineToken
		if not MO.cinema() then
			return
		end
		local old = MO.barBottom:FindFirstChild("Card")
		if on then
			if old then
				old:Destroy()
			end
			MO.aside("cine", true)
			MO.bars("cine", true)
			title, subtitle = tostring(title or ""), tostring(subtitle or "")
			if title == "" and subtitle == "" then
				return
			end
			local L = cf().Letterbox
			local h = MO.barH()
			local w = MO.size()
			local card = make("Frame", {
				Name = "Card", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3,
				Visible = MO.cutUp ~= true, Parent = MO.barBottom,
			})
			local size = MO.pick(L, "Title")
			local x = MO.pick(L, "X")
			local base = math.floor(h * 0.68 + 0.5)
			if title ~= "" then
				local tw = ST.measure(string.upper(title), size)
				ST.slash({
					Name = "Slash", Size = { math.floor(tw + size * 1.6 + 0.5), math.floor(size * 1.15 + 0.5) }, Color = color or tk().Paper,
					Pos = UDim2.fromOffset(x - math.floor(size * 0.35 + 0.5), base - math.floor(size * 0.95 + 0.5)), Value = 1, Z = 3, Parent = card,
				})
				MO.text({ Name = "Title", Text = string.upper(title), Size = size, X = x, Y = base, Shadow = 2, Z = 4, Parent = card })
			end
			if subtitle ~= "" then
				MO.text({
					Name = "Sub", Text = string.upper(subtitle), Size = MO.pick(L, "Sub"), Color = tk().Paper, T = 0.45,
					X = w - x, Y = base, AlignX = "Right", Z = 4, Parent = card,
				})
			end
			return
		end
		if old then
			old:Destroy()
		end
		MO.bars("cine", false)
		task.delay(0.1, function()
			if MO.cineToken == token then
				MO.aside("cine", false)
			end
		end)
	end

	---------------------------------------------------------------- the cut-in
	-- THE CUT-IN (an ult; ADMIN ABUSE): spec { Name, Color, Kicker (over the
	-- title), Title, Shout (marker, the hero's own voice), Line (a sentence, in
	-- the top bar), Who / Tag (the bottom bar, left / right), Pills ({ text }:
	-- the bottom bar, after Who), Hold, Key (its holds) }. f0: B/W and the
	-- bars, no tween; the slash wipes in; the title stamps; the shout lands;
	-- at Hold everything leaves along the lean and the colour comes back.
	-- Returns the frame; it's gone by Hold + Exit.
	-- ((round 101) spec.WipeAt / Wipe / TitleAt / ShoutAt / Exit: its own beats
	-- (an awakening's, Config.Awaken.CutIn), each defaulting to Cut's)
	function MO.cut(spec)
		local root = MO.cinema()
		if not root then
			return nil
		end
		local C = cf().Cut
		MO.cutToken += 1
		local token = MO.cutToken
		for _, old in MO.cutFrames or {} do
			old:Destroy()
		end
		local key = spec.Key or "cut"
		-- (another cut-in still up: it's replaced - its holds go with it unless
		-- they're the same as this one's)
		if MO.cutUp and MO.cutKey and MO.cutKey ~= key then
			ST.mono(false, MO.cutKey)
			MO.bars(MO.cutKey, false)
			MO.aside(MO.cutKey, false)
			MO.laneHold(MO.cutKey, false)
		end
		MO.cutKey = key
		local phone, ox, _, w, h = MO.frame()
		local kx, ky = phone and 812 / 1280 or 1, phone and 375 / 720 or 1
		-- ((round 100 review) the mockup's frame sits on the bottom bar, not in the
		-- middle: on a taller screen (an iPad's 4:3) the title still breaks into it)
		local oy = h - (phone and 375 or 720)
		local function X(x)
			return ox + x * kx
		end
		local function Y(y)
			return oy + y * ky
		end
		local color = spec.Color or tk().Paper
		local name = spec.Name or "Cut"
		local under = make("Frame", { Name = name .. "Under", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = MO.under })
		local over = make("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = MO.over })
		MO.cutFrames = { under, over }
		-- f0: the world black and white, the bars in, the HUD aside, the lane waiting
		-- ((round 100 review) not on a touch screen: the touch pad lives in the HUD,
		-- and a phone mustn't lose its buttons for the 1.7 s after its ULT - or
		-- mid-fight, for an event's 3.3 s - while a keyboard keeps every key)
		ST.mono(true, key)
		MO.bars(key, true)
		MO.aside(key, not (HUD.Touch and HUD.Touch.on == true))
		MO.laneHold(key, true)
		MO.cutUp = true
		local card = MO.barBottom and MO.barBottom:FindFirstChild("Card")
		if card then
			card.Visible = false
		end
		-- the speed streaks: thin paper bars on the slash's angle, uneven (the
		-- mockup's own, from where each starts along its line)
		local a = math.rad(C.StreakRot)
		for i, st in C.StreakList do
			if phone and i > C.PhoneStreaks then
				break
			end
			local len = st[3] * kx
			make("Frame", {
				Name = "Streak" .. i,
				AnchorPoint = V2(0.5, 0.5),
				Position = UDim2.fromOffset(math.floor(X(st[1]) + math.cos(a) * len / 2 + 0.5), math.floor(Y(st[2]) + math.sin(a) * len / 2 + st[4] / 2 + 0.5)),
				Size = UDim2.fromOffset(math.floor(len + 0.5), st[4]),
				Rotation = C.StreakRot,
				BackgroundColor3 = tk().Paper,
				BackgroundTransparency = st[5],
				BorderSizePixel = 0,
				ZIndex = 1,
				Parent = under,
			})
		end
		-- THE slash: the only colour on the screen (under the bars)
		local ss = MO.pick(C, "Slash")
		-- ((round 101) as much longer as the screen is wider than the mockup's
		-- frame: with the size knob there's room either side of it, and the
		-- slash still runs off both edges)
		local sw = ss[1] + math.max(0, w - (phone and 812 or 1280))
		local slash = ST.slash({
			Name = "Slash", Size = { sw, ss[2] }, Color = color, Value = 0, Rotation = C.SlashRot, Anchor = V2(0.5, 0.5),
			Pos = UDim2.fromOffset(math.floor(X(C.SlashPos[1]) + 0.5), math.floor(Y(C.SlashPos[2]) + 0.5)), Z = 2, Parent = under,
		})
		-- the kicker and the title, on the same rise (over the bars)
		local tsize = MO.pick(C, "Title")
		local title = string.upper(tostring(spec.Title or ""))
		local room = MO.pick(C, "Room")
		local tw = ST.measure(title, tsize)
		if tw > room then
			tsize = math.max(math.floor(tsize * room / tw), MO.pick(C, "TitleMin"))
			tw = ST.measure(title, tsize)
		end
		local tm = ST.metrics(tsize)
		local tcx, tby = X(C.TitlePos[1]), Y(C.TitlePos[2])
		local titleLabel = ST.shadowText({
			Name = spec.TitleName or "Title", Text = title, Size = tsize, Shadow = MO.pick(C, "TitleShadow"), Rotation = C.TextRot, Anchor = V2(0.5, 0),
			Pos = UDim2.fromOffset(math.floor(tcx + 0.5), math.floor(tby - tm.Base + 0.5)), Z = 4, Visible = false, Parent = over,
		})
		-- (the kicker over the title's left end: lower than its middle, on the rise)
		local ksize = MO.pick(C, "Kicker")
		local rise = math.tan(math.rad(-C.TextRot))
		local kicker = MO.text({
			Name = "Kicker", Text = string.upper(tostring(spec.Kicker or "")), Size = ksize, Shadow = phone and 2 or 3, Rotation = C.TextRot, -- ((round 100 review) 3 px muddied a phone's 16)
			X = math.max(tcx - tw / 2 + tsize * 0.08, X(24)),
			Y = tby - tsize * tk().Fonts.Display.Cap + (tw / 2 - tsize * 0.1) * rise - ksize * 1.27,
			Z = 4, Visible = false, Parent = over,
		})
		-- the shout: marker, in his own voice; two lines when it's long (the
		-- second set off to the right, as written by hand)
		local shoutLabels = {}
		if spec.Shout and spec.Shout ~= "" then
			local s = tostring(spec.Shout)
			local lines = { s }
			if #s > C.ShoutBreak then
				local best
				for i = 2, #s - 1 do
					if string.sub(s, i, i) == " " and (not best or math.abs(i - #s / 2) <= math.abs(best - #s / 2)) then
						best = i
					end
				end
				if best then
					lines = { string.sub(s, 1, best - 1), string.sub(s, best + 1) }
				end
			end
			local size = MO.pick(C, "Shout")
			local step = ST.textSize(size, "Note") * C.ShoutLine
			for i, line in lines do
				-- (ShoutPos: the first line's middle; the next one down a line and along)
				local dx = (i - 1) * C.ShoutStagger * kx
				local cx, cy = X(C.ShoutPos[1]) + dx, Y(C.ShoutPos[2]) + (i - 1) * step
				table.insert(shoutLabels, ST.shadowText({
					Name = "Shout" .. i, Text = line, Role = "Note", Size = size, Shadow = 3, Rotation = C.TextRot,
					Anchor = V2(0.5, 0.5), Pos = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(cy + 0.5)), Z = 5, Visible = false, Parent = over,
				}))
			end
		end
		-- a sentence in the top bar (ADMIN ABUSE's blurb)
		local bh = MO.barH()
		if spec.Line and spec.Line ~= "" then
			MO.text({
				Name = "Line", Text = MO.calm(spec.Line), Role = "Body", Size = MO.pick(C, "Line"), X = w / 2, Y = bh * 0.62,
				AlignX = "Center", Z = 4, Parent = over,
			})
		end
		-- the bottom bar: whose it is, what it is
		local who = MO.pick(C, "Who")
		local by = h - bh + bh * 0.6
		local x = MO.pick(C, "WhoX")
		if spec.Who and spec.Who ~= "" then
			local l = MO.text({ Name = spec.WhoName or "Who", Text = string.upper(tostring(spec.Who)), Size = who, T = 0.1, X = x, Y = by, Z = 4, Parent = over })
			x += l.Size.X.Offset + who * 1.2
		end
		for _, pill in spec.Pills or {} do
			local l = MO.text({ Name = "Pill", Text = string.upper(tostring(pill)), Size = who, T = 0.1, X = x, Y = by, Z = 4, Parent = over })
			x += l.Size.X.Offset + who * 1.2
		end
		if spec.Tag and spec.Tag ~= "" then
			MO.text({ Name = "Tag", Text = string.upper(tostring(spec.Tag)), Size = who, T = 0.55, X = w - MO.pick(C, "WhoX"), Y = by, AlignX = "Right", Z = 4, Parent = over })
		end
		-- the beats: the slash wipes in (f2), the title stamps, the shout lands
		local exit = tonumber(spec.Exit) or C.Exit
		local gone = false -- ((round 101) out early - MO.cutOff: no beat after it)
		task.delay(tonumber(spec.WipeAt) or C.WipeAt, function()
			if MO.cutToken == token and not gone then
				ST.setSlash(slash, 1, tonumber(spec.Wipe) or C.Wipe)
			end
		end)
		task.delay(tonumber(spec.TitleAt) or C.TitleAt, function()
			if MO.cutToken == token and not gone then
				titleLabel.Visible, kicker.Visible = true, true
				ST.stamp(titleLabel)
			end
		end)
		task.delay(tonumber(spec.ShoutAt) or C.ShoutAt, function()
			if MO.cutToken == token and not gone then
				for _, l in shoutLabels do
					l.Visible = true
				end
			end
		end)
		-- the streaks drift along their line while it holds
		local hold = spec.Hold or C.Hold
		for _, s in under:GetChildren() do
			if string.sub(s.Name, 1, 6) == "Streak" then
				local d = C.Drift * kx
				ST.tween(s, hold, { Position = s.Position + UDim2.fromOffset(-math.floor(d * math.cos(a) + 0.5), -math.floor(d * math.sin(a) + 0.5)) }, Enum.EasingStyle.Linear)
			end
		end
		-- out: everything along the lean, the colour back, the bars away
		-- ((round 101) or now: MO.cutOff - an awakening called off mid-way)
		local function out()
			if MO.cutToken ~= token or gone then
				return
			end
			gone = true
			local dx = -(w + 400)
			local dy = -dx * ST.lean()
			for _, layerFrame in { under, over } do
				ST.tween(layerFrame, exit, { Position = UDim2.fromOffset(dx, dy) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			end
			ST.mono(false, key)
			MO.bars(key, false)
			task.delay(exit + 0.02, function()
				under:Destroy()
				over:Destroy()
				if MO.cutToken ~= token then
					return
				end
				MO.cutUp = false
				local c = MO.barBottom and MO.barBottom:FindFirstChild("Card")
				if c then
					c.Visible = true
				end
				MO.aside(key, false)
				MO.laneHold(key, false)
			end)
		end
		MO.cutOut = out
		task.delay(hold, out)
		return over, under
	end
	-- ((round 101) the cut-in up now with this Key leaves at once, the way it
	-- would at its Hold (an awakening called off: dead, another hero)
	function MO.cutOff(key)
		if MO.cutUp and MO.cutKey == (key or "ult") and MO.cutOut then
			MO.cutOut()
		end
	end

	-- the ult's: your hero's colour, his name, the ult's name, his shout, yours
	-- ((round 101) beats: { WipeAt, Wipe, TitleAt, ShoutAt, Hold, Exit } - the
	-- awakening's, from its hit; nil: the cut-in's own)
	function MO.ult(view, shout, beats)
		if type(view) ~= "table" then
			return nil
		end
		beats = type(beats) == "table" and beats or {}
		local me = game:GetService("Players").LocalPlayer
		return MO.cut({
			Name = "UltCut",
			Key = "ult",
			Color = view.Color or accent,
			Kicker = view.DisplayName or "",
			Title = view.ModeName or "ULT",
			Shout = shout,
			Who = me and me.Name or "",
			Tag = "ULT",
			WipeAt = beats.WipeAt, Wipe = beats.Wipe, TitleAt = beats.TitleAt, ShoutAt = beats.ShoutAt, Hold = beats.Hold, Exit = beats.Exit,
		})
	end

	---------------------------------------------------------------- the lane
	-- a leaning band across the lane (the K.O. screen's, the KO popup's...):
	-- x, y, w, h on the mockup's frame; returns the slab (its target position
	-- set, ready to slide in)
	-- (rootX: x is the root's own, for a band across the whole screen)
	function MO.band(lane, name, x, y, w, h, t, rootX)
		local _, ox = MO.frame()
		local band = ST.slab({
			Name = name, Size = { math.floor(w + 0.5), math.floor(h + 0.5) }, Color = tk().Ink, T = t or 0.06,
			Pos = UDim2.fromOffset(math.floor((rootX and 0 or ox) + x + 0.5), math.floor(MO.laneY(y) + 0.5)), Z = 2, Parent = lane,
		})
		band:SetAttribute("At", band.Position)
		return band
	end
	-- ((round 100 review) the width of a band from 80 left of the screen: across
	-- it on a PC; on a phone its foot ends at PhoneClear (the mockup frame's x),
	-- clear of the touch grid - a band the player can't see his buttons through
	-- for 3 s mid-fight is a band too far)
	function MO.bandW(w, ox, h)
		if ST.isPhone() then
			return math.floor(80 + ox + cf().PhoneClear + h * ST.lean() + 0.5)
		end
		return w + 160
	end

	-- THE K.O. SCREEN (you went down): the world black and white and dimmed, one
	-- leaning band never taller than 40% of the screen - K.O. in red, who did it
	-- on their hero's slash, how much they had left, four numbers, BACK IN with
	-- the digit stepping once a second; your totals under it. data: HUD.ShowRecap's.
	function MO.down(data)
		data = type(data) == "table" and data or {}
		local D = cf().Down
		local shown = (Config.Fights and Config.Fights.RecapTime) or 5
		MO.push("Down", function(lane)
			local phone, ox, _, w = MO.frame()
			local L = phone and D.Phone or D.Pc
			local holder = make("Frame", { Name = "Recap", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = lane })
			-- the world: black and white, a little darker
			ST.mono(true, "down")
			local dim = make("Frame", {
				Name = "RecapDim", BackgroundColor3 = tk().Ink, BackgroundTransparency = 1, BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = lane.Parent and lane.Parent.Parent,
			})
			ST.tween(dim, D.In, { BackgroundTransparency = D.Dim }, Enum.EasingStyle.Linear)
			-- the band, sliding in along the lean
			local band = MO.band(holder, "Band", -80, L.Top, w + 160, L.Bottom - L.Top, D.BandT, true)
			ST.slideIn(band, band:GetAttribute("At"), D.Slide, cf().Slide)
			-- (the band's own x for the mockup frame's x: it starts 80 left of the screen)
			local function X(x)
				return x + ox + 80
			end
			local top = L.Top
			local function BY(y)
				return y - top
			end
			local z = band.ZIndex + 1
			-- K.O.: the one time red is big
			local ko = MO.nums("K.O.", L.K, { Name = "KO", Color = tk().Red, X = X(L.KX), Y = BY(L.KY), Z = z, Visible = false, Parent = band })
			-- who did it: their name on their hero's slash, their hero, what they had left
			local who = { ko }
			if data.Killer then
				local q = Config.Quirks[data.KillerQuirk or ""]
				local name = string.upper(tostring(data.Killer))
				local nw = ST.measure(name, L.Name)
				table.insert(who, MO.text({ Name = "By", Text = "BY", Size = L.By, T = 0.5, X = X(L.InfoX + 4), Y = BY(L.ByY), Z = z, Parent = band }))
				table.insert(who, ST.slash({
					Name = "KillerSlash", Size = { math.floor(nw + L.Name * 1.75 + 0.5), math.floor(L.Name + 0.5) },
					Color = q and q.Color or tk().Ash, Value = 1, Rotation = D.SlashRot,
					Pos = UDim2.fromOffset(math.floor(X(L.InfoX - L.Name * 0.35) + 0.5), math.floor(BY(L.NameY) - L.Name * 0.62 + 0.5)), Z = z, Parent = band,
				}))
				table.insert(who, MO.text({ Name = "Killer", Text = name, Size = L.Name, Shadow = 3, X = X(L.InfoX), Y = BY(L.NameY), Z = z + 1, Parent = band }))
				if q then
					table.insert(who, MO.text({
						Name = "KillerHero", Text = string.upper(q.DisplayName or ""), Size = L.Hero, T = 0.4,
						X = X(L.InfoX + nw + L.Name * 1.75), Y = BY(L.NameY), Z = z, Parent = band,
					}))
				end
				if data.KillerHealth then
					table.insert(who, MO.text({
						Name = "Left", Text = string.format("they had %d HP left.", math.floor(tonumber(data.KillerHealth) or 0)), Role = "Body",
						Size = L.Line, T = 0.25, X = X(L.InfoX + 2), Y = BY(L.LineY), Z = z, Parent = band,
					}))
				end
			else
				table.insert(who, MO.text({ Name = "Nobody", Text = "nobody gets this one.", Role = "Body", Size = L.Nobody, T = 0.15, X = X(L.InfoX + 2), Y = BY(L.NameY), Z = z, Parent = band }))
			end
			for _, o in who do
				o.Visible = false
			end
			-- four numbers, not eight
			local stats = {
				{ "DAMAGE", data.Dealt }, { "HITS", data.Hits }, { "BIGGEST HIT", data.BiggestHit }, { "STREAK LOST", data.StreakEnded },
			}
			local cells = {}
			for i, s in stats do
				local sx = L.StatX + (i - 1) * L.StatStep
				local n = MO.nums(tostring(math.floor(tonumber(s[2]) or 0)), L.Stat, { Name = "Stat" .. i, X = X(sx), Y = BY(L.StatY), Z = z, Visible = false, Parent = band })
				local l = MO.text({ Name = "StatLabel" .. i, Text = s[1], Size = L.StatLabel, T = 0.45, X = X(sx + 2), Y = BY(L.StatLabelY), Z = z, Visible = false, Parent = band })
				table.insert(cells, { n, l })
			end
			-- back in... (at the screen's right)
			local backX = w - L.Right + 80
			MO.text({ Name = "BackIn", Text = "BACK IN", Size = L.By, T = 0.5, X = backX, Y = BY(L.ByY), AlignX = "Right", Z = z, Parent = band })
			local digit = MO.nums(tostring(math.ceil(shown)), L.Back, { Name = "Back", X = backX, Y = BY(L.BackY), AlignX = "Right", Z = z, Parent = band })
			-- your totals, small, under the band
			if data.TotalKOs or data.BestStreak then
				MO.text({
					Name = "Totals", Text = string.format("%d KOs ALL TIME.  BEST STREAK %d.", data.TotalKOs or 0, data.BestStreak or 0),
					Size = L.Totals, T = 0.25, X = ox + (phone and 406 or 640), Y = MO.laneY(L.TotalsY), AlignX = "Center", Z = 2, Parent = holder,
				})
			end
			-- K.O. cuts in as the band lands, then the numbers one by one
			task.delay(D.Slide, function()
				if holder.Parent then
					for _, o in who do
						o.Visible = true
					end
				end
			end)
			for i, c in cells do
				task.delay(D.Slide + i * D.Step, function()
					if holder.Parent then
						c[1].Visible, c[2].Visible = true, true
					end
				end)
			end
			-- the digit steps once a second ((round 100 review) whole seconds, whatever RecapTime is)
			for k = 1, math.ceil(shown) - 1 do
				task.delay(k, function()
					if holder.Parent then
						ST.setNumerals(digit, tostring(math.ceil(shown - k)))
					end
				end)
			end
			-- and out the way it came, as its time's up
			task.delay(math.max(shown - D.Out, 0), function()
				if holder.Parent then
					ST.slideOut(band, band:GetAttribute("At"), D.Out, cf().Slide)
					ST.tween(dim, D.Out, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
				end
			end)
			return shown, function()
				ST.mono(false, "down")
				dim:Destroy()
			end
		end, { Wait = tk().Moments.Wait.Down, Replace = true })
	end

	-- THE KO POPUP (you landed a KO): the short version - K.O. in red on a short
	-- band, who, and what it got you. data: HUD.KOPopup's.
	function MO.koPop(data)
		data = type(data) == "table" and data or {}
		local P = cf().KO
		local hold = data.Callout and P.HoldCallout or P.Hold
		MO.push("KO", function(lane)
			local phone, ox, _, w = MO.frame()
			local L = phone and P.Phone or P.Pc
			local holder = make("Frame", { Name = "KOPopup", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = lane })
			local big = data.Finisher and "FINISHED" or "K.O."
			local red = data.Finisher or data.Counted or data.Farmed
			local bw = ST.measure(big, L.K)
			-- the lines to its right
			local lines = { { string.upper(tostring(data.Victim or "?")), L.Name, 0 } }
			local gains = {}
			if data.Farmed then
				table.insert(lines, { "SAME GUY TWICE. NO BUCKS.", L.Line, 0.1 }) -- (round 97: Config.AntiExploit.Farm)
			else
				if data.Bucks and data.Bucks > 0 then
					table.insert(gains, string.format("+%d %s", data.Bucks, data.Bucks == 1 and "BUCK" or "BUCKS"))
				end
				if data.Heal and data.Heal > 0 then
					table.insert(gains, string.format("+%d HP", data.Heal))
				end
				if #gains > 0 then
					table.insert(lines, { table.concat(gains, "   "), L.Line, 0 })
				end
			end
			if data.Counted and (data.Streak or 0) >= 2 then
				table.insert(lines, { string.format("STREAK %d%s", data.Streak, data.Callout and ("  " .. string.upper(tostring(data.Callout))) or ""), L.Small, 0.4 })
			end
			local lw = 0
			for _, l in lines do
				lw = math.max(lw, ST.measure(l[1], l[2]))
			end
			local hgt = L.H
			local l = hgt * ST.lean()
			local width = math.floor(l + L.Pad + bw + L.Gap + lw + L.Pad + l + 0.5)
			local x = (phone and 406 or 640) - width / 2
			local band = MO.band(holder, "Band", x, L.Y, width, hgt, P.BandT)
			local z = band.ZIndex + 1
			MO.nums(big, L.K, { Name = "Big", Color = red and tk().Red or tk().Paper, X = l + L.Pad, Y = L.KBase, Z = z, Parent = band })
			local ly = L.FirstY
			for i, line in lines do
				MO.text({ Name = i == 1 and "Victim" or ("Line" .. i), Text = line[1], Size = line[2], T = line[3], X = l + L.Pad + bw + L.Gap - (i - 1) * L.Lean, Y = ly, Z = z, Parent = band })
				ly += L.Step
			end
			band.Visible = true
			ST.slideIn(band, band:GetAttribute("At"), cf().KO.In, cf().Slide)
			return hold
		end)
	end

	-- RANK UP (yours): RANK UP, the new rank on your slash ((round 100 review)
	-- color: your hero's - nil, none picked: ash), how far to the next in
	-- marker. A 1.2 s moment.
	function MO.rankUp(data, color)
		local rank = Config.Ranks[data.Index or 1] or Config.Ranks[1]
		local nextRank = Config.Ranks[(data.Index or 1) + 1]
		local R = cf().RankUp
		MO.push("RankUp", function(lane)
			local phone = MO.frame()
			local L = phone and R.Phone or R.Pc
			local holder = make("Frame", { Name = "RankUp", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = lane })
			local name = string.upper(rank.Name)
			local nw = ST.measure(name, L.Name)
			local note = nextRank and string.format("next: %d KO", nextRank.Kills) or "nobody's above you."
			local width = math.floor(math.max(nw + L.Pad * 2 + L.H * ST.lean() * 2 + L.NoteW, L.MinW) + 0.5)
			local x = (phone and 406 or 640) - width / 2
			local band = MO.band(holder, "Band", x, L.Y, width, L.H, R.BandT)
			local z = band.ZIndex + 1
			local l = L.H * ST.lean()
			MO.text({ Name = "Label", Text = "RANK UP", Size = L.Kicker, T = 0.45, X = l + L.Pad, Y = L.KickerY, Z = z, Parent = band })
			ST.slash({
				Name = "Slash", Size = { math.floor(nw + L.Name * 1.2 + 0.5), math.floor(L.Name * 1.05 + 0.5) }, Color = color or tk().Ash, Value = 0,
				Pos = UDim2.fromOffset(math.floor(l * 0.4 + L.Pad - L.Name * 0.3 + 0.5), math.floor(L.NameY - L.Name * 0.78 + 0.5)), Z = z, Parent = band,
			})
			local slash = band:FindFirstChild("Slash")
			ST.setSlash(slash, 1, tk().Motion.SlashPaint)
			MO.text({ Name = "RankName", Text = name, Size = L.Name, X = l * 0.4 + L.Pad, Y = L.NameY, Z = z + 1, Parent = band })
			ST.note(note, L.Note, { Name = "Next", Pos = UDim2.fromOffset(math.floor(width - l - L.Pad + 0.5), math.floor(L.NoteY + 0.5)), Anchor = V2(1, 1), Z = z, Parent = band })
			ST.slideIn(band, band:GetAttribute("At"), cf().KO.In, cf().Slide)
			return R.Hold
		end)
	end

	-- a rank-up in the kill feed: NAME, a slash in his hero's colour ((round 100
	-- review) color: as a KO row's - nil: ash), THE RANK (yours inverted: a
	-- paper slab, YOU). parent: the feed's list.
	function MO.rankRow(parent, who, rank, mine, color)
		if not parent then
			return nil
		end
		color = color or tk().Ash
		-- (the combat HUD's own feed row when it has one - HUD.FH.feedRow, ui_hud's -
		-- so a rank-up reads exactly like a KO; this stream's own row otherwise)
		local FH = HUD.FH
		if FH and type(FH.feedRow) == "function" then
			local ok, row = pcall(FH.feedRow, { Left = mine and "YOU" or tostring(who or "?"), Right = rank.Name, Color = color, You = mine == true })
			if ok and row then
				row.Name = "RankUpRow"
				return row
			end
		end
		local R = cf().RankUp
		local h = R.RowH
		local l = h * ST.lean()
		local nameText = mine and "YOU" or string.upper(tostring(who or "?"))
		local rankText = string.upper(rank.Name)
		local nw, rw = ST.measure(nameText, R.RowText), ST.measure(rankText, R.RowText)
		local width = math.floor(l + 10 + nw + 8 + 34 + 8 + rw + 10 + l + 0.5)
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") then
				child.LayoutOrder += 1
				if child.LayoutOrder > 5 then
					child:Destroy()
				end
			end
		end
		local row = ST.slab({ Name = "RankUpRow", Size = { width, h }, Color = mine and tk().Paper or tk().Ink, T = mine and 0 or tk().HudT, Parent = parent })
		row.LayoutOrder = 0
		local ink = mine and tk().Ink or tk().Paper
		local z = row.ZIndex + 1
		local x = l + 10
		MO.text({ Name = "Who", Text = nameText, Size = R.RowText, Color = ink, X = x, Y = h * 0.74, Z = z, Parent = row })
		x += nw + 8
		ST.slash({ Name = "Slash", Size = { 34, 22 }, Rotation = -14, Color = color, Value = 1, Pos = UDim2.fromOffset(math.floor(x + 0.5), 1), Z = z, Parent = row })
		x += 42
		MO.text({ Name = "Rank", Text = rankText, Size = R.RowText, Color = ink, X = x, Y = h * 0.74, Z = z, Parent = row })
		task.delay(tk().Motion.FeedLife, function()
			if row.Parent then
				row:Destroy()
			end
		end)
		return row
	end

	-- A CALLOUT (PARRY!, GUARD BREAK, a level...): Oswald on a paper slab on
	-- the rise, in the moment lane; bad news on red
	function MO.callout(text, color)
		text = string.upper(ST.clean(tostring(text or "")))
		if text == "" then
			return
		end
		local C = cf().Callout
		local bad = MO.danger(color)
		MO.push("Callout", function(lane)
			local phone = MO.frame()
			local size = phone and C.PhoneSize or C.Size
			local h = phone and C.PhoneH or C.H
			local l = h * ST.lean()
			local width = math.floor(ST.measure(text, size) + l * 2 + C.Pad * 2 + 0.5)
			local x = (phone and 406 or 640) - width / 2
			local slab = MO.band(lane, "Callout", x, phone and C.PhoneY or C.Y, width, h, 0)
			ST.paint(slab, bad and tk().Red or tk().Paper, 0)
			slab.Rotation = C.Rot
			local m = ST.metrics(size)
			MO.text({ Name = "Text", Text = text, Size = size, Color = bad and tk().Paper or tk().Ink, X = width / 2, Y = h / 2 + (m.Base - m.CapTop) / 2, AlignX = "Center", Z = slab.ZIndex + 1, Parent = slab })
			ST.stamp(slab)
			return C.Hold
		end)
	end

	-- A TIP: the how-to as a toast (TIP, its keys as caps), once a session
	-- for each key (nil: every time). HUD.Tip is its public name.
	function HUD.Tip(text, key)
		return MO.tip(text, key)
	end
	function MO.tip(text, key)
		if key then
			if MO.tips[key] then
				return false
			end
			MO.tips[key] = true
		end
		ST.toast(text, "TIP")
		return true
	end
	-- a key cap's word for an action on this input (keyboard, pad, touch)
	function MO.key(action)
		local touch = keyText.Dash == "DASH"
		local pad = not touch and keyText.Guard ~= "F"
		local word
		if action == "Dash" then
			word = keyText.Dash
		elseif action == "Special" then
			word = pad and HUD.PadGlyph and HUD.PadGlyph(Config.SpecialKeys) or "R"
		elseif action == "Jump" then
			word = (pad and "A") or (touch and "JUMP") or "SPACE"
		else
			word = tostring(action)
		end
		word = tostring(word or "")
		if not string.match(word, "^%w+$") then
			word = string.upper(tostring(action)) -- (a D-pad arrow: its name)
		end
		return "[" .. word .. "]"
	end

	-- NEW HERO (a hero released to everyone): the picker's detail block, full
	-- width - NEW HERO, his number and mode, his name on his slash (and a
	-- marker "new!"), his one sentence, his moves with their keys, how to play
	-- him. b: RP's banner ({ Quirk, Hint, OnShow, Tap }). Waits till it's gone;
	-- returns true if it was cut short (the picker came out).
	function MO.newHero(b)
		local q = Config.Quirks[b.Quirk or ""]
		if not q then
			return false
		end
		local N = cf().NewHero
		local state = { cut = false }
		local function build(lane)
			local phone, ox, _, w = MO.frame()
			local L = phone and N.Phone or N.Pc
			-- (the holder is the band's own rect - ((round 100 review) on a phone the
			-- band itself stops short of the touch grid, MO.bandW: as a button it takes
			-- the taps on it, and only those)
			local bandW = MO.bandW(w, ox, L.H)
			local holder = make(b.Tap and "TextButton" or "Frame", {
				Name = "RosterBanner", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = lane,
				Position = UDim2.fromOffset(-80, math.floor(MO.laneY(L.Y) + 0.5)),
				Size = UDim2.fromOffset(bandW, L.H),
			})
			if b.Tap then
				holder.Text = ""
				holder.AutoButtonColor = false
				holder.Activated:Connect(function()
					if HUD.ToggleShop then
						pcall(HUD.ToggleShop, false)
					end
					pcall(HUD.ShowMenu, true)
					pcall(HUD.Roster.focusRow, b.Quirk)
					state.cut = true
					ST.endMoment()
				end)
			end
			local band = ST.slab({ Name = "Band", Size = { bandW, L.H }, Color = tk().Ink, T = N.BandT, Z = 2, Parent = holder })
			band:SetAttribute("At", band.Position)
			local z = band.ZIndex + 1
			local x0 = L.X + ox + 80 -- (the band starts 80 left of the screen)
			local function at(y)
				return y - L.Y
			end
			-- NEW HERO  No.25  MODE
			local x = x0
			local k = MO.text({ Name = "Kicker", Text = "NEW HERO", Size = L.Kicker, X = x, Y = at(L.KickerY), Z = z, Parent = band })
			x += k.Size.X.Offset + L.Kicker * 0.8
			local num
			for i, name in Config.QuirkOrder or {} do
				if name == b.Quirk then
					num = i
				end
			end
			if num then
				local n = MO.nums(string.format("No.%02d", num), L.Num, { Name = "Number", T = 0.4, X = x, Y = at(L.KickerY), Z = z, Parent = band })
				x += n.Size.X.Offset + L.Kicker * 0.6
			end
			if q.ModeName and q.ModeName ~= "" then
				MO.text({ Name = "Mode", Text = string.upper(q.ModeName), Size = L.Mode, T = 0.45, X = x, Y = at(L.KickerY), Z = z, Parent = band })
			end
			-- his name on his slash
			local display = q.DisplayName or b.Quirk
			local nw = ST.measure(string.upper(display), L.Name)
			local slash = ST.slash({
				Name = "Slash", Size = { math.floor(nw + L.Name * 1.5 + 0.5), math.floor(L.Name * 1.1 + 0.5) }, Color = q.Color, Value = 0,
				Pos = UDim2.fromOffset(math.floor(x0 - L.Name * 0.3 + 0.5), math.floor(at(L.NameY) - L.Name * 0.85 + 0.5)), Z = z, Parent = band,
			})
			ST.setSlash(slash, 1, tk().Motion.SlashPaint)
			MO.text({ Name = "HeroName", Text = string.upper(display), Size = L.Name, X = x0, Y = at(L.NameY), Z = z + 1, Parent = band })
			ST.note("new!", L.Note, { Name = "New", Pos = UDim2.fromOffset(math.floor(x0 + nw + L.Name * 0.5 + 0.5), math.floor(at(L.NameY) - L.Name * 0.55 + 0.5)), Z = z + 1, Parent = band })
			-- his one sentence
			local line = q.ShortDescription
			if type(line) == "string" and line ~= "" then
				MO.text({ Name = "Line", Text = line, Role = "Body", Size = L.Line, T = 0.15, X = x0 + 2, Y = at(L.LineY), Z = z, Parent = band })
			end
			-- his moves with their keys (the PC's: two columns of three)
			if not phone then
				local moves = {}
				local keys = { "1", "2", "3", "4", "R", "G" }
				for i = 1, 4 do
					local a = (q.Abilities or {})[i]
					if type(a) == "table" and type(a.Name) == "string" then
						table.insert(moves, { keys[i], a.Name })
					end
				end
				if type(q.Special) == "table" and type(q.Special.Name) == "string" then
					table.insert(moves, { "R", q.Special.Name })
				end
				if type(q.Ult) == "table" and type(q.Ult.Name) == "string" then
					table.insert(moves, { "G", q.Ult.Name })
				end
				for i, mv in moves do
					if i > 6 then
						break
					end
					local col, row = (i - 1) // 3, (i - 1) % 3
					local mx = L.MovesX + col * L.MovesCol - row * L.MovesLean
					local my = at(L.MovesY + row * L.MovesStep)
					MO.nums(mv[1], L.MoveKey, { Name = "Key" .. i, T = 0.4, X = mx, Y = my, Z = z, Parent = band })
					MO.text({ Name = "Move" .. i, Text = string.upper(mv[2]), Size = L.Move, X = mx + L.MoveKey * 1.3, Y = my, Z = z, Parent = band })
				end
			end
			-- how to play him
			if b.Hint and b.Hint ~= "" then
				-- (at the band's right: the screen's on a PC, the clear line's on a phone)
				local hx = phone and (80 + ox + cf().PhoneClear - 14) or (w + 80 - L.X)
				MO.text({ Name = "Hint", Text = string.upper(tostring(b.Hint)), Size = L.Hint, T = 0.1, X = hx, Y = at(L.HintY), AlignX = "Right", Z = z, Parent = band })
			end
			band.Visible = true
			ST.slideIn(band, band:GetAttribute("At"), cf().KO.In, cf().Slide)
			if b.OnShow then
				task.spawn(b.OnShow)
			end
			-- cut short if the picker comes out (it says the rest)
			task.spawn(function()
				local t0 = os.clock()
				while holder.Parent and os.clock() - t0 < N.Hold do
					if HUD.MenuVisible and HUD.MenuVisible() then
						state.cut = true
						if ST.momentNow and ST.momentNow.holder == lane then
							ST.endMoment()
						end
						break
					end
					task.wait(0.1)
				end
			end)
			return N.Hold
		end
		MO.push("NewHero", build, { Wait = tk().Moments.Wait.NewHero })
		local item
		if ST.momentNow and ST.momentNow.Build == build then
			item = ST.momentNow
		else
			for _, qd in ST.momentQ do
				if qd.Build == build then
					item = qd
				end
			end
		end
		-- (wait till it's been and gone: up, waiting in the queue - or dropped)
		local t0 = os.clock()
		while item and os.clock() - t0 < tk().Moments.Wait.NewHero + N.Hold + 5 do
			if ST.momentNow ~= item and not table.find(ST.momentQ, item) then
				break
			end
			task.wait(0.1)
		end
		return state.cut
	end

	---------------------------------------------------------------- the status lane
	-- the HUD's scaled root (QuirkHUD's StreetRoot: the one UIScale rule)
	function MO.hudRoot()
		return gui and ST.rootOf(gui) or nil
	end
	-- the status lane (under the toasts, centre): the ranked scoreboard OR the
	-- event chips (never both: the scoreboard wins), and the space chip under
	-- whichever's up. Where the next thing goes down it: y in root units.
	function MO.statusTop()
		-- ((round 101) the status lane hangs from the top, under the toast lane, as
		-- the toasts and the feed do - not from the middle: with the size knob the
		-- root is taller than the mockups' frame on every PC screen, and the chips
		-- drifted down off the toast into the moment lane)
		local y = ST.lane("Status")
		-- ((round 100 review) a Nomu raid's boss bar is up there (NomuRaidGui, px, from
		-- y 30): under it, as the old chips went - on a phone the lane (66-96) is
		-- right where it is
		local raid = gui and gui.Parent and gui.Parent:FindFirstChild("NomuRaidGui")
		local boss = raid and raid:FindFirstChild("Boss")
		if boss and boss:IsA("GuiObject") and boss.Visible and raid.Enabled then
			local bottom = boss.Position.Y.Offset + boss.Size.Y.Offset
			y = math.max(y, math.ceil(bottom / ST.scale()) + cf().Status.Gap)
		end
		return y
	end
	function MO.statusBelow(which)
		local y = MO.statusTop()
		local RKH = HUD.RankedHud
		local board = RKH and RKH.top and RKH.top.Parent and RKH.top.Visible
		if board then
			if which == "chips" then
				return nil -- (the scoreboard's up: no chips)
			end
			y += RKH.top.Size.Y.Offset + cf().Status.Gap
		end
		if which == "space" then
			local EP = HUD.AE
			if not board and EP and EP.row and EP.row.Parent and EP.row.Visible and next(EP.chips) ~= nil then
				y += EP.row.Size.Y.Offset + cf().Status.Gap
			end
		end
		return y
	end

	---------------------------------------------------------------- ADMIN ABUSE
	-- an event starting: the cut-in recipe in the event's colour (ADMIN ABUSE
	-- over its name, its line in the top bar, who and how long in the bottom
	-- one). Returns when it's gone. spec: HUD.EventBanner's.
	function MO.event(spec)
		local AE = Config.AdminEvents or {}
		local hold = (AE.Banner and AE.Banner.Hold) or cf().Event.Hold
		local pills = { HUD.AE and HUD.AE.clock and HUD.AE.clock(spec.Length or 0) or "" }
		if spec.Global then
			table.insert(pills, "ON EVERY SERVER")
		end
		if spec.OnShow then
			task.spawn(spec.OnShow)
		end
		local over = MO.cut({
			Name = "AdminEventBanner", TitleName = "EventName", Key = "event", Color = spec.Color, Kicker = "ADMIN ABUSE",
			Title = spec.Name or spec.Id, Line = spec.Blurb, Who = spec.By and ("BY " .. tostring(spec.By)) or nil, WhoName = "Pill",
			Pills = pills, Tag = "EVENT", Hold = hold,
		})
		local t0 = os.clock()
		while over and over.Parent and os.clock() - t0 < hold + cf().Cut.Exit + 1 do
			task.wait(0.1)
		end
	end

	-- EVENT(S) OVER: a stamp and the names, in the status lane for a moment
	function MO.eventOver(list)
		local root = MO.hudRoot()
		if not root then
			return
		end
		local old = root:FindFirstChild("AdminEventOver")
		if old then
			old:Destroy()
		end
		local E = cf().Event
		local phone, ox = MO.frame()
		local names = {}
		for _, e in list do
			table.insert(names, string.upper(tostring(e.Name or "?")))
		end
		local stamp = #list > 1 and "EVENTS OVER" or "EVENT OVER"
		local namesText = table.concat(names, "   ")
		local h = phone and E.OverPhoneH or E.OverH
		local size = phone and E.OverPhoneText or E.OverText
		local l = h * ST.lean()
		local sw = ST.measure(stamp, size - 2) + 2 * (h - 8) * ST.lean() + 16
		local width = math.floor(l + 6 + sw + 12 + ST.measure(namesText, size) + 12 + l + 0.5)
		local x = ox + (phone and 406 or 640) - width / 2
		local holder = ST.slab({
			Name = "AdminEventOver", Size = { width, h }, Color = tk().Ink, T = tk().HudT,
			Pos = UDim2.fromOffset(math.floor(x + 0.5), MO.statusTop()), Z = 3, Parent = root,
		})
		local stampSlab = ST.slab({ Name = "StampSlab", Size = { math.floor(sw + 0.5), h - 8 }, Color = tk().Paper, Pos = UDim2.fromOffset(math.floor(l + 2), 4), Z = 4, Parent = holder })
		local m = ST.metrics(size - 2)
		ST.label({
			Name = "Stamp", Text = stamp, Size = size - 2, Color = tk().Ink, AlignX = "Center",
			Pos = UDim2.new(0.5, 0, 0.5, math.floor((m.H / 2 - m.Base + (m.Base - m.CapTop) / 2) * -1 + 0.5)), Anchor = V2(0.5, 0.5), Z = 5, Parent = stampSlab,
		})
		MO.text({ Name = "Names", Text = namesText, Size = size, X = l + 6 + sw + 12, Y = h * 0.72, Z = 4, Parent = holder })
		holder:SetAttribute("At", holder.Position)
		ST.slideIn(holder, holder.Position, cf().KO.In, cf().Slide)
		task.delay(E.OverHold, function()
			if holder.Parent then
				ST.slideOut(holder, holder:GetAttribute("At"), tk().Motion.MenuOut, cf().Slide)
				task.delay(tk().Motion.MenuOut + 0.03, function()
					holder:Destroy()
				end)
			end
		end)
		return holder
	end

	-- THE CHIPS (one per event running, the status lane): its name, a note
	-- (EVERY SERVER, your bills...), the time left in numerals (red the last
	-- 10 s), a paper line along its foot running down
	function MO.chipRow()
		local EP = HUD.AE
		if EP.row and EP.row.Parent then
			return EP.row
		end
		local root = MO.hudRoot()
		if not root then
			return nil
		end
		EP.row = make("Frame", {
			Name = "AdminEventChips", AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, MO.statusTop()),
			Size = UDim2.fromOffset(cf().Chips.W, cf().Chips.H), BackgroundTransparency = 1, ZIndex = 3, Parent = root,
		})
		EP.row:SetAttribute("Phone", ST.isPhone())
		return EP.row
	end
	function MO.makeChip(order, id, d)
		local EP = HUD.AE
		local C = cf().Chips
		local phone = ST.isPhone()
		local w, h = phone and C.PhoneW or C.W, phone and C.PhoneH or C.H
		local l = h * ST.lean()
		local chip = ST.slab({ Name = id, Size = { w, h }, Color = tk().Ink, T = tk().HudT, Z = 3, Parent = EP.row })
		chip.LayoutOrder = order
		local z = chip.ZIndex + 1
		local nameSize, noteSize, timeSize = phone and C.PhoneName or C.Name, phone and C.PhoneNote or C.Note, phone and C.PhoneTime or C.Time
		local name = MO.text({ Name = "EventName", Text = string.upper(tostring(d.Name or id)), Size = nameSize, X = l + 8, Y = h * 0.46, Z = z, Parent = chip })
		name.Text = d.Name or id
		-- ((round 100 review) where its top sits with a note under it, and alone (its
		-- caps centred: no note, no hole under it))
		local nm = ST.metrics(nameSize)
		name:SetAttribute("YNote", name.Position.Y.Offset)
		name:SetAttribute("YAlone", math.floor((h - 3) / 2 + (nm.Base - nm.CapTop) / 2 - nm.Base + 0.5))
		local note = MO.text({ Name = "Note", Text = "", Size = noteSize, T = 0.45, X = l * 0.35 + 8, Y = h * 0.82, Z = z, Parent = chip })
		note.Size = UDim2.fromOffset(math.floor(w * 0.6), note.Size.Y.Offset)
		local time = MO.nums("0:00", timeSize, { Name = "Time", X = w - l - 8, Y = h * 0.66, AlignX = "Right", Z = z, Parent = chip })
		-- the line along its foot (a fill, leaning with it)
		local track = ST.slab({ Name = "Track", Size = { w - 2 * math.floor(l), 3 }, Color = tk().Ink, T = 1, Pos = UDim2.fromOffset(math.floor(l * 0.1), h - 3), Z = z, Parent = chip })
		local bar = ST.fill(track, { Name = "Bar", Color = tk().Paper, T = 0.2, Value = 1 })
		EP.chips[id] = { Chip = chip, Name = name, Note = note, Time = time, Bar = bar, Def = d }
	end
	-- list: { { Id, Ends, Length, Global } } in Order (empty: none)
	function MO.chips(list)
		local EP = HUD.AE
		local row = MO.chipRow()
		if not row then
			return nil
		end
		local keep = {}
		for order, e in list do
			local d = (Config.AdminEvents and Config.AdminEvents.Events or {})[e.Id]
			if d then
				keep[e.Id] = true
				if not EP.chips[e.Id] then
					MO.makeChip(order, e.Id, d)
				end
				local c = EP.chips[e.Id]
				c.Chip.LayoutOrder = order
				c.Ends, c.Length, c.Global = e.Ends, e.Length, e.Global
			end
		end
		for id, c in EP.chips do
			if not keep[id] then
				EP.chips[id] = nil
				c.Chip:Destroy()
			end
		end
		MO.drawChips()
		if next(EP.chips) ~= nil and not EP.chipsTicking then
			EP.chipsTicking = true
			task.spawn(function()
				while next(EP.chips) ~= nil do
					MO.drawChips()
					task.wait(0.1)
				end
				EP.chipsTicking = false
			end)
		end
		return row
	end
	function MO.drawChips()
		local EP = HUD.AE
		if not (EP.row and EP.row.Parent) then
			return
		end
		local C = cf().Chips
		local y = MO.statusBelow("chips")
		EP.row.Visible = y ~= nil
		if not y then
			return
		end
		local phone = ST.isPhone()
		if EP.row:GetAttribute("Phone") ~= phone then
			-- (the layout flipped: each chip built again for this one)
			EP.row:SetAttribute("Phone", phone)
			for id, c in EP.chips do
				local keep = { Ends = c.Ends, Length = c.Length, Global = c.Global, Order = c.Chip.LayoutOrder }
				c.Chip:Destroy()
				MO.makeChip(keep.Order, id, c.Def)
				local n = EP.chips[id]
				n.Ends, n.Length, n.Global = keep.Ends, keep.Length, keep.Global
			end
		end
		local cw, ch = phone and C.PhoneW or C.W, phone and C.PhoneH or C.H
		local list = {}
		for _, c in EP.chips do
			table.insert(list, c)
		end
		table.sort(list, function(a, b)
			return a.Chip.LayoutOrder < b.Chip.LayoutOrder
		end)
		-- (as many to a row as fit between the feed on the right and its twin on the left)
		local w = MO.size()
		local step = cw + C.Gap
		local perRow = math.max(1, math.floor((w - 2 * (phone and C.PhoneSide or C.Side) + C.Gap) / step))
		local n = #list
		local wide = math.max(math.min(n, perRow) * step - C.Gap, cw)
		EP.row.Position = UDim2.new(0.5, 0, 0, y)
		EP.row.Size = UDim2.fromOffset(wide, math.max(1, math.ceil(n / perRow)) * (ch + C.Gap) - C.Gap)
		for i, c in list do
			local r, col = (i - 1) // perRow, (i - 1) % perRow
			local m = math.min(perRow, n - r * perRow)
			-- (each row a step to the right of the one over it: the lean)
			c.Chip.Position = UDim2.fromOffset(math.floor((wide - (m * step - C.Gap)) / 2 + col * step - r * (ch + C.Gap) * ST.lean() + 0.5), r * (ch + C.Gap))
		end
		local t = workspace:GetServerTimeNow()
		for id, c in EP.chips do
			local left = math.max(0, (c.Ends or t) - t)
			local text = HUD.AE.clock(left)
			if c.Time:GetAttribute("NumText") ~= text then
				ST.setNumerals(c.Time, text)
			end
			local hurry = left <= 10
			if c.Time:GetAttribute("Hurry") ~= hurry then
				c.Time:SetAttribute("Hurry", hurry)
				c.Time:SetAttribute("NumColor", hurry and tk().Red or tk().Paper)
				ST.setNumerals(c.Time, text)
				for _, d in c.Time:GetDescendants() do
					if d:IsA("TextLabel") and d.Name == "Face" or (d:IsA("TextLabel") and d.Name == "Text") then
						d.TextColor3 = hurry and tk().Red or tk().Paper
					elseif d:IsA("ImageLabel") and string.sub(d.Name, 1, 1) == "G" then
						d.ImageColor3 = hurry and tk().Red or tk().Paper
					end
				end
			end
			ST.setFill(c.Bar, math.clamp(left / math.max(c.Length or 1, 1), 0, 1))
			c.Note.Text = string.upper(EP.notes[id] or (c.Global and "EVERY SERVER" or ""))
			local ny = c.Name:GetAttribute(c.Note.Text == "" and "YAlone" or "YNote")
			if ny and c.Name.Position.Y.Offset ~= ny then
				c.Name.Position = UDim2.fromOffset(c.Name.Position.X.Offset, ny)
			end
		end
	end

	-- HERO SHUFFLE's reel: heroes rolling past in a window, slowing, landing on
	-- yours - it gets your slash. hero, spin s, opts as HUD.ShuffleReel's.
	function MO.reel(hero, spin, opts)
		local q = Config.Quirks[hero or ""]
		local root = MO.hudRoot()
		if not (root and q) then
			return
		end
		local old = root:FindFirstChild("AdminShuffleReel")
		if old then
			old:Destroy()
		end
		local R = cf().Reel
		local phone, ox, oy = MO.frame()
		local W, H = R.W, R.H
		local CELL = R.Cell
		local l = H * ST.lean()
		local holder = ST.slab({
			Name = "AdminShuffleReel", Size = { W, H }, Color = tk().Ink, T = 0.05, Anchor = V2(0.5, 0.5),
			Pos = UDim2.fromOffset(ox + (phone and R.PhoneX or 640), oy + (phone and R.PhoneY or R.Y)), Z = 6, Parent = root,
		})
		if phone then
			make("UIScale", { Name = "Fit", Scale = R.PhoneScale, Parent = holder })
		end
		local z = holder.ZIndex + 1
		MO.text({ Name = "Title", Text = "HERO SHUFFLE", Size = R.Title, X = l + 18, Y = R.TitleY, Z = z, Parent = holder })
		-- the window: a band of ink 2, three rows showing, clipped (nothing turned in it)
		local window = make("Frame", {
			Name = "Window", Position = UDim2.fromOffset(math.floor(l * 0.5 + 18), R.WindowY), Size = UDim2.fromOffset(W - math.floor(l * 1.2) - 36, CELL * 3),
			BackgroundColor3 = tk().Ink2, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z, Parent = holder,
		})
		local strip = make("Frame", { Name = "Strip", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ZIndex = z + 1, Parent = window })
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
			local cell = make("Frame", { Name = "Cell", Position = UDim2.fromOffset(0, (i - 1) * CELL), Size = UDim2.new(1, 0, 0, CELL), BackgroundTransparency = 1, ZIndex = z + 1, Parent = strip })
			local num = table.find(Config.QuirkOrder, h)
			if num then
				MO.nums(string.format("%02d", num), R.Num, { Name = "Num", T = 0.4, X = 16, Y = CELL * 0.68, Z = z + 2, Parent = cell })
			end
			MO.text({ Name = "HeroName", Text = string.upper(hq.DisplayName or h), Size = R.Name, T = 0.44, X = 52, Y = CELL * 0.72, Z = z + 3, Parent = cell })
			cells[i] = cell
		end
		-- the payline: two paper hairlines either side of the middle row
		for i, y in { CELL, CELL * 2 - 2 } do
			make("Frame", { Name = "Payline" .. i, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = tk().Paper, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = z + 4, Parent = window })
		end
		local result = MO.text({
			Name = "Result", Text = (opts.Back and "BACK TO " or "YOU'RE ") .. string.upper(q.DisplayName or hero), Size = R.Result,
			X = l * 0.2 + 18, Y = R.ResultY, Z = z, Parent = holder,
		})
		result.TextTransparency = 1
		holder:SetAttribute("At", holder.Position)
		ST.slideIn(holder, holder.Position, cf().KO.In, cf().Slide)
		-- the roll: fast, then slowing onto his row (cubic ease out)
		local final = (#seq - 3) * CELL
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
		local function out(after)
			task.delay(after, function()
				if holder.Parent then
					ST.slideOut(holder, holder:GetAttribute("At"), tk().Motion.MenuOut, cf().Slide)
					task.delay(tk().Motion.MenuOut + 0.03, function()
						holder:Destroy()
					end)
				end
			end)
		end
		-- (the shuffle ended while it rolled: the server deals nothing)
		if opts.Still and not opts.Still() then
			result.Text = "HERO SHUFFLE'S OVER"
			result.TextTransparency = 0.45
			out(0.8)
			return
		end
		-- landed: his row lit, on his slash
		local mine = cells[#seq - 1]
		if mine then
			local nm = mine:FindFirstChild("HeroName")
			if nm then
				nm.TextTransparency = 0
				local sl = ST.slash({
					Name = "Slash", Size = { math.floor(nm.Size.X.Offset + 40), CELL - 8 }, Color = q.Color, Value = 0, Rotation = -1.5,
					Pos = UDim2.fromOffset(40, 4), Z = z + 2, Parent = mine,
				})
				ST.setSlash(sl, 1, tk().Motion.SlashPaint)
			end
		end
		result.TextTransparency = 0
		if opts.OnLand then
			task.spawn(opts.OnLand)
		end
		out(0.95)
		task.wait(0.95 + tk().Motion.MenuOut + 0.05)
	end

	---------------------------------------------------------------- RANKED
	-- the duel's scoreboard (the status lane): you and them on your heroes'
	-- slashes, the score in numerals, the round and the clock under it
	function MO.board()
		local RKH = HUD.RankedHud
		local was
		if RKH.top and RKH.top.Parent then
			if RKH.top:GetAttribute("Phone") == ST.isPhone() then
				return RKH.top
			end
			-- (the layout flipped: built again for this one, as it was)
			was = RKH.top.Visible
			RKH.top:Destroy()
			RKH.top = nil
		end
		local root = MO.hudRoot()
		if not root then
			return nil
		end
		local B = cf().Ranked.Board
		local phone = ST.isPhone()
		local W, H = phone and B.PhoneW or B.W, phone and B.PhoneH or B.H
		local l = H * ST.lean()
		local f = ST.slab({ Name = "RankedScore", Size = { W, H }, Color = tk().Ink, T = tk().HudT, Anchor = V2(0.5, 0), Pos = UDim2.new(0.5, 0, 0, MO.statusTop()), Visible = false, Z = 3, Parent = root })
		local z = f.ZIndex + 1
		local nameSize, tierSize = phone and B.PhoneName or B.Name, phone and B.PhoneTier or B.Tier
		local function side(name, right)
			local x = right and (W - l - 14) or (l + 14)
			local sl = ST.slash({
				Name = name .. "Slash", Size = { math.floor(W * 0.3), math.floor(nameSize * 1.25) }, Color = tk().Ash, Value = 1, Rotation = -2,
				Pos = UDim2.fromOffset(right and math.floor(W * 0.62) or math.floor(l * 0.5 + 4), math.floor(H * 0.06)), Z = z, Parent = f,
			})
			local nm = MO.text({ Name = name .. "Name", Text = "", Size = nameSize, Shadow = nil, X = x, Y = H * 0.5, AlignX = right and "Right" or "Left", Z = z + 1, Parent = f })
			nm.Size = UDim2.fromOffset(math.floor(W * 0.36), nm.Size.Y.Offset)
			nm.TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			local tier = MO.text({ Name = name .. "Tier", Text = "", Size = tierSize, T = 0.45, X = right and (x - H * 0.28 * ST.lean() * 2) or (x - 4), Y = H * 0.86, AlignX = right and "Right" or "Left", Z = z + 1, Parent = f })
			tier.Size = UDim2.fromOffset(math.floor(W * 0.36), tier.Size.Y.Offset)
			tier.TextXAlignment = nm.TextXAlignment
			return nm, tier, sl
		end
		RKH.meName, RKH.meTier, RKH.meSlash = side("Me", false)
		RKH.themName, RKH.themTier, RKH.themSlash = side("Them", true)
		RKH.score = MO.nums("0 - 0", phone and B.PhoneScore or B.Score, { Name = "Score", X = W / 2, Y = H * 0.6, AlignX = "Center", Z = z + 1, Parent = f })
		RKH.clockText = MO.text({ Name = "Clock", Text = "", Size = tierSize, T = 0.3, X = W / 2, Y = H * 0.93, AlignX = "Center", Z = z + 1, Parent = f })
		RKH.clockText.Size = UDim2.fromOffset(160, RKH.clockText.Size.Y.Offset)
		RKH.clockText.TextXAlignment = Enum.TextXAlignment.Center
		RKH.top = f
		f:SetAttribute("Phone", phone)
		if was ~= nil then
			for _, which in { "me", "them" } do
				if (RKH.cards or {})[which] then
					MO.boardSide(which, RKH.cards[which])
				end
			end
			if RKH.lastScore then
				MO.setScore(RKH.lastScore[1], RKH.lastScore[2])
			end
			f.Visible = was
		end
		return f
	end
	-- its sides' names, tiers and slashes (card: the server's { Name, Tier, Rating, Hero })
	function MO.boardSide(which, card)
		local RKH = HUD.RankedHud
		card = type(card) == "table" and card or {}
		RKH.cards = RKH.cards or {}
		RKH.cards[which] = card
		local nm, tier, sl = RKH[which .. "Name"], RKH[which .. "Tier"], RKH[which .. "Slash"]
		if nm then
			nm.Text = string.upper(tostring(card.Name or (which == "me" and "YOU" or "?")))
		end
		if tier then
			tier.Text = string.format("%s %d", string.upper(tostring(card.Tier or "")), tonumber(card.Rating) or 0)
		end
		if sl then
			ST.tintSlash(sl, MO.heroColor(card.Hero) or tk().Ash)
		end
	end
	-- the score, the clock
	function MO.setScore(me, them)
		local RKH = HUD.RankedHud
		RKH.lastScore = { me or 0, them or 0 }
		if RKH.score then
			ST.setNumerals(RKH.score, string.format("%d - %d", me or 0, them or 0))
		end
	end
	function MO.tick()
		local RKH = HUD.RankedHud
		if not (RKH.top and RKH.top.Visible) then
			return
		end
		if RKH.top:GetAttribute("Phone") ~= ST.isPhone() then
			MO.board()
		end
		local round = RKH.round or 1
		if RKH.ends then
			local left = math.max(0, math.ceil(RKH.ends - workspace:GetServerTimeNow()))
			RKH.clockText.Text = string.format("ROUND %d  %d:%02d", round, left // 60, left % 60)
			RKH.clockText.TextColor3 = left <= 10 and tk().Red or tk().Paper
		else
			RKH.clockText.Text = string.format("ROUND %d", round)
			RKH.clockText.TextColor3 = tk().Paper
		end
	end
	-- the board up or down (the chips step aside for it, and back)
	function MO.showBoard(on)
		local f = MO.board()
		if f then
			f.Position = UDim2.new(0.5, 0, 0, MO.statusTop())
			f.Visible = on == true
		end
		MO.drawChips()
	end

	-- A CALL (ROUND 2, 3, 2, 1, FIGHT, K.O.): numerals 120 that cut in with no
	-- ease and cut out; a line under it. Its own frame over the moment lane.
	function MO.call(text, color, sub, hold)
		local RKH = HUD.RankedHud
		local lane = ST.momentLane
		if not lane then
			return
		end
		local C = cf().Ranked.Call
		text = string.upper(string.gsub(tostring(text or ""), "!+", ""))
		local phone = ST.isPhone()
		local size = phone and C.PhoneSize or C.Size
		local old = lane.Parent:FindFirstChild("RankedCall")
		if old then
			old:Destroy()
		end
		-- (the VS card gives way to the first call; a promotion's call sits over its result)
		local card = lane.Parent:FindFirstChild("RankedCard")
		if card and sub ~= "PROMOTED" then
			card:Destroy()
		end
		local _, ox = MO.frame()
		local c = make("Frame", { Name = "RankedCall", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = lane.Parent })
		RKH.callFrame = c
		local cx = ox + (phone and 406 or 640)
		local y = MO.laneY(phone and C.PhoneY or C.Y) + ST.lane("Moment")
		local ko = text == "K.O."
		if typeof(color) == "Color3" and sub == "PROMOTED" then
			local w = ST.measure(text, size)
			local sl = ST.slash({ Name = "Slash", Size = { math.floor(w + size * 0.8), math.floor(size * 0.9) }, Color = color, Value = 1, Anchor = V2(0.5, 0.5), Pos = UDim2.fromOffset(math.floor(cx), math.floor(y - size * 0.4)), Z = 3, Parent = c })
			sl.Name = "Slash"
		end
		MO.nums(text, size, { Name = "Big", Color = ko and tk().Red or tk().Paper, Shadow = C.Shadow, X = cx, Y = y, AlignX = "Center", Z = 4, Parent = c })
		if sub and sub ~= "" then
			MO.text({ Name = "Sub", Text = string.upper(tostring(sub)), Size = phone and C.PhoneSub or C.Sub, Shadow = 2, X = cx, Y = y + (phone and C.PhoneSubGap or C.SubGap), AlignX = "Center", Z = 4, Parent = c })
		end
		local token = {}
		RKH.callToken = token
		task.delay(hold or 0.75, function()
			if RKH.callToken == token and c.Parent then
				c:Destroy()
			end
		end)
	end

	-- A CARD (the VS before round 1, the result after): a leaning band in the
	-- lane - a kicker, the big word on a slash, the lines. spec: { Kicker, Title,
	-- Color (the slash: nil = none), Name (a name on its hero's slash), NameColor,
	-- Lines = { { text, size, transparency, role } }, Hold }
	function MO.card(spec)
		local RKH = HUD.RankedHud
		local lane = ST.momentLane
		if not lane then
			return
		end
		local old = lane.Parent:FindFirstChild("RankedCard")
		if old then
			old:Destroy()
		end
		-- (a call still up - the last round's - gives way to the card)
		local call = lane.Parent:FindFirstChild("RankedCall")
		if call then
			call:Destroy()
		end
		local C = cf().Ranked.Card
		local phone, ox, _, w = MO.frame()
		local L = phone and C.Phone or C.Pc
		local holder = make("Frame", { Name = "RankedCard", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = lane.Parent })
		holder.Position = UDim2.fromOffset(0, ST.lane("Moment"))
		RKH.mid = holder
		local band = MO.band(holder, "Band", -80, L.Y, MO.bandW(w, ox, L.H), L.H, C.BandT, true)
		local z = band.ZIndex + 1
		local x0 = L.X + ox + 80
		local function at(y)
			return y - L.Y
		end
		MO.text({ Name = "Kicker", Text = string.upper(tostring(spec.Kicker or "")), Size = L.Kicker, T = 0.45, X = x0, Y = at(L.KickerY), Z = z, Parent = band })
		local title = string.upper(tostring(spec.Title or ""))
		local tw = ST.measure(title, L.Title)
		if spec.Color then
			local sl = ST.slash({
				Name = "Slash", Size = { math.floor(tw + L.Title * 0.9), math.floor(L.Title * 0.95) }, Color = spec.Color, Value = 0,
				Pos = UDim2.fromOffset(math.floor(x0 - L.Title * 0.25), math.floor(at(L.TitleY) - L.Title * 0.8)), Z = z, Parent = band,
			})
			ST.setSlash(sl, 1, tk().Motion.SlashPaint)
		end
		MO.text({ Name = "Title", Text = title, Size = L.Title, X = x0, Y = at(L.TitleY), Z = z + 1, Parent = band })
		-- the right column: the name on its slash, then the lines
		local rx = x0 + tw + L.Gap
		local y = at(L.FirstY)
		if spec.Name then
			local name = string.upper(tostring(spec.Name))
			local nw = ST.measure(name, L.Name)
			local sl = ST.slash({
				Name = "NameSlash", Size = { math.floor(nw + L.Name * 1.6), math.floor(L.Name * 1.05) }, Color = spec.NameColor or tk().Ash, Value = 1,
				Pos = UDim2.fromOffset(math.floor(rx - L.Name * 0.3), math.floor(y - L.Name * 0.85)), Z = z, Parent = band,
			})
			sl.Name = "NameSlash"
			MO.text({ Name = "Name", Text = name, Size = L.Name, Shadow = 2, X = rx, Y = y, Z = z + 1, Parent = band })
			y += L.Name * 0.35 -- ((round 100 review) was 0.95: a hole under the name, the lines crowded below it)
		end
		for i, line in spec.Lines or {} do
			if line[1] and line[1] ~= "" then
				-- ((round 100 review) a set size is a PC one: a phone's in proportion)
				local size = line[2] and line[2] * L.Line / C.Pc.Line or L.Line
				y += size * 1.45
				MO.text({ Name = "Line" .. i, Text = line[1], Size = size, T = line[3] or 0, Role = line[4], X = rx - (y - at(L.FirstY)) * ST.lean(), Y = y, Z = z, Parent = band })
			end
		end
		band:SetAttribute("At", band.Position)
		ST.slideIn(band, band.Position, cf().KO.In, cf().Slide)
		local token = {}
		RKH.midToken = token
		task.delay(spec.Hold or 3, function()
			if RKH.midToken == token and holder.Parent then
				ST.slideOut(band, band:GetAttribute("At"), tk().Motion.MenuOut, cf().Slide)
				task.delay(tk().Motion.MenuOut + 0.03, function()
					holder:Destroy()
				end)
			end
		end)
		return holder
	end

	---------------------------------------------------------------- the moderators
	-- A WARNING FROM THE MODERATORS: a leaning ink card over everything -
	-- WARNING in red, what they said, who from, I UNDERSTAND (gone by itself
	-- after a minute). Returns the card.
	function MO.warn(text, by)
		local pg = gui and gui.Parent
		if not pg then
			return nil
		end
		local Wc = cf().Warn
		local _, root = ST.screen("QuirkWarning", Wc.Order, pg)
		local old = root:FindFirstChild("ModWarning")
		if old then
			old:Destroy()
		end
		local phone, ox, oy = MO.frame()
		text = tostring(text or "")
		local from = "From the moderators" .. ((by and by ~= "") and (" (" .. tostring(by) .. ")") or "") .. ". Keep it up and it's a kick or a ban."
		-- ((round 100 review) sized to what they wrote: the server lets a warning
		-- run to 200 letters, and a wrapped label shows only the lines that fit -
		-- a fixed 60 px box cut a long one to its first two lines. The words and
		-- the From line wrap in the card's width; the card grows to hold them)
		local W, H = Wc.W, Wc.H
		local textH, fromH, l, boxW
		for _ = 1, 2 do
			l = H * ST.lean()
			boxW = W - 2 * l - 56
			local function lines(s, size)
				return math.max(1, math.ceil(ST.measure(s, size, "Body") * 1.12 / boxW))
			end
			-- (+4: under a phone's UIScale the lines round up a pixel - an exact box drops the last)
			textH = math.ceil(lines(text, Wc.Text) * ST.metrics(Wc.Text, "Body").H) + 4
			fromH = math.ceil(lines(from, Wc.From) * ST.metrics(Wc.From, "Body").H) + 4
			H = math.max(Wc.H, math.ceil(Wc.TextY + textH + 8 + fromH + 6 + Wc.ButtonH + 18))
		end
		local card = ST.slab({
			Name = "ModWarning", Size = { W, H }, Color = tk().Ink, T = 0.03, Anchor = V2(0.5, 0.5),
			Pos = UDim2.fromOffset(ox + (phone and 406 or 640), oy + (phone and 188 or 330)), Z = 2, Parent = root,
		})
		if phone then
			make("UIScale", { Name = "Fit", Scale = Wc.PhoneScale, Parent = card })
		end
		local z = card.ZIndex + 1
		local x = l + 28
		MO.text({ Name = "Title", Text = "WARNING", Size = Wc.Title, Color = tk().Red, X = x, Y = Wc.TitleY, Z = z, Parent = card })
		local body = ST.label({
			Name = "Text", Text = text, Role = "Body", Size = Wc.Text, Wrap = true, AlignY = "Top",
			Box = UDim2.fromOffset(boxW, textH), Pos = UDim2.fromOffset(x - 6, Wc.TextY), Z = z, Parent = card,
		})
		body.Text = text
		ST.label({
			Name = "From", Text = from, Role = "Body", Size = Wc.From, T = 0.4, Wrap = true, AlignY = "Top",
			Box = UDim2.fromOffset(boxW, fromH), Pos = UDim2.fromOffset(x - 10, Wc.TextY + textH + 8), Z = z, Parent = card,
		})
		local ok = ST.button({
			Name = "Ok", Kind = "Primary", Text = "I UNDERSTAND", Size = { Wc.ButtonW, Wc.ButtonH }, TextSize = Wc.ButtonText,
			Pos = UDim2.new(0, W - l - 24, 1, -18), Anchor = V2(1, 1), Z = z, Parent = card,
		})
		ok.Activated:Connect(function()
			card:Destroy()
		end)
		task.delay(Wc.Life, function()
			if card.Parent then
				card:Destroy()
			end
		end)
		return card
	end

	---------------------------------------------------------------- [E] FINISH
	-- the FINISH over a beaten body (QuirkClient's BillboardGui, px): an ink
	-- slab, the key on a paper cap, FINISH in red. key: "E", "RB", "" (touch:
	-- no key). Built again only when the key changes.
	function HUD.FinishFace(bb, key)
		if not bb then
			return nil
		end
		key = tostring(key or "E")
		local face = bb:FindFirstChild("Face")
		if face and bb:GetAttribute("FaceKey") == key then
			return face
		end
		if face then
			face:Destroy()
		end
		bb:SetAttribute("FaceKey", key)
		local F = cf().Finish
		face = make("Frame", { Name = "Face", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = bb })
		local h = F.H
		local l = h * ST.lean()
		local ww = ST.measure("FINISH", F.Text)
		local kw = key ~= "" and math.max(math.floor(F.Cap * 0.92 + 0.5), math.ceil(ST.measure(key, F.Cap * 0.78) + F.Cap * ST.lean() * 2 + 4)) or 0
		local width = math.floor(l + 8 + (kw > 0 and kw + 7 or 0) + ww + 10 + l + 0.5)
		local slab = ST.slab({ Name = "Slab", Size = { width, h }, Color = tk().Ink, T = 0.08, Anchor = V2(0.5, 0.5), Pos = UDim2.fromScale(0.5, 0.5), Parent = face })
		local x = l + 8
		if kw > 0 then
			ST.keyCap(key, F.Cap, { Name = "Key", Pos = UDim2.new(0, math.floor(x + 0.5), 0.5, 0), Anchor = V2(0, 0.5), Z = slab.ZIndex + 1, Parent = slab })
			x += kw + 7
		end
		MO.text({ Name = "Word", Text = "FINISH", Size = F.Text, Color = tk().Red, X = x, Y = h / 2 + F.Text * tk().Fonts.Display.Cap / 2, Z = slab.ZIndex + 1, Parent = slab })
		return face
	end

	---------------------------------------------------------------- the dev flight
	-- THE FLIGHT METER (dev flight): an ink slab over the move row - what's
	-- happening (Caption), the tier (on a slash at LIGHTSPEED and GODSPEED), the
	-- speed in numerals, the Mach number, a paper line for the speed with the
	-- tiers' ticks (the boom's taller), and the barrier's charge under it.
	-- info: HUD.FlightMeter's (nil: hidden).
	MO.LIGHT = { LIGHTSPEED = Color3.fromRGB(96, 220, 255), GODSPEED = Color3.fromRGB(255, 206, 92) }
	function MO.meterBuild()
		local FL = HUD.Flight
		local root = MO.hudRoot()
		if not root then
			return nil
		end
		local Fm = cf().Flight
		local phone, ox, oy = MO.frame()
		local W, H = Fm.W, Fm.H
		local l = H * ST.lean()
		-- ((round 101) on PC it hangs from the bottom left, as the move row under it
		-- does: with the size knob the root is bigger than the mockup's frame, and
		-- a centred frame floated it away from the row)
		local m = ST.slab({
			Name = "FlightMeter", Size = { W, H }, Color = tk().Ink, T = tk().HudT,
			Pos = phone and UDim2.fromOffset(ox + Fm.PhoneX, oy + Fm.PhoneY) or UDim2.new(0, Fm.X, 1, Fm.Y - 720), Z = 2, Parent = root,
		})
		if phone then
			make("UIScale", { Name = "Fit", Scale = Fm.PhoneScale, Parent = m })
		end
		local z = m.ZIndex + 1
		FL.tierSlash = ST.slash({ Name = "TierSlash", Size = { 150, 26 }, Color = tk().Paper, Value = 1, Pos = UDim2.fromOffset(math.floor(l * 0.4 + 2), 14), Z = z, Visible = false, Parent = m })
		FL.caption = MO.text({ Name = "Caption", Text = "DEV FLIGHT", Size = Fm.Caption, T = 0.4, X = l + 8, Y = 13, Z = z + 1, Parent = m })
		FL.caption.Size = UDim2.fromOffset(W - 2 * math.floor(l) - 70, FL.caption.Size.Y.Offset)
		FL.tier = MO.text({ Name = "Tier", Text = "HOVER", Size = Fm.Tier, X = l * 0.45 + 8, Y = 32, Z = z + 1, Parent = m })
		FL.tier.Size = UDim2.fromOffset(170, FL.tier.Size.Y.Offset)
		FL.speed = MO.nums("0", Fm.Speed, { Name = "Speed", X = W - l * 0.45 - 10, Y = 24, AlignX = "Right", Z = z + 1, Parent = m })
		FL.mach = MO.text({ Name = "Mach", Text = "MACH 0.00", Size = Fm.Mach, T = 0.4, X = W - l * 0.1 - 12, Y = 34, AlignX = "Right", Z = z + 1, Parent = m })
		FL.mach.Size = UDim2.fromOffset(110, FL.mach.Size.Y.Offset)
		FL.mach.TextXAlignment = Enum.TextXAlignment.Right
		-- the speed's line, the tiers' ticks, the boom's mark
		local bar = ST.slab({ Name = "Bar", Size = { W - math.floor(2 * l) - 16, 3 }, Color = tk().Ink2, T = 0, Pos = UDim2.fromOffset(math.floor(l * 0.2 + 8), H - 6), Z = z, Parent = m })
		FL.fill = ST.fill(bar, { Name = "Fill", Color = tk().Paper, Value = 0 })
		for _, mark in Fm.Marks do
			local boom = mark == Fm.Boom
			make("Frame", {
				Name = boom and "BoomMark" or "Mark", AnchorPoint = V2(0.5, 0.5), Position = UDim2.new(mark / FL.TOP, 0, 0.5, 0),
				Size = UDim2.fromOffset(boom and 2 or 1, boom and 9 or 6), BackgroundColor3 = tk().Paper, BackgroundTransparency = boom and 0 or 0.4,
				BorderSizePixel = 0, ZIndex = z + 2, Parent = bar,
			})
		end
		-- the light barrier's charge, under it
		local lightBar = ST.slab({ Name = "LightBar", Size = { W - math.floor(2 * l) - 16, 2 }, Color = tk().Ink2, T = 0, Pos = UDim2.fromOffset(math.floor(l * 0.05 + 8), H - 2), Z = z, Visible = false, Parent = m })
		FL.lightFill = ST.fill(lightBar, { Name = "Fill", Color = tk().Paper, Value = 0 })
		FL.lightBar = lightBar
		FL.meter = m
		m:SetAttribute("Phone", phone)
		return m
	end
	function MO.meter(info)
		local FL = HUD.Flight
		if not info then
			if FL.meter then
				FL.meter.Visible = false
			end
			return
		end
		if FL.meter and FL.meter.Parent and FL.meter:GetAttribute("Phone") ~= ST.isPhone() then
			FL.meter:Destroy() -- (the layout flipped: built again for this one)
			FL.meter = nil
		end
		if not (FL.meter and FL.meter.Parent) then
			if not MO.meterBuild() then
				return
			end
		end
		local name = tostring(info.Tier or "HOVER")
		local speed = math.max(tonumber(info.Speed) or 0, 0)
		FL.meter.Visible = true
		FL.tier.Text = name
		local spd = tostring(math.floor(speed + 0.5))
		if FL.speed:GetAttribute("NumText") ~= spd then
			ST.setNumerals(FL.speed, spd)
		end
		FL.mach.Text = string.format("MACH %.2f", tonumber(info.Mach) or speed / FL.TOP)
		ST.setFill(FL.fill, math.clamp(speed / FL.TOP, 0, 1))
		-- the light barrier: charging, broken (LIGHTSPEED), or how to get there;
		-- (round 99) GODSPEED: at it, its charge, or the way there
		local charge = math.clamp(tonumber(info.Charge) or 0, 0, 1)
		local lit = info.Light == true
		local god = info.God == true
		local gcharge = math.clamp(tonumber(info.GodCharge) or 0, 0, 1)
		local slashColor = (god and MO.LIGHT.GODSPEED) or (lit and MO.LIGHT.LIGHTSPEED) or nil
		FL.tierSlash.Visible = slashColor ~= nil
		if slashColor and FL.tierSlash:GetAttribute("Tint") ~= name then
			FL.tierSlash:SetAttribute("Tint", name)
			ST.tintSlash(FL.tierSlash, slashColor)
		end
		FL.lightBar.Visible = lit or charge > 0 or god or gcharge > 0
		if FL.lightBar.Visible then
			ST.setFill(FL.lightFill, (god and 1) or (gcharge > 0 and gcharge) or (lit and 1 or charge))
		end
		local text
		if god then
			text = info.GodOut and ("MAX POWER  " .. tostring(info.GodOut) .. ": LIGHTSPEED") or "MAX POWER"
		elseif gcharge > 0 then
			text = string.format("GODSPEED  %d%%", math.floor(gcharge * 100))
		elseif lit then
			text = info.GodHint and (tostring(info.GodHint) .. ": GODSPEED") or "LIGHT BARRIER BROKEN"
		else
			text = charge > 0 and string.format("LIGHT BARRIER  %d%%", math.floor(charge * 100))
				or (info.Hint and ("DEV FLIGHT  " .. tostring(info.Hint) .. ": LIGHTSPEED") or "DEV FLIGHT")
		end
		FL.caption.Text = text
		FL.caption.TextTransparency = (god or gcharge > 0 or lit or charge > 0) and 0 or 0.4
	end

	---------------------------------------------------------------- the dev menus
	-- THE DEV MENUS' SKIN (the test menu, the roster, the events, the console:
	-- same parts, a light touch): ink and ink 2 for their navies, paper for
	-- their gold, Oswald / BuilderSans / BuilderMono for Gotham / Bangers /
	-- Code, no rounded corners, no strokes, no glow, no emoji. Their layout and
	-- their wiring stay as they are; rows built later get it as they come.
	MO.FACES = {
		Bangers = "Display", GothamBlack = "Display", GothamBold = "Display", LuckiestGuy = "Display", FredokaOne = "Display",
		GothamMedium = "Body", Gotham = "Body", PatrickHand = "Body", Code = "Mono",
	}
	local function darkish(c)
		return math.max(c.R, c.G, c.B) < 0.3
	end
	local function goldish(c)
		return c.R > 0.9 and c.G > 0.66 and c.G < 0.9 and c.B < 0.45
	end
	-- emoji and symbol glyphs out (Oswald hasn't got them); the X glyph a letter
	function MO.noEmoji(s)
		s = string.gsub(tostring(s or ""), "\226\156\149", "X")
		local out = {}
		for _, c in utf8.codes(ST.utf8(s)) do
			local drop = c >= 0x1F000 or (c >= 0x2300 and c <= 0x23FF) or (c >= 0x2600 and c <= 0x27BF) or (c >= 0xFE00 and c <= 0xFE0F) or c == 0x200D or c == 0x203A
			if not drop then
				table.insert(out, utf8.char(c))
			end
		end
		return (string.gsub(string.gsub(table.concat(out), "^%s+", ""), "%s+$", ""))
	end
	function MO.skinOne(d)
		if d:IsA("UICorner") then
			d:Destroy()
		elseif d:IsA("UIStroke") then
			d.Enabled = false
		elseif d:IsA("GuiObject") then
			if d.Name == "Glow" then
				d.Visible = false
			end
			d.BorderSizePixel = 0 -- (a rounded corner hid Roblox's 1 px border; square, it'd show)
			if (d:IsA("Frame") or d:IsA("ScrollingFrame") or d:IsA("TextButton") or d:IsA("TextBox")) and d.BackgroundTransparency < 1 then
				local c = d.BackgroundColor3
				if darkish(c) then
					d.BackgroundColor3 = (c.R + c.G + c.B) / 3 < 0.1 and tk().Ink or tk().Ink2
				elseif goldish(c) then
					d.BackgroundColor3 = tk().Paper
				end
			end
			if d:IsA("ScrollingFrame") then
				d.ScrollBarImageColor3 = tk().Paper
			end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				local ok, font = pcall(function()
					return d.Font
				end)
				local role
				for name, r in ok and MO.FACES or {} do
					local okE, item = pcall(function()
						return Enum.Font[name]
					end)
					if okE and item == font then
						role = r
						break
					end
				end
				if role and not d:GetAttribute("StreetFace") then
					-- (once: the same em as the Gotham it was - Oswald's line is taller for its em)
					d:SetAttribute("StreetFace", true)
					d.FontFace = ST.font(role)
					if role == "Display" and not d.TextScaled then
						d.TextSize = math.min(math.floor(d.TextSize * 1.2 + 0.5), 100)
					end
				end
				if goldish(d.TextColor3) then
					d.TextColor3 = tk().Paper
				end
				d.TextStrokeTransparency = 1
				if not d:IsA("TextBox") and not d.RichText then
					local clean = MO.noEmoji(d.Text)
					if clean ~= d.Text then
						d.Text = clean
					end
				end
			end
		end
	end
	function MO.skin(root)
		if not root or root:GetAttribute("StreetSkin") then
			return
		end
		root:SetAttribute("StreetSkin", true)
		pcall(MO.skinOne, root)
		for _, d in root:GetDescendants() do
			pcall(MO.skinOne, d)
		end
		-- (rows built later: Roblox tells the panel about each new descendant)
		root.DescendantAdded:Connect(function(d)
			pcall(MO.skinOne, d)
		end)
	end
	-- the skin again over everything under root (what was built before anyone was told)
	function MO.reskin(root)
		if not root then
			return
		end
		if not root:GetAttribute("StreetSkin") then
			return MO.skin(root)
		end
		for _, d in root:GetDescendants() do
			pcall(MO.skinOne, d)
		end
	end
end)()

return HUD
