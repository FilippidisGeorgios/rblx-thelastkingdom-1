--!strict
--[[
	CampUi
	The camp bench's panel: four rows, each a thing the bench can make, what it costs
	and what the player has of it, and a button. Nothing else (docs/systems/Spoils.md
	§6.1: "no UI beyond four buttons"): the same parchment as the pages and the pack,
	so the camp reads as part of the same hand.

	It closes on the button, on E or Escape, on a click outside it, and when the player
	walks away from the bench. It never pauses the world.

	Location: StarterPlayerScripts.Client.UI.CampUi (a library).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local CampUi = {}

local INK = Color3.fromRGB(52, 36, 24)
local INK_SOFT = Color3.fromRGB(104, 82, 58)
local PAPER = Color3.fromRGB(222, 206, 168)
local PAPER_EDGE = Color3.fromRGB(190, 168, 124)
local GOOD = Color3.fromRGB(86, 112, 68)
local DIM = Color3.fromRGB(150, 138, 116)

export type Need = { id: string, name: string, need: number, have: number }
export type Recipe = { id: string, label: string, needs: { Need }, makes: string, can: boolean }
export type Payload = { at: Vector3, reach: number, recipes: { Recipe }, made: string? }

export type Handle = {
	gui: ScreenGui,
	show: (payload: Payload) -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

function CampUi.create(onMake: (id: string) -> ()): Handle
	local gui = Instance.new("ScreenGui")
	gui.Name = "CampUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 19
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local veil = Instance.new("TextButton")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	veil.BackgroundTransparency = 0.55
	veil.AutoButtonColor = false
	veil.Text = ""
	veil.Parent = gui

	local page = Instance.new("Frame")
	page.Name = "Page"
	page.AnchorPoint = Vector2.new(0.5, 0.5)
	page.Position = UDim2.fromScale(0.5, 0.5)
	page.Size = UDim2.new(0, 460, 0.9, 0)
	page.BackgroundColor3 = PAPER
	page.BorderSizePixel = 0
	page.Parent = gui
	Theme.corner(page, UDim.new(0, 3))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 450)
	limit.MinSize = Vector2.new(300, 220)
	limit.Parent = page
	local edge = Instance.new("UIStroke")
	edge.Color = PAPER_EDGE
	edge.Thickness = 3
	edge.Parent = page
	Theme.padding(page, 26)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 26
	title.TextColor3 = INK
	title.Text = "The Camp Bench"
	title.Parent = page
	Theme.applyFont(title, Theme.Role.Heading)

	local note = Instance.new("TextLabel")
	note.Position = UDim2.fromOffset(0, 36)
	note.Size = UDim2.new(1, 0, 0, 20)
	note.BackgroundTransparency = 1
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextSize = 16
	note.TextColor3 = INK_SOFT
	note.Text = "What the bench can make from what you carried in."
	note.Parent = page
	Theme.applyFont(note, Theme.Role.Body)

	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(0, 62)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.BackgroundColor3 = INK_SOFT
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.Parent = page

	-- a scroll, so a short window still reaches every row
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 72)
	list.Size = UDim2.new(1, 0, 1, -72)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = INK_SOFT
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local at: Vector3? = nil
	local reach = 18
	local open = false
	local watcher: RBXScriptConnection? = nil

	local function close()
		open = false
		gui.Enabled = false
		if watcher then
			watcher:Disconnect()
			watcher = nil
		end
	end

	local function paint(payload: Payload)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		note.Text = if payload.made then ("Made: " .. payload.made .. ".") else "What the bench can make from what you carried in."
		for i, recipe in payload.recipes do
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, 72)
			row.BackgroundColor3 = PAPER_EDGE
			row.BackgroundTransparency = 0.55
			row.BorderSizePixel = 0
			row.Parent = list
			Theme.corner(row, UDim.new(0, 3))

			local name = Instance.new("TextLabel")
			name.Position = UDim2.fromOffset(12, 6)
			name.Size = UDim2.new(1, -130, 0, 26)
			name.BackgroundTransparency = 1
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextSize = 22
			name.TextColor3 = INK
			name.Text = recipe.label
			name.Parent = row
			Theme.applyFont(name, Theme.Role.Heading)

			local parts: { string } = {}
			for _, need in recipe.needs do
				table.insert(parts, ("%d %s (%d)"):format(need.need, need.name, need.have))
			end
			local cost = Instance.new("TextLabel")
			cost.Position = UDim2.fromOffset(12, 34)
			cost.Size = UDim2.new(1, -130, 0, 30)
			cost.BackgroundTransparency = 1
			cost.TextXAlignment = Enum.TextXAlignment.Left
			cost.TextYAlignment = Enum.TextYAlignment.Top
			cost.TextWrapped = true
			cost.TextSize = 15
			cost.TextColor3 = if recipe.can then INK_SOFT else Color3.fromRGB(128, 78, 60)
			cost.Text = table.concat(parts, ", ") .. "  >  " .. recipe.makes
			cost.Parent = row
			Theme.applyFont(cost, Theme.Role.Body)

			local button = Instance.new("TextButton")
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -10, 0.5, 0)
			button.Size = UDim2.fromOffset(100, 40)
			button.AutoButtonColor = recipe.can
			button.BackgroundColor3 = if recipe.can then GOOD else DIM
			button.TextColor3 = Color3.fromRGB(244, 236, 214)
			button.TextSize = 20
			button.Text = "Make"
			button.Active = recipe.can
			button.Parent = row
			Theme.corner(button, UDim.new(0, 3))
			Theme.applyFont(button, Theme.Role.Heading)
			button.Activated:Connect(function()
				if recipe.can then
					onMake(recipe.id)
				end
			end)
		end
	end

	veil.Activated:Connect(close)
	UserInputService.InputBegan:Connect(function(input, processed)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E) and not processed then
			close()
		end
	end)

	return {
		gui = gui,
		show = function(payload: Payload)
			at = payload.at
			reach = payload.reach
			paint(payload)
			if not open then
				open = true
				gui.Enabled = true
				watcher = RunService.Heartbeat:Connect(function()
					local character = Players.LocalPlayer.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if at and root and root:IsA("BasePart") and (root.Position - at).Magnitude > reach then
						close()
					end
				end)
			end
		end,
		close = close,
		isOpen = function()
			return open
		end,
	}
end

return CampUi
