--[[
	ApplyLook — run in the Studio Command Bar of EITHER place, in EDIT MODE.
	Select the whole file (Ctrl+A), copy, paste, Enter.

	Bakes one preset from `configs/Look.luau` into the open place: Lighting, the
	Atmosphere / Sky / post-processing effects under it, the terrain's Clouds, and the
	colour each terrain material is painted. Set PRESET below.

	  "Baseline"             the Hub as it was before the art pass. This is the undo.
	  "DarkRealistic"        Look A.
	  "StylizedDarkFantasy"  Look B.
	  "ForgottenBaseline"    the Forgotten Lands as they were. Their undo.
	  "ForgottenDusk"        the Forgotten Lands' look.

	It reads `ReplicatedStorage.Config.Look`, which exists only once Rojo has synced
	`configs/Look.luau` into the place (`rojo serve`, then Connect). Without it the tool
	says so and stops; it never guesses.

	WHAT IT TOUCHES: Lighting and its children, Workspace.Terrain's Clouds, and the
	terrain MATERIAL COLOURS. No part, model, script or terrain voxel is ever modified.
	Every run is bracketed by two undo waypoints, so Ctrl+Z in Studio steps it back.

	`Lighting.Technology` is deliberately not handled — Roblox does not let a script
	touch it. Set it by hand in the Properties panel (both places are on Future).

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local PRESET = "Baseline"

--==========================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Terrain = workspace.Terrain

local configRoot = ReplicatedStorage:FindFirstChild("Config")
local lookModule = configRoot and configRoot:FindFirstChild("Look")
if not (lookModule and lookModule:IsA("ModuleScript")) then
	warn("[Look] ReplicatedStorage.Config.Look is missing. Run `rojo serve`, Connect, and try again.")
	return
end

-- A clone has never been required, so this always reads the CURRENT source rather
-- than whatever this Studio session cached the first time.
local Look = require(lookModule:Clone())
local preset = Look.Presets[PRESET]
if not preset then
	local names = {}
	for name in pairs(Look.Presets) do
		table.insert(names, name)
	end
	table.sort(names)
	warn(('[Look] no preset called "%s". Available: %s'):format(PRESET, table.concat(names, ", ")))
	return
end

local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

local applied, skipped = 0, 0

-- Sets every property in `props` on `target`. A property that cannot be set is a
-- warning, not a failure: one stubborn value must not stop the rest of the look.
local function setProps(target: Instance, props: { [string]: any }?, label: string)
	if not props then
		return
	end
	for name, value in pairs(props) do
		local ok, err = pcall(function()
			(target :: any)[name] = value
		end)
		if ok then
			applied += 1
		else
			skipped += 1
			warn(("[Look] %s.%s not set: %s"):format(label, name, tostring(err)))
		end
	end
end

--==========================================================================
waypoint("Look: before " .. PRESET)

setProps(Lighting, preset.Lighting, "Lighting")

-- Atmosphere and Sky are created if the place has none, so a look never silently
-- loses half its effect on a place that was set up differently.
local function ensureChild(className: string): Instance
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local created = Instance.new(className)
	created.Parent = Lighting
	return created
end

if preset.Atmosphere then
	setProps(ensureChild("Atmosphere"), preset.Atmosphere, "Atmosphere")
end
if preset.Sky then
	setProps(ensureChild("Sky"), preset.Sky, "Sky")
end

-- Clouds: nil leaves them alone, false removes them, a table creates and sets them.
local clouds = Terrain:FindFirstChildOfClass("Clouds")
if preset.Clouds == false then
	if clouds then
		clouds:Destroy()
		applied += 1
	end
elseif preset.Clouds then
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = Terrain
	end
	setProps(clouds, preset.Clouds, "Clouds")
end

-- Effects are matched by NAME under Lighting and are never created: a missing one
-- means the place was built differently, and that deserves a look, not a guess.
if preset.Effects then
	for effectName, props in pairs(preset.Effects) do
		local effect = Lighting:FindFirstChild(effectName)
		if effect then
			setProps(effect, props, "Lighting." .. effectName)
		else
			skipped += 1
			warn(("[Look] Lighting.%s does not exist in this place — skipped."):format(effectName))
		end
	end
end

if preset.Terrain then
	for materialName, color in pairs(preset.Terrain) do
		local material = (Enum.Material :: any)[materialName]
		if material then
			Terrain:SetMaterialColor(material, color)
			applied += 1
		else
			skipped += 1
			warn(("[Look] unknown terrain material %s — skipped."):format(materialName))
		end
	end
end

-- Water is a property of the terrain itself, so it is set there directly.
if preset.Water then
	setProps(Terrain, preset.Water, "Terrain")
end

waypoint("Look: " .. PRESET)

print(("[Look] applied \"%s\": %d values set, %d skipped."):format(PRESET, applied, skipped))
if PRESET ~= "Baseline" then
	print('[Look] Set PRESET = "Baseline" and run again to put everything back, or press Ctrl+Z.')
end
