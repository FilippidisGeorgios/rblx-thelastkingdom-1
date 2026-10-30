--!strict
--[[
	EnemyService
	Generic spawn layer for the Forgotten Lands: spawns a unit (enemy OR neutral NPC)
	from `configs/Enemies`, registers it as a CombatEntity (faction from its def),
	binds Health<->Humanoid, attaches the AI brain if the def has an `AI` block, and
	cleans it up on death. Generic on purpose — undead, animals, bosses, and NPC
	targets (Defend/Escort) all flow through here; archetype-specific content is data.

	The Wave System will later drive spawning through this same API (batches, pacing).

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat / Missions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local CombatService = require(script.Parent.CombatService)
local EnemyAIService = require(script.Parent.EnemyAIService)
local CrawlerBody = require(Server.Domain.CrawlerBody)
local HumanoidAdapter = require(Server.Domain.Combat.HumanoidAdapter)
local Enums = require(ReplicatedStorage.Shared.Combat.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local EnemyService = {}

EnemyService.Name = "EnemyService"

local log = Logger.new("EnemyService")

-- Height (studs) of the placeholder rig; used to rest its feet on the ground.
local RIG_HEIGHT = 5

-- Tag that the client's ZombieAnimController looks for on a body it should animate.
local UNDEAD_TAG = "TLK_Undead"

-- How long a fallen body lies before it sinks into the ground, and how long the sinking takes.
local DEATH_HOLD = 3.2
local SINK_SECONDS = 2.0
local SINK_DEPTH = 2.4

local nextId = 0
local bindings: { [string]: HumanoidAdapter.Binding } = {}

local function generateId(): string
	nextId += 1
	return Constants.CombatId.EnemyPrefix .. nextId
end

-- Simple visible marker colour by faction (placeholder rig, not VFX).
local function colorForFaction(faction: string): Color3
	if faction == Enums.Faction.Neutral then
		return Color3.fromRGB(60, 160, 90)
	elseif faction == Enums.Faction.Players then
		return Color3.fromRGB(60, 120, 220)
	end
	return Color3.fromRGB(150, 40, 40) -- Enemies / default
end

-- Minimal anchored Humanoid rig used as a stand-in body. TEST scaffolding only —
-- real models (models/World) come later.
local function buildRig(color: Color3): (Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = "SpawnedUnit"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, RIG_HEIGHT, 1)
	root.Anchored = true
	root.Color = color
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	-- Headless rig would auto-die without this.
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	return model, humanoid
end

--[[
	The cured: the same bodies with the Hollow Light put out. Skin goes from
	stone-grey to a living tone, and the marks of the curse (the glow in the
	eyes, the veins at the neck, the blotches of decay) are hidden. The cloth
	stays as it was: they were found in what they died in.

	Skin unions carry their colours per cube, so a tint needs UsePartColor on;
	the head loses its painted detail and gains a living colour. Good enough
	to read as "one of us" at game distance; a proper living head is a later
	art pass (docs/Todo.md).
]]
local LIVING_SKIN = {
	Color3.fromRGB(196, 152, 122),
	Color3.fromRGB(176, 132, 104),
	Color3.fromRGB(214, 170, 140),
}
local CURSE_MARKS = { HollowLight = true, NeckCord = true, Vein = true, Blotch = true, Tear = true, Hollow = true, Socket = true }

local function livingTint(model: Model)
	local skin = LIVING_SKIN[math.random(#LIVING_SKIN)]
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if CURSE_MARKS[d.Name] then
				d.Transparency = 1
			elseif d.Material == Enum.Material.Concrete then
				if d:IsA("UnionOperation") then
					d.UsePartColor = true
				end
				d.Color = skin
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

--[[
	A body from ServerStorage.Assets.Undead (tools/BuildUndead), if this unit's
	config names one (`Body`) and it has been built. One of the listed bodies is
	picked at random, which is how the same shambler is a guard in one room and a
	scullion in the next. Returns nil otherwise and the caller falls back to the box.

	The body is a Model of unanchored, massless limbs on an anchored root, so the
	AI moves it with PivotTo exactly as it moved the box. Its look is animated on
	each client from the attributes the AI writes (see ZombieAnimController).
]]
local function buildBody(def: any): (Model?, Humanoid?)
	local names = def.Body
	if typeof(names) ~= "table" or #names == 0 then
		return nil, nil
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local store = assets and assets:FindFirstChild("Undead")
	local master = store and store:FindFirstChild(names[math.random(#names)])
	if not master then
		return nil, nil
	end
	local model = master:Clone() :: Model
	model.Name = "SpawnedUnit"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		return nil, nil
	end
	-- One of three gaits, kept for life, so a crowd has no synchronised footfalls.
	model:SetAttribute("Variant", math.random(1, 3))
	model:SetAttribute("HitCount", 0)
	if def.Cured then
		livingTint(model)
	end
	-- no legs: it drags itself along on its arms (a body made at spawn from a standing one)
	if def.Crawler then
		CrawlerBody.make(model)
	end
	-- A body arrives whole or not at all (a limb without its torso is worse than nothing).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, UNDEAD_TAG)
	return model, humanoid
end

-- Spawns unit `enemyId` at `position`, registers it as a CombatEntity, and returns
-- its entity id. Attaches the AI brain only if the def has an `AI` block (so neutral
-- NPCs are passive). Despawns automatically on death. `healthMult` scales max health
-- (difficulty scaling); defaults to 1.
function EnemyService.spawn(enemyId: string, position: Vector3, healthMult: number?, floorY: number?): string
	local enemies = Config.get("Enemies")
	local def = enemies[enemyId]
	assert(def, "Unknown enemy id: " .. tostring(enemyId))

	local bodyModel, bodyHumanoid = buildBody(def)
	local model: Model, humanoid: Humanoid
	if bodyModel and bodyHumanoid then
		model, humanoid = bodyModel, bodyHumanoid
	else
		model, humanoid = buildRig(colorForFaction(def.Faction))
	end

	-- Rest feet on the ground under the spawn XZ (baseplate/terrain), else fall back.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model }
	local groundY = position.Y
	-- `floorY` is for INDOORS (a villager untied in a tavern): the ray below would land on the roof.
	local hit = if floorY then nil else Workspace:Raycast(
		Vector3.new(position.X, position.Y + 200, position.Z),
		Vector3.new(0, -400, 0),
		rayParams
	)
	if floorY then
		groundY = floorY
	elseif hit then
		groundY = hit.Position.Y
	end
	local spawnPos = Vector3.new(position.X, groundY + RIG_HEIGHT / 2, position.Z)
	model:PivotTo(CFrame.new(spawnPos))
	model:SetAttribute("EnemyId", enemyId) -- LootService reads which table to roll
	model.Parent = Workspace

	local id = generateId()
	local entity = CombatService.registerEntity({
		id = id,
		faction = def.Faction,
		maxHealth = def.MaxHealth * (healthMult or 1),
		model = model,
	})
	bindings[id] = HumanoidAdapter.bind(entity.health, humanoid)

	-- AI brain (no-op if the def has no AI block — neutral NPCs stay passive).
	EnemyAIService.attach(entity, enemyId, spawnPos)

	-- Count the hits it takes, so each client can flinch the body (no per-frame traffic).
	local lastHealth = entity.health.current
	entity.health.Changed:connect(function(current: number)
		if current < lastHealth and model.Parent then
			model:SetAttribute("HitCount", (model:GetAttribute("HitCount") or 0) + 1)
		end
		lastHealth = current
	end)

	entity.health.Died:connect(function()
		EnemyService.kill(id)
	end)

	return id
end

--[[
	A body with no brain and no combat entity: it stands where it is put and
	plays its idle. For the penned dead of the Kitchens, who are waiting to be
	fed and must neither chase, be targeted nor be killed. Returns nil when
	`enemyId` has no body. Destroy it (or swap it for a real spawn) to be rid of it.
]]
function EnemyService.spawnStatic(enemyId: string, position: Vector3, facing: Vector3?, floorY: number?): Model?
	local def = Config.get("Enemies")[enemyId]
	if not def then
		return nil
	end
	local model = buildBody(def)
	if not model then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	-- `floorY` is for INDOORS: a ray dropped from above a room lands on its roof.
	local hit = if floorY then nil else Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local groundY = floorY or (if hit then hit.Position.Y else position.Y)
	local at = Vector3.new(position.X, groundY + RIG_HEIGHT / 2, position.Z)
	if facing then
		model:PivotTo(CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z)))
	else
		model:PivotTo(CFrame.new(at))
	end
	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("State", "Idle")
	model:SetAttribute("Seq", 0)
	model:SetAttribute("Move", 0)
	model.Parent = Workspace
	return model
end

--[[
	An enemy has died. A sculpted body is not deleted: it falls (the clients play
	one of three falls, chosen here), lies a moment, and sinks into the ground.
	A plain box is simply removed. Either way the entity is gone from the combat
	registry this instant, so nothing targets it, and the AI drops it.
]]
function EnemyService.kill(id: string)
	local entity = CombatService.getEntity(id)
	local model = entity and entity.model
	if not (model and CollectionService:HasTag(model, UNDEAD_TAG)) then
		EnemyService.despawn(id)
		return
	end

	local binding = bindings[id]
	if binding then
		binding.disconnect()
		bindings[id] = nil
	end
	CombatService.unregisterEntity(id)

	local m = model :: Model
	m:SetAttribute("Fall", math.random(1, 3))
	m:SetAttribute("State", "Death")
	m:SetAttribute("Seq", (m:GetAttribute("Seq") or 0) + 1)
	local root = m.PrimaryPart
	if root then
		root.CanCollide = false
		root.CanQuery = false
	end

	task.delay(DEATH_HOLD, function()
		if not m.Parent then
			return
		end
		local steps = math.floor(SINK_SECONDS / 0.1)
		for _ = 1, steps do
			if not m.Parent then
				return
			end
			m:PivotTo(m:GetPivot() - Vector3.new(0, SINK_DEPTH / steps, 0))
			task.wait(0.1)
		end
		if m.Parent then
			m:Destroy()
		end
	end)
end

function EnemyService.despawn(id: string)
	local binding = bindings[id]
	if binding then
		binding.disconnect()
		bindings[id] = nil
	end
	local entity = CombatService.getEntity(id)
	if entity and entity.model then
		entity.model:Destroy()
	end
	CombatService.unregisterEntity(id)
end

function EnemyService.Init() end

function EnemyService.Start()
	log:info("ready")
end

return EnemyService
