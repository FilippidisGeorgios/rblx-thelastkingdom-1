--!strict
--[[
	TrialRun (domain class)
	The state of one chamber's trial (docs/systems/Trials.md): which PHASE is live,
	which of its tasks are done, and when the whole thing is complete. Pure, like
	EncounterRun: it hears `taskDone(id)` and says what changed; it spawns nothing,
	builds nothing and knows no verbs. TrialService turns its answers into props,
	prompts and gates.

	THE MODEL
	  phases   ordered; phase N+1 starts only when phase N is done
	  tasks    inside a phase, all running at once; a phase is done when
	             mode "all"    (default) every task is done
	             mode "any"    one task is done
	             mode "count"  `count` of its tasks are done
	  deeds    optional tasks for the whole trial; they never gate a phase and a
	           trial can finish with every one of them undone

	Location: ServerScriptService.Server.Domain.TrialRun
]]

local TrialRun = {}
TrialRun.__index = TrialRun

export type TaskRef = { id: string }

export type PhaseDef = {
	id: string,
	hint: string?,
	mode: string?, -- "all" | "any" | "count"
	count: number?,
	tasks: { TaskRef },
}

export type TrialDef = {
	id: string?,
	phases: { PhaseDef },
	deeds: { TaskRef }?,
}

export type TrialRun = typeof(setmetatable(
	{} :: {
		def: TrialDef,
		phase: number, -- 0 = not started, #phases + 1 = complete
		done: { [string]: boolean },
		deedsDone: { [string]: boolean },
	},
	TrialRun
))

export type Change = {
	phaseDone: boolean, -- the live phase just finished
	nextPhase: number?, -- the phase that is now live (nil when complete)
	complete: boolean,
}

function TrialRun.new(def: TrialDef): TrialRun
	assert(#def.phases > 0, "a trial needs at least one phase")
	return setmetatable({
		def = def,
		phase = 0,
		done = {},
		deedsDone = {},
	}, TrialRun)
end

function TrialRun.isComplete(self: TrialRun): boolean
	return self.phase > #self.def.phases
end

function TrialRun.isStarted(self: TrialRun): boolean
	return self.phase >= 1
end

-- Begins phase 1. Returns its task ids. A second call changes nothing.
function TrialRun.start(self: TrialRun): { string }
	if self.phase ~= 0 then
		return {}
	end
	self.phase = 1
	return self:liveTasks()
end

function TrialRun.currentPhase(self: TrialRun): PhaseDef?
	return self.def.phases[self.phase]
end

function TrialRun.liveTasks(self: TrialRun): { string }
	local ids: { string } = {}
	local phase = self:currentPhase()
	if phase then
		for _, task in phase.tasks do
			table.insert(ids, task.id)
		end
	end
	return ids
end

function TrialRun.deedIds(self: TrialRun): { string }
	local ids: { string } = {}
	for _, deed in self.def.deeds or {} do
		table.insert(ids, deed.id)
	end
	return ids
end

-- How many of the live phase's tasks are done, and how many are needed.
function TrialRun.progress(self: TrialRun): (number, number)
	local phase = self:currentPhase()
	if not phase then
		return 0, 0
	end
	local doneCount = 0
	for _, task in phase.tasks do
		if self.done[task.id] then
			doneCount += 1
		end
	end
	local mode = phase.mode or "all"
	local needed = if mode == "any" then 1 elseif mode == "count" then (phase.count or #phase.tasks) else #phase.tasks
	return doneCount, needed
end

local function isDeed(self: TrialRun, id: string): boolean
	for _, deed in self.def.deeds or {} do
		if deed.id == id then
			return true
		end
	end
	return false
end

--[[
	A task reports done. Returns what changed, or nil if it is not news (an
	unknown id, a repeat, a task of a phase that is not live, a deed).
]]
function TrialRun.taskDone(self: TrialRun, id: string): Change?
	if isDeed(self, id) then
		self.deedsDone[id] = true
		return nil
	end
	if self.phase < 1 or self:isComplete() or self.done[id] then
		return nil
	end
	local phase = self:currentPhase()
	if not phase then
		return nil
	end
	local live = false
	for _, task in phase.tasks do
		if task.id == id then
			live = true
		end
	end
	if not live then
		return nil
	end

	self.done[id] = true
	local doneCount, needed = self:progress()
	if doneCount < needed then
		return { phaseDone = false, nextPhase = nil, complete = false }
	end

	self.phase += 1
	if self.phase > #self.def.phases then
		return { phaseDone = true, nextPhase = nil, complete = true }
	end
	return { phaseDone = true, nextPhase = self.phase, complete = false }
end

function TrialRun.deedDone(self: TrialRun, id: string): boolean
	return self.deedsDone[id] == true
end

return TrialRun
