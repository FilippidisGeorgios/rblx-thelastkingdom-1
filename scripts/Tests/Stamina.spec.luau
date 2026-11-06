--!strict
--[[
	Stamina.spec
	The developer's numbers (2026-11-05): 6 seconds of running on a full bar, a roll costs 1.5 (four rolls on a full bar),
	the bar starts to fill 1 second after the last run or roll and fills from empty to full in 15 seconds; a run that
	empties the bar needs a new press of Shift.

	Location: TestService.Tests.Stamina.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stamina = require(ReplicatedStorage.Shared.Stamina)
local Movement: any = require(ReplicatedStorage.Config.Movement)

local cfg = Movement.Stamina
local COST = Movement.Roll.Cost

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

-- runs the bar in steps of `dt` for `seconds`, starting at time `t0`; returns the time it ends at
local function run(s: Stamina.State, t0: number, seconds: number, running: boolean, dt: number?): number
	local step = dt or 1 / 60
	local t = t0
	local n = math.floor(seconds / step + 0.5)
	for _ = 1, n do
		t += step
		Stamina.step(s, cfg, step, t, running)
	end
	return t
end

return function(t: any)
	t.test("the developer's numbers", function()
		assert(cfg.Max == 6, "6 seconds of running")
		assert(COST == 1.5, "a roll costs 1.5")
		assert(near(cfg.Max / COST, 4), "four rolls on a full bar")
		assert(cfg.RefillDelay == 1 and cfg.RefillSeconds == 15, "fills after 1 s, empty to full in 15 s")
	end)

	t.test("a full bar runs for 6 seconds and then the run stops", function()
		local s = Stamina.new(cfg)
		local tEnd = run(s, 0, 5.9, true)
		assert(s.value > 0 and Stamina.canRun(s), "still running at 5.9 s")
		run(s, tEnd, 0.2, true)
		assert(s.value == 0, "empty at 6 s")
		assert(not Stamina.canRun(s), "and the run is over")
	end)

	t.test("an emptied run needs Shift pressed again, even after the bar has filled a little", function()
		local s = Stamina.new(cfg)
		local t1 = run(s, 0, 6.1, true)
		-- Shift still held but the run is spent: the bar fills after the delay, the run does not come back
		local t2 = run(s, t1, 3, true)
		assert(s.value > 0, "the bar has come back a little")
		assert(not Stamina.canRun(s), "but not the run, until Shift is let go")
		Stamina.release(s)
		assert(Stamina.canRun(s), "a new press runs again")
		assert(t2 > t1)
	end)

	t.test("nothing fills for 1 second after the last use, then empty to full takes 15 seconds", function()
		local s = Stamina.new(cfg)
		run(s, 0, 6.1, true)
		Stamina.release(s)
		local emptied = s.lastUse -- the moment the run emptied the bar
		-- step exactly to the marks, from the moment it emptied
		Stamina.step(s, cfg, 0.95, emptied + 0.95, false)
		assert(s.value == 0, "still empty inside the first second")
		Stamina.step(s, cfg, 0.05 + 7.5, emptied + 8.5, false)
		assert(near(s.value, 3, 1e-4), ("half full 7.5 s after the delay, got %.4f"):format(s.value))
		Stamina.step(s, cfg, 7.5, emptied + 16, false)
		assert(near(s.value, cfg.Max, 1e-4), "full after 15 s of filling")
	end)

	t.test("four rolls on a full bar, not five", function()
		local s = Stamina.new(cfg)
		for i = 1, 4 do
			assert(Stamina.roll(s, COST, i * 0.7), ("roll %d"):format(i))
		end
		assert(near(s.value, 0), "empty after four")
		assert(not Stamina.roll(s, COST, 3.5), "no fifth")
		assert(near(s.value, 0), "and the refused roll spent nothing")
	end)

	t.test("a roll pushes the filling back by a second", function()
		local s = Stamina.new(cfg)
		Stamina.roll(s, COST, 0)
		local t1 = run(s, 0, 0.9, false)
		assert(near(s.value, cfg.Max - COST), "no filling yet")
		run(s, t1, 1.1, false)
		assert(s.value > cfg.Max - COST, "filling after the delay")
	end)

	t.test("standing still with Shift held costs nothing", function()
		-- the server only counts it as running while the body moves; this is the rule's side of it
		local s = Stamina.new(cfg)
		run(s, 0, 3, false)
		assert(s.value == cfg.Max, "full")
	end)

	t.test("a big step of time is handled in one go", function()
		local s = Stamina.new(cfg)
		Stamina.roll(s, COST, 0)
		Stamina.step(s, cfg, 20, 20, false)
		assert(s.value == cfg.Max, "filled to the top, not past it")
	end)
end
