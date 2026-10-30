--!strict
--[[
	IntroUI
	What the screen looks like while the arrival scene plays: black bars top and bottom, a title card over black,
	and the dialogue box: the speaker's face on the left, their name on a small gold plate, and what they say,
	typed out. In the bottom bar, on the right, the SKIP button, which has to be HELD.

	HOLD TO SKIP. A tap does nothing. The player presses and keeps pressing for `holdSeconds` (3) while a gold
	bar fills the button; let go early and it empties again. Only when it is full does the button say "skip" to
	the controller, and the controller sends the vote. In a party the skip needs a majority (the server counts),
	and the button shows how many have held so far.

	Built for a phone first. Every size is a share of the screen, and the text size is worked out from the
	screen's height (and redone if it turns), so the box reads the same on a 5-inch phone held sideways and on a
	monitor. The skip button is 48 px tall at least: a thumb, not a mouse pointer.

	Owns no logic: IntroController says what to show and when.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IntroUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

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

	-- Title card, centred: the name, a gold rule that draws itself out from the middle, and the line under it.
	local titleText = label(gui, "Title", Theme.Role.Heading, Theme.Color.Parchment)
	titleText.AnchorPoint = Vector2.new(0.5, 0.5)
	titleText.Position = UDim2.fromScale(0.5, 0.45)
	titleText.Size = UDim2.fromScale(0.9, 0.1)
	titleText.TextTransparency = 1
	titleText.ZIndex = 5
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

	local subText = label(gui, "Subtitle", Theme.Role.Body, Theme.Color.Muted)
	subText.AnchorPoint = Vector2.new(0.5, 0)
	subText.Position = UDim2.fromScale(0.5, 0.53)
	subText.Size = UDim2.fromScale(0.9, 0.06)
	subText.TextTransparency = 1
	subText.ZIndex = 5

	-- The dialogue box: just above the bottom bar, centred.
	local box = Instance.new("Frame")
	box.Name = "Dialogue"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1 - BAR, -10)
	box.Size = UDim2.fromScale(0.86, 0.17)
	box.BackgroundColor3 = Theme.Color.Ink
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	box.Visible = false
	box.ZIndex = 4
	box.Parent = gui
	Theme.corner(box)
	local boxLimit = Instance.new("UISizeConstraint")
	boxLimit.MaxSize = Vector2.new(860, math.huge)
	boxLimit.Parent = box
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = Theme.Color.Gold
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
	Theme.corner(portrait, Theme.Size.CornerSmall)
	Theme.goldStroke(portrait, 1.5)

	-- The name plate sits on the box's top edge, left.
	local plate = Instance.new("Frame")
	plate.Name = "NamePlate"
	plate.AnchorPoint = Vector2.new(0, 0.5)
	plate.Position = UDim2.new(0, 14, 0, 0)
	plate.Size = UDim2.fromOffset(160, 30)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.BackgroundColor3 = Theme.Color.Navy
	plate.BorderSizePixel = 0
	plate.ZIndex = 6
	plate.Parent = box
	Theme.corner(plate, Theme.Size.CornerSmall)
	Theme.goldStroke(plate, 1.5)
	local platePad = Instance.new("UIPadding")
	platePad.PaddingLeft = UDim.new(0, 12)
	platePad.PaddingRight = UDim.new(0, 12)
	platePad.Parent = plate

	local nameText = label(plate, "Name", Theme.Role.Strong, Theme.Color.GoldBright)
	nameText.Size = UDim2.fromScale(0, 1)
	nameText.AutomaticSize = Enum.AutomaticSize.X
	nameText.TextWrapped = false
	nameText.ZIndex = 7

	local lineText = label(box, "Line", Theme.Role.Body, Theme.Color.Parchment)
	lineText.Position = UDim2.new(0, 18, 0, 22)
	lineText.Size = UDim2.new(1, -36, 1, -30)
	lineText.TextXAlignment = Enum.TextXAlignment.Left
	lineText.TextYAlignment = Enum.TextYAlignment.Top
	lineText.ZIndex = 5

	-- Skip, in the bottom bar, right. A plate with a gold bar under its word that fills while it is held.
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -24, 0.5, 0)
	skip.Size = UDim2.fromOffset(230, 48)
	skip.BackgroundColor3 = Theme.Color.Navy
	skip.BackgroundTransparency = 0.15
	skip.AutoButtonColor = false
	skip.Text = ""
	skip.ClipsDescendants = true
	skip.ZIndex = 3
	skip.Parent = bottom
	Theme.corner(skip, Theme.Size.CornerSmall)
	Theme.goldStroke(skip, 1.2)

	local skipFill = Instance.new("Frame")
	skipFill.Name = "Fill"
	skipFill.Size = UDim2.fromScale(0, 1)
	skipFill.BackgroundColor3 = Theme.Color.Gold
	skipFill.BackgroundTransparency = 0.45
	skipFill.BorderSizePixel = 0
	skipFill.ZIndex = 4
	skipFill.Parent = skip

	local skipText = label(skip, "Word", Theme.Role.Strong, Theme.Color.Parchment)
	skipText.Size = UDim2.fromScale(1, 1)
	skipText.TextWrapped = false
	skipText.ZIndex = 5

	-- Text sizes follow the screen's height (and re-follow it if it turns).
	local function resize()
		local camera = Workspace.CurrentCamera
		local h = if camera then camera.ViewportSize.Y else 720
		titleText.TextSize = math.clamp(math.floor(h * 0.06), 24, 52)
		subText.TextSize = math.clamp(math.floor(h * 0.03), 14, 24)
		lineText.TextSize = math.clamp(math.floor(h * 0.034), 15, 28)
		nameText.TextSize = math.clamp(math.floor(h * 0.026), 13, 20)
		skipText.TextSize = math.clamp(math.floor(h * 0.024), 13, 18)
		plate.Size = UDim2.fromOffset(0, math.max(26, nameText.TextSize + 12))
		titleRule.Size = UDim2.new(titleRule.Size.X.Scale, 0, 0, 2)
	end
	local function layoutLine()
		-- the face is a square as tall as most of the box; the text starts after it, when there is one
		local side = math.floor(box.AbsoluteSize.Y * 0.74)
		portrait.Size = UDim2.fromOffset(side, side)
		local face = if portrait.Visible then side + 14 else 0
		lineText.Position = UDim2.new(0, 18 + face + (if face > 0 then 12 else 0), 0, 22)
		lineText.Size = UDim2.new(1, -(36 + face + (if face > 0 then 12 else 0)), 1, -30)
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

	local function words(): string
		if mine then
			return ("WAITING   %d / %d"):format(votes, needed)
		elseif needed <= 1 then
			return "HOLD TO SKIP"
		end
		return ("HOLD TO SKIP   %d / %d"):format(votes, needed)
	end

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
			skipText.Text = words()
		end
	end

	local function startHold(input: InputObject)
		if mine or holdStart then
			return
		end
		holdStart = os.clock()
		holdInput = input
		skipText.Text = "KEEP HOLDING"
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
				skipText.Text = words()
				for _, fn in skipFns do
					fn()
				end
			end
		end)
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
	skipText.Text = words()

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
		-- it settles from a little too large, slowly, for as long as it is on screen
		TweenService:Create(titleScale, TweenInfo.new(math.max(seconds, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.5, function()
			TweenService:Create(titleRule, ease(1.4), { Size = UDim2.new(0.34, 0, 0, 2) }):Play()
		end)
		task.delay(0.9, function()
			TweenService:Create(subText, inInfo, { TextTransparency = 0 }):Play()
		end)
		task.delay(math.max(seconds - 1.1, 0.5), function()
			local outInfo = ease(0.9)
			TweenService:Create(titleText, outInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(subText, outInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(titleRule, outInfo, { BackgroundTransparency = 1 }):Play()
		end)
	end

	function handle.say(name: string, text: string, charactersPerSecond: number, image: string?)
		typeToken += 1
		local token = typeToken
		nameText.Text = string.upper(name)
		lineText.Text = ""
		if image and image ~= "" then
			portrait.Image = image
			portrait.Visible = true
		else
			portrait.Visible = false
		end
		layoutLine()
		box.Visible = true
		task.spawn(function()
			local shown = ""
			for _, code in utf8.codes(text) do
				if token ~= typeToken then
					return
				end
				shown ..= utf8.char(code)
				lineText.Text = shown
				task.wait(1 / charactersPerSecond)
			end
		end)
	end

	function handle.clearLine()
		typeToken += 1
		box.Visible = false
	end

	function handle.setVotes(count: number, need: number, iHaveHeld: boolean)
		votes = count
		needed = need
		mine = iHaveHeld
		if not holdStart then
			skipText.Text = words()
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
		gui:Destroy()
	end

	return handle
end

return IntroUI
