--!strict
--[[
	CatacombMaze
	The floor plan of the Catacombs as a graph of cells, and nothing else (no Instances, no services): which cells open
	into which, which openings are low, which are shut, how far apart two cells are along the passages, and where a cell
	stands in the world. The Doctor's walking, the hearing and the checks of the plan all ask this one thing.

	The data is `configs/CatacombsMaze` (the plan) and `configs/Catacombs` (`Layout`: where it stands, how big a cell is).

	A DIRECTION is "E", "S", "W" or "N" (south is -z in the world). A wall is shared by two cells and stored once, by the
	west or north one: `Cells[row][col]` is a digit, 1 = open to the east, 2 = open to the south, 3 = both.

	THE SHUT WAYS. The Gate and the Barricade are openings in the plan that start shut (`shut(id, true)`) and are opened by
	the errand. While shut they are walls to everything, sound included. The Door is the way out at the end of the exit
	road, outside the grid (the stair's foot), so it is not an edge: `doorShut` says whether the party may leave.

	Place: both places (pure; Server/Domain).
]]

export type Cell = { c: number, r: number }
export type Step = { c: number, r: number, dir: string, low: boolean }

local CatacombMaze = {}
CatacombMaze.__index = CatacombMaze

local DELTA: { [string]: { number } } = { E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 }, N = { 0, -1 } }
local ORDER = { "E", "S", "W", "N" }

local function key(c: number, r: number): string
	return c .. "," .. r
end

-- A wall is one thing seen from either side: name it by the cell to its west or north.
local function edgeKey(c: number, r: number, dir: string): string
	if dir == "W" then
		return key(c - 1, r) .. "E"
	elseif dir == "N" then
		return key(c, r - 1) .. "S"
	end
	return key(c, r) .. dir
end

export type Maze = typeof(setmetatable(
	{} :: {
		cols: number,
		rows: number,
		pitch: number,
		unit: number,
		x0: number,
		zTop: number,
		_open: { [string]: boolean },
		_low: { [string]: boolean },
		_shut: { [string]: boolean }, -- edge keys that are shut right now
		_gates: { [string]: string }, -- id -> edge key
		halls: { any },
		doorShut: boolean,
	},
	CatacombMaze
))

function CatacombMaze.new(plan: any, layout: any): Maze
	local self = setmetatable({
		cols = plan.Cols,
		rows = plan.Rows,
		unit = layout.Unit,
		pitch = layout.Unit * 3,
		x0 = layout.X0,
		zTop = layout.ZTop,
		_open = {},
		_low = {},
		_shut = {},
		_gates = {},
		halls = plan.Halls,
		doorShut = true,
	}, CatacombMaze)

	for r = 1, plan.Rows do
		local line: string = plan.Cells[r]
		assert(#line == plan.Cols, ("catacomb plan row %d has %d cells, wants %d"):format(r, #line, plan.Cols))
		for c = 1, plan.Cols do
			local d = tonumber(string.sub(line, c, c)) or 0
			if bit32.band(d, 1) ~= 0 then
				self._open[edgeKey(c - 1, r - 1, "E")] = true
			end
			if bit32.band(d, 2) ~= 0 then
				self._open[edgeKey(c - 1, r - 1, "S")] = true
			end
		end
	end
	for _, l in plan.Low do
		self._low[edgeKey(l[1], l[2], l[3])] = true
	end
	-- the shut ways start shut
	for id, spec in { gate = plan.Gate, barricade = plan.Barricade } do
		local k = edgeKey(spec[1], spec[2], spec[3])
		self._gates[id] = k
		self._shut[k] = true
	end
	return self
end

--==========================================================================
-- The plan
--==========================================================================
function CatacombMaze.inside(self: Maze, c: number, r: number): boolean
	return c >= 0 and c < self.cols and r >= 0 and r < self.rows
end

-- Is the wall on `dir` of this cell open (and not a shut way)?
function CatacombMaze.isOpen(self: Maze, c: number, r: number, dir: string): boolean
	local d = DELTA[dir]
	if not d or not self:inside(c, r) or not self:inside(c + d[1], r + d[2]) then
		return false
	end
	local k = edgeKey(c, r, dir)
	return self._open[k] == true and not self._shut[k]
end

-- Is that opening a crawl (a low ceiling)?
function CatacombMaze.isLow(self: Maze, c: number, r: number, dir: string): boolean
	return self._low[edgeKey(c, r, dir)] == true
end

-- Open or shut a way by id ("gate", "barricade").
function CatacombMaze.setShut(self: Maze, id: string, shut: boolean)
	local k = self._gates[id]
	assert(k, "unknown way: " .. tostring(id))
	self._shut[k] = if shut then true else nil
end

function CatacombMaze.isShut(self: Maze, id: string): boolean
	local k = self._gates[id]
	return k ~= nil and self._shut[k] == true
end

--[[
	The openings of a cell. `crawl = false` leaves out the low ones: that is the Doctor's view of the plan, since he cannot
	pass them (a crouching body and a crawler can).
]]
function CatacombMaze.steps(self: Maze, c: number, r: number, crawl: boolean?): { Step }
	local out: { Step } = {}
	for _, dir in ORDER do
		if self:isOpen(c, r, dir) then
			local low = self:isLow(c, r, dir)
			if crawl ~= false or not low then
				local d = DELTA[dir]
				table.insert(out, { c = c + d[1], r = r + d[2], dir = dir, low = low })
			end
		end
	end
	return out
end

function CatacombMaze.degree(self: Maze, c: number, r: number): number
	return #self:steps(c, r, true)
end

-- Steps from `from` to every cell it can reach: { [key]: number }, and the way back { [key]: key }.
function CatacombMaze.spread(self: Maze, from: Cell, crawl: boolean?): ({ [string]: number }, { [string]: string })
	local dist: { [string]: number } = { [key(from.c, from.r)] = 0 }
	local parent: { [string]: string } = {}
	local queue: { Cell } = { from }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		local d = dist[key(cur.c, cur.r)]
		for _, s in self:steps(cur.c, cur.r, crawl) do
			local k = key(s.c, s.r)
			if dist[k] == nil then
				dist[k] = d + 1
				parent[k] = key(cur.c, cur.r)
				table.insert(queue, { c = s.c, r = s.r })
			end
		end
	end
	return dist, parent
end

-- The cells from `from` to `to`, both included, or nil when there is no way.
function CatacombMaze.path(self: Maze, from: Cell, to: Cell, crawl: boolean?): { Cell }?
	local dist, parent = self:spread(from, crawl)
	local k = key(to.c, to.r)
	if dist[k] == nil then
		return nil
	end
	local out: { Cell } = {}
	while k ~= nil do
		local c, r = string.match(k, "(-?%d+),(-?%d+)")
		table.insert(out, 1, { c = tonumber(c) :: number, r = tonumber(r) :: number })
		k = parent[k]
	end
	return out
end

-- How many studs of passage lie between two cells (a cell to itself is 0), or nil when no way is open.
function CatacombMaze.reach(self: Maze, a: Cell, b: Cell, crawl: boolean?): number?
	local dist = self:spread(a, crawl)
	local n = dist[key(b.c, b.r)]
	return if n then n * self.pitch else nil
end

function CatacombMaze.reachable(self: Maze, from: Cell, crawl: boolean?): number
	local dist = self:spread(from, crawl)
	local n = 0
	for _ in dist do
		n += 1
	end
	return n
end

function CatacombMaze.hallAt(self: Maze, c: number, r: number): string?
	for _, h in self.halls do
		if c >= h.c0 and c <= h.c1 and r >= h.r0 and r <= h.r1 then
			return h.id
		end
	end
	return nil
end

function CatacombMaze.hall(self: Maze, id: string): any?
	for _, h in self.halls do
		if h.id == id then
			return h
		end
	end
	return nil
end

--==========================================================================
-- The world
--==========================================================================

-- The middle of a cell, in studs: x, z.
function CatacombMaze.centre(self: Maze, c: number, r: number): (number, number)
	return self.x0 + self.unit * (3 * c + 1.5 + 0.5), self.zTop - self.unit * (3 * r + 1.5 + 0.5)
end

-- Which cell is this point in? nil when it is not over a cell's open square or the wall round it.
function CatacombMaze.cellAt(self: Maze, x: number, z: number): Cell?
	local c = math.floor((x - self.x0) / self.pitch)
	local r = math.floor((self.zTop - z) / self.pitch)
	if self:inside(c, r) then
		return { c = c, r = r }
	end
	return nil
end

return CatacombMaze
