--!strict
--[[
	PlayerSettings (shared, pure)
	What a player has chosen in the Settings panel, kept in `profile.settings` so it follows them to both places.
	Pure: the stored table, a requested change and configs/Graphics in, the checked settings out.

	  graphics    "Low" | "Medium" | "High" | "Ultra"   (absent = never chosen: the default for their device)
	  shadows     true | false                           (absent = whatever the chosen quality starts at)
	  fov         a number of degrees                    (absent = configs/View.Fov.Default)
	  headBob     true | false                           (absent = on: the picture steps with the feet)
	  crouchHold  true | false                           (absent = off: Ctrl is pressed once to duck and once to stand)

	(The old `mouseLock` is gone: since 2026-11-10 the game is first person and the mouse is always held; an old save's
	value is dropped by `clean`.)

	THE CEILING (the developer's rule, 2026-11-10). Inside a run the picture quality may only go DOWN: a player who lowers
	it in the castle cannot raise it again until they are back in the lobby (raising it in the middle of a fight was a
	way to freeze). The server passes the ceiling in `limits`; a request above it is ignored. In the lobby there is none.

	The client only ever REQUESTS a change; the server checks it here, so a tampered client can store nothing but a
	quality that exists, a true or a false, and a field of view inside the allowed range.

	Location: ReplicatedStorage.Shared.PlayerSettings (shared: the server checks a request with it, the client works out the picture from it)
]]

local PlayerSettings = {}

export type Settings = { graphics: string?, shadows: boolean?, fov: number?, headBob: boolean?, crouchHold: boolean? }

export type Graphics = {
	Order: { string },
	Default: string,
	PhoneDefault: string,
	Tiers: { [string]: { Shadows: boolean } },
}

-- ceiling: the best quality that may be asked for (nil = any). fovMin / fovMax: the allowed field of view.
export type Limits = { ceiling: string?, fovMin: number?, fovMax: number? }

-- The widest range a field of view is ever kept in, whatever the config says (a hand-edited save cannot store 179).
local FOV_FLOOR, FOV_ROOF = 40, 120

local function isQuality(value: any, cfg: Graphics): boolean
	return type(value) == "string" and cfg.Tiers[value] ~= nil
end

local function isFov(value: any): boolean
	return type(value) == "number" and value == value and value >= FOV_FLOOR and value <= FOV_ROOF
end

-- Where a quality stands in the order, from 1 (the cheapest). 0 for one that does not exist.
function PlayerSettings.rank(cfg: Graphics, quality: string?): number
	for i, id in cfg.Order do
		if id == quality then
			return i
		end
	end
	return 0
end

-- May `quality` be chosen under `ceiling`? (No ceiling: always.)
function PlayerSettings.allowed(cfg: Graphics, quality: string, ceiling: string?): boolean
	if not isQuality(quality, cfg) then
		return false
	end
	if ceiling == nil or not isQuality(ceiling, cfg) then
		return true
	end
	return PlayerSettings.rank(cfg, quality) <= PlayerSettings.rank(cfg, ceiling)
end

-- Keeps only what is valid from a stored table (an old save, a hand-edited one).
function PlayerSettings.clean(stored: any, cfg: Graphics): Settings
	local out: Settings = {}
	if type(stored) == "table" then
		if isQuality(stored.graphics, cfg) then
			out.graphics = stored.graphics
		end
		if type(stored.shadows) == "boolean" then
			out.shadows = stored.shadows
		end
		if isFov(stored.fov) then
			out.fov = math.floor(stored.fov + 0.5)
		end
		if type(stored.headBob) == "boolean" then
			out.headBob = stored.headBob
		end
		if type(stored.crouchHold) == "boolean" then
			out.crouchHold = stored.crouchHold
		end
	end
	return out
end

--[[
	Applies a request to the settings. Choosing a quality also moves the shadows switch to that quality's own
	start (Low starts with shadows off) UNLESS the request names the shadows as well. Anything invalid is ignored,
	and so is a quality above the ceiling in `limits`. Returns the new settings and whether anything changed.
]]
function PlayerSettings.apply(current: Settings, request: any, cfg: Graphics, limits: Limits?): (Settings, boolean)
	local next: Settings = {
		graphics = current.graphics,
		shadows = current.shadows,
		fov = current.fov,
		headBob = current.headBob,
		crouchHold = current.crouchHold,
	}
	if type(request) ~= "table" then
		return next, false
	end
	local named = false
	if isQuality(request.graphics, cfg) and PlayerSettings.allowed(cfg, request.graphics, limits and limits.ceiling) then
		next.graphics = request.graphics
		named = true
	end
	if type(request.shadows) == "boolean" then
		next.shadows = request.shadows
	elseif named then
		next.shadows = cfg.Tiers[next.graphics :: string].Shadows
	end
	if isFov(request.fov) then
		local lo = math.max(FOV_FLOOR, (limits and limits.fovMin) or FOV_FLOOR)
		local hi = math.min(FOV_ROOF, (limits and limits.fovMax) or FOV_ROOF)
		next.fov = math.clamp(math.floor(request.fov + 0.5), lo, hi)
	end
	if type(request.headBob) == "boolean" then
		next.headBob = request.headBob
	end
	if type(request.crouchHold) == "boolean" then
		next.crouchHold = request.crouchHold
	end
	local changed = next.graphics ~= current.graphics
		or next.shadows ~= current.shadows
		or next.fov ~= current.fov
		or next.headBob ~= current.headBob
		or next.crouchHold ~= current.crouchHold
	return next, changed
end

--[[
	The figures the picture is drawn from: the quality (the stored one, or the default for the device) and the
	shadows switch (the stored one, or the quality's start).
]]
function PlayerSettings.effective(settings: Settings, cfg: Graphics, phone: boolean): (string, boolean)
	local quality = settings.graphics
	if not quality or cfg.Tiers[quality] == nil then
		quality = if phone then cfg.PhoneDefault else cfg.Default
	end
	local shadows = settings.shadows
	if shadows == nil then
		shadows = cfg.Tiers[quality].Shadows
	end
	return quality, shadows
end

return PlayerSettings
