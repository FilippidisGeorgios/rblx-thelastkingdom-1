--!strict
--[[
	SettingsService
	Keeps what a player chose in the Settings panel (the picture quality and the shadows switch) in their
	profile, and hands it to their client as two attributes (`GfxQuality`, `GfxShadows`), which is how the client
	knows in BOTH places: a choice made in the Hub is already there when the player arrives in the castle.

	The client only REQUESTS (`RequestSettings`); `Shared/PlayerSettings` checks the request, so nothing but a
	quality that exists and a true or a false can ever be kept. The save is deferred a few seconds so a player
	trying the four qualities one after another writes once, not four times.

	Place: shared (both places). Phase: Settings.

	Location: ServerScriptService.Server.Services.SettingsService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local DataService = require(script.Parent.DataService)
local SaveService = require(script.Parent.SaveService)
local Config = require(ReplicatedStorage.Shared.Config)
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

-- Writes the player's kept choice onto them. A choice never made leaves the attribute empty, so the client
-- falls back to what suits its device.
local function publish(player: Player, settings: PlayerSettings.Settings)
	player:SetAttribute("GfxQuality", settings.graphics)
	player:SetAttribute("GfxShadows", settings.shadows)
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
	local current = PlayerSettings.clean(profile.settings, graphics)
	local nextSettings, changed = PlayerSettings.apply(current, request, graphics)
	if not changed then
		return
	end
	profile.settings = nextSettings
	publish(player, nextSettings)
	scheduleSave(player)
	log:info(("%s: picture %s, shadows %s"):format(player.Name, tostring(nextSettings.graphics), tostring(nextSettings.shadows)))
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
			publish(player, profile.settings)
		end
	end)
end

function SettingsService.Init() end

function SettingsService.Start()
	Net.getEvent("RequestSettings").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onJoined)
	for _, player in Players:GetPlayers() do
		onJoined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
		saveToken[player] = nil
	end)
	log:info("ready")
end

return SettingsService
