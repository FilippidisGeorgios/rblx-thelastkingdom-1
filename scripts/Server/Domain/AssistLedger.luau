--!strict
--[[
	AssistLedger (domain)
	Who has struck each enemy, and when, so that when an enemy dies the players who HELPED (struck it lately but did
	not land the killing blow) can be credited with an assist. Pure: keys are anything (players, in the game), time is
	passed in, so the rules are unit-tested (AssistLedger.spec).

	  blow(enemy, who, now)        `who` struck `enemy` at `now`
	  killed(enemy, killer, now)   the helpers: everyone but the killer whose last blow was within `window` seconds;
	                               the enemy is forgotten
	  forget(now)                  lets go of enemies not struck for `forgetAfter` seconds (they left, or were never killed)

	A ledger that grows past `maxTracked` enemies forgets the old ones by itself, so a long run in which many enemies are struck
	and never die cannot make it grow without end.

	Location: ServerScriptService.Server.Domain.AssistLedger
]]

local AssistLedger = {}
AssistLedger.__index = AssistLedger

export type AssistLedger = typeof(setmetatable(
	{} :: {
		window: number,
		forgetAfter: number,
		maxTracked: number,
		struck: { [any]: { [any]: number } },
		count: number,
	},
	AssistLedger
))

function AssistLedger.new(window: number, forgetAfter: number, maxTracked: number?): AssistLedger
	return setmetatable({ window = window, forgetAfter = forgetAfter, maxTracked = maxTracked or 400, struck = {}, count = 0 }, AssistLedger)
end

function AssistLedger.forget(self: AssistLedger, now: number)
	for enemy, by in self.struck do
		local newest = -math.huge
		for _, t in by do
			newest = math.max(newest, t)
		end
		if now - newest > self.forgetAfter then
			self.struck[enemy] = nil
			self.count -= 1
		end
	end
end

function AssistLedger.blow(self: AssistLedger, enemy: any, who: any, now: number)
	local by = self.struck[enemy]
	if not by then
		by = {}
		self.struck[enemy] = by
		self.count += 1
		by[who] = now -- recorded before the cleaning below, or the enemy being added would look stale and go
		if self.count > self.maxTracked then
			AssistLedger.forget(self, now)
		end
		return
	end
	by[who] = now
end

function AssistLedger.killed(self: AssistLedger, enemy: any, killer: any, now: number): { any }
	local by = self.struck[enemy]
	if not by then
		return {}
	end
	self.struck[enemy] = nil
	self.count -= 1
	local helpers: { any } = {}
	for who, at in by do
		if who ~= killer and now - at <= self.window then
			table.insert(helpers, who)
		end
	end
	return helpers
end

function AssistLedger.clear(self: AssistLedger)
	self.struck = {}
	self.count = 0
end

return AssistLedger
