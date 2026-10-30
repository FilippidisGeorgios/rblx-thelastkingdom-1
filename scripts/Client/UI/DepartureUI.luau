--!strict
--[[
	DepartureUI
	The train station's interface: the panel a player gets when they step into a
	wagon.

	Three faces, one screen:
		"create" — this wagon is empty. Pick a party size (1-8) and a mode, read the
		           DANGER it makes, and call it.
		"join"   — a party is already forming in this wagon. Take a seat.
		"aboard" — you are on board. One action left: Leave.

	THE MODE. A party of five or more plays Hard and Normal is shut to it (the button is
	dimmed and says why); a smaller party may choose Hard, and Normal is the default.

	THE DANGER is one figure from 0 to 100, "+34 of 100 harder": the mode's points plus
	the veterans' (the party's average level, kept small by the new players' shield). It
	is drawn as a thin meter that warms from green to red, with a line under it saying
	where the points come from. The server works it out from who is really aboard
	(Shared/Danger) and sends it; before anyone has boarded, the create face previews it
	from the caller's own level with the very same module.

	The primary action always lives at the BOTTOM CENTRE of the screen, whatever
	the face — the player's eye never has to go looking for it.

	Each of the four wagons runs its own party, so the panel names the wagon it is
	talking about.

	Presentation only: this module never decides anything. It renders what the
	server sent and reports what the player clicked.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.DepartureUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Danger = require(ReplicatedStorage.Shared.Danger)

local DepartureUI = {}

export type DangerInfo = {
	total: number,
	mode: number,
	veteran: number,
	avgLevel: number,
	keep: number,
	shielded: boolean,
}

export type Status = {
	state: string?,
	count: number?,
	capacity: number?,
	tier: string?,
	normalClosed: boolean?,
	danger: DangerInfo?,
	seconds: number?,
	wagon: number?,
	members: { string }?,
	-- one per member, in the same order: { name, level, title, might, renownTier, renown } (the Muster Roll's brief)
	crew: { { [string]: any } }?,
	partyMight: number?,
	leader: string?,
}

export type Callbacks = {
	onCreate: (size: number, hard: boolean) -> (),
	onJoin: () -> (),
	onLeave: () -> (),
	onDepartNow: () -> (),
}

type Meter = {
	frame: Frame,
	value: TextLabel,
	fill: Frame,
	note: TextLabel,
}

local MIN_PARTY = 1
local MAX_PARTY = 8

-- The whole panel is drawn a little smaller than its natural size: it was too big on the screen.
local PANEL_SCALE = 0.9
local STACK_SCALE = 0.92

-- Leave is a smaller commitment than boarding, and its button should read that
-- way: same type, narrower plate, so the label is not marooned in empty space.
local ACTION_WIDE = 340
local ACTION_NARROW = 228

local brand = { Title = "THE LAST KINGDOM", Developer = "by Cookies11f", LogoAssetId = "" }
local callbacks: Callbacks? = nil

local panel: Frame? = nil
local actionButton: TextButton? = nil
local departButton: TextButton? = nil
local chip: TextLabel? = nil
local rosterCard: Frame? = nil
local rosterText: TextLabel? = nil
local notice: TextLabel? = nil
local localName = ""
local isLeader = false

local wagonLabel: TextLabel? = nil
local modeValue: TextLabel? = nil
local modeButtons: Frame? = nil
local normalButton: TextButton? = nil
local hardButton: TextButton? = nil
local modeHint: TextLabel? = nil
local subtitle: TextLabel? = nil
local timerLabel: TextLabel? = nil
local stepper: Components.Stepper? = nil
local stepperGroup: Frame? = nil
local modeGroup: Frame? = nil
local panelMeter: Meter? = nil
local rosterMeter: Meter? = nil

local face = "hidden"
local lastStatus: Status = {}
local wantsHard = false
local yourLevel = 1
local partySize = 4

local screenGui: ScreenGui? = nil
local fitScale = PANEL_SCALE
local enterUntil = 0 -- while the panel is rising into place its own tween owns the scale

--[[
	Keeps the panel whole on a short screen. It is drawn at PANEL_SCALE, and smaller still if it would not fit
	between the top of the screen and the action button under it (a phone held sideways, a small Studio window):
	its natural height is measured, not guessed, so adding a row later never needs this touched.
]]
local function fit()
	local root, gui = panel, screenGui
	if not root or not gui then
		return
	end
	local scale = root:FindFirstChildOfClass("UIScale")
	if not scale or gui.AbsoluteSize.Y <= 0 then
		return
	end
	local natural = root.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
	if natural <= 0 then
		return
	end
	local room = gui.AbsoluteSize.Y - 170 -- the button below, and a margin
	fitScale = math.clamp(room / natural, 0.5, PANEL_SCALE)
	root.Position = UDim2.new(0.5, 0, 0, math.floor(room / 2 + 12))
	if os.clock() >= enterUntil then
		scale.Scale = fitScale
	end
end

--============================================================================
-- Helpers
--============================================================================

local function rules(): any
	return Config.get("Difficulty").Danger
end

local function tiers(): any
	return Config.get("Difficulty").Tiers
end

local function tierColor(tier: string): Color3
	-- Normal is deliberately grey: it is the absence of danger.
	return if tier:upper() == "HARD" then Theme.Color.BordeauxSoft else Theme.Color.Grey
end

local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- The meter warms as the danger climbs: forest, then brass, then red.
local function dangerColor(total: number): Color3
	local t = math.clamp(total / 100, 0, 1)
	if t < 0.4 then
		return Theme.Color.GreenLight:Lerp(Theme.Color.Gold, t / 0.4)
	end
	return Theme.Color.Gold:Lerp(Theme.Color.BordeauxSoft, (t - 0.4) / 0.6)
end

-- Where the points came from, in one quiet line.
local function dangerNote(d: DangerInfo): string
	local parts: { string } = {}
	if d.mode > 0 then
		table.insert(parts, ("Hard +%d"):format(round(d.mode)))
	end
	if d.veteran >= 0.5 then
		table.insert(parts, ("veterans +%d"):format(round(d.veteran)))
	end
	if d.shielded then
		table.insert(parts, ("new players' shield keeps %d%%"):format(round(d.keep * 100)))
	end
	if #parts == 0 then
		return "A quiet start."
	end
	return table.concat(parts, "  ·  ")
end

--============================================================================
-- The danger meter
--============================================================================

local function buildMeter(parent: Instance, order: number, compact: boolean): Meter
	local frame = Components.group({
		Name = "DangerMeter",
		Size = UDim2.new(1, 0, 0, if compact then 46 else 58),
		LayoutOrder = order,
		Parent = parent,
	})

	Components.label({
		Name = "DangerCaption",
		Text = Components.spaced("DANGER"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.4, 0, 0, 22),
		Parent = frame,
	})

	local value = Components.label({
		Name = "DangerValue",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Cream,
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.6, 0, 0, 22),
		Parent = frame,
	})

	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.Position = UDim2.fromOffset(0, 26)
	rail.Size = UDim2.new(1, 0, 0, 8)
	rail.BackgroundColor3 = Theme.Color.Void
	rail.BorderSizePixel = 0
	rail.ZIndex = 3
	rail.Parent = frame
	Theme.corner(rail, UDim.new(0.5, 0))
	local edge = Instance.new("UIStroke")
	edge.Color = Theme.Color.GoldDim
	edge.Thickness = 1
	edge.Parent = rail

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Color.GreenLight
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.Parent = rail
	Theme.corner(fill, UDim.new(0.5, 0))

	local note = Components.label({
		Name = "DangerNote",
		Text = "",
		TextSize = Theme.TextSize.Micro - 3,
		TextColor = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 37),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = frame,
	})
	note.TextTruncate = Enum.TextTruncate.AtEnd

	return { frame = frame, value = value, fill = fill, note = note }
end

local function drawMeter(meter: Meter?, d: DangerInfo, note: string?)
	if not meter then
		return
	end
	local total = math.clamp(d.total, 0, 100)
	meter.value.Text = ('<font size="%d">+%d</font> <font size="%d" color="#%s">of 100 harder</font>'):format(
		Theme.TextSize.Body,
		round(total),
		Theme.TextSize.Micro - 2,
		Theme.Color.Muted:ToHex()
	)
	meter.note.Text = note or dangerNote(d)
	meter.fill.BackgroundColor3 = dangerColor(total)
	TweenService:Create(meter.fill, Theme.Motion.Normal, { Size = UDim2.fromScale(math.max(total / 100, 0.02), 1) }):Play()
end

--============================================================================
-- Build
--============================================================================

local function buildPanel(parent: ScreenGui)
	local root = Components.panel({
		Name = "DeparturePanel",
		Size = UDim2.fromOffset(Theme.Size.PanelWidth, 0),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	root.AutomaticSize = Enum.AutomaticSize.Y

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(Theme.Size.PanelMin, 0)
	sizeConstraint.MaxSize = Vector2.new(Theme.Size.PanelMax, math.huge)
	sizeConstraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 10)
	Theme.shadow(root)

	-- Brand. At this size the wordmark carries itself; letter-spacing it would
	-- push it onto two lines.
	if brand.LogoAssetId ~= "" then
		local logo = Instance.new("ImageLabel")
		logo.Name = "Logo"
		logo.Image = brand.LogoAssetId
		logo.BackgroundTransparency = 1
		logo.Size = UDim2.fromOffset(280, 76)
		logo.ScaleType = Enum.ScaleType.Fit
		logo.LayoutOrder = 1
		logo.ZIndex = 3
		logo.Parent = root
	else
		local wordmark = Components.label({
			Name = "Logo",
			Text = brand.Title,
			Role = Theme.Role.Logo,
			TextSize = Theme.TextSize.Logo,
			TextColor = Theme.Color.GoldBright,
			Size = UDim2.new(1, 0, 0, Theme.TextSize.Logo + 12),
			LayoutOrder = 1,
			Gradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Color.GoldBright),
				ColorSequenceKeypoint.new(1, Theme.Color.Gold),
			}),
			Parent = root,
		})
		-- Fondamento's strokes are already fine and looping; a heavy outline fills
		-- the counters in and the word stops being readable. A hair is enough.
		Theme.thickenText(wordmark, 0.5)
	end

	Components.label({
		Name = "Developer",
		Text = brand.Developer,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 2,
		Parent = root,
	})

	Components.divider(root, 3)

	wagonLabel = Components.label({
		Name = "Wagon",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 4,
		Parent = root,
	})

	subtitle = Components.label({
		Name = "Subtitle",
		Text = "Board the train to the Forgotten Lands",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Parchment,
		LayoutOrder = 5,
		Parent = root,
	})

	-- Party size.
	stepperGroup = Components.group({
		Name = "PartySize",
		Size = UDim2.new(1, 0, 0, 106),
		LayoutOrder = 6,
		Parent = root,
	})
	Components.list(stepperGroup :: Frame, 2)

	Components.label({
		Name = "PlayersCaption",
		Text = Components.spaced("PLAYERS"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = stepperGroup,
	})

	stepper = Components.stepper({
		Min = MIN_PARTY,
		Max = MAX_PARTY,
		Value = partySize,
		LayoutOrder = 2,
		Parent = stepperGroup,
		OnChanged = function(value)
			partySize = value
			DepartureUI.refreshPreview()
		end,
	})

	-- The mode: chosen by a small party, forced on a big one; and the danger it makes.
	modeGroup = Components.group({
		Name = "Mode",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 7,
		Parent = root,
	})
	;(modeGroup :: Frame).AutomaticSize = Enum.AutomaticSize.Y
	Components.list(modeGroup :: Frame, 6)

	Components.label({
		Name = "ModeCaption",
		Text = Components.spaced("GAME MODE"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = modeGroup,
	})

	-- for a party already forming: the mode it plays, plainly
	modeValue = Components.label({
		Name = "ModeValue",
		Text = "NORMAL",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.Grey,
		LayoutOrder = 2,
		Parent = modeGroup,
	})

	-- for the one calling the party: two buttons
	modeButtons = Components.group({ Name = "ModeButtons", Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 3, Parent = modeGroup })
	local buttons = modeButtons :: Frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = buttons

	normalButton = Components.button({
		Name = "Normal",
		Text = "NORMAL",
		Variant = "gold",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.new(0.5, -4, 1, 0),
		LayoutOrder = 1,
		Parent = buttons,
	})
	hardButton = Components.button({
		Name = "Hard",
		Text = "HARD",
		Variant = "ghost",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.new(0.5, -4, 1, 0),
		LayoutOrder = 2,
		Parent = buttons,
	})
	;(normalButton :: TextButton).Activated:Connect(function()
		local _, closed = Danger.modeFor(partySize, false, tiers())
		if closed then
			return -- a party this big cannot play Normal
		end
		wantsHard = false
		DepartureUI.refreshPreview()
	end)
	;(hardButton :: TextButton).Activated:Connect(function()
		wantsHard = true
		DepartureUI.refreshPreview()
	end)

	modeHint = Components.label({
		Name = "ModeHint",
		Text = "",
		TextSize = Theme.TextSize.Micro - 3,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = modeGroup,
	})

	panelMeter = buildMeter(modeGroup :: Frame, 5, false)

	Components.divider(root, 8)

	timerLabel = Components.label({
		Name = "Timer",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Muted,
		LayoutOrder = 9,
		Parent = root,
	})

	local scale = Instance.new("UIScale")
	scale.Scale = PANEL_SCALE
	scale.Parent = root

	panel = root
end

-- Everything the player can act on lives in one column anchored to the bottom of
-- the screen. It is a UIListLayout growing UPWARD, so hiding a row (the leader's
-- Depart Now, say) closes the gap instead of leaving a hole.
local function buildBottomStack(parent: ScreenGui)
	local stack = Components.group({
		Name = "BottomStack",
		Size = UDim2.new(0, 460, 0, 0),
		Position = UDim2.new(0.5, 0, 1, -46),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = parent,
	})
	stack.AutomaticSize = Enum.AutomaticSize.Y
	Components.list(stack, 10)
	local stackScale = Instance.new("UIScale")
	stackScale.Scale = STACK_SCALE
	stackScale.Parent = stack

	notice = Components.label({
		Name = "Notice",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.BordeauxSoft,
		LayoutOrder = 1,
		Parent = stack,
	})
	;(notice :: TextLabel).Visible = false

	-- Who you are riding with. In a co-op run boarded with strangers, this is the
	-- first thing a player looks for.
	rosterCard = Components.panel({
		Name = "RosterCard",
		Size = UDim2.new(0, 320, 0, 0),
		LayoutOrder = 2,
		Parent = stack,
	})
	local card = rosterCard :: Frame
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.padding(card, 12)
	Components.list(card, 4)

	Components.label({
		Name = "Caption",
		Text = Components.spaced("YOUR PARTY"),
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Gold,
		LayoutOrder = 1,
		Parent = card,
	})

	rosterText = Components.label({
		Name = "Members",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.Parchment,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = card,
	})
	;(rosterText :: TextLabel).AutomaticSize = Enum.AutomaticSize.Y
	;(rosterText :: TextLabel).RichText = true -- a name, and under it in a smaller hand who they are

	Components.divider(card, 3)
	rosterMeter = buildMeter(card, 4, true)

	chip = Components.label({
		Name = "PartyChip",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Body,
		TextColor = Theme.Color.Gold,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		Parent = stack,
	})
	-- it sits over the world, not over a panel: a dark outline keeps it readable against a bright platform
	local chipStroke = Instance.new("UIStroke")
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	chipStroke.Color = Color3.new(0, 0, 0)
	chipStroke.Thickness = 1.8
	chipStroke.Transparency = 0.2
	chipStroke.Parent = chip

	departButton = Components.button({
		Name = "DepartNow",
		Text = "DEPART NOW",
		Variant = "confirm",
		TextSize = Theme.TextSize.Body,
		Size = UDim2.fromOffset(228, 48),
		LayoutOrder = 4,
		Parent = stack,
	})

	actionButton = Components.button({
		Name = "PrimaryAction",
		Text = "CREATE PARTY",
		Variant = "green",
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.fromOffset(ACTION_WIDE, 58),
		LayoutOrder = 5,
		Parent = stack,
	})

	;(departButton :: TextButton).Activated:Connect(function()
		if callbacks and face == "aboard" and isLeader then
			callbacks.onDepartNow()
		end
	end)

	;(actionButton :: TextButton).Activated:Connect(function()
		local handlers = callbacks
		if not handlers then
			return
		end
		if face == "create" then
			-- a party too big for Normal is Hard whatever the buttons say; the server decides again anyway
			local _, closed = Danger.modeFor(partySize, wantsHard, tiers())
			handlers.onCreate(if stepper then stepper.get() else partySize, wantsHard or closed)
		elseif face == "join" then
			handlers.onJoin()
		elseif face == "aboard" then
			handlers.onLeave()
		end
	end)
end

--============================================================================
-- Faces
--============================================================================

-- Redraws the mode buttons, the hint and the Danger preview of the create face from the party size, the chosen
-- mode and the caller's own level.
function DepartureUI.refreshPreview()
	if face ~= "create" then
		return
	end
	local tier, closed = Danger.modeFor(partySize, wantsHard, tiers())
	local normal, hard = normalButton, hardButton
	if normal and hard then
		Components.setVariant(normal, if tier == "Normal" then "gold" else "ghost")
		Components.setVariant(hard, if tier == "Hard" then "danger" else "ghost")
		-- Normal is shut to a party too big for it: dim it, so it reads as unavailable, not as unchosen
		normal.BackgroundTransparency = if closed then 0.55 else 0
		local label = normal:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.TextTransparency = if closed then 0.55 else 0
		end
	end
	if modeHint then
		modeHint.Text = if closed
			then ("A party of %d or more fights only in Hard."):format(tiers()[1].maxPlayers + 1)
			elseif tier == "Hard" then "Hard: the dead are tougher and the spoils richer."
			else "Normal. A small party may choose Hard."
	end
	local d = Danger.compute({ yourLevel }, tier, rules())
	drawMeter(panelMeter, d, if d.veteran >= 0.5 or tier == "Hard" then dangerNote(d) .. "  ·  grows with who joins" else "Grows with the levels of who joins.")
end

function DepartureUI.setYourLevel(level: number?)
	yourLevel = if type(level) == "number" then math.max(1, level) else 1
	DepartureUI.refreshPreview()
end

-- The mode of a party already forming (join and aboard).
function DepartureUI.setPreviewTier(tier: string)
	if modeValue then
		modeValue.Text = tier:upper()
		modeValue.TextColor3 = tierColor(tier)
	end
end

local function setPanelVisible(visible: boolean)
	local root = panel
	if not root then
		return
	end
	root.Visible = visible
	if visible then
		local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = root
		fit()
		enterUntil = os.clock() + 0.45
		scale.Scale = fitScale - 0.08
		TweenService:Create(scale, Theme.Motion.Enter, { Scale = fitScale }):Play()
		task.delay(0.5, fit)
	end
end

local function setAction(text: string, variant: string, visible: boolean)
	local button = actionButton
	if not button then
		return
	end
	button.Visible = visible
	Components.setText(button, text)

	-- Repaint and resize for the variant without rebuilding the button, taking the
	-- label colour from the same table every other button uses — cream on deep green or burgundy.
	local spec = Components.Variants[variant] or Components.Variants.green
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(spec.top, spec.bottom)
	end
	Components.setTextColor(button, spec.text)

	local width = if variant == "green" then ACTION_WIDE else ACTION_NARROW
	TweenService:Create(button, Theme.Motion.Normal, {
		Size = UDim2.fromOffset(width, 58),
	}):Play()
end

local function setBottom(showRoster: boolean, showChip: boolean)
	if rosterCard then
		rosterCard.Visible = showRoster
	end
	if chip then
		chip.Visible = showChip
	end
	if departButton then
		-- Only the person who called the party may cut the wait short.
		departButton.Visible = face == "aboard" and isLeader
	end
end

-- The centre panel shows either the buttons (the caller choosing) or the plain mode (a party already forming).
local function setModeEditable(editable: boolean)
	if modeButtons then
		modeButtons.Visible = editable
	end
	if modeHint then
		modeHint.Visible = editable
	end
	if modeValue then
		modeValue.Visible = not editable
	end
end

-- `mode` is one of "hidden" | "create" | "join" | "aboard".
function DepartureUI.setFace(mode: string)
	face = mode

	if mode == "hidden" then
		setPanelVisible(false)
		setAction("", "green", false)
		setBottom(false, false)
		DepartureUI.setNotice(nil)
		return
	end

	if mode == "create" then
		setPanelVisible(true)
		if stepperGroup then
			stepperGroup.Visible = true
		end
		if subtitle then
			subtitle.Text = "Board the train to the Forgotten Lands"
		end
		setModeEditable(true)
		DepartureUI.refreshPreview()
		setAction("CREATE PARTY", "green", true)
		setBottom(false, false)
	elseif mode == "join" then
		setPanelVisible(true)
		if stepperGroup then
			-- The leader already chose the size; a joiner only accepts it.
			stepperGroup.Visible = false
		end
		if subtitle then
			subtitle.Text = "A party is forming in this wagon"
		end
		setModeEditable(false)
		setAction("JOIN PARTY", "green", true)
		setBottom(true, false)
	elseif mode == "aboard" then
		setPanelVisible(false)
		setAction("LEAVE", "danger", true)
		setBottom(true, true)
	end

	DepartureUI.setStatus(lastStatus)
end

-- A one-line message under the panel: departure failures, mostly. Passing nil
-- clears it.
function DepartureUI.setNotice(message: string?)
	local label = notice
	if not label then
		return
	end
	label.Text = message or ""
	label.Visible = message ~= nil
end

-- Feeds the live server state into whichever face is showing.
function DepartureUI.setStatus(status: Status)
	lastStatus = status

	local count = status.count or 0
	local capacity = status.capacity or 0
	local tier = status.tier or "Normal"
	local seconds = status.seconds or 0

	-- Boarding order is party order, so the first name is the leader.
	local members = if typeof(status.members) == "table" then status.members else {}
	isLeader = status.leader ~= nil and status.leader == localName

	if rosterText then
		local lines: { string } = {}
		local crew = if typeof(status.crew) == "table" then status.crew else {}
		local function escape(s: string): string
			return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
		end
		for index, name in members do
			local who = crew[index]
			local line = escape(name) .. (if index == 1 then "  (leader)" else "")
			if who and who.level then
				-- the name, and under it in a smaller, quieter hand:  Lv 12 · Sergeant · Might 5
				local might = if who.might == math.floor(who.might) then tostring(math.floor(who.might)) else ("%.1f"):format(who.might)
				line ..= ('\n<font size="17" color="#%s">Lv %d  ·  %s  ·  Might %s</font>'):format(
					Theme.Color.Muted:ToHex(),
					who.level,
					escape(tostring(who.title or "")),
					might
				)
			end
			table.insert(lines, line)
		end
		if status.partyMight and #members > 1 then
			table.insert(lines, ('<font size="17" color="#%s">Party Might %.1f of 10</font>'):format(Theme.Color.Gold:ToHex(), status.partyMight))
		end
		rosterText.Text = if #lines > 0 then table.concat(lines, "\n") else "—"
	end
	if departButton then
		departButton.Visible = face == "aboard" and isLeader
	end

	if wagonLabel then
		wagonLabel.Text = if status.wagon then ("WAGON %d"):format(status.wagon) else ""
	end

	if face == "join" or face == "aboard" then
		DepartureUI.setPreviewTier(tier)
		-- the figure the server worked out for who is really aboard
		if status.danger then
			drawMeter(panelMeter, status.danger)
			drawMeter(rosterMeter, status.danger)
		end
	end

	if timerLabel then
		if face == "join" then
			timerLabel.Text = ("%d / %d aboard  ·  departing in %s"):format(count, capacity, clock(seconds))
		elseif face == "create" then
			timerLabel.Text = "Choose your party size"
		end
	end

	if chip then
		chip.Text = ("%d / %d  ·  %s  ·  %s"):format(count, capacity, tier:upper(), clock(seconds))
	end
end

-- Countdown on the create panel's own window (how long the offer stands).
function DepartureUI.setWindow(seconds: number)
	if face == "create" and timerLabel then
		timerLabel.Text = ("Closing in %ds"):format(math.max(math.floor(seconds), 0))
	end
end

--============================================================================
-- Lifecycle
--============================================================================

function DepartureUI.mount(handlers: Callbacks, brandConfig: { Title: string?, Developer: string?, LogoAssetId: string? }?)
	callbacks = handlers
	if brandConfig then
		brand.Title = brandConfig.Title or brand.Title
		brand.Developer = brandConfig.Developer or brand.Developer
		brand.LogoAssetId = brandConfig.LogoAssetId or brand.LogoAssetId
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DepartureUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	localName = Players.LocalPlayer.Name

	screenGui = gui
	buildPanel(gui)
	buildBottomStack(gui)
	-- the panel's height changes with its face; the screen's with the window: keep it whole either way
	if panel then
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	DepartureUI.setFace("hidden")
end

return DepartureUI
