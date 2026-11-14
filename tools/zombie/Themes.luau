--!nonstrict
--[[
	zombie/Themes — the looks of the dead. Each theme is a function(model, categoryId) that dresses ONE figure; the same theme is
	run over all eight categories so a photograph shows one idea eight ways.

	Each is rooted in the story (docs/Story.md): the garrison that stayed, the bones under the catacombs, the siege fire,
	the cold that came up from beneath, the drowned moat, the court that kept its manners, the hooded dead of the plague years.
	No green, no moss (the developer's rules), little red (the Bestiary): the horror is in the rot and the routine.

	  Themes.LIST   { { id, label, note, apply } } in photograph order
	  Themes.apply(themeId, model, categoryId)
]]

local ServerStorage = game:GetService("ServerStorage")

local Dress = require(script.Parent.Dress)
local Bones = require(script.Parent.Bones)

local Mat = Enum.Material
local C3 = Color3.fromRGB
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local Themes = {}

local function skullMesh(): MeshPart?
	local lab = ServerStorage:FindFirstChild("ZombieLab")
	local s = ServerStorage.Assets.CatacombMeshes:FindFirstChild("Skull")
	return s and s:FindFirstChildWhichIsA("MeshPart", true)
end

-- Puts the catacombs' skull mesh over a head (the head's own skin and hair are hidden).
local function skullHead(model: Model, tint: Color3?)
	local head = Dress.find(model, "Head")
	local src = skullMesh()
	if not (head and src) then
		return
	end
	head.Transparency = 1
	Dress.hide(model, "^head_")
	local m = src:Clone()
	m.Name = "Skull"
	local k = head.Size.Y / 1.0 * 1.08
	m.Size = src.Size * k
	m.Anchored = false
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	m.CastShadow = true
	-- the skull keeps its generated texture (the eye sockets and cracks are painted in it; a MeshPart texture ignores Color)
	local c0 = CF(0, 0.02, 0.02) * ANG(0, math.pi, 0)
	m.CFrame = head.CFrame * c0
	local w = Instance.new("Weld")
	w.Part0 = head
	w.Part1 = m
	w.C0 = c0
	w.Parent = m
	Dress.tag(m)
	m.Parent = model
end

--==========================================================================
-- 1. THE GARRISON, KEPT: as the game has them; the lowest ranks lose the skin of their hands
--==========================================================================
local function garrison(model: Model, id: string)
	if id == "crawler" or id == "runner" or id == "shambler" then
		Bones.arms(model)
	end
end

--==========================================================================
-- 2. THE OSSUARY: skin gone from the elbow down, a skull for a face, burial linen
--==========================================================================
local function ossuary(model: Model, id: string)
	Bones.arms(model, { armour = true })
	Bones.legs(model)
	Dress.paint(model, {
		skipModels = { "PlagueMask", "StagSkull" },
		skin = { color = C3(120, 112, 98), material = Mat.Slate },
		cloth = { color = C3(92, 84, 72), jitter = 0.1 },
		leather = { color = C3(48, 40, 34) },
		metal = { color = C3(46, 46, 50), material = Mat.Metal },
		vein = { color = C3(38, 32, 30) },
	})
	if id ~= "doctor" and id ~= "huntsman" then
		skullHead(model, C3(112, 100, 82))
	end
	Dress.eyes(model, C3(255, 150, 60), 0.5)
	-- a short ragged burial shroud, and a rosary of bone beads
	Dress.cloak(model, { color = C3(104, 94, 78), strips = 6, length = 1.7 })
	Dress.beads(model, "UpperTorso", 9, C3(190, 178, 152), Mat.Limestone, 0.13)
	Dress.emit(model, "UpperTorso", "ash", CF(0, 0.4, 0))
end

--==========================================================================
-- 3. THE CINDER: the siege fire's dead, black and cracked with embers, smoking
--==========================================================================
local function cinder(model: Model, id: string)
	Dress.paint(model, {
		skin = { color = C3(70, 46, 40), material = Mat.CrackedLava, jitter = 0.1 },
		cloth = { color = C3(38, 34, 32), jitter = 0.12 },
		leather = { color = C3(30, 24, 22) },
		metal = { color = C3(72, 56, 50), material = Mat.CorrodedMetal },
		vein = { color = C3(255, 120, 40), material = Mat.Neon },
		bone = { color = C3(210, 170, 130) },
	})
	Dress.eyes(model, C3(255, 130, 40), 0.7)
	-- charred rags with a glowing hem, and cracks of fire in the body
	Dress.cloak(model, { color = C3(30, 26, 26), strips = 7, length = 2.0, glowHem = C3(255, 110, 36) })
	Dress.cracks(model, "UpperTorso", 7, C3(255, 120, 40))
	for _, limb in { "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg" } do
		Dress.cracks(model, limb, 3, C3(255, 120, 40))
	end
	Dress.emit(model, "UpperTorso", "ember", CF(0, 0.5, 0))
	Dress.emit(model, "UpperTorso", "smoke", CF(0.5, 0.7, 0))
	Dress.emit(model, "Head", "ember", CF(0, 0.3, 0), { Rate = 6 })
	Dress.emit(model, "UpperTorso", "ember", CF(0, -0.2, 0), { Rate = 10 })
	Dress.light(model, "UpperTorso", C3(255, 110, 40), 0.9, 14, Vector3.new(0, 0.2, -0.6))
end

--==========================================================================
-- 4. THE RIME: the cold that came up from beneath: ice for skin, frost on cloth and steel
--==========================================================================
local function rime(model: Model, id: string)
	Dress.paint(model, {
		skin = { color = C3(80, 112, 140), material = Mat.Ice, jitter = 0.06 },
		cloth = { color = C3(96, 112, 140), jitter = 0.08 },
		leather = { color = C3(70, 82, 100) },
		metal = { color = C3(70, 88, 110), material = Mat.Metal, reflectance = 0.15 },
		wood = { color = C3(150, 150, 154) },
		vein = { color = C3(70, 120, 190) },
		bone = { color = C3(205, 225, 240) },
	})
	Dress.eyes(model, C3(160, 220, 255), 0.7)
	Dress.emit(model, "UpperTorso", "frost", CF(0, 0.5, 0))
	Dress.emit(model, "UpperTorso", "glint", CF(0, 0.3, 0))
	Dress.emit(model, "Head", "breath", CF(0, -0.35, -0.5))
	-- a frozen mantle fringed with icicles, a crown of ice on the head, and cracks of pale blue light
	Dress.cloak(model, { color = C3(120, 142, 172), strips = 7, length = 2.0, hemSpikes = C3(205, 232, 250) })
	local hs = Dress.find(model, "Head")
	if hs then
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Dress.spike(model, "Head", Vector3.new(math.cos(a) * hs.Size.X * 0.42, hs.Size.Y * 0.4, math.sin(a) * hs.Size.Z * 0.42), 0.45 + 0.15 * (k % 2), 0.11, C3(210, 236, 252), Mat.Ice, Vector3.new(math.cos(a) * 0.25, 1, math.sin(a) * 0.25))
		end
	end
	Dress.cracks(model, "UpperTorso", 5, C3(170, 220, 255))
	-- icicles on the shoulders and the forearms
	for _, side in { "Right", "Left" } do
		for k = 1, 3 do
			Dress.spike(model, side .. "UpperArm", Vector3.new(-0.3 + k * 0.28, -0.2, 0.25), 0.42 + 0.12 * (k % 2), 0.1, C3(200, 228, 246), Mat.Ice, Vector3.new(0, -1, 0.15))
		end
	end
end

--==========================================================================
-- 5. THE DROWNED: the moat's dead: pale and swollen, rope and chain, barnacles, hair of black weed, always dripping
--==========================================================================
local function drowned(model: Model, id: string)
	Dress.paint(model, {
		skipModels = { "PlagueMask", "StagSkull" },
		skin = { color = C3(112, 128, 140), reflectance = 0.1, jitter = 0.07 },
		cloth = { color = C3(40, 48, 58), reflectance = 0.08, jitter = 0.1 },
		leather = { color = C3(38, 38, 42), reflectance = 0.1 },
		metal = { color = C3(56, 64, 76), material = Mat.Metal, reflectance = 0.2 },
		wood = { color = C3(70, 62, 56) },
		vein = { color = C3(60, 80, 110) },
	})
	Dress.eyes(model, C3(190, 230, 235), 0.4)
	Dress.cloak(model, { color = C3(32, 40, 50), strips = 8, length = 2.1 })
	Dress.chain(model, "UpperTorso", Vector3.new(-0.55, -0.7, -0.52), 7, C3(140, 148, 158))
	Dress.chain(model, "UpperTorso", Vector3.new(0.7, -0.7, -0.52), 5, C3(140, 148, 158))
	local rope = C3(150, 118, 82)
	-- rope wound round the chest and the limbs
	for k = 0, 2 do
		Dress.attach(model, "UpperTorso", "Rope", Enum.PartType.Block, Vector3.new(2.02, 0.09, 1.02), CF(0, -0.55 + k * 0.42, 0) * ANG(0, 0, rad((k - 1) * 9)), rope, Mat.Fabric)
	end
	Dress.wrap(model, "RightUpperArm", 2, rope, Mat.Fabric, 0.08)
	Dress.wrap(model, "LeftUpperLeg", 2, rope, Mat.Fabric, 0.08)
	-- black weed hanging from the head, and barnacles on the shoulders
	local rngL = Random.new(11)
	for k = 1, 7 do
		local a = rngL:NextNumber(0, math.pi * 2)
		Dress.attach(model, "Head", "Weed", Enum.PartType.Block, Vector3.new(0.06, 0.9 + rngL:NextNumber(0, 0.7), 0.04), CF(math.cos(a) * 0.5, -0.45, math.sin(a) * 0.5 + 0.1) * ANG(rngL:NextNumber(-0.2, 0.2), a, rngL:NextNumber(-0.2, 0.2)), C3(26, 24, 26), Mat.Fabric)
	end
	for _, side in { "Right", "Left" } do
		for k = 1, 5 do
			Dress.attach(model, side .. "UpperArm", "Barnacle", Enum.PartType.Ball, Vector3.new(0.13, 0.1, 0.13), CF(rngL:NextNumber(-0.35, 0.35), rngL:NextNumber(-0.1, 0.1), rngL:NextNumber(-0.3, 0.3)), C3(168, 170, 160), Mat.Slate)
		end
	end
	Dress.emit(model, "RightHand", "drip", CF(0, -0.2, 0))
	Dress.emit(model, "LeftHand", "drip", CF(0, -0.2, 0))
	Dress.emit(model, "UpperTorso", "drip", CF(0, -0.4, -0.4), { Rate = 14 })
	Dress.emit(model, "UpperTorso", "frost", CF(0, 0.2, 0), { Color = ColorSequence.new(C3(150, 165, 175)), Rate = 3 })
end

--==========================================================================
-- 6. THE FADED COURT: the household that kept its manners: porcelain masks, tarnished gold, velvet that was bordeaux
--==========================================================================
local function maskOn(model: Model, kind: number)
	local head = Dress.find(model, "Head")
	if not head then
		return
	end
	local s = head.Size
	-- the face plate, a shallow ellipsoid over the face, then eye holes, a nose ridge and a mouth line
	local porcelain = C3(214, 206, 192)
	Dress.attach(model, "Head", "Mask", Enum.PartType.Ball, Vector3.new(s.X * 1.04, s.Y * 1.1, s.Z * 0.62), CF(0, 0.02, -s.Z * 0.26), porcelain, Mat.SmoothPlastic, { Reflectance = 0.08 })
	for _, x in { -0.2, 0.2 } do
		Dress.attach(model, "Head", "MaskEye", Enum.PartType.Block, Vector3.new(0.2, 0.11, 0.06), CF(x * s.X / 0.95, 0.16, -s.Z * 0.54) * ANG(0, 0, rad(x * 30)), C3(14, 12, 14), Mat.SmoothPlastic)
	end
	Dress.attach(model, "Head", "MaskNose", Enum.PartType.Block, Vector3.new(0.07, 0.3, 0.1), CF(0, -0.03, -s.Z * 0.55), porcelain, Mat.SmoothPlastic)
	Dress.attach(model, "Head", "MaskMouth", Enum.PartType.Block, Vector3.new(0.3, 0.035, 0.05), CF(0, -0.32, -s.Z * 0.49), C3(14, 12, 14), Mat.SmoothPlastic)
	-- gold trim and a crack
	Dress.attach(model, "Head", "MaskTrim", Enum.PartType.Block, Vector3.new(0.05, s.Y * 0.95, 0.05), CF(s.X * 0.45, 0.02, -s.Z * 0.42), C3(176, 140, 60), Mat.Metal)
	Dress.attach(model, "Head", "MaskCrack", Enum.PartType.Block, Vector3.new(0.02, 0.5, 0.02), CF(0.12, 0.18, -s.Z * 0.56) * ANG(0, 0, rad(18)), C3(40, 36, 34), Mat.SmoothPlastic)
	if kind == 2 then -- a half mask: the lower face is open and dark
		Dress.attach(model, "Head", "MaskJaw", Enum.PartType.Block, Vector3.new(0.7, 0.32, 0.05), CF(0, -0.36, -s.Z * 0.5), C3(26, 22, 24), Mat.Fabric)
	end
end

local function court(model: Model, id: string)
	local velvet = if id == "spearman" or id == "knight" or id == "runner" then C3(34, 38, 74) else C3(88, 26, 38)
	Dress.paint(model, {
		skipModels = { "PlagueMask", "StagSkull" },
		skin = { color = C3(176, 166, 154), jitter = 0.05 },
		cloth = { color = velvet, jitter = 0.1 },
		leather = { color = C3(40, 30, 30) },
		metal = { color = C3(84, 66, 38), material = Mat.Metal, reflectance = 0.3 },
		vein = { color = C3(110, 96, 120) },
	})
	Dress.cloak(model, { color = velvet, strips = 8, length = 2.5, trimColor = C3(150, 118, 58), width = 0.36 })
	if id ~= "doctor" and id ~= "huntsman" then
		maskOn(model, if id == "runner" or id == "crawler" then 2 else 1)
	end
	-- a ruff at the neck
	Dress.attach(model, "UpperTorso", "Ruff", Enum.PartType.Cylinder, Vector3.new(0.14, 1.32, 1.32), CF(0, 0.82, 0) * ANG(0, 0, rad(90)), C3(214, 204, 186), Mat.Fabric)
	-- a star brooch
	Dress.attach(model, "UpperTorso", "Brooch", Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.08), CF(-0.5, 0.45, -0.5), C3(176, 140, 60), Mat.Metal)
	Dress.eyes(model, C3(255, 226, 170), 0.35)
	Dress.emit(model, "UpperTorso", "glint", CF(0, 0.3, 0), { Color = ColorSequence.new(C3(255, 220, 140)), Rate = 5 })
end

--==========================================================================
-- 7. THE SHROUDED: the plague years' dead, bound in linen, hooded in sacking, stitched shut, pinned with rusted nails
--==========================================================================
local function shrouded(model: Model, id: string)
	local linen = C3(166, 154, 128)
	Dress.paint(model, {
		skipModels = { "PlagueMask", "StagSkull" },
		skin = { color = linen, material = Mat.Fabric, jitter = 0.08 },
		cloth = { color = C3(110, 100, 86), jitter = 0.12 },
		leather = { color = C3(52, 42, 34) },
		metal = { color = C3(58, 54, 52), material = Mat.Slate },
		vein = { color = C3(70, 56, 44) },
	})
	for _, limb in { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg" } do
		Dress.wrap(model, limb, 4, linen, Mat.Fabric, 0.07)
	end
	-- a burial shroud over the shoulders, down to the knees
	Dress.cloak(model, { color = C3(150, 138, 114), strips = 8, length = 2.5 })
	if id ~= "doctor" and id ~= "huntsman" then
		local head = Dress.find(model, "Head")
		if head then
			local s = head.Size
			Dress.hide(model, "^head_")
			Dress.attach(model, "Head", "Hood", Enum.PartType.Ball, Vector3.new(s.X * 1.34, s.Y * 1.3, s.Z * 1.3), CF(0, 0.04, 0.06), C3(124, 104, 76), Mat.Fabric)
			Dress.attach(model, "Head", "HoodPeak", Enum.PartType.Block, Vector3.new(0.22, 0.5, 0.22), CF(0, s.Y * 0.62, 0.3) * ANG(rad(-35), 0, 0), C3(118, 98, 72), Mat.Fabric)
			Dress.attach(model, "Head", "HoodVoid", Enum.PartType.Ball, Vector3.new(s.X * 0.86, s.Y * 0.9, s.Z * 0.5), CF(0, -0.02, -s.Z * 0.42), C3(10, 9, 10), Mat.SmoothPlastic)
			for _, x in { -0.19, 0.19 } do
				Dress.attach(model, "Head", "HoodEye", Enum.PartType.Ball, Vector3.new(0.09, 0.07, 0.05), CF(x, 0.08, -s.Z * 0.6), C3(236, 222, 160), Mat.Neon)
			end
			-- the stitched mouth: a dark line with cross-stitches
			Dress.attach(model, "Head", "Stitch", Enum.PartType.Block, Vector3.new(0.4, 0.03, 0.03), CF(0, -0.34, -s.Z * 0.58), C3(24, 20, 18), Mat.Fabric)
			for k = -2, 2 do
				Dress.attach(model, "Head", "StitchX", Enum.PartType.Block, Vector3.new(0.03, 0.16, 0.03), CF(k * 0.08, -0.34, -s.Z * 0.6) * ANG(0, 0, rad(24)), C3(24, 20, 18), Mat.Fabric)
			end
		end
	end
	-- rusted nails driven into the shoulders and chest
	local rn = Random.new(5)
	for k = 1, 8 do
		Dress.spike(model, "UpperTorso", Vector3.new(rn:NextNumber(-0.8, 0.8), rn:NextNumber(0.1, 0.7), -0.46), 0.28, 0.05, C3(104, 64, 40), Mat.CorrodedMetal, Vector3.new(rn:NextNumber(-0.3, 0.3), rn:NextNumber(-0.2, 0.4), 1))
	end
	Dress.emit(model, "UpperTorso", "ash", CF(0, 0.5, 0))
end

Themes.LIST = {
	{ id = "garrison", label = "The Garrison, kept", note = "the dead as the game has them; the lowest ranks lose the skin of their hands", apply = garrison },
	{ id = "ossuary", label = "The Ossuary", note = "bone from the elbow down, a skull for a face, burial linen", apply = ossuary, mood = { key = C3(255, 206, 160), keyK = 0.9, rim = C3(150, 170, 230), ambient = C3(52, 54, 62) } },
	{ id = "cinder", label = "The Cinder", note = "the siege fire's dead: black, cracked with embers, smoking", apply = cinder, mood = { key = C3(255, 120, 56), keyK = 0.8, key2 = C3(255, 90, 40), rim = C3(210, 60, 36), rimK = 0.9, fill = C3(120, 50, 36), ambient = C3(40, 32, 32) } },
	{ id = "rime", label = "The Rime", note = "the cold that came up from beneath: ice, frost, icicles", apply = rime, mood = { key = C3(180, 208, 255), keyK = 0.6, key2 = C3(200, 222, 255), rim = C3(120, 180, 255), rimK = 1.1, fill = C3(180, 210, 255), fillK = 0.7, ambient = C3(50, 60, 80) } },
	{ id = "drowned", label = "The Drowned", note = "the moat's dead: swollen, roped, barnacled, dripping", apply = drowned, mood = { key = C3(160, 196, 206), keyK = 1.5, key2 = C3(150, 180, 196), rim = C3(90, 120, 160), fill = C3(120, 150, 170), ambient = C3(50, 60, 70) } },
	{ id = "court", label = "The Faded Court", note = "the household that kept its manners: porcelain masks, tarnished gold, velvet", apply = court, mood = { key = C3(255, 214, 150), keyK = 1.1, key2 = C3(255, 190, 120), rim = C3(190, 90, 120), fill = C3(160, 120, 130), ambient = C3(54, 48, 56) } },
	{ id = "shrouded", label = "The Shrouded", note = "the plague years' dead: bound in linen, hooded in sacking, stitched shut, pinned with nails", apply = shrouded, mood = { key = C3(240, 220, 170), key2 = C3(226, 206, 160), rim = C3(120, 130, 150), ambient = C3(52, 50, 48) } },
}

function Themes.get(id: string)
	for _, t in Themes.LIST do
		if t.id == id then
			return t
		end
	end
	error("no theme " .. tostring(id))
end

function Themes.apply(themeId: string, model: Model, categoryId: string)
	Themes.get(themeId).apply(model, categoryId)
end

return Themes
