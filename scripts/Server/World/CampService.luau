--!strict
--[[
	CampService
	The breath after a gate (docs/systems/Trials.md §6, Spoils.md §6.1). When a chamber's
	gate has gone up, a camp is lit in the mouth of its passage, on the side toward the
	middle of the castle where the party is not going to walk through it: a fire to
	stand by, a bench, a chest, a bedroll and some crates.

	THE FIRE heals whoever stands within a few strides of it, a little every second.
	It is the only place in the castle where the dead's wounds close; and it lights the
	place, so the party sees where the camp is from the other side of the gate.

	THE BENCH makes four things from what the party carried in (configs/Camp): bandages
	from cloth, arrows, an oil pot, a torch. It opens a small panel on the player's
	screen (CampEvent) and makes things when asked (RequestCraft), after checking that
	they are standing at it, that they have what it needs, and that there is room.

	THE CHEST holds one Sound find per player per camp (`Loot.camp_chest`): a reason to
	come back for the last thing.

	THE PLACE IS SAVED: the fallen come back at the last camp that was lit, not at the
	castle's gate (DeathService.setRespawnPoint).

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local AreaService = require(script.Parent.AreaService)
local BackpackService = require(script.Parent.BackpackService)
local CombatService = require(script.Parent.CombatService)
local DeathService = require(script.Parent.DeathService)
local LootService = require(script.Parent.LootService)
local Torch = require(script.Parent.Trial.Torch)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local CampService = {}

CampService.Name = "CampService"

local log = Logger.new("CampService")

type Camp = {
	index: number,
	fire: BasePart,
	bench: Vector3,
	chest: Vector3,
	opened: { [Player]: boolean },
}

local camps: { Camp } = {}
local campEvent: RemoteEvent? = nil
local hintEvent: RemoteEvent? = nil
local lastCraft: { [Player]: number } = {}

local OAK = Color3.fromRGB(78, 58, 40)
local OAK_PALE = Color3.fromRGB(104, 80, 54)
local OAK_DARK = Color3.fromRGB(58, 44, 34)
local IRON = Color3.fromRGB(52, 46, 42)
local STONE = Color3.fromRGB(96, 92, 86)
local CLOTH = Color3.fromRGB(112, 98, 74)
local WOOL = Color3.fromRGB(96, 36, 44)

--==========================================================================
-- Building
--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = if collide == nil then true else collide
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinder(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function prompt(parent: Instance, at: Vector3, name: string, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local anchor = part(parent, name, Vector3.one, CFrame.new(at), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor.CanTouch = false
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = anchor
	return p
end

--[[
	`at` is the middle of the camp on the ground; `side` is +1 or -1, the way along x to the passage's
	WALL (the camp is built against the wall that is toward the middle of the castle, so the party's
	way through the passage is left clear). The fire is in the middle, the bench and the chest are
	against the wall, in world axes: the tunnel is only eleven studs deep.
]]
local function build(index: number, at: Vector3, side: number): Camp
	local model = Instance.new("Model")
	model.Name = ("Camp%d"):format(index)
	local folder = Workspace:FindFirstChild("Camps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Camps"
		folder.Parent = Workspace
	end
	model.Parent = folder

	-- x is toward the wall (positive), z along the tunnel (negative is the way on)
	local function place(x: number, y: number, z: number): CFrame
		return CFrame.new(at + Vector3.new(side * x, y, z))
	end

	-- THE FIRE: a ring of stones, five logs leaning in, a flame, a little smoke
	local firePos = place(0, 0, 0)
	for i = 0, 8 do
		local a = i * math.pi * 2 / 9
		part(model, "Stone", Vector3.new(1.5, 1.0, 1.3), firePos * CFrame.new(math.cos(a) * 2.1, 0.5, math.sin(a) * 2.1) * CFrame.Angles(0, -a, 0), STONE, Enum.Material.Cobblestone)
	end
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + 0.3
		cylinder(model, "Log", 3.2, 0.5, firePos * CFrame.new(math.cos(a) * 0.5, 0.9, math.sin(a) * 0.5) * CFrame.Angles(math.rad(34), a + math.pi / 2, math.rad(90)) , Color3.fromRGB(44, 32, 24), Enum.Material.Wood, false)
	end
	part(model, "Ash", Vector3.new(3.4, 0.1, 3.4), firePos * CFrame.new(0, 0.12, 0), Color3.fromRGB(34, 30, 28), Enum.Material.Slate, false)
	local flame = part(model, "Fire", Vector3.new(1, 1, 1), firePos * CFrame.new(0, 1.8, 0), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, false)
	flame.Transparency = 1
	flame.CanQuery = false
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(200, 60, 20)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Brightness = 1.8
	light.Range = 44
	light.Shadows = false
	light.Parent = flame
	CollectionService:AddTag(light, "TLK_Lod")
	local smoke = Instance.new("Smoke")
	smoke.Size = 3
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 3
	smoke.Color = Color3.fromRGB(120, 114, 106)
	smoke.Parent = flame
	-- a tripod and a pot over it, steaming
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		cylinder(model, "TripodLeg", 5, 0.25, firePos * CFrame.new(math.cos(a) * 0.8, 2.3, math.sin(a) * 0.8) * CFrame.Angles(0, -a, math.rad(90 - 18)), IRON, Enum.Material.CorrodedMetal, false)
	end
	local pot = cylinder(model, "Pot", 1.2, 1.7, firePos * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.Metal, false)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	steam.Lifetime = NumberRange.new(1.0, 1.8)
	steam.Speed = NumberRange.new(1, 2)
	steam.Rate = 4
	steam.Parent = pot

	-- THE BENCH: a plank top on trestles, a vice, a hammer, a saw, a coil of thread, cloth and iron
	local benchAt = place(8.7, 0, -3)
	local benchBase = benchAt * CFrame.Angles(0, math.rad(90), 0)
	part(model, "BenchTop", Vector3.new(7, 0.6, 3), benchBase * CFrame.new(0, 3.4, 0), OAK_PALE, Enum.Material.WoodPlanks)
	for _, x in { -2.8, 2.8 } do
		for _, z in { -1.1, 1.1 } do
			part(model, "BenchLeg", Vector3.new(0.5, 3.2, 0.5), benchBase * CFrame.new(x, 1.6, z), OAK_DARK, Enum.Material.Wood)
		end
		part(model, "BenchStretcher", Vector3.new(0.35, 0.35, 2.4), benchBase * CFrame.new(x, 1.0, 0), OAK_DARK, Enum.Material.Wood, false)
	end
	part(model, "Vice", Vector3.new(0.9, 0.9, 0.6), benchBase * CFrame.new(-2.6, 4.1, 1.0), IRON, Enum.Material.CorrodedMetal, false)
	part(model, "HammerHaft", Vector3.new(0.25, 0.25, 1.9), benchBase * CFrame.new(1.0, 3.85, 0.5) * CFrame.Angles(0, math.rad(30), 0), OAK, Enum.Material.Wood, false)
	part(model, "HammerHead", Vector3.new(0.7, 0.45, 0.45), benchBase * CFrame.new(1.4, 3.95, 1.3) * CFrame.Angles(0, math.rad(30), 0), IRON, Enum.Material.CorrodedMetal, false)
	part(model, "Saw", Vector3.new(2.4, 0.5, 0.12), benchBase * CFrame.new(-0.4, 3.72, -0.7) * CFrame.Angles(0, math.rad(-12), 0), Color3.fromRGB(110, 108, 106), Enum.Material.Metal, false)
	cylinder(model, "Thread", 0.5, 0.7, benchBase * CFrame.new(2.2, 3.9, -0.6), Color3.fromRGB(150, 138, 118), Enum.Material.Fabric, false)
	part(model, "ClothPile", Vector3.new(1.7, 0.5, 1.3), benchBase * CFrame.new(2.1, 3.95, 0.7) * CFrame.Angles(0, math.rad(20), 0), CLOTH, Enum.Material.Fabric, false)
	for i = 0, 2 do
		part(model, "IronBar", Vector3.new(1.5, 0.22, 0.22), benchBase * CFrame.new(-1.2, 3.82 + i * 0.22, 0.2) * CFrame.Angles(0, math.rad(8 * i), 0), Color3.fromRGB(70, 62, 58), Enum.Material.CorrodedMetal, false)
	end
	-- a lantern hung on a short post at the bench's end
	part(model, "Post", Vector3.new(0.4, 6.4, 0.4), benchBase * CFrame.new(3.7, 3.2, -1.2), OAK_DARK, Enum.Material.Wood)
	part(model, "Arm", Vector3.new(1.3, 0.3, 0.3), benchBase * CFrame.new(3.1, 6.2, -1.2), OAK_DARK, Enum.Material.Wood, false)
	part(model, "Lantern", Vector3.new(0.8, 1.1, 0.8), benchBase * CFrame.new(2.5, 5.6, -1.2), Color3.fromRGB(255, 190, 110), Enum.Material.Neon, false).Transparency = 0.25
	local benchWorld = benchBase.Position

	-- THE CHEST: against the wall behind the fire, iron-banded, lid ajar
	local chestAt = place(8.7, 0, 2.4)
	local chestBase = chestAt * CFrame.Angles(0, math.rad(-90 * side), 0)
	part(model, "ChestBody", Vector3.new(4.6, 2.6, 2.8), chestBase * CFrame.new(0, 1.3, 0), OAK, Enum.Material.WoodPlanks)
	part(model, "ChestLid", Vector3.new(4.8, 0.7, 3.0), chestBase * CFrame.new(0, 2.85, -0.2) * CFrame.Angles(math.rad(-9), 0, 0), OAK_PALE, Enum.Material.Wood, false)
	for _, x in { -1.6, 1.6 } do
		part(model, "ChestBand", Vector3.new(0.4, 2.9, 3.0), chestBase * CFrame.new(x, 1.5, 0), IRON, Enum.Material.CorrodedMetal, false)
	end
	part(model, "ChestLock", Vector3.new(0.7, 0.9, 0.3), chestBase * CFrame.new(0, 2.1, 1.5), Color3.fromRGB(150, 120, 52), Enum.Material.Metal, false)
	local chestWorld = chestBase.Position

	-- A BEDROLL by the fire, a sack, two crates
	local roll = place(-2.4, 0, 2.6)
	part(model, "Bedroll", Vector3.new(2.2, 0.5, 5), roll * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(14), 0), WOOL, Enum.Material.Fabric, false)
	cylinder(model, "BedrollRoll", 2.2, 0.8, roll * CFrame.new(0.4, 0.5, -2.2) * CFrame.Angles(0, math.rad(14), math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 112, 96), Enum.Material.Fabric, false)
	part(model, "Sack", Vector3.new(1.8, 1.8, 1.5), place(6.4, 0.9, -5.2) * CFrame.Angles(0, math.rad(25), math.rad(6)), CLOTH, Enum.Material.Fabric)
	part(model, "Crate", Vector3.new(2.4, 2.2, 2.4), place(9.2, 1.1, -6.2) * CFrame.Angles(0, math.rad(8), 0), OAK, Enum.Material.WoodPlanks)

	-- it lights itself: the flame and the lamp come up over a couple of seconds
	fire.Size = 2
	light.Brightness = 0.2
	TweenService:Create(light, TweenInfo.new(2.5), { Brightness = 1.8 }):Play()
	task.spawn(function()
		for s = 2, 8, 1 do
			fire.Size = s
			task.wait(0.35)
		end
	end)

	local camp: Camp = { index = index, fire = flame, bench = benchWorld + Vector3.new(0, 3, 0), chest = chestWorld, opened = {} }

	-- the bench
	local benchPrompt = prompt(model, benchWorld + Vector3.new(0, 5.2, 0), "BenchPrompt", "Make", "Camp bench", 0.4, 8)
	benchPrompt.Triggered:Connect(function(player: Player)
		CampService.open(player, camp)
	end)

	-- the chest: once each
	local chestPrompt = prompt(model, chestWorld + Vector3.new(0, 3.6, 0), "ChestPrompt", "Open", "Camp chest", 1.2, 7)
	chestPrompt.Triggered:Connect(function(player: Player)
		if camp.opened[player] then
			return
		end
		camp.opened[player] = true
		LootService.grant(player, "camp_chest", chestWorld + Vector3.new(0, 4, 0))
	end)

	return camp
end

--==========================================================================
-- The bench
--==========================================================================
local function recipePayload(player: Player): { any }
	local items = Config.get("Items")
	local bp = BackpackService.get(player)
	local out: { any } = {}
	for _, r in Config.get("Camp").Recipes do
		local needs: { any } = {}
		local can = true
		for itemId, need in r.needs do
			local have = bp:count(itemId)
			if have < need then
				can = false
			end
			local def = items[itemId]
			table.insert(needs, { id = itemId, name = if def then def.DisplayName else itemId, need = need, have = have })
		end
		table.sort(needs, function(a, b)
			return a.name < b.name
		end)
		if r.makes.item and bp:room(r.makes.item) < r.makes.count then
			can = false
		end
		local makes = if r.makes.item then (items[r.makes.item] and items[r.makes.item].DisplayName or r.makes.item) else "a lit torch"
		table.insert(out, { id = r.id, label = r.label, needs = needs, makes = makes, can = can })
	end
	return out
end

function CampService.open(player: Player, camp: Camp)
	if campEvent then
		campEvent:FireClient(player, { kind = "open", at = camp.bench, reach = Config.get("Camp").Reach + 4, recipes = recipePayload(player) })
	end
end

local function nearestBench(player: Player): Camp?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local reach = Config.get("Camp").Reach
	for _, camp in camps do
		if (root.Position - camp.bench).Magnitude <= reach then
			return camp
		end
	end
	return nil
end

local function craft(player: Player, recipeId: any)
	if typeof(recipeId) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastCraft[player] or 0) < 0.2 then
		return
	end
	lastCraft[player] = now
	local camp = nearestBench(player)
	if not camp then
		return
	end
	local recipe
	for _, r in Config.get("Camp").Recipes do
		if r.id == recipeId then
			recipe = r
		end
	end
	if not recipe then
		return
	end
	local bp = BackpackService.get(player)
	for itemId, need in recipe.needs do
		if bp:count(itemId) < need then
			CampService.open(player, camp)
			return
		end
	end
	if recipe.makes.item and bp:room(recipe.makes.item) < recipe.makes.count then
		CampService.open(player, camp)
		return
	end
	for itemId, need in recipe.needs do
		BackpackService.remove(player, itemId, need)
	end
	if recipe.makes.item then
		BackpackService.add(player, recipe.makes.item, recipe.makes.count)
	else
		Torch.give(player, recipe.makes.torch)
	end
	if campEvent then
		campEvent:FireClient(player, { kind = "update", at = camp.bench, reach = Config.get("Camp").Reach + 4, recipes = recipePayload(player), made = recipe.label })
	end
end

--==========================================================================
-- Lighting a camp
--==========================================================================
local function light(index: number)
	local passage = AreaService.passageOf(index)
	-- the wall toward the middle of the castle: the way through the passage's middle stays clear
	local side = if passage.X > 0 then -1 else 1
	local at = Vector3.new(passage.X + side * 12.3, passage.Y, passage.Z - 6.0)
	local camp = build(index, at, side)
	table.insert(camps, camp)
	DeathService.setRespawnPoint(CFrame.lookAt(at + Vector3.new(-side * 6, 3.4, 0), at + Vector3.new(-side * 6, 3.4, -20)))
	if hintEvent then
		hintEvent:FireAllClients({ source = "trialnote", text = "A camp is lit in the passage: a fire, a bench, a chest. If you fall, you wake here." })
		task.delay(7, function()
			hintEvent:FireAllClients({ source = "trialnote", text = nil })
		end)
	end
	log:info(("camp %d lit at %.0f, %.0f"):format(index, at.X, at.Z))
end

function CampService.Init() end

function CampService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	campEvent = Net.getEvent("CampEvent")
	hintEvent = Net.getEvent("ObjectiveHint")
	Net.getEvent("RequestCraft").OnServerEvent:Connect(craft)
	Players.PlayerRemoving:Connect(function(player)
		lastCraft[player] = nil
		for _, camp in camps do
			camp.opened[player] = nil
		end
	end)

	-- a new run (a Play Again): the last run's camps are struck
	DeathService.onRunBegin(function()
		table.clear(camps)
		local folder = Workspace:FindFirstChild("Camps")
		if folder then
			folder:ClearAllChildren()
		end
	end)

	AreaService.onCleared(function(index: number)
		-- the ninth chamber has no passage (it ends at the tower), so no camp
		if not AreaService.gateModel(index) then
			return
		end
		-- the gate has gone up by now; the camp comes after the party's first breath
		task.wait(3.6)
		light(index)
	end)

	-- the fire's warmth: a little every second to whoever stands by it
	local warmth = Config.get("Camp").Warmth
	task.spawn(function()
		while true do
			task.wait(1)
			for _, camp in camps do
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and (root.Position - camp.fire.Position).Magnitude <= warmth.Radius then
						local entity = CombatService.getEntity(Constants.CombatId.PlayerPrefix .. player.UserId)
						if entity and entity:isAlive() and entity.health.current < entity.health.max then
							entity.health:heal(warmth.Heal)
						end
					end
				end
			end
		end
	end)
	log:info("ready")
end

-- Development: light the camp of chamber `index` now.
function CampService.lightNow(index: number)
	light(index)
end

-- Development: open the panel of the last camp lit, as if the prompt had been held.
function CampService.devOpen(player: Player)
	local camp = camps[#camps]
	if camp then
		CampService.open(player, camp)
	end
end

return CampService
