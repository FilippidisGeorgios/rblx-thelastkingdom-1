--[[
	Config: Audio (2026-11-14)
	The quiet sounds the developer asked for: "when a player hits a zombie, a very quiet sound; a very quiet sound all
	through the game; and when someone draws his sword to fight, very light, barely heard."

	Played by Client/Controllers/AudioController. Volumes are of a Sound (0..1); they are kept LOW on purpose.
	Every id is a Roblox audio asset. The ones marked PSE are from Pro Sound Effects, Roblox's licensed library (free to
	use in any experience). An id can be swapped here without touching code (the ElevenLabs set made for the game will
	take these places when it is uploaded: docs/systems/Sound.md).

	Read via: Config.get("Audio")
]]

local Audio = {
	-- all through the game: a low drone under the ground and a far wind, both barely there
	Ambient = {
		{ Id = "rbxassetid://9114353261", Volume = 0.05, Speed = 0.92 }, -- PSE: a deep, uneasy rumble
		{ Id = "rbxassetid://9125742262", Volume = 0.035, Speed = 0.7 }, -- PSE: airy, windy, constant (slowed: a far wind)
	},
	AmbientFadeSeconds = 6, -- it comes up slowly after the loading screen

	-- a blow that lands on one of the dead: a muffled thud at the body, heard by whoever is near
	Hit = {
		Ids = { "rbxassetid://138812618450834" },
		Volume = 0.16,
		PitchMin = 0.82,
		PitchMax = 1.05,
		RollOffMax = 45, -- studs: beyond this it is not heard
		Gap = 0.06, -- seconds: two hits on one body closer than this make one sound
	},

	-- the sword comes out: steel on leather, close, very light
	Draw = {
		Id = "rbxassetid://9119747260", -- PSE: sword out of a scabbard
		Volume = 0.1,
		Kinds = { sword = true }, -- by configs/Gear.Weapons[id].Kind
		RollOffMax = 30,
	},
}

return table.freeze(Audio)
