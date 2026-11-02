--!strict
--[[
	DocumentUi
	A page somebody wrote, laid on the screen: a recipe, a letter, a burial roll.

	A sheet of PAPYRUS (2026-11-02, the developer: "a yellow thing like paper, a little eaten at every edge, like a real
	papyrus, not a textbook"): warm yellow, the crossed fibres of the reed showing through, the colour uneven with age, darker
	toward the edges, and the edges themselves ragged, nibbled all round. All of it is built from frames on the screen, so it
	needs no picture. No frame of gold, no stroke, no round stains. Ink-brown letters, the writer's name at the foot. It is
	the game's one visual language for "this was written by a person" (docs/systems/AreaPlan.md).

	Two looks: the ordinary one, and `style = "dark"` (the catacombs): older and browner, the title in the creepy face in dried
	blood, the lines appearing one after another.

	It closes on the button, on E or Escape, and on a click anywhere outside it. It never pauses the world.

	Location: StarterPlayerScripts.Client.UI.DocumentUi (a library).
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local DocumentUi = {}

local INK = Color3.fromRGB(58, 36, 18)
local INK_SOFT = Color3.fromRGB(110, 80, 44)

-- the reed: light, mid and old yellow, and the brown of the edges
local LOOK = {
	plain = {
		light = Color3.fromRGB(240, 220, 160),
		mid = Color3.fromRGB(226, 198, 132),
		old = Color3.fromRGB(204, 170, 104),
		edge = Color3.fromRGB(150, 106, 52),
		fibre = Color3.fromRGB(178, 140, 78),
		edgeDepth = 0.5,
	},
	dark = {
		light = Color3.fromRGB(214, 184, 122),
		mid = Color3.fromRGB(194, 160, 98),
		old = Color3.fromRGB(160, 122, 70),
		edge = Color3.fromRGB(96, 62, 30),
		fibre = Color3.fromRGB(140, 104, 56),
		edgeDepth = 0.3,
	},
}

export type Handle = {
	gui: ScreenGui,
	open: (payload: { title: string?, sign: string?, lines: { string }?, style: string? }) -> (),
	close: () -> (),
	destroy: () -> (),
}

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function fade(target: Frame, rotation: number, from: number, to: number)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(from, to)
	g.Parent = target
end

function DocumentUi.create(): Handle
	local gui = Instance.new("ScreenGui")
	gui.Name = "DocumentUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The veil: a click on it closes the page.
	local veil = Instance.new("TextButton")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.AutoButtonColor = false
	veil.Text = ""
	veil.Parent = gui

	-- The page holds the sheet and its ragged rim; it has no look of its own.
	local page = Instance.new("Frame")
	page.Name = "Page"
	page.AnchorPoint = Vector2.new(0.5, 0.5)
	page.Position = UDim2.fromScale(0.5, 0.5)
	page.Size = UDim2.new(0, 470, 0, 590)
	page.BackgroundTransparency = 1
	page.Parent = gui

	-- the sheet is drawn in pixels; on a small screen (a phone on its side) the whole page is scaled down to fit
	local scaler = Instance.new("UIScale")
	scaler.Parent = page
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local view = camera.ViewportSize
			scaler.Scale = math.clamp(math.min((view.Y - 30) / 590, (view.X - 24) / 470), 0.45, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- The sheet is inset from the page; the rim pieces stand out of it into the inset, unevenly.
	local INSET = 9
	local sheet = frame(page, "Sheet", UDim2.fromOffset(INSET, INSET), UDim2.new(1, -2 * INSET, 1, -2 * INSET), Color3.new(1, 1, 1))
	sheet.ZIndex = 2
	sheet.ClipsDescendants = true
	local tone = Instance.new("UIGradient")
	tone.Rotation = 72
	tone.Parent = sheet

	-- age: two soft streaked washes across the sheet at different angles (no spots)
	local washes: { Frame } = {}
	for i, spec in { { 38, { 1, 0.86, 1, 0.9, 0.97, 0.84, 1 } }, { -64, { 0.93, 1, 0.88, 1, 0.92, 1 } } } do
		local w = frame(sheet, "Age" .. i, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(0, 0, 0))
		w.ZIndex = 3
		local keys = {}
		local n = #spec[2]
		for k, v in spec[2] do
			table.insert(keys, NumberSequenceKeypoint.new((k - 1) / (n - 1), v))
		end
		local g = Instance.new("UIGradient")
		g.Rotation = spec[1]
		g.Transparency = NumberSequence.new(keys)
		g.Parent = w
		table.insert(washes, w)
	end

	-- the reed's fibres: a layer across and a layer down, faint, uneven
	local rng = Random.new(1207)
	local fibres: { Frame } = {}
	for _ = 1, 46 do
		local y = rng:NextNumber(0, 0.995)
		-- (kept inside the sheet: a turned page does not clip what sticks out of it)
		local x = rng:NextNumber(0, 0.2)
		local f = frame(sheet, "FibreAcross", UDim2.new(x, 0, y, 0), UDim2.new(rng:NextNumber(0.4, 1 - x), 0, 0, rng:NextInteger(1, 2)), Color3.new(0, 0, 0), rng:NextNumber(0.72, 0.9))
		f.ZIndex = 3
		table.insert(fibres, f)
	end
	for _ = 1, 30 do
		local x = rng:NextNumber(0, 0.995)
		local y = rng:NextNumber(0, 0.2)
		local f = frame(sheet, "FibreDown", UDim2.new(x, 0, y, 0), UDim2.new(0, rng:NextInteger(1, 2), rng:NextNumber(0.4, 1 - y), 0), Color3.new(0, 0, 0), rng:NextNumber(0.82, 0.94))
		f.ZIndex = 3
		table.insert(fibres, f)
	end

	-- darker toward the edges (the old brown creeps in from the rim)
	local edgeBands: { Frame } = {}
	for _, spec in {
		{ UDim2.fromScale(0, 0), UDim2.new(0, 34, 1, 0), 0 },
		{ UDim2.new(1, -34, 0, 0), UDim2.new(0, 34, 1, 0), 180 },
		{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 34), 90 },
		{ UDim2.new(0, 0, 1, -34), UDim2.new(1, 0, 0, 34), 270 },
	} do
		local b = frame(sheet, "EdgeAge", spec[1], spec[2], Color3.new(0, 0, 0))
		b.ZIndex = 4
		table.insert(edgeBands, b)
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Parent = b
	end

	-- the ragged rim: pieces of the sheet's edge standing out into the inset by 0..INSET, of every width, contiguous, with now
	-- and then a gap (a bite). They are the edge's own colour, so the outline of the sheet is what is ragged.
	local rim: { Frame } = {}
	local function side(horizontal: boolean, outward: number)
		local along = 0
		local span = if horizontal then 452 else 572 -- the sheet's length along this side, in pixels
		while along < 1 do
			local w = math.min(rng:NextInteger(4, 15), math.max(1, math.floor((1 - along) * span)))
			local step = w / span
			local bite = rng:NextNumber() < 0.14
			if not bite then
				local h = math.floor(INSET * (rng:NextNumber() ^ 0.7)) + 1
				local p
				local s
				if horizontal then
					s = UDim2.fromOffset(w, h)
					-- (along the sheet: `along` 0..1 runs from INSET to the far INSET)
					p = if outward < 0 then UDim2.new(along, INSET - along * 2 * INSET, 0, INSET - h) else UDim2.new(along, INSET - along * 2 * INSET, 1, -INSET)
				else
					s = UDim2.fromOffset(h, w)
					p = if outward < 0 then UDim2.new(0, INSET - h, along, INSET - along * 2 * INSET) else UDim2.new(1, -INSET, along, INSET - along * 2 * INSET)
				end
				local piece = frame(page, "Rim", p, s, Color3.new(1, 1, 1))
				piece.ZIndex = 2
				table.insert(rim, piece)
			end
			along += step * (if bite then rng:NextNumber(0.6, 2.2) else 0.85)
		end
	end
	side(true, -1)
	side(true, 1)
	side(false, -1)
	side(false, 1)
	-- the writing sits inside the sheet with a margin
	local content = Instance.new("Frame")
	content.Name = "Writing"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 6
	content.Parent = sheet
	Theme.padding(content, 34)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 27
	title.TextColor3 = INK
	title.Text = ""
	title.ZIndex = 6
	title.Parent = content

	-- a rule drawn by hand: not quite level, not quite even
	local rule = frame(content, "Rule", UDim2.fromOffset(0, 42), UDim2.new(0.92, 0, 0, 2), INK_SOFT, 0.45)
	rule.Rotation = -0.6
	rule.ZIndex = 6

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 56)
	body.Size = UDim2.new(1, 0, 1, -114)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = INK_SOFT
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = 6
	body.Parent = content

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 7)
	list.Parent = body

	local sign = Instance.new("TextLabel")
	sign.Name = "Sign"
	sign.AnchorPoint = Vector2.new(1, 1)
	sign.Position = UDim2.new(1, 0, 1, -34)
	sign.Size = UDim2.new(1, 0, 0, 24)
	sign.BackgroundTransparency = 1
	sign.TextXAlignment = Enum.TextXAlignment.Right
	sign.TextSize = 18
	sign.TextColor3 = INK_SOFT
	sign.Font = Enum.Font.Fondamento
	sign.Text = ""
	sign.ZIndex = 6
	sign.Parent = content

	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.AnchorPoint = Vector2.new(0.5, 1)
	fold.Position = UDim2.new(0.5, 0, 1, 0)
	fold.Size = UDim2.fromOffset(150, 28)
	fold.BackgroundTransparency = 1
	fold.Text = "Fold it away"
	fold.TextSize = 16
	fold.TextColor3 = INK_SOFT
	fold.Font = Enum.Font.Fondamento
	fold.ZIndex = 6
	fold.Parent = content

	-- colours the whole sheet for a look
	local function dress(look: any)
		tone.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, look.light),
			ColorSequenceKeypoint.new(0.35, look.mid),
			ColorSequenceKeypoint.new(0.6, look.light:Lerp(look.mid, 0.6)),
			ColorSequenceKeypoint.new(1, look.old),
		})
		for _, w in washes do
			w.BackgroundColor3 = look.old:Lerp(look.edge, 0.4)
		end
		for _, f in fibres do
			f.BackgroundColor3 = look.fibre
		end
		for _, b in edgeBands do
			b.BackgroundColor3 = look.edge
			local g = b:FindFirstChildOfClass("UIGradient")
			if g then
				g.Transparency = NumberSequence.new(look.edgeDepth, 1)
			end
		end
		for _, r in rim do
			r.BackgroundColor3 = look.edge:Lerp(look.old, 0.45)
		end
	end
	dress(LOOK.plain)

	--==========================================================================
	local opened = false
	local handle: Handle

	local function close()
		if not opened then
			return
		end
		opened = false
		TweenService:Create(page, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.53),
		}):Play()
		task.delay(0.17, function()
			if not opened then
				gui.Enabled = false
			end
		end)
	end

	handle = {
		gui = gui,

		open = function(payload)
			for _, child in body:GetChildren() do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local dark = payload.style == "dark"
			dress(if dark then LOOK.dark else LOOK.plain)
			page.Rotation = if dark then (math.random() - 0.5) * 2.4 else (math.random() - 0.5) * 0.8
			if dark then
				title.Font = Enum.Font.Creepster
				title.TextColor3 = Color3.fromRGB(96, 10, 14)
				title.TextSize = 32
			else
				title.Font = Enum.Font.Fondamento
				title.TextColor3 = INK
				title.TextSize = 28
			end
			title.Text = payload.title or ""
			sign.Text = payload.sign or ""
			for i, line in payload.lines or {} do
				local label = Instance.new("TextLabel")
				label.Name = "Line"
				label.LayoutOrder = i
				label.Size = UDim2.new(1, -8, 0, 0)
				label.AutomaticSize = Enum.AutomaticSize.Y
				label.BackgroundTransparency = 1
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextYAlignment = Enum.TextYAlignment.Top
				label.TextWrapped = true
				label.TextSize = 20
				label.TextColor3 = if dark then Color3.fromRGB(40, 24, 12) else INK
				label.Font = Enum.Font.Fondamento
				label.Text = if line == "" then " " else line
				label.ZIndex = 6
				label.Parent = body
				if dark then
					-- the lines come up one after another, as a reader's eye finds them
					label.TextTransparency = 1
					TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.12 * i), { TextTransparency = 0 }):Play()
				end
			end
			opened = true
			gui.Enabled = true
			page.Position = UDim2.fromScale(0.5, 0.54)
			TweenService:Create(page, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5),
			}):Play()
		end,

		close = close,

		destroy = function()
			gui:Destroy()
		end,
	}

	veil.MouseButton1Click:Connect(close)
	fold.MouseButton1Click:Connect(close)
	UserInputService.InputBegan:Connect(function(input, _processed)
		if opened and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E) then
			close()
		end
	end)

	return handle
end

return DocumentUi
