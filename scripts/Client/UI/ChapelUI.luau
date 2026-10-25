--!strict
--[[
	ChapelUI
	The Chapel screen in the Hub: four tabs, one for each thing the stash is FOR.

	  TITHE      bone dust for one pick from today's shelf of three
	  RELIQUARY  the charm you wear, and the blessing made for your next run
	  ALTAR      the star shards, one at a time, toward the Falling Star
	  JOURNAL    every page the party has copied out of the castle

	Presentation only: every price, shelf and result comes from the server (ChapelService) and
	every press is a request ("tithe", "charm", "forge", "offer"). The same forge look as the
	blacksmith's screen, so the Hub reads as one hand.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.ChapelUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local ChapelUI = {}

export type Need = { id: string, name: string, need: number, have: number }

local TABS = { "Tithe", "Reliquary", "Altar", "Journal" }

local onAction: ((action: string, id: string?) -> ())? = nil

local panel: Frame? = nil
local listFrame: Frame? = nil
local stashLabel: TextLabel? = nil
local noticeLabel: TextLabel? = nil
local tabButtons: { [string]: TextButton } = {}

local activeTab = "Tithe"
local lastState: any = nil
local reading: string? = nil -- the journal page that is open

local RANK_COLOUR = {
	Worn = Theme.Color.Parchment,
	Sound = Theme.Color.GreenBright,
	Hallowed = Theme.Color.EmberBright,
	Relic = Theme.Color.GoldBright,
}

--============================================================================
-- Small builders
--============================================================================

local function clearList()
	local list = listFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A wrapped block of text that grows to fit what it says.
local function text(parent: Instance, order: number, body: string, size: number, color: Color3, role: string?, align: Enum.TextXAlignment?): TextLabel
	local label = Components.label({
		Name = "Text",
		Text = body,
		Role = role,
		TextSize = size,
		TextColor = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, size + 6)
	return label
end

local function heading(order: number, body: string)
	text(listFrame :: Instance, order, body, Theme.TextSize.Small, Theme.Color.Gold, Theme.Role.Heading)
end

-- A row: the thing on the left, the one decision on the right.
local function row(order: number): (Frame, Frame)
	local frame = Components.panel({
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = order,
		Parent = listFrame,
	})
	frame.AutomaticSize = Enum.AutomaticSize.Y
	Theme.padding(frame, 14)

	local columns = Instance.new("UIListLayout")
	columns.FillDirection = Enum.FillDirection.Horizontal
	columns.SortOrder = Enum.SortOrder.LayoutOrder
	columns.VerticalAlignment = Enum.VerticalAlignment.Center
	columns.Padding = UDim.new(0, 12)
	columns.Parent = frame

	local details = Components.group({ Name = "Details", Size = UDim2.new(1, -210, 0, 0), LayoutOrder = 1, Parent = frame })
	details.AutomaticSize = Enum.AutomaticSize.Y
	Components.list(details, 2, Enum.HorizontalAlignment.Left)

	local action = Components.group({ Name = "Action", Size = UDim2.fromOffset(196, 50), LayoutOrder = 2, Parent = frame })
	Components.list(action, 4)
	return details, action
end

local function button(parent: Instance, label: string, variant: string, enabled: boolean, click: (() -> ())?)
	local b = Components.button({
		Name = "Do",
		Text = label,
		Variant = if enabled then variant else "ghost",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.fromOffset(190, 44),
		LayoutOrder = 1,
		Parent = parent,
	})
	if not enabled then
		Components.setTextColor(b, Theme.Color.Muted)
	end
	b.Activated:Connect(function()
		if enabled and click then
			click()
		end
	end)
end

local function request(action: string, id: string?)
	if onAction then
		onAction(action, id)
	end
end

local function needsLine(needs: { Need }): string
	local parts: { string } = {}
	for _, n in needs do
		table.insert(parts, ("%d %s (you have %d)"):format(n.need, n.name, n.have))
	end
	return table.concat(parts, ", ")
end

--============================================================================
-- Tabs
--============================================================================

local function drawTithe(state: any)
	local tithe = state.tithe
	heading(1, "THE TITHE")
	text(
		listFrame :: Instance,
		2,
		("Bring %s and take one thing from today's shelf. The shelf is the same for everyone, and it changes with the day."):format(needsLine(tithe.cost)),
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	for i, entry in tithe.shelf do
		local details, action = row(2 + i)
		text(details, 1, ("%s   x%d"):format(entry.name:upper(), entry.count), Theme.TextSize.Small, RANK_COLOUR[entry.rank] or Theme.Color.Parchment, Theme.Role.Heading)
		if entry.flavour then
			text(details, 2, entry.flavour, Theme.TextSize.Micro, Theme.Color.SteelLight)
		end
		text(
			details,
			3,
			if entry.to == "kit" then "Carried into your next run." else "Kept at home, in the stash.",
			Theme.TextSize.Micro,
			Theme.Color.Muted
		)
		button(action, "TAKE", "gold", tithe.can, function()
			request("tithe", entry.id)
		end)
	end
	if #state.carried > 0 then
		local parts: { string } = {}
		for _, k in state.carried do
			table.insert(parts, ("%s x%d"):format(k.name, k.count))
		end
		text(listFrame :: Instance, 20, "Waiting for your next run: " .. table.concat(parts, ", "), Theme.TextSize.Micro, Theme.Color.GreenBright)
	end
end

local function drawReliquary(state: any)
	local rel = state.reliquary
	heading(1, "THE CHARM")
	text(
		listFrame :: Instance,
		2,
		"One charm, worn run after run. Relics the party brought home can be worn here.",
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	local order = 2
	local anyCharm = false
	for _, charm in rel.charms do
		anyCharm = true
		order += 1
		local details, action = row(order)
		text(
			details,
			1,
			charm.name:upper(),
			Theme.TextSize.Small,
			if charm.owned then Theme.Color.GoldBright else Theme.Color.Muted,
			Theme.Role.Heading
		)
		if charm.use then
			text(details, 2, charm.use, Theme.TextSize.Micro, Theme.Color.SteelLight)
		end
		if charm.pending then
			text(details, 3, "Its effect is not yet wrought: it can be worn, and does nothing yet.", Theme.TextSize.Micro, Theme.Color.Muted)
		end
		if not charm.owned then
			button(action, "NOT FOUND", "ghost", false, nil)
		elseif charm.worn then
			button(action, "TAKE OFF", "ghost", true, function()
				request("charm", nil)
			end)
		else
			button(action, "WEAR", "gold", true, function()
				request("charm", charm.id)
			end)
		end
	end
	if not anyCharm then
		text(listFrame :: Instance, order + 1, "No charms are known.", Theme.TextSize.Micro, Theme.Color.Muted)
	end

	order += 1
	heading(order, "THE BLESSING")
	text(
		listFrame :: Instance,
		order + 1,
		"Made from the stash, and spent on your next run. One at a time.",
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	order += 1
	for _, recipe in rel.recipes do
		order += 1
		local details, action = row(order)
		text(details, 1, recipe.label:upper(), Theme.TextSize.Small, Theme.Color.EmberBright, Theme.Role.Heading)
		text(details, 2, recipe.use, Theme.TextSize.Micro, Theme.Color.SteelLight)
		text(details, 3, needsLine(recipe.needs), Theme.TextSize.Micro, Theme.Color.Muted)
		if recipe.waiting then
			button(action, "WAITING", "ghost", false, nil)
		else
			button(action, "MAKE", "gold", recipe.can, function()
				request("forge", recipe.id)
			end)
		end
	end
end

local function drawAltar(state: any)
	local altar = state.altar
	heading(1, "THE FALLING STAR")
	text(
		listFrame :: Instance,
		2,
		if altar.raised
			then "Nine shards lie on the altar and the star stands over it. It will be on your tabard in every place you go."
			else "Nine pieces of something that fell. Lay them here, one at a time, and what fell will stand again.",
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	local details, action = row(3)
	text(details, 1, ("%d OF %d LAID"):format(altar.offered, altar.goal), Theme.TextSize.Small, Theme.Color.GoldBright, Theme.Role.Heading)
	text(details, 2, ("Star shards in your stash: %d"):format(altar.shards), Theme.TextSize.Micro, Theme.Color.SteelLight)
	if altar.raised then
		button(action, "RAISED", "ghost", false, nil)
	else
		button(action, "LAY A SHARD", "gold", altar.shards > 0, function()
			request("offer", nil)
		end)
	end
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" }

local function drawJournal(state: any)
	heading(1, "THE JOURNAL")
	local found = 0
	for _, entry in state.journal do
		if entry.found then
			found += 1
		end
	end
	text(
		listFrame :: Instance,
		2,
		("%d of %d pages copied out. Each is a Deed done."):format(found, #state.journal),
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	for i, entry in state.journal do
		local details, action = row(2 + i)
		if entry.found then
			text(details, 1, entry.title:upper(), Theme.TextSize.Small, Theme.Color.GoldBright, Theme.Role.Heading)
			text(details, 2, ("%s  ·  %s"):format(entry.place, entry.sign), Theme.TextSize.Micro, Theme.Color.Muted)
			if reading == entry.id then
				for n, line in entry.lines do
					text(details, 2 + n, line, Theme.TextSize.Micro, Theme.Color.Parchment)
				end
			end
			button(action, if reading == entry.id then "CLOSE" else "READ", "gold", true, function()
				reading = if reading == entry.id then nil else entry.id
				ChapelUI.setState(lastState)
			end)
		else
			text(details, 1, "A PAGE NOT YET FOUND", Theme.TextSize.Small, Theme.Color.Muted, Theme.Role.Heading)
			text(details, 2, ("It was written in %s."):format(entry.place), Theme.TextSize.Micro, Theme.Color.Muted)
			button(action, ROMAN[i] or "—", "ghost", false, nil)
		end
	end
end

local DRAW = { Tithe = drawTithe, Reliquary = drawReliquary, Altar = drawAltar, Journal = drawJournal }

--============================================================================
-- Build
--============================================================================

local function selectTab(name: string)
	activeTab = name
	for tabName, b in tabButtons do
		Components.setTextColor(b, if tabName == name then Theme.Color.GoldBright else Theme.Color.Muted)
	end
	if lastState then
		lastState.notice = nil -- a line about the last thing done belongs to the tab it was done on
		ChapelUI.setState(lastState)
	end
end

local function build(parent: ScreenGui)
	local root = Components.panel({
		Name = "ChapelPanel",
		-- as tall as the screen allows (the list inside scrolls), never taller than it needs to be
		Size = UDim2.new(0, 760, 0.94, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(480, 360)
	constraint.MaxSize = Vector2.new(860, 700)
	constraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 10)
	Theme.shadow(root)

	Components.label({
		Name = "Title",
		Text = Components.spaced("THE CHAPEL"),
		Role = Theme.Role.Logo,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.GoldBright,
		LayoutOrder = 1,
		Parent = root,
	})

	stashLabel = Components.label({
		Name = "Stash",
		Text = "",
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Parchment,
		LayoutOrder = 2,
		Parent = root,
	})

	Components.divider(root, 3)

	local tabs = Components.group({ Name = "Tabs", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 4, Parent = root })
	Components.row(tabs, 8)
	for index, name in TABS do
		local b = Components.button({
			Name = name,
			Text = name:upper(),
			Variant = "ghost",
			TextSize = Theme.TextSize.Small,
			Size = UDim2.fromOffset(170, 42),
			LayoutOrder = index,
			Parent = tabs,
		})
		b.Activated:Connect(function()
			selectTab(name)
		end)
		tabButtons[name] = b
	end

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Content"
	-- what is left under the title, the tabs, the notice and the close button
	scroller.Size = UDim2.new(1, 0, 1, -300)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Gold
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.LayoutOrder = 5
	scroller.ZIndex = 3
	scroller.Parent = root
	Components.list(scroller, 8, Enum.HorizontalAlignment.Left)
	listFrame = scroller :: any

	noticeLabel = Components.label({
		Name = "Notice",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.EmberBright,
		LayoutOrder = 6,
		Parent = root,
	})

	local close = Components.button({
		Name = "Close",
		Text = "LEAVE THE CHAPEL",
		Variant = "ghost",
		TextSize = Theme.TextSize.Small,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 7,
		Parent = root,
	})
	close.Activated:Connect(function()
		ChapelUI.close()
	end)

	panel = root
	root.Visible = false
end

--============================================================================
-- API
--============================================================================

function ChapelUI.mount(handlers: { onAction: (string, string?) -> () })
	onAction = handlers.onAction

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChapelUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	build(gui)
	selectTab("Tithe")
end

function ChapelUI.setState(state: any)
	lastState = state
	if stashLabel then
		local stash = state.stash
		stashLabel.Text = ("BONE DUST %d      STAR SHARDS %d      PAGES %d"):format(stash.boneDust, stash.shards, stash.pages)
	end
	clearList()
	local draw = DRAW[activeTab]
	if draw then
		draw(state)
	end
	if noticeLabel then
		noticeLabel.Text = state.notice or ""
	end
end

function ChapelUI.open(tab: string?)
	local root = panel
	if not root then
		return
	end
	if tab and tabButtons[tab] then
		selectTab(tab)
	end
	reading = nil
	if noticeLabel then
		noticeLabel.Text = ""
	end
	root.Visible = true

	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	scale.Scale = 0.94
	TweenService:Create(scale, Theme.Motion.Enter, { Scale = 1 }):Play()
end

function ChapelUI.close()
	if panel then
		panel.Visible = false
	end
end

function ChapelUI.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

return ChapelUI
