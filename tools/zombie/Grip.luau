--[[
	Grip (2026-11-14): a hand of the dead closes round what it holds, and every finger TOUCHES it.

	The developer: "for every zombie, the fingers must touch exactly on the thing they hold". The bodies of
	ServerStorage.Assets.Undead had one stiff cylinder a finger, hanging below the palm; the haft passed somewhere near.

	HOW A FIST IS BUILT. In the hand's own frame (the bodies' hands: the wrist on top at +Y, the fingers hang to -Y and
	curl to +Z, the palm faces +Z; the thumb is on -X for a right hand, +X for a left one) the haft runs along X through
	the FIST POINT C, just in front of the palm's lower edge, touching the palm. Each finger is three phalanges (and
	the thumb two) that start at the knuckle line and go round the haft. Each phalanx is laid along a line TANGENT to
	the circle of radius (haft radius + finger radius) round the haft's axis, so a finger and the haft meet at exactly
	one line of contact: not apart, not inside. A ball at every joint and at the tip rounds the knuckles.

	`Grip.fist(model, side, opts)` builds the four fingers and the thumb for a haft of radius `opts.radius` and returns
	the fist frame: X along the haft toward the business end (the thumb's side), Y toward the true edge (away from the
	wrist), as an Attachment "Fist" in the hand. `Grip.hold(model, side, weapon, gripName)` puts a weapon (a Model with an
	Attachment named `gripName` whose frame means the same: X to the tip, Y to the edge) into that fist and welds it.

	Old fingers (parts named Finger, Thumb, Knuckles welded to that hand) are removed first.

	A tool, not game code: runs in Edit mode on the masters (ServerStorage.Assets.Undead).
]]

local Grip = {}

Grip.SHARE = { 0.46, 0.3, 0.24 } -- of a finger's length: the three phalanges
Grip.LENGTH = { 0.98, 1.04, 0.97, 0.8 } -- of the palm's height: index, middle, ring, little finger
Grip.THUMB = { 0.56, 0.44 }

local function weldTo(hand: BasePart, part: BasePart)
	local w = Instance.new("Weld")
	w.Name = "GripWeld"
	w.Part0 = hand
	w.Part1 = part
	w.C0 = hand.CFrame:ToObjectSpace(part.CFrame)
	w.Parent = part
end

local function bit(name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, look: BasePart?, opts: any): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = opts.color or (look and look.Color) or Color3.fromRGB(120, 112, 98)
	p.Material = opts.material or (look and look.Material) or Enum.Material.SmoothPlastic
	p.Reflectance = opts.reflectance or 0
	return p
end

-- The parts welded straight to `part` (any joint or weld kind), and the joint holding each.
local function welded(model: Model, part: BasePart): { [BasePart]: Instance }
	local out: { [BasePart]: Instance } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0, (d :: any).Part1
			if a == part and b and b:IsA("BasePart") then
				out[b] = d
			elseif b == part and a and a:IsA("BasePart") then
				out[a] = d
			end
		end
	end
	return out
end

--[[
	A chain of segments from point `start` that hugs a circle (centre `c`, radius `r`) going round it the way `dir` says
	(+1 counter-clockwise in the (u, v) plane). Each segment lies on a tangent line: it touches the circle at one point
	(or, if it is too short to reach it, points at that tangent point). Returns the points: start, then each end.
]]
function Grip.hug(start: Vector2, c: Vector2, r: number, lengths: { number }, dir: number): { Vector2 }
	local pts = { start }
	local p = start
	for _, len in lengths do
		local rel = p - c
		local d = rel.Magnitude
		local e: Vector2
		if d <= r + 1e-4 then
			-- already on (or inside) the circle: go along the tangent
			local tangent = Vector2.new(-rel.Y, rel.X).Unit * dir
			e = p + tangent * len
		else
			local base = math.atan2(rel.Y, rel.X)
			local alpha = math.acos(math.clamp(r / d, -1, 1))
			local a = base + dir * alpha
			local t = c + Vector2.new(math.cos(a), math.sin(a)) * r
			e = p + (t - p).Unit * len
		end
		table.insert(pts, e)
		p = e
	end
	return pts
end

-- The palm's box in the hand's space: its centre and size (a gauntlet that covers the hand counts as the palm).
local function palm(model: Model, hand: BasePart, opts: any): (CFrame, Vector3)
	if opts.palmSize then
		return opts.palmCentre or CFrame.new(), opts.palmSize
	end
	local size, centre = hand.Size, CFrame.new()
	for part in welded(model, hand) do
		if string.find(part.Name, "Gauntlet") and part.Transparency < 1 then
			local rel = hand.CFrame:ToObjectSpace(part.CFrame)
			if part.Size.X * part.Size.Y > size.X * size.Y then
				size, centre = part.Size, CFrame.new(rel.Position)
			end
		end
	end
	return centre, size
end

--[[
	Builds the fist. opts:
	  radius     the haft's radius (studs)                      (required)
	  finger     a finger's radius                              (from the palm: about a ninth of its width)
	  color, material, reflectance   of the fingers            (the old fingers' look, else the hand's)
	  palmSize, palmCentre           to override the palm box
	  keep       true: leave the old fingers (only for a test)
	Returns the "Fist" Attachment in the hand.
]]
function Grip.fist(model: Model, side: string, opts: any): Attachment
	local hand = model:FindFirstChild(side .. "Hand") :: BasePart
	assert(hand and hand:IsA("BasePart"), "no " .. side .. "Hand")
	local rg = opts.radius
	local centre, size = palm(model, hand, opts)
	local W, H, D = size.X, size.Y, size.Z
	local rf = opts.finger or math.clamp(W / 9, 0.035, 0.07)
	local R = rg + rf

	-- the old fingers go (their look is kept for the new ones)
	local look: BasePart? = nil
	for part in welded(model, hand) do
		local n = part.Name
		if n == "Finger" or n == "Thumb" or n == "Knuckles" or n == "Knuckle" or n == "Fingertip" or n == "Nail" then
			look = look or part
			if not opts.keep then
				part:Destroy()
			end
		end
	end
	local old = hand:FindFirstChild("Fist")
	if old then
		old:Destroy()
	end
	local folder = model:FindFirstChild("Fingers" .. side)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Model")
	folder.Name = "Fingers" .. side
	folder.Parent = model

	-- the fist point, in the hand's space: the haft touches the palm's face, a little below its lower edge
	local yc = centre.Y - H / 2 - rg * 0.3
	local zc = centre.Z + D / 2 + rg
	local c = Vector2.new(zc, yc) -- (u = z, v = y)
	local thumbSide = if side == "Right" then -1 else 1
	local hcf = hand.CFrame

	local function place(name: string, x: number, pts: { Vector2 }, radius: number)
		for i = 1, #pts - 1 do
			local a = hcf * Vector3.new(x, pts[i].Y, pts[i].X)
			local b = hcf * Vector3.new(x, pts[i + 1].Y, pts[i + 1].X)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local seg = bit(name, Enum.PartType.Cylinder, Vector3.new(len, radius * 2, radius * 2), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0), look, opts)
			seg.Parent = folder
			weldTo(hand, seg)
			local knot = bit(name .. "Joint", Enum.PartType.Ball, Vector3.one * radius * 2.04, CFrame.new(b), look, opts)
			knot.Parent = folder
			weldTo(hand, knot)
		end
	end

	-- the four fingers, index on the thumb's side
	for i = 1, 4 do
		local x = thumbSide * (W / 2 - W / 8 - (i - 1) * W / 4) + centre.X
		local total = H * Grip.LENGTH[i]
		local lengths = { total * Grip.SHARE[1], total * Grip.SHARE[2], total * Grip.SHARE[3] }
		local start = Vector2.new(centre.Z + D * 0.05, centre.Y - H / 2 + rf * 0.5)
		local pts = Grip.hug(start, c, R, lengths, 1)
		-- the knuckle itself
		local knuckle = bit("FingerJoint", Enum.PartType.Ball, Vector3.one * rf * 2.1, hcf * CFrame.new(x, start.Y, start.X), look, opts)
		knuckle.Parent = folder
		weldTo(hand, knuckle)
		place("Finger", x, pts, if i == 4 then rf * 0.88 else rf)
	end

	-- the thumb: from the side of the palm, over the top of the haft and down its front, beside the index finger
	local tx = thumbSide * (W / 2 + rf * 0.15) + centre.X
	local thumbLen = H * 0.78
	local tStart = Vector2.new(centre.Z + D * 0.2, centre.Y - H / 2 + H * 0.34)
	local tPts = Grip.hug(tStart, c, R, { thumbLen * Grip.THUMB[1], thumbLen * Grip.THUMB[2] }, -1)
	local tKnuckle = bit("ThumbJoint", Enum.PartType.Ball, Vector3.one * rf * 2.3, hcf * CFrame.new(tx, tStart.Y, tStart.X), look, opts)
	tKnuckle.Parent = folder
	weldTo(hand, tKnuckle)
	place("Thumb", tx, tPts, rf * 1.1)

	-- the fist frame: X along the haft toward the thumb's side, Y away from the wrist (the true edge)
	local fist = Instance.new("Attachment")
	fist.Name = "Fist"
	local flip = if side == "Right" then CFrame.Angles(0, 0, math.pi) else CFrame.Angles(math.pi, 0, 0)
	fist.CFrame = CFrame.new(centre.X, yc, zc) * flip
	fist.Parent = hand
	hand:SetAttribute("GripRadius", rg)
	return fist
end

--[[
	Puts `weapon` (a Model with an Attachment named `gripName` somewhere in it) into the `side` hand's fist (made by
	Grip.fist first) and welds every part of it to the hand. The weapon is moved as one piece.
]]
function Grip.hold(model: Model, side: string, weapon: Model, gripName: string)
	local hand = model:FindFirstChild(side .. "Hand") :: BasePart
	local fist = hand:FindFirstChild("Fist") :: Attachment
	assert(fist, "make the fist first")
	local grip = weapon:FindFirstChild(gripName, true) :: Attachment
	assert(grip and grip:IsA("Attachment"), "the weapon has no " .. gripName)
	local holder = grip.Parent :: BasePart
	-- where the weapon's grip frame is now, and where it must go
	local now = holder.CFrame * grip.CFrame
	local want = hand.CFrame * fist.CFrame
	local move = want * now:Inverse()
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = move * d.CFrame
		end
	end
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			for _, j in d:GetChildren() do
				if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
					j:Destroy()
				end
			end
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			weldTo(hand, d)
		end
	end
	weapon.Parent = model
end

-- Every part welded to `side` hand that is not a finger, the forearm or a glove: what it holds now.
function Grip.held(model: Model, side: string): { BasePart }
	local hand = model:FindFirstChild(side .. "Hand") :: BasePart
	local out = {}
	for part in welded(model, hand) do
		local n = part.Name
		if not (n == "Finger" or n == "Thumb" or n == "Knuckles" or string.find(n, "Joint$") or string.find(n, "LowerArm") or string.find(n, "Gauntlet") or n == "Vein") then
			table.insert(out, part)
		end
	end
	return out
end

--[[
	For a weapon ALREADY welded in the hand (the spade, the sentinel's sword, the bow): turns the hand on its wrist
	until its X runs along the haft (thumb toward `tip`), moves the weapon (without turning it) until the haft passes
	through the fist, rebuilds the fingers round it and welds the weapon again. `haft` is the part whose long axis is the
	grip; `tip` a point (world) at the business end.
]]
function Grip.refit(model: Model, side: string, parts: { BasePart }, haft: BasePart, tip: Vector3, opts: any)
	local hand = model:FindFirstChild(side .. "Hand") :: BasePart
	local wrist = hand:FindFirstChild(side .. "Wrist") :: Motor6D
	local forearm = wrist.Part0 :: BasePart
	-- the haft's axis and radius
	local s = haft.Size
	local axis, r
	if s.X >= s.Y and s.X >= s.Z then
		axis, r = haft.CFrame.RightVector, math.min(s.Y, s.Z) / 2
	elseif s.Y >= s.Z then
		axis, r = haft.CFrame.UpVector, math.min(s.X, s.Z) / 2
	else
		axis, r = haft.CFrame.LookVector, math.min(s.X, s.Y) / 2
	end
	local centreOnAxis = haft.Position
	if (tip - centreOnAxis):Dot(axis) < 0 then
		axis = -axis
	end
	-- turn the hand about the wrist: its thumb side along the axis
	local thumbDir = if side == "Right" then -hand.CFrame.RightVector else hand.CFrame.RightVector
	local turnAxis = thumbDir:Cross(axis)
	local angle = math.acos(math.clamp(thumbDir:Dot(axis), -1, 1))
	local turn = if turnAxis.Magnitude > 1e-4 then CFrame.fromAxisAngle(turnAxis.Unit, angle) else CFrame.new()
	local pivot = (forearm.CFrame * wrist.C0).Position
	local oldHand = hand.CFrame
	local newHand = CFrame.new(pivot) * turn * CFrame.new(-pivot) * oldHand
	-- what rides on the hand and is not held (a glove, a vein) turns with it
	local held: { [BasePart]: boolean } = {}
	for _, p in parts do
		held[p] = true
	end
	for part in welded(model, hand) do
		if not held[part] and part ~= forearm then
			part.CFrame = newHand * oldHand:ToObjectSpace(part.CFrame)
		end
	end
	hand.CFrame = newHand
	wrist.C0 = forearm.CFrame:ToObjectSpace(newHand * wrist.C1)
	-- the fist, then the weapon slid across (not turned) until its axis passes through the fist point
	local fist = Grip.fist(model, side, { radius = opts.radius or r, color = opts.color, material = opts.material, finger = opts.finger })
	local f = (newHand * fist.CFrame).Position
	-- the point of the axis nearest the fist point, along the haft's length as it is (the hand stays where it holds)
	local along = (f - centreOnAxis):Dot(axis)
	local nearest = centreOnAxis + axis * along
	local shift = f - nearest
	for _, p in parts do
		p.CFrame = p.CFrame + shift
		for _, j in p:GetChildren() do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
				j:Destroy()
			end
		end
	end
	for _, d in model:GetDescendants() do
		if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and ((d :: any).Part0 == hand or (d :: any).Part1 == hand) then
			local other = if (d :: any).Part0 == hand then (d :: any).Part1 else (d :: any).Part0
			if other and held[other] then
				d:Destroy()
			end
		end
	end
	for _, p in parts do
		weldTo(hand, p)
	end
	return math.deg(angle), shift.Magnitude
end

return Grip
