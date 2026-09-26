-- Regular enemies and their AI. Enemies are anchored, server-moved models; they only
-- think while a player is in their zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Damageable = require(script.Parent.Damageable)
local Projectiles = require(script.Parent.Projectiles)
local Props = require(script.Parent.World.Props)

local T = Config.TILE
local make = Props.make

local Enemies = {}

type PartSpec = {
	shape: Enum.PartType?,
	size: Vector3,
	offset: Vector3,
	rz: number?,
	color: Color3,
	neon: boolean?,
	transparency: number?,
	wing: boolean?,
}

type Kind = {
	name: string,
	hp: number,
	geo: number,
	size: Vector3,
	flying: boolean,
	parts: { PartSpec },
}

local MASK = Color3.fromRGB(232, 228, 218)
local EYE = Color3.fromRGB(10, 10, 14)

local KINDS: { [string]: Kind } = {
	c = {
		name = "Husk Mite",
		hp = 10,
		geo = 2,
		size = Vector3.new(3.4, 2.4, 2.6),
		flying = false,
		parts = {
			{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 2.4, 2.6), offset = Vector3.new(-0.2, 0, 0), color = Color3.fromRGB(88, 78, 70) },
			{ shape = Enum.PartType.Ball, size = Vector3.new(1.5, 1.4, 1.6), offset = Vector3.new(1.4, -0.2, 0.2), color = MASK },
			{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.5, 0.3), offset = Vector3.new(1.9, -0.1, 0.8), color = EYE },
			{ size = Vector3.new(0.25, 0.9, 0.25), offset = Vector3.new(0.6, -1.1, 0.6), rz = 0.4, color = Color3.fromRGB(40, 36, 34) },
			{ size = Vector3.new(0.25, 0.9, 0.25), offset = Vector3.new(-0.9, -1.1, 0.6), rz = -0.4, color = Color3.fromRGB(40, 36, 34) },
		},
	},
	f = {
		name = "Gloom Gnat",
		hp = 8,
		geo = 3,
		size = Vector3.new(2.4, 2.2, 2.2),
		flying = true,
		parts = {
			{ shape = Enum.PartType.Ball, size = Vector3.new(2.2, 2, 2), offset = Vector3.zero, color = Color3.fromRGB(58, 44, 72) },
			{ shape = Enum.PartType.Ball, size = Vector3.new(0.45, 0.45, 0.3), offset = Vector3.new(0.8, 0.3, 0.8), color = Color3.fromRGB(255, 150, 70), neon = true },
			{ size = Vector3.new(2.6, 0.12, 1.4), offset = Vector3.new(-0.3, 1.1, 0), rz = 0.4, color = Color3.fromRGB(190, 190, 220), transparency = 0.5, wing = true },
			{ size = Vector3.new(0.3, 0.8, 0.3), offset = Vector3.new(1.1, -0.2, 0), rz = -0.8, color = Color3.fromRGB(30, 24, 36) },
		},
	},
	s = {
		name = "Spore Bulb",
		hp = 14,
		geo = 4,
		size = Vector3.new(3, 3.4, 3),
		flying = false,
		parts = {
			{ size = Vector3.new(0.8, 1.6, 0.8), offset = Vector3.new(0, -1, 0), color = Color3.fromRGB(70, 90, 60) },
			{ shape = Enum.PartType.Ball, size = Vector3.new(3, 2.6, 3), offset = Vector3.new(0, 0.5, 0), color = Color3.fromRGB(96, 120, 70) },
			{ shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.6, 0.4), offset = Vector3.new(-0.7, 1.1, 1.2), color = Color3.fromRGB(210, 255, 150), neon = true },
			{ shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.5, 0.4), offset = Vector3.new(0.7, 0.4, 1.2), color = Color3.fromRGB(210, 255, 150), neon = true },
			{ shape = Enum.PartType.Ball, size = Vector3.new(1, 0.8, 0.5), offset = Vector3.new(0.9, 1.3, 0.9), color = EYE },
		},
	},
	g = {
		name = "Shellguard",
		hp = 26,
		geo = 7,
		size = Vector3.new(3.6, 4.8, 3),
		flying = false,
		parts = {
			{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 4.8, 3), offset = Vector3.new(-0.2, 0, 0), color = Color3.fromRGB(70, 74, 96) },
			{ shape = Enum.PartType.Ball, size = Vector3.new(1.8, 1.8, 1.8), offset = Vector3.new(0.9, 1.6, 0.3), color = MASK },
			{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.6, 0.3), offset = Vector3.new(1.5, 1.6, 0.9), color = EYE },
			{ size = Vector3.new(0.5, 3.4, 2.4), offset = Vector3.new(1.8, -0.4, 0), color = Color3.fromRGB(150, 150, 170) },
			{ size = Vector3.new(0.3, 1.6, 0.3), offset = Vector3.new(0.6, 2.8, 0), rz = -0.5, color = MASK },
		},
	},
}

type Enemy = {
	kind: string,
	def: Kind,
	zone: number,
	home: Vector3,
	position: Vector3,
	velocity: Vector3,
	dir: number,
	hp: number,
	alive: boolean,
	respawnAt: number,
	state: string,
	timer: number,
	model: Model?,
	parts: { { part: BasePart, spec: PartSpec } },
	colors: { [BasePart]: Color3 },
}

local enemies: { Enemy } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local PlayerService

local function place(enemy: Enemy, t: number)
	for _, entry in enemy.parts do
		local spec = entry.spec
		local rz = (spec.rz or 0) * enemy.dir
		if spec.wing then
			rz += math.sin(t * 40) * 0.5
		end
		local o = spec.offset
		entry.part.CFrame = CFrame.new(enemy.position + Vector3.new(o.X * enemy.dir, o.Y, o.Z)) * CFrame.Angles(0, 0, rz)
	end
end

local function burst(position: Vector3, color: Color3, count: number)
	local holder = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position,
		Parent = workspace,
	})
	local emitter = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = holder,
	})
	emitter:Emit(count)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end
Enemies.burst = burst

local function flash(enemy: Enemy)
	for part, _ in enemy.colors do
		part.Color = Color3.new(1, 1, 1)
	end
	task.delay(0.08, function()
		for part, color in enemy.colors do
			part.Color = color
		end
	end)
end

local function blocked(from: Vector3, dir: Vector3): boolean
	return workspace:Raycast(from, dir, rayParams) ~= nil
end

local function spawnEnemy(enemy: Enemy)
	local def = enemy.def
	local model = make("Model", { Name = def.name })
	enemy.parts = {}
	enemy.colors = {}
	for _, spec in def.parts do
		local p = make("Part", {
			Shape = spec.shape or Enum.PartType.Block,
			Size = spec.size,
			Color = spec.color,
			Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Transparency = spec.transparency or 0,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CastShadow = false,
			Parent = model,
		})
		table.insert(enemy.parts, { part = p, spec = spec })
		if not spec.neon then
			enemy.colors[p] = spec.color
		end
	end
	model.PrimaryPart = enemy.parts[1].part
	enemy.model = model
	enemy.hp = def.hp
	enemy.alive = true
	enemy.state = "patrol"
	enemy.timer = 0
	enemy.velocity = Vector3.zero
	enemy.position = enemy.home
	place(enemy, os.clock())
	model.Parent = folder

	Damageable.register(model, {
		onHit = function(player: Player, damage: number, direction: Vector3)
			if not enemy.alive then
				return false
			end
			enemy.hp -= damage
			flash(enemy)
			-- Recoil away from the strike.
			local push = Vector3.new(direction.X, if def.flying then direction.Y else 0, 0) * 2
			if not blocked(enemy.position, push * 1.5) then
				enemy.position += push
			end
			if def.flying then
				enemy.velocity = Vector3.new(direction.X, direction.Y, 0) * 18
			end
			if enemy.hp <= 0 then
				enemy.alive = false
				enemy.respawnAt = os.clock() + Config.ENEMY_RESPAWN_TIME
				burst(enemy.position, Color3.fromRGB(255, 255, 255), 16)
				burst(enemy.position, Color3.fromRGB(120, 220, 255), def.geo * 3)
				PlayerService.addGeo(player, def.geo)
				model:Destroy()
				enemy.model = nil
			end
			return true
		end,
	})
end

local function nearestPlayer(position: Vector3, zone: number, range: number): (Player?, BasePart?)
	local best, bestRoot, bestDist = nil, nil, range
	for _, player in Players:GetPlayers() do
		local root = PlayerService.rootOf(player)
		if root and Grid.zoneAt(root.Position) == zone then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = player, root, d
			end
		end
	end
	return best, bestRoot
end

local function walk(enemy: Enemy, speed: number, dt: number): boolean
	local half = enemy.def.size.X / 2
	local dir = Vector3.new(enemy.dir, 0, 0)
	local ahead = enemy.position + dir * (half + 0.3)
	local wall = blocked(enemy.position, dir * (half + 0.6))
	local ground = blocked(ahead, Vector3.new(0, -(enemy.def.size.Y / 2 + 2), 0))
	if wall or not ground then
		return false
	end
	enemy.position += dir * speed * dt
	return true
end

local function update(enemy: Enemy, dt: number, now: number)
	local def = enemy.def
	if enemy.kind == "c" then
		if not walk(enemy, 6, dt) then
			enemy.dir = -enemy.dir
		end
	elseif enemy.kind == "f" then
		local _, root = nearestPlayer(enemy.position, enemy.zone, 38)
		local desired
		if root then
			desired = (root.Position + Vector3.new(0, 1.5, 0) - enemy.position).Unit * 11
		else
			local target = enemy.home + Vector3.new(math.sin(now * 0.7 + enemy.home.X) * 4, math.sin(now * 1.3) * 2, 0)
			desired = (target - enemy.position) * 1.5
		end
		enemy.velocity = enemy.velocity:Lerp(Vector3.new(desired.X, desired.Y, 0), math.min(1, dt * 2.5))
		local step = enemy.velocity * dt
		local r = def.size.X / 2
		if step.X ~= 0 and not blocked(enemy.position, Vector3.new(step.X + math.sign(step.X) * r, 0, 0)) then
			enemy.position += Vector3.new(step.X, 0, 0)
		end
		if step.Y ~= 0 and not blocked(enemy.position, Vector3.new(0, step.Y + math.sign(step.Y) * r, 0)) then
			enemy.position += Vector3.new(0, step.Y, 0)
		end
		if math.abs(enemy.velocity.X) > 0.5 then
			enemy.dir = if enemy.velocity.X > 0 then 1 else -1
		end
	elseif enemy.kind == "s" then
		local _, root = nearestPlayer(enemy.position, enemy.zone, 44)
		if root then
			enemy.dir = if root.Position.X > enemy.position.X then 1 else -1
			enemy.timer -= dt
			if enemy.timer <= 0 then
				enemy.timer = 2.6
				local from = enemy.position + Vector3.new(0, 1.2, 0)
				local aim = (root.Position - from)
				Projectiles.spawn({
					position = from,
					velocity = Vector3.new(aim.X, aim.Y, 0).Unit * 24 + Vector3.new(0, 6, 0),
					gravity = 12,
					color = Color3.fromRGB(210, 255, 150),
					radius = 0.8,
				})
			end
		else
			enemy.timer = 1
		end
	elseif enemy.kind == "g" then
		if enemy.state == "patrol" then
			if not walk(enemy, 5, dt) then
				enemy.dir = -enemy.dir
			end
			local _, root = nearestPlayer(enemy.position, enemy.zone, 26)
			if root and math.abs(root.Position.Y - enemy.position.Y) < 6 then
				enemy.dir = if root.Position.X > enemy.position.X then 1 else -1
				enemy.state = "windup"
				enemy.timer = 0.55
			end
		elseif enemy.state == "windup" then
			enemy.timer -= dt
			enemy.position += Vector3.new(math.sin(now * 80) * 0.05, 0, 0)
			if enemy.timer <= 0 then
				enemy.state = "charge"
				enemy.timer = 1.3
			end
		elseif enemy.state == "charge" then
			enemy.timer -= dt
			if not walk(enemy, 28, dt) or enemy.timer <= 0 then
				enemy.state = "rest"
				enemy.timer = 1
			end
		else
			enemy.timer -= dt
			if enemy.timer <= 0 then
				enemy.state = "patrol"
			end
		end
	end
end

function Enemies.init(infos, playerService)
	PlayerService = playerService
	folder = make("Folder", { Name = "Enemies", Parent = workspace })
	local include = {}
	for _, info in infos do
		table.insert(include, info.folder:FindFirstChild("Map"))
		table.insert(include, info.folder:FindFirstChild("Breakables"))
		for _, spawn in info.enemies do
			local def = KINDS[spawn.kind]
			local home = spawn.position
			if not def.flying then
				-- Rest on the floor of the tile the enemy was drawn in.
				home = Vector3.new(home.X, home.Y - T / 2 + def.size.Y / 2, 0)
			end
			local enemy: Enemy = {
				kind = spawn.kind,
				def = def,
				zone = spawn.zone,
				home = home,
				position = home,
				velocity = Vector3.zero,
				dir = -1,
				hp = def.hp,
				alive = false,
				respawnAt = 0,
				state = "patrol",
				timer = 0,
				model = nil,
				parts = {},
				colors = {},
			}
			table.insert(enemies, enemy)
			spawnEnemy(enemy)
		end
	end
	rayParams.FilterDescendantsInstances = include

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local activeZones = {}
		local roots = {}
		for _, player in Players:GetPlayers() do
			local root = PlayerService.rootOf(player)
			if root then
				local zone = Grid.zoneAt(root.Position)
				if zone then
					activeZones[zone] = true
					table.insert(roots, { player = player, root = root, zone = zone })
				end
			end
		end
		for _, enemy in enemies do
			if not enemy.alive then
				if now >= enemy.respawnAt and enemy.respawnAt > 0 then
					local near = false
					for _, entry in roots do
						if (entry.root.Position - enemy.home).Magnitude < 70 then
							near = true
						end
					end
					if not near then
						spawnEnemy(enemy)
					end
				end
			elseif activeZones[enemy.zone] then
				update(enemy, dt, now)
				place(enemy, now)
				local half = enemy.def.size / 2
				for _, entry in roots do
					if entry.zone == enemy.zone then
						local d = entry.root.Position - enemy.position
						if math.abs(d.X) < half.X + 0.9 and math.abs(d.Y) < half.Y + 2.4 then
							PlayerService.damage(entry.player, 1, enemy.position)
						end
					end
				end
			end
		end
	end)
end

-- Respawn every enemy immediately (used when a player rests at a bench).
function Enemies.resetAll()
	for _, enemy in enemies do
		if not enemy.alive then
			spawnEnemy(enemy)
		end
	end
end

return Enemies
