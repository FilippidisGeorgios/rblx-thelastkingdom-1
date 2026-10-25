--!strict
--[[
	EndingController
	Closes the screen on the end of the run when the server sends it (`EndingEvent`, from Trial/Exit when
	the whole party has gone up and stands in the light). The Hub never sends one, so there it does nothing.

	Place: client (boots in both places; active only where the server sends).
	Phase: Trials.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local EndingUi = require(script.Parent.Parent.UI.EndingUi)

local EndingController = {}

EndingController.Name = "EndingController"

local playing = false

function EndingController.Init() end

function EndingController.Start()
	Net.getEvent("EndingEvent").OnClientEvent:Connect(function(payload)
		if playing or typeof(payload) ~= "table" then
			return
		end
		playing = true
		EndingUi.play({
			title = if typeof(payload.title) == "string" then payload.title else nil,
			subtitle = if typeof(payload.subtitle) == "string" then payload.subtitle else nil,
			lines = if typeof(payload.lines) == "table" then payload.lines else nil,
			footer = if typeof(payload.footer) == "string" then payload.footer else nil,
		})
	end)
end

return EndingController
