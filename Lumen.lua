--[[
    Lumen UI Library (Redesigned - Polished Icons & Controls Edition)
    A sleek, modern, high-performance UI library for Roblox.
    Fully compatible with the original Lumen API.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Lumen = { Version = "0.3.3" }

------------------------------------------------------------------------
-- Themes & Color Schemes
------------------------------------------------------------------------

local DefaultTheme = {
	bg = Color3.fromRGB(20, 22, 32),
	panel = Color3.fromRGB(26, 29, 42),
	card = Color3.fromRGB(34, 38, 56),
	cardHover = Color3.fromRGB(44, 49, 70),
	stroke = Color3.fromRGB(58, 64, 94),
	strokeGlow = Color3.fromRGB(135, 145, 255),
	text = Color3.fromRGB(246, 248, 255),
	subtext = Color3.fromRGB(152, 160, 188),
	accent = Color3.fromRGB(130, 140, 255),
	accent2 = Color3.fromRGB(95, 220, 248),
	danger = Color3.fromRGB(250, 80, 105),
}

local ThemeOverrides = {
	default = {},
	softpink = {
		bg = Color3.fromRGB(20, 20, 26),
		panel = Color3.fromRGB(27, 26, 34),
		card = Color3.fromRGB(37, 35, 48),
		cardHover = Color3.fromRGB(48, 45, 60),
		stroke = Color3.fromRGB(68, 62, 82),
		strokeGlow = Color3.fromRGB(255, 105, 180),
		text = Color3.fromRGB(255, 250, 253),
		subtext = Color3.fromRGB(182, 168, 185),
		accent = Color3.fromRGB(255, 82, 168),
		accent2 = Color3.fromRGB(255, 155, 220),
		danger = Color3.fromRGB(255, 75, 105),
	},
	cobalt = {
		accent = Color3.fromRGB(62, 145, 255),
		accent2 = Color3.fromRGB(80, 220, 255),
		strokeGlow = Color3.fromRGB(62, 145, 255),
	},
	ember = {
		accent = Color3.fromRGB(255, 120, 60),
		accent2 = Color3.fromRGB(255, 195, 75),
		strokeGlow = Color3.fromRGB(255, 120, 60),
	},
	amethyst = {
		accent = Color3.fromRGB(180, 100, 255),
		accent2 = Color3.fromRGB(240, 115, 215),
		strokeGlow = Color3.fromRGB(180, 100, 255),
	},
	frost = {
		bg = Color3.fromRGB(12, 18, 26),
		panel = Color3.fromRGB(18, 28, 40),
		card = Color3.fromRGB(26, 40, 56),
		cardHover = Color3.fromRGB(34, 52, 74),
		stroke = Color3.fromRGB(48, 70, 98),
		accent = Color3.fromRGB(96, 200, 255),
		accent2 = Color3.fromRGB(180, 240, 255),
		strokeGlow = Color3.fromRGB(96, 200, 255),
	},
	rose = {
		accent = Color3.fromRGB(255, 88, 128),
		accent2 = Color3.fromRGB(255, 165, 125),
		strokeGlow = Color3.fromRGB(255, 88, 128),
	},
}

local function resolveTheme(theme)
	local out = {}
	for k, v in pairs(DefaultTheme) do
		out[k] = v
	end
	local overrides
	if type(theme) == "string" then
		overrides = ThemeOverrides[theme:lower()]
	elseif type(theme) == "table" then
		overrides = theme
	end
	if overrides then
		for k, v in pairs(overrides) do
			out[k] = v
		end
	end
	return out
end

------------------------------------------------------------------------
-- Utilities & Helpers
------------------------------------------------------------------------

local function pick(props, key, default)
	if props == nil then
		return default
	end
	local v = props[key]
	if v == nil then
		v = props[key:sub(1, 1):upper() .. key:sub(2)]
	end
	if v == nil then
		return default
	end
	return v
end

local WEIGHTS = {
	Regular = { Enum.Font.GothamMedium, Enum.FontWeight.Medium },
	Medium = { Enum.Font.GothamSemibold, Enum.FontWeight.SemiBold },
	SemiBold = { Enum.Font.GothamBold, Enum.FontWeight.Bold },
	Bold = { Enum.Font.GothamBlack, Enum.FontWeight.ExtraBold },
}
local FACE_CACHE = {}

local function applyWeight(inst, weight)
	local w = WEIGHTS[weight] or WEIGHTS.Medium
	inst.Font = w[1]
	pcall(function()
		local face = FACE_CACHE[weight]
		if not face then
			face = Font.new("rbxasset://fonts/families/Inter.json", w[2])
			FACE_CACHE[weight] = face
		end
		inst.FontFace = face
	end)
end

local function create(class, props, children)
	local inst = Instance.new(class)
	local parent, weight
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif k == "Weight" then
			weight = v
		else
			inst[k] = v
		end
	end
	if weight then
		applyWeight(inst, weight)
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function tween(inst, duration, goal, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function round(v)
	return math.floor(v * 1e6 + 0.5) / 1e6
end

local function assetId(icon)
	if icon == nil or icon == 0 or icon == "" then
		return nil
	end
	if type(icon) == "number" or tonumber(icon) then
		return "rbxassetid://" .. tostring(icon)
	end
	return tostring(icon)
end

local function fire(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn("[Lumen] Callback error: " .. tostring(err))
		end
	end)
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 10), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
	local s = create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Color3.fromRGB(58, 64, 94),
		Thickness = thickness or 1.6,
		Transparency = transparency or 0.3,
		Parent = parent,
	})
	return s
end

local function getGuiParent(gui)
	local ok, ui = pcall(function()
		if type(gethui) == "function" then
			return gethui()
		end
		return nil
	end)
	if ok and ui and not ui:IsA("LayerCollector") then
		local okSet = pcall(function()
			gui.Parent = ui
		end)
		if okSet and gui.Parent == ui then
			return
		end
	end
	local okCore = pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
	if okCore and gui.Parent then
		return
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

------------------------------------------------------------------------
-- Dynamic Theme Binding
------------------------------------------------------------------------

local function bind(win, inst, prop, key)
	inst[prop] = win.theme[key]
	table.insert(win._bindings, { inst = inst, prop = prop, key = key })
end

local function bindGradient(win, grad, kind)
	local function apply()
		local t = win.theme
		if kind == "accent" then
			grad.Color = ColorSequence.new(t.accent, t.accent2)
		else
			grad.Color = ColorSequence.new(t.bg, t.bg:Lerp(t.accent, 0.08))
		end
	end
	apply()
	table.insert(win._refreshers, apply)
end

------------------------------------------------------------------------
-- Component Architecture
------------------------------------------------------------------------

local ROW_H = 48
local PAD = 14

local function buildRow(win, props, height, rightPad, topH)
	topH = topH or height
	local name = tostring(pick(props, "name", ""))
	local desc = pick(props, "description")
	local icon = assetId(pick(props, "icon"))

	local row = create("Frame", {
		Name = name ~= "" and name or "Element",
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
	})
	bind(win, row, "BackgroundColor3", "card")
	corner(row, UDim.new(0, 9))

	local rowStroke = addStroke(row, win.theme.stroke, 1.6, 0.4)
	bind(win, rowStroke, "Color", "stroke")

	local leftPad = PAD
	if icon then
		-- Framed icon container with border
		local iconBox = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, PAD, 0, topH / 2),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Parent = row,
		})
		bind(win, iconBox, "BackgroundColor3", "panel")
		corner(iconBox, UDim.new(0, 7))

		local iconBoxStroke = addStroke(iconBox, win.theme.stroke, 1.4, 0.35)
		bind(win, iconBoxStroke, "Color", "stroke")

		local img = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			Parent = iconBox,
		})
		bind(win, img, "ImageColor3", "accent")
		leftPad = PAD + 28 + 12
	end

	local textContainer = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, leftPad, 0, topH / 2),
		Size = UDim2.new(1, -(leftPad + rightPad), 0, 34),
		Parent = row,
	})
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = textContainer,
	})

	local nameLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = name,
		Weight = "SemiBold",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = textContainer,
	})
	bind(win, nameLabel, "TextColor3", "text")

	local descLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = desc and tostring(desc) or "",
		Weight = "Medium",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 14),
		Visible = desc ~= nil and desc ~= "",
		LayoutOrder = 2,
		Parent = textContainer,
	})
	bind(win, descLabel, "TextColor3", "subtext")

	local overlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 8,
		Parent = row,
	})
	bind(win, overlay, "BackgroundColor3", "bg")
	corner(overlay, UDim.new(0, 9))

	local refs = {
		name = nameLabel,
		desc = descLabel,
		overlay = overlay,
		stroke = rowStroke,
		origDesc = descLabel.Text,
	}

	function refs.update()
		descLabel.Visible = descLabel.Text ~= ""
	end

	return row, refs
end

local function hoverRow(win, row, hit, handle, onEnter, onLeave)
	hit.MouseEnter:Connect(function()
		if handle and handle.locked then
			return
		end
		tween(row, 0.2, { BackgroundColor3 = win.theme.cardHover })
		if onEnter then
			onEnter()
		end
	end)
	hit.MouseLeave:Connect(function()
		tween(row, 0.25, { BackgroundColor3 = win.theme.card })
		if onLeave then
			onLeave()
		end
	end)
end

local function decorate(target, handle, row, refs)
	handle._card = row
	handle.locked = false
	table.insert(target._items, handle)
	row.LayoutOrder = #target._items

	local function reorder()
		for i, h in ipairs(target._items) do
			h._card.LayoutOrder = i
		end
	end

	local function indexOf(self)
		for i, h in ipairs(target._items) do
			if h == self then
				return i
			end
		end
		return 1
	end

	function handle:MoveTo(index)
		table.remove(target._items, indexOf(self))
		index = clamp(math.floor(index), 1, #target._items + 1)
		table.insert(target._items, index, self)
		reorder()
	end
	function handle:MoveToTop()
		self:MoveTo(1)
	end
	function handle:MoveToBottom()
		self:MoveTo(#target._items)
	end
	function handle:MoveUp()
		self:MoveTo(indexOf(self) - 1)
	end
	function handle:MoveDown()
		self:MoveTo(indexOf(self) + 1)
	end
	function handle:Remove()
		table.remove(target._items, indexOf(self))
		row:Destroy()
		reorder()
	end

	if refs then
		function handle:IsLocked()
			return self.locked
		end
		function handle:Lock(reason)
			self.locked = true
			refs.overlay.Visible = true
			if reason then
				refs.desc.Text = tostring(reason)
				refs.update()
			end
			if self._onLock then
				self._onLock()
			end
		end
		function handle:Unlock()
			self.locked = false
			refs.overlay.Visible = false
			refs.desc.Text = refs.origDesc
			refs.update()
		end
	end
end

local function registerFlag(win, handle, props)
	local key = pick(props, "flag") or tostring(pick(props, "name", "element"))
	handle.flagKey = key
	handle.forgetState = pick(props, "forgetState", false)
	win._flags[key] = handle
	if not handle.forgetState and win._saved and win._saved[key] ~= nil then
		local saved = win._saved[key]
		task.defer(function()
			win._loading = true
			handle:Set(saved)
			win._loading = false
		end)
	end
end

local function pillFrame(win, parent)
	local pill = create("Frame", {
		BorderSizePixel = 0,
		Parent = parent,
	})
	bind(win, pill, "BackgroundColor3", "panel")
	corner(pill, UDim.new(0, 7))
	local stroke = addStroke(pill, win.theme.stroke, 1.6, 0.45)
	bind(win, stroke, "Color", "stroke")
	return pill, stroke
end

------------------------------------------------------------------------
-- Component Constructors
------------------------------------------------------------------------

local addMethods

addMethods = function(target, win, holder, rowMode)
	target._holder = holder
	target._rowMode = rowMode
	target._items = {}

	local function place(row, basis)
		if target._rowMode then
			row.Size = UDim2.new(0, basis or 180, 0, row.Size.Y.Offset)
			create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = row })
		end
		row.Parent = target._holder
	end

	------------------------------------------------------------ Button
	function target:CreateButton(props)
		props = props or {}
		local row, refs = buildRow(win, props, ROW_H, 100)
		local handle = {}

		local pill = pillFrame(win, row)
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -PAD, 0, ROW_H / 2)
		pill.Size = UDim2.fromOffset(76, 28)

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tostring(pick(props, "buttonText", "Run")),
			Weight = "SemiBold",
			TextSize = 12,
			Size = UDim2.fromScale(1, 1),
			Parent = pill,
		})
		bind(win, label, "TextColor3", "text")

		local hit = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = row,
		})

		hoverRow(win, row, hit, handle, function()
			tween(pill, 0.18, { BackgroundColor3 = win.theme.accent })
			tween(label, 0.18, { TextColor3 = Color3.fromRGB(255, 255, 255) })
		end, function()
			tween(pill, 0.22, { BackgroundColor3 = win.theme.panel })
			tween(label, 0.22, { TextColor3 = win.theme.text })
		end)

		hit.MouseButton1Down:Connect(function()
			if not handle.locked then
				tween(pill, 0.08, { Size = UDim2.fromOffset(72, 26) })
			end
		end)
		hit.MouseButton1Up:Connect(function()
			tween(pill, 0.2, { Size = UDim2.fromOffset(76, 28) }, Enum.EasingStyle.Back)
		end)
		hit.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			fire(pick(props, "callback"))
		end)

		place(row)
		decorate(target, handle, row, refs)
		return handle
	end

	------------------------------------------------------------ Toggle / Switch
	function target:CreateToggle(props)
		props = props or {}
		local row, refs = buildRow(win, props, ROW_H, 70)
		local handle = { value = pick(props, "value", false) and true or false }
		local cb = pick(props, "callback")

		local track = create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -PAD, 0, ROW_H / 2),
			Size = UDim2.fromOffset(40, 22),
			BorderSizePixel = 0,
			Parent = row,
		})
		corner(track, UDim.new(1, 0))

		local trackStroke = addStroke(track, win.theme.stroke, 1.6, 0.5)

		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Parent = track,
		})
		corner(knob, UDim.new(1, 0))

		local function visual(animate)
			local t = animate and 0.22 or 0
			local active = handle.value
			tween(track, t, {
				BackgroundColor3 = active and win.theme.accent or win.theme.panel,
			}, Enum.EasingStyle.Quart)
			tween(trackStroke, t, {
				Color = active and win.theme.accent or win.theme.stroke,
				Transparency = active and 0.15 or 0.5,
			})
			tween(knob, t, {
				Position = active and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			}, Enum.EasingStyle.Back)
		end

		visual(false)
		table.insert(win._refreshers, function()
			visual(true)
		end)

		function handle:Set(v, skip)
			self.value = v and true or false
			visual(true)
			win:_changed()
			if not skip then
				fire(cb, self.value)
			end
		end

		local hit = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = row,
		})
		hoverRow(win, row, hit, handle)
		hit.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			handle:Set(not handle.value)
		end)

		place(row)
		decorate(target, handle, row, refs)
		registerFlag(win, handle, props)
		return handle
	end
	target.CreateSwitch = target.CreateToggle

	------------------------------------------------------------ Slider
	function target:CreateSlider(props)
		props = props or {}
		local row, refs = buildRow(win, props, 72, 90, 42)
		local range = pick(props, "range", { 0, 100 })
		local minV, maxV = range[1] or 0, range[2] or 100
		local inc = pick(props, "increment", 1)
		if inc <= 0 then
			inc = 1
		end
		local suffix = tostring(pick(props, "suffix", ""))
		local cb = pick(props, "callback")
		local handle = { value = minV }

		local pill = pillFrame(win, row)
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -PAD, 0, 22)
		pill.Size = UDim2.new(0, 0, 0, 24)
		pill.AutomaticSize = Enum.AutomaticSize.X
		create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = pill })

		local valueLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Weight = "Bold",
			TextSize = 12,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = pill,
		})
		bind(win, valueLabel, "TextColor3", "text")

		local track = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, PAD, 0, 54),
			Size = UDim2.new(1, -(2 * PAD), 0, 6),
			BorderSizePixel = 0,
			Parent = row,
		})
		bind(win, track, "BackgroundColor3", "panel")
		corner(track, UDim.new(1, 0))

		local fill = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Parent = track,
		})
		corner(fill, UDim.new(1, 0))
		bindGradient(win, create("UIGradient", { Parent = fill }), "accent")

		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = track,
		})
		corner(knob, UDim.new(1, 0))
		local knobStroke = addStroke(knob, win.theme.accent, 2.5, 0)
		bind(win, knobStroke, "Color", "accent")

		local function snap(v)
			v = clamp(v, minV, maxV)
			local steps = math.floor((v - minV) / inc + 0.5)
			local s = minV + steps * inc
			if s > maxV then
				s = maxV
			end
			return round(s)
		end

		local function show(v, t)
			valueLabel.Text = tostring(v) .. suffix
			local r = (maxV == minV) and 0 or (v - minV) / (maxV - minV)
			tween(fill, t, { Size = UDim2.fromScale(r, 1) })
			tween(knob, t, { Position = UDim2.new(r, 0, 0.5, 0) })
		end

		handle.value = snap(tonumber(pick(props, "value", minV)) or minV)
		show(handle.value, 0)

		function handle:Set(v, skip)
			self.value = snap(tonumber(v) or minV)
			show(self.value, 0.15)
			win:_changed()
			if not skip then
				fire(cb, self.value, false)
			end
		end

		local dragging = false
		local function grow(big)
			local s = big and 18 or 14
			tween(knob, 0.15, { Size = UDim2.fromOffset(s, s) }, Enum.EasingStyle.Back)
		end

		local function fromX(x)
			local ratio = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local v = snap(minV + ratio * (maxV - minV))
			if v ~= handle.value then
				handle.value = v
				show(v, 0.05)
				win:_changed()
				fire(cb, v, true)
			end
		end

		local hit = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Position = UDim2.new(0, PAD, 0, 38),
			Size = UDim2.new(1, -2 * PAD, 0, 32),
			ZIndex = 4,
			Parent = row,
		})

		hit.MouseEnter:Connect(function()
			if not handle.locked then
				grow(true)
			end
		end)
		hit.MouseLeave:Connect(function()
			if not dragging then
				grow(false)
			end
		end)
		hit.InputBegan:Connect(function(input)
			if handle.locked then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				grow(true)
				fromX(input.Position.X)
				local moveConn, endConn
				moveConn = UserInputService.InputChanged:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
						fromX(i.Position.X)
					end
				end)
				endConn = UserInputService.InputEnded:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
						moveConn:Disconnect()
						endConn:Disconnect()
						dragging = false
						grow(false)
						fire(cb, handle.value, false)
					end
				end)
			end
		end)

		place(row, 220)
		decorate(target, handle, row, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Dropdown
	function target:CreateDropdown(props)
		props = props or {}
		local multi = pick(props, "multiSelect", false)
		local cb = pick(props, "callback")
		local placeholder = tostring(pick(props, "placeholder", "None"))
		local row, refs = buildRow(win, props, ROW_H, 180)

		local options = {}
		for _, o in ipairs(pick(props, "options", {})) do
			table.insert(options, tostring(o))
		end
		local handle = { value = {}, options = options }
		local open = false
		local search = ""
		local rows = {}

		local pill = pillFrame(win, row)
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -PAD, 0, ROW_H / 2)
		pill.Size = UDim2.fromOffset(160, 28)

		local summary = create("TextLabel", {
			BackgroundTransparency = 1,
			Weight = "Medium",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -30, 1, 0),
			Parent = pill,
		})
		bind(win, summary, "TextColor3", "text")

		local chevron = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = "▼",
			Weight = "Bold",
			TextSize = 9,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -9, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Parent = pill,
		})
		bind(win, chevron, "TextColor3", "subtext")

		local panel = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, PAD, 0, ROW_H),
			Size = UDim2.new(1, -2 * PAD, 0, 0),
			Visible = false,
			Parent = row,
		})

		local searchBox = create("TextBox", {
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
			PlaceholderText = "Search options...",
			ClearTextOnFocus = false,
			Weight = "Medium",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			Parent = panel,
		})
		bind(win, searchBox, "BackgroundColor3", "panel")
		bind(win, searchBox, "TextColor3", "text")
		bind(win, searchBox, "PlaceholderColor3", "subtext")
		corner(searchBox, UDim.new(0, 6))
		addStroke(searchBox, win.theme.stroke, 1.6, 0.45)
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = searchBox })

		local list = create("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 34),
			Size = UDim2.new(1, 0, 0, 0),
			ScrollBarThickness = 2,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = panel,
		})
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

		local function isSelected(opt)
			for _, v in ipairs(handle.value) do
				if v == opt then
					return true
				end
			end
			return false
		end

		local function copy(t)
			local out = {}
			for i, v in ipairs(t) do
				out[i] = v
			end
			return out
		end

		local function refreshSummary()
			if #handle.value == 0 then
				summary.Text = placeholder
				summary.TextTransparency = 0.45
			else
				summary.Text = table.concat(handle.value, ", ")
				summary.TextTransparency = 0
			end
		end

		local function resize(visibleCount)
			local listH = math.min(visibleCount * 32, 140)
			list.Size = UDim2.new(1, 0, 0, listH)
			panel.Size = UDim2.new(1, -2 * PAD, 0, 36 + listH)
			local h = open and (ROW_H + 36 + listH + 10) or ROW_H
			tween(row, 0.22, { Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, h) })
		end

		local commit

		local function rebuild()
			for _, r in ipairs(rows) do
				r:Destroy()
			end
			rows = {}
			local q = search:lower()
			local count = 0
			for _, opt in ipairs(handle.options) do
				if q == "" or opt:lower():find(q, 1, true) then
					count = count + 1
					local selected = isSelected(opt)
					local btn = create("TextButton", {
						Size = UDim2.new(1, -4, 0, 28),
						AutoButtonColor = false,
						Text = opt,
						Weight = selected and "Bold" or "Medium",
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						BorderSizePixel = 0,
						BackgroundColor3 = selected and win.theme.accent or win.theme.panel,
						BackgroundTransparency = selected and 0.85 or 0.6,
						TextColor3 = selected and win.theme.accent or win.theme.text,
						LayoutOrder = count,
						Parent = list,
					})
					corner(btn, UDim.new(0, 6))
					create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })

					local check = create("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(6, 6),
						BackgroundColor3 = win.theme.accent,
						BorderSizePixel = 0,
						Visible = selected,
						Parent = btn,
					})
					corner(check, UDim.new(1, 0))

					btn.MouseEnter:Connect(function()
						if not selected then
							tween(btn, 0.12, { BackgroundTransparency = 0.3, TextColor3 = win.theme.text })
						end
					end)
					btn.MouseLeave:Connect(function()
						if not selected then
							tween(btn, 0.15, { BackgroundTransparency = 0.6, TextColor3 = win.theme.subtext })
						end
					end)

					btn.MouseButton1Click:Connect(function()
						if handle.locked then
							return
						end
						if multi then
							local new = copy(handle.value)
							local found = false
							for i, v in ipairs(new) do
								if v == opt then
									table.remove(new, i)
									found = true
									break
								end
							end
							if not found then
								table.insert(new, opt)
							end
							commit(new, false)
						else
							commit({ opt }, false)
							open = false
							panel.Visible = false
							tween(chevron, 0.2, { Rotation = 0 })
							resize(0)
						end
					end)
					table.insert(rows, btn)
				end
			end
			resize(count)
		end

		commit = function(newValue, skip)
			handle.value = newValue
			refreshSummary()
			rebuild()
			win:_changed()
			if not skip then
				if multi then
					fire(cb, copy(newValue))
				else
					fire(cb, newValue[1])
				end
			end
		end

		local function normalize(v)
			local wanted = {}
			if type(v) == "string" then
				wanted = { v }
			elseif type(v) == "table" then
				wanted = v
			end
			local out = {}
			for _, w in ipairs(wanted) do
				for _, o in ipairs(handle.options) do
					if o == tostring(w) then
						table.insert(out, o)
						break
					end
				end
			end
			if not multi and #out > 1 then
				out = { out[1] }
			end
			return out
		end

		function handle:Set(v, skip)
			commit(normalize(v), skip)
		end

		function handle:Refresh(newOptions)
			local opts = {}
			for _, o in ipairs(newOptions or {}) do
				table.insert(opts, tostring(o))
			end
			self.options = opts
			local before = #self.value
			self.value = normalize(self.value)
			local changed = #self.value ~= before
			refreshSummary()
			rebuild()
			if changed then
				win:_changed()
				fire(cb, multi and copy(self.value) or self.value[1])
			end
		end

		function handle:Add(option)
			option = tostring(option)
			for _, o in ipairs(self.options) do
				if o == option then
					return
				end
			end
			table.insert(self.options, option)
			rebuild()
		end

		function handle:Remove(option)
			option = tostring(option)
			for i, o in ipairs(self.options) do
				if o == option then
					table.remove(self.options, i)
					break
				end
			end
			if isSelected(option) then
				local new = {}
				for _, v in ipairs(self.value) do
					if v ~= option then
						table.insert(new, v)
					end
				end
				commit(new, false)
			else
				rebuild()
			end
		end

		handle._onLock = function()
			open = false
			panel.Visible = false
			tween(chevron, 0.2, { Rotation = 0 })
			resize(0)
		end

		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			search = searchBox.Text
			rebuild()
		end)

		local header = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, ROW_H),
			ZIndex = 2,
			Parent = row,
		})
		hoverRow(win, row, header, handle)
		header.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			open = not open
			panel.Visible = open
			tween(chevron, 0.2, { Rotation = open and 180 or 0 })
			rebuild()
		end)

		handle.value = normalize(pick(props, "value", {}))
		refreshSummary()
		rebuild()
		table.insert(win._refreshers, function()
			rebuild()
		end)

		place(row, 240)
		decorate(target, handle, row, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Input
	function target:CreateInput(props)
		props = props or {}
		local row, refs = buildRow(win, props, ROW_H, 180)
		local numeric = pick(props, "numeric", false)
		local cb = pick(props, "callback")
		local handle = { value = tostring(pick(props, "value", "")) }

		local box = create("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -PAD, 0, ROW_H / 2),
			Size = UDim2.fromOffset(160, 28),
			Text = handle.value,
			PlaceholderText = tostring(pick(props, "placeholder", "Type here...")),
			ClearTextOnFocus = false,
			Weight = "Medium",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			Parent = row,
		})
		bind(win, box, "BackgroundColor3", "panel")
		bind(win, box, "TextColor3", "text")
		bind(win, box, "PlaceholderColor3", "subtext")
		corner(box, UDim.new(0, 6))
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })
		local boxStroke = addStroke(box, win.theme.stroke, 1.6, 0.4)
		bind(win, boxStroke, "Color", "stroke")

		function handle:Set(v, skip)
			self.value = tostring(v)
			box.Text = self.value
			win:_changed()
			if not skip then
				fire(cb, self.value)
			end
		end

		box.Focused:Connect(function()
			if handle.locked then
				box:ReleaseFocus()
				return
			end
			tween(boxStroke, 0.2, { Color = win.theme.accent, Transparency = 0.1 })
			if pick(props, "clearOnFocus", false) then
				box.Text = ""
			end
		end)

		box.FocusLost:Connect(function()
			tween(boxStroke, 0.2, { Color = win.theme.stroke, Transparency = 0.4 })
			if handle.locked then
				box.Text = handle.value
				return
			end
			local text = box.Text
			if numeric then
				local n = tonumber(text)
				if n == nil then
					box.Text = handle.value
					return
				end
				text = tostring(n)
			end
			handle:Set(text)
		end)

		place(row, 240)
		decorate(target, handle, row, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Text / Label
	function target:CreateText(props)
		props = props or {}
		local row = create("Frame", {
			Name = "Text",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, PAD),
			PaddingRight = UDim.new(0, PAD),
			Parent = row,
		})
		create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })

		local titleLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Weight = "Bold",
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = row,
		})
		bind(win, titleLabel, "TextColor3", "text")

		local bodyLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Weight = "Medium",
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = row,
		})
		bind(win, bodyLabel, "TextColor3", "subtext")

		local handle = {}
		function handle:SetTitle(t)
			titleLabel.Text = tostring(t or "")
			titleLabel.Visible = titleLabel.Text ~= ""
		end
		function handle:SetBody(t)
			bodyLabel.Text = tostring(t or "")
			bodyLabel.Visible = bodyLabel.Text ~= ""
		end
		handle:SetTitle(pick(props, "title", pick(props, "name", "")))
		handle:SetBody(pick(props, "body", pick(props, "text", pick(props, "description", ""))))

		place(row, 220)
		decorate(target, handle, row, nil)
		return handle
	end
	target.CreateLabel = target.CreateText

	------------------------------------------------------------ Divider
	function target:CreateDivider(props)
		props = props or {}
		local text = pick(props, "name", pick(props, "text"))
		local h = pick(props, "height", 18)
		local frame = create("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
		})

		local line = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -2 * PAD, 0, 2),
			BorderSizePixel = 0,
			Parent = frame,
		})
		bind(win, line, "BackgroundColor3", "stroke")

		if text and text ~= "" then
			local pill = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 0, 0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				BorderSizePixel = 0,
				Parent = frame,
			})
			bind(win, pill, "BackgroundColor3", "bg")
			corner(pill, UDim.new(0, 4))
			create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = pill })

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(text):upper(),
				Weight = "Bold",
				TextSize = 10,
				Parent = pill,
			})
			bind(win, label, "TextColor3", "subtext")
		end

		local handle = {}
		place(frame, 220)
		decorate(target, handle, frame, nil)
		return handle
	end

	------------------------------------------------------------ Section
	function target:CreateSection(props)
		props = props or {}
		local frame = create("Frame", {
			Name = "Section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
		})
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, PAD, 1, -4),
			Size = UDim2.new(1, -(2 * PAD), 0, 18),
			Text = tostring(pick(props, "name", "")),
			Weight = "Bold",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		bind(win, label, "TextColor3", "accent")

		local handle = {}
		function handle:SetName(t)
			label.Text = tostring(t)
		end

		place(frame, 220)
		decorate(target, handle, frame, nil)
		return handle
	end

	------------------------------------------------------------ Group
	function target:CreateGroup(props)
		props = props or {}
		local dir = tostring(pick(props, "direction", "row")):lower()
		local row = (dir == "row" or dir == "horizontal")
		local frame = create("Frame", {
			Name = "Group",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		local layout = create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
		if row then
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Wraps = true
			layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		end
		local group = {}
		addMethods(group, win, frame, row)
		place(frame, 220)
		decorate(target, group, frame, nil)
		return group
	end
end

------------------------------------------------------------------------
-- Window Class
------------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:_changed()
	if self._loading then
		return
	end
	local cfg = self._cfg
	if cfg and cfg.autoSave and fsAvailable() then
		self._saveToken = (self._saveToken or 0) + 1
		local token = self._saveToken
		task.delay(0.6, function()
			if token == self._saveToken and not self.unloaded then
				self:Save()
			end
		end)
	end
end

function Window:_conn(c)
	table.insert(self._conns, c)
	return c
end

function Window:_syncIndicator(instant)
	local tab = self._activeTab
	local ind, area = self._indicator, self._indicatorArea
	if not tab or not ind or not area then
		return
	end
	local btn = tab.button
	task.spawn(function()
		if not instant or btn.AbsoluteSize.X == 0 then
			task.wait()
		end
		if self.unloaded or not btn.Parent then
			return
		end
		local pos = UDim2.fromOffset(
			btn.AbsolutePosition.X - area.AbsolutePosition.X,
			btn.AbsolutePosition.Y - area.AbsolutePosition.Y
		)
		local size = UDim2.fromOffset(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
		if instant or not ind.Visible then
			ind.Position = pos
			ind.Size = size
			ind.Visible = true
		else
			tween(ind, 0.3, { Position = pos, Size = size }, Enum.EasingStyle.Quart)
		end
	end)
end

function Window:Get(flag)
	local h = self._flags[flag]
	if h then
		return h.value
	end
	return nil
end

function Window:Set(flag, value)
	local h = self._flags[flag]
	if not h then
		return false
	end
	h:Set(value)
	return true
end

function Window:GetPath(name)
	local cfg = self._cfg or {}
	local folder = cfg.customFolder or "Lumen"
	local file = tostring(name or cfg.fileName or self._name)
	file = (file:gsub("[^%w%-_ ]", ""))
	if file == "" then
		file = "config"
	end
	return folder, folder .. "/" .. file .. ".json"
end

function Window:Save(name)
	if not self._cfg or not fsAvailable() then
		return false
	end
	local folder, path = self:GetPath(name)
	local data = {}
	for key, h in pairs(self._flags) do
		if not h.forgetState then
			data[key] = h.value
		end
	end
	local ok = pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
			makefolder(folder)
		end
		writefile(path, HttpService:JSONEncode(data))
	end)
	return ok
end

function Window:Load(name)
	if not fsAvailable() then
		return false
	end
	local _, path = self:GetPath(name)
	local okRead, raw = pcall(function()
		if isfile(path) then
			return readfile(path)
		end
		return nil
	end)
	if not okRead or not raw then
		return false
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(data) ~= "table" then
		return false
	end
	self._loading = true
	for key, value in pairs(data) do
		local h = self._flags[key]
		if h and not h.forgetState then
			h:Set(value)
		end
	end
	self._loading = false
	return true
end

function Window:ListConfigs()
	local out = {}
	if type(listfiles) ~= "function" or type(isfolder) ~= "function" then
		return out
	end
	local folder = self:GetPath()
	if not isfolder(folder) then
		return out
	end
	for _, p in ipairs(listfiles(folder)) do
		local n = tostring(p):match("([^/\\]+)%.json$")
		if n then
			table.insert(out, n)
		end
	end
	return out
end

function Window:DeleteConfig(name)
	if type(delfile) ~= "function" then
		return false
	end
	local _, path = self:GetPath(name)
	return pcall(function()
		if isfile(path) then
			delfile(path)
		end
	end)
end

function Window:ChangeTheme(theme)
	self.theme = resolveTheme(theme)
	for i = #self._bindings, 1, -1 do
		local b = self._bindings[i]
		if b.inst:IsDescendantOf(self._gui) then
			tween(b.inst, 0.3, { [b.prop] = self.theme[b.key] })
		else
			table.remove(self._bindings, i)
		end
	end
	for _, fn in ipairs(self._refreshers) do
		pcall(fn)
	end
end

function Window:Show()
	self._hideToken = (self._hideToken or 0) + 1
	self._hidden = false
	self._pill.Visible = false
	self._main.Visible = true
	self._scale.Scale = 0.94
	self._main.GroupTransparency = 1
	tween(self._scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Quart)
	tween(self._main, 0.25, { GroupTransparency = 0 })
	self:_syncIndicator(true)
end

function Window:Hide()
	self._hideToken = (self._hideToken or 0) + 1
	local token = self._hideToken
	self._hidden = true
	tween(self._scale, 0.22, { Scale = 0.94 }, Enum.EasingStyle.Quart)
	tween(self._main, 0.2, { GroupTransparency = 1 })
	task.delay(0.22, function()
		if token == self._hideToken and not self.unloaded then
			self._main.Visible = false
			self._pill.Visible = true
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
		self._body.Visible = true
		tween(self._main, 0.35, { Size = self._fullSize }, Enum.EasingStyle.Quart)
	else
		self._minimised = true
		self._fullSize = self._main.Size
		self._body.Visible = false
		tween(self._main, 0.35, { Size = UDim2.new(self._fullSize.X.Scale, self._fullSize.X.Offset, 0, 52) }, Enum.EasingStyle.Quart)
	end
end

function Window:Navigate(tab)
	if type(tab) == "string" then
		for _, t in ipairs(self._tabs) do
			if t.name == tab then
				t:Select()
				return
			end
		end
	elseif type(tab) == "table" and tab.Select then
		tab:Select()
	end
end

function Window:Unload()
	if self.unloaded then
		return
	end
	self.unloaded = true
	for _, c in ipairs(self._conns) do
		pcall(function
