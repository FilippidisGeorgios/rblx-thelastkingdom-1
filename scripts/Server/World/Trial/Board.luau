--!strict
--[[
	Trial task: `board`
	Nail the Great Hall's four doorways shut with the planks you carried from the
	woodyard, before the siege comes.

	  - Each doorway (`BoardPoint`, attribute `Door` 1-4) takes up to six planks,
	    one per hold, built up from the sill. Four close the gap to less than a
	    body's height, so four SEALS a door; the fifth and sixth are strength.
	  - A barricade is a COMBAT ENTITY on the players' side, with `healthPerPlank`
	    health a plank. The dead, whose rule is "go for the nearest thing that is
	    not one of us", go for it. Spearmen thrust at it, archers shoot it,
	    the heavy ones lean on it. When its health is gone it breaks and the way
	    is open; it can be built again.
	  - A door that is not boarded is simply an open door. The siege never waits
	    for this task and nothing depends on it: boarding is what you do with the
	    pause, and the pause is as long as it is.
	  - Two racks of planks stand in the hall for a player who skipped the yard;
	    they hold less than the doors want, on purpose.

	It is a deed for the trial's purposes (it never gates the gate): done when all
	four doors are sealed at once.

	Params (configs/Trials):
	  hall            dotted path of the model that contains the BoardPoints
	  maxPlanks       planks a door takes (6)
	  sealPlanks      planks that seal it (4)
	  healthPerPlank  health of a barricade per plank
	  nailHold        seconds to nail one
	  racks           { { door = n, planks = n } } where plank racks stand, by door

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local TweenService = game:GetService("TweenService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local CombatService = require(script.Parent.Parent.CombatService)
local Util = require(script.Parent.Util)

local Board = {}

local rng = Random.new()
local PLANK_H = 2.3
local PLANK_STEP = 2.18

type Door = {
	index: number,
	part: BasePart,
	centre: Vector3,
	floorY: number,
	thinX: boolean, -- the opening's plane is YZ (it is thin along X)
	width: number,
	planks: number,
	model: Model?,
	entityId: string?,
	prompt: ProximityPrompt?,
}

function Board.create(ctx: any, def: any)
	local doors: { Door } = {}
	local connections: { any } = {}
	local finished = false
	local nextEntity = 0

	local function sealedCount(): number
		local n = 0
		for _, d in doors do
			if d.planks >= def.sealPlanks then
				n += 1
			end
		end
		return n
	end

	local function plankCFrame(d: Door, slot: number): (CFrame, Vector3)
		local y = d.floorY + 1.15 + (slot - 1) * PLANK_STEP
		local jitter = rng:NextNumber(-0.15, 0.15)
		if d.thinX then
			return CFrame.new(d.centre.X + jitter, y, d.centre.Z) * CFrame.Angles(math.rad(rng:NextNumber(-1.2, 1.2)), 0, 0),
				Vector3.new(0.9, PLANK_H, d.width + 1.2)
		end
		return CFrame.new(d.centre.X, y, d.centre.Z + jitter) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-1.2, 1.2))),
			Vector3.new(d.width + 1.2, PLANK_H, 0.9)
	end

	local function breakDoor(d: Door)
		local model = d.model
		if not model then
			return
		end
		d.model = nil
		d.planks = 0
		if d.entityId then
			CombatService.unregisterEntity(d.entityId)
			d.entityId = nil
		end
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				local out = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 2), rng:NextNumber(-3, 3))
				TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = p.CFrame * CFrame.new(out) * CFrame.Angles(math.rad(rng:NextNumber(-60, 60)), math.rad(rng:NextNumber(-30, 30)), math.rad(rng:NextNumber(-60, 60))),
					Transparency = 1,
				}):Play()
			end
		end
		task.delay(1.1, function()
			model:Destroy()
		end)
		ctx.note(("Door %d is broken."):format(d.index), 3)
	end

	local function addPlank(d: Door, player: Player)
		if d.planks >= def.maxPlanks then
			ctx.note("This door is as strong as planks make it.", 2.5)
			return
		end
		if BackpackService.count(player, "plank") <= 0 then
			ctx.note("No planks. The woodyard had some, and the racks in the hall.", 3)
			return
		end
		BackpackService.remove(player, "plank", 1)

		if not d.model then
			local model = Instance.new("Model")
			model.Name = ("Barricade%d"):format(d.index)
			model.Parent = ctx.folder
			d.model = model
		end
		local model = d.model :: Model
		d.planks += 1
		local cf, size = plankCFrame(d, d.planks)
		local p = Instance.new("Part")
		p.Name = "Plank"
		p.Anchored = true
		p.CanCollide = true
		p.Size = size
		p.CFrame = cf
		p.Color = Color3.fromRGB(110 + rng:NextInteger(-10, 10), 82 + rng:NextInteger(-8, 8), 54)
		p.Material = Enum.Material.WoodPlanks
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		-- A nail head at each end, so a plank reads as nailed and not as laid.
		for _, side in { -1, 1 } do
			local off = (size.X > size.Z and size.X or size.Z) / 2 - 0.5
			local nailPos = if d.thinX then Vector3.new(0.5, 0, side * off) else Vector3.new(side * off, 0, 0.5)
			local nail = Instance.new("Part")
			nail.Name = "Nail"
			nail.Anchored = true
			nail.CanCollide = false
			nail.CanQuery = false
			nail.Size = Vector3.new(0.35, 0.35, 0.35)
			nail.Color = Color3.fromRGB(34, 30, 28)
			nail.Material = Enum.Material.Metal
			nail.CFrame = cf * CFrame.new(nailPos)
			nail.Parent = model
		end
		if not model.PrimaryPart then
			model.PrimaryPart = p
		end

		-- The barricade as something the dead can hit.
		if not d.entityId then
			nextEntity += 1
			local id = ("board_%d_%d"):format(d.index, nextEntity)
			local entity = CombatService.registerEntity({
				id = id,
				faction = "Players",
				maxHealth = def.healthPerPlank,
				model = model,
			})
			d.entityId = id
			entity.health.Died:connect(function()
				breakDoor(d)
			end)
			-- Where the dead stand to reach it: a stride off each face.
			local normal = if d.thinX then Vector3.xAxis else Vector3.zAxis
			model:SetAttribute("ApproachA", Vector3.new(d.centre.X, d.floorY + 3, d.centre.Z) + normal * 4)
			model:SetAttribute("ApproachB", Vector3.new(d.centre.X, d.floorY + 3, d.centre.Z) - normal * 4)
		else
			local entity = CombatService.getEntity(d.entityId)
			if entity then
				entity.health.max += def.healthPerPlank
				entity.health.current = math.min(entity.health.max, entity.health.current + def.healthPerPlank)
			end
		end

		if d.planks == def.sealPlanks then
			ctx.note(("Door %d is sealed (%d of %d)."):format(d.index, sealedCount(), #doors), 3)
		else
			ctx.note(("Door %d: %d of %d planks."):format(d.index, d.planks, def.maxPlanks), 2)
		end
		if sealedCount() >= #doors and not finished then
			finished = true
			ctx.note("Every door is barred. Now they can come.", 5)
			ctx.done()
		end
	end

	local function buildRack(at: Vector3, planks: number)
		local model = Instance.new("Model")
		model.Name = "PlankRack"
		model.Parent = ctx.folder
		for row = 1, 3 do
			for col = 1, 2 do
				local p = Instance.new("Part")
				p.Name = "Stacked"
				p.Anchored = true
				p.CanCollide = false
				p.Size = Vector3.new(5.5, 0.45, 1.1)
				p.CFrame = CFrame.new(at + Vector3.new(0, 0.5 + (row - 1) * 0.5, (col - 1.5) * 1.2)) * CFrame.Angles(0, math.rad(rng:NextNumber(-3, 3)), 0)
				p.Color = Color3.fromRGB(104, 78, 52)
				p.Material = Enum.Material.WoodPlanks
				p.Parent = model
			end
		end
		local left = planks
		local prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 2.6, 0), "RackPrompt", "Take planks", ("Planks (%d)"):format(left), 1.2, 11)
		table.insert(
			connections,
			prompt.Triggered:Connect(function(player: Player)
				if left <= 0 then
					return
				end
				local took = BackpackService.add(player, "plank", math.min(left, 8), true)
				if took <= 0 then
					ctx.note("You cannot carry any more planks.", 2.5)
					return
				end
				left -= took
				ctx.note(("%d planks."):format(took), 2)
				if left <= 0 then
					prompt.Enabled = false
					model:Destroy()
				else
					prompt.ObjectText = ("Planks (%d)"):format(left)
				end
			end)
		)
	end

	return {
		start = function()
			local hall = Util.find(def.hall)
			if not hall then
				ctx.warn("board: no hall at " .. tostring(def.hall))
				return
			end
			for _, d in hall:GetDescendants() do
				if d.Name == "BoardPoint" and d:IsA("BasePart") then
					local index = d:GetAttribute("Door")
					local thinX = d.Size.X < d.Size.Z
					local door: Door = {
						index = if typeof(index) == "number" then index else #doors + 1,
						part = d,
						centre = d.Position,
						floorY = d.Position.Y - d.Size.Y / 2,
						thinX = thinX,
						width = if thinX then d.Size.Z else d.Size.X,
						planks = 0,
					}
					table.insert(doors, door)
				end
			end
			table.sort(doors, function(a, b)
				return a.index < b.index
			end)
			if #doors == 0 then
				ctx.warn("board: no BoardPoints in the hall")
				return
			end

			for _, d in doors do
				local lift = Vector3.new(0, -d.part.Size.Y / 2 + 3, 0)
				-- The prompt stands a stride INSIDE the hall (toward its middle), at the sill.
				local hallCentre = hall:GetPivot().Position
				local inward = (Vector3.new(hallCentre.X, d.centre.Y, hallCentre.Z) - d.centre)
				local axis = if d.thinX then Vector3.new(math.sign(inward.X), 0, 0) else Vector3.new(0, 0, math.sign(inward.Z))
				local prompt = Util.prompt(ctx.folder, d.centre + lift + axis * 2.5, "NailPrompt" .. d.index, "Nail a plank", ("Door %d"):format(d.index), def.nailHold, 12)
				d.prompt = prompt
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						addPlank(d, player)
					end)
				)

				for _, rack in def.racks do
					if rack.door == d.index then
						buildRack(d.centre + axis * 8 + (if d.thinX then Vector3.new(0, 0, 5) else Vector3.new(5, 0, 0)) - Vector3.new(0, d.part.Size.Y / 2 - 0.1, 0), rack.planks)
					end
				end
			end
			ctx.note("The doors are open. Board them before they come.", 5)
		end,

		-- Boarding stays possible (and re-boarding) for as long as the trial lives.
		stop = function() end,

		progress = function(): (number, number)
			return sealedCount(), #doors
		end,
	}
end

return Board
