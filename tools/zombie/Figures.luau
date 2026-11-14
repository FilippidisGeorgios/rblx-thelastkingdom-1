--!nonstrict
--[[
	zombie/Figures — the eight categories of the dead, made fresh from the masters in ServerStorage.Assets.Undead.

	  Figures.CATEGORIES   { { id, label, master, crawler? } } in the order they stand in a photograph
	  Figures.make(id)     a clone of that master (a crawler is laid down by the game's own CrawlerBody), unparented

	The eight were chosen from what the game has (docs/systems/Bestiary.md): the floor-dragger, the plain standing dead, the fast
	one, the spear-bearer, the hard one, the three big ones (the King, the Doctor of the catacombs, the Huntsman of the wood).
	The Gravedigger, the Archer, the Sentinel and the Burned follow the chosen look afterwards: it is the same recipe.
]]

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Figures = {}

Figures.CATEGORIES = {
	{ id = "crawler", label = "Crawler", master = "undead_shambler_scullion", crawler = true },
	{ id = "shambler", label = "Shambler", master = "undead_shambler" },
	{ id = "runner", label = "Runner", master = "undead_runner" },
	{ id = "spearman", label = "Spearman", master = "undead_spearman" },
	{ id = "knight", label = "Hollow Knight", master = "undead_knight" },
	{ id = "king", label = "The King", master = "the_king" },
	{ id = "doctor", label = "The Doctor", master = "plague_doctor" },
	{ id = "huntsman", label = "The Huntsman", master = "the_huntsman" },
}

local function crawlerModule()
	local d = ServerScriptService:FindFirstChild("Server") and ServerScriptService.Server:FindFirstChild("Domain")
	local m = d and d:FindFirstChild("CrawlerBody")
	assert(m, "CrawlerBody is not in the place: sync the scripts first")
	return require(m:Clone())
end

function Figures.find(id: string)
	for _, c in Figures.CATEGORIES do
		if c.id == id then
			return c
		end
	end
	error("no category " .. tostring(id))
end

function Figures.make(id: string): Model
	local c = Figures.find(id)
	local master = ServerStorage.Assets.Undead:FindFirstChild(c.master)
	assert(master, "no master " .. c.master)
	local m = master:Clone()
	m.Name = id
	m:SetAttribute("Category", id)
	if c.crawler then
		crawlerModule().make(m)
	end
	return m
end

return Figures
