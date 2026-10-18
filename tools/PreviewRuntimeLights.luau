--[[
	PreviewRuntimeLights — run in the Studio Command Bar of the KINGDOM HUB place,
	in EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	WHY THIS EXISTS. The lanterns, torches and campfires are hand-placed in Studio at
	whatever values they were dropped in with — brighter and far wider than intended.
	`LightService` retunes every one of them from `configs/Hub.luau -> Lights` when the
	game RUNS, but it never writes that back to the place. So the lobby you see while
	editing is not the lobby a player sees: in Edit mode the lamps flood the lanes with
	orange that does not exist in play. Judging a look (fog, ground colour, sky) against
	lights that are two or three times too strong gives the wrong answer.

	MODE, set below:

	  "on"    stamps the runtime values onto every lobby light, so the Edit view matches
	          what a player will see. The ORIGINAL values are kept on each light as
	          Preview* attributes.

	  "off"   puts every original value back exactly, and removes the attributes.

	Nothing is lost either way, and it is safe to run "on" twice (a light that already
	carries its originals is not overwritten). Both runs are undo waypoints.

	While it is "on", do NOT save the place by accident and do not hand-tune a light:
	run "off" first. Rojo does not own these lights, so what is saved is what stays.

	KEEP IN STEP WITH `scripts/Server/Hub/LightService.luau`: the group matching and
	the values written below are a copy of its `groupFor` / `tune`.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "on"

--==========================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local configRoot = ReplicatedStorage:FindFirstChild("Config")
local hubModule = configRoot and configRoot:FindFirstChild("Hub")
if not (hubModule and hubModule:IsA("ModuleScript")) then
	warn("[Preview] ReplicatedStorage.Config.Hub is missing — is this the Kingdom Hub place?")
	return
end

-- A clone has never been required, so this reads the CURRENT source.
local hub = require(hubModule:Clone())
local cfg = hub.Lights
local lobbyName = hub.Train.LobbyFolder
local lobby = workspace:FindFirstChild(lobbyName)
if not lobby then
	warn(("[Preview] workspace.%s not found — nothing to do."):format(lobbyName))
	return
end

local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

local function isLight(instance: Instance): boolean
	return instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
end

local function ours(light: Instance): boolean
	for _, folderName in cfg.IgnoreFolders do
		if light:FindFirstAncestor(folderName) then
			return true
		end
	end
	return false
end

local function groupFor(light: Instance): any
	local names = {}
	local node: Instance? = light
	while node and node.Name ~= lobbyName do
		table.insert(names, string.lower(node.Name))
		node = node.Parent
	end
	for _, group in cfg.Groups do
		for _, needle in group.Match do
			local lowered = string.lower(needle)
			for _, name in names do
				if string.find(name, lowered, 1, true) then
					return group
				end
			end
		end
	end
	return nil
end

--==========================================================================
local changed = 0

if MODE == "on" then
	waypoint("Preview lights: before on")
	for _, light in ipairs(lobby:GetDescendants()) do
		if isLight(light) and not ours(light) and light:GetAttribute("PreviewBrightness") == nil then
			local target = light :: any
			-- Originals first, so "off" can always return the light exactly as it was.
			light:SetAttribute("PreviewBrightness", target.Brightness)
			light:SetAttribute("PreviewColor", target.Color)
			light:SetAttribute("PreviewShadows", target.Shadows)
			if light:IsA("PointLight") or light:IsA("SpotLight") then
				light:SetAttribute("PreviewRange", target.Range)
			end
			if light:IsA("SpotLight") then
				light:SetAttribute("PreviewAngle", target.Angle)
			end

			local spec = groupFor(light) or cfg.Default
			target.Brightness = spec.Brightness
			target.Color = spec.Color
			target.Shadows = spec.Shadows
			if light:IsA("PointLight") or light:IsA("SpotLight") then
				target.Range = spec.Range
			end
			if light:IsA("SpotLight") then
				target.Angle = cfg.SpotAngle
			end
			changed += 1
		end
	end
	waypoint("Preview lights: on")
	print(("[Preview] ON: %d lights now show their runtime values."):format(changed))
	print('[Preview] Set MODE = "off" and run again before saving or hand-tuning any light.')
elseif MODE == "off" then
	waypoint("Preview lights: before off")
	for _, light in ipairs(lobby:GetDescendants()) do
		if isLight(light) and light:GetAttribute("PreviewBrightness") ~= nil then
			local target = light :: any
			target.Brightness = light:GetAttribute("PreviewBrightness")
			target.Color = light:GetAttribute("PreviewColor")
			target.Shadows = light:GetAttribute("PreviewShadows")
			if light:GetAttribute("PreviewRange") ~= nil then
				target.Range = light:GetAttribute("PreviewRange")
			end
			if light:GetAttribute("PreviewAngle") ~= nil then
				target.Angle = light:GetAttribute("PreviewAngle")
			end
			for _, name in { "PreviewBrightness", "PreviewColor", "PreviewShadows", "PreviewRange", "PreviewAngle" } do
				light:SetAttribute(name, nil)
			end
			changed += 1
		end
	end
	waypoint("Preview lights: off")
	print(("[Preview] OFF: %d lights restored to their saved values."):format(changed))
else
	warn('[Preview] MODE must be "on" or "off".')
end
