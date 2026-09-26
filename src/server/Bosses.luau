-- Boss arenas and the four guardians of Vesperdeep. Each boss is a scripted attack loop
-- built from small helpers (leap, charge, shockwave, projectile volleys).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Grid = require(Shared.Grid)
local Damageable = require(script.Parent.Damageable)
local Projectiles = require(script.Parent.Projectiles)
local Enemies = require(script.Parent.Enemies)
local Props = require(script.Parent.World.Props)

local make = Props.make
local PlayerService

local Bosses = {}

local MASK = Color3.fromRGB(232, 228, 218)

type PartSpec = {
	shape: Enum.PartType?,
	size: Vector3,
	offset: Vector3,
	rz: number?,
	color: Color3,
	neon: boolean?,
	transparency: number?,
	flap: number?,
}

type Def = {
	name: string,
	title: string,
	hp: number,
	size: Vector3,
	flying: boolean,
	reward: string?,
	geo: number,
	final: boolean?,
	parts: { PartSpec },
	run: (any) -> (),
}

local DEFS: { [string]: Def } = {}

-- ============================================================================
-- Boss definitions
-- ============================================================================

DEFS.gravelmaw = {
	name = "Gravelmaw",
	title = "The Tunneling Mother",
	hp = 130,
	size = Vector3.new(9, 5.6, 6),
	flying = false,
	reward = "dash",
	geo = 120,
	parts = {
		{ shape = Enum.PartType.Ball, size = Vector3.new(4.5, 4.4, 5), offset = Vector3.new(-3, -0.6, 0), color = Color3.fromRGB(96, 84, 74) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(5, 5.2, 5.5), offset = Vector3.new(-0.6, 0, 0), color = Color3.fromRGB(106, 92, 80) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(5, 5.6, 5.8), offset = Vector3.new(1.8, 0.2, 0), color = Color3.fromRGB(96, 84, 74) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 3.6, 3.6), offset = Vector3.new(3.8, 0.4, 0.6), color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.9, 0.3), offset = Vector3.new(4.7, 0.9, 2.2), color = Color3.fromRGB(255, 150, 60), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.8, 0.3), offset = Vector3.new(4.0, 1.1, 2.3), color = Color3.fromRGB(255, 150, 60), neon = true },
		{ size = Vector3.new(0.5, 2.2, 0.6), offset = Vector3.new(5.3, -1, 1), rz = 0.6, color = Color3.fromRGB(40, 34, 30) },
		{ size = Vector3.new(0.5, 1.6, 0.6), offset = Vector3.new(-0.6, 3, 0), rz = 0.3, color = Color3.fromRGB(150, 140, 130) },
		{ size = Vector3.new(0.5, 1.3, 0.6), offset = Vector3.new(-3, 1.8, 0), rz = 0.4, color = Color3.fromRGB(150, 140, 130) },
	},
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				-- Charge into the wall, shaking loose falling stones.
				b.faceTarget()
				b.telegraph(0.6)
				b.moveTo(if b.dir > 0 then b.maxX else b.minX, b.groundY, 32)
				b.shake(0.8)
				for _ = 1, if b.phase2() then 7 else 5 do
					b.projectile(Vector3.new(b.randomX(), b.ceilY - 1.5, 0), Vector3.new(0, -4, 0), { gravity = 70, color = Color3.fromRGB(150, 140, 130), radius = 1.1, lifetime = 3 })
					b.wait(0.12)
				end
				b.wait(b.pace(0.8))
			elseif roll == 2 then
				-- Leap onto the player and send ripples along the floor.
				b.telegraph(0.4)
				b.leap(b.targetPos().X, 16, 0.9)
				b.shake(0.5)
				b.shockwaves(28)
				b.wait(b.pace(0.7))
			else
				-- Burrow and burst up beneath the player.
				b.moveTo(b.position.X, b.floorY - b.size.Y, 14)
				b.wait(0.5)
				local x = b.clampX(b.targetPos().X)
				b.position = Vector3.new(x, b.position.Y, 0)
				b.dust(Vector3.new(x, b.floorY, 0))
				b.wait(b.pace(0.75))
				b.moveTo(x, b.groundY, 46)
				for i = -2, 2 do
					b.projectile(b.position + Vector3.new(0, 2, 0), Vector3.new(i * 7, 34, 0), { gravity = 70, color = Color3.fromRGB(150, 140, 130), radius = 0.9, lifetime = 3 })
				end
				b.wait(b.pace(0.8))
			end
		end
	end,
}

DEFS.vantis = {
	name = "Sir Vantis",
	title = "The Hollow Sentinel",
	hp = 190,
	size = Vector3.new(4, 8, 3.6),
	flying = false,
	reward = "claws",
	geo = 200,
	parts = {
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 5.6, 3.2), offset = Vector3.new(0, -0.8, 0), color = Color3.fromRGB(60, 64, 88) },
		{ size = Vector3.new(0.3, 5.4, 3), offset = Vector3.new(-1.8, -0.6, 0), color = Color3.fromRGB(120, 32, 44) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(4.6, 1.6, 3.6), offset = Vector3.new(0, 1.8, 0), color = Color3.fromRGB(150, 156, 180) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.2, 2.4, 2.2), offset = Vector3.new(0.4, 3.1, 0.3), color = MASK },
		{ size = Vector3.new(0.4, 2.4, 0.4), offset = Vector3.new(0, 4.6, 0), rz = -0.3, color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(1.1, 3.1, 1.2), color = Color3.fromRGB(150, 210, 255), neon = true },
		{ size = Vector3.new(7, 0.4, 0.4), offset = Vector3.new(3.4, 0.4, 1), color = Color3.fromRGB(205, 205, 220) },
		{ size = Vector3.new(0.6, 2.4, 0.6), offset = Vector3.new(-0.7, -3, 0.5), color = Color3.fromRGB(40, 42, 56) },
		{ size = Vector3.new(0.6, 2.4, 0.6), offset = Vector3.new(0.7, -3, 0.5), color = Color3.fromRGB(40, 42, 56) },
	},
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				b.faceTarget()
				b.telegraph(0.45)
				b.moveTo(b.clampX(b.targetPos().X + b.dir * 7), b.groundY, 50)
				if b.phase2() then
					b.shockwaves(30, b.dir)
				end
				b.wait(b.pace(0.55))
			elseif roll == 2 then
				b.telegraph(0.35)
				b.leap(b.targetPos().X, 22, 1.0)
				b.shake(0.6)
				b.shockwaves(32)
				b.wait(b.pace(0.6))
			else
				for _ = 1, 3 do
					b.faceTarget()
					b.telegraph(0.22)
					b.moveTo(b.clampX(b.position.X + b.dir * 9), b.groundY, 38)
					b.wait(0.12)
				end
				b.wait(b.pace(0.7))
			end
		end
	end,
}

local widowLegs = {}
for i = 1, 4 do
	local x = -1.8 + (i - 1) * 1.3
	table.insert(widowLegs, { size = Vector3.new(0.3, 4, 0.3), offset = Vector3.new(x, -1.6, 1.8), rz = if i % 2 == 0 then 0.6 else -0.5, color = Color3.fromRGB(28, 24, 32) })
	table.insert(widowLegs, { size = Vector3.new(0.3, 4, 0.3), offset = Vector3.new(x + 0.5, -1.6, -1.8), rz = if i % 2 == 0 then -0.5 else 0.6, color = Color3.fromRGB(22, 20, 26) })
end

DEFS.widow = {
	name = "The Thornwidow",
	title = "Weaver of Wings",
	hp = 230,
	size = Vector3.new(8, 5, 6),
	flying = false,
	reward = "wings",
	geo = 260,
	parts = table.move(widowLegs, 1, #widowLegs, 7, {
		{ shape = Enum.PartType.Ball, size = Vector3.new(5, 4.2, 5), offset = Vector3.new(-2.4, 0.8, 0), color = Color3.fromRGB(40, 36, 48) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 3, 3.8), offset = Vector3.new(0.8, 0, 0), color = Color3.fromRGB(54, 48, 60) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.2, 2.4), offset = Vector3.new(2.6, 0.3, 0.4), color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.45, 0.45, 0.3), offset = Vector3.new(3.4, 0.7, 1.5), color = Color3.fromRGB(255, 70, 90), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.35, 0.3), offset = Vector3.new(3.0, 0.1, 1.6), color = Color3.fromRGB(255, 70, 90), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1, 1, 0.4), offset = Vector3.new(-2.6, 1.6, 2.3), color = Color3.fromRGB(150, 255, 170), neon = true, transparency = 0.2 },
	}),
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				for _ = 1, if b.phase2() then 2 else 1 do
					b.faceTarget()
					b.telegraph(0.4)
					local aim = b.targetPos() - b.position
					local base = math.atan2(aim.Y, aim.X)
					for _, spread in { -0.28, 0, 0.28 } do
						local a = base + spread
						b.projectile(b.position, Vector3.new(math.cos(a), math.sin(a), 0) * 30, { color = Color3.fromRGB(235, 235, 245), radius = 0.8, lifetime = 3 })
					end
					b.wait(0.5)
				end
				b.wait(b.pace(0.5))
			elseif roll == 2 then
				-- Climb to the ceiling, stalk the player, then drop.
				local top = b.ceilY - b.size.Y / 2
				b.moveTo(b.position.X, top, 34)
				local stalk = 1.2
				while stalk > 0 do
					local dt = b.step()
					stalk -= dt
					local tx = b.clampX(b.targetPos().X)
					local x = b.position.X + math.clamp(tx - b.position.X, -22 * dt, 22 * dt)
					b.position = Vector3.new(x, top, 0)
				end
				b.telegraph(0.35)
				b.moveTo(b.position.X, b.groundY, 80)
				b.shake(0.7)
				b.shockwaves(26)
				b.wait(b.pace(0.8))
			else
				b.faceTarget()
				b.telegraph(0.35)
				b.moveTo(b.clampX(b.targetPos().X + b.dir * 4), b.groundY, 42)
				b.wait(b.pace(0.6))
			end
		end
	end,
}

DEFS.asterion = {
	name = "Asterion",
	title = "The Moth Seraph",
	hp = 340,
	size = Vector3.new(7, 7, 4),
	flying = true,
	geo = 400,
	final = true,
	parts = {
		{ size = Vector3.new(6, 5.6, 0.2), offset = Vector3.new(-3.3, 1, -0.6), rz = 0.25, color = Color3.fromRGB(250, 240, 215), transparency = 0.1, flap = 0.35 },
		{ size = Vector3.new(6, 5.6, 0.2), offset = Vector3.new(3.3, 1, -0.6), rz = -0.25, color = Color3.fromRGB(250, 240, 215), transparency = 0.1, flap = -0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.4, 0.3), offset = Vector3.new(-3.6, 1.6, -0.4), color = Color3.fromRGB(255, 200, 120), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.4, 0.3), offset = Vector3.new(3.6, 1.6, -0.4), color = Color3.fromRGB(255, 200, 120), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.6, 5, 2.4), offset = Vector3.new(0, 0, 0), color = Color3.fromRGB(228, 220, 198) },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 3.4, 0.2), offset = Vector3.new(0, 3.4, -0.9), color = Color3.fromRGB(255, 220, 150), neon = true, transparency = 0.35 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.4, 2.2), offset = Vector3.new(0, 3.3, 0.2), color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(0.5, 3.4, 1.2), color = Color3.fromRGB(255, 210, 120), neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.7, 0.3), offset = Vector3.new(-0.5, 3.4, 1.2), color = Color3.fromRGB(255, 210, 120), neon = true },
		{ size = Vector3.new(0.2, 1.8, 0.2), offset = Vector3.new(0.5, 5, 0), rz = -0.5, color = MASK },
		{ size = Vector3.new(0.2, 1.8, 0.2), offset = Vector3.new(-0.5, 5, 0), rz = 0.5, color = MASK },
	},
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				b.moveTo(b.randomX(), b.ceilY - b.rng:NextNumber(6, 10), 28)
				b.telegraph(0.5)
				local n = if b.phase2() then 14 else 9
				local offset = b.rng:NextNumber(0, math.pi)
				for i = 1, n do
					local a = offset + (i / n) * math.pi * 2
					b.projectile(b.position, Vector3.new(math.cos(a), math.sin(a), 0) * 17, { color = Color3.fromRGB(255, 220, 150), radius = 0.9, lifetime = 5, passWalls = true })
				end
				if b.phase2() then
					b.wait(0.45)
					for i = 1, n do
						local a = offset + (i + 0.5) / n * math.pi * 2
						b.projectile(b.position, Vector3.new(math.cos(a), math.sin(a), 0) * 14, { color = Color3.fromRGB(255, 240, 200), radius = 0.8, lifetime = 5, passWalls = true })
					end
				end
				b.wait(b.pace(0.8))
			elseif roll == 2 then
				-- Telegraphed dive through the player's position.
				local target = b.targetPos()
				b.faceTarget()
				b.line(b.position, target, 0.6)
				local dir = (target - b.position).Unit
				local finish = b.position + dir * ((target - b.position).Magnitude + 10)
				b.moveTo(b.clampX(finish.X), math.max(finish.Y, b.floorY + b.size.Y / 2), 72)
				b.shake(0.4)
				b.wait(0.2)
				b.moveTo(b.clampX(b.position.X), b.ceilY - 8, 30)
				b.wait(b.pace(0.5))
			else
				b.telegraph(0.4)
				for _ = 1, if b.phase2() then 16 else 10 do
					b.projectile(Vector3.new(b.randomX(), b.ceilY - 1, 0), Vector3.new(b.rng:NextNumber(-3, 3), -26, 0), { color = Color3.fromRGB(250, 240, 215), radius = 0.7, lifetime = 3, passWalls = true })
					b.wait(0.16)
				end
				b.wait(b.pace(0.6))
			end
		end
	end,
}

-- ============================================================================
-- Fight runtime
-- ============================================================================

type Fight = {
	info: any,
	def: Def,
	state: string,
	participants: { [Player]: boolean },
	boss: any?,
	stateFolder: Folder,
}

local fights: { Fight } = {}
local CANCEL = {}

local function playersInArena(info): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = PlayerService.rootOf(player)
		if root and (player:GetAttribute("Masks") or 0) > 0 then
			local p = root.Position
			if p.X >= info.triggerX and p.X <= info.maxX and p.Y >= info.floorY - 6 and p.Y <= info.ceilY + 6 then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function setGates(fight: Fight, closed: boolean)
	for _, gate in fight.info.gates do
		Props.setGate(gate, closed)
	end
end

local function buildModel(def: Def)
	local model = make("Model", { Name = def.name })
	local parts = {}
	local colors = {}
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
		table.insert(parts, { part = p, spec = spec })
		if not spec.neon then
			colors[p] = spec.color
		end
	end
	model.PrimaryPart = parts[1].part
	return model, parts, colors
end

local function endFight(fight: Fight, victory: boolean)
	local boss = fight.boss
	if boss then
		boss.cancelled = true
		if boss.model then
			boss.model:Destroy()
		end
		fight.boss = nil
	end
	Projectiles.clear()
	setGates(fight, false)
	fight.stateFolder:SetAttribute("Active", false)
	fight.state = "cooldown"
	if victory then
		for player in fight.participants do
			if player.Parent then
				PlayerService.markBoss(player, fight.info.id, fight.def.final == true)
				PlayerService.addGeo(player, fight.def.geo)
				if fight.def.reward then
					PlayerService.grantAbility(player, fight.def.reward)
				elseif fight.def.final then
					PlayerService.notify(player, "The Seraph Rests", "Kindle the Great Lamp at the altar beyond.", "ability")
				end
			end
		end
	end
	fight.participants = {}
	task.delay(4, function()
		fight.state = "idle"
	end)
end

local function startFight(fight: Fight, players: { Player })
	local info, def = fight.info, fight.def
	fight.state = "fighting"
	fight.participants = {}
	for _, p in players do
		fight.participants[p] = true
		Net.event("AreaTitle"):FireClient(p, def.name, def.title, "boss")
	end
	setGates(fight, true)

	local model, parts, colors = buildModel(def)
	local rng = Random.new()
	local b: any = {
		rng = rng,
		model = model,
		parts = parts,
		colors = colors,
		size = def.size,
		minX = info.minX + def.size.X / 2,
		maxX = info.maxX - def.size.X / 2,
		floorY = info.floorY,
		ceilY = info.ceilY,
		groundY = info.floorY + def.size.Y / 2,
		dir = -1,
		hp = def.hp,
		cancelled = false,
		telegraphing = false,
	}
	b.position = if def.flying then Vector3.new(info.position.X, info.position.Y, 0) else Vector3.new(info.position.X, b.groundY, 0)
	fight.boss = b

	function b.step(): number
		local dt = RunService.Heartbeat:Wait()
		if b.cancelled then
			error(CANCEL)
		end
		return dt
	end
	function b.wait(t: number)
		local elapsed = 0
		while elapsed < t do
			elapsed += b.step()
		end
	end
	function b.phase2(): boolean
		return b.hp <= def.hp / 2
	end
	function b.pace(t: number): number
		return if b.phase2() then t * 0.65 else t
	end
	function b.clampX(x: number): number
		return math.clamp(x, b.minX, b.maxX)
	end
	function b.randomX(): number
		return rng:NextNumber(b.minX, b.maxX)
	end
	function b.targetPos(): Vector3
		local best, bestD = nil, math.huge
		for player in fight.participants do
			local root = PlayerService.rootOf(player)
			if root then
				local d = (root.Position - b.position).Magnitude
				if d < bestD then
					best, bestD = root.Position, d
				end
			end
		end
		return best or Vector3.new((b.minX + b.maxX) / 2, b.groundY, 0)
	end
	function b.faceTarget()
		b.dir = if b.targetPos().X >= b.position.X then 1 else -1
	end
	function b.moveTo(x: number, y: number, speed: number)
		local target = Vector3.new(x, y, 0)
		if target.X ~= b.position.X then
			b.dir = if target.X > b.position.X then 1 else -1
		end
		while (target - b.position).Magnitude > 0.05 do
			local dt = b.step()
			local delta = target - b.position
			local stepLen = speed * dt
			if delta.Magnitude <= stepLen then
				b.position = target
			else
				b.position += delta.Unit * stepLen
			end
		end
	end
	function b.leap(targetX: number, height: number, duration: number)
		local fromPos = b.position
		local toX = b.clampX(targetX)
		b.dir = if toX >= fromPos.X then 1 else -1
		local t = 0
		while t < duration do
			t += b.step()
			local a = math.min(1, t / duration)
			local x = fromPos.X + (toX - fromPos.X) * a
			local y = fromPos.Y + (b.groundY - fromPos.Y) * a + math.sin(a * math.pi) * height
			b.position = Vector3.new(x, y, 0)
		end
		b.position = Vector3.new(toX, b.groundY, 0)
	end
	function b.telegraph(t: number)
		b.telegraphing = true
		local base = b.position
		local elapsed = 0
		while elapsed < t do
			elapsed += b.step()
			b.position = base + Vector3.new(math.sin(elapsed * 70) * 0.18, 0, 0)
		end
		b.position = base
		b.telegraphing = false
	end
	function b.shake(intensity: number)
		for player in fight.participants do
			Net.event("CameraShake"):FireClient(player, intensity)
		end
	end
	function b.projectile(position: Vector3, velocity: Vector3, opts)
		opts = opts or {}
		Projectiles.spawn({
			position = position,
			velocity = velocity,
			color = opts.color,
			radius = opts.radius,
			gravity = opts.gravity,
			lifetime = opts.lifetime,
			passWalls = opts.passWalls,
		})
	end
	function b.shockwaves(speed: number, onlyDir: number?)
		for _, d in { -1, 1 } do
			if not onlyDir or onlyDir == d then
				Projectiles.spawn({
					position = Vector3.new(b.position.X + d * b.size.X / 2, b.floorY + 1.1, 0),
					velocity = Vector3.new(d * speed, 0, 0),
					color = Color3.fromRGB(255, 255, 255),
					radius = 1.1,
					lifetime = 2.2,
				})
			end
		end
	end
	function b.dust(at: Vector3)
		Enemies.burst(at + Vector3.new(0, 0.5, 0), Color3.fromRGB(180, 170, 150), 24)
	end
	function b.line(from: Vector3, to: Vector3, t: number)
		local mid = (from + to) / 2
		local beam = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 220, 150),
			Transparency = 0.6,
			Size = Vector3.new(0.3, 0.3, (to - from).Magnitude),
			CFrame = CFrame.lookAt(mid, to),
			Parent = workspace,
		})
		local ok, err = pcall(b.telegraph, t)
		beam:Destroy()
		if not ok then
			error(err)
		end
	end

	fight.stateFolder:SetAttribute("Health", b.hp)
	fight.stateFolder:SetAttribute("MaxHealth", def.hp)
	fight.stateFolder:SetAttribute("Active", true)
	model.Parent = workspace:FindFirstChild("Enemies")

	Damageable.register(model, {
		onHit = function(_player: Player, damage: number)
			if b.cancelled or b.hp <= 0 then
				return false
			end
			b.hp -= damage
			fight.stateFolder:SetAttribute("Health", math.max(0, b.hp))
			for p in colors do
				p.Color = Color3.new(1, 1, 1)
			end
			task.delay(0.07, function()
				for p, c in colors do
					p.Color = c
				end
			end)
			if b.hp <= 0 then
				Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 60)
				Enemies.burst(b.position, Color3.fromRGB(120, 220, 255), 40)
				b.shake(1)
				for player in fight.participants do
					Net.event("AreaTitle"):FireClient(player, def.name, "has fallen", "victory")
				end
				endFight(fight, true)
			end
			return true
		end,
	})

	task.spawn(function()
		local ok, err = pcall(function()
			b.wait(1.2)
			def.run(b)
		end)
		if not ok and err ~= CANCEL then
			warn("[Vesperdeep] Boss error:", err)
		end
	end)
end

local function placeBoss(b, now: number)
	for _, entry in b.parts do
		local spec = entry.spec
		local o = spec.offset
		local rz = (spec.rz or 0) * b.dir
		if spec.flap then
			rz += math.sin(now * 9) * spec.flap
		end
		entry.part.CFrame = CFrame.new(b.position + Vector3.new(o.X * b.dir, o.Y, o.Z)) * CFrame.Angles(0, 0, rz)
	end
end

function Bosses.init(infos, playerService)
	PlayerService = playerService
	local stateRoot = make("Folder", { Name = "BossState", Parent = ReplicatedStorage })
	for _, info in infos do
		local bossInfo = info.boss
		if bossInfo then
			local def = DEFS[bossInfo.id]
			local stateFolder = make("Folder", { Name = bossInfo.id, Parent = stateRoot })
			stateFolder:SetAttribute("Name", def.name)
			stateFolder:SetAttribute("Zone", bossInfo.zone)
			stateFolder:SetAttribute("Active", false)
			table.insert(fights, {
				info = bossInfo,
				def = def,
				state = "idle",
				participants = {},
				boss = nil,
				stateFolder = stateFolder,
			})
		end
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fight in fights do
			if fight.state == "idle" then
				local inside = playersInArena(fight.info)
				local challengers = {}
				for _, player in inside do
					if not PlayerService.hasDefeated(player, fight.info.id) then
						table.insert(challengers, player)
					end
				end
				if #challengers > 0 then
					startFight(fight, inside)
				end
			elseif fight.state == "fighting" and fight.boss then
				local b = fight.boss
				for _, player in playersInArena(fight.info) do
					fight.participants[player] = true
				end
				local anyone = false
				for player in fight.participants do
					local root = PlayerService.rootOf(player)
					local alive = player.Parent ~= nil and root ~= nil and (player:GetAttribute("Masks") or 0) > 0
					if alive and root and Grid.zoneAt(root.Position) == fight.info.zone then
						anyone = true
						local d = root.Position - b.position
						if math.abs(d.X) < b.size.X / 2 + 0.9 and math.abs(d.Y) < b.size.Y / 2 + 2.4 then
							PlayerService.damage(player, 1, b.position)
						end
					else
						fight.participants[player] = nil
					end
				end
				if not anyone then
					endFight(fight, false)
				else
					placeBoss(b, now)
				end
			end
		end
	end)
end

return Bosses
