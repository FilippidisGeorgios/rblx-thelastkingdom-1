--!strict
--[[
	ZombieAnims
	The motion of the dead, authored here as KeyframeSequences and registered at
	runtime: no upload, no asset ids. Same pattern, same rules and the same angle
	convention as SwordAnims (docs/systems/Animation.md §1).

	--------------------------------------------------------------------------
	WHAT A CLIP IS

	A pose is a rotation (and sometimes a shift) of one JOINT away from its REST,
	and the rest of each body is baked into its Motor6Ds by tools/BuildUndead —
	a shambler is already hunched and reaching with no clip playing. So these
	clips are written as deltas: "the right arm draws back 52 degrees", not "the
	right arm is at 38". The same walk therefore sits on a stooped shambler, a
	stiff pikeman and a hooded gravedigger, and each looks like itself.

	    X  swings a limb that hangs down forward (+); on a part that stands up
	       (torso, head) +X leans it BACK
	    Y  twists
	    Z  takes a limb out to the character's right
	    a shift (T) moves the joint in the parent's frame: -Z is forward

	A bone that is absent from a keyframe is not touched: an attack keys the arms
	and torso and the legs go on doing whatever they were doing.

	--------------------------------------------------------------------------
	THE SET

	  Idle        breathing, a twitch every few seconds
	  Walk x3     lurch (a dragged foot, the head late), stiff march, shuffle
	  Run         the couriers
	  Aggro       the first sight of you: the head snaps up, the chest arches, a cry
	  Flinch      an overlay, played on every hit
	  Death x3    falls forward, falls back, kneels and slumps
	  Attacks     shove, lunge, overhead, thrust, draw, bash: each built from the
	              unit's own Windup / Strike / Recover (configs/Enemies), so the
	              clip and the server agree on when the blow lands

	Every attack follows the rules of Animation.md: it loads the other way first
	(anticipation), arrives at the top and HOLDS (the last quarter of the windup:
	that is the telegraph), accelerates into the strike, rebounds and settles.

	Location: ReplicatedStorage.Shared.Anim.ZombieAnims — pure construction, safe
	to require from either side. Registering needs the client's engine.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local ZombieAnims = {}

local rad = math.rad

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- A shift (parent's frame) and then a rotation.
local function move(px: number, py: number, pz: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(px, py, pz) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

type Ease = "in" | "out" | "smooth" | "flat"
type Pose = { [string]: CFrame }
type Frame = { time: number, ease: Ease?, pose: Pose }

local EASING = {
	smooth = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.InOut },
	["in"] = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.In },
	out = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.Out },
	flat = { style = Enum.PoseEasingStyle.Linear, direction = Enum.PoseEasingDirection.In },
}

--==========================================================================
-- Building
--==========================================================================
local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}

-- Parents before children, so a pose can always hang under the one above it.
local ORDER = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
}

type PoseInstance = Instance

local function newPose(name: string, cf: CFrame?, ease: Ease?, parent: Instance): PoseInstance
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf or CFrame.new()
	p.Weight = if cf then 1 else 0
	local e = EASING[ease or "smooth"]
	p.EasingStyle = e.style
	p.EasingDirection = e.direction
	p.Parent = parent
	return p
end

local function keyframe(frame: Frame, sequence: KeyframeSequence)
	local kf = Instance.new("Keyframe")
	kf.Name = "Keyframe"
	kf.Time = frame.time

	-- A bone in the pose needs every ancestor present (weight 0 where they carry nothing).
	local need: { [string]: boolean } = {}
	for bone in frame.pose do
		local b: string? = bone
		while b and b ~= "HumanoidRootPart" do
			need[b] = true
			b = PARENT[b]
		end
	end
	local nodes: { [string]: Instance } = { HumanoidRootPart = newPose("HumanoidRootPart", nil, frame.ease, kf) }
	for _, bone in ORDER do
		if need[bone] then
			nodes[bone] = newPose(bone, frame.pose[bone], frame.ease, nodes[PARENT[bone]])
		end
	end
	kf.Parent = sequence
end

local function build(name: string, frames: { Frame }, looped: boolean, priority: Enum.AnimationPriority): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = looped
	sequence.Priority = priority
	for _, frame in frames do
		keyframe(frame, sequence)
	end
	return sequence
end

-- A pose that is `f` of the way from rest to `p` (f in 0..1).
local function part(p: Pose, f: number): Pose
	local out: Pose = {}
	for bone, cf in p do
		out[bone] = CFrame.new():Lerp(cf, f)
	end
	return out
end

-- A pose that is `f` of the way from `a` to `b`, over the bones of either.
local function between(a: Pose, b: Pose, f: number): Pose
	local out: Pose = {}
	for bone, cf in a do
		out[bone] = cf:Lerp(b[bone] or CFrame.new(), f)
	end
	for bone, cf in b do
		if not a[bone] then
			out[bone] = CFrame.new():Lerp(cf, f)
		end
	end
	return out
end

-- The rest pose for the bones of `p`: every one of them at identity.
local function rest(p: Pose): Pose
	local out: Pose = {}
	for bone in p do
		out[bone] = CFrame.new()
	end
	return out
end

--==========================================================================
-- IDLE
--==========================================================================
local function idleFrames(): { Frame }
	local function breathe(t: number, chest: number, head: number, twitch: number?): Frame
		return {
			time = t,
			ease = "smooth",
			pose = {
				UpperTorso = deg(chest, 0, chest * 0.4),
				Head = deg(head, twitch or head * 1.5, head * 0.8),
				RightUpperArm = deg(chest * 0.8, 0, 1.5),
				LeftUpperArm = deg(-chest * 0.8, 0, -1.5),
				LowerTorso = move(0, -chest * 0.012, 0),
			},
		}
	end
	return {
		breathe(0, 0, 0),
		breathe(1.3, 2.2, 2.5),
		breathe(2.6, -0.6, -1.5),
		-- the twitch: quick out, quick back
		{ time = 2.72, ease = "out", pose = { UpperTorso = deg(-1, 0, 0), Head = deg(-3, -12, 5), RightUpperArm = deg(5, 0, 2), LeftUpperArm = deg(-2, 0, -3), LowerTorso = move(0, 0, 0) } },
		{ time = 2.9, ease = "smooth", pose = { UpperTorso = deg(-0.6, 0, 0), Head = deg(-2, -10, 4), RightUpperArm = deg(3, 0, 1), LeftUpperArm = deg(-1, 0, -2), LowerTorso = move(0, 0, 0) } },
		breathe(3.7, 1.6, 1.8),
		breathe(4.2, 0, 0),
	}
end

--==========================================================================
-- GAITS
--==========================================================================
type Gait = {
	D: number, -- seconds for one full stride (two steps)
	S: number, -- thigh swing, degrees
	K: number, -- knee flex at the passing, degrees
	arms: number, -- arm swing
	yaw: number, -- torso twist
	roll: number, -- hips rolling side to side
	bob: number, -- how far the pelvis drops at each contact
	head: number, -- how late the head is, as a multiple of the twist
	nod: number?, -- head nods
	drag: number?, -- the left leg does this fraction of the swing (a dragged foot)
	pitch: number?, -- extra lean forward (running)
}

local function gaitFrames(g: Gait): { Frame }
	local frames: { Frame } = {}
	local drag = g.drag or 1
	local pitch = g.pitch or 0
	local yawSeq = { 1, 0, -1, 0 }
	local headSeq = { 0, 1, 0, -1 }
	local rollSeq = { 1, 0, -1, 0 }
	local bobSeq = { 1, 0, 1, 0 }
	local rul = { g.S, 0, -g.S, 0 }
	local lul = { -g.S * drag, 0, g.S * drag, 0 }
	local rll = { -3, -4, -g.K * 0.6, -g.K * 1.3 }
	local lll = { -g.K * 0.6 * drag, -g.K * 1.3 * drag, -3, -4 }
	local armSeq = { -1, 0, 1, 0 }
	for i = 1, 5 do
		local k = ((i - 1) % 4) + 1
		frames[i] = {
			time = (i - 1) * g.D / 4,
			ease = "smooth",
			pose = {
				LowerTorso = move(0, -g.bob * bobSeq[k], 0, 0, -g.yaw * 0.5 * yawSeq[k], g.roll * rollSeq[k]),
				UpperTorso = deg(-pitch, g.yaw * yawSeq[k], -g.roll * 0.4 * rollSeq[k]),
				Head = deg(pitch * 0.8 + (g.nod or 0) * bobSeq[k], g.yaw * g.head * headSeq[k], g.roll * 0.3 * rollSeq[k]),
				RightUpperArm = deg(g.arms * armSeq[k], 0, 0),
				LeftUpperArm = deg(-g.arms * armSeq[k], 0, 0),
				RightLowerArm = deg(g.arms * 0.3 * (1 + armSeq[k]) , 0, 0),
				LeftLowerArm = deg(g.arms * 0.3 * (1 - armSeq[k]), 0, 0),
				RightUpperLeg = deg(rul[k], 0, 0),
				LeftUpperLeg = deg(lul[k], 0, 0),
				RightLowerLeg = deg(rll[k], 0, 0),
				LeftLowerLeg = deg(lll[k], 0, 0),
			},
		}
	end
	return frames
end

local WALKS: { Gait } = {
	-- 1. the lurch: weight thrown from hip to hip, the left foot dragged, the head late
	{ D = 1.3, S = 20, K = 28, arms = 7, yaw = 9, roll = 5, bob = 0.14, head = 1.4, drag = 0.5 },
	-- 2. the stiff march: upright, hardly bending, stepping in time with nobody
	{ D = 1.0, S = 24, K = 10, arms = 3, yaw = 3, roll = 1, bob = 0.08, head = 0.2 },
	-- 3. the shuffle: short steps, the hips rolling, the head nodding
	{ D = 1.5, S = 13, K = 18, arms = 11, yaw = 5, roll = 9, bob = 0.1, head = 0.8, nod = 6 },
}
local RUN: Gait = { D = 0.64, S = 48, K = 75, arms = 34, yaw = 12, roll = 4, bob = 0.28, head = 0.5, pitch = 8 }

--==========================================================================
-- AGGRO and FLINCH
--==========================================================================
local function aggroFrames(): { Frame }
	local cry: Pose = {
		Head = deg(38, 0, 0),
		UpperTorso = deg(15, 0, 0),
		RightUpperArm = deg(-14, 0, -20),
		LeftUpperArm = deg(-14, 0, 20),
		RightLowerArm = deg(10, 0, 0),
		LeftLowerArm = deg(10, 0, 0),
		LowerTorso = move(0, 0, 0.12),
	}
	local function shake(t: number, y: number): Frame
		return {
			time = t,
			ease = "flat",
			pose = {
				Head = deg(38, y, 0),
				UpperTorso = deg(15, -y * 0.5, 0),
				RightUpperArm = cry.RightUpperArm,
				LeftUpperArm = cry.LeftUpperArm,
				RightLowerArm = cry.RightLowerArm,
				LeftLowerArm = cry.LeftLowerArm,
				LowerTorso = cry.LowerTorso,
			},
		}
	end
	return {
		{ time = 0, ease = "smooth", pose = rest(cry) },
		-- it loads: the chin drops first
		{ time = 0.14, ease = "out", pose = { Head = deg(-10, 0, 0), UpperTorso = deg(-7, 0, 0), RightUpperArm = deg(6, 0, 0), LeftUpperArm = deg(6, 0, 0), RightLowerArm = deg(0, 0, 0), LeftLowerArm = deg(0, 0, 0), LowerTorso = move(0, 0, 0) } },
		{ time = 0.34, ease = "in", pose = cry },
		shake(0.48, 4),
		shake(0.56, -4),
		shake(0.64, 3),
		shake(0.72, -3),
		{ time = 0.9, ease = "smooth", pose = rest(cry) },
	}
end

local function flinchFrames(): { Frame }
	local hit: Pose = {
		UpperTorso = deg(9, 3, 0),
		Head = deg(16, -6, 0),
		RightUpperArm = deg(-12, 0, -6),
		LeftUpperArm = deg(-10, 0, 6),
	}
	return {
		{ time = 0, ease = "smooth", pose = rest(hit) },
		{ time = 0.07, ease = "in", pose = hit },
		{ time = 0.14, ease = "out", pose = part(hit, 0.7) },
		{ time = 0.34, ease = "smooth", pose = rest(hit) },
	}
end

--==========================================================================
-- DEATHS: the whole body goes down; the joint at the hip carries it
--==========================================================================
local function deathForward(): { Frame }
	return {
		{ time = 0, ease = "smooth", pose = { LowerTorso = move(0, 0, 0), UpperTorso = deg(0, 0, 0), Head = deg(0, 0, 0), RightUpperLeg = deg(0, 0, 0), LeftUpperLeg = deg(0, 0, 0), RightLowerLeg = deg(0, 0, 0), LeftLowerLeg = deg(0, 0, 0), RightUpperArm = deg(0, 0, 0), LeftUpperArm = deg(0, 0, 0) } },
		-- the knees go first
		{ time = 0.2, ease = "out", pose = { LowerTorso = move(0, -0.55, 0), UpperTorso = deg(-14, 0, 0), Head = deg(-16, 0, 0), RightUpperLeg = deg(30, 0, 0), LeftUpperLeg = deg(24, 0, 0), RightLowerLeg = deg(-44, 0, 0), LeftLowerLeg = deg(-36, 0, 0), RightUpperArm = deg(20, 0, 0), LeftUpperArm = deg(16, 0, 0) } },
		{ time = 0.58, ease = "in", pose = { LowerTorso = move(0, -1.5, -0.9, -52, 0, 0), UpperTorso = deg(-12, 0, 0), Head = deg(-10, 0, 0), RightUpperLeg = deg(10, 0, 0), LeftUpperLeg = deg(8, 0, 0), RightLowerLeg = deg(-20, 0, 0), LeftLowerLeg = deg(-16, 0, 0), RightUpperArm = deg(62, 0, -6), LeftUpperArm = deg(54, 0, 6) } },
		-- and the ground
		{ time = 0.86, ease = "out", pose = { LowerTorso = move(0, -2.0, -1.45, -84, 0, 3), UpperTorso = deg(-2, 0, 0), Head = deg(-6, 12, 0), RightUpperLeg = deg(-8, 0, 0), LeftUpperLeg = deg(-6, 0, 0), RightLowerLeg = deg(-4, 0, 0), LeftLowerLeg = deg(-2, 0, 0), RightUpperArm = deg(66, 0, -18), LeftUpperArm = deg(40, 0, 22) } },
		{ time = 1.05, ease = "smooth", pose = { LowerTorso = move(0, -2.04, -1.5, -86, 0, 3), UpperTorso = deg(0, 0, 0), Head = deg(-4, 14, 0), RightUpperLeg = deg(-8, 0, 0), LeftUpperLeg = deg(-6, 0, 0), RightLowerLeg = deg(-3, 0, 0), LeftLowerLeg = deg(-1, 0, 0), RightUpperArm = deg(70, 0, -22), LeftUpperArm = deg(42, 0, 24) } },
	}
end

local function deathBackward(): { Frame }
	return {
		{ time = 0, ease = "smooth", pose = { LowerTorso = move(0, 0, 0), UpperTorso = deg(0, 0, 0), Head = deg(0, 0, 0), RightUpperLeg = deg(0, 0, 0), LeftUpperLeg = deg(0, 0, 0), RightLowerLeg = deg(0, 0, 0), LeftLowerLeg = deg(0, 0, 0), RightUpperArm = deg(0, 0, 0), LeftUpperArm = deg(0, 0, 0) } },
		-- struck back: the chest arches, the arms fly
		{ time = 0.16, ease = "out", pose = { LowerTorso = move(0, -0.2, 0.25, 8, 0, 0), UpperTorso = deg(16, 0, 0), Head = deg(26, 0, 0), RightUpperLeg = deg(-12, 0, 0), LeftUpperLeg = deg(-8, 0, 0), RightLowerLeg = deg(-14, 0, 0), LeftLowerLeg = deg(-10, 0, 0), RightUpperArm = deg(-30, 0, -52), LeftUpperArm = deg(-34, 0, 48) } },
		{ time = 0.55, ease = "in", pose = { LowerTorso = move(0, -1.5, 1.0, 54, 0, -2), UpperTorso = deg(8, 0, 0), Head = deg(18, 0, 0), RightUpperLeg = deg(34, 0, 0), LeftUpperLeg = deg(20, 0, 0), RightLowerLeg = deg(-38, 0, 0), LeftLowerLeg = deg(-26, 0, 0), RightUpperArm = deg(-60, 0, -66), LeftUpperArm = deg(-56, 0, 60) } },
		{ time = 0.84, ease = "out", pose = { LowerTorso = move(0, -2.0, 1.45, 83, 0, -3), UpperTorso = deg(2, 0, 0), Head = deg(8, -16, 0), RightUpperLeg = deg(48, 0, 4), LeftUpperLeg = deg(18, 0, -6), RightLowerLeg = deg(-30, 0, 0), LeftLowerLeg = deg(-12, 0, 0), RightUpperArm = deg(-80, 0, -70), LeftUpperArm = deg(-70, 0, 64) } },
		{ time = 1.05, ease = "smooth", pose = { LowerTorso = move(0, -2.04, 1.5, 85, 0, -3), UpperTorso = deg(0, 0, 0), Head = deg(6, -18, 0), RightUpperLeg = deg(50, 0, 4), LeftUpperLeg = deg(20, 0, -6), RightLowerLeg = deg(-30, 0, 0), LeftLowerLeg = deg(-10, 0, 0), RightUpperArm = deg(-84, 0, -72), LeftUpperArm = deg(-74, 0, 66) } },
	}
end

local function deathKneel(): { Frame }
	return {
		{ time = 0, ease = "smooth", pose = { LowerTorso = move(0, 0, 0), UpperTorso = deg(0, 0, 0), Head = deg(0, 0, 0), RightUpperLeg = deg(0, 0, 0), LeftUpperLeg = deg(0, 0, 0), RightLowerLeg = deg(0, 0, 0), LeftLowerLeg = deg(0, 0, 0), RightUpperArm = deg(0, 0, 0), LeftUpperArm = deg(0, 0, 0) } },
		-- down on both knees
		{ time = 0.42, ease = "out", pose = { LowerTorso = move(0, -1.4, 0.1, -4, 0, 0), UpperTorso = deg(-6, 0, 0), Head = deg(-8, 0, 0), RightUpperLeg = deg(82, 0, 4), LeftUpperLeg = deg(80, 0, -4), RightLowerLeg = deg(-104, 0, 0), LeftLowerLeg = deg(-102, 0, 0), RightUpperArm = deg(18, 0, 0), LeftUpperArm = deg(14, 0, 0) } },
		-- the head falls, and then the chest
		{ time = 0.82, ease = "in", pose = { LowerTorso = move(0, -1.45, 0.1, -4, 0, 0), UpperTorso = deg(-42, 0, 3), Head = deg(-30, 6, 0), RightUpperLeg = deg(82, 0, 4), LeftUpperLeg = deg(80, 0, -4), RightLowerLeg = deg(-104, 0, 0), LeftLowerLeg = deg(-102, 0, 0), RightUpperArm = deg(40, 0, -6), LeftUpperArm = deg(34, 0, 6) } },
		{ time = 1.12, ease = "out", pose = { LowerTorso = move(0, -1.5, -0.1, -30, 0, 2), UpperTorso = deg(-60, 0, 4), Head = deg(-40, 8, 0), RightUpperLeg = deg(84, 0, 4), LeftUpperLeg = deg(82, 0, -4), RightLowerLeg = deg(-106, 0, 0), LeftLowerLeg = deg(-104, 0, 0), RightUpperArm = deg(66, 0, -10), LeftUpperArm = deg(60, 0, 10) } },
		{ time = 1.3, ease = "smooth", pose = { LowerTorso = move(0, -1.52, -0.14, -34, 0, 2), UpperTorso = deg(-62, 0, 4), Head = deg(-42, 8, 0), RightUpperLeg = deg(84, 0, 4), LeftUpperLeg = deg(82, 0, -4), RightLowerLeg = deg(-106, 0, 0), LeftLowerLeg = deg(-104, 0, 0), RightUpperArm = deg(70, 0, -10), LeftUpperArm = deg(64, 0, 10) } },
	}
end

--==========================================================================
-- ATTACKS
-- Each kind is { cock, hit [, stuck] }: the pose held at the end of the windup,
-- and the pose of the strike. The frames between are made from them.
--==========================================================================
type Attack = {
	cock: Pose,
	hit: Pose,
	stuck: number?, -- hold the strike pose for this fraction of the recover (a spade in the ground)
	settle: number?, -- the fraction of the recover the body takes to come back (default 1)
}

local ATTACKS: { [string]: Attack } = {
	-- the shambler: the reaching arm draws back, the jaw opens, then a slow shove and a bite
	shove = {
		cock = {
			UpperTorso = deg(10, 12, 0),
			RightUpperArm = deg(-52, 0, -6),
			RightLowerArm = deg(-34, 0, 0),
			LeftUpperArm = deg(-10, 0, 6),
			Head = deg(16, -8, 0),
			LowerTorso = move(0, 0, 0.15),
		},
		hit = {
			UpperTorso = deg(-26, -10, 0),
			RightUpperArm = deg(34, 0, 0),
			RightLowerArm = deg(18, 0, 0),
			LeftUpperArm = deg(12, 0, 0),
			Head = deg(-14, 6, 0),
			LowerTorso = move(0, -0.1, -0.55, -6, 0, 0),
		},
	},
	-- the courier: down into a crouch, a hitch, and a spring
	lunge = {
		cock = {
			LowerTorso = move(0, -0.75, 0.2, -8, 0, 0),
			UpperTorso = deg(-16, 0, 0),
			Head = deg(18, 0, 0),
			RightUpperLeg = deg(42, 0, 0),
			RightLowerLeg = deg(-76, 0, 0),
			LeftUpperLeg = deg(34, 0, 0),
			LeftLowerLeg = deg(-70, 0, 0),
			RightUpperArm = deg(-20, 0, -10),
			LeftUpperArm = deg(-22, 0, 10),
		},
		hit = {
			LowerTorso = move(0, 0.1, -1.1, -14, 0, 0),
			UpperTorso = deg(-20, 0, 0),
			Head = deg(16, 0, 0),
			RightUpperLeg = deg(-34, 0, 0),
			RightLowerLeg = deg(-8, 0, 0),
			LeftUpperLeg = deg(30, 0, 0),
			LeftLowerLeg = deg(-30, 0, 0),
			RightUpperArm = deg(76, 0, -6),
			LeftUpperArm = deg(68, 0, 6),
			RightLowerArm = deg(18, 0, 0),
			LeftLowerArm = deg(18, 0, 0),
		},
		settle = 0.4,
	},
	-- the gravedigger: both arms up and back, a long moment at the top, then the whole body drops with it
	overhead = {
		cock = {
			UpperTorso = deg(16, 0, 0),
			Head = deg(14, 0, 0),
			RightUpperArm = deg(52, 0, -6),
			RightLowerArm = deg(16, 0, 0),
			LeftUpperArm = deg(50, 0, 6),
			LeftLowerArm = deg(10, 0, 0),
			LowerTorso = move(0, 0.12, 0.25, 4, 0, 0),
		},
		hit = {
			UpperTorso = deg(-38, 0, 0),
			Head = deg(-14, 0, 0),
			RightUpperArm = deg(-78, 0, 0),
			RightLowerArm = deg(-44, 0, 0),
			LeftUpperArm = deg(-76, 0, 0),
			LeftLowerArm = deg(-40, 0, 0),
			LowerTorso = move(0, -0.4, -0.7, -10, 0, 0),
			RightUpperLeg = deg(16, 0, 0),
			RightLowerLeg = deg(-14, 0, 0),
			LeftUpperLeg = deg(10, 0, 0),
			LeftLowerLeg = deg(-10, 0, 0),
		},
		stuck = 0.72,
	},
	-- the pikeman: the pole draws back along the body, the feet plant, then it goes
	thrust = {
		cock = {
			UpperTorso = deg(4, 14, 0),
			RightUpperArm = deg(-28, 0, 0),
			RightLowerArm = deg(-40, 0, 0),
			LeftUpperArm = deg(-22, 0, 0),
			LeftLowerArm = deg(-30, 0, 0),
			LowerTorso = move(0, 0, 0.25),
			RightUpperLeg = deg(10, 0, 0),
			LeftUpperLeg = deg(-10, 0, 0),
		},
		hit = {
			UpperTorso = deg(-10, -12, 0),
			RightUpperArm = deg(24, 0, 0),
			RightLowerArm = deg(20, 0, 0),
			LeftUpperArm = deg(20, 0, 0),
			LeftLowerArm = deg(14, 0, 0),
			LowerTorso = move(0, -0.08, -0.7),
			RightUpperLeg = deg(16, 0, 0),
			LeftUpperLeg = deg(-14, 0, 0),
		},
	},
	-- the archer: the string hand comes back to the cheek, held, and let go
	draw = {
		cock = {
			UpperTorso = deg(0, -6, 0),
			RightUpperArm = deg(-18, 0, -22),
			RightLowerArm = deg(-34, 0, 0),
			Head = deg(0, 4, 0),
		},
		hit = {
			UpperTorso = deg(2, 4, 0),
			RightUpperArm = deg(14, 0, 8),
			RightLowerArm = deg(28, 0, 0),
			Head = deg(3, -2, 0),
		},
	},
	-- the Hollow Knight: the whole body winds to the right behind a sword drawn back over the
	-- shoulder (the plate groans), a long hold, then one wide cut across the front as the hips
	-- unwind and the weight comes onto the front foot. The head keeps the target while the body turns.
	sweep = {
		cock = {
			LowerTorso = move(0, -0.35, 0.3, -4, -32, 0),
			UpperTorso = deg(12, -72, 0),
			Head = deg(-4, 46, 0),
			RightUpperArm = deg(-38, 0, 72),
			RightLowerArm = deg(62, 0, 0),
			LeftUpperArm = deg(24, 0, 42),
			LeftLowerArm = deg(72, 0, 0),
			RightUpperLeg = deg(10, 0, 0),
			RightLowerLeg = deg(-18, 0, 0),
			LeftUpperLeg = deg(-6, 0, 0),
			LeftLowerLeg = deg(12, 0, 0),
		},
		hit = {
			LowerTorso = move(0, -0.12, -0.85, 2, 44, 0),
			UpperTorso = deg(-8, 84, 0),
			Head = deg(0, -52, 0),
			RightUpperArm = deg(72, 0, 14),
			RightLowerArm = deg(10, 0, 0),
			LeftUpperArm = deg(78, 0, 36),
			LeftLowerArm = deg(12, 0, 0),
			RightUpperLeg = deg(-30, 0, 0),
			RightLowerLeg = deg(8, 0, 0),
			LeftUpperLeg = deg(18, 0, 0),
			LeftLowerLeg = deg(-12, 0, 0),
		},
		settle = 0.85,
	},
	-- the shieldman: the shield draws back on the shoulder, the sword rises, then the bash
	bash = {
		cock = {
			UpperTorso = deg(0, -14, 0),
			LeftUpperArm = deg(-24, 0, 0),
			LeftLowerArm = deg(-30, 0, 0),
			RightUpperArm = deg(40, 0, 0),
			RightLowerArm = deg(20, 0, 0),
			LowerTorso = move(0, 0, 0.2),
		},
		hit = {
			UpperTorso = deg(-6, 16, 0),
			LeftUpperArm = deg(30, 0, 0),
			LeftLowerArm = deg(24, 0, 0),
			RightUpperArm = deg(-30, 0, 0),
			RightLowerArm = deg(-12, 0, 0),
			LowerTorso = move(0, -0.05, -0.6),
		},
	},
}

-- Which attack each type uses.
local KIND: { [string]: string } = {
	undead_shambler = "shove",
	undead_runner = "lunge",
	undead_brute_heavy = "overhead",
	undead_spearman = "thrust",
	undead_archer = "draw",
	undead_sentinel = "bash",
	undead_knight = "sweep",
	the_king = "bash",
}

local function attackFrames(a: Attack, W: number, S: number, R: number): { Frame }
	local frames: { Frame } = {}
	local function add(t: number, ease: Ease, pose: Pose)
		table.insert(frames, { time = t, ease = ease, pose = pose })
	end
	local zero: Pose = {}
	for bone in a.cock do
		zero[bone] = CFrame.new()
	end
	for bone in a.hit do
		zero[bone] = CFrame.new()
	end

	add(0, "smooth", zero)
	-- it loads the other way first: a small step toward the strike, before the cock
	add(W * 0.18, "out", part(a.hit, 0.16))
	-- the windup arrives at the top 26% early, so the last quarter of it is a HOLD:
	-- that is what the player reads
	add(W * 0.74, "smooth", a.cock)
	add(W, "flat", a.cock)
	-- the strike accelerates into the target
	add(W + S, "in", a.hit)
	if a.stuck then
		add(W + S + R * a.stuck, "flat", a.hit)
		add(W + S + R, "smooth", zero)
	else
		-- it rebounds a little toward the cock, then settles
		local settle = a.settle or 1
		add(W + S + R * 0.35 * settle, "out", between(a.hit, a.cock, 0.16))
		add(W + S + R * settle, "smooth", zero)
		if settle < 1 then
			add(W + S + R, "flat", zero)
		end
	end
	return frames
end

--==========================================================================
-- Registering
--==========================================================================
export type Timing = { windup: number, strike: number, recover: number }

export type Ids = {
	idle: string,
	walk: { string },
	run: string,
	aggro: string,
	flinch: string,
	death: { string },
	attack: { [string]: string }, -- by kind
	kindOf: { [string]: string }, -- by enemy type
	length: { [string]: number }, -- seconds, by kind
}

-- Kept alive for the session (see SwordAnims.register for why).
local registered: { KeyframeSequence } = {}

local function register(seq: KeyframeSequence): string
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	if not ok or typeof(result) ~= "string" or result == "" then
		error("could not register " .. seq.Name .. ": " .. tostring(result))
	end
	table.insert(registered, seq)
	return result
end

--[[
	Builds and registers the whole set. \`timings\` is by ATTACK KIND (not by enemy
	type): { windup, strike, recover }, so the clip lasts exactly as long as the
	server's attack does. A kind with no entry gets a sensible default.

	Returns nil and the reason if the engine will not register.
]]
function ZombieAnims.register(timings: { [string]: Timing }): (Ids?, string?)
	local ok, result = pcall(function()
		local P = Enum.AnimationPriority
		local ids: Ids = {
			idle = register(build("ZombieIdle", idleFrames(), true, P.Idle)),
			walk = {},
			run = register(build("ZombieRun", gaitFrames(RUN), true, P.Movement)),
			aggro = register(build("ZombieAggro", aggroFrames(), false, P.Action)),
			flinch = register(build("ZombieFlinch", flinchFrames(), false, P.Action2)),
			death = {
				register(build("ZombieDeathForward", deathForward(), false, P.Action4)),
				register(build("ZombieDeathBack", deathBackward(), false, P.Action4)),
				register(build("ZombieDeathKneel", deathKneel(), false, P.Action4)),
			},
			attack = {},
			kindOf = KIND,
			length = {},
		}
		for i, g in WALKS do
			table.insert(ids.walk, register(build("ZombieWalk" .. i, gaitFrames(g), true, P.Movement)))
		end
		for kind, a in ATTACKS do
			local t = timings[kind] or { windup = 0.8, strike = 0.15, recover = 0.6 }
			local frames = attackFrames(a, t.windup, t.strike, t.recover)
			ids.attack[kind] = register(build("ZombieAttack_" .. kind, frames, false, P.Action))
			ids.length[kind] = frames[#frames].time
		end
		return ids
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result :: Ids, nil
end

ZombieAnims.KIND = KIND

return ZombieAnims
