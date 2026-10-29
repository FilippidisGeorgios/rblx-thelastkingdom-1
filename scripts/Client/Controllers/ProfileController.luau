--!strict
--[[
	ProfileController
	Opens the MUSTER ROLL (UI/ProfileUI) in the Hub: the key P, or the small ROLL button in the corner
	(which is also the touch way in). Every time it opens it asks the server for the page and draws what
	comes back; the server builds it from this player's own profile, so there is nothing to decide here.

	Place: Kingdom Hub only (the same Client tree boots in both places; the Roll lives where the
	profile is authoritative). Phase: Profiles.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.ProfileController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local ProfileUI = require(Client.UI.ProfileUI)
local Theme = require(Client.UI.Theme)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local ProfileController = {}

ProfileController.Name = "ProfileController"

local MARGIN = 28

local ask: RemoteEvent

local function open()
	ProfileUI.open()
	ask:FireServer()
end

local function toggle()
	if ProfileUI.isOpen() then
		ProfileUI.close()
	else
		open()
	end
end

local function makeButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RollButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "Roll"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
	button.Size = UDim2.fromOffset(46, 46)
	button.BackgroundColor3 = Theme.Color.Ink
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.Text = "ROLL"
	button.TextSize = 11
	button.TextColor3 = Theme.Color.Gold
	button.Parent = gui
	Theme.applyFont(button, Theme.Role.Strong)
	Theme.corner(button)
	Theme.goldStroke(button, 1.2)
	button.Activated:Connect(toggle)
end

function ProfileController.Init() end

function ProfileController.Start()
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.KingdomHub then
		return
	end

	ask = Net.getEvent("RequestProfile")
	ProfileUI.mount()
	makeButton()

	Net.getEvent("ProfileEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ProfileUI.setPayload(payload)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			toggle()
		end
	end)
end

return ProfileController
