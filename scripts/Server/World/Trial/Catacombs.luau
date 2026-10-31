--!strict
--[[
	Trial task: `catacombs`
	Area 4 (docs/systems/Catacombs.md): a mountain shuts the yard, a table by its cave gives each of the party a lantern, and
	a deep stair goes down to a maze in the dark. This module is what happens there.

	THE SURFACE. The table by the cave: a lantern for each who asks (`LanternService`), and a note left on it.

	THE FOOT OF THE STAIR. When the first of the party reaches the small safe room at the bottom (a crawl is its only way
	out, so the big dead cannot come in), the Catacombs wake: the crawlers go to their niches all over the plan (a fixed
	number, scaled by the party) and the Doctor is put down at the far side (`Trial/Doctor`).

	THE ERRAND, in no fixed order, to get out by the exit road on the far side:
	  - THREE LEVERS in three wings lift the iron gate at the head of the road (each pull is loud);
	  - the AXE (one of three places in the quarry, rolled each run) cuts the fallen beams across the road (eight strokes, every
	    one very loud);
	  - the KEY (one of four places, in the plague ward and the gaol, rolled each run) opens the iron door at the foot of the
	    stair that goes up;
	  - ropes hang in dead ends: each rings a bell in another dead end, far off, for the Doctor to walk to, so a bell is a
	    way to move him (it is also a noise made by a hand at the rope, so it must be done quietly: crouched).
	Then the stair up. The first of the party at the top ends the trial and lifts the yard's gate.

	NOISE. Everything that is loud calls `doctor.hear`: levers, strokes, the key, bells, chests, every blow a player lands and
	every dead one going down (which also plays a sound; the game has no sound files yet, so Roblox's own are used, named in
	`configs/Catacombs.Sounds`).

	Params (configs/Trials): none; all numbers are `configs/Catacombs`, the plan is `configs/CatacombsMaze`.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent.Parent
local CatacombMaze = require(Server.Domain.CatacombMaze)
local EnemyService = require(script.Parent.Parent.EnemyService)
local EnemyAIService = require(script.Parent.Parent.EnemyAIService)
local CombatService = require(script.Parent.Parent.CombatService)
local LootService = require(script.Parent.Parent.LootService)
local BackpackService = require(script.Parent.Parent.BackpackService)
local LanternService = require(script.Parent.Parent.LanternService)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Config = require(ReplicatedStorage.Shared.Config)
local Cue = require(script.Parent.Cue)
local Doctor = require(script.Parent.Doctor)
local Read = require(script.Parent.Read)
local Util = require(script.Parent.Util)

local Catacombs = {}

local rng = Random.new()

local MARKS = "Decorations.Area4.Catacombs.Marks."

-- What a search turns up when it is not what you want.
local DUST = {
	"Bones, and a little dust.",
	"A rotted sack. Nothing.",
	"Cobweb to the elbow, and nothing in it.",
	"Somebody has been here before you.",
	"A tooth. A button. No more.",
	"Rats' work. Nothing left.",
}

local function eased(seconds: number, step: (number) -> ())
	local t = 0
	while t < seconds do
		t += task.wait(0.03)
		local a = math.clamp(t / seconds, 0, 1)
		step(0.5 - math.cos(math.pi * a) / 2)
	end
	step(1)
end

function Catacombs.create(ctx: any, _def: any)
	local cfg = Config.get("Catacombs")
	local plan = Config.get("CatacombsMaze")
	local err = cfg.Errand
	local floorY: number = cfg.Layout.FloorY

	local maze = CatacombMaze.new(plan, cfg.Layout)
	local doctor: any = Doctor.create(ctx, maze, cfg, plan)

	local connections: { RBXScriptConnection } = {}
	local disconnects: { () -> () } = {}
	local prompts: { ProximityPrompt } = {}
	local running = false
	local awake = false -- the foot of the stair has been reached
	local finished = false

	local leversPulled: { [string]: boolean } = {}
	local leverCount = 0
	local gateOpen = false
	local blows = 0
	local barricadeDown = false
	local doorOpen = false
	local keyAt: string = ""
	local axeAt: string = ""
	local keyFound = false
	local axeFound = false
	local crawlers: { string } = {}
	local ropeReady: { [string]: number } = {}

	local function mark(name: string): Instance?
		return Util.find(MARKS .. name)
	end

	local function guard(p: ProximityPrompt, handler: (Player) -> ())
		table.insert(prompts, p)
		table.insert(connections, p.Triggered:Connect(handler))
	end

	local function noise(at: Vector3, loudness: number, kind: string, source: string?)
		doctor.hear(at, loudness, kind, source)
	end

	-- The line at the top of the screen, from what has been done.
	local function describe()
		if not awake then
			ctx.hint(nil)
			return
		end
		if doorOpen then
			ctx.hint("The door is open. Climb the stair, quietly: the way out is up")
		elseif barricadeDown then
			ctx.hint(if keyFound then "The beams are down. Open the iron door with the key" else "The beams are down. Find the key for the iron door")
		elseif gateOpen then
			ctx.hint(
				if axeFound
					then "The gate is open. Cut the fallen beams across the road (every stroke is loud)"
					else "The gate is open. Find an axe for the fallen beams across the road"
			)
		else
			ctx.hint(
				("Find a way out in the dark: levers %d of %d  |  axe %s  |  key %s"):format(
					leverCount,
					err.Levers,
					if axeFound then "found" else "not yet",
					if keyFound then "found" else "not yet"
				)
			)
		end
	end

	--======================================================================
	-- The surface
	--======================================================================
	local function setUpTable()
		local spot = mark("LanternSpot")
		if spot then
			local p = Util.prompt(ctx.folder, Util.position(spot) + Vector3.new(0, 1.2, 0), "LanternPrompt", "Take", "Lantern", err.LanternHold, 10)
			guard(p, function(player: Player)
				if LanternService.give(player) then
					ctx.note(("%s takes a lantern. Keep it: it is the only light."):format(player.Name), 4)
				else
					ctx.note("You already carry a lantern.", 2.5)
				end
			end)
		else
			ctx.warn("catacombs: no LanternSpot (run tools/BuildCatacombs.luau)")
		end
		Read.place(ctx, MARKS .. "EntranceTable", cfg.Entrance.title, cfg.Entrance.sign, function()
			return cfg.Entrance.lines
		end, function() end)
	end

	--======================================================================
	-- The levers, the gate, the beams, the door
	--======================================================================
	local function openGate()
		if gateOpen then
			return
		end
		gateOpen = true
		maze:setShut("gate", false)
		local gate = mark("Gate")
		local at = if gate then Util.position(gate) else Vector3.new(0, floorY, 0)
		ctx.note("Far off, iron groans upward.", 4)
		Cue.play(at, cfg.Sounds.Lever)
		noise(at, cfg.Noise.Bell, "gate")
		if gate and gate:IsA("Model") then
			local home = gate:GetPivot()
			task.spawn(eased, 3.2, function(e: number)
				gate:PivotTo(home + Vector3.new(0, 8.6 * e, 0))
			end)
		end
		describe()
	end

	local function pull(player: Player, id: string)
		if leversPulled[id] or not awake then
			return
		end
		leversPulled[id] = true
		leverCount += 1
		local lever = mark(id)
		local at = if lever then Util.position(lever) else Vector3.zero
		if lever then
			local handle = lever:FindFirstChild("Handle")
			local base = lever:FindFirstChild("Base")
			if handle and handle:IsA("BasePart") and base and base:IsA("BasePart") then
				local length = (handle:GetAttribute("Length") or 3) :: number
				task.spawn(eased, 0.7, function(e: number)
					handle.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(35 - 70 * e)) * CFrame.new(0, length / 2, 0)
				end)
			end
			for _, d in lever:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					d.Enabled = false
				end
			end
		end
		Cue.play(at, cfg.Sounds.Lever)
		noise(at, cfg.Noise.Lever, "lever", tostring(player.UserId))
		ctx.note(("%s pulls a lever. It clanks through the stone."):format(player.Name), 3.5)
		if leverCount >= err.Levers then
			openGate()
		end
		describe()
	end

	local function chop(player: Player)
		if barricadeDown or not gateOpen then
			return
		end
		if BackpackService.count(player, err.AxeItem) <= 0 then
			ctx.note("Beams, rotten and thick. You need something with an edge.", 3.5)
			return
		end
		blows += 1
		local beams = mark("Barricade")
		local at = if beams then Util.position(beams) else Vector3.zero
		Cue.play(at, cfg.Sounds.Chop)
		noise(at, cfg.Noise.Chop, "chop", tostring(player.UserId))
		if beams then
			-- one beam in every few comes away with each stroke
			local pieces = {}
			for _, d in beams:GetChildren() do
				if d:IsA("BasePart") and d.CanCollide then
					table.insert(pieces, d)
				end
			end
			local share = math.max(1, math.floor(#pieces / math.max(err.BarricadeBlows - blows + 1, 1)))
			for i = 1, math.min(share, #pieces) do
				local piece = pieces[rng:NextInteger(1, #pieces)]
				piece.CanCollide = false
				local home = piece.CFrame
				task.spawn(eased, 0.5, function(e: number)
					piece.CFrame = home * CFrame.new(rng:NextNumber(-1, 1) * e, -2.2 * e, rng:NextNumber(-1, 1) * e) * CFrame.Angles(0, 0, math.rad(40 * e))
				end)
			end
		end
		if blows >= err.BarricadeBlows then
			barricadeDown = true
			maze:setShut("barricade", false)
			if beams then
				for _, d in beams:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide = false
					end
				end
			end
			for _, p in prompts do
				if p.Parent and p.Parent.Name == "ChopPrompt" then
					p.Enabled = false
				end
			end
			ctx.note("The last beam gives. The way to the door is open.", 4)
		else
			ctx.note(("Stroke %d of %d."):format(blows, err.BarricadeBlows), 1.5)
		end
		describe()
	end

	local function unlockDoor(player: Player)
		if doorOpen or not barricadeDown then
			return
		end
		if BackpackService.count(player, err.KeyItem) <= 0 then
			ctx.note("A cold iron lock, as old as the door. It wants a key.", 3.5)
			return
		end
		doorOpen = true
		pcall(BackpackService.remove, player, err.KeyItem, 1)
		local door = mark("IronDoor")
		local at = if door then Util.position(door) else Vector3.zero
		Cue.play(at, cfg.Sounds.Lever)
		noise(at, cfg.Noise.Key, "key", tostring(player.UserId))
		ctx.note(("%s turns the key. Cold air, and a stair going up."):format(player.Name), 4)
		if door then
			for _, side in { { "LeafW", 100 }, { "LeafE", -100 } } do
				local leaf = door:FindFirstChild(side[1] :: string)
				if leaf and leaf:IsA("Model") then
					local home = leaf:GetPivot()
					task.spawn(eased, 1.8, function(e: number)
						leaf:PivotTo(home * CFrame.Angles(0, math.rad((side[2] :: number) * e), 0))
					end)
				end
			end
		end
		describe()
	end

	--======================================================================
	-- Searching, ropes, caches
	--======================================================================
	local function makeSearch(id: string, item: string?, label: string)
		local at = mark(id)
		if not at then
			ctx.warn("catacombs: no mark " .. id)
			return
		end
		local done = false
		local p = Util.prompt(ctx.folder, Util.position(at) + Vector3.new(0, 1.6, 0), "Search_" .. id, "Search", label, err.SearchHold, 8)
		p.Enabled = false
		guard(p, function(player: Player)
			if done then
				return
			end
			done = true
			p.Enabled = false
			local where = Util.position(at)
			noise(where, cfg.Noise.Chest, "search", tostring(player.UserId))
			if item then
				BackpackService.add(player, item, 1, true)
				if item == err.KeyItem then
					keyFound = true
					ctx.note(("%s finds a cold iron key."):format(player.Name), 4)
				else
					axeFound = true
					ctx.note(("%s finds a hewing axe."):format(player.Name), 4)
				end
				describe()
			elseif rng:NextNumber() < 0.25 then
				LootService.give(player, "bandage", 1, where + Vector3.new(0, 2, 0))
				ctx.note("A bandage, rolled in a rag.", 2.5)
			else
				ctx.note(DUST[rng:NextInteger(1, #DUST)], 2.5)
			end
		end)
	end

	local function makeRope(id: string, targetId: string)
		local rope = mark(id)
		if not rope then
			return
		end
		local target = mark(targetId)
		local p = Util.prompt(ctx.folder, Util.position(rope) + Vector3.new(0, 1.4, 0), "Rope_" .. id, "Pull", "Rope", err.BellHold, 8)
		p.Enabled = false
		guard(p, function(player: Player)
			local now = os.clock()
			if (ropeReady[id] or 0) > now then
				ctx.note("The rope is still swinging.", 2)
				return
			end
			ropeReady[id] = now + err.BellCooldown
			local at = if target then Util.position(target) else Util.position(rope)
			Cue.play(at, cfg.Sounds.Bell)
			noise(at, cfg.Noise.Bell, "bell", nil)
			-- the hand at the rope is a noise of its own, a quiet one
			noise(Util.position(rope), cfg.Noise.Chest, "rope", tostring(player.UserId))
			ctx.note("Far off, a bell. Something starts to walk toward it.", 4)
			if target and target:IsA("Model") then
				local bell = target:FindFirstChild("Bell")
				if bell and bell:IsA("BasePart") then
					local home = bell.CFrame
					task.spawn(eased, 1.4, function(e: number)
						bell.CFrame = home * CFrame.Angles(0, 0, math.rad(22 * math.sin(e * math.pi * 6) * (1 - e)))
					end)
				end
			end
		end)
	end

	local function makePocket(index: number)
		local chest = mark("pocket" .. index)
		if not chest then
			return
		end
		local done = false
		local p = Util.prompt(ctx.folder, Util.position(chest) + Vector3.new(0, 1.4, 0), "Pocket" .. index, "Open", "Old chest", 1.0, 8)
		guard(p, function(player: Player)
			if done then
				return
			end
			done = true
			p.Enabled = false
			noise(Util.position(chest), cfg.Noise.Chest, "chest", tostring(player.UserId))
			LootService.grant(player, "catacomb_pocket", Util.position(chest) + Vector3.new(0, 2, 0))
			ctx.note("A little left, for whoever hid here.", 2.5)
		end)
	end

	--======================================================================
	-- The foot of the stair: everything wakes
	--======================================================================
	local function spawnCrawlers()
		local s = Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
		local want = math.max(1, math.round(cfg.Crawlers.Count * s.enemyCountMult))
		local nests: { Instance } = {}
		for _, f in plan.Features do
			if f.kind == "nest" then
				local m = mark(f.id)
				if m then
					table.insert(nests, m)
				end
			end
		end
		for i = #nests, 2, -1 do
			local j = rng:NextInteger(1, i)
			nests[i], nests[j] = nests[j], nests[i]
		end
		for i = 1, math.min(want, #nests) do
			local at = Util.position(nests[i])
			local id = EnemyService.spawn("undead_crawler", Vector3.new(at.X, floorY, at.Z), s.enemyHealthMult, floorY)
			table.insert(crawlers, id)
			EnemyAIService.tune(id, { detection = cfg.Crawlers.Detection, leash = 70, spawnPosition = Vector3.new(at.X, floorY, at.Z) })
		end
	end

	local function wake()
		if awake then
			return
		end
		awake = true
		ctx.note("You are down. The dark is complete. Somewhere, something that has been still for years lifts its head.", 6)
		spawnCrawlers()
		local start = mark("DoctorStart")
		local cell: CatacombMaze.Cell? = nil
		if start then
			local p = Util.position(start)
			cell = maze:cellAt(p.X, p.Z)
		end
		if not cell then
			local hall = maze:hall(cfg.Doctor.SpawnHall)
			cell = if hall then { c = hall.c0, r = hall.r0 } else { c = 3, r = 7 }
		end
		doctor.start(cell)
		for _, p in prompts do
			if p.Parent and (string.find(p.Parent.Name, "^Search_") or string.find(p.Parent.Name, "^Rope_")) then
				p.Enabled = true
			end
		end
		describe()
	end

	--======================================================================
	-- Run
	--======================================================================
	local function watchBody()
		local safe = mark("SafeRoom")
		local top = mark("ExitTop")
		local safeAt = if safe then Util.position(safe) else nil
		local topAt = if top then Util.position(top) else nil
		task.spawn(function()
			while running and not finished do
				task.wait(0.5)
				for _, player in Players:GetPlayers() do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						if not awake and safeAt and (root.Position - safeAt).Magnitude < 14 then
							wake()
						end
						if doorOpen and topAt and (root.Position - topAt).Magnitude < 7 then
							finished = true
							ctx.note(("%s is out. The air is cold, and it is moving."):format(player.Name), 5)
							ctx.done()
							return
						end
					end
				end
			end
		end)
	end

	local function listenToBlows()
		-- every blow a player lands, and every dead one going down, is a noise (and the second a sound)
		local d1 = CombatService.DamageDealt:connect(function(result: any)
			if not awake or not result or result.amount <= 0 then
				return
			end
			local source = if result.sourceId then CombatService.getEntity(result.sourceId) else nil
			local target = CombatService.getEntity(result.targetId)
			if source and source.faction == "Players" and target and target.model then
				local at = (target.model :: Model):GetPivot().Position
				if math.abs(at.Y - floorY) < 14 then
					noise(at, cfg.Noise.Hit, "hit", nil)
				end
			end
		end)
		table.insert(disconnects, d1)
		local d2 = CombatService.EntityDied:connect(function(entity: any)
			if not awake or not entity.model then
				return
			end
			local at = (entity.model :: Model):GetPivot().Position
			if math.abs(at.Y - floorY) < 14 and entity.faction == "Enemies" then
				Cue.play(at, cfg.Sounds.Kill)
				noise(at, cfg.Noise.Kill, "kill", nil)
			end
		end)
		table.insert(disconnects, d2)
	end

	return {
		start = function()
			local root = Util.find("Decorations.Area4.Catacombs")
			if not root then
				-- not built yet: never leave the party shut in the yard
				ctx.warn("catacombs: not built (run tools/BuildCatacombs.luau); the gate opens without it")
				ctx.done()
				return
			end
			running = true

			setUpTable()

			-- where the key and the axe lie this run
			keyAt = cfg.Spots.Key[rng:NextInteger(1, #cfg.Spots.Key)]
			axeAt = cfg.Spots.Axe[rng:NextInteger(1, #cfg.Spots.Axe)]
			for _, id in cfg.Spots.Key do
				makeSearch(id, if id == keyAt then err.KeyItem else nil, "Old chest")
			end
			for _, id in cfg.Spots.Axe do
				makeSearch(id, if id == axeAt then err.AxeItem else nil, "Tool rack")
			end

			-- levers
			local n = 0
			for _, f in plan.Features do
				if f.kind == "lever" then
					n += 1
					local lever = mark(f.id)
					if lever then
						local p = Util.prompt(ctx.folder, Util.position(lever) + Vector3.new(0, 1.6, 0), "Lever_" .. f.id, "Pull", "Lever", err.LeverHold, 8)
						local id = f.id
						guard(p, function(player: Player)
							pull(player, id)
						end)
					else
						ctx.warn("catacombs: no lever mark " .. f.id)
					end
				end
			end

			-- the bells: rope i rings the bell at the next-but-one
			local bells = {}
			for _, f in plan.Features do
				if f.kind == "bell" then
					table.insert(bells, f.id)
				end
			end
			for i = 1, #bells do
				makeRope(bells[i], bells[(i + 1) % #bells + 1])
			end

			for i = 1, 7 do
				makePocket(i)
			end

			-- the barricade and the iron door
			local beams = mark("Barricade")
			if beams then
				local p = Util.prompt(ctx.folder, Util.position(beams) + Vector3.new(0, 0.2, 0), "ChopPrompt", "Chop", "Fallen beams", err.BlowHold, 8)
				guard(p, chop)
			end
			local door = mark("IronDoor")
			if door then
				local lock = door:FindFirstChild("Lock")
				local at = if lock then Util.position(lock) else Util.position(door)
				guard(Util.prompt(ctx.folder, at + Vector3.new(0, 0, 0), "DoorPrompt", "Unlock", "Iron door", 1.4, 8), unlockDoor)
			end

			listenToBlows()
			watchBody()
		end,

		stop = function()
			running = false
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			for _, d in disconnects do
				d()
			end
			disconnects = {}
			for _, p in prompts do
				p.Enabled = false
			end
			doctor.stop()
			for _, id in crawlers do
				pcall(EnemyService.despawn, id)
			end
			crawlers = {}
		end,

		progress = function(): (number, number)
			return if finished then 1 else 0, 1
		end,

		--[[
			DEVELOPMENT (a ProximityPrompt cannot be pressed from a script): `TrialService.devHandle(4, "catacombs").dev`.
			  wake()                      as if the first body reached the foot of the stair
			  state()                     what has been done, one line
			  pull(player, id), chop(player), unlock(player)
			  where()                     where the key and the axe lie, the Doctor's state
			  doctor()                    the Doctor's handle
		]]
		dev = {
			wake = wake,
			pull = pull,
			chop = chop,
			unlock = unlockDoor,
			grant = function(player: Player, itemId: string)
				BackpackService.add(player, itemId, 1, true)
			end,
			doctor = function(): any
				return doctor
			end,
			maze = function(): any
				return maze
			end,
			state = function(): string
				return ("awake=%s levers=%d gate=%s blows=%d barricade=%s door=%s key=%s axe=%s crawlers=%d"):format(
					tostring(awake),
					leverCount,
					tostring(gateOpen),
					blows,
					tostring(barricadeDown),
					tostring(doorOpen),
					keyAt,
					axeAt,
					#crawlers
				)
			end,
		},
	}
end

return Catacombs
