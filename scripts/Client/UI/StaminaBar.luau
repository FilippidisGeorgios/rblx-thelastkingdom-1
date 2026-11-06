--!strict
--[[
	StaminaBar
	The blue bar right under the health bar (configs/Movement.Bar, configs/Hud.HealthBar): as wide as it, thinner, no
	words. It empties while Shift runs and drops a quarter at each roll; when it holds less than one roll it turns a
	darker blue, so the player sees that Q will not answer.

	Presentation only: Controllers/MovementController tells it the numbers.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.StaminaBar
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local StaminaBar = {}

export type Handle = {
	set: (value: number, max: number, rollCost: number) -> (),
	setVisible: (on: boolean) -> (),
	destroy: () -> (),
}

function StaminaBar.create(gui: ScreenGui): Handle
	local hud = Config.get("Hud").HealthBar
	local cfg = Config.get("Movement").Bar

	local root = Instance.new("Frame")
	root.Name = "StaminaBar"
	root.AnchorPoint = Vector2.new(0, 1)
	-- right under the health bar: its bottom edge, a small gap, then this bar
	root.Position = UDim2.new(0, hud.Margin, 1, -((hud.MarginBottom or hud.Margin) - cfg.Gap - cfg.Height))
	root.Size = UDim2.fromOffset(hud.Width, cfg.Height)
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
	fill.BackgroundColor3 = cfg.Color
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = root

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.fromScale(1, 0.4)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.8
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = fill

	local handle = {} :: Handle
	local last = -1

	function handle.set(value: number, max: number, rollCost: number)
		local fraction = if max > 0 then math.clamp(value / max, 0, 1) else 0
		if math.abs(fraction - last) < 1e-4 then
			return
		end
		last = fraction
		-- the server sends ten numbers a second: ease between them so the bar slides, never steps
		TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(fraction, 1) }):Play()
		fill.BackgroundColor3 = if value + 1e-6 < rollCost then cfg.ColorLow else cfg.Color
	end

	function handle.setVisible(on: boolean)
		root.Visible = on
	end

	function handle.destroy()
		root:Destroy()
	end

	return handle
end

return StaminaBar
