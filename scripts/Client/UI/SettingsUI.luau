--!strict
--[[
	SettingsUI
	The Settings panel, in three pages (the developer, 2026-11-10: "two or three categories", and no small print under
	the switches):

	  GAME         FIELD OF VIEW (how wide the eyes see), HEAD BOB (the picture steps with the feet), HOLD TO CROUCH
	               (Ctrl held, or pressed once).
	  PERFORMANCE  GRAPHICS (Low, Medium, High, Ultra) and SHADOWS (on, off). Names and nothing else.
	               In the castle a quality can only be LOWERED (configs/Graphics.Lock): the ones above the best that may
	               still be chosen are crossed out, and lowering asks first: "ARE YOU SURE?", YES or NO.
	  KEYS         what every key does (a computer only: a phone has buttons).

	It opens from the gear beside the chat. The panel rises and settles like a page being laid on a table, and
	sinks away when it is closed (the burgundy X, the dark behind it, or the gear again).

	Presentation only. It draws the state it is given (`setState` for the picture; the player's own attributes
	`ViewFov`, `ViewBob`, `CrouchHold`, `GfxLocked`, `GfxCeiling` for the rest, which the server sets) and reports what
	the player pressed (`onChange`); the server checks and keeps every choice.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.SettingsUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)

local SettingsUI = {}

export type Change = { graphics: string?, shadows: boolean?, fov: number?, headBob: boolean?, crouchHold: boolean? }

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local veil: TextButton? = nil
local panel: Frame? = nil
local scale: UIScale? = nil
local onChange: ((Change) -> ())? = nil
local opened = false
local token = 0

local current = { graphics = "High", shadows = true }

local tierButtons: { [string]: TextButton } = {}
local tierCross: { [string]: Frame } = {}
local redraws: { () -> () } = {}
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local page = "GAME"
local confirm: GuiObject? = nil
local confirmYes: (() -> ())? = nil

local KNOB = 24
local TRACK_W = 62
local TRACK_H = 30
local ROW = 38
local WIDTH = 520

-- What each key does, in the order a new player needs them (configs: View.UnlockKey, Movement, Crouch).
local KEYS = {
	{ "W  A  S  D", "Move" },
	{ "Mouse", "Look" },
	{ "Shift", "Run" },
	{ "Q", "Dash" },
	{ "Ctrl", "Crouch" },
	{ "Space", "Jump" },
	{ "L", "Unlock your mouse" },
	{ "Left click", "Strike  (hold to draw the bow)" },
	{ "Wheel  /  1 2 3", "Choose a weapon" },
	{ "G", "Cover the lantern" },
	{ "E", "Use what is in front of you" },
	{ "B", "The pack" },
	{ "P", "The muster roll" },
}

local function send(change: Change)
	if onChange then
		onChange(change)
	end
end

local function locked(): boolean
	return player:GetAttribute("GfxLocked") == true
end

-- the best quality that may still be chosen here (where the quality may only go down)
local function ceiling(): string
	local kept = player:GetAttribute("GfxCeiling")
	return if typeof(kept) == "string" then kept else current.graphics
end

--============================================================================
-- Pieces
--============================================================================
local function caption(parent: Instance, text: string, order: number): TextLabel
	local label = Components.label({
		Name = "Caption",
		Text = Components.spaced(text),
		Role = Theme.Role.Heading,
		TextSize = 20,
		TextColor = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
	return label
end

local function row(parent: Instance, name: string, text: string, order: number): Frame
	local frame = Components.group({ Name = name, Size = UDim2.new(1, 0, 0, ROW), LayoutOrder = order, Parent = parent })
	local label = caption(frame, text, 1)
	label.Size = UDim2.new(1, -150, 1, 0)
	return frame
end

-- An ON / OFF switch at the right of a row. `get` reads what is so; `set` is called with what the player wants.
local function switch(parent: Frame, get: () -> boolean, set: (boolean) -> ())
	local button = Instance.new("TextButton")
	button.Name = "Switch"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, 0, 0.5, 0)
	button.Size = UDim2.fromOffset(TRACK_W, TRACK_H)
	button.BackgroundTransparency = 1
	button.ZIndex = 4
	button.Parent = parent

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BorderSizePixel = 0
	track.ZIndex = 4
	track.Parent = button
	Theme.corner(track, UDim.new(0.5, 0))
	Theme.goldStroke(track, 1.2)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.BackgroundColor3 = Theme.Color.Cream
	knob.BorderSizePixel = 0
	knob.ZIndex = 5
	knob.Parent = track
	Theme.corner(knob, UDim.new(0.5, 0))
	Theme.surface(knob, Theme.Color.Cream, Theme.Color.Parchment:Lerp(Theme.Color.Bronze, 0.35))

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromOffset(TRACK_W - KNOB - 6, TRACK_H)
	word.TextSize = 12
	word.ZIndex = 5
	word.Parent = track
	Theme.applyFont(word, Theme.Role.Strong)

	local first = true
	local function draw()
		local on = get()
		local info = if first then TweenInfo.new(0) else Theme.Motion.Normal
		first = false
		TweenService:Create(knob, info, { Position = UDim2.fromOffset(if on then TRACK_W - KNOB - 3 else 3, (TRACK_H - KNOB) / 2) }):Play()
		TweenService:Create(track, info, { BackgroundColor3 = if on then Theme.Color.GreenTop else Color3.fromRGB(58, 42, 30) }):Play()
		word.Text = if on then "ON" else "OFF"
		word.TextColor3 = if on then Theme.Color.Cream else Theme.Color.Muted
		word.Position = if on then UDim2.fromOffset(0, 0) else UDim2.fromOffset(KNOB + 3, 0)
	end
	button.Activated:Connect(function()
		set(not get())
	end)
	table.insert(redraws, draw)
	draw()
end

-- A small square button with one sign on it (the - and + of the field of view).
local function sign(parent: Instance, text: string, x: number): TextButton
	local button = Components.button({
		Name = text,
		Text = text,
		Variant = "ghost",
		TextSize = 22,
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Parent = parent,
	})
	button.ZIndex = 4
	return button
end

--============================================================================
-- The picture quality
--============================================================================
local function drawTiers()
	local cfg = Config.get("Graphics")
	local lock = locked()
	local top = ceiling()
	for id, button in tierButtons do
		local crossed = lock and not PlayerSettings.allowed(cfg, id, top)
		Components.setVariant(button, if id == current.graphics then "gold" else "ghost")
		local cross = tierCross[id]
		if cross then
			cross.Visible = crossed
		end
		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.TextTransparency = if crossed then 0.6 else 0
		end
		button.Active = not crossed
	end
end

local function askLower(id: string)
	local sheet = confirm
	if not sheet then
		return
	end
	confirmYes = function()
		send({ graphics = id })
	end
	sheet.Visible = true
	local box = sheet:FindFirstChild("Box")
	local s = box and box:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 0.9
		TweenService:Create(s, Theme.Motion.Enter, { Scale = 1 }):Play()
	end
end

local function chooseTier(id: string)
	if current.graphics == id then
		return
	end
	local cfg = Config.get("Graphics")
	if locked() then
		if not PlayerSettings.allowed(cfg, id, ceiling()) then
			return -- crossed out: it cannot be raised here
		end
		if PlayerSettings.rank(cfg, id) < PlayerSettings.rank(cfg, current.graphics) then
			askLower(id)
			return
		end
	end
	send({ graphics = id })
end

--============================================================================
-- Build
--============================================================================
local function showPage(name: string)
	page = name
	for id, frame in pages do
		frame.Visible = id == name
	end
	for id, button in tabButtons do
		Components.setVariant(button, if id == name then "gold" else "ghost")
	end
end

local function buildGame(parent: Frame)
	local view = Config.get("View")

	-- (the field of view is no longer a choice, 2026-11-14: the developer locked it to one standard, configs/View.Fov)
	local _ = view

	local bobRow = row(parent, "HeadBob", "HEAD BOB", 3)
	switch(bobRow, function()
		return player:GetAttribute("ViewBob") ~= false
	end, function(on)
		send({ headBob = on })
	end)
	Components.divider(parent, 4)

	local holdRow = row(parent, "CrouchHold", "HOLD TO CROUCH", 5)
	switch(holdRow, function()
		return player:GetAttribute("CrouchHold") == true
	end, function(on)
		send({ crouchHold = on })
	end)
end

local function buildPerformance(parent: Frame)
	local cfg = Config.get("Graphics")
	local head = caption(parent, "GRAPHICS", 1)
	head.Size = UDim2.new(1, 0, 0, 26)
	local tiers = Components.group({ Name = "Tiers", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2, Parent = parent })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = tiers
	for index, id in cfg.Order do
		local button = Components.button({
			Name = id,
			Text = cfg.Tiers[id].Label,
			Variant = "ghost",
			TextSize = 19,
			Size = UDim2.new(1 / #cfg.Order, -5, 1, 0),
			LayoutOrder = index,
			Parent = tiers,
		})
		button.Activated:Connect(function()
			chooseTier(id)
		end)
		tierButtons[id] = button
		-- the cross of a quality that cannot be chosen here: two thin strokes from corner to corner
		local cross = Instance.new("Frame")
		cross.Name = "Cross"
		cross.Size = UDim2.fromScale(1, 1)
		cross.BackgroundTransparency = 1
		cross.Visible = false
		cross.ZIndex = 6
		cross.Parent = button
		for _, turn in { 21, -21 } do
			local stroke = Instance.new("Frame")
			stroke.AnchorPoint = Vector2.new(0.5, 0.5)
			stroke.Position = UDim2.fromScale(0.5, 0.5)
			stroke.Size = UDim2.new(0.86, 0, 0, 2)
			stroke.Rotation = turn
			stroke.BackgroundColor3 = Theme.Color.BordeauxSoft
			stroke.BorderSizePixel = 0
			stroke.ZIndex = 6
			stroke.Parent = cross
		end
		tierCross[id] = cross
	end
	Components.divider(parent, 3)

	local shadowRow = row(parent, "Shadows", "SHADOWS", 4)
	switch(shadowRow, function()
		return current.shadows
	end, function(on)
		send({ shadows = on })
	end)
	table.insert(redraws, drawTiers)
end

local function buildKeys(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, 0, 0, math.min(#KEYS * 30 + 4, 316))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Color.Gold
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 1
	scroll.ZIndex = 3
	scroll.Parent = parent
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = scroll
	for index, entry in KEYS do
		local line = Instance.new("Frame")
		line.Name = "Key" .. index
		line.Size = UDim2.new(1, -8, 0, 26)
		line.BackgroundTransparency = 1
		line.LayoutOrder = index
		line.ZIndex = 3
		line.Parent = scroll

		-- the key itself, as a small dark cap
		-- (the letters are in a label of their own: a gradient on a label paints its letters too, and they were lost)
		local cap = Instance.new("Frame")
		cap.Name = "Cap"
		cap.AutomaticSize = Enum.AutomaticSize.X
		cap.Size = UDim2.fromOffset(0, 24)
		cap.Position = UDim2.fromOffset(0, 1)
		cap.BackgroundColor3 = Color3.new(1, 1, 1)
		cap.BorderSizePixel = 0
		cap.ZIndex = 4
		cap.Parent = line
		Theme.surface(cap, Color3.fromRGB(46, 44, 46), Color3.fromRGB(14, 13, 14))
		Theme.corner(cap, UDim.new(0, 5))
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(96, 94, 98)
		edge.Thickness = 1.2
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = cap
		local letters = Instance.new("TextLabel")
		letters.Name = "Letters"
		letters.AutomaticSize = Enum.AutomaticSize.X
		letters.Size = UDim2.fromOffset(0, 24)
		letters.BackgroundTransparency = 1
		letters.TextSize = 14
		letters.TextColor3 = Theme.Color.Cream
		letters.Text = entry[1]
		letters.ZIndex = 5
		letters.Parent = cap
		Theme.applyFont(letters, Theme.Role.Strong)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 9)
		pad.PaddingRight = UDim.new(0, 9)
		pad.Parent = letters

		local what = Instance.new("TextLabel")
		what.Name = "What"
		what.BackgroundTransparency = 1
		what.Position = UDim2.fromOffset(176, 0)
		what.Size = UDim2.new(1, -176, 1, 0)
		what.TextXAlignment = Enum.TextXAlignment.Left
		what.TextSize = 17
		what.TextColor3 = Theme.Color.Parchment
		what.Text = entry[2]
		what.ZIndex = 4
		what.Parent = line
		Theme.applyFont(what, Theme.Role.Body)
	end
end

local function buildConfirm(screen: ScreenGui)
	local lock = Config.get("Graphics").Lock
	-- a dark sheet over the panel: nothing under it can be pressed while the question stands
	local sheet = Instance.new("TextButton")
	sheet.Name = "Confirm"
	sheet.Text = ""
	sheet.AutoButtonColor = false
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.BackgroundColor3 = Color3.new(0, 0, 0)
	sheet.BackgroundTransparency = 0.35
	sheet.BorderSizePixel = 0
	sheet.ZIndex = 20
	sheet.Visible = false
	sheet.Parent = screen

	local box = Components.panel({
		Name = "Box",
		Size = UDim2.fromOffset(440, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 21,
		Parent = sheet,
	})
	box.AutomaticSize = Enum.AutomaticSize.Y
	Theme.padding(box, 22)
	Components.list(box, 14)
	local s = Instance.new("UIScale")
	s.Parent = box

	local ask = Components.label({
		Name = "Ask",
		Text = Components.spaced(lock.Ask),
		Role = Theme.Role.Heading,
		TextSize = 26,
		TextColor = Theme.Color.GoldBright,
		LayoutOrder = 1,
		Parent = box,
	})
	ask.ZIndex = 22
	local warning = Components.label({
		Name = "Warning",
		Text = lock.Warning,
		TextSize = 18,
		TextColor = Theme.Color.Parchment,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = box,
	})
	warning.AutomaticSize = Enum.AutomaticSize.Y
	warning.ZIndex = 22

	local buttons = Components.group({ Name = "Buttons", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Parent = box })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	layout.Parent = buttons
	local function close()
		sheet.Visible = false
		confirmYes = nil
	end
	for index, def in { { "YES", "green" }, { "NO", "exit" } } do
		local button = Components.button({
			Name = def[1],
			Text = def[1],
			Variant = def[2],
			TextSize = 20,
			Size = UDim2.fromOffset(150, 44),
			LayoutOrder = index,
			Parent = buttons,
		})
		button.ZIndex = 22
		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.ZIndex = 23
		end
		button.Activated:Connect(function()
			local yes = confirmYes
			close()
			if def[1] == "YES" and yes then
				yes()
			end
		end)
	end
	confirm = sheet
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "SettingsUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen

	-- the dark behind the page; a press on it closes the page
	local dark = Instance.new("TextButton")
	dark.Name = "Veil"
	dark.Text = ""
	dark.AutoButtonColor = false
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 1
	dark.BorderSizePixel = 0
	dark.ZIndex = 1
	dark.Parent = screen
	dark.Activated:Connect(function()
		SettingsUI.close()
	end)
	veil = dark

	local root = Components.panel({
		Name = "SettingsPanel",
		Size = UDim2.fromOffset(WIDTH, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = screen,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(330, 0)
	limit.MaxSize = Vector2.new(WIDTH, math.huge)
	limit.Parent = root
	Theme.padding(root, 24)
	Components.list(root, 12)
	panel = root

	local s = Instance.new("UIScale")
	s.Scale = 0.88
	s.Parent = root
	scale = s

	-- the title, with the way out hanging from its corner
	local title = Components.label({
		Name = "Title",
		Text = Components.spaced("SETTINGS"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.GoldBright,
		LayoutOrder = 1,
		Parent = root,
	})
	Components.closeButton(title, function()
		SettingsUI.close()
	end)

	-- the three pages' names
	local names = { "GAME", "PERFORMANCE" }
	if UserInputService.KeyboardEnabled then
		table.insert(names, "KEYS")
	end
	local tabs = Components.group({ Name = "Tabs", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2, Parent = root })
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs
	for index, name in names do
		local button = Components.button({
			Name = name,
			Text = name,
			Variant = "ghost",
			TextSize = 17,
			Size = UDim2.new(1 / #names, -4, 1, 0),
			LayoutOrder = index,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			showPage(name)
		end)
		tabButtons[name] = button
	end
	Components.divider(root, 3)

	local builders: { [string]: (Frame) -> () } = { GAME = buildGame, PERFORMANCE = buildPerformance, KEYS = buildKeys }
	for _, name in names do
		local frame = Components.group({ Name = name, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 4, Parent = root })
		frame.AutomaticSize = Enum.AutomaticSize.Y
		Components.list(frame, 10)
		builders[name](frame)
		pages[name] = frame
	end

	buildConfirm(screen)

	-- the server keeps every choice; the panel draws what it kept
	for _, attribute in { "ViewFov", "ViewBob", "CrouchHold", "GfxLocked", "GfxCeiling" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			for _, draw in redraws do
				draw()
			end
		end)
	end

	showPage(page)
	drawTiers()
end

--============================================================================
-- API
--============================================================================

function SettingsUI.mount(handler: (Change) -> ())
	onChange = handler
	if not gui then
		build()
	end
end

-- Shows the picture the server has kept (or the one the device starts with).
function SettingsUI.setState(graphics: string, shadows: boolean)
	current.graphics = graphics
	current.shadows = shadows
	if gui then
		for _, draw in redraws do
			draw()
		end
	end
end

function SettingsUI.isOpen(): boolean
	return opened
end

function SettingsUI.open()
	local screen, dark, root, s = gui, veil, panel, scale
	if opened or not screen or not dark or not root or not s then
		return
	end
	opened = true
	token += 1
	screen.Enabled = true
	dark.BackgroundTransparency = 1
	s.Scale = 0.86
	root.Position = UDim2.new(0.5, 0, 0.5, 22)
	TweenService:Create(dark, TweenInfo.new(0.22), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(s, Theme.Motion.Enter, { Scale = 1 }):Play()
	TweenService:Create(root, Theme.Motion.Enter, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

function SettingsUI.close()
	local screen, dark, root, s = gui, veil, panel, scale
	if not opened or not screen or not dark or not root or not s then
		return
	end
	opened = false
	token += 1
	local mine = token
	if confirm then
		confirm.Visible = false
		confirmYes = nil
	end
	TweenService:Create(dark, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(s, Theme.Motion.Exit, { Scale = 0.9 }):Play()
	TweenService:Create(root, Theme.Motion.Exit, { Position = UDim2.new(0.5, 0, 0.5, 14) }):Play()
	task.delay(0.2, function()
		if token == mine and not opened then
			screen.Enabled = false
		end
	end)
end

function SettingsUI.toggle()
	if opened then
		SettingsUI.close()
	else
		SettingsUI.open()
	end
end

return SettingsUI
