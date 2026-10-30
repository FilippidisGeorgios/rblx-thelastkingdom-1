--!strict
--[[
	CrawlerBody.spec
	A crawler is a standing body with its legs taken away and its torso laid down. The legs are found by following the
	joints out from the thighs without crossing into the trunk; the pose is put where the animation clips will still
	read as they were written; and the unit's numbers are the ones the shared attack clip expects.

	Location: TestService.Tests.CrawlerBody.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CrawlerBody = require(ServerScriptService.Server.Domain.CrawlerBody)
local ZombieAnims = require(ReplicatedStorage.Shared.Anim.ZombieAnims)
local Enemies: any = require(ReplicatedStorage.Config.Enemies)

-- A small standing body with the same joints, names and kinds of weld as the real ones (and a PART called "Neck" as
-- well as the joint, which the real bodies have).
local function body(): Model
	local model = Instance.new("Model")
	local function part(name: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(1, 1, 1)
		p.Anchored = false
		p.Parent = model
		return p
	end
	local function motor(name: string, a: Part, b: Part, c0: CFrame?)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = a
		m.Part1 = b
		m.C0 = c0 or CFrame.new()
		m.Parent = b
	end
	local function weld(a: Part, b: Part)
		local w = Instance.new("WeldConstraint")
		w.Part0 = a
		w.Part1 = b
		w.Parent = b
	end

	local root = part("HumanoidRootPart")
	local lower = part("LowerTorso")
	local upper = part("UpperTorso")
	local head = part("Head")
	local neckPart = part("Neck") -- a part, as in the real bodies
	local lShoulderArm = part("LeftUpperArm")
	local rShoulderArm = part("RightUpperArm")
	motor("Root", root, lower, CFrame.new(0, 0.13, 0))
	motor("Waist", lower, upper)
	motor("Neck", upper, head, CFrame.new(0, 0.77, 0))
	motor("LeftShoulder", upper, lShoulderArm, CFrame.new(-1, 0.6, 0))
	motor("RightShoulder", upper, rShoulderArm, CFrame.new(1, 0.6, 0))
	weld(head, neckPart)

	-- legs: thigh, shin, foot (joints), a boot (weld) and a knee ball (weld to the shin)
	for _, side in { "Left", "Right" } do
		local thigh = part(side .. "UpperLeg")
		local shin = part(side .. "LowerLeg")
		local foot = part(side .. "Foot")
		local boot = part(side .. "BootTop")
		local knee = part(side .. "KneeBall")
		motor(side .. "Hip", lower, thigh, CFrame.new(if side == "Left" then -0.45 else 0.45, -0.2, 0))
		motor(side .. "Knee", thigh, shin)
		motor(side .. "Ankle", shin, foot)
		weld(foot, boot)
		weld(shin, knee)
	end

	-- things on the trunk, which must stay: a belt on the hips and a pouch on the belt
	local belt = part("Belt")
	local pouch = part("Pouch")
	weld(lower, belt)
	weld(belt, pouch)

	model.PrimaryPart = root
	return model
end

local function names(list: { Instance }): { string }
	local out = {}
	for _, i in list do
		table.insert(out, i.Name)
	end
	table.sort(out)
	return out
end

return function(t: any)
	t.test("the legs are everything joined to a thigh, boots and knee balls too, and nothing of the trunk", function()
		local model = body()
		local legs = names(CrawlerBody.legParts(model))
		local expect = {
			"LeftBootTop", "LeftFoot", "LeftKneeBall", "LeftLowerLeg", "LeftUpperLeg",
			"RightBootTop", "RightFoot", "RightKneeBall", "RightLowerLeg", "RightUpperLeg",
		}
		assert(#legs == #expect, "ten leg parts: " .. table.concat(legs, ","))
		for i, name in expect do
			assert(legs[i] == name, "expected " .. name .. " at " .. i .. ", got " .. tostring(legs[i]))
		end
		model:Destroy()
	end)

	t.test("making a crawler removes the legs and keeps the belt, the pouch, the arms, the head and the root", function()
		local model = body()
		local removed = CrawlerBody.make(model)
		assert(removed == 10, "ten parts removed: " .. removed)
		for _, name in { "LeftUpperLeg", "RightFoot", "LeftBootTop", "RightKneeBall" } do
			assert(model:FindFirstChild(name) == nil, name .. " is gone")
		end
		for _, name in { "HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "Neck", "Belt", "Pouch", "LeftUpperArm", "RightUpperArm" } do
			assert(model:FindFirstChild(name) ~= nil, name .. " stays")
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") then
				assert(d.Part0 ~= nil and d.Part1 ~= nil, d.Name .. " is not left holding nothing")
			end
		end
		assert(model:GetAttribute("Crawler") == true, "marked as a crawler")
		model:Destroy()
	end)

	t.test("the body is laid down by the Root joint's C1, so the clips' own shifts still go the way they were meant", function()
		local model = body()
		local root = model.LowerTorso:FindFirstChild("Root") :: Motor6D
		local c0, c1 = root.C0, root.C1
		CrawlerBody.make(model)
		assert(root.C0.Y < c0.Y, "dropped toward the ground")
		local pitched = c1:ToObjectSpace(root.C1)
		local rx = pitched:ToEulerAnglesXYZ()
		assert(math.abs(math.deg(rx) - 64) < 1, "pitched about X by the config's angle: " .. math.deg(rx))
		model:Destroy()
	end)

	t.test("the Neck JOINT is lifted, not the part that shares its name; the shoulders turn out to reach", function()
		local model = body()
		local neckJoint = model.Head:FindFirstChild("Neck") :: Motor6D
		local neckPart = model:FindFirstChild("Neck") :: Part
		local before, partBefore = neckJoint.C0, neckPart.CFrame
		local shoulder = model.LeftUpperArm:FindFirstChild("LeftShoulder") :: Motor6D
		local shoulderBefore = shoulder.C0
		CrawlerBody.make(model)
		assert(neckJoint.C0 ~= before, "the neck joint turned")
		assert(neckPart.CFrame == partBefore, "the neck PART was not touched")
		assert(shoulder.C0 ~= shoulderBefore, "the shoulder turned")
		model:Destroy()
	end)

	t.test("a model with no Root joint is left exactly as it was", function()
		local model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Name = "LeftUpperLeg"
		p.Parent = model
		assert(CrawlerBody.make(model) == 0, "nothing removed")
		assert(model:FindFirstChild("LeftUpperLeg") ~= nil, "nothing destroyed")
		assert(model:GetAttribute("Crawler") == nil, "not marked")
		model:Destroy()
	end)

	t.test("the crawler unit: low health, its own body from the standing dead, and the shambler's timings (they share a clip)", function()
		local crawler, shambler = Enemies.undead_crawler, Enemies.undead_shambler
		assert(crawler and crawler.Crawler == true, "it is a crawler")
		assert(crawler.MaxHealth < shambler.MaxHealth, "it breaks easily")
		assert(crawler.Tier == "Standard" and crawler.Faction == "Enemies", "an ordinary hostile")
		for _, key in { "Windup", "Strike", "Recover" } do
			assert(crawler.AI[key] == shambler.AI[key], key .. " matches the shambler's: the attack clip is shared")
		end
		assert(ZombieAnims.KIND.undead_crawler == ZombieAnims.KIND.undead_shambler, "it plays the shambler's attack")
		assert(#crawler.Body > 0, "it wears a standing body")
	end)
end
