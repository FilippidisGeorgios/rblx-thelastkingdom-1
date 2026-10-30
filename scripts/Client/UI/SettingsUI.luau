--!strict
--[[
	SettingsUI
	The Settings panel: the picture quality (Low, Medium, High, Ultra) and the shadows switch.

	It opens from the gear beside the chat. The panel rises and settles like a page being laid on a table, and
	sinks away when it is closed (the burgundy X, the dark behind it, or the gear again).

	Presentation only. It draws the state it is given (`setState`) and reports what the player pressed
	(`onChange`); the GraphicsController does the drawing of the world and the server checks and keeps the choice.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.SettingsUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)

local SettingsUI = {}

export type Change = { graphics: string?, shadows: boolean? }

local gui: ScreenGui? = nil
local veil: Frame? = nil
local panel: Frame? = nil
local scale: UIScale? = nil
local blurb: TextLabel? = nil
local shadowsCaption: TextLabel? = nil
local switchTrack: Frame? = nil
local switchKnob: Frame? = nil
local switchWord: TextLabel? = nil
local tierButtons: { [string]: TextButton } = {}
local onChange: ((Change) -> ())? = nil
local opened = false
local token = 0

local current = { graphics = "High", shadows = true }

local KNOB = 24
local TRACK_W = 62
local TRACK_H = 30

--============================================================================
-- Drawing the state
--============================================================================

local function drawSwitch(animate: boolean)
	local track, knob, word = switchTrack, switchKnob, switchWord
	if not track or not knob or not word then
		return
	end
	local on = current.shadows
	local targetX = if on then TRACK_W - KNOB - 3 else 3
	local trackColor = if on then Theme.Color.GreenTop else Color3.fromRGB(58, 42, 30)
	local info = if animate then Theme.Motion.Normal else TweenInfo.new(0)
	TweenService:Create(knob, info, { Position = UDim2.fromOffset(targetX, (TRACK_H - KNOB) / 2) }):Play()
	TweenService:Create(track, info, { BackgroundColor3 = trackColor }):Play()
	word.Text = if on then "ON" else "OFF"
	word.TextColor3 = if on then Theme.Color.Cream else Theme.Color.Muted
end

local function drawTiers()
	local tiers = Config.get("Graphics").Tiers
	for id, button in tierButtons do
		Components.setVariant(button, if id == current.graphics then "gold" else "ghost")
	end
	if blurb and tiers[current.graphics] then
		blurb.Text = tiers[current.graphics].Blurb
	end
	drawSwitch(true)
end

--============================================================================
-- Build
--============================================================================

local function caption(parent: Instance, text: string, order: number): TextLabel
	return Components.label({
		Name = "Caption" .. order,
		Text = Components.spaced(text),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "SettingsUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
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
		Size = UDim2.fromOffset(470, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = screen,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(330, 0)
	limit.MaxSize = Vector2.new(470, math.huge)
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
	Components.divider(root, 2)

	-- graphics
	caption(root, "GRAPHICS", 3)
	local row = Components.group({ Name = "Tiers", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 4, Parent = root })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	local cfg = Config.get("Graphics")
	for index, id in cfg.Order do
		local button = Components.button({
			Name = id,
			Text = cfg.Tiers[id].Label,
			Variant = "ghost",
			TextSize = 19,
			Size = UDim2.new(1 / #cfg.Order, -5, 1, 0),
			LayoutOrder = index,
			Parent = row,
		})
		button.Activated:Connect(function()
			if current.graphics == id then
				return
			end
			-- the quality carries its own shadows start (Low starts with them off)
			current.graphics = id
			current.shadows = cfg.Tiers[id].Shadows
			drawTiers()
			if onChange then
				onChange({ graphics = id })
			end
		end)
		tierButtons[id] = button
	end
	blurb = Components.label({
		Name = "Blurb",
		Text = "",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 5,
		Parent = root,
	})
	;(blurb :: TextLabel).TextYAlignment = Enum.TextYAlignment.Top
	Components.divider(root, 6)

	-- shadows
	local shadowRow = Components.group({ Name = "Shadows", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 7, Parent = root })
	local shadowLabel = caption(shadowRow, "SHADOWS", 1)
	shadowLabel.Size = UDim2.new(1, -(TRACK_W + 10), 1, 0)

	local switchButton = Instance.new("TextButton")
	switchButton.Name = "ShadowSwitch"
	switchButton.Text = ""
	switchButton.AutoButtonColor = false
	switchButton.AnchorPoint = Vector2.new(1, 0.5)
	switchButton.Position = UDim2.new(1, 0, 0.5, 0)
	switchButton.Size = UDim2.fromOffset(TRACK_W, TRACK_H)
	switchButton.BackgroundTransparency = 1
	switchButton.ZIndex = 4
	switchButton.Parent = shadowRow

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Theme.Color.GreenTop
	track.BorderSizePixel = 0
	track.ZIndex = 4
	track.Parent = switchButton
	Theme.corner(track, UDim.new(0.5, 0))
	Theme.goldStroke(track, 1.2)
	switchTrack = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.BackgroundColor3 = Theme.Color.Cream
	knob.BorderSizePixel = 0
	knob.ZIndex = 5
	knob.Parent = track
	Theme.corner(knob, UDim.new(0.5, 0))
	Theme.surface(knob, Theme.Color.Cream, Theme.Color.Parchment:Lerp(Theme.Color.Bronze, 0.35))
	switchKnob = knob

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromOffset(TRACK_W - KNOB - 6, TRACK_H)
	word.Position = UDim2.fromOffset(0, 0)
	word.TextSize = 12
	word.ZIndex = 5
	word.Text = "ON"
	word.Parent = track
	Theme.applyFont(word, Theme.Role.Strong)
	switchWord = word

	switchButton.Activated:Connect(function()
		current.shadows = not current.shadows
		drawSwitch(true)
		if onChange then
			onChange({ shadows = current.shadows })
		end
	end)

	shadowsCaption = Components.label({
		Name = "ShadowsCaption",
		Text = "Off keeps only the shadows of walls and roofs. The dark rooms stay exactly as dark for everyone.",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 8,
		Parent = root,
	})
	;(shadowsCaption :: TextLabel).TextYAlignment = Enum.TextYAlignment.Top
	Components.divider(root, 9)

	Components.label({
		Name = "Footer",
		Text = "This is only your own picture. It never changes what you can see in the castle.",
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Parchment,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 10,
		Parent = root,
	})

	drawTiers()
	drawSwitch(false)
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

-- Shows the choice the server has kept (or the one the device starts with).
function SettingsUI.setState(graphics: string, shadows: boolean)
	current.graphics = graphics
	current.shadows = shadows
	if gui then
		drawTiers()
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
