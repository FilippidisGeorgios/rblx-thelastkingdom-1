--!strict
--[[
	Trial.Huntsman
	The Huntsman of the King's Wood, in the world (docs/systems/Forest.md): it spawns him, looks for light with his eyes,
	walks him between the trees and lets him strike. What he SEES and DECIDES is `Domain/HuntsmanBrain`; this module is only
	the eyes, the legs and the hands.

	EYES. Five times a second, for every living player in the wood: where their lantern's flame is (or their head, without
	one), whether it is open or covered, whether they crouch, whether a burning watch-fire's glow holds them, and whether a
	ray from his eyes reaches it (trunks, rocks, huts and the ground stop it; leaves do not). A fire that is catching flares:
	he sees that from `Fire.FlareSeen`.

	LEGS. The pathfinder, with a body as wide and tall as his, walks him round the trunks; where it finds no way he goes
	straight. He never steps into a lit fire's glow: he stops at its edge. His feet follow the ground.

	HANDS. A body within `AttackRange` (and not in a fire's glow) is swung at: a windup that can be stepped out of, then the
	blow lands on whoever is still in reach.

	HE CANNOT DIE. Every blow he takes is counted; at `Endure` (times the party's health curve) he goes back into the dark
	for `DriveSeconds` and is made whole.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent.Parent
local HuntsmanBrain = require(Server.Domain.HuntsmanBrain)
local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local LanternService = require(script.Parent.Parent.LanternService)
local Cue = require(script.Parent.Cue)

local Huntsman = {}

local TICK = 0.1
local REPATH = 1.6 -- seconds between new paths to the same goal
local REPATH_MOVE = 6 -- or when the goal moves this far

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[
	ctx    the trial's context (note, warn, area)
	cfg    configs/Forest
	glows  a function that returns the burning fires' centres (inside their glow nothing is seen and he will not come)
]]
function Huntsman.create(ctx: any, cfg: any, glows: () -> { Vector3 })
	local H = cfg.Huntsman
	local handle: any = {}

	local running = false
	local id: string? = nil
	local model: Model? = nil
	local brain: any = nil
	local pivotAbove = 4
	local eyeAbove = 8
	local seq = 0
	local visual = "Idle"
	local taken = 0
	local endure = H.Endure
	local lastLook = 0
	local sightings: { HuntsmanBrain.Sighting } = {}
	local flares: { { at: Vector3, untilTime: number } } = {}
	local path: { PathWaypoint }? = nil
	local pathGoal: Vector3? = nil
	local pathAt = 0
	local wp = 1
	local lastStep = 0
	local connections: { any } = {}

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }

	local function groundY(x: number, z: number, near: number): number
		local hit = Workspace:Raycast(Vector3.new(x, near + 30, z), Vector3.new(0, -80, 0), groundParams)
		return if hit then hit.Position.Y else near
	end

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

	local function inGlow(at: Vector3, extra: number?): boolean
		for _, g in glows() do
			if flat(at - g).Magnitude <= cfg.Fire.Glow + (extra or 0) then
				return true
			end
		end
		return false
	end

	-- a ray from his eyes to `at` that nothing solid stops (players and he himself are not in the way)
	local function clearLine(eye: Vector3, at: Vector3): boolean
		local ignore: { Instance } = {}
		if model then
			table.insert(ignore, model)
		end
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(ignore, p.Character)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(eye, at - eye, params)
		return hit == nil or (hit.Position - at).Magnitude < 1
	end

	-- the living players in the wood
	local function bodies(): { { player: Player, root: BasePart } }
		local out = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and cfg.contains(root.Position) then
				table.insert(out, { player = player, root = root })
			end
		end
		return out
	end

	local function look(list: { { player: Player, root: BasePart } }, eye: Vector3, facing: Vector3, now: number)
		sightings = {}
		for _, b in list do
			local flame = LanternService.flameOf(b.player)
			local head = b.player.Character and b.player.Character:FindFirstChild("Head")
			local at = flame or (if head and head:IsA("BasePart") then head.Position else b.root.Position)
			local light: HuntsmanBrain.Light = {
				at = at,
				lantern = flame ~= nil,
				open = not LanternService.isCovered(b.player),
				crouched = b.player:GetAttribute("Crouching") == true,
				clear = false,
				inGlow = inGlow(at),
			}
			if not light.inGlow and flat(at - eye).Magnitude <= H.See.Open + 2 then
				light.clear = clearLine(eye, at)
			end
			if HuntsmanBrain.sees(H, eye, facing, light) then
				table.insert(sightings, { id = tostring(b.player.UserId), at = at })
			end
		end
		-- a fire catching flares across the wood
		for i = #flares, 1, -1 do
			local f = flares[i]
			if now > f.untilTime then
				table.remove(flares, i)
			elseif (f.at - eye).Magnitude <= cfg.Fire.FlareSeen and clearLine(eye, f.at + Vector3.new(0, 2, 0)) then
				-- he goes to the edge of its light, not into it
				local away = flat(eye - f.at)
				local edge = f.at + (if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)) * (cfg.Fire.Glow + 3)
				table.insert(sightings, { id = "flare", at = edge })
			end
		end
	end

	--======================================================================
	-- Legs
	--======================================================================
	local function stepToward(goal: Vector3, speed: number, now: number)
		local m = model :: Model
		local pos = m:GetPivot().Position
		local feet = pos - Vector3.new(0, pivotAbove, 0)
		-- a fresh path when the goal has moved or the old one is old
		if not pathGoal or flat(goal - pathGoal).Magnitude > REPATH_MOVE or now - pathAt > REPATH or not path then
			pathGoal = goal
			pathAt = now
			local p = PathfindingService:CreatePath({ AgentRadius = 2.2, AgentHeight = 9, AgentCanJump = false, WaypointSpacing = 5 })
			local ok = pcall(function()
				p:ComputeAsync(feet, goal)
			end)
			if ok and p.Status == Enum.PathStatus.Success then
				path = p:GetWaypoints()
				wp = 2
			else
				path = nil
			end
			if not model then
				return
			end
		end
		local target = goal
		if path and path[wp] then
			target = path[wp].Position
			if flat(target - feet).Magnitude < 1.5 then
				wp += 1
				if path[wp] then
					target = path[wp].Position
				end
			end
		end
		local delta = flat(target - feet)
		local dist = delta.Magnitude
		if dist < 0.05 then
			return
		end
		local dir = delta.Unit
		local nextFeet = feet + dir * math.min(speed * TICK, dist)
		-- never into a burning fire's light
		if inGlow(nextFeet, 1) then
			m:PivotTo(CFrame.lookAt(pos, pos + dir))
			setVisual("Idle", 0)
			return
		end
		local y = groundY(nextFeet.X, nextFeet.Z, feet.Y)
		local nextPos = Vector3.new(nextFeet.X, y + pivotAbove, nextFeet.Z)
		local turned = CFrame.new(nextPos) * (m:GetPivot().Rotation:Lerp(CFrame.lookAt(Vector3.zero, dir).Rotation, 0.3))
		m:PivotTo(turned)
		setVisual(if speed >= 12 then "Run" else "Walk", speed)
		if now - lastStep > (if speed >= 12 then 0.45 else 0.8) then
			lastStep = now
			Cue.play(nextPos - Vector3.new(0, pivotAbove, 0), cfg.Sounds.Step)
		end
	end

	local function face(toward: Vector3)
		local m = model
		if not m then
			return
		end
		local pos = m:GetPivot().Position
		local d = flat(toward - pos)
		if d.Magnitude > 0.2 then
			m:PivotTo(CFrame.new(pos) * m:GetPivot().Rotation:Lerp(CFrame.lookAt(Vector3.zero, d.Unit).Rotation, 0.3))
		end
	end

	--======================================================================
	-- The loop
	--======================================================================
	local function tick()
		local m = model
		if not (m and brain) then
			return
		end
		local now = os.clock()
		local pos = m:GetPivot().Position
		local eye = pos + Vector3.new(0, eyeAbove - pivotAbove, 0)
		local list = bodies()
		if now - lastLook >= H.See.Every then
			lastLook = now
			look(list, eye, m:GetPivot().LookVector, now)
		end

		local near: { HuntsmanBrain.Body } = {}
		for _, b in list do
			local d = flat(b.root.Position - pos).Magnitude
			if d <= H.AttackRange * 1.3 and not inGlow(b.root.Position) then
				table.insert(near, { id = tostring(b.player.UserId), distance = d })
			end
		end

		local action = brain:update(TICK, now, pos - Vector3.new(0, pivotAbove, 0), sightings, near)
		if action.horn then
			Cue.play(eye, cfg.Sounds.Horn)
			ctx.note("A horn, low and long, somewhere in the wood.", 3.5)
		end

		if action.strike then
			for _, b in list do
				if tostring(b.player.UserId) == action.strike and flat(b.root.Position - pos).Magnitude <= H.AttackRange + 1.2 then
					local entity = if b.player.Character then CombatService.getEntityByInstance(b.player.Character) else nil
					if entity and id then
						Cue.play(b.root.Position, cfg.Sounds.Strike)
						CombatService.applyDamage({ sourceId = id, targetId = entity.id, amount = H.AttackDamage, damageType = "Physical" })
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
		elseif action.goal then
			stepToward(action.goal, action.speed, now)
		else
			if action.face then
				face(action.face)
			elseif action.state == "Search" then
				-- he turns slowly where it was, looking
				m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.rad(4), 0))
			end
			setVisual(if action.state == "Alert" then "Aggro" else "Idle", 0)
		end
	end

	--======================================================================
	-- Life
	--======================================================================

	-- Puts him at `at` and lets him go round `stops`.
	function handle.start(at: Vector3, stops: { Vector3 }, healthMult: number)
		if running then
			return
		end
		running = true
		endure = H.Endure * math.max(1, healthMult)
		local spawned = EnemyService.spawn(H.Id, at, 1, at.Y - 0.5)
		local entity = CombatService.getEntity(spawned)
		if not (entity and entity.model) then
			ctx.warn("huntsman: the body is not built (run tools/BuildHuntsman.luau)")
			running = false
			return
		end
		id = spawned
		model = entity.model :: Model
		local m = model :: Model
		local box, size = m:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		local floor = groundY(at.X, at.Z, at.Y)
		m:PivotTo(m:GetPivot() + Vector3.new(0, floor - bottom, 0))
		pivotAbove = m:GetPivot().Position.Y - floor
		eyeAbove = size.Y - 1.2
		m:SetAttribute("State", "Idle")
		m:SetAttribute("Seq", 0)
		m:SetAttribute("Move", 0)
		m:SetAttribute("Hunter", true)
		brain = HuntsmanBrain.new(H, stops)

		-- he cannot die: what he takes is counted, and at `endure` he goes back into the dark and is made whole
		table.insert(connections, CombatService.DamageDealt:connect(function(result: any)
			if result.targetId ~= id or result.blocked then
				return
			end
			taken += result.amount
			local e = CombatService.getEntity(id :: string)
			if e then
				e.health:heal(result.amount)
			end
			if taken >= endure and model then
				taken = 0
				brain:drive(model:GetPivot().Position)
				ctx.note("The Huntsman staggers back into the dark.", 3.5)
			end
		end))

		task.spawn(function()
			while running do
				local ok, err = pcall(tick)
				if not ok then
					ctx.warn("huntsman: " .. tostring(err))
				end
				task.wait(TICK)
			end
		end)
	end

	-- A watch-fire at `at` is catching: its flare is seen across the wood for `seconds`.
	function handle.flare(at: Vector3, seconds: number)
		table.insert(flares, { at = at, untilTime = os.clock() + seconds })
	end

	function handle.stop()
		running = false
		for _, c in connections do
			if type(c) == "function" then
				c()
			elseif typeof(c) == "RBXScriptConnection" then
				c:Disconnect()
			end
		end
		connections = {}
		if id and model and model.Parent then
			EnemyService.despawn(id)
		end
		id = nil
		model = nil
	end

	function handle.model(): Model?
		return model
	end

	function handle.brain(): any
		return brain
	end

	function handle.isRunning(): boolean
		return running
	end

	return handle
end

return Huntsman
