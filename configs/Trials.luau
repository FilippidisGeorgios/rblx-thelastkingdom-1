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
							weight = { name = "Weight", damage = 1.4, cooldown = 1.35, text = "a weight that breaks things (+40% damage, slower swing)" },
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
