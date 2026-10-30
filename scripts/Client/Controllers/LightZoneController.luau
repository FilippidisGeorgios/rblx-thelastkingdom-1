--!strict
--[[
	LightZoneController
	Makes the rooms that are shut in dark: while the player stands inside a light zone (a tagged, invisible box in the
	place; see `configs/LightZones`) the flat ambient light and the sky's reflection are turned down, and they come back
	when the player leaves. Torches and fires are then the only light.

	It changes the PLACE's light, the same for every player, whatever picture quality they chose, and it touches
	only the properties `configs/LightZones` allows (a spec checks the list). It remembers the place's own values
	when it starts and returns to exactly those.

	Streaming: the boxes are found by their tag and follow it as they stream in and out.

	Place: client (boots in both places; the Hub has no zones, so it does nothing there).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local LightZone = require(ReplicatedStorage.Shared.LightZone)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local LightZoneController = {}

LightZoneController.Name = "LightZoneController"

local log = Logger.new("LightZoneController")

local STEP_SECONDS = 0.2

-- Lighting properties a zone may change, and where each lives.
local LIGHTING_KEYS = { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }

local cfg: any = nil
local parts: { [BasePart]: { profile: string, priority: number } } = {}
local baseline: { [string]: any } = {}
local atmosphere: Atmosphere? = nil
local current: string? = nil -- the profile now applied, nil = the place's own light
local tweens: { Tween } = {}

local function capture()
	for _, key in LIGHTING_KEYS do
		baseline[key] = (Lighting :: any)[key]
	end
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		baseline.AtmosphereDensity = atmosphere.Density
	end
end

local function register(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local profile = instance:GetAttribute("Profile")
	if type(profile) ~= "string" or not cfg.Profiles[profile] then
		log:warn(("light zone %s has no valid Profile attribute"):format(instance:GetFullName()))
		return
	end
	local priority = instance:GetAttribute("Priority")
	parts[instance] = { profile = profile, priority = if type(priority) == "number" then priority else 0 }
end

-- Moves the light toward profile `name` (nil = the place's own) over `seconds`.
local function apply(name: string?, seconds: number)
	for _, tween in tweens do
		tween:Cancel()
	end
	tweens = {}
	local profile = if name then cfg.Profiles[name] else nil
	local info = TweenInfo.new(math.max(seconds, 0.05), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local goal: { [string]: any } = {}
	for _, key in LIGHTING_KEYS do
		goal[key] = if profile and profile[key] ~= nil then profile[key] else baseline[key]
	end
	local tween = TweenService:Create(Lighting, info, goal)
	table.insert(tweens, tween)
	tween:Play()

	if atmosphere and atmosphere.Parent and baseline.AtmosphereDensity ~= nil then
		local density = if profile and profile.AtmosphereDensity ~= nil then profile.AtmosphereDensity else baseline.AtmosphereDensity
		local atmo = TweenService:Create(atmosphere, info, { Density = density })
		table.insert(tweens, atmo)
		atmo:Play()
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local list: { LightZone.Zone } = {}
	for part, info in parts do
		if part.Parent then
			table.insert(list, { id = info.profile, cframe = part.CFrame, size = part.Size, priority = info.priority })
		end
	end
	local zone = LightZone.pick(list, root.Position + Vector3.new(0, 2, 0))
	local want = if zone then zone.id else nil
	if want == current then
		return
	end
	-- going into a room takes that room's fade in; leaving takes the room being left's fade out
	local seconds
	if want then
		seconds = cfg.Profiles[want].FadeIn
	else
		seconds = (current and cfg.Profiles[current].FadeOut) or 1.5
	end
	current = want
	apply(want, seconds)
end

function LightZoneController.Init() end

function LightZoneController.Start()
	cfg = Config.get("LightZones")
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		capture()
		for _, instance in CollectionService:GetTagged(cfg.Tag) do
			register(instance)
		end
		CollectionService:GetInstanceAddedSignal(cfg.Tag):Connect(register)
		CollectionService:GetInstanceRemovedSignal(cfg.Tag):Connect(function(instance)
			if instance:IsA("BasePart") then
				parts[instance] = nil
			end
		end)
		while true do
			if next(parts) ~= nil or current ~= nil then
				step()
			end
			task.wait(STEP_SECONDS)
		end
	end)
end

return LightZoneController
