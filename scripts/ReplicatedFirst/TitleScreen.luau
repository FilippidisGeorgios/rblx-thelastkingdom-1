--!strict
--[[
	TitleScreen
	The loading screen, the first thing any player sees (2026-11-14, the developer: "much more realistic, more
	pictures, more frightening; THE LAST KINGDOM in even bigger letters; under it, smaller, Waiting for players and how
	many of how many; under that, smaller still, an hourglass with Starting in and the seconds; then the assets, smaller;
	then the rest, smaller still").

	THE PICTURE (drawn from frames: nothing to upload, nothing that can fail on a slow connection):
	  a night sky that bleeds red toward the horizon, a blood moon with its glow, the black silhouette of a ruined
	  fortress (a great keep with a spire, broken towers, gaps in the battlements, windows where a fire still burns and
	  flickers), fog sliding across its feet, crows crossing the moon now and then, embers rising, and once in a while
	  a flash of lightning that shows the walls for a moment. The whole picture breathes in very slowly.

	THE WORDS, top to bottom, each smaller than the one above:
	  THE LAST KINGDOM                       (gold, the biggest)
	  Waiting for players...   2 / 4          (the dots walk; the count is of players who have LOADED, of the party)
	  [hourglass] Starting in 23              (a count down; the hourglass turns)
	  Assets  63%  [a thin bar]              (what this player has fetched)
	  Raising the walls...                    (what is being done)
	In the lobby there is no party to wait for: the first line says "Loading", the hourglass is hidden.

	WHY THIS FILE REPEATS THE PALETTE instead of using Shared.UI.Theme: ReplicatedFirst replicates BEFORE everything
	else, which is what lets this appear on the first frame, so ReplicatedStorage may not exist yet when it runs.

	Location: ReplicatedFirst.TitleScreen (used by ReplicatedFirst.Loading)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TitleScreen = {}

--==========================================================================
-- Palette and type
--==========================================================================
local BLACK = Color3.new(0, 0, 0)
local SKY_TOP = Color3.fromRGB(6, 5, 9)
local SKY_LOW = Color3.fromRGB(58, 12, 14)
local MOON = Color3.fromRGB(170, 36, 28)
local MOON_CORE = Color3.fromRGB(214, 80, 52)
local STONE = Color3.fromRGB(5, 4, 6)
local FIRE = Color3.fromRGB(255, 148, 60)
local GOLD = Color3.fromRGB(210, 168, 74)
local GOLD_DIM = Color3.fromRGB(120, 86, 34)
local BONE = Color3.fromRGB(214, 202, 182)
local MUTED = Color3.fromRGB(150, 132, 118)
local BLOOD = Color3.fromRGB(120, 20, 22)

local DISPLAY = "rbxasset://fonts/families/Fondamento.json"
local SERIF = "rbxasset://fonts/families/Merriweather.json"

local FADE_OUT_SECONDS = 1.3

--==========================================================================
-- Helpers
--==========================================================================
local function font(target: TextLabel, family: string, weight: Enum.FontWeight, style: Enum.FontStyle?)
	pcall(function()
		target.FontFace = Font.new(family, weight, style or Enum.FontStyle.Normal)
	end)
end

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3, transparency: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function round(f: GuiObject, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = f
end

local function gradient(f: GuiObject, colors: ColorSequence?, transparency: NumberSequence?, rotation: number?)
	local g = Instance.new("UIGradient")
	if colors then
		g.Color = colors
	end
	if transparency then
		g.Transparency = transparency
	end
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

local function label(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, color: Color3, family: string, weight: Enum.FontWeight, z: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.ZIndex = z or 10
	font(l, family, weight)
	l.Parent = parent
	return l
end

--==========================================================================
-- The fortress: a silhouette on a 200 x 100 grid (x left to right, y up from the ground), scaled to its frame
--==========================================================================
local GW, GH = 200, 100

local function rect(parent: Instance, x1: number, y1: number, x2: number, y2: number, color: Color3?, z: number?): Frame
	return frame(parent, "Stone", UDim2.fromScale(x1 / GW, 1 - y2 / GH), UDim2.fromScale((x2 - x1) / GW, (y2 - y1) / GH), color or STONE, 0, z or 3)
end

-- a spire or a roof: narrowing steps, so many and so thin that the edge reads as a slope
local function spire(parent: Instance, cx: number, baseY: number, halfW: number, height: number)
	local steps = math.max(6, math.floor(height * 1.2))
	for k = 0, steps - 1 do
		local w = halfW * (1 - k / steps)
		local y0 = baseY + height * k / steps
		rect(parent, cx - w, y0, cx + w, y0 + height / steps + 0.05)
	end
end

local function battlements(parent: Instance, x1: number, x2: number, y: number, gaps: { number })
	local n = math.floor((x2 - x1) / 3)
	for i = 0, n - 1 do
		if not table.find(gaps, i) and i % 2 == 0 then
			rect(parent, x1 + i * 3, y, x1 + i * 3 + 2.2, y + 2.6)
		end
	end
end

local windows: { Frame } = {}

local function window(parent: Instance, x: number, y: number, lit: boolean)
	local w = rect(parent, x, y, x + 1.1, y + 2.6, if lit then FIRE else Color3.fromRGB(14, 10, 10), 4)
	if lit then
		table.insert(windows, w)
	end
end

local function fortress(parent: Instance): Frame
	local f = frame(parent, "Fortress", UDim2.fromScale(0.5, 1), UDim2.fromScale(0.92, 0.5), STONE, 1, 3)
	f.AnchorPoint = Vector2.new(0.5, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = GW / GH * 1.0
	aspect.Parent = f
	-- the ground and the hill it stands on
	rect(f, 0, 0, 200, 9)
	rect(f, 30, 9, 170, 14)
	-- the curtain wall, broken in two places
	rect(f, 22, 14, 70, 34)
	rect(f, 76, 14, 124, 30)
	rect(f, 131, 14, 178, 36)
	battlements(f, 22, 70, 34, { 3, 4, 9 })
	battlements(f, 131, 178, 36, { 6, 7 })
	rect(f, 70, 14, 76, 22) -- rubble in the first gap
	rect(f, 124, 14, 131, 18)
	-- the gate, black, an arch of fire behind it
	rect(f, 92, 14, 108, 27, Color3.fromRGB(2, 1, 2), 4)
	-- the left tower, broken off, its top jagged
	rect(f, 14, 14, 30, 56)
	rect(f, 14, 56, 18, 61)
	rect(f, 20, 56, 23, 59)
	rect(f, 25, 56, 30, 63)
	window(f, 21, 44, true)
	window(f, 21, 31, false)
	-- the right tower, whole, with a cone roof
	rect(f, 168, 14, 184, 60)
	battlements(f, 166, 186, 60, {})
	spire(f, 176, 62.6, 9, 16)
	window(f, 175, 48, true)
	window(f, 175, 36, false)
	-- the great keep, tall, with its spire and two turrets
	rect(f, 82, 30, 118, 78)
	battlements(f, 80, 120, 78, { 2 })
	rect(f, 78, 64, 84, 86)
	rect(f, 116, 64, 122, 86)
	spire(f, 81, 86, 4.5, 10)
	spire(f, 119, 86, 4.5, 10)
	rect(f, 94, 78, 106, 92)
	spire(f, 100, 92, 9, 20)
	rect(f, 99.6, 111, 100.4, 116) -- the spire's broken finial
	for i, x in { 88, 94, 105, 111 } do
		window(f, x, 64, i % 2 == 1)
		window(f, x, 50, i == 3)
	end
	window(f, 99.4, 84, true)
	-- inner towers peering over the wall
	rect(f, 44, 30, 54, 48)
	battlements(f, 43, 55, 48, { 1 })
	window(f, 48.4, 39, true)
	rect(f, 146, 30, 156, 52)
	spire(f, 151, 52, 6, 12)
	window(f, 150.4, 42, false)
	return f
end

--==========================================================================
export type Gate = { state: string?, ready: number?, expected: number?, endsAt: number? }

export type Handle = {
	setProgress: (fraction: number) -> (),
	setStatus: (text: string) -> (),
	setGate: (gate: Gate?) -> (),
	dismiss: () -> (),
}

function TitleScreen.show(): Handle
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "TLK_TitleScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("TLK_NoMouse", true)
	gui.Parent = playerGui

	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BLACK
	root.BorderSizePixel = 0
	root.Parent = gui

	-- the sky: black above, a bleeding red toward the horizon
	local sky = frame(root, "Sky", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 0, 1)
	gradient(sky, ColorSequence.new({
		ColorSequenceKeypoint.new(0, SKY_TOP),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 6, 10)),
		ColorSequenceKeypoint.new(0.86, SKY_LOW),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 6, 8)),
	}), nil, 90)

	-- the picture drifts in very slowly (a frame larger than the screen, eased toward the middle)
	local scene = frame(root, "Scene", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.08, 1.08), BLACK, 1, 2)
	scene.AnchorPoint = Vector2.new(0.5, 0.5)

	-- the blood moon and its glow
	local moonHolder = frame(scene, "Moon", UDim2.fromScale(0.68, 0.2), UDim2.fromScale(0.16, 0.16), BLACK, 1, 2)
	moonHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	local moonAspect = Instance.new("UIAspectRatioConstraint")
	moonAspect.Parent = moonHolder
	for i, s in { 2.4, 1.7, 1.25 } do
		local glow = frame(moonHolder, "Glow" .. i, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(s, s), MOON, 0.86 + i * 0.02, 2)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		round(glow)
	end
	local moon = frame(moonHolder, "Disc", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), MOON, 0, 2)
	moon.AnchorPoint = Vector2.new(0.5, 0.5)
	round(moon)
	gradient(moon, ColorSequence.new(MOON_CORE, Color3.fromRGB(110, 18, 16)), nil, 135)
	-- the moon's dark seas
	for _, sea in { { 0.35, 0.4, 0.22 }, { 0.62, 0.58, 0.16 }, { 0.48, 0.72, 0.12 } } do
		local s = frame(moon, "Sea", UDim2.fromScale(sea[1], sea[2]), UDim2.fromScale(sea[3], sea[3]), Color3.fromRGB(90, 14, 12), 0.45, 2)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		round(s)
	end

	-- the lightning: the whole sky goes pale for a moment
	local flash = frame(root, "Lightning", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(190, 200, 230), 1, 6)

	-- the fortress
	table.clear(windows)
	local fort = fortress(scene)

	-- fog at its feet, two layers sliding against each other
	local fogs: { Frame } = {}
	for i = 1, 2 do
		local fog = frame(scene, "Fog" .. i, UDim2.fromScale(-0.2, 0.74 + 0.06 * i), UDim2.fromScale(1.4, 0.2), Color3.fromRGB(70, 62, 66), 0, 5)
		gradient(fog, nil, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.82 - 0.05 * i),
			NumberSequenceKeypoint.new(0.6, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		}), 0)
		table.insert(fogs, fog)
	end

	-- the vignette: the edges of the picture sink into black
	local vignette = frame(root, "Vignette", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), BLACK, 0, 7)
	gradient(vignette, nil, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.25, 0.75),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	}), 0)
	local vignette2 = frame(root, "VignetteV", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), BLACK, 0, 7)
	gradient(vignette2, nil, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.3, 0.92),
		NumberSequenceKeypoint.new(0.62, 0.9),
		NumberSequenceKeypoint.new(1, 0.05),
	}), 90)

	-- embers rising
	local embers: { Frame } = {}
	for i = 1, 16 do
		local e = frame(root, "Ember", UDim2.fromScale(math.random(), 1.02), UDim2.fromOffset(3, 3), FIRE, 0.2, 8)
		round(e)
		table.insert(embers, e)
	end

	-- crows
	local crows: { Frame } = {}
	for i = 1, 3 do
		local c = frame(root, "Crow", UDim2.fromScale(-0.1, 0.16 + 0.04 * i), UDim2.fromOffset(18, 8), BLACK, 1, 4)
		for s = -1, 1, 2 do
			local wing = frame(c, "Wing", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(10, 2), Color3.fromRGB(4, 3, 4), 0, 4)
			wing.AnchorPoint = Vector2.new(if s < 0 then 1 else 0, 0.5)
			wing.Rotation = s * -22
		end
		table.insert(crows, c)
	end

	--------------------------------------------------------------------------
	-- The words
	--------------------------------------------------------------------------
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(1, 1)
	words.ZIndex = 10
	words.Parent = root

	-- THE LAST KINGDOM: the biggest; a red glow behind it, a dark edge
	local titleGlow = label(words, "TitleGlow", "THE LAST KINGDOM", UDim2.fromScale(0.5, 0.115), UDim2.fromScale(0.82, 0.135), BLOOD, DISPLAY, Enum.FontWeight.Bold, 9)
	titleGlow.TextTransparency = 0.55
	local title = label(words, "Title", "THE LAST KINGDOM", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.8, 0.13), GOLD, DISPLAY, Enum.FontWeight.Bold, 11)
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(26, 10, 6)
	titleStroke.Thickness = 2.5
	titleStroke.Parent = title
	local rule = frame(words, "Rule", UDim2.fromScale(0.5, 0.262), UDim2.fromScale(0.34, 0.0025), GOLD_DIM, 0.1, 11)
	rule.AnchorPoint = Vector2.new(0.5, 0)
	gradient(rule, nil, NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), 0)

	-- the block of lines at the bottom
	local waiting = label(words, "Waiting", "Waiting for players", UDim2.fromScale(0.5, 0.745), UDim2.fromScale(0.6, 0.038), BONE, SERIF, Enum.FontWeight.Regular)
	local hourglassHolder = Instance.new("Frame")
	hourglassHolder.Name = "Countdown"
	hourglassHolder.BackgroundTransparency = 1
	hourglassHolder.AnchorPoint = Vector2.new(0.5, 0)
	hourglassHolder.Position = UDim2.fromScale(0.5, 0.795)
	hourglassHolder.Size = UDim2.fromScale(0.4, 0.03)
	hourglassHolder.ZIndex = 10
	hourglassHolder.Parent = words
	local hourglass = label(hourglassHolder, "Hourglass", "\u{231B}", UDim2.fromScale(0.3, 0), UDim2.fromScale(0.06, 1), GOLD, SERIF, Enum.FontWeight.Regular)
	local countdown = label(hourglassHolder, "Starting", "Starting in 30", UDim2.fromScale(0.56, 0), UDim2.fromScale(0.5, 1), MUTED, SERIF, Enum.FontWeight.Regular)
	countdown.TextXAlignment = Enum.TextXAlignment.Left
	countdown.AnchorPoint = Vector2.new(0.5, 0)

	local assetsLine = label(words, "Assets", "Assets  0%", UDim2.fromScale(0.5, 0.84), UDim2.fromScale(0.3, 0.024), MUTED, SERIF, Enum.FontWeight.Regular)
	local track = frame(words, "Track", UDim2.fromScale(0.5, 0.869), UDim2.fromScale(0.24, 0.004), Color3.fromRGB(30, 22, 18), 0, 10)
	track.AnchorPoint = Vector2.new(0.5, 0)
	local fill = frame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), BLOOD, 0, 11)
	gradient(fill, ColorSequence.new(BLOOD, Color3.fromRGB(196, 70, 40)), nil, 0)
	local status = label(words, "Status", "", UDim2.fromScale(0.5, 0.888), UDim2.fromScale(0.4, 0.019), Color3.fromRGB(110, 98, 90), SERIF, Enum.FontWeight.Light)

	--------------------------------------------------------------------------
	-- The life of it
	--------------------------------------------------------------------------
	root.GroupTransparency = 1
	TweenService:Create(root, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	TweenService:Create(scene, TweenInfo.new(40, Enum.EasingStyle.Sine), { Size = UDim2.fromScale(1.0, 1.0) }):Play()
	for i, fog in fogs do
		TweenService:Create(fog, TweenInfo.new(18 + i * 7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = UDim2.fromScale(if i == 1 then 0 else -0.35, fog.Position.Y.Scale),
		}):Play()
	end
	TweenService:Create(moonHolder, TweenInfo.new(60, Enum.EasingStyle.Linear), { Position = UDim2.fromScale(0.64, 0.17) }):Play()

	local dismissed = false
	local dotsAt = 0
	local dots = 0
	local gate: Gate? = nil
	local nextFlash = os.clock() + 4 + math.random() * 5
	local nextCrow = os.clock() + 1.5
	local emberState: { { at: number, speed: number, drift: number } } = {}
	for i = 1, #embers do
		emberState[i] = { at = os.clock() - math.random() * 6, speed = 0.06 + math.random() * 0.06, drift = (math.random() - 0.5) * 0.08 }
	end
	local baseX: { number } = {}
	for i, e in embers do
		baseX[i] = e.Position.X.Scale
	end

	local function wordsFor()
		local g = gate
		if not g or g.state == nil then
			waiting.Text = "Loading" .. string.rep(".", dots)
			hourglassHolder.Visible = false
			return
		end
		if g.state == "starting" or g.state == "open" then
			waiting.Text = "The gates open"
			hourglassHolder.Visible = false
			return
		end
		local count = if g.expected and g.expected > 0 then ("   %d / %d"):format(g.ready or 0, g.expected) else ""
		waiting.Text = "Waiting for players" .. string.rep(".", dots) .. string.rep(" ", 3 - dots) .. count
		hourglassHolder.Visible = true
		local left = if g.endsAt then math.max(0, math.ceil(g.endsAt - Workspace:GetServerTimeNow())) else 0
		countdown.Text = ("Starting in %d"):format(left)
	end

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if dismissed then
			return
		end
		local now = os.clock()
		if now - dotsAt > 0.45 then
			dotsAt = now
			dots = (dots + 1) % 4
			wordsFor()
		end
		-- the hourglass turns over once a second
		hourglass.Rotation = (math.floor(now) % 2) * 180 + math.clamp((now % 1) * 4, 0, 1) * 180 - 180
		-- the title breathes, a fire flickers in the windows
		titleGlow.TextTransparency = 0.5 + 0.12 * math.sin(now * 1.3)
		for i, w in windows do
			w.BackgroundTransparency = 0.05 + 0.35 * math.abs(math.sin(now * (3 + i * 0.7) + i)) * (0.5 + 0.5 * math.sin(now * 0.9 + i))
		end
		-- embers
		for i, e in embers do
			local s = emberState[i]
			local t = (now - s.at) * s.speed
			if t > 1.15 then
				s.at = now
				baseX[i] = math.random()
				t = 0
			end
			e.Position = UDim2.fromScale(baseX[i] + s.drift * t + 0.01 * math.sin(now * 2 + i), 1.02 - t)
			e.BackgroundTransparency = 0.15 + 0.85 * t
		end
		-- lightning
		if now >= nextFlash then
			nextFlash = now + 6 + math.random() * 9
			flash.BackgroundTransparency = 0.55
			TweenService:Create(flash, TweenInfo.new(0.09), { BackgroundTransparency = 0.95 }):Play()
			task.delay(0.13, function()
				flash.BackgroundTransparency = 0.7
				TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			end)
		end
		-- crows cross the moon now and then
		if now >= nextCrow then
			nextCrow = now + 7 + math.random() * 6
			for i, c in crows do
				local y = 0.1 + 0.07 * i + (math.random() - 0.5) * 0.04
				c.Position = UDim2.fromScale(-0.08 - 0.05 * i, y)
				TweenService:Create(c, TweenInfo.new(9 + i * 1.5, Enum.EasingStyle.Linear), { Position = UDim2.fromScale(1.1, y - 0.06) }):Play()
			end
		end
		for i, c in crows do
			for _, wing in c:GetChildren() do
				if wing:IsA("Frame") then
					local s = if wing.AnchorPoint.X > 0.5 then 1 else -1
					wing.Rotation = s * (-22 + 26 * math.sin(now * 9 + i))
				end
			end
		end
	end)
	wordsFor()
	assetsLine.Text = "Assets  0%"

	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true
		TweenService:Create(root, TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
		task.delay(FADE_OUT_SECONDS + 0.2, function()
			conn:Disconnect()
			gui:Destroy()
		end)
	end

	return {
		setProgress = function(fraction: number)
			if dismissed then
				return
			end
			local f = math.clamp(fraction, 0, 1)
			assetsLine.Text = ("Assets  %d%%"):format(math.floor(f * 100 + 0.5))
			TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(f, 1) }):Play()
		end,
		setStatus = function(text: string)
			status.Text = text
		end,
		setGate = function(g: Gate?)
			gate = g
			wordsFor()
		end,
		dismiss = dismiss,
	}
end

return TitleScreen
