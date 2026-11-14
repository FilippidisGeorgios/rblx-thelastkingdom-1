--[[
	Pose (2026-11-14): puts ONE moment of a clip on a body in Edit mode, where joints do not move parts, so it can be
	photographed (tools/zombie/Booth) and judged frame by frame.

	    Pose.apply(model, pose)          -- pose = { [bone part name] = Transform CFrame }, as ClipPlayer writes them
	    Pose.at(clip, t)                  -- the pose of a ClipPlayer clip at t seconds
	    Pose.rest(model)                  -- back to the rest (every Transform identity)

	Every part is placed through the joints from the root: a Motor6D by C0 * Transform * C1:Inverse(), a Weld by
	C0 * C1:Inverse(), a WeldConstraint by the offset the two parts have at REST (taken the first time, kept on the model
	as Pose's own record, so posing twice does not drift).

	A tool, not game code. Use it on a COPY standing in the booth: it moves the parts.
]]

local Pose = {}

type Link = { other: BasePart, j: Instance, forward: boolean, rel: CFrame? }

local records: { [Model]: { [BasePart]: CFrame } } = {}

-- the rest layout (every part's CFrame relative to the root) is taken the first time a model is posed
local function restOf(model: Model): { [BasePart]: CFrame }
	local r = records[model]
	if r then
		return r
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	r = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			r[d] = root.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	records[model] = r
	return r
end

function Pose.apply(model: Model, pose: { [string]: CFrame })
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local rest = restOf(model)
	local links: { [BasePart]: { Link } } = {}
	local function add(a: BasePart, b: BasePart, j: Instance, forward: boolean)
		links[a] = links[a] or {}
		table.insert(links[a], { other = b, j = j, forward = forward })
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0, (d :: any).Part1
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				add(a, b, d, true)
				add(b, a, d, false)
			end
		end
	end
	local at: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local queue = { root }
	local i = 1
	while i <= #queue do
		local p = queue[i]
		i += 1
		for _, l in links[p] or {} do
			local q = l.other
			if not at[q] then
				local j = l.j :: any
				local rel: CFrame
				if j:IsA("Motor6D") then
					local t = pose[j.Part1.Name] or CFrame.new()
					rel = j.C0 * t * j.C1:Inverse()
				elseif j:IsA("JointInstance") then
					rel = j.C0 * j.C1:Inverse()
				else
					-- a WeldConstraint: the offset at rest
					local ra, rb = rest[j.Part0], rest[j.Part1]
					rel = if ra and rb then ra:ToObjectSpace(rb) else j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame)
				end
				at[q] = if l.forward then at[p] * rel else at[p] * rel:Inverse()
				table.insert(queue, q)
			end
		end
	end
	for part, cf in at do
		if part ~= root then
			part.CFrame = cf
		end
	end
end

function Pose.rest(model: Model)
	Pose.apply(model, {})
end

-- The pose of a ClipPlayer clip at `t` seconds (needs the ClipPlayer module handed in, from the synced copy).
function Pose.at(ClipPlayer: any, clip: any, t: number): { [string]: CFrame }
	local out = {}
	ClipPlayer.sample(clip, t, out, 1)
	return out
end

return Pose
