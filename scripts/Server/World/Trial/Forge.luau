--!strict
--[[
	Trial task: `forge`
	The smithy's hearth, and the one thing in the run that makes your weapon
	permanently better (docs/systems/Arsenal.md §7.1). Three rounds of working
	hot iron, then a choice of how the edge is finished.

	  ROUND   Pump the bellows (hold E, again and again) to bring the heat up.
	          The heat is not stored: it bleeds away, from full to cold in
	          `decaySeconds`. When it is above the round's THRESHOLD the anvil
	          takes a blow (hold E there for a second); each blow costs heat, and
	          each round wants a hotter fire than the last (.70, .76, .82).
	  TEMPER  After the third blow three stations stand by the anvil, each a
	          different answer, and each player takes ONE for their own weapon:

	            whetstone      EDGE    +18% damage
	            pointing file  POINT   +3 studs of reach
	            heavy pommel   WEIGHT  +40% damage, swings 35% slower

	          They are numbers on RunModService, read by the melee code. They are
	          meant to be a real choice: a spear player wants Point, a mace
	          player Weight, and it decides how the Inner Ward goes.

	THE HEAT IS THE CLOCK. The hearth's coals brighten and its flame and light
	rise and fall with it, so the player reads "now" off the fire and not off a
	bar. The work is done while the dead are coming through the doors: the
	time spent pumping is time not spent fighting, which is the whole room.

	SOLO-FIRST. One pair of hands can pump and strike; a second player can
	pump while the first strikes, which makes it faster and never possible.

	Params (configs/Trials):
	  hearth, bellows, anvil   dotted scenery paths
	  rounds, decaySeconds, pump, strikeCost, thresholds
	  tempers                  { edge = {name, damage?, reach?, cooldown?}, point, weight }

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RunModService = require(script.Parent.Parent.RunModService)
local Util = require(script.Parent.Util)

local Forge = {}

-- How far below a round's line the heat may fall during a blow before it is withdrawn.
local HYSTERESIS = 0.10

local COLD = Color3.fromRGB(88, 34, 20)
local HOT = Color3.fromRGB(255, 214, 150)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sparks(parent: Instance, at: Vector3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = at
	anchor.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(8, 18)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -40, 0)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 30))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = anchor
	e:Emit(count)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function Forge.create(ctx: any, def: any)
	local heat = 0
	local round = 1
	local finished = false
	local temperOpen = false
	local chosen: { [Player]: boolean } = {}
	local connections: { any } = {}
	local ticker: RBXScriptConnection? = nil
	local glowParts: { { part: BasePart, base: Color3 } } = {}
	local fire: Fire? = nil
	local light: PointLight? = nil
	local bellowsPrompt: ProximityPrompt? = nil
	local anvilPrompt: ProximityPrompt? = nil
	local anvilPos = Vector3.zero
	local hearthPos = Vector3.zero
	local stationPrompts: { ProximityPrompt } = {}

	local function threshold(): number
		return def.thresholds[math.min(round, #def.thresholds)]
	end

	-- Read by the tests (and visible in Studio): where the work stands.
	local function publish()
		ctx.folder:SetAttribute("ForgeRound", round)
		ctx.folder:SetAttribute("ForgeHeat", math.floor(heat * 100))
	end

	local function paint()
		publish()
		local color = COLD:Lerp(HOT, heat)
		for _, g in glowParts do
			g.part.Color = g.base:Lerp(color, math.clamp(heat * 1.2, 0.15, 1))
		end
		if fire then
			fire.Size = 3 + 9 * heat
			fire.Heat = 4 + 8 * heat
		end
		if light then
			light.Brightness = 0.3 + 1.5 * heat
			light.Color = Color3.fromRGB(255, 120, 50):Lerp(Color3.fromRGB(255, 220, 170), heat)
		end
	end

	local function refreshAnvil()
		if not anvilPrompt then
			return
		end
		if round > def.rounds then
			anvilPrompt.Enabled = false
			return
		end
		--[[
			Hysteresis. The anvil is offered at the threshold but is only withdrawn
			well below it, because the blow is a HOLD of a second and the fire bleeds
			1.8% a second: withdrawing the prompt the instant the heat crossed the line
			would cancel a blow that was already going down. (The first version did
			exactly that, and a player who started a blow at 78% against a 76% line
			saw nothing happen.)
		]]
		local want = anvilPrompt.Enabled
		if heat >= threshold() then
			want = true
		elseif heat < threshold() - HYSTERESIS then
			want = false
		end
		if anvilPrompt.Enabled ~= want then
			anvilPrompt.Enabled = want
		end
	end

	local function openTempers()
		temperOpen = true
		if anvilPrompt then
			anvilPrompt.Enabled = false
		end
		ctx.hint("Finish the blade: choose a temper at the anvil")
		ctx.note("The iron has taken. How will you finish it?", 5)

		local options = {
			{ key = "edge", label = "Whetstone", sub = "Edge", offset = Vector3.new(-5, 0, 9.5), size = Vector3.new(2.4, 0.9, 1.1), color = Color3.fromRGB(120, 116, 110), material = Enum.Material.Slate },
			{ key = "point", label = "Pointing file", sub = "Point", offset = Vector3.new(0, 0, 9.5), size = Vector3.new(0.5, 0.4, 2.8), color = Color3.fromRGB(90, 94, 100), material = Enum.Material.Metal },
			{ key = "weight", label = "Heavy pommel", sub = "Weight", offset = Vector3.new(5, 0, 9.5), size = Vector3.new(1.6, 1.6, 1.6), color = Color3.fromRGB(70, 68, 68), material = Enum.Material.Metal },
		}
		for _, o in options do
			local tdef = def.tempers[o.key]
			local at = anvilPos + o.offset
			local floorY = anvilPos.Y - 1.1
			local prop = part(ctx.folder, "Temper_" .. o.key, o.size, CFrame.new(at.X, floorY + o.size.Y / 2 + 0.2, at.Z), o.color, o.material)
			prop.CanCollide = true
			local prompt = Util.prompt(ctx.folder, Vector3.new(at.X, floorY + 2.2, at.Z), "TemperPrompt_" .. o.key, o.label, tdef.name, 0.9, 6)
			table.insert(stationPrompts, prompt)
			table.insert(
				connections,
				prompt.Triggered:Connect(function(player: Player)
					if chosen[player] then
						ctx.note("Your blade is finished already.", 2.5)
						return
					end
					chosen[player] = true
					RunModService.set(player, "temper", { damage = tdef.damage, reach = tdef.reach, cooldown = tdef.cooldown, pierce = tdef.pierce })
					sparks(ctx.folder, at + Vector3.new(0, 2, 0), 30)
					ctx.note(("%s takes the %s: %s."):format(player.Name, o.label:lower(), tdef.text), 5)
					if not finished then
						finished = true
						ctx.hint(nil)
						ctx.done()
					end
				end)
			)
		end
	end

	local function strike(player: Player)
		if finished or round > def.rounds then
			return
		end
		if heat < threshold() - HYSTERESIS * 0.6 then
			ctx.note("Too cold. It will not take the blow.", 2.5)
			return
		end
		heat = math.max(0, heat - def.strikeCost)
		sparks(ctx.folder, anvilPos + Vector3.new(0, 1.4, 0), 36)
		ctx.progress(round, def.rounds)
		if round >= def.rounds then
			round += 1
			ctx.note("The last blow rings.", 3)
			openTempers()
		else
			round += 1
			ctx.note(("Blow %d of %d. Heat it again, hotter."):format(round - 1, def.rounds), 3)
		end
		paint()
	end

	return {
		start = function()
			local hearth = Util.find(def.hearth)
			local bellows = Util.find(def.bellows)
			local anvil = Util.find(def.anvil)
			if not (hearth and bellows and anvil) then
				ctx.warn("forge: hearth, bellows or anvil missing")
				return
			end
			hearthPos = Util.position(hearth)
			anvilPos = Util.position(anvil)

			for _, d in hearth:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "FireCore" or d.Name == "HotTip" or d.Name == "Coals" or d.Name == "Coal") then
					table.insert(glowParts, { part = d, base = d.Color })
				end
			end

			local anchor = Instance.new("Part")
			anchor.Name = "HeatAnchor"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(2, 0.2, 2)
			anchor.Position = hearthPos + Vector3.new(0, -1.6, 0)
			anchor.Parent = ctx.folder
			local f, l = Util.flame(anchor, 3, 22)
			fire, light = f, l

			bellowsPrompt = Util.prompt(ctx.folder, Util.position(bellows) + Vector3.new(0, 1.4, 0), "BellowsPrompt", "Work the bellows", "The forge", def.pumpHold, 9)
			anvilPrompt = Util.prompt(ctx.folder, anvilPos + Vector3.new(0, 1.8, 0), "AnvilPrompt", "Strike", "Anvil", def.strikeHold, 9)
			anvilPrompt.Enabled = false

			table.insert(
				connections,
				bellowsPrompt.Triggered:Connect(function()
					if finished or temperOpen then
						return
					end
					heat = math.min(1, heat + def.pump)
					sparks(ctx.folder, hearthPos + Vector3.new(0, -0.5, 0), 6)
					paint()
					refreshAnvil()
				end)
			)
			table.insert(connections, anvilPrompt.Triggered:Connect(strike))

			ticker = RunService.Heartbeat:Connect(function(dt: number)
				if finished or temperOpen then
					return
				end
				if heat > 0 then
					heat = math.max(0, heat - dt / def.decaySeconds)
				end
				paint()
				refreshAnvil()
			end)
			ctx.progress(0, def.rounds)
		end,

		-- The temper stations stay usable after the task: every player takes their own.
		stop = function()
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
			if bellowsPrompt then
				bellowsPrompt.Enabled = false
			end
			if anvilPrompt then
				anvilPrompt.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return math.min(round - 1, def.rounds), def.rounds
		end,
	}
end

return Forge
