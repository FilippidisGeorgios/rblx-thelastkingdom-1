--[[
	PlaceBones — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE, after tools/BuildCatacombsProps ("props").
	Puts the catacombs' dead in their right shape. The first version made skulls from balls and bones from sticks, and it showed. These
	are two meshes made with `generate_mesh` (a skull with its jaw, and the upper half of a skeleton with its pelvis), kept in
	`ServerStorage.Assets.CatacombMeshes` (Skull, Torso). Run again, it replaces what it placed.

	  * every old skull ball and jaw of a heap becomes a skull (lying any way, some sunk in the sand)
	  * the skulls in the burial niches become small ones
	  * the sticks of a heap are kept (they are scattered ribs and thigh bones) but some are sunk, as before
	  * skeletons lie in the halls and in some dead ends, on their backs, the half of the chest or more sunk in the floor, and some more
	    skeletons lie beside the walls of the long passages

	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (the developer saves it).
]]

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local root = workspace.Gameplay.Battleground.Decorations.Area4.Catacombs
local store = ServerStorage.Assets:FindFirstChild("CatacombMeshes")
assert(store and store:FindFirstChild("Skull") and store:FindFirstChild("Torso"), "ServerStorage.Assets.CatacombMeshes.Skull / Torso are missing")
local FLOOR = -70
local rng = Random.new(31)

local recording = ChangeHistoryService:TryBeginRecording("PlaceBones")
local bones = root:FindFirstChild("Bones")
if not bones then
	bones = Instance.new("Folder")
	bones.Name = "Bones"
	bones.Parent = root
end
-- (run again, only the skeletons are laid anew; the skulls come from the balls of the heaps and are placed once)
for _, m in bones:GetChildren() do
	if m.Name == "Skeleton" then
		m:Destroy()
	end
end
local clear = OverlapParams.new()
clear.FilterType = Enum.RaycastFilterType.Exclude
clear.FilterDescendantsInstances = { bones, root:FindFirstChild("Detail") }
local function room(at: Vector3): boolean
	for _, q in workspace:GetPartBoundsInBox(CFrame.new(at.X, FLOOR + 1.1, at.Z), Vector3.new(3.6, 1.8, 3.6), clear) do
		if q.CanCollide and q.Name ~= "Floor" and q ~= workspace.Terrain then
			return false
		end
	end
	return true
end

local function stillLife(model: Model, parent: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	model.Parent = parent
end

local function skullAt(position: Vector3, scale: number, yaw: number, lieOnSide: boolean, sink: number)
	local m = store.Skull:Clone()
	m.Name = "Skull"
	m:ScaleTo(scale)
	local lift = scale * 0.55 - sink
	local roll = if lieOnSide then math.rad(rng:NextNumber(60, 100)) * (if rng:NextNumber() < 0.5 then 1 else -1) else 0
	m:PivotTo(CFrame.new(position.X, position.Y + lift, position.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, roll))
	stillLife(m, bones)
end

local counts = { skulls = 0, torsos = 0, niche = 0, jaws = 0 }
local props = root.Props
local sticks: { Vector3 } = {}
for _, p in props:GetChildren() do
	local base = p.Name:gsub("%d+$", "")
	if p:IsA("BasePart") and base == "Skull" then
		local at = p.Position
		p:Destroy()
		local sink = if at.Y < FLOOR + 0.15 then rng:NextNumber(0.1, 0.3) else 0
		skullAt(Vector3.new(at.X, math.max(at.Y, FLOOR), at.Z), rng:NextNumber(0.62, 0.8), rng:NextNumber(0, 6.28), rng:NextNumber() < 0.7, sink)
		counts.skulls += 1
	elseif p:IsA("BasePart") and base == "Jaw" then
		p:Destroy()
		counts.jaws += 1
	elseif p:IsA("BasePart") and base == "Bone" then
		table.insert(sticks, p.Position)
	end
end
-- niches
local detail = root:FindFirstChild("Detail")
if detail then
	for _, p in detail:GetChildren() do
		if p.Name == "NicheSkull" then
			local at = p.Position
			p:Destroy()
			skullAt(Vector3.new(at.X, at.Y - 0.2, at.Z), 0.5, rng:NextNumber(0, 6.28), true, 0)
			counts.niche += 1
		end
	end
end

-- skeletons on their backs, sunk: where the bones lie thick, and a few along the passages
local used: { Vector3 } = {}
local function far(v: Vector3): boolean
	for _, u in used do
		if (u - v).Magnitude < 7 then
			return false
		end
	end
	return true
end
local want = math.min(34, #sticks)
local tries = 0
while counts.torsos < want and tries < 600 do
	tries += 1
	local at = sticks[rng:NextInteger(1, #sticks)]
	if far(at) and room(at) then
		table.insert(used, at)
		local m = store.Torso:Clone()
		m.Name = "Skeleton"
		m:ScaleTo(rng:NextNumber(2.8, 3.3))
		local _, size = m:GetBoundingBox()
		-- lying on its back, head one way: the long side flat. The chest is sunk by a third to a half of its thickness
		local sink = rng:NextNumber(0.2, 0.55)
		m:PivotTo(CFrame.new(at.X, FLOOR + sink + 0.1, at.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(math.rad(-90), 0, 0))
		stillLife(m, bones)
		counts.torsos += 1
	end
end
-- the sticks that remain: some sunk to the half (as before they were, in 80 heaps)
for _, p in props:GetChildren() do
	if p:IsA("BasePart") and p.Name:gsub("%d+$", "") == "Bone" and rng:NextNumber() < 0.3 then
		p.CFrame = p.CFrame - Vector3.new(0, rng:NextNumber(0.05, 0.12), 0)
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return counts
