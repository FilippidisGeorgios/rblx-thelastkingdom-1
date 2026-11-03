--!strict
--[[
	Config: Forest
	The numbers of area 6, the King's Wood (docs/systems/Forest.md): where the wood lies, how dark it is, how the Huntsman sees,
	how the fires are lit, what the pages say. The stone, the trees and the ground are made by `tools/BuildForest.luau`, which
	reads the places below and leaves a named mark at each one (`Decorations.Area6.Forest.Marks.<Name>`) for the trial.

	WORDS. *Inner wood* = the part inside the castle walls. *Outer wood* = the part beyond the broken west wall. *The Hollow* =
	the old moat between them. *Watch-fire* = an iron fire basket on a stone foot. *Pitch* = black tar that lights a wet fire.
	*Open* / *covered* = the lantern's shutter (key F).

	Compass: the party walks toward -z ("south"). The way in from the Smithy is in the north wall at the east end; the way out to
	the Rows is in the south wall at the west end; the breach is in the west wall.

	Read via: Config.get("Forest")
]]

local Forest = {
	-- The area it replaces: the Great Hall (the old trial is kept in `RetiredTrials`).
	Area = 6,

	--======================================================================
	-- WHERE (studs; the ground inside the walls is at y 2)
	--======================================================================
	-- inside the walls: between the faces of the two cross-walls (z -1244 and -1463; the gate towers and the side towers stand
	-- into the yard, and the builder keeps the trees off every stone of the castle)
	Inner = { X0 = -171, X1 = 171, Z0 = -1246, Z1 = -1461 },
	-- the gap the wood broke in the west wall: between two of its buttresses, north of the side tower (z -1324 .. -1387)
	Breach = { Z0 = -1268, Z1 = -1306, WallX = -188 },
	Hollow = { X0 = -232, X1 = -302, Z0 = -1236, Z1 = -1474, Floor = -6, Channel = { X0 = -260, X1 = -272, Depth = 4 } },
	-- Beyond the moat. AreaService counts this box as area 6 too (outside the walls nothing else is any area).
	Outer = { X0 = -302, X1 = -610, Z0 = -1236, Z1 = -1474 },
	-- the dams that hold the moat's water back at both ends of the Hollow
	Dams = { -1232, -1478 },

	-- The way in (from the Smithy) and the way out (to the Rows), for the paths
	WayIn = Vector3.new(153, 2, -1248),
	WayOut = Vector3.new(-153, 2, -1460),

	--======================================================================
	-- THE DARK
	--======================================================================
	-- the light zone covers all of it: `configs/LightZones` profile `Forest`
	LightProfile = "Forest",

	-- Covering the lantern (key F, a button on a phone): the light that is left. Open, it is `Catacombs.Lantern`.
	Cover = { Range = 5, Brightness = 0.35 },

	--======================================================================
	-- THE WATCH-FIRES
	--======================================================================
	Fires = {
		{ id = "orchard", name = "the old orchard", at = Vector3.new(-96, 2, -1268) },
		{ id = "camp", name = "the charcoal burners' clearing", at = Vector3.new(96, 2, -1436) },
		{ id = "hollow", name = "the Hollow", at = Vector3.new(-266, -6, -1436) },
		{ id = "stones", name = "the stag stones", at = Vector3.new(-452, 2, -1352) },
	},
	Fire = {
		PourHold = 1.2, -- pouring the pitch in
		LightHold = 2.4, -- lighting it from the lantern (the lantern is open while you do)
		CatchSeconds = 6, -- it grows for this long before it is a safe place
		Glow = 16, -- studs: inside a lit fire's glow a light is not seen, and he will not come
		FlareSeen = 140, -- studs: how far he sees a fire catching (along a clear line)
		Range = 34, -- the fire's own light
		Brightness = 2.4,
		Color = Color3.fromRGB(255, 150, 70),
		Item = "pitch",
	},

	-- Where pitch may lie (marks Pitch1 .. Pitch9); this many of them hold a pot each run.
	PitchSpots = {
		Vector3.new(82, 2, -1446), -- the charcoal burners' hut
		Vector3.new(110, 2, -1452), -- by the earth mounds
		Vector3.new(70, 2, -1418), -- the woodpile
		Vector3.new(-120, 2, -1252), -- the orchard shed
		Vector3.new(-262, -6, -1250), -- the sunk cart in the Hollow
		Vector3.new(-424, 2, -1252), -- the woodcutter's hut
		Vector3.new(-404, 2, -1262), -- the woodcutter's chopping block
		Vector3.new(-534, 2, -1440), -- the lodge store
		Vector3.new(-548, 2, -1452), -- the lodge store, the back
	},
	PitchPots = 6,
	PitchHold = 0.9,

	-- Each fire that catches wakes this many dead in the leaves (before the party and depth curves), at the Rise marks nearest it.
	RisePerFire = 3,

	--======================================================================
	-- THE HUNTSMAN
	--======================================================================
	Huntsman = {
		Id = "the_huntsman",
		Height = 9, -- to the tips of the antlers
		Speeds = { Round = 7, Search = 8.5, Hunt = 14.5 }, -- studs a second (walking 16, crouching 8)
		See = {
			Open = 70, -- an open lantern, along a clear line, inside his sight
			Covered = 8, -- a covered one
			CoveredCrouched = 6,
			Dark = 8, -- a body with no lantern at all
			Behind = 8, -- anything outside his sight (behind him)
			HalfAngle = 110, -- degrees either side of where he looks
			Every = 0.2, -- seconds between looks
			LoseAfter = 2.5, -- seconds without seeing it before he gives up the hunt and searches
		},
		AlertSeconds = 1.6, -- he stops, lifts his head and blows the horn
		HornEvery = 20, -- at most one horn this often
		SearchSeconds = 8,
		RoundPause = 4, -- he stands this long at each stop of his round
		AttackRange = 7,
		AttackDamage = 50,
		Windup = 1.0,
		Strike = 0.2,
		Recover = 1.2,
		-- He cannot die. Hurt this much (times the party's health curve) he goes back into the dark for a while.
		Endure = 300,
		DriveSeconds = 25,
		-- the stops of his round (marks Round1 .. RoundN are put here by the builder; he walks between them)
		Round = {
			Vector3.new(120, 2, -1300),
			Vector3.new(30, 2, -1270),
			Vector3.new(-60, 2, -1330),
			Vector3.new(-130, 2, -1400),
			Vector3.new(-20, 2, -1450),
			Vector3.new(60, 2, -1380),
			Vector3.new(-212, 0, -1287),
			Vector3.new(-266, -6, -1300),
			Vector3.new(-266, -6, -1400),
			Vector3.new(-360, 2, -1300),
			Vector3.new(-420, 2, -1410),
			Vector3.new(-500, 2, -1300),
			Vector3.new(-560, 2, -1420),
			Vector3.new(-470, 2, -1240),
		},
		Spawn = Vector3.new(-520, 2, -1420), -- by his lodge
	},

	--======================================================================
	-- SOUNDS (Roblox's own until the sound pass; replace the Id and nothing else changes)
	--======================================================================
	Sounds = {
		Horn = { Id = "rbxasset://sounds/action_falling.ogg", Speed = 0.22, Volume = 2.6, Reach = 420 }, -- the hunting horn: everyone hears it
		Catch = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Speed = 0.5, Volume = 1.2, Reach = 120 }, -- a fire catching
		Pour = { Id = "rbxasset://sounds/impact_water.mp3", Speed = 0.6, Volume = 0.8, Reach = 40 },
		Step = { Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 0.55, Volume = 1.0, Reach = 60 }, -- his step
		Strike = { Id = "rbxasset://sounds/swordslash.wav", Speed = 0.6, Volume = 1.4, Reach = 60 },
		Gate = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Speed = 0.35, Volume = 1.6, Reach = 400 },
	},

	--======================================================================
	-- WHAT IS WRITTEN. English, because it is shown in the game.
	--======================================================================
	-- the gamekeepers' board at the way in
	Rule = {
		title = "The Gamekeepers' Board",
		sign = "cut into the wood, the letters filled with pitch",
		lines = {
			"KEEP THE KING'S WOOD.",
			"When the four fires burn, the hunt is over and the gate is raised.",
			"The Master of the Hunt sees by light. When you hear his horn, close your lantern (F) and keep still.",
			"He will not come into the light of a fire.",
		},
	},

	Pages = {
		{
			title = "The Huntsman's Book, I",
			sign = "Aldric Fenn, Master of the King's Hunt",
			lines = {
				"The King rode out on the eve of St. Hubert with forty dogs and came back with none. Something in the wood had the scent of every one of them.",
				"I have doubled the watch-fires. The men say the deer have stopped coming to the salt.",
			},
		},
		{
			title = "The Huntsman's Book, II",
			sign = "Aldric Fenn",
			lines = {
				"The sickness came over the wall from the Rows. The gamekeepers went home to their families and did not come back, so I keep the wood alone.",
				"At night I see their lanterns moving between the trees. I go to them and they are not there.",
			},
		},
		{
			title = "The Huntsman's Book, III",
			sign = "Aldric Fenn, in a hand that slopes",
			lines = {
				"My eyes are worse. I cannot see a man in front of me unless he carries a light, and then I see nothing else.",
				"I took the old stag's skull down from over the door. It helps. I do not know why it helps.",
			},
		},
		{
			title = "The Huntsman's Book, IV",
			sign = "Aldric Fenn",
			lines = {
				"The King sent word: no one is to leave by the wood. I am to keep it. I have always kept it.",
				"If a light walks in my wood, it is a poacher, and I know what is done with poachers.",
			},
		},
		{
			title = "A Gamekeeper's Note",
			sign = "Tom Hollis, under-keeper",
			lines = {
				"Light the four fires before you go in, even if it is still day. He will not go near them. Nobody knows why and nobody asks.",
				"If you hear the horn, put your lantern out and lie down. Do not run. He can run longer than you can.",
			},
		},
		{
			title = "The Charcoal Burner's Wife",
			sign = "scratched on a slate",
			lines = {
				"Edwin went for the pitch at the lodge store. I saw his lantern go in among the trees.",
				"Then I heard the horn, and I saw his lantern stop. It is still there. It has not moved in three nights.",
			},
		},
	},
	-- where each page lies (marks Page1 .. Page6)
	PageSpots = {
		Vector3.new(-526, 2, -1414), -- the lodge, his table
		Vector3.new(-512, 2, -1428), -- the lodge, the bed
		Vector3.new(-540, 2, -1404), -- the lodge, the trophy wall
		Vector3.new(-430, 2, -1244), -- the woodcutter's hut
		Vector3.new(118, 2, -1270), -- by the way in, on the dead gamekeeper
		Vector3.new(86, 2, -1450), -- the charcoal burners' hut
	},
	PagesPrize = "deed_forest_pages",
}

-- Whether `p` is in the wood: inside the walls, in the breach, in the Hollow or in the outer wood.
function Forest.contains(p: Vector3): boolean
	local function inBox(box: any): boolean
		return p.X >= math.min(box.X0, box.X1) and p.X <= math.max(box.X0, box.X1) and p.Z >= math.min(box.Z0, box.Z1) and p.Z <= math.max(box.Z0, box.Z1)
	end
	if inBox(Forest.Inner) or inBox(Forest.Hollow) or inBox(Forest.Outer) then
		return true
	end
	-- the strip between the inner wood and the Hollow, outside the wall
	return p.X < -171 and p.X > -232 and p.Z <= Forest.Inner.Z0 and p.Z >= Forest.Inner.Z1
end

return table.freeze(Forest)
