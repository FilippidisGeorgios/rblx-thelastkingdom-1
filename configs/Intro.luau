--!strict
--[[
	Config: Intro
	The arrival scene in the Forgotten Lands. The party stands on the hill in
	front of the castle, sees it for the first time in forty years, and talks
	about it. Then the screen goes dark and they are standing inside the gate.

	It is DATA: the lines, who may say them, the shots and their timing. The
	server (`Server/World/IntroService`) decides who is in the scene and who says
	which line; every client plays the same timeline from the same data.

	WHERE THINGS ARE. The stand marks and camera marks are parts in
	`Workspace.Gameplay.Surroundings.Intro` (Stand1..6, Cam1..6), built by
	`tools/BuildSurroundings.luau`. A camera mark's CFrame IS the camera, so a shot
	is re-framed by moving its part in Studio — nothing here changes.

	WHO SPEAKS. Each line is said by one of the players in the scene, shown by the
	name they chose on Roblox (DisplayName), never their username. The order is
	shuffled per run, so it is a different person each time; alone, the one player
	says everything (a returning soldier talking to himself is the right note).

	Read via: Config.get("Intro")
]]

local Intro = {
	Enabled = true,

	-- How long the server waits for a teleported party to finish loading before
	-- it starts the scene without the stragglers (they spawn straight in).
	WaitForPartySeconds = 10,

	-- After the party is here: how long the scene waits for every player's loading screen to be gone before it
	-- begins. (A player whose screen never reports is left behind after this; they spawn straight in.)
	WaitForLoadingSeconds = 30,

	-- Typing speed of a line, and how long it holds once written.
	CharactersPerSecond = 34,
	HoldSeconds = 1.8,

	-- Opening card, over black.
	Title = "THE FORGOTTEN LANDS",
	Subtitle = "Forty years after the march north",
	TitleSeconds = 4.5,

	FadeInSeconds = 2.5,
	FadeOutSeconds = 1.4,

	-- Field of view for the scene: narrower than play, so the castle sits large
	-- in frame and the hill reads as far away.
	FieldOfView = 50,

	--[[
		SKIPPING. A player holds the SKIP button for `SkipHoldSeconds` (a tap does nothing). The scene is skipped
		when enough of the party have held it: `SkipVotes[n]` is how many are needed when n players are in the
		scene (the developer's table: 1 of 1, 2 of 2, 2 of 3, 3 of 4, 3 of 5, 4 of 6, 5 of 7, 5 of 8, 6 of 9,
		7 of 10). Past the end of the table, `SkipOverflowShare` of the party is asked for.
	]]
	SkipHoldSeconds = 3,
	SkipVotes = { 1, 2, 2, 3, 3, 4, 5, 5, 6, 7 },
	SkipOverflowShare = 0.7,

	--[[
		How the picture is focused in each kind of shot (the lens in `UI/IntroCinema`). Distance is how far from the
		camera is sharp, Radius how deep the sharp zone is, Near and Far how much blur there is in front of it and
		behind it (0 = none, 1 = a lot). A wide shot is sharp all through; the shoulder shot lets the speaker's head
		go soft so the castle is the picture; the face shot lets everything behind the face fall away.
	]]
	Focus = {
		Marks = { Distance = 300, Radius = 300, Near = 0, Far = 0 },
		Shoulder = { Distance = 140, Radius = 70, Near = 0.3, Far = 0 },
		Face = { Distance = 8.2, Radius = 3, Near = 0, Far = 0.8 },
	},

	--[[
		The scene, in order. A beat lasts exactly `Seconds` (a line must fit), so every client and the server
		agree on the running time without talking to each other. Each beat has a SHOT:

		  Marks     (the default) the camera moves from the mark `From` to the mark `To`, eased. Where they are the
		            same mark, it drifts forward a little: a camera that does not move reads as a stopped game.
		  Shoulder  over the speaker's shoulder, looking at what they look at; needs a `Line` (it is the speaker's
		            shoulder). Falls back to `From` / `To` if the speaker cannot be found.
		  Face      the speaker's face, three-quarters, from `Side` 1 or -1; falls back the same way.

		Other things a beat may carry: `Line` (spoken) and `Flash` (seconds into the beat at which lightning flashes).
	]]
	Beats = {
		-- the long look, coming over the land toward the walls
		{ From = "Cam1", To = "Cam2", Seconds = 9 },
		{ Shot = "Shoulder", From = "Cam2", To = "Cam2", Seconds = 5.5, Line = "There it is. Asterfall." },
		{ Shot = "Face", Side = 1, From = "Cam3", To = "Cam3", Seconds = 6, Line = "Forty years. I remember a banner on every tower." },
		{ From = "Cam3", To = "Cam3", Seconds = 6, Line = "No banners now. No smoke from the kitchens. Nothing." },
		{ Shot = "Shoulder", From = "Cam4", To = "Cam4", Seconds = 6, Line = "The bridge is down. Nobody ever left that bridge down." },
		{ Shot = "Face", Side = -1, From = "Cam4", To = "Cam4", Seconds = 5.5, Line = "Something is still moving behind those walls.", Flash = 3.4 },
		{ From = "Cam5", To = "Cam6", Seconds = 8, Line = "Whatever waits in there, we go in together." },
	},
}

return table.freeze(Intro)
