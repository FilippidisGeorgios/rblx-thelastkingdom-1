--!strict
--[[
	Trial.Recipe
	The Kitchens' recipe, rolled once per run and shared by the tasks that need
	it: the papyrus that reads it out, the nodes that hold the ingredients, the
	pot that wants them.

	`trial.recipe` in configs/Trials:
	  title, sign        the parchment's heading and the hand that wrote it
	  intro, outro       lines before and after the list
	  pick               how many ingredients this run asks for
	  pool               { { id, name, line, where, prop } } the ingredients that exist
	                     id    ingredient_<id> in configs/Items
	                     line  what the parchment says about it
	                     where a dotted scenery path the node is placed around
	                     prop  "sack" | "ham" | "herbs" | "bucket" | "crate" | "cask" | "crock"

	The roll lives in ctx.shared.recipe, so every task of the trial sees the
	same four.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Recipe = {}

export type Pick = { id: string, name: string, line: string, where: string, prop: string }

local rng = Random.new()

--[[
	The chosen ingredients, rolled on first use. `def` is the trial's `recipe`
	table; `shared` is the trial's shared bag.
]]
function Recipe.get(shared: { [string]: any }, def: any): { Pick }
	local existing = shared.recipe
	if existing then
		return existing
	end
	local pool = table.clone(def.pool)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local chosen: { Pick } = {}
	for i = 1, math.min(def.pick, #pool) do
		chosen[i] = pool[i]
	end
	shared.recipe = chosen
	return chosen
end

-- The parchment's text: intro, one line per ingredient, outro.
function Recipe.lines(shared: { [string]: any }, def: any): { string }
	local lines: { string } = { def.intro, "" }
	for _, pick in Recipe.get(shared, def) do
		table.insert(lines, "- " .. pick.line)
	end
	table.insert(lines, "")
	table.insert(lines, def.outro)
	return lines
end

return Recipe
