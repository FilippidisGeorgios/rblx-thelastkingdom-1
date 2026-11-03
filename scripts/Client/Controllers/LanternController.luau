--!strict
--[[
	LanternController
	The key (F) and, on a phone, the button that close and open the shutter of the player's lantern (Server/World/
	LanternService, docs/systems/Forest.md). Covered, the lantern is a glimmer at the feet and the Huntsman of the King's
	Wood sees it only close; open, it lights the way and he sees it from far off. It only asks: the light is the server's.

	The button is a picture and no word (the developer's rule for buttons on the edge of the screen): a small lantern,
	above the crouch button, shown on touch screens only while the player carries a lantern; it goes dark while covered.
	The player's own `LanternCovered` attribute (set by the server) is the truth.

	Place: client (boots in both places; active only in the Forgotten Lands).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local IconButton = require(Client.UI.IconButton)

local LanternController = {}

LanternController.Name = "LanternController"

local ACTION = "TLKLanternCover"

function LanternController.Init() end

function LanternController.Start()
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end
	local player = Players.LocalPlayer
	local request = Net.getEvent("RequestLanternCover")

	local function holding(): boolean
		local character = player.Character
		return character ~= nil and character:FindFirstChild("HeldLantern") ~= nil
	end

	local function toggle()
		if holding() then
			request:FireServer(player:GetAttribute("LanternCovered") ~= true)
		end
	end

	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "LanternButton"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 6
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = player:WaitForChild("PlayerGui")

		local handle = IconButton.create({
			Name = "Lantern",
			Parent = gui,
			Icon = "lantern",
			IconSize = 30,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -150, 1, -214),
			Size = UDim2.fromOffset(56, 56),
			OnClick = toggle,
		})
		-- shown only with a lantern in the hand; a gold edge while it is OPEN (the light is on)
		local function refresh()
			gui.Enabled = holding()
			handle.setActive(player:GetAttribute("LanternCovered") ~= true)
		end
		player:GetAttributeChangedSignal("LanternCovered"):Connect(refresh)
		task.spawn(function()
			while true do
				refresh()
				task.wait(1)
			end
		end)
	end
end

return LanternController
