--!strict
--[[
	TrialRun.spec
	Phases in order, all / any / count, deeds that never gate, and repeats.

	Location: TestService.Tests.TrialRun.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local TrialRun = require(ServerScriptService.Server.Domain.TrialRun)

local function def()
	return {
		phases = {
			{ id = "a", tasks = { { id = "a1" }, { id = "a2" } } },
			{ id = "b", mode = "any", tasks = { { id = "b1" }, { id = "b2" } } },
			{ id = "c", mode = "count", count = 2, tasks = { { id = "c1" }, { id = "c2" }, { id = "c3" } } },
		},
		deeds = { { id = "bell" } },
	}
end

return function(t: any)
	t.test("starts on phase 1 and lists its tasks", function()
		local run = TrialRun.new(def())
		assert(not run:isStarted(), "not started")
		local ids = run:start()
		assert(#ids == 2 and ids[1] == "a1", "phase 1 tasks")
		assert(#run:start() == 0, "a second start does nothing")
	end)

	t.test("mode all needs every task", function()
		local run = TrialRun.new(def())
		run:start()
		local change = run:taskDone("a1")
		assert(change and not change.phaseDone, "one of two is not enough")
		local done, needed = run:progress()
		assert(done == 1 and needed == 2, "1 of 2")
		change = run:taskDone("a2")
		assert(change and change.phaseDone and change.nextPhase == 2 and not change.complete, "phase 2 live")
	end)

	t.test("mode any needs one", function()
		local run = TrialRun.new(def())
		run:start()
		run:taskDone("a1")
		run:taskDone("a2")
		local change = run:taskDone("b2")
		assert(change and change.phaseDone and change.nextPhase == 3, "one was enough")
	end)

	t.test("mode count needs N of M, and the trial completes after the last phase", function()
		local run = TrialRun.new(def())
		run:start()
		run:taskDone("a1")
		run:taskDone("a2")
		run:taskDone("b1")
		local change = run:taskDone("c3")
		assert(change and not change.phaseDone, "1 of 2")
		change = run:taskDone("c1")
		assert(change and change.complete and change.nextPhase == nil, "complete")
		assert(run:isComplete(), "isComplete")
	end)

	t.test("a task from a phase that is not live is ignored", function()
		local run = TrialRun.new(def())
		run:start()
		assert(run:taskDone("b1") == nil, "phase 2 is not live yet")
		assert(run:taskDone("nope") == nil, "unknown id")
	end)

	t.test("a repeat is not news", function()
		local run = TrialRun.new(def())
		run:start()
		run:taskDone("a1")
		assert(run:taskDone("a1") == nil, "a1 twice")
	end)

	t.test("a deed never gates and is remembered", function()
		local run = TrialRun.new(def())
		run:start()
		assert(run:taskDone("bell") == nil, "a deed changes nothing")
		assert(run:deedDone("bell"), "but it is recorded")
		local done = run:progress()
		assert(done == 0, "and is not counted toward the phase")
	end)
end
