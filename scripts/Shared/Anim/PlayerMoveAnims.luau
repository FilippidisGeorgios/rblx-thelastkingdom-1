--!strict
--[[
	PlayerMoveAnims
	How a PLAYER moves (docs/systems/Movement.md): three whole movement sets and one roll, authored here as frames in
	code (the same angle convention as ZombieAnims and SwordAnims, docs/systems/Animation.md section 2) and PLAYED BY
	Shared/Anim/ClipPlayer, which writes the joints itself every physics step: a registered KeyframeSequence id does not
	work outside Studio, and Roblox's upgraded avatar joints only take a pose written before the physics step. Every
	client plays the same clips on every player it can see (Client/Controllers/MovementController); nothing replicates.

	--------------------------------------------------------------------------
	THE SETS (the developer, 2026-11-05: one walk for everybody, like "Command An Army"; three whole sets to choose from)

	  1  THE SOLDIER    (the Command An Army walk) upright and purposeful, a short firm step, the arms close and a little
	                    bent; the run leans in and pumps the fists; the jump tucks both knees.
	  2  THE RANGER     low and quiet: knees always a little bent, the chest forward, long soft steps that roll from heel
	                    to toe, the arms held in; the run is long and low; the jump is a stride, one knee up.
	  3  THE VETERAN    broad and heavy: a wider stance, the shoulders roll with each step, the arms swing out from the
	                    body; the run pounds; the jump throws both arms up.

	Each set: Idle (breathing, the weight shifting), Walk (authored for 16 studs a second), Run (24, Shift), Jump, Fall.
	Shared by all three: the ROLL (Q), a forward tumble, head under, that comes up in a crouch, and Sit and Climb.

	--------------------------------------------------------------------------
	ANGLES (a joint's rotation away from the standard R15 rest, degrees)

	    X  swings a limb that hangs down forward (+); on a part that stands up (torso, head) +X leans it BACK;
	       on a foot +X lifts the toes; on a forearm +X bends the elbow; on a shin - X bends the knee
	    Y  twists
	    Z  takes a hanging limb out to the character's right (+)
	    a shift (move) moves the joint in the parent's frame: -Z is forward, -Y is down

	A walk is SAMPLED (sixteen samples a stride joined by straight lines), not a few poses eased into each other: each leg
	runs the real cycle (the heel lands with the leg forward, the body passes over the planted foot, the knee gives as the
	weight lands and bends hard as the foot leaves, the swing is quick), and the ankle rolls the foot from heel to toe.

	Location: ReplicatedStorage.Shared.Anim.PlayerMoveAnims (pure construction: frames in, nothing touched).
]]

local PlayerMoveAnims = {}

local rad = math.rad
local TAU = 2 * math.pi

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

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
-- Building (the same as ZombieAnims)
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

local function newPose(name: string, cf: CFrame?, ease: Ease?, parent: Instance): Instance
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
	kf.Time = frame.time
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

local function wrap(x: number): number
	return x - math.floor(x)
end

-- a soft bump at phase 0, `width` wide, for a phase that wraps
local function bump(p: number, width: number): number
	local d = math.min(wrap(p), 1 - wrap(p))
	return math.exp(-(d / width) ^ 2)
end

--==========================================================================
-- THE STYLES (every number a style has; see the header for what each set is)
--==========================================================================
export type Gait = {
	D: number, -- seconds for one stride (two steps) at the authored speed
	S: number, -- thigh swing, degrees (forward at the heel strike)
	K: number, -- knee bend in the swing, degrees
	stance: number, -- share of a stride a foot is on the ground (0.6 walking, under 0.45 running)
	bend: number, -- knees always this bent (a low, soft gait)
	arms: number, -- upper arm swing, degrees
	elbow: number, -- elbows always this bent
	elbowSwing: number, -- and this much more on the forward swing
	armOut: number, -- arms held this far out from the body
	legOut: number, -- feet this far apart (a wide stance), degrees of the thigh outward
	yaw: number, -- chest twist against the hips
	roll: number, -- hips rolling side to side
	bob: number, -- how far the body drops at each footfall, studs
	lean: number, -- chest forward, degrees
	head: number, -- how far the head holds still against the twist (0 = turns with the chest, 1 = keeps facing ahead)
	nod: number, -- the head's small drop at each footfall
	impact: number, -- the chest's jolt at each footfall
	ankle: number, -- heel-to-toe roll of the foot
}

export type Style = {
	name: string,
	walk: Gait,
	run: Gait,
	idle: { stance: number, bend: number, lean: number, elbow: number, armOut: number, sway: number, breath: number, look: number },
	jump: string, -- "tuck" | "stride" | "arms"
	fall: { arms: number, legs: number },
}

local STYLES: { Style } = {
	{
		name = "Soldier",
		walk = { D = 0.76, S = 30, K = 40, stance = 0.6, bend = 4, arms = 22, elbow = 14, elbowSwing = 14, armOut = 5, legOut = 1.5, yaw = 6, roll = 2.5, bob = 0.11, lean = 4, head = 0.7, nod = 1.5, impact = 1.5, ankle = 14 },
		run = { D = 0.6, S = 46, K = 92, stance = 0.38, bend = 6, arms = 46, elbow = 70, elbowSwing = 18, armOut = 7, legOut = 1, yaw = 9, roll = 2, bob = 0.2, lean = 13, head = 0.8, nod = 2.5, impact = 3, ankle = 22 },
		idle = { stance = 3, bend = 6, lean = 2, elbow = 12, armOut = 5, sway = 1.6, breath = 1.4, look = 7 },
		jump = "tuck",
		fall = { arms = 38, legs = 1 },
	},
	{
		name = "Ranger",
		walk = { D = 0.82, S = 33, K = 46, stance = 0.62, bend = 12, arms = 15, elbow = 24, elbowSwing = 10, armOut = 3, legOut = 1, yaw = 4, roll = 1.5, bob = 0.07, lean = 9, head = 0.85, nod = 1, impact = 0.8, ankle = 18 },
		run = { D = 0.62, S = 52, K = 100, stance = 0.36, bend = 14, arms = 40, elbow = 78, elbowSwing = 12, armOut = 4, legOut = 0.5, yaw = 7, roll = 1.5, bob = 0.14, lean = 18, head = 0.9, nod = 1.5, impact = 2, ankle = 24 },
		idle = { stance = 2, bend = 13, lean = 7, elbow = 26, armOut = 3, sway = 1.0, breath = 1.0, look = 14 },
		jump = "stride",
		fall = { arms = 26, legs = 1.3 },
	},
	{
		name = "Veteran",
		walk = { D = 0.84, S = 27, K = 36, stance = 0.64, bend = 3, arms = 26, elbow = 10, elbowSwing = 12, armOut = 11, legOut = 4.5, yaw = 9, roll = 4.5, bob = 0.15, lean = 1, head = 0.55, nod = 2.5, impact = 3, ankle = 12 },
		run = { D = 0.64, S = 42, K = 84, stance = 0.42, bend = 5, arms = 44, elbow = 60, elbowSwing = 16, armOut = 12, legOut = 3, yaw = 12, roll = 3.5, bob = 0.26, lean = 10, head = 0.6, nod = 3.5, impact = 5, ankle = 18 },
		idle = { stance = 6, bend = 3, lean = -2, elbow = 9, armOut = 9, sway = 2.2, breath = 1.8, look = 5 },
		jump = "arms",
		fall = { arms = 48, legs = 0.8 },
	},
}

-- The speeds the clips are authored for (studs a second): the controller plays them faster or slower to match.
PlayerMoveAnims.WALK_PACE = 16
PlayerMoveAnims.RUN_PACE = 24

--==========================================================================
-- GAIT (walk and run)
--==========================================================================
local SAMPLES = 16

-- one leg at phase p (0 = the heel lands): thigh swing, knee bend, ankle
local function leg(p: number, g: Gait): (number, number, number)
	local st = g.stance
	local S, K = g.S, g.K
	p = wrap(p)
	if p < st then
		-- planted: the thigh sweeps back at an even rate; the knee gives as the weight lands, then bends as the foot leaves
		local q = p / st
		local thigh = S - S * 1.85 * q
		local knee = -g.bend - 10 * math.exp(-((q - 0.14) / 0.1) ^ 2) - 22 * math.clamp((q - 0.62) / 0.38, 0, 1) ^ 2
		-- the foot: toes up at the heel strike, flat through the middle, heel up as it pushes off
		local ankle = g.ankle * (0.7 * math.exp(-(q / 0.08) ^ 2) - 1.1 * math.clamp((q - 0.6) / 0.4, 0, 1) ^ 1.5)
		-- keep the planted foot flat while the shin turns over it
		ankle += -(thigh + knee) * 0.55 * (1 - math.clamp((q - 0.6) / 0.4, 0, 1))
		return thigh, knee, ankle
	end
	-- the swing: quick and eased, the knee folding up and opening again for the next heel strike
	local q = (p - st) / (1 - st)
	local thigh = -0.85 * S + 1.85 * S * (0.5 - 0.5 * math.cos(math.pi * q))
	local knee = -(g.bend + 22) * (1 - q) - K * 1.25 * math.sin(math.pi * q) - g.bend * q
	local ankle = g.ankle * (-0.6 * (1 - q) + 0.5 * q) + 6 * math.sin(math.pi * q)
	return thigh, knee, ankle
end

local function gaitFrames(g: Gait): { Frame }
	local frames: { Frame } = {}
	for i = 0, SAMPLES do
		local t = i / SAMPLES
		local rThigh, rKnee, rAnkle = leg(t, g)
		local lThigh, lKnee, lAnkle = leg(t + 0.5, g)
		local c = math.cos(TAU * t)
		local fall = math.max(bump(t - 0.05, 0.07), bump(t - 0.55, 0.07))
		local late = math.max(bump(t - 0.12, 0.08), bump(t - 0.62, 0.08))
		-- the body is lowest just after each heel lands and highest as it passes over the planted foot
		local drop = -g.bob * (0.5 + 0.5 * math.cos(2 * TAU * (t - 0.07)))
		-- arms: opposite to the legs, a beat behind; the forearm bends more on the forward swing
		local swing = math.cos(TAU * (t - 0.06))
		local rArm, lArm = -g.arms * swing, g.arms * swing
		frames[i + 1] = {
			time = t * g.D,
			ease = "flat",
			pose = {
				LowerTorso = move(0, drop, 0, 0, -g.yaw * 0.5 * c, g.roll * c),
				UpperTorso = deg(-g.lean - g.impact * fall, g.yaw * c, -g.roll * 0.5 * c),
				Head = deg(g.lean * 0.75 - g.nod * late, -g.yaw * g.head * c, g.roll * 0.3 * c),
				RightUpperArm = deg(rArm, 0, g.armOut),
				LeftUpperArm = deg(lArm, 0, -g.armOut),
				RightLowerArm = deg(g.elbow + g.elbowSwing * math.max(0, rArm / math.max(1, g.arms)), 0, 0),
				LeftLowerArm = deg(g.elbow + g.elbowSwing * math.max(0, lArm / math.max(1, g.arms)), 0, 0),
				RightHand = deg(-g.elbow * 0.15, 0, 0),
				LeftHand = deg(-g.elbow * 0.15, 0, 0),
				RightUpperLeg = deg(rThigh, 0, g.legOut),
				LeftUpperLeg = deg(lThigh, 0, -g.legOut),
				RightLowerLeg = deg(rKnee, 0, 0),
				LeftLowerLeg = deg(lKnee, 0, 0),
				RightFoot = deg(rAnkle, 0, -g.legOut),
				LeftFoot = deg(lAnkle, 0, g.legOut),
			},
		}
	end
	return frames
end

--==========================================================================
-- IDLE: the stance, breathing, the weight going from foot to foot, a look round now and then
--==========================================================================
local function idleFrames(s: Style): { Frame }
	local i = s.idle
	local frames: { Frame } = {}
	local LENGTH = 6
	local N = 24
	for k = 0, N do
		local t = k / N
		local breath = math.sin(TAU * t * 2) -- two breaths in the loop
		local shift = math.sin(TAU * t) -- the weight goes to one foot and back
		-- one slow look to the side in the second half of the loop
		local look = i.look * math.exp(-((t - 0.68) / 0.11) ^ 2)
		local bend = i.bend + 1.2 * shift
		frames[k + 1] = {
			time = t * LENGTH,
			ease = "flat",
			pose = {
				LowerTorso = move(0.045 * i.sway * shift, -0.015 * i.bend - 0.01 * breath, 0, 0, 0, -i.sway * shift),
				UpperTorso = deg(-i.lean - 0.8 * i.breath * breath, 0, i.sway * 0.5 * shift),
				Head = deg(i.lean * 0.6 + 0.4 * breath, look, -i.sway * 0.3 * shift),
				RightUpperArm = deg(2 + 0.6 * breath, 0, i.armOut + 0.6 * i.breath * breath),
				LeftUpperArm = deg(2 + 0.6 * breath, 0, -i.armOut - 0.6 * i.breath * breath),
				RightLowerArm = deg(i.elbow, 0, 0),
				LeftLowerArm = deg(i.elbow, 0, 0),
				RightUpperLeg = deg(bend * 0.6, 0, i.stance + i.sway * 0.4 * shift),
				LeftUpperLeg = deg((i.bend - 1.2 * shift) * 0.6, 0, -i.stance + i.sway * 0.4 * shift),
				RightLowerLeg = deg(-bend, 0, 0),
				LeftLowerLeg = deg(-(i.bend - 1.2 * shift), 0, 0),
				RightFoot = deg(bend * 0.4, 0, -i.stance),
				LeftFoot = deg((i.bend - 1.2 * shift) * 0.4, 0, i.stance),
			},
		}
	end
	return frames
end

--==========================================================================
-- JUMP (once, held at its top) and FALL (looped)
--==========================================================================
local function jumpFrames(s: Style): { Frame }
	local load: Pose, up: Pose
	if s.jump == "stride" then
		load = {
			LowerTorso = move(0, -0.3, 0),
			UpperTorso = deg(-14, 0, 0),
			RightUpperLeg = deg(30, 0, 0), RightLowerLeg = deg(-40, 0, 0), RightFoot = deg(10, 0, 0),
			LeftUpperLeg = deg(10, 0, 0), LeftLowerLeg = deg(-30, 0, 0), LeftFoot = deg(14, 0, 0),
			RightUpperArm = deg(-20, 0, 6), LeftUpperArm = deg(25, 0, -6),
		}
		up = {
			LowerTorso = move(0, 0, 0),
			UpperTorso = deg(-8, 0, 0),
			RightUpperLeg = deg(68, 0, 2), RightLowerLeg = deg(-95, 0, 0), RightFoot = deg(20, 0, 0),
			LeftUpperLeg = deg(-22, 0, -2), LeftLowerLeg = deg(-30, 0, 0), LeftFoot = deg(-18, 0, 0),
			RightUpperArm = deg(-35, 0, 10), RightLowerArm = deg(40, 0, 0),
			LeftUpperArm = deg(55, 0, -10), LeftLowerArm = deg(50, 0, 0),
			Head = deg(4, 0, 0),
		}
	elseif s.jump == "arms" then
		load = {
			LowerTorso = move(0, -0.4, 0),
			UpperTorso = deg(-18, 0, 0),
			RightUpperLeg = deg(28, 0, 4), LeftUpperLeg = deg(28, 0, -4),
			RightLowerLeg = deg(-50, 0, 0), LeftLowerLeg = deg(-50, 0, 0),
			RightFoot = deg(22, 0, -4), LeftFoot = deg(22, 0, 4),
			RightUpperArm = deg(-30, 0, 14), LeftUpperArm = deg(-30, 0, -14),
		}
		up = {
			LowerTorso = move(0, 0, 0),
			UpperTorso = deg(4, 0, 0),
			RightUpperLeg = deg(22, 0, 6), LeftUpperLeg = deg(14, 0, -6),
			RightLowerLeg = deg(-46, 0, 0), LeftLowerLeg = deg(-38, 0, 0),
			RightFoot = deg(-12, 0, -6), LeftFoot = deg(-10, 0, 6),
			RightUpperArm = deg(150, 0, 22), RightLowerArm = deg(20, 0, 0),
			LeftUpperArm = deg(150, 0, -22), LeftLowerArm = deg(20, 0, 0),
			Head = deg(10, 0, 0),
		}
	else -- "tuck"
		load = {
			LowerTorso = move(0, -0.35, 0),
			UpperTorso = deg(-16, 0, 0),
			RightUpperLeg = deg(30, 0, 2), LeftUpperLeg = deg(30, 0, -2),
			RightLowerLeg = deg(-52, 0, 0), LeftLowerLeg = deg(-52, 0, 0),
			RightFoot = deg(22, 0, 0), LeftFoot = deg(22, 0, 0),
			RightUpperArm = deg(-28, 0, 8), LeftUpperArm = deg(-28, 0, -8),
		}
		up = {
			LowerTorso = move(0, 0, 0),
			UpperTorso = deg(-6, 0, 0),
			RightUpperLeg = deg(58, 0, 3), LeftUpperLeg = deg(50, 0, -3),
			RightLowerLeg = deg(-92, 0, 0), LeftLowerLeg = deg(-86, 0, 0),
			RightFoot = deg(18, 0, 0), LeftFoot = deg(16, 0, 0),
			RightUpperArm = deg(70, 0, 16), RightLowerArm = deg(45, 0, 0),
			LeftUpperArm = deg(64, 0, -16), LeftLowerArm = deg(45, 0, 0),
			Head = deg(-4, 0, 0),
		}
	end
	return {
		{ time = 0, ease = "out", pose = load },
		{ time = 0.09, ease = "out", pose = load },
		{ time = 0.32, ease = "smooth", pose = up },
		{ time = 0.5, ease = "smooth", pose = up },
	}
end

local function fallFrames(s: Style): { Frame }
	local f = s.fall
	local frames: { Frame } = {}
	local N = 8
	for k = 0, N do
		local t = k / N
		local w = math.sin(TAU * t)
		frames[k + 1] = {
			time = t * 0.9,
			ease = "flat",
			pose = {
				UpperTorso = deg(-4 + 2 * w, 0, 0),
				Head = deg(-8, 0, 0),
				-- the arms out for balance, paddling a little
				RightUpperArm = deg(20 + 6 * w, 0, f.arms + 5 * w),
				LeftUpperArm = deg(20 - 6 * w, 0, -f.arms + 5 * w),
				RightLowerArm = deg(25, 0, 0),
				LeftLowerArm = deg(25, 0, 0),
				-- the legs reaching for the ground, one a little ahead
				RightUpperLeg = deg((18 + 6 * w) * f.legs, 0, 3),
				LeftUpperLeg = deg((6 - 6 * w) * f.legs, 0, -3),
				RightLowerLeg = deg(-30 * f.legs, 0, 0),
				LeftLowerLeg = deg(-22 * f.legs, 0, 0),
				RightFoot = deg(-6, 0, 0),
				LeftFoot = deg(-8, 0, 0),
			},
		}
	end
	return frames
end

--==========================================================================
-- THE ROLL (Q): a forward tumble, the head goes under, and up again in a crouch. Shared by every set.
--==========================================================================
--[[
	The body turns a whole circle round the hips (the root joint), in steps of no more than 75 degrees so the engine's
	rotation between two keys always goes the same way round. As it goes the hips drop until the tucked body touches the
	ground, the knees come up to the chest, the arms hug them and the chin goes in; for the last quarter the legs open to
	land and the body rises out of a crouch. The ground it covers is the controller's (a push along the ground); this is
	only the body turning over.
]]
local ROLL_LENGTH = 0.6

local function rollFrames(): { Frame }
	local tuck: Pose = {
		UpperTorso = deg(-38, 0, 0),
		Head = deg(-42, 0, 0),
		RightUpperLeg = deg(112, 0, 6), LeftUpperLeg = deg(112, 0, -6),
		RightLowerLeg = deg(-138, 0, 0), LeftLowerLeg = deg(-138, 0, 0),
		RightFoot = deg(30, 0, 0), LeftFoot = deg(30, 0, 0),
		RightUpperArm = deg(88, 0, 10), LeftUpperArm = deg(88, 0, -10),
		RightLowerArm = deg(78, 0, 0), LeftLowerArm = deg(78, 0, 0),
	}
	local reach: Pose = {
		UpperTorso = deg(-30, 0, 0),
		Head = deg(-30, 0, 0),
		RightUpperLeg = deg(70, 0, 4), LeftUpperLeg = deg(62, 0, -4),
		RightLowerLeg = deg(-95, 0, 0), LeftLowerLeg = deg(-88, 0, 0),
		RightFoot = deg(25, 0, 0), LeftFoot = deg(22, 0, 0),
		RightUpperArm = deg(75, 0, 14), LeftUpperArm = deg(75, 0, -14),
		RightLowerArm = deg(25, 0, 0), LeftLowerArm = deg(25, 0, 0),
	}
	local land: Pose = {
		UpperTorso = deg(-22, 0, 0),
		Head = deg(-8, 0, 0),
		RightUpperLeg = deg(78, 0, 5), LeftUpperLeg = deg(58, 0, -5),
		RightLowerLeg = deg(-112, 0, 0), LeftLowerLeg = deg(-86, 0, 0),
		RightFoot = deg(30, 0, 0), LeftFoot = deg(26, 0, 0),
		RightUpperArm = deg(30, 0, 22), LeftUpperArm = deg(36, 0, -22),
		RightLowerArm = deg(30, 0, 0), LeftLowerArm = deg(30, 0, 0),
	}
	local up: Pose = {
		UpperTorso = deg(-8, 0, 0),
		Head = deg(0, 0, 0),
		RightUpperLeg = deg(20, 0, 3), LeftUpperLeg = deg(14, 0, -3),
		RightLowerLeg = deg(-30, 0, 0), LeftLowerLeg = deg(-24, 0, 0),
		RightFoot = deg(10, 0, 0), LeftFoot = deg(8, 0, 0),
		RightUpperArm = deg(10, 0, 10), LeftUpperArm = deg(12, 0, -10),
		RightLowerArm = deg(18, 0, 0), LeftLowerArm = deg(18, 0, 0),
	}
	-- the turn round the hips (negative X: the head goes forward and under) and how low the hips are, by time
	local turn: { { any } } = {
		{ 0.00, 0, 0, 0, false },
		{ 0.06, -32, -0.75, -0.2, reach },
		{ 0.13, -95, -1.35, -0.35, tuck },
		{ 0.21, -165, -1.5, -0.3, tuck },
		{ 0.29, -235, -1.5, -0.2, tuck },
		{ 0.37, -300, -1.4, -0.1, tuck },
		{ 0.45, -335, -1.15, 0, land },
		{ 0.53, -355, -0.55, 0, up },
		{ 0.60, -360, 0, 0, up },
	}
	local frames: { Frame } = {}
	for _, k in turn do
		local pose: Pose = {}
		if k[5] then
			for bone, cf in k[5] :: Pose do
				pose[bone] = cf
			end
		else
			for bone in tuck do
				pose[bone] = CFrame.new()
			end
		end
		pose.LowerTorso = CFrame.new(0, k[3], k[4]) * CFrame.Angles(rad(k[2]), 0, 0)
		frames[#frames + 1] = { time = k[1] * ROLL_LENGTH / 0.6, ease = "flat", pose = pose }
	end
	return frames
end

PlayerMoveAnims.ROLL_LENGTH = ROLL_LENGTH

--==========================================================================
-- SIT and CLIMB (shared)
--==========================================================================
local function sitFrames(): { Frame }
	local pose: Pose = {
		UpperTorso = deg(4, 0, 0),
		RightUpperLeg = deg(88, 0, 4), LeftUpperLeg = deg(88, 0, -4),
		RightLowerLeg = deg(-86, 0, 0), LeftLowerLeg = deg(-86, 0, 0),
		RightUpperArm = deg(38, 0, 8), LeftUpperArm = deg(38, 0, -8),
		RightLowerArm = deg(34, 0, 0), LeftLowerArm = deg(34, 0, 0),
	}
	return { { time = 0, pose = pose }, { time = 1, pose = pose } }
end

local function climbFrames(): { Frame }
	local frames: { Frame } = {}
	local N = 8
	for k = 0, N do
		local t = k / N
		local s = math.sin(TAU * t)
		frames[k + 1] = {
			time = t * 0.9,
			ease = "flat",
			pose = {
				UpperTorso = deg(-6, 0, 0),
				Head = deg(12, 0, 0),
				RightUpperArm = deg(150 + 25 * s, 0, 10), LeftUpperArm = deg(150 - 25 * s, 0, -10),
				RightLowerArm = deg(30 - 20 * s, 0, 0), LeftLowerArm = deg(30 + 20 * s, 0, 0),
				RightUpperLeg = deg(30 - 30 * s, 0, 4), LeftUpperLeg = deg(30 + 30 * s, 0, -4),
				RightLowerLeg = deg(-50 + 35 * s, 0, 0), LeftLowerLeg = deg(-50 - 35 * s, 0, 0),
			},
		}
	end
	return frames
end

--==========================================================================
-- The clips, by name
--==========================================================================
export type ClipDef = { frames: { Frame }, looped: boolean }

--[[
	Every clip of one set (1..COUNT): idle, walk, run, jump, fall; and the shared roll, sit, climb. The movement loops
	stand UNDER anything a weapon does (MovementController leaves the sword arm to the sword while it is drawn).
]]
function PlayerMoveAnims.clips(set: number): { [string]: ClipDef }
	local s = STYLES[set] or STYLES[1]
	return {
		idle = { frames = idleFrames(s), looped = true },
		walk = { frames = gaitFrames(s.walk), looped = true },
		run = { frames = gaitFrames(s.run), looped = true },
		jump = { frames = jumpFrames(s), looped = false },
		fall = { frames = fallFrames(s), looped = true },
		roll = { frames = rollFrames(), looped = false },
		sit = { frames = sitFrames(), looped = true },
		climb = { frames = climbFrames(), looped = true },
	}
end

-- The name of a set, for the log and the docs.
function PlayerMoveAnims.name(set: number): string
	return (STYLES[set] or STYLES[1]).name
end

-- How many sets there are (for a check of the config).
PlayerMoveAnims.COUNT = #STYLES

-- One clip's frames, for a test or a preview tool.
function PlayerMoveAnims.frames(set: number, clip: string): { Frame }
	local def = PlayerMoveAnims.clips(set)[clip]
	return if def then def.frames else {}
end

--[[
	One clip as a KeyframeSequence (for the developer to save as a real animation asset one day, or to look at in the
	Animation Editor): parent it under a rig's AnimSaves. Not used by the game.
]]
function PlayerMoveAnims.sequence(set: number, clip: string): KeyframeSequence
	local def = PlayerMoveAnims.clips(set)[clip]
	return build(("Player_%d_%s"):format(set, clip), if def then def.frames else {}, def ~= nil and def.looped, Enum.AnimationPriority.Core)
end

return PlayerMoveAnims
