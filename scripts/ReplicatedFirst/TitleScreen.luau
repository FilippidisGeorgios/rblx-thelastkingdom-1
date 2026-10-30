--!strict
--[[
	TitleScreen
	The loading screen, and the first thing any player sees: a plain black screen, a castle in gold, the name
	under it, and a bar that fills as the world arrives. When the bar is full the screen fades away and the
	player is in. Nobody is asked to press anything; there is nothing to press until the game is ready.

	The bar is REAL. `scripts/ReplicatedFirst/Loading` feeds it from what is actually being loaded (the game, the
	pictures and meshes the world uses, the ground under the player's feet), so a slow connection shows a slow bar
	and a fast one a fast bar, and the player enters a world that is already drawn instead of watching it build.

	The castle is drawn from frames (nothing to upload, nothing that can fail to load): a keep with its flag and
	battlements, two towers with red roofs, the curtain wall between them, and a gate. Its flag waves and a
	window flickers, so the screen is never quite still.

	WHY THIS FILE REPEATS THE PALETTE instead of using Shared.UI.Theme: ReplicatedFirst replicates BEFORE
	everything else, which is what lets this appear on the first frame, so ReplicatedStorage may not exist yet
	when it runs. If the palette changes, change these too.

	Location: ReplicatedFirst.TitleScreen
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TitleScreen = {}

--==========================================================================
-- Tuning
--==========================================================================
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(198, 158, 66)
local GOLD_BRIGHT = Color3.fromRGB(242, 216, 142)
local GOLD_DIM = Color3.fromRGB(128, 96, 38)
local GOLD_DEEP = Color3.fromRGB(86, 64, 26)
local ROOF = Color3.fromRGB(156, 30, 48)
local ROOF_DARK = Color3.fromRGB(88, 14, 28)
local EMBER = Color3.fromRGB(255, 176, 84)
local MUTED = Color3.fromRGB(146, 130, 118)

local DISPLAY = "rbxasset://fonts/families/Fondamento.json"
local SERIF = "rbxasset://fonts/families/Merriweather.json"

-- The castle is drawn on a 100 x 90 grid, three pixels to a unit.
local GRID_W, GRID_H, UNIT = 100, 90, 3

local FADE_IN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT_SECONDS = 1.1

--==========================================================================
-- Helpers
--==========================================================================
local function font(target: TextLabel, family: string, weight: Enum.FontWeight)
	pcall(function()
		target.FontFace = Font.new(family, weight)
	end)
end

-- A block on the castle's grid, painted top to bottom (a little lighter above, so the stone has a face).
local function block(parent: Instance, x1: number, y1: number, x2: number, y2: number, top: Color3, bottom: Color3?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromScale(x1 / GRID_W, y1 / GRID_H)
	f.Size = UDim2.fromScale((x2 - x1) / GRID_W, (y2 - y1) / GRID_H)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = parent
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom or top)
	g.Rotation = 90
	g.Parent = f
	return f
end

-- A row of battlements: `count` blocks spread evenly from x1 to x2, standing on y2.
local function merlons(parent: Instance, x1: number, x2: number, y1: number, y2: number, count: number, top: Color3, bottom: Color3)
	local w = 3.6
	local step = ((x2 - x1) - w) / (count - 1)
	for k = 0, count - 1 do
		block(parent, x1 + step * k, y1, x1 + step * k + w, y2, top, bottom)
	end
end

--[[
	A pointed roof: a square turned on its corner and cut off at the base. Its apex is 90 degrees, so it is as
	tall as half its width. Cut by a clipping frame, which is why it is a frame and not a polygon.
]]
local function roof(parent: Instance, x1: number, x2: number, baseY: number)
	local width = (x2 - x1)
	local height = width / 2
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromScale(x1 / GRID_W, (baseY - height) / GRID_H)
	clip.Size = UDim2.fromScale(width / GRID_W, height / GRID_H)
	clip.Parent = parent

	local side = width * UNIT / math.sqrt(2)
	local tile = Instance.new("Frame")
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 1)
	tile.Size = UDim2.fromOffset(side, side)
	tile.Rotation = 45
	tile.BorderSizePixel = 0
	tile.BackgroundColor3 = ROOF
	tile.Parent = clip
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(ROOF, ROOF_DARK)
	g.Rotation = 90
	g.Parent = tile
end

-- A rounded-top slit or window, black, with an optional glow inside it.
local function slit(parent: Instance, x1: number, y1: number, x2: number, y2: number, glow: boolean): Frame?
	local f = block(parent, x1, y1, x2, y2, BLACK)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	if not glow then
		return nil
	end
	local lamp = block(parent, x1 + 0.35, y1 + (y2 - y1) * 0.35, x2 - 0.35, y2 - 0.4, EMBER)
	lamp.BackgroundTransparency = 0.2
	return lamp
end

--[[
	The castle. Returns what moves: the pennant and the lit windows.
]]
local function castle(parent: Instance): (Frame, { Frame })
	-- the wall between the towers is the furthest back, so the dimmest
	merlons(parent, 24, 76, 51, 56.5, 9, GOLD_DIM, GOLD_DEEP)
	block(parent, 24, 56, 76, 86, GOLD_DIM, GOLD_DEEP)

	-- the two towers
	for _, left in { true, false } do
		local x1 = if left then 6 else 74
		local x2 = x1 + 20
		block(parent, x1, 38, x2, 86, GOLD, GOLD_DIM)
		-- the tower is a touch wider at the top, where the roof sits on it
		block(parent, x1 - 1.2, 36.2, x2 + 1.2, 38.4, GOLD_BRIGHT, GOLD)
		roof(parent, x1 - 2.4, x2 + 2.4, 36.4)
		slit(parent, x1 + 9.3, 48, x1 + 10.7, 60, false)
		slit(parent, x1 + 8.8, 66, x1 + 11.2, 74, false)
	end

	-- the keep, the tallest thing, in the brightest gold
	merlons(parent, 35, 65, 20.5, 26.5, 6, GOLD_BRIGHT, GOLD)
	block(parent, 35, 26, 65, 86, GOLD_BRIGHT, GOLD)
	block(parent, 33.5, 25.2, 66.5, 27.6, GOLD_BRIGHT, GOLD)

	-- the flag
	block(parent, 49.3, 5, 50.7, 21, GOLD_BRIGHT, GOLD)
	local pennant = block(parent, 50.7, 5.4, 60.5, 11.4, ROOF, ROOF_DARK)

	-- the keep's windows; the two upper ones are lit from inside
	local lamps: { Frame } = {}
	for _, lamp in { slit(parent, 42.5, 33, 45.5, 47, true), slit(parent, 54.5, 33, 57.5, 47, true) } do
		if lamp then
			table.insert(lamps, lamp)
		end
	end
	slit(parent, 48.6, 52, 51.4, 60, false)

	-- the gate: an arch cut into the keep, with the portcullis showing through
	local arch = block(parent, 42, 64, 58, 82, BLACK)
	local archCorner = Instance.new("UICorner")
	archCorner.CornerRadius = UDim.new(0.5, 0)
	archCorner.Parent = arch
	block(parent, 42, 73, 58, 86, BLACK)
	for _, x in { 46.5, 50, 53.5 } do
		local bar = block(parent, x - 0.3, 68, x + 0.3, 86, GOLD_DEEP)
		bar.BackgroundTransparency = 0.25
	end
	for _, y in { 72, 78 } do
		local bar = block(parent, 43, y - 0.3, 57, y + 0.3, GOLD_DEEP)
		bar.BackgroundTransparency = 0.25
	end

	-- the ground
	block(parent, 0, 86, 100, 88.4, GOLD_DIM, GOLD_DEEP)

	return pennant, lamps
end

--==========================================================================
-- Show
--==========================================================================
export type Handle = {
	setProgress: (fraction: number) -> (),
	setStatus: (text: string) -> (),
	dismiss: () -> (),
}

function TitleScreen.show(): Handle
	local player = Players.LocalPlayer
	while not player do
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "TitleScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Plain black: not a blur of the world, not a colour wash. The world is drawn behind it in the meantime.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BLACK
	backdrop.BackgroundTransparency = 0
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	-- Everything else sits in a stage at the screen's centre, scaled to the screen (so a phone and a monitor see
	-- the same picture).
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(0, 0)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 2
	stage.Parent = gui
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	local function fitToScreen()
		local size = gui.AbsoluteSize
		-- the whole picture is about 560 high at full size; keep it inside the shorter side with room to spare
		stageScale.Scale = math.clamp(math.min(size.Y / 640, size.X / 520), 0.5, 1.5)
	end
	fitToScreen()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)

	--------------------------------------------------------------------------
	-- The castle
	--------------------------------------------------------------------------
	local emblem = Instance.new("CanvasGroup")
	emblem.Name = "Castle"
	emblem.AnchorPoint = Vector2.new(0.5, 0.5)
	emblem.Position = UDim2.new(0, 0, 0, -118)
	emblem.Size = UDim2.fromOffset(GRID_W * UNIT, GRID_H * UNIT)
	emblem.BackgroundTransparency = 1
	emblem.GroupTransparency = 1
	emblem.ZIndex = 3
	emblem.Parent = stage
	local pennant, lamps = castle(emblem)

	--------------------------------------------------------------------------
	-- The name
	--------------------------------------------------------------------------
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "THE LAST KINGDOM"
	title.TextSize = 56
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0, 0, 0, 62)
	title.Size = UDim2.fromOffset(760, 72)
	title.TextTransparency = 1
	title.ZIndex = 3
	font(title, DISPLAY, Enum.FontWeight.Bold)
	title.Parent = stage
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new(GOLD_BRIGHT, GOLD)
	titleGradient.Rotation = 90
	titleGradient.Parent = title

	-- a gold rule that draws itself out from the middle
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0.5, 0.5)
	rule.Position = UDim2.new(0, 0, 0, 108)
	rule.Size = UDim2.fromOffset(0, 2)
	rule.BackgroundColor3 = GOLD
	rule.BackgroundTransparency = 0.2
	rule.BorderSizePixel = 0
	rule.ZIndex = 3
	rule.Parent = stage

	--------------------------------------------------------------------------
	-- The bar
	--------------------------------------------------------------------------
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.new(0, 0, 0, 150)
	track.Size = UDim2.fromOffset(400, 8)
	track.BackgroundColor3 = Color3.fromRGB(22, 18, 10)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ZIndex = 3
	track.Parent = stage
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0.5, 0)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = GOLD_DIM
	trackStroke.Thickness = 1.2
	trackStroke.Transparency = 1
	trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	-- a glint that runs along the gold all the time the bar is on screen
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.5, GOLD_BRIGHT),
		ColorSequenceKeypoint.new(1, GOLD),
	})
	fillGradient.Offset = Vector2.new(-1, 0)
	fillGradient.Parent = fill

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Text = ""
	status.TextSize = 16
	status.TextColor3 = MUTED
	status.BackgroundTransparency = 1
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.new(0, 0, 0, 182)
	status.Size = UDim2.fromOffset(500, 24)
	status.TextTransparency = 1
	status.ZIndex = 3
	font(status, SERIF, Enum.FontWeight.Regular)
	status.Parent = stage

	--------------------------------------------------------------------------
	-- Staging: the castle, then the name, then the bar
	--------------------------------------------------------------------------
	TweenService:Create(emblem, FADE_IN, { GroupTransparency = 0 }):Play()
	task.delay(0.5, function()
		TweenService:Create(title, FADE_IN, { TextTransparency = 0 }):Play()
		TweenService:Create(rule, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(380, 2) }):Play()
	end)
	task.delay(1.0, function()
		TweenService:Create(track, FADE_IN, { BackgroundTransparency = 0.25 }):Play()
		TweenService:Create(trackStroke, FADE_IN, { Transparency = 0.2 }):Play()
		TweenService:Create(status, FADE_IN, { TextTransparency = 0.15 }):Play()
	end)

	-- the flag waves, a window flickers, the glint runs: forever, until the screen goes
	local pennantHome = pennant.Size
	TweenService:Create(pennant, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.fromScale(pennantHome.X.Scale * 0.74, pennantHome.Y.Scale),
	}):Play()
	for index, lamp in lamps do
		TweenService:Create(lamp, TweenInfo.new(0.35 + 0.17 * index, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundTransparency = 0.6,
		}):Play()
	end
	TweenService:Create(fillGradient, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false), {
		Offset = Vector2.new(1, 0),
	}):Play()

	--------------------------------------------------------------------------
	-- Handle
	--------------------------------------------------------------------------
	local dismissed = false

	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true

		local out = TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(backdrop, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(emblem, out, { GroupTransparency = 1 }):Play()
		TweenService:Create(title, out, { TextTransparency = 1 }):Play()
		TweenService:Create(rule, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(track, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(trackStroke, out, { Transparency = 1 }):Play()
		TweenService:Create(fill, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(status, out, { TextTransparency = 1 }):Play()

		task.delay(FADE_OUT_SECONDS + 0.2, function()
			gui:Destroy()
		end)
	end

	return {
		setProgress = function(fraction: number)
			if dismissed then
				return
			end
			TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			}):Play()
		end,
		setStatus = function(text: string)
			status.Text = text
		end,
		dismiss = dismiss,
	}
end

return TitleScreen
