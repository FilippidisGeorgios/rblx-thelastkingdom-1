--!strict
--[[
	AudioController
	The game's quiet sounds (configs/Audio), on each client: the server only ever says what happened (an attribute on a
	body), and every client hears it from where it stands.

	  AMBIENT  a low drone and a far wind under everything, barely there, faded in after loading. One SoundGroup
	           "TLK_Ambience" so a later volume setting has one knob.
	  HIT      one of the dead takes a wound (its HitCount goes up: EnemyService/MeleeCombatService write it): a muffled
	           thud AT THAT BODY, a 3D sound heard by whoever is near, quietly. Two hits on one body inside Hit.Gap
	           are one sound.
	  DRAW     a player's sword comes out (the character's "WeaponDrawn" goes true while "Weapon" is a sword:
	           WeaponVisualService): steel on leather, very light, at that player.

	(Named AudioController, not "AudioService": server singletons are Services, client singletons are Controllers.)

	Place: shared client. Phase: Polish / Atmosphere (2026-11-14: was a skeleton until now).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BodyAnimController = require(script.Parent.BodyAnimController)

local AudioController = {}

AudioController.Name = "AudioController"

local UNDEAD_TAG = "TLK_Undead"

local effects: SoundGroup? = nil
local ambience: SoundGroup? = nil

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local new = Instance.new("SoundGroup")
	new.Name = name
	new.Volume = volume
	new.Parent = SoundService
	return new
end

-- A one-shot 3D sound at `part`, cleaned up when it ends.
local function oneShot(id: string, part: BasePart, volume: number, speed: number, rollOff: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = rollOff
	s.SoundGroup = effects
	s.Parent = part
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function startAmbient(cfg: any)
	local g = ambience :: SoundGroup
	for i, layer in cfg.Ambient or {} do
		local s = Instance.new("Sound")
		s.Name = "Ambient" .. i
		s.SoundId = layer.Id
		s.Looped = true
		s.Volume = 0
		s.PlaybackSpeed = layer.Speed or 1
		s.SoundGroup = g
		s.Parent = SoundService
		s:Play()
		TweenService:Create(s, TweenInfo.new(cfg.AmbientFadeSeconds or 6, Enum.EasingStyle.Sine), { Volume = layer.Volume }):Play()
	end
end

local function watchUndead(model: Instance, cfg: any)
	if not model:IsA("Model") then
		return
	end
	local hit = cfg.Hit
	if not hit or #hit.Ids == 0 then
		return
	end
	local last = model:GetAttribute("HitCount")
	local lastAt = 0
	model:GetAttributeChangedSignal("HitCount"):Connect(function()
		local n = model:GetAttribute("HitCount")
		local up = typeof(n) == "number" and typeof(last) == "number" and n > last
		last = n
		if not up then
			return
		end
		local now = os.clock()
		if now - lastAt < (hit.Gap or 0.06) then
			return
		end
		lastAt = now
		local at = model:FindFirstChild("UpperTorso") or model.PrimaryPart
		if at and at:IsA("BasePart") then
			local id = hit.Ids[math.random(1, #hit.Ids)]
			local speed = hit.PitchMin + math.random() * (hit.PitchMax - hit.PitchMin)
			oneShot(id, at, hit.Volume, speed, hit.RollOffMax or 45)
		end
	end)
end

local function watchCharacter(character: Model, cfg: any)
	local draw = cfg.Draw
	if not draw then
		return
	end
	local weapons = Config.get("Gear").Weapons
	local function kind(): string?
		local id = character:GetAttribute("Weapon")
		local def = typeof(id) == "string" and weapons[id] or nil
		return def and def.Kind or nil
	end
	local drawn = character:GetAttribute("WeaponDrawn") == true
	character:GetAttributeChangedSignal("WeaponDrawn"):Connect(function()
		local now = character:GetAttribute("WeaponDrawn") == true
		if now and not drawn then
			local k = kind()
			local at = character:FindFirstChild("HumanoidRootPart")
			if k and draw.Kinds[k] and at and at:IsA("BasePart") then
				oneShot(draw.Id, at, draw.Volume, 0.95 + math.random() * 0.1, draw.RollOffMax or 30)
			end
		end
		drawn = now
	end)
end

-- The dead groan now and then: one near the eyes, at random (configs/Audio.Groan).
local function groans(cfg: any)
	local g = cfg.Groan
	if not g or #g.Ids == 0 then
		return
	end
	task.spawn(function()
		while true do
			task.wait(g.EveryMin + math.random() * (g.EveryMax - g.EveryMin))
			local camera = workspace.CurrentCamera
			if camera then
				local near = {}
				for _, m in CollectionService:GetTagged(UNDEAD_TAG) do
					local head = m:IsA("Model") and (m:FindFirstChild("Head") or m.PrimaryPart)
					local humanoid = m:FindFirstChildOfClass("Humanoid")
					if head and head:IsA("BasePart") and (not humanoid or humanoid.Health > 0)
						and (head.Position - camera.CFrame.Position).Magnitude < g.Range then
						table.insert(near, head)
					end
				end
				if #near > 0 then
					local at = near[math.random(1, #near)]
					local id = g.Ids[math.random(1, #g.Ids)]
					oneShot(id, at, g.Volume, g.PitchMin + math.random() * (g.PitchMax - g.PitchMin), g.RollOffMax or 60)
				end
			end
		end
	end)
end

function AudioController.Init()
	effects = group("TLK_Effects", 1)
	ambience = group("TLK_Ambience", 1)
end

function AudioController.Start()
	local ok, cfg = pcall(Config.get, "Audio")
	if not ok or not cfg then
		return
	end
	-- the ambience waits for the game to be on screen (the loading screen sets this when it lifts)
	task.spawn(function()
		local first = game:GetService("ReplicatedFirst")
		local waited = 0
		while first:GetAttribute("TLKScreenGone") ~= true and waited < 80 do
			waited += task.wait(0.5)
		end
		startAmbient(cfg)
	end)
	-- a blade through the air at every swing, anyone's
	local sw = cfg.Swing
	if sw and #sw.Ids > 0 then
		BodyAnimController.onSwing(function(character: Model)
			local at = character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart")
			if at and at:IsA("BasePart") then
				local id = sw.Ids[math.random(1, #sw.Ids)]
				oneShot(id, at, sw.Volume, sw.PitchMin + math.random() * (sw.PitchMax - sw.PitchMin), sw.RollOffMax or 40)
			end
		end)
	end
	groans(cfg)
	for _, m in CollectionService:GetTagged(UNDEAD_TAG) do
		watchUndead(m, cfg)
	end
	CollectionService:GetInstanceAddedSignal(UNDEAD_TAG):Connect(function(m)
		watchUndead(m, cfg)
	end)
	local function onPlayer(p: Player)
		if p.Character then
			watchCharacter(p.Character, cfg)
		end
		p.CharacterAdded:Connect(function(c)
			watchCharacter(c, cfg)
		end)
	end
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return AudioController
