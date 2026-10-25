--!strict
--[[
	Chapel (domain)
	The rules of what the Hub does with a run's stash (docs/systems/Spoils.md §6.2), as pure
	functions over a profile and the config, so they can be tested without a place:

	  shelf      today's three things at the Tithe, the same for everyone, by day number
	  tithe      60 bone dust for one of them
	  setCharm   wear a relic from the stash as the one charm (or nothing)
	  forge      make a blessing for the next run from the stash
	  offer      give the altar one star shard
	  journal    the pages, found and unfound, in the castle's order
	  takeKit    what the next run starts with (the world hands it over once)

	Every mutating function returns `true` on success, or `false, reason` and changes nothing.
	They write only to `profile.stash`, `profile.loadout` and `profile.altar`.

	Location: ServerScriptService.Server.Domain.Chapel
]]

local Chapel = {}

export type Profile = {
	stash: { [string]: number },
	loadout: { kit: { [string]: number }, charm: string?, blessing: string? },
	altar: { offered: number },
	achievements: { [string]: boolean },
}

export type ShelfEntry = { item: string, count: number, to: string }

--==========================================================================
-- Small helpers
--==========================================================================

-- A seeded generator that is the same in every server (no engine Random: the day number is the seed).
local function generator(seed: number): () -> number
	local state = seed % 2147483646 + 1
	return function()
		state = (state * 48271) % 2147483647
		return state
	end
end

local function have(profile: Profile, itemId: string): number
	return profile.stash[itemId] or 0
end

local function canAfford(profile: Profile, cost: { [string]: number }): boolean
	for itemId, n in cost do
		if have(profile, itemId) < n then
			return false
		end
	end
	return true
end

local function spend(profile: Profile, cost: { [string]: number })
	for itemId, n in cost do
		local left = have(profile, itemId) - n
		profile.stash[itemId] = if left > 0 then left else nil
	end
end

function Chapel.canAfford(profile: Profile, cost: { [string]: number }): boolean
	return canAfford(profile, cost)
end

--==========================================================================
-- The Tithe
--==========================================================================

-- Today's shelf: `ShelfSize` distinct things from the pool, by `day` (whole days since the epoch).
function Chapel.shelf(cfg: any, day: number): { ShelfEntry }
	local pool = cfg.Tithe.Pool
	local order: { number } = {}
	for i = 1, #pool do
		order[i] = i
	end
	local nextValue = generator(day)
	for i = #order, 2, -1 do
		local j = nextValue() % i + 1
		order[i], order[j] = order[j], order[i]
	end
	local shelf: { ShelfEntry } = {}
	for i = 1, math.min(cfg.Tithe.ShelfSize, #order) do
		local entry = pool[order[i]]
		table.insert(shelf, { item = entry.Item, count = entry.Count, to = entry.To })
	end
	return shelf
end

function Chapel.tithe(profile: Profile, cfg: any, day: number, itemId: string): (boolean, string?)
	local picked: ShelfEntry? = nil
	for _, entry in Chapel.shelf(cfg, day) do
		if entry.item == itemId then
			picked = entry
		end
	end
	if not picked then
		return false, "not on the shelf"
	end
	if not canAfford(profile, cfg.Tithe.Cost) then
		return false, "not enough"
	end
	spend(profile, cfg.Tithe.Cost)
	local into = if picked.to == "kit" then profile.loadout.kit else profile.stash
	into[picked.item] = (into[picked.item] or 0) + picked.count
	return true
end

--==========================================================================
-- The Reliquary
--==========================================================================

-- `itemId` nil takes the charm off.
function Chapel.setCharm(profile: Profile, cfg: any, itemId: string?): (boolean, string?)
	if itemId == nil then
		profile.loadout.charm = nil
		return true
	end
	if not cfg.Charms[itemId] then
		return false, "not a charm"
	end
	if have(profile, itemId) < 1 then
		return false, "not owned"
	end
	profile.loadout.charm = itemId
	return true
end

function Chapel.forge(profile: Profile, cfg: any, recipeId: string): (boolean, string?)
	local recipe = cfg.Recipes[recipeId]
	if not recipe then
		return false, "no such blessing"
	end
	if profile.loadout.blessing ~= nil then
		return false, "already blessed"
	end
	if not canAfford(profile, recipe.Needs) then
		return false, "not enough"
	end
	spend(profile, recipe.Needs)
	profile.loadout.blessing = recipeId
	return true
end

--==========================================================================
-- The Altar
--==========================================================================

-- Returns `true, raisedNow` (raisedNow: this shard was the last one).
function Chapel.offer(profile: Profile, cfg: any): (boolean, string | boolean | nil)
	local goal = cfg.Altar.Shards
	if profile.altar.offered >= goal then
		return false, "raised"
	end
	if have(profile, "star_shard") < 1 then
		return false, "no shard"
	end
	spend(profile, { star_shard = 1 })
	profile.altar.offered += 1
	local raisedNow = profile.altar.offered >= goal
	if raisedNow then
		profile.achievements.falling_star = true
	end
	return true, raisedNow
end

function Chapel.raised(profile: Profile, cfg: any): boolean
	return profile.altar.offered >= cfg.Altar.Shards
end

--==========================================================================
-- The Journal
--==========================================================================

export type JournalEntry = { id: string, order: number, place: string, found: boolean, title: string?, sign: string?, lines: { string }? }

-- Every page in the castle's order; the text only of the ones that were found.
function Chapel.journal(profile: Profile, pages: any): { JournalEntry }
	local out: { JournalEntry } = {}
	for id, page in pages do
		local found = have(profile, id) >= 1
		table.insert(out, {
			id = id,
			order = page.Order,
			place = page.Place,
			found = found,
			title = if found then page.Title else nil,
			sign = if found then page.Sign else nil,
			lines = if found then page.Lines else nil,
		})
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

--==========================================================================
-- The next run
--==========================================================================

export type Kit = { items: { [string]: number }, charm: string?, blessing: string? }

--[[
	What the next run starts with. The kit and the blessing are handed over once and cleared (the
	caller saves); the charm stays on, worn run after run. A charm's own gift (a charm of
	`Kit`) is added to the items.
]]
function Chapel.takeKit(profile: Profile, cfg: any): Kit
	local items: { [string]: number } = {}
	for itemId, n in profile.loadout.kit do
		items[itemId] = n
	end
	local charm = profile.loadout.charm
	if charm and have(profile, charm) >= 1 then
		local def = cfg.Charms[charm]
		if def and def.Kit then
			for itemId, n in def.Kit do
				items[itemId] = (items[itemId] or 0) + n
			end
		end
	else
		charm = nil
	end
	local blessing = profile.loadout.blessing
	profile.loadout.kit = {}
	profile.loadout.blessing = nil
	return { items = items, charm = charm, blessing = blessing }
end

return Chapel
