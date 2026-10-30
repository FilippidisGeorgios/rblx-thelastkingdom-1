--!strict
--[[
	DetailLodController
	Switches lights and particle emitters off when they are too far from the
	camera to be seen, and back on as the camera comes near.

	WHY. The Forgotten Lands carries ~500 lights and ~430 emitters. Almost all
	of them are somewhere else: a fire two chambers away is a light the renderer
	still has to consider and a few thousand particles the client still has to
	simulate, for nothing the player can see through the haze. Streaming already
	drops what is far enough away to leave the map; this thins what is still
	loaded. Phones get shorter distances.

	WHAT. Instances tagged "TLK_Lod" (`tools/OptimiseCastle` tags them; the
	tag survives in the place). A tag can arrive or leave at any time because
	streaming brings parts in and out, so it follows the tag's signals. Position
	is read once, when the instance is registered: scenery does not move.

	FOR MECHANICS. Anything that lights or douses a tagged fire (the grave
	braziers, the forge) should set the attribute `LodWant` (true/false) on the
	light or emitter instead of, or as well as, `Enabled`. While `LodWant` is
	set it is the answer to "should this be on when it is near"; without it, the
	state the instance had when it arrived is. Setting `Enabled` directly still
	works for as long as the camera is near it.

	IN THE HUB there is no tag (the Hub was built by hand, not by the castle tool), so here the controller takes
	EVERY light and emitter in the world that is not on a character, as it arrives. This is what lets the picture
	quality in Settings change something in the lobby too (how far lanterns and fires stay lit, and on Ultra the
	lights near you casting shadows). Those entries are "dynamic": the Hub has things that move (the train), so
	a light's position is read again at every step, and what a light was doing when it was cut is what it goes
	back to.

	Place: client (boots in both places; tagged things in the castle, everything in the Hub).
	Phase: Performance.
]]

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

local DetailLodController = {}

DetailLodController.Name = "DetailLodController"

local TAG = "TLK_Lod"

-- Studs from the camera. An entry switches off beyond RANGE + HYSTERESIS and on
-- again inside RANGE, so one sitting on the edge does not flicker.
local LIGHT_RANGE = 120
local FX_RANGE = 150
local HYSTERESIS = 15
local PHONE_SCALE = 0.7
local STEP_SECONDS = 0.25

type Entry = {
	instance: Instance, -- a Light or a ParticleEmitter
	position: Vector3,
	range: number,
	arrivedOn: boolean,
	cut: boolean, -- true while this controller is holding it off
	arrivedShadows: boolean?, -- a Light's own Shadows as it arrived
	shadowed: boolean, -- true while this controller is making the light cast shadows (Ultra)
	dynamic: boolean, -- the Hub's: position re-read each step, and "on" is whatever it was when it was cut
}

local entries: { [Instance]: Entry } = {}

-- The picture quality (UI/SettingsUI, Controllers/GraphicsController) stretches or shrinks how far lights and
-- fires stay lit, and on Ultra lets the lights near the camera cast shadows. Neither changes how bright a
-- lit light is: only how far away it is still drawn.
local rangeScale = 1
local lightShadows = false
local SHADOW_RANGE = 45

local function worldPosition(instance: Instance): Vector3?
	local parent = instance.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function isOn(instance: Instance): boolean
	return (instance :: any).Enabled
end

local function setOn(instance: Instance, on: boolean)
	(instance :: any).Enabled = on
end

local function wanted(entry: Entry): boolean
	local override = entry.instance:GetAttribute("LodWant")
	if typeof(override) == "boolean" then
		return override
	end
	return entry.arrivedOn
end

local function register(instance: Instance, dynamic: boolean?)
	if entries[instance] then
		return
	end
	if not (instance:IsA("Light") or instance:IsA("ParticleEmitter")) then
		return
	end
	local position = worldPosition(instance)
	if not position then
		return
	end
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local scale = if phone then PHONE_SCALE else 1
	entries[instance] = {
		instance = instance,
		position = position,
		range = (if instance:IsA("Light") then LIGHT_RANGE else FX_RANGE) * scale,
		arrivedOn = isOn(instance),
		cut = false,
		arrivedShadows = if instance:IsA("Light") then (instance :: any).Shadows else nil,
		shadowed = false,
		dynamic = dynamic == true,
	}
end

-- A light or emitter in the Hub: any that is not part of a character (a player's torch moves with them and is
-- not scenery), taken when it arrives.
local function registerHub(instance: Instance)
	if not (instance:IsA("Light") or instance:IsA("ParticleEmitter")) then
		return
	end
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return
	end
	register(instance, true)
end

local function unregister(instance: Instance)
	local entry = entries[instance]
	if entry then
		entries[instance] = nil
		-- Streaming it out: leave it as it would have been, in case it comes back.
		if entry.cut and instance.Parent then
			setOn(instance, entry.arrivedOn)
		end
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, entry in entries do
		if entry.dynamic then
			local at = worldPosition(entry.instance)
			if at then
				entry.position = at
			end
		end
		local distance = (entry.position - eye).Magnitude
		local range = entry.range * rangeScale
		if entry.cut then
			if distance <= range then
				entry.cut = false
				setOn(entry.instance, wanted(entry))
			end
		elseif distance > range + HYSTERESIS then
			if entry.dynamic then
				-- remember what it was doing, so a fire the Hub put out is not lit again when you come back
				entry.arrivedOn = isOn(entry.instance)
			end
			entry.cut = true
			setOn(entry.instance, false)
		end

		if entry.arrivedShadows ~= nil then
			local want = lightShadows and not entry.cut and distance <= SHADOW_RANGE
			if want ~= entry.shadowed then
				entry.shadowed = want
				;(entry.instance :: any).Shadows = if want then true else entry.arrivedShadows
			end
		end
	end
end

-- How far lights and fires stay lit, as a share of the authored distance (Graphics.Tiers.*.LodScale).
function DetailLodController.setScale(scale: number)
	rangeScale = math.clamp(scale, 0.3, 3)
end

-- Ultra: the lights near the camera cast shadows (while the player's shadows switch is on).
function DetailLodController.setLightShadows(on: boolean)
	lightShadows = on
end

function DetailLodController.Init() end

function DetailLodController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		register(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

	-- the Hub: everything that is a light or a fire (see the header)
	local inHub = game.PlaceId == Constants.PlaceIds.KingdomHub
		or (game.PlaceId == 0 and Workspace:FindFirstChild("Lobby") ~= nil and Workspace:FindFirstChild("Gameplay") == nil)
	if inHub then
		task.spawn(function()
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
			local n = 0
			for _, instance in Workspace:GetDescendants() do
				registerHub(instance)
				n += 1
				if n % 3000 == 0 then
					task.wait()
				end
			end
		end)
		Workspace.DescendantAdded:Connect(registerHub)
		Workspace.DescendantRemoving:Connect(unregister)
	end

	task.spawn(function()
		while true do
			step()
			task.wait(STEP_SECONDS)
		end
	end)
end

return DetailLodController
