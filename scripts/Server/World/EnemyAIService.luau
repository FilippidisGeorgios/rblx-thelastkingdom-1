--!strict
--[[
	EnemyAIService
	Drives enemy AI in the Forgotten Lands. Per tick, for each attached enemy it:
	  1. perceives — finds the nearest alive hostile via CombatService,
	  2. decides  — asks the enemy's EnemyBrain for the next state,
	  3. actuates — walks toward it AROUND the buildings, or attacks THROUGH the
	     existing CombatService.

	It never contains its own combat maths: enemy attacks go through
	CombatService.applyDamage exactly like the player's melee does. Ranges,
	speed and cooldown come from configs/Enemies (the enemy's `AI` block);
	nothing here is hard-coded.

	--------------------------------------------------------------------------
	THEY USED TO WALK THROUGH HOUSES

	Movement was a straight line: take the direction to the target and PivotTo
	along it. Kinematic, deterministic, and completely blind — the dead came
	through walls, through the stables, and out of the side of a building into
	your face. That is not a difficulty problem, it is a legibility one: if
	nothing in the world stops a zombie then no fence, no house and no layout
	means anything, and the whole map is decoration.

	So movement is now in three layers, cheapest first:

	  1. LINE OF SIGHT. One raycast. If the way to the target is clear — which
	     it is most of the time, in a courtyard — walk straight at it and
	     compute nothing.

	  2. A PATH. When the line is blocked, ask PathfindingService for a route
	     and follow its waypoints. Recomputed about once a second per agent and
	     rate-limited across all of them, because thirty agents each pathing
	     every frame is a stall, not an AI.

	  3. A HARD STOP. Every step, whatever produced it, is raycast before it is
	     taken. If something solid is in the way the step is not taken. This is
	     the layer that makes the guarantee absolute: a path can be stale and a
	     line of sight can be wrong, but nothing gets to move into a wall.

	Other characters are ignored by both raycasts — the dead crowd, and a unit
	that refuses to step because another unit is in front of it is a unit that
	stands in a doorway forever.

	Place: Forgotten Lands ONLY (Server/World). Phase: Enemy AI.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local ProjectileService = require(script.Parent.ProjectileService)
local CombatEntity = require(Server.Domain.Combat.CombatEntity)
local EnemyBrain = require(Server.Domain.AI.EnemyBrain)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyAIService = {}

EnemyAIService.Name = "EnemyAIService"

local log = Logger.new("EnemyAIService")

-- Studs above the rig's pivot that a shot leaves from. Firing from the pivot
-- puts the arrow at knee height, where the ground eats it at any distance.
local MUZZLE_HEIGHT = 2.5

--==========================================================================
-- Walking around things
--==========================================================================

-- How wide and tall the pathfinder should assume a body is. Slightly generous:
-- a route that scrapes a doorway looks like clipping even when it is legal.
-- 1.0 (2 across, a rig's root) since the buildings became enterable: at 2.4,
-- and even at 1.6, the pathfinder judged every 4-stud door and stair
-- impassable (it rounds clearance up), so a player in a loft was unreachable.
-- Measured with tools/BuildWards: at 1.0 all 32 doors, stairs and decks in
-- chambers 1-3 route; at 1.6 almost none did.
local AGENT_RADIUS = 1.0
local AGENT_HEIGHT = 6

-- How often one agent re-asks for a route, and how far its target may drift
-- before it asks early. A second is imperceptible on something walking at 7
-- studs a second and is the difference between an AI and a stall.
local REPATH_SECONDS = 0.9
local GOAL_DRIFT = 10

-- Globally, per frame. Thirty agents will not all recompute together.
local MAX_COMPUTES_PER_FRAME = 3

-- Close enough to a waypoint to start walking to the next one. Was 4; on a
-- 4-wide flight that cut the corner at the foot, the body met the ramp from the
-- side (too high to step onto) and stood there. 2 keeps it in line.
local WAYPOINT_RADIUS = 2

-- The step-blocking ray leaves from chest height, not the pivot: a ray along
-- the floor catches every kerb, doorstep and flagstone in the castle and would
-- have the dead refuse to walk down the road.
local PROBE_HEIGHT = 1.6

--[[
	FOLLOWING THE FLOOR

	Movement used to be flat: a body kept the height it spawned at forever. In
	a yard that is invisible, but it made every roof, loft and stair a place the
	dead could never reach — stand on a hayloft and you were safe, which is the
	opposite of the game. So every step now finds the floor under where it lands:
	up a riser or a ramp of at most STEP_UP, down any drop of at most MAX_DROP
	(the dead do not mind jumping off a roof). No floor within that — the edge
	of the moat — and the step is refused like a wall.

	PIVOT_ABOVE_FLOOR is where EnemyService stands a rig: its root is RIG_HEIGHT
	(5) tall and pivoted at its centre.
]]
local STEP_UP = 2.2
local MAX_DROP = 40
local PIVOT_ABOVE_FLOOR = 2.5

-- Further apart than this vertically, the target is on another level (a roof,
-- a loft): walking straight at it ends underneath it, so take a route instead.
local LEVEL_GAP = 6

--[[
	AN ATTACK IS A THING THAT HAPPENS OVER TIME

	It used to be instant: the cooldown ran out and the damage landed that same
	frame, so the only defence was not being near. Now an attack is
	windup -> strike -> recover (docs/systems/Bestiary.md §7). The windup is what
	the player sees and answers: the body stops, faces you, and for the first
	part of it keeps turning to you; it then LOCKS, and the damage lands at the
	strike on whatever is still in front of it and within reach. Step out and it
	hits air. The numbers are in each enemy's AI block (Windup, Strike, Recover);
	absent means instant, as before.

	Every state is also written onto the model (State, Seq, Move) so each client
	can play the matching clip: nothing is streamed per frame.
]]
local STRIKE_LEEWAY = 2.5 -- studs past AttackRange that a strike can still reach
local STRIKE_CONE = math.cos(math.rad(75)) -- the target must be this far in front
local FACE_LOCK = 0.65 -- fraction of the windup after which it stops turning
local AGGRO_SECONDS = 0.9 -- the first time it sees you it stops and cries out
local RUN_SPEED = 12 -- at or above this a moving body plays Run, not Walk
local FOLLOW_GAP = 9 -- how close a follower comes to the player it follows
--[[
	A follower left far behind (stuck on a ledge, shut out by a door that closed,
	just slow) is put back beside the party after a while, out of sight. Every
	companion game does this, because a companion that is lost is worse than
	one that pops: the cured and the prisoner are only worth having if they are
	WITH you. Only when far enough that nobody is looking at them.
]]
local FOLLOW_TELEPORT_DIST = 80
local FOLLOW_TELEPORT_AFTER = 9
local FOLLOW_STUCK_AFTER = 6 -- seconds of wanting to walk and not moving, with nothing to fight

--[[
	What a ranged unit fires. Straight off the enemy def's `Ranged` block; nil
	for everything that has to swing.
]]
type RangedProfile = {
	projectile: string,
	speed: number,
	damage: number,
	damageType: string,
	spread: number,
	leadFactor: number,
	maxRange: number,
}

type Agent = {
	brain: EnemyBrain.EnemyBrain,
	spawnPosition: Vector3,
	params: EnemyBrain.Params,
	moveSpeed: number,
	attackCooldown: number,
	attackDamage: number,
	attackDamageType: string,
	lastAttack: number,

	-- The attack in progress, if any: windup -> strike -> recover.
	windup: number,
	strike: number,
	recover: number,
	phase: string?,
	phaseEnd: number,
	faceUntil: number,
	aggroDone: boolean, -- has it already noticed the player this time round
	aggroUntil: number,
	visual: string, -- the State last written to the model
	seq: number,

	-- Ranged units only.
	ranged: RangedProfile?,
	-- Inside this the unit uses its MELEE attack even though it has a bow.
	-- Only The King has both; nil means "whatever it has, it always uses".
	meleeRange: number?,
	follow: boolean, -- with nothing to fight, walk to the nearest player (the cured)
	farTime: number, -- seconds a follower has been further than FOLLOW_TELEPORT_DIST
	stuckSeconds: number,
	followCheckAt: number,
	followCheckPos: Vector3?,

	-- Last known position of its target, so the shot can lead a moving one.
	-- Velocity is derived here rather than read off a Humanoid, because the
	-- player rig and the enemy rigs report it differently and one of them
	-- reports nothing at all.
	lastTargetPos: Vector3?,
	targetVelocity: Vector3,

	-- Routing. `waypoints` is empty whenever the agent is walking on line of
	-- sight, which is most of the time.
	waypoints: { Vector3 },
	waypointIndex: number,
	pathGoal: Vector3?, -- what the current route was computed toward
	repathAt: number, -- os.clock() when it may ask again
	computing: boolean, -- a ComputeAsync is in flight for this agent
}

local agents: { [string]: Agent } = {} -- keyed by enemy entity id

local function positionOf(model: Instance): Vector3
	if model:IsA("Model") then
		return model:GetPivot().Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return Vector3.new(0, 0, 0)
end

--[[
	Nearest living HOSTILE entity to `pos`, with its distance.

	Hostility is "not my faction" rather than "is a player", because the cured
	villagers from the kitchens fight on the Players side and the undead have
	to be willing to attack them. Hard-coding the Players faction here would
	have the dead walk straight past the allies to reach you.
]]
local function nearestHostile(pos: Vector3, myFaction: string): (CombatEntity.CombatEntity?, number?)
	local best: CombatEntity.CombatEntity? = nil
	local bestDist: number? = nil
	for _, entity in CombatService.getAllEntities() do
		local hostile = entity.faction ~= myFaction and entity.faction ~= Enums.Faction.Neutral
		if hostile and entity:isAlive() and entity.model then
			local d = (positionOf(entity.model) - pos).Magnitude
			if bestDist == nil or d < bestDist then
				best = entity
				bestDist = d
			end
		end
	end
	return best, bestDist
end

--[[
	Where to walk to reach `model` — usually the model itself. A barricade is the
	exception: it is a wall, so a unit that tried to walk to its middle would be
	walking into it and its route would never exist. Such a model carries two
	attributes, `ApproachA` and `ApproachB`, the standing places on either side of
	it, and a unit goes to whichever is nearer to it. It is what lets the dead
	besiege a door (docs/systems/Trials.md §5, chamber 6) instead of standing at
	a distance from it forever.
]]
local function approachPoint(model: Instance, from: Vector3): Vector3
	local a = model:GetAttribute("ApproachA")
	local b = model:GetAttribute("ApproachB")
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
		return if (a - from).Magnitude <= (b - from).Magnitude then a else b
	end
	return positionOf(model)
end

--==========================================================================
-- Seeing
--==========================================================================

--[[
	Is `hit` a body rather than the world?

	Characters are ignored by every ray in this file. The dead arrive in
	crowds, and a unit that will not take a step because another unit is in
	front of it is a unit that stands in a doorway for the rest of the run.
]]
local function isCharacter(instance: BasePart): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

--[[
	Casts from `from` to `to` at chest height and reports what is in the way,
	ignoring `me` and anything with a Humanoid in it.

	Returns nil when the way is clear.
]]
local function obstacleBetween(me: Instance, from: Vector3, to: Vector3): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { me }
	params.IgnoreWater = true

	local origin = from + Vector3.new(0, PROBE_HEIGHT, 0)
	local finish = Vector3.new(to.X, from.Y + PROBE_HEIGHT, to.Z)
	local delta = finish - origin
	if delta.Magnitude < 0.05 then
		return nil
	end

	--[[
		Up to three casts. The first hit is very often another body, and
		Exclude cannot express "everything with a Humanoid in it" without
		rebuilding a list of every character every frame — so instead the ray
		is re-cast past whatever it found. Three is enough for a crowd and
		bounded enough not to matter.
	]]
	for _ = 1, 3 do
		local hit = Workspace:Raycast(origin, delta, params)
		if not hit then
			return nil
		end
		if not isCharacter(hit.Instance) then
			return hit.Instance
		end
		local skipped = table.clone(params.FilterDescendantsInstances)
		table.insert(skipped, hit.Instance)
		params.FilterDescendantsInstances = skipped
	end
	return nil
end

--[[
	The height of the floor under `at`, searched from STEP_UP above the floor
	the body stands on now down to MAX_DROP below it. Characters are skipped the
	same way obstacleBetween skips them, so the dead do not climb each other.

	Returns nil when there is no floor in that range.
]]
local function floorUnder(me: Instance, at: Vector3, currentFloor: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { me }
	params.IgnoreWater = true

	local origin = Vector3.new(at.X, currentFloor + STEP_UP + 0.25, at.Z)
	local delta = Vector3.new(0, -(STEP_UP + 0.25 + MAX_DROP), 0)
	for _ = 1, 3 do
		local hit = Workspace:Raycast(origin, delta, params)
		if not hit then
			return nil
		end
		if not isCharacter(hit.Instance) and hit.Instance.CanCollide then
			return hit.Position.Y
		end
		local skipped = table.clone(params.FilterDescendantsInstances)
		table.insert(skipped, hit.Instance)
		params.FilterDescendantsInstances = skipped
	end
	return nil
end

--==========================================================================
-- Moving
--==========================================================================

--[[
	One kinematic step toward `targetPos`, XZ only, facing where it goes.

	The step is PROBED before it is taken. This is the layer that makes the
	no-walking-through-walls guarantee absolute: a path can be stale and a line
	of sight can be a frame old, but a step that would end inside something
	simply does not happen. Returns false when it was refused, so the caller
	can ask for a new route.
]]
local function moveToward(model: Instance, targetPos: Vector3, speed: number, dt: number): boolean
	if not model:IsA("PVInstance") then
		return false
	end
	local cur = positionOf(model)
	local flat = Vector3.new(targetPos.X, cur.Y, targetPos.Z)
	local delta = flat - cur
	local dist = delta.Magnitude
	if dist <= 0.05 then
		return true
	end

	local step = math.min(speed * dt, dist)
	local nextPos = cur + delta.Unit * step

	-- Probe a little beyond the step, so a body stops short of a wall rather
	-- than with its nose in it.
	if obstacleBetween(model, cur, cur + delta.Unit * (step + AGENT_RADIUS)) then
		-- Still turn to face the way it wants to go: a unit pressed against a
		-- corner but looking at you reads as blocked, not as broken.
		model:PivotTo(CFrame.lookAt(cur, flat))
		return false
	end

	-- Stand on whatever floor is under the step: a stair, a ramp, a roof.
	local floor = floorUnder(model, nextPos, cur.Y - PIVOT_ABOVE_FLOOR)
	if not floor then
		model:PivotTo(CFrame.lookAt(cur, flat))
		return false
	end
	nextPos = Vector3.new(nextPos.X, floor + PIVOT_ABOVE_FLOOR, nextPos.Z)

	model:PivotTo(CFrame.lookAt(nextPos, Vector3.new(flat.X, nextPos.Y, flat.Z)))
	return true
end

local function faceToward(model: Instance, targetPos: Vector3)
	if not model:IsA("PVInstance") then
		return
	end
	local cur = positionOf(model)
	local flat = Vector3.new(targetPos.X, cur.Y, targetPos.Z)
	if (flat - cur).Magnitude > 0.05 then
		model:PivotTo(CFrame.lookAt(cur, flat))
	end
end

-- Attaches an AI brain to a spawned enemy. No-op if its config has no `AI` block,
-- so non-AI enemies stay static. Called by EnemyService on spawn.
function EnemyAIService.attach(entity: CombatEntity.CombatEntity, enemyId: string, spawnPosition: Vector3)
	local enemies = Config.get("Enemies")
	local def = enemies[enemyId]
	if not def or not def.AI then
		return
	end
	local ai = def.AI

	local ranged: RangedProfile? = nil
	if def.Ranged then
		local r = def.Ranged
		ranged = {
			projectile = r.Projectile,
			speed = r.Speed,
			damage = r.Damage,
			damageType = r.DamageType,
			spread = r.Spread,
			leadFactor = r.LeadFactor,
			maxRange = r.MaxRange,
		}
	end

	agents[entity.id] = {
		brain = EnemyBrain.new(),
		spawnPosition = spawnPosition,
		params = {
			DetectionRadius = ai.DetectionRadius,
			AttackRange = ai.AttackRange,
			LeashRadius = ai.LeashRadius,
			-- A follower stops a few strides short of the player, not on top of them.
			ArrivalRadius = if ai.Follow then math.max(ai.ArrivalRadius, FOLLOW_GAP) else ai.ArrivalRadius,
			MinRange = ai.MinRange,
		},
		moveSpeed = ai.MoveSpeed,
		attackCooldown = ai.AttackCooldown,
		attackDamage = ai.AttackDamage,
		attackDamageType = ai.AttackDamageType,
		lastAttack = 0,
		windup = ai.Windup or 0,
		strike = ai.Strike or 0.15,
		recover = ai.Recover or 0,
		phase = nil,
		phaseEnd = 0,
		faceUntil = 0,
		aggroDone = false,
		aggroUntil = 0,
		visual = "Idle",
		seq = 0,
		ranged = ranged,
		meleeRange = ai.MeleeRange,
		follow = ai.Follow == true,
		farTime = 0,
		stuckSeconds = 0,
		followCheckAt = 0,
		followCheckPos = nil,
		lastTargetPos = nil,
		targetVelocity = Vector3.zero,
		waypoints = {},
		waypointIndex = 1,
		pathGoal = nil,
		--[[
			Staggered from birth. Ten shamblers spawned in the same frame would
			otherwise ask for ten routes in the same frame, for the rest of the
			run, forever in lockstep.
		]]
		repathAt = os.clock() + math.random() * REPATH_SECONDS,
		computing = false,
	}

	-- What a client needs to start animating this body.
	local model = entity.model
	if model then
		model:SetAttribute("State", "Idle")
		model:SetAttribute("Seq", 0)
		model:SetAttribute("Move", 0)
	end
end

-- Writes the animation state onto the model, once per change.
local function setVisual(model: Instance, agent: Agent, state: string, move: number?)
	if agent.visual ~= state then
		agent.visual = state
		agent.seq += 1
		model:SetAttribute("State", state)
		model:SetAttribute("Seq", agent.seq)
	end
	model:SetAttribute("Move", move or 0)
end

--==========================================================================
-- Routing
--==========================================================================
local computesThisFrame = 0

--[[
	Asks PathfindingService for a route to `goal` and stores its waypoints.

	Async, so the agent keeps walking on whatever it had while this runs, and
	everything is re-checked afterwards — a second may have passed and the
	agent may be dead, despawned or somewhere else entirely.
]]
local function requestPath(entityId: string, agent: Agent, from: Vector3, goal: Vector3)
	if agent.computing or computesThisFrame >= MAX_COMPUTES_PER_FRAME then
		return
	end
	agent.computing = true
	computesThisFrame += 1
	agent.repathAt = os.clock() + REPATH_SECONDS

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = AGENT_RADIUS,
			AgentHeight = AGENT_HEIGHT,
			AgentCanJump = false,
			AgentCanClimb = false,
		})

		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)

		-- It may have died or despawned while that was computing.
		if agents[entityId] ~= agent then
			return
		end
		agent.computing = false

		if not ok or path.Status ~= Enum.PathStatus.Success then
			--[[
				No route. Do NOT fall back to walking straight at the target —
				that is the bug this whole system exists to remove. Keep
				whatever route it had; the step probe stops it at the wall, and
				it asks again in a second.
			]]
			return
		end

		local points: { Vector3 } = {}
		for i, waypoint in path:GetWaypoints() do
			-- Skip the first: it is where the agent already is, and walking to
			-- it produces a visible stutter at the start of every route.
			if i > 1 then
				table.insert(points, waypoint.Position)
			end
		end

		agent.waypoints = points
		agent.waypointIndex = 1
		agent.pathGoal = goal
	end)
end

--[[
	Walks the agent toward `goal`, around whatever is in the way.

	Line of sight first, because in an open ward it almost always is, and one
	raycast is a thousandth of the cost of a route.
]]
local function travelTo(entityId: string, agent: Agent, model: Instance, selfPos: Vector3, goal: Vector3, dt: number)
	-- On another level the straight line only leads underneath it.
	local sameLevel = math.abs(goal.Y - selfPos.Y) <= LEVEL_GAP
	if sameLevel and not obstacleBetween(model, selfPos, goal) then
		agent.waypoints = {}
		agent.pathGoal = nil
		moveToward(model, goal, agent.moveSpeed, dt)
		return
	end

	-- Blocked. Ask for a route if the one it has is old, missing, or was
	-- computed toward somewhere the target has since left.
	local stale = agent.pathGoal == nil
		or (goal - (agent.pathGoal :: Vector3)).Magnitude > GOAL_DRIFT
		or os.clock() >= agent.repathAt
	if stale then
		requestPath(entityId, agent, selfPos, goal)
	end

	local point = agent.waypoints[agent.waypointIndex]
	if not point then
		--[[
			Nothing to follow. If the target is up on another level and the way
			to the spot beneath it is open, walk there: when there is no route
			up (or none found yet), the dead gather underneath and wait, which
			is both what they would do and what makes coming down dangerous.
		]]
		if not sameLevel and not obstacleBetween(model, selfPos, goal) then
			moveToward(model, goal, agent.moveSpeed, dt)
		end
		return -- otherwise nothing to follow yet; the probe keeps it honest either way
	end

	local flat = Vector3.new(point.X - selfPos.X, 0, point.Z - selfPos.Z)
	if flat.Magnitude <= WAYPOINT_RADIUS then
		agent.waypointIndex += 1
		point = agent.waypoints[agent.waypointIndex]
		if not point then
			agent.waypoints = {}
			agent.pathGoal = nil
			return
		end
	end

	--[[
		A refused step means the route no longer matches the world — something
		has moved, or the waypoint cuts a corner too fine. Ask again now rather
		than grinding against the obstacle for the rest of the second.
	]]
	if not moveToward(model, point, agent.moveSpeed, dt) then
		agent.repathAt = 0
	end
end

--[[
	Swings or shoots, whichever this unit is holding at this distance.

	The King is the only one that owns both, and `meleeRange` is the whole
	switch: inside it the sword comes out, beyond it he uses the bow. For
	everything else one of the two branches simply never applies.
]]
local function attack(entityId: string, agent: Agent, target: CombatEntity.CombatEntity, selfPos: Vector3, distance: number)
	local useMelee = agent.ranged == nil or (agent.meleeRange ~= nil and distance <= agent.meleeRange)

	if useMelee then
		-- Enemy damage flows through the SAME CombatService as the player's.
		local result = CombatService.applyDamage({
			sourceId = entityId,
			targetId = target.id,
			amount = agent.attackDamage,
			damageType = agent.attackDamageType,
		})
		if not result.blocked then
			log:info(("%s hit %s for %s"):format(entityId, target.id, tostring(result.amount)))
		end
		return
	end

	local r = agent.ranged :: RangedProfile
	if distance > r.maxRange then
		return -- out of the bow's reach; it holds the shot
	end
	ProjectileService.fire({
		sourceId = entityId,
		origin = selfPos + Vector3.new(0, MUZZLE_HEIGHT, 0),
		targetPosition = positionOf((target :: any).model) + Vector3.new(0, MUZZLE_HEIGHT * 0.6, 0),
		targetVelocity = agent.targetVelocity,
		kind = r.projectile,
		speed = r.speed,
		damage = r.damage,
		damageType = r.damageType,
		spread = r.spread,
		leadFactor = r.leadFactor,
		maxRange = r.maxRange,
	})
end

--[[
	The nearest living player's position, for a follower. Followers are the
	cured villagers: their `spawnPosition` is not a place they go home to, it is
	wherever the party is, so the brain's leash and Return behave as "keep up".
]]
local function nearestPlayerPosition(pos: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = root.Position, d
			end
		end
	end
	return best
end

local function stepAgent(entityId: string, agent: Agent, dt: number)
	local entity = CombatService.getEntity(entityId)
	if not entity or not entity.model then
		agents[entityId] = nil -- enemy despawned
		return
	end
	local model = entity.model
	local selfPos = positionOf(model)

	local target, targetDist = nearestHostile(selfPos, entity.faction)

	local followPos: Vector3? = nil
	if agent.follow then
		followPos = nearestPlayerPosition(selfPos)
		if followPos then
			agent.spawnPosition = followPos
			local gap = (followPos - selfPos).Magnitude

			-- Lost: far away for a while, or wanting to come and not getting anywhere.
			if gap > FOLLOW_TELEPORT_DIST then
				agent.farTime += dt
			else
				agent.farTime = 0
			end
			local clock = os.clock()
			if clock - agent.followCheckAt >= 1 then
				local still = agent.followCheckPos ~= nil and (selfPos - agent.followCheckPos).Magnitude < 0.4
				if still and target == nil and agent.phase == nil and gap > FOLLOW_GAP + 6 then
					agent.stuckSeconds += 1
				else
					agent.stuckSeconds = 0
				end
				agent.followCheckPos = selfPos
				agent.followCheckAt = clock
			end
			if agent.farTime >= FOLLOW_TELEPORT_AFTER or agent.stuckSeconds >= FOLLOW_STUCK_AFTER then
				agent.farTime = 0
				agent.stuckSeconds = 0
				for i = 0, 5 do
					local a = i * math.pi / 3
					local spot = followPos + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
					local floor = floorUnder(model, spot, followPos.Y - PIVOT_ABOVE_FLOOR - 2.5)
					if floor then
						model:PivotTo(CFrame.new(spot.X, floor + PIVOT_ABOVE_FLOOR, spot.Z))
						agent.waypoints = {}
						agent.pathGoal = nil
						selfPos = positionOf(model)
						break
					end
				end
			end
		end
	end

	--[[
		Track how fast the target is moving, so a ranged shot can lead it.
		Derived from successive positions rather than read off a Humanoid: the
		player rig and the spawned rigs report velocity differently, and the
		anchored ones report nothing at all.
	]]
	if target and target.model and dt > 0 then
		local now = positionOf(target.model)
		if agent.lastTargetPos then
			agent.targetVelocity = (now - agent.lastTargetPos) / dt
		end
		agent.lastTargetPos = now
	else
		agent.lastTargetPos = nil
		agent.targetVelocity = Vector3.zero
	end

	local state = agent.brain:update({
		isAlive = entity:isAlive(),
		targetDistance = targetDist,
		distanceFromSpawn = (selfPos - agent.spawnPosition).Magnitude,
		params = agent.params,
	})
	local now = os.clock()
	local States = EnemyBrain.States

	-- Noticing you is an event, once per time it comes back from rest.
	if state == States.Idle then
		agent.aggroDone = false
	elseif not agent.aggroDone and state ~= States.Dead and state ~= States.Return then
		agent.aggroDone = true
		agent.aggroUntil = now + AGGRO_SECONDS
	end

	--[[
		One thing at a time: a swing in progress, then a cry of first sight, and
		only then the ordinary walking and attacking. While it is swinging or
		crying out the body does not move.
	]]
	if agent.phase == "windup" then
		if target and target.model and now < agent.faceUntil then
			faceToward(model, positionOf(target.model))
		end
		setVisual(model, agent, "Windup")
		if now >= agent.phaseEnd then
			--[[
				THE STRIKE. Judged now, not when the swing began: a target that has
				stepped out of reach, or round behind, takes nothing.
			]]
			if target and target.model and targetDist then
				local toTarget = positionOf(target.model) - selfPos
				local flatTo = Vector3.new(toTarget.X, 0, toTarget.Z)
				local look = model:GetPivot().LookVector
				local meleeNow = agent.ranged == nil or (agent.meleeRange ~= nil and targetDist <= agent.meleeRange)
				local inFront = flatTo.Magnitude < 0.5 or flatTo.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) >= STRIKE_CONE
				if not meleeNow or (targetDist <= agent.params.AttackRange + STRIKE_LEEWAY and inFront) then
					attack(entityId, agent, target, selfPos, targetDist)
				end
			end
			agent.phase = "strike"
			agent.phaseEnd = now + agent.strike
		end
	elseif agent.phase == "strike" then
		setVisual(model, agent, "Strike")
		if now >= agent.phaseEnd then
			agent.phase = "recover"
			agent.phaseEnd = now + agent.recover
		end
	elseif agent.phase == "recover" then
		setVisual(model, agent, "Recover")
		if now >= agent.phaseEnd then
			agent.phase = nil
		end
	elseif now < agent.aggroUntil then
		if target and target.model then
			faceToward(model, positionOf(target.model))
		end
		setVisual(model, agent, "Aggro")
	else
		local moving = false
		if state == States.Chase then
			if target and target.model then
				travelTo(entityId, agent, model, selfPos, approachPoint(target.model, selfPos), dt)
				moving = true
			end
		elseif state == States.Reposition then
			--[[
				Backing away — and still shooting. It walks directly away from the
				target rather than around it: an archer that circles reads as
				evasive and is miserable to pin down, whereas one that gives ground
				in a straight line can be cornered against the map, which is what
				makes the chambers' walls and barricades worth using.
			]]
			if target and target.model then
				local targetPos = positionOf(target.model)
				local away = selfPos - targetPos
				if away.Magnitude > 0.1 then
					moveToward(model, selfPos + away.Unit * 12, agent.moveSpeed, dt)
					moving = true
				end
				faceToward(model, targetPos)
			end
		elseif state == States.Return then
			travelTo(entityId, agent, model, selfPos, agent.spawnPosition, dt)
			moving = true
		elseif state == States.Idle and followPos and (followPos - selfPos).Magnitude > FOLLOW_GAP + 3 then
			-- Nothing to fight and the party has walked on.
			travelTo(entityId, agent, model, selfPos, followPos, dt)
			moving = true
		end

		-- Attack and Reposition are BOTH firing states — see EnemyBrain.isAttacking.
		local began = false
		if EnemyBrain.isAttacking(state) and target and target.model and targetDist then
			if state == States.Attack then
				faceToward(model, positionOf(target.model))
			end
			if now - agent.lastAttack >= agent.attackCooldown then
				agent.lastAttack = now
				began = true
				if agent.windup <= 0 then
					attack(entityId, agent, target, selfPos, targetDist)
					setVisual(model, agent, "Strike")
				else
					agent.phase = "windup"
					agent.phaseEnd = now + agent.windup
					agent.faceUntil = now + agent.windup * FACE_LOCK
					setVisual(model, agent, "Windup")
				end
			end
		end

		if not began then
			if moving then
				setVisual(model, agent, if agent.moveSpeed >= RUN_SPEED then "Run" else "Walk", agent.moveSpeed)
			else
				setVisual(model, agent, "Idle")
			end
		end
	end
	-- Dead: EnemyService takes the body from here.
end

function EnemyAIService.Init() end

function EnemyAIService.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		-- The per-frame routing budget resets here, so no matter how many
		-- agents are alive only a handful may ask the pathfinder each frame.
		computesThisFrame = 0
		for entityId, agent in agents do
			stepAgent(entityId, agent, dt)
		end
	end)
	log:info("ready")
end

return EnemyAIService
