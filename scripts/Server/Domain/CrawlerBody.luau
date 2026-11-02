--!strict
--[[
	CrawlerBody
	Turns one of the dead's standing bodies (ServerStorage.Assets.Undead) into a CRAWLER: a body with no legs that
	drags itself along the ground on its arms, its ribs and spine still showing. It is made at spawn from the body it
	is given, so there is no new model to build and the crawler wears whichever guard or scullion it is made from.

	  1. THE LEGS GO. Everything rigidly joined to a leg (the boots, the knee-balls, the cuffs, the toes) is found by
	     following the joints out from the two thighs, never crossing into the trunk, and destroyed. What is left is
	     a torso with a stump at each hip. A helmet or a coif goes too: nothing rides on a crawler's head.
	  2. THE WELDS ARE MADE FIXED. The bodies hold their cloth, belts and heads on with WeldConstraints, and a
	     WeldConstraint takes whatever offset its two parts have when the body first enters the world, by which time
	     the new joints below have already laid the torso down (found in play, 2026-11-03: the clothes, the neck and the
	     helmet stayed at a standing body's height over a body lying on the floor, "one crawls and the other stands").
	     Each is replaced by a plain Weld that carries its offset with it.
	  3. THE BODY LIES DOWN. The torso is pitched forward until it is nearly flat and dropped onto the ground, the head
	     only a stud or so off the floor (the developer: "the head about one, at most two studs from the floor"). The
	     pitch is put on the Root joint's C1 (after the animation's own shift), so every clip written for a standing
	     body still moves it the way it was meant. The head is lifted back up to look ahead.
	  4. THE HANDS FIND THE FLOOR. Each shoulder is turned until its hand rests on the ground in front of the body,
	     worked out through the joints for that body (the standing bodies hold their two arms differently, so one angle
	     put one hand in the floor and the other in the air).
	  5. NOTHING STANDS UP OFF IT. A thing worn on the trunk that now sticks up above a crawler's height (the arrows in
	     a guard's back, the ladle in a cook's belt) is taken off.
	  6. THE ROOT STAYS WHERE IT WAS. The anchored HumanoidRootPart is what the AI moves and what the combat reads, so
	     it is left at its height: only the visible body moves. (Hits are measured to the root, not to a part.)

	Nothing here changes how it fights: its AI, its health and its attacks are in configs/Enemies (`undead_crawler`).
	It crawls with its own clip (ZombieAnims `crawl`, hand over hand) and strikes with the shambler's shove.

	Place: used by the Forgotten Lands (EnemyService); lives in Domain, which both places carry, so its spec runs in both. Phase: Enemy AI / Presentation.

	Location: ServerScriptService.Server.Domain.CrawlerBody
]]

local CrawlerBody = {}

-- The pose, in degrees and studs, tuned by measuring the guard's and the cook's bodies (2026-11-03): the chest rests on
-- the ground, the head's centre is about 0.9 off the floor and its top about 1.6.
CrawlerBody.PITCH = 76 -- how far the torso is laid forward (90 would be flat)
local DROP = 1.75 -- how far the body is lowered from the root, to rest on the ground
local FORWARD = 0.3 -- and shifted toward where it is going
local HEAD_LIFT = 64 -- the head comes back up to look ahead
local ARM_REACH = 104 -- a body without hands turns its shoulders this far
local HAND_Y = 0.35 -- where the middle of a hand rests, above the floor
local HAND_AHEAD = 1.2 -- at least this far in front of the root
local HIGHEST = 1.65 -- nothing worn on the trunk may stand higher than this off the floor (the top of the head)
local ROOT_Y = 2.5 -- the root's centre above the ground (EnemyService stands a body half its 5-stud rig height up)
local BONE = Color3.fromRGB(214, 204, 178)

local TRUNK: { [string]: boolean } = { HumanoidRootPart = true, LowerTorso = true, UpperTorso = true }
local LEG_ROOTS = { "LeftUpperLeg", "RightUpperLeg" }
local HEADGEAR = { "^helm", "^coif", "^hat", "^hood" }

-- The Motor6D called `name` (a body also has PARTS with these names: "Neck"), or nil.
local function joint(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

--[[
	Every part joined, directly or through other parts, to a leg without passing through the trunk. A joint is any
	Motor6D, Weld, ManualWeld or WeldConstraint: the bodies use all of them.
]]
function CrawlerBody.legParts(model: Model): { Instance }
	local neighbours: { [Instance]: { Instance } } = {}
	local function link(a: Instance?, b: Instance?)
		if a and b then
			neighbours[a] = neighbours[a] or {}
			neighbours[b] = neighbours[b] or {}
			table.insert(neighbours[a], b)
			table.insert(neighbours[b], a)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			link((d :: any).Part0, (d :: any).Part1)
		end
	end

	local found: { [Instance]: boolean } = {}
	local queue: { Instance } = {}
	for _, name in LEG_ROOTS do
		local leg = model:FindFirstChild(name)
		if leg then
			found[leg] = true
			table.insert(queue, leg)
		end
	end
	while #queue > 0 do
		local current = table.remove(queue) :: Instance
		for _, next in neighbours[current] or {} do
			if not found[next] and not (next:IsA("BasePart") and TRUNK[next.Name]) then
				found[next] = true
				table.insert(queue, next)
			end
		end
	end

	local list: { Instance } = {}
	for part in found do
		table.insert(list, part)
	end
	return list
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
	world yet, so no part has moved). `owner` is the joint-driven part a welded thing hangs from; `via`, the part it was
	reached through; `order`, the parts nearest the root first.
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

-- Turns `shoulder` until its hand rests on the floor ahead of the body. `base` is the root standing on a floor at y 0.
local function reach(model: Model, shoulder: Motor6D, side: string, base: CFrame)
	local hand = model:FindFirstChild(side .. "Hand")
	local elbow = joint(model, side .. "Elbow")
	local wrist = joint(model, side .. "Wrist")
	local upper = shoulder.Part0
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hand and hand:IsA("BasePart") and elbow and wrist and upper and root and root:IsA("BasePart")) then
		shoulder.C0 = shoulder.C0 * CFrame.Angles(math.rad(ARM_REACH), 0, 0)
		return
	end
	local chest = place(model, root, base).at[upper]
	if not chest then
		shoulder.C0 = shoulder.C0 * CFrame.Angles(math.rad(ARM_REACH), 0, 0)
		return
	end
	local c0 = shoulder.C0
	local best, bestMiss = ARM_REACH, math.huge
	for a = 30, 200, 2 do
		local arm = chest * c0 * CFrame.Angles(math.rad(a), 0, 0) * shoulder.C1:Inverse()
		local fore = arm * elbow.C0 * elbow.C1:Inverse()
		local at = (fore * wrist.C0 * wrist.C1:Inverse()).Position
		local rel = base:PointToObjectSpace(at)
		local miss = math.abs(at.Y - HAND_Y) + (if -rel.Z < HAND_AHEAD then 4 else 0)
		if miss < bestMiss then
			best, bestMiss = a, miss
		end
	end
	shoulder.C0 = c0 * CFrame.Angles(math.rad(best), 0, 0)
end

-- Makes `model` a crawler. Returns how many parts were taken away (0 if it had no legs to lose: nothing is changed).
function CrawlerBody.make(model: Model): number
	local root = joint(model, "Root")
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	local legs = CrawlerBody.legParts(model)
	for _, part in legs do
		part:Destroy()
	end
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			for _, pattern in HEADGEAR do
				if string.match(child.Name, pattern) then
					child:Destroy()
					break
				end
			end
		end
	end
	-- a joint left holding nothing on its far side would only confuse the animator
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and (d.Part0 == nil or d.Part1 == nil) then
			d:Destroy()
		end
	end
	fixWelds(model)

	root.C0 = CFrame.new(0, -DROP, FORWARD) * root.C0
	root.C1 = root.C1 * CFrame.Angles(math.rad(CrawlerBody.PITCH), 0, 0)

	local neck = joint(model, "Neck")
	if neck then
		neck.C0 = neck.C0 * CFrame.Angles(math.rad(HEAD_LIFT), 0, 0)
	end

	-- the root as it will stand: its own turn, its centre ROOT_Y over a floor at 0
	local base = if rootPart and rootPart:IsA("BasePart") then CFrame.new(0, ROOT_Y, 0) * rootPart.CFrame.Rotation else CFrame.new(0, ROOT_Y, 0)
	for _, side in { "Left", "Right" } do
		local shoulder = joint(model, side .. "Shoulder")
		if shoulder then
			reach(model, shoulder, side, base)
		end
	end

	-- whatever worn on the trunk now stands up off the body goes, and what hangs from it
	if rootPart and rootPart:IsA("BasePart") then
		local placed = place(model, rootPart, base)
		local gone: { [BasePart]: boolean } = {}
		for _, p in placed.order do
			local owner = placed.owner[p]
			local via = placed.via[p]
			if owner and owner ~= p and (owner.Name == "UpperTorso" or owner.Name == "LowerTorso") then
				local cf = placed.at[p]
				local tall = math.abs(cf.RightVector.Y) * p.Size.X + math.abs(cf.UpVector.Y) * p.Size.Y + math.abs(cf.LookVector.Y) * p.Size.Z
				local top = cf.Position.Y + tall / 2
				if (via and gone[via]) or (p.Transparency < 1 and top > HIGHEST) then
					gone[p] = true
				end
			end
		end
		for p in gone do
			p:Destroy()
		end
	end

	-- the thighbones, broken off short at the hips
	local lower = model:FindFirstChild("LowerTorso")
	if lower and lower:IsA("BasePart") then
		for _, side in { -1, 1 } do
			local bone = Instance.new("Part")
			bone.Name = "Femur"
			bone.Shape = Enum.PartType.Cylinder
			bone.Size = Vector3.new(0.9, 0.34, 0.34)
			bone.Color = BONE
			bone.Material = Enum.Material.Slate
			bone.CanCollide = false
			bone.CanQuery = false
			bone.CanTouch = false
			bone.Massless = true
			bone.CFrame = lower.CFrame * CFrame.new(side * 0.45, -0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
			bone.Parent = model
			local weld = Instance.new("Weld")
			weld.Part0 = lower
			weld.Part1 = bone
			weld.C0 = CFrame.new(side * 0.45, -0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
			weld.Parent = bone
		end
	end

	model:SetAttribute("Crawler", true)
	return #legs
end

return CrawlerBody
