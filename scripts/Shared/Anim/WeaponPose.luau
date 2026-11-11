--!strict
--[[
	WeaponPose
	Puts both hands ON a weapon. Given a body's rig, the pose so far (the walk, the chest's turn) and where a track says
	the weapon is (Shared/Anim/PlayerActionAnims: the holding hand, where it points, how far along the other hand
	closes, how far the string is drawn), it works out the shoulders, elbows and wrists so that:

	  SPEAR  the holding hand has the shaft at `hand`, pointing along `aim`; the other hand closes on the shaft `support`
	         studs further on. Each fist is turned round the shaft to wherever its own forearm comes from, so no wrist is
	         broken.
	  BOW    the bow hand has the grip at `hand`, the arrow's line along `aim`, the stave's top toward `up`; the drawing
	         hand is on the string, `draw` of the way back (or going to the quiver).

	Everything is worked out in the body's own space from the pose itself (Shared/Anim/ClipPlayer `chest`, `link`,
	`reach`), not from where the parts were last frame, so the hands do not lag a running body by a frame.

	THE LOOK. A weapon follows the eyes up and down: its place and its aim are turned about a point at the base of the
	neck by the look's angle times the track's `look` (a carried bow follows a little, a drawn one wholly: the arrow
	goes where the eyes are).

	Pure arithmetic on tables: nothing in the world is read or written.

	Location: ReplicatedStorage.Shared.Anim.WeaponPose
]]

local ClipPlayer = require(script.Parent.ClipPlayer)

local WeaponPose = {}

export type Hold = {
	kind: string, -- "spear" | "bow"
	side: string, -- the hand that holds it: "Right" | "Left"
	hiltInHand: CFrame, -- the hilt's frame in that hand's own space (its +Y runs along the weapon)
	otherGrip: CFrame, -- the OTHER hand's grip point, in that hand's space
	stringBack: number, -- (bow) studs from the grip back to the string at rest
	stringDraw: number, -- (bow) studs the string comes back at a full draw
}

local IDENTITY = CFrame.new()
local NECK = Vector3.new(0, 1.15, 0) -- the point a held weapon turns about as the eyes go up and down (root space)

-- which way each elbow points (root space)
local ELBOW = {
	Right = Vector3.new(0.55, -0.75, 0.4),
	Left = Vector3.new(-0.55, -0.75, 0.35),
}
local ELBOW_BOW_ARM = Vector3.new(-0.35, -0.9, 0.15)
local ELBOW_DRAWING = Vector3.new(0.7, 0.25, 0.7) -- high and back, as an archer's is

local function unit(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-4 then v.Unit else fallback
end

local function across(v: Vector3, along: Vector3, fallback: Vector3): Vector3
	return unit(v - along * v:Dot(along), fallback)
end

-- What every track may do to the body under the arms: turn and lean the chest, push the hips forward.
local function body(pose: { [string]: CFrame }, v: { [string]: any }, weight: number)
	local yaw, lean, lunge = v.yaw or 0, v.lean or 0, v.lunge or 0
	if yaw ~= 0 or lean ~= 0 then
		local turn = CFrame.Angles(math.rad(-lean), math.rad(yaw), 0)
		pose.UpperTorso = (pose.UpperTorso or IDENTITY) * (if weight >= 1 then turn else IDENTITY:Lerp(turn, weight))
		-- the head keeps looking where the eyes look, not where the chest was turned
		local back = CFrame.Angles(math.rad(lean * 0.6), math.rad(-yaw * 0.85), 0)
		pose.Head = (pose.Head or IDENTITY) * (if weight >= 1 then back else IDENTITY:Lerp(back, weight))
	end
	if lunge ~= 0 then
		local push = lunge * weight
		pose.LowerTorso = CFrame.new(0, -math.abs(push) * 0.12, -push) * (pose.LowerTorso or IDENTITY)
		-- the feet stay where they are: both legs swing the other way, the feet stay flat
		local swing = math.rad(-push * 19)
		for _, side in { "Right", "Left" } do
			pose[side .. "UpperLeg"] = (pose[side .. "UpperLeg"] or IDENTITY) * CFrame.Angles(swing, 0, 0)
			pose[side .. "Foot"] = (pose[side .. "Foot"] or IDENTITY) * CFrame.Angles(-swing * 0.9, 0, 0)
		end
	end
end

--[[
	Sets one arm so that the frame `inHand` (given in that hand's own space: a hilt, or the hand's grip point) sits at
	`at` turned as `rot` (root space). With `free`, the hand may be turned ROUND the frame's +Y (a shaft) to wherever its
	forearm comes from, so the wrist stays straight.
]]
local function grasp(rig: ClipPlayer.Rig, pose: { [string]: CFrame }, side: string, inHand: CFrame, at: Vector3, rot: CFrame, pole: Vector3, weight: number, free: boolean)
	if weight <= 0 then
		return
	end
	local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
	local w0, w1 = rig.a0[hand], rig.a1[hand]
	if not (w0 and w1) then
		return
	end
	local before = pose[hand] or IDENTITY
	local chest = ClipPlayer.chest(rig, pose)
	local poleIn = chest:VectorToObjectSpace(pole)
	local handRot = rot * inHand.Rotation:Inverse()
	for pass = 1, if free then 2 else 1 do
		local handAt = at - handRot:VectorToWorldSpace(inHand.Position)
		local wristAt = handAt + handRot:VectorToWorldSpace(w1.Position)
		ClipPlayer.reach(rig, pose, side, chest:PointToObjectSpace(wristAt), poleIn, 1, true)
		if free and pass == 1 then
			-- turn the fist round the shaft until the hand's own "up the arm" axis points back along the forearm
			local forearm = (chest * ClipPlayer.link(rig, pose, upper) * ClipPlayer.link(rig, pose, lower)).Rotation
			local shaft = rot.YVector
			local toElbow = across(forearm.YVector, shaft, rot.ZVector)
			local nowUp = across(handRot.YVector, shaft, rot.ZVector)
			local angle = math.atan2(nowUp:Cross(toElbow):Dot(shaft), nowUp:Dot(toElbow))
			handRot = CFrame.fromAxisAngle(shaft, angle) * handRot
		end
	end
	local forearm = (chest * ClipPlayer.link(rig, pose, upper) * ClipPlayer.link(rig, pose, lower)).Rotation
	local wrist = w0.Rotation:Inverse() * (forearm:Inverse() * handRot) * w1.Rotation
	pose[hand] = wrist
	if weight < 1 then
		-- (the shoulder and elbow were set outright above: blend all three back toward what the pose had)
		pose[hand] = before:Lerp(wrist, weight)
	end
end

-- The same, but blended by `weight` from the arm the pose already has.
local function grasped(rig: ClipPlayer.Rig, pose: { [string]: CFrame }, side: string, inHand: CFrame, at: Vector3, rot: CFrame, pole: Vector3, weight: number, free: boolean)
	if weight <= 0 then
		return
	end
	if weight >= 1 then
		grasp(rig, pose, side, inHand, at, rot, pole, 1, free)
		return
	end
	local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
	local u, l, h = pose[upper] or IDENTITY, pose[lower] or IDENTITY, pose[hand] or IDENTITY
	grasp(rig, pose, side, inHand, at, rot, pole, 1, free)
	pose[upper] = u:Lerp(pose[upper] or IDENTITY, weight)
	pose[lower] = l:Lerp(pose[lower] or IDENTITY, weight)
	pose[hand] = h:Lerp(pose[hand] or IDENTITY, weight)
end

local function lookTurn(v: { [string]: any }, pitch: number): CFrame
	return CFrame.Angles(pitch * (v.look or 0), 0, 0)
end

--[[
	THE SPEAR. `v` is a sampled spear track, `pitch` the look (radians, + up), `weight` how much the hold is on (0..1: a
	weapon being taken in hand blends in). Returns the hilt's frame in the root's space (for anything that wants to know
	where the point is).
]]
function WeaponPose.spear(rig: ClipPlayer.Rig, pose: { [string]: CFrame }, v: { [string]: any }, hold: Hold, pitch: number, weight: number): CFrame
	body(pose, v, weight)
	local turn = lookTurn(v, pitch)
	local at = NECK + turn:VectorToWorldSpace((v.hand :: Vector3) - NECK)
	local aim = turn:VectorToWorldSpace(unit(v.aim, Vector3.new(0, 0, -1)))
	-- the hilt's frame: +Y along the shaft; the rest is free (a shaft is round), so start with "up" and let each fist turn
	local z = across(Vector3.yAxis, aim, Vector3.zAxis)
	local rot = CFrame.fromMatrix(Vector3.zero, aim:Cross(z), aim, z)
	local other = if hold.side == "Right" then "Left" else "Right"
	grasped(rig, pose, hold.side, hold.hiltInHand, at, rot, ELBOW[hold.side], weight, true)
	grasped(rig, pose, other, hold.otherGrip, at + aim * (v.support or 1.2), rot, ELBOW[other], weight, true)
	return CFrame.new(at) * rot
end

--[[
	THE BOW. Returns how far the string is back from its rest (studs), for the string and the nocked arrow.
]]
function WeaponPose.bow(rig: ClipPlayer.Rig, pose: { [string]: CFrame }, v: { [string]: any }, hold: Hold, pitch: number, weight: number): number
	body(pose, v, weight)
	local turn = lookTurn(v, pitch)
	local at = NECK + turn:VectorToWorldSpace((v.hand :: Vector3) - NECK)
	local aim = turn:VectorToWorldSpace(unit(v.aim, Vector3.new(0, 0, -1)))
	local up = turn:VectorToWorldSpace(v.up or Vector3.yAxis)
	-- the hilt's frame: the arrow leaves along -Z, the stave stands along +Y
	local z = -aim
	local y = across(up, z, Vector3.yAxis)
	local rot = CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
	local drawer = if hold.side == "Left" then "Right" else "Left"
	grasped(rig, pose, hold.side, hold.hiltInHand, at, rot, ELBOW_BOW_ARM * Vector3.new(if hold.side == "Left" then 1 else -1, 1, 1), weight, false)

	local pull = (v.draw or 0) * hold.stringDraw
	local onString = (v.string or 0) * weight
	local chest = ClipPlayer.chest(rig, pose)
	local elbow = ELBOW_DRAWING * Vector3.new(if drawer == "Right" then 1 else -1, 1, 1)
	local reachOn = (v.reachOn or 0) * weight
	if reachOn > 0 and v.reach then
		ClipPlayer.reach(rig, pose, drawer, chest:PointToObjectSpace(v.reach), chest:VectorToObjectSpace(elbow), reachOn)
	end
	if onString > 0 then
		local nock = at + z * (hold.stringBack + pull)
		ClipPlayer.reach(rig, pose, drawer, chest:PointToObjectSpace(nock), chest:VectorToObjectSpace(elbow), onString)
	end
	return pull
end

--[[
	What a body needs to know about the weapon in its hand to be posed (`Hold`), from configs/Gear and the body's own
	hands. `gripFrame` is the six-number grip as a CFrame.
]]
function WeaponPose.hold(character: Model, kind: string, side: string, gripFrame: CFrame, stringBack: number?, stringDraw: number?): Hold?
	local other = if side == "Right" then "Left" else "Right"
	local hand = character:FindFirstChild(side .. "Hand")
	local otherHand = character:FindFirstChild(other .. "Hand")
	local grip = hand and hand:FindFirstChild(side .. "GripAttachment")
	local otherGrip = otherHand and otherHand:FindFirstChild(other .. "GripAttachment")
	if not (grip and grip:IsA("Attachment") and otherGrip and otherGrip:IsA("Attachment")) then
		return nil
	end
	return {
		kind = kind,
		side = side,
		hiltInHand = grip.CFrame * gripFrame,
		otherGrip = otherGrip.CFrame,
		stringBack = stringBack or 0,
		stringDraw = stringDraw or 0,
	}
end

return WeaponPose
