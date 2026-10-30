--!strict
--[[
	Danger.spec
	The third curve: the mode's points, the veterans' points from the party's average level, the shield that
	keeps rookies from being buried by their friends' levels, and what the figure does to the enemies.

	Location: TestService.Tests.Danger.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Danger = require(ReplicatedStorage.Shared.Danger)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Difficulty: any = require(ReplicatedStorage.Config.Difficulty)

local rules: Danger.Rules = Difficulty.Danger
local tiers = Difficulty.Tiers

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 0.06)
end

local function many(level: number, n: number): { number }
	local out = {}
	for _ = 1, n do
		table.insert(out, level)
	end
	return out
end

local function join(...: { number }): { number }
	local out = {}
	for _, list in { ... } do
		for _, v in list do
			table.insert(out, v)
		end
	end
	return out
end

return function(t: any)
	t.test("a lone level-1 player on Normal adds nothing", function()
		local d = Danger.compute({ 1 }, "Normal", rules)
		assert(d.total == 0 and d.mode == 0 and d.veteran == 0, "nothing: " .. d.total)
	end)

	t.test("the veterans' points are the average level, from level 1 to the top", function()
		assert(near(Danger.compute({ 100, 100 }, "Normal", rules).total, 100), "a pair at the top is +100")
		local half = Danger.compute({ 50, 51 }, "Normal", rules)
		assert(near(half.veteran, 49.5, 1), "a pair around 50 is about +50: " .. half.veteran)
		assert(Danger.compute({ 30 }, "Normal", rules).veteran < Danger.compute({ 60 }, "Normal", rules).veteran, "higher is harder")
	end)

	t.test("Hard adds its points, and the total never passes the maximum", function()
		local hard = Danger.compute({ 1, 1 }, "Hard", rules)
		assert(hard.mode == rules.Mode.Hard and hard.total == rules.Mode.Hard, "Hard alone is its points")
		local top = Danger.compute({ 100, 100 }, "Hard", rules)
		assert(top.total == rules.Max, "capped at " .. rules.Max .. ": " .. top.total)
	end)

	t.test("fewer than three players are never shielded: two level-0 among veterans take the average", function()
		local two = Danger.compute({ 1, 100 }, "Normal", rules)
		assert(two.keep == 1 and not two.shielded, "a pair has no shield")
		assert(near(two.veteran, 50, 1), "the average counts in full: " .. two.veteran)
		-- three players but only two rookies: the third weakest is a veteran, so it is free
		local twoRookies = Danger.compute(join(many(1, 2), many(100, 3)), "Normal", rules)
		assert(twoRookies.keep == 1, "two rookies in five are not enough to shield")
	end)

	t.test("three rookies shield the party down to the floor, whoever else is aboard", function()
		local d = Danger.compute(join(many(1, 3), many(100, 2)), "Normal", rules)
		assert(near(d.keep, rules.Shield.Keep, 0.011), "keep is the floor: " .. d.keep)
		assert(d.shielded, "and it says so")
		-- the average is 41, so unshielded it would be about 40 points
		assert(d.veteran < 8 and d.veteran > 5, "only a sliver counts: " .. d.veteran)
	end)

	t.test("four level-0 and four level-100 players: Hard, and only a small share of the average", function()
		local d = Danger.compute(join(many(1, 4), many(100, 4)), "Hard", rules)
		assert(near(d.avgLevel, 50.5, 0.1), "average about 50")
		assert(near(d.veteran, 7.5, 0.6), "about 15% of 50: " .. d.veteran)
		assert(near(d.total, rules.Mode.Hard + d.veteran, 0.11), "plus Hard's points")
	end)

	t.test("the shield fades as the third weakest climbs, and is gone at the free level", function()
		local mid = Danger.keep(join(many(12, 3), many(100, 2)), rules.Shield)
		assert(mid > 0.4 and mid < 0.6, "a third player around level 12 keeps about half: " .. mid)
		local atFree = Danger.keep(join(many(rules.Shield.FreeFrom, 3), many(100, 2)), rules.Shield)
		assert(atFree == 1, "free from level " .. rules.Shield.FreeFrom)
		local below = Danger.keep(join(many(5, 3), many(100, 2)), rules.Shield)
		assert(near(below, rules.Shield.Keep, 0.011), "at level 5 the floor")
		-- monotone: a stronger third player never makes the shield stronger
		local last = 0
		for level = 1, 25 do
			local k = Danger.keep(join(many(level, 3), many(100, 2)), rules.Shield)
			assert(k >= last - 1e-9, "never falls as the third player levels: " .. level)
			last = k
		end
	end)

	t.test("everyone over the free level takes the average, whatever it is", function()
		local d = Danger.compute({ 20, 25, 40, 60, 90 }, "Normal", rules)
		assert(d.keep == 1 and not d.shielded, "no shield")
		assert(near(d.veteran, 100 * (d.avgLevel - 1) / 99, 0.2), "the full average")
	end)

	t.test("a big party cannot play Normal; a small one may choose Hard", function()
		local mode, locked = Danger.modeFor(4, false, tiers)
		assert(mode == "Normal" and not locked, "four on Normal")
		mode, locked = Danger.modeFor(5, false, tiers)
		assert(mode == "Hard" and locked, "five are Hard, and Normal is shut")
		mode, locked = Danger.modeFor(8, false, tiers)
		assert(mode == "Hard" and locked, "eight too")
		mode, locked = Danger.modeFor(2, true, tiers)
		assert(mode == "Hard" and not locked, "two may choose Hard")
		mode, locked = Danger.modeFor(1, true, tiers)
		assert(mode == "Hard" and not locked, "even alone")
	end)

	t.test("the enemies get a share of the full amount: none at 0, all at the maximum", function()
		local none = Danger.multipliers(0, rules)
		assert(none.enemyHealthMult == 1 and none.enemyCountMult == 1 and none.eliteWeight == 0 and none.rewardMult == 1, "0 changes nothing")
		local full = Danger.multipliers(rules.Max, rules)
		assert(near(full.enemyHealthMult, 1 + rules.AtFull.EnemyHealth, 1e-6), "health at full")
		assert(near(full.enemyCountMult, 1 + rules.AtFull.EnemyCount, 1e-6), "count at full")
		assert(near(full.rewardMult, 1 + rules.AtFull.Reward, 1e-6), "and the pay")
		local half = Danger.multipliers(rules.Max / 2, rules)
		assert(near(half.enemyHealthMult, 1 + rules.AtFull.EnemyHealth / 2, 1e-6), "half is half")
		assert(Danger.multipliers(1000, rules).enemyHealthMult == full.enemyHealthMult, "past the maximum is the maximum")
	end)

	t.test("the run's Danger reaches every party-size answer, and clears", function()
		Scaling.setRunDanger(0)
		local base = Scaling.forPlayers(2)
		Scaling.setRunDanger(50)
		local hard = Scaling.forPlayers(2)
		Scaling.setRunDanger(0)
		local after = Scaling.forPlayers(2)
		assert(hard.enemyHealthMult > base.enemyHealthMult and hard.enemyCountMult > base.enemyCountMult, "harder")
		assert(hard.rewardMult > base.rewardMult, "and better paid")
		assert(after.enemyHealthMult == base.enemyHealthMult and Scaling.getRunDanger() == 0, "cleared")
		assert(near(hard.enemyHealthMult / base.enemyHealthMult, 1 + rules.AtFull.EnemyHealth * 0.5, 1e-6), "by the config's share")
	end)

	t.test("the config is sane: Hard is a step, the shield fades up, nothing is negative", function()
		assert(rules.Mode.Normal == 0 and rules.Mode.Hard > 0, "Normal is the baseline")
		assert(rules.Shield.Keep > 0 and rules.Shield.Keep < 1, "the floor is a share")
		assert(rules.Shield.RookieBelow < rules.Shield.FreeFrom, "the shield fades UP")
		assert(rules.Shield.Need >= 2, "a shield needs a group")
		for _, v in rules.AtFull do
			assert(v >= 0, "no negative scaling")
		end
	end)
end
