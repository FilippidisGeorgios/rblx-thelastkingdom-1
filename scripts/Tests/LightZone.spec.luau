--!strict
--[[
	LightZone.spec
	Inside and outside a box (also a turned one), and which of two overlapping zones rules.

	Location: TestService.Tests.LightZone.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightZone = require(ReplicatedStorage.Shared.LightZone)
local Config: any = require(ReplicatedStorage.Config.LightZones)

local function zone(id: string, at: Vector3, size: Vector3, priority: number?, yaw: number?): LightZone.Zone
	return { id = id, cframe = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw or 0), 0), size = size, priority = priority or 0 }
end

return function(t: any)
	t.test("a point is inside a box, on its edge, and outside it", function()
		local z = zone("a", Vector3.new(100, 0, 0), Vector3.new(20, 10, 20))
		assert(LightZone.contains(z, Vector3.new(100, 0, 0)), "the middle")
		assert(LightZone.contains(z, Vector3.new(110, 5, 10)), "the corner counts")
		assert(not LightZone.contains(z, Vector3.new(110.5, 0, 0)), "just outside in x")
		assert(not LightZone.contains(z, Vector3.new(100, 5.5, 0)), "just outside in y")
	end)

	t.test("a box turned 45 degrees is measured in its own space", function()
		local z = zone("turned", Vector3.zero, Vector3.new(40, 10, 4), 0, 45)
		-- along the box's long axis, which now runs corner to corner
		assert(LightZone.contains(z, Vector3.new(10, 0, -10)), "on the turned long axis")
		assert(not LightZone.contains(z, Vector3.new(10, 0, 10)), "across it, outside")
	end)

	t.test("the higher priority rules, and between equals the smaller room", function()
		local cave = zone("cave", Vector3.zero, Vector3.new(100, 20, 100), 0)
		local passage = zone("passage", Vector3.zero, Vector3.new(10, 5, 10), 0)
		local vault = zone("vault", Vector3.zero, Vector3.new(200, 40, 200), 5)
		local picked = LightZone.pick({ cave, passage }, Vector3.zero)
		assert(picked and picked.id == "passage", "the passage inside the cave")
		picked = LightZone.pick({ cave, passage, vault }, Vector3.zero)
		assert(picked and picked.id == "vault", "priority beats size")
		assert(LightZone.pick({ cave }, Vector3.new(500, 0, 0)) == nil, "outside everything: nothing")
	end)

	t.test("every zone profile in the config sets only what changes how dark a room is", function()
		local allowed = {
			Ambient = true, OutdoorAmbient = true, Brightness = true, ExposureCompensation = true,
			EnvironmentDiffuseScale = true, EnvironmentSpecularScale = true, AtmosphereDensity = true,
			FadeIn = true, FadeOut = true,
		}
		for name, profile in Config.Profiles do
			for key in profile do
				assert(allowed[key], ("profile %s sets '%s', which a light zone may not touch"):format(name, key))
			end
			assert(profile.FadeIn > 0 and profile.FadeOut > 0, name .. ": fades must take time")
		end
	end)
end
