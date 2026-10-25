--!strict
--[[
	Config: Chapel
	What the Hub does with the stash a run brings home (docs/systems/Spoils.md §6.2,
	Server/Hub/ChapelService, Server/Domain/Chapel). Four places, one building:

	  THE TITHE     bone dust for one pick from today's shelf of three.
	  THE RELIQUARY a relic from the stash worn as the one charm; an ember and some
	                silver beaten into a blessing for the next run.
	  THE ALTAR     the nine star shards, offered one at a time.
	  THE JOURNAL   every page found, in the order of the castle (configs/Pages).

	What the Tithe and the Reliquary give is for the NEXT run: it sits in
	`profile.loadout` until Server/World/RunKitService hands it over at the gate.

	Read via: Config.get("Chapel")
]]

local Chapel = {
	Tithe = {
		-- Spent from the stash.
		Cost = { bone_dust = 60 },
		-- How many things are on the shelf each day (the same shelf for everyone, all day, UTC).
		ShelfSize = 3,
		-- What the shelf is drawn from. `To` is where the pick goes: "kit" is carried into the
		-- next run; "stash" stays at home, for the Reliquary.
		Pool = {
			{ Item = "hearty_dish", Count = 2, To = "kit" },
			{ Item = "oil_pot", Count = 3, To = "kit" },
			{ Item = "arrow_bundle", Count = 2, To = "kit" },
			{ Item = "bandage", Count = 4, To = "kit" },
			{ Item = "tallow", Count = 4, To = "kit" },
			{ Item = "grave_silver", Count = 3, To = "stash" },
		},
	},

	-- The one charm slot. `Kit` is what wearing it puts in the pack at the gate; `Pending` is a
	-- charm whose effect waits for the stat it changes (Arsenal §6): it can be worn, and does nothing yet.
	Charms = {
		saints_medal = { Kit = { bandage = 1 } },
		company_signet = { Pending = true },
		brass_stirrup = { Pending = true },
		mourners_veil = { Pending = true },
		hollow_lantern = { Pending = true },
		sextons_key = { Pending = true },
	},

	-- Made at the second table, from the stash, for the next run only (one at a time).
	Recipes = {
		blessed_edge = {
			Label = "Blessed Edge",
			Needs = { hollow_ember = 1, grave_silver = 2 },
			Use = "For one run your blows land a tenth heavier.",
			-- RunModService mods, set at the gate.
			Mods = { damage = 1.10 },
		},
	},

	Altar = {
		-- Shards offered before the Falling Star is raised.
		Shards = 9,
	},
}

return table.freeze(Chapel)
