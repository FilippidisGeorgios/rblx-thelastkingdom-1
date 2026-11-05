--!strict
--[[
	ZombieAnimController
	Plays the dead's clips (Shared/Anim/ZombieAnims) on every body the server has
	tagged "TLK_Undead", from the attributes the server writes on it:

	    State   Idle | Walk | Run | Aggro | Windup | Strike | Recover | Death
	    Seq     counts state changes, so the same state twice still replays
	    Move    its speed, to scale a walk or a run to its pace
	    Variant 1..3, which gait this body walks for life
	    HitCount goes up on every wound: the body flinches
	    Fall    1..3, which fall it takes when it dies

	NOTHING is sent per frame. The server (EnemyAIService / EnemyService) writes an
	attribute when the state changes and every client works out the picture from
	it, which is also why a body that streams in late arrives already doing the
	right thing: its attributes are on it.

	WHY CLIENT ONLY. A clip registered with KeyframeSequenceProvider exists on the
	machine that registered it, so every client builds the same set and plays it on
	every body it can see (the same way WeaponAnimController poses the sword).

	DISTANCE. A body further than ACTIVE_RANGE from the camera is not animated at
	all: its tracks are stopped and it stands in its baked rest pose, which is what
	a body that far is. They come back as it nears.

	SMOOTH STEPS (2026-11-05). The server moves a body by setting its anchored root
	a few times a second (the Huntsman ten times), and an anchored part's new place
	reaches a client as a jump, not a glide: at 100 frames a second he hopped 0.72
	studs nine times a second while his legs walked smoothly. So within ACTIVE_RANGE
	every frame draws the root a little behind the server, between the last two
	places it sent (SMOOTH_* below). A jump longer than SMOOTH_SNAP is a teleport and
	is shown at once. Only the picture changes: hits, reach and sight stay on the
	server's own numbers.

	Place: client (boots in both places; nothing in the Hub carries the tag).
	Phase: Enemy AI / Presentation.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ZombieAnims = require(ReplicatedStorage.Shared.Anim.ZombieAnims)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local ZombieAnimController = {}

ZombieAnimController.Name = "ZombieAnimController"

local log = Logger.new("ZombieAnimController")

local TAG = "TLK_Undead"
local ACTIVE_RANGE = 170
local STEP_SECONDS = 0.25
local WALK_PACE = 7 -- the speed a walk clip is authored for
local RUN_PACE = 15
local CRAWL_PACE = 6 -- the speed the crawl clip is authored for
local FADE = 0.2

-- smooth steps: how far behind the server a body is drawn (a share of the gap between its updates, within limits)
local SMOOTH_SHARE = 1.15
local SMOOTH_MIN = 0.02
local SMOOTH_MAX = 0.2
local SMOOTH_SNAP = 12 -- studs: a longer jump is a teleport, shown at once

type Snapshot = { t: number, cf: CFrame }

type Agent = {
	model: Model,
	animator: Animator,
	kind: string,
	variant: number,
	tracks: { [string]: AnimationTrack },
	seq: number,
	hits: number,
	active: boolean,
	connections: { RBXScriptConnection },
	jitter: number, -- this body's own pace, a little off everyone else's
	nextStumble: number,
	crawler: boolean, -- no legs (the attribute CrawlerBody sets): it crawls and dies where it lies
	-- smooth steps
	snaps: { Snapshot }, -- the last places the server sent, oldest first
	gap: number, -- the usual time between them
	written: CFrame?, -- what this client last drew, to tell it from a new place from the server
}

local ids: ZombieAnims.Ids? = nil
local agents: { [Model]: Agent } = {}

local LOOPS = { "idle", "walk", "run" }

local function track(agent: Agent, key: string, id: string): AnimationTrack
	local t = agent.tracks[key]
	if not t then
		local animation = Instance.new("Animation")
		animation.Name = key
		animation.AnimationId = id
		t = agent.animator:LoadAnimation(animation)
		agent.tracks[key] = t
	end
	return t
end

local function stopLoops(agent: Agent, except: string?)
	for _, key in LOOPS do
		local t = agent.tracks[key]
		if t and key ~= except and t.IsPlaying then
			t:Stop(FADE)
		end
	end
end

local function stopAll(agent: Agent, fade: number)
	for _, t in agent.tracks do
		if t.IsPlaying then
			t:Stop(fade)
		end
	end
end

-- `desync`: a loop that starts starts at a random point of itself, so a crowd of the dead never steps in time (2026-11-03)
local function play(agent: Agent, key: string, id: string, fade: number, speed: number?, desync: boolean?)
	local t = track(agent, key, id)
	if not t.IsPlaying then
		t:Play(fade)
		if desync and t.Length > 0 then
			t.TimePosition = math.random() * t.Length
		end
	end
	t:AdjustSpeed(speed or 1)
end

--[[
	Brings the body to whatever its State says it is doing right now.
]]
local function apply(agent: Agent)
	local set = ids
	if not set or not agent.active then
		return
	end
	local model = agent.model
	local state = model:GetAttribute("State")
	local pace = model:GetAttribute("Move")
	local move = if typeof(pace) == "number" then pace else 0

	if agent.crawler and (state == "Walk" or state == "Run") then
		-- no legs: walking and running are the same pull, faster
		stopLoops(agent, "walk")
		play(agent, "walk", set.crawl, FADE, math.max(0.5, move / CRAWL_PACE) * agent.jitter, true)
	elseif state == "Walk" then
		stopLoops(agent, "walk")
		play(agent, "walk", set.walk[agent.variant], FADE, math.max(0.4, move / WALK_PACE) * agent.jitter, true)
	elseif state == "Run" then
		stopLoops(agent, "run")
		play(agent, "run", set.run, FADE, math.max(0.5, move / RUN_PACE) * agent.jitter, true)
	elseif state == "Aggro" then
		stopLoops(agent, nil)
		local t = track(agent, "aggro", set.aggro)
		t:Play(0.08)
	elseif state == "Windup" then
		stopLoops(agent, nil)
		-- A unit that fights three ways (the King) says which one it is doing right now.
		local override = model:GetAttribute("AttackKind")
		local kindName = if typeof(override) == "string" then override else set.kindOf[agent.kind]
		local id = set.attack[kindName or "shove"] or set.attack.shove
		local t = track(agent, "attack", id)
		if t.IsPlaying then
			t:Stop(0)
		end
		t:Play(0.08)
	elseif state == "Death" then
		stopAll(agent, 0.05)
		local fall = model:GetAttribute("Fall")
		local n = if typeof(fall) == "number" then math.clamp(fall, 1, #set.death) else 1
		-- a crawler is already down: it dies where it lies
		local t = if agent.crawler then track(agent, "crawlDeath", set.crawlDeath) else track(agent, "death" .. n, set.death[n])
		t:Play(0.05)
		-- hold the last pose: a clip that ends returns to rest, and a corpse standing up is worse than none
		task.delay(math.max(0, t.Length - 0.04), function()
			if t.IsPlaying then
				t:AdjustSpeed(0)
			end
		end)
	elseif state == "Idle" then
		stopLoops(agent, "idle")
		play(agent, "idle", set.idle, FADE, 1)
	end
	-- Strike and Recover belong to the attack clip already running.
end

local function flinch(agent: Agent)
	local set = ids
	if not set or not agent.active then
		return
	end
	if agent.model:GetAttribute("State") == "Death" then
		return
	end
	local t = track(agent, "flinch", set.flinch)
	t:Play(0.03)
end

-- Now and then a walking body stumbles: a knee gives and it catches itself (an overlay; the legs go on walking).
local function maybeStumble(agent: Agent, now: number)
	local set = ids
	if not set or not agent.active or agent.crawler or now < agent.nextStumble then
		return
	end
	agent.nextStumble = now + 6 + math.random() * 9
	if agent.model:GetAttribute("State") ~= "Walk" then
		return
	end
	local t = track(agent, "stumble", set.stumble)
	t:Play(0.06)
	t:AdjustSpeed(0.85 + math.random() * 0.3)
end

local function samePlace(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.99999
end

--[[
	One frame of smooth steps for one body. Whatever the root holds now is either what this client drew last frame or a
	new place the server has just sent (it overwrote the drawing): a new place is kept with the time it came. The root is
	then drawn `delay` behind now, between the two places around that moment.
]]
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
				table.clear(snaps) -- a teleport: no gliding across the map
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

-- the server's own place again (a body that goes out of range or dies is left exactly where the server put it)
local function release(agent: Agent)
	local root = agent.model.PrimaryPart
	local newest = agent.snaps[#agent.snaps]
	if root and newest and agent.written and samePlace(root.CFrame, agent.written :: CFrame) then
		root.CFrame = newest.cf
	end
	table.clear(agent.snaps)
	agent.written = nil
end

local function activate(agent: Agent, on: boolean)
	if agent.active == on then
		return
	end
	agent.active = on
	if on then
		apply(agent)
	else
		stopAll(agent, 0)
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
	stopAll(agent, 0)
end

local function setup(instance: Instance)
	if not instance:IsA("Model") or agents[instance] then
		return
	end
	local model = instance
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return -- not streamed in whole yet; the tag fires again if it is re-added
	end
	local kind = model:GetAttribute("Type")
	local variant = model:GetAttribute("Variant")
	local hits = model:GetAttribute("HitCount")
	local agent: Agent = {
		model = model,
		animator = animator,
		kind = if typeof(kind) == "string" then kind else "undead_shambler",
		variant = if typeof(variant) == "number" then math.clamp(variant, 1, 3) else 1,
		tracks = {},
		seq = -1,
		hits = if typeof(hits) == "number" then hits else 0,
		active = false,
		connections = {},
		jitter = 0.88 + math.random() * 0.24,
		nextStumble = os.clock() + 4 + math.random() * 8,
		crawler = model:GetAttribute("Crawler") == true,
		snaps = {},
		gap = 0.05,
		written = nil,
	}
	agents[model] = agent

	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("Seq"):Connect(function()
			apply(agent)
		end)
	)
	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("Move"):Connect(function()
			local pace = model:GetAttribute("Move")
			local walk, run = agent.tracks.walk, agent.tracks.run
			if typeof(pace) == "number" then
				if walk and walk.IsPlaying then
					local speed = if agent.crawler then math.max(0.5, pace / CRAWL_PACE) else math.max(0.4, pace / WALK_PACE)
					walk:AdjustSpeed(speed * agent.jitter)
				end
				if run and run.IsPlaying then
					run:AdjustSpeed(math.max(0.5, pace / RUN_PACE) * agent.jitter)
				end
			end
		end)
	)
	table.insert(
		agent.connections,
		model:GetAttributeChangedSignal("HitCount"):Connect(function()
			local n = model:GetAttribute("HitCount")
			if typeof(n) == "number" and n > agent.hits then
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
		Clip lengths come from the same numbers the server's attacks use, by attack
		kind, so a swing's picture and its damage line up.
	]]
	local timings: { [string]: ZombieAnims.Timing } = {}
	local enemies = Config.get("Enemies")
	for enemyId, kind in ZombieAnims.KIND do
		local def = enemies[enemyId]
		local ai = def and def.AI
		if ai and timings[kind] == nil then
			timings[kind] = { windup = ai.Windup or 0.8, strike = ai.Strike or 0.15, recover = ai.Recover or 0.6 }
		end
	end

	local registered, why = ZombieAnims.register(timings)
	if not registered then
		log:warn("could not register the dead's clips: " .. tostring(why))
		return
	end
	ids = registered

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

	task.spawn(function()
		while true do
			local camera = Workspace.CurrentCamera
			if camera then
				local eye = camera.CFrame.Position
				local now = os.clock()
				for model, agent in agents do
					local root = model.PrimaryPart
					if root then
						activate(agent, (root.Position - eye).Magnitude <= ACTIVE_RANGE)
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
