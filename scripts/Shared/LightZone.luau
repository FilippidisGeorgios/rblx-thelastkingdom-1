--!strict
--[[
	LightZone
	Which dark room a point is standing in. Pure geometry, so it can be tested.

	A zone is a box (a CFrame and a size). `contains` asks whether a point is inside it, in the box's own space, so a
	box turned at any angle works. `pick` chooses between zones that overlap (a passage inside a larger cave): the
	one with the higher priority, and between equals the smaller one (the more specific place wins).

	Location: ReplicatedStorage.Shared.LightZone
]]

local LightZone = {}

export type Zone = {
	id: string,
	cframe: CFrame,
	size: Vector3,
	priority: number,
}

function LightZone.contains(zone: Zone, point: Vector3): boolean
	local local_ = zone.cframe:PointToObjectSpace(point)
	local half = zone.size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

local function volume(zone: Zone): number
	return zone.size.X * zone.size.Y * zone.size.Z
end

-- The zone that rules at `point`, or nil when it is in none.
function LightZone.pick(zones: { Zone }, point: Vector3): Zone?
	local best: Zone? = nil
	for _, zone in zones do
		if LightZone.contains(zone, point) then
			if best == nil or zone.priority > best.priority or (zone.priority == best.priority and volume(zone) < volume(best)) then
				best = zone
			end
		end
	end
	return best
end

return LightZone
