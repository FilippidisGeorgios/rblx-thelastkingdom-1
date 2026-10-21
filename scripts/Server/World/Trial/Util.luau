--!strict
--[[
	Trial.Util
	The small things every task module needs: finding scenery by name, putting a
	prompt on it, making a flame. Plain functions; no state, no boot.

	Location: ServerScriptService.Server.World.Trial.Util
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Util = {}

--[[
	Scenery by dotted path under Workspace.Gameplay.Battleground, e.g.
	"Decorations.Area4.Chapel.Altar". Returns nil (and says nothing: the caller
	knows what it was looking for and logs it) when any step is missing.
]]
function Util.find(path: string): Instance?
	local node: Instance? = Workspace:FindFirstChild("Gameplay")
	node = node and node:FindFirstChild("Battleground")
	for segment in string.gmatch(path, "[^%.]+") do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	return node
end

function Util.position(instance: Instance): Vector3
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return (instance :: BasePart).Position
end

--[[
	A prompt on its own invisible anchor part, so the scenery it belongs to is
	never touched. `at` is where the anchor sits.
]]
function Util.prompt(
	parent: Instance,
	at: Vector3,
	name: string,
	action: string,
	object: string,
	hold: number,
	distance: number
): ProximityPrompt
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = at
	anchor.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	return prompt
end

--[[
	A flame: the legacy Fire object (cheap, replicates as a property set) and a
	light the distance thinner (DetailLodController) can switch off. Returns both
	so a caller can shrink them.
]]
function Util.flame(parent: BasePart, size: number, lightRange: number): (Fire, PointLight)
	local fire = Instance.new("Fire")
	fire.Name = "Flame"
	fire.Size = size
	fire.Heat = size * 0.8
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(200, 60, 20)
	fire.Parent = parent

	local light = Instance.new("PointLight")
	light.Name = "FlameLight"
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = lightRange
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = parent
	CollectionService:AddTag(light, "TLK_Lod")
	return fire, light
end

return Util
