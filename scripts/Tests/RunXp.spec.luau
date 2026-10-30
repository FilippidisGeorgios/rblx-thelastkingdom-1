--!strict
--[[
	RunXp.spec
	What a run pays in experience: the dead by tier, each chamber once, the deeds, and the victory bonus;
	a wiped run keeps everything but the bonus.

	Location: TestService.Tests.RunXp.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunXp = require(ServerScriptService.Server.Domain.RunXp)
local Experience: any = require(ReplicatedStorage.Config.Experience)

local rules = {
	Kill = { Standard = 2, Elite = 8, Boss = 60 },
	Chamber = { Base = 30, PerChamber = 10 },
	Deed = 60,
	Won = 300,
}

return function(t: any)
	t.test("an empty run pays nothing", function()
		local xp = RunXp.compute({ kills = {}, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(xp.total == 0, "nothing done, nothing paid")
	end)

	t.test("the dead pay by their tier", function()
		local xp = RunXp.compute({ kills = { Standard = 10, Elite = 2, Boss = 1 }, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(xp.kills == 10 * 2 + 2 * 8 + 60 and xp.total == xp.kills, "20 + 16 + 60")
		local unknown = RunXp.compute({ kills = { Mystery = 5 }, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(unknown.total == 0, "a tier nobody priced pays nothing, not an error")
	end)

	t.test("each chamber pays Base + PerChamber x n, once however often it is reported", function()
		local xp = RunXp.compute({ kills = {}, cleared = { 1, 2, 2, 3 }, deeds = 0 }, "wiped", rules)
		assert(xp.chambers == (30 + 10) + (30 + 20) + (30 + 30), "chambers 1, 2 and 3 once each")
	end)

	t.test("deeds pay, and a victory adds its bonus on top; a wipe does not", function()
		local run = { kills = { Standard = 5 }, cleared = { 1 }, deeds = 3 }
		local won = RunXp.compute(run, "won", rules)
		local wiped = RunXp.compute(run, "wiped", rules)
		assert(won.deeds == 180 and won.won == 300, "three deeds and the castle taken")
		assert(wiped.won == 0, "no victory bonus on a wipe")
		assert(won.total - wiped.total == 300, "a wipe keeps all the rest: progress persists")
	end)

	t.test("a full victory is worth about what the curve was tuned for", function()
		local kills = { Standard = 350, Elite = 25, Boss = 3 }
		local cleared = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
		local xp = RunXp.compute({ kills = kills, cleared = cleared, deeds = 9 }, "won", Experience.Sources)
		assert(xp.total > 1500 and xp.total < 4000, "a full run pays a few thousand: " .. xp.total)
	end)

	local full = Experience.Sources

	t.test("helping pays: an assist and a fallen friend raised", function()
		local run = { kills = {}, cleared = {}, deeds = 0, damage = 500, assists = 10, revives = 2, activeSeconds = 0 }
		local xp = RunXp.compute(run, "wiped", full)
		assert(xp.assists == 10 * full.Assist and xp.revives == 2 * full.Revive, "ten assists, two raised")
		assert(xp.total == xp.assists + xp.revives, "nothing else was done")
	end)

	t.test("time on their feet pays by the minute, whole minutes only, up to the cap", function()
		local function timePay(seconds: number): number
			return RunXp.compute({ kills = {}, cleared = {}, deeds = 0, damage = 1000, activeSeconds = seconds }, "wiped", full).time
		end
		assert(timePay(59) == 0, "a part minute pays nothing")
		assert(timePay(60) == full.Time.PerMinute, "one minute")
		assert(timePay(10 * 60 + 30) == 10 * full.Time.PerMinute, "ten whole minutes")
		assert(timePay(500 * 60) == full.Time.CapMinutes * full.Time.PerMinute, "the cap: standing there all day is not a career")
	end)

	t.test("a player who took no part is paid the shared prizes at a share, and no time", function()
		local run = { kills = {}, cleared = { 1, 2 }, deeds = 2, damage = 0, assists = 0, revives = 0, activeSeconds = 1800 }
		local idle = RunXp.compute(run, "won", full)
		assert(not idle.tookPart and idle.time == 0, "no part, no time pay")
		local played = RunXp.compute({ kills = run.kills, cleared = run.cleared, deeds = 2, damage = 800, activeSeconds = 1800 }, "won", full)
		assert(played.tookPart and played.time > 0, "this one played")
		local sharedIdle = idle.chambers + idle.deeds + idle.won
		local sharedPlayed = played.chambers + played.deeds + played.won
		assert(math.abs(sharedIdle - sharedPlayed * full.Participation.IdleShare) < 1e-6, "the shared prizes at the idle share")
		assert(idle.total > 0, "still something: they are not made to lose what the party earned")
	end)

	t.test("a few blows, or a single raised friend, are enough to count as playing", function()
		local rules = full
		assert(RunXp.tookPart({ kills = {}, cleared = {}, deeds = 0, damage = rules.Participation.MinContribution }, rules), "the line itself")
		assert(not RunXp.tookPart({ kills = {}, cleared = {}, deeds = 0, damage = rules.Participation.MinContribution - 1 }, rules), "a hair under")
		assert(RunXp.tookPart({ kills = {}, cleared = {}, deeds = 0, damage = 0, revives = 1 }, rules), "raising a friend is playing")
		assert(RunXp.tookPart({ kills = {}, cleared = {}, deeds = 0, damage = 0, assists = 4 }, rules), "four assists too")
	end)

	t.test("the old shape of a run (no damage count) still counts as playing", function()
		local xp = RunXp.compute({ kills = {}, cleared = { 1 }, deeds = 0 }, "wiped", full)
		assert(xp.tookPart and xp.chambers == full.Chamber.Base + full.Chamber.PerChamber, "paid in full")
	end)

	t.test("a full, well-played victory with helping and time still lands in the tuned range", function()
		local run = {
			kills = { Standard = 350, Elite = 25, Boss = 3 },
			cleared = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
			deeds = 9,
			damage = 60000,
			assists = 60,
			revives = 2,
			activeSeconds = 42 * 60,
		}
		local xp = RunXp.compute(run, "won", full)
		assert(xp.total > 2500 and xp.total < 4500, "a few thousand: " .. xp.total)
		assert(xp.time == 42 * full.Time.PerMinute, "forty-two minutes")
	end)
end
