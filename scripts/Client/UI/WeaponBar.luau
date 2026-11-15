--!strict
--[[
	WeaponBar
	The weapons a player carries, along the bottom of the screen (the developer, 2026-11-10: "not Roblox's own plain bar,
	a nice one; the mouse wheel chooses"). One small plate of blackened iron for each weapon (Theme.ironPlate, rivets
	in its corners) with its rendered picture and its number key; the one in hand is lifted, larger, edged like iron
	hot from the forge with a glow rising from its foot (2026-11-15: "darker, not for little children"), and its name
	is written above the bar for a moment when it is taken. The bow's plate counts its arrows (a dash when the quiver
	is not on the back).

	Presentation only. It draws what it is given (`set`, `setArrows`) and reports a plate that was pressed (`onPick`):
	the controller (Controllers/CombatController) turns the wheel and the number keys into the same thing, and the
	server decides what is in the hand.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.WeaponBar
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local WeaponBar = {}

export type Weapon = { id: string, name: string, kind: string }

export type Handle = {
	set: (weapons: { Weapon }, selected: number, drawn: boolean) -> (),
	setArrows: (count: number?, carried: boolean) -> (),
	onPick: (handler: (index: number) -> ()) -> (),
	setVisible: (on: boolean) -> (),
	destroy: () -> (),
}

local PLATE = 62
local GAP = 8
local MARGIN = 16
local PICTURE = 48
local EDGE = Theme.Iron.Edge
local HOT = Theme.Iron.Ember

type Slot = { button: TextButton, plate: Frame, stroke: UIStroke, scale: UIScale, heat: Frame, count: TextLabel?, kind: string }

function WeaponBar.create(gui: ScreenGui): Handle
	local root = Instance.new("Frame")
	root.Name = "WeaponBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -MARGIN)
	root.Size = UDim2.fromOffset(0, PLATE + 12)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = root

	-- the name of the weapon just taken, above the bar
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -(MARGIN + PLATE + 16))
	name.Size = UDim2.fromOffset(360, 20)
	name.BackgroundTransparency = 1
	name.TextSize = 16
	name.TextColor3 = Theme.Color.Cream
	name.TextTransparency = 1
	name.Text = ""
	name.Parent = gui
	Theme.applyFont(name, Theme.Role.Heading)
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Thickness = 1.5
	nameStroke.Transparency = 1
	nameStroke.Parent = name

	local slots: { Slot } = {}
	local shownIds = ""
	local shownSelected = -1
	local pick: ((number) -> ())? = nil
	local nameToken = 0
	local arrows: number? = nil
	local quiver = false

	local function drawCount()
		for _, slot in slots do
			local label = slot.count
			if label then
				label.Text = if not quiver then "–" elseif arrows then tostring(arrows) else ""
				label.TextColor3 = if quiver and (arrows or 0) > 0 then Theme.Color.GoldBright else Theme.Color.BordeauxSoft
			end
		end
	end

	local function build(weapons: { Weapon })
		for _, slot in slots do
			slot.button:Destroy()
		end
		table.clear(slots)
		for index, weapon in weapons do
			local button = Instance.new("TextButton")
			button.Name = "Slot" .. index
			button.Text = ""
			button.AutoButtonColor = false
			button.BackgroundTransparency = 1
			button.Size = UDim2.fromOffset(PLATE, PLATE + 12)
			button.LayoutOrder = index
			button.Parent = root

			local plate = Instance.new("Frame")
			plate.Name = "Plate"
			plate.AnchorPoint = Vector2.new(0.5, 1)
			plate.Position = UDim2.new(0.5, 0, 1, 0)
			plate.Size = UDim2.fromOffset(PLATE, PLATE)
			plate.BackgroundColor3 = Theme.Iron.Black
			plate.BackgroundTransparency = 0.1
			plate.BorderSizePixel = 0
			plate.Parent = button
			Theme.corner(plate, UDim.new(0, 3))
			Theme.ironPlate(plate, 10)
			local stroke = Instance.new("UIStroke")
			stroke.Color = EDGE
			stroke.Thickness = 1.2
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = plate
			local scale = Instance.new("UIScale")
			scale.Parent = plate

			-- the forge's glow, rising from the foot of the plate of the weapon in hand (off until then)
			local heat = Instance.new("Frame")
			heat.Name = "Heat"
			heat.AnchorPoint = Vector2.new(0, 1)
			heat.Position = UDim2.fromScale(0, 1)
			heat.Size = UDim2.fromScale(1, 0.75)
			heat.BackgroundColor3 = HOT
			heat.BackgroundTransparency = 1
			heat.BorderSizePixel = 0
			heat.ZIndex = 2
			heat.Parent = plate
			local heatFade = Instance.new("UIGradient")
			heatFade.Rotation = 90
			heatFade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.62),
			})
			heatFade.Parent = heat

			local icon = Icons.create(weapon.kind, { Size = PICTURE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Parent = plate })
				or Icons.create("sword", { Size = PICTURE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Parent = plate })
			if icon then
				icon.ZIndex = 3
			end

			local key = Instance.new("TextLabel")
			key.Name = "Key"
			key.BackgroundTransparency = 1
			key.Position = UDim2.fromOffset(5, 2)
			key.Size = UDim2.fromOffset(14, 14)
			key.TextSize = 12
			key.TextColor3 = Theme.Iron.Bone
			key.TextTransparency = 0.25
			key.Text = tostring(index)
			key.ZIndex = 4
			key.Parent = plate
			Theme.applyFont(key, Theme.Role.Strong)

			local count: TextLabel? = nil
			if weapon.kind == "bow" then
				local made = Instance.new("TextLabel")
				made.Name = "Arrows"
				made.BackgroundTransparency = 1
				made.AnchorPoint = Vector2.new(1, 1)
				made.Position = UDim2.new(1, -5, 1, -2)
				made.Size = UDim2.fromOffset(26, 14)
				made.TextXAlignment = Enum.TextXAlignment.Right
				made.TextSize = 13
				made.ZIndex = 4
				made.Parent = plate
				Theme.applyFont(made, Theme.Role.Strong)
				count = made
			end

			button.Activated:Connect(function()
				if pick then
					pick(index)
				end
			end)
			slots[index] = { button = button, plate = plate, stroke = stroke, scale = scale, heat = heat, count = count, kind = weapon.kind }
		end
		drawCount()
	end

	local handle = {} :: Handle

	function handle.set(weapons: { Weapon }, selected: number, drawn: boolean)
		local ids = ""
		for _, weapon in weapons do
			ids ..= weapon.id .. ","
		end
		if ids ~= shownIds then
			shownIds = ids
			shownSelected = -1
			build(weapons)
		end
		root.Visible = #weapons > 0
		local inHand = if drawn then selected else 0
		if inHand == shownSelected then
			return
		end
		shownSelected = inHand
		for index, slot in slots do
			local on = index == inHand
			TweenService:Create(slot.scale, Theme.Motion.Normal, { Scale = if on then 1.12 else 1 }):Play()
			TweenService:Create(slot.plate, Theme.Motion.Normal, { Position = UDim2.new(0.5, 0, 1, if on then -8 else 0) }):Play()
			TweenService:Create(slot.stroke, Theme.Motion.Normal, { Color = if on then HOT else EDGE, Thickness = if on then 2 else 1.2 }):Play()
			TweenService:Create(slot.heat, Theme.Motion.Normal, { BackgroundTransparency = if on then 0 else 1 }):Play()
		end
		-- its name, for a moment
		local weapon = weapons[inHand]
		nameToken += 1
		local mine = nameToken
		if weapon then
			name.Text = weapon.name
			TweenService:Create(name, TweenInfo.new(0.15), { TextTransparency = 0.05 }):Play()
			TweenService:Create(nameStroke, TweenInfo.new(0.15), { Transparency = 0.35 }):Play()
			task.delay(1.7, function()
				if nameToken == mine then
					TweenService:Create(name, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
					TweenService:Create(nameStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				end
			end)
		else
			TweenService:Create(name, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
			TweenService:Create(nameStroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		end
	end

	function handle.setArrows(count: number?, carried: boolean)
		arrows = count
		quiver = carried
		drawCount()
	end

	function handle.onPick(handler: (index: number) -> ())
		pick = handler
	end

	function handle.setVisible(on: boolean)
		root.Visible = on and #slots > 0
	end

	function handle.destroy()
		root:Destroy()
		name:Destroy()
	end

	return handle
end

return WeaponBar
