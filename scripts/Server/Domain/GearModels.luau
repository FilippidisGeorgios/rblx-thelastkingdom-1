--!strict
--[[
	GearModels
	Makes the things a player wears and carries (configs/Gear): the spear, the bow with its string and its nocked arrow,
	the quiver and the lantern's belt hook. Construction only: it is handed a body or nothing and gives
	back models; who has what, and when, is World/WeaponVisualService and World/GearService.

	WHERE THE SHAPES COME FROM. The sculpted pieces the dead already use (`ServerStorage.Assets.UndeadKitField`, made by
	tools/BuildUndeadKit from thousands of small cubes: the right look on a square body). A piece is a Model whose pivot
	is its origin; a weapon runs along its own +X from the grip. Where the kit is missing (a place that never had it) a
	plain stand-in of a few parts is made, so nothing is ever invisible.

	A WEAPON comes back as a Model and its HILT: a small unseen part AT THE GRIP whose +Y runs along the weapon (the same
	as the developer's sword and as a Roblox tool's Handle), with everything else welded to it. So "hold this" is one
	joint from a hand to the hilt, the same for every weapon. On the hilt:
	  spear   an attachment `Support` where the second hand closes
	  bow     `TipA`, `TipB` (the ends of the string), `Nock` (its middle: the clients move it as the bow is drawn),
	          two Beams that draw the string through the three, and an arrow (`Arrow`, joint `ArrowNock`) that the clients
	          show on the string while it is drawn

	Nothing made here collides, can be hit by a ray, or weighs anything (docs/systems/Realism.md: "the picture is not
	the hitbox").

	Location: ServerScriptService.Server.Domain.GearModels (the server builds with it; tools/PreviewPose uses it in Studio)
]]

local ServerStorage = game:GetService("ServerStorage")

local GearModels = {}

export type Six = { x: number, y: number, z: number, pitch: number, yaw: number, roll: number }

local WOOD = Color3.fromRGB(122, 96, 64)
local IRON = Color3.fromRGB(96, 94, 96)
local LEATHER = Color3.fromRGB(52, 38, 28)

-- Six plain numbers as a frame: a move, then pitch (X), yaw (Y), roll (Z).
function GearModels.frame(t: Six): CFrame
	return CFrame.new(t.x, t.y, t.z) * CFrame.Angles(math.rad(t.pitch), math.rad(t.yaw), math.rad(t.roll))
end

-- The sculpted kit, or nil in a place that has none.
function GearModels.kit(): Instance?
	local assets = ServerStorage:FindFirstChild("Assets")
	return assets and (assets:FindFirstChild("UndeadKitField") or assets:FindFirstChild("UndeadKit"))
end

local function quiet(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

local function block(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- One kit piece, scaled, with its pivot at `at` (world). Parts named in `skip` are left out. Nil if the kit has no such piece.
local function piece(kit: Instance?, name: string, scale: number, at: CFrame, skip: { [string]: boolean }?): Model?
	local source = kit and kit:FindFirstChild(name)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local made = source:Clone()
	for _, d in made:GetDescendants() do
		if d:IsA("BasePart") then
			if skip and skip[d.Name] then
				d:Destroy()
			else
				quiet(d)
			end
		elseif d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	if math.abs(scale - 1) > 1e-3 then
		made:ScaleTo(scale)
	end
	made:PivotTo(at)
	return made
end

-- Moves every part of `from` into `into`, welded to `anchor`.
local function absorb(from: Model, into: Instance, anchor: BasePart)
	for _, d in from:GetDescendants() do
		if d:IsA("BasePart") then
			d.Parent = into
			weld(anchor, d)
		end
	end
	from:Destroy()
end

local function attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

--==========================================================================
-- Weapons
--==========================================================================

-- The unseen part at the grip. Its +Y runs along the weapon (the weapon's own +X), its +Z is the weapon's +Z.
local function newHilt(model: Model, weaponFrame: CFrame, gripAt: number): Part
	local hilt = block("Hilt", Vector3.new(0.2, 0.2, 0.2), IRON, Enum.Material.SmoothPlastic, model)
	hilt.Transparency = 1
	hilt.CastShadow = false
	hilt.CFrame = weaponFrame * CFrame.new(gripAt, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
	model.PrimaryPart = hilt
	return hilt
end

local function standInSpear(model: Model, frame: CFrame, length: number)
	local shaft = block("Shaft", Vector3.new(length, 0.16, 0.16), WOOD, Enum.Material.Wood, model)
	shaft.CFrame = frame * CFrame.new(length / 2, 0, 0)
	local head = block("Head", Vector3.new(1.1, 0.3, 0.1), IRON, Enum.Material.Metal, model)
	head.CFrame = frame * CFrame.new(length + 0.5, 0, 0)
end

local function standInBow(model: Model, frame: CFrame, half: number)
	for i, s in { -1, 1 } do
		local limb = block("Limb" .. i, Vector3.new(half, 0.14, 0.2), WOOD, Enum.Material.Wood, model)
		limb.CFrame = frame * CFrame.new(s * half / 2, 0, 0.06) * CFrame.Angles(0, math.rad(s * 6), 0)
	end
	local grip = block("Grip", Vector3.new(0.6, 0.18, 0.24), LEATHER, Enum.Material.Fabric, model)
	grip.CFrame = frame
end

--[[
	Builds the weapon `def` (an entry of configs/Gear.Weapons that has a `Kit`). Returns the model and its hilt, both not
	yet in the world and at the origin: the caller makes the joint to a hand FIRST and parents the model after, so the
	weapon is never loose (an unanchored part with no joint is on the floor a frame later).
]]
function GearModels.weapon(weaponId: string, def: any): (Model, BasePart)
	local kit = GearModels.kit()
	local scale = def.Scale or 1
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weaponId
	local frame = CFrame.new()
	local hilt = newHilt(model, frame, def.GripAt or 0)

	local built = false
	for _, entry in def.Kit or {} do
		local at = frame * CFrame.new((entry.At :: CFrame).Position * scale) * (entry.At :: CFrame).Rotation
		local made = piece(kit, entry.Piece, scale, at, entry.Skip)
		if made then
			absorb(made, model, hilt)
			built = true
		end
	end
	if not built then
		if def.Kind == "bow" then
			standInBow(model, frame, (def.String and def.String.Half) or 2.6)
		else
			standInSpear(model, frame, 7)
		end
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d ~= hilt then
				weld(hilt, d)
			end
		end
	end

	if def.SupportAt then
		attachment(hilt, "Support", Vector3.new(0, def.SupportAt - (def.GripAt or 0), 0))
	end

	local str = def.String
	if str then
		-- the string: tip, middle, tip. The clients move the middle (Nock) back as the bow is drawn.
		local tipA = attachment(hilt, "TipA", Vector3.new(0, str.Half, str.Back))
		local tipB = attachment(hilt, "TipB", Vector3.new(0, -str.Half, str.Back))
		local nock = attachment(hilt, "Nock", Vector3.new(0, 0, str.Back))
		for name, pair in { StringA = { tipA, nock }, StringB = { nock, tipB } } do
			local beam = Instance.new("Beam")
			beam.Name = name
			beam.Attachment0 = pair[1]
			beam.Attachment1 = pair[2]
			beam.Width0 = str.Width
			beam.Width1 = str.Width
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Color = ColorSequence.new(str.Color)
			beam.LightEmission = 0
			beam.LightInfluence = 1
			beam.Transparency = NumberSequence.new(0)
			beam.Parent = hilt
		end
		-- the arrow on the string: unseen until a client draws the bow. Its own +X is its flight (the kit's frame), so
		-- it lies along the hilt's -Z (out of the bow's back), its nock on the string.
		local arrowDef = def.Arrow
		if arrowDef then
			local arrow = Instance.new("Model")
			arrow.Name = "Arrow"
			local root = block("Root", Vector3.new(0.1, 0.1, 0.1), WOOD, Enum.Material.Wood, arrow)
			root.Transparency = 1
			root.CastShadow = false
			arrow.PrimaryPart = root
			local made = piece(kit, arrowDef.Piece, arrowDef.Scale or 1, CFrame.new())
			if made then
				absorb(made, arrow, root)
			else
				local shaft = block("Shaft", Vector3.new(2.8, 0.06, 0.06), WOOD, Enum.Material.Wood, arrow)
				shaft.CFrame = CFrame.new(1.4, 0, 0)
				weld(root, shaft)
			end
			for _, d in arrow:GetChildren() do
				if d:IsA("BasePart") and d ~= root then
					d.Transparency = 1
					d:SetAttribute("Shown", 0)
				end
			end
			-- the arrow's +X -> the hilt's -Z
			local joint = Instance.new("Motor6D")
			joint.Name = "ArrowNock"
			joint.Part0 = hilt
			joint.Part1 = root
			joint.C0 = CFrame.new(0, 0, str.Back) * CFrame.Angles(0, math.rad(90), 0)
			joint.Parent = hilt
			arrow.Parent = model
		end
	end
	return model, hilt
end

--[[
	For a weapon that is ONE part of somebody else's making (the developer's sword off the toolbox): where the hand
	closes on it. Its longest side is taken for its length, and the fist closes `BLADE_BIAS` of the way from the middle
	to the near end (0.86 leaves a little of the grip and the pommel behind the hand). The frame returned is the joint's
	seat on the part (a Motor6D's C1): the weapon's length along +Y, the fist at the origin.
]]
local BLADE_BIAS = 0.86

function GearModels.gripSeat(part: BasePart): CFrame
	local s = part.Size
	local rotate: CFrame
	local along: Vector3
	if s.X >= s.Y and s.X >= s.Z then
		rotate = CFrame.Angles(0, 0, math.rad(-90)) -- up -> +X
		along = Vector3.new(-s.X / 2, 0, 0)
	elseif s.Z >= s.X and s.Z >= s.Y then
		rotate = CFrame.Angles(math.rad(90), 0, 0) -- up -> +Z
		along = Vector3.new(0, 0, -s.Z / 2)
	else
		rotate = CFrame.new() -- already along Y
		along = Vector3.new(0, -s.Y / 2, 0)
	end
	return CFrame.new(along * BLADE_BIAS) * rotate
end

--==========================================================================
-- Things worn (the quiver)
--==========================================================================

--[[
	Puts kit pieces on a body: each `entry` is `{ Piece, Part, At, Scale }` (the piece's origin at `Part`'s middle moved by
	`At`). Everything is welded to its body part and kept in one Model named `name` under the character. Returns the model
	(empty where the kit or the body part is missing), and for each entry the parts it made (so a caller can reveal them
	one after another).
]]
function GearModels.wear(character: Model, name: string, entries: { any }): (Model, { { BasePart } })
	local kit = GearModels.kit()
	local holder = Instance.new("Model")
	holder.Name = name
	local groups: { { BasePart } } = {}
	for i, entry in entries do
		groups[i] = {}
		local limb = character:FindFirstChild(entry.Part)
		if limb and limb:IsA("BasePart") then
			local made = piece(kit, entry.Piece, entry.Scale or 1, limb.CFrame * (entry.At :: CFrame))
			if made then
				for _, d in made:GetDescendants() do
					if d:IsA("BasePart") then
						d.Parent = holder
						weld(limb, d)
						table.insert(groups[i], d)
					end
				end
				made:Destroy()
			end
		end
	end
	holder.Parent = character
	return holder, groups
end

--[[
	The quiver on a back with `count` arrows standing in it (at most `cfg.Arrows.Most` are drawn).
]]
function GearModels.quiver(character: Model, cfg: any, count: number): Model
	local holder = GearModels.wear(character, "Quiver", cfg.Kit)
	local torso = character:FindFirstChild(cfg.Kit[1].Part)
	local kit = GearModels.kit()
	if torso and torso:IsA("BasePart") then
		local base = torso.CFrame * (cfg.Kit[1].At :: CFrame)
		local shown = math.clamp(count, 0, cfg.Arrows.Most)
		for i = 1, shown do
			-- a ring of arrows in the mouth, the heads down inside, the flights up: the arrow's +X (its flight) points DOWN
			local angle = (i - 1) / math.max(cfg.Arrows.Most, 1) * math.pi * 2
			local off = Vector3.new(math.cos(angle) * 0.11, cfg.Arrows.Lift + (i % 3) * 0.05, math.sin(angle) * 0.11)
			local at = base * CFrame.new(off) * CFrame.Angles(0, angle, math.rad(-90))
			local made = piece(kit, cfg.Arrows.Piece, cfg.Arrows.Scale or 1, at)
			if made then
				for _, d in made:GetDescendants() do
					if d:IsA("BasePart") then
						d.Parent = holder
						weld(torso, d)
					end
				end
				made:Destroy()
			end
		end
	end
	return holder
end

--[[
	A hook on the belt for the lantern to hang from (World/LanternService builds the lantern on whatever part it is given).
]]
function GearModels.beltHook(character: Model, cfg: any): BasePart?
	local limb = character:FindFirstChild(cfg.Part)
	if not (limb and limb:IsA("BasePart")) then
		return nil
	end
	local hook = block("BeltHook", Vector3.new(0.2, 0.2, 0.2), LEATHER, Enum.Material.Fabric, character)
	hook.Transparency = 1
	hook.CastShadow = false
	hook.CFrame = limb.CFrame * (cfg.At :: CFrame)
	weld(limb, hook)
	return hook
end

return GearModels
