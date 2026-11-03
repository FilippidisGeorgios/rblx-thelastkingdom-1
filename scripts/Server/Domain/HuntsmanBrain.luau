--!strict
--[[
	HuntsmanBrain
	What the Huntsman of the King's Wood SEES and DECIDES (docs/systems/Forest.md), as plain rules and a state machine. It
	moves nothing and casts no rays: the world (Server/World/Trial/Huntsman) tells it which lights it can see along a clear
	line and which bodies are within reach, and walks the body where it says.

	WHAT HE SEES (`sees`). Light, nothing else. An open lantern far off (`See.Open`), a covered one only close (`See.Covered`,
	less if the bearer crouches), a body with no lantern only close (`See.Dark`); outside his sight to either side (`HalfAngle`)
	only what is at his back (`See.Behind`). A light must be on a clear line from his eyes (the world checks it), and a light
	inside a burning watch-fire's glow is not seen at all: the fire drowns it.

	STATES
	  Round    walks from stop to stop of his round, and stands a while at each (`Pause`).
	  Alert    has just seen a light: stops, faces it, lifts his head and blows the horn (`horn` is true once).
	  Hunt     goes to the light, as long as he sees it; `LoseAfter` seconds without it and he goes to where it was last.
	  Seek     on his way to where it was last seen (a light seen on the way turns it back into a hunt, without a horn).
	  Search   stands where it was last seen, turning, for `SearchSeconds`; then back to his round.
	  Windup, Strike, Recover   a swing at a body in reach.
	  Driven   hurt enough: goes away to the far end of his round for `DriveSeconds`, and sees nothing on the way.

	Place: both places (pure; Server/Domain).
]]

local HuntsmanBrain = {}
HuntsmanBrain.__index = HuntsmanBrain

export type Light = {
	at: Vector3, -- where the light is
	lantern: boolean, -- the bearer carries a lantern at all
	open: boolean, -- and it is open
	crouched: boolean,
	clear: boolean, -- a clear line from his eyes to it (the world's ray)
	inGlow: boolean, -- it stands inside a burning watch-fire's glow
}
export type Sighting = { id: string, at: Vector3 }
export type Body = { id: string, distance: number }
export type Action = {
	state: string,
	goal: Vector3?, -- where to walk (nil: stand)
	speed: number,
	face: Vector3?, -- where to look while standing
	horn: boolean?, -- blow the horn now
	strike: string?, -- the body struck, on the one update where the blow lands
}

local ARRIVE = 3.5 -- studs: near enough to a goal to have arrived
local TOUCH = 3 -- anything this close is noticed, whatever the line

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[
	Whether he sees `light`, standing with his eyes at `eye` and looking along `look`. Pure: the clear line and the glow come
	in on the light.
]]
function HuntsmanBrain.sees(cfg: any, eye: Vector3, look: Vector3, light: Light): boolean
	local see = cfg.See
	if light.inGlow then
		return false
	end
	local offset = light.at - eye
	-- measured along the ground: his eyes are high and a lantern hangs at the hip, and "8 studs from him" means from his feet
	local distance = flat(offset).Magnitude
	if distance <= TOUCH then
		return true
	end
	if not light.clear then
		return false
	end
	local reach
	if not light.lantern then
		reach = see.Dark
	elseif light.open then
		reach = see.Open
	elseif light.crouched then
		reach = see.CoveredCrouched
	else
		reach = see.Covered
	end
	local f, l = flat(offset), flat(look)
	if f.Magnitude > 0.01 and l.Magnitude > 0.01 then
		local angle = math.deg(math.acos(math.clamp(f.Unit:Dot(l.Unit), -1, 1)))
		if angle > see.HalfAngle then
			reach = math.min(reach, see.Behind)
		end
	end
	return distance <= reach
end

export type Brain = typeof(setmetatable(
	{} :: {
		cfg: any,
		stops: { Vector3 },
		rng: () -> number,
		state: string,
		goal: Vector3?,
		timer: number,
		target: string?,
		lastSeen: number,
		lastSpot: Vector3?,
		lastHorn: number,
		stopIndex: number,
	},
	HuntsmanBrain
))

function HuntsmanBrain.new(cfg: any, stops: { Vector3 }, rng: (() -> number)?): Brain
	return setmetatable({
		cfg = cfg,
		stops = stops,
		rng = rng or function()
			return math.random()
		end,
		state = "Round",
		goal = nil,
		timer = 0,
		target = nil,
		lastSeen = -math.huge,
		lastSpot = nil,
		lastHorn = -math.huge,
		stopIndex = 0,
	}, HuntsmanBrain)
end

-- A stop of his round other than the one he is at (no loop to wait on: any generator of numbers will do).
function HuntsmanBrain.nextStop(self: Brain): Vector3?
	local n = #self.stops
	if n == 0 then
		return nil
	end
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

-- The stop of his round farthest from `here` (where he goes when he is driven off).
function HuntsmanBrain.farthestStop(self: Brain, here: Vector3): Vector3?
	local best, bestD = nil, -1
	for i, stop in self.stops do
		local d = flat(stop - here).Magnitude
		if d > bestD then
			best, bestD = stop, d
			self.stopIndex = i
		end
	end
	return best
end

-- He has been hurt enough: he goes back into the dark.
function HuntsmanBrain.drive(self: Brain, here: Vector3)
	if self.state == "Driven" then
		return
	end
	self.state = "Driven"
	self.timer = self.cfg.DriveSeconds
	self.goal = self:farthestStop(here)
	self.target = nil
end

local function nearestSighting(here: Vector3, sightings: { Sighting }, prefer: string?): Sighting?
	local best: Sighting? = nil
	local bestD = math.huge
	for _, s in sightings do
		if prefer and s.id == prefer then
			return s
		end
		local d = flat(s.at - here).Magnitude
		if d < bestD then
			best, bestD = s, d
		end
	end
	return best
end

local function nearestBody(bodies: { Body }): Body?
	local best: Body? = nil
	for _, b in bodies do
		if best == nil or b.distance < best.distance then
			best = b
		end
	end
	return best
end

local function arrived(here: Vector3, goal: Vector3?): boolean
	return goal ~= nil and flat(goal - here).Magnitude <= ARRIVE
end

function HuntsmanBrain.update(self: Brain, dt: number, now: number, here: Vector3, sightings: { Sighting }, bodies: { Body }): Action
	local cfg = self.cfg

	-- a swing in progress runs to its end
	if self.state == "Windup" or self.state == "Strike" or self.state == "Recover" then
		self.timer -= dt
		if self.state == "Windup" and self.timer <= 0 then
			self.state = "Strike"
			self.timer = cfg.Strike
			return { state = "Strike", speed = 0, strike = self.target }
		elseif self.state == "Strike" and self.timer <= 0 then
			self.state = "Recover"
			self.timer = cfg.Recover
		elseif self.state == "Recover" and self.timer <= 0 then
			-- back to the hunt if the light is still there, else he looks about
			self.state = "Search"
			self.timer = cfg.SearchSeconds
			self.goal = nil
		end
		return { state = self.state, speed = 0 }
	end

	-- driven off: away, blind to everything, until the time is up
	if self.state == "Driven" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "Round"
			self.goal = nil
		elseif self.goal and not arrived(here, self.goal) then
			return { state = "Driven", goal = self.goal, speed = cfg.Speeds.Hunt }
		else
			return { state = "Driven", speed = 0 }
		end
	end

	-- a body in reach is struck
	local close = nearestBody(bodies)
	if close and close.distance <= cfg.AttackRange then
		self.state = "Windup"
		self.timer = cfg.Windup
		self.target = close.id
		return { state = "Windup", speed = 0 }
	end

	local seen = nearestSighting(here, sightings, self.target)
	if seen then
		self.lastSeen = now
		self.lastSpot = seen.at
	end

	-- on his way to where a light was, he sees one: the hunt is on again (he has blown his horn already)
	if seen and self.state == "Seek" then
		self.state = "Hunt"
	end

	-- a light seen while he is not already hunting: he stops and blows the horn
	if seen and (self.state == "Round" or self.state == "Pause" or self.state == "Search") then
		self.state = "Alert"
		self.timer = cfg.AlertSeconds
		self.target = seen.id
		local horn = now - self.lastHorn >= cfg.HornEvery
		if horn then
			self.lastHorn = now
		end
		return { state = "Alert", speed = 0, face = seen.at, horn = horn }
	end

	if self.state == "Alert" then
		self.timer -= dt
		if self.timer > 0 then
			return { state = "Alert", speed = 0, face = self.lastSpot }
		end
		self.state = "Hunt"
	end

	if self.state == "Hunt" then
		if seen then
			self.target = seen.id
			self.goal = seen.at
		elseif now - self.lastSeen >= cfg.See.LoseAfter then
			-- lost it: to where it was last, then look about there
			self.goal = self.lastSpot
			self.state = "Seek"
		end
		if self.state == "Hunt" then
			if arrived(here, self.goal) then
				return { state = "Hunt", speed = 0, face = self.goal }
			end
			return { state = "Hunt", goal = self.goal, speed = cfg.Speeds.Hunt }
		end
	end

	if self.state == "Seek" then
		if self.goal == nil or arrived(here, self.goal) then
			self.state = "Search"
			self.timer = cfg.SearchSeconds
			self.goal = nil
			self.target = nil
			return { state = "Search", speed = 0 }
		end
		return { state = "Seek", goal = self.goal, speed = cfg.Speeds.Search }
	end

	if self.state == "Search" then
		self.timer -= dt
		if self.timer <= 0 then
			self.state = "Round"
			self.goal = nil
			self.target = nil
		else
			return { state = "Search", speed = 0 }
		end
	end

	if self.state == "Pause" then
		self.timer -= dt
		if self.timer > 0 then
			return { state = "Pause", speed = 0 }
		end
		self.state = "Round"
		self.goal = nil
	end

	-- Round: walk to the next stop, stand there a while
	if self.goal == nil then
		self.goal = self:nextStop()
		if self.goal == nil then
			return { state = "Round", speed = 0 }
		end
	end
	if arrived(here, self.goal) then
		self.state = "Pause"
		self.timer = cfg.RoundPause
		self.goal = nil
		return { state = "Pause", speed = 0 }
	end
	return { state = "Round", goal = self.goal, speed = cfg.Speeds.Round }
end

return HuntsmanBrain
