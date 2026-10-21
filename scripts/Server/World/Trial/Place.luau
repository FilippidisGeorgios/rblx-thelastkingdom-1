--!strict
--[[
	Trial.Place
	Finding somewhere to put a prop in a chamber that has been edited by hand.

	The same lesson WinchService learned the hard way: coordinates written down
	from the build tools stop being true the moment the place is touched. So a
	trial never says "put it at x, z"; it says "somewhere in this zone, on the
	floor, with nothing in the way", and this module finds it by looking.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Workspace = game:GetService("Workspace")

local Place = {}

-- Above this a downward ray has hit a roof, not the ward's floor.
local MAX_FLOOR_Y = 9

--[[
	Where the floor is under (x, z), by raycast from above. nil when there is no
	floor, or the first thing hit is higher than a ward's floor can be.
]]
function Place.floorAt(x: number, z: number, ignore: { Instance }?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), params)
	if not hit then
		return nil
	end
	local y = hit.Position.Y
	if y > MAX_FLOOR_Y or y < -4 then
		return nil
	end
	return y
end

--[[
	Is the space a person would walk through, round `at`, empty? The box starts
	above the floor so that standing on flagstones is fine and standing inside a
	wall is not.
]]
function Place.isClear(at: Vector3, radius: number, ignore: { Instance }?): boolean
	local params = OverlapParams.new()
	local skip: { Instance } = { Workspace.Terrain }
	for _, i in ignore or {} do
		table.insert(skip, i)
	end
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.MaxParts = 1
	local box = CFrame.new(at + Vector3.new(0, 1.5 + 4, 0))
	return #Workspace:GetPartBoundsInBox(box, Vector3.new(radius * 2, 7, radius * 2), params) == 0
end

--[[
	Up to `count` spots in the zone [x0..x1] x [z0..z1], each at least `apart`
	from the others and from every point in `avoid`, each on a floor and clear
	for `radius`. Returns what it found; fewer than asked is possible and the
	caller decides whether that matters.
]]
function Place.find(
	zone: { x0: number, x1: number, z0: number, z1: number },
	count: number,
	radius: number,
	apart: number,
	avoid: { Vector3 }?,
	ignore: { Instance }?,
	rng: Random
): { Vector3 }
	local chosen: { Vector3 } = {}
	local attempts = 0
	while #chosen < count and attempts < 500 do
		attempts += 1
		local x = rng:NextNumber(math.min(zone.x0, zone.x1), math.max(zone.x0, zone.x1))
		local z = rng:NextNumber(math.min(zone.z0, zone.z1), math.max(zone.z0, zone.z1))
		local y = Place.floorAt(x, z, ignore)
		if y then
			local at = Vector3.new(x, y, z)
			local ok = true
			for _, p in chosen do
				if Vector2.new(at.X - p.X, at.Z - p.Z).Magnitude < apart then
					ok = false
					break
				end
			end
			if ok and avoid then
				for _, p in avoid do
					if Vector2.new(at.X - p.X, at.Z - p.Z).Magnitude < apart then
						ok = false
						break
					end
				end
			end
			if ok and Place.isClear(at, radius, ignore) then
				table.insert(chosen, at)
			end
		end
	end
	return chosen
end

return Place
