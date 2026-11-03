--!strict
--[[
	Config: RetiredTrials
	Trials that are no longer played, kept so that nothing is lost. Nothing reads this file.

	[4] The Graveyard, "carry the fire": four braziers, graves that open section by section, the belfry bell. It gave its place to the
	Catacombs (2026-10-31, docs/systems/Catacombs.md): the burying ground is still in the yard behind the mountain, but its trial
	is not run. To bring it back, move this entry into `Trials.luau` and say what happens to the Catacombs.

	[6] The Great Hall, "the siege": board the four doors with planks, then hold the hall against three waves. It gave its place to the
	King's Wood (2026-11-03, docs/systems/Forest.md): the hall and its yard were moved to `ServerStorage.Assets.Retired.Area6`.
]]

local RetiredTrials = {
	--======================================================================
	-- 4 — Graveyard. Carry the fire.
	--
	-- Four braziers, one to each section of the burying ground. A torch burns
	-- for 25 seconds and is lit at the chapel altar (or at a brazier already
	-- alight); the braziers are 36 to 150 studs from it. Each section's graves
	-- keep giving up the dead until ITS brazier burns, so the order you light
	-- them in is the whole decision.
	--======================================================================
	[4] = {
		phases = {
			{
				id = "fire",
				hint = "Carry fire from the chapel to the braziers (%d of %d)",
				tasks = {
					{
						id = "braziers",
						kind = "light",
						braziers = "Decorations.Area4.GraveBraziers",
						sources = { "Decorations.Area4.Chapel.Altar" },
						torchSeconds = 25,
						holdSeconds = 2.2,
						sourceHoldSeconds = 0.7,
					},
				},
			},
		},

		pressure = {
			{
				id = "graves",
				kind = "rising",
				from = "start",
				braziers = "Decorations.Area4.GraveBraziers",
				graves = { "Decorations.Area4.NewGraves", "Decorations.Area4.Churchyard" },
				gravesPerSection = 6, -- graves in each section that can open
				interval = 9, -- seconds between pulses in a section
				burst = 2, -- the dead per pulse (before the party / depth curve)
				cap = 7, -- alive from one section at once (before the curve)
				stagger = 5, -- sections wake this many seconds apart
				enemies = {
					{ id = "undead_shambler", weight = 3 },
					{ id = "undead_runner", weight = 1 },
				},
				-- Every Nth pulse in a section carries a Gravedigger: the first heavy weapons.
				heavy = { id = "undead_brute_heavy", every = 4 },
			},
		},

		deeds = {
			{
				id = "bell",
				kind = "toll",
				rope = "Decorations.Area4.Belfry.BellRope",
				bell = "Decorations.Area4.Belfry.Bell",
				prize = "deed_graveyard_bell",
				-- What answers the bell: the hardest hour of the chamber.
				answer = {
					{ id = "undead_shambler", count = 5 },
					{ id = "undead_runner", count = 3 },
					{ id = "undead_brute_heavy", count = 1 },
				},
			},
		},
	},

	--======================================================================
	-- 6 — Great Hall. The siege.
	--
	-- The hall has four doorways and, on the Great Hall's own terms, a pause:
	-- 75 seconds in which to fetch planks and nail the doors (up to six a door,
	-- four seal it), then a horn, then three waves of spearmen and archers that
	-- come to the DOORS and break them. The barricades are things the dead
	-- attack, so the boards are health, not decoration. Boarding is a deed
	-- (nothing waits on it); the gate rises when the siege is cleared.
	--======================================================================
	[6] = {
		ownsWaves = true,

		phases = {
			{
				id = "hold",
				hint = "Board the doors, then hold the hall",
				tasks = {
					{ id = "siege", kind = "siege", encounter = "area_6", grace = 75 },
				},
			},
		},

		pressure = {},

		deeds = {
			{
				id = "boards",
				kind = "board",
				hall = "Decorations.Area6.GreatHall",
				maxPlanks = 6,
				sealPlanks = 4,
				healthPerPlank = 150,
				nailHold = 1.1,
				racks = { { door = 2, planks = 8 }, { door = 4, planks = 8 } },
			},
		},
	},
}

return table.freeze(RetiredTrials)
