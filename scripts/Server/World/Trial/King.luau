--!strict
--[[
	Trial task: `king`
	The Fallen King of Asterfall, at the head of the Keep Steps. A fight in three faces and an ending that
	is not a kill (docs/systems/Bestiary.md §8, Story §8). One body, one health bar, one nameplate that says
	"The King" so there is no doubt who this is; what he fights WITH changes as he loses health, and each
	change is a thing the player has to answer.

	  1. THE CROWNED (100 to 66%)   shield on the arm and the arming sword. Walks down the Steps and
	                                presses with the sword's bash. At 80% he raises a horn and the guard
	                                answers: two spearmen out of the dark at the edge of the court.
	  2. THE ARCHER KING (66 to 33%) the shield goes to his back, the great bow into his hand. He leaps back
	                                up the Steps to the landing and rains arrows on the court: a ring of pale
	                                frost on the ground shows where each one will land, a second and a bit
	                                before it does; and every second volley is an aimed shot, through the
	                                cover that you thought was safe. Climb the Steps at him and he sidesteps
	                                across the landing.
	  3. THE HOLLOW (33 to 0%)       the power under the castle takes over: the seams of the armour open on
	                                a cold light, the shield falls off his back, the bow is gone, the sword
	                                is two-handed and he is faster; and rings of frost spread over the court
	                                that slow whoever stands in them.

	THE PHASES CANNOT BE SKIPPED. `KingFloor` on the model is the health he cannot be hurt below in the
	current face (a combat modifier clamps every blow to it), and while he changes face he is `KingGuard`ed
	and takes nothing. A burst that would carry him through a face stops at the line.

	HE DOES NOT FALL. At the bottom he kneels, the light goes out of his eyes, the crown cracks; the
	prompt is a held "Release him" that every player can add to (banked, summed). Then the task is done.

	Params (configs/Trials):
	  enemy        the configs/Enemies id ("the_king")
	  landing      dotted path of the landing part at the head of the Steps
	  centre       marker path of the middle of the court
	  guard        { id, count, spawns = { marker path } } the answer to the horn at 80%
	  release      seconds of held "Release him", summed across players
	  slow         the walking-speed fraction inside the frost (0.55)

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.Parent.CombatService)
local EnemyAIService = require(script.Parent.Parent.EnemyAIService)
local EnemyService = require(script.Parent.Parent.EnemyService)
local LootService = require(script.Parent.Parent.LootService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Util = require(script.Parent.Util)

local King = {}

local rng = Random.new()

local PIVOT_ABOVE_FLOOR = 2.5
local SETS = { "SwordSet", "ShieldArm", "ShieldBack", "BowSet", "GreatSet" }

-- The sets of arms he shows, per face.
local FACES = {
	crowned = { SwordSet = true, ShieldArm = true },
	archer = { ShieldBack = true, BowSet = true },
	hollow = { GreatSet = true },
}

--==========================================================================
-- the pipeline modifier: a face cannot be skipped, and a guarded body takes nothing
--==========================================================================
local modifierRegistered = false

local function registerModifier()
	if modifierRegistered then
		return
	end
	modifierRegistered = true
	CombatService.registerModifier(function(context)
		local model = context.target.model
		if not model or model:GetAttribute("KingFloor") == nil then
			return
		end
		if model:GetAttribute("KingGuard") == true then
			context.blocked = true
			return
		end
		local room = context.target.health.current - (model:GetAttribute("KingFloor") :: number)
		if room <= 0 then
			context.blocked = true
		else
			context.amount = math.min(context.amount, room)
		end
	end)
end

--==========================================================================
-- small things
--==========================================================================
local function visual(model: Model, state: string, move: number?)
	model:SetAttribute("State", state)
	model:SetAttribute("Seq", ((model:GetAttribute("Seq") :: number?) or 0) + 1)
	model:SetAttribute("Move", move or 0)
end

local function setSet(model: Model, name: string, shown: boolean)
	local set = model:FindFirstChild(name)
	if not set then
		return
	end
	for _, d in set:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("T0") == nil then
				d:SetAttribute("T0", d.Transparency)
			end
			d.Transparency = if shown then (d:GetAttribute("T0") :: number) else 1
		end
	end
end

local function showFace(model: Model, face: string)
	local on = FACES[face]
	for _, name in SETS do
		setSet(model, name, on[name] == true)
	end
	model:SetAttribute("AttackKind", if face == "crowned" then "bash" elseif face == "archer" then "draw" else "sweep")
end

local function lightSeams(model: Model, lit: boolean, seconds: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Seam" then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = if lit then 0.05 else 1 }):Play()
		end
	end
end

local function puff(parent: Instance, at: Vector3, count: number, spread: number, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(spread, 1, spread)
	anchor.Position = at
	anchor.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(190, 220, 240))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 7) })
	e.Lifetime = NumberRange.new(1.0, 2.0)
	e.Speed = NumberRange.new(3, 12)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Drag = 2
	e.Rate = count / 0.12
	e.Parent = anchor
	task.delay(0.12, function()
		e.Enabled = false
	end)
	task.delay(3, function()
		anchor:Destroy()
	end)
end

local function floorAt(x: number, z: number, fromY: number, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

type PlayerInfo = { player: Player, root: BasePart, humanoid: Humanoid }

local function livingPlayers(): { PlayerInfo }
	local out: { PlayerInfo } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			table.insert(out, { player = player, root = root, humanoid = humanoid })
		end
	end
	return out
end

--==========================================================================
-- THE TASK
--==========================================================================
function King.create(ctx: any, def: any)
	registerModifier()

	local connections: { any } = {}
	local running = false
	local finished = false
	local kingId: string? = nil
	local model: Model? = nil
	local entity: any = nil
	local face = "waiting" -- waiting | crowned | archer | hollow | kneeling | released
	local transitioning = false
	local landingFeet = Vector3.zero
	local centre = Vector3.zero
	local maxHealth = 1
	local volleyCount = 0
	local plannedVolley: { { at: Vector3, ring: Part } } = {}
	local frost: { { part: Part, centre: Vector3, radius: number, grown: number, dies: number } } = {}
	local baseSpeed: { [Player]: number } = {}
	local lastSidestep = 0
	local guardCalled = false
	local ticker: RBXScriptConnection? = nil
	local prompt: ProximityPrompt? = nil
	local holds: { [Player]: number } = {}
	local banked = 0
	local nextFrostAt = 0
	local bar: Frame? = nil

	local function ignoreList(): { Instance }
		return if model then { model } else {}
	end

	--======================================================================
	-- The nameplate: his name, and a bar with the two lines where he changes
	--======================================================================
	local function buildNameplate(m: Model)
		local head = m:FindFirstChild("Head")
		if not (head and head:IsA("BasePart")) then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Nameplate"
		gui.Adornee = head
		gui.Size = UDim2.fromOffset(300, 64)
		gui.StudsOffset = Vector3.new(0, 4.6, 0)
		gui.MaxDistance = 320
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.Parent = head

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 34)
		name.Font = Enum.Font.Antique
		name.Text = "The King"
		name.TextSize = 30
		name.TextColor3 = Color3.fromRGB(232, 196, 104)
		name.TextStrokeColor3 = Color3.fromRGB(10, 6, 4)
		name.TextStrokeTransparency = 0.25
		name.Parent = gui

		local back = Instance.new("Frame")
		back.Position = UDim2.new(0.05, 0, 0, 40)
		back.Size = UDim2.new(0.9, 0, 0, 10)
		back.BackgroundColor3 = Color3.fromRGB(14, 10, 10)
		back.BackgroundTransparency = 0.15
		back.BorderSizePixel = 0
		back.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 118, 52)
		stroke.Thickness = 1.5
		stroke.Parent = back

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(150, 36, 44)
		fill.BorderSizePixel = 0
		fill.Parent = back
		bar = fill

		for _, at in { 1 / 3, 2 / 3 } do
			local tick = Instance.new("Frame")
			tick.Position = UDim2.new(at, -1, 0, -2)
			tick.Size = UDim2.new(0, 2, 1, 4)
			tick.BackgroundColor3 = Color3.fromRGB(232, 196, 104)
			tick.BorderSizePixel = 0
			tick.Parent = back
		end
	end

	local function paintBar()
		if bar and entity then
			bar.Size = UDim2.fromScale(math.clamp(entity.health.current / maxHealth, 0, 1), 1)
		end
	end

	--======================================================================
	-- Moving him (the brain is held while a script moves him)
	--======================================================================
	local function leap(toFeet: Vector3, seconds: number, height: number)
		local m = model
		if not m then
			return
		end
		local from = m:GetPivot().Position
		local goal = toFeet + Vector3.new(0, PIVOT_ABOVE_FLOOR, 0)
		local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
		local look = if flat.Magnitude > 0.1 then flat.Unit else m:GetPivot().LookVector
		visual(m, "Run", 16)
		local started = os.clock()
		while true do
			local a = (os.clock() - started) / seconds
			if a >= 1 or finished or not m.Parent then
				break
			end
			local pos = from:Lerp(goal, a) + Vector3.new(0, height * 4 * a * (1 - a), 0)
			m:PivotTo(CFrame.lookAt(pos, pos + look))
			RunService.Heartbeat:Wait()
		end
		if m.Parent then
			m:PivotTo(CFrame.lookAt(goal, goal + look))
			puff(ctx.folder, toFeet + Vector3.new(0, 0.6, 0), 14, 6)
			visual(m, "Idle", 0)
		end
	end

	local function cry(seconds: number)
		local m = model
		if m then
			visual(m, "Aggro", 0)
			task.wait(seconds)
			if m.Parent and not finished then
				visual(m, "Idle", 0)
			end
		end
	end

	--======================================================================
	-- FACE 1: THE CROWNED
	--======================================================================
	local function enterCrowned()
		face = "crowned"
		local m = model :: Model
		showFace(m, "crowned")
		m:SetAttribute("KingFloor", maxHealth * (2 / 3) + 1)
		EnemyAIService.tune(kingId :: string, {
			ranged = false,
			meleeRange = 0,
			attackRange = 9,
			minRange = 0,
			moveSpeed = 11,
			attackDamage = 45,
			attackCooldown = 1.9,
			windup = 0.9,
			strike = 0.2,
			recover = 0.8,
			detection = 400,
			leash = 400,
		})
		EnemyAIService.setHooks(kingId :: string, nil)
		EnemyAIService.hold(kingId :: string, false)
		ctx.progress(1, 3)
	end

	local function callGuard()
		if guardCalled then
			return
		end
		guardCalled = true
		local g = def.guard
		if not g then
			return
		end
		ctx.note("A horn. Answered, from the dark at the edge of the court.", 5)
		local party = Scaling.forPlayers(#Players:GetPlayers())
		local count = math.max(1, math.round(g.count * party.enemyCountMult))
		for i = 1, count do
			local at = Markers.resolve(g.spawns[((i - 1) % #g.spawns) + 1])
			if at then
				EnemyService.spawn(g.id, at + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), party.enemyHealthMult)
			end
		end
	end

	--======================================================================
	-- FACE 2: THE ARCHER KING
	--======================================================================
	local function makeRing(at: Vector3, radius: number): Part
		local ring = Instance.new("Part")
		ring.Name = "FrostMark"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(190, 224, 255)
		ring.Transparency = 0.9
		ring.Size = Vector3.new(0.18, radius * 2, radius * 2)
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = ctx.folder
		TweenService:Create(ring, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.25 }):Play()
		return ring
	end

	local function damageIn(at: Vector3, radius: number, amount: number)
		for _, info in livingPlayers() do
			local d = Vector3.new(info.root.Position.X - at.X, 0, info.root.Position.Z - at.Z).Magnitude
			if d <= radius then
				CombatService.applyDamage({
					targetId = Constants.CombatId.PlayerPrefix .. info.player.UserId,
					sourceId = kingId,
					amount = amount,
					damageType = "Physical",
				})
			end
		end
	end

	local function arrowFalls(at: Vector3)
		local shaft = Instance.new("Part")
		shaft.Name = "Volley"
		shaft.Anchored = true
		shaft.CanCollide = false
		shaft.CanQuery = false
		shaft.CanTouch = false
		shaft.Size = Vector3.new(0.3, 0.3, 9)
		shaft.Color = Color3.fromRGB(214, 236, 255)
		shaft.Material = Enum.Material.Neon
		shaft.Parent = ctx.folder
		local top = at + Vector3.new(rng:NextNumber(-6, 6), 60, rng:NextNumber(-6, 6))
		local started = os.clock()
		local seconds = 0.26
		while true do
			local a = (os.clock() - started) / seconds
			if a >= 1 then
				break
			end
			local pos = top:Lerp(at, a)
			shaft.CFrame = CFrame.lookAt(pos, at)
			RunService.Heartbeat:Wait()
		end
		shaft:Destroy()
	end

	local function onArcherWindup(_: string, target: any)
		volleyCount += 1
		plannedVolley = {}
		if volleyCount % 2 == 1 then
			-- the marked rain: every living player within 100, predicted a second ahead
			for _, info in livingPlayers() do
				if (info.root.Position - (model :: Model):GetPivot().Position).Magnitude <= 110 then
					local velocity = info.root.AssemblyLinearVelocity
					local at = info.root.Position + Vector3.new(velocity.X, 0, velocity.Z) * 0.9
					local y = floorAt(at.X, at.Z, at.Y + 6, ignoreList()) or info.root.Position.Y - 3
					local floor = Vector3.new(at.X, y, at.Z)
					table.insert(plannedVolley, { at = floor, ring = makeRing(floor, 6.5) })
				end
			end
		end
	end

	local function onArcherStrike(_: string, target: any, selfPos: Vector3)
		local volley = plannedVolley
		plannedVolley = {}
		if #volley > 0 then
			for _, v in volley do
				task.spawn(function()
					arrowFalls(v.at)
					puff(ctx.folder, v.at + Vector3.new(0, 0.6, 0), 18, 8)
					damageIn(v.at, 6.5, 34)
					TweenService:Create(v.ring, TweenInfo.new(0.7), { Transparency = 1 }):Play()
					task.delay(0.8, function()
						v.ring:Destroy()
					end)
				end)
			end
			return
		end
		-- the aimed shot, through whatever is in the way (cover is real: it can stop this one)
		local r = Config.get("Enemies")[def.enemy].Ranged
		if target and target.model and r then
			local targetPos = (target.model :: Model):GetPivot().Position
			ProjectileService.fire({
				sourceId = kingId,
				origin = selfPos + Vector3.new(0, 3.2, 0),
				targetPosition = targetPos + Vector3.new(0, 1.5, 0),
				targetVelocity = Vector3.zero,
				kind = r.Projectile,
				speed = r.Speed,
				damage = r.Damage,
				damageType = r.DamageType,
				spread = r.Spread,
				leadFactor = r.LeadFactor,
				maxRange = r.MaxRange,
			})
		end
	end

	local function sidestep()
		local m = model
		if not m or transitioning or face ~= "archer" or not kingId then
			return
		end
		lastSidestep = os.clock()
		EnemyAIService.hold(kingId, true)
		local here = m:GetPivot().Position
		local toX = if here.X > 0 then -13 else 13
		leap(Vector3.new(landingFeet.X + toX, landingFeet.Y, landingFeet.Z), 0.45, 4)
		if face == "archer" and not finished then
			EnemyAIService.hold(kingId, false)
		end
	end

	local function enterArcher()
		transitioning = true
		face = "archer"
		local m = model :: Model
		local id = kingId :: string
		m:SetAttribute("KingGuard", true)
		EnemyAIService.hold(id, true)
		EnemyAIService.setHooks(id, nil)
		ctx.note("He withdraws. The shield goes to his back, and he is going for the bow.", 5)
		cry(0.9)
		showFace(m, "archer")
		-- back up the Steps in one leap
		leap(landingFeet, 1.3, 14)
		m:SetAttribute("KingFloor", maxHealth * (1 / 3) + 1)
		EnemyAIService.tune(id, {
			ranged = true,
			meleeRange = 0,
			attackRange = 105,
			minRange = 0,
			moveSpeed = 8,
			attackCooldown = 3.0,
			windup = 0.9,
			strike = 0.1,
			recover = 0.5,
			spawnPosition = landingFeet,
		})
		EnemyAIService.setHooks(id, { windup = onArcherWindup, strike = onArcherStrike })
		EnemyAIService.hold(id, false)
		m:SetAttribute("KingGuard", false)
		transitioning = false
		ctx.progress(2, 3)
		ctx.note("Where the pale rings are, the arrows will be. Move.", 5)
	end

	--======================================================================
	-- FACE 3: THE HOLLOW
	--======================================================================
	local function makeFrost(at: Vector3)
		local radius = 9
		local part = Instance.new("Part")
		part.Name = "Frost"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Ice
		part.Color = Color3.fromRGB(176, 214, 240)
		part.Transparency = 0.5
		part.Size = Vector3.new(0.12, 1, 1)
		part.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		part.Parent = ctx.folder
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Color = ColorSequence.new(Color3.fromRGB(200, 226, 245))
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		mist.Lifetime = NumberRange.new(1.5, 2.6)
		mist.Speed = NumberRange.new(0.5, 2)
		mist.Rate = 6
		mist.Parent = part
		TweenService:Create(part, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, radius * 2, radius * 2) }):Play()
		table.insert(frost, { part = part, centre = at, radius = radius, grown = os.clock() + 1.4, dies = os.clock() + 15 })
	end

	local function frostStep(now: number)
		for i = #frost, 1, -1 do
			local z = frost[i]
			if now >= z.dies then
				TweenService:Create(z.part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
				local part = z.part
				task.delay(1.3, function()
					part:Destroy()
				end)
				table.remove(frost, i)
			end
		end
		for _, info in livingPlayers() do
			local inside = false
			for _, z in frost do
				if now >= z.grown then
					local d = Vector3.new(info.root.Position.X - z.centre.X, 0, info.root.Position.Z - z.centre.Z).Magnitude
					if d <= z.radius then
						inside = true
						break
					end
				end
			end
			if baseSpeed[info.player] == nil then
				baseSpeed[info.player] = info.humanoid.WalkSpeed
			end
			local base = baseSpeed[info.player]
			local want = if inside then base * def.slow else base
			if math.abs(info.humanoid.WalkSpeed - want) > 0.05 then
				info.humanoid.WalkSpeed = want
			end
		end
	end

	local function restoreSpeed()
		for player, base in baseSpeed do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = base
			end
		end
		baseSpeed = {}
	end

	local function enterHollow()
		transitioning = true
		face = "hollow"
		local m = model :: Model
		local id = kingId :: string
		m:SetAttribute("KingGuard", true)
		EnemyAIService.hold(id, true)
		EnemyAIService.setHooks(id, nil)
		ctx.note("The cold in the stone comes up through him.", 5)
		cry(1.0)
		lightSeams(m, true, 1.6)
		showFace(m, "hollow")
		-- the shield on his back drops and is left
		local old = m:FindFirstChild("ShieldBack")
		if old then
			local at = m:GetPivot().Position
			puff(ctx.folder, at, 22, 8)
		end
		-- down the Steps to meet whoever is nearest
		local nearest: PlayerInfo? = nil
		local best = math.huge
		for _, info in livingPlayers() do
			local d = (info.root.Position - m:GetPivot().Position).Magnitude
			if d < best then
				best, nearest = d, info
			end
		end
		local land = centre
		if nearest then
			local p = nearest.root.Position
			local f = floorAt(p.X, p.Z - 6, p.Y + 8, ignoreList())
			land = Vector3.new(p.X, f or centre.Y, p.Z - 6)
		end
		leap(land, 1.2, 12)
		m:SetAttribute("KingFloor", 1)
		EnemyAIService.tune(id, {
			ranged = false,
			meleeRange = 0,
			attackRange = 11,
			moveSpeed = 15,
			attackDamage = 56,
			attackCooldown = 1.3,
			windup = 1.0,
			strike = 0.25,
			recover = 1.0,
			spawnPosition = centre,
		})
		EnemyAIService.hold(id, false)
		m:SetAttribute("KingGuard", false)
		transitioning = false
		nextFrostAt = os.clock() + 2
		ctx.progress(3, 3)
	end

	--======================================================================
	-- THE END THAT IS NOT A KILL
	--======================================================================
	local function paintRelease()
		local total = banked
		local now = os.clock()
		for _, startedAt in holds do
			total += now - startedAt
		end
		return total
	end

	local function released()
		if finished then
			return
		end
		finished = true
		local m = model :: Model
		if prompt then
			prompt.Enabled = false
		end
		-- the light goes out: the eyes first, then the seams
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "HollowLight" then
				TweenService:Create(d, TweenInfo.new(2.5), { Transparency = 1 }):Play()
			end
		end
		lightSeams(m, false, 3)
		-- the crown breaks: two points fall away and the band darkens
		local points = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "CrownPoint" then
				table.insert(points, d)
			elseif d:IsA("BasePart") and d.Name == "CrownBand" then
				TweenService:Create(d, TweenInfo.new(2), { Color = Color3.fromRGB(96, 84, 52) }):Play()
			end
		end
		for i = 1, math.min(2, #points) do
			local p = points[i]
			p.Parent = Workspace
			p.Anchored = false
			p.CanCollide = true
			p.Massless = false
			for _, w in p:GetChildren() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-4, 4), 6, rng:NextNumber(-4, 4))
			task.delay(30, function()
				p:Destroy()
			end)
		end
		puff(ctx.folder, m:GetPivot().Position + Vector3.new(0, 2, 0), 30, 8, Color3.fromRGB(150, 130, 100))
		-- the name comes down with the fight
		local head = m:FindFirstChild("Head")
		local plate = head and head:FindFirstChild("Nameplate")
		if plate then
			task.delay(4, function()
				plate:Destroy()
			end)
		end
		ctx.hint(nil)
		ctx.note("The crown cracks. He lets go of it. The keep door answers somewhere above.", 7)
		LootService.grantAll("the_king", m:GetPivot().Position + Vector3.new(0, 3, -4))
		restoreSpeed()
		task.delay(3.2, function()
			ctx.done()
		end)
	end

	local function kneel()
		if face == "kneeling" or finished then
			return
		end
		face = "kneeling"
		transitioning = true
		local m = model :: Model
		local id = kingId :: string
		m:SetAttribute("KingGuard", true)
		EnemyAIService.hold(id, true)
		EnemyAIService.setHooks(id, nil)
		-- kill any thing of his still falling or standing in the court
		for _, z in frost do
			local part = z.part
			TweenService:Create(part, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			task.delay(1.6, function()
				part:Destroy()
			end)
		end
		frost = {}
		restoreSpeed()
		-- he does not fall: the kneeling clip, held
		m:SetAttribute("Fall", 3)
		visual(m, "Death", 0)
		ctx.hint("Release him")
		ctx.note("He does not fall. He kneels. The light in him is going out, slowly, and it hurts.", 7)

		local at = m:GetPivot().Position
		prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 1.2, 0) + m:GetPivot().LookVector * 2.2, "ReleasePrompt", "Release him", "The King - kneeling", def.release, 11)
		local p = prompt :: ProximityPrompt
		p.PromptButtonHoldBegan:Connect(function(player: Player)
			holds[player] = os.clock()
		end)
		p.PromptButtonHoldEnded:Connect(function(player: Player)
			local startedAt = holds[player]
			if startedAt then
				banked += os.clock() - startedAt
				holds[player] = nil
			end
			if not finished then
				p.HoldDuration = math.max(0.6, def.release - banked)
				local left = math.max(0, math.ceil(def.release - banked))
				p.ObjectText = if banked > 0.5 then ("The King - %ds more"):format(left) else "The King - kneeling"
			end
		end)
		p.Triggered:Connect(function()
			released()
		end)
		table.insert(connections, Players.PlayerRemoving:Connect(function(player)
			holds[player] = nil
		end))
	end

	--======================================================================
	-- The fight, by the numbers
	--======================================================================
	local function onHealth()
		paintBar()
		if not entity or transitioning or finished then
			return
		end
		local current = entity.health.current
		if face == "crowned" then
			if current <= maxHealth * 0.8 and not guardCalled then
				callGuard()
			end
			if current <= maxHealth * (2 / 3) + 1.5 then
				task.spawn(enterArcher)
			end
		elseif face == "archer" then
			if current <= maxHealth * (1 / 3) + 1.5 then
				task.spawn(enterHollow)
			end
		elseif face == "hollow" then
			if current <= 1.5 then
				task.spawn(kneel)
			end
		end
	end

	local function begin()
		-- he lifts his head; and then the fight
		ctx.note("He lifts his head. There is a crown on it.", 4)
		task.wait(1.6)
		if finished or not model then
			return
		end
		cry(1.3)
		enterCrowned()
	end

	return {
		start = function()
			if running then
				return
			end
			running = true
			local landing = Util.find(def.landing)
			local c = Markers.resolve(def.centre)
			if not landing or not c then
				ctx.warn("king: missing landing or centre")
				return
			end
			local landingPart = landing :: BasePart
			landingFeet = Vector3.new(landingPart.Position.X, landingPart.Position.Y + landingPart.Size.Y / 2, landingPart.Position.Z + 2)
			centre = Vector3.new(c.X, 2, c.Z)

			local party = Scaling.forPlayers(#Players:GetPlayers())
			kingId = EnemyService.spawn(def.enemy, landingFeet + Vector3.new(0, PIVOT_ABOVE_FLOOR, 0), party.enemyHealthMult, landingFeet.Y)
			entity = CombatService.getEntity(kingId :: string)
			model = entity and entity.model
			if not (entity and model) then
				ctx.warn("king: could not spawn")
				return
			end
			local m = model :: Model
			maxHealth = entity.health.max
			m:SetAttribute("KingFloor", maxHealth + 1)
			m:SetAttribute("KingGuard", false)
			showFace(m, "crowned")
			-- stands facing the court, the way the Steps run
			m:PivotTo(CFrame.lookAt(landingFeet + Vector3.new(0, PIVOT_ABOVE_FLOOR, 0), landingFeet + Vector3.new(0, PIVOT_ABOVE_FLOOR, 40)))
			EnemyAIService.hold(kingId :: string, true)
			buildNameplate(m)
			paintBar()
			entity.health.Changed:connect(onHealth)

			ctx.progress(0, 3)
			ctx.note("At the head of the Steps a figure stands with his hands on a sword. It is not a statue.", 6)

			local started = false
			ticker = RunService.Heartbeat:Connect(function()
				if finished then
					return
				end
				local now = os.clock()
				if not started then
					-- he wakes when a living player comes within 90 studs, or is struck
					for _, info in livingPlayers() do
						if (info.root.Position - m:GetPivot().Position).Magnitude <= 90 then
							started = true
							task.spawn(begin)
							break
						end
					end
					if entity.health.current < maxHealth and not started then
						started = true
						task.spawn(begin)
					end
					return
				end
				if face == "archer" and not transitioning and now - lastSidestep > 5.5 then
					for _, info in livingPlayers() do
						if (info.root.Position - m:GetPivot().Position).Magnitude <= 11 then
							task.spawn(sidestep)
							break
						end
					end
				end
				if face == "hollow" and not transitioning then
					frostStep(now)
					if now >= nextFrostAt then
						nextFrostAt = now + 3.6
						local targets = livingPlayers()
						if #targets > 0 then
							local info = targets[rng:NextInteger(1, #targets)]
							local p = info.root.Position + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
							local y = floorAt(p.X, p.Z, p.Y + 6, ignoreList())
							if y then
								makeFrost(Vector3.new(p.X, y, p.Z))
							end
						end
					end
				elseif face == "kneeling" then
					if not finished and paintRelease() >= def.release then
						released()
					end
				end
			end)
		end,

		stop = function()
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
			restoreSpeed()
			for _, z in frost do
				z.part:Destroy()
			end
			frost = {}
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
		end,

		progress = function(): (number, number)
			if face == "crowned" then
				return 1, 3
			elseif face == "archer" then
				return 2, 3
			elseif face == "hollow" or face == "kneeling" or face == "released" then
				return 3, 3
			end
			return 0, 3
		end,
	}
end

return King
