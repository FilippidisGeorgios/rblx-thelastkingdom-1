--!strict
--[[
	NametagService
	What floats over a player's head.

	IN THE KINGDOM HUB each player wears a small, quiet name of our own making in place of Roblox's: their
	nickname (the Roblox display name, never the @account name) in cream serif letters with a thin brass rule
	beneath, readable at a distance and never louder than the person. Nobody sees their own.

	IN THE FORGOTTEN LANDS there is no name at all, ours or Roblox's: in the castle you are looking at a person, not
	at a label, and a label over every head would tell the player where their friends are through a wall.

	Roblox's own overhead name and health bar are switched off in both places (the Humanoid's DisplayDistanceType).
	The nickname is not changed or chosen here: it is whatever the player's account says (a custom nickname would
	need text filtering, and is not built).

	Place: shared (both places). Phase: Presentation.

	Location: ServerScriptService.Server.Services.NametagService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameService = require(script.Parent.GameService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local NametagService = {}

NametagService.Name = "NametagService"

local log = Logger.new("NametagService")

local TAG = "TLKNameTag"
local CREAM = Color3.fromRGB(253, 243, 218)
local GOLD = Color3.fromRGB(218, 170, 72)

local function buildTag(player: Player, head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	-- nobody needs to read their own name floating above them
	gui.PlayerToHideFrom = player

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 22)
	name.Text = player.DisplayName
	name.TextSize = 18
	name.TextColor3 = CREAM
	name.TextTruncate = Enum.TextTruncate.AtEnd
	pcall(function()
		name.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	end)
	name.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = name

	-- a thin brass rule that fades out at both ends
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 25)
	rule.Size = UDim2.new(0.55, 0, 0, 1)
	rule.BackgroundColor3 = GOLD
	rule.BorderSizePixel = 0
	rule.Parent = gui
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = rule

	return gui
end

local function dress(player: Player, character: Model, showNickname: boolean)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	if not showNickname then
		return
	end
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild(TAG)
	if old then
		old:Destroy()
	end
	buildTag(player, head).Parent = head
end

local function watch(player: Player, showNickname: boolean)
	local function onCharacter(character: Model)
		task.spawn(dress, player, character, showNickname)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function NametagService.Init() end

function NametagService.Start()
	-- the nickname is shown in the Hub only; everywhere else there is nothing over a head
	local showNickname = GameService.getPlaceRole() == Constants.PlaceRole.Hub

	Players.PlayerAdded:Connect(function(player)
		watch(player, showNickname)
	end)
	for _, player in Players:GetPlayers() do
		watch(player, showNickname)
	end
	log:info(if showNickname then "ready: nicknames in the Hub" else "ready: no names over heads")
end

return NametagService
