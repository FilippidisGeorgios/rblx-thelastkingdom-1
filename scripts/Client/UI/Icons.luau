--!strict
--[[
	Icons
	Small pictures for the interface, drawn from UI pieces (frames, corners, strokes, gradients) so there is no
	image asset to upload, nothing that can fail to load, and every one takes the Theme's metals and leathers:

	  coin       a gold coin with a raised rim and a diamond stamped on it (the gold, everywhere gold is counted)
	  gem        a cut stone (the day there is a second currency)
	  backpack   the pack: leather body, flap with a brass buckle, a pocket, a carrying loop
	  gear       a cog with eight teeth and a hole (Settings)
	  person     a head and shoulders (the Muster Roll)
	  laurel     a pair of leaves round a dot (the first place on the roll of honour)

	Every icon is a Frame of the size asked for that holds its parts at SCALE positions, so it can be any size.
	They have no click of their own: put one inside a button.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.Icons
]]

local Theme = require(script.Parent.Theme)

local Icons = {}

export type Props = { Size: number?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number?, Tint: Color3?, Parent: Instance? }

local function frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(f: Frame, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = f
end

local function stroke(f: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end

local function shade(f: Frame, top: Color3, bottom: Color3)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.surface(f, top, bottom)
end

local function root(props: Props): Frame
	local size = props.Size or 24
	local r = Instance.new("Frame")
	r.Name = "Icon"
	r.Size = UDim2.fromOffset(size, size)
	r.Position = props.Position or UDim2.new()
	r.AnchorPoint = props.AnchorPoint or Vector2.zero
	r.LayoutOrder = props.LayoutOrder or 0
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Parent = props.Parent
	return r
end

--============================================================================
-- Coin
--============================================================================
function Icons.coin(props: Props): Frame
	local r = root(props)
	r.Name = "Coin"
	local rim = frame(r, 0.5, 0.5, 1, 1)
	round(rim)
	shade(rim, Theme.Color.GoldBright, Theme.Color.Bronze)
	stroke(rim, Theme.Color.BronzeDark, math.max(1, (props.Size or 24) / 14))

	local face = frame(r, 0.5, 0.5, 0.74, 0.74)
	round(face)
	shade(face, Theme.Color.Gold, Theme.Color.GoldDim)
	stroke(face, Theme.Color.BronzeDark, math.max(1, (props.Size or 24) / 24), 0.3)

	-- the stamp: a diamond
	local mark = frame(r, 0.5, 0.5, 0.26, 0.26, Theme.Color.BronzeDark)
	mark.Rotation = 45
	local gleam = frame(r, 0.34, 0.3, 0.18, 0.1, Theme.Color.GoldBright)
	gleam.Rotation = -35
	gleam.BackgroundTransparency = 0.25
	round(gleam)
	return r
end

--============================================================================
-- Gem
--============================================================================
function Icons.gem(props: Props): Frame
	local r = root(props)
	r.Name = "Gem"
	local tint = props.Tint or Color3.fromRGB(150, 206, 232)
	local body = frame(r, 0.5, 0.52, 0.62, 0.62)
	body.Rotation = 45
	shade(body, tint:Lerp(Color3.new(1, 1, 1), 0.55), tint:Lerp(Color3.new(0, 0, 0), 0.35))
	stroke(body, tint:Lerp(Color3.new(0, 0, 0), 0.6), math.max(1, (props.Size or 24) / 16))
	local facet = frame(r, 0.5, 0.5, 0.3, 0.3, Color3.new(1, 1, 1))
	facet.Rotation = 45
	facet.BackgroundTransparency = 0.6
	local girdle = frame(r, 0.5, 0.52, 0.5, 0.04, Color3.new(1, 1, 1))
	girdle.BackgroundTransparency = 0.5
	return r
end

--============================================================================
-- Backpack
--============================================================================
function Icons.backpack(props: Props): Frame
	local r = root(props)
	r.Name = "Backpack"
	local leather = props.Tint or Theme.Color.Bronze
	local dark = leather:Lerp(Color3.new(0, 0, 0), 0.5)
	local px = math.max(1, (props.Size or 24) / 18)

	-- the loop to carry it by
	local loop = frame(r, 0.5, 0.13, 0.26, 0.2)
	loop.BackgroundTransparency = 1
	round(loop, 0.5)
	stroke(loop, dark, px * 1.4)

	-- the body
	local body = frame(r, 0.5, 0.58, 0.72, 0.7)
	round(body, 0.28)
	shade(body, leather:Lerp(Color3.new(1, 1, 1), 0.18), dark)
	stroke(body, dark:Lerp(Color3.new(0, 0, 0), 0.4), px)

	-- the pocket, stitched
	local pocket = frame(r, 0.5, 0.72, 0.46, 0.28)
	round(pocket, 0.3)
	shade(pocket, leather, dark:Lerp(leather, 0.3))
	stroke(pocket, Theme.Color.GoldDim, px * 0.8, 0.35)

	-- the flap over the top
	local flap = frame(r, 0.5, 0.36, 0.72, 0.3)
	round(flap, 0.45)
	shade(flap, leather:Lerp(Color3.new(1, 1, 1), 0.28), leather:Lerp(dark, 0.4))
	stroke(flap, dark:Lerp(Color3.new(0, 0, 0), 0.4), px)

	-- the brass buckle
	local buckle = frame(r, 0.5, 0.5, 0.15, 0.13)
	round(buckle, 0.25)
	shade(buckle, Theme.Color.GoldBright, Theme.Color.Gold)
	stroke(buckle, Theme.Color.BronzeDark, px * 0.8)
	return r
end

--============================================================================
-- Gear
--============================================================================
function Icons.gear(props: Props): Frame
	local r = root(props)
	r.Name = "Gear"
	local metal = props.Tint or Theme.Color.SteelLight
	local dark = metal:Lerp(Color3.new(0, 0, 0), 0.5)
	local px = math.max(1, (props.Size or 24) / 20)

	-- eight teeth, set round the rim
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local tooth = frame(r, 0.5 + math.sin(angle) * 0.36, 0.5 - math.cos(angle) * 0.36, 0.2, 0.3)
		tooth.Rotation = i * 45
		shade(tooth, metal, dark)
		round(tooth, 0.15)
	end

	local ring = frame(r, 0.5, 0.5, 0.66, 0.66)
	round(ring)
	shade(ring, metal:Lerp(Color3.new(1, 1, 1), 0.2), dark)
	stroke(ring, dark:Lerp(Color3.new(0, 0, 0), 0.4), px)

	local hole = frame(r, 0.5, 0.5, 0.26, 0.26, Theme.Color.Void)
	round(hole)
	stroke(hole, dark, px * 0.8)
	return r
end

--============================================================================
-- Person
--============================================================================
function Icons.person(props: Props): Frame
	local r = root(props)
	r.Name = "Person"
	r.ClipsDescendants = true
	local cloth = props.Tint or Theme.Color.Parchment
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.5)
	local px = math.max(1, (props.Size or 24) / 20)

	-- the shoulders, a pill whose lower half is cut off by the icon's own edge
	local shoulders = frame(r, 0.5, 0.98, 0.78, 0.66)
	round(shoulders, 0.5)
	shade(shoulders, cloth, dark)
	stroke(shoulders, dark:Lerp(Color3.new(0, 0, 0), 0.4), px)

	local head = frame(r, 0.5, 0.33, 0.42, 0.42)
	round(head)
	shade(head, cloth:Lerp(Color3.new(1, 1, 1), 0.15), dark:Lerp(cloth, 0.3))
	stroke(head, dark:Lerp(Color3.new(0, 0, 0), 0.4), px)
	return r
end

--============================================================================
-- Crouch: a figure ducking, head low, back bent, knees up (the crouch button on a phone)
--============================================================================
function Icons.crouch(props: Props): Frame
	local r = root(props)
	r.Name = "Crouch"
	local cloth = props.Tint or Theme.Color.Parchment
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.5)
	local edge = dark:Lerp(Color3.new(0, 0, 0), 0.4)
	local px = math.max(1, (props.Size or 24) / 20)

	-- the shin, standing; the thigh, going forward from the hip; the back, leaning over the knees
	local shin = frame(r, 0.72, 0.78, 0.15, 0.34)
	round(shin, 0.4)
	shade(shin, cloth, dark)
	stroke(shin, edge, px)
	local thigh = frame(r, 0.52, 0.6, 0.4, 0.17)
	round(thigh, 0.4)
	shade(thigh, cloth, dark)
	stroke(thigh, edge, px)
	local back = frame(r, 0.43, 0.42, 0.18, 0.4)
	back.Rotation = -28
	round(back, 0.4)
	shade(back, cloth:Lerp(Color3.new(1, 1, 1), 0.1), dark)
	stroke(back, edge, px)
	local head = frame(r, 0.55, 0.2, 0.25, 0.25)
	round(head)
	shade(head, cloth:Lerp(Color3.new(1, 1, 1), 0.15), dark:Lerp(cloth, 0.3))
	stroke(head, edge, px)
	return r
end

--============================================================================
-- Laurel
--============================================================================
function Icons.laurel(props: Props): Frame
	local r = root(props)
	r.Name = "Laurel"
	local gold = props.Tint or Theme.Color.GoldBright
	for side = -1, 1, 2 do
		for i = 0, 4 do
			-- five leaves a side, climbing from the foot and leaning in toward the middle
			local leaf = frame(r, 0.5 + side * (0.3 - i * 0.012), 0.84 - i * 0.15, 0.3, 0.15, gold:Lerp(Theme.Color.Bronze, i / 8))
			leaf.Rotation = side * (-35 - i * 11)
			round(leaf)
		end
	end
	local dot = frame(r, 0.5, 0.5, 0.18, 0.18, gold)
	round(dot)
	return r
end

--[[
	Puts a picture to the left of a label's CENTRED text and keeps it there as the text changes: a coin before the
	number of gold, a gem before the number of gems. The label must be centred (the default of Components.label).
	Returns the icon.
]]
function Icons.beside(label: TextLabel, kind: string, size: number): Frame?
	local icon = Icons.create(kind, { Size = size, AnchorPoint = Vector2.new(1, 0.5), Parent = label })
	if not icon then
		return nil
	end
	icon.ZIndex = label.ZIndex
	local function place()
		icon.Position = UDim2.new(0.5, -label.TextBounds.X / 2 - 6, 0.5, 0)
		icon.Visible = label.Text ~= ""
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(place)
	label:GetPropertyChangedSignal("Text"):Connect(place)
	place()
	return icon
end

--[[
	By name, for a caller that holds the kind in data. `kind` is one of the names above.
]]
function Icons.create(kind: string, props: Props): Frame?
	local make = (Icons :: any)[kind]
	if kind == "create" or type(make) ~= "function" then
		return nil
	end
	return make(props)
end

return Icons
