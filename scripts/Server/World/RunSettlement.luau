--!strict
--[[
	RunSettlement
	The end of a run, settled (docs/systems/Spoils.md §7): what each player carried
	out of the castle is banked into their profile, the pack is emptied, the profile
	is saved, a card closes the screen with what they brought home, and a few seconds
	later the party is sent back to the Hub.

	  WON    (Trial/Exit, when the whole party stands in the light at the top of the
	         keep) every banked thing in the pack goes to the profile: gold becomes
	         currency, the rest the stash; the prisoner of the Rows, if he is still
	         alive, pays the whole team 5% of their gold on top.
	  WIPED  (DeathService.onRunOver, nobody left standing) the castle keeps three
	         quarters of the gold; the star shards and the pages come home all the
	         same; no bonus.

	It happens ONCE per run: a run is a server's life (the party arrives in a fresh
	Forgotten Lands and leaves it). Only a Play Again, which starts a new run in the same
	server, re-arms it (and cancels the way home still pending from the last one).

	The rules are the pure `Domain/Settlement` (spec-tested); this owns the players,
	the saving, the card (`EndingEvent`, one payload per player: it is their own
	ledger) and the way home.

	Place: Forgotten Lands ONLY (Server/World). Phase: Spoils.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Settlement = require(Server.Domain.Settlement)
local RunXp = require(Server.Domain.RunXp)
local PlayerStats = require(Server.Domain.PlayerStats)
local PlayerCard = require(Server.Domain.PlayerCard)
local DataService = require(Server.Services.DataService)
local GameService = require(Server.Services.GameService)
local SaveService = require(Server.Services.SaveService)
local TeleportService = require(Server.Services.TeleportService)
local RewardService = require(Server.Services.RewardService)
local BackpackService = require(script.Parent.BackpackService)
local RunStatsService = require(script.Parent.RunStatsService)
local DeathService = require(script.Parent.DeathService)
local RunModService = require(script.Parent.RunModService)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RunSettlement = {}

RunSettlement.Name = "RunSettlement"

local log = Logger.new("RunSettlement")

-- Seconds the party is left to read the end of the card, before the way home.
local READ_AFTER = 6

local settled = false
local runNumber = 0

local function ledgerLines(ledger: Settlement.Ledger, prisonerAlive: boolean): { string }
	local items = Config.get("Items")
	local lines: { string } = {}
	if ledger.outcome == "won" then
		local text = ("Gold carried out: %d"):format(ledger.gold)
		if ledger.bonusGold > 0 then
			text ..= (" (+%d: the prisoner lived)"):format(ledger.bonusGold)
		end
		table.insert(lines, text)
	else
		table.insert(lines, ("Gold kept: %d of %d"):format(ledger.gold, ledger.gold + ledger.lostGold))
	end
	if ledger.xp and ledger.xp > 0 then
		local text = ("Experience: +%d"):format(ledger.xp)
		if (ledger.levelsGained or 0) > 0 and ledger.level then
			local titles = Config.get("Profile").Titles
			text ..= ("  (level %d, %s)"):format(ledger.level, PlayerCard.titleFor(ledger.level, titles))
		end
		table.insert(lines, text)
	end
	local names: { string } = {}
	for itemId in ledger.items do
		table.insert(names, itemId)
	end
	table.sort(names)
	for _, itemId in names do
		local def = items[itemId]
		table.insert(lines, ("%s x%d"):format(if def then def.DisplayName else itemId, ledger.items[itemId]))
	end
	return lines
end

-- The card for one player.
local function cardFor(outcome: string, ledger: Settlement.Ledger, prisonerAlive: boolean): any
	if outcome == "won" then
		return {
			title = "The Last Kingdom",
			subtitle = "Book One: the Return",
			lines = {
				"The King kneels, and the bells are quiet.",
				"The way up is open, and you went up it together.",
				"Asterfall remembers.",
				"Nobody has written down what sent the Company north.",
			},
			ledgerTitle = "You carry home",
			ledger = ledgerLines(ledger, prisonerAlive),
			footer = "To be continued",
		}
	end
	return {
		title = "The Run Is Over",
		subtitle = "The castle keeps what it keeps",
		lines = {
			"The party is down, and nobody is left to lift it.",
			"The castle keeps three quarters of your gold. The star and every page you found come home with you.",
		},
		ledgerTitle = "You carry home",
		ledger = ledgerLines(ledger, prisonerAlive),
		footer = "The train is waiting",
	}
end

--[[
	How long the card plays on the client (UI/EndingUi's timeline: the title, each line held for
	its length, the ledger, the footer). The party is sent home only after it has finished.
]]
local function cardSeconds(card: any): number
	local t = 3 + (if card.subtitle then 1.2 else 0) + 4 + 2
	for _, text in card.lines do
		t += math.max(3.6, #text / 14) + 1.6
	end
	if #card.ledger > 0 then
		t += math.clamp(#card.ledger * 0.9, 5, 14) + 1.4
	end
	return t + 2.6
end

--[[
	Settles the run. `players` defaults to everyone in the server. Returns the ledger of
	each player (for a test), or nil when it was already settled.
]]
function RunSettlement.finish(outcome: Settlement.Outcome, players: { Player }?): { [Player]: Settlement.Ledger }?
	if settled then
		return nil
	end
	settled = true

	local group = players or Players:GetPlayers()
	local loot = Config.get("Loot").Rules
	local rules: Settlement.Rules = { keepFraction = loot.WipeKeepsGold, bonus = loot.PrisonerGoldBonus }
	local prisonerAlive = RunModService.getFlag("prisonerAlive") == true
	local event = Net.getEvent("EndingEvent")
	local out: { [Player]: Settlement.Ledger } = {}
	local cardTime = 0

	for _, player in group do
		if player.Parent then
			local ledger = Settlement.compute(BackpackService.get(player), outcome, rules, prisonerAlive)
			local profile = DataService.get(player)
			if profile then
				Settlement.apply(profile :: any, ledger)
				-- what the run was worth in experience, and what they did in it (World/RunStatsService)
				local snap = RunStatsService.snapshot(player)
				local xp = RunXp.compute(
					{ kills = snap.kills, cleared = snap.cleared, deeds = snap.deeds },
					outcome,
					Config.get("Experience").Sources
				)
				local paid = RewardService.applyTo(player, { xp = xp.total })
				ledger.xp = xp.total
				ledger.level = (profile :: any).level
				ledger.levelsGained = if paid then paid.levelsGained else 0
				PlayerStats.addRun((profile :: any).stats, snap, outcome, ledger.gold + ledger.bonusGold, xp.total)
				SaveService.save(player)
			else
				log:warn(player.Name .. " has no profile: nothing was banked")
			end
			BackpackService.reset(player)
			out[player] = ledger
			local card = cardFor(outcome, ledger, prisonerAlive)
			cardTime = math.max(cardTime, cardSeconds(card))
			event:FireClient(player, card)
			log:info(("%s: %s, %d gold + %d bonus, %d kinds of thing"):format(player.Name, outcome, ledger.gold, ledger.bonusGold, (function()
				local n = 0
				for _ in ledger.items do
					n += 1
				end
				return n
			end)()))
		end
	end

	RunModService.setFlag("runOutcome", outcome)
	local thisRun = runNumber
	task.delay(cardTime + READ_AFTER, function()
		if thisRun == runNumber then -- a Play Again in between cancels the way home
			pcall(TeleportService.returnToHub, group, { outcome = outcome })
		end
	end)
	return out
end

function RunSettlement.isSettled(): boolean
	return settled
end

function RunSettlement.Init() end

function RunSettlement.Start()
	if GameService.getPlaceRole() ~= Constants.PlaceRole.World then
		return
	end
	DeathService.onRunOver(function(players: { Player })
		RunSettlement.finish("wiped", players)
	end)
	-- a run begins (the first, or a Play Again): the last one's settlement is behind us
	DeathService.onRunBegin(function()
		settled = false
		runNumber += 1
	end)
	log:info("ready")
end

return RunSettlement
