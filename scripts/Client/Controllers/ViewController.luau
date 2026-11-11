--!strict
--[[
	ViewController
	How this player SEES the game (configs/View, docs/systems/FirstPerson.md): through the character's own eyes, in both
	places, with the mouse always held in the middle. The developer's decision of 2026-11-10 ("full screen", as DOORS).

	  FIRST PERSON   `Player.CameraMode = LockFirstPerson`: Roblox's own camera does the looking and turns the body with
	                 it (smooth: it is the engine turning it, not a script setting the body's place every frame, which is
	                 what made the old mouse lock stutter). This controller adds: the eyes' place, your OWN BODY made
	                 visible below the neck (Roblox hides all of it in first person), the step of the picture with the
	                 feet, the dip of a landing and of a dash, the field of view you chose.

	  THE MOUSE      Held in the middle under a very small dot. L lets it go and takes it back (`View.UnlockKey`). It is
	                 also let go, by itself, whenever a panel is open (the Settings, the pack, the forge, a page, the
	                 arrival scene's SKIP...) and taken back when the panel closes. Other controllers ask with
	                 `ViewController.isFree()` before they treat a click as a blow.
	                 While L has it free, small lines of things to do with it stand at the bottom of the screen ("Hang
	                 the lantern on your belt"): `ViewController.chip`.

	  THE LOOK       Where you look (up and down) is sent a few times a second so your friends see your head and chest
	                 follow it (Services/MovementService passes it on; Controllers/BodyAnimController draws it).

	  OPENING THE EYES  The first time you have control in a place the eyes open: two slow blinks, the blur clearing, the
	                 view settling (`ViewController.wake`). After the arrival scene in the castle; after the title in the
	                 lobby.

	Scenes that take the camera (the arrival scene, a death, the train) set it to Scriptable: everything here stands
	back while the camera is not Roblox's own.

	Place: client (boots in both places).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local Theme = require(Client.UI.Theme)
local BodyAnimController = require(script.Parent.BodyAnimController)

local ViewController = {}

ViewController.Name = "ViewController"

local log = Logger.new("ViewController")

local player = Players.LocalPlayer
local cfg: any = nil

--==========================================================================
-- State
--==========================================================================
local reasons: { [string]: boolean } = {} -- why the mouse is free ("key", "panel", ...)
local sceneOn = false
local woke = false
local waking = false
local spawnedAt = os.clock()

local modal: TextButton? = nil
local dot: Frame? = nil
local hint: TextLabel? = nil
local chipHolder: Frame? = nil

type Chip = { id: string, text: () -> string?, click: () -> (), button: TextButton? }
local chips: { Chip } = {}

-- the eyes
local eyeOffset = Vector3.zero
local leanNow = 0
local fovAdd = 0
local landGoal = 0
local dashAt = -math.huge
local dashFor = 0.5
local dashSide = 0
local kickOffset = Vector3.zero
local kickUntil = 0

-- the body's parts that are shown to their own eyes
local shownParts: { BasePart } = {}
local shownFor: Model? = nil
local shownDirty = true

--==========================================================================
-- Small helpers
--==========================================================================
local function anyReason(): boolean
	return next(reasons) ~= nil
end

local function firstPerson(): boolean
	local camera = Workspace.CurrentCamera
	return cfg.FirstPerson and camera ~= nil and camera.CameraType == Enum.CameraType.Custom
end

local function fovChosen(): number
	local chosen = player:GetAttribute("ViewFov")
	if typeof(chosen) == "number" then
		return math.clamp(chosen, cfg.Fov.Min, cfg.Fov.Max)
	end
	return cfg.Fov.Default
end

local function bobOn(): boolean
	return player:GetAttribute("ViewBob") ~= false
end

--==========================================================================
-- The mouse
--==========================================================================

-- Is there a button to be pressed under here (a thing that is shown, with everything above it shown)?
local function hasButton(parent: Instance): boolean
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			if child:IsA("GuiButton") and child.Active and child.AbsoluteSize.X > 6 and child.AbsoluteSize.Y > 6 then
				return true
			end
			if hasButton(child) then
				return true
			end
		end
	end
	return false
end

--[[
	Is a panel (or anything else that needs the mouse) open? A panel is a screen drawn at order 15 or above (the
	Settings, the Muster Roll, the forge, the chapel, the train's board, the arrival scene...) that is showing a BUTTON:
	the lobby keeps several such screens switched on with nothing in them (found in play, 2026-11-11: an empty strip of
	the train's screen let the mouse go for ever). And the backpack's open pack.
]]
local function panelOpen(): boolean
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return false
	end
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and screen.DisplayOrder >= 15 and screen:GetAttribute("TLK_NoMouse") ~= true then
			if hasButton(screen) then
				return true
			end
		end
	end
	local pack = gui:FindFirstChild("BackpackHud")
	local open = pack and pack:FindFirstChild("Pack", true)
	return open ~= nil and open:IsA("GuiObject") and open.Visible
end

local function applyMouse()
	local free = anyReason()
	if modal then
		-- a visible Modal button is how Roblox lets the mouse go in first person
		modal.Visible = free
	end
	if dot then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		dot.Visible = not free and firstPerson() and not sceneOn and not waking and humanoid ~= nil and humanoid.Health > 0 and UserInputService.MouseEnabled
	end
end

--[[
	Lets the mouse go (`on` true) or takes it back, for `reason` (any name: each reason is kept apart, and the mouse is
	held again only when none is left).
]]
function ViewController.setFree(reason: string, on: boolean)
	local was = reasons[reason] == true
	if was == on then
		return
	end
	reasons[reason] = if on then true else nil
	applyMouse()
end

-- Is the mouse free right now (a panel is open, or L let it go)? A click is then a click on the screen, not a blow.
function ViewController.isFree(): boolean
	return anyReason()
end

-- Did the player let it go with L (and not a panel)?
function ViewController.isFreeByKey(): boolean
	return reasons.key == true
end

--[[
	A small line shown at the bottom while L has the mouse free. `text` is asked a few times a second: nil hides the
	line (nothing to do just now). `click` is what pressing it does.
]]
function ViewController.chip(id: string, text: () -> string?, click: () -> ())
	for _, have in chips do
		if have.id == id then
			have.text = text
			have.click = click
			return
		end
	end
	table.insert(chips, { id = id, text = text, click = click, button = nil })
end

local function drawChips()
	local holder = chipHolder
	if not holder then
		return
	end
	local byKey = reasons.key == true and not sceneOn
	local order = 0
	for _, chip in chips do
		local label = if byKey then chip.text() else nil
		local button = chip.button
		if label and not button then
			local made = Instance.new("TextButton")
			made.Name = chip.id
			made.AutoButtonColor = false
			made.BackgroundTransparency = 1
			made.Size = UDim2.fromOffset(360, 22)
			made.TextSize = 15
			made.TextColor3 = Theme.Color.Parchment
			made.TextTransparency = 0.12
			made.Text = ""
			Theme.applyFont(made, Theme.Role.Body)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Thickness = 1.4
			stroke.Transparency = 0.3
			stroke.Parent = made
			local rule = Instance.new("Frame")
			rule.Name = "Rule"
			rule.AnchorPoint = Vector2.new(0.5, 1)
			rule.Position = UDim2.new(0.5, 0, 1, 0)
			rule.Size = UDim2.new(0, 0, 0, 1)
			rule.BackgroundColor3 = Theme.Color.Gold
			rule.BackgroundTransparency = 0.25
			rule.BorderSizePixel = 0
			rule.Parent = made
			made.MouseEnter:Connect(function()
				made.TextColor3 = Theme.Color.GoldBright
				TweenService:Create(rule, Theme.Motion.Fast, { Size = UDim2.new(0, made.TextBounds.X + 12, 0, 1) }):Play()
			end)
			made.MouseLeave:Connect(function()
				made.TextColor3 = Theme.Color.Parchment
				TweenService:Create(rule, Theme.Motion.Fast, { Size = UDim2.new(0, 0, 0, 1) }):Play()
			end)
			made.Activated:Connect(function()
				chip.click()
			end)
			made.Parent = holder
			chip.button = made
			button = made
		end
		if button then
			button.Visible = label ~= nil
			if label then
				order += 1
				button.LayoutOrder = order
				button.Text = label
			end
		end
	end
end

local function drawHint()
	local label = hint
	if not label then
		return
	end
	local show = false
	local text = cfg.Hint.Locked
	if UserInputService.MouseEnabled and cfg.FirstPerson and not sceneOn and not waking then
		if reasons.key then
			show = true
			text = cfg.Hint.Free
		elseif not anyReason() and os.clock() - spawnedAt < cfg.Hint.Seconds then
			show = true
		end
	end
	label.Text = text
	local goal = if show then 0.25 else 1
	if math.abs(label.TextTransparency - goal) > 0.01 and label:GetAttribute("Goal") ~= goal then
		label:SetAttribute("Goal", goal)
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = goal }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = if show then 0.45 else 1 }):Play()
		end
	end
end

--==========================================================================
-- Your own body, seen by your own eyes
--==========================================================================
local function gatherParts(character: Model)
	table.clear(shownParts)
	local head = character:FindFirstChild("Head")
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d ~= head and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(shownParts, d)
		end
	end
	shownFor = character
	shownDirty = false
end

local function showBody(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	if shownFor ~= character or shownDirty then
		gatherParts(character)
	end
	local value = if hidden then 1 else 0
	for _, part in shownParts do
		if part.LocalTransparencyModifier ~= value then
			part.LocalTransparencyModifier = value
		end
	end
end

--==========================================================================
-- The eyes, every frame
--==========================================================================

-- before Roblox's camera reads them: where the eyes are, how wide they see
local function stepBefore(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not (humanoid and root and root:IsA("BasePart") and camera) then
		return
	end
	if not firstPerson() then
		if humanoid.CameraOffset ~= Vector3.zero and not cfg.FirstPerson then
			humanoid.CameraOffset = Vector3.zero
		end
		return
	end
	local now = os.clock()
	local bob = cfg.Bob
	local phase, moving, run, aside, landed = BodyAnimController.localStep()

	-- the step
	local want = Vector3.zero
	local lean = -aside * moving * bob.StrafeLean
	if bobOn() and moving > 0.01 and humanoid.FloorMaterial ~= Enum.Material.Air then
		local up = bob.WalkUp + (bob.RunUp - bob.WalkUp) * run
		local side = bob.WalkSide + (bob.RunSide - bob.WalkSide) * run
		local fall = 0.5 + 0.5 * math.cos(4 * math.pi * (phase - 0.07)) -- 1 just after each foot lands
		local sway = math.sin(2 * math.pi * phase)
		want = Vector3.new(side * sway, up * (0.5 - fall), 0) * moving
		lean += bob.Lean * sway * moving
	end

	-- a landing
	if landed > 0 then
		landGoal = math.max(landGoal, bob.Land * math.clamp(landed / 45, 0.3, 1))
	end
	landGoal *= math.exp(-dt * 6.5)

	-- a dash
	local dashDip, dashFov = 0, 0
	local a = (now - dashAt) / dashFor
	if a >= 0 and a < 1 then
		local arc = math.sin(math.pi * a)
		dashDip = cfg.Dash.Dip * arc
		dashFov = cfg.DashFov * (1 - a) * (1 - a)
		lean += -dashSide * cfg.Dash.Lean * arc
	end

	local kick = if now < kickUntil then kickOffset else Vector3.zero
	local ease = math.min(1, dt * bob.Ease)
	eyeOffset += (want + Vector3.new(0, -landGoal - dashDip, 0) + kick - eyeOffset) * ease
	leanNow += (lean - leanNow) * ease

	-- the eyes sit a little up and forward of the head's middle (smaller on a ducked body)
	local scale = math.clamp(root.Size.Y / 2, 0.4, 1.2)
	humanoid.CameraOffset = Vector3.new(cfg.Eye.X, cfg.Eye.Y * scale, cfg.Eye.Z) + eyeOffset

	if not waking then
		local wantAdd = cfg.RunFov * run * moving + dashFov
		fovAdd += (wantAdd - fovAdd) * math.min(1, dt * 9)
		camera.FieldOfView = fovChosen() + fovAdd
	end
end

-- after Roblox's camera: the lean of the picture, and your own body shown
local function stepAfter()
	if not firstPerson() then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and math.abs(leanNow) > 0.01 then
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(leanNow))
	end
	local a = (os.clock() - dashAt) / dashFor
	showBody(a >= 0 and a < 1.08)
end

--[[
	A dash began (Controllers/MovementController): `side` is how much of it goes to the right (-1 left .. 1 right, the
	picture leans away from it), `seconds` how long it lasts. The eyes dip and come up; your own body is not drawn until
	it is over (you are inside it, and it is busy).
]]
function ViewController.dash(side: number, seconds: number)
	dashAt = os.clock()
	dashFor = math.max(seconds, 0.1)
	dashSide = math.clamp(side, -1, 1)
end

-- A knock to the eyes for a moment (a pick striking stone): `offset` in studs, for `seconds`.
function ViewController.kick(offset: Vector3, seconds: number)
	kickOffset = offset
	kickUntil = os.clock() + seconds
end

--==========================================================================
-- Opening the eyes
--==========================================================================
local function lid(parent: Instance, top: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = if top then "UpperLid" else "LowerLid"
	f.AnchorPoint = Vector2.new(0.5, if top then 0 else 1)
	f.Position = UDim2.fromScale(0.5, if top then 0 else 1)
	f.Size = UDim2.fromScale(1.2, 0.56)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = parent
	-- a soft edge where the lids meet
	local edge = Instance.new("UIGradient")
	edge.Rotation = if top then 90 else -90
	edge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.82, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	edge.Parent = f
	return f
end

--[[
	The eyes open on the place: black, a slit, shut, half, a last small blink, open; the blur clears and the view settles
	from narrow to the player's own. Nothing is taken from the player meanwhile: they can already walk.
]]
function ViewController.wake()
	local wake = cfg.Wake
	if woke or waking or not wake.Enabled or not cfg.FirstPerson then
		woke = true
		return
	end
	woke = true
	waking = true
	spawnedAt = os.clock() + wake.Seconds -- the key's hint is shown once the eyes are open
	task.spawn(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "WakeEyes"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 14 -- under every panel, over the play screen (and it does not ask for the mouse)
		gui.Parent = player:WaitForChild("PlayerGui")
		local upper, lower = lid(gui, true), lid(gui, false)
		local blur = Instance.new("BlurEffect")
		blur.Name = "TLK_WakeBlur"
		blur.Size = wake.Blur
		blur.Parent = Lighting

		local camera = Workspace.CurrentCamera
		if camera then
			camera.FieldOfView = wake.FromFov
		end
		local total = wake.Seconds
		-- how far the lids are apart (0 shut .. 1 open) at each share of the time, and the blur left
		local beats = {
			{ 0.00, 0.00, 1.0 },
			{ 0.10, 0.00, 1.0 },
			{ 0.24, 0.20, 1.0 },
			{ 0.31, 0.00, 0.9 },
			{ 0.50, 0.58, 0.6 },
			{ 0.56, 0.30, 0.55 },
			{ 0.80, 1.00, 0.12 },
			{ 1.00, 1.00, 0.0 },
		}
		local started = os.clock()
		while true do
			local t = (os.clock() - started) / total
			if t >= 1 then
				break
			end
			local i = 1
			while i < #beats and beats[i + 1][1] <= t do
				i += 1
			end
			local a, b = beats[i], beats[math.min(i + 1, #beats)]
			local span = b[1] - a[1]
			local k = if span > 0 then (t - a[1]) / span else 1
			k = k * k * (3 - 2 * k)
			local open = a[2] + (b[2] - a[2]) * k
			local haze = a[3] + (b[3] - a[3]) * k
			-- each lid covers a little more than half when shut and is gone when open
			local cover = 0.56 * (1 - open)
			upper.Size = UDim2.fromScale(1.2, cover)
			lower.Size = UDim2.fromScale(1.2, cover)
			blur.Size = wake.Blur * haze
			local cam = Workspace.CurrentCamera
			if cam and cam.CameraType == Enum.CameraType.Custom then
				local settle = math.clamp((t - 0.3) / 0.7, 0, 1)
				settle = 1 - (1 - settle) ^ 3
				cam.FieldOfView = wake.FromFov + (fovChosen() - wake.FromFov) * settle
			end
			RunService.RenderStepped:Wait()
		end
		gui:Destroy()
		blur:Destroy()
		waking = false
		spawnedAt = os.clock()
		applyMouse()
	end)
end

-- A scene has taken the screen (the arrival): nothing of ours is drawn over it, and the mouse is free for its button.
function ViewController.sceneBegan()
	sceneOn = true
	ViewController.setFree("scene", true)
end

-- The scene is over; `open` true opens the eyes on the place.
function ViewController.sceneEnded(open: boolean)
	sceneOn = false
	ViewController.setFree("scene", false)
	if open then
		woke = false
		ViewController.wake()
	end
end

--==========================================================================
-- Build
--==========================================================================
local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	local free = Instance.new("ScreenGui")
	free.Name = "MouseFree"
	free.ResetOnSpawn = false
	free.DisplayOrder = 1
	free.Parent = playerGui
	local button = Instance.new("TextButton")
	button.Name = "Modal"
	button.Modal = true
	button.Text = ""
	button.BackgroundTransparency = 1
	-- (it has to be ON the screen to count: put outside it, at -10,-10, the mouse stayed held. Found in play 2026-11-11.)
	button.Size = UDim2.fromOffset(2, 2)
	button.Position = UDim2.fromOffset(0, 0)
	button.AutoButtonColor = false
	button.Visible = false
	button.Parent = free
	modal = button

	local dotGui = Instance.new("ScreenGui")
	dotGui.Name = "ViewDot"
	dotGui.ResetOnSpawn = false
	dotGui.IgnoreGuiInset = true -- the true middle of the screen, where the mouse is held
	dotGui.DisplayOrder = 9
	dotGui.Parent = playerGui
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(cfg.Dot.Size, cfg.Dot.Size)
	d.BackgroundColor3 = cfg.Dot.Color
	d.BackgroundTransparency = cfg.Dot.Transparency
	d.BorderSizePixel = 0
	d.Visible = false
	d.Parent = dotGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = d
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Thickness = 1
	edge.Transparency = 0.35
	edge.Parent = d
	dot = d

	local hintGui = Instance.new("ScreenGui")
	hintGui.Name = "ViewHint"
	hintGui.ResetOnSpawn = false
	hintGui.IgnoreGuiInset = true
	hintGui.DisplayOrder = 9
	hintGui.Parent = playerGui
	local holder = Instance.new("Frame")
	holder.Name = "Lines"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -118)
	holder.Size = UDim2.fromOffset(420, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = hintGui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, 2)
	list.Parent = holder
	chipHolder = holder
	local label = Instance.new("TextLabel")
	label.Name = "Key"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(420, 18)
	label.LayoutOrder = 1000
	label.TextSize = 13
	label.TextColor3 = Theme.Color.Cream
	label.TextTransparency = 1
	label.Text = cfg.Hint.Locked
	Theme.applyFont(label, Theme.Role.Body)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.2
	stroke.Transparency = 1
	stroke.Parent = label
	label.Parent = holder
	hint = label
end

--==========================================================================
function ViewController.Init() end

function ViewController.Start()
	cfg = Config.get("View")
	build()

	if cfg.FirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end

	-- L: the mouse free, the mouse held
	ContextActionService:BindAction("TLKMouseFree", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin and not sceneOn and UserInputService:GetFocusedTextBox() == nil then
			ViewController.setFree("key", not reasons.key)
			drawChips()
			drawHint()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode[cfg.UnlockKey])

	RunService:BindToRenderStep("TLK_ViewEyes", Enum.RenderPriority.Camera.Value - 1, stepBefore)
	RunService:BindToRenderStep("TLK_ViewBody", Enum.RenderPriority.Camera.Value + 1, stepAfter)

	-- a few times a second: is a panel open, what do the lines say
	task.spawn(function()
		while true do
			ViewController.setFree("panel", panelOpen())
			-- Roblox's own menu frees the mouse itself; a body that died gives it back to the screens that follow
			applyMouse()
			drawChips()
			drawHint()
			task.wait(0.2)
		end
	end)

	-- where you look, for your friends' eyes
	local look = cfg.Look
	local sendLook = Net.getUnreliable("LookSync")
	local lastSent, lastAt = 0, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastAt < 1 / look.SendHz then
			return
		end
		local camera = Workspace.CurrentCamera
		local pitch = 0
		if camera and firstPerson() then
			pitch = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
		end
		pitch = math.floor(pitch * 2 + 0.5) / 2
		if math.abs(pitch - lastSent) >= look.SendStep or (pitch ~= lastSent and now - lastAt > 0.5) then
			lastSent, lastAt = pitch, now
			sendLook:FireServer(pitch)
		end
	end)

	local function onCharacter(character: Model)
		spawnedAt = os.clock()
		shownDirty = true
		eyeOffset = Vector3.zero
		landGoal = 0
		character.DescendantAdded:Connect(function()
			shownDirty = true
		end)
		character.DescendantRemoving:Connect(function()
			shownDirty = true
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	-- the eyes open once the loading screen (and, in the castle, the arrival scene) is over
	local inWorld = game.PlaceId == Constants.PlaceIds.ForgottenLands or game.PlaceId == 0
	local function loaded()
		task.delay(if inWorld then 3 else 0.4, function()
			if not sceneOn and not woke then
				ViewController.wake()
			end
		end)
	end
	if ReplicatedFirst:GetAttribute("TLKLoaded") then
		loaded()
	else
		local once = false
		ReplicatedFirst:GetAttributeChangedSignal("TLKLoaded"):Connect(function()
			if not once and ReplicatedFirst:GetAttribute("TLKLoaded") then
				once = true
				loaded()
			end
		end)
	end

	GuiService.MenuOpened:Connect(applyMouse)
	GuiService.MenuClosed:Connect(applyMouse)

	log:info(("ready: first person %s, %s lets the mouse go, field of view %d"):format(tostring(cfg.FirstPerson), cfg.UnlockKey, fovChosen()))
end

return ViewController
