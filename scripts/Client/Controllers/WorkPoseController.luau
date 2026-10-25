--!strict
--[[
	WorkPoseController
	The body of a person at work. The server says what somebody is doing by an
	attribute on their character (`WorkPose` = "dig" | "dig_bare", `WorkAt` = the
	point they are working on, `WorkHit` = a counter that ticks when they are
	struck), and every client turns that into a pose: the arms go up over the
	shoulder, come down on the stones, the hips drop with it, and a spit of grit
	leaves the face of the cut at the moment of the blow.

	WHY PROCEDURAL
	There is no digging clip to play (nothing in the game is animated by uploaded
	keyframes except the dead's, built in code at start). The swing is a set of
	joint angles on the character's Motor6Ds, written after the engine's own
	animation step each frame (Heartbeat), blended in and out over a quarter of a
	second so a person does not snap into the pose or out of it. Nothing here
	replicates: each client poses every character that carries the attribute
	from the same clock, so they all see the same swing within a frame or two.

	It is general on purpose: the forge's hammer and the woodyard's axe will be
	more entries in the same table.

	Place: client (boots in both places; active only where the server sets the attribute).
	Phase: Trials.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WorkPoseController = {}

WorkPoseController.Name = "WorkPoseController"

type Joints = { [string]: Motor6D }

type State = {
	character: Model,
	joints: Joints,
	weight: number,
	pose: string?,
	lastPose: string,
	hitSeen: number,
	flinchUntil: number,
	lastStrike: number,
	humanoid: Humanoid?,
	autoRotate: boolean?,
}

local states: { [Model]: State } = {}

local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightHip = { "RightUpperLeg", "RightHip" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
}

local function findJoints(character: Model): Joints?
	local out: Joints = {}
	for name, where in JOINTS do
		local limb = character:FindFirstChild(where[1])
		local motor = limb and limb:FindFirstChild(where[2])
		if motor and motor:IsA("Motor6D") then
			out[name] = motor
		end
	end
	-- Without the shoulders there is no pose to give (an R6 rig, a character still loading).
	if not (out.RightShoulder and out.LeftShoulder and out.Waist) then
		return nil
	end
	return out
end

local function rx(deg: number): CFrame
	return CFrame.Angles(math.rad(deg), 0, 0)
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--==========================================================================
-- THE POSES. Each returns the angle (degrees) or CFrame for each joint at time
-- `t`, plus whether the blow lands in this frame's window (for the grit).
--==========================================================================
type Frame = { [string]: CFrame }

-- Overhead pick: up over the shoulder, a hang, down on the stones, a hold while it
-- is levered, and up again. 1.15 seconds a swing.
local DIG_PERIOD = 1.15
local function dig(t: number): (Frame, number)
	local s = (t % DIG_PERIOD)
	local u -- 0 = at the top, 1 = at the blow
	local raise, hang, strike = 0.55, 0.1, 0.12
	if s < raise then
		u = 1 - smooth(s / raise)
	elseif s < raise + hang then
		u = 0
	elseif s < raise + hang + strike then
		local k = (s - raise - hang) / strike
		u = k * k
	else
		u = 1
	end
	-- a little shake in the hold, as the head bites and the haft is worked
	local shake = 0
	if s > raise + hang + strike and s < raise + hang + strike + 0.14 then
		shake = math.sin((s - raise - hang - strike) * 60) * (1 - (s - raise - hang - strike) / 0.14) * 0.9
	end
	local frame: Frame = {
		RightShoulder = rx(mix(158, 58, u) + shake),
		LeftShoulder = rx(mix(154, 54, u) + shake),
		RightElbow = rx(mix(38, 14, u)),
		LeftElbow = rx(mix(38, 14, u)),
		Waist = rx(mix(16, -26, u)),
		Neck = rx(mix(-6, 12, u)),
		Root = CFrame.new(0, mix(0, -0.34, u), mix(0.08, -0.42, u)),
		RightHip = rx(mix(2, 26, u)),
		LeftHip = rx(mix(4, 22, u)),
		RightKnee = rx(mix(-2, -42, u)),
		LeftKnee = rx(mix(-2, -38, u)),
	}
	return frame, s
end

-- Bare hands: bent double, scraping and pulling at the rubble, one arm then the other.
local BARE_PERIOD = 1.0
local function digBare(t: number): (Frame, number)
	local a = math.sin((t % BARE_PERIOD) / BARE_PERIOD * math.pi * 2)
	local b = math.cos((t % BARE_PERIOD) / BARE_PERIOD * math.pi * 2)
	local frame: Frame = {
		RightShoulder = rx(52 + a * 22),
		LeftShoulder = rx(52 - a * 22),
		RightElbow = rx(54 + b * 14),
		LeftElbow = rx(54 - b * 14),
		Waist = rx(-40 + a * 4),
		Neck = rx(24),
		Root = CFrame.new(0, -0.55, -0.5),
		RightHip = rx(44),
		LeftHip = rx(40),
		RightKnee = rx(-76),
		LeftKnee = rx(-70),
	}
	return frame, (t % BARE_PERIOD)
end

local POSES: { [string]: (number) -> (Frame, number) } = {
	dig = dig,
	dig_bare = digBare,
}

--==========================================================================
-- THE GRIT: a spit of stone and dust at the face at the moment of the blow.
--==========================================================================
local gritPart: Part? = nil
local gritEmitter: ParticleEmitter? = nil
local dustEmitter: ParticleEmitter? = nil

local function grit(at: Vector3)
	if not gritPart or not gritPart.Parent then
		local p = Instance.new("Part")
		p.Name = "WorkGrit"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.Parent = workspace
		gritPart = p

		local chips = Instance.new("ParticleEmitter")
		chips.Rate = 0
		chips.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		chips.Color = ColorSequence.new(Color3.fromRGB(112, 104, 94))
		chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.1) })
		chips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
		chips.Lifetime = NumberRange.new(0.5, 0.9)
		chips.Speed = NumberRange.new(10, 22)
		chips.SpreadAngle = Vector2.new(55, 55)
		chips.Acceleration = Vector3.new(0, -60, 0)
		chips.LightEmission = 0
		chips.Parent = p
		gritEmitter = chips

		local dust = Instance.new("ParticleEmitter")
		dust.Rate = 0
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(126, 114, 98))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.6) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.9, 1.6)
		dust.Speed = NumberRange.new(2, 6)
		dust.SpreadAngle = Vector2.new(80, 80)
		dust.Acceleration = Vector3.new(0, 1.5, 0)
		dust.Drag = 2.5
		dust.Parent = p
		dustEmitter = dust
	end
	(gritPart :: Part).Position = at
	if gritEmitter then
		gritEmitter:Emit(9)
	end
	if dustEmitter then
		dustEmitter:Emit(4)
	end
end

--==========================================================================
-- PER-FRAME
--==========================================================================
local function ensureState(character: Model): State?
	local existing = states[character]
	if existing then
		return existing
	end
	local joints = findJoints(character)
	if not joints then
		return nil
	end
	local state: State = {
		character = character,
		joints = joints,
		weight = 0,
		pose = nil,
		lastPose = "dig",
		hitSeen = (character:GetAttribute("WorkHit") :: number?) or 0,
		flinchUntil = 0,
		lastStrike = -1,
		humanoid = character:FindFirstChildOfClass("Humanoid"),
		autoRotate = nil,
	}
	states[character] = state
	return state
end

local function release(state: State)
	local localCharacter = Players.LocalPlayer.Character
	if state.character == localCharacter and state.humanoid and state.autoRotate ~= nil then
		state.humanoid.AutoRotate = state.autoRotate
		state.autoRotate = nil
	end
	states[state.character] = nil
end

local function step(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:GetAttribute("WorkPose") ~= nil then
			ensureState(character)
		end
	end

	for character, state in states do
		if not character.Parent then
			states[character] = nil
			continue
		end
		local wanted = character:GetAttribute("WorkPose")
		local pose = if typeof(wanted) == "string" and POSES[wanted] then wanted else nil
		state.pose = pose
		if pose then
			state.lastPose = pose
			state.weight = math.min(1, state.weight + dt / 0.25)
		else
			state.weight = math.max(0, state.weight - dt / 0.25)
			if state.weight <= 0 then
				release(state)
				continue
			end
		end

		-- a blow taken
		local hits = (character:GetAttribute("WorkHit") :: number?) or 0
		if hits ~= state.hitSeen then
			state.hitSeen = hits
			state.flinchUntil = now + 0.5
		end

		local frame, phase = POSES[state.lastPose](now)
		local flinch = if now < state.flinchUntil then smooth((state.flinchUntil - now) / 0.5) else 0
		if flinch > 0 then
			frame.Waist = frame.Waist * CFrame.Angles(math.rad(20 * flinch), 0, 0)
			frame.RightShoulder = rx(mix(60, -26, flinch))
			frame.LeftShoulder = rx(mix(60, -26, flinch))
			frame.Neck = rx(-18 * flinch)
		end

		for name, target in frame do
			local motor = state.joints[name]
			if motor then
				motor.Transform = motor.Transform:Lerp(target, state.weight)
			end
		end

		-- the blow: grit at the face, once per swing
		if state.lastPose == "dig" and pose and state.weight > 0.9 and flinch == 0 then
			local strikeAt = 0.55 + 0.1 + 0.12
			local swing = math.floor(now / DIG_PERIOD)
			if phase >= strikeAt and phase < strikeAt + 0.12 and swing ~= state.lastStrike then
				state.lastStrike = swing
				local at = character:GetAttribute("WorkAt")
				if typeof(at) == "Vector3" then
					grit(at)
					if character == Players.LocalPlayer.Character and state.humanoid then
						local humanoid = state.humanoid
						humanoid.CameraOffset = Vector3.new(0, -0.14, 0)
						task.delay(0.07, function()
							if humanoid.Parent then
								humanoid.CameraOffset = Vector3.zero
							end
						end)
					end
				end
			end
		end

		-- turn to the work (our own character only: the others' owners do the same)
		if character == Players.LocalPlayer.Character and pose and state.humanoid then
			local root = character:FindFirstChild("HumanoidRootPart")
			local at = character:GetAttribute("WorkAt")
			if root and root:IsA("BasePart") and typeof(at) == "Vector3" then
				if state.autoRotate == nil then
					state.autoRotate = state.humanoid.AutoRotate
					state.humanoid.AutoRotate = false
				end
				local flat = Vector3.new(at.X, root.Position.Y, at.Z)
				if (flat - root.Position).Magnitude > 0.5 then
					local want = CFrame.lookAt(root.Position, flat)
					root.CFrame = root.CFrame:Lerp(want, math.clamp(dt * 9, 0, 1))
				end
			end
		end
	end
end

function WorkPoseController.Init() end

function WorkPoseController.Start()
	-- After the engine's own animation step, so the pose is on top of whatever the
	-- Animate script is playing (and before the frame is drawn).
	RunService.Heartbeat:Connect(step)
end

return WorkPoseController
