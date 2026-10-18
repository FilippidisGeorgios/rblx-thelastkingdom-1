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

	-- Skip: a vote. Alone, one press. In a party, more than half.
	SkipShare = 0.5,

	--[[
		The scene, in order. Each beat moves the camera from one mark to another
		over `Seconds`, and may carry one spoken line. A beat lasts exactly
		`Seconds` (the line must fit), so every client and the server agree on the
		running time without talking to each other.
	]]
	Beats = {
		{ From = "Cam1", To = "Cam2", Seconds = 9 },
		{ From = "Cam2", To = "Cam2", Seconds = 5.5, Line = "There it is. Asterfall." },
		{ From = "Cam3", To = "Cam3", Seconds = 6, Line = "Forty years. I remember a banner on every tower." },
		{ From = "Cam3", To = "Cam3", Seconds = 6, Line = "No banners now. No smoke from the kitchens. Nothing." },
		{ From = "Cam4", To = "Cam4", Seconds = 6, Line = "The bridge is down. Nobody ever left that bridge down." },
		{ From = "Cam4", To = "Cam4", Seconds = 5.5, Line = "Something is still moving behind those walls." },
		{ From = "Cam5", To = "Cam6", Seconds = 8, Line = "Whatever waits in there, we go in together." },
	},
}

return table.freeze(Intro)
