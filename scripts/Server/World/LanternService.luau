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
	local ring = part(model, "Ring", Vector3.new(0.08, 0.5, 0.5), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	weld(hand, ring, CFrame.new(0, -0.35, 0))

	local cap = part(model, "Cap", Vector3.new(0.62, 0.14, 0.62), IRON, Enum.Material.Metal)
	weld(hand, cap, CFrame.new(0, -0.78, 0))
	local base = part(model, "Base", Vector3.new(0.6, 0.12, 0.6), IRON, Enum.Material.Metal)
	weld(hand, base, CFrame.new(0, -1.5, 0))

	local glass = part(model, "Glass", Vector3.new(0.46, 0.6, 0.46), cfg.Color, Enum.Material.Glass)
	glass.Transparency = 0.55
	glass.Reflectance = 0
	weld(hand, glass, CFrame.new(0, -1.14, 0))

	for i, c in { { 0.27, 0.27 }, { -0.27, 0.27 }, { 0.27, -0.27 }, { -0.27, -0.27 } } do
		local bar = part(model, "Bar" .. i, Vector3.new(0.05, 0.64, 0.05), IRON, Enum.Material.Metal)
		weld(hand, bar, CFrame.new(c[1], -1.14, c[2]))
	end

	local flame = part(model, "Flame", Vector3.new(0.2, 0.28, 0.2), Color3.fromRGB(255, 214, 140), Enum.Material.Neon, Enum.PartType.Ball)
	weld(hand, flame, CFrame.new(0, -1.16, 0))

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
