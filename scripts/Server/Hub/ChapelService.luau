--!strict
--[[
	ChapelService
	The Hub's four uses of the stash (docs/systems/Spoils.md §6.2): the Tithe, the Reliquary, the
	Star Altar and the Journal. The rules are the pure `Domain/Chapel`; this owns the player's
	profile, the day, the saving, and what the Chapel panel is told.

	Server-authoritative like the forge: the client sends only "do this, with this id" (an item,
	a recipe) and gets back the whole state of the Chapel to draw. Nothing is priced or decided
	on the client.

	What the Tithe and the Reliquary give is for the NEXT run: it waits in `profile.loadout`
	until Server/World/RunKitService hands it over.

	Place: Kingdom Hub only. Phase: Spoils.

	Location: ServerScriptService.Server.Hub.ChapelService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Chapel = require(Server.Domain.Chapel)
local DataService = require(Server.Services.DataService)
local SaveService = require(Server.Services.SaveService)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ChapelService = {}

ChapelService.Name = "ChapelService"

local log = Logger.new("ChapelService")

local cfg: any = nil
local items: any = nil
local pages: any = nil

local chapelEvent: RemoteEvent
local lastAsk: { [Player]: number } = {}

local function today(): number
	return os.time() // 86400
end

local function nameOf(itemId: string): string
	local def = items[itemId]
	return if def then def.DisplayName else itemId
end

local function needLines(profile: any, needs: { [string]: number }): { any }
	local out: { any } = {}
	for itemId, need in needs do
		table.insert(out, { id = itemId, name = nameOf(itemId), need = need, have = profile.stash[itemId] or 0 })
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

--==========================================================================
-- What the panel is told
--==========================================================================
local function stateFor(player: Player, notice: string?): any?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local tithe = cfg.Tithe
	local shelf: { any } = {}
	for _, entry in Chapel.shelf(cfg, today()) do
		local def = items[entry.item]
		table.insert(shelf, {
			id = entry.item,
			name = nameOf(entry.item),
			count = entry.count,
			rank = if def and def.Rank then def.Rank else "Worn",
			flavour = if def then def.Flavour else nil,
			to = entry.to,
		})
	end

	local charms: { any } = {}
	for charmId, def in cfg.Charms do
		local owned = (profile.stash[charmId] or 0) >= 1
		local item = items[charmId]
		table.insert(charms, {
			id = charmId,
			name = nameOf(charmId),
			use = if item then item.Use else nil,
			owned = owned,
			worn = profile.loadout.charm == charmId,
			pending = def.Pending == true,
		})
	end
	table.sort(charms, function(a, b)
		if a.owned ~= b.owned then
			return a.owned
		end
		return a.name < b.name
	end)

	local recipes: { any } = {}
	for recipeId, recipe in cfg.Recipes do
		table.insert(recipes, {
			id = recipeId,
			label = recipe.Label,
			use = recipe.Use,
			needs = needLines(profile, recipe.Needs),
			can = Chapel.canAfford(profile, recipe.Needs) and profile.loadout.blessing == nil,
			waiting = profile.loadout.blessing == recipeId,
		})
	end
	table.sort(recipes, function(a, b)
		return a.label < b.label
	end)

	local kit: { any } = {}
	for itemId, n in profile.loadout.kit do
		table.insert(kit, { id = itemId, name = nameOf(itemId), count = n })
	end
	table.sort(kit, function(a, b)
		return a.name < b.name
	end)

	local pagesFound = 0
	for id in pages do
		if (profile.stash[id] or 0) >= 1 then
			pagesFound += 1
		end
	end

	return {
		kind = "state",
		notice = notice,
		stash = { boneDust = profile.stash.bone_dust or 0, shards = profile.stash.star_shard or 0, pages = pagesFound },
		tithe = {
			cost = needLines(profile, tithe.Cost),
			can = Chapel.canAfford(profile, tithe.Cost),
			shelf = shelf,
		},
		reliquary = { charms = charms, recipes = recipes },
		altar = {
			offered = profile.altar.offered,
			goal = cfg.Altar.Shards,
			shards = profile.stash.star_shard or 0,
			raised = Chapel.raised(profile, cfg),
		},
		journal = Chapel.journal(profile, pages),
		carried = kit,
		blessing = if profile.loadout.blessing then cfg.Recipes[profile.loadout.blessing].Label else nil,
	}
end

local function push(player: Player, notice: string?)
	local state = stateFor(player, notice)
	if state then
		chapelEvent:FireClient(player, state)
	end
end

-- The star on the tabard: a flag the world and the Hub can read off the player.
local function markStar(player: Player)
	local profile = DataService.get(player)
	if profile then
		player:SetAttribute("FallingStar", Chapel.raised(profile, cfg))
	end
end

--==========================================================================
-- Doing things
--==========================================================================
local REFUSAL = {
	["not enough"] = "You have not brought enough.",
	["not on the shelf"] = "That is not on today's shelf.",
	["not owned"] = "You do not have that.",
	["not a charm"] = "That is not a charm.",
	["already blessed"] = "A blessing already waits for your next run.",
	["no such blessing"] = "That cannot be made.",
	["raised"] = "The star is already raised.",
	["no shard"] = "You have no star shard to give.",
}

local function onRequest(player: Player, request: any)
	if type(request) ~= "table" then
		return
	end
	-- a click at a time: the panel is not a place to hammer
	local now = os.clock()
	if now - (lastAsk[player] or 0) < 0.15 then
		return
	end
	lastAsk[player] = now

	local profile = DataService.get(player)
	local action = request.action
	local id = request.id
	if not profile or type(action) ~= "string" then
		return
	end
	if id ~= nil and type(id) ~= "string" then
		return
	end

	if action == "state" then
		push(player, nil)
		return
	end

	local ok: boolean, why: any
	local notice: string? = nil
	if action == "tithe" and id then
		ok, why = Chapel.tithe(profile, cfg, today(), id)
		if ok then
			notice = ("The chapel gives you %s."):format(nameOf(id))
		end
	elseif action == "charm" then
		ok, why = Chapel.setCharm(profile, cfg, id)
		if ok then
			notice = if id then ("You wear the %s."):format(nameOf(id)) else "You take the charm off."
		end
	elseif action == "forge" and id then
		ok, why = Chapel.forge(profile, cfg, id)
		if ok then
			notice = ("The %s is made. It waits for your next run."):format(cfg.Recipes[id].Label)
		end
	elseif action == "offer" then
		ok, why = Chapel.offer(profile, cfg)
		if ok then
			notice = if why == true
				then "The ninth shard. The Falling Star is raised."
				else ("A shard is laid on the altar (%d of %d)."):format(profile.altar.offered, cfg.Altar.Shards)
			markStar(player)
		end
	else
		return
	end

	if ok then
		SaveService.save(player) -- the world loads this profile on the next boarding
		log:info(("%s: %s %s"):format(player.Name, action, tostring(id)))
		push(player, notice)
	else
		push(player, REFUSAL[tostring(why)] or "That cannot be done.")
	end
end

--==========================================================================
-- Lifecycle
--==========================================================================
function ChapelService.Init()
	cfg = Config.get("Chapel")
	items = Config.get("Items")
	pages = Config.get("Pages")
end

function ChapelService.Start()
	chapelEvent = Net.getEvent("ChapelEvent")
	Net.getEvent("RequestChapel").OnServerEvent:Connect(onRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)

	-- the star is on whoever has raised it, as soon as their profile is in
	local function watch(player: Player)
		task.spawn(function()
			for _ = 1, 50 do
				if DataService.get(player) then
					markStar(player)
					return
				end
				task.wait(0.2)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	log:info("ready")
end

return ChapelService
