--!strict
--[[
	GearService
	The one thing on a player's back: the ARMOUR or the QUIVER (configs/Gear.Back, docs/systems/Gear.md; the developer,
	2026-11-10: "on the back a player can put only one thing, an armour or arrows").

	  ARMOUR   carried, it is a bundle of plate strapped on the back. F (`RequestArmour`) puts it ON: the pieces appear
	           one after another over a second and a half while the arms pull it on (every client plays that from the
	           Humanoid's `GearAct` / `GearSeq`), and F takes it off again. Worn, a quarter of every ordinary blow is
	           turned aside and the stamina bar fills a tenth slower (docs/systems/Arsenal.md 6, the Medium class).
	  QUIVER   a small leather quiver with the arrows that are left standing in it. Only with it on the back does a bow
	           have arrows (`arrows`, `takeArrow`: World/RangedCombatService asks). An empty quiver takes a bundle out of
	           the pack by itself, if there is one.
	  THE CHANGE between the two is `RequestBack` (the client offers it while the mouse is free). Armour that is being
	           worn has to come off first.

	Published on the Player: `Back` ("armour" | "quiver"), `ArmourOn`, `Arrows`. A new body carries what the old one did,
	with the armour OFF.

	The models are made by Domain/GearModels from the sculpted kit; nothing here collides or can be hit.

	Place: Forgotten Lands ONLY (Server/World).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GearModels = require(Server.Domain.GearModels)
local AvatarService = require(Server.Services.AvatarService)
local GameService = require(Server.Services.GameService)
local MovementService = require(Server.Services.MovementService)
local BackpackService = require(script.Parent.BackpackService)
local CombatService = require(script.Parent.CombatService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local GearService = {}

GearService.Name = "GearService"

local log = Logger.new("GearService")

type State = {
	back: string,
	armourOn: boolean,
	arrows: number,
	busyUntil: number,
	lastSwap: number,
	seq: number,
	token: number, -- a change of clothes in progress is dropped when another begins
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
		local starter = cfg().Starter
		s = {
			back = starter.Back,
			armourOn = false,
			arrows = starter.Arrows,
			busyUntil = 0,
			lastSwap = 0,
			seq = 0,
			token = 0,
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
	local state = stateOf(player)
	player:SetAttribute("Back", state.back)
	player:SetAttribute("ArmourOn", if state.armourOn then true else nil)
	player:SetAttribute("Arrows", state.arrows)
end

local function remove(character: Model, name: string)
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- What is on the body right now, made again from the state (a new body, a change of what is carried).
local function dress(player: Player)
	local state = stateOf(player)
	local _, character = livingHumanoid(player)
	if not character then
		return
	end
	local back = cfg().Back
	remove(character, "Armour")
	remove(character, "ArmourBundle")
	remove(character, "Quiver")
	if state.back == "quiver" then
		GearModels.quiver(character, back.Quiver, state.arrows)
		state.shownArrows = math.min(state.arrows, back.Quiver.Arrows.Most)
	elseif state.armourOn then
		GearModels.wear(character, "Armour", back.Armour.Worn)
	else
		GearModels.wear(character, "ArmourBundle", back.Armour.Bundle)
	end
end

local function applyEffects(player: Player)
	local state = stateOf(player)
	MovementService.setRefillScale(player, if state.armourOn then cfg().Back.Armour.StaminaRefill else 1)
end

--==========================================================================
-- Arrows (for World/RangedCombatService)
--==========================================================================

-- How many arrows `player` can loose right now (none without the quiver on the back).
function GearService.arrows(player: Player): number
	local state = stateOf(player)
	return if state.back == "quiver" then state.arrows else 0
end

-- Why a bow cannot be drawn, as a line for the player; nil when it can.
function GearService.noArrowsReason(player: Player): string?
	local state = stateOf(player)
	if state.back ~= "quiver" then
		return "The quiver is not on your back."
	end
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
	if state.back ~= "quiver" or not refill(player) then
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
	if state.back == "quiver" then
		dress(player)
	end
	return put
end

function GearService.isArmoured(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.armourOn
end

--==========================================================================
-- The armour on and off
--==========================================================================
local function announce(humanoid: Humanoid, state: State, act: string)
	state.seq += 1
	humanoid:SetAttribute("GearAct", act)
	humanoid:SetAttribute("GearSeq", state.seq)
end

function GearService.setArmour(player: Player, on: boolean): boolean
	local state = stateOf(player)
	local humanoid, character = livingHumanoid(player)
	if not (humanoid and character) or state.back ~= "armour" or state.armourOn == on then
		return false
	end
	local now = os.clock()
	if now < state.busyUntil then
		return false
	end
	local armour = cfg().Back.Armour
	state.armourOn = on
	state.busyUntil = now + (if on then armour.DonSeconds else armour.DoffSeconds)
	state.token += 1
	local token = state.token
	publish(player)
	announce(humanoid, state, if on then "don" else "doff")

	local function still(): boolean
		return state.token == token and player.Character == character and character.Parent ~= nil
	end

	if on then
		-- every piece is there at once but unseen; each shows at its own moment, as the arms reach it
		local holder, groups = GearModels.wear(character, "Armour", armour.Worn)
		local first = math.huge
		for i, group in groups do
			first = math.min(first, armour.Worn[i].After)
			for _, part in group do
				part:SetAttribute("Seen", part.Transparency)
				part.Transparency = 1
			end
			task.delay(armour.Worn[i].After, function()
				if not still() or not holder.Parent then
					return
				end
				for _, part in group do
					if part.Parent then
						part.Transparency = part:GetAttribute("Seen") or 0
					end
				end
			end)
		end
		-- the bundle leaves the back as the first piece arrives
		task.delay(math.max(0.05, first - 0.2), function()
			if still() then
				remove(character, "ArmourBundle")
			end
		end)
	else
		task.delay(armour.DoffSeconds * 0.42, function()
			if still() then
				remove(character, "Armour")
			end
		end)
		task.delay(armour.DoffSeconds * 0.66, function()
			if still() and not character:FindFirstChild("ArmourBundle") then
				GearModels.wear(character, "ArmourBundle", armour.Bundle)
			end
		end)
	end
	applyEffects(player)
	return true
end

function GearService.setBack(player: Player, what: string): boolean
	local state = stateOf(player)
	local labels = cfg().Back.Labels
	if labels[what] == nil or what == state.back then
		return false
	end
	local humanoid = livingHumanoid(player)
	if not humanoid then
		return false
	end
	if state.armourOn then
		tell(player, "Take the armour off first.")
		return false
	end
	local now = os.clock()
	if now - state.lastSwap < cfg().Back.SwapSeconds or now < state.busyUntil then
		return false
	end
	state.lastSwap = now
	state.token += 1
	state.back = what
	publish(player)
	dress(player)
	tell(player, if what == "quiver" then "The quiver is on your back." else "The armour is on your back.")
	return true
end

--==========================================================================
local function onCharacter(player: Player, character: Model)
	local state = stateOf(player)
	-- a new body: what it carried, the armour off
	state.armourOn = false
	state.busyUntil = 0
	state.token += 1
	publish(player)
	applyEffects(player)
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

	-- worn armour turns part of a blow aside (not what ignores armour)
	CombatService.registerModifier(function(context)
		if context.request.damageType == "True" then
			return
		end
		local model = context.target.model
		local player = model and Players:GetPlayerFromCharacter(model)
		local state = player and states[player]
		if state and state.armourOn then
			context.amount *= cfg().Back.Armour.DamageTaken
		end
	end)

	Net.getEvent("RequestArmour").OnServerEvent:Connect(function(player: Player, on: any)
		if typeof(on) == "boolean" then
			GearService.setArmour(player, on)
		end
	end)
	Net.getEvent("RequestBack").OnServerEvent:Connect(function(player: Player, what: any)
		if typeof(what) == "string" then
			GearService.setBack(player, what)
		end
	end)

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
	log:info("ready: the back holds the armour or the quiver")
end

return GearService
