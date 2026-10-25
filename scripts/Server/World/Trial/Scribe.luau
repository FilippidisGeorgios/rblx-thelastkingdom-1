--!strict
--[[
	Trial task: `scribe`
	The one living thing left in the keep: a man at a writing desk who has not put his quill down in forty
	years. He is the way up, because he has the key to the little door in the west of the hall, and he will
	not hand it over until he has said what he has to say (AreaPlan §9: "the scribe NPC gives the key, but
	only after the player has heard the whole dialogue").

	THE DIALOGUE is spoken, line by line, over his head, each held long enough to read, in the order a man
	tells it who has told it to the empty hall every night: who came, who the King was, what he brought up,
	what the bells did, who the party freed, where the way out is. It only goes on while somebody is near
	enough to hear it (the lines pause when everyone walks away and take up where they stopped), it cannot
	be hurried by pressing a key, and it cannot be started twice. At the end he gives the key.

	THE KEY is one item (`keep_key`, carried, never banked) put into the hands of whoever started the
	conversation. If that player dies with it, the scribe will give another to whoever asks, for he has
	copied it by hand. Nothing is gated by who holds it: one key opens the door for the whole party.

	Params (configs/Trials):
	  at        dotted path of the part he stands at (Interior.Desk.ScribeAt)
	  enemy     the configs/Enemies id of his body
	  name      what the nameplate says
	  lines     the dialogue
	  key       the item id of the key

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackpackService = require(script.Parent.Parent.BackpackService)
local EnemyService = require(script.Parent.Parent.EnemyService)
local Util = require(script.Parent.Util)

local Scribe = {}

local HEARING = 34 -- studs: closer than this and you can hear him

local function speechBubble(head: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(420, 120)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = head

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(16, 12, 10)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 118, 52)
	stroke.Thickness = 1.5
	stroke.Parent = back
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = back

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.TextSize = 19
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(238, 226, 196)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = back
	return gui, label
end

local function nameTag(head: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(300, 26)
	gui.StudsOffset = Vector3.new(0, 2.0, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(222, 186, 96)
	label.TextStrokeColor3 = Color3.fromRGB(10, 6, 4)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return gui
end

function Scribe.create(ctx: any, def: any)
	local model: Model? = nil
	local prompt: ProximityPrompt? = nil
	local bubble: BillboardGui? = nil
	local line: TextLabel? = nil
	local speaking = false
	local spoken = false
	local alive = true
	local given = false

	local function someoneNear(at: Vector3): boolean
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and (root.Position - at).Magnitude <= HEARING then
				return true
			end
		end
		return false
	end

	local function keyHeld(): boolean
		for _, player in Players:GetPlayers() do
			if BackpackService.count(player, def.key) > 0 then
				return true
			end
		end
		return false
	end

	local function say(text: string)
		if line then
			line.Text = text
		end
		if bubble then
			bubble.Enabled = text ~= ""
		end
	end

	local function giveKey(player: Player)
		if BackpackService.add(player, def.key, 1, true) > 0 then
			given = true
			ctx.note("He holds out a key, black with handling. You take it.", 5)
			return true
		end
		return false
	end

	local function converse(starter: Player)
		if speaking or spoken then
			return
		end
		speaking = true
		if prompt then
			prompt.Enabled = false
		end
		local head = (model :: Model):FindFirstChild("Head") :: BasePart
		for i, text in def.lines do
			-- he waits for an audience
			while alive and not someoneNear(head.Position) do
				task.wait(0.5)
			end
			if not alive then
				return
			end
			say(text)
			local seconds = math.max(3.8, #text / 16)
			task.wait(seconds)
		end
		say("")
		spoken = true
		speaking = false
		local who = starter
		if not (who.Character and who.Character:FindFirstChild("HumanoidRootPart")) then
			for _, p in Players:GetPlayers() do
				if p.Character then
					who = p
					break
				end
			end
		end
		giveKey(who)
		ctx.done()
		-- if the key is lost he gives another to whoever asks
		if prompt then
			prompt.ActionText = "Ask for the key"
			prompt.ObjectText = "The scribe"
			prompt.HoldDuration = 1.2
			prompt.Enabled = true
		end
	end

	return {
		start = function()
			local at = Util.find(def.at)
			if not at then
				ctx.warn("scribe: no desk spot at " .. tostring(def.at))
				return
			end
			local spot = at :: BasePart
			model = EnemyService.spawnStatic(def.enemy, spot.Position + Vector3.new(0, 1.5, 0), spot.Position + Vector3.new(0, 1.5, 40), spot.Position.Y - 1)
			if not model then
				ctx.warn("scribe: no body for " .. tostring(def.enemy))
				return
			end
			local m = model :: Model
			local head = m:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				bubble, line = speechBubble(head)
				;(bubble :: BillboardGui).Enabled = false
				nameTag(head, def.name)
			end
			prompt = Util.prompt(ctx.folder, spot.Position + Vector3.new(0, 3.4, 1.0), "SpeakPrompt", "Speak with him", "The scribe", 0.5, 8)
			local p = prompt :: ProximityPrompt
			p.Triggered:Connect(function(player: Player)
				if spoken then
					-- a second key, if nobody has the first
					if not keyHeld() then
						giveKey(player)
					else
						ctx.note("He nods at the one who already has it.", 3)
					end
					return
				end
				task.spawn(converse, player)
			end)
			ctx.note("A candle, and the scratch of a quill. Somebody is alive in here.", 5)
		end,

		stop = function()
			-- he stays at his desk, and stays speaking if he was
			alive = alive
		end,

		progress = function(): (number, number)
			return if spoken then 1 else 0, 1
		end,
	}
end

return Scribe
