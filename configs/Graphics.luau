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
		Label                 shown in the panel (a name and nothing else: the developer asked for no small print)
		Shadows               what the shadows switch starts at when this tier is chosen
		ParticleScale         share of each emitter's rate that is drawn (never to zero: cues stay)
		LodScale              how far lights and fires stay lit, as a share of the authored distance
		Bloom, SunRays, DepthOfField   the post effects, kept on or switched off if the place has them
		Decoration            the terrain's grass
		LightShadows          lights cast shadows (only while shadows are on)
		SoftShadows           ShadowSoftness is multiplied by this (smaller = sharper)
		QualityLevel          the engine's own level (1-21), set if the client is allowed to
		Surfaces              "full": everything as it was made. "plain": the fine surface pictures (SurfaceAppearance)
		                      are taken off, the materials stay. "flat": that, and every material becomes smooth plastic
		                      and the tiled pictures on walls are hidden: the world in plain colours. Shapes, colours,
		                      light and dark are the same on all three (the rule above), only the surface is cheaper.

	LOW MUST LOOK LOW (the developer, 2026-11-10): a player who chooses Low on a weak machine should SEE that the game
	became lighter, so Low is "flat" with a fifth of the particles and half the far lights, and Medium is "plain".

	ONLY DOWN INSIDE A RUN (`Lock`). In the places named there a quality can be lowered and never raised again until the
	player is back in the lobby: raising it in the middle of a fight was a way to freeze the game, and "flat" and "plain"
	are cheap to put on and dear to take off. The panel asks first ("Are you sure?"), and crosses out what is above.
]]

local Graphics = {
	Order = { "Low", "Medium", "High", "Ultra" },
	Default = "High",
	PhoneDefault = "Medium",

	-- Parts whose largest side is under this many studs are "small": they stop casting under SIMPLE shadows.
	SmallPartStuds = 5,

	-- Where the quality may only go down (Shared/PlayerSettings keeps the ceiling, Services/SettingsService holds it).
	Lock = {
		Places = { "ForgottenLands" },
		Ask = "ARE YOU SURE?",
		Warning = "If you press YES, remember: you cannot raise the graphics again during this game. They can only be raised in the lobby.",
	},

	Tiers = {
		Low = {
			Label = "Low",
			Shadows = false,
			ParticleScale = 0.2,
			LodScale = 0.5,
			Bloom = false,
			SunRays = false,
			DepthOfField = false,
			Decoration = false,
			LightShadows = false,
			SoftShadows = 1,
			QualityLevel = 1,
			Surfaces = "flat",
		},
		Medium = {
			Label = "Medium",
			Shadows = true,
			ParticleScale = 0.65,
			LodScale = 0.85,
			Bloom = true,
			SunRays = false,
			DepthOfField = false,
			Decoration = false,
			LightShadows = false,
			SoftShadows = 1,
			QualityLevel = 7,
			Surfaces = "plain",
		},
		High = {
			Label = "High",
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
			Surfaces = "full",
		},
		Ultra = {
			Label = "Ultra",
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
			Surfaces = "full",
		},
	},
}

return table.freeze(Graphics)
