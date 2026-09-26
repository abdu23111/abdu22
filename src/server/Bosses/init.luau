-- Boss arenas and the fight runtime. Each boss lives in Bosses/Defs as a data table plus a
-- scripted attack loop built from the helpers below. On the server a boss is an invisible
-- hitbox; its model's attributes (Rig, Anim, Warn, HitAt) let every client draw and animate
-- the boss's rig. The runtime adds:
--   * cinematic introductions (gates slam, camera orbits the boss, title card, a roar)
--   * phases at health thresholds, each opening with a stagger and roar
--   * readable warnings: bosses glow hot and wind up; hazards are marked on the floor first
--   * a death sequence before rewards are handed out

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Grid = require(Shared.Grid)
local Rig = require(Shared.Rig)
local Damageable = require(script.Parent.Damageable)
local Projectiles = require(script.Parent.Projectiles)
local Enemies = require(script.Parent.Enemies)
local Props = require(script.Parent.World.Props)

local make = Props.make
local PlayerService

local Bosses = {}

local WARN = Color3.fromRGB(255, 170, 90)
local CANCEL = {}

local DEFS: { [string]: any } = {}
for _, module in script:WaitForChild("Defs"):GetChildren() do
	if module:IsA("ModuleScript") then
		DEFS[module.Name] = require(module) :: any
	end
end

type Hazard = { cf: CFrame, size: Vector3, expires: number }

type Fight = {
	info: any,
	def: any,
	state: string, -- idle | intro | fighting | dying | cooldown
	participants: { [Player]: boolean },
	boss: any?,
	hazards: { Hazard },
	temp: { Instance },
	stateFolder: Folder,
	trial: boolean?, -- the Hall of Trials arena: fights start from the statue, any boss
	rigId: string?, -- which boss is being fought in a trial
	rematch: boolean?, -- a story boss fought again (no rewards)
}

local fights: { Fight } = {}

local function flat(v: Vector3): Vector3
	if Config.SIDE_VIEW then
		return if math.abs(v.X) > 1e-4 then Vector3.new(math.sign(v.X), 0, 0) else Vector3.zero
	end
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.zero
end

local function arenaPlayers(info): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = PlayerService.rootOf(player)
		if root and (player:GetAttribute("Masks") or 0) > 0 then
			local p = root.Position
			if p.X >= info.minX + 6 and p.X <= info.maxX - 6 and p.Y >= info.floorY - 6 and p.Y <= info.ceilY + 6 then
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

local function cleanup(fight: Fight)
	for _, inst in fight.temp do
		if inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(fight.temp)
	table.clear(fight.hazards)
	Projectiles.clear()
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
	cleanup(fight)
	setGates(fight, false)
	fight.stateFolder:SetAttribute("Active", false)
	fight.state = "cooldown"
	if victory and fight.trial then
		local def, id = fight.def, fight.rigId :: string
		for player in fight.participants do
			if player.Parent then
				if fight.rematch then
					PlayerService.addGeo(player, 25)
					PlayerService.notify(player, "Trial Won", def.name .. " is beaten again.", "info")
				elseif not PlayerService.hasDefeated(player, "trial_" .. id) then
					PlayerService.markBoss(player, "trial_" .. id, false)
					PlayerService.addGeo(player, def.geo)
					if def.reward then
						PlayerService.grantAbility(player, def.reward)
					else
						PlayerService.notify(player, "Champion Defeated", "A new challenger waits at the statue.", "ability")
					end
				else
					PlayerService.addGeo(player, 25)
				end
			end
		end
	elseif victory then
		local def = fight.def
		for player in fight.participants do
			if player.Parent then
				PlayerService.markBoss(player, fight.info.id, def.final == true)
				PlayerService.addGeo(player, def.geo)
				if def.reward then
					PlayerService.grantAbility(player, def.reward)
				elseif def.final then
					PlayerService.notify(player, "The Seraph Rests", "Kindle the Great Lamp at the altar beyond.", "ability")
				elseif fight.info.id == "echo" then
					PlayerService.notify(player, "The Echo Is Quiet", "Those who turned back are at peace. Carry them to the lamp.", "ability")
				end
			end
		end
	end
	fight.participants = {}
	task.delay(4, function()
		fight.state = "idle"
	end)
end

-- ============================================================================
-- Boss helpers (the `b` table handed to each boss's run function)
-- ============================================================================

local function createBoss(fight: Fight)
	local info, def = fight.info, fight.def
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
	model:SetAttribute("Rig", fight.rigId or fight.info.id)
	model:SetAttribute("Anim", "idle")
	model:SetAttribute("Anchor", def.size.Y / 2)
	model:SetAttribute("Boss", true)

	local rng = Random.new()
	local half = math.max(def.size.X, def.size.Z) / 2
	local b: any = {
		rng = rng,
		model = model,
		hitbox = hitbox,
		size = def.size,
		minX = info.minX + half,
		maxX = info.maxX - half,
		minZ = if Config.SIDE_VIEW then 0 else -info.zHalf + half,
		maxZ = if Config.SIDE_VIEW then 0 else info.zHalf - half,
		floorY = info.floorY,
		ceilY = info.ceilY,
		groundY = info.floorY + def.size.Y / 2,
		facing = Vector3.new(-1, 0, 0),
		hp = def.hp,
		phase = 1,
		pendingPhase = nil,
		staggering = false,
		cancelled = false,
		warning = false,
		hidden = false,
		anim = "idle",
	}
	b.position = if def.flying then Vector3.new(info.position.X, info.position.Y, 0) else Vector3.new(info.position.X, b.groundY, 0)

	local function temp(inst: Instance, lifetime: number?): Instance
		table.insert(fight.temp, inst)
		if lifetime then
			task.delay(lifetime, function()
				if inst.Parent then
					inst:Destroy()
				end
			end)
		end
		return inst
	end

	function b.setAnim(anim: string, restart: boolean?)
		if b.anim ~= anim or restart then
			b.anim = anim
			model:SetAttribute("Anim", anim)
			model:SetAttribute("AnimAt", os.clock())
		end
	end

	local function setWarn(on: boolean)
		b.warning = on
		model:SetAttribute("Warn", on)
	end

	local function rawWait(t: number)
		local elapsed = 0
		while elapsed < t do
			elapsed += RunService.Heartbeat:Wait()
			if b.cancelled then
				error(CANCEL)
			end
		end
	end
	b.rawWait = rawWait

	local function stagger(phase: number)
		b.staggering = true
		b.setAnim("stagger", true)
		rawWait(1.1)
		b.shake(1)
		Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 30)
		if def.onPhase then
			def.onPhase(b, phase)
		end
		b.staggering = false
		b.setAnim("idle")
	end

	function b.step(): number
		local dt = RunService.Heartbeat:Wait()
		if b.cancelled then
			error(CANCEL)
		end
		if b.pendingPhase and not b.staggering then
			local p = b.pendingPhase
			b.pendingPhase = nil
			stagger(p)
		end
		return dt
	end
	function b.wait(t: number, anim: string?)
		if anim then
			b.setAnim(anim)
		end
		local elapsed = 0
		while elapsed < t do
			elapsed += b.step()
		end
	end
	-- Pause between attacks, idling.
	function b.rest(t: number)
		b.wait(b.pace(t), "idle")
	end
	function b.phase2(): boolean
		return b.phase >= 2
	end
	-- Later phases shorten the pauses between attacks.
	function b.pace(t: number): number
		return t * (1 - 0.18 * (b.phase - 1))
	end
	function b.clamp(p: Vector3): Vector3
		return Vector3.new(math.clamp(p.X, b.minX, b.maxX), p.Y, math.clamp(p.Z, b.minZ, b.maxZ))
	end
	function b.randomPoint(y: number?): Vector3
		return Vector3.new(rng:NextNumber(b.minX, b.maxX), y or b.groundY, rng:NextNumber(b.minZ, b.maxZ))
	end
	function b.center(): Vector3
		return Vector3.new((b.minX + b.maxX) / 2, b.groundY, (b.minZ + b.maxZ) / 2)
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
		return best or b.center()
	end
	-- Where the player stands, projected onto the floor.
	function b.targetGround(): Vector3
		local t = b.targetPos()
		return Vector3.new(t.X, b.groundY, t.Z)
	end
	function b.faceTarget()
		local d = flat(b.targetPos() - b.position)
		if d.Magnitude > 0 then
			b.facing = d
		end
	end
	function b.moveTo(target: Vector3, speed: number, anim: string?)
		target = b.clamp(target)
		local dir = flat(target - b.position)
		if dir.Magnitude > 0 then
			b.facing = dir
		end
		b.setAnim(anim or (if speed >= 40 then "attack" else "move"))
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
	function b.leap(target: Vector3, height: number, duration: number)
		local fromPos = b.position
		local to = b.clamp(Vector3.new(target.X, b.groundY, target.Z))
		local dir = flat(to - fromPos)
		if dir.Magnitude > 0 then
			b.facing = dir
		end
		b.setAnim("leap")
		local t = 0
		while t < duration do
			t += b.step()
			local a = math.min(1, t / duration)
			local p = fromPos:Lerp(to, a)
			b.position = Vector3.new(p.X, fromPos.Y + (to.Y - fromPos.Y) * a + math.sin(a * math.pi) * height, p.Z)
		end
		b.position = to
		b.setAnim("slam", true)
	end
	-- Wind-up: the boss glows hot and coils, so every attack can be read in advance.
	function b.telegraph(t: number)
		setWarn(true)
		b.setAnim("windup")
		local ok, err = pcall(function()
			local elapsed = 0
			while elapsed < t do
				elapsed += b.step()
			end
		end)
		setWarn(false)
		if not ok then
			error(err)
		end
	end
	function b.shake(intensity: number)
		for player in fight.participants do
			Net.event("CameraShake"):FireClient(player, intensity)
		end
	end
	function b.projectile(position: Vector3, velocity: Vector3, opts)
		opts = opts or {}
		if not opts.quiet then
			b.setAnim("shoot", true)
		end
		Projectiles.spawn({
			position = position,
			velocity = velocity,
			color = opts.color,
			radius = opts.radius,
			gravity = opts.gravity,
			lifetime = opts.lifetime,
			passWalls = opts.passWalls,
			accel = opts.accel,
			homing = opts.homing,
			damage = opts.damage,
		})
	end
	-- Fire `count` projectiles fanned horizontally around `dir`.
	-- Rotate a direction by `a` radians within the play plane (vertical plane in side view).
	function b.rotate(dir: Vector3, a: number): Vector3
		if Config.SIDE_VIEW then
			return Vector3.new(dir.X * math.cos(a) - dir.Y * math.sin(a), dir.X * math.sin(a) + dir.Y * math.cos(a), 0).Unit
		end
		return Vector3.new(dir.X * math.cos(a) - dir.Z * math.sin(a), 0, dir.X * math.sin(a) + dir.Z * math.cos(a)).Unit
	end
	function b.fan(origin: Vector3, dir: Vector3, count: number, spread: number, speed: number, opts)
		if Config.SIDE_VIEW then
			-- Fanned in the vertical plane around the aim.
			for i = 1, count do
				b.projectile(origin, b.rotate(dir.Unit, (i - (count + 1) / 2) * spread) * speed, opts)
			end
			return
		end
		local base = math.atan2(dir.Z, dir.X)
		local pitch = math.asin(math.clamp(dir.Unit.Y, -1, 1))
		for i = 1, count do
			local a = base + (i - (count + 1) / 2) * spread
			local v = Vector3.new(math.cos(a) * math.cos(pitch), math.sin(pitch), math.sin(a) * math.cos(pitch)) * speed
			b.projectile(origin, v, opts)
		end
	end
	-- A ring of force expanding along the floor from the boss.
	function b.shockwaves(speed: number, maxRadius: number?)
		b.setAnim("slam", true)
		Projectiles.ring(Vector3.new(b.position.X, b.floorY, b.position.Z), speed, maxRadius or 40)
	end
	function b.dust(at: Vector3)
		Enemies.burst(at + Vector3.new(0, 0.5, 0), Color3.fromRGB(180, 170, 150), 24)
	end
	-- A glowing disc on the floor marking where something is about to land.
	function b.marker(at: Vector3, radius: number, t: number)
		local disc = make("Part", {
			Shape = Enum.PartType.Cylinder,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.35,
			Size = Vector3.new(0.3, radius * 2, radius * 2),
			CFrame = CFrame.new(at.X, b.floorY + 0.2, at.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = workspace,
		})
		temp(disc, t)
		TweenService:Create(disc, TweenInfo.new(t / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 }):Play()
		if Config.SIDE_VIEW then
			-- From the side a floor disc is a thin line, so a glowing column rises over the spot.
			local column = make("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.Neon,
				Color = WARN,
				Transparency = 0.8,
				Size = Vector3.new(radius * 1.6, 14, 0.4),
				Position = Vector3.new(at.X, b.floorY + 7, -1),
				Parent = workspace,
			})
			temp(column, t)
			TweenService:Create(column, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(radius * 0.4, 14, 0.4), Transparency = 0.45 }):Play()
		end
	end
	-- A thin warning line from `from` along `dir`.
	function b.beamWarn(from: Vector3, dir: Vector3, length: number, t: number)
		local mid = from + dir.Unit * length / 2
		local line = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.4,
			Size = Vector3.new(0.3, 0.3, length),
			CFrame = CFrame.lookAt(mid, mid + dir),
			Parent = workspace,
		})
		temp(line, t)
	end
	function b.hazard(cf: CFrame, size: Vector3, t: number)
		table.insert(fight.hazards, { cf = cf, size = size, expires = os.clock() + t })
	end
	-- A blazing beam from `from` along `dir`.
	function b.beam(from: Vector3, dir: Vector3, length: number, t: number, color: Color3?)
		local mid = from + dir.Unit * length / 2
		local cf = CFrame.lookAt(mid, mid + dir)
		local beam = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = color or Color3.fromRGB(255, 220, 255),
			Transparency = 0.1,
			Size = Vector3.new(2.2, 2.2, length),
			CFrame = cf,
			Parent = workspace,
		})
		make("PointLight", { Range = 30, Brightness = 3, Color = beam.Color, Parent = beam })
		temp(beam, t)
		b.hazard(cf, Vector3.new(2.2, 2.2, length), t)
	end
	-- A crystal spire bursting from the floor.
	function b.spire(at: Vector3, height: number, t: number)
		local spire = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(240, 160, 255),
			Transparency = 0.1,
			Size = Vector3.new(2.4, height, 2.4),
			CFrame = CFrame.new(at.X, b.floorY - height / 2, at.Z) * CFrame.Angles(0, math.rad(45), 0),
			Parent = workspace,
		})
		temp(spire, t + 0.3)
		TweenService:Create(spire, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = CFrame.new(at.X, b.floorY + height / 2, at.Z) * CFrame.Angles(0, math.rad(45), 0) }):Play()
		task.delay(t, function()
			if spire.Parent then
				TweenService:Create(spire, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end)
		b.hazard(CFrame.new(at.X, b.floorY + height / 2, at.Z), Vector3.new(2.4, height, 2.4), t)
	end
	-- Flood the arena floor with ink up to `top` for a while (runs alongside other attacks).
	function b.inkTide(top: number, duration: number)
		local sizeX, sizeZ = fight.info.maxX - fight.info.minX, fight.info.zHalf * 2
		local cz = 0
		if Config.SIDE_VIEW then
			-- Only from the back wall to the front edge of the floor, never between camera and player.
			sizeZ = fight.info.zHalf + Config.FRONT_DEPTH
			cz = (Config.FRONT_DEPTH - fight.info.zHalf) / 2
		end
		local cx = (fight.info.minX + fight.info.maxX) / 2
		local ink = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(8, 14, 18),
			Reflectance = 0.3,
			Transparency = 0.1,
			Size = Vector3.new(sizeX, 0.2, sizeZ),
			Position = Vector3.new(cx, b.floorY, cz),
			Parent = workspace,
		})
		temp(ink)
		local height = top - b.floorY
		for player in fight.participants do
			PlayerService.notify(player, "The ink is rising!", "Get off the floor.", "info")
		end
		TweenService:Create(ink, TweenInfo.new(1, Enum.EasingStyle.Sine), { Size = Vector3.new(sizeX, height, sizeZ), Position = Vector3.new(cx, b.floorY + height / 2, cz) }):Play()
		task.delay(1, function()
			if fight.boss == b and not b.cancelled then
				b.hazard(CFrame.new(cx, b.floorY + height / 2, cz), Vector3.new(sizeX, height, sizeZ), duration)
			end
		end)
		task.delay(1 + duration, function()
			if ink.Parent then
				TweenService:Create(ink, TweenInfo.new(0.8), { Size = Vector3.new(sizeX, 0.2, sizeZ), Position = Vector3.new(cx, b.floorY, cz) }):Play()
				task.delay(0.9, function()
					if ink.Parent then
						ink:Destroy()
					end
				end)
			end
		end)
	end
	-- Slip out of sight (beneath the floor) and back.
	function b.hide()
		b.hidden = true
		b.setAnim("vanish", true)
		b.wait(0.25)
		b.position = Vector3.new(b.position.X, b.floorY - 40, b.position.Z)
	end
	function b.appear(position: Vector3)
		b.position = position
		b.hidden = false
		b.dust(position)
		b.setAnim("idle")
	end
	function b.line(from: Vector3, to: Vector3, t: number)
		local mid = (from + to) / 2
		local beam = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = WARN,
			Transparency = 0.5,
			Size = Vector3.new(0.3, 0.3, (to - from).Magnitude),
			CFrame = CFrame.lookAt(mid, to),
			Parent = workspace,
		})
		temp(beam)
		local ok, err = pcall(b.telegraph, t)
		beam:Destroy()
		if not ok then
			error(err)
		end
	end
	-- Keep a point inside the arena's air (for flying and leaping bosses).
	function b.clampAir(p: Vector3): Vector3
		local half = def.size.Y / 2
		return Vector3.new(math.clamp(p.X, b.minX, b.maxX), math.clamp(p.Y, b.groundY, info.ceilY - half - 2), math.clamp(p.Z, b.minZ, b.maxZ))
	end
	-- Fly in a straight line (no floor snapping).
	function b.flyTo(target: Vector3, speed: number, anim: string?)
		target = b.clampAir(target)
		local dir = flat(target - b.position)
		if dir.Magnitude > 0 then
			b.facing = dir
		end
		b.setAnim(anim or "move")
		while (target - b.position).Magnitude > 0.05 do
			local dt = b.step()
			local delta = target - b.position
			local stepLen = speed * dt
			b.position = if delta.Magnitude <= stepLen then target else b.position + delta.Unit * stepLen
		end
	end
	-- Blink away in a puff and reappear somewhere else.
	function b.teleport(to: Vector3, color: Color3?)
		b.setAnim("vanish", true)
		Enemies.burst(b.position, color or Color3.fromRGB(230, 225, 255), 18)
		b.wait(0.18)
		b.hidden = true
		local away = b.position
		b.position = Vector3.new(away.X, b.floorY - 40, away.Z)
		b.wait(0.22)
		b.position = b.clampAir(to)
		b.hidden = false
		Enemies.burst(b.position, color or Color3.fromRGB(230, 225, 255), 18)
		b.faceTarget()
		b.setAnim("appear", true)
		b.wait(0.15)
	end
	-- A column of danger rising from the floor at `x` (fire, light, thorns).
	function b.pillar(x: number, width: number, t: number, color: Color3)
		local h = info.ceilY - info.floorY
		local cf = CFrame.new(x, info.floorY + h / 2, 0)
		local col = make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.15,
			Size = Vector3.new(width * 0.3, h, 1.2),
			CFrame = cf,
			Parent = workspace,
		})
		make("PointLight", { Range = 26, Brightness = 3, Color = color, Parent = col })
		temp(col, t + 0.3)
		TweenService:Create(col, TweenInfo.new(0.1), { Size = Vector3.new(width, h, 1.2) }):Play()
		task.delay(t, function()
			if col.Parent then
				TweenService:Create(col, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.2, h, 1.2) }):Play()
			end
		end)
		b.hazard(cf, Vector3.new(width, h, 4), t)
	end
	-- A warning strip on the floor where a pillar will rise.
	function b.pillarWarn(x: number, width: number, t: number)
		b.marker(Vector3.new(x, b.floorY, 0), width / 2, t)
	end
	return b
end

local function placeBoss(b)
	if b.hitbox then
		b.hitbox.CFrame = Rig.frame(b.position, b.facing)
	end
end

local function dyingSequence(fight: Fight, b)
	fight.state = "dying"
	b.cancelled = true
	fight.stateFolder:SetAttribute("Health", 0)
	table.clear(fight.hazards)
	Projectiles.clear()
	b.model:SetAttribute("Warn", false)
	b.setAnim("death", true)
	local def = fight.def
	for player in fight.participants do
		Net.event("Flash"):FireClient(player, 0.6)
		Net.event("CameraShake"):FireClient(player, 1.2)
	end
	task.spawn(function()
		for _ = 1, 8 do
			Enemies.burst(b.position + Vector3.new(math.random(-3, 3), math.random(-2, 3), math.random(-3, 3)), Color3.fromRGB(255, 255, 255), 14)
			task.wait(0.2)
		end
		b.model:SetAttribute("Dead", true)
		Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 60)
		Enemies.burst(b.position, Color3.fromRGB(120, 220, 255), 40)
		for player in fight.participants do
			Net.event("AreaTitle"):FireClient(player, def.name, "has fallen", "victory")
			Net.event("CameraShake"):FireClient(player, 1)
		end
		task.wait(0.1)
		endFight(fight, true)
	end)
end

local function startFight(fight: Fight, players: { Player })
	local def = fight.def
	fight.state = "intro"
	fight.participants = {}
	setGates(fight, true)

	local b = createBoss(fight)
	fight.boss = b
	b.faceTarget()
	fight.stateFolder:SetAttribute("Health", b.hp)
	fight.stateFolder:SetAttribute("MaxHealth", def.hp)
	fight.stateFolder:SetAttribute("Active", true)
	placeBoss(b)
	b.model.Parent = workspace:FindFirstChild("Enemies")

	for _, p in players do
		fight.participants[p] = true
		Net.event("BossIntro"):FireClient(p, def.name, def.title, b.position, Config.BOSS_INTRO_TIME)
	end

	Damageable.register(b.model, {
		onHit = function(_player: Player, damage: number, _direction: Vector3?, kind: string?)
			if b.cancelled or b.hp <= 0 or fight.state ~= "fighting" or b.hidden then
				return false
			end
			b.hp -= damage
			fight.stateFolder:SetAttribute("Health", math.max(0, b.hp))
			b.model:SetAttribute("HitKind", kind or "nail")
			b.model:SetAttribute("HitAt", os.clock())
			if b.hp <= 0 then
				dyingSequence(fight, b)
				return true
			end
			local thresholds = def.phases or {}
			while b.phase <= #thresholds and b.hp / def.hp <= thresholds[b.phase] do
				b.phase += 1
				b.pendingPhase = b.phase
				for p in fight.participants do
					Net.event("BossPhase"):FireClient(p, b.phase)
				end
			end
			return true
		end,
	})

	task.spawn(function()
		local ok, err = pcall(function()
			-- Introduction: a roar once the camera arrives, then the fight begins.
			b.rawWait(Config.BOSS_INTRO_TIME * 0.35)
			b.setAnim("roar", true)
			b.shake(0.9)
			Enemies.burst(b.position, Color3.fromRGB(255, 255, 255), 20)
			b.rawWait(Config.BOSS_INTRO_TIME * 0.65)
			if fight.state == "intro" then
				fight.state = "fighting"
			end
			b.setAnim("idle")
			b.wait(0.4)
			def.run(b)
		end)
		if not ok and err ~= CANCEL then
			warn("[Vesperdeep] Boss error:", err)
		end
	end)
end

-- ===== The Hall of Trials =====

-- The hall's own champions, beaten in order; then every story boss you have already felled.
local CHAMPIONS = { "sessa", "mirra", "carapace", "vell", "pyrrhe" }
local STORY = { "gravelmaw", "vantis", "widow", "quartzelle", "murrow", "echo", "asterion" }
local trialFight: Fight? = nil

local function trialList(player: Player)
	local list = {}
	local open = true
	for _, id in CHAMPIONS do
		local def = DEFS[id]
		local beaten = PlayerService.hasDefeated(player, "trial_" .. id)
		table.insert(list, { id = id, name = def.name, title = def.title, unlocked = open, beaten = beaten, champion = true })
		open = open and beaten
	end
	for _, id in STORY do
		local def = DEFS[id]
		if def then
			local beaten = PlayerService.hasDefeated(player, id)
			table.insert(list, { id = id, name = def.name, title = def.title, unlocked = beaten, beaten = beaten, champion = false })
		end
	end
	return list
end

local function challenge(player: Player, id: unknown)
	local fight = trialFight
	if not fight or typeof(id) ~= "string" or fight.state ~= "idle" or not DEFS[id] then
		return
	end
	if PlayerService.zoneOf(player) ~= fight.info.zone or (player:GetAttribute("Masks") or 0) <= 0 then
		return
	end
	local allowed = false
	for _, entry in trialList(player) do
		if entry.id == id and entry.unlocked then
			allowed = true
		end
	end
	if not allowed then
		return
	end
	local def = DEFS[id]
	fight.def = def
	fight.rigId = id
	fight.rematch = table.find(STORY, id) ~= nil
	fight.stateFolder:SetAttribute("Name", def.name)
	fight.stateFolder:SetAttribute("Title", def.title)
	fight.stateFolder:SetAttribute("Music", def.music or "boss")
	-- Step into the arena, a little in from its left gate.
	local info = fight.info
	local character = player.Character
	if character then
		local at = Vector3.new(info.minX + 14, info.floorY + 3.2, 0)
		character:PivotTo(CFrame.lookAt(at, at + Vector3.xAxis))
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	task.wait(0.35)
	if fight.state == "idle" then
		startFight(fight, { player })
	end
end

function Bosses.init(infos, playerService)
	PlayerService = playerService
	local stateRoot = make("Folder", { Name = "BossState", Parent = ReplicatedStorage })
	for _, info in infos do
		local bossInfo = info.boss
		if bossInfo and bossInfo.id == "trials" then
			local stateFolder = make("Folder", { Name = "trials", Parent = stateRoot })
			stateFolder:SetAttribute("Name", "")
			stateFolder:SetAttribute("Title", "")
			stateFolder:SetAttribute("Zone", bossInfo.zone)
			stateFolder:SetAttribute("Music", "boss")
			stateFolder:SetAttribute("Active", false)
			local fight: Fight = {
				info = bossInfo,
				def = nil,
				state = "idle",
				participants = {},
				boss = nil,
				hazards = {},
				temp = {},
				stateFolder = stateFolder,
				trial = true,
			}
			trialFight = fight
			table.insert(fights, fight)
		elseif bossInfo then
			local def = DEFS[bossInfo.id]
			assert(def, "No boss definition for " .. bossInfo.id)
			local stateFolder = make("Folder", { Name = bossInfo.id, Parent = stateRoot })
			stateFolder:SetAttribute("Name", def.name)
			stateFolder:SetAttribute("Title", def.title)
			stateFolder:SetAttribute("Zone", bossInfo.zone)
			stateFolder:SetAttribute("Music", def.music or "boss")
			stateFolder:SetAttribute("Active", false)
			table.insert(fights, {
				info = bossInfo,
				def = def,
				state = "idle",
				participants = {},
				boss = nil,
				hazards = {},
				temp = {},
				stateFolder = stateFolder,
			})
		end
	end

	-- The statue in the Hall of Trials offers the list of foes; the client picks one.
	local world = workspace:FindFirstChild("World")
	if world then
		for _, inst in world:GetDescendants() do
			if inst:IsA("ProximityPrompt") then
				local model = inst:FindFirstAncestorWhichIsA("Model")
				if model and model.Name == "TrialStatue" then
					inst.Triggered:Connect(function(player)
						if trialFight and trialFight.state == "idle" then
							Net.event("TrialMenu"):FireClient(player, trialList(player))
						else
							PlayerService.notify(player, "The hall is busy.", "A trial is already under way.", "info")
						end
					end)
				end
			end
		end
	end
	Net.event("Challenge").OnServerEvent:Connect(challenge)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fight in fights do
			if fight.state == "idle" and fight.trial then
				continue
			elseif fight.state == "idle" then
				local inside = arenaPlayers(fight.info)
				for _, player in inside do
					if not PlayerService.hasDefeated(player, fight.info.id) then
						startFight(fight, inside)
						break
					end
				end
			elseif (fight.state == "intro" or fight.state == "fighting" or fight.state == "dying") and fight.boss then
				local b = fight.boss
				if fight.state ~= "dying" then
					for _, player in arenaPlayers(fight.info) do
						if not fight.participants[player] then
							fight.participants[player] = true
							Net.event("AreaTitle"):FireClient(player, fight.def.name, fight.def.title, "boss")
						end
					end
				end
				for i = #fight.hazards, 1, -1 do
					if now > fight.hazards[i].expires then
						table.remove(fight.hazards, i)
					end
				end
				placeBoss(b)
				local anyone = false
				for player in fight.participants do
					local root = PlayerService.rootOf(player)
					local alive = player.Parent ~= nil and root ~= nil and (player:GetAttribute("Masks") or 0) > 0
					if alive and root and Grid.zoneAt(root.Position) == fight.info.zone then
						anyone = true
						if fight.state == "fighting" then
							local half = b.size / 2
							local p = b.hitbox.CFrame:PointToObjectSpace(root.Position)
							if not b.hidden and math.abs(p.X) < half.X + 0.9 and math.abs(p.Z) < half.Z + 0.9 and math.abs(p.Y) < half.Y + 2.4 then
								PlayerService.damage(player, 1, b.position)
							end
							for _, hz in fight.hazards do
								local h = hz.cf:PointToObjectSpace(root.Position)
								if math.abs(h.X) < hz.size.X / 2 + 0.9 and math.abs(h.Y) < hz.size.Y / 2 + 2.4 and math.abs(h.Z) < hz.size.Z / 2 + 0.9 then
									PlayerService.damage(player, 1, hz.cf.Position)
									break
								end
							end
						end
					else
						fight.participants[player] = nil
					end
				end
				if not anyone and fight.state ~= "dying" then
					endFight(fight, false)
				end
			end
		end
	end)
end

return Bosses
