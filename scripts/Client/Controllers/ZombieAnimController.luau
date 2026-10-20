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

	Place: client (boots in both places; nothing in the Hub carries the tag).
	Phase: Enemy AI / Presentation.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local FADE = 0.2

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

local function play(agent: Agent, key: string, id: string, fade: number, speed: number?)
	local t = track(agent, key, id)
	if not t.IsPlaying then
		t:Play(fade)
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

	if state == "Walk" then
		stopLoops(agent, "walk")
		play(agent, "walk", set.walk[agent.variant], FADE, math.max(0.4, move / WALK_PACE))
	elseif state == "Run" then
		stopLoops(agent, "run")
		play(agent, "run", set.run, FADE, math.max(0.5, move / RUN_PACE))
	elseif state == "Aggro" then
		stopLoops(agent, nil)
		local t = track(agent, "aggro", set.aggro)
		t:Play(0.08)
	elseif state == "Windup" then
		stopLoops(agent, nil)
		local id = set.attack[set.kindOf[agent.kind] or "shove"] or set.attack.shove
		local t = track(agent, "attack", id)
		if t.IsPlaying then
			t:Stop(0)
		end
		t:Play(0.08)
	elseif state == "Death" then
		stopAll(agent, 0.05)
		local fall = model:GetAttribute("Fall")
		local n = if typeof(fall) == "number" then math.clamp(fall, 1, #set.death) else 1
		local t = track(agent, "death" .. n, set.death[n])
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

local function activate(agent: Agent, on: boolean)
	if agent.active == on then
		return
	end
	agent.active = on
	if on then
		apply(agent)
	else
		stopAll(agent, 0)
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
					walk:AdjustSpeed(math.max(0.4, pace / WALK_PACE))
				end
				if run and run.IsPlaying then
					run:AdjustSpeed(math.max(0.5, pace / RUN_PACE))
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

	task.spawn(function()
		while true do
			local camera = Workspace.CurrentCamera
			if camera then
				local eye = camera.CFrame.Position
				for model, agent in agents do
					local root = model.PrimaryPart
					if root then
						activate(agent, (root.Position - eye).Magnitude <= ACTIVE_RANGE)
					end
				end
			end
			task.wait(STEP_SECONDS)
		end
	end)

	log:info("ready")
end

return ZombieAnimController
