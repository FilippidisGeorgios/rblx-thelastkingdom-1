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
	Shared by all three: the ROLL (Q), a tumble, head under, that comes up in a crouch, and Sit and Climb.

	EVERY WAY, NOT ONLY FORWARD (2026-11-10). The game is first person: the body faces where the eyes look while the feet
	go back or sideways, and a forward walk slid backward is a moonwalk. So a walk and a run each have four clips with the
	SAME stride time (forward, back, right, left), which the controller blends by the way the feet are really going; a
	diagonal is two of them at the same step. A sidestep reaches out with the leading leg and closes with the other (the
	legs never cross); a backward step is shorter and the chest sits back.
	And CROUCHED (Ctrl): a still crouch and a crouched walk every way, a real one (the hips lowered, the legs folded under
	them by IK, the chest over the knees; see THE CROUCH).

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
		run = { D = 0.6, S = 46, K = 92, stance = 0.38, bend = 6, arms = 40, elbow = 62, elbowSwing = 12, armOut = 7, legOut = 1, yaw = 9, roll = 2, bob = 0.2, lean = 13, head = 0.8, nod = 2.5, impact = 3, ankle = 22 },
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
PlayerMoveAnims.DUCK_PACE = 8

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

--[[
	THE GROUND (2026-11-15). The square body's legs, measured on the body itself (tools/Filmstrip `geometry`: every
	player has this one body, Services/AvatarService): the joint seats of the hips, knees and ankles in the root's space.
	With them the height of a foot's sole can be worked out for any pose, and every gait is set on the ground BY ITS
	OWN LEGS: the hips go exactly as low as the planted foot needs, so a foot never sinks into the floor or floats over
	it, and a run leaves the ground only between two steps (the hips then follow a short arc).
]]
local LEG_SEATS = {
	-- LowerTorso: its seat on the root, and the part's centre from its joint
	torso0 = CFrame.new(0, -1, 0),
	torso1 = CFrame.new(0, 0.2, 0),
	-- hip (on the LowerTorso, x mirrored for the left), knee, ankle; and each part's centre from its own joint
	hip = Vector3.new(0.5, -0.2, 0),
	thigh1 = CFrame.new(0, -0.4208, 0),
	knee0 = CFrame.new(0, -0.4009, 0),
	shin1 = CFrame.new(0, -0.3792, 0),
	ankle0 = CFrame.new(0, -0.5472, 0),
	foot1 = CFrame.new(0, -0.1019, 0),
	-- the foot is 1 x 0.3 x 1: its sole's corners from its centre
	sole = { Vector3.new(0.5, -0.15, 0.5), Vector3.new(-0.5, -0.15, 0.5), Vector3.new(0.5, -0.15, -0.5), Vector3.new(-0.5, -0.15, -0.5) },
	-- the root's centre stands 3 studs above the floor (HipHeight 2 + half of the 2-stud root)
	stand = 3,
}

-- How high the lowest corner of one foot's sole is above the floor under `pose` ("Right" or "Left").
local function soleHeight(pose: Pose, side: string): number
	local s = LEG_SEATS
	local torso = s.torso0 * (pose.LowerTorso or CFrame.new()) * s.torso1
	local hip = if side == "Right" then s.hip else Vector3.new(-s.hip.X, s.hip.Y, s.hip.Z)
	local thigh = torso * CFrame.new(hip) * (pose[side .. "UpperLeg"] or CFrame.new()) * s.thigh1
	local shin = thigh * s.knee0 * (pose[side .. "LowerLeg"] or CFrame.new()) * s.shin1
	local foot = shin * s.ankle0 * (pose[side .. "Foot"] or CFrame.new()) * s.foot1
	local low = math.huge
	for _, corner in s.sole do
		low = math.min(low, (foot * corner).Y)
	end
	return low + s.stand
end

PlayerMoveAnims.soleHeight = soleHeight

--[[
	Sets a gait's frames on the ground. `planted(at)` says which feet are down at a sample ("Right", "Left", both or
	neither); `rise` lifts the whole body (a crouch: the root itself is lowered by the Humanoid, so the feet must reach
	that much higher). A walk always has a foot down; a run's flights are filled with an arc from take-off to landing.
]]
local FLIGHT_ARC = 0.2 -- how far the hips rise in a run's flight above the line from take-off to landing, studs

local function ground(frames: { Frame }, phases: { number }, stance: number, rise: number)
	local n = #frames
	local need: { number? } = {}
	for i, frame in frames do
		local at = phases[i]
		local right = wrap(at) < stance
		local left = wrap(at + 0.5) < stance
		local low: number? = nil
		if right then
			low = soleHeight(frame.pose, "Right")
		end
		if left then
			local l = soleHeight(frame.pose, "Left")
			low = if low then math.min(low, l) else l
		end
		need[i] = if low then rise - low else nil
	end
	-- a flight: from the last foot down to the next, on a line with an arc over it (the samples wrap round)
	for i = 1, n do
		if need[i] == nil then
			local a, b = i, i
			local da, db = 0, 0
			repeat
				a = if a == 1 then n else a - 1
				da += 1
			until need[a] ~= nil or da > n
			repeat
				b = if b == n then 1 else b + 1
				db += 1
			until need[b] ~= nil or db > n
			local from, to = need[a] or 0, need[b] or 0
			local u = da / (da + db)
			frames[i].pose.LowerTorso = CFrame.new(0, from + (to - from) * u + FLIGHT_ARC * 4 * u * (1 - u), 0) * (frames[i].pose.LowerTorso or CFrame.new())
			frames[i].ease = "flat"
		end
	end
	for i = 1, n do
		local d = need[i]
		if d then
			frames[i].pose.LowerTorso = CFrame.new(0, d, 0) * (frames[i].pose.LowerTorso or CFrame.new())
		end
	end
end

-- What changes a gait without being a new one: played `back`ward (the feet go the other way), and `squat` degrees
-- of extra thigh so that a deep knee bend keeps the feet under the hips (the ducked walk), and `rise`: how far the
-- Humanoid itself lowers the body (a crouch), which the feet must reach up to.
type GaitOptions = { back: boolean?, squat: number?, sink: number?, rise: number? }

local function gaitFrames(g: Gait, options: GaitOptions?): { Frame }
	local frames: { Frame } = {}
	local back = options ~= nil and options.back == true
	local squat = (options and options.squat) or 0
	local rise = (options and options.rise) or 0
	local phases: { number } = {}
	for i = 0, SAMPLES do
		local t = i / SAMPLES
		-- backward: the same step, run the other way round (the heel leaves first, the toe lands)
		local at = if back then 1 - t else t
		phases[i + 1] = at
		local rThigh, rKnee, rAnkle = leg(at, g)
		local lThigh, lKnee, lAnkle = leg(at + 0.5, g)
		rThigh += squat
		lThigh += squat
		rAnkle -= squat * 0.45
		lAnkle -= squat * 0.45
		local c = math.cos(TAU * at)
		local fall = math.max(bump(at - 0.05, 0.07), bump(at - 0.55, 0.07))
		local late = math.max(bump(at - 0.12, 0.08), bump(at - 0.62, 0.08))
		-- (how high the hips are is not drawn: `ground` sets them where the planted foot needs them)
		-- arms: opposite to the legs, a beat behind; the forearm bends more on the forward swing
		local swing = math.cos(TAU * (at - 0.06))
		local rArm, lArm = -g.arms * swing, g.arms * swing
		frames[i + 1] = {
			time = t * g.D,
			ease = "flat",
			pose = {
				LowerTorso = deg(0, -g.yaw * 0.5 * c, g.roll * c),
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
	ground(frames, phases, g.stance, rise)
	return frames
end

--[[
	THE SIDESTEP. `dir` +1 goes to the body's right, -1 to its left. The same leg cycle as the walk (plant, pass over,
	lift, swing), but the thigh swings OUT instead of forward: the leading leg plants far out and the body passes over
	it; the other plants close in and is left far out behind. The legs never cross (`CLOSE` is how far a leg comes past
	the middle). A lifted foot comes straight up (the thigh rises by half of what the knee bends), and each ankle keeps
	its sole flat.
]]
local CLOSE = 5

local function sideFrames(g: Gait, dir: number, options: GaitOptions?): { Frame }
	local frames: { Frame } = {}
	local squat = (options and options.squat) or 0
	local rise = (options and options.rise) or 0
	local phases: { number } = {}
	local reach = math.min(g.S * 0.8, 30)
	local half = (reach + CLOSE) / 2
	local lead = (reach - CLOSE) / 2
	-- the middle of each leg's sweep: the leading leg works out to its own side, the trailing one in under the body
	local rMid = if dir > 0 then lead else -lead
	local lMid = -rMid
	for i = 0, SAMPLES do
		local t = i / SAMPLES
		local rSwing, rKnee0 = leg(t, g)
		local lSwing, lKnee0 = leg(t + 0.5, g)
		local rOut = dir * (rMid + half * rSwing / g.S)
		local lOut = dir * (lMid + half * lSwing / g.S)
		-- the knee only does about half of a walking knee: a sidestep lifts the foot, it does not kick it back
		local rKnee = -g.bend - (-rKnee0 - g.bend) * 0.55
		local lKnee = -g.bend - (-lKnee0 - g.bend) * 0.55
		local rLift = -rKnee * 0.5 + squat
		local lLift = -lKnee * 0.5 + squat
		local c = math.cos(TAU * t)
		local fall = math.max(bump(t - 0.05, 0.07), bump(t - 0.55, 0.07))
		local swing = math.cos(TAU * (t - 0.06))
		phases[i + 1] = t
		frames[i + 1] = {
			time = t * g.D,
			ease = "flat",
			pose = {
				LowerTorso = deg(0, 0, -dir * 1.5 + g.roll * 0.8 * c),
				UpperTorso = deg(-g.lean * 0.5 - g.impact * 0.6 * fall, -dir * 3, -dir * 2 - g.roll * 0.4 * c),
				Head = deg(g.lean * 0.35, dir * 3, dir * 1.5),
				-- the arms a little out for balance, swinging small
				RightUpperArm = deg(g.arms * 0.25 * swing, 0, g.armOut + 4 + (if dir > 0 then 3 else 0)),
				LeftUpperArm = deg(-g.arms * 0.25 * swing, 0, -g.armOut - 4 - (if dir < 0 then 3 else 0)),
				RightLowerArm = deg(g.elbow + 8, 0, 0),
				LeftLowerArm = deg(g.elbow + 8, 0, 0),
				RightUpperLeg = deg(rLift, 0, rOut),
				LeftUpperLeg = deg(lLift, 0, lOut),
				RightLowerLeg = deg(rKnee, 0, 0),
				LeftLowerLeg = deg(lKnee, 0, 0),
				RightFoot = deg(-(rLift + rKnee) * 0.8, 0, -rOut),
				LeftFoot = deg(-(lLift + lKnee) * 0.8, 0, -lOut),
			},
		}
	end
	ground(frames, phases, g.stance, rise)
	return frames
end

-- A walk or a run going BACKWARD: a shorter step, the chest sat back, the arms quieter.
local function backGait(g: Gait): Gait
	local b = table.clone(g)
	b.S = g.S * 0.74
	b.K = g.K * 0.7
	b.arms = g.arms * 0.55
	b.lean = -g.lean * 0.35
	b.yaw = g.yaw * 0.6
	b.bob = g.bob * 0.8
	return b
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
	-- both feet down, all the time
	ground(frames, table.create(#frames, 0), 1, 0)
	return frames
end

--==========================================================================
-- THE CROUCH (Ctrl). 2026-11-15: a real one. Until now the body was made SMALLER (half its height); the developer
-- asked for real crouching. The Humanoid now lowers the hips (CrouchService: HipHeight down by `drop`, the same as
-- configs/Crouch.HipDrop, Tests/Crouch.spec checks it) and the legs fold under them by IK so each foot is set on the
-- floor where the step puts it (flat while it bears the weight), the pelvis tips forward, the chest leans over the
-- knees and the head comes up to look ahead. The head stays under 3.8 studs (tools/Filmstrip), so the cellar's crawl
-- was raised from 3.4 to 4.1 (a standing body, 5.2, still cannot pass). The same build gives the still crouch, the walk ahead and back, and the side steps.
--==========================================================================
local CROUCH = {
	drop = 0.95, -- studs the Humanoid lowers the hips by (configs/Crouch.HipDrop)
	pelvis = -18, -- the pelvis tipped forward, degrees
	chest = -27, -- and the chest further over it (45 degrees in all)
	head = 40, -- the head lifted back to look ahead
	back = 0.35, -- the hips sit back this far, so the head, over the knees, is not far ahead of the body
	step = 0.55, -- how far a foot goes ahead of the hip, and behind it, while it bears the weight
	lift = 0.32, -- how high a foot comes up as it goes forward again
	width = 0.6, -- the feet this far out from the middle (the hips are 0.5): a wider base, low down
	stride = 0.92, -- seconds for two steps at DUCK_PACE
	stance = 0.62, -- share of the stride a foot is down
}
PlayerMoveAnims.CROUCH_DROP = CROUCH.drop

-- the square body's leg: hip to knee, knee to ankle, ankle to sole (LEG_SEATS)
local THIGH, SHIN, ANKLE = 0.8217, 0.9264, 0.2519

--[[
	The thigh and knee (the pose's angles, degrees: thigh forward +, knee bent -) that put the ankle `ahead` studs in
	front of the hip and `below` under it, with the pelvis tipped `pelvis` degrees. The knee always bends forward.
]]
local function legIK(ahead: number, below: number, pelvis: number): (number, number, number)
	local r = math.clamp(math.sqrt(ahead * ahead + below * below), 0.25, THIGH + SHIN - 1e-3)
	local phi = math.atan2(ahead, below)
	local alpha = math.acos(math.clamp((THIGH * THIGH + r * r - SHIN * SHIN) / (2 * THIGH * r), -1, 1))
	local beta = math.acos(math.clamp((THIGH * THIGH + SHIN * SHIN - r * r) / (2 * THIGH * SHIN), -1, 1))
	local world = math.deg(phi + alpha)
	local knee = -(180 - math.deg(beta))
	-- (the pose's thigh is measured from the pelvis; the third value is the foot's angle that keeps the sole flat)
	return world - pelvis, knee, -(world + knee)
end

-- `forward`, `side`: the way the feet go in the body's own space ((1, 0) ahead, (-1, 0) back, (0, 1) right, (0, -1)
-- left); (0, 0) is the crouch held still.
local function crouchFrames(forward: number, side: number, rise: number?): { Frame }
	local c = CROUCH
	local lowered = rise or c.drop
	local still = forward == 0 and side == 0
	local length = if still then 5 else c.stride
	local frames: { Frame } = {}
	local phases: { number } = {}
	-- the hip joints stand this high over the floor when the hips are lowered by `drop` and nothing else moves them
	local hip = 2 - lowered
	for i = 0, SAMPLES do
		local t = i / SAMPLES
		phases[i + 1] = t
		local pose: Pose = {}
		local breath = math.sin(TAU * t * (if still then 2 else 1))
		local sway = if still then 0 else math.cos(TAU * t)
		for _, name in { "Right", "Left" } do
			local sign = if name == "Right" then 1 else -1
			local p = wrap(t + (if name == "Left" then 0.5 else 0))
			local along, up = 0, 0
			if not still then
				if p < c.stance then
					-- down: the foot goes from ahead of the hip to behind it
					along = c.step * (1 - 2 * p / c.stance)
				else
					-- up: it comes forward again, lifted, quick and eased
					local q = (p - c.stance) / (1 - c.stance)
					along = c.step * (-1 + 2 * (0.5 - 0.5 * math.cos(math.pi * q)))
					up = c.lift * math.sin(math.pi * q)
				end
			end
			-- a still crouch: one foot a little ahead of the other, the weight shifting with the breath
			local ahead = if still then 0.22 * sign + 0.03 * breath else along * forward
			local below = hip - ANKLE - up
			local thigh, knee, flat = legIK(ahead, below, c.pelvis)
			local lateral = (c.width - 0.5) * sign + along * side
			local out = math.deg(math.atan2(lateral, below))
			pose[name .. "UpperLeg"] = deg(thigh, 0, out)
			pose[name .. "LowerLeg"] = deg(knee, 0, 0)
			-- the sole flat while it bears the weight; the toes down a little as it lifts
			pose[name .. "Foot"] = deg(flat - 14 * (up / c.lift), 0, -out)
		end
		pose.LowerTorso = CFrame.new(0, 0, c.back) * deg(c.pelvis, 4 * sway * forward, 2.5 * sway)
		pose.UpperTorso = deg(c.chest - 1.5 * breath, -3 * sway * forward, -1.2 * sway)
		pose.Head = deg(c.head + 0.8 * breath, 0, 0)
		-- the arms forward and low, the forearms up, hands ready by the knees; a small swing against the legs
		local swing = if still then 0 else 7 * math.cos(TAU * (t - 0.06))
		pose.RightUpperArm = deg(56 - swing * forward, 0, 12)
		pose.LeftUpperArm = deg(56 + swing * forward, 0, -12)
		pose.RightLowerArm = deg(40, 0, 0)
		pose.LeftLowerArm = deg(40, 0, 0)
		pose.RightHand = deg(-8, 0, 0)
		pose.LeftHand = deg(-8, 0, 0)
		frames[i + 1] = { time = t * length, ease = "flat", pose = pose }
	end
	-- the feet reach down to the floor the lowered hips stand over
	ground(frames, phases, if still then 1 else c.stance, lowered)
	return frames
end

--==========================================================================
-- SCENE POSES (2026-11-15). The party on the hill in the arrival scene: the developer asked that not everyone stands
-- the same way. Each is one way of waiting (breathing, a small shift of weight), played by every client on a body whose
-- character has the attribute `ScenePose` (Server/World/IntroService gives one to each player). The legs that bear
-- the weight are set on the ground by their soles (`ground`); kneeling and sitting fold the legs by IK (`legIK`).
--==========================================================================
local SCENE_POSES = { "watch", "arms", "kneel", "brow", "sit", "crouch", "hips", "lookback" }
PlayerMoveAnims.SCENE_POSES = SCENE_POSES

-- An upper arm turned about its own length FIRST (`twist`, + turns the elbow's bend in toward the body for the right
-- arm), then taken out to the side (`out`), then swung forward (`x`). (`deg` does it the other way round: out, then
-- a turn about the upright, which on an arm held out swings it round instead of turning it.)
local function limb(x: number, twist: number, out: number): CFrame
	return CFrame.Angles(rad(x), 0, 0) * CFrame.Angles(0, 0, rad(out)) * CFrame.Angles(0, rad(twist), 0)
end

local function scenePoseFrames(name: string): { Frame }
	if name == "crouch" then
		-- the still crouch, on a root that stands where it is (the scene does not lower the hips)
		return crouchFrames(0, 0, 0)
	end
	local frames: { Frame } = {}
	local phases: { number } = {}
	local LENGTH = 5
	local N = 12
	for k = 0, N do
		local t = k / N
		phases[k + 1] = 0
		local breath = math.sin(TAU * t * 2)
		local shift = math.sin(TAU * t)
		local p: Pose = {
			RightUpperLeg = deg(3, 0, 2),
			LeftUpperLeg = deg(3, 0, -2),
			RightLowerLeg = deg(-5, 0, 0),
			LeftLowerLeg = deg(-5, 0, 0),
			RightFoot = deg(2, 0, -2),
			LeftFoot = deg(2, 0, 2),
			RightUpperArm = deg(4, 0, 5),
			LeftUpperArm = deg(4, 0, -5),
			RightLowerArm = deg(10, 0, 0),
			LeftLowerArm = deg(10, 0, 0),
		}
		local chest, head, twist, headTurn = -2.0, 1.0, 0.0, 0.0
		if name == "watch" then
			-- the weight on the right leg, the left knee easy, the right hand on the hip
			p.LowerTorso = deg(0, -6, 3 + 0.6 * shift)
			p.RightUpperLeg = deg(2, 0, 3)
			p.RightLowerLeg = deg(-2, 0, 0)
			p.LeftUpperLeg = deg(9, 0, -6)
			p.LeftLowerLeg = deg(-16, 0, 0)
			p.LeftFoot = deg(7, 0, 6)
			p.RightUpperArm = limb(-6, 100, 38)
			p.RightLowerArm = deg(100, 0, 0)
			twist, headTurn = 8, -6
		elseif name == "arms" then
			-- arms folded over the chest
			p.RightUpperArm = limb(14, 78, -6)
			p.LeftUpperArm = limb(14, -78, 6)
			p.RightLowerArm = deg(96, 0, 0)
			p.LeftLowerArm = deg(96, 0, 0)
			p.LeftUpperLeg = deg(3, 0, -5)
			p.RightUpperLeg = deg(3, 0, 5)
			chest = -1
		elseif name == "kneel" then
			-- down on the left knee, the right foot planted ahead, the right forearm on the right knee
			local thighR, kneeR, flatR = legIK(0.7, 0.98, 0)
			p.RightUpperLeg = deg(thighR, 0, 4)
			p.RightLowerLeg = deg(kneeR, 0, 0)
			p.RightFoot = deg(flatR, 0, -4)
			p.LeftUpperLeg = deg(-14, 0, -3)
			p.LeftLowerLeg = deg(-76, 0, 0)
			p.LeftFoot = deg(52, 0, 3)
			p.RightUpperArm = deg(46, 0, 8)
			p.RightLowerArm = deg(40, 0, 0)
			p.LeftUpperArm = deg(8, 0, -6)
			p.LeftLowerArm = deg(16, 0, 0)
			chest, head = -7, 6
		elseif name == "brow" then
			-- the right hand raised to shade the eyes, looking hard at the castle
			p.RightUpperArm = deg(132, -20, 10)
			p.RightLowerArm = deg(112, 0, 0)
			p.RightHand = deg(-20, 0, 0)
			p.LeftUpperLeg = deg(10, 0, -3)
			p.LeftLowerLeg = deg(-12, 0, 0)
			chest, head = -4, 5
		elseif name == "sit" then
			-- on the ground, knees up, the forearms on the knees
			local thigh, knee, flat = legIK(1.15, 0.28, 0)
			p.RightUpperLeg = deg(thigh, 0, 9)
			p.LeftUpperLeg = deg(thigh, 0, -9)
			p.RightLowerLeg = deg(knee, 0, 0)
			p.LeftLowerLeg = deg(knee, 0, 0)
			p.RightFoot = deg(flat, 0, -9)
			p.LeftFoot = deg(flat, 0, 9)
			p.RightUpperArm = deg(62, 0, 10)
			p.LeftUpperArm = deg(62, 0, -10)
			p.RightLowerArm = deg(48, 0, 0)
			p.LeftLowerArm = deg(48, 0, 0)
			chest, head = -14, 12
		elseif name == "hips" then
			-- both hands on the hips, the feet apart
			p.RightUpperArm = limb(-6, 100, 38)
			p.LeftUpperArm = limb(-6, -100, -38)
			p.RightLowerArm = deg(100, 0, 0)
			p.LeftLowerArm = deg(100, 0, 0)
			p.RightUpperLeg = deg(2, 0, 7)
			p.LeftUpperLeg = deg(2, 0, -7)
			p.RightFoot = deg(2, 0, -7)
			p.LeftFoot = deg(2, 0, 7)
			chest = -1
		elseif name == "lookback" then
			-- turned at the waist, looking back over the shoulder at the others
			p.LowerTorso = deg(0, 8, 0)
			p.LeftUpperLeg = deg(6, 0, -3)
			p.LeftLowerLeg = deg(-10, 0, 0)
			twist, headTurn = 22, 34
		end
		p.UpperTorso = deg(chest - 1.2 * breath, twist, 0)
		p.Head = deg(head + 0.6 * breath, headTurn + 1.5 * shift, 0)
		frames[k + 1] = { time = t * LENGTH, ease = "flat", pose = p }
	end
	-- the feet that bear the weight are on the ground (a kneel and a sit too: their soles are down)
	ground(frames, phases, 1, 0)
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

local function rollFrames(): ({ Frame }, { { any } })
	local tuck: Pose = {
		-- curled tight: the back round, the chin on the chest (a body that is a ball rolls; a plank does not)
		UpperTorso = deg(-62, 0, 0),
		Head = deg(-48, 0, 0),
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
	-- (2026-11-15: the hips' heights are MEASURED, not guessed: at each key the lowest point of the whole body,
	-- head and shoulders included, is exactly on the floor (tools/Filmstrip `whole`); before, the head went 2 studs
	-- into the ground at the top of the turn and the feet half a stud at the landing. The hips go up and over the
	-- shoulders, as they do in a real forward roll.)
	local turn: { { any } } = {
		{ 0.00, 0, 0, 0, false },
		{ 0.06, -32, -0.27, -0.2, reach },
		{ 0.13, -95, 0.84, -0.35, tuck },
		{ 0.21, -165, 0.08, -0.3, tuck },
		{ 0.29, -235, -1.33, -0.2, tuck },
		{ 0.37, -300, -1.44, -0.1, tuck },
		{ 0.45, -335, -0.54, 0, land },
		{ 0.53, -355, 0, 0, up },
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
		frames[#frames + 1] = { time = k[1] * ROLL_LENGTH / 0.6, ease = "flat", pose = pose }
	end
	return frames, turn
end

PlayerMoveAnims.ROLL_LENGTH = ROLL_LENGTH

local ROLL_TURN: { { any } } = select(2, rollFrames())

--[[
	The hips of the roll at `t` seconds of its clip, for a body going `way` (a flat direction in the BODY's own space:
	-Z is ahead of it, +X its right). The clip itself carries only the tucked limbs; the body turns over the way it is
	really going, so a dash to the side is a roll to the side and not a forward tumble sliding sideways.
	Returns the root joint's pose (LowerTorso).
]]
function PlayerMoveAnims.rollHips(t: number, way: Vector3): CFrame
	local n = #ROLL_TURN
	local scaled = math.clamp(t, 0, ROLL_LENGTH) * 0.6 / ROLL_LENGTH
	local i = 1
	while i < n and ROLL_TURN[i + 1][1] <= scaled do
		i += 1
	end
	local a, b = ROLL_TURN[i], ROLL_TURN[math.min(i + 1, n)]
	local span = b[1] - a[1]
	local alpha = if span > 0 then math.clamp((scaled - a[1]) / span, 0, 1) else 0
	local angle = a[2] + (b[2] - a[2]) * alpha
	local drop = a[3] + (b[3] - a[3]) * alpha
	local push = a[4] + (b[4] - a[4]) * alpha
	local flat = Vector3.new(way.X, 0, way.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	-- the axis the body turns round lies across the way it goes (going ahead: its own X; the angle is negative, so
	-- the head goes the way of the roll and under)
	local axis = Vector3.new(-flat.Z, 0, flat.X)
	return CFrame.new(flat * -push + Vector3.new(0, drop, 0)) * CFrame.fromAxisAngle(axis, rad(angle))
end

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
	local walkBack, runBack = backGait(s.walk), backGait(s.run)
	return {
		idle = { frames = idleFrames(s), looped = true },
		walk = { frames = gaitFrames(s.walk), looped = true },
		walkBack = { frames = gaitFrames(walkBack, { back = true }), looped = true },
		walkRight = { frames = sideFrames(s.walk, 1), looped = true },
		walkLeft = { frames = sideFrames(s.walk, -1), looped = true },
		run = { frames = gaitFrames(s.run), looped = true },
		runBack = { frames = gaitFrames(runBack, { back = true }), looped = true },
		runRight = { frames = sideFrames(s.run, 1), looped = true },
		runLeft = { frames = sideFrames(s.run, -1), looped = true },
		duckIdle = { frames = crouchFrames(0, 0), looped = true },
		duck = { frames = crouchFrames(1, 0), looped = true },
		duckBack = { frames = crouchFrames(-1, 0), looped = true },
		duckRight = { frames = crouchFrames(0, 1), looped = true },
		duckLeft = { frames = crouchFrames(0, -1), looped = true },
		pose_watch = { frames = scenePoseFrames("watch"), looped = true },
		pose_arms = { frames = scenePoseFrames("arms"), looped = true },
		pose_kneel = { frames = scenePoseFrames("kneel"), looped = true },
		pose_brow = { frames = scenePoseFrames("brow"), looped = true },
		pose_sit = { frames = scenePoseFrames("sit"), looped = true },
		pose_crouch = { frames = scenePoseFrames("crouch"), looped = true },
		pose_hips = { frames = scenePoseFrames("hips"), looped = true },
		pose_lookback = { frames = scenePoseFrames("lookback"), looped = true },
		jump = { frames = jumpFrames(s), looped = false },
		fall = { frames = fallFrames(s), looped = true },
		roll = { frames = (rollFrames()), looped = false },
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
