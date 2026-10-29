--!strict
--[[
	ProfileSchema.spec
	Validates the persistent profile contract: a fresh default is stamped with the
	current version, zeroed currency/xp/level and empty containers; migrate() is
	idempotent for a current profile and upgrades a v1 profile to v2.

	Location: TestService.Tests.ProfileSchema.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)

return function(t: any)
	t.test("a default profile has the current version, zeroed currency/xp/level, empty containers", function()
		local p = ProfileSchema.default()
		assert(p.version == ProfileSchema.VERSION, "default should stamp the current schema version")
		assert(p.currency == 0, "default currency should be 0")
		assert(p.xp == 0, "default xp should be 0")
		assert(p.level == 1, "default level should be 1")
		for _, field in { "inventory", "upgrades", "stats", "unlockedLore", "achievements" } do
			local container = (p :: any)[field]
			assert(type(container) == "table", field .. " should be a table")
			assert(next(container) == nil, field .. " should start empty")
		end
	end)

	t.test("migrate is idempotent for a current profile", function()
		local p = ProfileSchema.default()
		local migrated = ProfileSchema.migrate(p)
		assert(migrated == p, "migrate returns the same profile")
		assert(migrated.version == ProfileSchema.VERSION, "stays at the current version")
	end)

	t.test("migrate upgrades a v1 profile (no xp/level) to v2, preserving data", function()
		local old: any = {
			version = 1,
			currency = 42,
			inventory = {},
			upgrades = {},
			stats = {},
			unlockedLore = {},
			achievements = {},
		}
		local migrated = ProfileSchema.migrate(old)
		assert(migrated.version == ProfileSchema.VERSION, "bumped to the current version")
		assert(migrated.xp == 0, "xp backfilled to 0")
		assert(migrated.level == 1, "level backfilled to 1")
		assert(migrated.currency == 42, "existing data preserved")
	end)

	t.test("a v4 profile migrates to v5 with an empty account, keeping everything it had", function()
		local old: any = ProfileSchema.default()
		old.version = 4
		old.account = nil
		old.currency = 77
		old.stash = { bone_dust = 3 }
		local migrated = ProfileSchema.migrate(old)
		assert(migrated.version == 5 and ProfileSchema.VERSION == 5, "the schema is at 5")
		assert(type(migrated.account) == "table" and next(migrated.account) == nil, "an empty account")
		assert(migrated.currency == 77 and migrated.stash.bone_dust == 3, "nothing else touched")
	end)

	t.test("stamp gives the Company number once, never changes it, and follows the names", function()
		local p = ProfileSchema.default()
		ProfileSchema.stamp(p, { userId = 2062889722, name = "Cookies11f", displayName = "Cookie" }, 1000)
		local id = p.account.id
		assert(id ~= nil and id:sub(1, 4) == "TLK-", "a Company number: " .. tostring(id))
		assert(p.account.userId == 2062889722 and p.account.name == "Cookies11f", "the account")
		assert(p.account.since == 1000 and p.account.lastSeen == 1000, "first seen")

		ProfileSchema.stamp(p, { userId = 2062889722, name = "Cookies11f", displayName = "New Nick" }, 5000)
		assert(p.account.id == id, "the number is never changed")
		assert(p.account.displayName == "New Nick", "a new display name is followed")
		assert(p.account.since == 1000 and p.account.lastSeen == 5000, "since stays, last seen moves")
	end)

	t.test("a Company number stamped long ago is kept even if it differs from what the scheme gives now", function()
		local p = ProfileSchema.default()
		p.account.id = "TLK-OLD0-0000-0"
		ProfileSchema.stamp(p, { userId = 5, name = "A", displayName = "A" }, 1)
		assert(p.account.id == "TLK-OLD0-0000-0", "the first number given stays")
	end)
end
