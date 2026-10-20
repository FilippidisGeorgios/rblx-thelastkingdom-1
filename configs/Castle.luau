--!strict
--[[
	Config: Castle
	The castle's numbers: how wide it is, how deep each chamber is, where the
	gaps in the cross-walls sit. One source of truth.

	The castle is BUILT by a tool (`tools/BuildBattleground.luau`) and GATED by a
	service (`Server/World/AreaService`). Before this file each kept its own
	copy of these values, and the only thing tying them together was that the
	copies agreed. Now both read them from here.

	CHANGING THEM DOES NOT MOVE ANY STONE. The walls are instances in the place.
	To change the size of a built castle, edit the numbers here AND run
	`tools/BuildBattleground.luau` with MODE = "resize" (it reads the old size
	from the Battleground's attributes, so it knows what it is resizing from).

	History: 300 x 1800 with 200-stud chambers until 2026-10-19; widened 25%
	both ways (to 376 x 2250, 250-stud chambers) for room to build in.

	Read via: Config.get("Castle")
]]

local Castle = {
	-- Half the width between the centre lines of the side walls.
	HalfWidth = 188,

	-- The front wall's line; the player walks toward -z from here.
	ZStart = 20,

	Chambers = 9,
	ChamberDepth = 250,

	WallHeight = 62,
	WallThickness = 14,

	-- The single opening in each cross-wall, and how far in from the side wall
	-- it sits. Odd chambers open on the east (+x), even on the west (-x).
	GapWidth = 46,
	GapInset = 12,

	-- Distance from a side wall's centre line to its inner face (half the
	-- wall plus the batter at its foot). Inside this, the floor is yours.
	WallInnerOffset = 17,

	-- The ground inside the walls.
	GroundY = 2,
}

-- Derived values, so nobody re-derives them by hand.
function Castle.zEnd(): number
	return Castle.ZStart - Castle.Chambers * Castle.ChamberDepth
end

-- The z range of chamber `index`, near edge first.
function Castle.chamberBounds(index: number): (number, number)
	local zNear = Castle.ZStart - (index - 1) * Castle.ChamberDepth
	return zNear, zNear - Castle.ChamberDepth
end

-- The centre of the opening at the far end of chamber `index`.
function Castle.gapX(index: number): number
	local x = Castle.HalfWidth - Castle.GapWidth / 2 - Castle.GapInset
	return if index % 2 == 1 then x else -x
end

-- How far either way from x = 0 the inside of the walls reaches.
function Castle.innerHalfWidth(): number
	return Castle.HalfWidth - Castle.WallInnerOffset
end

return Castle
