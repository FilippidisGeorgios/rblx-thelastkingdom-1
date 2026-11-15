--!strict
--[[
	HealthBar
	A small bar in the bottom-left corner of the screen: a fill that is green, yellow, orange or red according to how
	much health is left, and the percentage in small letters inside it (the developer, 2026-10-31). Its size is
	`configs/Hud.HealthBar`.

	2026-11-15 ("a much better, realistic UI: it looks fake now"): the same colours and the same number, but the bar
	is set in a riveted iron rim (Theme.ironPlate) and runs in a dark groove; the fill is shaded like a liquid in a
	glass (light at the top, dark at the foot) with marks at each quarter; a pale trail stays where the health was
	for a moment after a blow and then sinks to it, so a hit is SEEN; under a quarter of health the bar beats slowly.

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

local RIM = 3 -- the iron rim's width round the groove, in pixels
local TRAIL_WAIT = 0.35 -- how long the pale trail holds before it sinks
local LOW = 0.25 -- below this share of health the bar beats

function HealthBar.create(gui: ScreenGui): Handle
	local cfg = Config.get("Hud").HealthBar

	-- the groove the bar runs in
	local root = Instance.new("Frame")
	root.Name = "HealthBar"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, cfg.Margin, 1, -(cfg.MarginBottom or cfg.Margin))
	root.Size = UDim2.fromOffset(cfg.Width, cfg.Height)
	root.BackgroundColor3 = Theme.Iron.Trough
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.ZIndex = 2
	root.Parent = gui

	-- the iron rim round it: a sibling behind, a little larger, so the groove sits sunk in the plate
	local rim = Theme.ironPlate(gui, 6)
	rim.Name = "HealthRim"
	rim.AnchorPoint = Vector2.new(0, 1)
	rim.Position = root.Position + UDim2.fromOffset(-RIM, RIM)
	rim.Size = UDim2.fromOffset(cfg.Width + RIM * 2, cfg.Height + RIM * 2)
	rim.ZIndex = 1
	local rimEdge = Instance.new("UIStroke")
	rimEdge.Color = Color3.new(0, 0, 0)
	rimEdge.Thickness = 1
	rimEdge.Transparency = 0.3
	rimEdge.Parent = rim

	-- the groove's inner shadow: dark along its top edge, as if the rim overhangs it
	local inner = Instance.new("UIStroke")
	inner.Color = Color3.new(0, 0, 0)
	inner.Thickness = 1
	inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inner.Parent = root

	-- the pale trail: where the health was a moment ago
	local trail = Instance.new("Frame")
	trail.Name = "Trail"
	trail.Size = UDim2.fromScale(1, 1)
	trail.BackgroundColor3 = Color3.fromRGB(232, 222, 200)
	trail.BackgroundTransparency = 0.45
	trail.BorderSizePixel = 0
	trail.ZIndex = 3
	trail.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = cfg.Stops[1].Color
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = root
	Theme.barShade(fill)

	-- a thin light along the top of the fill: the bar is round, not a flat stripe
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromOffset(0, 1)
	shine.Size = UDim2.new(1, 0, 0, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Parent = fill

	-- a mark at each quarter, cut into the bar
	for i = 1, 3 do
		local mark = Instance.new("Frame")
		mark.Name = "Mark" .. i
		mark.AnchorPoint = Vector2.new(0.5, 0)
		mark.Position = UDim2.fromScale(i / 4, 0)
		mark.Size = UDim2.new(0, 1, 1, 0)
		mark.BackgroundColor3 = Color3.new(0, 0, 0)
		mark.BackgroundTransparency = 0.55
		mark.BorderSizePixel = 0
		mark.ZIndex = 6
		mark.Parent = root
	end

	-- the slow beat under a quarter of health
	local beat = Instance.new("Frame")
	beat.Name = "Beat"
	beat.Size = UDim2.fromScale(1, 1)
	beat.BackgroundColor3 = Color3.fromRGB(255, 70, 50)
	beat.BackgroundTransparency = 1
	beat.BorderSizePixel = 0
	beat.ZIndex = 6
	beat.Parent = root
	local beating: Tween? = nil

	local label = Instance.new("TextLabel")
	label.Name = "Percent"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "100%"
	label.TextSize = cfg.TextSize
	label.TextColor3 = Theme.Iron.Bone
	label.ZIndex = 7
	label.Parent = root
	Theme.applyFont(label, Theme.Role.Strong)
	local text = Instance.new("UIStroke")
	text.Color = Color3.new(0, 0, 0)
	text.Thickness = 1
	text.Transparency = 0.15
	text.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	text.Parent = label

	local handle = {} :: Handle
	local shown = 1
	local trailToken = 0

	function handle.set(health: number, maxHealth: number)
		local fraction = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
		TweenService:Create(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
		fill.BackgroundColor3 = HealthColor.of(fraction, cfg.Stops)
		label.Text = ("%d%%"):format(HealthColor.percent(health, maxHealth))

		trailToken += 1
		local mine = trailToken
		if fraction < shown then
			-- a blow: the trail holds where the health was, then sinks to it
			task.delay(TRAIL_WAIT, function()
				if trailToken == mine then
					TweenService:Create(trail, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(fraction, 1) }):Play()
				end
			end)
		else
			trail.Size = UDim2.fromScale(fraction, 1)
		end
		shown = fraction

		local low = fraction > 0 and fraction < LOW
		if low and not beating then
			beat.BackgroundTransparency = 1
			local tween = TweenService:Create(beat, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.72 })
			tween:Play()
			beating = tween
		elseif not low and beating then
			beating:Cancel()
			beating = nil
			beat.BackgroundTransparency = 1
		end
	end

	function handle.setVisible(on: boolean)
		root.Visible = on
		rim.Visible = on
	end

	function handle.destroy()
		if beating then
			beating:Cancel()
		end
		root:Destroy()
		rim:Destroy()
	end

	return handle
end

return HealthBar
