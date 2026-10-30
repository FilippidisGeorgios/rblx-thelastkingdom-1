--!strict
--[[
	IconButton
	The small square buttons that sit on the edge of the screen (Settings, Profile, Inventory): a picture from
	`Icons` with a one-word caption under it, in a dark leather plate with a thin brass edge. It lifts a little when
	the cursor is on it, sinks when pressed, and says what it is even on a phone, where there is no cursor to hover.

	Presentation only: it reports a click and nothing else.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IconButton
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local IconButton = {}

export type Props = {
	Name: string?,
	Parent: Instance?,
	Icon: string,
	Caption: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	IconSize: number?,
	CaptionSize: number?,
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
	button.Size = props.Size or UDim2.fromOffset(54, 58)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.ZIndex = 2
	button.Parent = props.Parent
	Theme.surface(button, Theme.Color.Navy, Theme.Color.Void)
	Theme.corner(button, UDim.new(0, 8))
	local stroke = Theme.goldStroke(button, 1.4)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local iconSize = props.IconSize or 26
	local icon = Icons.create(props.Icon, {
		Size = iconSize,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
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

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -5)
	caption.Size = UDim2.new(1, -4, 0, (props.CaptionSize or 10) + 4)
	caption.BackgroundTransparency = 1
	caption.Text = props.Caption
	caption.TextSize = props.CaptionSize or 10
	caption.TextColor3 = Theme.Color.Parchment
	caption.ZIndex = 3
	caption.Parent = button
	Theme.applyFont(caption, Theme.Role.Strong)

	-- a small red-free dot or number in the corner (a prize waiting, say)
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

	local function pose(target: number, thickness: number, captionColor: Color3)
		TweenService:Create(scale, Theme.Motion.Fast, { Scale = target }):Play()
		TweenService:Create(stroke, Theme.Motion.Fast, { Thickness = thickness }):Play()
		TweenService:Create(caption, Theme.Motion.Fast, { TextColor3 = captionColor }):Play()
	end
	button.MouseEnter:Connect(function()
		pose(1.07, 2.2, Theme.Color.GoldBright)
	end)
	button.MouseLeave:Connect(function()
		pose(1, 1.4, Theme.Color.Parchment)
	end)
	button.MouseButton1Down:Connect(function()
		pose(0.93, 2.2, Theme.Color.GoldBright)
	end)
	button.MouseButton1Up:Connect(function()
		pose(1.07, 2.2, Theme.Color.GoldBright)
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
