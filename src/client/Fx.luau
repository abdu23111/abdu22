-- Local-only visual effects: glowing shards, puffs, dust rings, impact flashes, nail arcs,
-- shatter bursts, soul wisps and afterimages. Everything is anchored, non-colliding and
-- cleans itself up. The palette stays restrained: pale light, a little colour, soft fades.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local folder = Instance.new("Folder")
folder.Name = "LocalFx"
folder.Parent = workspace

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.fromRGB(255, 255, 255)

-- An anchored, non-interactive neon part. Stretched balls become sphere meshes.
function Fx.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	local size = props.Size
	if props.Shape == Enum.PartType.Ball and size and not (size.X == size.Y and size.Y == size.Z) then
		p.Shape = Enum.PartType.Block
		p.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = folder
	return p
end

-- Tween a part to invisible (plus any extra goals) and destroy it.
function Fx.fade(p: BasePart, duration: number, goals: { [string]: any }?, style: Enum.EasingStyle?)
	local goal = goals or {}
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(duration, function()
		p:Destroy()
	end)
end

local function randomUnit(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.yAxis
end

-- A soft, expanding cloud (dust, landing puffs, spell impacts).
function Fx.puff(position: Vector3, color: Color3, size: number, duration: number?)
	local p = Fx.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size * 0.6, size),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.5,
	})
	Fx.fade(p, duration or 0.4, { Size = Vector3.new(size * 2.2, size * 1.1, size * 2.2), Position = p.Position + Vector3.new(0, size * 0.3, 0) })
end

-- Streaks flying outward in every direction (or biased along `dir`).
function Fx.sparks(at: Vector3, color: Color3?, count: number?, length: number?, dir: Vector3?)
	for _ = 1, count or 6 do
		local d = randomUnit()
		if dir then
			d = (d * 0.8 + dir.Unit).Unit
		end
		local len = (length or 1.4) * (0.6 + math.random() * 0.7)
		local cf = CFrame.lookAt(at, at + d)
		local p = Fx.part({
			Size = Vector3.new(0.14, 0.14, len),
			Color = color or WHITE,
			CFrame = cf * CFrame.new(0, 0, -len / 2),
		})
		Fx.fade(p, 0.18 + math.random() * 0.1, { CFrame = p.CFrame + d * (2 + math.random() * 2.5), Size = Vector3.new(0.05, 0.05, len * 0.4) })
	end
end

-- A flat ring of dust or light spreading across the floor.
function Fx.ring(at: Vector3, color: Color3, radius: number, duration: number?, transparency: number?)
	local p = Fx.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 0.4, radius * 0.4),
		CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = transparency or 0.45,
	})
	Fx.fade(p, duration or 0.45, { Size = Vector3.new(0.1, radius * 2, radius * 2) })
end

-- A brief point of light (hits, casts, landings).
function Fx.light(at: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local holder = Fx.part({ Size = Vector3.new(0.1, 0.1, 0.1), Position = at, Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = holder
	TweenService:Create(l, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	task.delay(duration, function()
		holder:Destroy()
	end)
end

-- The impact frame of a landed strike: a white star that pops and vanishes, a thin flash
-- slice across the strike direction, sparks thrown along it, and a flicker of light.
function Fx.impact(at: Vector3, dir: Vector3, color: Color3?, heavy: boolean?)
	local c = color or WHITE
	local s = if heavy then 1.7 else 1
	local star = Fx.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2 * s, Position = at, Color = WHITE })
	Fx.fade(star, 0.12, { Size = Vector3.one * 3.4 * s })
	local d = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.xAxis
	local side = d:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	local slice = Fx.part({
		Size = Vector3.new(0.12, 0.12, 6 * s),
		CFrame = CFrame.lookAt(at, at + side.Unit + Vector3.new(0, 0.35, 0)),
		Color = c,
	})
	Fx.fade(slice, 0.16, { Size = Vector3.new(0.03, 0.03, 8.5 * s) })
	Fx.sparks(at, c, if heavy then 12 else 7, if heavy then 2.2 else 1.5, d)
	Fx.light(at, c, if heavy then 20 else 12, if heavy then 4 else 2.5, 0.2)
end

-- A crescent of blade-light swept in a plane. `cf` is placed at the swing's pivot with its
-- LookVector as the swing's centre line and UpVector as the plane's normal.
function Fx.slash(cf: CFrame, radius: number, heavy: boolean?, color: Color3?, follow: BasePart?)
	local count = if heavy then 9 else 6
	local spread = math.rad(if heavy then 150 else 115)
	local c = color or (if heavy then Color3.fromRGB(255, 225, 255) else Color3.fromRGB(240, 244, 255))
	local segments = {}
	local offset = if follow then follow.CFrame:ToObjectSpace(cf) else nil
	for i = 0, count - 1 do
		local f = i / (count - 1)
		local a = -spread / 2 + spread * f
		-- Thick in the middle and tapering at both ends; the leading edge is brightest.
		local taper = math.sin(f * math.pi)
		local thickness = (if heavy then 0.9 else 0.55) * (0.25 + 0.75 * taper)
		local len = radius * spread / count * 1.25
		local p = Fx.part({
			Size = Vector3.new(thickness, 0.12, len),
			Color = c,
			Transparency = 0.05 + (1 - f) * 0.45,
		})
		table.insert(segments, { part = p, angle = a })
		task.delay(f * 0.05, function()
			Fx.fade(p, if heavy then 0.24 else 0.15)
		end)
	end
	local function place()
		local base = if follow and offset then follow.CFrame * offset else cf
		for _, s in segments do
			if s.part.Parent then
				local dirCf = base * CFrame.Angles(0, s.angle, 0)
				s.part.CFrame = (dirCf * CFrame.new(0, 0, -radius)) * CFrame.Angles(0, math.pi / 2, 0)
			end
		end
	end
	place()
	if follow then
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not segments[1].part.Parent or not follow.Parent then
				conn:Disconnect()
				return
			end
			place()
		end)
	end
end

-- A defeated creature breaks into drifting shards and a puff of its colour.
function Fx.shatter(at: Vector3, color: Color3, count: number?, size: number?)
	local n = count or 10
	local s = size or 1
	for _ = 1, n do
		local d = randomUnit() + Vector3.new(0, 0.6, 0)
		local shard = Fx.part({
			Size = Vector3.new(0.3, 0.3, 0.8) * s * (0.6 + math.random()),
			CFrame = CFrame.lookAt(at, at + d),
			Color = color,
			Material = if math.random() < 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
		local goal = shard.CFrame * CFrame.Angles(math.random() * 6, math.random() * 6, 0) + d * (3 + math.random() * 4) * s - Vector3.new(0, 1.5 * s, 0)
		Fx.fade(shard, 0.55 + math.random() * 0.3, { CFrame = goal })
	end
	Fx.puff(at, color:Lerp(WHITE, 0.3), 2.5 * s, 0.5)
	Fx.light(at, color:Lerp(WHITE, 0.5), 14 * s, 3, 0.35)
end

-- Soul drawn from a struck creature into the player: small motes curving to `target`.
function Fx.wisps(from: Vector3, target: BasePart, count: number?)
	for i = 1, count or 3 do
		local mote = Fx.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Position = from, Color = Color3.fromRGB(230, 240, 255) })
		local bend = randomUnit() * 4 + Vector3.new(0, 3, 0)
		local start = os.clock() + i * 0.04
		local duration = 0.45 + math.random() * 0.15
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			if t >= 1 or not target.Parent then
				conn:Disconnect()
				mote:Destroy()
				return
			end
			local to = target.Position
			local a = from:Lerp(from + bend, t)
			local b = (from + bend):Lerp(to, t)
			mote.Position = a:Lerp(b, t)
			mote.Size = Vector3.one * (0.45 * (1 - t * 0.6))
		end)
	end
end

-- A frozen, fading copy of a rig's current pose (dash trails, dodges, blinks).
function Fx.afterimage(rig: any, color: Color3, transparency: number?, duration: number?)
	if not rig or not rig.partList then
		return
	end
	for _, src in rig.partList do
		local part = src :: BasePart
		if part.Transparency < 0.9 then
			local ghost = Instance.new(if part:IsA("WedgePart") then "WedgePart" else "Part") :: BasePart
			if ghost:IsA("Part") and part:IsA("Part") then
				ghost.Shape = part.Shape
			end
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.CastShadow = false
			ghost.Size = part.Size
			ghost.CFrame = part.CFrame
			ghost.Color = color
			ghost.Material = Enum.Material.Neon
			ghost.Transparency = transparency or 0.6
			local mesh = part:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh:Clone().Parent = ghost
			end
			ghost.Parent = folder
			Fx.fade(ghost, duration or 0.25)
		end
	end
end

-- A burst of sparkles that lingers a moment (casts, pickups, ability flourishes).
function Fx.glitter(at: Vector3, color: Color3, amount: number?, spread: number?)
	local holder = Fx.part({ Size = Vector3.one * (spread or 2), Position = at, Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(3, 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount or 20)
	task.delay(1, function()
		holder:Destroy()
	end)
end

return Fx
