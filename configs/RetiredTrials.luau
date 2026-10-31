--!strict
--[[
	Config: RetiredTrials
	Trials that are no longer played, kept so that nothing is lost. Nothing reads this file.

	[4] The Graveyard, "carry the fire": four braziers, graves that open section by section, the belfry bell. It gave its place to the
	Catacombs (2026-10-31, docs/systems/Catacombs.md): the burying ground is still in the yard behind the mountain, but its trial
	is not run. To bring it back, move this entry into `Trials.luau` and say what happens to the Catacombs.
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
}

return table.freeze(RetiredTrials)
