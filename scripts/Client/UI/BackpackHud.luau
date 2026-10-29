--!strict
--[[
	BackpackHud
	Two things about what you are carrying, and nothing else.

	  THE LOG   Bottom right, above the pack button: a few small lines that say
	            what you just picked up ("+2 Bone Dust", "+14 gold") and fade.
	            Like the area name it has no panel: bare letters with a thin
	            outline, coloured by rank, so a Sound find is VERDIGRIS and a
	            Relic is gold before the words are read. A Sound-or-better find
	            also gets its line of flavour, once.

	  THE PACK  A parchment panel (key B, or the small button for touch): the
	            stacks you carry, the gold, the charm, and what each thing is
	            FOR. This is the only place the economy is explained, so every
	            row says its use.

	It owns no state of its own: the controller hands it the server's `set` and
	`gain` messages and it draws them.

	Location: StarterPlayerScripts.Client.UI.BackpackHud (a library).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local ItemCard = require(script.Parent.ItemCard)

local BackpackHud = {}

local LOG_MARGIN = 28
local LOG_LINES = 6
local LINE_SECONDS = 3.6
local GOLD_SECONDS = 4

export type Handle = {
	gui: ScreenGui,
	set: (payload: any, items: any, ranks: any) -> (),
	gain: (payload: any, ranks: any) -> (),
	full: () -> (),
	toggle: () -> (),
	destroy: () -> (),
}

local function outline(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.25
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

--==========================================================================
function BackpackHud.create(): Handle
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "BackpackHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	--------------------------------------------------------------------------
	-- The button. Small, bottom right, always there: it is also the touch way in.
	--------------------------------------------------------------------------
	local button = Instance.new("TextButton")
	button.Name = "PackButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -LOG_MARGIN, 1, -LOG_MARGIN)
	button.Size = UDim2.fromOffset(46, 46)
	button.BackgroundColor3 = Theme.Color.Ink
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.Text = "PACK"
	button.TextSize = 11
	button.TextColor3 = Theme.Color.Gold
	button.Parent = gui
	Theme.applyFont(button, Theme.Role.Strong)
	Theme.corner(button)
	Theme.goldStroke(button, 1.2)

	--------------------------------------------------------------------------
	-- The log: lines stack upward from just above the button.
	--------------------------------------------------------------------------
	local logFrame = Instance.new("Frame")
	logFrame.Name = "Log"
	logFrame.AnchorPoint = Vector2.new(1, 1)
	logFrame.Position = UDim2.new(1, -LOG_MARGIN, 1, -(LOG_MARGIN + 54))
	logFrame.Size = UDim2.fromOffset(320, 160)
	logFrame.BackgroundTransparency = 1
	logFrame.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = logFrame

	local goldLine = Instance.new("TextLabel")
	goldLine.Name = "Gold"
	goldLine.AnchorPoint = Vector2.new(1, 1)
	goldLine.Position = UDim2.new(1, -(LOG_MARGIN + 54), 1, -(LOG_MARGIN + 6))
	goldLine.Size = UDim2.fromOffset(160, 24)
	goldLine.BackgroundTransparency = 1
	goldLine.TextXAlignment = Enum.TextXAlignment.Right
	goldLine.TextSize = 18
	goldLine.TextColor3 = Theme.Color.GoldBright
	goldLine.TextTransparency = 1
	goldLine.Text = ""
	goldLine.Parent = gui
	Theme.applyFont(goldLine, Theme.Role.Strong)
	local goldStroke = outline(goldLine)
	goldStroke.Transparency = 1

	--------------------------------------------------------------------------
	-- The pack panel.
	--------------------------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name = "Pack"
	-- Sits above the button it opens from, not over it.
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -LOG_MARGIN, 1, -(LOG_MARGIN + 54))
	-- as tall as the screen allows (the list scrolls), never taller than 600
	panel.Size = UDim2.new(0, 430, 0.78, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(430, 240)
	limit.MaxSize = Vector2.new(430, 600)
	limit.Parent = panel
	panel.BackgroundColor3 = Theme.Color.Ink
	panel.BackgroundTransparency = 0.06
	panel.Visible = false
	panel.Parent = gui
	Theme.corner(panel)
	Theme.surface(panel, Theme.Color.Navy, Theme.Color.Ink)
	Theme.goldStroke(panel, 1.6)
	Theme.padding(panel, 16)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 24
	title.TextColor3 = Theme.Color.Gold
	title.Text = "THE PACK"
	title.Parent = panel
	Theme.applyFont(title, Theme.Role.Heading)
	-- the way out: the red X in the corner
	Components.closeButton(title, function()
		panel.Visible = false
	end)

	local summary = Instance.new("TextLabel")
	summary.Name = "Summary"
	summary.Position = UDim2.fromOffset(0, 30)
	summary.Size = UDim2.new(1, 0, 0, 20)
	summary.BackgroundTransparency = 1
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextSize = 15
	summary.TextColor3 = Theme.Color.Muted
	summary.Text = ""
	summary.Parent = panel
	Theme.applyFont(summary, Theme.Role.Body)

	local rows = Instance.new("ScrollingFrame")
	rows.Name = "Rows"
	rows.Position = UDim2.fromOffset(0, 58)
	rows.Size = UDim2.new(1, 0, 1, -58)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 3
	rows.ScrollBarImageColor3 = Theme.Color.GoldDim
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.Parent = panel

	local rowList = Instance.new("UIListLayout")
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = rows

	--==========================================================================
	local lastItems: any = nil
	local lastRanks: any = nil
	local lastSet: any = nil

	local function clearRows()
		for _, child in rows:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function rankColour(rank: string?): Color3
		local def = lastRanks and rank and lastRanks[rank]
		return if def then def.Colour else Theme.Color.Parchment
	end

	local order = 0
	local function addRow(name: string, count: number?, use: string?, colour: Color3)
		order += 1
		local row = Instance.new("Frame")
		row.Name = name
		row.Size = UDim2.new(1, -6, 0, if use then 40 else 24)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = rows

		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(4, if use then 34 else 18)
		pip.Position = UDim2.fromOffset(0, 2)
		pip.BackgroundColor3 = colour
		pip.BorderSizePixel = 0
		pip.Parent = row

		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(12, 0)
		label.Size = UDim2.new(1, -60, 0, 20)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextSize = 17
		label.TextColor3 = colour
		label.Text = name
		label.Parent = row
		Theme.applyFont(label, Theme.Role.Strong)

		if count then
			local n = Instance.new("TextLabel")
			n.Position = UDim2.new(1, -48, 0, 0)
			n.Size = UDim2.fromOffset(48, 20)
			n.BackgroundTransparency = 1
			n.TextXAlignment = Enum.TextXAlignment.Right
			n.TextSize = 17
			n.TextColor3 = Theme.Color.Parchment
			n.Text = "x" .. tostring(count)
			n.Parent = row
			Theme.applyFont(n, Theme.Role.Strong)
		end

		if use then
			local u = Instance.new("TextLabel")
			u.Position = UDim2.fromOffset(12, 20)
			u.Size = UDim2.new(1, -12, 0, 18)
			u.BackgroundTransparency = 1
			u.TextXAlignment = Enum.TextXAlignment.Left
			u.TextSize = 13
			u.TextColor3 = Theme.Color.Muted
			u.Text = use
			u.Parent = row
			Theme.applyFont(u, Theme.Role.Body)
		end
	end

	local function heading(text: string)
		order += 1
		local h = Instance.new("TextLabel")
		h.Name = text
		h.Size = UDim2.new(1, 0, 0, 20)
		h.BackgroundTransparency = 1
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextSize = 13
		h.TextColor3 = Theme.Color.GoldDim
		h.Text = string.upper(text)
		h.LayoutOrder = order
		h.Parent = rows
		Theme.applyFont(h, Theme.Role.Strong)
	end

	local function redraw()
		-- keep the boxes the player had open
		local openIds: { [string]: boolean } = {}
		for _, child in rows:GetChildren() do
			if child:IsA("Frame") and child:GetAttribute("Open") == true then
				openIds[child.Name] = true
			end
		end
		clearRows()
		order = 0
		local set = lastSet
		local items = lastItems
		if not set or not items then
			return
		end
		summary.Text = ("%d of %d places used  -  %d gold"):format(set.used or 0, set.slots or 0, set.gold or 0)

		-- the charm worn this run, first (set by the Hub's Reliquary; the veil says whether it is spent)
		local worn = player:GetAttribute("Charm")
		if typeof(worn) == "string" and items[worn] then
			heading("Charm worn")
			local status, statusColour = "Worn", Theme.Color.GoldBright
			if worn == "mourners_veil" then
				if player:GetAttribute("VeilSpent") == true then
					status, statusColour = "Spent", Theme.Color.BordeauxSoft
				else
					status, statusColour = "Ready", Theme.Color.GreenLight
				end
			end
			order += 1
			ItemCard.create({
				Parent = rows,
				ItemId = worn,
				Def = items[worn],
				RankColour = rankColour(items[worn].Rank),
				LayoutOrder = order,
				Open = openIds[worn],
				Status = status,
				StatusColour = statusColour,
			})
			heading("In the pack")
		end

		-- Rank order first, then name, so the good things sit at the top.
		local rankOrder = { Relic = 1, Hallowed = 2, Sound = 3, Worn = 4 }
		local stacks: { { id: string, n: number } } = {}
		for id, n in set.stacks or {} do
			table.insert(stacks, { id = id, n = n })
		end
		table.sort(stacks, function(a, b)
			local ra = rankOrder[(items[a.id] and items[a.id].Rank) or "Worn"] or 5
			local rb = rankOrder[(items[b.id] and items[b.id].Rank) or "Worn"] or 5
			if ra ~= rb then
				return ra < rb
			end
			return a.id < b.id
		end)

		if #stacks == 0 then
			addRow("Nothing yet", nil, "What the dead leave behind will be here.", Theme.Color.Muted)
		else
			for _, s in stacks do
				local def = items[s.id]
				order += 1
				ItemCard.create({
					Parent = rows,
					ItemId = s.id,
					Def = def,
					Count = s.n,
					RankColour = rankColour(def and def.Rank or "Worn"),
					LayoutOrder = order,
					Open = openIds[s.id],
				})
			end
		end

		local hasCarried = false
		for _ in set.carried or {} do
			hasCarried = true
		end
		if hasCarried then
			heading("In your hands")
			for id, n in set.carried do
				local def = items[id]
				addRow(if def then def.DisplayName else id, n, if def then def.Use else nil, Theme.Color.Cream)
			end
		end
	end

	--==========================================================================
	-- The log
	--==========================================================================
	type Line = { label: TextLabel, count: number, name: string, token: number }
	local lines: { [string]: Line } = {}
	local lineOrder = 0
	local goldToken = 0
	local goldTotalShown = 0

	local function fadeAndRemove(key: string, line: Line, token: number)
		task.delay(LINE_SECONDS, function()
			if line.token ~= token or not line.label.Parent then
				return
			end
			lines[key] = nil
			TweenService:Create(line.label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local stroke = line.label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
			task.delay(0.45, function()
				line.label:Destroy()
			end)
		end)
	end

	local function pushLine(key: string, name: string, count: number, colour: Color3, sub: string?)
		local existing = lines[key]
		if existing and existing.label.Parent then
			existing.count += count
			existing.token += 1
			existing.label.Text = ("+%d %s"):format(existing.count, name)
			fadeAndRemove(key, existing, existing.token)
			return
		end

		lineOrder += 1
		local label = Instance.new("TextLabel")
		label.Name = key
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextSize = 18
		label.TextColor3 = colour
		label.TextTransparency = 1
		label.Text = ("+%d %s"):format(count, name)
		label.LayoutOrder = lineOrder
		label.Parent = logFrame
		Theme.applyFont(label, Theme.Role.Strong)
		local stroke = outline(label)
		stroke.Transparency = 1

		TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18), { Transparency = 0.25 }):Play()

		local line: Line = { label = label, count = count, name = name, token = 0 }
		lines[key] = line
		fadeAndRemove(key, line, 0)

		if sub then
			-- The flavour, once, as its own small line under the find.
			lineOrder += 1
			local flavour = Instance.new("TextLabel")
			flavour.Size = UDim2.new(1, 0, 0, 16)
			flavour.BackgroundTransparency = 1
			flavour.TextXAlignment = Enum.TextXAlignment.Right
			flavour.TextSize = 13
			flavour.TextColor3 = Theme.Color.Parchment
			flavour.TextTransparency = 1
			flavour.Text = sub
			flavour.LayoutOrder = lineOrder
			flavour.Parent = logFrame
			Theme.applyFont(flavour, Theme.Role.Body)
			local fs = outline(flavour)
			fs.Transparency = 1
			TweenService:Create(flavour, TweenInfo.new(0.3), { TextTransparency = 0.1 }):Play()
			TweenService:Create(fs, TweenInfo.new(0.3), { Transparency = 0.3 }):Play()
			task.delay(LINE_SECONDS + 1.4, function()
				if flavour.Parent then
					TweenService:Create(flavour, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
					TweenService:Create(fs, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					task.delay(0.55, function()
						flavour:Destroy()
					end)
				end
			end)
		end

		-- Never more than a handful: the oldest goes.
		local children = {}
		for _, child in logFrame:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(children, child)
			end
		end
		if #children > LOG_LINES then
			table.sort(children, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, #children - LOG_LINES do
				children[i]:Destroy()
			end
		end
	end

	local function showGold(total: number)
		goldToken += 1
		local token = goldToken
		goldTotalShown = total
		goldLine.Text = ("%d gold"):format(total)
		TweenService:Create(goldLine, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		TweenService:Create(goldStroke, TweenInfo.new(0.2), { Transparency = 0.25 }):Play()
		task.delay(GOLD_SECONDS, function()
			if goldToken == token then
				TweenService:Create(goldLine, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				TweenService:Create(goldStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end)
	end

	--==========================================================================
	local handle: Handle
	handle = {
		gui = gui,

		set = function(payload: any, items: any, ranks: any)
			lastSet = payload
			lastItems = items
			lastRanks = ranks
			if panel.Visible then
				redraw()
			end
			if typeof(payload.gold) == "number" and payload.gold ~= goldTotalShown then
				-- Only the change is news: the first set after joining is not.
				if goldTotalShown ~= 0 or payload.gold ~= 0 then
					showGold(payload.gold)
				end
			end
		end,

		gain = function(payload: any, ranks: any)
			lastRanks = ranks or lastRanks
			if payload.gold then
				pushLine("gold", "gold", payload.count, Theme.Color.GoldBright, nil)
				return
			end
			local colour = rankColour(payload.rank)
			local sub = if payload.rank ~= "Worn" and typeof(payload.flavour) == "string" then payload.flavour else nil
			pushLine(tostring(payload.item), tostring(payload.name), payload.count, colour, sub)
		end,

		full = function()
			pushLine("full", "Pack full", 0, Theme.Color.BordeauxSoft, nil)
			local line = lines["full"]
			if line then
				line.label.Text = "Your pack is full"
			end
		end,

		toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				redraw()
			end
		end,

		destroy = function()
			gui:Destroy()
		end,
	}

	button.MouseButton1Click:Connect(function()
		handle.toggle()
	end)

	-- the charm is an attribute the server sets at the gate (and the veil's spending): the pack follows it
	for _, name in { "Charm", "VeilSpent" } do
		player:GetAttributeChangedSignal(name):Connect(redraw)
	end

	return handle
end

return BackpackHud
