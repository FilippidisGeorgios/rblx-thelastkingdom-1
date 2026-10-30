--!strict
--[[
	IntroCinema
	The camera work of the arrival scene: the shots, the hand-held sway, the soft focus, the grade, the drifting
	ash and the flash of lightning. All of it is client-side and temporary: it exists while the scene plays and
	leaves nothing behind when `rig.destroy()` is called.

	WHY THIS EXISTS. A camera that glides between two parts reads as a screensaver. A real scene has a person
	holding the camera (it is never perfectly still), a lens that cannot keep everything sharp, air with something
	in it, and shots that are CHOSEN: the long look at the castle, the view over a speaker's shoulder toward it,
	the face of the one who is talking. These are those pieces; `Controllers/IntroController` plays them to the
	timeline in `configs/Intro`.

	A SHOT is a function of t (0 at the start of the beat, 1 at its end) that returns the camera's CFrame and
	field of view. It reads the characters live, so it follows whoever it is pointed at.

	GRAPHICS. The effects added here (the soft focus) are post effects like any other: on Low and Medium the
	player's picture setting switches the depth blur off (`Controllers/GraphicsController`), and the ash is an
	ordinary emitter whose rate that controller scales. Nothing here changes what a player can see in play; the
	scene is over before play begins.

	Location: StarterPlayer.StarterPlayerScripts.Client.UI.IntroCinema
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local IntroCinema = {}

export type Shot = (t: number) -> (CFrame, number)

export type Rig = {
	-- Soft focus: the distance that is sharp, how deep the sharp zone is, and how much blur in front and behind.
	focus: (distance: number, radius: number, near: number, far: number, seconds: number) -> (),
	-- A double flash of lightning, a hard one and a weaker one right behind it.
	flash: () -> (),
	-- Puts the camera on `cf`, adding the hand-held sway (0 = a tripod, 1 = a person holding it).
	frame: (cf: CFrame, fov: number, sway: number) -> (),
	destroy: () -> (),
}

--==========================================================================
-- Shots
--==========================================================================

local function ease(t: number): number
	return 0.5 - math.cos(math.pi * t) / 2
end

-- From one mark to another, eased at both ends.
function IntroCinema.marks(a: CFrame, b: CFrame, fov: number): Shot
	return function(t: number)
		return a:Lerp(b, ease(t)), fov
	end
end

-- The head of a character and which way the body faces (flat, so a tilted pose cannot tilt the shot).
local function bearing(character: Model): (BasePart?, Vector3, Vector3)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return nil, Vector3.zAxis, Vector3.xAxis
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.zAxis
	end
	look = look.Unit
	local right = Vector3.yAxis:Cross(look) * -1
	return head :: BasePart, look, right
end

--[[
	Over the speaker's shoulder, looking where they look. The speaker's head is in the near left of the frame,
	the castle is the picture. It creeps in slowly.
]]
function IntroCinema.shoulder(character: Model): Shot?
	local head = bearing(character)
	if not head then
		return nil
	end
	return function(t: number)
		local h, look, right = bearing(character)
		local at = if h then h.Position else Vector3.zero
		-- far enough back that the head is a shape in the lower left, not a wall (a player's hair, wings and
		-- hats are all different; the picture must not depend on how big they are)
		local back = 7.0 - 1.0 * t
		local pos = at - look * back + right * 2.2 + Vector3.new(0, 0.7, 0)
		local target = at + look * 120 + right * 3.2 + Vector3.new(0, 5, 0)
		return CFrame.lookAt(pos, target), 42 - 3 * t
	end
end

--[[
	The speaker's face, three-quarters, from in front: the camera drifts round a little and in, on a long lens
	so the background falls away. `side` is 1 or -1 (which side of the face the camera is on).
]]
function IntroCinema.face(character: Model, side: number): Shot?
	local head = bearing(character)
	if not head then
		return nil
	end
	return function(t: number)
		local h, look, right = bearing(character)
		local at = if h then h.Position else Vector3.zero
		local angle = math.rad(side * (26 - 9 * t))
		local dir = look * math.cos(angle) + right * math.sin(angle)
		local pos = at + dir * (9.2 - 1.2 * t) + Vector3.new(0, 0.3 + 0.25 * t, 0)
		-- aimed a little below the face, so the face sits in the upper middle of the frame, above the dialogue box
		return CFrame.lookAt(pos, at + Vector3.new(0, -1.0, 0)), 30
	end
end

--==========================================================================
-- The rig: what the lens and the air do
--==========================================================================

-- A person holding a camera: slow drift in position, a little in each angle. Perlin noise, so no two moments
-- repeat and nothing is a regular wobble.
local function sway(clock: number, amount: number): CFrame
	local nx = math.noise(clock * 0.37, 11.3, 0.5)
	local ny = math.noise(clock * 0.29, 47.9, 0.5)
	local nr = math.noise(clock * 0.21, 3.7, 0.5)
	return CFrame.new(nx * 0.07 * amount, ny * 0.05 * amount, 0)
		* CFrame.Angles(ny * 0.010 * amount, nx * 0.012 * amount, nr * 0.006 * amount)
end

function IntroCinema.rig(): Rig
	local camera = Workspace.CurrentCamera :: Camera

	-- the lens
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "TLKIntroFocus"
	dof.NearIntensity = 0
	dof.FarIntensity = 0
	dof.FocusDistance = 200
	dof.InFocusRadius = 200
	dof.Parent = Lighting

	-- the grade: a touch cooler and flatter than play, and the thing the lightning flashes through
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "TLKIntroGrade"
	grade.TintColor = Color3.fromRGB(240, 236, 232)
	grade.Saturation = -0.1
	grade.Contrast = 0.06
	grade.Brightness = 0
	grade.Parent = Lighting

	-- the air: ash and a few sparks drifting across the whole frame, carried on the wind
	local volume = Instance.new("Part")
	volume.Name = "TLKIntroAsh"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.CastShadow = false
	volume.Transparency = 1
	volume.Size = Vector3.new(70, 34, 46)
	local ash = Instance.new("ParticleEmitter")
	ash.Name = "Ash"
	ash.Shape = Enum.ParticleEmitterShape.Box
	ash.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	ash.Rate = 22
	ash.Lifetime = NumberRange.new(6, 10)
	ash.Speed = NumberRange.new(0.4, 1.8)
	ash.Acceleration = Vector3.new(2.4, 0.5, -0.8)
	ash.Rotation = NumberRange.new(0, 360)
	ash.RotSpeed = NumberRange.new(-40, 40)
	ash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.05) })
	ash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.55),
		NumberSequenceKeypoint.new(0.85, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	ash.Color = ColorSequence.new(Color3.fromRGB(255, 176, 96), Color3.fromRGB(150, 148, 146))
	ash.LightEmission = 0.5
	ash.LockedToPart = false
	ash.Parent = volume
	-- parented last, so the picture settings see the emitter already set up
	volume.Parent = camera

	local rig = {} :: Rig

	function rig.focus(distance: number, radius: number, near: number, far: number, seconds: number)
		if not dof.Parent then
			return
		end
		TweenService:Create(dof, TweenInfo.new(math.max(seconds, 0.01), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			FocusDistance = distance,
			InFocusRadius = radius,
			NearIntensity = near,
			FarIntensity = far,
		}):Play()
	end

	function rig.flash()
		task.spawn(function()
			for _, step in { { 0.34, 0.05 }, { 0.03, 0.1 }, { 0.5, 0.05 }, { 0, 0.8 } } do
				if not grade.Parent then
					return
				end
				TweenService:Create(grade, TweenInfo.new(step[2], Enum.EasingStyle.Quad), { Brightness = step[1] }):Play()
				task.wait(step[2])
			end
		end)
	end

	function rig.frame(cf: CFrame, fov: number, amount: number)
		local clock = os.clock()
		local shaken = cf * sway(clock, amount)
		camera.CFrame = shaken
		-- the lens breathes: a slow, tiny change of view, never enough to notice, always enough to feel
		camera.FieldOfView = fov + math.sin(clock * 0.45) * 0.5 * amount
		volume.CFrame = shaken * CFrame.new(0, 1.5, -24)
	end

	function rig.destroy()
		dof:Destroy()
		grade:Destroy()
		volume:Destroy()
	end

	return rig
end

return IntroCinema
