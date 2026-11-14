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

	TWO THINGS A CLIP MAY SAY (2026-11-10):
	  * A frame's `ease` is how that pose is ARRIVED AT ("in" speeds up into it: a strike; "out" slows into it: a
	    wind-up or a recovery; "flat" at an even rate; "smooth" both). It is the way the sword's cuts were written.
	  * A bone named with a "+" in front ("+UpperTorso") is ADDED to what is already there instead of replacing it: a
	    cut can turn the chest thirty degrees while the walk underneath keeps leaning and rolling it.

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
	bones: { string }, -- the joint each column moves (the "+" taken off)
	added: { boolean }, -- per bone: laid on top of what is there (it was written "+Bone")
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
	local names: { string } = {}
	local added: { boolean } = {}
	for j, bone in bones do
		local plus = string.sub(bone, 1, 1) == "+"
		added[j] = plus
		names[j] = if plus then string.sub(bone, 2) else bone
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
		bones = names,
		added = added,
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

-- The same easing, for a track of plain numbers (Shared/Anim/PlayerActionAnims).
ClipPlayer.ease = ease

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
	-- the ease is the one of the pose being arrived at
	local alpha = if span > 0 then ease(clip.eases[math.min(i + 1, n)], math.clamp((t - clip.times[i]) / span, 0, 1)) else 0
	for j, bone in clip.bones do
		local pose = if alpha <= 0 then a[j] elseif alpha >= 1 then b[j] else a[j]:Lerp(b[j], alpha)
		if clip.added[j] then
			out[bone] = (out[bone] or IDENTITY) * (if weight >= 1 then pose else IDENTITY:Lerp(pose, weight))
		elseif weight >= 1 then
			out[bone] = pose
		else
			out[bone] = (out[bone] or IDENTITY):Lerp(pose, weight)
		end
	end
end

--==========================================================================
-- A body's joints
--==========================================================================
--[[
	A rig is the body's joints by the part each one moves, and for each joint where it sits: `a0` in the parent part and
	`a1` in the part itself (a Motor6D's C0 and C1; an AnimationConstraint's two attachments). With those a pose can be
	worked out WITHOUT touching the body ("where will the right hand be, in the chest's own space, once this pose is
	written?"), which is what lets a second hand be put exactly on a spear or a bowstring in the same frame.
]]
export type Rig = {
	joints: { [string]: any },
	a0: { [string]: CFrame },
	a1: { [string]: CFrame },
	character: Model,
	count: number, -- how many of the 15 joints were found
	complete: boolean, -- all of them (a friend's body streams in piece by piece: a rig with the neck missing never turns the head)
}

local function seats(joint: any): (CFrame?, CFrame?)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local first, second = joint.Attachment0, joint.Attachment1
	if first and second then
		return first.CFrame, second.CFrame
	end
	return nil, nil
end

-- The joints of an R15 body by the part they move (Motor6D or AnimationConstraint). Nil until the body has its torso
-- and both hips (a body still streaming in). `legless`: a body made without legs on purpose (a crawler that lost them)
-- needs only its torso.
function ClipPlayer.rig(character: Model, legless: boolean?): Rig?
	local joints: { [string]: any } = {}
	local a0: { [string]: CFrame } = {}
	local a1: { [string]: CFrame } = {}
	local count, total = 0, 0
	for part, jointName in ClipPlayer.JOINTS do
		total += 1
		local limb = character:FindFirstChild(part)
		local joint = limb and limb:FindFirstChild(jointName)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			local first, second = seats(joint)
			if first and second then
				joints[part] = joint
				a0[part] = first
				a1[part] = second
				count += 1
			end
		end
	end
	if not (joints.LowerTorso and joints.UpperTorso and (legless or (joints.RightUpperLeg and joints.LeftUpperLeg))) then
		return nil
	end
	return { joints = joints, a0 = a0, a1 = a1, character = character, count = count, complete = count == total }
end

-- Is every joint of this rig still in the body? (A body whose parts were swapped, by a new avatar description, is not.)
function ClipPlayer.alive(rig: Rig): boolean
	for _, joint in rig.joints do
		if joint.Parent == nil or not joint:IsDescendantOf(rig.character) then
			return false
		end
	end
	return true
end

-- Writes a blended pose onto the body; a joint the pose leaves out goes to rest, unless it is in `skip`.
function ClipPlayer.write(rig: Rig, pose: { [string]: CFrame }, skip: { [string]: boolean }?)
	for part, joint in rig.joints do
		if not (skip and skip[part]) then
			joint.Transform = pose[part] or IDENTITY
		end
	end
end

--==========================================================================
-- Working a pose out (no body is touched)
--==========================================================================

-- Where the part `part` sits in its PARENT part's space under `pose`.
function ClipPlayer.link(rig: Rig, pose: { [string]: CFrame }, part: string): CFrame
	local first, second = rig.a0[part], rig.a1[part]
	if not (first and second) then
		return IDENTITY
	end
	return first * (pose[part] or IDENTITY) * second:Inverse()
end

-- Where a hand sits in the CHEST's space (UpperTorso) under `pose`. `side` is "Right" or "Left".
function ClipPlayer.hand(rig: Rig, pose: { [string]: CFrame }, side: string): CFrame
	return ClipPlayer.link(rig, pose, side .. "UpperArm") * ClipPlayer.link(rig, pose, side .. "LowerArm") * ClipPlayer.link(rig, pose, side .. "Hand")
end

-- Where the chest (UpperTorso) sits in the ROOT's space (HumanoidRootPart) under `pose`.
function ClipPlayer.chest(rig: Rig, pose: { [string]: CFrame }): CFrame
	return ClipPlayer.link(rig, pose, "LowerTorso") * ClipPlayer.link(rig, pose, "UpperTorso")
end

--[[
	Puts a hand ON a point: changes `pose` so that the grip of the `side` hand reaches `target` (a point in the chest's
	space), by turning the shoulder and bending the elbow (the wrist stays straight). `pole` says which way the elbow
	should point (in the chest's space, for instance down and a little out). `weight` (0..1) blends from the pose's own
	arm to the reaching one. A point out of reach is reached for as far as the arm goes.

	The arithmetic: the upper arm's "bone" runs from the shoulder joint to the elbow joint (on a block body that is a
	slant: the shoulder joint is at the arm's inner top corner), the forearm's from the elbow straight down to the grip.
	The elbow bends about the arm's own X (+X bends it forward, the convention of every clip), so the distance from
	shoulder to grip depends on the bend alone; then the whole arm is turned so that line points at the target and the
	elbow falls on the pole's side.
]]
function ClipPlayer.reach(rig: Rig, pose: { [string]: CFrame }, side: string, target: Vector3, pole: Vector3, weight: number, toWrist: boolean?)
	if weight <= 0 then
		return
	end
	local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
	local s0, s1 = rig.a0[upper], rig.a1[upper]
	local e0, e1 = rig.a0[lower], rig.a1[lower]
	local w0, w1 = rig.a0[hand], rig.a1[hand]
	if not (s0 and s1 and e0 and e1 and w0 and w1) then
		return
	end
	local shoulder = s0.Position
	-- the two bones, each in its own part's space
	local u = e0.Position - s1.Position -- shoulder joint -> elbow joint, in the upper arm
	-- elbow joint -> grip, in the forearm (the hand hangs straight on from it)
	-- (with `toWrist` the target is where the WRIST joint must be: the caller turns the hand itself)
	local f = (w0.Position - e1.Position) + (if toWrist then Vector3.zero else Vector3.new(0, -(w1.Position.Y + 0.16), 0))
	local fLen = f.Magnitude
	local to = target - shoulder
	local d = to.Magnitude
	if d < 1e-3 or fLen < 1e-3 then
		return
	end
	-- |u + Rx(b) f|^2 = |u|^2 + |f|^2 + 2 (u.y f.y cos b)   (u has no forward part, f points straight down)
	local k = 2 * u.Y * f.Y
	local cosBend = if math.abs(k) > 1e-6 then (d * d - u:Dot(u) - fLen * fLen) / k else 1
	local bend = math.acos(math.clamp(cosBend, -0.88, 1)) -- never folded quite flat
	local elbow = CFrame.Angles(bend, 0, 0)
	-- shoulder -> grip, in the upper arm's space, at that bend
	local v = u + elbow:VectorToWorldSpace(f)
	local vLen = v.Magnitude
	if vLen < 1e-3 then
		return
	end
	local dir = to / d
	-- two frames: one in the arm (along v, with the elbow off to one side), one in the chest (along the target, with
	-- the pole off to the same side); the rotation between them is the shoulder
	local vHat = v / vLen
	local uSide = u - vHat * u:Dot(vHat)
	if uSide.Magnitude < 1e-4 then
		uSide = Vector3.new(0, 0, 1) - vHat * vHat.Z
	end
	local pSide = pole - dir * pole:Dot(dir)
	if pSide.Magnitude < 1e-4 then
		pSide = Vector3.new(0, -1, 0) - dir * -dir.Y
		if pSide.Magnitude < 1e-4 then
			pSide = Vector3.new(1, 0, 0)
		end
	end
	uSide, pSide = uSide.Unit, pSide.Unit
	local inArm = CFrame.fromMatrix(Vector3.zero, vHat, uSide, vHat:Cross(uSide))
	local inChest = CFrame.fromMatrix(Vector3.zero, dir, pSide, dir:Cross(pSide))
	local turn = inChest * inArm:Inverse()
	-- a joint's Transform is the part's turn seen from the joint's own frames (identity on every R15 body, kept general)
	local shoulderT = s0.Rotation:Inverse() * turn * s1.Rotation
	local elbowT = e0.Rotation:Inverse() * elbow * e1.Rotation
	if weight >= 1 then
		pose[upper] = shoulderT
		pose[lower] = elbowT
		if not toWrist then
			pose[hand] = IDENTITY
		end
	else
		pose[upper] = (pose[upper] or IDENTITY):Lerp(shoulderT, weight)
		pose[lower] = (pose[lower] or IDENTITY):Lerp(elbowT, weight)
		if not toWrist then
			pose[hand] = (pose[hand] or IDENTITY):Lerp(IDENTITY, weight)
		end
	end
end

--[[
	Turns a hand so that it hangs level whatever the arm is doing (a lantern must hang straight down from a hand that
	is held out): changes `pose[<side>Hand]` so that the hand's own frame matches the ROOT's, tipped by `tilt`.
]]
function ClipPlayer.level(rig: Rig, pose: { [string]: CFrame }, side: string, tilt: CFrame?, weight: number)
	if weight <= 0 then
		return
	end
	local hand = side .. "Hand"
	local w0, w1 = rig.a0[hand], rig.a1[hand]
	if not (w0 and w1) then
		return
	end
	local forearm = (ClipPlayer.chest(rig, pose) * ClipPlayer.link(rig, pose, side .. "UpperArm") * ClipPlayer.link(rig, pose, side .. "LowerArm")).Rotation
	local want = forearm:Inverse() * (tilt or IDENTITY)
	local wristT = w0.Rotation:Inverse() * want * w1.Rotation
	pose[hand] = if weight >= 1 then wristT else (pose[hand] or IDENTITY):Lerp(wristT, weight)
end

return ClipPlayer
