--!strict
--[[
	Trial task: `exit`
	The way out (AreaPlan §9). There is no gate at the end of the castle: there is a little door in the west
	of the hall, a stair that goes up and up inside the wall, a walk round the top of the keep, and at the
	end of it an arch with a light in it. The party goes up together and out together.

	  1. THE DOOR. Locked. A held "Unlock" at the lock, with the scribe's key in the hands (one key opens it
	     for everybody). The key turns, the iron plate on the leaf shifts, and the leaf swings in on its
	     hinge, heavy and slow, and shows the stair. Without the key the door says whose it is.
	  2. THE STAIR AND THE WALK. Scenery (tools/BuildKeepInterior): nothing to do but climb. Nothing in the
	     castle has ever let anybody up here, which is the reason it is the way out.
	  3. THE ARCH. A held "Leave" in the light. It does not take the party until every living player has
	     it: the first to arrive is told how many are still coming, and a player who dies drops out of the
	     count. When all are there the screen closes (EndingEvent), and a few seconds later the party goes
	     back to the Hub.

	THIS TASK IS THE END OF THE RUN. It calls the trial done (the last one), which stops the pressure and
	lets AreaService do whatever it does at the last chamber (nothing: there is no gate).

	Params (configs/Trials):
	  door     dotted path of the Model of the roof door (Interior.RoofDoor)
	  arch     dotted path of the Model of the arch (Interior.ExitArch)
	  key      the item id of the key
	  leave    seconds of the held "Leave"
	  after    seconds between the screen closing and the party leaving

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Server = script.Parent.Parent.Parent
local BackpackService = require(script.Parent.Parent.BackpackService)
local RunModService = require(script.Parent.Parent.RunModService)
local TeleportService = require(Server.Services.TeleportService)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(script.Parent.Util)

local Exit = {}

local function easeInOut(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function run(duration: number, step: (number) -> ())
	local started = os.clock()
	while true do
		local a = (os.clock() - started) / duration
		if a >= 1 then
			step(1)
			return
		end
		step(a)
		RunService.Heartbeat:Wait()
	end
end

function Exit.create(ctx: any, def: any)
	local connections: { any } = {}
	local unlocked = false
	local ready: { [Player]: boolean } = {}
	local leaving = false
	local ticker: RBXScriptConnection? = nil
	local gate: BasePart? = nil
	local lastCount = -1

	local function living(): { Player }
		local out: { Player } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(out, player)
			end
		end
		return out
	end

	local function openDoor(door: Model)
		local leaf = door:FindFirstChild("Leaf") :: Model?
		local hinge = door:FindFirstChild("Hinge") :: BasePart?
		if not (leaf and hinge) then
			return
		end
		door:SetAttribute("Locked", false)
		local home = leaf:GetPivot()
		local hingeCf = CFrame.new(hinge.Position)
		-- the lock plate: the bolt draws back first, with a click you can see
		local lock = leaf:FindFirstChild("Lock") :: BasePart?
		if lock then
			TweenService:Create(lock, TweenInfo.new(0.4), { Color = Color3.fromRGB(150, 120, 52) }):Play()
		end
		task.wait(0.7)
		run(3.2, function(a)
			local e = easeInOut(a)
			leaf:PivotTo(hingeCf * CFrame.Angles(0, -math.rad(102) * e, 0) * hingeCf:Inverse() * home)
		end)
		for _, d in leaf:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end

	local function ending()
		if leaving then
			return
		end
		leaving = true
		RunModService.setFlag("runComplete", true)
		ctx.hint(nil)
		Net.getEvent("EndingEvent"):FireAllClients({
			title = "The Last Kingdom",
			subtitle = "Book One: the Return",
			lines = {
				"The King kneels, and the bells are quiet.",
				"The way up is open, and you went up it together.",
				"Asterfall remembers.",
				"Nobody has written down what sent the Company north.",
			},
			footer = "To be continued",
		})
		task.spawn(function()
			task.wait(def.after)
			local players = Players:GetPlayers()
			pcall(TeleportService.returnToHub, players, { runComplete = true })
		end)
		ctx.done()
	end

	local function count(): (number, number)
		local alive = living()
		local ok = 0
		for _, p in alive do
			if ready[p] then
				ok += 1
			end
		end
		return ok, #alive
	end

	return {
		start = function()
			local door = Util.find(def.door)
			local arch = Util.find(def.arch)
			if not (door and arch) then
				ctx.warn("exit: missing the roof door or the arch")
				return
			end
			-- THE DOOR
			local leaf = (door :: Model):FindFirstChild("Leaf") :: Model?
			local lock = leaf and leaf:FindFirstChild("Lock") :: BasePart?
			if leaf and lock then
				local doorPrompt = Util.prompt(ctx.folder, lock.Position + Vector3.new(1.4, 0.3, 0), "UnlockPrompt", "Unlock", "The marshal's door", 1.3, 7)
				table.insert(
					connections,
					doorPrompt.Triggered:Connect(function(player: Player)
						if unlocked then
							return
						end
						if BackpackService.count(player, def.key) <= 0 then
							ctx.note("Locked. The scribe keeps the key to this one.", 4)
							return
						end
						unlocked = true
						BackpackService.remove(player, def.key, 1)
						doorPrompt.Enabled = false
						ctx.note("The key turns. Something in the wall lets go.", 4)
						task.spawn(openDoor, door :: Model)
						ctx.hint("Up. Everyone, together.")
					end)
				)
			else
				ctx.warn("exit: the roof door has no lock")
			end

			-- THE ARCH
			gate = (arch :: Model):FindFirstChild("Gate") :: BasePart?
			if gate then
				local leavePrompt = Util.prompt(ctx.folder, (gate :: BasePart).Position, "LeavePrompt", "Leave", "The way out", def.leave, 9)
				table.insert(
					connections,
					leavePrompt.Triggered:Connect(function(player: Player)
						ready[player] = true
						local ok, total = count()
						if ok < total then
							ctx.note(("Ready: %d of %d. Wait for the others."):format(ok, total), 4)
						end
					end)
				)
				table.insert(
					connections,
					Players.PlayerRemoving:Connect(function(player)
						ready[player] = nil
					end)
				)
			end

			ticker = RunService.Heartbeat:Connect(function()
				if leaving or not gate then
					return
				end
				local ok, total = count()
				if ok ~= lastCount then
					lastCount = ok
				end
				if total > 0 and ok >= total then
					-- everyone who is alive is ready, and standing at the light
					local near = true
					for _, player in living() do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if not root or ((root :: BasePart).Position - (gate :: BasePart).Position).Magnitude > 24 then
							near = false
							break
						end
					end
					if near then
						task.spawn(ending)
					end
				end
			end)
		end,

		stop = function()
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
		end,

		progress = function(): (number, number)
			local ok, total = count()
			return ok, math.max(1, total)
		end,
	}
end

return Exit
