--!strict
--[[
	RunModService
	What a player has become during THIS run, as numbers the combat code reads:
	a damage multiplier, extra reach, a swing-speed multiplier. Today the only
	source is the forge's temper (chamber 5); relics and oaths will be others.

	It sits between the thing that grants a change (a trial task) and the thing
	that applies it (MeleeCombatService), so neither has to know the other. A
	mod set is plain data, merged by multiplying damage and cooldown and adding
	reach, so two sources compose without a special case.

	Reset by `resetAll()` when a run starts; nothing here persists to the profile.

	Place: Forgotten Lands ONLY (Server/World). Phase: Arsenal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RunModService = {}

RunModService.Name = "RunModService"

local log = Logger.new("RunModService")

-- `pierce` is the share of an armoured unit's plate that this player's blows get through (0..1).
export type Mods = { damage: number?, reach: number?, cooldown: number?, pierce: number? }

type Applied = { damage: number, reach: number, cooldown: number, pierce: number, sources: { [string]: Mods } }

local applied: { [Player]: Applied } = {}

local function entry(player: Player): Applied
	local existing = applied[player]
	if existing then
		return existing
	end
	local created: Applied = { damage = 1, reach = 0, cooldown = 1, pierce = 0, sources = {} }
	applied[player] = created
	return created
end

local function recompute(a: Applied)
	a.damage, a.reach, a.cooldown, a.pierce = 1, 0, 1, 0
	for _, mods in a.sources do
		a.damage *= mods.damage or 1
		a.reach += mods.reach or 0
		a.cooldown *= mods.cooldown or 1
		a.pierce = math.max(a.pierce, mods.pierce or 0)
	end
end

--[[
	Sets (replaces) the mods from `source` ("temper", "relic:saints_medal", ...).
	A source is replaced, not stacked: choosing a temper twice is choosing once.
]]
function RunModService.set(player: Player, source: string, mods: Mods)
	local a = entry(player)
	a.sources[source] = mods
	recompute(a)
	log:info(("%s: %s -> x%.2f damage, +%.1f reach, x%.2f swing time"):format(player.Name, source, a.damage, a.reach, a.cooldown))
end

function RunModService.damage(player: Player): number
	return entry(player).damage
end

function RunModService.reach(player: Player): number
	return entry(player).reach
end

function RunModService.cooldown(player: Player): number
	return entry(player).cooldown
end

function RunModService.pierce(player: Player): number
	return entry(player).pierce
end

function RunModService.has(player: Player, source: string): boolean
	return entry(player).sources[source] ~= nil
end

--[[
	PARTY FLAGS: facts about the run that are not one player's: "the prisoner of
	the Rows is alive" (the whole team earns +5% gold if it is still true when the
	run is won). Set by trials, read by whatever settles the run's rewards.
]]
local flags: { [string]: any } = {}

function RunModService.setFlag(name: string, value: any)
	flags[name] = value
end

function RunModService.getFlag(name: string): any
	return flags[name]
end

function RunModService.resetAll()
	applied = {}
	flags = {}
end

function RunModService.Init() end

function RunModService.Start()
	Players.PlayerRemoving:Connect(function(player)
		applied[player] = nil
	end)
end

return RunModService
