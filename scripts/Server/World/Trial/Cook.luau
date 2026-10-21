--!strict
--[[
	Trial task: `cook`
	The pot in the kitchen hall. Put the ingredients in, mind it while it
	simmers, ladle the broth.

	  1. Hold at the pot with an ingredient in your hands: it goes in. (Any
	     player, any ingredient; the pot remembers what it has.)
	  2. When it has everything the recipe asked for it begins to SIMMER. The
	     smell draws the dead (the trial's `tide` pressure starts on this
	     chamber's signal "simmer"), and the pot has to be MINDED: it only
	     simmers while a player is within `mindRadius` studs of it. Walk away to
	     fight and the steam sinks and the clock waits; come back and it goes on.
	  3. When it is ready the task is done and the pot offers broth: hold at it
	     to take a ladle (up to `portions`, five, one per mouth to feed). The pot
	     stays usable after the task ends.

	The pot is a place you have to stand and the dead come to it: that is the
	whole chamber (docs/systems/Trials.md §5, chamber 3). It does not need two
	players; a second one only makes the standing safer.

	Params (configs/Trials):
	  pot             dotted path of the cauldron model
	  simmerSeconds   how long it must be minded
	  mindRadius      studs
	  portions        ladles it gives

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local Recipe = require(script.Parent.Recipe)
local Util = require(script.Parent.Util)

local Cook = {}

local function steamEmitter(parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Rate = 0
	e.Lifetime = NumberRange.new(1.6, 2.6)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(18, 18)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.LightInfluence = 0.6
	e.Color = ColorSequence.new(Color3.fromRGB(226, 226, 220))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 3.6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = parent
	return e
end

function Cook.create(ctx: any, def: any)
	local picks = Recipe.get(ctx.shared, ctx.trial.recipe)
	local needed: { [string]: boolean } = {}
	for _, p in picks do
		needed[p.id] = true
	end
	local total = #picks
	local added: { [string]: boolean } = {}
	local addedCount = 0

	local state = "add" -- "add" | "simmer" | "ready"
	local mindLeft: number = def.simmerSeconds
	local portions: number = def.portions
	local connections: { any } = {}
	local prompt: ProximityPrompt? = nil
	local steam: ParticleEmitter? = nil
	local potPos = Vector3.zero
	local warnedAt = 0
	local ticker: RBXScriptConnection? = nil

	local function minded(): boolean
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				if (root.Position - potPos).Magnitude <= def.mindRadius then
					return true
				end
			end
		end
		return false
	end

	local function becomeReady()
		state = "ready"
		if ticker then
			ticker:Disconnect()
			ticker = nil
		end
		if prompt then
			prompt.ActionText = "Take a ladle"
			prompt.ObjectText = ("Broth (%d left)"):format(portions)
			prompt.HoldDuration = 1
			prompt.Enabled = true
		end
		if steam then
			steam.Rate = 22
		end
		ctx.hint(nil)
		ctx.note("The broth is ready. Take it to the penned.", 5)
		ctx.done()
	end

	local function beginSimmer()
		state = "simmer"
		if prompt then
			prompt.Enabled = false
		end
		ctx.signal("simmer")
		ctx.hint("Mind the pot while it simmers - stay close")
		ctx.note("It begins to simmer. They will smell it.", 4)

		ticker = RunService.Heartbeat:Connect(function(dt: number)
			if state ~= "simmer" then
				return
			end
			local progress = 1 - mindLeft / def.simmerSeconds
			if minded() then
				mindLeft -= dt
				if steam then
					steam.Rate = 4 + 18 * progress
				end
				if mindLeft <= 0 then
					becomeReady()
				end
			else
				if steam then
					steam.Rate = 1
				end
				local now = os.clock()
				if now - warnedAt > 8 then
					warnedAt = now
					ctx.note("The pot needs minding. The steam is sinking.", 3)
				end
			end
		end)
	end

	local function onTrigger(player: Player)
		if state == "add" then
			local gave = {}
			for id in needed do
				if not added[id] and BackpackService.count(player, "ingredient_" .. id) > 0 then
					BackpackService.remove(player, "ingredient_" .. id, 1)
					added[id] = true
					addedCount += 1
					table.insert(gave, id)
				end
			end
			if #gave == 0 then
				ctx.note("The pot is waiting for what the recipe asks.", 3)
				return
			end
			ctx.progress(addedCount, total)
			if addedCount >= total then
				beginSimmer()
			else
				ctx.note("Into the pot.", 2)
			end
		elseif state == "ready" then
			if portions <= 0 then
				ctx.note("The pot is empty.", 3)
				return
			end
			if BackpackService.add(player, "broth", 1, true) > 0 then
				portions -= 1
				if prompt then
					prompt.ObjectText = if portions > 0 then ("Broth (%d left)"):format(portions) else "Empty"
					if portions <= 0 then
						prompt.Enabled = false
					end
				end
			else
				ctx.note("Your hands are full of broth.", 2)
			end
		end
	end

	return {
		start = function()
			local pot = Util.find(def.pot)
			if not pot then
				ctx.warn("cook: no pot at " .. tostring(def.pot))
				return
			end
			potPos = Util.position(pot)
			local top = potPos + Vector3.new(0, 3.2, 0)

			local anchor = Instance.new("Part")
			anchor.Name = "Steam"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(2, 0.2, 2)
			anchor.Position = top
			anchor.Parent = ctx.folder
			steam = steamEmitter(anchor)

			prompt = Util.prompt(ctx.folder, top, "PotPrompt", "Put in the pot", "The pot - empty", 0.8, 12)
			table.insert(connections, (prompt :: ProximityPrompt).Triggered:Connect(onTrigger))
			ctx.progress(0, total)
		end,

		-- The pot stays: the ladle is taken after the task is done.
		stop = function() end,

		progress = function(): (number, number)
			return addedCount, total
		end,
	}
end

return Cook
