--!strict
--[[
	Config: Experience
	Character progression: how much XP each level costs, what earns XP, and where the prizes sit.
	("Experience" here means XP/levels, distinct from the Roblox "experience".)

	Read via: Config.get("Experience"). Values are PROVISIONAL (tuned in the Balance phase).

	THE CURVE (level 100 is the top, and the way there is meant to be long):
	  levels  1 to 30   EASY. The cost grows 12% a level from 60 XP: the first ten levels take a handful of kills
	                    each, level 20 costs about 500 XP, level 30 about 1,600. A first-timer climbs through
	                    these in the first few runs.
	  levels 31 to 100  HARD. Each level costs 4% more than the last, with nothing to soften it: level 50 costs
	                    3,500 XP, level 75 about 9,000, level 99 about 24,000. At the sources below (a full
	                    victory is worth about 2,300 XP) the second half is dozens of runs, not a few.
	  Whole way: about 12,900 XP to reach level 30 and about 600,000 to reach level 100.

	Change the five numbers in `Curve`, not the table: it is built from them.

	Schema:
		MaxLevel     = number,
		XpToLevel    = { number },              -- XpToLevel[level] = XP to reach level+1
		Sources      = what a run pays, per player (Domain/RunXp)
		Milestones   = where the prizes are (Domain/LevelMilestones); `LevelRewards[level]` is what is given
]]

local Curve = {
	MaxLevel = 100,
	Base = 60, -- XP from level 1 to 2
	EarlyGrowth = 1.12, -- per level, up to EarlyUntil
	EarlyUntil = 30,
	LateGrowth = 1.04, -- per level, after it
}

local function build(): { number }
	local table_: { number } = {}
	local atTurn = Curve.Base * Curve.EarlyGrowth ^ (Curve.EarlyUntil - 1)
	for level = 1, Curve.MaxLevel - 1 do
		local xp = if level <= Curve.EarlyUntil
			then Curve.Base * Curve.EarlyGrowth ^ (level - 1)
			else atTurn * Curve.LateGrowth ^ (level - Curve.EarlyUntil)
		table_[level] = math.floor(xp / 5 + 0.5) * 5 -- tidy: whole fives
	end
	return table_
end

local Experience = {
	MaxLevel = Curve.MaxLevel,
	Curve = Curve,
	-- XP to go FROM this level to the next (index = level).
	XpToLevel = build(),

	--[[
		What a run pays each player when it ends (a win OR a wipe: progress persists). Chamber `n`
		pays `Chamber.Base + Chamber.PerChamber * n` the first time the party clears it in the run.
	]]
	Sources = {
		Kill = { Standard = 2, Elite = 8, Boss = 60 }, -- by the Tier of the enemy slain (configs/Enemies)
		Chamber = { Base = 30, PerChamber = 10 },
		Deed = 60, -- each deed done in the run (the party shares it)
		Won = 300, -- the castle is taken
	},

	--[[
		A prize at every `RewardEvery`th level, and a milestone (a new rank, a bigger prize) at every
		`MilestoneEvery`th. What the prizes ARE is not decided yet: `LevelRewards[level]` stays empty
		until it is, and the Muster Roll shows the road with its prizes "being forged".
	]]
	Milestones = {
		RewardEvery = 5,
		MilestoneEvery = 10,
	},
	LevelRewards = {},
}

return table.freeze(Experience)
