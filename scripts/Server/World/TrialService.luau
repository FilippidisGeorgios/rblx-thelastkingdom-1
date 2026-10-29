--!strict
--[[
	TrialService
	Runs the data-driven trials (configs/Trials, docs/systems/Trials.md): the
	thing each chamber asks of the party. It owns the shape — start on entry,
	phases in order, pressure laid over them, the top line, the gate — and none
	of the verbs: every verb is a module under Trial/, handed a small context.

	--------------------------------------------------------------------------
	HOW A TRIAL RUNS

	  walk in  ->  a few seconds' grace  ->  phase 1's tasks start, the pressure
	  that starts "from start" starts, the deeds are offered  ->  tasks report
	  done  ->  when a phase is done the next begins  ->  when the last is done
	  the pressure stops, the line clears and the gate rises (AreaService.clear).

	The state machine is the pure `Domain/TrialRun`; this is the glue.

	--------------------------------------------------------------------------
	WHAT A TASK MODULE IS

	`Trial/<Kind>.create(ctx, def)` returns { start, stop, progress }.
	ctx = {
	  area      the chamber index
	  folder    a Folder to build props and prompts in (removed with the trial)
	  done()    this task is finished
	  progress(cur, total)  the count changed (the top line is rebuilt)
	  note(text, seconds)   a short message over the top line, then it falls back
	  warn(text)            something in the scenery was missing
	}
	A PRESSURE module has the same shape (`start`/`stop`) and a ctx without `done`.

	Chambers 1 and 2 predate this and run their own services; they still call
	AreaService.clear. They are not listed in configs/Trials.

	Place: Forgotten Lands ONLY (Server/World). Phase: Areas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local TrialRun = require(Server.Domain.TrialRun)
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local TrialService = {}

TrialService.Name = "TrialService"

-- Called (area, deedId) the first time a deed is done: the run's statistics and the profiles listen.
local deedHandlers: { (number, string) -> () } = {}

local log = Logger.new("TrialService")

-- A breath between walking in and the room starting to ask things of you.
local GRACE_SECONDS = 4

local TASKS: { [string]: any } = {
	light = require(script.Parent.Trial.Light),
	toll = require(script.Parent.Trial.Toll),
	read = require(script.Parent.Trial.Read),
	gather = require(script.Parent.Trial.Gather),
	cook = require(script.Parent.Trial.Cook),
	feed = require(script.Parent.Trial.Feed),
	forge = require(script.Parent.Trial.Forge),
	burn = require(script.Parent.Trial.Burn),
	chop = require(script.Parent.Trial.Chop),
	mine = require(script.Parent.Trial.Mine),
	board = require(script.Parent.Trial.Board),
	siege = require(script.Parent.Trial.Siege),
	rescue = require(script.Parent.Trial.Rescue),
	letters = require(script.Parent.Trial.Letters),
	dig = require(script.Parent.Trial.Dig),
	mangonel = require(script.Parent.Trial.Mangonel),
	king = require(script.Parent.Trial.King),
	unseal = require(script.Parent.Trial.Unseal),
	scribe = require(script.Parent.Trial.Scribe),
	exit = require(script.Parent.Trial.Exit),
}

local PRESSURE: { [string]: any } = {
	rising = require(script.Parent.Trial.Rising),
	tide = require(script.Parent.Trial.Tide),
	surge = require(script.Parent.Trial.Surge),
}

type Handle = { start: () -> (), stop: () -> (), progress: (() -> (number, number))? }

type Live = {
	area: number,
	def: any,
	run: TrialRun.TrialRun,
	folder: Folder,
	tasks: { [string]: Handle },
	taskProgress: { [string]: { number } },
	pressure: { [string]: Handle },
	pressureStarted: { [string]: boolean },
	noteToken: number,
	finished: boolean,
	shared: { [string]: any }, -- a bag the trial's tasks share (the rolled recipe)
	hintOverride: string?, -- a task's own line, shown instead of the phase's
}

local live: { [number]: Live } = {}
local hintEvent: RemoteEvent? = nil

--==========================================================================
-- The top line
--==========================================================================
local function say(source: string, text: string?)
	if hintEvent then
		hintEvent:FireAllClients({ source = source, text = text })
	end
end

local function refreshHint(trial: Live)
	if trial.finished then
		say("trial", nil)
		return
	end
	if trial.hintOverride then
		say("trial", trial.hintOverride)
		return
	end
	local phase = trial.run:currentPhase()
	if not phase or not phase.hint then
		say("trial", nil)
		return
	end
	local text = phase.hint
	if text:find("%%d") then
		local cur, total = 0, 0
		for _, ref in phase.tasks do
			local p = trial.taskProgress[ref.id]
			if p then
				cur += p[1]
				total += p[2]
			end
		end
		text = text:format(cur, total)
	end
	say("trial", text)
end

--==========================================================================
-- Tasks and pressure
--==========================================================================
local startTask: (Live, string) -> ()

local function taskDef(trial: Live, id: string): any?
	for _, phase in trial.def.phases do
		for _, t in phase.tasks do
			if t.id == id then
				return t
			end
		end
	end
	for _, t in trial.def.deeds or {} do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- A short line over the top line, then it falls back to the phase's own.
local function noteFor(trial: Live, text: string, seconds: number?)
	trial.noteToken += 1
	local token = trial.noteToken
	say("trialnote", text)
	task.delay(seconds or 3, function()
		if trial.noteToken == token then
			say("trialnote", nil)
		end
	end)
end

local function startPressureFor(trial: Live, from: string)
	for _, p in trial.def.pressure or {} do
		if (p.from or "start") == from and not trial.pressureStarted[p.id] then
			trial.pressureStarted[p.id] = true
			local module = PRESSURE[p.kind]
			if not module then
				log:warn(("area %d: unknown pressure kind '%s'"):format(trial.area, tostring(p.kind)))
			else
				local handle = module.create({
					area = trial.area,
					folder = trial.folder,
					note = function(text: string, seconds: number?)
						noteFor(trial, text, seconds)
					end,
					warn = function(text: string)
						log:warn(("area %d %s: %s"):format(trial.area, p.id, text))
					end,
				}, p)
				trial.pressure[p.id] = handle
				handle.start()
			end
		end
	end
end

local function finish(trial: Live)
	if trial.finished then
		return
	end
	trial.finished = true
	for _, handle in trial.pressure do
		handle.stop()
	end
	for id, handle in trial.tasks do
		-- Deeds stay on offer: the gate does not wait for them and they do not wait for the gate.
		local def = taskDef(trial, id)
		local isDeed = false
		for _, d in trial.def.deeds or {} do
			if d.id == id then
				isDeed = true
			end
		end
		if def and not isDeed then
			handle.stop()
		end
	end
	say("trial", nil)
	log:info(("area %d trial complete — gate rising"):format(trial.area))
	AreaService.clear(trial.area)
end

local function onTaskDone(trial: Live, id: string)
	local handle = trial.tasks[id]
	local phaseBefore = trial.run:currentPhase()
	local deedBefore = trial.run:deedDone(id)
	local change = trial.run:taskDone(id)
	if not deedBefore and trial.run:deedDone(id) then
		for _, handler in deedHandlers do
			task.spawn(handler, trial.area, id)
		end
	end
	if handle and change then
		handle.stop()
	end
	if not change then
		return
	end
	if change.phaseDone and phaseBefore then
		trial.hintOverride = nil
		for _, p in trial.def.pressure or {} do
			if p.untilPhase == phaseBefore.id and trial.pressure[p.id] then
				trial.pressure[p.id].stop()
			end
		end
	end
	if change.complete then
		finish(trial)
	elseif change.phaseDone and change.nextPhase then
		local phase = trial.run:currentPhase()
		if phase then
			for _, ref in phase.tasks do
				startTask(trial, ref.id)
			end
			startPressureFor(trial, phase.id)
		end
		refreshHint(trial)
	else
		refreshHint(trial)
	end
end

startTask = function(trial: Live, id: string)
	local def = taskDef(trial, id)
	if not def then
		return
	end
	local module = TASKS[def.kind]
	if not module then
		log:warn(("area %d: unknown task kind '%s'"):format(trial.area, tostring(def.kind)))
		return
	end
	local handle = module.create({
		area = trial.area,
		folder = trial.folder,
		shared = trial.shared,
		trial = trial.def,
		hint = function(text: string?)
			trial.hintOverride = text
			refreshHint(trial)
		end,
		signal = function(name: string)
			startPressureFor(trial, "signal:" .. name)
		end,
		done = function()
			onTaskDone(trial, id)
		end,
		progress = function(cur: number, total: number)
			trial.taskProgress[id] = { cur, total }
			refreshHint(trial)
		end,
		note = function(text: string, seconds: number?)
			noteFor(trial, text, seconds)
		end,
		warn = function(text: string)
			log:warn(("area %d %s: %s"):format(trial.area, id, text))
		end,
	}, def)
	trial.tasks[id] = handle
	handle.start()
end

--==========================================================================
-- Lifecycle
--==========================================================================
local function trialsFolder(): Folder
	local existing = Workspace:FindFirstChild("Trials")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Trials"
	created.Parent = Workspace
	return created
end

local function begin(area: number)
	if live[area] then
		return
	end
	local def = Config.get("Trials")[area]
	if not def then
		return
	end

	local refs = { phases = {}, deeds = {} }
	for _, phase in def.phases do
		local tasks = {}
		for _, t in phase.tasks do
			table.insert(tasks, { id = t.id })
		end
		table.insert(refs.phases, { id = phase.id, hint = phase.hint, mode = phase.mode, count = phase.count, tasks = tasks })
	end
	for _, d in def.deeds or {} do
		table.insert(refs.deeds, { id = d.id })
	end

	local folder = Instance.new("Folder")
	folder.Name = ("Area%d"):format(area)
	folder.Parent = trialsFolder()

	local trial: Live = {
		area = area,
		def = def,
		run = TrialRun.new(refs),
		folder = folder,
		tasks = {},
		taskProgress = {},
		pressure = {},
		pressureStarted = {},
		noteToken = 0,
		finished = false,
		shared = {},
		hintOverride = nil,
	}
	live[area] = trial

	log:info(("area %d entered — trial starts in %ds"):format(area, GRACE_SECONDS))
	task.delay(GRACE_SECONDS, function()
		if trial.finished then
			return
		end
		for _, id in trial.run:start() do
			startTask(trial, id)
		end
		for _, d in def.deeds or {} do
			startTask(trial, d.id)
		end
		startPressureFor(trial, "start")
		local first = trial.run:currentPhase()
		if first then
			startPressureFor(trial, first.id)
		end
		refreshHint(trial)
	end)
end

--==========================================================================
-- API
--==========================================================================

-- Subscribes to deeds: `handler(area, id)` runs once for each deed, the first time it is done.
function TrialService.onDeed(handler: (number, string) -> ())
	table.insert(deedHandlers, handler)
end

function TrialService.isRunning(area: number): boolean
	local trial = live[area]
	return trial ~= nil and not trial.finished
end

-- Development shortcut: finish area `area`'s trial now, as if every task were done.
function TrialService.forceComplete(area: number)
	local trial = live[area]
	if trial then
		finish(trial)
	else
		AreaService.clear(area)
	end
end

-- Development: report task `id` of area `area` done, as if its work had been finished.
function TrialService.devDone(area: number, id: string)
	local trial = live[area]
	if trial then
		onTaskDone(trial, id)
	end
end

function TrialService.openSections(area: number): number?
	local trial = live[area]
	local handle = trial and trial.pressure.graves
	if handle and (handle :: any).openSections then
		return (handle :: any).openSections()
	end
	return nil
end

--==========================================================================
function TrialService.Init() end

function TrialService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	hintEvent = Net.getEvent("ObjectiveHint")

	local count = 0
	for area in Config.get("Trials") do
		local index = area :: number
		AreaService.onEnter(index, function()
			begin(index)
		end)
		count += 1
	end
	log:info(("armed — %d trial(s)"):format(count))
end

return TrialService
