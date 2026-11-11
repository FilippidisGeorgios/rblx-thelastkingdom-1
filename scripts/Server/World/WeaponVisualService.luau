--!strict
--[[
	WeaponVisualService
	Puts a player's weapons ON them, and one of them in the hand (configs/Gear, docs/systems/Gear.md).

	Every weapon a player carries is on the body all the time: the sword at the right hip, the spear and the bow on the
	back. The one chosen on the weapon bar is in the hand (a bow in the left). Each weapon is one model held by ONE joint
	(a Motor6D from a body part to the weapon's hilt), which is moved between its place on the body and the hand: nothing
	is rebuilt, and there is never a frame with two swords or none.

	  WHAT A PLAYER CARRIES   the weapon items in their inventory (Services/InventoryService), in the order of
	                          configs/Gear.Starter.Weapons. Choosing one equips it (Services/EquipmentService), so the
	                          blow or the arrow is that weapon's (World/MeleeCombatService, World/RangedCombatService).
	  THE KEYS                `RequestSelectWeapon` (a place on the bar; 0 puts the weapon away) and the older
	                          `RequestToggleWeapon`. The client only asks.
	  WHAT EVERYBODY IS TOLD  two attributes on the character, `Weapon` (the chosen weapon's id) and `WeaponDrawn`, which
	                          every client reads to pose the arms (Client/Controllers/BodyAnimController); and to the
	                          owner alone `WeaponBar` (the list, the place chosen, in hand or not).

	THE MODELS come from World-side `Domain/GearModels`: a weapon with a `Kit` in configs/Gear is put together from the
	sculpted pieces; the sword is whatever the developer has put at `ServerStorage.Assets.Weapons.<id>` (a Part, a Tool
	or a Model), else a sword built here from parts.

	ASSETS, NOT MODELS. `world.project.json` maps `ServerStorage.Models` to an empty folder on disk, so Rojo deletes
	whatever is in it each time the plugin connects. Hand-made things live in `ServerStorage.Assets`, which no project
	file claims. (The old place is still read, with a warning.)

	THE ARMS ARE NOT MOVED HERE. A pose written by the server composes with nothing a client is playing; the arms are
	posed on every client from the two attributes above.

	A body is only given its weapons once it is the square body (Services/AvatarService): laying a look on a standing
	body replaces its hands, and a joint to a hand that is gone drops the weapon on the floor.

	Place: Forgotten Lands ONLY (Server/World). Phase: Combat.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local GearModels = require(Server.Domain.GearModels)
local AvatarService = require(Server.Services.AvatarService)
local EquipmentService = require(Server.Services.EquipmentService)
local InventoryService = require(Server.Services.InventoryService)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Util.Logger)

local WeaponVisualService = {}

WeaponVisualService.Name = "WeaponVisualService"

local log = Logger.new("WeaponVisualService")

local PALETTE = {
	steel = Color3.fromRGB(168, 176, 186),
	steelDark = Color3.fromRGB(104, 112, 124),
	edge = Color3.fromRGB(206, 214, 224),
	guard = Color3.fromRGB(92, 84, 66),
	grip = Color3.fromRGB(58, 40, 28),
	pommel = Color3.fromRGB(112, 96, 62),
}

--==========================================================================
type Carried = { uid: string, weaponId: string, name: string, kind: string }

type State = {
	carried: { Carried },
	selected: number, -- the place on the bar that is chosen (0 = nothing yet)
	drawn: boolean, -- is it in the hand
	built: Model?, -- the character the models were made for
}

local states: { [Player]: State } = {}
local barEvent: RemoteEvent? = nil
local drawnChanged: { (Player, string?, boolean) -> () } = {}

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { carried = {}, selected = 0, drawn = false, built = nil }
		states[player] = s
	end
	return s
end

local function gearDef(weaponId: string): any
	return Config.get("Gear").Weapons[weaponId]
end

--==========================================================================
-- The built sword (when the developer has supplied none)
--==========================================================================
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weldTo(root: BasePart, piece: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = piece
	weld.Parent = piece
end

-- Built along +Y out of the hilt, as a Roblox tool handle is.
local function buildSword(): (Model, BasePart)
	local model = Instance.new("Model")
	local hilt = part(model, "Hilt", Vector3.new(0.32, 1.5, 0.32), CFrame.new(), PALETTE.grip, Enum.Material.Fabric)
	model.PrimaryPart = hilt
	for i = -1, 1 do
		weldTo(hilt, part(model, "Binding", Vector3.new(0.4, 0.16, 0.4), CFrame.new(0, i * 0.42, 0), PALETTE.guard, Enum.Material.Fabric))
	end
	local pommel = part(model, "Pommel", Vector3.new(0.52, 0.4, 0.52), CFrame.new(0, -0.9, 0), PALETTE.pommel, Enum.Material.Metal)
	pommel.Shape = Enum.PartType.Ball
	weldTo(hilt, pommel)
	weldTo(hilt, part(model, "Guard", Vector3.new(2.6, 0.26, 0.5), CFrame.new(0, 0.85, 0), PALETTE.guard, Enum.Material.Metal))
	for _, side in { -1, 1 } do
		weldTo(hilt, part(model, "GuardTip", Vector3.new(0.5, 0.24, 0.44), CFrame.new(side * 1.4, 0.78, 0) * CFrame.Angles(0, 0, math.rad(side * 18)), PALETTE.guard, Enum.Material.Metal))
	end
	weldTo(hilt, part(model, "Blade", Vector3.new(0.62, 4.6, 0.2), CFrame.new(0, 3.3, 0), PALETTE.steel, Enum.Material.Metal))
	weldTo(hilt, part(model, "Fuller", Vector3.new(0.2, 3.9, 0.24), CFrame.new(0, 3.2, 0), PALETTE.steelDark, Enum.Material.Metal))
	for _, side in { -1, 1 } do
		weldTo(hilt, part(model, "Edge", Vector3.new(0.12, 4.6, 0.14), CFrame.new(side * 0.28, 3.3, 0), PALETTE.edge, Enum.Material.Metal))
	end
	weldTo(hilt, part(model, "Point", Vector3.new(0.6, 0.9, 0.2), CFrame.new(0, 5.9, 0) * CFrame.Angles(0, 0, math.rad(45)), PALETTE.edge, Enum.Material.Metal))

	-- the streak of a cut: off until the blade is really moving (the clients switch it on for a swing)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = hilt
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Position = Vector3.new(0, 5.9, 0)
	a1.Parent = hilt
	local trail = Instance.new("Trail")
	trail.Name = "Swing"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.1
	trail.LightEmission = 0.35
	trail.LightInfluence = 0
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Color = ColorSequence.new(Color3.fromRGB(226, 232, 240), Color3.fromRGB(150, 160, 175))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = hilt
	return model, hilt
end

--==========================================================================
-- A model the developer supplied
--==========================================================================
local function biggestPart(root: Instance): BasePart?
	local best: BasePart? = nil
	local bestVolume = -1
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best
end

-- Where a hand-made weapon may live, best first. `Models` is Rojo's and is only still read so that anything already
-- there keeps working while it is moved.
local WEAPON_HOMES = {
	{ path = { "Assets", "Weapons" }, safe = true },
	{ path = { "Weapons" }, safe = true },
	{ path = { "Models", "Weapons" }, safe = false },
}

local function findWeaponSource(weaponId: string): Instance?
	for _, home in WEAPON_HOMES do
		local node: Instance? = ServerStorage
		for _, step in home.path do
			node = node and node:FindFirstChild(step)
		end
		local found = node and node:FindFirstChild(weaponId)
		if found then
			if not home.safe then
				log:warn(("'%s' is in ServerStorage.Models: Rojo OWNS that folder and deletes it on the next connect. Move it to ServerStorage.Assets.Weapons."):format(weaponId))
			end
			return found
		end
	end
	return nil
end

--[[
	A weapon arrives as a Part / MeshPart (the whole weapon IS the hilt), a Tool (its Handle is the hilt) or a Model (a
	part called Hilt, else its PrimaryPart, else its biggest part). Anything shorter than a forearm is a piece of a
	weapon, not a weapon, and is refused. Old joints and every script come out.
]]
local function suppliedModel(weaponId: string): (Model?, BasePart?)
	local source = findWeaponSource(weaponId)
	if not source then
		return nil, nil
	end
	local clone: Model
	local hilt: BasePart?
	if source:IsA("BasePart") then
		clone = Instance.new("Model")
		local copy = source:Clone()
		copy.Parent = clone
		clone.PrimaryPart = copy
		hilt = copy
	elseif source:IsA("Tool") then
		local wrapper = source:Clone()
		local handle = wrapper:FindFirstChild("Handle")
		hilt = if handle and handle:IsA("BasePart") then handle else biggestPart(wrapper)
		clone = Instance.new("Model")
		for _, child in wrapper:GetChildren() do
			child.Parent = clone
		end
		wrapper:Destroy()
		clone.PrimaryPart = if hilt and hilt:IsDescendantOf(clone) then hilt else nil
	elseif source:IsA("Model") then
		clone = source:Clone()
		local found = clone:FindFirstChild("Hilt") or clone.PrimaryPart or biggestPart(clone)
		hilt = if found and found:IsA("BasePart") then found else nil
	else
		log:warn(("weapon '%s' is a %s: expected a Part, a Tool or a Model"):format(weaponId, source.ClassName))
		return nil, nil
	end
	if not hilt then
		clone:Destroy()
		log:warn(("weapon '%s' has no parts in it"):format(weaponId))
		return nil, nil
	end
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			lo = lo:Min(d.Position - d.Size / 2)
			hi = hi:Max(d.Position + d.Size / 2)
		end
	end
	local extent = hi - lo
	if math.max(extent.X, extent.Y, extent.Z) < 3 then
		clone:Destroy()
		log:warn(("weapon '%s' is under 3 studs long: that is a piece of a weapon. Put the WHOLE model in ServerStorage.Assets.Weapons."):format(weaponId))
		return nil, nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy() -- a joint that points outside the clone drags the blade back to the original
		elseif d:IsA("LuaSourceContainer") then
			log:warn(("stripped a %s from weapon model '%s'"):format(d.ClassName, weaponId))
			d:Destroy()
		end
	end
	-- whatever is not the hilt is held to it
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") and d ~= hilt then
			weldTo(hilt, d)
		end
	end
	return clone, hilt
end

--==========================================================================
-- On the body
--==========================================================================
local function modelName(weaponId: string): string
	return "Weapon_" .. weaponId
end

local function clearWeapons(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 7) == "Weapon_" then
			child:Destroy()
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and string.sub(d.Name, 1, 11) == "WeaponGrip_" then
			d:Destroy()
		end
	end
end

-- Where the weapon's joint goes: the hand (in use) or its place on the body.
local function seat(character: Model, weaponId: string, joint: Motor6D, inHand: boolean): boolean
	local def = gearDef(weaponId)
	if not def then
		return false
	end
	local hilt = joint.Part1
	if not hilt then
		return false
	end
	local seatOnWeapon = if def.Kit then CFrame.new() else GearModels.gripSeat(hilt)
	if inHand then
		local hand = character:FindFirstChild(def.Hand .. "Hand")
		if not (hand and hand:IsA("BasePart")) then
			return false
		end
		local gripAt = hand:FindFirstChild(def.Hand .. "GripAttachment")
		local base = if gripAt and gripAt:IsA("Attachment") then gripAt.CFrame else CFrame.new(0, -0.16, 0)
		joint.Part0 = hand
		joint.C0 = base * GearModels.frame(def.Grip)
		joint.C1 = seatOnWeapon
		joint.Parent = hand
	else
		local limb = character:FindFirstChild(def.Sheath.Part)
		if not (limb and limb:IsA("BasePart")) then
			return false
		end
		joint.Part0 = limb
		joint.C0 = GearModels.frame(def.Sheath.At)
		joint.C1 = seatOnWeapon
		joint.Parent = limb
	end
	return true
end

local function jointOf(character: Model, weaponId: string): Motor6D?
	local found = character:FindFirstChild("WeaponGrip_" .. weaponId, true)
	return if found and found:IsA("Motor6D") then found else nil
end

local function publish(player: Player)
	local state = stateOf(player)
	local character = player.Character
	local chosen = state.carried[state.selected]
	if character then
		character:SetAttribute("Weapon", chosen and chosen.weaponId)
		character:SetAttribute("WeaponDrawn", if chosen and state.drawn then true else nil)
	end
	if barEvent then
		local list = {}
		for i, c in state.carried do
			list[i] = { id = c.weaponId, name = c.name, kind = c.kind }
		end
		barEvent:FireClient(player, { weapons = list, selected = state.selected, drawn = state.drawn and chosen ~= nil })
	end
end

-- What this player carries: the weapon items of their inventory that configs/Gear knows how to show, in the bar's order.
local function readCarried(player: Player): { Carried }
	local items = Config.get("Items")
	local weapons = Config.get("Weapons")
	local gear = Config.get("Gear")
	local order: { [string]: number } = {}
	for i, id in gear.Starter.Weapons do
		order[id] = i
	end
	local list: { Carried } = {}
	local seen: { [string]: boolean } = {}
	for _, instance in InventoryService.list(player) do
		local item = items[instance.itemId]
		local weaponId = item and item.Category == "Weapon" and item.WeaponId
		if weaponId and not seen[weaponId] and gear.Weapons[weaponId] and weapons[weaponId] then
			seen[weaponId] = true
			table.insert(list, { uid = instance.uid, weaponId = weaponId, name = weapons[weaponId].DisplayName or weaponId, kind = gear.Weapons[weaponId].Kind })
		end
	end
	table.sort(list, function(a, b)
		local ia, ib = order[a.weaponId] or 100, order[b.weaponId] or 100
		if ia ~= ib then
			return ia < ib
		end
		return a.weaponId < b.weaponId
	end)
	return list
end

-- Builds every carried weapon on `character`, each at its place on the body; the chosen one in the hand if drawn.
local function attachAll(player: Player, character: Model)
	local state = stateOf(player)
	clearWeapons(character)
	state.carried = readCarried(player)
	state.built = character
	if #state.carried == 0 then
		state.selected = 0
		state.drawn = false
		publish(player)
		return
	end
	if state.selected < 1 or state.selected > #state.carried then
		state.selected = 1
	end
	for index, carried in state.carried do
		local def = gearDef(carried.weaponId)
		local model: Model?, hilt: BasePart? = nil, nil
		if def.Kit then
			model, hilt = GearModels.weapon(carried.weaponId, def)
		else
			model, hilt = suppliedModel(carried.weaponId)
			if not (model and hilt) then
				model, hilt = buildSword()
			end
		end
		if model and hilt then
			model.Name = modelName(carried.weaponId)
			-- the joint is made before the weapon enters the world: its parts are loose the moment they are parented
			local joint = Instance.new("Motor6D")
			joint.Name = "WeaponGrip_" .. carried.weaponId
			joint.Part1 = hilt
			local inHand = state.drawn and index == state.selected
			if seat(character, carried.weaponId, joint, inHand) then
				model.Parent = character
			else
				joint:Destroy()
				model:Destroy()
				log:warn(("no place on %s's body for %s"):format(player.Name, carried.weaponId))
			end
		end
	end
	local chosen = state.carried[state.selected]
	if chosen then
		EquipmentService.equip(player, chosen.uid)
	end
	publish(player)
	log:info(("%s carries %d weapon(s); %s %s"):format(player.Name, #state.carried, chosen and chosen.weaponId or "none", if state.drawn then "in hand" else "put away"))
end

local function tell(player: Player)
	local state = stateOf(player)
	local chosen = state.carried[state.selected]
	for _, handler in drawnChanged do
		task.spawn(handler, player, if chosen and state.drawn then chosen.weaponId else nil, state.drawn)
	end
end

--==========================================================================
-- For the other services
--==========================================================================

-- Is `player`'s chosen weapon in the hand? (A weapon that is put away does not cut.)
function WeaponVisualService.isDrawn(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.drawn and state.carried[state.selected] ~= nil
end

-- The id of the weapon in `player`'s hand, or nil.
function WeaponVisualService.inHand(player: Player): string?
	local state = states[player]
	local chosen = state and state.drawn and state.carried[state.selected]
	return if chosen then chosen.weaponId else nil
end

-- Calls `handler(player, weaponId or nil, drawn)` whenever what a player holds changes (World/LanternService hangs
-- the lantern on the belt when both hands are needed; World/RangedCombatService lets a drawn bow down).
function WeaponVisualService.onChanged(handler: (Player, string?, boolean) -> ())
	table.insert(drawnChanged, handler)
end

--[[
	Takes the weapon at `index` of the bar in hand (1..), or with 0 puts the one in hand away. Returns false when there is
	no such place or no body.
]]
function WeaponVisualService.select(player: Player, index: number): boolean
	local state = stateOf(player)
	local character = player.Character
	if not character or state.built ~= character then
		return false
	end
	index = math.floor(index)
	if index == 0 then
		return WeaponVisualService.setDrawn(player, false)
	end
	local chosen = state.carried[index]
	if not chosen then
		return false
	end
	-- the one in hand goes back to its place
	local old = state.carried[state.selected]
	if old and state.drawn and state.selected ~= index then
		local joint = jointOf(character, old.weaponId)
		if joint then
			seat(character, old.weaponId, joint, false)
		end
	end
	state.selected = index
	state.drawn = true
	local joint = jointOf(character, chosen.weaponId)
	if joint then
		seat(character, chosen.weaponId, joint, true)
	end
	EquipmentService.equip(player, chosen.uid)
	publish(player)
	tell(player)
	return true
end

-- In the hand (true) or put away (false): the chosen weapon.
function WeaponVisualService.setDrawn(player: Player, wantDrawn: boolean): boolean
	local state = stateOf(player)
	local character = player.Character
	local chosen = state.carried[state.selected]
	if not (character and chosen) or state.built ~= character then
		return false
	end
	local joint = jointOf(character, chosen.weaponId)
	if not joint or not seat(character, chosen.weaponId, joint, wantDrawn) then
		return false
	end
	state.drawn = wantDrawn
	publish(player)
	tell(player)
	return true
end

function WeaponVisualService.toggle(player: Player)
	WeaponVisualService.setDrawn(player, not WeaponVisualService.isDrawn(player))
end

-- Reads again what the player carries and rebuilds it (a weapon was gained or lost).
function WeaponVisualService.refresh(player: Player)
	local character = player.Character
	if character then
		attachAll(player, character)
		tell(player)
	end
end

--==========================================================================
local function onCharacter(player: Player, character: Model)
	task.spawn(function()
		-- the square body first (its hands are the ones a weapon is held by), and the starter kit a moment after joining
		if not AvatarService.waitReady(character) then
			return
		end
		for _ = 1, 20 do
			if player.Character ~= character or not character.Parent then
				return
			end
			if #readCarried(player) > 0 then
				break
			end
			task.wait(0.25)
		end
		if player.Character ~= character or not character.Parent then
			return
		end
		local state = stateOf(player)
		state.drawn = true -- armed and on guard from the first frame
		attachAll(player, character)
		tell(player)
		-- once more a moment later: a client that was still loading has the bar anyway
		task.wait(2)
		if player.Character == character then
			publish(player)
		end
	end)
end

function WeaponVisualService.Init() end

function WeaponVisualService.Start()
	barEvent = Net.getEvent("WeaponBar")

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	local lastAsk: { [Player]: number } = {}
	Net.getEvent("RequestSelectWeapon").OnServerEvent:Connect(function(player: Player, index: any)
		if typeof(index) ~= "number" or index ~= index or index < 0 or index > 20 then
			return
		end
		local now = os.clock()
		if now - (lastAsk[player] or 0) < 0.08 then
			return
		end
		lastAsk[player] = now
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			WeaponVisualService.select(player, index)
		end
	end)
	Net.getEvent("RequestToggleWeapon").OnServerEvent:Connect(function(player: Player)
		WeaponVisualService.toggle(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastAsk[player] = nil
	end)
	log:info("ready")
end

return WeaponVisualService
