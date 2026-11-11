--!strict
--[[
	PlayerActionAnims
	Everything a player's ARMS do that is not walking (docs/systems/Animation.md, docs/systems/Gear.md): holding a sword,
	a spear or a bow, cutting, thrusting, drawing and loosing, putting the armour on and taking it off, carrying the
	lantern. Authored here in code, played on every client by Client/Controllers/BodyAnimController on top of the
	movement loops (Shared/Anim/PlayerMoveAnims), so the legs go on walking under a cut.

	TWO WAYS OF WRITING A MOVE, and why there are two:

	  CLIPS (the sword, the armour, the lantern). Frames of joint angles, as the developer's sword cuts were written
	  (anticipation, a hold, follow-through, two settles, an ease per pose: docs/systems/Animation.md section 1). Good
	  for one arm doing something by itself. A bone written "+UpperTorso" is added to the walk's own chest, not put in
	  its place (Shared/Anim/ClipPlayer).

	  TRACKS (the spear, the bow). A weapon held in TWO hands cannot be written as two arms' angles: the second hand
	  would be near the shaft, never on it. So a track says where the WEAPON is, in the body's own space (the root's:
	  -Z is ahead, +X the right, +Y up, studs from the body's middle): where the holding hand is, where the weapon
	  points, how far along it the other hand closes, how far the string is drawn. Shared/Anim/WeaponPose then works
	  out both arms so the hands are exactly there. A track's numbers are eased from key to key like a clip's poses.

	THE HOUSE RULES hold for every move here: load before you go, hold at the top, carry past the target, settle twice,
	and no two attacks of one weapon the same length.

	ANGLES (a joint's rotation away from the standard R15 rest, degrees): X swings a hanging limb forward (+); on the
	chest +X leans it BACK; on a forearm +X bends the elbow; Y twists; Z takes a hanging limb to the character's right.

	Location: ReplicatedStorage.Shared.Anim.PlayerActionAnims (pure data and sampling: nothing is touched)
]]

local ClipPlayer = require(script.Parent.ClipPlayer)

local PlayerActionAnims = {}

local rad = math.rad

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

type Ease = ClipPlayer.Ease
type Frame = ClipPlayer.Frame
local V = Vector3.new

--==========================================================================
-- THE SWORD (one hand): the guard, and the two cuts that draw an X. The developer's own, kept number for number.
--==========================================================================
local function sword(time: number, ease: Ease?, torso: number, upper: CFrame, lower: CFrame, hand: CFrame): Frame
	return {
		time = time,
		ease = ease or "smooth",
		pose = { ["+UpperTorso"] = deg(0, torso, 0), RightUpperArm = upper, RightLowerArm = lower, RightHand = hand },
	}
end

local function guard(time: number, ease: Ease?): Frame
	return sword(time, ease, -8, deg(52, -14, -26), deg(46, 0, -8), deg(0, 0, -12))
end

local SWORD_HOLD: { Frame } = {
	guard(0),
	sword(1.3, "smooth", -6.5, deg(49.5, -14, -24.5), deg(48.5, 0, -8), deg(0, 0, -13.5)),
	sword(2.6, "smooth", -9.5, deg(52.5, -15, -27), deg(45, 0, -7), deg(1.5, 0, -11)),
	sword(3.9, "smooth", -7, deg(50, -13.5, -25), deg(47.5, 0, -8.5), deg(0, 0, -13)),
	guard(5.2),
}

-- A: down from the upper right to the lower left.
local SWORD_CUT_A: { Frame } = {
	guard(0),
	sword(0.05, "out", -14, deg(44, -6, -8), deg(56, 0, -6), deg(0, 0, -20)), -- load: down and left, away from where it goes
	sword(0.15, "out", -36, deg(14, -38, 80), deg(70, 0, -12), deg(-26, 0, -34)), -- cocked: high on the right
	sword(0.19, "flat", -36, deg(14, -38, 80), deg(70, 0, -12), deg(-26, 0, -34)), -- THE HOLD
	sword(0.29, "in", 30, deg(98, 18, -60), deg(8, 0, 8), deg(22, 0, 26)), -- through the target, from a dead stop
	sword(0.37, "out", 38, deg(106, 26, -76), deg(36, 0, 12), deg(28, 0, 34)), -- past it, the elbow folding
	sword(0.51, "out", -16, deg(45, -19, -17), deg(53, 0, -11), deg(-8, 0, -18)), -- back, past the guard
	sword(0.62, "out", -4, deg(55, -11, -30), deg(43, 0, -6), deg(3, 0, -8)), -- and the small one the other way
	guard(0.72),
}

-- B: down from the upper left to the lower right. The arm crosses the body to cock: a different shape, and heavier.
local SWORD_CUT_B: { Frame } = {
	guard(0),
	sword(0.06, "out", 10, deg(56, 6, -40), deg(60, 0, -4), deg(0, 0, -6)),
	sword(0.18, "out", 37, deg(40, 37, -90), deg(82, 0, 0), deg(-22, 0, 14)),
	sword(0.24, "flat", 37, deg(40, 37, -90), deg(82, 0, 0), deg(-22, 0, 14)),
	sword(0.34, "in", -31, deg(94, -19, 58), deg(10, 0, -8), deg(20, 0, -28)),
	sword(0.42, "out", -38, deg(100, -26, 74), deg(38, 0, -14), deg(26, 0, -36)),
	sword(0.56, "out", -2, deg(47, -9, -21), deg(51, 0, -8), deg(-7, 0, -15)),
	sword(0.66, "out", -11, deg(55, -17, -29), deg(44, 0, -9), deg(2, 0, -9)),
	guard(0.76),
}

--==========================================================================
-- THE ARMOUR (F): on over the head and buckled, off and slung back. Both arms; the chest and head only lean with it.
--==========================================================================
local function both(time: number, ease: Ease?, rUp: CFrame, rLow: CFrame, lUp: CFrame, lLow: CFrame, chest: CFrame?, head: CFrame?): Frame
	return {
		time = time,
		ease = ease or "smooth",
		pose = {
			RightUpperArm = rUp,
			RightLowerArm = rLow,
			LeftUpperArm = lUp,
			LeftLowerArm = lLow,
			RightHand = CFrame.new(),
			LeftHand = CFrame.new(),
			["+UpperTorso"] = chest or CFrame.new(),
			["+Head"] = head or CFrame.new(),
		},
	}
end

local ARMOUR_DON: { Frame } = {
	both(0, "smooth", deg(20, 0, 10), deg(30, 0, 0), deg(20, 0, -10), deg(30, 0, 0)),
	-- both hands over the shoulders to the bundle on the back, the head bowed
	both(0.28, "out", deg(165, 0, 25), deg(120, 0, 0), deg(165, 0, -25), deg(120, 0, 0), deg(-10, 0, 0), deg(-18, 0, 0)),
	both(0.34, "flat", deg(165, 0, 25), deg(120, 0, 0), deg(165, 0, -25), deg(120, 0, 0), deg(-10, 0, 0), deg(-18, 0, 0)),
	-- over the head and down the front
	both(0.52, "in", deg(95, 0, 12), deg(100, 0, 0), deg(95, 0, -12), deg(100, 0, 0), deg(6, 0, 0), deg(8, 0, 0)),
	-- tugged down at the sides
	both(0.7, "out", deg(35, 0, 18), deg(85, 0, 0), deg(35, 0, -18), deg(85, 0, 0), deg(-4, 0, 0)),
	-- the right hand settles the left shoulder plate, then the left the right
	both(0.86, "smooth", deg(70, 0, -55), deg(110, 0, 0), deg(20, 0, -22), deg(40, 0, 0), deg(0, 10, 0), deg(0, 14, 0)),
	both(1.02, "smooth", deg(20, 0, 22), deg(40, 0, 0), deg(70, 0, 55), deg(110, 0, 0), deg(0, -10, 0), deg(0, -14, 0)),
	-- both fists knock the chest: it sits
	both(1.2, "in", deg(48, 0, -30), deg(105, 0, 0), deg(48, 0, 30), deg(105, 0, 0), deg(-3, 0, 0)),
	both(1.3, "flat", deg(48, 0, -30), deg(105, 0, 0), deg(48, 0, 30), deg(105, 0, 0), deg(-3, 0, 0)),
	both(1.5, "out", deg(8, 0, 6), deg(14, 0, 0), deg(8, 0, -6), deg(14, 0, 0)),
}

local ARMOUR_DOFF: { Frame } = {
	both(0, "smooth", deg(20, 0, 10), deg(30, 0, 0), deg(20, 0, -10), deg(30, 0, 0)),
	-- thumbs under the sides
	both(0.18, "out", deg(35, 0, 18), deg(92, 0, 0), deg(35, 0, -18), deg(92, 0, 0), deg(-6, 0, 0)),
	-- up and over the head
	both(0.42, "in", deg(120, 0, 14), deg(96, 0, 0), deg(120, 0, -14), deg(96, 0, 0), deg(4, 0, 0), deg(-12, 0, 0)),
	-- swung back onto the shoulders
	both(0.66, "out", deg(160, 0, 26), deg(118, 0, 0), deg(160, 0, -26), deg(118, 0, 0), deg(-8, 0, 0), deg(-14, 0, 0)),
	both(0.74, "flat", deg(160, 0, 26), deg(118, 0, 0), deg(160, 0, -26), deg(118, 0, 0), deg(-8, 0, 0), deg(-14, 0, 0)),
	both(1.0, "out", deg(8, 0, 6), deg(14, 0, 0), deg(8, 0, -6), deg(14, 0, 0)),
}

--==========================================================================
-- THE LANTERN in the left hand: held up and forward to light the way (the hand itself is kept level by the
-- controller, so the lantern hangs straight down from it whatever the arm does).
--==========================================================================
local function lantern(time: number, lift: number, out: number, bend: number): Frame
	return {
		time = time,
		ease = "smooth",
		pose = { LeftUpperArm = deg(lift, 6, -out), LeftLowerArm = deg(bend, 0, 0) },
	}
end

local LANTERN_HOLD: { Frame } = {
	lantern(0, 96, 16, 40),
	lantern(1.4, 93, 18, 44),
	lantern(2.8, 98, 15, 38),
	lantern(4.2, 96, 16, 40),
}

--==========================================================================
-- Clips by name
--==========================================================================
local FRAMES: { [string]: { frames: { Frame }, looped: boolean } } = {
	sword_hold = { frames = SWORD_HOLD, looped = true },
	sword_cut_a = { frames = SWORD_CUT_A, looped = false },
	sword_cut_b = { frames = SWORD_CUT_B, looped = false },
	armour_don = { frames = ARMOUR_DON, looped = false },
	armour_doff = { frames = ARMOUR_DOFF, looped = false },
	lantern_hold = { frames = LANTERN_HOLD, looped = true },
}

local built: { [string]: ClipPlayer.Clip } = {}

-- A clip by name ("sword_hold", "sword_cut_a", "sword_cut_b", "armour_don", "armour_doff", "lantern_hold").
function PlayerActionAnims.clip(name: string): ClipPlayer.Clip?
	local have = built[name]
	if have then
		return have
	end
	local def = FRAMES[name]
	if not def then
		return nil
	end
	local made = ClipPlayer.clip(name, def.frames, def.looped)
	built[name] = made
	return made
end

--==========================================================================
-- TRACKS (the spear and the bow): where the weapon is, key by key
--==========================================================================
--[[
	A key holds a time, the ease it is arrived at with, and any of:
	  hand     where the holding hand's grip is                      (Vector3, the body's space)
	  aim      where the weapon points: the spear's shaft, the bow's arrow   (Vector3; made a unit vector when used)
	  up       (bow) where the top of the stave leans                (Vector3)
	  support  (spear) studs along the shaft from the holding hand to the other one
	  draw     (bow) 0..1, how far the string is drawn
	  string   (bow) 0..1, how much the drawing hand is on the string (0 = that arm is free, or going to `reach`)
	  reach    (bow) where the drawing hand goes when it is not on the string (the quiver)  (Vector3)
	  reachOn  (bow) 0..1, how much it goes there
	  yaw      the chest turned (degrees; + to the left), on top of the walk
	  lean     the chest forward (degrees)
	  lunge    the hips pushed forward (studs)
	  look     0..1, how much of the up-and-down look the weapon follows
	A value a key leaves out keeps the last one before it (the first key says everything).
]]
export type Key = { [string]: any }
export type Track = { name: string, length: number, looped: boolean, keys: { Key }, fields: { string } }

local function track(name: string, looped: boolean, keys: { Key }): Track
	table.sort(keys, function(a, b)
		return a.t < b.t
	end)
	local seen: { [string]: boolean } = {}
	local fields: { string } = {}
	for _, key in keys do
		for field in key do
			if field ~= "t" and field ~= "ease" and not seen[field] then
				seen[field] = true
				table.insert(fields, field)
			end
		end
	end
	-- carry every value forward so each key is whole
	local last: { [string]: any } = {}
	for _, key in keys do
		for _, field in fields do
			if key[field] == nil then
				key[field] = last[field]
			else
				last[field] = key[field]
			end
		end
	end
	return { name = name, length = if #keys > 0 then keys[#keys].t else 0, looped = looped, keys = keys, fields = fields }
end

--[[
	The values of `tr` at `t` seconds into `out` (numbers and Vector3s, eased between the two keys round `t`; a looped
	track wraps, a one-shot holds its last key).
]]
function PlayerActionAnims.sample(tr: Track, t: number, out: { [string]: any })
	local keys = tr.keys
	local n = #keys
	if n == 0 then
		return
	end
	if tr.looped and tr.length > 0 then
		t = t % tr.length
	else
		t = math.clamp(t, 0, tr.length)
	end
	local i = 1
	while i < n and keys[i + 1].t <= t do
		i += 1
	end
	local a, b = keys[i], keys[math.min(i + 1, n)]
	local span = b.t - a.t
	local alpha = if span > 0 then ClipPlayer.ease(b.ease or "smooth", math.clamp((t - a.t) / span, 0, 1)) else 0
	for _, field in tr.fields do
		local x, y = a[field], b[field]
		if x == nil or y == nil or alpha <= 0 then
			out[field] = if x ~= nil then x else y
		elseif alpha >= 1 then
			out[field] = y
		elseif typeof(x) == "Vector3" then
			out[field] = (x :: Vector3):Lerp(y, alpha)
		else
			out[field] = x + (y - x) * alpha
		end
	end
end

--==========================================================================
-- THE SPEAR (two hands). Held at the chest, the body turned a quarter away (the left shoulder leads), the point
-- ahead and a little up. The right hand drives; the shaft slides through the left.
--==========================================================================
local SPEAR_AT = V(0.75, 0.3, -0.55)
local SPEAR_AIM = V(-0.17, 0.07, -0.98)

local SPEAR_HOLD = track("spear_hold", true, {
	{ t = 0, hand = SPEAR_AT, aim = SPEAR_AIM, support = 1.18, yaw = -42, lean = 5, lunge = 0, look = 0.75 },
	{ t = 1.5, ease = "smooth", hand = SPEAR_AT + V(0.01, -0.03, 0.02), aim = SPEAR_AIM + V(0.01, -0.012, 0), yaw = -41 },
	{ t = 3.0, ease = "smooth", hand = SPEAR_AT + V(-0.01, 0.01, -0.01), aim = SPEAR_AIM + V(-0.008, 0.008, 0), yaw = -43 },
	{ t = 4.4, ease = "smooth", hand = SPEAR_AT, aim = SPEAR_AIM, yaw = -42 },
})

-- A: the straight thrust. Load, draw back, HOLD, drive, carry on, come back past the guard and settle.
local SPEAR_THRUST_A = track("spear_thrust_a", false, {
	{ t = 0, hand = SPEAR_AT, aim = SPEAR_AIM, support = 1.18, yaw = -42, lean = 5, lunge = 0, look = 0.75 },
	{ t = 0.05, ease = "out", hand = V(0.72, 0.28, -0.66), support = 1.1, yaw = -38 }, -- load: a touch forward first
	{ t = 0.2, ease = "out", hand = V(0.98, 0.4, 0.02), aim = V(-0.2, 0.05, -0.98), support = 1.72, yaw = -62, lean = 2, lunge = -0.12 }, -- drawn back
	{ t = 0.27, ease = "flat", hand = V(0.98, 0.4, 0.02), aim = V(-0.2, 0.05, -0.98), support = 1.72, yaw = -62, lean = 2, lunge = -0.12 }, -- THE HOLD
	{ t = 0.36, ease = "in", hand = V(0.36, 0.42, -1.0), aim = V(-0.09, 0.0, -1), support = 0.55, yaw = -14, lean = 14, lunge = 0.36 }, -- driven home
	{ t = 0.44, ease = "out", hand = V(0.34, 0.41, -1.06), aim = V(-0.08, -0.02, -1), support = 0.5, yaw = -10, lean = 16, lunge = 0.42 }, -- and a little further
	{ t = 0.58, ease = "out", hand = V(0.8, 0.27, -0.44), aim = SPEAR_AIM, support = 1.26, yaw = -47, lean = 3, lunge = -0.04 }, -- back, past the guard
	{ t = 0.68, ease = "out", hand = V(0.73, 0.31, -0.58), support = 1.16, yaw = -40, lean = 6, lunge = 0.01 }, -- the small one the other way
	{ t = 0.78, ease = "out", hand = SPEAR_AT, aim = SPEAR_AIM, support = 1.18, yaw = -42, lean = 5, lunge = 0 },
})

-- B: the high thrust, over the guard: the point drops in from above. Longer, with a longer hold.
local SPEAR_THRUST_B = track("spear_thrust_b", false, {
	{ t = 0, hand = SPEAR_AT, aim = SPEAR_AIM, support = 1.18, yaw = -42, lean = 5, lunge = 0, look = 0.75 },
	{ t = 0.06, ease = "out", hand = V(0.74, 0.22, -0.6), support = 1.14, yaw = -44 }, -- load: it dips
	{ t = 0.24, ease = "out", hand = V(0.92, 0.95, 0.1), aim = V(-0.18, -0.12, -0.98), support = 1.6, yaw = -58, lean = -2, lunge = -0.1 }, -- raised by the ear
	{ t = 0.33, ease = "flat", hand = V(0.92, 0.95, 0.1), aim = V(-0.18, -0.12, -0.98), support = 1.6, yaw = -58, lean = -2, lunge = -0.1 }, -- THE HOLD
	{ t = 0.43, ease = "in", hand = V(0.4, 0.78, -0.98), aim = V(-0.1, -0.2, -0.97), support = 0.6, yaw = -16, lean = 16, lunge = 0.34 }, -- down and in
	{ t = 0.51, ease = "out", hand = V(0.38, 0.72, -1.04), aim = V(-0.09, -0.23, -0.97), support = 0.55, yaw = -12, lean = 18, lunge = 0.4 },
	{ t = 0.66, ease = "out", hand = V(0.79, 0.26, -0.46), aim = SPEAR_AIM, support = 1.24, yaw = -46, lean = 3, lunge = -0.03 },
	{ t = 0.76, ease = "out", hand = V(0.74, 0.31, -0.57), support = 1.17, yaw = -41, lean = 6 },
	{ t = 0.86, ease = "out", hand = SPEAR_AT, aim = SPEAR_AIM, support = 1.18, yaw = -42, lean = 5, lunge = 0 },
})

--==========================================================================
-- THE BOW. The left hand holds it; the right draws. `draw` and `string` are what the string and the nocked arrow follow.
--==========================================================================
local BOW_LOW = V(-0.62, 0.05, -1.05) -- carried: low, in front of the left hip
local BOW_UP = V(0, 1.0, -2.05) -- raised: the fist low in the middle of the picture (it must not hide what is aimed at), the arm long; the string comes back under the chin
local QUIVER = V(0.5, 1.55, 0.55) -- over the right shoulder

local BOW_HOLD = track("bow_hold", true, {
	{ t = 0, hand = BOW_LOW, aim = V(0.32, -0.2, -0.92), up = V(0.42, 0.9, -0.1), draw = 0, string = 0, reach = QUIVER, reachOn = 0, yaw = -10, lean = 3, lunge = 0, look = 0.35 },
	{ t = 1.6, ease = "smooth", hand = BOW_LOW + V(0.01, -0.03, 0.01), aim = V(0.33, -0.22, -0.92), yaw = -9 },
	{ t = 3.2, ease = "smooth", hand = BOW_LOW + V(-0.01, 0.01, -0.01), aim = V(0.31, -0.19, -0.92), yaw = -11 },
	{ t = 4.6, ease = "smooth", hand = BOW_LOW, aim = V(0.32, -0.2, -0.92), yaw = -10 },
})

--[[
	The draw: the bow comes up while the right hand finds the string, then the string comes back to the corner of the
	mouth. Its LAST key is the full draw, which is held (with the breath in it) for as long as the button is.
	The controller plays it at the weapon's own DrawSeconds (the track is written for 0.8).
]]
local BOW_DRAW = track("bow_draw", false, {
	{ t = 0, hand = BOW_LOW, aim = V(0.32, -0.2, -0.92), up = V(0.42, 0.9, -0.1), draw = 0, string = 0, reach = QUIVER, reachOn = 0, yaw = -10, lean = 3, lunge = 0, look = 0.35 },
	{ t = 0.2, ease = "out", hand = V(-0.1, 0.8, -1.8), aim = V(0.06, -0.06, -1), up = V(0.22, 0.97, 0), draw = 0, string = 1, yaw = -34, lean = 1, look = 1 }, -- up, the hand on the string
	{ t = 0.3, ease = "smooth", hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 0.08, string = 1, yaw = -44, lean = 0, look = 1 },
	{ t = 0.72, ease = "out", hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 0.97, string = 1, yaw = -52, lean = -2, look = 1 }, -- back to the mouth
	{ t = 0.8, ease = "out", hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 1, string = 1, yaw = -53, lean = -2, look = 1 },
})

-- Held at full draw: the smallest sway, the breath.
local BOW_AIM = track("bow_aim", true, {
	{ t = 0, hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 1, string = 1, reach = QUIVER, reachOn = 0, yaw = -53, lean = -2, lunge = 0, look = 1 },
	{ t = 1.1, ease = "smooth", hand = BOW_UP + V(0.006, 0.01, 0), aim = V(0.003, 0.004, -1), draw = 0.985 },
	{ t = 2.2, ease = "smooth", hand = BOW_UP + V(-0.006, -0.006, 0), aim = V(-0.003, -0.003, -1), draw = 1 },
	{ t = 3.2, ease = "smooth", hand = BOW_UP, aim = V(0, 0, -1), draw = 1 },
})

--[[
	The loose: the string is gone in a twentieth of a second, the drawing hand flies back off the mouth, the bow hand
	tips the bow forward; then the hand goes over the shoulder to the quiver and comes back as the bow sinks.
]]
local BOW_LOOSE = track("bow_loose", false, {
	{ t = 0, hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 1, string = 1, reach = V(0.4, 1.05, 0.55), reachOn = 0, yaw = -53, lean = -2, lunge = 0, look = 1 },
	{ t = 0.05, ease = "in", draw = 0, string = 0, reachOn = 1, hand = BOW_UP + V(0, 0.02, -0.05), up = V(0.1, 0.96, -0.2), yaw = -56 }, -- gone; the bow rolls forward
	{ t = 0.16, ease = "out", reach = V(0.5, 1.08, 0.7), hand = BOW_UP + V(0, 0, -0.03), up = V(0.12, 0.98, -0.1), yaw = -55 }, -- the hand carries back
	{ t = 0.34, ease = "smooth", reach = QUIVER, hand = V(-0.1, 0.75, -1.75), aim = V(0.08, -0.08, -1), up = V(0.22, 0.97, 0), yaw = -36, look = 0.8 }, -- to the quiver
	{ t = 0.4, ease = "flat", reach = QUIVER },
	{ t = 0.62, ease = "smooth", reachOn = 0, hand = BOW_LOW, aim = V(0.32, -0.2, -0.92), up = V(0.42, 0.9, -0.1), yaw = -10, lean = 3, look = 0.35 },
})

-- Let down without loosing (the button was let go too soon, or there is no arrow).
local BOW_LOWER = track("bow_lower", false, {
	{ t = 0, hand = BOW_UP, aim = V(0, 0, -1), up = V(0.2, 0.98, 0), draw = 0.5, string = 1, reach = QUIVER, reachOn = 0, yaw = -50, lean = -1, lunge = 0, look = 1 },
	{ t = 0.14, ease = "out", draw = 0, string = 1, hand = V(-0.1, 0.8, -1.8), up = V(0.22, 0.97, 0), yaw = -34 },
	{ t = 0.36, ease = "smooth", string = 0, hand = BOW_LOW, aim = V(0.32, -0.2, -0.92), up = V(0.42, 0.9, -0.1), yaw = -10, lean = 3, look = 0.35 },
})

local TRACKS: { [string]: Track } = {
	spear_hold = SPEAR_HOLD,
	spear_thrust_a = SPEAR_THRUST_A,
	spear_thrust_b = SPEAR_THRUST_B,
	bow_hold = BOW_HOLD,
	bow_draw = BOW_DRAW,
	bow_aim = BOW_AIM,
	bow_loose = BOW_LOOSE,
	bow_lower = BOW_LOWER,
}

function PlayerActionAnims.track(name: string): Track?
	return TRACKS[name]
end

--==========================================================================
-- What each KIND of weapon uses (configs/Gear.Weapons[id].Kind)
--==========================================================================
--[[
	clips    the weapon is moved by joint clips: `hold` (looped) and `attacks` (taken in turn)
	tracks   the weapon is moved by tracks: `hold` and `attacks`; a bow has `draw`, `aim`, `loose`, `lower` instead
	pace     an attack is written for a weapon whose Cooldown is this; a slower weapon (an axe on the sword's cuts) plays
	         its attacks slower by the same share, so the swing always ends as the weapon is ready again
]]
PlayerActionAnims.KINDS = {
	sword = { clips = true, hold = "sword_hold", attacks = { "sword_cut_a", "sword_cut_b" }, pace = 0.6 },
	axe = { clips = true, hold = "sword_hold", attacks = { "sword_cut_a", "sword_cut_b" }, pace = 0.6 },
	mace = { clips = true, hold = "sword_hold", attacks = { "sword_cut_b", "sword_cut_a" }, pace = 0.6 },
	spear = { tracks = true, hold = "spear_hold", attacks = { "spear_thrust_a", "spear_thrust_b" }, pace = 0.8 },
	bow = { tracks = true, hold = "bow_hold", draw = "bow_draw", aim = "bow_aim", loose = "bow_loose", lower = "bow_lower", pace = 0.8 },
}

-- Every clip and track name, for a test.
function PlayerActionAnims.names(): ({ string }, { string })
	local clips: { string } = {}
	for name in FRAMES do
		table.insert(clips, name)
	end
	local tracks: { string } = {}
	for name in TRACKS do
		table.insert(tracks, name)
	end
	table.sort(clips)
	table.sort(tracks)
	return clips, tracks
end

return PlayerActionAnims
