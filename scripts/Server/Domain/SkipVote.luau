--!strict
--[[
	SkipVote
	How many players must hold SKIP before the arrival scene is skipped. Pure arithmetic, so it can be tested
	without a server.

	The numbers are the developer's own table (`Intro.SkipVotes`, one entry per party size):
	1 player needs 1, 2 need 2, 3 need 2, 4 need 3, 5 need 3, 6 need 4, 7 need 5, 8 need 5, 9 need 6, 10 need 7.
	It is a table and not a formula because those are not one formula: it is a majority for the small parties and
	a firmer majority for the big ones. Above the table's end the same share as its last row is used.

	Location: ServerScriptService.Server.Domain.SkipVote
]]

local SkipVote = {}

--[[
	votes needed for a party of `present` players.
	`table` is `Intro.SkipVotes`; `overflowShare` is the share of the party asked for beyond its end.
	Never less than 1, never more than the players there are (an impossible row cannot lock a party in).
]]
function SkipVote.needed(present: number, rows: { number }, overflowShare: number): number
	local count = math.max(0, math.floor(present))
	if count <= 1 then
		return 1
	end
	local raw = rows[count]
	if raw == nil then
		raw = math.ceil(count * overflowShare)
	end
	return math.clamp(math.floor(raw), 1, count)
end

return SkipVote
