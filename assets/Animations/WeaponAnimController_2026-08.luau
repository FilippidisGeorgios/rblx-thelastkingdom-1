--!strict
--[[
	WeaponAnimController
	Poses the sword arm — on the client, after the animator, every frame.

	--------------------------------------------------------------------------
	WHY THIS IS NOT ON THE SERVER

	It was, and it did nothing at all, and the reason is worth writing down.

	A character's joints are driven by TWO things. `Motor6D.C0` is a property
	you set and it replicates. `Motor6D.Transform` is the animation channel, and
	Roblox's Animator overwrites it on the CLIENT, every single frame, from
	whatever idle or walk track is playing.

	The final pose is `C0 * Transform * C1:Inverse()`. Writing C0 from the
	server therefore composes with the idle rather than replacing it — and the
	R15 idle holds the arm firmly at the character's side, so a modest offset
	pushed into C0 is a modest nudge to an arm the idle is holding down. Which
	is exactly what it looked like: no animation.

	So the pose is applied HERE, on the client, from a RenderStep binding that
	runs at `Character + 1` — after the animator has written Transform for the
	frame, so this gets the last word.

	--------------------------------------------------------------------------
	IT POSES EVERYBODY, NOT JUST YOU

	The server broadcasts who is holding what (`WeaponState`) and every swing
	(`CombatEvent`), so each client can pose every character it can see. Client
	joint writes do not replicate, but they do not need to: every client is
	running this and reaching the same answer from the same two messages.

	Place: client. Phase: Combat.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WeaponAnimController = {}

WeaponAnimController.Name = "WeaponAnimController"

local log = Logger.new("WeaponAnimController")

--==========================================================================
--[[
	The blade's own arc, in the same phases as the clips it rides on.

	These are not free choices — they are the keyframe times out of SwordAnims,
	averaged across the two cuts: cocked and holding until ~0.21, through the
	target by ~0.31, back on guard at ~0.74. A wrist that peaks half a beat
	after the arm does is worse than a wrist that does not move at all, so when
	those change, these change with them.

	T_WIND runs to the END of the hold rather than the start of it. The arc has
	to be sitting still while the arm is sitting still, or the one frame that
	makes the strike look fast is the one frame with a rotating sword in it.
]]
local T_WIND = 0.21
local T_STRIKE = 0.1
local T_RECOVER = 0.43
local T_TOTAL = T_WIND + T_STRIKE + T_RECOVER

--==========================================================================
type State = {
	armed: boolean,
	swingAt: number?, -- os.clock() when the current swing started
	arc: number,
	animated: boolean, -- did a real swing clip play? then the wrist stays quiet
}

local states: { [Player]: State } = {}

local function stateFor(player: Player): State
	local existing = states[player]
	if existing then
		return existing
	end
	local created: State = { armed = false, swingAt = nil, arc = 0, animated = false }
	states[player] = created
	return created
end

--==========================================================================
--[[
	THE ARM IS MOVED BY THE ANIMATOR, BECAUSE NOTHING ELSE CAN MOVE IT.

	Four attempts went into turning the shoulder joint by hand and every one of
	them failed on this avatar, for a reason that is now clear:

	  Motor6D.C0                     — no body Motor6Ds on this rig at all
	  Motor6D.Transform              — same, nothing to write to
	  AnimationConstraint seat       — written, replicated, moved nothing
	  AnimationConstraint.Transform  — written with no error, moved nothing

	The last one is the tell. The write succeeds, so the property is real and
	writable; the arm still does not move, so something reads it after we do.
	AnimationConstraint is solved by the PHYSICS engine, and the animator feeds
	it inside that step — our render-step value is already stale by the time the
	solve happens. There is no ordering trick that wins this reliably.

	So the arm is moved the way the engine intends: by playing an AnimationTrack
	through the character's own Animator. That path works on every rig, present
	and future, because it IS the rig system rather than an argument with it.

	WHERE THE ANIMATIONS COME FROM

	`Shared/Anim/SwordAnims` — written for this game, not borrowed.

	Roblox's classic-sword clips came first. They loaded and ran and were the
	wrong animation: the lunge kicked a leg out from under the character. Ours
	are two cuts that draw an X, one-handed, with NO leg and NO left arm keyed
	at any point — so the legs go on walking underneath an attack and the free
	arm swings along with them.

	The ids are registered per session, on each client. Every client already
	poses every character it can see from the same broadcasts, so all of them
	reach the same picture from their own copies.
]]
local SwordAnims = require(ReplicatedStorage.Shared.Anim.SwordAnims)

local ids: SwordAnims.Ids? = nil

type Rig = {
	hold: AnimationTrack?,
	swings: { AnimationTrack },
}

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	-- Parented, not destroyed after loading. The clip resolves asynchronously
	-- and the track needs its Animation to still be there when it does; it goes
	-- with the character when the character goes.
	animation.Parent = animator

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		return track
	end
	animation:Destroy()
	return nil
end

local function rigFor(character: Model): Rig?
	local cached = rigs[character]
	if cached then
		return cached
	end

	local registered = ids
	if not registered then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local built: Rig = { hold = nil, swings = {} }

	local hold = loadTrack(animator, registered.hold)
	if hold then
		hold.Looped = true
		--[[
			Movement, not Idle. The idle track is already holding both arms at
			the character's side; a guard at the same priority is a coin toss and
			this one has to win. No leg is keyed, so outranking the walk costs
			nothing below the waist.
		]]
		hold.Priority = Enum.AnimationPriority.Movement
		built.hold = hold
	end

	for _, id in registered.swings do
		local track = loadTrack(animator, id)
		if track then
			track.Priority = Enum.AnimationPriority.Action
			table.insert(built.swings, track)
		end
	end

	rigs[character] = built
	log:info(("%s: %s guard, %d of %d cuts"):format(
		character.Name,
		if built.hold then "loaded" else "NO",
		#built.swings,
		#registered.swings
	))
	return built
end

--==========================================================================
--[[
	THE BLADE MOVES EVEN WHEN THE ARM CANNOT.

	The sword hangs off `WeaponGrip`, a Motor6D this game creates itself, so
	turning that joint sweeps the blade on ANY rig — including the one upstairs
	that defeated four attempts to pose its shoulder by hand. It was the whole
	animation for a while and it is now the safety net: if a swing clip fails to
	load, the weapon still moves and the attack still reads.
]]

--[[
	The weapon's own joint, and the pose it was welded at.

	The server sets this C0 when the sword is drawn or put away and never
	touches it otherwise, so caching the value it left is safe — and the cache
	is dropped whenever the drawn state changes, which is the only time the
	server writes it.
]]
type Weapon = { motor: Motor6D, rest: CFrame }

local weapons: { [Model]: Weapon } = setmetatable({}, { __mode = "k" }) :: any

local function weaponJoint(character: Model): Weapon?
	local cached = weapons[character]
	if cached and cached.motor.Parent then
		return cached
	end

	local motor = character:FindFirstChild("WeaponGrip", true)
	if not motor or not motor:IsA("Motor6D") then
		return nil
	end
	local found: Weapon = { motor = motor, rest = motor.C0 }
	weapons[character] = found
	return found
end

--==========================================================================
--[[
	How far the BLADE itself travels through a swing, on top of the arm.

	Two entries, one per cut, mirrored — the wrist rolls the edge one way on the
	cut from the right and the other way on the cut from the left.

	This was once the entire animation, because for a long time it was the only
	thing on this rig that could be moved at all. It is now a layer on top of a
	real one: the sword hangs off a Motor6D this game made, so turning it adds
	blade travel that no keyframe has to pay for, and it still carries the whole
	attack on its own if a clip ever fails to load.
]]
local BLADE_SWINGS = {
	{ wind = CFrame.Angles(math.rad(46), math.rad(-34), 0), strike = CFrame.Angles(math.rad(-64), math.rad(62), 0) },
	{ wind = CFrame.Angles(math.rad(40), math.rad(38), 0), strike = CFrame.Angles(math.rad(-58), math.rad(-66), 0) },
}

local lastWarn = 0

--[[
	Where a swing is in its arc, as a pure function of the clock.

	Returns the offset and nothing else — no coroutines, no tokens, no state to
	get stuck. A swing interrupted by a respawn or by the next swing simply
	stops being asked about.
]]
local function arcAt(state: State, set: { { wind: CFrame, strike: CFrame } }): CFrame?
	local startedAt = state.swingAt
	if not startedAt then
		return nil
	end
	local t = os.clock() - startedAt
	if t >= T_TOTAL then
		return nil
	end

	local arc = set[state.arc] or set[1]

	if t < T_WIND then
		--[[
			Cubed, so the wind-up is finished well before T_WIND is.

			At a = 0.7 this is already 97% of the way there, which leaves the
			last third of the phase as a wrist that has stopped — matching the
			hold in the clip. That stillness is what the strike explodes out of.
		]]
		local a = t / T_WIND
		return CFrame.new():Lerp(arc.wind, 1 - (1 - a) ^ 3)
	elseif t < T_WIND + T_STRIKE then
		local a = (t - T_WIND) / T_STRIKE
		return arc.wind:Lerp(arc.strike, a * a)
	end
	local a = (t - T_WIND - T_STRIKE) / T_RECOVER
	return arc.strike:Lerp(CFrame.new(), 1 - (1 - a) ^ 3)
end

--==========================================================================
--[[
	SWORD TUNING MODES — Studio only. F2 the sheathed sword, F3 the held one.

	Three separate times I shipped an angle for the sheathed sword, was told it
	was wrong, changed it, and was told it was wrong again. I cannot see the
	avatar and he cannot send a picture, so describing a rotation in words is
	the slowest possible way to agree on one. He turns it himself instead — and
	the first time he did, it took one attempt.

	F3 exists for the same reason and was added before it was needed. The guard
	pose swings the arm right round from where it used to hang, which moves the
	blade with it; rather than guess the new grip and wait to be told it is
	wrong, he can just turn it.

	Press either and the movement keys stop moving the character and start
	moving the sword — every axis, both directions. P prints the six numbers.
	The same key again gives the keyboard back.

	This has to live here rather than in tools/, because the pose is written
	from this render step every frame: anything a command-bar script set would
	be overwritten before he saw it.

	Each table below MUST match its constant in WeaponVisualService, or the
	sword will jump the moment the mode opens and he will be tuning from the
	wrong starting point.
]]
local TUNE_DEG_RATE = 55 -- degrees per second held
local TUNE_POS_RATE = 0.8 -- studs per second held
local TUNE_FAST = 3 -- multiplier while Shift is down

type Tune = { x: number, y: number, z: number, pitch: number, yaw: number, roll: number }

local tuning: string? = nil -- "sheath" | "grip" | nil
local tunes: { [string]: Tune } = {
	sheath = { x = 0.65, y = 0.15, z = -1.54, pitch = 79, yaw = -87, roll = -13 }, -- SHEATH_TUNE
	grip = { x = 0, y = -0.55, z = 0, pitch = -50, yaw = 90, roll = 0 }, -- GRIP
}
local TUNE_LABEL = { sheath = "SHEATH_TUNE", grip = "GRIP_TUNE" }

local function tunedCFrame(which: string): CFrame
	local t = tunes[which]
	return CFrame.new(t.x, t.y, t.z) * CFrame.Angles(math.rad(t.pitch), math.rad(t.yaw), math.rad(t.roll))
end

--[[
	The held sword hangs off the hand's grip attachment, not off the hand.

	The server composes `RightGripAttachment.CFrame * GRIP`, so the preview has
	to compose the same thing or the numbers he sends back will be right here
	and wrong there.
]]
local function tunedGrip(character: Model): CFrame?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return nil
	end
	local gripAt = hand:FindFirstChild("RightGripAttachment")
	local base = if gripAt and gripAt:IsA("Attachment") then gripAt.CFrame else CFrame.new(0, -0.9, 0)
	return base * tunedCFrame("grip")
end

-- Which key pushes which field, and which way.
local TUNE_KEYS: { { key: Enum.KeyCode, field: string, sign: number, angle: boolean } } = {
	{ key = Enum.KeyCode.Up, field = "pitch", sign = 1, angle = true },
	{ key = Enum.KeyCode.Down, field = "pitch", sign = -1, angle = true },
	{ key = Enum.KeyCode.Left, field = "yaw", sign = 1, angle = true },
	{ key = Enum.KeyCode.Right, field = "yaw", sign = -1, angle = true },
	{ key = Enum.KeyCode.Q, field = "roll", sign = 1, angle = true },
	{ key = Enum.KeyCode.E, field = "roll", sign = -1, angle = true },
	{ key = Enum.KeyCode.D, field = "x", sign = 1, angle = false },
	{ key = Enum.KeyCode.A, field = "x", sign = -1, angle = false },
	{ key = Enum.KeyCode.W, field = "y", sign = 1, angle = false },
	{ key = Enum.KeyCode.S, field = "y", sign = -1, angle = false },
	{ key = Enum.KeyCode.R, field = "z", sign = 1, angle = false },
	{ key = Enum.KeyCode.F, field = "z", sign = -1, angle = false },
}

local function printTune(which: string)
	local t = tunes[which]
	log:info(("%s = { x = %.2f, y = %.2f, z = %.2f, pitch = %d, yaw = %d, roll = %d }"):format(
		TUNE_LABEL[which],
		t.x,
		t.y,
		t.z,
		math.floor(t.pitch + 0.5),
		math.floor(t.yaw + 0.5),
		math.floor(t.roll + 0.5)
	))
end

local function stepTune(dt: number)
	local which = tuning
	if not which then
		return
	end
	local t = tunes[which]
	local fast = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then TUNE_FAST else 1
	for _, binding in TUNE_KEYS do
		if UserInputService:IsKeyDown(binding.key) then
			local rate = if binding.angle then TUNE_DEG_RATE else TUNE_POS_RATE
			t[binding.field] += binding.sign * rate * fast * dt
		end
	end
end

local function setTuning(which: string?)
	if tuning == which then
		return
	end

	local previous = tuning
	tuning = which

	if previous then
		ContextActionService:UnbindAction("SwordTune")
		--[[
			Put back what the server sent, right now — before the next render
			step, which would otherwise adopt the tuned pose as the resting one
			and keep it for the rest of the round.
		]]
		for character, weapon in weapons do
			if character.Parent and weapon.motor.Parent then
				weapon.motor.C0 = weapon.rest
			end
		end
		printTune(previous)
		log:info(("%s tuning OFF"):format(previous))
	end

	if not which then
		return
	end

	local keys: { Enum.KeyCode } = { Enum.KeyCode.P }
	for _, binding in TUNE_KEYS do
		table.insert(keys, binding.key)
	end

	--[[
		Sunk, all of them. Otherwise WASD walks the character across the map
		while he is trying to look at the sword, and the arrow keys do the same.
		That is what makes this a mode rather than a set of hotkeys.
	]]
	ContextActionService:BindAction("SwordTune", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.P then
			printTune(which)
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(keys))

	log:info(("%s tuning ON — arrows lean/turn, Q/E roll, WASD+R/F move, Shift faster, P prints"):format(which))
	printTune(which)
end

--==========================================================================
local function update(dt: number)
	stepTune(dt)

	for player, state in states do
		local character = player.Character
		if character then
			--------------------------------------------------------------
			-- The blade. Always.
			--------------------------------------------------------------
			local weapon = weaponJoint(character)
			if weapon then
				--[[
					The wrist eases off when a real clip is playing.

					At full size on top of an animated arm it reads as two
					swings at once. At a third it reads as what it is — the
					blade travelling a little further than the hand that holds
					it, which is exactly what a sword does. With no clip loaded
					it goes back to full, where it is the whole attack again.
				]]
				local arc = arcAt(state, BLADE_SWINGS)
				if arc and state.animated then
					arc = CFrame.new():Lerp(arc, 0.33)
				end

				--[[
					A tuned pose replaces the server's only while that mode is
					open, and only for the state it describes: F2 shows nothing
					on a drawn sword and F3 nothing on a sheathed one, because a
					preview of a pose you cannot see is just a sword in the
					wrong place. `rest` is deliberately not refreshed on those
					frames, so closing the mode puts back exactly what the
					server sent.
				]]
				local preview: CFrame? = nil
				if tuning == "sheath" and not state.armed then
					preview = tunedCFrame("sheath")
				elseif tuning == "grip" and state.armed then
					preview = tunedGrip(character)
				end

				if preview then
					weapon.motor.C0 = preview
				elseif arc then
					weapon.motor.C0 = weapon.rest * arc
				else
					--[[
						NOT SWINGING: the joint is left exactly as the server
						left it, and that pose becomes the one the next swing
						starts from.

						Re-reading it here rather than caching it once removes a
						race that would otherwise be very hard to see: the
						server writes C0 and fires WeaponState in the same
						frame, and if the cache were dropped on the event but
						the property had not landed yet, the sword would swing
						from — and settle back to — the wrong pose.
					]]
					weapon.rest = weapon.motor.C0
				end
			end

			--------------------------------------------------------------
			-- The arm: the carry pose, held for exactly as long as the
			-- sword is out. Swings are fired on the event, not here.
			--------------------------------------------------------------
			local rig = rigFor(character)
			local hold = rig and rig.hold
			if hold then
				if state.armed and not hold.IsPlaying then
					hold:Play(0.25)
				elseif not state.armed and hold.IsPlaying then
					hold:Stop(0.25)
				end
			elseif os.clock() - lastWarn > 10 then
				lastWarn = os.clock()
				log:warn(("no carry pose for %s — swinging the blade only"):format(player.Name))
			end
		end
	end
end

--==========================================================================
function WeaponAnimController.Init() end

function WeaponAnimController.Start()
	--------------------------------------------------------------------------
	-- The animations, once, before anyone can need them
	--------------------------------------------------------------------------
	local registered, reason = SwordAnims.register()
	ids = registered
	if registered then
		log:info(("registered %d cuts and a guard"):format(#registered.swings))
	else
		--[[
			Not fatal. The blade still swings on its own joint, which is a real
			attack and was the whole animation for a while — but say so loudly,
			because the difference is the arms and it has to be diagnosable from
			the log alone.
		]]
		log:warn(("could not register the sword animations (%s) — blade only"):format(tostring(reason)))
	end

	--------------------------------------------------------------------------
	-- Who is holding what
	--------------------------------------------------------------------------
	Net.getEvent("WeaponState").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local player = Players:GetPlayerByUserId(payload.userId)
		if player then
			--[[
				Nothing else to do. The resting pose is re-read from the joint
				every frame the sword is not mid-swing, so the move from hand to
				leg is picked up on its own — no cache to invalidate, and no
				race with the C0 the server wrote alongside this message.
			]]
			stateFor(player).armed = payload.drawn == true
		end
	end)

	--------------------------------------------------------------------------
	-- Every swing, by anyone
	--------------------------------------------------------------------------
	Net.getEvent("CombatEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.kind ~= "MeleeSwing" then
			return
		end

		-- Entity ids are "player_<UserId>"; anything else swung at us, not by a
		-- player, and has no arm here to pose.
		local id = tostring(payload.attackerId)
		local userId = tonumber(string.match(id, "^player_(%d+)$"))
		if not userId then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return
		end

		local state = stateFor(player)
		state.swingAt = os.clock()
		state.animated = false

		--[[
			Fired here rather than polled in the render step, because a swing is
			an EVENT. Restarting the track from zero on every hit is deliberate:
			a second swing during the first has to cut it off, not queue behind
			it, or a fast fight desynchronises from what the server counted.

			Right cut then left cut, alternating — so a run of hits draws an X
			rather than the same swing twice.
		]]
		local character = player.Character
		local rig = character and rigFor(character)
		local count = if rig then #rig.swings else 0
		state.arc = if count > 0 then (state.arc % count) + 1 else (state.arc % #BLADE_SWINGS) + 1

		if rig and count > 0 then
			local track = rig.swings[state.arc]
			track:Stop(0)
			track:Play(0.05)
			state.animated = true
		end

		if player == Players.LocalPlayer then
			log:info(("attack %d%s"):format(state.arc, if state.animated then "" else " (blade only)"))
		end
	end)

	--------------------------------------------------------------------------
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	--------------------------------------------------------------------------
	-- F2 the sheathed sword, F3 the held one. Studio only: a workbench, not a
	-- feature — a live game must never let a key move somebody's weapon.
	--------------------------------------------------------------------------
	if RunService:IsStudio() then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			-- Each key toggles its own mode, and opening one closes the other.
			if input.KeyCode == Enum.KeyCode.F2 then
				setTuning(if tuning == "sheath" then nil else "sheath")
			elseif input.KeyCode == Enum.KeyCode.F3 then
				setTuning(if tuning == "grip" then nil else "grip")
			end
		end)
	end

	--[[
		Character + 1. The order is the whole reason this works: the animator
		writes Transform during the Character step, and this runs immediately
		after it, so the arm pose is the last thing applied before the frame is
		drawn.
	]]
	RunService:BindToRenderStep("WeaponArms", Enum.RenderPriority.Character.Value + 1, update)

	log:info("ready")
end

return WeaponAnimController
