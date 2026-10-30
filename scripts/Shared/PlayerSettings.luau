--!strict
--[[
	PlayerSettings (shared, pure)
	What a player has chosen in the Settings panel, kept in `profile.settings` so it follows them to both places.
	Pure: the stored table, a requested change and configs/Graphics in, the checked settings out.

	  graphics   "Low" | "Medium" | "High" | "Ultra"      (absent = never chosen: the default for their device)
	  shadows    true | false                              (absent = whatever the chosen quality starts at)

	The client only ever REQUESTS a change; the server checks it here, so a tampered client can store nothing but
	a quality that exists and a true or a false.

	Location: ReplicatedStorage.Shared.PlayerSettings (shared: the server checks a request with it, the client works out the picture from it)
]]

local PlayerSettings = {}

export type Settings = { graphics: string?, shadows: boolean? }

export type Graphics = {
	Order: { string },
	Default: string,
	PhoneDefault: string,
	Tiers: { [string]: { Shadows: boolean } },
}

local function isQuality(value: any, cfg: Graphics): boolean
	return type(value) == "string" and cfg.Tiers[value] ~= nil
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
	end
	return out
end

--[[
	Applies a request to the settings. Choosing a quality also moves the shadows switch to that quality's own
	start (Low starts with shadows off) UNLESS the request names the shadows as well. Anything invalid is
	ignored. Returns the new settings and whether anything changed.
]]
function PlayerSettings.apply(current: Settings, request: any, cfg: Graphics): (Settings, boolean)
	local next: Settings = { graphics = current.graphics, shadows = current.shadows }
	if type(request) ~= "table" then
		return next, false
	end
	local named = false
	if isQuality(request.graphics, cfg) then
		next.graphics = request.graphics
		named = true
	end
	if type(request.shadows) == "boolean" then
		next.shadows = request.shadows
	elseif named then
		next.shadows = cfg.Tiers[next.graphics :: string].Shadows
	end
	return next, next.graphics ~= current.graphics or next.shadows ~= current.shadows
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
