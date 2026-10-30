--!strict
--[[
	CrouchController
	The key (C) and, on a phone, the button that ask the server to duck down or stand up (Server/World/CrouchService,
	configs/Crouch). It only asks: the body, the speed and the room to stand are the server's.

	The button is a picture and no word (the developer's rule for buttons on the edge of the screen): a small figure
	ducking, on the right above the jump button, shown on touch screens only; it lights while you are crouched. The
	player's own `Crouching` attribute (set by the server) is the truth, so a press that is refused (a low ceiling)
	leaves the button as it was.

	Place: client (boots in both places; active only in the Forgotten Lands).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local IconButton = require(Client.UI.IconButton)

local CrouchController = {}

CrouchController.Name = "CrouchController"

local ACTION = "TLKCrouch"

function CrouchController.Init() end

function CrouchController.Start()
	-- stand down anywhere that is definitely not the Forgotten Lands (an unpublished local place reports PlaceId 0)
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end
	local cfg = Config.get("Crouch")
	if not cfg.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local request = Net.getEvent("RequestCrouch")

	local function toggle()
		request:FireServer(player:GetAttribute("Crouching") ~= true)
	end

	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[cfg.Key])

	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CrouchButton"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 6
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = player:WaitForChild("PlayerGui")

		local handle = IconButton.create({
			Name = "Crouch",
			Parent = gui,
			Icon = "crouch",
			IconSize = 30,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -150, 1, -150),
			Size = UDim2.fromOffset(56, 56),
			OnClick = toggle,
		})
		-- a gold edge while crouched
		local function lit()
			handle.setActive(player:GetAttribute("Crouching") == true)
		end
		player:GetAttributeChangedSignal("Crouching"):Connect(lit)
		lit()
	end
end

return CrouchController
