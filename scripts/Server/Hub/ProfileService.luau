--!strict
--[[
	ProfileService
	The player's own page, the MUSTER ROLL (docs/systems/Profile.md): level, Might, arms, record and
	collection, built from the profile the server already holds (Server/Domain/PlayerCard) and sent to
	the one player who asked.

	Read only. The client sends no number and changes nothing: it asks "my roll", the server answers with
	a card built from THAT player's profile (a request carries no player id, so nobody can ask for another
	player's page). Opening a friend's roll is a later feature with its own consent rules.

	Place: Kingdom Hub only. Phase: Profiles.

	Location: ServerScriptService.Server.Hub.ProfileService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local PlayerCard = require(Server.Domain.PlayerCard)
local DataService = require(Server.Services.DataService)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ProfileService = {}

ProfileService.Name = "ProfileService"

local log = Logger.new("ProfileService")

local ASK_GAP = 0.4 -- seconds between two asks from one player

local ctx: PlayerCard.Context? = nil
local profileEvent: RemoteEvent
local lastAsk: { [Player]: number } = {}

-- A player's name, level, rank, Might and Renown, for the train to show beside them. Nil without a profile.
function ProfileService.brief(player: Player): PlayerCard.Brief?
	local profile = DataService.get(player)
	local context = ctx
	if not profile or not context then
		return nil
	end
	return PlayerCard.brief(PlayerCard.build(profile, context))
end

local function onRequest(player: Player)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < ASK_GAP then
		return
	end
	lastAsk[player] = now

	local profile = DataService.get(player)
	local context = ctx
	if not profile or not context then
		profileEvent:FireClient(player, { kind = "unavailable" })
		return
	end
	profileEvent:FireClient(player, { kind = "card", card = PlayerCard.build(profile, context) })
end

function ProfileService.Init()
	ctx = {
		experience = Config.get("Experience"),
		weapons = Config.get("Weapons"),
		curve = Config.get("Economy").Upgrades.Weapon,
		profileCfg = Config.get("Profile"),
		chapel = Config.get("Chapel"),
		pages = Config.get("Pages"),
	}
end

function ProfileService.Start()
	profileEvent = Net.getEvent("ProfileEvent")
	Net.getEvent("RequestProfile").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
	log:info("ready")
end

return ProfileService
