--!strict
--[[
	Chapel.spec
	The Hub's uses of the stash: the Tithe's daily shelf and its price, the charm, the blessing,
	the altar's nine shards, the Journal, and what the next run is handed. Also checks that the
	real config names things that exist.

	Location: TestService.Tests.Chapel.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Chapel = require(ServerScriptService.Server.Domain.Chapel)
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)
local cfg = require(ReplicatedStorage.Config.Chapel)
local Items = require(ReplicatedStorage.Config.Items)
local Pages = require(ReplicatedStorage.Config.Pages)
local Loot = require(ReplicatedStorage.Config.Loot)

local function fresh(stash: { [string]: number }?): any
	local p: any = ProfileSchema.default()
	for k, v in stash or {} do
		p.stash[k] = v
	end
	return p
end

local function same(a: { Chapel.ShelfEntry }, b: { Chapel.ShelfEntry }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i].item ~= b[i].item then
			return false
		end
	end
	return true
end

return function(t: any)
	t.test("the shelf is three distinct things, the same all day, and moves from day to day", function()
		local a = Chapel.shelf(cfg, 20000)
		assert(#a == 3, "three on the shelf")
		assert(a[1].item ~= a[2].item and a[2].item ~= a[3].item and a[1].item ~= a[3].item, "distinct")
		assert(same(a, Chapel.shelf(cfg, 20000)), "the same shelf all day")
		local moved = false
		for day = 20001, 20030 do
			if not same(a, Chapel.shelf(cfg, day)) then
				moved = true
			end
		end
		assert(moved, "the shelf changes over a month")
	end)

	t.test("the tithe takes sixty bone dust and hands over the pick: a kit thing is carried, the rest stays home", function()
		local day = 20000
		local profile = fresh({ bone_dust = 130 })
		local pick = Chapel.shelf(cfg, day)[1]
		local ok = Chapel.tithe(profile, cfg, day, pick.item)
		assert(ok, "paid")
		assert(profile.stash.bone_dust == 70, "sixty spent")
		local into = if pick.to == "kit" then profile.loadout.kit else profile.stash
		assert(into[pick.item] >= pick.count, "the pick arrived where it goes")
	end)

	t.test("the tithe refuses what is not on the shelf and what it cannot be paid for, and changes nothing", function()
		local day = 20000
		local profile = fresh({ bone_dust = 59 })
		local pick = Chapel.shelf(cfg, day)[1]
		local ok, why = Chapel.tithe(profile, cfg, day, pick.item)
		assert(not ok and why == "not enough", "59 is not 60")
		profile.stash.bone_dust = 200
		local ok2, why2 = Chapel.tithe(profile, cfg, day, "kings_seal")
		assert(not ok2 and why2 == "not on the shelf", "not on the shelf")
		assert(profile.stash.bone_dust == 200 and next(profile.loadout.kit) == nil, "nothing changed")
	end)

	t.test("a charm must be owned; it can be taken off", function()
		local profile = fresh({ saints_medal = 1 })
		local ok = Chapel.setCharm(profile, cfg, "saints_medal")
		assert(ok and profile.loadout.charm == "saints_medal", "worn")
		local ok2, why2 = Chapel.setCharm(profile, cfg, "mourners_veil")
		assert(not ok2 and why2 == "not owned", "not owned")
		local ok3, why3 = Chapel.setCharm(profile, cfg, "star_shard")
		assert(not ok3 and why3 == "not a charm", "a shard is not a charm")
		assert(Chapel.setCharm(profile, cfg, nil) and profile.loadout.charm == nil, "taken off")
	end)

	t.test("a blessing is made from the stash, once at a time", function()
		local profile = fresh({ hollow_ember = 2, grave_silver = 5 })
		assert(Chapel.forge(profile, cfg, "blessed_edge"), "made")
		assert(profile.stash.hollow_ember == 1 and profile.stash.grave_silver == 3, "an ember and two silver spent")
		assert(profile.loadout.blessing == "blessed_edge", "the blessing is waiting")
		local ok, why = Chapel.forge(profile, cfg, "blessed_edge")
		assert(not ok and why == "already blessed", "one at a time")
		assert(profile.stash.hollow_ember == 1, "the second was not paid for")
	end)

	t.test("a blessing needs its materials", function()
		local profile = fresh({ hollow_ember = 1, grave_silver = 1 })
		local ok, why = Chapel.forge(profile, cfg, "blessed_edge")
		assert(not ok and why == "not enough", "one silver is not two")
		assert(profile.loadout.blessing == nil and profile.stash.hollow_ember == 1, "nothing spent")
	end)

	t.test("the altar takes a shard at a time and the ninth raises the star", function()
		local profile = fresh({ star_shard = 9 })
		for i = 1, 8 do
			local ok, raisedNow = Chapel.offer(profile, cfg)
			assert(ok and raisedNow == false, "shard " .. i)
		end
		assert(not Chapel.raised(profile, cfg), "not yet")
		local ok, raisedNow = Chapel.offer(profile, cfg)
		assert(ok and raisedNow == true, "the ninth")
		assert(Chapel.raised(profile, cfg) and profile.achievements.falling_star == true, "raised and remembered")
		assert(profile.stash.star_shard == nil, "all nine spent")
		local ok2, why2 = Chapel.offer(profile, cfg)
		assert(not ok2 and why2 == "raised", "no more to offer")
	end)

	t.test("the altar refuses with no shard", function()
		local profile = fresh()
		local ok, why = Chapel.offer(profile, cfg)
		assert(not ok and why == "no shard", "nothing to give")
		assert(profile.altar.offered == 0, "unchanged")
	end)

	t.test("the journal lists every page in the castle's order and reads only the found ones", function()
		local profile = fresh({ page_rows_letters = 1, page_graveyard_bell = 1 })
		local entries = Chapel.journal(profile, Pages)
		local count = 0
		for _ in Pages do
			count += 1
		end
		assert(#entries == count, "all of them are listed")
		for i = 2, #entries do
			assert(entries[i - 1].order <= entries[i].order, "in order")
		end
		local found = 0
		for _, e in entries do
			if e.found then
				found += 1
				assert(e.title and e.lines and #e.lines > 0, "found: readable")
			else
				assert(e.title == nil and e.lines == nil, "unfound: blank")
			end
		end
		assert(found == 2, "two found")
	end)

	t.test("the next run is handed the kit and the blessing once; the charm stays and brings its gift", function()
		local profile = fresh({ saints_medal = 1 })
		profile.loadout.kit = { oil_pot = 3, bandage = 2 }
		profile.loadout.blessing = "blessed_edge"
		Chapel.setCharm(profile, cfg, "saints_medal")
		local kit = Chapel.takeKit(profile, cfg)
		assert(kit.items.oil_pot == 3, "the kit")
		assert(kit.items.bandage == 3, "two bandages and the medal's one")
		assert(kit.blessing == "blessed_edge" and kit.charm == "saints_medal", "the blessing and the charm")
		assert(next(profile.loadout.kit) == nil and profile.loadout.blessing == nil, "handed over once")
		assert(profile.loadout.charm == "saints_medal", "the charm is still worn")
		local again = Chapel.takeKit(profile, cfg)
		assert(again.items.bandage == 1 and again.items.oil_pot == nil and again.blessing == nil, "only the medal's gift now")
	end)

	t.test("a charm no longer owned is not carried", function()
		local profile = fresh()
		profile.loadout.charm = "saints_medal"
		local kit = Chapel.takeKit(profile, cfg)
		assert(kit.charm == nil and next(kit.items) == nil, "nothing")
	end)

	t.test("the config names only things that exist, and every deed page is a page", function()
		for _, entry in cfg.Tithe.Pool do
			assert(Items[entry.Item], "tithe item " .. entry.Item)
			assert(entry.To == "kit" or entry.To == "stash", "tithe destination of " .. entry.Item)
		end
		for need in cfg.Tithe.Cost do
			assert(Items[need], "tithe cost " .. need)
		end
		for charm in cfg.Charms do
			assert(Items[charm], "charm " .. charm)
		end
		for _, recipe in cfg.Recipes do
			for need in recipe.Needs do
				assert(Items[need], "recipe need " .. need)
			end
		end
		for id in Pages do
			assert(Items[id], "page item " .. id)
		end
		local granted = {}
		for _, tbl in Loot.Tables do
			for _, drop in tbl.Always or {} do
				if drop.Item:sub(1, 5) == "page_" then
					granted[drop.Item] = true
				end
			end
		end
		for id in Pages do
			assert(granted[id], id .. " is given by a deed")
		end
	end)
end
