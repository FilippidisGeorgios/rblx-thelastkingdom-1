--!strict
--[[
	PlayerId.spec
	The Company number: made from the user id and the same every time, decoded back to the user id,
	and refused when mistyped (a wrong character, a wrong prefix, a bad check).

	Location: TestService.Tests.PlayerId.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerId = require(ServerScriptService.Server.Domain.PlayerId)

local ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

return function(t: any)
	t.test("a number has the shape TLK-XXXX-XXXX-C and is the same every time", function()
		local code = PlayerId.forUser(1) :: string
		assert(code:match("^TLK%-%w%w%w%w%-%w%w%w%w%-%w$") ~= nil, "the shape: " .. code)
		assert(code:sub(1, 13) == "TLK-0000-0001", "user 1 is 0000-0001: " .. code)
		assert(PlayerId.forUser(1) == code, "the same every time")
	end)

	t.test("it decodes back to the user id, for small, ordinary and very large ids", function()
		for _, id in { 1, 31, 32, 1024, 2062889722, 9876543210, 1234567890123 } do
			local code = PlayerId.forUser(id) :: string
			assert(PlayerId.decode(code) == id, "round trip " .. id .. " via " .. code)
		end
	end)

	t.test("different users never share a number", function()
		local seen: { [string]: number } = {}
		for id = 1, 3000 do
			local code = PlayerId.forUser(id) :: string
			assert(seen[code] == nil, "duplicate " .. code)
			seen[code] = id
		end
	end)

	t.test("it is forgiving of how it is typed: case, spaces, no dashes", function()
		local id = 2062889722
		local code = PlayerId.forUser(id) :: string
		assert(PlayerId.decode(code:lower()) == id, "lower case")
		assert(PlayerId.decode((code:gsub("%-", " "))) == id, "spaces for dashes")
		assert(PlayerId.decode((code:gsub("%-", ""))) == id, "no dashes")
	end)

	t.test("O is read as 0 and I or L as 1, but only in the number: the prefix keeps its L", function()
		local code = PlayerId.forUser(32) :: string -- 0000-0010: has both a 0 and a 1
		local number = code:sub(5)
		local typo = "TLK-" .. number:gsub("0", "O"):gsub("1", "I")
		assert(PlayerId.decode(typo) == 32, "O for 0, I for 1: " .. typo)
		assert(PlayerId.normalise("tlk-oooo-ooo1") == "TLK00000001", "normalised: " .. PlayerId.normalise("tlk-oooo-ooo1"))
	end)

	t.test("a mistyped number is refused, not read as somebody else", function()
		local id = 2062889722
		local code = PlayerId.forUser(id) :: string
		-- change any one character of the number or the check: every single change is caught
		for i = 5, #code do
			local c = code:sub(i, i)
			if c ~= "-" then
				local at = ALPHABET:find(c, 1, true) :: number
				local other = ALPHABET:sub(at % #ALPHABET + 1, at % #ALPHABET + 1)
				local changed = code:sub(1, i - 1) .. other .. code:sub(i + 1)
				assert(PlayerId.decode(changed) ~= id, "a changed character at " .. i .. " was accepted: " .. changed)
			end
		end
		assert(PlayerId.decode("XYZ-0000-0001-0") == nil, "the wrong prefix")
		assert(PlayerId.decode("TLK-0000") == nil, "too short")
		assert(PlayerId.decode("TLK-0000-000U-0") == nil, "a letter that is not in the alphabet")
		assert(PlayerId.decode("") == nil and not PlayerId.isValid("hello"), "nonsense")
	end)

	t.test("it will not make a number for an id that is not a user", function()
		assert(PlayerId.forUser(0) == nil, "0")
		assert(PlayerId.forUser(-5) == nil, "negative")
		assert(PlayerId.forUser(1.5) == nil, "a fraction")
		assert(PlayerId.forUser(0 / 0) == nil, "nan")
	end)
end
