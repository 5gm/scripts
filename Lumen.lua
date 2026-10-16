--[[
	Vanta
	A smooth, dark, code-built interface library for Roblox.

	Same API surface as Rayfield Gen2, different skin.

		local Vanta = loadstring(game:HttpGet("https://your.host/Vanta.lua"))()

		local window = Vanta:CreateWindow({
			name = "Example",
			subtitle = "Vanta",
			sidebarLayout = true,
		})

		local tab = window:CreateTab({ name = "Home", icon = 0 })

		tab:CreateButton({
			name = "Say hello",
			callback = function()
				window:Notify({ title = "Hello", content = "It works." })
			end,
		})

	Everything is drawn in code: no model, no assets, no icon packs required.
	Icons are optional and use whatever asset id you hand them.
]]

--// Services ---------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

--// Fonts ------------------------------------------------------------------

local FONT_BODY = Font.fromEnum(Enum.Font.Gotham)
local FONT_MEDIUM = Font.fromEnum(Enum.Font.GothamMedium)
local FONT_TITLE = Font.fromEnum(Enum.Font.GothamBold)
local FONT_MONO = Font.fromEnum(Enum.Font.RobotoMono)

--// Layout constants -------------------------------------------------------

local GAP = 8
local ELEMENT_HEIGHT = 46
local ELEMENT_HEIGHT_DESC = 62
local PAD = 12

--// Instance helpers -------------------------------------------------------

local function create(class, props, children)
	local inst = Instance.new(class)
	local parent

	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end

	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end

	if parent then
		inst.Parent = parent
	end

	return inst
end

local function corner(parent, radius)
	if type(radius) == "number" then
		radius = UDim.new(0, radius)
	end

	return create("UICorner", { CornerRadius = radius or UDim.new(0, 8), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function padding(parent, top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
		Parent = parent,
	})
end

local function gradient(parent, sequence, rotation)
	return create("UIGradient", {
		Color = sequence,
		Rotation = rotation or 0,
		Parent = parent,
	})
end

local function listLayout(parent, direction, gap, alignment)
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

--// Animation --------------------------------------------------------------

local function tween(inst, time, props, style, direction)
	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function afterLayout(fn)
	task.defer(function()
		RunService.RenderStepped:Wait()
		fn()
	end)
end

-- A tiny damped spring, stepped once per frame on a shared connection.
local Springs = {}

local Spring = {}
Spring.__index = Spring

function Spring.new(value, onUpdate, opts)
	local self = setmetatable({
		value = value or 0,
		target = value or 0,
		velocity = 0,
		onUpdate = onUpdate,
		stiffness = (opts and opts.stiffness) or 190,
		damping = (opts and opts.damping) or 24,
	}, Spring)

	Springs[self] = true

	if opts and opts.attach then
		opts.attach.Destroying:Connect(function()
			Springs[self] = nil
		end)
	end

	return self
end

function Spring:to(target)
	self.target = target
end

function Spring:snap(value)
	self.value = value
	self.target = value
	self.velocity = 0
	if self.onUpdate then
		self.onUpdate(value)
	end
end

function Spring:kill()
	Springs[self] = nil
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 30)

	for spring in next, Springs do
		local delta = spring.target - spring.value

		if math.abs(delta) < 0.0004 and math.abs(spring.velocity) < 0.0004 then
			if spring.value ~= spring.target then
				spring.value = spring.target
				spring.velocity = 0
				if spring.onUpdate then
					spring.onUpdate(spring.value)
				end
			end
		else
			spring.velocity = (spring.velocity + delta * spring.stiffness * dt)
				* math.exp(-spring.damping * dt)
			spring.value = spring.value + spring.velocity * dt

			if spring.onUpdate then
				spring.onUpdate(spring.value)
			end
		end
	end
end)

-- Manual colour tween, so a theme swap can breathe.
local function tweenColor(from, to, duration, apply, style)
	local startClock = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startClock) / duration, 0, 1)
		local eased = TweenService:GetValue(alpha, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		apply(from:Lerp(to, eased))

		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

--// Colour helpers ---------------------------------------------------------

local function fromHex(hex)
	if typeof(hex) == "Color3" then
		return hex
	end
	if type(hex) ~= "string" then
		return Color3.new(1, 1, 1)
	end

	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
	end

	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255

	return Color3.fromRGB(r, g, b)
end

local function toHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function luminance(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

local function contrastFor(color)
	return luminance(color) > 0.55 and Color3.fromRGB(16, 16, 22) or Color3.fromRGB(250, 250, 255)
end

local function toHSV(color)
	return Color3.toHSV(color)
end

--// Text -------------------------------------------------------------------

local function measureText(text, font, size, width)
	if not text or text == "" then
		return 0
	end

	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = math.max(width, 1)
	params.RichText = false

	local ok, bounds = pcall(function()
		return TextService:GetTextBoundsAsync(params)
	end)

	if ok and bounds then
		return bounds.Y
	end

	return #text * size * 0.52
end

--// Drawn icons ------------------------------------------------------------
-- Vanta does not need an icon pack for its own chrome. These are drawn from
-- frames so the finish stays crisp at any size.

local function bar(parent, width, thickness, color, angle, offset, radius)
	return create("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, offset and offset.X or 0, 0.5, offset and offset.Y or 0),
		Size = UDim2.fromOffset(width, thickness),
		Rotation = angle or 0,
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
end

local function glyphHolder(parent, size)
	return create("Frame", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
end

local function glyphClose(parent, color, size, thickness)
	local holder = glyphHolder(parent, size)
	local arm = size * 0.78
	bar(holder, arm, thickness, color, 45, Vector2.new(0, 0))
	bar(holder, arm, thickness, color, -45, Vector2.new(0, 0))
	return holder
end

local function glyphMinus(parent, color, size, thickness)
	local holder = glyphHolder(parent, size)
	bar(holder, size * 0.7, thickness, color, 0, Vector2.new(0, 0))
	return holder
end

local function glyphChevron(parent, color, size, thickness)
	local holder = glyphHolder(parent, size)
	local arm = size * 0.62
	bar(holder, arm, thickness, color, 45, Vector2.new(-arm * 0.24, 0))
	bar(holder, arm, thickness, color, -45, Vector2.new(arm * 0.24, 0))
	return holder
end

local function glyphCheck(parent, color, size, thickness)
	local holder = glyphHolder(parent, size)
	bar(holder, size * 0.5, thickness, color, -45, Vector2.new(-size * 0.16, size * 0.08))
	bar(holder, size * 0.9, thickness, color, 45, Vector2.new(size * 0.08, -size * 0.02))
	return holder
end

--// Ripple -----------------------------------------------------------------

local function ripple(frame, color, x, y, zIndex)
	local size = 6
	local r = create("Frame", {
		Name = "Ripple",
		BackgroundColor3 = color,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex or (frame.ZIndex + 1),
		Parent = frame,
	})
	corner(r, UDim.new(1, 0))

	local target = math.max(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) * 2.4
	tween(r, 0.55, {
		Size = UDim2.fromOffset(target, target),
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quart)

	task.delay(0.6, function()
		r:Destroy()
	end)
end

--// Shadow -----------------------------------------------------------------
-- Roblox has no drop shadow, so a soft dark halo is layered from a few
-- rounded frames. Cheap, and reads as depth against any backdrop.

local function makeShadow(parent, color, radius, strength)
	local layers = {}

	for i = 1, 5 do
		local spread = i * 3
		local drop = 8
		local layer = create("Frame", {
			Name = "Shadow" .. i,
			BackgroundColor3 = color,
			BackgroundTransparency = math.clamp(0.985 - (strength or 0.5) * 0.06 * (6 - i), 0, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, drop * 0.5),
			Size = UDim2.new(1, spread * 2, 1, spread * 2 + drop),
			ZIndex = 1,
			Parent = parent,
		})
		corner(layer, UDim.new(0, radius + spread))
		layers[i] = layer
	end

	return layers
end

--// Themes -----------------------------------------------------------------

local Themes = {}

Themes.default = {
	-- shape
	CornerWindow = UDim.new(0, 14),
	CornerElement = UDim.new(0, 10),
	CornerPill = UDim.new(1, 0),
	ShadowStrength = 0.85,

	-- window
	WindowTop = Color3.fromRGB(26, 25, 34),
	WindowBottom = Color3.fromRGB(11, 11, 15),
	WindowStroke = Color3.fromRGB(52, 51, 68),
	WindowStrokeTransparency = 0.35,
	Shadow = Color3.fromRGB(0, 0, 0),

	-- type
	TitleText = Color3.fromRGB(246, 245, 252),
	Text = Color3.fromRGB(227, 226, 238),
	TextDim = Color3.fromRGB(138, 137, 160),
	Placeholder = Color3.fromRGB(108, 107, 128),

	-- accent
	Accent = Color3.fromRGB(139, 92, 246),
	AccentAlt = Color3.fromRGB(56, 189, 248),
	AccentText = Color3.fromRGB(252, 251, 255),
	AccentGlowTransparency = 0.72,

	-- surfaces
	Surface = Color3.fromRGB(33, 32, 43),
	SurfaceTransparency = 0.35,
	SurfaceHover = Color3.fromRGB(46, 45, 60),
	SurfaceHoverTransparency = 0.1,
	ElementStroke = Color3.fromRGB(60, 59, 78),
	ElementStrokeTransparency = 0.35,
	ElementStrokeHover = Color3.fromRGB(104, 100, 138),
	ElementStrokeHoverTransparency = 0.05,

	-- tabs
	TabText = Color3.fromRGB(146, 145, 168),
	TabTextActive = Color3.fromRGB(255, 255, 255),
	TabFill = Color3.fromRGB(46, 45, 62),
	TabFillTransparency = 0.8,
	RailWidth = 188,

	-- controls
	ToggleTrackOff = Color3.fromRGB(62, 61, 80),
	ToggleTrackOffTransparency = 0.15,
	ToggleKnobOff = Color3.fromRGB(154, 153, 176),
	SliderTrack = Color3.fromRGB(55, 54, 72),
	SliderTrackTransparency = 0.15,
	SliderHandle = Color3.fromRGB(247, 246, 253),

	FieldFill = Color3.fromRGB(20, 19, 26),
	FieldFillTransparency = 0.05,
	FieldStroke = Color3.fromRGB(56, 55, 72),

	Divider = Color3.fromRGB(52, 51, 68),
	DividerTransparency = 0.45,

	Danger = Color3.fromRGB(248, 113, 113),
	Success = Color3.fromRGB(74, 222, 160),
	Warning = Color3.fromRGB(251, 191, 36),

	ModalDim = Color3.fromRGB(0, 0, 0),
	ModalDimTransparency = 0.45,
}

Themes.cobalt = table.clone(Themes.default)
Themes.cobalt.Accent = Color3.fromRGB(45, 156, 245)
Themes.cobalt.AccentAlt = Color3.fromRGB(56, 220, 226)
Themes.cobalt.WindowTop = Color3.fromRGB(22, 28, 38)
Themes.cobalt.Surface = Color3.fromRGB(28, 34, 46)
Themes.cobalt.SurfaceHover = Color3.fromRGB(38, 47, 63)
Themes.cobalt.ElementStroke = Color3.fromRGB(52, 64, 84)

Themes.ember = table.clone(Themes.default)
Themes.ember.Accent = Color3.fromRGB(249, 115, 22)
Themes.ember.AccentAlt = Color3.fromRGB(244, 63, 94)
Themes.ember.WindowTop = Color3.fromRGB(36, 26, 24)
Themes.ember.Surface = Color3.fromRGB(43, 32, 30)
Themes.ember.SurfaceHover = Color3.fromRGB(58, 42, 38)
Themes.ember.ElementStroke = Color3.fromRGB(80, 58, 52)

Themes.amethyst = table.clone(Themes.default)
Themes.amethyst.Accent = Color3.fromRGB(196, 92, 246)
Themes.amethyst.AccentAlt = Color3.fromRGB(129, 140, 248)
Themes.amethyst.Surface = Color3.fromRGB(38, 30, 50)

Themes.frost = table.clone(Themes.default)
Themes.frost.Accent = Color3.fromRGB(56, 189, 248)
Themes.frost.AccentAlt = Color3.fromRGB(165, 243, 252)
Themes.frost.WindowBottom = Color3.fromRGB(14, 18, 24)

Themes.rose = table.clone(Themes.default)
Themes.rose.Accent = Color3.fromRGB(244, 114, 182)
Themes.rose.AccentAlt = Color3.fromRGB(251, 146, 60)
Themes.rose.Surface = Color3.fromRGB(46, 30, 42)

Themes.mono = table.clone(Themes.default)
Themes.mono.Accent = Color3.fromRGB(203, 213, 225)
Themes.mono.AccentAlt = Color3.fromRGB(148, 163, 184)
Themes.mono.AccentText = Color3.fromRGB(18, 18, 24)
Themes.mono.Surface = Color3.fromRGB(34, 34, 38)

-- Names Rayfield Gen2 ships, plus a couple of our own, so old scripts still land.
local THEME_ALIASES = {
	ocean = "cobalt",
	dark = "default",
	light = "mono",
}

-- Gen2 speaks a different set of theme keys. Translate the ones that map cleanly
-- so a Gen2-style custom theme still lands somewhere sensible.
local GEN2_THEME_KEYS = {
	AccentColor = "Accent",
	AccentStroke = "Accent",
	AccentGlow = "AccentGlowTransparency",
	ContentColor = "Text",
	TitlingColor = "TitleText",
	ElementTextHoverColor = "Text",
	ActionColor = "TextDim",
	TabColor = "TabText",
	StatBackground = "SurfaceHover",
	FieldBackground = "FieldFill",
	FieldTransparency = "FieldFillTransparency",
	PlaceholderColor = "Placeholder",
	SliderBackground = "SliderTrack",
	SliderBackgroundHover = "SliderTrack",
	SliderHandle = "SliderHandle",
	ToggleTrack = "ToggleTrackOff",
	ToggleTrackTransparency = "ToggleTrackOffTransparency",
	ToggleKnobOff = "ToggleKnobOff",
	DropdownHighlight = "Accent",
	ErrorColor = "Danger",
	ShadowColor = "Shadow",
	CornerRoundness = "CornerWindow",
	ElementCornerRadius = "CornerElement",
	PillCornerRadius = "CornerPill",
	ElementTransparency = "SurfaceTransparency",
}

local function normalizeThemeTable(value)
	local out = {}

	for key, item in pairs(value) do
		if typeof(item) == "ColorSequence" then
			-- Gen2 widens a flat Color3 into a sequence; we only keep colours.
			item = item.Keypoints[1].Value
		end

		out[GEN2_THEME_KEYS[key] or key] = item
	end

	return out
end

-- Corner keys must be UDims, but a Gen2-style theme may hand us a plain number.
local function coerceCorner(value, fallback)
	if typeof(value) == "UDim" then
		return value
	end

	if type(value) == "number" then
		return UDim.new(0, value)
	end

	return fallback
end

local function coerceTheme(theme)
	theme.CornerWindow = coerceCorner(theme.CornerWindow, UDim.new(0, 14))
	theme.CornerElement = coerceCorner(theme.CornerElement, UDim.new(0, 10))
	theme.CornerPill = coerceCorner(theme.CornerPill, UDim.new(1, 0))
	return theme
end

local function resolveTheme(value)
	if type(value) == "table" then
		local merged = table.clone(Themes.default)
		for key, item in pairs(normalizeThemeTable(value)) do
			merged[key] = item
		end
		return coerceTheme(merged)
	end

	if type(value) == "string" then
		local key = value:lower()
		key = THEME_ALIASES[key] or key
		return coerceTheme(table.clone(Themes[key] or Themes.default))
	end

	return coerceTheme(table.clone(Themes.default))
end

--// Library ----------------------------------------------------------------

local Vanta = {}
Vanta.__index = Vanta
Vanta.Version = "1.0.0"
Vanta.Themes = Themes

-- Forward declarations, so methods can reference builders defined further down.
local createElement
local Tab
local Group

local function createGui()
	local candidates = {}

	if gethui then
		table.insert(candidates, function()
			return gethui()
		end)
	end

	table.insert(candidates, function()
		return game:GetService("CoreGui")
	end)

	table.insert(candidates, function()
		return Players.LocalPlayer:WaitForChild("PlayerGui")
	end)

	for _, resolve in ipairs(candidates) do
		local ok, parent = pcall(resolve)

		if ok and parent then
			local gui = Instance.new("ScreenGui")
			gui.Name = "Vanta"
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = true
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.DisplayOrder = 9999

			local placed = pcall(function()
				gui.Parent = parent
			end)

			if placed then
				return gui
			end

			gui:Destroy()
		end
	end

	return nil
end

--// Window -----------------------------------------------------------------

local Window = {}
Window.__index = function(self, key)
	if key == "unloaded" then
		return self._unloaded
	end

	return Window[key]
end

local RAIL_ITEM_HEIGHT = 38
local RAIL_ITEM_GAP = 4

local TOPBAR_HEIGHT = 56
local STRIP_HEIGHT = 48

function Window:_bind(key, apply, owner)
	local binding = {
		key = key,
		apply = apply,
		current = self._theme[key],
	}
	table.insert(self._bindings, binding)

	-- Short-lived pieces (cards, toasts, popups, dropdown rows) hand us the frame
	-- they paint, so the binding can retire itself instead of piling up forever.
	if owner then
		owner.Destroying:Connect(function()
			local list = self._bindings

			for index = #list, 1, -1 do
				if list[index] == binding then
					table.remove(list, index)
				end
			end
		end)
	end

	if binding.current ~= nil then
		apply(binding.current)
	end

	return binding
end

function Window:_pushTheme(theme, animate)
	for _, binding in ipairs(self._bindings) do
		local target = theme[binding.key]

		if target ~= nil then
			if typeof(target) == "Color3" then
				local from = binding.current
				if typeof(from) == "Color3" then
					if animate and from ~= target then
						tweenColor(from, target, 0.5, binding.apply)
					else
						binding.apply(target)
					end
				else
					binding.apply(target)
				end
			else
				binding.apply(target)
			end

			binding.current = target
		end
	end
end

function Window:_syncIndicator(instant)
	if not self._activeTab then
		return
	end

	local tab = self._activeTab

	if self._sidebar then
		local rail = self._rail
		local button = tab._button

		if not (rail and button) then
			return
		end

		local targetY = button.Position.Y.Offset

		if instant then
			self._railIndicator.Position = UDim2.fromOffset(0, targetY)
		else
			tween(self._railIndicator, 0.34, {
				Position = UDim2.fromOffset(0, targetY),
			}, Enum.EasingStyle.Quint)
		end
	else
		local strip = self._strip
		local list = self._tabList
		local button = tab._button

		if not (strip and list and button) then
			return
		end

		local size = button.AbsoluteSize
		local position = button.AbsolutePosition - strip.AbsolutePosition

		if size.X <= 0 then
			afterLayout(function()
				if not self._unloaded then
					self:_syncIndicator(instant)
				end
			end)
			return
		end

		if instant then
			local indicator = self._stripIndicator
			indicator.Position = UDim2.fromOffset(position.X, position.Y)
			indicator.Size = UDim2.fromOffset(size.X, size.Y)
		else
			tween(self._stripIndicator, 0.34, {
				Position = UDim2.fromOffset(position.X, position.Y),
				Size = UDim2.fromOffset(size.X, size.Y),
			}, Enum.EasingStyle.Quint)
		end
	end
end

function Window:_createAction(parent, order, buildGlyph, onClick, tooltip)
	local button = create("TextButton", {
		Name = tooltip or "Action",
		BackgroundColor3 = self._theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(28, 28),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16 - (order - 1) * 30, 0.5, 0),
		Parent = parent,
	})
	corner(button, UDim.new(0, 8))

	local glyph = buildGlyph(button)

	self:_bind("TextDim", function(color)
		for _, child in ipairs(glyph:GetChildren()) do
			if child:IsA("Frame") then
				child.BackgroundColor3 = color
			end
		end
	end)

	button.MouseEnter:Connect(function()
		tween(button, 0.15, { BackgroundTransparency = 0.82, BackgroundColor3 = self._theme.Accent })
		for _, child in ipairs(glyph:GetChildren()) do
			if child:IsA("Frame") then
				tween(child, 0.15, { BackgroundColor3 = self._theme.TitleText })
			end
		end
	end)

	button.MouseLeave:Connect(function()
		tween(button, 0.2, { BackgroundTransparency = 1 })
		for _, child in ipairs(glyph:GetChildren()) do
			if child:IsA("Frame") then
				tween(child, 0.2, { BackgroundColor3 = self._theme.TextDim })
			end
		end
	end)

	button.MouseButton1Click:Connect(onClick)

	return button
end

function Window:_build()
	local self_ = self
	local theme = self._theme

	-- root -----------------------------------------------------------------
	local root = create("Frame", {
		Name = "WindowRoot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self._width + 48, self._height + 48),
		Parent = self._gui,
	})
	self._root = root

	create("UIScale", { Scale = 0.94, Parent = root })
	afterLayout(function()
		local scale = root:FindFirstChildOfClass("UIScale")
		if scale then
			tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)

	makeShadow(root, theme.Shadow, 14, theme.ShadowStrength)

	-- the fade shell also does the clipping, so minimise is just a resize ---
	local fade = create("CanvasGroup", {
		Name = "Shell",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self._width, self._height),
		GroupTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	})
	self._fade = fade

	afterLayout(function()
		tween(fade, 0.35, { GroupTransparency = 0 })
	end)

	local main = create("Frame", {
		Name = "Main",
		BackgroundColor3 = theme.WindowTop,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = fade,
	})
	self._main = main
	corner(main, theme.CornerWindow)

	local windowGradient = gradient(main, ColorSequence.new(theme.WindowTop, theme.WindowBottom), 90)
	self:_bind("WindowTop", function(color)
		windowGradient.Color = ColorSequence.new(color, self._theme.WindowBottom)
	end)
	self:_bind("WindowBottom", function(color)
		windowGradient.Color = ColorSequence.new(self._theme.WindowTop, color)
	end)

	-- a faint rim of accent light along the top edge
	local sheen = create("Frame", {
		Name = "Sheen",
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -2, 0, 1),
		Position = UDim2.new(0, 1, 0, 0),
		ZIndex = 2,
		Parent = main,
	})
	local sheenGradient = gradient(sheen, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	}), 0)
	sheenGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})

	self:_bind("Accent", function(color)
		sheen.BackgroundColor3 = color
	end)

	local mainStroke = stroke(main, theme.WindowStroke, 1, theme.WindowStrokeTransparency)
	mainStroke.ZIndex = 2

	self:_bind("WindowStroke", function(color)
		mainStroke.Color = color
	end)
	self:_bind("WindowStrokeTransparency", function(value)
		mainStroke.Transparency = value
	end)

	-- top bar --------------------------------------------------------------
	local topbar = create("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
		ZIndex = 4,
		Parent = main,
	})
	self._topbar = topbar

	local titleHolder = create("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 1, 0),
		Parent = topbar,
	})

	local hasSubtitle = self._subtitle ~= nil and self._subtitle ~= ""

	local titleRow = create("Frame", {
		Name = "TitleRow",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = hasSubtitle and UDim2.new(0, 17, 0, 12) or UDim2.new(0, 17, 0.5, 0),
		AnchorPoint = hasSubtitle and Vector2.new(0, 0) or Vector2.new(0, 0.5),
		Parent = titleHolder,
	})
	listLayout(titleRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)

	local titleIcon = self._icon
	if titleIcon and titleIcon ~= 0 and titleIcon ~= "" then
		create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			Image = self:_resolveIcon(titleIcon),
			LayoutOrder = 0,
			Parent = titleRow,
		})
	end

	local title = create("TextLabel", {
		Name = "TitleText",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = FONT_TITLE,
		Text = self._name,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 1,
		Parent = titleRow,
	})
	self._titleLabel = title
	self:_bind("TitleText", function(color)
		title.TextColor3 = color
	end)

	local tagHolder = create("Frame", {
		Name = "Tags",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = titleRow,
	})
	listLayout(tagHolder, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	self._tagHolder = tagHolder

	if hasSubtitle then
		local subtitle = create("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 0, 14),
			Position = UDim2.new(0, 18, 0, 32),
			FontFace = FONT_BODY,
			Text = self._subtitle,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = titleHolder,
		})
		self:_bind("TextDim", function(color)
			subtitle.TextColor3 = color
		end)
	end

	self:_createAction(topbar, 1, function(parent)
		return glyphMinus(parent, theme.TextDim, 12, 1.6)
	end, function()
		self_:ToggleMinimise()
	end, "Minimise")

	self:_createAction(topbar, 2, function(parent)
		return glyphClose(parent, theme.TextDim, 11, 1.6)
	end, function()
		self_:Hide()
	end, "Hide")

	if not self._sidebar then
		local hairline = create("Frame", {
			Name = "Hairline",
			BackgroundColor3 = theme.Divider,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -24, 0, 1),
			Position = UDim2.new(0, 12, 0, TOPBAR_HEIGHT - 1),
			ZIndex = 3,
			Parent = main,
		})
		self:_bind("Divider", function(color)
			hairline.BackgroundColor3 = color
		end)
		self:_bind("DividerTransparency", function(value)
			hairline.BackgroundTransparency = value
		end)
	end

	-- body places ----------------------------------------------------------
	local bodyTop = TOPBAR_HEIGHT

	if self._sidebar then
		self._content = create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, self._railWidth, 0, bodyTop),
			Size = UDim2.new(1, -self._railWidth, 1, -bodyTop),
			ZIndex = 3,
			Parent = main,
		})
	else
		local strip = create("Frame", {
			Name = "TabStrip",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, bodyTop),
			Size = UDim2.new(1, 0, 0, STRIP_HEIGHT),
			ZIndex = 3,
			Parent = main,
		})
		self._strip = strip

		local indicator = create("Frame", {
			Name = "Indicator",
			BackgroundColor3 = theme.Accent,
			BackgroundTransparency = theme.TabFillTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 3,
			Visible = false,
			Parent = strip,
		})
		corner(indicator, theme.CornerPill)
		self._stripIndicator = indicator

		-- The active tab is an accent wash, never a grey block.
		self:_bind("Accent", function(color)
			indicator.BackgroundColor3 = color
		end)
		self:_bind("TabFillTransparency", function(value)
			indicator.BackgroundTransparency = value
		end)
		self:_bind("CornerPill", function(radius)
			indicator:FindFirstChildOfClass("UICorner").CornerRadius = radius
		end)

		local tabList = create("ScrollingFrame", {
			Name = "TabList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ZIndex = 4,
			Parent = strip,
		})
		padding(tabList, 12, 8, 8, 8)
		self._tabList = tabList

		listLayout(tabList, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)

		self._content = create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, bodyTop + STRIP_HEIGHT),
			Size = UDim2.new(1, 0, 1, -(bodyTop + STRIP_HEIGHT)),
			ZIndex = 3,
			Parent = main,
		})

		tabList:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self_:_syncIndicator(true)
		end)
	end

	self._content.ZIndex = 3

	-- overlays live outside the shell so they can spill past the window ----
	self._notifyHolder = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 500),
		ZIndex = 50,
		Parent = self._gui,
	})
	listLayout(self._notifyHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)

	self._toastHolder = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(360, 300),
		ZIndex = 60,
		Parent = self._gui,
	})
	listLayout(self._toastHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
	self._toastHolderTop = self._toastHolder

	self._toastHolderBottom = create("Frame", {
		Name = "ToastsBottom",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(360, 300),
		ZIndex = 60,
		Parent = self._gui,
	})
	listLayout(self._toastHolderBottom, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)

	self._popupHolder = create("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Visible = false,
		Parent = self._gui,
	})

	self:_buildSidebar()
end

function Window:_buildSidebar()
	if not self._sidebar then
		return
	end

	local theme = self._theme

	local rail = create("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, TOPBAR_HEIGHT),
		Size = UDim2.new(0, self._railWidth, 1, -TOPBAR_HEIGHT),
		ZIndex = 3,
		Parent = self._main,
	})
	self._rail = rail

	local divider = create("Frame", {
		Name = "RailEdge",
		BackgroundColor3 = theme.Divider,
		BackgroundTransparency = theme.DividerTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, -24),
		Position = UDim2.new(1, -1, 0, 12),
		Parent = rail,
	})
	self:_bind("Divider", function(color)
		divider.BackgroundColor3 = color
	end)
	self:_bind("DividerTransparency", function(value)
		divider.BackgroundTransparency = value
	end)

	local railScroll = create("ScrollingFrame", {
		Name = "RailScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 8),
		Size = UDim2.new(1, 0, 1, -74),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.ElementStroke,
		ScrollBarImageTransparency = 0.4,
		ZIndex = 4,
		Parent = rail,
	})
	padding(railScroll, 0, 10, 0, 10)
	self._railScroll = railScroll

	local railIndicator = create("Frame", {
		Name = "RailIndicator",
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = theme.TabFillTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, RAIL_ITEM_HEIGHT),
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 1,
		Visible = false,
		Parent = railScroll,
	})
	corner(railIndicator, UDim.new(0, 9))
	self._railIndicator = railIndicator

	local accentPip = create("Frame", {
		Name = "Pip",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		ZIndex = 3,
		Parent = railIndicator,
	})
	corner(accentPip, UDim.new(1, 0))
	self:_bind("Accent", function(color)
		accentPip.BackgroundColor3 = color
		railIndicator.BackgroundColor3 = color
	end)

	self:_bind("TabFillTransparency", function(value)
		railIndicator.BackgroundTransparency = value
	end)

	-- profile card ---------------------------------------------------------
	local player = Players.LocalPlayer
	local card = create("Frame", {
		Name = "Profile",
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 52),
		ZIndex = 4,
		Parent = rail,
	})
	corner(card, UDim.new(0, 10))
	local cardStroke = stroke(card, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

	local avatar = create("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = theme.FieldFill,
		BackgroundTransparency = theme.FieldFillTransparency,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(34, 34),
		Image = player
				and ("rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150")
			or "",
		Parent = card,
	})
	corner(avatar, UDim.new(1, 0))

	local nameLabel = create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 50, 0, 10),
		Size = UDim2.new(1, -58, 0, 16),
		FontFace = FONT_MEDIUM,
		Text = player and player.DisplayName or "Player",
		TextSize = 12.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	local profileLabel = create("TextLabel", {
		Name = "Profile",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 50, 0, 26),
		Size = UDim2.new(1, -58, 0, 14),
		FontFace = FONT_BODY,
		Text = self._profile or ("@" .. (player and player.Name or "player")),
		TextSize = 10.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	self:_bind("ElementStroke", function(color)
		cardStroke.Color = color
	end)
	self:_bind("ElementStrokeTransparency", function(value)
		cardStroke.Transparency = value
	end)
	self:_bind("Surface", function(color)
		card.BackgroundColor3 = color
	end)
	self:_bind("SurfaceTransparency", function(value)
		card.BackgroundTransparency = value
	end)
	self:_bind("Text", function(color)
		nameLabel.TextColor3 = color
	end)
	self:_bind("TextDim", function(color)
		profileLabel.TextColor3 = color
	end)

	self._profileLabel = profileLabel
	self._profileCard = card
end

--// Window: lifecycle ------------------------------------------------------

function Window:_buildPill()
	local theme = self._theme

	local pill = create("CanvasGroup", {
		Name = "Pill",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = self._showIconOnly and UDim2.fromOffset(44, 44) or UDim2.fromOffset(112, 40),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = self._gui,
	})
	self._pill = pill

	local body = create("Frame", {
		Name = "Body",
		BackgroundColor3 = theme.WindowTop,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = pill,
	})
	corner(body, theme.CornerPill)
	local pillStroke = stroke(body, theme.WindowStroke, 1, theme.WindowStrokeTransparency)

	local pillGradient = gradient(body, ColorSequence.new(theme.WindowTop, theme.WindowBottom), 90)
	self:_bind("WindowTop", function(color)
		pillGradient.Color = ColorSequence.new(color, self._theme.WindowBottom)
	end)
	self:_bind("WindowBottom", function(color)
		pillGradient.Color = ColorSequence.new(self._theme.WindowTop, color)
	end)
	self:_bind("WindowStroke", function(color)
		pillStroke.Color = color
	end)
	self:_bind("WindowStrokeTransparency", function(value)
		pillStroke.Transparency = value
	end)
	self:_bind("CornerPill", function(radius)
		body:FindFirstChildOfClass("UICorner").CornerRadius = radius
	end)

	listLayout(body, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)

	local iconValue = self._showIcon
	if iconValue and iconValue ~= 0 and iconValue ~= "" then
		local icon = create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(20, 20),
			Image = self:_resolveIcon(iconValue),
			LayoutOrder = 1,
			Parent = body,
		})
		self:_bind("Accent", function(color)
			icon.ImageColor3 = color
		end)
	else
		local dot = create("Frame", {
			Name = "Dot",
			BackgroundColor3 = theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
			LayoutOrder = 1,
			Parent = body,
		})
		corner(dot, UDim.new(1, 0))
		self:_bind("Accent", function(color)
			dot.BackgroundColor3 = color
		end)
	end

	if not self._showIconOnly then
		local label = create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			FontFace = FONT_MEDIUM,
			Text = self._showName,
			TextSize = 12,
			LayoutOrder = 2,
			Parent = body,
		})
		self:_bind("TitleText", function(color)
			label.TextColor3 = color
		end)
	end

	-- dragging the pill ---------------------------------------------------
	local dragging, dragStart, startPosition

	body.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = pill.Position
			self._pillMoved = 0
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local delta = input.Position - dragStart
			self._pillMoved = math.abs(delta.X) + math.abs(delta.Y)
			pill.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)

	body.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false

			if (self._pillMoved or 0) < 6 then
				self:Show()
			end
		end
	end)

	return pill
end

function Window:Show()
	if self._unloaded then
		return
	end

	self._hidden = false

	if self._pill then
		tween(self._pill, 0.18, { GroupTransparency = 1 })
		task.delay(0.18, function()
			if self._hidden and self._pill then
				self._pill.Visible = false
			end
		end)
	end

	local root = self._root
	root.Visible = true

	local scale = root:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.94
		tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	tween(self._fade, 0.28, { GroupTransparency = 0 })
end

function Window:Hide()
	if self._unloaded then
		return
	end

	self._hidden = true

	tween(self._fade, 0.22, { GroupTransparency = 1 })

	local root = self._root
	local scale = root:FindFirstChildOfClass("UIScale")
	if scale then
		tween(scale, 0.28, { Scale = 0.94 }, Enum.EasingStyle.Quad)
	end

	if self._pill then
		self._pill.Visible = true
		self._pill.GroupTransparency = 1
		tween(self._pill, 0.32, { GroupTransparency = 0 })
	end

	task.delay(0.3, function()
		if self._hidden and root then
			root.Visible = false
		end
	end)
end

function Window:ToggleHide()
	if self._hidden then
		self:Show()
	else
		self:Hide()
	end
end

function Window:ToggleMinimise()
	if self._minimised then
		self._minimised = false
		tween(self._fade, 0.45, {
			Size = UDim2.fromOffset(self._width, self._height),
		}, Enum.EasingStyle.Quint)
		tween(self._root, 0.45, {
			Size = UDim2.fromOffset(self._width + 48, self._height + 48),
		}, Enum.EasingStyle.Quint)
	else
		self._minimised = true
		tween(self._fade, 0.42, {
			Size = UDim2.fromOffset(self._width, TOPBAR_HEIGHT),
		}, Enum.EasingStyle.Quint)
		tween(self._root, 0.42, {
			Size = UDim2.fromOffset(self._width + 48, TOPBAR_HEIGHT + 48),
		}, Enum.EasingStyle.Quint)
	end
end

function Window:Unload()
	if self._unloaded then
		return
	end

	self._unloaded = true
	self._bindings = {}

	for _, element in pairs(self._elements) do
		element._dead = true
	end

	self._elements = {}
	self._tabs = {}

	if self._gui then
		self._gui:Destroy()
	end
end

function Window:ChangeTheme(value)
	if type(value) ~= "string" and type(value) ~= "table" then
		return
	end

	local incoming

	if type(value) == "string" then
		local key = string.lower(value)
		key = THEME_ALIASES[key] or key
		self._themeName = Themes[key] and key or "default"
		incoming = Themes[self._themeName]
	else
		-- A partial table overlays the current theme; a name resets omitted keys.
		self._themeName = nil
		incoming = normalizeThemeTable(value)
	end

	-- Mutate the window's own theme table in place, so references captured while
	-- building elements stay live and repaint with the new palette.
	local theme = self._theme

	for key, item in pairs(incoming) do
		theme[key] = item
	end

	coerceTheme(theme)

	self:_pushTheme(theme, true)
end

function Window:_resolveIcon(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end

	if type(icon) == "string" then
		if icon == "" then
			return ""
		end
		if icon:match("^rbx") or icon:match("^http") then
			return icon
		end
		if tonumber(icon) then
			return "rbxassetid://" .. icon
		end
		return icon
	end

	return ""
end

--// Flags, saving and localization ------------------------------------------

local hasFilesystem = type(writefile) == "function" and type(readfile) == "function"

local function ensureFolder(path)
	if type(makefolder) ~= "function" then
		return
	end

	local current = ""
	for part in string.gmatch(path, "[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		if type(isfolder) ~= "function" or not isfolder(current) then
			pcall(makefolder, current)
		end
	end
end

local function encodeValue(value)
	local kind = typeof(value)

	if kind == "Color3" then
		return { __vanta = "color", value = toHex(value) }
	end

	if kind == "EnumItem" then
		return { __vanta = "enum", value = value.EnumType.Name .. "." .. value.Name }
	end

	if kind == "table" then
		local out = {}
		for key, item in pairs(value) do
			out[key] = encodeValue(item)
		end
		return out
	end

	return value
end

local function decodeValue(value)
	if type(value) == "table" and value.__vanta == "color" then
		return fromHex(value.value)
	end

	if type(value) == "table" and value.__vanta == "enum" then
		local enumType, name = string.match(value.value, "^([^.]+)%.(.+)$")
		if enumType then
			local enum = Enum[enumType]
			local item = enum and enum[name]
			if item then
				return item
			end
		end
		return value
	end

	if type(value) == "table" then
		local out = {}
		for key, item in pairs(value) do
			out[key] = decodeValue(item)
		end
		return out
	end

	return value
end

local function makeFlags(window)
	return setmetatable({}, {
		__index = function(_, key)
			return window._values[key]
		end,
		__newindex = function(_, key, value)
			local element = window._elements[key]
			if element and element.Set then
				element:Set(value)
			else
				window._values[key] = value
			end
		end,
		__iter = function()
			return next, window._values, nil
		end,
	})
end

function Window:_registerLabel(apply, source)
	table.insert(self._labelBindings, { apply = apply, source = source })
	apply(self:_translate(source))
end

function Window:_translate(source)
	if source == nil then
		return nil
	end

	if self._translator then
		local ok, result = pcall(self._translator, source, self._locale)
		if ok and type(result) == "string" then
			return result
		end
	end

	local pack = self._translations[self._locale]
	if not pack then
		local base = string.match(self._locale, "^(%a+)")
		pack = base and self._translations[base] or nil
	end

	if pack and pack[source] then
		return pack[source]
	end

	return source
end

function Window:SetLocale(id)
	self._locale = tostring(id or "en"):lower()

	for _, binding in ipairs(self._labelBindings) do
		binding.apply(self:_translate(binding.source))
	end
end

function Window:RegisterTranslations(pack)
	for locale, table_ in pairs(pack or {}) do
		self._translations[string.lower(locale)] = table_
	end
	self:SetLocale(self._locale)
end

function Window:SetTranslator(fn)
	self._translator = fn
	self:SetLocale(self._locale)
end

function Window:_configFolderPath()
	local folder = "Vanta/Configurations"
	if self._configFolder then
		folder = folder .. "/" .. self._configFolder
	end
	return folder
end

function Window:_configFilePath(name)
	return self:_configFolderPath() .. "/" .. (name or self._configFile or self._name) .. ".rfld"
end

function Window:GetPath()
	return self:_configFolderPath(), self:_configFilePath(nil)
end

function Window:Save(name)
	if not hasFilesystem then
		return false
	end

	local payload = {}

	for flag, value in pairs(self._values) do
		payload[flag] = encodeValue(value)
	end

	local encoded = HttpService:JSONEncode(payload)

	ensureFolder(self:_configFolderPath())

	return (pcall(function()
		writefile(self:_configFilePath(name), encoded)
	end))
end

function Window:Load(name)
	if not hasFilesystem then
		return false
	end

	local path = self:_configFilePath(name)

	if type(isfile) == "function" and not isfile(path) then
		return false
	end

	local ok, contents = pcall(readfile, path)
	if not ok or type(contents) ~= "string" then
		return false
	end

	local decoded, data = pcall(function()
		return HttpService:JSONDecode(contents)
	end)

	if not decoded or type(data) ~= "table" then
		return false
	end

	for flag, value in pairs(data) do
		self:Set(flag, decodeValue(value))
	end

	return true
end

function Window:ListConfigs()
	local results = {}

	if not hasFilesystem or type(listfiles) ~= "function" then
		return results
	end

	local ok, files = pcall(listfiles, self:_configFolderPath())

	if ok and type(files) == "table" then
		for _, file in ipairs(files) do
			local name = string.match(file, "([^/\\]+)%.rfld$")
			if name then
				table.insert(results, name)
			end
		end
	end

	return results
end

function Window:DeleteConfig(name)
	if not hasFilesystem or type(delfile) ~= "function" then
		return false
	end

	return (pcall(delfile, self:_configFilePath(name)))
end

function Window:Get(flag)
	return self._values[flag]
end

function Window:Set(flag, value)
	local element = self._elements[flag]

	if not element or not element.Set then
		return false
	end

	element:Set(value)
	return true
end

function Window:_markDirty()
	if not self._autoSave or self._unloaded then
		return
	end

	self._saveDue = os.clock() + 0.6

	if self._saveTask then
		return
	end

	self._saveTask = task.spawn(function()
		repeat
			task.wait(0.2)
		until os.clock() >= (self._saveDue or 0)

		self._saveTask = nil
		self:Save()
	end)
end

--// Window: notifications and toasts ----------------------------------------

function Window:Notify(props)
	props = props or {}

	local theme = self._theme
	local content = tostring(props.content or "")
	local duration = props.duration or math.clamp(3 + math.floor(#content / 24), 3, 9)

	local card = create("CanvasGroup", {
		Name = "Notification",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1,
		LayoutOrder = #self._notifyHolder:GetChildren(),
		Parent = self._notifyHolder,
	})

	local height = 34
	if content ~= "" then
		height += math.ceil(measureText(content, FONT_BODY, 11.5, 240) / 15) * 15 + 4
	end

	local body = create("Frame", {
		Name = "Body",
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Parent = card,
	})
	corner(body, UDim.new(0, 10))
	local bodyStroke = stroke(body, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

	local pip = create("Frame", {
		Name = "Pip",
		BackgroundColor3 = fromHex(props.color or theme.Accent),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 22),
		Parent = body,
	})
	corner(pip, UDim.new(1, 0))

	local textLeft = 16
	local icon = props.icon

	if icon and icon ~= 0 and icon ~= "" then
		create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 11),
			Size = UDim2.fromOffset(16, 16),
			Image = self:_resolveIcon(icon),
			Parent = body,
		})
		textLeft = 36
	end

	local titleLabel = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, textLeft, 0, 11),
		Size = UDim2.new(1, -(textLeft + 12), 0, 16),
		FontFace = FONT_MEDIUM,
		Text = tostring(props.title or ""),
		TextColor3 = theme.TitleText,
		TextSize = 12.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})

	local contentLabel
	if content ~= "" then
		contentLabel = create("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, textLeft, 0, 29),
			Size = UDim2.new(1, -(textLeft + 12), 0, height - 37),
			FontFace = FONT_BODY,
			Text = content,
			TextColor3 = theme.TextDim,
			TextSize = 11.5,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = body,
		})
	end

	self:_bind("Surface", function(color)
		if body.Parent then
			body.BackgroundColor3 = color
		end
	end, card)
	self:_bind("ElementStroke", function(color)
		if body.Parent then
			bodyStroke.Color = color
		end
	end, card)
	self:_bind("TitleText", function(color)
		if titleLabel.Parent then
			titleLabel.TextColor3 = color
		end
	end, card)
	self:_bind("TextDim", function(color)
		if contentLabel and contentLabel.Parent then
			contentLabel.TextColor3 = color
		end
	end, card)

	local scale = create("UIScale", { Scale = 0.95, Parent = body })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(card, 0.3, { GroupTransparency = 0 })

	local dismissing = false
	local function dismiss()
		if dismissing then
			return
		end
		dismissing = true
		tween(scale, 0.22, { Scale = 0.96 })
		tween(card, 0.24, { GroupTransparency = 1 })
		task.delay(0.26, function()
			card:Destroy()
		end)
	end

	local paused = false
	body.MouseEnter:Connect(function()
		paused = true
	end)
	body.MouseLeave:Connect(function()
		paused = false
	end)

	body.Active = true
	body.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dismiss()
		end
	end)

	task.spawn(function()
		local remaining = duration

		while remaining > 0 and not dismissing do
			task.wait(0.1)
			if not paused then
				remaining -= 0.1
			end
		end

		dismiss()
	end)

	local live = {}

	for _, child in ipairs(self._notifyHolder:GetChildren()) do
		if child:IsA("CanvasGroup") then
			table.insert(live, child)
		end
	end

	if #live > 6 then
		local oldest = live[1]
		if oldest and oldest ~= card then
			tween(oldest, 0.22, { GroupTransparency = 1 })
			task.delay(0.24, function()
				oldest:Destroy()
			end)
		end
	end

	return card
end

function Window:Toast(props)
	props = props or {}

	local theme = self._theme
	local holder = string.lower(tostring(props.position or "Top")) == "bottom"
			and self._toastHolderBottom
		or self._toastHolderTop

	local title = tostring(props.title or "")
	local subtitle = props.subtitle

	local pill = create("CanvasGroup", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, props.minWidth or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		GroupTransparency = 1,
		LayoutOrder = #holder:GetChildren(),
		Parent = holder,
	})

	local body = create("Frame", {
		Name = "Body",
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = pill,
	})
	corner(body, UDim.new(1, 0))
	local bodyStroke = stroke(body, theme.ElementStroke, 1, theme.ElementStrokeTransparency)
	padding(body, 7, 16, 7, 12)
	listLayout(body, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)

	local column = create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = body,
	})
	local columnLayout = listLayout(column, Enum.FillDirection.Vertical, 1, Enum.HorizontalAlignment.Left)
	columnLayout.HorizontalFlex = Enum.UIFlexAlignment.None

	create("Frame", {
		Name = "Spacer",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Parent = column,
	})

	local function makeLine(text, font, size, colorKey)
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, size + 4),
			FontFace = font,
			Text = tostring(text),
			TextColor3 = theme[colorKey],
			TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = column,
		})
		self:_bind(colorKey, function(color)
			if label.Parent then
				label.TextColor3 = color
			end
		end, pill)
		return label
	end

	if subtitle and props.subtitleAbove then
		makeLine(subtitle, FONT_BODY, 10.5, "TextDim")
	end

	makeLine(title, FONT_MEDIUM, 12.5, "TitleText")

	if subtitle and not props.subtitleAbove then
		makeLine(subtitle, FONT_BODY, 10.5, "TextDim")
	end

	if props.avatar then
		local avatar = create("ImageLabel", {
			Name = "Avatar",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(24, 24),
			Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(props.avatar) .. "&w=100&h=100",
			LayoutOrder = 1,
			Parent = body,
		})
		corner(avatar, UDim.new(1, 0))
	elseif props.icon and props.icon ~= 0 and props.icon ~= "" then
		local icon = create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			Image = self:_resolveIcon(props.icon),
			ImageColor3 = theme.Accent,
			LayoutOrder = 1,
			Parent = body,
		})
		self:_bind("Accent", function(color)
			if icon.Parent then
				icon.ImageColor3 = color
			end
		end)
	end

	self:_bind("Surface", function(color)
		if body.Parent then
			body.BackgroundColor3 = color
		end
	end, pill)
	self:_bind("ElementStroke", function(color)
		if body.Parent then
			bodyStroke.Color = color
		end
	end, pill)

	local scale = create("UIScale", { Scale = 0.9, Parent = body })
	tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(pill, 0.28, { GroupTransparency = 0 })

	local dismissing = false
	local function dismiss()
		if dismissing then
			return
		end
		dismissing = true
		tween(scale, 0.22, { Scale = 0.92 })
		tween(pill, 0.24, { GroupTransparency = 1 })
		task.delay(0.26, function()
			pill:Destroy()
		end)
	end

	body.Active = true
	body.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dismiss()
		end
	end)

	task.delay(props.duration or math.clamp(2.4 + #title * 0.06, 2.4, 8), dismiss)

	return pill
end

--// Window: popups and tags -----------------------------------------------

function Window:Popup(props)
	props = props or {}

	local theme = self._theme
	local holder = self._popupHolder
	holder.Visible = true

	local backdrop = create("TextButton", {
		Name = "Popup",
		BackgroundColor3 = theme.ModalDim,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})

	local card = create("CanvasGroup", {
		Name = "Card",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = backdrop,
	})

	local shell = create("Frame", {
		Name = "Shell",
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	corner(shell, UDim.new(0, 12))
	local shellStroke = stroke(shell, theme.ElementStroke, 1, theme.ElementStrokeTransparency)
	padding(shell, 18, 18, 16, 18)

	local shellLayout = listLayout(shell, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left)
	shellLayout.HorizontalFlex = Enum.UIFlexAlignment.None

	create("Frame", {
		Name = "Spacer",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Parent = shell,
	})

	local header = create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = shell,
	})
	listLayout(header, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)

	if props.icon and props.icon ~= 0 and props.icon ~= "" then
		create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(20, 20),
			Image = self:_resolveIcon(props.icon),
			LayoutOrder = 1,
			Parent = header,
		})
	end

	local titleLabel = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		FontFace = FONT_TITLE,
		Text = tostring(props.title or "Popup"),
		TextColor3 = theme.TitleText,
		TextSize = 15.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 2,
		Parent = header,
	})

	self:_bind("TitleText", function(color)
		if titleLabel.Parent then
			titleLabel.TextColor3 = color
		end
	end, backdrop)

	if props.subtitle then
		local subtitle = create("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			FontFace = FONT_BODY,
			Text = tostring(props.subtitle),
			TextColor3 = theme.TextDim,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = shell,
		})
		self:_bind("TextDim", function(color)
			if subtitle.Parent then
				subtitle.TextColor3 = color
			end
		end, backdrop)
	end

	for index, box in ipairs(props.boxes or {}) do
		local row = create("Frame", {
			Name = "Box" .. index,
			BackgroundColor3 = theme.Surface:Lerp(theme.Accent, 0.1),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, box.description and 54 or 40),
			Parent = shell,
		})
		corner(row, UDim.new(0, 9))
		stroke(row, theme.ElementStroke, 1, theme.ElementStrokeTransparency)
		padding(row, 9, 12, 9, 12)

		local textOffset = 0

		if box.icon and box.icon ~= 0 and box.icon ~= "" then
			create("ImageLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(16, 16),
				Image = self:_resolveIcon(box.icon),
				Parent = row,
			})
			textOffset = 26
		end

		if box.title then
			local boxTitle = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, textOffset, 0, box.description and 5 or 0),
				Size = UDim2.new(1, -textOffset, 0, 18),
				FontFace = FONT_MEDIUM,
				Text = tostring(box.title),
				TextColor3 = theme.Text,
				TextSize = 12.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = box.description and Enum.TextYAlignment.Center or Enum.TextYAlignment.Center,
				Parent = row,
			})
			self:_bind("Text", function(color)
				if boxTitle.Parent then
					boxTitle.TextColor3 = color
				end
			end, backdrop)
		end

		if box.description then
			local description = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, textOffset, 0, 24),
				Size = UDim2.new(1, -textOffset, 0, 24),
				FontFace = FONT_BODY,
				Text = tostring(box.description),
				TextColor3 = theme.TextDim,
				TextSize = 11,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = row,
			})
			self:_bind("TextDim", function(color)
				if description.Parent then
					description.TextColor3 = color
				end
			end, backdrop)
		end
	end

	if props.content then
		local content = create("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, math.max(18, measureText(props.content, FONT_BODY, 12, 360) + 6)),
			FontFace = FONT_BODY,
			Text = tostring(props.content),
			TextColor3 = theme.TextDim,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = shell,
		})
		self:_bind("TextDim", function(color)
			if content.Parent then
				content.TextColor3 = color
			end
		end, backdrop)
	end

	local footer = create("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = shell,
	})
	listLayout(footer, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)

	create("Frame", {
		Name = "Spacer",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 1),
		LayoutOrder = 0,
		Parent = footer,
	})

	local function close()
		if not backdrop.Parent then
			return
		end

		tween(card, 0.2, { GroupTransparency = 1 })
		tween(backdrop, 0.2, { BackgroundTransparency = 1 })

		task.delay(0.22, function()
			backdrop:Destroy()
			if #holder:GetChildren() == 0 then
				holder.Visible = false
			end
		end)
	end

	local options = props.options or { { text = "Close", style = "neutral" } }

	for index, option in ipairs(options) do
		local style = option.style or "neutral"
		local fill = style == "primary" and theme.Accent
			or style == "danger" and theme.Danger
			or theme.Surface

		local button = create("TextButton", {
			Name = "Option" .. index,
			BackgroundColor3 = fill,
			BackgroundTransparency = style == "neutral" and 0.15 or 0,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			LayoutOrder = index,
			Parent = footer,
		})
		corner(button, UDim.new(0, 8))
		padding(button, 0, 14, 0, 14)

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			FontFace = FONT_MEDIUM,
			Text = tostring(option.text or "OK"),
			TextSize = 12,
			Parent = button,
		})

		if style == "primary" or style == "danger" then
			label.TextColor3 = contrastFor(fill)
		else
			label.TextColor3 = theme.Text
			self:_bind("Text", function(color)
				if label.Parent then
					label.TextColor3 = color
				end
			end, backdrop)
		end

		button.MouseEnter:Connect(function()
			tween(button, 0.14, {
				BackgroundColor3 = style == "primary" and theme.AccentAlt
					or style == "danger" and Color3.fromRGB(220, 38, 38)
					or theme.Surface:Lerp(theme.Accent, 0.35),
				BackgroundTransparency = style == "neutral" and 0.05 or 0,
			})
		end)

		button.MouseLeave:Connect(function()
			tween(button, 0.18, {
				BackgroundColor3 = fill,
				BackgroundTransparency = style == "neutral" and 0.15 or 0,
			})
		end)

		button.MouseButton1Click:Connect(function()
			if option.callback then
				task.spawn(option.callback)
			end
			close()
		end)
	end

	self:_bind("ModalDim", function(color)
		if backdrop.Parent then
			backdrop.BackgroundColor3 = color
		end
	end, backdrop)
	self:_bind("Surface", function(color)
		if shell.Parent then
			shell.BackgroundColor3 = color
		end
	end, backdrop)
	self:_bind("ElementStroke", function(color)
		if shell.Parent then
			shellStroke.Color = color
		end
	end, backdrop)

	local scale = create("UIScale", { Scale = 0.92, Parent = card })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(backdrop, 0.25, { BackgroundTransparency = theme.ModalDimTransparency })

	if props.dismissable ~= false then
		backdrop.MouseButton1Click:Connect(close)

		local escapeConnection
		escapeConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end

			if input.KeyCode == Enum.KeyCode.Escape then
				escapeConnection:Disconnect()
				close()
			end
		end)

		backdrop.Destroying:Connect(function()
			escapeConnection:Disconnect()
		end)
	end

	return {
		Close = close,
		Instance = backdrop,
	}
end

function Window:CreateTag(props)
	props = props or {}

	local self_ = self
	local color = fromHex(props.color or Color3.fromRGB(255, 175, 15))

	local tag = create("Frame", {
		Name = "Tag",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.order or 0,
		Parent = self._tagHolder,
	})
	corner(tag, UDim.new(1, 0))
	padding(tag, 2, 7, 2, 7)
	listLayout(tag, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)

	local iconLabel
	if props.icon and props.icon ~= 0 and props.icon ~= "" then
		iconLabel = create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(10, 10),
			Image = self:_resolveIcon(props.icon),
			ImageColor3 = contrastFor(color),
			LayoutOrder = 1,
			Parent = tag,
		})
	end

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		FontFace = FONT_MEDIUM,
		Text = tostring(props.text or props.title or ""),
		TextColor3 = contrastFor(color),
		TextSize = 10,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 2,
		Parent = tag,
	})

	local handle = {}

	function handle:SetColor(value)
		color = fromHex(value)
		tag.BackgroundColor3 = color
		label.TextColor3 = contrastFor(color)
		if iconLabel then
			iconLabel.ImageColor3 = contrastFor(color)
		end
	end

	function handle:SetText(value)
		label.Text = tostring(value or "")
		tag.Visible = label.Text ~= "" or iconLabel ~= nil
	end

	function handle:SetIcon(value)
		if not iconLabel then
			iconLabel = create("ImageLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(10, 10),
				ImageColor3 = contrastFor(color),
				LayoutOrder = 1,
				Parent = tag,
			})
		end
		iconLabel.Image = self_:_resolveIcon(value)
	end

	function handle:Set(options)
		if options.color then
			handle:SetColor(options.color)
		end
		if options.text or options.title then
			handle:SetText(options.text or options.title)
		end
		if options.icon then
			handle:SetIcon(options.icon)
		end
	end

	function handle:Remove()
		tag:Destroy()
	end

	return handle
end

function Window:SetProfile(text)
	if not self._profileLabel then
		return
	end

	self._profile = text
	self._profileLabel.Text = text or ""
end

function Window:Navigate(tab)
	if type(tab) == "string" then
		for _, candidate in ipairs(self._tabs) do
			if candidate._name == tab then
				candidate:Select()
				return
			end
		end
		return
	end

	if type(tab) == "table" and tab.Select then
		tab:Select()
	end
end

--// Containers --------------------------------------------------------------

local function deriveFlag(name)
	if not name or name == "" then
		return nil
	end
	return (string.gsub(name, "[^%w]", ""))
end

local function containerAdd(container, frame, height, half)
	local item = { frame = frame, height = height, half = half == true }
	table.insert(container._items, item)

	if container.direction == "row" or container.direction == "grid" then
		container:_relayout()
	end

	return item
end

local function containerRemove(container, item)
	local index = table.find(container._items, item)

	if not index then
		return
	end

	table.remove(container._items, index)
	item.frame:Destroy()

	if container.direction == "row" or container.direction == "grid" then
		container:_relayout()
	end
end

local function containerReorder(container, item, target)
	local items = container._items
	local index = table.find(items, item)

	if not index then
		return
	end

	table.remove(items, index)
	table.insert(items, math.clamp(target, 1, #items + 1), item)

	for position, entry in ipairs(items) do
		entry.frame.LayoutOrder = position
	end

	if container.direction == "row" or container.direction == "grid" then
		container:_relayout()
	end
end

local function buildContainer(container, frame, direction, gap)
	container.frame = frame
	container.direction = direction
	container.gap = gap or GAP
	container._items = container._items or {}

	local layout = create("UIListLayout", {
		FillDirection = (direction == "row" or direction == "grid")
				and Enum.FillDirection.Horizontal
			or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, container.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = frame,
	})

	-- A grid flows elements left to right and wraps, so half-width cards sit two
	-- to a line while full-width ones get a line of their own.
	if direction == "grid" then
		layout.Wraps = true
		if Enum.ItemLineAlignment then
			layout.ItemLineAlignment = Enum.ItemLineAlignment.Start
		end
	end

	function container:_relayout()
		if self.direction == "grid" then
			local gapPixels = self.gap

			for _, item in ipairs(self._items) do
				local autoHeight = item.frame.AutomaticSize == Enum.AutomaticSize.Y
					or item.frame.AutomaticSize == Enum.AutomaticSize.XY

				if item.half then
					-- The extra pixel guards against rounding pushing the second
					-- card onto its own line.
					item.frame.Size = UDim2.new(0.5, -(gapPixels / 2) - 1, 0, autoHeight and 0 or item.height)
				else
					item.frame.Size = UDim2.new(1, 0, 0, autoHeight and 0 or item.height)
				end
			end

			return
		end

		if self.direction ~= "row" then
			return
		end

		local count = #self._items

		if count == 0 then
			return
		end

		local gapPixels = self.gap

		for _, item in ipairs(self._items) do
			local autoHeight = item.frame.AutomaticSize == Enum.AutomaticSize.Y
				or item.frame.AutomaticSize == Enum.AutomaticSize.XY

			item.frame.Size = UDim2.new(
				1 / count,
				-(gapPixels * (count - 1)) / count,
				0,
				autoHeight and 0 or item.height
			)
		end
	end
end

--// Element base ------------------------------------------------------------

local Element = {}
Element.__index = Element

function Element:MoveTo(index)
	containerReorder(self._container, self._entry, index)
end

function Element:MoveToTop()
	containerReorder(self._container, self._entry, 1)
end

function Element:MoveToBottom()
	containerReorder(self._container, self._entry, #self._container._items)
end

function Element:MoveUp()
	local items = self._container._items
	local index = table.find(items, self._entry)

	if index and index > 1 then
		containerReorder(self._container, self._entry, index - 1)
	end
end

function Element:MoveDown()
	local items = self._container._items
	local index = table.find(items, self._entry)

	if index and index < #items then
		containerReorder(self._container, self._entry, index + 1)
	end
end

function Element:Lock(reason)
	if self._locked then
		return
	end

	self._locked = true

	if self._applyLock then
		self._applyLock(true, reason)
	end
end

function Element:Unlock()
	if not self._locked then
		return
	end

	self._locked = false

	if self._applyLock then
		self._applyLock(false, nil)
	end
end

function Element:IsLocked()
	return self._locked == true
end

function Element:Remove()
	if self._dead then
		return
	end

	self._dead = true

	if self._window and self._flag then
		self._window._elements[self._flag] = nil
	end

	containerRemove(self._container, self._entry)
end

--// Element shell -----------------------------------------------------------

local function buildShell(container, props, height, rightInset)
	local window = container.window
	local theme = window._theme

	local card = create("Frame", {
		Name = props.name or "Element",
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = #container._items + 1,
		Parent = container.frame,
	})
	corner(card, theme.CornerElement)
	local cardStroke = stroke(card, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

	local left = 13

	local iconLabel
	if props.icon and props.icon ~= 0 and props.icon ~= "" then
		iconLabel = create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, left, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(16, 16),
			Image = window:_resolveIcon(props.icon),
			ImageColor3 = theme.Text,
			Parent = card,
		})
		left += 24
	end

	local hasDescription = props.description ~= nil and props.description ~= ""

	local label = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, left, 0, hasDescription and 9 or 0),
		Size = UDim2.new(1, -(left + (rightInset or 13)), 0, hasDescription and 16 or height),
		FontFace = FONT_MEDIUM,
		Text = tostring(props.name or ""),
		TextColor3 = theme.Text,
		TextSize = 12.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = hasDescription and Enum.TextYAlignment.Top
			or Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	local description
	if hasDescription then
		description = create("TextLabel", {
			Name = "Description",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, left, 0, 26),
			Size = UDim2.new(1, -(left + (rightInset or 13)), 0, 14),
			FontFace = FONT_BODY,
			Text = tostring(props.description),
			TextColor3 = theme.TextDim,
			TextSize = 10.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
	end

	window:_bind("Surface", function(color)
		if card.Parent then
			card.BackgroundColor3 = color
		end
	end, card)
	window:_bind("SurfaceTransparency", function(value)
		if card.Parent then
			card.BackgroundTransparency = value
		end
	end, card)
	window:_bind("Text", function(color)
		if label.Parent then
			label.TextColor3 = color
		end
		if iconLabel and iconLabel.Parent then
			iconLabel.ImageColor3 = color
		end
	end, card)
	window:_bind("TextDim", function(color)
		if description and description.Parent then
			description.TextColor3 = color
		end
	end, card)
	window:_bind("ElementStroke", function(color)
		if cardStroke.Parent then
			cardStroke.Color = color
		end
	end, card)
	window:_bind("ElementStrokeTransparency", function(value)
		if cardStroke.Parent then
			cardStroke.Transparency = value
		end
	end, card)

	return {
		card = card,
		stroke = cardStroke,
		label = label,
		description = description,
		icon = iconLabel,
		left = left,
	}
end

local function addHover(element, shell)
	local window = element._window

	-- Hover reads the live theme, so the tint follows whatever accent is set
	-- instead of a fixed grey.
	local function paint(on)
		local theme = window._theme
		local accent = theme.Accent
		local speed = on and 0.18 or 0.24

		tween(shell.card, speed, {
			BackgroundColor3 = on and theme.Surface:Lerp(accent, 0.16) or theme.Surface,
			BackgroundTransparency = on
					and math.max(theme.SurfaceTransparency - 0.12, 0)
				or theme.SurfaceTransparency,
		})

		tween(shell.stroke, speed, {
			Color = on and accent or theme.ElementStroke,
			Transparency = on and 0.25 or theme.ElementStrokeTransparency,
		})
	end

	shell.card.MouseEnter:Connect(function()
		if element._locked then
			return
		end

		paint(true)
	end)

	shell.card.MouseLeave:Connect(function()
		if element._locked then
			return
		end

		paint(false)
	end)
end

local function attach(element, container, frame, height, props, shell)
	element._window = container.window
	element._container = container
	element._frame = frame
	element._entry = containerAdd(container, frame, height, props.__half == true)
	element._locked = false

	local window = container.window

	if props.name and not props.forgetState then
		local flag = props.flag or deriveFlag(props.name)

		if flag then
			element._flag = flag
			window._elements[flag] = element
		end
	end

	if shell and props.name then
		window:_registerLabel(function(text)
			if shell.label.Parent then
				shell.label.Text = text
			end
		end, props.name)
	end

	function element:_store(value)
		if self._flag then
			window._values[self._flag] = value
			window:_markDirty()
		end
	end

	function element:_guard()
		return not self._locked and not self._dead
	end

	return element
end

--// Elements ----------------------------------------------------------------

local function shortNumber(value)
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end

	local text = string.format("%.3f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")

	return text
end

local function normalizeProps(props)
	local out = {}

	for key, value in pairs(props or {}) do
		if type(key) == "string" then
			out[string.lower(string.sub(key, 1, 1)) .. string.sub(key, 2)] = value
		end
	end

	return out
end

local FULL_WIDTH_ONLY = {
	input = true,
	keybind = true,
	colorpicker = true,
	text = true,
	divider = true,
	console = true,
	section = true,
}

-- Inside a grid these sit two to a line; everything else spans the full width.
local HALF_WIDTH = {
	button = true,
	toggle = true,
	switch = true,
	slider = true,
	stat = true,
}

createElement = function(kind, container, props)
	props = normalizeProps(props)

	local window = container.window

	if not window or window._unloaded then
		return nil
	end

	if container.direction == "row" and FULL_WIDTH_ONLY[kind] then
		warn("[Vanta] " .. kind .. " is full width and cannot live inside a row group.")
		return nil
	end

	props.__half = container.direction == "grid" and HALF_WIDTH[kind] == true

	local theme = window._theme
	local hasDescription = props.description ~= nil and props.description ~= ""

	--// Toggle ---------------------------------------------------------------
	if kind == "toggle" or kind == "switch" then
		local element = setmetatable({ value = props.value == true }, Element)
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local shell = buildShell(container, props, height, 62)
		addHover(element, shell)

		local track = create("Frame", {
			Name = "Track",
			BackgroundColor3 = theme.ToggleTrackOff,
			BackgroundTransparency = theme.ToggleTrackOffTransparency,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(38, 21),
			Parent = shell.card,
		})
		corner(track, UDim.new(1, 0))

		local glow = create("Frame", {
			Name = "Glow",
			BackgroundColor3 = theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 7, 1, 7),
			ZIndex = 0,
			Parent = track,
		})
		corner(glow, UDim.new(1, 0))

		local knobSize = 15
		local knob = create("Frame", {
			Name = "Knob",
			BackgroundColor3 = theme.ToggleKnobOff,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(knobSize, knobSize),
			Parent = track,
		})
		corner(knob, UDim.new(1, 0))

		local travel = 38 - 6 - knobSize
		local spring = Spring.new(element.value and travel or 0, function(offset)
			knob.Position = UDim2.new(0, 3 + offset, 0.5, 0)
		end, { stiffness = 380, damping = 30, attach = knob })
		spring:snap(element.value and travel or 0)

		local function paint(animate)
			local speed = animate and 0.25 or 0

			tween(track, speed, {
				BackgroundColor3 = element.value and theme.Accent or theme.ToggleTrackOff,
				BackgroundTransparency = element.value and 0 or theme.ToggleTrackOffTransparency,
			})

			tween(knob, speed, {
				BackgroundColor3 = element.value and Color3.new(1, 1, 1) or theme.ToggleKnobOff,
			})

			tween(glow, speed + 0.05, {
				BackgroundTransparency = element.value and theme.AccentGlowTransparency or 1,
			})
		end

		function element:_apply(value, skipCallback)
			element.value = value == true
			spring:to(element.value and travel or 0)
			paint(true)
			element:_store(element.value)

			if not skipCallback and props.callback then
				task.spawn(props.callback, element.value)
			end
		end

		function element:Set(value, skipCallback)
			element:_apply(value == true, skipCallback)
		end

		shell.card.Active = true
		shell.card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if not element:_guard() then
				return
			end

			element:_apply(not element.value, false)
		end)

		element._applyLock = function(locked, reason)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			tween(shell.card, 0.2, {
				BackgroundTransparency = locked and math.min(1, theme.SurfaceTransparency + 0.3)
					or theme.SurfaceTransparency,
			})
			if shell.description then
				shell.description.Text = locked and (reason or props.description) or (props.description or "")
			end
		end

		window:_bind("Accent", function(color)
			if track.Parent then
				glow.BackgroundColor3 = color
				if element.value then
					track.BackgroundColor3 = color
				end
			end
		end)
		window:_bind("ToggleTrackOff", function(color)
			if track.Parent and not element.value then
				track.BackgroundColor3 = color
			end
		end)
		window:_bind("ToggleKnobOff", function(color)
			if knob.Parent and not element.value then
				knob.BackgroundColor3 = color
			end
		end)

		attach(element, container, shell.card, height, props, shell)
		paint(false)
		element:_store(element.value)

		return element
	end

	--// Button ---------------------------------------------------------------
	if kind == "button" then
		local element = setmetatable({}, Element)
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local shell = buildShell(container, props, height, 18)
		addHover(element, shell)

		shell.card.ClipsDescendants = true
		shell.card.Active = true

		shell.card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if not element:_guard() then
				return
			end

			ripple(
				shell.card,
				theme.Accent,
				input.Position.X - shell.card.AbsolutePosition.X,
				input.Position.Y - shell.card.AbsolutePosition.Y
			)

			local flash = create("Frame", {
				Name = "Flash",
				BackgroundColor3 = theme.Accent,
				BackgroundTransparency = 0.86,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = shell.card.ZIndex + 2,
				Parent = shell.card,
			})
			corner(flash, theme.CornerElement)
			tween(flash, 0.42, { BackgroundTransparency = 1 })
			task.delay(0.45, function()
				flash:Destroy()
			end)

			if props.callback then
				task.spawn(props.callback)
			end
		end)

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			tween(shell.card, 0.2, {
				BackgroundTransparency = locked and math.min(1, theme.SurfaceTransparency + 0.3)
					or theme.SurfaceTransparency,
			})
		end

		attach(element, container, shell.card, height, props, shell)

		return element
	end

	--// Slider ---------------------------------------------------------------
	if kind == "slider" then
		local element = setmetatable({}, Element)
		local range = props.range or { 0, 100 }
		local minimum = range[1] or 0
		local maximum = range[2] or 100
		local increment = props.increment or 1
		local minimal = props.minimal == true
		local height = minimal and 26 or (hasDescription and 74 or 58)
		local shell = buildShell(container, props, height, 76)
		addHover(element, shell)

		element.value = math.clamp(props.value or minimum, minimum, maximum)

		local track = create("Frame", {
			Name = "Track",
			BackgroundColor3 = theme.SliderTrack,
			BackgroundTransparency = theme.SliderTrackTransparency,
			BorderSizePixel = 0,
			Position = minimal and UDim2.new(0, 13, 0.5, 0) or UDim2.new(0, 13, 0, 34),
			AnchorPoint = minimal and Vector2.new(0, 0.5) or Vector2.new(0, 0),
			Size = UDim2.new(1, -26, 0, 5),
			Parent = shell.card,
		})
		corner(track, UDim.new(1, 0))

		local fill = create("Frame", {
			Name = "Fill",
			BackgroundColor3 = theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = track,
		})
		corner(fill, UDim.new(1, 0))
		local fillGradient = gradient(fill, ColorSequence.new(theme.Accent, theme.AccentAlt), 0)
		window:_bind("Accent", function(color)
			if fill.Parent then
				fillGradient.Color = ColorSequence.new(color, window._theme.AccentAlt)
			end
		end)
		window:_bind("AccentAlt", function(color)
			if fill.Parent then
				fillGradient.Color = ColorSequence.new(window._theme.Accent, color)
			end
		end)
		window:_bind("SliderTrack", function(color)
			if track.Parent then
				track.BackgroundColor3 = color
			end
		end)

		local handle = create("Frame", {
			Name = "Handle",
			BackgroundColor3 = theme.SliderHandle,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(13, 13),
			Parent = track,
		})
		corner(handle, UDim.new(1, 0))
		local handleScale = create("UIScale", { Scale = 1, Parent = handle })
		window:_bind("SliderHandle", function(color)
			if handle.Parent then
				handle.BackgroundColor3 = color
			end
		end)

		local valueLabel
		if not minimal then
			valueLabel = create("TextLabel", {
				Name = "Value",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -13 - 60, 0, 9),
				Size = UDim2.fromOffset(60, 16),
				FontFace = FONT_MEDIUM,
				TextColor3 = theme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = shell.card,
			})
			window:_bind("Text", function(color)
				if valueLabel.Parent then
					valueLabel.TextColor3 = color
				end
			end)
		end

		local dragging = false

		local function alphaFor(value)
			if maximum == minimum then
				return 0
			end
			return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
		end

		local function paint()
			local alpha = alphaFor(element.value)

			if dragging then
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				handle.Position = UDim2.new(alpha, 0, 0.5, 0)
			else
				tween(fill, 0.16, { Size = UDim2.new(alpha, 0, 1, 0) }, Enum.EasingStyle.Quart)
				tween(handle, 0.16, { Position = UDim2.new(alpha, 0, 0.5, 0) }, Enum.EasingStyle.Quart)
			end

			if valueLabel then
				valueLabel.Text = shortNumber(element.value) .. tostring(props.suffix or "")
			end
		end

		local function valueAt(x)
			local width = math.max(track.AbsoluteSize.X, 1)
			local relative = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			local raw = minimum + relative * (maximum - minimum)

			if increment and increment > 0 then
				raw = minimum + math.floor((raw - minimum) / increment + 0.5) * increment
			end

			return math.clamp(raw, minimum, maximum)
		end

		function element:_apply(value, silent)
			element.value = math.clamp(value, minimum, maximum)
			paint()
			element:_store(element.value)

			if not silent and props.callback then
				task.spawn(props.callback, element.value, dragging)
			end
		end

		function element:Set(value, skipCallback)
			element:_apply(value, skipCallback == true)
		end

		shell.card.Active = true
		shell.card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if not element:_guard() then
				return
			end

			dragging = true
			tween(handleScale, 0.16, { Scale = 1.35 }, Enum.EasingStyle.Back)
			element:_apply(valueAt(input.Position.X), true)

			if props.callback then
				task.spawn(props.callback, element.value, true)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				element:_apply(valueAt(input.Position.X), true)

				if props.callback then
					task.spawn(props.callback, element.value, true)
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not dragging then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
				tween(handleScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Quart)

				if props.callback then
					task.spawn(props.callback, element.value, false)
				end
			end
		end)

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			handle.BackgroundTransparency = locked and 0.5 or 0
		end

		attach(element, container, shell.card, height, props, shell)
		paint()
		element:_store(element.value)

		return element
	end

	--// Section --------------------------------------------------------------
	if kind == "section" then
		local element = setmetatable({}, Element)

		local row = create("Frame", {
			Name = props.name or "Section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})

		local pip = create("Frame", {
			Name = "Pip",
			BackgroundColor3 = theme.Accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 13, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(3, 11),
			Parent = row,
		})
		corner(pip, UDim.new(1, 0))

		local iconLabel
		local textLeft = 24

		if props.icon and props.icon ~= 0 and props.icon ~= "" then
			iconLabel = create("ImageLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, textLeft, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(13, 13),
				Image = window:_resolveIcon(props.icon),
				ImageColor3 = theme.TextDim,
				Parent = row,
			})
			textLeft += 19
		end

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, textLeft, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			FontFace = FONT_MEDIUM,
			Text = string.upper(tostring(props.name or "")),
			TextColor3 = theme.TextDim,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		window:_bind("Accent", function(color)
			if pip.Parent then
				pip.BackgroundColor3 = color
			end
		end)
		window:_bind("TextDim", function(color)
			if label.Parent then
				label.TextColor3 = color
			end
			if iconLabel and iconLabel.Parent then
				iconLabel.ImageColor3 = color
			end
		end)

		attach(element, container, row, 30, props, nil)

		window:_registerLabel(function(text)
			if label.Parent then
				label.Text = string.upper(text)
			end
		end, props.name or "")

		return element
	end

	--// Divider --------------------------------------------------------------
	if kind == "divider" then
		local element = setmetatable({}, Element)
		local spacing = props.spacing or 12
		local withLine = props.line ~= false
		local text = tostring(props.text or "")
		local height = spacing * 2 + (withLine and 1 or 0)

		local row = create("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})

		local lines = {}

		if withLine then
			for index = 1, 2 do
				local line = create("Frame", {
					Name = "Line" .. index,
					BackgroundColor3 = theme.Divider,
					BackgroundTransparency = theme.DividerTransparency,
					BorderSizePixel = 0,
					Size = UDim2.new(0.5, -20, 0, 1),
					Parent = row,
				})
				lines[index] = line
			end

			lines[1].Position = UDim2.new(0, 13, 0.5, 0)
			lines[1].AnchorPoint = Vector2.new(0, 0.5)
			lines[2].Position = UDim2.new(1, -13, 0.5, 0)
			lines[2].AnchorPoint = Vector2.new(1, 0.5)
			lines[2].Size = UDim2.new(0.5, -33, 0, 1)

			window:_bind("Divider", function(color)
				for _, line in ipairs(lines) do
					if line.Parent then
						line.BackgroundColor3 = color
					end
				end
			end)
			window:_bind("DividerTransparency", function(value)
				for _, line in ipairs(lines) do
					if line.Parent then
						line.BackgroundTransparency = value
					end
				end
			end)
		end

		local label = create("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			FontFace = FONT_MEDIUM,
			Text = text,
			TextColor3 = theme.TextDim,
			TextSize = 10,
			Visible = text ~= "",
			Parent = row,
		})
		padding(label, 0, 10, 0, 10)

		window:_bind("TextDim", function(color)
			if label.Parent then
				label.TextColor3 = color
			end
		end)

		function element:Set(value)
			element.text = tostring(value or "")
			label.Text = element.text
			label.Visible = element.text ~= ""
		end

		element.text = text

		attach(element, container, row, height, props, nil)

		return element
	end

	--// Text ----------------------------------------------------------------
	if kind == "text" then
		local element = setmetatable({}, Element)
		local title = props.name
		local body = props.text or props.body or ""

		local card = create("Frame", {
			Name = "Text",
			BackgroundColor3 = theme.Surface,
			BackgroundTransparency = math.min(1, theme.SurfaceTransparency + 0.3),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})
		corner(card, theme.CornerElement)
		stroke(card, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

		local left = 13
		local iconLabel

		if props.icon and props.icon ~= 0 and props.icon ~= "" then
			iconLabel = create("ImageLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, left, 0, 11),
				Size = UDim2.fromOffset(15, 15),
				Image = window:_resolveIcon(props.icon),
				ImageColor3 = theme.Text,
				Parent = card,
			})
			left += 22
		end

		local titleLabel
		if title then
			titleLabel = create("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, left, 0, 11),
				Size = UDim2.new(1, -(left + 13), 0, 18),
				FontFace = FONT_MEDIUM,
				Text = tostring(title),
				TextColor3 = theme.Text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
		end

		local bodyLabel
		if body ~= "" then
			bodyLabel = create("TextLabel", {
				Name = "Body",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, left, 0, title and 31 or 12),
				Size = UDim2.new(1, -(left + 13), 0, 18),
				FontFace = FONT_BODY,
				Text = tostring(body),
				TextColor3 = theme.TextDim,
				TextSize = 11.5,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
		end

		local widthEstimate = window._width - (window._sidebar and window._railWidth or 0) - 60
		local function reflow()
			local width = card.AbsoluteSize.X

			if width <= 0 then
				width = widthEstimate
			end

			local textWidth = width - (left + 13)
			local bodyHeight = bodyLabel
					and math.max(16, math.ceil(measureText(bodyLabel.Text, FONT_BODY, 11.5, textWidth) / 14) * 14)
				or 0
			local height = 12 + (titleLabel and 20 or 0) + bodyHeight + 12

			card.Size = UDim2.new(1, 0, 0, height)

			if bodyLabel then
				bodyLabel.Size = UDim2.new(1, -(left + 13), 0, bodyHeight)
			end

			if element._entry then
				element._entry.height = height
			end
		end

		window:_bind("Surface", function(color)
			if card.Parent then
				card.BackgroundColor3 = color
			end
		end)
		window:_bind("Text", function(color)
			if titleLabel and titleLabel.Parent then
				titleLabel.TextColor3 = color
			end
			if iconLabel and iconLabel.Parent then
				iconLabel.ImageColor3 = color
			end
		end)
		window:_bind("TextDim", function(color)
			if bodyLabel and bodyLabel.Parent then
				bodyLabel.TextColor3 = color
			end
		end)

		function element:Set(value)
			element.text = tostring(value or "")

			if not bodyLabel then
				bodyLabel = create("TextLabel", {
					Name = "Body",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, left, 0, titleLabel and 31 or 12),
					Size = UDim2.new(1, -(left + 13), 0, 18),
					FontFace = FONT_BODY,
					TextColor3 = theme.TextDim,
					TextSize = 11.5,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Parent = card,
				})
			end

			bodyLabel.Text = element.text
			bodyLabel.Visible = element.text ~= ""
			reflow()
		end

		function element:SetTitle(value)
			if not titleLabel then
				return
			end

			titleLabel.Text = tostring(value or "")
			titleLabel.Visible = titleLabel.Text ~= ""
			reflow()
		end

		element.name = title or ""
		element.text = tostring(body)

		attach(element, container, card, 40, props, nil)
		afterLayout(reflow)

		if title then
			window:_registerLabel(function(text)
				if titleLabel and titleLabel.Parent then
					titleLabel.Text = text
				end
			end, title)
		end

		return element
	end

	--// Dropdown -------------------------------------------------------------
	if kind == "dropdown" then
		local element = setmetatable({}, Element)
		local multi = props.multiSelect == true
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local ROW_HEIGHT = 28
		local ROW_GAP = 2

		local wrapper = create("Frame", {
			Name = "Dropdown",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})
		listLayout(wrapper, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left)

		local shell = buildShell({
			window = window,
			frame = wrapper,
			_items = {},
			direction = "column",
			gap = 6,
			_relayout = function() end,
		}, props, height, 196)

		addHover(element, shell)

		local chevron = create("Frame", {
			Name = "Chevron",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Parent = shell.card,
		})
		local chevronGlyph = glyphChevron(chevron, theme.TextDim, 13, 1.6)

		local valueLabel = create("TextLabel", {
			Name = "Value",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -38, 0.5, 0),
			Size = UDim2.fromOffset(146, 16),
			FontFace = FONT_MEDIUM,
			TextColor3 = theme.Accent,
			TextSize = 11.5,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = shell.card,
		})
		local refreshSelection

		window:_bind("Accent", function()
			if valueLabel.Parent and refreshSelection then
				refreshSelection()
			end
		end, shell.card)
		window:_bind("TextDim", function(color)
			if chevronGlyph.Parent then
				for _, child in ipairs(chevronGlyph:GetChildren()) do
					if child:IsA("Frame") then
						child.BackgroundColor3 = color
					end
				end
			end
		end, shell.card)

		local panel = create("Frame", {
			Name = "Panel",
			BackgroundColor3 = theme.FieldFill,
			BackgroundTransparency = theme.FieldFillTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			LayoutOrder = 2,
			Visible = false,
			Parent = wrapper,
		})
		corner(panel, UDim.new(0, 9))
		stroke(panel, theme.ElementStroke, 1, theme.ElementStrokeTransparency)
		padding(panel, 8, 8, 8, 8)
		listLayout(panel, Enum.FillDirection.Vertical, ROW_GAP, Enum.HorizontalAlignment.Left)

		local options = {}
		local lookup = {}

		for _, option in ipairs(props.options or {}) do
			local name = tostring(option)
			if not lookup[name] then
				lookup[name] = true
				table.insert(options, name)
			end
		end

		local selected = {}
		local wanted = props.value

		if type(wanted) == "string" then
			wanted = { wanted }
		end

		for _, item in ipairs(wanted or {}) do
			local name = tostring(item)
			if lookup[name] and not table.find(selected, name) then
				table.insert(selected, name)
			end
		end

		if not multi and #selected > 1 then
			selected = { selected[1] }
		end

		local search

		if #options > 7 then
			search = create("TextBox", {
				Name = "Search",
				BackgroundColor3 = theme.Surface,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Search...",
				PlaceholderColor3 = theme.Placeholder,
				FontFace = FONT_BODY,
				Text = "",
				TextColor3 = theme.Text,
				TextSize = 11.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = 1,
				Parent = panel,
			})
			corner(search, UDim.new(0, 7))
			padding(search, 0, 8, 0, 8)
			window:_bind("Placeholder", function(color)
				if search.Parent then
					search.PlaceholderColor3 = color
				end
			end)
			window:_bind("Text", function(color)
				if search.Parent then
					search.TextColor3 = color
				end
			end)
		end

		local listFrame = create("Frame", {
			Name = "Options",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = panel,
		})
		listLayout(listFrame, Enum.FillDirection.Vertical, ROW_GAP, Enum.HorizontalAlignment.Left)

		local emptyLabel = create("TextLabel", {
			Name = "Empty",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			FontFace = FONT_BODY,
			Text = "Nothing matches.",
			TextColor3 = theme.Placeholder,
			TextSize = 11,
			LayoutOrder = 3,
			Visible = false,
			Parent = panel,
		})
		window:_bind("Placeholder", function(color)
			if emptyLabel.Parent then
				emptyLabel.TextColor3 = color
			end
		end)

		local rows = {}
		local fullHeight = 0

		local function isSelected(name)
			return table.find(selected, name) ~= nil
		end

		local function paintRow(row)
			row.highlight.BackgroundTransparency = isSelected(row.name) and 0.78 or 1
			row.marker.Visible = isSelected(row.name)
			row.label.TextColor3 = isSelected(row.name) and window._theme.Text or window._theme.TextDim
		end

		local function buildRows()
			for _, row in ipairs(rows) do
				row.frame:Destroy()
			end

			rows = {}

			for index, name in ipairs(options) do
				local rowFrame = create("TextButton", {
					Name = "Option" .. index,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
					LayoutOrder = index,
					Parent = listFrame,
				})
				corner(rowFrame, UDim.new(0, 7))

				local highlight = create("Frame", {
					Name = "Highlight",
					BackgroundColor3 = theme.Accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Parent = rowFrame,
				})
				corner(highlight, UDim.new(0, 7))

				local label = create("TextLabel", {
					Name = "Label",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 9, 0, 0),
					Size = UDim2.new(1, -36, 1, 0),
					FontFace = FONT_BODY,
					Text = name,
					TextColor3 = theme.TextDim,
					TextSize = 11.5,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = rowFrame,
				})

				local marker = create("Frame", {
					Name = "Marker",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					Visible = false,
					Parent = rowFrame,
				})
				local markerGlyph = glyphCheck(marker, theme.Accent, 13, 1.8)

				local row = {
					frame = rowFrame,
					label = label,
					highlight = highlight,
					marker = marker,
					name = name,
					visible = true,
				}
				rows[index] = row

				window:_bind("Accent", function(color)
					if highlight.Parent then
						highlight.BackgroundColor3 = color
						for _, child in ipairs(markerGlyph:GetChildren()) do
							if child:IsA("Frame") then
								child.BackgroundColor3 = color
							end
						end
					end
				end, rowFrame)

				rowFrame.MouseEnter:Connect(function()
					if row.visible then
						tween(highlight, 0.14, { BackgroundTransparency = 0.92 })
					end
				end)

				rowFrame.MouseLeave:Connect(function()
					tween(highlight, 0.16, {
						BackgroundTransparency = isSelected(name) and 0.78 or 1,
					})
				end)

				rowFrame.MouseButton1Click:Connect(function()
					if not element:_guard() then
						return
					end

					if multi then
						local index_ = table.find(selected, name)

						if index_ then
							table.remove(selected, index_)
						else
							table.insert(selected, name)
						end
					else
						selected = isSelected(name) and {} or { name }
					end

					element:Set(selected, false)
				end)
			end
		end

		buildRows()

		local function visibleCount()
			local count = 0

			for _, row in ipairs(rows) do
				if row.visible then
					count += 1
				end
			end

			return count
		end

		local function measurePanel()
			local count = visibleCount()
			local total = 16

			if search then
				total += 26 + ROW_GAP
			end

			if count > 0 then
				total += count * ROW_HEIGHT + (count - 1) * ROW_GAP
			end

			return total
		end

		local panelSpring = Spring.new(0, function(progress)
			if not panel.Parent then
				return
			end

			panel.Size = UDim2.new(1, 0, 0, math.max(fullHeight * progress, 0))
			panel.Visible = progress > 0.002
		end, { stiffness = 300, damping = 28, attach = panel })

		local open = false

		local function setOpen(state)
			open = state
			fullHeight = measurePanel()
			panelSpring:to(state and 1 or 0)
			tween(chevron, 0.32, {
				Rotation = state and 180 or 0,
			}, Enum.EasingStyle.Quint)

			if not state and search then
				search.Text = ""
			end
		end

		element._setOpen = setOpen

		function refreshSelection()
			local text = nil

			if #selected > 0 then
				if multi and #selected > 2 then
					text = selected[1] .. " +" .. (#selected - 1)
				else
					text = table.concat(selected, ", ")
				end
			end

			valueLabel.Text = text or tostring(props.placeholder or "None")
			valueLabel.TextColor3 = text and window._theme.Accent or window._theme.Placeholder

			for _, row in ipairs(rows) do
				paintRow(row)
			end

			if open then
				fullHeight = measurePanel()
			end
		end

		local function fire()
			if not props.callback then
				return
			end

			if multi then
				task.spawn(props.callback, table.clone(selected))
			else
				task.spawn(props.callback, selected[1])
			end
		end

		function element:Set(value, skipCallback)
			local incoming = type(value) == "table" and value or { value }
			local nextSelection = {}

			for _, item in ipairs(incoming) do
				local name = tostring(item)
				if lookup[name] and not table.find(nextSelection, name) then
					table.insert(nextSelection, name)
				end
			end

			if not multi and #nextSelection > 1 then
				nextSelection = { nextSelection[1] }
			end

			selected = nextSelection
			element.value = selected

			refreshSelection()
			element:_store(table.clone(selected))

			if not skipCallback then
				fire()
			end
		end

		function element:Refresh(newOptions)
			options = {}
			lookup = {}

			for _, option in ipairs(newOptions or {}) do
				local name = tostring(option)
				if not lookup[name] then
					lookup[name] = true
					table.insert(options, name)
				end
			end

			local kept = {}

			for _, name in ipairs(selected) do
				if lookup[name] then
					table.insert(kept, name)
				end
			end

			buildRows()
			element:Set(kept, #kept == #selected)
			refreshSelection()
		end

		function element:Add(option)
			local name = tostring(option)

			if lookup[name] then
				return
			end

			lookup[name] = true
			table.insert(options, name)
			buildRows()
			refreshSelection()
		end

		function element:Remove(option)
			local name = tostring(option)
			local index = table.find(options, name)

			if not index then
				return
			end

			table.remove(options, index)
			lookup[name] = nil
			buildRows()

			local selectedIndex = table.find(selected, name)

			if selectedIndex then
				table.remove(selected, selectedIndex)
				element.value = selected
				element:_store(table.clone(selected))
				fire()
			end

			refreshSelection()
		end

		if search then
			search:GetPropertyChangedSignal("Text"):Connect(function()
				local query = string.lower(search.Text)

				for _, row in ipairs(rows) do
					row.visible = query == "" or string.find(string.lower(row.name), query, 1, true) ~= nil
					row.frame.Visible = row.visible
				end

				local count = visibleCount()
				emptyLabel.Visible = count == 0
				fullHeight = measurePanel()

				if open then
					panelSpring:to(1)
					panel.Size = UDim2.new(1, 0, 0, fullHeight)
				end
			end)
		end

		shell.card.Active = true
		shell.card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if not element:_guard() then
				return
			end

			setOpen(not open)
		end)

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			valueLabel.TextTransparency = locked and 0.5 or 0

			if locked and open then
				setOpen(false)
			end
		end

		window:_bind("FieldFill", function(color)
			if panel.Parent then
				panel.BackgroundColor3 = color
			end
		end)

		attach(element, container, wrapper, height, props, shell)

		element.value = selected
		refreshSelection()
		element:_store(table.clone(selected))

		return element
	end

	--// Input ----------------------------------------------------------------
	if kind == "input" then
		local element = setmetatable({}, Element)
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local shell = buildShell(container, props, height, 200)
		addHover(element, shell)

		local field = create("Frame", {
			Name = "Field",
			BackgroundColor3 = theme.FieldFill,
			BackgroundTransparency = theme.FieldFillTransparency,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(178, 30),
			Parent = shell.card,
		})
		corner(field, UDim.new(0, 8))
		local fieldStroke = stroke(field, theme.FieldStroke, 1, 0.1)

		local textBox = create("TextBox", {
			Name = "Input",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ClearTextOnFocus = props.clearOnFocus == true,
			PlaceholderText = tostring(props.placeholder or ""),
			PlaceholderColor3 = theme.Placeholder,
			FontFace = FONT_BODY,
			Text = tostring(props.value or ""),
			TextColor3 = theme.Text,
			TextSize = 11.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = field,
		})
		padding(textBox, 0, 10, 0, 10)

		element.value = tostring(props.value or "")

		window:_bind("FieldFill", function(color)
			if field.Parent then
				field.BackgroundColor3 = color
			end
		end)
		window:_bind("FieldStroke", function(color)
			if fieldStroke.Parent then
				fieldStroke.Color = color
			end
		end)
		window:_bind("Placeholder", function(color)
			if textBox.Parent then
				textBox.PlaceholderColor3 = color
			end
		end)
		window:_bind("Text", function(color)
			if textBox.Parent then
				textBox.TextColor3 = color
			end
		end)

		local function commit()
			local text = textBox.Text

			if props.numeric then
				text = string.match(text, "%-?%d*%.?%d+") or element.value or ""
				textBox.Text = text
			end

			element.value = text
			element:_store(text)

			if props.callback then
				task.spawn(props.callback, text)
			end
		end

		textBox.Focused:Connect(function()
			tween(fieldStroke, 0.2, {
				Color = theme.Accent,
				Transparency = 0,
			})
		end)

		textBox.FocusLost:Connect(function()
			tween(fieldStroke, 0.25, {
				Color = theme.FieldStroke,
				Transparency = 0.1,
			})
			commit()
		end)

		if props.numeric then
			textBox:GetPropertyChangedSignal("Text"):Connect(function()
				local filtered = string.match(textBox.Text, "%-?%d*%.?%d*")

				if filtered ~= textBox.Text then
					local caret = textBox.CursorPosition
					textBox.Text = filtered or ""
					textBox.CursorPosition = math.min(caret, #textBox.Text + 1)
				end
			end)
		end

		function element:Set(value, skipCallback)
			element.value = tostring(value or "")
			textBox.Text = element.value
			element:_store(element.value)

			if not skipCallback and props.callback then
				task.spawn(props.callback, element.value)
			end
		end

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			textBox.TextTransparency = locked and 0.5 or 0
			field.BackgroundTransparency = locked and math.min(1, theme.FieldFillTransparency + 0.4)
				or theme.FieldFillTransparency
		end

		attach(element, container, shell.card, height, props, shell)
		element:_store(element.value)

		return element
	end

	--// Keybind --------------------------------------------------------------
	if kind == "keybind" then
		local element = setmetatable({}, Element)
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local shell = buildShell(container, props, height, 160)
		addHover(element, shell)

		local function bindName(value)
			if value == nil then
				return "None"
			end

			if typeof(value) == "EnumItem" then
				return value.Name
			end

			return tostring(value)
		end

		local function resolveBind(value)
			if value == nil or value == "" then
				return nil
			end

			if typeof(value) == "EnumItem" then
				return value
			end

			if type(value) == "string" then
				return Enum.KeyCode[value] or Enum.UserInputType[value] or value
			end

			return value
		end

		local field = create("TextButton", {
			Name = "Bind",
			BackgroundColor3 = theme.FieldFill,
			BackgroundTransparency = theme.FieldFillTransparency,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(140, 30),
			Parent = shell.card,
		})
		corner(field, UDim.new(0, 8))
		local fieldStroke = stroke(field, theme.FieldStroke, 1, 0.1)

		local bindLabel = create("TextLabel", {
			Name = "BindLabel",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = FONT_MEDIUM,
			Text = bindName(resolveBind(props.value)),
			TextColor3 = theme.Text,
			TextSize = 11.5,
			Parent = field,
		})

		element.value = resolveBind(props.value)

		local recording = false
		local holding = false
		local holdToken = nil

		local function stopRecording(cancelled)
			recording = false

			tween(fieldStroke, 0.22, {
				Color = theme.FieldStroke,
				Transparency = 0.1,
			})

			if cancelled then
				bindLabel.Text = bindName(element.value)
			end
		end

		local function apply(value, skipChanged)
			element.value = value
			bindLabel.Text = bindName(value)
			element:_store(value)

			if not skipChanged and props.onChanged then
				task.spawn(props.onChanged, value)
			end
		end

		function element:Set(value, skipChanged)
			local resolved = resolveBind(value)

			if resolved == Enum.KeyCode.RightShift then
				warn("[Vanta] that key is reserved for the menu.")
				return
			end

			apply(resolved, skipChanged)
		end

		window:_bind("FieldFill", function(color)
			if field.Parent then
				field.BackgroundColor3 = color
			end
		end)
		window:_bind("FieldStroke", function(color)
			if fieldStroke.Parent then
				fieldStroke.Color = color
			end
		end)
		window:_bind("Text", function(color)
			if bindLabel.Parent then
				bindLabel.TextColor3 = color
			end
		end)

		field.MouseButton1Click:Connect(function()
			if not element:_guard() then
				return
			end

			recording = true
			bindLabel.Text = "Press a key..."

			tween(fieldStroke, 0.2, {
				Color = theme.Accent,
				Transparency = 0,
			})
		end)

		UserInputService.InputBegan:Connect(function(input, processed)
			if recording then
				if input.KeyCode == Enum.KeyCode.Escape then
					stopRecording(true)
					return
				end

				if input.KeyCode == Enum.KeyCode.Backspace then
					apply(nil, false)
					stopRecording(false)
					return
				end

				if input.KeyCode ~= Enum.KeyCode.Unknown then
					element:Set(input.KeyCode, false)
					stopRecording(false)
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2
				then
					element:Set(input.UserInputType, false)
					stopRecording(false)
				end

				return
			end

			if processed or element.value == nil or element._locked then
				return
			end

			if input.KeyCode ~= element.value and input.UserInputType ~= element.value then
				return
			end

			if props.hold then
				local token = {}
				holdToken = token

				task.delay(props.holdThreshold or 0.2, function()
					if holdToken == token then
						holding = true
						if props.callback then
							task.spawn(props.callback, true)
						end
					end
				end)
			elseif props.callback then
				task.spawn(props.callback, element.value)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode ~= element.value and input.UserInputType ~= element.value then
				return
			end

			holdToken = nil

			if holding then
				holding = false
				if props.callback then
					task.spawn(props.callback, false)
				end
			end
		end)

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			bindLabel.TextTransparency = locked and 0.5 or 0

			if locked and recording then
				stopRecording(true)
			end
		end

		attach(element, container, shell.card, height, props, shell)
		element:_store(element.value)

		return element
	end

	--// Color picker ----------------------------------------------------------
	if kind == "colorpicker" then
		local element = setmetatable({}, Element)
		local height = hasDescription and ELEMENT_HEIGHT_DESC or ELEMENT_HEIGHT
		local PANEL_HEIGHT = 190

		local wrapper = create("Frame", {
			Name = "ColorPicker",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})
		listLayout(wrapper, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left)

		local shell = buildShell({
			window = window,
			frame = wrapper,
			_items = {},
			direction = "column",
			gap = 6,
			_relayout = function() end,
		}, props, height, 92)

		addHover(element, shell)

		local swatch = create("Frame", {
			Name = "Swatch",
			BackgroundColor3 = fromHex(props.color or Color3.new(1, 1, 1)),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(52, 26),
			Parent = shell.card,
		})
		corner(swatch, UDim.new(0, 8))
		stroke(swatch, theme.WindowStroke, 1, 0.4)

		local chevron = create("Frame", {
			Name = "Chevron",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -72, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Parent = shell.card,
		})
		local chevronGlyph = glyphChevron(chevron, theme.TextDim, 13, 1.6)

		local panel = create("Frame", {
			Name = "Panel",
			BackgroundColor3 = theme.FieldFill,
			BackgroundTransparency = theme.FieldFillTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			LayoutOrder = 2,
			Visible = false,
			Parent = wrapper,
		})
		corner(panel, UDim.new(0, 9))
		stroke(panel, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

		local map = create("Frame", {
			Name = "Map",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 10),
			Size = UDim2.new(1, -20, 0, 106),
			ClipsDescendants = true,
			Parent = panel,
		})
		corner(map, UDim.new(0, 7))

		local whiteWash = create("Frame", {
			Name = "White",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = map,
		})
		local whiteGradient = gradient(whiteWash, ColorSequence.new(Color3.new(1, 1, 1)), 0)
		whiteGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})

		local blackWash = create("Frame", {
			Name = "Black",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = map,
		})
		local blackGradient = gradient(blackWash, ColorSequence.new(Color3.new(0, 0, 0)), 90)
		blackGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})

		local mapCursor = create("Frame", {
			Name = "Cursor",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 4,
			Parent = map,
		})
		corner(mapCursor, UDim.new(1, 0))
		stroke(mapCursor, Color3.new(1, 1, 1), 2, 0.15)
		local mapDot = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3, 3),
			ZIndex = 5,
			Parent = map,
		})
		corner(mapDot, UDim.new(1, 0))

		local hueBar = create("Frame", {
			Name = "Hue",
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 124),
			Size = UDim2.new(1, -20, 0, 12),
			Parent = panel,
		})
		corner(hueBar, UDim.new(1, 0))
		gradient(hueBar, ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}), 0)

		local hueCursor = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 18),
			ZIndex = 3,
			Parent = hueBar,
		})
		corner(hueCursor, UDim.new(1, 0))
		stroke(hueCursor, Color3.fromRGB(12, 12, 16), 1.5, 0.3)

		local alphaBar = create("Frame", {
			Name = "Alpha",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 144),
			Size = UDim2.new(1, -20, 0, 12),
			Parent = panel,
		})
		corner(alphaBar, UDim.new(1, 0))

		local alphaGradient = gradient(alphaBar, ColorSequence.new(Color3.new(1, 1, 1)), 0)
		alphaGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})

		local alphaCursor = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 18),
			ZIndex = 3,
			Parent = alphaBar,
		})
		corner(alphaCursor, UDim.new(1, 0))
		stroke(alphaCursor, Color3.fromRGB(12, 12, 16), 1.5, 0.3)

		local hexLabel = create("TextLabel", {
			Name = "Hex",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 162),
			Size = UDim2.new(1, -20, 0, 18),
			FontFace = FONT_MONO,
			Text = "",
			TextColor3 = theme.TextDim,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panel,
		})
		window:_bind("TextDim", function(color)
			if hexLabel.Parent then
				hexLabel.TextColor3 = color
			end
		end)
		window:_bind("FieldFill", function(color)
			if panel.Parent then
				panel.BackgroundColor3 = color
			end
		end)
		window:_bind("TextDim", function(color)
			if chevronGlyph.Parent then
				for _, child in ipairs(chevronGlyph:GetChildren()) do
					if child:IsA("Frame") then
						child.BackgroundColor3 = color
					end
				end
			end
		end)

		local startHue, startSat, startVal = toHSV(fromHex(props.color or Color3.new(1, 1, 1)))
		local hue, saturation, value = startHue, startSat, startVal

		element.value = Color3.fromHSV(hue, saturation, value)
		element.alpha = math.clamp(props.alpha or 1, 0, 1)

		local dragging = false

		local function paint(animate)
			local color = Color3.fromHSV(hue, saturation, value)
			element.value = color

			map.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			mapCursor.Position = UDim2.fromScale(saturation, 1 - value)
			mapDot.Position = UDim2.fromScale(saturation, 1 - value)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			alphaCursor.Position = UDim2.new(element.alpha, 0, 0.5, 0)
			alphaGradient.Color = ColorSequence.new(color)

			swatch.BackgroundColor3 = color
			swatch.BackgroundTransparency = 1 - element.alpha

			local suffix = element.alpha < 0.999
					and string.format("  ·  %d%%", math.floor(element.alpha * 100 + 0.5))
				or ""

			hexLabel.Text = string.upper(toHex(color)) .. suffix
		end

		local function fire(skipCallback)
			element:_store()

			if not skipCallback and props.callback then
				task.spawn(props.callback, element.value, element.alpha)
			end
		end

		local function boundsOf(frame)
			return frame.AbsolutePosition, math.max(frame.AbsoluteSize.X, 1),
				math.max(frame.AbsoluteSize.Y, 1)
		end

		local function updateFrom(x, y)
			local originX, width, height = boundsOf(map)
			saturation = math.clamp((x - originX.X) / width, 0, 1)
			value = 1 - math.clamp((y - originX.Y) / height, 0, 1)
			paint()
			fire(false)
		end

		local function updateHue(x)
			local originX, width = boundsOf(hueBar)
			hue = math.clamp((x - originX.X) / width, 0, 1)
			paint()
			fire(false)
		end

		local function updateAlpha(x)
			local originX, width = boundsOf(alphaBar)
			element.alpha = math.clamp((x - originX.X) / width, 0, 1)
			paint()
			fire(false)
		end

		local dragTarget = nil

		local function beginDrag(target, input)
			dragging = true
			dragTarget = target

			if target == "map" then
				updateFrom(input.Position.X, input.Position.Y)
			elseif target == "hue" then
				updateHue(input.Position.X)
			else
				updateAlpha(input.Position.X)
			end
		end

		for name, target in pairs({ ["map"] = map, ["hue"] = hueBar, ["alpha"] = alphaBar }) do
			target.InputBegan:Connect(function(input)
				if not element:_guard() then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					beginDrag(name, input)
				end
			end)
		end

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				if dragTarget == "map" then
					updateFrom(input.Position.X, input.Position.Y)
				elseif dragTarget == "hue" then
					updateHue(input.Position.X)
				else
					updateAlpha(input.Position.X)
				end
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
				dragTarget = nil
			end
		end)

		local open = false
		local panelSpring = Spring.new(0, function(progress)
			if not panel.Parent then
				return
			end

			panel.Size = UDim2.new(1, 0, 0, PANEL_HEIGHT * progress)
			panel.Visible = progress > 0.002
		end, { stiffness = 300, damping = 28, attach = panel })

		local function setOpen(state)
			open = state
			panelSpring:to(state and 1 or 0)
			tween(chevron, 0.32, { Rotation = state and 180 or 0 }, Enum.EasingStyle.Quint)
		end

		function element:Set(value, skipCallback)
			if type(value) == "table" then
				if value.alpha ~= nil then
					element.alpha = math.clamp(tonumber(value.alpha) or 1, 0, 1)
				end

				value = value.color or value.value or value[1]
			end

			local nextHue, nextSat, nextVal = toHSV(fromHex(value))
			hue, saturation, value = nextHue, nextSat, nextVal
			paint()
			fire(skipCallback == true)
		end

		function element:SetAlpha(alpha, skipCallback)
			element.alpha = math.clamp(alpha or 1, 0, 1)
			paint()
			fire(skipCallback == true)
		end

		shell.card.Active = true
		shell.card.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			if not element:_guard() then
				return
			end

			setOpen(not open)
		end)

		element._applyLock = function(locked)
			shell.label.TextColor3 = locked and theme.TextDim or theme.Text
			swatch.BackgroundTransparency = locked and 0.6 or (1 - element.alpha)

			if locked and open then
				setOpen(false)
			end
		end

		attach(element, container, wrapper, height, props, shell)

		function element:_store()
			if self._flag then
				window._values[self._flag] = {
					color = toHex(element.value),
					alpha = element.alpha,
				}
				window:_markDirty()
			end
		end

		paint()
		element:_store()

		return element
	end

	--// Stat -----------------------------------------------------------------
	if kind == "stat" then
		local element = setmetatable({}, Element)
		local compact = props.compact == true or container.direction == "row"
			or container.direction == "grid"
		local display = props.display == "change" and "change" or "value"
		local showDelta = not compact
		local height = compact and ELEMENT_HEIGHT or (hasDescription and 74 or 64)
		local shell = buildShell(container, props, height, compact and 78 or 86)

		element.value = tonumber(props.value) or 0
		local initial = element.value
		local displayed = element.value
		local previousValue = element.value
		local rollToken = 0

		local changeMode = props.changeMode or "percentage"
		local changeBaseline = props.changeBaseline or "previous"

		-- A compact card has room for one figure: either the value or the change.
		local changeFigure = compact and display == "change"

		local valueLabel = create("TextLabel", {
			Name = "Value",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, shell.left, 0, compact and 0 or 28),
			Size = UDim2.new(1, -(shell.left + (compact and 78 or 86)), 0, compact and height or 26),
			FontFace = FONT_TITLE,
			TextColor3 = theme.TitleText,
			TextSize = compact and 14 or 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = compact and Enum.TextYAlignment.Center
				or Enum.TextYAlignment.Top,
			Parent = shell.card,
		})

		local deltaLabel
		if showDelta then
			deltaLabel = create("TextLabel", {
				Name = "Delta",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -13, 0.4, 0),
				Size = UDim2.fromOffset(70, 16),
				FontFace = FONT_MEDIUM,
				Text = "",
				TextColor3 = theme.TextDim,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = shell.card,
			})
		end

		window:_bind("TitleText", function(color)
			if valueLabel.Parent and not changeFigure then
				valueLabel.TextColor3 = color
			end
		end, shell.card)

		-- The change indicator's text and colour, shared by the compact card.
		local function changeInfo(previous)
			local baseline = changeBaseline == "initial" and initial or previous
			local delta = element.value - baseline

			if delta == 0 then
				return "no change", theme.TextDim
			end

			local magnitude = math.abs(delta)
			local text = (delta > 0 and "+" or "-") .. shortNumber(magnitude)

			if changeMode == "percentage" and baseline ~= 0 then
				text ..= string.format(" (%.1f%%)", magnitude / math.abs(baseline) * 100)
			end

			return text, (delta > 0 and theme.Success or theme.Danger)
		end

		local function render()
			if changeFigure then
				local text, color = changeInfo(previousValue)
				valueLabel.Text = text
				valueLabel.TextColor3 = color
				return
			end

			valueLabel.Text = tostring(props.prefix or "")
				.. shortNumber(displayed)
				.. tostring(props.suffix or "")
		end

		local function rollTo(target)
			rollToken += 1
			local token = rollToken

			if changeFigure or props.numberEasing == false then
				displayed = target
				render()
				return
			end

			task.spawn(function()
				local from = displayed
				local started = os.clock()

				while true do
					if rollToken ~= token then
						return
					end

					local alpha = math.clamp((os.clock() - started) / 0.5, 0, 1)
					displayed = from
						+ (target - from)
							* TweenService:GetValue(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
					render()

					if alpha >= 1 then
						return
					end

					RunService.RenderStepped:Wait()
				end
			end)
		end

		local function renderDelta(previous)
			if not deltaLabel then
				return
			end

			local text, color = changeInfo(previous)
			deltaLabel.Text = text
			deltaLabel.TextColor3 = color
		end

		function element:Set(value)
			previousValue = element.value
			element.value = tonumber(value) or 0

			rollTo(element.value)
			renderDelta(previousValue)
		end

		function element:ResetBaseline(value)
			initial = tonumber(value) or element.value
			renderDelta(initial)

			if changeFigure then
				render()
			end
		end

		attach(element, container, shell.card, height, props, shell)
		render()
		renderDelta(initial)

		return element
	end

	--// Progress -------------------------------------------------------------
	if kind == "progress" then
		local element = setmetatable({}, Element)
		local steps = tonumber(props.steps)
		local range = props.range

		if not range and steps and steps >= 2 then
			range = { 0, steps }
		end

		range = range or { 0, 1 }

		local minimum = range[1] or 0
		local maximum = range[2] or 1
		local hasName = props.name ~= nil and props.name ~= ""
		local height = hasName and (hasDescription and 74 or 58) or 32
		local shell = buildShell(container, props, height, 90)

		element.value = math.clamp(props.value or minimum, minimum, maximum)
		local indeterminate = props.indeterminate == true
		local customText = props.text

		local barY = hasName and 34 or 0

		local track = create("Frame", {
			Name = "Track",
			BackgroundColor3 = theme.SliderTrack,
			BackgroundTransparency = theme.SliderTrackTransparency,
			BorderSizePixel = 0,
			Position = hasName and UDim2.new(0, 13, 0, barY) or UDim2.new(0, 13, 0.5, 0),
			AnchorPoint = hasName and Vector2.new(0, 0) or Vector2.new(0, 0.5),
			Size = UDim2.new(1, -26, 0, 6),
			ClipsDescendants = true,
			Parent = shell.card,
		})
		corner(track, UDim.new(1, 0))

		local fill = create("Frame", {
			Name = "Fill",
			BackgroundColor3 = theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = track,
		})
		corner(fill, UDim.new(1, 0))
		local fillGradient = gradient(fill, ColorSequence.new(theme.Accent, theme.AccentAlt), 0)
		window:_bind("Accent", function(color)
			if fill.Parent then
				fillGradient.Color = ColorSequence.new(color, window._theme.AccentAlt)
			end
		end)
		window:_bind("AccentAlt", function(color)
			if fill.Parent then
				fillGradient.Color = ColorSequence.new(window._theme.Accent, color)
			end
		end)
		window:_bind("SliderTrack", function(color)
			if track.Parent then
				track.BackgroundColor3 = color
			end
		end)

		local segments = {}

		if steps and steps >= 2 then
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundTransparency = 1
			gradient(fill, ColorSequence.new(Color3.new(1, 1, 1)), 0)

			local strip = create("Frame", {
				Name = "Segments",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = track,
			})
			listLayout(strip, Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left)

			for index = 1, steps do
				local segment = create("Frame", {
					Name = "Step" .. index,
					BackgroundColor3 = theme.SliderTrack,
					BorderSizePixel = 0,
					Size = UDim2.new(1 / steps, -(3 * (steps - 1)) / steps, 1, 0),
					LayoutOrder = index,
					Parent = strip,
				})
				corner(segment, UDim.new(1, 0))
				segments[index] = segment
			end
		end

		local readout
		if props.showValue ~= false then
			readout = create("TextLabel", {
				Name = "Readout",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = hasName and UDim2.new(1, -13, 0, 17) or UDim2.new(1, -13, 0.5, 0),
				Size = UDim2.fromOffset(84, 16),
				FontFace = FONT_MEDIUM,
				TextColor3 = theme.Text,
				TextSize = 11.5,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = shell.card,
			})
			window:_bind("Text", function(color)
				if readout.Parent then
					readout.TextColor3 = color
				end
			end)
		end

		local sweep

		local function percentage()
			if maximum == minimum then
				return 0
			end

			return math.clamp((element.value - minimum) / (maximum - minimum), 0, 1)
		end

		local function renderReadout()
			if not readout then
				return
			end

			if customText then
				readout.Text = customText
				return
			end

			if props.format then
				readout.Text = tostring(props.format(element.value, minimum, maximum))
				return
			end

			if steps then
				readout.Text = shortNumber(element.value) .. "/" .. tostring(steps)
				return
			end

			readout.Text = tostring(math.floor(percentage() * 100 + 0.5)) .. "%"
		end

		local function stopSweep()
			if sweep then
				sweep:Cancel()
				sweep = nil
			end

			fill.Position = UDim2.fromScale(0, 0)
		end

		local function startSweep()
			fill.Size = UDim2.new(0.3, 0, 1, 0)
			fill.BackgroundTransparency = 0

			local function cycle()
				if not indeterminate then
					return
				end

				fill.Position = UDim2.new(-0.3, 0, 0, 0)
				sweep = tween(fill, 1.1, {
					Position = UDim2.new(1, 0, 0, 0),
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

				sweep.Completed:Connect(function()
					cycle()
				end)
			end

			cycle()
		end

		function element:Set(value)
			indeterminate = false
			stopSweep()
			element.value = math.clamp(tonumber(value) or minimum, minimum, maximum)
			fill.BackgroundTransparency = 0

			if steps then
				local reached = math.floor(element.value + 0.0001)

				for index, segment in ipairs(segments) do
					tween(segment, 0.25, {
						BackgroundColor3 = index <= reached
								and window._theme.Accent
							or window._theme.SliderTrack,
					})
				end

				fill.Size = UDim2.new(percentage(), 0, 1, 0)
			else
				tween(fill, 0.3, {
					Size = UDim2.new(percentage(), 0, 1, 0),
				}, Enum.EasingStyle.Quart)
			end

			renderReadout()
		end

		function element:Get()
			return element.value
		end

		function element:GetPercentage()
			return percentage()
		end

		function element:SetRange(min, max)
			minimum = min or minimum
			maximum = max or maximum

			if props.steps and not props.range then
				maximum = props.steps
			end

			element:Set(element.value)
		end

		function element:SetText(text)
			customText = text
			renderReadout()
		end

		function element:SetIndeterminate(state)
			indeterminate = state == true

			if indeterminate then
				startSweep()
				if readout then
					readout.Text = ""
				end
			else
				stopSweep()
				element:Set(element.value)
			end
		end

		attach(element, container, shell.card, height, props, shell)

		if indeterminate then
			startSweep()
		else
			element:Set(element.value)
		end

		return element
	end

	--// Console --------------------------------------------------------------
	if kind == "console" then
		local element = setmetatable({}, Element)
		local panelHeight = math.max(tonumber(props.height) or 120, 48)
		local hasName = props.name ~= nil and props.name ~= ""
		local height = (hasName and 32 or 12) + panelHeight + 12

		local card = create("Frame", {
			Name = props.name or "Console",
			BackgroundColor3 = theme.Surface,
			BackgroundTransparency = theme.SurfaceTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = #container._items + 1,
			Parent = container.frame,
		})
		corner(card, theme.CornerElement)
		local cardStroke = stroke(card, theme.ElementStroke, 1, theme.ElementStrokeTransparency)

		local nameLabel
		if hasName then
			nameLabel = create("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 13, 0, 8),
				Size = UDim2.new(1, -26, 0, 16),
				FontFace = FONT_MEDIUM,
				Text = tostring(props.name),
				TextColor3 = theme.Text,
				TextSize = 12.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
		end

		local panel = create("Frame", {
			Name = "Panel",
			BackgroundColor3 = theme.FieldFill,
			BackgroundTransparency = theme.FieldFillTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, hasName and 30 or 6),
			Size = UDim2.new(1, -20, 0, panelHeight),
			ClipsDescendants = true,
			Parent = card,
		})
		corner(panel, UDim.new(0, 8))

		local scroll = create("ScrollingFrame", {
			Name = "Scroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme.ElementStroke,
			ScrollBarImageTransparency = 0.3,
			Parent = panel,
		})
		padding(scroll, 8, 8, 8, 8)

		local body = create("TextLabel", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = FONT_MONO,
			Text = "",
			TextColor3 = theme.TextDim,
			TextSize = 11,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = scroll,
		})

		window:_bind("Surface", function(color)
			if card.Parent then
				card.BackgroundColor3 = color
			end
		end)
		window:_bind("ElementStroke", function(color)
			if cardStroke.Parent then
				cardStroke.Color = color
			end
		end)
		window:_bind("FieldFill", function(color)
			if panel.Parent then
				panel.BackgroundColor3 = color
			end
		end)
		window:_bind("Text", function(color)
			if nameLabel and nameLabel.Parent then
				nameLabel.TextColor3 = color
			end
		end)
		window:_bind("TextDim", function(color)
			if body.Parent then
				body.TextColor3 = color
			end
		end)

		local lines = {}
		local maxLines = tonumber(props.maxLines) or 200
		local follow = props.follow == true

		if props.text or props.code then
			for line in string.gmatch(tostring(props.text or props.code) .. "\n", "([^\n]*)\n") do
				table.insert(lines, line)
			end
		end

		local function render()
			while #lines > maxLines do
				table.remove(lines, 1)
			end

			body.Text = table.concat(lines, "\n")

			if follow then
				task.defer(function()
					scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y))
				end)
			end
		end

		function element:Set(text)
			lines = {}

			for line in string.gmatch(tostring(text or "") .. "\n", "([^\n]*)\n") do
				table.insert(lines, line)
			end

			render()
		end

		function element:Append(line)
			for part in string.gmatch(tostring(line) .. "\n", "([^\n]*)\n") do
				table.insert(lines, part)
			end

			render()
		end

		function element:Clear()
			lines = {}
			render()
		end

		function element:Get()
			return table.concat(lines, "\n")
		end

		function element:Copy()
			local setter = rawget(getfenv(), "setclipboard") or setclipboard

			if type(setter) ~= "function" then
				return false
			end

			return (pcall(setter, element:Get()))
		end

		function element:SetHeight(value)
			panelHeight = math.max(tonumber(value) or panelHeight, 48)
			panel.Size = UDim2.new(1, -20, 0, panelHeight)

			local nextHeight = (hasName and 32 or 12) + panelHeight + 12
			card.Size = UDim2.new(1, 0, 0, nextHeight)
			element._entry.height = nextHeight
		end

		attach(element, container, card, height, props, nil)
		render()

		return element
	end

	return nil
end

--// Groups and tabs ---------------------------------------------------------

Group = {}
Group.__index = Group

function Group.new(window, parent, props)
	props = normalizeProps(props or {})

	local self = setmetatable({}, Group)
	self.window = window

	local direction = props.direction or "row"
	if direction == "horizontal" then
		direction = "row"
	elseif direction == "vertical" then
		direction = "column"
	end

	local frame = create("Frame", {
		Name = "Group",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #parent._items + 1,
		Parent = parent.frame,
	})

	buildContainer(self, frame, direction, props.gap or GAP)
	self._entry = containerAdd(parent, frame, ELEMENT_HEIGHT)

	function self:Remove()
		containerRemove(parent, self._entry)
	end

	function self:CreateGroup(childProps)
		return Group.new(window, self, childProps)
	end

	return self
end

Tab = {}
Tab.__index = Tab

function Tab.new(window, props)
	props = normalizeProps(props or {})

	local self = setmetatable({}, Tab)
	self.window = window
	self._name = props.name or props.title or ""
	self._icon = props.icon

	local holder = create("CanvasGroup", {
		Name = "Tab_" .. (self._name ~= "" and self._name or "unnamed"),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Visible = false,
		Parent = window._content,
	})
	self.holder = holder

	local scroll = create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = window._theme.ElementStroke,
		ScrollBarImageTransparency = 0.35,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = holder,
	})
	self.scroll = scroll

	local page = create("Frame", {
		Name = "Page",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	padding(page, PAD, PAD, PAD, PAD)
	self.page = page

	buildContainer(self, page, "grid", GAP)

	local slide = Spring.new(0, function(offset)
		if holder.Parent then
			holder.Position = UDim2.new(0, 0, 0, offset)
		end
	end, { stiffness = 240, damping = 26, attach = holder })
	self._slide = slide

	-- button --------------------------------------------------------------
	local button
	local iconLabel
	local textLabel

	if window._sidebar then
		window._railOrder += 1

		button = create("TextButton", {
			Name = "TabButton",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.new(1, 0, 0, RAIL_ITEM_HEIGHT),
			LayoutOrder = window._railOrder,
			Position = UDim2.fromOffset(0, window:_railNext()),
			Parent = window._railScroll,
		})

		if self._icon and self._icon ~= 0 and self._icon ~= "" then
			iconLabel = create("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(17, 17),
				Image = window:_resolveIcon(self._icon),
				ImageColor3 = window._theme.TabText,
				Parent = button,
			})
		end

		textLabel = create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, iconLabel and 42 or 14, 0, 0),
			Size = UDim2.new(1, -(iconLabel and 52 or 24), 1, 0),
			FontFace = FONT_MEDIUM,
			Text = self._name,
			TextColor3 = window._theme.TabText,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
	else
		button = create("TextButton", {
			Name = "TabButton",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = #window._tabs + 1,
			Parent = window._tabList,
		})
		corner(button, window._theme.CornerPill)
		padding(button, 0, 14, 0, 14)
		listLayout(button, Enum.FillDirection.Horizontal, 7, Enum.HorizontalAlignment.Center)

		if self._icon and self._icon ~= 0 and self._icon ~= "" then
			iconLabel = create("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(15, 15),
				Image = window:_resolveIcon(self._icon),
				ImageColor3 = window._theme.TabText,
				LayoutOrder = 1,
				Parent = button,
			})
		end

		textLabel = create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			FontFace = FONT_MEDIUM,
			Text = self._name,
			TextColor3 = window._theme.TabText,
			TextSize = 12,
			LayoutOrder = 2,
			Parent = button,
		})
	end

	self._button = button

	window:_registerLabel(function(text)
		if textLabel.Parent then
			textLabel.Text = text
		end
	end, self._name)

	-- behaviour -----------------------------------------------------------
	local function paint(active, hovered)
		local color = active and window._theme.TabTextActive
			or (hovered and window._theme.Text) or window._theme.TabText

		tween(textLabel, 0.2, { TextColor3 = color })

		if iconLabel then
			tween(iconLabel, 0.2, { ImageColor3 = color })
		end
	end

	self._paint = paint

	button.MouseEnter:Connect(function()
		if window._activeTab ~= self then
			paint(false, true)
		end
	end)

	button.MouseLeave:Connect(function()
		if window._activeTab ~= self then
			paint(false, false)
		end
	end)

	button.MouseButton1Click:Connect(function()
		self:Select()
	end)

	window:_bind("TabText", function(color)
		if window._activeTab ~= self then
			textLabel.TextColor3 = color
			if iconLabel then
				iconLabel.ImageColor3 = color
			end
		end
	end, holder)
	window:_bind("TabTextActive", function(color)
		if window._activeTab == self then
			textLabel.TextColor3 = color
			if iconLabel then
				iconLabel.ImageColor3 = color
			end
		end
	end, holder)
	window:_bind("CornerPill", function(radius)
		if not window._sidebar then
			button:FindFirstChildOfClass("UICorner").CornerRadius = radius
		end
	end, holder)

	function self:Select(noAnimation)
		if window._activeTab == self or window._unloaded then
			return
		end

		local previous = window._activeTab

		if previous then
			previous:_deactivate()
		end

		window._activeTab = self
		holder.Visible = true

		if noAnimation then
			holder.GroupTransparency = 0
			slide:snap(0)
		else
			holder.GroupTransparency = 1
			tween(holder, 0.26, { GroupTransparency = 0 })
			slide:snap(14)
			slide:to(0)
		end

		paint(true, false)
		window:_syncIndicator(noAnimation == true)

		if window._stripIndicator then
			window._stripIndicator.Visible = true
		end

		if window._railIndicator then
			window._railIndicator.Visible = true
		end

		if window._sidebar and window._railScroll then
			local buttonY = button.Position.Y.Offset
			local viewport = window._railScroll.AbsoluteWindowSize.Y
			local current = window._railScroll.CanvasPosition.Y

			if buttonY < current then
				tween(window._railScroll, 0.3, { CanvasPosition = Vector2.new(0, buttonY - 8) })
			elseif buttonY + RAIL_ITEM_HEIGHT > current + viewport then
				tween(window._railScroll, 0.3, {
					CanvasPosition = Vector2.new(0, buttonY + RAIL_ITEM_HEIGHT - viewport + 8),
				})
			end
		end
	end

	function self:_deactivate()
		if window._activeTab ~= self then
			return
		end

		holder.Visible = false
		paint(false, false)
	end

	function self:Deselect(noAnimation)
		if window._activeTab ~= self then
			return
		end

		holder.Visible = false
		paint(false, false)
		window._activeTab = nil
	end

	function self:Remove()
		holder:Destroy()
		button:Destroy()

		local index = table.find(window._tabs, self)

		if index then
			table.remove(window._tabs, index)
		end

		if window._activeTab == self then
			window._activeTab = nil

			local next_ = window._tabs[1]

			if next_ then
				next_:Select(true)
			end
		end

		if window._sidebar then
			window:_relayoutRail()
		end
	end

	function self:CreateGroup(groupProps)
		return Group.new(window, self, groupProps)
	end

	return self
end

--// Element constructors ----------------------------------------------------
-- Tabs and groups both build elements; the only difference is the container.

local ELEMENT_METHODS = {
	CreateButton = "button",
	CreateToggle = "toggle",
	CreateSwitch = "toggle",
	CreateSlider = "slider",
	CreateDropdown = "dropdown",
	CreateInput = "input",
	CreateKeybind = "keybind",
	CreateColorPicker = "colorpicker",
	CreateStat = "stat",
	CreateProgress = "progress",
	CreateConsole = "console",
	CreateText = "text",
	CreateDivider = "divider",
	CreateSection = "section",
}

for methodName, kind in pairs(ELEMENT_METHODS) do
	Tab[methodName] = function(self, props)
		return createElement(kind, self, props)
	end

	Group[methodName] = function(self, props)
		return createElement(kind, self, props)
	end
end

function Window:_railNext(height)
	local y = self._railY or 8
	self._railY = y + (height or RAIL_ITEM_HEIGHT) + RAIL_ITEM_GAP
	return y
end

function Window:_relayoutRail()
	self._railY = 8

	local children = {}

	for _, child in ipairs(self._railScroll:GetChildren()) do
		if (child:IsA("TextButton") and child.Name == "TabButton")
			or (child:IsA("TextLabel") and child.Name == "RailSection")
		then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			child.Position = UDim2.fromOffset(0, self:_railNext(26))
		else
			child.Position = UDim2.fromOffset(0, self:_railNext())
		end
	end
end

function Window:CreateTab(props)
	if self._unloaded then
		return nil
	end

	local tab = Tab.new(self, props)
	table.insert(self._tabs, tab)

	if not self._activeTab then
		tab:Select(true)

		afterLayout(function()
			if not self._unloaded then
				self:_syncIndicator(true)
			end
		end)
	end

	return tab
end

function Window:CreateSection(props)
	props = normalizeProps(props or {})

	if not self._sidebar or not self._railScroll then
		return nil
	end

	self._railOrder += 1

	local heading = create("TextLabel", {
		Name = "RailSection",
		BackgroundTransparency = 1,
		LayoutOrder = self._railOrder,
		Position = UDim2.fromOffset(0, self:_railNext(26)),
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = FONT_MEDIUM,
		Text = string.upper(tostring(props.name or "")),
		TextColor3 = self._theme.TextDim,
		TextSize = 9.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._railScroll,
	})
	padding(heading, 0, 0, 0, 14)

	self:_bind("TextDim", function(color)
		if heading.Parent then
			heading.TextColor3 = color
		end
	end)

	local window = self
	local handle = {}

	function handle:Remove()
		if heading.Parent then
			heading:Destroy()
		end

		if not window._unloaded then
			window:_relayoutRail()
		end
	end

	return handle
end

--// CreateWindow ------------------------------------------------------------

local THEME_NAMES = { "default", "cobalt", "ember", "amethyst", "frost", "rose", "mono" }

function Window:_buildSettingsTab()
	if self._settingsBuilt or self._unloaded then
		return nil
	end

	self._settingsBuilt = true

	local tab = self:CreateTab({ name = "Settings" })

	tab:CreateSection({ name = "Appearance" })
	tab:CreateDropdown({
		name = "Theme",
		options = THEME_NAMES,
		value = self._themeName or "default",
		placeholder = "default",
		forgetState = true,
		callback = function(value)
			self:ChangeTheme(value)
		end,
	})

	tab:CreateSlider({
		name = "Interface scale",
		range = { 80, 120 },
		increment = 5,
		value = 100,
		suffix = "%",
		forgetState = true,
		callback = function(value)
			local scale = self._root:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = value / 100
			end
		end,
	})

	if self._configFile then
		tab:CreateSection({ name = "Configurations" })

		local nameInput = tab:CreateInput({
			name = "Configuration name",
			placeholder = "default",
			value = "default",
			forgetState = true,
		})

		tab:CreateButton({
			name = "Save",
			callback = function()
				local name = nameInput.value ~= "" and nameInput.value or nil

				if self:Save(name) then
					self:Notify({
						title = "Saved",
						content = "Configuration " .. (name or "default") .. " written.",
					})
				else
					self:Notify({
						title = "Not saved",
						content = "This executor has no filesystem access.",
						color = self._theme.Danger,
					})
				end
			end,
		})

		tab:CreateButton({
			name = "Load",
			callback = function()
				local name = nameInput.value ~= "" and nameInput.value or nil

				if self:Load(name) then
					self:Toast({ title = "Loaded" })
				else
					self:Toast({ title = "Nothing to load" })
				end
			end,
		})

		tab:CreateButton({
			name = "Delete",
			callback = function()
				if self:DeleteConfig(nameInput.value) then
					self:Toast({ title = "Deleted" })
				end
			end,
		})
	end

	tab:CreateSection({ name = "Interface" })

	tab:CreateToggle({
		name = "Show profile card",
		value = true,
		forgetState = true,
		callback = function(value)
			if self._profileCard then
				self._profileCard.Visible = value
			end
		end,
	})

	tab:CreateButton({
		name = "Unload interface",
		callback = function()
			self:Unload()
		end,
	})

	tab:CreateDivider()

	tab:CreateText({
		name = "Vanta",
		text = "Version " .. Vanta.Version .. ". Drawn in code, dark by default.",
	})

	return tab
end

function Vanta:CreateWindow(props)
	props = normalizeProps(props or {})

	local window = setmetatable({}, Window)

	window._gui = createGui()

	if not window._gui then
		error("[Vanta] could not find a parent for the interface.", 2)
	end

	window._name = props.name or props.title or "Vanta"
	window._subtitle = props.subtitle
	window._icon = props.icon
	window._sidebar = props.sidebarLayout == true
	window._profile = props.profile
	window._showName = props.showName or "Vanta"
	window._showIcon = props.showIcon
	window._showIconOnly = props.showIconOnly == true
	window._themeName = type(props.theme) == "string" and string.lower(props.theme) or "default"
	window._theme = resolveTheme(props.theme)
	window._railWidth = window._theme.RailWidth or 188
	window._bindings = {}
	window._tabs = {}
	window._items = {}
	window._elements = {}
	window._values = {}
	window._labelBindings = {}
	window._translations = {}
	window._translator = props.translator
	window._unloaded = false
	window._hidden = false
	window._minimised = false
	window._railY = 8
	window._railOrder = 0

	window._width = window._sidebar and 780 or 620
	window._height = window._sidebar and 486 or 468

	window.Flags = makeFlags(window)

	for locale, pack in pairs(props.translations or {}) do
		window._translations[string.lower(locale)] = pack
	end

	local locale = props.locale

	if not locale and Players.LocalPlayer then
		locale = Players.LocalPlayer.LocaleId
	end

	window._locale = string.lower(locale or "en")

	window:_build()
	window:_buildPill()

	local configuration = props.configuration

	if type(configuration) == "table" then
		window._configFile = configuration.fileName or window._name
		window._configFolder = configuration.customFolder
		window._autoSave = configuration.autoSave == true

		if configuration.autoLoad ~= false then
			task.defer(function()
				window:Load()
			end)
		end
	end

	task.defer(function()
		window:_buildSettingsTab()
	end)

	if props.heartbeat then
		task.spawn(function()
			while not window._unloaded do
				pcall(function()
					HttpService:GetAsync(props.heartbeat)
				end)
				task.wait(60)
			end
		end)
	end

	return window
end

return Vanta

