--[[
	Filmstrip — run in EDIT MODE (either place). A whole movement in ONE picture.

	PreviewPose stands one body in one moment; this stands a ROW of bodies, each at the next moment of the same clip,
	seen from the side through a long lens, so a walk, a run, a crouch walk, the roll or a sword cut can be judged as a
	whole (the step, the arms against the legs, the drop at each footfall, where the head goes) in a single capture.

	HOW IT IS CALLED (after a sync, from the Studio tool):
	    local film = loadstring(game.ServerStorage.TLK_Tools.Filmstrip.Source)()
	    return film({ move = "walk", count = 8 })

	WHAT THE TABLE MAY SAY (all optional):
	    set      the movement set, 1..3                              (1)
	    move     a clip of PlayerMoveAnims: "walk", "run", "duck", "roll", "walkLeft"...  ("idle")
	    action   a clip of PlayerActionAnims laid over it ("sword_cut_a"...)
	    count    how many bodies                                     (8)
	    from, to the stretch of the clip, seconds                    (the whole clip)
	    gap      studs between two bodies                            (4.2)
	    view     "side" or "front"                                    ("side")
	    clear    true: take it all away and give the camera back

	Uses the modules FRESH from the scripts in the place (as PreviewPose does). NOT game code; not synced by Rojo into
	the game (it rides in the sync bundle's TLK_Tools, which is deleted afterwards).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AT = CFrame.new(0, 3400, 0)

local loaded: { [string]: any } = {}
local HOMES = {
	{ "scripts/Shared/", "ReplicatedStorage.Shared." },
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

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- a body with no joints: every part placed from the pose and the joints' rest frames
local function stand(model: Model, a0: { [string]: CFrame }, a1: { [string]: CFrame }, pose: { [string]: CFrame }, at: CFrame)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.CFrame = at
	local cf: { [string]: CFrame } = { HumanoidRootPart = at }
	for _, pair in ORDER do
		local p = model:FindFirstChild(pair[1]) :: BasePart
		local parentCf = cf[pair[2]]
		if p and parentCf and a0[pair[1]] and a1[pair[1]] then
			cf[pair[1]] = parentCf * a0[pair[1]] * (pose[pair[1]] or CFrame.new()) * a1[pair[1]]:Inverse()
			p.CFrame = cf[pair[1]]
		end
	end
end

-- the lowest corner of a part (a turned foot stands on its heel or its toe, not on its middle)
local function lowest(p: BasePart): number
	local h = p.Size / 2
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, (p.CFrame * Vector3.new(h.X * x, h.Y * y, h.Z * z)).Y)
			end
		end
	end
	return low
end

return function(args: { [string]: any }): string
	args = args or {}
	local old = Workspace:FindFirstChild("TLK_Film")
	if old then
		old:Destroy()
	end
	local camera = Workspace.CurrentCamera
	if args.clear then
		camera.FieldOfView = 70
		return "the filmstrip is gone"
	end
	loaded = {}
	local ClipPlayer = fresh("scripts/Shared/Anim/ClipPlayer.luau")
	local MoveAnims = fresh("scripts/Shared/Anim/PlayerMoveAnims.luau")
	local ActionAnims = fresh("scripts/Shared/Anim/PlayerActionAnims.luau")

	local room = Instance.new("Folder")
	room.Name = "TLK_Film"
	room.Parent = Workspace

	local count = args.count or 8
	local gap = args.gap or 4.2
	local width = gap * count + 8
	-- a floor with a line every stud, and a plain wall behind, so steps and drops can be read
	local floor = part(room, Vector3.new(width, 1, 14), AT * CFrame.new(gap * (count - 1) / 2, -3.5, 0), Color3.fromRGB(64, 60, 56))
	part(room, Vector3.new(width, 20, 1), AT * CFrame.new(gap * (count - 1) / 2, 6, if args.view == "front" then 8 else 6), Color3.fromRGB(150, 150, 156))
	local lamp = part(room, Vector3.one, AT * CFrame.new(gap * (count - 1) / 2, 14, -14), Color3.new(1, 1, 1))
	lamp.Transparency = 1
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 40
	light.Brightness = 2
	light.Angle = 120
	light.Parent = lamp

	-- the body: a plain R15 with the game's colours (legs dark, coat red, skin)
	-- the game's own square body (Services/AvatarService: block parts, every scale 1, no body type, no proportion)
	local description = Instance.new("HumanoidDescription")
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	local template = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	local colours = template:FindFirstChildOfClass("BodyColors")
	if colours then
		colours:Destroy()
	end
	-- the joints rest frames, whatever kind of joint the engine gave the body (Motor6D or AnimationConstraint)
	local rig = ClipPlayer.rig(template)
	assert(rig, "the body has no joints")
	local a0: { [string]: CFrame }, a1: { [string]: CFrame } = rig.a0, rig.a1
	for _, d in template:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			if d.Name:find("Leg") or d.Name:find("Foot") or d.Name == "LowerTorso" then
				d.Color = Color3.fromRGB(70, 62, 54)
			elseif d.Name == "UpperTorso" or d.Name:find("UpperArm") then
				d.Color = Color3.fromRGB(120, 46, 40)
			elseif d.Name == "RightHand" or d.Name == "RightLowerArm" then
				d.Color = Color3.fromRGB(236, 196, 160) -- the right arm a shade lighter: which arm is which
			else
				d.Color = Color3.fromRGB(200, 160, 128)
			end
		end
	end

	if args.geometry then
		local out = {}
		local hum = template:FindFirstChildOfClass("Humanoid")
		table.insert(out, "HipHeight " .. (hum and hum.HipHeight or -1))
		for _, n in { "HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightUpperArm", "RightLowerArm", "RightHand" } do
			local p = template:FindFirstChild(n) :: BasePart
			local line = n .. " size " .. tostring(p.Size)
			if a0[n] then
				line ..= " a0 " .. tostring(a0[n].Position) .. " a1 " .. tostring(a1[n].Position)
			end
			table.insert(out, line)
		end
		template:Destroy()
		return table.concat(out, " | ")
	end
	local set = args.set or 1
	local moves = MoveAnims.clips(set)
	local name = args.move or "idle"
	local def = moves[name]
	assert(def, "no movement clip called " .. tostring(name))
	local clip = ClipPlayer.clip("move", def.frames, def.looped)
	local length = def.frames[#def.frames].time
	local action = args.action and ActionAnims.clip(args.action)
	if args.action then
		assert(action, "no action clip called " .. tostring(args.action))
		length = (action :: any).length or length
	end
	local from = args.from or 0
	local to = args.to or length
	-- a looped clip's last frame is its first: leave it out
	local steps = if def.looped and not args.action and args.to == nil then count else math.max(1, count - 1)

	-- side: they walk to the right of the picture; front: they walk at the camera
	local facing = if args.view == "front" then CFrame.new() else CFrame.Angles(0, math.rad(-90), 0)
	-- a crouch: the Humanoid lowers the root itself (CrouchService), so the body is shown lowered by as much
	local lower = args.lower or (if string.sub(name, 1, 4) == "duck" then MoveAnims.CROUCH_DROP or 0 else 0)
	local headTop, headAt = -math.huge, Vector3.zero
	local lines = {}
	-- where the feet are with no pose at all: every height below is measured from there (0 = standing on the floor)
	local rest = 0
	do
		local still = template:Clone()
		stand(still, a0, a1, {}, AT)
		local low = math.huge
		for _, foot in { "RightFoot", "LeftFoot" } do
			local f = still:FindFirstChild(foot) :: BasePart
			low = math.min(low, lowest(f))
		end
		rest = low
		still:Destroy()
	end
	local times: { number }? = args.times
	if times then
		count = #times
	end
	for i = 0, count - 1 do
		local t = if times then times[i + 1] else from + (to - from) * i / steps
		local body = template:Clone()
		body.Name = ("At%.2f"):format(t)
		local pose: { [string]: CFrame } = {}
		ClipPlayer.sample(clip, t, pose, 1)
		if name == "roll" then
			pose.LowerTorso = MoveAnims.rollHips(t, Vector3.new(0, 0, -1))
		end
		if action then
			ClipPlayer.sample(action, t, pose, 1)
		end
		local rootAt = AT * CFrame.new(gap * i, -lower, 0) * facing
		stand(body, a0, a1, pose, rootAt)
		local head = body:FindFirstChild("Head") :: BasePart
		local h = head.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					headTop = math.max(headTop, (head.CFrame * Vector3.new(h.X * x, h.Y * y, h.Z * z)).Y - rest)
				end
			end
		end
		headAt += rootAt:PointToObjectSpace(head.Position) / count
		body.Parent = room
		-- how high the lowest foot is against where it stands unposed (below 0: in the ground)
		local low = math.huge
		for _, foot in { "RightFoot", "LeftFoot" } do
			local f = body:FindFirstChild(foot) :: BasePart
			low = math.min(low, (lowest(f)) - rest)
		end
		if args.whole then
			-- the lowest point of the whole body (a roll lies on its back, its shoulders, its head)
			for _, d in body:GetChildren() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					low = math.min(low, lowest(d) - rest)
				end
			end
		end
		table.insert(lines, ("%.2f:%.2f"):format(t, low))
	end
	template:Destroy()
	-- the floor where the unposed feet stand
	floor.CFrame = floor.CFrame + Vector3.new(0, rest - (floor.Position.Y + 0.5), 0)

	local mid = (AT * CFrame.new(gap * (count - 1) / 2, -0.2, 0)).Position
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 14
	local half = (gap * count) / 2 + 1
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local dist = half / math.tan(math.rad(14) / 2 * aspect)
	camera.CFrame = CFrame.lookAt(mid + Vector3.new(0, 1.2, -dist), mid)
	return ("%s %d bodies, %.2f s; highest head top %.2f; head centre from the root (avg) %.2f up %.2f ahead; foot height above the floor at each: %s"):format(name, count, length, headTop, headAt.Y, -headAt.Z, table.concat(lines, " "))
end
