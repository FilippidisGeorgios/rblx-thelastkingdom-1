--[[
	Hold (2026-11-14): bakes an arm's REST pose so that its fist (Grip.fist's "Fist" Attachment) is exactly at a wanted
	frame: the shoulder is turned and the elbow bent to put the wrist where that hand must be (ClipPlayer.reach), then
	the wrist is turned so the hand lies as the frame says. The result goes into the joints' C0 (the bodies' rest is
	baked into their Motor6Ds, and every clip is a delta from it), and the parts are moved to match (tools/zombie/Pose).

	    Hold.fistAt(model, "Right", fistWorld, pole)   -- fistWorld: the frame the fist must take, in world space
	    Hold.rollToward(point, along)                   -- a fist frame along `along` whose Y faces away from `point`

	A tool, not game code. Run it on a body OUTSIDE the world (ServerStorage) or in the Booth; it moves parts.
]]

local Hold = {}

local function deps()
	local lab = script.Parent
	local ClipPlayer = require(lab.Fresh.Anim.ClipPlayer)
	local Pose = require(lab.Pose)
	return ClipPlayer, Pose
end

-- The joint (Motor6D) that moves part `name`.
local function jointOf(model: Model, name: string): Motor6D?
	local part = model:FindFirstChild(name)
	if not part then
		return nil
	end
	for _, d in part:GetChildren() do
		if d:IsA("Motor6D") and d.Part1 == part then
			return d
		end
	end
	return nil
end

--[[
	Puts the `side` fist at `fistWorld` (the CFrame its Fist attachment must have). `pole` (chest space) is where the elbow
	should point. Returns how far the fist ended from where it was asked to be (studs).
]]
function Hold.fistAt(model: Model, side: string, fistWorld: CFrame, pole: Vector3?): number
	local ClipPlayer, Pose = deps()
	local rig = ClipPlayer.rig(model, true)
	assert(rig, "no rig")
	local handName = side .. "Hand"
	local hand = model:FindFirstChild(handName) :: BasePart
	local fist = hand:FindFirstChild("Fist") :: Attachment
	assert(fist, "make the fist first (Grip.fist)")
	local chest = (model :: any).UpperTorso.CFrame
	local handWorld = fistWorld * fist.CFrame:Inverse()
	local handChest = chest:ToObjectSpace(handWorld)
	local pose = {}
	local ArmIK = require(script.Parent.Fresh.Anim.ArmIK)
	ArmIK.solve(rig, pose, side, handChest, pole or Vector3.new(if side == "Left" then -0.6 else 0.6, -1, 0.4))
	-- bake into the C0s
	for _, part in { side .. "UpperArm", side .. "LowerArm", handName } do
		local j = jointOf(model, part)
		local tr = pose[part]
		if j and tr then
			j.C0 = j.C0 * tr
		end
	end
	Pose.rest(model)
	-- how near
	local got = hand.CFrame * fist.CFrame
	return (got.Position - fistWorld.Position).Magnitude
end

--[[
	A fist frame at `p` running along `along` (X, toward the business end), turned about that line so its Y (away from
	the wrist) points away from `from` (a point the forearm comes from: a shoulder, an elbow).
]]
function Hold.frame(p: Vector3, along: Vector3, from: Vector3): CFrame
	local x = along.Unit
	local v = p - from
	local y = v - x * v:Dot(x)
	if y.Magnitude < 1e-4 then
		y = Vector3.new(0, -1, 0) - x * -x.Y
	end
	y = y.Unit
	return CFrame.fromMatrix(p, x, y, x:Cross(y))
end

return Hold
