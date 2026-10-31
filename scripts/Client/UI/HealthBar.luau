--!strict
--[[
	HealthBar
	A tiny bar in the bottom-left corner of the screen: a black outline, a fill that is green, yellow, orange or red
	according to how much health is left, and the percentage in very small letters inside it. It is meant to be
	almost not there (`configs/Hud.HealthBar`: 92 by 11 pixels).

	Presentation only: `Controllers/HealthController` tells it the numbers.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.HealthBar
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HealthColor = require(ReplicatedStorage.Shared.HealthColor)
local Theme = require(script.Parent.Theme)

local HealthBar = {}

export type Handle = {
	set: (health: number, maxHealth: number) -> (),
	setVisible: (on: boolean) -> (),
	destroy: () -> (),
}

function HealthBar.create(gui: ScreenGui): Handle
	local cfg = Config.get("Hud").HealthBar

	local root = Instance.new("Frame")
	root.Name = "HealthBar"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, cfg.Margin, 1, -cfg.Margin)
	root.Size = UDim2.fromOffset(cfg.Width, cfg.Height)
	root.BackgroundColor3 = Color3.fromRGB(14, 12, 12)
	root.BackgroundTransparency = 0.25
	root.BorderSizePixel = 0
	root.Parent = gui

	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Thickness = 1.5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = cfg.Stops[1].Color
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = root

	-- a very small shine along the top of the fill, so it reads as a bar and not as a flat stripe
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.fromScale(1, 0.4)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Percent"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "100%"
	label.TextSize = cfg.TextSize
	label.TextColor3 = Theme.Color.Cream
	label.ZIndex = 4
	label.Parent = root
	Theme.applyFont(label, Theme.Role.Strong)
	local text = Instance.new("UIStroke")
	text.Color = Color3.new(0, 0, 0)
	text.Thickness = 0.8
	text.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	text.Parent = label

	local handle = {} :: Handle

	function handle.set(health: number, maxHealth: number)
		local fraction = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
		TweenService:Create(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
		fill.BackgroundColor3 = HealthColor.of(fraction, cfg.Stops)
		label.Text = ("%d%%"):format(HealthColor.percent(health, maxHealth))
	end

	function handle.setVisible(on: boolean)
		root.Visible = on
	end

	function handle.destroy()
		root:Destroy()
	end

	return handle
end

return HealthBar
