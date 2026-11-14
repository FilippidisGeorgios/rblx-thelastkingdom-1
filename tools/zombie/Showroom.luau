--!nonstrict
--[[
	zombie/Showroom — a small photo studio for the dead, built far away from the map (Edit mode, Forgotten Lands place).

	  Showroom.build()                       makes Workspace.ZombieShowroom (floor, back wall, three lights), returns it
	  Showroom.lineup(models, rowIndex)      stands the given figures in a row, feet on the floor, facing the camera
	  Showroom.clear()                       removes the whole thing
	  Showroom.camera(rowIndex, n)           the camera position and look-at point that frame a row of n figures

	The figures face -Z (a Humanoid's front); the camera stands at lower Z and looks toward +Z.
	A tool, not game code: it is loaded from the sync bundle (tools/mksync.js) and never reaches the players.
]]

local Workspace = game:GetService("Workspace")

local Showroom = {}

local ORIGIN = Vector3.new(4000, 500, 4000) -- far from the map and above everything
Showroom.ORIGIN = ORIGIN
local SPACING = 4.6
local ROW_GAP = 15

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function light(parent, at, color, brightness, range, name)
	local anchor = part(parent, name, Vector3.new(0.4, 0.4, 0.4), CFrame.new(at), color, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false -- shadowed lights do not render in Edit mode here (found 2026-11-14)
	l.Parent = anchor
	return anchor
end

-- The place's night is too dark to judge a face, so the showroom lifts the ambient light and thins the fog while it stands,
-- and puts every number back on clear(). The originals are kept as attributes (TLK_Orig_*) so a crash cannot lose them.
local Lighting = game:GetService("Lighting")
local LIGHT_PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ClockTime" }

local function stageLighting(on: boolean)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if on then
		if Lighting:GetAttribute("TLK_Orig_Saved") then
			return -- already lifted: the originals are safe
		end
		for _, k in LIGHT_PROPS do
			Lighting:SetAttribute("TLK_Orig_" .. k, (Lighting :: any)[k])
		end
		if atmo then
			Lighting:SetAttribute("TLK_Orig_AtmoDensity", atmo.Density)
			Lighting:SetAttribute("TLK_Orig_AtmoOffset", atmo.Offset)
		end
		Lighting:SetAttribute("TLK_Orig_Saved", true)
		Lighting.Ambient = Color3.fromRGB(64, 66, 76)
		Lighting.OutdoorAmbient = Color3.fromRGB(64, 66, 76)
		Lighting.Brightness = 1
		Lighting.ExposureCompensation = 0.4
		if atmo then
			atmo.Density = 0.05
			atmo.Offset = 0
		end
	elseif Lighting:GetAttribute("TLK_Orig_Saved") then
		for _, k in LIGHT_PROPS do
			local v = Lighting:GetAttribute("TLK_Orig_" .. k)
			if v ~= nil then
				(Lighting :: any)[k] = v
			end
			Lighting:SetAttribute("TLK_Orig_" .. k, nil)
		end
		if atmo then
			atmo.Density = Lighting:GetAttribute("TLK_Orig_AtmoDensity") or atmo.Density
			atmo.Offset = Lighting:GetAttribute("TLK_Orig_AtmoOffset") or atmo.Offset
		end
		Lighting:SetAttribute("TLK_Orig_AtmoDensity", nil)
		Lighting:SetAttribute("TLK_Orig_AtmoOffset", nil)
		Lighting:SetAttribute("TLK_Orig_Saved", nil)
	end
end

function Showroom.clear()
	local old = Workspace:FindFirstChild("ZombieShowroom")
	if old then
		old:Destroy()
	end
	stageLighting(false)
end

function Showroom.build(rows: number?)
	Showroom.clear()
	rows = rows or 1
	stageLighting(true)
	local folder = Instance.new("Model")
	folder.Name = "ZombieShowroom"
	folder.Parent = Workspace

	local depth = 20 + (rows - 1) * ROW_GAP
	-- floor: dark, wet-looking flagstones; wall: old stone with a lower band so the figures read against it
	part(folder, "Floor", Vector3.new(140, 2, depth + 30), CFrame.new(ORIGIN + Vector3.new(0, -1, depth / 2 - 6)), Color3.fromRGB(66, 64, 64), Enum.Material.Slate)
	part(folder, "Wall", Vector3.new(140, 40, 2), CFrame.new(ORIGIN + Vector3.new(0, 20, depth + 6)), Color3.fromRGB(58, 54, 54), Enum.Material.Slate)
	part(folder, "WallBand", Vector3.new(140, 7, 0.6), CFrame.new(ORIGIN + Vector3.new(0, 12, depth + 4.7)), Color3.fromRGB(80, 72, 66), Enum.Material.Cobblestone)
	-- three lights: a warm key from the front-left, a cold rim from behind, a faint cool fill from the right
	for r = 0, rows - 1 do
		local z = r * ROW_GAP
		light(folder, ORIGIN + Vector3.new(-18, 11, z - 9), Color3.fromRGB(255, 176, 108), 1.0, 70, "Key" .. r)
		light(folder, ORIGIN + Vector3.new(14, 11, z - 9), Color3.fromRGB(255, 196, 140), 0.8, 70, "Key2_" .. r)
		light(folder, ORIGIN + Vector3.new(0, 9, z + 7), Color3.fromRGB(120, 160, 230), 1.6, 60, "Rim" .. r)
		light(folder, ORIGIN + Vector3.new(0, 4, z - 12), Color3.fromRGB(150, 170, 210), 0.45, 60, "Fill" .. r)
	end
	return folder
end

-- The lowest visible point of a model (parts you can see), measured along world Y.
local function lowestY(model: Model): number
	local low = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			local cf, s = d.CFrame, d.Size
			local ext = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			low = math.min(low, cf.Position.Y - ext)
		end
	end
	return low
end

-- Stands the figures in a row. `models` is { Model }, centred on x = 0. rowIndex 0 is the front row.
function Showroom.lineup(models: { Model }, rowIndex: number?)
	local folder = Workspace:FindFirstChild("ZombieShowroom")
	assert(folder, "Showroom.build() first")
	local z = (rowIndex or 0) * ROW_GAP
	local n = #models
	for i, m in models do
		local x = ((n + 1) / 2 - i) * SPACING -- the camera looks toward +Z, so +X is on its left
		local root = m:FindFirstChild("HumanoidRootPart")
		if root and not m.PrimaryPart then
			m.PrimaryPart = root
		end
		m.Parent = folder
		-- face the camera (-Z front, camera at lower Z), then drop the feet to the floor
		local yaw = math.rad(if i % 2 == 0 then 24 else -20) -- a three-quarter turn, alternating, so the backs (cloaks, hoods) show
		local at = CFrame.new(ORIGIN + Vector3.new(x, 3, z)) * CFrame.Angles(0, yaw, 0)
		m:PivotTo(at)
		local low = lowestY(m)
		m:PivotTo(at + Vector3.new(0, ORIGIN.Y - low, 0))
		-- an anchored root only holds the body still; the rest hangs from Motor6Ds
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = (d == root)
			end
		end
	end
end

-- The capture is about 2.67 : 1 and the camera's field of view is 70 degrees tall, so it sees 3.67 studs across per stud of distance.
-- A theme's mood: the colour of the key, the second key, the rim and the fill, and the ambient light.
function Showroom.mood(m: { [string]: any })
	local folder = Workspace:FindFirstChild("ZombieShowroom")
	if not folder then
		return
	end
	local function set(name: string, color: Color3?, k: number?)
		local a = folder:FindFirstChild(name)
		local l = a and a:FindFirstChildOfClass("PointLight")
		if l then
			if color then
				l.Color = color
			end
			if k then
				l.Brightness = l.Brightness * k
			end
		end
	end
	set("Key0", m.key, m.keyK)
	set("Key2_0", m.key2 or m.key, m.keyK)
	set("Rim0", m.rim, m.rimK)
	set("Fill0", m.fill, m.fillK)
	if m.ambient then
		Lighting.Ambient = m.ambient
		Lighting.OutdoorAmbient = m.ambient
	end
end

function Showroom.camera(rowIndex: number?, n: number?, closeness: number?)
	local z = (rowIndex or 0) * ROW_GAP
	local width = ((n or 8) - 1) * SPACING + 5
	local dist = width / 3.67 * 1.4 * (closeness or 1)
	local pos = ORIGIN + Vector3.new(0, 4.4, z - dist)
	local look = ORIGIN + Vector3.new(0, 3.1, z)
	return pos, look
end

return Showroom
