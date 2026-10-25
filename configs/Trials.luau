--!strict
--[[
	Config: Trials
	What each chamber ASKS of the party (docs/systems/Trials.md). One entry per
	chamber that has a data-driven trial; chambers 1 and 2 predate this and run
	their own services (BarricadeService, WinchService), which still call
	AreaService.clear themselves.

	Read via: Config.get("Trials")

	SCHEMA
	Trials[areaIndex] = {
		phases = {
			{
				id = string,
				hint = string,                 -- the top line while this phase is live ("%d" / "%d" fill from progress)
				mode = "all" | "any" | "count"?,
				count = number?,
				tasks = { { id = string, kind = string, ...params } },
			},
		},
		pressure = { { id = string, kind = string, from = "start" | phaseId?, ...params } },
		deeds = { { id = string, kind = string, ...params } },   -- optional, never gate
	}

	Task kinds and their params are documented at the top of each module in
	Server/World/Trial/. Positions are NAMES of scenery under
	Workspace.Gameplay.Battleground (dotted paths), never coordinates, so the
	trial follows the art when it moves.
]]

local Trials = {
	--======================================================================
	-- 3 — Kitchens. The recipe, the pot, the five.
	--
	-- Read the cook's parchment, fetch what it asks for (four of seven things,
	-- rolled each run), put it all in the pot in the kitchen hall and MIND it
	-- while it simmers (the smell draws the dead, and the pot only cooks while
	-- someone is near it), then take a ladle to each of five penned dead. They
	-- turn back into villagers and walk with the party through 4 to 6.
	--======================================================================
	[3] = {
		recipe = {
			title = "Marta's Broth",
			sign = "Marta, cook of the keep",
			intro = "If any of them ever come back from the Hollow, this is the broth that brought my sister round the winter the fever took the village. Do not ask me why it works. Bring me:",
			outro = "All of it into the great pot in the hall. Mind it until it speaks; they come to the smell, so keep your sword by you. Then a ladle to each, and do not be afraid of their eyes.",
			pick = 4,
			pool = {
				{ id = "flour", name = "Flour", line = "Flour, a good fistful, from the granary where the dry sacks were kept.", where = "Decorations.Area3.Granary", prop = "sack" },
				{ id = "salted_meat", name = "Salted Meat", line = "Salted meat, the oldest hams in the smokehouse.", where = "Decorations.Area3.Smokehouse", prop = "ham" },
				{ id = "herbs", name = "Herbs", line = "Thyme and sage, from the kitchen garden.", where = "Decorations.Area3.Garden", prop = "herbs" },
				{ id = "well_water", name = "Well Water", line = "A bucket from the well. The water there never turned.", where = "Decorations.Area3.Well", prop = "bucket" },
				{ id = "turnips", name = "Turnips", line = "Turnips from the garden, as many as a hand will hold.", where = "Decorations.Area3.Garden", prop = "crate" },
				{ id = "ale", name = "Ale", line = "A little ale from the dairy cellar, for body.", where = "Decorations.Area3.Dairy", prop = "cask" },
				{ id = "salt", name = "Salt", line = "A crock of salt from the store.", where = "Decorations.Area3.Store", prop = "crock" },
			},
		},

		phases = {
			{
				id = "read",
				hint = "Find the cook's parchment in the kitchen hall",
				tasks = { { id = "parchment", kind = "read", at = "Decorations.Area3.KitchenHall.Table", title = "Marta's Broth", sign = "Marta, cook of the keep", recipe = true } },
			},
			{
				id = "gather",
				hint = "Gather what the recipe asks for (%d of %d)",
				tasks = { { id = "ingredients", kind = "gather" } },
			},
			{
				id = "cook",
				hint = "Put the ingredients in the pot (%d of %d)",
				tasks = {
					{ id = "pot", kind = "cook", pot = "Decorations.Area3.KitchenHall.Cauldron", simmerSeconds = 30, mindRadius = 22, portions = 5 },
				},
			},
			{
				id = "feed",
				hint = "Take the broth to the penned (%d of %d)",
				tasks = {
					{
						id = "penned",
						kind = "feed",
						near = "Decorations.Area3.Well",
						radius = 80,
						gateToward = "Decorations.Area3.KitchenHall.Cauldron",
						holdSeconds = 2.5,
						penned = {
							{ dead = "undead_shambler", cure = "cured_villager" },
							{ dead = "undead_shambler", cure = "cured_villager" },
							{ dead = "undead_shambler", cure = "cured_villager" },
							{ dead = "undead_archer", cure = "cured_villager_bow" },
							{ dead = "undead_archer", cure = "cured_villager_bow" },
						},
						lines = {
							"\"...Marta? Is that her pot? Gods, the smell of it.\"",
							"\"I was in the yard. I was in the yard and then I was here.\"",
							"\"Forty years? That is not possible. My daughter was six.\"",
							"\"I remember the bell. I remember it did not stop.\"",
							"\"Give me a bow. I will not stand behind you for this.\"",
						},
					},
				},
			},
		},

		pressure = {
			{
				id = "smell",
				kind = "tide",
				from = "signal:simmer",
				untilPhase = "cook",
				spawns = {
					"Battleground.Chamber3.Spawns.North",
					"Battleground.Chamber3.Spawns.East",
					"Battleground.Chamber3.Spawns.West",
				},
				interval = 7,
				burst = 2,
				cap = 8,
				enemies = {
					{ id = "undead_shambler", weight = 3 },
					{ id = "undead_runner", weight = 1 },
				},
			},
		},
	},

	--======================================================================
	-- 5 — Smithy. THE SPIKE. The forge, and the door that is burned.
	--
	-- Two jobs, in any order, in a yard full of spears and bows: work the
	-- forge (three blows at a heat that will not hold, then a temper that
	-- changes how you fight for the rest of the run), and burn the timber door
	-- out of the yard (oil from the far west, fire from the forge, the door at
	-- the far east: the longest carry in the game). Two deeds beside them: the
	-- woodyard (planks for the Great Hall) and the mine (gold, and the pickaxe
	-- the Inner Ward will want).
	--======================================================================
	[5] = {
		phases = {
			{
				id = "work",
				hint = "Temper your blade at the forge, and burn the door",
				mode = "all",
				tasks = {
					{
						id = "forge",
						kind = "forge",
						hearth = "Decorations.Area5.Smithy.ForgeHearth",
						bellows = "Decorations.Area5.Smithy.ForgeBellows",
						anvil = "Decorations.Area5.Smithy.ForgeAnvil",
						rounds = 3,
						decaySeconds = 55,
						pump = 0.14,
						pumpHold = 0.45,
						strikeHold = 1.0,
						strikeCost = 0.38,
						thresholds = { 0.70, 0.76, 0.82 },
						tempers = {
							edge = { name = "Edge", damage = 1.18, text = "an edge that bites deeper (+18% damage)" },
							point = { name = "Point", reach = 3, text = "a point that reaches further (+3 studs)" },
							weight = { name = "Weight", damage = 1.4, cooldown = 1.35, pierce = 0.6, text = "a weight that breaks things (+40% damage, slower swing, plate does not stop it)" },
						},
					},
					{
						id = "door",
						kind = "burn",
						oilStore = "Decorations.Area5.OilStore",
						torchRack = "Decorations.Area5.TorchRack",
						fire = "Decorations.Area5.Smithy.ForgeHearth",
						jars = 2,
						torchSeconds = 50,
						pourHold = 1.2,
						setHold = 1.4,
						takeHold = 0.8,
					},
				},
			},
		},

		pressure = {},

		deeds = {
			{
				id = "wood",
				kind = "chop",
				woodyard = "Decorations.Area5.Woodyard",
				trees = "Decorations.Area5",
				stack = "Decorations.Area5.Woodyard.PlankStack",
				chopHold = 2.8,
				perTree = 3,
				stackPlanks = 4,
				target = 12,
				prize = "deed_smithy_planks",
			},
			{
				id = "mine",
				kind = "mine",
				veins = "Decorations.Area5.Mine",
				count = 8,
				table = "mine_vein",
				hold = 2.2,
			},
		},
	},

	--======================================================================
	-- 6 — Great Hall. The siege.
	--
	-- The hall has four doorways and, on the Great Hall's own terms, a pause:
	-- 75 seconds in which to fetch planks and nail the doors (up to six a door,
	-- four seal it), then a horn, then three waves of spearmen and archers that
	-- come to the DOORS and break them. The barricades are things the dead
	-- attack, so the boards are health, not decoration. Boarding is a deed
	-- (nothing waits on it); the gate rises when the siege is cleared.
	--======================================================================
	[6] = {
		ownsWaves = true,

		phases = {
			{
				id = "hold",
				hint = "Board the doors, then hold the hall",
				tasks = {
					{ id = "siege", kind = "siege", encounter = "area_6", grace = 75 },
				},
			},
		},

		pressure = {},

		deeds = {
			{
				id = "boards",
				kind = "board",
				hall = "Decorations.Area6.GreatHall",
				maxPlanks = 6,
				sealPlanks = 4,
				healthPerPlank = 150,
				nailHold = 1.1,
				racks = { { door = 2, planks = 8 }, { door = 4, planks = 8 } },
			},
		},
	},

	--======================================================================
	-- 7 — The Rows. The prisoner.
	--
	-- A villager is tied to a chair in the tavern. Untie him (a held twenty
	-- seconds, kept if you break off) and bring him to the gate alive, through
	-- the maze of lanes, with the chamber's waves on you and the dead going for
	-- him as much as for you. If he dies a second is found, and a third; if he
	-- lives to the end of the run the whole team earns more gold. Three letters
	-- in three houses are the deed.
	--======================================================================
	[7] = {
		phases = {
			{
				id = "rescue",
				hint = "Free the prisoner in the tavern, and bring him to the gate",
				tasks = {
					{
						id = "prisoner",
						kind = "rescue",
						chair = "Decorations.Area7.Tavern.PrisonerChair",
						enemy = "prisoner_villager",
						seconds = 20,
						reach = 28,
						retries = 2,
						respawnDelay = 18,
						lines = {
							"\"The gate road. Is it still there? Take me to it. Please.\"",
							"\"They kept me for the bell. I never learned what the bell wanted.\"",
							"\"Keep walking. I will be behind you and I will not stop.\"",
						},
					},
				},
			},
		},

		pressure = {},

		deeds = {
			{
				id = "letters",
				kind = "letters",
				prize = "deed_rows_letters",
				letters = {
					{
						at = "Decorations.Area7.ClerksHouse.Table",
						title = "The Clerk's Last Entry",
						sign = "Hobb Tarrow, clerk of the Rows",
						lines = {
							"Muster of the Rows, the fourth winter after the Company marched. Households answering: nineteen of sixty-one.",
							"The king's heralds still ride the road each new moon, reading the names of the absent out of the great book. They read them very loud. I think he believes they can hear.",
							"No grain from the keep since Candlemas. The bells ring the hours and the hours are wrong.",
							"If this is found: the Company's names are in the third drawer, under the star. Whoever comes home should have them back.",
						},
					},
					{
						at = "Decorations.Area7.WidowsHouse.Table",
						title = "To Edric, in the north",
						sign = "Your Maud",
						lines = {
							"The boy asks every night whether the road is open. I say it is, and he sleeps.",
							"They say the king went down under the keep to bring something up. They say the bells did not stop for nine days. I have shut the south shutters and I do not look at the keep any more.",
							"The dead stand in the lane in the mornings now and they do not seem to know why. Old Pell is among them. I put out his boots.",
							"Come home. Come home before the winter, if there is still a home.",
						},
					},
					{
						at = "Decorations.Area7.Cottage.Table",
						title = "A Child's Drawing",
						sign = "charcoal, on the back of a bill of lading",
						lines = {
							"A tall house with a red light at the top. A great star falling on it, gold where the child had a gold stub to use.",
							"Under it a stick figure in a crown, and a smaller figure holding its hand. Letters, uneven: PAPA SAYS THE KING IS SAD.",
							"At the bottom, in a grown hand: Do not let her draw it again.",
						},
					},
				},
			},
		},
	},

	--======================================================================
	-- 8 — The Inner Ward. The line, and the way out under the arch.
	--
	-- The tower fell across the ward and the arch over the passage came down
	-- with it. The only way on is to cut a trench through the heap: a held pick,
	-- five lengths of it, a timber frame at the end of each. Hands off and it
	-- slips back, as far as the last frame. Every frame set is noise, and the
	-- noise carries to the far end of the ward: a surge for each, the last of
	-- them the line's own guard in plate. The fallen tower is the one high
	-- ground; the two slopes of rubble up to it are the only way up. Three
	-- papers in the camp, and the broken mangonel, are the deeds.
	--======================================================================
	[8] = {
		phases = {
			{
				id = "dig",
				hint = "Dig out the buried passage: frames set %d of %d",
				tasks = {
					{
						id = "passage",
						kind = "dig",
						seconds = 26,
						bare = 0.45,
						fall = 0.8,
						hands = 0.5,
					},
				},
			},
		},

		pressure = {
			{
				id = "surge1",
				kind = "surge",
				from = "signal:shore1",
				warn = "A drum, far off in the ward. They heard the picks.",
				delay = 12,
				groups = {
					{ id = "undead_shambler", count = 3, spawn = "Battleground.Chamber8.Spawns.East", spread = 14 },
					{ id = "undead_runner", count = 2, spawn = "Battleground.Chamber8.Spawns.West", spread = 12 },
				},
			},
			{
				id = "surge2",
				kind = "surge",
				from = "signal:shore2",
				warn = "Horns on the east wall. Spears are coming along the line.",
				delay = 12,
				groups = {
					{ id = "undead_spearman", count = 3, spawn = "Battleground.Chamber8.Spawns.West", spread = 12 },
					{ id = "undead_archer", count = 2, spawn = "Battleground.Chamber8.Spawns.East", spread = 12 },
				},
			},
			{
				id = "surge3",
				kind = "surge",
				from = "signal:shore3",
				warn = "Plate on stone, from the far side of the ward. Something heavy is walking.",
				delay = 10,
				groups = {
					{ id = "undead_knight", count = 1, spawn = "Battleground.Chamber8.Spawns.East", spread = 4, flat = true },
					{ id = "undead_shambler", count = 3, spawn = "Battleground.Chamber8.Spawns.West", spread = 14 },
				},
			},
			{
				id = "surge4",
				kind = "surge",
				from = "signal:shore4",
				warn = "The bells have stopped. The line's own guard has begun to march.",
				delay = 10,
				groups = {
					{ id = "undead_knight", count = 1, spawn = "Battleground.Chamber8.Spawns.West", spread = 4, flat = true },
					{ id = "undead_knight", count = 1, spawn = "Battleground.Chamber8.Spawns.East", spread = 4, flat = true },
					{ id = "undead_brute_heavy", count = 1, spawn = "Battleground.Chamber8.Spawns.East", spread = 6, flat = true },
					{ id = "undead_runner", count = 3, spawn = "Battleground.Chamber8.Spawns.West", spread = 14 },
				},
			},
		},

		deeds = {
			{
				id = "papers",
				kind = "letters",
				prize = "deed_ward_papers",
				letters = {
					{
						at = "Decorations.Area8.Camp.Trestle",
						title = "Order of the Day",
						sign = "Marshal Aldous Venn, under the Company's star",
						lines = {
							"The line holds at the palisade. The tower holds at the line. Nobody leaves the ward by the arch; the arch is the king's, and it is shut.",
							"The sappers will mine the keep road by night in case the hollow comes up that way. They will say nothing to the families. The hospital will say nothing to the families.",
							"If the bells begin again, we do not answer them. That is an order. I do not wish to hear that any man has answered them.",
						},
					},
					{
						at = "Decorations.Area8.Camp.Table",
						title = "The Surgeon's Tally",
						sign = "Ilse Marrow, field surgeon",
						lines = {
							"Cots: 31. Linen: for nine. Bone-saws: two, one bent. Poppy: none since the fourth week.",
							"Cause of death, this week. Fever: 3. The line: 11. Not the line, not the fever: 17. These are men who lie down quietly in the morning and are still lying down at noon, and I have stopped writing why.",
							"The cold comes up the ward from the keep. It is not the winter's cold. The candles lean toward it.",
						},
					},
					{
						at = "Decorations.Area8.MarshalsHouse.Table",
						title = "Unsent: to the King",
						sign = "A. Venn, never sealed",
						lines = {
							"Majesty. I have held the line forty days and forty nights and on the forty-first the tower fell on its own, with no hand near it and no gun, as if the stone had grown tired.",
							"My sappers dig toward the keep and are met, I will not say by what. They come back, those that come back, and ask me when you will come out.",
							"If you can hear me down there: the Company is not coming. They went north the winter before the star fell. It is only us. Come out, my king, and let the bells be.",
						},
					},
				},
			},
			{
				id = "mangonel",
				kind = "mangonel",
				model = "Decorations.Area8.Camp.Mangonel",
				stones = 4,
				splash = 15,
				damage = 190,
				minRange = 40,
				maxRange = 150,
				windSeconds = 4,
				prize = "deed_ward_mangonel",
			},
		},
	},

	--======================================================================
	-- 9 — The Keep Steps. The King, and the way out.
	--
	-- Four phases, and they are the last of the run: break the King in his three
	-- faces (and do not kill him: kneel him, and release him), watch the keep's
	-- door answer, hear the scribe out and take his key, unlock the marshal's door
	-- and go up together to the light at the end of the wall-walk. No gate: the
	-- ending. Three papers in the court's own buildings are the deeds.
	--======================================================================
	[9] = {
		phases = {
			{
				id = "king",
				hint = "Break the King: face %d of %d",
				tasks = {
					{
						id = "king",
						kind = "king",
						enemy = "the_king",
						landing = "Decorations.Area9.KeepLanding",
						centre = "Battleground.Chamber9.Objectives.Centre",
						guard = {
							id = "undead_spearman",
							count = 2,
							spawns = { "Battleground.Chamber9.Spawns.West", "Battleground.Chamber9.Spawns.East" },
						},
						release = 5,
						slow = 0.55,
					},
				},
			},
			{
				id = "door",
				hint = "The keep is opening",
				tasks = {
					{
						id = "door",
						kind = "unseal",
						door = "Decorations.Area9.Keep.Interior.KeepDoor",
						seal = "Decorations.Area9.Keep.KeepDoor",
						bar = "Decorations.Area9.Keep.Bar",
						from = "Battleground.Chamber9.Objectives.Centre",
						to = "Decorations.Area9.KeepLanding",
					},
				},
			},
			{
				id = "hall",
				hint = "Hear the scribe out",
				tasks = {
					{
						id = "scribe",
						kind = "scribe",
						at = "Decorations.Area9.Keep.Interior.Desk.ScribeAt",
						enemy = "scribe_npc",
						name = "Orrin Vale, keeper of the rolls",
						key = "keep_key",
						lines = {
							"You came up the Steps. Nobody has come up the Steps in forty years, and I have written that down every morning, in case.",
							"Do not mind the quill. It dries if I stop. I stopped once, the ninth night of the bells, and I have not stopped since.",
							"He went down under the keep, the King. Not to hide: to fetch. Something fell on Asterfall the year the Company marched. It fell into the old well under this hall, and he went to bring it up.",
							"He brought it up. The bells rang nine days. Everyone who heard them lay down in the morning, and was still lying down at noon. I heard them too. I was writing.",
							"The Company\'s names are in the third drawer, under the star. I have copied them nine hundred and eleven times. I do not know why I know how many.",
							"You let him go. I heard it: the bells stopped, and the quiet is so large that I do not know where to put my hands.",
							"He was not wicked. He was sad, as the child drew him. If it is true that a king can carry a kingdom, it is also true that a kingdom can sit down on him.",
							"The way out is up. The marshal\'s stair, behind the little door in the west of the hall. I keep the key, because I keep everything.",
							"Take it. Go up into the light, all of you together, and say that Asterfall remembers. And ask what it was that sent the Company north. Nobody ever wrote that down.",
						},
					},
				},
			},
			{
				id = "way",
				hint = "Unlock the marshal's door, and go up together (%d of %d at the light)",
				tasks = {
					{
						id = "exit",
						kind = "exit",
						door = "Decorations.Area9.Keep.Interior.RoofDoor",
						arch = "Decorations.Area9.Keep.Interior.ExitArch",
						key = "keep_key",
						leave = 2,
					},
				},
			},
		},

		pressure = {},

		deeds = {
			{
				id = "papers",
				kind = "letters",
				prize = "deed_keep_papers",
				letters = {
					{
						at = "Decorations.Area9.Chancery.Table",
						title = "The Last Writ of the Chancery",
						sign = "Clerk of the Seal, under the King's hand",
						lines = {
							"By the King's order: that the bells be rung for the Company's return, nine for the nine halls it left, at the hours of the old rule.",
							"By the King's order: that no person leave the keep by the stair or the court without his seal. By the King's order: that the well be opened.",
							"Sealed in the ninth month. The seal will not take the wax. I have put it in the fire to warm it, and it is cold when I take it out.",
						},
					},
					{
						at = "Decorations.Area9.Treasury.Clutter",
						title = "The Treasurer's Reckoning",
						sign = "Hollis Crane, treasurer of Asterfall",
						lines = {
							"Received, this quarter: nothing. Paid out: the stonemasons of the north quarter, for the well-head, to be built in secret. Paid out: the same again.",
							"I am asked what the well is for. I have been told it is for water. I have been told it is for the Company's homecoming. Nobody has told me why the masons ask to be paid in candles.",
							"If these books are found: the kingdom was solvent on the day it fell. It was the King who was not.",
						},
					},
					{
						at = "Decorations.Area9.KingsGarden.Seat",
						title = "Cut in the stone of a bench",
						sign = "a child's hand, then a man's",
						lines = {
							"Here the King sat in the evenings, and the child drew him, and he said it was not a good likeness, and kept it.",
							"Underneath, in a larger and more careful hand, the same words again, and then: she would have liked the garden this year.",
						},
					},
				},
			},
		},
	},

	--======================================================================
	-- 4 — Graveyard. Carry the fire.
	--
	-- Four braziers, one to each section of the burying ground. A torch burns
	-- for 25 seconds and is lit at the chapel altar (or at a brazier already
	-- alight); the braziers are 36 to 150 studs from it. Each section's graves
	-- keep giving up the dead until ITS brazier burns, so the order you light
	-- them in is the whole decision.
	--======================================================================
	[4] = {
		phases = {
			{
				id = "fire",
				hint = "Carry fire from the chapel to the braziers (%d of %d)",
				tasks = {
					{
						id = "braziers",
						kind = "light",
						braziers = "Decorations.Area4.GraveBraziers",
						sources = { "Decorations.Area4.Chapel.Altar" },
						torchSeconds = 25,
						holdSeconds = 2.2,
						sourceHoldSeconds = 0.7,
					},
				},
			},
		},

		pressure = {
			{
				id = "graves",
				kind = "rising",
				from = "start",
				braziers = "Decorations.Area4.GraveBraziers",
				graves = { "Decorations.Area4.NewGraves", "Decorations.Area4.Churchyard" },
				gravesPerSection = 6, -- graves in each section that can open
				interval = 9, -- seconds between pulses in a section
				burst = 2, -- the dead per pulse (before the party / depth curve)
				cap = 7, -- alive from one section at once (before the curve)
				stagger = 5, -- sections wake this many seconds apart
				enemies = {
					{ id = "undead_shambler", weight = 3 },
					{ id = "undead_runner", weight = 1 },
				},
				-- Every Nth pulse in a section carries a Gravedigger: the first heavy weapons.
				heavy = { id = "undead_brute_heavy", every = 4 },
			},
		},

		deeds = {
			{
				id = "bell",
				kind = "toll",
				rope = "Decorations.Area4.Belfry.BellRope",
				bell = "Decorations.Area4.Belfry.Bell",
				prize = "deed_graveyard_bell",
				-- What answers the bell: the hardest hour of the chamber.
				answer = {
					{ id = "undead_shambler", count = 5 },
					{ id = "undead_runner", count = 3 },
					{ id = "undead_brute_heavy", count = 1 },
				},
			},
		},
	},
}

return table.freeze(Trials)
