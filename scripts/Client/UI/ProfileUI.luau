--!strict
--[[
	ProfileUI
	The MUSTER ROLL: the player's own page, a parchment panel in the Hub.

	  the portrait, the nickname, the Company number, the rank and the level with its xp
	  THE ROAD  the prizes on the way to level 100 (one at every 5th level, a milestone at every 10th)
	  RENOWN    the whole player in one number, and what it is made of
	  MIGHT     the rating (out of ten, the best weapon) and what the difficulty does with it
	  ARMS      every weapon and how far it is forged
	  THE RECORD and STATISTICS   what they have done
	  THE COLLECTION  pages, shards on the altar, the stash; and the charm worn

	Presentation only: every number is built by the server (Server/Domain/PlayerCard) from this player's
	own profile and sent whole. The panel asks for it when it opens (ProfileController does the asking).
	Pictures: the avatar's head, and the same item pictures as the pack (UI/ItemArt).

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.ProfileUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local ItemArt = require(script.Parent.ItemArt)
local Icons = require(script.Parent.Icons)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local ProfileUI = {}

local panel: Frame? = nil
local content: Frame? = nil
local noticeLabel: TextLabel? = nil

local PORTRAIT = 112
local TILE_HEIGHT = 104
local STOP_HEIGHT = 46

--============================================================================
-- Small builders
--============================================================================

local function clear()
	local list = content
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

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
	text(content :: Instance, order, body, Theme.TextSize.Small, Theme.Color.Gold, Theme.Role.Heading)
end

-- A dark leather card that grows to fit what is put in it.
local function card(order: number, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Color.Ink
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.ZIndex = 2
	frame.Parent = content
	Theme.corner(frame, Theme.Size.CornerSmall)
	Theme.surface(frame, Theme.Color.NavyLight, Theme.Color.Ink)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.GoldDim
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	Theme.padding(frame, 14)
	return frame
end

local function framed(parent: Instance, size: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Picture"
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Theme.Color.Void
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.ZIndex = 3
	frame.Parent = parent
	Theme.corner(frame, Theme.Size.CornerSmall)
	Theme.surface(frame, Theme.Color.Navy, Theme.Color.Void)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Gold
	stroke.Thickness = 1.6
	stroke.Parent = frame
	return frame
end

-- A row of small squares, `filled` of `total` lit: forging, might.
local function pips(parent: Instance, order: number, filled: number, total: number, side: number, lit: Color3)
	local strip = Instance.new("Frame")
	strip.Name = "Pips"
	strip.Size = UDim2.new(1, 0, 0, side)
	strip.BackgroundTransparency = 1
	strip.LayoutOrder = order
	strip.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = strip
	for i = 1, total do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(side, side)
		cell.LayoutOrder = i
		cell.BorderSizePixel = 0
		cell.BackgroundColor3 = if i <= filled then lit else Theme.Color.Void
		cell.ZIndex = 3
		cell.Parent = strip
		local stroke = Instance.new("UIStroke")
		stroke.Color = if i <= filled then Theme.Color.GoldBright else Theme.Color.GoldDim
		stroke.Thickness = 1
		stroke.Transparency = if i <= filled then 0.3 else 0.5
		stroke.Parent = cell
	end
end

-- A bar filled to `fraction`; `height` defaults to a thick one.
local function bar(parent: Instance, order: number, fraction: number, fill: Color3, height: number?): Frame
	local trough = Instance.new("Frame")
	trough.Name = "Bar"
	trough.Size = UDim2.new(1, 0, 0, height or 14)
	trough.BackgroundColor3 = Theme.Color.Void
	trough.BorderSizePixel = 0
	trough.LayoutOrder = order
	trough.ZIndex = 3
	trough.Parent = parent
	Theme.corner(trough, Theme.Size.CornerSmall)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.GoldDim
	stroke.Thickness = 1.2
	stroke.Parent = trough
	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
	inner.BackgroundColor3 = fill
	inner.BorderSizePixel = 0
	inner.ZIndex = 4
	inner.Parent = trough
	Theme.corner(inner, Theme.Size.CornerSmall)
	Theme.surface(inner, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
	return trough
end

-- One figure with its name under it, and a picture when it has one. `across` tiles fit a row.
local function tile(parent: Instance, order: number, value: string, caption: string, itemId: string?, tone: Color3?, across: number?)
	local frame = Instance.new("Frame")
	frame.Name = caption
	frame.Size = UDim2.new(1 / (across or 3), -8, 0, TILE_HEIGHT)
	frame.BackgroundColor3 = Theme.Color.Ink
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.ZIndex = 2
	frame.Parent = parent
	Theme.corner(frame, Theme.Size.CornerSmall)
	Theme.surface(frame, Theme.Color.NavyLight, Theme.Color.Ink)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.GoldDim
	stroke.Thickness = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = frame
	Theme.padding(frame, 10)

	local left = 0
	if itemId == "coin" then
		-- gold is counted with a coin in the corner, not with a word
		Icons.coin({ Size = 26, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = frame })
	elseif itemId then
		local picture = Instance.new("Frame")
		picture.Size = UDim2.fromOffset(60, 60)
		picture.Position = UDim2.fromOffset(0, 2)
		picture.BackgroundColor3 = Theme.Color.Void
		picture.BorderSizePixel = 0
		picture.ZIndex = 3
		picture.Parent = frame
		Theme.corner(picture, Theme.Size.CornerSmall)
		ItemArt.mount(itemId, { Parent = picture, Size = UDim2.fromScale(1, 1), Zoom = 1.25 })
		left = 70
	end

	local number = Components.label({
		Name = "Value",
		Text = value,
		Role = Theme.Role.Heading,
		TextSize = Theme.TextSize.Heading,
		TextColor = tone or Theme.Color.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left, 0, 38),
		Parent = frame,
	})
	number.TextWrapped = false
	local caption_ = Components.label({
		Name = "Caption",
		Text = caption,
		TextSize = Theme.TextSize.Micro,
		TextColor = Theme.Color.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -left, 0, 44),
		Parent = frame,
	})
	caption_.TextYAlignment = Enum.TextYAlignment.Top
end

local function grid(order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Grid"
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = content
	local wrap = Instance.new("UIListLayout")
	wrap.FillDirection = Enum.FillDirection.Horizontal
	wrap.Wraps = true
	wrap.SortOrder = Enum.SortOrder.LayoutOrder
	wrap.Padding = UDim.new(0, 8)
	wrap.VerticalAlignment = Enum.VerticalAlignment.Top
	wrap.Parent = frame
	return frame
end

local function thousands(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function percent(fraction: number): string
	return ("%d%%"):format(math.floor(fraction * 100 + 0.5))
end

-- 3 h 20 m  /  12 m 05 s  /  45 s
local function duration(seconds: number): string
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return ("%d h %02d m"):format(seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return ("%d m %02d s"):format(seconds // 60, seconds % 60)
	end
	return ("%d s"):format(seconds)
end

local function plain(n: number): string
	return if n == math.floor(n) then tostring(math.floor(n)) else ("%.1f"):format(n)
end

--============================================================================
-- The page
--============================================================================

local function drawHeader(c: any, order: number)
	local frame = card(order, "Header")
	local across = Instance.new("UIListLayout")
	across.FillDirection = Enum.FillDirection.Horizontal
	across.SortOrder = Enum.SortOrder.LayoutOrder
	across.VerticalAlignment = Enum.VerticalAlignment.Top
	across.Padding = UDim.new(0, 16)
	across.Parent = frame

	local portrait = framed(frame, PORTRAIT, 1)
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.ZIndex = 4
	face.Parent = portrait
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and face.Parent then
			face.Image = image
		end
	end)

	local details = Components.group({ Name = "Details", Size = UDim2.new(1, -(PORTRAIT + 16), 0, 0), LayoutOrder = 2, Parent = frame })
	details.AutomaticSize = Enum.AutomaticSize.Y
	Components.list(details, 4, Enum.HorizontalAlignment.Left)

	local who = c.account
	local nick = if who.displayName ~= "" then who.displayName else Players.LocalPlayer.DisplayName
	local user = if who.name ~= "" then who.name else Players.LocalPlayer.Name
	text(details, 1, nick:upper(), Theme.TextSize.Heading, Theme.Color.GoldBright, Theme.Role.Heading)
	text(details, 2, ("@%s      %s"):format(user, who.id ~= "" and ("COMPANY NO. " .. who.id) or ""), Theme.TextSize.Micro, Theme.Color.SteelLight, Theme.Role.Strong)
	text(details, 3, c.title:upper(), Theme.TextSize.Small, Theme.Color.Gold, Theme.Role.Heading)
	text(
		details,
		4,
		if c.xpToNext > 0
			then ("LEVEL %d OF %d      %s XP TO THE NEXT"):format(c.level, c.maxLevel, thousands(math.ceil(c.xpToNext)))
			else ("LEVEL %d OF %d      THE HIGHEST RANK"):format(c.level, c.maxLevel),
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	bar(details, 5, c.xpFraction, Theme.Color.Gold)
	text(details, 6, ("%s XP earned in all      %s gold in the purse"):format(thousands(c.totalXp), thousands(c.gold)), Theme.TextSize.Micro, Theme.Color.Muted)
end

local function drawRoad(c: any, order: number)
	heading(order, "THE ROAD")
	local frame = card(order + 1, "Road")
	Components.list(frame, 8, Enum.HorizontalAlignment.Left)

	local lines: { string } = {}
	if c.nextReward then
		table.insert(lines, ("The next prize is at level %d, %d %s away."):format(c.nextReward.level, c.nextReward.away, if c.nextReward.away == 1 then "level" else "levels"))
	else
		table.insert(lines, "Every prize on the road has been reached.")
	end
	if c.nextTitle then
		table.insert(lines, ("The next rank, %s, comes at level %d."):format(c.nextTitle.name, c.nextTitle.level))
	end
	text(frame, 1, table.concat(lines, " "), Theme.TextSize.Micro, Theme.Color.Parchment)

	-- twenty stops, ten to a row: a prize at every 5th level, the big ones at the 10ths
	local strip = Instance.new("Frame")
	strip.Name = "Stops"
	strip.Size = UDim2.new(1, 0, 0, 0)
	strip.AutomaticSize = Enum.AutomaticSize.Y
	strip.BackgroundTransparency = 1
	strip.LayoutOrder = 2
	strip.Parent = frame
	local wrap = Instance.new("UIListLayout")
	wrap.FillDirection = Enum.FillDirection.Horizontal
	wrap.Wraps = true
	wrap.SortOrder = Enum.SortOrder.LayoutOrder
	wrap.Padding = UDim.new(0, 6)
	wrap.Parent = strip
	local nextLevel = if c.nextReward then c.nextReward.level else nil
	for i, stop in c.road do
		local box = Instance.new("Frame")
		box.Name = "Stop" .. stop.level
		box.Size = UDim2.new(0.1, -6, 0, STOP_HEIGHT)
		box.LayoutOrder = i
		box.BorderSizePixel = 0
		box.ZIndex = 3
		box.BackgroundColor3 = if stop.reached then (if stop.milestone then Theme.Color.GoldBright else Theme.Color.Gold) else Theme.Color.Void
		box.Parent = strip
		Theme.corner(box, Theme.Size.CornerSmall)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = if stop.milestone then 2.4 else 1.2
		stroke.Color = if stop.level == nextLevel then Theme.Color.GreenLight elseif stop.reached then Theme.Color.GoldBright else Theme.Color.GoldDim
		stroke.Parent = box
		local label = Components.label({
			Name = "Level",
			Text = tostring(stop.level),
			Role = Theme.Role.Heading,
			TextSize = if stop.milestone then Theme.TextSize.Small else Theme.TextSize.Micro,
			TextColor = if stop.reached then Theme.Color.Void else (if stop.milestone then Theme.Color.Gold else Theme.Color.Muted),
			Size = UDim2.fromScale(1, 1),
			Parent = box,
		})
		label.TextYAlignment = Enum.TextYAlignment.Center
	end
	text(
		frame,
		3,
		"Gold squares are reached. The large ones are milestones, a new rank every tenth level. The prizes themselves are still being forged.",
		Theme.TextSize.Micro,
		Theme.Color.Muted
	)
end

local function drawRenown(c: any, order: number)
	heading(order, "RENOWN")
	local r = c.renown
	local frame = card(order + 1, "Renown")
	Components.list(frame, 8, Enum.HorizontalAlignment.Left)
	text(
		frame,
		1,
		("%s of %s      %s"):format(thousands(r.total), thousands(r.max), string.upper(r.tier)),
		Theme.TextSize.Heading,
		Theme.Color.GoldBright,
		Theme.Role.Heading
	)
	bar(frame, 2, r.total / math.max(1, r.max), Theme.Color.Bronze, 16)
	if r.nextTier then
		text(frame, 3, ("%s more points make you %s."):format(thousands(r.toNext or 0), string.upper(r.nextTier)), Theme.TextSize.Micro, Theme.Color.SteelLight)
	else
		text(frame, 3, "There is no higher standing.", Theme.TextSize.Micro, Theme.Color.SteelLight)
	end

	-- what it is made of: every part is capped, so no one thing can make a standing
	local parts = Instance.new("Frame")
	parts.Name = "Parts"
	parts.Size = UDim2.new(1, 0, 0, 0)
	parts.AutomaticSize = Enum.AutomaticSize.Y
	parts.BackgroundTransparency = 1
	parts.LayoutOrder = 4
	parts.Parent = frame
	Components.list(parts, 6, Enum.HorizontalAlignment.Left)
	for i, part in r.parts do
		local line = Components.group({ Name = part.id, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = i, Parent = parts })
		line.AutomaticSize = Enum.AutomaticSize.Y
		Components.list(line, 3, Enum.HorizontalAlignment.Left)
		text(line, 1, ("%s      %s / %s"):format(string.upper(part.label), thousands(part.points), thousands(part.max)), Theme.TextSize.Micro, Theme.Color.Parchment, Theme.Role.Strong)
		bar(line, 2, part.points / math.max(1, part.max), Theme.Color.Gold, 8)
	end
	text(
		frame,
		5,
		"Renown is standing, not strength: it never changes how hard a run is. Each part has a ceiling, so no one thing can make a name.",
		Theme.TextSize.Micro,
		Theme.Color.Muted
	)
end

local function drawMight(c: any, order: number)
	heading(order, "MIGHT")
	local might = c.might
	local frame = card(order + 1, "Might")
	Components.list(frame, 8, Enum.HorizontalAlignment.Left)

	text(
		frame,
		1,
		("%s of %d      %s"):format(plain(might.rating), might.maxRating, string.upper(might.tier)),
		Theme.TextSize.Heading,
		Theme.Color.GoldBright,
		Theme.Role.Heading
	)
	pips(frame, 2, math.floor(might.rating + 0.5), might.maxRating, 22, Theme.Color.Gold)

	local weaponName = "your best weapon"
	local weapons = Config.get("Weapons")
	if might.bestId and weapons[might.bestId] then
		weaponName = weapons[might.bestId].DisplayName
	end
	text(
		frame,
		3,
		("Rated by %s, the arm you would actually swing. Owning more weapons never lowers it."):format(weaponName),
		Theme.TextSize.Micro,
		Theme.Color.Parchment
	)
	if might.multiplier - 1 < 0.005 then
		text(
			frame,
			4,
			"Nothing is forged yet. Every level bought at the Blacksmith makes you hit harder, and the dead grow only half as much for it.",
			Theme.TextSize.Micro,
			Theme.Color.SteelLight
		)
	else
		text(
			frame,
			4,
			("You strike %s harder than a fresh blade. The dead grow only %s for it, so you keep an edge of x%.2f."):format(
				percent(might.multiplier - 1),
				percent(might.enemyGrowth),
				might.edge
			),
			Theme.TextSize.Micro,
			Theme.Color.GreenBright
		)
	end
	text(
		frame,
		5,
		"A party is rated by the average of its people, so no one strong can carry the rest, nor one weak sink them.",
		Theme.TextSize.Micro,
		Theme.Color.Muted
	)
end

local function drawArms(c: any, order: number)
	heading(order, "ARMS")
	local frame = card(order + 1, "Arms")
	Components.list(frame, 10, Enum.HorizontalAlignment.Left)
	for i, arm in c.arms do
		local line = Components.group({ Name = arm.id, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = i, Parent = frame })
		line.AutomaticSize = Enum.AutomaticSize.Y
		Components.list(line, 4, Enum.HorizontalAlignment.Left)
		text(
			line,
			1,
			if arm.locked
				then ("%s      locked until level %d"):format(arm.name:upper(), arm.requiredLevel)
				else ("%s      +%d of %d"):format(arm.name:upper(), arm.level, arm.maxLevel),
			Theme.TextSize.Micro,
			if arm.locked then Theme.Color.Muted else Theme.Color.GoldBright,
			Theme.Role.Strong
		)
		pips(line, 2, if arm.locked then 0 else arm.level, arm.maxLevel, 14, Theme.Color.Bronze)
	end
end

local function drawRecord(c: any, order: number)
	heading(order, "THE RECORD")
	local g = grid(order + 1)
	local r, s = c.record, c.stats
	tile(g, 1, tostring(r.runsWon), "RUNS WON", nil, Theme.Color.GreenBright, 4)
	tile(g, 2, tostring(r.runsWiped), "RUNS LOST", nil, Theme.Color.BordeauxSoft, 4)
	tile(g, 3, if s.winRate then percent(s.winRate) else "-", "OF RUNS WON", nil, Theme.Color.GoldBright, 4)
	tile(g, 4, tostring(r.deeds), "DEEDS DONE", nil, Theme.Color.GoldBright, 4)

	heading(order + 2, "STATISTICS")
	local h = grid(order + 3)
	tile(h, 1, thousands(s.kills), "THE DEAD SLAIN", nil, Theme.Color.Parchment, 4)
	tile(h, 2, ("%d / %d"):format(s.eliteKills, s.bossKills), "ELITE / BOSS SLAIN", nil, Theme.Color.Parchment, 4)
	tile(h, 3, thousands(s.damageDealt), "DAMAGE DEALT", nil, Theme.Color.Parchment, 4)
	tile(h, 4, thousands(s.downs), "TIMES FALLEN", nil, Theme.Color.BordeauxSoft, 4)
	tile(h, 5, thousands(s.chambersCleared), "CHAMBERS CLEARED", nil, Theme.Color.Parchment, 4)
	tile(h, 6, if s.deepestChamber > 0 then tostring(s.deepestChamber) else "-", "DEEPEST CHAMBER", nil, Theme.Color.Parchment, 4)
	tile(h, 7, duration(s.playSeconds), "TIME IN THE CASTLE", nil, Theme.Color.Parchment, 4)
	tile(h, 8, if s.fastestWinSeconds then duration(s.fastestWinSeconds) else "-", "FASTEST VICTORY", nil, Theme.Color.GreenBright, 4)
	tile(h, 9, thousands(s.goldBanked), "GOLD BROUGHT HOME", "coin", Theme.Color.GoldBright, 4)
	tile(h, 10, thousands(r.bestRunGold), "BEST RUN (GOLD)", "coin", Theme.Color.GoldBright, 4)
	tile(h, 11, thousands(s.assists or 0), "ASSISTS", nil, Theme.Color.Parchment, 4)
	tile(h, 12, thousands(s.revives or 0), "FRIENDS RAISED", nil, Theme.Color.GreenBright, 4)
end

local function drawCollection(c: any, order: number)
	heading(order, "THE COLLECTION")
	local g = grid(order + 1)
	local k = c.collection
	tile(g, 1, ("%d / %d"):format(k.pagesFound, k.pagesTotal), "PAGES COPIED", "page", Theme.Color.Parchment)
	tile(
		g,
		2,
		if k.starRaised then "RAISED" else ("%d / %d"):format(k.shardsLaid, k.shardsGoal),
		if k.starRaised then "THE FALLING STAR" else "SHARDS LAID",
		"star_shard",
		Theme.Color.GoldBright
	)
	tile(g, 3, ("%d"):format(k.stashKinds), ("KINDS STASHED (%s IN ALL)"):format(thousands(k.stashTotal)), "bone_dust", Theme.Color.Parchment)

	-- the charm, with its picture
	local items = Config.get("Items")
	local frame = card(order + 2, "Charm")
	Components.list(frame, 6, Enum.HorizontalAlignment.Left)
	if c.charm and items[c.charm] then
		local across = Components.group({ Name = "Worn", Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 1, Parent = frame })
		Components.row(across, 14)
		local holder = framed(across, 72, 1)
		ItemArt.mount(c.charm, { Parent = holder, Size = UDim2.fromScale(1, 1), Zoom = 1.25 })
		local words = Components.group({ Name = "Words", Size = UDim2.new(1, -86, 1, 0), LayoutOrder = 2, Parent = across })
		Components.list(words, 2, Enum.HorizontalAlignment.Left)
		text(words, 1, "CHARM WORN", Theme.TextSize.Micro, Theme.Color.Gold, Theme.Role.Strong)
		text(words, 2, items[c.charm].DisplayName:upper(), Theme.TextSize.Small, Theme.Color.GoldBright, Theme.Role.Heading)
		if items[c.charm].Use then
			text(words, 3, items[c.charm].Use, Theme.TextSize.Micro, Theme.Color.SteelLight)
		end
	else
		text(frame, 1, "No charm is worn. The Reliquary in the chapel keeps them.", Theme.TextSize.Micro, Theme.Color.Muted)
	end
end

local function drawCard(c: any)
	clear()
	drawHeader(c, 1)
	drawRoad(c, 2)
	drawRenown(c, 4)
	drawMight(c, 6)
	drawArms(c, 8)
	drawRecord(c, 10)
	drawCollection(c, 15)
	text(
		content :: Instance,
		20,
		"This roll is yours alone: it is kept on your account and read by you only.",
		Theme.TextSize.Micro,
		Theme.Color.Muted,
		nil,
		Enum.TextXAlignment.Center
	)
end

--============================================================================
-- The panel
--============================================================================

local function build(parent: ScreenGui)
	local root = Components.panel({
		Name = "ProfilePanel",
		Size = UDim2.new(0, 760, 0.94, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(480, 360)
	constraint.MaxSize = Vector2.new(860, 760)
	constraint.Parent = root

	Theme.padding(root, Theme.Size.Pad)
	Components.list(root, 10)
	Theme.shadow(root)

	local title = Components.label({
		Name = "Title",
		Text = Components.spaced("THE MUSTER ROLL"),
		Role = Theme.Role.Logo,
		TextSize = Theme.TextSize.Heading,
		TextColor = Theme.Color.GoldBright,
		LayoutOrder = 1,
		Parent = root,
	})
	Components.closeButton(title, function()
		ProfileUI.close()
	end)
	Components.divider(root, 2)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Content"
	scroller.Size = UDim2.new(1, 0, 1, -110)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Color.Gold
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.LayoutOrder = 3
	scroller.ZIndex = 3
	scroller.Parent = root
	Components.list(scroller, 10, Enum.HorizontalAlignment.Left)
	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingLeft = UDim.new(0, 3)
	sidePad.PaddingRight = UDim.new(0, 6)
	sidePad.Parent = scroller
	content = scroller :: any

	noticeLabel = Components.label({
		Name = "Notice",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor = Theme.Color.EmberBright,
		LayoutOrder = 4,
		Parent = root,
	})

	panel = root
	root.Visible = false
end

--============================================================================
-- API
--============================================================================

function ProfileUI.mount()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ProfileUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	build(gui)
end

-- What the server answered: a card to draw, or "not yet".
function ProfileUI.setPayload(payload: any)
	if noticeLabel then
		noticeLabel.Text = ""
	end
	if payload.kind == "card" and typeof(payload.card) == "table" then
		drawCard(payload.card)
	elseif noticeLabel then
		noticeLabel.Text = "Your roll is not ready yet. Try again in a moment."
	end
end

function ProfileUI.open()
	local root = panel
	if not root then
		return
	end
	root.Visible = true
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	scale.Scale = 0.94
	TweenService:Create(scale, Theme.Motion.Enter, { Scale = 1 }):Play()
end

function ProfileUI.close()
	if panel then
		panel.Visible = false
	end
end

function ProfileUI.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

return ProfileUI
