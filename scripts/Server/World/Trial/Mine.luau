--!strict
--[[
	Trial deed: `mine`
	The mine in the south-west corner: veins of gold in the walls of the adit,
	a cart, broken rails. Prise a vein with the hold at its face and it gives
	what the vein table gives (gold, sometimes iron, rarely silver); one of the
	veins, which one changes every run, holds a miner's pickaxe that a
	chamber far on will want (rubble in the Inner Ward, chamber 8). Finding it
	is the deed.

	Gold is PERSONAL like all spoils (Domain/LootTable, Server/World/LootService):
	each vein is rolled for whoever prised it.

	Params (configs/Trials):
	  veins    dotted path of the mine model; every part named `GoldVein` is a vein
	  count    how many of them to open as veins this run (the rest stay rock)
	  table    a configs/Loot table id
	  hold     seconds to prise one

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local BackpackService = require(script.Parent.Parent.BackpackService)
local LootService = require(script.Parent.Parent.LootService)
local Util = require(script.Parent.Util)

local Mine = {}

local rng = Random.new()

function Mine.create(ctx: any, def: any)
	local connections: { any } = {}
	local found = false

	return {
		start = function()
			local mine = Util.find(def.veins)
			if not mine then
				ctx.warn("mine: nothing at " .. tostring(def.veins))
				return
			end
			local veins: { BasePart } = {}
			for _, d in mine:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "GoldVein" then
					table.insert(veins, d)
				end
			end
			-- Shuffle; the first `count` are real veins and the first of THOSE hides the pickaxe.
			for i = #veins, 2, -1 do
				local j = rng:NextInteger(1, i)
				veins[i], veins[j] = veins[j], veins[i]
			end
			local opened = math.min(def.count, #veins)
			local pickIndex = rng:NextInteger(1, math.max(1, opened))
			for i = 1, opened do
				local vein = veins[i]
				local hidesPick = (i == pickIndex)
				local prompt = Util.prompt(ctx.folder, vein.Position + Vector3.new(0, 0, 2.2), "Vein", "Prise out the gold", "Gold vein", def.hold, 9)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						prompt.Enabled = false
						prompt.Parent:Destroy()
						vein.Color = vein.Color:Lerp(Color3.fromRGB(70, 66, 60), 0.7)
						vein.Material = Enum.Material.Slate
						LootService.grant(player, def.table, vein.Position + Vector3.new(0, 1, 3))
						if hidesPick and not found then
							found = true
							BackpackService.add(player, "pickaxe", 1, true)
							ctx.note("A pickaxe, rusted and sound, left in the seam. Keep it.", 5)
							ctx.done()
						end
					end)
				)
			end
		end,

		stop = function() end,

		progress = function(): (number, number)
			return if found then 1 else 0, 1
		end,
	}
end

return Mine
