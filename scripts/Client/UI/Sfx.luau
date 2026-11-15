--!strict
--[[
	Sfx
	The sounds of the screen itself (not of a place in the world): the letters of a line being written, a name that
	appears, the title's blow, thunder after lightning, the pack opening. Each is played once, flat (2D), on the
	`TLK_Ui` sound group; their ids and volumes are in configs/Audio.Ui, so a sound can be changed without code.

	The developer, 2026-11-15: "put sound in the game, it has nothing so far; when the letters are written a very light
	sound; with the lightning a sound too".

	    Sfx.play("Type", { speed = 1.1, cut = 0.07 })   -- `cut` stops it after that many seconds (a single key)

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.Sfx (a library: it creates nothing until asked).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

export type Options = { speed: number?, volume: number?, cut: number?, delay: number? }

local group: SoundGroup? = nil

local function uiGroup(): SoundGroup
	local have = group or SoundService:FindFirstChild("TLK_Ui")
	if have and have:IsA("SoundGroup") then
		group = have
		return have
	end
	local made = Instance.new("SoundGroup")
	made.Name = "TLK_Ui"
	made.Volume = 1
	made.Parent = SoundService
	group = made
	return made
end

local function spec(name: string): any
	local ok, cfg = pcall(Config.get, "Audio")
	local ui = ok and cfg and cfg.Ui
	return ui and ui[name]
end

local function playNow(def: any, options: Options?)
	local ids = def.Ids or { def.Id }
	local id = ids[math.random(1, #ids)]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (options and options.volume) or def.Volume or 0.3
	local lo, hi = def.PitchMin or 1, def.PitchMax or 1
	s.PlaybackSpeed = (options and options.speed) or (lo + (hi - lo) * math.random())
	s.SoundGroup = uiGroup()
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	local cut = (options and options.cut) or def.Cut
	task.delay(cut or 12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Plays the screen sound `name` (a key of configs/Audio.Ui) once.
function Sfx.play(name: string, options: Options?)
	local def = spec(name)
	if not def then
		return
	end
	local wait = (options and options.delay) or def.Delay
	if wait and wait > 0 then
		task.delay(wait, playNow, def, options)
	else
		playNow(def, options)
	end
end

return Sfx
