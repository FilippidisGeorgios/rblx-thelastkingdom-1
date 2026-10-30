--!strict
--[[
	RunDifficultyService
	Sets how hard THIS run is, once, when the run begins (the first one, and every Play Again): works out the Danger
	of the party actually standing here (Shared/Danger) and hands it to Shared/Scaling, which folds it into every
	wave, trial, the King and the pay.

	  who          the players in the server when the arrival scene ends, with the level each has in their profile
	               (read here, on this server: the Hub's figure is only what the train SHOWED)
	  the mode     what the party chose on the train, carried in the teleport data. It is checked again: a party
	               bigger than the Normal tier holds is Hard whatever the data says, and the only thing a forged
	               payload can do is make its own run harder
	  the figure   Danger.compute(levels, mode): the mode's points plus the veterans' points after the shield

	The figure is also left on the workspace (`RunDanger`, `RunMode`) for the HUD and the closing card to read.

	Place: Forgotten Lands ONLY (Server/World). Phase: Difficulty.

	Location: ServerScriptService.Server.World.RunDifficultyService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local DataService = require(Server.Services.DataService)
local GameService = require(Server.Services.GameService)
local TeleportService = require(Server.Services.TeleportService)
local DeathService = require(script.Parent.DeathService)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Danger = require(ReplicatedStorage.Shared.Danger)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RunDifficultyService = {}

RunDifficultyService.Name = "RunDifficultyService"

local log = Logger.new("RunDifficultyService")

local current: Danger.Breakdown? = nil

-- Did the party ask for Hard on the train? Any member's teleport data may say so; none = Normal.
local function wantsHard(players: { Player }): boolean
	for _, player in players do
		local ok, data = pcall(TeleportService.getArrivingData, player)
		if ok and type(data) == "table" and data.difficulty == "Hard" then
			return true
		end
	end
	return false
end

-- Works the figure out for `players` and sets it. Returns it (also for a test).
function RunDifficultyService.set(players: { Player }, hard: boolean): Danger.Breakdown
	local difficulty = Config.get("Difficulty")
	local levels: { number } = {}
	for _, player in players do
		local profile = DataService.get(player)
		table.insert(levels, if profile then profile.level or 1 else 1)
	end
	local tier = Danger.modeFor(#players, hard, difficulty.Tiers)
	local result = Danger.compute(levels, tier, difficulty.Danger)
	current = result
	Scaling.setRunDanger(result.total)
	workspace:SetAttribute("RunDanger", result.total)
	workspace:SetAttribute("RunMode", tier)
	log:info(("run difficulty: %s, %d player(s), average level %.1f, Danger +%.1f (mode %d, veterans %.1f%s)"):format(
		tier,
		#players,
		result.avgLevel,
		result.total,
		result.mode,
		result.veteran,
		if result.shielded then (", shield keeps %d%%"):format(result.keep * 100) else ""
	))
	return result
end

-- The figure of the run in play (nil before the first run begins).
function RunDifficultyService.get(): Danger.Breakdown?
	return current
end

function RunDifficultyService.Init() end

function RunDifficultyService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	DeathService.onRunBegin(function()
		local players = Players:GetPlayers()
		RunDifficultyService.set(players, wantsHard(players))
	end)
	log:info("ready")
end

return RunDifficultyService
