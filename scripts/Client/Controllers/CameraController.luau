--!strict
--[[
	CameraController
	How far the camera may be from the player.

	Since 2026-11-10 the game is FIRST PERSON (configs/View): the camera is held at the eyes and cannot be pulled back at
	all (Controllers/ViewController does everything else about the view). The limit on zooming out that this controller
	was made for (configs/Camera: 23 studs, so the castle never became a map) is kept for the day the developer switches
	`View.FirstPerson` off.

	The cinematic death camera and the arrival scene take the camera over themselves (they set it to Scriptable), so
	neither limit gets in their way.

	Place: client (boots in both places).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraController = {}

CameraController.Name = "CameraController"

function CameraController.Init() end

function CameraController.Start()
	local cfg = Config.get("Camera")
	local view = Config.get("View")
	local player = Players.LocalPlayer
	-- Properties of the Player, so they hold across respawns. The min is set first: the engine refuses a max that is
	-- below the current min.
	if view.FirstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		return
	end
	player.CameraMinZoomDistance = cfg.MinZoom
	player.CameraMaxZoomDistance = math.max(cfg.MaxZoomOut, cfg.MinZoom + 1)
end

return CameraController
