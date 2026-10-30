--!strict
--[[
	IntroController
	Plays the arrival scene on this player's screen: the camera work (the long look at the castle, the view over a
	speaker's shoulder, the speaker's face), the title, the letterbox, and each line in the dialogue box under the
	name and face of whoever says it.

	The server (Server/World/IntroService) says when it starts, who speaks, and when it ends; this side only plays
	pictures. Every client runs the same timeline from `configs/Intro.luau`, so the shots line up across a party
	without the server timing each one. The camera pieces (shots, hand-held sway, soft focus, ash, lightning) are in
	`UI/IntroCinema`.

	SKIP is a hold, not a tap (`Intro.SkipHoldSeconds`, 3 s): the button fills while held and only then does this
	player's vote go to the server, which skips the scene when enough of the party have held theirs.

	While the scene plays, everything else on screen is put away (the game's own HUDs and Roblox's) and put back
	exactly as it was afterwards.

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
local IntroCinema = require(script.Parent.Parent.UI.IntroCinema)

local IntroController = {}

IntroController.Name = "IntroController"

local CAMERA_STEP = "TLKIntroCamera"

local ui: IntroUI.Handle? = nil
local rig: IntroCinema.Rig? = nil
local sceneToken = 0
local hiddenGuis: { ScreenGui } = {}
local votedSkip = false

-- The shot that is on screen now, and how it is running.
local shot: IntroCinema.Shot? = nil
local shotStarted = 0
local shotSeconds = 1
local shotSway = 1

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
			-- (the loading screen is not put away: it leaves by itself, when the bar is full)
			if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "IntroUI" and gui.Name ~= "TitleScreen" then
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

--==========================================================================
-- Shots
--==========================================================================

--[[
	The camera for one beat. The beat's SHOT picks the style; where the style needs a person (a shoulder, a
	face) and that person cannot be found, it falls back to the marks, so a speaker who left mid-scene can
	never leave the screen without a picture.
]]
local function shotFor(beat: any, speakerId: number, fov: number): (IntroCinema.Shot?, string)
	local kind = beat.Shot or "Marks"
	if kind ~= "Marks" and speakerId ~= 0 then
		local speaker = Players:GetPlayerByUserId(speakerId)
		local character = speaker and speaker.Character
		if character then
			local made: IntroCinema.Shot? = nil
			if kind == "Shoulder" then
				made = IntroCinema.shoulder(character)
			elseif kind == "Face" then
				made = IntroCinema.face(character, beat.Side or 1)
			end
			if made then
				return made, kind
			end
		end
	end

	local from = markCFrame(beat.From)
	local to = markCFrame(beat.To)
	if from and to then
		-- A beat that holds on one mark still drifts: a dead-still camera reads as a paused game, not a shot.
		if from == to then
			to = from * CFrame.new(0, 0, -3)
		end
		return IntroCinema.marks(from, to, fov), "Marks"
	end
	return nil, "Marks"
end

local function cut(upcoming: IntroCinema.Shot?, seconds: number, sway: number)
	shot = upcoming
	shotStarted = os.clock()
	shotSeconds = math.max(seconds, 0.1)
	shotSway = sway
end

-- The camera runs on frames, the scene on the clock: a hitch in rendering may stutter a shot, but it can never
-- stall the dialogue or put this client out of step with the rest of the party.
local function renderStep()
	local current = shot
	local lens = rig
	if not (current and lens) then
		return
	end
	local t = math.clamp((os.clock() - shotStarted) / shotSeconds, 0, 1)
	local cf, fov = current(t)
	lens.frame(cf, fov, shotSway)
end

local function stopCamera()
	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_STEP)
	end)
	shot = nil
	if rig then
		rig.destroy()
		rig = nil
	end
end

--==========================================================================
local function play(speakers: { [number]: string }, speakerIds: { [number]: number }, needed: number)
	local cfg = Config.get("Intro")
	sceneToken += 1
	local token = sceneToken
	votedSkip = false

	if ui then
		ui.destroy()
	end
	stopCamera()
	local handle = IntroUI.create(cfg.SkipHoldSeconds)
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

	local lens = IntroCinema.rig()
	rig = lens
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, renderStep)
	handle.black(0, cfg.FadeInSeconds)

	for i, beat in cfg.Beats do
		if token ~= sceneToken then
			return
		end
		local speakerId = speakerIds[i] or 0
		local speakerName = speakers[i]
		if beat.Line and speakerName and speakerName ~= "" then
			local face = if speakerId ~= 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(speakerId) else nil
			handle.say(speakerName, beat.Line, cfg.CharactersPerSecond, face)
		else
			handle.clearLine()
		end

		local made, kind = shotFor(beat, speakerId, cfg.FieldOfView)
		-- a person holding a camera shakes a little more on the long approach than at a speaker's face
		cut(made, beat.Seconds, if kind == "Face" then 0.6 else 1)
		local focus = cfg.Focus[kind] or cfg.Focus.Marks
		-- quick: the cut is hard, so the lens must not still be settling from the last shot on the new one
		lens.focus(focus.Distance, focus.Radius, focus.Near, focus.Far, 0.3)
		if beat.Flash then
			task.delay(beat.Flash, function()
				if token == sceneToken and rig == lens then
					lens.flash()
				end
			end)
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
	stopCamera()
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
			task.spawn(play, payload.speakers or {}, payload.speakerIds or {}, tonumber(payload.needed) or 1)
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
