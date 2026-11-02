--[[
	DressUndeadRot — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE.
	Dresses every body in `ServerStorage.Assets.Undead` in the stuff of the dead (2026-11-03, the developer: "change the
	material of their clothes, so they look more easily like zombies"). The plain Fabric read as clean knitted wool.

	Three materials, made with `generate_material` and kept in MaterialService (each with three variations):
	  RotCloth    filthy rotten linen: grave dirt, old brown blood, frayed holes, mildew        (on Fabric)
	  RotSkin     dead skin: mottled, bruised, dark veins, small sores                          (on Concrete, the skin)
	  RotLeather  cracked, peeling, mud-caked leather                                           (on boots and belts)
	One variation of each per body, so a body's clothes are of one cloth; the colours the bodies already have are kept (a
	variant is tinted by the part's colour). Metal, glass and the burned one's cracked lava are not touched.

	Run again, it re-rolls the variations. NOTE: a tool, not game code. The result lives in the place.
]]

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local variants: { [string]: { string } } = {}
for _, v in MaterialService:GetDescendants() do
	if v:IsA("MaterialVariant") then
		local base = v.Name:gsub("%d+$", "")
		if base == "RotCloth" or base == "RotSkin" or base == "RotLeather" then
			v.StudsPerTile = if base == "RotSkin" then 2.5 else 3
			variants[base] = variants[base] or {}
			table.insert(variants[base], v.Name)
		end
	end
end
assert(variants.RotCloth and variants.RotSkin and variants.RotLeather, "the Rot materials are not in MaterialService")

local rng = Random.new(11)
local function pick(base: string): string
	local list = variants[base]
	return list[rng:NextInteger(1, #list)]
end

local BOOT = { LeftFoot = true, RightFoot = true, LeftToe = true, RightToe = true, LeftBootTop = true, RightBootTop = true }
local report = {}
for _, model in ServerStorage.Assets.Undead:GetChildren() do
	if model:IsA("Model") then
		local cloth, skin, leather = pick("RotCloth"), pick("RotSkin"), pick("RotLeather")
		local n = 0
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				if BOOT[p.Name] and (p.Material == Enum.Material.Fabric or p.Material == Enum.Material.Leather) then
					p.Material = Enum.Material.Leather
					p.MaterialVariant = leather
					n += 1
				elseif p.Material == Enum.Material.Fabric then
					p.MaterialVariant = cloth
					n += 1
				elseif p.Material == Enum.Material.Concrete then
					p.MaterialVariant = skin
					n += 1
				elseif p.Material == Enum.Material.Leather then
					p.MaterialVariant = leather
					n += 1
				end
			end
		end
		table.insert(report, ("%s: %d parts"):format(model.Name, n))
	end
end
return report
