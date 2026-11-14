--!strict
--[[
	CrawlerBody
	Turns one of the dead's standing bodies (ServerStorage.Assets.Undead) into a CRAWLER, made at spawn from the body it
	is given (no new model to build: it wears whichever guard or scullion it is made from).

	THE SECOND CRAWLER (2026-11-14, the developer): "more upright: from the waist down on the floor, and from the waist up
	to the head a slope that looks up at the player. Cut off the right arm and make it look cut, with blood. Leave the
	left arm, a little shorter, raised and reaching toward the player; it crawls one pull at a time, at a fair pace, never
	faster than a player. And take the pole (the ladle) out of its hand." So:

	  1. THE RIGHT ARM IS GONE below the middle of the upper arm: the forearm, the hand and whatever the hand held (the
	     scullion's ladle) are taken off, the upper arm is cut short, and the stump ends in a dark wound with the end of
	     the bone showing and a slow drip.
	  2. THE LEFT ARM IS SHORTER (the forearm, by LEFT_ARM) and, at rest, held up and forward, reaching for you.
	  3. THE LEGS STAY and lie along the ground behind it, limp: the hips flat on the floor, the knees a little bent, the
	     feet turned over. (The first crawler, 0.39 to 0.47, had no legs.)
	  4. THE BODY RISES FROM THE WAIST: the hips lie flat (LOW_PITCH), the chest comes up (WAIST) and the head is lifted
	     to look up at a standing player (NECK).
	  5. THE WELDS ARE MADE FIXED: the bodies hold cloth, belts and heads on with WeldConstraints, which take whatever
	     offset their parts have when the body enters the world, after the joints have laid it down ("one crawls and the
	     other stands", 2026-11-03). Each becomes a Weld that carries the standing offset with it.
	  6. NOTHING STICKS UP OFF IT: a helmet, the arrows in a guard's back and a cleaver in a belt are taken off.
	  7. IT LIES ON THE FLOOR: the whole body is lowered on the Root joint until its lowest point touches the ground
	     under the root. The anchored HumanoidRootPart stays where the AI puts it (hits are measured to the root).

	The pitch is put on the Root joint's C1 (after an animation's own shift), so a clip that shifts the hips still moves
	them along the ground. It crawls with its own clip (Shared/Anim/ZombieAnims `crawl`): one long reach and pull of the
	left arm, the stump shoving, the body lurching forward on each pull.

	Place: used by the Forgotten Lands (EnemyService); lives in Domain, which both places carry, so its spec runs in both.
	Phase: Enemy AI / Presentation.

	Location: ServerScriptService.Server.Domain.CrawlerBody
]]

local CrawlerBody = {}

-- The pose, in degrees and studs.
CrawlerBody.PITCH = 84 -- the hips are laid forward this far (90 would be flat on the belly)
CrawlerBody.WAIST = 68 -- and the chest comes back up this far from them (the standing bodies are already hunched ~18)
CrawlerBody.NECK = 50 -- the head is lifted to look up at a standing player
CrawlerBody.LEFT_ARM = 0.82 -- the left forearm's length, of what it was
CrawlerBody.STUMP = 0.52 -- what is left of the right upper arm, of its length
CrawlerBody.VERSION = 2

local ROOT_Y = 2.5 -- the root's centre above the ground (EnemyService stands a body half its 5-stud rig height up)
local FLOOR_GAP = 0.03 -- the lowest point of the body rests this far above the floor
-- where the left hand is held at rest, in the root's frame (the body faces -Z): up, ahead and a little to its left
-- (root at ROOT_Y: the hand about 2.8 off the floor, 2.3 ahead, out to its left so the face shows past the arm)
local REACH_AT = Vector3.new(-1.4, 0.3, -2.3)

local BONE = Color3.fromRGB(206, 194, 166)
local WOUND = Color3.fromRGB(58, 8, 10)
local WOUND_WET = Color3.fromRGB(92, 12, 14)

local TRUNK: { [string]: boolean } = { HumanoidRootPart = true, LowerTorso = true, UpperTorso = true }
local LEG_ROOTS = { "LeftUpperLeg", "RightUpperLeg" }
local HEADGEAR = { "^helm", "^coif", "^hat", "^hood" }
-- cloth that hangs from the front of the body would lie under it, through the floor: it goes
local UNDER = { "^Apron%d", "^SkF", "^TabF", "^TabardFront", "^Pouch", "^Stain" }
local STICKING_UP: { [string]: boolean } = {
	ArrowShaft = true,
	Fletching0 = true,
	Fletching1 = true,
	CleaverBlade = true,
	CleaverGrip = true,
	LadleHandle = true,
	LadleBowl = true,
}

-- The Motor6D called `name` (a body also has PARTS with these names: "Neck"), or nil.
local function joint(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

-- Every part joined (any joint or weld kind) to another, as a neighbour list.
local function neighbours(model: Model): { [Instance]: { Instance } }
	local n: { [Instance]: { Instance } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0, (d :: any).Part1
			if a and b then
				n[a] = n[a] or {}
				n[b] = n[b] or {}
				table.insert(n[a], b)
				table.insert(n[b], a)
			end
		end
	end
	return n
end

-- Every part reached from the `from` parts without passing through a part in `stop`.
local function branch(model: Model, from: { string }, stop: { [string]: boolean }): { Instance }
	local n = neighbours(model)
	local found: { [Instance]: boolean } = {}
	local queue: { Instance } = {}
	for _, name in from do
		local p = model:FindFirstChild(name)
		if p then
			found[p] = true
			table.insert(queue, p)
		end
	end
	while #queue > 0 do
		local current = table.remove(queue) :: Instance
		for _, nxt in n[current] or {} do
			if not found[nxt] and not (nxt:IsA("BasePart") and stop[nxt.Name]) then
				found[nxt] = true
				table.insert(queue, nxt)
			end
		end
	end
	local list: { Instance } = {}
	for part in found do
		table.insert(list, part)
	end
	return list
end

--[[
	Every part joined, directly or through other parts, to a leg without passing through the trunk. A joint is any
	Motor6D, Weld, ManualWeld or WeldConstraint: the bodies use all of them.
]]
function CrawlerBody.legParts(model: Model): { Instance }
	return branch(model, LEG_ROOTS, TRUNK)
end

-- The right forearm and everything that hangs from it (the hand, the fingers, what the hand holds).
function CrawlerBody.forearmParts(model: Model): { Instance }
	return branch(model, { "RightLowerArm" }, { RightUpperArm = true, UpperTorso = true })
end

-- Every WeldConstraint becomes a Weld holding the offset its parts have NOW (the master's standing pose).
local function fixWelds(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then
			local a, b = d.Part0, d.Part1
			if a and b then
				local w = Instance.new("Weld")
				w.Name = d.Name
				w.Part0 = a
				w.Part1 = b
				w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
				w.Parent = d.Parent
			end
			d:Destroy()
		end
	end
end

type Placed = { at: { [BasePart]: CFrame }, owner: { [BasePart]: BasePart }, via: { [BasePart]: BasePart }, order: { BasePart } }

--[[
	Where every part will be once the root stands at `base`, worked out through the joints (the body is not in the
	world yet, so no part has moved).
]]
local function place(model: Model, root: BasePart, base: CFrame): Placed
	local links: { [BasePart]: { { other: BasePart, j: any, forward: boolean } } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") then
			local a, b = d.Part0, d.Part1
			if a and b then
				links[a] = links[a] or {}
				links[b] = links[b] or {}
				table.insert(links[a], { other = b, j = d, forward = true })
				table.insert(links[b], { other = a, j = d, forward = false })
			end
		end
	end
	local placed: Placed = { at = { [root] = base }, owner = { [root] = root }, via = {}, order = { root } }
	local i = 1
	while i <= #placed.order do
		local p = placed.order[i]
		i += 1
		for _, l in links[p] or {} do
			local q = l.other
			if not placed.at[q] then
				local j = l.j
				placed.at[q] = if l.forward then placed.at[p] * j.C0 * j.C1:Inverse() else placed.at[p] * j.C1 * j.C0:Inverse()
				placed.owner[q] = if j:IsA("Motor6D") then q else placed.owner[p]
				placed.via[q] = p
				table.insert(placed.order, q)
			end
		end
	end
	return placed
end

-- The lowest point of the parts one can see, once the root stands at `base`.
local function lowest(model: Model, root: BasePart, base: CFrame): number
	local placed = place(model, root, base)
	local low = math.huge
	for part, cf in placed.at do
		local owner = placed.owner[part]
		local arm = owner and (owner.Name == "LeftUpperArm" or owner.Name == "LeftLowerArm" or owner.Name == "LeftHand")
		if part ~= root and part.Transparency < 0.95 and not arm then
			local s = part.Size
			local ext = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			low = math.min(low, cf.Position.Y - ext)
		end
	end
	return low
end

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function weldAt(to: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = to
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
end

--[[
	A limb part (a cylinder along its X, the joint to its parent near the +X end) made `scale` times as long, keeping
	its +X end where it was: the joint to the parent stays put, the joint to its child comes in, and what is welded to it
	is slid in proportion. `childJoint` is the Motor6D whose C0 sits in this part (its child), if any.
]]
local function shorten(model: Model, part: BasePart, scale: number, childJoint: Motor6D?)
	local old = part.Size.X
	local new = old * scale
	local delta = (old - new) / 2 -- the centre moves toward +X by this, in the part's own frame
	part.Size = Vector3.new(new, part.Size.Y, part.Size.Z)
	-- the part's own joint to its parent (C1 is in this part)
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 == part then
			d.C1 = CFrame.new(-delta, 0, 0) * d.C1
		end
	end
	if childJoint then
		local c0 = childJoint.C0
		-- from the old +X end to the joint, scaled, measured from the new end
		local fromEnd = old / 2 - c0.Position.X
		local x = new / 2 - fromEnd * scale
		childJoint.C0 = CFrame.new(x, c0.Position.Y, c0.Position.Z) * c0.Rotation
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Part0 == part then
			local p = d.C0.Position
			d.C0 = CFrame.new(new / 2 - (old / 2 - p.X) * scale, p.Y, p.Z) * d.C0.Rotation
		elseif d:IsA("Weld") and d.Part1 == part then
			local p = d.C1.Position
			d.C1 = CFrame.new(new / 2 - (old / 2 - p.X) * scale, p.Y, p.Z) * d.C1.Rotation
		end
	end
end

-- The wound at the end of the stump: the cut skin, the bone, a dark wet core and a slow drip.
local function wound(model: Model, arm: BasePart)
	local r = math.min(arm.Size.Y, arm.Size.Z) / 2
	local endX = -arm.Size.X / 2
	local cap = newPart(model, "StumpWound", Enum.PartType.Cylinder, Vector3.new(0.1, r * 2.04, r * 2.04), WOUND, Enum.Material.SmoothPlastic)
	cap.Reflectance = 0.04
	weldAt(arm, cap, CFrame.new(endX - 0.02, 0, 0))
	local wet = newPart(model, "StumpWound", Enum.PartType.Cylinder, Vector3.new(0.08, r * 1.5, r * 1.5), WOUND_WET, Enum.Material.Glass)
	wet.Transparency = 0.1
	weldAt(arm, wet, CFrame.new(endX - 0.07, 0.03, -0.02))
	-- ragged skin round the cut
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local flap = newPart(model, "StumpFlap", Enum.PartType.Block, Vector3.new(0.16 + (i % 2) * 0.08, 0.05, r * 0.7), arm.Color, arm.Material)
		weldAt(arm, flap, CFrame.new(endX - 0.03, math.cos(a) * r * 0.92, math.sin(a) * r * 0.92) * CFrame.Angles(a, 0, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 18 else -10)))
	end
	-- the end of the bone, broken
	local bone = newPart(model, "StumpBone", Enum.PartType.Cylinder, Vector3.new(0.34, r * 0.62, r * 0.62), BONE, Enum.Material.Limestone)
	weldAt(arm, bone, CFrame.new(endX - 0.12, -0.02, 0.03) * CFrame.Angles(0, math.rad(6), math.rad(4)))
	local splinter = newPart(model, "StumpBone", Enum.PartType.Block, Vector3.new(0.18, r * 0.22, r * 0.3), BONE, Enum.Material.Limestone)
	weldAt(arm, splinter, CFrame.new(endX - 0.3, 0.04, 0.02) * CFrame.Angles(0, 0, math.rad(12)))
	-- a slow, dark drip
	local at = Instance.new("Attachment")
	at.Name = "StumpDrip"
	at.Position = Vector3.new(endX - 0.1, -r * 0.6, 0)
	at.Parent = arm
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Blood"
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(Color3.fromRGB(70, 6, 8))
	drip.LightEmission = 0
	drip.LightInfluence = 1
	drip.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0.04) })
	drip.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.5) })
	drip.Lifetime = NumberRange.new(0.35, 0.6)
	drip.Speed = NumberRange.new(0.2, 0.6)
	drip.Acceleration = Vector3.new(0, -30, 0)
	drip.Rate = 2.2
	drip.SpreadAngle = Vector2.new(10, 10)
	drip.Parent = at
end

-- Turns the left shoulder (two ways) until the hand is as near as it can come to REACH_AT (the root's frame).
local function holdUp(model: Model, root: BasePart, base: CFrame)
	local shoulder = joint(model, "LeftShoulder")
	local hand = model:FindFirstChild("LeftHand")
	if not (shoulder and hand and hand:IsA("BasePart")) then
		return
	end
	local elbow = joint(model, "LeftElbow")
	local wrist = joint(model, "LeftWrist")
	local chest = place(model, root, base).at[shoulder.Part0 :: BasePart]
	if not (chest and elbow and wrist) then
		return
	end
	local c0 = shoulder.C0
	local e0 = elbow.C0
	local target = base * REACH_AT
	local local_ = (chest * c0):PointToObjectSpace(target) -- the target, from the shoulder joint
	local best, bestMiss, bestElbow = c0, math.huge, e0
	-- for each bend of the elbow, the shoulder is turned to point the hand straight at the target; the bend that
	-- leaves the hand nearest it (a natural bend preferred when two are as good) is kept
	for bend = -40, 110, 4 do
		local e = e0 * CFrame.Angles(math.rad(bend), 0, 0)
		local below = shoulder.C1:Inverse() * e * elbow.C1:Inverse() * wrist.C0 * wrist.C1:Inverse()
		local v0 = below.Position
		if v0.Magnitude > 1e-3 and local_.Magnitude > 1e-3 then
			local a, b = v0.Unit, local_.Unit
			local axis = a:Cross(b)
			local angle = math.acos(math.clamp(a:Dot(b), -1, 1))
			local q = if axis.Magnitude > 1e-5 then CFrame.fromAxisAngle(axis.Unit, angle) else CFrame.new()
			local turned = c0 * q
			local miss = ((chest * turned * below).Position - target).Magnitude + math.abs(bend - 22) * 0.002
			if miss < bestMiss then
				best, bestMiss, bestElbow = turned, miss, e
			end
		end
	end
	shoulder.C0 = best
	elbow.C0 = bestElbow
	model:SetAttribute("CrawlerReachMiss", math.floor(bestMiss * 100) / 100)
end

-- Makes `model` a crawler. Returns how many parts were taken away (0 if it has no Root joint: nothing is changed).
function CrawlerBody.make(model: Model): number
	local root = joint(model, "Root")
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not (root and rootPart and rootPart:IsA("BasePart")) then
		return 0
	end
	local removed = 0

	-- 6. what would stick up, and the head's gear
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			for _, pattern in HEADGEAR do
				if string.match(child.Name, pattern) then
					child:Destroy()
					removed += 1
					break
				end
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local gone = STICKING_UP[d.Name] == true
			for _, pattern in UNDER do
				if string.match(d.Name, pattern) then
					gone = true
					break
				end
			end
			if gone then
				d:Destroy()
				removed += 1
			end
		end
	end

	-- 1. the right forearm and all that hangs from it
	for _, part in CrawlerBody.forearmParts(model) do
		part:Destroy()
		removed += 1
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and (d.Part0 == nil or d.Part1 == nil) then
			d:Destroy()
		end
	end

	-- 5. fixed welds (before anything below moves)
	fixWelds(model)

	-- 1. the stump: what is welded beyond the cut goes, the arm is cut short, the wound is made
	local stump = model:FindFirstChild("RightUpperArm")
	if stump and stump:IsA("BasePart") then
		local cutX = stump.Size.X / 2 - stump.Size.X * CrawlerBody.STUMP
		for _, d in model:GetDescendants() do
			if d:IsA("Weld") and (d.Part0 == stump or d.Part1 == stump) then
				local other = if d.Part0 == stump then d.Part1 else d.Part0
				local rel = if d.Part0 == stump then d.C0 * d.C1:Inverse() else (d.C0 * d.C1:Inverse()):Inverse()
				if other and rel.Position.X < cutX + 0.05 then
					other:Destroy()
					removed += 1
				end
			end
		end
		shorten(model, stump, CrawlerBody.STUMP, nil)
		wound(model, stump)
	end

	-- 2. the left forearm, shorter
	local leftFore = model:FindFirstChild("LeftLowerArm")
	if leftFore and leftFore:IsA("BasePart") then
		shorten(model, leftFore, CrawlerBody.LEFT_ARM, joint(model, "LeftWrist"))
	end

	-- 4. the hips flat, the chest up, the head lifted
	root.C1 = root.C1 * CFrame.Angles(math.rad(CrawlerBody.PITCH), 0, 0)
	local waist = joint(model, "Waist")
	if waist then
		waist.C0 = waist.C0 * CFrame.Angles(math.rad(CrawlerBody.WAIST), 0, 0)
	end
	local neck = joint(model, "Neck")
	if neck then
		neck.C0 = neck.C0 * CFrame.Angles(math.rad(CrawlerBody.NECK), 0, 0)
	end

	-- 3. the legs: lying behind, a little apart, the knees giving, the feet turned over
	for _, side in { "Left", "Right" } do
		local s = if side == "Left" then -1 else 1
		local hip = joint(model, side .. "Hip")
		if hip then
			hip.C0 = hip.C0 * CFrame.Angles(math.rad(-4), 0, math.rad(s * 7))
		end
		local knee = joint(model, side .. "Knee")
		if knee then
			knee.C0 = knee.C0 * CFrame.Angles(math.rad(if side == "Left" then -14 else -6), 0, 0)
		end
		local ankle = joint(model, side .. "Ankle")
		if ankle then
			ankle.C0 = ankle.C0 * CFrame.Angles(math.rad(62), math.rad(s * 18), 0)
		end
	end

	-- nothing may be left hanging from a part that was taken away (an unanchored part with no weld falls in the game)
	local reached: { [Instance]: boolean } = {}
	for _, p in branch(model, { "HumanoidRootPart" }, {}) do
		reached[p] = true
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not reached[d] then
			d:Destroy()
			removed += 1
		end
	end

	-- 7. down onto the floor (the left arm still hangs: it is lifted after, above everything)
	local base = CFrame.new(0, ROOT_Y, 0) * rootPart.CFrame.Rotation
	local low = lowest(model, rootPart, base)
	if low < math.huge then
		root.C0 = CFrame.new(0, -(low - FLOOR_GAP), 0) * root.C0
	end

	-- 2. the left hand up, reaching
	holdUp(model, rootPart, base)

	model:SetAttribute("Crawler", true)
	model:SetAttribute("CrawlerVersion", CrawlerBody.VERSION)
	return removed
end

return CrawlerBody
