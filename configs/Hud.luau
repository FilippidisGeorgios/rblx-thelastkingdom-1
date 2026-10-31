--!strict
--[[
	Config: Hud
	The small things on the player's own screen that are not panels.

	HEALTH BAR. A tiny bar in the bottom-left corner of every player's screen, hardly there: a black outline, a fill that
	goes green, yellow, orange, red as health falls, and the percentage left in very small letters inside it. Roblox's own
	health bar (top right) is switched off in its favour, so there is only this one.

	  Width, Height   in pixels (a phone is not given a different size: it is meant to be almost not there)
	  Margin          from the screen's left and bottom edges
	  TextSize        the percentage's size
	  Stops           the colour at a share of health, from full to empty; between two stops the colour is blended
	                  (checked by `HealthColor.spec`: they must run from 1 down to 0)
	  PlacesShown     the bar is drawn only in these places: there is nothing to hurt you in the Hub

	Read via: Config.get("Hud")
]]

local Hud = {
	HealthBar = {
		Width = 92,
		Height = 11,
		Margin = 12,
		TextSize = 9,
		Stops = {
			{ At = 1.00, Color = Color3.fromRGB(86, 186, 82) }, -- green
			{ At = 0.66, Color = Color3.fromRGB(226, 210, 70) }, -- yellow
			{ At = 0.33, Color = Color3.fromRGB(232, 140, 48) }, -- orange
			{ At = 0.00, Color = Color3.fromRGB(206, 48, 44) }, -- red
		},
		PlacesShown = { "ForgottenLands" },
	},
}

return table.freeze(Hud)
