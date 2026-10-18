--!strict
--[[
	IntroController
	Plays the arrival scene on this player's screen: the camera moving between
	the marks on the hill, the title, the letterbox, and each line in the
	dialogue box under the name of whoever says it.

	The server (Server/World/IntroService) says when it starts, who speaks, and
	when it ends; this side only plays pictures. Every client runs the same
	timeline from `configs/Intro.luau`, so the shots line up across a party
	without the server timing each one.

	While the scene plays, everything else on screen is put away (the game's own
	HUDs and Roblox's) and put back exactly as it was afterwards.

	Place: client (boots in both places; active only in the Forgotten Lands).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local IntroUI = require(script.Parent.Parent.UI.IntroUI)

local IntroController = {}

IntroController.Name = "IntroController"

local ui: IntroUI.Handle? = nil
local sceneToken = 0
local hiddenGuis: { ScreenGui } = {}
local votedSkip = false

--==========================================================================
local function marks(): Instance?
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local surroundings = gameplay and gameplay:FindFirstChild("Surroundings")
	return surroundings and surroundings:FindFirstChild("Intro")
end

local function markCFrame(name: string): CFrame?
	local folder = marks()
	local mark = folder and folder:FindFirstChild(name)
	return if mark and mark:IsA("BasePart") then mark.CFrame else nil
end

local function hideOtherScreens()
	hiddenGuis = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "IntroUI" then
				gui.Enabled = false
				table.insert(hiddenGuis, gui)
			end
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
end

local function restoreScreens()
	for _, gui in hiddenGuis do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	hiddenGuis = {}
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
end

-- Moves the camera from a to b over `seconds`, eased at both ends. Stops the
-- moment the scene is ended from the server.
local moveToken = 0
local function move(a: CFrame, b: CFrame, seconds: number, token: number)
	local camera = Workspace.CurrentCamera
	local started = os.clock()
	-- A newer shot takes over from this one.
	moveToken += 1
	local mine = moveToken
	while token == sceneToken and mine == moveToken do
		local t = math.clamp((os.clock() - started) / seconds, 0, 1)
		local eased = 0.5 - math.cos(math.pi * t) / 2
		camera.CFrame = a:Lerp(b, eased)
		if t >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

--==========================================================================
local function play(speakers: { [number]: string }, needed: number)
	local cfg = Config.get("Intro")
	sceneToken += 1
	local token = sceneToken
	votedSkip = false

	if ui then
		ui.destroy()
	end
	local handle = IntroUI.create()
	ui = handle
	handle.setVotes(0, needed, false)
	handle.onSkip(function()
		if votedSkip then
			return
		end
		votedSkip = true
		Net.getEvent("RequestIntroSkip"):FireServer()
	end)

	hideOtherScreens()

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = cfg.FieldOfView
	local first = cfg.Beats[1]
	local start = first and markCFrame(first.From)
	if start then
		camera.CFrame = start
	end

	handle.letterbox(true, 0.01)
	handle.title(cfg.Title, cfg.Subtitle, cfg.TitleSeconds)
	task.wait(cfg.TitleSeconds)
	if token ~= sceneToken then
		return
	end
	handle.black(0, cfg.FadeInSeconds)

	for i, beat in cfg.Beats do
		if token ~= sceneToken then
			return
		end
		local from = markCFrame(beat.From)
		local to = markCFrame(beat.To)
		if beat.Line and speakers[i] and speakers[i] ~= "" then
			handle.say(speakers[i], beat.Line, cfg.CharactersPerSecond)
		else
			handle.clearLine()
		end
		if from and to then
			-- A beat that holds on one mark still drifts: a dead-still camera
			-- reads as a paused game, not a shot.
			if from == to then
				to = from * CFrame.new(0, 0, -3)
			end
			-- The camera runs on frames, the scene on the clock: a hitch in
			-- rendering may stutter a shot, but it can never stall the dialogue
			-- or put this client out of step with the rest of the party.
			task.spawn(move, from, to, beat.Seconds, token)
		end
		task.wait(beat.Seconds)
	end
	if token == sceneToken then
		handle.clearLine()
	end
	-- The server ends the scene; until it does, hold the last frame.
end

local function finishOnScreen(fadeSeconds: number)
	sceneToken += 1
	if ui then
		ui.clearLine()
		ui.black(1, fadeSeconds)
	end
end

local function arrived()
	sceneToken += 1
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = 70
	local handle = ui
	if handle then
		handle.letterbox(false, 0.8)
		handle.black(0, 1.2)
		task.delay(1.3, function()
			if ui == handle then
				handle.destroy()
				ui = nil
			end
		end)
	end
	restoreScreens()
end

--==========================================================================
function IntroController.Init() end

function IntroController.Start()
	-- Same rule as AreaController: stand down anywhere that is definitely not the
	-- Forgotten Lands (an unpublished local place reports PlaceId 0).
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end

	Net.getEvent("IntroEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "start" then
			task.spawn(play, payload.speakers or {}, tonumber(payload.needed) or 1)
		elseif payload.kind == "votes" then
			if ui then
				ui.setVotes(tonumber(payload.votes) or 0, tonumber(payload.needed) or 1, votedSkip)
			end
		elseif payload.kind == "end" then
			finishOnScreen(tonumber(payload.fade) or 1)
		elseif payload.kind == "arrived" then
			arrived()
		end
	end)
end

return IntroController
