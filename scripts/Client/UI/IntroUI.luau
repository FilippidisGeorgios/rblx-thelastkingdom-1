--!strict
--[[
	IntroUI
	What the screen looks like while the arrival scene plays: black bars top and bottom, a title card over black,
	and the dialogue box: the speaker's face on the left, their name on a small gold plate, and what they say,
	typed out. In the bottom bar, on the right, the SKIP button, which has to be HELD.

	THE SKIP BUTTON says only SKIP, in bold cream letters on a small golden-brown plate with a thin gold edge. A tap
	does nothing: the player presses and keeps pressing for `holdSeconds` (3) while a gold fill rises in it; let go
	early and it empties again. Only when it is full does the button say "skip" to the controller, and the controller
	sends the vote. In a party the skip needs a majority (the server counts), and small dots under the plate show
	how many of the votes needed have been given. For the first two seconds it is fully visible, then it fades to
	40% so as not to trouble the scene, and is full again while it is held.

	Built for a phone first. Every size is a share of the screen, and the text size is worked out from the
	screen's height (and redone if it turns), so the box reads the same on a 5-inch phone held sideways and on a
	monitor. The skip plate is only as big as its word (the letters 17 to 25 px, a thin margin round them).

	2026-11-15 (the developer: "a much nicer intro, the buttons, the animation"): the title is gold struck in metal
	between two rules that draw themselves out, over embers rising slowly out of the dark; the dialogue box is the pack's
	page of oiled leather (Theme.leatherPage), the name on an iron plate, the face in an iron frame, and the box rises
	into place and fades away instead of blinking; SKIP is an iron plate with the gold edge and the gold fill; a gold
	hairline runs along the inner edge of each black bar.

	Owns no logic: IntroController says what to show and when.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IntroUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local IntroUI = {}

export type Handle = {
	black: (alpha: number, seconds: number) -> (),
	letterbox: (on: boolean, seconds: number) -> (),
	title: (text: string, sub: string, seconds: number) -> (),
	say: (name: string, text: string, charactersPerSecond: number, portrait: string?) -> (),
	clearLine: () -> (),
	setVotes: (votes: number, needed: number, mine: boolean) -> (),
	onSkip: (fn: () -> ()) -> (),
	destroy: () -> (),
}

local BAR = 0.11 -- each letterbox bar, as a share of the screen height

local function ease(seconds: number): TweenInfo
	return TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function label(parent: Instance, name: string, role: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.TextWrapped = true
	l.RichText = false
	Theme.applyFont(l, role)
	l.Parent = parent
	return l
end

-- holdSeconds: how long SKIP has to be held (Intro.SkipHoldSeconds).
function IntroUI.create(holdSeconds: number): Handle
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Black, under everything else in this gui: fades to and from it.
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 0
	fade.BorderSizePixel = 0
	fade.ZIndex = 1
	fade.Parent = gui

	-- The bars start off-screen and slide in.
	local top = Instance.new("Frame")
	top.Name = "BarTop"
	top.AnchorPoint = Vector2.new(0, 1)
	top.Position = UDim2.fromScale(0, 0)
	top.Size = UDim2.fromScale(1, BAR)
	top.BackgroundColor3 = Color3.new(0, 0, 0)
	top.BorderSizePixel = 0
	top.ZIndex = 2
	top.Parent = gui

	local bottom = Instance.new("Frame")
	bottom.Name = "BarBottom"
	bottom.AnchorPoint = Vector2.new(0, 0)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.fromScale(1, BAR)
	bottom.BackgroundColor3 = Color3.new(0, 0, 0)
	bottom.BorderSizePixel = 0
	bottom.ZIndex = 2
	bottom.Parent = gui
	for _, bar in { top, bottom } do
		local hair = Instance.new("Frame")
		hair.Name = "Hairline"
		hair.AnchorPoint = Vector2.new(0.5, if bar == top then 1 else 0)
		hair.Position = UDim2.fromScale(0.5, if bar == top then 1 else 0)
		hair.Size = UDim2.new(0.7, 0, 0, 1)
		hair.BackgroundColor3 = Theme.Color.Gold
		hair.BackgroundTransparency = 0.55
		hair.BorderSizePixel = 0
		hair.ZIndex = 3
		hair.Parent = bar
		local fadeEnds = Instance.new("UIGradient")
		fadeEnds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fadeEnds.Parent = hair
	end

	-- Title card, centred: the name, a gold rule that draws itself out from the middle, and the line under it.
	local titleText = label(gui, "Title", Theme.Role.Heading, Theme.Color.Parchment)
	titleText.AnchorPoint = Vector2.new(0.5, 0.5)
	titleText.Position = UDim2.fromScale(0.5, 0.45)
	titleText.Size = UDim2.fromScale(0.9, 0.11)
	titleText.TextTransparency = 1
	titleText.ZIndex = 5
	Theme.metalText(titleText)
	local titleShade = Instance.new("UIStroke")
	titleShade.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	titleShade.Color = Color3.fromRGB(20, 10, 4)
	titleShade.Thickness = 1.6
	titleShade.Transparency = 1
	titleShade.Parent = titleText

	-- a rule above the title too: the name is set between two
	local titleRuleTop = Instance.new("Frame")
	titleRuleTop.Name = "TitleRuleTop"
	titleRuleTop.AnchorPoint = Vector2.new(0.5, 0.5)
	titleRuleTop.Position = UDim2.fromScale(0.5, 0.385)
	titleRuleTop.Size = UDim2.fromScale(0, 0)
	titleRuleTop.BackgroundColor3 = Theme.Color.Gold
	titleRuleTop.BackgroundTransparency = 0.35
	titleRuleTop.BorderSizePixel = 0
	titleRuleTop.ZIndex = 5
	titleRuleTop.Parent = gui

	-- embers rising slowly out of the dark behind the title (shown with it)
	local embers = Instance.new("Frame")
	embers.Name = "Embers"
	embers.Size = UDim2.fromScale(1, 1)
	embers.BackgroundTransparency = 1
	embers.ZIndex = 2
	embers.Visible = false
	embers.Parent = gui
	type Ember = { f: Frame, x: number, y: number, speed: number, sway: number, phase: number, life: number }
	local emberList: { Ember } = {}
	for i = 1, 34 do
		local e = Instance.new("Frame")
		e.Name = "Ember"
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		local px = 2 + (i % 3)
		e.Size = UDim2.fromOffset(px, px)
		e.BackgroundColor3 = if i % 4 == 0 then Theme.Color.EmberBright else Theme.Color.Ember
		e.BackgroundTransparency = 1
		e.BorderSizePixel = 0
		e.ZIndex = 2
		e.Parent = embers
		Theme.corner(e, UDim.new(0.5, 0))
		table.insert(emberList, {
			f = e,
			x = math.random(),
			y = math.random(),
			speed = 0.025 + math.random() * 0.05,
			sway = 0.004 + math.random() * 0.01,
			phase = math.random() * 6.28,
			life = math.random(),
		})
	end
	local emberConn: RBXScriptConnection? = nil
	local emberAlpha = 0
	local emberGoal = 0
	local function runEmbers()
		if emberConn then
			return
		end
		embers.Visible = true
		emberConn = RunService.RenderStepped:Connect(function(dt)
			emberAlpha += (emberGoal - emberAlpha) * math.min(1, dt * 1.6)
			for _, e in emberList do
				e.y -= e.speed * dt
				e.life += dt * 0.35
				if e.y < -0.05 then
					e.y = 1.05
					e.x = math.random()
					e.life = 0
				end
				local x = e.x + math.sin(e.phase + e.life * 3) * e.sway
				e.f.Position = UDim2.fromScale(x, e.y)
				-- each glows up from below and dies as it rises; all of them fade with the title
				local glow = math.clamp(1 - e.y, 0, 1) * (0.55 + 0.45 * math.sin(e.phase + e.life * 7))
				e.f.BackgroundTransparency = 1 - math.clamp(glow, 0, 1) * 0.8 * emberAlpha
			end
			if emberGoal == 0 and emberAlpha < 0.01 and emberConn then
				emberConn:Disconnect()
				emberConn = nil
				embers.Visible = false
			end
		end)
	end
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 1.08
	titleScale.Parent = titleText

	local titleRule = Instance.new("Frame")
	titleRule.Name = "TitleRule"
	titleRule.AnchorPoint = Vector2.new(0.5, 0.5)
	titleRule.Position = UDim2.fromScale(0.5, 0.505)
	titleRule.Size = UDim2.fromScale(0, 0)
	titleRule.BackgroundColor3 = Theme.Color.Gold
	titleRule.BackgroundTransparency = 0.15
	titleRule.BorderSizePixel = 0
	titleRule.ZIndex = 5
	titleRule.Parent = gui

	local subText = label(gui, "Subtitle", Theme.Role.Body, Theme.Iron.Bone)
	pcall(function()
		subText.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	end)
	subText.AnchorPoint = Vector2.new(0.5, 0)
	subText.Position = UDim2.fromScale(0.5, 0.53)
	subText.Size = UDim2.fromScale(0.9, 0.06)
	subText.TextTransparency = 1
	subText.ZIndex = 5

	-- The dialogue box: just above the bottom bar, centred.
	local BOX_AT = UDim2.new(0.5, 0, 1 - BAR, -10)
	local BOX_BELOW = UDim2.new(0.5, 0, 1 - BAR, 6)
	local box = Instance.new("CanvasGroup")
	box.Name = "Dialogue"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = BOX_AT
	box.Size = UDim2.fromScale(0.86, 0.17)
	box.BackgroundTransparency = 1
	box.GroupTransparency = 1
	box.BorderSizePixel = 0
	box.Visible = false
	box.ZIndex = 4
	box.Parent = gui
	local boxLimit = Instance.new("UISizeConstraint")
	boxLimit.MaxSize = Vector2.new(860, math.huge)
	boxLimit.Parent = box
	-- the page of oiled leather, a little see-through so the scene is not shut out
	local page = Theme.leatherPage(box, 26)
	page.ImageTransparency = 0.12
	page.ImageColor3 = Color3.fromRGB(176, 164, 150)
	page.ZIndex = 3
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.fromScale(0.5, 0)
	rule.Size = UDim2.new(1, -40, 0, 1)
	rule.BackgroundColor3 = Theme.Color.Gold
	rule.BackgroundTransparency = 0.35
	rule.BorderSizePixel = 0
	rule.ZIndex = 5
	rule.Parent = box

	-- The speaker's face: their Roblox head, in a gold frame. Square, as tall as the box allows.
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.AnchorPoint = Vector2.new(0, 0.5)
	portrait.Position = UDim2.new(0, 14, 0.5, 4)
	portrait.Size = UDim2.fromOffset(0, 0) -- squared to the box's height in layoutLine
	portrait.BackgroundColor3 = Theme.Color.Navy
	portrait.BorderSizePixel = 0
	portrait.ScaleType = Enum.ScaleType.Crop
	portrait.Visible = false
	portrait.ZIndex = 5
	portrait.Parent = box
	Theme.goldStroke(portrait, 1)
	-- the iron frame round the face (a sibling under it, a little larger; it follows the face)
	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "PortraitFrame"
	portraitFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	portraitFrame.BackgroundTransparency = 1
	portraitFrame.ZIndex = 4
	portraitFrame.Visible = false
	portraitFrame.Parent = box
	Theme.ironPlate(portraitFrame, 8).ZIndex = 4

	-- The name plate sits on the box's top edge, left.
	local plate = Instance.new("Frame")
	plate.Name = "NamePlate"
	-- (inside the page, over the words: the box fades as one CanvasGroup, which cuts off whatever sticks out of it)
	plate.AnchorPoint = Vector2.new(0, 0)
	plate.Position = UDim2.new(0, 18, 0, 10)
	plate.Size = UDim2.fromOffset(160, 30)
	plate.AutomaticSize = Enum.AutomaticSize.X
	-- (2026-11-15, the developer: the name over the face picture, in letters alone, as wide as the name needs)
	plate.BackgroundTransparency = 1
	plate.BorderSizePixel = 0
	plate.ZIndex = 6
	plate.Parent = box
	local platePad = Instance.new("UIPadding")
	platePad.PaddingLeft = UDim.new(0, 12)
	platePad.PaddingRight = UDim.new(0, 12)
	platePad.Parent = plate

	local nameText = label(plate, "Name", Theme.Role.Strong, Theme.Color.GoldBright)
	nameText.Size = UDim2.fromScale(0, 1)
	nameText.AutomaticSize = Enum.AutomaticSize.X
	nameText.TextWrapped = false
	nameText.ZIndex = 7
	nameText.TextXAlignment = Enum.TextXAlignment.Left
	Theme.metalText(nameText)
	local nameShade = Instance.new("UIStroke")
	nameShade.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	nameShade.Color = Color3.fromRGB(16, 8, 4)
	nameShade.Thickness = 1.2
	nameShade.Transparency = 0.2
	nameShade.Parent = nameText
	-- a long name is made smaller to fit, never larger than the size the screen gives
	local nameFit = Instance.new("UITextSizeConstraint")
	nameFit.Parent = nameText

	local lineText = label(box, "Line", Theme.Role.Body, Theme.Color.Parchment)
	lineText.Position = UDim2.new(0, 18, 0, 22)
	lineText.Size = UDim2.new(1, -36, 1, -30)
	lineText.TextXAlignment = Enum.TextXAlignment.Left
	lineText.TextYAlignment = Enum.TextYAlignment.Top
	lineText.ZIndex = 5
	local lineShade = Instance.new("UIStroke")
	lineShade.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	lineShade.Color = Color3.new(0, 0, 0)
	lineShade.Thickness = 1
	lineShade.Transparency = 0.55
	lineShade.Parent = lineText

	--[[
		SKIP, in the bottom bar, right: a small plate only as big as its one word, in bold cream letters. Golden brown
		inside, a thin gold edge that shines now and then (not much), and a gold fill that rises while it is held. It
		says only SKIP: no "hold", no "continue". For the first two seconds it is fully there; then it fades to 40% so
		that it does not trouble the scene, and it comes back to full while it is being held.
		The whole thing is a CanvasGroup so that one number (GroupTransparency) fades the plate, the edge and the word
		together.
	]]
	local skipGroup = Instance.new("CanvasGroup")
	skipGroup.Name = "SkipGroup"
	skipGroup.AnchorPoint = Vector2.new(1, 0)
	skipGroup.Position = UDim2.new(1, -24, 0.5, -17)
	skipGroup.Size = UDim2.fromOffset(80, 34)
	skipGroup.BackgroundTransparency = 1
	skipGroup.ZIndex = 3
	skipGroup.Parent = bottom

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Position = UDim2.fromScale(0, 0)
	skip.Size = UDim2.fromOffset(80, 34)
	skip.BackgroundColor3 = Theme.Iron.Black -- (2026-11-15: iron, as the HUD's plates; it was golden brown)
	skip.BackgroundTransparency = 0.1
	skip.AutoButtonColor = false
	skip.Text = ""
	skip.ClipsDescendants = true
	skip.ZIndex = 3
	skip.Parent = skipGroup
	Theme.corner(skip, Theme.Size.CornerSmall)
	local skipEdge = Theme.goldStroke(skip, 1.2)
	Theme.ironPlate(skip, 8).ZIndex = 3

	local skipFill = Instance.new("Frame")
	skipFill.Name = "Fill"
	skipFill.Size = UDim2.fromScale(0, 1)
	skipFill.BackgroundColor3 = Theme.Color.Gold
	skipFill.BackgroundTransparency = 0.35
	local fillHeat = Instance.new("UIGradient")
	fillHeat.Color = ColorSequence.new(Theme.Color.Ember, Theme.Color.GoldBright)
	fillHeat.Parent = skipFill
	skipFill.BorderSizePixel = 0
	skipFill.ZIndex = 4
	skipFill.Parent = skip

	local skipText = label(skip, "Word", Theme.Role.Strong, Theme.Color.Cream)
	skipText.Text = "SKIP"
	skipText.Size = UDim2.fromScale(1, 1)
	skipText.TextWrapped = false
	skipText.ZIndex = 5

	-- A party's votes, as small dots under the plate (a picture, not a word): one for each vote needed, gold for each given.
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.Position = UDim2.fromOffset(0, 37)
	pips.Size = UDim2.fromOffset(80, 6)
	pips.BackgroundTransparency = 1
	pips.Visible = false
	pips.ZIndex = 3
	pips.Parent = skipGroup
	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pipLayout.Padding = UDim.new(0, 4)
	pipLayout.Parent = pips

	-- Text sizes follow the screen's height (and re-follow it if it turns).
	local function resize()
		local camera = Workspace.CurrentCamera
		local h = if camera then camera.ViewportSize.Y else 720
		titleText.TextSize = math.clamp(math.floor(h * 0.072), 28, 64)
		subText.TextSize = math.clamp(math.floor(h * 0.03), 14, 24)
		lineText.TextSize = math.clamp(math.floor(h * 0.034), 15, 28)
		nameText.TextSize = math.clamp(math.floor(h * 0.026), 13, 20)
		-- the plate is only as big as its word: the letters a little larger than before, a thin margin round them
		skipText.TextSize = math.clamp(math.floor(h * 0.034), 17, 25)
		local bounds = skipText.TextBounds
		local w = math.ceil((if bounds.X > 0 then bounds.X else skipText.TextSize * 2.4) + 22)
		local ph = math.ceil(skipText.TextSize + 12)
		skip.Size = UDim2.fromOffset(w, ph)
		skipGroup.Size = UDim2.fromOffset(w, ph + 10)
		skipGroup.Position = UDim2.new(1, -24, 0.5, -math.floor(ph / 2))
		pips.Position = UDim2.fromOffset(0, ph + 3)
		pips.Size = UDim2.fromOffset(w, 6)
		nameFit.MaxTextSize = nameText.TextSize
		titleRule.Size = UDim2.new(titleRule.Size.X.Scale, 0, 0, 2)
		titleRuleTop.Size = UDim2.new(titleRuleTop.Size.X.Scale, 0, 0, 1)
	end
	local function layoutLine()
		-- the face is a square as tall as most of the box; the text starts after it, when there is one
		-- the name in a row along the top, the face picture under it down to the foot of the box (smaller than
		-- before, and no gap under it), the words to the right of both
		local h = box.AbsoluteSize.Y
		local nameH = math.max(18, math.floor(h * 0.22))
		local side = math.max(24, h - nameH - 18)
		portrait.AnchorPoint = Vector2.new(0, 1)
		portrait.Position = UDim2.new(0, 20, 1, -9)
		portrait.Size = UDim2.fromOffset(side, side)
		portraitFrame.Size = UDim2.fromOffset(side + 8, side + 8)
		portraitFrame.Position = UDim2.new(0, 20 + side / 2, 1, -9 - side / 2)
		portraitFrame.Visible = portrait.Visible
		-- the name: over the face, as wide as it needs (up to a little more than the face and the gap beside it)
		plate.AutomaticSize = Enum.AutomaticSize.None
		plate.AnchorPoint = Vector2.new(0, 0)
		plate.Position = UDim2.new(0, 18, 0, 6)
		plate.Size = UDim2.fromOffset(math.floor(math.max(side * 1.9, 120)), nameH)
		nameText.AutomaticSize = Enum.AutomaticSize.None
		nameText.Size = UDim2.fromScale(1, 1)
		nameText.TextScaled = true
		local x = if portrait.Visible then 20 + side + 18 else 18
		local top = if portrait.Visible then 10 else 6 + nameH + 4
		lineText.Position = UDim2.new(0, x, 0, top + (if portrait.Visible then nameH * 0.5 else 0))
		lineText.Size = UDim2.new(1, -(x + 18), 1, -(top + 10))
	end
	resize()
	local camera = Workspace.CurrentCamera
	local resizeConn = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) else nil
	local portraitConn = box:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLine)

	local typeToken = 0
	local skipFns: { () -> () } = {}
	local handle = {} :: Handle

	--========================================================================
	-- Hold to skip
	--========================================================================
	local needed = 1
	local votes = 0
	local mine = false
	local holdStart: number? = nil
	local holdInput: InputObject? = nil
	local holdConn: RBXScriptConnection? = nil

	-- How present the button is: fully there for the first two seconds, then 40% (the scene must not be troubled by it),
	-- full again while it is being held and for a moment when a friend has held theirs.
	local FADE_AFTER = 2
	local DIMMED = 0.6 -- GroupTransparency: 0.6 leaves 40% of it showing
	local dimToken = 0
	local function present(full: boolean, seconds: number)
		TweenService:Create(skipGroup, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			GroupTransparency = if full then 0 else DIMMED,
		}):Play()
	end
	local function dimSoon(after: number)
		dimToken += 1
		local mineToken = dimToken
		task.delay(after, function()
			if mineToken == dimToken and not holdStart and not mine and skipGroup.Parent then
				present(false, 0.9)
			end
		end)
	end
	dimSoon(FADE_AFTER)

	-- the gold edge shines now and then: slowly, and not much
	TweenService:Create(skipEdge, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 }):Play()

	local function emptyFill()
		TweenService:Create(skipFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(0, 1) }):Play()
	end

	local function stopHold(completed: boolean)
		if holdConn then
			holdConn:Disconnect()
			holdConn = nil
		end
		holdStart = nil
		holdInput = nil
		if not completed then
			emptyFill()
			dimSoon(0.8)
		end
	end

	local function startHold(input: InputObject)
		if mine or holdStart then
			return
		end
		holdStart = os.clock()
		holdInput = input
		dimToken += 1
		present(true, 0.15)
		holdConn = RunService.RenderStepped:Connect(function()
			local started = holdStart
			if not started then
				return
			end
			local t = math.clamp((os.clock() - started) / math.max(holdSeconds, 0.1), 0, 1)
			skipFill.Size = UDim2.fromScale(t, 1)
			if t >= 1 then
				stopHold(true)
				mine = true
				for _, fn in skipFns do
					fn()
				end
			end
		end)
	end

	-- the dots under the plate: one for each vote needed (when more than one is), gold for each one given
	local function drawPips()
		for _, child in pips:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		pips.Visible = needed > 1
		for i = 1, if needed > 1 then needed else 0 do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(6, 6)
			dot.BackgroundColor3 = if i <= votes then Theme.Color.GoldBright else Color3.fromRGB(60, 44, 24)
			dot.BorderSizePixel = 0
			dot.LayoutOrder = i
			dot.Parent = pips
			Theme.corner(dot, UDim.new(0.5, 0))
			local rim = Instance.new("UIStroke")
			rim.Color = Theme.Color.GoldDim
			rim.Thickness = 1
			rim.Parent = dot
		end
	end

	skip.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startHold(input)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End and holdInput == input then
					stopHold(false)
				end
			end)
		end
	end)
	skip.MouseLeave:Connect(function()
		-- a mouse that slides off the button lets go; a thumb stays where it is
		if holdInput and holdInput.UserInputType == Enum.UserInputType.MouseButton1 then
			stopHold(false)
		end
	end)
	-- the size once the word has its letters (TextBounds is only true after the label has been drawn)
	task.defer(function()
		if skipText.Parent then
			resize()
		end
	end)

	--========================================================================
	-- The handle
	--========================================================================
	function handle.black(alpha: number, seconds: number)
		TweenService:Create(fade, ease(math.max(seconds, 0.01)), { BackgroundTransparency = 1 - alpha }):Play()
	end

	function handle.letterbox(on: boolean, seconds: number)
		local info = ease(math.max(seconds, 0.01))
		TweenService:Create(top, info, { Position = UDim2.fromScale(0, if on then BAR else 0) }):Play()
		TweenService:Create(bottom, info, { Position = UDim2.fromScale(0, if on then 1 - BAR else 1) }):Play()
	end

	function handle.title(text: string, sub: string, seconds: number)
		titleText.Text = text
		subText.Text = sub
		local inInfo = ease(1.2)
		TweenService:Create(titleText, inInfo, { TextTransparency = 0 }):Play()
		TweenService:Create(titleShade, inInfo, { Transparency = 0.2 }):Play()
		emberGoal = 1
		runEmbers()
		Sfx.play("Title")
		-- it settles from a little too large, slowly, for as long as it is on screen
		TweenService:Create(titleScale, TweenInfo.new(math.max(seconds, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.5, function()
			TweenService:Create(titleRule, ease(1.4), { Size = UDim2.new(0.34, 0, 0, 2) }):Play()
			TweenService:Create(titleRuleTop, ease(1.6), { Size = UDim2.new(0.22, 0, 0, 1) }):Play()
		end)
		task.delay(0.9, function()
			TweenService:Create(subText, inInfo, { TextTransparency = 0 }):Play()
		end)
		task.delay(math.max(seconds - 1.1, 0.5), function()
			local outInfo = ease(0.9)
			TweenService:Create(titleText, outInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(subText, outInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(titleRule, outInfo, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(titleRuleTop, outInfo, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(titleShade, outInfo, { Transparency = 1 }):Play()
			emberGoal = 0
		end)
	end

	function handle.say(name: string, text: string, charactersPerSecond: number, image: string?)
		typeToken += 1
		local token = typeToken
		-- the name as the player wrote it (their nickname: Roblox's display name), not in capitals
		local newName = nameText.Text ~= name
		nameText.Text = name
		lineText.Text = ""
		if image and image ~= "" then
			portrait.Image = image
			portrait.Visible = true
		else
			portrait.Visible = false
		end
		layoutLine()
		if newName or not box.Visible or box.GroupTransparency > 0.5 then
			Sfx.play("Name")
		end
		if not box.Visible or box.GroupTransparency > 0.5 then
			box.Visible = true
			box.Position = BOX_BELOW
			TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = BOX_AT, GroupTransparency = 0 }):Play()
		end
		local typed = 0
		local okA, audio = pcall(Config.get, "Audio")
		local typeEvery = (okA and audio and audio.Ui and audio.Ui.Type and audio.Ui.Type.Every) or 3
		task.spawn(function()
			local shown = ""
			for _, code in utf8.codes(text) do
				if token ~= typeToken then
					return
				end
				shown ..= utf8.char(code)
				lineText.Text = shown
				-- a very light key every few letters (not on a space)
				if code ~= 32 then
					typed += 1
					if typed % typeEvery == 0 then
						Sfx.play("Type")
					end
				end
				task.wait(1 / charactersPerSecond)
			end
		end)
	end

	function handle.clearLine()
		typeToken += 1
		local mineToken = typeToken
		TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
		task.delay(0.32, function()
			if typeToken == mineToken then
				box.Visible = false
			end
		end)
	end

	function handle.setVotes(count: number, need: number, iHaveHeld: boolean)
		local more = count > votes
		votes = count
		needed = need
		mine = iHaveHeld
		drawPips()
		-- a friend has held theirs: the button comes back to full for a moment, so it is noticed
		if more and not holdStart and not mine then
			present(true, 0.2)
			dimSoon(2.5)
		end
	end

	function handle.onSkip(fn: () -> ())
		table.insert(skipFns, fn)
	end

	function handle.destroy()
		typeToken += 1
		stopHold(true)
		if resizeConn then
			resizeConn:Disconnect()
		end
		portraitConn:Disconnect()
		if emberConn then
			emberConn:Disconnect()
			emberConn = nil
		end
		gui:Destroy()
	end

	return handle
end

return IntroUI
