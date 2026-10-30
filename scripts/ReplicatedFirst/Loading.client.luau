--!strict
--[[
	Loading
	Puts the loading screen up on the first frame (black, the castle, the name, a bar) and loads the world behind
	it. When everything the player will stand in is here, the bar is full and the screen fades away. No button.

	Roblox drops a player into the place the moment the server accepts them, before meshes, textures and terrain
	arrive, so without this they would watch the lobby assemble around them: grey trees popping in, ground
	appearing late, decorations arriving after the buildings they were meant to hide.

	WHAT THE BAR MEANS. It is the real work, in four parts, each with a share of the bar:
	  0 - 10 %   the game itself has loaded (the place, its lighting, its scripts)
	  10 - 80 %  every picture, mesh, sound and animation the world uses (found by looking through it, listed once
	             each, and fetched in batches several at a time, so progress is the true count of what is done)
	  80 - 95 %  the player's body exists and the ground round it has streamed in
	  95 - 100 % the picture has drawn a couple of frames with the lighting on it
	Nothing waits for ever: the assets get 25 seconds, the body and the ground a few, and the whole screen 45, after
	which the player goes in with whatever is ready (a slow connection must never be a locked one). The screen also
	stays at least 3.5 seconds, so the name can be read.

	When it is done it sets the attribute `TLKLoaded` on ReplicatedFirst, which `Client/Controllers/LoadingController`
	turns into a message to the server ("this player is ready"): the arrival scene waits for it.

	Location: ReplicatedFirst.Loading (a LocalScript, runs before anything else)
]]

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local TitleScreen = require(script.Parent.TitleScreen)

--==========================================================================
-- Tuning
--==========================================================================
local MIN_SECONDS = 3.5 -- the name must be readable even when everything is already cached
local ASSET_SECONDS = 25 -- the longest the assets may take
local BODY_SECONDS = 12 -- the longest to wait for the player's body to appear
local STREAM_SECONDS = 8 -- the longest to wait for the ground round it
local TOTAL_SECONDS = 45 -- the longest the whole screen may stay
local BATCH = 24 -- assets per request
local WORKERS = 6 -- requests in flight at once
local MAX_ASSETS = 3000 -- a world with more than this is loaded for this long and no longer

ReplicatedFirst:RemoveDefaultLoadingScreen()

local startedAt = os.clock()
local screen = TitleScreen.show()

--==========================================================================
-- Looking for what the world uses
--==========================================================================

-- Which property of which class names a file. Matching on the exact class name is the cheap way to look at tens
-- of thousands of instances.
local WHERE: { [string]: { string } } = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	Sound = { "SoundId" },
	ParticleEmitter = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	Animation = { "AnimationId" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" },
}

local function collect(): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	local looked = 0

	local function scan(root: Instance)
		for _, instance in root:GetDescendants() do
			local properties = WHERE[instance.ClassName]
			if properties then
				for _, property in properties do
					local ok, value = pcall(function()
						return (instance :: any)[property]
					end)
					-- local files ("rbxasset://...") are already on the machine; empty is nothing
					if ok and type(value) == "string" and value ~= "" and string.sub(value, 1, 11) ~= "rbxasset://" and not seen[value] then
						seen[value] = true
						table.insert(list, value)
					end
				end
			end
			looked += 1
			if looked % 4000 == 0 then
				task.wait() -- never hold a frame for the whole world
			end
			if #list >= MAX_ASSETS then
				return
			end
		end
	end

	for _, root in { Workspace :: Instance, Lighting, SoundService, ReplicatedStorage } do
		scan(root)
		if #list >= MAX_ASSETS then
			break
		end
	end
	return list
end

--==========================================================================
-- The work
--==========================================================================
local function loadWorld()
	screen.setStatus("Opening the gates...")
	screen.setProgress(0.03)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	screen.setProgress(0.1)

	-- the assets
	screen.setStatus("Raising the walls...")
	local assets = collect()
	local batches: { { string } } = {}
	for first = 1, #assets, BATCH do
		table.insert(batches, table.move(assets, first, math.min(first + BATCH - 1, #assets), 1, {}))
	end

	local deadline = os.clock() + ASSET_SECONDS
	local nextBatch = 1
	local done = 0
	local running = 0
	local function worker()
		running += 1
		while nextBatch <= #batches and os.clock() < deadline do
			local mine = nextBatch
			nextBatch += 1
			pcall(function()
				ContentProvider:PreloadAsync(batches[mine])
			end)
			done += 1
			screen.setProgress(0.1 + 0.7 * (done / #batches))
		end
		running -= 1
	end
	for _ = 1, math.min(WORKERS, #batches) do
		task.spawn(worker)
	end
	while running > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	screen.setProgress(0.8)

	-- the player's body and the ground it stands on
	screen.setStatus("Lighting the torches...")
	local player = Players.LocalPlayer
	local bodyDeadline = os.clock() + BODY_SECONDS
	local root: BasePart? = nil
	while os.clock() < bodyDeadline do
		local character = player.Character
		local part = character and character:FindFirstChild("HumanoidRootPart")
		if part and part:IsA("BasePart") then
			root = part
			break
		end
		task.wait(0.1)
	end
	if root then
		pcall(function()
			player:RequestStreamAroundAsync(root.Position, STREAM_SECONDS)
		end)
	end
	screen.setProgress(0.95)

	-- a couple of frames drawn with the light on them
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	screen.setProgress(1)
	screen.setStatus("Ready")
end

--==========================================================================
task.spawn(function()
	local finished = false
	task.spawn(function()
		local ok, err = pcall(loadWorld)
		if not ok then
			warn("[Loading] " .. tostring(err))
		end
		finished = true
	end)
	-- never longer than the whole-screen limit, whatever is still loading
	while not finished and os.clock() - startedAt < TOTAL_SECONDS do
		task.wait(0.1)
	end

	-- the bar's last move, and the name on screen long enough to read
	screen.setProgress(1)
	task.wait(0.45)
	local remaining = MIN_SECONDS - (os.clock() - startedAt)
	if remaining > 0 then
		task.wait(remaining)
	end

	ReplicatedFirst:SetAttribute("TLKLoaded", true)
	screen.dismiss()
end)
