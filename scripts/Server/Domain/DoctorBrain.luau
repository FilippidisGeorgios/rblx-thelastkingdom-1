--!strict
--[[
	DoctorBrain
	What the big blind one DECIDES, as a plain state machine: where to walk, how fast, when to swing. It does not move
	anything and does not see anything; the service tells it what it heard and where the bodies are, and walks the body
	where it says (Server/World/DoctorService).

	STATES
	  Prowl        walks the round of the plan, stopping at each stop to listen (`Listen`).
	  Investigate  has heard something: goes to where it was.
	  Chase        keeps hearing the same walking body close by: follows it, step by step.
	  Search       arrived and found nothing: stands and listens for `SearchSeconds`, then goes back to his round.
	  Windup, Strike, Recover   a swing at a body within reach.
	  (He never looks: a body in reach is struck whatever it is doing, because it breathes.)

	The loudest remembered noise wins (Domain/Hearing), a louder one pulls him off a quieter one, and his round is only what
	he does when there is nothing to hear.

	Place: both places (pure; Server/Domain).
]]

local Hearing = require(script.Parent.Hearing)

local DoctorBrain = {}
DoctorBrain.__index = DoctorBrain

export type Cell = { c: number, r: number }
export type Body = { id: string, c: number, r: number, distance: number } -- a living body and its straight distance in studs

export type Action = {
	state: string,
	walk: Cell?, -- the cell to walk toward (nil: stand)
	speed: number, -- studs a second
	strike: string?, -- the id of the body struck, on the one update where the blow lands
}

export type Brain = typeof(setmetatable(
	{} :: {
		cfg: any,
		noise: any,
		stops: { Cell },
		rng: () -> number,
		memory: Hearing.Memory,
		state: string,
		goal: Cell?,
		timer: number,
		target: string?,
		stopIndex: number,
		chaseSource: string?,
		fresh: boolean,
		pitch: number,
	},
	DoctorBrain
))

function DoctorBrain.new(cfg: any, noise: any, stops: { Cell }, pitch: number, rng: (() -> number)?): Brain
	return setmetatable({
		cfg = cfg,
		noise = noise,
		stops = stops,
		rng = rng or function()
			return math.random()
		end,
		memory = Hearing.newMemory(noise.Remember),
		state = "Prowl",
		goal = nil,
		timer = 0,
		target = nil,
		stopIndex = 0,
		chaseSource = nil,
		fresh = false,
		pitch = pitch,
	}, DoctorBrain)
end

-- The world says: this was heard (it has already been checked against the plan).
function DoctorBrain.hear(self: Brain, noise: Hearing.Noise, now: number)
	if Hearing.hear(self.memory, noise, now) then
		self.fresh = true
	end
end

local function same(a: Cell?, b: Cell): boolean
	return a ~= nil and a.c == b.c and a.r == b.r
end

function DoctorBrain.nextStop(self: Brain): Cell?
	if #self.stops == 0 then
		return nil
	end
	-- not the one he is at: a random one of the others (no loop to wait on, so any generator of numbers will do)
	local n = #self.stops
	local pick = 1
	if n > 1 then
		pick = 1 + math.min(n - 2, math.floor(self.rng() * (n - 1)))
		if self.stopIndex > 0 and pick >= self.stopIndex then
			pick += 1
		end
	end
	self.stopIndex = pick
	return self.stops[pick]
end

local function nearest(bodies: { Body }): Body?
	local best: Body? = nil
	for _, b in bodies do
		if best == nil or b.distance < best.distance then
			best = b
		end
	end
	return best
end

function DoctorBrain.update(self: Brain, dt: number, now: number, here: Cell, bodies: { Body }): Action
	local cfg = self.cfg

	-- a swing in progress runs to its end
	if self.state == "Windup" or self.state == "Strike" or self.state == "Recover" then
		self.timer -= dt
		if self.state == "Windup" and self.timer <= 0 then
			self.state = "Strike"
			self.timer = cfg.Strike
			local victim = self.target
			return { state = "Strike", walk = nil, speed = 0, strike = victim }
		elseif self.state == "Strike" and self.timer <= 0 then
			self.state = "Recover"
			self.timer = cfg.Recover
		elseif self.state == "Recover" and self.timer <= 0 then
			self.state = "Search"
			self.timer = cfg.SearchSeconds
			self.goal = nil
		end
		return { state = self.state, walk = nil, speed = 0 }
	end

	-- a body in reach is struck
	local close = nearest(bodies)
	if close and close.distance <= cfg.AttackRange then
		self.state = "Windup"
		self.timer = cfg.Windup
		self.target = close.id
		return { state = "Windup", walk = nil, speed = 0 }
	end

	-- something heard
	if self.fresh then
		self.fresh = false
		local noise = Hearing.recall(self.memory, now)
		if noise then
			self.goal = { c = noise.c, r = noise.r }
			local nearSteps = math.abs(noise.c - here.c) + math.abs(noise.r - here.r)
			if noise.kind == "step" and nearSteps <= cfg.ChaseCells then
				self.state = "Chase"
				self.chaseSource = noise.source
			else
				self.state = "Investigate"
				self.chaseSource = nil
			end
		end
	end

	if self.state == "Chase" or self.state == "Investigate" then
		local goal = self.goal
		if goal == nil or same(goal, here) then
			self.state = "Search"
			self.timer = cfg.SearchSeconds
			self.goal = nil
			Hearing.forgetAll(self.memory)
			return { state = "Search", walk = nil, speed = 0 }
		end
		local speed = if self.state == "Chase" then cfg.Speeds.Chase else cfg.Speeds.Investigate
		return { state = self.state, walk = goal, speed = speed }
	end

	if self.state == "Search" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "Prowl"
			self.goal = nil
		end
		return { state = "Search", walk = nil, speed = 0 }
	end

	if self.state == "Listen" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "Prowl"
			self.goal = nil
		end
		return { state = "Listen", walk = nil, speed = 0 }
	end

	-- Prowl: walk the round
	if self.goal == nil then
		self.goal = self:nextStop()
		if self.goal == nil then
			return { state = "Prowl", walk = nil, speed = 0 }
		end
	end
	local goal = self.goal :: Cell
	if same(goal, here) then
		self.state = "Listen"
		self.timer = cfg.ListenSeconds
		self.goal = nil
		return { state = "Listen", walk = nil, speed = 0 }
	end
	return { state = "Prowl", walk = goal, speed = cfg.Speeds.Prowl }
end

return DoctorBrain
