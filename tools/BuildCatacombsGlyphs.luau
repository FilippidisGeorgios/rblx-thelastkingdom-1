--[[
	BuildCatacombsGlyphs — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE, after the catacombs are built.
	Marks painted on the walls, each with a REASON (2026-11-02: the developer did not understand things stuck on walls for nothing):

	  ankh   over the entrance of every pocket (a refuge): "life, here you may rest"
	  eye    in the Doctor's study and the plague ward: where he was made what he is
	  sun    at the head of the exit road: the way out
	  tally  in the gaol: strokes in fives, the days a prisoner counted
	  ankh + eye in the crypt and the ossuary: the dead's own marks

	They are drawn with frames on a SurfaceGui (the engine has no font for hieroglyphs: they came out as boxes), in dried-blood
	ochre, lit by the light that falls on them. Run again, it replaces what it placed (`Catacombs.Glyphs`).
	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = workspace.Gameplay.Battleground.Decorations.Area4.Catacombs
local plan = require(ReplicatedStorage.Config.CatacombsMaze)
local cfg = require(ReplicatedStorage.Config.Catacombs)
local L = cfg.Layout
local U = L.Unit
local FLOOR = L.FloorY
local INK = Color3.fromRGB(122, 40, 24)
local rng = Random.new(5)

local function cellCentre(c: number, r: number): Vector3
	return Vector3.new(L.X0 + U * (3 * c + 2), FLOOR, L.ZTop - U * (3 * r + 2))
end

local function frame(parent: Instance, x: number, y: number, w: number, h: number, rot: number?, fill: boolean?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rot or 0
	f.BorderSizePixel = 0
	f.BackgroundColor3 = INK
	f.BackgroundTransparency = if fill == false then 1 else 0.08
	f.Parent = parent
	return f
end

local function ring(parent: Instance, x: number, y: number, w: number, h: number, thick: number)
	local f = frame(parent, x, y, w, h, 0, false)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thick
	s.Parent = f
	return f
end

local GLYPH = {}
function GLYPH.ankh(c: Instance)
	ring(c, 100, 52, 62, 70, 13)
	frame(c, 100, 120, 14, 130)
	frame(c, 100, 98, 96, 14)
end
function GLYPH.eye(c: Instance)
	ring(c, 100, 100, 176, 78, 8)
	ring(c, 100, 100, 56, 56, 9)
	frame(c, 100, 100, 18, 18)
	frame(c, 100, 52, 150, 7)
	frame(c, 100, 150, 9, 36)
	frame(c, 78, 148, 7, 26, 18)
end
function GLYPH.sun(c: Instance)
	ring(c, 100, 100, 70, 70, 10)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		frame(c, 100 + math.cos(a) * 66, 100 + math.sin(a) * 66, 9, 34, i * 30 + 90)
	end
end
function GLYPH.tally(c: Instance)
	for g = 0, 2 do
		local ox = 28 + g * 62
		for i = 0, 3 do
			frame(c, ox + i * 11, 100, 5, 62, rng:NextNumber(-3, 3))
		end
		frame(c, ox + 16, 100, 5, 78, 72)
	end
end

local walls = root.Plan.Walls
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { walls }

local function wallNear(at: Vector3, reach: number): { pos: Vector3, normal: Vector3 }?
	local best = nil
	local bestD = reach
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hit = workspace:Raycast(at, dir * reach, rp)
		if hit and hit.Distance < bestD then
			best, bestD = { pos = hit.Position, normal = hit.Normal }, hit.Distance
		end
	end
	return best
end

local recording = ChangeHistoryService:TryBeginRecording("BuildCatacombsGlyphs")
local old = root:FindFirstChild("Glyphs")
if old then
	old:Destroy()
end
local out = Instance.new("Folder")
out.Name = "Glyphs"
out.Parent = root

local counts: { [string]: number } = {}
local function place(kind: string, from: Vector3, size: number, up: number?, reach: number?)
	local found = wallNear(Vector3.new(from.X, FLOOR + (up or 4.6), from.Z), reach or 14)
	if not found then
		return
	end
	local pos, normal = found.pos, found.normal
	local panel = Instance.new("Part")
	panel.Name = "Glyph_" .. kind
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.CastShadow = false
	panel.Transparency = 1
	panel.Size = Vector3.new(size, size, 0.05)
	panel.CFrame = CFrame.lookAt(pos + normal * 0.04, pos + normal) * CFrame.Angles(0, math.pi, 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 1
	gui.Parent = panel
	local canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = gui
	GLYPH[kind](canvas)
	panel.Parent = out
	counts[kind] = (counts[kind] or 0) + 1
end

-- pockets: an ankh over each (their marks are named pocket1 .. pocket7)
for _, m in root.Marks:GetChildren() do
	if m.Name:find("^pocket%d") then
		local p = if m:IsA("BasePart") then m.Position else m:GetPivot().Position
		place("ankh", p, 2.6, 5.2, 9)
	end
end
-- the halls
for _, hall in plan.Halls do
	local c = cellCentre((hall.c0 + hall.c1) // 2, (hall.r0 + hall.r1) // 2)
	if hall.id == "study" then
		place("eye", c, 4.2, 4.6, 40)
	elseif hall.id == "ward" then
		place("eye", c, 3.4, 4.6, 40)
		place("ankh", c + Vector3.new(6, 0, 0), 2.6, 4.6, 40)
	elseif hall.id == "gaol" then
		for k = -1, 1 do
			place("tally", c + Vector3.new(k * 7, 0, 0), 3.2, 4.2, 40)
		end
	elseif hall.id == "crypt" or hall.id == "ossuary" then
		place("ankh", c, 2.8, 4.8, 40)
		place("eye", c + Vector3.new(-5, 0, 5), 2.8, 4.8, 40)
	end
end
-- the head of the exit road
local gate = root.Marks:FindFirstChild("Gate")
if gate then
	local p = gate:GetPivot().Position
	place("sun", Vector3.new(p.X + 6, 0, p.Z + 7), 3.4, 5.0, 14)
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return counts
