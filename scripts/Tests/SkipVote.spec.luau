--!strict
--[[
	SkipVote.spec
	The skip table the developer asked for, row by row, and the limits around it.

	Location: TestService.Tests.SkipVote.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SkipVote = require(ServerScriptService.Server.Domain.SkipVote)
local Intro: any = require(ReplicatedStorage.Config.Intro)

return function(t: any)
	t.test("the table is the one asked for: 1,2,2,3,3,4,5,5,6,7 for one to ten players", function()
		local want = { 1, 2, 2, 3, 3, 4, 5, 5, 6, 7 }
		for players, votes in want do
			local got = SkipVote.needed(players, Intro.SkipVotes, Intro.SkipOverflowShare)
			assert(got == votes, ("%d players need %d votes, got %d"):format(players, votes, got))
		end
	end)

	t.test("alone, or nobody counted yet, one vote is enough", function()
		assert(SkipVote.needed(1, Intro.SkipVotes, 0.7) == 1, "one player")
		assert(SkipVote.needed(0, Intro.SkipVotes, 0.7) == 1, "an empty cast cannot ask for more than 1")
	end)

	t.test("past the end of the table the overflow share is used", function()
		assert(SkipVote.needed(11, { 1, 2 }, 0.7) == 8, "ceil(11 * 0.7)")
		assert(SkipVote.needed(12, { 1, 2 }, 0.5) == 6, "half of twelve")
	end)

	t.test("a row can never ask for more people than there are", function()
		assert(SkipVote.needed(3, { 1, 9, 9 }, 0.7) == 3, "capped at the party")
		assert(SkipVote.needed(2, { 1, 0 }, 0.7) == 1, "and at least one")
	end)

	t.test("every row of the real table is a majority that never shrinks as the party grows", function()
		local last = 0
		for players = 1, #Intro.SkipVotes do
			local got = SkipVote.needed(players, Intro.SkipVotes, Intro.SkipOverflowShare)
			assert(got >= last, "never fewer votes for a bigger party")
			assert(got * 2 > players, ("%d of %d is a majority"):format(got, players))
			last = got
		end
	end)
end
