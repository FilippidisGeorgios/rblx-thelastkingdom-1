--!nonstrict
--[[
	zombie/Dress — the small tools every look (theme) is made of.

	  Dress.paint(model, spec)        recolour and re-material the parts by ROLE: skin, cloth, leather, metal, wood, bone, vein, eye
	  Dress.attach(model, baseName, name, shape, size, offset, color, material, props)   a part welded to a body part
	  Dress.spike(model, baseName, offset, length, width, color, material, aim)           a spike / icicle / nail (two crossed wedges)
	  Dress.wrap(model, limbName, count, color, material, thickness)                      bandage rings round a limb
	  Dress.emit(model, baseName, preset, offset, overrides)                              a particle emitter (ember, smoke, frost, drip, ash, breath)
	  Dress.eyes(model, color, light)                                                      recolour the two hollow lights, optionally lit
	  Dress.light(model, baseName, color, brightness, range)   Dress.hide(model, pattern)   Dress.tag(part)

	Everything added is tagged TLK_Added, so a second pass never repaints its own work. A look made of these costs no
	script at runtime: it is parts, materials and emitters on the body.
]]

local Dress = {}

local Mat = Enum.Material
local rng = Random.new(2026)

function Dress.tag(p: Instance)
	p:SetAttribute("TLK_Added", true)
end

-- What a part IS, from its name first and its material second (the bodies are built from the same palette).
function Dress.role(p: BasePart): string
	local n, m = p.Name, p.Material
	if n == "HollowLight" then
		return "eye"
	end
	if string.find(n, "^Vein") then
		return "vein"
	end
	if string.find(n, "^Rib") or n == "Spine" or string.find(n, "^Tooth") then
		return "bone"
	end
	if m == Mat.Concrete then
		return "skin"
	elseif m == Mat.Fabric then
		return "cloth"
	elseif m == Mat.Leather then
		return "leather"
	elseif m == Mat.Metal or m == Mat.CorrodedMetal or m == Mat.DiamondPlate then
		return "metal"
	elseif m == Mat.Wood or m == Mat.WoodPlanks then
		return "wood"
	elseif m == Mat.Neon then
		return "glow"
	end
	return "other"
end

local function jitter(c: Color3, f: number): Color3
	local k = 1 + rng:NextNumber(-f, f)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

--[[
	spec = { skin = { color, material?, jitter?, reflectance? }, cloth = ..., ... }. A role that is not in the spec is left alone.
	A union keeps its cubes' colours unless it is repainted, so a painted union is switched to its own colour.
]]
function Dress.paint(model: Model, spec: { [string]: any })
	local skip = spec.skipModels or {}
	for _, p in model:GetDescendants() do
		local skipped = false
		for _, n in skip do
			if p:FindFirstAncestor(n) then
				skipped = true
			end
		end
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not p:GetAttribute("TLK_Added") and not skipped then
			local s = spec[Dress.role(p)]
			if s then
				if s.color then
					p.Color = jitter(s.color, s.jitter or 0.05)
					if p:IsA("UnionOperation") then
						p.UsePartColor = true
					end
				end
				if s.material then
					p.Material = s.material
					p.MaterialVariant = ""
				end
				if s.reflectance then
					p.Reflectance = s.reflectance
				end
			end
		end
	end
end

local function find(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end
Dress.find = find

function Dress.hide(model: Model, pattern: string)
	for _, d in model:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Model")) and string.find(d.Name, pattern) and not d:GetAttribute("TLK_Added") then
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			else
				for _, q in d:GetDescendants() do
					if q:IsA("BasePart") then
						q.Transparency = 1
						q.CastShadow = false
					end
				end
			end
		end
	end
end

function Dress.attach(model: Model, baseName: string, name: string, shape: Enum.PartType?, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?): BasePart?
	local base = find(model, baseName)
	if not base then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	Dress.tag(p)
	p.Parent = model
	return p
end

-- A spike: two wedges crossed at right angles, pointing along `aim` (a unit-ish direction in the base's own frame).
function Dress.spike(model: Model, baseName: string, offset: Vector3, length: number, width: number, color: Color3, material: Enum.Material, aim: Vector3?)
	local base = find(model, baseName)
	if not base then
		return
	end
	local dir = (aim or Vector3.new(0, -1, 0)).Unit
	local look = CFrame.lookAt(offset, offset + dir)
	for k = 0, 1 do
		local w = Instance.new("WedgePart")
		w.Name = "Spike"
		w.Size = Vector3.new(0.02 + width * 0.12, width, length)
		w.Color = color
		w.Material = material
		w.Anchored = false
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Massless = true
		w.CastShadow = false
		-- a wedge's slope runs along its Z; lay it so the point is at +Z (the far end)
		local c0 = look * CFrame.Angles(0, 0, math.rad(90 * k)) * CFrame.new(0, 0, -length / 2) * CFrame.Angles(math.rad(90), 0, 0)
		w.CFrame = base.CFrame * c0
		local wd = Instance.new("Weld")
		wd.Part0 = base
		wd.Part1 = w
		wd.C0 = c0
		wd.Parent = w
		Dress.tag(w)
		w.Parent = model
	end
end

-- Bandage / rope rings round a limb whose long axis is local X (the bodies' cylinder limbs).
function Dress.wrap(model: Model, limbName: string, count: number, color: Color3, material: Enum.Material, thickness: number?)
	local limb = find(model, limbName)
	if not limb then
		return
	end
	local len, wid = limb.Size.X, math.max(limb.Size.Y, limb.Size.Z)
	for i = 1, count do
		local x = (i / (count + 1) - 0.5) * len
		local ring = Instance.new("Part")
		ring.Name = "Wrap"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(thickness or 0.07, wid * 1.08, wid * 1.08)
		ring.Color = jitter(color, 0.08)
		ring.Material = material
		ring.Anchored = false
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Massless = true
		ring.CastShadow = false
		local c0 = CFrame.new(x, rng:NextNumber(-0.02, 0.02), 0) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25))
		ring.CFrame = limb.CFrame * c0
		local wd = Instance.new("Weld")
		wd.Part0 = limb
		wd.Part1 = ring
		wd.C0 = c0
		wd.Parent = ring
		Dress.tag(ring)
		ring.Parent = model
	end
end

local PRESETS = {
	ember = {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 70, 20)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 1,
		Lifetime = NumberRange.new(1.4, 2.6),
		Rate = 14,
		Speed = NumberRange.new(0.6, 1.8),
		Acceleration = Vector3.new(0, 3, 0),
		SpreadAngle = Vector2.new(40, 40),
		Rotation = NumberRange.new(0, 360),
	},
	smoke = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(70, 66, 64), Color3.fromRGB(30, 28, 28)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.2, 3.4),
		Rate = 5,
		Speed = NumberRange.new(0.4, 0.9),
		Acceleration = Vector3.new(0, 1.2, 0),
		SpreadAngle = Vector2.new(25, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
	},
	frost = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(205, 228, 245), Color3.fromRGB(150, 190, 225)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.35,
		Lifetime = NumberRange.new(2.4, 3.6),
		Rate = 6,
		Speed = NumberRange.new(0.3, 0.8),
		Acceleration = Vector3.new(0, -0.9, 0),
		SpreadAngle = Vector2.new(60, 60),
		Rotation = NumberRange.new(0, 360),
	},
	glint = {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(235, 248, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0, 1),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.8, 1.6),
		Rate = 7,
		Speed = NumberRange.new(0, 0.3),
		SpreadAngle = Vector2.new(180, 180),
	},
	drip = {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 140, 160)),
		Size = NumberSequence.new(0.07),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
		Lifetime = NumberRange.new(0.5, 0.8),
		Rate = 10,
		Speed = NumberRange.new(0, 0.4),
		Acceleration = Vector3.new(0, -26, 0),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Bottom,
	},
	ash = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 116, 112)),
		Size = NumberSequence.new(0.12),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3.5),
		Rate = 8,
		Speed = NumberRange.new(0.2, 0.7),
		Acceleration = Vector3.new(0.4, -0.6, 0),
		SpreadAngle = Vector2.new(180, 180),
	},
	breath = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(210, 225, 240)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.8),
		Rate = 6,
		Speed = NumberRange.new(0.5, 1.1),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Front,
	},
}

function Dress.emit(model: Model, baseName: string, preset: string, offset: CFrame?, overrides: { [string]: any }?)
	local base = find(model, baseName)
	if not base then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "TLK_FX_" .. preset
	at.CFrame = offset or CFrame.new()
	Dress.tag(at)
	at.Parent = base
	local e = Instance.new("ParticleEmitter")
	e.Name = preset
	for k, v in PRESETS[preset] do
		(e :: any)[k] = v
	end
	for k, v in overrides or {} do
		(e :: any)[k] = v
	end
	e.Parent = at
	return e
end

-- A small light on a body part (for the photographs; a real spawn would drop these: lights are the dearest thing in a crowd).
function Dress.light(model: Model, baseName: string, color: Color3, brightness: number, range: number, offset: Vector3?)
	local base = find(model, baseName)
	if not base then
		return
	end
	local at = Instance.new("Attachment")
	at.Position = offset or Vector3.zero
	Dress.tag(at)
	at.Parent = base
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = at
end

function Dress.eyes(model: Model, color: Color3, light: number?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "HollowLight" then
			p.Color = color
			p.Material = Mat.Neon
			if light then
				local l = Instance.new("PointLight")
				l.Color = color
				l.Brightness = light
				l.Range = 6
				l.Shadows = false
				l.Parent = p
				Dress.tag(l)
			end
		end
	end
end

--[[
	A cloak: ragged strips hanging from the shoulders down the back (the bodies' own cloth hems are strips too, so it reads as
	one family). opts: color, material, strips (7), length (2.2), width (0.34), trimColor? (a thin bright hem), hemSpikes? (colour of
	little icicles / thorns along the hem), glowHem? (a neon hem)
]]
function Dress.cloak(model: Model, opts: { [string]: any })
	local torso = find(model, "UpperTorso")
	if not torso then
		return
	end
	local n = opts.strips or 7
	local length = opts.length or 2.2
	if model:GetAttribute("Category") == "crawler" then
		length = math.min(length, 1.1)
	end
	local width = opts.width or 0.34
	local span = torso.Size.X * 0.44
	for i = 1, n do
		local x = (i / (n + 1) - 0.5) * 2 * span * 1.05
		local L = length * rng:NextNumber(0.72, 1.0)
		local top = torso.Size.Y * 0.46
		local c0 = CFrame.new(x, top - L / 2, torso.Size.Z * 0.5 + 0.05) * CFrame.Angles(math.rad(rng:NextNumber(-3, 9)), math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-3, 3)))
		local strip = Dress.attach(model, "UpperTorso", "Cloak", Enum.PartType.Block, Vector3.new(width, L, 0.05), c0, jitter(opts.color, 0.1), opts.material or Mat.Fabric)
		if strip then
			local bottom = CFrame.new(0, -L / 2, 0)
			if opts.glowHem then
				Dress.attach(model, "UpperTorso", "CloakHem", Enum.PartType.Block, Vector3.new(width, 0.05, 0.06), c0 * bottom, opts.glowHem, Mat.Neon)
			elseif opts.trimColor then
				Dress.attach(model, "UpperTorso", "CloakTrim", Enum.PartType.Block, Vector3.new(width, 0.07, 0.065), c0 * bottom, opts.trimColor, Mat.Metal)
			end
			if opts.hemSpikes then
				Dress.spike(model, "UpperTorso", (c0 * bottom).Position + Vector3.new(0, -0.02, 0), 0.3 + rng:NextNumber(0, 0.15), 0.08, opts.hemSpikes, Mat.Ice, Vector3.new(0, -1, 0))
			end
		end
	end
	-- a collar piece at the shoulders so the strips have something to hang from
	Dress.attach(model, "UpperTorso", "CloakYoke", Enum.PartType.Block, Vector3.new(torso.Size.X * 1.0, 0.22, torso.Size.Z * 1.06), CFrame.new(0, torso.Size.Y * 0.46, 0.02), jitter(opts.color, 0.05), opts.material or Mat.Fabric)
end

-- A hanging chain: alternate links turned a quarter apart, swaying a little. `hang` is how many links.
function Dress.chain(model: Model, baseName: string, offset: Vector3, hang: number, color: Color3, material: Enum.Material?)
	for i = 0, hang - 1 do
		local c0 = CFrame.new(offset + Vector3.new(math.sin(i * 0.7) * 0.03, -i * 0.15, 0)) * CFrame.Angles(0, math.rad(if i % 2 == 0 then 0 else 90), 0)
		Dress.attach(model, baseName, "Link", Enum.PartType.Block, Vector3.new(0.1, 0.2, 0.04), c0, color, material or Mat.Metal)
	end
end

-- Thin glowing cracks across a body part (a block-shaped part: torso) or along a limb (long axis X).
function Dress.cracks(model: Model, baseName: string, count: number, color: Color3, spec: { [string]: any }?)
	local base = find(model, baseName)
	if not base then
		return
	end
	spec = spec or {}
	local s = base.Size
	local limb = s.X > s.Y * 1.3 and s.X > s.Z * 1.3
	for i = 1, count do
		local len = rng:NextNumber(0.18, 0.5)
		local c0
		if limb then
			c0 = CFrame.new(rng:NextNumber(-s.X * 0.4, s.X * 0.4), rng:NextNumber(-s.Y * 0.3, s.Y * 0.3), -s.Z * 0.5 - 0.005) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-70, 70)))
			Dress.attach(model, baseName, "Crack", Enum.PartType.Block, Vector3.new(len, 0.035, 0.02), c0, color, Mat.Neon)
		else
			c0 = CFrame.new(rng:NextNumber(-s.X * 0.4, s.X * 0.4), rng:NextNumber(-s.Y * 0.4, s.Y * 0.4), -s.Z * 0.5 - 0.005) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-60, 60)))
			Dress.attach(model, baseName, "Crack", Enum.PartType.Block, Vector3.new(0.035, len, 0.02), c0, color, Mat.Neon)
		end
	end
end

-- A string of beads (small balls) hanging in a curve from the neck: bone beads, a rosary of skulls.
function Dress.beads(model: Model, baseName: string, count: number, color: Color3, material: Enum.Material, size: number?)
	for i = 1, count do
		local t = i / (count + 1)
		local x = (t - 0.5) * 1.1
		local y = 0.78 - math.sin(t * math.pi) * 0.55
		Dress.attach(model, baseName, "Bead", Enum.PartType.Ball, Vector3.new(1, 1, 1) * (size or 0.12), CFrame.new(x, y, -0.5), color, material)
	end
end

return Dress
