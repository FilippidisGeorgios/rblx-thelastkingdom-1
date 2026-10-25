--!strict
--[[
	Config: Camp
	What a camp's bench can make (docs/systems/Spoils.md §6.1, Trials.md §6). A camp
	is lit in the mouth of every passage once its gate is open (Server/World/
	CampService): a fire to stand by, a bench, a chest, and the place the fallen come
	back to. The bench is instant and has four buttons; the point is that after the
	Kitchens a player WANTS cloth, and after the Smithy wants iron.

	Read via: Config.get("Camp")

	Recipe = {
		id     = string,
		label  = string,                        -- the button
		needs  = { [itemId]: count },           -- spent
		makes  = { item: string, count: number } | { torch: number },
		                                        -- an item into the pack, or a lit torch for `torch` seconds
	}
]]

local Camp = {
	-- How far from the bench a player may be and still use it, studs.
	Reach = 14,
	-- The fire heals those who stand by it: this much, every second, within this many studs.
	Warmth = { Heal = 3, Radius = 13 },

	Recipes = {
		{ id = "bandage", label = "Bandage", needs = { grave_cloth = 3 }, makes = { item = "bandage", count = 1 } },
		{ id = "arrows", label = "Arrows", needs = { wild_feather = 2, rusted_iron = 1 }, makes = { item = "arrow_bundle", count = 1 } },
		{ id = "oil_pot", label = "Oil pot", needs = { tallow = 2, rusted_iron = 1 }, makes = { item = "oil_pot", count = 1 } },
		{ id = "torch", label = "Torch", needs = { tallow = 1, grave_cloth = 1 }, makes = { torch = 45 } },
	},
}

return table.freeze(Camp)
