--!strict
--[[
	Stamina (shared, pure)
	The rules of the stamina bar (configs/Movement.Stamina, docs/systems/Movement.md). Pure: a state, the time, what the
	player is doing in, the new state out. The server keeps the real bar with it; the client draws the bar the server
	publishes and asks no more of this than whether a roll is worth asking for.

	THE BAR is counted in seconds of running: `Max` (6) on a full bar.
	  * Running (Shift held while moving) takes one second of bar per second.
	  * A roll takes `Cost` (1.5) at once, and only when the bar holds that much.
	  * The bar fills again `RefillDelay` (1 s) after the last run or roll, at Max / RefillSeconds a second (empty to
	    full in 15 s).
	  * When running empties the bar, the run stops and stays stopped until Shift is pressed AGAIN (`spent`).

	Location: ReplicatedStorage.Shared.Stamina
]]

local Stamina = {}

export type Config = { Max: number, RefillSeconds: number, RefillDelay: number }

export type State = {
	value: number, -- seconds of running left
	lastUse: number, -- when the bar was last spent (os.clock()); -inf for never
	spent: boolean, -- the run emptied the bar: no running until Shift is let go and pressed again
}

function Stamina.new(cfg: Config): State
	return { value = cfg.Max, lastUse = -math.huge, spent = false }
end

-- May this player run right now (Shift is held)? Not on an empty bar, and not after the run emptied it until Shift is pressed again.
function Stamina.canRun(state: State): boolean
	return state.value > 0 and not state.spent
end

--[[
	Shift was let go: an emptied run may start again on the next press.
]]
function Stamina.release(state: State)
	state.spent = false
end

--[[
	Moves the bar on by `dt` seconds. `running` = Shift held, moving, and allowed (canRun). Returns whether the run is
	still on after this step (false when this step emptied the bar).
]]
function Stamina.step(state: State, cfg: Config, dt: number, now: number, running: boolean): boolean
	if dt <= 0 then
		return running
	end
	if running and Stamina.canRun(state) then
		state.value = math.max(0, state.value - dt)
		state.lastUse = now
		if state.value <= 0 then
			state.spent = true
			return false
		end
		return true
	end
	if now - state.lastUse >= cfg.RefillDelay and state.value < cfg.Max then
		-- the part of this step that falls after the delay is what fills
		local since = math.min(dt, now - state.lastUse - cfg.RefillDelay)
		state.value = math.min(cfg.Max, state.value + since * cfg.Max / cfg.RefillSeconds)
	end
	return false
end

-- Is there enough in the bar for a roll?
function Stamina.canRoll(state: State, cost: number): boolean
	return state.value >= cost - 1e-6
end

-- Spends a roll. Returns false (and spends nothing) when the bar holds less than `cost`.
function Stamina.roll(state: State, cost: number, now: number): boolean
	if not Stamina.canRoll(state, cost) then
		return false
	end
	state.value = math.max(0, state.value - cost)
	state.lastUse = now
	return true
end

return Stamina
