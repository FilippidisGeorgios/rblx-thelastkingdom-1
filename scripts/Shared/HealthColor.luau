--!strict
--[[
	HealthColor
	The colour of the health bar for a share of health: green when full, then yellow, orange and red as it falls
	(`configs/Hud.HealthBar.Stops`). Pure, so it can be tested.

	Location: ReplicatedStorage.Shared.HealthColor
]]

local HealthColor = {}

export type Stop = { At: number, Color: Color3 }

-- `fraction` is health / max health (clamped to 0..1); `stops` run from 1 down to 0.
function HealthColor.of(fraction: number, stops: { Stop }): Color3
	local f = math.clamp(fraction, 0, 1)
	for i = 1, #stops - 1 do
		local upper, lower = stops[i], stops[i + 1]
		if f <= upper.At and f >= lower.At then
			local span = upper.At - lower.At
			local t = if span <= 0 then 0 else (f - lower.At) / span
			return lower.Color:Lerp(upper.Color, t)
		end
	end
	return if f >= 0.5 then stops[1].Color else stops[#stops].Color
end

-- "87%": rounded UP while alive, so a sliver of health never reads as nothing; 0 only when it is 0.
function HealthColor.percent(health: number, maxHealth: number): number
	if maxHealth <= 0 or health <= 0 then
		return 0
	end
	return math.clamp(math.ceil(health / maxHealth * 100), 1, 100)
end

return HealthColor
