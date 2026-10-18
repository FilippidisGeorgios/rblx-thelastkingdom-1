--!strict
--[[
	IntroUI
	What the screen looks like while the arrival scene plays: black bars top and
	bottom, a title card over black, and the dialogue box — the speaker's name on
	a small gold plate, what they say underneath, typed out.

	Built for a phone first. Every size is a share of the screen, and the text
	size is worked out from the screen's height (and redone if it turns), so the
	box reads the same on a 5-inch phone held sideways and on a monitor. The
	skip button is 48 px tall at least: a thumb, not a mouse pointer.

	Owns no logic: IntroController says what to show and when.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IntroUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local IntroUI = {}

export type Handle = {
	black: (alpha: number, seconds: number) -> (),
	letterbox: (on: boolean, seconds: number) -> (),
	title: (text: string, sub: string, seconds: number) -> (),
	say: (name: string, text: string, charactersPerSecond: number) -> (),
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

function IntroUI.create(): Handle
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

	-- Title card, centred.
	local titleText = label(gui, "Title", Theme.Role.Heading, Theme.Color.Parchment)
	titleText.AnchorPoint = Vector2.new(0.5, 0.5)
	titleText.Position = UDim2.fromScale(0.5, 0.46)
	titleText.Size = UDim2.fromScale(0.9, 0.1)
	titleText.TextTransparency = 1
	titleText.ZIndex = 5

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
	box.Size = UDim2.fromScale(0.86, 0.15)
	box.BackgroundColor3 = Theme.Color.Ink
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	box.Visible = false
	box.ZIndex = 4
	box.Parent = gui
	Theme.corner(box)
	local boxLimit = Instance.new("UISizeConstraint")
	boxLimit.MaxSize = Vector2.new(820, math.huge)
	boxLimit.Parent = box
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.BackgroundColor3 = Theme.Color.Gold
	rule.BorderSizePixel = 0
	rule.ZIndex = 5
	rule.Parent = box

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

	-- Skip, in the bottom bar, right.
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -24, 0.5, 0)
	skip.Size = UDim2.fromOffset(150, 48)
	skip.BackgroundColor3 = Theme.Color.Navy
	skip.BackgroundTransparency = 0.15
	skip.AutoButtonColor = true
	skip.Text = "SKIP"
	skip.TextColor3 = Theme.Color.Parchment
	skip.ZIndex = 3
	skip.Parent = bottom
	Theme.applyFont(skip, Theme.Role.Strong)
	Theme.corner(skip, Theme.Size.CornerSmall)
	Theme.goldStroke(skip, 1.2)

	-- Text sizes follow the screen's height (and re-follow it if it turns).
	local function resize()
		local camera = Workspace.CurrentCamera
		local h = if camera then camera.ViewportSize.Y else 720
		titleText.TextSize = math.clamp(math.floor(h * 0.06), 24, 52)
		subText.TextSize = math.clamp(math.floor(h * 0.03), 14, 24)
		lineText.TextSize = math.clamp(math.floor(h * 0.034), 15, 28)
		nameText.TextSize = math.clamp(math.floor(h * 0.026), 13, 20)
		skip.TextSize = math.clamp(math.floor(h * 0.026), 14, 20)
		plate.Size = UDim2.fromOffset(0, math.max(26, nameText.TextSize + 12))
	end
	resize()
	local camera = Workspace.CurrentCamera
	local resizeConn = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) else nil

	local typeToken = 0
	local skipFns: { () -> () } = {}
	skip.Activated:Connect(function()
		for _, fn in skipFns do
			fn()
		end
	end)

	local handle = {} :: Handle

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
		local inInfo = ease(1)
		TweenService:Create(titleText, inInfo, { TextTransparency = 0 }):Play()
		task.delay(0.4, function()
			TweenService:Create(subText, inInfo, { TextTransparency = 0 }):Play()
		end)
		task.delay(math.max(seconds - 1, 0.5), function()
			local outInfo = ease(0.9)
			TweenService:Create(titleText, outInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(subText, outInfo, { TextTransparency = 1 }):Play()
		end)
	end

	function handle.say(name: string, text: string, charactersPerSecond: number)
		typeToken += 1
		local token = typeToken
		nameText.Text = string.upper(name)
		lineText.Text = ""
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

	function handle.setVotes(votes: number, needed: number, mine: boolean)
		if needed <= 1 then
			skip.Text = "SKIP"
		elseif mine then
			skip.Text = ("WAITING %d/%d"):format(votes, needed)
		else
			skip.Text = ("SKIP %d/%d"):format(votes, needed)
		end
	end

	function handle.onSkip(fn: () -> ())
		table.insert(skipFns, fn)
	end

	function handle.destroy()
		typeToken += 1
		if resizeConn then
			resizeConn:Disconnect()
		end
		gui:Destroy()
	end

	return handle
end

return IntroUI
