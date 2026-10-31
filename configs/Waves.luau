--!strict
--[[
	Config: Waves
	GLOBAL tuning for the Wave System — defaults shared by all encounters. Per-encounter
	fields in `configs/Encounters.luau` override these. Specific encounter content lives
	there, not here.

	Read via: Config.get("Waves")
]]

local Waves = {
	-- Applied by the WaveService unless an encounter overrides them.
	Defaults = {
		RestBetweenWavesSeconds = 2, -- pause between sequential waves

		-- The share of a wave's units that come from one of the encounter's OTHER spawn points instead of their group's own,
		-- picked at random one by one, so the dead arrive from several sides and not in one clump (the developer asked, 2026-10-31).
		-- 0 = every group from its own point, as before. An encounter may set `scatter` to override.
		Scatter = 0.5,
	},
}

return table.freeze(Waves)
