--!strict
--[[
	Catacombs.spec
	The floor plan is a real maze (everything can be reached, the exit road is behind the gate), the things to find can all be
	found by a player and some are out of the big one's reach, noise carries along passages and not through walls, and the
	big blind one hunts what he hears.

	Location: TestService.Tests.Catacombs.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CatacombMaze = require(ServerScriptService.Server.Domain.CatacombMaze)
local Hearing = require(ServerScriptService.Server.Domain.Hearing)
local DoctorBrain = require(ServerScriptService.Server.Domain.DoctorBrain)
local Plan: any = require(ReplicatedStorage.Config.CatacombsMaze)
local Cfg: any = require(ReplicatedStorage.Config.Catacombs)

local function fresh()
	return CatacombMaze.new(Plan, Cfg.Layout)
end

local function cellOf(id: string): CatacombMaze.Cell
	for _, f in Plan.Features do
		if f.id == id then
			return { c = f.c, r = f.r }
		end
	end
	error("no feature " .. id)
end

return function(t: any)
	t.test("the plan has the size it says and every cell can be reached from the foot of the stair", function()
		local maze = fresh()
		assert(#Plan.Cells == Plan.Rows, "a row of digits for every row")
		maze:setShut("gate", false)
		maze:setShut("barricade", false)
		local n = maze:reachable({ c = Plan.Start[1], r = Plan.Start[2] }, true)
		assert(n == Plan.Cols * Plan.Rows, ("%d of %d cells reached with every way open"):format(n, Plan.Cols * Plan.Rows))
	end)

	t.test("the exit road lies behind the gate and the barricade is inside it", function()
		local maze = fresh()
		local start = { c = Plan.Start[1], r = Plan.Start[2] }
		local road = Plan.Road
		local roadEnd = { c = road.c, r = road.r1 }
		assert(maze:isShut("gate") and maze:isShut("barricade"), "both start shut")
		assert(maze:path(start, roadEnd, true) == nil, "the exit road cannot be reached while the gate is shut")
		maze:setShut("gate", false)
		assert(maze:path(start, roadEnd, true) == nil, "the barricade still stops the end of the road")
		local beforeBarricade = { c = road.c, r = Plan.Barricade[2] }
		assert(maze:path(start, beforeBarricade, true) ~= nil, "the gate opens the way to the barricade")
		maze:setShut("barricade", false)
		assert(maze:path(start, roadEnd, true) ~= nil, "and the barricade gone, to the end of the road")
	end)

	t.test("every thing to find lies outside the road, so the party can find it before the gate is open", function()
		local maze = fresh()
		local start = { c = Plan.Start[1], r = Plan.Start[2] }
		local dist = maze:spread(start, true)
		for _, f in Plan.Features do
			assert(dist[f.c .. "," .. f.r] ~= nil, f.id .. " cannot be reached before the gate opens")
		end
	end)

	t.test("the places for the key and the axe are in the plan, and there are enough of the rest", function()
		local ids: { [string]: boolean } = {}
		local count: { [string]: number } = {}
		for _, f in Plan.Features do
			ids[f.id] = true
			count[f.kind] = (count[f.kind] or 0) + 1
		end
		for _, id in Cfg.Spots.Key do
			assert(ids[id], "key spot missing: " .. id)
		end
		for _, id in Cfg.Spots.Axe do
			assert(ids[id], "axe spot missing: " .. id)
		end
		assert((count.lever or 0) == Cfg.Errand.Levers, "one lever for each of the levers in the errand")
		assert((count.paper or 0) >= #Cfg.Pages, "a place for every page")
		assert((count.nest or 0) >= Cfg.Crawlers.Count, "a nest for every crawler")
		assert((count.bell or 0) >= 3, "bells to be rung")
		assert((count.pocket or 0) >= 5, "pockets to hide in")
	end)

	t.test("the big one cannot go through a crawl, so those places are a refuge", function()
		local maze = fresh()
		maze:setShut("gate", false)
		maze:setShut("barricade", false)
		local hall = maze:hall(Cfg.Doctor.SpawnHall)
		assert(hall, "his hall exists")
		local from = { c = hall.c0, r = hall.r0 }
		local walkAll = maze:reachable(from, true)
		local doctorOnly = maze:reachable(from, false)
		assert(doctorOnly < walkAll, "some cells can only be reached by crawling")
		assert(walkAll - doctorOnly >= 4, ("only %d cells are cut off by the low openings"):format(walkAll - doctorOnly))
		assert(doctorOnly > walkAll * 0.7, "and the rest of the plan is still his to walk")
		-- the levers are in his reach or the party could never be hunted there: at least two of three
		local reachable = 0
		local dist = maze:spread(from, false)
		for _, f in Plan.Features do
			if f.kind == "lever" and dist[f.c .. "," .. f.r] ~= nil then
				reachable += 1
			end
		end
		assert(reachable >= 2, "most levers are on his round")
	end)

	t.test("a pocket can be entered only by crawling: it is a refuge from the Doctor", function()
		local maze = fresh()
		maze:setShut("gate", false)
		maze:setShut("barricade", false)
		local hall = maze:hall(Cfg.Doctor.SpawnHall)
		local reach = maze:spread({ c = hall.c0, r = hall.r0 }, false)
		local pockets = 0
		for _, f in Plan.Features do
			if f.kind == "pocket" then
				pockets += 1
				assert(reach[f.c .. "," .. f.r] == nil, f.id .. " can be walked into by the Doctor")
				assert(#maze:steps(f.c, f.r, false) == 0, f.id .. " has a way in that is not a crawl")
				assert(#maze:steps(f.c, f.r, true) >= 1, f.id .. " has no way in at all")
			end
		end
		assert(pockets >= 5, "there are pockets")
	end)

	t.test("noise carries along the passages and stops at a shut gate", function()
		local maze = fresh()
		local n = Cfg.Noise
		local start = { c = Plan.Start[1], r = Plan.Start[2] }
		local here = { kind = "step", c = start.c, r = start.r, loudness = n.StepWalk }
		assert(Hearing.hears(maze, here, start), "in the same cell, always")
		local far = cellOf("lever_ossuary")
		assert(not Hearing.hears(maze, here, far), "a footstep at one end is not heard at the other")
		local bell = { kind = "bell", c = start.c, r = start.r, loudness = 100000 }
		assert(Hearing.hears(maze, bell, far), "something loud enough is")
		-- the road is shut behind the gate: nothing reaches it
		local roadCell = { c = Plan.Road.c, r = Plan.Road.r0 + 1 }
		assert(not Hearing.hears(maze, bell, roadCell), "the gate stops even a great noise")
		maze:setShut("gate", false)
		assert(Hearing.hears(maze, bell, roadCell), "and an open gate lets it through")
	end)

	t.test("a body that is crouched is nearly silent, and one that is still is silent", function()
		local n = Cfg.Noise
		assert(Hearing.footstep(n, 0, false) == 0, "standing still")
		assert(Hearing.footstep(n, 8, true) == n.StepCrouch, "crouched and moving")
		assert(Hearing.footstep(n, 16, false) == n.StepWalk, "walking")
		assert(Hearing.footstep(n, 20, false) == n.StepRun, "running")
		assert(n.StepCrouch < 10.5, "a crouched step does not carry one cell")
		assert(n.StepWalk > n.StepCrouch * 3, "walking is much louder")
		assert(Hearing.footstep(n, 16, false, true) == 0, "in the air")
		assert(Hearing.touches(n, n.Touch - 0.1) and not Hearing.touches(n, n.Touch + 0.1), "touching range")
	end)

	t.test("the louder noise wins the memory, and it is forgotten after a while", function()
		local mem = Hearing.newMemory(5)
		local quiet = { kind = "step", c = 1, r = 1, loudness = 10 } :: Hearing.Noise
		local loud = { kind = "bell", c = 9, r = 9, loudness = 90 } :: Hearing.Noise
		assert(Hearing.hear(mem, quiet, 0), "the first is taken")
		assert(Hearing.hear(mem, loud, 1), "a louder one replaces it")
		assert(not Hearing.hear(mem, quiet, 2), "a quieter one does not")
		local held = Hearing.recall(mem, 3)
		assert(held and held.kind == "bell", "the bell is remembered")
		assert(Hearing.recall(mem, 20) == nil, "forgotten after a while")
		assert(Hearing.hear(mem, quiet, 21), "and then anything is taken again")
	end)

	t.test("the Doctor walks his round, goes to a noise, searches, and goes back", function()
		local stops = { { c = 2, r = 2 }, { c = 8, r = 8 }, { c = 12, r = 2 } }
		local brain = DoctorBrain.new(Cfg.Doctor, Cfg.Noise, stops, 10.5, function()
			return 0.3
		end)
		local here = { c = 5, r = 5 }
		local a = brain:update(0.1, 0, here, {})
		assert(a.state == "Prowl" and a.walk ~= nil, "no noise: he walks his round")
		assert(a.speed == Cfg.Doctor.Speeds.Prowl, "at a slow pace")

		brain:hear({ kind = "lever", c = 14, r = 10, loudness = 60 }, 1)
		a = brain:update(0.1, 1, here, {})
		assert(a.state == "Investigate", "he goes to the noise")
		assert(a.walk and a.walk.c == 14 and a.walk.r == 10, "to where it was")
		assert(a.speed == Cfg.Doctor.Speeds.Investigate, "faster than a stroll")

		a = brain:update(0.1, 2, { c = 14, r = 10 }, {})
		assert(a.state == "Search" and a.walk == nil, "he stops and listens where it was")
		for i = 1, 200 do
			a = brain:update(0.1, 2 + i * 0.1, { c = 14, r = 10 }, {})
		end
		assert(a.state == "Prowl" or a.state == "Listen", "nothing more: back to his round, not " .. a.state)
	end)

	t.test("a body that keeps walking close by is chased, and one in reach is struck", function()
		local brain = DoctorBrain.new(Cfg.Doctor, Cfg.Noise, { { c = 2, r = 2 } }, 10.5)
		local here = { c = 6, r = 6 }
		brain:hear({ kind = "step", c = 8, r = 6, loudness = Cfg.Noise.StepWalk, source = "p1" }, 0)
		local a = brain:update(0.1, 0, here, {})
		assert(a.state == "Chase" and a.speed == Cfg.Doctor.Speeds.Chase, "the same walker near: a chase")
		brain:hear({ kind = "step", c = 9, r = 6, loudness = Cfg.Noise.StepWalk, source = "p1" }, 0.5)
		a = brain:update(0.1, 0.5, here, {})
		assert(a.walk and a.walk.c == 9, "he follows to the next step")

		-- a body within reach: the swing, then the blow lands once
		local struck = 0
		local blow: string? = nil
		local bodies = { { id = "p1", c = 6, r = 6, distance = 5 } }
		for i = 1, 40 do
			a = brain:update(0.1, 1 + i * 0.1, here, bodies)
			if a.strike then
				struck += 1
				blow = a.strike
			end
		end
		assert(struck >= 1 and blow == "p1", "the blow lands on the body in reach")
		local brain2 = DoctorBrain.new(Cfg.Doctor, Cfg.Noise, { { c = 2, r = 2 } }, 10.5)
		local lands = 0
		for i = 1, 8 do
			local r = brain2:update(0.1, i * 0.1, here, { { id = "p2", c = 6, r = 6, distance = 5 } })
			if r.strike then
				lands += 1
			end
		end
		assert(lands == 0, "but not at once: the windup is a warning")
	end)

	t.test("a crouched body that is not touching him is not chased", function()
		-- a crouched step carries 7 studs: from two cells away it is not heard
		local maze = fresh()
		local n = Cfg.Noise
		local cell = cellOf("lever_quarry")
		local noise = { kind = "step", c = cell.c, r = cell.r, loudness = n.StepCrouch } :: Hearing.Noise
		local d = maze:spread(cell, true)
		local twoAway: CatacombMaze.Cell? = nil
		for k, steps in d do
			if steps == 2 then
				local c, r = string.match(k, "(-?%d+),(-?%d+)")
				twoAway = { c = tonumber(c) :: number, r = tonumber(r) :: number }
				break
			end
		end
		assert(twoAway, "a cell two steps off")
		assert(not Hearing.hears(maze, noise, twoAway :: CatacombMaze.Cell), "a crouched step is lost two cells off")
	end)

	t.test("the passages are the size that was promised", function()
		local l = Cfg.Layout
		assert(l.Unit * 2 >= 7, "a passage is two units wide: at least 7 studs")
		assert(l.PassageHeight >= Cfg.Doctor.Height + 0.5, "the Doctor fits under the ceiling with air to spare")
		assert(Cfg.Doctor.Width < l.Unit * 2, "and between the walls")
		assert(l.CrawlHeight < 3.8 and l.CrawlHeight > 3.1, "a crawl clears a crouched body (3.0) and stops a standing one")
	end)
end
