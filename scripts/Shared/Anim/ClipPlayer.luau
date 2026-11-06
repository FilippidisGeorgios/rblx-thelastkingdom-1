--!strict
--[[
	ClipPlayer
	Plays clips written in code (a list of frames: a time and a pose, the pose a rotation per joint) by writing the
	joints' `Transform` ourselves, every physics step, on the client. No KeyframeSequence, no animation id, nothing to
	upload.

	WHY (2026-11-05). Two facts found while building the player's movement:
	  1. An id from `KeyframeSequenceProvider:RegisterKeyframeSequence` "is temporary and cannot be used outside of
	     Studio" (the Roblox reference for KeyframeSequenceProvider): such clips play in a Studio test and not in the
	     published game.
	  2. Roblox's upgraded avatar joints are `AnimationConstraint`s, not Motor6Ds, and an AnimationConstraint takes its
	     Transform inside the physics step: a value written at RenderStepped or Heartbeat moves nothing, a value written
	     at `RunService.PreSimulation` moves the joint (measured: the right shoulder to exactly 90 degrees, on the
	     player's own body and on a body the server owns).
	So a clip is evaluated here and written at PreSimulation, onto Motor6Ds or AnimationConstraints alike. Nothing
	replicates: every client poses every body it can see from the same rules, as the sword and the dead already do.

	A pose's CFrame means the same as a KeyframeSequence Pose's: the joint's Transform away from its rest.

	Location: ReplicatedStorage.Shared.Anim.ClipPlayer (evaluation is pure; `Rig` touches the character's joints).
]]

local ClipPlayer = {}

export type Ease = "in" | "out" | "smooth" | "flat"
export type Pose = { [string]: CFrame }
export type Frame = { time: number, ease: Ease?, pose: Pose }

export type Clip = {
	name: string,
	looped: boolean,
	length: number,
	bones: { string },
	times: { number },
	eases: { Ease },
	poses: { { CFrame } }, -- per frame, per bone (in `bones` order): every bone filled
}

-- the R15 body: the part a joint moves, and the joint's own name
ClipPlayer.JOINTS = {
	LowerTorso = "Root",
	UpperTorso = "Waist",
	Head = "Neck",
	RightUpperArm = "RightShoulder",
	RightLowerArm = "RightElbow",
	RightHand = "RightWrist",
	LeftUpperArm = "LeftShoulder",
	LeftLowerArm = "LeftElbow",
	LeftHand = "LeftWrist",
	RightUpperLeg = "RightHip",
	RightLowerLeg = "RightKnee",
	RightFoot = "RightAnkle",
	LeftUpperLeg = "LeftHip",
	LeftLowerLeg = "LeftKnee",
	LeftFoot = "LeftAnkle",
}

local IDENTITY = CFrame.new()

--[[
	Makes a clip from frames. A bone keyed in any frame is filled in every frame (at rest where a frame leaves it out),
	so the clip can be sampled with no gaps.
]]
function ClipPlayer.clip(name: string, frames: { Frame }, looped: boolean): Clip
	table.sort(frames, function(a, b)
		return a.time < b.time
	end)
	local seen: { [string]: boolean } = {}
	local bones: { string } = {}
	for _, f in frames do
		for bone in f.pose do
			if not seen[bone] then
				seen[bone] = true
				table.insert(bones, bone)
			end
		end
	end
	local times, eases, poses = {}, {}, {}
	for i, f in frames do
		times[i] = f.time
		eases[i] = f.ease or "smooth"
		local row = {}
		for j, bone in bones do
			row[j] = f.pose[bone] or IDENTITY
		end
		poses[i] = row
	end
	return {
		name = name,
		looped = looped,
		length = if #frames > 0 then frames[#frames].time else 0,
		bones = bones,
		times = times,
		eases = eases,
		poses = poses,
	}
end

local function ease(kind: Ease, a: number): number
	if kind == "flat" then
		return a
	elseif kind == "in" then
		return a * a * a
	elseif kind == "out" then
		local b = 1 - a
		return 1 - b * b * b
	end
	-- smooth: cubic in and out
	if a < 0.5 then
		return 4 * a * a * a
	end
	local b = -2 * a + 2
	return 1 - b * b * b / 2
end

--[[
	The pose of `clip` at `t` seconds (a looped clip wraps, a one-shot holds its last frame), blended into `out` with
	`weight` (0..1) over whatever `out` already holds: out[bone] = out[bone] (or rest) moved `weight` of the way to the
	clip's pose. Several clips are blended by calling this for each with weight / (the weights so far, this one included).
]]
function ClipPlayer.sample(clip: Clip, t: number, out: { [string]: CFrame }, weight: number)
	local n = #clip.times
	if n == 0 or weight <= 0 then
		return
	end
	if clip.looped and clip.length > 0 then
		t = t % clip.length
	else
		t = math.clamp(t, 0, clip.length)
	end
	-- the two frames round t
	local i = 1
	while i < n and clip.times[i + 1] <= t do
		i += 1
	end
	local a, b = clip.poses[i], clip.poses[math.min(i + 1, n)]
	local span = if i < n then clip.times[i + 1] - clip.times[i] else 0
	local alpha = if span > 0 then ease(clip.eases[i], math.clamp((t - clip.times[i]) / span, 0, 1)) else 0
	for j, bone in clip.bones do
		local pose = if alpha <= 0 then a[j] elseif alpha >= 1 then b[j] else a[j]:Lerp(b[j], alpha)
		if weight >= 1 then
			out[bone] = pose
		else
			out[bone] = (out[bone] or IDENTITY):Lerp(pose, weight)
		end
	end
end

--==========================================================================
-- A body's joints
--==========================================================================
export type Rig = { joints: { [string]: any }, character: Model }

-- The joints of an R15 body by the part they move (Motor6D or AnimationConstraint). Nil until the body has its torso
-- and both hips (a body still streaming in).
function ClipPlayer.rig(character: Model): Rig?
	local joints: { [string]: any } = {}
	for part, jointName in ClipPlayer.JOINTS do
		local limb = character:FindFirstChild(part)
		local joint = limb and limb:FindFirstChild(jointName)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[part] = joint
		end
	end
	if not (joints.LowerTorso and joints.UpperTorso and joints.RightUpperLeg and joints.LeftUpperLeg) then
		return nil
	end
	return { joints = joints, character = character }
end

-- Writes a blended pose onto the body; a joint the pose leaves out goes to rest, unless it is in `skip`.
function ClipPlayer.write(rig: Rig, pose: { [string]: CFrame }, skip: { [string]: boolean }?)
	for part, joint in rig.joints do
		if not (skip and skip[part]) then
			joint.Transform = pose[part] or IDENTITY
		end
	end
end

return ClipPlayer
