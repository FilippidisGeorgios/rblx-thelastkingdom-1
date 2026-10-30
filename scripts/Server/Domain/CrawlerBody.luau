--!strict
--[[
	CrawlerBody
	Turns one of the dead's standing bodies (ServerStorage.Assets.Undead) into a CRAWLER: a body with no legs that
	drags itself along the ground on its arms, its ribs and spine still showing. It is made at spawn from the body it
	is given, so there is no new model to build and the crawler wears whichever guard or scullion it is made from.

	  1. THE LEGS GO. Everything rigidly joined to a leg (the boots, the knee-balls, the cuffs, the toes) is found by
	     following the joints out from the two thighs, never crossing into the trunk, and destroyed. What is left is
	     a torso with a stump at each hip.
	  2. THE BODY LIES DOWN. The torso is pitched forward until it is nearly flat and dropped to the ground. The pitch
	     is put on the Root joint's C1 (after the animation's own shift), so every clip written for a standing body
	     still moves it the way it was meant: a lean is a rise and fall of the front, a twist turns it on the floor,
	     a lurch goes forward, not into the ground. The head is lifted back up to look ahead, and the shoulders are
	     turned so the arms reach out in front and down to the stones.
	  3. THE ROOT STAYS WHERE IT WAS. The anchored HumanoidRootPart is what the AI moves and what the combat reads, so
	     it is left at its height: only the visible body moves. (Hits are measured to the root, not to a part.)

	Nothing here changes how it fights: its AI, its health and its attacks are in configs/Enemies (`undead_crawler`).
	It uses the standing clips: the shambler's shove, as a lunge of the arm, and the walk, as a drag.

	Place: Forgotten Lands ONLY (Server/World). Phase: Enemy AI / Presentation.

	Location: ServerScriptService.Server.World.CrawlerBody
]]

local CrawlerBody = {}

-- The pose, in degrees and studs. All tuned by eye on the shambler's body (docs/systems/Bestiary.md): the torso
-- slopes up from the hips about 26 degrees, the head is lifted to look ahead and the hands are planted ahead of it.
local PITCH = 64 -- how far the torso is laid forward (90 would be flat)
local DROP = 1.55 -- how far the body is lowered from the root, to rest on the ground
local FORWARD = 0.2 -- and shifted toward where it is going
local HEAD_LIFT = 52 -- the head comes back up to look ahead
local ARM_REACH = 104 -- the shoulders turn the arms out in front and down to the stones
local BONE = Color3.fromRGB(214, 204, 178)

local TRUNK: { [string]: boolean } = { HumanoidRootPart = true, LowerTorso = true, UpperTorso = true }
local LEG_ROOTS = { "LeftUpperLeg", "RightUpperLeg" }

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

-- Makes `model` a crawler. Returns how many parts were taken away (0 if it had no legs to lose: nothing is changed).
function CrawlerBody.make(model: Model): number
	local root = joint(model, "Root")
	if not root then
		return 0
	end

	local legs = CrawlerBody.legParts(model)
	for _, part in legs do
		part:Destroy()
	end
	-- a joint left holding nothing on its far side would only confuse the animator
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and (d.Part0 == nil or d.Part1 == nil) then
			d:Destroy()
		end
	end

	root.C0 = CFrame.new(0, -DROP, FORWARD) * root.C0
	root.C1 = root.C1 * CFrame.Angles(math.rad(PITCH), 0, 0)

	local neck = joint(model, "Neck")
	if neck then
		neck.C0 = neck.C0 * CFrame.Angles(math.rad(HEAD_LIFT), 0, 0)
	end
	for _, name in { "LeftShoulder", "RightShoulder" } do
		local shoulder = joint(model, name)
		if shoulder then
			shoulder.C0 = shoulder.C0 * CFrame.Angles(math.rad(ARM_REACH), 0, 0)
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
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = lower
			weld.Part1 = bone
			weld.Parent = bone
		end
	end

	model:SetAttribute("Crawler", true)
	return #legs
end

return CrawlerBody
