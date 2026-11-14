--!strict
--[[
	BodyAnimController
	Moves the body of every player this client can see (you too): the walk under everything, and on top of it whatever
	the hands are doing (docs/systems/Animation.md, docs/systems/Movement.md, docs/systems/Gear.md).

	Every frame, before the physics step (Roblox's upgraded joints only take a pose written there), each body's pose is
	put together in this order:

	  1. THE FEET   idle, the walk and the run EVERY WAY (forward, back, sidesteps, blended by the way the feet are really
	                going, because the body faces where the eyes look), ducked versions of them, jump, fall, sit, climb,
	                each fading into the next over a fifth of a second (Shared/Anim/PlayerMoveAnims).
	  2. THE HANDS  the weapon held (a sword's guard; a spear in two hands; a bow), the lantern held up, then the one
	                thing being DONE: a cut, a thrust, the draw and the loose (Shared/Anim/PlayerActionAnims).
	  3. THE LOOK   the chest and the head follow where that player looks, up and down, and the head runs a little ahead
	                of a turning body (what you see of a friend looking round).
	  4. TWO HANDS  a spear's second hand and a bow's drawing hand are put exactly ON the weapon (Shared/Anim/WeaponPose).
	  5. THE ROLL   the tumble, the way the body is really going. (Not on your own body: you are behind its eyes, and a
	                body that turns over inside its own collision box is what made the roll catch on the ground.)
	  6. Whenever what the hands do changes, the new pose is eased in from the one that was showing, so nothing snaps.

	WHERE IT GETS ITS NEWS. Nothing is sent per frame. The server writes a few attributes and every client reads them:
	on the character `Weapon` and `WeaponDrawn` (World/WeaponVisualService); on its Humanoid `RollSeq`, `Crouching`,
	`BowSeq` + `BowState` (Services/MovementService, World/CrouchService,
	World/RangedCombatService); a swing is the `CombatEvent` "MeleeSwing"; a look is `LookSync`.
	Your OWN swing, draw and roll are drawn the moment you press (`playLocal...` below, called by the input controllers);
	the server's echo of them is then ignored.

	Roblox's own `Animate` script is switched off on your body: nothing else moves the limbs.

	Place: client (boots in both places).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local ClipPlayer = require(ReplicatedStorage.Shared.Anim.ClipPlayer)
local PlayerMoveAnims = require(ReplicatedStorage.Shared.Anim.PlayerMoveAnims)
local PlayerActionAnims = require(ReplicatedStorage.Shared.Anim.PlayerActionAnims)
local WeaponPose = require(ReplicatedStorage.Shared.Anim.WeaponPose)

local BodyAnimController = {}

BodyAnimController.Name = "BodyAnimController"

local log = Logger.new("BodyAnimController")

local player = Players.LocalPlayer
local moveCfg: any = nil
local viewCfg: any = nil
local gearCfg: any = nil
local weaponsCfg: any = nil

local IDENTITY = CFrame.new()
local viewOffset: (any, { [string]: CFrame }, number) -> { [string]: CFrame }
local FADE = 0.18 -- seconds one state of the feet takes to become the next
local RUN_ABOVE = 19.5 -- studs a second along the ground: faster than any walk
local IDLE_BELOW = 0.8
local FALL_AFTER = 0.16 -- seconds off the ground before a step down becomes a fall
local ROLL_IN, ROLL_OUT = 0.04, 0.07
local HOLD_FADE = 0.22 -- seconds a weapon's hold takes to come on or go off
local EASE_IN = 0.09 -- seconds a new move is eased in from the pose that was showing

--==========================================================================
-- The clips
--==========================================================================
local built: { [number]: { [string]: ClipPlayer.Clip } } = {}

local function clipsFor(set: number): { [string]: ClipPlayer.Clip }
	local have = built[set]
	if have then
		return have
	end
	local made: { [string]: ClipPlayer.Clip } = {}
	for name, def in PlayerMoveAnims.clips(set) do
		made[name] = ClipPlayer.clip(PlayerMoveAnims.name(set) .. "_" .. name, def.frames, def.looped)
	end
	built[set] = made
	return made
end

local function currentSet(): number
	local s = Workspace:GetAttribute("TLK_MoveStyle")
	if typeof(s) == "number" and s >= 1 and s <= PlayerMoveAnims.COUNT then
		return math.floor(s)
	end
	return moveCfg.Style
end

--==========================================================================
-- The bodies
--==========================================================================
type Layer = { time: number, weight: number }

type Action = {
	name: string,
	clip: ClipPlayer.Clip?,
	track: PlayerActionAnims.Track?,
	start: number,
	rate: number, -- seconds of the move played each second
	stay: boolean, -- stays on its last key until something else is played (a drawn bow)
	after: string?, -- a track to go to when this one ends (the draw goes into the aim)
}

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	rig: ClipPlayer.Rig,
	owner: Player,
	mine: boolean,
	checked: number,
	-- the feet
	state: string,
	layers: { [string]: Layer },
	phase: number,
	run: number,
	duck: number,
	ahead: number, -- the way the feet go in the body's own space: ahead (+) or back (-)
	aside: number, -- right (+) or left (-)
	moving: number, -- 0 standing .. 1 walking, eased (for the eyes' step)
	airAt: number?,
	jumped: boolean,
	landed: number, -- how hard the last landing was (studs a second), read once by the view
	ray: RaycastParams,
	yaw: number,
	turn: number, -- how fast the body is turning, radians a second, eased
	-- the roll
	rollSeq: number?,
	rollAt: number?,
	rollRate: number,
	rollWay: Vector3,
	-- the look
	pitch: number,
	pitchWant: number,
	-- the hands
	weaponId: string?,
	kind: string?,
	drawn: boolean,
	hold: WeaponPose.Hold?,
	holdOn: number,
	lantern: number,
	action: Action?,
	attack: number,
	bowSeq: number?,
	ownAt: number, -- when this client last drew its own move on this body (the server's echo is ignored for a moment)
	pull: number, -- how far the string is back, studs
	-- the ease from one pose to the next
	last: { [string]: CFrame },
	from: { [string]: CFrame }?,
	fromAt: number,
	fromFor: number,
}

local bodies: { [Model]: Body } = {}
local looks: { [number]: number } = {} -- by UserId: where a friend looks, radians up

local function moveToward(x: number, target: number, step: number): number
	if x < target then
		return math.min(target, x + step)
	end
	return math.max(target, x - step)
end

--[[
	WHAT YOU SEE OF YOUR OWN ARMS (2026-11-14, the developer: "the weapons must not get in the player's way; with the bow
	you cannot see well. Let the hands do the real pose, but on his own screen the bow should sit a little to the right
	and the target be clear."). Every client poses every body itself, so YOUR OWN client may draw your arms differently
	from what your friends' clients draw: in first person, with a weapon out, both arms are swung together about a point
	between the shoulders, down and to the right (VIEW_OFFSET, by weapon kind). The hold between the two hands is kept (they
	turn as one), the aim, the draw and every cut still play; only where they sit in your picture changes. Friends see the
	true pose. Faded in and out over VIEW_FADE.
]]
local VIEW_OFFSET: { [string]: { yaw: number, pitch: number } } = {
	bow = { yaw = -13, pitch = -7 },
	sword = { yaw = -11, pitch = -15 },
	spear = { yaw = -9, pitch = -11 },
}
local VIEW_FADE = 0.18
local VIEW_PIVOT = Vector3.new(0, 0.55, 0) -- the chest's space: between the shoulders
local viewWeight = 0

function viewOffset(body: any, pose: { [string]: CFrame }, dt: number): { [string]: CFrame }
	if not body.mine then
		return pose
	end
	local character = body.character
	local camera = Workspace.CurrentCamera
	local head = character:FindFirstChild("Head")
	local kind: string? = nil
	if camera and head and head:IsA("BasePart") and (camera.CFrame.Position - head.Position).Magnitude < 1.6 and character:GetAttribute("WeaponDrawn") == true then
		local id = character:GetAttribute("Weapon")
		local def = if typeof(id) == "string" then Config.get("Gear").Weapons[id] else nil
		kind = def and def.Kind or nil
	end
	local o = kind and VIEW_OFFSET[kind]
	viewWeight = math.clamp(viewWeight + (if o then 1 else -1) * dt / VIEW_FADE, 0, 1)
	if viewWeight <= 0 then
		return pose
	end
	o = o or body.viewLast or VIEW_OFFSET.sword
	body.viewLast = o
	local w = viewWeight * viewWeight * (3 - 2 * viewWeight)
	local q = CFrame.new(VIEW_PIVOT)
		* CFrame.fromAxisAngle(Vector3.yAxis, math.rad(o.yaw * w))
		* CFrame.fromAxisAngle(Vector3.xAxis, math.rad(o.pitch * w))
		* CFrame.new(-VIEW_PIVOT)
	local shown = table.clone(pose)
	for _, side in { "Right", "Left" } do
		local part = side .. "UpperArm"
		local a0 = body.rig.a0[part]
		if a0 then
			shown[part] = a0:Inverse() * q * a0 * (pose[part] or IDENTITY)
		end
	end
	return shown
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function onGround(body: Body): boolean
	local humanoid = body.humanoid
	if body.mine then
		return humanoid.FloorMaterial ~= Enum.Material.Air
	end
	local reach = humanoid.HipHeight + body.root.Size.Y / 2 + 0.9
	return Workspace:Raycast(body.root.Position, Vector3.new(0, -reach, 0), body.ray) ~= nil
end

-- Whatever was showing becomes the start of an ease into what comes next.
local function easeFromNow(body: Body, seconds: number)
	body.from = table.clone(body.last)
	body.fromAt = os.clock()
	body.fromFor = seconds
end

--==========================================================================
-- The feet
--==========================================================================
local function chooseState(body: Body, now: number, along: number, v: Vector3): string
	local humanoid = body.humanoid
	local state = if body.mine then humanoid:GetState() else nil
	if humanoid.Sit then
		body.airAt = nil
		return "sit"
	end
	if state == Enum.HumanoidStateType.Climbing then
		body.airAt = nil
		return "climb"
	end
	if state == Enum.HumanoidStateType.Swimming then
		body.airAt = nil
		return "move"
	end
	if not onGround(body) then
		if body.airAt == nil then
			body.airAt = now
			body.jumped = v.Y > 4
		end
		local airAt = body.airAt :: number
		if body.jumped and now - airAt < 0.55 and v.Y > -6 then
			return "jump"
		end
		if body.jumped or now - airAt > FALL_AFTER then
			return "fall"
		end
		return body.state -- a step down: stay in what it was doing
	end
	if body.airAt ~= nil then
		-- down again: how hard, for the eyes
		if now - (body.airAt :: number) > 0.25 then
			body.landed = math.max(body.landed, math.abs(v.Y), 8)
		end
		body.airAt = nil
		body.jumped = false
	end
	if along < IDLE_BELOW then
		return "idle"
	end
	return "move"
end

-- one family of the walk ("walk", "run", "duck") at the body's step, the way its feet go
local scratchA: { [string]: CFrame } = {}
local scratchB: { [string]: CFrame } = {}

local function gait(clips: { [string]: ClipPlayer.Clip }, family: string, body: Body, out: { [string]: CFrame })
	local forward = clips[if body.ahead >= 0 then family else family .. "Back"]
	local side = clips[family .. (if body.aside >= 0 then "Right" else "Left")]
	local wAhead, wAside = body.ahead * body.ahead, body.aside * body.aside
	local total = wAhead + wAside
	table.clear(out)
	if total < 1e-4 then
		ClipPlayer.sample(forward, body.phase * forward.length, out, 1)
		return
	end
	ClipPlayer.sample(forward, body.phase * forward.length, out, 1)
	if wAside > 1e-4 then
		ClipPlayer.sample(side, body.phase * side.length, out, wAside / total)
	end
end

-- lays pose `b` over pose `a` by `w` (every bone either of them moves)
local function mix(a: { [string]: CFrame }, b: { [string]: CFrame }, w: number)
	if w <= 0 then
		return
	end
	for bone, cf in b do
		a[bone] = if w >= 1 then cf else (a[bone] or IDENTITY):Lerp(cf, w)
	end
	if w < 1 then
		for bone, cf in a do
			if b[bone] == nil then
				a[bone] = cf:Lerp(IDENTITY, w)
			end
		end
	end
end

local function sampleState(body: Body, name: string, layer: Layer, clips: { [string]: ClipPlayer.Clip }, out: { [string]: CFrame })
	table.clear(out)
	if name == "move" then
		-- walk and run at the same step, then the ducked walk over them
		gait(clips, "walk", body, out)
		if body.run > 0.001 then
			gait(clips, "run", body, scratchB)
			mix(out, scratchB, body.run)
		end
		if body.duck > 0.001 then
			gait(clips, "duck", body, scratchB)
			mix(out, scratchB, body.duck)
		end
	elseif name == "idle" then
		ClipPlayer.sample(clips.idle, layer.time, out, 1)
		if body.duck > 0.001 then
			table.clear(scratchB)
			ClipPlayer.sample(clips.duckIdle, layer.time, scratchB, 1)
			mix(out, scratchB, body.duck)
		end
		-- turning on the spot: the feet shuffle round instead of sliding
		local shuffle = math.clamp((math.abs(body.turn) - 0.9) / 4, 0, 0.42)
		if shuffle > 0.01 then
			table.clear(scratchB)
			local walk = clips.walk
			ClipPlayer.sample(walk, body.phase * walk.length, scratchB, 1)
			for _, bone in { "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" } do
				local cf = scratchB[bone]
				if cf then
					out[bone] = (out[bone] or IDENTITY):Lerp(cf, shuffle)
				end
			end
		end
	else
		local clip = clips[name]
		if clip then
			ClipPlayer.sample(clip, layer.time, out, 1)
		end
	end
end

local function stepFeet(body: Body, dt: number, now: number, clips: { [string]: ClipPlayer.Clip }, pose: { [string]: CFrame })
	local humanoid = body.humanoid
	local v = body.root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local along = flat.Magnitude

	-- the way the feet go, in the body's own space, eased so a change of direction rolls through
	local wantAhead, wantAside = 1, 0
	if along > 1 then
		local own = body.root.CFrame:VectorToObjectSpace(flat / along)
		wantAhead, wantAside = -own.Z, own.X
	end
	local ease = math.min(1, dt * 10)
	body.ahead += (wantAhead - body.ahead) * ease
	body.aside += (wantAside - body.aside) * ease

	-- how fast the body turns (for the head's lead and the shuffle on the spot)
	local look = body.root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local dYaw = (yaw - body.yaw + math.pi) % (2 * math.pi) - math.pi
	body.yaw = yaw
	if dt > 1e-4 then
		body.turn += (math.clamp(dYaw / dt, -12, 12) - body.turn) * math.min(1, dt * 9)
	end

	local ducked = humanoid:GetAttribute("Crouching") == true
	body.duck = moveToward(body.duck, if ducked then 1 else 0, dt / 0.2)
	body.run = moveToward(body.run, if along > RUN_ABOVE and not ducked then 1 else 0, dt / 0.22)

	local want = chooseState(body, now, along, v)
	if want ~= body.state then
		local layer = body.layers[want]
		if not layer then
			layer = { time = 0, weight = 0 }
			body.layers[want] = layer
		end
		if want == "jump" then
			layer.time = 0
		end
		body.state = want
	end
	body.moving = moveToward(body.moving, if want == "move" then 1 else 0, dt / 0.2)

	-- the step: one stride of the walk is 0.76 s at 16 studs a second, of the run 0.6 at 24, ducked 0.92 at 8
	local walk, run, duck = clips.walk, clips.run, clips.duck
	local stride = walk.length + (run.length - walk.length) * body.run
	local pace = PlayerMoveAnims.WALK_PACE + (PlayerMoveAnims.RUN_PACE - PlayerMoveAnims.WALK_PACE) * body.run
	stride += (duck.length - stride) * body.duck
	pace += (PlayerMoveAnims.DUCK_PACE - pace) * body.duck
	local rate = if want == "move" then math.clamp(along / pace, 0.45, 1.4) else math.clamp(math.abs(body.turn) / 5, 0, 1)
	body.phase = (body.phase + dt * rate / math.max(stride, 0.1)) % 1

	local total = 0
	for name, layer in body.layers do
		local here = name == body.state
		layer.weight = moveToward(layer.weight, if here then 1 else 0, dt / FADE)
		local speed = 1
		if name == "climb" then
			speed = math.clamp(math.abs(v.Y) / 8, 0.2, 1.5)
		end
		layer.time += dt * speed
		if not here and layer.weight <= 0 then
			body.layers[name] = nil
		elseif layer.weight > 0 then
			sampleState(body, name, layer, clips, scratchA)
			total += layer.weight
			mix(pose, scratchA, layer.weight / total)
		end
	end
end

--==========================================================================
-- The hands
--==========================================================================
local function readWeapon(body: Body)
	local character = body.character
	local id = character:GetAttribute("Weapon")
	local drawn = character:GetAttribute("WeaponDrawn") == true
	local weaponId = if typeof(id) == "string" and gearCfg.Weapons[id] then id else nil
	if weaponId ~= body.weaponId then
		easeFromNow(body, 0.2)
		body.weaponId = weaponId
		body.action = nil
		body.holdOn = 0
		body.pull = 0
		local def = weaponId and gearCfg.Weapons[weaponId]
		body.kind = def and def.Kind
		body.hold = nil
	end
	if drawn ~= body.drawn then
		body.drawn = drawn
		if not drawn then
			body.action = nil
		end
	end
	-- what a two-handed weapon needs to know about the hands (made once the weapon is there)
	local def = body.weaponId and gearCfg.Weapons[body.weaponId]
	if def and body.hold == nil and PlayerActionAnims.KINDS[def.Kind] and PlayerActionAnims.KINDS[def.Kind].tracks then
		local g = def.Grip
		local grip = CFrame.new(g.x, g.y, g.z) * CFrame.Angles(math.rad(g.pitch), math.rad(g.yaw), math.rad(g.roll))
		body.hold = WeaponPose.hold(character, def.Kind, def.Hand, grip, def.String and def.String.Back, def.String and def.String.Draw)
	end
end

local function play(body: Body, name: string, rate: number, stay: boolean, after: string?)
	local clip = PlayerActionAnims.clip(name)
	local track = if clip then nil else PlayerActionAnims.track(name)
	if not (clip or track) then
		return
	end
	easeFromNow(body, EASE_IN)
	body.action = { name = name, clip = clip, track = track, start = os.clock(), rate = rate, stay = stay, after = after }
end

local function attackRate(body: Body, kind: any): number
	local def = body.weaponId and weaponsCfg[body.weaponId]
	local cooldown = (def and def.Cooldown) or kind.pace
	return math.clamp(kind.pace / math.max(cooldown, 0.2), 0.45, 1.6)
end

local function swing(body: Body)
	local kind = body.kind and PlayerActionAnims.KINDS[body.kind]
	if not (kind and kind.attacks) then
		return
	end
	body.attack = body.attack % #kind.attacks + 1
	play(body, kind.attacks[body.attack], attackRate(body, kind), false, nil)
	-- the blade's streak, for as long as the cut
	local model = body.weaponId and body.character:FindFirstChild("Weapon_" .. body.weaponId)
	local trail = model and model:FindFirstChild("Swing", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(0.42, function()
			if trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

local function bow(body: Body, state: string)
	local kind = body.kind and PlayerActionAnims.KINDS[body.kind]
	if not (kind and kind.draw) then
		return
	end
	local def = body.weaponId and weaponsCfg[body.weaponId]
	if state == "draw" then
		local seconds = (def and def.DrawSeconds) or kind.pace
		play(body, kind.draw, kind.pace / math.max(seconds, 0.2), true, kind.aim)
	elseif state == "loose" then
		play(body, kind.loose, 1, false, nil)
	elseif state == "lower" then
		if body.action and (body.action.name == kind.draw or body.action.name == kind.aim) then
			play(body, kind.lower, 1, false, nil)
		end
	end
end

local scratchValues: { [string]: any } = {}

local function stepHands(body: Body, dt: number, now: number, pose: { [string]: CFrame })
	readWeapon(body)
	local humanoid = body.humanoid

	-- what the server says was done (your own was drawn when you pressed)
	local bowSeq = humanoid:GetAttribute("BowSeq")
	if typeof(bowSeq) == "number" and bowSeq ~= body.bowSeq then
		local first = body.bowSeq == nil
		body.bowSeq = bowSeq
		local state = humanoid:GetAttribute("BowState")
		if not first and typeof(state) == "string" and not (body.mine and now - body.ownAt < 0.5 and state ~= "lower") then
			bow(body, state)
		end
	end

	-- the lantern in the hand (not on the belt, and not while both hands are on a weapon)
	local held = body.character:FindFirstChild("HeldLantern")
	local inHand = held ~= nil and held:GetAttribute("OnBelt") ~= true
	local def = body.weaponId and gearCfg.Weapons[body.weaponId]
	local twoHands = def ~= nil and def.TwoHanded == true and body.drawn
	body.lantern = moveToward(body.lantern, if inHand and not twoHands then 1 else 0, dt / 0.25)

	body.holdOn = moveToward(body.holdOn, if body.drawn and body.kind ~= nil then 1 else 0, dt / HOLD_FADE)
	local kind = body.kind and PlayerActionAnims.KINDS[body.kind]

	-- the one move being done: has it ended?
	local action = body.action
	local t = 0
	if action then
		t = (now - action.start) * action.rate
		local length = if action.clip then action.clip.length else (action.track :: PlayerActionAnims.Track).length
		if t >= length then
			if action.after then
				local nextTrack = PlayerActionAnims.track(action.after)
				body.action = if nextTrack then { name = action.after, track = nextTrack, start = now, rate = 1, stay = true } else nil
				action = body.action
				t = 0
			elseif action.stay or (action.track and action.track.looped) then
				-- held on its last key (or going round)
			else
				easeFromNow(body, EASE_IN)
				body.action = nil
				action = nil
			end
		end
	end

	-- a weapon moved by clips (the sword): its guard, then the cut over it
	if kind and kind.clips and body.holdOn > 0 then
		local hold = PlayerActionAnims.clip(kind.hold)
		if hold then
			ClipPlayer.sample(hold, now, pose, body.holdOn)
		end
		if action and action.clip then
			ClipPlayer.sample(action.clip, t, pose, body.holdOn)
		end
	end
	if body.lantern > 0 then
		local clip = PlayerActionAnims.clip("lantern_hold")
		if clip then
			ClipPlayer.sample(clip, now, pose, smooth(body.lantern))
		end
	end
end

-- after the look: the weapons that need both hands, and the lantern's level hand
local function stepTwoHands(body: Body, now: number, pose: { [string]: CFrame })
	local kind = body.kind and PlayerActionAnims.KINDS[body.kind]
	local hold = body.hold
	if kind and kind.tracks and hold and body.holdOn > 0 then
		local action = body.action
		local track = if action and action.track then action.track else PlayerActionAnims.track(kind.hold)
		if track then
			local t = if action and action.track then (now - action.start) * action.rate else now
			table.clear(scratchValues)
			PlayerActionAnims.sample(track, t, scratchValues)
			local weight = smooth(body.holdOn)
			if hold.kind == "bow" then
				body.pull = WeaponPose.bow(body.rig, pose, scratchValues, hold, body.pitch, weight)
			else
				WeaponPose.spear(body.rig, pose, scratchValues, hold, body.pitch, weight)
			end
		end
	else
		body.pull = 0
	end
	if body.lantern > 0 then
		ClipPlayer.level(body.rig, pose, "Left", nil, smooth(body.lantern))
	end
end

-- The bow's string and its nocked arrow follow the draw (they are the server's parts; this only moves them here).
local function stepString(body: Body)
	if body.kind ~= "bow" or not body.weaponId then
		return
	end
	local def = gearCfg.Weapons[body.weaponId]
	local model = body.character:FindFirstChild("Weapon_" .. body.weaponId)
	local hilt = model and model:FindFirstChild("Hilt")
	if not (def and def.String and hilt) then
		return
	end
	local back = def.String.Back + body.pull
	local nock = hilt:FindFirstChild("Nock")
	if nock and nock:IsA("Attachment") then
		nock.Position = Vector3.new(0, 0, back)
	end
	local joint = hilt:FindFirstChild("ArrowNock")
	if joint and joint:IsA("Motor6D") then
		joint.C0 = CFrame.new(0, 0, back) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- an arrow is on the string from the moment the hand is, until it is loosed
	local action = body.action
	local shown = body.drawn and action ~= nil and (action.name == "bow_draw" or action.name == "bow_aim") and (action.name == "bow_aim" or (os.clock() - action.start) * action.rate > 0.2)
	local arrow = model and model:FindFirstChild("Arrow")
	if arrow and arrow:GetAttribute("ShownHere") ~= shown then
		arrow:SetAttribute("ShownHere", shown)
		for _, d in arrow:GetChildren() do
			if d:IsA("BasePart") and d.Name ~= "Root" then
				d.Transparency = if shown then 0 else 1
			end
		end
	end
end

--==========================================================================
-- The look
--==========================================================================
local function stepLook(body: Body, dt: number, pose: { [string]: CFrame })
	local look = viewCfg.Look
	if body.mine then
		local camera = Workspace.CurrentCamera
		body.pitchWant = if camera and camera.CameraType == Enum.CameraType.Custom then math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)) else 0
	else
		body.pitchWant = looks[body.owner.UserId] or 0
	end
	-- your own arms follow the eyes at once (a weapon that lags the eyes swims); a friend's look is eased between the
	-- few it is sent a second
	local rate = if body.mine then 30 else look.Smooth
	body.pitch += (body.pitchWant - body.pitch) * math.min(1, dt * rate)
	local pitch = body.pitch
	if body.state == "sit" or body.state == "climb" then
		pitch *= 0.3
	end
	local lead = math.clamp(body.turn * look.LeadSeconds, -math.rad(look.LeadMax), math.rad(look.LeadMax))
	pose.UpperTorso = CFrame.Angles(pitch * look.Waist, 0, 0) * (pose.UpperTorso or IDENTITY)
	pose.Head = CFrame.Angles(pitch * look.Neck, lead, 0) * (pose.Head or IDENTITY)
	-- one hand on a weapon: the arm follows the look more than the chest does
	local kind = body.kind and PlayerActionAnims.KINDS[body.kind]
	if kind and kind.clips and body.holdOn > 0 then
		pose.RightUpperArm = CFrame.Angles(pitch * look.ArmShare * body.holdOn, 0, 0) * (pose.RightUpperArm or IDENTITY)
	end
	if body.lantern > 0 then
		pose.LeftUpperArm = CFrame.Angles(pitch * look.ArmShare * 0.8 * body.lantern, 0, 0) * (pose.LeftUpperArm or IDENTITY)
	end
end

--==========================================================================
-- One body, one frame
--==========================================================================
local function startRoll(body: Body, now: number, worldWay: Vector3?)
	body.rollAt = now
	body.rollRate = PlayerMoveAnims.ROLL_LENGTH / moveCfg.Roll.Seconds
	local way = worldWay
	if not way then
		local yaw = body.humanoid:GetAttribute("RollYaw")
		if typeof(yaw) == "number" then
			way = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		end
	end
	local own = if way then body.root.CFrame:VectorToObjectSpace(way) else Vector3.new(0, 0, -1)
	body.rollWay = Vector3.new(own.X, 0, own.Z)
	easeFromNow(body, 0.05)
end

local function stepBody(body: Body, dt: number, now: number, clips: { [string]: ClipPlayer.Clip })
	local humanoid = body.humanoid
	if humanoid.Health <= 0 or not body.root.Parent then
		return
	end
	-- a body at work is posed by WorkPoseController
	if body.character:GetAttribute("WorkPose") ~= nil then
		return
	end
	-- a body whose parts were changed (a new avatar description) has new joints; a body that was taken on before all of its
	-- joints had streamed in (a friend's, found in a two-player test 2026-11-13: the head never turned, the neck had not
	-- arrived) is looked at again until it is whole
	if now - body.checked > 0.5 then
		body.checked = now
		local alive = ClipPlayer.alive(body.rig)
		if not alive or not body.rig.complete then
			local rig = ClipPlayer.rig(body.character)
			if not rig then
				if not alive then
					return
				end
			elseif not alive or rig.count > body.rig.count then
				body.rig = rig
				body.hold = nil
			end
		end
	end

	-- a roll the server announced (your own is not drawn on your own body: see the header)
	local seq = humanoid:GetAttribute("RollSeq")
	if typeof(seq) == "number" and seq ~= body.rollSeq then
		local first = body.rollSeq == nil
		body.rollSeq = seq
		if not first and not body.mine then
			startRoll(body, now, nil)
		end
	end

	local pose: { [string]: CFrame } = {}
	stepFeet(body, dt, now, clips, pose)
	stepHands(body, dt, now, pose)
	stepLook(body, dt, pose)
	stepTwoHands(body, now, pose)

	local rollAt = body.rollAt
	if rollAt then
		local roll = clips.roll
		local t = (now - rollAt) * body.rollRate
		if t >= roll.length then
			body.rollAt = nil
			easeFromNow(body, 0.08)
		else
			local w = math.clamp(math.min(1, t / ROLL_IN, (roll.length - t) / ROLL_OUT), 0, 1)
			ClipPlayer.sample(roll, t, pose, w)
			local hips = PlayerMoveAnims.rollHips(t, body.rollWay)
			pose.LowerTorso = (pose.LowerTorso or IDENTITY):Lerp(hips, w)
		end
	end

	-- eased in from what was showing when the hands last changed what they do
	local from = body.from
	if from then
		local a = (now - body.fromAt) / body.fromFor
		if a >= 1 then
			body.from = nil
		else
			local s = smooth(math.clamp(a, 0, 1))
			for bone in body.rig.joints do
				local was = from[bone] or IDENTITY
				pose[bone] = was:Lerp(pose[bone] or IDENTITY, s)
			end
		end
	end

	ClipPlayer.write(body.rig, viewOffset(body, pose, dt), nil)
	body.last = pose
	stepString(body)
end

--==========================================================================
-- Taking a body on
--==========================================================================
local function adopt(target: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 15)
		local root = character:WaitForChild("HumanoidRootPart", 15)
		if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
			return
		end
		-- your own body: Roblox's own walk and idle stop, ours take over
		if target == player then
			local animate = character:WaitForChild("Animate", 5)
			if animate and animate:IsA("LocalScript") then
				animate.Enabled = false
			end
			task.defer(function()
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					for _, track in animator:GetPlayingAnimationTracks() do
						track:Stop(0.1)
					end
				end
			end)
		end
		-- the joints arrive with the body; a body that streams in late may need a moment
		local rig = ClipPlayer.rig(character)
		local tries = 0
		while (not rig or (not rig.complete and tries < 20)) and tries < 40 and character.Parent do
			task.wait(0.25)
			tries += 1
			rig = ClipPlayer.rig(character) or rig
		end
		if not rig or not character.Parent then
			return
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { character }
		ray.IgnoreWater = false
		local look = root.CFrame.LookVector
		bodies[character] = {
			character = character,
			humanoid = humanoid,
			root = root,
			rig = rig,
			owner = target,
			mine = target == player,
			checked = os.clock(),
			state = "idle",
			layers = { idle = { time = math.random() * 6, weight = 1 } },
			phase = 0,
			run = 0,
			duck = 0,
			ahead = 1,
			aside = 0,
			moving = 0,
			airAt = nil,
			jumped = false,
			landed = 0,
			ray = ray,
			yaw = math.atan2(-look.X, -look.Z),
			turn = 0,
			rollSeq = nil,
			rollAt = nil,
			rollRate = 1,
			rollWay = Vector3.new(0, 0, -1),
			pitch = 0,
			pitchWant = 0,
			weaponId = nil,
			kind = nil,
			drawn = false,
			hold = nil,
			holdOn = 0,
			lantern = 0,
			action = nil,
			attack = 0,
			bowSeq = nil,
			ownAt = -math.huge,
			pull = 0,
			last = {},
			from = nil,
			fromAt = 0,
			fromFor = 0.1,
		}
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				bodies[character] = nil
			end
		end)
	end)
end

local function watch(target: Player)
	target.CharacterAdded:Connect(function(character)
		adopt(target, character)
	end)
	if target.Character then
		adopt(target, target.Character)
	end
end

local function myBody(): Body?
	local character = player.Character
	return character and bodies[character]
end

--==========================================================================
-- For the controllers that take your keys
--==========================================================================

-- Your own cut or thrust, drawn the moment you press (Controllers/CombatController). The server's word of it is then
-- not drawn a second time.
function BodyAnimController.playLocalSwing()
	local body = myBody()
	if body and body.drawn then
		body.ownAt = os.clock()
		swing(body)
	end
end

-- Your own bow: "draw", "loose" or "lower".
function BodyAnimController.playLocalBow(state: string)
	local body = myBody()
	if body and body.drawn then
		body.ownAt = os.clock()
		bow(body, state)
	end
end

-- Is your own bow at (or nearly at) the full draw? (0..1 of the way.)
function BodyAnimController.localDraw(): number
	local body = myBody()
	if not body or body.kind ~= "bow" then
		return 0
	end
	local def = body.weaponId and gearCfg.Weapons[body.weaponId]
	local full = (def and def.String and def.String.Draw) or 1
	return math.clamp(body.pull / full, 0, 1)
end

--[[
	What the eyes need of your own walk (Controllers/ViewController): where the step is (0..1, two footfalls a stride),
	how much you are walking (0..1) and running (0..1), how much you go sideways (-1 left .. 1 right), and how hard you
	last landed (studs a second; handed over once, then zero).
]]
function BodyAnimController.localStep(): (number, number, number, number, number)
	local body = myBody()
	if not body then
		return 0, 0, 0, 0, 0
	end
	local landed = body.landed
	body.landed = 0
	return body.phase, body.moving, body.run, body.aside, landed
end

-- The weapon in your own hand ("sword", "spear", "bow") or nil, and whether it is out.
function BodyAnimController.localWeapon(): (string?, boolean)
	local body = myBody()
	if not body then
		return nil, false
	end
	return body.kind, body.drawn
end

--==========================================================================
function BodyAnimController.Init() end

function BodyAnimController.Start()
	moveCfg = Config.get("Movement")
	viewCfg = Config.get("View")
	gearCfg = Config.get("Gear")
	weaponsCfg = Config.get("Weapons")

	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		looks[p.UserId] = nil
	end)

	-- a swing, by anybody (your own was already drawn)
	Net.getEvent("CombatEvent").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or payload.kind ~= "MeleeSwing" then
			return
		end
		local userId = tonumber(string.match(tostring(payload.attackerId), "^player_(%-?%d+)$"))
		local who = userId and Players:GetPlayerByUserId(userId)
		local body = who and who.Character and bodies[who.Character]
		if not body then
			return
		end
		if body.mine and os.clock() - body.ownAt < 0.5 then
			return
		end
		swing(body)
	end)

	-- where a friend looks
	Net.getUnreliable("LookSync").OnClientEvent:Connect(function(userId: any, pitch: any)
		if typeof(userId) == "number" and typeof(pitch) == "number" and pitch == pitch then
			looks[userId] = math.rad(math.clamp(pitch, -85, 85))
		end
	end)

	-- the poses go on before the physics step: Roblox's upgraded joints only take a pose written there
	RunService.PreSimulation:Connect(function(dt: number)
		local now = os.clock()
		local clips = clipsFor(currentSet())
		for _, body in bodies do
			stepBody(body, dt, now, clips)
		end
	end)

	log:info(("ready: set %d (%s)"):format(currentSet(), PlayerMoveAnims.name(currentSet())))
end

return BodyAnimController
