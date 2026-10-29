--!strict
--[[
	CharmService
	What the one worn charm DOES in the field (configs/Chapel.luau → Charms, the rules in
	Server/Domain/Charms). RunKitService puts the charm's mods into RunModService at the gate;
	this service makes three of them true:

	  MOURNER'S VEIL   The first blow of a run that would kill leaves one breath instead. A damage
	                   modifier on the combat pipeline. Spent per player until the next run
	                   (Player attribute `VeilSpent`, which the pack shows); the player is told with
	                   a CharmEvent cue.
	  BRASS STIRRUP    Out of a fight (no blow given or taken for `Calm` seconds) the wearer walks
	                   faster. It takes a CLAIM on the Humanoid's WalkSpeed and gives it back; a speed
	                   someone else wrote in between (the King's frost) is left alone. While the frost
	                   holds the speed, `SpeedHeld` is set on the Humanoid and this service stands
	                   back; while it holds a claim it publishes `BaseWalkSpeed`, so that writer
	                   can start from the true speed.
	  HOLLOW LANTERN   Nothing to do here: EnemyAIService asks RunModService.notice per target.

	The Signet (parry) and the Sexton's Key (locked caches) are Pending in the config: they wait for
	things that are not built.

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Server = script.Parent.Parent
local Charms = require(Server.Domain.Charms)
local GameService = require(Server.Services.GameService)
local CombatService = require(script.Parent.CombatService)
local DeathService = require(script.Parent.DeathService)
local RunModService = require(script.Parent.RunModService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local CharmService = {}

CharmService.Name = "CharmService"

local log = Logger.new("CharmService")

local TICK = 0.25
local DEFAULT_CALM = 5

-- the veil is spent per person for the run; it is kept by UserId so leaving and coming back does not mend it
local spent: { [number]: boolean } = {}
-- os.clock() of the last blow each player dealt or took
local lastFight: { [number]: number } = {}

type Record = { claim: Charms.Claim, humanoid: Humanoid }
local records: { [Player]: Record } = {}

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

local function calmSecondsOf(player: Player): number
	local worn = player:GetAttribute("Charm")
	local def = if typeof(worn) == "string" then Config.get("Chapel").Charms[worn] else nil
	return if def and def.Calm then def.Calm else DEFAULT_CALM
end

--==========================================================================
-- The veil
--==========================================================================

local function veilModifier(context: any)
	local model = context.target.model
	if not model then
		return
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player or not RunModService.lastBreath(player) then
		return
	end
	local amount, used =
		Charms.lastBreath(context.target.health.current, context.amount, true, spent[player.UserId] == true)
	if not used then
		return
	end
	context.amount = amount
	spent[player.UserId] = true
	player:SetAttribute("VeilSpent", true)
	Net.getEvent("CharmEvent"):FireClient(player, {
		kind = "cue",
		charm = "mourners_veil",
		title = "THE VEIL HOLDS",
		line = "One breath is left to you. The veil is spent until the next run.",
	})
	log:info(("%s: the veil held (a blow of %.0f on %.0f health)"):format(
		player.Name,
		context.request.amount,
		context.target.health.current
	))
end

--==========================================================================
-- The stirrup
--==========================================================================

local function stepStirrup(player: Player, now: number)
	local mult = RunModService.calmSpeed(player)
	local record = records[player]
	if mult == 1 and record == nil then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if record and record.humanoid ~= humanoid then
		-- a new body: the old claim was on a speed that no longer exists
		records[player] = nil
		record = nil
	end
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local calm = mult ~= 1
		and humanoid:GetAttribute("SpeedHeld") ~= true
		and Charms.isCalm(now, lastFight[player.UserId], calmSecondsOf(player))
	local current: Record = record or { claim = {}, humanoid = humanoid }
	records[player] = current

	local want = Charms.calmSpeed(current.claim, humanoid.WalkSpeed, calm, mult)
	if want then
		humanoid.WalkSpeed = want
	end
	local base = current.claim.base
	if humanoid:GetAttribute("BaseWalkSpeed") ~= base then
		humanoid:SetAttribute("BaseWalkSpeed", base)
	end
	if current.claim.set == nil and mult == 1 then
		records[player] = nil
	end
end

--==========================================================================

-- A new run (the first, or Play Again): nothing of the last one is kept.
local function newRun()
	spent = {}
	lastFight = {}
	for _, player in Players:GetPlayers() do
		player:SetAttribute("VeilSpent", nil)
	end
end

function CharmService.Init() end

function CharmService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	CombatService.registerModifier(veilModifier)

	CombatService.DamageDealt:connect(function(result: any)
		if result.blocked then
			return
		end
		local now = os.clock()
		local hit = playerOfId(result.targetId)
		if hit then
			lastFight[hit.UserId] = now
		end
		local struck = playerOfId(result.sourceId)
		if struck then
			lastFight[struck.UserId] = now
		end
	end)

	DeathService.onRunBegin(newRun)

	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < TICK then
			return
		end
		sinceTick = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			stepStirrup(player, now)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
		lastFight[player.UserId] = nil
	end)

	log:info("ready")
end

return CharmService
