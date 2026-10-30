--!strict
--[[
	ProfileController
	Opens the MUSTER ROLL (UI/ProfileUI): from the PROFILE button beside the chat (Controllers/HudController builds
	it and calls `toggle`), or with the key P in the Hub. Every time it opens it asks the server for the page and draws
	what comes back; the server builds it from this player's own profile, so there is nothing to decide here.

	The Roll opens in the Hub and in the castle alike: it is the player's own page, read only.

	Place: shared client (both places). Phase: Profiles.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.ProfileController
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local ProfileUI = require(Client.UI.ProfileUI)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local ProfileController = {}

ProfileController.Name = "ProfileController"

local ask: RemoteEvent

local function open()
	ProfileUI.open()
	ask:FireServer()
end

-- Opens the page, or closes it if it is open. The PROFILE button calls this.
function ProfileController.toggle()
	if ProfileUI.isOpen() then
		ProfileUI.close()
	else
		open()
	end
end

function ProfileController.Init() end

function ProfileController.Start()
	ask = Net.getEvent("RequestProfile")
	ProfileUI.mount()

	Net.getEvent("ProfileEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ProfileUI.setPayload(payload)
		end
	end)

	-- the key P is the Hub's; in the castle the button is the way in (the key is the weapon-tuning mode's there)
	if game.PlaceId == 0 or game.PlaceId == Constants.PlaceIds.KingdomHub then
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.P then
				ProfileController.toggle()
			end
		end)
	end
end

return ProfileController
