--!strict
--[[
	GraphicsController
	Draws the world at the quality the player chose in the Settings panel (configs/Graphics): Low, Medium, High or
	Ultra, and the shadows switch.

	THE RULE (see configs/Graphics): a quality changes what the picture COSTS, never what the player can SEE. This
	module therefore never touches the brightness, the ambient light, the atmosphere and its fog, the colour grading
	or the colour and reach of any authored light. It changes:
	  - the post effects the place already has (the glow, the sun's rays, the depth blur), kept as authored or
	    switched off, never added;
	  - how many particles each emitter draws (a share of its rate, never to zero, so every cue stays);
	  - how far lights and fires stay lit (DetailLodController), and, on Ultra, shadows from the lights near you;
	  - the terrain's grass;
	  - how sharp the shadows are, and the engine's own quality level where it lets a script set it;
	  - the SURFACES (`Surfaces` in configs/Graphics): on Medium the fine surface pictures (SurfaceAppearance) are taken
	    off; on Low every material also becomes smooth plastic and the tiled pictures on walls are hidden, so the world
	    is plain colours and a player on a weak machine SEES that Low is low (the developer, 2026-11-10). Shapes, colours,
	    light and dark stay as they are. In the lobby this is put back when a better quality is chosen; in the castle a
	    quality can only be lowered (the server holds that), so nothing is kept to put back and the memory is saved.

	THE SHADOWS SWITCH does not turn the world's shadows off: that would let the sun through every roof and light the
	dark rooms, which is an advantage and the end of the mood. Off means SIMPLE shadows: walls, roofs and floors keep
	casting, and the small things (props, people, the dead) stop. The rooms are exactly as dark either way.

	The choice is kept by the server (SettingsService) and arrives as two attributes on the player, so a player in the
	castle draws what they chose in the Hub. It can be changed in either place.

	Place: client (boots in both places). Phase: Settings.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Constants = require(ReplicatedStorage.Shared.Constants)
local DetailLodController = require(script.Parent.DetailLodController)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local GraphicsController = {}

GraphicsController.Name = "GraphicsController"

local log = Logger.new("GraphicsController")

local player = Players.LocalPlayer
local cfg: any = nil
local requestEvent: RemoteEvent? = nil

local quality = "High"
local shadows = true

--[[
	What was authored, kept so a quality can be undone. These are STRONG tables on purpose: a weak-keyed table of
	Instances loses its entries (Roblox may collect the Lua proxy of an instance nothing else in Lua refers to, even
	though the part is alive in the world), which is how the first version of this stopped no shadows at all. The
	price is that a part streamed out of the world stays referenced until `prune` lets it go.
]]
local effectEnabled: { [Instance]: boolean } = {} -- as authored
local emitterRate: { [ParticleEmitter]: number } = {} -- as authored
local smallParts: { [BasePart]: boolean } = {} -- small parts that cast a shadow as authored
local softness: number? = nil
local muted = false

-- the surfaces: what is on now, and what was taken off (kept only where it can ever be put back)
local surfaces = "full"
local canRestore = true
local savedMaterial: { [BasePart]: Enum.Material } = {}
local savedAppearance: { [Instance]: Instance } = {}
local savedTexture: { [Instance]: number } = {}
-- materials that MEAN something (a glow, a window, a ward): never flattened
local KEEP_MATERIAL: { [Enum.Material]: boolean } = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.SmoothPlastic] = true,
}
local onChanged: { (string, boolean) -> () } = {}

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function tier(): any
	return cfg.Tiers[quality]
end

--============================================================================
-- Pieces of the picture
--============================================================================

local function applyEffect(effect: Instance)
	local want: boolean? = nil
	if effect:IsA("BloomEffect") then
		want = tier().Bloom
	elseif effect:IsA("SunRaysEffect") then
		want = tier().SunRays
	elseif effect:IsA("DepthOfFieldEffect") then
		want = tier().DepthOfField
	end
	if want == nil then
		return
	end
	if effectEnabled[effect] == nil then
		effectEnabled[effect] = (effect :: any).Enabled
	end
	-- as authored when the quality allows it; never switched ON when the place had it off
	;(effect :: any).Enabled = effectEnabled[effect] and want
end

local function applyEmitter(emitter: ParticleEmitter)
	local rate = emitterRate[emitter]
	if rate == nil then
		rate = emitter.Rate
		emitterRate[emitter] = rate
	end
	emitter.Rate = (rate :: number) * tier().ParticleScale
end

local function isSmall(part: BasePart): boolean
	local s = part.Size
	return math.max(s.X, s.Y, s.Z) < cfg.SmallPartStuds
end

local function registerPart(part: BasePart)
	if part.CastShadow and not part:IsA("Terrain") and isSmall(part) then
		smallParts[part] = true
		if muted then
			part.CastShadow = false
		end
	end
end

-- One thing's surface as the quality says ("plain": no fine surface picture; "flat": that, smooth plastic, no tiled picture).
local function surfaceOf(instance: Instance)
	if surfaces == "full" then
		return
	end
	if instance:IsA("SurfaceAppearance") then
		local parent = instance.Parent
		if parent then
			if canRestore then
				savedAppearance[instance] = parent
			end
			-- (not in the same breath as it arrives: a thing may not be moved while it is still being put in)
			task.defer(function()
				if surfaces ~= "full" and instance.Parent == parent then
					instance.Parent = nil
				end
			end)
		end
	elseif surfaces == "flat" then
		if instance:IsA("Texture") then
			if canRestore and savedTexture[instance] == nil then
				savedTexture[instance] = instance.Transparency
			end
			instance.Transparency = 1
		elseif instance:IsA("BasePart") and not instance:IsA("Terrain") and not KEEP_MATERIAL[instance.Material] then
			if canRestore and savedMaterial[instance] == nil then
				savedMaterial[instance] = instance.Material
			end
			instance.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function register(instance: Instance)
	if instance:IsA("ParticleEmitter") then
		applyEmitter(instance)
	elseif instance:IsA("BasePart") then
		registerPart(instance)
	end
	surfaceOf(instance)
end

-- The whole world's surfaces, when the quality's `Surfaces` changes. Going up puts back what was kept (the lobby only).
local surfaceToken = 0
local function setSurfaces(mode: string)
	if mode == surfaces then
		return
	end
	local was = surfaces
	surfaces = mode
	surfaceToken += 1
	local token = surfaceToken
	local rank = { full = 3, plain = 2, flat = 1 }
	if (rank[mode] or 3) > (rank[was] or 3) then
		-- richer than before: materials and tiled pictures come back; the fine pictures only at "full"
		local n = 0
		for part, material in savedMaterial do
			if part.Parent then
				part.Material = material
			end
			savedMaterial[part] = nil
			n += 1
			if n % 2000 == 0 then
				task.wait()
			end
		end
		for texture, transparency in savedTexture do
			if texture.Parent then
				(texture :: any).Transparency = transparency
			end
			savedTexture[texture] = nil
		end
		if mode == "full" then
			for appearance, parent in savedAppearance do
				if parent.Parent then
					appearance.Parent = parent
				end
				savedAppearance[appearance] = nil
			end
		end
		return
	end
	local n = 0
	for _, instance in Workspace:GetDescendants() do
		if token ~= surfaceToken then
			return
		end
		surfaceOf(instance)
		n += 1
		if n % 2500 == 0 then
			task.wait()
		end
	end
	log:info(("surfaces %s: %d things looked at"):format(mode, n))
end

-- SIMPLE shadows (shadows switch off): the small casters stop; the structures keep casting.
local function setMuted(on: boolean)
	if muted == on then
		return
	end
	muted = on
	local n = 0
	for part in smallParts do
		if part.Parent then
			part.CastShadow = not on
		end
		n += 1
		if n % 1500 == 0 then
			task.wait()
		end
	end
	log:info(("shadows %s: %d small casters %s"):format(if on then "SIMPLE" else "full", n, if on then "stopped" else "restored"))
end

-- Lets go of what has left the world (streamed out, destroyed), so the strong tables above do not grow for ever.
local function prune()
	local n = 0
	for part in smallParts do
		if not part.Parent then
			smallParts[part] = nil
		end
		n += 1
		if n % 3000 == 0 then
			task.wait()
		end
	end
	for emitter in emitterRate do
		if not emitter.Parent then
			emitterRate[emitter] = nil
		end
	end
	for effect in effectEnabled do
		if not effect.Parent then
			effectEnabled[effect] = nil
		end
	end
	for part in savedMaterial do
		if not part.Parent then
			savedMaterial[part] = nil
		end
	end
	for texture in savedTexture do
		if not texture.Parent then
			savedTexture[texture] = nil
		end
	end
	for appearance, parent in savedAppearance do
		if not parent.Parent then
			savedAppearance[appearance] = nil
		end
	end
end

--============================================================================
-- The whole picture
--============================================================================

local function applyAll()
	local t = tier()

	for _, child in Lighting:GetChildren() do
		applyEffect(child)
	end

	if softness == nil then
		softness = Lighting.ShadowSoftness
	end
	Lighting.ShadowSoftness = math.clamp((softness :: number) * t.SoftShadows, 0, 1)

	pcall(function()
		Workspace.Terrain.Decoration = t.Decoration
	end)

	for emitter in emitterRate do
		if emitter.Parent then
			applyEmitter(emitter)
		end
	end

	DetailLodController.setScale(t.LodScale)
	DetailLodController.setLightShadows(t.LightShadows and shadows)

	-- the engine's own level, where a script may set it. It changes how much detail is drawn far away, not the light.
	-- Only once the player has CHOSEN a quality: until then their own Roblox setting is left alone.
	if type(player:GetAttribute("GfxQuality")) == "string" then
		pcall(function()
			local level = Enum.QualityLevel:FromName(("Level%02d"):format(t.QualityLevel))
			if level and settings().Rendering.QualityLevel ~= level then
				settings().Rendering.QualityLevel = level
			end
		end)
	end

	task.spawn(setMuted, not shadows)
	task.spawn(setSurfaces, t.Surfaces or "full")
end

local function readState()
	local graphics = player:GetAttribute("GfxQuality")
	local sh = player:GetAttribute("GfxShadows")
	local stored = {
		graphics = if type(graphics) == "string" then graphics else nil,
		shadows = if type(sh) == "boolean" then sh else nil,
	}
	quality, shadows = PlayerSettings.effective(stored, cfg, isPhone())
end

local pending = false
local function refresh()
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		readState()
		applyAll()
		for _, handler in onChanged do
			handler(quality, shadows)
		end
	end)
end

--============================================================================
-- For the Settings panel
--============================================================================

-- Asks the server to keep a choice ({ graphics = "Ultra" } and/or { shadows = false }). The picture follows
-- when the server has accepted it and the attributes arrive.
function GraphicsController.request(change: { [string]: any })
	if requestEvent then
		requestEvent:FireServer(change)
	end
end

-- Calls `handler(quality, shadows)` now and every time the picture's settings change.
function GraphicsController.observe(handler: (string, boolean) -> ())
	table.insert(onChanged, handler)
	handler(quality, shadows)
end

function GraphicsController.current(): (string, boolean)
	return quality, shadows
end

function GraphicsController.Init() end

function GraphicsController.Start()
	cfg = Config.get("Graphics")
	requestEvent = Net.getEvent("RequestSettings")
	readState()
	-- where the quality may only go down, nothing that is taken off is kept to be put back
	for _, place in cfg.Lock.Places do
		if Constants.PlaceIds[place] == game.PlaceId then
			canRestore = false
		end
	end

	-- scan the world once, then follow whatever streams in
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		local n = 0
		for _, instance in Workspace:GetDescendants() do
			register(instance)
			n += 1
			if n % 2000 == 0 then
				task.wait()
			end
		end
		applyAll()
		local small, emitters = 0, 0
		for _ in smallParts do
			small += 1
		end
		for _ in emitterRate do
			emitters += 1
		end
		log:info(("scanned %d instances: %d small shadow casters, %d emitters; picture %s, shadows %s"):format(n, small, emitters, quality, tostring(shadows)))
	end)
	Workspace.DescendantAdded:Connect(register)
	task.spawn(function()
		while true do
			task.wait(30)
			prune()
		end
	end)
	Lighting.ChildAdded:Connect(function(child)
		applyEffect(child)
	end)

	player:GetAttributeChangedSignal("GfxQuality"):Connect(refresh)
	player:GetAttributeChangedSignal("GfxShadows"):Connect(refresh)
	refresh()
end

return GraphicsController
