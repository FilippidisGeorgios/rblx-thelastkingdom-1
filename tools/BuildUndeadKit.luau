--[[
	BuildUndeadKit — run in the FORGOTTEN LANDS place, in EDIT MODE.

	The fine kit of the dead: heads, helmets, swords, spears, bows, arrows,
	shields, spades and armour, each SCULPTED from thousands of small cubes and
	then fused into a handful of solid pieces.

	HOW
	  A piece is described as a shape function (a signed distance field, plus a
	  colour rule): "is this point inside the blade, and what colour is the steel
	  here". The tool samples it on a fine grid (0.02-0.04 studs: a sword is
	  ~150 cubes long, ~12 across), so edges are bevelled, fullers are cut,
	  grips are wrapped, paint is chipped and rust is where rust would be.
	  Neighbouring cubes of one colour in a row are merged into one box, cubes
	  nobody can see (inside the solid) take whatever colour helps the merge, and
	  then every box of one MATERIAL is fused with UnionAsync into one
	  UnionOperation that keeps every cube's colour. A sword is ~1,500 cubes and
	  three parts in the game: steel, iron, leather.

	  Unions use RenderFidelity Automatic (the engine thins them with distance:
	  free LOD) and Box collision (they never collide anyway).

	WHERE
	  ServerStorage.Assets.UndeadKit.<piece>  — a Model per piece; its WorldPivot
	  is the piece's origin (a grip, the centre of a head, the centre of a shield's
	  arm strap), so tools/BuildUndead can place it and weld it to a bone.

	CONVENTIONS (each piece's own frame)
	  weapons  +X along the weapon from the grip; Y across the edge; Z through it
	  shields  X across, Y up, the face looks down -Z; origin at the arm
	  heads    X right, Y up, the face looks down -Z; origin at the head's centre
	  helmets  same as heads, origin at the head's centre

	Rerun safely: a piece is replaced. ONLY limits what is built.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local ONLY: { string }? = nil

-- "fine" : the sculpt, at 0.02-0.03 studs (hundreds of thousands of triangles a body)
-- "field": the same shapes at twice the voxel size (about a quarter of the triangles);
--          this is what the game spawns. Each goes to its own folder in Assets.
local QUALITY = "field"
local VSCALE = if QUALITY == "field" then 2 else 1
local STORE = if QUALITY == "field" then "UndeadKitField" else "UndeadKit"

--==========================================================================
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local V3 = Vector3.new
local Mat = Enum.Material
local abs, max, min, sqrt, floor, sin, cos, pi = math.abs, math.max, math.min, math.sqrt, math.floor, math.sin, math.cos, math.pi
local clamp = math.clamp

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, clamp(t, 0, 1))
end
local function shade(c: Color3, f: number): Color3
	return Color3.new(clamp(c.R * f, 0, 1), clamp(c.G * f, 0, 1), clamp(c.B * f, 0, 1))
end

-- Materials a union can be (one per union; colours are per cube).
local MAT = {
	steel = { Mat.Metal, nil },
	iron = { Mat.Metal, nil },
	rust = { Mat.CorrodedMetal, nil },
	leather = { Mat.Fabric, nil },
	cloth = { Mat.Fabric, nil },
	wood = { Mat.Wood, nil },
	paint = { Mat.SmoothPlastic, nil },
	skin = { Mat.Concrete, nil },
	bone = { Mat.SmoothPlastic, nil },
	dark = { Mat.SmoothPlastic, nil },
	hair = { Mat.SmoothPlastic, nil },
	feather = { Mat.SmoothPlastic, nil },
	mail = { Mat.Metal, nil },
	soil = { Mat.Ground, nil },
}

--==========================================================================
-- NOISE AND SHAPES
--==========================================================================
local function hash(x: number, y: number, z: number): number
	local n = sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
	return n - floor(n)
end

-- Smooth value noise in [0, 1].
local function noise(p: Vector3, scale: number): number
	local x, y, z = p.X / scale, p.Y / scale, p.Z / scale
	local xi, yi, zi = floor(x), floor(y), floor(z)
	local xf, yf, zf = x - xi, y - yi, z - zi
	local u, v, w = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf), zf * zf * (3 - 2 * zf)
	local function h(a, b, c)
		return hash(xi + a, yi + b, zi + c)
	end
	local x00 = h(0, 0, 0) + (h(1, 0, 0) - h(0, 0, 0)) * u
	local x10 = h(0, 1, 0) + (h(1, 1, 0) - h(0, 1, 0)) * u
	local x01 = h(0, 0, 1) + (h(1, 0, 1) - h(0, 0, 1)) * u
	local x11 = h(0, 1, 1) + (h(1, 1, 1) - h(0, 1, 1)) * u
	local y0 = x00 + (x10 - x00) * v
	local y1 = x01 + (x11 - x01) * v
	return y0 + (y1 - y0) * w
end

local function sdEllipsoid(p: Vector3, r: Vector3): number
	local k0 = (p / r).Magnitude
	local k1 = (p / (r * r)).Magnitude
	if k1 == 0 then
		return -min(r.X, r.Y, r.Z)
	end
	return k0 * (k0 - 1) / k1
end
local function sdSphere(p: Vector3, c: Vector3, r: number): number
	return (p - c).Magnitude - r
end
local function sdBox(p: Vector3, b: Vector3): number
	local qx, qy, qz = abs(p.X) - b.X, abs(p.Y) - b.Y, abs(p.Z) - b.Z
	return V3(max(qx, 0), max(qy, 0), max(qz, 0)).Magnitude + min(max(qx, qy, qz), 0)
end
local function sdCapsule(p: Vector3, a: Vector3, b: Vector3, r: number): number
	local pa, ba = p - a, b - a
	local t = clamp(pa:Dot(ba) / ba:Dot(ba), 0, 1)
	return (pa - ba * t).Magnitude - r
end
local function smin(a: number, b: number, k: number): number
	local h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end
local function smax(a: number, b: number, k: number): number
	return -smin(-a, -b, k)
end

--==========================================================================
-- THE SCULPTOR
--==========================================================================
type Sample = (p: Vector3) -> (string?, Color3?)

local function quant(c: Color3): number
	local r = floor(c.R * 255 / 5 + 0.5) * 5
	local g = floor(c.G * 255 / 5 + 0.5) * 5
	local b = floor(c.B * 255 / 5 + 0.5) * 5
	return clamp(r, 0, 255) * 65536 + clamp(g, 0, 255) * 256 + clamp(b, 0, 255)
end
local function unquant(n: number): Color3
	return Color3.fromRGB(floor(n / 65536), floor(n / 256) % 256, n % 256)
end

local stats = { cubes = 0, boxes = 0, unions = 0 }

--[[
	Samples `sample` over [lo, hi] at voxel size v and returns a Model of unions,
	one per material key, positioned in the piece's own frame (origin = 0,0,0).
]]
local function sculpt(name: string, lo: Vector3, hi: Vector3, v: number, sample: Sample, work: Instance): Model
	v = v * VSCALE
	local nx = floor((hi.X - lo.X) / v + 0.5)
	local ny = floor((hi.Y - lo.Y) / v + 0.5)
	local nz = floor((hi.Z - lo.Z) / v + 0.5)
	local keyAt: { [number]: string } = {}
	local colAt: { [number]: number } = {}
	local function idx(i, j, k)
		return (k * ny + j) * nx + i
	end
	for k = 0, nz - 1 do
		for j = 0, ny - 1 do
			for i = 0, nx - 1 do
				local p = V3(lo.X + (i + 0.5) * v, lo.Y + (j + 0.5) * v, lo.Z + (k + 0.5) * v)
				local key, col = sample(p)
				if key then
					local n = idx(i, j, k)
					keyAt[n] = key
					colAt[n] = quant(col or Color3.new(1, 0, 1))
				end
			end
		end
		if k % 8 == 0 then
			task.wait()
		end
	end

	local function solid(i, j, k)
		if i < 0 or j < 0 or k < 0 or i >= nx or j >= ny or k >= nz then
			return false
		end
		return keyAt[idx(i, j, k)] ~= nil
	end

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = work
	local groups: { [string]: { BasePart } } = {}

	local function emit(key: string, col: number, i0: number, i1: number, j: number, k: number)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = V3((i1 - i0 + 1) * v, v, v)
		p.CFrame = CFrame.new(lo.X + ((i0 + i1 + 1) / 2) * v, lo.Y + (j + 0.5) * v, lo.Z + (k + 0.5) * v)
		p.Color = unquant(col)
		p.Parent = model
		groups[key] = groups[key] or {}
		table.insert(groups[key], p)
		stats.boxes += 1
	end

	for k = 0, nz - 1 do
		for j = 0, ny - 1 do
			local runKey, runCol, runStart = nil, nil, 0
			local pendingHidden = -1 -- first hidden cube before a run has a colour
			for i = 0, nx do
				local n = idx(i, j, k)
				local key = if i < nx then keyAt[n] else nil
				local hidden = key ~= nil
					and solid(i - 1, j, k)
					and solid(i + 1, j, k)
					and solid(i, j - 1, k)
					and solid(i, j + 1, k)
					and solid(i, j, k - 1)
					and solid(i, j, k + 1)
				if key then
					stats.cubes += 1
				end
				local col = if key then colAt[n] else nil
				if runKey and key == runKey and (hidden or col == runCol) then
					-- extend
				else
					if runKey then
						emit(runKey, runCol :: number, runStart, i - 1, j, k)
						runKey = nil
					end
					if key then
						runKey, runCol, runStart = key, col, i
					end
				end
				pendingHidden = -1
			end
		end
		if k % 4 == 0 then
			task.wait()
		end
	end

	-- Fuse each material into as few unions as it takes (a union of more than
	-- ~900 boxes is split, so no single operation is slow).
	for key, parts in groups do
		local m = MAT[key] or MAT.paint
		local chunks = {}
		local CHUNK = 900
		for s = 1, #parts, CHUNK do
			table.insert(chunks, table.move(parts, s, min(s + CHUNK - 1, #parts), 1, {}))
		end
		for c, chunk in chunks do
			local result: BasePart
			if #chunk == 1 then
				result = chunk[1]
			else
				local first = table.remove(chunk, 1) :: BasePart
				local ok, u = pcall(function()
					return first:UnionAsync(chunk, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
				end)
				if not ok then
					warn("[UndeadKit] union failed for " .. name .. "/" .. key .. ": " .. tostring(u))
					continue
				end
				result = u :: BasePart
				first:Destroy()
				for _, p in chunk do
					p:Destroy()
				end
				;(result :: UnionOperation).UsePartColor = false
				stats.unions += 1
			end
			result.Name = key .. (if #chunks > 1 then tostring(c) else "")
			result.Material = m[1]
			if m[2] and MaterialService:FindFirstChild(m[2], true) then
				result.MaterialVariant = m[2]
			end
			result.Anchored = true
			result.CanCollide = false
			result.CanTouch = false
			result.CanQuery = false
			result.Massless = true
			result.CastShadow = result.Size.Magnitude > 1.2
			result:SetAttribute("Kit", key)
			result.Parent = model
		end
		task.wait()
	end
	model.WorldPivot = CFrame.new()
	return model
end

--==========================================================================
-- PALETTE
--==========================================================================
local P = {
	steel = rgb(150, 154, 158),
	steelEdge = rgb(196, 200, 204),
	steelDark = rgb(96, 100, 106),
	iron = rgb(84, 82, 82),
	rust = rgb(118, 70, 46),
	rustDark = rgb(78, 50, 38),
	leather = rgb(74, 50, 36),
	leatherDark = rgb(46, 32, 26),
	wood = rgb(104, 76, 52),
	woodDark = rgb(70, 50, 36),
	yewHeart = rgb(132, 72, 40),
	yewSap = rgb(206, 180, 136),
	horn = rgb(196, 186, 162),
	bordeaux = rgb(110, 34, 44),
	gold = rgb(176, 138, 58),
	linen = rgb(168, 156, 132),
	skin = rgb(104, 112, 116),
	skinDark = rgb(70, 76, 82),
	skinPale = rgb(138, 144, 144),
	vein = rgb(66, 58, 88),
	socket = rgb(18, 18, 22),
	bone = rgb(186, 176, 152),
	boneDark = rgb(138, 128, 106),
	hair = rgb(36, 32, 30),
	feather = rgb(160, 156, 150),
	featherDark = rgb(70, 66, 62),
	soil = rgb(66, 50, 38),
}

-- Steel that has been through forty years of weather: polished at the edge,
-- dull on the flat, rust where water stood.
local function steelAt(p: Vector3, edge: number): Color3
	local n = noise(p, 0.18)
	local fine = noise(p, 0.05)
	local c = mix(P.steelDark, P.steel, 0.4 + 0.6 * fine)
	c = mix(c, P.steelEdge, edge)
	if n > 0.66 then
		c = mix(c, P.rust, (n - 0.66) * 3.2)
	end
	return c
end

local function ironAt(p: Vector3): Color3
	local n = noise(p, 0.14)
	local c = mix(P.iron, shade(P.iron, 1.25), noise(p, 0.04))
	if n > 0.55 then
		c = mix(c, P.rust, (n - 0.55) * 2.2)
	end
	return c
end

local function woodAt(p: Vector3, base: Color3, grainAxis: string): Color3
	local g = if grainAxis == "X" then p.Y * 0.7 + p.Z else p.X * 0.7 + p.Z
	local band = sin(g * 70 + noise(p, 0.3) * 6) * 0.5 + 0.5
	return mix(shade(base, 0.82), shade(base, 1.12), band * 0.7 + noise(p, 0.06) * 0.3)
end

local function leatherAt(p: Vector3): Color3
	return mix(P.leatherDark, P.leather, noise(p, 0.05))
end

--==========================================================================
-- THE PIECES
--==========================================================================
local PIECES: { [string]: (work: Instance) -> Model } = {}

--[[
	ARMING SWORD. Grip at the origin, blade along +X.
	Blade 3.1 long, a diamond section with a fuller down two-thirds of it, nicks in
	the edge; a guard whose quillons curve toward the blade and swell at the ends;
	a grip wrapped in leather cord; a wheel pommel with a peened rivet.
]]
PIECES.sword_arming = function(work)
	local B0, B1 = 0.3, 3.4 -- blade start/end
	return sculpt("sword_arming", V3(-0.45, -0.5, -0.12), V3(3.45, 0.5, 0.12), 0.02, function(p)
		local x, y, z = p.X, p.Y, p.Z
		-- blade
		if x >= B0 and x <= B1 then
			local t = (x - B0) / (B1 - B0)
			local w = 0.125 - 0.075 * t
			local tip = clamp((B1 - x) / 0.5, 0, 1)
			w *= tip ^ 0.75
			if w > 0.005 and abs(y) <= w then
				local e = abs(y) / w
				local thick = 0.034 * (1 - 0.62 * e)
				local fuller = abs(y) < 0.026 and x > B0 + 0.05 and x < 2.35
				if fuller then
					thick = 0.017
				end
				-- a nick here and there in the edge
				if e > 0.82 and hash(floor(x * 9), 1, y > 0 and 1 or 2) > 0.9 then
					return nil
				end
				if abs(z) <= thick then
					local edge = clamp((e - 0.72) / 0.28, 0, 1)
					local c = steelAt(p, edge)
					if fuller then
						c = shade(c, 0.72)
					end
					return "steel", c
				end
			end
		end
		-- guard: quillons curving toward the blade, swelling at the tips
		local gy = clamp(abs(y) / 0.45, 0, 1)
		local gx = 0.26 + 0.07 * gy * gy
		local gr = 0.035 + 0.025 * gy ^ 4
		if abs(y) <= 0.47 and abs(x - gx) <= gr and abs(z) <= 0.05 + 0.02 * gy ^ 4 then
			return "iron", ironAt(p)
		end
		if sdSphere(p, V3(0.33, 0.47, 0), 0.055) <= 0 or sdSphere(p, V3(0.33, -0.47, 0), 0.055) <= 0 then
			return "iron", ironAt(p)
		end
		-- grip: leather cord wrapped in a spiral, ridged
		if x >= -0.22 and x <= 0.22 then
			local r = sqrt(y * y + z * z)
			local a = math.atan2(z, y)
			local wrap = (x * 26 + a / (2 * pi)) % 1
			local rr = 0.07 + (if wrap < 0.5 then 0.012 else 0)
			if r <= rr then
				return "leather", if wrap < 0.5 then leatherAt(p) else shade(P.leatherDark, 0.8)
			end
		end
		-- the tang shoulder (ferrules) either end of the grip
		if (abs(x - 0.235) <= 0.02 or abs(x + 0.235) <= 0.02) and sqrt(y * y + z * z) <= 0.085 then
			return "iron", ironAt(p)
		end
		-- wheel pommel, axis through Z, with the peened rivet
		local px = x + 0.34
		if abs(z) <= 0.05 and sqrt(px * px + y * y) <= 0.115 then
			return "iron", ironAt(p)
		end
		if sdSphere(p, V3(-0.34, 0, 0), 0.07) <= 0 and abs(z) <= 0.075 then
			return "iron", shade(ironAt(p), 1.2)
		end
		return nil
	end, work)
end

--[[
	SPEAR HEAD. The socket's mouth at the origin, the point along +X.
	A leaf blade with a raised midrib, a tapering socket with a ring at its mouth,
	two langets nailed down the shaft.
]]
PIECES.spear_head = function(work)
	return sculpt("spear_head", V3(-0.75, -0.24, -0.14), V3(1.95, 0.24, 0.14), 0.02, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local r = sqrt(y * y + z * z)
		if x >= 0 and x <= 0.5 then
			local rr = 0.105 - 0.045 * (x / 0.5)
			if r <= rr then
				local c = ironAt(p)
				if x < 0.05 or abs(x - 0.42) < 0.025 then
					c = shade(c, 1.25)
				end
				return "iron", c
			end
		end
		-- langets
		if x >= -0.7 and x < 0.02 and abs(abs(y) - 0.095) <= 0.013 and abs(z) <= 0.028 then
			return "iron", ironAt(p)
		end
		for _, rx in { -0.18, -0.55 } do
			if sdSphere(V3(x, abs(y), z), V3(rx, 0.112, 0), 0.026) <= 0 then
				return "iron", shade(ironAt(p), 1.3)
			end
		end
		-- the leaf
		if x > 0.45 and x <= 1.92 then
			local t = (x - 0.45) / 1.47
			local w = 0.2 * sin(pi * t ^ 0.62) ^ 0.85
			if w > 0.006 and abs(y) <= w then
				local e = abs(y) / w
				local thick = 0.046 * (1 - 0.76 * e)
				if abs(z) <= thick then
					if e > 0.85 and hash(floor(x * 11), 3, y > 0 and 1 or 2) > 0.88 then
						return nil
					end
					local edge = clamp((e - 0.7) / 0.3, 0, 1)
					local c = steelAt(p, edge)
					if abs(y) < 0.018 then
						c = shade(c, 1.12) -- the midrib catches the light
					end
					return "steel", c
				end
			end
		end
		return nil
	end, work)
end

--[[
	SPEAR SHAFT. 9.8 of ash from the butt (origin) along +X, a spike on the butt,
	a leather grip where the hands go, and binding rings.
]]
PIECES.spear_shaft = function(work)
	return sculpt("spear_shaft", V3(-0.3, -0.105, -0.105), V3(9.85, 0.105, 0.105), 0.035, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local r = sqrt(y * y + z * z)
		if x < 0 then
			if r <= 0.09 * (1 + x / 0.3) + 0.012 then
				return "iron", ironAt(p)
			end
			return nil
		end
		if x < 0.14 and r <= 0.098 then
			return "iron", ironAt(p)
		end
		if r <= 0.085 then
			-- leather wrap where the hands hold, binding rings either side
			if (x > 2.3 and x < 3.0) or (x > 5.6 and x < 6.4) then
				local a = math.atan2(z, y)
				local wrap = (x * 18 + a / (2 * pi)) % 1
				return "leather", if wrap < 0.55 then leatherAt(p) else shade(P.leatherDark, 0.75)
			end
			return "wood", woodAt(p, rgb(150, 116, 80), "X")
		end
		if r <= 0.1 and (abs(x - 2.25) < 0.04 or abs(x - 3.05) < 0.04 or abs(x - 5.55) < 0.04 or abs(x - 6.45) < 0.04) then
			return "iron", ironAt(p)
		end
		return nil
	end, work)
end

--[[
	LONGBOW. Grip at the origin, the stave along X (tip to tip 5.3), the limbs
	bending back toward the archer (+Z), the string straight between the nocks.
	Yew, two-tone: pale sapwood on the back, red heartwood on the belly.
]]
PIECES.bow_long = function(work)
	return sculpt("bow_long", V3(-2.7, -0.12, -0.1), V3(2.7, 0.12, 0.42), 0.02, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local ax = abs(x)
		local zc = 0.32 * (x / 2.6) ^ 2
		-- the string
		if ax <= 2.5 and abs(y) <= 0.012 and abs(z - 0.31) <= 0.012 then
			return "cloth", mix(P.linen, shade(P.linen, 0.8), noise(p, 0.1))
		end
		if ax > 2.66 then
			return nil
		end
		local wy = 0.07 - 0.036 * ax / 2.6
		local tz = 0.055 - 0.028 * ax / 2.6
		local dz = z - zc
		-- horn nocks
		if ax > 2.47 then
			local s = 1 - (ax - 2.47) / 0.19 * 0.6
			if (y / (wy * 1.25 * s)) ^ 2 + (dz / (tz * 1.3 * s)) ^ 2 <= 1 then
				if abs(dz - 0.0) < 0.012 and ax > 2.52 and ax < 2.56 then
					return nil -- the string groove
				end
				return "bone", mix(P.horn, shade(P.horn, 0.75), noise(p, 0.05))
			end
			return nil
		end
		-- grip: leather wrap and the arrow pass
		if ax < 0.3 then
			if (y / (wy + 0.02)) ^ 2 + (dz / (tz + 0.02)) ^ 2 <= 1 then
				local band = (x * 30) % 1
				return "leather", if band < 0.7 then leatherAt(p) else shade(P.leatherDark, 0.7)
			end
			return nil
		end
		if (y / wy) ^ 2 + (dz / tz) ^ 2 <= 1 then
			local base = if dz < -0.25 * tz then P.yewSap else P.yewHeart
			return "wood", woodAt(p, base, "X")
		end
		return nil
	end, work)
end

--[[
	ARROW. Nock at the origin, point along +X (2.8). Barred goose fletching with
	the cock feather dyed, crested bands, a barbed broadhead.
]]
PIECES.arrow = function(work)
	local vanes = { pi / 2, pi / 2 + 2 * pi / 3, pi / 2 + 4 * pi / 3 }
	return sculpt("arrow", V3(-0.02, -0.1, -0.1), V3(2.86, 0.1, 0.1), 0.016, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local r = sqrt(y * y + z * z)
		-- broadhead
		if x >= 2.5 and x <= 2.84 then
			if x < 2.57 and r <= 0.03 then
				return "steel", steelAt(p, 0)
			end
			local w
			if x < 2.6 then
				w = 0.085 -- the barbs
			else
				w = 0.085 * (1 - (x - 2.6) / 0.24)
			end
			if abs(z) <= 0.012 and abs(y) <= w and not (x < 2.6 and abs(y) < 0.05 and abs(y) > 0.03) then
				return "steel", steelAt(p, clamp(abs(y) / max(w, 0.01), 0, 1))
			end
		end
		-- the shaft, crested near the feathers
		if x >= 0 and x < 2.52 and r <= 0.024 then
			if x < 0.07 then
				return "bone", shade(P.horn, 0.8)
			end
			if (x > 0.58 and x < 0.62) or (x > 0.66 and x < 0.72) then
				return "paint", P.bordeaux
			end
			if x > 0.62 and x < 0.66 then
				return "paint", P.gold
			end
			return "wood", woodAt(p, rgb(176, 146, 104), "X")
		end
		-- fletching: three vanes
		if x > 0.09 and x < 0.55 then
			local h = 0.08 * sin(pi * (x - 0.09) / 0.46) ^ 0.55
			for k, a in vanes do
				local dy, dz = cos(a), sin(a)
				local along = dy * y + dz * z
				local across = -dz * y + dy * z
				if abs(across) <= 0.009 and along >= 0.018 and along <= 0.02 + h then
					local barred = floor(x * 38) % 3 == 0
					local c = if k == 1 then P.bordeaux else P.feather
					if barred then
						c = shade(c, 0.55)
					end
					return "feather", mix(c, shade(c, 0.85), noise(p, 0.03))
				end
			end
		end
		return nil
	end, work)
end

--[[
	KITE SHIELD. Its face looks down -Z; the origin is the arm, behind the boss.
	Linen over planks, painted bordeaux with the falling star in gold; the paint
	chipped to the wood; an iron rim with rivets; a boss; a split through it and a
	bite out of the edge; on the back, the planks and the arm straps.
]]
PIECES.shield_kite = function(work)
	local function ytop(x)
		return 1.12 - 0.22 * (x / 0.85) ^ 2
	end
	local function hw(y)
		if y >= 0.25 then
			return 0.85
		end
		return 0.85 * clamp((y + 1.78) / 2.03, 0, 1) ^ 0.8
	end
	local rivets = {}
	for i = -3, 3 do
		local x = i * 0.25
		table.insert(rivets, V3(x, ytop(x) - 0.035, 0))
	end
	for y = 0.9, -1.55, -0.24 do
		local w = hw(y) - 0.035
		table.insert(rivets, V3(w, y, 0))
		table.insert(rivets, V3(-w, y, 0))
	end
	local starC = V3(0, 0.3, 0)
	local tailDir = V3(-0.45, -0.89, 0).Unit
	local m = sculpt("shield_kite", V3(-0.93, -1.84, -0.24), V3(0.93, 1.2, 0.34), 0.028, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local top = ytop(x)
		local half = hw(y)
		if y > top + 0.02 or abs(x) > half + 0.02 or y < -1.8 then
			return nil
		end
		-- the split and the bite
		local sx, sy = 0.35 + (y - 1.0) * 0.125, y
		if y < 1.05 and y > -0.7 and abs(x - sx) < 0.014 + 0.006 * sin(y * 30) then
			return nil
		end
		if sdSphere(V3(x, y, 0), V3(0.83, -0.25, 0), 0.17) <= 0 then
			return nil
		end
		local zf = -0.06 + 0.14 * (x / 0.85) ^ 2
		local dz = z - zf
		local edge = min(half - abs(x), top - y)
		-- the boss
		if sdSphere(p, V3(0, 0.3, zf + 0.06), 0.15) <= 0 and dz < 0 then
			return "iron", ironAt(p)
		end
		-- rim rivets
		if edge < 0.08 and dz < 0 and dz > -0.06 then
			for _, rv in rivets do
				local dx, dy = x - rv.X, y - rv.Y
				if dx * dx + dy * dy < 0.028 * 0.028 then
					return "iron", shade(ironAt(p), 1.3)
				end
			end
		end
		-- iron rim wrapping the edge
		if edge < 0.055 and edge > -0.02 and dz >= -0.035 and dz <= 0.115 then
			return "iron", ironAt(p)
		end
		if edge < 0 then
			return nil
		end
		-- the painted face
		if dz >= -0.034 and dz < 0 then
			local q = V3(x, y, 0) - starC
			local rr = q.Magnitude
			local th = math.atan2(q.Y, q.X)
			local rStar = 0.56 * (0.3 + 0.7 * abs(cos(4 * th)) ^ 3)
			local inStar = rr <= rStar
			local t = q:Dot(tailDir)
			local perp = (q - tailDir * t).Magnitude
			local inTail = t > 0.25 and t < 1.35 and perp < 0.11 * (1 - (t - 0.25) / 1.1)
			local chip = noise(p, 0.08) > 0.78 or hash(floor(x * 40), floor(y * 40), 5) > 0.992
			if chip then
				return "paint", mix(rgb(150, 124, 92), rgb(120, 96, 70), noise(p, 0.03))
			end
			if inStar or inTail then
				return "paint", mix(rgb(196, 152, 58), rgb(150, 112, 44), noise(p, 0.06))
			end
			local c = mix(P.bordeaux, shade(P.bordeaux, 0.7), noise(p, 0.12))
			c = mix(c, rgb(50, 36, 30), clamp((-y - 0.8) * 0.6, 0, 0.6)) -- mud at the foot
			return "paint", c
		end
		-- the planks
		if dz >= 0 and dz <= 0.09 then
			local plank = floor((x + 0.93) / 0.2)
			local f = (x + 0.93) / 0.2 - plank
			if dz > 0.07 and (f < 0.06 or f > 0.94) then
				return "wood", shade(P.woodDark, 0.6)
			end
			local base = shade(P.wood, 0.85 + hash(plank, 7, 7) * 0.3)
			return "wood", woodAt(p, base, "Y")
		end
		-- arm straps on the back
		if dz > 0.09 and dz <= 0.13 and abs(x) < 0.36 and ((y > 0.12 and y < 0.24) or (y > 0.46 and y < 0.58)) then
			return "leather", leatherAt(p)
		end
		return nil
	end, work)
	m.WorldPivot = CFrame.new(0, 0.35, 0.16)
	return m
end

--[[
	GRAVE-SPADE. The T-grip at the origin, the shaft along +X, the blade at the
	far end: rounded corners, a rolled tread, a socket strapped to the shaft, rust
	and caked soil.
]]
PIECES.spade = function(work)
	return sculpt("spade", V3(-0.05, -0.46, -0.13), V3(4.95, 0.46, 0.13), 0.026, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local r = sqrt(y * y + z * z)
		-- T-grip
		if x <= 0.12 and abs(y) <= 0.3 and sqrt((x - 0.06) ^ 2 + z * z) <= 0.06 then
			return "wood", woodAt(p, P.woodDark, "Y")
		end
		-- shaft
		if x > 0.08 and x < 3.4 and r <= 0.075 then
			return "wood", woodAt(p, P.wood, "X")
		end
		-- socket and straps
		if x >= 3.3 and x < 3.78 and r <= 0.1 - 0.03 * (x - 3.3) / 0.48 then
			return "iron", ironAt(p)
		end
		if x >= 2.9 and x < 3.35 and abs(abs(y) - 0.08) < 0.014 and abs(z) < 0.035 then
			return "iron", ironAt(p)
		end
		-- the blade
		if x >= 3.72 and x <= 4.92 then
			local corner = 0.16
			local inside = abs(y) <= 0.42
			if x > 4.92 - corner and abs(y) > 0.42 - corner then
				local cx, cy = x - (4.92 - corner), abs(y) - (0.42 - corner)
				inside = cx * cx + cy * cy <= corner * corner
			end
			if inside then
				local zc = 0.035 * (y / 0.42) ^ 2
				local tread = x < 3.8
				if abs(z - zc) <= (if tread then 0.05 else 0.022) then
					if x > 4.2 and noise(p, 0.09) > 0.42 + (4.92 - x) * 0.12 then
						return "soil", mix(P.soil, shade(P.soil, 0.7), noise(p, 0.03))
					end
					local c = ironAt(p)
					if abs(y) > 0.38 or x > 4.85 then
						c = mix(c, P.steel, 0.5) -- worn bright at the cutting edge
					end
					return "iron", c
				end
			end
		end
		return nil
	end, work)
end

--[[
	KETTLE HAT (head frame). A dome with a comb, a broad sloping brim with a rolled
	edge, a ring of rivets where the brim is joined.
]]
PIECES.helm_kettle = function(work)
	local dome = V3(0.47, 0.42, 0.49)
	local base = 0.2
	return sculpt("helm_kettle", V3(-0.88, 0.0, -0.88), V3(0.88, 0.66, 0.88), 0.024, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local q = p - V3(0, base, 0)
		if y >= base - 0.005 then
			local e = sdEllipsoid(q, dome)
			-- rivets round the base
			if y < base + 0.08 then
				local a = math.atan2(z, x)
				local k = floor(a / (2 * pi) * 15 + 0.5)
				local ra = k / 15 * 2 * pi
				if sdSphere(p, V3(0.475 * cos(ra), base + 0.045, 0.495 * sin(ra)), 0.026) <= 0 then
					return "iron", shade(ironAt(p), 1.35)
				end
			end
			if e <= 0 and e >= -0.04 then
				return "iron", ironAt(p)
			end
			if abs(x) < 0.022 and e > 0 and e < 0.026 and y > base + 0.06 then
				return "iron", shade(ironAt(p), 1.15)
			end
		end
		local rr = sqrt(x * x + z * z)
		if rr >= 0.44 and rr <= 0.85 then
			local by = base - 0.17 * ((rr - 0.44) / 0.41) ^ 1.2
			local th = if rr > 0.81 then 0.034 else 0.02
			if abs(y - by) <= th then
				return "iron", ironAt(p)
			end
		end
		return nil
	end, work)
end

--[[
	NASAL HELM (head frame). A tall spangenhelm: four riveted bands up a conical
	bowl, a brow band, a nasal down over the face.
]]
PIECES.helm_nasal = function(work)
	local B, T = 0.12, 0.8
	return sculpt("helm_nasal", V3(-0.56, -0.27, -0.6), V3(0.56, 0.82, 0.58), 0.022, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local zz = z / 1.04
		local rr = sqrt(x * x + zz * zz)
		-- nasal
		if abs(x) <= 0.04 + (if y < -0.15 then 0.012 else 0) and y > -0.25 and y < B + 0.06 and z < -0.47 and z > -0.535 then
			return "steel", steelAt(p, 0.2)
		end
		if y >= B and y <= T then
			local R = 0.5 * max(0, 1 - ((y - B) / (T - B)) ^ 1.8) ^ 0.5
			local band = abs(x) < 0.034 or abs(z) < 0.034
			local brow = y < B + 0.1
			local outer = R + (if band or brow then 0.016 else 0)
			if rr <= outer and rr >= R - 0.035 then
				if band or brow then
					local c = ironAt(p)
					local s = if brow then (math.atan2(zz, x) * 4) % 1 else (y * 9) % 1
					if s < 0.12 then
						c = shade(c, 1.4) -- a rivet
					end
					return "iron", c
				end
				return "steel", steelAt(p, 0.15)
			end
		end
		return nil
	end, work)
end

-- Mail: the rings, as alternating bright and dark cubes in staggered rows.
local function mailAt(p: Vector3, v: number): Color3
	local i, j, k = floor(p.X / v), floor(p.Y / v), floor(p.Z / v)
	local ring = (j % 2 == 0) ~= (hash(i, j, k) > 0.86) -- rows of rings, a few out of place
	local c = if ring then rgb(122, 124, 128) else rgb(52, 54, 58)
	local n = noise(p, 0.15)
	if n > 0.62 then
		c = mix(c, P.rust, (n - 0.62) * 2)
	end
	return c
end

--[[
	MAIL COIF (head frame). A hood of mail with the face open, falling to a cape
	over the shoulders.
]]
PIECES.coif_mail = function(work)
	local v = 0.028 * VSCALE
	return sculpt("coif_mail", V3(-1.02, -1.02, -0.72), V3(1.02, 0.66, 0.62), v / VSCALE, function(p)
		local x, y, z = p.X, p.Y, p.Z
		if z < -0.16 and abs(x) < 0.29 and y > -0.38 and y < 0.24 then
			return nil
		end
		if y > -0.42 then
			local e = sdEllipsoid(p - V3(0, 0.07, 0.03), V3(0.5, 0.57, 0.53))
			if e <= 0 and e >= -0.045 then
				return "iron", mailAt(p, v)
			end
			return nil
		end
		if y >= -1.0 then
			local t = (-0.42 - y) / 0.58
			local rc = 0.4 + 0.58 * t ^ 1.3
			local d = sqrt(x * x + (z / 0.66) ^ 2)
			if d <= rc and d >= rc - 0.05 then
				-- a ragged hem
				if y < -0.9 and hash(floor(x * 14), floor(z * 14), 9) > 0.5 then
					return nil
				end
				return "iron", mailAt(p, v)
			end
		end
		return nil
	end, work)
end

--[[
	BRIGANDINE (UpperTorso frame, base size 1.8 x 1.55 x 0.85). Cloth over small
	plates: rows of brass rivet heads, each row a plate's lip.
]]
PIECES.torso_brigandine = function(work)
	return sculpt("torso_brigandine", V3(-1.0, -0.86, -0.53), V3(1.0, 0.86, 0.53), 0.026, function(p)
		local d = sdBox(p, V3(0.9, 0.78, 0.44)) - 0.05
		if d > 0 or d < -0.06 then
			-- rivet heads stand proud of the cloth
			if d > 0 and d < 0.025 then
				local row = floor((p.Y + 0.8) / 0.155)
				local ry = -0.8 + (row + 0.62) * 0.155
				local cx = (p.X + (if row % 2 == 0 then 0 else 0.055)) / 0.11
				local f = cx - floor(cx)
				local fz = (p.Z / 0.11) - floor(p.Z / 0.11)
				local onFace = abs(p.Z) > 0.46 and (f < 0.28 or f > 0.72)
				local onSide = abs(p.X) > 0.92 and (fz < 0.28 or fz > 0.72)
				if abs(p.Y - ry) < 0.022 and (onFace or onSide) then
					return "iron", mix(P.gold, shade(P.gold, 0.6), noise(p, 0.05))
				end
			end
			return nil
		end
		local row = (p.Y + 0.8) / 0.155
		local within = row - floor(row)
		local c = mix(rgb(60, 72, 90), rgb(40, 48, 62), within) -- each plate shades toward its lower lip
		c = mix(c, shade(c, 0.7), noise(p, 0.1))
		return "cloth", c
	end, work)
end

--[[
	HAUBERK (UpperTorso frame). Mail over the whole trunk.
]]
PIECES.torso_hauberk = function(work)
	local v = 0.026 * VSCALE
	return sculpt("torso_hauberk", V3(-1.0, -0.86, -0.53), V3(1.0, 0.86, 0.53), v / VSCALE, function(p)
		local d = sdBox(p, V3(0.9, 0.78, 0.44)) - 0.05
		if d <= 0 and d >= -0.05 then
			return "iron", mailAt(p, v)
		end
		return nil
	end, work)
end

--[[
	PAULDRON (right; the left is the mirror). Origin at the shoulder joint.
	A domed cop and two lames below it, each riveted front and back, with a
	rolled edge.
]]
local function pauldron(name: string, side: number)
	return function(work)
		return sculpt(name, V3(-0.55, -0.48, -0.55), V3(0.55, 0.4, 0.55), 0.022, function(p0)
			local p = V3(p0.X * side, p0.Y, p0.Z)
			local x, y, z = p.X, p.Y, p.Z
			-- the cop: an ellipsoid shell, the upper half, leaning out
			local e = sdEllipsoid(p - V3(0.06, 0.02, 0), V3(0.42, 0.32, 0.45))
			if y >= -0.04 and e <= 0 and e >= -0.035 then
				local c = steelAt(p, 0.1)
				if y < 0.01 then
					c = shade(c, 1.2)
				end
				return "steel", c
			end
			-- two lames, each a band round the outside of the arm
			for i, ly in { -0.13, -0.28 } do
				local rr = sqrt((x - 0.02) ^ 2 + z * z)
				local R = 0.44 - i * 0.03
				if abs(y - ly) < 0.065 and rr <= R and rr >= R - 0.032 and x > -0.12 then
					local c = steelAt(p, 0.1)
					if abs(y - ly) > 0.048 then
						c = shade(c, 1.25) -- the rolled edge
					end
					if abs(abs(z) - 0.32) < 0.035 and abs(y - ly) < 0.026 then
						c = shade(ironAt(p), 1.4) -- rivets
					end
					return "steel", c
				end
			end
			return nil
		end, work)
	end
end
PIECES.pauldron_r = pauldron("pauldron_r", 1)
PIECES.pauldron_l = pauldron("pauldron_l", -1)

--[[
	VAMBRACE / GREAVE (limb frame, Y along the limb). A shell of steel with a ridge
	down the outside, held on by two leather straps with buckles.
]]
local function limbPlate(name: string, R: number, L: number)
	return function(work)
		return sculpt(name, V3(-R - 0.06, -L / 2 - 0.02, -R - 0.06), V3(R + 0.06, L / 2 + 0.02, R + 0.06), 0.02, function(p)
			local x, y, z = p.X, p.Y, p.Z
			local rr = sqrt(x * x + z * z)
			if abs(y) > L / 2 then
				return nil
			end
			-- straps go all the way round
			for _, sy in { -L * 0.3, L * 0.3 } do
				if abs(y - sy) < 0.04 and rr <= R + 0.02 and rr >= R - 0.01 then
					if z > R * 0.6 and abs(x) < 0.05 then
						return "iron", shade(ironAt(p), 1.3) -- the buckle
					end
					return "leather", leatherAt(p)
				end
			end
			-- the plate covers the front and the outside, open behind
			if z > R * 0.55 then
				return nil
			end
			local ridge = abs(x) < 0.03 and z < 0
			local outer = R + (if ridge then 0.02 else 0)
			if rr <= outer and rr >= R - 0.03 then
				local c = steelAt(p, if ridge then 0.5 else 0.1)
				if abs(abs(y) - L / 2) < 0.025 then
					c = shade(c, 1.2) -- turned edge
				end
				return "steel", c
			end
			return nil
		end, work)
	end
end
PIECES.vambrace = limbPlate("vambrace", 0.27, 0.72)
PIECES.greave = limbPlate("greave", 0.31, 0.86)

--[[
	QUIVER (its own frame, Y up). A leather tube with stitched seams, a stiff rim,
	a strap ring.
]]
PIECES.quiver = function(work)
	return sculpt("quiver", V3(-0.24, -0.82, -0.24), V3(0.24, 0.82, 0.24), 0.022, function(p)
		local x, y, z = p.X, p.Y, p.Z
		local rr = sqrt(x * x + z * z)
		local R = 0.19 + 0.025 * (y + 0.8) / 1.6
		if y > 0.8 or y < -0.8 then
			return nil
		end
		if y > 0.7 and rr <= R + 0.02 and rr >= R - 0.03 then
			return "leather", shade(P.leatherDark, 0.8)
		end
		if rr <= R and (rr >= R - 0.03 or y < -0.76) then
			local seam = abs(x) < 0.015 and z > 0
			if seam and (y * 24) % 1 < 0.5 then
				return "leather", shade(P.linen, 0.6)
			end
			return "leather", leatherAt(p)
		end
		return nil
	end, work)
end

--==========================================================================
-- HEADS
--==========================================================================
type HeadOpts = {
	brow: number?, -- brow ridge radius
	jaw: number?, -- how far the mouth gapes
	torn: boolean?, -- right cheek torn open to the teeth
	skull: boolean?, -- a patch of bare skull on the crown
	hair: string?, -- "none" | "wisps" | "long"
	stubble: boolean?,
	noNose: boolean?,
	gaunt: number?, -- how deep the cheeks are sunk
	seed: number?,
}

local function head(name: string, o: HeadOpts)
	return function(work)
		local brow = o.brow or 0.045
		local gape = o.jaw or 0.05
		local gaunt = o.gaunt or 0.06
		local seed = o.seed or 1
		local lipY = -0.27 -- where the lips meet when the mouth is shut
		local topGap, botGap = lipY + gape * 0.35, lipY - gape * 0.65
		local EYE = V3(0.135, 0.025, -0.335)
		return sculpt(name, V3(-0.5, -0.58, -0.56), V3(0.5, 0.6, 0.56), 0.022, function(p)
			local x, y, z = p.X, p.Y, p.Z
			local ax = abs(x)
			local pm = V3(ax, y, z)

			-- the eyes: clouded, sunk in the socket under a heavy lid
			local eyeD = (pm - EYE).Magnitude
			if eyeD <= 0.05 then
				local lid = y > EYE.Y + 0.012 - (if o.torn and x > 0 then 0.02 else 0)
				if not lid then
					return "bone", mix(rgb(176, 184, 182), rgb(120, 130, 134), noise(p, 0.02))
				end
			end

			-- teeth, behind the lips, in the gap
			if ax < 0.105 and z < -0.36 and z > -0.43 then
				local idx = floor((x + 0.105) / 0.03)
				local f = (x + 0.105) / 0.03 - idx
				local yellow = mix(rgb(170, 154, 116), rgb(112, 98, 72), hash(idx, seed, 6))
				if f > 0.12 and hash(idx, seed, 3) < 0.82 and y <= topGap + 0.01 and y >= topGap - 0.02 - 0.015 * hash(idx, seed, 4) then
					return "bone", yellow
				end
				if f > 0.12 and hash(idx, seed, 7) < 0.78 and y >= botGap - 0.01 and y <= botGap + 0.018 + 0.01 * hash(idx, seed, 5) then
					return "bone", shade(yellow, 0.9)
				end
			end

			-- the head: cranium, face, jaw, chin, cheekbones, brow, nose, lips, ears
			local d = sdEllipsoid(p - V3(0, 0.1, 0.05), V3(0.37, 0.42, 0.44))
			d = smin(d, sdEllipsoid(p - V3(0, -0.08, -0.12), V3(0.3, 0.38, 0.34)), 0.1)
			d = smin(d, sdBox(p - V3(0, -0.34, -0.12), V3(0.19, 0.08, 0.2)) - 0.06, 0.1)
			d = smin(d, sdSphere(p, V3(0, -0.42, -0.29), 0.075), 0.06)
			d = smin(d, sdEllipsoid(pm - V3(0.21, -0.03, -0.29), V3(0.09, 0.05, 0.09)), 0.04)
			d = smin(d, sdCapsule(p, V3(-0.2, 0.1, -0.345), V3(0.2, 0.1, -0.345), brow), 0.05)
			d = smin(d, sdCapsule(p, V3(0, 0.07, -0.39), V3(0, -0.12, -0.46), 0.032), 0.025)
			if not o.noNose then
				d = smin(d, sdSphere(p, V3(0, -0.13, -0.465), 0.045), 0.02)
				d = smin(d, sdSphere(pm, V3(0.042, -0.155, -0.43), 0.033), 0.02)
			end
			d = smin(d, sdCapsule(p, V3(-0.1, topGap + 0.02, -0.425), V3(0.1, topGap + 0.02, -0.425), 0.026), 0.02)
			d = smin(d, sdCapsule(p, V3(-0.09, botGap - 0.022, -0.415), V3(0.09, botGap - 0.022, -0.415), 0.027), 0.02)
			d = smin(d, sdEllipsoid(pm - V3(0.37, 0.0, 0.04), V3(0.045, 0.11, 0.07)), 0.03)
			-- taken away: the orbits, the mouth, the hollows of the cheeks
			d = smax(d, -sdEllipsoid(pm - V3(0.135, 0.03, -0.37), V3(0.075, 0.055, 0.07)), 0.025)
			local mouth = sdBox(p - V3(0, (topGap + botGap) / 2, -0.45), V3(0.095, (topGap - botGap) / 2, 0.09))
			d = smax(d, -mouth, 0.012)
			d = smax(d, -sdSphere(pm, V3(0.205, -0.18, -0.44), 0.06 + gaunt), 0.08)
			if o.noNose then
				d = smax(d, -sdSphere(p, V3(0, -0.11, -0.46), 0.05), 0.02)
			end
			if o.torn then
				d = smax(d, -sdBox(p - V3(0.17, -0.25, -0.36), V3(0.07, 0.06, 0.12)), 0.02)
			end
			d = smin(d, eyeD - 0.05, 0.005) -- the eyeballs sit in the orbits

			-- hair
			if o.hair and o.hair ~= "none" and d > 0 and d < 0.03 and y > 0.08 and z > -0.25 then
				local n = noise(p * V3(1, 0.35, 1), 0.045)
				if (o.hair == "long" and n > 0.36) or (o.hair == "wisps" and n > 0.6) then
					return "hair", mix(P.hair, shade(P.hair, 1.7), noise(p, 0.02))
				end
			end
			if o.hair == "long" and z > 0.05 and y < 0.12 and y > -0.7 then
				local r2 = sqrt(x * x + (z - 0.05) ^ 2)
				if r2 > 0.33 and r2 < 0.4 and hash(floor(x * 28), seed, 11) > 0.45 and hash(floor(x * 28), seed, 12) * 0.5 - 0.65 < y then
					return "hair", mix(P.hair, shade(P.hair, 1.5), noise(p, 0.03))
				end
			end
			if d > 0 then
				return nil
			end

			-- colour: grey-green, mottled, darker in every hollow
			local c = mix(rgb(96, 104, 102), rgb(118, 124, 118), noise(p, 0.14))
			c = mix(c, rgb(70, 80, 72), clamp((noise(p + V3(seed * 3, 0, 0), 0.09) - 0.45) * 2.2, 0, 0.7))
			local ds = (pm - V3(0.135, 0.03, -0.37)).Magnitude
			if ds < 0.15 then
				c = mix(c, rgb(46, 44, 54), (0.15 - ds) / 0.07) -- dark round the eyes
			end
			if mouth < 0.035 then
				c = mix(c, rgb(66, 46, 56), 0.8) -- lips, bloodless
			end
			if mouth < 0.004 then
				c = rgb(56, 30, 34) -- gums
			end
			local nostril = min((pm - V3(0.03, -0.165, -0.46)).Magnitude, 1)
			if nostril < 0.025 then
				c = P.socket
			end
			if (p - V3(0, -0.13, -0.5)).Magnitude < 0.05 then
				c = mix(c, rgb(60, 52, 58), 0.6) -- the nose's tip, going
			end
			if ax > 0.22 and y > -0.05 and abs(noise(p, 0.055) - 0.5) < 0.025 then
				c = P.vein
			end
			if o.stubble and y < -0.2 and z < 0.0 and hash(floor(x * 70), floor(y * 70), floor(z * 70)) > 0.55 then
				c = shade(c, 0.62)
			end
			if o.skull and y > 0.25 and x < 0.02 and noise(p, 0.09) > 0.5 then
				return "bone", if noise(p, 0.09) > 0.55 then mix(P.bone, P.boneDark, noise(p, 0.04)) else rgb(64, 40, 46)
			end
			if o.torn and (p - V3(0.17, -0.25, -0.36)).Magnitude < 0.16 then
				c = mix(rgb(72, 40, 48), rgb(44, 28, 34), noise(p, 0.03))
			end
			return "skin", c
		end, work)
	end
end

PIECES.head_gaunt = head("head_gaunt", { brow = 0.045, jaw = 0.05, gaunt = 0.06, hair = "wisps", seed = 2 })
PIECES.head_heavy = head("head_heavy", { brow = 0.06, jaw = 0.035, gaunt = 0.03, stubble = true, hair = "none", seed = 3 })
PIECES.head_torn = head("head_torn", { brow = 0.042, jaw = 0.07, gaunt = 0.07, torn = true, skull = true, hair = "wisps", noNose = true, seed = 4 })
PIECES.head_old = head("head_old", { brow = 0.05, jaw = 0.06, gaunt = 0.07, hair = "long", seed = 5 })

--==========================================================================
local work = Instance.new("Folder")
work.Name = "UndeadKitWork"
work.Parent = Workspace

local assets = ServerStorage:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ServerStorage
local store = assets:FindFirstChild(STORE) or Instance.new("Folder")
store.Name = STORE
store.Parent = assets

local built = {}
for name, make in PIECES do
	if not ONLY or table.find(ONLY, name) then
		local old = store:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local t0 = os.clock()
		local m = make(work)
		m.Parent = store
		table.insert(built, ("%s %.1fs"):format(name, os.clock() - t0))
	end
end
work:Destroy()

print(("[UndeadKit] %d cubes -> %d boxes -> %d unions | %s"):format(stats.cubes, stats.boxes, stats.unions, table.concat(built, ", ")))
return stats
