--!strict
--[[
	ArmourService
	Plate. A unit whose config says `Armour = 0.4` turns that share of every
	ordinary blow aside, and a hit from a player who has chosen the forge's WEIGHT
	temper (chamber 5) turns less of it aside: the weight "breaks things", which
	is the whole answer to the Hollow Knight (docs/systems/Bestiary.md §5.2:
	"do you have something that breaks armour?").

	  damage taken = damage x (1 - Armour x (1 - pierce))

	`pierce` is the attacker's (RunModService, 0 with no temper, 0.6 with Weight);
	`True` damage ignores armour altogether (Shared.Combat.Enums.DamageType).

	It is one modifier on the combat pipeline's seam (CombatService.registerModifier),
	so nothing in combat knows about it, and a unit with no `Armour` is untouched.

	Place: Forgotten Lands ONLY (Server/World). Phase: Arsenal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local CombatService = require(script.Parent.CombatService)
local RunModService = require(script.Parent.RunModService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)

local ArmourService = {}

ArmourService.Name = "ArmourService"

local function attackerOf(sourceId: string?): Player?
	if not sourceId then
		return nil
	end
	local prefix = Constants.CombatId.PlayerPrefix
	if string.sub(sourceId, 1, #prefix) ~= prefix then
		return nil
	end
	local userId = tonumber(string.sub(sourceId, #prefix + 1))
	return if userId then Players:GetPlayerByUserId(userId) else nil
end

function ArmourService.Init() end

function ArmourService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	local enemies = Config.get("Enemies")
	CombatService.registerModifier(function(context)
		if context.request.damageType == "True" then
			return
		end
		local model = context.target.model
		local enemyId = model and model:GetAttribute("EnemyId")
		local def = enemyId and enemies[enemyId]
		local armour = def and def.Armour
		if not armour or armour <= 0 then
			return
		end
		local attacker = attackerOf(context.request.sourceId)
		local pierce = if attacker then RunModService.pierce(attacker) else 0
		context.amount *= 1 - armour * (1 - pierce)
	end)
end

return ArmourService
