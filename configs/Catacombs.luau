--!strict
--[[
	Config: Catacombs
	The numbers of area 4, the Catacombs (docs/systems/Catacombs.md): how big the passages are, how loud things are, how the
	big blind dead one listens, how many crawlers, what the papers say. The floor plan itself is `CatacombsMaze.luau`.

	WORDS. *Cell* = one square of the floor plan (10.5 studs). *Passage* = a corridor, 7 wide and 7.6 high: two wide
	avatars side by side, a little over a head. *Crawl* = an opening 3.4 high that only a crouching body fits (the big one
	cannot go there, so a crawl is a place to hide). *The Doctor* = the big blind dead one (a plague doctor who was
	experimented on). *Noise* = anything that can be heard: the Doctor goes to the loudest thing he heard last.

	Read via: Config.get("Catacombs")
]]

local Catacombs = {
	-- The area it replaces: the Graveyard (the old trial is kept in `RetiredTrials`).
	Area = 4,

	--======================================================================
	-- WHERE THE PLAN STANDS (studs). The plan lies under the yard of area 4, far under the ground: the ground there is
	-- solid down to y -46, the floor is at -70 and the ceiling slab ends at -54, so nothing of the yard shows through.
	--======================================================================
	Layout = {
		Unit = 3.5, -- one block of wall or half a passage; a cell is 3 units (2 open + 1 of wall)
		X0 = -133, -- west edge of the plan
		ZTop = -758.75, -- north edge of the plan (south is -z)
		FloorY = -70, -- top of the floor
		PassageHeight = 7.6, -- clear height of a passage
		CrawlHeight = 3.4, -- clear height of a crawl (crouched body about 3.0)
		Slab = 4, -- thickness of floor and ceiling
	},

	-- The two deep stairs: round shafts with a spiral stair round an open well. They go from the ground (y 2) to the floor.
	Stairs = {
		-- Turns is NOT a round number on purpose: the last step must stand IN the doorway at the foot (west, 180 degrees, for the
		-- way down; east, 0 degrees, for the way up), and the first step leaves the top landing (north, 90; south, 270).
		-- 2.75 turns clockwise from 90 ends at 180; 3.25 turns counter-clockwise from 270 ends at 0.
		Down = { X = 141, Z = -786.75, Radius = 14, Well = 6, Top = 2, Bottom = -70, Turns = 2.75, Clockwise = true },
		Up = { X = -152, Z = -923.25, Radius = 14, Well = 6, Top = 2, Bottom = -70, Turns = 3.25, Clockwise = false },
		Width = 7, -- the walking width of a stair
		BrokenShare = 0.14, -- share of the planks missing or hanging (the walk itself is never broken)
	},

	-- The mountain that shuts the yard: from wall to wall, across the yard, with one cave in it.
	Mountain = {
		FrontZ = -772, -- its face
		Depth = 46, -- from the face to where it ends behind
		Height = 86, -- at the face
		Cave = { X = 141, Width = 9 }, -- the way in
		BarrierHeight = 150, -- the invisible wall in front of the face (the developer asked for one: nobody climbs over)
		HalfWidth = 171, -- wall to wall
	},

	--======================================================================
	-- LIGHT AND DARK
	--======================================================================
	-- Below this height (studs) nothing a body carries gives light but the lantern: a blade's glow is put out (LanternService).
	DarkBelow = -20,
	-- The lantern the table gives (it is carried for the rest of the run: the forest will need it).
	Lantern = {
		Item = "lantern",
		Range = 30, -- studs of light round the bearer
		Brightness = 2.6,
		Color = Color3.fromRGB(255, 190, 110),
		Shadows = true, -- the walls stop the light (without it the maze would glow through its walls)
	},
	-- What a candle, a lamp at a table or a brazier gives: only near.
	Candle = { Range = 7, Brightness = 1.2, Color = Color3.fromRGB(255, 176, 96) },

	--======================================================================
	-- NOISE. Every number is "how far the sound carries along the passages, in studs". Walls stop it, so a loud noise in
	-- the next corridor is far away for the Doctor; he walks the passages, not the line through the stone.
	--======================================================================
	Noise = {
		StepWalk = 36, -- an upright body walking
		StepRun = 52, -- running (speed over RunSpeed)
		StepCrouch = 7, -- a crouched body: nearly nothing
		RunSpeed = 17,
		Jump = 24,
		Swing = 30, -- a swing of a weapon
		Hit = 42, -- a blow that lands
		Kill = 64, -- a dead one going down
		Chop = 90,
		Lever = 60,
		Key = 34, -- the lock of the iron door
		Chest = 20,
		Bell = 130, -- a bell pulled: heard far, at the bell
		Touch = 4, -- anything this close is noticed whatever it does (breath, cloth, warmth)
		-- how often a moving body makes its sound (seconds), and the loudest one remembered counts for this long
		StepEvery = 0.45,
		Remember = 9,
	},

	--======================================================================
	-- THE DOCTOR (the big blind one)
	--======================================================================
	Doctor = {
		Id = "plague_doctor",
		Height = 6.9, -- studs, standing: fits a 7.6 passage with a hand of air
		Width = 4.6, -- shoulder to shoulder: two slim avatars, or one in the middle of a passage
		MaxHealth = 1500,
		Speeds = { Prowl = 6, Investigate = 10, Chase = 13 }, -- studs a second (a crouching player does 8, a walking one 16)
		AttackRange = 6.5,
		AttackDamage = 45,
		Windup = 0.9,
		Strike = 0.2,
		Recover = 1.5,
		SearchSeconds = 8, -- he stands and listens where the noise was
		ListenSeconds = 3, -- a breath at each stop of his round
		ChaseCells = 7, -- he takes up the chase of a body he keeps hearing within this many cells
		-- the cells he walks between when he hears nothing (a round of the middle of the plan); filled from the plan at start
		RoundStops = 8,
		-- The Doctor wakes when the first of the party reaches the foot of the stair and he is put at the far side.
		SpawnHall = "study",
		Prize = "deed_catacomb_doctor",
	},

	--======================================================================
	-- THE CRAWLERS (the ones that go low), the same all over the plan: this many, each in a niche, a pocket or a corner
	--======================================================================
	Crawlers = {
		Count = 14, -- for one player; more players, more (Scaling)
		Detection = 24, -- they notice you only this close (the dark makes the dead nearsighted too)
		Wake = 18, -- they stay still until a player is this close
	},

	--======================================================================
	-- THE ERRAND (the order is fixed, the places are rolled each run)
	--======================================================================
	Errand = {
		Levers = 3, -- pulled in three wings: they lift the iron gate on the exit road
		BarricadeBlows = 8, -- strokes of the axe on the fallen beams (each hold is one, and every one is loud)
		BlowHold = 1.0,
		LeverHold = 1.6,
		SearchHold = 1.4,
		BellHold = 0.8,
		BellCooldown = 40,
		KeyItem = "catacomb_key",
		AxeItem = "catacomb_axe",
		LanternHold = 1.0,
	},

	-- Where each thing may lie (ids of the plan's features). One of each list holds the key and the axe, each run.
	Spots = {
		Key = { "key_ward1", "key_ward2", "key_gaol1", "key_gaol2" },
		Axe = { "axe_quarry1", "axe_quarry2", "axe_quarry3" },
	},

	--======================================================================
	-- THINGS TO FRIGHTEN WITH (made by the builder; these are the counts and the words)
	--======================================================================
	Decoys = 10, -- eyes and a grin on the wall at the end of a long straight passage
	Stains = 36, -- blood on floor and wall
	-- Written in red on the wall. A line may be cut short, as if the hand stopped.
	Writings = {
		"HELP",
		"DO NOT MOVE",
		"HELP M-",
		"IT HEARS",
		"STAY STILL",
		"DON'T BREATHE",
		"NOT THIS WAY",
		"THE BELL IS A LIE",
		"I CAN HEAR HIM COUNTING",
		"SHH",
		"WHO IS WALKING?",
		"DO NOT RU-",
		"HE KNOWS",
		"QUIET QUIET QUIET",
	},

	--======================================================================
	-- SOUNDS. Roblox's own sounds are used until the sound pass makes real ones (the project has no audio yet): each is
	-- `rbxasset://sounds/<file>`, which every Roblox install carries. Replace the Id and nothing else changes.
	--======================================================================
	Sounds = {
		Kill = { Id = "rbxasset://sounds/ouch.ogg", Speed = 0.5, Volume = 1.4, Reach = 70 }, -- a dead one going down
		Stomp = { Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 0.42, Volume = 1.6, Reach = 90 }, -- the Doctor's step
		Chop = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Speed = 1.7, Volume = 0.9, Reach = 80 },
		Lever = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Speed = 0.7, Volume = 1.0, Reach = 80 },
		Bell = { Id = "rbxasset://sounds/impact_water.mp3", Speed = 0.35, Volume = 2.2, Reach = 140 },
		Roar = { Id = "rbxasset://sounds/action_falling.ogg", Speed = 0.4, Volume = 1.8, Reach = 110 },
	},

	--======================================================================
	-- WHAT IS WRITTEN. English, because it is shown in the game.
	--======================================================================
	Entrance = {
		title = "Left on the table",
		sign = "in a hand that shook",
		lines = {
			"Take the light. It is the only one you will be given, and you will want it to the very end.",
			"They say it hears, whatever it is. Do not speak. Do not run. Where the passage is low, go low.",
			"Down is easy. The way up is on the far side, under the old graveyard stones, behind an iron door we shut from within. We did not think of how we would come out.",
		},
	},

	Pages = {
		{
			title = "The Gravedigger's Tally",
			sign = "Osric Thane, gravedigger of the Rows",
			lines = {
				"Nine hundred and twelve this winter, and no ground left. The Warden has had us open the old vaults under the churchyard and stack them to the lintels.",
				"The smell comes up through the floor into the chapel. The sexton has stopped lighting the lamps there. Nobody asks why.",
			},
		},
		{
			title = "To my son, Wat",
			sign = "Alys, the baker's wife",
			lines = {
				"They took your father to the Ward on St. Brannoc's. The physician would cure him, they said.",
				"He came back to the door cured. He sat down at the table. He did not know my name, and he did not know yours.",
				"I will not open the door again. Be quiet, Wat. Be quiet, and go to your aunt.",
			},
		},
		{
			title = "From the Physician's Hand, I",
			sign = "Lucan Verrow, physician to the Ward",
			lines = {
				"I have cured them. Let nobody write that I have not. The dead walk back, and with the broth and the pale lamp and my two hands they sit up and ask for water. Forty-one so far.",
				"The Warden calls it a miracle. It is not a miracle. It is a method, and I would have taught it to anyone who asked.",
			},
		},
		{
			title = "From the Physician's Hand, II",
			sign = "Lucan Verrow, physician to the Ward",
			lines = {
				"They came at night with the iron chair. For the realm, the Warden said; we must know how it is done.",
				"They tried it on me. Salts in the eyes first, to stop the spread. When I woke the lamps were out and I could not find the wall.",
			},
		},
		{
			title = "From the Physician's Hand, III",
			sign = "Lucan Verrow, written blind",
			lines = {
				"I do not see. I hear. I hear the rats in the third gallery and the damp creeping down the chapel stair. I hear every step above me, and the ones that try to be quiet are the loudest of all.",
				"They gave me something for the pain, and I grew. I can no longer pass the doors I made. Whoever reads this: do not run, do not speak, and do not strike what lies in your path unless you must.",
				"I listen. I am very big now, and very sorry.",
			},
		},
		{
			title = "The Mason's Note",
			sign = "Gil Parrow, mason",
			lines = {
				"We were told to close the stair under the graveyard from below, and to hang the iron door on the inside, so that nothing could come out.",
				"We were not told how we were to come out.",
			},
		},
		{
			title = "The Warden's Order (a copy)",
			sign = "sealed with a grey wax",
			lines = {
				"By order: the vaults are sealed. No one is to be heard in the galleries after the bell.",
				"The Physician is to be fed through the grating. He is not to be spoken to, and he is not to be shown a light. He will not know it, but the others will.",
			},
		},
		{
			title = "Brother Anselm's Confession",
			sign = "scratched on a board",
			lines = {
				"I rang the bell in the third gallery to draw it from the corridor, and it went to the bell.",
				"God forgive me. I rang it again for the others, and it went to the others. The bells are not for the dead. They are for whoever is running.",
			},
		},
		{
			title = "A Child's Count",
			sign = "chalk, low on the wall",
			lines = {
				"I counted four hundred steps to the door and four hundred back. It does not open from this side.",
				"Mother says be quiet. Mother has been quiet a long time.",
			},
		},
	},
}

return table.freeze(Catacombs)
