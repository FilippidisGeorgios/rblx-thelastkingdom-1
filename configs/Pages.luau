--!strict
--[[
	Config: Pages
	The Journal's pages (docs/systems/Spoils.md §6.2, Story.md). A page is a thing the
	party copies out of a place in the castle when a Deed is done: it comes home in the
	stash as `page_<id>` (never lost, even on a wiped run) and is read in the Chapel.

	They are the Story's papyrus language: short, in the voice of whoever wrote the
	original, and they never explain the curse: they hand the player a fact and let
	them put it with the others.

	Read via: Config.get("Pages")

	[id] = {
		Order = number,        -- the castle's order (chamber), the Journal's order
		Place = string,        -- where it was found
		Title = string,
		Sign = string,         -- who wrote it
		Lines = { string },
	}
]]

local Pages = {
	page_graveyard_bell = {
		Order = 4,
		Place = "The Graveyard",
		Title = "The Sexton's Ledger",
		Sign = "Aldous Pell, sexton",
		Lines = {
			"Burials, the fifth winter. Forty-one. I stopped writing the names in the second month: there was no one left to read them out.",
			"I have dug the long row by the east wall for the Company, in case. Forty places. No one has been sent for them.",
			"I ring the bell for each, as is proper. The ones I bury do not stay long enough to hear it.",
		},
	},
	page_smithy_tally = {
		Order = 5,
		Place = "The Smithy",
		Title = "A Smith's Tally",
		Sign = "Gerrit Hale, smith",
		Lines = {
			"Swords made for the Company, the last spring before they marched: two hundred and twelve. Cut and tempered, every one.",
			"The king came himself to the forge to see them boxed. He did not speak. He put his hand on the cold iron and kept it there.",
			"I made the last three after the bells stopped. I do not know who they were for.",
		},
	},
	page_rows_letters = {
		Order = 7,
		Place = "The Rows",
		Title = "The Clerk's Muster",
		Sign = "Hobb Tarrow, clerk of the Rows",
		Lines = {
			"Households answering the muster: nineteen of sixty-one. The heralds read the names of the absent every new moon.",
			"The Company's names are in the third drawer, under the star. Whoever comes home should have them back.",
			"He keeps asking the heralds if the dead can hear. They say it is not for them to say.",
		},
	},
	page_ward_papers = {
		Order = 8,
		Place = "The Inner Ward",
		Title = "The Marshal's Dispatch",
		Sign = "Marshal Edric Vane",
		Lines = {
			"The line held at the ward until the third night. Then the ones we had buried came up the road, and they knew the way in.",
			"I have sent for the Company eleven times. I am told the road north is not a road any longer.",
			"If the keep is shut against us, say that we kept the gate as long as there was a gate.",
		},
	},
	page_keep_papers = {
		Order = 9,
		Place = "The Keep",
		Title = "The Chancery's Last Page",
		Sign = "The King's scribe",
		Lines = {
			"The king went down beneath the keep on the night of the first frost, alone, with the key that was never to be turned.",
			"What came up the stair was not he, and was. It knew my name. It asked whether the bells had been rung.",
			"I am keeping the hall as I was bid. I have not been told what for.",
		},
	},
}

return table.freeze(Pages)
