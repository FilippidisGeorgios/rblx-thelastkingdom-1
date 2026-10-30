--!strict
--[[
	CrouchService
	Ducking down, for the low passages and for being quiet (configs/Crouch, rules in Server/Domain/Crouch).

	The client only ASKS (`RequestCrouch`, a boolean). This service decides:
	  - going down is always allowed to a living player (a key that is hammered is held to `ToggleGap`);
	  - coming up is allowed only where there is room: it looks straight up from the head (five rays, so the edge of a
	    ceiling is not missed) and keeps the player down under anything solid. The player is told in a line at the top
	    ("There is no room to stand.").

	WHAT CHANGES. The body gets shorter (R15 `BodyHeightScale`, tweened), the WalkSpeed takes a claim (so the Brass
	Stirrup and the King's frost are not trampled; see Domain/Crouch), and `Crouching` is published on the Player and
	on the Humanoid, which the hunters and the dead will read when they listen for footsteps.

	A new body (respawn) is always standing. A player whose rig has no `BodyHeightScale` (an R6 body) still gets the
	slower walk, and the log says so once.

	Place: Forgotten Lands ONLY (Server/World).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Server = script.Parent.Parent
local CrouchRules = require(Server.Domain.Crouch)
local GameService = require(Server.Services.GameService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local CrouchService = {}

CrouchService.Name = "CrouchService"

local log = Logger.new("CrouchService")

type State = {
	crouched: boolean,
	claim: CrouchRules.Claim,
	last: number?,
	humanoid: Humanoid?,
	noteToken: number,
	-- the body as it was standing: its own height scale (an avatar may be 1.05, or 0.9) and how tall it stood
	standScale: number,
	standHeight: number,
}

local states: { [Player]: State } = {}
local warnedNoScale = false

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { crouched = false, claim = {}, last = nil, humanoid = nil, noteToken = 0, standScale = 1, standHeight = 0 }
		states[player] = state
	end
	return state
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- A line at the top for this player only, then it clears.
local function tell(player: Player, text: string)
	local state = stateOf(player)
	state.noteToken += 1
	local token = state.noteToken
	local event = Net.getEvent("ObjectiveHint")
	event:FireClient(player, { source = "crouch", text = text })
	task.delay(2.5, function()
		if state.noteToken == token and player.Parent then
			event:FireClient(player, { source = "crouch", text = nil })
		end
	end)
end

local function setScale(humanoid: Humanoid, scale: number, seconds: number): boolean
	local value = humanoid:FindFirstChild("BodyHeightScale")
	if not (value and value:IsA("NumberValue")) then
		return false
	end
	TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = scale }):Play()
	return true
end

--[[
	How many studs are clear straight above this body's head. Five rays (the middle and four points round it) so a
	ceiling's edge over only one shoulder still counts. Parts that do not collide are not ceilings, and neither are
	other bodies (a friend standing on the stair above you does not shut you in).
]]
local function clearAbove(character: Model, reach: number): number
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return reach
	end
	local top = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.05, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore: { Instance } = { character }
	params.FilterDescendantsInstances = ignore

	local best = reach
	for _, offset in { Vector3.zero, Vector3.new(0.7, 0, 0), Vector3.new(-0.7, 0, 0), Vector3.new(0, 0, 0.7), Vector3.new(0, 0, -0.7) } do
		-- cast, skipping other bodies (up to a few), until a solid thing or the top of the reach
		for _ = 1, 4 do
			local hit = Workspace:Raycast(top + offset, Vector3.new(0, reach, 0), params)
			if not hit then
				break
			end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				table.insert(ignore, model)
				params.FilterDescendantsInstances = ignore
			else
				best = math.min(best, hit.Distance)
				break
			end
		end
	end
	return best
end

local function height(character: Model, humanoid: Humanoid): number
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return 0
	end
	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	return head.Position.Y + head.Size.Y / 2 - feet
end

local function publish(player: Player, humanoid: Humanoid?, on: boolean)
	player:SetAttribute("Crouching", if on then true else nil)
	if humanoid then
		humanoid:SetAttribute("Crouching", if on then true else nil)
	end
end

local function goDown(player: Player, humanoid: Humanoid, state: State)
	local cfg = Config.get("Crouch")
	state.crouched = true
	state.humanoid = humanoid
	-- remember the standing body before it changes: the avatar's own scale, and how tall it is
	local value = humanoid:FindFirstChild("BodyHeightScale")
	state.standScale = if value and value:IsA("NumberValue") then value.Value else 1
	local measured = height(player.Character :: Model, humanoid)
	state.standHeight = if measured > 1 then measured else cfg.StandHeight
	humanoid.WalkSpeed = CrouchRules.enter(state.claim, humanoid.WalkSpeed, cfg.SpeedMult)
	if not setScale(humanoid, math.min(state.standScale, cfg.CrouchScale), cfg.TweenSeconds) and not warnedNoScale then
		warnedNoScale = true
		log:warn("this body has no BodyHeightScale (R6?): crouching only slows the walk")
	end
	publish(player, humanoid, true)
end

local function standUp(player: Player, humanoid: Humanoid?, state: State)
	local cfg = Config.get("Crouch")
	state.crouched = false
	if humanoid then
		local speed = CrouchRules.leave(state.claim, humanoid.WalkSpeed)
		if speed then
			humanoid.WalkSpeed = speed
		end
		setScale(humanoid, state.standScale, cfg.TweenSeconds)
	else
		state.claim = {}
	end
	publish(player, humanoid, false)
end

local function onRequest(player: Player, want: any)
	if typeof(want) ~= "boolean" then
		return
	end
	local cfg = Config.get("Crouch")
	if not cfg.Enabled then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local state = stateOf(player)
	local now = os.clock()
	if not CrouchRules.mayToggle(now, state.last, cfg.ToggleGap) then
		return
	end
	if want == state.crouched then
		return
	end
	state.last = now

	if want then
		goDown(player, humanoid, state)
		return
	end

	-- coming up needs room
	local character = player.Character :: Model
	local above = clearAbove(character, state.standHeight + 1)
	if CrouchRules.hasRoom(above, height(character, humanoid), state.standHeight) then
		standUp(player, humanoid, state)
	else
		tell(player, "There is no room to stand.")
	end
end

local function onCharacter(player: Player, character: Model)
	-- a new body is a standing one
	local state = stateOf(player)
	state.crouched = false
	state.claim = {}
	state.humanoid = nil
	publish(player, nil, false)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			state.crouched = false
			state.claim = {}
			publish(player, humanoid, false)
		end)
	end
end

--==========================================================================
function CrouchService.Init() end

function CrouchService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	Net.getEvent("RequestCrouch").OnServerEvent:Connect(onRequest)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	log:info("ready")
end

--[[
	Is this player crouched right now? For the hunters and the dead, which listen for footsteps.
]]
function CrouchService.isCrouched(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.crouched
end

return CrouchService
