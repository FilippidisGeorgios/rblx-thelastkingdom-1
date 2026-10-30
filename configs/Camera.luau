--!strict
--[[
	Config: Camera
	How far a player may pull the camera back while playing.

	Roblox lets a player zoom out to 128 studs, which turns the castle into a map: the whole yard in one look, the
	dead seen from far above, nothing close enough to be afraid of. This puts a limit on zooming OUT only. Zooming
	in is left as it is (first person, over the shoulder, as close as the player likes).

	The number is a distance in studs from the character. The camera starts at about 12 studs; 30 lets a player
	step back far enough to see a fight round them, and no further. If it feels too near, raise it; too far, lower
	it. The developer said to try a smaller number than the engine's and tune it by playing.

	Read via: Config.get("Camera")   (applied by Client/Controllers/CameraController, in both places)
]]

local Camera = {
	MaxZoomOut = 30,
	-- the closest the camera may come (the engine's default is 0.5)
	MinZoom = 0.5,
}

return table.freeze(Camera)
