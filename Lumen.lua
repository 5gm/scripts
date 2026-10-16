--[[
    Lumen UI Library
    An original Roblox UI library with an API shaped like Rayfield Gen2's public docs:
    CreateWindow -> CreateTab -> Create<Element>, flags, configuration saving, themes.

    Load it as a ModuleScript (require) or host it and loadstring it:
        local Lumen = loadstring(game:HttpGet("YOUR_URL"))()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local Lumen = { Version = "0.1.0" }

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

------------------------------------------------------------------------
-- Themes
------------------------------------------------------------------------

local DefaultTheme = {
	bg = Color3.fromRGB(13, 14, 21),
	panel = Color3.fromRGB(20, 22, 33),
	card = Color3.fromRGB(28, 31, 46),
	stroke = Color3.fromRGB(50, 55, 80),
	text = Color3.fromRGB(236, 238, 248),
	subtext = Color3.fromRGB(139, 146, 173),
	accent = Color3.fromRGB(124, 92, 255),
	accent2 = Color3.fromRGB(0, 214, 201),
}

local ThemeOverrides = {
	default = {},
	cobalt = { accent = Color3.fromRGB(59, 130, 246), accent2 = Color3.fromRGB(56, 189, 248) },
	ember = { accent = Color3.fromRGB(249, 115, 22), accent2 = Color3.fromRGB(250, 204, 21) },
	amethyst = { accent = Color3.fromRGB(168, 85, 247), accent2 = Color3.fromRGB(236, 72, 153) },
	frost = {
		bg = Color3.fromRGB(12, 20, 28),
		panel = Color3.fromRGB(18, 29, 40),
		card = Color3.fromRGB(26, 41, 56),
		stroke = Color3.fromRGB(45, 68, 90),
		accent = Color3.fromRGB(125, 211, 252),
		accent2 = Color3.fromRGB(186, 230, 253),
	},
	rose = { accent = Color3.fromRGB(244, 63, 94), accent2 = Color3.fromRGB(251, 146, 60) },
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
-- Helpers
------------------------------------------------------------------------

-- Accepts camelCase or PascalCase property names.
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

local function create(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
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

local function tween(inst, duration, goal)
	local t = TweenService:Create(inst, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
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
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	if tonumber(icon) then
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
			warn("[Lumen] callback error: " .. tostring(err))
		end
	end)
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 10), Parent = parent })
end

local function getGuiParent(gui)
	local ok, ui = pcall(function()
		if type(gethui) == "function" then
			return gethui()
		end
		return nil
	end)
	if ok and ui then
		gui.Parent = ui
		return
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
-- Theme binding
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
			grad.Color = ColorSequence.new(t.bg, t.bg:Lerp(t.accent, 0.1))
		end
	end
	apply()
	table.insert(win._refreshers, apply)
end

------------------------------------------------------------------------
-- Element cards
------------------------------------------------------------------------

local function buildCard(win, props, height, rightPad, topH)
	topH = topH or height
	local name = tostring(pick(props, "name", ""))
	local desc = pick(props, "description")
	local icon = assetId(pick(props, "icon"))

	local card = create("Frame", {
		Name = name ~= "" and name or "Element",
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	bind(win, card, "BackgroundColor3", "card")
	corner(card, UDim.new(0, 10))
	local stroke = create("UIStroke", {
		Thickness = 1,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})
	bind(win, stroke, "Color", "stroke")

	local edge = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, topH / 2),
		Size = UDim2.fromOffset(3, 18),
		BorderSizePixel = 0,
		Parent = card,
	})
	bind(win, edge, "BackgroundColor3", "accent")
	corner(edge, UDim.new(1, 0))

	local leftPad = 16
	if icon then
		local img = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0, topH / 2),
			Size = UDim2.fromOffset(18, 18),
			Parent = card,
		})
		bind(win, img, "ImageColor3", "accent2")
		leftPad = 40
	end

	local nameLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = name,
		Font = FONT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(leftPad + rightPad), 0, 18),
		Parent = card,
	})
	bind(win, nameLabel, "TextColor3", "text")

	local descLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = desc and tostring(desc) or "",
		Font = FONT_REG,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(leftPad + rightPad), 0, 14),
		Parent = card,
	})
	bind(win, descLabel, "TextColor3", "subtext")

	local overlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 10,
		Parent = card,
	})
	bind(win, overlay, "BackgroundColor3", "bg")
	corner(overlay, UDim.new(0, 10))

	local refs = { name = nameLabel, desc = descLabel, overlay = overlay, origDesc = descLabel.Text }
	function refs.update()
		if descLabel.Text ~= "" then
			nameLabel.AnchorPoint = Vector2.new(0, 0)
			nameLabel.Position = UDim2.new(0, leftPad, 0, topH / 2 - 17)
			descLabel.Visible = true
			descLabel.Position = UDim2.new(0, leftPad, 0, topH / 2 + 1)
		else
			nameLabel.AnchorPoint = Vector2.new(0, 0.5)
			nameLabel.Position = UDim2.new(0, leftPad, 0, topH / 2)
			descLabel.Visible = false
		end
	end
	refs.update()
	return card, refs
end

-- Adds reorder / lock / remove methods and registers the handle with its container.
local function decorate(target, handle, card, refs)
	handle._card = card
	handle.locked = false
	table.insert(target._items, handle)
	card.LayoutOrder = #target._items

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
		card:Destroy()
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

-- Value elements: flags + saved state.
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

------------------------------------------------------------------------
-- Containers (tabs and groups share these methods)
------------------------------------------------------------------------

local addMethods

addMethods = function(target, win, holder, rowMode)
	target._holder = holder
	target._rowMode = rowMode
	target._items = {}

	local function place(card, basis)
		if target._rowMode then
			card.Size = UDim2.new(0, basis or 170, 0, card.Size.Y.Offset)
			create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = card })
		end
		card.Parent = target._holder
	end

	------------------------------------------------------------ Button
	function target:CreateButton(props)
		props = props or {}
		local card, refs = buildCard(win, props, 46, 40)
		local handle = {}
		local arrow = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = "›",
			Font = FONT_BOLD,
			TextSize = 24,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, -2),
			Size = UDim2.fromOffset(20, 26),
			Parent = card,
		})
		bind(win, arrow, "TextColor3", "accent2")
		local hit = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = card,
		})
		hit.MouseEnter:Connect(function()
			if not handle.locked then
				tween(card, 0.15, { BackgroundColor3 = win.theme.card:Lerp(win.theme.accent, 0.16) })
			end
		end)
		hit.MouseLeave:Connect(function()
			tween(card, 0.15, { BackgroundColor3 = win.theme.card })
		end)
		hit.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			tween(card, 0.08, { BackgroundColor3 = win.theme.card:Lerp(win.theme.accent, 0.32) })
			task.delay(0.1, function()
				if card.Parent then
					tween(card, 0.2, { BackgroundColor3 = win.theme.card })
				end
			end)
			fire(pick(props, "callback"))
		end)
		place(card)
		decorate(target, handle, card, refs)
		return handle
	end

	------------------------------------------------------------ Toggle
	function target:CreateToggle(props)
		props = props or {}
		local card, refs = buildCard(win, props, 46, 70)
		local handle = { value = pick(props, "value", false) and true or false }
		local cb = pick(props, "callback")

		local track = create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(42, 22),
			BorderSizePixel = 0,
			Parent = card,
		})
		corner(track, UDim.new(1, 0))
		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = track,
		})
		corner(knob, UDim.new(1, 0))

		local function visual(animate)
			local t = animate and 0.18 or 0
			tween(track, t, { BackgroundColor3 = handle.value and win.theme.accent or win.theme.stroke })
			tween(knob, t, { Position = handle.value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
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
			ZIndex = 2,
			Parent = card,
		})
		hit.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			handle:Set(not handle.value)
		end)

		place(card)
		decorate(target, handle, card, refs)
		registerFlag(win, handle, props)
		return handle
	end
	target.CreateSwitch = target.CreateToggle

	------------------------------------------------------------ Slider
	function target:CreateSlider(props)
		props = props or {}
		local card, refs = buildCard(win, props, 68, 90, 44)
		local range = pick(props, "range", { 0, 100 })
		local minV, maxV = range[1] or 0, range[2] or 100
		local inc = pick(props, "increment", 1)
		if inc <= 0 then
			inc = 1
		end
		local suffix = tostring(pick(props, "suffix", ""))
		local cb = pick(props, "callback")
		local handle = { value = minV }

		local valueLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0, 22),
			Size = UDim2.fromOffset(80, 18),
			Parent = card,
		})
		bind(win, valueLabel, "TextColor3", "accent2")

		local track = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0, 56),
			Size = UDim2.new(1, -32, 0, 6),
			BorderSizePixel = 0,
			Parent = card,
		})
		bind(win, track, "BackgroundColor3", "stroke")
		corner(track, UDim.new(1, 0))
		local fill = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = track,
		})
		corner(fill, UDim.new(1, 0))
		bindGradient(win, create("UIGradient", { Parent = fill }), "accent")
		local knob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = track,
		})
		corner(knob, UDim.new(1, 0))

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
			show(self.value, 0.12)
			win:_changed()
			if not skip then
				fire(cb, self.value, false)
			end
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
			Position = UDim2.new(0, 10, 0, 42),
			Size = UDim2.new(1, -20, 0, 28),
			Parent = card,
		})
		hit.InputBegan:Connect(function(input)
			if handle.locked then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
						fire(cb, handle.value, false)
					end
				end)
			end
		end)

		place(card, 220)
		decorate(target, handle, card, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Dropdown
	function target:CreateDropdown(props)
		props = props or {}
		local multi = pick(props, "multiSelect", false)
		local cb = pick(props, "callback")
		local placeholder = tostring(pick(props, "placeholder", "None"))
		local card, refs = buildCard(win, props, 46, 190)

		local options = {}
		for _, o in ipairs(pick(props, "options", {})) do
			table.insert(options, tostring(o))
		end
		local handle = { value = {}, options = options }
		local open = false
		local search = ""
		local rows = {}

		local summary = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_REG,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -32, 0, 23),
			Size = UDim2.fromOffset(150, 18),
			Parent = card,
		})
		bind(win, summary, "TextColor3", "accent2")
		local chevron = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = "▾",
			Font = FONT_BOLD,
			TextSize = 14,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0, 23),
			Size = UDim2.fromOffset(16, 16),
			Parent = card,
		})
		bind(win, chevron, "TextColor3", "subtext")

		local panel = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 50),
			Size = UDim2.new(1, -20, 0, 0),
			Visible = false,
			Parent = card,
		})
		local box = create("TextBox", {
			Size = UDim2.new(1, 0, 0, 26),
			Text = "",
			PlaceholderText = "Search...",
			ClearTextOnFocus = false,
			Font = FONT_REG,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			Parent = panel,
		})
		bind(win, box, "BackgroundColor3", "panel")
		bind(win, box, "TextColor3", "text")
		bind(win, box, "PlaceholderColor3", "subtext")
		corner(box, UDim.new(0, 7))
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = box })

		local list = create("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 0),
			ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = panel,
		})
		create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

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
			else
				summary.Text = table.concat(handle.value, ", ")
			end
		end

		local function resize(visibleCount)
			local listH = math.min(visibleCount * 29, 150)
			list.Size = UDim2.new(1, 0, 0, listH)
			panel.Size = UDim2.new(1, -20, 0, 32 + listH)
			local h = open and (50 + 32 + listH + 10) or 46
			tween(card, 0.18, { Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset, 0, h) })
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
						Size = UDim2.new(1, -6, 0, 26),
						AutoButtonColor = false,
						Text = opt,
						Font = FONT_REG,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						BorderSizePixel = 0,
						BackgroundColor3 = selected and win.theme.accent or win.theme.panel,
						BackgroundTransparency = selected and 0.75 or 0,
						TextColor3 = selected and win.theme.accent2 or win.theme.text,
						LayoutOrder = count,
						Parent = list,
					})
					corner(btn, UDim.new(0, 7))
					create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = btn })
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
							chevron.Text = "▾"
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
			chevron.Text = "▾"
			resize(0)
		end

		box:GetPropertyChangedSignal("Text"):Connect(function()
			search = box.Text
			rebuild()
		end)

		local header = create("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, 46),
			ZIndex = 2,
			Parent = card,
		})
		header.MouseButton1Click:Connect(function()
			if handle.locked then
				return
			end
			open = not open
			panel.Visible = open
			chevron.Text = open and "▴" or "▾"
			rebuild()
		end)

		handle.value = normalize(pick(props, "value", {}))
		refreshSummary()
		rebuild()
		table.insert(win._refreshers, function()
			rebuild()
		end)

		place(card, 240)
		decorate(target, handle, card, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Input
	function target:CreateInput(props)
		props = props or {}
		local card, refs = buildCard(win, props, 46, 170)
		local numeric = pick(props, "numeric", false)
		local cb = pick(props, "callback")
		local handle = { value = tostring(pick(props, "value", "")) }

		local box = create("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 28),
			Text = handle.value,
			PlaceholderText = tostring(pick(props, "placeholder", "")),
			ClearTextOnFocus = false,
			Font = FONT_REG,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			Parent = card,
		})
		bind(win, box, "BackgroundColor3", "panel")
		bind(win, box, "TextColor3", "text")
		bind(win, box, "PlaceholderColor3", "subtext")
		corner(box, UDim.new(0, 8))
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })

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
			if pick(props, "clearOnFocus", false) then
				box.Text = ""
			end
		end)
		box.FocusLost:Connect(function()
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

		place(card, 240)
		decorate(target, handle, card, refs)
		registerFlag(win, handle, props)
		return handle
	end

	------------------------------------------------------------ Text
	function target:CreateText(props)
		props = props or {}
		local card = create("Frame", {
			Name = "Text",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0,
		})
		bind(win, card, "BackgroundColor3", "card")
		corner(card, UDim.new(0, 10))
		local stroke = create("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		})
		bind(win, stroke, "Color", "stroke")
		create("UIPadding", {
			PaddingTop = UDim.new(0, 11),
			PaddingBottom = UDim.new(0, 11),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 14),
			Parent = card,
		})
		create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

		local titleLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = card,
		})
		bind(win, titleLabel, "TextColor3", "text")
		local bodyLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_REG,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
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

		place(card, 220)
		decorate(target, handle, card, nil)
		return handle
	end
	target.CreateLabel = target.CreateText

	------------------------------------------------------------ Divider
	function target:CreateDivider(props)
		props = props or {}
		local text = pick(props, "name", pick(props, "text"))
		local frame = create("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, pick(props, "height", 18)),
		})
		if text and text ~= "" then
			text = tostring(text)
			local w = TextService:GetTextSize(text, 11, FONT_BOLD, Vector2.new(1000, 20)).X
			local left = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.5, -(w / 2 + 10), 0, 1),
				BorderSizePixel = 0,
				Parent = frame,
			})
			bind(win, left, "BackgroundColor3", "stroke")
			local right = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0.5, -(w / 2 + 10), 0, 1),
				BorderSizePixel = 0,
				Parent = frame,
			})
			bind(win, right, "BackgroundColor3", "stroke")
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(w + 4, 16),
				Text = text,
				Font = FONT_BOLD,
				TextSize = 11,
				Parent = frame,
			})
			bind(win, label, "TextColor3", "subtext")
		else
			local line = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 1),
				BorderSizePixel = 0,
				Parent = frame,
			})
			bind(win, line, "BackgroundColor3", "stroke")
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
			Size = UDim2.new(1, 0, 0, 26),
		})
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -4, 1, 0),
			Text = tostring(pick(props, "name", "")):upper(),
			Font = FONT_BOLD,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		bind(win, label, "TextColor3", "accent2")
		local handle = {}
		function handle:SetName(t)
			label.Text = tostring(t):upper()
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
-- Window
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
	self._main.Visible = true
	self._pill.Visible = false
end

function Window:Hide()
	self._main.Visible = false
	self._pill.Visible = true
end

function Window:ToggleHide()
	if self._main.Visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:ToggleMinimise()
	if self._minimised then
		self._minimised = false
		self._body.Visible = true
		tween(self._main, 0.25, { Size = self._fullSize })
	else
		self._minimised = true
		self._fullSize = self._main.Size
		self._body.Visible = false
		tween(self._main, 0.25, { Size = UDim2.new(self._fullSize.X.Scale, self._fullSize.X.Offset, 0, 46) })
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
		pcall(function()
			c:Disconnect()
		end)
	end
	self._gui:Destroy()
end

function Window:SetProfile(text)
	if self._profileLabel then
		self._profileLabel.Text = text and tostring(text) or ""
		self._profileLabel.Visible = self._profileLabel.Text ~= ""
	end
end

function Window:Notify(props)
	props = props or {}
	local title = tostring(pick(props, "title", pick(props, "name", "Notification")))
	local content = tostring(pick(props, "content", pick(props, "description", pick(props, "body", ""))))
	local duration = pick(props, "duration", 4)

	local card = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self._notifHolder,
	})
	bind(self, card, "BackgroundColor3", "card")
	corner(card, UDim.new(0, 12))
	local stroke = create("UIStroke", {
		Thickness = 1.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})
	bindGradient(self, create("UIGradient", { Parent = stroke }), "accent")
	create("UIPadding", {
		PaddingTop = UDim.new(0, 11),
		PaddingBottom = UDim.new(0, 11),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = card,
	})
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local t = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = title,
		Font = FONT_BOLD,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = card,
	})
	bind(self, t, "TextColor3", "text")
	if content ~= "" then
		local c = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = content,
			Font = FONT_REG,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
		})
		bind(self, c, "TextColor3", "subtext")
	end

	tween(card, 0.3, { GroupTransparency = 0 })
	task.delay(duration, function()
		if card.Parent then
			tween(card, 0.3, { GroupTransparency = 1 })
			task.delay(0.35, function()
				card:Destroy()
			end)
		end
	end)
end

function Window:Toast(props)
	props = props or {}
	local text = tostring(pick(props, "text", pick(props, "content", pick(props, "title", pick(props, "name", "")))))
	local duration = pick(props, "duration", 2.5)

	local toast = create("CanvasGroup", {
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self._toastHolder,
	})
	bind(self, toast, "BackgroundColor3", "card")
	corner(toast, UDim.new(1, 0))
	local stroke = create("UIStroke", {
		Thickness = 1.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = toast,
	})
	bindGradient(self, create("UIGradient", { Parent = stroke }), "accent")
	create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = toast })
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = FONT,
		TextSize = 13,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = toast,
	})
	bind(self, label, "TextColor3", "text")

	tween(toast, 0.25, { GroupTransparency = 0 })
	task.delay(duration, function()
		if toast.Parent then
			tween(toast, 0.25, { GroupTransparency = 1 })
			task.delay(0.3, function()
				toast:Destroy()
			end)
		end
	end)
end

------------------------------------------------------------------------
-- CreateWindow
------------------------------------------------------------------------

function Lumen:CreateWindow(props)
	props = props or {}
	local name = tostring(pick(props, "name", "Lumen Window"))
	local sidebar = pick(props, "sidebarLayout", false)
	local cfg = pick(props, "configuration")

	local win = setmetatable({
		_name = name,
		_cfg = cfg,
		_bindings = {},
		_refreshers = {},
		_flags = {},
		_tabs = {},
		_conns = {},
		_loading = false,
		unloaded = false,
	}, Window)
	win.theme = resolveTheme(pick(props, "theme", "default"))
	win.Flags = setmetatable({}, {
		__index = function(_, k)
			return win:Get(k)
		end,
		__newindex = function(_, k, v)
			win:Set(k, v)
		end,
	})

	-- Pre-read saved state so elements restore themselves as they are created.
	if cfg and cfg.autoLoad and fsAvailable() then
		local _, path = win:GetPath()
		local ok, data = pcall(function()
			if isfile(path) then
				return HttpService:JSONDecode(readfile(path))
			end
			return nil
		end)
		if ok and type(data) == "table" then
			win._saved = data
		end
	end

	local gui = create("ScreenGui", {
		Name = "Lumen_" .. name:gsub("%W", ""),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	getGuiParent(gui)
	win._gui = gui

	local width, height = 560, 380
	if sidebar then
		width, height = 660, 410
	end

	local main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	main.BackgroundColor3 = Color3.new(1, 1, 1)
	corner(main, UDim.new(0, 16))
	bindGradient(win, create("UIGradient", { Rotation = 55, Parent = main }), "bg")
	local mainStroke = create("UIStroke", {
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = main,
	})
	bindGradient(win, create("UIGradient", { Rotation = 35, Parent = mainStroke }), "accent")
	win._main = main

	local glow = create("Frame", {
		Position = UDim2.new(0, 24, 0, 0),
		Size = UDim2.new(1, -48, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = main,
	})
	bindGradient(win, create("UIGradient", { Parent = glow }), "accent")

	-- Title bar
	local titleBar = create("Frame", {
		Name = "TitleBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = main,
	})
	local titleIcon = assetId(pick(props, "icon"))
	local titleLeft = 18
	if titleIcon then
		local img = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = titleIcon,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			Parent = titleBar,
		})
		bind(win, img, "ImageColor3", "accent2")
		titleLeft = 46
	end
	local subtitle = pick(props, "subtitle")
	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = name,
		Font = FONT_BOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, titleLeft, 0, subtitle and 6 or 14),
		Size = UDim2.new(1, -(titleLeft + 90), 0, 18),
		Parent = titleBar,
	})
	bind(win, titleLabel, "TextColor3", "text")
	if subtitle then
		local sub = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tostring(subtitle),
			Font = FONT_REG,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, titleLeft, 0, 25),
			Size = UDim2.new(1, -(titleLeft + 90), 0, 14),
			Parent = titleBar,
		})
		bind(win, sub, "TextColor3", "subtext")
	end

	local function titleButton(text, xOffset, onClick)
		local b = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			Text = text,
			Font = FONT_BOLD,
			TextSize = 15,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Parent = titleBar,
		})
		bind(win, b, "BackgroundColor3", "card")
		bind(win, b, "TextColor3", "subtext")
		corner(b, UDim.new(1, 0))
		b.MouseEnter:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = win.theme.accent })
			tween(b, 0.12, { TextColor3 = Color3.new(1, 1, 1) })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.12, { BackgroundColor3 = win.theme.card })
			tween(b, 0.12, { TextColor3 = win.theme.subtext })
		end)
		b.MouseButton1Click:Connect(onClick)
	end
	titleButton("×", -14, function()
		win:Hide()
	end)
	titleButton("–", -44, function()
		win:ToggleMinimise()
	end)

	-- Dragging
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	win:_conn(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	-- Body
	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		Parent = main,
	})
	win._body = body

	local tabHolder, pageParent, railList
	if sidebar then
		local rail = create("Frame", {
			Name = "Rail",
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(0, 154, 1, -10),
			BorderSizePixel = 0,
			Parent = body,
		})
		bind(win, rail, "BackgroundColor3", "panel")
		corner(rail, UDim.new(0, 12))
		local railStroke = create("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = rail,
		})
		bind(win, railStroke, "Color", "stroke")

		railList = create("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 1, -62),
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = rail,
		})
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = railList })
		tabHolder = railList

		local profile = create("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 6, 1, -6),
			Size = UDim2.new(1, -12, 0, 46),
			BorderSizePixel = 0,
			Parent = rail,
		})
		bind(win, profile, "BackgroundColor3", "card")
		corner(profile, UDim.new(0, 10))
		local avatar = create("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			Parent = profile,
		})
		corner(avatar, UDim.new(1, 0))
		local lp = Players.LocalPlayer
		if lp then
			avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=48&h=48"
		end
		local pname = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = lp and lp.DisplayName or "Player",
			Font = FONT,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 46, 0, 8),
			Size = UDim2.new(1, -52, 0, 14),
			Parent = profile,
		})
		bind(win, pname, "TextColor3", "text")
		local pline = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = tostring(pick(props, "profile", "")),
			Visible = pick(props, "profile") ~= nil,
			Font = FONT_REG,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 46, 0, 23),
			Size = UDim2.new(1, -52, 0, 13),
			Parent = profile,
		})
		bind(win, pline, "TextColor3", "subtext")
		win._profileLabel = pline

		local content = create("Frame", {
			Name = "Content",
			Position = UDim2.new(0, 172, 0, 0),
			Size = UDim2.new(1, -182, 1, -10),
			BorderSizePixel = 0,
			Parent = body,
		})
		bind(win, content, "BackgroundColor3", "panel")
		corner(content, UDim.new(0, 12))
		local contentStroke = create("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = content,
		})
		bind(win, contentStroke, "Color", "stroke")
		pageParent = content
	else
		local pill = create("Frame", {
			Name = "TabPill",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			Parent = body,
		})
		bind(win, pill, "BackgroundColor3", "panel")
		corner(pill, UDim.new(1, 0))
		local pillStroke = create("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = pill,
		})
		bind(win, pillStroke, "Color", "stroke")
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = pill,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = pill,
		})
		tabHolder = pill

		pageParent = create("Frame", {
			Name = "Pages",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 46),
			Size = UDim2.new(1, -24, 1, -56),
			Parent = body,
		})
	end

	-- Collapsed pill
	local showName = tostring(pick(props, "showName", name))
	local pillBtn = create("TextButton", {
		Name = "Collapsed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = showName,
		Font = FONT_BOLD,
		TextSize = 13,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	bind(win, pillBtn, "BackgroundColor3", "card")
	bind(win, pillBtn, "TextColor3", "text")
	corner(pillBtn, UDim.new(1, 0))
	create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = pillBtn })
	local pillStroke2 = create("UIStroke", {
		Thickness = 1.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = pillBtn,
	})
	bindGradient(win, create("UIGradient", { Parent = pillStroke2 }), "accent")
	pillBtn.MouseButton1Click:Connect(function()
		win:Show()
	end)
	win._pill = pillBtn

	-- Notifications and toasts
	win._notifHolder = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 290, 1, -32),
		Parent = gui,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = win._notifHolder,
	})
	win._toastHolder = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 320, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = win._toastHolder,
	})

	-- Optional toggle key
	local toggleKey = pick(props, "toggleKey")
	if toggleKey then
		if type(toggleKey) == "string" then
			toggleKey = Enum.KeyCode[toggleKey]
		end
		win:_conn(UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == toggleKey then
				win:ToggleHide()
			end
		end))
	end

	-- Sidebar sections
	function win:CreateSection(sprops)
		if not sidebar then
			return { Remove = function() end }
		end
		sprops = sprops or {}
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Text = tostring(pick(sprops, "name", "")):upper(),
			Font = FONT_BOLD,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = #win._tabs + 1,
			Parent = tabHolder,
		})
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = label })
		bind(win, label, "TextColor3", "subtext")
		win._railOrder = (win._railOrder or 0) + 1
		label.LayoutOrder = win._railOrder
		return {
			Remove = function()
				label:Destroy()
			end,
		}
	end

	-- Tabs
	function win:CreateTab(tprops)
		tprops = tprops or {}
		local tname = tostring(pick(tprops, "name", ""))
		local ticon = assetId(pick(tprops, "icon"))
		local tab = { name = tname }

		win._railOrder = (win._railOrder or 0) + 1

		local btn
		local iconImg
		if sidebar then
			btn = create("TextButton", {
				Name = tname,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Text = tname,
				Font = FONT,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				LayoutOrder = win._railOrder,
				Parent = tabHolder,
			})
			corner(btn, UDim.new(0, 9))
			create("UIPadding", { PaddingLeft = UDim.new(0, ticon and 34 or 12), Parent = btn })
		else
			btn = create("TextButton", {
				Name = tname,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Text = tname,
				Font = FONT,
				TextSize = 13,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = win._railOrder,
				Parent = tabHolder,
			})
			corner(btn, UDim.new(1, 0))
			create("UIPadding", {
				PaddingLeft = UDim.new(0, ticon and 32 or 14),
				PaddingRight = UDim.new(0, 14),
				Parent = btn,
			})
		end
		if ticon then
			iconImg = create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = ticon,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, sidebar and -22 or -22, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				Parent = btn,
			})
		end

		local page = create("ScrollingFrame", {
			Name = tname,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			Visible = false,
			Parent = pageParent,
		})
		bind(win, page, "ScrollBarImageColor3", "accent")
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
		local pad = sidebar and 12 or 4
		create("UIPadding", {
			PaddingTop = UDim.new(0, pad),
			PaddingBottom = UDim.new(0, pad),
			PaddingLeft = UDim.new(0, pad),
			PaddingRight = UDim.new(0, pad + 4),
			Parent = page,
		})

		addMethods(tab, win, page, false)
		tab.page = page
		tab.button = btn

		function tab:_style(selected, instant)
			local t = instant and 0 or 0.18
			local theme = win.theme
			tween(btn, t, {
				BackgroundColor3 = theme.accent,
				BackgroundTransparency = selected and (sidebar and 0.8 or 0.1) or 1,
				TextColor3 = selected and theme.text or theme.subtext,
			})
			if iconImg then
				tween(iconImg, t, { ImageColor3 = selected and theme.accent2 or theme.subtext })
			end
		end

		function tab:Select(noAnimation)
			local current = win._activeTab
			if current and current ~= tab then
				current:Deselect(noAnimation)
			end
			win._activeTab = tab
			page.Visible = true
			tab._selected = true
			tab:_style(true, noAnimation)
		end

		function tab:Deselect(noAnimation)
			page.Visible = false
			tab._selected = false
			tab:_style(false, noAnimation)
			if win._activeTab == tab then
				win._activeTab = nil
			end
		end

		function tab:Remove()
			local wasActive = win._activeTab == tab
			for i, t in ipairs(win._tabs) do
				if t == tab then
					table.remove(win._tabs, i)
					break
				end
			end
			btn:Destroy()
			page:Destroy()
			if wasActive then
				win._activeTab = nil
				if win._tabs[1] then
					win._tabs[1]:Select(true)
				end
			end
		end

		btn.MouseEnter:Connect(function()
			if not tab._selected then
				tween(btn, 0.12, { TextColor3 = win.theme.text })
			end
		end)
		btn.MouseLeave:Connect(function()
			if not tab._selected then
				tween(btn, 0.12, { TextColor3 = win.theme.subtext })
			end
		end)
		btn.MouseButton1Click:Connect(function()
			tab:Select()
		end)

		table.insert(win._tabs, tab)
		table.insert(win._refreshers, function()
			tab:_style(tab._selected == true, false)
		end)

		tab:_style(false, true)
		if #win._tabs == 1 then
			tab:Select(true)
		end
		return tab
	end

	return win
end

return Lumen
