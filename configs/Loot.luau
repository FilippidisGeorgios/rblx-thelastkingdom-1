--!strict
--[[
	Config: Loot
	What falls out of the dead, out of containers, and out of tasks. The design
	is docs/systems/Spoils.md; the roll itself is the pure
	`Server/Domain/LootTable` (so the maths is spec-tested without Roblox).

	Read via: Config.get("Loot")

	NOTE: drop tables are sensitive in a competitive game; in this co-op PvE
	game exposing them to the client is harmless, so they stay in the shared
	config folder for now (decision recorded in docs/Todo.md).

	--------------------------------------------------------------------------
	SCHEMA

	Ranks[rank] = { Colour = Color3, Glow = number }       -- 0..3

	Rules = {
		Radius          = number,   -- a kill is rolled for every player within this many studs
		PityGuaranteeSound   = number,  -- kills without a Sound-or-better drop before one is forced
		PityUpgradeHallowed  = number,  -- kills without a Hallowed drop before the next Sound roll is upgraded
		GoldPerDepth    = number,   -- gold x (1 + this x (chamber - 1))
		SoundPerDepth   = number,   -- Sound chance x (1 + this x (chamber - 1))
		HallowedPerDepth = number,
		PickupSeconds   = number,   -- an unclaimed drop vanishes after this long
		MaxPickups      = number,   -- in the world at once; the oldest goes first
		WipeKeepsGold   = number,   -- fraction of gold kept on a wiped run   [PROPOSED, Spoils §7]
	PrisonerGoldBonus = number, -- of the gold, for the team, with the prisoner alive at the end of a won run (RunSettlement)
		BackpackSlots   = number,   -- stacks a player can carry (quest items are separate)
	}

	Tables[id] = {
		Gold     = { Chance = 0..1, Min = n, Max = n }?,
		Drops    = { { Item = id, Chance = 0..1, Min = n, Max = n } }?,   -- each rolled on its own
		Sound    = { Chance = 0..1, Pool = { { Item = id, Weight = n, Min = n, Max = n } } }?,
		Hallowed = { Chance = 0..1, Pool = { ... } }?,
		Always   = { { Item = id, Min = n, Max = n } }?,                    -- guaranteed (bosses)
	}

	`Tables` is keyed by ENEMY id (configs/Enemies) for the dead, and by
	`cache_<kind>` for containers.
]]

local Loot = {
	Ranks = {
		Worn = { Colour = Color3.fromRGB(226, 214, 188), Glow = 0 },
		Sound = { Colour = Color3.fromRGB(118, 190, 154), Glow = 1 },
		Hallowed = { Colour = Color3.fromRGB(238, 128, 58), Glow = 2 },
		Relic = { Colour = Color3.fromRGB(240, 204, 104), Glow = 3 },
	},

	Rules = {
		Radius = 70,
		PityGuaranteeSound = 30,
		PityUpgradeHallowed = 120,
		GoldPerDepth = 0.15,
		SoundPerDepth = 0.08,
		HallowedPerDepth = 0.06,
		PickupSeconds = 90,
		MaxPickups = 90,
		WipeKeepsGold = 0.25,
		PrisonerGoldBonus = 0.05, -- of the gold carried out, for the whole team, if the prisoner of the Rows is alive at the end of a won run
		BackpackSlots = 16,
	},

	Tables = {
		--==================================================================
		-- THE DEAD
		--==================================================================
		undead_shambler = {
			Gold = { Chance = 0.55, Min = 1, Max = 3 },
			Drops = {
				{ Item = "bone_dust", Chance = 0.45, Min = 1, Max = 2 },
				{ Item = "grave_cloth", Chance = 0.25, Min = 1, Max = 1 },
				{ Item = "rusted_iron", Chance = 0.04, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.012,
				Pool = {
					{ Item = "tallow", Weight = 40, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 25, Min = 1, Max = 1 },
					{ Item = "oil_pot", Weight = 20, Min = 1, Max = 1 },
					{ Item = "hearty_dish", Weight = 15, Min = 1, Max = 1 },
				},
			},
			Hallowed = {
				Chance = 0.002,
				Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } },
			},
		},

		-- The crawler: little to take from what is left of it, but the bone dust is plentiful (it shows its bones).
		undead_crawler = {
			Gold = { Chance = 0.35, Min = 1, Max = 2 },
			Drops = {
				{ Item = "bone_dust", Chance = 0.6, Min = 1, Max = 2 },
				{ Item = "grave_cloth", Chance = 0.12, Min = 1, Max = 1 },
			},
		},

		undead_runner = {
			Gold = { Chance = 0.4, Min = 1, Max = 2 },
			Drops = {
				{ Item = "bone_dust", Chance = 0.35, Min = 1, Max = 2 },
				{ Item = "grave_cloth", Chance = 0.15, Min = 1, Max = 1 },
				{ Item = "wild_feather", Chance = 0.06, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.012,
				Pool = {
					{ Item = "tallow", Weight = 40, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 1 },
					{ Item = "oil_pot", Weight = 30, Min = 1, Max = 1 },
				},
			},
			Hallowed = {
				Chance = 0.002,
				Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } },
			},
		},

		-- The Gravedigger. A kill worth the trouble: iron, silver, and a chance at more.
		undead_brute_heavy = {
			Gold = { Chance = 1.0, Min = 4, Max = 9 },
			Drops = {
				{ Item = "bone_dust", Chance = 1.0, Min = 2, Max = 4 },
				{ Item = "rusted_iron", Chance = 0.6, Min = 1, Max = 2 },
				{ Item = "grave_silver", Chance = 0.25, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.08,
				Pool = {
					{ Item = "tallow", Weight = 30, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 2 },
					{ Item = "oil_pot", Weight = 20, Min = 1, Max = 1 },
					{ Item = "hearty_dish", Weight = 20, Min = 1, Max = 1 },
				},
			},
			Hallowed = {
				Chance = 0.01,
				Pool = {
					{ Item = "hollow_ember", Weight = 70, Min = 1, Max = 1 },
					{ Item = "sextons_key", Weight = 30, Min = 1, Max = 1 },
				},
			},
		},

		undead_spearman = {
			Gold = { Chance = 0.5, Min = 2, Max = 4 },
			Drops = {
				{ Item = "rusted_iron", Chance = 0.45, Min = 1, Max = 2 },
				{ Item = "bone_dust", Chance = 0.4, Min = 1, Max = 2 },
				{ Item = "grave_cloth", Chance = 0.15, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.03,
				Pool = {
					{ Item = "tallow", Weight = 30, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 1 },
					{ Item = "oil_pot", Weight = 40, Min = 1, Max = 1 },
				},
			},
			Hallowed = {
				Chance = 0.004,
				Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } },
			},
		},

		undead_archer = {
			Gold = { Chance = 0.45, Min = 2, Max = 4 },
			Drops = {
				{ Item = "wild_feather", Chance = 0.55, Min = 1, Max = 3 },
				{ Item = "bone_dust", Chance = 0.3, Min = 1, Max = 2 },
				{ Item = "rusted_iron", Chance = 0.2, Min = 1, Max = 1 },
				{ Item = "arrow_bundle", Chance = 0.08, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.03,
				Pool = {
					{ Item = "tallow", Weight = 30, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 1 },
					{ Item = "arrow_bundle", Weight = 40, Min = 1, Max = 2 },
				},
			},
			Hallowed = {
				Chance = 0.004,
				Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } },
			},
		},

		-- The Hollow Knight. The line's own guard in plate: a kill that has to be
		-- earned, so it pays like one.
		undead_knight = {
			Gold = { Chance = 1.0, Min = 12, Max = 24 },
			Drops = {
				{ Item = "rusted_iron", Chance = 1.0, Min = 2, Max = 3 },
				{ Item = "bone_dust", Chance = 1.0, Min = 1, Max = 3 },
				{ Item = "grave_silver", Chance = 0.4, Min = 1, Max = 2 },
			},
			Sound = {
				Chance = 0.25,
				Pool = {
					{ Item = "tallow", Weight = 20, Min = 1, Max = 2 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 2 },
					{ Item = "oil_pot", Weight = 25, Min = 1, Max = 1 },
					{ Item = "hearty_dish", Weight = 25, Min = 1, Max = 1 },
				},
			},
			Hallowed = {
				Chance = 0.06,
				Pool = {
					{ Item = "hollow_ember", Weight = 60, Min = 1, Max = 1 },
					{ Item = "sextons_key", Weight = 20, Min = 1, Max = 1 },
					{ Item = "hollow_lantern", Weight = 20, Min = 1, Max = 1 },
				},
			},
		},

		-- The Doctor of the Catacombs: killing him is a long, loud, hard thing and he pays for it.
		plague_doctor = {
			Gold = { Chance = 1.0, Min = 60, Max = 90 },
			Always = {
				{ Item = "grave_silver", Min = 4, Max = 6 },
				{ Item = "hollow_ember", Min = 1, Max = 2 },
				{ Item = "saints_medal", Min = 1, Max = 1 },
			},
		},

		the_king = {
			Gold = { Chance = 1.0, Min = 120, Max = 160 },
			Always = {
				{ Item = "kings_seal", Min = 1, Max = 1 },
				{ Item = "hollow_ember", Min = 3, Max = 5 },
			},
		},

		--==================================================================
		-- CONTAINERS — rolled when searched (docs/systems/Spoils.md §4)
		--==================================================================
		cache_sack = {
			Gold = { Chance = 0.6, Min = 2, Max = 6 },
			Drops = {
				{ Item = "grave_cloth", Chance = 0.5, Min = 1, Max = 3 },
				{ Item = "wild_feather", Chance = 0.2, Min = 1, Max = 2 },
				{ Item = "bone_dust", Chance = 0.3, Min = 1, Max = 3 },
			},
			Sound = { Chance = 0.04, Pool = { { Item = "tallow", Weight = 1, Min = 1, Max = 2 } } },
		},
		cache_crate = {
			Gold = { Chance = 0.6, Min = 3, Max = 8 },
			Drops = {
				{ Item = "rusted_iron", Chance = 0.5, Min = 1, Max = 2 },
				{ Item = "bandage", Chance = 0.25, Min = 1, Max = 1 },
				{ Item = "arrow_bundle", Chance = 0.15, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.06,
				Pool = {
					{ Item = "oil_pot", Weight = 1, Min = 1, Max = 1 },
					{ Item = "tallow", Weight = 1, Min = 1, Max = 2 },
				},
			},
		},
		cache_chest = {
			Gold = { Chance = 1.0, Min = 10, Max = 30 },
			Drops = {
				{ Item = "bandage", Chance = 0.6, Min = 1, Max = 2 },
				{ Item = "grave_silver", Chance = 0.3, Min = 1, Max = 1 },
			},
			Sound = {
				Chance = 0.35,
				Pool = {
					{ Item = "oil_pot", Weight = 1, Min = 1, Max = 2 },
					{ Item = "hearty_dish", Weight = 1, Min = 1, Max = 1 },
					{ Item = "grave_silver", Weight = 1, Min = 1, Max = 2 },
				},
			},
			Hallowed = { Chance = 0.05, Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } } },
		},

		-- A vein in the Smithy's mine: gold, sometimes iron, rarely silver.
		mine_vein = {
			Gold = { Chance = 1.0, Min = 14, Max = 34 },
			Drops = { { Item = "rusted_iron", Chance = 0.5, Min = 1, Max = 2 } },
			Sound = { Chance = 0.12, Pool = { { Item = "grave_silver", Weight = 1, Min = 1, Max = 2 } } },
		},

		--==================================================================
		-- DEED PRIZES — fixed, no chance (docs/systems/Trials.md)
		--==================================================================
		-- The three letters of the Rows: the first of the nine star shards, and a veil.
		deed_rows_letters = {
			Always = { { Item = "star_shard", Min = 1, Max = 1 }, { Item = "mourners_veil", Min = 1, Max = 1 }, { Item = "page_rows_letters", Min = 1, Max = 1 } },
		},
		-- The Inner Ward's three papers: a star shard, and the Marshal's signet from his table.
		deed_ward_papers = {
			Always = { { Item = "star_shard", Min = 1, Max = 1 }, { Item = "company_signet", Min = 1, Max = 1 }, { Item = "page_ward_papers", Min = 1, Max = 1 } },
		},
		-- The mangonel put back in order: what the crew had left in its ammunition box.
		deed_ward_mangonel = {
			Always = { { Item = "rusted_iron", Min = 3, Max = 5 }, { Item = "bandage", Min = 2, Max = 3 } },
			Sound = { Chance = 1.0, Pool = { { Item = "oil_pot", Weight = 1, Min = 1, Max = 2 }, { Item = "arrow_bundle", Weight = 1, Min = 1, Max = 2 } } },
		},
		-- The camp chest (Server/World/CampService): once per player per camp, a guaranteed Sound find.
		camp_chest = {
			Gold = { Chance = 1.0, Min = 6, Max = 14 },
			Drops = { { Item = "bandage", Chance = 0.6, Min = 1, Max = 2 }, { Item = "grave_cloth", Chance = 0.5, Min = 1, Max = 3 } },
			Sound = {
				Chance = 1.0,
				Pool = {
					{ Item = "oil_pot", Weight = 25, Min = 1, Max = 1 },
					{ Item = "hearty_dish", Weight = 25, Min = 1, Max = 1 },
					{ Item = "grave_silver", Weight = 30, Min = 1, Max = 2 },
					{ Item = "tallow", Weight = 20, Min = 2, Max = 3 },
				},
			},
		},

		-- The three papers of the keep: a star shard, and a stirrup nobody has ridden in for forty years.
		deed_keep_papers = {
			Always = { { Item = "star_shard", Min = 1, Max = 1 }, { Item = "brass_stirrup", Min = 1, Max = 1 }, { Item = "page_keep_papers", Min = 1, Max = 1 } },
		},
		deed_smithy_planks = {
			Always = { { Item = "tallow", Min = 2, Max = 3 }, { Item = "rusted_iron", Min = 2, Max = 4 }, { Item = "page_smithy_tally", Min = 1, Max = 1 } },
			Sound = { Chance = 1.0, Pool = { { Item = "oil_pot", Weight = 1, Min = 1, Max = 2 }, { Item = "hearty_dish", Weight = 1, Min = 1, Max = 1 } } },
		},
		-- The Kitchens' cellar: the larder's chest is the ordinary reward, the hoard under the Dairy the one worth the crawl.
		deed_kitchen_larder = {
			Always = { { Item = "bandage", Min = 2, Max = 3 }, { Item = "tallow", Min = 2, Max = 3 }, { Item = "hearty_dish", Min = 1, Max = 1 } },
		},
		deed_kitchen_hoard = {
			Always = { { Item = "grave_silver", Min = 3, Max = 4 }, { Item = "hollow_ember", Min = 1, Max = 1 } },
			Sound = { Chance = 0.5, Pool = { { Item = "oil_pot", Weight = 1, Min = 1, Max = 2 } } },
		},
		-- The nine pages of the Catacombs, all read.
		deed_catacomb_pages = {
			Always = { { Item = "grave_silver", Min = 3, Max = 4 }, { Item = "saints_medal", Min = 1, Max = 1 } },
		},
		-- A cache in a crawl pocket: a refuge with a little in it.
		catacomb_pocket = {
			Gold = { Chance = 0.7, Min = 3, Max = 8 },
			Drops = {
				{ Item = "bandage", Chance = 0.7, Min = 1, Max = 2 },
				{ Item = "tallow", Chance = 0.5, Min = 1, Max = 2 },
				{ Item = "oil_pot", Chance = 0.25, Min = 1, Max = 1 },
				{ Item = "bone_dust", Chance = 0.5, Min = 1, Max = 3 },
			},
		},
		deed_graveyard_bell = {
			Always = {
				{ Item = "grave_silver", Min = 3, Max = 5 },
				{ Item = "saints_medal", Min = 1, Max = 1 },
				{ Item = "page_graveyard_bell", Min = 1, Max = 1 },
			},
		},
	},
}

return table.freeze(Loot)
