--!strict
--[[
	MovementController
	Your own running and dashing, and the stamina bar (docs/systems/Movement.md, configs/Movement). The bodies
	themselves (the walk, the run, the roll that the others see) are drawn by Controllers/BodyAnimController; what the
	eyes do is Controllers/ViewController.

	  RUN    Shift held asks the server to run (`RequestRun`); the server keeps the stamina and the speed
	         (Server/Services/MovementService). A phone has a run button that stays on until pressed again.

	  DASH   Q (a button on a phone): the way the movement keys point (as the eyes see them), straight ahead when none
	         is held. If the bar holds a dash's worth, this client goes at once (it owns its body's physics): the body
	         is carried `Roll.Distance` studs in `Roll.Seconds`, fast at first and slowing (`Roll.Ease`), no jumping
	         meanwhile; the server spends the stamina and tells everybody else, who see a roll that way.
	         (2026-11-10, why it no longer catches: it used to turn the body over INSIDE its own collision box, so the
	         head and chest struck the ground half way round, and it set the body's facing by hand at the start. Now
	         your own body is only carried: the tumble is drawn on the other players' screens, where nothing collides,
	         and the eyes dip instead.)

	  STAMINA BAR  The blue bar under the health bar (UI/StaminaBar), from the `Stamina` the server publishes.

	Place: client (boots in both places).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local StaminaBar = require(Client.UI.StaminaBar)
local IconButton = require(Client.UI.IconButton)
local ViewController = require(script.Parent.ViewController)

local MovementController = {}

MovementController.Name = "MovementController"

local log = Logger.new("MovementController")

local player = Players.LocalPlayer
local cfg: any = nil

--==========================================================================
-- Your own run and dash
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

	-- carry the body: along the ground only (gravity keeps its own say), fast and slowing. Nothing else about the body
	-- is touched: it keeps facing where the eyes look, and its joints keep their walk.
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

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	rolling = { start = now, dir = dir, v0 = v0, force = force, attachment = attachment, humanoid = humanoid }
	-- the eyes: down and up, leaning away from a dash to the side
	ViewController.dash(root.CFrame:VectorToObjectSpace(dir).X, cfg.Roll.Seconds)
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
function MovementController.Init() end

function MovementController.Start()
	cfg = Config.get("Movement")
	runEvent = Net.getEvent("RequestRun")
	rollEvent = Net.getEvent("RequestRoll")

	RunService.PreSimulation:Connect(function()
		stepRoll(os.clock())
	end)

	-- Shift: run while held (it is not Roblox's Shift lock: the server switches that off)
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

	-- a phone: a run button (on until pressed again) and a dash button, beside the crouch button
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

	player.CharacterAdded:Connect(function()
		endRoll()
		-- a new body has a full bar: keep asking to run if Shift is still down
		if shiftHeld or runToggle then
			task.delay(0.5, function()
				sendRun(shiftHeld or runToggle)
			end)
		end
	end)

	log:info(("ready: Shift runs, %s dashes"):format(cfg.Roll.Key))
end

return MovementController
