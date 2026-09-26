-- Server-simulated hostile projectiles (spores, stones, webs, light orbs, ink) and expanding
-- shockwave rings that sweep along the floor and must be jumped.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Props = require(script.Parent.World.Props)

local Projectiles = {}

type Projectile = {
	part: BasePart,
	velocity: Vector3,
	gravity: number,
	radius: number,
	damage: number,
	expires: number,
	passWalls: boolean,
}

type Ring = {
	part: BasePart,
	center: Vector3,
	radius: number,
	speed: number,
	maxRadius: number,
	height: number,
	damage: number,
	hit: { [Player]: boolean },
}

export type Options = {
	position: Vector3,
	velocity: Vector3,
	color: Color3?,
	radius: number?,
	gravity: number?,
	lifetime: number?,
	damage: number?,
	passWalls: boolean?,
}

local active: { Projectile } = {}
local rings: { Ring } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local damageFn: (Player, number, Vector3) -> ()

function Projectiles.spawn(opts: Options)
	local radius = opts.radius or 0.9
	local color = opts.color or Color3.fromRGB(200, 255, 170)
	local p = Props.make("Part", {
		Name = "Projectile",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Position = opts.position,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Color = color,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	Props.make("PointLight", { Range = 8, Brightness = 1.2, Color = color, Parent = p })
	Props.make("Trail", {
		Attachment0 = Props.make("Attachment", { Position = Vector3.new(0, radius * 0.5, 0), Parent = p }),
		Attachment1 = Props.make("Attachment", { Position = Vector3.new(0, -radius * 0.5, 0), Parent = p }),
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = 0.25,
		LightEmission = 0.8,
		FaceCamera = true,
		Parent = p,
	})
	table.insert(active, {
		part = p,
		velocity = opts.velocity,
		gravity = opts.gravity or 0,
		radius = radius,
		damage = opts.damage or 1,
		expires = os.clock() + (opts.lifetime or 4),
		passWalls = opts.passWalls == true,
	})
end

-- A ring of force expanding from `center` along the floor. Jump it.
function Projectiles.ring(center: Vector3, speed: number, maxRadius: number, color: Color3?)
	local p = Props.make("Part", {
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Color = color or Color3.fromRGB(255, 246, 230),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		Parent = folder,
	})
	table.insert(rings, {
		part = p,
		center = center,
		radius = 1,
		speed = speed,
		maxRadius = maxRadius,
		height = 2.2,
		damage = 1,
		hit = {},
	})
end

function Projectiles.clear()
	for _, proj in active do
		proj.part:Destroy()
	end
	for _, ring in rings do
		ring.part:Destroy()
	end
	table.clear(active)
	table.clear(rings)
end

function Projectiles.init(mapFolders: { Instance }, damage: (Player, number, Vector3) -> ())
	folder = Props.make("Folder", { Name = "Projectiles", Parent = workspace })
	local include = table.clone(mapFolders)
	table.insert(include, workspace.Terrain)
	rayParams.FilterDescendantsInstances = include
	damageFn = damage

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local roots = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(roots, { player, root })
			end
		end
		for i = #active, 1, -1 do
			local proj = active[i]
			local from = proj.part.Position
			proj.velocity += Vector3.new(0, -proj.gravity * dt, 0)
			local step = proj.velocity * dt
			local hitWall = false
			if not proj.passWalls then
				if workspace:Raycast(from, step, rayParams) then
					hitWall = true
				end
			end
			local to = from + step
			proj.part.Position = to
			for _, entry in roots do
				local root = entry[2] :: BasePart
				local d = root.Position - to
				if math.abs(d.X) < proj.radius + 1.1 and math.abs(d.Z) < proj.radius + 1.1 and math.abs(d.Y) < proj.radius + 2.4 then
					damageFn(entry[1], proj.damage, to)
					hitWall = true
					break
				end
			end
			if hitWall or now > proj.expires then
				proj.part:Destroy()
				table.remove(active, i)
			end
		end
		for i = #rings, 1, -1 do
			local ring = rings[i]
			ring.radius += ring.speed * dt
			ring.part.Size = Vector3.new(1.4, ring.radius * 2, ring.radius * 2)
			ring.part.Transparency = 0.55 + 0.4 * (ring.radius / ring.maxRadius)
			for _, entry in roots do
				local player, root = entry[1], entry[2] :: BasePart
				local d = root.Position - ring.center
				local flat = Vector3.new(d.X, 0, d.Z).Magnitude
				-- The wave is a thin band just above the floor: stand clear of it or jump.
				if not ring.hit[player] and math.abs(flat - ring.radius) < 1.3 and d.Y < ring.height + 3 and d.Y > -2 then
					ring.hit[player] = true
					damageFn(player, ring.damage, ring.center)
				end
			end
			if ring.radius >= ring.maxRadius then
				ring.part:Destroy()
				table.remove(rings, i)
			end
		end
	end)
end

return Projectiles
