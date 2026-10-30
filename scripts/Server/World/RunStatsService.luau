--!strict
--[[
	RunStatsService
	What each player did in THIS run, counted as it happens, so RunSettlement can turn it into experience
	(Domain/RunXp) and into their lifetime statistics (Domain/PlayerStats) when the run ends:

	  kills      the dead slain, by tier (Standard, Elite, Boss), from the blows that killed them
	  damage     points of damage dealt to the dead
	  downs      times they fell
	  assists    dead enemies someone else finished that they had struck in the last few seconds
	  revives    fallen friends they raised (DeathService.onRaised)
	  active     seconds spent on their feet (alive) since the run began
	  cleared    the chambers the party cleared (AreaService), shared by everyone in the run
	  deeds      the deeds the party did (TrialService), shared; each is also written to every player's
	             profile at once as the achievement `deed_<id>`, so a deed is never lost with a wiped run
	  seconds    how long the run has lasted

	Nothing here decides anything or touches a profile except the deed achievements: it only counts. A run
	is a server's life; a Play Again starts the count afresh (DeathService.onRunBegin).

	Place: Forgotten Lands ONLY (Server/World). Phase: Profiles.

	Location: ServerScriptService.Server.World.RunStatsService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local AssistLedger = require(Server.Domain.AssistLedger)
local GameService = require(Server.Services.GameService)
local DataService = require(Server.Services.DataService)
local AreaService = require(script.Parent.AreaService)
local CombatService = require(script.Parent.CombatService)
local DeathService = require(script.Parent.DeathService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RunStatsService = {}

RunStatsService.Name = "RunStatsService"

local log = Logger.new("RunStatsService")

type Counts = {
	kills: { [string]: number },
	damage: number,
	downs: number,
	assists: number,
	revives: number,
	active: number,
}

export type Snapshot = {
	kills: { [string]: number },
	damage: number,
	downs: number,
	assists: number,
	revives: number,
	activeSeconds: number,
	cleared: { number },
	deeds: number,
	seconds: number,
}

-- A blow counts toward an assist if the enemy dies within this many seconds of it.
local ASSIST_WINDOW = 12
-- Enemies being tracked for assists are forgotten after this long without a blow.
local FORGET_AFTER = 60
local TICK = 1

--[[
	A dead enemy is already gone from the combat registry by the time DamageDealt tells us it died (the
	enemy service removes it on death, first). So the damage pipeline's modifier seam gives us the target
	just before the blow lands, and onDamage reads it from here. Weak, and cleared on use.
]]
local pending: { [string]: any } = setmetatable({}, { __mode = "v" }) :: any

local counts: { [Player]: Counts } = {}
local cleared: { number } = {}
local deeds: { [string]: boolean } = {}
local startedAt = os.clock()
local function countsOf(player: Player): Counts
	local c = counts[player]
	if not c then
		c = { kills = {}, damage = 0, downs = 0, assists = 0, revives = 0, active = 0 }
		counts[player] = c
	end
	return c
end

-- who has struck each enemy, and when (Domain/AssistLedger); an enemy that dies pays the others who struck it lately
local ledger = AssistLedger.new(ASSIST_WINDOW, FORGET_AFTER, 400)

local function noteBlow(enemyId: string, attacker: Player)
	ledger:blow(enemyId, attacker, os.clock())
end

-- The enemy died to `killer`: every OTHER player who struck it lately has helped.
local function creditAssists(enemyId: string, killer: Player)
	for _, helper in ledger:killed(enemyId, killer, os.clock()) do
		if (helper :: Player).Parent then
			countsOf(helper :: Player).assists += 1
		end
	end
end

local function playerOfId(entityId: string?): Player?
	if not entityId then
		return nil
	end
	local prefix = Constants.CombatId.PlayerPrefix
	if string.sub(entityId, 1, #prefix) ~= prefix then
		return nil
	end
	local userId = tonumber(string.sub(entityId, #prefix + 1))
	return if userId then Players:GetPlayerByUserId(userId) else nil
end

local function onDamage(result: any)
	local target = pending[result.targetId] or CombatService.getEntity(result.targetId)
	pending[result.targetId] = nil
	if result.blocked or not target then
		return
	end

	-- a player fell
	local fallen = playerOfId(result.targetId)
	if fallen then
		if result.killed then
			countsOf(fallen).downs += 1
		end
		return
	end

	-- a player struck the dead
	local attacker = playerOfId(result.sourceId)
	if not attacker or target.faction ~= "Enemies" then
		return
	end
	local c = countsOf(attacker)
	c.damage += math.max(0, result.amount or 0)
	noteBlow(result.targetId, attacker)
	if result.killed then
		creditAssists(result.targetId, attacker)
		local model = target.model
		local enemyId = model and model:GetAttribute("EnemyId")
		local def = if typeof(enemyId) == "string" then Config.get("Enemies")[enemyId] else nil
		local tier = if def and def.Tier then def.Tier else "Standard"
		c.kills[tier] = (c.kills[tier] or 0) + 1
	end
end

local function onDeed(_area: number, id: string)
	if deeds[id] then
		return
	end
	deeds[id] = true
	-- every player in the run did it with the party, and keeps it whatever happens next
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			profile.achievements["deed_" .. id] = true
		end
	end
	log:info("deed done: " .. id)
end

local function onCleared(index: number)
	for _, n in cleared do
		if n == index then
			return
		end
	end
	table.insert(cleared, index)
end

local function reset()
	counts = {}
	cleared = {}
	deeds = {}
	ledger:clear()
	startedAt = os.clock()
end

-- A teammate raised a fallen friend.
local function onRaised(_downed: Player, reviver: Player)
	countsOf(reviver).revives += 1
end

-- Seconds on their feet: counted a moment at a time for every player who is alive (not downed, waiting or gone).
local function tickActive(dt: number)
	for _, player in Players:GetPlayers() do
		if DeathService.isAlive(player) then
			countsOf(player).active += dt
		end
	end
end

-- What `player` did in this run so far (a copy: the caller may keep it).
function RunStatsService.snapshot(player: Player): Snapshot
	local c = countsOf(player)
	local kills: { [string]: number } = {}
	for tier, n in c.kills do
		kills[tier] = n
	end
	local doneDeeds = 0
	for _ in deeds do
		doneDeeds += 1
	end
	return {
		kills = kills,
		damage = c.damage,
		downs = c.downs,
		assists = c.assists,
		revives = c.revives,
		activeSeconds = c.active,
		cleared = table.clone(cleared),
		deeds = doneDeeds,
		seconds = os.clock() - startedAt,
	}
end

function RunStatsService.Init() end

function RunStatsService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	-- Required here, not at the top: TrialService -> Trial/Exit -> RunSettlement -> this module is a circle,
	-- and a module that requires itself through a circle fails to load. By Start every module is loaded.
	local TrialService = require(script.Parent.TrialService)
	CombatService.registerModifier(function(context)
		pending[context.request.targetId] = context.target
	end)
	CombatService.DamageDealt:connect(onDamage)
	AreaService.onCleared(onCleared)
	TrialService.onDeed(onDeed)
	DeathService.onRunBegin(reset)
	DeathService.onRaised(onRaised)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			tickActive(now - last)
			last = now
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)
	log:info("ready")
end

return RunStatsService
