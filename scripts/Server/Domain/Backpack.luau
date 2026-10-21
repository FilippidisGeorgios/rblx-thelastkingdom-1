--!strict
--[[
	Backpack (domain class)
	What one player carries for the length of one run: a gold purse, stacks of
	materials / consumables / relics, and the quest items they are holding.
	Pure data and rules; BackpackService owns the instances and the networking.

	Three kinds of thing, treated differently on purpose (docs/systems/Spoils.md §7):
	  - gold         a counter, takes no slot
	  - stacks       materials, consumables, relics: one slot per kind, capped
	  - carried      quest items (a torch, a plank load): no slot, never banked

	Capacity is counted in SLOTS (kinds), not units: a pack is full when it holds
	N different things, because "can I pick this up" should be about whether the
	thing is new to you, not about weight.

	Location: ServerScriptService.Server.Domain.Backpack
]]

local Backpack = {}
Backpack.__index = Backpack

export type Backpack = typeof(setmetatable(
	{} :: {
		gold: number,
		stacks: { [string]: number },
		carried: { [string]: number },
		slots: number,
		items: any, -- the item catalog (configs/Items), for stack caps and categories
	},
	Backpack
))

function Backpack.new(items: any, slots: number): Backpack
	return setmetatable({
		gold = 0,
		stacks = {},
		carried = {},
		slots = slots,
		items = items,
	}, Backpack)
end

local function isCarried(self: Backpack, itemId: string): boolean
	local def = self.items[itemId]
	return def ~= nil and def.Category == "QuestItem"
end

function Backpack.slotsUsed(self: Backpack): number
	local n = 0
	for _ in self.stacks do
		n += 1
	end
	return n
end

function Backpack.count(self: Backpack, itemId: string): number
	return (self.stacks[itemId] or 0) + (self.carried[itemId] or 0)
end

-- How many of `itemId` would fit right now.
function Backpack.room(self: Backpack, itemId: string): number
	local def = self.items[itemId]
	if not def then
		return 0
	end
	if isCarried(self, itemId) then
		return if def.Stackable then (def.MaxStack or 99) - (self.carried[itemId] or 0) else (1 - (self.carried[itemId] or 0))
	end
	local cap = if def.Stackable then (def.MaxStack or 99) else 1
	local have = self.stacks[itemId]
	if have == nil then
		if self:slotsUsed() >= self.slots then
			return 0
		end
		return cap
	end
	return math.max(0, cap - have)
end

-- Adds up to `count`. Returns how many were taken (the rest does not fit).
function Backpack.add(self: Backpack, itemId: string, count: number): number
	if count <= 0 then
		return 0
	end
	local take = math.min(count, self:room(itemId))
	if take <= 0 then
		return 0
	end
	local into = if isCarried(self, itemId) then self.carried else self.stacks
	into[itemId] = (into[itemId] or 0) + take
	return take
end

function Backpack.addGold(self: Backpack, amount: number)
	self.gold += math.max(0, amount)
end

-- Removes exactly `count` or nothing. Returns whether it did.
function Backpack.remove(self: Backpack, itemId: string, count: number): boolean
	local from = if isCarried(self, itemId) then self.carried else self.stacks
	local have = from[itemId] or 0
	if count <= 0 or have < count then
		return false
	end
	if have == count then
		from[itemId] = nil
	else
		from[itemId] = have - count
	end
	return true
end

function Backpack.spendGold(self: Backpack, amount: number): boolean
	if amount < 0 or self.gold < amount then
		return false
	end
	self.gold -= amount
	return true
end

-- Drops everything carried (quest items): a new chamber, a death, a run restart.
function Backpack.clearCarried(self: Backpack)
	self.carried = {}
end

--[[
	What survives the end of a run. `banked` is false for a quest item; the
	caller decides the gold fraction. `storyOnly` keeps only what the Story says is
	never lost (a wiped run): shards and pages.
]]
function Backpack.bankable(self: Backpack, storyOnly: boolean?): { [string]: number }
	local out: { [string]: number } = {}
	for itemId, n in self.stacks do
		local def = self.items[itemId]
		local banked = def == nil or def.Banked ~= false
		if banked and (not storyOnly or itemId == "star_shard" or itemId:sub(1, 5) == "page_") then
			out[itemId] = n
		end
	end
	return out
end

function Backpack.reset(self: Backpack)
	self.gold = 0
	self.stacks = {}
	self.carried = {}
end

return Backpack
