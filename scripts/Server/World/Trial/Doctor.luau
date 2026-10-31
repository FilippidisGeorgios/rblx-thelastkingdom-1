--!strict
--[[
	Trial.Doctor
	The big blind one of the Catacombs, in the world: it spawns him, listens for him, walks him and lets him strike.
	What he DECIDES is `Domain/DoctorBrain`; what can be heard is `Domain/Hearing` over the floor plan
	(`Domain/CatacombMaze`); this module is only the hands and the ears.

	EARS. Every 0.1 s each player on the plan makes a footstep noise (nothing if still, a few studs if crouched, `StepWalk`
	if walking, `StepRun` if running: `configs/Catacombs.Noise`), and anything else that is loud calls `handle.hear`. A
	noise reaches him only if the plan has an open way for it (walls and the shut gate stop it).

	LEGS. He does not use the dead's ordinary walker (it walks to what it sees, and he sees nothing, and it asks the
	pathfinder, which would send him through the crawls). He walks the plan's cells from centre to centre, by the shortest
	way that has no crawl in it, at the speed the brain asks for. Where he cannot go (a crawl, a shut gate) he gives up and
	listens.

	HANDS. A body within `AttackRange`, in his cell or the next one along an open way, is swung at: a windup of 0.9 s that a
	body can step out of, then the blow lands on whoever is still in reach.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent.Parent
local CatacombMaze = require(Server.Domain.CatacombMaze)
local Hearing = require(Server.Domain.Hearing)
local DoctorBrain = require(Server.Domain.DoctorBrain)
local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local Cue = require(script.Parent.Cue)
local Scaling = require(ReplicatedStorage.Shared.Scaling)

local Doctor = {}

local TICK = 0.1

-- How close (studs, across the floor) a leg must be to a cell's middle to count as having arrived
local ARRIVE = 0.7

-- The body turned part of the way to look along `toward`, standing at `at`.
local function turned(current: CFrame, toward: Vector3, at: Vector3, alpha: number): CFrame
	local want = CFrame.lookAt(Vector3.zero, toward)
	return CFrame.new(at) * (current - current.Position):Lerp(want, alpha)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

--[[
	ctx   the trial's context (note, warn, area)
	maze  Domain/CatacombMaze for this run
	cfg   configs/Catacombs
	plan  configs/CatacombsMaze
]]
function Doctor.create(ctx: any, maze: any, cfg: any, plan: any)
	local dcfg = cfg.Doctor
	local ncfg = cfg.Noise
	local floorY: number = cfg.Layout.FloorY

	local running = false
	local alive = false
	local id: string? = nil
	local model: Model? = nil
	local pivotAbove = 3
	local brain: any = nil
	local diedDisconnect: any = nil
	local seq = 0
	local visual = "Idle"
	local lastStomp = 0
	local lastRoar = -100
	local stepClock: { [Player]: number } = {}
	local lastState = "Prowl"

	local handle: any = {}

	local function setVisual(state: string, move: number)
		local m = model
		if not m then
			return
		end
		if state ~= visual then
			visual = state
			seq += 1
			m:SetAttribute("State", state)
			m:SetAttribute("Seq", seq)
		end
		m:SetAttribute("Move", move)
	end

	local function position(): Vector3?
		local m = model
		return if m then m:GetPivot().Position else nil
	end

	local function cellOfBody(): CatacombMaze.Cell?
		local p = position()
		return if p then maze:cellAt(p.X, p.Z) else nil
	end

	-- The living players who are down on the plan, with their cells.
	local function bodies(): { { player: Player, root: BasePart, humanoid: Humanoid, cell: CatacombMaze.Cell } }
		local out = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				if math.abs(root.Position.Y - floorY) < 14 then
					local cell = maze:cellAt(root.Position.X, root.Position.Z)
					if cell then
						table.insert(out, { player = player, root = root, humanoid = humanoid, cell = cell })
					end
				end
			end
		end
		return out
	end

	--======================================================================
	-- Ears
	--======================================================================
	-- Someone made a sound at `at` (world), `loudness` studs of passage loud.
	function handle.hear(at: Vector3, loudness: number, kind: string, source: string?)
		if not alive or not brain then
			return
		end
		local cell = maze:cellAt(at.X, at.Z)
		local mine = cellOfBody()
		if not cell or not mine then
			return
		end
		local noise: Hearing.Noise = { c = cell.c, r = cell.r, loudness = loudness, kind = kind, source = source, x = at.X, z = at.Z }
		if Hearing.hears(maze, noise, mine) then
			brain:hear(noise, os.clock())
		end
	end

	local function listenToFeet(now: number, list: { any })
		for _, b in list do
			local velocity = b.root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local crouching = b.player:GetAttribute("Crouching") == true
			local airborne = b.humanoid.FloorMaterial == Enum.Material.Air
			local loud = Hearing.footstep(ncfg, speed, crouching, airborne)
			if loud > 0 and now - (stepClock[b.player] or 0) >= ncfg.StepEvery then
				stepClock[b.player] = now
				handle.hear(b.root.Position, loud, "step", tostring(b.player.UserId))
			end
		end
	end

	--======================================================================
	-- Legs
	--======================================================================
	local function walkToward(here: CatacombMaze.Cell, goal: CatacombMaze.Cell, speed: number): boolean
		local m = model
		if not m then
			return false
		end
		local path = maze:path(here, goal, false)
		if path == nil then
			return false
		end
		if #path < 2 then
			return true
		end
		local pos = m:GetPivot().Position
		local cx, cz = maze:centre(here.c, here.r)
		local nx, nz = maze:centre(path[2].c, path[2].r)
		-- stay on the middle line of the passage: off it, go to the middle of this cell first
		local onLine
		if path[2].c ~= here.c then
			onLine = math.abs(pos.Z - cz) <= ARRIVE
		else
			onLine = math.abs(pos.X - cx) <= ARRIVE
		end
		local target = if onLine then Vector3.new(nx, pos.Y, nz) else Vector3.new(cx, pos.Y, cz)
		local delta = target - pos
		local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local step = math.min(speed * TICK, dist)
		if dist > 0.01 then
			local dir = Vector3.new(delta.X, 0, delta.Z).Unit
			m:PivotTo(turned(m:GetPivot(), dir, pos + dir * step, 0.35))
		end
		return true
	end

	local function face(toward: Vector3)
		local m = model
		if not m then
			return
		end
		local pos = m:GetPivot().Position
		local d = Vector3.new(toward.X - pos.X, 0, toward.Z - pos.Z)
		if d.Magnitude > 0.2 then
			m:PivotTo(turned(m:GetPivot(), d.Unit, pos, 0.3))
		end
	end

	--======================================================================
	-- The loop
	--======================================================================
	local function tick(dt: number)
		local m = model
		if not (m and alive and brain) then
			return
		end
		local now = os.clock()
		local list = bodies()
		listenToFeet(now, list)

		local here = cellOfBody()
		if not here then
			return
		end
		local pos = m:GetPivot().Position

		-- bodies he could strike: in reach, and in his cell or one open step along
		local near: { DoctorBrain.Body } = {}
		for _, b in list do
			local d = flat(b.root.Position, pos)
			local reach = maze:reach(here, b.cell, false)
			if d <= dcfg.AttackRange * 1.4 and reach ~= nil and reach <= maze.pitch then
				table.insert(near, { id = tostring(b.player.UserId), c = b.cell.c, r = b.cell.r, distance = d })
			end
		end

		local action = brain:update(dt, now, here, near)

		if action.state == "Chase" and lastState ~= "Chase" and now - lastRoar > 12 then
			lastRoar = now
			Cue.play(pos + Vector3.new(0, 3, 0), cfg.Sounds.Roar)
		end
		lastState = action.state

		if action.strike then
			for _, b in list do
				if tostring(b.player.UserId) == action.strike then
					-- the blow lands on a body that is still in reach: stepping back during the windup is the answer
					if flat(b.root.Position, pos) <= dcfg.AttackRange + 1.2 then
						local entity = if b.player.Character then CombatService.getEntityByInstance(b.player.Character) else nil
						if entity and id then
							CombatService.applyDamage({
								sourceId = id,
								targetId = entity.id,
								amount = dcfg.AttackDamage,
								damageType = "Physical",
							})
						end
					end
				end
			end
		end

		if action.state == "Windup" or action.state == "Strike" or action.state == "Recover" then
			for _, b in list do
				if tostring(b.player.UserId) == brain.target then
					face(b.root.Position)
				end
			end
			setVisual(action.state, 0)
		elseif action.walk then
			if walkToward(here, action.walk, action.speed) then
				setVisual(if action.speed >= 12 then "Run" else "Walk", action.speed)
				if now - lastStomp > 1.1 then
					lastStomp = now
					Cue.play(pos, cfg.Sounds.Stomp)
				end
			else
				-- no way there for him (a crawl, a shut gate): he stands and listens
				brain.goal = nil
				brain.state = "Search"
				brain.timer = dcfg.SearchSeconds
				setVisual("Idle", 0)
			end
		else
			setVisual("Idle", 0)
		end
	end

	--======================================================================
	-- Life
	--======================================================================

	-- Puts the Doctor on the plan at `cell` and lets him go. The stops of his round are the cells of the halls and a few
	-- of the corridors, picked from the plan.
	function handle.start(cell: CatacombMaze.Cell)
		if running then
			return
		end
		running = true
		local s = Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
		local x, z = maze:centre(cell.c, cell.r)
		local spawned = EnemyService.spawn("plague_doctor", Vector3.new(x, floorY, z), s.enemyHealthMult, floorY)
		local entity = CombatService.getEntity(spawned)
		if not (entity and entity.model) then
			ctx.warn("doctor: the body is not built (run tools/BuildDoctor.luau)")
			running = false
			return
		end
		id = spawned
		model = entity.model :: Model
		local m = model :: Model
		-- his feet on the floor, whatever his body's height
		local box, size = m:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		m:PivotTo(m:GetPivot() + Vector3.new(0, floorY - bottom, 0))
		pivotAbove = m:GetPivot().Position.Y - floorY
		m:SetAttribute("State", "Idle")
		m:SetAttribute("Seq", 0)
		m:SetAttribute("Move", 0)
		m:SetAttribute("Doctor", true)

		-- the round: the middle of each hall, and every sixth cell the walk reaches from here (without crawling)
		local stops: { CatacombMaze.Cell } = {}
		local dist = maze:spread(cell, false)
		for _, hall in plan.Halls do
			local c = math.floor((hall.c0 + hall.c1) / 2)
			local r = math.floor((hall.r0 + hall.r1) / 2)
			if dist[c .. "," .. r] ~= nil then
				table.insert(stops, { c = c, r = r })
			end
		end
		local extra = 0
		for k, steps in dist do
			if steps > 0 and steps % 11 == 0 and extra < dcfg.RoundStops then
				local c, r = string.match(k, "(-?%d+),(-?%d+)")
				table.insert(stops, { c = tonumber(c) :: number, r = tonumber(r) :: number })
				extra += 1
			end
		end

		brain = DoctorBrain.new(dcfg, ncfg, stops, maze.pitch)
		alive = true
		diedDisconnect = CombatService.EntityDied:connect(function(dead: any)
			if dead.id == id then
				alive = false
				running = false
				ctx.note("The Doctor falls. The passages are quiet, and then they are not.", 5)
			end
		end)

		task.spawn(function()
			while running do
				local ok, err = pcall(tick, TICK)
				if not ok then
					ctx.warn("doctor: " .. tostring(err))
				end
				task.wait(TICK)
			end
		end)
	end

	function handle.stop()
		running = false
		alive = false
		if diedDisconnect then
			diedDisconnect()
			diedDisconnect = nil
		end
		if id and model and model.Parent then
			EnemyService.despawn(id)
		end
		id = nil
		model = nil
	end

	function handle.isAlive(): boolean
		return alive
	end

	function handle.model(): Model?
		return model
	end

	function handle.brain(): any
		return brain
	end

	return handle
end

return Doctor
