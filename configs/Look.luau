--!strict
--[[
	Config: Look
	How a place LOOKS, as data: lighting, atmosphere, sky, clouds, post-processing and
	the colour of the terrain's materials. One file for both places, so the Kingdom
	Hub and the Forgotten Lands can never drift apart by accident — they are the same
	world at two different hours, and this is where "the same world" is written down.

	Applied at EDIT TIME by `tools/ApplyLook.luau`, which bakes a preset into the
	place. Nothing here is read while the game runs, so a look costs nothing per frame.

	Read via: Config.get("Look")

	SCHEMA — every section is optional; a preset only states what it changes.

		Lighting  = { <Lighting property> = value, ... }
		Atmosphere = { <Atmosphere property> = value, ... }
		Sky       = { <Sky property> = value, ... }
		Clouds    = nil    leave the terrain's Clouds object alone
		          = false  remove it (what "no clouds" means)
		          = { Enabled, Cover, Density, Color }   create it if missing, then set
		Effects   = { [instance name under Lighting] = { <property> = value, ... } }
		            An effect that is not there is skipped with a warning, never created.
		Terrain   = { [Enum.Material name] = Color3 }   the colour of that material,
		            everywhere. Voxels are never touched, only how a material is painted.
		Water     = { <Terrain water property> = value, ... }   WaterColor,
		            WaterTransparency, WaterReflectance, WaterWaveSize, WaterWaveSpeed.

	WHAT CANNOT BE HERE: `Lighting.Technology` (Future / ShadowMap / ...). Roblox does
	not let a script read or write it; it is set by hand in Studio's Properties panel.
	Both places are already on Future.

	PRESETS
		Baseline             the Hub exactly as it was before the art pass began
		                     (2026-10-17), read live from Studio. Values are rounded to
		                     three significant digits — the .rbxl backup is the exact copy.
		                     Apply it to undo any other preset.
		DarkRealistic        "Look A". Mordhau / Kingdom Come / Vermintide: overcast,
		                     desaturated, cold ambient, warm light only from fire.
		                     LOCKED on 2026-10-17 as the base look of both places —
		                     see docs/systems/Presentation.md.
		StylizedDarkFantasy  "Look B". Valheim / V Rising: dusk, strong silhouettes,
		                     saturated, hard contrast between warm light and cold shadow.

	DarkRealistic was chosen from the A/B test and retuned against the painted ground
	(tools/PaintGround.luau). StylizedDarkFantasy is still the first draft from that test,
	kept as a reference: its moon, stars and violet horizon glow are worth borrowing.

	FORGOTTEN LANDS PRESETS (its effects are named WorldGrade / Bloom / ColorGrading)
		ForgottenBaseline    the Forgotten Lands exactly as it was on 2026-10-18, read
		                     live from Studio. Apply it to undo ForgottenDusk.
		ForgottenDusk        Look A, an hour later: the sun is gone, the sky is cold
		                     blue-grey under a heavy deck, and the only colour left on the
		                     horizon is a dull bruise of red over the castle. Still no
		                     warm light that is not fire.
]]

local Look = {
	Presets = {

		----------------------------------------------------------------------
		Baseline = {
			Lighting = {
				ClockTime = 12.8,
				GeographicLatitude = 20,
				Brightness = 2.22,
				Ambient = Color3.fromRGB(26, 28, 38),
				OutdoorAmbient = Color3.fromRGB(52, 55, 74),
				ColorShift_Top = Color3.fromRGB(130, 92, 68),
				ColorShift_Bottom = Color3.fromRGB(38, 42, 66),
				ExposureCompensation = 0.15,
				EnvironmentDiffuseScale = 0.35,
				EnvironmentSpecularScale = 0.4,
				ShadowSoftness = 0.6,
				GlobalShadows = true,
			},
			Atmosphere = {
				Density = 0.35,
				Offset = 0.1,
				Color = Color3.fromRGB(188, 190, 202),
				Decay = Color3.fromRGB(84, 88, 110),
				Glare = 0.25,
				Haze = 2.4,
			},
			Sky = {
				CelestialBodiesShown = true,
				StarCount = 3000,
				MoonAngularSize = 11,
				SunAngularSize = 0,
			},
			Clouds = false,
			Effects = {
				SunRays = { Enabled = true, Intensity = 0.01, Spread = 0.1 },
				LobbyCC = {
					Enabled = true,
					Brightness = -0.03,
					Contrast = 0.12,
					Saturation = -0.2,
					TintColor = Color3.fromRGB(224, 220, 232),
				},
				LobbyBloom = { Enabled = true, Intensity = 0.7, Size = 24, Threshold = 1.05 },
				Bloom = { Enabled = true, Intensity = 1, Size = 24, Threshold = 2 },
				DepthOfField = {
					Enabled = false,
					FarIntensity = 0.1,
					FocusDistance = 0.05,
					InFocusRadius = 30,
					NearIntensity = 0.75,
				},
			},
			Terrain = {
				Grass = Color3.fromRGB(111, 126, 62),
				Mud = Color3.fromRGB(121, 112, 98),
				Ground = Color3.fromRGB(150, 132, 102),
				Sand = Color3.fromRGB(207, 203, 167),
				Rock = Color3.fromRGB(99, 100, 102),
				Cobblestone = Color3.fromRGB(134, 134, 118),
				Pavement = Color3.fromRGB(143, 144, 135),
			},
		},

		----------------------------------------------------------------------
		-- Look A. The sun is a smear behind cloud; everything is cold and flat
		-- except the fires, which are the only warm thing in the world.
		DarkRealistic = {
			Lighting = {
				ClockTime = 17,
				GeographicLatitude = 52,
				Brightness = 1.8,
				Ambient = Color3.fromRGB(34, 36, 44),
				OutdoorAmbient = Color3.fromRGB(58, 62, 74),
				ColorShift_Top = Color3.fromRGB(175, 165, 155), -- near neutral: warmth belongs to fire, not sun
				ColorShift_Bottom = Color3.fromRGB(30, 34, 44),
				ExposureCompensation = 0,
				EnvironmentDiffuseScale = 0.55,
				EnvironmentSpecularScale = 0.45,
				ShadowSoftness = 0.4,
				GlobalShadows = true,
			},
			Atmosphere = {
				Density = 0.42,
				Offset = 0.2,
				Color = Color3.fromRGB(164, 170, 182),
				Decay = Color3.fromRGB(88, 92, 102),
				Glare = 0,
				Haze = 2.2,
			},
			Sky = {
				CelestialBodiesShown = true,
				StarCount = 500,
				MoonAngularSize = 11,
				SunAngularSize = 0,
			},
			Clouds = { Enabled = true, Cover = 0.82, Density = 0.65, Color = Color3.fromRGB(122, 128, 140) },
			Effects = {
				SunRays = { Enabled = true, Intensity = 0.015, Spread = 0.15 },
				LobbyCC = {
					Enabled = true,
					Brightness = -0.02,
					Contrast = 0.18,
					Saturation = -0.28,
					TintColor = Color3.fromRGB(232, 226, 218),
				},
				-- Only the genuinely bright things (fire, lanterns) may bloom.
				LobbyBloom = { Enabled = true, Intensity = 0.28, Size = 20, Threshold = 1.6 },
				-- A second Bloom on top of LobbyBloom doubled every glow. Off.
				Bloom = { Enabled = false },
				DepthOfField = { Enabled = false },
			},
			Terrain = {
				Grass = Color3.fromRGB(66, 82, 44),
				Mud = Color3.fromRGB(52, 44, 38),
				Ground = Color3.fromRGB(84, 74, 62), -- packed earth
				-- No Sand is left once tools/PaintGround has run (the roads are Cobblestone now);
				-- this is only what a restored ground would look like.
				Sand = Color3.fromRGB(132, 118, 96),
				Rock = Color3.fromRGB(74, 74, 78),
				-- The roads are how a player finds the way, so the paving is a clear step lighter
				-- than the earth around it: it must still read as a cross from the air.
				Cobblestone = Color3.fromRGB(124, 120, 110),
				Pavement = Color3.fromRGB(100, 98, 92),
			},
		},

		----------------------------------------------------------------------
		-- Look B. The last light of the day: orange on the lit side, violet in
		-- the shade, and a sky that is allowed to be beautiful.
		StylizedDarkFantasy = {
			Lighting = {
				ClockTime = 18.1,
				GeographicLatitude = 40,
				Brightness = 2.4,
				Ambient = Color3.fromRGB(52, 44, 74),
				OutdoorAmbient = Color3.fromRGB(88, 74, 118),
				ColorShift_Top = Color3.fromRGB(255, 160, 90),
				ColorShift_Bottom = Color3.fromRGB(70, 56, 120),
				ExposureCompensation = 0.2,
				EnvironmentDiffuseScale = 0.5,
				EnvironmentSpecularScale = 0.35,
				ShadowSoftness = 0.25,
				GlobalShadows = true,
			},
			Atmosphere = {
				Density = 0.36,
				Offset = 0.12,
				Color = Color3.fromRGB(178, 140, 186),
				Decay = Color3.fromRGB(150, 80, 110),
				Glare = 0.7,
				Haze = 1.6,
			},
			Sky = {
				CelestialBodiesShown = true,
				StarCount = 3000,
				MoonAngularSize = 14,
				SunAngularSize = 0,
			},
			Clouds = { Enabled = true, Cover = 0.5, Density = 0.5, Color = Color3.fromRGB(190, 120, 150) },
			Effects = {
				SunRays = { Enabled = true, Intensity = 0.06, Spread = 0.3 },
				LobbyCC = {
					Enabled = true,
					Brightness = 0,
					Contrast = 0.25,
					Saturation = 0.12,
					TintColor = Color3.fromRGB(255, 232, 240),
				},
				LobbyBloom = { Enabled = true, Intensity = 0.7, Size = 32, Threshold = 1 },
				Bloom = { Enabled = false },
				-- A soft far blur is what makes the distance look painted.
				DepthOfField = {
					Enabled = true,
					FarIntensity = 0.25,
					FocusDistance = 90,
					InFocusRadius = 60,
					NearIntensity = 0,
				},
			},
			Terrain = {
				Grass = Color3.fromRGB(84, 116, 52),
				Mud = Color3.fromRGB(92, 64, 44),
				Ground = Color3.fromRGB(112, 84, 58),
				Sand = Color3.fromRGB(176, 142, 98),
				Rock = Color3.fromRGB(104, 92, 112),
				Cobblestone = Color3.fromRGB(128, 116, 112),
				Pavement = Color3.fromRGB(136, 126, 124),
			},
		},

		----------------------------------------------------------------------
		-- The Forgotten Lands as they were before their art pass. The undo.
		ForgottenBaseline = {
			Lighting = {
				ClockTime = 17.6,
				GeographicLatitude = 12,
				Brightness = 1.1,
				Ambient = Color3.fromRGB(28, 26, 34),
				OutdoorAmbient = Color3.fromRGB(74, 66, 74),
				ColorShift_Top = Color3.fromRGB(126, 82, 52),
				ColorShift_Bottom = Color3.fromRGB(28, 24, 32),
				ExposureCompensation = -0.15,
				EnvironmentDiffuseScale = 0.55,
				EnvironmentSpecularScale = 0.35,
				ShadowSoftness = 0.5,
				GlobalShadows = true,
			},
			Atmosphere = {
				Density = 0.3,
				Offset = 0.4,
				Color = Color3.fromRGB(39, 8, 8),
				Decay = Color3.fromRGB(88, 58, 59),
				Glare = 0.15,
				Haze = 2.8,
			},
			Sky = {
				CelestialBodiesShown = false,
				StarCount = 25,
				MoonAngularSize = 0,
				SunAngularSize = 0,
			},
			Clouds = false,
			Effects = {
				Bloom = { Enabled = true, Intensity = 0.5, Size = 20, Threshold = 1.1 },
				WorldGrade = {
					Enabled = true,
					Brightness = -0.02,
					Contrast = 0.12,
					Saturation = -0.22,
					TintColor = Color3.fromRGB(255, 238, 224),
				},
			},
			Terrain = {
				Ground = Color3.fromRGB(96, 82, 64),
				Grass = Color3.fromRGB(106, 127, 63),
				Mud = Color3.fromRGB(58, 46, 36),
				Rock = Color3.fromRGB(82, 78, 74),
				Slate = Color3.fromRGB(74, 72, 70),
				Cobblestone = Color3.fromRGB(132, 123, 90),
				Sand = Color3.fromRGB(143, 126, 95),
				Basalt = Color3.fromRGB(30, 30, 37),
				LeafyGrass = Color3.fromRGB(115, 132, 74),
			},
			Water = {
				WaterColor = Color3.fromRGB(13, 84, 92),
				WaterTransparency = 0.3,
				WaterReflectance = 1,
			},
		},

		----------------------------------------------------------------------
		-- Look A, an hour later. Cold, heavy, and legible: the castle must still
		-- read as a silhouette from the hill, so the sky is lighter than the
		-- stone and the ground is darker than both.
		ForgottenDusk = {
			Lighting = {
				ClockTime = 18.25, -- the sun just under the hills: no direct light, a long glow
				GeographicLatitude = 52,
				Brightness = 1.8,
				-- Lifted after the first screenshots: at 62/84 the ground and the moat
				-- went to pure black, which on a phone is just a black screen.
				Ambient = Color3.fromRGB(40, 41, 50),
				OutdoorAmbient = Color3.fromRGB(84, 86, 100),
				ColorShift_Top = Color3.fromRGB(160, 158, 166), -- cold: warmth belongs to fire
				ColorShift_Bottom = Color3.fromRGB(26, 28, 40),
				ExposureCompensation = 0.6,
				EnvironmentDiffuseScale = 0.6,
				EnvironmentSpecularScale = 0.5,
				ShadowSoftness = 0.35,
				GlobalShadows = true,
			},
			-- The castle has to read from the hill, 800 studs off: at density 0.44 it
			-- vanished into the haze entirely. 0.3 keeps it a silhouette and still
			-- loses the far end of it, which is what distance should do.
			Atmosphere = {
				Density = 0.3,
				Offset = 0.22,
				Color = Color3.fromRGB(112, 116, 128), -- the haze is grey-blue, never red
				Decay = Color3.fromRGB(88, 62, 66), -- a bruise of red only where the sky meets the hills
				Glare = 0.12,
				Haze = 1.5,
			},
			Sky = {
				CelestialBodiesShown = true,
				StarCount = 600,
				MoonAngularSize = 15,
				SunAngularSize = 0,
			},
			-- Broken cloud, not a lid: a full deck sat on the mountains like a ceiling.
			Clouds = { Enabled = true, Cover = 0.6, Density = 0.5, Color = Color3.fromRGB(82, 84, 96) },
			Effects = {
				-- Only fire and the cursed glow are bright enough to bloom.
				Bloom = { Enabled = true, Intensity = 0.4, Size = 24, Threshold = 1.35 },
				WorldGrade = {
					Enabled = true,
					Brightness = 0,
					Contrast = 0.22,
					Saturation = -0.25,
					TintColor = Color3.fromRGB(236, 232, 234), -- near neutral: the haze is blue enough
				},
			},
			Terrain = {
				Ground = Color3.fromRGB(70, 62, 52),
				Mud = Color3.fromRGB(42, 36, 31),
				Grass = Color3.fromRGB(54, 64, 40), -- dead, not green
				LeafyGrass = Color3.fromRGB(60, 66, 44),
				Rock = Color3.fromRGB(70, 70, 74),
				Slate = Color3.fromRGB(62, 62, 66),
				Basalt = Color3.fromRGB(40, 40, 46),
				Cobblestone = Color3.fromRGB(106, 102, 94),
				Sand = Color3.fromRGB(96, 86, 72),
			},
			-- Black, still, and only just reflective: a moat nobody has cleaned in
			-- forty years, not a swimming pool.
			-- Dark, but it must show the sky in it, or the moat reads as a hole.
			Water = {
				WaterColor = Color3.fromRGB(36, 48, 48),
				WaterTransparency = 0.25,
				WaterReflectance = 0.85,
				WaterWaveSize = 0.06,
				WaterWaveSpeed = 3,
			},
		},
	},
}

return table.freeze(Look)
