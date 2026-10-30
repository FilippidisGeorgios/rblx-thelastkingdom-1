--!strict
--[[
	AssistLedger.spec
	An assist: striking an enemy someone else finishes, soon enough. Not the killer, not too long ago, once.

	Location: TestService.Tests.AssistLedger.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local AssistLedger = require(ServerScriptService.Server.Domain.AssistLedger)

local function has(list: { any }, who: any): boolean
	return table.find(list, who) ~= nil
end

return function(t: any)
	t.test("someone who struck it lately and did not kill it has helped", function()
		local ledger = AssistLedger.new(12, 60)
		ledger:blow("zombie1", "ada", 0)
		ledger:blow("zombie1", "bram", 3)
		local helpers = ledger:killed("zombie1", "bram", 5)
		assert(#helpers == 1 and has(helpers, "ada"), "ada helped, bram made the kill")
	end)

	t.test("the killer is never their own helper, and a lone attacker has no helpers", function()
		local ledger = AssistLedger.new(12, 60)
		ledger:blow("z", "ada", 0)
		ledger:blow("z", "ada", 2)
		assert(#ledger:killed("z", "ada", 3) == 0, "no one else struck it")
	end)

	t.test("a blow from long ago is not an assist", function()
		local ledger = AssistLedger.new(12, 60)
		ledger:blow("z", "ada", 0)
		ledger:blow("z", "bram", 40)
		assert(#ledger:killed("z", "bram", 41) == 0, "ada's last blow was 41 seconds ago")
	end)

	t.test("the last blow is what counts, not the first", function()
		local ledger = AssistLedger.new(12, 60)
		ledger:blow("z", "ada", 0)
		ledger:blow("z", "ada", 30)
		ledger:blow("z", "bram", 31)
		assert(has(ledger:killed("z", "bram", 32), "ada"), "ada struck again 2 seconds ago")
	end)

	t.test("every helper is counted, once, and the enemy is forgotten after it dies", function()
		local ledger = AssistLedger.new(12, 60)
		for _, who in { "a", "b", "c" } do
			ledger:blow("z", who, 1)
			ledger:blow("z", who, 2)
		end
		local helpers = ledger:killed("z", "d", 3)
		assert(#helpers == 3, "three helpers, however many blows each")
		assert(#ledger:killed("z", "d", 4) == 0, "a second death of the same id pays nothing")
	end)

	t.test("enemies are kept apart", function()
		local ledger = AssistLedger.new(12, 60)
		ledger:blow("z1", "ada", 0)
		ledger:blow("z2", "bram", 0)
		assert(#ledger:killed("z1", "bram", 1) == 1, "ada helped with z1")
		assert(#ledger:killed("z2", "ada", 1) == 1, "bram helped with z2")
	end)

	t.test("enemies never killed are forgotten, and the ledger cannot grow without end", function()
		local ledger = AssistLedger.new(12, 60, 5)
		for i = 1, 5 do
			ledger:blow("old" .. i, "ada", 0)
		end
		assert(ledger.count == 5, "five tracked")
		ledger:blow("new", "ada", 100) -- past the cap and the old ones are stale: they go
		assert(ledger.count == 1, "only the fresh one is kept: " .. ledger.count)
		ledger:blow("z", "ada", 200)
		ledger:clear()
		assert(ledger.count == 0 and #ledger:killed("z", "bram", 201) == 0, "clear empties it")
	end)
end
