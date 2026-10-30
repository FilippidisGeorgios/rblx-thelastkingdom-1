--!strict
--[[
	CameraController
	Client-side camera rules for play.

	Today it does one thing: it limits how far the player can zoom OUT (`configs/Camera`). Roblox's own limit is 128
	studs, far enough to turn the castle into a map; here the camera may come back only as far as the config says.
	Zooming IN is untouched. The cinematic death camera and the arrival scene take the camera over themselves
	(they set it to Scriptable), so this limit never gets in their way.

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
	local player = Players.LocalPlayer
	-- A property of the Player, so it holds across respawns. The min is set first: the engine refuses a max that is
	-- below the current min.
	player.CameraMinZoomDistance = cfg.MinZoom
	player.CameraMaxZoomDistance = math.max(cfg.MaxZoomOut, cfg.MinZoom + 1)
end

return CameraController
