--!strict
--[[
	SettingsService
	Keeps what a player chose in the Settings panel in their profile, and hands it to their client as attributes on the
	player, which is how the client knows in BOTH places: a choice made in the lobby is already there when the player
	arrives in the castle.

	  GfxQuality, GfxShadows   the picture quality and the shadows switch (Controllers/GraphicsController)
	  ViewFov, ViewBob         the field of view and the step of the picture (Controllers/ViewController)
	  CrouchHold               Ctrl held to crouch, or pressed once (Controllers/CrouchController)
	  GfxLocked, GfxCeiling    in the castle only: the quality may only go DOWN there, and this is the best one that may
	                           still be chosen (see below)

	The client only REQUESTS (`RequestSettings`); `Shared/PlayerSettings` checks the request, so nothing but a quality
	that exists, a true or a false and a field of view inside the allowed range can ever be kept. The save is deferred a
	few seconds so a player trying the four qualities one after another writes once, not four times.

	ONLY DOWN INSIDE A RUN (configs/Graphics.Lock; the developer, 2026-11-10). In the Forgotten Lands a quality that was
	lowered cannot be raised again until the player is back in the lobby. The ceiling starts at the quality the player
	arrived with (one never chosen: whatever their device starts at, which only their client knows, so the ceiling is
	left open until the first choice) and comes down with every lower choice. `PlayerSettings.apply` refuses anything
	above it. In the lobby there is no ceiling.

	Place: shared (both places). Phase: Settings.

	Location: ServerScriptService.Server.Services.SettingsService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local GameService = require(script.Parent.GameService)
local SaveService = require(script.Parent.SaveService)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local SettingsService = {}

SettingsService.Name = "SettingsService"

local log = Logger.new("SettingsService")

local ASK_GAP = 0.15 -- seconds between two requests from one player
local SAVE_AFTER = 4 -- seconds of quiet before a change is written

local lastAsk: { [Player]: number } = {}
local saveToken: { [Player]: number } = {}
local ceiling: { [Player]: string } = {} -- the best quality still allowed (only where the lock holds)
local locked = false -- does this place hold the lock?

-- Writes the player's kept choice onto them. A choice never made leaves the attribute empty, so the client
-- falls back to what suits its device (or to the config's start).
local function publish(player: Player, settings: PlayerSettings.Settings)
	player:SetAttribute("GfxQuality", settings.graphics)
	player:SetAttribute("GfxShadows", settings.shadows)
	player:SetAttribute("ViewFov", settings.fov)
	player:SetAttribute("ViewBob", settings.headBob)
	player:SetAttribute("CrouchHold", settings.crouchHold)
	player:SetAttribute("GfxLocked", if locked then true else nil)
	player:SetAttribute("GfxCeiling", ceiling[player])
end

local function scheduleSave(player: Player)
	local token = (saveToken[player] or 0) + 1
	saveToken[player] = token
	task.delay(SAVE_AFTER, function()
		if saveToken[player] == token and player.Parent then
			SaveService.save(player)
		end
	end)
end

local function onRequest(player: Player, request: any)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < ASK_GAP then
		return
	end
	lastAsk[player] = now

	local profile = DataService.get(player)
	if not profile then
		return
	end
	local graphics = Config.get("Graphics")
	local view = Config.get("View")
	local current = PlayerSettings.clean(profile.settings, graphics)
	local nextSettings, changed = PlayerSettings.apply(current, request, graphics, {
		ceiling = if locked then ceiling[player] else nil,
		fovMin = view.Fov.Min,
		fovMax = view.Fov.Max,
	})
	if not changed then
		return
	end
	-- a quality chosen where the lock holds is the new ceiling (it can only have been the same or lower)
	if locked and nextSettings.graphics and nextSettings.graphics ~= current.graphics then
		ceiling[player] = nextSettings.graphics
	end
	profile.settings = nextSettings
	publish(player, nextSettings)
	scheduleSave(player)
	log:info(("%s: picture %s, shadows %s, view %s, step %s, hold to crouch %s%s"):format(
		player.Name,
		tostring(nextSettings.graphics),
		tostring(nextSettings.shadows),
		tostring(nextSettings.fov),
		tostring(nextSettings.headBob),
		tostring(nextSettings.crouchHold),
		if locked then ", ceiling " .. tostring(ceiling[player]) else ""
	))
end

-- The profile loads a moment after the player joins; publish as soon as it is there.
local function onJoined(player: Player)
	task.spawn(function()
		local waited = 0
		local profile = DataService.get(player)
		while not profile and waited < 15 and player.Parent do
			task.wait(0.25)
			waited += 0.25
			profile = DataService.get(player)
		end
		if profile and player.Parent then
			local graphics = Config.get("Graphics")
			profile.settings = PlayerSettings.clean(profile.settings, graphics)
			if locked then
				ceiling[player] = profile.settings.graphics -- nil: never chosen, open until the first choice
			end
			publish(player, profile.settings)
		end
	end)
end

function SettingsService.Init() end

function SettingsService.Start()
	-- where the quality may only go down
	local role = GameService.getPlaceRole()
	for _, place in Config.get("Graphics").Lock.Places do
		if (place == "ForgottenLands" and role == Constants.PlaceRole.World) or (place == "KingdomHub" and role == Constants.PlaceRole.Hub) then
			locked = true
		end
	end

	Net.getEvent("RequestSettings").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onJoined)
	for _, player in Players:GetPlayers() do
		onJoined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
		saveToken[player] = nil
		ceiling[player] = nil
	end)
	log:info(if locked then "ready: here the picture quality may only be lowered" else "ready")
end

return SettingsService
