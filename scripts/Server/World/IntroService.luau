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
local sceneAt = 0 -- server time the scene began (a late player joins it at the same moment)
local runAt = 0 -- os.clock() when the scene ended and the first area began (for the late-join limit)
local lastStart: { speakers: { string }, speakerIds: { number } }? = nil

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
	runAt = os.clock()
	ReplicatedStorage:SetAttribute("TLK_GateState", "open")
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

--[[
	THE PARTY ON THE HILL (2026-11-15, the developer: "not only one speaks: the three in front speak; everyone is seen;
	not side by side; each in a way of their own"). Eight places in the first mark's own space (x to its right, z back
	toward the cameras), loosely grouped, none in a line: three in front (they are the ones who speak) and five behind;
	a ninth player and more stand a little further back. Who stands where is shuffled for each scene. Each place has a
	way of waiting (`ScenePose` on the character; Shared/Anim/PlayerMoveAnims SCENE POSES, played by every client):
	the front ones stand or kneel, so their faces can be filmed; the ones behind may sit or crouch.
]]
local WeaponVisualService = require(script.Parent.WeaponVisualService)

local SPOTS = {
	{ x = 0.0, z = -1.6, yaw = 4 },
	{ x = -6.2, z = -0.4, yaw = 14 },
	{ x = 5.8, z = -0.9, yaw = -10 },
	{ x = -2.9, z = 3.6, yaw = 8 },
	{ x = 3.2, z = 4.2, yaw = -6 },
	{ x = -9.8, z = 3.2, yaw = 20 },
	{ x = 9.4, z = 4.8, yaw = -18 },
	{ x = 0.4, z = 7.2, yaw = 0 },
}
local FRONT = 3
local FRONT_POSES = { "watch", "arms", "kneel", "brow" }
local BACK_POSES = { "sit", "crouch", "hips", "lookback", "watch", "arms" }
local spotPoses: { string } = {}

local function shuffled<T>(list: { T }, rng: Random): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A way of waiting for every place: the front ones from the standing poses, the others from the rest.
local function dealPoses(rng: Random)
	local front = shuffled(FRONT_POSES, rng)
	local back = shuffled(BACK_POSES, rng)
	table.clear(spotPoses)
	for i = 1, #SPOTS do
		spotPoses[i] = if i <= FRONT then front[(i - 1) % #front + 1] else back[(i - FRONT - 1) % #back + 1]
	end
end

-- The weapon in hand is put away while the scene plays (the drawn sword crossed the speaker's face), and given back
-- after it to whoever had it out.
local hadDrawn: { [Player]: boolean } = {}

local function putAway(player: Player)
	local ok, drawn = pcall(WeaponVisualService.isDrawn, player)
	if ok and drawn then
		hadDrawn[player] = true
		pcall(WeaponVisualService.setDrawn, player, false)
	end
end

local function giveBack(player: Player)
	if hadDrawn[player] then
		hadDrawn[player] = nil
		pcall(WeaponVisualService.setDrawn, player, true)
	end
end

local function standOnHill(player: Player, index: number)
	local folder = introFolder()
	local mark = folder and folder:FindFirstChild("Stand1")
	local root = rootOf(player)
	if not (mark and mark:IsA("BasePart") and root) then
		return
	end
	local character = player.Character :: Model
	local spot = SPOTS[(index - 1) % #SPOTS + 1]
	local ring = math.floor((index - 1) / #SPOTS)
	local place = mark.CFrame * CFrame.new(spot.x + ring * 1.7, 0, spot.z + ring * 6)
	-- on the ground under the place (the hill is not flat): the root stands 3 studs over it
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore: { Instance } = { folder :: Instance }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(place.Position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	local at = if hit then Vector3.new(place.Position.X, hit.Position.Y + 3, place.Position.Z) else place.Position
	local ahead = mark.CFrame.LookVector
	local flat = Vector3.new(ahead.X, 0, ahead.Z).Unit
	local look = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(spot.yaw)):VectorToWorldSpace(flat)
	character:PivotTo(CFrame.lookAt(at, at + look))
	root.Anchored = true -- still, looking at the castle; the way of waiting plays on every screen
	character:SetAttribute("ScenePose", spotPoses[(index - 1) % #SPOTS + 1] or "watch")
	putAway(player)
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
	;(player.Character :: Model):SetAttribute("ScenePose", nil)
	giveBack(player)
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

	-- Who stands where is shuffled; the three in front are the ones who speak, in a shuffled rotation, so the lines
	-- move between them and the first line is not always the host's.
	local rng = Random.new()
	cast = shuffled(cast, rng)
	dealPoses(rng)
	local front: { Player } = {}
	for i = 1, math.min(FRONT, #cast) do
		front[i] = cast[i]
	end
	local order = shuffled(front, rng)

	-- while the scene plays nobody holds a weapon (a sword drawn late, by a slow load, is put away too)
	task.spawn(function()
		while state == "playing" do
			for _, player in cast do
				if player.Parent then
					putAway(player)
				end
			end
			task.wait(0.5)
		end
	end)
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
	sceneAt = Workspace:GetServerTimeNow()
	lastStart = { speakers = speakers, speakerIds = speakerIds }
	ReplicatedStorage:SetAttribute("TLK_GateState", "open")
	for _, player in cast do
		event:FireClient(player, {
			kind = "start",
			speakers = speakers,
			speakerIds = speakerIds,
			votes = 0,
			needed = IntroService.votesNeeded(),
			at = sceneAt,
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
				character:SetAttribute("ScenePose", "watch")
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

	--[[
		LATE PLAYERS (2026-11-14). One who arrives while the scene plays is put into it at the moment the others are
		at (the scene's start time goes with it: IntroController skips what has passed). One who arrives after the
		first area began is let in for LateJoinSeconds; later than that, they are sent back to the lobby: a run in its
		third room is no place to land alone.
	]]
	Players.PlayerAdded:Connect(function(player)
		local cfg = Config.get("Intro")
		local start = lastStart
		if state == "playing" and start then
			task.spawn(function()
				-- their own loading screen first; the scene's clock keeps running meanwhile
				local deadline = os.clock() + 25
				while not ready[player] and os.clock() < deadline and player.Parent do
					task.wait(0.2)
				end
				if state ~= "playing" or not player.Parent or not waitForCharacter(player, 5) then
					return
				end
				table.insert(cast, player)
				standOnHill(player, #cast)
				Net.getEvent("IntroEvent"):FireClient(player, {
					kind = "start",
					speakers = start.speakers,
					speakerIds = start.speakerIds,
					votes = 0,
					needed = IntroService.votesNeeded(),
					at = sceneAt,
				})
			end)
		elseif state == "finished" and runAt > 0 and os.clock() - runAt > cfg.LateJoinSeconds then
			log:info(player.Name .. " came too late to the run: back to the lobby")
			local ok, Teleport = pcall(function(): any
				return require(script.Parent.Parent.Services.TeleportService)
			end)
			local sent = ok and Teleport.returnToHub({ player }, { reason = "late" })
			if not sent then
				player:Kick("The party has already gone too far into the castle. Join the next run from the lobby.")
			end
		end
	end)

	--[[
		THE GATE (2026-11-14, the developer). The loading screens show how many of the party have loaded, out of how
		many, and a count down: everyone waits at most WaitForPlayersSeconds for the whole party; once all of them are
		in the server, the assets get at most AssetsAfterAllInSeconds more; if every one of them has finished loading
		sooner, it opens at once. Then the scene. Shown through attributes on ReplicatedStorage (TLK_Gate*).
	]]
	task.spawn(function()
		while #Players:GetPlayers() == 0 do
			Players.PlayerAdded:Wait()
		end
		local cfg = Config.get("Intro")
		local function expected(): number
			local most = #Players:GetPlayers()
			for _, player in Players:GetPlayers() do
				local ok, data = pcall(function()
					return player:GetJoinData().TeleportData
				end)
				local members = if ok and typeof(data) == "table" then data.memberUserIds else nil
				if typeof(members) == "table" then
					most = math.max(most, #members)
				end
			end
			return most
		end
		local function readyCount(): number
			local n = 0
			for _, player in Players:GetPlayers() do
				if ready[player] then
					n += 1
				end
			end
			return n
		end
		local now = Workspace:GetServerTimeNow()
		local endsAt = now + cfg.WaitForPlayersSeconds
		local allIn = false
		ReplicatedStorage:SetAttribute("TLK_GateState", "waiting")
		while true do
			now = Workspace:GetServerTimeNow()
			local want = expected()
			local inCount = #Players:GetPlayers()
			local loaded = readyCount()
			if not allIn and inCount >= want then
				allIn = true
				endsAt = math.min(endsAt, now + cfg.AssetsAfterAllInSeconds)
			end
			ReplicatedStorage:SetAttribute("TLK_GateExpected", want)
			ReplicatedStorage:SetAttribute("TLK_GateIn", inCount)
			ReplicatedStorage:SetAttribute("TLK_GateReady", loaded)
			ReplicatedStorage:SetAttribute("TLK_GateEndsAt", endsAt)
			if (allIn and loaded >= want) or now >= endsAt then
				break
			end
			task.wait(0.2)
		end
		ReplicatedStorage:SetAttribute("TLK_GateState", "starting")
		playScene()
	end)

	log:info("ready")
end

return IntroService
