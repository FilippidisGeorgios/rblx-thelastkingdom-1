--!strict
--[[
	Trial task: `light`
	Carry fire to N cold braziers. Chamber 4's whole job.

	  1. Take fire from a SOURCE (the chapel altar's candles) or from any brazier
	     that is already alight. You hold a torch.
	  2. The torch burns for `torchSeconds`. Its flame is the clock.
	  3. Hold at a cold brazier for `holdSeconds` to light it. The torch is spent.
	  4. When every brazier burns the task is done.

	WHY A SPENT TORCH, AND A SHORT ONE
	If a torch lit every brazier on one trip there would be no decision; if it
	lasted two minutes there would be no clock. One torch, one brazier, 25
	seconds, with the braziers 36 to 150 studs from the altar: you take the
	near ones first and refuel at each, or you gamble on the far one while the
	dead keep climbing out of its section (Rising, in Trial/Rising). A lit
	brazier is itself a source, so the chain is always possible and the fight
	between trips is the game.

	Params (configs/Trials):
	  braziers           dotted path of the model holding the braziers; each child has `Section`
	  sources            dotted paths of the scenery you take fire from
	  torchSeconds       how long a torch burns
	  holdSeconds        hold time at a cold brazier
	  sourceHoldSeconds  hold time to take fire

	The brazier's `Lit` attribute is the signal other systems read (Rising
	stops a section's graves when it turns true).

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local TweenService = game:GetService("TweenService")

local Util = require(script.Parent.Util)
local Torch = require(script.Parent.Torch)

local Light = {}

type Brazier = {
	model: Model,
	prompt: ProximityPrompt,
	lit: boolean,
	section: number,
}

function Light.create(ctx: any, def: any)
	local braziers: { Brazier } = {}
	local sourcePrompts: { ProximityPrompt } = {}
	local connections: { any } = {}
	local active = false
	local litCount = 0

	local root = ctx.folder :: Instance

	local function report()
		ctx.progress(litCount, #braziers)
	end

	local function takeFire(player: Player)
		if Torch.give(player, def.torchSeconds) then
			ctx.note("Fire in hand. It will not last.", 3)
		end
	end

	local function ignite(b: Brazier, player: Player)
		Torch.consume(player)
		b.lit = true
		litCount += 1
		b.model:SetAttribute("Lit", true)

		local point = b.model:FindFirstChild("FirePoint")
		if point and point:IsA("BasePart") then
			local fire, light = Util.flame(point, 4, 36)
			TweenService:Create(fire, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = 9, Heat = 8 }):Play()
			light.Brightness = 2.4
		end

		-- A lit brazier is a source from now on.
		b.prompt.ActionText = "Take fire"
		b.prompt.ObjectText = "Brazier"
		b.prompt.HoldDuration = def.sourceHoldSeconds

		report()
		if litCount >= #braziers then
			active = false
			ctx.note("The last brazier takes. The graves go quiet.", 4)
			ctx.done()
		else
			ctx.note(("Brazier lit - section %d is shut."):format(b.section), 3)
		end
	end

	local function onBrazier(b: Brazier, player: Player)
		if not active then
			return
		end
		if b.lit then
			takeFire(player)
		elseif Torch.isLit(player) then
			ignite(b, player)
		else
			ctx.note("It needs fire. The altar in the chapel is lit.", 3)
		end
	end

	return {
		start = function()
			active = true
			local set = Util.find(def.braziers)
			if not set then
				ctx.warn("light: no braziers at " .. tostring(def.braziers))
				return
			end

			for _, child in set:GetChildren() do
				local point = child:FindFirstChild("FirePoint")
				if child:IsA("Model") and point and point:IsA("BasePart") then
					local prompt = Util.prompt(root, point.Position - Vector3.new(0, 2.2, 0), "BrazierPrompt", "Light", "Brazier - cold", def.holdSeconds, 10)
					local b: Brazier = {
						model = child,
						prompt = prompt,
						lit = child:GetAttribute("Lit") == true,
						section = (child:GetAttribute("Section") :: number?) or 0,
					}
					table.insert(braziers, b)
					table.insert(
						connections,
						prompt.Triggered:Connect(function(player: Player)
							onBrazier(b, player)
						end)
					)
				end
			end
			table.sort(braziers, function(a, b)
				return a.section < b.section
			end)

			for _, path in def.sources do
				local scenery = Util.find(path)
				if scenery then
					local prompt = Util.prompt(
						root,
						Util.position(scenery) + Vector3.new(0, 2.6, 0),
						"FireSource",
						"Take fire",
						"Altar candles",
						def.sourceHoldSeconds,
						11
					)
					table.insert(sourcePrompts, prompt)
					table.insert(
						connections,
						prompt.Triggered:Connect(function(player: Player)
							if active then
								takeFire(player)
							end
						end)
					)
				else
					ctx.warn("light: no fire source at " .. path)
				end
			end

			table.insert(connections, Torch.onExpired(function(player: Player)
				if active then
					ctx.note("Your torch gutters out. Fresh fire: the altar, or a lit brazier.", 4)
				end
			end))
			report()
		end,

		stop = function()
			active = false
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			for _, b in braziers do
				b.prompt.Enabled = false
			end
			for _, p in sourcePrompts do
				p.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return litCount, #braziers
		end,
	}
end

return Light
