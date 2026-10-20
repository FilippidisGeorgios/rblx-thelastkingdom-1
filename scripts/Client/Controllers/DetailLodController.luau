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

	Place: client (boots in both places; nothing in the Hub carries the tag).
	Phase: Performance.
]]

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
}

local entries: { [Instance]: Entry } = {}

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

local function register(instance: Instance)
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
	}
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
		local distance = (entry.position - eye).Magnitude
		if entry.cut then
			if distance <= entry.range then
				entry.cut = false
				setOn(entry.instance, wanted(entry))
			end
		elseif distance > entry.range + HYSTERESIS then
			entry.cut = true
			setOn(entry.instance, false)
		end
	end
end

function DetailLodController.Init() end

function DetailLodController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

	task.spawn(function()
		while true do
			step()
			task.wait(STEP_SECONDS)
		end
	end)
end

return DetailLodController
