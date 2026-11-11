--!strict
--[[
	LanternController
	The player's lantern (Server/World/LanternService, docs/systems/Forest.md, docs/systems/Gear.md). It only asks: the
	light is the server's.

	  THE SHUTTER  G (it was F until 2026-11-10: F now puts the armour on), and on a phone a button: closes and opens
	               the lantern's shutter. Covered, the lantern is a glimmer at the feet and the Huntsman of the King's Wood
	               sees it only close; open, it lights the way and he sees it from far off.

	  THE BELT     With the mouse let go (L), a small line at the bottom of the screen: "Hang the lantern on your belt".
	               It then hangs at the left hip and both hands are free; "Take the lantern in your hand" brings it back.
	               (A spear or a bow needs both hands: taking one in hand hangs the lantern up by itself.)

	The phone's button is a picture and no word (the developer's rule for buttons on the edge of the screen): a small
	lantern, above the crouch button, shown on touch screens only while the player carries a lantern; it goes dark while
	covered. The player's own `LanternCovered` attribute (set by the server) is the truth.

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
local ViewController = require(script.Parent.ViewController)

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
	local belt = Net.getEvent("RequestLanternBelt")

	local function lantern(): Instance?
		local character = player.Character
		return character and character:FindFirstChild("HeldLantern")
	end

	local function toggle()
		if lantern() then
			request:FireServer(player:GetAttribute("LanternCovered") ~= true)
		end
	end

	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

	-- the belt: a line shown while the mouse is free
	ViewController.chip("lantern", function(): string?
		local held = lantern()
		if not held then
			return nil
		end
		return if held:GetAttribute("OnBelt") == true then "Take the lantern in your hand" else "Hang the lantern on your belt"
	end, function()
		local held = lantern()
		if held then
			belt:FireServer(held:GetAttribute("OnBelt") ~= true)
		end
	end)

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
			Position = UDim2.new(1, -150, 1, -214 - 64),
			Size = UDim2.fromOffset(56, 56),
			OnClick = toggle,
		})
		-- shown only with a lantern; a gold edge while it is OPEN (the light is on)
		local function refresh()
			gui.Enabled = lantern() ~= nil
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
