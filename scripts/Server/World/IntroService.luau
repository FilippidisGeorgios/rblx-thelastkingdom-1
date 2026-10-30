--!strict
--[[
	IntroService
	The arrival scene: the party on the hill, looking at the castle, talking
	about it. Then they are inside the gate and the run begins.

	Who owns what:
	  - THIS service decides who is in the scene, who says which line, when it
	    starts and when it ends (the timeline runs out, or the party votes to
	    skip). It stands the characters on the hill and, at the end, puts them
	    on the arrival pad.
	  - The client (`Client/Controllers/IntroController`) plays the pictures: the
	    camera, the letterbox, the dialogue box. Every client runs the same
	    timeline from `configs/Intro.luau`, so the server sends one message to
	    start and one to end, not a stream.
	  - ChapterService waits for `IntroService.whenFinished` before it starts the
	    first mission, so nothing spawns while the party is still on the hill.

	Once per server. A player who arrives after the scene has started skips it
	and spawns in as normal; so does anyone who respawns later.

	Place: Forgotten Lands ONLY (Server/World).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local SkipVote = require(script.Parent.Parent.Domain.SkipVote)

local IntroService = {}

IntroService.Name = "IntroService"

local log = Logger.new("IntroService")

type State = "waiting" | "playing" | "ending" | "finished"

local state: State = "waiting"
local finishedCallbacks: { () -> () } = {}
local cast: { Player } = {}
local skipVotes: { [Player]: boolean } = {}
local ready: { [Player]: boolean } = {} -- whose loading screen has gone (the client says so with ClientReady)
local endToken = 0

--==========================================================================
local function introFolder(): Instance?
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local surroundings = gameplay and gameplay:FindFirstChild("Surroundings")
	return surroundings and surroundings:FindFirstChild("Intro")
end

local function totalSeconds(cfg: any): number
	local total = cfg.TitleSeconds
	for _, beat in cfg.Beats do
		total += beat.Seconds
	end
	return total
end

local function finish()
	if state == "finished" then
		return
	end
	state = "finished"
	local callbacks = finishedCallbacks
	finishedCallbacks = {}
	for _, fn in callbacks do
		task.spawn(fn)
	end
end

--[[
	Calls `fn` once the scene is over (or at once, if it already is, or never
	ran). This is what ChapterService waits on.
]]
function IntroService.whenFinished(fn: () -> ())
	if state == "finished" then
		task.spawn(fn)
	else
		table.insert(finishedCallbacks, fn)
	end
end

function IntroService.isPlaying(): boolean
	return state == "playing"
end

--==========================================================================
-- Characters
--==========================================================================
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function standOnHill(player: Player, index: number)
	local folder = introFolder()
	local mark = folder and folder:FindFirstChild("Stand" .. ((index - 1) % 6 + 1))
	local root = rootOf(player)
	if not (mark and mark:IsA("BasePart") and root) then
		return
	end
	local character = player.Character :: Model
	character:PivotTo(mark.CFrame)
	root.Anchored = true -- standing still, looking at the castle; the idle still plays
end

-- Back to where the run begins: the arrival pad, spread out so nobody lands on
-- anybody else.
local function standAtGate(player: Player, index: number)
	local root = rootOf(player)
	if not root then
		return
	end
	local spawn = Workspace:FindFirstChild("ArrivalSpawn", true)
	local base = if spawn and spawn:IsA("BasePart") then spawn.Position else Vector3.new(0, 3, -35)
	local angle = (index - 1) * (math.pi * 2 / 6)
	local offset = if index == 1 then Vector3.zero else Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
	local at = base + offset + Vector3.new(0, 3, 0)
	-- Facing into the castle (away from the gate, which is at +Z).
	;(player.Character :: Model):PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
	-- The body is still anchored from the hill. With streaming on, the ground at the
	-- gate may not have reached this client yet (it was 800 studs away a moment
	-- ago): hold the body until it has, or it lands on nothing and falls.
	pcall(function()
		player:RequestStreamAroundAsync(at, 6)
	end)
	root.Anchored = false
end

local function waitForCharacter(player: Player, timeout: number): boolean
	local deadline = os.clock() + timeout
	while player.Parent and not rootOf(player) and os.clock() < deadline do
		task.wait(0.1)
	end
	return rootOf(player) ~= nil
end

--==========================================================================
-- The scene
--==========================================================================
local function endScene(reason: string)
	if state ~= "playing" then
		return
	end
	-- The timeline running out and the last skip vote can land together.
	state = "ending"
	endToken += 1
	local cfg = Config.get("Intro")
	log:info("scene over (" .. reason .. ")")

	local event = Net.getEvent("IntroEvent")
	for _, player in cast do
		if player.Parent then
			event:FireClient(player, { kind = "end", fade = cfg.FadeOutSeconds })
		end
	end

	-- Move everyone while the screen is black, then let the clients fade back in.
	task.wait(cfg.FadeOutSeconds + 0.1)
	-- All at once: each one waits on its own client's streaming.
	local placing = 0
	for i, player in cast do
		if player.Parent then
			placing += 1
			task.spawn(function()
				standAtGate(player, i)
				placing -= 1
			end)
		end
	end
	local placeDeadline = os.clock() + 8
	while placing > 0 and os.clock() < placeDeadline do
		task.wait(0.1)
	end
	for _, player in cast do
		if player.Parent then
			event:FireClient(player, { kind = "arrived" })
		end
	end
	finish()
end

local function playScene()
	local cfg = Config.get("Intro")

	-- Everyone who has a body by now is in the scene.
	cast = {}
	for _, player in Players:GetPlayers() do
		if waitForCharacter(player, 3) then
			table.insert(cast, player)
		end
	end
	if #cast == 0 or not introFolder() then
		log:warn(if #cast == 0 then "nobody to show the scene to" else "no Surroundings.Intro marks — skipping the scene")
		finish()
		return
	end

	state = "playing"
	skipVotes = {}

	-- Who says what: a shuffled rotation through the party, so the lines move
	-- between people and the first line is not always the host's.
	local order = table.clone(cast)
	local rng = Random.new()
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- One entry per beat ("" where nobody speaks): a remote turns an array with
	-- holes into a dictionary, so the list is kept dense.
	local speakers: { string } = {}
	local speakerIds: { number } = {} -- 0 where nobody speaks; the client frames the speaker's shot and face from it
	local cursor = 0
	for i, beat in cfg.Beats do
		if beat.Line then
			cursor += 1
			local speaker = order[(cursor - 1) % #order + 1]
			speakers[i] = speaker.DisplayName
			speakerIds[i] = speaker.UserId
		else
			speakers[i] = ""
			speakerIds[i] = 0
		end
	end

	for i, player in cast do
		standOnHill(player, i)
	end

	local event = Net.getEvent("IntroEvent")
	for _, player in cast do
		event:FireClient(player, {
			kind = "start",
			speakers = speakers,
			speakerIds = speakerIds,
			votes = 0,
			needed = IntroService.votesNeeded(),
		})
	end
	log:info(("scene started for %d player(s)"):format(#cast))

	local token = endToken

	task.delay(totalSeconds(cfg) + cfg.FadeInSeconds * 0.5, function()
		if token == endToken then
			endScene("timeline")
		end
	end)
end

function IntroService.votesNeeded(): number
	local present = 0
	for _, player in cast do
		if player.Parent then
			present += 1
		end
	end
	-- the developer's table (Intro.SkipVotes): 1 of 1, 2 of 2, 2 of 3, 3 of 4, 3 of 5 ... 7 of 10
	local cfg = Config.get("Intro")
	return SkipVote.needed(present, cfg.SkipVotes, cfg.SkipOverflowShare)
end

local function onSkip(player: Player)
	if state ~= "playing" or not table.find(cast, player) or skipVotes[player] then
		return
	end
	skipVotes[player] = true
	local count = 0
	for voter in skipVotes do
		if voter.Parent then
			count += 1
		end
	end
	local needed = IntroService.votesNeeded()
	local event = Net.getEvent("IntroEvent")
	for _, member in cast do
		if member.Parent then
			event:FireClient(member, { kind = "votes", votes = count, needed = needed })
		end
	end
	if count >= needed then
		endScene("skipped")
	end
end

--==========================================================================
function IntroService.Init()
	local cfg = Config.get("Intro")
	if not cfg.Enabled then
		state = "finished"
	end
end

function IntroService.Start()
	Net.getEvent("RequestIntroSkip").OnServerEvent:Connect(onSkip)
	Net.getEvent("ClientReady").OnServerEvent:Connect(function(player)
		ready[player] = true
	end)

	Players.PlayerRemoving:Connect(function(player)
		skipVotes[player] = nil
		ready[player] = nil
		-- Somebody leaving can be the vote that was missing.
		if state == "playing" then
			local count = 0
			for voter in skipVotes do
				if voter.Parent and voter ~= player then
					count += 1
				end
			end
			if count > 0 and count >= IntroService.votesNeeded() then
				endScene("skipped")
			end
		end
	end)

	if state == "finished" then
		log:info("disabled (Intro.Enabled = false)")
		return
	end

	--[[
		Take every body that appears before the scene starts straight up the
		hill. The arrival pad is inside chamber 1, and a player left standing on
		it for the few seconds the party takes to load has already walked into
		the first room as far as AreaService is concerned: the barricade arms,
		the first wave is called, and the dead are waiting by the time the
		scene ends.
	]]
	local function hold(player: Player)
		local function place()
			if state ~= "waiting" then
				return
			end
			local character = player.Character
			if character and character:WaitForChild("HumanoidRootPart", 5) and state == "waiting" then
				standOnHill(player, table.find(Players:GetPlayers(), player) or 1)
			end
		end
		player.CharacterAdded:Connect(function()
			task.defer(place)
		end)
		if player.Character then
			task.defer(place)
		end
	end
	for _, player in Players:GetPlayers() do
		hold(player)
	end
	Players.PlayerAdded:Connect(hold)

	-- Start once the first player is in and the rest of a teleported party has
	-- had a fair chance to load.
	task.spawn(function()
		while #Players:GetPlayers() == 0 do
			Players.PlayerAdded:Wait()
		end
		local cfg = Config.get("Intro")
		local deadline = os.clock() + cfg.WaitForPartySeconds
		-- A party arrives together; once nobody new has joined for 3 seconds,
		-- the party is here.
		local lastJoin = os.clock()
		local conn = Players.PlayerAdded:Connect(function()
			lastJoin = os.clock()
		end)
		while os.clock() < deadline and os.clock() - lastJoin < 3 do
			task.wait(0.25)
		end
		conn:Disconnect()

		-- Then until each of them has finished loading (their loading screen is gone), so nobody's first
		-- seconds of the scene play behind a loading bar. A time limit keeps one slow connection from holding
		-- the whole party at the gate.
		local readyDeadline = os.clock() + cfg.WaitForLoadingSeconds
		local function everyoneReady(): boolean
			for _, player in Players:GetPlayers() do
				if not ready[player] then
					return false
				end
			end
			return true
		end
		while os.clock() < readyDeadline and not everyoneReady() do
			task.wait(0.25)
		end
		playScene()
	end)

	log:info("ready")
end

return IntroService
