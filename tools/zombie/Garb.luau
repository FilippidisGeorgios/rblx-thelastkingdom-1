--[[
	Garb (2026-11-14): dresses the King and the Hollow Knight in the pieces of asset garb_v1 (tools/blender/make_garb.py).

	    local Garb = require(lab.Garb)
	    Garb.load()                  -- the uploaded model, into ZombieLab.GarbRaw (once)
	    Garb.dress(model, "King")    -- or "Knight"

	Each mesh is named <Body>_<Part>__<Piece> and was built in the frame of that body part; the markers Garb_M0/MX/MY give
	the frame back. A piece on a LIMB is turned about the limb's long axis so that its front (-Z) faces the way it should
	(the body's front; a pauldron, away from the chest), since a limb's own roll is whatever the rig made it.

	RIGID pieces are welded to their part. CLOTH is jointed so the clients can sway it (ZombieAnimController):
	    Skirt<i>     a Motor6D "ClothSkirt<i>" from the LowerTorso at the marker SkirtHinge<i>; its gold hem welded to it
	    Cape<i>_0    a Motor6D "ClothCape<i>A" from the UpperTorso at CapeHinge<i>
	    Cape<i>_1    a Motor6D "ClothCape<i>B" from Cape<i>_0 at CapeKnee<i>

	A tool, not game code.
]]

local InsertService = game:GetService("InsertService")

local Garb = {}

Garb.ASSET = 140652163236115

local lab = script.Parent

local M = Enum.Material
local LOOK = {
	Coat = { M.Fabric, Color3.fromRGB(96, 60, 36) },
	Sleeve = { M.Fabric, Color3.fromRGB(96, 60, 36) },
	Skirt = { M.Fabric, Color3.fromRGB(92, 58, 34) },
	Braid = { M.Metal, Color3.fromRGB(196, 150, 70), 0.15 },
	Cuff = { M.Metal, Color3.fromRGB(196, 150, 70), 0.15 },
	SkirtHem = { M.Metal, Color3.fromRGB(186, 142, 64), 0.1 },
	Buckle = { M.Metal, Color3.fromRGB(204, 158, 72), 0.2 },
	Ermine = { M.Fabric, Color3.fromRGB(236, 232, 222) },
	CuffFur = { M.Fabric, Color3.fromRGB(236, 232, 222) },
	ErmineSpots = { M.Fabric, Color3.fromRGB(16, 14, 14) },
	Belt = { M.Leather, Color3.fromRGB(52, 34, 24) },
	Cape = { M.Fabric, Color3.fromRGB(86, 14, 26) },
	VisorDark = { M.SmoothPlastic, Color3.fromRGB(10, 10, 12) },
	VisorGlow = { M.Neon, Color3.fromRGB(150, 196, 255) },
	Aventail = { M.DiamondPlate, Color3.fromRGB(58, 58, 62) },
}
local PLATE = { M.Metal, Color3.fromRGB(44, 46, 50), 0.08 } -- blackened steel

-- which way a piece's front (-Z) should face: "front" (the body's), "out" (away from the chest), or nil (no turn)
local FACING = { Pauldron = "out", Rerebrace = "out", Couter = "front", Vambrace = "front", Cuff = "front", Cuisse = "front", Poleyn = "front", Greave = "front", GreaveRidge = "front" }

function Garb.load(): Instance
	local raw = lab:FindFirstChild("GarbRaw")
	if raw then
		return raw
	end
	-- the newest revision (LoadAsset may hand back a copy it already has)
	local ok, version = pcall(function()
		return InsertService:GetLatestAssetVersionAsync(Garb.ASSET)
	end)
	local m = if ok and version then InsertService:LoadAssetVersion(version) else InsertService:LoadAsset(Garb.ASSET)
	m.Name = "GarbRaw"
	m.Parent = lab
	return m
end

local function frameOf(raw: Instance): CFrame
	local m0 = (raw:FindFirstChild("Garb_M0", true) :: BasePart).Position
	local x = ((raw:FindFirstChild("Garb_MX", true) :: BasePart).Position - m0).Unit
	local yr = (raw:FindFirstChild("Garb_MY", true) :: BasePart).Position - m0
	local y = (yr - x * yr:Dot(x)).Unit
	return CFrame.fromMatrix(m0, x, y, x:Cross(y))
end

local function look(p: BasePart, piece: string)
	local base = string.gsub(piece, "%d+.*$", "")
	local l = LOOK[piece] or LOOK[base] or PLATE
	if string.sub(piece, 1, 4) == "Cape" then
		l = LOOK.Cape
	end
	p.Material = l[1]
	p.Color = l[2]
	p.Reflectance = l[3] or 0
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("Weld")
	w.Name = "GarbWeld"
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
	w.Parent = b
end

-- a hinge at `at` (in a's space) whose axes are those of `ref` (the torso the cloth hangs from: its X is the swing
-- axis for every piece, whatever turn the importer gave the meshes); b keeps where it is
local function hinge(name: string, a: BasePart, b: BasePart, at: Vector3, ref: BasePart)
	local joint = CFrame.new(a.CFrame * at) * ref.CFrame.Rotation
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = a
	m.Part1 = b
	m.C0 = a.CFrame:ToObjectSpace(joint)
	m.C1 = b.CFrame:ToObjectSpace(joint)
	m.Parent = b
end

-- the turn about a limb's X that brings local -Z nearest `want` (world)
local function roll(part: BasePart, want: Vector3): CFrame
	local cf = part.CFrame
	local x = cf.RightVector
	local w = want - x * want:Dot(x)
	if w.Magnitude < 1e-3 then
		return CFrame.new()
	end
	w = w.Unit
	local front = -cf.LookVector
	local angle = math.atan2(x:Dot(front:Cross(w)), front:Dot(w))
	return CFrame.Angles(angle, 0, 0)
end

function Garb.dress(model: Model, body: string): number
	local raw = Garb.load()
	local f = frameOf(raw)
	local root = (model :: any).HumanoidRootPart :: BasePart
	local chest = (model :: any).UpperTorso :: BasePart
	local placed: { [string]: BasePart } = {}
	local hinges: { [string]: Vector3 } = {}
	local folder = Instance.new("Model")
	folder.Name = "Garb"
	folder.Parent = model
	local count = 0
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") then
			local partName, piece = string.match(d.Name, "^" .. body .. "_(%w+)__([%w_]+)$")
			if partName and piece then
				local target = model:FindFirstChild(partName)
				if target and target:IsA("BasePart") then
					local rel = f:ToObjectSpace(d.CFrame)
					if string.find(piece, "Hinge") or string.find(piece, "Knee") then
						hinges[partName .. "." .. piece] = rel.Position
					else
						local turn = CFrame.new()
						local facing = FACING[piece]
						if facing == "front" then
							turn = roll(target, -root.CFrame.LookVector)
						elseif facing == "out" then
							local out = target.Position - chest.Position
							turn = roll(target, out)
						end
						local p = d:Clone()
						p.Name = piece
						p.CFrame = target.CFrame * turn * rel
						look(p, piece)
						p.Parent = folder
						placed[partName .. "." .. piece] = p
						count += 1
					end
				end
			end
		end
	end
	-- joints: cloth hinged, everything else welded
	for key, p in placed do
		local partName, piece = string.match(key, "^(%w+)%.([%w_]+)$")
		local target = (model :: any)[partName] :: BasePart
		local skirt = string.match(piece, "^Skirt(%d+)$")
		local hem = string.match(piece, "^SkirtHem(%d+)$")
		local cape, seg = string.match(piece, "^Cape(%d+)_(%d)$")
		if skirt then
			hinge("ClothSkirt" .. skirt, target, p, hinges[partName .. ".SkirtHinge" .. skirt] or Vector3.zero, target)
		elseif hem then
			local panel = placed[partName .. ".Skirt" .. hem]
			weld(panel or target, p)
		elseif cape and seg == "0" then
			hinge("ClothCape" .. cape .. "A", target, p, hinges[partName .. ".CapeHinge" .. cape] or Vector3.zero, target)
		elseif cape and seg == "1" then
			local upper = placed[partName .. ".Cape" .. cape .. "_0"]
			local knee = hinges[partName .. ".CapeKnee" .. cape]
			if upper and knee then
				-- the knee point is in the chest's frame: into the upper piece's
				local at = upper.CFrame:PointToObjectSpace(target.CFrame * knee)
				hinge("ClothCape" .. cape .. "B", upper, p, at, target)
			else
				weld(target, p)
			end
		elseif piece == "CapeTrim" then
			p:Destroy()
		else
			weld(target, p)
		end
	end
	-- what the garb covers is hidden (the block torso's corners came through the rounded coat and cuirass); hidden, not
	-- removed: the joints and what hangs from them stay
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Parent == model then
			local n = d.Name
			if n == "UpperTorso" or n == "LowerTorso" or string.match(n, "^Blotch") or string.find(n, "ShoulderBall") or string.find(n, "ElbowBall") then
				d.Transparency = 1
			end
		end
	end
	return count
end

return Garb
