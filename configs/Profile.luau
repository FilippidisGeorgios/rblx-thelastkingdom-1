--!strict
--[[
	Config: Profile
	The words and bands on the player's own page, the MUSTER ROLL (docs/systems/Profile.md,
	Server/Domain/PlayerCard, Server/Hub/ProfileService, Client/UI/ProfileUI).

	Nothing here is a rule of the game: the Roll only SHOWS what the profile already holds and what the
	difficulty already does with it. MIGHT is Server/Domain/TeamPower's rating (it is what sets how hard a
	run is); RENOWN is the standing of the whole player (it sets nothing: it is for the Roll, the train and
	the admin panel). The curve Might reads is the forge's (configs/Economy.Upgrades.Weapon).

	Read via: Config.get("Profile")
]]

local Profile = {
	-- A rank for each stretch of levels: the title at the highest `Level` the player has reached.
	-- A new rank at every 10th level, which is also where the milestones are (configs/Experience).
	Titles = {
		{ Level = 1, Name = "Recruit" },
		{ Level = 10, Name = "Footman" },
		{ Level = 20, Name = "Man-at-Arms" },
		{ Level = 30, Name = "Sergeant" },
		{ Level = 40, Name = "Standard-Bearer" },
		{ Level = 50, Name = "Knight-Errant" },
		{ Level = 60, Name = "Banneret" },
		{ Level = 70, Name = "Castellan" },
		{ Level = 80, Name = "Marshal" },
		{ Level = 90, Name = "Lord Marshal" },
		{ Level = 100, Name = "Warden of the Last Kingdom" },
	},

	-- What a Might rating is called, ascending: the first band whose `maxRating` it fits under.
	MightTiers = {
		{ id = "Raw", maxRating = 2 },
		{ id = "Blooded", maxRating = 4 },
		{ id = "Seasoned", maxRating = 6 },
		{ id = "Hardened", maxRating = 8 },
		{ id = "Veteran", maxRating = 10 },
	},

	--[[
		RENOWN: the whole player in one number, out of the sum of the caps (about 9,500). Every part is
		CAPPED, so no single thing can make a standing: grinding kills for ever tops out at 500 points, and
		the biggest parts (rank, might, victories) are the ones that take real progress. A part is
		`Per` points for each unit above `Offset`, never more than `Cap`.

		  Unit   the number on the card it counts (Domain/Renown.Inputs)
		  Flag   a yes/no that adds `FlagPoints` (the Falling Star raised)
	]]
	Renown = {
		Parts = {
			{ id = "rank", Label = "Rank", Unit = "level", Offset = 1, Per = 25, Cap = 2475 },
			{ id = "might", Label = "Might", Unit = "might", Offset = 1, Per = 150, Cap = 1350 },
			{ id = "victories", Label = "Victories", Unit = "runsWon", Offset = 0, Per = 75, Cap = 1500 },
			{ id = "depth", Label = "Depth", Unit = "deepest", Offset = 0, Per = 100, Cap = 900 },
			{ id = "deeds", Label = "Deeds", Unit = "deeds", Offset = 0, Per = 40, Cap = 1000 },
			{ id = "lore", Label = "Lore", Unit = "pages", Offset = 0, Per = 100, Cap = 1000 },
			{ id = "star", Label = "The Star", Unit = "shards", Offset = 0, Per = 50, Cap = 750, Flag = "starRaised", FlagPoints = 300 },
			{ id = "slaying", Label = "Slaying", Unit = "kills", Offset = 0, Per = 0.05, Cap = 500 },
		},
		-- ascending by points: the first band the total fits under
		Tiers = {
			{ id = "Unknown", maxPoints = 250 },
			{ id = "Known", maxPoints = 1000 },
			{ id = "Respected", maxPoints = 2500 },
			{ id = "Renowned", maxPoints = 4500 },
			{ id = "Famed", maxPoints = 7000 },
			{ id = "Legendary", maxPoints = math.huge },
		},
	},
}

return table.freeze(Profile)
