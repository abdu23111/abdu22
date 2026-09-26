-- Regular enemies and their AI. On the server each enemy is an invisible hitbox part that
-- moves around the cave; its model carries attributes (Rig, Anim, Warn, HitAt) that every
-- client uses to draw and animate the creature's rig. Enemies only think while a player is
-- in their zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Rig = require(Shared.Rig)
local Damageable = require(script.Parent.Damageable)
local Projectiles = require(script.Parent.Projectiles)
local Props = require(script.Parent.World.Props)

local T = Config.TILE
local make = Props.make

local Enemies = {}

type Kind = {
	name: string,
	rig: string,
	hp: number,
	geo: number,
	size: Vector3, -- hitbox (length along facing, height, width)
	behavior: string,
	speed: number,
}

local KINDS: { [string]: Kind } = {
	c = { name = "Husk Mite", rig = "mite", hp = 10, geo = 2, size = Vector3.new(3.4, 2.4, 2.6), behavior = "crawler", speed = 6 },
	m = { name = "Crystal Mite", rig = "crystal_mite", hp = 16, geo = 4, size = Vector3.new(3.4, 2.6, 2.6), behavior = "crawler", speed = 8 },
	f = { name = "Gloom Gnat", rig = "gnat", hp = 8, geo = 3, size = Vector3.new(2.4, 2.2, 2.2), behavior = "flyer", speed = 11 },
	w = { name = "Ink Wisp", rig = "wisp", hp = 12, geo = 5, size = Vector3.new(2.4, 2.8, 2.2), behavior = "shooter", speed = 9 },
	s = { name = "Spore Bulb", rig = "bulb", hp = 14, geo = 4, size = Vector3.new(3, 3.4, 3), behavior = "spitter", speed = 0 },
	g = { name = "Shellguard", rig = "shellguard", hp = 26, geo = 7, size = Vector3.new(3.6, 4.8, 3), behavior = "charger", speed = 5 },
	h = { name = "Hollow Hopper", rig = "hopper", hp = 18, geo = 5, size = Vector3.new(3, 3.4, 2.6), behavior = "hopper", speed = 0 },
}

type Enemy = {
	kind: string,
	def: Kind,
	zone: number,
	home: Vector3,
	position: Vector3,
	velocity: Vector3,
	dir: Vector3,
	hp: number,
	alive: boolean,
	respawnAt: number,
	state: string,
	timer: number,
	anim: string,
	warning: boolean,
	model: Model?,
	hitbox: BasePart?,
	wander: number,
}

local enemies: { Enemy } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local PlayerService

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zero
end

local function setAnim(enemy: Enemy, anim: string, restart: boolean?)
	if enemy.model and (enemy.anim ~= anim or restart) then
		enemy.anim = anim
		enemy.model:SetAttribute("Anim", anim)
		enemy.model:SetAttribute("AnimAt", os.clock())
	end
end

local function setWarning(enemy: Enemy, on: boolean)
	if enemy.warning ~= on and enemy.model then
		enemy.warning = on
		enemy.model:SetAttribute("Warn", on)
	end
end

local function place(enemy: Enemy)
	if enemy.hitbox then
		enemy.hitbox.CFrame = Rig.frame(enemy.position, enemy.dir)
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

local function blocked(from: Vector3, dir: Vector3): RaycastResult?
	return workspace:Raycast(from, dir, rayParams)
end

local function spawnEnemy(enemy: Enemy)
	local def = enemy.def
	local model = make("Model", { Name = def.name })
	local hitbox = make("Part", {
		Name = "Hitbox",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		Transparency = 1,
		Size = def.size,
		Parent = model,
	})
	model.PrimaryPart = hitbox
	model:SetAttribute("Rig", def.rig)
	model:SetAttribute("Anim", "idle")
	-- Distance from the hitbox centre down to the rig's origin (flyers are centred on their body).
	model:SetAttribute("Anchor", if def.behavior == "flyer" or def.behavior == "shooter" then 0 else def.size.Y / 2)
	enemy.model = model
	enemy.hitbox = hitbox
	enemy.hp = def.hp
	enemy.alive = true
	enemy.state = "patrol"
	enemy.timer = 0
	enemy.anim = "idle"
	enemy.warning = false
	enemy.velocity = Vector3.zero
	enemy.position = enemy.home
	place(enemy)
	model.Parent = folder

	Damageable.register(model, {
		onHit = function(player: Player, damage: number, direction: Vector3)
			if not enemy.alive then
				return false
			end
			enemy.hp -= damage
			model:SetAttribute("HitAt", os.clock())
			local flying = def.behavior == "flyer" or def.behavior == "shooter"
			-- Recoil away from the strike.
			local push = (if flying then direction else flat(direction)) * 2
			if not blocked(enemy.position, push * 1.5) then
				enemy.position += push
			end
			if flying then
				enemy.velocity = direction * 18
			end
			if enemy.hp <= 0 then
				enemy.alive = false
				enemy.respawnAt = os.clock() + Config.ENEMY_RESPAWN_TIME
				model:SetAttribute("Dead", true)
				PlayerService.enemyGeo(player, def.geo)
				-- Give clients a moment to play the defeat before the model is removed.
				task.delay(0.05, function()
					model:Destroy()
				end)
				enemy.model = nil
				enemy.hitbox = nil
			else
				setAnim(enemy, "hurt", true)
				task.delay(0.25, function()
					if enemy.alive and enemy.anim == "hurt" then
						setAnim(enemy, "idle")
					end
				end)
			end
			return true
		end,
	})
end

local function nearestPlayer(position: Vector3, zone: number, range: number): (Player?, BasePart?)
	local best, bestRoot, bestDist = nil, nil, range
	for _, player in Players:GetPlayers() do
		local root = PlayerService.rootOf(player)
		if root and Grid.zoneAt(root.Position) == zone and (player:GetAttribute("Masks") or 0) > 0 then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = player, root, d
			end
		end
	end
	return best, bestRoot
end

-- Step along `dir` on the ground, refusing to walk into walls or off ledges.
local function walk(enemy: Enemy, dir: Vector3, speed: number, dt: number): boolean
	if dir.Magnitude < 1e-3 then
		return false
	end
	local half = enemy.def.size.X / 2
	local ahead = enemy.position + dir * (half + 0.4)
	local wall = blocked(enemy.position, dir * (half + 0.8))
	local ground = blocked(ahead, Vector3.new(0, -(enemy.def.size.Y / 2 + 2.2), 0))
	if wall or not ground then
		return false
	end
	enemy.position += dir * speed * dt
	enemy.dir = dir
	return true
end

-- Fly toward a desired velocity while sliding along walls.
local function fly(enemy: Enemy, desired: Vector3, dt: number)
	enemy.velocity = enemy.velocity:Lerp(desired, math.min(1, dt * 2.5))
	local step = enemy.velocity * dt
	local r = enemy.def.size.X / 2
	for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		local s = axis * step:Dot(axis)
		if s.Magnitude > 1e-4 and not blocked(enemy.position, s + s.Unit * r) then
			enemy.position += s
		end
	end
	local f = flat(enemy.velocity)
	if f.Magnitude > 0 and Vector3.new(enemy.velocity.X, 0, enemy.velocity.Z).Magnitude > 0.5 then
		enemy.dir = f
	end
end

local function update(enemy: Enemy, dt: number, now: number)
	local def = enemy.def
	local behavior = def.behavior
	if behavior == "crawler" then
		local _, root = nearestPlayer(enemy.position, enemy.zone, 18)
		local chasing = root and math.abs(root.Position.Y - enemy.position.Y) < 5
		local dir = if chasing and root then flat(root.Position - enemy.position) else enemy.dir
		if not walk(enemy, dir, def.speed * (if chasing then 1.4 else 1), dt) then
			if chasing then
				setAnim(enemy, "idle")
			else
				-- Turn around (with a little variety) at walls and ledges.
				local a = math.pi + (math.random() - 0.5) * 1.2
				enemy.dir = Vector3.new(enemy.dir.X * math.cos(a) - enemy.dir.Z * math.sin(a), 0, enemy.dir.X * math.sin(a) + enemy.dir.Z * math.cos(a)).Unit
			end
		else
			setAnim(enemy, "move")
		end
	elseif behavior == "flyer" then
		local _, root = nearestPlayer(enemy.position, enemy.zone, 38)
		local desired
		if root then
			desired = (root.Position + Vector3.new(0, 1.5, 0) - enemy.position).Unit * def.speed
			setAnim(enemy, "move")
		else
			local target = enemy.home + Vector3.new(math.sin(now * 0.7 + enemy.wander) * 5, math.sin(now * 1.3) * 2, math.cos(now * 0.5 + enemy.wander) * 5)
			desired = (target - enemy.position) * 1.5
			setAnim(enemy, "idle")
		end
		fly(enemy, desired, dt)
	elseif behavior == "shooter" then
		-- Keeps its distance, then spits a glob of ink after a visible wind-up.
		local _, root = nearestPlayer(enemy.position, enemy.zone, 42)
		local desired = (enemy.home + Vector3.new(0, math.sin(now * 1.1) * 2, 0) - enemy.position) * 1.2
		if root then
			local away = enemy.position - root.Position
			local dist = away.Magnitude
			local ideal = root.Position + away.Unit * 16 + Vector3.new(0, 4, 0)
			desired = (ideal - enemy.position) * (if dist < 12 then 2.5 else 1.2)
			enemy.timer -= dt
			if enemy.timer <= 0.5 and not enemy.warning then
				setWarning(enemy, true)
				setAnim(enemy, "windup")
			end
			if enemy.timer <= 0 then
				setWarning(enemy, false)
				setAnim(enemy, "attack", true)
				enemy.timer = 2.4
				local aim = root.Position - enemy.position
				Projectiles.spawn({ position = enemy.position, velocity = aim.Unit * 30, color = Color3.fromRGB(40, 90, 96), radius = 0.8, lifetime = 3 })
			elseif not enemy.warning then
				setAnim(enemy, "move")
			end
		else
			enemy.timer = 1.2
			setWarning(enemy, false)
			setAnim(enemy, "idle")
		end
		fly(enemy, desired, dt)
		if root then
			enemy.dir = flat(root.Position - enemy.position)
		end
	elseif behavior == "spitter" then
		local _, root = nearestPlayer(enemy.position, enemy.zone, 44)
		if root then
			enemy.dir = flat(root.Position - enemy.position)
			enemy.timer -= dt
			if enemy.timer <= 0.45 and not enemy.warning then
				setWarning(enemy, true)
				setAnim(enemy, "windup")
			end
			if enemy.timer <= 0 then
				setWarning(enemy, false)
				setAnim(enemy, "attack", true)
				enemy.timer = 2.6
				local from = enemy.position + Vector3.new(0, 1.2, 0)
				local aim = root.Position - from
				Projectiles.spawn({ position = from, velocity = aim.Unit * 24 + Vector3.new(0, 6, 0), gravity = 12, color = Color3.fromRGB(210, 255, 150), radius = 0.8 })
			end
		else
			enemy.timer = 1
			setWarning(enemy, false)
			setAnim(enemy, "idle")
		end
	elseif behavior == "charger" then
		if enemy.state == "patrol" then
			if walk(enemy, enemy.dir, def.speed, dt) then
				setAnim(enemy, "move")
			else
				enemy.dir = -enemy.dir
			end
			local _, root = nearestPlayer(enemy.position, enemy.zone, 26)
			if root and math.abs(root.Position.Y - enemy.position.Y) < 6 then
				enemy.dir = flat(root.Position - enemy.position)
				enemy.state = "windup"
				enemy.timer = 0.6
				setWarning(enemy, true)
				setAnim(enemy, "windup")
			end
		elseif enemy.state == "windup" then
			enemy.timer -= dt
			if enemy.timer <= 0 then
				setWarning(enemy, false)
				setAnim(enemy, "attack")
				enemy.state = "charge"
				enemy.timer = 1.3
			end
		elseif enemy.state == "charge" then
			enemy.timer -= dt
			if not walk(enemy, enemy.dir, 28, dt) or enemy.timer <= 0 then
				enemy.state = "rest"
				enemy.timer = 1
				setAnim(enemy, "idle")
			end
		else
			enemy.timer -= dt
			if enemy.timer <= 0 then
				enemy.state = "patrol"
			end
		end
	elseif behavior == "hopper" then
		local half = def.size.Y / 2
		if enemy.state == "air" then
			enemy.velocity += Vector3.new(0, -120 * dt, 0)
			local step = enemy.velocity * dt
			local horizontal = Vector3.new(step.X, 0, step.Z)
			if horizontal.Magnitude > 0 and blocked(enemy.position, horizontal + horizontal.Unit * def.size.X / 2) then
				enemy.velocity = Vector3.new(0, enemy.velocity.Y, 0)
				step = Vector3.new(0, step.Y, 0)
			end
			if step.Y < 0 then
				local hit = blocked(enemy.position, Vector3.new(0, step.Y - half, 0))
				if hit then
					enemy.position = Vector3.new(enemy.position.X + step.X, hit.Position.Y + half, enemy.position.Z + step.Z)
					enemy.velocity = Vector3.zero
					enemy.state = "patrol"
					enemy.timer = 0.7
					setAnim(enemy, "idle")
					return
				end
			elseif blocked(enemy.position, Vector3.new(0, step.Y + half, 0)) then
				enemy.velocity = Vector3.new(enemy.velocity.X, 0, enemy.velocity.Z)
				step = Vector3.new(step.X, 0, step.Z)
			end
			enemy.position += step
		else
			enemy.timer -= dt
			local _, root = nearestPlayer(enemy.position, enemy.zone, 30)
			if root then
				enemy.dir = flat(root.Position - enemy.position)
			end
			if enemy.timer <= 0.35 and root and not enemy.warning then
				setWarning(enemy, true)
				setAnim(enemy, "windup")
			end
			if enemy.timer <= 0 then
				setWarning(enemy, false)
				local reach = Vector3.zero
				if root then
					local d = root.Position - enemy.position
					reach = Vector3.new(d.X, 0, d.Z) * 1.1
					if reach.Magnitude > 26 then
						reach = reach.Unit * 26
					end
				elseif (enemy.position - enemy.home).Magnitude > 12 then
					reach = flat(enemy.home - enemy.position) * 8
				else
					reach = enemy.dir * 6
				end
				enemy.velocity = Vector3.new(reach.X, 42, reach.Z)
				enemy.state = "air"
				setAnim(enemy, "attack")
				enemy.timer = 1.2
			end
		end
	end
end

function Enemies.init(infos, playerService)
	PlayerService = playerService
	folder = make("Folder", { Name = "Enemies", Parent = workspace })
	local include = { workspace.Terrain }
	for _, info in infos do
		table.insert(include, info.folder:FindFirstChild("Map"))
		table.insert(include, info.folder:FindFirstChild("Breakables"))
		for i, spawn in info.enemies do
			local def = KINDS[spawn.kind]
			local home = spawn.position
			if def.behavior ~= "flyer" and def.behavior ~= "shooter" then
				-- Rest on the floor of the tile the enemy was drawn in.
				home = Vector3.new(home.X, home.Y - T / 2 + def.size.Y / 2, home.Z)
			end
			local angle = (i * 2.39) % (math.pi * 2)
			local enemy: Enemy = {
				kind = spawn.kind,
				def = def,
				zone = spawn.zone,
				home = home,
				position = home,
				velocity = Vector3.zero,
				dir = Vector3.new(math.cos(angle), 0, math.sin(angle) * 0.4).Unit,
				hp = def.hp,
				alive = false,
				respawnAt = 0,
				state = "patrol",
				timer = 0,
				anim = "idle",
				warning = false,
				model = nil,
				hitbox = nil,
				wander = i * 1.7,
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
				place(enemy)
				local hitbox = enemy.hitbox
				if hitbox then
					local half = enemy.def.size / 2
					for _, entry in roots do
						if entry.zone == enemy.zone then
							local p = hitbox.CFrame:PointToObjectSpace(entry.root.Position)
							if math.abs(p.X) < half.X + 0.9 and math.abs(p.Z) < half.Z + 0.9 and math.abs(p.Y) < half.Y + 2.4 then
								PlayerService.damage(entry.player, 1, enemy.position)
							end
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
