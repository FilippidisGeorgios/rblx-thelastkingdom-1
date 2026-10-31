--!strict
--[[
	Config: CatacombsMaze
	The catacombs' floor plan, GENERATED once by a design-time script (seeded; seed 7) and then kept as data. Do not edit by hand:
	change the tuning in `Catacombs.luau`, or ask for a new plan.

	A plan is a grid of CELLS (22 columns, 18 rows). Each cell is one digit in `Cells[row][col]`:
	  1 = open to the EAST neighbour, 2 = open to the SOUTH neighbour, 3 = both, 0 = neither (walls are shared, so every
	  wall is stored once, by the cell to its west or north). Column 0 is the west (the exit side), column 21 the east (where you come down);
	  row 0 is the north (toward the gate you came through), the last row the south. South is -z in the world.

	Halls are blocks of cells with the walls between them taken out (the pillars stay). `Low` lists openings with a LOW ceiling
	(a crawl): the big dead cannot pass them. Gate, Barricade and Door are the three shut ways at the exit road.

	Read via: Config.get("CatacombsMaze")
]]

local CatacombsMaze = {
	Seed = 7,
	Cols = 22,
	Rows = 18,
	Cells = {
		"3303333113112333333132",
		"3031101212321131111100",
		"3222332122211212123122",
		"2101021222112122302222",
		"1111103020310221230210",
		"3231122212231212212310",
		"0233210230221030222132",
		"3033213223332302301202",
		"3213032023332123032122",
		"2321222301130221221212",
		"2023022130303212232110",
		"2301221211032122221312",
		"2311031131201222011030",
		"2213211212231021112302",
		"2122111030112333322212",
		"2221233332312333322112",
		"2301033332222111301122",
		"0111111110101111111010",
	},
	Low = {
		{ 19, 17, "W" },
		{ 9, 4, "N" },
		{ 7, 5, "S" },
		{ 16, 2, "E" },
		{ 3, 2, "S" },
		{ 7, 8, "N" },
		{ 1, 10, "N" },
		{ 12, 14, "W" },
		{ 18, 10, "W" },
		{ 7, 11, "S" },
		{ 19, 0, "W" },
		{ 0, 0, "S" },
	},
	Halls = {
		{ id = "crypt", c0 = 9, c1 = 12, r0 = 7, r1 = 9 },
		{ id = "study", c0 = 2, c1 = 4, r0 = 6, r1 = 8 },
		{ id = "ossuary", c0 = 3, c1 = 5, r0 = 0, r1 = 1 },
		{ id = "ward", c0 = 13, c1 = 18, r0 = 0, r1 = 1 },
		{ id = "quarry", c0 = 5, c1 = 9, r0 = 15, r1 = 17 },
		{ id = "gaol", c0 = 13, c1 = 17, r0 = 14, r1 = 16 },
	},
	-- The exit road: column 0, rows 9 to 17. It is entered only through the Gate (the edge south of cell 0,8).
	Road = { c = 0, r0 = 9, r1 = 17 },
	Gate = { 0, 8, "S" },
	Barricade = { 0, 12, "S" },
	Door = { 0, 15, "W" },
	Start = { 21, 2 },
	Exit = { 0, 15 },
	Features = {
		{ kind = "keyspot", id = "key_ward1", c = 15, r = 2 },
		{ kind = "keyspot", id = "key_ward2", c = 16, r = 3 },
		{ kind = "keyspot", id = "key_gaol1", c = 15, r = 13 },
		{ kind = "keyspot", id = "key_gaol2", c = 15, r = 17 },
		{ kind = "axespot", id = "axe_quarry1", c = 7, r = 14 },
		{ kind = "axespot", id = "axe_quarry2", c = 4, r = 16 },
		{ kind = "axespot", id = "axe_quarry3", c = 6, r = 14 },
		{ kind = "lever", id = "lever_ossuary", c = 4, r = 2 },
		{ kind = "lever", id = "lever_quarry", c = 5, r = 14 },
		{ kind = "lever", id = "lever_ward", c = 18, r = 3 },
		{ kind = "paper", id = "paper1", c = 20, r = 7 },
		{ kind = "paper", id = "paper2", c = 18, r = 9 },
		{ kind = "paper", id = "paper3", c = 12, r = 3 },
		{ kind = "paper", id = "paper4", c = 8, r = 11 },
		{ kind = "paper", id = "paper5", c = 2, r = 13 },
		{ kind = "paper", id = "paper6", c = 11, r = 12 },
		{ kind = "paper", id = "paper7", c = 6, r = 4 },
		{ kind = "paper", id = "paper8", c = 15, r = 7 },
		{ kind = "paper", id = "paper9", c = 1, r = 3 },
		{ kind = "bell", id = "bell1", c = 18, r = 5 },
		{ kind = "bell", id = "bell2", c = 10, r = 12 },
		{ kind = "bell", id = "bell3", c = 4, r = 3 },
		{ kind = "bell", id = "bell4", c = 10, r = 16 },
		{ kind = "nest", id = "nest1", c = 14, r = 5 },
		{ kind = "nest", id = "nest2", c = 7, r = 10 },
		{ kind = "nest", id = "nest3", c = 1, r = 15 },
		{ kind = "nest", id = "nest4", c = 19, r = 15 },
		{ kind = "nest", id = "nest5", c = 3, r = 3 },
		{ kind = "nest", id = "nest6", c = 4, r = 10 },
		{ kind = "nest", id = "nest7", c = 18, r = 14 },
		{ kind = "nest", id = "nest8", c = 9, r = 2 },
		{ kind = "nest", id = "nest9", c = 4, r = 17 },
		{ kind = "nest", id = "nest10", c = 19, r = 16 },
		{ kind = "nest", id = "nest11", c = 12, r = 5 },
		{ kind = "nest", id = "nest12", c = 16, r = 1 },
		{ kind = "nest", id = "nest13", c = 3, r = 14 },
		{ kind = "nest", id = "nest14", c = 21, r = 10 },
		{ kind = "nest", id = "nest15", c = 5, r = 2 },
		{ kind = "nest", id = "nest16", c = 16, r = 5 },
		{ kind = "pocket", id = "pocket1", c = 19, r = 17 },
		{ kind = "pocket", id = "pocket2", c = 9, r = 4 },
		{ kind = "pocket", id = "pocket3", c = 7, r = 5 },
		{ kind = "pocket", id = "pocket4", c = 16, r = 2 },
		{ kind = "pocket", id = "pocket5", c = 3, r = 2 },
		{ kind = "pocket", id = "pocket6", c = 7, r = 8 },
		{ kind = "pocket", id = "pocket7", c = 1, r = 10 },
	},
}

return table.freeze(CatacombsMaze)
