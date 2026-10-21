--!strict
--[[
	LootService
	Turns a death (or a task's prize) into things lying on the floor that belong
	to a player, and walks them into that player's backpack.

	The roll is the pure `Domain/LootTable`; the tables are `configs/Loot`; the
	pack is `BackpackService`. This is the glue and the picture.

	--------------------------------------------------------------------------
	LOOT IS PERSONAL  (docs/systems/Spoils.md §8)

	A kill is rolled once FOR EACH PLAYER within `Rules.Radius`, and every drop
	is stamped with its owner. The part exists for everyone (the server owns it)
	but each client hides what is not theirs (LootController), so nobody sees,
	races for or steals another player's find. A player in a doorway is not
	robbed by a faster one; five players do not split one Hallowed Ember, they
	each had their own chance at one.

	--------------------------------------------------------------------------
	PICKING UP

	No prompt, no key. Within MAGNET_RADIUS the drop slides to its owner and is
	taken at TAKE_RADIUS. A full pack leaves the drop where it is (and says so,
	rarely): you never lose a find to a crowded pack, you come back for it
	before it fades (`Rules.PickupSeconds`).

	--------------------------------------------------------------------------
	WHAT IT DOES NOT DO

	It does not decide what a chamber awards for a task: tasks call
	`LootService.grant(player, tableId, at)` with a table id from configs/Loot
	(`deed_*`, `cache_*`), or `LootService.give(player, itemId, count, at)` for a
	fixed prize.

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local LootTable = require(Server.Domain.LootTable)
local GameService = require(Server.Services.GameService)
local CombatService = require(script.Parent.CombatService)
local BackpackService = require(script.Parent.BackpackService)
local AreaService = require(script.Parent.AreaService)
local Net = require(ReplicatedStorage.Shared.Net)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local LootService = {}

LootService.Name = "LootService"

local log = Logger.new("LootService")

local TAG = "TLK_Pickup"

local TICK = 0.1
local MAGNET_RADIUS = 9
local TAKE_RADIUS = 3
local PACK_FULL_COOLDOWN = 4

type Pickup = {
	part: BasePart,
	owner: Player,
	item: string?, -- nil = gold
	count: number,
	born: number,
	landed: boolean,
	moving: boolean,
}

local pickups: { Pickup } = {}
local pity: { [Player]: LootTable.Pity } = {}
local lastFull: { [Player]: number } = {}
local folder: Folder? = nil
local rng = Random.new()
local backpackEvent: RemoteEvent? = nil

--==========================================================================
-- Looks
--==========================================================================

local function coinLook(amount: number)
	-- A few coins, a purse, a bar: the size of the pile tells the size of the find.
	if amount >= 25 then
		return {
			Shape = "Bar",
			Size = Vector3.new(0.9, 0.34, 0.45),
			Colour = Color3.fromRGB(226, 182, 74),
			Material = Enum.Material.Metal,
			Glow = true,
		}
	elseif amount >= 8 then
		return {
			Shape = "Ball",
			Size = Vector3.new(0.75, 0.7, 0.75),
			Colour = Color3.fromRGB(150, 112, 56),
			Material = Enum.Material.Fabric,
			Glow = false,
		}
	end
	return {
		Shape = "Disc",
		Size = Vector3.new(0.14, 0.62, 0.62),
		Colour = Color3.fromRGB(226, 182, 74),
		Material = Enum.Material.Metal,
		Glow = false,
	}
end

local function sparkle(parent: BasePart, colour: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Glint"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.7, 1.3)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(colour)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
end

local function buildPart(itemId: string?, amount: number, rank: string): BasePart
	local look
	if itemId == nil then
		look = coinLook(amount)
	else
		local def = Config.get("Items")[itemId]
		look = def and def.Look
		if not look then
			look = {
				Shape = "Block",
				Size = Vector3.new(0.6, 0.6, 0.6),
				Colour = Color3.fromRGB(200, 190, 170),
				Material = Enum.Material.SmoothPlastic,
				Glow = false,
			}
		end
	end

	local part = Instance.new("Part")
	part.Name = if itemId then itemId else "gold"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = look.Size
	part.Color = look.Colour
	part.Material = look.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if look.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif look.Shape == "Disc" then
		part.Shape = Enum.PartType.Cylinder
	end

	local ranks = Config.get("Loot").Ranks
	local rankDef = ranks[rank] or ranks.Worn
	if rankDef.Glow >= 1 or look.Glow then
		sparkle(part, rankDef.Colour, 4 + rankDef.Glow * 5, 0.28 + rankDef.Glow * 0.08)
	else
		sparkle(part, Color3.fromRGB(235, 226, 200), 1.2, 0.16)
	end
	return part
end

--==========================================================================
-- Placing
--==========================================================================

local function floorUnder(at: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -24, 0), params)
	if hit then
		return hit.Position.Y
	end
	return at.Y - 2.5
end

local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	if folder then
		table.insert(list, folder)
	end
	return list
end

local function trim()
	local max = Config.get("Loot").Rules.MaxPickups
	while #pickups > max do
		local oldest = table.remove(pickups, 1)
		if oldest then
			oldest.part:Destroy()
		end
	end
end

local function spawnPickup(player: Player, itemId: string?, count: number, rank: string, from: Vector3)
	local root = folder
	if not root then
		return
	end
	local part = buildPart(itemId, count, rank)
	part:SetAttribute("Owner", player.UserId)
	part:SetAttribute("Rank", rank)

	local ignore = characters()
	local angle = rng:NextNumber(0, math.pi * 2)
	local reach = rng:NextNumber(1.8, 4.6)
	local flat = from + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
	local floorY = floorUnder(flat, ignore)
	local rest = Vector3.new(flat.X, floorY + part.Size.Y / 2 + 0.25, flat.Z)
	local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	-- A cylinder's axis is its local X: stand a coin on its edge by laying it flat.
	local lay = if part.Shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity

	part.CFrame = CFrame.new(from + Vector3.new(0, 1.5, 0)) * spin * lay
	part.Parent = root
	CollectionService:AddTag(part, TAG)

	local record: Pickup = {
		part = part,
		owner = player,
		item = itemId,
		count = count,
		born = os.clock(),
		landed = false,
		moving = false,
	}
	table.insert(pickups, record)
	trim()

	-- Up, then down onto the floor: a pop rather than a teleport.
	local peak = (from + rest) / 2 + Vector3.new(0, 2.2, 0)
	local up = TweenService:Create(part, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(peak) * spin * lay,
	})
	local down = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(rest) * spin * lay,
	})
	up.Completed:Connect(function()
		if part.Parent then
			down:Play()
		end
	end)
	down.Completed:Connect(function()
		record.landed = true
	end)
	up:Play()
end

--==========================================================================
-- Rolling
--==========================================================================

local function playerPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root.Position
	end
	return nil
end

local function pityOf(player: Player): LootTable.Pity
	local state = pity[player]
	if not state then
		state = LootTable.newPity()
		pity[player] = state
	end
	return state
end

local function goldMultFor(playerCount: number): number
	return Scaling.forPlayers(playerCount).rewardMult
end

--[[
	Rolls table `tableId` for `player` and lays what falls round `at`. `usePity`
	is for kills (a stream of them); a container or a prize is a one-off and does
	not feed the counters.
]]
local function award(player: Player, tableId: string, at: Vector3, usePity: boolean)
	local loot = Config.get("Loot")
	local def = loot.Tables[tableId]
	if not def then
		return
	end

	local depth = AreaService.areaOf(player) or 1
	local drops = LootTable.roll(def, Config.get("Items"), loot.Rules, rng, {
		depth = depth,
		goldMult = goldMultFor(#Players:GetPlayers()),
		pity = if usePity then pityOf(player) else nil,
	})
	for _, drop in drops do
		spawnPickup(player, drop.item, drop.count, drop.rank, at)
	end
end

local function onDied(entity: any)
	if entity.faction ~= "Enemies" then
		return
	end
	local model = entity.model
	if not (model and model:IsA("Model")) then
		return
	end
	local enemyId = model:GetAttribute("EnemyId")
	if typeof(enemyId) ~= "string" then
		return
	end
	local at = model:GetPivot().Position
	local radius = Config.get("Loot").Rules.Radius
	for _, player in Players:GetPlayers() do
		local here = playerPosition(player)
		if here and (here - at).Magnitude <= radius then
			award(player, enemyId, at, true)
		end
	end
end

--==========================================================================
-- API — tasks call these
--==========================================================================

-- Rolls `tableId` for `player` and drops it at `at` (a cache, a deed prize).
function LootService.grant(player: Player, tableId: string, at: Vector3)
	award(player, tableId, at, false)
end

-- Rolls `tableId` for every player in the party.
function LootService.grantAll(tableId: string, at: Vector3)
	for _, player in Players:GetPlayers() do
		award(player, tableId, at, false)
	end
end

-- A fixed prize: `count` of `itemId`, dropped at `at` for `player`.
function LootService.give(player: Player, itemId: string, count: number, at: Vector3)
	local item = Config.get("Items")[itemId]
	spawnPickup(player, itemId, count, if item and item.Rank then item.Rank else "Worn", at)
end

function LootService.giveGold(player: Player, amount: number, at: Vector3)
	spawnPickup(player, nil, amount, "Worn", at)
end

--==========================================================================
-- Collecting
--==========================================================================

local function tellFull(player: Player)
	local now = os.clock()
	if (lastFull[player] or -1e9) + PACK_FULL_COOLDOWN > now then
		return
	end
	lastFull[player] = now
	if backpackEvent then
		backpackEvent:FireClient(player, { kind = "full" })
	end
end

local function collect(record: Pickup): boolean
	local player = record.owner
	if record.item == nil then
		BackpackService.addGold(player, record.count)
		return true
	end
	local taken = BackpackService.add(player, record.item, record.count)
	if taken >= record.count then
		return true
	end
	record.count -= taken
	tellFull(player)
	return false
end

local function step()
	local now = os.clock()
	local lifetime = Config.get("Loot").Rules.PickupSeconds
	local i = 1
	while i <= #pickups do
		local record = pickups[i]
		local part = record.part
		local gone = false

		if not part.Parent or not record.owner.Parent then
			gone = true
		elseif now - record.born > lifetime then
			gone = true
		elseif record.landed then
			local here = playerPosition(record.owner)
			if here then
				local distance = (here - part.Position).Magnitude
				if distance <= TAKE_RADIUS then
					if collect(record) then
						gone = true
					end
				elseif distance <= MAGNET_RADIUS then
					-- Slide toward the owner; re-aimed every tick, so a moving player is followed.
					local target = here + Vector3.new(0, -1.2, 0)
					local tween = TweenService:Create(part, TweenInfo.new(TICK * 1.4, Enum.EasingStyle.Linear), {
						CFrame = part.CFrame.Rotation + target,
					})
					tween:Play()
				end
			end
		end

		if gone then
			part:Destroy()
			table.remove(pickups, i)
		else
			i += 1
		end
	end
end

--==========================================================================
function LootService.Init() end

function LootService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	backpackEvent = Net.getEvent("BackpackEvent")

	local existing = Workspace:FindFirstChild("Loot")
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = "Loot"
	created.Parent = Workspace
	folder = created

	CombatService.EntityDied:connect(onDied)

	Players.PlayerRemoving:Connect(function(player)
		pity[player] = nil
		lastFull[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(step)
			if not ok then
				log:warn("pickup step failed: " .. tostring(err))
			end
		end
	end)

	log:info("ready")
end

return LootService
