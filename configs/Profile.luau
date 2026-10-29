--!strict
--[[
	Config: Profile
	The words and bands on the player's own page, the MUSTER ROLL (docs/systems/Profile.md,
	Server/Domain/PlayerCard, Server/Hub/ProfileService, Client/UI/ProfileUI).

	Nothing here is a rule of the game: the Roll only SHOWS what the profile already holds and what the
	difficulty already does with it. The rating ("Might") is Server/Domain/TeamPower's, the curve it reads
	is the forge's (configs/Economy.Upgrades.Weapon), so editing a number there changes the Roll too.

	Read via: Config.get("Profile")
]]

local Profile = {
	-- A title for each character level, 1 up. Past the end, the last one.
	Titles = {
		"Recruit",
		"Footman",
		"Man-at-Arms",
		"Sergeant",
		"Standard-Bearer",
		"Knight-Errant",
		"Banneret",
		"Castellan",
		"Marshal",
		"Warden of the Last Kingdom",
	},

	-- What a Might rating is called, ascending: the first band whose `maxRating` it fits under.
	MightTiers = {
		{ id = "Raw", maxRating = 2 },
		{ id = "Blooded", maxRating = 4 },
		{ id = "Seasoned", maxRating = 6 },
		{ id = "Hardened", maxRating = 8 },
		{ id = "Veteran", maxRating = 10 },
	},
}

return table.freeze(Profile)
