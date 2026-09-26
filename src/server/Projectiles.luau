-- Simple server-simulated projectiles (spores, rocks, webs, light orbs).

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
		Color = color,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	Props.make("PointLight", { Range = 8, Brightness = 1, Color = color, Parent = p })
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

function Projectiles.clear()
	for _, proj in active do
		proj.part:Destroy()
	end
	table.clear(active)
end

function Projectiles.init(mapFolders: { Instance }, damage: (Player, number, Vector3) -> ())
	folder = Props.make("Folder", { Name = "Projectiles", Parent = workspace })
	rayParams.FilterDescendantsInstances = mapFolders
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
				local result = workspace:Raycast(from, step, rayParams)
				if result then
					hitWall = true
				end
			end
			local to = from + step
			proj.part.Position = to
			for _, entry in roots do
				local root = entry[2] :: BasePart
				local d = root.Position - to
				if math.abs(d.X) < proj.radius + 1.1 and math.abs(d.Y) < proj.radius + 2.4 then
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
	end)
end

return Projectiles
