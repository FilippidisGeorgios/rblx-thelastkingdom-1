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
	  sword, axe, mace, spear, bow   the weapons on the weapon bar
	  armour, quiver                 the one thing on the back

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
-- Run: a figure leaning into a stride, one leg reaching, one pushing off (the run button on a phone)
--============================================================================
function Icons.run(props: Props): Frame
	local r = root(props)
	r.Name = "Run"
	local cloth = props.Tint or Theme.Color.Parchment
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.5)
	local edge = dark:Lerp(Color3.new(0, 0, 0), 0.4)
	local px = math.max(1, (props.Size or 24) / 20)
	local function limb(x: number, y: number, w: number, h: number, rot: number, light: number?)
		local f = frame(r, x, y, w, h)
		f.Rotation = rot
		round(f, 0.4)
		shade(f, cloth:Lerp(Color3.new(1, 1, 1), light or 0), dark)
		stroke(f, edge, px)
	end
	limb(0.34, 0.74, 0.14, 0.4, 42) -- the back leg, pushing off
	limb(0.64, 0.72, 0.14, 0.38, -30) -- the front leg, reaching
	limb(0.32, 0.4, 0.11, 0.3, 60) -- the back arm
	limb(0.5, 0.45, 0.2, 0.42, 20, 0.1) -- the body, leaning in
	limb(0.68, 0.36, 0.11, 0.28, -50) -- the front arm
	local head = frame(r, 0.62, 0.15, 0.24, 0.24)
	round(head)
	shade(head, cloth:Lerp(Color3.new(1, 1, 1), 0.15), dark:Lerp(cloth, 0.3))
	stroke(head, edge, px)
	return r
end

--============================================================================
-- Roll: a body curled into a ball inside the turn it makes (the roll button on a phone)
--============================================================================
function Icons.roll(props: Props): Frame
	local r = root(props)
	r.Name = "Roll"
	local cloth = props.Tint or Theme.Color.Parchment
	local dark = cloth:Lerp(Color3.new(0, 0, 0), 0.5)
	local edge = dark:Lerp(Color3.new(0, 0, 0), 0.4)
	local px = math.max(1, (props.Size or 24) / 20)
	-- the turn: a ring, open at the top right, with the head of an arrow where it ends
	local ring = frame(r, 0.5, 0.5, 0.94, 0.94)
	ring.BackgroundTransparency = 1
	round(ring)
	stroke(ring, cloth, px * 1.6, 0.25)
	local tip = frame(r, 0.78, 0.13, 0.2, 0.08, cloth)
	tip.Rotation = 35
	round(tip, 0.4)
	local tip2 = frame(r, 0.88, 0.22, 0.2, 0.08, cloth)
	tip2.Rotation = -55
	round(tip2, 0.4)
	-- the ball: the back curved round, the knees in, the head tucked
	local back = frame(r, 0.48, 0.52, 0.46, 0.46)
	round(back)
	shade(back, cloth:Lerp(Color3.new(1, 1, 1), 0.1), dark)
	stroke(back, edge, px)
	local knees = frame(r, 0.6, 0.62, 0.22, 0.22)
	round(knees)
	shade(knees, cloth, dark)
	stroke(knees, edge, px)
	local head = frame(r, 0.36, 0.38, 0.2, 0.2)
	round(head)
	shade(head, cloth:Lerp(Color3.new(1, 1, 1), 0.15), dark:Lerp(cloth, 0.3))
	stroke(head, edge, px)
	return r
end

--============================================================================
-- Lantern: a hand lantern with its bail, the glass lit (the cover button in the King's Wood)
--============================================================================
function Icons.lantern(props: Props): Frame
	local r = root(props)
	r.Name = "Lantern"
	local iron = Color3.fromRGB(52, 46, 42)
	local glow = props.Tint or Color3.fromRGB(255, 214, 140)
	local px = math.max(1, (props.Size or 24) / 20)
	local bail = frame(r, 0.5, 0.14, 0.34, 0.16)
	bail.BackgroundTransparency = 1
	round(bail)
	stroke(bail, iron:Lerp(Color3.new(1, 1, 1), 0.35), px * 1.4)
	local cap = frame(r, 0.5, 0.3, 0.56, 0.12, iron:Lerp(Color3.new(1, 1, 1), 0.2))
	round(cap, 0.4)
	local glass = frame(r, 0.5, 0.58, 0.46, 0.42)
	shade(glass, glow:Lerp(Color3.new(1, 1, 1), 0.3), glow:Lerp(Color3.fromRGB(150, 80, 30), 0.5))
	stroke(glass, iron, px * 1.6)
	local flame = frame(r, 0.5, 0.6, 0.12, 0.2, Color3.fromRGB(255, 246, 210))
	round(flame)
	local foot = frame(r, 0.5, 0.84, 0.58, 0.1, iron:Lerp(Color3.new(1, 1, 1), 0.2))
	round(foot, 0.4)
	return r
end

--============================================================================
-- Weapons and gear (the weapon bar, UI/WeaponBar): each is drawn point up and to the right, as it lies on a rack
--============================================================================
local STEEL = Color3.fromRGB(196, 202, 210)
local STEEL_DARK = Color3.fromRGB(104, 110, 122)
local WOOD = Color3.fromRGB(150, 112, 70)
local WOOD_DARK = Color3.fromRGB(84, 58, 34)
local LEATHER = Color3.fromRGB(96, 66, 42)
local LEATHER_DARK = Color3.fromRGB(46, 30, 20)
local BLACK_EDGE = Color3.fromRGB(14, 12, 12)

local function bar(r: Frame, x: number, y: number, w: number, h: number, rot: number, top: Color3, bottom: Color3, px: number, roundness: number?): Frame
	local f = frame(r, x, y, w, h)
	f.Rotation = rot
	round(f, roundness or 0.3)
	shade(f, top, bottom)
	stroke(f, BLACK_EDGE, px)
	return f
end

-- Sword: blade, crossguard, grip, pommel
function Icons.sword(props: Props): Frame
	local r = root(props)
	r.Name = "Sword"
	local px = math.max(1, (props.Size or 24) / 22)
	bar(r, 0.57, 0.41, 0.12, 0.68, 45, STEEL, STEEL_DARK, px, 0.5)
	bar(r, 0.33, 0.65, 0.36, 0.09, 45, Theme.Color.Gold, Theme.Color.GoldDim, px)
	bar(r, 0.25, 0.73, 0.1, 0.2, 45, LEATHER, LEATHER_DARK, px)
	local pommel = frame(r, 0.17, 0.81, 0.14, 0.14)
	round(pommel)
	shade(pommel, Theme.Color.Gold, Theme.Color.GoldDim)
	stroke(pommel, BLACK_EDGE, px)
	return r
end

-- Axe: a haft and a bearded head
function Icons.axe(props: Props): Frame
	local r = root(props)
	r.Name = "Axe"
	local px = math.max(1, (props.Size or 24) / 22)
	bar(r, 0.48, 0.54, 0.1, 0.84, 35, WOOD, WOOD_DARK, px)
	bar(r, 0.7, 0.3, 0.34, 0.3, 35, STEEL, STEEL_DARK, px, 0.3)
	bar(r, 0.8, 0.42, 0.14, 0.22, 35, STEEL, STEEL_DARK, px, 0.4)
	return r
end

-- Mace: a haft and a flanged head
function Icons.mace(props: Props): Frame
	local r = root(props)
	r.Name = "Mace"
	local px = math.max(1, (props.Size or 24) / 22)
	bar(r, 0.44, 0.58, 0.1, 0.76, 40, WOOD, WOOD_DARK, px)
	bar(r, 0.72, 0.26, 0.34, 0.12, 40, STEEL, STEEL_DARK, px)
	bar(r, 0.72, 0.26, 0.12, 0.34, 40, STEEL, STEEL_DARK, px)
	local head = frame(r, 0.72, 0.26, 0.24, 0.24)
	round(head)
	shade(head, STEEL, STEEL_DARK)
	stroke(head, BLACK_EDGE, px)
	return r
end

-- Spear: a long shaft and a leaf head
function Icons.spear(props: Props): Frame
	local r = root(props)
	r.Name = "Spear"
	local px = math.max(1, (props.Size or 24) / 22)
	bar(r, 0.46, 0.58, 0.07, 0.9, 42, WOOD, WOOD_DARK, px)
	bar(r, 0.79, 0.21, 0.13, 0.3, 42, STEEL, STEEL_DARK, px, 0.5)
	bar(r, 0.68, 0.33, 0.12, 0.06, 42, LEATHER, LEATHER_DARK, px)
	return r
end

-- Bow: the stave's curve, the string, an arrow across it
function Icons.bow(props: Props): Frame
	local r = root(props)
	r.Name = "Bow"
	local px = math.max(1, (props.Size or 24) / 22)
	-- the curve: the left half of a tall ring
	local clip = frame(r, 0.3, 0.5, 0.46, 1)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	local ring = frame(clip, 1.04, 0.5, 1.24, 0.9)
	ring.BackgroundTransparency = 1
	round(ring)
	stroke(ring, WOOD, px * 2.6)
	local grip = frame(r, 0.255, 0.5, 0.08, 0.2, LEATHER_DARK)
	round(grip, 0.4)
	-- the string
	frame(r, 0.53, 0.5, math.max(0.03, 0.02), 0.84, Color3.fromRGB(226, 216, 190))
	-- the arrow
	bar(r, 0.5, 0.5, 0.7, 0.045, 0, WOOD, WOOD_DARK, px * 0.6)
	bar(r, 0.13, 0.5, 0.12, 0.12, 45, STEEL, STEEL_DARK, px * 0.8, 0.1)
	bar(r, 0.82, 0.5, 0.14, 0.14, 0, Theme.Color.Parchment, Theme.Color.Muted, px * 0.6, 0.2)
	return r
end

-- Quiver: a leather tube and the flights of three arrows
function Icons.quiver(props: Props): Frame
	local r = root(props)
	r.Name = "Quiver"
	local px = math.max(1, (props.Size or 24) / 22)
	for i, x in { 0.5, 0.6, 0.7 } do
		bar(r, x, 0.22 + i * 0.02, 0.04, 0.3, 14, WOOD, WOOD_DARK, px * 0.5)
		bar(r, x + 0.02, 0.14 + i * 0.02, 0.1, 0.14, 14, Theme.Color.Parchment, Theme.Color.Muted, px * 0.5, 0.3)
	end
	bar(r, 0.5, 0.62, 0.32, 0.64, 14, LEATHER, LEATHER_DARK, px, 0.25)
	bar(r, 0.57, 0.36, 0.36, 0.08, 14, Theme.Color.Gold, Theme.Color.GoldDim, px * 0.7)
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
--[[
	PICTURES (2026-11-14, the developer: "not the boring little sword and bow: sharper, wilder, darker"). A weapon kind
	with an uploaded picture (tools/blender/make_icons.py renders them from modelled weapons; assets/Icons/weapons) is
	shown as that picture; until a picture is uploaded, the drawn icon below stands in. Fill the ids here.
]]
Icons.PICTURES = {
	sword = "",
	spear = "",
	bow = "",
} :: { [string]: string }

local function picture(id: string, props: Props): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Picture"
	holder.BackgroundTransparency = 1
	local size = props.Size or 40
	holder.Size = UDim2.fromOffset(size, size)
	holder.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	holder.Position = props.Position or UDim2.new()
	holder.LayoutOrder = props.LayoutOrder or 0
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1.25, 1.25)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Image = id
	image.ScaleType = Enum.ScaleType.Fit
	if props.Tint then
		image.ImageColor3 = props.Tint
	end
	image.Parent = holder
	holder.Parent = props.Parent
	return holder
end

function Icons.create(kind: string, props: Props): Frame?
	local id = Icons.PICTURES[kind]
	if id and id ~= "" then
		return picture(id, props)
	end
	local make = (Icons :: any)[kind]
	if kind == "create" or type(make) ~= "function" then
		return nil
	end
	return make(props)
end

return Icons
