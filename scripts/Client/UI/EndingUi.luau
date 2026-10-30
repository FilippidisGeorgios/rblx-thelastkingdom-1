--!strict
--[[
	EndingUi
	The screen that closes on the end of the run: the world goes dark over a couple of seconds, the title
	comes up in gold, then a few lines, one at a time, each held long enough to read and let go, and last of
	all a small line in a quiet colour ("To be continued"). Nothing to press: it is the end, and it is gone
	when the party is taken back to the Hub.

	Plain on purpose, the same restraint as the parchment page: black, serif, gold only for the name of the
	game. It is the one place in the run where the player should do nothing but read.

	Location: StarterPlayerScripts.Client.UI.EndingUi (a library).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local EndingUi = {}

-- One line of the roll of honour (Server/Domain/Mvp): who, where they stand, the quiet line under the name, the
-- length of the thin bar (0..1 of the best), and whether they carry the laurel.
export type HonourRow = { userId: number, name: string, rank: number, line: string, share: number, mvp: boolean }

export type Payload = {
	title: string?,
	subtitle: string?,
	lines: { string }?,
	ledgerTitle: string?,
	ledger: { string }?,
	mvp: { HonourRow }?,
	footer: string?,
}

--[[
	The roll of honour of a won run: a short list in the middle of the dark, one row to a person. Plain and quiet,
	the same restraint as the rest of the card: a name, one line of what they did, a thin bar for how it compared,
	and a small laurel on the first place when there is more than one person. Your own row is a little brighter.
	Returns how long it stays (the server allows exactly this long, Server/World/RunSettlement.cardSeconds).
]]
local function honourRoll(gui: ScreenGui, rows: { HonourRow }): number
	local ROW_W, ROW_H = 520, 50
	local hold = math.clamp(#rows * 0.9 + 4, 6, 13)

	local heading = Instance.new("TextLabel")
	heading.AnchorPoint = Vector2.new(0.5, 0)
	heading.Position = UDim2.new(0.5, 0, 0.18, 0)
	heading.Size = UDim2.new(0.8, 0, 0, 36)
	heading.BackgroundTransparency = 1
	heading.Text = "THE ROLL OF HONOUR"
	heading.TextSize = 26
	heading.TextColor3 = Theme.Color.Gold
	heading.TextTransparency = 1
	heading.Parent = gui
	Theme.applyFont(heading, Theme.Role.Heading)
	TweenService:Create(heading, TweenInfo.new(1.4), { TextTransparency = 0 }):Play()

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.18, 52)
	holder.Size = UDim2.fromOffset(ROW_W, #rows * (ROW_H + 6))
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = holder

	local me = Players.LocalPlayer.UserId
	local made: { CanvasGroup } = {}
	for index, row in rows do
		local group = Instance.new("CanvasGroup")
		group.Name = "Row" .. index
		group.Size = UDim2.fromOffset(ROW_W, ROW_H)
		group.BackgroundTransparency = 1
		group.GroupTransparency = 1
		group.LayoutOrder = index
		group.Parent = holder

		-- the place: a laurel for the first of several, a plain numeral for the rest
		if row.mvp then
			Icons.laurel({ Size = 34, Position = UDim2.fromOffset(0, 4), Parent = group })
		else
			local place = Instance.new("TextLabel")
			place.Position = UDim2.fromOffset(0, 4)
			place.Size = UDim2.fromOffset(34, 28)
			place.BackgroundTransparency = 1
			place.Text = tostring(row.rank)
			place.TextSize = 22
			place.TextColor3 = Theme.Color.Muted
			place.Parent = group
			Theme.applyFont(place, Theme.Role.Heading)
		end

		local mine = row.userId == me
		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(46, 0)
		name.Size = UDim2.new(1, -46, 0, 26)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = row.name
		name.TextSize = 24
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = if row.mvp then Theme.Color.GoldBright elseif mine then Theme.Color.Cream else Color3.fromRGB(206, 194, 168)
		name.Parent = group
		Theme.applyFont(name, if row.mvp or mine then Theme.Role.Strong else Theme.Role.Body)

		local line = Instance.new("TextLabel")
		line.Position = UDim2.fromOffset(46, 26)
		line.Size = UDim2.new(1, -46, 0, 18)
		line.BackgroundTransparency = 1
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Text = row.line
		line.TextSize = 16
		line.TextColor3 = Theme.Color.Muted
		line.Parent = group
		Theme.applyFont(line, Theme.Role.Body)

		-- the thin bar: a rail, and over it a length of brass
		local rail = Instance.new("Frame")
		rail.Position = UDim2.new(0, 46, 1, -3)
		rail.Size = UDim2.new(1, -46, 0, 2)
		rail.BackgroundColor3 = Color3.fromRGB(60, 48, 36)
		rail.BorderSizePixel = 0
		rail.Parent = group
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(row.share, 0, 1), 1)
		fill.BackgroundColor3 = if row.mvp then Theme.Color.GoldBright else Theme.Color.GoldDim
		fill.BorderSizePixel = 0
		fill.Parent = rail

		table.insert(made, group)
	end

	task.spawn(function()
		for _, group in made do
			TweenService:Create(group, TweenInfo.new(0.5), { GroupTransparency = 0 }):Play()
			task.wait(0.3)
		end
		task.wait(hold - 0.3 * #made)
		TweenService:Create(heading, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
		for _, group in made do
			TweenService:Create(group, TweenInfo.new(1.2), { GroupTransparency = 1 }):Play()
		end
		task.wait(1.4)
		heading:Destroy()
		holder:Destroy()
	end)
	return hold + 1.4
end

function EndingUi.play(payload: Payload)
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndingUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui
	TweenService:Create(veil, TweenInfo.new(2.6, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 }):Play()

	local function label(text: string, size: number, color: Color3, role: string, y: number, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, y, 0)
		l.Size = UDim2.new(0.8, 0, 0, height)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.TextTransparency = 1
		l.TextWrapped = true
		l.Parent = gui
		Theme.applyFont(l, role)
		return l
	end

	local function show(l: TextLabel, seconds: number)
		TweenService:Create(l, TweenInfo.new(seconds), { TextTransparency = 0 }):Play()
	end
	local function hide(l: TextLabel, seconds: number)
		TweenService:Create(l, TweenInfo.new(seconds), { TextTransparency = 1 }):Play()
	end

	task.spawn(function()
		task.wait(3)
		local title = label(payload.title or "The Last Kingdom", 58, Theme.Color.GoldBright, Theme.Role.Heading, 0.3, 80)
		show(title, 2.4)
		if payload.subtitle then
			task.wait(1.2)
			local sub = label(payload.subtitle, 28, Theme.Color.Gold, Theme.Role.Body, 0.3, 40)
			sub.Position = UDim2.new(0.5, 0, 0.3, 82)
			show(sub, 2)
		end
		task.wait(4)
		hide(title, 1.6)
		for _, child in gui:GetChildren() do
			if child:IsA("TextLabel") and child ~= title then
				hide(child, 1.6)
			end
		end
		task.wait(2)
		for _, text in payload.lines or {} do
			local l = label(text, 30, Color3.fromRGB(226, 214, 188), Theme.Role.Body, 0.42, 120)
			show(l, 1.6)
			task.wait(math.max(3.6, #text / 14))
			hide(l, 1.4)
			task.wait(1.6)
			l:Destroy()
		end
		-- what this player carries home: a short list, held longer than a line
		if payload.ledger and #payload.ledger > 0 then
			local head = label(payload.ledgerTitle or "You carry home", 26, Theme.Color.Gold, Theme.Role.Heading, 0.22, 40)
			show(head, 1.4)
			local joined = table.concat(payload.ledger, string.char(10))
			local list = label(joined, 24, Color3.fromRGB(226, 214, 188), Theme.Role.Body, 0.3, 360)
			list.TextYAlignment = Enum.TextYAlignment.Top
			show(list, 1.6)
			task.wait(math.clamp(#payload.ledger * 0.9, 5, 14))
			hide(head, 1.2)
			hide(list, 1.2)
			task.wait(1.4)
		end
		-- the roll of honour of a won run, after what they carry home and before the last line
		if payload.mvp and #payload.mvp > 0 then
			task.wait(honourRoll(gui, payload.mvp))
			task.wait(1.4)
		end
		if payload.footer then
			local f = label(payload.footer, 24, Color3.fromRGB(150, 138, 118), Theme.Role.Body, 0.5, 40)
			show(f, 2.6)
		end
	end)
end

return EndingUi
