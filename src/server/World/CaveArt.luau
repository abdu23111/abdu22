-- Set dressing for every region: turns the carved terrain corridors into designed caves.
--
-- The Builder carves the playable space from the ASCII map; CaveArt reads the same map and
-- dresses it without changing where anything can stand:
--   * shape: rock buttresses and ceiling ribs in the terrain, rocks where floor meets wall,
--     trims along the base of every wall, rocky lips on platform edges;
--   * walls: layered ledges, cracks, fossils, glowing fungus, crystal veins, carved panels;
--   * ceilings: stalactites, roots, vines, chains, hanging lanterns and banners;
--   * floors: each region's props (columns, statues, giant mushrooms, crystals, shelves...),
--     ground cover, and light pools every few metres so the caves are readable;
--   * set pieces: arches and timber frames over the path, rope bridges and mushroom caps on
--     floating platforms, signposts at every doorway, and windows in the cave wall that look
--     out over distant scenery.
--
-- Rules that keep it playable: big props sit in the band along each wall (the middle of
-- the path stays clear), anything that looks solid enough to bump into and sits near a wall
-- is collidable, everything else is non-colliding and ignored by raycasts, nothing is placed
-- on hazards or near doors, benches, NPCs, switches, gates and items, and boss arenas only
-- get non-colliding dressing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Zones = require(Shared.Zones)

local T = Config.TILE
local WALL = Config.WALL_THICKNESS

local CaveArt = {}
CaveArt.debug = false

local terrain = workspace.Terrain
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local HALF_PI = math.pi / 2

-- ===========================================================================
-- Part helpers
-- ===========================================================================

local parent: Instance -- current output folder (set per zone)
local rng: Random
local partCount = 0

local function part(className: string, props: { [string]: any }, collide: boolean?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	if not props.Parent then
		p.Parent = parent
	end
	partCount += 1
	return p
end

local function block(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return part("Part", { CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic }, collide)
end

local function wedge(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return part("WedgePart", { CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

-- A stretched sphere (ellipsoid). Always non-colliding: its collision box wouldn't match.
local function ellipsoid(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = part("Part", { CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function ball(pos: Vector3, d: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * d, Position = pos, Color = color, Material = material or Enum.Material.SmoothPlastic }, collide)
end

-- A cylinder from a to b.
local function rod(a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart?
	local len = (b - a).Magnitude
	if len < 0.05 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, HALF_PI, 0)
	return part("Part", { Shape = Enum.PartType.Cylinder, CFrame = cf, Size = Vector3.new(len, d, d), Color = color, Material = material or Enum.Material.SmoothPlastic }, collide)
end

-- A square beam from a to b.
local function beam(a: Vector3, b: Vector3, w: number, h: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart?
	local len = (b - a).Magnitude
	if len < 0.05 then
		return nil
	end
	return block(CFrame.lookAt((a + b) / 2, b), Vector3.new(w, h, len), color, material, collide)
end

local function light(host: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = host
end

local function motes(host: BasePart, color: Color3, rate: number, size: number?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 0.22)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(2.5, 5)
	e.Rate = rate
	e.Speed = NumberRange.new(0.3, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 0.5, 0)
	e.Parent = host
end

-- Small variations keep repeated props from looking stamped.
local function vary(c: Color3, amount: number?): Color3
	local a = amount or 0.08
	local h, s, v = c:ToHSV()
	return Color3.fromHSV((h + rng:NextNumber(-a, a) * 0.25) % 1, math.clamp(s + rng:NextNumber(-a, a), 0, 1), math.clamp(v + rng:NextNumber(-a, a), 0, 1))
end

local function pick<V>(list: { V }): V
	return list[rng:NextInteger(1, #list)]
end

-- A tapering spike (stalactite / stalagmite / thorn): stacked cylinders narrowing to a tip.
local function spike(base: Vector3, dir: Vector3, length: number, radius: number, color: Color3, material: Enum.Material?, tipColor: Color3?)
	local steps = 3
	local prev = base
	for i = 1, steps do
		local f = i / steps
		local p = base + dir * length * f
		local r = radius * (1 - (i - 1) / steps * 0.72)
		rod(prev, p, r * 2, color:Lerp(tipColor or color, f * 0.6), material)
		prev = p - dir * 0.15
	end
end

-- ===========================================================================
-- Generic props (coloured by the region's theme)
-- ===========================================================================

local theme: any

local function rockLump(pos: Vector3, size: Vector3, color: Color3?)
	ellipsoid(CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)), size, vary(color or theme.rock, 0.06), theme.material)
end

local function candle(pos: Vector3, h: number?, withLight: boolean?)
	local height = h or rng:NextNumber(0.5, 1.2)
	rod(pos, pos + Vector3.new(0, height, 0), 0.35, Color3.fromRGB(236, 228, 206))
	local flame = ellipsoid(CFrame.new(pos + Vector3.new(0, height + 0.25, 0)), Vector3.new(0.25, 0.5, 0.25), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	if withLight then
		light(flame, Color3.fromRGB(255, 190, 120), 14, 0.9)
	end
end

local function crystalCluster(base: Vector3, normal: Vector3, scale: number, color: Color3, withLight: boolean?)
	local up = normal.Unit
	local count = rng:NextInteger(4, 7)
	local brightest: BasePart? = nil
	for i = 1, count do
		local len = rng:NextNumber(1.4, 4.2) * scale * (if i == 1 then 1.3 else 1)
		local w = len * rng:NextNumber(0.22, 0.32)
		local tilt = CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.6, 0.6))
		local basis = CFrame.lookAt(base, base + up) * CFrame.Angles(-HALF_PI, 0, 0) * tilt
		local cf = basis * CFrame.new(0, len / 2 - w * 0.4, 0) * CFrame.Angles(0, math.rad(45), 0)
		local c = vary(color, 0.05)
		block(cf, Vector3.new(w, len, w), c, Enum.Material.Glass).Transparency = 0.2
		local core = block(cf, Vector3.new(w * 0.45, len * 0.85, w * 0.45), c:Lerp(WHITE, 0.35), Enum.Material.Neon)
		core.Transparency = 0.15
		brightest = brightest or core
	end
	if withLight and brightest then
		light(brightest, color, 18 * math.max(1, scale * 0.8), 1.4)
		motes(brightest, color:Lerp(WHITE, 0.4), 1.5)
	end
end

local function mushroom(floor: Vector3, height: number, capColor: Color3, glowColor: Color3, withLight: boolean, collide: boolean?)
	local lean = Vector3.new(rng:NextNumber(-0.12, 0.12), 1, rng:NextNumber(-0.12, 0.12)).Unit
	local stemD = math.max(0.35, height * 0.13)
	local mid = floor + lean * height * 0.55 + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, 0)
	local top = floor + lean * height
	local stemColor = Color3.fromRGB(226, 226, 214):Lerp(capColor, 0.15)
	rod(floor, mid, stemD * 1.15, stemColor, Enum.Material.SmoothPlastic, collide)
	rod(mid, top, stemD, stemColor, Enum.Material.SmoothPlastic, collide)
	local capD = height * rng:NextNumber(0.75, 1.0)
	local capH = capD * 0.34
	local cap = ellipsoid(CFrame.new(top + Vector3.new(0, capH * 0.25, 0)), Vector3.new(capD, capH, capD), vary(capColor, 0.05), Enum.Material.SmoothPlastic)
	local gills = ellipsoid(CFrame.new(top - Vector3.new(0, capH * 0.05, 0)), Vector3.new(capD * 0.9, capH * 0.35, capD * 0.9), glowColor, Enum.Material.Neon)
	gills.Transparency = 0.1
	for _ = 1, math.clamp(math.floor(capD), 2, 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.1, 0.36) * capD
		ball(cap.Position + Vector3.new(math.cos(a) * r, capH * 0.38 - r * 0.25, math.sin(a) * r), math.max(0.25, capD * 0.07), glowColor:Lerp(WHITE, 0.5), Enum.Material.Neon)
	end
	if withLight then
		light(gills, glowColor, math.clamp(height * 3.2, 14, 40), 1.5)
		motes(gills, glowColor:Lerp(WHITE, 0.4), 1.2)
	end
end

local function mushroomPatch(floor: Vector3, glowColor: Color3)
	for _ = 1, rng:NextInteger(3, 6) do
		local p = floor + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		local h = rng:NextNumber(0.5, 1.8)
		rod(p, p + Vector3.new(0, h, 0), math.max(0.18, h * 0.16), Color3.fromRGB(230, 226, 214))
		ellipsoid(CFrame.new(p + Vector3.new(0, h, 0)), Vector3.new(h * 0.9, h * 0.35, h * 0.9), glowColor, Enum.Material.Neon).Transparency = 0.1
	end
end

local function grassTuft(floor: Vector3, color: Color3)
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(0.6, 1.7)
		local cf = CFrame.new(floor + Vector3.new(rng:NextNumber(-0.6, 0.6), h / 2 - 0.05, rng:NextNumber(-0.6, 0.6)))
			* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.35, 0.35))
		wedge(cf, Vector3.new(0.08, h, 0.45), vary(color, 0.08), Enum.Material.Grass)
	end
end

local function fern(floor: Vector3, color: Color3, scale: number)
	local n = rng:NextInteger(5, 8)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = rng:NextNumber(1.6, 2.8) * scale
		local cf = CFrame.new(floor) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(rng:NextNumber(35, 60)), 0, 0) * CFrame.new(0, len / 2, 0)
		ellipsoid(cf, Vector3.new(0.9 * scale, len, 0.12), vary(color, 0.06), Enum.Material.Grass)
	end
end

local function flowerCluster(floor: Vector3, color: Color3)
	for _ = 1, rng:NextInteger(3, 5) do
		local p = floor + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local h = rng:NextNumber(0.8, 2)
		rod(p, p + Vector3.new(rng:NextNumber(-0.2, 0.2), h, rng:NextNumber(-0.2, 0.2)), 0.12, theme.flora)
		ellipsoid(CFrame.new(p + Vector3.new(0, h, 0)), Vector3.new(0.6, 0.35, 0.6), color, Enum.Material.Neon).Transparency = 0.05
	end
end

local function pebbles(floor: Vector3)
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(0.4, 1.1)
		rockLump(floor + Vector3.new(rng:NextNumber(-1.5, 1.5), s * 0.2, rng:NextNumber(-1.5, 1.5)), Vector3.new(s * 1.4, s * 0.7, s * 1.1), theme.rock:Lerp(theme.rim, 0.2))
	end
end

-- A caged lantern hanging from `top` down to `at`.
local function hangingLantern(top: Vector3, at: Vector3, glowColor: Color3, frameColor: Color3?, range: number?)
	local metal = frameColor or Color3.fromRGB(46, 40, 38)
	rod(top, at + Vector3.new(0, 0.8, 0), 0.14, metal, Enum.Material.Metal)
	block(CFrame.new(at + Vector3.new(0, 0.75, 0)), Vector3.new(1.3, 0.25, 1.3), metal, Enum.Material.Metal)
	block(CFrame.new(at - Vector3.new(0, 0.75, 0)), Vector3.new(1.1, 0.25, 1.1), metal, Enum.Material.Metal)
	local glass = block(CFrame.new(at), Vector3.new(0.95, 1.3, 0.95), glowColor:Lerp(WHITE, 0.3), Enum.Material.Glass)
	glass.Transparency = 0.45
	local core = ellipsoid(CFrame.new(at), Vector3.new(0.55, 0.8, 0.55), glowColor, Enum.Material.Neon)
	for _, o in { Vector3.new(0.5, 0, 0.5), Vector3.new(-0.5, 0, 0.5), Vector3.new(0.5, 0, -0.5), Vector3.new(-0.5, 0, -0.5) } do
		rod(at + o - Vector3.new(0, 0.7, 0), at + o + Vector3.new(0, 0.7, 0), 0.1, metal, Enum.Material.Metal)
	end
	light(core, glowColor, range or 26, 1.6)
	motes(core, glowColor:Lerp(WHITE, 0.5), 1.2, 0.15)
end

-- A lamp post standing by the wall, its lantern hanging out over the path.
local function lampPost(floor: Vector3, side: number, glowColor: Color3, style: string)
	local h = rng:NextNumber(7, 9.5)
	local inward = Vector3.new(0, 0, -side)
	if style == "gold" then
		local gold = Color3.fromRGB(214, 170, 90)
		rod(floor, floor + Vector3.new(0, h, 0), 0.45, gold, Enum.Material.Metal, true)
		block(CFrame.new(floor + Vector3.new(0, 0.3, 0)), Vector3.new(1.4, 0.6, 1.4), theme.smooth, theme.material, true)
		local globe = ball(floor + Vector3.new(0, h + 0.7, 0), 1.6, glowColor:Lerp(WHITE, 0.2), Enum.Material.Glass)
		globe.Transparency = 0.35
		local core = ball(globe.Position, 0.9, glowColor, Enum.Material.Neon)
		ball(globe.Position + Vector3.new(0, 0.9, 0), 0.5, gold, Enum.Material.Metal)
		light(core, glowColor, 28, 1.7)
	else
		local wood = vary(theme.wood, 0.05)
		rod(floor, floor + Vector3.new(0, h, 0), 0.55, wood, Enum.Material.Wood, true)
		local armEnd = floor + Vector3.new(0, h - 0.3, 0) + inward * 2.2
		beam(floor + Vector3.new(0, h - 0.3, 0), armEnd, 0.3, 0.3, wood, Enum.Material.Wood)
		beam(floor + Vector3.new(0, h - 1.6, 0), floor + Vector3.new(0, h - 0.3, 0) + inward * 1.2, 0.2, 0.2, wood, Enum.Material.Wood)
		hangingLantern(armEnd, armEnd - Vector3.new(0, 1.8, 0), glowColor, nil, 28)
	end
end

local function column(floor: Vector3, height: number, radius: number, broken: boolean, collide: boolean)
	local stone = vary(theme.smooth, 0.04)
	local trim = theme.rim
	block(CFrame.new(floor + Vector3.new(0, 0.5, 0)), Vector3.new(radius * 2.8, 1, radius * 2.8), stone, theme.material, collide)
	block(CFrame.new(floor + Vector3.new(0, 1.2, 0)), Vector3.new(radius * 2.4, 0.4, radius * 2.4), trim, Enum.Material.Marble, collide)
	local h = if broken then height * rng:NextNumber(0.35, 0.7) else height
	rod(floor + Vector3.new(0, 1.3, 0), floor + Vector3.new(0, h, 0), radius * 2, stone, Enum.Material.Marble, collide)
	-- Fluting: thin darker strips around the shaft.
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local o = Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.96
		block(CFrame.new(floor + o + Vector3.new(0, (h + 1.3) / 2, 0)), Vector3.new(0.18, h - 1.6, 0.18), stone:Lerp(BLACK, 0.18), Enum.Material.Marble)
	end
	if broken then
		for _ = 1, 2 do
			wedge(CFrame.new(floor + Vector3.new(rng:NextNumber(-0.4, 0.4), h + 0.5, rng:NextNumber(-0.4, 0.4))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(radius * 1.2, 1.2, radius), stone, Enum.Material.Marble)
		end
		-- A fallen drum beside it.
		local d = floor + Vector3.new(rng:NextNumber(-3, 3), radius, rng:NextNumber(-1, 1))
		rod(d - Vector3.new(1.2, 0, 0), d + Vector3.new(1.2, 0, 0), radius * 2, stone, Enum.Material.Marble)
	else
		block(CFrame.new(floor + Vector3.new(0, h + 0.3, 0)), Vector3.new(radius * 2.7, 0.6, radius * 2.7), trim, Enum.Material.Marble, collide)
		block(CFrame.new(floor + Vector3.new(0, h + 0.9, 0)), Vector3.new(radius * 3.1, 0.6, radius * 3.1), stone, Enum.Material.Marble, collide)
	end
end

-- A stone moth-guardian on a pedestal, facing the path.
local function statue(floor: Vector3, side: number, stone: Color3, accent: Color3)
	local face = Vector3.new(0, 0, -side)
	local base = CFrame.lookAt(floor, floor + face)
	block(base * CFrame.new(0, 0.8, 0), Vector3.new(3, 1.6, 3), stone:Lerp(BLACK, 0.12), theme.material, true)
	block(base * CFrame.new(0, 1.7, 0), Vector3.new(2.6, 0.2, 2.6), accent, Enum.Material.Metal, true)
	local body = base * CFrame.new(0, 3.6, 0)
	ellipsoid(body, Vector3.new(1.7, 3.4, 1.4), stone, Enum.Material.Marble)
	ellipsoid(body * CFrame.new(0, 2.3, -0.1), Vector3.new(1.5, 1.6, 1.4), stone:Lerp(WHITE, 0.25), Enum.Material.Marble)
	-- Eyes: two dark hollows (the statue is a mask, like the living).
	for _, x in { -0.35, 0.35 } do
		ellipsoid(body * CFrame.new(x, 2.3, -0.62), Vector3.new(0.32, 0.55, 0.2), stone:Lerp(BLACK, 0.7), Enum.Material.SmoothPlastic)
	end
	for _, s in { -1, 1 } do
		-- Folded wings, sweeping down the back.
		local wing = body * CFrame.new(s * 0.7, 0.4, 0.55) * CFrame.Angles(0.15, s * 0.35, s * 0.18)
		ellipsoid(wing, Vector3.new(0.25, 3.6, 1.8), stone:Lerp(theme.rim, 0.15), Enum.Material.Marble)
		-- Antennae.
		rod(body.Position + Vector3.new(s * 0.3, 3, 0), body.Position + Vector3.new(s * 0.9, 4.6, 0.3), 0.14, stone, Enum.Material.Marble)
	end
	-- Hands resting on a sword.
	local blade = body * CFrame.new(0, -0.6, -0.9)
	block(blade * CFrame.new(0, -0.9, 0), Vector3.new(0.25, 3.2, 0.12), stone:Lerp(WHITE, 0.2), Enum.Material.Marble)
	block(blade * CFrame.new(0, 0.75, 0), Vector3.new(1.2, 0.22, 0.22), accent, Enum.Material.Metal)
end

local function banner(top: Vector3, length: number, side: number, color: Color3, emblem: Color3)
	local z = -side * 0.25
	rod(top + Vector3.new(-1.4, 0, z), top + Vector3.new(1.4, 0, z), 0.2, theme.rim, Enum.Material.Metal)
	local cloth = block(CFrame.new(top + Vector3.new(0, -length / 2, z)), Vector3.new(2.2, length, 0.1), color, Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		wedge(CFrame.new(top + Vector3.new(s * 0.55, -length - 0.5, z)) * CFrame.Angles(0, if s > 0 then HALF_PI else -HALF_PI, math.pi), Vector3.new(0.1, 1, 1.1), color, Enum.Material.Fabric)
	end
	local diamond = block(CFrame.new(cloth.Position + Vector3.new(0, length * 0.15, -side * 0.08)) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.8, 0.8, 0.06), emblem, Enum.Material.Neon)
	diamond.Transparency = 0.1
	block(CFrame.new(cloth.Position + Vector3.new(0, -length * 0.42, 0)), Vector3.new(2.25, 0.25, 0.13), theme.rim, Enum.Material.Fabric)
end

local function bookshelf(floor: Vector3, side: number, width: number, height: number, collide: boolean)
	local wood = vary(theme.wood, 0.04)
	local face = Vector3.new(0, 0, -side)
	local base = CFrame.lookAt(floor, floor + face)
	block(base * CFrame.new(0, height / 2, 0.55), Vector3.new(width, height, 0.3), wood:Lerp(BLACK, 0.3), Enum.Material.WoodPlanks, collide)
	for _, x in { -width / 2, width / 2 } do
		block(base * CFrame.new(x, height / 2, 0), Vector3.new(0.35, height, 1.4), wood, Enum.Material.WoodPlanks, collide)
	end
	block(base * CFrame.new(0, height + 0.2, 0), Vector3.new(width + 0.6, 0.4, 1.6), wood, Enum.Material.WoodPlanks, collide)
	local y = 0.3
	while y < height - 1.2 do
		block(base * CFrame.new(0, y, 0), Vector3.new(width, 0.2, 1.3), wood, Enum.Material.WoodPlanks, collide)
		-- Book blocks: a few runs of spines in different colours and heights.
		local x = -width / 2 + 0.3
		while x < width / 2 - 0.5 do
			local bw = math.min(rng:NextNumber(0.7, 1.6), width / 2 - 0.3 - x)
			local bh = rng:NextNumber(1.1, 1.7)
			local c = Color3.fromHSV(rng:NextNumber(0, 1), rng:NextNumber(0.35, 0.6), rng:NextNumber(0.35, 0.65))
			if rng:NextNumber() < 0.15 then
				-- A leaning book.
				block(base * CFrame.new(x + bw / 2, y + 0.1 + bh / 2, 0) * CFrame.Angles(0, 0, 0.35), Vector3.new(0.3, bh, 1), c, Enum.Material.Fabric)
			else
				block(base * CFrame.new(x + bw / 2, y + 0.1 + bh / 2, 0), Vector3.new(bw, bh, 1), c, Enum.Material.Fabric)
			end
			x += bw + 0.08
		end
		y += 2.1
	end
end

local function brazier(floor: Vector3, glowColor: Color3)
	local gold = Color3.fromRGB(210, 166, 86)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local o = Vector3.new(math.cos(a), 0, math.sin(a)) * 0.9
		rod(floor + o, floor + o * 0.5 + Vector3.new(0, 2.4, 0), 0.22, gold, Enum.Material.Metal)
	end
	rod(floor + Vector3.new(0, 2.3, 0), floor + Vector3.new(0, 3, 0), 2.2, gold, Enum.Material.Metal, true)
	local fire = ellipsoid(CFrame.new(floor + Vector3.new(0, 3.5, 0)), Vector3.new(1.3, 1.6, 1.3), glowColor, Enum.Material.Neon)
	ellipsoid(CFrame.new(floor + Vector3.new(0, 3.9, 0)), Vector3.new(0.7, 1.2, 0.7), glowColor:Lerp(WHITE, 0.6), Enum.Material.Neon)
	light(fire, glowColor, 30, 1.8)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(glowColor)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.3, 0)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Rate = 10
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Parent = fire
end

local function crate(floor: Vector3, s: number)
	local wood = vary(theme.wood, 0.06)
	local cf = CFrame.new(floor + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
	block(cf, Vector3.one * s, wood, Enum.Material.WoodPlanks, true)
	for _, y in { -0.42, 0.42 } do
		block(cf * CFrame.new(0, y * s, 0), Vector3.new(s * 1.02, s * 0.12, s * 1.02), wood:Lerp(BLACK, 0.35), Enum.Material.Wood)
	end
end

local function barrel(floor: Vector3)
	local wood = vary(theme.wood, 0.06)
	rod(floor, floor + Vector3.new(0, 2.6, 0), 2, wood, Enum.Material.Wood, true)
	for _, y in { 0.4, 1.3, 2.2 } do
		rod(floor + Vector3.new(0, y - 0.1, 0), floor + Vector3.new(0, y + 0.1, 0), 2.08, Color3.fromRGB(60, 56, 54), Enum.Material.Metal)
	end
end

local function fossil(center: Vector3, side: number)
	local bone = vary(theme.bone, 0.03)
	local inward = Vector3.new(0, 0, -side)
	if rng:NextNumber() < 0.55 then
		-- A spiral shell pressed into the rock.
		local turns = 14
		for i = 0, turns do
			local a = i * 0.55
			local r = 0.25 * math.exp(0.16 * a)
			local p = center + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0) + inward * 0.1
			ball(p, 0.28 + r * 0.45, bone, Enum.Material.Limestone)
		end
	else
		-- The ribs of something long and old.
		local len = rng:NextNumber(5, 9)
		local tilt = rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(tilt), math.sin(tilt), 0)
		for i = 0, 7 do
			local p = center + dir * (i / 7 - 0.5) * len + inward * 0.2
			ball(p, 0.7 - i * 0.04, bone, Enum.Material.Limestone)
			if i > 0 and i < 7 then
				local ribLen = 1.6 * math.sin(i / 7 * math.pi) + 0.5
				for _, s in { -1, 1 } do
					rod(p, p + Vector3.new(-dir.Y, dir.X, 0) * s * ribLen + dir * 0.4, 0.22, bone, Enum.Material.Limestone)
				end
			end
		end
	end
end

local function crack(center: Vector3, side: number, glowing: Color3?)
	local p = center
	local a = rng:NextNumber(-0.5, 0.5) - HALF_PI
	for _ = 1, rng:NextInteger(3, 5) do
		local len = rng:NextNumber(0.9, 2.2)
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local q = p + dir * len
		local b = beam(p + Vector3.new(0, 0, -side * 0.05), q + Vector3.new(0, 0, -side * 0.05), 0.2, 0.3, glowing or theme.rockDark, if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		if b and glowing then
			b.Transparency = 0.2
		end
		p = q
		a += rng:NextNumber(-0.7, 0.7)
	end
end

-- A rocky shelf jutting from the wall, sometimes with something resting on it.
local function wallLedge(center: Vector3, side: number, len: number)
	local depth = rng:NextNumber(1.6, 2.6)
	local cf = CFrame.new(center + Vector3.new(0, 0, -side * depth / 2)) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05))
	block(cf, Vector3.new(len, rng:NextNumber(0.7, 1.2), depth), vary(theme.rock, 0.05), theme.material)
	block(cf * CFrame.new(0, 0.5, 0), Vector3.new(len + 0.1, 0.18, depth + 0.1), vary(theme.rim, 0.04), theme.material)
	-- A wedge of rock underneath so it grows out of the wall.
	wedge(cf * CFrame.new(0, -1.1, side * 0.2) * CFrame.Angles(0, if side > 0 then 0 else math.pi, math.pi), Vector3.new(len * 0.85, 1.6, depth * 0.8), vary(theme.rock, 0.05), theme.material)
	return cf * CFrame.new(0, 0.6, 0)
end

local function glowShelf(center: Vector3, side: number, color: Color3, withLight: boolean)
	local first: BasePart? = nil
	for i = 1, rng:NextInteger(2, 4) do
		local p = center + Vector3.new(rng:NextNumber(-1.2, 1.2), (i - 1) * rng:NextNumber(0.8, 1.3), 0)
		local w = rng:NextNumber(1.6, 2.8)
		ellipsoid(CFrame.new(p + Vector3.new(0, 0.15, -side * w * 0.3)), Vector3.new(w, w * 0.28, w * 0.9), vary(theme.flora:Lerp(color, 0.25), 0.05), Enum.Material.SmoothPlastic)
		local g = ellipsoid(CFrame.new(p + Vector3.new(0, 0, -side * w * 0.3)), Vector3.new(w * 0.88, w * 0.12, w * 0.8), color, Enum.Material.Neon)
		first = first or g
	end
	if withLight and first then
		light(first, color, 20, 1.3)
	end
end

local function sconce(center: Vector3, side: number, color: Color3)
	local metal = Color3.fromRGB(64, 56, 52)
	block(CFrame.new(center + Vector3.new(0, 0, -side * 0.2)), Vector3.new(0.9, 1.6, 0.4), metal, Enum.Material.Metal)
	local cup = center + Vector3.new(0, 0.9, -side * 0.9)
	beam(center + Vector3.new(0, 0.2, -side * 0.3), cup, 0.25, 0.25, metal, Enum.Material.Metal)
	rod(cup - Vector3.new(0, 0.2, 0), cup + Vector3.new(0, 0.2, 0), 0.9, metal, Enum.Material.Metal)
	local flame = ellipsoid(CFrame.new(cup + Vector3.new(0, 0.6, 0)), Vector3.new(0.6, 1, 0.6), color, Enum.Material.Neon)
	light(flame, color, 24, 1.5)
end

-- A carved stone tablet set into the wall, with a gilded border and a faint glowing glyph.
local function reliefPanel(center: Vector3, side: number)
	local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, -side))
	block(cf * CFrame.new(0, 0, 0.1), Vector3.new(4, 5, 0.5), vary(theme.smooth, 0.03), Enum.Material.Marble)
	for _, y in { -2.5, 2.5 } do
		block(cf * CFrame.new(0, y, -0.15), Vector3.new(4.3, 0.3, 0.3), theme.rim, Enum.Material.Metal)
	end
	for _, x in { -2, 2 } do
		block(cf * CFrame.new(x, 0, -0.15), Vector3.new(0.3, 5.2, 0.3), theme.rim, Enum.Material.Metal)
	end
	-- A moth in flight, drawn in glowing lines.
	local g = theme.accent
	block(cf * CFrame.new(0, 0, -0.22), Vector3.new(0.25, 2.2, 0.05), g, Enum.Material.Neon)
	for _, s in { -1, 1 } do
		block(cf * CFrame.new(s * 0.8, 0.5, -0.22) * CFrame.Angles(0, 0, s * 0.6), Vector3.new(1.6, 0.18, 0.05), g, Enum.Material.Neon)
		block(cf * CFrame.new(s * 0.7, -0.4, -0.22) * CFrame.Angles(0, 0, -s * 0.5), Vector3.new(1.1, 0.18, 0.05), g, Enum.Material.Neon)
	end
end

-- A rope/root/vine hanging from `top`, swaying slightly.
local function strand(top: Vector3, length: number, d: number, color: Color3, material: Enum.Material, leafColor: Color3?, bulbColor: Color3?)
	local p = top
	local segs = math.clamp(math.floor(length / 2.5), 2, 5)
	for i = 1, segs do
		local q = top + Vector3.new(rng:NextNumber(-0.5, 0.5), -length * i / segs, rng:NextNumber(-0.5, 0.5))
		rod(p, q, d * (1 - i / segs * 0.4), color, material)
		if leafColor and rng:NextNumber() < 0.7 then
			ellipsoid(CFrame.new(q) * CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(0, 6), rng:NextNumber(-1, 1)), Vector3.new(0.9, 0.12, 0.5), vary(leafColor, 0.06), Enum.Material.Grass)
		end
		p = q
	end
	if bulbColor then
		ball(p, math.max(0.45, d * 1.6), bulbColor, Enum.Material.Neon)
	end
end

local function timberFrame(x: number, floorY: number, height: number, hz: number, withLantern: boolean, glowColor: Color3, collide: boolean)
	local wood = vary(theme.wood, 0.04)
	local zs = { -(hz - 1.2), hz - 1.2 }
	for _, z in zs do
		block(CFrame.new(x, floorY + height / 2, z), Vector3.new(1, height, 1), wood, Enum.Material.WoodPlanks, collide)
	end
	block(CFrame.new(x, floorY + height + 0.5, 0), Vector3.new(1.1, 1, hz * 2), wood, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		local z = s * (hz - 1.2)
		beam(Vector3.new(x, floorY + height - 3, z), Vector3.new(x, floorY + height + 0.2, z - s * 3), 0.6, 0.6, wood, Enum.Material.WoodPlanks)
	end
	if withLantern then
		hangingLantern(Vector3.new(x, floorY + height, rng:NextNumber(-3, 3)), Vector3.new(x, floorY + height - 2.4, 0), glowColor)
	end
end

-- An arch over the path, from wall to wall: dressed stone, living roots or pale bone.
local function arch(x: number, floorY: number, height: number, hz: number, style: string, collide: boolean)
	local span = hz - 1.4
	local rise = math.min(6, height * 0.3)
	local springY = floorY + height - rise
	local stone = vary(theme.smooth, 0.03)
	if style == "stone" then
		for _, s in { -1, 1 } do
			block(CFrame.new(x, floorY + (springY - floorY) / 2, s * span), Vector3.new(2.4, springY - floorY, 2.2), stone, theme.material, collide)
			block(CFrame.new(x, springY + 0.3, s * span), Vector3.new(2.9, 0.6, 2.7), theme.rim, Enum.Material.Marble)
			block(CFrame.new(x, floorY + 0.6, s * span), Vector3.new(3, 1.2, 2.8), stone:Lerp(BLACK, 0.1), theme.material, collide)
		end
	end
	local n = 11
	local prev: Vector3? = nil
	for i = 0, n do
		local t = i / n
		local a = math.pi * t
		local p = Vector3.new(x, springY + math.sin(a) * rise, -math.cos(a) * span)
		if prev then
			if style == "stone" then
				local b = beam(prev, p, 2.2, 1.6, if i == n // 2 + 1 then theme.rim else stone, Enum.Material.Marble)
				if b then
					b.Size += Vector3.new(0, 0, 0.5)
				end
			elseif style == "root" then
				rod(prev + Vector3.new(0, rng:NextNumber(-0.3, 0.3), 0), p, rng:NextNumber(1.2, 1.8), vary(theme.wood, 0.05), Enum.Material.Wood)
			else
				rod(prev, p, 0.9, theme.bone, Enum.Material.Limestone)
			end
		end
		prev = p
	end
	if style == "stone" then
		local key = block(CFrame.new(x, springY + rise + 0.2, 0), Vector3.new(2.5, 2, 1.4), theme.rim, Enum.Material.Marble)
		local gem = block(CFrame.new(x - 1.3, springY + rise + 0.2, 0) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.2, 0.9, 0.9), theme.accent, Enum.Material.Neon)
		light(gem, theme.accent, 16, 0.8)
		local _ = key
	elseif style == "root" then
		for _ = 1, 4 do
			local z = rng:NextNumber(-span, span)
			local y = springY + math.sin(math.acos(math.clamp(-z / span, -1, 1))) * rise
			strand(Vector3.new(x, y, z), rng:NextNumber(2, 5), 0.25, theme.flora, Enum.Material.Grass, theme.flora, if rng:NextNumber() < 0.6 then pick(theme.glow) else nil)
		end
	end
end

local function signpost(floor: Vector3, facing: Vector3, text: string)
	local wood = vary(theme.wood, 0.03)
	rod(floor, floor + Vector3.new(0, 5.2, 0), 0.45, wood, Enum.Material.Wood)
	local board = block(CFrame.lookAt(floor + Vector3.new(0, 4.3, 0), floor + Vector3.new(0, 4.3, 0) + facing), Vector3.new(5, 1.4, 0.25), wood:Lerp(WHITE, 0.1), Enum.Material.WoodPlanks)
	-- A pointed end toward the doorway.
	wedge(board.CFrame * CFrame.new(2.9, 0, 0) * CFrame.Angles(0, HALF_PI, 0), Vector3.new(0.25, 1.4, 0.8), wood:Lerp(WHITE, 0.1), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.Fantasy
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(250, 236, 206)
		label.TextStrokeTransparency = 0.4
		label.Text = text
		label.Parent = gui
		gui.Parent = board
	end
	-- A little lantern on top so the sign is visible from a distance.
	local l = ball(floor + Vector3.new(0, 5.6, 0), 0.7, theme.accent, Enum.Material.Neon)
	light(l, theme.accent, 16, 1.1)
end

-- ===========================================================================
-- Region styles
-- ===========================================================================
-- floor(pos, side, space, lit, collide): a prop against the wall; returns true if it gave light.
-- wall(pos, side, lit): a feature on the wall face.  hang(pos, maxLen): from a ceiling.
-- vista(center, side, width, height): distant scenery beyond a window in the wall.

type Style = {
	floor: (Vector3, number, number, boolean, boolean) -> boolean,
	wall: (Vector3, number, boolean) -> (),
	hang: (Vector3, number) -> (),
	ground: (Vector3) -> (),
	trim: (number, number, number, number, number) -> (),
	archStyle: string,
	platform: string,
	vista: (Vector3, number, number, number) -> (),
}

local function trimStrip(x1: number, x2: number, y: number, z: number, side: number, color: Color3, material: Enum.Material, height: number?, depth: number?)
	local h = height or 0.5
	local d = depth or 1.3
	block(CFrame.new((x1 + x2) / 2, y + h / 2, z - side * d / 2), Vector3.new(x2 - x1, h, d), color, material)
end

-- Distant scenery helpers.
local function tower(base: Vector3, h: number, w: number, color: Color3, windowColor: Color3)
	block(CFrame.new(base + Vector3.new(0, h / 2, 0)), Vector3.new(w, h, w), color, theme.material)
	block(CFrame.new(base + Vector3.new(0, h + 1, 0)), Vector3.new(w * 1.2, 2, w * 1.2), color:Lerp(WHITE, 0.1), theme.material)
	local spireH = w * 1.6
	for _, a in { 0, HALF_PI } do
		local cf = CFrame.new(base + Vector3.new(0, h + 2 + spireH / 2, 0)) * CFrame.Angles(0, a, 0)
		wedge(cf * CFrame.new(0, 0, -w * 0.3) * CFrame.Angles(0, math.pi, 0), Vector3.new(w * 0.9, spireH, w * 0.6), color:Lerp(BLACK, 0.2), theme.material)
		wedge(cf * CFrame.new(0, 0, w * 0.3), Vector3.new(w * 0.9, spireH, w * 0.6), color:Lerp(BLACK, 0.2), theme.material)
	end
	for _ = 1, math.floor(h / 6) do
		local y = rng:NextNumber(3, h - 3)
		for _, f in { -1, 1 } do
			local win = block(CFrame.new(base + Vector3.new(rng:NextNumber(-w * 0.3, w * 0.3), y, f * (w / 2 + 0.05))), Vector3.new(1, 1.6, 0.1), windowColor, Enum.Material.Neon)
			win.Transparency = rng:NextNumber(0, 0.4)
		end
	end
end

local function backdrop(center: Vector3, side: number, width: number, height: number, hzMin: number)
	-- The far cavern: a floor well below the window, a back wall and a roof, all terrain.
	local z0 = side * (hzMin + WALL)
	local depth = 150
	local far = side * (hzMin + WALL + depth)
	local floorY = center.Y - height / 2 - rng:NextNumber(18, 34)
	terrain:FillBlock(CFrame.new(center.X, floorY - 10, (z0 + far) / 2), Vector3.new(width + 220, 20, depth + 10), theme.wall)
	terrain:FillBlock(CFrame.new(center.X, center.Y + 30, far + side * 10), Vector3.new(width + 240, 220, 20), theme.wall)
	terrain:FillBlock(CFrame.new(center.X, center.Y + height / 2 + 70, (z0 + far) / 2), Vector3.new(width + 240, 20, depth + 20), theme.wall)
	for _, s in { -1, 1 } do
		terrain:FillBlock(CFrame.new(center.X + s * (width / 2 + 120), center.Y + 30, (z0 + far) / 2), Vector3.new(20, 220, depth + 20), theme.wall)
	end
	for _ = 1, 8 do
		terrain:FillBall(Vector3.new(center.X + rng:NextNumber(-width / 2 - 90, width / 2 + 90), floorY + rng:NextNumber(-4, 10), (z0 + far) / 2 + side * rng:NextNumber(-60, 60)), rng:NextNumber(10, 24), theme.wall)
	end
	return floorY, z0, far
end

local function vistaLights(center: Vector3, side: number, z0: number, far: number)
	for i = 1, 3 do
		local p = Vector3.new(center.X + (i - 2) * 50, center.Y + rng:NextNumber(-5, 25), (z0 + far) / 2 + side * rng:NextNumber(-20, 40))
		local holder = block(CFrame.new(p), Vector3.one * 0.5, theme.accent, Enum.Material.Neon)
		holder.Transparency = 1
		light(holder, pick(theme.glow), 70, 0.7)
	end
end

local STYLES: { [string]: Style } = {}

-- ----- Ashen Burrows: dug tunnels, timber, amber lanterns, coral fungus, fossils -----
STYLES.caves = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.18 then
			lampPost(pos, side, pick(theme.glow), "wood")
			return true
		elseif r < 0.4 then
			for _ = 1, rng:NextInteger(1, 3) do
				local h = rng:NextNumber(3, math.min(10, space * 0.6))
				spike(pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-1, 1)), Vector3.yAxis, h, h * 0.22, vary(theme.rock, 0.05), theme.material, theme.rim)
			end
		elseif r < 0.58 then
			crate(pos, rng:NextNumber(1.8, 2.6))
			if rng:NextNumber() < 0.5 then
				crate(pos + Vector3.new(rng:NextNumber(1.6, 2.4), 0, 0), rng:NextNumber(1.4, 2))
			end
			if rng:NextNumber() < 0.4 then
				barrel(pos + Vector3.new(-2.6, 0, 0))
			end
		elseif r < 0.8 then
			mushroomPatch(pos, pick(theme.glow))
		else
			rockLump(pos + Vector3.new(0, 1, 0), Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2, 3.5), rng:NextNumber(2.5, 4)))
			pebbles(pos + Vector3.new(0, 0, -side * 2))
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			glowShelf(pos, side, pick(theme.glow), true)
		elseif r < 0.3 then
			crack(pos, side)
		elseif r < 0.45 then
			fossil(pos, side)
		elseif r < 0.7 then
			local top = wallLedge(pos, side, rng:NextNumber(4, 8))
			if rng:NextNumber() < 0.5 then
				candle(top.Position + Vector3.new(rng:NextNumber(-1, 1), 0, 0), nil, true)
			end
		else
			glowShelf(pos, side, pick(theme.glow), false)
		end
	end,
	hang = function(pos, maxLen)
		local r = rng:NextNumber()
		if r < 0.55 then
			local len = math.min(maxLen, rng:NextNumber(2, 7))
			spike(pos, -Vector3.yAxis, len, len * 0.2, vary(theme.rock, 0.05), theme.material, theme.rim)
		elseif r < 0.85 then
			strand(pos, math.min(maxLen, rng:NextNumber(3, 9)), 0.35, vary(theme.wood, 0.05), Enum.Material.Wood, nil, if rng:NextNumber() < 0.3 then pick(theme.glow) else nil)
		else
			hangingLantern(pos, pos - Vector3.new(0, math.min(maxLen, rng:NextNumber(3, 6)), 0), pick(theme.glow))
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.5 then
			pebbles(pos)
		else
			grassTuft(pos, theme.flora)
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, vary(theme.rockDark:Lerp(theme.rock, 0.4), 0.03), theme.material, 0.7, 1.6)
	end,
	archStyle = "timber",
	platform = "wood",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		-- A lamplit mining settlement on ledges across the chasm.
		for _ = 1, 7 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 60, width / 2 + 60), floorY + rng:NextNumber(0, height + 20), (z0 + far) / 2 + side * rng:NextNumber(0, 60))
			terrain:FillBlock(CFrame.new(base - Vector3.new(0, 3, 0)), Vector3.new(rng:NextNumber(16, 28), 6, 14), theme.top)
			local hut = block(CFrame.new(base + Vector3.new(0, 3, 0)), Vector3.new(7, 6, 6), vary(theme.wood, 0.05), Enum.Material.WoodPlanks)
			wedge(hut.CFrame * CFrame.new(0, 4.5, 0), Vector3.new(8, 3, 7), theme.fabric, Enum.Material.Fabric)
			local win = block(hut.CFrame * CFrame.new(0, 0.5, -side * 3.05), Vector3.new(2, 2, 0.1), pick(theme.glow), Enum.Material.Neon)
			local _ = win
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- Mothlight Ruins: the golden city -----
STYLES.city = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.2 then
			lampPost(pos, side, pick(theme.glow), "gold")
			return true
		elseif r < 0.5 and space > 14 then
			column(pos, math.min(space - 3, rng:NextNumber(12, 20)), rng:NextNumber(1.3, 1.8), rng:NextNumber() < 0.45, collide)
		elseif r < 0.62 and space > 10 then
			statue(pos, side, theme.smooth, theme.rim)
		elseif r < 0.8 then
			-- Rubble from fallen masonry.
			for _ = 1, rng:NextInteger(3, 6) do
				local s = rng:NextNumber(0.8, 2)
				block(CFrame.new(pos + Vector3.new(rng:NextNumber(-2.5, 2.5), s * 0.4, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), Vector3.new(s * 1.5, s, s), vary(theme.smooth, 0.05), theme.material)
			end
		else
			-- A planter with a small golden tree.
			block(CFrame.new(pos + Vector3.new(0, 0.8, 0)), Vector3.new(3, 1.6, 3), theme.smooth, Enum.Material.Marble, collide)
			rod(pos + Vector3.new(0, 1.6, 0), pos + Vector3.new(0.3, 4.5, 0), 0.4, theme.wood, Enum.Material.Wood)
			for _ = 1, 4 do
				ellipsoid(CFrame.new(pos + Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(4.2, 5.4), rng:NextNumber(-1.2, 1.2))), Vector3.new(2.2, 1.6, 2.2), vary(Color3.fromRGB(230, 178, 70), 0.05), Enum.Material.Grass)
			end
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			sconce(pos, side, pick(theme.glow))
		elseif r < 0.35 then
			reliefPanel(pos, side)
		elseif r < 0.6 then
			banner(pos + Vector3.new(0, 4, 0), rng:NextNumber(5, 8), side, theme.fabric, theme.accent)
		elseif r < 0.8 then
			wallLedge(pos, side, rng:NextNumber(3, 6))
		else
			crack(pos, side)
		end
	end,
	hang = function(pos, maxLen)
		if rng:NextNumber() < 0.5 then
			hangingLantern(pos, pos - Vector3.new(0, math.min(maxLen, rng:NextNumber(3, 8)), 0), pick(theme.glow), Color3.fromRGB(190, 150, 80))
		else
			local len = math.min(maxLen, rng:NextNumber(4, 9))
			banner(pos - Vector3.new(0, 0.5, 0), len, 1, theme.fabric, theme.accent)
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.6 then
			-- Loose golden floor tiles.
			block(CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(2, 0.15, 2), vary(theme.rim, 0.04), Enum.Material.Marble)
		else
			grassTuft(pos, theme.flora)
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.smooth, Enum.Material.Marble, 0.9, 1.6)
		trimStrip(x1, x2, y + 0.9, z, side, Color3.fromRGB(226, 180, 90), Enum.Material.Metal, 0.25, 1.75)
	end,
	archStyle = "stone",
	platform = "stone",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		-- The golden city stretching into the haze: towers with lit windows.
		for _ = 1, 12 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 80, width / 2 + 80), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			tower(base, rng:NextNumber(30, 80), rng:NextNumber(6, 12), vary(theme.smooth, 0.05), pick(theme.glow))
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- Verdant Hush: an overgrown grotto -----
STYLES.forest = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.25 then
			mushroom(pos, rng:NextNumber(4, math.min(11, space * 0.7)), theme.flora:Lerp(Color3.fromRGB(240, 240, 220), 0.3), pick(theme.glow), true, collide)
			return true
		elseif r < 0.5 then
			fern(pos, theme.flora, rng:NextNumber(1, 1.6))
			if rng:NextNumber() < 0.5 then
				flowerCluster(pos + Vector3.new(2, 0, 0), pick(theme.glow))
			end
		elseif r < 0.7 then
			-- A mossy fallen log.
			local a = pos + Vector3.new(-3, 0.8, 0)
			local b = pos + Vector3.new(3, 1, rng:NextNumber(-1, 1))
			rod(a, b, 1.8, vary(theme.wood, 0.05), Enum.Material.Wood, collide)
			ellipsoid(CFrame.new((a + b) / 2 + Vector3.new(0, 0.8, 0)), Vector3.new(5, 0.6, 1.6), theme.flora, Enum.Material.Grass)
		elseif r < 0.85 then
			mushroomPatch(pos, pick(theme.glow))
		else
			flowerCluster(pos, pick(theme.glow))
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			glowShelf(pos, side, pick(theme.glow), true)
		elseif r < 0.45 then
			-- Curtains of ivy.
			for _ = 1, rng:NextInteger(2, 4) do
				strand(pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(2, 5), -side * 0.3), rng:NextNumber(3, 7), 0.2, theme.flora, Enum.Material.Grass, theme.flora, if rng:NextNumber() < 0.3 then pick(theme.glow) else nil)
			end
		elseif r < 0.65 then
			glowShelf(pos, side, pick(theme.glow), false)
		elseif r < 0.85 then
			local top = wallLedge(pos, side, rng:NextNumber(4, 7))
			grassTuft(top.Position, theme.flora)
		else
			fossil(pos, side)
		end
	end,
	hang = function(pos, maxLen)
		strand(pos, math.min(maxLen, rng:NextNumber(3, 10)), rng:NextNumber(0.25, 0.5), vary(theme.wood:Lerp(theme.flora, 0.4), 0.05), Enum.Material.Wood, theme.flora, if rng:NextNumber() < 0.45 then pick(theme.glow) else nil)
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.7 then
			grassTuft(pos, theme.flora)
		else
			flowerCluster(pos, pick(theme.glow))
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.flora, Enum.Material.Grass, 0.6, 2)
	end,
	archStyle = "root",
	platform = "wood",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		-- Giant trees with glowing canopies and a waterfall.
		for _ = 1, 8 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 70, width / 2 + 70), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			local h = rng:NextNumber(40, 90)
			rod(base, base + Vector3.new(rng:NextNumber(-4, 4), h, 0), rng:NextNumber(4, 7), vary(theme.wood, 0.05), Enum.Material.Wood)
			for _ = 1, 3 do
				ellipsoid(CFrame.new(base + Vector3.new(rng:NextNumber(-8, 8), h + rng:NextNumber(-6, 4), rng:NextNumber(-8, 8))), Vector3.new(rng:NextNumber(16, 26), rng:NextNumber(8, 12), rng:NextNumber(16, 26)), vary(theme.flora, 0.06), Enum.Material.Grass)
			end
			ball(base + Vector3.new(0, h - 8, 0), 2, pick(theme.glow), Enum.Material.Neon)
		end
		local fx = center.X + rng:NextNumber(-60, 60)
		for i = 1, 3 do
			local fall = block(CFrame.new(fx + (i - 2) * 2.2, center.Y + 10, far - side * (12 + i)), Vector3.new(1.6, 140, 0.4), Color3.fromRGB(190, 240, 255), Enum.Material.Neon)
			fall.Transparency = 0.7
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- Sanctum of Still Wings: ivory and gold -----
STYLES.temple = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.25 then
			brazier(pos, pick(theme.glow))
			return true
		elseif r < 0.6 and space > 14 then
			column(pos, math.min(space - 3, rng:NextNumber(14, 24)), rng:NextNumber(1.5, 2), rng:NextNumber() < 0.15, collide)
		elseif r < 0.8 and space > 10 then
			statue(pos, side, theme.smooth, theme.rim)
		else
			-- An urn of pale flowers.
			rod(pos, pos + Vector3.new(0, 2, 0), 1.6, theme.rim, Enum.Material.Metal, collide)
			flowerCluster(pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 200, 220))
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			sconce(pos, side, pick(theme.glow))
		elseif r < 0.4 then
			reliefPanel(pos, side)
		elseif r < 0.75 then
			banner(pos + Vector3.new(0, 5, 0), rng:NextNumber(6, 10), side, theme.fabric, theme.rim)
		else
			wallLedge(pos, side, rng:NextNumber(3, 6))
		end
	end,
	hang = function(pos, maxLen)
		if rng:NextNumber() < 0.55 then
			hangingLantern(pos, pos - Vector3.new(0, math.min(maxLen, rng:NextNumber(4, 10)), 0), pick(theme.glow), Color3.fromRGB(214, 172, 90))
		else
			banner(pos - Vector3.new(0, 0.5, 0), math.min(maxLen, rng:NextNumber(6, 12)), 1, theme.fabric, theme.rim)
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.5 then
			block(CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(1.8, 0.12, 1.8), theme.rim, Enum.Material.Marble)
		else
			flowerCluster(pos, Color3.fromRGB(255, 214, 230))
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.smooth, Enum.Material.Marble, 1.1, 1.7)
		trimStrip(x1, x2, y + 1.1, z, side, Color3.fromRGB(230, 184, 96), Enum.Material.Metal, 0.3, 1.85)
	end,
	archStyle = "stone",
	platform = "stone",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		for _ = 1, 8 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 70, width / 2 + 70), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			tower(base, rng:NextNumber(40, 100), rng:NextNumber(6, 10), theme.smooth, theme.accent)
		end
		-- The Great Lamp's glow on the horizon.
		local lamp = ball(Vector3.new(center.X, center.Y + 30, far - side * 20), 24, Color3.fromRGB(255, 226, 170), Enum.Material.Neon)
		lamp.Transparency = 0.3
		light(lamp, Color3.fromRGB(255, 220, 160), 120, 2)
		vistaLights(center, side, z0, far)
	end,
}

-- ----- Glimmerdeep Mines: violet crystal and old timber -----
STYLES.crystal = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.35 then
			crystalCluster(pos, Vector3.new(0, 1, -side * 0.35), rng:NextNumber(1, 1.8), pick(theme.glow), true)
			return true
		elseif r < 0.55 then
			-- An abandoned mine cart full of glowing ore.
			local cf = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0)
			block(cf, Vector3.new(4, 2, 2.6), Color3.fromRGB(72, 62, 70), Enum.Material.CorrodedMetal, collide)
			for _, x in { -1.3, 1.3 } do
				for _, z in { -1.35, 1.35 } do
					rod((cf * CFrame.new(x, -1, z)).Position - Vector3.new(0, 0, 0.15), (cf * CFrame.new(x, -1, z)).Position + Vector3.new(0, 0, 0.15), 1, Color3.fromRGB(40, 36, 40), Enum.Material.Metal)
				end
			end
			for _ = 1, 4 do
				block(cf * CFrame.new(rng:NextNumber(-1.3, 1.3), 1.1, rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Vector3.one * rng:NextNumber(0.6, 1), pick(theme.glow), Enum.Material.Neon)
			end
			for _, z in { -0.8, 0.8 } do
				block(CFrame.new(pos + Vector3.new(0, 0.1, z)), Vector3.new(9, 0.2, 0.25), Color3.fromRGB(90, 84, 90), Enum.Material.Metal)
			end
		elseif r < 0.75 then
			crate(pos, rng:NextNumber(1.6, 2.2))
		else
			for _ = 1, rng:NextInteger(3, 5) do
				local s = rng:NextNumber(0.8, 1.8)
				rockLump(pos + Vector3.new(rng:NextNumber(-2, 2), s * 0.3, rng:NextNumber(-1, 1)), Vector3.new(s * 1.5, s, s * 1.2))
			end
			crystalCluster(pos, Vector3.yAxis, 0.5, pick(theme.glow), false)
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			crystalCluster(pos, Vector3.new(0, 0.4, -side), rng:NextNumber(0.8, 1.3), pick(theme.glow), true)
		elseif r < 0.45 then
			-- A glowing crystal vein through the rock.
			crack(pos, side, pick(theme.glow))
		elseif r < 0.7 then
			crystalCluster(pos, Vector3.new(0, 0.2, -side), rng:NextNumber(0.5, 0.9), pick(theme.glow), false)
		else
			wallLedge(pos, side, rng:NextNumber(3, 6))
		end
	end,
	hang = function(pos, maxLen)
		if rng:NextNumber() < 0.6 then
			crystalCluster(pos, -Vector3.yAxis, math.min(1.2, maxLen / 6), pick(theme.glow), rng:NextNumber() < 0.3)
		else
			local len = math.min(maxLen, rng:NextNumber(2, 6))
			spike(pos, -Vector3.yAxis, len, len * 0.2, vary(theme.rock, 0.05), theme.material, theme.rim)
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.5 then
			crystalCluster(pos, Vector3.yAxis, 0.3, pick(theme.glow), false)
		else
			pebbles(pos)
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.rockDark:Lerp(theme.rock, 0.5), theme.material, 0.8, 1.6)
		local x = x1 + 1
		while x < x2 - 1 do
			local s = block(CFrame.new(x, y + 0.9, z - side * 1.3) * CFrame.Angles(0, math.rad(45), rng:NextNumber(-0.4, 0.4)), Vector3.new(0.4, rng:NextNumber(0.6, 1.4), 0.4), pick(theme.glow), Enum.Material.Neon)
			s.Transparency = 0.1
			x += rng:NextNumber(2.5, 5)
		end
	end,
	archStyle = "timber",
	platform = "wood",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		for _ = 1, 10 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 70, width / 2 + 70), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			crystalCluster(base, Vector3.new(rng:NextNumber(-0.3, 0.3), 1, rng:NextNumber(-0.3, 0.3)), rng:NextNumber(6, 14), pick(theme.glow), true)
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- Drowned Archive: stacks, reading desks, candles and aqua lamps -----
STYLES.library = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.2 then
			-- A reading desk with candles.
			local wood = vary(theme.wood, 0.04)
			block(CFrame.new(pos + Vector3.new(0, 2, 0)), Vector3.new(4, 0.3, 2), wood, Enum.Material.WoodPlanks, collide)
			for _, x in { -1.7, 1.7 } do
				block(CFrame.new(pos + Vector3.new(x, 1, 0)), Vector3.new(0.3, 2, 1.8), wood, Enum.Material.WoodPlanks, collide)
			end
			block(CFrame.new(pos + Vector3.new(-0.6, 2.25, 0)) * CFrame.Angles(0, 0.3, 0), Vector3.new(1.6, 0.2, 1.1), Color3.fromRGB(236, 228, 204))
			candle(pos + Vector3.new(1.2, 2.15, 0.3), 0.9, true)
			candle(pos + Vector3.new(1.5, 2.15, -0.4), 0.6, false)
			return true
		elseif r < 0.65 and space > 10 then
			bookshelf(pos, side, rng:NextNumber(5, 7), math.min(space - 2, rng:NextNumber(8, 14)), collide)
		elseif r < 0.85 then
			-- A leaning stack of books.
			for i = 0, rng:NextInteger(3, 7) do
				block(CFrame.new(pos + Vector3.new(rng:NextNumber(-0.15, 0.15), 0.2 + i * 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(rng:NextNumber(1.2, 1.8), 0.38, rng:NextNumber(0.9, 1.3)), Color3.fromHSV(rng:NextNumber(0, 1), 0.45, rng:NextNumber(0.35, 0.6)), Enum.Material.Fabric)
			end
		else
			local pool = block(CFrame.new(pos + Vector3.new(0, 0.06, -side * 1.5)), Vector3.new(rng:NextNumber(4, 7), 0.1, rng:NextNumber(2.5, 4)), theme.accent:Lerp(BLACK, 0.4), Enum.Material.Glass)
			pool.Transparency = 0.35
			pool.Reflectance = 0.3
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			sconce(pos, side, pick(theme.glow))
		elseif r < 0.4 then
			-- Floating pages caught in an old draught.
			for _ = 1, rng:NextInteger(3, 6) do
				block(CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-1, 3), -side * rng:NextNumber(1, 4))) * CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(0, 6), rng:NextNumber(-1, 1)), Vector3.new(0.9, 1.2, 0.03), Color3.fromRGB(238, 230, 206))
			end
		elseif r < 0.7 then
			local top = wallLedge(pos, side, rng:NextNumber(4, 7))
			candle(top.Position, nil, rng:NextNumber() < 0.4)
		else
			crack(pos, side)
		end
	end,
	hang = function(pos, maxLen)
		if rng:NextNumber() < 0.45 then
			hangingLantern(pos, pos - Vector3.new(0, math.min(maxLen, rng:NextNumber(3, 8)), 0), pick(theme.glow))
		else
			-- Dripping water frozen as glassy strands.
			local len = math.min(maxLen, rng:NextNumber(2, 6))
			local drip = block(CFrame.new(pos - Vector3.new(0, len / 2, 0)), Vector3.new(0.15, len, 0.15), Color3.fromRGB(170, 230, 240), Enum.Material.Glass)
			drip.Transparency = 0.4
			strand(pos + Vector3.new(1, 0, 0), math.min(maxLen, rng:NextNumber(2, 6)), 0.25, theme.flora, Enum.Material.Grass, theme.flora, nil)
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.5 then
			block(CFrame.new(pos + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(0.9, 0.05, 1.2), Color3.fromRGB(238, 230, 206))
		else
			pebbles(pos)
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.wood:Lerp(BLACK, 0.2), Enum.Material.WoodPlanks, 1.2, 1.2)
		trimStrip(x1, x2, y + 1.2, z, side, theme.rim, Enum.Material.WoodPlanks, 0.2, 1.35)
	end,
	archStyle = "timber",
	platform = "wood",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		-- Towering stacks lost in the drowned dark, and a cascade pouring between them.
		for _ = 1, 10 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 70, width / 2 + 70), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			local h = rng:NextNumber(40, 100)
			local w = rng:NextNumber(10, 16)
			block(CFrame.new(base + Vector3.new(0, h / 2, 0)), Vector3.new(w, h, 5), vary(theme.wood, 0.05), Enum.Material.WoodPlanks)
			for y = 4, h - 4, 6 do
				block(CFrame.new(base + Vector3.new(0, y, -side * 2.6)), Vector3.new(w - 1, 3.5, 0.2), Color3.fromHSV(rng:NextNumber(0, 1), 0.4, 0.45), Enum.Material.Fabric)
			end
			if rng:NextNumber() < 0.5 then
				ball(base + Vector3.new(0, h + 2, 0), 2.5, pick(theme.glow), Enum.Material.Neon)
			end
		end
		local fx = center.X + rng:NextNumber(-70, 70)
		for i = 1, 3 do
			local fall = block(CFrame.new(fx + (i - 2) * 2, center.Y + 10, far - side * (20 + i)), Vector3.new(1.4, 160, 0.4), Color3.fromRGB(150, 230, 240), Enum.Material.Neon)
			fall.Transparency = 0.7
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- The Hollowroot: forgotten lanterns in a silver abyss -----
local function lanternPile(pos: Vector3, lit: boolean)
	local brightest: BasePart? = nil
	for i = 1, rng:NextInteger(4, 7) do
		local p = pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-1.5, 1.5))
		local s = rng:NextNumber(0.8, 1.4)
		local cf = CFrame.new(p + Vector3.new(0, s * 0.6, 0)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6))
		local glass = ellipsoid(cf, Vector3.new(s, s * 1.3, s), Color3.fromRGB(200, 206, 226), Enum.Material.Glass)
		glass.Transparency = 0.45
		block(cf * CFrame.new(0, s * 0.7, 0), Vector3.new(s * 0.6, s * 0.2, s * 0.6), Color3.fromRGB(60, 62, 72), Enum.Material.Metal)
		if i <= 2 then
			local core = ball(cf.Position, s * 0.45, pick(theme.glow), Enum.Material.Neon)
			brightest = brightest or core
		end
	end
	if lit and brightest then
		light(brightest, theme.accent, 24, 1.3)
		motes(brightest, theme.accent, 1.5)
	end
end

STYLES.abyss = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.35 then
			lanternPile(pos, true)
			return true
		elseif r < 0.6 then
			-- A cairn of flat stones.
			local y = 0
			for i = 1, rng:NextInteger(3, 6) do
				local s = 2.2 - i * 0.28
				ellipsoid(CFrame.new(pos + Vector3.new(rng:NextNumber(-0.2, 0.2), y + s * 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(s, s * 0.4, s * 0.9), vary(theme.rim, 0.05), Enum.Material.Slate)
				y += s * 0.36
			end
		elseif r < 0.8 then
			for _ = 1, rng:NextInteger(1, 3) do
				local h = rng:NextNumber(3, math.min(9, space * 0.6))
				spike(pos + Vector3.new(rng:NextNumber(-2, 2), 0, 0), Vector3.yAxis, h, h * 0.18, vary(theme.rock, 0.04), theme.material, theme.rim)
			end
		else
			fossil(pos + Vector3.new(0, 2.5, side * 0.5), side)
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			sconce(pos, side, pick(theme.glow))
		elseif r < 0.4 then
			crack(pos, side, if rng:NextNumber() < 0.5 then theme.accent:Lerp(BLACK, 0.2) else nil)
		elseif r < 0.65 then
			fossil(pos, side)
		else
			for _ = 1, rng:NextInteger(2, 3) do
				strand(pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(2, 5), -side * 0.3), rng:NextNumber(3, 7), 0.25, theme.flora, Enum.Material.Wood, nil, nil)
			end
		end
	end,
	hang = function(pos, maxLen)
		local r = rng:NextNumber()
		if r < 0.45 then
			hangingLantern(pos, pos - Vector3.new(0, math.min(maxLen, rng:NextNumber(3, 10)), 0), pick(theme.glow), Color3.fromRGB(70, 72, 84), 22)
		elseif r < 0.8 then
			strand(pos, math.min(maxLen, rng:NextNumber(4, 12)), 0.3, theme.flora, Enum.Material.Wood, nil, nil)
		else
			local len = math.min(maxLen, rng:NextNumber(3, 8))
			spike(pos, -Vector3.yAxis, len, len * 0.2, vary(theme.rock, 0.04), theme.material, theme.rim)
		end
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.6 then
			pebbles(pos)
		else
			candle(pos, rng:NextNumber(0.4, 0.9), false)
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.rim, Enum.Material.Salt, 0.4, 2)
	end,
	archStyle = "bone",
	platform = "stone",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		-- Thousands of abandoned lanterns drifting in the dark.
		for _ = 1, 40 do
			local p = Vector3.new(center.X + rng:NextNumber(-width / 2 - 90, width / 2 + 90), floorY + rng:NextNumber(5, height + 60), (z0 + far) / 2 + side * rng:NextNumber(-40, 60))
			ball(p, rng:NextNumber(0.8, 2), pick(theme.glow), Enum.Material.Neon)
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ----- The Glowmire: giant blue mushrooms and still, glowing pools -----
STYLES.glowmire = {
	floor = function(pos, side, space, lit, collide)
		local r = rng:NextNumber()
		if lit or r < 0.3 then
			mushroom(pos, rng:NextNumber(5, math.min(16, space * 0.75)), Color3.fromRGB(70, 110, 200), pick(theme.glow), true, collide)
			return true
		elseif r < 0.5 then
			mushroomPatch(pos, pick(theme.glow))
		elseif r < 0.7 then
			local pool = ellipsoid(CFrame.new(pos + Vector3.new(0, 0.05, -side * 2)), Vector3.new(rng:NextNumber(5, 9), 0.12, rng:NextNumber(3, 5)), theme.accent, Enum.Material.Neon)
			pool.Transparency = 0.45
			for _ = 1, 3 do
				local reed = pos + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-1, 1))
				rod(reed, reed + Vector3.new(0, rng:NextNumber(1.5, 3.5), 0), 0.15, theme.flora, Enum.Material.Grass)
			end
		elseif r < 0.85 then
			-- Spore pods on stalks.
			for _ = 1, rng:NextInteger(2, 4) do
				local p = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1, 1))
				local h = rng:NextNumber(1.5, 3.5)
				rod(p, p + Vector3.new(0, h, 0), 0.2, theme.flora, Enum.Material.Grass)
				local pod = ball(p + Vector3.new(0, h + 0.4, 0), rng:NextNumber(0.8, 1.3), pick(theme.glow), Enum.Material.Neon)
				pod.Transparency = 0.15
			end
		else
			fern(pos, theme.flora, rng:NextNumber(1, 1.5))
		end
		return false
	end,
	wall = function(pos, side, lit)
		local r = rng:NextNumber()
		if lit then
			glowShelf(pos, side, pick(theme.glow), true)
		elseif r < 0.45 then
			glowShelf(pos, side, pick(theme.glow), false)
		elseif r < 0.7 then
			for _ = 1, rng:NextInteger(2, 4) do
				strand(pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(2, 5), -side * 0.3), rng:NextNumber(3, 8), 0.2, theme.flora, Enum.Material.Grass, nil, if rng:NextNumber() < 0.6 then pick(theme.glow) else nil)
			end
		elseif r < 0.85 then
			crack(pos, side, theme.accent:Lerp(BLACK, 0.3))
		else
			fossil(pos, side)
		end
	end,
	hang = function(pos, maxLen)
		strand(pos, math.min(maxLen, rng:NextNumber(4, 12)), rng:NextNumber(0.2, 0.4), theme.flora, Enum.Material.Grass, nil, pick(theme.glow))
	end,
	ground = function(pos)
		if rng:NextNumber() < 0.6 then
			grassTuft(pos, theme.flora)
		else
			mushroomPatch(pos, pick(theme.glow))
		end
	end,
	trim = function(x1, x2, y, z, side)
		trimStrip(x1, x2, y, z, side, theme.flora, Enum.Material.Grass, 0.5, 2)
		local glow = block(CFrame.new((x1 + x2) / 2, y + 0.55, z - side * 2.05), Vector3.new(x2 - x1, 0.12, 0.3), theme.accent, Enum.Material.Neon)
		glow.Transparency = 0.35
	end,
	archStyle = "root",
	platform = "mushroom",
	vista = function(center, side, width, height)
		local hz = math.abs(center.Z) - WALL / 2
		local floorY, z0, far = backdrop(center, side, width, height, hz)
		for _ = 1, 9 do
			local base = Vector3.new(center.X + rng:NextNumber(-width / 2 - 70, width / 2 + 70), floorY, (z0 + far) / 2 + side * rng:NextNumber(-30, 60))
			mushroom(base, rng:NextNumber(30, 70), Color3.fromRGB(60, 96, 190), pick(theme.glow), true, false)
		end
		for _ = 1, 3 do
			local pool = ellipsoid(CFrame.new(Vector3.new(center.X + rng:NextNumber(-60, 60), floorY + 0.5, (z0 + far) / 2 + side * rng:NextNumber(-20, 40))), Vector3.new(rng:NextNumber(30, 60), 1, rng:NextNumber(20, 40)), theme.accent, Enum.Material.Neon)
			pool.Transparency = 0.5
		end
		vistaLights(center, side, z0, far)
	end,
}

-- ===========================================================================
-- Map analysis
-- ===========================================================================

local SOLID = { ["#"] = true, ["%"] = true }
local HAZARD = { ["^"] = true, ["~"] = true }
local ENEMY = { c = true, f = true, s = true, g = true, m = true, h = true, w = true }

local function isSolid(chars, c: number, r: number, w: number, h: number): boolean
	if c < 1 or c > w or r < 1 or r > h then
		return true
	end
	return SOLID[chars[r][c]] == true
end

-- Tiles that are part of gates, seals, cracked walls and switches count as "busy".
local function isBusy(ch: string): boolean
	return not (ch == "." or ch == "o" or SOLID[ch] or HAZARD[ch] or ENEMY[ch])
end

-- ===========================================================================
-- Dressing a zone
-- ===========================================================================

function CaveArt.dress(zoneIndex: number, chars, w: number, h: number, zoneTheme, folder: Instance)
	theme = zoneTheme
	rng = Random.new(zoneIndex * 9173 + 17)
	local style = STYLES[theme.decor] or STYLES.caves
	local art = Instance.new("Folder")
	art.Name = "CaveArt"
	art.Parent = folder
	parent = art
	partCount = 0

	local zone = Zones[zoneIndex]
	local ox = Grid.originX(zoneIndex)
	local function colX(c: number): number
		return ox + (c - 0.5) * T
	end
	local function rowTop(r: number): number
		return (h - r + 1) * T
	end
	local function hzAt(c: number): number
		return Grid.halfWidth(zoneIndex, c)
	end

	-- Columns that must stay clear: near doors, benches, NPCs, items, switches, gates.
	local busy: { [number]: boolean } = {}
	for r = 1, h do
		for c = 1, w do
			if isBusy(chars[r][c]) then
				for dc = -2, 2 do
					busy[c + dc] = true
				end
			end
		end
	end
	local arena: { number }? = nil
	for _, spec in zone.specials do
		if spec.kind == "boss" then
			arena = spec.arena
		end
	end
	local function inArena(c: number): boolean
		return arena ~= nil and c >= (arena :: { number })[1] - 1 and c <= (arena :: { number })[2] + 1
	end

	-- Clear vertical space above the floor tile (c, r), in tiles.
	local function clearance(c: number, r: number): number
		local n = 0
		local rr = r
		while rr >= 1 and not isSolid(chars, c, rr, w, h) do
			n += 1
			rr -= 1
		end
		return n
	end

	local sections = {}
	local function mark(name: string)
		table.insert(sections, name .. "=" .. partCount)
	end
	mark("start")
	-- ===== 1. Terrain shaping: buttresses along the walls and ribs across tall ceilings =====
	local lastRib = -100
	for c = 1, w do
		local hz = hzAt(c)
		local x = colX(c)
		-- Find open runs in this column to place boulders where they'll be seen.
		for r = 2, h - 1 do
			if not isSolid(chars, c, r, w, h) and isSolid(chars, c, r + 1, w, h) then
				local clear = clearance(c, r)
				local floorY = rowTop(r + 1)
				if rng:NextNumber() < 0.5 then
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					local radius = rng:NextNumber(3.5, 7)
					local y = floorY + rng:NextNumber(0, math.max(2, clear * T * 0.8))
					terrain:FillBall(Vector3.new(x + rng:NextNumber(-2, 2), y, side * (hz + radius * 0.6)), radius, theme.wall)
				end
				-- A rock rib arching across a tall ceiling.
				if clear >= 8 and c - lastRib > 12 and not inArena(c) and rng:NextNumber() < 0.35 then
					lastRib = c
					local ceilY = rowTop(r - clear + 1)
					terrain:FillCylinder(CFrame.new(x, ceilY - 1.5, 0) * CFrame.Angles(HALF_PI, 0, 0), hz * 2 + 8, rng:NextNumber(2.5, 3.5), theme.wall)
				end
			end
		end
	end

	mark("terrain")
	-- ===== 2. Floor strips: runs of open tiles standing on solid ground =====
	type Strip = { r: number, c1: number, c2: number, y: number }
	local strips: { Strip } = {}
	for r = 1, h - 1 do
		local c = 1
		while c <= w do
			local standable = not isSolid(chars, c, r, w, h) and not HAZARD[chars[r][c]] and isSolid(chars, c, r + 1, w, h)
			if standable then
				local c2 = c
				while c2 + 1 <= w and not isSolid(chars, c2 + 1, r, w, h) and not HAZARD[chars[r][c2 + 1]] and isSolid(chars, c2 + 1, r + 1, w, h) do
					c2 += 1
				end
				table.insert(strips, { r = r, c1 = c, c2 = c2, y = rowTop(r + 1) })
				c = c2 + 1
			else
				c += 1
			end
		end
	end

	local lastLightX = -math.huge
	for _, s in strips do
		local x1, x2 = colX(s.c1) - T / 2, colX(s.c2) + T / 2
		-- Trims and rocks where the floor meets both walls.
		local cc = s.c1
		while cc <= s.c2 do
			local cEnd = math.min(s.c2, cc + 3)
			local hz = hzAt(cc)
			for _, side in { -1, 1 } do
				style.trim(colX(cc) - T / 2, colX(cEnd) + T / 2, s.y, side * hz, side)
			end
			cc = cEnd + 1
		end
		for c = s.c1, s.c2 do
			local hz = hzAt(c)
			local x = colX(c)
			for _, side in { -1, 1 } do
				if rng:NextNumber() < 0.38 then
					local sz = Vector3.new(rng:NextNumber(2.5, 5), rng:NextNumber(1.4, 3.2), rng:NextNumber(2.2, 3.6))
					rockLump(Vector3.new(x + rng:NextNumber(-1.5, 1.5), s.y + sz.Y * 0.28, side * (hz - 0.3)), sz, theme.rock:Lerp(theme.rockDark, rng:NextNumber(0, 0.35)))
				end
			end
		end

		-- Rocky lips where a platform drops away.
		for _, edge in { { c = s.c1, dir = -1 }, { c = s.c2, dir = 1 } } do
			local nc = edge.c + edge.dir
			if nc >= 1 and nc <= w and not isSolid(chars, nc, s.r + 1, w, h) and not isSolid(chars, nc, s.r, w, h) then
				local ex = colX(edge.c) + edge.dir * T / 2
				local hz = hzAt(edge.c)
				local z = -hz + 1
				while z < hz - 1 and style.platform ~= "mushroom" do
					local sz = rng:NextNumber(1.2, 2.4)
					rockLump(Vector3.new(ex - edge.dir * sz * 0.35, s.y - sz * 0.15, z), Vector3.new(sz * 1.2, sz * 0.8, sz * 1.3), theme.rock:Lerp(theme.rim, rng:NextNumber(0, 0.3)))
					z += rng:NextNumber(3.2, 5)
				end
				-- Moss or roots hanging down the drop.
				for _ = 1, rng:NextInteger(1, 3) do
					strand(Vector3.new(ex + edge.dir * 0.3, s.y - 0.5, rng:NextNumber(-hz + 2, hz - 2)), rng:NextNumber(2, 5), 0.25, theme.flora, Enum.Material.Grass, nil, nil)
				end
			end
		end

		-- Props along the walls and light pools.
		local x = x1 + rng:NextNumber(2, 5)
		while x < x2 - 2 do
			local c = math.clamp(math.floor((x - ox) / T) + 1, 1, w)
			if not busy[c] then
				local hz = hzAt(c)
				local space = clearance(c, s.r) * T
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local lit = x - lastLightX > 17
				local collide = not inArena(c)
				local pos = Vector3.new(x, s.y, side * (hz - rng:NextNumber(2.2, 3.5)))
				if space >= 8 then
					if style.floor(pos, side, space, lit, collide) then
						lastLightX = x
					end
				end
				-- Ground cover scattered across the floor.
				for _ = 1, 2 do
					if rng:NextNumber() < 0.35 then
						style.ground(Vector3.new(x + rng:NextNumber(-3, 3), s.y, rng:NextNumber(-hz + 2, hz - 2)))
					end
				end
			end
			x += rng:NextNumber(6, 10)
		end
	end

	mark("floors")
	-- ===== 3. Walls: features at several heights on both walls =====
	for c = 1, w, 3 do
		local hz = hzAt(c)
		local x = colX(c)
		for r = 2, h - 1 do
			-- Wall height bands: every open run, sampled every few tiles.
			if not isSolid(chars, c, r, w, h) and isSolid(chars, c, r + 1, w, h) then
				local clear = clearance(c, r)
				local floorY = rowTop(r + 1)
				for _, side in { -1, 1 } do
					local y = floorY + rng:NextNumber(4, 7)
					local limit = floorY + clear * T - 3
					while y < limit do
						local high = y - floorY > 36
						if rng:NextNumber() < (if high then 0.22 else 0.26) and not busy[c] then
							-- Lights high on tall walls keep the upper cave from going black.
							local lit = y - floorY > 10 and rng:NextNumber() < (if high then 0.6 else 0.28)
							style.wall(Vector3.new(x + rng:NextNumber(-1.5, 1.5), y, side * (hz - 0.1)), side, lit)
						end
						-- Detail thins out high above the path, where it's only seen from afar.
						y += if high then rng:NextNumber(16, 24) else rng:NextNumber(7, 11)
					end
				end
			end
		end
	end

	mark("walls")
	-- ===== 4. Ceilings: things hanging down =====
	for c = 1, w do
		local hz = hzAt(c)
		local x = colX(c)
		for r = 2, h - 1 do
			if not isSolid(chars, c, r, w, h) and isSolid(chars, c, r - 1, w, h) then
				-- Find how far down the open space goes.
				local rr = r
				while rr <= h and not isSolid(chars, c, rr, w, h) do
					rr += 1
				end
				local depth = (rr - r) * T
				local maxLen = math.max(0, depth - 10)
				if maxLen > 1.5 then
					local ceilY = rowTop(r)
					for _ = 1, 2 do
						if rng:NextNumber() < 0.2 then
							style.hang(Vector3.new(x + rng:NextNumber(-1.8, 1.8), ceilY + 0.5, rng:NextNumber(-hz + 1.5, hz - 1.5)), maxLen)
						end
					end
				end
			end
		end
	end

	mark("ceilings")
	-- ===== 5. Arches / frames over the path =====
	local lastArch = -100
	for _, s in strips do
		for c = s.c1 + 2, s.c2 - 2 do
			local clear = clearance(c, s.r)
			if c - lastArch > 11 and clear >= 6 and not busy[c] and rng:NextNumber() < 0.2 then
				-- The span above must be open across a few columns.
				local ok = true
				for dc = -1, 1 do
					if clearance(c + dc, s.r) < 6 then
						ok = false
					end
				end
				if ok then
					lastArch = c
					local height = math.min(clear * T - 3, rng:NextNumber(14, 20))
					local hz = hzAt(c)
					if style.archStyle == "timber" then
						timberFrame(colX(c), s.y, height, hz, true, pick(theme.glow), not inArena(c))
					else
						arch(colX(c), s.y, height, hz, style.archStyle, not inArena(c))
					end
				end
			end
		end
	end

	mark("arches")
	-- ===== 6. Floating platforms: bridges, stone slabs or mushroom caps =====
	for _, s in strips do
		-- A floating platform: a single row of solid with open space under it.
		local under = s.r + 2
		local floating = under <= h
		for c = s.c1, s.c2 do
			if under > h or isSolid(chars, c, under, w, h) then
				floating = false
			end
		end
		if floating and s.c2 - s.c1 <= 10 then
			local x1, x2 = colX(s.c1) - T / 2, colX(s.c2) + T / 2
			local hz = hzAt(s.c1)
			local bottom = s.y - T
			if style.platform == "wood" then
				local plankZ = -hz + 0.6
				while plankZ < hz - 0.6 do
					block(CFrame.new((x1 + x2) / 2, s.y + 0.05, plankZ), Vector3.new(x2 - x1 + 0.4, 0.3, 0.95), vary(theme.wood, 0.06), Enum.Material.WoodPlanks)
					plankZ += 1.1
				end
				for _, x in { x1 + 0.4, x2 - 0.4 } do
					block(CFrame.new(x, bottom + 0.3, 0), Vector3.new(0.8, 0.8, hz * 2), theme.wood:Lerp(BLACK, 0.25), Enum.Material.Wood)
					-- Ropes up into the dark.
					for _, z in { -hz * 0.6, hz * 0.6 } do
						rod(Vector3.new(x, s.y, z), Vector3.new(x, s.y + 26, z), 0.18, Color3.fromRGB(150, 124, 90), Enum.Material.Fabric)
					end
				end
			elseif style.platform == "mushroom" then
				local cx = (x1 + x2) / 2
				-- The platform becomes a giant cap: glowing gills underneath, a stem to the floor.
				local gills = ellipsoid(CFrame.new(cx, bottom - 0.3, 0), Vector3.new(x2 - x1 + 4, 2, hz * 2), pick(theme.glow), Enum.Material.Neon)
				gills.Transparency = 0.15
				light(gills, gills.Color, 30, 1.2)
				local rr = under
				while rr <= h and not isSolid(chars, s.c1, rr, w, h) do
					rr += 1
				end
				local groundY = rowTop(rr)
				if s.y - groundY < 60 then
					rod(Vector3.new(cx, groundY, 0), Vector3.new(cx, bottom, 0), math.min(4, (x2 - x1) * 0.3), Color3.fromRGB(200, 214, 230), Enum.Material.SmoothPlastic)
				end
			else
				-- Dressed stone with a gilded edge.
				for _, x in { x1, x2 } do
					block(CFrame.new(x, s.y - 0.4, 0), Vector3.new(0.6, 0.8, hz * 2), theme.rim, Enum.Material.Metal)
				end
				for _ = 1, 3 do
					spike(Vector3.new(rng:NextNumber(x1 + 1, x2 - 1), bottom, rng:NextNumber(-hz + 3, hz - 3)), -Vector3.yAxis, rng:NextNumber(2, 5), 0.8, theme.rock, theme.material, theme.rim)
				end
			end
		end
	end

	mark("platforms")
	-- ===== 7. Signposts at every doorway =====
	for r = 1, h do
		for c = 1, w do
			local ch = chars[r][c]
			if string.match(ch, "%d") and (r == h or chars[r + 1][c] ~= ch) then
				-- Bottom tile of a doorway: find where it leads.
				local dest = nil
				for i, other in Zones do
					if i ~= zoneIndex then
						for _, line in other.map do
							if string.find(line, ch, 1, true) then
								dest = other.name
							end
						end
					end
				end
				local inward = if c <= w / 2 then 1 else -1
				local sc = c + inward * 2
				if dest and sc >= 1 and sc <= w then
					local hz = hzAt(sc)
					local floorY = rowTop(r + 1)
					signpost(Vector3.new(colX(sc), floorY, -(hz - 3)), Vector3.new(inward, 0, 0), dest)
				end
			end
		end
	end

	mark("signs")
	-- ===== 8. Windows onto distant scenery =====
	local vistas = 0
	local c = 4
	while c < w - 10 and vistas < 3 do
		local ok = not busy[c] and not inArena(c)
		local floorR = nil
		if ok then
			-- The lowest open run in this column that is tall.
			for r = h - 1, 2, -1 do
				if not isSolid(chars, c, r, w, h) and isSolid(chars, c, r + 1, w, h) and clearance(c, r) >= 8 then
					floorR = r
					break
				end
			end
		end
		if floorR then
			local width = 0
			while c + width < w and width < 8 and not busy[c + width] and not inArena(c + width) and clearance(c + width, floorR) >= 8 and isSolid(chars, c + width, floorR + 1, w, h) do
				width += 1
			end
			if width >= 6 and rng:NextNumber() < 0.6 then
				vistas += 1
				local c1, c2 = c + 1, c + width - 2
				local x1, x2 = colX(c1) - T / 2, colX(c2) + T / 2
				local floorY = rowTop(floorR + 1)
				local clear = clearance(c, floorR) * T
				local yb = floorY + 9
				local yt = floorY + math.min(clear - 4, 30)
				local hzMin = math.huge
				for cc = c1, c2 do
					hzMin = math.min(hzMin, hzAt(cc))
				end
				local side = -1
				local center = Vector3.new((x1 + x2) / 2, (yb + yt) / 2, side * (hzMin + WALL / 2))
				-- Cut the window and keep players (and the camera) on this side of it.
				terrain:FillBlock(CFrame.new(center.X, center.Y, side * (hzMin + WALL / 2 + 1)), Vector3.new(x2 - x1, yt - yb, WALL + 8), Enum.Material.Air)
				local barrier = Instance.new("Part")
				barrier.Name = "VistaBarrier"
				barrier.Anchored = true
				barrier.Transparency = 1
				barrier.CanQuery = true
				barrier.Size = Vector3.new(x2 - x1, yt - yb, 1)
				barrier.Position = Vector3.new(center.X, center.Y, side * (hzMin + 0.5))
				barrier.Parent = folder:FindFirstChild("Map") or folder
				-- A carved frame around the opening.
				for _, x in { x1, x2 } do
					block(CFrame.new(x, center.Y, side * (hzMin + 0.4)), Vector3.new(1.4, yt - yb + 2, 1.2), theme.rim:Lerp(theme.rock, 0.3), theme.material)
				end
				block(CFrame.new(center.X, yt + 0.6, side * (hzMin + 0.4)), Vector3.new(x2 - x1 + 2, 1.2, 1.2), theme.rim:Lerp(theme.rock, 0.3), theme.material)
				block(CFrame.new(center.X, yb - 0.6, side * (hzMin + 0.4)), Vector3.new(x2 - x1 + 2, 1.2, 1.6), theme.rim:Lerp(theme.rock, 0.3), theme.material)
				style.vista(center, side, x2 - x1, yt - yb)
				c += width + 20
			else
				c += math.max(1, width)
			end
		else
			c += 1
		end
	end

	mark("vistas")
	if CaveArt.debug then
		print(string.format("[CaveArt] zone %d: %s", zoneIndex, table.concat(sections, " ")))
	end
	return partCount
end

return CaveArt
