--!strict
--[[
	Config: Interactions
	Every place in the lobby a player can walk into and have something open:
	the storyteller, the blacksmith, the merchant, a reward chest.

	They are DATA, not code. Adding one means adding an entry here and placing a
	model with the matching name in Studio — no new script. The server draws the
	marker, notices the player, and tells the client which screen to open.

	The wagons keep their own rectangular zones (they are boxes you stand in);
	everything here gets a RING on the ground, because these are places you walk
	up to rather than climb into.

	Read via: Config.get("Interactions")
]]

local Interactions = {
	-- Shared look of the ground markers. Same gold as the boarding zones, so the
	-- whole lobby teaches one lesson: gold light means "step here".
	Marker = {
		Color = Color3.fromRGB(198, 158, 66),
		Segments = 40, -- pieces the ring is drawn from; higher is rounder
		Thickness = 0.45,
		Height = 0.1,
		LightBrightness = 1.6,
		LightRange = 16,
		PulseSeconds = 1.8,
	},

	PollSeconds = 0.3,

	-- How dialogue is delivered. Lines type themselves out and then hold, so the
	-- scene plays on its own like someone actually talking — the buttons are
	-- there for anyone who would rather set their own pace.
	Dialogue = {
		CharactersPerSecond = 46,
		FirstHoldSeconds = 2.5, -- the opening line gets longer to land
		HoldSeconds = 1.2, -- every line after it (sentences are short)
		AutoAdvance = true,

		-- Long lines need longer on screen than short ones, so the hold grows
		-- with the text instead of being written out per line: roughly one extra
		-- second for every line it wraps onto. Ignored once a line has a voice —
		-- there, the recording decides.
		CharactersPerLine = 70,
		ExtraSecondsPerLine = 1,

		-- A soft tick under the typing. Upload a short, quiet sound and paste its
		-- id here; empty means silence, which is better than a wrong sound.
		TypeSoundId = "",
		TypeSoundEvery = 3, -- characters between ticks
		TypeSoundVolume = 0.25,

		-- Roblox's built-in text-to-speech, used for any line that has no
		-- recording of its own. It is the stand-in until real takes are uploaded:
		-- a line with a `Sound` always wins. VoiceId is a string ("1", "2", …);
		-- Pitch is in semitones (-12..12), Speed 0.5..2. Lower and slower reads
		-- older. Set Enabled = false to go back to silence plus typing ticks.
		Voice = {
			Enabled = true,
			VoiceId = "1",
			Pitch = -4,
			Speed = 0.88,
		},
	},

	-- Each point: an object in `workspace.Lobby.<Folder>.<Name>` and the screen
	-- that opens when a player steps into its ring.
	Points = {
		{
			Id = "storyteller",
			Screen = "Dialogue",
			Folder = "NPCs",
			Name = "Storyteller",
			Radius = 8,

			-- Build the character from a real Roblox avatar instead of placing a
			-- model. Avatar data is public, so ANY user id works — the person does
			-- not have to be a collaborator, or even know. Set UserId to 0 to use
			-- whatever model is placed at `Folder.Name` instead.
			Avatar = {
				UserId = 2062889722,
				FaceAngle = 180, -- degrees, so he can be turned to face the camp
			},

			Dialogue = {
				Title = "THE VETERAN",
				--[[
					Provisional copy — the story beats are locked, the wording is not.

					A line may be a plain string, or a table with a `Sound`. Give a
					line a recording and the typing paces itself to that recording:
					the words finish as the voice does, and the scene holds until
					the line has been spoken rather than for a fixed count. Lines
					without one keep the default speed and hold.

					Record, upload at create.roblox.com/dashboard → Audio, wait for
					moderation, then paste the id below as "rbxassetid://123…".
				]]
				-- One sentence per entry: the veteran speaks in short breaths, and each
				-- one replaces the last on screen instead of piling up.
				Lines = {
					{ Text = "Forty years we held that line.", Sound = "rbxassetid://101107232381129" },
					{ Text = "Forty years of a war that was never ours.", Sound = "rbxassetid://136732612922129" },
					{ Text = "Word came in the spring.", Sound = "rbxassetid://115869856350611" },
					{ Text = "The kingdom has gone dark.", Sound = "rbxassetid://82737517940359" },
					{ Text = "And they say the king is no longer a king.", Sound = "rbxassetid://134608808928336" },
					{ Text = "I am too old for the road.", Sound = "rbxassetid://128155524035302" },
					{ Text = "You are not.", Sound = "rbxassetid://96383892343545" },
					{ Text = "Take a wagon.", Sound = "rbxassetid://92324325489643" },
					{ Text = "Take whoever will stand beside you.", Sound = "rbxassetid://74395856335429" },
					{ Text = "Go home, and see what is left of it.", Sound = "rbxassetid://108572114741903" },
				},
			},
		},

		{
			Id = "blacksmith",
			Screen = "Blacksmith",
			Folder = "NPCs",
			Name = "Blacksmith",
			Radius = 9,
			-- A hand-placed model already stands here, so no avatar is fetched.
			Avatar = { UserId = 0, FaceAngle = 0 },
		},

		-- The Chapel (docs/systems/Spoils.md §6.2): four tables, one screen. `Tab` is the one that
		-- opens first. Built by tools/BuildChapel into workspace.Lobby.Chapel; move the models
		-- wherever the chapel stands, the rings follow them.
		{ Id = "chapel_tithe", Screen = "Chapel", Tab = "Tithe", Folder = "Chapel", Name = "Tithe", Radius = 7 },
		{ Id = "chapel_reliquary", Screen = "Chapel", Tab = "Reliquary", Folder = "Chapel", Name = "Reliquary", Radius = 7 },
		{ Id = "chapel_altar", Screen = "Chapel", Tab = "Altar", Folder = "Chapel", Name = "Altar", Radius = 7 },
		{ Id = "chapel_journal", Screen = "Chapel", Tab = "Journal", Folder = "Chapel", Name = "Journal", Radius = 6 },
	},
}

return table.freeze(Interactions)
