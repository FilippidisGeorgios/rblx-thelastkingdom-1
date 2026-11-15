--!strict
--[[
	StaminaBar
	The blue bar right under the health bar (configs/Movement.Bar, configs/Hud.HealthBar): as wide as it, thinner, no
	words. It empties while Shift runs and drops a quarter at each roll; when it holds less than one roll it turns a
	darker blue, so the player sees that Q will not answer.

	2026-11-15: set in the same riveted iron rim as the health bar and shaded the same way (Theme.barShade), with a
	mark where one roll's worth ends, so the blue reads as a gauge and not as a flat stripe.

	Presentation only: Controllers/MovementController tells it the numbers.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.StaminaBar
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local StaminaBar = {}

export type Handle = {
	set: (value: number, max: number, rollCost: number) -> (),
	setVisible: (on: boolean) -> (),
	destroy: () -> (),
}

local RIM = 3

function StaminaBar.create(gui: ScreenGui): Handle
	local hud = Config.get("Hud").HealthBar
	local cfg = Config.get("Movement").Bar

	local root = Instance.new("Frame")
	root.Name = "StaminaBar"
	root.AnchorPoint = Vector2.new(0, 1)
	-- right under the health bar: its bottom edge, a gap as wide as the two rims, then this bar
	local gap = math.max(cfg.Gap, RIM * 2)
	root.Position = UDim2.new(0, hud.Margin, 1, -((hud.MarginBottom or hud.Margin) - gap - cfg.Height))
	root.Size = UDim2.fromOffset(hud.Width, cfg.Height)
	root.BackgroundColor3 = Theme.Iron.Trough
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.ZIndex = 2
	root.Parent = gui

	local rim = Theme.ironPlate(gui, 5)
	rim.Name = "StaminaRim"
	rim.AnchorPoint = Vector2.new(0, 1)
	rim.Position = root.Position + UDim2.fromOffset(-RIM, RIM)
	rim.Size = UDim2.fromOffset(hud.Width + RIM * 2, cfg.Height + RIM * 2)
	rim.ZIndex = 1
	local rimEdge = Instance.new("UIStroke")
	rimEdge.Color = Color3.new(0, 0, 0)
	rimEdge.Thickness = 1
	rimEdge.Transparency = 0.3
	rimEdge.Parent = rim

	local inner = Instance.new("UIStroke")
	inner.Color = Color3.new(0, 0, 0)
	inner.Thickness = 1
	inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inner.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = cfg.Color
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	fill.Parent = root
	Theme.barShade(fill)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, 0, 0, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	shine.Parent = fill

	-- where one roll's worth ends (placed on the first `set`, when the cost is known)
	local rollMark = Instance.new("Frame")
	rollMark.Name = "RollMark"
	rollMark.AnchorPoint = Vector2.new(0.5, 0)
	rollMark.Size = UDim2.new(0, 1, 1, 0)
	rollMark.BackgroundColor3 = Color3.new(0, 0, 0)
	rollMark.BackgroundTransparency = 0.45
	rollMark.BorderSizePixel = 0
	rollMark.Visible = false
	rollMark.ZIndex = 5
	rollMark.Parent = root

	local handle = {} :: Handle
	local last = -1

	function handle.set(value: number, max: number, rollCost: number)
		if max > 0 and rollCost > 0 and rollCost < max then
			rollMark.Position = UDim2.fromScale(rollCost / max, 0)
			rollMark.Visible = true
		end
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
		rim.Visible = on
	end

	function handle.destroy()
		root:Destroy()
		rim:Destroy()
	end

	return handle
end

return StaminaBar
