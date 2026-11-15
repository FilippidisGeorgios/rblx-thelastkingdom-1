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
	2026-11-15, the developer: "put sound in the game, it has nothing so far" (every sound played, but at 0.035 to 0.16
	of full: inaudible), and then: "some letters are loud and some cannot be heard; medium to high; take away the
	zombies' sound; a general sound in the game, medium; a sound of lightning with the white flash; very quiet boot steps;
	and take away the blade at the start".

	EVERY NUMBER HERE WAS MEASURED (tools/SoundMeter: each clip played silently into an AudioAnalyzer; peak at volume 1,
	and where in the clip it strikes). A volume is the loudness wanted divided by the clip's own peak, so one clip that is
	quiet by nature (the far thunder, peak 0.19) is not lost beside one that is loud (the sword drawn, 1.0). `Start` skips
	a clip's silent lead (the book strikes 0.85 s in, the lightning cracks 1.4 s in) so the sound lands WITH its moment.
	Loudness aimed at (peak x volume): the world under everything about 0.03 of loudness, steps 0.06, a blow 0.4, a
	swing 0.3, the letters 0.45, the title and the lightning 0.4 to 0.75.
]]
local Audio = {
	-- all through the game: a low drone under the ground and a far wind (mean loudness 0.058 and 0.035 at full)
	Ambient = {
		{ Id = "rbxassetid://9114353261", Volume = 0.55, Speed = 0.92 }, -- PSE: a deep, uneasy rumble
		{ Id = "rbxassetid://9125742262", Volume = 0.45, Speed = 0.7 }, -- PSE: airy, windy, constant (slowed: a far wind)
	},
	AmbientFadeSeconds = 6, -- it comes up slowly after the loading screen
	Hit = {
		Ids = { "rbxassetid://138812618450834" }, -- peak 0.91
		Volume = 0.45,
		PitchMin = 0.82,
		PitchMax = 1.05,
		RollOffMax = 45, -- studs: beyond this it is not heard
		Gap = 0.06, -- seconds: two hits on one body closer than this make one sound
	},
	-- a sword drawn to fight (not at a spawn, not when the scene gives it back: AudioController)
	Draw = {
		Id = "rbxassetid://9119747260", -- PSE: sword out of a scabbard (peak 1.0)
		Volume = 0.25,
		Kinds = { sword = true }, -- by configs/Gear.Weapons[id].Kind
		RollOffMax = 30,
	},
	-- a blade through the air, at every swing of every player (heard by all near)
	Swing = {
		Ids = { "rbxassetid://9120972321" }, -- PSE: whoosh, slicing air (peak 0.35; its twin was 0.14 and is gone)
		Volume = 0.85,
		PitchMin = 0.92,
		PitchMax = 1.12,
		RollOffMax = 40,
	},
	-- a foot coming down, every step of every player: boots on earth, VERY quiet (many players hear them all)
	Steps = {
		Ids = { "rbxassetid://9114523345", "rbxassetid://9114523358" }, -- PSE: a foot stomp, one each (peak 0.26, 0.31)
		Volume = 0.22,
		RunMult = 1.35, -- running is a little louder
		DuckMult = 0.35, -- crouched, hardly anything (that is what crouching is for)
		PitchMin = 0.78,
		PitchMax = 0.92, -- lower: heavier, duller
		RollOffMin = 3,
		RollOffMax = 26,
	},
	-- the screen's own sounds (flat, not in the world): Client/UI/Sfx
	Ui = {
		-- a typewriter key (ONE strike, 0.04 s into a 0.54 s clip, peak 0.81): every other letter of a line, the whole
		-- strike every time (it was cut at 0.07 s, and a sound starts a frame or two late: some letters lost it all)
		Type = { Id = "rbxassetid://9120299710", Volume = 0.55, PitchMin = 0.97, PitchMax = 1.06, Every = 2 },
		-- a leather-bound book opening (it strikes 0.85 s in, peak 0.33): a speaker's name appearing, the pack opening
		Name = { Id = "rbxassetid://9118835414", Start = 0.78, Volume = 0.9, PitchMin = 1.0, PitchMax = 1.06, Cut = 0.75 },
		Pack = { Id = "rbxassetid://9118835414", Start = 0.78, Volume = 0.8, PitchMin = 1.05, PitchMax = 1.12, Cut = 0.75 },
		-- a deep far blow as the title comes up (strikes 0.26 s in, peak 0.33)
		Title = { Id = "rbxassetid://9119388384", Start = 0.2, Volume = 1.2, PitchMin = 0.85, PitchMax = 0.85 },
		-- the lightning itself: a sharp hissing crack WITH the white flash (it cracks 1.4 s in, peak 0.72)
		Crack = { Id = "rbxassetid://9116282875", Start = 1.3, Volume = 1.0, PitchMin = 0.95, PitchMax = 1.05 },
		-- and the thunder rolling after it (peak 0.19 by nature: a high volume to be heard)
		Thunder = { Ids = { "rbxassetid://9113169432" }, Volume = 1.8, PitchMin = 0.85, PitchMax = 1.0, Delay = 0.7 },
	},
}

return table.freeze(Audio)
