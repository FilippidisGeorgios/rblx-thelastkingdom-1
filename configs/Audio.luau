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

--[[
	2026-11-15, the developer: "put sound in the game, it has nothing so far". Measured in play: every sound loaded and
	played, but at 0.035 to 0.16 of full they could not be heard at all. The volumes are raised (still under the world),
	and the game has more to say: a blade's swing, the dead groaning near you, and the screen's own sounds (`Ui`,
	played by Client/UI/Sfx): the letters of a line, a speaker's name, the title's blow, thunder after lightning, the pack.
]]
local Audio = {
	-- all through the game: a low drone under the ground and a far wind, quiet under the world
	Ambient = {
		{ Id = "rbxassetid://9114353261", Volume = 0.22, Speed = 0.92 }, -- PSE: a deep, uneasy rumble
		{ Id = "rbxassetid://9125742262", Volume = 0.15, Speed = 0.7 }, -- PSE: airy, windy, constant (slowed: a far wind)
	},
	AmbientFadeSeconds = 6, -- it comes up slowly after the loading screen

	-- a blow that lands on one of the dead: a muffled thud at the body, heard by whoever is near
	Hit = {
		Ids = { "rbxassetid://138812618450834" },
		Volume = 0.4,
		PitchMin = 0.82,
		PitchMax = 1.05,
		RollOffMax = 45, -- studs: beyond this it is not heard
		Gap = 0.06, -- seconds: two hits on one body closer than this make one sound
	},

	-- the sword comes out: steel on leather, close, very light
	Draw = {
		Id = "rbxassetid://9119747260", -- PSE: sword out of a scabbard
		Volume = 0.26,
		Kinds = { sword = true }, -- by configs/Gear.Weapons[id].Kind
		RollOffMax = 30,
	},
	-- a blade through the air, at every swing of every player (heard by all near)
	Swing = {
		Ids = { "rbxassetid://9120972321", "rbxassetid://9120972444" }, -- PSE: whoosh, slicing air, quick swing
		Volume = 0.32,
		PitchMin = 0.92,
		PitchMax = 1.18,
		RollOffMax = 40,
	},
	-- the dead groan now and then: one near you, at random, every few seconds
	Groan = {
		Ids = { "rbxassetid://9113980644", "rbxassetid://9113980319" }, -- PSE: creature growl, groan (slowed down)
		Volume = 0.34,
		PitchMin = 0.55,
		PitchMax = 0.8,
		EveryMin = 3.5,
		EveryMax = 8,
		Range = 70, -- studs from the eyes: only the dead this near groan
		RollOffMax = 60,
	},
	-- the screen's own sounds (flat, not in the world): Client/UI/Sfx
	Ui = {
		-- one key of a typewriter, cut short, for the letters of a line (every few letters, very light)
		Type = { Id = "rbxassetid://9120299710", Volume = 0.07, PitchMin = 0.95, PitchMax = 1.2, Cut = 0.07, Every = 3 },
		-- a leather-bound book opening: a speaker's name appearing, the pack opening
		Name = { Id = "rbxassetid://9118835414", Volume = 0.28, PitchMin = 1.0, PitchMax = 1.1, Cut = 0.9 },
		Pack = { Id = "rbxassetid://9118835414", Volume = 0.24, PitchMin = 1.05, PitchMax = 1.15, Cut = 0.9 },
		-- a deep far blow, as the title comes up
		Title = { Id = "rbxassetid://9119388384", Volume = 0.45, PitchMin = 0.85, PitchMax = 0.85 },
		-- thunder, a moment after the lightning (the light is faster)
		Thunder = { Ids = { "rbxassetid://9113169432" }, Volume = 0.55, PitchMin = 0.85, PitchMax = 1.0, Delay = 0.55 },
	},
}

return table.freeze(Audio)
