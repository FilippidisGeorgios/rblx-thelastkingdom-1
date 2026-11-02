--!strict
--[[
	LanternService
	The lantern: the one light a body carries in the dark places (docs/systems/Catacombs.md). The table by the mountain of
	area 4 gives one to each player who takes it (`give`); from then on it hangs from their left hand and is lit, for
	everyone to see, to the end of the run (the forest will not be walkable without it).

	WHAT IT IS. The item `lantern` in the backpack (so the top of the screen, the pack and the run's record all know it),
	and a small model welded to the left hand with ONE PointLight in it: its range, strength and colour are
	`configs/Catacombs.Lantern`. The light casts shadows, so that a wall stops it (without that the maze would glow
	through its own walls). The light is the same for every player whatever picture quality they chose.

	It looks once a second at who holds the item, so a body that died and came back, or one that took the lantern after
	the others, gets it without anything having to tell this service.

	Place: Forgotten Lands ONLY (Server/World).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GameService = require(Server.Services.GameService)
local BackpackService = require(script.Parent.BackpackService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local LanternService = {}

LanternService.Name = "LanternService"

local log = Logger.new("LanternService")

local MODEL = "HeldLantern"

local IRON = Color3.fromRGB(46, 41, 38)
local BRASS = Color3.fromRGB(150, 118, 62)

local function part(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart, offset: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = offset
	w.Parent = b
end

-- The lantern, hanging below the hand: a glass box in an iron frame, a cap, a ring, a flame and the light.
local function build(hand: BasePart): Model
	local cfg = Config.get("Catacombs").Lantern
	local model = Instance.new("Model")
	model.Name = MODEL

	-- everything is placed relative to the hand: the ring at the hand, the body hanging 0.9 below it
	-- (a cylinder's axis is its X: this one is a thin disc standing in the plane of the hand)
	-- (2026-11-02, more real: an old hand lantern of black iron and aged brass, with a bail to hold it by, a domed cap with a
	-- chimney, four corner posts with rims, panes of smoky glass, a pot with a stub of candle and a small teardrop flame)
	local RUST = Color3.fromRGB(58, 40, 30)
	local AGED = Color3.fromRGB(112, 88, 48)
	-- the bail: a ring in the hand, two thin wires up from the cap's sides to an arch
	local ring = part(model, "Ring", Vector3.new(0.07, 0.42, 0.42), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(hand, ring, CFrame.new(0, -0.3, 0))
	for i, s in { -1, 1 } do
		local wire = part(model, "Bail" .. i, Vector3.new(0.04, 0.5, 0.04), IRON, Enum.Material.Metal)
		weld(hand, wire, CFrame.new(s * 0.2, -0.62, 0) * CFrame.Angles(0, 0, math.rad(-s * 18)))
	end
	local arch = part(model, "Arch", Vector3.new(0.04, 0.04, 0.34), IRON, Enum.Material.Metal)
	weld(hand, arch, CFrame.new(0, -0.38, 0) * CFrame.Angles(0, math.rad(90), 0))

	-- the cap: a wide dome, a chimney and a small knob
	local dome = part(model, "Dome", Vector3.new(0.2, 0.7, 0.7), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(hand, dome, CFrame.new(0, -0.84, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local chimney = part(model, "Chimney", Vector3.new(0.16, 0.34, 0.34), RUST, Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(hand, chimney, CFrame.new(0, -0.74, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local knob = part(model, "Knob", Vector3.new(0.12, 0.12, 0.12), AGED, Enum.Material.Metal, Enum.PartType.Ball)
	weld(hand, knob, CFrame.new(0, -0.62, 0))

	-- rims, top and bottom
	for _, y in { -0.93, -1.5 } do
		local rim = part(model, "Rim", Vector3.new(0.6, 0.07, 0.6), IRON, Enum.Material.Metal)
		weld(hand, rim, CFrame.new(0, y, 0))
	end

	-- panes of smoky glass
	local glass = part(model, "Glass", Vector3.new(0.46, 0.52, 0.46), cfg.Color:Lerp(Color3.fromRGB(120, 100, 70), 0.4), Enum.Material.Glass)
	glass.Transparency = 0.6
	glass.Reflectance = 0.04
	weld(hand, glass, CFrame.new(0, -1.21, 0))

	for i, c in { { 0.26, 0.26 }, { -0.26, 0.26 }, { 0.26, -0.26 }, { -0.26, -0.26 } } do
		local bar = part(model, "Bar" .. i, Vector3.new(0.05, 0.6, 0.05), IRON, Enum.Material.Metal)
		weld(hand, bar, CFrame.new(c[1], -1.22, c[2]))
		local foot = part(model, "Foot" .. i, Vector3.new(0.07, 0.1, 0.07), RUST, Enum.Material.Metal)
		weld(hand, foot, CFrame.new(c[1], -1.58, c[2]))
	end
	-- a cross band round the middle
	local band = part(model, "Band", Vector3.new(0.52, 0.04, 0.52), AGED, Enum.Material.Metal)
	weld(hand, band, CFrame.new(0, -1.22, 0))

	-- the oil pot and a stub of candle with its wick
	local pot = part(model, "Pot", Vector3.new(0.12, 0.34, 0.34), AGED, Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(hand, pot, CFrame.new(0, -1.44, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local candle = part(model, "Candle", Vector3.new(0.2, 0.1, 0.1), Color3.fromRGB(226, 210, 170), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	candle.Size = Vector3.new(0.26, 0.11, 0.11)
	weld(hand, candle, CFrame.new(0, -1.31, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local wick = part(model, "Wick", Vector3.new(0.02, 0.1, 0.02), Color3.fromRGB(30, 24, 20), Enum.Material.Fabric)
	weld(hand, wick, CFrame.new(0, -1.22, 0))

	-- the flame: a small teardrop (a round body and a small tip), the body is the one that carries the light
	local tip = part(model, "FlameTip", Vector3.new(0.09, 0.09, 0.09), Color3.fromRGB(255, 232, 170), Enum.Material.Neon, Enum.PartType.Ball)
	weld(hand, tip, CFrame.new(0, -1.03, 0))
	local flame = part(model, "Flame", Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(255, 190, 110), Enum.Material.Neon, Enum.PartType.Ball)
	weld(hand, flame, CFrame.new(0, -1.13, 0))

	local light = Instance.new("PointLight")
	light.Name = "LanternLight"
	light.Color = cfg.Color
	light.Range = cfg.Range
	light.Brightness = cfg.Brightness
	light.Shadows = cfg.Shadows
	light.Parent = flame
	-- NOT tagged "TLK_Lod": that controller reads a light's place once, when it arrives, and cuts it off when the camera is
	-- far from there. A lantern walks. (Found in play: it went out 135 studs from where it was first lit.)

	model.PrimaryPart = flame
	return model
end

--[[
	A lantern standing on a surface, the same one a hand carries (2026-11-03: the table at the catacombs showed an older,
	plainer one than the one you are given). `at` is where its feet stand. It is anchored by an unseen part where a hand
	would be; its light is softer and casts no shadow.
]]
function LanternService.display(parent: Instance, at: CFrame): Model
	local anchor = Instance.new("Part")
	anchor.Name = "Hang"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = at * CFrame.new(0, 1.63, 0)
	local model = build(anchor)
	model.Name = "LanternDisplay"
	anchor.Parent = model
	local light = model:FindFirstChild("LanternLight", true)
	if light and light:IsA("PointLight") then
		light.Range = 12
		light.Brightness = 1.2
		light.Shadows = false
	end
	model.Parent = parent
	return model
end

local function handOf(character: Model): BasePart?
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function hasLantern(player: Player): boolean
	local item = Config.get("Catacombs").Lantern.Item
	local ok, n = pcall(BackpackService.count, player, item)
	return ok and n > 0
end

-- Below the ground the lantern is the only light a body carries: the glow of a blade or a charm is put out while they
-- are down there, and lit again as they come up. (The lantern's own light is never touched.)
local function quietOtherLights(character: Model)
	local cfg = Config.get("Catacombs")
	local below = (cfg.DarkBelow or -20) :: number
	local quiet = character:GetPivot().Position.Y < below
	local held = character:FindFirstChild(MODEL)
	for _, d in character:GetDescendants() do
		if d:IsA("Light") and not (held and d:IsDescendantOf(held)) then
			if quiet and d.Enabled then
				d:SetAttribute("TLK_QuietWas", true)
				d.Enabled = false
			elseif not quiet and d:GetAttribute("TLK_QuietWas") then
				d:SetAttribute("TLK_QuietWas", nil)
				d.Enabled = true
			end
		end
	end
end

local function refresh(player: Player)
	local character = player.Character
	if not character then
		return
	end
	quietOtherLights(character)
	local held = character:FindFirstChild(MODEL)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local wants = hasLantern(player) and humanoid ~= nil and humanoid.Health > 0
	if wants and not held then
		local hand = handOf(character)
		if hand then
			build(hand).Parent = character
		end
	elseif held and not wants then
		held:Destroy()
	end
end

--[[
	Hands the lantern to `player` (the table's prompt calls this). Returns false when they already have it.
]]
function LanternService.give(player: Player): boolean
	if hasLantern(player) then
		return false
	end
	BackpackService.add(player, Config.get("Catacombs").Lantern.Item, 1, true)
	refresh(player)
	return true
end

function LanternService.has(player: Player): boolean
	return hasLantern(player)
end

function LanternService.Init() end

function LanternService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(refresh, player)
				if not ok then
					log:warn("refresh: " .. tostring(err))
				end
			end
			task.wait(1)
		end
	end)
	log:info("ready")
end

return LanternService
