--!strict
--[[
	PlayerId (domain)
	The Company number of a player: a short code made from their Roblox user id, the same every time,
	for the admin panel to search by and for a player to read out. `TLK-0001-AB3D-K`.

	  - Made, not stored-and-counted: no global counter, no race between servers, no DataStore call. The
	    same user always gets the same code, in both places, and the code decodes back to the user id.
	  - Written in Crockford's base 32 (no I, L, O or U, so nothing is mistaken for a 1, a 0 or a rude
	    word) with one check character, so a mistyped code is refused instead of finding somebody else.
	  - It is not a secret and gives nothing away: a Roblox user id is public.

	The profile keeps the code it was first given (ProfileSchema.stamp) so it never changes later, even if
	this scheme does; `decode` is what an admin panel uses to go from a typed code to the account.

	Location: ServerScriptService.Server.Domain.PlayerId
]]

local PlayerId = {}

local PREFIX = "TLK"
local ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
local MIN_WIDTH = 8 -- 32^8 is over a trillion: far above any user id today
local GROUP = 4

local VALUE: { [string]: number } = {}
for i = 1, #ALPHABET do
	VALUE[ALPHABET:sub(i, i)] = i - 1
end

-- Odd weights, so that changing any single character always changes the check.
local function checkOf(chars: string): string
	local sum = 0
	for i = 1, #chars do
		sum += VALUE[chars:sub(i, i)] * (2 * i + 1)
	end
	local c = sum % 32
	return ALPHABET:sub(c + 1, c + 1)
end

local function toBase32(n: number): string
	local out = ""
	local rest = n
	repeat
		local digit = rest % 32
		out = ALPHABET:sub(digit + 1, digit + 1) .. out
		rest = (rest - digit) / 32
	until rest == 0
	if #out < MIN_WIDTH then
		out = string.rep("0", MIN_WIDTH - #out) .. out
	end
	return out
end

-- `TLK-0000-0001-X` for user id 1. Nil for an id that is not a whole number of at least 1.
function PlayerId.forUser(userId: number): string?
	if type(userId) ~= "number" or userId ~= math.floor(userId) or userId < 1 or userId >= 2 ^ 50 then
		return nil
	end
	local body = toBase32(userId)
	local groups: { string } = {}
	local i = 1
	while i <= #body do
		table.insert(groups, body:sub(i, i + GROUP - 1))
		i += GROUP
	end
	return PREFIX .. "-" .. table.concat(groups, "-") .. "-" .. checkOf(body)
end

-- What a person types: any case, spaces or no dashes, O for 0, I or L for 1.
function PlayerId.normalise(text: string): string
	local s = text:upper():gsub("[%s%-_]", "")
	local hasPrefix = s:sub(1, #PREFIX) == PREFIX
	local rest = if hasPrefix then s:sub(#PREFIX + 1) else s
	-- the confusable letters are mapped in the number only: the prefix has an L in it
	rest = rest:gsub("O", "0"):gsub("[IL]", "1")
	return (if hasPrefix then PREFIX else "") .. rest
end

-- The user id behind a code, or nil if it is not a valid code (wrong prefix, a stray character, a bad check).
function PlayerId.decode(code: string): number?
	local s = PlayerId.normalise(code)
	if s:sub(1, #PREFIX) ~= PREFIX then
		return nil
	end
	local rest = s:sub(#PREFIX + 1)
	if #rest < MIN_WIDTH + 1 then
		return nil
	end
	local body = rest:sub(1, #rest - 1)
	local check = rest:sub(#rest)
	local n = 0
	for i = 1, #body do
		local v = VALUE[body:sub(i, i)]
		if v == nil then
			return nil
		end
		n = n * 32 + v
	end
	if VALUE[check] == nil or checkOf(body) ~= check then
		return nil
	end
	if n < 1 then
		return nil
	end
	return n
end

function PlayerId.isValid(code: string): boolean
	return PlayerId.decode(code) ~= nil
end

return PlayerId
