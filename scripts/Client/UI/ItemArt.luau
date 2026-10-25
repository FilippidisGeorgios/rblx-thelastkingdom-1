--!strict
--[[
	ItemArt
	A picture of an item, drawn live: a ViewportFrame with the item's 3D model turned a little toward the
	viewer. The models are the AI-generated meshes listed in configs/ItemArt (a mesh id and a texture id per
	item, so nothing has to be copied between places); an item without one is drawn from its `Look` in
	configs/Items (a block, a ball, a disc, a bar), so there is never a hole in a list.

	Meshes are fetched once per item and cloned for every use. Nothing here is the server's business.

	Location: StarterPlayerScripts.Client.UI.ItemArt (a library).
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ItemArt = {}

type Template = { part: BasePart?, ready: boolean, waiting: { (BasePart) -> () } }

local templates: { [string]: Template } = {}

-- Every page shares one picture.
local function keyFor(itemId: string): string
	if itemId:sub(1, 5) == "page_" then
		return "page"
	end
	return itemId
end

-- A stand-in drawn from the item's `Look`, for an item that has no mesh (yet).
local function fromLook(itemId: string): BasePart
	local def = Config.get("Items")[itemId]
	local look = def and def.Look
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if look then
		part.Color = look.Colour
		part.Material = look.Material
		part.Size = look.Size
		if look.Shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif look.Shape == "Disc" then
			part.Shape = Enum.PartType.Cylinder
		end
	else
		part.Color = Color3.fromRGB(150, 130, 100)
		part.Size = Vector3.new(0.8, 0.8, 0.8)
	end
	return part
end

-- Scales a part so that its longest side is one stud: every picture is then framed the same way.
local function normalise(part: BasePart)
	local size = part.Size
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		part.Size = size / longest
	end
end

local function load(itemId: string, key: string, template: Template)
	local art = Config.get("ItemArt").Art[key]
	local part: BasePart? = nil
	if art then
		local ok, mesh = pcall(function()
			return AssetService:CreateMeshPartAsync(art.Mesh)
		end)
		if ok and mesh then
			mesh.Anchored = true
			mesh.CanCollide = false
			if art.Texture then
				pcall(function()
					mesh.TextureID = art.Texture
				end)
			end
			part = mesh
		end
	end
	local made = part or fromLook(itemId)
	normalise(made)
	template.part = made
	template.ready = true
	local waiting = template.waiting
	template.waiting = {}
	for _, callback in waiting do
		callback(made:Clone())
	end
end

-- Calls back with a fresh clone of the item's model (now, or when its mesh has come in).
local function get(itemId: string, callback: (BasePart) -> ())
	local key = keyFor(itemId)
	local template = templates[key]
	if not template then
		template = { part = nil, ready = false, waiting = {} }
		templates[key] = template
		table.insert(template.waiting, callback)
		task.spawn(load, itemId, key, template)
		return
	end
	if template.ready and template.part then
		callback(template.part:Clone())
	else
		table.insert(template.waiting, callback)
	end
end

export type Props = {
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	-- Zoom: 1 frames the item as it is; above 1 is closer.
	Zoom: number?,
}

-- The picture, as a ViewportFrame inside `Props.Parent`. It fills in a moment later when the mesh arrives.
function ItemArt.mount(itemId: string, props: Props): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Art"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = props.Size or UDim2.fromOffset(84, 84)
	viewport.Position = props.Position or UDim2.fromScale(0, 0)
	viewport.AnchorPoint = props.AnchorPoint or Vector2.zero
	viewport.LayoutOrder = props.LayoutOrder or 0
	viewport.Ambient = Color3.fromRGB(150, 128, 102)
	viewport.LightColor = Color3.fromRGB(255, 238, 205)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	viewport.ZIndex = 4

	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	local zoom = props.Zoom or 1
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.35, 3.4 / zoom), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Parent = props.Parent

	get(itemId, function(part: BasePart)
		if not viewport.Parent then
			return
		end
		local art = Config.get("ItemArt").Art[keyFor(itemId)]
		local tilt = if art and art.Tilt then art.Tilt else Vector3.new(14, -38, 0)
		part.CFrame = CFrame.Angles(math.rad(tilt.X), math.rad(tilt.Y), math.rad(tilt.Z))
		part.Parent = viewport
	end)

	return viewport
end

return ItemArt
