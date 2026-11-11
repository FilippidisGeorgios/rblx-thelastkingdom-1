--!strict
--[[
	RangedCombatService
	The player's bow (configs/Weapons `hunting_bow`, docs/systems/Arsenal.md): hold to draw, let go to loose, and the arrow
	is a real one that travels and is stopped by whatever is in its way (World/ProjectileService, the same one the dead's
	archers shoot through), so a wall is cover for the dead too.

	The client only ASKS (`RequestBow`):
	  { kind = "draw" }                the button went down
	  { kind = "loose", aim = Vector3 } the button came up: where the eyes look
	  { kind = "cancel" }              let down without loosing

	This service decides:
	  * a draw needs a bow IN THE HAND, the weapon ready again (its Cooldown since the last arrow), a living body, and an
	    arrow: the quiver on the back with something in it (World/GearService; an empty quiver takes a bundle from the
	    pack). If not, the player is told why in a line at the top.
	  * a loose needs the draw to have been held `MinDraw` seconds (sooner: the bow is only lowered). The longer the
	    draw, up to `DrawSeconds`, the harder and faster the arrow: at the least draw it has `WeakDraw` of its damage and
	    a little over half its speed. The aim is the client's look if it points roughly where the body faces (the game is
	    first person: the body faces where the eyes do), else the body's own facing.
	  * the arrow leaves from in front of the chest, costs one arrow, and its damage goes through the same door as every
	    other blow (`CombatService.applyDamage`, with the run's damage share from RunModService).

	What everybody sees: the Humanoid's `BowState` ("draw" | "loose" | "lower") and `BowSeq`; each client plays the bow's
	clips from them (Client/Controllers/BodyAnimController). The owner's own client drew it the moment the button moved.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat / ranged.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent.CombatService)
local GearService = require(script.Parent.GearService)
local ProjectileService = require(script.Parent.ProjectileService)
local RunModService = require(script.Parent.RunModService)
local WeaponVisualService = require(script.Parent.WeaponVisualService)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local RangedCombatService = {}

RangedCombatService.Name = "RangedCombatService"

local log = Logger.new("RangedCombatService")

type State = { drawAt: number?, lastLoose: number, seq: number, noteToken: number }

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { drawAt = nil, lastLoose = -math.huge, seq = 0, noteToken = 0 }
		states[player] = s
	end
	return s
end

local function entityId(player: Player): string
	return Constants.CombatId.PlayerPrefix .. player.UserId
end

-- The bow in `player`'s hand: its id and its numbers, or nil.
local function bowOf(player: Player): (string?, any)
	local weaponId = WeaponVisualService.inHand(player)
	local def = weaponId and Config.get("Weapons")[weaponId]
	if def and def.Class == "Ranged" then
		return weaponId, def
	end
	return nil, nil
end

local function body(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function show(player: Player, state: State, what: string)
	local humanoid = body(player)
	if humanoid then
		state.seq += 1
		humanoid:SetAttribute("BowState", what)
		humanoid:SetAttribute("BowSeq", state.seq)
	end
end

local function tell(player: Player, text: string)
	local state = stateOf(player)
	state.noteToken += 1
	local token = state.noteToken
	local event = Net.getEvent("ObjectiveHint")
	event:FireClient(player, { source = "bow", text = text })
	task.delay(2.5, function()
		if state.noteToken == token and player.Parent then
			event:FireClient(player, { source = "bow", text = nil })
		end
	end)
end

local function onDraw(player: Player)
	local state = stateOf(player)
	local humanoid = body(player)
	local weaponId, def = bowOf(player)
	if not (humanoid and weaponId and def) then
		return
	end
	local attacker = CombatService.getEntity(entityId(player))
	if not attacker or not attacker:isAlive() then
		return
	end
	local now = os.clock()
	if now - state.lastLoose < def.Cooldown * RunModService.cooldown(player) - 0.05 then
		return
	end
	local why = GearService.noArrowsReason(player)
	if why then
		state.drawAt = nil
		tell(player, why)
		return
	end
	state.drawAt = now
	show(player, state, "draw")
end

local function onLoose(player: Player, aim: any)
	local state = stateOf(player)
	local drawAt = state.drawAt
	state.drawAt = nil
	if not drawAt then
		return
	end
	local humanoid, root = body(player)
	local weaponId, def = bowOf(player)
	if not (humanoid and root and weaponId and def) then
		return
	end
	local now = os.clock()
	local held = now - drawAt
	-- a little slack for the trip from the client: it measured the same hold on its own clock
	if held < def.MinDraw - 0.08 then
		show(player, state, "lower")
		return
	end
	local attacker = CombatService.getEntity(entityId(player))
	if not attacker or not attacker:isAlive() then
		return
	end

	-- where it goes: the eyes, if they look roughly where the body faces
	local facing = root.CFrame.LookVector
	local direction = facing
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 1.5 and aim == aim then
		local unit = aim.Unit
		local flat = Vector3.new(unit.X, 0, unit.Z)
		local flatFacing = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude < 0.05 or (flatFacing.Magnitude > 0.05 and flat.Unit:Dot(flatFacing.Unit) > -0.2) then
			direction = unit
		end
	end

	if not GearService.takeArrow(player) then
		show(player, state, "lower")
		tell(player, GearService.noArrowsReason(player) or "The quiver is empty.")
		return
	end

	local power = math.clamp(held / def.DrawSeconds, 0, 1)
	local share = def.WeakDraw + (1 - def.WeakDraw) * power
	local origin = root.Position + Vector3.new(0, 1.3, 0) + direction * 1.8
	local fired = ProjectileService.fire({
		kind = "arrow",
		sourceId = attacker.id,
		origin = origin,
		targetPosition = origin + direction * def.Range,
		speed = def.Speed * (0.55 + 0.45 * power),
		damage = def.Damage * share * RunModService.damage(player),
		damageType = def.DamageType,
		spread = 0,
		leadFactor = 0,
		maxRange = def.Range,
	} :: any)
	state.lastLoose = now
	show(player, state, "loose")
	if fired then
		log:info(("%s looses (draw %.2f s, %d%% of the blow, %d arrows left)"):format(player.Name, held, math.floor(share * 100 + 0.5), GearService.arrows(player)))
	end
end

local function onCancel(player: Player)
	local state = stateOf(player)
	if state.drawAt then
		state.drawAt = nil
		show(player, state, "lower")
	end
end

function RangedCombatService.Init() end

function RangedCombatService.Start()
	local lastAsk: { [Player]: number } = {}
	Net.getEvent("RequestBow").OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "draw" then
			-- (only a draw is held to a pace: a loose or a let-down must never be lost)
			local now = os.clock()
			if now - (lastAsk[player] or 0) < 0.05 then
				return
			end
			lastAsk[player] = now
			onDraw(player)
		elseif payload.kind == "loose" then
			onLoose(player, payload.aim)
		elseif payload.kind == "cancel" then
			onCancel(player)
		end
	end)

	-- a bow that leaves the hand is let down
	WeaponVisualService.onChanged(function(player: Player)
		local state = states[player]
		if state and state.drawAt and bowOf(player) == nil then
			state.drawAt = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastAsk[player] = nil
	end)
	log:info("ready")
end

return RangedCombatService
