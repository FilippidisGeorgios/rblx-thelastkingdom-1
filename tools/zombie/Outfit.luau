--[[
	Outfit (2026-11-14): the developer's changes to the dead, applied to the masters in ServerStorage.Assets.Undead.

	    local Outfit = require(lab.Outfit)
	    Outfit.apply("undead_spearman")      -- a copy is rebuilt and put in place of the master (the old one is kept in
	                                         -- ServerStorage.ZombieLab.Backup the first time)
	    Outfit.all()

	What each one does (2026-11-14 brief):
	  undead_spearman  the old 12-stud pole and its pennon go; the new spear (Assets.Arms.Spear, 7.6 studs) is held at
	                   the hip in both hands, point toward a man's chest; both fists closed round the shaft.
	  the_huntsman     the boar spear a little shorter and real (Assets.Arms.BoarSpear), two hands.
	  undead_knight    a smaller hand-and-a-half sword (Assets.Arms.KnightSword) in two hands at the ready.
	  the_king         no bow, no great sword, no plate; a sharp sword in the right hand, the bordeaux heater shield on
	                   the left arm, the crown made to his head (it rests ON it).
	  the rest         whatever a hand holds (the sentinel's sword and shield, the gravedigger's spade, the archer's bow,
	                   the scullion's ladle) is kept, and the fingers are rebuilt round it (tools/zombie/Grip.refit).

	A tool, not game code. Needs ZombieLab (tools/zombie/Reload) and Assets.Arms (tools/zombie/Arms).
]]

local ServerStorage = game:GetService("ServerStorage")

local Outfit = {}

local lab = script.Parent
local Grip = require(lab.Grip)
local Hold = require(lab.Hold)
local Arms = require(lab.Arms)

local function gone(m: Model, names: { string }, patterns: { string }?)
	for _, n in names do
		for _, d in m:GetChildren() do
			if d.Name == n then
				d:Destroy()
			end
		end
	end
	if patterns then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Model") then
				for _, p in patterns do
					if string.match(d.Name, p) then
						d:Destroy()
						break
					end
				end
			end
		end
	end
end

-- Anything left with no joint to the body falls in the game: such parts go.
local function sweep(m: Model)
	local root = m:FindFirstChild("HumanoidRootPart")
	local n: { [Instance]: { Instance } } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0, (d :: any).Part1
			if a and b then
				n[a] = n[a] or {}
				n[b] = n[b] or {}
				table.insert(n[a], b)
				table.insert(n[b], a)
			end
		end
	end
	local seen = { [root] = true }
	local q = { root }
	while #q > 0 do
		local c = table.remove(q)
		for _, o in n[c] or {} do
			if not seen[o] then
				seen[o] = true
				table.insert(q, o)
			end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not seen[d] then
			d:Destroy()
		end
	end
	-- models left empty
	for _, d in m:GetChildren() do
		if d:IsA("Model") and #d:GetChildren() == 0 then
			d:Destroy()
		end
	end
end

local function shoulder(m: Model, side: string): Vector3
	return (m :: any).UpperTorso.CFrame * Vector3.new(if side == "Left" then -1.08 else 1.08, 0.65, 0)
end

-- both hands on a long haft: the right at `rightAt` (root space), the haft along `dir` (root space), the left at Grip2
local function twoHands(m: Model, item: string, rightAt: Vector3, dir: Vector3, grip2: number, rRadius: number, lRadius: number)
	Grip.fist(m, "Right", { radius = rRadius })
	Grip.fist(m, "Left", { radius = lRadius })
	local root = (m :: any).HumanoidRootPart.CFrame
	local along = root:VectorToWorldSpace(dir.Unit)
	local missR = Hold.fistAt(m, "Right", Hold.frame(root * rightAt, along, shoulder(m, "Right")))
	local weapon = Arms.make(item)
	weapon.Name = item
	Grip.hold(m, "Right", weapon, "Grip")
	local g2 = weapon:FindFirstChild("Grip2", true) :: Attachment
	g2.Position = Vector3.new(grip2, 0, 0)
	local g2World = (g2.Parent :: BasePart).CFrame * g2.CFrame
	local missL = Hold.fistAt(m, "Left", Hold.frame(g2World.Position, along, shoulder(m, "Left")))
	return missR, missL
end

Outfit.BUILD = {}

Outfit.BUILD.undead_spearman = function(m: Model)
	gone(m, { "spear_shaft", "spear_head" }, { "^Pennon" })
	return twoHands(m, "Spear", Vector3.new(0.72, -0.2, -0.4), Vector3.new(-0.14, 0.16, -1), 1.55, 0.086, 0.082)
end

Outfit.BUILD.the_huntsman = function(m: Model)
	gone(m, { "SpearShaft", "SpearBlade", "SpearTip", "SpearBar", "SpearWrap" })
	return twoHands(m, "BoarSpear", Vector3.new(0.8, -0.1, -0.45), Vector3.new(-0.12, 0.12, -1), 1.42, 0.1, 0.096)
end

Outfit.BUILD.undead_knight = function(m: Model)
	gone(m, { "SwordGrip", "SwordPommel", "SwordGuard", "SwordQuillonA", "SwordQuillonB", "Blade", "Fuller", "BladeTip", "BladeStain" })
	-- the plough guard: hilt at the belly, the point up at a man's face
	return twoHands(m, "KnightSword", Vector3.new(0.35, 0.0, -1.0), Vector3.new(-0.05, 0.42, -1), -0.36, 0.1, 0.1)
end

Outfit.BUILD.the_king = function(m: Model)
	gone(m, { "BowSet", "GreatSet", "ShieldArm", "ShieldBack", "SwordSet", "torso_hauberk" }, {
		"^Breastplate$", "^Fauld", "^Gorget", "Couter$", "Gauntlet$", "Greave$", "Poleyn$", "Sabaton$", "Tasset", "Vambrace",
		"^Pauldron", "^Seam$", "^StarBar", "^StarCore$", "^Tab", "^Cl%d", "^CloakYoke$", "^Ermine$", "^Crown",
	})
	sweep(m)
	-- the crown, made to the head: it rests on it
	local head = (m :: any).Head :: BasePart
	local crown = Arms.make("Crown", head.CFrame)
	crown.Name = "Crown"
	for _, d in crown:GetDescendants() do
		if d:IsA("BasePart") then
			for _, j in d:GetChildren() do
				if j:IsA("JointInstance") then
					j:Destroy()
				end
			end
			local w = Instance.new("Weld")
			w.Part0 = head
			w.Part1 = d
			w.C0 = head.CFrame:ToObjectSpace(d.CFrame)
			w.Parent = d
		end
	end
	crown.Parent = m
	-- the sword: right hand at the hip, the point low and forward
	Grip.fist(m, "Right", { radius = 0.082 })
	local root = (m :: any).HumanoidRootPart.CFrame
	local along = root:VectorToWorldSpace(Vector3.new(0.1, -0.35, -1).Unit)
	local missR = Hold.fistAt(m, "Right", Hold.frame(root * Vector3.new(1.0, -0.2, -0.6), along, shoulder(m, "Right")))
	local sword = Arms.make("KingSword")
	sword.Name = "SwordSet"
	Grip.hold(m, "Right", sword, "Grip")
	-- the cold in the blade: a pale trail when it moves, frost motes off its length, a faint light
	local handle = sword:FindFirstChild("Handle") :: BasePart
	local blade = sword:FindFirstChild("KingSword_Blade") :: BasePart
	local a0 = handle:FindFirstChild("BladeBase") :: Attachment
	local a1 = handle:FindFirstChild("BladeTip") :: Attachment
	if a0 and a1 then
		local trail = Instance.new("Trail")
		trail.Name = "SwordTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.2
		trail.MinLength = 0.05
		trail.LightEmission = 0.7
		trail.LightInfluence = 0.2
		trail.Color = ColorSequence.new(Color3.fromRGB(200, 226, 255), Color3.fromRGB(120, 170, 255))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new(1, 0.4)
		trail.Parent = handle
	end
	if blade then
		local cold = Instance.new("ParticleEmitter")
		cold.Name = "SwordCold"
		cold.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		cold.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
		cold.LightEmission = 0.8
		cold.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.02) })
		cold.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		cold.Lifetime = NumberRange.new(0.5, 1.1)
		cold.Speed = NumberRange.new(0.1, 0.5)
		cold.SpreadAngle = Vector2.new(180, 180)
		cold.Acceleration = Vector3.new(0, -0.6, 0)
		cold.Rate = 7
		cold.Parent = blade
		local glow = Instance.new("PointLight")
		glow.Name = "SwordGlow"
		glow.Color = Color3.fromRGB(170, 204, 255)
		glow.Brightness = 0.7
		glow.Range = 7
		glow.Shadows = false
		glow.Parent = blade
		-- the edge catches the cold light
		blade.Reflectance = 0.28
	end
	-- the shield: on the left, in front, its face turned a little out
	Grip.fist(m, "Left", { radius = 0.045 })
	local face = root:VectorToWorldSpace((CFrame.Angles(0, math.rad(22), 0) * Vector3.new(0, 0, -1)))
	local up = root:VectorToWorldSpace(Vector3.new(0, 1, 0.12).Unit)
	local at = root * Vector3.new(-0.85, 0.35, -1.25)
	local shieldFrame = CFrame.fromMatrix(at, up, face, up:Cross(face))
	local missL = Hold.fistAt(m, "Left", shieldFrame)
	local shield = Arms.make("Shield")
	shield.Name = "ShieldArm"
	Grip.hold(m, "Left", shield, "Grip")
	return missR, missL
end

-- every other body: rebuild the fingers round what each hand already holds
local HELD = {
	undead_sentinel = { Right = { haft = "leather", tip = "steel" }, Left = nil },
	undead_brute_heavy = { Right = { haft = "wood", tip = "iron" } },
	undead_archer = { Left = { haft = "leather", tip = "wood" } },
	undead_shambler_scullion = { Right = { haft = "LadleHandle", tip = "LadleBowl" } },
}

function Outfit.refit(m: Model, name: string)
	local spec = HELD[name]
	if not spec then
		return nil, nil
	end
	local out = {}
	for side, s in spec do
		local parts = Grip.held(m, side)
		local haft, tip
		for _, p in parts do
			if p.Name == s.haft and not haft then
				haft = p
			end
			if p.Name == s.tip and not tip then
				tip = p
			end
		end
		if haft and tip then
			out[side] = { Grip.refit(m, side, parts, haft, tip.Position, {}) }
		end
	end
	return out
end

function Outfit.apply(name: string)
	local undead = ServerStorage.Assets.Undead
	local master = undead:FindFirstChild(name)
	assert(master, "no master " .. name)
	local backup = lab:FindFirstChild("Backup") or Instance.new("Folder")
	backup.Name = "Backup"
	backup.Parent = lab
	if not backup:FindFirstChild(name) then
		master:Clone().Parent = backup
	end
	-- always rebuilt from the ORIGINAL (the backup), so running twice gives the same body
	local m = (backup :: any)[name]:Clone() :: Model
	m.Parent = lab.Work
	local a, b
	if Outfit.BUILD[name] then
		a, b = Outfit.BUILD[name](m)
	else
		a = Outfit.refit(m, name)
	end
	m:SetAttribute("Outfit", "2026-11-14")
	master:Destroy()
	m.Parent = undead
	return a, b
end

function Outfit.all()
	local report = {}
	for _, name in { "undead_spearman", "the_huntsman", "undead_knight", "the_king", "undead_sentinel", "undead_brute_heavy", "undead_archer", "undead_shambler_scullion" } do
		local ok, a, b = pcall(Outfit.apply, name)
		table.insert(report, name .. ": " .. (if ok then "ok " .. tostring(a) .. " " .. tostring(b) else "FAILED " .. tostring(a)))
	end
	return table.concat(report, "\n")
end

return Outfit
