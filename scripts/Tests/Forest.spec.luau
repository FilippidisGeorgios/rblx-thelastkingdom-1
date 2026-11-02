--!strict
--[[
	Forest.spec
	The Huntsman of the King's Wood sees light and nothing else (far when it is open, near when it is covered, never inside a
	fire's glow or behind a trunk), blows his horn once when he first sees it, hunts it, loses it, searches and goes back to his
	round; strikes what is in reach; and goes away when he is driven off. The wood's numbers hold together.

	Location: TestService.Tests.Forest.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HuntsmanBrain = require(ServerScriptService.Server.Domain.HuntsmanBrain)
local Cfg: any = require(ReplicatedStorage.Config.Forest)

local H = Cfg.Huntsman
local EYE = Vector3.new(0, 8, 0)
local LOOK = Vector3.new(0, 0, -1) -- he looks toward -z

local function light(x: number, z: number, opts: { [string]: any }?): HuntsmanBrain.Light
	local o = opts or {}
	return {
		at = Vector3.new(x, 4, z),
		lantern = if o.lantern == nil then true else o.lantern,
		open = if o.open == nil then true else o.open,
		crouched = o.crouched == true,
		clear = if o.clear == nil then true else o.clear,
		inGlow = o.inGlow == true,
	}
end

local function inBox(p: Vector3, box: any): boolean
	return p.X >= math.min(box.X0, box.X1) and p.X <= math.max(box.X0, box.X1) and p.Z <= math.max(box.Z0, box.Z1) and p.Z >= math.min(box.Z0, box.Z1)
end

-- runs the brain for `seconds` in steps of 0.1 with the same inputs; returns every action
local function run(brain: any, from: number, seconds: number, here: Vector3, sightings: { any }, bodies: { any }): { any }
	local out = {}
	local now = from
	for _ = 1, math.round(seconds / 0.1) do
		now += 0.1
		table.insert(out, brain:update(0.1, now, here, sightings, bodies))
	end
	return out
end

return function(t: any)
	t.test("an open lantern is seen far, a covered one only near, and a crouched covered one nearer still", function()
		assert(HuntsmanBrain.sees(H, EYE, LOOK, light(0, -60)), "open at 60, in front")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -H.See.Open - 3)), "open, past his sight")
		assert(HuntsmanBrain.sees(H, EYE, LOOK, light(0, -7, { open = false })), "covered at 7")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -12, { open = false })), "covered at 12 is not seen")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -7.5, { open = false, crouched = true })), "crouched and covered at 7.5 is not seen")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -20, { lantern = false })), "no lantern at 20: a shape in the dark")
	end)

	t.test("behind him only what is close; behind a trunk nothing; in a fire's glow nothing; at his elbow always", function()
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, 30)), "an open lantern 30 behind him")
		assert(HuntsmanBrain.sees(H, EYE, LOOK, light(0, 6)), "an open lantern 6 behind him")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -20, { clear = false })), "behind a trunk")
		assert(not HuntsmanBrain.sees(H, EYE, LOOK, light(0, -20, { inGlow = true })), "inside a fire's glow")
		assert(HuntsmanBrain.sees(H, EYE, LOOK, light(1, -1.5, { clear = false, open = false })), "at his elbow")
	end)

	t.test("he walks his round, stands at each stop, and goes on to another", function()
		local stops = { Vector3.new(0, 2, 0), Vector3.new(100, 2, 0) }
		local brain = HuntsmanBrain.new(H, stops, function()
			return 0.5
		end)
		local a = brain:update(0.1, 1, Vector3.new(50, 2, 0), {}, {})
		assert(a.state == "Round" and a.goal ~= nil and a.speed == H.Speeds.Round, "walking his round")
		local at = a.goal :: Vector3
		a = brain:update(0.1, 1.1, at, {}, {})
		assert(a.state == "Pause", "stands at the stop")
		local actions = run(brain, 1.1, H.RoundPause + 0.3, at, {}, {})
		local last = actions[#actions]
		assert(last.state == "Round" and last.goal ~= nil and last.goal ~= at, "and goes on to another stop")
	end)

	t.test("a light: he stops and blows his horn once, then hunts it", function()
		local brain = HuntsmanBrain.new(H, { Vector3.new(0, 2, 0) })
		local here = Vector3.new(0, 2, 40)
		local seen = { { id = "p1", at = Vector3.new(0, 4, -10) } }
		local a = brain:update(0.1, 10, here, seen, {})
		assert(a.state == "Alert" and a.horn == true, "the horn")
		local actions = run(brain, 10, H.AlertSeconds + 0.2, here, seen, {})
		for _, x in actions do
			assert(not x.horn, "only one horn")
		end
		local last = actions[#actions]
		assert(last.state == "Hunt" and last.goal == seen[1].at and last.speed == H.Speeds.Hunt, "hunting the light")
		assert(H.Speeds.Hunt < 16, "a walking player is faster than his hunt")
	end)

	t.test("a light that goes out: he goes to where it was, searches, and goes back to his round", function()
		local brain = HuntsmanBrain.new(H, { Vector3.new(0, 2, 200) })
		local here = Vector3.new(0, 2, 40)
		local spot = Vector3.new(0, 4, -10)
		run(brain, 0, H.AlertSeconds + 0.5, here, { { id = "p1", at = spot } }, {})
		local actions = run(brain, H.AlertSeconds + 0.5, H.See.LoseAfter + 0.3, here, {}, {})
		local last = actions[#actions]
		assert(last.state == "Seek" and last.goal == spot, "to where it was last seen: " .. tostring(last.state))
		local a = brain:update(0.1, 50, Vector3.new(spot.X, 2, spot.Z), {}, {})
		assert(a.state == "Search", "looks about there")
		actions = run(brain, 50, H.SearchSeconds + 0.3, Vector3.new(spot.X, 2, spot.Z), {}, {})
		assert(actions[#actions].state == "Round", "and goes back to his round")
	end)

	t.test("in reach he swings: a windup that can be stepped out of, then the blow on its one update", function()
		local brain = HuntsmanBrain.new(H, { Vector3.new(0, 2, 0) })
		local a = brain:update(0.1, 1, Vector3.zero, {}, { { id = "p1", distance = H.AttackRange - 1 } })
		assert(a.state == "Windup", "winds up")
		local struck = 0
		for _, x in run(brain, 1, H.Windup + H.Strike + 0.3, Vector3.zero, {}, {}) do
			if x.strike then
				struck += 1
				assert(x.strike == "p1", "the one he wound up at")
			end
		end
		assert(struck == 1, "one blow, once")
	end)

	t.test("driven off he goes to the far end of his round and sees nothing until the time is up", function()
		local stops = { Vector3.new(0, 2, 0), Vector3.new(300, 2, 0), Vector3.new(20, 2, 0) }
		local brain = HuntsmanBrain.new(H, stops)
		brain:drive(Vector3.new(10, 2, 0))
		local a = brain:update(0.1, 1, Vector3.new(10, 2, 0), { { id = "p1", at = Vector3.new(12, 4, 0) } }, {})
		assert(a.state == "Driven" and a.goal == stops[2], "to the farthest stop, the light ignored")
		local actions = run(brain, 1, H.DriveSeconds + 0.3, Vector3.new(300, 2, 0), {}, {})
		assert(actions[#actions].state ~= "Driven", "and back when the time is up")
	end)

	t.test("the wood's numbers hold together", function()
		assert(#Cfg.Fires == 4, "four fires")
		assert(Cfg.PitchPots >= #Cfg.Fires and Cfg.PitchPots <= #Cfg.PitchSpots, "enough pots for the fires, and places for them")
		assert(#Cfg.Pages == #Cfg.PageSpots, "a place for every page")
		assert(H.See.Covered < H.See.Open and H.See.CoveredCrouched <= H.See.Covered, "covering hides")
		assert(Cfg.Fire.Glow < H.See.Open, "a fire's glow is smaller than his sight")
		assert(Cfg.Cover.Range < 8, "a covered lantern is a glimmer")
		assert(Cfg.Outer.X0 < -188 and Cfg.Outer.X1 < -188, "the outer wood is beyond the west wall")
		for i, stop in H.Round do
			assert(inBox(stop, Cfg.Inner) or inBox(stop, Cfg.Hollow) or inBox(stop, Cfg.Outer) or (stop.X < -171 and stop.X > -232 and stop.Z <= Cfg.Breach.Z0 and stop.Z >= Cfg.Breach.Z1), "round stop " .. i .. " is in the wood")
		end
		for _, f in Cfg.Fires do
			assert(inBox(f.at, Cfg.Inner) or inBox(f.at, Cfg.Hollow) or inBox(f.at, Cfg.Outer), f.id .. " is in the wood")
		end
	end)
end
