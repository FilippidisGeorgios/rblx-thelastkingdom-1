--!strict
--[[
	Config: Difficulty

	TWO independent curves, multiplied together:

	  PlayerCount — how much harder it gets with more people in the party
	  Areas       — how much harder it gets as you go DEEPER into the castle

	They are separate on purpose. Party size changes how much the room can
	chew through; depth changes what the castle is willing to send. A solo
	player in area 8 and a party of four in area 2 should both be working hard,
	and only two numbers multiplied can say that.

	Read via: Config.get("Difficulty"). Values are PROVISIONAL.
]]

local Difficulty = {
	--======================================================================
	-- PLAYER COUNT
	--
	-- The "balanced, not linear" rule: more players => more and tougher
	-- enemies and better rewards, but roughly the SAME completion time.
	-- Eight players is NOT eight times the enemies — the multiplier tops out
	-- at 3.0, because eight people in one doorway are not eight times as
	-- effective either.
	--
	-- Schema:
	--   PlayerCount[count] = {
	--       EnemyCountMult, EnemyHealthMult, EliteWeight, RewardMult
	--   }
	--======================================================================
	PlayerCount = {
		[1] = { EnemyCountMult = 1.0, EnemyHealthMult = 1.0, EliteWeight = 0.0, RewardMult = 1.0 },
		[2] = { EnemyCountMult = 1.4, EnemyHealthMult = 1.1, EliteWeight = 0.1, RewardMult = 1.3 },
		[3] = { EnemyCountMult = 1.7, EnemyHealthMult = 1.15, EliteWeight = 0.15, RewardMult = 1.6 },
		[4] = { EnemyCountMult = 2.0, EnemyHealthMult = 1.2, EliteWeight = 0.2, RewardMult = 1.9 },
		[5] = { EnemyCountMult = 2.3, EnemyHealthMult = 1.25, EliteWeight = 0.25, RewardMult = 2.2 },
		[6] = { EnemyCountMult = 2.5, EnemyHealthMult = 1.3, EliteWeight = 0.3, RewardMult = 2.5 },
		[7] = { EnemyCountMult = 2.7, EnemyHealthMult = 1.35, EliteWeight = 0.35, RewardMult = 2.8 },
		[8] = { EnemyCountMult = 3.0, EnemyHealthMult = 1.4, EliteWeight = 0.4, RewardMult = 3.1 },
	},

	--======================================================================
	-- THE RUN, AREA BY AREA
	--
	-- This is the SHAPE of the game, written as numbers. Read the CountMult
	-- column down the page and you can see the run:
	--
	--     1-3   a ramp you can feel but not fear
	--       4   the turn — it gets aggressive, and the heavy weapons arrive
	--       5   THE SPIKE — the single biggest jump in the game
	--     6-8   relentless, no let-up
	--       9   the King
	--
	-- The step from 4 to 5 is +0.55, and every other step is between +0.15 and
	-- +0.30. That gap IS the design: area 5 is the smithy, it is the one place
	-- that makes you permanently stronger, and it has the mine and the loot —
	-- so it has to be the place that nearly takes you apart. A reward that
	-- costs nothing is not a reward.
	--
	-- `Unlocks` is the single source of truth for WHEN each enemy first
	-- appears. Content (Encounters/Waves) picks from what is unlocked; it does
	-- not get to introduce an archer in area 1.
	--
	-- Schema:
	--   Areas[index] = {
	--       Label, EnemyCountMult, EnemyHealthMult, EnemyDamageMult,
	--       Unlocks = { enemyId, ... },   -- FIRST seen here
	--   }
	--======================================================================
	Areas = {
		[1] = {
			Label = "Outer Ward",
			EnemyCountMult = 1.0,
			EnemyHealthMult = 1.0,
			EnemyDamageMult = 1.0,
			Unlocks = { "undead_shambler" },
		},
		[2] = {
			Label = "Stables",
			EnemyCountMult = 1.15,
			EnemyHealthMult = 1.05,
			EnemyDamageMult = 1.05,
			Unlocks = { "undead_runner" },
		},
		[3] = {
			Label = "Kitchens",
			EnemyCountMult = 1.3,
			EnemyHealthMult = 1.1,
			EnemyDamageMult = 1.1,
			Unlocks = {},
		},
		[4] = {
			-- The turn. Heavy weapons, and the graveyard keeps producing.
			Label = "Graveyard",
			EnemyCountMult = 1.55,
			EnemyHealthMult = 1.25,
			EnemyDamageMult = 1.2,
			Unlocks = { "undead_brute_heavy" },
		},
		[5] = {
			-- THE SPIKE. Reach and range arrive in the same room.
			Label = "Smithy",
			EnemyCountMult = 2.1,
			EnemyHealthMult = 1.5,
			EnemyDamageMult = 1.45,
			Unlocks = { "undead_spearman", "undead_archer" },
		},
		[6] = {
			Label = "Great Hall",
			EnemyCountMult = 2.4,
			EnemyHealthMult = 1.7,
			EnemyDamageMult = 1.6,
			Unlocks = {},
		},
		[7] = {
			Label = "The Rows",
			EnemyCountMult = 2.6,
			EnemyHealthMult = 1.85,
			EnemyDamageMult = 1.7,
			Unlocks = {},
		},
		[8] = {
			Label = "Inner Ward",
			EnemyCountMult = 2.85,
			EnemyHealthMult = 2.0,
			EnemyDamageMult = 1.85,
			Unlocks = {},
		},
		[9] = {
			Label = "Keep Steps",
			EnemyCountMult = 3.0,
			EnemyHealthMult = 2.2,
			EnemyDamageMult = 2.0,
			Unlocks = { "the_king" },
		},
	},

	--[[
		Party-size tiers, ascending: a group of `count` players gets the first
		tier whose `maxPlayers` it fits into. Shown in the lobby when boarding
		and carried across in the teleport payload.
	]]
	Tiers = {
		{ id = "Normal", maxPlayers = 4 },
		{ id = "Hard", maxPlayers = 8 },
	},

	--[[
		DANGER: the third curve, on top of the party size and the depth. One number from 0 to 100 that the train
		shows ("+34 of 100 harder") and the run uses (Shared/Danger, Shared/Scaling.setRunDanger).

		It has two parts:
		  the mode      Hard adds `Mode.Hard` points. A party of 5 or more is Hard whatever it chooses; a smaller
		                one may choose Hard, never the other way round (a big party cannot play Normal).
		  the veterans  the AVERAGE level of the party, from level 1 (0 points) to MaxLevel (`LevelPoints`). So a
		                pair of level-100 players is +100, and a level-50 pair about +50.

		THE SHIELD keeps a new player from being buried by their friends' levels. The third-weakest player of the
		party decides it: if three or more are rookies (level 5 or less) only `Keep` (15%) of the veterans' points
		count; from level 5 to level 20 of that third player the shield fades out (a third player at level 12 keeps
		about half), and from level 20 the average counts in full. Fewer than three players is never shielded: two
		level-0 players among veterans still take the average, as they chose to.
		  Example: four level-0 and four level-100 players, an average of 50, three or more rookies: the veterans
		  add 50 x 0.15 = 7.5 points, plus Hard's 25 for eight players.

		`AtFull` is what the enemies get at 100 points; any lower is a share of it. Health and numbers only: damage is
		left alone so a hard run is long and tense, not a run where one hit is a down. Provisional, like all of this.
	]]
	Danger = {
		Max = 100,
		MaxLevel = 100,
		LevelPoints = 100, -- the points of a party whose average level is MaxLevel
		Mode = { Normal = 0, Hard = 25 },
		Shield = { Need = 3, RookieBelow = 5, FreeFrom = 20, Keep = 0.15 },
		AtFull = { EnemyHealth = 0.6, EnemyCount = 0.4, Elite = 0.2, Reward = 0.5 },
	},
}

return table.freeze(Difficulty)
