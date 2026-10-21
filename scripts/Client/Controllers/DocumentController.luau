--!strict
--[[
	DocumentController
	Opens a page on this player's screen when the server sends one
	(`DocumentEvent`): the Kitchens' recipe, and every letter and roll after it.

	The UI is built on the first page, so the Hub (which never sends one)
	builds nothing.

	Place: client (boots in both places; active only where the server sends).
	Phase: Trials.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local DocumentUi = require(script.Parent.Parent.UI.DocumentUi)

local DocumentController = {}

DocumentController.Name = "DocumentController"

local ui: DocumentUi.Handle? = nil

function DocumentController.Init() end

function DocumentController.Start()
	Net.getEvent("DocumentEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.kind ~= "open" then
			return
		end
		local handle = ui
		if not handle then
			handle = DocumentUi.create()
			ui = handle
		end
		handle.open({
			title = if typeof(payload.title) == "string" then payload.title else nil,
			sign = if typeof(payload.sign) == "string" then payload.sign else nil,
			lines = if typeof(payload.lines) == "table" then payload.lines else {},
		})
	end)
end

return DocumentController
