--!strict
--[[
	HubInventoryService
	What the INVENTORY tab on the left of the screen shows in the Kingdom Hub: the purse, the stash the runs
	brought home (with a picture of each thing), the charm that will be worn, and the PRIZES OF THE ROAD waiting to
	be collected. It speaks the same `BackpackEvent` "set" message the pack uses in the castle, so one panel
	(UI/BackpackHud) draws both; the Hub's has `hub = true` and a `prizes` block.

	  asking     the client asks (`RequestInventory`) each time the panel opens, and the server also sends it once
	             the profile has loaded and after every claim
	  claiming   `RequestClaimPrize(level)`: Domain/Prizes decides whether the prize may be taken (the level is
	             reached, the prize exists, it was not taken before); gold goes to the purse and items to the stash,
	             the profile is saved at once, and the panel is sent again. A claim moves nothing but what that
	             level's prize says.

	What the prizes ARE is not decided (`Experience.LevelRewards` is empty), so today the panel only says the road's
	prizes are being forged and nothing is ever waiting; the whole claim path is built and tested for the day it is.

	Place: Kingdom Hub ONLY (Server/Hub). Phase: Profiles.

	Location: ServerScriptService.Server.Hub.HubInventoryService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Prizes = require(Server.Domain.Prizes)
local DataService = require(Server.Services.DataService)
local SaveService = require(Server.Services.SaveService)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local HubInventoryService = {}

HubInventoryService.Name = "HubInventoryService"

local log = Logger.new("HubInventoryService")

local ASK_GAP = 0.2

local backpackEvent: RemoteEvent
local lastAsk: { [Player]: number } = {}

local function nameOf(items: any, id: string): string
	local def = items[id]
	return if def and def.DisplayName then def.DisplayName else id
end

-- One prize as the panel draws it: what it gives, in words and in things.
local function prizeRow(items: any, waiting: Prizes.Waiting): any
	local things: { any } = {}
	if waiting.reward.Items then
		for id, count in waiting.reward.Items do
			table.insert(things, { id = id, name = nameOf(items, id), count = count })
		end
		table.sort(things, function(a, b)
			return a.name < b.name
		end)
	end
	return {
		level = waiting.level,
		milestone = waiting.milestone,
		gold = waiting.reward.Gold or 0,
		title = waiting.reward.Title,
		items = things,
	}
end

local function build(player: Player): any?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local items = Config.get("Items")
	local exp = Config.get("Experience")

	local stacks: { [string]: number } = {}
	for id, count in profile.stash do
		if count > 0 and items[id] then
			stacks[id] = count
		end
	end

	local waiting: { any } = {}
	for _, w in Prizes.waiting(profile, exp.LevelRewards, exp.Milestones) do
		table.insert(waiting, prizeRow(items, w))
	end

	-- the next stop on the road, for "next prize at level N"
	local nextStop = (math.floor((profile.level or 1) / exp.Milestones.RewardEvery) + 1) * exp.Milestones.RewardEvery

	player:SetAttribute("PrizesWaiting", #waiting)
	return {
		kind = "set",
		hub = true,
		gold = profile.currency or 0,
		stacks = stacks,
		charm = profile.loadout and profile.loadout.charm or nil,
		prizes = {
			waiting = waiting,
			defined = next(exp.LevelRewards) ~= nil,
			nextLevel = if nextStop <= exp.MaxLevel then nextStop else nil,
		},
	}
end

local function push(player: Player)
	local payload = build(player)
	if payload then
		backpackEvent:FireClient(player, payload)
	end
end

local function onAsk(player: Player)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < ASK_GAP then
		return
	end
	lastAsk[player] = now
	push(player)
end

local function onClaim(player: Player, level: any)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < ASK_GAP then
		return
	end
	lastAsk[player] = now
	if type(level) ~= "number" or level ~= level or level < 1 or level > 1000 then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end
	local items = Config.get("Items")
	local exp = Config.get("Experience")
	local claim, why = Prizes.claim(profile, math.floor(level), exp.LevelRewards, exp.Milestones, items)
	if not claim then
		log:info(("%s tried to claim level %s: %s"):format(player.Name, tostring(level), tostring(why)))
		push(player)
		return
	end

	-- a prize is worth more than one autosave interval: write it now
	SaveService.save(player)
	log:info(("%s claimed the prize of level %d (%d gold, %s)"):format(player.Name, claim.level, claim.gold, if next(claim.items) then "items" else "no items"))

	-- the little lines in the corner, as when a find is picked up
	if claim.gold > 0 then
		backpackEvent:FireClient(player, { kind = "gain", gold = true, count = claim.gold })
	end
	for id, count in claim.items do
		local def = items[id]
		backpackEvent:FireClient(player, {
			kind = "gain",
			item = id,
			name = nameOf(items, id),
			count = count,
			rank = def and def.Rank or "Worn",
		})
	end
	push(player)
end

function HubInventoryService.Init() end

function HubInventoryService.Start()
	backpackEvent = Net.getEvent("BackpackEvent")
	Net.getEvent("RequestInventory").OnServerEvent:Connect(onAsk)
	Net.getEvent("RequestClaimPrize").OnServerEvent:Connect(onClaim)

	-- once the profile has loaded, the panel (and its badge) are ready before it is ever opened
	local function ready(player: Player)
		task.spawn(function()
			local waited = 0
			while not DataService.get(player) and waited < 15 and player.Parent do
				task.wait(0.25)
				waited += 0.25
			end
			if player.Parent and DataService.get(player) then
				push(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(ready)
	for _, player in Players:GetPlayers() do
		ready(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
	log:info("ready")
end

return HubInventoryService
