--!strict
--[[
	GearController
	The keys for what a player wears on the back (Server/World/GearService, configs/Gear, docs/systems/Gear.md). It only
	asks: what is worn, and what it does, is the server's.

	  F        with the ARMOUR on the back: puts it on (it appears piece by piece while the arms pull it on) and takes it
	           off again. With the quiver on the back F does nothing.

	  THE BACK holds one thing, the armour or the quiver. With the mouse let go (L) a small line at the bottom of the
	           screen changes it: "Carry the quiver on your back" / "Carry the armour on your back". (Armour that is
	           being worn has to come off first.)

	The player attributes `Back` ("armour" | "quiver"), `ArmourOn` and `Arrows` are the truth (set by the server).

	Place: client (boots in both places; active only in the Forgotten Lands).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local ViewController = require(script.Parent.ViewController)

local GearController = {}

GearController.Name = "GearController"

function GearController.Init() end

function GearController.Start()
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end
	local player = Players.LocalPlayer
	local cfg = Config.get("Gear")
	local armour = Net.getEvent("RequestArmour")
	local back = Net.getEvent("RequestBack")

	local function alive(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	end

	ContextActionService:BindAction("TLKArmour", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin and alive() and player:GetAttribute("Back") == "armour" then
			armour:FireServer(player:GetAttribute("ArmourOn") ~= true)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.DPadUp)

	ViewController.chip("back", function(): string?
		if not alive() then
			return nil
		end
		local have = player:GetAttribute("Back")
		if have == "armour" then
			if player:GetAttribute("ArmourOn") == true then
				return nil -- take it off first (F)
			end
			return "Carry the " .. string.lower(cfg.Back.Labels.quiver) .. " on your back"
		elseif have == "quiver" then
			return "Carry the " .. string.lower(cfg.Back.Labels.armour) .. " on your back"
		end
		return nil
	end, function()
		local have = player:GetAttribute("Back")
		back:FireServer(if have == "armour" then "quiver" else "armour")
	end)
end

return GearController
