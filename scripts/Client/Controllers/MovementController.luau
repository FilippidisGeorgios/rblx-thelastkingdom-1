--!strict
--[[
	MovementController
	How every player moves, on this client (docs/systems/Movement.md, configs/Movement):

	  THE BODIES. Every player this client can see (you too) is posed by our own clips (Shared/Anim/PlayerMoveAnims)
	  through Shared/Anim/ClipPlayer: idle, walk, run, jump, fall, sit, climb, blended over a fifth of a second, and the
	  roll laid on top. Roblox's own `Animate` script is switched off on your body (and every client switches off its
	  own), so nothing else moves the limbs. The set everybody walks with is `Movement.Style` (the workspace attribute
	  `TLK_MoveStyle` overrides it for a test). Which clip: the body's speed along the ground (a run is anything faster
	  than walking can be), whether it stands on something, and the server's `RollSeq`.
	  While someone's sword is drawn their sword arm is left to the sword (WeaponAnimController).

	  RUN. Shift held asks the server to run (`RequestRun`); the server keeps the stamina and the speed
	  (Server/Services/MovementService). A phone has a run button that stays on until pressed again.

	  ROLL. Q (a button on a phone): the way the movement keys point (as the camera sees them), straight ahead when
	  none is held. If the bar holds a roll's worth, this client rolls at once (it owns its body's physics): the body
	  turns that way and is carried `Roll.Distance` studs in `Roll.Seconds`, fast at first and slowing (`Roll.Ease`),
	  no jumping meanwhile; the server spends the stamina and tells everybody else to draw it.

	  STAMINA BAR. The blue bar under the health bar (UI/StaminaBar), from the `Stamina` the server publishes.

	  MOUSE LOCK. The Settings switch (`MouseLock` on the player, kept by SettingsService). On: the mouse is held in the
	  middle under a very small dot, the camera sits over the right shoulder and the body faces where the camera looks.
	  It lets go while any panel is open, while the Roblox menu is open, while typing, and while Left Alt is held.

	Place: client (boots in both places).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local ClipPlayer = require(ReplicatedStorage.Shared.Anim.ClipPlayer)
local PlayerMoveAnims = require(ReplicatedStorage.Shared.Anim.PlayerMoveAnims)
local StaminaBar = require(Client.UI.StaminaBar)
local IconButton = require(Client.UI.IconButton)

local MovementController = {}

MovementController.Name = "MovementController"

local log = Logger.new("MovementController")

local player = Players.LocalPlayer
local cfg: any = nil

local FADE = 0.18 -- seconds a loop takes to blend into the next
local RUN_ABOVE = 19.5 -- studs a second along the ground: faster than any walk (the Brass Stirrup walks 17.3)
local IDLE_BELOW = 0.8
local FALL_AFTER = 0.16 -- seconds off the ground before a step down becomes a fall
local ROLL_IN, ROLL_OUT = 0.04, 0.07 -- the roll's blend in and out, seconds of its own clip
local RIGHT_ARM = { RightUpperArm = true, RightLowerArm = true, RightHand = true }

--==========================================================================
-- The clips
--==========================================================================
local built: { [number]: { [string]: ClipPlayer.Clip } } = {}

local function clipsFor(set: number): { [string]: ClipPlayer.Clip }
	local have = built[set]
	if have then
		return have
	end
	local made: { [string]: ClipPlayer.Clip } = {}
	for name, def in PlayerMoveAnims.clips(set) do
		made[name] = ClipPlayer.clip(PlayerMoveAnims.name(set) .. "_" .. name, def.frames, def.looped)
	end
	built[set] = made
	return made
end

local function currentSet(): number
	local s = Workspace:GetAttribute("TLK_MoveStyle")
	if typeof(s) == "number" and s >= 1 and s <= PlayerMoveAnims.COUNT then
		return math.floor(s)
	end
	return cfg.Style
end

--==========================================================================
-- The bodies
--==========================================================================
type Layer = { time: number, weight: number, speed: number }

type Body = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	rig: ClipPlayer.Rig,
	userId: number,
	want: string,
	layers: { [string]: Layer },
	rollSeq: number?,
	rollAt: number?, -- when the roll began (os.clock())
	rollRate: number,
	airAt: number?,
	jumped: boolean,
	ray: RaycastParams,
}

local bodies: { [Model]: Body } = {}
local armed: { [number]: boolean } = {} -- by UserId: the sword is drawn
local localRollAt = -math.huge

local function moveToward(x: number, target: number, step: number): number
	if x < target then
		return math.min(target, x + step)
	end
	return math.max(target, x - step)
end

local function isMine(body: Body): boolean
	return body.character == player.Character
end

local function onGround(body: Body): boolean
	local humanoid = body.humanoid
	if isMine(body) then
		return humanoid.FloorMaterial ~= Enum.Material.Air
	end
	local reach = humanoid.HipHeight + body.root.Size.Y / 2 + 0.9
	return Workspace:Raycast(body.root.Position, Vector3.new(0, -reach, 0), body.ray) ~= nil
end

local function startRoll(body: Body, now: number)
	body.rollAt = now
	body.rollRate = PlayerMoveAnims.ROLL_LENGTH / cfg.Roll.Seconds
end

-- which loop the body should be in, and how fast it plays
local function choose(body: Body, now: number): (string, number)
	local humanoid = body.humanoid
	local v = body.root.AssemblyLinearVelocity
	local along = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = if isMine(body) then humanoid:GetState() else nil
	if humanoid.Sit then
		body.airAt = nil
		return "sit", 1
	end
	if state == Enum.HumanoidStateType.Climbing then
		body.airAt = nil
		return "climb", math.clamp(math.abs(v.Y) / 8, 0.2, 1.5)
	end
	if state == Enum.HumanoidStateType.Swimming then
		body.airAt = nil
		return "walk", 0.55
	end
	if not onGround(body) then
		if body.airAt == nil then
			body.airAt = now
			body.jumped = v.Y > 4
		end
		local airAt = body.airAt :: number
		if body.jumped and now - airAt < 0.55 and v.Y > -6 then
			return "jump", 1
		end
		if body.jumped or now - airAt > FALL_AFTER then
			return "fall", 1
		end
		-- a step down: stay in what it was doing
		return body.want, (body.layers[body.want] and body.layers[body.want].speed) or 1
	end
	body.airAt = nil
	body.jumped = false
	if along < IDLE_BELOW then
		return "idle", 1
	elseif along > RUN_ABOVE then
		return "run", math.clamp(along / PlayerMoveAnims.RUN_PACE, 0.6, 1.4)
	end
	return "walk", math.clamp(along / PlayerMoveAnims.WALK_PACE, 0.45, 1.35)
end

local function stepBody(body: Body, dt: number, now: number, clips: { [string]: ClipPlayer.Clip })
	local humanoid = body.humanoid
	if humanoid.Health <= 0 or not body.root.Parent then
		return
	end
	-- a body at work is posed by WorkPoseController
	if body.character:GetAttribute("WorkPose") ~= nil then
		return
	end

	-- a roll the server announced (your own was drawn the moment you pressed)
	local seq = humanoid:GetAttribute("RollSeq")
	if typeof(seq) == "number" and seq ~= body.rollSeq then
		local first = body.rollSeq == nil
		body.rollSeq = seq
		if not first and not (isMine(body) and now - localRollAt < 0.6) then
			startRoll(body, now)
		end
	end

	local want, speed = choose(body, now)
	if want ~= body.want then
		local old = body.layers[body.want]
		local layer = body.layers[want]
		if not layer then
			layer = { time = 0, weight = 0, speed = speed }
			body.layers[want] = layer
		end
		-- walk <-> run keep the step they are on, so the feet do not jump
		if old and (want == "walk" or want == "run") and (body.want == "walk" or body.want == "run") then
			local from, to = clips[body.want], clips[want]
			if from.length > 0 then
				layer.time = (old.time % from.length) / from.length * to.length
			end
		elseif want == "jump" then
			layer.time = 0
		end
		body.want = want
	end

	for name, layer in body.layers do
		local here = name == body.want
		layer.weight = moveToward(layer.weight, if here then 1 else 0, dt / FADE)
		if here then
			layer.speed = speed
		end
		layer.time += dt * layer.speed
		if not here and layer.weight <= 0 then
			body.layers[name] = nil
		end
	end

	local pose: { [string]: CFrame } = {}
	local total = 0
	for name, layer in body.layers do
		local clip = clips[name]
		if clip and layer.weight > 0 then
			total += layer.weight
			ClipPlayer.sample(clip, layer.time, pose, layer.weight / total)
		end
	end
	local rollAt = body.rollAt
	if rollAt then
		local roll = clips.roll
		local t = (now - rollAt) * body.rollRate
		if t >= roll.length then
			body.rollAt = nil
		else
			local w = math.min(1, t / ROLL_IN, (roll.length - t) / ROLL_OUT)
			ClipPlayer.sample(roll, t, pose, math.clamp(w, 0, 1))
		end
	end
	ClipPlayer.write(body.rig, pose, if armed[body.userId] then RIGHT_ARM else nil)
end

local function forget(character: Model)
	bodies[character] = nil
end

local function adopt(target: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 15)
		local root = character:WaitForChild("HumanoidRootPart", 15)
		if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
			return
		end
		-- your own body: Roblox's own walk and idle stop, ours take over
		if target == player then
			local animate = character:WaitForChild("Animate", 5)
			if animate and animate:IsA("LocalScript") then
				animate.Enabled = false
			end
			task.defer(function()
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					for _, track in animator:GetPlayingAnimationTracks() do
						local id = track.Animation and track.Animation.AnimationId or ""
						-- Roblox's own clips are real assets; the sword's are ours and stay
						if id:find("roblox.com/asset") or id:find("rbxassetid://") then
							track:Stop(0.1)
						end
					end
				end
			end)
		end
		-- the joints arrive with the body; a body that streams in late may need a moment
		local rig = ClipPlayer.rig(character)
		local tries = 0
		while not rig and tries < 40 and character.Parent do
			task.wait(0.25)
			tries += 1
			rig = ClipPlayer.rig(character)
		end
		if not rig then
			return
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { character }
		ray.IgnoreWater = false
		bodies[character] = {
			character = character,
			humanoid = humanoid,
			root = root,
			rig = rig,
			userId = target.UserId,
			want = "idle",
			layers = { idle = { time = math.random() * 6, weight = 1, speed = 1 } },
			rollSeq = nil,
			rollAt = nil,
			rollRate = 1,
			airAt = nil,
			jumped = false,
			ray = ray,
		}
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				forget(character)
			end
		end)
	end)
end

local function watch(target: Player)
	target.CharacterAdded:Connect(function(character)
		adopt(target, character)
	end)
	if target.Character then
		adopt(target, target.Character)
	end
end

--==========================================================================
-- Your own run and roll
--==========================================================================
local runEvent: RemoteEvent? = nil
local rollEvent: RemoteEvent? = nil
local shiftHeld = false
local runToggle = false -- the phone's button

type Rolling = {
	start: number,
	dir: Vector3,
	v0: number,
	force: LinearVelocity,
	attachment: Attachment,
	humanoid: Humanoid,
	autoRotate: boolean,
}
local rolling: Rolling? = nil
local nextRollAt = 0

local function sendRun(on: boolean)
	if runEvent then
		runEvent:FireServer(on)
	end
end

local function endRoll()
	local r = rolling
	if not r then
		return
	end
	rolling = nil
	r.force:Destroy()
	r.attachment:Destroy()
	if r.humanoid.Parent then
		r.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		r.humanoid.AutoRotate = r.autoRotate
	end
	nextRollAt = os.clock() + cfg.Roll.Gap
end

local function tryRoll()
	local now = os.clock()
	if rolling or now < nextRollAt then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	if player:GetAttribute("Crouching") == true then
		return
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
		return
	end
	local bar = player:GetAttribute("Stamina")
	if typeof(bar) == "number" and bar + 1e-3 < cfg.Roll.Cost then
		return -- not enough left: the bar is already the darker blue that says so
	end
	local move = humanoid.MoveDirection
	local dir = Vector3.new(move.X, 0, move.Z)
	if dir.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
	end
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	if rollEvent then
		rollEvent:FireServer(dir)
	end

	-- carry the body: along the ground only (gravity keeps its own say), fast and slowing
	local average = cfg.Roll.Distance / cfg.Roll.Seconds
	local v0 = average / (1 - cfg.Roll.Ease / 2)
	local attachment = Instance.new("Attachment")
	attachment.Name = "TLK_RollAttachment"
	attachment.Parent = root
	local force = Instance.new("LinearVelocity")
	force.Name = "TLK_Roll"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	force.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	force.VectorVelocity = dir * v0
	force.Parent = root

	local autoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	rolling = { start = now, dir = dir, v0 = v0, force = force, attachment = attachment, humanoid = humanoid, autoRotate = autoRotate }
	localRollAt = now
	local body = character and bodies[character :: Model]
	if body then
		startRoll(body, now)
	end
end

local function stepRoll(now: number)
	local r = rolling
	if not r then
		return
	end
	local t = (now - r.start) / cfg.Roll.Seconds
	if t >= 1 or not r.force.Parent or r.humanoid.Health <= 0 then
		endRoll()
		return
	end
	r.force.VectorVelocity = r.dir * (r.v0 * (1 - cfg.Roll.Ease * t))
end

--==========================================================================
-- The mouse lock
--==========================================================================
local dot: Frame? = nil
local lockActive = false
local lockHumanoid: Humanoid? = nil
local panelOpen = false
local panelCheckedAt = 0

-- Is a panel (or anything else that needs the mouse) open? Panels are the screens drawn at order 15 and above (the
-- Settings, the Muster Roll, a page, the forge...) and the backpack's open pack.
local function lookForPanels(): boolean
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return false
	end
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and screen.DisplayOrder >= 15 and screen.Name ~= "MouseLockDot" then
			for _, child in screen:GetChildren() do
				if child:IsA("GuiObject") and child.Visible then
					return true
				end
			end
		end
	end
	local pack = gui:FindFirstChild("BackpackHud")
	local open = pack and pack:FindFirstChild("Pack", true)
	return open ~= nil and open:IsA("GuiObject") and open.Visible
end

local function mouseFree(now: number): boolean
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
		return true
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		return true
	end
	if now - panelCheckedAt > 0.2 then
		panelCheckedAt = now
		panelOpen = lookForPanels()
	end
	return panelOpen
end

local function lockOff()
	if not lockActive then
		return
	end
	lockActive = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if dot then
		dot.Visible = false
	end
	local humanoid = lockHumanoid
	if humanoid and humanoid.Parent then
		if (humanoid.CameraOffset - Vector3.new(cfg.MouseLock.ShoulderOffset, 0, 0)).Magnitude < 1e-3 then
			humanoid.CameraOffset = Vector3.zero
		end
		if not rolling then
			humanoid.AutoRotate = true
		end
	end
	lockHumanoid = nil
end

local function stepLock()
	local now = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local wanted = player:GetAttribute("MouseLock") == true
		and UserInputService.MouseEnabled
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and not mouseFree(now)
	if not wanted or not humanoid or not root or not root:IsA("BasePart") then
		lockOff()
		return
	end
	if lockHumanoid ~= humanoid then
		lockOff()
	end
	if not lockActive then
		lockActive = true
		lockHumanoid = humanoid
		humanoid.CameraOffset = Vector3.new(cfg.MouseLock.ShoulderOffset, 0, 0)
		if not rolling then
			humanoid.AutoRotate = false
		end
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	if dot then
		dot.Visible = true
	end
	-- the body faces where the camera looks (not while rolling, sitting or climbing)
	local camera = Workspace.CurrentCamera
	if camera and not rolling and not humanoid.Sit and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
end

local function makeDot(): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "MouseLockDot"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the true middle of the screen, where the mouse is held
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(cfg.MouseLock.DotSize, cfg.MouseLock.DotSize)
	d.BackgroundColor3 = cfg.MouseLock.DotColor
	d.BackgroundTransparency = cfg.MouseLock.DotTransparency
	d.BorderSizePixel = 0
	d.Visible = false
	d.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = d
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Thickness = 1
	edge.Transparency = 0.35
	edge.Parent = d
	return d
end

--==========================================================================
function MovementController.Init() end

function MovementController.Start()
	cfg = Config.get("Movement")
	runEvent = Net.getEvent("RequestRun")
	rollEvent = Net.getEvent("RequestRoll")

	-- every player's body
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		armed[p.UserId] = nil
	end)
	Net.getEvent("WeaponState").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.userId) == "number" then
			armed[payload.userId] = payload.drawn == true
		end
	end)

	-- the poses go on before the physics step: Roblox's upgraded joints only take a pose written there
	RunService.PreSimulation:Connect(function(dt: number)
		local now = os.clock()
		stepRoll(now)
		local clips = clipsFor(currentSet())
		for _, body in bodies do
			stepBody(body, dt, now, clips)
		end
	end)

	-- Shift: run while held (it is not Roblox's Shift lock any more: the server switches that off)
	ContextActionService:BindAction("TLKRun", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			shiftHeld = true
			sendRun(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			shiftHeld = false
			sendRun(runToggle)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[cfg.Run.Key], Enum.KeyCode.ButtonL3)
	-- a window that loses the keyboard never hears Shift come up
	UserInputService.WindowFocusReleased:Connect(function()
		if shiftHeld then
			shiftHeld = false
			sendRun(runToggle)
		end
	end)

	ContextActionService:BindAction("TLKRoll", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			tryRoll()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[cfg.Roll.Key], Enum.KeyCode.ButtonB)

	-- the stamina bar, under the health bar
	local gui = Instance.new("ScreenGui")
	gui.Name = "StaminaGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = StaminaBar.create(gui)
	local function drawBar()
		local value = player:GetAttribute("Stamina")
		local max = player:GetAttribute("StaminaMax")
		bar.set(if typeof(value) == "number" then value else cfg.Stamina.Max, if typeof(max) == "number" then max else cfg.Stamina.Max, cfg.Roll.Cost)
	end
	player:GetAttributeChangedSignal("Stamina"):Connect(drawBar)
	player:GetAttributeChangedSignal("StaminaMax"):Connect(drawBar)
	drawBar()

	-- a phone: a run button (on until pressed again) and a roll button, beside the crouch button
	if UserInputService.TouchEnabled then
		local buttons = Instance.new("ScreenGui")
		buttons.Name = "MoveButtons"
		buttons.ResetOnSpawn = false
		buttons.DisplayOrder = 6
		buttons.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		buttons.Parent = player:WaitForChild("PlayerGui")
		local runButton
		runButton = IconButton.create({
			Name = "Run",
			Parent = buttons,
			Icon = "run",
			IconSize = 30,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -214, 1, -150),
			Size = UDim2.fromOffset(56, 56),
			OnClick = function()
				runToggle = not runToggle
				sendRun(runToggle or shiftHeld)
				runButton.setActive(runToggle)
			end,
		})
		IconButton.create({
			Name = "Roll",
			Parent = buttons,
			Icon = "roll",
			IconSize = 32,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -150, 1, -214),
			Size = UDim2.fromOffset(56, 56),
			OnClick = tryRoll,
		})
	end

	-- the mouse lock and its dot
	dot = makeDot()
	RunService:BindToRenderStep("TLK_MouseLock", Enum.RenderPriority.Camera.Value - 1, stepLock)
	player.CharacterAdded:Connect(function()
		lockOff()
		endRoll()
		-- a new body has a full bar: keep asking to run if Shift is still down
		if shiftHeld or runToggle then
			task.delay(0.5, function()
				sendRun(shiftHeld or runToggle)
			end)
		end
	end)

	log:info(("ready: set %d (%s), Shift runs, %s rolls"):format(currentSet(), PlayerMoveAnims.name(currentSet()), cfg.Roll.Key))
end

return MovementController
