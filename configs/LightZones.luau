--!strict
--[[
	Config: LightZones
	How dark a room is made, for the rooms that are underground or shut in.

	A real ceiling stops the sun and the moon, but Roblox also lights every room with a flat "ambient" light and a
	reflection of the sky, which a ceiling cannot stop: a cellar built under the castle would still glow faintly.
	A light zone turns those two down while a player is inside a box, and brings them back when the player leaves.
	Torches, fires and lanterns are then the only light, which is what makes a place frightening.

	THE FAIRNESS RULE (the same as `Graphics.luau`): a zone is part of the PLACE, so it is the same for every player,
	whatever picture quality they chose. Nothing here is read from the player's settings. And a zone may set only the
	things below (a spec checks it): how much ambient light, how bright the sky reflection is, how thick the haze.

	WHERE THE BOXES ARE. Parts in the place, tagged `TLK_LightZone`, with the attribute `Profile` (a name from
	`Profiles` below) and an optional `Priority` number. They are invisible, do not collide and cannot be touched.
	`tools/BuildCellar.luau` makes the cellar's. Several may overlap: see `Shared/LightZone` (the higher priority, then
	the smaller box).

	Profile fields (all optional except the fades):
	  Ambient, OutdoorAmbient              the flat light in a room (Color3)
	  Brightness                           the sun / moon's strength
	  ExposureCompensation                 how bright the picture is overall
	  EnvironmentDiffuseScale, EnvironmentSpecularScale   how much of the sky is reflected into the room
	  AtmosphereDensity                    the thickness of the haze
	  FadeIn, FadeOut                      seconds to go into the room's light, and back to the place's own

	Read via: Config.get("LightZones")
]]

local LightZones = {
	Tag = "TLK_LightZone",

	Profiles = {
		-- the Catacombs (docs/systems/Catacombs.md): NOTHING lights the place. The lantern each body carries and the odd candle
		-- by a letter are all there is, so a corridor ends where the lantern's light does.
		Catacombs = {
			Ambient = Color3.fromRGB(0, 0, 0),
			OutdoorAmbient = Color3.fromRGB(0, 0, 0),
			Brightness = 0,
			ExposureCompensation = 0.85,
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0,
			AtmosphereDensity = 0,
			FadeIn = 1.6,
			FadeOut = 2.2,
		},
		-- the mouth of the cave and the top of the exit stair: the day goes out slowly as you go in
		CatacombMouth = {
			Ambient = Color3.fromRGB(14, 14, 18),
			OutdoorAmbient = Color3.fromRGB(18, 18, 24),
			Brightness = 0.15,
			ExposureCompensation = 0.7,
			EnvironmentDiffuseScale = 0.06,
			EnvironmentSpecularScale = 0.08,
			AtmosphereDensity = 0.05,
			FadeIn = 1.2,
			FadeOut = 1.6,
		},

		-- under the ground: black but for what burns
		Cellar = {
			Ambient = Color3.fromRGB(6, 6, 8),
			OutdoorAmbient = Color3.fromRGB(8, 8, 11),
			Brightness = 0.1,
			ExposureCompensation = 0.55,
			EnvironmentDiffuseScale = 0.05,
			EnvironmentSpecularScale = 0.08,
			AtmosphereDensity = 0.08,
			FadeIn = 1.1,
			FadeOut = 1.6,
		},
	},
}

return table.freeze(LightZones)
