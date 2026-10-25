--!strict
--[[
	BackpackService
	Every player's backpack for the length of the run (docs/systems/Spoils.md §7).
	The rules are the pure `Domain/Backpack`; this owns one per player, tells the
	owner's client what is in it, and is the ONE door anything goes through to put
	something in a pack or take something out.

	WHY ITS OWN SERVICE, NOT InventoryService
	InventoryService holds GEAR as discrete item instances with uids (a sword you
	own). A backpack is a different animal: counts of things, run-bound, gone
	when the run ends unless it is banked. Forcing both through one class would
	make stacking, slots and "this vanishes" fight the equipment rules. They
	meet only at banking, which is a later step.

	WHAT THE CLIENT IS TOLD
	  { kind = "set",  gold, stacks = {id=n}, carried = {id=n}, slots, used }
	      the whole pack, throttled, after any change
	  { kind = "gain", item?, gold?, count, rank }
	      one line for the pickup log

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Backpack = require(Server.Domain.Backpack)
local GameService = require(Server.Services.GameService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local BackpackService = {}

BackpackService.Name = "BackpackService"

local log = Logger.new("BackpackService")

-- A burst of pickups (a pile of dead) would send a pack per item; one every
-- tenth of a second is plenty for a readout.
local SYNC_SECONDS = 0.1
local RESYNC_SECONDS = 10

local packs: { [Player]: Backpack.Backpack } = {}
local dirty: { [Player]: boolean } = {}
local event: RemoteEvent? = nil

local function pack(player: Player): Backpack.Backpack
	local existing = packs[player]
	if existing then
		return existing
	end
	local rules = Config.get("Loot").Rules
	local created = Backpack.new(Config.get("Items"), rules.BackpackSlots)
	packs[player] = created
	return created
end

local function markDirty(player: Player)
	dirty[player] = true
end

local function snapshot(player: Player)
	local bp = pack(player)
	return {
		kind = "set",
		gold = bp.gold,
		stacks = bp.stacks,
		carried = bp.carried,
		slots = bp.slots,
		used = bp:slotsUsed(),
	}
end

--==========================================================================
-- API
--==========================================================================

function BackpackService.get(player: Player): Backpack.Backpack
	return pack(player)
end

--[[
	Puts `count` of `itemId` in the pack. Returns how many went in (the rest did
	not fit). `quiet` skips the pickup line, for a quest item that has its own
	feedback.
]]
function BackpackService.add(player: Player, itemId: string, count: number, quiet: boolean?): number
	local taken = pack(player):add(itemId, count)
	if taken > 0 then
		markDirty(player)
		if not quiet and event then
			local item = Config.get("Items")[itemId]
			event:FireClient(player, {
				kind = "gain",
				item = itemId,
				name = if item then item.DisplayName else itemId,
				count = taken,
				rank = if item and item.Rank then item.Rank else "Worn",
				flavour = if item then item.Flavour else nil,
			})
		end
	end
	return taken
end

function BackpackService.addGold(player: Player, amount: number, quiet: boolean?)
	if amount <= 0 then
		return
	end
	pack(player):addGold(amount)
	markDirty(player)
	if not quiet and event then
		event:FireClient(player, { kind = "gain", gold = true, count = amount, rank = "Worn" })
	end
end

function BackpackService.count(player: Player, itemId: string): number
	return pack(player):count(itemId)
end

function BackpackService.remove(player: Player, itemId: string, count: number): boolean
	local ok = pack(player):remove(itemId, count)
	if ok then
		markDirty(player)
	end
	return ok
end

function BackpackService.spendGold(player: Player, amount: number): boolean
	local ok = pack(player):spendGold(amount)
	if ok then
		markDirty(player)
	end
	return ok
end

-- Empties a player's hands (quest items).
function BackpackService.clearCarried(player: Player)
	pack(player):clearCarried()
	markDirty(player)
end

-- One player's pack emptied (their run has been settled).
function BackpackService.reset(player: Player)
	local bp = packs[player]
	if bp then
		bp:reset()
		markDirty(player)
	end
end

-- A new run: every pack empty.
function BackpackService.resetAll()
	for player, bp in packs do
		bp:reset()
		markDirty(player)
	end
end

--==========================================================================
function BackpackService.Init() end

function BackpackService.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	event = Net.getEvent("BackpackEvent")

	Players.PlayerAdded:Connect(function(player)
		pack(player)
		markDirty(player)
	end)
	for _, player in Players:GetPlayers() do
		pack(player)
		markDirty(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		packs[player] = nil
		dirty[player] = nil
	end)

	--[[
		Every pack is also re-sent now and then. A client that was still loading
		when its first `set` went out would otherwise show an empty pack until
		something changed; ten seconds of staleness at worst is cheaper than a
		request remote.
	]]
	task.spawn(function()
		while true do
			task.wait(RESYNC_SECONDS)
			for player in packs do
				dirty[player] = true
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SYNC_SECONDS)
			for player in dirty do
				dirty[player] = nil
				if player.Parent and event then
					event:FireClient(player, snapshot(player))
				end
			end
		end
	end)

	log:info("ready")
end

return BackpackService
