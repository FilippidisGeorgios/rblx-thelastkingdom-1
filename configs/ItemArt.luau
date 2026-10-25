--!strict
--[[
	Config: ItemArt
	The picture of each item (UI/ItemArt, UI/ItemCard): the AI-generated mesh and its texture, as asset ids,
	so a place needs no copy of the models, only the config. An item with no entry here is drawn from its
	`Look` in configs/Items (a block, a ball, a disc, a bar). Every page_* shares the `page` entry.

	Made with the Studio generate_mesh tool (a text prompt per item, in docs/systems/ItemArt.md): to remake one,
	generate it again and replace its two ids.

	Read via: Config.get("ItemArt")

	Art = {
		[key] = {
			Mesh = "rbxassetid://...",
			Texture = "rbxassetid://...",
			Tilt = Vector3?,    -- degrees the model is turned toward the viewer; default (14, -38, 0)
		},
	}
]]

local ItemArt = {
	Art = {
		bone_dust = { Mesh = "rbxassetid://139672385940052", Texture = "rbxassetid://124288464646992" },
		grave_cloth = { Mesh = "rbxassetid://102098918362470", Texture = "rbxassetid://75530439075732" },
		rusted_iron = { Mesh = "rbxassetid://88312305338421", Texture = "rbxassetid://76617923425683" },
		wild_feather = { Mesh = "rbxassetid://136988444118005", Texture = "rbxassetid://135607675567935" },
		tallow = { Mesh = "rbxassetid://119512339284795", Texture = "rbxassetid://127775093857976" },
		grave_silver = { Mesh = "rbxassetid://116814435661246", Texture = "rbxassetid://78570010594846" },
		hollow_ember = { Mesh = "rbxassetid://76944998813420", Texture = "rbxassetid://85103318633386" },
		bandage = { Mesh = "rbxassetid://132181896354465", Texture = "rbxassetid://135205083566192" },
		arrow_bundle = { Mesh = "rbxassetid://94998704505412", Texture = "rbxassetid://100206401558367" },
		oil_pot = { Mesh = "rbxassetid://120229237092053", Texture = "rbxassetid://74776813804689" },
		hearty_dish = { Mesh = "rbxassetid://130906248920859", Texture = "rbxassetid://111701230028915" },
		saints_medal = { Mesh = "rbxassetid://114804233345729", Texture = "rbxassetid://97089396140587" },
		company_signet = { Mesh = "rbxassetid://82118950664453", Texture = "rbxassetid://99871759204227" },
		brass_stirrup = { Mesh = "rbxassetid://106444852379517", Texture = "rbxassetid://116320841330029" },
		mourners_veil = { Mesh = "rbxassetid://122713070836876", Texture = "rbxassetid://106110914587994" },
		hollow_lantern = { Mesh = "rbxassetid://100100455866724", Texture = "rbxassetid://126290320026581" },
		sextons_key = { Mesh = "rbxassetid://89149520650534", Texture = "rbxassetid://99428722649844" },
		kings_seal = { Mesh = "rbxassetid://81199509955208", Texture = "rbxassetid://80672018354905" },
		star_shard = { Mesh = "rbxassetid://91836898437677", Texture = "rbxassetid://87628324742653" },
		page = { Mesh = "rbxassetid://88449846831863", Texture = "rbxassetid://100598647091501" },
	},
}

return table.freeze(ItemArt)
