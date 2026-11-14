--[[
	Booth (2026-11-14): a small closed, evenly lit room high above the map for CLOSE-UPS (a hand round a haft, a helm, a
	crown on a head), where the Showroom is for a whole line of figures. Grey walls, six lights round the subject, the
	place's ambient lifted while it stands (put back by Booth.clear, the same TLK_Orig_* way as the Showroom).

	    local Booth = require(ServerStorage.ZombieLab.Booth)
	    local m = Booth.stand(model)            -- puts the model in the booth (a copy is up to you)
	    local cam, look = Booth.view(part, Vector3.new(1, 0.2, -1), 2.5)   -- a camera 2.5 studs off `part`, from that side
	    -- then screen_capture(cam, look)
	    Booth.clear()

	A tool, not game code.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Booth = {}

Booth.AT = Vector3.new(-3000, 2600, -3000)
local PROPS = { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "ClockTime", "FogEnd", "FogStart" }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function lift(on: boolean)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if on then
		if not Lighting:GetAttribute("TLK_Booth_Saved") then
			for _, k in PROPS do
				Lighting:SetAttribute("TLK_Booth_" .. k, (Lighting :: any)[k])
			end
			if atmo then
				Lighting:SetAttribute("TLK_Booth_AtmoDensity", atmo.Density)
			end
			Lighting:SetAttribute("TLK_Booth_Saved", true)
		end
		Lighting.Ambient = Color3.fromRGB(104, 104, 110)
		Lighting.OutdoorAmbient = Color3.fromRGB(104, 104, 110)
		Lighting.Brightness = 1.2
		Lighting.ExposureCompensation = -0.3
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
		Lighting.ClockTime = 13
		if atmo then
			atmo.Density = 0
		end
	elseif Lighting:GetAttribute("TLK_Booth_Saved") then
		for _, k in PROPS do
			local v = Lighting:GetAttribute("TLK_Booth_" .. k)
			if v ~= nil then
				(Lighting :: any)[k] = v
			end
			Lighting:SetAttribute("TLK_Booth_" .. k, nil)
		end
		if atmo then
			local d = Lighting:GetAttribute("TLK_Booth_AtmoDensity")
			if d then
				atmo.Density = d
			end
		end
		Lighting:SetAttribute("TLK_Booth_AtmoDensity", nil)
		Lighting:SetAttribute("TLK_Booth_Saved", nil)
	end
end

function Booth.clear()
	local old = Workspace:FindFirstChild("ZombieBooth")
	if old then
		old:Destroy()
	end
	lift(false)
end

function Booth.build(): Model
	local old = Workspace:FindFirstChild("ZombieBooth")
	if old then
		return old :: Model
	end
	lift(true)
	local folder = Instance.new("Model")
	folder.Name = "ZombieBooth"
	folder.Parent = Workspace
	local c = Booth.AT
	local grey = Color3.fromRGB(70, 70, 74)
	part(folder, "Floor", Vector3.new(40, 1, 40), CFrame.new(c + Vector3.new(0, -0.5, 0)), Color3.fromRGB(58, 56, 56))
	part(folder, "Ceiling", Vector3.new(40, 1, 40), CFrame.new(c + Vector3.new(0, 16, 0)), grey)
	for _, s in { { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, -20 } } do
		part(folder, "Wall", Vector3.new(if s[1] ~= 0 then 1 else 40, 16, if s[2] ~= 0 then 1 else 40), CFrame.new(c + Vector3.new(s[1], 8, s[2])), grey)
	end
	local lights = {
		{ Vector3.new(-6, 7, -7), Color3.fromRGB(255, 236, 214), 1.6 },
		{ Vector3.new(7, 6, -6), Color3.fromRGB(230, 236, 255), 1.2 },
		{ Vector3.new(0, 9, 6), Color3.fromRGB(190, 206, 255), 1.3 },
		{ Vector3.new(0, 2, -7), Color3.fromRGB(255, 244, 230), 0.6 },
		{ Vector3.new(-7, 3, 5), Color3.fromRGB(220, 220, 230), 0.6 },
		{ Vector3.new(7, 12, 2), Color3.fromRGB(255, 255, 255), 0.7 },
	}
	for i, l in lights do
		local a = part(folder, "Light" .. i, Vector3.one * 0.3, CFrame.new(c + l[1]), l[2])
		a.Transparency = 1
		local pl = Instance.new("PointLight")
		pl.Color = l[2]
		pl.Brightness = l[3] * 1.7
		pl.Range = 26
		pl.Shadows = false
		pl.Parent = a
	end
	return folder
end

-- Stands `model` in the booth (feet on the floor, facing -Z, toward a camera at lower Z), the root anchored.
function Booth.stand(model: Model, yaw: number?): Model
	local folder = Booth.build()
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and not model.PrimaryPart then
		model.PrimaryPart = root :: BasePart
	end
	model.Parent = folder
	local at = CFrame.new(Booth.AT + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	model:PivotTo(at)
	local low = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			local cf, s = d.CFrame, d.Size
			local ext = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			low = math.min(low, cf.Position.Y - ext)
		end
	end
	model:PivotTo(at + Vector3.new(0, Booth.AT.Y - low, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = (d == root)
		end
	end
	return model
end

-- A camera `dist` studs from `target` (a part or a point), on the side `from` points to (world directions; -Z is the
-- front of a body standing in the booth). Returns the two arrays screen_capture wants.
function Booth.view(target: BasePart | Vector3, from: Vector3, dist: number): ({ number }, { number })
	local p = if typeof(target) == "Vector3" then target else (target :: BasePart).Position
	local cam = p + from.Unit * dist
	return { cam.X, cam.Y, cam.Z }, { p.X, p.Y, p.Z }
end

return Booth
