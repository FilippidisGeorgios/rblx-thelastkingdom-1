--!strict
--[[
	Trial.Cue
	A short sound at a place, for everyone near it: a part with no body and a Sound in it, removed when it is done. The sound
	files are named in `configs/Catacombs.Sounds` (Roblox's own, until the sound pass makes real ones), so changing a sound
	is changing a line of data.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Cue = {}

local function folder(): Folder
	local f = Workspace:FindFirstChild("Cues")
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "Cues"
	made.Parent = Workspace
	return made
end

-- Plays `cue` ({ Id, Speed, Volume, Reach }) at `at`.
function Cue.play(at: Vector3, cue: any)
	local part = Instance.new("Part")
	part.Name = "Cue"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = at
	part.Parent = folder()

	local sound = Instance.new("Sound")
	sound.SoundId = cue.Id
	sound.PlaybackSpeed = cue.Speed or 1
	sound.Volume = cue.Volume or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = cue.Reach or 80
	sound.Parent = part
	sound:Play()
	Debris:AddItem(part, 8)
end

return Cue
