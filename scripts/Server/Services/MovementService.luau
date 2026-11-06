--!strict
--[[
	MovementService
	Running on Shift with stamina, and the roll on Q (configs/Movement, rules in Shared/Stamina, docs/systems/Movement.md).

	The client only ASKS:
	  RequestRun  (boolean)  Shift held / let go
	  RequestRoll (Vector3)  the way to roll
	This service keeps each player's bar and decides:
	  * RUN. While Shift is held, the bar is not empty and the player is not crouched, the walking speed takes a claim
	    (x `Run.SpeedMult`); the bar drains only while the body actually moves. An emptied bar ends the run until Shift
	    is pressed again. The claim is the same handshake as the crouch's and the charms' (Domain/Crouch): the speed is
	    given back only if it is still the one this service wrote.
	  * ROLL. Allowed to a living player who is not crouched, not already rolling, with `Roll.Cost` in the bar; it spends
	    the cost and tells every client to draw the tumble (`RollSeq` and `RollYaw` on the Humanoid). The client moves its
	    own body (it owns its physics); the server only counts.

	Published: on the Player `Stamina` (seconds left, to the hundredth) and `StaminaMax`; on the Humanoid `Running` (the
	body is running now: every client draws the run) and `RollSeq` / `RollYaw`.

	Also: Roblox's own Shift lock is switched off for every player (`DevEnableMouseLock`): Shift runs. The mouse lock is
	ours (a switch in Settings, Client/Controllers/MovementController).

	Place: shared (both places: the lobby walks the same).
	Location: ServerScriptService.Server.Services.MovementService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Stamina = require(ReplicatedStorage.Shared.Stamina)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local MovementService = {}

MovementService.Name = "MovementService"

local log = Logger.new("MovementService")

type State = {
	bar: Stamina.State,
	shift: boolean, -- Shift is held
	running: boolean, -- the run claim is on
	base: number?, -- the walking speed before the run claim
	set: number?, -- the speed the run claim wrote
	humanoid: Humanoid?,
	rollUntil: number,
	rollSeq: number,
	shown: number, -- the last Stamina value published
	shownAt: number,
}

local states: { [Player]: State } = {}

local function cfg(): any
	return Config.get("Movement")
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = {
			bar = Stamina.new(cfg().Stamina),
			shift = false,
			running = false,
			base = nil,
			set = nil,
			humanoid = nil,
			rollUntil = 0,
			rollSeq = 0,
			shown = -1,
			shownAt = 0,
		}
		states[player] = s
	end
	return s
end

local function livingHumanoid(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- the run claim: take it (the current speed x the multiplier) / give it back (only if it is still ours)
local function claim(state: State, humanoid: Humanoid)
	if state.set ~= nil then
		return
	end
	state.base = humanoid.WalkSpeed
	state.set = humanoid.WalkSpeed * cfg().Run.SpeedMult
	humanoid.WalkSpeed = state.set :: number
end

local function release(state: State, humanoid: Humanoid?)
	local base, set = state.base, state.set
	state.base, state.set = nil, nil
	if humanoid and base and set and math.abs(humanoid.WalkSpeed - set) < 1e-3 then
		humanoid.WalkSpeed = base
	end
end

local function setRunning(state: State, humanoid: Humanoid?, on: boolean)
	if state.running == on then
		return
	end
	state.running = on
	if humanoid then
		if on then
			claim(state, humanoid)
		else
			release(state, humanoid)
		end
	end
end

local function publish(player: Player, state: State, now: number, force: boolean?)
	local value = math.floor(state.bar.value * 100 + 0.5) / 100
	-- ten times a second at most while it changes (the client eases the bar between), and always the moment it is empty or full
	if force or (value ~= state.shown and (now - state.shownAt >= 0.1 or value == 0 or value == cfg().Stamina.Max)) then
		state.shown = value
		state.shownAt = now
		player:SetAttribute("Stamina", value)
	end
end

-- Stops a run at once and gives the speed back (the crouch calls this before it takes its own share of the speed).
function MovementService.stopRun(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local humanoid = livingHumanoid(player)
	setRunning(state, humanoid or state.humanoid, false)
	if state.humanoid then
		state.humanoid:SetAttribute("Running", nil)
	end
end

local function onRun(player: Player, held: any)
	if typeof(held) ~= "boolean" then
		return
	end
	local state = stateOf(player)
	state.shift = held
	if not held then
		Stamina.release(state.bar)
	end
end

local function onRoll(player: Player, way: any)
	if typeof(way) ~= "Vector3" then
		return
	end
	local humanoid, root = livingHumanoid(player)
	if not (humanoid and root) then
		return
	end
	local c = cfg()
	local state = stateOf(player)
	local now = os.clock()
	if now < state.rollUntil + c.Roll.Gap * 0.5 then
		return -- still rolling (a little slack for the network)
	end
	if player:GetAttribute("Crouching") == true then
		return
	end
	local flat = Vector3.new(way.X, 0, way.Z)
	if flat.Magnitude ~= flat.Magnitude or flat.Magnitude < 0.05 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 0.05 then
		return
	end
	flat = flat.Unit
	if not Stamina.roll(state.bar, c.Roll.Cost, now) then
		return
	end
	state.rollUntil = now + c.Roll.Seconds
	state.rollSeq += 1
	humanoid:SetAttribute("RollYaw", math.atan2(-flat.X, -flat.Z))
	humanoid:SetAttribute("RollSeq", state.rollSeq)
	publish(player, state, now, true)
end

local function onCharacter(player: Player, character: Model)
	local state = stateOf(player)
	-- a new body: a full bar, standing, not running
	state.bar = Stamina.new(cfg().Stamina)
	state.running = false
	state.base, state.set = nil, nil
	state.rollUntil = 0
	state.humanoid = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		state.humanoid = humanoid
		humanoid:SetAttribute("RollSeq", state.rollSeq)
	end
	publish(player, state, os.clock(), true)
end

local function step(dt: number)
	local c = cfg()
	local now = os.clock()
	for player, state in states do
		local humanoid, root = livingHumanoid(player)
		if not (humanoid and root) then
			if state.running then
				setRunning(state, state.humanoid, false)
			end
			continue
		end
		state.humanoid = humanoid
		local v = root.AssemblyLinearVelocity
		local moving = Vector3.new(v.X, 0, v.Z).Magnitude > c.Stamina.MovingSpeed
		local rolling = now < state.rollUntil
		local allowed = state.shift and Stamina.canRun(state.bar) and player:GetAttribute("Crouching") ~= true
		-- the speed is on whenever the run is allowed (so the first steps are already fast); the bar drains only on the move
		setRunning(state, humanoid, allowed)
		local draining = allowed and moving and not rolling
		local still = Stamina.step(state.bar, c.Stamina, dt, now, draining)
		if draining and not still then
			setRunning(state, humanoid, false) -- the bar is empty
		end
		local shownRunning = state.running and moving
		if (humanoid:GetAttribute("Running") == true) ~= shownRunning then
			humanoid:SetAttribute("Running", if shownRunning then true else nil)
		end
		publish(player, state, now)
	end
end

function MovementService.Init() end

function MovementService.Start()
	local c = cfg()
	Net.getEvent("RequestRun").OnServerEvent:Connect(onRun)
	Net.getEvent("RequestRoll").OnServerEvent:Connect(onRoll)

	local function watch(player: Player)
		-- Shift runs: Roblox's own Shift lock is off (our mouse lock is a switch in Settings)
		player.DevEnableMouseLock = false
		player:SetAttribute("StaminaMax", c.Stamina.Max)
		stateOf(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
	log:info(("ready: %g s of running, a roll costs %g, full again in %g s"):format(c.Stamina.Max, c.Roll.Cost, c.Stamina.RefillSeconds))
end

return MovementService
