--[[
	Arms (2026-11-14): turns the uploaded Blender model of the arms (asset arms_v1, tools/blender/make_arms.py) into a
	library, ServerStorage.Assets.Arms, one Model per item:

	    Spear, BoarSpear, KnightSword, KingSword, Shield, Crown, Antler

	Each item's three marker meshes (<item>_M0, _MX, _MY: its origin, one stud along its +X and along its +Y) give its
	frame back whatever the importer did; every mesh is placed in that frame, so an item's Model sits with its own frame
	at the world origin. An invisible "Handle" at the origin carries the Attachments:
	    Grip       the frame the holding fist takes (X to the business end, Y the true edge): tools/zombie/Grip.hold
	    Grip2      where the second hand goes (spears, the knight's sword): ZombieAnimController
	    BladeBase / BladeTip   the King's sword: the ends of its glow and its trail
	The look (Roblox material, colour, shine) is set per mesh here: the meshes come untextured.

	ServerStorage.Assets is claimed by no Rojo project (CLAUDE.md): it survives a reconnect.
	A tool, not game code.
]]

local ServerStorage = game:GetService("ServerStorage")

local Arms = {}

local M = Enum.Material
local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- name -> { material, colour, reflectance?, transparency? }
Arms.LOOK = {
	Spear_Shaft = { M.Wood, c(118, 88, 60) },
	Spear_Butt = { M.Metal, c(56, 54, 52) },
	Spear_Wrap = { M.Leather, c(68, 44, 30) },
	Spear_Socket = { M.Metal, c(80, 78, 76) },
	Spear_Head = { M.Metal, c(152, 152, 156), 0.06 },
	BoarSpear_Shaft = { M.Wood, c(70, 50, 36) },
	BoarSpear_Butt = { M.CorrodedMetal, c(58, 56, 54) },
	BoarSpear_Wrap = { M.Leather, c(54, 36, 26) },
	BoarSpear_Socket = { M.CorrodedMetal, c(62, 60, 58) },
	BoarSpear_Binding = { M.Leather, c(60, 40, 28) },
	BoarSpear_Head = { M.Metal, c(70, 68, 66), 0.04 },
	KnightSword_Grip = { M.Leather, c(38, 28, 22) },
	KnightSword_Pommel = { M.Metal, c(62, 62, 64), 0.04 },
	KnightSword_Guard = { M.Metal, c(62, 62, 64), 0.04 },
	KnightSword_Blade = { M.Metal, c(138, 140, 146), 0.08 },
	KingSword_Grip = { M.Metal, c(186, 142, 64), 0.12 },
	KingSword_Pommel = { M.Metal, c(196, 150, 70), 0.18 },
	KingSword_Guard = { M.Metal, c(196, 150, 70), 0.18 },
	KingSword_Blade = { M.Metal, c(196, 200, 208), 0.22 },
	Shield_Face = { M.SmoothPlastic, c(104, 20, 32), 0.1 },
	Shield_Rim = { M.Metal, c(190, 146, 68), 0.2 },
	Shield_Star = { M.Metal, c(204, 158, 72), 0.25 },
	Shield_Back = { M.Leather, c(68, 44, 30) },
	Crown_Band = { M.Metal, c(196, 150, 70), 0.16 },
	Crown_Gems = { M.Glass, c(128, 12, 26), 0.2, 0.05 },
	Crown_Sapphires = { M.Glass, c(32, 54, 128), 0.2, 0.05 },
	Antler_Right = { M.Wood, c(52, 36, 24) },
}

local ITEMS = { "Spear", "BoarSpear", "KnightSword", "KingSword", "Shield", "Crown", "Antler" }

local function frameOf(raw: Instance, item: string): CFrame?
	local m0 = raw:FindFirstChild(item .. "_M0", true) :: BasePart?
	local mx = raw:FindFirstChild(item .. "_MX", true) :: BasePart?
	local my = raw:FindFirstChild(item .. "_MY", true) :: BasePart?
	if not (m0 and mx and my) then
		return nil
	end
	local o = m0.Position
	local x = (mx.Position - o).Unit
	local yr = my.Position - o
	local y = (yr - x * yr:Dot(x)).Unit
	return CFrame.fromMatrix(o, x, y, x:Cross(y))
end

function Arms.library(raw: Instance): Folder
	local assets = ServerStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ServerStorage
	local lib = assets:FindFirstChild("Arms")
	if lib then
		lib:Destroy()
	end
	lib = Instance.new("Folder")
	lib.Name = "Arms"
	lib.Parent = assets

	for _, item in ITEMS do
		local f = frameOf(raw, item)
		if f then
			local model = Instance.new("Model")
			model.Name = item
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(0.1, 0.1, 0.1)
			handle.Transparency = 1
			handle.CanCollide = false
			handle.CanQuery = false
			handle.CanTouch = false
			handle.Massless = true
			handle.Anchored = false
			handle.CFrame = CFrame.new()
			handle.Parent = model
			model.PrimaryPart = handle
			local grip = Instance.new("Attachment")
			grip.Name = "Grip"
			grip.Parent = handle
			for _, d in raw:GetDescendants() do
				if d:IsA("MeshPart") and string.sub(d.Name, 1, #item + 1) == item .. "_" then
					local suffix = string.sub(d.Name, #item + 2)
					local rel = f:ToObjectSpace(d.CFrame)
					if suffix == "M0" or suffix == "MX" or suffix == "MY" then
						-- a marker: its job is done
					elseif suffix == "G2" or suffix == "B0" or suffix == "B1" then
						local a = Instance.new("Attachment")
						a.Name = if suffix == "G2" then "Grip2" elseif suffix == "B0" then "BladeBase" else "BladeTip"
						a.CFrame = CFrame.new(rel.Position)
						a.Parent = handle
					else
						local p = d:Clone()
						p.CFrame = rel
						p.Anchored = false
						p.CanCollide = false
						p.CanQuery = false
						p.CanTouch = false
						p.Massless = true
						p.CastShadow = true
						local look = Arms.LOOK[d.Name]
						if look then
							p.Material = look[1]
							p.Color = look[2]
							p.Reflectance = look[3] or 0
							p.Transparency = look[4] or 0
						end
						p.Parent = model
						local w = Instance.new("Weld")
						w.Part0 = handle
						w.Part1 = p
						w.C0 = rel
						w.Parent = p
					end
				end
			end
			model.Parent = lib
		end
	end
	return lib
end

-- A copy of an item, at `cf` (its frame there).
function Arms.make(item: string, cf: CFrame?): Model
	local lib = ServerStorage.Assets.Arms
	local m = (lib :: any)[item]:Clone() :: Model
	if cf then
		m:PivotTo(cf)
	end
	return m
end

return Arms
