--!strict
--[[
	Trial deed: `cellar`
	The Kitchens' cellar: find the key, go down, crawl, and take what is at the end, if you dare.
	An optional task: the gate never waits for it, and it never leaves the offer.

	THE CELLAR itself is built by `tools/BuildCellar.luau` under Decorations.Area3.Cellar: a stair beside the kitchen
	hall, a locked door at its foot, a larder, a LOW passage you must crouch through (3.4 studs: `configs/Crouch`), and a
	flooded vault under the Dairy with a hoard on a dais. This module is what happens in it.

	THE ERRAND, in order:
	  1. SEARCH. A few of the kitchen yard's buildings (`places`) each have something lying near them (a sack, a crock, a
	     bucket, a cask) that can be searched: hold the prompt. Which ones exist and which holds the KEY are rolled each
	     run, so it is a different errand every time. Some of the rest hold a bandage, most hold nothing: the first
	     lesson of searching is that you are often wrong.
	  2. THE DOOR. At the foot of the stair. Locked until someone has found the key; then any hand can turn it (a
	     solo player does everything alone, as the law of the game says). The leaves swing in.
	  3. THE LARDER. A chest, and a few lines of what the cook kept. The ordinary reward.
	  4. THE CRAWL. Nothing to code: the passage is low, so a standing player does not fit, and the dark (a light zone)
	     and the stone do the rest.
	  5. THE HOARD. At the far end, on a dais, in a flooded vault. Lifting the lid wakes the floor: the dead dig up
	     through three mounds, BEHIND you as much as in front. When the last is down, the hoard's prize is dropped for
	     everyone and the deed is done.

	Co-op: the crawlers scale with the party and the depth like every wave (Scaling). More hands search faster.

	Params (configs/Trials):
	  root          dotted path of the built cellar
	  places        dotted paths of the yard's buildings the search spots are placed near
	  searches      how many spots exist this run (one holds the key)
	  radius        how far from its building a spot may be
	  searchHold    seconds to hold
	  crawlers      the dead that dig up (before the party and depth curves)
	  larderPrize   a configs/Loot table for the larder chest
	  prize         a configs/Loot table for the hoard

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local LootService = require(script.Parent.Parent.LootService)
local BackpackService = require(script.Parent.Parent.BackpackService)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Gather = require(script.Parent.Gather)
local Place = require(script.Parent.Place)
local Util = require(script.Parent.Util)

local Cellar = {}

local rng = Random.new()

-- What a search turns up when it is not the key.
local DUST = {
	"Nothing here but dust.",
	"Mouse droppings and a bent nail.",
	"Rotten, all of it.",
	"An empty clay lamp.",
	"A rag, stiff with age.",
	"Nothing. Somebody has been here before you.",
}

-- What a spot looks like: the builder (from the Kitchens' props) and what the prompt calls it.
local KINDS = {
	{ build = "sack", name = "Sack" },
	{ build = "crock", name = "Old crock" },
	{ build = "bucket", name = "Bucket" },
	{ build = "cask", name = "Cask" },
}

-- The scenery as it was built, remembered the first time it is seen, so a second run in one server starts closed.
local closedPivot: { [Instance]: CFrame } = {}

local function remember(i: Instance)
	if closedPivot[i] == nil then
		if i:IsA("Model") then
			closedPivot[i] = i:GetPivot()
		elseif i:IsA("BasePart") then
			closedPivot[i] = i.CFrame
		end
	end
end

local function restore(i: Instance)
	local cf = closedPivot[i]
	if cf then
		if i:IsA("Model") then
			i:PivotTo(cf)
		elseif i:IsA("BasePart") then
			i.CFrame = cf
		end
	end
end

local function eased(seconds: number, step: (number) -> ())
	local t = 0
	while t < seconds do
		t += task.wait(0.03)
		local a = math.clamp(t / seconds, 0, 1)
		step(0.5 - math.cos(math.pi * a) / 2)
	end
	step(1)
end

-- A hinged lid: turned about the back top edge of the chest's body, up by `degrees`.
local function openLid(chest: Instance, degrees: number)
	local body = chest:FindFirstChild("Body")
	local lid = chest:FindFirstChild("Lid")
	if not (body and body:IsA("BasePart") and lid and lid:IsA("BasePart")) then
		return
	end
	remember(lid)
	local closed = closedPivot[lid] :: CFrame
	local hinge = body.CFrame * CFrame.new(0, 0.85, -1.15)
	task.spawn(eased, 0.6, function(e: number)
		lid.CFrame = hinge * CFrame.Angles(math.rad(-degrees * e), 0, 0) * hinge:Inverse() * closed
	end)
end

local function glow(adornee: Instance)
	local h = Instance.new("Highlight")
	h.Name = "Glow"
	h.FillColor = Color3.fromRGB(232, 216, 182)
	h.FillTransparency = 0.9
	h.OutlineColor = Color3.fromRGB(240, 230, 206)
	h.OutlineTransparency = 0.9
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = adornee
	h.Parent = adornee
	TweenService:Create(h, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.96 }):Play()
end

function Cellar.create(ctx: any, def: any)
	local connections: { RBXScriptConnection } = {}
	local prompts: { ProximityPrompt } = {}
	local running = false
	local hasKey = false
	local keyHolder: Player? = nil
	local opened = false
	local larderTaken = false
	local hoardTaken = false
	local remaining = 0
	local alive: { [string]: boolean } = {}
	local diedConnection: any = nil

	local root: Instance? = nil
	local spotsMade: { any } = {}

	local function sub(path: string): Instance?
		return if root then root:FindFirstChild(path, true) else nil
	end

	local function guard(p: ProximityPrompt, handler: (Player) -> ())
		table.insert(prompts, p)
		table.insert(connections, p.Triggered:Connect(handler))
	end

	local function award()
		local hoard = sub("Hoard")
		local at = if hoard then Util.position(hoard) else Vector3.zero
		LootService.grantAll(def.prize, at + Vector3.new(0, 3, 0))
		ctx.note("The floor is still. Something was left here for you.", 4)
		ctx.done()
	end

	local function wake()
		local s = Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
		local count = math.max(1, math.round(def.crawlers * s.enemyCountMult))
		remaining = count
		diedConnection = CombatService.EntityDied:connect(function(entity: any)
			if alive[entity.id] then
				alive[entity.id] = nil
				remaining -= 1
				if remaining <= 0 then
					if diedConnection then
						diedConnection()
						diedConnection = nil
					end
					award()
				end
			end
		end)

		local burrows = sub("Burrows")
		local mounds = if burrows then burrows:GetChildren() else {}
		task.spawn(function()
			ctx.note("The floor groans.", 3)
			task.wait(1.2)
			for i = 1, count do
				local mound = mounds[(i - 1) % math.max(#mounds, 1) + 1]
				local pit = mound and mound:FindFirstChild("Pit")
				local at = if pit and pit:IsA("BasePart") then pit.Position else Vector3.zero
				-- the rubble heaves up and over: the picture of the dead coming through
				if mound then
					for _, r in mound:GetChildren() do
						if r.Name == "Rubble" and r:IsA("BasePart") then
							remember(r)
							local home = closedPivot[r] :: CFrame
							local away = (r.Position - at) * Vector3.new(1, 0, 1)
							task.spawn(eased, 0.5, function(e: number)
								r.CFrame = home + away.Unit * 1.4 * e + Vector3.new(0, 0.9 * math.sin(e * math.pi), 0)
							end)
						end
					end
				end
				local id = EnemyService.spawn("undead_crawler", at, s.enemyHealthMult, at.Y)
				alive[id] = true
				task.wait(0.9)
			end
		end)
	end

	local function openHoard(player: Player)
		if hoardTaken or not opened then
			return
		end
		hoardTaken = true
		local hoard = sub("Hoard")
		if hoard then
			openLid(hoard, 100)
		end
		ctx.note(("%s lifts the lid."):format(player.Name), 3)
		wake()
	end

	local function openLarder(player: Player)
		if larderTaken or not opened then
			return
		end
		larderTaken = true
		local chest = sub("Chest")
		if chest then
			openLid(chest, 100)
		end
		LootService.grantAll(def.larderPrize, (if chest then Util.position(chest) else Vector3.zero) + Vector3.new(0, 3, 0))
		ctx.note("The cook kept a few things.", 3)
	end

	local function unlock(player: Player)
		if opened then
			return
		end
		if not hasKey then
			ctx.note("The door is locked. The key must be somewhere in the yard.", 3.5)
			return
		end
		opened = true
		if keyHolder then
			pcall(BackpackService.remove, keyHolder, "cellar_key", 1)
		end
		ctx.note(("%s turns the key. Cold air comes up."):format(player.Name), 3.5)
		local door = sub("Door")
		if door then
			local lock = door:FindFirstChild("Lock")
			if lock then
				for _, p in lock:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = 1
					end
				end
			end
			for _, side in { { "LeafW", 100 }, { "LeafE", -100 } } do
				local leaf = door:FindFirstChild(side[1] :: string)
				if leaf and leaf:IsA("Model") then
					remember(leaf)
					local home = closedPivot[leaf] :: CFrame
					task.spawn(eased, 1.6, function(e: number)
						leaf:PivotTo(home * CFrame.Angles(0, math.rad((side[2] :: number) * e), 0))
					end)
				end
			end
		end
		-- the rest of the cellar can be searched now
		for _, p in prompts do
			local anchor = p.Parent
			if anchor and (anchor.Name == "LarderPrompt" or anchor.Name == "HoardPrompt") then
				p.Enabled = true
			end
		end
	end

	local function foundKey(player: Player)
		hasKey = true
		keyHolder = player
		BackpackService.add(player, "cellar_key", 1, true)
		ctx.note(("%s found a key, cold and heavy. It must open the cellar door."):format(player.Name), 4.5)
	end

	-- one searchable spot near a building of the yard; the key is put in one of the spots that were really made
	type Spot = { at: Vector3, holdsKey: boolean, search: (Player) -> () }
	local function makeSpot(placeName: string, avoid: { Vector3 }): Spot?
		local scenery = Util.find(placeName)
		if not scenery then
			ctx.warn("cellar: no scenery at " .. placeName)
			return nil
		end
		local centre = Util.position(scenery)
		local zone = { x0 = centre.X - def.radius, x1 = centre.X + def.radius, z0 = centre.Z - def.radius, z1 = centre.Z + def.radius }
		local spots = Place.find(zone, 1, 3, 9, avoid, { ctx.folder }, rng)
		local at = spots[1]
		if not at then
			ctx.warn("cellar: no clear ground near " .. placeName)
			return nil
		end

		local kind = KINDS[rng:NextInteger(1, #KINDS)]
		local model = Instance.new("Model")
		model.Name = "SearchSpot"
		model.Parent = ctx.folder
		local build = Gather.BUILDERS[kind.build]
		build(model, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		glow(model)

		local spot: Spot = { at = at, holdsKey = false, search = function(_: Player) end }
		local prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 2.2, 0), "Search", "Search", kind.name, def.searchHold, 9)
		local done = false
		spot.search = function(player: Player)
			if done then
				return
			end
			done = true
			prompt.Enabled = false
			if spot.holdsKey then
				foundKey(player)
			elseif rng:NextNumber() < 0.3 then
				LootService.give(player, "bandage", 1, at + Vector3.new(0, 2, 0))
				ctx.note("A bandage, rolled up in a rag.", 2.5)
			else
				ctx.note(DUST[rng:NextInteger(1, #DUST)], 2.5)
			end
		end
		guard(prompt, spot.search)
		return spot
	end

	local function nearAnnouncer()
		local top = sub("Top")
		if not top then
			return
		end
		local at = Util.position(top)
		local told = false
		task.spawn(function()
			while running and not told do
				task.wait(1.5)
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					if rootPart and rootPart:IsA("BasePart") then
						local d = Vector2.new(rootPart.Position.X - at.X, rootPart.Position.Z - at.Z).Magnitude
						if d < 34 and not opened then
							told = true
							ctx.note("A stair goes down beside the kitchen. At its foot, a door that wants a key.", 5)
							break
						end
					end
				end
			end
		end)
	end

	return {
		start = function()
			root = Util.find(def.root)
			if not root then
				ctx.warn("cellar: not built at " .. tostring(def.root) .. " (run tools/BuildCellar.luau)")
				return
			end
			running = true

			-- everything back as it was built, in case this is a second run in the same server
			local door = sub("Door")
			if door then
				for _, name in { "LeafW", "LeafE" } do
					local leaf = door:FindFirstChild(name)
					if leaf then
						remember(leaf)
						restore(leaf)
					end
				end
				local lock = door:FindFirstChild("Lock")
				if lock then
					for _, p in lock:GetDescendants() do
						if p:IsA("BasePart") then
							p.Transparency = 0
						end
					end
				end
			end
			for _, name in { "Chest", "Hoard" } do
				local chest = sub(name)
				local lid = chest and chest:FindFirstChild("Lid")
				if lid then
					remember(lid)
					restore(lid)
				end
			end
			local burrows = sub("Burrows")
			if burrows then
				for _, d in burrows:GetDescendants() do
					if d.Name == "Rubble" and d:IsA("BasePart") then
						remember(d)
						restore(d)
					end
				end
			end

			-- the search: some of the yard's buildings each get a spot; one holds the key
			local places: { string } = table.clone(def.places)
			for i = #places, 2, -1 do
				local j = rng:NextInteger(1, i)
				places[i], places[j] = places[j], places[i]
			end
			local avoid: { Vector3 } = {}
			local made: { Spot } = {}
			for i = 1, math.min(def.searches, #places) do
				local spot = makeSpot(places[i], avoid)
				if spot then
					table.insert(made, spot)
					table.insert(avoid, spot.at)
				end
			end
			spotsMade = made
			if #made > 0 then
				made[rng:NextInteger(1, #made)].holdsKey = true
			else
				-- nowhere to put a single spot: do not leave the door locked for ever
				ctx.warn("cellar: no search spot could be placed; the door opens without a key")
				hasKey = true
			end

			-- the door at the foot of the stair
			local lock = door and door:FindFirstChild("Lock")
			if lock then
				local doorAt = Util.position(lock)
				guard(Util.prompt(ctx.folder, doorAt + Vector3.new(0, -0.6, 1.4), "DoorPrompt", "Unlock", "Cellar door", 1.4, 9), unlock)
			end

			-- the larder's chest and the hoard stay shut until the door is open
			local chest = sub("Chest")
			if chest then
				local p = Util.prompt(ctx.folder, Util.position(chest) + Vector3.new(0, 1.8, 0), "LarderPrompt", "Open", "Larder chest", 1.1, 8)
				p.Enabled = false
				guard(p, openLarder)
			end
			local hoard = sub("Hoard")
			if hoard then
				local p = Util.prompt(ctx.folder, Util.position(hoard) + Vector3.new(0, 1.8, 0), "HoardPrompt", "Lift the lid", "Old chest", 1.8, 8)
				p.Enabled = false
				guard(p, openHoard)
			end

			nearAnnouncer()
		end,

		stop = function()
			running = false
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			for _, p in prompts do
				p.Enabled = false
			end
			if diedConnection then
				diedConnection()
				diedConnection = nil
			end
		end,

		progress = function(): (number, number)
			return if hoardTaken and remaining <= 0 then 1 else 0, 1
		end,

		--[[
			DEVELOPMENT: the same things a player's hands do, without hands (a ProximityPrompt cannot be pressed from
			a script: it needs a rendering client). `TrialService.devHandle(3, "cellar").dev`.
			  spots()                       the search spots, each { at, holdsKey, search(player) }
			  unlock(player), larder(player), hoard(player)
		]]
		dev = {
			spots = function(): { any }
				return spotsMade
			end,
			unlock = unlock,
			larder = openLarder,
			hoard = openHoard,
		},
	}
end

return Cellar
