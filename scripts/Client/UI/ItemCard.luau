--!strict
--[[
	ItemCard
	One thing the player owns, as a card: its name, a picture of it, how many there are, and a small
	arrow that opens a box under the card saying what it is for and giving a tip.

	    NAME                                  [v]
	    [ picture ]   x 12     Sound
	    -------------------------------------------
	    FOR   what it is used for
	    TIP   a line of advice                      (only when the arrow is open)

	The card draws what it is told (a definition from configs/Items and a count). The rank colour comes
	from the caller (configs/Loot.Ranks), so one edit restyles every Sound item at once.

	Location: StarterPlayerScripts.Client.UI.ItemCard (a library).
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local ItemArt = require(script.Parent.ItemArt)

local ItemCard = {}

export type Props = {
	Parent: Instance?,
	ItemId: string,
	Def: any?,
	Count: number?,
	RankColour: Color3?,
	LayoutOrder: number?,
	-- Start with the box open.
	Open: boolean?,
	-- The card's width (default: the whole row).
	Width: UDim?,
	-- A word under the rank, in a colour of its own: a worn charm's state (READY / SPENT / WORN).
	Status: string?,
	StatusColour: Color3?,
}

local PICTURE = 92

local function label(parent: Instance, text: string, size: number, colour: Color3, role: string, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.LayoutOrder = order
	l.Parent = parent
	Theme.applyFont(l, role)
	return l
end

function ItemCard.create(props: Props): Frame
	local def = props.Def
	local rankColour = props.RankColour or Theme.Color.Parchment
	local name = if def and def.DisplayName then def.DisplayName else props.ItemId

	local card = Instance.new("Frame")
	card.Name = props.ItemId
	card.Size = UDim2.new(if props.Width then props.Width else UDim.new(1, -6), 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Color.Ink
	card.BorderSizePixel = 0
	card.LayoutOrder = props.LayoutOrder or 0
	card.ZIndex = 2
	card.Parent = props.Parent
	Theme.corner(card, Theme.Size.CornerSmall)
	Theme.surface(card, Theme.Color.NavyLight, Theme.Color.Ink)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rankColour
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	Theme.padding(card, 10)

	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 6)
	stack.Parent = card

	-- the name, and the arrow at the end of it
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.Parent = card

	local title = label(header, name:upper(), 20, rankColour, Theme.Role.Heading, 1)
	title.Size = UDim2.new(1, -36, 1, 0)
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local arrow = Instance.new("TextButton")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, 0, 0.5, 0)
	arrow.Size = UDim2.fromOffset(26, 26)
	arrow.BackgroundColor3 = Theme.Color.Navy
	arrow.AutoButtonColor = false
	arrow.Text = "v"
	arrow.TextSize = 16
	arrow.TextColor3 = Theme.Color.GoldBright
	arrow.ZIndex = 5
	arrow.Parent = header
	Theme.applyFont(arrow, Theme.Role.Strong)
	Theme.corner(arrow, Theme.Size.CornerSmall)
	Theme.goldStroke(arrow, 1.2)

	-- the picture, and what there is of it
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, PICTURE)
	body.BackgroundTransparency = 1
	body.LayoutOrder = 2
	body.Parent = card

	local frame = Instance.new("Frame")
	frame.Name = "Picture"
	frame.Size = UDim2.fromOffset(PICTURE, PICTURE)
	frame.BackgroundColor3 = Theme.Color.Void
	frame.BorderSizePixel = 0
	frame.ZIndex = 3
	frame.Parent = body
	Theme.corner(frame, Theme.Size.CornerSmall)
	Theme.surface(frame, Theme.Color.NavyLight, Theme.Color.Navy)
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Theme.Color.GoldDim
	frameStroke.Thickness = 1.2
	frameStroke.Parent = frame
	ItemArt.mount(props.ItemId, { Parent = frame, Size = UDim2.fromScale(1, 1), Zoom = 1.25 })

	if props.Count then
		local count = label(body, "x " .. tostring(props.Count), 34, Theme.Color.Cream, Theme.Role.Heading, 1)
		count.Position = UDim2.fromOffset(PICTURE + 16, 8)
		count.Size = UDim2.new(1, -(PICTURE + 16), 0, 40)
		count.TextWrapped = false
	end
	local rank = if def and def.Rank then def.Rank else "Worn"
	local rankLabel = label(body, rank:upper(), 14, rankColour, Theme.Role.Strong, 2)
	rankLabel.Position = UDim2.fromOffset(PICTURE + 16, if props.Count then 52 else 12)
	rankLabel.Size = UDim2.new(1, -(PICTURE + 16), 0, 18)
	rankLabel.TextWrapped = false
	if props.Status then
		local status = label(body, props.Status:upper(), 15, props.StatusColour or Theme.Color.GoldBright, Theme.Role.Strong, 3)
		status.Position = UDim2.fromOffset(PICTURE + 16, if props.Count then 74 else 36)
		status.Size = UDim2.new(1, -(PICTURE + 16), 0, 18)
		status.TextWrapped = false
	end

	-- the box under the arrow
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.Size = UDim2.new(1, 0, 0, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.BackgroundColor3 = Theme.Color.Void
	info.BackgroundTransparency = 0.25
	info.BorderSizePixel = 0
	info.LayoutOrder = 3
	info.Visible = false
	info.Parent = card
	Theme.corner(info, Theme.Size.CornerSmall)
	Theme.padding(info, 8)
	local infoList = Instance.new("UIListLayout")
	infoList.SortOrder = Enum.SortOrder.LayoutOrder
	infoList.Padding = UDim.new(0, 4)
	infoList.Parent = info

	local function line(heading: string, text: string, order: number)
		local l = label(info, "", 15, Theme.Color.Parchment, Theme.Role.Body, order)
		l.RichText = true
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Text = ('<font color="#%s"><b>%s</b></font>  %s'):format(Theme.Color.Gold:ToHex(), heading, text)
	end
	local use = if def then def.Use else nil
	local tip = if def then def.Tip else nil
	if use then
		line("FOR", use, 1)
	end
	if tip then
		line("TIP", tip, 2)
	end
	if def and def.Flavour then
		local flavour = label(info, '"' .. def.Flavour .. '"', 14, Theme.Color.Muted, Theme.Role.Body, 3)
		flavour.Size = UDim2.new(1, 0, 0, 0)
		flavour.AutomaticSize = Enum.AutomaticSize.Y
	end

	local open = props.Open == true
	local function show()
		info.Visible = open
		arrow.Text = if open then "^" else "v"
		card:SetAttribute("Open", open)
	end
	show()
	arrow.Activated:Connect(function()
		open = not open
		show()
	end)
	arrow.MouseEnter:Connect(function()
		TweenService:Create(arrow, Theme.Motion.Fast, { BackgroundColor3 = Theme.Color.NavyLight }):Play()
	end)
	arrow.MouseLeave:Connect(function()
		TweenService:Create(arrow, Theme.Motion.Fast, { BackgroundColor3 = Theme.Color.Navy }):Play()
	end)

	return card
end

return ItemCard
