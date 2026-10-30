--!strict
--[[
	Net
	Central registry and factory for networking objects (RemoteEvents /
	RemoteFunctions). This is the single contract shared by client and server so
	remotes are never created ad-hoc or looked up by hard-coded path.

	How it works:
		- Remotes are DECLARED by name in the lists below.
		- On the server, the declared remotes are created under a single
		  ReplicatedStorage.Remotes folder at require time.
		- Client and server both fetch a remote via `Net.getEvent(name)` /
		  `Net.getFunction(name)`, which resolves it from that folder.

	A remote name is declared only when a feature needs one (and only here). The
	server validates every incoming call — clients send intent, the server decides.
	The first remotes belong to the combat vertical slice.

	Location: ReplicatedStorage.Shared.Net
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

-- Declare remote names here as the architecture grows.
local EVENT_NAMES: { string } = {
	"RequestMeleeAttack", -- client -> server: melee swing intent (server-validated)
	"CombatEvent", -- server -> client: combat outcome notifications (hit feedback)
	"MissionEvent", -- server -> client: mission/objective feed (start / objective / progress / complete / narrative)
	"DeathEvent", -- server -> client: death state (downed / choices / revived / left / wiped)
	"RequestDeathChoice", -- client -> server: a downed player's choice (Lobby / Revive / Wait)
	"RequestPlayAgain", -- client -> server: retry the chapter after a run-over (Play Again)
	"TrainEvent", -- server -> client: hub departure feed (prompt / status / aboard / departing)
	"RequestTrainBoard", -- client -> server: call a party of N, or take a seat in the one forming
	"RequestTrainLeave", -- client -> server: step off the train before it departs
	"RequestTrainDepart", -- client -> server: the party leader leaves early, skipping the countdown
	"InteractionEvent", -- server -> client: entered / left a lobby interaction point (NPC, chest, …)
	"ForgeEvent", -- server -> client: the blacksmith's stock, gold and upgrade results
	"RequestForgeState", -- client -> server: open the forge / refresh it
	"RequestForgeUpgrade", -- client -> server: buy the next level of one weapon
	"AreaEvent", -- server -> client: which chamber you are in, and whether its gate is shut
	"ObjectiveHint", -- server -> client: the one line at the top saying what to do now
	"RequestToggleWeapon", -- client -> server: draw the weapon, or put it away
	"WeaponState", -- server -> client: who has their weapon out, so arms can be posed
	"IntroEvent", -- server -> client: the arrival scene (start / votes / end / arrived)
	"RequestIntroSkip", -- client -> server: this player votes to skip the arrival scene
	"DocumentEvent", -- server -> client: open a parchment (a recipe, a letter, a burial roll) for one player
	"BackpackEvent", -- server -> client: the run backpack (set) and what was just picked up (gain)
	"EndingEvent", -- server -> client: the end of the run: the screen closes on a title and a few lines
	"CampEvent", -- server -> client: the camp bench opens (recipes and what can be made) / updates
	"RequestCraft", -- client -> server: make recipe `id` at the camp bench
	"ChapelEvent", -- server -> client: the Hub chapel's state (the Tithe, the Reliquary, the Altar, the Journal)
	"RequestChapel", -- client -> server: { action = "state"|"tithe"|"charm"|"forge"|"offer", id = string? }
	"CharmEvent", -- server -> client: a worn charm just did something { kind = "cue", charm, title, line }
	"RequestProfile", -- client -> server: "my muster roll" (no arguments: you can only ask for your own)
	"ProfileEvent", -- server -> client: { kind = "card", card = PlayerCard } or { kind = "unavailable" }
	"RequestSettings", -- client -> server: { graphics = "Low"|"Medium"|"High"|"Ultra"?, shadows = boolean? } (checked by Shared/PlayerSettings)
	"RequestInventory", -- client -> server: "my inventory" (the Hub fills the left-hand panel with the stash and the road's prizes)
	"RequestClaimPrize", -- client -> server: the level of the road's prize to take (Domain/Prizes decides if it may be taken)
	"ClientReady", -- client -> server: this player's loading screen has gone (the world is drawn); the arrival scene waits for it
	"RequestCrouch", -- client -> server: a boolean, duck down (true) or stand up (false); the server checks there is room to stand
}
local FUNCTION_NAMES: { string } = {}

local Net = {}

local function getFolder(): Instance?
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:FindFirstChild(FOLDER_NAME)
end

-- Build declared remotes on the server. Skipped entirely when nothing is
-- declared, so Phase 1 creates no instances at all.
if IS_SERVER and (#EVENT_NAMES > 0 or #FUNCTION_NAMES > 0) then
	local folder = getFolder()
	if folder then
		for _, name in EVENT_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
		for _, name in FUNCTION_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

-- Resolves the Remotes folder. On the server it exists (created above); on the
-- client it may not have replicated yet, so we wait for it.
local function resolveFolder(): Instance
	if IS_SERVER then
		local folder = getFolder()
		assert(folder, "Remotes folder is not available")
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
	assert(folder, "Remotes folder did not replicate")
	return folder
end

function Net.getEvent(name: string): RemoteEvent
	local remote = resolveFolder():WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Missing RemoteEvent: " .. name)
	return remote
end

function Net.getFunction(name: string): RemoteFunction
	local remote = resolveFolder():WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "Missing RemoteFunction: " .. name)
	return remote
end

return Net
