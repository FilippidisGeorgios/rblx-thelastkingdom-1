--!strict
--[[
	CampController
	Opens the camp bench's panel when the server sends it (`CampEvent`: "open" on the
	prompt, "update" after something was made) and asks for a recipe to be made when
	a button is pressed (`RequestCraft`). The server decides everything: the panel only
	shows what it was told and asks.

	The Hub never sends a CampEvent, so there the UI is never built.

	Place: client (boots in both places; active only where the server sends).
	Phase: Spoils.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local CampUi = require(script.Parent.Parent.UI.CampUi)

local CampController = {}

CampController.Name = "CampController"

local ui: CampUi.Handle? = nil

function CampController.Init() end

function CampController.Start()
	Net.getEvent("CampEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.recipes) ~= "table" or typeof(payload.at) ~= "Vector3" then
			return
		end
		local handle = ui
		if not handle then
			handle = CampUi.create(function(id: string)
				Net.getEvent("RequestCraft"):FireServer(id)
			end)
			ui = handle
		end
		if payload.kind == "update" and not handle.isOpen() then
			return
		end
		handle.show({
			at = payload.at,
			reach = if typeof(payload.reach) == "number" then payload.reach else 18,
			recipes = payload.recipes,
			made = if typeof(payload.made) == "string" then payload.made else nil,
		})
	end)
	-- the run is over: the bench has nothing more to make
	Net.getEvent("EndingEvent").OnClientEvent:Connect(function()
		if ui then
			ui.close()
		end
	end)
end

return CampController
