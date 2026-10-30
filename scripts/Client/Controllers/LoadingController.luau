--!strict
--[[
	LoadingController
	Tells the server when this player's loading screen is gone.

	The loading screen (ReplicatedFirst.Loading) is a LocalScript that runs before the rest of the game exists, so
	it cannot reach the networking. When its bar is full it sets the attribute `TLKLoaded` on ReplicatedFirst; this
	controller waits for that and sends one `ClientReady`. In the Forgotten Lands the arrival scene does not begin
	until every player in it has said so (or a time limit has run out), so nobody's first seconds of it play
	behind a loading bar.

	If the screen never reports (it failed), a message goes anyway after `GIVE_UP_SECONDS`, so a broken screen can
	never hold a party at the gate.

	Place: client (boots in both places).
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local LoadingController = {}

LoadingController.Name = "LoadingController"

local GIVE_UP_SECONDS = 60

function LoadingController.Init() end

function LoadingController.Start()
	local sent = false
	local function send()
		if sent then
			return
		end
		sent = true
		Net.getEvent("ClientReady"):FireServer()
	end

	if ReplicatedFirst:GetAttribute("TLKLoaded") then
		send()
		return
	end
	ReplicatedFirst:GetAttributeChangedSignal("TLKLoaded"):Connect(function()
		if ReplicatedFirst:GetAttribute("TLKLoaded") then
			send()
		end
	end)
	task.delay(GIVE_UP_SECONDS, send)
end

return LoadingController
