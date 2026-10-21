--!strict
--[[
	Trial deed: `chop`
	The woodyard. An axe waits in a stump; six dead trees stand in the yard;
	a stack of cut planks lies by the saw pit. Planks are what the Great Hall's
	doors are boarded with (chamber 6), so a player who cuts them walks into
	the siege with something to do about it, and one who does not walks into it
	short. It is optional, and the gate never waits for it.

	  - Take the axe from the stump (carried, never banked).
	  - Hold at a tree with the axe in your hands: it falls, and gives `perTree`
	    planks. Without the axe the tree says so.
	  - The plank stack gives `stack` planks for the taking.
	  - Planks are carried (stack to 16). The deed is done, and pays its prize,
	    when `target` planks have been gathered in all.

	Params (configs/Trials):
	  woodyard   dotted path of the woodyard model (contains the axe stump)
	  trees      dotted path of the scenery folder; every `Choppable` model is a tree
	  stack      dotted path of the plank stack
	  perTree, stackPlanks, target, prize (a configs/Loot table), chopHold

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local TweenService = game:GetService("TweenService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local LootService = require(script.Parent.Parent.LootService)
local Util = require(script.Parent.Util)

local Chop = {}

local function treeCentre(tree: Model): Vector3
	local cf, size = tree:GetBoundingBox()
	return Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
end

function Chop.create(ctx: any, def: any)
	local connections: { any } = {}
	local gathered = 0
	local finished = false

	local function gain(player: Player, n: number, at: Vector3)
		local took = BackpackService.add(player, "plank", n, true)
		if took > 0 then
			gathered += took
			ctx.note(("Planks: %d of %d."):format(math.min(gathered, def.target), def.target), 3)
			if gathered >= def.target and not finished then
				finished = true
				LootService.grantAll(def.prize, at + Vector3.new(0, 3, 0))
				ctx.note("Enough planks for a hall full of doors. Something else turned up in the chips.", 5)
				ctx.done()
			end
		else
			ctx.note("You cannot carry any more planks.", 3)
		end
		return took
	end

	return {
		start = function()
			-- THE AXE
			local yard = Util.find(def.woodyard)
			local stump: Instance? = nil
			if yard then
				for _, d in yard:GetDescendants() do
					if d:GetAttribute("Axe") then
						stump = d
						break
					end
				end
			end
			if stump then
				local prompt = Util.prompt(ctx.folder, Util.position(stump) + Vector3.new(0, 4.5, 0), "TakeAxe", "Take the axe", "Woodsman's axe", 0.8, 10)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if BackpackService.add(player, "axe", 1, true) > 0 then
							ctx.note("An axe, left in the stump. Good.", 3)
							prompt.Parent:Destroy()
						else
							ctx.note("You have one already.", 2)
						end
					end)
				)
			else
				ctx.warn("chop: no axe stump in " .. tostring(def.woodyard))
			end

			-- THE TREES
			local scenery = Util.find(def.trees)
			if scenery then
				for _, tree in scenery:GetDescendants() do
					if tree:IsA("Model") and tree:GetAttribute("Choppable") == true then
						local base = treeCentre(tree)
						local prompt = Util.prompt(ctx.folder, base + Vector3.new(0, 3.6, 0), "ChopTree", "Chop", "Dead tree", def.chopHold, 9)
						table.insert(
							connections,
							prompt.Triggered:Connect(function(player: Player)
								if tree:GetAttribute("Choppable") ~= true then
									return
								end
								if BackpackService.count(player, "axe") <= 0 then
									ctx.note("You need an axe. There is one in a stump in the yard.", 3)
									return
								end
								tree:SetAttribute("Choppable", false)
								prompt.Parent:Destroy()
								-- It tips over about its foot, away from the one who cut it.
								local pivot = tree:GetPivot()
								local away = (base - (player.Character and player.Character:GetPivot().Position or base))
								away = Vector3.new(away.X, 0, away.Z)
								local axis = if away.Magnitude > 0.1 then away.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
								local foot = CFrame.new(base)
								local tilt = foot * CFrame.fromAxisAngle(axis, math.rad(-82)) * foot:Inverse() * pivot
								local value = Instance.new("CFrameValue")
								value.Value = pivot
								value.Changed:Connect(function(cf)
									if tree.Parent then
										tree:PivotTo(cf)
									end
								end)
								local tween = TweenService:Create(value, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = tilt })
								tween:Play()
								tween.Completed:Connect(function()
									value:Destroy()
								end)
								gain(player, def.perTree, base)
							end)
						)
					end
				end
			else
				ctx.warn("chop: no trees at " .. tostring(def.trees))
			end

			-- THE PLANK STACK
			local stack = Util.find(def.stack)
			if stack then
				local prompt = Util.prompt(ctx.folder, Util.position(stack) + Vector3.new(0, 3, 0), "TakePlanks", "Take planks", "Cut planks", 0.9, 10)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if gain(player, def.stackPlanks, Util.position(stack)) > 0 then
							prompt.Parent:Destroy()
						end
					end)
				)
			end
		end,

		stop = function()
			-- A deed stays on offer until the trial ends (TrialService leaves deeds running).
		end,

		progress = function(): (number, number)
			return math.min(gathered, def.target), def.target
		end,
	}
end

return Chop
