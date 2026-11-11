--!strict
--[[
	CombatController
	The client half of fighting: it turns the player's keys into INTENTS (never damage) and sends them to the server,
	and it owns the weapon bar. All validation and every hit are the server's (World/MeleeCombatService,
	World/RangedCombatService, World/WeaponVisualService).

	  THE WEAPON BAR   the weapons carried, along the bottom of the screen (UI/WeaponBar). The MOUSE WHEEL goes from one
	                   to the next; a NUMBER KEY takes that weapon in hand, and the number of the one already in hand
	                   puts it away. (`RequestSelectWeapon`; the server answers with `WeaponBar`.)
	  A BLOW           the left mouse button with a sword, an axe, a mace or a spear in hand: `RequestMeleeAttack` with
	                   where you look (flat: a blow is aimed along the ground). Your own arm moves at once
	                   (BodyAnimController.playLocalSwing), no faster than the weapon is ready again.
	  THE BOW          HOLD the left button to draw (`RequestBow` "draw"), let go to loose where the dot is ("loose", with
	                   the look). Let go too soon and the bow is only lowered.

	A click is only a blow while the mouse is held in the middle: with a panel open, or the mouse let go with L, a click
	is a click on the screen (ViewController.isFree).

	Client Controllers boot in both places; fighting only matters in the Forgotten Lands, where the server answers.

	Place: client. Phase: Combat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)
local WeaponBar = require(Client.UI.WeaponBar)
local IconButton = require(Client.UI.IconButton)
local BodyAnimController = require(script.Parent.BodyAnimController)
local ViewController = require(script.Parent.ViewController)

local CombatController = {}

CombatController.Name = "CombatController"

local log = Logger.new("CombatController")

local player = Players.LocalPlayer

type Carried = { id: string, name: string, kind: string }

local weapons: { Carried } = {}
local selected = 0
local drawn = false
local lastSwing = -math.huge
local lastWheel = -math.huge
local drawingSince: number? = nil

local function lookVector(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		return camera.CFrame.LookVector
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.CFrame.LookVector else nil
end

local function alive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function inHand(): Carried?
	return if drawn then weapons[selected] else nil
end

function CombatController.Init() end

function CombatController.Start()
	-- stand down anywhere that is definitely not the Forgotten Lands (an unpublished local place reports PlaceId 0)
	if game.PlaceId ~= 0 and game.PlaceId ~= Constants.PlaceIds.ForgottenLands then
		return
	end
	local weaponCfg = Config.get("Weapons")
	local requestAttack = Net.getEvent("RequestMeleeAttack")
	local requestSelect = Net.getEvent("RequestSelectWeapon")
	local requestBow = Net.getEvent("RequestBow")

	--------------------------------------------------------------------------
	-- the bar
	--------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponBarGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local bar = WeaponBar.create(gui)

	local function pick(index: number)
		if not alive() or #weapons == 0 then
			return
		end
		-- the number of the weapon already in hand puts it away
		requestSelect:FireServer(if drawn and index == selected then 0 else index)
	end
	bar.onPick(pick)

	local function drawArrows()
		local count = player:GetAttribute("Arrows")
		bar.setArrows(if typeof(count) == "number" then count else nil, player:GetAttribute("Back") == "quiver")
	end
	player:GetAttributeChangedSignal("Arrows"):Connect(drawArrows)
	player:GetAttributeChangedSignal("Back"):Connect(drawArrows)

	Net.getEvent("WeaponBar").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.weapons) ~= "table" then
			return
		end
		local list: { Carried } = {}
		for _, w in payload.weapons do
			if typeof(w) == "table" and typeof(w.id) == "string" then
				table.insert(list, { id = w.id, name = tostring(w.name or w.id), kind = tostring(w.kind or "sword") })
			end
		end
		weapons = list
		selected = if typeof(payload.selected) == "number" then payload.selected else 0
		drawn = payload.drawn == true
		if not drawn then
			drawingSince = nil
		end
		bar.set(weapons, selected, drawn)
		drawArrows()
	end)

	--------------------------------------------------------------------------
	-- a blow, and the bow
	--------------------------------------------------------------------------
	local function swing()
		local weapon = inHand()
		if not weapon then
			return
		end
		local def = weaponCfg[weapon.id]
		local kept = player:GetAttribute("SwingCooldown")
		local cooldown = if typeof(kept) == "number" then kept else (def and def.Cooldown) or 0.6
		local now = os.clock()
		if now - lastSwing < cooldown then
			return
		end
		lastSwing = now
		local look = lookVector()
		local flat = look and Vector3.new(look.X, 0, look.Z)
		requestAttack:FireServer(if flat and flat.Magnitude > 0.01 then flat.Unit else nil)
		BodyAnimController.playLocalSwing()
	end

	local function press()
		if not alive() or ViewController.isFree() then
			return
		end
		local weapon = inHand()
		if not weapon then
			return
		end
		if weapon.kind == "bow" then
			local count = player:GetAttribute("Arrows")
			if player:GetAttribute("Back") ~= "quiver" or (typeof(count) == "number" and count <= 0) then
				requestBow:FireServer({ kind = "draw" }) -- the server says why not (a line at the top)
				return
			end
			if os.clock() - lastSwing < ((weaponCfg[weapon.id] and weaponCfg[weapon.id].Cooldown) or 0.45) then
				return
			end
			drawingSince = os.clock()
			requestBow:FireServer({ kind = "draw" })
			BodyAnimController.playLocalBow("draw")
		else
			swing()
		end
	end

	local function release()
		local since = drawingSince
		if not since then
			return
		end
		drawingSince = nil
		local weapon = inHand()
		local def = weapon and weaponCfg[weapon.id]
		local held = os.clock() - since
		if weapon and def and held >= (def.MinDraw or 0.3) and not ViewController.isFree() then
			lastSwing = os.clock()
			requestBow:FireServer({ kind = "loose", aim = lookVector() })
			BodyAnimController.playLocalBow("loose")
		else
			requestBow:FireServer({ kind = "cancel" })
			BodyAnimController.playLocalBow("lower")
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			press()
			return
		end
		-- the number row: 1..9
		local number = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if input.UserInputType == Enum.UserInputType.Keyboard and number >= 1 and number <= 9 and number <= #weapons then
			pick(number)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			release()
		end
	end)
	-- the wheel: the next weapon, the one before
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel or processed or ViewController.isFree() then
			return
		end
		local count = #weapons
		local now = os.clock()
		if count == 0 or not alive() or now - lastWheel < 0.11 then
			return
		end
		lastWheel = now
		local step = if input.Position.Z > 0 then -1 else 1
		local from = if drawn then selected else 0
		local to = from + step
		if to < 1 then
			to = count
		elseif to > count then
			to = 1
		end
		drawingSince = nil
		requestSelect:FireServer(to)
	end)
	-- a window that loses the mouse never hears the button come up
	UserInputService.WindowFocusReleased:Connect(release)

	-- a phone: one button that strikes (hold it to draw the bow)
	if UserInputService.TouchEnabled then
		local buttons = Instance.new("ScreenGui")
		buttons.Name = "AttackButton"
		buttons.ResetOnSpawn = false
		buttons.DisplayOrder = 6
		buttons.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		buttons.Parent = player:WaitForChild("PlayerGui")
		local handle = IconButton.create({
			Name = "Attack",
			Parent = buttons,
			Icon = "sword",
			IconSize = 34,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -214, 1, -214),
			Size = UDim2.fromOffset(62, 62),
		})
		handle.button.MouseButton1Down:Connect(press)
		handle.button.MouseButton1Up:Connect(release)
		handle.button.MouseLeave:Connect(release)
	end

	player.CharacterAdded:Connect(function()
		drawingSince = nil
	end)

	log:info("ready")
end

return CombatController
