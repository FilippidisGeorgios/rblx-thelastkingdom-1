--!strict
--[[
	DocumentUi
	A page somebody wrote, laid on the screen: a recipe, a letter, a burial roll.

	Parchment on a dark veil, ink-brown letters, the writer's name at the foot.
	Nothing else: no frame of gold, no glow. It is the game's one visual
	language for "this was written by a person" (docs/systems/AreaPlan.md), so
	it is plain on purpose, and it is the same page every time it appears.

	It closes on the button, on E or Escape, and on a click anywhere outside it.
	It never pauses the world: the dead do not wait for a reader, and a player
	who reads a recipe in the middle of a fight has chosen to.

	Location: StarterPlayerScripts.Client.UI.DocumentUi (a library).
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local DocumentUi = {}

local INK = Color3.fromRGB(52, 36, 24)
local INK_SOFT = Color3.fromRGB(104, 82, 58)
local PAPER = Color3.fromRGB(222, 206, 168)
local PAPER_EDGE = Color3.fromRGB(190, 168, 124)

export type Handle = {
	gui: ScreenGui,
	open: (payload: { title: string?, sign: string?, lines: { string }?, style: string? }) -> (),
	close: () -> (),
	destroy: () -> (),
}

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

	local page = Instance.new("Frame")
	page.Name = "Page"
	page.AnchorPoint = Vector2.new(0.5, 0.5)
	page.Position = UDim2.fromScale(0.5, 0.5)
	page.Size = UDim2.new(0, 460, 0, 560)
	page.BackgroundColor3 = PAPER
	page.BorderSizePixel = 0
	page.Parent = gui
	Theme.corner(page, UDim.new(0, 3))

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 640)
	limit.MinSize = Vector2.new(280, 320)
	limit.Parent = page

	local edge = Instance.new("UIStroke")
	edge.Color = PAPER_EDGE
	edge.Thickness = 3
	edge.Parent = page

	local grain = Instance.new("UIGradient")
	grain.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(232, 218, 182)),
		ColorSequenceKeypoint.new(0.5, PAPER),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 184, 142)),
	})
	grain.Rotation = 80
	grain.Parent = page

	Theme.padding(page, 30)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 26
	title.TextColor3 = INK
	title.Text = ""
	title.Parent = page
	Theme.applyFont(title, Theme.Role.Heading)

	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(0, 40)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.BackgroundColor3 = INK_SOFT
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.Parent = page

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 54)
	body.Size = UDim2.new(1, 0, 1, -112)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = INK_SOFT
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = page

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = body

	local sign = Instance.new("TextLabel")
	sign.Name = "Sign"
	sign.AnchorPoint = Vector2.new(1, 1)
	sign.Position = UDim2.new(1, 0, 1, -36)
	sign.Size = UDim2.new(1, 0, 0, 24)
	sign.BackgroundTransparency = 1
	sign.TextXAlignment = Enum.TextXAlignment.Right
	sign.TextSize = 17
	sign.TextColor3 = INK_SOFT
	sign.Text = ""
	sign.Parent = page
	Theme.applyFont(sign, Theme.Role.Body)

	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.AnchorPoint = Vector2.new(0.5, 1)
	fold.Position = UDim2.new(0.5, 0, 1, 0)
	fold.Size = UDim2.fromOffset(150, 28)
	fold.BackgroundTransparency = 1
	fold.Text = "Fold it away"
	fold.TextSize = 15
	fold.TextColor3 = INK_SOFT
	fold.Parent = page
	Theme.applyFont(fold, Theme.Role.Strong)

	--==========================================================================
	-- The DARK style (2026-11-02, the catacombs' pages): old, stained paper, the title in the creepy letters in dried blood,
	-- the body in a hand-written face, the page a little askew. Marks laid once and shown only in that style.
	local stains: { Frame } = {}
	for _, spec in {
		{ 0.76, 0.2, 60, Color3.fromRGB(88, 14, 16), 0.72 },
		{ 0.14, 0.72, 90, Color3.fromRGB(96, 70, 40), 0.86 },
		{ 0.6, 0.84, 36, Color3.fromRGB(70, 10, 14), 0.7 },
	} do
		local st = Instance.new("Frame")
		st.Name = "Stain"
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Position = UDim2.fromScale(spec[1] :: number, spec[2] :: number)
		st.Size = UDim2.fromOffset(spec[3] :: number, (spec[3] :: number) * 0.8)
		st.BackgroundColor3 = spec[4] :: Color3
		st.BackgroundTransparency = spec[5] :: number
		st.BorderSizePixel = 0
		st.Visible = false
		st.ZIndex = 0
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = st
		st.Parent = page
		table.insert(stains, st)
	end

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
			page.BackgroundColor3 = if dark then Color3.fromRGB(184, 160, 112) else PAPER
			grain.Color = if dark
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 124, 84)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 166, 118)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(128, 100, 66)),
				})
				else ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(232, 218, 182)),
					ColorSequenceKeypoint.new(0.5, PAPER),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 184, 142)),
				})
			edge.Color = if dark then Color3.fromRGB(84, 62, 38) else PAPER_EDGE
			page.Rotation = if dark then (math.random() - 0.5) * 3 else 0
			for _, st in stains do
				st.Visible = dark
			end
			if dark then
				title.Font = Enum.Font.Creepster
				title.TextColor3 = Color3.fromRGB(96, 10, 14)
				title.TextSize = 32
			else
				Theme.applyFont(title, Theme.Role.Heading)
				title.TextColor3 = INK
				title.TextSize = 26
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
				label.TextSize = if dark then 21 else 19
				label.TextColor3 = if dark then Color3.fromRGB(38, 26, 16) else INK
				label.Text = if line == "" then " " else line
				label.Parent = body
				if dark then
					label.Font = Enum.Font.Fondamento
					-- the lines come up one after another, as a reader's eye finds them
					label.TextTransparency = 1
					TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { TextTransparency = 0 }):Play()
				else
					Theme.applyFont(label, Theme.Role.Body)
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
