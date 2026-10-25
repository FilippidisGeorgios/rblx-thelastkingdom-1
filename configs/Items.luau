--!strict
--[[
	Config: Items
	The item catalog — static definitions for every item type (weapons, armor,
	consumables, resources, quest items, relics). This is item STRUCTURE/metadata,
	not combat balancing: a weapon item points at its combat stats in Weapons.luau
	via `WeaponId`, keeping "what an item is" separate from "how a weapon fights".

	Read via: Config.get("Items")

	Schema (per entry):
		[itemId: string] = {
			DisplayName = string,
			Category    = string,    -- a Shared.Inventory.Enums.ItemCategory value
			Stackable   = boolean,
			MaxStack    = number?,   -- for stackables
			Slot        = string?,   -- equippables: a Shared.Inventory.Enums.EquipmentSlot value
			WeaponId    = string?,   -- weapons: a configs/Weapons key for combat stats

			-- Spoils (docs/systems/Spoils.md). Everything below is optional.
			Rank        = string?,   -- "Worn" | "Sound" | "Hallowed" | "Relic"; default "Worn"
			Flavour     = string?,   -- one line, shown on a Sound-or-better pickup
			Use         = string?,   -- one line: what it is FOR (shown in the pack)
			Banked      = boolean?,  -- kept at the end of a won run (default: false for QuestItem, else true)
			Look        = {          -- what the pickup on the ground looks like
				Shape = "Block" | "Ball" | "Disc" | "Bar",
				Size = Vector3,
				Colour = Color3,
				Material = Enum.Material,
				Glow = boolean?,     -- Neon core
			}?,
		}

	The ranks and their colours are in configs/Loot.luau (`Ranks`), not in each
	entry, so one edit restyles every Sound item at once.
]]

local function look(shape: string, size: Vector3, colour: Color3, material: Enum.Material, glow: boolean?)
	return { Shape = shape, Size = size, Colour = colour, Material = material, Glow = glow }
end

local Items = {
	-- TEST placeholder item for the combat/equipment slice. Links to the
	-- starter_sword combat stats in Weapons.luau. Not final content.
	starter_sword = {
		DisplayName = "Worn Sword",
		Category = "Weapon",
		Stackable = false,
		Slot = "MainHand",
		WeaponId = "starter_sword",
	},

	--======================================================================
	-- MATERIALS — the stuff of the dead. Stack to 99, one backpack slot per kind.
	--======================================================================
	bone_dust = {
		DisplayName = "Bone Dust",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "Offered at the chapel for something better.",
		Look = look("Ball", Vector3.new(0.55, 0.45, 0.55), Color3.fromRGB(214, 206, 188), Enum.Material.Sand),
	},
	grave_cloth = {
		DisplayName = "Grave Cloth",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "Three make a bandage.",
		Look = look("Block", Vector3.new(0.8, 0.22, 0.6), Color3.fromRGB(176, 164, 138), Enum.Material.Fabric),
	},
	rusted_iron = {
		DisplayName = "Rusted Iron",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "For arrows and oil pots.",
		Look = look("Block", Vector3.new(0.7, 0.28, 0.4), Color3.fromRGB(104, 66, 44), Enum.Material.CorrodedMetal),
	},
	wild_feather = {
		DisplayName = "Fletching",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "Two make the flights of an arrow bundle.",
		Look = look("Bar", Vector3.new(0.12, 0.05, 0.9), Color3.fromRGB(196, 186, 164), Enum.Material.Fabric),
	},
	tallow = {
		DisplayName = "Tallow",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Sound",
		Flavour = "A cook's tallow, still soft.",
		Use = "Two make an oil pot; one a torch.",
		Look = look("Disc", Vector3.new(0.5, 0.7, 0.7), Color3.fromRGB(232, 218, 170), Enum.Material.SmoothPlastic),
	},
	grave_silver = {
		DisplayName = "Grave Silver",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Sound",
		Flavour = "A mourner's silver, warm from the ground.",
		Use = "The best shelf at the chapel; blessed edges.",
		Look = look("Bar", Vector3.new(0.9, 0.18, 0.35), Color3.fromRGB(190, 196, 204), Enum.Material.Metal, true),
	},
	hollow_ember = {
		DisplayName = "Hollow Ember",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Hallowed",
		Flavour = "It is not warm. It glows anyway.",
		Use = "The Reliquary can make something of it.",
		Look = look("Ball", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(232, 120, 52), Enum.Material.Neon, true),
	},

	--======================================================================
	-- CONSUMABLES — made at the camp or found in caches.
	--======================================================================
	bandage = {
		DisplayName = "Bandage",
		Category = "Consumable",
		Stackable = true,
		MaxStack = 9,
		Rank = "Worn",
		Use = "Hold to mend 35 health.",
		Look = look("Disc", Vector3.new(0.4, 0.7, 0.7), Color3.fromRGB(226, 218, 196), Enum.Material.Fabric),
	},
	arrow_bundle = {
		DisplayName = "Arrow Bundle",
		Category = "Consumable",
		Stackable = true,
		MaxStack = 9,
		Rank = "Worn",
		Use = "Eight arrows.",
		Look = look("Bar", Vector3.new(0.12, 0.12, 1.3), Color3.fromRGB(150, 118, 78), Enum.Material.Wood),
	},
	oil_pot = {
		DisplayName = "Oil Pot",
		Category = "Consumable",
		Stackable = true,
		MaxStack = 9,
		Rank = "Sound",
		Flavour = "Sealed with wax. It sloshes.",
		Use = "Thrown: a pool of fire for four seconds.",
		Look = look("Ball", Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(96, 72, 52), Enum.Material.Slate),
	},
	hearty_dish = {
		DisplayName = "Hearty Dish",
		Category = "Consumable",
		Stackable = true,
		MaxStack = 9,
		Rank = "Sound",
		Flavour = "Still steaming. It should not be.",
		Use = "Eat to mend 60 health.",
		Look = look("Disc", Vector3.new(0.35, 0.9, 0.9), Color3.fromRGB(126, 98, 66), Enum.Material.Wood),
	},

	--======================================================================
	-- QUEST ITEMS — spent in the same run, never banked.
	--======================================================================
	torch = {
		DisplayName = "Torch",
		Category = "QuestItem",
		Stackable = false,
		Banked = false,
		Use = "Burns for forty-five seconds.",
	},

	-- The Kitchens' recipe (docs/systems/Trials.md §5, chamber 3). Carried, never banked.
	ingredient_flour = { DisplayName = "Flour", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_salted_meat = { DisplayName = "Salted Meat", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_herbs = { DisplayName = "Herbs", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_well_water = { DisplayName = "Well Water", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_turnips = { DisplayName = "Turnips", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_ale = { DisplayName = "Ale", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	ingredient_salt = { DisplayName = "Salt", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the pot in the kitchen hall." },
	-- The Smithy (docs/systems/Trials.md §5, chamber 5). Carried, never banked; planks and the pickaxe go on to later chambers.
	oil_jar = { DisplayName = "Jar of Lamp Oil", Category = "QuestItem", Stackable = true, MaxStack = 2, Banked = false, Use = "Pour it on the door at the end of the yard." },
	unlit_torch = { DisplayName = "Unlit Torch", Category = "QuestItem", Stackable = false, Banked = false, Use = "Light it at the forge." },
	axe = { DisplayName = "Woodsman's Axe", Category = "QuestItem", Stackable = false, Banked = false, Use = "For the dead trees in the yard." },
	plank = { DisplayName = "Plank", Category = "QuestItem", Stackable = true, MaxStack = 16, Banked = false, Use = "To board the doors of the Great Hall." },
	keep_key = { DisplayName = "Key of the Marshal's Door", Category = "QuestItem", Stackable = false, Banked = false, Use = "Opens the little door in the west of the keep's hall: the way up and out." },
	mangonel_stone = { DisplayName = "Mangonel Stone", Category = "QuestItem", Stackable = false, Banked = false, Use = "Load it in the sling of the mangonel in the Inner Ward." },
	pickaxe = { DisplayName = "Miner's Pickaxe", Category = "QuestItem", Stackable = false, Banked = false, Use = "For rubble. Keep it." },
	broth = {
		DisplayName = "A Ladle of Broth",
		Category = "QuestItem",
		Stackable = true,
		MaxStack = 5,
		Banked = false,
		Use = "Hold it to the lips of one of the penned.",
	},

	--======================================================================
	-- RELICS — one charm slot. The item exists now; the effect comes with the
	-- stats it changes (Arsenal §6).
	--======================================================================
	saints_medal = {
		DisplayName = "Saint's Medal",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Worn smooth by a thumb.",
		Use = "Carry one more bandage.",
		Look = look("Disc", Vector3.new(0.15, 0.8, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	company_signet = {
		DisplayName = "The Company's Signet",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "A falling star, cut in carnelian.",
		Use = "A wider parry window.",
		Look = look("Disc", Vector3.new(0.2, 0.7, 0.7), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	brass_stirrup = {
		DisplayName = "Brass Stirrup",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "No horse in this castle has worn it in forty years.",
		Use = "Walk a little faster out of a fight.",
		Look = look("Disc", Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	mourners_veil = {
		DisplayName = "Mourner's Veil",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Black lace. It remembers a face.",
		Use = "Survive the first killing blow of a run.",
		Look = look("Block", Vector3.new(0.8, 0.12, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Fabric, true),
	},
	hollow_lantern = {
		DisplayName = "Hollow Lantern",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Its light is not for you.",
		Use = "The dead notice you a little later.",
		Look = look("Block", Vector3.new(0.5, 0.9, 0.5), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	sextons_key = {
		DisplayName = "Sexton's Key",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Every grave has one lock. This opens the one that was left shut.",
		Use = "Opens one locked cache a run.",
		Look = look("Bar", Vector3.new(0.14, 0.14, 1), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	kings_seal = {
		DisplayName = "The King's Seal",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Pressed in wax that never cooled.",
		Use = "Proof.",
		Look = look("Disc", Vector3.new(0.25, 1, 1), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},

	--======================================================================
	-- STORY — never lost, even on a wiped run.
	--======================================================================
	star_shard = {
		DisplayName = "Star Shard",
		Category = "Relic",
		Stackable = true,
		MaxStack = 9,
		Rank = "Relic",
		Flavour = "Part of something that fell.",
		Use = "Nine raise the Falling Star.",
		Look = look("Block", Vector3.new(0.3, 0.9, 0.3), Color3.fromRGB(250, 236, 190), Enum.Material.Neon, true),
	},

	-- The Journal's pages (configs/Pages): copied out when a Deed is done, never lost.
	page_graveyard_bell = {
		DisplayName = "The Sexton's Ledger",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Forty places dug, and no one sent for them.",
		Use = "Read it in the Journal, at the Chapel.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_smithy_tally = {
		DisplayName = "A Smith's Tally",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Two hundred and twelve, and three more for no one.",
		Use = "Read it in the Journal, at the Chapel.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_rows_letters = {
		DisplayName = "The Clerk's Muster",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Nineteen of sixty-one.",
		Use = "Read it in the Journal, at the Chapel.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_ward_papers = {
		DisplayName = "The Marshal's Dispatch",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "We kept the gate as long as there was a gate.",
		Use = "Read it in the Journal, at the Chapel.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_keep_papers = {
		DisplayName = "The Chancery's Last Page",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "The ink is still wet.",
		Use = "Read it in the Journal, at the Chapel.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
}

return table.freeze(Items)
