--[[
	BuildChapel — run in the KINGDOM HUB place, in EDIT MODE.
	Builds the four tables of the Chapel (docs/systems/Spoils.md §6.2) into `workspace.Lobby.Chapel`:

	  Tithe      an alms table: a bowl of bone dust, three plates (today's shelf), tallow candles, an alms box
	  Reliquary  a stone table with a glass casket (an ember in it), two candelabra, a linen cloth
	  Altar      a three-step plinth, the altar, a stele with nine niches, a shard hanging in light above it
	  Journal    a lectern with an open book, a quill and ink, a stool, a bookcase of rolls behind

	The names are the ones configs/Interactions.luau points at; the ring on the ground is drawn round
	each model at run time, so MOVE THE MODELS wherever the chapel stands (select `Lobby.Chapel` and
	drag it): nothing else needs to change.

	Where it is built: `ORIGIN` below, or, left nil, twenty-five studs in front of the Storyteller (and eight to
	the left, clear of the Tudor house) if he is there, or the world origin. The ground is found with a ray. A rerun deletes `Lobby.Chapel` and builds it again.

	NOTE: a tool, not game code. Not synced by Rojo. Everything is anchored; only the big pieces collide.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ORIGIN: Vector3? = nil

--==========================================================================
local lobby = workspace:FindFirstChild("Lobby")
if not lobby then
	lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace
end

local recording = ChangeHistoryService:TryBeginRecording("BuildChapel")
local old = lobby:FindFirstChild("Chapel")
if old then
	old:Destroy()
end

local root = Instance.new("Folder")
root.Name = "Chapel"
root.Parent = lobby

local anchor = ORIGIN
if not anchor then
	local npcs = lobby:FindFirstChild("NPCs")
	local teller = npcs and npcs:FindFirstChild("Storyteller")
	if teller then
		local pivot = if teller:IsA("Model") then teller:GetPivot().Position else (teller :: BasePart).Position
		-- the plaza between the spawn and the train, left of the Tudor house (the row is 48 studs wide)
		anchor = pivot + Vector3.new(-8, 0, 25)
	else
		anchor = Vector3.zero
	end
end
local hit = workspace:Raycast((anchor :: Vector3) + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0))
local GROUND = if hit then hit.Position.Y else (anchor :: Vector3).Y
local BASE = Vector3.new((anchor :: Vector3).X, GROUND, (anchor :: Vector3).Z)

local STONE = Color3.fromRGB(109, 105, 99)
local STONE_DARK = Color3.fromRGB(78, 75, 72)
local STONE_PALE = Color3.fromRGB(140, 134, 124)
local OAK = Color3.fromRGB(84, 62, 44)
local OAK_DARK = Color3.fromRGB(58, 44, 34)
local OAK_PALE = Color3.fromRGB(110, 84, 56)
local IRON = Color3.fromRGB(52, 46, 42)
local BRASS = Color3.fromRGB(160, 128, 56)
local LINEN = Color3.fromRGB(216, 206, 178)
local WAX = Color3.fromRGB(226, 212, 178)
local BORDEAUX = Color3.fromRGB(96, 30, 40)
local PAPER = Color3.fromRGB(226, 212, 172)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = if collide == nil then false else collide
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

-- A vertical cylinder: standing on `cf`, `height` tall.
local function post(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	return cylinder(parent, name, height, diameter, cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, false)
end

local function candle(parent: Instance, at: CFrame, height: number, withLight: boolean)
	post(parent, "Candle", height, 0.3, at, WAX, Enum.Material.SmoothPlastic)
	local flame = part(parent, "Flame", Vector3.new(0.18, 0.34, 0.18), at * CFrame.new(0, height + 0.16, 0), Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flame.CanQuery = false
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 176, 96)
		light.Brightness = 0.9
		light.Range = 16
		light.Shadows = false
		light.Parent = flame
	end
end

local function model(name: string, x: number): (Model, CFrame)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m, CFrame.new(BASE + Vector3.new(x, 0, 0))
end

local function table4(m: Model, at: CFrame, w: number, d: number, h: number, top: Color3, leg: Color3, material: Enum.Material)
	part(m, "Top", Vector3.new(w, 0.5, d), at * CFrame.new(0, h, 0), top, material, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, "Leg", Vector3.new(0.5, h - 0.25, 0.5), at * CFrame.new(sx * (w / 2 - 0.5), (h - 0.25) / 2, sz * (d / 2 - 0.5)), leg, Enum.Material.Wood, true)
		end
	end
end

--==========================================================================
-- THE TITHE
--==========================================================================
do
	local m, at = model("Tithe", -24)
	table4(m, at, 7, 3.4, 3.2, OAK_PALE, OAK_DARK, Enum.Material.WoodPlanks)
	local top = 3.2 + 0.25
	-- a runner of red cloth down the middle
	part(m, "Runner", Vector3.new(7.2, 0.08, 1.4), at * CFrame.new(0, top + 0.04, 0), BORDEAUX, Enum.Material.Fabric)
	-- the bowl of bone dust
	cylinder(m, "Bowl", 0.8, 2.2, at * CFrame.new(-1.8, top + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), OAK, Enum.Material.Wood)
	local dust = part(m, "Dust", Vector3.new(1.9, 0.5, 1.9), at * CFrame.new(-1.8, top + 0.75, 0), Color3.fromRGB(226, 218, 196), Enum.Material.Sand)
	dust.Shape = Enum.PartType.Ball
	-- today's shelf: three plates, a different small thing on each
	local plate = { Color3.fromRGB(150, 138, 118), Color3.fromRGB(190, 196, 204), Color3.fromRGB(126, 98, 66) }
	for i = 1, 3 do
		local px = 0.9 + (i - 1) * 1.55
		cylinder(m, "Plate", 0.14, 1.3, at * CFrame.new(px, top + 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(176, 164, 140), Enum.Material.Slate)
		local thing = part(m, "Thing", Vector3.new(0.7, 0.35, 0.55), at * CFrame.new(px, top + 0.4, 0) * CFrame.Angles(0, math.rad(i * 30), 0), plate[i], Enum.Material.Metal)
		thing.Shape = if i == 3 then Enum.PartType.Ball else Enum.PartType.Block
	end
	-- two tallow candles at the back corners
	candle(m, at * CFrame.new(-3.1, top, -1.2), 0.9, true)
	candle(m, at * CFrame.new(3.1, top, -1.2), 0.6, false)
	-- an iron-bound alms box with a slot, at the front
	part(m, "AlmsBox", Vector3.new(1.4, 1.1, 0.9), at * CFrame.new(-2.9, top + 0.55, 1.05), OAK, Enum.Material.WoodPlanks)
	part(m, "AlmsBand", Vector3.new(1.5, 0.18, 1.0), at * CFrame.new(-2.9, top + 0.75, 1.05), IRON, Enum.Material.CorrodedMetal)
	part(m, "AlmsSlot", Vector3.new(0.7, 0.06, 0.1), at * CFrame.new(-2.9, top + 1.12, 1.05), Color3.fromRGB(14, 12, 10), Enum.Material.SmoothPlastic)
	-- a hanging sign: what the table is
	post(m, "SignPost", 6.4, 0.4, at * CFrame.new(3.8, 0, 1.6), OAK_DARK, Enum.Material.Wood)
	part(m, "SignArm", Vector3.new(0.3, 0.3, 2.2), at * CFrame.new(3.8, 6.2, 0.6), OAK_DARK, Enum.Material.Wood)
	part(m, "Sign", Vector3.new(0.2, 1.2, 1.7), at * CFrame.new(3.8, 5.3, 0.6), OAK_PALE, Enum.Material.WoodPlanks)
end

--==========================================================================
-- THE RELIQUARY
--==========================================================================
do
	local m, at = model("Reliquary", -8)
	-- the stone table, with a linen cloth hanging off it
	part(m, "Plinth", Vector3.new(7, 3.6, 3.4), at * CFrame.new(0, 1.8, 0), STONE, Enum.Material.Cobblestone, true)
	part(m, "Slab", Vector3.new(7.4, 0.5, 3.8), at * CFrame.new(0, 3.85, 0), STONE_PALE, Enum.Material.Slate, true)
	part(m, "Cloth", Vector3.new(5, 0.06, 2.4), at * CFrame.new(0, 4.13, 0), LINEN, Enum.Material.Fabric)
	part(m, "ClothHang", Vector3.new(5, 1.6, 0.06), at * CFrame.new(0, 3.3, 1.72), LINEN, Enum.Material.Fabric)
	local top = 4.1
	-- a glass casket in a brass frame, with an ember in it
	part(m, "CasketBase", Vector3.new(2.2, 0.3, 1.5), at * CFrame.new(0, top + 0.15, 0), BRASS, Enum.Material.Metal)
	local glass = part(m, "Glass", Vector3.new(2.0, 1.2, 1.3), at * CFrame.new(0, top + 0.9, 0), Color3.fromRGB(190, 210, 220), Enum.Material.Glass)
	glass.Transparency = 0.6
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, "CasketPost", Vector3.new(0.12, 1.3, 0.12), at * CFrame.new(sx * 1.0, top + 0.95, sz * 0.65), BRASS, Enum.Material.Metal)
		end
	end
	part(m, "CasketLid", Vector3.new(2.2, 0.16, 1.5), at * CFrame.new(0, top + 1.6, 0), BRASS, Enum.Material.Metal)
	local ember = part(m, "Ember", Vector3.new(0.5, 0.5, 0.5), at * CFrame.new(0, top + 0.7, 0), Color3.fromRGB(232, 120, 52), Enum.Material.Neon)
	ember.Shape = Enum.PartType.Ball
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(240, 130, 60)
	glow.Brightness = 1.0
	glow.Range = 14
	glow.Shadows = false
	glow.Parent = ember
	-- two candelabra, three candles each
	for _, sx in { -2.6, 2.6 } do
		post(m, "Stem", 1.9, 0.22, at * CFrame.new(sx, top, 0), BRASS, Enum.Material.Metal)
		part(m, "Foot", Vector3.new(0.9, 0.12, 0.9), at * CFrame.new(sx, top + 0.06, 0), BRASS, Enum.Material.Metal)
		part(m, "Bar", Vector3.new(1.5, 0.12, 0.12), at * CFrame.new(sx, top + 1.9, 0), BRASS, Enum.Material.Metal)
		for k = -1, 1 do
			candle(m, at * CFrame.new(sx + k * 0.65, top + 1.95, 0), 0.5, k == 0)
		end
	end
end

--==========================================================================
-- THE ALTAR
--==========================================================================
do
	local m, at = model("Altar", 8)
	-- three steps up
	part(m, "Step1", Vector3.new(10, 0.5, 6.6), at * CFrame.new(0, 0.25, 0), STONE_DARK, Enum.Material.Slate, true)
	part(m, "Step2", Vector3.new(8.6, 0.5, 5.4), at * CFrame.new(0, 0.75, -0.2), STONE, Enum.Material.Slate, true)
	part(m, "Step3", Vector3.new(7.2, 0.5, 4.2), at * CFrame.new(0, 1.25, -0.4), STONE_PALE, Enum.Material.Slate, true)
	-- the altar
	part(m, "Block", Vector3.new(5.4, 2.6, 2.4), at * CFrame.new(0, 2.8, -0.4), STONE, Enum.Material.Cobblestone, true)
	part(m, "Cap", Vector3.new(5.8, 0.4, 2.8), at * CFrame.new(0, 4.3, -0.4), STONE_PALE, Enum.Material.Slate, true)
	-- nine shallow places along the cap, one for each shard
	for i = 0, 8 do
		part(m, "Place", Vector3.new(0.34, 0.08, 0.34), at * CFrame.new(-2.4 + i * 0.6, 4.54, 0.4), Color3.fromRGB(34, 32, 32), Enum.Material.Slate)
	end
	-- the stele behind it, with nine niches in three rows of three
	part(m, "Stele", Vector3.new(5.0, 10.0, 1.2), at * CFrame.new(0, 6.5, -2.2), STONE_DARK, Enum.Material.Cobblestone, true)
	part(m, "SteleCap", Vector3.new(5.4, 0.7, 1.5), at * CFrame.new(0, 11.7, -2.2), STONE, Enum.Material.Slate, true)
	for row = 0, 2 do
		for col = 0, 2 do
			part(m, "Niche", Vector3.new(0.9, 0.9, 0.2), at * CFrame.new(-1.4 + col * 1.4, 4.9 + row * 1.9, -1.55), Color3.fromRGB(20, 19, 19), Enum.Material.Slate)
		end
	end
	-- a shard hanging in the light over the altar
	local shard = part(m, "Shard", Vector3.new(0.5, 3.0, 0.5), at * CFrame.new(0, 7.4, -0.4) * CFrame.Angles(math.rad(8), math.rad(35), math.rad(14)), Color3.fromRGB(250, 236, 190), Enum.Material.Neon)
	shard.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 200)
	light.Brightness = 1.6
	light.Range = 26
	light.Shadows = false
	light.Parent = shard
	-- iron braziers at the foot of the steps
	for _, sx in { -4.8, 4.8 } do
		post(m, "BrazierLeg", 2.4, 0.3, at * CFrame.new(sx, 0, 3.6), IRON, Enum.Material.CorrodedMetal)
		cylinder(m, "BrazierBowl", 0.7, 1.7, at * CFrame.new(sx, 2.6, 3.6) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.CorrodedMetal)
		local flame = part(m, "BrazierFlame", Vector3.new(0.9, 1.0, 0.9), at * CFrame.new(sx, 3.2, 3.6), Color3.fromRGB(255, 160, 70), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanQuery = false
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 4
		fire.Parent = flame
		local lamp = Instance.new("PointLight")
		lamp.Color = Color3.fromRGB(255, 160, 80)
		lamp.Brightness = 1.2
		lamp.Range = 20
		lamp.Shadows = false
		lamp.Parent = flame
	end
end

--==========================================================================
-- THE JOURNAL
--==========================================================================
do
	local m, at = model("Journal", 24)
	-- the lectern: a post and a sloping top
	part(m, "Foot", Vector3.new(2.2, 0.4, 2.0), at * CFrame.new(0, 0.2, 0), OAK_DARK, Enum.Material.Wood, true)
	post(m, "Stem", 3.4, 0.8, at * CFrame.new(0, 0.4, 0), OAK, Enum.Material.Wood)
	local desk = at * CFrame.new(0, 4.1, 0) * CFrame.Angles(math.rad(-22), 0, 0)
	part(m, "Desk", Vector3.new(3.4, 0.3, 2.4), desk, OAK_PALE, Enum.Material.WoodPlanks, true)
	part(m, "DeskLip", Vector3.new(3.4, 0.3, 0.25), desk * CFrame.new(0, 0.2, 1.1), OAK_DARK, Enum.Material.Wood)
	-- the book open on it: a cover, two leaves
	part(m, "Cover", Vector3.new(2.5, 0.12, 1.7), desk * CFrame.new(0, 0.22, -0.05), Color3.fromRGB(70, 30, 30), Enum.Material.Leather)
	part(m, "LeafLeft", Vector3.new(1.15, 0.08, 1.5), desk * CFrame.new(-0.62, 0.3, -0.05) * CFrame.Angles(0, 0, math.rad(3)), PAPER, Enum.Material.Fabric)
	part(m, "LeafRight", Vector3.new(1.15, 0.08, 1.5), desk * CFrame.new(0.62, 0.3, -0.05) * CFrame.Angles(0, 0, math.rad(-3)), PAPER, Enum.Material.Fabric)
	-- a quill and an inkwell on a little shelf beside the desk
	part(m, "Shelf", Vector3.new(1.2, 0.2, 1.0), at * CFrame.new(2.4, 3.6, 0), OAK, Enum.Material.Wood)
	cylinder(m, "Inkwell", 0.5, 0.5, at * CFrame.new(2.4, 3.95, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 22, 28), Enum.Material.Glass)
	part(m, "Quill", Vector3.new(0.08, 0.08, 1.5), at * CFrame.new(2.3, 4.0, -0.2) * CFrame.Angles(0, math.rad(25), math.rad(8)), LINEN, Enum.Material.Fabric)
	-- a stool
	part(m, "StoolSeat", Vector3.new(1.5, 0.25, 1.5), at * CFrame.new(-2.4, 2.0, 1.4), OAK, Enum.Material.Wood, true)
	for _, sx in { -0.5, 0.5 } do
		for _, sz in { -0.5, 0.5 } do
			part(m, "StoolLeg", Vector3.new(0.22, 1.9, 0.22), at * CFrame.new(-2.4 + sx, 1.0, 1.4 + sz), OAK_DARK, Enum.Material.Wood)
		end
	end
	-- a bookcase of rolls and bound pages behind
	local back = at * CFrame.new(0, 0, -3.2)
	part(m, "CaseBack", Vector3.new(7, 8, 0.3), back * CFrame.new(0, 4, -0.5), OAK_DARK, Enum.Material.Wood, true)
	for _, sx in { -3.4, 3.4 } do
		part(m, "CaseSide", Vector3.new(0.3, 8, 1.4), back * CFrame.new(sx, 4, 0), OAK, Enum.Material.Wood, true)
	end
	local rng = Random.new(7)
	for shelf = 0, 3 do
		part(m, "CaseShelf", Vector3.new(7, 0.25, 1.4), back * CFrame.new(0, 0.2 + shelf * 2.1, 0), OAK, Enum.Material.Wood)
		if shelf < 3 then
			local x = -3.0
			while x < 3.0 do
				local w = 0.25 + rng:NextNumber() * 0.2
				local h = 1.0 + rng:NextNumber() * 0.7
				local tone = rng:NextInteger(0, 3)
				local c = if tone == 0 then Color3.fromRGB(96, 40, 44) elseif tone == 1 then Color3.fromRGB(64, 72, 56) elseif tone == 2 then Color3.fromRGB(120, 96, 64) else Color3.fromRGB(52, 48, 56)
				part(m, "Book", Vector3.new(w, h, 1.0), back * CFrame.new(x + w / 2, 0.325 + shelf * 2.1 + h / 2, 0), c, Enum.Material.Leather)
				x += w + 0.04
			end
		end
	end
	candle(m, at * CFrame.new(2.4, 3.7, -0.3), 0.7, true)
end

--==========================================================================
-- flagstones under all four, so the chapel reads as one place
for i = 0, 3 do
	local x = -24 + i * 16
	local slab = part(root, "Flags", Vector3.new(11, 0.2, 9), CFrame.new(BASE + Vector3.new(x, 0.1, 0)), STONE_DARK, Enum.Material.Cobblestone, false)
	slab.CanQuery = false
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(("BuildChapel: built at %.0f, %.0f, %.0f (ground %.1f). Move Lobby.Chapel to where the chapel stands."):format(BASE.X, BASE.Y, BASE.Z, GROUND))
