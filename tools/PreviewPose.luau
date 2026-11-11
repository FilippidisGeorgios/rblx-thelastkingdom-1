--[[
	PreviewPose — run in the FORGOTTEN LANDS place, in EDIT MODE (it needs the sculpted kit in ServerStorage.Assets).

	Stands a square body in a small photo booth high above the map, puts ONE moment of the player's animation on it
	(a walk, a hold, a cut, a thrust, a draw; the armour, the quiver, the lantern) and leaves it there to be looked at
	from any side, or from the body's own eyes. It is how the clips in Shared/Anim were judged without a playtest for
	every number.

	It runs the modules FRESH from the text of the scripts in the place (not through `require`, which keeps the first
	copy it ever saw for the whole Studio session), so a number that was just synced (tools/SyncFromBundle) is on the body
	the next time this runs.

	HOW IT IS CALLED (from the command bar or the Studio tool, after a sync):
	    local preview = loadstring(game.ServerStorage.TLK_Tools.PreviewPose.Source)()
	    return preview({ weapon = "hunting_bow", track = "bow_aim", t = 0.5, pitch = 10 })

	WHAT THE TABLE MAY SAY (all optional):
	    set      1, 2 or 3: the movement set                        (1)
	    move     a movement clip: "idle", "walk", "walkLeft", "run", "duck"...  ("idle")
	    moveT    seconds into it                                    (0)
	    weapon   a key of configs/Gear.Weapons: it is put in the hand
	    clip     a clip of PlayerActionAnims ("sword_cut_a", "armour_don", "lantern_hold"), with `t` seconds into it
	    track    a track of PlayerActionAnims ("spear_thrust_a", "bow_draw"...), with `t`
	    pitch    the look, degrees up                               (0)
	    armour   true: the armour is worn; "back": it is carried
	    quiver   a number: the quiver, with that many arrows
	    roll     seconds into the roll (and `way`, a Vector3 in the body's space)
	    clear    true: take the booth away and stop

	It returns a line of numbers: where the hands ended up against where they were asked to be.

	NOTE: a tool, not game code. Not synced by Rojo. The booth is `Workspace.TLK_Booth`; `clear = true` removes it.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AT = CFrame.new(0, 3000, 0)

--==========================================================================
-- Fresh modules from disk
--==========================================================================
local loaded: { [string]: any } = {}

-- where a file of the repository lives in the place
local HOMES = {
	{ "scripts/Shared/", "ReplicatedStorage.Shared." },
	{ "scripts/Server/Domain/", "ServerScriptService.Server.Domain." },
	{ "configs/", "ReplicatedStorage.Config." },
}

local function fetch(path: string): string
	for _, home in HOMES do
		if string.sub(path, 1, #home[1]) == home[1] then
			local dotted = home[2] .. string.gsub(string.gsub(string.sub(path, #home[1] + 1), "%.luau$", ""), "/", ".")
			local at: Instance? = game
			for segment in string.gmatch(dotted, "[^.]+") do
				at = at and at:FindFirstChild(segment)
			end
			assert(at and at:IsA("LuaSourceContainer"), "no script in the place for " .. path .. " (sync first)")
			return (at :: any).Source
		end
	end
	error("do not know where " .. path .. " lives in the place")
end

local fresh: (string) -> any

local function folder(dir: string): any
	return setmetatable({}, {
		__index = function(_, name)
			if name == "Parent" then
				return folder((string.gsub(dir, "[^/]+/$", "")))
			end
			return { __path = dir .. name .. ".luau", __dir = dir .. name .. "/" }
		end,
	})
end

function fresh(path: string): any
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local chunk, err = loadstring(fetch(path), "=" .. path)
	assert(chunk, tostring(err))
	local dir = string.gsub(path, "[^/]+$", "")
	local env = setmetatable({
		script = { Parent = folder(dir) },
		require = function(what: any)
			if type(what) == "table" and what.__path then
				return fresh(what.__path)
			end
			return require(what)
		end,
	}, { __index = getfenv() })
	setfenv(chunk, env)
	local value = chunk()
	loaded[path] = value
	return value
end

--==========================================================================
-- The booth and the body
--==========================================================================
local function wall(parent: Instance, name: string, size: Vector3, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromRGB(58, 60, 66)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
end

local function booth(): (Folder, Model)
	local have = Workspace:FindFirstChild("TLK_Booth")
	local dummy = have and have:FindFirstChild("Dummy")
	if have and dummy and have:GetAttribute("Version") == 5 then
		return have :: Folder, dummy :: Model
	end
	if have then
		have:Destroy()
	end
	local made = Instance.new("Folder")
	made.Name = "TLK_Booth"
	made:SetAttribute("Version", 5)
	made.Parent = Workspace
	wall(made, "Back", Vector3.new(70, 34, 1), AT * CFrame.new(0, 6, 16))
	wall(made, "Front", Vector3.new(70, 34, 1), AT * CFrame.new(0, 6, -26))
	wall(made, "Left", Vector3.new(1, 34, 44), AT * CFrame.new(-30, 6, -5))
	wall(made, "Right", Vector3.new(1, 34, 44), AT * CFrame.new(30, 6, -5))
	wall(made, "Floor", Vector3.new(70, 1, 44), AT * CFrame.new(0, -3.7, -5))
	for i, pos in { Vector3.new(-9, 7, -10), Vector3.new(9, 7, -10), Vector3.new(0, 8, 8), Vector3.new(0, 3, -4) } do
		local holder = Instance.new("Part")
		holder.Name = "Light" .. i
		holder.Anchored = true
		holder.Transparency = 1
		holder.CanCollide = false
		holder.Size = Vector3.one
		holder.CFrame = AT * CFrame.new(pos)
		holder.Parent = made
		local light = Instance.new("PointLight")
		light.Range = 34
		light.Brightness = 0.42
		light.Shadows = false
		light.Parent = holder
	end
	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "Dummy"
	-- (its own colours would paint every part black again)
	local colours = rig:FindFirstChildOfClass("BodyColors")
	if colours then
		colours:Destroy()
	end
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			if p.Name:find("Leg") or p.Name:find("Foot") or p.Name == "LowerTorso" then
				p.Color = Color3.fromRGB(70, 62, 54)
			elseif p.Name == "UpperTorso" or p.Name:find("UpperArm") then
				p.Color = Color3.fromRGB(110, 44, 40)
			else
				p.Color = Color3.fromRGB(214, 176, 142)
			end
		end
	end
	rig:PivotTo(AT)
	rig.Parent = made
	return made, rig
end

local ORDER = {
	{ "LowerTorso", "HumanoidRootPart" },
	{ "UpperTorso", "LowerTorso" },
	{ "Head", "UpperTorso" },
	{ "RightUpperArm", "UpperTorso" },
	{ "RightLowerArm", "RightUpperArm" },
	{ "RightHand", "RightLowerArm" },
	{ "LeftUpperArm", "UpperTorso" },
	{ "LeftLowerArm", "LeftUpperArm" },
	{ "LeftHand", "LeftLowerArm" },
	{ "RightUpperLeg", "LowerTorso" },
	{ "RightLowerLeg", "RightUpperLeg" },
	{ "RightFoot", "RightLowerLeg" },
	{ "LeftUpperLeg", "LowerTorso" },
	{ "LeftLowerLeg", "LeftUpperLeg" },
	{ "LeftFoot", "LeftLowerLeg" },
}

-- Puts a pose on the standing body by moving its parts (in edit mode nothing solves the joints for us).
local function stand(dummy: Model, rig: any, pose: { [string]: CFrame })
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	root.CFrame = AT
	for _, pair in ORDER do
		local part = dummy:FindFirstChild(pair[1]) :: BasePart
		local parent = dummy:FindFirstChild(pair[2]) :: BasePart
		local first, second = rig.a0[pair[1]], rig.a1[pair[1]]
		if part and parent and first and second then
			part.CFrame = parent.CFrame * first * (pose[pair[1]] or CFrame.new()) * second:Inverse()
		end
	end
end

-- A built thing whose parts are welded to one part: frees it into anchored parts and remembers where each sits.
local function loosen(model: Instance, anchor: BasePart): { [BasePart]: CFrame }
	local rel: { [BasePart]: CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			rel[d] = anchor.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Motor6D") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return rel
end

local function place(rel: { [BasePart]: CFrame }, at: CFrame)
	for part, offset in rel do
		part.CFrame = at * offset
	end
end

local function v3(v: Vector3): string
	return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z)
end

--==========================================================================
return function(args: { [string]: any }): string
	args = args or {}
	if args.clear then
		local have = Workspace:FindFirstChild("TLK_Booth")
		if have then
			have:Destroy()
		end
		return "the booth is gone"
	end
	loaded = {}
	local ClipPlayer = fresh("scripts/Shared/Anim/ClipPlayer.luau")
	local MoveAnims = fresh("scripts/Shared/Anim/PlayerMoveAnims.luau")
	local ActionAnims = fresh("scripts/Shared/Anim/PlayerActionAnims.luau")
	local WeaponPose = fresh("scripts/Shared/Anim/WeaponPose.luau")
	local GearModels = fresh("scripts/Server/Domain/GearModels.luau")
	local Gear = fresh("configs/Gear.luau")

	local room, dummy = booth()
	for _, old in room:GetChildren() do
		if old:GetAttribute("Gear") then
			old:Destroy()
		end
	end
	for _, old in dummy:GetChildren() do
		if old:IsA("Model") or old.Name == "BeltHook" then
			old:Destroy()
		end
	end
	local rig = ClipPlayer.rig(dummy)
	assert(rig, "the dummy has no joints")
	local notes: { string } = {}

	-- the movement under everything
	local pose: { [string]: CFrame } = {}
	local set = args.set or 1
	local moves = MoveAnims.clips(set)
	local move = moves[args.move or "idle"]
	assert(move, "no movement clip called " .. tostring(args.move))
	ClipPlayer.sample(ClipPlayer.clip("move", move.frames, move.looped), args.moveT or 0, pose, 1)
	if args.roll then
		local def = moves.roll
		ClipPlayer.sample(ClipPlayer.clip("roll", def.frames, false), args.roll, pose, 1)
		pose.LowerTorso = MoveAnims.rollHips(args.roll, args.way or Vector3.new(0, 0, -1))
	end

	-- a clip on top
	if args.clip then
		local clip = ActionAnims.clip(args.clip)
		assert(clip, "no clip called " .. args.clip)
		ClipPlayer.sample(clip, args.t or 0, pose, 1)
	end

	-- the look
	local pitch = math.rad(args.pitch or 0)
	pose.UpperTorso = CFrame.Angles(pitch * 0.34, 0, 0) * (pose.UpperTorso or CFrame.new())
	pose.Head = CFrame.Angles(pitch * 0.5, 0, 0) * (pose.Head or CFrame.new())

	-- the weapon
	local weaponId = args.weapon
	local def = weaponId and Gear.Weapons[weaponId]
	local hiltInHand: CFrame? = nil
	local pull = 0
	if def then
		local side = def.Hand
		local hold = WeaponPose.hold(dummy, def.Kind, side, GearModels.frame(def.Grip), def.String and def.String.Back, def.String and def.String.Draw)
		assert(hold, "the dummy's hands have no grip points")
		hiltInHand = hold.hiltInHand
		local values: { [string]: any } = {}
		local kind = ActionAnims.KINDS[def.Kind]
		if kind.tracks then
			local tr = ActionAnims.track(args.track or kind.hold)
			assert(tr, "no track called " .. tostring(args.track))
			ActionAnims.sample(tr, args.t or 0, values)
			if def.Kind == "bow" then
				pull = WeaponPose.bow(rig, pose, values, hold, pitch, 1)
			else
				WeaponPose.spear(rig, pose, values, hold, pitch, 1)
			end
			table.insert(notes, "asked hand " .. v3(values.hand))
		elseif not args.clip then
			ClipPlayer.sample(ActionAnims.clip(kind.hold), args.t or 0, pose, 1)
		end
		if kind.clips then
			pose.RightUpperArm = CFrame.Angles(pitch * 0.5, 0, 0) * (pose.RightUpperArm or CFrame.new())
		end
	end
	if args.lantern == "hand" then
		ClipPlayer.sample(ActionAnims.clip("lantern_hold"), args.t or 0, pose, 1)
		pose.LeftUpperArm = CFrame.Angles(pitch * 0.4, 0, 0) * (pose.LeftUpperArm or CFrame.new())
		ClipPlayer.level(rig, pose, "Left", nil, 1)
	end

	stand(dummy, rig, pose)

	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	-- where a thing is in the picture of the body's own eyes: degrees to the right and degrees DOWN from where they look
	local eye = Vector3.new(0, 1.5 + 0.2, -0.34)
	local lookTurn = CFrame.Angles(pitch, 0, 0)
	local function seen(name: string, world: Vector3)
		local own = lookTurn:VectorToObjectSpace(root.CFrame:PointToObjectSpace(world) - eye)
		local ahead = -own.Z
		if ahead <= 0.05 then
			table.insert(notes, name .. " behind the eyes")
			return
		end
		table.insert(notes, ("%s %d right %d down (%.1f ahead)"):format(name, math.floor(math.deg(math.atan2(own.X, ahead)) + 0.5), math.floor(math.deg(math.atan2(-own.Y, ahead)) + 0.5), ahead))
	end
	for _, side in { "Right", "Left" } do
		local hand = dummy:FindFirstChild(side .. "Hand") :: BasePart
		local grip = hand:FindFirstChild(side .. "GripAttachment") :: Attachment
		table.insert(notes, side .. " grip " .. v3(root.CFrame:PointToObjectSpace(grip.WorldPosition)))
		seen(side .. " hand", grip.WorldPosition)
	end

	-- the things
	if def and hiltInHand then
		local hand = dummy:FindFirstChild(def.Hand .. "Hand") :: BasePart
		local model: Model, hilt: BasePart
		local seat = CFrame.new()
		if def.Kit then
			model, hilt = GearModels.weapon(weaponId, def)
		else
			local supplied = ServerStorage.Assets.Weapons:FindFirstChild(weaponId)
			assert(supplied, "no model for " .. weaponId)
			model = Instance.new("Model")
			hilt = supplied:Clone()
			hilt.Parent = model
			for _, d in hilt:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Light") then
					(d :: any).Enabled = false
				end
			end
			seat = GearModels.gripSeat(hilt)
		end
		local arrowRel: { [BasePart]: CFrame }? = nil
		local arrow = model:FindFirstChild("Arrow")
		local arrowRoot = arrow and arrow:FindFirstChild("Root")
		if arrow and arrowRoot then
			arrow.Parent = nil
			arrowRel = loosen(arrow, arrowRoot :: BasePart)
			arrow.Parent = model
		end
		local rel = loosen(model, hilt)
		if arrowRel then
			for part in arrowRel do
				rel[part] = nil
			end
		end
		local hiltAt = hand.CFrame * hiltInHand * seat:Inverse()
		place(rel, hiltAt)
		-- the weapon's far end, from the eyes (the picture is 40 degrees up and down, 56 to each side at a field of view of 80)
		local far, farAt = 0, hiltAt.Position
		for part in rel do
			for _, corner in { part.CFrame * (part.Size / 2), part.CFrame * (-part.Size / 2) } do
				local d = (corner - hand.Position).Magnitude
				if d > far then
					far, farAt = d, corner
				end
			end
		end
		seen("far end", farAt)
		local nock = hilt:FindFirstChild("Nock")
		if nock and nock:IsA("Attachment") and def.String then
			nock.Position = Vector3.new(0, 0, def.String.Back + pull)
			if arrowRel then
				local shown = (args.track == "bow_draw" and (args.t or 0) > 0.15) or args.track == "bow_aim"
				place(arrowRel, hiltAt * CFrame.new(0, 0, def.String.Back + pull) * CFrame.Angles(0, math.rad(90), 0))
				for part in arrowRel do
					part.Transparency = if shown and part.Name ~= "Root" then 0 else 1
				end
			end
			table.insert(notes, "nock " .. v3(root.CFrame:PointToObjectSpace(nock.WorldPosition)))
		end
		local support = hilt:FindFirstChild("Support")
		if support and support:IsA("Attachment") then
			table.insert(notes, "shaft at the second hand's distance: see the left grip; hilt " .. v3(root.CFrame:PointToObjectSpace(hilt.Position)))
		end
		model:SetAttribute("Gear", true)
		model.Parent = room
	end
	local function anchorAll(model: Instance)
		for _, d in model:GetDescendants() do
			if d:IsA("WeldConstraint") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	if args.armour == true then
		anchorAll((GearModels.wear(dummy, "Armour", Gear.Back.Armour.Worn)))
	elseif args.armour == "back" then
		anchorAll((GearModels.wear(dummy, "ArmourBundle", Gear.Back.Armour.Bundle)))
	end
	if args.quiver then
		anchorAll(GearModels.quiver(dummy, Gear.Back.Quiver, args.quiver))
	end
	local head = dummy:FindFirstChild("Head") :: BasePart
	head.Transparency = if args.eyes then 1 else 0
	for _, d in head:GetDescendants() do
		if d:IsA("Decal") then
			d.Transparency = if args.eyes then 1 else 0
		end
	end
	return table.concat(notes, " | ")
end
