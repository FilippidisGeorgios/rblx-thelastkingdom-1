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

	THE GATE (2026-11-14, the developer). In the Forgotten Lands the server holds the whole party at a gate
	(Server/World/IntroService, attributes TLK_Gate* on ReplicatedStorage): at most 30 seconds for everyone to load, and
	once everyone is in, at most 7 more for the assets. This screen shows it (how many have loaded of the party, a count
	down), says "ready" as soon as THIS player has loaded, and stays up until the gate opens, so the whole party walks
	into the same first second of the scene. Assets still being fetched when it opens go on loading behind the scene.
	In the lobby there is no gate: the screen goes when this player is ready.

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
local TOTAL_SECONDS = 75 -- the longest the whole screen may stay (a gate holds it 30 + 7 at most)
local GATE_LOOK_SECONDS = 4 -- how long to look for a gate before deciding there is none (the lobby)
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
	ParticleEmitter = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	Animation = { "AnimationId" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" },
}

-- What is fetched: a file named by a string, or a Sound itself (a sound's id handed over as a string is fetched as a
-- picture and refused, "Asset type does not match requested type": found in the log, 2026-11-03).
type Want = string | Instance

local function collect(): { Want }
	local seen: { [string]: boolean } = {}
	local list: { Want } = {}
	local looked = 0

	local function scan(root: Instance)
		for _, instance in root:GetDescendants() do
			local properties = WHERE[instance.ClassName]
			if instance.ClassName == "Sound" then
				local id = (instance :: Sound).SoundId
				if id ~= "" and string.sub(id, 1, 11) ~= "rbxasset://" and not seen[id] then
					seen[id] = true
					table.insert(list, instance)
				end
			elseif properties then
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
	local batches: { { Want } } = {}
	for first = 1, #assets, BATCH do
		table.insert(batches, table.move(assets, first, math.min(first + BATCH - 1, #assets), 1, {}))
	end

	-- the workers go on until everything is fetched, even after the screen has gone; the screen only waits for them
	-- while nothing else says go (the lobby: ASSET_SECONDS; a gate: until it opens)
	local deadline = math.huge
	local holdUntil = os.clock() + ASSET_SECONDS
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
			screen.setProgress(done / #batches)
		end
		running -= 1
	end
	for _ = 1, math.min(WORKERS, #batches) do
		task.spawn(worker)
	end
	while running > 0 do
		local state = ReplicatedStorage:GetAttribute("TLK_GateState")
		if state == "starting" or state == "open" then
			break -- the gate has opened: the rest loads behind the scene
		end
		if state == nil and os.clock() > holdUntil then
			break
		end
		task.wait(0.1)
	end
	if #batches == 0 then
		screen.setProgress(1)
	end

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
	-- a couple of frames drawn with the light on them
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
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

	-- this player is ready: the server counts it at the gate
	ReplicatedFirst:SetAttribute("TLKLoaded", true)

	-- the gate: stay up until it opens (the lobby has none: a few seconds of looking, then go)
	local lookUntil = os.clock() + GATE_LOOK_SECONDS
	while os.clock() - startedAt < TOTAL_SECONDS do
		local state = ReplicatedStorage:GetAttribute("TLK_GateState")
		if state == nil and os.clock() > lookUntil then
			break
		end
		if state == "starting" or state == "open" then
			break
		end
		task.wait(0.15)
	end

	-- the name on screen long enough to read
	local remaining = MIN_SECONDS - (os.clock() - startedAt)
	if remaining > 0 then
		task.wait(remaining)
	end
	ReplicatedFirst:SetAttribute("TLKScreenGone", true) -- (the eyes open and the night is heard after this)
	screen.dismiss()
end)

-- the gate's numbers, onto the screen, until it goes
task.spawn(function()
	while true do
		local state = ReplicatedStorage:GetAttribute("TLK_GateState")
		if typeof(state) == "string" then
			screen.setGate({
				state = state,
				ready = ReplicatedStorage:GetAttribute("TLK_GateReady") :: number?,
				expected = ReplicatedStorage:GetAttribute("TLK_GateExpected") :: number?,
				endsAt = ReplicatedStorage:GetAttribute("TLK_GateEndsAt") :: number?,
			})
			if state == "open" then
				break
			end
		end
		task.wait(0.2)
	end
end)
