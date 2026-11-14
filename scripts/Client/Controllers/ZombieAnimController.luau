--!strict
--[[
	ZombieAnimController
	Moves the dead: every body the server has tagged "TLK_Undead" is posed here, every frame, from the attributes the
	server writes on it:

	    State   Idle | Walk | Run | Aggro | Windup | Strike | Recover | Death | Block
	    Seq     counts state changes, so the same state twice still replays
	    Move    its speed, to scale a walk or a run to its pace
	    Variant 1..3, which gait this body walks for life
	    HitCount goes up on every wound: the body flinches
	    Fall    1..3, which fall it takes when it dies
	    AttackKind  a unit that fights more than one way (the King) says which blow this is

	NOTHING is sent per frame. The server writes an attribute when the state changes and every client works out the
	picture from it, which is also why a body that streams in late arrives already doing the right thing.

	PLAYED WITH CLIPPLAYER (2026-11-14). The clips (Shared/Anim/ZombieAnims) are evaluated here and written onto the
	joints' Transform at PreSimulation, the way the player's own body is moved (Shared/Anim/ClipPlayer explains why:
	ids registered with KeyframeSequenceProvider play only in Studio, so until now the dead stood still in the published
	game). Layers, lowest first:
	    base      idle / walk / run / crawl, cross-faded when it changes
	    hold      the arms of a body that carries a weapon (ZombieAnims.STYLE): the base leaves its arms alone
	    action    aggro, an attack, a block, a death (a death holds its last frame)
	    overlays  a flinch on every hit, a stumble now and then on a walk
	then THE SECOND HAND: a weapon held in two hands (STYLE.twoHands) has a second grip, an Attachment "Grip2"; the
	other hand is put on it every frame (ClipPlayer.reach to the wrist, then the hand turned along the haft), so whatever
	the clip does with the weapon hand, the other hand stays on the haft.

	DISTANCE. A body further than ACTIVE_RANGE from the camera is not animated (rest pose). Nearer, it is posed every
	frame within NEAR, every second frame within MID, every third beyond.

	SMOOTH STEPS (2026-11-05). The server moves a body by setting its anchored root a few times a second, which reaches a
	client as a jump; within ACTIVE_RANGE every frame draws the root a little behind the server, between the last two
	places it sent. Only the picture changes: hits, reach and sight stay on the server's numbers.

	Place: client (boots in both places; nothing in the Hub carries the tag). Phase: Enemy AI / Presentation.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ClipPlayer = require(ReplicatedStorage.Shared.Anim.ClipPlayer)
local ArmIK = require(ReplicatedStorage.Shared.Anim.ArmIK)
local ZombieAnims = require(ReplicatedStorage.Shared.Anim.ZombieAnims)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ZombieAnimController = {}

ZombieAnimController.Name = "ZombieAnimController"

local log = Logger.new("ZombieAnimController")

local TAG = "TLK_Undead"
local ACTIVE_RANGE = 170
local NEAR = 55
local MID = 105
local STEP_SECONDS = 0.25
local WALK_PACE = 7 -- the speed a walk clip is authored for
local RUN_PACE = 15
local CRAWL_PACE = 6 -- the speed the first crawl clip is authored for
local FADE = 0.2
local ACTION_IN = 0.08
local ACTION_OUT = 0.18

-- smooth steps: how far behind the server a body is drawn (a share of the gap between its updates, within limits)
local SMOOTH_SHARE = 1.15
local SMOOTH_MIN = 0.02
local SMOOTH_MAX = 0.2
local SMOOTH_SNAP = 12 -- studs: a longer jump is a teleport, shown at once

local IDENTITY = CFrame.new()

type Clip = ClipPlayer.Clip
type Snapshot = { t: number, cf: CFrame }

type Layer = {
	clip: Clip,
	t: number,
	speed: number,
	w: number, -- its weight now
	fade: number, -- seconds to come in
	out: boolean, -- going out
	hold: boolean, -- a one-shot that stays on its last frame (a death, a block)
}

type Agent = {
	model: Model,
	rig: ClipPlayer.Rig?,
	kind: string,
	variant: number,
	style: { hold: string, twoHands: string? }?,
	crawler: number, -- 0 standing, 1 the first (legless) crawler, 2 the second
	seq: number,
	hits: number,
	active: boolean,
	connections: { RBXScriptConnection },
	jitter: number, -- this body's own pace, a little off everyone else's
	nextStumble: number,
	base: Layer?,
	baseOld: Layer?,
	baseKey: string?,
	holdLayer: Layer?,
	action: Layer?,
	overlays: { Layer },
	pose: { [string]: CFrame },
	every: number, -- posed every this many frames
	waited: number, -- seconds since it was last posed
	-- the second hand
	grip2: Attachment?,
	gripHand: BasePart?,
	-- the weapon's path during an attack or a block (per hand), and each fist's rest frame in the chest's space
	actionGrips: { [string]: any }?,
	blockGrips: boolean,
	restFist: { [string]: CFrame },
	fists: { [string]: Attachment },
	-- smooth steps
	snaps: { Snapshot },
	gap: number,
	written: CFrame?,
}

local set: ZombieAnims.Set? = nil
local agents: { [Model]: Agent } = {}
local frame = 0

--==========================================================================
-- Layers
--==========================================================================
local function layer(clip: Clip, speed: number?, fade: number?, hold: boolean?, desync: boolean?): Layer
	return {
		clip = clip,
		t = if desync and clip.looped and clip.length > 0 then math.random() * clip.length else 0,
		speed = speed or 1,
		w = 0,
		fade = fade or FADE,
		out = false,
		hold = hold == true,
	}
end

local function setBase(agent: Agent, key: string, clip: Clip, speed: number)
	if agent.baseKey == key and agent.base then
		agent.base.speed = speed
		return
	end
	agent.baseOld = agent.base
	agent.base = layer(clip, speed, FADE, false, true)
	agent.baseKey = key
end

local function setAction(agent: Agent, clip: Clip, hold: boolean?, fade: number?)
	agent.action = layer(clip, 1, fade or ACTION_IN, hold, false)
end

local function armed(agent: Agent): boolean
	return agent.style ~= nil
end

--[[
	Brings the body to whatever its State says it is doing right now.
]]
local function apply(agent: Agent)
	local s = set
	if not s then
		return
	end
	local model = agent.model
	local state = model:GetAttribute("State")
	local pace = model:GetAttribute("Move")
	local move = if typeof(pace) == "number" then pace else 0
	local held = armed(agent)

	if agent.crawler > 0 and (state == "Walk" or state == "Run") then
		if agent.crawler == 2 then
			setBase(agent, "crawl2", s.crawl2, math.max(0.45, move / ZombieAnims.CRAWL2_PACE) * agent.jitter)
		else
			setBase(agent, "crawl", s.crawl, math.max(0.5, move / CRAWL_PACE) * agent.jitter)
		end
	elseif state == "Walk" then
		local list = if held then s.walkArmed else s.walk
		setBase(agent, "walk", list[agent.variant], math.max(0.4, move / WALK_PACE) * agent.jitter)
	elseif state == "Run" then
		setBase(agent, "run", if held then s.runArmed else s.run, math.max(0.5, move / RUN_PACE) * agent.jitter)
	elseif state == "Idle" then
		if agent.crawler == 2 then
			setBase(agent, "idle", s.crawl2Idle, 1)
		else
			setBase(agent, "idle", if held then s.idleArmed else s.idle, 1)
		end
	elseif state == "Aggro" then
		setAction(agent, s.aggro)
		agent.actionGrips = nil
		agent.blockGrips = false
	elseif state == "Windup" then
		-- a unit that fights more than one way says which one it is doing right now
		local override = model:GetAttribute("AttackKind")
		local kindName = if typeof(override) == "string" then override else s.kindOf[agent.kind]
		local variants = ZombieAnims.VARIANTS[agent.kind]
		if typeof(override) ~= "string" and variants then
			kindName = variants[math.random(1, #variants)]
		end
		local clip = s.attack[kindName or "shove"] or s.attack.shove
		setAction(agent, clip)
		agent.actionGrips = s.grips[kindName or "shove"]
		agent.blockGrips = false
	elseif state == "Death" then
		local fall = model:GetAttribute("Fall")
		local n = if typeof(fall) == "number" then math.clamp(fall, 1, #s.death) else 1
		local clip = if agent.crawler == 2 then s.crawlDeath2 elseif agent.crawler == 1 then s.crawlDeath else s.death[n]
		setAction(agent, clip, true, 0.05)
		agent.actionGrips = nil
		agent.blockGrips = false
		agent.overlays = {}
		-- nothing goes on walking or holding under a fall
		agent.baseOld, agent.holdLayer = nil, nil
		if agent.base then
			agent.base.speed = 0
		end
	end
	-- Strike and Recover belong to the attack clip already running. A state the action does not belong to fades it.
	if agent.action and state ~= "Windup" and state ~= "Strike" and state ~= "Recover" and state ~= "Aggro" and state ~= "Death" then
		if agent.action.hold then
			agent.action.out = true
		end
	end
end

-- The server's "Guard" (the King's shield up): a held block over whatever the body is doing; an attack ends it.
local function guard(agent: Agent)
	local s = set
	if not s or not s.attack.block then
		return
	end
	local state = agent.model:GetAttribute("State")
	if agent.model:GetAttribute("Guard") == true and state ~= "Death" and state ~= "Windup" and state ~= "Strike" then
		setAction(agent, s.attack.block, true, ZombieAnims.BLOCK_IN)
		agent.actionGrips = nil
		agent.blockGrips = true
	elseif agent.blockGrips and agent.action then
		agent.action.out = true
	end
end

local function flinch(agent: Agent)
	local s = set
	if not s or agent.model:GetAttribute("State") == "Death" then
		return
	end
	table.insert(agent.overlays, layer(s.flinch, 1, 0.03))
end

-- Now and then a walking body stumbles: a knee gives and it catches itself (an overlay; the legs go on walking).
local function maybeStumble(agent: Agent, now: number)
	local s = set
	if not s or not agent.active or agent.crawler > 0 or now < agent.nextStumble then
		return
	end
	agent.nextStumble = now + 6 + math.random() * 9
	if agent.model:GetAttribute("State") ~= "Walk" then
		return
	end
	table.insert(agent.overlays, layer(s.stumble, 0.85 + math.random() * 0.3, 0.06))
end

-- Advances a layer by dt; returns false when it has gone.
local function advance(l: Layer, dt: number): boolean
	l.t += dt * l.speed
	if l.out then
		l.w -= dt / ACTION_OUT
		return l.w > 0
	end
	l.w = math.min(1, l.w + dt / math.max(l.fade, 1e-3))
	if not l.clip.looped and l.t >= l.clip.length then
		if l.hold then
			l.t = l.clip.length
		else
			l.out = true
		end
	end
	return true
end

--==========================================================================
-- The second hand on the haft
--==========================================================================
--[[
	`side` hand onto the grip `grip2` of the weapon welded in the other hand. Everything in the chest's space. The hand's
	X runs along the haft (its thumb toward the tip), its Y (toward the wrist) toward the shoulder.
]]
local function secondHand(agent: Agent, side: string)
	local rig = agent.rig
	local grip2 = agent.grip2
	local holder = agent.gripHand
	if not (rig and grip2 and holder) then
		return
	end
	local pose = agent.pose
	local other = if side == "Left" then "Right" else "Left"
	local handName = side .. "Hand"
	local hand = agent.model:FindFirstChild(handName)
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	-- the weapon hand under this pose, then the grip on the haft
	local weaponHand = ClipPlayer.hand(rig, pose, other)
	local gripPart = grip2.Parent :: BasePart
	local offset = holder.CFrame:ToObjectSpace(gripPart.CFrame) * grip2.CFrame
	local grip = weaponHand * offset
	local p = grip.Position
	local along = grip.RightVector
	-- the fist's frame on the haft (tools/zombie/Grip): X along the haft toward the business end, Y away from the
	-- shoulder (the forearm comes from there); the hand follows from the "Fist" Attachment its fingers were built round
	local fist = hand:FindFirstChild("Fist")
	if not (fist and fist:IsA("Attachment")) then
		return
	end
	local shoulder = (rig.a0[side .. "UpperArm"] or IDENTITY).Position
	local away = p - shoulder
	local y = away - along * away:Dot(along)
	if y.Magnitude < 1e-3 then
		return
	end
	y = y.Unit
	local fistFrame = CFrame.fromMatrix(p, along, y, along:Cross(y))
	local handCF = fistFrame * fist.CFrame:Inverse()
	ArmIK.solve(rig, pose, side, handCF, Vector3.new(if side == "Left" then -0.7 else 0.7, -1, 0.3))
end

--==========================================================================
-- Posing
--==========================================================================
local function compose(agent: Agent, dt: number)
	local rig = agent.rig
	if not rig then
		return
	end
	local pose = agent.pose
	table.clear(pose)
	-- base, cross-faded
	local old, base = agent.baseOld, agent.base
	if old then
		advance(old, dt)
		ClipPlayer.sample(old.clip, old.t, pose, 1)
	end
	if base then
		advance(base, dt)
		ClipPlayer.sample(base.clip, base.t, pose, if old then base.w else 1)
		if base.w >= 1 then
			agent.baseOld = nil
		end
	end
	-- the arms' hold
	local h = agent.holdLayer
	if h then
		advance(h, dt)
		ClipPlayer.sample(h.clip, h.t, pose, 1)
	end
	-- an action over it all
	local a = agent.action
	if a then
		if advance(a, dt) then
			ClipPlayer.sample(a.clip, a.t, pose, a.w)
		else
			agent.action = nil
		end
	end
	-- overlays
	for i = #agent.overlays, 1, -1 do
		local o = agent.overlays[i]
		if advance(o, dt) then
			ClipPlayer.sample(o.clip, o.t, pose, o.w)
		else
			table.remove(agent.overlays, i)
		end
	end
	-- the weapon's path: each fist along its track (an attack) or to its guard (a block), blended by the action's weight
	local act = agent.action
	if act and (agent.actionGrips or agent.blockGrips) then
		for side, rest in agent.restFist do
			local p, yaw, pitch, roll
			if agent.blockGrips then
				local g = ZombieAnims.BLOCK_GRIP[side]
				if g then
					local f = math.clamp(act.t / ZombieAnims.BLOCK_IN, 0, 1)
					f = f * f * (3 - 2 * f)
					p, yaw, pitch, roll = g.p * f, (g.yaw or 0) * f, (g.pitch or 0) * f, (g.roll or 0) * f
				end
			else
				local keys = (agent.actionGrips :: any)[side]
				if keys then
					p, yaw, pitch, roll = ZombieAnims.sampleGrip(ClipPlayer, keys, act.t)
				end
			end
			local fist = agent.fists[side]
			if p and fist then
				local target = CFrame.new(rest.Position + p)
					* CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yaw))
					* CFrame.fromAxisAngle(Vector3.xAxis, math.rad(pitch))
					* rest.Rotation
					* CFrame.Angles(math.rad(roll), 0, 0)
				local handChest = target * fist.CFrame:Inverse()
				local names = { side .. "UpperArm", side .. "LowerArm", side .. "Hand" }
				local before = { pose[names[1]] or IDENTITY, pose[names[2]] or IDENTITY, pose[names[3]] or IDENTITY }
				ArmIK.solve(rig, pose, side, handChest, Vector3.new(if side == "Left" then -0.8 else 0.8, -1, 0.3))
				if act.w < 1 then
					for i, n in names do
						pose[n] = before[i]:Lerp(pose[n] or IDENTITY, act.w)
					end
				end
			end
		end
	end
	-- the second hand
	local style = agent.style
	if style and style.twoHands and agent.model:GetAttribute("State") ~= "Death" then
		secondHand(agent, style.twoHands)
	end
	ClipPlayer.write(rig, pose)
end

--==========================================================================
-- Smooth steps
--==========================================================================
local function samePlace(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.99999
end

local function smooth(agent: Agent, root: BasePart, now: number)
	local current = root.CFrame
	local snaps = agent.snaps
	if not agent.written or not samePlace(current, agent.written :: CFrame) then
		local last = snaps[#snaps]
		if last then
			local dt = now - last.t
			if dt > 0.005 and dt < 1 then
				agent.gap += (dt - agent.gap) * 0.2
			end
			if (current.Position - last.cf.Position).Magnitude > SMOOTH_SNAP then
				table.clear(snaps)
			end
		end
		table.insert(snaps, { t = now, cf = current })
		if #snaps > 4 then
			table.remove(snaps, 1)
		end
	end
	if #snaps < 2 then
		agent.written = current
		return
	end
	local at = now - math.clamp(agent.gap * SMOOTH_SHARE, SMOOTH_MIN, SMOOTH_MAX)
	local drawn = snaps[#snaps].cf
	for i = #snaps, 2, -1 do
		local a, b = snaps[i - 1], snaps[i]
		if at >= a.t then
			local span = b.t - a.t
			drawn = if span > 0 then a.cf:Lerp(b.cf, math.clamp((at - a.t) / span, 0, 1)) else b.cf
			break
		end
		drawn = a.cf
	end
	if not samePlace(drawn, current) then
		root.CFrame = drawn
	end
	agent.written = root.CFrame
end

local function release(agent: Agent)
	local root = agent.model.PrimaryPart
	local newest = agent.snaps[#agent.snaps]
	if root and newest and agent.written and samePlace(root.CFrame, agent.written :: CFrame) then
		root.CFrame = newest.cf
	end
	table.clear(agent.snaps)
	agent.written = nil
end

--==========================================================================
-- Bodies
--==========================================================================
local function findRig(agent: Agent): ClipPlayer.Rig?
	if agent.rig and ClipPlayer.alive(agent.rig :: ClipPlayer.Rig) then
		return agent.rig
	end
	agent.rig = ClipPlayer.rig(agent.model, agent.crawler == 1)
	-- each fist's rest frame, in the chest's space (the hold baked into the joints: tools/zombie/Hold)
	table.clear(agent.restFist)
	table.clear(agent.fists)
	if agent.rig then
		for _, side in { "Right", "Left" } do
			local hand = agent.model:FindFirstChild(side .. "Hand")
			local fist = hand and hand:FindFirstChild("Fist")
			if fist and fist:IsA("Attachment") then
				agent.fists[side] = fist
				agent.restFist[side] = ClipPlayer.hand(agent.rig :: ClipPlayer.Rig, {}, side) * fist.CFrame
			end
		end
	end
	-- the weapon's second grip, if it holds one in two hands
	local style = agent.style
	if agent.rig and style and style.twoHands then
		local other = if style.twoHands == "Left" then "RightHand" else "LeftHand"
		local holder = agent.model:FindFirstChild(other)
		agent.gripHand = if holder and holder:IsA("BasePart") then holder else nil
		local g = agent.model:FindFirstChild("Grip2", true)
		agent.grip2 = if g and g:IsA("Attachment") then g else nil
	end
	return agent.rig
end

local function activate(agent: Agent, on: boolean)
	if agent.active == on then
		return
	end
	agent.active = on
	if on then
		apply(agent)
	else
		if agent.rig then
			ClipPlayer.write(agent.rig :: ClipPlayer.Rig, {})
		end
		release(agent)
	end
end

local function remove(model: Model)
	local agent = agents[model]
	if not agent then
		return
	end
	agents[model] = nil
	for _, c in agent.connections do
		c:Disconnect()
	end
end

local function setup(instance: Instance)
	if not instance:IsA("Model") or agents[instance] then
		return
	end
	local model = instance
	local kind = model:GetAttribute("Unit") or model:GetAttribute("Type")
	local variant = model:GetAttribute("Variant")
	local hits = model:GetAttribute("HitCount")
	local crawlerVersion = model:GetAttribute("CrawlerVersion")
	local kindName = if typeof(kind) == "string" then kind else "undead_shambler"
	local agent: Agent = {
		model = model,
		rig = nil,
		kind = kindName,
		variant = if typeof(variant) == "number" then math.clamp(variant, 1, 3) else 1,
		style = ZombieAnims.STYLE[kindName],
		crawler = if model:GetAttribute("Crawler") == true then (if crawlerVersion == 2 then 2 else 1) else 0,
		seq = -1,
		hits = if typeof(hits) == "number" then hits else 0,
		active = false,
		connections = {},
		jitter = 0.88 + math.random() * 0.24,
		nextStumble = os.clock() + 4 + math.random() * 8,
		base = nil,
		baseOld = nil,
		baseKey = nil,
		holdLayer = nil,
		action = nil,
		overlays = {},
		pose = {},
		every = 1,
		waited = 0,
		grip2 = nil,
		gripHand = nil,
		actionGrips = nil,
		blockGrips = false,
		restFist = {},
		fists = {},
		snaps = {},
		gap = 0.05,
		written = nil,
	}
	if agent.crawler > 0 then
		agent.style = nil -- a crawler holds nothing
	end
	local s = set
	if s and agent.style then
		agent.holdLayer = layer(s.hold[agent.style.hold] or s.hold.tool, 1, 0, false, true)
	end
	agents[model] = agent

	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("Seq"):Connect(function()
			if agent.active then
				apply(agent)
			end
		end)
	)
	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("Move"):Connect(function()
			-- only the pace of a walk, a run or a crawl (re-applying would restart an attack in the middle)
			local state = model:GetAttribute("State")
			if agent.active and (state == "Walk" or state == "Run") then
				apply(agent)
			end
		end)
	)
	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("Guard"):Connect(function()
			if agent.active then
				guard(agent)
			end
		end)
	)
	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("HitCount"):Connect(function()
			local n = model:GetAttribute("HitCount")
			if typeof(n) == "number" and n > agent.hits and agent.active then
				flinch(agent)
			end
			agent.hits = if typeof(n) == "number" then n else agent.hits
		end)
	)
	table.insert(
		agent.connections,
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				remove(model)
			end
		end)
	)
	activate(agent, true)
end

function ZombieAnimController.Init() end

function ZombieAnimController.Start()
	--[[
		Clip lengths come from the same numbers the server's attacks use, by attack kind, so a swing's picture and its
		damage line up.
	]]
	local timings: { [string]: ZombieAnims.Timing } = {}
	local enemies = Config.get("Enemies")
	for enemyId, kind in ZombieAnims.KIND do
		local def = enemies[enemyId]
		local ai = def and def.AI
		local kinds = { kind }
		for _, v in ZombieAnims.VARIANTS[enemyId] or {} do
			table.insert(kinds, v)
		end
		for _, k in kinds do
			if ai and timings[k] == nil then
				timings[k] = { windup = ai.Windup or 0.8, strike = ai.Strike or 0.15, recover = ai.Recover or 0.6 }
			end
		end
	end
	-- the King's last face fights faster (Server/World/Trial/King tunes him): his cleave is timed for it
	timings.kingCleave = { windup = 1.0, strike = 0.25, recover = 1.0 }
	local ok, built = pcall(ZombieAnims.build, ClipPlayer, timings)
	if not ok then
		log:warn("could not build the dead's clips: " .. tostring(built))
		return
	end
	set = built

	for _, instance in CollectionService:GetTagged(TAG) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

	-- smooth steps, every frame, for the bodies near enough to be animated (a dead body lies where the server put it)
	RunService:BindToRenderStep("TLK_UndeadSmooth", Enum.RenderPriority.Camera.Value - 1, function()
		local now = os.clock()
		for model, agent in agents do
			local root = model.PrimaryPart
			if root and agent.active then
				if model:GetAttribute("State") == "Death" then
					if agent.written then
						release(agent)
					end
				else
					smooth(agent, root, now)
				end
			end
		end
	end)

	-- the pose, at PreSimulation (an AnimationConstraint takes its Transform inside the physics step)
	RunService.PreSimulation:Connect(function(dt: number)
		frame += 1
		for _, agent in agents do
			if agent.active then
				agent.waited += dt
				if frame % agent.every == 0 then
					if findRig(agent) then
						compose(agent, agent.waited)
					end
					agent.waited = 0
				end
			end
		end
	end)

	-- who is near, a few times a second
	task.spawn(function()
		while true do
			local camera = Workspace.CurrentCamera
			if camera then
				local eye = camera.CFrame.Position
				local now = os.clock()
				for model, agent in agents do
					local root = model.PrimaryPart
					if root then
						local d = (root.Position - eye).Magnitude
						activate(agent, d <= ACTIVE_RANGE)
						agent.every = if d <= NEAR then 1 elseif d <= MID then 2 else 3
						maybeStumble(agent, now)
					end
				end
			end
			task.wait(STEP_SECONDS)
		end
	end)

	log:info("ready")
end

return ZombieAnimController
