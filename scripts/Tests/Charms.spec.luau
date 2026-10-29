--!strict
--[[
	Charms.spec
	What the worn charms do, as rules: the veil's one breath, the stirrup's claim on the walking
	speed (taken, kept, given back, and never put over somebody else's), and that the real config
	names mods the run-mod service knows.

	Location: TestService.Tests.Charms.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charms = require(ServerScriptService.Server.Domain.Charms)
local cfg: any = require(ReplicatedStorage.Config.Chapel)
local Items: any = require(ReplicatedStorage.Config.Items)

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: any)
	t.test("the veil leaves one breath when the blow would kill", function()
		local amount, used = Charms.lastBreath(30, 45, true, false)
		assert(used, "a killing blow uses the veil")
		assert(near(amount, 29), "one breath is left, not none")
		local exact, usedExact = Charms.lastBreath(30, 30, true, false)
		assert(usedExact and near(exact, 29), "a blow that exactly kills counts")
	end)

	t.test("the veil lets an ordinary blow through and stays unspent", function()
		local amount, used = Charms.lastBreath(30, 12, true, false)
		assert(not used and near(amount, 12), "a blow that does not kill is not the veil's")
	end)

	t.test("the veil is not there when it is not worn or already spent", function()
		local a, usedA = Charms.lastBreath(30, 45, false, false)
		assert(not usedA and near(a, 45), "not worn: the blow falls whole")
		local b, usedB = Charms.lastBreath(30, 45, true, true)
		assert(not usedB and near(b, 45), "spent: the blow falls whole")
	end)

	t.test("with one breath left a blow is swallowed whole, never made negative", function()
		local amount, used = Charms.lastBreath(1, 20, true, false)
		assert(used and near(amount, 0), "at 1 health the veil takes the entire blow")
	end)

	t.test("calm means no blow for the given seconds", function()
		assert(Charms.isCalm(100, nil, 5), "no fight at all is calm")
		assert(not Charms.isCalm(100, 97, 5), "three seconds ago is not calm")
		assert(Charms.isCalm(100, 95, 5), "five seconds ago is")
	end)

	t.test("the stirrup takes the claim when calm and writes the faster speed", function()
		local claim: Charms.Claim = {}
		local want = Charms.calmSpeed(claim, 16, true, 1.08)
		assert(want ~= nil and near(want, 17.28), "16 x 1.08")
		assert(claim.base == 16 and claim.set ~= nil, "the claim remembers the base")
	end)

	t.test("while calm and unchanged the stirrup writes nothing; when the fight starts it gives the base back", function()
		local claim: Charms.Claim = {}
		local fast = Charms.calmSpeed(claim, 16, true, 1.08) :: number
		assert(Charms.calmSpeed(claim, fast, true, 1.08) == nil, "nothing to do while calm")
		local back = Charms.calmSpeed(claim, fast, false, 1.08)
		assert(back == 16, "the base goes back")
		assert(claim.base == nil and claim.set == nil, "and the claim is gone")
		assert(Charms.calmSpeed(claim, 16, false, 1.08) == nil, "in a fight, with no claim: nothing")
	end)

	t.test("a speed set by somebody else is theirs: the claim is dropped and nothing is written", function()
		local claim: Charms.Claim = {}
		local fast = Charms.calmSpeed(claim, 16, true, 1.08) :: number
		-- the King's frost writes a slow
		assert(Charms.calmSpeed(claim, 8, true, 1.08) == nil, "never write over a speed that is not ours")
		assert(claim.set == nil, "the claim is dropped")
		assert(fast > 16, "(sanity)")
		-- and in a fight, too: the base must not be put back over their value
		local claim2: Charms.Claim = {}
		Charms.calmSpeed(claim2, 16, true, 1.08)
		assert(Charms.calmSpeed(claim2, 8, false, 1.08) == nil, "their slow is not undone by the giving back")
	end)

	t.test("a body with no speed (downed, anchored) is not claimed", function()
		local claim: Charms.Claim = {}
		assert(Charms.calmSpeed(claim, 0, true, 1.08) == nil, "a speed of 0 stays 0")
		assert(claim.set == nil, "no claim")
	end)

	t.test("a multiplier of 1 does nothing", function()
		local claim: Charms.Claim = {}
		assert(Charms.calmSpeed(claim, 16, true, 1) == nil, "no charm, no change")
	end)

	t.test("the real config: every charm has a mod, a kit, or says it is pending; the mods are ones the run knows", function()
		local known = { damage = true, reach = true, cooldown = true, pierce = true, calmSpeed = true, notice = true, lastBreath = true }
		for id, def in cfg.Charms do
			assert(Items[id], id .. " is an item")
			assert(def.Kit or def.Mods or def.Pending, id .. " does something or says it does not yet")
			assert(not (def.Pending and def.Mods), id .. " cannot be pending and have an effect")
			for mod in def.Mods or {} do
				assert(known[mod], id .. " names a mod nobody reads: " .. mod)
			end
		end
		assert(cfg.Charms.brass_stirrup.Calm and cfg.Charms.brass_stirrup.Calm > 0, "the stirrup says how long calm is")
		assert(cfg.Charms.hollow_lantern.Mods.notice < 1, "the lantern makes you harder to notice")
	end)
end
