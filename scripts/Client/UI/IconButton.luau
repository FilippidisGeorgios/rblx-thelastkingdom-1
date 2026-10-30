--!strict
--[[
	IconButton
	The small square buttons that sit on the edge of the screen (Settings, Profile, Inventory): a picture from `Icons`
	and NOTHING ELSE. No word, ever: the developer's rule for these buttons is that the picture says what it is.
	A black plate with a dark-grey edge; it lifts a little when the cursor is on it (the edge turns lighter) and
	sinks when pressed.

	Presentation only: it reports a click and nothing else.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IconButton
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local IconButton = {}

-- The plate and its edge: black and dark grey (the picture inside keeps its own colours).
local PLATE_TOP = Color3.fromRGB(30, 30, 33)
local PLATE_BOTTOM = Color3.fromRGB(5, 5, 7)
local EDGE = Color3.fromRGB(78, 78, 84)
local EDGE_LIT = Color3.fromRGB(132, 132, 140)

export type Props = {
	Name: string?,
	Parent: Instance?,
	Icon: string,
	Tint: Color3?, -- the picture's own colour, where it takes one (the cog is grey)
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	IconSize: number?,
	OnClick: (() -> ())?,
}

export type Handle = { button: TextButton, setBadge: (text: string?) -> () }

function IconButton.create(props: Props): Handle
	local button = Instance.new("TextButton")
	button.Name = props.Name or "IconButton"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.Position = props.Position or UDim2.new()
	button.Size = props.Size or UDim2.fromOffset(50, 50)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.04
	button.BorderSizePixel = 0
	button.ZIndex = 2
	button.Parent = props.Parent
	Theme.surface(button, PLATE_TOP, PLATE_BOTTOM)
	Theme.corner(button, UDim.new(0, 8))

	local stroke = Instance.new("UIStroke")
	stroke.Color = EDGE
	stroke.Thickness = 1.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local icon = Icons.create(props.Icon, {
		Size = props.IconSize or 28,
		Tint = props.Tint,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = button,
	})
	if icon then
		icon.ZIndex = 3
		for _, d in icon:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 3
			end
		end
	end

	-- a small gold number in the corner (a prize waiting, say): a number, not a word
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -4)
	badge.Size = UDim2.fromOffset(20, 20)
	badge.BackgroundColor3 = Theme.Color.Gold
	badge.TextColor3 = Theme.Color.Void
	badge.TextSize = 12
	badge.Visible = false
	badge.ZIndex = 5
	badge.Parent = button
	Theme.applyFont(badge, Theme.Role.Strong)
	Theme.corner(badge, UDim.new(0.5, 0))

	local function pose(target: number, thickness: number, edge: Color3)
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = target }):Play()
		TweenService:Create(stroke, Theme.Motion.Fast, { Thickness = thickness, Color = edge }):Play()
	end
	button.MouseEnter:Connect(function()
		pose(1.07, 2.2, EDGE_LIT)
	end)
	button.MouseLeave:Connect(function()
		pose(1, 1.6, EDGE)
	end)
	button.MouseButton1Down:Connect(function()
		pose(0.93, 2.2, EDGE_LIT)
	end)
	button.MouseButton1Up:Connect(function()
		pose(1.07, 2.2, EDGE_LIT)
	end)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end

	return {
		button = button,
		setBadge = function(text: string?)
			badge.Visible = text ~= nil
			badge.Text = text or ""
		end,
	}
end

return IconButton
