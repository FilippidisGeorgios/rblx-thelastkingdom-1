--!strict
--[[
	AvatarService
	Every player has a SQUARE body (the developer, 2026-11-10: "square legs, square arms, all of it square"): the plain
	block torso, arms and legs of Roblox's classic figure, the same size for everybody. A player keeps what makes them
	themselves: their head and face, their hair and hats, their clothes and their colours.

	WHY THE SAME SIZE. A tall, thin or child-sized avatar is a different target and reaches different things; the low
	passages, the crouch, the hands on a spear and the eyes' height are all measured on one body.

	HOW. A player's own look (their HumanoidDescription) is fetched once when they join; the body parts are set to none
	(which is the block body) and the scales to the standard ones. Then:
	  * `AvatarService.loadCharacter(player)` spawns them with it at once (the Forgotten Lands spawns every body itself:
	    World/DeathService calls this instead of `LoadCharacter`), and
	  * a body that was spawned any other way (the lobby's own automatic spawn, or a join so quick the look had not
	    arrived) is given it as soon as it stands, once.
	A body's parts and joints are replaced when a look is applied to a standing body, so anything that holds on to them
	(the clients' pose rigs) looks again; a weapon is only put in a hand after `AvatarService.ready(character)`.

	Also here, because it is the same "every player is the same" rule: the camera is locked to first person for every
	player from the server's side too (the client sets it as well, configs/View).

	Place: shared (both places).
	Location: ServerScriptService.Server.Services.AvatarService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local AvatarService = {}

AvatarService.Name = "AvatarService"

local log = Logger.new("AvatarService")

local looks: { [Player]: HumanoidDescription } = {}
local fetching: { [Player]: boolean } = {}

-- The body parts that become blocks (0 = Roblox's own default part, the block), and the scales everybody shares.
local BLOCK_PARTS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local SCALES = { HeightScale = 1, WidthScale = 1, DepthScale = 1, HeadScale = 1, BodyTypeScale = 0, ProportionScale = 0 }

local function squared(description: HumanoidDescription): HumanoidDescription
	local made = description:Clone()
	for _, part in BLOCK_PARTS do
		(made :: any)[part] = 0
	end
	for scale, value in SCALES do
		(made :: any)[scale] = value
	end
	return made
end

local function isSquare(description: HumanoidDescription): boolean
	for _, part in BLOCK_PARTS do
		if (description :: any)[part] ~= 0 then
			return false
		end
	end
	for scale, value in SCALES do
		if math.abs((description :: any)[scale] - value) > 1e-3 then
			return false
		end
	end
	return true
end

local function fetch(player: Player)
	if looks[player] or fetching[player] then
		return
	end
	fetching[player] = true
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, description = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
			end)
			if ok and description and player.Parent then
				looks[player] = squared(description)
				break
			end
			task.wait(attempt)
		end
		fetching[player] = nil
	end)
end

-- Has this body been made square (or was it spawned square)? A weapon waits for this before it takes a hand.
function AvatarService.ready(character: Model): boolean
	return character:GetAttribute("SquareBody") == true
end

--[[
	Waits until `character` stands in the world with its square body (at most `timeout` seconds, 12 by default), and
	returns whether it is in the world then. A service that puts something ON a body calls this first.
	(`CharacterAdded` is told a moment BEFORE the body is put in the world: a check of `character.Parent` made at once
	says "gone" about a body that has not arrived yet. Found in play, 2026-11-11: no weapons and no armour on anybody.)
]]
function AvatarService.waitReady(character: Model, timeout: number?): boolean
	local limit = os.clock() + (timeout or 12)
	local arrived = false
	while os.clock() < limit do
		local here = character:IsDescendantOf(workspace)
		if here then
			arrived = true
			if character:GetAttribute("SquareBody") == true then
				return true
			end
		elseif arrived then
			return false -- it was here and has left: a body that died or was replaced
		end
		task.wait(0.1)
	end
	return character:IsDescendantOf(workspace)
end

--[[
	Spawns `player` with their square body (or, if their look has not arrived yet, as they are: the body is squared as
	soon as it stands). The same as `player:LoadCharacter()` for the caller: it yields until the body exists.
]]
function AvatarService.loadCharacter(player: Player)
	-- a player who has only just joined: their look is a moment away, and a body spawned square needs no second pass
	local waited = 0
	while not looks[player] and fetching[player] and waited < 2 and player.Parent do
		task.wait(0.1)
		waited += 0.1
	end
	local look = looks[player]
	if look then
		local ok = pcall(function()
			player:LoadCharacterWithHumanoidDescription(look)
		end)
		if ok then
			local character = player.Character
			if character then
				character:SetAttribute("SquareBody", true)
			end
			return
		end
	end
	player:LoadCharacter()
end

local function squareStanding(player: Player, character: Model)
	if character:GetAttribute("SquareBody") then
		return
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		-- (the body is announced a moment before it is put in the world)
		local waitedForWorld = 0
		while not character:IsDescendantOf(workspace) and waitedForWorld < 5 do
			task.wait(0.05)
			waitedForWorld += 0.05
		end
		-- the body's own look has to be on it before another can be laid over it
		if not player:HasAppearanceLoaded() then
			local done = false
			local connection = player.CharacterAppearanceLoaded:Connect(function()
				done = true
			end)
			local waited = 0
			while not done and waited < 8 and character.Parent do
				task.wait(0.1)
				waited += 0.1
			end
			connection:Disconnect()
		end
		if character:GetAttribute("SquareBody") or not character.Parent or humanoid.Health <= 0 then
			return
		end
		local look = looks[player]
		if not look then
			-- the look never arrived (a test player with no account): square what the body is wearing
			local ok, worn = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			if ok and worn then
				look = squared(worn)
			end
		end
		if look and not (function()
			local ok, worn = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			return ok and worn ~= nil and isSquare(worn)
		end)() then
			local ok, err = pcall(function()
				humanoid:ApplyDescription(look)
			end)
			if not ok then
				log:warn(("could not square %s's body: %s"):format(player.Name, tostring(err)))
			end
		end
		if character.Parent then
			character:SetAttribute("SquareBody", true)
		end
	end)
end

function AvatarService.Init() end

function AvatarService.Start()
	local firstPerson = Config.get("View").FirstPerson

	local function watch(player: Player)
		fetch(player)
		if firstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		player.CharacterAdded:Connect(function(character)
			squareStanding(player, character)
		end)
		if player.Character then
			squareStanding(player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		looks[player] = nil
		fetching[player] = nil
	end)
	log:info("ready: square bodies for everybody")
end

return AvatarService
