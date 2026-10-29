--!strict
--[[
	ProfileSchema (domain)
	The SHAPE of a persistent player profile plus a versioned default and migration.
	This is the "Save Architecture" data contract. The `version` field enables safe
	migrations as the schema evolves.

	v2 adds progression fields (`xp`, `level`) owned by the Progression/Reward systems.
	v3 adds the `stash`: counts of what a run brought home (materials, relics, shards,
	pages), banked by RunSettlement; the Hub's Tithe, Reliquary and Altar spend it.
	v4 adds what the Chapel does with it: the `loadout` (what the next run starts with: a
	`kit` of things to carry in, an equipped `charm`, a `blessing`) and the Falling Star's
	`altar` (shards offered so far). See Domain/Chapel.
	v5 adds the `account`: who this profile belongs to (the Company number from Domain/PlayerId, the
	Roblox user id, the name and display name last seen, when it began and when it was last loaded), for the
	Muster Roll and the admin panel to come. `stamp` writes it on every load.

	Location: ServerScriptService.Server.Domain.ProfileSchema
]]

local PlayerId = require(script.Parent.PlayerId)

export type Loadout = { kit: { [string]: number }, charm: string?, blessing: string? }

export type Account = {
	id: string?,
	userId: number?,
	name: string?,
	displayName: string?,
	since: number?,
	lastSeen: number?,
}

export type Profile = {
	version: number,
	account: Account,
	currency: number,
	xp: number,
	level: number,
	inventory: { [string]: any },
	stash: { [string]: number },
	loadout: Loadout,
	altar: { offered: number },
	upgrades: { [string]: any },
	stats: { [string]: any },
	unlockedLore: { [string]: boolean },
	achievements: { [string]: boolean },
}

local ProfileSchema = {}

ProfileSchema.VERSION = 5

-- Returns a fresh default profile for a brand-new player.
function ProfileSchema.default(): Profile
	return {
		version = ProfileSchema.VERSION,
		account = {},
		currency = 0,
		xp = 0,
		level = 1,
		inventory = {},
		stash = {},
		loadout = { kit = {} },
		altar = { offered = 0 },
		upgrades = {},
		stats = {},
		unlockedLore = {},
		achievements = {},
	}
end

-- Brings an older profile up to VERSION. Idempotent and additive: fills any missing
-- field with its default so a v1 profile becomes a valid v2 profile.
function ProfileSchema.migrate(profile: Profile): Profile
	if (profile.version or 0) < 2 then
		profile.xp = profile.xp or 0
		profile.level = profile.level or 1
	end
	-- Backfill any container that a partial/old save might be missing.
	profile.account = profile.account or {}
	profile.currency = profile.currency or 0
	profile.inventory = profile.inventory or {}
	profile.stash = profile.stash or {}
	profile.loadout = profile.loadout or { kit = {} }
	profile.loadout.kit = profile.loadout.kit or {}
	profile.altar = profile.altar or { offered = 0 }
	profile.altar.offered = profile.altar.offered or 0
	profile.upgrades = profile.upgrades or {}
	profile.stats = profile.stats or {}
	profile.unlockedLore = profile.unlockedLore or {}
	profile.achievements = profile.achievements or {}
	profile.version = ProfileSchema.VERSION
	return profile
end

--[[
	Writes who the profile belongs to. The Company number is given ONCE (the first time) and never changed
	after that, even if the scheme in Domain/PlayerId changes; the names and the last-seen time follow the
	player. `now` is os.time(), passed in so the rule stays pure.
]]
function ProfileSchema.stamp(profile: Profile, who: { userId: number, name: string, displayName: string }, now: number)
	local account = profile.account
	if account.id == nil then
		account.id = PlayerId.forUser(who.userId)
	end
	account.userId = who.userId
	account.name = who.name
	account.displayName = who.displayName
	account.since = account.since or now
	account.lastSeen = now
end

return ProfileSchema
