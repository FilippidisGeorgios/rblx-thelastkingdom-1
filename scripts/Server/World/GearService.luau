--!strict
--[[
	GearService
	What a player carries on the back besides the weapons: the QUIVER (configs/Gear.Back, docs/systems/Gear.md).

	  QUIVER   a small leather quiver with the arrows that are left standing in it. Only with it on the back does a bow
	           have arrows (`arrows`, `takeArrow`: World/RangedCombatService asks). An empty quiver takes a bundle out of
	           the pack by itself, if there is one.

	NO BODY ARMOUR (the developer, 2026-11-13): "when I said armour I meant a SHIELD, the thing held in the left hand".
	Everything that was here for plate worn on the body (the F key, putting it on and off piece by piece, the bundle on
	the back, the swap between armour and quiver, the share of every blow turned aside) is gone. The shield comes later,
	with a model of its own, held in the left hand.

	Published on the Player: `Arrows`. A new body carries the quiver again with what is left in it.

	The model is made by Domain/GearModels from the sculpted kit; nothing here collides or can be hit.

	Place: Forgotten Lands ONLY (Server/World).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GearModels = require(Server.Domain.GearModels)
local AvatarService = require(Server.Services.AvatarService)
local GameService = require(Server.Services.GameService)
local BackpackService = require(script.Parent.BackpackService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local GearService = {}

GearService.Name = "GearService"

local log = Logger.new("GearService")

type State = {
	arrows: number,
	noteToken: number,
	shownArrows: number,
}

local states: { [Player]: State } = {}

local function cfg(): any
	return Config.get("Gear")
end

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = {
			arrows = cfg().Starter.Arrows,
			noteToken = 0,
			shownArrows = -1,
		}
		states[player] = s
	end
	return s
end

local function livingHumanoid(player: Player): (Humanoid?, Model?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return humanoid, character
	end
	return nil, nil
end

-- A line at the top for this player only, then it clears.
local function tell(player: Player, text: string)
	local state = stateOf(player)
	state.noteToken += 1
	local token = state.noteToken
	local event = Net.getEvent("ObjectiveHint")
	event:FireClient(player, { source = "gear", text = text })
	task.delay(2.8, function()
		if state.noteToken == token and player.Parent then
			event:FireClient(player, { source = "gear", text = nil })
		end
	end)
end

local function publish(player: Player)
	player:SetAttribute("Arrows", stateOf(player).arrows)
end

-- What is on the body right now, made again from the state (a new body, a change in the arrows standing in the quiver).
local function dress(player: Player)
	local state = stateOf(player)
	local _, character = livingHumanoid(player)
	if not character then
		return
	end
	local quiver = cfg().Back.Quiver
	local old = character:FindFirstChild("Quiver")
	if old then
		old:Destroy()
	end
	GearModels.quiver(character, quiver, state.arrows)
	state.shownArrows = math.min(state.arrows, quiver.Arrows.Most)
end

--==========================================================================
-- Arrows (for World/RangedCombatService)
--==========================================================================

-- How many arrows `player` can loose right now.
function GearService.arrows(player: Player): number
	return stateOf(player).arrows
end

-- Why a bow cannot be drawn, as a line for the player; nil when it can.
function GearService.noArrowsReason(player: Player): string?
	local state = stateOf(player)
	if state.arrows <= 0 then
		local quiver = cfg().Back.Quiver
		local ok, n = pcall(BackpackService.count, player, quiver.BundleItem)
		if not (ok and n > 0) then
			return "The quiver is empty."
		end
	end
	return nil
end

-- Fills an empty quiver from a bundle in the pack. Returns whether it holds an arrow now.
local function refill(player: Player): boolean
	local state = stateOf(player)
	if state.arrows > 0 then
		return true
	end
	local quiver = cfg().Back.Quiver
	local ok, taken = pcall(BackpackService.remove, player, quiver.BundleItem, 1)
	if ok and taken then
		state.arrows = math.min(quiver.Capacity, quiver.BundleArrows)
		tell(player, "A bundle of arrows into the quiver.")
		return true
	end
	return false
end

-- Takes one arrow out of the quiver. False when there is none (and none to be had from the pack).
function GearService.takeArrow(player: Player): boolean
	local state = stateOf(player)
	if not refill(player) then
		return false
	end
	state.arrows -= 1
	if state.arrows <= 0 then
		refill(player)
	end
	publish(player)
	-- the arrows standing in the quiver are only drawn again when their number (up to the few that are drawn) changes
	local most = cfg().Back.Quiver.Arrows.Most
	if math.min(state.arrows, most) ~= state.shownArrows then
		dress(player)
	end
	return true
end

-- Puts `count` arrows in the quiver (a find, a test). Returns how many went in.
function GearService.addArrows(player: Player, count: number): number
	local state = stateOf(player)
	local room = cfg().Back.Quiver.Capacity - state.arrows
	local put = math.clamp(math.floor(count), 0, math.max(room, 0))
	state.arrows += put
	publish(player)
	dress(player)
	return put
end

--==========================================================================
local function onCharacter(player: Player, character: Model)
	publish(player)
	task.spawn(function()
		if AvatarService.waitReady(character) and player.Character == character then
			dress(player)
		end
	end)
end

function GearService.Init() end

function GearService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end

	local function watch(player: Player)
		stateOf(player)
		publish(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	log:info("ready: the quiver on the back")
end

return GearService
