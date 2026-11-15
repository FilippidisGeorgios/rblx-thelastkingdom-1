--!strict
--[[
	Gear.spec
	The weapon bar, the hands and the back hang together (configs/Gear, configs/Weapons, configs/Items,
	Shared/Anim/PlayerActionAnims, Shared/Anim/PlayerMoveAnims, Shared/Anim/ClipPlayer, Shared/Anim/WeaponPose):
	every weapon a player starts with exists everywhere it has to, every kind of weapon has its moves, no two attacks of
	one weapon are the same length, a walk is the same stride every way, and a hand that is told to reach a point is ON it.

	Location: TestService.Tests.Gear.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear: any = require(ReplicatedStorage.Config.Gear)
local Weapons: any = require(ReplicatedStorage.Config.Weapons)
local Items: any = require(ReplicatedStorage.Config.Items)
local ClipPlayer = require(ReplicatedStorage.Shared.Anim.ClipPlayer)
local PlayerActionAnims = require(ReplicatedStorage.Shared.Anim.PlayerActionAnims)
local PlayerMoveAnims = require(ReplicatedStorage.Shared.Anim.PlayerMoveAnims)
local WeaponPose = require(ReplicatedStorage.Shared.Anim.WeaponPose)

-- The joints of the square R15 body, as measured on one (studs): where each joint sits in its parent part and in its own.
local function squareRig(): any
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	local a0 = {
		LowerTorso = at(0, -1, 0),
		UpperTorso = at(0, 0.2, 0),
		Head = at(0, 0.85, 0),
		RightUpperArm = at(0.97, 0.6, 0),
		RightLowerArm = at(0, -0.36, 0),
		RightHand = at(0, -0.53, 0),
		LeftUpperArm = at(-0.97, 0.6, 0),
		LeftLowerArm = at(0, -0.36, 0),
		LeftHand = at(0, -0.53, 0),
	}
	local a1 = {
		LowerTorso = at(0, -0.2, 0),
		UpperTorso = at(0, -0.85, 0),
		Head = at(0, -0.58, 0),
		RightUpperArm = at(-0.5, 0.42, 0),
		RightLowerArm = at(0, 0.27, 0),
		RightHand = at(0, 0.13, 0),
		LeftUpperArm = at(0.5, 0.42, 0),
		LeftLowerArm = at(0, 0.27, 0),
		LeftHand = at(0, 0.13, 0),
	}
	return { joints = {}, a0 = a0, a1 = a1, character = nil }
end

return function(t: any)
	t.test("every starter weapon is a weapon, an item that points at it, and a thing that can be shown", function()
		assert(#Gear.Starter.Weapons >= 1, "somebody starts with something")
		for _, id in Gear.Starter.Weapons do
			assert(Weapons[id] ~= nil, id .. " has numbers in configs/Weapons")
			assert(Items[id] ~= nil and Items[id].Category == "Weapon" and Items[id].WeaponId == id, id .. " is a weapon item")
			assert(Gear.Weapons[id] ~= nil, id .. " has a look in configs/Gear")
		end
		assert(Gear.Starter.Arrows > 0 and Gear.Starter.Arrows <= Gear.Back.Quiver.Capacity, "a quiver starts with arrows and never more than it holds")
	end)

	t.test("no body armour is left anywhere in the data (the developer, 2026-11-13: the shield is a thing of its own)", function()
		assert(Gear.Back.Armour == nil and Gear.Back.Order == nil and Gear.Starter.Back == nil, "armour is not on the back any more")
		assert(PlayerActionAnims.clip("armour_don") == nil and PlayerActionAnims.clip("armour_doff") == nil, "no clips for putting plate on")
	end)

	t.test("a body whose neck has not streamed in yet is not a whole rig, and becomes one when it has (the friend's head that never turned)", function()
		local body = Instance.new("Model")
		local parts: { [string]: Part } = {}
		for name in ClipPlayer.JOINTS do
			local part = Instance.new("Part")
			part.Name = name
			part.Parent = body
			parts[name] = part
		end
		-- every joint but the neck is complete; the neck is an AnimationConstraint with no attachments yet
		for name, jointName in ClipPlayer.JOINTS do
			local joint = Instance.new("AnimationConstraint")
			joint.Name = jointName
			joint.Parent = parts[name]
			if name ~= "Head" then
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent, a1.Parent = parts.LowerTorso, parts[name]
				joint.Attachment0, joint.Attachment1 = a0, a1
			end
		end
		local early = ClipPlayer.rig(body)
		assert(early ~= nil, "a body with its torso and hips can be taken on")
		assert(not early.complete and early.joints.Head == nil and early.count == 14, "but it is not whole: the neck is missing")
		-- the neck arrives
		local neck = (parts.Head :: Part):FindFirstChild("Neck") :: AnimationConstraint
		local n0, n1 = Instance.new("Attachment"), Instance.new("Attachment")
		n0.Parent, n1.Parent = parts.UpperTorso, parts.Head
		neck.Attachment0, neck.Attachment1 = n0, n1
		local later = ClipPlayer.rig(body)
		assert(later ~= nil and later.complete and later.joints.Head ~= nil and later.count == 15, "and the next look finds all 15 joints")
		body:Destroy()
	end)

	t.test("every weapon's kind has its moves, and every move it names exists", function()
		for id, def in Gear.Weapons do
			local kind = (PlayerActionAnims.KINDS :: any)[def.Kind]
			assert(kind ~= nil, id .. ": no moves for the kind " .. tostring(def.Kind))
			assert(def.Hand == "Right" or def.Hand == "Left", id .. " is held in a hand")
			assert(def.Sheath and def.Sheath.Part and def.Sheath.At, id .. " has a place on the body")
			local names: { string } = { kind.hold }
			for _, name in kind.attacks or {} do
				table.insert(names, name)
			end
			for _, field in { "draw", "aim", "loose", "lower" } do
				if kind[field] then
					table.insert(names, kind[field])
				end
			end
			for _, name in names do
				if kind.clips then
					assert(PlayerActionAnims.clip(name) ~= nil, id .. ": no clip called " .. name)
				else
					assert(PlayerActionAnims.track(name) ~= nil, id .. ": no track called " .. name)
				end
			end
		end
	end)

	t.test("no two attacks of one weapon are the same length (the house rule)", function()
		for kindName, kind in PlayerActionAnims.KINDS :: any do
			local seen: { [number]: string } = {}
			for _, name in kind.attacks or {} do
				local clip = PlayerActionAnims.clip(name)
				local track = PlayerActionAnims.track(name)
				local length = if clip then clip.length else (track :: any).length
				local key = math.floor(length * 1000 + 0.5)
				assert(seen[key] == nil, kindName .. ": " .. name .. " is as long as " .. tostring(seen[key]))
				seen[key] = name
			end
		end
	end)

	t.test("a track says where the hand and the weapon are from its first key, and is eased between keys", function()
		local _, tracks = PlayerActionAnims.names()
		for _, name in tracks do
			local track = PlayerActionAnims.track(name) :: any
			local out: { [string]: any } = {}
			PlayerActionAnims.sample(track, 0, out)
			assert(typeof(out.hand) == "Vector3" and typeof(out.aim) == "Vector3", name .. " starts with a hand and an aim")
			PlayerActionAnims.sample(track, track.length / 2, out)
			assert(typeof(out.hand) == "Vector3" and out.hand == out.hand, name .. " has a hand half way")
		end
		-- the bow's draw ends at the full draw, the loose begins there
		local draw, loose = PlayerActionAnims.track("bow_draw") :: any, PlayerActionAnims.track("bow_loose") :: any
		local a, b: { [string]: any } = {}, {}
		PlayerActionAnims.sample(draw, draw.length, a)
		PlayerActionAnims.sample(loose, 0, b)
		assert(a.draw == 1 and b.draw == 1, "full draw at the end of the draw and the start of the loose")
		PlayerActionAnims.sample(loose, loose.length, b)
		assert(b.draw == 0 and b.string == 0, "the string is back and the hand is off it when the loose is over")
	end)

	t.test("a walk is the same stride every way, in every set", function()
		for set = 1, PlayerMoveAnims.COUNT do
			local clips = PlayerMoveAnims.clips(set)
			for _, family in { "walk", "run", "duck" } do
				local forward = clips[family].frames
				local length = forward[#forward].time
				for _, way in { "Back", "Right", "Left" } do
					local other = clips[family .. way]
					assert(other ~= nil, ("set %d has no %s%s"):format(set, family, way))
					assert(math.abs(other.frames[#other.frames].time - length) < 1e-6, ("set %d: %s%s is not the stride of %s"):format(set, family, way, family))
				end
			end
		end
	end)

	t.test("the roll's hips: nothing at the start, a whole turn at the end, the way it is going", function()
		local start = PlayerMoveAnims.rollHips(0, Vector3.new(0, 0, -1))
		assert(start.Position.Magnitude < 1e-4, "the hips have not moved at the start")
		-- (2026-11-15, measured contact: the hips go UP over the shoulders at the dive, then DOWN while the back is on
		-- the floor)
		local dive = PlayerMoveAnims.rollHips(PlayerMoveAnims.ROLL_LENGTH * 0.13 / 0.6, Vector3.new(0, 0, -1))
		assert(dive.Position.Y > 0.5, "the hips go up over the shoulders at the dive")
		local back = PlayerMoveAnims.rollHips(PlayerMoveAnims.ROLL_LENGTH * 0.55, Vector3.new(0, 0, -1))
		assert(back.Position.Y < -1, "the hips are down while the back is on the floor")
		-- going ahead the head goes ahead (-Z); going right it goes right (+X)
		local quarter = PlayerMoveAnims.rollHips(PlayerMoveAnims.ROLL_LENGTH * 0.2, Vector3.new(0, 0, -1))
		assert(quarter:VectorToWorldSpace(Vector3.yAxis).Z < -0.5, "a roll ahead turns the head ahead")
		local side = PlayerMoveAnims.rollHips(PlayerMoveAnims.ROLL_LENGTH * 0.2, Vector3.new(1, 0, 0))
		assert(side:VectorToWorldSpace(Vector3.yAxis).X > 0.5, "a roll to the right turns the head to the right")
	end)

	t.test("a hand told to reach a point is on it", function()
		local rig = squareRig()
		for _, case in { { "Right", Vector3.new(0.6, 0.1, -1.2) }, { "Left", Vector3.new(-0.2, -0.4, -1.0) }, { "Right", Vector3.new(1.2, -0.9, 0.3) } } do
			local side, target = case[1] :: string, case[2] :: Vector3
			local pose: { [string]: CFrame } = {}
			ClipPlayer.reach(rig, pose, side, target, Vector3.new(if side == "Right" then 0.5 else -0.5, -0.8, 0.4), 1)
			-- the grip is 0.16 under the hand's middle
			local grip = ClipPlayer.hand(rig, pose, side) * Vector3.new(0, -0.16, 0)
			assert((grip - target).Magnitude < 0.01, ("%s grip is %.3f from the point"):format(side, (grip - target).Magnitude))
		end
		-- out of reach: the arm goes straight toward it and stops
		local pose: { [string]: CFrame } = {}
		ClipPlayer.reach(rig, pose, "Right", Vector3.new(0.97, 0.6, -9), Vector3.new(0.5, -0.8, 0.4), 1)
		local grip = ClipPlayer.hand(rig, pose, "Right") * Vector3.new(0, -0.16, 0)
		assert(grip.Z < -1.7 and grip.Z > -2.1, "a far point is reached for as far as the arm goes")
	end)

	t.test("a spear's two hands are on its shaft, as far apart as the track says", function()
		local rig = squareRig()
		local hold: WeaponPose.Hold = {
			kind = "spear",
			side = "Right",
			hiltInHand = CFrame.new(0, -0.16, 0) * CFrame.Angles(math.rad(-90), 0, 0),
			otherGrip = CFrame.new(0, -0.16, 0) * CFrame.Angles(math.rad(-90), 0, 0),
			stringBack = 0,
			stringDraw = 0,
		}
		local track = PlayerActionAnims.track("spear_hold") :: any
		local values: { [string]: any } = {}
		PlayerActionAnims.sample(track, 0, values)
		local pose: { [string]: CFrame } = {}
		local hilt = WeaponPose.spear(rig, pose, values, hold, 0, 1)
		assert((hilt.Position - values.hand).Magnitude < 0.02, "the shaft is where the track put the hand")
		local chest = ClipPlayer.chest(rig, pose)
		local right = (chest * ClipPlayer.hand(rig, pose, "Right") * hold.hiltInHand).Position
		local left = (chest * ClipPlayer.hand(rig, pose, "Left") * hold.otherGrip).Position
		assert((right - values.hand).Magnitude < 0.03, ("the holding hand is %.3f off"):format((right - values.hand).Magnitude))
		assert(math.abs((left - right).Magnitude - values.support) < 0.05, ("the hands are %.2f apart, the track says %.2f"):format((left - right).Magnitude, values.support))
		-- and the second hand is ON the shaft's line
		local along = (left - right):Dot(hilt.YVector)
		assert((left - (right + hilt.YVector * along)).Magnitude < 0.05, "the second hand is on the shaft")
	end)
end
