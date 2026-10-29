--!strict
--[[
	Renown.spec
	The whole player in one number: each part counted, capped, summed, with a band, and the real config
	checked (every part has a ceiling, the bands rise).

	Location: TestService.Tests.Renown.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Renown = require(ServerScriptService.Server.Domain.Renown)
local ProfileCfg: any = require(ReplicatedStorage.Config.Profile)

local cfg = ProfileCfg.Renown

local function inputs(over: any?): any
	local base = { level = 1, might = 1, runsWon = 0, deepest = 0, deeds = 0, pages = 0, shards = 0, starRaised = false, kills = 0 }
	for k, v in over or {} do
		base[k] = v
	end
	return base
end

return function(t: any)
	t.test("a new player has no renown and is Unknown", function()
		local r = Renown.compute(inputs(), cfg)
		assert(r.total == 0 and r.tier == "Unknown", "nothing yet")
		assert(r.nextTier == "Known" and (r.toNext or 0) > 0, "the next band and how far")
	end)

	t.test("a part is Per points for each unit above its offset", function()
		local r = Renown.compute(inputs({ level = 11 }), cfg)
		local rank
		for _, p in r.parts do
			if p.id == "rank" then
				rank = p
			end
		end
		assert(rank and rank.points == 250, "ten levels above the first, at 25 each")
		assert(r.total == 250, "and nothing else")
	end)

	t.test("every part stops at its ceiling", function()
		local r = Renown.compute(
			inputs({ level = 10 ^ 6, might = 99, runsWon = 10 ^ 6, deepest = 99, deeds = 10 ^ 6, pages = 10 ^ 6, shards = 99, starRaised = true, kills = 10 ^ 9 }),
			cfg
		)
		for _, p in r.parts do
			assert(p.points == p.max, p.id .. " is at its ceiling, not past it")
		end
		assert(r.total == r.max, "the total is the sum of the ceilings")
		assert(r.tier == "Legendary" and r.nextTier == nil, "the top band has nothing above it")
	end)

	t.test("the Falling Star adds its bonus on top of the shards, once raised", function()
		local without = Renown.compute(inputs({ shards = 9 }), cfg)
		local with = Renown.compute(inputs({ shards = 9, starRaised = true }), cfg)
		assert(with.total - without.total == 300, "the raised star is worth 300 more")
	end)

	t.test("a band is the first one the total fits under, and the next one is told", function()
		local r = Renown.compute(inputs({ level = 21 }), cfg) -- 500 points
		assert(r.total == 500 and r.tier == "Known", "500 is Known")
		assert(r.nextTier == "Respected" and r.toNext == 1000 - 500 + 1, "and 501 more make it Respected")
	end)

	t.test("the real config: every part has a ceiling, the bands rise, and one thing alone cannot make the top", function()
		local last = 0
		for _, band in cfg.Tiers do
			assert(band.maxPoints > last, "bands rise")
			last = band.maxPoints
		end
		local sum, biggest = 0, 0
		for _, part in cfg.Parts do
			assert(part.Cap > 0 and part.Per > 0, part.id .. " counts something up to a ceiling")
			sum += part.Cap
			biggest = math.max(biggest, part.Cap)
		end
		assert(biggest < sum / 3, "no part is a third of the whole: no one thing makes a name")
		local r = Renown.compute(inputs({ level = 100 }), cfg)
		assert(r.tier ~= "Legendary", "reaching level 100 alone is not Legendary")
	end)
end
