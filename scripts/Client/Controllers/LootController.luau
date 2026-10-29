--!strict
--[[
	LootController
	The client half of the spoils: hides what is not yours, and feeds the
	server's backpack messages to the HUD.

	THE PICKUPS ARE ONE PART PER OWNER, SEEN BY EVERYONE'S CLIENT
	The server owns every drop (it is the one that moves and collects them) and
	stamps it with its owner's UserId. Replication would show all of them to all
	of us, so each client simply refuses to draw the ones that are not its own:
	fully transparent, its glint switched off. Nothing about it is secret, and
	nothing needs to be; it is a PvE game and the point is only that nobody sees
	a find they cannot take.

	Place: client (boots in both places; active only where the server sends).
	Phase: Spoils.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local BackpackHud = require(script.Parent.Parent.UI.BackpackHud)
local CharmCue = require(script.Parent.Parent.UI.CharmCue)

local LootController = {}

LootController.Name = "LootController"

local TAG = "TLK_Pickup"

local hud: BackpackHud.Handle? = nil

local function ensureHud(): BackpackHud.Handle
	local existing = hud
	if existing then
		return existing
	end
	local created = BackpackHud.create()
	hud = created
	return created
end

local function hideIfForeign(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if instance:GetAttribute("Owner") == Players.LocalPlayer.UserId then
		return
	end
	instance.LocalTransparencyModifier = 1
	for _, child in instance:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		end
	end
	-- Streamed in with its emitter after the part: catch the late one too.
	instance.DescendantAdded:Connect(function(child)
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		end
	end)
end

function LootController.Init() end

function LootController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		hideIfForeign(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(hideIfForeign)

	local ranks = Config.get("Loot").Ranks
	local items = Config.get("Items")

	Net.getEvent("BackpackEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local kind = payload.kind
		if kind == "set" then
			ensureHud().set(payload, items, ranks)
		elseif kind == "gain" then
			ensureHud().gain(payload, ranks)
		elseif kind == "full" then
			ensureHud().full()
		end
	end)

	-- a worn charm did something: the veil held
	Net.getEvent("CharmEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.kind == "cue" and typeof(payload.charm) == "string" then
			CharmCue.show({
				charm = payload.charm,
				title = tostring(payload.title or ""),
				line = if typeof(payload.line) == "string" then payload.line else nil,
			})
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B and hud then
			hud.toggle()
		end
	end)
end

return LootController
