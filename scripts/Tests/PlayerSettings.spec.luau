--!strict
--[[
	PlayerSettings.spec
	The Settings panel's contract: only a real quality and a real boolean are ever stored; a quality carries its
	own shadows start; the defaults depend on the device; and the four qualities never change what can be seen.

	Location: TestService.Tests.PlayerSettings.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Graphics: any = require(ReplicatedStorage.Config.Graphics)

return function(t: any)
	t.test("a quality that exists is stored; anything else is ignored", function()
		local s, changed = PlayerSettings.apply({}, { graphics = "Ultra" }, Graphics)
		assert(changed and s.graphics == "Ultra", "Ultra")
		local bad, c2 = PlayerSettings.apply({ graphics = "High" }, { graphics = "Cinematic" }, Graphics)
		assert(not c2 and bad.graphics == "High", "unknown quality ignored")
		local junk, c3 = PlayerSettings.apply({ graphics = "High" }, { graphics = 3, shadows = "yes" }, Graphics)
		assert(not c3 and junk.graphics == "High" and junk.shadows == nil, "wrong types ignored")
		local notTable, c4 = PlayerSettings.apply({ graphics = "Low" }, "hello", Graphics)
		assert(not c4 and notTable.graphics == "Low", "not even a table")
	end)

	t.test("choosing a quality moves the shadows to that quality's start, unless the request says otherwise", function()
		local low = PlayerSettings.apply({ graphics = "High", shadows = true }, { graphics = "Low" }, Graphics)
		assert(low.graphics == "Low" and low.shadows == false, "Low starts with shadows off")
		local high = PlayerSettings.apply(low, { graphics = "High" }, Graphics)
		assert(high.shadows == true, "High starts with them on")
		local both = PlayerSettings.apply({}, { graphics = "Low", shadows = true }, Graphics)
		assert(both.graphics == "Low" and both.shadows == true, "named shadows win")
	end)

	t.test("the shadows switch alone changes only the shadows", function()
		local s, changed = PlayerSettings.apply({ graphics = "Ultra", shadows = true }, { shadows = false }, Graphics)
		assert(changed and s.graphics == "Ultra" and s.shadows == false, "just the switch")
		local same, c2 = PlayerSettings.apply(s, { shadows = false }, Graphics)
		assert(not c2 and same.shadows == false, "asking for what is already so changes nothing")
	end)

	t.test("a stored table is cleaned of everything invalid", function()
		local cleaned = PlayerSettings.clean({ graphics = "Medium", shadows = false, hax = 1, extra = {} }, Graphics)
		assert(cleaned.graphics == "Medium" and cleaned.shadows == false, "the good keys")
		assert((cleaned :: any).hax == nil and (cleaned :: any).extra == nil, "and no others")
		local none = PlayerSettings.clean({ graphics = "Nope", shadows = 7 }, Graphics)
		assert(none.graphics == nil and none.shadows == nil, "bad values dropped")
		assert(next(PlayerSettings.clean(nil, Graphics)) == nil, "nothing at all is empty")
	end)

	t.test("the picture follows the device when nothing was chosen, and the choice when it was", function()
		local q, shadows = PlayerSettings.effective({}, Graphics, false)
		assert(q == Graphics.Default and shadows == Graphics.Tiers[Graphics.Default].Shadows, "a computer")
		local pq = PlayerSettings.effective({}, Graphics, true)
		assert(pq == Graphics.PhoneDefault, "a phone starts lighter")
		local chosen, sh = PlayerSettings.effective({ graphics = "Ultra", shadows = false }, Graphics, true)
		assert(chosen == "Ultra" and sh == false, "a choice beats the device")
		local broken = PlayerSettings.effective({ graphics = "Gone" }, Graphics, false)
		assert(broken == Graphics.Default, "a quality that no longer exists falls back")
	end)

	t.test("the four qualities exist, in order, from cheapest to richest", function()
		assert(#Graphics.Order == 4 and Graphics.Order[1] == "Low" and Graphics.Order[4] == "Ultra", "Low, Medium, High, Ultra")
		assert(Graphics.Tiers[Graphics.Default] ~= nil and Graphics.Tiers[Graphics.PhoneDefault] ~= nil, "the defaults exist")
		local lastParticles, lastLod, lastQuality = 0, 0, 0
		for _, id in Graphics.Order do
			local tier = Graphics.Tiers[id]
			assert(tier.ParticleScale >= lastParticles and tier.LodScale >= lastLod and tier.QualityLevel >= lastQuality, id .. " is not poorer than the one below")
			assert(tier.ParticleScale > 0, id .. " keeps some particles: the cues stay")
			lastParticles, lastLod, lastQuality = tier.ParticleScale, tier.LodScale, tier.QualityLevel
		end
	end)

	t.test("no quality is allowed to change what can be seen: only the cost is in the table", function()
		local allowed = {
			Label = true, Blurb = true, Shadows = true, ParticleScale = true, LodScale = true, Bloom = true, SunRays = true,
			DepthOfField = true, Decoration = true, LightShadows = true, SoftShadows = true, QualityLevel = true,
		}
		for id, tier in Graphics.Tiers do
			for key in tier do
				assert(allowed[key], id .. " carries '" .. key .. "', which the fairness rule does not allow")
			end
		end
	end)
end
