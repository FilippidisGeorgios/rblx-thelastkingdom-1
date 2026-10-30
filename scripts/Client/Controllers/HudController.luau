--!strict
--[[
	HudController
	The two small buttons beside the chat, at the top left, in both places:

	  PROFILE   a head and shoulders (no word on it). Opens the Muster Roll (Controllers/ProfileController).
	  SETTINGS  a grey cog (no word on it). Opens the Settings panel (UI/SettingsUI): the picture quality and the shadows switch.

	(The INVENTORY tab on the left edge belongs to UI/BackpackHud, which also draws the pack and the Hub's inventory.)

	It wires the Settings panel to the GraphicsController: a press is sent to the server as a request, and the panel
	shows whatever the server has kept.

	Place: shared client (both places). Phase: Settings.

	Location: StarterPlayer.StarterPlayerScripts.Client.Controllers.HudController
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local IconButton = require(Client.UI.IconButton)
local SettingsUI = require(Client.UI.SettingsUI)
local ProfileController = require(script.Parent.ProfileController)
local GraphicsController = require(script.Parent.GraphicsController)

local HudController = {}

HudController.Name = "HudController"

-- Roblox's own menu and chat buttons take the left of the top bar; ours start where its free part begins
-- (`GuiService.TopbarInset`, which moves with the device and the player's own settings).
local FALLBACK_X = 172
local GAP = 6
local BUTTON_W = 48
local BUTTON_H = 48

function HudController.Init() end

function HudController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudButtons"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local profile = IconButton.create({
		Name = "ProfileButton",
		Parent = gui,
		Icon = "person",
		IconSize = 28,
		Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
		OnClick = function()
			ProfileController.toggle()
		end,
	})

	local gear = IconButton.create({
		Name = "SettingsButton",
		Parent = gui,
		Icon = "gear",
		Tint = Color3.fromRGB(168, 168, 174), -- a grey cog
		IconSize = 30,
		Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
		OnClick = function()
			SettingsUI.toggle()
		end,
	})

	-- sit just after Roblox's own buttons, wherever this device puts them
	local function place()
		local x = FALLBACK_X
		local ok, inset = pcall(function()
			return GuiService.TopbarInset
		end)
		if ok and inset and inset.Min.X > 0 then
			x = inset.Min.X + 8
		end
		profile.button.Position = UDim2.fromOffset(x, 5)
		gear.button.Position = UDim2.fromOffset(x + BUTTON_W + GAP, 5)
	end
	place()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	end)

	SettingsUI.mount(function(change)
		GraphicsController.request(change)
	end)
	GraphicsController.observe(function(quality: string, shadows: boolean)
		SettingsUI.setState(quality, shadows)
	end)
end

return HudController
