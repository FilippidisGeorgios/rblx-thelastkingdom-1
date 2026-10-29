--!strict
--[[
	RunKitService
	What the Hub gave a player for THIS run, handed over at the gate (docs/systems/Spoils.md
	§6.2, Server/Hub/ChapelService): the kit the Tithe chose (into the pack), the charm they
	wear (and its gift), and the blessing the Reliquary made (a RunModService source).

	Once per player per server: the kit and the blessing are cleared from the profile and the
	profile is saved the moment they are handed over; the charm stays on. The rules are the
	pure `Domain/Chapel.takeKit`.

	Also marks the Falling Star on a player who has raised it (a `FallingStar` attribute, the
	same one the Hub sets), so the world can show the sigil.

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Chapel = require(Server.Domain.Chapel)
local DataService = require(Server.Services.DataService)
local GameService = require(Server.Services.GameService)
local SaveService = require(Server.Services.SaveService)
local BackpackService = require(script.Parent.BackpackService)
local RunModService = require(script.Parent.RunModService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RunKitService = {}

RunKitService.Name = "RunKitService"

local log = Logger.new("RunKitService")

local handed: { [Player]: boolean } = {}

-- Hands one player what the Hub gave them. Returns what went into the pack (for a test).
function RunKitService.give(player: Player): { [string]: number }?
	if handed[player] then
		return nil
	end
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	handed[player] = true

	local cfg = Config.get("Chapel")
	local kit = Chapel.takeKit(profile, cfg)

	local went: { [string]: number } = {}
	for itemId, n in kit.items do
		local taken = BackpackService.add(player, itemId, n)
		if taken > 0 then
			went[itemId] = taken
		end
	end
	if kit.charm then
		local charmDef = cfg.Charms[kit.charm]
		if charmDef and charmDef.Mods then
			RunModService.set(player, "charm:" .. kit.charm, charmDef.Mods)
		end
		player:SetAttribute("Charm", kit.charm) -- after the mods: CharmService and the pack read it
	end
	if kit.blessing then
		local recipe = cfg.Recipes[kit.blessing]
		if recipe then
			RunModService.set(player, "blessing:" .. kit.blessing, recipe.Mods)
		end
	end
	player:SetAttribute("FallingStar", Chapel.raised(profile, cfg))

	if next(kit.items) ~= nil or kit.blessing then
		SaveService.save(player) -- the kit is spent: do not hand it over twice
	end
	log:info(("%s: kit %s, charm %s, blessing %s"):format(
		player.Name,
		(function()
			local parts: { string } = {}
			for itemId, n in went do
				table.insert(parts, ("%s x%d"):format(itemId, n))
			end
			return if #parts > 0 then table.concat(parts, ", ") else "none"
		end)(),
		tostring(kit.charm),
		tostring(kit.blessing)
	))
	return went
end

function RunKitService.Init() end

function RunKitService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	local function watch(player: Player)
		task.spawn(function()
			-- the profile arrives a moment after the player does
			for _ = 1, 50 do
				if DataService.get(player) then
					RunKitService.give(player)
					return
				end
				task.wait(0.2)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		handed[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	log:info("ready")
end

return RunKitService
