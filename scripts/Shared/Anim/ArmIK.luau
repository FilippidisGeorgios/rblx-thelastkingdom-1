--!strict
--[[
	ArmIK (2026-11-14)
	Puts a HAND exactly on a frame by turning the shoulder, bending the elbow and turning the wrist, for any body whose
	arm joints are Motor6Ds (or AnimationConstraints) with whatever seats (C0/C1) the body was built with.

	WHY NOT ClipPlayer.reach. That one is written for the player's square body (each arm bone along the part's own Y, the
	elbow bending about X), and on the dead (limbs built along X, joints seated a quarter turn round) it missed by a
	third of a stud: a hand that should close on a haft hung beside it. This one only uses where the three joints ARE:
	  * the two bone lengths (shoulder to elbow, elbow to wrist) come from the joints' seats, whatever their turn;
	  * the elbow is put on the circle where both bones meet, on the side `pole` says;
	  * the upper arm is turned (about the shoulder) to carry the elbow there, the forearm (about the elbow) to carry
	    the wrist onto the target, and the hand at the wrist to lie as the frame says.
	All in the CHEST's space (UpperTorso), under the pose being built, so it sits on top of any clip.

	Location: ReplicatedStorage.Shared.Anim.ArmIK. Pure: it writes into the `pose` table it is given.
]]

local ClipPlayer = require(script.Parent.ClipPlayer)

local ArmIK = {}

local IDENTITY = CFrame.new()

-- the rotation that carries direction a onto direction b (the shortest)
local function between(a: Vector3, b: Vector3): CFrame
	local ua, ub = a.Unit, b.Unit
	local axis = ua:Cross(ub)
	local d = math.clamp(ua:Dot(ub), -1, 1)
	if axis.Magnitude < 1e-6 then
		if d > 0 then
			return IDENTITY
		end
		local any = if math.abs(ua.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
		return CFrame.fromAxisAngle(ua:Cross(any).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

-- turns frame f by rotation q about point p
local function about(q: CFrame, p: Vector3, f: CFrame): CFrame
	return CFrame.new(p) * q * CFrame.new(-p) * f
end

--[[
	Changes pose[<side>UpperArm], pose[<side>LowerArm] and pose[<side>Hand] so the hand's frame (in the chest's space)
	becomes `handChest`. `pole`: a direction (chest space) the elbow should point to. Returns how far the wrist is from
	where it had to be (0 when it was in reach).
]]
function ArmIK.solve(rig: ClipPlayer.Rig, pose: { [string]: CFrame }, side: string, handChest: CFrame, pole: Vector3): number
	local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
	local s0, s1 = rig.a0[upper], rig.a1[upper]
	local e0, e1 = rig.a0[lower], rig.a1[lower]
	local w0, w1 = rig.a0[hand], rig.a1[hand]
	if not (s0 and s1 and e0 and e1 and w0 and w1) then
		return math.huge
	end
	-- the arm as the pose has it
	local fu = ClipPlayer.link(rig, pose, upper)
	local ff = fu * ClipPlayer.link(rig, pose, lower)
	local S = s0.Position
	local E = (fu * e0).Position
	local W = (ff * w0).Position
	local L1 = (e0.Position - s1.Position).Magnitude
	local L2 = (w0.Position - e1.Position).Magnitude
	-- where the wrist must go
	local T = (handChest * w1).Position
	local toT = T - S
	local d = math.clamp(toT.Magnitude, math.abs(L1 - L2) + 1e-3, L1 + L2 - 1e-3)
	local dir = toT.Unit
	local along = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(0, L1 * L1 - along * along))
	local p = pole - dir * pole:Dot(dir)
	if p.Magnitude < 1e-4 then
		p = Vector3.new(0, -1, 0) - dir * -dir.Y
	end
	local E2 = S + dir * along + p.Unit * h
	-- the upper arm, about the shoulder, carries the elbow to E2 (and the forearm with it)
	local q1 = between(E - S, E2 - S)
	local fu2 = about(q1, S, fu)
	local ff1 = about(q1, S, ff)
	local W1 = (ff1 * w0).Position
	-- the forearm, about the elbow, carries the wrist onto the target line
	local Treal = S + dir * d
	local q2 = between(W1 - E2, Treal - E2)
	local ff2 = about(q2, E2, ff1)
	-- back into the joints' Transforms
	pose[upper] = (s0:Inverse() * fu2 * s1).Rotation
	pose[lower] = (e0:Inverse() * fu2:Inverse() * ff2 * e1).Rotation
	pose[hand] = (w0:Inverse() * ff2:Inverse() * handChest * w1).Rotation
	return (T - Treal).Magnitude
end

return ArmIK
