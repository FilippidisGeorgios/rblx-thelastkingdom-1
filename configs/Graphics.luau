--!strict
--[[
	Config: Graphics
	The four picture qualities a player can choose in the Settings panel (Low, Medium, High, Ultra), and the
	shadows switch. Read by the client's GraphicsController and by the server's SettingsService (to validate).

	THE RULE, and it is not negotiable: a quality changes what the picture COSTS, never what the player CAN SEE.
	Brightness, ambient light, the atmosphere and its fog, the colour grading and every authored light's colour
	and reach are the same on all four, so no one fights in a clearer castle than their friend. A quality only
	changes: how many particles are drawn, how far away lights and fires are kept on, whether the glow and the
	sun's rays are drawn, the terrain's grass, the sharpness of shadows, and the engine's own quality level.

	THE SHADOWS SWITCH keeps the same promise. Turning shadows off must not light the dark parts of the castle (the
	sun would pour through every roof if the world's shadows were simply disabled, and the dark rooms are the
	game). So "off" means SIMPLE shadows: the walls, roofs and floors keep casting, and the small things (props,
	people, the dead) stop. The rooms stay exactly as dark; the machine has far fewer shadows to draw.

	Quality is changeable in the Hub and in the castle alike; it is only the player's own picture.

	Schema (per tier):
		Label, Blurb          shown in the panel
		Shadows               what the shadows switch starts at when this tier is chosen
		ParticleScale         share of each emitter's rate that is drawn (never to zero: cues stay)
		LodScale              how far lights and fires stay lit, as a share of the authored distance
		Bloom, SunRays, DepthOfField   the post effects, kept on or switched off if the place has them
		Decoration            the terrain's grass
		LightShadows          lights cast shadows (only while shadows are on)
		SoftShadows           ShadowSoftness is multiplied by this (smaller = sharper)
		QualityLevel          the engine's own level (1-21), set if the client is allowed to
]]

local Graphics = {
	Order = { "Low", "Medium", "High", "Ultra" },
	Default = "High",
	PhoneDefault = "Medium",

	-- Parts whose largest side is under this many studs are "small": they stop casting under SIMPLE shadows.
	SmallPartStuds = 5,

	Tiers = {
		Low = {
			Label = "Low",
			Blurb = "For phones and older machines. Fewer glows, sparks and far-off fires.",
			Shadows = false,
			ParticleScale = 0.35,
			LodScale = 0.6,
			Bloom = false,
			SunRays = false,
			DepthOfField = false,
			Decoration = false,
			LightShadows = false,
			SoftShadows = 1,
			QualityLevel = 3,
		},
		Medium = {
			Label = "Medium",
			Blurb = "Balanced. The picture most phones and laptops hold steady.",
			Shadows = true,
			ParticleScale = 0.65,
			LodScale = 0.85,
			Bloom = true,
			SunRays = false,
			DepthOfField = false,
			Decoration = false,
			LightShadows = false,
			SoftShadows = 1,
			QualityLevel = 8,
		},
		High = {
			Label = "High",
			Blurb = "The picture the castle was made for.",
			Shadows = true,
			ParticleScale = 1,
			LodScale = 1,
			Bloom = true,
			SunRays = true,
			DepthOfField = true,
			Decoration = true,
			LightShadows = false,
			SoftShadows = 1,
			QualityLevel = 14,
		},
		Ultra = {
			Label = "Ultra",
			Blurb = "The best light: sharper shadows, torches that shadow the room, fires lit from far away.",
			Shadows = true,
			ParticleScale = 1,
			LodScale = 1.5,
			Bloom = true,
			SunRays = true,
			DepthOfField = true,
			Decoration = true,
			LightShadows = true,
			SoftShadows = 0.4,
			QualityLevel = 21,
		},
	},
}

return table.freeze(Graphics)
