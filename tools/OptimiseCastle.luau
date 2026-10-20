--[[
	OptimiseCastle — run in the FORGOTTEN LANDS place, in EDIT MODE, after any
	build tool (BuildBattleground, BuildWards, LightCastle, BuildSurroundings).
	Safe to run again: it only sets properties and tags, it builds nothing.

	The place is ~64k parts, ~500 lights and ~430 emitters. Two things keep that
	playable on a phone, and both need the scenery marked up first:

	  STREAMING   `Workspace.StreamingEnabled` is on (a script can turn it on but
	              cannot set the radii; the defaults, 128 min / 1024 target, are
	              what the place uses). A building that streamed in a part at a
	              time would arrive with a floor and no wall, or a stair and no
	              landing, so every building (each direct child Model of
	              Decorations.AreaN) is ATOMIC: it appears whole or not at all.
	              The Shell (walls and towers, ~5.9k parts) is Persistent and
	              always there. Everything else stays at Default.

	  DETAIL LOD  Lights and particle emitters are tagged "TLK_Lod". The client
	              (`Client/Controllers/DetailLodController`) switches the tagged
	              ones off beyond a distance from the camera and back on as they
	              come near, because a fire 300 studs away that nobody can see
	              still costs a light and a few thousand particles. Anything
	              under `Gameplay.Surroundings` (the red light in the last tower,
	              the smoke seen from the hill) and anything with the attribute
	              LodExempt = true is left alone.

	Rerunning on a clean place changes nothing. Undo with MODE = "undo".

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "apply" -- "apply" | "undo"

--==========================================================================
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TAG = "TLK_Lod"

local gameplay = workspace:FindFirstChild("Gameplay")
assert(gameplay, "OptimiseCastle: no Workspace.Gameplay — is this the Forgotten Lands place?")

local recording = ChangeHistoryService:TryBeginRecording("OptimiseCastle")

local atomic, persistent, tagged, untagged, exempt = 0, 0, 0, 0, 0

-- Streaming: workspace switch, buildings atomic, shell persistent.
pcall(function()
	workspace.StreamingEnabled = MODE == "apply"
end)

local battleground = gameplay:FindFirstChild("Battleground")
local decorations = battleground and battleground:FindFirstChild("Decorations")
if decorations then
	for _, area in decorations:GetChildren() do
		for _, child in area:GetChildren() do
			if child:IsA("Model") then
				child.ModelStreamingMode = if MODE == "apply" then Enum.ModelStreamingMode.Atomic else Enum.ModelStreamingMode.Default
				atomic += 1
			end
		end
	end
end
local shell = battleground and battleground:FindFirstChild("Shell")
if shell and shell:IsA("Model") then
	shell.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	persistent += 1
end
-- The arrival pad is where a player lands: it must be there before they are.
local pad = battleground and battleground:FindFirstChild("SpawnPad")
if pad and pad:IsA("Model") then
	pad.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	persistent += 1
end

-- Detail LOD: tag every light and emitter that is not scenery seen from afar.
local surroundings = gameplay:FindFirstChild("Surroundings")
for _, d in gameplay:GetDescendants() do
	if d:IsA("Light") or d:IsA("ParticleEmitter") then
		if (surroundings and d:IsDescendantOf(surroundings)) or d:GetAttribute("LodExempt") == true then
			exempt += 1
			CollectionService:RemoveTag(d, TAG)
		elseif MODE == "apply" then
			CollectionService:AddTag(d, TAG)
			tagged += 1
		else
			CollectionService:RemoveTag(d, TAG)
			untagged += 1
		end
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(
	("[OptimiseCastle] %s — StreamingEnabled=%s, %d buildings atomic, %d persistent, %d lights/emitters %s, %d left alone")
		:format(MODE, tostring(workspace.StreamingEnabled), atomic, persistent, tagged + untagged, if MODE == "apply" then "tagged" else "untagged", exempt)
)
