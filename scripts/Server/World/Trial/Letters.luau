--!strict
--[[
	Trial deed: `letters`
	Several pages lying in several houses, each a different hand, together a
	picture (docs/systems/Story.md §5: the fall is uncovered by the player, not
	told). Each is a parchment on a table that glows a little; reading one opens
	it on that player's screen. The deed is done, and pays its prize (a configs/Loot
	table, `prize`), when every one has been read by someone.

	It is optional: the gate never waits for it. It exists so the Rows, the one
	"cheerful" chamber of the castle (AreaPlan §7), can say what it saw.

	Params (configs/Trials):
	  letters  { { at = dotted path of the table, title, sign, lines = { string } } }
	  prize    a configs/Loot table id

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local LootService = require(script.Parent.Parent.LootService)
local Read = require(script.Parent.Read)
local Util = require(script.Parent.Util)

local Letters = {}

function Letters.create(ctx: any, def: any)
	local read: { [number]: boolean } = {}
	local count = 0
	local total = #def.letters
	local finished = false
	local lastAt = Vector3.zero

	return {
		start = function()
			for i, letter in def.letters do
				local scenery = Util.find(letter.at)
				if scenery then
					lastAt = Util.position(scenery)
				end
				Read.place(ctx, letter.at, letter.title, letter.sign, function()
					return letter.lines
				end, function()
					if read[i] then
						return
					end
					read[i] = true
					count += 1
					ctx.note(("Letters found: %d of %d."):format(count, total), 3)
					if count >= total and not finished then
						finished = true
						LootService.grantAll(def.prize, lastAt + Vector3.new(0, 4, 0))
						ctx.note("That is all of it. The Rows told you what they could.", 5)
						ctx.done()
					end
				end)
			end
		end,

		stop = function() end,

		progress = function(): (number, number)
			return count, total
		end,
	}
end

return Letters
