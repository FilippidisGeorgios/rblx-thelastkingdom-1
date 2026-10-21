--!strict
--[[
	Trial task: `rescue`
	A villager is tied to a chair in the tavern. Untie him (a held 20 seconds,
	progress kept if you break off, ropes falling away as it goes), and get him
	to the gate alive.

	THE HOLD
	One continuous press, but banked: every second a player has held the prompt is
	kept, summed across players (two people untie him twice as fast: faster,
	never required). The prompt's ring is set to the time that REMAINS at the
	start of each hold, so it never lies about how long is left. It is a held
	interaction because it is meant to be the long, exposed thing in the chamber:
	you stand still in a tavern in the Rows while the dead come.

	THE WALK
	Once free he is a real unit (\`prisoner_villager\`: Players side, a body and
	health, does not fight) that follows the party. The dead target the nearest
	thing that is not one of them, which is now sometimes him. The task is done
	when he stands within \`reach\` studs of the passage out, alive.

	IF HE DIES
	It must never leave the chamber impossible. A second prisoner is found tied
	to the chair after \`respawnDelay\` seconds, and a third; when those are spent
	the Rows give up no one else, the way opens, and the team's bonus is lost
	(\`RunModService\` party flag \`prisonerAlive\` goes false). He keeps walking
	with the party after the gate and the flag follows him: dead at any later
	point, the bonus is gone.

	Params (configs/Trials):
	  chair          dotted path of the chair model (a child \`SeatPoint\`, parts named Rope / Coil)
	  enemy          the configs/Enemies id
	  seconds        total held time to free him
	  reach          studs from the passage that counts as "at the gate"
	  retries        extra prisoners after a death
	  respawnDelay   seconds before the next one is found
	  lines          what he says when freed

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AreaService = require(script.Parent.Parent.AreaService)
local CombatService = require(script.Parent.Parent.CombatService)
local EnemyService = require(script.Parent.Parent.EnemyService)
local RunModService = require(script.Parent.Parent.RunModService)
local Place = require(script.Parent.Place)
local Util = require(script.Parent.Util)

local Rescue = {}

local RINGS = 3
local rng = Random.new()

local function ropeRing(parent: Instance, centre: Vector3, y: number): { Part }
	local pieces: { Part } = {}
	for i = 0, 7 do
		local a = i * math.pi / 4
		local seg = Instance.new("Part")
		seg.Name = "Cord"
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.Size = Vector3.new(1.05, 0.24, 0.24)
		seg.Color = Color3.fromRGB(150, 126, 88)
		seg.Material = Enum.Material.Fabric
		seg.CFrame = CFrame.new(centre.X + math.cos(a) * 1.18, y + rng:NextNumber(-0.06, 0.06), centre.Z + math.sin(a) * 1.18) * CFrame.Angles(0, -a + math.pi / 2, 0)
		seg.Parent = parent
		table.insert(pieces, seg)
	end
	return pieces
end

function Rescue.create(ctx: any, def: any)
	local banked = 0
	local holds: { [Player]: number } = {}
	local prompt: ProximityPrompt? = nil
	local captive: Model? = nil
	local rings: { { Part } } = {}
	local chairRopes: { { part: BasePart, original: number } } = {}
	local seatPos = Vector3.zero
	local feetY = 0
	local facing = Vector3.zero

	local freed = false
	local finished = false
	local retriesLeft: number = def.retries
	local entityId: string? = nil
	local watching = false
	local ticker: RBXScriptConnection? = nil
	local diedConnection: any = nil

	local function progress(): number
		local total = banked
		local now = os.clock()
		for _, startedAt in holds do
			total += now - startedAt
		end
		return total
	end

	local function paintRopes()
		local fraction = progress() / def.seconds
		for i, ring in rings do
			local gone = fraction >= i / RINGS
			for _, seg in ring do
				seg.Transparency = if gone then 1 else 0
			end
		end
		for _, r in chairRopes do
			r.part.Transparency = if fraction >= 0.5 then 1 else r.original
		end
	end

	local function clearCaptive()
		if captive then
			captive:Destroy()
			captive = nil
		end
		for _, ring in rings do
			for _, seg in ring do
				seg:Destroy()
			end
		end
		rings = {}
	end

	local function spawnCaptive()
		banked = 0
		holds = {}
		freed = false
		-- Behind the chair, bound to its back: standing, since a sitting clip does not exist yet.
		local at = seatPos + Vector3.new(0, 0, 0) - facing * 0.9
		captive = EnemyService.spawnStatic(def.enemy, Vector3.new(at.X, feetY, at.Z), at + facing * 10, feetY)
		for i = 1, RINGS do
			table.insert(rings, ropeRing(ctx.folder, at, feetY + 1.2 + (i - 1) * 1.45))
		end
		for _, r in chairRopes do
			r.part.Transparency = r.original
		end
		if prompt then
			prompt.HoldDuration = def.seconds
			prompt.ObjectText = "The prisoner - bound"
			prompt.Enabled = true
		end
		paintRopes()
	end

	local function onSuccess()
		finished = true
		RunModService.setFlag("prisonerAlive", true)
		ctx.hint(nil)
		ctx.note("He is through the gate road alive. He will remember it, and so will the Rows.", 5)
		ctx.done()
	end

	local function onDeath()
		entityId = nil
		if finished then
			-- Dead after the gate: the bonus goes, the chamber is long done.
			RunModService.setFlag("prisonerAlive", false)
			ctx.note("The prisoner is dead.", 4)
			return
		end
		ctx.note("He is dead.", 4)
		if retriesLeft > 0 then
			retriesLeft -= 1
			ctx.hint("Free the prisoner")
			task.delay(def.respawnDelay, function()
				if finished then
					return
				end
				ctx.note("Another voice, from the cellar stair: someone else was kept. The chair is tied again.", 5)
				spawnCaptive()
			end)
		else
			finished = true
			RunModService.setFlag("prisonerAlive", false)
			ctx.hint(nil)
			ctx.note("The Rows give up no one else. The way is open, and the price is paid.", 6)
			ctx.done()
		end
	end

	local function free()
		if freed then
			return
		end
		freed = true
		-- He steps out in FRONT of the chair: standing in it, its legs and back would hold him fast (the AI will not take a step into a solid thing).
		local from = seatPos + facing * 3.4
		-- ...and not into a stair or a table: the first of eight places round the chair with room for a body.
		for i = 0, 7 do
			local turned = CFrame.Angles(0, i * math.pi / 4, 0) * facing
			local candidate = Vector3.new(seatPos.X, feetY, seatPos.Z) + turned * 3.4
			if Place.isClear(candidate, 1.5, { ctx.folder }) then
				from = candidate
				break
			end
		end
		clearCaptive()
		if prompt then
			prompt.Enabled = false
		end
		for _, r in chairRopes do
			r.part.Transparency = 1
		end
		local id = EnemyService.spawn(def.enemy, Vector3.new(from.X, feetY, from.Z), nil, feetY)
		entityId = id
		RunModService.setFlag("prisonerAlive", true)
		ctx.hint("Get him to the gate alive")
		local line = def.lines[math.random(#def.lines)]
		ctx.note(line, 6)
		if diedConnection then
			diedConnection()
		end
		diedConnection = CombatService.EntityDied:connect(function(entity: any)
			if entity.id == entityId then
				onDeath()
			end
		end)
		watching = true
	end

	return {
		start = function()
			local chair = Util.find(def.chair)
			if not chair then
				ctx.warn("rescue: no chair at " .. tostring(def.chair))
				return
			end
			local seat = chair:FindFirstChild("SeatPoint", true)
			seatPos = if seat and seat:IsA("BasePart") then seat.Position else Util.position(chair)
			-- The floor is the underside of the chair: a ray from above would find the roof.
			local chairBox, chairSize
			if chair:IsA("Model") then
				chairBox, chairSize = chair:GetBoundingBox()
			end
			feetY = if chairBox then chairBox.Position.Y - chairSize.Y / 2 + 0.05 else seatPos.Y - 2.5
			-- The chair faces the way its seat part's front faces; the prisoner looks out the same way.
			local look = if seat and seat:IsA("BasePart") then seat.CFrame.LookVector else Vector3.new(0, 0, 1)
			facing = Vector3.new(look.X, 0, look.Z)
			if facing.Magnitude < 0.1 then
				facing = Vector3.new(0, 0, 1)
			end
			facing = facing.Unit

			for _, d in chair:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "Rope" or d.Name == "Coil") then
					table.insert(chairRopes, { part = d, original = d.Transparency })
				end
			end

			prompt = Util.prompt(ctx.folder, Vector3.new(seatPos.X, feetY + 3, seatPos.Z) + facing * 2.2, "UntiePrompt", "Untie him", "The prisoner - bound", def.seconds, 11)
			local p = prompt :: ProximityPrompt
			p.PromptButtonHoldBegan:Connect(function(player: Player)
				holds[player] = os.clock()
			end)
			p.PromptButtonHoldEnded:Connect(function(player: Player)
				local startedAt = holds[player]
				if startedAt then
					banked += os.clock() - startedAt
					holds[player] = nil
				end
				if not freed then
					p.HoldDuration = math.max(0.6, def.seconds - banked)
					local left = math.max(0, math.ceil(def.seconds - banked))
					p.ObjectText = if banked > 0.5 then ("The prisoner - %ds more"):format(left) else "The prisoner - bound"
				end
			end)
			p.Triggered:Connect(function()
				free()
			end)
			Players.PlayerRemoving:Connect(function(player)
				holds[player] = nil
			end)

			spawnCaptive()
			ctx.hint("Free the prisoner in the tavern")

			ticker = RunService.Heartbeat:Connect(function()
				if not freed and not finished then
					paintRopes()
					if progress() >= def.seconds then
						free()
					end
				end
				if watching and entityId and not finished then
					local entity = CombatService.getEntity(entityId)
					local model = entity and entity.model
					if model and entity and entity:isAlive() then
						local gate = AreaService.passageOf(ctx.area)
						local pos = model:GetPivot().Position
						if Vector3.new(pos.X - gate.X, 0, pos.Z - gate.Z).Magnitude <= def.reach then
							watching = false
							onSuccess()
						end
					end
				end
			end)
		end,

		stop = function()
			-- The task is done (or the trial over): he stays alive and keeps following; only the chair is finished with.
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
			if prompt then
				prompt.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return math.floor(progress()), def.seconds
		end,
	}
end

return Rescue
