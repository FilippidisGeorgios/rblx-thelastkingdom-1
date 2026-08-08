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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WeaponAnimController = {}

WeaponAnimController.Name = "WeaponAnimController"

local log = Logger.new("WeaponAnimController")

--==========================================================================
--[[
	The carrying stance.

	Big on purpose. The last version used sixteen degrees and it was invisible
	next to an idle animation that holds the arm at the side — a pose has to
	beat what it is composed with or it may as well not be there. Forty-five
	degrees out and forward reads instantly as "this person is holding a sword".
]]
local READY = CFrame.Angles(math.rad(-46), math.rad(-14), math.rad(-24))

--[[
	Three arcs, taken in turn, so a run of hits is a fight rather than a
	button. Backhand across the body, forehand back across it, overhead chop.
]]
local SWINGS = {
	{ wind = CFrame.Angles(math.rad(-24), math.rad(-78), math.rad(-30)), strike = CFrame.Angles(math.rad(-96), math.rad(56), math.rad(18)) },
	{ wind = CFrame.Angles(math.rad(-50), math.rad(72), math.rad(26)), strike = CFrame.Angles(math.rad(-80), math.rad(-58), math.rad(-24)) },
	{ wind = CFrame.Angles(math.rad(-158), math.rad(-16), math.rad(-8)), strike = CFrame.Angles(math.rad(-34), math.rad(8), math.rad(6)) },
}

local T_WIND = 0.13
local T_STRIKE = 0.12
local T_RECOVER = 0.24
local T_TOTAL = T_WIND + T_STRIKE + T_RECOVER

-- How fast the arm eases between stances when the weapon is drawn or put away.
local SETTLE = 6

--==========================================================================
type State = {
	armed: boolean,
	swingAt: number?, -- os.clock() when the current swing started
	arc: number,
	blend: CFrame, -- what the arm is actually showing, chased toward the target
}

local states: { [Player]: State } = {}

local function stateFor(player: Player): State
	local existing = states[player]
	if existing then
		return existing
	end
	local created: State = { armed = false, swingAt = nil, arc = 0, blend = CFrame.new() }
	states[player] = created
	return created
end

--==========================================================================
-- R15 keeps the shoulder inside RightUpperArm; R6 keeps it in Torso under a
-- name with a space in it.
local function rightShoulder(character: Model): Motor6D?
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "RightShoulder" or d.Name == "Right Shoulder") then
			return d
		end
	end
	return nil
end

--==========================================================================
--[[
	The offset this character's arm should be showing right now.

	One function, no coroutines, no tweens, no tokens. The pose is a pure
	function of the clock and the state, which means a swing interrupted by a
	respawn, a death or a second swing cannot leave an arm stuck anywhere — the
	next frame simply asks again.
]]
local function targetPose(state: State): CFrame
	local base = if state.armed then READY else CFrame.new()

	local startedAt = state.swingAt
	if not startedAt then
		return base
	end

	local t = os.clock() - startedAt
	if t >= T_TOTAL then
		state.swingAt = nil
		return base
	end

	local arc = SWINGS[state.arc] or SWINGS[1]

	if t < T_WIND then
		-- Back, decelerating into the top of the wind-up.
		local a = t / T_WIND
		return base:Lerp(base * arc.wind, 1 - (1 - a) ^ 3)
	elseif t < T_WIND + T_STRIKE then
		-- Through, accelerating. This is the fast part and it has to look it.
		local a = (t - T_WIND) / T_STRIKE
		return (base * arc.wind):Lerp(base * arc.strike, a * a)
	end

	-- And back on guard, so the next swing starts where this one finished.
	local a = (t - T_WIND - T_STRIKE) / T_RECOVER
	return (base * arc.strike):Lerp(base, 1 - (1 - a) ^ 3)
end

--==========================================================================
local function update(dt: number)
	for player, state in states do
		local character = player.Character
		if character then
			local joint = rightShoulder(character)
			if joint then
				--[[
					Chased rather than snapped. Drawing a sword is a movement,
					and an arm that teleports into a guard is the single most
					obvious tell that a game is unfinished. During a swing the
					chase is instant, because a swing IS the movement.
				]]
				local want = targetPose(state)
				local rate = if state.swingAt then 1 else math.min(dt * SETTLE, 1)
				state.blend = state.blend:Lerp(want, rate)

				--[[
					Transform, not C0, and AFTER the animator.

					This binding runs at Character + 1, so the animator has
					already written this frame's idle or walk into Transform.
					Multiplying on top of it keeps the character breathing and
					walking while the arm does something else — and, unlike C0,
					it is not something the idle can out-vote.
				]]
				joint.Transform = joint.Transform * state.blend
			end
		end
	end
end

--==========================================================================
function WeaponAnimController.Init() end

function WeaponAnimController.Start()
	--------------------------------------------------------------------------
	-- Who is holding what
	--------------------------------------------------------------------------
	Net.getEvent("WeaponState").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local player = Players:GetPlayerByUserId(payload.userId)
		if player then
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
		state.arc = (state.arc % #SWINGS) + 1
		state.swingAt = os.clock()
	end)

	--------------------------------------------------------------------------
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

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
