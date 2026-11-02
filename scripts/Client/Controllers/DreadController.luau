--!strict
--[[
	DreadController
	What the catacombs do to the player's own senses (docs/systems/Catacombs.md, "Fear"). Only the player's own screen and ears:
	nothing here changes what the server knows, so it can never be unfair.

	  * THE LANTERN BREATHES. Under the ground (below `configs/Catacombs.DarkBelow`) the light of the held lantern wavers a little
	    all the time, and when the plague doctor is near it flickers hard, shrinks and gutters, the nearer he is.
	  * A HEART. A slow heartbeat grows with his nearness: silent beyond `Dread.HeartFrom` studs, loud at his feet.
	  * A DRONE. A low, constant, unsettling sound while the player is below the ground, so the silence is never empty.

	Sounds are named in `configs/Catacombs.Dread` (Roblox's own library; a sound that does not load is simply silent).
	Place: client (boots in both places; active only below the ground of the Forgotten Lands).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local DreadController = {}

DreadController.Name = "DreadController"

local function makeSound(spec: any, name: string): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = spec.Id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

function DreadController.Init() end

function DreadController.Start()
	local ok, cfg = pcall(Config.get, "Catacombs")
	if not ok or not cfg.Dread then
		return
	end
	local dread = cfg.Dread
	local player = Players.LocalPlayer
	local drone = makeSound(dread.Drone, "CatacombDrone")
	local heart = makeSound(dread.Heart, "CatacombHeart")
	local baseRange: number? = nil
	local baseBright: number? = nil
	local t = 0

	local function doctorDistance(origin: Vector3): number
		local best = math.huge
		-- the Doctor is the one model that carries the attribute `Doctor`
		for _, m in Workspace:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Doctor") then
				local d = (m:GetPivot().Position - origin).Magnitude
				if d < best then
					best = d
				end
			end
		end
		return best
	end

	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local below = root.Position.Y < (cfg.DarkBelow or -20)

		-- the drone fades in below the ground and out above it
		local want = if below then dread.Drone.Volume else 0
		drone.Volume += (want - drone.Volume) * math.min(1, dt * 0.8)
		if below and not drone.IsPlaying then
			drone:Play()
		elseif not below and drone.IsPlaying and drone.Volume < 0.01 then
			drone:Stop()
		end

		local near = 0 -- 0 far .. 1 at his feet
		if below then
			local d = doctorDistance(root.Position)
			near = math.clamp(1 - (d - dread.HeartTo) / (dread.HeartFrom - dread.HeartTo), 0, 1)
		end

		-- the heart: its speed and loudness follow his nearness
		local heartWant = near * dread.Heart.Volume
		heart.Volume += (heartWant - heart.Volume) * math.min(1, dt * 3)
		heart.PlaybackSpeed = dread.Heart.Speed + near * dread.Heart.Quicken
		if near > 0.02 and not heart.IsPlaying then
			heart:Play()
		elseif near <= 0.02 and heart.IsPlaying and heart.Volume < 0.01 then
			heart:Stop()
		end

		-- the lantern
		local held = character and character:FindFirstChild("HeldLantern")
		local light = held and held:FindFirstChild("LanternLight", true) :: PointLight?
		if light then
			if not baseRange or not light:GetAttribute("TLK_Base") then
				baseRange, baseBright = light.Range, light.Brightness
				light:SetAttribute("TLK_Base", true)
			end
			if below then
				local waver = math.noise(t * 2.3, 7) * 0.5 + math.noise(t * 9, 3) * 0.25
				-- a hard flicker when he is near: bursts, not a smooth change
				local gutter = near * (math.noise(t * 21, 5) * 0.5 + 0.5) ^ 2
				light.Range = (baseRange :: number) * (1 + waver * dread.Waver) * (1 - near * dread.Shrink) * (1 - gutter * 0.25)
				light.Brightness = (baseBright :: number) * (1 + waver * dread.Waver * 1.5) * (1 - gutter * 0.7)
			else
				light.Range = baseRange :: number
				light.Brightness = baseBright :: number
			end
		end
	end)
end

return DreadController
