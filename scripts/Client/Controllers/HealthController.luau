--!strict
--[[
	HealthController
	Shows the player's health as the tiny bar in the bottom-left corner (UI/HealthBar) and switches Roblox's own health
	bar off, so that this is the only one.

	Roblox's bar is switched off in BOTH places. Ours is drawn only where `configs/Hud.HealthBar.PlacesShown` says (the
	Forgotten Lands: there is nothing to hurt you in the Hub).

	The arrival scene switches every Roblox gui off and then ON again when it ends, which would bring the health bar
	back; this controller looks once a second and switches it off again.

	Place: client (boots in both places).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Client = script.Parent.Parent
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local HealthBar = require(Client.UI.HealthBar)

local HealthController = {}

HealthController.Name = "HealthController"

local function robloxBarOff()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end

local function shownHere(): boolean
	local places = Config.get("Hud").HealthBar.PlacesShown
	if game.PlaceId == 0 then
		-- an unpublished local place: show it where the castle's folder exists
		return table.find(places, "ForgottenLands") ~= nil and workspace:FindFirstChild("Gameplay") ~= nil
	end
	return (table.find(places, "ForgottenLands") ~= nil and game.PlaceId == Constants.PlaceIds.ForgottenLands)
		or (table.find(places, "KingdomHub") ~= nil and game.PlaceId == Constants.PlaceIds.KingdomHub)
end

function HealthController.Init() end

function HealthController.Start()
	-- Roblox's bar: off now (the call can fail until the core scripts are up, so keep trying for a while), and off
	-- again whenever something switches it on.
	robloxBarOff()
	-- (`CoreGuiChangedSignal` is not open to game scripts, so this looks once a second: cheap, and the bar is never
	-- back for longer than that.)
	task.spawn(function()
		while true do
			local ok, enabled = pcall(function()
				return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
			end)
			if not ok or enabled then
				robloxBarOff()
			end
			task.wait(1)
		end
	end)

	if not shownHere() then
		return
	end

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBarGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = HealthBar.create(gui)

	local connections: { RBXScriptConnection } = {}
	local function follow(character: Model)
		for _, c in connections do
			c:Disconnect()
		end
		connections = {}
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		local function refresh()
			bar.set(humanoid.Health, humanoid.MaxHealth)
		end
		table.insert(connections, humanoid.HealthChanged:Connect(refresh))
		table.insert(connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
		refresh()
	end
	player.CharacterAdded:Connect(follow)
	if player.Character then
		task.spawn(follow, player.Character)
	end
end

return HealthController
