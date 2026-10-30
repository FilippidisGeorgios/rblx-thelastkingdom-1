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
			Tip         = string?,   -- a line of advice, shown under the arrow on the item's card (UI/ItemCard)
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
		Tip = "Sixty of it buys one pick from the Tithe in the Chapel. It is the commons' coin: never leave a pile behind.",
		Look = look("Ball", Vector3.new(0.55, 0.45, 0.55), Color3.fromRGB(214, 206, 188), Enum.Material.Sand),
	},
	grave_cloth = {
		DisplayName = "Grave Cloth",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "Three make a bandage.",
		Tip = "Three make a bandage at any camp bench. One more, with tallow, makes a torch.",
		Look = look("Block", Vector3.new(0.8, 0.22, 0.6), Color3.fromRGB(176, 164, 138), Enum.Material.Fabric),
	},
	rusted_iron = {
		DisplayName = "Rusted Iron",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "For arrows and oil pots.",
		Tip = "Arrows and oil pots each want one at the camp bench. Armed dead and crates carry it.",
		Look = look("Block", Vector3.new(0.7, 0.28, 0.4), Color3.fromRGB(104, 66, 44), Enum.Material.CorrodedMetal),
	},
	wild_feather = {
		DisplayName = "Fletching",
		Category = "Resource",
		Stackable = true,
		MaxStack = 99,
		Rank = "Worn",
		Use = "Two make the flights of an arrow bundle.",
		Tip = "Two feathers and a piece of iron make a bundle of arrows at the camp bench.",
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
		Tip = "Two make an oil pot, one makes a torch. The Kitchens and the candle stands are rich in it.",
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
		Tip = "Two, with a Hollow Ember, make a Blessed Edge at the Reliquary. The Tithe sometimes sells it too.",
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
		Tip = "The Reliquary can beat it into a blessing for your next run. Cinders and Hollow Knights carry them.",
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
		Tip = "Hold it to bind a wound: it mends 35 health in two seconds. Do not start one in the middle of a swing.",
		Look = look("Disc", Vector3.new(0.4, 0.7, 0.7), Color3.fromRGB(226, 218, 196), Enum.Material.Fabric),
	},
	arrow_bundle = {
		DisplayName = "Arrow Bundle",
		Category = "Consumable",
		Stackable = true,
		MaxStack = 9,
		Rank = "Worn",
		Use = "Eight arrows.",
		Tip = "Eight arrows for a bow. Keep a bundle in reserve against the archers.",
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
		Tip = "Throw it at a crowd or a door: the fire burns for four seconds. It does not care whose feet are in it.",
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
		Tip = "Eat it between fights. It mends 60 health, more than two bandages.",
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
	cellar_key = { DisplayName = "Cellar Key", Category = "QuestItem", Stackable = false, Banked = false, Use = "Opens the door at the foot of the cellar stair, beside the kitchen." },
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
		Tip = "Wear it at the Reliquary: it puts one more bandage in your pack at the gate of every run.",
		Look = look("Disc", Vector3.new(0.15, 0.8, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	company_signet = {
		DisplayName = "The Company's Signet",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "A falling star, cut in carnelian.",
		Use = "A wider parry window.",
		Tip = "A charm, worn at the Reliquary. Its effect, a wider parry window, is not yet wrought.",
		Look = look("Disc", Vector3.new(0.2, 0.7, 0.7), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	brass_stirrup = {
		DisplayName = "Brass Stirrup",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "No horse in this castle has worn it in forty years.",
		Use = "Walk a little faster out of a fight.",
		Tip = "A charm, worn at the Reliquary. After five quiet seconds, with no blow given or taken, you walk 8% faster until the next one.",
		Look = look("Disc", Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	mourners_veil = {
		DisplayName = "Mourner's Veil",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Black lace. It remembers a face.",
		Use = "Survive the first killing blow of a run.",
		Tip = "A charm, worn at the Reliquary. The first blow of a run that would kill you leaves you one breath instead; then the veil is spent until the next run.",
		Look = look("Block", Vector3.new(0.8, 0.12, 0.8), Color3.fromRGB(232, 196, 96), Enum.Material.Fabric, true),
	},
	hollow_lantern = {
		DisplayName = "Hollow Lantern",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Its light is not for you.",
		Use = "The dead notice you a little later.",
		Tip = "A charm, worn at the Reliquary. The dead notice you from a fifth less distance. Once they are on you, nothing changes.",
		Look = look("Block", Vector3.new(0.5, 0.9, 0.5), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	sextons_key = {
		DisplayName = "Sexton's Key",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Every grave has one lock. This opens the one that was left shut.",
		Use = "Opens one locked cache a run.",
		Tip = "A charm, worn at the Reliquary. Its effect, one locked cache a run, is not yet wrought.",
		Look = look("Bar", Vector3.new(0.14, 0.14, 1), Color3.fromRGB(232, 196, 96), Enum.Material.Metal, true),
	},
	kings_seal = {
		DisplayName = "The King's Seal",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Pressed in wax that never cooled.",
		Use = "Proof.",
		Tip = "Proof that the Fallen King is freed. Nothing uses it yet: keep it.",
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
		Tip = "Lay nine on the Altar in the Chapel to raise the Falling Star. A shard is never lost, even when the party falls.",
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
		Tip = "Pages are copied out when a Deed is done. They come home even when the party falls.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_smithy_tally = {
		DisplayName = "A Smith's Tally",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Two hundred and twelve, and three more for no one.",
		Use = "Read it in the Journal, at the Chapel.",
		Tip = "Pages are copied out when a Deed is done. They come home even when the party falls.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_rows_letters = {
		DisplayName = "The Clerk's Muster",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "Nineteen of sixty-one.",
		Use = "Read it in the Journal, at the Chapel.",
		Tip = "Pages are copied out when a Deed is done. They come home even when the party falls.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_ward_papers = {
		DisplayName = "The Marshal's Dispatch",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "We kept the gate as long as there was a gate.",
		Use = "Read it in the Journal, at the Chapel.",
		Tip = "Pages are copied out when a Deed is done. They come home even when the party falls.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
	page_keep_papers = {
		DisplayName = "The Chancery's Last Page",
		Category = "Relic",
		Stackable = false,
		Rank = "Relic",
		Flavour = "The ink is still wet.",
		Use = "Read it in the Journal, at the Chapel.",
		Tip = "Pages are copied out when a Deed is done. They come home even when the party falls.",
		Look = look("Block", Vector3.new(0.8, 0.06, 0.6), Color3.fromRGB(226, 210, 170), Enum.Material.Fabric),
	},
}

return table.freeze(Items)
