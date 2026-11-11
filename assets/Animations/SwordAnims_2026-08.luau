--!strict
--[[
	SwordAnims
	The two sword cuts and the guard, authored here as KeyframeSequences and
	registered at runtime — no upload, no asset ids.

	--------------------------------------------------------------------------
	ONE HAND, TWO CUTS

	    A  down from the upper RIGHT to the lower LEFT
	    B  down from the upper LEFT to the lower RIGHT

	Taken in turn, they draw an X. That is the whole moveset and it is meant to
	be: two cuts that are clearly different beat three that are nearly the same.

	THE LEFT ARM IS NOT KEYED ANYWHERE IN THIS FILE. Not held down, not posed —
	absent. A pose that does not exist in a keyframe is a pose the animator does
	not touch, so the left arm keeps doing whatever the idle or the walk was
	already doing with it. That is both what he asked for and the most alive
	thing it could do: an arm swinging naturally beside a swinging sword.

	The legs are absent for the same reason. Nothing below the waist is ever
	keyed, so walking continues underneath an attack.

	--------------------------------------------------------------------------
	WHY THERE ARE EIGHT KEYFRAMES AND NOT THREE

	The first version had guard → wind → strike → guard, and it looked exactly
	like what it was: a machine moving between four positions.

	ANTICIPATION. Before the arm goes up and right it dips down and left, for
	fifty milliseconds. Nothing in a body starts moving in the direction it is
	going; it loads first. Remove this one frame and the swing reads as a puppet
	being yanked.

	THE HOLD. The wind-up arrives at the top and then does NOTHING for forty
	milliseconds — the same pose, twice, with linear easing between so the
	engine cannot smooth it away. This is the single biggest change in the file
	and the least obvious: a strike that leaves from a dead stop reads as far
	faster than the same strike leaving from a moving arm, because the eye
	measures speed against what came before it. It also gives the swing a
	rhythm — load, aim, GO — instead of one continuous sweep.

	FOLLOW-THROUGH. The strike does not stop at the target. It carries past,
	the elbow folds to absorb it, and only then comes back. A blade that halts
	dead on contact weighs nothing.

	TWO SETTLES, NOT ONE. The arm passes the guard, comes back past it a
	smaller amount the other way, and only then rests. A single overshoot is
	better than none and still reads as mechanical; the second, quarter-sized
	one is what makes it look like a limb losing momentum.

	And underneath all of it, EASING per pose rather than one setting for the
	file: the wind-up decelerates into the top, the strike accelerates into the
	target, the recovery decelerates into the guard. Linear interpolation is
	what made the first attempt feel like a windscreen wiper.

	THE TWO CUTS ARE NOT THE SAME LENGTH. A is 0.72 seconds and B is 0.76, and
	B holds at the top half as long again. Two attacks on an identical rhythm
	read as one attack played twice however different their shapes are; a
	fortieth of a second of difference is enough to break that, and B is the one
	that crosses the body to cock, so it is the one that should feel heavier.

	THE WRIST IS KEYED TOO. `RightHand` turns through every cut, which rolls the
	blade over inside the arc. Without it the sword is a stick welded to a hand;
	with it, the edge leads and the cut looks like a cut.

	--------------------------------------------------------------------------
	THE ANGLE CONVENTION

	Every pose is a rotation of one JOINT away from its rest, in degrees:

	    X  swings the limb forward (+) or back (-)
	    Y  twists it
	    Z  takes it out to the character's +X side (its right) and back

	ONE EXCEPTION, LEARNED THE HARD WAY: on `UpperTorso`, +X leans the chest
	BACK, not forward. An overlay written on the other assumption put the
	character's face at the ceiling. Nothing in this file pitches the torso —
	the cuts only turn it about Y — but the next thing that does should know.

	Location: ReplicatedStorage.Shared.Anim.SwordAnims — pure construction, no
	side effects, safe to require from either side.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local SwordAnims = {}

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

--[[
	How a pose is arrived at, not how it looks.

	"Out" decelerates into the pose, "In" accelerates into it. The strike is the
	only frame that uses In, and it is the reason the cut has a snap.
]]
type Ease = "in" | "out" | "smooth" | "flat"

type Frame = {
	time: number,
	ease: Ease?,
	torso: CFrame?,
	upper: CFrame?, -- right upper arm  — the shoulder
	lower: CFrame?, -- right lower arm  — the elbow
	hand: CFrame?, -- right hand       — the wrist
}

--==========================================================================
--[[
	THE GUARD, and the pose both cuts leave from and return to.

	The sword hand comes up and inward so the blade crosses the body rather than
	sticking out sideways; the elbow stays bent, because a straight arm holding
	a weapon is a mannequin. The torso sits a few degrees off square — nobody
	stands facing dead ahead with a sword out.
]]
local GUARD: Frame = {
	time = 0,
	ease = "smooth",
	torso = deg(0, -8, 0),
	upper = deg(52, -14, -26),
	lower = deg(46, 0, -8),
	hand = deg(0, 0, -12),
}

local function guardAt(time: number, ease: Ease?): Frame
	local copy: Frame = table.clone(GUARD) :: any
	copy.time = time
	copy.ease = ease or GUARD.ease
	return copy
end

--[[
	Standing still, breathing.

	Four poses over five seconds, all within a few degrees of the guard, with
	the torso drifting off it and back. It is barely visible and that is the
	point: a character who holds a perfectly identical pose looks switched off,
	and the fix costs nothing.
]]
local HOLD: { Frame } = {
	guardAt(0),
	{
		time = 1.3,
		ease = "smooth",
		torso = deg(0, -6.5, 0),
		upper = deg(49.5, -14, -24.5),
		lower = deg(48.5, 0, -8),
		hand = deg(0, 0, -13.5),
	},
	{
		time = 2.6,
		ease = "smooth",
		torso = deg(0, -9.5, 0),
		upper = deg(52.5, -15, -27),
		lower = deg(45, 0, -7),
		hand = deg(1.5, 0, -11),
	},
	{
		time = 3.9,
		ease = "smooth",
		torso = deg(0, -7, 0),
		upper = deg(50, -13.5, -25),
		lower = deg(47.5, 0, -8.5),
		hand = deg(0, 0, -13),
	},
	guardAt(5.2),
}

--[[
	A — the cut from the upper right down to the lower left.

	Read the Z column of `upper` down the frames and the whole swing is there:
	-26 at guard, -8 loading, +76 cocked out to the right, -58 through the
	target, -72 past it, and back. The torso runs the opposite way to the arm on
	the wind-up and turns through with it on the strike, which is where the
	weight of a cut actually comes from.
]]
local CUT_RIGHT_TO_LEFT: { Frame } = {
	guardAt(0),
	{ -- load: down and left, AWAY from where it is about to go
		time = 0.05,
		ease = "out",
		torso = deg(0, -14, 0),
		upper = deg(44, -6, -8),
		lower = deg(56, 0, -6),
		hand = deg(0, 0, -20),
	},
	{ -- cocked: high on the right, blade laid back over the shoulder
		time = 0.15,
		ease = "out",
		torso = deg(0, -36, 0),
		upper = deg(14, -38, 80),
		lower = deg(70, 0, -12),
		hand = deg(-26, 0, -34),
	},
	{ -- THE HOLD. Forty milliseconds of absolutely nothing.
		time = 0.19,
		ease = "flat",
		torso = deg(0, -36, 0),
		upper = deg(14, -38, 80),
		lower = deg(70, 0, -12),
		hand = deg(-26, 0, -34),
	},
	{ -- through the target: 100ms from a dead stop. Arm long, edge leading.
		time = 0.29,
		ease = "in",
		torso = deg(0, 30, 0),
		upper = deg(98, 18, -60),
		lower = deg(8, 0, 8),
		hand = deg(22, 0, 26),
	},
	{ -- follow-through: past it, elbow folding to take the weight
		time = 0.37,
		ease = "out",
		torso = deg(0, 38, 0),
		upper = deg(106, 26, -76),
		lower = deg(36, 0, 12),
		hand = deg(28, 0, 34),
	},
	{ -- back, overshooting the guard
		time = 0.51,
		ease = "out",
		torso = deg(0, -16, 0),
		upper = deg(45, -19, -17),
		lower = deg(53, 0, -11),
		hand = deg(-8, 0, -18),
	},
	{ -- and the small one back the other way, before it finally settles
		time = 0.62,
		ease = "out",
		torso = deg(0, -4, 0),
		upper = deg(55, -11, -30),
		lower = deg(43, 0, -6),
		hand = deg(3, 0, -8),
	},
	guardAt(0.72),
}

-- B — the mirror, upper left down to lower right. The arm crosses the body to
-- cock, which is a genuinely different shape from A rather than A reversed.
local CUT_LEFT_TO_RIGHT: { Frame } = {
	guardAt(0),
	{ -- load
		time = 0.06,
		ease = "out",
		torso = deg(0, 10, 0),
		upper = deg(56, 6, -40),
		lower = deg(60, 0, -4),
		hand = deg(0, 0, -6),
	},
	{ -- cocked across the body, over the left shoulder
		time = 0.18,
		ease = "out",
		torso = deg(0, 37, 0),
		upper = deg(40, 37, -90),
		lower = deg(82, 0, 0),
		hand = deg(-22, 0, 14),
	},
	{ -- the hold, a beat longer than A's. This cut is the heavier one.
		time = 0.24,
		ease = "flat",
		torso = deg(0, 37, 0),
		upper = deg(40, 37, -90),
		lower = deg(82, 0, 0),
		hand = deg(-22, 0, 14),
	},
	{ -- through
		time = 0.34,
		ease = "in",
		torso = deg(0, -31, 0),
		upper = deg(94, -19, 58),
		lower = deg(10, 0, -8),
		hand = deg(20, 0, -28),
	},
	{ -- follow-through
		time = 0.42,
		ease = "out",
		torso = deg(0, -38, 0),
		upper = deg(100, -26, 74),
		lower = deg(38, 0, -14),
		hand = deg(26, 0, -36),
	},
	{ -- overshoot
		time = 0.56,
		ease = "out",
		torso = deg(0, -2, 0),
		upper = deg(47, -9, -21),
		lower = deg(51, 0, -8),
		hand = deg(-7, 0, -15),
	},
	{ -- micro-settle
		time = 0.66,
		ease = "out",
		torso = deg(0, -11, 0),
		upper = deg(55, -17, -29),
		lower = deg(44, 0, -9),
		hand = deg(2, 0, -9),
	},
	guardAt(0.76),
}

--==========================================================================
local EASING: { [string]: { style: Enum.PoseEasingStyle, direction: Enum.PoseEasingDirection } } = {
	["in"] = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.In },
	out = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.Out },
	smooth = { style = Enum.PoseEasingStyle.Cubic, direction = Enum.PoseEasingDirection.InOut },
	flat = { style = Enum.PoseEasingStyle.Linear, direction = Enum.PoseEasingDirection.InOut },
}

--[[
	A pose with no CFrame is a PASS-THROUGH, and that is not the same as a pose
	set to rest.

	Weight 1 with an identity CFrame does not mean "leave this joint alone" — it
	means "hold this joint at exactly its rest position", and at Movement
	priority that flattens whatever a lower layer was doing with it. The chain
	from the root down to the shoulder has to exist so the animator can find the
	arm, but none of it is meant to be animated, so all of it carries weight 0.

	This is why the guard's torso had to come out rather than just be left
	blank: blank was never blank.
]]
local function pose(name: string, cf: CFrame?, ease: Ease?, parent: Instance): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf or CFrame.new()
	p.Weight = if cf then 1 else 0
	local easing = EASING[ease or "smooth"]
	p.EasingStyle = easing.style
	p.EasingDirection = easing.direction
	p.Parent = parent
	return p
end

--[[
	One keyframe, as the rig's own hierarchy.

	A Pose has to sit under the pose of the part it hangs from, all the way back
	to the root, or the animator cannot match it to a joint. Only the chain down
	the RIGHT arm is built. Everything else — the left arm, both legs, the head
	— is deliberately missing, which is what leaves them free.
]]
local function keyframe(frame: Frame, sequence: KeyframeSequence)
	local kf = Instance.new("Keyframe")
	kf.Name = "Keyframe"
	kf.Time = frame.time

	local root = pose("HumanoidRootPart", nil, frame.ease, kf)
	local lowerTorso = pose("LowerTorso", nil, frame.ease, root)
	local upperTorso = pose("UpperTorso", frame.torso, frame.ease, lowerTorso)

	local shoulder = pose("RightUpperArm", frame.upper, frame.ease, upperTorso)
	local elbow = pose("RightLowerArm", frame.lower, frame.ease, shoulder)
	pose("RightHand", frame.hand, frame.ease, elbow)

	kf.Parent = sequence
end

local function build(name: string, frames: { Frame }, looped: boolean, priority: Enum.AnimationPriority)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = looped
	sequence.Priority = priority
	for _, frame in frames do
		keyframe(frame, sequence)
	end
	return sequence
end

--==========================================================================
--[[
	Registers all three and hands back playable ids.

	Registration is per machine and per session, so this runs on each client and
	each one gets its own ids for the same animations. That is fine and in fact
	necessary: every client already poses every character it can see from the
	same broadcasts, so they all reach the same picture from their own copies.

	Returns nil, and the reason, if the engine will not register — the caller
	falls back to something rather than to nothing.
]]
export type Ids = { hold: string, swings: { string } }

--[[
	Kept alive for the session on purpose.

	The registered id refers to a sequence the provider was handed; letting the
	instance be collected the moment registration returns is the kind of bug
	that works on the machine it was written on and fails on a slower one. They
	are three small instances and they last as long as the game does.
]]
local registered: { KeyframeSequence } = {}

function SwordAnims.register(): (Ids?, string?)
	local sequences = {
		hold = build("SwordGuard", HOLD, true, Enum.AnimationPriority.Movement),
		a = build("SwordCutRight", CUT_RIGHT_TO_LEFT, false, Enum.AnimationPriority.Action),
		b = build("SwordCutLeft", CUT_LEFT_TO_RIGHT, false, Enum.AnimationPriority.Action),
	}

	local ids: { [string]: string } = {}
	for key, sequence in sequences do
		local ok, result = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end)
		if not ok or typeof(result) ~= "string" or result == "" then
			return nil, tostring(result)
		end
		table.insert(registered, sequence)
		ids[key] = result
	end

	return { hold = ids.hold, swings = { ids.a, ids.b } }, nil
end

--[[
	The same three as loose instances, for publishing them properly.

	If the engine ever refuses to register at runtime, these can be dropped into
	the Explorer, opened in the Animation Editor and uploaded once — after which
	they are ordinary asset ids and none of this matters.
]]
function SwordAnims.buildAll(parent: Instance)
	build("SwordGuard", HOLD, true, Enum.AnimationPriority.Movement).Parent = parent
	build("SwordCutRight", CUT_RIGHT_TO_LEFT, false, Enum.AnimationPriority.Action).Parent = parent
	build("SwordCutLeft", CUT_LEFT_TO_RIGHT, false, Enum.AnimationPriority.Action).Parent = parent
end

return SwordAnims
