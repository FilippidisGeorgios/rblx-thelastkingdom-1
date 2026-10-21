--!strict
--[[
	Trial.Torch
	A lit torch in a player's hand, and the clock it carries.

	WHY IT IS A TASK PIECE AND NOT AN ITEM
	The torch is not loot, it is a deadline you carry: it burns for N seconds
	and the flame at the top of the stick IS the countdown, shrinking and
	dimming as it goes, flickering in the last few seconds. No number on the
	screen (docs/systems/Trials.md §7: a timer is always a thing that is
	happening). Chamber 4 uses it to carry fire to braziers; chamber 5's burning
	door will use it the same way.

	It lives in the player's `carried` slot of the backpack (a quest item: no
	pack slot, never banked) so the pack panel shows it, and a death or a new
	chamber can clear it with everything else carried.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local Util = require(script.Parent.Util)

local Torch = {}

local ITEM = "torch"
local FLICKER_SECONDS = 6

type Held = {
	model: Part,
	fire: Fire,
	light: PointLight,
	born: number,
	lifetime: number,
}

local held: { [Player]: Held } = {}
local expiredHandlers: { (Player) -> () } = {}
local connection: RBXScriptConnection? = nil

local function dispose(player: Player)
	local h = held[player]
	if not h then
		return
	end
	held[player] = nil
	h.model:Destroy()
	BackpackService.remove(player, ITEM, 1)
end

local function hand(character: Model): BasePart?
	local right = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if right and right:IsA("BasePart") then right else nil
end

local function ensureLoop()
	if connection then
		return
	end
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, h in held do
			local left = h.lifetime - (now - h.born)
			if left <= 0 or not player.Parent then
				dispose(player)
				for _, fn in expiredHandlers do
					task.spawn(fn, player)
				end
			else
				-- The flame is the clock: it shrinks and dims, and gutters at the end.
				local fraction = left / h.lifetime
				local flicker = if left < FLICKER_SECONDS then (0.75 + 0.25 * math.sin(now * 22)) else 1
				h.fire.Size = math.max(2, 7 * (0.3 + 0.7 * fraction)) * flicker
				h.light.Brightness = (0.5 + 1.1 * fraction) * flicker
			end
		end
		if next(held) == nil and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

--[[
	Lights a torch in `player`'s hand for `seconds`, replacing any they hold.
	Returns false if they have no hand to put it in (dead, no character).
]]
function Torch.give(player: Player, seconds: number): boolean
	local character = player.Character
	local grip = character and hand(character)
	if not (character and grip) then
		return false
	end
	dispose(player)

	local stick = Instance.new("Part")
	stick.Name = "Torch"
	stick.Size = Vector3.new(0.34, 2.4, 0.34)
	stick.Color = Color3.fromRGB(70, 48, 30)
	stick.Material = Enum.Material.Wood
	stick.CanCollide = false
	stick.CanQuery = false
	stick.CanTouch = false
	stick.Massless = true
	stick.CFrame = grip.CFrame * CFrame.new(0, 0.3, -0.35) * CFrame.Angles(math.rad(-25), 0, 0)
	stick.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = grip
	weld.Part1 = stick
	weld.Parent = stick

	-- The bound rag at the head, so it is not just a lit stick.
	local rag = Instance.new("Part")
	rag.Name = "Rag"
	rag.Size = Vector3.new(0.55, 0.7, 0.55)
	rag.Color = Color3.fromRGB(40, 30, 22)
	rag.Material = Enum.Material.Fabric
	rag.CanCollide = false
	rag.CanQuery = false
	rag.CanTouch = false
	rag.Massless = true
	rag.CFrame = stick.CFrame * CFrame.new(0, 1.25, 0)
	rag.Parent = stick
	local ragWeld = Instance.new("WeldConstraint")
	ragWeld.Part0 = stick
	ragWeld.Part1 = rag
	ragWeld.Parent = rag

	local fire, light = Util.flame(rag, 7, 18)

	held[player] = { model = stick, fire = fire, light = light, born = os.clock(), lifetime = seconds }
	-- Other things carried (a jar of oil, an unlit torch) stay in the hands.
	BackpackService.add(player, ITEM, 1, true)
	ensureLoop()
	return true
end

function Torch.isLit(player: Player): boolean
	return held[player] ~= nil
end

-- Spent: used on a brazier or a door.
function Torch.consume(player: Player)
	dispose(player)
end

-- Seconds of flame left, 0 if none.
function Torch.remaining(player: Player): number
	local h = held[player]
	if not h then
		return 0
	end
	return math.max(0, h.lifetime - (os.clock() - h.born))
end

-- Called when a torch burns out in somebody's hand. Returns something to Disconnect.
function Torch.onExpired(fn: (Player) -> ()): { Disconnect: (self: any) -> () }
	table.insert(expiredHandlers, fn)
	return {
		Disconnect = function()
			local i = table.find(expiredHandlers, fn)
			if i then
				table.remove(expiredHandlers, i)
			end
		end,
	}
end

Players.PlayerRemoving:Connect(function(player)
	local h = held[player]
	if h then
		held[player] = nil
		h.model:Destroy()
	end
end)

return Torch
